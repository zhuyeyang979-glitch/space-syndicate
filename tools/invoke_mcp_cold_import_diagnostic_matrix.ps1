param(
    [string]$RepositoryRoot = (Get-Location).Path,
    [string]$TargetAddonSource = "E:\SpaceSyndicateWorkspace\worktrees\player-hand-zero-commit-a-exact-v3-3e73aaa8\addons\funplay_mcp",
    [string]$MirrorRoot = "E:\ss-mcp\cu2\m",
    [string]$RuntimeDataBase = "E:\ss-mcp\cu2\r",
    [string]$EvidenceRoot = "E:\ss-mcp\alpha04c-mcp-cold-unicode-attribution-v2",
    [string]$GodotPath = "C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe",
    [string]$C0Head = "794ccf010e661a4750efca20a4e0d2a5839b7f2b",
    [string]$C1Head = "510ebc3b1f80e6ef8a18e4e22b121dd9f5238337",
    [string]$C2Head = "3e73aaa8598ee0cfe3f9f97098db194679218f20",
    [string]$ExpectedTargetTree = "db25e364d38b91f4725655475c44145a349ab262"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "role_godot_mcp_common.ps1")
. (Join-Path $PSScriptRoot "role_godot_mcp_diagnostics.ps1")

function Write-McpMatrixJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Value
    )

    $directory = [System.IO.Path]::GetDirectoryName($Path)
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    $json = $Value | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-McpMatrixDirectoryManifest {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    $root = [System.IO.Path]::GetFullPath($Path).TrimEnd("\")
    $files = @(
        Get-ChildItem -Recurse -Force -File -LiteralPath $root | ForEach-Object {
            [ordered]@{
                path = $_.FullName.Substring($root.Length + 1).Replace("\", "/")
                length = $_.Length
                sha256 = Get-McpFileSha256Hex -Path $_.FullName
            }
        } | Sort-Object path
    )
    $canonical = $files | ConvertTo-Json -Depth 5 -Compress
    return [ordered]@{
        root = $root
        file_count = $files.Count
        files = $files
        manifest_sha256 = Get-McpByteSha256Hex -Bytes ([System.Text.Encoding]::UTF8.GetBytes($canonical))
    }
}

function Get-McpMatrixToolingRuntimeHash {
    $relativePaths = @(
        "tools/launch_role_godot_mcp.ps1",
        "tools/invoke_role_godot_mcp.ps1",
        "tools/stop_role_godot_mcp.ps1",
        "tools/role_godot_mcp_common.ps1",
        "tools/role_godot_mcp_diagnostics.ps1",
        "tools/invoke_mcp_cold_import_diagnostic_matrix.ps1"
    )
    $entries = foreach ($relativePath in $relativePaths) {
        $absolutePath = Join-Path $RepositoryRoot $relativePath
        if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
            throw "MCP_MATRIX_TOOLING_FILE_MISSING|path=$absolutePath"
        }
        [ordered]@{
            path = $relativePath
            sha256 = Get-McpFileSha256Hex -Path $absolutePath
        }
    }
    $canonical = @($entries) | ConvertTo-Json -Depth 5 -Compress
    return [ordered]@{
        schema = "McpToolingRuntimeBuildV1"
        files = @($entries)
        sha256 = Get-McpByteSha256Hex -Bytes ([System.Text.Encoding]::UTF8.GetBytes($canonical))
    }
}

function Invoke-McpMatrixTool {
    param(
        [Parameter(Mandatory = $true)][object]$Connection,
        [Parameter(Mandatory = $true)][string]$Name,
        [hashtable]$Arguments = @{},
        [int]$TimeoutSeconds = 30
    )

    $token = [System.IO.File]::ReadAllText([string]$Connection.token_path).Trim()
    $headers = @{
        "X-Funplay-MCP-Token" = $token
        "MCP-Protocol-Version" = "2025-11-25"
    }
    $body = @{
        jsonrpc = "2.0"
        id = [guid]::NewGuid().ToString("N")
        method = "tools/call"
        params = @{ name = $Name; arguments = $Arguments }
    } | ConvertTo-Json -Depth 30 -Compress
    $response = Invoke-RestMethod -Uri ([string]$Connection.endpoint) -Method Post -Headers $headers -ContentType "application/json" -Body $body -TimeoutSec $TimeoutSeconds
    $rpcError = Get-McpOptionalProperty -Object $response -Name "error"
    if ($null -ne $rpcError) {
        throw "MCP_MATRIX_RPC_ERROR|tool=$Name|error=$($rpcError | ConvertTo-Json -Depth 10 -Compress)"
    }
    $text = [string]$response.result.content[0].text
    try {
        return $text | ConvertFrom-Json
    } catch {
        return [ordered]@{ text = $text }
    }
}

function Wait-McpMatrixOperation {
    param(
        [Parameter(Mandatory = $true)][object]$Connection,
        [Parameter(Mandatory = $true)][string]$OperationId,
        [int]$TimeoutSeconds = 300
    )

    $deadline = [DateTimeOffset]::Now.AddSeconds($TimeoutSeconds)
    while ([DateTimeOffset]::Now -lt $deadline) {
        $identity = Test-McpProcessIdentity -Connection $Connection
        if (-not [bool]$identity.valid) {
            throw "MCP_MATRIX_EDITOR_EXITED|operation_id=$OperationId|reason=$($identity.reason_code)"
        }
        $status = Invoke-McpMatrixTool -Connection $Connection -Name filesystem_scan_status -Arguments @{ operation_id = $OperationId }
        if ([string]$status.operation.status -eq "completed" `
            -and [string]$status.state -eq "ready" `
            -and [bool]$status.import_quiescence_reached `
            -and [int]$status.known_reimport_depth -eq 0 `
            -and [int]$status.active_import_operation_total -eq 0) {
            return $status
        }
        if ([string]$status.operation.status -eq "failed" -or [string]$status.state -eq "failed") {
            throw "MCP_MATRIX_RELOAD_FAILED|operation_id=$OperationId"
        }
        Start-Sleep -Milliseconds 100
    }
    throw "MCP_MATRIX_RELOAD_TIMEOUT|operation_id=$OperationId"
}

function Get-McpMatrixLogFailureCounts {
    param(
        [Parameter(Mandatory = $true)][object]$Snapshot
    )

    $records = @($Snapshot.records)
    return [ordered]@{
        script_parse_error_count = @($records | Where-Object { [string]$_.category -eq "script_parse_error" }).Count
        failed_resource_load_count = @($records | Where-Object { [string]$_.category -eq "resource_load_error" }).Count
        runtime_error_count = @($records | Where-Object { [string]$_.category -eq "runtime_error" }).Count
    }
}

function New-McpMatrixMirror {
    param(
        [Parameter(Mandatory = $true)][string]$CellId,
        [Parameter(Mandatory = $true)][string]$Head
    )

    $mirrorPath = Join-Path $MirrorRoot $CellId.ToLowerInvariant()
    if (Test-Path -LiteralPath $mirrorPath) {
        throw "MCP_MATRIX_MIRROR_ALREADY_EXISTS|path=$mirrorPath"
    }
    & git -C $RepositoryRoot worktree add --detach $mirrorPath $Head | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "MCP_MATRIX_WORKTREE_CREATE_FAILED|cell=$CellId|head=$Head"
    }
    $actualHead = (& git -C $mirrorPath rev-parse HEAD).Trim()
    $sourceTree = (& git -C $mirrorPath show -s --format=%T HEAD).Trim()
    if ($actualHead -ne $Head) {
        throw "MCP_MATRIX_HEAD_MISMATCH|cell=$CellId|expected=$Head|actual=$actualHead"
    }
    $projectStatusBeforeOverlay = @(& git -C $mirrorPath status --short)
    $addonDestination = Join-Path $mirrorPath "addons\funplay_mcp"
    Get-ChildItem -Force -LiteralPath $TargetAddonSource | Copy-Item -Destination $addonDestination -Recurse -Force
    $sourceAddonManifest = Get-McpMatrixDirectoryManifest -Path $TargetAddonSource
    $mirrorAddonManifest = Get-McpMatrixDirectoryManifest -Path $addonDestination
    if ([string]$sourceAddonManifest.manifest_sha256 -ne [string]$mirrorAddonManifest.manifest_sha256) {
        throw "MCP_MATRIX_ADDON_OVERLAY_MISMATCH|cell=$CellId"
    }
    $statusBefore = @(& git -C $mirrorPath status --short)
    return [ordered]@{
        path = $mirrorPath
        project_head = $actualHead
        project_tree = $sourceTree
        source_status_before = $statusBefore
        project_status_before_overlay = $projectStatusBeforeOverlay
        addon_overlay_source = $TargetAddonSource
        addon_manifest = $mirrorAddonManifest
        cache_absent_before = -not (Test-Path -LiteralPath (Join-Path $mirrorPath ".godot"))
        control_absent_before = -not (Test-Path -LiteralPath (Join-Path $mirrorPath ".codex-godot"))
    }
}

function Invoke-McpMatrixCell {
    param(
        [Parameter(Mandatory = $true)][object]$Cell,
        [Parameter(Mandatory = $true)][object]$Environment,
        [Parameter(Mandatory = $true)][string[]]$ChangedScripts
    )

    $cellId = [string]$Cell.id
    $mirror = $Cell.mirror
    $cellEvidenceRoot = Join-Path $EvidenceRoot $cellId
    [System.IO.Directory]::CreateDirectory($cellEvidenceRoot) | Out-Null
    $connection = $null
    $stopResult = $null
    $cellFailure = ""
    $reloadStatus = $null
    $scriptDiscovery = $null
    $initialStatus = $null
    try {
        if (-not [bool]$mirror.cache_absent_before -or -not [bool]$mirror.control_absent_before) {
            throw "MCP_MATRIX_CACHE_NOT_FRESH|cell=$cellId"
        }
        if ((Get-McpEndpointOwnerPid -Port ([int]$Cell.port)) -ne 0) {
            throw "MCP_MATRIX_PORT_IN_USE|cell=$cellId|port=$($Cell.port)"
        }
        $launchJson = & (Join-Path $PSScriptRoot "launch_role_godot_mcp.ps1") `
            -Role Supervisor `
            -Port ([int]$Cell.port) `
            -Worktree ([string]$mirror.path) `
            -RuntimeDataBase $RuntimeDataBase `
            -GodotPath $GodotPath `
            -Renderer compatibility `
            -StartupTimeoutSeconds 300 `
            -RecoveryImportTimeoutSeconds 300 `
            -HttpTimeoutSeconds 3 `
            -InitialReadyStabilitySeconds 15 `
            -RequireFreshProjectCache $true `
            -SessionId ([string]$Cell.session_id) | Out-String
        $connection = $launchJson | ConvertFrom-Json
        $projectInfo = Invoke-McpMatrixTool -Connection $connection -Name get_project_info
        $initialStatus = Invoke-McpMatrixTool -Connection $connection -Name filesystem_scan_status
        if (-not [bool]$initialStatus.initial_scan_completed `
            -or [string]$initialStatus.state -ne "ready" `
            -or -not [bool]$initialStatus.import_quiescence_reached `
            -or [int]$initialStatus.known_reimport_depth -ne 0 `
            -or [int]$initialStatus.active_import_operation_total -ne 0) {
            throw "MCP_MATRIX_INITIAL_SCAN_NOT_READY|cell=$cellId"
        }
        $reloadRequestId = "alpha04c-cold-$($cellId.ToLowerInvariant())-reload-a1"
        $reloadRequest = Invoke-McpMatrixTool -Connection $connection -Name request_script_reload -Arguments @{ request_id = $reloadRequestId }
        $reloadStatus = Wait-McpMatrixOperation -Connection $connection -OperationId ([string]$reloadRequest.operation_id)
        $scriptDiscovery = Invoke-McpMatrixTool -Connection $connection -Name list_scripts -Arguments @{ path = "res://"; language = "gdscript"; recursive = $true; max_entries = 5000 }
        $discoveredPaths = @($scriptDiscovery.scripts | ForEach-Object { [string]$_.path })
        $expectedPresence = [ordered]@{}
        $discoveryMatchCount = 0
        foreach ($changedScript in $ChangedScripts) {
            & git -C $RepositoryRoot cat-file -e "$($Cell.head):$changedScript" 2>$null
            $expected = $LASTEXITCODE -eq 0
            $observed = ("res://$changedScript") -in $discoveredPaths
            $expectedPresence[$changedScript] = [ordered]@{ expected = $expected; observed = $observed; match = $expected -eq $observed }
            if ($expected -eq $observed) { $discoveryMatchCount += 1 }
        }
        $scriptDiscovery = [ordered]@{
            total_project_scripts = [int]$scriptDiscovery.count
            target_changed_scripts = $expectedPresence
            match_count = $discoveryMatchCount
            total = $ChangedScripts.Count
            green = $discoveryMatchCount -eq $ChangedScripts.Count
        }
        if (-not [bool]$scriptDiscovery.green) {
            throw "MCP_MATRIX_SCRIPT_DISCOVERY_MISMATCH|cell=$cellId"
        }
        $reportedProjectRoot = ([string]$projectInfo.project_root).Replace("/", "\").TrimEnd("\")
        if (-not $reportedProjectRoot.Equals(([string]$mirror.path).TrimEnd("\"), [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "MCP_MATRIX_PROJECT_ROOT_MISMATCH|cell=$cellId"
        }
    } catch {
        $cellFailure = $_.Exception.Message
    } finally {
        if ($null -ne $connection) {
            try {
                $stopJson = & (Join-Path $PSScriptRoot "stop_role_godot_mcp.ps1") -Worktree ([string]$mirror.path) -RequestId "alpha04c-cold-$($cellId.ToLowerInvariant())-stop-a1" -ShutdownTimeoutSeconds 20 -AllowForcedCleanup $true | Out-String
                $stopResult = $stopJson | ConvertFrom-Json
            } catch {
                if ($cellFailure -eq "") { $cellFailure = $_.Exception.Message }
            }
        }
    }

    $sessionRoot = Join-Path ([string]$mirror.path) ".codex-godot\sessions\$($Cell.session_id)"
    $logsRoot = Join-Path $sessionRoot "logs"
    $editorStderr = Get-McpRawLogSnapshot -Path (Join-Path $logsRoot "editor.stderr.log") -SourceStream editor_stderr -Stage startup_initial_filesystem_scan_before_endpoint_readiness
    $recoveryStderr = Get-McpRawLogSnapshot -Path (Join-Path $logsRoot "recovery-import.stderr.log") -SourceStream recovery_import_stderr -Stage recovery_cold_import
    $godotLog = Get-McpRawLogSnapshot -Path (Join-Path $logsRoot "godot.log") -SourceStream godot_log -Stage editor_lifecycle
    $recoveryGodotLog = Get-McpRawLogSnapshot -Path (Join-Path $logsRoot "recovery-import.godot.log") -SourceStream recovery_import_godot_log -Stage recovery_cold_import
    $mirrorCoverage = Compare-McpDiagnosticMirrorCoverageV2 `
        -AuthoritativeDiagnostics @($editorStderr.diagnostics + $recoveryStderr.diagnostics) `
        -MirrorDiagnostics @($godotLog.diagnostics + $recoveryGodotLog.diagnostics)
    $editorFailureCounts = Get-McpMatrixLogFailureCounts -Snapshot $editorStderr
    $recoveryFailureCounts = Get-McpMatrixLogFailureCounts -Snapshot $recoveryStderr
    $statusAfter = @(& git -C ([string]$mirror.path) status --short)
    $headAfter = (& git -C ([string]$mirror.path) rev-parse HEAD).Trim()
    $treeAfter = (& git -C ([string]$mirror.path) show -s --format=%T HEAD).Trim()
    $attempt = [ordered]@{
        schema = "McpColdImportDiagnosticAttemptV2"
        cell_id = $cellId
        session_id = [string]$Cell.session_id
        port = [int]$Cell.port
        project_head = [string]$Cell.head
        expected_project_head = [string]$Cell.head
        project_head_match = $headAfter -eq [string]$Cell.head
        project_tree = $treeAfter
        expected_project_tree = [string]$mirror.project_tree
        project_tree_match = $treeAfter -eq [string]$mirror.project_tree
        source_commit_is_ancestor_of_target = [bool]$Cell.ancestor
        source_status_before = @($mirror.source_status_before)
        source_status_after = $statusAfter
        cache_was_fresh = [bool]$mirror.cache_absent_before
        unique_cache_id = [string]$Cell.session_id
        environment = $Environment
        initial_scan_green = $null -ne $initialStatus -and [bool]$initialStatus.initial_scan_completed -and [string]$initialStatus.state -eq "ready"
        import_quiescence_green = $null -ne $initialStatus `
            -and [bool]$initialStatus.import_quiescence_reached `
            -and [int]$initialStatus.known_reimport_depth -eq 0 `
            -and [int]$initialStatus.active_import_operation_total -eq 0 `
            -and $null -ne $reloadStatus `
            -and [bool]$reloadStatus.import_quiescence_reached
        import_quiescence_stable_window_msec = if ($null -ne $initialStatus) { [int]$initialStatus.import_quiescence_stable_window_msec } else { 0 }
        import_quiescence_timeout_msec = if ($null -ne $initialStatus) { [int]$initialStatus.import_quiescence_timeout_msec } else { 0 }
        initial_quiescence_reached_count = if ($null -ne $initialStatus) { [int]$initialStatus.import_quiescence_reached_count } else { 0 }
        reload_quiescence_reached_count = if ($null -ne $reloadStatus) { [int]$reloadStatus.import_quiescence_reached_count } else { 0 }
        project_reload_green = $null -ne $reloadStatus -and [string]$reloadStatus.operation.status -eq "completed"
        script_discovery_green = $null -ne $scriptDiscovery -and [bool]$scriptDiscovery.green
        script_discovery = $scriptDiscovery
        editor_stderr = $editorStderr
        recovery_import_stderr = $recoveryStderr
        godot_log_independent_mirror = $godotLog
        recovery_import_godot_log_independent_mirror = $recoveryGodotLog
        diagnostic_mirror_coverage = $mirrorCoverage
        editor_unicode_diagnostic_count = @($editorStderr.diagnostics | Where-Object { [string]$_.category -eq "unicode_nul_diagnostic" }).Count
        recovery_unicode_diagnostic_count = @($recoveryStderr.diagnostics | Where-Object { [string]$_.category -eq "unicode_nul_diagnostic" }).Count
        unicode_diagnostic_count = @($editorStderr.diagnostics + $recoveryStderr.diagnostics | Where-Object { [string]$_.category -eq "unicode_nul_diagnostic" }).Count
        raw_nul_count = [int]$editorStderr.raw_nul_count + [int]$recoveryStderr.raw_nul_count
        script_parse_error_count = [int]$editorFailureCounts.script_parse_error_count + [int]$recoveryFailureCounts.script_parse_error_count
        failed_resource_load_count = [int]$editorFailureCounts.failed_resource_load_count + [int]$recoveryFailureCounts.failed_resource_load_count
        runtime_error_count = [int]$editorFailureCounts.runtime_error_count + [int]$recoveryFailureCounts.runtime_error_count
        reimport_conflict_count = @($editorStderr.diagnostics + $recoveryStderr.diagnostics | Where-Object {
            [bool](Get-McpDiagnosticObjectValueV2 -Object $_ -Name "reimport_conflict_correlated" -Default $false)
        }).Count
        stopped_cleanly = $null -ne $stopResult -and [bool]$stopResult.stopped -and [bool]$stopResult.clean_stop
        editor_exit_code = if ($null -ne $stopResult) { $stopResult.editor_exit_code } else { $null }
        process_count_after = if ($null -ne $stopResult) { [int]$stopResult.task_process_count_after } else { 1 }
        endpoint_count_after = if ((Get-McpEndpointOwnerPid -Port ([int]$Cell.port)) -eq 0) { 0 } else { 1 }
        failure = $cellFailure
    }
    Write-McpMatrixJson -Path (Join-Path $cellEvidenceRoot "attempt.json") -Value $attempt
    if ($cellFailure -ne "") {
        throw "MCP_MATRIX_CELL_FAILED|cell=$cellId|reason=$cellFailure"
    }
    if (-not [bool]$attempt.stopped_cleanly -or [int]$attempt.process_count_after -ne 0 -or [int]$attempt.endpoint_count_after -ne 0) {
        throw "MCP_MATRIX_CELL_CLEANUP_FAILED|cell=$cellId"
    }
    return $attempt
}

$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path.TrimEnd("\")
$TargetAddonSource = (Resolve-Path -LiteralPath $TargetAddonSource).Path.TrimEnd("\")
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
foreach ($path in @($MirrorRoot, $RuntimeDataBase, $EvidenceRoot)) {
    if (Test-Path -LiteralPath $path) {
        throw "MCP_MATRIX_OUTPUT_ALREADY_EXISTS|path=$path"
    }
}
foreach ($sha in @($C0Head, $C1Head, $C2Head)) {
    $objectType = (& git -C $RepositoryRoot cat-file -t $sha).Trim()
    if ($LASTEXITCODE -ne 0 -or $objectType -ne "commit") { throw "MCP_MATRIX_COMMIT_MISSING|sha=$sha" }
}
$actualTargetTree = (& git -C $RepositoryRoot show -s --format=%T $C2Head).Trim()
if ($actualTargetTree -ne $ExpectedTargetTree) {
    throw "MCP_MATRIX_TARGET_TREE_MISMATCH|expected=$ExpectedTargetTree|actual=$actualTargetTree"
}
[System.IO.Directory]::CreateDirectory($MirrorRoot) | Out-Null
[System.IO.Directory]::CreateDirectory($RuntimeDataBase) | Out-Null
[System.IO.Directory]::CreateDirectory($EvidenceRoot) | Out-Null

$toolingRuntime = Get-McpMatrixToolingRuntimeHash
$godotSha = Get-McpFileSha256Hex -Path $GodotPath
$godotVersion = (& $GodotPath --version | Select-Object -First 1).Trim()
$addonTree = [string](Get-McpMatrixDirectoryManifest -Path $TargetAddonSource).manifest_sha256
$launchTemplate = [ordered]@{
    role = "Supervisor"
    renderer = "compatibility"
    recovery = @("--import", "--recovery-mode", "--path", "<PROJECT_ROOT>", "--log-file", "<LOG_PATH>", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--role-godot-mcp-session-id=<SESSION_ID>-recovery-import", "--role-godot-mcp-role=Supervisor-recovery-import")
    editor = @("--editor", "--path", "<PROJECT_ROOT>", "--log-file", "<LOG_PATH>", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--resolution", "1600x960", "--position", "40,40", "--", "--role-godot-mcp-session-id=<SESSION_ID>", "--role-godot-mcp-role=Supervisor", "--role-godot-mcp-project-head=<PROJECT_HEAD>")
}
$launchTemplateHash = Get-McpByteSha256Hex -Bytes ([System.Text.Encoding]::UTF8.GetBytes(($launchTemplate | ConvertTo-Json -Depth 8 -Compress)))
$environment = [ordered]@{
    godot_executable_sha256 = $godotSha
    godot_version = $godotVersion
    tooling_runtime_build_sha256 = [string]$toolingRuntime.sha256
    mcp_addon_tree = $addonTree
    launch_arguments_sha256 = $launchTemplateHash
    locale = [System.Globalization.CultureInfo]::CurrentCulture.Name
    ui_locale = [System.Globalization.CultureInfo]::CurrentUICulture.Name
    powershell_version = $PSVersionTable.PSVersion.ToString()
    powershell_edition = [string]$PSVersionTable.PSEdition
    platform = "windows"
    capture_backend = "start_process_win32_inherited_file_handle_v1"
    renderer = "compatibility"
    rendering_method = "gl_compatibility"
    rendering_driver = "opengl3"
    startup_timeout_seconds = 300
    recovery_import_timeout_seconds = 300
    http_timeout_seconds = 3
    initial_ready_stability_seconds = 15
    cache_layout = "fresh_external_ephemeral_mirror_v1"
}

$changedScripts = @(
    "scripts/runtime/player_hand_interaction_runtime_service.gd",
    "tests/card_inventory_bench_discardability_migration_test.gd",
    "tests/card_inventory_discardability_typed_query_contract_test.gd"
)
$cellDefinitions = @(
    [ordered]@{ id = "C0_MAIN_A"; head = $C0Head; port = 28920; session_id = "alpha04c-quiescence-c0-main-a" },
    [ordered]@{ id = "C1_PARENT_A"; head = $C1Head; port = 28921; session_id = "alpha04c-quiescence-c1-parent-a" },
    [ordered]@{ id = "C2_TARGET_A"; head = $C2Head; port = 28922; session_id = "alpha04c-quiescence-c2-target-a" },
    [ordered]@{ id = "C1_PARENT_B"; head = $C1Head; port = 28923; session_id = "alpha04c-quiescence-c1-parent-b" },
    [ordered]@{ id = "C2_TARGET_B"; head = $C2Head; port = 28924; session_id = "alpha04c-quiescence-c2-target-b" }
)
foreach ($cell in $cellDefinitions) {
    & git -C $RepositoryRoot merge-base --is-ancestor ([string]$cell.head) $C2Head
    $cell["ancestor"] = $LASTEXITCODE -eq 0
    $cell["mirror"] = New-McpMatrixMirror -CellId ([string]$cell.id) -Head ([string]$cell.head)
}

$matrixManifest = [ordered]@{
    schema = "McpColdImportDiagnosticMatrixRunV3"
    task_id = "ALPHA_0_4_C_MCP_IMPORT_QUIESCENCE_REIMPORT_CONFLICT_AND_UNICODE_PHASE_ATTRIBUTION_REPAIR"
    attempt_count = 5
    sequential = $true
    environment = $environment
    tooling_runtime = $toolingRuntime
    launch_argument_template = $launchTemplate
    changed_scripts = $changedScripts
    cells = $cellDefinitions
}
Write-McpMatrixJson -Path (Join-Path $EvidenceRoot "matrix_manifest.json") -Value $matrixManifest

$attempts = [System.Collections.Generic.List[object]]::new()
foreach ($cell in $cellDefinitions) {
    $attempts.Add((Invoke-McpMatrixCell -Cell $cell -Environment $environment -ChangedScripts $changedScripts))
}
$comparison = Compare-McpColdImportDiagnosticAttemptsV3 `
    -C0 $attempts[0] `
    -C1A $attempts[1] `
    -C2A $attempts[2] `
    -C1B $attempts[3] `
    -C2B $attempts[4] `
    -ChangedFiles $changedScripts
Write-McpMatrixJson -Path (Join-Path $EvidenceRoot "comparison.json") -Value $comparison
Write-McpMatrixJson -Path (Join-Path $EvidenceRoot "baseline_manifest.json") -Value $comparison.baseline_manifest

$result = [ordered]@{
    schema = "McpColdImportDiagnosticMatrixResultV3"
    green = [bool]$comparison.valid -and [bool]$comparison.green -and [bool]$comparison.target_gate.green
    evidence_root = $EvidenceRoot
    environment = $environment
    attempts = $attempts.ToArray()
    comparison = $comparison
    target_classifications = $comparison.target_classifications
    target_gate = $comparison.target_gate
}
Write-McpMatrixJson -Path (Join-Path $EvidenceRoot "result.json") -Value $result
$result | ConvertTo-Json -Depth 30
if (-not [bool]$result.green) {
    exit 1
}
