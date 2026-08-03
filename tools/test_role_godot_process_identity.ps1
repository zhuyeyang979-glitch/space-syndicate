param(
    [string]$CommonScript = (Join-Path $PSScriptRoot "role_godot_mcp_common.ps1")
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. $CommonScript

$categories = [ordered]@{
    contract = [ordered]@{ passed = 0; total = 0 }
    property_matrix = [ordered]@{ passed = 0; total = 0 }
    pid_reuse = [ordered]@{ passed = 0; total = 0 }
    endpoint_binding = [ordered]@{ passed = 0; total = 0 }
}
$failures = [System.Collections.Generic.List[string]]::new()
$unhandled = 0

function Invoke-IdentityCase {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Body
    )

    $categories[$Category].total = [int]$categories[$Category].total + 1
    try {
        if ([bool](& $Body)) {
            $categories[$Category].passed = [int]$categories[$Category].passed + 1
        } else {
            $failures.Add("$Category|$Name|assertion_failed")
        }
    } catch {
        $script:unhandled += 1
        $failures.Add("$Category|$Name|unhandled=$($_.Exception.GetType().FullName):$($_.Exception.Message)")
    }
}

$relatedToolSources = @(
    $CommonScript,
    (Join-Path $PSScriptRoot "launch_role_godot_mcp.ps1"),
    (Join-Path $PSScriptRoot "invoke_role_godot_mcp.ps1"),
    (Join-Path $PSScriptRoot "stop_role_godot_mcp.ps1")
) | ForEach-Object { [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $_)) }
$commonSource = $relatedToolSources -join "`n"
$directFileNameAccessCount = [regex]::Matches(
    $commonSource,
    '(?i)\$(?:process|p)\.FileName|\.MainModule\.FileName'
).Count

$helperProcess = $null
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("role-godot-process-identity-{0}" -f [guid]::NewGuid().ToString("N"))
[System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
$helperPath = Join-Path $tempRoot "identity helper.ps1"
$helperSource = @'
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Remaining
)
Start-Sleep -Seconds 60
'@
[System.IO.File]::WriteAllText($helperPath, $helperSource, [System.Text.UTF8Encoding]::new($false))

try {
    $pwshPath = ConvertTo-McpNormalizedPath -Path ([string](Get-Process -Id $PID).Path)
    $projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
    $projectHeadSha = @(& git -C $projectPath rev-parse HEAD)[0]
    $sessionId = "offline-process-identity-contract"
    $argumentString = @(
        "-NoProfile",
        "-File", ('"' + $helperPath + '"'),
        "--path", ('"' + $projectPath + '"'),
        "--role-godot-mcp-session-id=$sessionId"
    ) -join " "
    $helperProcess = Start-Process `
        -FilePath $pwshPath `
        -ArgumentList $argumentString `
        -WorkingDirectory $projectPath `
        -PassThru `
        -WindowStyle Hidden
    Start-Sleep -Milliseconds 500
    $helperProcess.Refresh()
    $getProcessObject = Get-Process -Id $helperProcess.Id
    $cimRecords = @(Get-CimInstance Win32_Process -Filter "ProcessId=$($helperProcess.Id)")

    $realIdentity = New-RoleGodotProcessIdentityV3 `
        -Process $helperProcess `
        -Role "Supervisor" `
        -SessionId $sessionId `
        -ExpectedExecutablePath $pwshPath `
        -ProjectPath $projectPath `
        -ProjectHeadSha $projectHeadSha `
        -Endpoint "http://127.0.0.1:65534/" `
        -IdentityReadTimeoutMilliseconds 2000

    Invoke-IdentityCase contract "real_identity_verified" { $realIdentity.identity_verified }
    Invoke-IdentityCase contract "schema_v3" { $realIdentity.schema -eq "RoleGodotProcessIdentityV3" -and [int]$realIdentity.schema_version -eq 3 }
    Invoke-IdentityCase contract "complete_core_fields" {
        [int]$realIdentity.process_id -eq $helperProcess.Id `
            -and $realIdentity.process_creation_time.value -is [string] `
            -and [string]$realIdentity.process_creation_time.value -match '^[0-9]+$' `
            -and -not [string]::IsNullOrWhiteSpace([string]$realIdentity.observed_executable_path)
    }
    Invoke-IdentityCase contract "command_hash" { [string]$realIdentity.command_line_sha256 -match '^[0-9a-f]{64}$' }
    Invoke-IdentityCase contract "expected_observed_distinct_fields" {
        $realIdentity.Contains("expected_executable_path") `
            -and $realIdentity.Contains("observed_executable_path") `
            -and ([string]$realIdentity.expected_executable_path).Equals([string]$realIdentity.observed_executable_path, [System.StringComparison]::OrdinalIgnoreCase)
    }
    Invoke-IdentityCase contract "session_role_project_bound" {
        $realIdentity.session_id -eq $sessionId `
            -and $realIdentity.role -eq "Supervisor" `
            -and $realIdentity.project_head_sha -eq $projectHeadSha
    }
    Invoke-IdentityCase contract "json_round_trip" {
        $roundTrip = $realIdentity | ConvertTo-Json -Depth 8 | ConvertFrom-Json
        $roundTrip.schema -eq "RoleGodotProcessIdentityV3" `
            -and [int]$roundTrip.process_id -eq $helperProcess.Id `
            -and $roundTrip.command_line_sha256 -eq $realIdentity.command_line_sha256 `
            -and $roundTrip.process_creation_time.value -is [string] `
            -and $roundTrip.process_creation_time.value -eq $realIdentity.process_creation_time.value
    }
    Invoke-IdentityCase contract "no_direct_filename_access" { $directFileNameAccessCount -eq 0 }

    Invoke-IdentityCase property_matrix "start_process_type" { $helperProcess.GetType().FullName -eq "System.Diagnostics.Process" }
    Invoke-IdentityCase property_matrix "get_process_type" { $getProcessObject.GetType().FullName -eq "System.Diagnostics.Process" }
    Invoke-IdentityCase property_matrix "cim_type" { $cimRecords.Count -eq 1 -and $cimRecords[0].CimClass.CimClassName -eq "Win32_Process" }
    Invoke-IdentityCase property_matrix "direct_filename_missing" { $null -eq $helperProcess.PSObject.Properties["FileName"] }
    Invoke-IdentityCase property_matrix "path_present" { $null -ne $helperProcess.PSObject.Properties["Path"] -and -not [string]::IsNullOrWhiteSpace([string]$helperProcess.Path) }
    Invoke-IdentityCase property_matrix "cim_executable_path" { -not [string]::IsNullOrWhiteSpace([string]$cimRecords[0].ExecutablePath) }
    Invoke-IdentityCase property_matrix "cim_command_line" { ([string]$cimRecords[0].CommandLine).Contains("--role-godot-mcp-session-id=$sessionId") }
    Invoke-IdentityCase property_matrix "case_insensitive_path" {
        $resolved = Resolve-RoleGodotExecutableIdentity -Process $helperProcess -ExpectedExecutablePath $pwshPath.ToUpperInvariant() -CimProcess $cimRecords[0]
        $resolved.verified
    }
    Invoke-IdentityCase property_matrix "spaces_unicode_path" {
        $unicodePath = "C:\测试 Project\Godot Editor.exe"
        $binding = Test-McpCommandLineBinding `
            -CommandLine ('"C:\Godot.exe" --editor --path "C:\测试 Project" -- --role-godot-mcp-session-id=unicode-session') `
            -ProjectPath "C:\测试 Project" `
            -SessionId "unicode-session"
        $binding.verified -and (ConvertTo-McpNormalizedPath -Path $unicodePath).Contains("测试 Project")
    }
    Invoke-IdentityCase property_matrix "startinfo_only_fails_closed" {
        $fake = [pscustomobject]@{ StartInfo = [pscustomobject]@{ FileName = $pwshPath }; MainModule = $null }
        $resolved = Resolve-RoleGodotExecutableIdentity -Process $fake -ExpectedExecutablePath $pwshPath
        -not $resolved.verified `
            -and $resolved.failure_reason -eq "process_executable_path_unavailable" `
            -and ([string]$resolved.start_info_path).Equals($pwshPath, [System.StringComparison]::OrdinalIgnoreCase)
    }
    Invoke-IdentityCase property_matrix "throwing_mainmodule_fails_closed" {
        $fake = [pscustomobject]@{ StartInfo = [pscustomobject]@{ FileName = $pwshPath } }
        $fake | Add-Member -MemberType ScriptProperty -Name MainModule -Value { throw "module unavailable" }
        $resolved = Resolve-RoleGodotExecutableIdentity -Process $fake -ExpectedExecutablePath $pwshPath
        -not $resolved.verified -and $resolved.failure_reason -eq "process_executable_path_unavailable"
    }
    Invoke-IdentityCase property_matrix "wrong_executable_rejected" {
        $resolved = Resolve-RoleGodotExecutableIdentity -Process $helperProcess -ExpectedExecutablePath "C:\wrong\godot.exe" -CimProcess $cimRecords[0]
        -not $resolved.verified -and $resolved.failure_reason -eq "process_executable_path_mismatch"
    }
    Invoke-IdentityCase property_matrix "process_path_fallback" {
        $expected = "C:\Tools\Godot Editor.exe"
        $fake = [pscustomobject]@{ Path = $expected; MainModule = $null; StartInfo = [pscustomobject]@{ FileName = "" } }
        $fakeCimPath = [pscustomobject]@{ ExecutablePath = "" }
        $resolved = Resolve-RoleGodotExecutableIdentity -Process $fake -ExpectedExecutablePath $expected -CimProcess $fakeCimPath
        $resolved.verified -and $resolved.source -eq "system_diagnostics_process_path"
    }
    Invoke-IdentityCase property_matrix "mainmodule_fallback" {
        $expected = "C:\Tools\Godot Editor.exe"
        $fake = [pscustomobject]@{ MainModule = [pscustomobject]@{ FileName = $expected }; StartInfo = [pscustomobject]@{ FileName = "" } }
        $fakeCimPath = [pscustomobject]@{ ExecutablePath = "" }
        $resolved = Resolve-RoleGodotExecutableIdentity -Process $fake -ExpectedExecutablePath $expected -CimProcess $fakeCimPath
        $resolved.verified -and $resolved.source -eq "process_main_module_filename"
    }
    Invoke-IdentityCase property_matrix "unicode_executable_identity" {
        $expected = "C:\测试 Project\Godot Editor.exe"
        $fake = [pscustomobject]@{ MainModule = $null; StartInfo = [pscustomobject]@{ FileName = "" } }
        $fakeCimPath = [pscustomobject]@{ ExecutablePath = "C:\测试 Project\GODOT EDITOR.EXE" }
        $resolved = Resolve-RoleGodotExecutableIdentity -Process $fake -ExpectedExecutablePath $expected -CimProcess $fakeCimPath
        $resolved.verified -and $resolved.source -eq "win32_process_executable_path"
    }

    $fakeProcess = [pscustomobject]@{
        Id = 4242
        HasExited = $false
        StartTime = [DateTime]::UtcNow
        Path = $pwshPath
        MainModule = $null
        StartInfo = [pscustomobject]@{ FileName = $pwshPath }
    }
    $fakeSession = "synthetic-session"
    $fakeProjectPath = "C:\测试 Project"
    $fakeCommandLine = '"C:\pwsh.exe" --path "C:\测试 Project" --role-godot-mcp-session-id=synthetic-session'
    $fakeCim = [pscustomobject]@{
        ProcessId = 4242
        CreationDate = $fakeProcess.StartTime
        ExecutablePath = $pwshPath
        CommandLine = $fakeCommandLine
    }

    Invoke-IdentityCase pid_reuse "creation_time_mismatch" {
        $mismatchedCreation = ConvertTo-RoleGodotCreationTimeToken -CreationTime $fakeProcess.StartTime.AddSeconds(-1)
        $identity = New-RoleGodotProcessIdentityV3 `
            -Process $fakeProcess -Role Supervisor -SessionId $fakeSession -ExpectedExecutablePath $pwshPath `
            -ExpectedCreationTimeToken $mismatchedCreation.token `
            -ProjectPath $fakeProjectPath -ProjectHeadSha $projectHeadSha -Endpoint "http://127.0.0.1:1/" `
            -ProvidedCimProcess $fakeCim -UseProvidedCimProcess -IdentityReadTimeoutMilliseconds 0
        -not $identity.identity_verified -and $identity.failure_reason -eq "process_creation_time_mismatch"
    }
    Invoke-IdentityCase pid_reuse "already_exited" {
        $exited = $fakeProcess.PSObject.Copy()
        $exited.HasExited = $true
        $identity = New-RoleGodotProcessIdentityV3 `
            -Process $exited -Role Supervisor -SessionId $fakeSession -ExpectedExecutablePath $pwshPath `
            -ProjectPath $fakeProjectPath -ProjectHeadSha $projectHeadSha -Endpoint "http://127.0.0.1:1/" `
            -ProvidedCimProcess $fakeCim -UseProvidedCimProcess -IdentityReadTimeoutMilliseconds 0
        -not $identity.identity_verified -and $identity.failure_reason -eq "process_exited_before_identity"
    }
    Invoke-IdentityCase pid_reuse "cim_missing" {
        $identity = New-RoleGodotProcessIdentityV3 `
            -Process $fakeProcess -Role Supervisor -SessionId $fakeSession -ExpectedExecutablePath $pwshPath `
            -ProjectPath $fakeProjectPath -ProjectHeadSha $projectHeadSha -Endpoint "http://127.0.0.1:1/" `
            -ProvidedCimProcess $null -UseProvidedCimProcess -IdentityReadTimeoutMilliseconds 0
        -not $identity.identity_verified -and $identity.failure_reason -eq "process_exited_during_identity"
    }
    Invoke-IdentityCase pid_reuse "exited_during_path_read" {
        $exitsDuringRead = [pscustomobject]@{
            Id = 4242
            HasExited = $false
            StartTime = $fakeProcess.StartTime
            MainModule = $null
            StartInfo = [pscustomobject]@{ FileName = $pwshPath }
        }
        $exitsDuringRead | Add-Member -MemberType ScriptProperty -Name Path -Value { $this.HasExited = $true; throw "process exited" }
        $noExecutableCim = $fakeCim.PSObject.Copy()
        $noExecutableCim.ExecutablePath = ""
        $identity = New-RoleGodotProcessIdentityV3 `
            -Process $exitsDuringRead -Role Supervisor -SessionId $fakeSession -ExpectedExecutablePath $pwshPath `
            -ProjectPath $fakeProjectPath -ProjectHeadSha $projectHeadSha -Endpoint "http://127.0.0.1:1/" `
            -ProvidedCimProcess $noExecutableCim -UseProvidedCimProcess -IdentityReadTimeoutMilliseconds 0
        -not $identity.identity_verified -and $identity.failure_reason -eq "process_exited_during_identity"
    }
    Invoke-IdentityCase pid_reuse "cim_creation_not_authoritative" {
        $staleCim = $fakeCim.PSObject.Copy()
        $staleCim.CreationDate = $fakeProcess.StartTime.AddMinutes(-1)
        $identity = New-RoleGodotProcessIdentityV3 `
            -Process $fakeProcess -Role Supervisor -SessionId $fakeSession -ExpectedExecutablePath $pwshPath `
            -ProjectPath $fakeProjectPath -ProjectHeadSha $projectHeadSha -Endpoint "http://127.0.0.1:1/" `
            -ProvidedCimProcess $staleCim -UseProvidedCimProcess -IdentityReadTimeoutMilliseconds 0
        $identity.identity_verified -and $identity.failure_reason -eq "none"
    }
    Invoke-IdentityCase pid_reuse "cim_subsecond_not_authoritative" {
        $staleCim = $fakeCim.PSObject.Copy()
        $staleCim.CreationDate = $fakeProcess.StartTime.AddMilliseconds(900)
        $identity = New-RoleGodotProcessIdentityV3 `
            -Process $fakeProcess -Role Supervisor -SessionId $fakeSession -ExpectedExecutablePath $pwshPath `
            -ProjectPath $fakeProjectPath -ProjectHeadSha $projectHeadSha -Endpoint "http://127.0.0.1:1/" `
            -ProvidedCimProcess $staleCim -UseProvidedCimProcess -IdentityReadTimeoutMilliseconds 0
        $identity.identity_verified -and $identity.failure_reason -eq "none"
    }
    Invoke-IdentityCase pid_reuse "command_line_mismatch" {
        $badCim = $fakeCim.PSObject.Copy()
        $badCim.CommandLine = '"C:\pwsh.exe" --path "C:\other" --role-godot-mcp-session-id=synthetic-session'
        $identity = New-RoleGodotProcessIdentityV3 `
            -Process $fakeProcess -Role Supervisor -SessionId $fakeSession -ExpectedExecutablePath $pwshPath `
            -ProjectPath $fakeProjectPath -ProjectHeadSha $projectHeadSha -Endpoint "http://127.0.0.1:1/" `
            -ProvidedCimProcess $badCim -UseProvidedCimProcess -IdentityReadTimeoutMilliseconds 0
        -not $identity.identity_verified -and $identity.failure_reason -eq "process_command_line_mismatch"
    }
    Invoke-IdentityCase pid_reuse "all_paths_unavailable" {
        $noPathProcess = $fakeProcess.PSObject.Copy()
        $noPathProcess.PSObject.Properties.Remove("Path")
        $noPathCim = $fakeCim.PSObject.Copy()
        $noPathCim.ExecutablePath = ""
        $resolved = Resolve-RoleGodotExecutableIdentity -Process $noPathProcess -ExpectedExecutablePath $pwshPath -CimProcess $noPathCim
        -not $resolved.verified -and $resolved.failure_reason -eq "process_executable_path_unavailable"
    }
    Invoke-IdentityCase pid_reuse "malformed_pid" {
        $malformed = $fakeProcess.PSObject.Copy()
        $malformed.Id = "not-an-int"
        $identity = New-RoleGodotProcessIdentityV3 `
            -Process $malformed -Role Supervisor -SessionId $fakeSession -ExpectedExecutablePath $pwshPath `
            -ProjectPath $fakeProjectPath -ProjectHeadSha $projectHeadSha -Endpoint "http://127.0.0.1:1/" `
            -ProvidedCimProcess $fakeCim -UseProvidedCimProcess -IdentityReadTimeoutMilliseconds 0
        -not $identity.identity_verified -and $identity.failure_reason -eq "process_identity_incomplete"
    }
    Invoke-IdentityCase pid_reuse "start_time_unavailable" {
        $missingStart = [pscustomobject]@{ Id = 4242; HasExited = $false; Path = $pwshPath; MainModule = $null; StartInfo = [pscustomobject]@{ FileName = $pwshPath } }
        $missingStart | Add-Member -MemberType ScriptProperty -Name StartTime -Value { throw "start time unavailable" }
        $identity = New-RoleGodotProcessIdentityV3 `
            -Process $missingStart -Role Supervisor -SessionId $fakeSession -ExpectedExecutablePath $pwshPath `
            -ProjectPath $fakeProjectPath -ProjectHeadSha $projectHeadSha -Endpoint "http://127.0.0.1:1/" `
            -ProvidedCimProcess $fakeCim -UseProvidedCimProcess -IdentityReadTimeoutMilliseconds 0
        -not $identity.identity_verified -and $identity.failure_reason -eq "process_creation_time_source_unavailable"
    }
    Invoke-IdentityCase pid_reuse "disposed_process" {
        $disposed = Get-Process -Id $helperProcess.Id
        $disposed.Dispose()
        $identity = New-RoleGodotProcessIdentityV3 `
            -Process $disposed -Role Supervisor -SessionId $sessionId -ExpectedExecutablePath $pwshPath `
            -ProjectPath $projectPath -ProjectHeadSha $projectHeadSha -Endpoint "http://127.0.0.1:1/" `
            -ProvidedCimProcess $cimRecords[0] -UseProvidedCimProcess -IdentityReadTimeoutMilliseconds 0
        -not $identity.identity_verified -and $identity.failure_reason -ne "none"
    }
    Invoke-IdentityCase pid_reuse "cleanup_creation_time_guard" {
        $wrongCleanupCreation = ConvertTo-RoleGodotCreationTimeToken -CreationTime $helperProcess.StartTime.AddSeconds(-1)
        $cleanup = Stop-McpBoundProcess `
            -Process $helperProcess `
            -TimeoutSeconds 1 `
            -ExpectedCreationTimeToken $wrongCleanupCreation.token `
            -AllowForcedCleanup
        $helperProcess.Refresh()
        -not $cleanup.stopped -and $cleanup.failure_reason -eq "cleanup_pid_reused" -and -not $helperProcess.HasExited
    }

    Invoke-IdentityCase endpoint_binding "matching_owner" {
        $identity = New-RoleGodotProcessIdentityV3 `
            -Process $fakeProcess -Role Supervisor -SessionId $fakeSession -ExpectedExecutablePath $pwshPath `
            -ProjectPath $fakeProjectPath -ProjectHeadSha $projectHeadSha -Endpoint "http://127.0.0.1:12345/" `
            -ProvidedCimProcess $fakeCim -UseProvidedCimProcess -RequireEndpointOwner `
            -EndpointOwnerPidOverride 4242 -IdentityReadTimeoutMilliseconds 0
        $identity.identity_verified -and [int]$identity.endpoint_owner_pid -eq 4242
    }
    Invoke-IdentityCase endpoint_binding "wrong_owner" {
        $identity = New-RoleGodotProcessIdentityV3 `
            -Process $fakeProcess -Role Supervisor -SessionId $fakeSession -ExpectedExecutablePath $pwshPath `
            -ProjectPath $fakeProjectPath -ProjectHeadSha $projectHeadSha -Endpoint "http://127.0.0.1:12345/" `
            -ProvidedCimProcess $fakeCim -UseProvidedCimProcess -RequireEndpointOwner `
            -EndpointOwnerPidOverride 4243 -IdentityReadTimeoutMilliseconds 0
        -not $identity.identity_verified -and $identity.failure_reason -eq "endpoint_owner_pid_mismatch"
    }
    Invoke-IdentityCase endpoint_binding "missing_owner" {
        $identity = New-RoleGodotProcessIdentityV3 `
            -Process $fakeProcess -Role Supervisor -SessionId $fakeSession -ExpectedExecutablePath $pwshPath `
            -ProjectPath $fakeProjectPath -ProjectHeadSha $projectHeadSha -Endpoint "http://127.0.0.1:12345/" `
            -ProvidedCimProcess $fakeCim -UseProvidedCimProcess -RequireEndpointOwner `
            -EndpointOwnerPidOverride 0 -IdentityReadTimeoutMilliseconds 0
        -not $identity.identity_verified -and $identity.failure_reason -eq "endpoint_owner_pid_missing"
    }
    Invoke-IdentityCase endpoint_binding "missing_command_line" {
        $missingCommand = $fakeCim.PSObject.Copy()
        $missingCommand.CommandLine = ""
        $identity = New-RoleGodotProcessIdentityV3 `
            -Process $fakeProcess -Role Supervisor -SessionId $fakeSession -ExpectedExecutablePath $pwshPath `
            -ProjectPath $fakeProjectPath -ProjectHeadSha $projectHeadSha -Endpoint "http://127.0.0.1:12345/" `
            -ProvidedCimProcess $missingCommand -UseProvidedCimProcess -RequireEndpointOwner `
            -EndpointOwnerPidOverride 4242 -IdentityReadTimeoutMilliseconds 0
        -not $identity.identity_verified -and $identity.failure_reason -eq "process_command_line_unavailable"
    }
    Invoke-IdentityCase endpoint_binding "owner_changed_during_identity" {
        $identity = New-RoleGodotProcessIdentityV3 `
            -Process $fakeProcess -Role Supervisor -SessionId $fakeSession -ExpectedExecutablePath $pwshPath `
            -ProjectPath $fakeProjectPath -ProjectHeadSha $projectHeadSha -Endpoint "http://127.0.0.1:12345/" `
            -ProvidedCimProcess $fakeCim -UseProvidedCimProcess -RequireEndpointOwner `
            -EndpointOwnerPidBeforeOverride 4242 -EndpointOwnerPidAfterOverride 4243 -IdentityReadTimeoutMilliseconds 0
        -not $identity.identity_verified -and $identity.failure_reason -eq "endpoint_owner_pid_mismatch"
    }
    Invoke-IdentityCase endpoint_binding "connection_envelope_mismatch" {
        $inner = New-RoleGodotProcessIdentityV3 `
            -Process $fakeProcess -Role Supervisor -SessionId $fakeSession -ExpectedExecutablePath $pwshPath `
            -ProjectPath $fakeProjectPath -ProjectHeadSha $projectHeadSha -Endpoint "http://127.0.0.1:12345/" `
            -ProvidedCimProcess $fakeCim -UseProvidedCimProcess -RequireEndpointOwner `
            -EndpointOwnerPidOverride 4242 -IdentityReadTimeoutMilliseconds 0
        $connection = [pscustomobject]@{
            process_identity = $inner
            pid = 4243
            endpoint_owner_pid = 4242
            port = 12345
            session_id = $fakeSession
            role = "Supervisor"
            process_creation_time = $inner.process_creation_time
            godot_path = $inner.observed_executable_path
            worktree = $inner.project_path
            project_head_sha = $inner.project_head_sha
            endpoint = $inner.endpoint
        }
        $tested = Test-McpProcessIdentity -Connection $connection
        -not $tested.valid -and $tested.reason_code -eq "process_identity_incomplete"
    }
} finally {
    if ($null -ne $helperProcess) {
        try {
            $helperProcess.Refresh()
            if (-not $helperProcess.HasExited) {
                $helperProcess.Kill()
                $helperProcess.WaitForExit(5000) | Out-Null
            }
        } catch {
            $unhandled += 1
            $failures.Add("cleanup|helper_process|unhandled=$($_.Exception.Message)")
        }
        $helperProcess.Dispose()
    }
    if ([System.IO.Directory]::Exists($tempRoot)) {
        [System.IO.Directory]::Delete($tempRoot, $true)
    }
}

$totalPassed = 0
$totalCases = 0
foreach ($category in $categories.Values) {
    $totalPassed += [int]$category.passed
    $totalCases += [int]$category.total
}
$result = [ordered]@{
    schema = "RoleGodotProcessIdentityContractTestV1"
    status = if ($failures.Count -eq 0 -and $unhandled -eq 0) { "PASS" } else { "FAIL" }
    contract = "{0}/{1}" -f $categories.contract.passed, $categories.contract.total
    property_matrix = "{0}/{1}" -f $categories.property_matrix.passed, $categories.property_matrix.total
    pid_reuse = "{0}/{1}" -f $categories.pid_reuse.passed, $categories.pid_reuse.total
    endpoint_binding = "{0}/{1}" -f $categories.endpoint_binding.passed, $categories.endpoint_binding.total
    total = "{0}/{1}" -f $totalPassed, $totalCases
    unhandled_powershell_exception_count = $unhandled
    filename_direct_property_access_count_after = $directFileNameAccessCount
    failures = $failures.ToArray()
}
$result | ConvertTo-Json -Depth 8
if ($result.status -ne "PASS") {
    exit 1
}
