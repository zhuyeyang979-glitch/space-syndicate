Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "cold_restore_attested_process.psm1") -ErrorAction Stop

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

function Assert-ColdRestoreBootstrapAdmission {
    param([Parameter(Mandatory = $true)]$Value)

    if (-not (Test-ColdRestoreExactFieldSet $Value $script:BootstrapAdmissionFields) `
        -or [int]$Value.schema_version -ne 1 `
        -or [string]$Value.admission_id -cne "PreQuotaOrchestratorBootstrapAdmissionV1" `
        -or -not (Test-ColdRestoreUtcTimestamp $Value.created_at_utc) `
        -or [string]$Value.run_id -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$' `
        -or [string]$Value.role -cne "targeted_owner_diagnostic" `
        -or [string]$Value.repository_head -cnotmatch '^[0-9a-f]{40}$' `
        -or [string]$Value.authorization_id -cnotmatch '^[a-z0-9_]{1,128}$' `
        -or [int]$Value.historical_count -ne 2 `
        -or [int]$Value.authorized_increment -ne 1 `
        -or [int]$Value.maximum_allowed_count -ne 3 `
        -or $Value.official -isnot [bool] -or [bool]$Value.official `
        -or $Value.formal -isnot [bool] -or [bool]$Value.formal `
        -or [int]$Value.orchestrator_process_id -le 0 `
        -or [string]$Value.orchestrator_creation_time_utc_ticks -cnotmatch '^[1-9][0-9]{0,18}$' `
        -or [string]$Value.invocation_nonce -cnotmatch '^[0-9a-f]{32}$' `
        -or [string]$Value.admission_fingerprint -cne (Get-ColdRestoreEvidenceFingerprint $Value "admission_fingerprint")) {
        throw "prequota_bootstrap_admission_invalid"
    }
}

function Assert-ColdRestorePreQuotaAttestation {
    param([Parameter(Mandatory = $true)]$Value)

    if (-not (Test-ColdRestoreExactFieldSet $Value $script:PreQuotaAttestationFields) `
        -or [int]$Value.schema_version -ne 1 `
        -or [string]$Value.attestation_id -cne "PreQuotaOrchestratorAttestationV1" `
        -or [string]$Value.run_id -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$' `
        -or [string]$Value.role -cne "targeted_owner_diagnostic" `
        -or [string]$Value.repository_head -cnotmatch '^[0-9a-f]{40}$' `
        -or [int]$Value.historical_count -ne 2 `
        -or [int]$Value.authorized_increment -ne 1 `
        -or [int]$Value.maximum_allowed_count -ne 3 `
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
        -or [string]$Value.attestation_fingerprint -cne (Get-ColdRestoreEvidenceFingerprint $Value "attestation_fingerprint")) {
        throw "prequota_attestation_invalid"
    }
    foreach ($reason in @($Value.secondary_failure_codes)) {
        if (-not (Test-ColdRestoreSafeReasonCode $reason)) {
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

function New-ColdRestorePreQuotaContext {
    param(
        [Parameter(Mandatory = $true)][string]$BootstrapRoot,
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$RepositoryHead,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Branch,
        [Parameter(Mandatory = $true)][string]$AuthorizationId,
        [Parameter(Mandatory = $true)][string]$QuotaLedgerPath
    )

    if (-not [IO.Path]::IsPathFullyQualified($BootstrapRoot) `
        -or $RunId -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$' `
        -or $RepositoryHead -cnotmatch '^[0-9a-f]{40}$' `
        -or $AuthorizationId -cnotmatch '^[a-z0-9_]{1,128}$' `
        -or -not [IO.Path]::IsPathFullyQualified($QuotaLedgerPath)) {
        throw "prequota_bootstrap_parameter_invalid"
    }
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
        historical_count = 2
        authorized_increment = 1
        maximum_allowed_count = 3
        official = $false
        formal = $false
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = $ticks
        invocation_nonce = $nonce
        admission_fingerprint = ""
    }
    $admission.admission_fingerprint = Get-ColdRestoreEvidenceFingerprint ([pscustomobject]$admission) "admission_fingerprint"
    Assert-ColdRestoreBootstrapAdmission ([pscustomobject]$admission)
    $admissionSha = Write-ColdRestoreAtomicJson $admissionPath ([pscustomobject]$admission)
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
        historical_count = 2
        authorized_increment = 1
        maximum_allowed_count = 3
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
    $attestation.attestation_fingerprint = Get-ColdRestoreEvidenceFingerprint ([pscustomobject]$attestation) "attestation_fingerprint"
    Assert-ColdRestorePreQuotaAttestation ([pscustomobject]$attestation)
    $attestationSha = Write-ColdRestoreAtomicJson $attestationPath ([pscustomobject]$attestation)
    return [pscustomobject]@{
        invocation_root = $invocationRoot
        admission_path = $admissionPath
        admission_sha256 = [string]$admissionSha
        admission_fingerprint = [string]$admission.admission_fingerprint
        attestation_path = $attestationPath
        attestation_sha256 = [string]$attestationSha
        value = $attestation
    }
}

function Update-ColdRestorePreQuotaAttestation {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][Collections.IDictionary]$Updates,
        [AllowNull()]$FailureState
    )

    $candidate = ConvertTo-ColdRestoreCanonicalJson $Context.value |
        ConvertFrom-Json -AsHashtable -DateKind String
    foreach ($key in $Updates.Keys) {
        if ($script:PreQuotaAttestationFields -cnotcontains [string]$key `
            -or [string]$key -in @("attestation_fingerprint", "bootstrap_admission_sha256", "bootstrap_admission_fingerprint")) {
            throw "prequota_attestation_update_field_invalid"
        }
        $candidate[[string]$key] = $Updates[$key]
    }
    if ($null -ne $FailureState) {
        $projection = Get-ColdRestoreFailureProjection $FailureState
        $candidate.primary_failure_phase = [string]$projection.primary_failure_phase
        $candidate.primary_failure_code = [string]$projection.primary_failure_code
        $candidate.secondary_failure_codes = @($projection.secondary_failure_codes)
    }
    $candidate.updated_at_utc = [DateTime]::UtcNow.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
    $candidate.attestation_fingerprint = ""
    $candidate.attestation_fingerprint = Get-ColdRestoreEvidenceFingerprint ([pscustomobject]$candidate) "attestation_fingerprint"
    Assert-ColdRestorePreQuotaAttestation ([pscustomobject]$candidate)
    $sha = Write-ColdRestoreReplacingAtomicJson $Context.attestation_path ([pscustomobject]$candidate)
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

    if (-not (Test-ColdRestoreExactFieldSet $Value $script:TargetedQuotaLedgerV3Fields) `
        -or [int]$Value.schema_version -ne 3 `
        -or [string]$Value.ledger_id -cne "Alpha04C.TargetedOwnerCaptureDiagnosticQuotaLedgerV3" `
        -or [string]$Value.authorization_id -cne "alpha04c-targeted-owner-capture-diagnostic-v3" `
        -or [string]$Value.task_id -cne "ALPHA_0_4_C_FINAL_HARNESS_REPAIR_REHEARSAL_OFFICIAL_ATTEMPT_2_AND_MAIN_LANDING" `
        -or -not (Test-ColdRestoreUtcTimestamp $Value.created_at_utc) `
        -or [string]$Value.run_id -cnotmatch '^alpha04c-owner-capture-diagnostic-[0-9a-f]{12}$' `
        -or [string]$Value.repository_head -cnotmatch '^[0-9a-f]{40}$' `
        -or [string]$Value.scenario_fingerprint -cnotmatch '^[0-9a-f]{64}$' `
        -or [int]$Value.authorized_new_diagnostic_count -ne 1 `
        -or [int]$Value.diagnostic_count_before -ne 2 `
        -or [int]$Value.diagnostic_count_after -ne 3 `
        -or [int]$Value.diagnostic_count_maximum -ne 3 `
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
        return Write-ColdRestoreExclusiveJson $Path $Ledger
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
            throw "targeted_owner_capture_diagnostic_already_consumed"
        }
        if ($reason -like "exclusive_evidence_consumed_*") {
            throw "targeted_owner_capture_diagnostic_consumed_but_ledger_invalid"
        }
        throw "targeted_owner_capture_diagnostic_quota_ledger_failed"
    }
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
    "Assert-ColdRestoreTargetedQuotaLedgerV3",
    "New-ColdRestorePreQuotaContext",
    "Update-ColdRestorePreQuotaAttestation",
    "Publish-ColdRestoreTargetedQuotaLedgerV3"
)
