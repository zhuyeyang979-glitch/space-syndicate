Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ModuleLoader = Import-Module `
    (Join-Path $PSScriptRoot "cold_restore_module_loader.psm1") `
    -PassThru `
    -ErrorAction Stop
$script:AttestedProcessModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
    -Path (Join-Path $PSScriptRoot "cold_restore_attested_process.psm1") `
    -RequiredCommands @("ConvertTo-ColdRestoreCanonicalJson", "Test-ColdRestoreExactFieldSet")
$script:LaunchContextContractPath = Join-Path `
    $PSScriptRoot "cold_restore_targeted_diagnostic_launch_context_v1.json"

function Get-ColdRestoreTargetedDiagnosticLaunchContextContract {
    if (-not [IO.File]::Exists($script:LaunchContextContractPath)) {
        throw "targeted_diagnostic_launch_context_contract_missing"
    }
    try {
        $contract = [IO.File]::ReadAllText(
            $script:LaunchContextContractPath,
            [Text.UTF8Encoding]::new($false)
        ) | ConvertFrom-Json -DateKind String
    }
    catch {
        throw "targeted_diagnostic_launch_context_contract_invalid"
    }
    if ([int]$contract.schema_version -ne 1 `
        -or [string]$contract.context_id -cne "ColdRestoreTargetedDiagnosticLaunchContextV1" `
        -or [int]$contract.runtime_identity.schema_version -ne 1 `
        -or [string]$contract.runtime_identity.context_id -cne [string]$contract.context_id `
        -or @($contract.required_fields).Count -eq 0 `
        -or -not [bool]$contract.repository_head.required `
        -or [bool]$contract.repository_head.nullable `
        -or [bool]$contract.repository_head.empty_allowed `
        -or [bool]$contract.repository_head.implicit_fallback_allowed `
        -or [bool]$contract.repository_head.source_head_sha_alias_allowed `
        -or [int]$contract.repository_head.length -ne 40 `
        -or [string]$contract.repository_head.wire_type -cne "lowercase_hex_string") {
        throw "targeted_diagnostic_launch_context_contract_invalid"
    }
    foreach ($fieldValue in @($contract.required_fields)) {
        $field = [string]$fieldValue
        foreach ($mapName in @(
                "field_types", "validation_rules", "field_sources",
                "failure_reason_by_field"
            )) {
            if ($null -eq $contract.$mapName.PSObject.Properties[$field]) {
                throw "targeted_diagnostic_launch_context_contract_invalid"
            }
        }
    }
    foreach ($fieldValue in @($contract.gdscript_option_names.PSObject.Properties.Name)) {
        $field = [string]$fieldValue
        if ($null -eq $contract.cli_argument_names.PSObject.Properties[$field]) {
            throw "targeted_diagnostic_launch_context_contract_invalid"
        }
    }
    return $contract
}

function Get-ColdRestoreTargetedDiagnosticLaunchContextContractPath {
    return [IO.Path]::GetFullPath($script:LaunchContextContractPath)
}

function Test-ColdRestoreLaunchContextHasField {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory = $true)][string]$Field
    )

    if ($null -eq $Value) { return $false }
    if ($Value -is [Collections.IDictionary]) {
        return $Value.Contains($Field)
    }
    return $null -ne $Value.PSObject.Properties[$Field]
}

function Get-ColdRestoreLaunchContextFieldValue {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory = $true)][string]$Field
    )

    if (-not (Test-ColdRestoreLaunchContextHasField $Value $Field)) { return $null }
    if ($Value -is [Collections.IDictionary]) { return $Value[$Field] }
    return $Value.PSObject.Properties[$Field].Value
}

function Test-ColdRestoreLaunchContextJsonInteger {
    param([AllowNull()]$Value)

    return $Value -is [sbyte] -or $Value -is [byte] `
        -or $Value -is [int16] -or $Value -is [uint16] `
        -or $Value -is [int32] -or $Value -is [uint32] `
        -or $Value -is [int64]
}

function Get-ColdRestoreLaunchContextSafeFingerprint {
    param([AllowNull()]$Value)

    $canonical = cold_restore_attested_process\ConvertTo-ColdRestoreCanonicalJson $Value
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($canonical)
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
}

function Get-ColdRestoreLaunchContextShapeFailure {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory = $true)][string]$ExpectedType,
        [Parameter(Mandatory = $true)][string]$Rule
    )

    if ($null -eq $Value) { return "null" }
    if ($ExpectedType -in @("string", "decimal_string")) {
        if ($Value -isnot [string]) { return "wrong_type" }
        if ([string]$Value -ceq "") { return "empty" }
    }
    elseif ($ExpectedType -eq "json_integer_number") {
        if (-not (Test-ColdRestoreLaunchContextJsonInteger $Value)) { return "wrong_type" }
    }
    else {
        return "wrong_type"
    }

    $text = if ($Value -is [string]) { [string]$Value } else { "" }
    switch ($Rule) {
        "lower_hex_40" {
            if ($text.Length -ne 40) { return "wrong_length" }
            if ($text -cnotmatch '^[0-9A-Fa-f]{40}$') { return "non_hex" }
            if ($text -cmatch '[A-F]') { return "uppercase" }
        }
        "lower_sha256" {
            if ($text.Length -ne 64) { return "wrong_length" }
            if ($text -cnotmatch '^[0-9A-Fa-f]{64}$') { return "non_hex" }
            if ($text -cmatch '[A-F]') { return "uppercase" }
        }
        "lower_hex_32" {
            if ($text.Length -ne 32) { return "wrong_length" }
            if ($text -cnotmatch '^[0-9A-Fa-f]{32}$') { return "non_hex" }
            if ($text -cmatch '[A-F]') { return "uppercase" }
        }
        "safe_identifier" {
            if ($text -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') { return "invalid_format" }
        }
        "safe_run_id" {
            if ($text -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$') { return "invalid_format" }
        }
        "absolute_path" {
            if (-not [IO.Path]::IsPathFullyQualified($text)) { return "invalid_path" }
        }
        "positive_integer" {
            if (-not (Test-ColdRestoreLaunchContextJsonInteger $Value) -or [int64]$Value -le 0) {
                return "out_of_range"
            }
        }
        "positive_decimal_19" {
            if ($text -cnotmatch '^[1-9][0-9]{0,18}$') { return "invalid_format" }
        }
        default { return "invalid_rule" }
    }
    return ""
}

function New-ColdRestoreLaunchContextFailure {
    param(
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)][string]$Field,
        [Parameter(Mandatory = $true)][string]$FieldReason,
        [AllowNull()]$Expected,
        [AllowNull()]$Actual
    )

    return [pscustomobject][ordered]@{
        valid = $false
        reason_code = "targeted_owner_capture_launch_context_invalid"
        failing_stage = $Stage
        failing_field = $Field
        field_reason = $FieldReason
        safe_expected_fingerprint = Get-ColdRestoreLaunchContextSafeFingerprint $Expected
        safe_actual_fingerprint = Get-ColdRestoreLaunchContextSafeFingerprint $Actual
    }
}

function Test-ColdRestoreTargetedDiagnosticLaunchContext {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Collections.IDictionary]$ExpectedBindings = @{},
        [string]$Stage = "launch_context_validation"
    )

    $contract = Get-ColdRestoreTargetedDiagnosticLaunchContextContract
    foreach ($fieldValue in @($contract.required_fields)) {
        $field = [string]$fieldValue
        if (-not (Test-ColdRestoreLaunchContextHasField $Context $field)) {
            return New-ColdRestoreLaunchContextFailure `
                $Stage $field "missing" (Get-ColdRestoreLaunchContextFieldValue $ExpectedBindings $field) "__missing__"
        }
        $value = Get-ColdRestoreLaunchContextFieldValue $Context $field
        $shapeFailure = Get-ColdRestoreLaunchContextShapeFailure `
            $value ([string]$contract.field_types.$field) ([string]$contract.validation_rules.$field)
        if (-not [string]::IsNullOrEmpty($shapeFailure)) {
            $expected = if (Test-ColdRestoreLaunchContextHasField $ExpectedBindings $field) {
                Get-ColdRestoreLaunchContextFieldValue $ExpectedBindings $field
            }
            else {
                [string]$contract.field_types.$field
            }
            return New-ColdRestoreLaunchContextFailure $Stage $field $shapeFailure $expected $value
        }
    }
    $actualFields = if ($Context -is [Collections.IDictionary]) {
        @($Context.Keys | ForEach-Object { [string]$_ })
    }
    else {
        @($Context.PSObject.Properties.Name | ForEach-Object { [string]$_ })
    }
    $fieldSetValid = $actualFields.Count -eq @($contract.required_fields).Count
    foreach ($requiredField in @($contract.required_fields)) {
        $fieldSetValid = $fieldSetValid -and ($actualFields -ccontains [string]$requiredField)
    }
    if (-not $fieldSetValid) {
        return New-ColdRestoreLaunchContextFailure `
            $Stage "field_set" "unexpected_field" @($contract.required_fields) $actualFields
    }

    $builtInExpected = [ordered]@{
        schema_version = [int]$contract.runtime_identity.schema_version
        context_id = [string]$contract.runtime_identity.context_id
        challenge_depth = [int]$contract.fixed_values.challenge_depth
        run_seed = [int]$contract.fixed_values.run_seed
        local_player_count = [int]$contract.fixed_values.local_player_count
        ai_player_count = [int]$contract.fixed_values.ai_player_count
    }
    foreach ($field in @($builtInExpected.Keys) + @($ExpectedBindings.Keys)) {
        $expected = if ($ExpectedBindings.Contains($field)) {
            $ExpectedBindings[$field]
        }
        else {
            $builtInExpected[$field]
        }
        $actual = Get-ColdRestoreLaunchContextFieldValue $Context ([string]$field)
        $equal = if ($actual -is [string] -and $expected -is [string]) {
            [string]$actual -ceq [string]$expected
        }
        elseif ((Test-ColdRestoreLaunchContextJsonInteger $actual) `
            -and (Test-ColdRestoreLaunchContextJsonInteger $expected)) {
            [int64]$actual -eq [int64]$expected
        }
        else {
            $actual -eq $expected
        }
        if (-not $equal) {
            return New-ColdRestoreLaunchContextFailure `
                $Stage ([string]$field) "value_mismatch" $expected $actual
        }
    }
    return [pscustomobject][ordered]@{
        valid = $true
        reason_code = "ok"
        failing_stage = ""
        failing_field = ""
        field_reason = ""
        safe_expected_fingerprint = ""
        safe_actual_fingerprint = ""
    }
}

function New-ColdRestoreTargetedDiagnosticLaunchContext {
    param(
        [Parameter(Mandatory = $true)]$Ledger,
        [Parameter(Mandatory = $true)][string]$RepositoryHead,
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$ScenarioFingerprint,
        [Parameter(Mandatory = $true)][string]$QuotaLedgerPath,
        [Parameter(Mandatory = $true)][string]$QuotaLedgerSha256,
        [Parameter(Mandatory = $true)][string]$LaunchAttestationPath,
        [Parameter(Mandatory = $true)][string]$LaunchNonce,
        [Parameter(Mandatory = $true)][string]$RoleTimeoutPolicySha256
    )

    $contract = Get-ColdRestoreTargetedDiagnosticLaunchContextContract
    if (-not [IO.File]::Exists($QuotaLedgerPath)) {
        throw "targeted_owner_capture_launch_context_invalid|powershell_builder|quota_ledger_path|missing"
    }
    $actualLedgerSha256 = (Get-FileHash -LiteralPath $QuotaLedgerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualLedgerSha256 -cne $QuotaLedgerSha256) {
        throw "targeted_owner_capture_launch_context_invalid|powershell_builder|quota_ledger_sha256|value_mismatch"
    }
    $context = [ordered]@{
        schema_version = [int]$contract.runtime_identity.schema_version
        context_id = [string]$contract.runtime_identity.context_id
        authorization_id = Get-ColdRestoreLaunchContextFieldValue $Ledger "authorization_id"
        run_id = $RunId
        repository_head = $RepositoryHead
        scenario_fingerprint = $ScenarioFingerprint
        challenge_depth = [int]$contract.fixed_values.challenge_depth
        run_seed = [int]$contract.fixed_values.run_seed
        local_player_count = [int]$contract.fixed_values.local_player_count
        ai_player_count = [int]$contract.fixed_values.ai_player_count
        quota_ledger_path = [IO.Path]::GetFullPath($QuotaLedgerPath)
        quota_ledger_sha256 = $QuotaLedgerSha256
        launch_attestation_path = [IO.Path]::GetFullPath($LaunchAttestationPath)
        claim_nonce = Get-ColdRestoreLaunchContextFieldValue $Ledger "claim_nonce"
        launch_nonce = $LaunchNonce
        orchestrator_process_id = Get-ColdRestoreLaunchContextFieldValue $Ledger "orchestrator_process_id"
        orchestrator_creation_time_utc_ticks = Get-ColdRestoreLaunchContextFieldValue $Ledger "orchestrator_creation_time_utc_ticks"
        role_timeout_policy_sha256 = $RoleTimeoutPolicySha256
        official_attempt_1_claim_sha256 = Get-ColdRestoreLaunchContextFieldValue $Ledger "official_attempt_1_claim_sha256"
    }
    $expected = [ordered]@{
        authorization_id = Get-ColdRestoreLaunchContextFieldValue $Ledger "authorization_id"
        run_id = Get-ColdRestoreLaunchContextFieldValue $Ledger "run_id"
        repository_head = Get-ColdRestoreLaunchContextFieldValue $Ledger "repository_head"
        scenario_fingerprint = Get-ColdRestoreLaunchContextFieldValue $Ledger "scenario_fingerprint"
        claim_nonce = Get-ColdRestoreLaunchContextFieldValue $Ledger "claim_nonce"
        launch_nonce = Get-ColdRestoreLaunchContextFieldValue $Ledger "launch_nonce"
        orchestrator_process_id = Get-ColdRestoreLaunchContextFieldValue $Ledger "orchestrator_process_id"
        orchestrator_creation_time_utc_ticks = Get-ColdRestoreLaunchContextFieldValue $Ledger "orchestrator_creation_time_utc_ticks"
        role_timeout_policy_sha256 = Get-ColdRestoreLaunchContextFieldValue $Ledger "role_timeout_policy_sha256"
        official_attempt_1_claim_sha256 = Get-ColdRestoreLaunchContextFieldValue $Ledger "official_attempt_1_claim_sha256"
    }
    $report = Test-ColdRestoreTargetedDiagnosticLaunchContext `
        -Context $context -ExpectedBindings $expected -Stage "powershell_builder"
    if (-not [bool]$report.valid) {
        throw "targeted_owner_capture_launch_context_invalid|$($report.failing_stage)|$($report.failing_field)|$($report.field_reason)"
    }
    return [pscustomobject]$context
}

function ConvertTo-ColdRestoreTargetedDiagnosticLaunchArgumentList {
    param([Parameter(Mandatory = $true)]$Context)

    $contract = Get-ColdRestoreTargetedDiagnosticLaunchContextContract
    $report = Test-ColdRestoreTargetedDiagnosticLaunchContext `
        -Context $Context -Stage "powershell_cli_publisher"
    if (-not [bool]$report.valid) {
        throw "targeted_owner_capture_launch_context_invalid|$($report.failing_stage)|$($report.failing_field)|$($report.field_reason)"
    }
    $arguments = [Collections.Generic.List[string]]::new()
    foreach ($modeArgument in @($contract.mode_arguments)) {
        $arguments.Add([string]$modeArgument)
    }
    foreach ($fieldValue in @($contract.required_fields)) {
        $field = [string]$fieldValue
        $mapping = $contract.cli_argument_names.PSObject.Properties[$field]
        if ($null -eq $mapping -or $null -eq $mapping.Value) { continue }
        $arguments.Add("$([string]$mapping.Value)$(Get-ColdRestoreLaunchContextFieldValue $Context $field)")
    }
    return $arguments.ToArray()
}

Export-ModuleMember -Function @(
    "ConvertTo-ColdRestoreTargetedDiagnosticLaunchArgumentList",
    "Get-ColdRestoreTargetedDiagnosticLaunchContextContract",
    "Get-ColdRestoreTargetedDiagnosticLaunchContextContractPath",
    "New-ColdRestoreTargetedDiagnosticLaunchContext",
    "Test-ColdRestoreTargetedDiagnosticLaunchContext"
)
