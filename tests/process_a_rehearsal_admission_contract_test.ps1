[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $root "scripts\tools\process_a_rehearsal_admission_contract.psm1"
$authorizationModulePath = Join-Path $root "scripts\tools\cold_restore_authorization_contract_v1.psm1"
Import-Module $authorizationModulePath -Force
$targetedAuthorization = `
    Get-ColdRestoreAuthorizationEntry "targeted_owner_capture_diagnostic_v4_importchain"
$rehearsalAuthorization = Get-ColdRestoreAuthorizationEntry "process_a_save_completion_rehearsal_v1"
$officialAuthorization = Get-ColdRestoreAuthorizationEntry "official_attempt_2"
Import-Module $modulePath -Force
Import-Module $authorizationModulePath -Force
$contractModule = Get-Module process_a_rehearsal_admission_contract

$head = "0123456789abcdef0123456789abcdef01234567"
$scenarioFingerprint = "0bccef8426345e2ea1fd8ae7d6187d282d52d44bc73d6fb3d1ed3375dc20b7bf"
$prerequisiteFingerprint = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
$sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
$officialAttempt1Sha = [string]$officialAuthorization.attempt_1_claim_sha256
$officialAttempt1Text = '{"authorization_id":"alpha04c-p0-cold-restore-depth1-seed900626424-v1","authorized_official_count":1,"challenge_depth":1,"claim_nonce":"880e209871804c37871997f4b3177507","created_at_utc":"2026-07-30T06:09:56.4081399Z","official_count_after":1,"official_count_before":0,"orchestrator_creation_time_utc_ticks":"639209885951511870","orchestrator_id":"alpha04c_cold_restore_vertical_slice_orchestrator_v3","orchestrator_process_id":16120,"orchestrator_schema_version":3,"orchestrator_script_sha256":"e3bccd881ee44c76a82118932806a8785bbc4f2bde96afe697941eb23a57c0c8","qualification_child_attestation_fingerprint":"d0d2f437ec4f7a5eb5445053589d809d9c6440cdea1628de5d9f57355cbeb192","qualification_parent_attestation_sha256":"56822a6fb0870239e0b172bca0bdb98219dd8e02b6d72b915037a4ec06155bc5","qualification_result_sha256":"107ca42897f6ca7963ffb42f09df121e1221a7793f32f3dc21eaf0df5fd495ba","run_id":"alpha04c-facility-bridge-ca3b7cf4","scenario_fingerprint":"0bccef8426345e2ea1fd8ae7d6187d282d52d44bc73d6fb3d1ed3375dc20b7bf","schema_version":1,"seed":900626424,"source_head_sha":"ca3b7cf4222a6145bed81606fc4f04b7076ae0d9","status":"consumed"}'
$sectionOrder = @(
    "ruleset", "region_infrastructure", "region_supply", "commodity_flow",
    "routes", "player_mana", "commodity_belt_visibility", "card_inventory",
    "player_organization", "monsters", "military", "weather",
    "card_resolution_queue", "card_resolution_execution", "card_resolution_history",
    "ai", "bankruptcy_neutral_estate", "victory_control", "session"
)
$ownerOrder = @(
    "ruleset_runtime", "public_facility_region", "region_supply", "commodity_flow",
    "route_network", "player_mana", "commodity_belt_visibility", "card_inventory",
    "player_organization", "monster_runtime", "military_runtime", "weather_runtime",
    "card_resolution_queue", "card_resolution_execution", "card_resolution_history",
    "ai_runtime", "bankruptcy_neutral_estate", "victory_control", "game_session"
)

$checks = 0
$failures = [Collections.Generic.List[string]]::new()
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "alpha04c process a rehearsal contract 中文 $([Guid]::NewGuid().ToString('N'))"
[IO.Directory]::CreateDirectory($testRoot) | Out-Null

function Assert-ContractCondition {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $script:checks += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
        Write-Error $Message -ErrorAction Continue
    }
}

function Assert-ContractThrows {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter(Mandatory = $true)][string]$ReasonCode,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $thrown = ""
    try {
        & $Action
    }
    catch {
        $thrown = [string]$_.Exception.Message
    }
    Assert-ContractCondition ($thrown -ceq $ReasonCode) "$Message (actual=$thrown)"
}

function Get-TestFingerprint {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [string]$OmittedField = ""
    )

    return & $script:contractModule {
        param($InnerValue, $InnerOmittedField)
        Get-ProcessARehearsalFingerprint $InnerValue $InnerOmittedField
    } $Value $OmittedField
}

function ConvertTo-TestCanonicalJson {
    param([Parameter(Mandatory = $true)]$Value)

    return & $script:contractModule {
        param($InnerValue)
        ConvertTo-ProcessARehearsalCanonicalJson $InnerValue
    } $Value
}

function Write-TestJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )

    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    [IO.File]::WriteAllText($Path, (ConvertTo-TestCanonicalJson $Value), [Text.UTF8Encoding]::new($false))
}

function Read-TestJson {
    param([Parameter(Mandatory = $true)][string]$Path)

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -DateKind String
}

function Seal-TestValue {
    param(
        [Parameter(Mandatory = $true)][Collections.IDictionary]$Value,
        [Parameter(Mandatory = $true)][string]$FingerprintField
    )

    $Value[$FingerprintField] = ""
    $Value[$FingerprintField] = Get-TestFingerprint $Value $FingerprintField
    return [pscustomobject]$Value
}

function New-TestDiagnostic {
    param(
        [Parameter(Mandatory = $true)][string]$RepositoryHead,
        [Parameter(Mandatory = $true)][string]$Scenario,
        [bool]$SafetyGreen = $true,
        [object]$FirstPrivatePayloadRedacted = $true
    )

    $diagnosticRunId = Get-ColdRestoreAuthorizationRunId `
        "targeted_owner_capture_diagnostic_v4_importchain" $RepositoryHead
    $identity = Seal-TestValue ([ordered]@{
        schema_version = 1
        identity_id = "DiagnosticScenarioIdentityV1"
        run_id = $diagnosticRunId
        repository_head = $RepositoryHead
        ruleset_id = "v0.6"
        ruleset_fingerprint = $sha
        challenge_depth = 1
        run_seed_tagged_int64 = [ordered]@{ '$codec' = "Int64"; value = "900626424" }
        session_seed_tagged_int64 = [ordered]@{ '$codec' = "Int64"; value = "42" }
        scenario_fingerprint = $Scenario
        local_player_count = 1
        ai_player_count = 3
        roster_fingerprint = $sha
        session_id = "diagnostic-session"
        session_generation = 1
        session_plan_fingerprint = $sha
        world_revision = 1
        runtime_composition_fingerprint = $sha
        save_registry_fingerprint = $sha
        user_data_path_fingerprint = $sha
        diagnostic_role = "targeted_owner_diagnostic"
    }) "identity_fingerprint"

    $phaseSpecs = [Collections.Generic.List[object]]::new()
    foreach ($phase in @(
        "diagnostic_started", "session_creating", "session_started",
        "scenario_identity_attesting", "scenario_identity_attested",
        "registry_binding_attesting", "registry_binding_attested", "owner_audit_started"
    )) {
        $phaseSpecs.Add([pscustomobject]@{ phase_id = $phase; owner_index = -1; reason_code = "ok" })
    }
    for ($ownerIndex = 0; $ownerIndex -lt 19; $ownerIndex += 1) {
        $phaseSpecs.Add([pscustomobject]@{ phase_id = "owner_capture_started"; owner_index = $ownerIndex; reason_code = "owner_capture_started" })
        $phaseSpecs.Add([pscustomobject]@{ phase_id = "owner_capture_succeeded"; owner_index = $ownerIndex; reason_code = "owner_capture_valid" })
    }
    $phaseSpecs.Add([pscustomobject]@{ phase_id = "owner_audit_completed"; owner_index = -1; reason_code = "ok" })
    $phaseSpecs.Add([pscustomobject]@{ phase_id = "diagnostic_completed"; owner_index = -1; reason_code = "diagnostic_owner_audit_completed" })
    $timelineRows = @()
    for ($index = 0; $index -lt $phaseSpecs.Count; $index += 1) {
        $spec = $phaseSpecs[$index]
        $timelineRows += Seal-TestValue ([ordered]@{
            sequence = $index + 1
            phase_id = [string]$spec.phase_id
            owner_index = [int]$spec.owner_index
            completed_monotonic_ms = 1000 + ($index * 10)
            success = $true
            reason_code = [string]$spec.reason_code
        }) "evidence_fingerprint"
    }
    $timeline = Seal-TestValue ([ordered]@{
        schema_version = 1
        timeline_id = "TargetedOwnerCaptureDiagnosticPhaseTimelineV1"
        run_id = $diagnosticRunId
        repository_head = $RepositoryHead
        phase_rows = $timelineRows
        last_completed_phase = "diagnostic_completed"
        current_phase = "diagnostic_completed"
        next_expected_phase = "none"
    }) "evidence_fingerprint"

    $ownerRows = @()
    for ($index = 0; $index -lt 19; $index += 1) {
        $ownerRows += Seal-TestValue ([ordered]@{
            owner_index = $index
            section_id = $sectionOrder[$index]
            owner_id = $ownerOrder[$index]
            owner_path = "../../Owner$index"
            capture_started = $true
            capture_completed = $true
            capture_result_kind = "CAPTURED"
            payload_schema_version = 3
            payload_fingerprint = $sha
            payload_pure_data = $true
            elapsed_milliseconds = 1
            mutation_count = 0
            rng_draw_delta = 0
            world_time_delta = 0
            public_log_delta = 0
            reason_code = "owner_capture_valid"
            private_payload_redacted = if ($index -eq 0) { $FirstPrivatePayloadRedacted } else { $true }
        }) "row_evidence_fingerprint"
    }

    return Seal-TestValue ([ordered]@{
        schema_version = 2
        diagnostic_id = "TargetedOwnerCaptureDiagnosticV2"
        run_id = $diagnosticRunId
        repository_head = $RepositoryHead
        official = $false
        formal = $false
        scenario_identity = $identity
        scenario_identity_attested = $true
        scenario_identity_failure = [pscustomobject]@{}
        harness_or_scenario_failure_attested = $false
        diagnostic_phase_timeline = $timeline
        last_completed_diagnostic_phase = "diagnostic_completed"
        current_diagnostic_phase = "diagnostic_completed"
        next_expected_diagnostic_phase = "none"
        owner_audit_started = $true
        owner_audit_completed = $true
        first_owner_capture_index = 0
        last_completed_owner_capture_index = 18
        owner_capture_attempted_count = 19
        owner_capture_succeeded_count = 19
        owner_capture_failed_count = 0
        owner_capture_skipped_count = 0
        owner_capture_rows = $ownerRows
        first_failure = [pscustomobject]@{}
        owner_capture_failure_attested = $false
        post_capture_validation = "PASSED"
        post_capture_failure = [pscustomobject]@{}
        safety_green = $SafetyGreen
        save_file_exists = $false
        official_claim_path_present = $false
    }) "evidence_fingerprint"
}

function New-TestPolicy {
    param([int]$AbsoluteTimeoutSeconds = 120)

    return [pscustomobject][ordered]@{
        schema_version = 1
        policy_id = "ColdRestoreRoleTimeoutPolicyV1"
        policy_source = "focused_contract_fixture"
        measurement_head = "fedcba9876543210fedcba9876543210fedcba98"
        measurement_run_id = "fixture-measurement"
        poll_interval_ms = 100
        normal_exit_grace_seconds = 5
        stream_drain_grace_seconds = 2
        process_tree_cleanup_grace_seconds = 5
        progress_heartbeat_fields = @(
            "phase",
            "world_time",
            "owner_index",
            "queue_revision",
            "save_phase",
            "last_evidence_write_time"
        )
        roles = [pscustomobject][ordered]@{
            targeted_owner_diagnostic = [pscustomobject][ordered]@{
                absolute_timeout_seconds = 120
                no_progress_timeout_seconds = 30
                timeout_reason_code = "targeted_owner_diagnostic_timeout"
                cleanup_policy = "kill_task_tree_then_verify_pid_and_creation_time"
                contract_only_in_this_task = $false
            }
            process_a = [pscustomobject][ordered]@{
                absolute_timeout_seconds = $AbsoluteTimeoutSeconds
                no_progress_timeout_seconds = 30
                timeout_reason_code = "process_a_timeout"
                cleanup_policy = "kill_task_tree_then_verify_pid_and_creation_time"
                contract_only_in_this_task = $false
            }
            process_b = [pscustomobject][ordered]@{
                absolute_timeout_seconds = 360
                no_progress_timeout_seconds = 60
                timeout_reason_code = "process_b_timeout"
                cleanup_policy = "kill_task_tree_then_verify_pid_and_creation_time"
                contract_only_in_this_task = $false
            }
            process_c = [pscustomobject][ordered]@{
                absolute_timeout_seconds = 180
                no_progress_timeout_seconds = 30
                timeout_reason_code = "process_c_timeout"
                cleanup_policy = "kill_task_tree_then_verify_pid_and_creation_time"
                contract_only_in_this_task = $false
            }
        }
    }
}

function New-TestDiagnosticQuotaLedger {
    param(
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$RepositoryHead,
        [Parameter(Mandatory = $true)][string]$Scenario,
        [Parameter(Mandatory = $true)][string]$TimeoutPolicyFingerprint,
        [Parameter(Mandatory = $true)][string]$BootstrapPath,
        [Parameter(Mandatory = $true)][string]$BootstrapSha256,
        [Parameter(Mandatory = $true)][string]$BootstrapFingerprint,
        [Parameter(Mandatory = $true)][string]$PreQuotaPath
    )

    $orchestratorCreationTicks = & $script:contractModule {
        Get-ProcessARehearsalCurrentCreationTicks
    }
    $claimNonce = [Guid]::NewGuid().ToString("N")
    do {
        $launchNonce = [Guid]::NewGuid().ToString("N")
    } while ($launchNonce -ceq $claimNonce)

    return [pscustomobject][ordered]@{
        schema_version = 4
        ledger_id = [string]$targetedAuthorization.ledger_id
        authorization_id = [string]$targetedAuthorization.authorization_id
        task_id = [string]$targetedAuthorization.task_id
        created_at_utc = "2026-07-30T15:00:00.0000000Z"
        run_id = $RunId
        repository_head = $RepositoryHead
        scenario_fingerprint = $Scenario
        authorized_new_diagnostic_count = [int]$targetedAuthorization.authorized_increment
        diagnostic_count_before = [int]$targetedAuthorization.permitted_transition_from
        diagnostic_count_after = [int]$targetedAuthorization.permitted_transition_to
        diagnostic_count_maximum = [int]$targetedAuthorization.maximum_invocation_count
        previous_ledger_sha256 = "2dba183fe0e354370802d0f886bf40a88b7e1c0b39ddb0df18ee110821e957a1"
        historical_invocation_commit = "3b3061508541d0e5f6f4c2d6560b134b7d4ee5f8"
        historical_invocation_blob_sha1 = "b54917e54a39e24e1c7288d919394305a4e21c71"
        historical_invocation_file_sha256 = "50608e7dc7a362969d0ee7358ba008aa0278342ae34d33cd579fcac7bf8a7306"
        bootstrap_admission_path = [IO.Path]::GetFullPath($BootstrapPath)
        bootstrap_admission_sha256 = $BootstrapSha256
        bootstrap_admission_fingerprint = $BootstrapFingerprint
        prequota_attestation_path = [IO.Path]::GetFullPath($PreQuotaPath)
        role_timeout_policy_sha256 = $TimeoutPolicyFingerprint
        official_attempt_1_claim_sha256 = $officialAttempt1Sha
        official_attempt_2_claim_absent = $true
        official = $false
        formal = $false
        official_authorization_consumed = $false
        orchestrator_script_sha256 = $sha
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = $orchestratorCreationTicks
        claim_nonce = $claimNonce
        launch_nonce = $launchNonce
        status = "consumed"
    }
}

function New-TestDiagnosticLaunchAttestation {
    param(
        [Parameter(Mandatory = $true)]$Quota,
        [Parameter(Mandatory = $true)][string]$QuotaRawSha256,
        [int]$WrapperPid = 41001,
        [int]$EnginePid = 41002
    )

    return [pscustomobject][ordered]@{
        schema_version = 1
        authorization_id = [string]$targetedAuthorization.authorization_id
        claim_fingerprint = $QuotaRawSha256
        claim_nonce = [string]$Quota.claim_nonce
        source_head_sha = [string]$Quota.repository_head
        scenario_fingerprint = [string]$Quota.scenario_fingerprint
        run_id = [string]$Quota.run_id
        process_role = "producer"
        launch_nonce = [string]$Quota.launch_nonce
        orchestrator_process_id = [int]$Quota.orchestrator_process_id
        orchestrator_creation_time_utc_ticks = [string]$Quota.orchestrator_creation_time_utc_ticks
        wrapper_process_id = $WrapperPid
        wrapper_parent_process_id = [int]$Quota.orchestrator_process_id
        wrapper_creation_time_utc_ticks = "638000000000000000"
        engine_process_id = $EnginePid
        engine_parent_process_id = $WrapperPid
        engine_creation_time_utc_ticks = "638000000000000010"
        status = "authorized"
    }
}

function New-TestDiagnosticManifest {
    param(
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$RepositoryHead,
        [Parameter(Mandatory = $true)][string]$Scenario,
        [int]$EnginePid = 41002,
        [string]$FailureCode = "targeted_owner_capture_all_owners_succeeded"
    )

    return [pscustomobject][ordered]@{
        schema_version = 4
        visibility_scope = "qa_allowlisted"
        run_id = $RunId
        process_role = "producer"
        process_id = $EnginePid
        head_sha = $RepositoryHead
        scenario_fingerprint = $Scenario
        slot_id = "current_run"
        slot_state = "failed"
        source_sections_digest = ""
        restored_sections_digest = ""
        saved_sections_digest = ""
        source_write_id = ""
        write_id = ""
        source_write_fingerprint = ""
        write_fingerprint = ""
        section_count = 0
        preflight_count = 0
        owner_apply_count = 0
        registry_apply_count = 0
        registry_commit_count = 0
        registry_rebind_count = 0
        partial_restore_state_count = 0
        save_capture_world_delta = 0
        save_capture_rng_delta = 0
        save_capture_log_delta = 0
        rng_draw_count_before = 0
        rng_draw_count_after = 0
        restore_rng_draw_delta = 0
        restore_world_time_delta = 0
        restore_public_log_delta = 0
        restore_sale_receipt_delta = 0
        restore_economic_reward_delta = 0
        restore_ai_action_delta = 0
        restore_player_action_delta = 0
        restore_notification_delta = 0
        restore_private_feedback_delta = 0
        human_action_count = 0
        commodity_action_count = 0
        ai_action_count = 0
        sale_receipt_count = 0
        normal_card_count = 0
        commodity_card_count = 0
        commodity_claim_count = 0
        facility_count = 0
        route_count = 0
        military_unit_count = 0
        queue_entry_count = 1
        weather_region_count = 0
        ai_nondefault_state_count = 1
        queue_trigger_resolution_id = 1
        queue_trigger_stable_target_fingerprint = $sha
        queue_target_pending_before_resume = 1
        queue_target_pending_after_resume = 1
        queue_target_completed_before_resume = 0
        queue_target_completed_after_resume = 0
        queue_target_history_before_resume = 0
        queue_target_history_after_resume = 0
        queue_target_execution_finalize_delta = 0
        queue_target_history_append_delta = 0
        queue_target_history_duplicate_delta = 0
        queue_target_transition_duplicate_delta = 0
        queue_target_inventory_queue_commit_delta = 0
        queue_target_public_log_duplicate_delta = 0
        queue_target_public_log_collision_delta = 0
        duplicate_queue_entry_count = 0
        duplicate_facility_creation_count = 0
        duplicate_card_consumption_count = 0
        duplicate_cost_consumption_count = 0
        duplicate_sale_receipt_count = 0
        world_fingerprint_match = $false
        rng_cursor_match = $false
        ai_state_fingerprint_match = $false
        card_inventory_fingerprint_match = $false
        queue_fingerprint_match = $false
        generation_2_recapture_fingerprint_match = $false
        generation_2_rng_cursor_match = $false
        generation_2_duplicate_transaction_count = 0
        victory_unresolved_before_save = $true
        production_surface_ready = $true
        victory_state_sequence = @()
        final_settlement_count = 0
        final_settlement_presentation_count = 0
        final_settlement_public_log_count = 0
        terminal_quiescent_frames = 0
        terminal_world_delta = 0
        terminal_rng_draw_delta = 0
        generation = 0
        backup_created = $false
        save_readback_green = $false
        save_fingerprint_parity = $false
        elapsed_ms = 1000
        success = $false
        failure_code = $FailureCode
    }
}

function New-TestDiagnosticChildCompletionAttestation {
    param(
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$RepositoryHead,
        [Parameter(Mandatory = $true)][string]$Scenario,
        [Parameter(Mandatory = $true)][string]$DiagnosticRawSha256
    )

    return Seal-TestValue ([ordered]@{
        schema_version = 1
        run_id = $RunId
        role = "producer"
        repository_head = $RepositoryHead
        scenario_fingerprint = $Scenario
        official = $false
        formal = $false
        qualification_completed = $true
        qualification_green = $false
        product_blocker = "TARGETED_OWNER_CAPTURE_DIAGNOSTIC_SHA256:$DiagnosticRawSha256"
        queue_count = 1
        queue_revision = 1
        queue_trigger_actor = "player-1"
        queue_trigger_semantic_action_id = "facility_card_queue_submission"
        queue_trigger_card_semantic_id = "facility.factory.energy.rank_1"
        queue_trigger_target_fingerprint = $sha
        save_written = $false
        official_count_consumed = $false
        product_mutation_count = 0
        direct_authority_mutation_count = 0
        queue_injection_count = 0
        final_reason_code = "targeted_owner_capture_diagnostic_sha256_$DiagnosticRawSha256"
        child_ready_to_exit = $true
    }) "evidence_fingerprint"
}

function New-TestDiagnosticParentExitAttestation {
    param(
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$ChildFingerprint,
        [Parameter(Mandatory = $true)][string]$StdoutSha256,
        [Parameter(Mandatory = $true)][string]$StderrSha256,
        [Parameter(Mandatory = $true)][string]$TimeoutPolicyFingerprint
    )

    return [pscustomobject][ordered]@{
        schema_version = 2
        run_id = $RunId
        role = "producer"
        child_pid = 41002
        observed_exit = $true
        exit_code = 0
        timed_out = $false
        terminated_by_parent = $false
        stdout_sha256 = $StdoutSha256
        stderr_sha256 = $StderrSha256
        child_attestation_found = $true
        child_attestation_fingerprint = $ChildFingerprint
        child_attestation_valid = $true
        task_owned_process_count_after = 0
        unrelated_preexisting_process_count = 0
        wrapper_exit_green = $true
        wrapper_reason_code = "ok"
        policy_role = "targeted_owner_diagnostic"
        timeout_policy_fingerprint = $TimeoutPolicyFingerprint
        absolute_timeout_seconds = 120
        no_progress_timeout_seconds = 30
        timeout_kind = "none"
        progress_heartbeat_found = $true
        progress_heartbeat_valid = $true
        progress_heartbeat_sequence = 61
        progress_heartbeat_fingerprint = $sha
        progress_semantic_fingerprint = $sha
        progress_phase = "quit_requested"
        progress_last_evidence_write_time = 638000000000000000
        task_owned_process_identity_fingerprint = $sha
    }
}

function New-TestFixture {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$PolicyTimeout = 120,
        [bool]$SafetyGreen = $true,
        [object]$FirstPrivatePayloadRedacted = $true
    )

    $fixtureRoot = Join-Path $testRoot $Name
    $officialRoot = Join-Path $fixtureRoot "git-common\codex\cold_restore_v3"
    $attempt1Directory = Join-Path $officialRoot "official-alpha04c-depth1-seed900626424"
    $attempt1Path = Join-Path $attempt1Directory "official_claim_ledger.json"
    $evidencePath = Join-Path $fixtureRoot "evidence\owner_capture_audit.json"
    $policyPath = Join-Path $fixtureRoot "policy\cold_restore_role_timeout_policy_v1.json"
    $diagnosticQuotaPath = Join-Path $fixtureRoot "ledger\targeted_owner_capture_diagnostic_quota_v3.json"
    $bootstrapPath = Join-Path $fixtureRoot "bootstrap\bootstrap.admission.json"
    $preQuotaPath = Join-Path $fixtureRoot "bootstrap\prequota_orchestrator_attestation.json"
    $diagnosticLaunchAttestationPath = Join-Path $fixtureRoot "evidence\targeted_owner_capture.launch.json"
    $diagnosticManifestPath = Join-Path $fixtureRoot "evidence\targeted_owner_capture.manifest.json"
    $diagnosticChildPath = Join-Path $fixtureRoot "evidence\targeted_owner_capture.child.json"
    $diagnosticParentPath = Join-Path $fixtureRoot "evidence\targeted_owner_capture.parent.json"
    $diagnosticStdoutPath = Join-Path $fixtureRoot "evidence\targeted_owner_capture.stdout.log"
    $diagnosticStderrPath = Join-Path $fixtureRoot "evidence\targeted_owner_capture.stderr.log"
    [IO.Directory]::CreateDirectory($attempt1Directory) | Out-Null
    [IO.File]::WriteAllText($attempt1Path, $officialAttempt1Text, [Text.UTF8Encoding]::new($false))
    Write-TestJson $policyPath (New-TestPolicy $PolicyTimeout)
    $policyFingerprint = (Get-FileHash -LiteralPath $policyPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $diagnostic = New-TestDiagnostic $head $scenarioFingerprint $SafetyGreen $FirstPrivatePayloadRedacted
    Write-TestJson $evidencePath $diagnostic
    $diagnosticRawSha256 = (Get-FileHash -LiteralPath $evidencePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $diagnosticRunId = [string]$diagnostic.run_id
    [IO.Directory]::CreateDirectory((Split-Path -Parent $diagnosticStdoutPath)) | Out-Null
    [IO.File]::WriteAllText($diagnosticStdoutPath, "TARGETED_OWNER_CAPTURE_DIAGNOSTIC|run_id=$diagnosticRunId|status=PASS`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($diagnosticStderrPath, "", [Text.UTF8Encoding]::new($false))
    $orchestratorCreationTicks = & $script:contractModule {
        Get-ProcessARehearsalCurrentCreationTicks
    }
    $bootstrap = Seal-TestValue ([ordered]@{
        schema_version = 1
        admission_id = "PreQuotaOrchestratorBootstrapAdmissionV1"
        created_at_utc = "2026-07-30T14:59:59.0000000Z"
        run_id = $diagnosticRunId
        role = "targeted_owner_diagnostic"
        repository_head = $head
        branch = "codex/fixture"
        authorization_id = [string]$targetedAuthorization.authorization_id
        historical_count = [int]$targetedAuthorization.permitted_transition_from
        authorized_increment = [int]$targetedAuthorization.authorized_increment
        maximum_allowed_count = [int]$targetedAuthorization.maximum_invocation_count
        official = $false
        formal = $false
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = $orchestratorCreationTicks
        invocation_nonce = [Guid]::NewGuid().ToString("N")
        admission_fingerprint = ""
    }) "admission_fingerprint"
    Write-TestJson $bootstrapPath $bootstrap
    $bootstrapSha256 = (Get-FileHash -LiteralPath $bootstrapPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $preQuota = Seal-TestValue ([ordered]@{
        schema_version = 1
        attestation_id = "PreQuotaOrchestratorAttestationV1"
        run_id = $diagnosticRunId
        role = "targeted_owner_diagnostic"
        repository_head = $head
        branch = "codex/fixture"
        authorization_checked = $true
        historical_count = [int]$targetedAuthorization.permitted_transition_from
        authorized_increment = [int]$targetedAuthorization.authorized_increment
        maximum_allowed_count = [int]$targetedAuthorization.maximum_invocation_count
        quota_claim_attempted = $true
        quota_claimed = $true
        quota_ledger_path = [IO.Path]::GetFullPath($diagnosticQuotaPath)
        evidence_root_creation_attempted = $true
        evidence_root_created = $true
        godot_launch_attempted = $true
        godot_launched = $true
        primary_failure_phase = ""
        primary_failure_code = ""
        secondary_failure_codes = @()
        task_owned_process_count_after = 0
        bootstrap_admission_sha256 = $bootstrapSha256
        bootstrap_admission_fingerprint = [string]$bootstrap.admission_fingerprint
        updated_at_utc = "2026-07-30T15:00:01.0000000Z"
        attestation_fingerprint = ""
    }) "attestation_fingerprint"
    Write-TestJson $preQuotaPath $preQuota
    $diagnosticQuota = New-TestDiagnosticQuotaLedger `
        $diagnosticRunId $head $scenarioFingerprint $policyFingerprint `
        $bootstrapPath $bootstrapSha256 ([string]$bootstrap.admission_fingerprint) $preQuotaPath
    Write-TestJson $diagnosticQuotaPath $diagnosticQuota
    $diagnosticQuotaRawSha256 = (Get-FileHash -LiteralPath $diagnosticQuotaPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-TestJson $diagnosticLaunchAttestationPath (New-TestDiagnosticLaunchAttestation $diagnosticQuota $diagnosticQuotaRawSha256)
    Write-TestJson $diagnosticManifestPath (New-TestDiagnosticManifest $diagnosticRunId $head $scenarioFingerprint)
    $child = New-TestDiagnosticChildCompletionAttestation $diagnosticRunId $head $scenarioFingerprint $diagnosticRawSha256
    Write-TestJson $diagnosticChildPath $child
    $stdoutSha256 = (Get-FileHash -LiteralPath $diagnosticStdoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $stderrSha256 = (Get-FileHash -LiteralPath $diagnosticStderrPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-TestJson $diagnosticParentPath (New-TestDiagnosticParentExitAttestation $diagnosticRunId $child.evidence_fingerprint $stdoutSha256 $stderrSha256 $policyFingerprint)
    return [pscustomobject]@{
        root = $fixtureRoot
        official_root = $officialRoot
        attempt_1_path = $attempt1Path
        evidence_path = $evidencePath
        policy_path = $policyPath
        bootstrap_path = $bootstrapPath
        prequota_path = $preQuotaPath
        diagnostic_quota_path = $diagnosticQuotaPath
        diagnostic_launch_attestation_path = $diagnosticLaunchAttestationPath
        diagnostic_manifest_path = $diagnosticManifestPath
        diagnostic_child_path = $diagnosticChildPath
        diagnostic_parent_path = $diagnosticParentPath
        diagnostic_stdout_path = $diagnosticStdoutPath
        diagnostic_stderr_path = $diagnosticStderrPath
        admission_path = Join-Path $fixtureRoot "ledger\process_a_rehearsal_admission.json"
        launch_path = Join-Path $fixtureRoot "ledger\process_a_rehearsal_launch.json"
        launch_attestation_path = Join-Path $fixtureRoot "evidence\producer.launch.json"
        run_id = "$([string]$rehearsalAuthorization.run_id_prefix)-$Name"
    }
}

function Get-TestAdmissionEvidence {
    param([Parameter(Mandatory = $true)]$Fixture)

    $policyFingerprint = (Get-FileHash -LiteralPath $Fixture.policy_path -Algorithm SHA256).Hash.ToLowerInvariant()
    return Get-ProcessARehearsalAdmissionEvidence `
        -Path $Fixture.evidence_path `
        -ExpectedRepositoryHead $head `
        -ExpectedScenarioFingerprint $scenarioFingerprint `
        -DiagnosticQuotaLedgerPath $Fixture.diagnostic_quota_path `
        -DiagnosticLaunchAttestationPath $Fixture.diagnostic_launch_attestation_path `
        -DiagnosticManifestPath $Fixture.diagnostic_manifest_path `
        -ChildAttestationPath $Fixture.diagnostic_child_path `
        -ParentAttestationPath $Fixture.diagnostic_parent_path `
        -StdoutPath $Fixture.diagnostic_stdout_path `
        -StderrPath $Fixture.diagnostic_stderr_path `
        -ExpectedTimeoutPolicyFingerprint $policyFingerprint
}

function Invoke-TestAdmission {
    param([Parameter(Mandatory = $true)]$Fixture)

    return New-ProcessARehearsalAdmission `
        -LedgerPath $Fixture.admission_path `
        -RunId $Fixture.run_id `
        -RepositoryHead $head `
        -ScenarioFingerprint $scenarioFingerprint `
        -PrerequisiteEvidenceFingerprint $prerequisiteFingerprint `
        -TimeoutPolicyPath $Fixture.policy_path `
        -AdmissionEvidencePath $Fixture.evidence_path `
        -DiagnosticQuotaLedgerPath $Fixture.diagnostic_quota_path `
        -DiagnosticLaunchAttestationPath $Fixture.diagnostic_launch_attestation_path `
        -DiagnosticManifestPath $Fixture.diagnostic_manifest_path `
        -DiagnosticChildAttestationPath $Fixture.diagnostic_child_path `
        -DiagnosticParentAttestationPath $Fixture.diagnostic_parent_path `
        -DiagnosticStdoutPath $Fixture.diagnostic_stdout_path `
        -DiagnosticStderrPath $Fixture.diagnostic_stderr_path `
        -OfficialClaimRoot $Fixture.official_root `
        -OfficialAttempt1ClaimPath $Fixture.attempt_1_path
}

function Assert-TestAdmissionSourcesUnchanged {
    param(
        [Parameter(Mandatory = $true)]$Fixture,
        [Parameter(Mandatory = $true)]$Admission
    )

    return Assert-ProcessARehearsalAdmissionSourcesUnchanged `
        -Admission $Admission `
        -PrerequisiteEvidenceFingerprint $prerequisiteFingerprint `
        -TimeoutPolicyPath $Fixture.policy_path `
        -AdmissionEvidencePath $Fixture.evidence_path `
        -DiagnosticQuotaLedgerPath $Fixture.diagnostic_quota_path `
        -DiagnosticLaunchAttestationPath $Fixture.diagnostic_launch_attestation_path `
        -DiagnosticManifestPath $Fixture.diagnostic_manifest_path `
        -DiagnosticChildAttestationPath $Fixture.diagnostic_child_path `
        -DiagnosticParentAttestationPath $Fixture.diagnostic_parent_path `
        -DiagnosticStdoutPath $Fixture.diagnostic_stdout_path `
        -DiagnosticStderrPath $Fixture.diagnostic_stderr_path `
        -OfficialClaimRoot $Fixture.official_root `
        -OfficialAttempt1ClaimPath $Fixture.attempt_1_path
}

function New-TestLaunchAttestation {
    param(
        [Parameter(Mandatory = $true)]$Authorization,
        [int]$WrapperPid = 42001,
        [int]$EnginePid = 42002
    )

    return [pscustomobject][ordered]@{
        schema_version = 1
        authorization_id = [string]$Authorization.authorization_id
        claim_fingerprint = [string]$Authorization.claim_fingerprint
        claim_nonce = [string]$Authorization.claim_nonce
        source_head_sha = [string]$Authorization.source_head_sha
        scenario_fingerprint = [string]$Authorization.scenario_fingerprint
        run_id = [string]$Authorization.run_id
        process_role = [string]$Authorization.process_role
        launch_nonce = [string]$Authorization.launch_nonce
        orchestrator_process_id = [int]$Authorization.orchestrator_process_id
        orchestrator_creation_time_utc_ticks = [string]$Authorization.orchestrator_creation_time_utc_ticks
        wrapper_process_id = $WrapperPid
        wrapper_parent_process_id = [int]$Authorization.orchestrator_process_id
        wrapper_creation_time_utc_ticks = "638000000000000000"
        engine_process_id = $EnginePid
        engine_parent_process_id = $WrapperPid
        engine_creation_time_utc_ticks = "638000000000000010"
        status = "authorized"
    }
}

function Complete-TestLaunch {
    param(
        [Parameter(Mandatory = $true)]$Fixture,
        [Parameter(Mandatory = $true)]$Admission
    )

    return Complete-ProcessARehearsalLaunch `
        -LaunchLedgerPath $Fixture.launch_path `
        -AdmissionLedgerPath $Fixture.admission_path `
        -ExpectedAdmissionLedgerSha256 $Admission.fingerprint `
        -PrerequisiteEvidenceFingerprint $prerequisiteFingerprint `
        -LaunchAttestationPath $Fixture.launch_attestation_path `
        -TimeoutPolicyPath $Fixture.policy_path `
        -AdmissionEvidencePath $Fixture.evidence_path `
        -DiagnosticQuotaLedgerPath $Fixture.diagnostic_quota_path `
        -DiagnosticLaunchAttestationPath $Fixture.diagnostic_launch_attestation_path `
        -DiagnosticManifestPath $Fixture.diagnostic_manifest_path `
        -DiagnosticChildAttestationPath $Fixture.diagnostic_child_path `
        -DiagnosticParentAttestationPath $Fixture.diagnostic_parent_path `
        -DiagnosticStdoutPath $Fixture.diagnostic_stdout_path `
        -DiagnosticStderrPath $Fixture.diagnostic_stderr_path `
        -OfficialClaimRoot $Fixture.official_root `
        -OfficialAttempt1ClaimPath $Fixture.attempt_1_path
}

try {
    $claimHash = (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.UTF8Encoding]::new($false).GetBytes($officialAttempt1Text))) -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-ContractCondition ($claimHash -ceq $officialAttempt1Sha) "embedded Attempt 1 fixture preserves the immutable production SHA-256"

    $info = Get-ProcessARehearsalAdmissionContractInfo
    Assert-ContractCondition ([string]$info.contract_id -ceq "Alpha04C.ProcessARehearsalAdmissionContractV1") "contract ID is closed"
    Assert-ContractCondition ([string]$info.admission_ledger_id -ceq "ProcessARehearsalAdmissionLedgerV3") "admission ledger schema is V3"
    Assert-ContractCondition ([string]$info.launch_ledger_id -ceq "ProcessARehearsalLaunchLedgerV1") "launch ledger schema is V1"
    Assert-ContractCondition ([int]$info.challenge_depth -eq 1 -and [int64]$info.seed -eq 900626424) "contract fixes challenge depth and seed"
    Assert-ContractCondition ([int]$info.local_player_count -eq 1 -and [int]$info.ai_player_count -eq 3) "contract fixes the 1 local plus 3 AI roster"
    Assert-ContractCondition ([string]$info.official_attempt_1_claim_sha256 -ceq $officialAttempt1Sha) "contract fixes the immutable Attempt 1 SHA"

    $validFixture = New-TestFixture "valid"
    $evidence = Get-TestAdmissionEvidence $validFixture
    $validDiagnosticSha256 = (Get-FileHash $validFixture.evidence_path -Algorithm SHA256).Hash.ToLowerInvariant()
    $validQuota = Read-TestJson $validFixture.diagnostic_quota_path
    $validDiagnosticLaunch = Read-TestJson $validFixture.diagnostic_launch_attestation_path
    $validDiagnosticManifest = Read-TestJson $validFixture.diagnostic_manifest_path
    $validChild = Read-TestJson $validFixture.diagnostic_child_path
    $validParent = Read-TestJson $validFixture.diagnostic_parent_path
    Assert-ContractCondition ([int]$evidence.owner_capture_succeeded_count -eq 19 -and [bool]$evidence.safety_green) "19/19 green diagnostic becomes bounded admission evidence"
    Assert-ContractCondition ([string]$evidence.binding_fingerprint -match '^[0-9a-f]{64}$') "admission evidence has a typed binding fingerprint"
    Assert-ContractCondition ([string]$validChild.product_blocker -ceq "TARGETED_OWNER_CAPTURE_DIAGNOSTIC_SHA256:$validDiagnosticSha256" -and [string]$validChild.final_reason_code -ceq "targeted_owner_capture_diagnostic_sha256_$validDiagnosticSha256") "Child completion reason fields bind the diagnostic raw SHA-256"
    Assert-ContractCondition ([string]$validParent.child_attestation_fingerprint -ceq [string]$validChild.evidence_fingerprint) "Parent exit attestation binds the Child completion fingerprint"
    Assert-ContractCondition ([string]$validParent.stdout_sha256 -ceq (Get-FileHash $validFixture.diagnostic_stdout_path -Algorithm SHA256).Hash.ToLowerInvariant() -and [string]$validParent.stderr_sha256 -ceq (Get-FileHash $validFixture.diagnostic_stderr_path -Algorithm SHA256).Hash.ToLowerInvariant()) "Parent exit attestation binds exact stdout and stderr bytes"
    Assert-ContractCondition ([string]$evidence.diagnostic_quota_ledger_sha256 -ceq (Get-FileHash $validFixture.diagnostic_quota_path -Algorithm SHA256).Hash.ToLowerInvariant()) "admission evidence binds exact TargetedOwnerCaptureDiagnosticQuotaLedgerV3 bytes"
    Assert-ContractCondition ([string]$validDiagnosticLaunch.authorization_id -ceq [string]$targetedAuthorization.authorization_id -and [string]$validDiagnosticLaunch.claim_fingerprint -ceq [string]$evidence.diagnostic_quota_ledger_sha256) "diagnostic launch binds the targeted authorization ID and exact quota bytes"
    Assert-ContractCondition ([string]$validDiagnosticLaunch.claim_nonce -ceq [string]$validQuota.claim_nonce -and [string]$validDiagnosticLaunch.launch_nonce -ceq [string]$validQuota.launch_nonce) "diagnostic launch binds both quota nonces"
    Assert-ContractCondition ([string]$evidence.diagnostic_launch_attestation_sha256 -ceq (Get-FileHash $validFixture.diagnostic_launch_attestation_path -Algorithm SHA256).Hash.ToLowerInvariant()) "admission evidence binds exact diagnostic LaunchAttestation bytes"
    Assert-ContractCondition ([string]$evidence.diagnostic_manifest_sha256 -ceq (Get-FileHash $validFixture.diagnostic_manifest_path -Algorithm SHA256).Hash.ToLowerInvariant()) "admission evidence binds exact atomic diagnostic manifest bytes"
    Assert-ContractCondition ([int]$validDiagnosticManifest.process_id -eq [int]$validDiagnosticLaunch.engine_process_id -and [int]$validParent.child_pid -eq [int]$validDiagnosticLaunch.engine_process_id) "manifest and Parent exit bind the authorized diagnostic engine PID"
    Assert-ContractCondition (-not [bool]$validDiagnosticManifest.success -and [string]$validDiagnosticManifest.failure_code -ceq "targeted_owner_capture_all_owners_succeeded") "diagnostic manifest remains unsuccessful while closing the successful audit reason"
    Assert-ContractCondition ([string]$evidence.diagnostic_child_attestation_sha256 -ceq (Get-FileHash $validFixture.diagnostic_child_path -Algorithm SHA256).Hash.ToLowerInvariant()) "admission evidence binds exact ChildCompletionAttestationV1 bytes"
    Assert-ContractCondition ([string]$evidence.diagnostic_parent_attestation_sha256 -ceq (Get-FileHash $validFixture.diagnostic_parent_path -Algorithm SHA256).Hash.ToLowerInvariant()) "admission evidence binds exact ParentExitAttestationV2 bytes"
    Assert-ContractCondition ([string]$evidence.diagnostic_stdout_sha256 -ceq (Get-FileHash $validFixture.diagnostic_stdout_path -Algorithm SHA256).Hash.ToLowerInvariant() -and [string]$evidence.diagnostic_stderr_sha256 -ceq (Get-FileHash $validFixture.diagnostic_stderr_path -Algorithm SHA256).Hash.ToLowerInvariant()) "admission evidence binds exact stdout and stderr bytes"

    $admission = Invoke-TestAdmission $validFixture
    Write-Verbose "valid admission created"
    Assert-ContractCondition ([IO.File]::Exists($validFixture.admission_path)) "admission ledger is atomically published"
    Assert-ContractCondition ([string]$admission.fingerprint -match '^[0-9a-f]{64}$') "admission ledger exposes its raw-file fingerprint"
    Assert-ContractCondition ([string]$admission.value.run_id -ceq $validFixture.run_id -and [string]$admission.value.repository_head -ceq $head) "admission binds run ID and HEAD"
    Assert-ContractCondition ([string]$admission.value.scenario_fingerprint -ceq $scenarioFingerprint -and [string]$admission.value.timeout_policy_fingerprint -ceq (Get-FileHash $validFixture.policy_path -Algorithm SHA256).Hash.ToLowerInvariant()) "admission binds scenario and timeout-policy fingerprints"
    Assert-ContractCondition ([bool]$admission.value.rehearsal_only -and [bool]$admission.value.nonofficial -and -not [bool]$admission.value.official -and -not [bool]$admission.value.formal) "admission is rehearsal-only and nonofficial"
    Assert-ContractCondition (-not [bool]$admission.value.official_authorization_consumed -and [int]$admission.value.rehearsal_count_after -eq 1) "admission consumes only the one rehearsal quota"
    Assert-ContractCondition ([bool]$admission.value.official_attempt_1_claim_immutable -and [bool]$admission.value.official_attempt_2_claim_absent) "admission binds immutable Attempt 1 and absent Attempt 2"
    Assert-ContractCondition ([string]$admission.value.admission_evidence_sha256 -ceq (Get-FileHash $validFixture.evidence_path -Algorithm SHA256).Hash.ToLowerInvariant()) "admission binds exact diagnostic bytes"
    Assert-ContractCondition ([string]$admission.value.diagnostic_quota_ledger_sha256 -ceq [string]$evidence.diagnostic_quota_ledger_sha256 -and [string]$admission.value.diagnostic_child_attestation_sha256 -ceq [string]$evidence.diagnostic_child_attestation_sha256) "admission ledger closes quota and Child raw-SHA bindings"
    Assert-ContractCondition ([string]$admission.value.diagnostic_launch_attestation_sha256 -ceq [string]$evidence.diagnostic_launch_attestation_sha256 -and [string]$admission.value.diagnostic_manifest_sha256 -ceq [string]$evidence.diagnostic_manifest_sha256) "admission ledger closes diagnostic launch and manifest raw-SHA bindings"
    Assert-ContractCondition ([int]$admission.value.diagnostic_engine_process_id -eq [int]$validDiagnosticLaunch.engine_process_id -and [string]$admission.value.diagnostic_engine_creation_time_utc_ticks -ceq [string]$validDiagnosticLaunch.engine_creation_time_utc_ticks) "admission ledger retains the diagnostic engine PID identity summary"
    Assert-ContractCondition ([string]$admission.value.diagnostic_parent_attestation_sha256 -ceq [string]$evidence.diagnostic_parent_attestation_sha256 -and [string]$admission.value.diagnostic_child_attestation_fingerprint -ceq [string]$evidence.diagnostic_child_attestation_fingerprint) "admission ledger closes Parent raw SHA and Child semantic fingerprint"
    Assert-ContractCondition ([string]$admission.value.diagnostic_stdout_sha256 -ceq [string]$evidence.diagnostic_stdout_sha256 -and [string]$admission.value.diagnostic_stderr_sha256 -ceq [string]$evidence.diagnostic_stderr_sha256) "admission ledger closes stdout and stderr raw-SHA bindings"
    Assert-ContractCondition ([string]$admission.value.claim_nonce -ne [string]$admission.value.launch_nonce) "claim and launch nonces are independent"
    Assert-ContractCondition (@(Get-ChildItem (Split-Path -Parent $validFixture.admission_path) -Filter '*.tmp.*' -Force).Count -eq 0) "atomic admission leaves no temporary sidecar"
    Assert-ContractCondition ([bool](Assert-TestAdmissionSourcesUnchanged $validFixture $admission)) "post-commit validator accepts the unchanged diagnostic, policy, and official boundary"

    $postCommitSourceFixture = New-TestFixture "post-commit-source-change"
    $postCommitSourceAdmission = Invoke-TestAdmission $postCommitSourceFixture
    [IO.File]::AppendAllText($postCommitSourceFixture.diagnostic_stdout_path, "changed-after-commit" + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    Assert-ContractThrows { $null = Assert-TestAdmissionSourcesUnchanged $postCommitSourceFixture $postCommitSourceAdmission } "process_a_rehearsal_admission_source_changed_after_commit" "post-commit diagnostic byte changes fail after the caller owns the admission"
    Assert-ContractCondition ([string](Read-ProcessARehearsalAdmissionLedger $postCommitSourceFixture.admission_path $postCommitSourceAdmission.fingerprint).value.run_id -ceq $postCommitSourceFixture.run_id) "post-commit source failure leaves one complete immutable admission ledger"

    $postCommitOfficialFixture = New-TestFixture "post-commit-official-change"
    $postCommitOfficialAdmission = Invoke-TestAdmission $postCommitOfficialFixture
    $postCommitAttempt2Directory = Join-Path $postCommitOfficialFixture.official_root "official-alpha04c-attempt-2"
    [IO.Directory]::CreateDirectory($postCommitAttempt2Directory) | Out-Null
    [IO.File]::WriteAllText((Join-Path $postCommitAttempt2Directory "official_claim_ledger.json"), "{}", [Text.UTF8Encoding]::new($false))
    Assert-ContractThrows { $null = Assert-TestAdmissionSourcesUnchanged $postCommitOfficialFixture $postCommitOfficialAdmission } "process_a_rehearsal_official_attempt_2_claim_must_be_absent" "post-commit official inventory changes fail after the caller owns the admission"

    $readAdmission = Read-ProcessARehearsalAdmissionLedger $validFixture.admission_path $admission.fingerprint
    Assert-ContractCondition ([string]$readAdmission.value.ledger_fingerprint -ceq [string]$admission.value.ledger_fingerprint) "admission readback validates its semantic fingerprint"
    $forgedAdmission = $admission.value | ConvertTo-Json -Depth 20 | ConvertFrom-Json -DateKind String
    $forgedAdmission.challenge_depth = 2
    $forgedAdmission.ledger_fingerprint = Get-TestFingerprint $forgedAdmission "ledger_fingerprint"
    $forgedAdmissionPath = Join-Path $validFixture.root "ledger\forged_admission.json"
    Write-TestJson $forgedAdmissionPath $forgedAdmission
    Assert-ContractThrows { $null = Read-ProcessARehearsalAdmissionLedger $forgedAdmissionPath } "process_a_rehearsal_admission_ledger_invalid" "recomputed self-fingerprint cannot legalize a changed fixed scenario"
    $authorization = Get-ProcessARehearsalLaunchAuthorization $validFixture.admission_path $admission.fingerprint
    Assert-ContractCondition ([string]$authorization.claim_fingerprint -ceq [string]$admission.fingerprint) "Wrapper authorization binds the immutable admission file"
    Assert-ContractCondition ([string]$authorization.launch_nonce -ceq [string]$admission.value.launch_nonce -and [int]$authorization.orchestrator_process_id -eq $PID) "Wrapper authorization binds launcher PID and nonce"
    Assert-ContractCondition (@($authorization.PSObject.Properties.Name).Count -eq 10) "Wrapper authorization preserves the existing exact ten-field API"

    Write-Verbose "checking admission reuse"
    Assert-ContractThrows { $null = Invoke-TestAdmission $validFixture } "process_a_rehearsal_admission_already_consumed" "same admission cannot consume quota twice"
    Write-Verbose "admission reuse rejected"

    Write-TestJson $validFixture.launch_attestation_path (New-TestLaunchAttestation $authorization)
    $launch = Complete-TestLaunch $validFixture $admission
    Assert-ContractCondition ([IO.File]::Exists($validFixture.launch_path)) "launch identity ledger is atomically published"
    Assert-ContractCondition ([string]$launch.value.admission_ledger_sha256 -ceq [string]$admission.fingerprint) "launch ledger binds the exact admission ledger"
    Assert-ContractCondition ([string]$launch.value.timeout_policy_fingerprint -ceq [string]$admission.value.timeout_policy_fingerprint) "launch ledger carries the timeout-policy binding"
    Assert-ContractCondition ([int]$launch.value.wrapper_process_id -eq 42001 -and [int]$launch.value.engine_process_id -eq 42002) "launch ledger binds wrapper and engine PIDs"
    Assert-ContractCondition ([string]$launch.value.claim_nonce -ceq [string]$admission.value.claim_nonce -and [string]$launch.value.launch_nonce -ceq [string]$admission.value.launch_nonce) "launch ledger binds both nonces"
    Assert-ContractCondition (@(Get-ChildItem (Split-Path -Parent $validFixture.launch_path) -Filter '*.tmp.*' -Force).Count -eq 0) "atomic launch binding leaves no temporary sidecar"
    $readLaunch = Read-ProcessARehearsalLaunchLedger $validFixture.launch_path $launch.fingerprint
    Assert-ContractCondition ([string]$readLaunch.value.status -ceq "launch_identity_bound") "launch readback validates the final state"
    Assert-ContractCondition ([string]$readLaunch.value.claim_fingerprint -ceq [string]$readLaunch.value.admission_ledger_sha256) "launch ledger preserves claim-fingerprint equivalence"
    $forgedLaunch = $launch.value | ConvertTo-Json -Depth 20 | ConvertFrom-Json -DateKind String
    $forgedLaunch.engine_parent_process_id = 99999
    $forgedLaunch.ledger_fingerprint = Get-TestFingerprint $forgedLaunch "ledger_fingerprint"
    $forgedLaunchPath = Join-Path $validFixture.root "ledger\forged_launch.json"
    Write-TestJson $forgedLaunchPath $forgedLaunch
    Assert-ContractThrows { $null = Read-ProcessARehearsalLaunchLedger $forgedLaunchPath } "process_a_rehearsal_launch_ledger_invalid" "recomputed self-fingerprint cannot legalize an unowned engine PID"
    Assert-ContractThrows { $null = Complete-TestLaunch $validFixture $admission } "process_a_rehearsal_launch_already_bound" "same launch identity cannot bind twice"

    $collisionFixture = New-TestFixture "collision"
    $collisionAdmission = Invoke-TestAdmission $collisionFixture
    $collisionFixture.run_id = "$([string]$rehearsalAuthorization.run_id_prefix)-collision-second"
    Assert-ContractThrows { $null = Invoke-TestAdmission $collisionFixture } "process_a_rehearsal_admission_ledger_collision" "different run identity cannot collide with a consumed admission"
    Assert-ContractCondition ([string](Read-ProcessARehearsalAdmissionLedger $collisionFixture.admission_path $collisionAdmission.fingerprint).value.timeout_policy_fingerprint -ceq [string]$collisionAdmission.value.timeout_policy_fingerprint) "collision leaves the first admission immutable"

    $unsafeFixture = New-TestFixture "unsafe" 180 $false
    Assert-ContractThrows { $null = Invoke-TestAdmission $unsafeFixture } "process_a_rehearsal_admission_evidence_not_green" "unsafe diagnostic cannot admit rehearsal"
    Assert-ContractCondition (-not [IO.File]::Exists($unsafeFixture.admission_path)) "rejected evidence does not consume quota"

    $quotaTamperFixture = New-TestFixture "tampered-quota"
    $tamperedQuota = Read-TestJson $quotaTamperFixture.diagnostic_quota_path
    $tamperedQuota.diagnostic_count_after = 2
    Write-TestJson $quotaTamperFixture.diagnostic_quota_path $tamperedQuota
    Assert-ContractThrows { $null = Invoke-TestAdmission $quotaTamperFixture } "process_a_rehearsal_diagnostic_quota_invalid" "tampered diagnostic quota ledger cannot admit rehearsal"
    Assert-ContractCondition (-not [IO.File]::Exists($quotaTamperFixture.admission_path)) "quota tampering does not create an admission ledger"

    foreach ($launchMismatch in @(
        [pscustomobject]@{ name = "authorization"; field = "authorization_id"; value = "alpha04c-wrong-authorization" },
        [pscustomobject]@{ name = "claim"; field = "claim_fingerprint"; value = ("b" * 64) },
        [pscustomobject]@{ name = "nonce"; field = "launch_nonce"; value = ("c" * 32) },
        [pscustomobject]@{ name = "run"; field = "run_id"; value = "$([string]$targetedAuthorization.run_id_prefix)-wrong" },
        [pscustomobject]@{ name = "head"; field = "source_head_sha"; value = "fedcba9876543210fedcba9876543210fedcba98" },
        [pscustomobject]@{ name = "scenario"; field = "scenario_fingerprint"; value = ("d" * 64) }
    )) {
        $launchMismatchFixture = New-TestFixture "diagnostic-launch-$($launchMismatch.name)-mismatch"
        $tamperedDiagnosticLaunch = Read-TestJson $launchMismatchFixture.diagnostic_launch_attestation_path
        $tamperedDiagnosticLaunch.($launchMismatch.field) = $launchMismatch.value
        Write-TestJson $launchMismatchFixture.diagnostic_launch_attestation_path $tamperedDiagnosticLaunch
        Assert-ContractThrows { $null = Invoke-TestAdmission $launchMismatchFixture } "process_a_rehearsal_launch_attestation_authorization_mismatch" "diagnostic launch $($launchMismatch.name) mismatch cannot admit rehearsal"
    }

    $diagnosticLaunchRelationFixture = New-TestFixture "diagnostic-launch-wrapper-relation"
    $diagnosticLaunchRelation = Read-TestJson $diagnosticLaunchRelationFixture.diagnostic_launch_attestation_path
    $diagnosticLaunchRelation.wrapper_parent_process_id = 99999
    Write-TestJson $diagnosticLaunchRelationFixture.diagnostic_launch_attestation_path $diagnosticLaunchRelation
    Assert-ContractThrows { $null = Invoke-TestAdmission $diagnosticLaunchRelationFixture } "process_a_rehearsal_launch_process_identity_invalid" "diagnostic Wrapper PID relation must match its quota-authorized orchestrator"

    $diagnosticLaunchTicksFixture = New-TestFixture "diagnostic-launch-creation-ticks"
    $diagnosticLaunchTicks = Read-TestJson $diagnosticLaunchTicksFixture.diagnostic_launch_attestation_path
    $diagnosticLaunchTicks.engine_creation_time_utc_ticks = "not-ticks"
    Write-TestJson $diagnosticLaunchTicksFixture.diagnostic_launch_attestation_path $diagnosticLaunchTicks
    Assert-ContractThrows { $null = Invoke-TestAdmission $diagnosticLaunchTicksFixture } "process_a_rehearsal_launch_process_identity_invalid" "diagnostic engine creation ticks must remain strict"

    $diagnosticLaunchTypeFixture = New-TestFixture "diagnostic-launch-string-type"
    $diagnosticLaunchType = Read-TestJson $diagnosticLaunchTypeFixture.diagnostic_launch_attestation_path
    $diagnosticLaunchType.authorization_id = @([string]$targetedAuthorization.authorization_id)
    Write-TestJson $diagnosticLaunchTypeFixture.diagnostic_launch_attestation_path $diagnosticLaunchType
    Assert-ContractThrows { $null = Invoke-TestAdmission $diagnosticLaunchTypeFixture } "process_a_rehearsal_launch_attestation_authorization_mismatch" "diagnostic launch identity fields require real strings"

    $diagnosticEnginePidFixture = New-TestFixture "diagnostic-engine-pid-mismatch"
    $diagnosticEnginePidLaunch = Read-TestJson $diagnosticEnginePidFixture.diagnostic_launch_attestation_path
    $diagnosticEnginePidLaunch.engine_process_id = 41003
    Write-TestJson $diagnosticEnginePidFixture.diagnostic_launch_attestation_path $diagnosticEnginePidLaunch
    Assert-ContractThrows { $null = Invoke-TestAdmission $diagnosticEnginePidFixture } "process_a_rehearsal_diagnostic_manifest_identity_invalid" "atomic manifest process ID must equal the authorized diagnostic engine PID"

    $diagnosticManifestPidFixture = New-TestFixture "diagnostic-manifest-pid-mismatch"
    $diagnosticManifestPid = Read-TestJson $diagnosticManifestPidFixture.diagnostic_manifest_path
    $diagnosticManifestPid.process_id = 49999
    Write-TestJson $diagnosticManifestPidFixture.diagnostic_manifest_path $diagnosticManifestPid
    Assert-ContractThrows { $null = Invoke-TestAdmission $diagnosticManifestPidFixture } "process_a_rehearsal_diagnostic_manifest_identity_invalid" "wrong atomic manifest PID cannot admit rehearsal"

    foreach ($manifestMismatch in @(
        [pscustomobject]@{ name = "run"; field = "run_id"; value = "$([string]$targetedAuthorization.run_id_prefix)-wrong" },
        [pscustomobject]@{ name = "head"; field = "head_sha"; value = "fedcba9876543210fedcba9876543210fedcba98" },
        [pscustomobject]@{ name = "scenario"; field = "scenario_fingerprint"; value = ("b" * 64) },
        [pscustomobject]@{ name = "role"; field = "process_role"; value = "consumer" }
    )) {
        $manifestMismatchFixture = New-TestFixture "diagnostic-manifest-$($manifestMismatch.name)-mismatch"
        $tamperedManifest = Read-TestJson $manifestMismatchFixture.diagnostic_manifest_path
        $tamperedManifest.($manifestMismatch.field) = $manifestMismatch.value
        Write-TestJson $manifestMismatchFixture.diagnostic_manifest_path $tamperedManifest
        Assert-ContractThrows { $null = Invoke-TestAdmission $manifestMismatchFixture } "process_a_rehearsal_diagnostic_manifest_identity_invalid" "diagnostic manifest $($manifestMismatch.name) mismatch cannot admit rehearsal"
    }

    $diagnosticManifestSuccessFixture = New-TestFixture "diagnostic-manifest-success"
    $diagnosticManifestSuccess = Read-TestJson $diagnosticManifestSuccessFixture.diagnostic_manifest_path
    $diagnosticManifestSuccess.success = $true
    Write-TestJson $diagnosticManifestSuccessFixture.diagnostic_manifest_path $diagnosticManifestSuccess
    Assert-ContractThrows { $null = Invoke-TestAdmission $diagnosticManifestSuccessFixture } "process_a_rehearsal_diagnostic_manifest_failure_binding_invalid" "targeted diagnostic manifest cannot claim production success"

    $diagnosticManifestRestoreClaimFixture = New-TestFixture "diagnostic-manifest-restore-claim"
    $diagnosticManifestRestoreClaim = Read-TestJson $diagnosticManifestRestoreClaimFixture.diagnostic_manifest_path
    $diagnosticManifestRestoreClaim.world_fingerprint_match = $true
    Write-TestJson $diagnosticManifestRestoreClaimFixture.diagnostic_manifest_path $diagnosticManifestRestoreClaim
    Assert-ContractThrows { $null = Invoke-TestAdmission $diagnosticManifestRestoreClaimFixture } "process_a_rehearsal_diagnostic_manifest_role_evidence_non_neutral" "producer diagnostic cannot claim restore-only fingerprint evidence"

    $diagnosticManifestGenerationTwoClaimFixture = New-TestFixture "diagnostic-manifest-generation-two-claim"
    $diagnosticManifestGenerationTwoClaim = Read-TestJson $diagnosticManifestGenerationTwoClaimFixture.diagnostic_manifest_path
    $diagnosticManifestGenerationTwoClaim.generation_2_duplicate_transaction_count = 1
    Write-TestJson $diagnosticManifestGenerationTwoClaimFixture.diagnostic_manifest_path $diagnosticManifestGenerationTwoClaim
    Assert-ContractThrows { $null = Invoke-TestAdmission $diagnosticManifestGenerationTwoClaimFixture } "process_a_rehearsal_diagnostic_manifest_role_evidence_non_neutral" "producer diagnostic cannot claim Generation 2 transaction evidence"

    $diagnosticManifestReasonFixture = New-TestFixture "diagnostic-manifest-reason"
    $diagnosticManifestReason = Read-TestJson $diagnosticManifestReasonFixture.diagnostic_manifest_path
    $diagnosticManifestReason.failure_code = "targeted_owner_capture_diagnostic_complete"
    Write-TestJson $diagnosticManifestReasonFixture.diagnostic_manifest_path $diagnosticManifestReason
    Assert-ContractThrows { $null = Invoke-TestAdmission $diagnosticManifestReasonFixture } "process_a_rehearsal_diagnostic_manifest_failure_binding_invalid" "manifest failure code must close the 19-owner successful diagnostic result"

    $diagnosticParentPidFixture = New-TestFixture "diagnostic-parent-engine-pid-mismatch"
    $diagnosticParentPid = Read-TestJson $diagnosticParentPidFixture.diagnostic_parent_path
    $diagnosticParentPid.child_pid = 49999
    Write-TestJson $diagnosticParentPidFixture.diagnostic_parent_path $diagnosticParentPid
    Assert-ContractThrows { $null = Invoke-TestAdmission $diagnosticParentPidFixture } "process_a_rehearsal_diagnostic_parent_attestation_invalid" "Parent child PID must equal the authorized diagnostic engine PID"

    $childTamperFixture = New-TestFixture "tampered-child"
    $tamperedChild = Read-TestJson $childTamperFixture.diagnostic_child_path
    $tamperedChild.queue_revision = [int]$tamperedChild.queue_revision + 1
    $tamperedChild.evidence_fingerprint = Get-TestFingerprint $tamperedChild "evidence_fingerprint"
    Write-TestJson $childTamperFixture.diagnostic_child_path $tamperedChild
    Assert-ContractThrows { $null = Invoke-TestAdmission $childTamperFixture } "process_a_rehearsal_diagnostic_parent_attestation_invalid" "re-fingerprinted Child tampering breaks the Parent Child-fingerprint closure"
    Assert-ContractCondition (-not [IO.File]::Exists($childTamperFixture.admission_path)) "Child tampering does not create an admission ledger"

    $parentTamperFixture = New-TestFixture "tampered-parent"
    $tamperedParent = Read-TestJson $parentTamperFixture.diagnostic_parent_path
    $tamperedParent.child_attestation_fingerprint = "b" * 64
    Write-TestJson $parentTamperFixture.diagnostic_parent_path $tamperedParent
    Assert-ContractThrows { $null = Invoke-TestAdmission $parentTamperFixture } "process_a_rehearsal_diagnostic_parent_attestation_invalid" "tampered Parent Child-fingerprint binding cannot admit rehearsal"
    Assert-ContractCondition (-not [IO.File]::Exists($parentTamperFixture.admission_path)) "Parent tampering does not create an admission ledger"

    $stdoutTamperFixture = New-TestFixture "tampered-stdout"
    [IO.File]::AppendAllText($stdoutTamperFixture.diagnostic_stdout_path, "tampered`n", [Text.UTF8Encoding]::new($false))
    Assert-ContractThrows { $null = Invoke-TestAdmission $stdoutTamperFixture } "process_a_rehearsal_diagnostic_parent_attestation_invalid" "stdout byte tampering breaks the Parent stream-SHA closure"
    Assert-ContractCondition (-not [IO.File]::Exists($stdoutTamperFixture.admission_path)) "stdout tampering does not create an admission ledger"

    $privacyStringFixture = New-TestFixture -Name "privacy-string-false" -FirstPrivatePayloadRedacted "false"
    Assert-ContractThrows { $null = Invoke-TestAdmission $privacyStringFixture } "process_a_rehearsal_admission_owner_row_invalid" "string false cannot impersonate the private-payload-redacted Boolean"
    Assert-ContractCondition (-not [IO.File]::Exists($privacyStringFixture.admission_path)) "privacy type confusion does not create an admission ledger"

    $wrongHeadFixture = New-TestFixture "wrong-head"
    Assert-ContractThrows {
        $null = New-ProcessARehearsalAdmission -LedgerPath $wrongHeadFixture.admission_path -RunId $wrongHeadFixture.run_id -RepositoryHead "fedcba9876543210fedcba9876543210fedcba98" -ScenarioFingerprint $scenarioFingerprint -PrerequisiteEvidenceFingerprint $prerequisiteFingerprint -TimeoutPolicyPath $wrongHeadFixture.policy_path -AdmissionEvidencePath $wrongHeadFixture.evidence_path -DiagnosticQuotaLedgerPath $wrongHeadFixture.diagnostic_quota_path -DiagnosticLaunchAttestationPath $wrongHeadFixture.diagnostic_launch_attestation_path -DiagnosticManifestPath $wrongHeadFixture.diagnostic_manifest_path -DiagnosticChildAttestationPath $wrongHeadFixture.diagnostic_child_path -DiagnosticParentAttestationPath $wrongHeadFixture.diagnostic_parent_path -DiagnosticStdoutPath $wrongHeadFixture.diagnostic_stdout_path -DiagnosticStderrPath $wrongHeadFixture.diagnostic_stderr_path -OfficialClaimRoot $wrongHeadFixture.official_root -OfficialAttempt1ClaimPath $wrongHeadFixture.attempt_1_path
    } "process_a_rehearsal_admission_evidence_head_mismatch" "diagnostic HEAD mismatch fails closed"

    $wrongScenarioFixture = New-TestFixture "wrong-scenario"
    Assert-ContractThrows {
        $null = New-ProcessARehearsalAdmission -LedgerPath $wrongScenarioFixture.admission_path -RunId $wrongScenarioFixture.run_id -RepositoryHead $head -ScenarioFingerprint ("b" * 64) -PrerequisiteEvidenceFingerprint $prerequisiteFingerprint -TimeoutPolicyPath $wrongScenarioFixture.policy_path -AdmissionEvidencePath $wrongScenarioFixture.evidence_path -DiagnosticQuotaLedgerPath $wrongScenarioFixture.diagnostic_quota_path -DiagnosticLaunchAttestationPath $wrongScenarioFixture.diagnostic_launch_attestation_path -DiagnosticManifestPath $wrongScenarioFixture.diagnostic_manifest_path -DiagnosticChildAttestationPath $wrongScenarioFixture.diagnostic_child_path -DiagnosticParentAttestationPath $wrongScenarioFixture.diagnostic_parent_path -DiagnosticStdoutPath $wrongScenarioFixture.diagnostic_stdout_path -DiagnosticStderrPath $wrongScenarioFixture.diagnostic_stderr_path -OfficialClaimRoot $wrongScenarioFixture.official_root -OfficialAttempt1ClaimPath $wrongScenarioFixture.attempt_1_path
    } "process_a_rehearsal_admission_identity_binding_invalid" "scenario collision fails closed"

    $policyFixture = New-TestFixture "bad-policy" 181
    Assert-ContractThrows { $null = Invoke-TestAdmission $policyFixture } "role_timeout_policy_entry_bound_invalid" "over-cap Process A policy cannot admit rehearsal"

    $policyExtraFieldFixture = New-TestFixture "policy-extra-field"
    $policyExtraField = Read-TestJson $policyExtraFieldFixture.policy_path
    $policyExtraField | Add-Member -NotePropertyName unexpected_timeout_override -NotePropertyValue 9
    Write-TestJson $policyExtraFieldFixture.policy_path $policyExtraField
    Assert-ContractThrows { $null = Invoke-TestAdmission $policyExtraFieldFixture } "role_timeout_policy_field_set_invalid" "policy extra fields fail the complete Wrapper validator"

    $policyMissingRoleFixture = New-TestFixture "policy-missing-role"
    $policyMissingRole = Read-TestJson $policyMissingRoleFixture.policy_path
    $policyMissingRole.roles.PSObject.Properties.Remove("process_c")
    Write-TestJson $policyMissingRoleFixture.policy_path $policyMissingRole
    Assert-ContractThrows { $null = Invoke-TestAdmission $policyMissingRoleFixture } "role_timeout_policy_role_set_invalid" "missing any of the four policy roles fails closed"

    $policyHeartbeatFixture = New-TestFixture "policy-wrong-heartbeat"
    $policyHeartbeat = Read-TestJson $policyHeartbeatFixture.policy_path
    $policyHeartbeat.progress_heartbeat_fields[0] = "wrong_phase"
    Write-TestJson $policyHeartbeatFixture.policy_path $policyHeartbeat
    Assert-ContractThrows { $null = Invoke-TestAdmission $policyHeartbeatFixture } "role_timeout_policy_heartbeat_fields_invalid" "heartbeat field drift fails the complete Wrapper validator"

    $policyProcessBFixture = New-TestFixture "policy-process-b-over-cap"
    $policyProcessB = Read-TestJson $policyProcessBFixture.policy_path
    $policyProcessB.roles.process_b.absolute_timeout_seconds = 361
    Write-TestJson $policyProcessBFixture.policy_path $policyProcessB
    Assert-ContractThrows { $null = Invoke-TestAdmission $policyProcessBFixture } "role_timeout_policy_entry_bound_invalid" "an over-cap Process B policy cannot hide behind a valid Process A entry"

    $policyRawShaFixture = New-TestFixture "policy-raw-sha-mismatch"
    [IO.File]::AppendAllText($policyRawShaFixture.policy_path, " ", [Text.UTF8Encoding]::new($false))
    Assert-ContractThrows { $null = Invoke-TestAdmission $policyRawShaFixture } "process_a_rehearsal_diagnostic_quota_invalid" "raw policy byte changes break the diagnostic quota SHA binding"

    $mutatedClaimFixture = New-TestFixture "mutated-claim"
    [IO.File]::AppendAllText($mutatedClaimFixture.attempt_1_path, " ", [Text.UTF8Encoding]::new($false))
    Assert-ContractThrows { $null = Invoke-TestAdmission $mutatedClaimFixture } "process_a_rehearsal_official_attempt_1_claim_mutated" "Attempt 1 byte mutation fails closed"

    $attempt2Fixture = New-TestFixture "attempt-2"
    $attempt2Directory = Join-Path $attempt2Fixture.official_root "official-alpha04c-attempt-2"
    [IO.Directory]::CreateDirectory($attempt2Directory) | Out-Null
    [IO.File]::WriteAllText((Join-Path $attempt2Directory "official_claim_ledger.json"), "{}", [Text.UTF8Encoding]::new($false))
    Assert-ContractThrows { $null = Invoke-TestAdmission $attempt2Fixture } "process_a_rehearsal_official_attempt_2_claim_must_be_absent" "Attempt 2 presence forbids rehearsal admission"

    $nonceFixture = New-TestFixture "wrong-nonce"
    $nonceAdmission = Invoke-TestAdmission $nonceFixture
    $nonceAuthorization = $nonceAdmission.launch_authorization
    $nonceAttestation = New-TestLaunchAttestation $nonceAuthorization
    $nonceAttestation.launch_nonce = "f" * 32
    Write-TestJson $nonceFixture.launch_attestation_path $nonceAttestation
    Assert-ContractThrows { $null = Complete-TestLaunch $nonceFixture $nonceAdmission } "process_a_rehearsal_launch_attestation_authorization_mismatch" "launch nonce mismatch cannot bind"

    $pidFixture = New-TestFixture "wrong-pid"
    $pidAdmission = Invoke-TestAdmission $pidFixture
    $pidAttestation = New-TestLaunchAttestation $pidAdmission.launch_authorization
    $pidAttestation.engine_parent_process_id = 99999
    Write-TestJson $pidFixture.launch_attestation_path $pidAttestation
    Assert-ContractThrows { $null = Complete-TestLaunch $pidFixture $pidAdmission } "process_a_rehearsal_launch_process_identity_invalid" "unowned engine PID relation cannot bind"

    $tamperFixture = New-TestFixture "tamper"
    $tamperAdmission = Invoke-TestAdmission $tamperFixture
    [IO.File]::AppendAllText($tamperFixture.admission_path, " ", [Text.UTF8Encoding]::new($false))
    Assert-ContractThrows { $null = Read-ProcessARehearsalAdmissionLedger $tamperFixture.admission_path $tamperAdmission.fingerprint } "process_a_rehearsal_admission_ledger_sha256_mismatch" "admission byte mutation invalidates expected SHA"

    $launchSourceTamperFixture = New-TestFixture "launch-source-tamper"
    $launchSourceTamperAdmission = Invoke-TestAdmission $launchSourceTamperFixture
    Write-TestJson $launchSourceTamperFixture.launch_attestation_path (New-TestLaunchAttestation $launchSourceTamperAdmission.launch_authorization)
    [IO.File]::AppendAllText($launchSourceTamperFixture.diagnostic_stdout_path, "changed-after-admission`n", [Text.UTF8Encoding]::new($false))
    Assert-ContractThrows { $null = Complete-TestLaunch $launchSourceTamperFixture $launchSourceTamperAdmission } "process_a_rehearsal_launch_bound_source_changed" "Complete rejects diagnostic-chain byte changes after admission"
    Assert-ContractCondition (-not [IO.File]::Exists($launchSourceTamperFixture.launch_path)) "rejected launch-chain tampering does not create a launch ledger"

    $diagnosticLaunchRawTamperFixture = New-TestFixture "diagnostic-launch-raw-tamper-after-admission"
    $diagnosticLaunchRawTamperAdmission = Invoke-TestAdmission $diagnosticLaunchRawTamperFixture
    Write-TestJson $diagnosticLaunchRawTamperFixture.launch_attestation_path (New-TestLaunchAttestation $diagnosticLaunchRawTamperAdmission.launch_authorization)
    [IO.File]::AppendAllText($diagnosticLaunchRawTamperFixture.diagnostic_launch_attestation_path, " ", [Text.UTF8Encoding]::new($false))
    Assert-ContractThrows { $null = Complete-TestLaunch $diagnosticLaunchRawTamperFixture $diagnosticLaunchRawTamperAdmission } "process_a_rehearsal_launch_bound_source_changed" "Complete rehashes the bound diagnostic launch attestation"
    Assert-ContractCondition (-not [IO.File]::Exists($diagnosticLaunchRawTamperFixture.launch_path)) "diagnostic launch byte tampering cannot publish the rehearsal launch ledger"

    $diagnosticManifestRawTamperFixture = New-TestFixture "diagnostic-manifest-raw-tamper-after-admission"
    $diagnosticManifestRawTamperAdmission = Invoke-TestAdmission $diagnosticManifestRawTamperFixture
    Write-TestJson $diagnosticManifestRawTamperFixture.launch_attestation_path (New-TestLaunchAttestation $diagnosticManifestRawTamperAdmission.launch_authorization)
    [IO.File]::AppendAllText($diagnosticManifestRawTamperFixture.diagnostic_manifest_path, " ", [Text.UTF8Encoding]::new($false))
    Assert-ContractThrows { $null = Complete-TestLaunch $diagnosticManifestRawTamperFixture $diagnosticManifestRawTamperAdmission } "process_a_rehearsal_launch_bound_source_changed" "Complete rehashes the bound atomic diagnostic manifest"
    Assert-ContractCondition (-not [IO.File]::Exists($diagnosticManifestRawTamperFixture.launch_path)) "diagnostic manifest byte tampering cannot publish the rehearsal launch ledger"

    $truncatedFixture = New-TestFixture "truncated"
    [IO.Directory]::CreateDirectory((Split-Path -Parent $truncatedFixture.admission_path)) | Out-Null
    [IO.File]::WriteAllText($truncatedFixture.admission_path, '{"schema_version":2', [Text.UTF8Encoding]::new($false))
    Assert-ContractThrows { $null = Read-ProcessARehearsalAdmissionLedger $truncatedFixture.admission_path } "process_a_rehearsal_artifact_json_invalid" "truncated ledger is rejected"

    $launchCollisionFixture = New-TestFixture "launch-collision-a"
    $launchCollisionAdmission = Invoke-TestAdmission $launchCollisionFixture
    Write-TestJson $launchCollisionFixture.launch_attestation_path (New-TestLaunchAttestation $launchCollisionAdmission.launch_authorization 43001 43002)
    $null = Complete-TestLaunch $launchCollisionFixture $launchCollisionAdmission
    $secondLaunchFixture = New-TestFixture "launch-collision-b"
    $secondLaunchAdmission = Invoke-TestAdmission $secondLaunchFixture
    Write-TestJson $secondLaunchFixture.launch_attestation_path (New-TestLaunchAttestation $secondLaunchAdmission.launch_authorization 44001 44002)
    $secondLaunchFixture.launch_path = $launchCollisionFixture.launch_path
    Assert-ContractThrows { $null = Complete-TestLaunch $secondLaunchFixture $secondLaunchAdmission } "process_a_rehearsal_launch_ledger_collision" "different admission cannot collide with an existing launch ledger"

    $raceFixture = New-TestFixture "race"
    $jobArguments = @(
        $modulePath, $raceFixture.admission_path, $raceFixture.run_id, $head,
        $scenarioFingerprint, $prerequisiteFingerprint, $raceFixture.policy_path, $raceFixture.evidence_path,
        $raceFixture.diagnostic_quota_path, $raceFixture.diagnostic_launch_attestation_path,
        $raceFixture.diagnostic_manifest_path, $raceFixture.diagnostic_child_path,
        $raceFixture.diagnostic_parent_path, $raceFixture.diagnostic_stdout_path,
        $raceFixture.diagnostic_stderr_path, $raceFixture.official_root, $raceFixture.attempt_1_path
    )
    $jobs = @(
        1..2 | ForEach-Object {
            Start-Job -ScriptBlock {
                param($ModulePath, $LedgerPath, $RunId, $Head, $Scenario, $PrerequisiteFingerprint, $PolicyPath, $EvidencePath, $QuotaPath, $DiagnosticLaunchPath, $DiagnosticManifestPath, $ChildPath, $ParentPath, $StdoutPath, $StderrPath, $OfficialRoot, $Attempt1Path)
                $ErrorActionPreference = "Stop"
                Import-Module $ModulePath -Force
                try {
                    $null = New-ProcessARehearsalAdmission -LedgerPath $LedgerPath -RunId $RunId -RepositoryHead $Head -ScenarioFingerprint $Scenario -PrerequisiteEvidenceFingerprint $PrerequisiteFingerprint -TimeoutPolicyPath $PolicyPath -AdmissionEvidencePath $EvidencePath -DiagnosticQuotaLedgerPath $QuotaPath -DiagnosticLaunchAttestationPath $DiagnosticLaunchPath -DiagnosticManifestPath $DiagnosticManifestPath -DiagnosticChildAttestationPath $ChildPath -DiagnosticParentAttestationPath $ParentPath -DiagnosticStdoutPath $StdoutPath -DiagnosticStderrPath $StderrPath -OfficialClaimRoot $OfficialRoot -OfficialAttempt1ClaimPath $Attempt1Path
                    "SUCCESS"
                }
                catch {
                    "FAIL:$($_.Exception.Message)"
                }
            } -ArgumentList $jobArguments
        }
    )
    try {
        $raceTimeoutSeconds = 30
        $null = Wait-Job -Job $jobs -Timeout $raceTimeoutSeconds
        $unfinishedJobs = @($jobs | Where-Object { $_.State -notin @("Completed", "Failed", "Stopped") })
        $raceTimedOut = $unfinishedJobs.Count -gt 0
        if ($raceTimedOut) {
            $unfinishedJobs | Stop-Job -ErrorAction SilentlyContinue
        }
        $raceResults = @($jobs | Receive-Job -ErrorAction SilentlyContinue)
        Assert-ContractCondition (-not $raceTimedOut) "concurrent admission completes within $raceTimeoutSeconds seconds"
        Assert-ContractCondition (@($raceResults | Where-Object { $_ -ceq "SUCCESS" }).Count -eq 1) "concurrent admission has exactly one winner"
        Assert-ContractCondition (@($raceResults | Where-Object { $_ -ceq "FAIL:process_a_rehearsal_admission_already_consumed" }).Count -eq 1) "concurrent admission rejects the losing reuse"
        Assert-ContractCondition ([IO.File]::Exists($raceFixture.admission_path)) "concurrent winner publishes one complete ledger"
        $null = Read-ProcessARehearsalAdmissionLedger $raceFixture.admission_path
        Assert-ContractCondition (@(Get-ChildItem (Split-Path -Parent $raceFixture.admission_path) -Filter '*.tmp.*' -Force).Count -eq 0) "concurrent race leaves no temporary sidecar"
    }
    finally {
        $runningJobs = @($jobs | Where-Object { $_.State -notin @("Completed", "Failed", "Stopped") })
        if ($runningJobs.Count -gt 0) {
            $runningJobs | Stop-Job -ErrorAction SilentlyContinue
        }
        $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
    }
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$status = if ($failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "PROCESS_A_REHEARSAL_ADMISSION_CONTRACT_TEST|status=$status|checks=$checks|failures=$($failures.Count)"
if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Output "FAIL|$failure"
    }
    exit 1
}
exit 0
