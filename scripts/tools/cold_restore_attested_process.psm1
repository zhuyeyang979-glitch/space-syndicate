Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ChildCompletionFields = @(
    "schema_version",
    "run_id",
    "role",
    "repository_head",
    "scenario_fingerprint",
    "official",
    "formal",
    "qualification_completed",
    "qualification_green",
    "product_blocker",
    "queue_count",
    "queue_revision",
    "queue_trigger_actor",
    "queue_trigger_semantic_action_id",
    "queue_trigger_card_semantic_id",
    "queue_trigger_target_fingerprint",
    "save_written",
    "official_count_consumed",
    "product_mutation_count",
    "direct_authority_mutation_count",
    "queue_injection_count",
    "final_reason_code",
    "evidence_fingerprint",
    "child_ready_to_exit"
)

$script:ParentExitFieldsV1 = @(
    "schema_version",
    "run_id",
    "role",
    "child_pid",
    "observed_exit",
    "exit_code",
    "timed_out",
    "terminated_by_parent",
    "stdout_sha256",
    "stderr_sha256",
    "child_attestation_found",
    "child_attestation_fingerprint",
    "child_attestation_valid",
    "task_owned_process_count_after",
    "unrelated_preexisting_process_count",
    "wrapper_exit_green",
    "wrapper_reason_code"
)

$script:ParentExitFieldsV2 = @(
    $script:ParentExitFieldsV1
    "policy_role",
    "timeout_policy_fingerprint",
    "absolute_timeout_seconds",
    "no_progress_timeout_seconds",
    "timeout_kind",
    "progress_heartbeat_found",
    "progress_heartbeat_valid",
    "progress_heartbeat_sequence",
    "progress_heartbeat_fingerprint",
    "progress_semantic_fingerprint",
    "progress_phase",
    "progress_last_evidence_write_time",
    "task_owned_process_identity_fingerprint"
)

$script:RoleTimeoutPolicyFields = @(
    "schema_version",
    "policy_id",
    "policy_source",
    "measurement_head",
    "measurement_run_id",
    "poll_interval_ms",
    "normal_exit_grace_seconds",
    "stream_drain_grace_seconds",
    "process_tree_cleanup_grace_seconds",
    "progress_heartbeat_fields",
    "roles"
)

$script:RoleTimeoutEntryFields = @(
    "absolute_timeout_seconds",
    "no_progress_timeout_seconds",
    "timeout_reason_code",
    "cleanup_policy",
    "contract_only_in_this_task"
)

$script:ProgressHeartbeatFields = @(
    "schema_version",
    "heartbeat_id",
    "run_id",
    "role_id",
    "repository_head",
    "policy_fingerprint",
    "heartbeat_sequence",
    "phase",
    "world_time",
    "owner_index",
    "queue_revision",
    "save_phase",
    "last_evidence_write_time",
    "semantic_progress_fingerprint",
    "evidence_fingerprint"
)

$script:RequiredProgressHeartbeatFields = @(
    "phase",
    "world_time",
    "owner_index",
    "queue_revision",
    "save_phase",
    "last_evidence_write_time"
)

$script:RoleTimeoutContracts = [ordered]@{
    targeted_owner_diagnostic = [ordered]@{
        process_role = "producer"
        maximum_absolute_timeout_seconds = 120
        maximum_no_progress_timeout_seconds = 30
        timeout_reason_code = "targeted_owner_diagnostic_timeout"
    }
    process_a = [ordered]@{
        process_role = "producer"
        maximum_absolute_timeout_seconds = 180
        maximum_no_progress_timeout_seconds = 60
        timeout_reason_code = "process_a_timeout"
    }
    process_b = [ordered]@{
        process_role = "consumer"
        maximum_absolute_timeout_seconds = 360
        maximum_no_progress_timeout_seconds = 60
        timeout_reason_code = "process_b_timeout"
    }
    process_c = [ordered]@{
        process_role = "validator"
        maximum_absolute_timeout_seconds = 180
        maximum_no_progress_timeout_seconds = 30
        timeout_reason_code = "process_c_timeout"
    }
}

$script:LaunchAuthorizationContextFields = @(
    "authorization_id",
    "claim_fingerprint",
    "claim_nonce",
    "source_head_sha",
    "scenario_fingerprint",
    "run_id",
    "process_role",
    "launch_nonce",
    "orchestrator_process_id",
    "orchestrator_creation_time_utc_ticks"
)

$script:ProcessAPhaseTimelineFields = @(
    "schema_version",
    "timeline_id",
    "run_id",
    "role",
    "repository_head",
    "scenario_fingerprint",
    "official",
    "process_start_monotonic_ms",
    "snapshot_sequence",
    "phase_rows",
    "current_phase",
    "last_completed_phase",
    "last_progress_monotonic_ms",
    "save_file_exists",
    "save_file_bytes",
    "save_file_sha256",
    "child_completion_written",
    "allowlisted_manifest_written",
    "quit_requested",
    "timeline_fingerprint"
)

$script:ProcessAPhaseRowFields = @(
    "phase_id",
    "entered_monotonic_ms",
    "completed_monotonic_ms",
    "duration_ms",
    "success",
    "reason_code",
    "evidence_fingerprint"
)

$script:ProcessAPhaseIds = @(
    "child_bootstrap",
    "scene_loaded",
    "session_started",
    "real_commodity_claim_complete",
    "real_normal_card_purchase_complete",
    "real_facility_economy_complete",
    "first_sale_receipt_complete",
    "ai_nondefault_state_complete",
    "queue_entry_committed",
    "restore_barrier_entered",
    "save_intent_submitted",
    "save_capture_complete",
    "envelope_encode_complete",
    "atomic_write_complete",
    "save_readback_complete",
    "allowlisted_manifest_complete",
    "child_completion_attestation_complete",
    "runtime_cleanup_complete",
    "quit_requested"
)

function ConvertTo-ColdRestoreCanonicalJson {
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
            "$(ConvertTo-ColdRestoreCanonicalJson $key):$(ConvertTo-ColdRestoreCanonicalJson $Value[$key])"
        }
        return "{$($members -join ',')}"
    }
    if ($Value -is [Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = foreach ($item in $Value) {
            ConvertTo-ColdRestoreCanonicalJson $item
        }
        return "[$($items -join ',')]"
    }
    $properties = @($Value.PSObject.Properties | Where-Object { $_.MemberType -in @("NoteProperty", "Property") })
    if ($properties.Count -gt 0) {
        $members = foreach ($property in @($properties | Sort-Object Name -CaseSensitive)) {
            "$(ConvertTo-ColdRestoreCanonicalJson $property.Name):$(ConvertTo-ColdRestoreCanonicalJson $property.Value)"
        }
        return "{$($members -join ',')}"
    }
    throw "canonical_json_type_invalid"
}

function Get-ColdRestoreTextSha256 {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    return ([Convert]::ToHexString($hash)).ToLowerInvariant()
}

function Get-ColdRestoreEvidenceFingerprint {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [string]$OmittedField = ""
    )

    $copy = [ordered]@{}
    if ($Value -is [Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            if ([string]$key -ne $OmittedField) {
                $copy[[string]$key] = $Value[$key]
            }
        }
    }
    else {
        foreach ($property in $Value.PSObject.Properties) {
            if ($property.Name -ne $OmittedField) {
                $copy[$property.Name] = $property.Value
            }
        }
    }
    return Get-ColdRestoreTextSha256 (ConvertTo-ColdRestoreCanonicalJson $copy)
}

function Test-ColdRestoreExactFieldSet {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string[]]$ExpectedFields
    )

    $actual = @($Value.PSObject.Properties.Name | Sort-Object -CaseSensitive)
    $expected = @($ExpectedFields | Sort-Object -CaseSensitive)
    return @(Compare-Object -ReferenceObject $expected -DifferenceObject $actual -CaseSensitive).Count -eq 0
}

function Test-ColdRestoreIntegerValue {
    param([AllowNull()]$Value)

    return $Value -is [byte] -or $Value -is [sbyte] `
        -or $Value -is [int16] -or $Value -is [uint16] `
        -or $Value -is [int32] -or $Value -is [uint32] `
        -or $Value -is [int64] -or $Value -is [uint64]
}

function Test-ColdRestoreClosedIdentifier {
    param(
        [AllowNull()]$Value,
        [int]$MaximumLength = 128
    )

    return $Value -is [string] `
        -and ([string]$Value).Length -ge 1 `
        -and ([string]$Value).Length -le $MaximumLength `
        -and [string]$Value -cmatch '^[a-z][a-z0-9_]*$'
}

function Test-ColdRestoreOrderedIdentifierList {
    param(
        [AllowNull()]$Value,
        [int]$MaximumCount = 128
    )

    if ($Value -isnot [System.Array] -or @($Value).Count -lt 1 -or @($Value).Count -gt $MaximumCount) {
        return $false
    }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($item in @($Value)) {
        if (-not (Test-ColdRestoreClosedIdentifier $item) -or -not $seen.Add([string]$item)) {
            return $false
        }
    }
    return $true
}

function Get-ColdRestoreIdentifierIndex {
    param(
        [Parameter(Mandatory = $true)][array]$Values,
        [Parameter(Mandatory = $true)][string]$Value
    )

    for ($index = 0; $index -lt $Values.Count; $index += 1) {
        if ([string]$Values[$index] -ceq $Value) {
            return $index
        }
    }
    return -1
}

function Test-ColdRestoreRoleTimeoutPolicy {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$ExpectedRepositoryHead,
        [Parameter(Mandatory = $true)][string]$ExpectedPolicyFingerprint,
        [Parameter(Mandatory = $true)][string]$PolicyRole,
        [Parameter(Mandatory = $true)][string]$ExpectedProcessRole
    )

    $invalid = {
        param([string]$Reason)
        return [pscustomobject]@{
            valid = $false
            reason_code = $Reason
            fingerprint = ""
            role_policy = $null
        }
    }
    if (-not (Test-ColdRestoreExactFieldSet $Value $script:RoleTimeoutPolicyFields)) {
        return & $invalid "role_timeout_policy_field_set_invalid"
    }
    if ([int]$Value.schema_version -ne 1 -or [string]$Value.policy_id -cne "ColdRestoreRoleTimeoutPolicyV1") {
        return & $invalid "role_timeout_policy_schema_invalid"
    }
    if ($ExpectedPolicyFingerprint -cnotmatch '^[0-9a-f]{64}$') {
        return & $invalid "role_timeout_policy_fingerprint_invalid"
    }
    if ([string]$Value.policy_source -cnotmatch '^[a-z0-9][a-z0-9._:-]{0,127}$' `
        -or [string]$Value.measurement_run_id -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$') {
        return & $invalid "role_timeout_policy_source_invalid"
    }
    if ([string]$Value.measurement_head -cnotmatch '^[0-9a-f]{40,64}$' `
        -or $ExpectedRepositoryHead -cnotmatch '^[0-9a-f]{40,64}$') {
        return & $invalid "role_timeout_policy_measurement_head_invalid"
    }
    foreach ($field in @(
        "poll_interval_ms",
        "normal_exit_grace_seconds",
        "stream_drain_grace_seconds",
        "process_tree_cleanup_grace_seconds"
    )) {
        if (-not (Test-ColdRestoreIntegerValue $Value.$field)) {
            return & $invalid "role_timeout_policy_integer_invalid"
        }
    }
    if ([int]$Value.poll_interval_ms -lt 25 -or [int]$Value.poll_interval_ms -gt 1000 `
        -or [int]$Value.normal_exit_grace_seconds -lt 1 -or [int]$Value.normal_exit_grace_seconds -gt 30 `
        -or [int]$Value.stream_drain_grace_seconds -lt 1 -or [int]$Value.stream_drain_grace_seconds -gt 30 `
        -or [int]$Value.process_tree_cleanup_grace_seconds -lt 1 -or [int]$Value.process_tree_cleanup_grace_seconds -gt 30) {
        return & $invalid "role_timeout_policy_bound_invalid"
    }
    if ($Value.progress_heartbeat_fields -isnot [System.Array]) {
        return & $invalid "role_timeout_policy_heartbeat_fields_invalid"
    }
    $heartbeatDifferences = @(
        Compare-Object `
            -ReferenceObject @($script:RequiredProgressHeartbeatFields | Sort-Object -CaseSensitive) `
            -DifferenceObject @($Value.progress_heartbeat_fields | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive) `
            -CaseSensitive
    )
    if ($heartbeatDifferences.Count -ne 0 `
        -or @($Value.progress_heartbeat_fields).Count -ne $script:RequiredProgressHeartbeatFields.Count) {
        return & $invalid "role_timeout_policy_heartbeat_fields_invalid"
    }
    if (-not (Test-ColdRestoreExactFieldSet $Value.roles @($script:RoleTimeoutContracts.Keys))) {
        return & $invalid "role_timeout_policy_role_set_invalid"
    }
    if ((Get-ColdRestoreIdentifierIndex `
        -Values @($script:RoleTimeoutContracts.Keys) `
        -Value $PolicyRole) -lt 0) {
        return & $invalid "role_timeout_policy_role_invalid"
    }
    $contract = $script:RoleTimeoutContracts[$PolicyRole]
    if ([string]$contract.process_role -cne $ExpectedProcessRole) {
        return & $invalid "role_timeout_policy_process_role_mismatch"
    }
    foreach ($roleName in @($script:RoleTimeoutContracts.Keys)) {
        $entry = $Value.roles.PSObject.Properties[[string]$roleName].Value
        if (-not (Test-ColdRestoreExactFieldSet $entry $script:RoleTimeoutEntryFields)) {
            return & $invalid "role_timeout_policy_entry_field_set_invalid"
        }
        foreach ($field in @("absolute_timeout_seconds", "no_progress_timeout_seconds")) {
            if (-not (Test-ColdRestoreIntegerValue $entry.$field)) {
                return & $invalid "role_timeout_policy_entry_integer_invalid"
            }
        }
        $entryContract = $script:RoleTimeoutContracts[[string]$roleName]
        if ([int]$entry.absolute_timeout_seconds -lt 1 `
            -or [int]$entry.absolute_timeout_seconds -gt [int]$entryContract.maximum_absolute_timeout_seconds `
            -or [int]$entry.no_progress_timeout_seconds -lt 1 `
            -or [int]$entry.no_progress_timeout_seconds -gt [int]$entryContract.maximum_no_progress_timeout_seconds `
            -or [int]$entry.no_progress_timeout_seconds -ge [int]$entry.absolute_timeout_seconds) {
            return & $invalid "role_timeout_policy_entry_bound_invalid"
        }
        if ([string]$entry.timeout_reason_code -cne [string]$entryContract.timeout_reason_code) {
            return & $invalid "role_timeout_policy_reason_code_invalid"
        }
        if ([string]$entry.cleanup_policy -cne "kill_task_tree_then_verify_pid_and_creation_time") {
            return & $invalid "role_timeout_policy_cleanup_invalid"
        }
        if ($entry.contract_only_in_this_task -isnot [bool] `
            -or [bool]$entry.contract_only_in_this_task -ne ([string]$roleName -in @("process_b", "process_c"))) {
            return & $invalid "role_timeout_policy_contract_only_invalid"
        }
    }
    return [pscustomobject]@{
        valid = $true
        reason_code = "ok"
        fingerprint = $ExpectedPolicyFingerprint
        role_policy = $Value.roles.PSObject.Properties[$PolicyRole].Value
    }
}

function Get-ColdRestoreProgressSemanticFingerprint {
    param([Parameter(Mandatory = $true)]$Value)

    $semantic = [ordered]@{
        phase = [string]$Value.phase
        world_time = [int64]$Value.world_time
        owner_index = [int64]$Value.owner_index
        queue_revision = [int64]$Value.queue_revision
        save_phase = [string]$Value.save_phase
    }
    return Get-ColdRestoreTextSha256 (ConvertTo-ColdRestoreCanonicalJson $semantic)
}

function Test-ColdRestoreProgressHeartbeat {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$ExpectedRunId,
        [Parameter(Mandatory = $true)][string]$ExpectedRoleId,
        [Parameter(Mandatory = $true)][string]$ExpectedRepositoryHead,
        [Parameter(Mandatory = $true)][string]$ExpectedPolicyFingerprint,
        $Previous = $null
    )

    $failure = {
        param([string]$Reason)
        return [pscustomobject]@{
            valid = $false
            reason_code = $Reason
            value = $Value
            semantic_fingerprint = ""
            semantic_progressed = $false
        }
    }
    if (-not (Test-ColdRestoreExactFieldSet $Value $script:ProgressHeartbeatFields)) {
        return & $failure "progress_heartbeat_field_set_invalid"
    }
    if ([int]$Value.schema_version -ne 1 -or [string]$Value.heartbeat_id -cne "ColdRestoreRoleProgressHeartbeatV1") {
        return & $failure "progress_heartbeat_schema_invalid"
    }
    if ([string]$Value.run_id -cne $ExpectedRunId) {
        return & $failure "progress_heartbeat_run_id_mismatch"
    }
    if ([string]$Value.role_id -cne $ExpectedRoleId) {
        return & $failure "progress_heartbeat_role_mismatch"
    }
    if ([string]$Value.repository_head -cne $ExpectedRepositoryHead) {
        return & $failure "progress_heartbeat_repository_head_mismatch"
    }
    if ([string]$Value.policy_fingerprint -cne $ExpectedPolicyFingerprint) {
        return & $failure "progress_heartbeat_policy_fingerprint_mismatch"
    }
    foreach ($field in @("heartbeat_sequence", "world_time", "owner_index", "queue_revision", "last_evidence_write_time")) {
        if (-not (Test-ColdRestoreIntegerValue $Value.$field)) {
            return & $failure "progress_heartbeat_integer_invalid"
        }
    }
    if ([int64]$Value.heartbeat_sequence -lt 1 -or [int64]$Value.heartbeat_sequence -gt 999999 `
        -or [int64]$Value.world_time -lt 0 `
        -or [int64]$Value.owner_index -lt -1 -or [int64]$Value.owner_index -gt 1000000 `
        -or [int64]$Value.queue_revision -lt 0 `
        -or [int64]$Value.last_evidence_write_time -lt 0) {
        return & $failure "progress_heartbeat_integer_invalid"
    }
    if (-not (Test-ColdRestoreClosedIdentifier $Value.phase 96) `
        -or -not (Test-ColdRestoreClosedIdentifier $Value.save_phase 96)) {
        return & $failure "progress_heartbeat_phase_invalid"
    }
    $fingerprint = Get-ColdRestoreEvidenceFingerprint $Value "evidence_fingerprint"
    if ([string]$Value.evidence_fingerprint -cne $fingerprint) {
        return & $failure "progress_heartbeat_fingerprint_invalid"
    }
    $semanticFingerprint = Get-ColdRestoreProgressSemanticFingerprint $Value
    if ([string]$Value.semantic_progress_fingerprint -cne $semanticFingerprint) {
        return & $failure "progress_heartbeat_semantic_fingerprint_invalid"
    }
    $semanticProgressed = $true
    if ($null -ne $Previous) {
        if ([int64]$Value.heartbeat_sequence -ne ([int64]$Previous.heartbeat_sequence + 1)) {
            return & $failure "progress_heartbeat_sequence_invalid"
        }
        if ([int64]$Value.world_time -lt [int64]$Previous.world_time `
            -or [int64]$Value.queue_revision -lt [int64]$Previous.queue_revision `
            -or ([string]$Value.phase -ceq [string]$Previous.phase `
                -and [int64]$Value.owner_index -lt [int64]$Previous.owner_index)) {
            return & $failure "progress_heartbeat_semantic_regression"
        }
        if ([int64]$Value.last_evidence_write_time -lt [int64]$Previous.last_evidence_write_time) {
            return & $failure "progress_heartbeat_write_time_regressed"
        }
        $semanticProgressed = $semanticFingerprint -cne (Get-ColdRestoreProgressSemanticFingerprint $Previous)
    }
    return [pscustomobject]@{
        valid = $true
        reason_code = "ok"
        value = $Value
        semantic_fingerprint = $semanticFingerprint
        semantic_progressed = $semanticProgressed
    }
}

function Sync-ColdRestoreProgressHeartbeat {
    param(
        [Parameter(Mandatory = $true)][string]$EventDirectory,
        [Parameter(Mandatory = $true)][string]$HeartbeatPath,
        [Parameter(Mandatory = $true)][string]$ExpectedRunId,
        [Parameter(Mandatory = $true)][string]$ExpectedRoleId,
        [Parameter(Mandatory = $true)][string]$ExpectedRepositoryHead,
        [Parameter(Mandatory = $true)][string]$ExpectedPolicyFingerprint
    )

    $previous = $null
    if ([IO.File]::Exists($HeartbeatPath)) {
        try {
            $previous = [IO.File]::ReadAllText($HeartbeatPath, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
        }
        catch {
            return [pscustomobject]@{ valid = $false; found = $true; reason_code = "progress_heartbeat_stable_json_invalid"; value = $null; semantic_fingerprint = ""; semantic_progressed = $false }
        }
        $stableValidation = Test-ColdRestoreProgressHeartbeat `
            -Value $previous `
            -ExpectedRunId $ExpectedRunId `
            -ExpectedRoleId $ExpectedRoleId `
            -ExpectedRepositoryHead $ExpectedRepositoryHead `
            -ExpectedPolicyFingerprint $ExpectedPolicyFingerprint
        if (-not [bool]$stableValidation.valid) {
            return [pscustomobject]@{ valid = $false; found = $true; reason_code = [string]$stableValidation.reason_code; value = $previous; semantic_fingerprint = ""; semantic_progressed = $false }
        }
    }
    if (-not [IO.Directory]::Exists($EventDirectory)) {
        return [pscustomobject]@{
            valid = $true
            found = $null -ne $previous
            reason_code = "ok"
            value = $previous
            semantic_fingerprint = $(if ($null -eq $previous) { "" } else { Get-ColdRestoreProgressSemanticFingerprint $previous })
            semantic_progressed = $false
        }
    }
    $semanticProgressed = $false
    $events = @(Get-ChildItem -LiteralPath $EventDirectory -File -Filter "*.snapshot.json" | Sort-Object Name)
    foreach ($event in $events) {
        try {
            $candidate = [IO.File]::ReadAllText($event.FullName, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
        }
        catch {
            return [pscustomobject]@{ valid = $false; found = $true; reason_code = "progress_heartbeat_event_json_invalid"; value = $previous; semantic_fingerprint = ""; semantic_progressed = $semanticProgressed }
        }
        $standalone = Test-ColdRestoreProgressHeartbeat `
            -Value $candidate `
            -ExpectedRunId $ExpectedRunId `
            -ExpectedRoleId $ExpectedRoleId `
            -ExpectedRepositoryHead $ExpectedRepositoryHead `
            -ExpectedPolicyFingerprint $ExpectedPolicyFingerprint
        if (-not [bool]$standalone.valid) {
            return [pscustomobject]@{ valid = $false; found = $true; reason_code = [string]$standalone.reason_code; value = $candidate; semantic_fingerprint = ""; semantic_progressed = $semanticProgressed }
        }
        $sequence = [int64]$candidate.heartbeat_sequence
        if ($event.Name -cne ("{0:D4}.snapshot.json" -f $sequence)) {
            return [pscustomobject]@{ valid = $false; found = $true; reason_code = "progress_heartbeat_event_name_invalid"; value = $candidate; semantic_fingerprint = ""; semantic_progressed = $semanticProgressed }
        }
        if ($null -ne $previous -and $sequence -le [int64]$previous.heartbeat_sequence) {
            continue
        }
        $validation = Test-ColdRestoreProgressHeartbeat `
            -Value $candidate `
            -ExpectedRunId $ExpectedRunId `
            -ExpectedRoleId $ExpectedRoleId `
            -ExpectedRepositoryHead $ExpectedRepositoryHead `
            -ExpectedPolicyFingerprint $ExpectedPolicyFingerprint `
            -Previous $previous
        if (-not [bool]$validation.valid) {
            return [pscustomobject]@{ valid = $false; found = $true; reason_code = [string]$validation.reason_code; value = $candidate; semantic_fingerprint = ""; semantic_progressed = $semanticProgressed }
        }
        try {
            $null = Write-ColdRestoreReplacingAtomicJson $HeartbeatPath $candidate
        }
        catch {
            return [pscustomobject]@{ valid = $false; found = $true; reason_code = "progress_heartbeat_atomic_replace_failed"; value = $candidate; semantic_fingerprint = ""; semantic_progressed = $semanticProgressed }
        }
        $semanticProgressed = $semanticProgressed -or [bool]$validation.semantic_progressed
        $previous = $candidate
    }
    return [pscustomobject]@{
        valid = $true
        found = $null -ne $previous
        reason_code = "ok"
        value = $previous
        semantic_fingerprint = $(if ($null -eq $previous) { "" } else { Get-ColdRestoreProgressSemanticFingerprint $previous })
        semantic_progressed = $semanticProgressed
    }
}

function Write-ColdRestoreAtomicJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )

    $parent = Split-Path -Parent $Path
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    if ([IO.File]::Exists($Path)) {
        throw "evidence_collision"
    }
    $tempPath = "$Path.tmp.$PID.$([Guid]::NewGuid().ToString('N'))"
    $json = ConvertTo-ColdRestoreCanonicalJson $Value
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
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
        $readback = [IO.File]::ReadAllText($tempPath, [Text.UTF8Encoding]::new($false))
        if ($readback -cne $json) {
            throw "evidence_readback_failed"
        }
        $null = $readback | ConvertFrom-Json
        [IO.File]::Move($tempPath, $Path)
        $finalReadback = [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false))
        if ($finalReadback -cne $json) {
            throw "evidence_final_readback_failed"
        }
    }
    finally {
        if ([IO.File]::Exists($tempPath)) {
            [IO.File]::Delete($tempPath)
        }
    }
    return Get-ColdRestoreTextSha256 $json
}

function Write-ColdRestoreExclusiveJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )

    $parent = Split-Path -Parent $Path
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    $json = ConvertTo-ColdRestoreCanonicalJson $Value
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
    try {
        $stream = [IO.FileStream]::new(
            $Path,
            [IO.FileMode]::CreateNew,
            [IO.FileAccess]::Write,
            [IO.FileShare]::None,
            4096,
            [IO.FileOptions]::WriteThrough
        )
    }
    catch {
        throw "exclusive_evidence_create_new_failed"
    }
    $consumedFailure = ""
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    }
    catch {
        $consumedFailure = "exclusive_evidence_consumed_write_failed"
    }
    try {
        $stream.Dispose()
    }
    catch {
        if ($consumedFailure -eq "") {
            $consumedFailure = "exclusive_evidence_consumed_dispose_failed"
        }
    }
    if ($consumedFailure -ne "") {
        throw $consumedFailure
    }
    try {
        $readback = [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false))
        if ($readback -cne $json) {
            throw "exclusive_evidence_consumed_readback_failed"
        }
        $null = $readback | ConvertFrom-Json
    }
    catch {
        if ($_.Exception.Message -like "exclusive_evidence_consumed_*") {
            throw
        }
        throw "exclusive_evidence_consumed_readback_failed"
    }
    return Get-ColdRestoreTextSha256 $json
}

function Write-ColdRestoreReplacingAtomicJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )

    $parent = Split-Path -Parent $Path
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    $tempPath = "$Path.tmp.$PID.$([Guid]::NewGuid().ToString('N'))"
    $backupPath = "$Path.swap.$PID.$([Guid]::NewGuid().ToString('N'))"
    $json = ConvertTo-ColdRestoreCanonicalJson $Value
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
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
        $readback = [IO.File]::ReadAllText($tempPath, [Text.UTF8Encoding]::new($false))
        if ($readback -cne $json) {
            throw "replacing_evidence_readback_failed"
        }
        $null = $readback | ConvertFrom-Json
        if ([IO.File]::Exists($Path)) {
            [IO.File]::Replace($tempPath, $Path, $backupPath, $true)
        }
        else {
            [IO.File]::Move($tempPath, $Path)
        }
        $finalReadback = [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false))
        if ($finalReadback -cne $json) {
            throw "replacing_evidence_final_readback_failed"
        }
    }
    finally {
        foreach ($candidate in @($tempPath, $backupPath)) {
            if ([IO.File]::Exists($candidate)) {
                [IO.File]::Delete($candidate)
            }
        }
    }
    return Get-ColdRestoreTextSha256 $json
}

function Test-ColdRestoreProcessAPhaseTimeline {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$ExpectedRunId,
        [Parameter(Mandatory = $true)][string]$ExpectedRepositoryHead,
        $Previous = $null
    )

    if (-not (Test-ColdRestoreExactFieldSet $Value $script:ProcessAPhaseTimelineFields)) {
        return [pscustomobject]@{ valid = $false; reason_code = "phase_timeline_field_set_invalid"; value = $Value }
    }
    $reason = "ok"
    if ([int]$Value.schema_version -ne 1 -or [string]$Value.timeline_id -cne "ProcessAPhaseTimelineV1") {
        $reason = "phase_timeline_schema_invalid"
    }
    elseif ([string]$Value.run_id -cne $ExpectedRunId) {
        $reason = "phase_timeline_run_id_mismatch"
    }
    elseif ([string]$Value.role -cne "producer") {
        $reason = "phase_timeline_role_invalid"
    }
    elseif ([string]$Value.repository_head -cne $ExpectedRepositoryHead) {
        $reason = "phase_timeline_repository_head_mismatch"
    }
    elseif ([string]$Value.scenario_fingerprint -notmatch '^[0-9a-f]{64}$') {
        $reason = "phase_timeline_scenario_fingerprint_invalid"
    }
    elseif ($Value.official -isnot [bool] `
        -or $Value.save_file_exists -isnot [bool] `
        -or $Value.child_completion_written -isnot [bool] `
        -or $Value.allowlisted_manifest_written -isnot [bool] `
        -or $Value.quit_requested -isnot [bool]) {
        $reason = "phase_timeline_boolean_invalid"
    }
    elseif ([int64]$Value.process_start_monotonic_ms -lt 0 `
        -or [int64]$Value.snapshot_sequence -le 0 `
        -or [int64]$Value.last_progress_monotonic_ms -lt [int64]$Value.process_start_monotonic_ms `
        -or [int64]$Value.save_file_bytes -lt 0) {
        $reason = "phase_timeline_integer_invalid"
    }
    elseif ([bool]$Value.save_file_exists -ne (
        [int64]$Value.save_file_bytes -gt 0 -and [string]$Value.save_file_sha256 -match '^[0-9a-f]{64}$'
    )) {
        $reason = "phase_timeline_save_state_invalid"
    }
    elseif (@($Value.phase_rows).Count -lt 1 -or @($Value.phase_rows).Count -gt $script:ProcessAPhaseIds.Count) {
        $reason = "phase_timeline_rows_invalid"
    }

    $lastCompleted = ""
    $incompleteCount = 0
    $previousEntered = [int64]$Value.process_start_monotonic_ms
    if ($reason -eq "ok") {
        for ($index = 0; $index -lt @($Value.phase_rows).Count; $index += 1) {
            $row = @($Value.phase_rows)[$index]
            if (-not (Test-ColdRestoreExactFieldSet $row $script:ProcessAPhaseRowFields) `
                -or [string]$row.phase_id -cne [string]$script:ProcessAPhaseIds[$index]) {
                $reason = "phase_timeline_phase_order_invalid"
                break
            }
            $entered = [int64]$row.entered_monotonic_ms
            $completed = [int64]$row.completed_monotonic_ms
            $duration = [int64]$row.duration_ms
            if ($entered -lt $previousEntered -or $completed -lt 0 -or $duration -lt 0) {
                $reason = "phase_timeline_monotonicity_invalid"
                break
            }
            if ($completed -eq 0) {
                $incompleteCount += 1
                if ($index -ne @($Value.phase_rows).Count - 1 `
                    -or $duration -ne 0 `
                    -or [string]$row.reason_code -cne "in_progress") {
                    $reason = "phase_timeline_incomplete_row_invalid"
                    break
                }
            }
            else {
                if ($completed -lt $entered -or $duration -ne ($completed - $entered)) {
                    $reason = "phase_timeline_duration_invalid"
                    break
                }
                if ([string]::IsNullOrEmpty([string]$row.reason_code) `
                    -or (-not [string]::IsNullOrEmpty([string]$row.evidence_fingerprint) `
                        -and [string]$row.evidence_fingerprint -notmatch '^[0-9a-f]{64}$')) {
                    $reason = "phase_timeline_row_value_invalid"
                    break
                }
                $lastCompleted = [string]$row.phase_id
                $previousEntered = $completed
            }
        }
    }
    if ($reason -eq "ok") {
        $lastRow = @($Value.phase_rows)[@($Value.phase_rows).Count - 1]
        $expectedCurrent = if ([int64]$lastRow.completed_monotonic_ms -eq 0) { [string]$lastRow.phase_id } else { "" }
        if ($incompleteCount -gt 1 `
            -or [string]$Value.current_phase -cne $expectedCurrent `
            -or [string]$Value.last_completed_phase -cne $lastCompleted) {
            $reason = "phase_timeline_cursor_invalid"
        }
    }
    if ($reason -eq "ok") {
        $fingerprint = Get-ColdRestoreEvidenceFingerprint $Value "timeline_fingerprint"
        if ([string]$Value.timeline_fingerprint -cne $fingerprint) {
            $reason = "phase_timeline_fingerprint_invalid"
        }
    }
    if ($reason -eq "ok" -and $null -ne $Previous) {
        if ([string]$Previous.run_id -cne [string]$Value.run_id `
            -or [string]$Previous.repository_head -cne [string]$Value.repository_head `
            -or [string]$Previous.scenario_fingerprint -cne [string]$Value.scenario_fingerprint `
            -or [bool]$Previous.official -ne [bool]$Value.official) {
            $reason = "phase_timeline_identity_mutation"
        }
        elseif ([int64]$Value.snapshot_sequence -ne ([int64]$Previous.snapshot_sequence + 1)) {
            $reason = "phase_timeline_sequence_invalid"
        }
        elseif (@($Value.phase_rows).Count -lt @($Previous.phase_rows).Count) {
            $reason = "phase_timeline_truncated"
        }
        elseif ([int64]$Value.last_progress_monotonic_ms -lt [int64]$Previous.last_progress_monotonic_ms) {
            $reason = "phase_timeline_progress_regressed"
        }
        else {
            for ($index = 0; $index -lt @($Previous.phase_rows).Count; $index += 1) {
                $previousRow = @($Previous.phase_rows)[$index]
                if ([int64]$previousRow.completed_monotonic_ms -gt 0 `
                    -and (ConvertTo-ColdRestoreCanonicalJson $previousRow) -cne (ConvertTo-ColdRestoreCanonicalJson @($Value.phase_rows)[$index])) {
                    $reason = "phase_timeline_completed_row_mutation"
                    break
                }
            }
            if ($reason -eq "ok") {
                foreach ($flag in @("save_file_exists", "child_completion_written", "allowlisted_manifest_written", "quit_requested")) {
                    if ([bool]$Previous.$flag -and -not [bool]$Value.$flag) {
                        $reason = "phase_timeline_flag_regressed"
                        break
                    }
                }
            }
        }
    }
    return [pscustomobject]@{
        valid = $reason -eq "ok"
        reason_code = $reason
        value = $Value
    }
}

function Sync-ColdRestoreProcessAPhaseTimeline {
    param(
        [Parameter(Mandatory = $true)][string]$EventDirectory,
        [Parameter(Mandatory = $true)][string]$TimelinePath,
        [Parameter(Mandatory = $true)][string]$ExpectedRunId,
        [Parameter(Mandatory = $true)][string]$ExpectedRepositoryHead
    )

    $previous = $null
    if ([IO.File]::Exists($TimelinePath)) {
        try {
            $previous = [IO.File]::ReadAllText($TimelinePath, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
        }
        catch {
            return [pscustomobject]@{ valid = $false; found = $true; reason_code = "phase_timeline_stable_json_invalid"; value = $null }
        }
        $stableValidation = Test-ColdRestoreProcessAPhaseTimeline $previous $ExpectedRunId $ExpectedRepositoryHead
        if (-not [bool]$stableValidation.valid) {
            return [pscustomobject]@{ valid = $false; found = $true; reason_code = [string]$stableValidation.reason_code; value = $previous }
        }
    }
    if (-not [IO.Directory]::Exists($EventDirectory)) {
        return [pscustomobject]@{ valid = $true; found = $null -ne $previous; reason_code = "ok"; value = $previous }
    }
    $events = @(
        Get-ChildItem -LiteralPath $EventDirectory -File -Filter "*.snapshot.json" |
            Sort-Object Name
    )
    foreach ($event in $events) {
        try {
            $candidate = [IO.File]::ReadAllText($event.FullName, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
        }
        catch {
            return [pscustomobject]@{ valid = $false; found = $true; reason_code = "phase_timeline_event_json_invalid"; value = $previous }
        }
        if ($null -ne $previous -and [int64]$candidate.snapshot_sequence -le [int64]$previous.snapshot_sequence) {
            continue
        }
        $validation = Test-ColdRestoreProcessAPhaseTimeline $candidate $ExpectedRunId $ExpectedRepositoryHead $previous
        if (-not [bool]$validation.valid) {
            return [pscustomobject]@{ valid = $false; found = $true; reason_code = [string]$validation.reason_code; value = $candidate }
        }
        try {
            $null = Write-ColdRestoreReplacingAtomicJson $TimelinePath $candidate
        }
        catch {
            return [pscustomobject]@{ valid = $false; found = $true; reason_code = "phase_timeline_atomic_replace_failed"; value = $candidate }
        }
        $previous = $candidate
    }
    return [pscustomobject]@{ valid = $true; found = $null -ne $previous; reason_code = "ok"; value = $previous }
}

function New-ColdRestoreChildCompletionFixture {
    param(
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$Role,
        [Parameter(Mandatory = $true)][string]$RepositoryHead,
        [bool]$QualificationGreen = $true,
        [string]$ProductBlocker = "",
        [int]$QueueCount = 1
    )

    $value = [ordered]@{
        schema_version = 1
        run_id = $RunId
        role = $Role
        repository_head = $RepositoryHead
        scenario_fingerprint = ("a" * 64)
        official = $false
        formal = $false
        qualification_completed = $true
        qualification_green = $QualificationGreen
        product_blocker = $ProductBlocker
        queue_count = $QueueCount
        queue_revision = $QueueCount
        queue_trigger_actor = $(if ($QueueCount -gt 0) { "local" } else { "none" })
        queue_trigger_semantic_action_id = $(if ($QueueCount -gt 0) { "card.play" } else { "" })
        queue_trigger_card_semantic_id = $(if ($QueueCount -gt 0) { "fixture.card" } else { "" })
        queue_trigger_target_fingerprint = $(if ($QueueCount -gt 0) { "b" * 64 } else { "" })
        save_written = $false
        official_count_consumed = $false
        product_mutation_count = 0
        direct_authority_mutation_count = 0
        queue_injection_count = 0
        final_reason_code = $(if ($QualificationGreen) { "qualification_green" } else { $ProductBlocker })
        evidence_fingerprint = ""
        child_ready_to_exit = $true
    }
    $value.evidence_fingerprint = Get-ColdRestoreEvidenceFingerprint $value "evidence_fingerprint"
    return [pscustomobject]$value
}

function Test-ColdRestoreChildCompletionAttestation {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedRunId,
        [Parameter(Mandatory = $true)][string]$ExpectedRole,
        [Parameter(Mandatory = $true)][string]$ExpectedRepositoryHead,
        [Parameter(Mandatory = $true)][datetime]$ProcessStartedAtUtc
    )

    if (-not [IO.File]::Exists($Path)) {
        return [pscustomobject]@{ valid = $false; found = $false; reason_code = "child_attestation_missing"; fingerprint = ""; value = $null }
    }
    if ([IO.File]::GetLastWriteTimeUtc($Path) -lt $ProcessStartedAtUtc.AddSeconds(-1)) {
        return [pscustomobject]@{ valid = $false; found = $true; reason_code = "child_attestation_stale"; fingerprint = ""; value = $null }
    }
    try {
        $value = [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{ valid = $false; found = $true; reason_code = "child_attestation_json_invalid"; fingerprint = ""; value = $null }
    }
    if (-not (Test-ColdRestoreExactFieldSet $value $script:ChildCompletionFields)) {
        return [pscustomobject]@{ valid = $false; found = $true; reason_code = "child_attestation_field_set_invalid"; fingerprint = ""; value = $value }
    }
    $reason = ""
    if ([int]$value.schema_version -ne 1) { $reason = "child_attestation_schema_invalid" }
    elseif ([string]$value.run_id -cne $ExpectedRunId) { $reason = "child_attestation_run_id_mismatch" }
    elseif ([string]$value.role -cne $ExpectedRole) { $reason = "child_attestation_role_mismatch" }
    elseif ([string]$value.repository_head -cne $ExpectedRepositoryHead) { $reason = "child_attestation_repository_head_mismatch" }
    elseif ($value.child_ready_to_exit -isnot [bool] -or -not [bool]$value.child_ready_to_exit) { $reason = "child_attestation_not_ready_to_exit" }
    elseif ($value.qualification_completed -isnot [bool] -or -not [bool]$value.qualification_completed) { $reason = "child_attestation_qualification_incomplete" }
    elseif ([string]$value.queue_trigger_actor -notin @("local", "ai", "none")) { $reason = "child_attestation_actor_invalid" }
    elseif ([int64]$value.queue_count -lt 0 -or [int64]$value.queue_revision -lt 0) { $reason = "child_attestation_count_invalid" }
    elseif ([bool]$value.qualification_green -and -not [string]::IsNullOrEmpty([string]$value.product_blocker)) { $reason = "child_attestation_green_blocker_conflict" }
    elseif (-not [bool]$value.qualification_green -and [string]::IsNullOrEmpty([string]$value.product_blocker)) { $reason = "child_attestation_blocker_missing" }
    $fingerprint = Get-ColdRestoreEvidenceFingerprint $value "evidence_fingerprint"
    if ([string]::IsNullOrEmpty($reason) -and [string]$value.evidence_fingerprint -cne $fingerprint) {
        $reason = "child_attestation_fingerprint_invalid"
    }
    return [pscustomobject]@{
        valid = [string]::IsNullOrEmpty($reason)
        found = $true
        reason_code = $(if ([string]::IsNullOrEmpty($reason)) { "ok" } else { $reason })
        fingerprint = $(if ([string]::IsNullOrEmpty($reason)) { $fingerprint } else { "" })
        value = $value
    }
}

function New-ColdRestoreGodotArgumentList {
    param(
        [Parameter(Mandatory = $true)][string[]]$EngineArgumentList,
        [Parameter(Mandatory = $true)][string[]]$UserArgumentList
    )

    $engineOnly = @("--check-only", "--headless", "--path", "--script", "--editor", "--import")
    if ($EngineArgumentList -contains "--" -or $UserArgumentList -contains "--") {
        throw "godot_argument_separator_duplicated"
    }
    foreach ($argument in $UserArgumentList) {
        $name = ([string]$argument).Split("=", 2)[0]
        if ($name -in $engineOnly) {
            throw "godot_engine_argument_after_separator"
        }
    }
    return @($EngineArgumentList) + @("--") + @($UserArgumentList)
}

function Get-ColdRestoreProcessSnapshot {
    try {
        return @(
            Get-CimInstance Win32_Process -ErrorAction Stop |
                Select-Object ProcessId, ParentProcessId, Name, CommandLine, CreationDate
        )
    }
    catch {
        throw "process_snapshot_failed"
    }
}

function Get-ColdRestoreSnapshotCreationTimeTicks {
    param([Parameter(Mandatory = $true)]$Record)

    if ($null -eq $Record.CreationDate -or $Record.CreationDate -isnot [datetime]) {
        throw "process_identity_creation_time_unavailable"
    }
    return ConvertTo-ColdRestoreProcessCreationTimeTicks ([datetime]$Record.CreationDate)
}

function ConvertTo-ColdRestoreProcessCreationTimeTicks {
    param([Parameter(Mandatory = $true)][datetime]$CreationTime)

    # Win32_Process exposes CreationDate at microsecond precision. Normalize
    # Process.StartTime to that same precision before identity comparisons.
    $utcTicks = $CreationTime.ToUniversalTime().Ticks
    $microsecondTicks = $utcTicks - ($utcTicks % 10)
    return $microsecondTicks.ToString([Globalization.CultureInfo]::InvariantCulture)
}

function Test-ColdRestoreOwnedProcessRecord {
    param(
        [Parameter(Mandatory = $true)][Collections.Generic.Dictionary[int, string]]$OwnedProcesses,
        [Parameter(Mandatory = $true)]$Record
    )

    $processId = [int]$Record.ProcessId
    if (-not $OwnedProcesses.ContainsKey($processId)) {
        return $false
    }
    try {
        return [string]$OwnedProcesses[$processId] -ceq (Get-ColdRestoreSnapshotCreationTimeTicks $Record)
    }
    catch {
        return $false
    }
}

function Add-ColdRestoreOwnedProcesses {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][Collections.Generic.Dictionary[int, string]]$OwnedProcesses,
        [Parameter(Mandatory = $true)][array]$Snapshot
    )

    $snapshotByProcessId = @{}
    foreach ($record in $Snapshot) {
        $snapshotByProcessId[[int]$record.ProcessId] = $record
    }
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($record in $Snapshot) {
            $pidValue = [int]$record.ProcessId
            $parentValue = [int]$record.ParentProcessId
            if (-not $OwnedProcesses.ContainsKey($parentValue)) {
                continue
            }
            if ($snapshotByProcessId.ContainsKey($parentValue) `
                -and -not (Test-ColdRestoreOwnedProcessRecord $OwnedProcesses $snapshotByProcessId[$parentValue])) {
                continue
            }
            $creationTicks = Get-ColdRestoreSnapshotCreationTimeTicks $record
            if ($OwnedProcesses.ContainsKey($pidValue)) {
                if ([string]$OwnedProcesses[$pidValue] -cne $creationTicks) {
                    throw "process_identity_pid_reused"
                }
                continue
            }
            $OwnedProcesses.Add($pidValue, $creationTicks)
            $changed = $true
        }
    }
}

function Get-ColdRestoreAliveOwnedProcessRecords {
    param(
        [Parameter(Mandatory = $true)][Collections.Generic.Dictionary[int, string]]$OwnedProcesses,
        [Parameter(Mandatory = $true)][array]$Snapshot
    )

    return @($Snapshot | Where-Object { Test-ColdRestoreOwnedProcessRecord $OwnedProcesses $_ })
}

function Stop-ColdRestoreOwnedProcessIdentity {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][string]$ExpectedCreationTimeUtcTicks
    )

    try {
        $process = [Diagnostics.Process]::GetProcessById($ProcessId)
        try {
            $actualTicks = ConvertTo-ColdRestoreProcessCreationTimeTicks $process.StartTime
            if ($actualTicks -cne $ExpectedCreationTimeUtcTicks) {
                return $false
            }
            $process.Kill($true)
            return $true
        }
        finally {
            $process.Dispose()
        }
    }
    catch [ArgumentException] {
        return $true
    }
    catch {
        return $false
    }
}

function Get-ColdRestoreProcessIdentityFingerprint {
    param([Parameter(Mandatory = $true)][Collections.Generic.Dictionary[int, string]]$OwnedProcesses)

    $identities = @(
        foreach ($processId in @($OwnedProcesses.Keys | Sort-Object)) {
            [ordered]@{
                process_id = [int]$processId
                creation_time_utc_ticks = [string]$OwnedProcesses[[int]$processId]
            }
        }
    )
    return Get-ColdRestoreTextSha256 (ConvertTo-ColdRestoreCanonicalJson $identities)
}

function Get-ColdRestoreProcessCreationTimeTicks {
    param([Parameter(Mandatory = $true)][int]$ProcessId)

    $process = $null
    try {
        $process = [Diagnostics.Process]::GetProcessById($ProcessId)
        return ConvertTo-ColdRestoreProcessCreationTimeTicks $process.StartTime
    }
    catch {
        throw "launch_process_creation_time_unavailable"
    }
    finally {
        if ($null -ne $process) {
            $process.Dispose()
        }
    }
}

function Write-ColdRestoreLaunchAttestation {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Authorization,
        [Parameter(Mandatory = $true)][Diagnostics.Process]$WrapperProcess
    )

    if (-not (Test-ColdRestoreExactFieldSet $Authorization $script:LaunchAuthorizationContextFields)) {
        throw "launch_authorization_context_field_set_invalid"
    }
    if ([int]$Authorization.orchestrator_process_id -ne $PID) {
        throw "launch_orchestrator_process_mismatch"
    }
    $wrapperPid = [int]$WrapperProcess.Id
    $wrapperCreationTicks = Get-ColdRestoreProcessCreationTimeTicks $wrapperPid
    $enginePid = $wrapperPid
    $engineParentPid = $PID
    $engineCreationTicks = $wrapperCreationTicks
    $wrapperName = [IO.Path]::GetFileNameWithoutExtension($WrapperProcess.StartInfo.FileName)
    $wrapperIsGodot = $wrapperName -like "Godot*"
    if ($wrapperIsGodot) {
        $launchToken = "--cold-restore-launch-nonce=$([string]$Authorization.launch_nonce)"
        $engineCandidate = @()
        $discoveryDeadline = [DateTime]::UtcNow.AddSeconds(5)
        $requiresConsoleChild = $wrapperName.EndsWith("_console", [StringComparison]::OrdinalIgnoreCase)
        do {
            $snapshot = Get-ColdRestoreProcessSnapshot
            $engineCandidate = @($snapshot | Where-Object {
                [string]$_.Name -like "Godot*" `
                    -and (([int]$_.ParentProcessId -eq $wrapperPid) `
                        -or (-not $requiresConsoleChild -and [int]$_.ProcessId -eq $wrapperPid)) `
                    -and [string]$_.CommandLine -like "*$launchToken*"
            } | Sort-Object @{ Expression = { if ([int]$_.ParentProcessId -eq $wrapperPid) { 0 } else { 1 } } }, ProcessId | Select-Object -First 1)
            if ($engineCandidate.Count -eq 1) {
                break
            }
            Start-Sleep -Milliseconds 25
        } while ([DateTime]::UtcNow -lt $discoveryDeadline -and -not $WrapperProcess.HasExited)
        if ($engineCandidate.Count -ne 1) {
            throw "launch_engine_process_unavailable"
        }
        $enginePid = [int]$engineCandidate[0].ProcessId
        $engineParentPid = [int]$engineCandidate[0].ParentProcessId
        $engineCreationTicks = Get-ColdRestoreProcessCreationTimeTicks $enginePid
    }

    $attestation = [ordered]@{
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
        wrapper_process_id = $wrapperPid
        wrapper_parent_process_id = $PID
        wrapper_creation_time_utc_ticks = $wrapperCreationTicks
        engine_process_id = $enginePid
        engine_parent_process_id = $engineParentPid
        engine_creation_time_utc_ticks = $engineCreationTicks
        status = "authorized"
    }
    Write-ColdRestoreAtomicJson $Path ([pscustomobject]$attestation) | Out-Null
    return [pscustomobject]$attestation
}

function Invoke-ColdRestoreAttestedProcess {
    param(
        [Parameter(Mandatory = $true)][string]$ExecutablePath,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList,
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$Role,
        [Parameter(Mandatory = $true)][string]$RepositoryHead,
        [Parameter(Mandatory = $true)][string]$ChildAttestationPath,
        [Parameter(Mandatory = $true)][string]$ParentAttestationPath,
        [Parameter(Mandatory = $true)][string]$StdoutPath,
        [Parameter(Mandatory = $true)][string]$StderrPath,
        [ValidateRange(1, 3600)][int]$TimeoutSeconds = 60,
        [hashtable]$EnvironmentVariables = @{},
        [string]$LaunchAttestationPath = "",
        $LaunchAuthorization = $null,
        [string]$PhaseTimelineEventDirectory = "",
        [string]$PhaseTimelinePath = "",
        $TimeoutPolicy = $null,
        [string]$ExpectedPolicyFingerprint = "",
        [string]$PolicyRole = "",
        [string]$ProgressHeartbeatEventDirectory = "",
        [string]$ProgressHeartbeatPath = ""
    )

    $wallStopwatch = [Diagnostics.Stopwatch]::StartNew()
    $launchAuthorizationEnabled = $LaunchAttestationPath -ne "" -and $null -ne $LaunchAuthorization
    if (($LaunchAttestationPath -ne "") -ne ($null -ne $LaunchAuthorization)) {
        throw "launch_authorization_parameter_mismatch"
    }
    $phaseTimelineEnabled = $PhaseTimelineEventDirectory -ne "" -and $PhaseTimelinePath -ne ""
    if (($PhaseTimelineEventDirectory -ne "") -ne ($PhaseTimelinePath -ne "")) {
        throw "phase_timeline_parameter_mismatch"
    }
    $timeoutPolicyEnabled = $null -ne $TimeoutPolicy
    $heartbeatParametersPresent = $ExpectedPolicyFingerprint -ne "" `
        -or $PolicyRole -ne "" `
        -or $ProgressHeartbeatEventDirectory -ne "" `
        -or $ProgressHeartbeatPath -ne ""
    if ($timeoutPolicyEnabled -ne $heartbeatParametersPresent `
        -or ($timeoutPolicyEnabled -and (
            $ExpectedPolicyFingerprint -eq "" `
            -or $PolicyRole -eq "" `
            -or $ProgressHeartbeatEventDirectory -eq "" `
            -or $ProgressHeartbeatPath -eq ""
        ))) {
        throw "role_timeout_policy_parameter_mismatch"
    }
    $policyValidation = [pscustomobject]@{
        valid = $true
        reason_code = "legacy_timeout_policy"
        fingerprint = ""
        role_policy = $null
    }
    $rolePolicy = $null
    $absoluteTimeoutSeconds = $TimeoutSeconds
    $noProgressTimeoutSeconds = 0
    $pollIntervalMilliseconds = 100
    $normalExitGraceSeconds = 5
    $streamDrainGraceSeconds = 2
    $processTreeCleanupGraceSeconds = 5
    if ($timeoutPolicyEnabled) {
        $policyValidation = Test-ColdRestoreRoleTimeoutPolicy `
            -Value $TimeoutPolicy `
            -ExpectedRepositoryHead $RepositoryHead `
            -ExpectedPolicyFingerprint $ExpectedPolicyFingerprint `
            -PolicyRole $PolicyRole `
            -ExpectedProcessRole $Role
        if (-not [bool]$policyValidation.valid) {
            throw [string]$policyValidation.reason_code
        }
        $eventParent = [IO.Path]::GetFullPath((Split-Path -Parent $ProgressHeartbeatEventDirectory))
        $stableParent = [IO.Path]::GetFullPath((Split-Path -Parent $ProgressHeartbeatPath))
        if ([IO.Path]::GetFileName($ProgressHeartbeatEventDirectory) -cne "$PolicyRole.heartbeat.events" `
            -or [IO.Path]::GetFileName($ProgressHeartbeatPath) -cne "$PolicyRole.heartbeat.json" `
            -or -not $eventParent.Equals($stableParent, [StringComparison]::OrdinalIgnoreCase)) {
            throw "progress_heartbeat_path_contract_invalid"
        }
        $rolePolicy = $policyValidation.role_policy
        $absoluteTimeoutSeconds = [int]$rolePolicy.absolute_timeout_seconds
        $noProgressTimeoutSeconds = [int]$rolePolicy.no_progress_timeout_seconds
        $pollIntervalMilliseconds = [int]$TimeoutPolicy.poll_interval_ms
        $normalExitGraceSeconds = [int]$TimeoutPolicy.normal_exit_grace_seconds
        $streamDrainGraceSeconds = [int]$TimeoutPolicy.stream_drain_grace_seconds
        $processTreeCleanupGraceSeconds = [int]$TimeoutPolicy.process_tree_cleanup_grace_seconds
    }
    $evidencePaths = @($ChildAttestationPath, $ParentAttestationPath, $StdoutPath, $StderrPath)
    if ($launchAuthorizationEnabled) {
        $evidencePaths += $LaunchAttestationPath
    }
    if ($phaseTimelineEnabled) {
        $evidencePaths += $PhaseTimelinePath
    }
    if ($timeoutPolicyEnabled) {
        $evidencePaths += $ProgressHeartbeatPath
    }
    foreach ($path in $evidencePaths) {
        [IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
    }
    $preexistingGodotCount = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "godot*" }).Count
    $startedAt = [DateTime]::UtcNow
    $childPid = 0
    $observedExit = $false
    $exitCode = -1
    $timedOut = $false
    $terminatedByParent = $false
    $stdout = ""
    $stderr = ""
    $captureComplete = $false
    $launchFailureCode = ""
    $supervisionFailureCode = ""
    $timeoutReasonCode = ""
    $timeoutKind = "none"
    $phaseTimelineSync = [pscustomobject]@{ valid = $true; found = $false; reason_code = "ok"; value = $null }
    $progressHeartbeatSync = [pscustomobject]@{
        valid = $true
        found = $false
        reason_code = "ok"
        value = $null
        semantic_fingerprint = ""
        semantic_progressed = $false
    }
    $ownedProcesses = [Collections.Generic.Dictionary[int, string]]::new()
    $launchCollision = @(
        $evidencePaths |
            Where-Object { [IO.File]::Exists($_) }
    )
    if ($timeoutPolicyEnabled -and [IO.Directory]::Exists($ProgressHeartbeatEventDirectory)) {
        $launchCollision += $ProgressHeartbeatEventDirectory
    }

    if ($launchCollision.Count -eq 0) {
        $process = [Diagnostics.Process]::new()
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $ExecutablePath
        $startInfo.WorkingDirectory = $WorkingDirectory
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        foreach ($argument in $ArgumentList) {
            $startInfo.ArgumentList.Add([string]$argument)
        }
        foreach ($entry in $EnvironmentVariables.GetEnumerator()) {
            $startInfo.Environment[[string]$entry.Key] = [string]$entry.Value
        }
        $process.StartInfo = $startInfo
        try {
            if (-not $process.Start()) {
                throw "child_process_start_failed"
            }
            $childPid = $process.Id
            $ownedProcesses.Add($childPid, (Get-ColdRestoreProcessCreationTimeTicks $childPid))
            $processStopwatch = [Diagnostics.Stopwatch]::StartNew()
            $lastSemanticProgressMilliseconds = [int64]0
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
            if ($launchAuthorizationEnabled) {
                try {
                    $launchAttestation = Write-ColdRestoreLaunchAttestation $LaunchAttestationPath $LaunchAuthorization $process
                    $engineProcessId = [int]$launchAttestation.engine_process_id
                    $engineCreationTicks = [string]$launchAttestation.engine_creation_time_utc_ticks
                    if ($ownedProcesses.ContainsKey($engineProcessId) `
                        -and [string]$ownedProcesses[$engineProcessId] -cne $engineCreationTicks) {
                        throw "process_identity_pid_reused"
                    }
                    $ownedProcesses[$engineProcessId] = $engineCreationTicks
                }
                catch {
                    $launchFailureCode = "launch_attestation_write_failed"
                    throw
                }
            }
            while (-not $process.HasExited) {
                try {
                    Add-ColdRestoreOwnedProcesses $ownedProcesses (Get-ColdRestoreProcessSnapshot)
                }
                catch {
                    $supervisionFailureCode = [string]$_.Exception.Message
                    break
                }
                if ($phaseTimelineEnabled) {
                    $phaseTimelineSync = Sync-ColdRestoreProcessAPhaseTimeline `
                        -EventDirectory $PhaseTimelineEventDirectory `
                        -TimelinePath $PhaseTimelinePath `
                        -ExpectedRunId $RunId `
                        -ExpectedRepositoryHead $RepositoryHead
                    if (-not [bool]$phaseTimelineSync.valid) {
                        $supervisionFailureCode = [string]$phaseTimelineSync.reason_code
                        break
                    }
                }
                if ($timeoutPolicyEnabled) {
                    try {
                        $progressHeartbeatSync = Sync-ColdRestoreProgressHeartbeat `
                            -EventDirectory $ProgressHeartbeatEventDirectory `
                            -HeartbeatPath $ProgressHeartbeatPath `
                            -ExpectedRunId $RunId `
                            -ExpectedRoleId $PolicyRole `
                            -ExpectedRepositoryHead $RepositoryHead `
                            -ExpectedPolicyFingerprint ([string]$policyValidation.fingerprint)
                    }
                    catch {
                        $supervisionFailureCode = "progress_heartbeat_sync_failed"
                        break
                    }
                    if (-not [bool]$progressHeartbeatSync.valid) {
                        $supervisionFailureCode = [string]$progressHeartbeatSync.reason_code
                        break
                    }
                    if ([bool]$progressHeartbeatSync.semantic_progressed) {
                        $lastSemanticProgressMilliseconds = [int64]$processStopwatch.ElapsedMilliseconds
                    }
                }
                $elapsedMilliseconds = [int64]$processStopwatch.ElapsedMilliseconds
                if ($elapsedMilliseconds -ge ([int64]$absoluteTimeoutSeconds * 1000)) {
                    $timedOut = $true
                    $timeoutKind = "absolute"
                    $timeoutReasonCode = if ($timeoutPolicyEnabled) {
                        "${PolicyRole}_absolute_timeout"
                    }
                    else {
                        "child_process_timeout"
                    }
                    break
                }
                if ($timeoutPolicyEnabled `
                    -and ($elapsedMilliseconds - $lastSemanticProgressMilliseconds) -ge ([int64]$noProgressTimeoutSeconds * 1000)) {
                    $timedOut = $true
                    $timeoutKind = "no_progress"
                    $timeoutReasonCode = "${PolicyRole}_no_progress_timeout"
                    break
                }
                Start-Sleep -Milliseconds $pollIntervalMilliseconds
            }
            if (-not $process.HasExited) {
                $terminatedByParent = $true
                try {
                    $process.Kill($true)
                }
                catch [InvalidOperationException] {
                    # The child exited between the HasExited observation and the kill request.
                }
            }
            if ($process.WaitForExit($normalExitGraceSeconds * 1000)) {
                $observedExit = $true
                $exitCode = $process.ExitCode
            }
            if ($phaseTimelineEnabled) {
                $phaseTimelineSync = Sync-ColdRestoreProcessAPhaseTimeline `
                    -EventDirectory $PhaseTimelineEventDirectory `
                    -TimelinePath $PhaseTimelinePath `
                    -ExpectedRunId $RunId `
                    -ExpectedRepositoryHead $RepositoryHead
                if (-not [bool]$phaseTimelineSync.valid -and $supervisionFailureCode -eq "") {
                    $supervisionFailureCode = [string]$phaseTimelineSync.reason_code
                }
            }
            if ($timeoutPolicyEnabled -and $supervisionFailureCode -eq "") {
                try {
                    $progressHeartbeatSync = Sync-ColdRestoreProgressHeartbeat `
                        -EventDirectory $ProgressHeartbeatEventDirectory `
                        -HeartbeatPath $ProgressHeartbeatPath `
                        -ExpectedRunId $RunId `
                        -ExpectedRoleId $PolicyRole `
                        -ExpectedRepositoryHead $RepositoryHead `
                        -ExpectedPolicyFingerprint ([string]$policyValidation.fingerprint)
                    if (-not [bool]$progressHeartbeatSync.valid) {
                        $supervisionFailureCode = [string]$progressHeartbeatSync.reason_code
                    }
                    elseif ([bool]$progressHeartbeatSync.semantic_progressed) {
                        $lastSemanticProgressMilliseconds = [int64]$processStopwatch.ElapsedMilliseconds
                    }
                }
                catch {
                    $supervisionFailureCode = "progress_heartbeat_sync_failed"
                }
            }
            try {
                Add-ColdRestoreOwnedProcesses $ownedProcesses (Get-ColdRestoreProcessSnapshot)
            }
            catch {
                if ($supervisionFailureCode -eq "") {
                    $supervisionFailureCode = [string]$_.Exception.Message
                }
            }
            $stdoutReady = $stdoutTask.Wait($streamDrainGraceSeconds * 1000)
            $stderrReady = $stderrTask.Wait($streamDrainGraceSeconds * 1000)
            if ($stdoutReady) { $stdout = $stdoutTask.GetAwaiter().GetResult() }
            if ($stderrReady) { $stderr = $stderrTask.GetAwaiter().GetResult() }
            $captureComplete = $stdoutReady -and $stderrReady
        }
        catch {
            $stderr = "$stderr`n$($_.Exception.Message)".Trim()
            if ($launchFailureCode -eq "" -and $supervisionFailureCode -eq "") {
                $candidateFailure = [string]$_.Exception.Message
                $supervisionFailureCode = if ($candidateFailure -cmatch '^[a-z0-9_]{1,128}$') {
                    $candidateFailure
                }
                else {
                    "child_supervision_internal_error"
                }
            }
            if ($childPid -gt 0 -and -not $process.HasExited) {
                $terminatedByParent = $true
                $process.Kill($true)
                $null = $process.WaitForExit($normalExitGraceSeconds * 1000)
                $observedExit = $process.HasExited
                if ($observedExit) { $exitCode = $process.ExitCode }
            }
        }
        finally {
            $process.Dispose()
        }
    }

    [IO.File]::WriteAllText($StdoutPath, $stdout, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($StderrPath, $stderr, [Text.UTF8Encoding]::new($false))

    $remainingOwned = @()
    $taskOwnedProcessCountAfter = 0
    try {
        $postExitSnapshot = Get-ColdRestoreProcessSnapshot
        Add-ColdRestoreOwnedProcesses $ownedProcesses $postExitSnapshot
        $aliveOwned = @(Get-ColdRestoreAliveOwnedProcessRecords $ownedProcesses $postExitSnapshot)
        if ($aliveOwned.Count -gt 0) {
            $terminatedByParent = $true
            foreach ($record in $aliveOwned) {
                $recordProcessId = [int]$record.ProcessId
                $null = Stop-ColdRestoreOwnedProcessIdentity `
                    -ProcessId $recordProcessId `
                    -ExpectedCreationTimeUtcTicks ([string]$ownedProcesses[$recordProcessId])
            }
            $cleanupStopwatch = [Diagnostics.Stopwatch]::StartNew()
            do {
                Start-Sleep -Milliseconds 50
                $cleanupSnapshot = Get-ColdRestoreProcessSnapshot
                $remainingOwned = @(Get-ColdRestoreAliveOwnedProcessRecords $ownedProcesses $cleanupSnapshot)
            } while ($remainingOwned.Count -gt 0 `
                -and $cleanupStopwatch.ElapsedMilliseconds -lt ($processTreeCleanupGraceSeconds * 1000))
        }
        $finalSnapshot = Get-ColdRestoreProcessSnapshot
        Add-ColdRestoreOwnedProcesses $ownedProcesses $finalSnapshot
        $remainingOwned = @(Get-ColdRestoreAliveOwnedProcessRecords $ownedProcesses $finalSnapshot)
        $taskOwnedProcessCountAfter = $remainingOwned.Count
    }
    catch {
        $taskOwnedProcessCountAfter = -1
        if ($supervisionFailureCode -eq "") {
            $supervisionFailureCode = "process_snapshot_failed"
        }
    }

    $childValidation = if ($launchCollision.Count -gt 0) {
        [pscustomobject]@{ valid = $false; found = $true; reason_code = "evidence_collision"; fingerprint = ""; value = $null }
    }
    else {
        Test-ColdRestoreChildCompletionAttestation `
            -Path $ChildAttestationPath `
            -ExpectedRunId $RunId `
            -ExpectedRole $Role `
            -ExpectedRepositoryHead $RepositoryHead `
            -ProcessStartedAtUtc $startedAt
    }

    $wrapperReason = if ($launchCollision.Count -gt 0) {
        "evidence_collision"
    } elseif ($launchFailureCode -ne "") {
        $launchFailureCode
    } elseif ($supervisionFailureCode -ne "") {
        $supervisionFailureCode
    } elseif ($timedOut) {
        $timeoutReasonCode
    } elseif ($phaseTimelineEnabled -and -not [bool]$phaseTimelineSync.found) {
        "phase_timeline_missing"
    } elseif (-not $observedExit) {
        "child_exit_not_observed"
    } elseif ($exitCode -ne 0) {
        "child_process_exit_nonzero"
    } elseif (-not $captureComplete) {
        "child_stream_capture_incomplete"
    } elseif ($timeoutPolicyEnabled -and -not [bool]$progressHeartbeatSync.found) {
        "progress_heartbeat_missing"
    } elseif ($timeoutPolicyEnabled -and -not [bool]$progressHeartbeatSync.valid) {
        [string]$progressHeartbeatSync.reason_code
    } elseif (-not [bool]$childValidation.valid) {
        [string]$childValidation.reason_code
    } elseif ($terminatedByParent) {
        "child_process_tree_cleanup_required"
    } elseif ($taskOwnedProcessCountAfter -ne 0) {
        "child_process_tree_not_clean"
    } else {
        "ok"
    }
    $wrapperGreen = $wrapperReason -eq "ok"
    $parent = [ordered]@{
        schema_version = $(if ($timeoutPolicyEnabled) { 2 } else { 1 })
        run_id = $RunId
        role = $Role
        child_pid = $childPid
        observed_exit = $observedExit
        exit_code = $exitCode
        timed_out = $timedOut
        terminated_by_parent = $terminatedByParent
        stdout_sha256 = (Get-ColdRestoreTextSha256 $stdout)
        stderr_sha256 = (Get-ColdRestoreTextSha256 $stderr)
        child_attestation_found = [bool]$childValidation.found
        child_attestation_fingerprint = [string]$childValidation.fingerprint
        child_attestation_valid = [bool]$childValidation.valid
        task_owned_process_count_after = $taskOwnedProcessCountAfter
        unrelated_preexisting_process_count = $preexistingGodotCount
        wrapper_exit_green = $wrapperGreen
        wrapper_reason_code = $wrapperReason
    }
    if ($timeoutPolicyEnabled) {
        $heartbeatValue = $progressHeartbeatSync.value
        $heartbeatValid = [bool]$progressHeartbeatSync.valid -and $null -ne $heartbeatValue
        $parent["policy_role"] = $PolicyRole
        $parent["timeout_policy_fingerprint"] = [string]$policyValidation.fingerprint
        $parent["absolute_timeout_seconds"] = $absoluteTimeoutSeconds
        $parent["no_progress_timeout_seconds"] = $noProgressTimeoutSeconds
        $parent["timeout_kind"] = $timeoutKind
        $parent["progress_heartbeat_found"] = [bool]$progressHeartbeatSync.found
        $parent["progress_heartbeat_valid"] = $heartbeatValid
        $parent["progress_heartbeat_sequence"] = $(if ($heartbeatValid) { [int64]$heartbeatValue.heartbeat_sequence } else { 0 })
        $parent["progress_heartbeat_fingerprint"] = $(if ($heartbeatValid) { [string]$heartbeatValue.evidence_fingerprint } else { "" })
        $parent["progress_semantic_fingerprint"] = $(if ($heartbeatValid) { [string]$progressHeartbeatSync.semantic_fingerprint } else { "" })
        $parent["progress_phase"] = $(if ($heartbeatValid) { [string]$heartbeatValue.phase } else { "" })
        $parent["progress_last_evidence_write_time"] = $(if ($heartbeatValid) { [int64]$heartbeatValue.last_evidence_write_time } else { [int64]0 })
        $parent["task_owned_process_identity_fingerprint"] = Get-ColdRestoreProcessIdentityFingerprint $ownedProcesses
    }
    $expectedParentFields = if ($timeoutPolicyEnabled) { $script:ParentExitFieldsV2 } else { $script:ParentExitFieldsV1 }
    if (-not (Test-ColdRestoreExactFieldSet ([pscustomobject]$parent) $expectedParentFields)) {
        throw "parent_attestation_field_set_invalid"
    }
    Write-ColdRestoreAtomicJson $ParentAttestationPath ([pscustomobject]$parent) | Out-Null
    $wallStopwatch.Stop()
    return [pscustomobject]@{
        wrapper_exit_green = $wrapperGreen
        wrapper_reason_code = $wrapperReason
        child = $childValidation.value
        child_validation = $childValidation
        parent = [pscustomobject]$parent
        observed_task_process_ids = @($ownedProcesses.Keys | Sort-Object)
        observed_task_process_identities = @(
            foreach ($processId in @($ownedProcesses.Keys | Sort-Object)) {
                [pscustomobject][ordered]@{
                    process_id = [int]$processId
                    creation_time_utc_ticks = [string]$ownedProcesses[[int]$processId]
                }
            }
        )
        stdout = $stdout
        stderr = $stderr
        phase_timeline = $phaseTimelineSync.value
        phase_timeline_validation = $phaseTimelineSync
        timeout_policy_validation = $policyValidation
        timeout_policy_fingerprint = [string]$policyValidation.fingerprint
        policy_role = $PolicyRole
        timeout_kind = $timeoutKind
        progress_heartbeat = $progressHeartbeatSync.value
        progress_heartbeat_validation = $progressHeartbeatSync
        wall_elapsed_ms = [int64]$wallStopwatch.ElapsedMilliseconds
    }
}

Export-ModuleMember -Function @(
    "ConvertTo-ColdRestoreCanonicalJson",
    "Get-ColdRestoreTextSha256",
    "Get-ColdRestoreEvidenceFingerprint",
    "Test-ColdRestoreExactFieldSet",
    "Write-ColdRestoreAtomicJson",
    "Write-ColdRestoreExclusiveJson",
    "Write-ColdRestoreReplacingAtomicJson",
    "Test-ColdRestoreRoleTimeoutPolicy",
    "Get-ColdRestoreProgressSemanticFingerprint",
    "Test-ColdRestoreProgressHeartbeat",
    "Sync-ColdRestoreProgressHeartbeat",
    "Test-ColdRestoreProcessAPhaseTimeline",
    "Sync-ColdRestoreProcessAPhaseTimeline",
    "New-ColdRestoreChildCompletionFixture",
    "Test-ColdRestoreChildCompletionAttestation",
    "New-ColdRestoreGodotArgumentList",
    "Invoke-ColdRestoreAttestedProcess"
)
