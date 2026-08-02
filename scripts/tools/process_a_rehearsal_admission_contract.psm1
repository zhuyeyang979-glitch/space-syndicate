Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ColdRestoreModuleLoader = Import-Module `
    (Join-Path $PSScriptRoot "cold_restore_module_loader.psm1") `
    -PassThru `
    -ErrorAction Stop
$script:ColdRestoreAuthorizationModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
    -Path (Join-Path $PSScriptRoot "cold_restore_authorization_contract_v1.psm1") `
    -RequiredCommands @(
        "Get-ColdRestoreAuthorizationContract",
        "Get-ColdRestoreAuthorizationEntry",
        "Get-ColdRestoreCurrentTargetedDiagnosticAuthorizationName",
        "Get-ColdRestoreAuthorizationRunId"
    )
$script:AuthorizationContract = `
    cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationContract
$script:RehearsalAuthorization = $script:AuthorizationContract.process_a_save_completion_rehearsal_v1
$script:TargetedDiagnosticAuthorizationName = `
    cold_restore_authorization_contract_v1\Get-ColdRestoreCurrentTargetedDiagnosticAuthorizationName
$script:TargetedDiagnosticAuthorization = `
    cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationEntry `
        $script:TargetedDiagnosticAuthorizationName
$script:OfficialAttempt2Authorization = $script:AuthorizationContract.official_attempt_2
$script:TargetedLedgerBindingModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
    -Path (Join-Path $PSScriptRoot "cold_restore_targeted_ledger_binding_contract_v1.psm1") `
    -RequiredCommands @(
        "Assert-ColdRestoreTargetedLedgerPublisherValue"
    )

$script:ColdRestoreAttestedProcessModulePath = Join-Path $PSScriptRoot "cold_restore_attested_process.psm1"
if (-not [IO.File]::Exists($script:ColdRestoreAttestedProcessModulePath)) {
    throw "process_a_rehearsal_timeout_policy_validator_missing"
}
try {
    $script:ColdRestoreAttestedProcessModule = `
        cold_restore_module_loader\Import-ColdRestoreModuleOnce `
            -Path $script:ColdRestoreAttestedProcessModulePath `
            -RequiredCommands @(
                "Get-ColdRestoreEvidenceFingerprint",
                "Test-ColdRestoreRoleTimeoutPolicy"
            )
}
catch {
    throw "process_a_rehearsal_timeout_policy_validator_import_failed"
}
$script:ColdRestoreRoleTimeoutPolicyValidator =
    $script:ColdRestoreAttestedProcessModule.ExportedCommands["Test-ColdRestoreRoleTimeoutPolicy"]
if ($null -eq $script:ColdRestoreRoleTimeoutPolicyValidator) {
    throw "process_a_rehearsal_timeout_policy_validator_missing"
}

$script:ContractId = "Alpha04C.ProcessARehearsalAdmissionContractV1"
$script:AdmissionLedgerId = "ProcessARehearsalAdmissionLedgerV3"
$script:LaunchLedgerId = "ProcessARehearsalLaunchLedgerV1"
$script:AuthorizationId = [string]$script:RehearsalAuthorization.authorization_id
$script:RehearsalRunIdPrefix = [string]$script:RehearsalAuthorization.run_id_prefix
$script:TargetedDiagnosticAuthorizationId = [string]$script:TargetedDiagnosticAuthorization.authorization_id
$script:OfficialAttempt1ClaimSha256 = [string]$script:OfficialAttempt2Authorization.attempt_1_claim_sha256
$script:ChallengeDepth = 1
$script:Seed = 900626424
$script:LocalPlayerCount = 1
$script:AiPlayerCount = 3

$script:SectionOrder = @(
    "ruleset", "region_infrastructure", "region_supply", "commodity_flow",
    "routes", "player_mana", "commodity_belt_visibility", "card_inventory",
    "player_organization", "monsters", "military", "weather",
    "card_resolution_queue", "card_resolution_execution", "card_resolution_history",
    "ai", "bankruptcy_neutral_estate", "victory_control", "session"
)
$script:OwnerOrder = @(
    "ruleset_runtime", "public_facility_region", "region_supply", "commodity_flow",
    "route_network", "player_mana", "commodity_belt_visibility", "card_inventory",
    "player_organization", "monster_runtime", "military_runtime", "weather_runtime",
    "card_resolution_queue", "card_resolution_execution", "card_resolution_history",
    "ai_runtime", "bankruptcy_neutral_estate", "victory_control", "game_session"
)

$script:DiagnosticFields = @(
    "schema_version", "diagnostic_id", "run_id", "repository_head", "official", "formal",
    "scenario_identity", "scenario_identity_attested", "scenario_identity_failure",
    "registry_binding_attested",
    "harness_or_scenario_failure_attested", "diagnostic_phase_timeline",
    "last_completed_diagnostic_phase", "current_diagnostic_phase", "next_expected_diagnostic_phase",
    "owner_audit_started", "owner_audit_completed", "first_owner_capture_index",
    "last_completed_owner_capture_index", "owner_capture_attempted_count",
    "owner_capture_succeeded_count", "owner_capture_failed_count", "owner_capture_skipped_count",
    "owner_capture_rows", "first_failure", "owner_capture_failure_attested",
    "post_capture_validation", "post_capture_failure", "safety_green", "save_file_exists",
    "official_claim_path_present", "evidence_fingerprint"
)
$script:ScenarioIdentityFields = @(
    "schema_version", "identity_id", "run_id", "repository_head", "ruleset_id",
    "ruleset_fingerprint", "challenge_depth", "run_seed_tagged_int64",
    "session_seed_tagged_int64", "scenario_fingerprint", "local_player_count",
    "ai_player_count", "roster_fingerprint", "session_id", "session_generation",
    "session_plan_fingerprint", "world_revision", "runtime_composition_fingerprint",
    "save_registry_fingerprint", "user_data_path_fingerprint", "diagnostic_role",
    "identity_fingerprint"
)
$script:TimelineFields = @(
    "schema_version", "timeline_id", "run_id", "repository_head", "phase_rows",
    "last_completed_phase", "current_phase", "next_expected_phase", "evidence_fingerprint"
)
$script:TimelineRowFields = @(
    "sequence", "phase_id", "owner_index", "completed_monotonic_ms", "success",
    "reason_code", "evidence_fingerprint"
)
$script:OwnerRowFields = @(
    "owner_index", "section_id", "owner_id", "owner_path", "capture_started",
    "capture_completed", "capture_result_kind", "state_version",
    "payload_fingerprint", "payload_pure_data", "elapsed_milliseconds",
    "mutation_count", "rng_draw_delta", "world_time_delta", "public_log_delta",
    "reason_code", "private_payload_redacted", "row_evidence_fingerprint"
)
$script:ChildCompletionFields = @(
    "schema_version", "run_id", "role", "repository_head", "scenario_fingerprint",
    "official", "formal", "qualification_completed", "qualification_green",
    "product_blocker", "queue_count", "queue_revision", "queue_trigger_actor",
    "queue_trigger_semantic_action_id", "queue_trigger_card_semantic_id",
    "queue_trigger_target_fingerprint", "save_written", "official_count_consumed",
    "product_mutation_count", "direct_authority_mutation_count", "queue_injection_count",
    "final_reason_code", "evidence_fingerprint", "child_ready_to_exit"
)
$script:ParentExitFieldsV2 = @(
    "schema_version", "run_id", "role", "child_pid", "observed_exit", "exit_code",
    "timed_out", "terminated_by_parent", "stdout_sha256", "stderr_sha256",
    "child_attestation_found", "child_attestation_fingerprint",
    "child_attestation_valid", "task_owned_process_count_after",
    "unrelated_preexisting_process_count", "wrapper_exit_green", "wrapper_reason_code",
    "policy_role", "timeout_policy_fingerprint", "absolute_timeout_seconds",
    "no_progress_timeout_seconds", "timeout_kind", "progress_heartbeat_found",
    "progress_heartbeat_valid", "progress_heartbeat_sequence",
    "progress_heartbeat_fingerprint", "progress_semantic_fingerprint", "progress_phase",
    "progress_last_evidence_write_time", "task_owned_process_identity_fingerprint"
)
$script:DiagnosticManifestFields = @(
    "schema_version", "visibility_scope", "run_id", "process_role", "process_id", "head_sha",
    "scenario_fingerprint",
    "slot_id", "slot_state", "source_sections_digest", "restored_sections_digest",
    "saved_sections_digest", "source_write_id", "write_id", "source_write_fingerprint",
    "section_count", "preflight_count", "owner_apply_count", "registry_apply_count",
    "registry_commit_count", "registry_rebind_count", "partial_restore_state_count",
    "save_capture_world_delta", "save_capture_rng_delta",
    "save_capture_log_delta", "rng_draw_count_before", "rng_draw_count_after",
    "restore_rng_draw_delta", "restore_world_time_delta", "restore_public_log_delta",
    "restore_sale_receipt_delta", "restore_economic_reward_delta", "restore_ai_action_delta",
    "restore_player_action_delta", "restore_notification_delta", "restore_private_feedback_delta",
    "human_action_count",
    "commodity_action_count", "ai_action_count", "sale_receipt_count", "normal_card_count",
    "commodity_card_count", "commodity_claim_count", "facility_count", "route_count",
    "military_unit_count", "queue_entry_count", "weather_region_count",
    "ai_nondefault_state_count", "queue_trigger_resolution_id",
    "queue_trigger_stable_target_fingerprint", "queue_target_pending_before_resume",
    "queue_target_pending_after_resume", "queue_target_completed_before_resume",
    "queue_target_completed_after_resume", "queue_target_history_before_resume",
    "queue_target_history_after_resume", "queue_target_execution_finalize_delta",
    "queue_target_history_append_delta", "queue_target_history_duplicate_delta",
    "queue_target_transition_duplicate_delta", "queue_target_inventory_queue_commit_delta",
    "queue_target_public_log_duplicate_delta", "queue_target_public_log_collision_delta",
    "duplicate_queue_entry_count", "duplicate_facility_creation_count",
    "duplicate_card_consumption_count", "duplicate_cost_consumption_count",
    "duplicate_sale_receipt_count",
    "world_fingerprint_match", "rng_cursor_match", "ai_state_fingerprint_match",
    "card_inventory_fingerprint_match", "queue_fingerprint_match",
    "generation_2_recapture_fingerprint_match", "generation_2_rng_cursor_match",
    "generation_2_duplicate_transaction_count",
    "victory_unresolved_before_save", "production_surface_ready", "victory_state_sequence",
    "final_settlement_count", "final_settlement_presentation_count",
    "final_settlement_public_log_count", "terminal_quiescent_frames", "terminal_world_delta",
    "terminal_rng_draw_delta", "generation", "backup_created", "save_readback_green",
    "save_fingerprint_parity", "write_fingerprint", "elapsed_ms", "success",
    "failure_code"
)
$script:DiagnosticManifestIntegerFields = @(
    "schema_version", "process_id", "section_count", "preflight_count", "owner_apply_count",
    "registry_apply_count", "registry_commit_count", "registry_rebind_count",
    "partial_restore_state_count", "save_capture_world_delta", "save_capture_rng_delta",
    "save_capture_log_delta", "rng_draw_count_before", "rng_draw_count_after",
    "restore_rng_draw_delta", "restore_world_time_delta", "restore_public_log_delta",
    "restore_sale_receipt_delta", "restore_economic_reward_delta", "restore_ai_action_delta",
    "restore_player_action_delta", "restore_notification_delta", "restore_private_feedback_delta",
    "human_action_count",
    "commodity_action_count", "ai_action_count", "sale_receipt_count", "normal_card_count",
    "commodity_card_count", "commodity_claim_count", "facility_count", "route_count",
    "military_unit_count", "queue_entry_count", "weather_region_count",
    "ai_nondefault_state_count", "queue_trigger_resolution_id",
    "queue_target_pending_before_resume", "queue_target_pending_after_resume",
    "queue_target_completed_before_resume", "queue_target_completed_after_resume",
    "queue_target_history_before_resume", "queue_target_history_after_resume",
    "queue_target_execution_finalize_delta", "queue_target_history_append_delta",
    "queue_target_history_duplicate_delta", "queue_target_transition_duplicate_delta",
    "queue_target_inventory_queue_commit_delta", "queue_target_public_log_duplicate_delta",
    "queue_target_public_log_collision_delta", "duplicate_queue_entry_count",
    "duplicate_facility_creation_count", "duplicate_card_consumption_count",
    "duplicate_cost_consumption_count", "duplicate_sale_receipt_count",
    "generation_2_duplicate_transaction_count", "final_settlement_count",
    "final_settlement_presentation_count", "final_settlement_public_log_count",
    "terminal_quiescent_frames", "terminal_world_delta", "terminal_rng_draw_delta",
    "generation", "elapsed_ms"
)
$script:AdmissionEvidenceBindingFields = @(
    "schema_version", "binding_id", "diagnostic_id", "diagnostic_run_id",
    "repository_head", "scenario_fingerprint", "diagnostic_artifact_sha256",
    "diagnostic_evidence_fingerprint", "owner_capture_succeeded_count",
    "owner_capture_failed_count", "post_capture_validation", "safety_green",
    "diagnostic_quota_ledger_sha256", "diagnostic_launch_attestation_sha256",
    "diagnostic_manifest_sha256", "diagnostic_engine_process_id",
    "diagnostic_engine_creation_time_utc_ticks", "diagnostic_child_attestation_sha256",
    "diagnostic_child_attestation_fingerprint", "diagnostic_parent_attestation_sha256",
    "diagnostic_stdout_sha256", "diagnostic_stderr_sha256",
    "diagnostic_timeout_policy_fingerprint", "diagnostic_parent_exit_green",
    "diagnostic_bootstrap_admission_sha256", "diagnostic_bootstrap_admission_fingerprint",
    "diagnostic_prequota_attestation_sha256", "diagnostic_prequota_attestation_fingerprint",
    "binding_fingerprint"
)
$script:AdmissionLedgerFields = @(
    "schema_version", "ledger_id", "contract_id", "authorization_id", "status",
    "created_at_utc", "run_id", "repository_head", "scenario_fingerprint",
    "timeout_policy_fingerprint", "prerequisite_evidence_fingerprint",
    "challenge_depth", "seed", "local_player_count",
    "ai_player_count", "rehearsal_only", "nonofficial", "official", "formal",
    "official_authorization_consumed", "authorized_rehearsal_count",
    "rehearsal_count_before", "rehearsal_count_after", "admission_evidence_id",
    "admission_evidence_run_id", "admission_evidence_sha256",
    "admission_evidence_fingerprint", "admission_evidence_green",
    "diagnostic_quota_ledger_sha256", "diagnostic_launch_attestation_sha256",
    "diagnostic_manifest_sha256", "diagnostic_engine_process_id",
    "diagnostic_engine_creation_time_utc_ticks", "diagnostic_child_attestation_sha256",
    "diagnostic_child_attestation_fingerprint", "diagnostic_parent_attestation_sha256",
    "diagnostic_stdout_sha256", "diagnostic_stderr_sha256",
    "diagnostic_bootstrap_admission_sha256", "diagnostic_bootstrap_admission_fingerprint",
    "diagnostic_prequota_attestation_sha256", "diagnostic_prequota_attestation_fingerprint",
    "official_attempt_1_claim_relative_path", "official_attempt_1_claim_sha256",
    "official_attempt_1_claim_immutable", "official_attempt_2_claim_absent",
    "official_claim_inventory_count", "official_claim_inventory_fingerprint",
    "process_role", "orchestrator_process_id", "orchestrator_creation_time_utc_ticks",
    "claim_nonce", "launch_nonce", "ledger_fingerprint"
)
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
$script:LaunchAuthorizationFields = @(
    "authorization_id", "claim_fingerprint", "claim_nonce", "source_head_sha",
    "scenario_fingerprint", "run_id", "process_role", "launch_nonce",
    "orchestrator_process_id", "orchestrator_creation_time_utc_ticks"
)
$script:LaunchAttestationFields = @(
    "schema_version", "authorization_id", "claim_fingerprint", "claim_nonce",
    "source_head_sha", "scenario_fingerprint", "run_id", "process_role",
    "launch_nonce", "orchestrator_process_id", "orchestrator_creation_time_utc_ticks",
    "wrapper_process_id", "wrapper_parent_process_id", "wrapper_creation_time_utc_ticks",
    "engine_process_id", "engine_parent_process_id", "engine_creation_time_utc_ticks",
    "status"
)
$script:LaunchLedgerFields = @(
    "schema_version", "ledger_id", "contract_id", "authorization_id", "status",
    "created_at_utc", "admission_ledger_sha256", "claim_fingerprint", "run_id", "repository_head",
    "scenario_fingerprint", "timeout_policy_fingerprint", "challenge_depth", "seed",
    "local_player_count", "ai_player_count", "rehearsal_only", "nonofficial",
    "official", "formal", "official_authorization_consumed",
    "admission_evidence_sha256", "admission_evidence_fingerprint",
    "official_attempt_1_claim_sha256", "official_attempt_2_claim_absent",
    "official_claim_inventory_fingerprint", "process_role", "claim_nonce", "launch_nonce",
    "orchestrator_process_id", "orchestrator_creation_time_utc_ticks",
    "wrapper_process_id", "wrapper_parent_process_id", "wrapper_creation_time_utc_ticks",
    "engine_process_id", "engine_parent_process_id", "engine_creation_time_utc_ticks",
    "launch_attestation_sha256", "ledger_fingerprint"
)

function ConvertTo-ProcessARehearsalCanonicalJson {
    param([AllowNull()]$Value)

    if ($null -eq $Value) {
        return "null"
    }
    if ($Value -is [bool]) {
        return $(if ($Value) { "true" } else { "false" })
    }
    if ($Value -is [string] -or $Value -is [char]) {
        return ([string]$Value | ConvertTo-Json -Compress)
    }
    if ($Value -is [byte] -or $Value -is [sbyte] `
        -or $Value -is [int16] -or $Value -is [uint16] `
        -or $Value -is [int32] -or $Value -is [uint32] `
        -or $Value -is [int64] -or $Value -is [uint64]) {
        return [Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [float] -or $Value -is [double] -or $Value -is [decimal]) {
        return ([IFormattable]$Value).ToString("R", [Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [Collections.IDictionary]) {
        $members = foreach ($key in @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive)) {
            "$(ConvertTo-ProcessARehearsalCanonicalJson $key):$(ConvertTo-ProcessARehearsalCanonicalJson $Value[$key])"
        }
        return "{$($members -join ',')}"
    }
    if ($Value -is [Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = foreach ($item in $Value) {
            ConvertTo-ProcessARehearsalCanonicalJson $item
        }
        return "[$($items -join ',')]"
    }
    $properties = @($Value.PSObject.Properties | Where-Object { $_.MemberType -in @("NoteProperty", "Property") })
    if ($properties.Count -gt 0) {
        $members = foreach ($property in @($properties | Sort-Object Name -CaseSensitive)) {
            "$(ConvertTo-ProcessARehearsalCanonicalJson $property.Name):$(ConvertTo-ProcessARehearsalCanonicalJson $property.Value)"
        }
        return "{$($members -join ',')}"
    }
    if ($Value -is [pscustomobject]) {
        return "{}"
    }
    throw "process_a_rehearsal_canonical_json_type_invalid"
}

function Get-ProcessARehearsalTextSha256 {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    return ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))).ToLowerInvariant()
}

function Get-ProcessARehearsalFingerprint {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [string]$OmittedField = ""
    )

    if ($OmittedField -eq "") {
        return Get-ProcessARehearsalTextSha256 (ConvertTo-ProcessARehearsalCanonicalJson $Value)
    }
    $copy = [ordered]@{}
    if ($Value -is [Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            if ([string]$key -cne $OmittedField) {
                $copy[[string]$key] = $Value[$key]
            }
        }
    }
    else {
        foreach ($property in $Value.PSObject.Properties) {
            if ($property.Name -cne $OmittedField) {
                $copy[$property.Name] = $property.Value
            }
        }
    }
    return Get-ProcessARehearsalTextSha256 (ConvertTo-ProcessARehearsalCanonicalJson $copy)
}

function Test-ProcessARehearsalExactFieldSet {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string[]]$ExpectedFields
    )

    if ($null -eq $Value) {
        return $false
    }
    $actual = if ($Value -is [Collections.IDictionary]) {
        @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive)
    }
    else {
        @($Value.PSObject.Properties.Name | Sort-Object -CaseSensitive)
    }
    $expected = @($ExpectedFields | Sort-Object -CaseSensitive)
    return @(Compare-Object -ReferenceObject $expected -DifferenceObject $actual -CaseSensitive).Count -eq 0
}

function Test-ProcessARehearsalInteger {
    param([AllowNull()]$Value)

    return $Value -is [byte] -or $Value -is [sbyte] `
        -or $Value -is [int16] -or $Value -is [uint16] `
        -or $Value -is [int32] -or $Value -is [uint32] `
        -or $Value -is [int64] -or $Value -is [uint64]
}

function Test-ProcessARehearsalFingerprintValue {
    param([AllowNull()]$Value)

    return $Value -is [string] -and [string]$Value -cmatch '^[0-9a-f]{64}$'
}

function Test-ProcessARehearsalRunId {
    param([AllowNull()]$Value)

    return $Value -is [string] `
        -and ([string]$Value).Length -ge 1 `
        -and ([string]$Value).Length -le 128 `
        -and [string]$Value -cmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$'
}

function Test-ProcessARehearsalEmptyObject {
    param([AllowNull()]$Value)

    if ($null -eq $Value) {
        return $false
    }
    if ($Value -is [Collections.IDictionary]) {
        return $Value.Count -eq 0
    }
    return @($Value.PSObject.Properties).Count -eq 0
}

function Test-ProcessARehearsalCreationTicks {
    param([AllowNull()]$Value)

    if ($Value -isnot [string] -or [string]$Value -cnotmatch '^[1-9][0-9]{0,18}$') {
        return $false
    }
    $parsed = [int64]0
    return [int64]::TryParse([string]$Value, [ref]$parsed) -and ($parsed % 10) -eq 0
}

function Test-ProcessARehearsalUtcTimestamp {
    param([AllowNull()]$Value)

    if ($Value -isnot [string]) {
        return $false
    }
    $parsed = [DateTimeOffset]::MinValue
    return [DateTimeOffset]::TryParse(
        [string]$Value,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::RoundtripKind,
        [ref]$parsed
    ) -and $parsed.Offset -eq [TimeSpan]::Zero
}

function Read-ProcessARehearsalJsonArtifact {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not [IO.File]::Exists($Path)) {
        throw "process_a_rehearsal_artifact_missing"
    }
    try {
        $text = [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false))
        if ([string]::IsNullOrWhiteSpace($text)) {
            throw "empty"
        }
        $value = $text | ConvertFrom-Json -DateKind String
        if ($null -eq $value -or $value -is [System.Array]) {
            throw "root"
        }
        return [pscustomobject]@{
            path = [IO.Path]::GetFullPath($Path)
            text = $text
            value = $value
            sha256 = Get-ProcessARehearsalTextSha256 $text
        }
    }
    catch {
        if ([string]$_.Exception.Message -eq "process_a_rehearsal_artifact_missing") {
            throw
        }
        throw "process_a_rehearsal_artifact_json_invalid"
    }
}

function Write-ProcessARehearsalExclusiveAtomicJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $parent = Split-Path -Parent $fullPath
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    $tempPath = Join-Path $parent (".{0}.tmp.{1}.{2}" -f [IO.Path]::GetFileName($fullPath), $PID, [Guid]::NewGuid().ToString("N"))
    $json = ConvertTo-ProcessARehearsalCanonicalJson $Value
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
    $sha256 = Get-ProcessARehearsalTextSha256 $json
    $published = $false
    try {
        $stream = [IO.FileStream]::new(
            $tempPath,
            [IO.FileMode]::CreateNew,
            [IO.FileAccess]::Write,
            [IO.FileShare]::None,
            4096,
            [IO.FileOptions]::WriteThrough
        )
        try {
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush($true)
        }
        finally {
            $stream.Dispose()
        }
        $tempReadback = [IO.File]::ReadAllText($tempPath, [Text.UTF8Encoding]::new($false))
        if ($tempReadback -cne $json) {
            throw "process_a_rehearsal_atomic_temp_readback_failed"
        }
        $null = $tempReadback | ConvertFrom-Json
        try {
            [IO.File]::Move($tempPath, $fullPath)
            $published = $true
        }
        catch {
            if ([IO.File]::Exists($fullPath)) {
                throw "process_a_rehearsal_atomic_target_exists"
            }
            throw "process_a_rehearsal_atomic_publish_failed"
        }
    }
    finally {
        if (-not $published -and [IO.File]::Exists($tempPath)) {
            [IO.File]::Delete($tempPath)
        }
    }
    return $sha256
}

function Get-ProcessARehearsalCurrentCreationTicks {
    $process = $null
    try {
        $process = [Diagnostics.Process]::GetProcessById($PID)
        $ticks = $process.StartTime.ToUniversalTime().Ticks
        return ($ticks - ($ticks % 10)).ToString([Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        throw "process_a_rehearsal_orchestrator_identity_unavailable"
    }
    finally {
        if ($null -ne $process) {
            $process.Dispose()
        }
    }
}

function Assert-ProcessARehearsalTaggedInt64 {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [string]$ExpectedValue = ""
    )

    if (-not (Test-ProcessARehearsalExactFieldSet $Value @('$codec', 'value')) `
        -or [string]$Value.'$codec' -cne "Int64" `
        -or [string]$Value.value -cnotmatch '^-?(0|[1-9][0-9]*)$' `
        -or ($ExpectedValue -ne "" -and [string]$Value.value -cne $ExpectedValue)) {
        throw "process_a_rehearsal_admission_evidence_seed_invalid"
    }
}

function Assert-ProcessARehearsalDiagnosticManifest {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$ExpectedRunId,
        [Parameter(Mandatory = $true)][string]$ExpectedRepositoryHead,
        [Parameter(Mandatory = $true)][string]$ExpectedScenarioFingerprint,
        [Parameter(Mandatory = $true)][int]$ExpectedEngineProcessId,
        [Parameter(Mandatory = $true)][string]$ExpectedFailureCode
    )

    if (-not (Test-ProcessARehearsalExactFieldSet $Manifest $script:DiagnosticManifestFields)) {
        throw "process_a_rehearsal_diagnostic_manifest_field_set_invalid"
    }
    foreach ($field in $script:DiagnosticManifestIntegerFields) {
        if (-not (Test-ProcessARehearsalInteger $Manifest.$field) -or [int64]$Manifest.$field -lt 0) {
            throw "process_a_rehearsal_diagnostic_manifest_integer_invalid"
        }
    }
    foreach ($field in @(
        "visibility_scope", "run_id", "process_role", "head_sha", "scenario_fingerprint", "slot_id", "slot_state",
        "source_sections_digest", "restored_sections_digest", "saved_sections_digest",
        "source_write_id", "write_id", "source_write_fingerprint", "write_fingerprint",
        "queue_trigger_stable_target_fingerprint", "failure_code"
    )) {
        if ($Manifest.$field -isnot [string]) {
            throw "process_a_rehearsal_diagnostic_manifest_string_invalid"
        }
    }
    if ([int]$Manifest.schema_version -ne 4 `
        -or [string]$Manifest.visibility_scope -cne "qa_allowlisted" `
        -or [string]$Manifest.run_id -cne $ExpectedRunId `
        -or [string]$Manifest.process_role -cne "producer" `
        -or [int]$Manifest.process_id -ne $ExpectedEngineProcessId `
        -or [string]$Manifest.head_sha -cne $ExpectedRepositoryHead `
        -or [string]$Manifest.scenario_fingerprint -cne $ExpectedScenarioFingerprint `
        -or [string]$Manifest.slot_id -cne "current_run" `
        -or [string]$Manifest.slot_state -cne "failed") {
        throw "process_a_rehearsal_diagnostic_manifest_identity_invalid"
    }
    foreach ($field in @(
        "source_sections_digest", "restored_sections_digest", "saved_sections_digest",
        "source_write_fingerprint", "write_fingerprint", "queue_trigger_stable_target_fingerprint"
    )) {
        if ($Manifest.$field -isnot [string] `
            -or ([string]$Manifest.$field -ne "" -and -not (Test-ProcessARehearsalFingerprintValue $Manifest.$field))) {
            throw "process_a_rehearsal_diagnostic_manifest_digest_invalid"
        }
    }
    foreach ($field in @("source_write_id", "write_id")) {
        if ($Manifest.$field -isnot [string] -or [string]$Manifest.$field -cnotmatch '^[A-Za-z0-9._:-]{0,128}$') {
            throw "process_a_rehearsal_diagnostic_manifest_write_id_invalid"
        }
    }
    foreach ($field in @(
        "victory_unresolved_before_save", "production_surface_ready", "backup_created",
        "save_readback_green", "save_fingerprint_parity", "world_fingerprint_match",
        "rng_cursor_match", "ai_state_fingerprint_match", "card_inventory_fingerprint_match",
        "queue_fingerprint_match", "generation_2_recapture_fingerprint_match",
        "generation_2_rng_cursor_match", "success"
    )) {
        if ($Manifest.$field -isnot [bool]) {
            throw "process_a_rehearsal_diagnostic_manifest_boolean_invalid"
        }
    }
    foreach ($field in @(
        "world_fingerprint_match", "rng_cursor_match", "ai_state_fingerprint_match",
        "card_inventory_fingerprint_match", "queue_fingerprint_match",
        "generation_2_recapture_fingerprint_match", "generation_2_rng_cursor_match"
    )) {
        if ([bool]$Manifest.$field) {
            throw "process_a_rehearsal_diagnostic_manifest_role_evidence_non_neutral"
        }
    }
    if ([int]$Manifest.generation_2_duplicate_transaction_count -ne 0) {
        throw "process_a_rehearsal_diagnostic_manifest_role_evidence_non_neutral"
    }
    if ([bool]$Manifest.success `
        -or $Manifest.victory_state_sequence -isnot [System.Array] `
        -or @($Manifest.victory_state_sequence).Count -gt 12 `
        -or $Manifest.failure_code -isnot [string] `
        -or [string]$Manifest.failure_code -cne $ExpectedFailureCode `
        -or [string]$Manifest.failure_code -cnotmatch '^[a-z0-9_]{1,128}$') {
        throw "process_a_rehearsal_diagnostic_manifest_failure_binding_invalid"
    }
    foreach ($state in @($Manifest.victory_state_sequence)) {
        if ($state -isnot [string] -or [string]$state -cnotmatch '^[a-z0-9_]{1,64}$') {
            throw "process_a_rehearsal_diagnostic_manifest_victory_sequence_invalid"
        }
    }
}

function Get-ProcessARehearsalAdmissionEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedRepositoryHead,
        [Parameter(Mandatory = $true)][string]$ExpectedScenarioFingerprint,
        [Parameter(Mandatory = $true)][string]$DiagnosticQuotaLedgerPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticLaunchAttestationPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticManifestPath,
        [Parameter(Mandatory = $true)][string]$ChildAttestationPath,
        [Parameter(Mandatory = $true)][string]$ParentAttestationPath,
        [Parameter(Mandatory = $true)][string]$StdoutPath,
        [Parameter(Mandatory = $true)][string]$StderrPath,
        [Parameter(Mandatory = $true)][string]$ExpectedTimeoutPolicyFingerprint
    )

    if ($ExpectedRepositoryHead -cnotmatch '^[0-9a-f]{40}$') {
        throw "process_a_rehearsal_repository_head_invalid"
    }
    if (-not (Test-ProcessARehearsalFingerprintValue $ExpectedScenarioFingerprint)) {
        throw "process_a_rehearsal_scenario_fingerprint_invalid"
    }
    if (-not (Test-ProcessARehearsalFingerprintValue $ExpectedTimeoutPolicyFingerprint)) {
        throw "process_a_rehearsal_timeout_policy_fingerprint_invalid"
    }
    $artifact = Read-ProcessARehearsalJsonArtifact $Path
    $diagnostic = $artifact.value
    if (-not (Test-ProcessARehearsalExactFieldSet $diagnostic $script:DiagnosticFields)) {
        throw "process_a_rehearsal_admission_evidence_field_set_invalid"
    }
    if (-not (Test-ProcessARehearsalInteger $diagnostic.schema_version) `
        -or [int]$diagnostic.schema_version -ne 2 `
        -or [string]$diagnostic.diagnostic_id -cne "TargetedOwnerCaptureDiagnosticV2" `
        -or -not (Test-ProcessARehearsalRunId $diagnostic.run_id) `
        -or $diagnostic.official -isnot [bool] -or [bool]$diagnostic.official `
        -or $diagnostic.formal -isnot [bool] -or [bool]$diagnostic.formal) {
        throw "process_a_rehearsal_admission_evidence_header_invalid"
    }
    if ([string]$diagnostic.repository_head -cne $ExpectedRepositoryHead) {
        throw "process_a_rehearsal_admission_evidence_head_mismatch"
    }
    if ([string]$diagnostic.evidence_fingerprint -cne (Get-ProcessARehearsalFingerprint $diagnostic "evidence_fingerprint")) {
        throw "process_a_rehearsal_admission_evidence_fingerprint_invalid"
    }

    $identity = $diagnostic.scenario_identity
    if (-not (Test-ProcessARehearsalExactFieldSet $identity $script:ScenarioIdentityFields) `
        -or -not (Test-ProcessARehearsalInteger $identity.schema_version) `
        -or [int]$identity.schema_version -ne 1 `
        -or [string]$identity.identity_id -cne "DiagnosticScenarioIdentityV1" `
        -or $diagnostic.scenario_identity_attested -isnot [bool] `
        -or -not [bool]$diagnostic.scenario_identity_attested `
        -or -not (Test-ProcessARehearsalEmptyObject $diagnostic.scenario_identity_failure) `
        -or $diagnostic.harness_or_scenario_failure_attested -isnot [bool] `
        -or [bool]$diagnostic.harness_or_scenario_failure_attested) {
        throw "process_a_rehearsal_admission_identity_invalid"
    }
    if ([string]$identity.run_id -cne [string]$diagnostic.run_id `
        -or [string]$identity.repository_head -cne $ExpectedRepositoryHead `
        -or [string]$identity.ruleset_id -cne "v0.6" `
        -or [string]$identity.diagnostic_role -cne "targeted_owner_diagnostic" `
        -or [string]$identity.scenario_fingerprint -cne $ExpectedScenarioFingerprint) {
        throw "process_a_rehearsal_admission_identity_binding_invalid"
    }
    foreach ($field in @(
        "ruleset_fingerprint", "scenario_fingerprint", "roster_fingerprint",
        "session_plan_fingerprint", "runtime_composition_fingerprint",
        "save_registry_fingerprint", "user_data_path_fingerprint", "identity_fingerprint"
    )) {
        if (-not (Test-ProcessARehearsalFingerprintValue $identity.$field)) {
            throw "process_a_rehearsal_admission_identity_fingerprint_invalid"
        }
    }
    if ([string]$identity.identity_fingerprint -cne (Get-ProcessARehearsalFingerprint $identity "identity_fingerprint") `
        -or -not (Test-ProcessARehearsalInteger $identity.challenge_depth) `
        -or [int]$identity.challenge_depth -ne $script:ChallengeDepth `
        -or -not (Test-ProcessARehearsalInteger $identity.local_player_count) `
        -or [int]$identity.local_player_count -ne $script:LocalPlayerCount `
        -or -not (Test-ProcessARehearsalInteger $identity.ai_player_count) `
        -or [int]$identity.ai_player_count -ne $script:AiPlayerCount `
        -or -not (Test-ProcessARehearsalInteger $identity.session_generation) `
        -or [int64]$identity.session_generation -lt 1 `
        -or -not (Test-ProcessARehearsalInteger $identity.world_revision) `
        -or [int64]$identity.world_revision -lt 0) {
        throw "process_a_rehearsal_admission_identity_contract_invalid"
    }
    Assert-ProcessARehearsalTaggedInt64 $identity.run_seed_tagged_int64 ([string]$script:Seed)
    Assert-ProcessARehearsalTaggedInt64 $identity.session_seed_tagged_int64

    $timeline = $diagnostic.diagnostic_phase_timeline
    if (-not (Test-ProcessARehearsalExactFieldSet $timeline $script:TimelineFields) `
        -or -not (Test-ProcessARehearsalInteger $timeline.schema_version) `
        -or [int]$timeline.schema_version -ne 1 `
        -or [string]$timeline.timeline_id -cne "TargetedOwnerCaptureDiagnosticPhaseTimelineV1" `
        -or [string]$timeline.run_id -cne [string]$diagnostic.run_id `
        -or [string]$timeline.repository_head -cne $ExpectedRepositoryHead `
        -or [string]$timeline.last_completed_phase -cne "diagnostic_completed" `
        -or [string]$timeline.current_phase -cne "diagnostic_completed" `
        -or [string]$timeline.next_expected_phase -cne "none" `
        -or [string]$diagnostic.last_completed_diagnostic_phase -cne "diagnostic_completed" `
        -or [string]$diagnostic.current_diagnostic_phase -cne "diagnostic_completed" `
        -or [string]$diagnostic.next_expected_diagnostic_phase -cne "none" `
        -or [string]$timeline.evidence_fingerprint -cne (Get-ProcessARehearsalFingerprint $timeline "evidence_fingerprint")) {
        throw "process_a_rehearsal_admission_timeline_invalid"
    }
    $timelineRows = @($timeline.phase_rows)
    $expectedTimeline = @(
        [pscustomobject]@{ phase_id = "diagnostic_started"; owner_index = -1 },
        [pscustomobject]@{ phase_id = "session_creating"; owner_index = -1 },
        [pscustomobject]@{ phase_id = "session_started"; owner_index = -1 },
        [pscustomobject]@{ phase_id = "scenario_identity_attesting"; owner_index = -1 },
        [pscustomobject]@{ phase_id = "scenario_identity_attested"; owner_index = -1 },
        [pscustomobject]@{ phase_id = "registry_binding_attesting"; owner_index = -1 },
        [pscustomobject]@{ phase_id = "registry_binding_attested"; owner_index = -1 },
        [pscustomobject]@{ phase_id = "owner_audit_started"; owner_index = -1 }
    )
    for ($ownerIndex = 0; $ownerIndex -lt 19; $ownerIndex += 1) {
        $expectedTimeline += [pscustomobject]@{ phase_id = "owner_capture_started"; owner_index = $ownerIndex }
        $expectedTimeline += [pscustomobject]@{ phase_id = "owner_capture_succeeded"; owner_index = $ownerIndex }
    }
    $expectedTimeline += [pscustomobject]@{ phase_id = "owner_audit_completed"; owner_index = -1 }
    $expectedTimeline += [pscustomobject]@{ phase_id = "diagnostic_completed"; owner_index = -1 }
    if ($timelineRows.Count -ne $expectedTimeline.Count) {
        throw "process_a_rehearsal_admission_timeline_invalid"
    }
    $previousMonotonicMs = [int64]-1
    for ($index = 0; $index -lt $timelineRows.Count; $index += 1) {
        $row = $timelineRows[$index]
        if (-not (Test-ProcessARehearsalExactFieldSet $row $script:TimelineRowFields) `
            -or -not (Test-ProcessARehearsalInteger $row.sequence) `
            -or [int]$row.sequence -ne $index + 1 `
            -or [string]$row.phase_id -cne [string]$expectedTimeline[$index].phase_id `
            -or -not (Test-ProcessARehearsalInteger $row.owner_index) `
            -or [int]$row.owner_index -ne [int]$expectedTimeline[$index].owner_index `
            -or $row.success -isnot [bool] -or -not [bool]$row.success `
            -or -not (Test-ProcessARehearsalInteger $row.completed_monotonic_ms) `
            -or [int64]$row.completed_monotonic_ms -lt $previousMonotonicMs `
            -or [string]$row.evidence_fingerprint -cne (Get-ProcessARehearsalFingerprint $row "evidence_fingerprint")) {
            throw "process_a_rehearsal_admission_timeline_row_invalid"
        }
        $previousMonotonicMs = [int64]$row.completed_monotonic_ms
    }
    if ([string]$timelineRows[-1].phase_id -cne "diagnostic_completed" `
        -or -not [bool]$timelineRows[-1].success) {
        throw "process_a_rehearsal_admission_timeline_incomplete"
    }

    if ($diagnostic.registry_binding_attested -isnot [bool] `
        -or -not [bool]$diagnostic.registry_binding_attested `
        -or $diagnostic.owner_audit_started -isnot [bool] -or -not [bool]$diagnostic.owner_audit_started `
        -or $diagnostic.owner_audit_completed -isnot [bool] -or -not [bool]$diagnostic.owner_audit_completed `
        -or -not (Test-ProcessARehearsalInteger $diagnostic.first_owner_capture_index) `
        -or [int]$diagnostic.first_owner_capture_index -ne 0 `
        -or -not (Test-ProcessARehearsalInteger $diagnostic.last_completed_owner_capture_index) `
        -or [int]$diagnostic.last_completed_owner_capture_index -ne 18 `
        -or -not (Test-ProcessARehearsalInteger $diagnostic.owner_capture_attempted_count) `
        -or [int]$diagnostic.owner_capture_attempted_count -ne 19 `
        -or -not (Test-ProcessARehearsalInteger $diagnostic.owner_capture_succeeded_count) `
        -or [int]$diagnostic.owner_capture_succeeded_count -ne 19 `
        -or -not (Test-ProcessARehearsalInteger $diagnostic.owner_capture_failed_count) `
        -or [int]$diagnostic.owner_capture_failed_count -ne 0 `
        -or -not (Test-ProcessARehearsalInteger $diagnostic.owner_capture_skipped_count) `
        -or [int]$diagnostic.owner_capture_skipped_count -ne 0 `
        -or -not (Test-ProcessARehearsalEmptyObject $diagnostic.first_failure) `
        -or $diagnostic.owner_capture_failure_attested -isnot [bool] `
        -or [bool]$diagnostic.owner_capture_failure_attested `
        -or [string]$diagnostic.post_capture_validation -cne "PASSED" `
        -or -not (Test-ProcessARehearsalEmptyObject $diagnostic.post_capture_failure) `
        -or $diagnostic.safety_green -isnot [bool] -or -not [bool]$diagnostic.safety_green `
        -or $diagnostic.save_file_exists -isnot [bool] -or [bool]$diagnostic.save_file_exists `
        -or $diagnostic.official_claim_path_present -isnot [bool] `
        -or [bool]$diagnostic.official_claim_path_present) {
        throw "process_a_rehearsal_admission_evidence_not_green"
    }
    $ownerRows = @($diagnostic.owner_capture_rows)
    if ($ownerRows.Count -ne 19) {
        throw "process_a_rehearsal_admission_owner_rows_invalid"
    }
    for ($index = 0; $index -lt 19; $index += 1) {
        $row = $ownerRows[$index]
        if (-not (Test-ProcessARehearsalExactFieldSet $row $script:OwnerRowFields) `
            -or -not (Test-ProcessARehearsalInteger $row.owner_index) `
            -or [int]$row.owner_index -ne $index `
            -or [string]$row.section_id -cne $script:SectionOrder[$index] `
            -or [string]$row.owner_id -cne $script:OwnerOrder[$index] `
            -or $row.owner_path -isnot [string] `
            -or ([string]$row.owner_path).Length -lt 1 `
            -or ([string]$row.owner_path).Length -gt 512 `
            -or $row.capture_started -isnot [bool] -or -not [bool]$row.capture_started `
            -or $row.capture_completed -isnot [bool] -or -not [bool]$row.capture_completed `
            -or [string]$row.capture_result_kind -cne "CAPTURED" `
            -or -not (Test-ProcessARehearsalInteger $row.state_version) `
            -or [int]$row.state_version -lt 1 `
            -or -not (Test-ProcessARehearsalFingerprintValue $row.payload_fingerprint) `
            -or $row.payload_pure_data -isnot [bool] -or -not [bool]$row.payload_pure_data `
            -or -not (Test-ProcessARehearsalInteger $row.elapsed_milliseconds) `
            -or [int64]$row.elapsed_milliseconds -lt 0 `
            -or -not (Test-ProcessARehearsalInteger $row.mutation_count) `
            -or [int]$row.mutation_count -ne 0 `
            -or -not (Test-ProcessARehearsalInteger $row.rng_draw_delta) `
            -or [int]$row.rng_draw_delta -ne 0 `
            -or -not (Test-ProcessARehearsalInteger $row.world_time_delta) `
            -or [int]$row.world_time_delta -ne 0 `
            -or -not (Test-ProcessARehearsalInteger $row.public_log_delta) `
            -or [int]$row.public_log_delta -ne 0 `
            -or [string]$row.reason_code -cne "owner_capture_valid" `
            -or $row.private_payload_redacted -isnot [bool] -or -not [bool]$row.private_payload_redacted `
            -or [string]$row.row_evidence_fingerprint -cne (Get-ProcessARehearsalFingerprint $row "row_evidence_fingerprint")) {
            throw "process_a_rehearsal_admission_owner_row_invalid"
        }
    }

    $quotaArtifact = Read-ProcessARehearsalJsonArtifact $DiagnosticQuotaLedgerPath
    $quota = $quotaArtifact.value
    try {
        $null = cold_restore_targeted_ledger_binding_contract_v1\Assert-ColdRestoreTargetedLedgerPublisherValue `
            $quota
    }
    catch {
        throw "process_a_rehearsal_diagnostic_quota_invalid"
    }
    if ([string]$quota.run_id -cne [string]$diagnostic.run_id `
        -or [string]$quota.repository_head -cne $ExpectedRepositoryHead `
        -or [string]$quota.scenario_fingerprint -cne $ExpectedScenarioFingerprint `
        -or [string]$quota.role_timeout_policy_sha256 -cne $ExpectedTimeoutPolicyFingerprint `
        -or [string]$quota.official_attempt_1_claim_sha256 -cne $script:OfficialAttempt1ClaimSha256) {
        throw "process_a_rehearsal_diagnostic_quota_invalid"
    }
    $bootstrapArtifact = Read-ProcessARehearsalJsonArtifact ([string]$quota.bootstrap_admission_path)
    $bootstrap = $bootstrapArtifact.value
    if ([string]$bootstrapArtifact.sha256 -cne [string]$quota.bootstrap_admission_sha256 `
        -or -not (Test-ProcessARehearsalExactFieldSet $bootstrap $script:BootstrapAdmissionFields) `
        -or [int]$bootstrap.schema_version -ne 1 `
        -or [string]$bootstrap.admission_id -cne "PreQuotaOrchestratorBootstrapAdmissionV1" `
        -or [string]$bootstrap.run_id -cne [string]$diagnostic.run_id `
        -or [string]$bootstrap.role -cne "targeted_owner_diagnostic" `
        -or [string]$bootstrap.repository_head -cne $ExpectedRepositoryHead `
        -or [string]$bootstrap.authorization_id -cne $script:TargetedDiagnosticAuthorizationId `
        -or [int]$bootstrap.historical_count `
            -ne [int]$script:TargetedDiagnosticAuthorization.permitted_transition_from `
        -or [int]$bootstrap.authorized_increment `
            -ne [int]$script:TargetedDiagnosticAuthorization.authorized_increment `
        -or [int]$bootstrap.maximum_allowed_count `
            -ne [int]$script:TargetedDiagnosticAuthorization.maximum_invocation_count `
        -or $bootstrap.official -isnot [bool] -or [bool]$bootstrap.official `
        -or $bootstrap.formal -isnot [bool] -or [bool]$bootstrap.formal `
        -or [string]$bootstrap.admission_fingerprint -cne [string]$quota.bootstrap_admission_fingerprint `
        -or [string]$bootstrap.admission_fingerprint -cne (Get-ProcessARehearsalFingerprint $bootstrap "admission_fingerprint")) {
        throw "process_a_rehearsal_diagnostic_bootstrap_admission_invalid"
    }
    $prequotaArtifact = Read-ProcessARehearsalJsonArtifact ([string]$quota.prequota_attestation_path)
    $prequota = $prequotaArtifact.value
    if (-not (Test-ProcessARehearsalExactFieldSet $prequota $script:PreQuotaAttestationFields) `
        -or [int]$prequota.schema_version -ne 1 `
        -or [string]$prequota.attestation_id -cne "PreQuotaOrchestratorAttestationV1" `
        -or [string]$prequota.run_id -cne [string]$diagnostic.run_id `
        -or [string]$prequota.role -cne "targeted_owner_diagnostic" `
        -or [string]$prequota.repository_head -cne $ExpectedRepositoryHead `
        -or $prequota.authorization_checked -isnot [bool] -or -not [bool]$prequota.authorization_checked `
        -or [int]$prequota.historical_count `
            -ne [int]$script:TargetedDiagnosticAuthorization.permitted_transition_from `
        -or [int]$prequota.authorized_increment `
            -ne [int]$script:TargetedDiagnosticAuthorization.authorized_increment `
        -or [int]$prequota.maximum_allowed_count `
            -ne [int]$script:TargetedDiagnosticAuthorization.maximum_invocation_count `
        -or $prequota.quota_claim_attempted -isnot [bool] -or -not [bool]$prequota.quota_claim_attempted `
        -or $prequota.quota_claimed -isnot [bool] -or -not [bool]$prequota.quota_claimed `
        -or [IO.Path]::GetFullPath([string]$prequota.quota_ledger_path) -cne [IO.Path]::GetFullPath($DiagnosticQuotaLedgerPath) `
        -or $prequota.evidence_root_creation_attempted -isnot [bool] -or -not [bool]$prequota.evidence_root_creation_attempted `
        -or $prequota.evidence_root_created -isnot [bool] -or -not [bool]$prequota.evidence_root_created `
        -or $prequota.godot_launch_attempted -isnot [bool] -or -not [bool]$prequota.godot_launch_attempted `
        -or $prequota.godot_launched -isnot [bool] -or -not [bool]$prequota.godot_launched `
        -or [string]$prequota.primary_failure_phase -cne "" `
        -or [string]$prequota.primary_failure_code -cne "" `
        -or $prequota.secondary_failure_codes -isnot [System.Array] `
        -or @($prequota.secondary_failure_codes).Count -ne 0 `
        -or [int]$prequota.task_owned_process_count_after -ne 0 `
        -or [string]$prequota.bootstrap_admission_sha256 -cne [string]$quota.bootstrap_admission_sha256 `
        -or [string]$prequota.bootstrap_admission_fingerprint -cne [string]$quota.bootstrap_admission_fingerprint `
        -or [string]$prequota.attestation_fingerprint -cne (Get-ProcessARehearsalFingerprint $prequota "attestation_fingerprint")) {
        throw "process_a_rehearsal_diagnostic_prequota_attestation_invalid"
    }

    $diagnosticLaunchArtifact = Read-ProcessARehearsalJsonArtifact $DiagnosticLaunchAttestationPath
    $diagnosticLaunch = $diagnosticLaunchArtifact.value
    if (-not (Test-ProcessARehearsalExactFieldSet $diagnosticLaunch $script:LaunchAttestationFields)) {
        throw "process_a_rehearsal_launch_attestation_invalid"
    }
    foreach ($field in @(
        "authorization_id", "claim_fingerprint", "claim_nonce", "source_head_sha",
        "scenario_fingerprint", "run_id", "process_role", "launch_nonce",
        "orchestrator_creation_time_utc_ticks", "wrapper_creation_time_utc_ticks",
        "engine_creation_time_utc_ticks", "status"
    )) {
        if ($diagnosticLaunch.$field -isnot [string]) {
            throw "process_a_rehearsal_launch_attestation_authorization_mismatch"
        }
    }
    $diagnosticLaunchAuthorization = [pscustomobject][ordered]@{
        authorization_id = $script:TargetedDiagnosticAuthorizationId
        claim_fingerprint = [string]$quotaArtifact.sha256
        claim_nonce = [string]$quota.claim_nonce
        source_head_sha = $ExpectedRepositoryHead
        scenario_fingerprint = $ExpectedScenarioFingerprint
        run_id = [string]$diagnostic.run_id
        process_role = "producer"
        launch_nonce = [string]$quota.launch_nonce
        orchestrator_process_id = [int]$quota.orchestrator_process_id
        orchestrator_creation_time_utc_ticks = [string]$quota.orchestrator_creation_time_utc_ticks
    }
    Assert-ProcessARehearsalLaunchAttestation $diagnosticLaunchArtifact.value $diagnosticLaunchAuthorization
    $diagnosticEngineProcessId = [int]$diagnosticLaunch.engine_process_id

    $diagnosticManifestArtifact = Read-ProcessARehearsalJsonArtifact $DiagnosticManifestPath
    Assert-ProcessARehearsalDiagnosticManifest `
        -Manifest $diagnosticManifestArtifact.value `
        -ExpectedRunId ([string]$diagnostic.run_id) `
        -ExpectedRepositoryHead $ExpectedRepositoryHead `
        -ExpectedScenarioFingerprint $ExpectedScenarioFingerprint `
        -ExpectedEngineProcessId $diagnosticEngineProcessId `
        -ExpectedFailureCode "targeted_owner_capture_all_owners_succeeded"

    $childArtifact = Read-ProcessARehearsalJsonArtifact $ChildAttestationPath
    $child = $childArtifact.value
    if (-not (Test-ProcessARehearsalExactFieldSet $child $script:ChildCompletionFields) `
        -or -not (Test-ProcessARehearsalInteger $child.schema_version) `
        -or [int]$child.schema_version -ne 1 `
        -or [string]$child.run_id -cne [string]$diagnostic.run_id `
        -or [string]$child.role -cne "producer" `
        -or [string]$child.repository_head -cne $ExpectedRepositoryHead `
        -or [string]$child.scenario_fingerprint -cne $ExpectedScenarioFingerprint `
        -or $child.official -isnot [bool] -or [bool]$child.official `
        -or $child.formal -isnot [bool] -or [bool]$child.formal `
        -or $child.qualification_completed -isnot [bool] -or -not [bool]$child.qualification_completed `
        -or $child.qualification_green -isnot [bool] -or [bool]$child.qualification_green `
        -or [string]$child.product_blocker -cne "TARGETED_OWNER_CAPTURE_DIAGNOSTIC_SHA256:$($artifact.sha256)" `
        -or -not (Test-ProcessARehearsalInteger $child.queue_count) `
        -or [int]$child.queue_count -lt 1 `
        -or -not (Test-ProcessARehearsalInteger $child.queue_revision) `
        -or [int64]$child.queue_revision -lt 1 `
        -or $child.save_written -isnot [bool] -or [bool]$child.save_written `
        -or $child.official_count_consumed -isnot [bool] -or [bool]$child.official_count_consumed `
        -or -not (Test-ProcessARehearsalInteger $child.product_mutation_count) `
        -or [int]$child.product_mutation_count -lt 0 `
        -or -not (Test-ProcessARehearsalInteger $child.direct_authority_mutation_count) `
        -or [int]$child.direct_authority_mutation_count -ne 0 `
        -or -not (Test-ProcessARehearsalInteger $child.queue_injection_count) `
        -or [int]$child.queue_injection_count -ne 0 `
        -or [string]$child.final_reason_code -cne "targeted_owner_capture_diagnostic_sha256_$($artifact.sha256)" `
        -or $child.child_ready_to_exit -isnot [bool] -or -not [bool]$child.child_ready_to_exit `
        -or [string]$child.evidence_fingerprint -cne (Get-ProcessARehearsalFingerprint $child "evidence_fingerprint")) {
        throw "process_a_rehearsal_diagnostic_child_attestation_invalid"
    }

    if (-not [IO.File]::Exists($StdoutPath) -or -not [IO.File]::Exists($StderrPath)) {
        throw "process_a_rehearsal_diagnostic_stream_evidence_missing"
    }
    $stdoutSha256 = (Get-FileHash -LiteralPath $StdoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $stderrSha256 = (Get-FileHash -LiteralPath $StderrPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $parentArtifact = Read-ProcessARehearsalJsonArtifact $ParentAttestationPath
    $parent = $parentArtifact.value
    if (-not (Test-ProcessARehearsalExactFieldSet $parent $script:ParentExitFieldsV2) `
        -or -not (Test-ProcessARehearsalInteger $parent.schema_version) `
        -or [int]$parent.schema_version -ne 2 `
        -or [string]$parent.run_id -cne [string]$diagnostic.run_id `
        -or [string]$parent.role -cne "producer" `
        -or -not (Test-ProcessARehearsalInteger $parent.child_pid) `
        -or [int]$parent.child_pid -ne $diagnosticEngineProcessId `
        -or $parent.observed_exit -isnot [bool] -or -not [bool]$parent.observed_exit `
        -or -not (Test-ProcessARehearsalInteger $parent.exit_code) `
        -or [int]$parent.exit_code -ne 0 `
        -or $parent.timed_out -isnot [bool] -or [bool]$parent.timed_out `
        -or $parent.terminated_by_parent -isnot [bool] -or [bool]$parent.terminated_by_parent `
        -or [string]$parent.stdout_sha256 -cne $stdoutSha256 `
        -or [string]$parent.stderr_sha256 -cne $stderrSha256 `
        -or $parent.child_attestation_found -isnot [bool] -or -not [bool]$parent.child_attestation_found `
        -or [string]$parent.child_attestation_fingerprint -cne [string]$child.evidence_fingerprint `
        -or $parent.child_attestation_valid -isnot [bool] -or -not [bool]$parent.child_attestation_valid `
        -or -not (Test-ProcessARehearsalInteger $parent.task_owned_process_count_after) `
        -or [int]$parent.task_owned_process_count_after -ne 0 `
        -or -not (Test-ProcessARehearsalInteger $parent.unrelated_preexisting_process_count) `
        -or [int]$parent.unrelated_preexisting_process_count -lt 0 `
        -or $parent.wrapper_exit_green -isnot [bool] -or -not [bool]$parent.wrapper_exit_green `
        -or [string]$parent.wrapper_reason_code -cne "ok" `
        -or [string]$parent.policy_role -cne "targeted_owner_diagnostic" `
        -or [string]$parent.timeout_policy_fingerprint -cne $ExpectedTimeoutPolicyFingerprint `
        -or -not (Test-ProcessARehearsalInteger $parent.absolute_timeout_seconds) `
        -or [int]$parent.absolute_timeout_seconds -ne 120 `
        -or -not (Test-ProcessARehearsalInteger $parent.no_progress_timeout_seconds) `
        -or [int]$parent.no_progress_timeout_seconds -ne 30 `
        -or [string]$parent.timeout_kind -cne "none" `
        -or $parent.progress_heartbeat_found -isnot [bool] -or -not [bool]$parent.progress_heartbeat_found `
        -or $parent.progress_heartbeat_valid -isnot [bool] -or -not [bool]$parent.progress_heartbeat_valid `
        -or -not (Test-ProcessARehearsalInteger $parent.progress_heartbeat_sequence) `
        -or [int64]$parent.progress_heartbeat_sequence -le 0 `
        -or -not (Test-ProcessARehearsalFingerprintValue $parent.progress_heartbeat_fingerprint) `
        -or -not (Test-ProcessARehearsalFingerprintValue $parent.progress_semantic_fingerprint) `
        -or [string]$parent.progress_phase -cne "quit_requested" `
        -or -not (Test-ProcessARehearsalInteger $parent.progress_last_evidence_write_time) `
        -or [int64]$parent.progress_last_evidence_write_time -le 0 `
        -or -not (Test-ProcessARehearsalFingerprintValue $parent.task_owned_process_identity_fingerprint)) {
        throw "process_a_rehearsal_diagnostic_parent_attestation_invalid"
    }

    $binding = [ordered]@{
        schema_version = 1
        binding_id = "ProcessARehearsalAdmissionEvidenceBindingV1"
        diagnostic_id = [string]$diagnostic.diagnostic_id
        diagnostic_run_id = [string]$diagnostic.run_id
        repository_head = $ExpectedRepositoryHead
        scenario_fingerprint = $ExpectedScenarioFingerprint
        diagnostic_artifact_sha256 = [string]$artifact.sha256
        diagnostic_evidence_fingerprint = [string]$diagnostic.evidence_fingerprint
        owner_capture_succeeded_count = 19
        owner_capture_failed_count = 0
        post_capture_validation = "PASSED"
        safety_green = $true
        diagnostic_quota_ledger_sha256 = [string]$quotaArtifact.sha256
        diagnostic_launch_attestation_sha256 = [string]$diagnosticLaunchArtifact.sha256
        diagnostic_manifest_sha256 = [string]$diagnosticManifestArtifact.sha256
        diagnostic_engine_process_id = $diagnosticEngineProcessId
        diagnostic_engine_creation_time_utc_ticks = [string]$diagnosticLaunch.engine_creation_time_utc_ticks
        diagnostic_child_attestation_sha256 = [string]$childArtifact.sha256
        diagnostic_child_attestation_fingerprint = [string]$child.evidence_fingerprint
        diagnostic_parent_attestation_sha256 = [string]$parentArtifact.sha256
        diagnostic_stdout_sha256 = $stdoutSha256
        diagnostic_stderr_sha256 = $stderrSha256
        diagnostic_timeout_policy_fingerprint = $ExpectedTimeoutPolicyFingerprint
        diagnostic_parent_exit_green = $true
        diagnostic_bootstrap_admission_sha256 = [string]$bootstrapArtifact.sha256
        diagnostic_bootstrap_admission_fingerprint = [string]$bootstrap.admission_fingerprint
        diagnostic_prequota_attestation_sha256 = [string]$prequotaArtifact.sha256
        diagnostic_prequota_attestation_fingerprint = [string]$prequota.attestation_fingerprint
        binding_fingerprint = ""
    }
    $binding.binding_fingerprint = Get-ProcessARehearsalFingerprint $binding "binding_fingerprint"
    return [pscustomobject]$binding
}

function Assert-ProcessARehearsalAdmissionEvidenceBinding {
    param(
        [Parameter(Mandatory = $true)]$Binding,
        [Parameter(Mandatory = $true)][string]$ExpectedRepositoryHead,
        [Parameter(Mandatory = $true)][string]$ExpectedScenarioFingerprint
    )

    if (-not (Test-ProcessARehearsalExactFieldSet $Binding $script:AdmissionEvidenceBindingFields) `
        -or -not (Test-ProcessARehearsalInteger $Binding.schema_version) `
        -or [int]$Binding.schema_version -ne 1 `
        -or [string]$Binding.binding_id -cne "ProcessARehearsalAdmissionEvidenceBindingV1" `
        -or [string]$Binding.diagnostic_id -cne "TargetedOwnerCaptureDiagnosticV2" `
        -or [string]$Binding.repository_head -cne $ExpectedRepositoryHead `
        -or [string]$Binding.scenario_fingerprint -cne $ExpectedScenarioFingerprint `
        -or -not (Test-ProcessARehearsalFingerprintValue $Binding.diagnostic_artifact_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Binding.diagnostic_evidence_fingerprint) `
        -or [int]$Binding.owner_capture_succeeded_count -ne 19 `
        -or [int]$Binding.owner_capture_failed_count -ne 0 `
        -or [string]$Binding.post_capture_validation -cne "PASSED" `
        -or $Binding.safety_green -isnot [bool] -or -not [bool]$Binding.safety_green `
        -or -not (Test-ProcessARehearsalFingerprintValue $Binding.diagnostic_quota_ledger_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Binding.diagnostic_launch_attestation_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Binding.diagnostic_manifest_sha256) `
        -or -not (Test-ProcessARehearsalInteger $Binding.diagnostic_engine_process_id) `
        -or [int]$Binding.diagnostic_engine_process_id -le 0 `
        -or -not (Test-ProcessARehearsalCreationTicks $Binding.diagnostic_engine_creation_time_utc_ticks) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Binding.diagnostic_child_attestation_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Binding.diagnostic_child_attestation_fingerprint) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Binding.diagnostic_parent_attestation_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Binding.diagnostic_stdout_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Binding.diagnostic_stderr_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Binding.diagnostic_timeout_policy_fingerprint) `
        -or $Binding.diagnostic_parent_exit_green -isnot [bool] `
        -or -not [bool]$Binding.diagnostic_parent_exit_green `
        -or -not (Test-ProcessARehearsalFingerprintValue $Binding.diagnostic_bootstrap_admission_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Binding.diagnostic_bootstrap_admission_fingerprint) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Binding.diagnostic_prequota_attestation_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Binding.diagnostic_prequota_attestation_fingerprint) `
        -or [string]$Binding.binding_fingerprint -cne (Get-ProcessARehearsalFingerprint $Binding "binding_fingerprint")) {
        throw "process_a_rehearsal_admission_binding_invalid"
    }
}

function Get-ProcessARehearsalTimeoutPolicyBinding {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedRepositoryHead,
        [string]$ExpectedFileSha256 = ""
    )

    $artifact = Read-ProcessARehearsalJsonArtifact $Path
    if ($ExpectedFileSha256 -ne "") {
        if (-not (Test-ProcessARehearsalFingerprintValue $ExpectedFileSha256) `
            -or [string]$artifact.sha256 -cne $ExpectedFileSha256) {
            throw "process_a_rehearsal_timeout_policy_file_sha256_mismatch"
        }
    }

    $validation = & $script:ColdRestoreRoleTimeoutPolicyValidator `
        -Value $artifact.value `
        -ExpectedRepositoryHead $ExpectedRepositoryHead `
        -ExpectedPolicyFingerprint ([string]$artifact.sha256) `
        -PolicyRole "process_a" `
        -ExpectedProcessRole "producer"
    if ($null -eq $validation `
        -or $validation.valid -isnot [bool] `
        -or -not [bool]$validation.valid) {
        $reasonCode = if ($null -ne $validation `
            -and $validation.PSObject.Properties.Name -ccontains "reason_code" `
            -and [string]$validation.reason_code -match '^[a-z0-9_]{1,128}$') {
            [string]$validation.reason_code
        }
        else {
            "process_a_rehearsal_timeout_policy_invalid"
        }
        throw $reasonCode
    }
    if ([string]$validation.reason_code -cne "ok" `
        -or [string]$validation.fingerprint -cne [string]$artifact.sha256 `
        -or $null -eq $validation.role_policy) {
        throw "process_a_rehearsal_timeout_policy_validation_result_invalid"
    }
    $processA = $validation.role_policy
    return [pscustomobject]@{
        path = [string]$artifact.path
        sha256 = [string]$artifact.sha256
        policy_role = "process_a"
        process_role = "producer"
        validation_reason_code = [string]$validation.reason_code
        absolute_timeout_seconds = [int]$processA.absolute_timeout_seconds
        no_progress_timeout_seconds = [int]$processA.no_progress_timeout_seconds
    }
}

function Get-ProcessARehearsalOfficialClaimState {
    param(
        [Parameter(Mandatory = $true)][string]$OfficialClaimRoot,
        [Parameter(Mandatory = $true)][string]$OfficialAttempt1ClaimPath
    )

    $root = [IO.Path]::GetFullPath($OfficialClaimRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $attempt1Path = [IO.Path]::GetFullPath($OfficialAttempt1ClaimPath)
    if (-not [IO.Directory]::Exists($root) `
        -or -not $attempt1Path.StartsWith("$root$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::OrdinalIgnoreCase) `
        -or -not [IO.File]::Exists($attempt1Path)) {
        throw "process_a_rehearsal_official_attempt_1_claim_missing"
    }
    $attempt1Sha = (Get-FileHash -LiteralPath $attempt1Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($attempt1Sha -cne $script:OfficialAttempt1ClaimSha256) {
        throw "process_a_rehearsal_official_attempt_1_claim_mutated"
    }
    $officialDirectories = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction Stop | Where-Object { $_.Name -clike "official-*" })
    $claimFiles = @(
        foreach ($directory in $officialDirectories) {
            Get-ChildItem -LiteralPath $directory.FullName -File -Recurse -ErrorAction Stop |
                Where-Object { $_.Name -clike "*claim*.json" }
        }
    )
    if ($officialDirectories.Count -ne 1 `
        -or $claimFiles.Count -ne 1 `
        -or -not [IO.Path]::GetFullPath($claimFiles[0].FullName).Equals($attempt1Path, [StringComparison]::OrdinalIgnoreCase)) {
        throw "process_a_rehearsal_official_attempt_2_claim_must_be_absent"
    }
    $relativePath = [IO.Path]::GetRelativePath($root, $attempt1Path).Replace('\', '/')
    $inventory = @([ordered]@{ relative_path = $relativePath; sha256 = $attempt1Sha })
    return [pscustomobject]@{
        attempt_1_relative_path = $relativePath
        attempt_1_sha256 = $attempt1Sha
        attempt_2_absent = $true
        inventory_count = 1
        inventory_fingerprint = Get-ProcessARehearsalFingerprint $inventory
    }
}

function Assert-ProcessARehearsalAdmissionLedgerValue {
    param([Parameter(Mandatory = $true)]$Ledger)

    if (-not (Test-ProcessARehearsalExactFieldSet $Ledger $script:AdmissionLedgerFields) `
        -or -not (Test-ProcessARehearsalInteger $Ledger.schema_version) `
        -or [int]$Ledger.schema_version -ne 3 `
        -or [string]$Ledger.ledger_id -cne $script:AdmissionLedgerId `
        -or [string]$Ledger.contract_id -cne $script:ContractId `
        -or [string]$Ledger.authorization_id -cne $script:AuthorizationId `
        -or [string]$Ledger.status -cne "admitted" `
        -or -not (Test-ProcessARehearsalUtcTimestamp $Ledger.created_at_utc) `
        -or -not (Test-ProcessARehearsalRunId $Ledger.run_id) `
        -or -not ([string]$Ledger.run_id).StartsWith(
            "$([string]$script:RehearsalAuthorization.run_id_prefix)-", [StringComparison]::Ordinal
        ) `
        -or [string]$Ledger.repository_head -cnotmatch '^[0-9a-f]{40}$' `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.scenario_fingerprint) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.timeout_policy_fingerprint) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.prerequisite_evidence_fingerprint) `
        -or -not (Test-ProcessARehearsalInteger $Ledger.challenge_depth) `
        -or [int]$Ledger.challenge_depth -ne $script:ChallengeDepth `
        -or -not (Test-ProcessARehearsalInteger $Ledger.seed) `
        -or [int64]$Ledger.seed -ne $script:Seed `
        -or -not (Test-ProcessARehearsalInteger $Ledger.local_player_count) `
        -or [int]$Ledger.local_player_count -ne $script:LocalPlayerCount `
        -or -not (Test-ProcessARehearsalInteger $Ledger.ai_player_count) `
        -or [int]$Ledger.ai_player_count -ne $script:AiPlayerCount `
        -or $Ledger.rehearsal_only -isnot [bool] `
        -or -not [bool]$Ledger.rehearsal_only `
        -or $Ledger.nonofficial -isnot [bool] `
        -or -not [bool]$Ledger.nonofficial `
        -or $Ledger.official -isnot [bool] `
        -or [bool]$Ledger.official `
        -or $Ledger.formal -isnot [bool] `
        -or [bool]$Ledger.formal `
        -or $Ledger.official_authorization_consumed -isnot [bool] `
        -or [bool]$Ledger.official_authorization_consumed `
        -or -not (Test-ProcessARehearsalInteger $Ledger.authorized_rehearsal_count) `
        -or [int]$Ledger.authorized_rehearsal_count -ne 1 `
        -or -not (Test-ProcessARehearsalInteger $Ledger.rehearsal_count_before) `
        -or [int]$Ledger.rehearsal_count_before -ne 0 `
        -or -not (Test-ProcessARehearsalInteger $Ledger.rehearsal_count_after) `
        -or [int]$Ledger.rehearsal_count_after -ne 1 `
        -or [string]$Ledger.admission_evidence_id -cne "TargetedOwnerCaptureDiagnosticV2" `
        -or -not (Test-ProcessARehearsalRunId $Ledger.admission_evidence_run_id) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.admission_evidence_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.admission_evidence_fingerprint) `
        -or $Ledger.admission_evidence_green -isnot [bool] `
        -or -not [bool]$Ledger.admission_evidence_green `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.diagnostic_quota_ledger_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.diagnostic_launch_attestation_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.diagnostic_manifest_sha256) `
        -or -not (Test-ProcessARehearsalInteger $Ledger.diagnostic_engine_process_id) `
        -or [int]$Ledger.diagnostic_engine_process_id -le 0 `
        -or -not (Test-ProcessARehearsalCreationTicks $Ledger.diagnostic_engine_creation_time_utc_ticks) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.diagnostic_child_attestation_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.diagnostic_child_attestation_fingerprint) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.diagnostic_parent_attestation_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.diagnostic_stdout_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.diagnostic_stderr_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.diagnostic_bootstrap_admission_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.diagnostic_bootstrap_admission_fingerprint) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.diagnostic_prequota_attestation_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.diagnostic_prequota_attestation_fingerprint) `
        -or [string]$Ledger.official_attempt_1_claim_relative_path -cnotmatch '^official-[^/]+/official_claim_ledger\.json$' `
        -or [string]$Ledger.official_attempt_1_claim_sha256 -cne $script:OfficialAttempt1ClaimSha256 `
        -or $Ledger.official_attempt_1_claim_immutable -isnot [bool] `
        -or -not [bool]$Ledger.official_attempt_1_claim_immutable `
        -or $Ledger.official_attempt_2_claim_absent -isnot [bool] `
        -or -not [bool]$Ledger.official_attempt_2_claim_absent `
        -or -not (Test-ProcessARehearsalInteger $Ledger.official_claim_inventory_count) `
        -or [int]$Ledger.official_claim_inventory_count -ne 1 `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.official_claim_inventory_fingerprint) `
        -or [string]$Ledger.process_role -cne "producer" `
        -or -not (Test-ProcessARehearsalInteger $Ledger.orchestrator_process_id) `
        -or [int]$Ledger.orchestrator_process_id -le 0 `
        -or -not (Test-ProcessARehearsalCreationTicks $Ledger.orchestrator_creation_time_utc_ticks) `
        -or [string]$Ledger.claim_nonce -cnotmatch '^[0-9a-f]{32}$' `
        -or [string]$Ledger.launch_nonce -cnotmatch '^[0-9a-f]{32}$' `
        -or [string]$Ledger.claim_nonce -ceq [string]$Ledger.launch_nonce `
        -or [string]$Ledger.ledger_fingerprint -cne (Get-ProcessARehearsalFingerprint $Ledger "ledger_fingerprint")) {
        throw "process_a_rehearsal_admission_ledger_invalid"
    }
}

function Read-ProcessARehearsalAdmissionLedger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$ExpectedFileSha256 = ""
    )

    $artifact = Read-ProcessARehearsalJsonArtifact $Path
    if ($ExpectedFileSha256 -ne "" -and [string]$artifact.sha256 -cne $ExpectedFileSha256) {
        throw "process_a_rehearsal_admission_ledger_sha256_mismatch"
    }
    Assert-ProcessARehearsalAdmissionLedgerValue $artifact.value
    return [pscustomobject]@{
        path = [string]$artifact.path
        fingerprint = [string]$artifact.sha256
        value = $artifact.value
    }
}

function Get-ProcessARehearsalAdmissionCollisionReason {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Candidate
    )

    try {
        $existing = (Read-ProcessARehearsalAdmissionLedger $Path).value
        if ([string]$existing.run_id -ceq [string]$Candidate.run_id `
            -and [string]$existing.repository_head -ceq [string]$Candidate.repository_head `
            -and [string]$existing.scenario_fingerprint -ceq [string]$Candidate.scenario_fingerprint `
            -and [string]$existing.timeout_policy_fingerprint -ceq [string]$Candidate.timeout_policy_fingerprint `
            -and [string]$existing.prerequisite_evidence_fingerprint -ceq [string]$Candidate.prerequisite_evidence_fingerprint `
            -and [string]$existing.admission_evidence_sha256 -ceq [string]$Candidate.admission_evidence_sha256 `
            -and [string]$existing.diagnostic_quota_ledger_sha256 -ceq [string]$Candidate.diagnostic_quota_ledger_sha256 `
            -and [string]$existing.diagnostic_launch_attestation_sha256 -ceq [string]$Candidate.diagnostic_launch_attestation_sha256 `
            -and [string]$existing.diagnostic_manifest_sha256 -ceq [string]$Candidate.diagnostic_manifest_sha256 `
            -and [string]$existing.diagnostic_child_attestation_sha256 -ceq [string]$Candidate.diagnostic_child_attestation_sha256 `
            -and [string]$existing.diagnostic_parent_attestation_sha256 -ceq [string]$Candidate.diagnostic_parent_attestation_sha256) {
            return "process_a_rehearsal_admission_already_consumed"
        }
    }
    catch {
    }
    return "process_a_rehearsal_admission_ledger_collision"
}

function ConvertTo-ProcessARehearsalLaunchAuthorization {
    param(
        [Parameter(Mandatory = $true)]$Ledger,
        [Parameter(Mandatory = $true)][string]$LedgerSha256
    )

    $authorization = [ordered]@{
        authorization_id = [string]$Ledger.authorization_id
        claim_fingerprint = $LedgerSha256
        claim_nonce = [string]$Ledger.claim_nonce
        source_head_sha = [string]$Ledger.repository_head
        scenario_fingerprint = [string]$Ledger.scenario_fingerprint
        run_id = [string]$Ledger.run_id
        process_role = [string]$Ledger.process_role
        launch_nonce = [string]$Ledger.launch_nonce
        orchestrator_process_id = [int]$Ledger.orchestrator_process_id
        orchestrator_creation_time_utc_ticks = [string]$Ledger.orchestrator_creation_time_utc_ticks
    }
    if (-not (Test-ProcessARehearsalExactFieldSet ([pscustomobject]$authorization) $script:LaunchAuthorizationFields)) {
        throw "process_a_rehearsal_launch_authorization_invalid"
    }
    return [pscustomobject]$authorization
}

function Get-ProcessARehearsalLaunchAuthorization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$AdmissionLedgerPath,
        [Parameter(Mandatory = $true)][string]$ExpectedAdmissionLedgerSha256
    )

    $admission = Read-ProcessARehearsalAdmissionLedger $AdmissionLedgerPath $ExpectedAdmissionLedgerSha256
    return ConvertTo-ProcessARehearsalLaunchAuthorization $admission.value $admission.fingerprint
}

function New-ProcessARehearsalAdmission {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$LedgerPath,
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$RepositoryHead,
        [Parameter(Mandatory = $true)][string]$ScenarioFingerprint,
        [Parameter(Mandatory = $true)][string]$PrerequisiteEvidenceFingerprint,
        [Parameter(Mandatory = $true)][string]$TimeoutPolicyPath,
        [Parameter(Mandatory = $true)][string]$AdmissionEvidencePath,
        [Parameter(Mandatory = $true)][string]$DiagnosticQuotaLedgerPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticLaunchAttestationPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticManifestPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticChildAttestationPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticParentAttestationPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticStdoutPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticStderrPath,
        [Parameter(Mandatory = $true)][string]$OfficialClaimRoot,
        [Parameter(Mandatory = $true)][string]$OfficialAttempt1ClaimPath
    )

    if (-not (Test-ProcessARehearsalRunId $RunId) `
        -or -not $RunId.StartsWith("$($script:RehearsalRunIdPrefix)-", [StringComparison]::Ordinal)) {
        throw "process_a_rehearsal_run_id_invalid"
    }
    if ($RepositoryHead -cnotmatch '^[0-9a-f]{40}$') {
        throw "process_a_rehearsal_repository_head_invalid"
    }
    if (-not (Test-ProcessARehearsalFingerprintValue $ScenarioFingerprint)) {
        throw "process_a_rehearsal_scenario_fingerprint_invalid"
    }
    if (-not (Test-ProcessARehearsalFingerprintValue $PrerequisiteEvidenceFingerprint)) {
        throw "process_a_rehearsal_prerequisite_evidence_fingerprint_invalid"
    }
    $policy = Get-ProcessARehearsalTimeoutPolicyBinding `
        -Path $TimeoutPolicyPath `
        -ExpectedRepositoryHead $RepositoryHead
    $evidence = Get-ProcessARehearsalAdmissionEvidence `
        -Path $AdmissionEvidencePath `
        -ExpectedRepositoryHead $RepositoryHead `
        -ExpectedScenarioFingerprint $ScenarioFingerprint `
        -DiagnosticQuotaLedgerPath $DiagnosticQuotaLedgerPath `
        -DiagnosticLaunchAttestationPath $DiagnosticLaunchAttestationPath `
        -DiagnosticManifestPath $DiagnosticManifestPath `
        -ChildAttestationPath $DiagnosticChildAttestationPath `
        -ParentAttestationPath $DiagnosticParentAttestationPath `
        -StdoutPath $DiagnosticStdoutPath `
        -StderrPath $DiagnosticStderrPath `
        -ExpectedTimeoutPolicyFingerprint $policy.sha256
    Assert-ProcessARehearsalAdmissionEvidenceBinding $evidence $RepositoryHead $ScenarioFingerprint
    $claimState = Get-ProcessARehearsalOfficialClaimState $OfficialClaimRoot $OfficialAttempt1ClaimPath
    $orchestratorTicks = Get-ProcessARehearsalCurrentCreationTicks
    $ledger = [ordered]@{
        schema_version = 3
        ledger_id = $script:AdmissionLedgerId
        contract_id = $script:ContractId
        authorization_id = $script:AuthorizationId
        status = "admitted"
        created_at_utc = [DateTime]::UtcNow.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
        run_id = $RunId
        repository_head = $RepositoryHead
        scenario_fingerprint = $ScenarioFingerprint
        timeout_policy_fingerprint = [string]$policy.sha256
        prerequisite_evidence_fingerprint = $PrerequisiteEvidenceFingerprint
        challenge_depth = $script:ChallengeDepth
        seed = $script:Seed
        local_player_count = $script:LocalPlayerCount
        ai_player_count = $script:AiPlayerCount
        rehearsal_only = $true
        nonofficial = $true
        official = $false
        formal = $false
        official_authorization_consumed = $false
        authorized_rehearsal_count = 1
        rehearsal_count_before = 0
        rehearsal_count_after = 1
        admission_evidence_id = [string]$evidence.diagnostic_id
        admission_evidence_run_id = [string]$evidence.diagnostic_run_id
        admission_evidence_sha256 = [string]$evidence.diagnostic_artifact_sha256
        admission_evidence_fingerprint = [string]$evidence.diagnostic_evidence_fingerprint
        admission_evidence_green = $true
        diagnostic_quota_ledger_sha256 = [string]$evidence.diagnostic_quota_ledger_sha256
        diagnostic_launch_attestation_sha256 = [string]$evidence.diagnostic_launch_attestation_sha256
        diagnostic_manifest_sha256 = [string]$evidence.diagnostic_manifest_sha256
        diagnostic_engine_process_id = [int]$evidence.diagnostic_engine_process_id
        diagnostic_engine_creation_time_utc_ticks = [string]$evidence.diagnostic_engine_creation_time_utc_ticks
        diagnostic_child_attestation_sha256 = [string]$evidence.diagnostic_child_attestation_sha256
        diagnostic_child_attestation_fingerprint = [string]$evidence.diagnostic_child_attestation_fingerprint
        diagnostic_parent_attestation_sha256 = [string]$evidence.diagnostic_parent_attestation_sha256
        diagnostic_stdout_sha256 = [string]$evidence.diagnostic_stdout_sha256
        diagnostic_stderr_sha256 = [string]$evidence.diagnostic_stderr_sha256
        diagnostic_bootstrap_admission_sha256 = [string]$evidence.diagnostic_bootstrap_admission_sha256
        diagnostic_bootstrap_admission_fingerprint = [string]$evidence.diagnostic_bootstrap_admission_fingerprint
        diagnostic_prequota_attestation_sha256 = [string]$evidence.diagnostic_prequota_attestation_sha256
        diagnostic_prequota_attestation_fingerprint = [string]$evidence.diagnostic_prequota_attestation_fingerprint
        official_attempt_1_claim_relative_path = [string]$claimState.attempt_1_relative_path
        official_attempt_1_claim_sha256 = [string]$claimState.attempt_1_sha256
        official_attempt_1_claim_immutable = $true
        official_attempt_2_claim_absent = $true
        official_claim_inventory_count = [int]$claimState.inventory_count
        official_claim_inventory_fingerprint = [string]$claimState.inventory_fingerprint
        process_role = "producer"
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = $orchestratorTicks
        claim_nonce = [Guid]::NewGuid().ToString("N")
        launch_nonce = [Guid]::NewGuid().ToString("N")
        ledger_fingerprint = ""
    }
    $ledger.ledger_fingerprint = Get-ProcessARehearsalFingerprint $ledger "ledger_fingerprint"
    Assert-ProcessARehearsalAdmissionLedgerValue ([pscustomobject]$ledger)
    try {
        $ledgerSha = Write-ProcessARehearsalExclusiveAtomicJson $LedgerPath ([pscustomobject]$ledger)
    }
    catch {
        if ([string]$_.Exception.Message -eq "process_a_rehearsal_atomic_target_exists") {
            throw (Get-ProcessARehearsalAdmissionCollisionReason $LedgerPath ([pscustomobject]$ledger))
        }
        throw
    }

    $authorization = ConvertTo-ProcessARehearsalLaunchAuthorization ([pscustomobject]$ledger) $ledgerSha
    return [pscustomobject]@{
        path = [IO.Path]::GetFullPath($LedgerPath)
        fingerprint = [string]$ledgerSha
        value = [pscustomobject]$ledger
        timeout_policy_fingerprint = [string]$policy.sha256
        launch_authorization = $authorization
    }
}

function Assert-ProcessARehearsalAdmissionSourcesUnchanged {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Admission,
        [Parameter(Mandatory = $true)][string]$PrerequisiteEvidenceFingerprint,
        [Parameter(Mandatory = $true)][string]$TimeoutPolicyPath,
        [Parameter(Mandatory = $true)][string]$AdmissionEvidencePath,
        [Parameter(Mandatory = $true)][string]$DiagnosticQuotaLedgerPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticLaunchAttestationPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticManifestPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticChildAttestationPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticParentAttestationPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticStdoutPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticStderrPath,
        [Parameter(Mandatory = $true)][string]$OfficialClaimRoot,
        [Parameter(Mandatory = $true)][string]$OfficialAttempt1ClaimPath
    )

    $ledger = $Admission.value
    $null = Read-ProcessARehearsalAdmissionLedger $Admission.path $Admission.fingerprint
    if (-not (Test-ProcessARehearsalFingerprintValue $PrerequisiteEvidenceFingerprint) `
        -or [string]$ledger.prerequisite_evidence_fingerprint -cne $PrerequisiteEvidenceFingerprint) {
        throw "process_a_rehearsal_prerequisite_evidence_changed_after_admission"
    }
    $sourceBindings = @(
        @($AdmissionEvidencePath, [string]$ledger.admission_evidence_sha256),
        @($DiagnosticQuotaLedgerPath, [string]$ledger.diagnostic_quota_ledger_sha256),
        @($DiagnosticLaunchAttestationPath, [string]$ledger.diagnostic_launch_attestation_sha256),
        @($DiagnosticManifestPath, [string]$ledger.diagnostic_manifest_sha256),
        @($DiagnosticChildAttestationPath, [string]$ledger.diagnostic_child_attestation_sha256),
        @($DiagnosticParentAttestationPath, [string]$ledger.diagnostic_parent_attestation_sha256),
        @($DiagnosticStdoutPath, [string]$ledger.diagnostic_stdout_sha256),
        @($DiagnosticStderrPath, [string]$ledger.diagnostic_stderr_sha256),
        @($TimeoutPolicyPath, [string]$ledger.timeout_policy_fingerprint)
    )
    foreach ($binding in $sourceBindings) {
        try {
            if (-not [IO.File]::Exists([string]$binding[0]) `
                -or (Get-FileHash -LiteralPath ([string]$binding[0]) -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$binding[1]) {
                throw "process_a_rehearsal_admission_source_changed_after_commit"
            }
        }
        catch {
            if ([string]$_.Exception.Message -ceq "process_a_rehearsal_admission_source_changed_after_commit") {
                throw
            }
            throw "process_a_rehearsal_admission_source_changed_after_commit"
        }
    }
    $claimStateAfter = Get-ProcessARehearsalOfficialClaimState $OfficialClaimRoot $OfficialAttempt1ClaimPath
    if ([string]$claimStateAfter.inventory_fingerprint -cne [string]$ledger.official_claim_inventory_fingerprint) {
        throw "process_a_rehearsal_official_claim_state_changed_after_admission"
    }
    return $true
}

function Assert-ProcessARehearsalLaunchAttestation {
    param(
        [Parameter(Mandatory = $true)]$Attestation,
        [Parameter(Mandatory = $true)]$Authorization
    )

    if (-not (Test-ProcessARehearsalExactFieldSet $Attestation $script:LaunchAttestationFields) `
        -or -not (Test-ProcessARehearsalExactFieldSet $Authorization $script:LaunchAuthorizationFields) `
        -or -not (Test-ProcessARehearsalInteger $Attestation.schema_version) `
        -or [int]$Attestation.schema_version -ne 1 `
        -or [string]$Attestation.status -cne "authorized") {
        throw "process_a_rehearsal_launch_attestation_invalid"
    }
    foreach ($field in @(
        "authorization_id", "claim_fingerprint", "claim_nonce", "source_head_sha",
        "scenario_fingerprint", "run_id", "process_role", "launch_nonce",
        "orchestrator_process_id", "orchestrator_creation_time_utc_ticks"
    )) {
        if ([string]$Attestation.$field -cne [string]$Authorization.$field) {
            throw "process_a_rehearsal_launch_attestation_authorization_mismatch"
        }
    }
    foreach ($field in @(
        "orchestrator_process_id", "wrapper_process_id", "wrapper_parent_process_id",
        "engine_process_id", "engine_parent_process_id"
    )) {
        $candidate = if ($field -ceq "orchestrator_process_id") { $Authorization.$field } else { $Attestation.$field }
        if (-not (Test-ProcessARehearsalInteger $candidate)) {
            throw "process_a_rehearsal_launch_process_identity_invalid"
        }
    }
    if (-not (Test-ProcessARehearsalInteger $Attestation.orchestrator_process_id)) {
        throw "process_a_rehearsal_launch_process_identity_invalid"
    }
    $orchestratorPid = [int]$Authorization.orchestrator_process_id
    $wrapperPid = [int]$Attestation.wrapper_process_id
    $enginePid = [int]$Attestation.engine_process_id
    if ($wrapperPid -le 0 -or $enginePid -le 0 `
        -or $wrapperPid -eq $orchestratorPid -or $enginePid -eq $orchestratorPid `
        -or [int]$Attestation.wrapper_parent_process_id -ne $orchestratorPid `
        -or [int]$Attestation.engine_parent_process_id -notin @($orchestratorPid, $wrapperPid) `
        -or -not (Test-ProcessARehearsalCreationTicks $Attestation.wrapper_creation_time_utc_ticks) `
        -or -not (Test-ProcessARehearsalCreationTicks $Attestation.engine_creation_time_utc_ticks)) {
        throw "process_a_rehearsal_launch_process_identity_invalid"
    }
    if ($wrapperPid -eq $enginePid `
        -and ([int]$Attestation.engine_parent_process_id -ne $orchestratorPid `
            -or [string]$Attestation.engine_creation_time_utc_ticks -cne [string]$Attestation.wrapper_creation_time_utc_ticks)) {
        throw "process_a_rehearsal_launch_process_identity_invalid"
    }
    if ($wrapperPid -ne $enginePid -and [int]$Attestation.engine_parent_process_id -ne $wrapperPid) {
        throw "process_a_rehearsal_launch_process_identity_invalid"
    }
}

function Assert-ProcessARehearsalLaunchLedgerValue {
    param([Parameter(Mandatory = $true)]$Ledger)

    if (-not (Test-ProcessARehearsalExactFieldSet $Ledger $script:LaunchLedgerFields) `
        -or -not (Test-ProcessARehearsalInteger $Ledger.schema_version) `
        -or [int]$Ledger.schema_version -ne 1 `
        -or [string]$Ledger.ledger_id -cne $script:LaunchLedgerId `
        -or [string]$Ledger.contract_id -cne $script:ContractId `
        -or [string]$Ledger.authorization_id -cne $script:AuthorizationId `
        -or [string]$Ledger.status -cne "launch_identity_bound" `
        -or -not (Test-ProcessARehearsalUtcTimestamp $Ledger.created_at_utc) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.admission_ledger_sha256) `
        -or [string]$Ledger.claim_fingerprint -cne [string]$Ledger.admission_ledger_sha256 `
        -or -not (Test-ProcessARehearsalRunId $Ledger.run_id) `
        -or -not ([string]$Ledger.run_id).StartsWith("$($script:RehearsalRunIdPrefix)-", [StringComparison]::Ordinal) `
        -or [string]$Ledger.repository_head -cnotmatch '^[0-9a-f]{40}$' `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.scenario_fingerprint) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.timeout_policy_fingerprint) `
        -or -not (Test-ProcessARehearsalInteger $Ledger.challenge_depth) `
        -or [int]$Ledger.challenge_depth -ne $script:ChallengeDepth `
        -or -not (Test-ProcessARehearsalInteger $Ledger.seed) `
        -or [int64]$Ledger.seed -ne $script:Seed `
        -or -not (Test-ProcessARehearsalInteger $Ledger.local_player_count) `
        -or [int]$Ledger.local_player_count -ne $script:LocalPlayerCount `
        -or -not (Test-ProcessARehearsalInteger $Ledger.ai_player_count) `
        -or [int]$Ledger.ai_player_count -ne $script:AiPlayerCount `
        -or $Ledger.rehearsal_only -isnot [bool] `
        -or -not [bool]$Ledger.rehearsal_only `
        -or $Ledger.nonofficial -isnot [bool] `
        -or -not [bool]$Ledger.nonofficial `
        -or $Ledger.official -isnot [bool] `
        -or [bool]$Ledger.official `
        -or $Ledger.formal -isnot [bool] `
        -or [bool]$Ledger.formal `
        -or $Ledger.official_authorization_consumed -isnot [bool] `
        -or [bool]$Ledger.official_authorization_consumed `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.admission_evidence_sha256) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.admission_evidence_fingerprint) `
        -or [string]$Ledger.official_attempt_1_claim_sha256 -cne $script:OfficialAttempt1ClaimSha256 `
        -or $Ledger.official_attempt_2_claim_absent -isnot [bool] `
        -or -not [bool]$Ledger.official_attempt_2_claim_absent `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.official_claim_inventory_fingerprint) `
        -or [string]$Ledger.process_role -cne "producer" `
        -or [string]$Ledger.claim_nonce -cnotmatch '^[0-9a-f]{32}$' `
        -or [string]$Ledger.launch_nonce -cnotmatch '^[0-9a-f]{32}$' `
        -or [string]$Ledger.claim_nonce -ceq [string]$Ledger.launch_nonce `
        -or -not (Test-ProcessARehearsalInteger $Ledger.orchestrator_process_id) `
        -or [int]$Ledger.orchestrator_process_id -le 0 `
        -or -not (Test-ProcessARehearsalCreationTicks $Ledger.orchestrator_creation_time_utc_ticks) `
        -or -not (Test-ProcessARehearsalInteger $Ledger.wrapper_process_id) `
        -or -not (Test-ProcessARehearsalInteger $Ledger.wrapper_parent_process_id) `
        -or -not (Test-ProcessARehearsalInteger $Ledger.engine_process_id) `
        -or -not (Test-ProcessARehearsalInteger $Ledger.engine_parent_process_id) `
        -or [int]$Ledger.wrapper_process_id -le 0 `
        -or [int]$Ledger.engine_process_id -le 0 `
        -or [int]$Ledger.wrapper_process_id -eq [int]$Ledger.orchestrator_process_id `
        -or [int]$Ledger.engine_process_id -eq [int]$Ledger.orchestrator_process_id `
        -or [int]$Ledger.wrapper_parent_process_id -ne [int]$Ledger.orchestrator_process_id `
        -or [int]$Ledger.engine_parent_process_id -notin @([int]$Ledger.orchestrator_process_id, [int]$Ledger.wrapper_process_id) `
        -or -not (Test-ProcessARehearsalCreationTicks $Ledger.wrapper_creation_time_utc_ticks) `
        -or -not (Test-ProcessARehearsalCreationTicks $Ledger.engine_creation_time_utc_ticks) `
        -or ([int]$Ledger.wrapper_process_id -eq [int]$Ledger.engine_process_id -and (
            [int]$Ledger.engine_parent_process_id -ne [int]$Ledger.orchestrator_process_id `
            -or [string]$Ledger.engine_creation_time_utc_ticks -cne [string]$Ledger.wrapper_creation_time_utc_ticks
        )) `
        -or ([int]$Ledger.wrapper_process_id -ne [int]$Ledger.engine_process_id `
            -and [int]$Ledger.engine_parent_process_id -ne [int]$Ledger.wrapper_process_id) `
        -or -not (Test-ProcessARehearsalFingerprintValue $Ledger.launch_attestation_sha256) `
        -or [string]$Ledger.ledger_fingerprint -cne (Get-ProcessARehearsalFingerprint $Ledger "ledger_fingerprint")) {
        throw "process_a_rehearsal_launch_ledger_invalid"
    }
}

function Read-ProcessARehearsalLaunchLedger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$ExpectedFileSha256 = ""
    )

    $artifact = Read-ProcessARehearsalJsonArtifact $Path
    if ($ExpectedFileSha256 -ne "" -and [string]$artifact.sha256 -cne $ExpectedFileSha256) {
        throw "process_a_rehearsal_launch_ledger_sha256_mismatch"
    }
    Assert-ProcessARehearsalLaunchLedgerValue $artifact.value
    return [pscustomobject]@{
        path = [string]$artifact.path
        fingerprint = [string]$artifact.sha256
        value = $artifact.value
    }
}

function Get-ProcessARehearsalLaunchCollisionReason {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Candidate
    )

    try {
        $existing = (Read-ProcessARehearsalLaunchLedger $Path).value
        if ([string]$existing.admission_ledger_sha256 -ceq [string]$Candidate.admission_ledger_sha256 `
            -and [string]$existing.launch_nonce -ceq [string]$Candidate.launch_nonce) {
            return "process_a_rehearsal_launch_already_bound"
        }
    }
    catch {
    }
    return "process_a_rehearsal_launch_ledger_collision"
}

function Complete-ProcessARehearsalLaunch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$LaunchLedgerPath,
        [Parameter(Mandatory = $true)][string]$AdmissionLedgerPath,
        [Parameter(Mandatory = $true)][string]$ExpectedAdmissionLedgerSha256,
        [Parameter(Mandatory = $true)][string]$PrerequisiteEvidenceFingerprint,
        [Parameter(Mandatory = $true)][string]$LaunchAttestationPath,
        [Parameter(Mandatory = $true)][string]$TimeoutPolicyPath,
        [Parameter(Mandatory = $true)][string]$AdmissionEvidencePath,
        [Parameter(Mandatory = $true)][string]$DiagnosticQuotaLedgerPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticLaunchAttestationPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticManifestPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticChildAttestationPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticParentAttestationPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticStdoutPath,
        [Parameter(Mandatory = $true)][string]$DiagnosticStderrPath,
        [Parameter(Mandatory = $true)][string]$OfficialClaimRoot,
        [Parameter(Mandatory = $true)][string]$OfficialAttempt1ClaimPath
    )

    $admission = Read-ProcessARehearsalAdmissionLedger $AdmissionLedgerPath $ExpectedAdmissionLedgerSha256
    $ledger = $admission.value
    if (-not (Test-ProcessARehearsalFingerprintValue $PrerequisiteEvidenceFingerprint) `
        -or [string]$ledger.prerequisite_evidence_fingerprint -cne $PrerequisiteEvidenceFingerprint `
        -or (Get-FileHash -LiteralPath $TimeoutPolicyPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$ledger.timeout_policy_fingerprint `
        -or (Get-FileHash -LiteralPath $AdmissionEvidencePath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$ledger.admission_evidence_sha256 `
        -or (Get-FileHash -LiteralPath $DiagnosticQuotaLedgerPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$ledger.diagnostic_quota_ledger_sha256 `
        -or (Get-FileHash -LiteralPath $DiagnosticLaunchAttestationPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$ledger.diagnostic_launch_attestation_sha256 `
        -or (Get-FileHash -LiteralPath $DiagnosticManifestPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$ledger.diagnostic_manifest_sha256 `
        -or (Get-FileHash -LiteralPath $DiagnosticChildAttestationPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$ledger.diagnostic_child_attestation_sha256 `
        -or (Get-FileHash -LiteralPath $DiagnosticParentAttestationPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$ledger.diagnostic_parent_attestation_sha256 `
        -or (Get-FileHash -LiteralPath $DiagnosticStdoutPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$ledger.diagnostic_stdout_sha256 `
        -or (Get-FileHash -LiteralPath $DiagnosticStderrPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$ledger.diagnostic_stderr_sha256) {
        throw "process_a_rehearsal_launch_bound_source_changed"
    }
    $claimState = Get-ProcessARehearsalOfficialClaimState $OfficialClaimRoot $OfficialAttempt1ClaimPath
    if ([string]$claimState.inventory_fingerprint -cne [string]$ledger.official_claim_inventory_fingerprint) {
        throw "process_a_rehearsal_launch_official_claim_state_changed"
    }
    $authorization = Get-ProcessARehearsalLaunchAuthorization $AdmissionLedgerPath $ExpectedAdmissionLedgerSha256
    $launchArtifact = Read-ProcessARehearsalJsonArtifact $LaunchAttestationPath
    Assert-ProcessARehearsalLaunchAttestation $launchArtifact.value $authorization
    $attestation = $launchArtifact.value
    $launchLedger = [ordered]@{
        schema_version = 1
        ledger_id = $script:LaunchLedgerId
        contract_id = $script:ContractId
        authorization_id = [string]$ledger.authorization_id
        status = "launch_identity_bound"
        created_at_utc = [DateTime]::UtcNow.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
        admission_ledger_sha256 = [string]$admission.fingerprint
        claim_fingerprint = [string]$admission.fingerprint
        run_id = [string]$ledger.run_id
        repository_head = [string]$ledger.repository_head
        scenario_fingerprint = [string]$ledger.scenario_fingerprint
        timeout_policy_fingerprint = [string]$ledger.timeout_policy_fingerprint
        challenge_depth = [int]$ledger.challenge_depth
        seed = [int64]$ledger.seed
        local_player_count = [int]$ledger.local_player_count
        ai_player_count = [int]$ledger.ai_player_count
        rehearsal_only = $true
        nonofficial = $true
        official = $false
        formal = $false
        official_authorization_consumed = $false
        admission_evidence_sha256 = [string]$ledger.admission_evidence_sha256
        admission_evidence_fingerprint = [string]$ledger.admission_evidence_fingerprint
        official_attempt_1_claim_sha256 = [string]$ledger.official_attempt_1_claim_sha256
        official_attempt_2_claim_absent = $true
        official_claim_inventory_fingerprint = [string]$ledger.official_claim_inventory_fingerprint
        process_role = [string]$ledger.process_role
        claim_nonce = [string]$ledger.claim_nonce
        launch_nonce = [string]$ledger.launch_nonce
        orchestrator_process_id = [int]$attestation.orchestrator_process_id
        orchestrator_creation_time_utc_ticks = [string]$attestation.orchestrator_creation_time_utc_ticks
        wrapper_process_id = [int]$attestation.wrapper_process_id
        wrapper_parent_process_id = [int]$attestation.wrapper_parent_process_id
        wrapper_creation_time_utc_ticks = [string]$attestation.wrapper_creation_time_utc_ticks
        engine_process_id = [int]$attestation.engine_process_id
        engine_parent_process_id = [int]$attestation.engine_parent_process_id
        engine_creation_time_utc_ticks = [string]$attestation.engine_creation_time_utc_ticks
        launch_attestation_sha256 = [string]$launchArtifact.sha256
        ledger_fingerprint = ""
    }
    $launchLedger.ledger_fingerprint = Get-ProcessARehearsalFingerprint $launchLedger "ledger_fingerprint"
    Assert-ProcessARehearsalLaunchLedgerValue ([pscustomobject]$launchLedger)
    try {
        $launchLedgerSha = Write-ProcessARehearsalExclusiveAtomicJson $LaunchLedgerPath ([pscustomobject]$launchLedger)
    }
    catch {
        if ([string]$_.Exception.Message -eq "process_a_rehearsal_atomic_target_exists") {
            throw (Get-ProcessARehearsalLaunchCollisionReason $LaunchLedgerPath ([pscustomobject]$launchLedger))
        }
        throw
    }
    return [pscustomobject]@{
        path = [IO.Path]::GetFullPath($LaunchLedgerPath)
        fingerprint = [string]$launchLedgerSha
        value = [pscustomobject]$launchLedger
    }
}

function Get-ProcessARehearsalAdmissionContractInfo {
    [CmdletBinding()]
    param()

    return [pscustomobject]@{
        contract_id = $script:ContractId
        admission_ledger_id = $script:AdmissionLedgerId
        launch_ledger_id = $script:LaunchLedgerId
        authorization_id = $script:AuthorizationId
        official_attempt_1_claim_sha256 = $script:OfficialAttempt1ClaimSha256
        challenge_depth = $script:ChallengeDepth
        seed = $script:Seed
        local_player_count = $script:LocalPlayerCount
        ai_player_count = $script:AiPlayerCount
        admission_ledger_fields = @($script:AdmissionLedgerFields)
        launch_authorization_fields = @($script:LaunchAuthorizationFields)
        launch_ledger_fields = @($script:LaunchLedgerFields)
    }
}

Export-ModuleMember -Function @(
    "Get-ProcessARehearsalAdmissionContractInfo",
    "Get-ProcessARehearsalAdmissionEvidence",
    "Write-ProcessARehearsalExclusiveAtomicJson",
    "New-ProcessARehearsalAdmission",
    "Assert-ProcessARehearsalAdmissionSourcesUnchanged",
    "Read-ProcessARehearsalAdmissionLedger",
    "Get-ProcessARehearsalLaunchAuthorization",
    "Complete-ProcessARehearsalLaunch",
    "Read-ProcessARehearsalLaunchLedger"
)
