[CmdletBinding()]
param(
    [switch]$FixtureChild,
    [string]$ModulePath = "",
    [string]$RunId = "",
    [string]$Role = "",
    [string]$RepositoryHead = "",
    [string]$ChildAttestationPath = "",
    [string]$LaunchMarkerPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($FixtureChild) {
    Import-Module $ModulePath -Force
    [IO.Directory]::CreateDirectory((Split-Path -Parent $LaunchMarkerPath)) | Out-Null
    [IO.File]::WriteAllText($LaunchMarkerPath, "child-launched", [Text.UTF8Encoding]::new($false))
    $child = New-ColdRestoreChildCompletionFixture `
        -RunId $RunId `
        -Role $Role `
        -RepositoryHead $RepositoryHead
    Write-ColdRestoreAtomicJson $ChildAttestationPath $child | Out-Null
    exit 0
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$modulePath = Join-Path $projectRoot "scripts/tools/cold_restore_attested_process.psm1"
Import-Module $modulePath -Force

$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()
$repositoryHead = "d" * 40
$scenarioFingerprint = "a" * 64
$role = "producer"
$root = Join-Path ([IO.Path]::GetTempPath()) (
    "space-syndicate-launch-authorization-binding-" + [Guid]::NewGuid().ToString("N")
)
[IO.Directory]::CreateDirectory($root) | Out-Null

function Assert-BindingCondition {
    param([bool]$Condition, [string]$Message)

    $script:checks += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

function Get-CurrentMicrosecondCreationTicks {
    $process = $null
    try {
        $process = [Diagnostics.Process]::GetCurrentProcess()
        $ticks = $process.StartTime.ToUniversalTime().Ticks
        return ($ticks - ($ticks % 10)).ToString([Globalization.CultureInfo]::InvariantCulture)
    }
    finally {
        if ($null -ne $process) {
            $process.Dispose()
        }
    }
}

function New-LaunchAuthorizationFixture {
    param([Parameter(Mandatory = $true)][string]$FixtureRunId)

    return [pscustomobject][ordered]@{
        authorization_id = "alpha04c-p0-cold-restore-depth1-seed900626424-v1"
        claim_fingerprint = "1" * 64
        claim_nonce = "2" * 32
        source_head_sha = $repositoryHead
        scenario_fingerprint = $scenarioFingerprint
        run_id = $FixtureRunId
        process_role = $role
        launch_nonce = "3" * 32
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = Get-CurrentMicrosecondCreationTicks
    }
}

function Get-FixturePaths {
    param([Parameter(Mandatory = $true)][string]$Name)

    $caseRoot = Join-Path $root $Name
    return [pscustomobject]@{
        child = Join-Path $caseRoot "child/producer.completion.json"
        parent = Join-Path $caseRoot "parent/producer.exit.json"
        stdout = Join-Path $caseRoot "parent/producer.stdout.log"
        stderr = Join-Path $caseRoot "parent/producer.stderr.log"
        launch = Join-Path $caseRoot "launch/producer.authorized.json"
        marker = Join-Path $caseRoot "child/launch.marker"
    }
}

function Invoke-LaunchAuthorizationFixture {
    param(
        [Parameter(Mandatory = $true)][string]$CaseName,
        [Parameter(Mandatory = $true)]$Authorization
    )

    $paths = Get-FixturePaths $CaseName
    $arguments = @(
        "-NoProfile",
        "-File", $PSCommandPath,
        "-FixtureChild",
        "-ModulePath", $modulePath,
        "-RunId", $CaseName,
        "-Role", $role,
        "-RepositoryHead", $repositoryHead,
        "-ChildAttestationPath", $paths.child,
        "-LaunchMarkerPath", $paths.marker
    )
    $result = Invoke-ColdRestoreAttestedProcess `
        -ExecutablePath (Get-Command pwsh).Source `
        -WorkingDirectory $projectRoot `
        -ArgumentList $arguments `
        -RunId $CaseName `
        -Role $role `
        -RepositoryHead $repositoryHead `
        -ChildAttestationPath $paths.child `
        -ParentAttestationPath $paths.parent `
        -StdoutPath $paths.stdout `
        -StderrPath $paths.stderr `
        -TimeoutSeconds 5 `
        -LaunchAttestationPath $paths.launch `
        -LaunchAuthorization $Authorization `
        -ExpectedScenarioFingerprint $scenarioFingerprint
    return [pscustomobject]@{ result = $result; paths = $paths }
}

function Assert-MismatchRejectedBeforeLaunch {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Field,
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$ExpectedReason
    )

    $authorization = New-LaunchAuthorizationFixture $Name
    $authorization.$Field = $Value
    $paths = Get-FixturePaths $Name
    $reason = ""
    try {
        $null = Invoke-LaunchAuthorizationFixture $Name $authorization
    }
    catch {
        $reason = $_.Exception.Message
    }
    Assert-BindingCondition ($reason -ceq $ExpectedReason) "$Name must reject with $ExpectedReason"
    Assert-BindingCondition (-not [IO.File]::Exists($paths.marker)) "$Name must reject before child launch"
    Assert-BindingCondition (-not [IO.File]::Exists($paths.launch)) "$Name must not write launch attestation"
    Assert-BindingCondition (-not [IO.File]::Exists($paths.child)) "$Name must not write child attestation"
}

function Assert-MalformedChildCompletionRejected {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Field,
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$ExpectedReason
    )

    $runId = "malformed-$Name"
    $candidate = New-ColdRestoreChildCompletionFixture `
        -RunId $runId `
        -Role $role `
        -RepositoryHead $repositoryHead
    $candidate.$Field = $Value
    $path = Join-Path $root "malformed/$Name/producer.completion.json"
    Write-ColdRestoreAtomicJson $path $candidate | Out-Null
    $validation = Test-ColdRestoreChildCompletionAttestation `
        -Path $path `
        -ExpectedRunId $runId `
        -ExpectedRole $role `
        -ExpectedRepositoryHead $repositoryHead `
        -ProcessStartedAtUtc ([DateTime]::UtcNow.AddSeconds(-1)) `
        -ExpectedScenarioFingerprint $scenarioFingerprint
    Assert-BindingCondition (-not [bool]$validation.valid) "$Name must be rejected"
    Assert-BindingCondition ([string]$validation.reason_code -ceq $ExpectedReason) "$Name must return $ExpectedReason"
}

try {
    Assert-MismatchRejectedBeforeLaunch `
        -Name "run-id-mismatch" `
        -Field "run_id" `
        -Value "different-run-id" `
        -ExpectedReason "launch_authorization_run_id_mismatch"
    Assert-MismatchRejectedBeforeLaunch `
        -Name "source-head-mismatch" `
        -Field "source_head_sha" `
        -Value ("e" * 40) `
        -ExpectedReason "launch_authorization_source_head_mismatch"
    Assert-MismatchRejectedBeforeLaunch `
        -Name "process-role-mismatch" `
        -Field "process_role" `
        -Value "consumer" `
        -ExpectedReason "launch_authorization_process_role_mismatch"
    Assert-MismatchRejectedBeforeLaunch `
        -Name "scenario-mismatch" `
        -Field "scenario_fingerprint" `
        -Value ("b" * 64) `
        -ExpectedReason "launch_authorization_scenario_fingerprint_mismatch"
    Assert-MismatchRejectedBeforeLaunch `
        -Name "orchestrator-pid-mismatch" `
        -Field "orchestrator_process_id" `
        -Value ($PID + 1) `
        -ExpectedReason "launch_orchestrator_process_mismatch"
    $wrongCreationTicks = ([int64](Get-CurrentMicrosecondCreationTicks) + 10).ToString(
        [Globalization.CultureInfo]::InvariantCulture
    )
    Assert-MismatchRejectedBeforeLaunch `
        -Name "orchestrator-creation-mismatch" `
        -Field "orchestrator_creation_time_utc_ticks" `
        -Value $wrongCreationTicks `
        -ExpectedReason "launch_orchestrator_creation_time_mismatch"

    $malformedChildCases = @(
        [pscustomobject]@{ name = "string-schema"; field = "schema_version"; value = "1"; reason = "child_attestation_schema_invalid" },
        [pscustomobject]@{ name = "string-official"; field = "official"; value = "false"; reason = "child_attestation_boolean_invalid" },
        [pscustomobject]@{ name = "string-formal"; field = "formal"; value = "false"; reason = "child_attestation_boolean_invalid" },
        [pscustomobject]@{ name = "string-green"; field = "qualification_green"; value = "true"; reason = "child_attestation_boolean_invalid" },
        [pscustomobject]@{ name = "string-save-written"; field = "save_written"; value = "false"; reason = "child_attestation_boolean_invalid" },
        [pscustomobject]@{ name = "string-official-count"; field = "official_count_consumed"; value = "false"; reason = "child_attestation_boolean_invalid" },
        [pscustomobject]@{ name = "string-queue-count"; field = "queue_count"; value = "1"; reason = "child_attestation_integer_invalid" },
        [pscustomobject]@{ name = "string-queue-revision"; field = "queue_revision"; value = "1"; reason = "child_attestation_integer_invalid" },
        [pscustomobject]@{ name = "negative-product-mutation"; field = "product_mutation_count"; value = -1; reason = "child_attestation_integer_invalid" },
        [pscustomobject]@{ name = "negative-authority-mutation"; field = "direct_authority_mutation_count"; value = -1; reason = "child_attestation_integer_invalid" },
        [pscustomobject]@{ name = "negative-queue-injection"; field = "queue_injection_count"; value = -1; reason = "child_attestation_integer_invalid" },
        [pscustomobject]@{ name = "invalid-target-fingerprint"; field = "queue_trigger_target_fingerprint"; value = ("g" * 64); reason = "child_attestation_target_fingerprint_invalid" },
        [pscustomobject]@{ name = "oversized-final-reason"; field = "final_reason_code"; value = ("r" * 300); reason = "child_attestation_text_invalid" }
    )
    foreach ($case in $malformedChildCases) {
        Assert-MalformedChildCompletionRejected `
            -Name ([string]$case.name) `
            -Field ([string]$case.field) `
            -Value $case.value `
            -ExpectedReason ([string]$case.reason)
    }

    $validRunId = "authorization-binding-green"
    $valid = Invoke-LaunchAuthorizationFixture `
        -CaseName $validRunId `
        -Authorization (New-LaunchAuthorizationFixture $validRunId)
    $launch = Get-Content -LiteralPath $valid.paths.launch -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-BindingCondition ([bool]$valid.result.wrapper_exit_green) "matching authorization must complete green"
    Assert-BindingCondition ([string]$valid.result.wrapper_reason_code -ceq "ok") "matching authorization must preserve ok reason"
    Assert-BindingCondition ([IO.File]::Exists($valid.paths.marker)) "matching authorization must launch the child"
    Assert-BindingCondition ([IO.File]::Exists($valid.paths.child)) "matching authorization must write Child Completion"
    Assert-BindingCondition ([IO.File]::Exists($valid.paths.parent)) "matching authorization must write Parent Exit"
    Assert-BindingCondition ([IO.File]::Exists($valid.paths.launch)) "matching authorization must write launch attestation"
    Assert-BindingCondition ([string]$launch.run_id -ceq $validRunId `
        -and [string]$launch.source_head_sha -ceq $repositoryHead `
        -and [string]$launch.process_role -ceq $role `
        -and [string]$launch.scenario_fingerprint -ceq $scenarioFingerprint `
        -and [int]$launch.orchestrator_process_id -eq $PID `
        -and [string]$launch.orchestrator_creation_time_utc_ticks -ceq (Get-CurrentMicrosecondCreationTicks)) "launch attestation must preserve the validated authorization binding"
}
catch {
    $script:failures.Add("unexpected exception: $($_.Exception.Message)")
}
finally {
    if ([IO.Directory]::Exists($root)) {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "COLD_RESTORE_LAUNCH_AUTHORIZATION_BINDING_TEST|status=$status|checks=$($script:checks)|failures=$($script:failures.Count)"
foreach ($failure in $script:failures) {
    Write-Output "FAIL|$failure"
}
if ($script:failures.Count -gt 0) {
    exit 1
}
