[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Worktree,
    [Parameter(Mandatory = $true)][string]$EvidenceRoot,
    [Parameter(Mandatory = $true)][string]$ProfileRoot,
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ExpectedHeadSha,
    [Parameter(Mandatory = $true)][string]$ExpectedTreeSha
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:ToolingRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script:HarnessPath = [IO.Path]::GetFullPath($PSCommandPath)
Import-Module (Join-Path $script:ToolingRoot 'tools/pr90_mcp_startup_state_machine_v1.psm1') -Force
Import-Module (Join-Path $script:ToolingRoot 'tools/pr90_mcp_endpoint_ownership_v2.psm1') -Force
Import-Module (Join-Path $script:ToolingRoot 'tools/pr90_listener_process_identity_reader_v1.psm1') -Force
Import-Module (Join-Path $script:ToolingRoot 'tools/pr90_endpoint_listener_record_v1.psm1') -Force
Import-Module (Join-Path $script:ToolingRoot 'tools/pr90_probe_b_attempt22_contract_v1.psm1') -Force


function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-ImmutableJson([string]$Path, [object]$Value) {
    if (Test-Path -LiteralPath $Path) {
        throw "Refusing to overwrite immutable evidence: $Path"
    }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    $temporary = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText(
            $temporary,
            ($Value | ConvertTo-Json -Depth 50),
            [Text.UTF8Encoding]::new($false)
        )
        [IO.File]::Move($temporary, $Path, $false)
    } finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }
}

function Invoke-Git([string[]]$Arguments) {
    $rows = @(& git -C $script:Root @Arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "git failed: $($Arguments -join ' ')"
    }
    return @($rows)
}

function Get-CanonicalRowsSha([string[]]$Rows) {
    $sorted = [string[]]@($Rows)
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
        [string]::Join("`n", $sorted)
    )
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
}

function Get-ImportRows {
    $paths = @(Invoke-Git @('diff', '--name-only', '--diff-filter=M', 'HEAD', '--') |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_.EndsWith('.import', [StringComparison]::Ordinal) })
    $result = [Collections.Generic.List[object]]::new()
    foreach ($path in $paths) {
        $absolute = Join-Path $script:Root $path
        $text = [IO.File]::ReadAllText($absolute)
        $sourceMatch = [regex]::Match($text, '(?m)^source_file="res://([^"]+)"\s*$')
        $importerMatch = [regex]::Match($text, '(?m)^importer="([^"]+)"\s*$')
        $sourceRelative = if ($sourceMatch.Success) {
            $sourceMatch.Groups[1].Value.Replace('/', [IO.Path]::DirectorySeparatorChar)
        } else { '' }
        $sourceAbsolute = if ($sourceRelative) { Join-Path $script:Root $sourceRelative } else { '' }
        $sourceTracked = $false
        if ($sourceRelative) {
            & git -C $script:Root ls-files --error-unmatch -- $sourceRelative 2>$null | Out-Null
            $sourceTracked = $LASTEXITCODE -eq 0
        }
        $preHash = (Invoke-Git @('show', "HEAD:$path") | Out-String)
        $preBytes = [Text.UTF8Encoding]::new($false).GetBytes($preHash)
        $preSha = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($preBytes)
        ).ToLowerInvariant()
        $referenceCount = 0
        if ($sourceMatch.Success) {
            $needle = "res://$($sourceMatch.Groups[1].Value)"
            $referenceRows = @(& git -C $script:Root grep -n -F -- $needle HEAD -- '*.gd' '*.tscn' '*.tres' '*.res' '*.json' '*.import' 2>$null)
            if ($LASTEXITCODE -in @(0, 1)) { $referenceCount = $referenceRows.Count }
        }
        $classification = if (
            $sourceMatch.Success -and $importerMatch.Success -and
            $sourceTracked -and (Test-Path -LiteralPath $sourceAbsolute -PathType Leaf)
        ) { 'CANONICAL_GENERATED_TRACKED_IMPORT_METADATA' } else { 'UNKNOWN' }
        $result.Add([pscustomobject][ordered]@{
            path = $path.Replace('\', '/')
            associated_source_path = if ($sourceMatch.Success) { "res://$($sourceMatch.Groups[1].Value)" } else { '' }
            source_sha256 = if ($sourceTracked -and (Test-Path -LiteralPath $sourceAbsolute -PathType Leaf)) { Get-Sha256 $sourceAbsolute } else { '' }
            pre_import_sha256 = $preSha
            post_import_sha256 = Get-Sha256 $absolute
            pass_2_sha256 = Get-Sha256 $absolute
            git_tracked = $true
            runtime_reference_count = $referenceCount
            importer = if ($importerMatch.Success) { $importerMatch.Groups[1].Value } else { '' }
            godot_version = $script:GodotVersion
            classification = $classification
        })
    }
    return @($result)
}

function Get-Uids {
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($path in @(Invoke-Git @('ls-files', '-o', '--exclude-standard'))) {
        $normalized = $path.Replace('\', '/')
        if ($normalized -notmatch '\.(gd|gdshader)\.uid$') { continue }
        $sourcePath = $normalized.Substring(0, $normalized.Length - 4)
        & git -C $script:Root ls-files --error-unmatch -- $sourcePath 2>$null | Out-Null
        $sourceTracked = $LASTEXITCODE -eq 0
        $absolute = Join-Path $script:Root $normalized
        $rows.Add([pscustomobject][ordered]@{
            path = $normalized
            source_path = $sourcePath
            sha256 = Get-Sha256 $absolute
            byte_count = (Get-Item -LiteralPath $absolute).Length
            source_tracked = $sourceTracked
        })
    }
    return @($rows)
}

function Get-IgnoredInventory {
    $paths = @(Invoke-Git @('-c', 'core.quotePath=false', 'ls-files', '-o', '-i', '--exclude-standard')) |
        ForEach-Object { $_.Replace('\', '/') }
    $unknown = @($paths | Where-Object {
        -not $_.StartsWith('.godot/', [StringComparison]::Ordinal) -and
        -not $_.StartsWith('.codex-godot/', [StringComparison]::Ordinal) -and
        -not $_.EndsWith('.import', [StringComparison]::Ordinal)
    })
    return [pscustomobject][ordered]@{
        count = $paths.Count
        path_set_sha256 = Get-CanonicalRowsSha $paths
        unknown_count = $unknown.Count
        unknown_paths = $unknown
    }
}

function Get-CurrentSnapshot([string]$Label, [int]$ExitCode) {
    $tracked = @(Invoke-Git @('diff', '--name-only', 'HEAD', '--'))
    $imports = @(Get-ImportRows)
    $uids = @(Get-Uids)
    $untracked = @(Invoke-Git @('ls-files', '-o', '--exclude-standard'))
    $unknownUntracked = @($untracked | Where-Object { $_ -notmatch '\.(gd|gdshader)\.uid$' })
    $nonGeneratedTracked = @($tracked | Where-Object { -not $_.EndsWith('.import', [StringComparison]::Ordinal) })
    return [pscustomobject][ordered]@{
        schema = 'SpaceSyndicateCanonicalImportPassV2'
        canonical_import_harness_version = 3
        canonical_import_harness_path = $script:HarnessPath
        canonical_import_harness_sha256 = Get-Sha256 $script:HarnessPath
        endpoint_ownership_contract_version = 2
        label = $Label
        captured_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
        head_sha = $script:Head
        tree_sha = $script:Tree
        godot_version = $script:GodotVersion
        godot_sha256 = Get-Sha256 $script:Godot
        exit_code = $ExitCode
        tracked_delta_count = $tracked.Count
        tracked_import_metadata_count = $imports.Count
        tracked_import_metadata = $imports
        tracked_import_path_set_sha256 = Get-CanonicalRowsSha @($imports | ForEach-Object { $_.path })
        tracked_import_byte_map_sha256 = Get-CanonicalRowsSha @($imports | ForEach-Object { "$($_.path)|$($_.post_import_sha256)" })
        non_generated_tracked_delta_count = $nonGeneratedTracked.Count
        non_generated_tracked_delta_paths = $nonGeneratedTracked
        untracked_uid_count = $uids.Count
        untracked_uid_manifest = $uids
        untracked_uid_path_set_sha256 = Get-CanonicalRowsSha @($uids | ForEach-Object { $_.path })
        untracked_uid_byte_map_sha256 = Get-CanonicalRowsSha @($uids | ForEach-Object { "$($_.path)|$($_.sha256)" })
        unknown_untracked_count = $unknownUntracked.Count
        unknown_untracked_paths = $unknownUntracked
        ignored_inventory = Get-IgnoredInventory
        class_cache_path = '.godot/global_script_class_cache.cfg'
        class_cache_sha256 = Get-Sha256 (Join-Path $script:Root '.godot/global_script_class_cache.cfg')
    }
}

function Wait-ImportStable {
    $previous = ''
    $stable = 0
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(90)
    do {
        $rows = @(Invoke-Git @('status', '--porcelain=v1', '--untracked-files=all'))
        $signature = Get-CanonicalRowsSha $rows
        if ($signature -ceq $previous) { $stable += 1 } else { $stable = 0; $previous = $signature }
        if ($stable -ge 5) { return }
        Start-Sleep -Seconds 1
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw 'Godot import state did not stabilize within 90 seconds.'
}

function Get-TaskGodotProcessRows {
    return @(
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object {
                [string]$_.ExecutablePath -iin @($script:Godot, $script:GodotGui) -and
                (Test-Pr90McpCommandLinePathBindingV2 -CommandLine ([string]$_.CommandLine) -ExpectedRoot $script:Root)
            }
    )
}

function Wait-CanonicalEndpointOwnerV2 {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][object]$LaunchReceipt,
        [Parameter(Mandatory = $true)][string]$LaunchReceiptPath
    )
    $controlPid = [int]$LaunchReceipt.pid
    $control = Read-EndpointListenerOwnerIdentityV1 -PidValue $controlPid
    $expectedControlFiletime = [DateTimeOffset]::Parse(
        [string]$LaunchReceipt.process_start_time_utc,
        [Globalization.CultureInfo]::InvariantCulture
    ).UtcDateTime.ToFileTimeUtc().ToString([Globalization.CultureInfo]::InvariantCulture)
    $expectedGuiPath = $script:GodotGui
    $controlGreen = (
        [bool]$control.exists -and [bool]$control.identity_read_green -and
        [int]$control.pid -eq $controlPid -and
        [string]$control.executable_path -ieq $script:Godot -and
        [string]$control.executable_sha256 -ceq (Get-Sha256 $script:Godot) -and
        [string]$control.creation_time_filetime_utc -ceq $expectedControlFiletime -and
        (Test-Pr90McpCommandLinePathBindingV2 -CommandLine ([string]$control.command_line) -ExpectedRoot $script:Root)
    )
    if (-not $controlGreen) { throw "$Label console wrapper identity is not exact." }

    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(180)
    $owner = $null
    $projectInfo = $null
    while ([DateTimeOffset]::UtcNow -lt $deadline) {
        $alternate = @(Get-NetTCPConnection -State Listen -LocalPort 7586 -ErrorAction SilentlyContinue)
        if ($alternate.Count -ne 0) { throw "$Label protected alternate port 7586 is occupied." }
        $listeners = @(Get-NetTCPConnection -State Listen -LocalPort 7576 -ErrorAction SilentlyContinue)
        if ($listeners.Count -gt 1) { throw "$Label MCP endpoint has multiple listener rows." }
        if ($listeners.Count -eq 1) {
            $ownerPid = [int]$listeners[0].OwningProcess
            $candidate = Read-EndpointListenerOwnerIdentityV1 -PidValue $ownerPid
            $ownerGreen = (
                [bool]$candidate.exists -and [bool]$candidate.identity_read_green -and
                $ownerPid -ne $controlPid -and
                [string]$candidate.executable_path -ieq $expectedGuiPath -and
                [string]$candidate.executable_sha256 -ceq (Get-Sha256 $expectedGuiPath) -and
                [int]$candidate.parent_pid -eq $controlPid -and
                [int]$candidate.windows_session_id -eq [int]$control.windows_session_id -and
                -not [string]::IsNullOrWhiteSpace([string]$candidate.user_sid) -and
                [string]$candidate.user_sid -ceq [string]$control.user_sid -and
                [long]$candidate.creation_time_filetime_utc -ge [long]$control.creation_time_filetime_utc -and
                (Test-Pr90McpCommandLinePathBindingV2 -CommandLine ([string]$candidate.command_line) -ExpectedRoot $script:Root)
            )
            $ownershipParams = @{
                ControlIdentity = $control
                EndpointOwnerIdentity = $candidate
                ListenerOwnerPids = @($ownerPid)
                AlternateProtectedListenerCount = $alternate.Count
                ExpectedControlProcessId = $controlPid
                ExpectedControlPath = $script:Godot
                ExpectedControlSha256 = Get-Sha256 $script:Godot
                ExpectedControlCreationFiletimeUtc = $expectedControlFiletime
                ExpectedEndpointOwnerPid = $ownerPid
                ExpectedEndpointOwnerPath = $expectedGuiPath
                ExpectedEndpointOwnerSha256 = Get-Sha256 $expectedGuiPath
                ExpectedRoot = $script:Root
            }
            $ownerGreen = $ownerGreen -and (Test-Pr90CanonicalImportEndpointOwnershipV2 @ownershipParams)
            if (-not $ownerGreen) { throw "$Label listener is not the exact V2 GUI endpoint owner." }

            $token = [IO.File]::ReadAllText([string]$LaunchReceipt.token_path).Trim()
            if ($token -notmatch '^[0-9a-f]{64}$') { throw "$Label role token is invalid." }
            $body = @{
                jsonrpc = '2.0'
                id = 1
                method = 'tools/call'
                params = @{ name = 'get_project_info'; arguments = @{} }
            } | ConvertTo-Json -Depth 10 -Compress
            try {
                $response = Invoke-RestMethod -Uri 'http://127.0.0.1:7576/' -Method Post -Headers @{
                    'X-Funplay-MCP-Token' = $token
                    'MCP-Protocol-Version' = '2025-11-25'
                } -ContentType 'application/json' -Body $body -TimeoutSec 5
                $hasError = $null -ne $response.PSObject.Properties['error'] -and $null -ne $response.error
                if (-not $hasError -and -not [bool]$response.result.isError) {
                    $candidateInfo = $response.result.content[0].text | ConvertFrom-Json -Depth 20
                    $reportedRoot = [IO.Path]::GetFullPath(([string]$candidateInfo.project_root).Replace('/', '\')).TrimEnd('\')
                    if (-not $reportedRoot.Equals($script:Root, [StringComparison]::OrdinalIgnoreCase)) {
                        throw "$Label MCP project root does not match the disposable clone."
                    }
                    if ([string]$candidateInfo.tool_profile -cne 'core') {
                        throw "$Label MCP tool profile is not core."
                    }
                    $owner = $candidate
                    $projectInfo = $candidateInfo
                    break
                }
            } catch {
                if ($_.Exception.Message -like "$Label MCP project root*" -or $_.Exception.Message -like "$Label MCP tool profile*") {
                    throw
                }
            }
        }
        $controlNow = Read-EndpointListenerOwnerIdentityV1 -PidValue $controlPid
        if (-not [bool]$controlNow.exists -or [string]$controlNow.creation_time_filetime_utc -cne $expectedControlFiletime) {
            throw "$Label console wrapper exited or changed identity before MCP readiness."
        }
        Start-Sleep -Milliseconds 500
    }
    if ($null -eq $owner -or $null -eq $projectInfo) {
        throw "$Label V2 MCP editor did not become ready within 180 seconds."
    }

    $connectionPath = Join-Path $script:Root '.codex-godot/connection.json'
    $connection = [pscustomobject][ordered]@{
        schema = 'McpStartupConnectionV2'
        role = 'A'
        endpoint = 'http://127.0.0.1:7576/'
        port = 7576
        pid = $controlPid
        control_process_pid = $controlPid
        worktree = $script:Root
        godot_path = $script:Godot
        process_start_time_utc = [string]$LaunchReceipt.process_start_time_utc
        command_line = [string]$control.command_line
        endpoint_ownership_contract_version = 2
        endpoint_owner_pid = [int]$owner.pid
        endpoint_owner_creation_time_utc = [string]$owner.creation_time_utc
        endpoint_owner_creation_time_filetime_utc = [string]$owner.creation_time_filetime_utc
        endpoint_owner_executable_path = [string]$owner.executable_path
        endpoint_owner_executable_sha256 = [string]$owner.executable_sha256
        endpoint_owner_process_role = 'GUI_ENGINE'
        endpoint_owner_command_line = [string]$owner.command_line
        endpoint_owner_parent_pid = [int]$owner.parent_pid
        endpoint_owner_windows_session_id = [int]$owner.windows_session_id
        endpoint_owner_user_sid = [string]$owner.user_sid
        launch_session_id = [string]$LaunchReceipt.launch_session_id
        launch_session_id_source = 'tooling_generated'
        token_path = [string]$LaunchReceipt.token_path
        log_path = [string]$LaunchReceipt.log_path
        godot_version = [string]$projectInfo.godot_version.string
        tool_profile = [string]$projectInfo.tool_profile
        renderer = 'compatibility'
        resolution = '1600x960'
    }
    [IO.File]::WriteAllText(
        $connectionPath,
        ($connection | ConvertTo-Json -Depth 20),
        [Text.UTF8Encoding]::new($false)
    )

    $attestation = [pscustomobject][ordered]@{
        schema = 'Pr90CanonicalImportEndpointOwnershipV2'
        status = 'PASS'
        import_pass_label = $Label
        captured_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
        harness_path = $script:HarnessPath
        harness_sha256 = Get-Sha256 $script:HarnessPath
        launch_receipt_path = [IO.Path]::GetFullPath($LaunchReceiptPath)
        launch_receipt_sha256 = Get-Sha256 $LaunchReceiptPath
        launch_session_id = [string]$LaunchReceipt.launch_session_id
        endpoint_ownership_contract_version = 2
        endpoint = 'http://127.0.0.1:7576/'
        port = 7576
        listener_count = 1
        alternate_listener_count = 0
        control_process_identity = $control
        endpoint_owner_identity = $owner
        endpoint_owner_is_gui_engine = $true
        endpoint_owner_is_console_wrapper = $false
        endpoint_owner_parent_is_control = $true
        endpoint_owner_worktree_match = $true
        endpoint_owner_windows_session_match = $true
        endpoint_owner_user_sid_match = $true
        endpoint_owner_created_after_control = $true
        project_root = $script:Root
        project_root_match = $true
        godot_version = [string]$projectInfo.godot_version.string
        tool_profile = [string]$projectInfo.tool_profile
        canonical_payload_sha256 = ''
    }
    $attestation = Set-Pr90CanonicalPayloadV1 -Value $attestation
    $attestationPath = Join-Path $script:Evidence "$Label-endpoint-owner-v2.json"
    Write-Pr90ImmutableJson -Path $attestationPath -Value $attestation -WriteSha256Sidecar | Out-Null
    return [pscustomobject]@{
        control = $control
        owner = $owner
        connection = $connection
        attestation_path = $attestationPath
        attestation_sha256 = Get-Sha256 $attestationPath
    }
}

function Invoke-ImportPass([string]$Label) {
    $launchScript = Join-Path $script:ToolingRoot 'tools/launch_role_godot_mcp.ps1'
    $stopScript = Join-Path $script:ToolingRoot 'tools/stop_role_godot_mcp.ps1'
    $launchReceiptPath = Join-Path $script:Evidence "$Label-launch-receipt.json"
    $launcherStdoutPath = Join-Path $script:Evidence "$Label-launcher.stdout.log"
    $launcherStderrPath = Join-Path $script:Evidence "$Label-launcher.stderr.log"
    $cleanupPath = Join-Path $script:Evidence "$Label-cleanup.json"
    foreach ($path in @($launchReceiptPath, "$launchReceiptPath.sha256", $launcherStdoutPath, $launcherStderrPath, $cleanupPath, "$cleanupPath.sha256")) {
        if (Test-Path -LiteralPath $path) { throw "Refusing overwrite: $path" }
    }
    if (@(Get-NetTCPConnection -State Listen -LocalPort 7576 -ErrorAction SilentlyContinue).Count -ne 0 -or
        @(Get-NetTCPConnection -State Listen -LocalPort 7586 -ErrorAction SilentlyContinue).Count -ne 0) {
        throw "$Label requires protected ports 7576 and 7586 to be free."
    }
    if (@(Get-TaskGodotProcessRows).Count -ne 0) {
        throw "$Label found a pre-existing task-owned Godot process."
    }

    $launchSessionId = [Guid]::NewGuid().ToString('N')
    $launchArguments = @(
        '-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-File', $launchScript,
        '-Role', 'A',
        '-Port', '7576',
        '-Worktree', $script:Root,
        '-GodotPath', $script:Godot,
        '-Renderer', 'compatibility',
        '-StartupTimeoutSeconds', '90',
        '-StartOnly',
        '-LaunchReceiptPath', $launchReceiptPath,
        '-LaunchSessionId', $launchSessionId
    )
    $controlPid = 0
    $processStartUtc = ''
    $owner = $null
    $primaryFailure = $null
    $cleanupFailure = $null
    try {
        # Wait for the exact launcher PID, not for native-pipeline EOF. The
        # long-lived Godot child can inherit the launcher's output handles;
        # PowerShell's native pipeline then waits forever even after the
        # launcher has written its receipt and exited.
        $launcher = Start-Process -FilePath (Join-Path $PSHOME 'pwsh.exe') -ArgumentList $launchArguments `
            -RedirectStandardOutput $launcherStdoutPath -RedirectStandardError $launcherStderrPath `
            -PassThru -WindowStyle Hidden
        $launcherExited = $launcher.WaitForExit(120000)
        if (-not $launcherExited) {
            try {
                Stop-Process -Id $launcher.Id -Force -ErrorAction Stop
                if (-not $launcher.WaitForExit(10000)) { throw 'launcher did not exit after exact-PID stop' }
            } catch {
                throw "$Label sealed launcher timeout cleanup failed: $($_.Exception.Message)"
            }
            throw "$Label sealed launcher did not exit within 120 seconds."
        }
        $launcherExitCode = [int]$launcher.ExitCode
        if ($launcherExitCode -ne 0) { throw "$Label sealed launcher failed: exit=$launcherExitCode" }
        $launchReceipt = Get-Content -Raw -LiteralPath $launchReceiptPath | ConvertFrom-Json -Depth 30
        if (
            [string]$launchReceipt.schema -cne 'McpGodotProcessStartReceiptV1' -or
            [string]$launchReceipt.status -cne 'PASS' -or
            [string]$launchReceipt.launch_session_id -cne $launchSessionId -or
            [int]$launchReceipt.port -ne 7576 -or
            [string]$launchReceipt.endpoint -cne 'http://127.0.0.1:7576/' -or
            [string]$launchReceipt.godot_path -ine $script:Godot -or
            [string]$launchReceipt.worktree -ine $script:Root -or
            [int]$launchReceipt.pid -le 0
        ) { throw "$Label sealed launch receipt contract failed." }
        $expectedTokenPath = [IO.Path]::GetFullPath((Join-Path $script:Root '.codex-godot/auth.token'))
        if ([IO.Path]::GetFullPath([string]$launchReceipt.token_path) -ine $expectedTokenPath) {
            throw "$Label sealed launch token escaped the disposable clone."
        }
        $candidatePid = [int]$launchReceipt.pid
        $candidateStartUtc = [string]$launchReceipt.process_start_time_utc
        try {
            $candidateCreationFiletime = [DateTimeOffset]::Parse(
                $candidateStartUtc,
                [Globalization.CultureInfo]::InvariantCulture
            ).UtcDateTime.ToFileTimeUtc().ToString([Globalization.CultureInfo]::InvariantCulture)
        } catch {
            throw "$Label sealed launch receipt creation identity is invalid."
        }
        $candidateControl = Read-EndpointListenerOwnerIdentityV1 -PidValue $candidatePid
        $candidateControlGreen = (
            [bool]$candidateControl.exists -and [bool]$candidateControl.identity_read_green -and
            [int]$candidateControl.pid -eq $candidatePid -and
            [string]$candidateControl.executable_path -ieq $script:Godot -and
            [string]$candidateControl.executable_sha256 -ceq (Get-Sha256 $script:Godot) -and
            [string]$candidateControl.creation_time_filetime_utc -ceq $candidateCreationFiletime -and
            (Test-Pr90McpCommandLinePathBindingV2 -CommandLine ([string]$candidateControl.command_line) -ExpectedRoot $script:Root)
        )
        if (-not $candidateControlGreen) {
            throw "$Label sealed launch receipt does not identify the exact live console process."
        }
        # Only a complete receipt plus exact live identity may suppress fallback discovery.
        $controlPid = $candidatePid
        $processStartUtc = $candidateStartUtc
        $launchReceiptSha = Get-Sha256 $launchReceiptPath
        Write-Pr90ImmutableText -Path "$launchReceiptPath.sha256" -Text (
            "$launchReceiptSha  $([IO.Path]::GetFileName($launchReceiptPath))" + [Environment]::NewLine
        ) | Out-Null

        $binding = Wait-CanonicalEndpointOwnerV2 -Label $Label -LaunchReceipt $launchReceipt -LaunchReceiptPath $launchReceiptPath
        $owner = $binding.owner
        Wait-ImportStable
    } catch {
        $primaryFailure = $_
    } finally {
        if ($controlPid -le 0) {
            # Recover only one exact console process already bound to this
            # disposable worktree; never select or terminate a foreign process.
            $fallbackControls = @(
                Get-TaskGodotProcessRows |
                    Where-Object { [string]$_.ExecutablePath -ieq $script:Godot }
            )
            $fallbackIdentities = @(
                foreach ($fallbackControl in $fallbackControls) {
                    Read-EndpointListenerOwnerIdentityV1 -PidValue ([int]$fallbackControl.ProcessId)
                }
            )
            $fallbackSelection = Resolve-Pr90CanonicalImportFallbackControlV1 `
                -CandidateIdentities $fallbackIdentities -ExpectedControlPath $script:Godot -ExpectedRoot $script:Root
            if ([bool]$fallbackSelection.accepted) {
                $controlPid = [int]$fallbackSelection.pid
                $processStartUtc = [string]$fallbackSelection.creation_time_utc
            }
        }
        if ($controlPid -gt 0) {
            try {
                $cleanup = Stop-StateGodot -ControlProcessId $controlPid -ProcessStartUtc $processStartUtc -GodotPath $script:Godot -Worktree $script:Root -Port 7576 -StopScriptPath $stopScript -EndpointOwnerPid $(if ($null -ne $owner) { [int]$owner.pid } else { 0 }) -EndpointOwnerCreationFiletimeUtc $(if ($null -ne $owner) { [string]$owner.creation_time_filetime_utc } else { '' }) -EndpointOwnerSessionId $(if ($null -ne $owner) { [int]$owner.windows_session_id } else { 0 }) -EndpointOwnerUserSid $(if ($null -ne $owner) { [string]$owner.user_sid } else { '' })
                $alternateAfter = @(Get-NetTCPConnection -State Listen -LocalPort 7586 -ErrorAction SilentlyContinue).Count
                $cleanupEnvelope = [pscustomobject][ordered]@{
                    schema = 'Pr90CanonicalImportScopedCleanupV1'
                    status = if ([bool]$cleanup.stopped -and -not [bool]$cleanup.forced_stop -and [int]$cleanup.unrelated_process_termination_count -eq 0 -and $alternateAfter -eq 0) { 'PASS' } else { 'BLOCKED' }
                    import_pass_label = $Label
                    captured_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
                    control_process_id = $controlPid
                    endpoint_owner_pid = if ($null -ne $owner) { [int]$owner.pid } else { 0 }
                    stopped = [bool]$cleanup.stopped
                    forced_stop = [bool]$cleanup.forced_stop
                    forced_stop_process_ids = @($cleanup.forced_stop_process_ids)
                    process_count_after = [int]$cleanup.process_count_after
                    endpoint_count_after = [int]$cleanup.endpoint_count_after
                    alternate_endpoint_count_after = $alternateAfter
                    unrelated_process_termination_count = [int]$cleanup.unrelated_process_termination_count
                    canonical_payload_sha256 = ''
                }
                $cleanupEnvelope = Set-Pr90CanonicalPayloadV1 -Value $cleanupEnvelope
                Write-Pr90ImmutableJson -Path $cleanupPath -Value $cleanupEnvelope -WriteSha256Sidecar | Out-Null
                if ([string]$cleanupEnvelope.status -cne 'PASS') {
                    throw "$Label scoped cleanup did not converge normally."
                }
            } catch {
                $cleanupFailure = $_
            }
        }
    }
    $terminalProcessCount = @(Get-TaskGodotProcessRows).Count
    $terminalPrimaryPortCount = @(Get-NetTCPConnection -State Listen -LocalPort 7576 -ErrorAction SilentlyContinue).Count
    $terminalAlternatePortCount = @(Get-NetTCPConnection -State Listen -LocalPort 7586 -ErrorAction SilentlyContinue).Count
    if ($terminalProcessCount -ne 0 -or $terminalPrimaryPortCount -ne 0 -or $terminalAlternatePortCount -ne 0) {
        $cleanupDetail = if ($null -ne $cleanupFailure) { $cleanupFailure.Exception.Message } else { '' }
        $primaryDetail = if ($null -ne $primaryFailure) { $primaryFailure.Exception.Message } else { '' }
        throw "$Label terminal process/port convergence failed: process=$terminalProcessCount port7576=$terminalPrimaryPortCount port7586=$terminalAlternatePortCount cleanup='$cleanupDetail' primary='$primaryDetail'"
    }
    if ($null -ne $cleanupFailure) {
        throw "$Label cleanup failed after terminal-zero verification: $($cleanupFailure.Exception.Message)"
    }
    if ($null -ne $primaryFailure) { throw $primaryFailure }
    Wait-ImportStable
    return 0
}

function Invoke-CompatibilityWarmup {
    $originalEnvironment = @{
        USERPROFILE = $env:USERPROFILE
        APPDATA = $env:APPDATA
        LOCALAPPDATA = $env:LOCALAPPDATA
        TEMP = $env:TEMP
        TMP = $env:TMP
    }
    $env:USERPROFILE = $script:Profile
    $env:APPDATA = Join-Path $script:Profile 'appdata-roaming'
    $env:LOCALAPPDATA = Join-Path $script:Profile 'appdata-local'
    $env:TEMP = Join-Path $script:Profile 'temp'
    $env:TMP = Join-Path $script:Profile 'tmp'
    foreach ($path in @($env:USERPROFILE, $env:APPDATA, $env:LOCALAPPDATA, $env:TEMP, $env:TMP)) {
        [IO.Directory]::CreateDirectory($path) | Out-Null
    }
    $log = Join-Path $script:Evidence 'compatibility-warmup.godot.log'
    # A dummy headless renderer writes different .import metadata for 3D
    # textures; the subsequent compatibility editor then queues a second
    # reimport and Godot reports "Task 'reimport' already exists". Use the
    # exact Role A renderer and let --import wait for every resource import.
    # Recovery mode keeps editor plugins (including MCP) out of this phase.
    $arguments = @(
        '--editor', '--recovery-mode', '--path', $script:Root,
        '--log-file', $log, '--import',
        '--rendering-method', 'gl_compatibility',
        '--rendering-driver', 'opengl3_angle'
    )
    $environment = @{
        USERPROFILE = $env:USERPROFILE; APPDATA = $env:APPDATA; LOCALAPPDATA = $env:LOCALAPPDATA
        TEMP = $env:TEMP; TMP = $env:TMP
    }
    try {
        $process = Start-Process -FilePath $script:Godot -ArgumentList $arguments -Environment $environment -PassThru -Wait -WindowStyle Hidden
        if ($process.ExitCode -ne 0) { throw "Compatibility import warmup failed: exit=$($process.ExitCode)" }
        Wait-ImportStable
    } finally {
        foreach ($name in $originalEnvironment.Keys) {
            Set-Item -Path "Env:$name" -Value $originalEnvironment[$name]
        }
    }
}

$script:Root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd('\')
$script:Evidence = [IO.Path]::GetFullPath($EvidenceRoot)
$script:Profile = [IO.Path]::GetFullPath($ProfileRoot)
$script:Godot = (Resolve-Path -LiteralPath $GodotPath).Path
$script:GodotGui = Resolve-Pr90McpGuiEnginePathV2 -GodotConsolePath $script:Godot
if (-not (Test-Path -LiteralPath $script:GodotGui -PathType Leaf) -or
    $script:GodotGui.Equals($script:Godot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Canonical import requires a console engine with a distinct existing GUI sibling.'
}
[IO.Directory]::CreateDirectory($script:Evidence) | Out-Null
[IO.Directory]::CreateDirectory($script:Profile) | Out-Null

$script:Head = @(Invoke-Git @('rev-parse', 'HEAD'))[0].Trim()
$script:Tree = @(Invoke-Git @('rev-parse', 'HEAD^{tree}'))[0].Trim()
if ($script:Head -cne $ExpectedHeadSha -or $script:Tree -cne $ExpectedTreeSha) {
    throw 'Disposable clone HEAD/tree does not match the frozen authority.'
}
$initialStatus = @(Invoke-Git @('status', '--porcelain=v1', '--untracked-files=all'))
if ($initialStatus.Count -ne 0) { throw 'Import authority requires a fresh clean clone.' }
$script:GodotVersion = (& $script:Godot --version | Select-Object -First 1).Trim()

Invoke-CompatibilityWarmup
$pass1Exit = Invoke-ImportPass 'import-pass-1'
$pass1 = Get-CurrentSnapshot 'import-pass-1' $pass1Exit
$pass1Path = Join-Path $script:Evidence 'import-pass-1-manifest.json'
Write-ImmutableJson $pass1Path $pass1

$pass2Exit = Invoke-ImportPass 'import-pass-2'
$pass2 = Get-CurrentSnapshot 'import-pass-2' $pass2Exit
$pass2Path = Join-Path $script:Evidence 'import-pass-2-manifest.json'
Write-ImmutableJson $pass2Path $pass2

$pathParity = [string]$pass1.tracked_import_path_set_sha256 -ceq [string]$pass2.tracked_import_path_set_sha256
$byteParity = [string]$pass1.tracked_import_byte_map_sha256 -ceq [string]$pass2.tracked_import_byte_map_sha256
$uidPathParity = [string]$pass1.untracked_uid_path_set_sha256 -ceq [string]$pass2.untracked_uid_path_set_sha256
$uidByteParity = [string]$pass1.untracked_uid_byte_map_sha256 -ceq [string]$pass2.untracked_uid_byte_map_sha256
$unknownImports = @($pass2.tracked_import_metadata | Where-Object { $_.classification -ceq 'UNKNOWN' })
$baselineGreen = $pass1Exit -eq 0 -and $pass2Exit -eq 0 -and $pathParity -and $byteParity -and
    $uidPathParity -and $uidByteParity -and $pass2.non_generated_tracked_delta_count -eq 0 -and
    $pass2.unknown_untracked_count -eq 0 -and $pass2.ignored_inventory.unknown_count -eq 0 -and
    $unknownImports.Count -eq 0 -and $pass2.tracked_import_metadata_count -gt 0 -and
    (Test-Path -LiteralPath (Join-Path $script:Root '.godot/global_script_class_cache.cfg'))

$baseline = [pscustomobject][ordered]@{
    schema = 'SpaceSyndicatePostImportAuthorityBaselineV2'
    canonical_import_harness_version = 3
    canonical_import_harness_path = $script:HarnessPath
    canonical_import_harness_sha256 = Get-Sha256 $script:HarnessPath
    endpoint_ownership_contract_version = 2
    sealed_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    head_sha = $script:Head
    tree_sha = $script:Tree
    godot_version = $script:GodotVersion
    godot_sha256 = Get-Sha256 $script:Godot
    project_godot_sha256 = Get-Sha256 (Join-Path $script:Root 'project.godot')
    import_pass_1_exit_code = $pass1Exit
    import_pass_2_exit_code = $pass2Exit
    import_pass_1_manifest_sha256 = Get-Sha256 $pass1Path
    import_pass_2_manifest_sha256 = Get-Sha256 $pass2Path
    tracked_import_metadata_count = $pass2.tracked_import_metadata_count
    tracked_import_metadata = $pass2.tracked_import_metadata
    import_pass_1_2_path_set_parity = $pathParity
    import_pass_1_2_byte_parity = $byteParity
    import_pass_2_new_mutation_count = if ($pathParity -and $byteParity) { 0 } else { 1 }
    tracked_import_metadata_unknown_count = $unknownImports.Count
    tracked_import_associated_source_coverage_percent = if ($pass2.tracked_import_metadata_count -gt 0) { 100 } else { 0 }
    untracked_uid_count = $pass2.untracked_uid_count
    untracked_uid_path_set_sha256 = $pass2.untracked_uid_path_set_sha256
    untracked_uid_byte_map_sha256 = $pass2.untracked_uid_byte_map_sha256
    ignored_sidecar_count = $pass2.ignored_inventory.count
    ignored_sidecar_path_set_sha256 = $pass2.ignored_inventory.path_set_sha256
    class_cache_sha256 = $pass2.class_cache_sha256
    post_import_non_generated_tracked_delta = $pass2.non_generated_tracked_delta_count
    post_import_unknown_untracked_count = $pass2.unknown_untracked_count
    post_import_unknown_ignored_count = $pass2.ignored_inventory.unknown_count
    post_import_baseline_sealed = $baselineGreen
}
$baselinePath = Join-Path $script:Evidence 'post-import-authority-baseline.json'
Write-ImmutableJson $baselinePath $baseline

[pscustomobject][ordered]@{
    status = if ($baselineGreen) { 'PASS' } else { 'BLOCKED' }
    baseline_path = $baselinePath
    baseline_sha256 = Get-Sha256 $baselinePath
    tracked_import_metadata_count = $pass2.tracked_import_metadata_count
    import_pass_1_2_path_set_parity = $pathParity
    import_pass_1_2_byte_parity = $byteParity
    untracked_uid_count = $pass2.untracked_uid_count
    post_import_baseline_sealed = $baselineGreen
} | ConvertTo-Json -Depth 10

if (-not $baselineGreen) { exit 2 }
