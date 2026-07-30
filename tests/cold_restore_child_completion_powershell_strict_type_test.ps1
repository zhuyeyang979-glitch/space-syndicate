[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$modulePath = Join-Path $projectRoot "scripts/tools/cold_restore_attested_process.psm1"
Import-Module $modulePath -Force

$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()
$repositoryHead = "d" * 40
$scenarioFingerprint = "a" * 64
$runId = "child-completion-powershell-strict-type"
$role = "producer"
$root = Join-Path ([IO.Path]::GetTempPath()) (
    "space-syndicate-child-completion-powershell-strict-type-" + [Guid]::NewGuid().ToString("N")
)
[IO.Directory]::CreateDirectory($root) | Out-Null

function Assert-StrictTypeCondition {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $script:checks += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

function Copy-ChildCompletionFixture {
    param([Parameter(Mandatory = $true)]$Value)

    return $Value | ConvertTo-Json -Depth 20 | ConvertFrom-Json
}

function Write-ChildCompletionCase {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )

    $Value.evidence_fingerprint = Get-ColdRestoreEvidenceFingerprint $Value "evidence_fingerprint"
    Write-ColdRestoreAtomicJson $Path $Value | Out-Null
}

function Assert-MalformedChildCompletionRejected {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Field,
        [Parameter(Mandatory = $true)]$MalformedValue,
        [Parameter(Mandatory = $true)][string]$ExpectedReason,
        [Parameter(Mandatory = $true)]$Baseline
    )

    $value = Copy-ChildCompletionFixture $Baseline
    $value.$Field = $MalformedValue
    $path = Join-Path $root "$Name.json"
    Write-ChildCompletionCase -Path $path -Value $value

    $validation = Test-ColdRestoreChildCompletionAttestation `
        -Path $path `
        -ExpectedRunId $runId `
        -ExpectedRole $role `
        -ExpectedRepositoryHead $repositoryHead `
        -ProcessStartedAtUtc ([DateTime]::UtcNow.AddSeconds(-2)) `
        -ExpectedScenarioFingerprint $scenarioFingerprint

    $rejected = $validation.valid -is [bool] -and $validation.valid -eq $false
    $reason = [string]$validation.reason_code
    Assert-StrictTypeCondition `
        -Condition $rejected `
        -Message "$Name must be rejected"
    Assert-StrictTypeCondition `
        -Condition (-not [string]::IsNullOrWhiteSpace($reason) -and $reason -cne "ok") `
        -Message "$Name must return a concrete non-ok reason; observed '$reason'"
    Assert-StrictTypeCondition `
        -Condition ($reason -ceq $ExpectedReason) `
        -Message "$Name expected '$ExpectedReason'; observed '$reason'"
}

try {
    $baseline = New-ColdRestoreChildCompletionFixture `
        -RunId $runId `
        -Role $role `
        -RepositoryHead $repositoryHead
    $baselinePath = Join-Path $root "baseline.json"
    Write-ChildCompletionCase -Path $baselinePath -Value $baseline
    $baselineValidation = Test-ColdRestoreChildCompletionAttestation `
        -Path $baselinePath `
        -ExpectedRunId $runId `
        -ExpectedRole $role `
        -ExpectedRepositoryHead $repositoryHead `
        -ProcessStartedAtUtc ([DateTime]::UtcNow.AddSeconds(-2)) `
        -ExpectedScenarioFingerprint $scenarioFingerprint
    Assert-StrictTypeCondition `
        -Condition ($baselineValidation.valid -is [bool] -and $baselineValidation.valid) `
        -Message "legal New-ColdRestoreChildCompletionFixture baseline must validate"
    Assert-StrictTypeCondition `
        -Condition ([string]$baselineValidation.reason_code -ceq "ok") `
        -Message "legal baseline must return reason_code=ok"

    $cases = @(
        [pscustomobject]@{ name = "schema-string"; field = "schema_version"; value = "1"; reason = "child_attestation_schema_invalid" }
        [pscustomobject]@{ name = "official-string"; field = "official"; value = "false"; reason = "child_attestation_boolean_invalid" }
        [pscustomobject]@{ name = "formal-string"; field = "formal"; value = "false"; reason = "child_attestation_boolean_invalid" }
        [pscustomobject]@{ name = "qualification-completed-string"; field = "qualification_completed"; value = "true"; reason = "child_attestation_boolean_invalid" }
        [pscustomobject]@{ name = "qualification-green-string"; field = "qualification_green"; value = "true"; reason = "child_attestation_boolean_invalid" }
        [pscustomobject]@{ name = "save-written-string"; field = "save_written"; value = "false"; reason = "child_attestation_boolean_invalid" }
        [pscustomobject]@{ name = "official-count-consumed-string"; field = "official_count_consumed"; value = "false"; reason = "child_attestation_boolean_invalid" }
        [pscustomobject]@{ name = "child-ready-to-exit-string"; field = "child_ready_to_exit"; value = "true"; reason = "child_attestation_boolean_invalid" }
        [pscustomobject]@{ name = "queue-count-string"; field = "queue_count"; value = "1"; reason = "child_attestation_integer_invalid" }
        [pscustomobject]@{ name = "queue-revision-string"; field = "queue_revision"; value = "1"; reason = "child_attestation_integer_invalid" }
        [pscustomobject]@{ name = "product-mutation-string"; field = "product_mutation_count"; value = "0"; reason = "child_attestation_integer_invalid" }
        [pscustomobject]@{ name = "queue-mutation-string"; field = "queue_injection_count"; value = "0"; reason = "child_attestation_integer_invalid" }
        [pscustomobject]@{ name = "direct-authority-mutation-string"; field = "direct_authority_mutation_count"; value = "0"; reason = "child_attestation_integer_invalid" }
        [pscustomobject]@{ name = "product-mutation-negative"; field = "product_mutation_count"; value = -1; reason = "child_attestation_integer_invalid" }
        [pscustomobject]@{ name = "queue-mutation-negative"; field = "queue_injection_count"; value = -1; reason = "child_attestation_integer_invalid" }
        [pscustomobject]@{ name = "direct-authority-mutation-negative"; field = "direct_authority_mutation_count"; value = -1; reason = "child_attestation_integer_invalid" }
        [pscustomobject]@{ name = "target-fingerprint-invalid"; field = "queue_trigger_target_fingerprint"; value = "not-a-fingerprint"; reason = "child_attestation_target_fingerprint_invalid" }
        [pscustomobject]@{ name = "final-reason-code-too-long"; field = "final_reason_code"; value = ("x" * 257); reason = "child_attestation_text_invalid" }
    )

    foreach ($case in $cases) {
        Assert-MalformedChildCompletionRejected `
            -Name ([string]$case.name) `
            -Field ([string]$case.field) `
            -MalformedValue $case.value `
            -ExpectedReason ([string]$case.reason) `
            -Baseline $baseline
    }
}
finally {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $resolvedRoot = [IO.Path]::GetFullPath($root)
    if ($resolvedRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and [IO.Directory]::Exists($resolvedRoot)) {
        [IO.Directory]::Delete($resolvedRoot, $true)
    }
}

$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output (
    "COLD_RESTORE_CHILD_COMPLETION_POWERSHELL_STRICT_TYPE_TEST|status={0}|checks={1}|failures={2}" -f `
        $status,
        $script:checks,
        $script:failures.Count
)
foreach ($failure in $script:failures) {
    Write-Output "FAIL|$failure"
}
if ($script:failures.Count -gt 0) {
    exit 1
}
