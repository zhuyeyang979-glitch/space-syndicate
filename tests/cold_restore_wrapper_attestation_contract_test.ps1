[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$modulePath = Join-Path $projectRoot "scripts/tools/cold_restore_attested_process.psm1"
$fixturePath = Join-Path $projectRoot "tests/fixtures/cold_restore_attestation_fixture_child.ps1"
$godotFixturePath = "res://tests/fixtures/cold_restore_godot_attestation_fixture.gd"
Import-Module $modulePath -Force

$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()
$repositoryHead = "d" * 40
$root = Join-Path ([IO.Path]::GetTempPath()) ("space syndicate wrapper 测试 " + [Guid]::NewGuid().ToString("N"))
[IO.Directory]::CreateDirectory($root) | Out-Null

function Assert-WrapperCondition {
    param([bool]$Condition, [string]$Message)
    $script:checks += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

function Invoke-FixtureCase {
    param(
        [Parameter(Mandatory = $true)][string]$Mode,
        [int]$TimeoutSeconds = 5,
        [string]$PathSuffix = ""
    )

    $runId = "wrapper-$Mode-$([Guid]::NewGuid().ToString('N'))"
    $caseRoot = Join-Path $root ("case $Mode $PathSuffix")
    if ($PathSuffix -ne "") {
        $caseRoot = Join-Path $caseRoot ("long-segment-" + ("x" * 80))
    }
    $childPath = Join-Path $caseRoot "child/qualification.completion.json"
    $parentPath = Join-Path $caseRoot "parent/qualification.exit.json"
    $stdoutPath = Join-Path $caseRoot "parent/qualification.stdout.log"
    $stderrPath = Join-Path $caseRoot "parent/qualification.stderr.log"
    $arguments = @(
        "-NoProfile",
        "-File", $fixturePath,
        "-ModulePath", $modulePath,
        "-RunId", $runId,
        "-Role", "qualification",
        "-RepositoryHead", $repositoryHead,
        "-ChildAttestationPath", $childPath,
        "-Mode", $Mode
    )
    $result = Invoke-ColdRestoreAttestedProcess `
        -ExecutablePath (Get-Command pwsh).Source `
        -WorkingDirectory $projectRoot `
        -ArgumentList $arguments `
        -RunId $runId `
        -Role "qualification" `
        -RepositoryHead $repositoryHead `
        -ChildAttestationPath $childPath `
        -ParentAttestationPath $parentPath `
        -StdoutPath $stdoutPath `
        -StderrPath $stderrPath `
        -TimeoutSeconds $TimeoutSeconds
    return [pscustomobject]@{
        result = $result
        run_id = $runId
        child_path = $childPath
        parent_path = $parentPath
        stdout_path = $stdoutPath
        stderr_path = $stderrPath
    }
}

try {
    $green = Invoke-FixtureCase "valid_green"
    Assert-WrapperCondition ([bool]$green.result.wrapper_exit_green) "valid child must produce a green wrapper"
    Assert-WrapperCondition ([bool]$green.result.parent.observed_exit -and [int]$green.result.parent.exit_code -eq 0) "parent must observe exact zero exit"
    Assert-WrapperCondition ([bool]$green.result.parent.child_attestation_valid) "parent must validate child completion"
    Assert-WrapperCondition ([int]$green.result.parent.task_owned_process_count_after -eq 0) "valid child must leave no task-owned process"
    Assert-WrapperCondition ((Get-FileHash $green.stdout_path -Algorithm SHA256).Hash.ToLowerInvariant() -eq [string]$green.result.parent.stdout_sha256) "stdout SHA-256 must bind the captured file"
    Assert-WrapperCondition ((Get-FileHash $green.stderr_path -Algorithm SHA256).Hash.ToLowerInvariant() -eq [string]$green.result.parent.stderr_sha256) "stderr SHA-256 must bind the captured file"

    $blocked = Invoke-FixtureCase "valid_blocked"
    Assert-WrapperCondition ([bool]$blocked.result.wrapper_exit_green) "product Queue blocker must keep the wrapper green"
    Assert-WrapperCondition (-not [bool]$blocked.result.child.qualification_green -and [int]$blocked.result.child.queue_count -eq 0) "blocked product result must remain explicit"
    Assert-WrapperCondition ([string]$blocked.result.child.product_blocker -eq "BLOCKED_BY_NO_LEGAL_QUEUE_ACCEPTANCE_SCENARIO") "blocked product result must carry the closed blocker"
    Assert-WrapperCondition ([int]$blocked.result.parent.exit_code -eq 0) "product blocker must exit zero"

    $expectedFaults = [ordered]@{
        missing = "child_attestation_missing"
        truncated = "child_attestation_json_invalid"
        wrong_schema = "child_attestation_schema_invalid"
        wrong_run_id = "child_attestation_run_id_mismatch"
        wrong_role = "child_attestation_role_mismatch"
        wrong_head = "child_attestation_repository_head_mismatch"
        wrong_fingerprint = "child_attestation_fingerprint_invalid"
        stale = "child_attestation_stale"
    }
    foreach ($mode in $expectedFaults.Keys) {
        $fault = Invoke-FixtureCase $mode
        Assert-WrapperCondition (-not [bool]$fault.result.wrapper_exit_green) "$mode must fail the wrapper"
        Assert-WrapperCondition ([string]$fault.result.wrapper_reason_code -eq [string]$expectedFaults[$mode]) "$mode must preserve its exact reason"
    }

    foreach ($mode in @("nonzero", "write_failure", "readback_failure")) {
        $fault = Invoke-FixtureCase $mode
        Assert-WrapperCondition (-not [bool]$fault.result.wrapper_exit_green -and [int]$fault.result.parent.exit_code -ne 0) "$mode must preserve a nonzero Harness exit"
        Assert-WrapperCondition ([string]$fault.result.wrapper_reason_code -eq "child_process_exit_nonzero") "$mode must be classified as a Harness process failure"
    }

    $timeout = Invoke-FixtureCase "timeout" 1
    Assert-WrapperCondition (-not [bool]$timeout.result.wrapper_exit_green -and [bool]$timeout.result.parent.timed_out) "timeout must be explicit"
    Assert-WrapperCondition ([bool]$timeout.result.parent.terminated_by_parent) "timeout must record parent termination"
    Assert-WrapperCondition ([int]$timeout.result.parent.task_owned_process_count_after -eq 0) "timeout cleanup must leave zero task-owned processes"

    $residual = Invoke-FixtureCase "residual"
    Assert-WrapperCondition (-not [bool]$residual.result.wrapper_exit_green) "a surviving descendant must fail the wrapper"
    Assert-WrapperCondition ([bool]$residual.result.parent.terminated_by_parent) "descendant cleanup must be recorded"
    Assert-WrapperCondition ([int]$residual.result.parent.task_owned_process_count_after -eq 0) "descendant cleanup must finish at zero"

    $pathCase = Invoke-FixtureCase "valid_green" 5 "中文 path"
    Assert-WrapperCondition ([bool]$pathCase.result.wrapper_exit_green) "space, Unicode, and long paths must round-trip"

    $exclusivePath = Join-Path $root "exclusive/official_claim_ledger.json"
    $exclusiveValue = [pscustomobject][ordered]@{ schema_version = 1; authorization_id = "fixture" }
    $exclusiveFingerprint = Write-ColdRestoreExclusiveJson $exclusivePath $exclusiveValue
    $exclusiveSecondWriteRejected = $false
    try {
        $null = Write-ColdRestoreExclusiveJson $exclusivePath ([pscustomobject]@{ attempted_run_id = "different-run-id" })
    }
    catch {
        $exclusiveSecondWriteRejected = $true
    }
    $exclusiveReadback = Get-Content -LiteralPath $exclusivePath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-WrapperCondition ($exclusiveFingerprint -match '^[0-9a-f]{64}$') "exclusive claim writer returns a stable SHA-256 fingerprint"
    Assert-WrapperCondition ($exclusiveSecondWriteRejected -and [string]$exclusiveReadback.authorization_id -eq "fixture") "a different RunId cannot mint or overwrite another authorization at the fixed claim path"

    $racePath = Join-Path $root "exclusive-race/official_claim_ledger.json"
    $raceStartTicks = [DateTime]::UtcNow.AddMilliseconds(500).Ticks.ToString([Globalization.CultureInfo]::InvariantCulture)
    $raceJobs = foreach ($raceRunId in @("run-id-alpha", "run-id-beta")) {
        Start-Job -ScriptBlock {
            param($ImportedModulePath, $TargetPath, $CandidateRunId, $StartTicks)
            Import-Module $ImportedModulePath -Force
            $startAt = [DateTime]::new([int64]$StartTicks, [DateTimeKind]::Utc)
            while ([DateTime]::UtcNow -lt $startAt) { Start-Sleep -Milliseconds 5 }
            try {
                $null = Write-ColdRestoreExclusiveJson $TargetPath ([pscustomobject][ordered]@{ schema_version = 1; run_id = $CandidateRunId })
                [pscustomobject]@{ run_id = $CandidateRunId; won = $true }
            }
            catch {
                [pscustomobject]@{ run_id = $CandidateRunId; won = $false }
            }
        } -ArgumentList $modulePath, $racePath, $raceRunId, $raceStartTicks
    }
    $raceResults = @($raceJobs | Wait-Job | Receive-Job)
    $raceJobs | Remove-Job -Force
    $raceWinner = Get-Content -LiteralPath $racePath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-WrapperCondition (@($raceResults | Where-Object { [bool]$_.won }).Count -eq 1 `
        -and @($raceResults | Where-Object { -not [bool]$_.won }).Count -eq 1 `
        -and [string]$raceWinner.run_id -in @("run-id-alpha", "run-id-beta")) "two different RunIds racing the fixed path consume exactly one authorization"

    $launchRunId = "wrapper-launch-$([Guid]::NewGuid().ToString('N'))"
    $launchRoot = Join-Path $root "launch-case"
    $launchChild = Join-Path $launchRoot "child/producer.completion.json"
    $launchParent = Join-Path $launchRoot "parent/producer.exit.json"
    $launchStdout = Join-Path $launchRoot "parent/producer.stdout.log"
    $launchStderr = Join-Path $launchRoot "parent/producer.stderr.log"
    $launchPath = Join-Path $launchRoot "launch/producer.authorized.json"
    $launchArguments = @(
        "-NoProfile",
        "-File", $fixturePath,
        "-ModulePath", $modulePath,
        "-RunId", $launchRunId,
        "-Role", "producer",
        "-RepositoryHead", $repositoryHead,
        "-ChildAttestationPath", $launchChild,
        "-Mode", "valid_green"
    )
    $launchContext = [pscustomobject][ordered]@{
        authorization_id = "alpha04c-p0-cold-restore-depth1-seed900626424-v1"
        claim_fingerprint = "a" * 64
        claim_nonce = "b" * 32
        source_head_sha = $repositoryHead
        scenario_fingerprint = "c" * 64
        run_id = $launchRunId
        process_role = "producer"
        launch_nonce = "d" * 32
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = ([Diagnostics.Process]::GetCurrentProcess().StartTime.ToUniversalTime().Ticks).ToString([Globalization.CultureInfo]::InvariantCulture)
    }
    $launchRun = Invoke-ColdRestoreAttestedProcess `
        -ExecutablePath (Get-Command pwsh).Source `
        -WorkingDirectory $projectRoot `
        -ArgumentList $launchArguments `
        -RunId $launchRunId `
        -Role "producer" `
        -RepositoryHead $repositoryHead `
        -ChildAttestationPath $launchChild `
        -ParentAttestationPath $launchParent `
        -StdoutPath $launchStdout `
        -StderrPath $launchStderr `
        -TimeoutSeconds 5 `
        -LaunchAttestationPath $launchPath `
        -LaunchAuthorization $launchContext
    $launchEvidence = Get-Content -LiteralPath $launchPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-WrapperCondition ([bool]$launchRun.wrapper_exit_green) "a launch-authorized child preserves ChildCompletionAttestationV1 and ParentExitAttestationV1"
    Assert-WrapperCondition ([int]$launchEvidence.wrapper_process_id -eq [int]$launchRun.parent.child_pid -and [int]$launchEvidence.engine_process_id -eq [int]$launchRun.parent.child_pid) "launch attestation binds the exact wrapper/engine process for a direct child"
    Assert-WrapperCondition ([int]$launchEvidence.orchestrator_process_id -eq $PID -and [string]$launchEvidence.launch_nonce -eq [string]$launchContext.launch_nonce) "launch attestation binds orchestrator identity and one role nonce"

    $engineArguments = New-ColdRestoreGodotArgumentList `
        -EngineArgumentList @("--headless", "--check-only", "--path", $projectRoot, "--script", "res://tests/smoke_test.gd") `
        -UserArgumentList @("--cold-restore-contract-only")
    $separatorIndex = [Array]::IndexOf($engineArguments, "--")
    $checkOnlyIndex = [Array]::IndexOf($engineArguments, "--check-only")
    Assert-WrapperCondition ($checkOnlyIndex -ge 0 -and $checkOnlyIndex -lt $separatorIndex) "--check-only must be before the user separator"
    $rejectedEngineArgument = $false
    try {
        $null = New-ColdRestoreGodotArgumentList -EngineArgumentList @("--headless") -UserArgumentList @("--check-only")
    }
    catch {
        $rejectedEngineArgument = $_.Exception.Message -eq "godot_engine_argument_after_separator"
    }
    Assert-WrapperCondition $rejectedEngineArgument "engine-only arguments after -- must fail closed"

    $godotCommand = (Get-Command godot -CommandType Application).Source
    $godotConsole = @(
        Get-ChildItem -LiteralPath (Split-Path -Parent $godotCommand) -Filter "Godot*_console.exe" -File
    )[0].FullName
    $godotRunId = "wrapper-godot-$([Guid]::NewGuid().ToString('N'))"
    $godotRoot = Join-Path $projectRoot ".godot/cold_restore_attestation_v1/$godotRunId"
    $godotLaunchPath = Join-Path $godotRoot "launch/qualification.authorized.json"
    $godotLaunchContext = [pscustomobject][ordered]@{
        authorization_id = "alpha04c-p0-cold-restore-depth1-seed900626424-v1"
        claim_fingerprint = "1" * 64
        claim_nonce = "2" * 32
        source_head_sha = $repositoryHead
        scenario_fingerprint = "3" * 64
        run_id = $godotRunId
        process_role = "qualification"
        launch_nonce = "4" * 32
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = ([Diagnostics.Process]::GetCurrentProcess().StartTime.ToUniversalTime().Ticks).ToString([Globalization.CultureInfo]::InvariantCulture)
    }
    $godotArguments = New-ColdRestoreGodotArgumentList `
        -EngineArgumentList @("--headless", "--path", $projectRoot, "--script", $godotFixturePath) `
        -UserArgumentList @("--fixture-run-id=$godotRunId", "--fixture-repository-head=$repositoryHead", "--cold-restore-launch-nonce=$($godotLaunchContext.launch_nonce)")
    $godotRun = Invoke-ColdRestoreAttestedProcess `
        -ExecutablePath $godotConsole `
        -WorkingDirectory $projectRoot `
        -ArgumentList $godotArguments `
        -RunId $godotRunId `
        -Role "qualification" `
        -RepositoryHead $repositoryHead `
        -ChildAttestationPath (Join-Path $godotRoot "child/qualification.completion.json") `
        -ParentAttestationPath (Join-Path $godotRoot "parent/qualification.exit.json") `
        -StdoutPath (Join-Path $godotRoot "parent/qualification.stdout.log") `
        -StderrPath (Join-Path $godotRoot "parent/qualification.stderr.log") `
        -TimeoutSeconds 10 `
        -LaunchAttestationPath $godotLaunchPath `
        -LaunchAuthorization $godotLaunchContext
    Assert-WrapperCondition ([bool]$godotRun.wrapper_exit_green) "real Godot console wrapper and engine child must complete one attested run"
    $enginePidMatch = [regex]::Match([string]$godotRun.stdout, 'GODOT_ATTESTATION_FIXTURE\|pid=(\d+)')
    $enginePid = if ($enginePidMatch.Success) { [int]$enginePidMatch.Groups[1].Value } else { 0 }
    Assert-WrapperCondition ($enginePid -gt 0 -and @($godotRun.observed_task_process_ids) -contains $enginePid) "parent must observe the real Godot engine PID behind the console wrapper"
    $godotLaunchEvidence = Get-Content -LiteralPath $godotLaunchPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-WrapperCondition ([int]$godotLaunchEvidence.engine_process_id -eq $enginePid `
        -and [int]$godotLaunchEvidence.wrapper_process_id -eq [int]$godotRun.parent.child_pid `
        -and [int]$godotLaunchEvidence.engine_process_id -ne [int]$godotLaunchEvidence.wrapper_process_id `
        -and [int]$godotLaunchEvidence.engine_parent_process_id -eq [int]$godotLaunchEvidence.wrapper_process_id) "real Godot launch attestation waits for and binds OS.get_process_id behind the console executable"
    Assert-WrapperCondition ([int]$godotRun.parent.task_owned_process_count_after -eq 0) "real console wrapper and engine must both exit"

    $duplicateRoot = Join-Path $root "duplicate"
    $duplicateChild = Join-Path $duplicateRoot "child/qualification.completion.json"
    [IO.Directory]::CreateDirectory((Split-Path -Parent $duplicateChild)) | Out-Null
    [IO.File]::WriteAllText($duplicateChild, "{}", [Text.UTF8Encoding]::new($false))
    $duplicateRun = "wrapper-duplicate-$([Guid]::NewGuid().ToString('N'))"
    $duplicateResult = Invoke-ColdRestoreAttestedProcess `
        -ExecutablePath (Get-Command pwsh).Source `
        -WorkingDirectory $projectRoot `
        -ArgumentList @("-NoProfile", "-Command", "exit 0") `
        -RunId $duplicateRun `
        -Role "qualification" `
        -RepositoryHead $repositoryHead `
        -ChildAttestationPath $duplicateChild `
        -ParentAttestationPath (Join-Path $duplicateRoot "parent/qualification.exit.json") `
        -StdoutPath (Join-Path $duplicateRoot "parent/stdout.log") `
        -StderrPath (Join-Path $duplicateRoot "parent/stderr.log") `
        -TimeoutSeconds 5
    Assert-WrapperCondition (-not [bool]$duplicateResult.wrapper_exit_green -and [string]$duplicateResult.wrapper_reason_code -eq "evidence_collision") "duplicate final attestation must fail before launch"

    if ($script:failures.Count -gt 0) {
        foreach ($failure in $script:failures) {
            Write-Error "WRAPPER ATTESTATION FAILURE: $failure"
        }
        exit 1
    }
    Write-Output "WRAPPER ATTESTATION PASS $script:checks checks"
    exit 0
}
finally {
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolvedRoot = [IO.Path]::GetFullPath($root)
    if ($resolvedRoot.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) `
        -and [IO.Directory]::Exists($resolvedRoot)) {
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    $godotEvidenceRoot = Join-Path $projectRoot ".godot/cold_restore_attestation_v1"
    if (Test-Path -LiteralPath $godotEvidenceRoot -PathType Container) {
        Get-ChildItem -LiteralPath $godotEvidenceRoot -Directory -Filter "wrapper-godot-*" | ForEach-Object {
            $resolvedCandidate = [IO.Path]::GetFullPath($_.FullName)
            $resolvedEvidenceRoot = [IO.Path]::GetFullPath($godotEvidenceRoot)
            if ($resolvedCandidate.StartsWith($resolvedEvidenceRoot, [StringComparison]::OrdinalIgnoreCase)) {
                Remove-Item -LiteralPath $resolvedCandidate -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
