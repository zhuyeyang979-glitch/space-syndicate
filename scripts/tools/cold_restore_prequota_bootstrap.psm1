Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ColdRestoreModuleLoader = Import-Module `
    (Join-Path $PSScriptRoot "cold_restore_module_loader.psm1") `
    -PassThru `
    -ErrorAction Stop
$script:ColdRestoreAttestedProcessModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
    -Path (Join-Path $PSScriptRoot "cold_restore_attested_process.psm1") `
    -RequiredCommands @(
        "ConvertTo-ColdRestoreCanonicalJson",
        "Get-ColdRestoreEvidenceFingerprint",
        "Get-ColdRestoreFailureProjection",
        "Test-ColdRestoreExactFieldSet",
        "Test-ColdRestoreSafeReasonCode",
        "Write-ColdRestoreAtomicJson",
        "Write-ColdRestoreExclusiveJson",
        "Write-ColdRestoreReplacingAtomicJson"
    )
$script:ColdRestoreAuthorizationModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
    -Path (Join-Path $PSScriptRoot "cold_restore_authorization_contract_v1.psm1") `
    -RequiredCommands @(
        "Get-ColdRestoreAuthorizationEntry",
        "Get-ColdRestoreAuthorizationRunId",
        "Get-ColdRestoreTargetedDiagnosticAuthorizationBinding",
        "Get-ColdRestoreTargetedDiagnosticAuthorizationNames",
        "Get-ColdRestoreCurrentTargetedDiagnosticAuthorizationName",
        "Test-ColdRestoreExactAuthorizationId"
    )
$script:TargetedLedgerBindingModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
    -Path (Join-Path $PSScriptRoot "cold_restore_targeted_ledger_binding_contract_v1.psm1") `
    -RequiredCommands @(
        "Assert-ColdRestoreTargetedLedgerPublisherValue",
        "Get-ColdRestoreTargetedLedgerBindingContract"
    )
$script:TargetedLaunchContextModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
    -Path (Join-Path $PSScriptRoot "cold_restore_targeted_diagnostic_launch_context_v1.psm1") `
    -RequiredCommands @(
        "ConvertTo-ColdRestoreTargetedDiagnosticLaunchArgumentList",
        "New-ColdRestoreTargetedDiagnosticLaunchContext"
    )

$script:TargetedAuthorizationNames = @(
    cold_restore_authorization_contract_v1\Get-ColdRestoreTargetedDiagnosticAuthorizationNames
)
$script:TargetedAuthorizationV3 = `
    cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationEntry `
        "targeted_owner_capture_diagnostic_v3"
$script:TargetedAuthorizationV4 = `
    cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationEntry `
        "targeted_owner_capture_diagnostic_v4_importchain"
$script:CurrentTargetedAuthorizationName = `
    cold_restore_authorization_contract_v1\Get-ColdRestoreCurrentTargetedDiagnosticAuthorizationName
$script:CurrentTargetedAuthorization = `
    cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationEntry `
        $script:CurrentTargetedAuthorizationName

$script:PrimaryFailureRecordFields = @("phase", "reason_code", "safe_details", "recorded_at")
$script:BootstrapAdmissionFields = @(
    "schema_version", "admission_id", "created_at_utc", "run_id", "role",
    "repository_head", "branch", "authorization_id", "historical_count",
    "authorized_increment", "maximum_allowed_count", "official", "formal",
    "orchestrator_process_id", "orchestrator_creation_time_utc_ticks",
    "invocation_nonce", "admission_fingerprint"
)
$script:PreQuotaAttestationFields = @(
    "schema_version", "attestation_id", "run_id", "role", "repository_head", "branch",
    "authorization_checked", "historical_count", "authorized_increment",
    "maximum_allowed_count", "quota_claim_attempted", "quota_claimed",
    "quota_ledger_path", "evidence_root_creation_attempted", "evidence_root_created",
    "godot_launch_attempted", "godot_launched", "primary_failure_phase",
    "primary_failure_code", "secondary_failure_codes", "task_owned_process_count_after",
    "bootstrap_admission_sha256", "bootstrap_admission_fingerprint", "updated_at_utc",
    "attestation_fingerprint"
)
$script:TargetedQuotaLedgerV3Fields = @(
    "schema_version", "ledger_id", "authorization_id", "task_id", "created_at_utc",
    "run_id", "repository_head", "scenario_fingerprint",
    "authorized_new_diagnostic_count", "diagnostic_count_before",
    "diagnostic_count_after", "diagnostic_count_maximum", "previous_ledger_sha256",
    "historical_invocation_commit", "historical_invocation_blob_sha1",
    "historical_invocation_file_sha256", "bootstrap_admission_path",
    "bootstrap_admission_sha256", "bootstrap_admission_fingerprint",
    "prequota_attestation_path", "role_timeout_policy_sha256",
    "official_attempt_1_claim_sha256", "official_attempt_2_claim_absent",
    "official", "formal", "official_authorization_consumed",
    "orchestrator_script_sha256", "orchestrator_process_id",
    "orchestrator_creation_time_utc_ticks", "claim_nonce", "launch_nonce", "status"
)

function Get-ColdRestoreCurrentProcessCreationTicks {
    try {
        return ([Diagnostics.Process]::GetProcessById($PID).StartTime.ToUniversalTime().Ticks).ToString(
            [Globalization.CultureInfo]::InvariantCulture
        )
    }
    catch {
        throw "prequota_orchestrator_creation_time_unavailable"
    }
}

function Test-ColdRestoreUtcTimestamp {
    param([AllowNull()]$Value)

    if ($Value -isnot [string]) {
        return $false
    }
    $parsed = [DateTime]::MinValue
    return [DateTime]::TryParseExact(
        [string]$Value,
        "O",
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::RoundtripKind,
        [ref]$parsed
    )
}

function Get-ColdRestoreTargetedAuthorizationNameForId {
    param([AllowNull()]$AuthorizationId)

    foreach ($name in $script:TargetedAuthorizationNames) {
        if (cold_restore_authorization_contract_v1\Test-ColdRestoreExactAuthorizationId `
                $name $AuthorizationId) {
            return $name
        }
    }
    throw "authorization_id_invalid"
}

function Get-ColdRestoreTargetedAuthorizationNameForRunId {
    param(
        [AllowNull()]$RunId,
        [AllowNull()]$RepositoryHead
    )

    if ($RunId -isnot [string] -or $RepositoryHead -isnot [string] `
        -or [string]$RepositoryHead -cnotmatch '^[0-9a-f]{40}$') {
        throw "targeted_owner_capture_run_id_invalid"
    }
    foreach ($name in $script:TargetedAuthorizationNames) {
        $expectedRunId = `
            cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationRunId `
                $name ([string]$RepositoryHead)
        if ([string]$RunId -ceq $expectedRunId) {
            return $name
        }
    }
    throw "targeted_owner_capture_run_id_invalid"
}

function Assert-ColdRestoreBootstrapAdmission {
    param([Parameter(Mandatory = $true)]$Value)

    if (-not (cold_restore_attested_process\Test-ColdRestoreExactFieldSet $Value $script:BootstrapAdmissionFields)) {
        throw "prequota_bootstrap_admission_invalid"
    }
    try {
        $authorizationName = Get-ColdRestoreTargetedAuthorizationNameForId $Value.authorization_id
        $authorization = cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationEntry `
            $authorizationName
    }
    catch {
        throw "prequota_bootstrap_admission_invalid"
    }
    if ([int]$Value.schema_version -ne 1 `
        -or [string]$Value.admission_id -cne "PreQuotaOrchestratorBootstrapAdmissionV1" `
        -or -not (Test-ColdRestoreUtcTimestamp $Value.created_at_utc) `
        -or [string]$Value.run_id -cne (cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationRunId $authorizationName ([string]$Value.repository_head)) `
        -or [string]$Value.role -cne "targeted_owner_diagnostic" `
        -or [string]$Value.repository_head -cnotmatch '^[0-9a-f]{40}$' `
        -or [int]$Value.historical_count -ne [int]$authorization.permitted_transition_from `
        -or [int]$Value.authorized_increment -ne [int]$authorization.authorized_increment `
        -or [int]$Value.maximum_allowed_count -ne [int]$authorization.maximum_invocation_count `
        -or $Value.official -isnot [bool] -or [bool]$Value.official `
        -or $Value.formal -isnot [bool] -or [bool]$Value.formal `
        -or [int]$Value.orchestrator_process_id -le 0 `
        -or [string]$Value.orchestrator_creation_time_utc_ticks -cnotmatch '^[1-9][0-9]{0,18}$' `
        -or [string]$Value.invocation_nonce -cnotmatch '^[0-9a-f]{32}$' `
        -or [string]$Value.admission_fingerprint -cne (cold_restore_attested_process\Get-ColdRestoreEvidenceFingerprint $Value "admission_fingerprint")) {
        throw "prequota_bootstrap_admission_invalid"
    }
}

function Assert-ColdRestorePreQuotaAttestation {
    param([Parameter(Mandatory = $true)]$Value)

    if (-not (cold_restore_attested_process\Test-ColdRestoreExactFieldSet $Value $script:PreQuotaAttestationFields)) {
        throw "prequota_attestation_invalid"
    }
    try {
        $authorizationName = Get-ColdRestoreTargetedAuthorizationNameForRunId `
            $Value.run_id $Value.repository_head
        $authorization = cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationEntry `
            $authorizationName
    }
    catch {
        throw "prequota_attestation_invalid"
    }
    if ([int]$Value.schema_version -ne 1 `
        -or [string]$Value.attestation_id -cne "PreQuotaOrchestratorAttestationV1" `
        -or [string]$Value.run_id -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$' `
        -or [string]$Value.role -cne "targeted_owner_diagnostic" `
        -or [string]$Value.repository_head -cnotmatch '^[0-9a-f]{40}$' `
        -or [int]$Value.historical_count -ne [int]$authorization.permitted_transition_from `
        -or [int]$Value.authorized_increment -ne [int]$authorization.authorized_increment `
        -or [int]$Value.maximum_allowed_count -ne [int]$authorization.maximum_invocation_count `
        -or $Value.authorization_checked -isnot [bool] `
        -or $Value.quota_claim_attempted -isnot [bool] `
        -or $Value.quota_claimed -isnot [bool] `
        -or $Value.evidence_root_creation_attempted -isnot [bool] `
        -or $Value.evidence_root_created -isnot [bool] `
        -or $Value.godot_launch_attempted -isnot [bool] `
        -or $Value.godot_launched -isnot [bool] `
        -or [string]$Value.quota_ledger_path -eq "" `
        -or [string]$Value.primary_failure_phase -cnotmatch '^$|^[a-z0-9_]{1,128}$' `
        -or [string]$Value.primary_failure_code -cnotmatch '^$|^[a-z0-9_]{1,128}$' `
        -or $Value.secondary_failure_codes -isnot [System.Array] `
        -or [int]$Value.task_owned_process_count_after -lt -1 `
        -or [string]$Value.bootstrap_admission_sha256 -cnotmatch '^[0-9a-f]{64}$' `
        -or [string]$Value.bootstrap_admission_fingerprint -cnotmatch '^[0-9a-f]{64}$' `
        -or -not (Test-ColdRestoreUtcTimestamp $Value.updated_at_utc) `
        -or [string]$Value.attestation_fingerprint -cne (cold_restore_attested_process\Get-ColdRestoreEvidenceFingerprint $Value "attestation_fingerprint")) {
        throw "prequota_attestation_invalid"
    }
    foreach ($reason in @($Value.secondary_failure_codes)) {
        if (-not (cold_restore_attested_process\Test-ColdRestoreSafeReasonCode $reason)) {
            throw "prequota_attestation_secondary_failure_invalid"
        }
    }
}

function Read-ColdRestorePreQuotaJson {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not [IO.File]::Exists($Path)) {
        throw "prequota_artifact_missing"
    }
    try {
        return [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json -DateKind String
    }
    catch {
        throw "prequota_artifact_json_invalid"
    }
}

function Assert-ColdRestorePreQuotaContextParameters {
    param(
        [Parameter(Mandatory = $true)][string]$GitCommonDirectory,
        [Parameter(Mandatory = $true)][string]$BootstrapRoot,
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$RepositoryHead,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Branch,
        [Parameter(Mandatory = $true)][string]$AuthorizationId,
        [Parameter(Mandatory = $true)][string]$QuotaLedgerPath
    )

    if (-not [IO.Path]::IsPathFullyQualified($GitCommonDirectory) `
        -or -not [IO.Path]::IsPathFullyQualified($BootstrapRoot) `
        -or $RunId -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$' `
        -or $RepositoryHead -cnotmatch '^[0-9a-f]{40}$' `
        -or -not [IO.Path]::IsPathFullyQualified($QuotaLedgerPath) `
        -or $Branch.Length -gt 200 `
        -or $Branch.Contains("`r") `
        -or $Branch.Contains("`n")) {
        throw "prequota_bootstrap_parameter_invalid"
    }
    $authorizationName = Get-ColdRestoreTargetedAuthorizationNameForId $AuthorizationId
    $targetedAuthorization = `
        cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationEntry `
            $authorizationName
    $binding = cold_restore_authorization_contract_v1\Get-ColdRestoreTargetedDiagnosticAuthorizationBinding `
        -GitCommonDirectory $GitCommonDirectory `
        -RepositoryHead $RepositoryHead `
        -AuthorizationName $authorizationName
    if ($RunId -cne [string]$binding.run_id) {
        throw "targeted_owner_capture_run_id_invalid"
    }
    if ([IO.Path]::GetFullPath($QuotaLedgerPath) `
            -cne [IO.Path]::GetFullPath([string]$binding.quota_ledger_path) `
        -or [IO.Path]::GetFullPath($BootstrapRoot) `
            -cne [IO.Path]::GetFullPath([string]$binding.bootstrap_root)) {
        throw "quota_ledger_path_invalid"
    }
    return [pscustomobject][ordered]@{
        authorization_name = $authorizationName
        authorization = $targetedAuthorization
        binding = $binding
    }
}

function New-ColdRestorePreQuotaContext {
    param(
        [Parameter(Mandatory = $true)][string]$GitCommonDirectory,
        [Parameter(Mandatory = $true)][string]$BootstrapRoot,
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$RepositoryHead,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Branch,
        [Parameter(Mandatory = $true)][string]$AuthorizationId,
        [Parameter(Mandatory = $true)][string]$QuotaLedgerPath
    )

    $parameterBinding = Assert-ColdRestorePreQuotaContextParameters `
        -GitCommonDirectory $GitCommonDirectory `
        -BootstrapRoot $BootstrapRoot `
        -RunId $RunId `
        -RepositoryHead $RepositoryHead `
        -Branch $Branch `
        -AuthorizationId $AuthorizationId `
        -QuotaLedgerPath $QuotaLedgerPath
    $authorizationName = [string]$parameterBinding.authorization_name
    $targetedAuthorization = $parameterBinding.authorization
    $ticks = Get-ColdRestoreCurrentProcessCreationTicks
    $nonce = [Guid]::NewGuid().ToString("N")
    $invocationRoot = Join-Path $BootstrapRoot "$RunId\invocations\$PID-$ticks-$nonce"
    $admissionPath = Join-Path $invocationRoot "bootstrap.admission.json"
    $attestationPath = Join-Path $invocationRoot "prequota_orchestrator_attestation.json"
    $admission = [ordered]@{
        schema_version = 1
        admission_id = "PreQuotaOrchestratorBootstrapAdmissionV1"
        created_at_utc = [DateTime]::UtcNow.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
        run_id = $RunId
        role = "targeted_owner_diagnostic"
        repository_head = $RepositoryHead
        branch = $Branch
        authorization_id = $AuthorizationId
        historical_count = [int]$targetedAuthorization.permitted_transition_from
        authorized_increment = [int]$targetedAuthorization.authorized_increment
        maximum_allowed_count = [int]$targetedAuthorization.maximum_invocation_count
        official = $false
        formal = $false
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = $ticks
        invocation_nonce = $nonce
        admission_fingerprint = ""
    }
    $admission.admission_fingerprint = cold_restore_attested_process\Get-ColdRestoreEvidenceFingerprint ([pscustomobject]$admission) "admission_fingerprint"
    Assert-ColdRestoreBootstrapAdmission ([pscustomobject]$admission)
    $admissionSha = cold_restore_attested_process\Write-ColdRestoreAtomicJson $admissionPath ([pscustomobject]$admission)
    $admissionReadback = Read-ColdRestorePreQuotaJson $admissionPath
    Assert-ColdRestoreBootstrapAdmission $admissionReadback
    if ([string]$admissionSha -cne (Get-FileHash -LiteralPath $admissionPath -Algorithm SHA256).Hash.ToLowerInvariant()) {
        throw "prequota_bootstrap_admission_sha256_invalid"
    }
    $attestation = [ordered]@{
        schema_version = 1
        attestation_id = "PreQuotaOrchestratorAttestationV1"
        run_id = $RunId
        role = "targeted_owner_diagnostic"
        repository_head = $RepositoryHead
        branch = $Branch
        authorization_checked = $false
        historical_count = [int]$targetedAuthorization.permitted_transition_from
        authorized_increment = [int]$targetedAuthorization.authorized_increment
        maximum_allowed_count = [int]$targetedAuthorization.maximum_invocation_count
        quota_claim_attempted = $false
        quota_claimed = $false
        quota_ledger_path = [IO.Path]::GetFullPath($QuotaLedgerPath)
        evidence_root_creation_attempted = $false
        evidence_root_created = $false
        godot_launch_attempted = $false
        godot_launched = $false
        primary_failure_phase = ""
        primary_failure_code = ""
        secondary_failure_codes = @()
        task_owned_process_count_after = 0
        bootstrap_admission_sha256 = [string]$admissionSha
        bootstrap_admission_fingerprint = [string]$admission.admission_fingerprint
        updated_at_utc = [DateTime]::UtcNow.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
        attestation_fingerprint = ""
    }
    $attestation.attestation_fingerprint = cold_restore_attested_process\Get-ColdRestoreEvidenceFingerprint ([pscustomobject]$attestation) "attestation_fingerprint"
    Assert-ColdRestorePreQuotaAttestation ([pscustomobject]$attestation)
    $attestationSha = cold_restore_attested_process\Write-ColdRestoreAtomicJson $attestationPath ([pscustomobject]$attestation)
    return [pscustomobject]@{
        invocation_root = $invocationRoot
        admission_path = $admissionPath
        admission_sha256 = [string]$admissionSha
        admission_fingerprint = [string]$admission.admission_fingerprint
        attestation_path = $attestationPath
        attestation_sha256 = [string]$attestationSha
        value = $attestation
        authorization_name = $authorizationName
    }
}

function Update-ColdRestorePreQuotaAttestation {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][Collections.IDictionary]$Updates,
        [AllowNull()]$FailureState
    )

    $candidate = cold_restore_attested_process\ConvertTo-ColdRestoreCanonicalJson $Context.value |
        ConvertFrom-Json -AsHashtable -DateKind String
    foreach ($key in $Updates.Keys) {
        if ($script:PreQuotaAttestationFields -cnotcontains [string]$key `
            -or [string]$key -in @("attestation_fingerprint", "bootstrap_admission_sha256", "bootstrap_admission_fingerprint")) {
            throw "prequota_attestation_update_field_invalid"
        }
        $candidate[[string]$key] = $Updates[$key]
    }
    if ($null -ne $FailureState) {
        $projection = cold_restore_attested_process\Get-ColdRestoreFailureProjection $FailureState
        $candidate.primary_failure_phase = [string]$projection.primary_failure_phase
        $candidate.primary_failure_code = [string]$projection.primary_failure_code
        $candidate.secondary_failure_codes = @($projection.secondary_failure_codes)
    }
    $candidate.updated_at_utc = [DateTime]::UtcNow.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
    $candidate.attestation_fingerprint = ""
    $candidate.attestation_fingerprint = cold_restore_attested_process\Get-ColdRestoreEvidenceFingerprint ([pscustomobject]$candidate) "attestation_fingerprint"
    Assert-ColdRestorePreQuotaAttestation ([pscustomobject]$candidate)
    $sha = cold_restore_attested_process\Write-ColdRestoreReplacingAtomicJson $Context.attestation_path ([pscustomobject]$candidate)
    $readback = Read-ColdRestorePreQuotaJson $Context.attestation_path
    Assert-ColdRestorePreQuotaAttestation $readback
    if ([string]$sha -cne (Get-FileHash -LiteralPath $Context.attestation_path -Algorithm SHA256).Hash.ToLowerInvariant() `
        -or [string]$readback.attestation_fingerprint -cne [string]$candidate.attestation_fingerprint) {
        throw "prequota_attestation_readback_invalid"
    }
    $Context.value = $candidate
    $Context.attestation_sha256 = [string]$sha
    return [pscustomobject]@{
        path = [string]$Context.attestation_path
        sha256 = [string]$sha
        fingerprint = [string]$candidate.attestation_fingerprint
        value = $readback
    }
}

function Assert-ColdRestoreTargetedQuotaLedgerV3 {
    param([Parameter(Mandatory = $true)]$Value)

    if (-not (cold_restore_authorization_contract_v1\Test-ColdRestoreExactAuthorizationId "targeted_owner_capture_diagnostic_v3" $Value.authorization_id)) {
        throw "authorization_id_invalid"
    }
    if ([int]$Value.authorized_new_diagnostic_count -ne [int]$script:TargetedAuthorizationV3.authorized_increment `
        -or [int]$Value.diagnostic_count_before -ne [int]$script:TargetedAuthorizationV3.permitted_transition_from `
        -or [int]$Value.diagnostic_count_after -ne [int]$script:TargetedAuthorizationV3.permitted_transition_to `
        -or [int]$Value.diagnostic_count_maximum -ne [int]$script:TargetedAuthorizationV3.maximum_invocation_count) {
        throw "quota_transition_invalid"
    }
    if (-not (cold_restore_attested_process\Test-ColdRestoreExactFieldSet $Value $script:TargetedQuotaLedgerV3Fields) `
        -or [int]$Value.schema_version -ne 3 `
        -or [string]$Value.ledger_id -cne [string]$script:TargetedAuthorizationV3.ledger_id `
        -or [string]$Value.task_id -cne [string]$script:TargetedAuthorizationV3.task_id `
        -or -not (Test-ColdRestoreUtcTimestamp $Value.created_at_utc) `
        -or [string]$Value.repository_head -cnotmatch '^[0-9a-f]{40}$' `
        -or [string]$Value.run_id -cne (cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationRunId "targeted_owner_capture_diagnostic_v3" ([string]$Value.repository_head)) `
        -or [string]$Value.scenario_fingerprint -cnotmatch '^[0-9a-f]{64}$' `
        -or [string]$Value.previous_ledger_sha256 -cnotmatch '^[0-9a-f]{64}$' `
        -or [string]$Value.historical_invocation_commit -cnotmatch '^[0-9a-f]{40}$' `
        -or [string]$Value.historical_invocation_blob_sha1 -cnotmatch '^[0-9a-f]{40}$' `
        -or [string]$Value.historical_invocation_file_sha256 -cnotmatch '^[0-9a-f]{64}$' `
        -or -not [IO.Path]::IsPathFullyQualified([string]$Value.bootstrap_admission_path) `
        -or [string]$Value.bootstrap_admission_sha256 -cnotmatch '^[0-9a-f]{64}$' `
        -or [string]$Value.bootstrap_admission_fingerprint -cnotmatch '^[0-9a-f]{64}$' `
        -or -not [IO.Path]::IsPathFullyQualified([string]$Value.prequota_attestation_path) `
        -or [string]$Value.role_timeout_policy_sha256 -cnotmatch '^[0-9a-f]{64}$' `
        -or [string]$Value.official_attempt_1_claim_sha256 -cnotmatch '^[0-9a-f]{64}$' `
        -or $Value.official_attempt_2_claim_absent -isnot [bool] -or -not [bool]$Value.official_attempt_2_claim_absent `
        -or $Value.official -isnot [bool] -or [bool]$Value.official `
        -or $Value.formal -isnot [bool] -or [bool]$Value.formal `
        -or $Value.official_authorization_consumed -isnot [bool] -or [bool]$Value.official_authorization_consumed `
        -or [string]$Value.orchestrator_script_sha256 -cnotmatch '^[0-9a-f]{64}$' `
        -or [int]$Value.orchestrator_process_id -le 0 `
        -or [string]$Value.orchestrator_creation_time_utc_ticks -cnotmatch '^[1-9][0-9]{0,18}$' `
        -or [string]$Value.claim_nonce -cnotmatch '^[0-9a-f]{32}$' `
        -or [string]$Value.launch_nonce -cnotmatch '^[0-9a-f]{32}$' `
        -or [string]$Value.claim_nonce -ceq [string]$Value.launch_nonce `
        -or [string]$Value.status -cne "consumed") {
        throw "targeted_owner_capture_quota_v3_invalid"
    }
}

function Publish-ColdRestoreTargetedQuotaLedgerV3 {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Ledger
    )

    Assert-ColdRestoreTargetedQuotaLedgerV3 $Ledger
    try {
        return cold_restore_attested_process\Write-ColdRestoreExclusiveJson $Path $Ledger
    }
    catch {
        $reason = [string]$_.Exception.Message
        if ($reason -eq "exclusive_evidence_create_new_failed" -and [IO.File]::Exists($Path)) {
            try {
                $existing = [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json -DateKind String
                Assert-ColdRestoreTargetedQuotaLedgerV3 $existing
            }
            catch {
                throw "targeted_owner_capture_diagnostic_stale_ledger"
            }
            throw "quota_already_consumed"
        }
        if ($reason -like "exclusive_evidence_consumed_*") {
            throw "targeted_owner_capture_diagnostic_consumed_but_ledger_invalid"
        }
        throw "targeted_owner_capture_diagnostic_quota_ledger_failed"
    }
}

function Assert-ColdRestoreTargetedQuotaLedgerV4 {
    param([Parameter(Mandatory = $true)]$Value)

    $authorizationName = "targeted_owner_capture_diagnostic_v4_importchain"
    $authorization = $script:TargetedAuthorizationV4
    if (-not (cold_restore_authorization_contract_v1\Test-ColdRestoreExactAuthorizationId `
            $authorizationName $Value.authorization_id)) {
        throw "authorization_id_invalid"
    }
    try {
        $null = cold_restore_targeted_ledger_binding_contract_v1\Assert-ColdRestoreTargetedLedgerPublisherValue `
            $Value
    }
    catch {
        if ([string]$_.Exception.Message -cmatch '(authorized_increment|diagnostic_count_(before|after|maximum))_mismatch') {
            throw "quota_transition_invalid"
        }
        throw "targeted_owner_capture_quota_v4_invalid"
    }
    if ([string]$Value.run_id -cne (
            cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationRunId `
                $authorizationName ([string]$Value.repository_head)
        )) {
        throw "targeted_owner_capture_quota_v4_invalid"
    }
}

function Publish-ColdRestoreTargetedQuotaLedgerV4 {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Ledger
    )

    Assert-ColdRestoreTargetedQuotaLedgerV4 $Ledger
    try {
        return cold_restore_attested_process\Write-ColdRestoreExclusiveJson $Path $Ledger
    }
    catch {
        $reason = [string]$_.Exception.Message
        if ($reason -eq "exclusive_evidence_create_new_failed" -and [IO.File]::Exists($Path)) {
            try {
                $existing = [IO.File]::ReadAllText(
                    $Path,
                    [Text.UTF8Encoding]::new($false)
                ) | ConvertFrom-Json -DateKind String
                Assert-ColdRestoreTargetedQuotaLedgerV4 $existing
            }
            catch {
                throw "targeted_owner_capture_diagnostic_stale_ledger"
            }
            throw "quota_already_consumed"
        }
        if ($reason -like "exclusive_evidence_consumed_*") {
            throw "targeted_owner_capture_diagnostic_consumed_but_ledger_invalid"
        }
        throw "targeted_owner_capture_diagnostic_quota_ledger_failed"
    }
}

function Assert-ColdRestoreCurrentTargetedQuotaLedger {
    param([Parameter(Mandatory = $true)]$Value)

    if (-not (cold_restore_authorization_contract_v1\Test-ColdRestoreExactAuthorizationId `
            $script:CurrentTargetedAuthorizationName $Value.authorization_id)) {
        throw "authorization_id_invalid"
    }
    try {
        $null = cold_restore_targeted_ledger_binding_contract_v1\Assert-ColdRestoreTargetedLedgerPublisherValue `
            $Value
    }
    catch {
        if ([string]$_.Exception.Message -cmatch '(authorized_increment|diagnostic_count_(before|after|maximum))_mismatch') {
            throw "quota_transition_invalid"
        }
        throw "targeted_owner_capture_current_quota_invalid"
    }
    if ([string]$Value.run_id -cne (
            cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationRunId `
                $script:CurrentTargetedAuthorizationName ([string]$Value.repository_head)
        )) {
        throw "targeted_owner_capture_current_quota_invalid"
    }
}

function Publish-ColdRestoreCurrentTargetedQuotaLedger {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Ledger
    )

    Assert-ColdRestoreCurrentTargetedQuotaLedger $Ledger
    try {
        return cold_restore_attested_process\Write-ColdRestoreExclusiveJson $Path $Ledger
    }
    catch {
        $reason = [string]$_.Exception.Message
        if ($reason -eq "exclusive_evidence_create_new_failed" -and [IO.File]::Exists($Path)) {
            try {
                $existing = [IO.File]::ReadAllText(
                    $Path,
                    [Text.UTF8Encoding]::new($false)
                ) | ConvertFrom-Json -DateKind String
                Assert-ColdRestoreCurrentTargetedQuotaLedger $existing
            }
            catch {
                throw "targeted_owner_capture_diagnostic_stale_ledger"
            }
            throw "quota_already_consumed"
        }
        if ($reason -like "exclusive_evidence_consumed_*") {
            throw "targeted_owner_capture_diagnostic_consumed_but_ledger_invalid"
        }
        throw "targeted_owner_capture_diagnostic_quota_ledger_failed"
    }
}

function New-ColdRestoreTargetedDiagnosticPreQuotaContext {
    param(
        [Parameter(Mandatory = $true)][string]$GitCommonDirectory,
        [Parameter(Mandatory = $true)][string]$RepositoryHead,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Branch,
        [string]$AuthorizationName = ""
    )

    if ([string]::IsNullOrEmpty($AuthorizationName)) {
        $AuthorizationName = $script:CurrentTargetedAuthorizationName
    }

    $binding = cold_restore_authorization_contract_v1\Get-ColdRestoreTargetedDiagnosticAuthorizationBinding `
        -GitCommonDirectory $GitCommonDirectory `
        -RepositoryHead $RepositoryHead `
        -AuthorizationName $AuthorizationName
    $context = New-ColdRestorePreQuotaContext `
        -GitCommonDirectory $GitCommonDirectory `
        -BootstrapRoot $binding.bootstrap_root `
        -RunId $binding.run_id `
        -RepositoryHead $RepositoryHead `
        -Branch $Branch `
        -AuthorizationId $binding.authorization_id `
        -QuotaLedgerPath $binding.quota_ledger_path
    $context | Add-Member -NotePropertyName authorization_binding -NotePropertyValue $binding
    return $context
}

function New-ColdRestoreTargetedDiagnosticUserArgumentList {
    param(
        [Parameter(Mandatory = $true)][string]$GitCommonDirectory,
        [Parameter(Mandatory = $true)][string]$RepositoryHead,
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$ArtifactRoot,
        [Parameter(Mandatory = $true)][string]$ScenarioFingerprint,
        [Parameter(Mandatory = $true)][string]$TimeoutPolicyFingerprint,
        [Parameter(Mandatory = $true)][string]$QuotaLedgerPath,
        [Parameter(Mandatory = $true)][string]$QuotaLedgerFingerprint,
        [Parameter(Mandatory = $true)][string]$LaunchAttestationPath,
        [Parameter(Mandatory = $true)][string]$LaunchNonce,
        [string]$AuthorizationName = ""
    )

    if ([string]::IsNullOrEmpty($AuthorizationName)) {
        $AuthorizationName = $script:CurrentTargetedAuthorizationName
    }

    $binding = cold_restore_authorization_contract_v1\Get-ColdRestoreTargetedDiagnosticAuthorizationBinding `
        -GitCommonDirectory $GitCommonDirectory `
        -RepositoryHead $RepositoryHead `
        -AuthorizationName $AuthorizationName
    if ($RunId -cne [string]$binding.run_id) {
        throw "targeted_owner_capture_run_id_invalid"
    }
    if ([IO.Path]::GetFullPath($QuotaLedgerPath) -cne [IO.Path]::GetFullPath([string]$binding.quota_ledger_path)) {
        throw "quota_ledger_path_invalid"
    }
    $evidencePrefix = [IO.Path]::GetFullPath([string]$binding.evidence_root).TrimEnd(
        [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar
    ) + [IO.Path]::DirectorySeparatorChar
    if (-not [IO.Path]::IsPathFullyQualified($LaunchAttestationPath) `
        -or -not [IO.Path]::GetFullPath($LaunchAttestationPath).StartsWith(
            $evidencePrefix, [StringComparison]::OrdinalIgnoreCase
        ) `
        -or $ScenarioFingerprint -cnotmatch '^[0-9a-f]{64}$' `
        -or $TimeoutPolicyFingerprint -cnotmatch '^[0-9a-f]{64}$' `
        -or $QuotaLedgerFingerprint -cnotmatch '^[0-9a-f]{64}$' `
        -or $LaunchNonce -cnotmatch '^[0-9a-f]{32}$') {
        throw "targeted_owner_capture_command_authorization_invalid"
    }
    try {
        $ledger = [IO.File]::ReadAllText(
            $QuotaLedgerPath,
            [Text.UTF8Encoding]::new($false)
        ) | ConvertFrom-Json -DateKind String
    }
    catch {
        throw "targeted_owner_capture_launch_context_ledger_invalid"
    }
    $launchContext = `
        cold_restore_targeted_diagnostic_launch_context_v1\New-ColdRestoreTargetedDiagnosticLaunchContext `
            -Ledger $ledger `
            -RepositoryHead $RepositoryHead `
            -RunId $RunId `
            -ScenarioFingerprint $ScenarioFingerprint `
            -QuotaLedgerPath $QuotaLedgerPath `
            -QuotaLedgerSha256 $QuotaLedgerFingerprint `
            -LaunchAttestationPath $LaunchAttestationPath `
            -LaunchNonce $LaunchNonce `
            -RoleTimeoutPolicySha256 $TimeoutPolicyFingerprint
    $arguments = @(
        cold_restore_targeted_diagnostic_launch_context_v1\ConvertTo-ColdRestoreTargetedDiagnosticLaunchArgumentList `
            -Context $launchContext
    )
    $artifactArgument = "--cold-restore-artifact-root=$ArtifactRoot"
    $roleIndex = [Array]::IndexOf($arguments, "--cold-restore-role=producer")
    if ($roleIndex -lt 0) {
        throw "targeted_owner_capture_launch_context_role_missing"
    }
    return @($arguments[0..$roleIndex]) + @($artifactArgument) `
        + @($arguments[($roleIndex + 1)..($arguments.Count - 1)])
}

Export-ModuleMember -Function @(
    "Get-ColdRestoreSafeCollectionCount",
    "New-ColdRestorePrimaryFailureState",
    "Add-ColdRestoreFailureRecord",
    "Get-ColdRestoreFailureProjection",
    "New-ColdRestoreFailureException",
    "Get-ColdRestoreFailureProjectionFromError",
    "Get-ColdRestoreSecondaryFailureCodesFromError",
    "Assert-ColdRestoreBootstrapAdmission",
    "Assert-ColdRestorePreQuotaAttestation",
    "Assert-ColdRestorePreQuotaContextParameters",
    "Assert-ColdRestoreTargetedQuotaLedgerV3",
    "Assert-ColdRestoreTargetedQuotaLedgerV4",
    "Assert-ColdRestoreCurrentTargetedQuotaLedger",
    "New-ColdRestorePreQuotaContext",
    "Update-ColdRestorePreQuotaAttestation",
    "Publish-ColdRestoreTargetedQuotaLedgerV3",
    "Publish-ColdRestoreTargetedQuotaLedgerV4",
    "Publish-ColdRestoreCurrentTargetedQuotaLedger",
    "New-ColdRestoreTargetedDiagnosticPreQuotaContext",
    "New-ColdRestoreTargetedDiagnosticUserArgumentList"
)
