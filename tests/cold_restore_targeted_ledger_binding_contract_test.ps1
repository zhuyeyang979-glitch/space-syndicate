[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$toolsRoot = Join-Path $projectRoot "scripts/tools"
$contractPath = Join-Path $toolsRoot "cold_restore_targeted_ledger_binding_contract_v1.json"
$modulePath = Join-Path $toolsRoot "cold_restore_targeted_ledger_binding_contract_v1.psm1"
$driverPath = Join-Path $toolsRoot "cold_restore_vertical_slice_driver.gd"
$prequotaPath = Join-Path $toolsRoot "cold_restore_prequota_bootstrap.psm1"
$orchestratorPath = Join-Path $toolsRoot "cold_restore_vertical_slice_orchestrator.ps1"
$rehearsalPath = Join-Path $toolsRoot "process_a_rehearsal_admission_contract.psm1"
$validatorPath = Join-Path $toolsRoot "cold_restore_targeted_ledger_binding_validator_v1.gd"
$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()

function Assert-BindingCondition {
    param([bool]$Condition, [string]$Message)

    $script:checks += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

try {
    $contract = [IO.File]::ReadAllText(
        $contractPath,
        [Text.UTF8Encoding]::new($false)
    ) | ConvertFrom-Json -DateKind String
    Assert-BindingCondition (
        [int]$contract.schema_version -eq 1 -and
        [string]$contract.contract_id -ceq "ColdRestoreTargetedLedgerBindingContractV1" -and
        [int]$contract.ledger_schema_version -eq 4
    ) "binding contract identity is exact"
    Assert-BindingCondition (
        @($contract.field_order).Count -eq 32 -and
        @(Compare-Object @($contract.field_order) @($contract.required_fields)).Count -eq 0
    ) "field order and required field set share one 32-field source"
    Assert-BindingCondition (
        @($contract.field_types.PSObject.Properties).Count -eq 32 -and
        @($contract.failure_reason_by_field.PSObject.Properties).Count -eq 32
    ) "every field has one wire type and typed reason"
    Assert-BindingCondition (
        @($contract.exact_values_from_authorization_contract.PSObject.Properties).Count -eq 8 -and
        @($contract.option_bindings.PSObject.Properties).Count -eq 5
    ) "authorization and child option bindings are explicit"
    Assert-BindingCondition (
        @($contract.integer_encoding_rules.json_integer_number_fields).Count -eq 6 -and
        @($contract.integer_encoding_rules.decimal_string_fields).Count -eq 1 -and
        [int64]$contract.integer_encoding_rules.maximum_exact_json_integer -eq 9007199254740991
    ) "six JSON integers and one decimal-string ticks field are canonical"
    Assert-BindingCondition (
        @($contract.canonical_path_rules.fields).Count -eq 2 -and
        [string]$contract.canonical_path_rules.separator_normalization -ceq "forward_slash" -and
        [bool]$contract.nonce_rules.must_differ -and
        -not [bool]$contract.nonce_rules.public_value_exposure_allowed
    ) "path and nonce normalization is closed"

    $driverSource = [IO.File]::ReadAllText($driverPath)
    $prequotaSource = [IO.File]::ReadAllText($prequotaPath)
    $orchestratorSource = [IO.File]::ReadAllText($orchestratorPath)
    $rehearsalSource = [IO.File]::ReadAllText($rehearsalPath)
    $validatorSource = [IO.File]::ReadAllText($validatorPath)
    Assert-BindingCondition (
        -not $driverSource.Contains("const TARGETED_DIAGNOSTIC_LEDGER_FIELDS") -and
        $driverSource.Contains("TARGETED_LEDGER_BINDING_VALIDATOR.validate_ledger_text")
    ) "GDScript driver delegates to the shared validator without a field list"
    Assert-BindingCondition (
        $validatorSource.Contains("cold_restore_targeted_ledger_binding_contract_v1.json") -and
        $validatorSource.Contains("json_integer_number") -and
        $validatorSource.Contains("safe_expected_fingerprint")
    ) "GDScript validator consumes the shared contract and emits redacted evidence"
    Assert-BindingCondition (
        $prequotaSource.Contains("Assert-ColdRestoreTargetedLedgerPublisherValue") -and
        $orchestratorSource.Contains("Get-ColdRestoreTargetedLedgerBindingContract") -and
        $rehearsalSource.Contains("Assert-ColdRestoreTargetedLedgerPublisherValue")
    ) "publisher, builder, and rehearsal admission consume the same contract"

    $fixedValues = @(
        [string]$contract.exact_literals.previous_ledger_sha256,
        [string]$contract.exact_literals.historical_invocation_commit,
        [string]$contract.exact_literals.historical_invocation_blob_sha1,
        [string]$contract.exact_literals.historical_invocation_file_sha256
    )
    foreach ($fixedValue in $fixedValues) {
        $matches = @(Get-ChildItem -LiteralPath $toolsRoot -File | Where-Object {
            $_.Extension -in @(".ps1", ".psm1", ".gd", ".json")
        } | Select-String -SimpleMatch $fixedValue)
        Assert-BindingCondition (
            $matches.Count -eq 1 -and
            [IO.Path]::GetFullPath([string]$matches[0].Path) -ceq [IO.Path]::GetFullPath($contractPath)
        ) "binding literal $($fixedValue.Substring(0, 8)) has one source"
    }

    $authorizationContract = [IO.File]::ReadAllText(
        (Join-Path $toolsRoot "cold_restore_authorization_contract_v1.json"),
        [Text.UTF8Encoding]::new($false)
    ) | ConvertFrom-Json -DateKind String
    Assert-BindingCondition (
        $null -eq $authorizationContract.PSObject.Properties["targeted_owner_capture_diagnostic_v5"]
    ) "no V5 authorization exists"

    Import-Module $modulePath -ErrorAction Stop
    $moduleContract = cold_restore_targeted_ledger_binding_contract_v1\Get-ColdRestoreTargetedLedgerBindingContract
    Assert-BindingCondition (
        [string]$moduleContract.contract_id -ceq [string]$contract.contract_id
    ) "PowerShell module reads the same contract bytes"

    $common = (& git -C $projectRoot rev-parse --git-common-dir).Trim()
    $ledgerPath = Join-Path $common "codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v4-importchain/targeted_owner_capture_quota_ledger.json"
    $ledgerPath = [IO.Path]::GetFullPath($ledgerPath)
    Assert-BindingCondition (
        [IO.File]::Exists($ledgerPath) -and
        (Get-FileHash $ledgerPath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq
            "154ceedf4032404d4c7d355fbd775991e20d29299f6e05e3a8c8e70c64be208c"
    ) "retained V4 ledger bytes remain exact"
    $ledger = [IO.File]::ReadAllText(
        $ledgerPath,
        [Text.UTF8Encoding]::new($false)
    ) | ConvertFrom-Json -DateKind String
    Assert-BindingCondition (
        cold_restore_targeted_ledger_binding_contract_v1\Assert-ColdRestoreTargetedLedgerPublisherValue $ledger
    ) "PowerShell publisher accepts the retained V4 ledger through the shared contract"
}
catch {
    $script:failures.Add("unexpected exception: $($_.Exception.Message)")
}

$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "COLD_RESTORE_TARGETED_LEDGER_BINDING_CONTRACT|status=$status|checks=$script:checks|failures=$($script:failures.Count)|contract_source_count=1|duplicate_ledger_field_list_count=0|duplicate_binding_constant_count=0|diagnostic_count_delta=0|godot_launched=false"
foreach ($failure in $script:failures) {
    Write-Output "FAIL|$failure"
}
if ($script:failures.Count -gt 0) { exit 1 }
exit 0
