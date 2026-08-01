Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ModuleLoader = Import-Module `
    (Join-Path $PSScriptRoot "cold_restore_module_loader.psm1") `
    -PassThru `
    -ErrorAction Stop
$script:AuthorizationModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
    -Path (Join-Path $PSScriptRoot "cold_restore_authorization_contract_v1.psm1") `
    -RequiredCommands @(
        "Get-ColdRestoreAuthorizationContract",
        "Get-ColdRestoreAuthorizationEntry",
        "Get-ColdRestoreTargetedDiagnosticAuthorizationNames"
    )
$script:AttestedProcessModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
    -Path (Join-Path $PSScriptRoot "cold_restore_attested_process.psm1") `
    -RequiredCommands @("Test-ColdRestoreExactFieldSet")
$script:BindingContractPath = Join-Path `
    $PSScriptRoot "cold_restore_targeted_ledger_binding_contract_v1.json"

function Get-ColdRestoreTargetedLedgerBindingContract {
    if (-not [IO.File]::Exists($script:BindingContractPath)) {
        throw "targeted_ledger_binding_contract_missing"
    }
    try {
        $contract = [IO.File]::ReadAllText(
            $script:BindingContractPath,
            [Text.UTF8Encoding]::new($false)
        ) | ConvertFrom-Json -DateKind String
    }
    catch {
        throw "targeted_ledger_binding_contract_invalid"
    }
    if ([int]$contract.schema_version -ne 1 `
        -or [string]$contract.contract_id -cne "ColdRestoreTargetedLedgerBindingContractV1" `
        -or [string]$contract.authorization_entry_resolution -cne "ledger_authorization_id" `
        -or @($contract.field_order).Count -eq 0 `
        -or @(Compare-Object @($contract.field_order) @($contract.required_fields)).Count -ne 0) {
        throw "targeted_ledger_binding_contract_invalid"
    }
    foreach ($field in @($contract.field_order)) {
        if ($null -eq $contract.field_types.PSObject.Properties[[string]$field] `
            -or $null -eq $contract.failure_reason_by_field.PSObject.Properties[[string]$field]) {
            throw "targeted_ledger_binding_contract_invalid"
        }
    }
    return $contract
}

function Get-ColdRestoreDottedValue {
    param(
        [Parameter(Mandatory = $true)]$Root,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $current = $Root
    foreach ($segment in $Path.Split('.', [StringSplitOptions]::RemoveEmptyEntries)) {
        $property = $current.PSObject.Properties[$segment]
        if ($null -eq $property) {
            throw "targeted_ledger_binding_contract_path_invalid"
        }
        $current = $property.Value
    }
    return $current
}

function Test-ColdRestoreJsonIntegerNumber {
    param([AllowNull()]$Value)

    return $Value -is [sbyte] -or $Value -is [byte] `
        -or $Value -is [int16] -or $Value -is [uint16] `
        -or $Value -is [int32] -or $Value -is [uint32] `
        -or $Value -is [int64]
}

function Test-ColdRestoreTargetedLedgerWireType {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory = $true)][string]$ExpectedType
    )

    switch ($ExpectedType) {
        "string" { return $Value -is [string] }
        "decimal_string" { return $Value -is [string] }
        "boolean" { return $Value -is [bool] }
        "json_integer_number" { return Test-ColdRestoreJsonIntegerNumber $Value }
        default { return $false }
    }
}

function Test-ColdRestoreTargetedLedgerRegex {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory = $true)][string]$Pattern
    )

    return $Value -is [string] -and [string]$Value -cmatch $Pattern
}

function Test-ColdRestoreTargetedLedgerRule {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory = $true)][string]$RuleId
    )

    switch ($RuleId) {
        "none" { return $true }
        "utc_timestamp" {
            if ($Value -isnot [string]) { return $false }
            $parsed = [DateTime]::MinValue
            return [DateTime]::TryParseExact(
                [string]$Value,
                "O",
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::RoundtripKind,
                [ref]$parsed
            )
        }
        "safe_run_id" {
            return Test-ColdRestoreTargetedLedgerRegex $Value '^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$'
        }
        "lower_hex_40" {
            return Test-ColdRestoreTargetedLedgerRegex $Value '^[0-9a-f]{40}$'
        }
        "lower_sha256" {
            return Test-ColdRestoreTargetedLedgerRegex $Value '^[0-9a-f]{64}$'
        }
        "lower_hex_32" {
            return Test-ColdRestoreTargetedLedgerRegex $Value '^[0-9a-f]{32}$'
        }
        "portable_absolute_path" {
            return $Value -is [string] -and [IO.Path]::IsPathFullyQualified([string]$Value)
        }
        "positive_integer" {
            return (Test-ColdRestoreJsonIntegerNumber $Value) -and [int64]$Value -gt 0
        }
        "positive_decimal_19" {
            return Test-ColdRestoreTargetedLedgerRegex $Value '^[1-9][0-9]{0,18}$'
        }
        default { return $false }
    }
}

function Test-ColdRestoreTargetedLedgerExactValue {
    param(
        [AllowNull()]$Actual,
        [AllowNull()]$Expected,
        [Parameter(Mandatory = $true)][string]$ExpectedType
    )

    if ($ExpectedType -eq "json_integer_number") {
        return (Test-ColdRestoreJsonIntegerNumber $Actual) `
            -and (Test-ColdRestoreJsonIntegerNumber $Expected) `
            -and [int64]$Actual -eq [int64]$Expected
    }
    if ($Actual -is [string] -and $Expected -is [string]) {
        return [string]$Actual -ceq [string]$Expected
    }
    return $Actual -eq $Expected
}

function Assert-ColdRestoreTargetedLedgerPublisherValue {
    param([Parameter(Mandatory = $true)]$Value)

    $contract = Get-ColdRestoreTargetedLedgerBindingContract
    if (-not (cold_restore_attested_process\Test-ColdRestoreExactFieldSet `
            $Value @($contract.required_fields))) {
        throw "targeted_ledger_binding_field_set_invalid"
    }
    $authorizationContract = `
        cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationContract
    $authorizationNames = @(
        cold_restore_authorization_contract_v1\Get-ColdRestoreTargetedDiagnosticAuthorizationNames
    )
    $authorizationName = @(
        $authorizationNames | Where-Object {
            [string](cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationEntry $_).authorization_id `
                -ceq [string]$Value.authorization_id
        }
    )
    if ($authorizationName.Count -ne 1) {
        throw "targeted_ledger_binding_authorization_id_mismatch"
    }
    $authorizationEntry = cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationEntry `
        ([string]$authorizationName[0])
    foreach ($fieldValue in @($contract.field_order)) {
        $field = [string]$fieldValue
        $actual = $Value.PSObject.Properties[$field].Value
        $expectedType = [string]$contract.field_types.$field
        if (-not (Test-ColdRestoreTargetedLedgerWireType $actual $expectedType)) {
            throw "targeted_ledger_binding_$($field)_type_invalid"
        }
        $expectedSet = $false
        $expected = $null
        $literal = $contract.exact_literals.PSObject.Properties[$field]
        if ($null -ne $literal) {
            $expected = $literal.Value
            $expectedSet = $true
        }
        $authorizationBinding = $contract.exact_values_from_authorization_contract.PSObject.Properties[$field]
        if ($null -ne $authorizationBinding) {
            $bindingPath = [string]$authorizationBinding.Value
            $expected = if ($bindingPath.Contains(".", [StringComparison]::Ordinal)) {
                Get-ColdRestoreDottedValue $authorizationContract $bindingPath
            }
            else {
                Get-ColdRestoreDottedValue $authorizationEntry $bindingPath
            }
            $expectedSet = $true
        }
        $overrideBinding = $contract.authorization_override_fields.PSObject.Properties[$field]
        if ($null -ne $overrideBinding `
            -and $authorizationEntry.PSObject.Properties.Name -ccontains [string]$overrideBinding.Value) {
            $expected = Get-ColdRestoreDottedValue `
                $authorizationEntry ([string]$overrideBinding.Value)
            $expectedSet = $true
        }
        if ($expectedSet -and -not (Test-ColdRestoreTargetedLedgerExactValue `
                $actual $expected $expectedType)) {
            $reason = [string]$contract.failure_reason_by_field.$field
            throw "targeted_ledger_binding_$reason"
        }
        $ruleProperty = $contract.validation_rules.PSObject.Properties[$field]
        $rule = if ($null -eq $ruleProperty) { "none" } else { [string]$ruleProperty.Value }
        if (-not (Test-ColdRestoreTargetedLedgerRule $actual $rule)) {
            $reason = [string]$contract.failure_reason_by_field.$field
            throw "targeted_ledger_binding_$reason"
        }
    }
    foreach ($rule in @($contract.cross_field_rules)) {
        if ([string]$rule.comparison -cne "not_equal") {
            throw "targeted_ledger_binding_cross_field_rule_invalid"
        }
        $left = $Value.PSObject.Properties[[string]$rule.left_field].Value
        $right = $Value.PSObject.Properties[[string]$rule.right_field].Value
        if ([string]$left -ceq [string]$right) {
            throw "targeted_ledger_binding_$([string]$rule.failure_reason)"
        }
    }
    return $true
}

function Get-ColdRestoreTargetedLedgerBindingContractPath {
    return [IO.Path]::GetFullPath($script:BindingContractPath)
}

Export-ModuleMember -Function @(
    "Assert-ColdRestoreTargetedLedgerPublisherValue",
    "Get-ColdRestoreTargetedLedgerBindingContract",
    "Get-ColdRestoreTargetedLedgerBindingContractPath"
)
