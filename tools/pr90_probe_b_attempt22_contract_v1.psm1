Set-StrictMode -Version Latest

function Get-Pr90ProbeBSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing file: $Path" }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function ConvertTo-Pr90ProbeBCanonicalJson {
    param([Parameter(Mandatory = $true)][object]$Value)
    return ($Value | ConvertTo-Json -Depth 100 -Compress)
}

function Copy-Pr90ProbeBJsonObject {
    param([Parameter(Mandatory = $true)][object]$Value)
    return (ConvertTo-Pr90ProbeBCanonicalJson $Value | ConvertFrom-Json -Depth 100)
}

function Get-Pr90ProbeBCanonicalSha256 {
    param([Parameter(Mandatory = $true)][object]$Value, [string]$FieldName = 'canonical_payload_sha256')
    $copy = Copy-Pr90ProbeBJsonObject $Value
    if ($copy.PSObject.Properties.Name -ccontains $FieldName) { $copy.$FieldName = '' }
    else { $copy | Add-Member -NotePropertyName $FieldName -NotePropertyValue '' }
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-Pr90ProbeBCanonicalJson $copy))
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Write-Pr90ProbeBImmutableJson {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][object]$Value, [switch]$WriteSha256Sidecar)
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) { throw "Refusing to overwrite immutable evidence: $full" }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($full)) | Out-Null
    $temporary = "$full.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temporary, ($Value | ConvertTo-Json -Depth 100), [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporary, $full, $false)
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
    if ($WriteSha256Sidecar) {
        $sidecar = "$full.sha256"
        if (Test-Path -LiteralPath $sidecar) { throw "Refusing to overwrite immutable evidence: $sidecar" }
        [IO.File]::WriteAllText($sidecar, "$(Get-Pr90ProbeBSha256 $full)  $([IO.Path]::GetFileName($full))`n", [Text.UTF8Encoding]::new($false))
    }
    return $full
}

function Write-Pr90ProbeBImmutableText {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Text)
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) { throw "Refusing to overwrite immutable evidence: $full" }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($full)) | Out-Null
    [IO.File]::WriteAllText($full, $Text.TrimEnd("`r","`n"), [Text.UTF8Encoding]::new($false))
    return $full
}

function Test-Pr90ProbeBShaSidecar {
    param([Parameter(Mandatory = $true)][string]$TargetPath, [Parameter(Mandatory = $true)][string]$SidecarPath)
    if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf) -or -not (Test-Path -LiteralPath $SidecarPath -PathType Leaf)) { return $false }
    $match = [regex]::Match([IO.File]::ReadAllText([IO.Path]::GetFullPath($SidecarPath)).Trim(), '^([0-9a-f]{64})\s{2}(.+)$')
    return $match.Success -and $match.Groups[1].Value -ceq (Get-Pr90ProbeBSha256 $TargetPath) -and $match.Groups[2].Value -ceq [IO.Path]::GetFileName($TargetPath)
}

function Get-Pr90Attempt19RequiredFieldsV3 {
    return @(
        'authorization_schema_version','authorization_id','authorization_status','created_at_utc','authorized_run_count',
        'automatic_retry_allowed','formal_run_id','formal_evidence_root','product_head_sha','product_tree_sha',
        'import_tooling_branch','import_tooling_head_sha','import_tooling_tree_sha','import_tooling_worktree_path',
        'import_runner_path','import_runner_sha256','authorization_builder_path','authorization_builder_sha256',
        'authorization_validator_path','authorization_validator_sha256','authorized_tooling_file_count','authorized_tooling_files',
        'sealed_baseline_path','sealed_baseline_sha256','import_pass1_manifest_path','import_pass1_manifest_sha256',
        'import_pass2_manifest_path','import_pass2_manifest_sha256','warmup_log_path','warmup_log_sha256',
        'class_cache_path','class_cache_sha256','class_cache_bytes','class_cache_product_head_sha',
        'class_cache_product_tree_sha','class_cache_godot_version','class_cache_godot_executable_sha256',
        'class_cache_source_baseline_path','class_cache_source_baseline_sha256','formal_gate_1_79_receipt_path','formal_gate_1_79_receipt_sha256',
        'formal_gate_1_79_receipt_schema_version','formal_gate_1_79_receipt_head_sha','formal_gate_1_79_receipt_tree_sha',
        'formal_gate_1_79_receipt_gate_count','formal_gate_1_79_receipt_pass_count','formal_gate_1_79_receipt_fail_count',
        'formal_gate_1_79_receipt_duplicate_gate_count','formal_gate_1_79_receipt_missing_gate_count',
        'import_finalizer_dry_run_path','import_finalizer_dry_run_evidence_sha256','import_finalizer_dry_run_schema_version',
        'import_finalizer_dry_run_product_head_sha','import_finalizer_dry_run_product_tree_sha',
        'import_finalizer_dry_run_tooling_head_sha','import_finalizer_dry_run_tooling_tree_sha',
        'import_finalizer_dry_run_import_runner_sha256','import_finalizer_dry_run_baseline_sha256',
        'import_finalizer_dry_run_status','godot_path','godot_version','godot_executable_sha256','project_godot_path',
        'project_godot_sha256','cursor_runbook_path','cursor_runbook_sha256','import_controller_path',
        'import_controller_sha256','import_controller_receipt_path','import_controller_receipt_sha256',
        'bound_import_engine_path','bound_import_engine_sha256','import_finalizer_path','import_finalizer_sha256','selftest_manifest_path',
        'selftest_manifest_sha256','formal_dry_run_path','formal_dry_run_sha256','tooling_seal_path',
        'tooling_seal_sha256','old_attempt18_manifest_path','old_attempt18_manifest_sha256','old_import_runner_sha256',
        'formal_mcp_execution_count','authorized_run_count_consumed','conditional_next_stages','canonical_payload_sha256'
    )
}

function Get-Pr90Attempt22RequiredFieldsV4 {
    $fields = [Collections.Generic.List[string]]::new()
    foreach ($field in @(Get-Pr90Attempt19RequiredFieldsV3)) { $fields.Add($field) }
    foreach ($field in @(
        'authorized_run_id','tooling_repository','tooling_remote_branch','tooling_head_sha','tooling_tree_sha','tooling_parent_sha',
        'tooling_manifest_path','tooling_manifest_sha256','tooling_file_hash_inventory_sha256','startup_watchdog_sha256',
        'startup_state_machine_sha256','endpoint_ownership_contract_version','endpoint_ownership_validator_sha256',
        'listener_parity_contract_version','listener_core_normalizer_sha256','listener_parity_comparator_sha256','bracketed_cohort_controller_sha256','process_identity_enricher_sha256','failure_cleanup_sha256',
        'listener_forensics_path','listener_forensics_sha256','probe_b_v2_id',
        'probe004_result_path','probe004_result_sha256','probe004_attestation_path','probe004_attestation_sha256',
        'probe_b_result_path','probe_b_result_sha256','probe_b_attestation_path','probe_b_attestation_sha256',
        'probe_b_post_import_baseline_sha256','probe_b_class_cache_sha256',
        'probe_b_recovery_receipt_path','probe_b_recovery_receipt_sha256','probe_b_frozen_input_inventory_path','probe_b_frozen_input_inventory_sha256',
        'probe_b_execution_start_path','probe_b_execution_start_sha256','probe_b_execution_config_path','probe_b_execution_config_sha256',
        'probe_b_execution_tooling_head_sha','probe_b_execution_tooling_tree_sha','probe_b_execution_tooling_seal_sha256',
        'probe_b_recovery_tooling_head_sha','probe_b_recovery_tooling_tree_sha','probe_b_recovery_tooling_manifest_sha256','probe_b_recovery_tooling_seal_sha256','runtime_reachable_tooling_hash_mismatch_count',
        'probe_b_finalizer_result_path','probe_b_finalizer_result_sha256','probe_b_import_finalizer_status','preformal_dry_run_path','preformal_dry_run_sha256','preformal_v2_check_count',
        'preformal_v2_pass_count','preformal_v2_fail_count','authorization_seal_builder_path','authorization_seal_builder_sha256',
        'probe_b_controller_sha256','probe_b_result_builder_sha256','probe_b_attestation_builder_sha256','probe_b_recovery_controller_sha256','probe_b_recovery_contract_module_sha256','attempt22_contract_module_sha256','probe_b_frozen_input_inventory_builder_sha256',
        'probe_b_finalizer_binding_sha256','preformal_v2_controller_sha256','authorization_negative_test_count',
        'authorization_negative_test_pass_count','authorization_negative_test_fail_count','attempt22_authorization_missing_contract_count','godot_gui_path','godot_gui_sha256','godot_console_path','godot_console_sha256',
        'sealed_post_import_baseline_sha256','import_finalizer_dry_run_sha256',
        'authorization_config_path','authorization_config_sha256',
        'formal_authorization_validation_receipt_path','formal_authorization_seal_path','formal_authorization_consumption_receipt_path',
        'formal_prelaunch_ignored_inventory_path','formal_terminal_manifest_path','formal_finalizer_result_path'
    )) { if ($fields -cnotcontains $field) { $fields.Add($field) } }
    return @($fields)
}

function Test-Pr90ProbeBToolingEligibilityV1 {
    param(
        [Parameter(Mandatory = $true)][int]$MissingContractCount,
        [Parameter(Mandatory = $true)][int]$BaseSelfTestPassCount,
        [Parameter(Mandatory = $true)][int]$NewSelfTestPassCount,
        [Parameter(Mandatory = $true)][int]$NewSelfTestCaseCount,
        [Parameter(Mandatory = $true)][int]$FailureCount,
        [Parameter(Mandatory = $true)][int]$PowerShellParseErrorCount,
        [Parameter(Mandatory = $true)][int]$ParameterBindingExceptionCount
    )
    return ($MissingContractCount -eq 0 -and $BaseSelfTestPassCount -eq 326 -and $NewSelfTestCaseCount -ge 40 -and
        $NewSelfTestPassCount -eq $NewSelfTestCaseCount -and $FailureCount -eq 0 -and
        $PowerShellParseErrorCount -eq 0 -and $ParameterBindingExceptionCount -eq 0)
}

function Test-Pr90FormalM5InvocationBindingV1 {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$M5Receipt,
        [AllowNull()][object]$Connection,
        [AllowNull()][object]$EndpointOwnershipAttestation,
        [Parameter(Mandatory=$true)][string]$ExpectedRunId,
        [Parameter(Mandatory=$true)][string]$ExpectedExecutionMode,
        [Parameter(Mandatory=$true)][int]$ExpectedPort,
        [Parameter(Mandatory=$true)][int]$ExpectedGodotPid,
        [Parameter(Mandatory=$true)][string]$ExpectedLaunchSessionId,
        [Parameter(Mandatory=$true)][int]$ExpectedEndpointOwnerPid
    )
    try {
        if($null-eq$M5Receipt-or$null-eq$Connection-or$null-eq$EndpointOwnershipAttestation-or$ExpectedGodotPid-le0-or$ExpectedEndpointOwnerPid-le0){return $false}
        if([string]$M5Receipt.schema-cne'McpStartupMilestoneV1'-or[string]$M5Receipt.status-cne'PASS'-or
           [string]$M5Receipt.run_id-cne$ExpectedRunId-or[string]$M5Receipt.execution_mode-cne$ExpectedExecutionMode-or
           [int]$M5Receipt.milestone_index-ne5-or[string]$M5Receipt.milestone_id-cne'M5'-or[string]$M5Receipt.milestone_name-cne'mcp_endpoint_owner_v2_verified'-or
           [int]$M5Receipt.port-ne$ExpectedPort-or-not[bool]$M5Receipt.port_bound-or[int]$M5Receipt.endpoint_ownership_contract_version-ne2-or
           -not[bool]$M5Receipt.connection_exists-or[string]$M5Receipt.session_id-cne$ExpectedLaunchSessionId-or
           [int]$M5Receipt.pid-ne$ExpectedGodotPid-or[int]$M5Receipt.endpoint_owner_pid-ne$ExpectedEndpointOwnerPid-or
           [string]$M5Receipt.canonical_payload_sha256-cne(Get-Pr90ProbeBCanonicalSha256 $M5Receipt)){return $false}
        if([string]$Connection.schema-cne'McpStartupConnectionV2'-or[int]$Connection.endpoint_ownership_contract_version-ne2-or
           [int]$Connection.port-ne$ExpectedPort-or[int]$Connection.pid-ne$ExpectedGodotPid-or[int]$Connection.control_process_pid-ne$ExpectedGodotPid-or
           [string]$Connection.launch_session_id-cne$ExpectedLaunchSessionId-or[int]$Connection.endpoint_owner_pid-ne$ExpectedEndpointOwnerPid){return $false}
        if([string]$EndpointOwnershipAttestation.schema-cne'SpaceSyndicatePr90McpEndpointOwnershipBracketedV2Attestation'-or
           [string]$EndpointOwnershipAttestation.status-cne'PASS'-or-not[bool]$EndpointOwnershipAttestation.green-or
           [int]$EndpointOwnershipAttestation.endpoint_ownership_contract_version-ne2-or[int]$EndpointOwnershipAttestation.endpoint_owner_pid-ne$ExpectedEndpointOwnerPid){return $false}
        return $true
    } catch {return $false}
}

function Test-Pr90FormalMainRuntimeStreamTransitionV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$StartupStreamId,
        [AllowNull()][object]$SnapshotPage,
        [AllowNull()][object]$ReadyPage
    )
    try {
        if([string]::IsNullOrWhiteSpace($StartupStreamId)-or$null-eq$SnapshotPage-or$null-eq$ReadyPage){return $false}
        $mainStreamId=[string]$SnapshotPage.stream_id
        if([string]::IsNullOrWhiteSpace($mainStreamId)-or$mainStreamId-ceq$StartupStreamId-or
           -not[bool]$SnapshotPage.success-or[string]$SnapshotPage.event_sequence_mode-cne'snapshot_only'-or
           [string]$SnapshotPage.continuity_status-cne'SNAPSHOT_ONLY'-or[bool]$SnapshotPage.client_truncated-or
           [bool]$SnapshotPage.event_window_overflowed-or[int]$SnapshotPage.event_overflow_count-ne0-or
           [int]$SnapshotPage.buffered_first_event_sequence-ne1){return $false}
        if(-not[bool]$ReadyPage.success-or[string]$ReadyPage.stream_id-cne$mainStreamId-or
           [string]$ReadyPage.requested_stream_id-cne$mainStreamId-or[int64]$ReadyPage.requested_since_sequence-ne0-or
           [string]$ReadyPage.event_sequence_mode-cne'cursor'-or[string]$ReadyPage.continuity_status-cne'CONTIGUOUS'-or
           -not[bool]$ReadyPage.event_sequence_complete-or[int]$ReadyPage.event_sequence_gap_count-ne0-or
           [int]$ReadyPage.event_sequence_invalid_count-ne0-or[bool]$ReadyPage.client_truncated-or
           [bool]$ReadyPage.event_window_overflowed-or[int]$ReadyPage.event_overflow_count-ne0){return $false}
        $events=@($ReadyPage.events)
        if($events.Count-eq0){return $false}
        if([int64]$events[0].event_sequence-ne1-or[string]$events[0].kind-cne'ready'-or[string]$events[0].message-cne'Runtime bridge ready.'){return $false}
        $expectedSequence=[int64]1;$readyCount=0
        foreach($event in $events){
            if([string]$event.stream_id-cne$mainStreamId-or[int64]$event.event_sequence-ne$expectedSequence){return $false}
            if([string]$event.kind-ceq'ready'-and[string]$event.message-ceq'Runtime bridge ready.'){$readyCount+=1}
            $expectedSequence+=1
        }
        return ($readyCount-eq1-and[int64]$ReadyPage.event_sequence_first-eq1-and[int64]$ReadyPage.event_sequence_last-eq($expectedSequence-1))
    } catch {return $false}
}

function Test-Pr90McpV2BoundInvocationIdentityV1 {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Connection,
        [AllowNull()][object]$EndpointOwnerIdentity,
        [AllowNull()][object]$EndpointOwnershipAttestation,
        [int[]]$ListenerOwnerPids=@(),
        [int]$AlternateProtectedListenerCount=0,
        [Parameter(Mandatory=$true)][string]$ExpectedWorktree,
        [Parameter(Mandatory=$true)][int]$ExpectedPort,
        [Parameter(Mandatory=$true)][int]$ExpectedControlProcessId,
        [Parameter(Mandatory=$true)][string]$ExpectedControlProcessStartUtc,
        [Parameter(Mandatory=$true)][string]$ExpectedLaunchSessionId,
        [Parameter(Mandatory=$true)][int]$ExpectedEndpointOwnerPid,
        [Parameter(Mandatory=$true)][string]$ExpectedEndpointOwnerPath,
        [Parameter(Mandatory=$true)][string]$ExpectedEndpointOwnerSha256,
        [Parameter(Mandatory=$true)][string]$ExpectedEndpointOwnerCreationFiletimeUtc,
        [Parameter(Mandatory=$true)][int]$ExpectedEndpointOwnerSessionId,
        [Parameter(Mandatory=$true)][string]$ExpectedEndpointOwnerUserSid
    )
    try {
        if($null-eq$Connection-or$null-eq$EndpointOwnerIdentity-or$null-eq$EndpointOwnershipAttestation){return $false}
        $root=[IO.Path]::GetFullPath($ExpectedWorktree).TrimEnd('\','/')
        $ownerPath=[IO.Path]::GetFullPath($ExpectedEndpointOwnerPath)
        $endpoint="http://127.0.0.1:$ExpectedPort/"
        $requiredConnectionFields=@('schema','endpoint','port','pid','control_process_pid','worktree','godot_path','process_start_time_utc','command_line','endpoint_ownership_contract_version','endpoint_owner_pid','endpoint_owner_process_role','endpoint_owner_executable_path','endpoint_owner_command_line','endpoint_owner_creation_time_filetime_utc','endpoint_owner_parent_pid','endpoint_owner_windows_session_id','endpoint_owner_user_sid','launch_session_id','token_path')
        $connectionFields=@($Connection.PSObject.Properties.Name)
        if(@($requiredConnectionFields|Where-Object{$connectionFields-cnotcontains$_}).Count-ne0-or
           [string]$Connection.schema-cne'McpStartupConnectionV2'-or[int]$Connection.endpoint_ownership_contract_version-ne2-or
           [string]$Connection.endpoint_owner_process_role-cne'GUI_ENGINE'-or[string]$Connection.endpoint-cne$endpoint-or[int]$Connection.port-ne$ExpectedPort-or
           [IO.Path]::GetFullPath([string]$Connection.worktree).TrimEnd('\','/')-cne$root-or
           [int]$Connection.pid-ne$ExpectedControlProcessId-or[int]$Connection.control_process_pid-ne$ExpectedControlProcessId-or
           [string]$Connection.process_start_time_utc-cne$ExpectedControlProcessStartUtc-or[string]$Connection.launch_session_id-cne$ExpectedLaunchSessionId-or
           [int]$Connection.endpoint_owner_pid-ne$ExpectedEndpointOwnerPid-or$ExpectedEndpointOwnerPid-le0-or$ExpectedEndpointOwnerPid-eq$ExpectedControlProcessId-or
           -not([IO.Path]::GetFullPath([string]$Connection.endpoint_owner_executable_path).Equals($ownerPath,[StringComparison]::OrdinalIgnoreCase))-or
           [string]$Connection.endpoint_owner_creation_time_filetime_utc-cne$ExpectedEndpointOwnerCreationFiletimeUtc-or
           [int]$Connection.endpoint_owner_parent_pid-ne$ExpectedControlProcessId-or[int]$Connection.endpoint_owner_windows_session_id-ne$ExpectedEndpointOwnerSessionId-or
           [string]$Connection.endpoint_owner_user_sid-cne$ExpectedEndpointOwnerUserSid-or
           -not([IO.Path]::GetFullPath([string]$Connection.token_path).Equals((Join-Path $root '.codex-godot/auth.token'),[StringComparison]::OrdinalIgnoreCase))){return $false}
        $escapedRoot=[Regex]::Escape($root);if([string]$Connection.endpoint_owner_command_line-notmatch("(?i)(?:^|\s)--path(?:\s+|=)(?:`"$escapedRoot`"|$escapedRoot)(?=\s|$)")){return $false}
        if($ListenerOwnerPids.Count-ne1-or[int]$ListenerOwnerPids[0]-ne$ExpectedEndpointOwnerPid-or$AlternateProtectedListenerCount-ne0){return $false}
        if(-not[bool]$EndpointOwnerIdentity.exists-or-not[bool]$EndpointOwnerIdentity.identity_read_green-or[int]$EndpointOwnerIdentity.pid-ne$ExpectedEndpointOwnerPid-or
           -not([IO.Path]::GetFullPath([string]$EndpointOwnerIdentity.executable_path).Equals($ownerPath,[StringComparison]::OrdinalIgnoreCase))-or
           [string]$EndpointOwnerIdentity.executable_sha256-cne$ExpectedEndpointOwnerSha256-or[string]$EndpointOwnerIdentity.creation_time_filetime_utc-cne$ExpectedEndpointOwnerCreationFiletimeUtc-or
           [int]$EndpointOwnerIdentity.parent_pid-ne$ExpectedControlProcessId-or[int]$EndpointOwnerIdentity.windows_session_id-ne$ExpectedEndpointOwnerSessionId-or
           [string]$EndpointOwnerIdentity.user_sid-cne$ExpectedEndpointOwnerUserSid-or[string]$EndpointOwnerIdentity.command_line-cne[string]$Connection.endpoint_owner_command_line){return $false}
        if([string]$EndpointOwnershipAttestation.schema-cne'SpaceSyndicatePr90McpEndpointOwnershipBracketedV2Attestation'-or[string]$EndpointOwnershipAttestation.status-cne'PASS'-or
           -not[bool]$EndpointOwnershipAttestation.green-or[int]$EndpointOwnershipAttestation.endpoint_ownership_contract_version-ne2-or[int]$EndpointOwnershipAttestation.endpoint_owner_pid-ne$ExpectedEndpointOwnerPid-or
           [int]$EndpointOwnershipAttestation.endpoint_owner_identity.pid-ne$ExpectedEndpointOwnerPid-or[string]$EndpointOwnershipAttestation.endpoint_owner_identity.creation_time_filetime_utc-cne$ExpectedEndpointOwnerCreationFiletimeUtc-or
           [string]$EndpointOwnershipAttestation.endpoint_owner_identity.executable_sha256-cne$ExpectedEndpointOwnerSha256-or-not[bool]$EndpointOwnershipAttestation.endpoint_owner_is_gui_engine-or
           [bool]$EndpointOwnershipAttestation.endpoint_owner_is_console_wrapper-or-not[bool]$EndpointOwnershipAttestation.endpoint_owner_is_descendant_of_launcher-or
           -not[bool]$EndpointOwnershipAttestation.endpoint_owner_project_match-or-not[bool]$EndpointOwnershipAttestation.endpoint_owner_mcp_session_match-or
           -not[bool]$EndpointOwnershipAttestation.endpoint_owner_windows_session_match-or-not[bool]$EndpointOwnershipAttestation.endpoint_owner_user_sid_match-or
           -not[bool]$EndpointOwnershipAttestation.endpoint_owner_creation_identity_match-or[int]$EndpointOwnershipAttestation.foreign_listener_count-ne0-or
           [int]$EndpointOwnershipAttestation.multiple_active_endpoint_owner_count-ne0-or[int]$EndpointOwnershipAttestation.protected_port_multiple_owner_count-ne0){return $false}
        return $true
    } catch {return $false}
}

function Test-Pr90CanonicalImportEndpointOwnershipV2 {
    param(
        [AllowNull()][object]$ControlIdentity,
        [AllowNull()][object]$EndpointOwnerIdentity,
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][int[]]$ListenerOwnerPids,
        [Parameter(Mandatory=$true)][int]$AlternateProtectedListenerCount,
        [Parameter(Mandatory=$true)][int]$ExpectedControlProcessId,
        [Parameter(Mandatory=$true)][string]$ExpectedControlPath,
        [Parameter(Mandatory=$true)][string]$ExpectedControlSha256,
        [Parameter(Mandatory=$true)][string]$ExpectedControlCreationFiletimeUtc,
        [Parameter(Mandatory=$true)][int]$ExpectedEndpointOwnerPid,
        [Parameter(Mandatory=$true)][string]$ExpectedEndpointOwnerPath,
        [Parameter(Mandatory=$true)][string]$ExpectedEndpointOwnerSha256,
        [Parameter(Mandatory=$true)][string]$ExpectedRoot
    )
    if($null-eq$ControlIdentity-or$null-eq$EndpointOwnerIdentity){return $false}
    try{
        $pathBinding={param([string]$CommandLine,[string]$Root)
            if([string]::IsNullOrWhiteSpace($CommandLine)){return $false}
            foreach($form in @($Root,$Root.Replace('\','/'))){
                $escaped=[Regex]::Escape($form.TrimEnd('\','/'))
                if([Regex]::IsMatch($CommandLine,'(?i)(?:^|\s)--path(?:\s+|=)(?:"'+$escaped+'"|'+$escaped+')(?=\s|$)')){return $true}
            }
            return $false
        }
        if($ListenerOwnerPids.Count-ne1-or[int]$ListenerOwnerPids[0]-ne$ExpectedEndpointOwnerPid-or$AlternateProtectedListenerCount-ne0){return $false}
        if(-not[bool]$ControlIdentity.exists-or-not[bool]$ControlIdentity.identity_read_green-or[int]$ControlIdentity.pid-ne$ExpectedControlProcessId-or
           [string]$ControlIdentity.executable_path-ine$ExpectedControlPath-or[string]$ControlIdentity.executable_sha256-cne$ExpectedControlSha256-or
           [string]$ControlIdentity.creation_time_filetime_utc-cne$ExpectedControlCreationFiletimeUtc-or-not(& $pathBinding ([string]$ControlIdentity.command_line) $ExpectedRoot)){return $false}
        if(-not[bool]$EndpointOwnerIdentity.exists-or-not[bool]$EndpointOwnerIdentity.identity_read_green-or[int]$EndpointOwnerIdentity.pid-ne$ExpectedEndpointOwnerPid-or
           $ExpectedEndpointOwnerPid-eq$ExpectedControlProcessId-or[string]$EndpointOwnerIdentity.executable_path-ine$ExpectedEndpointOwnerPath-or
           [string]$EndpointOwnerIdentity.executable_sha256-cne$ExpectedEndpointOwnerSha256-or[int]$EndpointOwnerIdentity.parent_pid-ne$ExpectedControlProcessId-or
           [int]$EndpointOwnerIdentity.windows_session_id-ne[int]$ControlIdentity.windows_session_id-or[string]::IsNullOrWhiteSpace([string]$EndpointOwnerIdentity.user_sid)-or
           [string]$EndpointOwnerIdentity.user_sid-cne[string]$ControlIdentity.user_sid-or[long]$EndpointOwnerIdentity.creation_time_filetime_utc-lt[long]$ExpectedControlCreationFiletimeUtc-or
           -not(& $pathBinding ([string]$EndpointOwnerIdentity.command_line) $ExpectedRoot)){return $false}
        return $true
    }catch{return $false}
}

function Resolve-Pr90CanonicalImportFallbackControlV1 {
    param(
        [AllowNull()][object[]]$CandidateIdentities,
        [Parameter(Mandatory=$true)][string]$ExpectedControlPath,
        [Parameter(Mandatory=$true)][string]$ExpectedRoot
    )
    $rows=@($CandidateIdentities)
    if($rows.Count-ne1){return [pscustomobject][ordered]@{accepted=$false;pid=0;creation_time_utc='';failure_class='CONTROL_CANDIDATE_CARDINALITY'}}
    $candidate=$rows[0]
    try{
        $pathGreen=$false
        foreach($form in @($ExpectedRoot,$ExpectedRoot.Replace('\','/'))){
            $escaped=[Regex]::Escape($form.TrimEnd('\','/'))
            if([Regex]::IsMatch([string]$candidate.command_line,'(?i)(?:^|\s)--path(?:\s+|=)(?:"'+$escaped+'"|'+$escaped+')(?=\s|$)')){$pathGreen=$true;break}
        }
        $accepted=([bool]$candidate.exists-and[bool]$candidate.identity_read_green-and[int]$candidate.pid-gt0-and
            [string]$candidate.executable_path-ieq$ExpectedControlPath-and-not[string]::IsNullOrWhiteSpace([string]$candidate.creation_time_utc)-and$pathGreen)
        return [pscustomobject][ordered]@{
            accepted=$accepted
            pid=if($accepted){[int]$candidate.pid}else{0}
            creation_time_utc=if($accepted){[string]$candidate.creation_time_utc}else{''}
            failure_class=if($accepted){''}else{'CONTROL_CANDIDATE_IDENTITY'}
        }
    }catch{return [pscustomobject][ordered]@{accepted=$false;pid=0;creation_time_utc='';failure_class='CONTROL_CANDIDATE_UNREADABLE'}}
}

function Test-Pr90FormalPostInputBridgeReadinessSampleV1 {
    param(
        [AllowNull()][object]$Status,
        [Parameter(Mandatory=$true)][string]$ExpectedStreamId,
        [Parameter(Mandatory=$true)][int64]$MinimumCursorAfter,
        [Parameter(Mandatory=$true)][string]$ExpectedCommandId,
        [Parameter(Mandatory=$true)][long]$MinimumStateModifiedUnix,
        [int]$MaximumStateAgeMsec=2500
    )
    if($null-eq$Status-or[string]::IsNullOrWhiteSpace($ExpectedStreamId)-or[string]::IsNullOrWhiteSpace($ExpectedCommandId)-or$MinimumCursorAfter-lt1-or$MinimumStateModifiedUnix-lt0-or$MaximumStateAgeMsec-lt1){return $false}
    try{
        $state=$Status.state;$cursor=$state.runtime_event_cursor;$latest=$Status.latest_response
        if(-not[bool]$Status.installed-or-not[bool]$Status.script_exists-or-not[bool]$Status.state_exists-or-not[bool]$Status.response_exists-or
           [long]$Status.state_modified_unix-le$MinimumStateModifiedUnix-or[long]$Status.state_age_msec-lt0-or[long]$Status.state_age_msec-gt$MaximumStateAgeMsec-or
           [string]$state.status-cne'running'-or[bool]$state.paused-or[string]$state.current_scene.scene_file_path-cne'res://scenes/main.tscn'-or
           [string]$state.last_command_id-cne$ExpectedCommandId-or[string]$latest.id-cne$ExpectedCommandId-or[string]$latest.command-cne'send_input'-or-not[bool]$latest.success-or
           [string]$cursor.stream_id-cne$ExpectedStreamId-or[int64]$cursor.buffered_last_event_sequence-lt$MinimumCursorAfter-or[int64]$cursor.next_event_sequence-le[int64]$cursor.buffered_last_event_sequence-or
           [bool]$cursor.event_window_overflowed-or[bool]$cursor.event_window_saturated-or[int64]$cursor.event_overflow_count-ne0){return $false}
        return $true
    }catch{return $false}
}

function Get-Pr90FormalPostInputReadinessObservationClassV1 {
    param(
        [AllowNull()][object]$Status,
        [AllowEmptyString()][string]$ObservationError='',
        [Parameter(Mandatory=$true)][string]$ExpectedStreamId,
        [Parameter(Mandatory=$true)][int64]$MinimumCursorAfter,
        [Parameter(Mandatory=$true)][string]$ExpectedCommandId,
        [bool]$AllowPendingExpectedCommandState=$false
    )
    if(-not[string]::IsNullOrWhiteSpace($ObservationError)-or$null-eq$Status){return 'MCP_STATUS_UNAVAILABLE'}
    try{
        $state=$Status.state;$cursor=$state.runtime_event_cursor;$latest=$Status.latest_response
        if(-not[bool]$Status.installed-or-not[bool]$Status.script_exists-or-not[bool]$Status.state_exists-or-not[bool]$Status.response_exists){return 'MCP_STATUS_UNAVAILABLE'}
        if([bool]$cursor.event_window_overflowed-or[bool]$cursor.event_window_saturated-or[int64]$cursor.event_overflow_count-ne0){return 'RUNTIME_EVENT_OVERFLOW'}
        if([bool]$state.paused-or[string]$state.current_scene.scene_file_path-cne'res://scenes/main.tscn'-or
           [string]$latest.id-cne$ExpectedCommandId-or[string]$latest.command-cne'send_input'-or-not[bool]$latest.success-or
           [string]$cursor.stream_id-cne$ExpectedStreamId){return 'RUNTIME_IDENTITY_DRIFT'}
        if([string]$state.status-cnotin@('running','command')){return 'RUNTIME_IDENTITY_DRIFT'}
        if([int64]$cursor.next_event_sequence-le[int64]$cursor.buffered_last_event_sequence){return 'RUNTIME_CURSOR_REGRESSION'}
        if($AllowPendingExpectedCommandState-and([string]$state.last_command_id-cne$ExpectedCommandId-or[int64]$cursor.buffered_last_event_sequence-lt$MinimumCursorAfter)){return 'AWAITING_EXPECTED_COMMAND_HEARTBEAT'}
        if([string]$state.last_command_id-cne$ExpectedCommandId){return 'RUNTIME_IDENTITY_DRIFT'}
        if([int64]$cursor.buffered_last_event_sequence-lt$MinimumCursorAfter){return 'RUNTIME_CURSOR_REGRESSION'}
        if([string]$state.status-ceq'running'){return 'READINESS_IDENTITY_GREEN'}
        if($AllowPendingExpectedCommandState-and[string]$state.status-ceq'command'){return 'AWAITING_POST_COMMAND_RUNNING_HEARTBEAT'}
        return 'RUNTIME_IDENTITY_DRIFT'
    }catch{return 'MCP_STATUS_UNAVAILABLE'}
}

function Resolve-Pr90FormalPostInputReadinessOutcomeV1 {
    param(
        [Parameter(Mandatory=$true)][bool]$Passed,
        [AllowEmptyString()][string]$HardFailureClass='',
        [Parameter(Mandatory=$true)][bool]$SawProductReadinessStall,
        [AllowEmptyString()][string]$LastObservationClass='MCP_STATUS_UNAVAILABLE'
    )
    if(-not[string]::IsNullOrWhiteSpace($HardFailureClass)){return $HardFailureClass}
    if($Passed){return ''}
    if($SawProductReadinessStall){return 'PRODUCT_RUNTIME_UNRESPONSIVE'}
    if([string]::IsNullOrWhiteSpace($LastObservationClass)){return 'MCP_STATUS_UNAVAILABLE'}
    return $LastObservationClass
}

function Get-Pr90FormalUiTreeRowsV1 {
    param([AllowNull()][object]$Root)
    if($null-eq$Root){return @()}
    $rows=[Collections.Generic.List[object]]::new();$stack=[Collections.Generic.Stack[object]]::new();$stack.Push($Root)
    while($stack.Count-gt0){
        $row=$stack.Pop();$rows.Add($row)
        $childrenValue=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $row -Name 'children'
        $children=@()
        if($childrenValue-is[Collections.IEnumerable]-and-not($childrenValue-is[string])){$children=@($childrenValue)}
        for($index=$children.Count-1;$index-ge0;$index-=1){if($null-ne$children[$index]){$stack.Push($children[$index])}}
    }
    return @($rows)
}

function ConvertTo-Pr90FormalTapCenterV1 {
    param([AllowNull()][object]$Center)
    if($null-eq$Center){return $null}
    try{
        if($Center-is[Collections.IDictionary]){
            $names=@($Center.Keys|ForEach-Object{[string]$_});if(@(Compare-Object -ReferenceObject @('x','y') -DifferenceObject $names).Count-ne0){return $null};$xValue=$Center['x'];$yValue=$Center['y']
        }else{
            $names=@($Center.PSObject.Properties.Name);if(@(Compare-Object -ReferenceObject @('x','y') -DifferenceObject $names).Count-ne0){return $null};$xValue=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $Center -Name 'x';$yValue=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $Center -Name 'y'
        }
        $numericTypes=@([byte],[sbyte],[int16],[uint16],[int32],[uint32],[int64],[uint64],[single],[double],[decimal])
        if($xValue-is[bool]-or$yValue-is[bool]-or-not($numericTypes-contains$xValue.GetType())-or-not($numericTypes-contains$yValue.GetType())){return $null}
        $x=[double]$xValue;$y=[double]$yValue
        if([double]::IsNaN($x)-or[double]::IsInfinity($x)-or[double]::IsNaN($y)-or[double]::IsInfinity($y)){return $null}
        return @{x=$x;y=$y}
    }catch{return $null}
}

function Get-Pr90FormalTapViewportDecisionV1 {
    param([AllowNull()][object]$Center,[AllowNull()][object]$ViewportNode)
    $invalid=[pscustomobject][ordered]@{green=$false;classification='INVALID';direction='';distance=[double]::PositiveInfinity;center=$null}
    try{
        $normalized=ConvertTo-Pr90FormalTapCenterV1 -Center $Center
        if($null-eq$normalized-or$null-eq$ViewportNode){return $invalid}
        $properties=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $ViewportNode -Name 'properties'
        $position=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $properties -Name 'global_position'
        $size=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $properties -Name 'size'
        $topLeft=ConvertTo-Pr90FormalTapCenterV1 -Center $position
        $extent=ConvertTo-Pr90FormalTapCenterV1 -Center $size
        $visible=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $properties -Name 'visible'
        if($null-eq$topLeft-or$null-eq$extent-or$visible-isnot[bool]-or-not$visible-or[double]$extent.x-le0-or[double]$extent.y-le0){return $invalid}
        $left=[double]$topLeft.x;$top=[double]$topLeft.y;$right=$left+[double]$extent.x;$bottom=$top+[double]$extent.y
        if([double]$normalized.x-lt$left-or[double]$normalized.x-ge$right){return [pscustomobject][ordered]@{green=$false;classification='HORIZONTAL_OUT_OF_BOUNDS';direction='';distance=[Math]::Min([Math]::Abs([double]$normalized.x-$left),[Math]::Abs([double]$normalized.x-$right));center=$normalized}}
        if([double]$normalized.y-lt$top){return [pscustomobject][ordered]@{green=$false;classification='VERTICAL_OUT_OF_BOUNDS';direction='wheel_up';distance=$top-[double]$normalized.y;center=$normalized}}
        if([double]$normalized.y-ge$bottom){return [pscustomobject][ordered]@{green=$false;classification='VERTICAL_OUT_OF_BOUNDS';direction='wheel_down';distance=[double]$normalized.y-$bottom;center=$normalized}}
        return [pscustomobject][ordered]@{green=$true;classification='INSIDE';direction='';distance=0.0;center=$normalized}
    }catch{return $invalid}
}

function Test-Pr90FormalTapViewportProgressV1 {
    param([AllowNull()][object]$Before,[AllowNull()][object]$After)
    try{
        if($null-eq$Before-or$null-eq$After-or[bool]$Before.green){return $false}
        if([bool]$After.green){return $true}
        return [string]$Before.classification-ceq'VERTICAL_OUT_OF_BOUNDS'-and[string]$After.classification-ceq'VERTICAL_OUT_OF_BOUNDS'-and[double]$After.distance-lt[double]$Before.distance
    }catch{return $false}
}

function Test-Pr90FormalTapCenterInScreenV1 {
    param([AllowNull()][object]$Center,[double]$Width=1600.0,[double]$Height=960.0)
    $normalized=ConvertTo-Pr90FormalTapCenterV1 -Center $Center
    return $null-ne$normalized-and$Width-gt0-and$Height-gt0-and[double]$normalized.x-ge0-and[double]$normalized.x-lt$Width-and[double]$normalized.y-ge0-and[double]$normalized.y-lt$Height
}

function Get-Pr90FormalRootActionCenterV1 {
    param([AllowNull()][object]$Node,[AllowNull()][object]$ViewportNode)
    try{
        $properties=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $Node -Name 'properties'
        $visible=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $properties -Name 'visible'
        if($visible-isnot[bool]-or-not[bool]$visible){return $null}
        $center=Get-Pr90FormalNodeCenterV1 -Node $Node
        $decision=Get-Pr90FormalTapViewportDecisionV1 -Center $center -ViewportNode $ViewportNode
        if(-not[bool]$decision.green-or-not(Test-Pr90FormalTapCenterInScreenV1 -Center $decision.center)){return $null}
        return $decision.center
    }catch{return $null}
}

function Test-Pr90FormalAutoGeneratedNodePathV1 {
    param([AllowNull()][string]$Path)
    return -not[string]::IsNullOrWhiteSpace($Path)-and$Path-cmatch'(?:^|/)@[^/@]+@\d+(?:/|$)'
}

function Test-Pr90FormalImmediateChildPathV1 {
    param([AllowNull()][string]$Path,[AllowNull()][string]$StableParentPath)
    if([string]::IsNullOrWhiteSpace($Path)-or[string]::IsNullOrWhiteSpace($StableParentPath)){return $false}
    $normalizedPath=$Path.TrimEnd('/');$normalizedParent=$StableParentPath.TrimEnd('/')
    if($normalizedPath.StartsWith('/root/Main/',[StringComparison]::Ordinal)){$normalizedPath=$normalizedPath.Substring('/root/Main/'.Length)}
    if($normalizedParent.StartsWith('/root/Main/',[StringComparison]::Ordinal)){$normalizedParent=$normalizedParent.Substring('/root/Main/'.Length)}
    if(-not$normalizedPath.StartsWith($normalizedParent+'/',[StringComparison]::Ordinal)){return $false}
    $leaf=$normalizedPath.Substring($normalizedParent.Length+1)
    return -not[string]::IsNullOrWhiteSpace($leaf)-and-not$leaf.Contains('/')
}

function Test-Pr90FormalImmediateAutoGeneratedChildPathV1 {
    param([AllowNull()][string]$Path,[AllowNull()][string]$StableParentPath)
    return (Test-Pr90FormalImmediateChildPathV1 -Path $Path -StableParentPath $StableParentPath)-and(Test-Pr90FormalAutoGeneratedNodePathV1 -Path $Path)
}

function ConvertTo-Pr90FormalSemanticJsonValueV1 {
    param([AllowNull()][object]$Value)
    if($null-eq$Value){return $null}
    if($Value-is[bool]-or$Value-is[string]){return $Value}
    if($Value-is[byte]-or$Value-is[sbyte]-or$Value-is[int16]-or$Value-is[uint16]-or$Value-is[int32]-or$Value-is[uint32]-or$Value-is[int64]-or$Value-is[uint64]-or$Value-is[single]-or$Value-is[double]-or$Value-is[decimal]){return [double]$Value}
    if($Value-is[Collections.IDictionary]){$row=[ordered]@{};foreach($key in $Value.Keys){$row[[string]$key]=ConvertTo-Pr90FormalSemanticJsonValueV1 $Value[$key]};return [pscustomobject]$row}
    if($Value-is[Collections.IEnumerable]-and$Value-isnot[string]){return @($Value|ForEach-Object{ConvertTo-Pr90FormalSemanticJsonValueV1 $_})}
    if($null-ne$Value.PSObject){$row=[ordered]@{};foreach($property in @($Value.PSObject.Properties)){$row[$property.Name]=ConvertTo-Pr90FormalSemanticJsonValueV1 $property.Value};return [pscustomobject]$row}
    return $Value
}

function Test-Pr90FormalJsonIntegerV1 {
    param([AllowNull()][object]$Value,[int64]$Expected)
    if($null-eq$Value-or$Value-is[bool]-or$Value-is[string]-or$Value-isnot[ValueType]){return $false}
    try{
        $numeric=[double]$Value
        if([double]::IsNaN($numeric)-or[double]::IsInfinity($numeric)-or$numeric-ne[Math]::Truncate($numeric)){return $false}
        return ([int64]$numeric)-eq$Expected
    }catch{return $false}
}

function Test-Pr90FormalJsonNonnegativeNumberV1 {
    param([AllowNull()][object]$Value)
    if($null-eq$Value-or$Value-is[bool]-or$Value-is[string]-or$Value-isnot[ValueType]){return $false}
    try{
        $numeric=[double]$Value
        return -not[double]::IsNaN($numeric)-and-not[double]::IsInfinity($numeric)-and$numeric-ge0
    }catch{return $false}
}

function Test-Pr90FormalJsonArrayV1 {
    param([AllowNull()][object]$Value)
    return $null-ne$Value-and$Value-is[Collections.IEnumerable]-and$Value-isnot[string]-and$Value-isnot[Collections.IDictionary]-and$Value-isnot[pscustomobject]
}

function Test-Pr90FormalJsonObjectV1 {
    param([AllowNull()][object]$Value)
    return $null-ne$Value-and($Value-is[pscustomobject]-or$Value-is[Collections.IDictionary])
}

function Test-Pr90FormalJsonStringArrayExactV1 {
    param([AllowNull()][object]$Value,[string[]]$Expected=@())
    if(-not(Test-Pr90FormalJsonArrayV1 -Value $Value)){return $false}
    $actual=@($Value)
    if($actual.Count-ne$Expected.Count){return $false}
    for($index=0;$index-lt$actual.Count;$index+=1){if($actual[$index]-isnot[string]-or[string]$actual[$index]-cne[string]$Expected[$index]){return $false}}
    return $true
}

function Test-Pr90FormalJsonPointV1 {
    param([AllowNull()][object]$Point)
    if($null-eq$Point-or@(Compare-Object -ReferenceObject @('x','y') -DifferenceObject @($Point.PSObject.Properties.Name)).Count-ne0){return $false}
    return (Test-Pr90FormalJsonNonnegativeNumberV1 -Value $Point.x)-and(Test-Pr90FormalJsonNonnegativeNumberV1 -Value $Point.y)
}

function Test-Pr90FormalRawEnvelopeV1 {
    param([AllowNull()][object]$RawResponse)
    try{
        if($null-eq$RawResponse-or@(Compare-Object -ReferenceObject @('id','jsonrpc','result') -DifferenceObject @($RawResponse.PSObject.Properties.Name)).Count-ne0-or
            $RawResponse.jsonrpc-isnot[string]-or[string]$RawResponse.jsonrpc-cne'2.0'-or-not(Test-Pr90FormalJsonIntegerV1 -Value $RawResponse.id -Expected 1)-or
            @(Compare-Object -ReferenceObject @('content','isError','structuredContent') -DifferenceObject @($RawResponse.result.PSObject.Properties.Name)).Count-ne0-or
            $RawResponse.result.isError-isnot[bool]-or$null-eq$RawResponse.result.structuredContent-or-not(Test-Pr90FormalJsonArrayV1 -Value $RawResponse.result.content)){return $false}
        $content=@($RawResponse.result.content)
        return $content.Count-eq1-and@(Compare-Object -ReferenceObject @('text','type') -DifferenceObject @($content[0].PSObject.Properties.Name)).Count-eq0-and$content[0].type-is[string]-and[string]$content[0].type-ceq'text'-and$content[0].text-is[string]-and-not[string]::IsNullOrWhiteSpace([string]$content[0].text)
    }catch{return $false}
}

function Test-Pr90FormalTreeNodeShapeV1 {
    param([AllowNull()][object]$Node)
    try{
        $required=@('children','name','path','properties','scene_file_path','type');$allowed=$required+@('children_truncated','groups','script_path')
        $actual=@($Node.PSObject.Properties.Name)
        if(@(Compare-Object -ReferenceObject $required -DifferenceObject @($actual|Where-Object{$_-cnotin@('children_truncated','groups','script_path')})).Count-ne0-or@($actual|Where-Object{$_-cnotin$allowed}).Count-ne0-or
            $Node.name-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Node.name)-or$Node.path-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Node.path)-or$Node.scene_file_path-isnot[string]-or$Node.type-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Node.type)-or-not(Test-Pr90FormalJsonObjectV1 -Value $Node.properties)-or-not(Test-Pr90FormalJsonArrayV1 -Value $Node.children)){return $false}
        if($null-ne$Node.PSObject.Properties['script_path']-and($Node.script_path-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Node.script_path))){return $false}
        if($null-ne$Node.PSObject.Properties['groups']){if(-not(Test-Pr90FormalJsonArrayV1 -Value $Node.groups)-or@($Node.groups).Count-eq0-or@($Node.groups|Sort-Object -Unique).Count-ne@($Node.groups).Count){return $false};foreach($group in @($Node.groups)){if($group-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$group)){return $false}}}
        if($null-ne$Node.PSObject.Properties['children_truncated']-and($Node.children_truncated-isnot[bool]-or[bool]$Node.children_truncated)){return $false}
        foreach($child in @($Node.children)){if(-not(Test-Pr90FormalTreeNodeShapeV1 -Node $child)){return $false}}
        return $true
    }catch{return $false}
}

function Get-Pr90FormalTreeMetricsV1 {
    param([AllowNull()][object]$Tree,[int]$ExpectedMaxDepth)
    $count=0;$observedMaxDepth=0;$green=$true
    try{
        $pending=[Collections.Generic.Queue[object]]::new();$pending.Enqueue([pscustomobject]@{node=$Tree;depth=0})
        while($pending.Count-gt0){
            $entry=$pending.Dequeue();$node=$entry.node;$depth=[int]$entry.depth
            if($null-eq$node-or$depth-gt$ExpectedMaxDepth){$green=$false;break}
            $count+=1;if($depth-gt$observedMaxDepth){$observedMaxDepth=$depth}
            $truncatedProperty=$node.PSObject.Properties['children_truncated']
            if($depth-eq$ExpectedMaxDepth){if($null-eq$truncatedProperty-or$truncatedProperty.Value-isnot[bool]-or[bool]$truncatedProperty.Value){$green=$false;break}}
            elseif($null-ne$truncatedProperty){$green=$false;break}
            foreach($child in @($node.children)){$pending.Enqueue([pscustomobject]@{node=$child;depth=$depth+1})}
        }
    }catch{$green=$false}
    return [pscustomobject][ordered]@{green=$green;node_count=$count;max_depth=$observedMaxDepth}
}

function Test-Pr90FormalFoundNodeResultShapeV1 {
    param([AllowNull()][object]$Result,[bool]$IncludeChildren,[string[]]$ExpectedProperties=@())
    try{
        $required=[Collections.Generic.List[string]]@('found','name','path','properties','scene_file_path','type')
        if($IncludeChildren){$required.Add('tree');$required.Add('tree_truncated')}
        if($ExpectedProperties.Count-gt0){$required.Add('requested_properties')}
        $actual=@($Result.PSObject.Properties.Name)
        $allowed=@($required)+@('script_path','groups')
        if(@(Compare-Object -ReferenceObject @($required) -DifferenceObject @($actual|Where-Object{$_-cnotin@('script_path','groups')})).Count-ne0-or@($actual|Where-Object{$_-cnotin$allowed}).Count-ne0){return $false}
        if($Result.found-isnot[bool]-or-not[bool]$Result.found-or$Result.name-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Result.name)-or$Result.path-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Result.path)-or$Result.type-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Result.type)-or$Result.scene_file_path-isnot[string]-or-not(Test-Pr90FormalJsonObjectV1 -Value $Result.properties)){return $false}
        if($null-ne$Result.PSObject.Properties['script_path']-and($Result.script_path-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Result.script_path))){return $false}
        if($null-ne$Result.PSObject.Properties['groups']){if(-not(Test-Pr90FormalJsonArrayV1 -Value $Result.groups)-or@($Result.groups).Count-eq0-or@($Result.groups|Sort-Object -Unique).Count-ne@($Result.groups).Count){return $false};foreach($group in @($Result.groups)){if($group-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$group)){return $false}}}
        if($IncludeChildren){
            if($Result.tree_truncated-isnot[bool]-or[bool]$Result.tree_truncated-or$null-eq$Result.tree-or-not(Test-Pr90FormalTreeNodeShapeV1 -Node $Result.tree)){return $false}
            $treePaths=@(Get-Pr90FormalUiTreeRowsV1 -Root $Result.tree|ForEach-Object{[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $_ -Name 'path')})
            if($treePaths.Count-eq0-or@($treePaths|Where-Object{[string]::IsNullOrWhiteSpace($_)}).Count-ne0-or@($treePaths|Sort-Object -Unique).Count-ne$treePaths.Count){return $false}
        }
        if($ExpectedProperties.Count-gt0){if(-not(Test-Pr90FormalJsonObjectV1 -Value $Result.requested_properties)){return $false};$names=@($Result.requested_properties.PSObject.Properties.Name);if($names.Count-ne$ExpectedProperties.Count-or@(Compare-Object -ReferenceObject @($ExpectedProperties) -DifferenceObject $names).Count-ne0){return $false}}
        return $true
    }catch{return $false}
}

function Test-Pr90FormalStructuredTextMirrorV1 {
    param([AllowNull()][object]$RawResponse)
    try{
        if(-not(Test-Pr90FormalRawEnvelopeV1 -RawResponse $RawResponse)){return $false}
        $content=@($RawResponse.result.content)
        if($content.Count-ne1-or[string]$content[0].type-cne'text'-or[string]::IsNullOrWhiteSpace([string]$content[0].text)){return $false}
        $textStructured=[string]$content[0].text|ConvertFrom-Json -Depth 100 -DateKind String
        return (ConvertTo-Pr90ProbeBCanonicalJson (ConvertTo-Pr90FormalSemanticJsonValueV1 $textStructured))-ceq(ConvertTo-Pr90ProbeBCanonicalJson (ConvertTo-Pr90FormalSemanticJsonValueV1 $RawResponse.result.structuredContent))
    }catch{return $false}
}

function Get-Pr90FormalDynamicNodeQueryClassV1 {
    param(
        [AllowNull()][object]$Request,
        [AllowNull()][object]$RawResponse,
        [Parameter(Mandatory=$true)][string]$ExpectedRunId,
        [Parameter(Mandatory=$true)][int]$ExpectedCallIndex,
        [Parameter(Mandatory=$true)][string]$ExpectedPath,
        [Parameter(Mandatory=$true)][string]$StableParentPath,
        [string[]]$ExpectedProperties=@()
    )
    try{
        if($null-eq$Request-or@(Compare-Object -ReferenceObject @('schema','run_id','call_index','tool_name','arguments','timeout_seconds','canonical_payload_sha256') -DifferenceObject @($Request.PSObject.Properties.Name)).Count-ne0-or
            $Request.schema-isnot[string]-or[string]$Request.schema-cne'SpaceSyndicateFormalMcpRequestV1'-or$Request.run_id-isnot[string]-or[string]$Request.run_id-cne$ExpectedRunId-or
            -not(Test-Pr90FormalJsonIntegerV1 -Value $Request.call_index -Expected $ExpectedCallIndex)-or$Request.tool_name-isnot[string]-or[string]$Request.tool_name-cne'query_runtime_node'-or-not(Test-Pr90FormalJsonIntegerV1 -Value $Request.timeout_seconds -Expected 45)-or
            $Request.canonical_payload_sha256-isnot[string]-or[string]$Request.canonical_payload_sha256-cne(Get-Pr90ProbeBCanonicalSha256 $Request)-or-not(Test-Pr90FormalJsonObjectV1 -Value $Request.arguments)-or
            @(Compare-Object -ReferenceObject @('node_path','properties','include_children','timeout_msec') -DifferenceObject @($Request.arguments.PSObject.Properties.Name)).Count-ne0-or
            $Request.arguments.node_path-isnot[string]-or[string]$Request.arguments.node_path-cne$ExpectedPath-or$Request.arguments.include_children-isnot[bool]-or[bool]$Request.arguments.include_children-or-not(Test-Pr90FormalJsonIntegerV1 -Value $Request.arguments.timeout_msec -Expected 30000)-or
            -not(Test-Pr90FormalJsonStringArrayExactV1 -Value $Request.arguments.properties -Expected $ExpectedProperties)-or
            -not(Test-Pr90FormalImmediateChildPathV1 -Path $ExpectedPath -StableParentPath $StableParentPath)){return 'FOREIGN_ERROR'}
        if(-not(Test-Pr90FormalRawEnvelopeV1 -RawResponse $RawResponse)-or-not(Test-Pr90FormalStructuredTextMirrorV1 -RawResponse $RawResponse)){return 'FOREIGN_ERROR'}
        $structured=$RawResponse.result.structuredContent
        if(@(Compare-Object -ReferenceObject @('command','command_id','elapsed_msec','error','response','result','success') -DifferenceObject @($structured.PSObject.Properties.Name)).Count-ne0-or
            $null-eq$structured.PSObject.Properties['success']-or$structured.success-isnot[bool]-or$null-eq$structured.response.PSObject.Properties['success']-or$structured.response.success-isnot[bool]-or
            -not(Test-Pr90FormalJsonNonnegativeNumberV1 -Value $structured.elapsed_msec)-or-not(Test-Pr90FormalJsonNonnegativeNumberV1 -Value $structured.response.elapsed_msec)-or$structured.response.timestamp-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$structured.response.timestamp)-or
            $structured.command-isnot[string]-or[string]$structured.command-cne'query_node'-or$structured.command_id-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$structured.command_id)-or$structured.error-isnot[string]-or
            $structured.response.command-isnot[string]-or[string]$structured.response.command-cne'query_node'-or$structured.response.id-isnot[string]-or[string]$structured.response.id-cne[string]$structured.command_id-or
            (ConvertTo-Pr90ProbeBCanonicalJson $structured.result)-cne(ConvertTo-Pr90ProbeBCanonicalJson $structured.response.result)){return 'FOREIGN_ERROR'}
        $expectedRuntimePath=if($ExpectedPath.StartsWith('/root/Main/',[StringComparison]::Ordinal)){$ExpectedPath}else{'/root/Main/'+$ExpectedPath}
        if(-not[bool]$RawResponse.result.isError-and[bool]$structured.success-and[bool]$structured.response.success-and[string]$structured.error-ceq''-and
            @(Compare-Object -ReferenceObject @('command','elapsed_msec','id','result','success','timestamp') -DifferenceObject @($structured.response.PSObject.Properties.Name)).Count-eq0-and
            (Test-Pr90FormalFoundNodeResultShapeV1 -Result $structured.result -IncludeChildren $false -ExpectedProperties $ExpectedProperties)-and
            (Test-Pr90FormalFoundNodeResultShapeV1 -Result $structured.response.result -IncludeChildren $false -ExpectedProperties $ExpectedProperties)-and
            [string]$structured.result.path-ceq$expectedRuntimePath-and[string]$structured.response.result.path-ceq$expectedRuntimePath){
            $resultRequested=$structured.result.PSObject.Properties['requested_properties'];$responseRequested=$structured.response.result.PSObject.Properties['requested_properties']
            if($ExpectedProperties.Count-eq0){if($null-ne$resultRequested-or$null-ne$responseRequested){return 'FOREIGN_ERROR'}}else{
                if($null-eq$resultRequested-or$null-eq$responseRequested){return 'FOREIGN_ERROR'}
                $resultNames=@($structured.result.requested_properties.PSObject.Properties.Name);$responseNames=@($structured.response.result.requested_properties.PSObject.Properties.Name)
                if($resultNames.Count-ne$ExpectedProperties.Count-or$responseNames.Count-ne$ExpectedProperties.Count-or
                    @(Compare-Object -ReferenceObject @($ExpectedProperties) -DifferenceObject $resultNames).Count-ne0-or
                    @(Compare-Object -ReferenceObject @($ExpectedProperties) -DifferenceObject $responseNames).Count-ne0){return 'FOREIGN_ERROR'}
            }
            return 'FOUND'
        }
        if((Test-Pr90FormalImmediateAutoGeneratedChildPathV1 -Path $ExpectedPath -StableParentPath $StableParentPath)-and
            [bool]$RawResponse.result.isError-and-not[bool]$structured.success-and-not[bool]$structured.response.success-and
            @(Compare-Object -ReferenceObject @('command','elapsed_msec','error','id','result','success','timestamp') -DifferenceObject @($structured.response.PSObject.Properties.Name)).Count-eq0-and
            $structured.error-is[string]-and$structured.response.error-is[string]-and[string]$structured.error-ceq'Runtime node not found.'-and[string]$structured.response.error-ceq'Runtime node not found.'-and
            @(Compare-Object -ReferenceObject @('found','error','node_path') -DifferenceObject @($structured.result.PSObject.Properties.Name)).Count-eq0-and
            @(Compare-Object -ReferenceObject @('found','error','node_path') -DifferenceObject @($structured.response.result.PSObject.Properties.Name)).Count-eq0-and
            $structured.result.found-is[bool]-and-not[bool]$structured.result.found-and$structured.response.result.found-is[bool]-and-not[bool]$structured.response.result.found-and
            $structured.result.error-is[string]-and$structured.response.result.error-is[string]-and$structured.result.node_path-is[string]-and$structured.response.result.node_path-is[string]-and
            [string]$structured.result.error-ceq'Runtime node not found.'-and[string]$structured.response.result.error-ceq'Runtime node not found.'-and
            [string]$structured.result.node_path-ceq$expectedRuntimePath-and[string]$structured.response.result.node_path-ceq$expectedRuntimePath){return 'EXACT_NOT_FOUND'}
        return 'FOREIGN_ERROR'
    }catch{return 'FOREIGN_ERROR'}
}

function Get-Pr90FormalCardCandidateV1 {
    param(
        [AllowNull()][object]$Tree,
        [ValidateSet('hand','track')][string]$Surface,
        [ValidateSet('military','facility')][string]$Domain,
        [bool]$TreeTruncated=$false
    )
    if($TreeTruncated-or$null-eq$Tree){return $null}
    $childrenValue=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $Tree -Name 'children'
    if(-not($childrenValue-is[Collections.IEnumerable])-or$childrenValue-is[string]){return $null}
    $expectedScript=if($Surface-ceq'track'){'res://scripts/ui/v074/v074_track_card_button.gd'}else{'res://scripts/ui/v073/v073_sample_card_button.gd'}
    $candidateMatches=[Collections.Generic.List[object]]::new();$directChildOrdinal=-1
    foreach($card in @($childrenValue)){
        $directChildOrdinal+=1
        if($null-eq$card-or[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $card -Name 'script_path')-cne$expectedScript){continue}
        $cardPath=[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $card -Name 'path')
        $cardName=[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $card -Name 'name')
        if($Surface-ceq'track'-and($cardName-cne'TrackCard_05'-or-not$cardPath.EndsWith('/TrackCard_05',[StringComparison]::Ordinal))){continue}
        $properties=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $card -Name 'properties'
        $visible=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $properties -Name 'visible'
        $size=ConvertTo-Pr90FormalTapCenterV1 (Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $properties -Name 'size')
        $position=ConvertTo-Pr90FormalTapCenterV1 (Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $properties -Name 'global_position')
        if($visible-isnot[bool]-or-not$visible-or$null-eq$size-or$null-eq$position-or[double]$size.x-le0-or[double]$size.y-le0){continue}
        $labelValues=[Collections.Generic.List[string]]::new();$labelShapeGreen=$true
        foreach($labelRow in @(Get-Pr90FormalUiTreeRowsV1 -Root $card|Where-Object{[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $_ -Name 'type')-ceq'Label'})){
            $labelProperties=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $labelRow -Name 'properties'
            $labelValue=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $labelProperties -Name 'text'
            if($labelValue-isnot[string]){$labelShapeGreen=$false;break}
            $labelValues.Add([string]$labelValue)
        }
        if(-not$labelShapeGreen-or$labelValues.Count-eq0){continue}
        $labelText=@($labelValues)-join' | '
        $semanticMatch=if($Domain-ceq'military'){
            if($Surface-ceq'track'){
                $labelText.Contains('军队',[StringComparison]::Ordinal)-and$labelText.Contains('NORMAL',[StringComparison]::Ordinal)-and$labelText.Contains('L1',[StringComparison]::Ordinal)-and$labelText.Contains('成本 2',[StringComparison]::Ordinal)-and$labelText.Contains('进入弃牌',[StringComparison]::Ordinal)
            }else{
                $labelText.Contains('军队',[StringComparison]::Ordinal)-and$labelText.Contains('STANDARD',[StringComparison]::Ordinal)-and$labelText.Contains('标准设施牌',[StringComparison]::Ordinal)-and$labelText.Contains('预绑定目标',[StringComparison]::Ordinal)
            }
        }else{$Surface-ceq'hand'-and($labelText.Contains('市场',[StringComparison]::Ordinal)-or$labelText.Contains('工厂',[StringComparison]::Ordinal))}
        if($semanticMatch){$candidateMatches.Add([pscustomobject][ordered]@{surface=$Surface;domain=$Domain;path=$cardPath;ui_text=$labelText;direct_child_ordinal=$directChildOrdinal;properties=$properties;center=[pscustomobject][ordered]@{x=([double]$position.x+[double]$size.x/2.0);y=([double]$position.y+[double]$size.y/2.0)}})}
    }
    if($Domain-ceq'military'-and$candidateMatches.Count-ne1){return $null}
    if($candidateMatches.Count-eq0){return $null}
    return $candidateMatches[0]
}

function Test-Pr90FormalMilitaryMissionUiTransitionV1 {
    param(
        [AllowNull()][object]$SurfaceBefore,
        [AllowNull()][object]$SurfaceAfter,
        [AllowNull()][object]$MilitaryPanelAfter,
        [AllowNull()][object]$OptionBefore,
        [AllowNull()][object]$OptionAfter,
        [AllowNull()][object]$TaskButtonAfter,
        [ValidateSet('assault_region','assault_monster')][string]$MissionKind,
        [bool]$SurfaceExpandPerformed
    )
    try{
        $surfacePath='V075GameScreen/RootMargin/Shell/V075CombatStackHost/V075CombatOverlay/Margin/Rows/SurfaceHost/CombatSurface'
        $panelPath="$surfacePath/Rows/PrivateGrid/MilitaryPanel"
        $suffix=if($MissionKind-ceq'assault_region'){'Region'}else{'Monster'}
        $optionPath="$surfacePath/Rows/PrivateGrid/MilitaryPanel/Margin/Rows/TargetMenus/Assault${suffix}Option"
        $buttonPath="$surfacePath/Rows/PrivateGrid/MilitaryPanel/Margin/Rows/TaskButtons/Assault${suffix}Button"
        foreach($pair in @(@($SurfaceBefore,$surfacePath,'Control'),@($SurfaceAfter,$surfacePath,'Control'),@($MilitaryPanelAfter,$panelPath,'Control'),@($OptionBefore,$optionPath,'OptionButton'),@($OptionAfter,$optionPath,'OptionButton'),@($TaskButtonAfter,$buttonPath,'Button'))){
            if($null-eq$pair[0]){return $false};$observedPath=[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $pair[0] -Name 'path');if($observedPath.StartsWith('/root/Main/',[StringComparison]::Ordinal)){$observedPath=$observedPath.Substring('/root/Main/'.Length)}
            if($observedPath-cne[string]$pair[1]){return $false}
            $type=[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $pair[0] -Name 'type')
            if([string]$pair[2]-ceq'Control'){
                if($type-cnotin@('Control','PanelContainer')){return $false}
            }elseif($type-cne[string]$pair[2]){return $false}
        }
        $surfaceBeforeProps=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $SurfaceBefore -Name 'properties'
        $surfaceAfterProps=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $SurfaceAfter -Name 'properties'
        $surfaceBeforeVisible=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $surfaceBeforeProps -Name 'visible'
        $surfaceAfterVisible=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $surfaceAfterProps -Name 'visible'
        if($surfaceBeforeVisible-isnot[bool]-or$surfaceAfterVisible-isnot[bool]-or-not$surfaceAfterVisible-or($SurfaceExpandPerformed-and$surfaceBeforeVisible)-or(-not$SurfaceExpandPerformed-and-not$surfaceBeforeVisible)){return $false}
        foreach($row in @($SurfaceAfter,$MilitaryPanelAfter,$OptionBefore,$OptionAfter,$TaskButtonAfter)){
            $properties=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $row -Name 'properties';$size=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $properties -Name 'size'
            if((Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $properties -Name 'visible')-isnot[bool]-or-not[bool](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $properties -Name 'visible')-or$null-eq$size-or[double](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $size -Name 'x')-le0-or[double](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $size -Name 'y')-le0){return $false}
        }
        $beforeRequested=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $OptionBefore -Name 'requested_properties'
        $afterRequested=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $OptionAfter -Name 'requested_properties'
        $buttonRequested=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $TaskButtonAfter -Name 'requested_properties'
        if((Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $beforeRequested -Name 'disabled')-isnot[bool]-or[bool](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $beforeRequested -Name 'disabled')){return $false}
        if([int](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $beforeRequested -Name 'item_count')-le0-or[int](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $beforeRequested -Name 'selected')-ne-1){return $false}
        if([bool](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $afterRequested -Name 'disabled')-or[int](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $afterRequested -Name 'item_count')-ne[int](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $beforeRequested -Name 'item_count')-or[int](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $afterRequested -Name 'selected')-lt0){return $false}
        if((Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $buttonRequested -Name 'disabled')-isnot[bool]-or[bool](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $buttonRequested -Name 'disabled')){return $false}
        return $true
    }catch{return $false}
}

function Test-Pr90FormalMcpEvidencePairV1 {
    param(
        [string]$RequestPath,[string]$RequestSha256,[string]$RawPath,[string]$RawSha256,
        [ValidateSet('query_runtime_node','send_runtime_input')][string]$ExpectedToolName,
        [string]$ExpectedRunId,
        [string]$ExpectedNodePath='',
        [string[]]$ExpectedEventTypes=@(),
        [string[]]$ExpectedMouseButtons=@(),
        [string[]]$ExpectedProperties=@(),
        [AllowNull()][Nullable[bool]]$ExpectedIncludeChildren=$null,
        [int]$ExpectedMaxDepth=0,
        [int]$ExpectedMaxNodes=0
    )
    try{
        if(-not(Test-Path -LiteralPath $RequestPath -PathType Leaf)-or-not(Test-Path -LiteralPath $RawPath -PathType Leaf)-or(Get-Pr90ProbeBSha256 $RequestPath)-cne$RequestSha256-or(Get-Pr90ProbeBSha256 $RawPath)-cne$RawSha256){return $false}
        $request=Get-Content -Raw -LiteralPath $RequestPath|ConvertFrom-Json -Depth 100 -DateKind String
        $raw=Get-Content -Raw -LiteralPath $RawPath|ConvertFrom-Json -Depth 100 -DateKind String
        if(@(Compare-Object -ReferenceObject @('schema','run_id','call_index','tool_name','arguments','timeout_seconds','canonical_payload_sha256') -DifferenceObject @($request.PSObject.Properties.Name)).Count-ne0-or$request.schema-isnot[string]-or[string]$request.schema-cne'SpaceSyndicateFormalMcpRequestV1'-or$request.run_id-isnot[string]-or[string]$request.run_id-cne$ExpectedRunId-or$request.tool_name-isnot[string]-or[string]$request.tool_name-cne$ExpectedToolName-or-not(Test-Pr90FormalJsonIntegerV1 -Value $request.call_index -Expected ([int64]$request.call_index))-or[int64]$request.call_index-le0-or$request.canonical_payload_sha256-isnot[string]-or[string]$request.canonical_payload_sha256-cne(Get-Pr90ProbeBCanonicalSha256 $request)-or-not(Test-Pr90FormalJsonObjectV1 -Value $request.arguments)){return $false}
        $requestLeaf=[IO.Path]::GetFileName($RequestPath)
        $rawLeaf=[IO.Path]::GetFileName($RawPath)
        $requestPattern='^(?<call>\d{4})-'+[regex]::Escape($ExpectedToolName)+'\.json$'
        $rawPattern='^(?<call>\d{4})-'+[regex]::Escape($ExpectedToolName)+'\.jsonrpc\.json$'
        if($requestLeaf-cnotmatch$requestPattern){return $false}
        $requestFileCall=[int]$Matches.call
        if($rawLeaf-cnotmatch$rawPattern){return $false}
        $rawFileCall=[int]$Matches.call
        if($requestFileCall-ne[int]$request.call_index-or$rawFileCall-ne[int]$request.call_index){return $false}
        if(-not(Test-Pr90FormalRawEnvelopeV1 -RawResponse $raw)-or[bool]$raw.result.isError-or$null-eq$raw.result.structuredContent.PSObject.Properties['success']-or$raw.result.structuredContent.success-isnot[bool]-or-not[bool]$raw.result.structuredContent.success-or-not(Test-Pr90FormalStructuredTextMirrorV1 -RawResponse $raw)){return $false}
        $structured=$raw.result.structuredContent;$expectedCommand=if($ExpectedToolName-ceq'query_runtime_node'){'query_node'}else{'send_input'}
        if(@(Compare-Object -ReferenceObject @('command','command_id','elapsed_msec','error','response','result','success') -DifferenceObject @($structured.PSObject.Properties.Name)).Count-ne0-or
            $structured.command-isnot[string]-or[string]$structured.command-cne$expectedCommand-or$structured.command_id-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$structured.command_id)-or$structured.error-isnot[string]-or[string]$structured.error-cne''-or-not(Test-Pr90FormalJsonNonnegativeNumberV1 -Value $structured.elapsed_msec)-or
            @(Compare-Object -ReferenceObject @('command','elapsed_msec','id','result','success','timestamp') -DifferenceObject @($structured.response.PSObject.Properties.Name)).Count-ne0-or
            $structured.response.command-isnot[string]-or[string]$structured.response.command-cne$expectedCommand-or$structured.response.id-isnot[string]-or[string]$structured.response.id-cne[string]$structured.command_id-or$structured.response.success-isnot[bool]-or-not[bool]$structured.response.success-or-not(Test-Pr90FormalJsonNonnegativeNumberV1 -Value $structured.response.elapsed_msec)-or$structured.response.timestamp-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$structured.response.timestamp)){return $false}
        if((ConvertTo-Pr90ProbeBCanonicalJson $structured.result)-cne(ConvertTo-Pr90ProbeBCanonicalJson $structured.response.result)){return $false}
        if($ExpectedToolName-ceq'query_runtime_node'){
            $expectedChildren=if($null-ne$ExpectedIncludeChildren){[bool]$ExpectedIncludeChildren}else{$ExpectedNodePath.EndsWith('Rail',[StringComparison]::Ordinal)}
            $expectedRuntimePath=if($ExpectedNodePath.StartsWith('/root/Main/',[StringComparison]::Ordinal)){$ExpectedNodePath}else{'/root/Main/'+$ExpectedNodePath}
            $expectedArgumentFields=if($expectedChildren){@('node_path','properties','include_children','max_depth','max_nodes','timeout_msec')}else{@('node_path','properties','include_children','timeout_msec')}
            if(@(Compare-Object -ReferenceObject $expectedArgumentFields -DifferenceObject @($request.arguments.PSObject.Properties.Name)).Count-ne0-or$request.arguments.node_path-isnot[string]-or[string]$request.arguments.node_path-cne$ExpectedNodePath-or$request.arguments.include_children-isnot[bool]-or[bool]$request.arguments.include_children-ne$expectedChildren-or-not(Test-Pr90FormalJsonIntegerV1 -Value $request.arguments.timeout_msec -Expected 30000)-or-not(Test-Pr90FormalJsonIntegerV1 -Value $request.timeout_seconds -Expected 45)-or
                -not(Test-Pr90FormalJsonStringArrayExactV1 -Value $request.arguments.properties -Expected $ExpectedProperties)){return $false}
            if($expectedChildren){
                if($ExpectedMaxDepth-le0){$ExpectedMaxDepth=if($ExpectedNodePath.EndsWith('/HandRail',[StringComparison]::Ordinal)){5}elseif($ExpectedNodePath.EndsWith('/TrackRail',[StringComparison]::Ordinal)){5}else{4}}
                if($ExpectedMaxNodes-le0){$ExpectedMaxNodes=if($ExpectedNodePath.EndsWith('/HandRail',[StringComparison]::Ordinal)){160}elseif($ExpectedNodePath.EndsWith('/TrackRail',[StringComparison]::Ordinal)){240}else{100}}
                if(-not(Test-Pr90FormalJsonIntegerV1 -Value $request.arguments.max_depth -Expected $ExpectedMaxDepth)-or-not(Test-Pr90FormalJsonIntegerV1 -Value $request.arguments.max_nodes -Expected $ExpectedMaxNodes)){return $false}
            }
            if(-not(Test-Pr90FormalFoundNodeResultShapeV1 -Result $structured.result -IncludeChildren $expectedChildren -ExpectedProperties $ExpectedProperties)-or-not(Test-Pr90FormalFoundNodeResultShapeV1 -Result $structured.response.result -IncludeChildren $expectedChildren -ExpectedProperties $ExpectedProperties)-or[string]$structured.result.path-cne$expectedRuntimePath-or[string]$structured.response.result.path-cne$expectedRuntimePath){return $false}
            $resultRequestedProperty=$structured.result.PSObject.Properties['requested_properties'];$responseRequestedProperty=$structured.response.result.PSObject.Properties['requested_properties']
            if($ExpectedProperties.Count-eq0){
                if($null-ne$resultRequestedProperty-or$null-ne$responseRequestedProperty){return $false}
            }else{
                if($null-eq$resultRequestedProperty-or$null-eq$responseRequestedProperty){return $false}
                $requestedPropertyNames=@($structured.result.requested_properties.PSObject.Properties.Name);$responseRequestedPropertyNames=@($structured.response.result.requested_properties.PSObject.Properties.Name)
                if($requestedPropertyNames.Count-ne$ExpectedProperties.Count-or$responseRequestedPropertyNames.Count-ne$ExpectedProperties.Count-or
                    @(Compare-Object -ReferenceObject @($ExpectedProperties) -DifferenceObject $requestedPropertyNames).Count-ne0-or
                    @(Compare-Object -ReferenceObject @($ExpectedProperties) -DifferenceObject $responseRequestedPropertyNames).Count-ne0){return $false}
            }
            if($expectedChildren-and($null-eq$structured.result.PSObject.Properties['tree_truncated']-or$structured.result.tree_truncated-isnot[bool]-or[bool]$structured.result.tree_truncated-or$null-eq$structured.result.PSObject.Properties['tree']-or$null-eq$structured.result.tree-or$null-eq$structured.response.result.PSObject.Properties['tree_truncated']-or$structured.response.result.tree_truncated-isnot[bool]-or[bool]$structured.response.result.tree_truncated-or$null-eq$structured.response.result.PSObject.Properties['tree']-or$null-eq$structured.response.result.tree)){return $false}
            if($expectedChildren){
                $treeRoot=$structured.result.tree
                $treeMetrics=Get-Pr90FormalTreeMetricsV1 -Tree $treeRoot -ExpectedMaxDepth $ExpectedMaxDepth
                if(-not[bool]$treeMetrics.green-or[int]$treeMetrics.node_count-gt$ExpectedMaxNodes-or[int]$treeMetrics.max_depth-gt$ExpectedMaxDepth){return $false}
                foreach($name in @('name','path','type','scene_file_path')){if([string]$structured.result.$name-cne[string]$treeRoot.$name){return $false}}
                if((ConvertTo-Pr90ProbeBCanonicalJson (ConvertTo-Pr90FormalSemanticJsonValueV1 $structured.result.properties))-cne(ConvertTo-Pr90ProbeBCanonicalJson (ConvertTo-Pr90FormalSemanticJsonValueV1 $treeRoot.properties))){return $false}
                foreach($optionalName in @('groups','script_path')){$outerProperty=$structured.result.PSObject.Properties[$optionalName];$treeProperty=$treeRoot.PSObject.Properties[$optionalName];if(($null-eq$outerProperty)-ne($null-eq$treeProperty)){return $false};if($null-ne$outerProperty-and(ConvertTo-Pr90ProbeBCanonicalJson (ConvertTo-Pr90FormalSemanticJsonValueV1 $outerProperty.Value))-cne(ConvertTo-Pr90ProbeBCanonicalJson (ConvertTo-Pr90FormalSemanticJsonValueV1 $treeProperty.Value))){return $false}}
            }
        }else{
            if(@(Compare-Object -ReferenceObject @('events','timeout_msec') -DifferenceObject @($request.arguments.PSObject.Properties.Name)).Count-ne0-or-not(Test-Pr90FormalJsonIntegerV1 -Value $request.arguments.timeout_msec -Expected 60000)-or-not(Test-Pr90FormalJsonIntegerV1 -Value $request.timeout_seconds -Expected 60)-or-not(Test-Pr90FormalJsonArrayV1 -Value $request.arguments.events)-or
                @(Compare-Object -ReferenceObject @('event_count','results') -DifferenceObject @($structured.result.PSObject.Properties.Name)).Count-ne0-or@(Compare-Object -ReferenceObject @('event_count','results') -DifferenceObject @($structured.response.result.PSObject.Properties.Name)).Count-ne0-or
                -not(Test-Pr90FormalJsonArrayV1 -Value $structured.result.results)-or-not(Test-Pr90FormalJsonArrayV1 -Value $structured.response.result.results)){return $false}
            $events=@($request.arguments.events);$results=@($structured.result.results);$responseResults=@($structured.response.result.results)
            if($events.Count-ne$ExpectedEventTypes.Count-or$results.Count-ne$events.Count-or$responseResults.Count-ne$events.Count-or-not(Test-Pr90FormalJsonIntegerV1 -Value $structured.result.event_count -Expected $events.Count)-or-not(Test-Pr90FormalJsonIntegerV1 -Value $structured.response.result.event_count -Expected $events.Count)){return $false}
            for($index=0;$index-lt$events.Count;$index+=1){
                if($events[$index]-isnot[pscustomobject]-and$events[$index]-isnot[Collections.IDictionary]){return $false}
                if($events[$index].type-isnot[string]-or[string]$events[$index].type-cne[string]$ExpectedEventTypes[$index]-or$results[$index].success-isnot[bool]-or-not[bool]$results[$index].success-or$responseResults[$index].success-isnot[bool]-or-not[bool]$responseResults[$index].success-or$results[$index].type-isnot[string]-or[string]$results[$index].type-cne[string]$ExpectedEventTypes[$index]-or$responseResults[$index].type-isnot[string]-or[string]$responseResults[$index].type-cne[string]$ExpectedEventTypes[$index]){return $false}
                if([string]$events[$index].type-ceq'mouse_button'){
                    $expectedButton=if($ExpectedMouseButtons.Count-eq$events.Count){[string]$ExpectedMouseButtons[$index]}else{'left'}
                    $expectedButtonIndex=switch($expectedButton){'left'{1}'wheel_up'{4}'wheel_down'{5}default{-1}}
                    if(@(Compare-Object -ReferenceObject @('button','mode','position','type') -DifferenceObject @($events[$index].PSObject.Properties.Name)).Count-ne0-or$events[$index].button-isnot[string]-or[string]$events[$index].button-cne$expectedButton-or$events[$index].mode-isnot[string]-or[string]$events[$index].mode-cne'tap'-or-not(Test-Pr90FormalJsonPointV1 -Point $events[$index].position)-or
                        @(Compare-Object -ReferenceObject @('button_index','mode','position','success','type') -DifferenceObject @($results[$index].PSObject.Properties.Name)).Count-ne0-or-not(Test-Pr90FormalJsonIntegerV1 -Value $results[$index].button_index -Expected $expectedButtonIndex)-or$results[$index].mode-isnot[string]-or[string]$results[$index].mode-cne'tap'-or-not(Test-Pr90FormalJsonPointV1 -Point $results[$index].position)-or
                        (ConvertTo-Pr90ProbeBCanonicalJson (ConvertTo-Pr90FormalSemanticJsonValueV1 $results[$index].position))-cne(ConvertTo-Pr90ProbeBCanonicalJson (ConvertTo-Pr90FormalSemanticJsonValueV1 $events[$index].position))){return $false}
                }
                if([string]$events[$index].type-ceq'action'){
                    $expectedAction=if($index-eq1-and$events.Count-eq3){'ui_down'}elseif($index-eq2-and$events.Count-eq3){'ui_accept'}else{''}
                    if(@(Compare-Object -ReferenceObject @('action','mode','type') -DifferenceObject @($events[$index].PSObject.Properties.Name)).Count-ne0-or[string]::IsNullOrWhiteSpace($expectedAction)-or$events[$index].action-isnot[string]-or[string]$events[$index].action-cne$expectedAction-or$events[$index].mode-isnot[string]-or[string]$events[$index].mode-cne'tap'-or
                        @(Compare-Object -ReferenceObject @('action','mode','strength','success','type') -DifferenceObject @($results[$index].PSObject.Properties.Name)).Count-ne0-or$results[$index].action-isnot[string]-or[string]$results[$index].action-cne$expectedAction-or$results[$index].mode-isnot[string]-or[string]$results[$index].mode-cne'tap'-or-not(Test-Pr90FormalJsonNonnegativeNumberV1 -Value $results[$index].strength)-or[double]$results[$index].strength-ne1.0){return $false}
                }
            }
        }
        return $true
    }catch{return $false}
}

function Get-Pr90FormalMcpEvidenceTypedV1 {
    param([string]$RequestPath,[string]$RawPath)
    $request=Get-Content -Raw -LiteralPath $RequestPath|ConvertFrom-Json -Depth 100 -DateKind String
    $raw=Get-Content -Raw -LiteralPath $RawPath|ConvertFrom-Json -Depth 100 -DateKind String
    $structured=$raw.result.structuredContent
    return [pscustomobject][ordered]@{request=$request;raw=$raw;structured=$structured;result=$structured.result;call_index=[int]$request.call_index;command_id=[string]$structured.command_id}
}

function Test-Pr90FormalDynamicResolutionBudgetV1 {
    param([AllowNull()][object]$Rows)
    if(-not(Test-Pr90FormalJsonArrayV1 -Value $Rows)){return $false}
    $items=@($Rows)
    if($items.Count-lt1-or$items.Count-gt21){return $false}
    $notFoundCount=0;$scrolledCount=0
    for($index=0;$index-lt$items.Count;$index+=1){
        $outcome=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $items[$index] -Name 'outcome'
        if($outcome-isnot[string]-or[string]$outcome-cnotin@('EXACT_TRANSIENT_NOT_FOUND','SCROLLED','FOUND_ACTIONABLE')){return $false}
        if([string]$outcome-ceq'EXACT_TRANSIENT_NOT_FOUND'){$notFoundCount+=1}
        if([string]$outcome-ceq'SCROLLED'){$scrolledCount+=1}
        if([string]$outcome-ceq'FOUND_ACTIONABLE'-and$index-ne($items.Count-1)){return $false}
    }
    return [string]$items[-1].outcome-ceq'FOUND_ACTIONABLE'-and$notFoundCount-le4-and$scrolledCount-le16
}

function Get-Pr90FormalDynamicResolutionLedgerValidationV1 {
    param(
        [AllowNull()][object]$Ledger,
        [string]$ExpectedRunId,
        [string]$StableParentPath,
        [int]$ExpectedTreeMaxDepth,
        [int]$ExpectedTreeMaxNodes,
        [string[]]$ExpectedLeafProperties=@(),
        [string]$ExpectedFinalPath,
        [string]$ExpectedSemanticText,
        [string]$ExpectedSemanticName='',
        [int]$ExpectedDirectChildOrdinal,
        [int]$ExpectedFinalViewportCallIndex,
        [int]$ExpectedFinalTreeCallIndex,
        [int]$ExpectedFinalNodeCallIndex,
        [AllowNull()][object]$ExpectedFinalEvidence,
        [bool]$RequireAutoGeneratedPath,
        [ValidateSet('hand','choice')][string]$SelectorKind,
        [ValidateSet('military','facility')][string]$CardDomain='facility',
        [string]$RequiredNamePattern='',
        [string]$RequiredTextPattern='',
        [switch]$RequireUniqueMatch
    )
    $intermediateRecords=[Collections.Generic.List[object]]::new();$notFoundCount=0;$scrollCount=0;$scrolledAttemptCount=0
    try{
        if(-not(Test-Pr90FormalDynamicResolutionBudgetV1 -Rows $Ledger)){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
        $rows=@($Ledger)
        if($rows.Count-lt1-or$rows.Count-gt21){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
        $fingerprint=$null;$previousLastCall=0;$previousScrollDecision=$null
        for($index=0;$index-lt$rows.Count;$index+=1){
            $row=$rows[$index];$isFinal=$index-eq($rows.Count-1);$candidatePath=[string]$row.candidate_path
            $commonRowFields=@('attempt_index','outcome','candidate_path','candidate_direct_child_ordinal','viewport_query_call_index','viewport_request_path','viewport_request_sha256','viewport_raw_path','viewport_raw_sha256','tree_query_call_index','tree_request_path','tree_request_sha256','tree_raw_path','tree_raw_sha256','node_query_call_index','node_request_path','node_request_sha256','node_raw_path','node_raw_sha256','scroll_input_call_index','scroll_direction','scroll_request_path','scroll_request_sha256','scroll_raw_path','scroll_raw_sha256')
            $semanticRowFields=if($SelectorKind-ceq'hand'){@('candidate_ui_text')}else{@('candidate_name','candidate_text')}
            if(@(Compare-Object -ReferenceObject @($commonRowFields+$semanticRowFields) -DifferenceObject @($row.PSObject.Properties.Name)).Count-ne0){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
            $semanticValue=if($SelectorKind-ceq'hand'){$row.candidate_ui_text}else{$row.candidate_text}
            $semanticNameValue=if($SelectorKind-ceq'choice'){$row.candidate_name}else{''}
            if($row.outcome-isnot[string]-or$semanticValue-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$semanticValue)-or($SelectorKind-ceq'choice'-and$semanticNameValue-isnot[string]) -or
                $row.candidate_path-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$row.candidate_path)-or
                -not(Test-Pr90FormalJsonIntegerV1 -Value $row.attempt_index -Expected ($index+1))-or-not(Test-Pr90FormalJsonIntegerV1 -Value $row.candidate_direct_child_ordinal -Expected ([int64]$row.candidate_direct_child_ordinal))-or[int64]$row.candidate_direct_child_ordinal-lt0-or
                -not(Test-Pr90FormalJsonIntegerV1 -Value $row.viewport_query_call_index -Expected ([int64]$row.viewport_query_call_index))-or[int64]$row.viewport_query_call_index-le0-or
                -not(Test-Pr90FormalJsonIntegerV1 -Value $row.tree_query_call_index -Expected ([int64]$row.tree_query_call_index))-or[int64]$row.tree_query_call_index-le0-or
                -not(Test-Pr90FormalJsonIntegerV1 -Value $row.node_query_call_index -Expected ([int64]$row.node_query_call_index))-or[int64]$row.node_query_call_index-le0-or
                -not(Test-Pr90FormalJsonIntegerV1 -Value $row.scroll_input_call_index -Expected ([int64]$row.scroll_input_call_index))-or[int64]$row.scroll_input_call_index-lt0){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
            foreach($stringField in @('viewport_request_path','viewport_request_sha256','viewport_raw_path','viewport_raw_sha256','tree_request_path','tree_request_sha256','tree_raw_path','tree_raw_sha256','node_request_path','node_request_sha256','node_raw_path','node_raw_sha256','scroll_direction','scroll_request_path','scroll_request_sha256','scroll_raw_path','scroll_raw_sha256')){if($row.$stringField-isnot[string]){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}}
            $semanticText=[string]$semanticValue;$semanticName=[string]$semanticNameValue
            if(-not(Test-Pr90FormalImmediateChildPathV1 -Path $candidatePath -StableParentPath $StableParentPath)-or
                ($RequireAutoGeneratedPath-and-not(Test-Pr90FormalImmediateAutoGeneratedChildPathV1 -Path $candidatePath -StableParentPath $StableParentPath))){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
            $currentFingerprint=[pscustomobject][ordered]@{semantic_text=$semanticText;semantic_name=if($RequireAutoGeneratedPath){''}else{$semanticName};direct_child_ordinal=[int]$row.candidate_direct_child_ordinal}
            if($null-eq$fingerprint){$fingerprint=$currentFingerprint}elseif((ConvertTo-Pr90ProbeBCanonicalJson $fingerprint)-cne(ConvertTo-Pr90ProbeBCanonicalJson $currentFingerprint)){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
            $viewportGreen=Test-Pr90FormalMcpEvidencePairV1 -RequestPath ([string]$row.viewport_request_path) -RequestSha256 ([string]$row.viewport_request_sha256) -RawPath ([string]$row.viewport_raw_path) -RawSha256 ([string]$row.viewport_raw_sha256) -ExpectedToolName query_runtime_node -ExpectedRunId $ExpectedRunId -ExpectedNodePath 'V075GameScreen/RootMargin' -ExpectedProperties @() -ExpectedIncludeChildren $false
            $treeGreen=Test-Pr90FormalMcpEvidencePairV1 -RequestPath ([string]$row.tree_request_path) -RequestSha256 ([string]$row.tree_request_sha256) -RawPath ([string]$row.tree_raw_path) -RawSha256 ([string]$row.tree_raw_sha256) -ExpectedToolName query_runtime_node -ExpectedRunId $ExpectedRunId -ExpectedNodePath $StableParentPath -ExpectedProperties @() -ExpectedIncludeChildren $true -ExpectedMaxDepth $ExpectedTreeMaxDepth -ExpectedMaxNodes $ExpectedTreeMaxNodes
            $viewportTyped=Get-Pr90FormalMcpEvidenceTypedV1 -RequestPath ([string]$row.viewport_request_path) -RawPath ([string]$row.viewport_raw_path)
            $treeTyped=Get-Pr90FormalMcpEvidenceTypedV1 -RequestPath ([string]$row.tree_request_path) -RawPath ([string]$row.tree_raw_path)
            if(-not$viewportGreen-or-not$treeGreen-or[int]$viewportTyped.call_index-ne[int]$row.viewport_query_call_index-or[int]$treeTyped.call_index-ne[int]$row.tree_query_call_index-or
                [string]::IsNullOrWhiteSpace([string]$viewportTyped.command_id)-or[string]::IsNullOrWhiteSpace([string]$treeTyped.command_id)-or
                ($index-gt0-and[int]$row.viewport_query_call_index-ne($previousLastCall+2))-or
                [int]$row.tree_query_call_index-ne([int]$row.viewport_query_call_index+1)-or[int]$row.node_query_call_index-ne([int]$row.tree_query_call_index+1)){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
            $derivedCandidate=if($SelectorKind-ceq'hand'){
                Get-Pr90FormalCardCandidateV1 -Tree $treeTyped.result.tree -Surface hand -Domain $CardDomain -TreeTruncated ([bool]$treeTyped.result.tree_truncated)
            }else{
                Get-Pr90FormalFirstChoiceTreeRowV1 -Tree $treeTyped.result.tree -RequiredNamePattern $RequiredNamePattern -RequiredTextPattern $RequiredTextPattern -RequireUniqueMatch:$RequireUniqueMatch
            }
            if($null-eq$derivedCandidate-or[string]$derivedCandidate.path-cne$candidatePath-or[int]$derivedCandidate.direct_child_ordinal-ne[int]$row.candidate_direct_child_ordinal){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
            if($SelectorKind-ceq'hand'){
                if([string]$derivedCandidate.ui_text-cne$semanticText){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
            }elseif([string]$derivedCandidate.properties.text-cne$semanticText-or[string]$derivedCandidate.name-cne$semanticName){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
            $nodeRequestPath=[string]$row.node_request_path;$nodeRawPath=[string]$row.node_raw_path
            if(-not(Test-Path -LiteralPath $nodeRequestPath -PathType Leaf)-or-not(Test-Path -LiteralPath $nodeRawPath -PathType Leaf)-or
                (Get-Pr90ProbeBSha256 $nodeRequestPath)-cne[string]$row.node_request_sha256-or(Get-Pr90ProbeBSha256 $nodeRawPath)-cne[string]$row.node_raw_sha256){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
            $nodeRequest=Get-Content -Raw -LiteralPath $nodeRequestPath|ConvertFrom-Json -Depth 100 -DateKind String
            $nodeRaw=Get-Content -Raw -LiteralPath $nodeRawPath|ConvertFrom-Json -Depth 100 -DateKind String
            $nodeRequestLeaf=[IO.Path]::GetFileName($nodeRequestPath);$nodeRawLeaf=[IO.Path]::GetFileName($nodeRawPath)
            if($nodeRequestLeaf-cnotmatch'^(?<call>\d{4})-query_runtime_node\.json$'){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
            $nodeRequestFileCall=[int]$Matches.call
            if($nodeRawLeaf-cnotmatch'^(?<call>\d{4})-query_runtime_node\.jsonrpc\.json$'){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
            $nodeRawFileCall=[int]$Matches.call
            if($nodeRequestFileCall-ne[int]$row.node_query_call_index-or$nodeRawFileCall-ne[int]$row.node_query_call_index-or[int]$nodeRequest.call_index-ne[int]$row.node_query_call_index){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
            $outcome=[string]$row.outcome;$nodeGreen=$false
            if($outcome-ceq'EXACT_TRANSIENT_NOT_FOUND'){
                $nodeGreen=(Get-Pr90FormalDynamicNodeQueryClassV1 -Request $nodeRequest -RawResponse $nodeRaw -ExpectedRunId $ExpectedRunId -ExpectedCallIndex ([int]$row.node_query_call_index) -ExpectedPath $candidatePath -StableParentPath $StableParentPath -ExpectedProperties @($ExpectedLeafProperties))-ceq'EXACT_NOT_FOUND'
                $notFoundCount+=1
                if($isFinal-or-not$RequireAutoGeneratedPath-or[int]$row.scroll_input_call_index-ne0-or-not[string]::IsNullOrEmpty([string]$row.scroll_direction)-or-not[string]::IsNullOrEmpty([string]$row.scroll_request_path)-or-not[string]::IsNullOrEmpty([string]$row.scroll_request_sha256)-or-not[string]::IsNullOrEmpty([string]$row.scroll_raw_path)-or-not[string]::IsNullOrEmpty([string]$row.scroll_raw_sha256)){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
            }else{
                $nodeGreen=Test-Pr90FormalMcpEvidencePairV1 -RequestPath ([string]$row.node_request_path) -RequestSha256 ([string]$row.node_request_sha256) -RawPath ([string]$row.node_raw_path) -RawSha256 ([string]$row.node_raw_sha256) -ExpectedToolName query_runtime_node -ExpectedRunId $ExpectedRunId -ExpectedNodePath $candidatePath -ExpectedProperties @($ExpectedLeafProperties) -ExpectedIncludeChildren $false
            }
            if(-not$nodeGreen){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
            $nodeEvidence=$null
            if($outcome-cne'EXACT_TRANSIENT_NOT_FOUND'){
                $nodeEvidence=Get-Pr90FormalMcpEvidenceTypedV1 -RequestPath $nodeRequestPath -RawPath $nodeRawPath
                if($SelectorKind-ceq'hand'){
                    if([string]$nodeEvidence.result.type-cne'PanelContainer'-or[string]$nodeEvidence.result.script_path-cne'res://scripts/ui/v073/v073_sample_card_button.gd'){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
                }else{
                    $disabled=Get-Pr90FormalRequestedValueV1 -Evidence $nodeEvidence -Name 'disabled'
                    if([string]$nodeEvidence.result.type-cne'Button'-or[string]$nodeEvidence.result.name-cne[string]$derivedCandidate.name-or$nodeEvidence.result.properties.text-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$nodeEvidence.result.properties.text)-or[string]$nodeEvidence.result.properties.text-cne[string]$derivedCandidate.properties.text-or$disabled-isnot[bool]-or[bool]$disabled){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
                }
            }
            $lastCall=[int]$row.node_query_call_index
            if($outcome-ceq'SCROLLED'){
                $scrolledAttemptCount+=1;if($scrolledAttemptCount-gt16){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
                if($isFinal-or[string]$row.scroll_direction-cnotin@('wheel_up','wheel_down')-or[int]$row.scroll_input_call_index-ne($lastCall+1)-or[string]::IsNullOrWhiteSpace([string]$row.scroll_request_path)-or[string]::IsNullOrWhiteSpace([string]$row.scroll_request_sha256)-or[string]::IsNullOrWhiteSpace([string]$row.scroll_raw_path)-or[string]::IsNullOrWhiteSpace([string]$row.scroll_raw_sha256)){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
                $buttons=@([string]$row.scroll_direction,[string]$row.scroll_direction,[string]$row.scroll_direction,[string]$row.scroll_direction)
                if(-not(Test-Pr90FormalMcpEvidencePairV1 -RequestPath ([string]$row.scroll_request_path) -RequestSha256 ([string]$row.scroll_request_sha256) -RawPath ([string]$row.scroll_raw_path) -RawSha256 ([string]$row.scroll_raw_sha256) -ExpectedToolName send_runtime_input -ExpectedRunId $ExpectedRunId -ExpectedEventTypes @('mouse_button','mouse_button','mouse_button','mouse_button') -ExpectedMouseButtons $buttons)){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
                $scrollTyped=Get-Pr90FormalMcpEvidenceTypedV1 -RequestPath ([string]$row.scroll_request_path) -RawPath ([string]$row.scroll_raw_path)
                if([int]$scrollTyped.call_index-ne[int]$row.scroll_input_call_index-or[string]::IsNullOrWhiteSpace([string]$scrollTyped.command_id)){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
                $decision=Get-Pr90FormalTapViewportDecisionV1 -Center (Get-Pr90FormalNodeCenterV1 -Node $nodeEvidence.result) -ViewportNode $viewportTyped.result
                $viewportProperties=$viewportTyped.result.properties;$viewportPosition=$viewportProperties.global_position;$viewportSize=$viewportProperties.size
                $scrollAnchor=[pscustomobject][ordered]@{x=([double]$viewportPosition.x+[double]$viewportSize.x-8.0);y=([double]$viewportPosition.y+[double]$viewportSize.y/2.0)}
                if(-not(Test-Pr90FormalTapCenterInScreenV1 -Center $scrollAnchor)){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
                foreach($event in @($scrollTyped.request.arguments.events)){if(-not(Test-Pr90FormalPointExactV1 -Observed $event.position -Expected $scrollAnchor)){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}}
                if([string]$decision.classification-cne'VERTICAL_OUT_OF_BOUNDS'-or[string]$decision.direction-cne[string]$row.scroll_direction-or($null-ne$previousScrollDecision-and-not(Test-Pr90FormalTapViewportProgressV1 -Before $previousScrollDecision -After $decision))){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
                $previousScrollDecision=$decision
                $scrollCount+=4;$lastCall=[int]$row.scroll_input_call_index
            }elseif($outcome-ceq'FOUND_ACTIONABLE'){
                if(-not$isFinal-or[int]$row.scroll_input_call_index-ne0-or-not[string]::IsNullOrEmpty([string]$row.scroll_direction)-or-not[string]::IsNullOrEmpty([string]$row.scroll_request_path)-or-not[string]::IsNullOrEmpty([string]$row.scroll_request_sha256)-or-not[string]::IsNullOrEmpty([string]$row.scroll_raw_path)-or-not[string]::IsNullOrEmpty([string]$row.scroll_raw_sha256)-or$candidatePath-cne$ExpectedFinalPath-or$semanticText-cne$ExpectedSemanticText-or$semanticName-cne$ExpectedSemanticName-or[int]$row.candidate_direct_child_ordinal-ne$ExpectedDirectChildOrdinal-or
                    [int]$row.viewport_query_call_index-ne$ExpectedFinalViewportCallIndex-or[int]$row.tree_query_call_index-ne$ExpectedFinalTreeCallIndex-or[int]$row.node_query_call_index-ne$ExpectedFinalNodeCallIndex){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
                if($null-eq$ExpectedFinalEvidence-or@(Compare-Object -ReferenceObject @('viewport','tree','node') -DifferenceObject @($ExpectedFinalEvidence.PSObject.Properties.Name)).Count-ne0){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
                foreach($binding in @(@('viewport','viewport'),@('tree','tree'),@('node','node'))){
                    $expected=$ExpectedFinalEvidence.([string]$binding[0]);$prefix=[string]$binding[1]
                    if($null-eq$expected-or@(Compare-Object -ReferenceObject @('call_index','request_path','request_sha256','raw_path','raw_sha256') -DifferenceObject @($expected.PSObject.Properties.Name)).Count-ne0-or
                        -not(Test-Pr90FormalJsonIntegerV1 -Value $expected.call_index -Expected ([int64]$row.($prefix+'_query_call_index')))-or
                        $expected.request_path-isnot[string]-or[string]$expected.request_path-cne[string]$row.($prefix+'_request_path')-or$expected.request_sha256-isnot[string]-or[string]$expected.request_sha256-cne[string]$row.($prefix+'_request_sha256')-or
                        $expected.raw_path-isnot[string]-or[string]$expected.raw_path-cne[string]$row.($prefix+'_raw_path')-or$expected.raw_sha256-isnot[string]-or[string]$expected.raw_sha256-cne[string]$row.($prefix+'_raw_sha256')){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
                }
                if($null-eq(Get-Pr90FormalRootActionCenterV1 -Node $nodeEvidence.result -ViewportNode $viewportTyped.result)){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
            }elseif($outcome-cne'EXACT_TRANSIENT_NOT_FOUND'){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
            if(-not$isFinal){
                foreach($record in @(
                    [pscustomobject]@{call_index=[int]$row.viewport_query_call_index;request_path=[string]$row.viewport_request_path;raw_path=[string]$row.viewport_raw_path},
                    [pscustomobject]@{call_index=[int]$row.tree_query_call_index;request_path=[string]$row.tree_request_path;raw_path=[string]$row.tree_raw_path},
                    [pscustomobject]@{call_index=[int]$row.node_query_call_index;request_path=[string]$row.node_request_path;raw_path=[string]$row.node_raw_path}
                )){$intermediateRecords.Add($record)}
                if($outcome-ceq'SCROLLED'){$intermediateRecords.Add([pscustomobject]@{call_index=[int]$row.scroll_input_call_index;request_path=[string]$row.scroll_request_path;raw_path=[string]$row.scroll_raw_path})}
            }
            $previousLastCall=$lastCall
        }
        if($notFoundCount-gt4-or$scrolledAttemptCount-gt16-or$scrollCount-ne($scrolledAttemptCount*4)){return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
        return [pscustomobject]@{green=$true;intermediate_records=@($intermediateRecords);transient_not_found_count=$notFoundCount;scroll_count=$scrollCount;first_call_index=[int]$rows[0].viewport_query_call_index;final_call_index=[int]$rows[-1].node_query_call_index}
    }catch{return [pscustomobject]@{green=$false;intermediate_records=@();transient_not_found_count=0;scroll_count=0}}
}

function Test-Pr90FormalPointExactV1 {
    param([AllowNull()][object]$Observed,[AllowNull()][object]$Expected)
    try{$observedCenter=ConvertTo-Pr90FormalTapCenterV1 $Observed;$expectedCenter=ConvertTo-Pr90FormalTapCenterV1 $Expected;return $null-ne$observedCenter-and$null-ne$expectedCenter-and[double]$observedCenter.x-eq[double]$expectedCenter.x-and[double]$observedCenter.y-eq[double]$expectedCenter.y}catch{return $false}
}

function Get-Pr90FormalNodeCenterV1 {
    param([AllowNull()][object]$Node)
    try{
        $properties=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $Node -Name 'properties';$position=ConvertTo-Pr90FormalTapCenterV1 (Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $properties -Name 'global_position');$size=ConvertTo-Pr90FormalTapCenterV1 (Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $properties -Name 'size')
        if($null-eq$position-or$null-eq$size-or[double]$size.x-le0-or[double]$size.y-le0){return $null}
        return [pscustomobject][ordered]@{x=([double]$position.x+[double]$size.x/2.0);y=([double]$position.y+[double]$size.y/2.0)}
    }catch{return $null}
}

function Test-Pr90FormalSendCenterV1 {
    param([AllowNull()][object]$SendEvidence,[AllowNull()][object]$SourceNode)
    try{
        $events=@($SendEvidence.request.arguments.events);$center=Get-Pr90FormalNodeCenterV1 -Node $SourceNode
        return $events.Count-gt0-and[string]$events[0].type-ceq'mouse_button'-and(Test-Pr90FormalTapCenterInScreenV1 -Center $center)-and(Test-Pr90FormalPointExactV1 -Observed $events[0].position -Expected $center)
    }catch{return $false}
}

function Get-Pr90FormalChoiceTreeRowV1 {
    param([AllowNull()][object]$Tree,[string]$ExpectedPath,[string]$RequiredNamePattern='')
    foreach($row in @(Get-Pr90FormalUiTreeRowsV1 -Root $Tree)){
        if([string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $row -Name 'path')-cne$ExpectedPath-or[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $row -Name 'type')-cne'Button'){continue}
        if(-not[string]::IsNullOrWhiteSpace($RequiredNamePattern)-and[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $row -Name 'name')-cnotmatch$RequiredNamePattern){return $null}
        $properties=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $row -Name 'properties'
        if((Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $properties -Name 'visible')-isnot[bool]-or-not[bool](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $properties -Name 'visible')-or$null-eq(Get-Pr90FormalNodeCenterV1 -Node $row)){return $null}
        return $row
    }
    return $null
}

function Get-Pr90FormalFirstChoiceTreeRowV1 {
    param([AllowNull()][object]$Tree,[string]$RequiredNamePattern='',[string]$RequiredTextPattern='',[switch]$RequireUniqueMatch)
    $candidateRows=[Collections.Generic.List[object]]::new()
    $children=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $Tree -Name 'children'
    if(-not($children-is[Collections.IEnumerable])-or$children-is[string]){return $null}
    for($ordinal=0;$ordinal-lt@($children).Count;$ordinal+=1){
        $row=@($children)[$ordinal]
        if([string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $row -Name 'type')-cne'Button'){continue}
        if(-not[string]::IsNullOrWhiteSpace($RequiredNamePattern)-and[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $row -Name 'name')-cnotmatch$RequiredNamePattern){continue}
        $properties=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $row -Name 'properties'
        $textValue=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $properties -Name 'text'
        if($textValue-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$textValue)){continue}
        if(-not[string]::IsNullOrWhiteSpace($RequiredTextPattern)-and[string]$textValue-cnotmatch$RequiredTextPattern){continue}
        if((Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $properties -Name 'visible')-isnot[bool]-or-not[bool](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $properties -Name 'visible')-or$null-eq(Get-Pr90FormalNodeCenterV1 -Node $row)){continue}
        $copy=[pscustomobject][ordered]@{name=[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $row -Name 'name');path=[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $row -Name 'path');type=[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $row -Name 'type');script_path=[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $row -Name 'script_path');properties=$properties;direct_child_ordinal=$ordinal}
        $candidateRows.Add($copy)
    }
    if($candidateRows.Count-eq0-or($RequireUniqueMatch-and$candidateRows.Count-ne1)){return $null}
    return $candidateRows[0]
}

function Get-Pr90FormalRequestedValueV1 {
    param([AllowNull()][object]$Evidence,[string]$Name)
    $requested=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $Evidence.result -Name 'requested_properties'
    return Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $requested -Name $Name
}

function Test-Pr90FormalAcceptanceCountersV1 {
    param([AllowNull()][object]$Acceptance,[AllowNull()][object]$WitnessStep,[switch]$After)
    try{
        $suffix=if($After){'after'}else{'before'}
        return [int]$Acceptance.interaction_counts.card_selected-eq[int](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $WitnessStep -Name ('card_selected_'+$suffix))-and
            [int]$Acceptance.interaction_counts.target_bound-eq[int](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $WitnessStep -Name ('target_bound_'+$suffix))-and
            [int]$Acceptance.queue_count-eq[int](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $WitnessStep -Name ('queue_'+$suffix))-and
            [int]$Acceptance.invalid_action_count-eq[int](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $WitnessStep -Name ('invalid_action_'+$suffix))
    }catch{return $false}
}

function Get-Pr90FormalCombatPresentationGateV1 {
    param(
        [AllowNull()][object]$BeforeAcceptance,
        [AllowNull()][object]$AfterAcceptance,
        [AllowNull()][object]$ScenarioWitness
    )
    $classification='FORMAL_COMBAT_EVIDENCE_INVALID'
    $sourceCount=0;$presentationCount=0;$mapCueCount=0;$surfaceCueCount=0;$mapHistoryCount=0;$surfaceHistoryCount=0
    try{
        $surfacePath='V075GameScreen/RootMargin/Shell/V075CombatStackHost/V075CombatOverlay/Margin/Rows/SurfaceHost/CombatSurface'
        $evidenceDescriptors=@(
            @('seed','query_runtime_node',[string]$ScenarioWitness.seed_input_path,@(),@('text'),$false),@('baseline','query_runtime_node','V075GameScreen',@(),@('acceptance_state'),$false),
            @('pre_acquire_hand','query_runtime_node','V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/HandScroll/HandRail',@(),@(),$true),@('track_viewport','query_runtime_node','V075GameScreen/RootMargin',@(),@(),$false),@('track','query_runtime_node','V075GameScreen/RootMargin/Shell/TrackPanel/TrackMargin/TrackRows/TrackScroll/TrackRail',@(),@(),$true),@('track_payload','query_runtime_node',[string]$ScenarioWitness.acquired_card_node_path,@(),@('_payload'),$false),@('acquire','send_runtime_input','',@('mouse_button'),@(),$null),@('acquire_acceptance','query_runtime_node','V075GameScreen',@(),@('acceptance_state'),$false),
            @('hand_viewport','query_runtime_node','V075GameScreen/RootMargin',@(),@(),$false),@('hand','query_runtime_node','V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/HandScroll/HandRail',@(),@(),$true),@('hand_payload','query_runtime_node',[string]$ScenarioWitness.staged_card_node_path,@(),@('_payload'),$false),@('card','send_runtime_input','',@('mouse_button'),@(),$null),@('card_acceptance','query_runtime_node','V075GameScreen',@(),@('acceptance_state'),$false),
            @('surface_initial_query','query_runtime_node',$surfacePath,@(),@(),$false),@('surface_ready_query','query_runtime_node',$surfacePath,@(),@(),$false),
            @('mission_panel_query','query_runtime_node',[string]$ScenarioWitness.mission_panel_path,@(),@(),$false),@('mission_option_query','query_runtime_node',[string]$ScenarioWitness.mission_option_path,@(),@('disabled','item_count','selected'),$false),@('mission_option','send_runtime_input','',@('mouse_button','action','action'),@(),$null),@('mission_option_result_query','query_runtime_node',[string]$ScenarioWitness.mission_option_path,@(),@('disabled','item_count','selected'),$false),
            @('mission_query','query_runtime_node',[string]$ScenarioWitness.mission_button_path,@(),@('disabled'),$false),@('mission','send_runtime_input','',@('mouse_button'),@(),$null),@('acceptance','query_runtime_node','V075GameScreen',@(),@('acceptance_state'),$false)
        )
        if([bool](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $ScenarioWitness -Name 'combat_surface_expand_performed')){$evidenceDescriptors+=,@('surface_expand','send_runtime_input','',@('mouse_button'),@(),$null)}
        $witnessHashesGreen=$true;$witnessEvidencePaths=[Collections.Generic.List[string]]::new();$witnessCallIndices=[Collections.Generic.List[int]]::new();$witnessCommandIds=[Collections.Generic.List[string]]::new();$evidenceByPrefix=@{};$dynamicIntermediatePairCount=0
        foreach($descriptor in $evidenceDescriptors){
            $prefix=[string]$descriptor[0];$requestPath=[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $ScenarioWitness -Name ($prefix+'_request_path'));$requestSha=[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $ScenarioWitness -Name ($prefix+'_request_sha256'));$rawPath=[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $ScenarioWitness -Name ($prefix+'_raw_path'));$rawSha=[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $ScenarioWitness -Name ($prefix+'_raw_sha256'))
            if(-not(Test-Pr90FormalMcpEvidencePairV1 -RequestPath $requestPath -RequestSha256 $requestSha -RawPath $rawPath -RawSha256 $rawSha -ExpectedToolName ([string]$descriptor[1]) -ExpectedRunId ([string]$ScenarioWitness.run_id) -ExpectedNodePath ([string]$descriptor[2]) -ExpectedEventTypes @($descriptor[3]) -ExpectedProperties @($descriptor[4]) -ExpectedIncludeChildren $descriptor[5])){$witnessHashesGreen=$false;break}
            $typedEvidence=Get-Pr90FormalMcpEvidenceTypedV1 -RequestPath $requestPath -RawPath $rawPath;$evidenceByPrefix[$prefix]=$typedEvidence;$witnessCallIndices.Add([int]$typedEvidence.call_index);$witnessCommandIds.Add([string]$typedEvidence.command_id)
            $witnessEvidencePaths.Add([IO.Path]::GetFullPath($requestPath));$witnessEvidencePaths.Add([IO.Path]::GetFullPath($rawPath))
        }
        $preAcquireHandGreen=$false
        try{
            $preAcquireResult=$evidenceByPrefix.pre_acquire_hand.result;$preAcquireTree=$preAcquireResult.tree
            $preAcquireHandGreen=($null-ne$preAcquireResult.PSObject.Properties['tree_truncated']-and$preAcquireResult.tree_truncated-is[bool]-and-not[bool]$preAcquireResult.tree_truncated-and$null-ne$preAcquireTree-and$null-eq(Get-Pr90FormalCardCandidateV1 -Tree $preAcquireTree -Surface hand -Domain military -TreeTruncated $false))
        }catch{$preAcquireHandGreen=$false}
        $mainEvidenceSemanticsGreen=$false;$baselineAcceptance=$null;$acquireAcceptance=$null;$cardAcceptance=$null;$missionAcceptance=$null;$trackCandidate=$null;$handCandidate=$null;$trackPrivatePayload=$null;$handPrivatePayload=$null;$handLedgerValidation=$null
        try{
            $baselineAcceptance=Get-Pr90FormalRequestedValueV1 -Evidence $evidenceByPrefix.baseline -Name 'acceptance_state'
            $acquireAcceptance=Get-Pr90FormalRequestedValueV1 -Evidence $evidenceByPrefix.acquire_acceptance -Name 'acceptance_state'
            $cardAcceptance=Get-Pr90FormalRequestedValueV1 -Evidence $evidenceByPrefix.card_acceptance -Name 'acceptance_state'
            $missionAcceptance=Get-Pr90FormalRequestedValueV1 -Evidence $evidenceByPrefix.acceptance -Name 'acceptance_state'
            $trackCandidate=Get-Pr90FormalCardCandidateV1 -Tree $evidenceByPrefix.track.result.tree -Surface track -Domain military -TreeTruncated ([bool]$evidenceByPrefix.track.result.tree_truncated)
            $handCandidate=Get-Pr90FormalCardCandidateV1 -Tree $evidenceByPrefix.hand.result.tree -Surface hand -Domain military -TreeTruncated ([bool]$evidenceByPrefix.hand.result.tree_truncated)
            $trackPrivatePayload=Get-Pr90FormalRequestedValueV1 -Evidence $evidenceByPrefix.track_payload -Name '_payload'
            $handPrivatePayload=Get-Pr90FormalRequestedValueV1 -Evidence $evidenceByPrefix.hand_payload -Name '_payload'
            $trackRow=@(Get-Pr90FormalUiTreeRowsV1 -Root $evidenceByPrefix.track.result.tree|Where-Object{[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $_ -Name 'path')-ceq[string]$ScenarioWitness.acquired_card_node_path})|Select-Object -First 1
            $handRow=@(Get-Pr90FormalUiTreeRowsV1 -Root $evidenceByPrefix.hand.result.tree|Where-Object{[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $_ -Name 'path')-ceq[string]$ScenarioWitness.staged_card_node_path})|Select-Object -First 1
            $handFinalEvidence=[pscustomobject][ordered]@{
                viewport=[pscustomobject][ordered]@{call_index=$evidenceByPrefix.hand_viewport.call_index;request_path=$ScenarioWitness.hand_viewport_request_path;request_sha256=$ScenarioWitness.hand_viewport_request_sha256;raw_path=$ScenarioWitness.hand_viewport_raw_path;raw_sha256=$ScenarioWitness.hand_viewport_raw_sha256}
                tree=[pscustomobject][ordered]@{call_index=$evidenceByPrefix.hand.call_index;request_path=$ScenarioWitness.hand_request_path;request_sha256=$ScenarioWitness.hand_request_sha256;raw_path=$ScenarioWitness.hand_raw_path;raw_sha256=$ScenarioWitness.hand_raw_sha256}
                node=[pscustomobject][ordered]@{call_index=$evidenceByPrefix.hand_payload.call_index;request_path=$ScenarioWitness.hand_payload_request_path;request_sha256=$ScenarioWitness.hand_payload_request_sha256;raw_path=$ScenarioWitness.hand_payload_raw_path;raw_sha256=$ScenarioWitness.hand_payload_raw_sha256}
            }
            $handLedgerValidation=Get-Pr90FormalDynamicResolutionLedgerValidationV1 -Ledger @($ScenarioWitness.hand_resolution_attempts) -ExpectedRunId ([string]$ScenarioWitness.run_id) -StableParentPath 'V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/HandScroll/HandRail' -ExpectedTreeMaxDepth 5 -ExpectedTreeMaxNodes 160 -ExpectedLeafProperties @('_payload') -ExpectedFinalPath ([string]$ScenarioWitness.staged_card_node_path) -ExpectedSemanticText ([string]$ScenarioWitness.staged_card_ui_text) -ExpectedDirectChildOrdinal ([int]$handCandidate.direct_child_ordinal) -ExpectedFinalViewportCallIndex ([int]$evidenceByPrefix.hand_viewport.call_index) -ExpectedFinalTreeCallIndex ([int]$evidenceByPrefix.hand.call_index) -ExpectedFinalNodeCallIndex ([int]$evidenceByPrefix.hand_payload.call_index) -ExpectedFinalEvidence $handFinalEvidence -RequireAutoGeneratedPath $true -SelectorKind hand -CardDomain military
            if(-not[bool]$handLedgerValidation.green-or
                -not(Test-Pr90FormalJsonIntegerV1 -Value $ScenarioWitness.hand_transient_not_found_count -Expected ([int64]$handLedgerValidation.transient_not_found_count))-or
                -not(Test-Pr90FormalJsonIntegerV1 -Value $ScenarioWitness.hand_scroll_count -Expected ([int64]$handLedgerValidation.scroll_count))){throw 'Formal dynamic military hand resolution ledger mismatch.'}
            foreach($record in @($handLedgerValidation.intermediate_records)){$typed=Get-Pr90FormalMcpEvidenceTypedV1 -RequestPath ([string]$record.request_path) -RawPath ([string]$record.raw_path);$witnessCallIndices.Add([int]$typed.call_index);$witnessCommandIds.Add([string]$typed.command_id);$witnessEvidencePaths.Add([IO.Path]::GetFullPath([string]$record.request_path));$witnessEvidencePaths.Add([IO.Path]::GetFullPath([string]$record.raw_path));$dynamicIntermediatePairCount+=1}
            $missionTransition=Test-Pr90FormalMilitaryMissionUiTransitionV1 -SurfaceBefore $evidenceByPrefix.surface_initial_query.result -SurfaceAfter $evidenceByPrefix.surface_ready_query.result -MilitaryPanelAfter $evidenceByPrefix.mission_panel_query.result -OptionBefore $evidenceByPrefix.mission_option_query.result -OptionAfter $evidenceByPrefix.mission_option_result_query.result -TaskButtonAfter $evidenceByPrefix.mission_query.result -MissionKind ([string]$ScenarioWitness.mission_kind) -SurfaceExpandPerformed ([bool]$ScenarioWitness.combat_surface_expand_performed)
            $mainChronologyGreen=([int]$evidenceByPrefix.seed.call_index-lt[int]$evidenceByPrefix.baseline.call_index-and[int]$evidenceByPrefix.baseline.call_index-lt[int]$evidenceByPrefix.pre_acquire_hand.call_index-and[int]$evidenceByPrefix.pre_acquire_hand.call_index-lt[int]$evidenceByPrefix.track_viewport.call_index-and
                [int]$evidenceByPrefix.track_viewport.call_index-lt[int]$evidenceByPrefix.track.call_index-and[int]$evidenceByPrefix.track.call_index-lt[int]$evidenceByPrefix.track_payload.call_index-and[int]$evidenceByPrefix.track_payload.call_index-lt[int]$evidenceByPrefix.acquire.call_index-and[int]$evidenceByPrefix.acquire.call_index-lt[int]$evidenceByPrefix.acquire_acceptance.call_index-and
                [int]$evidenceByPrefix.hand_viewport.call_index-lt[int]$evidenceByPrefix.hand.call_index-and[int]$evidenceByPrefix.hand.call_index-lt[int]$evidenceByPrefix.hand_payload.call_index-and[int]$evidenceByPrefix.card.call_index-eq([int]$evidenceByPrefix.hand_payload.call_index+1)-and[int]$evidenceByPrefix.card.call_index-lt[int]$evidenceByPrefix.card_acceptance.call_index-and
                [int]$evidenceByPrefix.card_acceptance.call_index-lt[int]$evidenceByPrefix.surface_initial_query.call_index-and[int]$evidenceByPrefix.surface_initial_query.call_index-lt[int]$evidenceByPrefix.surface_ready_query.call_index-and
                [int]$evidenceByPrefix.surface_ready_query.call_index-lt[int]$evidenceByPrefix.mission_panel_query.call_index-and[int]$evidenceByPrefix.mission_panel_query.call_index-lt[int]$evidenceByPrefix.mission_option_query.call_index-and[int]$evidenceByPrefix.mission_option_query.call_index-lt[int]$evidenceByPrefix.mission_option.call_index-and
                [int]$evidenceByPrefix.mission_option.call_index-lt[int]$evidenceByPrefix.mission_option_result_query.call_index-and[int]$evidenceByPrefix.mission_option_result_query.call_index-lt[int]$evidenceByPrefix.mission_query.call_index-and[int]$evidenceByPrefix.mission_query.call_index-lt[int]$evidenceByPrefix.mission.call_index-and[int]$evidenceByPrefix.mission.call_index-lt[int]$evidenceByPrefix.acceptance.call_index)
            if([bool](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $ScenarioWitness -Name 'combat_surface_expand_performed')){$mainChronologyGreen=$mainChronologyGreen-and[int]$evidenceByPrefix.surface_initial_query.call_index-lt[int]$evidenceByPrefix.surface_expand.call_index-and[int]$evidenceByPrefix.surface_expand.call_index-lt[int]$evidenceByPrefix.surface_ready_query.call_index}
            $mainEvidenceSemanticsGreen=($mainChronologyGreen-and
                [int]$evidenceByPrefix.hand_viewport.call_index-lt[int]$evidenceByPrefix.hand.call_index-and[int]$evidenceByPrefix.hand.call_index-lt[int]$evidenceByPrefix.hand_payload.call_index-and[int]$evidenceByPrefix.hand_payload.call_index-lt[int]$evidenceByPrefix.card.call_index-and[int]$evidenceByPrefix.card.call_index-lt[int]$evidenceByPrefix.card_acceptance.call_index-and
                [string](Get-Pr90FormalRequestedValueV1 -Evidence $evidenceByPrefix.seed -Name 'text')-ceq[string]$ScenarioWitness.seed_input_value-and[string]$ScenarioWitness.seed_input_value-ceq'900626424'-and[int64]$ScenarioWitness.deterministic_match_seed-eq900626424-and[string]$ScenarioWitness.card_definition_registry_sha256-ceq'0a06f99a7ed010595865ed7d1c339fe15516586891e60c2c912729a745d92932'-and
                (ConvertTo-Pr90ProbeBCanonicalJson $baselineAcceptance.combat_wrapper)-ceq(ConvertTo-Pr90ProbeBCanonicalJson $BeforeAcceptance.combat_wrapper)-and
                $null-ne$trackCandidate-and$null-ne$trackRow-and[string]$trackCandidate.path-ceq[string]$ScenarioWitness.acquired_card_node_path-and[string]$trackCandidate.ui_text-ceq[string]$ScenarioWitness.acquired_card_ui_text-and
                [string]$evidenceByPrefix.track_payload.result.name-ceq[string]$trackRow.name-and[string]$evidenceByPrefix.track_payload.result.type-ceq'PanelContainer'-and[string]$evidenceByPrefix.track_payload.result.type-ceq[string]$trackRow.type-and[string]$evidenceByPrefix.track_payload.result.script_path-ceq'res://scripts/ui/v074/v074_track_card_button.gd'-and[string]$evidenceByPrefix.track_payload.result.script_path-ceq[string]$trackRow.script_path-and
                (ConvertTo-Pr90ProbeBCanonicalJson (ConvertTo-Pr90FormalSemanticJsonValueV1 $evidenceByPrefix.track_payload.result.properties))-ceq(ConvertTo-Pr90ProbeBCanonicalJson (ConvertTo-Pr90FormalSemanticJsonValueV1 $trackRow.properties))-and
                (Get-Pr90FormalTapViewportDecisionV1 -Center $trackCandidate.center -ViewportNode $evidenceByPrefix.track_viewport.result).green-and(Test-Pr90FormalTapCenterInScreenV1 -Center $trackCandidate.center)-and(Test-Pr90FormalSendCenterV1 -SendEvidence $evidenceByPrefix.acquire -SourceNode $trackRow)-and
                $null-ne$trackPrivatePayload-and[string]$trackPrivatePayload.instance_id-ceq[string]$ScenarioWitness.acquired_card_instance_id-and[string]$ScenarioWitness.acquired_card_instance_id-ceq'track.card.00000005'-and[string]$trackPrivatePayload.card_definition_id-ceq[string]$ScenarioWitness.acquired_card_definition_id-and[string]$ScenarioWitness.acquired_card_definition_id-ceq'military.submarine_fleet.life.rank_1'-and
                [string]$trackPrivatePayload.card_kind-ceq'normal_card'-and[int]$trackPrivatePayload.level-eq1-and[string]$trackPrivatePayload.primary_color-ceq[string]$ScenarioWitness.acquired_card_primary_color-and[string]$ScenarioWitness.acquired_card_primary_color-ceq'life'-and[int]$trackPrivatePayload.local_slot_index-eq5-and$trackPrivatePayload.claimable-is[bool]-and[bool]$trackPrivatePayload.claimable-and[string]$trackPrivatePayload.claimability_state-ceq'claimable'-and[string]$trackPrivatePayload.origin_class-ceq[string]$ScenarioWitness.acquired_card_origin_class-and[string]$ScenarioWitness.acquired_card_origin_class-ceq'standard'-and[string]$trackPrivatePayload.asset_cost_profile-ceq[string]$ScenarioWitness.acquired_card_asset_cost_profile-and[string]$ScenarioWitness.acquired_card_asset_cost_profile-ceq'v075_military_track_color_rank_1'-and[int]$trackPrivatePayload.track_revision-eq[int]$ScenarioWitness.acquired_card_track_revision-and[int]$ScenarioWitness.acquired_card_track_revision-eq4-and[int]$trackPrivatePayload.claimable_from_scroll_sequence-eq[int]$ScenarioWitness.acquired_card_claimable_from_scroll_sequence-and[int]$ScenarioWitness.acquired_card_claimable_from_scroll_sequence-eq0-and[int]$trackPrivatePayload.primary_asset_cost-eq[int]$ScenarioWitness.acquired_card_primary_asset_cost-and[int]$ScenarioWitness.acquired_card_primary_asset_cost-eq2-and$trackPrivatePayload.starter_badge-is[bool]-and-not[bool]$trackPrivatePayload.starter_badge-and
                [int]$baselineAcceptance.interaction_counts.track_acquired-eq[int]$ScenarioWitness.track_acquired_before-and[int]$acquireAcceptance.interaction_counts.track_acquired-eq[int]$ScenarioWitness.track_acquired_after-and
                ([int]$acquireAcceptance.interaction_counts.track_acquired-[int]$baselineAcceptance.interaction_counts.track_acquired)-eq[int]$ScenarioWitness.track_acquired_delta-and
                ([int]$acquireAcceptance.track_player_projection_visible_card_count-[int]$baselineAcceptance.track_player_projection_visible_card_count)-eq[int]$ScenarioWitness.track_visible_card_delta-and
                ([int]$acquireAcceptance.track_current_real_card_count-[int]$baselineAcceptance.track_current_real_card_count)-eq[int]$ScenarioWitness.track_real_card_delta-and
                ([int]$acquireAcceptance.track_vacancy_slot_count-[int]$baselineAcceptance.track_vacancy_slot_count)-eq[int]$ScenarioWitness.track_vacancy_delta-and
                $null-ne$handCandidate-and(Test-Pr90FormalImmediateAutoGeneratedChildPathV1 -Path ([string]$handCandidate.path) -StableParentPath 'V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/HandScroll/HandRail')-and[string]$handCandidate.path-ceq[string]$ScenarioWitness.staged_card_node_path-and[string]$handCandidate.ui_text-ceq[string]$ScenarioWitness.staged_card_ui_text-and
                [string]$evidenceByPrefix.hand_payload.result.type-ceq'PanelContainer'-and[string]$evidenceByPrefix.hand_payload.result.script_path-ceq'res://scripts/ui/v073/v073_sample_card_button.gd'-and
                $null-ne(Get-Pr90FormalRootActionCenterV1 -Node $evidenceByPrefix.hand_payload.result -ViewportNode $evidenceByPrefix.hand_viewport.result)-and(Test-Pr90FormalSendCenterV1 -SendEvidence $evidenceByPrefix.card -SourceNode $evidenceByPrefix.hand_payload.result)-and
                $null-ne$handPrivatePayload-and[string]$handPrivatePayload.definition_id-ceq[string]$ScenarioWitness.staged_card_definition_id-and[string]$handPrivatePayload.card_definition_id-ceq[string]$handPrivatePayload.definition_id-and[string]$ScenarioWitness.staged_card_definition_id-ceq[string]$ScenarioWitness.acquired_card_definition_id-and[string]$handPrivatePayload.instance_id-ceq[string]$ScenarioWitness.staged_card_instance_id-and[string]$handPrivatePayload.card_instance_id-ceq[string]$handPrivatePayload.instance_id-and-not[string]::IsNullOrWhiteSpace([string]$ScenarioWitness.staged_card_instance_id)-and[string]$ScenarioWitness.staged_card_instance_id-cne[string]$ScenarioWitness.acquired_card_instance_id-and[string]$handPrivatePayload.origin_class-ceq[string]$ScenarioWitness.staged_card_origin_class-and[string]$ScenarioWitness.staged_card_origin_class-ceq'standard'-and[string]$handPrivatePayload.primary_color-ceq[string]$ScenarioWitness.staged_card_primary_color-and[string]$ScenarioWitness.staged_card_primary_color-ceq'life'-and[string]$handPrivatePayload.asset_cost_profile-ceq[string]$ScenarioWitness.staged_card_asset_cost_profile-and[string]$ScenarioWitness.staged_card_asset_cost_profile-ceq[string]$ScenarioWitness.acquired_card_asset_cost_profile-and[string]$ScenarioWitness.staged_card_asset_cost_profile-ceq'v075_military_track_color_rank_1'-and[int]$handPrivatePayload.level-eq[int]$ScenarioWitness.staged_card_level-and[int]$ScenarioWitness.staged_card_level-eq1-and[int]$handPrivatePayload.primary_asset_cost-eq[int]$ScenarioWitness.staged_card_primary_asset_cost-and[int]$ScenarioWitness.staged_card_primary_asset_cost-eq2-and$handPrivatePayload.starter_badge-is[bool]-and[bool]$ScenarioWitness.staged_card_starter_badge-eq[bool]$handPrivatePayload.starter_badge-and-not[bool]$ScenarioWitness.staged_card_starter_badge-and
                [int]$cardAcceptance.interaction_counts.card_selected-eq[int]$ScenarioWitness.card_selected_after-and
                $missionTransition-and[int](Get-Pr90FormalRequestedValueV1 -Evidence $evidenceByPrefix.mission_option_query -Name 'item_count')-eq[int]$ScenarioWitness.mission_option_item_count-and
                [int](Get-Pr90FormalRequestedValueV1 -Evidence $evidenceByPrefix.mission_option_query -Name 'selected')-eq[int]$ScenarioWitness.mission_option_selected_before-and
                [int](Get-Pr90FormalRequestedValueV1 -Evidence $evidenceByPrefix.mission_option_result_query -Name 'selected')-eq[int]$ScenarioWitness.mission_option_selected_after-and
                (Test-Pr90FormalSendCenterV1 -SendEvidence $evidenceByPrefix.mission_option -SourceNode $evidenceByPrefix.mission_option_query.result)-and
                (Test-Pr90FormalSendCenterV1 -SendEvidence $evidenceByPrefix.mission -SourceNode $evidenceByPrefix.mission_query.result)-and
                [int]$cardAcceptance.combat_wrapper.military_intent_count-eq[int]$ScenarioWitness.military_intent_before-and[int]$missionAcceptance.combat_wrapper.military_intent_count-eq[int]$ScenarioWitness.military_intent_after-and
                ([int]$missionAcceptance.combat_wrapper.military_intent_count-[int]$cardAcceptance.combat_wrapper.military_intent_count)-eq[int]$ScenarioWitness.military_intent_delta)
        }catch{$mainEvidenceSemanticsGreen=$false}
        $facilityBatchTransitions=@($ScenarioWitness.facility_batch_transitions);$facilityBatchTransitionsGreen=($facilityBatchTransitions.Count-eq2);$transitionEvidenceByNextBatch=@{}
        for($transitionIndex=0;$transitionIndex-lt$facilityBatchTransitions.Count-and$facilityBatchTransitionsGreen;$transitionIndex+=1){
            $transition=$facilityBatchTransitions[$transitionIndex]
            try{
                if([int]$transition.transition_index-ne($transitionIndex+1)-or[int]$transition.prior_batch_index-ne$transitionIndex-or[int]$transition.next_batch_index-ne($transitionIndex+1)-or
                    [int]$transition.card_selected_count-ne(($transitionIndex+1)*5)-or[int]$transition.target_bound_count-ne(($transitionIndex+1)*5)-or[int]$transition.queue_count-ne0-or[int]$transition.invalid_action_count-ne0){$facilityBatchTransitionsGreen=$false;break}
                $transitionRequestPath=[string]$transition.acceptance_request_path;$transitionRequestSha=[string]$transition.acceptance_request_sha256;$transitionRawPath=[string]$transition.acceptance_raw_path;$transitionRawSha=[string]$transition.acceptance_raw_sha256
                if(-not(Test-Pr90FormalMcpEvidencePairV1 -RequestPath $transitionRequestPath -RequestSha256 $transitionRequestSha -RawPath $transitionRawPath -RawSha256 $transitionRawSha -ExpectedToolName query_runtime_node -ExpectedRunId ([string]$ScenarioWitness.run_id) -ExpectedNodePath 'V075GameScreen' -ExpectedProperties @('acceptance_state') -ExpectedIncludeChildren $false)){$facilityBatchTransitionsGreen=$false;break}
                $transitionEvidence=Get-Pr90FormalMcpEvidenceTypedV1 -RequestPath $transitionRequestPath -RawPath $transitionRawPath;$transitionAcceptance=Get-Pr90FormalRequestedValueV1 -Evidence $transitionEvidence -Name 'acceptance_state'
                if([int]$transitionAcceptance.interaction_counts.card_selected-ne[int]$transition.card_selected_count-or[int]$transitionAcceptance.interaction_counts.target_bound-ne[int]$transition.target_bound_count-or[int]$transitionAcceptance.queue_count-ne0-or[int]$transitionAcceptance.invalid_action_count-ne0){$facilityBatchTransitionsGreen=$false;break}
                $transitionEvidenceByNextBatch[[int]$transition.next_batch_index]=$transitionEvidence;$witnessCallIndices.Add([int]$transitionEvidence.call_index);$witnessCommandIds.Add([string]$transitionEvidence.command_id)
                $witnessEvidencePaths.Add([IO.Path]::GetFullPath($transitionRequestPath));$witnessEvidencePaths.Add([IO.Path]::GetFullPath($transitionRawPath))
            }catch{$facilityBatchTransitionsGreen=$false;break}
        }
        $facilitySteps=@($ScenarioWitness.facility_advance_steps);$facilityStepsGreen=($facilitySteps.Count-eq15-and$facilityBatchTransitionsGreen);$facilityChronologyGreen=$true;$previousFacilityAcceptanceCall=0
        $handRailPath='V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/HandScroll/HandRail'
        $targetOpenerTreePath='V075GameScreen/RootMargin/Shell/TargetPanel/TargetMargin/TargetRow/TargetScroll/TargetRail'
        $targetTreePath='V075GameScreen/PlaytestUtilityLayer/PlaytestSafeArea/V074TargetRailFloat/V074VirtualizedTargetRail/RailRows/Body/TargetScroll/VirtualContent/Rows'
        for($stepIndex=0;$stepIndex-lt$facilitySteps.Count-and$facilityStepsGreen;$stepIndex+=1){
            $step=$facilitySteps[$stepIndex]
            if([int]$step.step_index-ne($stepIndex+1)-or[int]$step.batch_index-ne[Math]::Floor($stepIndex/5)-or[int]$step.action_slot-ne($stepIndex%5)-or
                [string]$step.card_node_path-cnotlike'*/HandRail/*'-or[string]$step.card_ui_text-cnotlike'*设施*'-or[string]$step.target_opener_path-cnotlike'*/TargetRail/*'-or[string]$step.target_opener_text-cnotlike'目标列表 · *'-or[string]$step.target_node_path-cnotmatch'/VirtualTargetRow\d{2}$'-or
                [int]$step.card_selected_after-ne([int]$step.card_selected_before+1)-or[int]$step.target_bound_after-ne([int]$step.target_bound_before+1)-or[int]$step.queue_after-ne([int]$step.queue_before+1)-or[int]$step.invalid_action_after-ne[int]$step.invalid_action_before){$facilityStepsGreen=$false;break}
            $stepDescriptors=@(
                @('facility_hand_viewport_query','query_runtime_node','V075GameScreen/RootMargin',@(),@(),$false),@('facility_hand_query','query_runtime_node',$handRailPath,@(),@(),$true),@('facility_hand_node_query','query_runtime_node',[string]$step.card_node_path,@(),@(),$false),@('facility_card','send_runtime_input','',@('mouse_button'),@(),$null),
                @('target_opener_viewport_query','query_runtime_node','V075GameScreen/RootMargin',@(),@(),$false),@('target_opener_tree_query','query_runtime_node',$targetOpenerTreePath,@(),@(),$true),@('target_opener_node_query','query_runtime_node',[string]$step.target_opener_path,@(),@('disabled'),$false),@('target_opener','send_runtime_input','',@('mouse_button'),@(),$null),
                @('target_viewport_query','query_runtime_node','V075GameScreen/RootMargin',@(),@(),$false),@('target_tree_query','query_runtime_node',$targetTreePath,@(),@(),$true),@('target_node_query','query_runtime_node',[string]$step.target_node_path,@(),@('disabled'),$false),@('target','send_runtime_input','',@('mouse_button'),@(),$null),
                @('acceptance','query_runtime_node','V075GameScreen',@(),@('acceptance_state'),$false)
            )
            $stepEvidence=@{}
            foreach($descriptor in $stepDescriptors){
                $prefix=[string]$descriptor[0];$requestPath=[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $step -Name ($prefix+'_request_path'));$requestSha=[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $step -Name ($prefix+'_request_sha256'));$rawPath=[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $step -Name ($prefix+'_raw_path'));$rawSha=[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $step -Name ($prefix+'_raw_sha256'))
                if(-not(Test-Pr90FormalMcpEvidencePairV1 -RequestPath $requestPath -RequestSha256 $requestSha -RawPath $rawPath -RawSha256 $rawSha -ExpectedToolName ([string]$descriptor[1]) -ExpectedRunId ([string]$ScenarioWitness.run_id) -ExpectedNodePath ([string]$descriptor[2]) -ExpectedEventTypes @($descriptor[3]) -ExpectedProperties @($descriptor[4]) -ExpectedIncludeChildren $descriptor[5])){$facilityStepsGreen=$false;break}
                $typedEvidence=Get-Pr90FormalMcpEvidenceTypedV1 -RequestPath $requestPath -RawPath $rawPath;$stepEvidence[$prefix]=$typedEvidence;$witnessCallIndices.Add([int]$typedEvidence.call_index);$witnessCommandIds.Add([string]$typedEvidence.command_id)
                $witnessEvidencePaths.Add([IO.Path]::GetFullPath($requestPath));$witnessEvidencePaths.Add([IO.Path]::GetFullPath($rawPath))
            }
            if(-not$facilityStepsGreen){break}
            try{
                $facilityCandidate=Get-Pr90FormalCardCandidateV1 -Tree $stepEvidence.facility_hand_query.result.tree -Surface hand -Domain facility -TreeTruncated ([bool]$stepEvidence.facility_hand_query.result.tree_truncated)
                $facilityRow=@(Get-Pr90FormalUiTreeRowsV1 -Root $stepEvidence.facility_hand_query.result.tree|Where-Object{[string](Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $_ -Name 'path')-ceq[string]$step.card_node_path})|Select-Object -First 1
                $openerRow=Get-Pr90FormalFirstChoiceTreeRowV1 -Tree $stepEvidence.target_opener_tree_query.result.tree -RequiredTextPattern '^目标列表 · \d+$' -RequireUniqueMatch
                $targetRow=Get-Pr90FormalFirstChoiceTreeRowV1 -Tree $stepEvidence.target_tree_query.result.tree -RequiredNamePattern '^VirtualTargetRow\d{2}$'
                $acceptanceAfter=Get-Pr90FormalRequestedValueV1 -Evidence $stepEvidence.acceptance -Name 'acceptance_state'
                $acceptanceBefore=if($stepIndex-eq0){$acquireAcceptance}elseif([int]$step.action_slot-eq0){Get-Pr90FormalRequestedValueV1 -Evidence $transitionEvidenceByNextBatch[[int]$step.batch_index] -Name 'acceptance_state'}else{Get-Pr90FormalRequestedValueV1 -Evidence $previousFacilityAcceptanceEvidence -Name 'acceptance_state'}
                $facilityFinalEvidence=[pscustomobject][ordered]@{
                    viewport=[pscustomobject][ordered]@{call_index=$stepEvidence.facility_hand_viewport_query.call_index;request_path=$step.facility_hand_viewport_query_request_path;request_sha256=$step.facility_hand_viewport_query_request_sha256;raw_path=$step.facility_hand_viewport_query_raw_path;raw_sha256=$step.facility_hand_viewport_query_raw_sha256}
                    tree=[pscustomobject][ordered]@{call_index=$stepEvidence.facility_hand_query.call_index;request_path=$step.facility_hand_query_request_path;request_sha256=$step.facility_hand_query_request_sha256;raw_path=$step.facility_hand_query_raw_path;raw_sha256=$step.facility_hand_query_raw_sha256}
                    node=[pscustomobject][ordered]@{call_index=$stepEvidence.facility_hand_node_query.call_index;request_path=$step.facility_hand_node_query_request_path;request_sha256=$step.facility_hand_node_query_request_sha256;raw_path=$step.facility_hand_node_query_raw_path;raw_sha256=$step.facility_hand_node_query_raw_sha256}
                }
                $openerFinalEvidence=[pscustomobject][ordered]@{
                    viewport=[pscustomobject][ordered]@{call_index=$stepEvidence.target_opener_viewport_query.call_index;request_path=$step.target_opener_viewport_query_request_path;request_sha256=$step.target_opener_viewport_query_request_sha256;raw_path=$step.target_opener_viewport_query_raw_path;raw_sha256=$step.target_opener_viewport_query_raw_sha256}
                    tree=[pscustomobject][ordered]@{call_index=$stepEvidence.target_opener_tree_query.call_index;request_path=$step.target_opener_tree_query_request_path;request_sha256=$step.target_opener_tree_query_request_sha256;raw_path=$step.target_opener_tree_query_raw_path;raw_sha256=$step.target_opener_tree_query_raw_sha256}
                    node=[pscustomobject][ordered]@{call_index=$stepEvidence.target_opener_node_query.call_index;request_path=$step.target_opener_node_query_request_path;request_sha256=$step.target_opener_node_query_request_sha256;raw_path=$step.target_opener_node_query_raw_path;raw_sha256=$step.target_opener_node_query_raw_sha256}
                }
                $targetFinalEvidence=[pscustomobject][ordered]@{
                    viewport=[pscustomobject][ordered]@{call_index=$stepEvidence.target_viewport_query.call_index;request_path=$step.target_viewport_query_request_path;request_sha256=$step.target_viewport_query_request_sha256;raw_path=$step.target_viewport_query_raw_path;raw_sha256=$step.target_viewport_query_raw_sha256}
                    tree=[pscustomobject][ordered]@{call_index=$stepEvidence.target_tree_query.call_index;request_path=$step.target_tree_query_request_path;request_sha256=$step.target_tree_query_request_sha256;raw_path=$step.target_tree_query_raw_path;raw_sha256=$step.target_tree_query_raw_sha256}
                    node=[pscustomobject][ordered]@{call_index=$stepEvidence.target_node_query.call_index;request_path=$step.target_node_query_request_path;request_sha256=$step.target_node_query_request_sha256;raw_path=$step.target_node_query_raw_path;raw_sha256=$step.target_node_query_raw_sha256}
                }
                $facilityLedger=Get-Pr90FormalDynamicResolutionLedgerValidationV1 -Ledger @($step.facility_hand_resolution_attempts) -ExpectedRunId ([string]$ScenarioWitness.run_id) -StableParentPath $handRailPath -ExpectedTreeMaxDepth 5 -ExpectedTreeMaxNodes 160 -ExpectedLeafProperties @() -ExpectedFinalPath ([string]$step.card_node_path) -ExpectedSemanticText ([string]$step.card_ui_text) -ExpectedDirectChildOrdinal ([int]$facilityCandidate.direct_child_ordinal) -ExpectedFinalViewportCallIndex ([int]$stepEvidence.facility_hand_viewport_query.call_index) -ExpectedFinalTreeCallIndex ([int]$stepEvidence.facility_hand_query.call_index) -ExpectedFinalNodeCallIndex ([int]$stepEvidence.facility_hand_node_query.call_index) -ExpectedFinalEvidence $facilityFinalEvidence -RequireAutoGeneratedPath $true -SelectorKind hand -CardDomain facility
                $openerLedger=Get-Pr90FormalDynamicResolutionLedgerValidationV1 -Ledger @($step.target_opener_resolution_attempts) -ExpectedRunId ([string]$ScenarioWitness.run_id) -StableParentPath $targetOpenerTreePath -ExpectedTreeMaxDepth 4 -ExpectedTreeMaxNodes 100 -ExpectedLeafProperties @('disabled') -ExpectedFinalPath ([string]$step.target_opener_path) -ExpectedSemanticText ([string]$step.target_opener_text) -ExpectedSemanticName ([string]$openerRow.name) -ExpectedDirectChildOrdinal ([int]$openerRow.direct_child_ordinal) -ExpectedFinalViewportCallIndex ([int]$stepEvidence.target_opener_viewport_query.call_index) -ExpectedFinalTreeCallIndex ([int]$stepEvidence.target_opener_tree_query.call_index) -ExpectedFinalNodeCallIndex ([int]$stepEvidence.target_opener_node_query.call_index) -ExpectedFinalEvidence $openerFinalEvidence -RequireAutoGeneratedPath $true -SelectorKind choice -RequiredTextPattern '^目标列表 · \d+$' -RequireUniqueMatch
                $targetLedger=Get-Pr90FormalDynamicResolutionLedgerValidationV1 -Ledger @($step.target_resolution_attempts) -ExpectedRunId ([string]$ScenarioWitness.run_id) -StableParentPath $targetTreePath -ExpectedTreeMaxDepth 4 -ExpectedTreeMaxNodes 100 -ExpectedLeafProperties @('disabled') -ExpectedFinalPath ([string]$step.target_node_path) -ExpectedSemanticText ([string]$step.target_ui_text) -ExpectedSemanticName ([string]$targetRow.name) -ExpectedDirectChildOrdinal ([int]$targetRow.direct_child_ordinal) -ExpectedFinalViewportCallIndex ([int]$stepEvidence.target_viewport_query.call_index) -ExpectedFinalTreeCallIndex ([int]$stepEvidence.target_tree_query.call_index) -ExpectedFinalNodeCallIndex ([int]$stepEvidence.target_node_query.call_index) -ExpectedFinalEvidence $targetFinalEvidence -RequireAutoGeneratedPath $false -SelectorKind choice -RequiredNamePattern '^VirtualTargetRow\d{2}$'
                foreach($ledgerResult in @($facilityLedger,$openerLedger,$targetLedger)){if(-not[bool]$ledgerResult.green){$facilityStepsGreen=$false;break};foreach($record in @($ledgerResult.intermediate_records)){$typed=Get-Pr90FormalMcpEvidenceTypedV1 -RequestPath ([string]$record.request_path) -RawPath ([string]$record.raw_path);$witnessCallIndices.Add([int]$typed.call_index);$witnessCommandIds.Add([string]$typed.command_id);$witnessEvidencePaths.Add([IO.Path]::GetFullPath([string]$record.request_path));$witnessEvidencePaths.Add([IO.Path]::GetFullPath([string]$record.raw_path));$dynamicIntermediatePairCount+=1}}
                if(-not$facilityStepsGreen){break}
                $firstStepCall=[int]$facilityLedger.first_call_index;$lastStepCall=[int]$stepEvidence.acceptance.call_index
                if($stepIndex-eq0){$facilityChronologyGreen=[int]$evidenceByPrefix.acquire_acceptance.call_index-lt$firstStepCall}elseif([int]$step.action_slot-eq0){$transitionCall=[int]$transitionEvidenceByNextBatch[[int]$step.batch_index].call_index;$facilityChronologyGreen=$previousFacilityAcceptanceCall-lt$transitionCall-and$transitionCall-lt$firstStepCall}else{$facilityChronologyGreen=$previousFacilityAcceptanceCall-lt$firstStepCall}
                $facilityChronologyGreen=$facilityChronologyGreen-and[int]$stepEvidence.facility_card.call_index-eq([int]$facilityLedger.final_call_index+1)-and[int]$openerLedger.first_call_index-eq([int]$stepEvidence.facility_card.call_index+2)-and[int]$stepEvidence.target_opener.call_index-eq([int]$openerLedger.final_call_index+1)-and[int]$targetLedger.first_call_index-eq([int]$stepEvidence.target_opener.call_index+2)-and[int]$stepEvidence.target.call_index-eq([int]$targetLedger.final_call_index+1)-and$lastStepCall-eq([int]$stepEvidence.target.call_index+2)
                if(-not$facilityChronologyGreen){$facilityStepsGreen=$false;break}
                $facilitySemanticsGreen=($null-ne$facilityCandidate-and(Test-Pr90FormalImmediateAutoGeneratedChildPathV1 -Path ([string]$facilityCandidate.path) -StableParentPath $handRailPath)-and[string]$facilityCandidate.path-ceq[string]$step.card_node_path-and[string]$facilityCandidate.ui_text-ceq[string]$step.card_ui_text-and
                    $null-ne$openerRow-and(Test-Pr90FormalImmediateAutoGeneratedChildPathV1 -Path ([string]$openerRow.path) -StableParentPath $targetOpenerTreePath)-and[string]$openerRow.path-ceq[string]$step.target_opener_path-and[string]$openerRow.properties.text-ceq[string]$step.target_opener_text-and
                    $null-ne$targetRow-and(Test-Pr90FormalImmediateChildPathV1 -Path ([string]$targetRow.path) -StableParentPath $targetTreePath)-and[string]$targetRow.path-ceq[string]$step.target_node_path-and[string]$targetRow.properties.text-ceq[string]$step.target_ui_text-and
                    [bool]$facilityLedger.green-and[bool]$openerLedger.green-and[bool]$targetLedger.green-and
                    (Test-Pr90FormalJsonIntegerV1 -Value $step.facility_hand_transient_not_found_count -Expected ([int64]$facilityLedger.transient_not_found_count))-and(Test-Pr90FormalJsonIntegerV1 -Value $step.target_opener_transient_not_found_count -Expected ([int64]$openerLedger.transient_not_found_count))-and(Test-Pr90FormalJsonIntegerV1 -Value $step.target_transient_not_found_count -Expected ([int64]$targetLedger.transient_not_found_count))-and
                    [int]$stepEvidence.facility_hand_viewport_query.call_index-lt[int]$stepEvidence.facility_hand_query.call_index-and[int]$stepEvidence.facility_hand_query.call_index-lt[int]$stepEvidence.facility_hand_node_query.call_index-and[int]$stepEvidence.facility_hand_node_query.call_index-lt[int]$stepEvidence.facility_card.call_index-and[int]$stepEvidence.facility_card.call_index-lt[int]$stepEvidence.target_opener_viewport_query.call_index-and
                    [int]$stepEvidence.target_opener_viewport_query.call_index-lt[int]$stepEvidence.target_opener_tree_query.call_index-and[int]$stepEvidence.target_opener_tree_query.call_index-lt[int]$stepEvidence.target_opener_node_query.call_index-and[int]$stepEvidence.target_opener_node_query.call_index-lt[int]$stepEvidence.target_opener.call_index-and[int]$stepEvidence.target_opener.call_index-lt[int]$stepEvidence.target_viewport_query.call_index-and
                    [int]$stepEvidence.target_viewport_query.call_index-lt[int]$stepEvidence.target_tree_query.call_index-and[int]$stepEvidence.target_tree_query.call_index-lt[int]$stepEvidence.target_node_query.call_index-and[int]$stepEvidence.target_node_query.call_index-lt[int]$stepEvidence.target.call_index-and[int]$stepEvidence.target.call_index-lt[int]$stepEvidence.acceptance.call_index-and
                    [string]$stepEvidence.facility_hand_node_query.result.type-ceq'PanelContainer'-and[string]$stepEvidence.facility_hand_node_query.result.script_path-ceq'res://scripts/ui/v073/v073_sample_card_button.gd'-and[string]$stepEvidence.target_opener_node_query.result.type-ceq'Button'-and[string]$stepEvidence.target_node_query.result.type-ceq'Button'-and
                    (Get-Pr90FormalRequestedValueV1 -Evidence $stepEvidence.target_opener_node_query -Name 'disabled')-is[bool]-and-not[bool](Get-Pr90FormalRequestedValueV1 -Evidence $stepEvidence.target_opener_node_query -Name 'disabled')-and
                    (Get-Pr90FormalRequestedValueV1 -Evidence $stepEvidence.target_node_query -Name 'disabled')-is[bool]-and-not[bool](Get-Pr90FormalRequestedValueV1 -Evidence $stepEvidence.target_node_query -Name 'disabled')-and
                    (Test-Pr90FormalSendCenterV1 -SendEvidence $stepEvidence.facility_card -SourceNode $stepEvidence.facility_hand_node_query.result)-and(Test-Pr90FormalSendCenterV1 -SendEvidence $stepEvidence.target_opener -SourceNode $stepEvidence.target_opener_node_query.result)-and(Test-Pr90FormalSendCenterV1 -SendEvidence $stepEvidence.target -SourceNode $stepEvidence.target_node_query.result)-and
                    (Test-Pr90FormalAcceptanceCountersV1 -Acceptance $acceptanceBefore -WitnessStep $step)-and(Test-Pr90FormalAcceptanceCountersV1 -Acceptance $acceptanceAfter -WitnessStep $step -After))
                if(-not$facilitySemanticsGreen){$facilityStepsGreen=$false;break}
                $previousFacilityAcceptanceEvidence=$stepEvidence.acceptance;$previousFacilityAcceptanceCall=$lastStepCall
            }catch{$facilityStepsGreen=$false;break}
        }
        if($facilityStepsGreen-and($previousFacilityAcceptanceCall-ge[int]$handLedgerValidation.first_call_index)){$facilityStepsGreen=$false;$facilityChronologyGreen=$false}
        $expectedEvidencePathCount=($evidenceDescriptors.Count+$facilityBatchTransitions.Count+($facilitySteps.Count*13)+$dynamicIntermediatePairCount)*2
        $expectedEvidencePairCount=$expectedEvidencePathCount/2
        if($witnessEvidencePaths.Count-ne$expectedEvidencePathCount-or@($witnessEvidencePaths|Sort-Object -Unique).Count-ne$expectedEvidencePathCount-or$witnessCallIndices.Count-ne$expectedEvidencePairCount-or@($witnessCallIndices|Sort-Object -Unique).Count-ne$expectedEvidencePairCount-or$witnessCommandIds.Count-ne$expectedEvidencePairCount-or@($witnessCommandIds|Sort-Object -Unique).Count-ne$expectedEvidencePairCount){$witnessHashesGreen=$false}
        if($facilityStepsGreen){
            try{
                $lastFacilityAcceptance=Get-Pr90FormalRequestedValueV1 -Evidence $previousFacilityAcceptanceEvidence -Name 'acceptance_state'
                if([int]$lastFacilityAcceptance.interaction_counts.card_selected-ne[int]$ScenarioWitness.card_selected_before-or[int]$cardAcceptance.interaction_counts.card_selected-ne[int]$ScenarioWitness.card_selected_after){$facilityStepsGreen=$false}
            }catch{$facilityStepsGreen=$false}
        }
        $witnessGreen=($null-ne$ScenarioWitness-and[string]$ScenarioWitness.schema-ceq'SpaceSyndicateFormalCombatScenarioWitnessV1'-and[string]$ScenarioWitness.status-ceq'PASS'-and
            [int64]$ScenarioWitness.deterministic_match_seed-eq900626424-and[string]$ScenarioWitness.acquired_card_domain-ceq'military'-and
            [int]$ScenarioWitness.initial_public_military_hand_candidate_count-eq0-and$preAcquireHandGreen-and[string]$ScenarioWitness.acquired_card_node_path-like'*/TrackRail/TrackCard_05'-and$null-eq$ScenarioWitness.PSObject.Properties['track_viewport_scroll_count']-and[int]$ScenarioWitness.track_acquired_delta-eq1-and[int]$ScenarioWitness.facility_advance_action_count-eq15-and$facilityStepsGreen-and$facilityChronologyGreen-and
            [int]$ScenarioWitness.track_visible_card_delta-eq-1-and[int]$ScenarioWitness.track_real_card_delta-eq-1-and[int]$ScenarioWitness.track_vacancy_delta-eq1-and
            [string]$ScenarioWitness.acquired_card_ui_text-like'*NORMAL*'-and[string]$ScenarioWitness.acquired_card_ui_text-like'*L1*'-and[string]$ScenarioWitness.acquired_card_ui_text-like'*军队*'-and[string]$ScenarioWitness.acquired_card_ui_text-like'*成本 2*'-and[string]$ScenarioWitness.acquired_card_ui_text-like'*进入弃牌*'-and
            [string]$ScenarioWitness.staged_card_domain-ceq'military'-and[string]$ScenarioWitness.staged_card_node_path-like'*/HandRail/*'-and[string]$ScenarioWitness.staged_card_ui_text-like'*军队*'-and[string]$ScenarioWitness.staged_card_ui_text-like'*STANDARD*'-and[string]$ScenarioWitness.staged_card_ui_text-like'*标准设施牌*'-and[string]$ScenarioWitness.staged_card_ui_text-like'*预绑定目标*'-and
            [int]$ScenarioWitness.card_selected_delta-eq1-and[int]$ScenarioWitness.card_selected_after-eq([int]$ScenarioWitness.card_selected_before+1)-and
            [string]$ScenarioWitness.combat_surface_path-ceq'V075GameScreen/RootMargin/Shell/V075CombatStackHost/V075CombatOverlay/Margin/Rows/SurfaceHost/CombatSurface'-and[bool]$ScenarioWitness.combat_surface_final_visible-and
            [string]$ScenarioWitness.mission_panel_path-ceq'V075GameScreen/RootMargin/Shell/V075CombatStackHost/V075CombatOverlay/Margin/Rows/SurfaceHost/CombatSurface/Rows/PrivateGrid/MilitaryPanel'-and
            [string]$ScenarioWitness.mission_kind-in@('assault_region','assault_monster')-and[string]$ScenarioWitness.mission_option_path-like'*/MilitaryPanel/Margin/Rows/TargetMenus/Assault*Option'-and[int]$ScenarioWitness.mission_option_item_count-gt0-and[int]$ScenarioWitness.mission_option_selected_before-eq-1-and[int]$ScenarioWitness.mission_option_selected_after-ge0-and
            [string]$ScenarioWitness.mission_button_path-like'V075GameScreen/RootMargin/Shell/V075CombatStackHost/*/MilitaryPanel/Margin/Rows/TaskButtons/Assault*Button'-and-not[string]::IsNullOrWhiteSpace([string]$ScenarioWitness.mission_button_text)-and[int]$ScenarioWitness.military_intent_delta-eq1-and
            $witnessHashesGreen-and$mainEvidenceSemanticsGreen-and[string]$ScenarioWitness.canonical_payload_sha256-ceq(Get-Pr90ProbeBCanonicalSha256 $ScenarioWitness))
        if(-not$witnessGreen){return [pscustomobject][ordered]@{green=$false;classification='SCENARIO_COMBAT_PRECONDITION_NOT_REACHED';source_count=0;presentation_count=0;map_cue_count=0;surface_cue_count=0;map_history_count=0;surface_history_count=0}}
        $beforeWrapper=$BeforeAcceptance.combat_wrapper;$afterWrapper=$AfterAcceptance.combat_wrapper
        $beforePresentation=$beforeWrapper.presentation;$afterPresentation=$AfterAcceptance.runtime_acceptance_debug.combat_presentation
        $beforeSurface=$beforeWrapper.surface;$afterSurface=$afterWrapper.surface
        $baselineProperties=@(
            @($beforeWrapper,'receipt_count'),@($beforeWrapper,'receipt_applied_count'),@($beforeWrapper,'receipt_duplicate_count'),@($beforeWrapper,'receipt_rejected_count'),@($beforeWrapper,'presentation_suppressed_duplicate_consume_count'),
            @($beforeWrapper,'combat_map_cue_apply_count'),@($beforeWrapper,'combat_map_cue_history_count'),
            @($beforePresentation,'applied_receipt_count'),@($beforePresentation,'collision_receipt_count'),@($beforePresentation,'duplicate_receipt_count'),@($beforePresentation,'rejected_receipt_count'),@($beforePresentation,'presentation_gameplay_mutation_count'),@($beforePresentation,'presentation_rng_draw_delta'),
            @($beforeSurface,'presentation_cue_applied_count'),@($beforeSurface,'presentation_history_count'),@($beforeSurface,'presentation_cue_collision_count'),@($beforeSurface,'presentation_cue_duplicate_count'),@($beforeSurface,'presentation_cue_rejected_count'),@($beforeSurface,'presentation_gameplay_mutation_count'),@($beforeSurface,'presentation_rng_draw_delta')
        )
        $baselineGreen=([string]$beforeWrapper.schema-ceq'V075SampleGameScreenCombatDebugV1'-and[string]$beforeWrapper.ruleset_id-ceq'v0.7.5'-and[string]$beforeWrapper.presentation_source_mode-ceq'runtime_shared'-and[int]$beforeWrapper.presentation_shared_consumer_count-eq1-and[int]$beforeWrapper.presentation_signal_connection_count-eq1-and[int]$beforeWrapper.presentation_source_bind_count-eq1)
        foreach($item in $baselineProperties){if($null-eq$item[0].PSObject.Properties[[string]$item[1]]-or[int]$item[0].PSObject.Properties[[string]$item[1]].Value-ne0){$baselineGreen=$false;break}}
        if(-not$baselineGreen){$classification='SCENARIO_COMBAT_BASELINE_NOT_ZERO'}else{
        $sourceCount=[int]$AfterAcceptance.runtime_acceptance_debug.combat_public_receipt_count
        $presentationCount=[int]$afterPresentation.applied_receipt_count
        $mapCueCount=[int]$afterWrapper.combat_map_cue_apply_count
        $surfaceCueCount=[int]$afterSurface.presentation_cue_applied_count
        $mapHistoryCount=[int]$afterWrapper.combat_map_cue_history_count
        $surfaceHistoryCount=[int]$afterSurface.presentation_history_count
        if($sourceCount-le0){$classification='SCENARIO_COMBAT_PRECONDITION_NOT_REACHED'}
        elseif($presentationCount-ne$sourceCount-or[int]$afterWrapper.presentation.applied_receipt_count-ne$sourceCount-or$mapCueCount-ne$sourceCount-or$surfaceCueCount-ne$sourceCount-or
            $mapHistoryCount-ne[Math]::Min($sourceCount,12)-or$surfaceHistoryCount-ne[Math]::Min($sourceCount,4)-or
            [int]$afterPresentation.collision_receipt_count-ne0-or[int]$afterPresentation.duplicate_receipt_count-ne0-or[int]$afterPresentation.rejected_receipt_count-ne0-or
            [int]$afterPresentation.presentation_gameplay_mutation_count-ne0-or[int]$afterPresentation.presentation_rng_draw_delta-ne0-or
            [int]$afterWrapper.presentation.collision_receipt_count-ne0-or[int]$afterWrapper.presentation.duplicate_receipt_count-ne0-or[int]$afterWrapper.presentation.rejected_receipt_count-ne0-or
            [int]$afterWrapper.presentation.presentation_gameplay_mutation_count-ne0-or[int]$afterWrapper.presentation.presentation_rng_draw_delta-ne0-or
            [int]$afterWrapper.receipt_count-ne1-or[int]$afterWrapper.receipt_applied_count-ne1-or[int]$afterWrapper.receipt_duplicate_count-ne0-or[int]$afterWrapper.receipt_rejected_count-ne0-or[int]$afterWrapper.presentation_suppressed_duplicate_consume_count-ne1-or
            [int]$afterSurface.presentation_cue_collision_count-ne0-or[int]$afterSurface.presentation_cue_duplicate_count-ne0-or[int]$afterSurface.presentation_cue_rejected_count-ne0-or[int]$afterSurface.presentation_gameplay_mutation_count-ne0-or[int]$afterSurface.presentation_rng_draw_delta-ne0){$classification='PRODUCT_PRESENTATION_CHAIN_FAILURE'}
        else{$classification='PASS'}
        }
    }catch{$classification='FORMAL_COMBAT_EVIDENCE_INVALID'}
    return [pscustomobject][ordered]@{green=($classification-ceq'PASS');classification=$classification;source_count=$sourceCount;presentation_count=$presentationCount;map_cue_count=$mapCueCount;surface_cue_count=$surfaceCueCount;map_history_count=$mapHistoryCount;surface_history_count=$surfaceHistoryCount}
}

function Test-Pr90Attempt22FormalRepairSelfTestReceiptV1 {
    param([AllowNull()][object]$Receipt)
    $requiredCases=@(
        'ATTEMPT19_COMPAT_IMPORT_RUNNER_BOUND_IN_TOOLING_AUTHORITY',
        'RECOVERY_IDENTITY_SEPARATE_FROM_FORMAL_TOOLING',
        'PROBE_B_AND_FORMAL_BASELINE_IDENTITIES_SEPARATED',
        'FORMAL_AUTHORIZATION_SEAL_AND_ATOMIC_CONSUMPTION_BOUND',
        'FORMAL_STATE_MACHINE_ACCOUNTING_CONSUMED',
        'FORMAL_RESULT_AFTER_CLEANUP_AND_FINALIZER_ONLY',
        'FORMAL_MCP_SUPPORT_CLASSIFIER_EXCLUDES_CURRENT_PROCESS',
        'FORMAL_MCP_SUPPORT_CLASSIFIER_REQUIRES_FILE_TARGET',
        'FORMAL_MCP_SUPPORT_CLASSIFIER_ACCEPTS_REAL_WATCHDOG',
        'FORMAL_MCP_SUPPORT_CLASSIFIER_REJECTS_EMBEDDED_FILE_TOKEN',
        'FORMAL_MCP_SUPPORT_CLASSIFIER_REJECTS_COMMAND_WITH_ARGS_PAYLOAD',
        'FORMAL_MCP_SUPPORT_CLASSIFIER_REJECTS_CWA_PAYLOAD',
        'FORMAL_MCP_SUPPORT_CLASSIFIER_REJECTS_ALL_COMMAND_MODE_PREFIX_PAYLOADS',
        'FORMAL_MCP_SUPPORT_CLASSIFIER_ACCEPTS_ALL_FILE_MODE_PREFIXES',
        'FORMAL_MCP_SUPPORT_CLASSIFIER_REJECTS_WRONG_ROOT_WATCHDOG',
        'FORMAL_PRESTART_BLOCKER_EMITS_PROCESS_ROWS',
        'FORMAL_V2_BOUND_INVOKER_ACCEPTS_DISTINCT_CONTROL_AND_GUI_OWNER',
        'NEGATIVE_FORMAL_V2_INVOKER_REJECTS_WRAPPER_AS_OWNER',
        'NEGATIVE_FORMAL_V2_INVOKER_REJECTS_OWNER_IDENTITY_DRIFT',
        'FORMAL_RUNBOOK_USES_SEALED_TOOLING_V2_INVOKER',
        'FORMAL_V2_M5_BINDING_FAILURE_PREVENTS_HTTP',
        'FORMAL_M5_INVOCATION_BINDING_ACCEPTED',
        'NEGATIVE_FORMAL_M5_WRONG_RUN_REJECTED',
        'NEGATIVE_FORMAL_M5_CONTROL_PID_DRIFT_REJECTED',
        'FORMAL_MAIN_RUNTIME_STREAM_TRANSITION_ACCEPTED',
        'NEGATIVE_FORMAL_MAIN_STREAM_SAME_AS_STARTUP_REJECTED',
        'NEGATIVE_FORMAL_MAIN_STREAM_READY_NOT_FIRST_REJECTED',
        'NEGATIVE_FORMAL_MAIN_STREAM_READY_GAP_REJECTED',
        'FORMAL_MAIN_STREAM_REBIND_PRECEDES_PHASE1',
        'FORMAL_PHASE2_RESPONSE_STATE_LAG_TRANSITION_ACCEPTED',
        'FORMAL_PHASE2_COMMAND_STATE_TRANSITION_WAITS_FOR_RUNNING',
        'FORMAL_PHASE2_POST_INPUT_DOUBLE_HEARTBEAT_ACCEPTED',
        'NEGATIVE_FORMAL_PHASE2_STALE_HEARTBEAT_REJECTED',
        'NEGATIVE_FORMAL_PHASE2_WRONG_COMMAND_ID_REJECTED',
        'NEGATIVE_FORMAL_PHASE2_STREAM_CHANGE_REJECTED',
        'NEGATIVE_FORMAL_PHASE2_INTER_HEARTBEAT_CURSOR_REGRESSION_REJECTED',
        'NEGATIVE_FORMAL_PHASE2_OVERFLOW_REJECTED',
        'NEGATIVE_FORMAL_PHASE2_COMMAND_STATE_IDENTITY_DRIFT_REJECTED',
        'FORMAL_PHASE2_FAILURE_CLASSIFICATION_DISTINGUISHES_PRODUCT_FROM_OBSERVER',
        'FORMAL_PHASE2_READINESS_PRECEDES_STRICT_30S_CURSOR_POLL',
        'FORMAL_TAP_CENTER_NORMALIZATION_ACCEPTS_MIXED_PRODUCERS',
        'FORMAL_TAP_VIEWPORT_BOUNDED_SCROLL_CONVERGENCE',
        'NEGATIVE_FORMAL_TAP_CENTER_INVALID_OR_NONFINITE_REJECTED',
        'NEGATIVE_FORMAL_TAP_VIEWPORT_OFFSCREEN_OR_STAGNANT_REJECTED',
        'FORMAL_COMBAT_SCENARIO_UI_ACTION_WITNESS_BOUND',
        'FORMAL_COMBAT_TRACK_MILITARY_SELECTOR_PRODUCTION_SHAPE',
        'FORMAL_COMBAT_FACILITY_FALLBACK_SELECTOR_PRODUCTION_SHAPE',
        'FORMAL_COMBAT_MILITARY_OPTION_SELECTION_PRODUCTION_SHAPE',
        'FORMAL_COMBAT_PURCHASED_CARD_BOUNDED_HAND_REACHABILITY',
        'FORMAL_COMBAT_PRESENTATION_CHAIN_ACCEPTED',
        'NEGATIVE_FORMAL_COMBAT_TREE_TRUNCATION_REJECTED',
        'NEGATIVE_FORMAL_COMBAT_HIDDEN_OR_WRONG_MISSION_SURFACE_REJECTED',
        'NEGATIVE_FORMAL_COMBAT_ZERO_SOURCE_REJECTED_AS_COVERAGE',
        'NEGATIVE_FORMAL_COMBAT_SOURCE_DROP_REJECTED_AS_PRODUCT',
        'NEGATIVE_FORMAL_COMBAT_DUPLICATE_OR_COLLISION_REJECTED',
        'NEGATIVE_FORMAL_COMBAT_CONTAMINATED_BASELINE_REJECTED',
        'NEGATIVE_FORMAL_COMBAT_MISSING_BASELINE_FIELD_REJECTED',
        'NEGATIVE_FORMAL_COMBAT_RESIDUAL_SOURCE_COUNT_REJECTED',
        'NEGATIVE_FORMAL_COMBAT_EVIDENCE_BYTES_OR_PATH_REJECTED',
        'NEGATIVE_FORMAL_COMBAT_EVIDENCE_SEMANTIC_BINDING_REJECTED',
        'FORMAL_REQUEST_ENVELOPES_IMMUTABLY_PERSISTED',
        'FORMAL_MILESTONE_SNAPSHOT_USES_EXPLICIT_PROCESS_ID',
        'CANONICAL_IMPORT_V2_DISTINCT_GUI_OWNER_ACCEPTED',
        'NEGATIVE_CANONICAL_IMPORT_WRAPPER_OWNER_REJECTED',
        'NEGATIVE_CANONICAL_IMPORT_WRONG_ROOT_REJECTED',
        'NEGATIVE_CANONICAL_IMPORT_FOREIGN_LISTENER_REJECTED',
        'NEGATIVE_CANONICAL_IMPORT_ALTERNATE_PORT_REJECTED',
        'NEGATIVE_CANONICAL_IMPORT_CONTROL_IDENTITY_DRIFT_REJECTED',
        'NEGATIVE_CANONICAL_IMPORT_OWNER_BINARY_DRIFT_REJECTED',
        'NEGATIVE_CANONICAL_IMPORT_OWNER_PARENT_DRIFT_REJECTED',
        'NEGATIVE_CANONICAL_IMPORT_OWNER_SESSION_DRIFT_REJECTED',
        'NEGATIVE_CANONICAL_IMPORT_OWNER_SID_DRIFT_REJECTED',
        'NEGATIVE_CANONICAL_IMPORT_OWNER_CREATION_ORDER_REJECTED',
        'NEGATIVE_CANONICAL_IMPORT_NULL_OWNER_REJECTED',
        'CANONICAL_IMPORT_FALLBACK_SINGLE_EXACT_CONTROL_ACCEPTED',
        'NEGATIVE_CANONICAL_IMPORT_FALLBACK_EMPTY_REJECTED',
        'NEGATIVE_CANONICAL_IMPORT_FALLBACK_MULTIPLE_REJECTED',
        'NEGATIVE_CANONICAL_IMPORT_FALLBACK_FOREIGN_REJECTED',
        'CANONICAL_RELEASE_HARNESS_SINGLE_IMPLEMENTATION',
        'CANONICAL_IMPORT_HARNESS_REUSES_SEALED_LAUNCH_AND_SCOPED_STOP',
        'CANONICAL_IMPORT_HARNESS_FAILURE_PATH_SCOPED_CLEANUP',
        'CANONICAL_IMPORT_V2_CONNECTION_REQUIRED_FIELDS_PRESENT',
        'CANONICAL_IMPORT_RUNTIME_MODULE_IMPORT_ORDER_REACHABLE',
        'NEGATIVE_CANONICAL_IMPORT_OLD_MODULE_ORDER_REJECTED',
        'CANONICAL_IMPORT_CONSOLE_TO_GUI_MAPPING_ACCEPTED',
        'NEGATIVE_CANONICAL_IMPORT_MISSING_GUI_SIBLING_PRECREATE_REJECTED',
        'CANONICAL_IMPORT_LAUNCHER_EXACT_PID_WAIT_IGNORES_DESCENDANT_LIFETIME',
        'NEGATIVE_CANONICAL_IMPORT_LAUNCHER_TIMEOUT_FAILS_CLOSED',
        'CANONICAL_IMPORT_PROCESS_START_TIMESTAMP_PRESERVES_EXACT_UTC_TICKS',
        'NEGATIVE_CANONICAL_IMPORT_LOCALIZED_TIMESTAMP_REJECTED',
        'FORMAL_GODOT_GUI_CONSOLE_IDENTITIES_DISTINCT_AND_BOUND',
        'FORMAL_FINALIZER_USES_SEALED_CONSOLE_BINARY',
        'NEGATIVE_GODOT_GUI_IDENTITY_MISSING',
        'NEGATIVE_GODOT_GUI_CONSOLE_IDENTITY_COLLAPSED',
        'NEGATIVE_GODOT_COMPAT_CONSOLE_ALIAS_SWAPPED',
        'STALE_326_SELFTEST_REJECTED',
        'STALE_V1_SELFTEST_REJECTED'
    )
    if($null-eq$Receipt){return $false}
    $requiredFields=@('schema','selftest_revision','status','created_at_utc','base_tooling_selftest_case_count','base_tooling_selftest_pass_count','new_selftest_case_count','new_selftest_pass_count','new_selftest_failure_count','total_tooling_selftest_pass_count','total_tooling_selftest_failure_count','authorization_negative_test_count','authorization_negative_test_pass_count','authorization_negative_test_fail_count','false_green_count','missing_prerequisite_false_accept_count','stale_tooling_false_accept_count','missing_probe_b_false_accept_count','invalid_preformal_false_accept_count','reused_run_id_false_accept_count','selftest_report_version_exact_match','selftest_unknown_version_false_accept_count','selftest_missing_version_false_accept_count','stale_326_report_accept_count','stale_326_report_rejection_green','historical_326_report_mutation_count','powershell_parse_error_count','powershell_parameter_binding_exception_count','selftest_case_name_inventory_sha256','parameter_binding_failures','cases','canonical_payload_sha256')
    if(@(Compare-Object -ReferenceObject $requiredFields -DifferenceObject @($Receipt.PSObject.Properties.Name)).Count-ne0){return $false}
    $revision=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $Receipt -Name 'selftest_revision'
    if([string]$Receipt.schema-cne'Pr90ProbeBV2ResultRecoveryToolingSelfTestV1'-or[string]$Receipt.status-cne'PASS'-or
       [string]$revision-cne'PR90_ATTEMPT22_FORMAL_EPHEMERAL_UI_REBIND_REPAIR_V19'-or[int]$Receipt.base_tooling_selftest_pass_count-ne326-or
       [int]$Receipt.new_selftest_case_count-ne@($Receipt.cases).Count-or[int]$Receipt.new_selftest_pass_count-ne[int]$Receipt.new_selftest_case_count-or
       [int]$Receipt.new_selftest_failure_count-ne0-or[int]$Receipt.total_tooling_selftest_pass_count-ne(326+[int]$Receipt.new_selftest_case_count)-or[int]$Receipt.total_tooling_selftest_failure_count-ne0-or
       [int]$Receipt.authorization_negative_test_fail_count-ne0-or[int]$Receipt.false_green_count-ne0-or[int]$Receipt.missing_prerequisite_false_accept_count-ne0-or
       [int]$Receipt.stale_tooling_false_accept_count-ne0-or[int]$Receipt.missing_probe_b_false_accept_count-ne0-or[int]$Receipt.invalid_preformal_false_accept_count-ne0-or[int]$Receipt.reused_run_id_false_accept_count-ne0-or
       [int]$Receipt.powershell_parse_error_count-ne0-or[int]$Receipt.powershell_parameter_binding_exception_count-ne0-or
       -not[bool]$Receipt.selftest_report_version_exact_match-or
       [int]$Receipt.selftest_unknown_version_false_accept_count-ne0-or[int]$Receipt.selftest_missing_version_false_accept_count-ne0-or
       [int]$Receipt.stale_326_report_accept_count-ne0-or-not[bool]$Receipt.stale_326_report_rejection_green-or[int]$Receipt.historical_326_report_mutation_count-ne0-or
       @($Receipt.parameter_binding_failures).Count-ne0-or[string]$Receipt.canonical_payload_sha256-cne(Get-Pr90ProbeBCanonicalSha256 $Receipt)){return $false}
    foreach($case in @($Receipt.cases)){
        if(@(Compare-Object -ReferenceObject @('name','pass','detail') -DifferenceObject @($case.PSObject.Properties.Name)).Count-ne0-or[string]::IsNullOrWhiteSpace([string]$case.name)-or-not[bool]$case.pass){return $false}
    }
    $caseNames=@($Receipt.cases|ForEach-Object{[string]$_.name})
    if($caseNames.Count-ne@($caseNames|Sort-Object -Unique).Count-or[string]$Receipt.selftest_case_name_inventory_sha256-cne(Get-Pr90ProbeBStringSetSha256 -Rows $caseNames)){return $false}
    $negativeCases=@($Receipt.cases|Where-Object{[string]$_.name-like'NEGATIVE_*'})
    if([int]$Receipt.authorization_negative_test_count-ne$negativeCases.Count-or[int]$Receipt.authorization_negative_test_pass_count-ne$negativeCases.Count){return $false}
    foreach($name in $requiredCases){$rows=@($Receipt.cases|Where-Object{[string]$_.name-ceq$name-and[bool]$_.pass});if($rows.Count-ne1){return $false}}
    return $true
}

function Test-Pr90Attempt22ToolingManifestStructureV2 {
    param(
        [AllowNull()][object]$Manifest,[AllowNull()][object]$BaseManifest,[AllowNull()][object]$BaseSeal,[AllowNull()][object]$NewSelfTest,[AllowNull()][object]$FrozenInput,
        [Parameter(Mandatory = $true)][string]$ExpectedHead,[Parameter(Mandatory = $true)][string]$ExpectedTree,[Parameter(Mandatory = $true)][string]$ExpectedParent,
        [Parameter(Mandatory = $true)][string]$ExpectedBaseManifestSha256,[Parameter(Mandatory = $true)][string]$ExpectedBaseSealSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedNewSelfTestSha256,[Parameter(Mandatory = $true)][string]$ExpectedFrozenInputSha256
    )
    if($null-eq$Manifest-or$null-eq$BaseManifest-or$null-eq$BaseSeal-or$null-eq$NewSelfTest-or$null-eq$FrozenInput){return $false}
        $expectedDiff=@('tools/pr90_attempt21_cursor_aware_exact_mcp_v5.ps1','tools/pr90_probe_b_attempt22_contract_v1.psm1','tools/pr90_probe_b_attempt22_selftest_v1.ps1','tools/pr90_probe_b_attempt22_tooling_manifest_builder_v1.ps1','tools/pr90_probe_b_attempt22_tooling_seal_builder_v1.ps1')|Sort-Object
    try{
        if([string]$Manifest.schema-cne'Pr90ProbeBV2ResultRecoveryToolingManifestV1'-or[string]$Manifest.status-cne'READY'-or-not[bool]$Manifest.preformal_authorization_eligible-or[bool]$Manifest.startup_probe_b_authorization_eligible-or
           [string]$Manifest.tooling_head_sha-cne$ExpectedHead-or[string]$Manifest.tooling_tree_sha-cne$ExpectedTree-or[string]$Manifest.tooling_parent_sha-cne$ExpectedParent-or
           [string]$Manifest.base_tooling_head_sha-cne$ExpectedParent-or[string]$Manifest.base_tooling_manifest_sha256-cne$ExpectedBaseManifestSha256-or[string]$Manifest.base_tooling_seal_sha256-cne$ExpectedBaseSealSha256-or
           [string]$Manifest.new_selftest_sha256-cne$ExpectedNewSelfTestSha256-or[string]$Manifest.frozen_input_inventory_sha256-cne$ExpectedFrozenInputSha256-or
            [int]$Manifest.new_tooling_commit_count-ne1-or[int]$Manifest.new_tooling_diff_count-ne5-or[int]$Manifest.new_tooling_modified_count-ne5-or[int]$Manifest.new_tooling_added_count-ne0-or
           [int]$Manifest.tooling_scope_violation_count-ne0-or[int]$Manifest.product_code_change_count-ne0-or[int]$Manifest.product_test_change_count-ne0-or[int]$Manifest.tooling_file_hash_mismatch_count-ne0-or
            [int]$Manifest.authorized_runtime_reachable_change_count-ne2-or[int]$Manifest.runtime_reachable_tooling_hash_mismatch_count-ne0-or
           [string]$Manifest.canonical_payload_sha256-cne(Get-Pr90ProbeBCanonicalSha256 $Manifest)){return $false}
        if([string]$BaseManifest.schema-cne'Pr90ProbeBV2ResultRecoveryToolingManifestV1'-or[string]$BaseManifest.status-cne'READY'-or[string]$BaseManifest.tooling_head_sha-cne$ExpectedParent-or
           [string]$BaseManifest.canonical_payload_sha256-cne(Get-Pr90ProbeBCanonicalSha256 $BaseManifest)-or[string]$BaseSeal.schema-cne'Pr90ProbeBV2ResultRecoveryToolingSealV1'-or[string]$BaseSeal.status-cne'SEALED'-or
           [string]$BaseSeal.tooling_head_sha-cne$ExpectedParent-or[string]$BaseSeal.manifest_sha256-cne$ExpectedBaseManifestSha256-or[string]$BaseSeal.canonical_payload_sha256-cne(Get-Pr90ProbeBCanonicalSha256 $BaseSeal)){return $false}
        if(-not(Test-Pr90Attempt22FormalRepairSelfTestReceiptV1 $NewSelfTest)-or[string]$Manifest.new_selftest_revision-cne[string]$NewSelfTest.selftest_revision-or[int]$Manifest.new_selftest_case_count-ne[int]$NewSelfTest.new_selftest_case_count-or
           [int]$Manifest.new_selftest_pass_count-ne[int]$NewSelfTest.new_selftest_pass_count-or[string]$Manifest.new_selftest_case_name_inventory_sha256-cne[string]$NewSelfTest.selftest_case_name_inventory_sha256){return $false}
        if([string]$FrozenInput.schema-cne'Pr90ProbeBV2FrozenInputInventoryV1'-or[string]$FrozenInput.status-cne'FROZEN'-or
           [string]$Manifest.frozen_input_tooling_head_sha-cne[string]$FrozenInput.tooling_head_sha-or[string]$Manifest.frozen_input_tooling_tree_sha-cne[string]$FrozenInput.tooling_tree_sha-or
           [int]$Manifest.frozen_input_count-ne[int]$FrozenInput.input_count-or[string]$Manifest.frozen_input_hash_inventory_sha256-cne[string]$FrozenInput.input_inventory_sha256){return $false}
        $diffRows=@($Manifest.new_tooling_diff);$diffPaths=@($diffRows|ForEach-Object{[string]$_.relative_path}|Sort-Object)
        if($diffRows.Count-ne5-or@($diffRows|Where-Object{[string]$_.status-ceq'M'}).Count-ne5-or@($diffRows|Where-Object{[string]$_.status-ceq'A'}).Count-ne0-or
           @($diffRows|Where-Object{[string]$_.status-notin@('M','A')}).Count-ne0-or@($diffPaths|Select-Object -Unique).Count-ne5-or@(Compare-Object $expectedDiff $diffPaths).Count-ne0){return $false}
        $rows=@($Manifest.tooling_files);$paths=@($rows|ForEach-Object{([string]$_.relative_path).Replace('\','/')}|Sort-Object);$basePaths=@($BaseManifest.tooling_files|ForEach-Object{([string]$_.relative_path).Replace('\','/')}|Sort-Object)
        $expectedToolingPaths=@($basePaths|Sort-Object -Unique)
        if([int]$Manifest.tooling_file_count-ne$rows.Count-or$rows.Count-ne@($paths|Select-Object -Unique).Count-or@(Compare-Object $expectedToolingPaths $paths).Count-ne0){return $false}
        return $true
    }catch{return $false}
}

function Test-Pr90FormalAuthorizationAccountingV1 {
    param(
        [Parameter(Mandatory=$true)][bool]$GodotProcessSuccessfullyCreated,
        [Parameter(Mandatory=$true)][bool]$ConsumptionReceiptExists,
        [Parameter(Mandatory=$true)][int]$FormalMcpExecutionCount,
        [Parameter(Mandatory=$true)][int]$AuthorizedRunCountConsumed
    )
    if($GodotProcessSuccessfullyCreated){
        return ($ConsumptionReceiptExists-and$FormalMcpExecutionCount-eq1-and$AuthorizedRunCountConsumed-eq1)
    }
    return (-not$ConsumptionReceiptExists-and$FormalMcpExecutionCount-eq0-and$AuthorizedRunCountConsumed-eq0)
}

function Get-Pr90ProbeBFileInventoryV1 {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Paths)
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($path in $Paths) {
        $full = (Resolve-Path -LiteralPath $path).Path
        $rows.Add([pscustomobject][ordered]@{path=$full;sha256=Get-Pr90ProbeBSha256 $full;byte_count=(Get-Item -LiteralPath $full).Length})
    }
    $orderedRows = @($rows | Sort-Object path)
    $rowText = @($orderedRows | ForEach-Object { "$($_.path)|$($_.sha256)|$($_.byte_count)" })
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes([string]::Join("`n", $rowText))
    return [pscustomobject][ordered]@{count=$orderedRows.Count;rows=$orderedRows;inventory_sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()}
}

function Get-Pr90ProbeBStringSetSha256 {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Rows)
    $sorted=[string[]]@($Rows)
    [Array]::Sort($sorted,[StringComparer]::Ordinal)
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes([string]::Join("`n",$sorted))
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Get-Pr90ProbeBOptionalPropertyValueV1 {
    param(
        [AllowNull()][object]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if ($null -eq $InputObject) { return $null }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    if ($property.Value -is [array]) {
        Write-Output -NoEnumerate $property.Value
        return
    }
    return $property.Value
}

function ConvertTo-Pr90ProbeBRequestFactV1 {
    param([AllowNull()][object]$Request)
    $malformed = $false
    $parameters = Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $Request -Name 'params'
    if ($null -eq $parameters -or $parameters -is [array]) { $malformed = $true }
    $nameValue = Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $parameters -Name 'name'
    $name = if ($null -eq $nameValue) { '' } else { [string]$nameValue }
    if ([string]::IsNullOrWhiteSpace($name)) { $malformed = $true }
    $arguments = Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $parameters -Name 'arguments'
    if ($arguments -is [array]) { $malformed = $true; $arguments = $null }
    $modeValue = Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $arguments -Name 'mode'
    $scenePathValue = Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $arguments -Name 'scene_path'
    $mode = if ($null -eq $modeValue) { '' } else { [string]$modeValue }
    $scenePath = if ($null -eq $scenePathValue) { '' } else { [string]$scenePathValue }
    return [pscustomobject][ordered]@{
        name = $name
        mode = $mode
        scene_path = $scenePath
        malformed = $malformed
        requests_main_scene = ($name -ceq 'play_main_scene' -or $scenePath -in @('res://scenes/main.tscn','res://main.tscn'))
    }
}

function Get-Pr90ProbeBPathFingerprintV1 {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path).ToLowerInvariant()
    return Get-Pr90ProbeBCanonicalSha256 ([pscustomobject][ordered]@{path=$full;canonical_payload_sha256=''})
}

function Test-Pr90ProbeBListenerSampleContractV1 {
    param([int]$TotalSampleCount,[int]$ConsecutiveParitySampleCount,[double]$StableWindowMs,[int]$ObserverSourceCount,[bool]$Parity)
    return ($TotalSampleCount-ge5-and$ConsecutiveParitySampleCount-ge5-and$StableWindowMs-ge1000-and$ObserverSourceCount-eq2-and$Parity)
}

function Test-Pr90ProbeBSceneIsolationContractV1 {
    param([Parameter(Mandatory = $true)][object]$Audit,[Parameter(Mandatory = $true)][string]$ExpectedScenePath,[Parameter(Mandatory = $true)][string]$ExpectedSceneSha256)
    return ([string]$Audit.schema-ceq'Pr90ProbeBSceneIsolationAuditV1'-and[string]$Audit.status-ceq'PASS'-and[string]$Audit.authorized_probe_scene_path-ceq$ExpectedScenePath-and
        [string]$Audit.authorized_probe_scene_sha256-ceq$ExpectedSceneSha256-and[bool]$Audit.autoload_contract_green-and[int]$Audit.unresolved_resource_count-eq0-and
        [int]$Audit.dynamic_resource_load_count-eq0-and[int]$Audit.main_tscn_dependency_count-eq0-and[int]$Audit.main_tscn_instance_count-eq0)
}

function Test-Pr90Attempt22ValidationReceiptV4 {
    param(
        [AllowNull()][object]$Validation,
        [Parameter(Mandatory = $true)][object]$Manifest,
        [Parameter(Mandatory = $true)][string]$ExpectedManifestPath,
        [Parameter(Mandatory = $true)][string]$ExpectedManifestSha256
    )
    if($null-eq$Validation){return $false}
    $required=@('schema','status','created_at_utc','authorization_id','authorized_run_id','formal_evidence_root','manifest_path','manifest_sha256','tooling_manifest_sha256','tooling_seal_sha256','product_head_sha','product_tree_sha','tooling_head_sha','tooling_tree_sha','declared_field_count','validated_field_count','field_mismatch_count','missing_field_count','unexpected_field_count','attempt19_compatibility_status','authorization_consumed','errors','canonical_payload_sha256')
    $names=@($Validation.PSObject.Properties.Name)
    if(@(Compare-Object -ReferenceObject $required -DifferenceObject $names).Count-ne0){return $false}
    if([string]::IsNullOrWhiteSpace([string]$Manifest.authorization_id)-or[string]::IsNullOrWhiteSpace([string]$Manifest.authorized_run_id)-or[string]::IsNullOrWhiteSpace([string]$Manifest.formal_evidence_root)){return $false}
    return [string]$Validation.schema-ceq'Pr90Attempt22AuthorizationValidationV4'-and[string]$Validation.status-ceq'PASS'-and
        [string]$Validation.authorization_id-ceq[string]$Manifest.authorization_id-and[string]$Validation.authorized_run_id-ceq[string]$Manifest.authorized_run_id-and
        [IO.Path]::GetFullPath([string]$Validation.formal_evidence_root)-ceq[IO.Path]::GetFullPath([string]$Manifest.formal_evidence_root)-and
        [IO.Path]::GetFullPath([string]$Validation.manifest_path)-ceq[IO.Path]::GetFullPath($ExpectedManifestPath)-and[string]$Validation.manifest_sha256-ceq$ExpectedManifestSha256-and
        [string]$Validation.tooling_manifest_sha256-ceq[string]$Manifest.tooling_manifest_sha256-and[string]$Validation.tooling_seal_sha256-ceq[string]$Manifest.tooling_seal_sha256-and
        [string]$Validation.product_head_sha-ceq[string]$Manifest.product_head_sha-and[string]$Validation.product_tree_sha-ceq[string]$Manifest.product_tree_sha-and
        [string]$Validation.tooling_head_sha-ceq[string]$Manifest.tooling_head_sha-and[string]$Validation.tooling_tree_sha-ceq[string]$Manifest.tooling_tree_sha-and
        [int]$Validation.declared_field_count-eq@($Manifest.PSObject.Properties).Count-and[int]$Validation.validated_field_count-eq[int]$Validation.declared_field_count-and
        [int]$Validation.field_mismatch_count-eq0-and[int]$Validation.missing_field_count-eq0-and[int]$Validation.unexpected_field_count-eq0-and
        [string]$Validation.attempt19_compatibility_status-ceq'PASS'-and-not[bool]$Validation.authorization_consumed-and@($Validation.errors).Count-eq0-and
        [string]$Validation.canonical_payload_sha256-ceq(Get-Pr90ProbeBCanonicalSha256 $Validation)
}

function Test-Pr90Probe004EvidenceContractsV1 {
    param(
        [AllowNull()][object]$Result,
        [AllowNull()][object]$Attestation,
        [Parameter(Mandatory = $true)][string]$ExpectedResultSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedProductHeadSha,
        [Parameter(Mandatory = $true)][string]$ExpectedProductTreeSha
    )
    if($null-eq$Result-or$null-eq$Attestation){return $false}
    $authorizationId='PR90_MCP_ENDPOINT_OWNERSHIP_V2_POST_REPAIR_M9_RUNTIME_BRIDGE_HEARTBEAT_BOOTSTRAP_NEW_PROBE_CONTROLLER_AND_M0_M11_PROBE_AUTHORIZATION'
    $probeId='pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-004'
    $toolingHead='7eda5b355759dbad952beeebd16e3b2d3b20b4f0';$toolingTree='41c9cd45e57e987036102dcf10cd1c34385f864b'
    try{
        $resultGreen=[string]$Result.schema-ceq'SpaceSyndicatePr90EndpointOwnershipV2PostRepairM0M11ResultV1'-and[string]$Result.status-ceq'PASS'-and
            [string]$Result.authorization_id-ceq$authorizationId-and[string]$Result.probe_id-ceq$probeId-and[string]$Result.execution_mode-ceq'PRE_FORMAL_STARTUP_PROBE'-and
            [int]$Result.post_repair_probe_execution_count-eq1-and[int]$Result.new_probe_execution_count-eq1-and-not[bool]$Result.automatic_retry_allowed-and-not[bool]$Result.second_new_probe_created-and
            [string]$Result.product_head_sha-ceq$ExpectedProductHeadSha-and[string]$Result.product_tree_sha-ceq$ExpectedProductTreeSha-and[string]$Result.tooling_head_sha-ceq$toolingHead-and[string]$Result.tooling_tree_sha-ceq$toolingTree-and
            [bool]$Result.endpoint_ownership_contract_v2_implemented-and[int]$Result.endpoint_ownership_contract_version-eq2-and[int]$Result.total_listener_sample_count-ge5-and[int]$Result.consecutive_parity_sample_count-ge5-and
            [double]$Result.endpoint_owner_stable_window_ms-ge1000-and[int]$Result.endpoint_listener_observer_source_count-eq2-and[bool]$Result.endpoint_listener_observer_parity-and[int]$Result.endpoint_listener_a_only_count-eq0-and[int]$Result.endpoint_listener_b_only_count-eq0-and
            [bool]$Result.endpoint_owner_is_gui_engine-and-not[bool]$Result.endpoint_owner_is_console_wrapper-and[bool]$Result.endpoint_owner_is_descendant_of_launcher-and[bool]$Result.endpoint_owner_command_line_fixture_match-and
            [bool]$Result.endpoint_owner_windows_session_match-and[bool]$Result.endpoint_owner_user_sid_match-and[int]$Result.endpoint_owner_pid_changed_count-eq0-and[int]$Result.endpoint_owner_creation_identity_changed_count-eq0-and
            [int]$Result.endpoint_owner_process_lineage_changed_count-eq0-and[int]$Result.multiple_active_endpoint_owner_count-eq0-and[int]$Result.prelaunch_godot_process_count-eq0-and[int]$Result.prelaunch_protected_port_listener_count-eq0-and
            [int]$Result.milestone_count-eq12-and[int]$Result.milestone_expected_count-eq12-and[bool]$Result.startup_milestone_complete-and[bool]$Result.startup_milestone_order_green-and
            [bool]$Result.first_jsonrpc_request_sent-and[bool]$Result.first_jsonrpc_response_received-and[int]$Result.m6_to_m11_execution_count-eq6-and[bool]$Result.first_mcp_raw_evidence_persisted-and
            [bool]$Result.runtime_stream_bootstrap_received-and[bool]$Result.ready_witness_persisted-and[bool]$Result.phase0_evidence_persisted-and[int]$Result.play_main_scene_count-eq0-and[int]$Result.product_match_count-eq0-and
            -not[bool]$Result.formal_authorization_consumed-and[int]$Result.formal_mcp_execution_count-eq0-and[int]$Result.authorized_run_count_consumed-eq0-and[bool]$Result.probe_stopped_cleanly-and[bool]$Result.stops_cleanly-and
            -not[bool]$Result.forced_stop-and@($Result.forced_stop_process_ids).Count-eq0-and[int]$Result.godot_process_count_after-eq0-and[int]$Result.port_7576_count_after-eq0-and[int]$Result.port_7586_count_after-eq0-and
            [int]$Result.unrelated_process_termination_count-eq0-and[string]::IsNullOrWhiteSpace([string]$Result.first_failure_class)-and[string]::IsNullOrWhiteSpace([string]$Result.failure_detail)-and
            [bool]$Result.ready_for_pr90_startup_probe_b_authorization-and-not[bool]$Result.ready_for_new_exact_sha_mcp_authorization-and[string]$Result.canonical_payload_sha256-ceq(Get-Pr90ProbeBCanonicalSha256 $Result)
        $attestationGreen=[string]$Attestation.schema-ceq'SpaceSyndicatePr90EndpointOwnershipV2PostRepairM0M11AttestationV1'-and[string]$Attestation.status-ceq'SEALED'-and
            [string]$Attestation.authorization_id-ceq$authorizationId-and[string]$Attestation.probe_id-ceq$probeId-and[string]$Attestation.result_sha256-ceq$ExpectedResultSha256-and
            [string]$Attestation.tooling_head_sha-ceq$toolingHead-and[string]$Attestation.tooling_tree_sha-ceq$toolingTree-and[string]$Attestation.product_head_sha-ceq$ExpectedProductHeadSha-and[string]$Attestation.product_tree_sha-ceq$ExpectedProductTreeSha-and
            [int]$Attestation.post_repair_probe_execution_count-eq1-and[int]$Attestation.new_probe_execution_count-eq1-and-not[bool]$Attestation.automatic_retry_allowed-and-not[bool]$Attestation.second_new_probe_created-and
            [int]$Attestation.formal_mcp_execution_count-eq0-and[int]$Attestation.authorized_run_count_consumed-eq0-and[bool]$Attestation.endpoint_ownership_contract_v2_implemented-and
            [bool]$Attestation.post_repair_m0_m11_probe_green-and-not[bool]$Attestation.tooling_bytes_changed_by_probe-and[string]$Attestation.canonical_payload_sha256-ceq(Get-Pr90ProbeBCanonicalSha256 $Attestation)
        return $resultGreen-and$attestationGreen
    }catch{return $false}
}

function Get-Pr90Attempt22FormalCommandParametersV2 {
    param([Parameter(Mandatory = $true)][object]$Config)
    if ([string]$Config.schema -cne 'Pr90Attempt22AuthorizationConfigV4') { throw 'Attempt 22 formal plan config schema mismatch.' }
    $attempt22ContractPath = Join-Path ([string]$Config.tooling_worktree) 'tools/pr90_probe_b_attempt22_contract_v1.psm1'
    return @(
        [pscustomobject][ordered]@{name='ExecutionMode';value='FORMAL_EXACT_SHA_MCP';binding_source='sealed_plan'},
        [pscustomobject][ordered]@{name='RunId';value=[string]$Config.authorized_run_id;binding_source='attempt22_authorization'},
        [pscustomobject][ordered]@{name='Worktree';value=[IO.Path]::GetFullPath([string]$Config.formal_product_worktree);binding_source='future_exact_clone'},
        [pscustomobject][ordered]@{name='EvidenceRoot';value=[IO.Path]::GetFullPath([string]$Config.formal_evidence_root);binding_source='authorized_run_id'},
        [pscustomobject][ordered]@{name='GodotPath';value=[IO.Path]::GetFullPath([string]$Config.godot_console_path);sha256=[string]$Config.godot_console_sha256;binding_source='probe_b_attestation'},
        [pscustomobject][ordered]@{name='ExpectedHeadSha';value=[string]$Config.product_head_sha;binding_source='pr90_exact_head'},
        [pscustomobject][ordered]@{name='ExpectedTreeSha';value=[string]$Config.product_tree_sha;binding_source='pr90_exact_tree'},
        [pscustomobject][ordered]@{name='LaunchScriptPath';value=[IO.Path]::GetFullPath([string]$Config.launch_script_path);sha256=[string]$Config.launch_script_sha256;binding_source='tooling_manifest'},
        [pscustomobject][ordered]@{name='ExpectedLaunchScriptSha256';value=[string]$Config.launch_script_sha256;binding_source='tooling_manifest'},
        [pscustomobject][ordered]@{name='StopScriptPath';value=[IO.Path]::GetFullPath([string]$Config.stop_script_path);sha256=[string]$Config.stop_script_sha256;binding_source='tooling_manifest'},
        [pscustomobject][ordered]@{name='ExpectedStopScriptSha256';value=[string]$Config.stop_script_sha256;binding_source='tooling_manifest'},
        [pscustomobject][ordered]@{name='WatchdogScriptPath';value=[IO.Path]::GetFullPath([string]$Config.startup_watchdog_path);sha256=[string]$Config.startup_watchdog_sha256;binding_source='tooling_manifest'},
        [pscustomobject][ordered]@{name='ExpectedWatchdogScriptSha256';value=[string]$Config.startup_watchdog_sha256;binding_source='tooling_manifest'},
        [pscustomobject][ordered]@{name='StateMachineScriptPath';value=[IO.Path]::GetFullPath([string]$Config.startup_state_machine_path);sha256=[string]$Config.startup_state_machine_sha256;binding_source='tooling_manifest'},
        [pscustomobject][ordered]@{name='ExpectedStateMachineSha256';value=[string]$Config.startup_state_machine_sha256;binding_source='tooling_manifest'},
        [pscustomobject][ordered]@{name='ContractScriptPath';value=[IO.Path]::GetFullPath([string]$Config.startup_contract_path);sha256=[string]$Config.startup_contract_sha256;binding_source='tooling_manifest'},
        [pscustomobject][ordered]@{name='ExpectedContractSha256';value=[string]$Config.startup_contract_sha256;binding_source='tooling_manifest'},
        [pscustomobject][ordered]@{name='SealedBaselinePath';value=[IO.Path]::GetFullPath([string]$Config.sealed_baseline_path);sha256=[string]$Config.sealed_baseline_sha256;binding_source='formal_clone_canonical_import'},
        [pscustomobject][ordered]@{name='ExpectedSealedBaselineSha256';value=[string]$Config.sealed_baseline_sha256;binding_source='formal_clone_canonical_import'},
        [pscustomobject][ordered]@{name='StartupToolingManifestPath';value=[IO.Path]::GetFullPath([string]$Config.tooling_manifest_path);sha256=[string]$Config.tooling_manifest_sha256;binding_source='tooling_seal'},
        [pscustomobject][ordered]@{name='ExpectedStartupToolingManifestSha256';value=[string]$Config.tooling_manifest_sha256;binding_source='tooling_seal'},
        [pscustomobject][ordered]@{name='StartupToolingSealPath';value=[IO.Path]::GetFullPath([string]$Config.tooling_seal_path);sha256=[string]$Config.tooling_seal_sha256;binding_source='tooling_seal'},
        [pscustomobject][ordered]@{name='ExpectedStartupToolingSealSha256';value=[string]$Config.tooling_seal_sha256;binding_source='tooling_seal'},
        [pscustomobject][ordered]@{name='FormalAuthorizationValidationReceiptPath';value=[IO.Path]::GetFullPath([string]$Config.future_authorization_validation_receipt_path);binding_source='attempt22_seal_after_preformal'},
        [pscustomobject][ordered]@{name='ExpectedFormalAuthorizationValidationReceiptSha256';value_source='attempt22_seal.validation_receipt_sha256';binding_source='deferred_after_preformal'},
        [pscustomobject][ordered]@{name='FormalAuthorizationSealPath';value=[IO.Path]::GetFullPath([string]$Config.future_authorization_seal_path);binding_source='attempt22_seal_after_preformal'},
        [pscustomobject][ordered]@{name='ExpectedFormalAuthorizationSealSha256';value_source='attempt22_seal.sha256';binding_source='deferred_after_preformal'},
        [pscustomobject][ordered]@{name='FormalAuthorizationConsumptionReceiptPath';value=[IO.Path]::GetFullPath([string]$Config.formal_authorization_consumption_receipt_path);binding_source='atomic_single_consume'},
        [pscustomobject][ordered]@{name='Attempt22ContractScriptPath';value=[IO.Path]::GetFullPath($attempt22ContractPath);sha256=[string]$Config.attempt22_contract_module_sha256;binding_source='tooling_manifest'},
        [pscustomobject][ordered]@{name='ExpectedAttempt22ContractSha256';value=[string]$Config.attempt22_contract_module_sha256;binding_source='tooling_manifest'},
        [pscustomobject][ordered]@{name='ExpectedRunbookSha256';value=[string]$Config.cursor_runbook_sha256;binding_source='tooling_manifest'},
        [pscustomobject][ordered]@{name='ImportFinalizerBindingPath';value=[IO.Path]::GetFullPath([string]$Config.import_finalizer_path);sha256=[string]$Config.import_finalizer_sha256;binding_source='tooling_manifest'},
        [pscustomobject][ordered]@{name='ExpectedImportFinalizerBindingSha256';value=[string]$Config.import_finalizer_sha256;binding_source='tooling_manifest'},
        [pscustomobject][ordered]@{name='ImportRunnerPath';value=[IO.Path]::GetFullPath([string]$Config.import_runner_path);sha256=[string]$Config.import_runner_sha256;binding_source='tooling_manifest'},
        [pscustomobject][ordered]@{name='ExpectedImportRunnerSha256';value=[string]$Config.import_runner_sha256;binding_source='tooling_manifest'},
        [pscustomobject][ordered]@{name='ClassCachePath';value=[IO.Path]::GetFullPath([string]$Config.class_cache_path);sha256=[string]$Config.class_cache_sha256;binding_source='sealed_baseline'},
        [pscustomobject][ordered]@{name='ExpectedClassCacheSha256';value=[string]$Config.class_cache_sha256;binding_source='sealed_baseline'},
        [pscustomobject][ordered]@{name='GodotGuiPath';value=[IO.Path]::GetFullPath([string]$Config.godot_gui_path);sha256=[string]$Config.godot_gui_sha256;binding_source='probe_b_attestation'},
        [pscustomobject][ordered]@{name='ExpectedGodotGuiSha256';value=[string]$Config.godot_gui_sha256;binding_source='probe_b_attestation'},
        [pscustomobject][ordered]@{name='FormalPrelaunchIgnoredInventoryPath';value=[IO.Path]::GetFullPath([string]$Config.formal_prelaunch_ignored_inventory_path);binding_source='attempt22_authorization'},
        [pscustomobject][ordered]@{name='FormalTerminalManifestPath';value=[IO.Path]::GetFullPath([string]$Config.formal_terminal_manifest_path);binding_source='attempt22_authorization'},
        [pscustomobject][ordered]@{name='FormalFinalizerResultPath';value=[IO.Path]::GetFullPath([string]$Config.formal_finalizer_result_path);binding_source='attempt22_authorization'},
        [pscustomobject][ordered]@{name='AllowFormalContinuation';value=$true;binding_source='future_user_authorization'},
        [pscustomobject][ordered]@{name='Port';value=7576;binding_source='endpoint_contract_v2'}
    )
}

function Test-Pr90Attempt22PreformalReceiptV2 {
    param(
        [AllowNull()][object]$Preformal,
        [Parameter(Mandatory = $true)][AllowNull()][object]$ExpectedPlanConfig,
        [Parameter(Mandatory = $true)][string]$ExpectedFormalEvidenceRoot,
        [Parameter(Mandatory = $true)][string]$ExpectedToolingManifestSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedToolingSealSha256
    )
    if($null-eq$Preformal){return $false}
    $checkNames=@('AUTHORIZATION_SCHEMA_LOADABLE','PRODUCT_HEAD_BOUND','PRODUCT_TREE_BOUND','TOOLING_HEAD_BOUND','TOOLING_TREE_BOUND','TOOLING_SEAL_BOUND','TOOLING_FILE_HASH_INVENTORY_BOUND','REMOTE_TOOLING_BRANCH_BOUND','FORMAL_GATE_1_79_RECEIPT_BOUND','SEALED_POST_IMPORT_BASELINE_BOUND','CLASS_CACHE_BOUND','IMPORT_PASS1_MANIFEST_BOUND','IMPORT_PASS2_MANIFEST_BOUND','PROBE004_RESULT_BOUND','PROBE004_ATTESTATION_BOUND','PROBE_B_RESULT_BOUND','PROBE_B_ATTESTATION_BOUND','ENDPOINT_OWNERSHIP_CONTRACT_V2_BOUND','CURSOR_AWARE_RUNBOOK_LOADABLE_AND_BOUND','IMPORT_CONTROLLER_FINALIZER_LOADABLE_AND_BOUND','FORMAL_COMMAND_PHASE_EVIDENCE_ACCOUNTING_PLAN_CONSTRUCTED','FORMAL_START_BOUNDARY_REACHED_WITHOUT_PROCESS')
    $parameterNamesExpected=@('ExecutionMode','RunId','Worktree','EvidenceRoot','GodotPath','ExpectedHeadSha','ExpectedTreeSha','LaunchScriptPath','ExpectedLaunchScriptSha256','StopScriptPath','ExpectedStopScriptSha256','WatchdogScriptPath','ExpectedWatchdogScriptSha256','StateMachineScriptPath','ExpectedStateMachineSha256','ContractScriptPath','ExpectedContractSha256','SealedBaselinePath','ExpectedSealedBaselineSha256','StartupToolingManifestPath','ExpectedStartupToolingManifestSha256','StartupToolingSealPath','ExpectedStartupToolingSealSha256','FormalAuthorizationValidationReceiptPath','ExpectedFormalAuthorizationValidationReceiptSha256','FormalAuthorizationSealPath','ExpectedFormalAuthorizationSealSha256','FormalAuthorizationConsumptionReceiptPath','Attempt22ContractScriptPath','ExpectedAttempt22ContractSha256','ExpectedRunbookSha256','ImportFinalizerBindingPath','ExpectedImportFinalizerBindingSha256','ImportRunnerPath','ExpectedImportRunnerSha256','ClassCachePath','ExpectedClassCacheSha256','GodotGuiPath','ExpectedGodotGuiSha256','FormalPrelaunchIgnoredInventoryPath','FormalTerminalManifestPath','FormalFinalizerResultPath','AllowFormalContinuation','Port')
    $phaseExpected=@('M0-M11 startup and phase-0-ready','exit custom probe play mode','play_main_scene exact res://scenes/main.tscn','phase-1-main-scene cursor witness','phase-2-new-game cursor witness','phase-3-early-match cursor witness','phase-4-mid-match cursor witness','phase-5-combat-facility cursor witness','phase-6-victory cursor witness','phase-7-settlement cursor witness','phase-7-final-settlement and exact result')
    $evidenceExpected=@('authorization-validation','12 milestone receipts and sidecars','endpoint ownership V2 samples and attestation','raw JSON-RPC inventory','runtime bridge heartbeat/bootstrap','ready witness','phase-0 through phase-7 cursor witnesses','exact-sha-mcp result or failure','terminal process and port manifest','formal import finalizer result')
    $accountingExpected=@('authorized_run_count=1','automatic_retry_allowed=false','formal_mcp_execution_count=0 before authorized boundary','authorized_run_count_consumed=0 before authorized boundary','same run id evidence root must not exist','no automatic retry after any failure')
    try{
        if([string]$Preformal.schema-cne'Pr90Attempt22PreformalDryRunV2'-or[string]$Preformal.run_id-cne'pr90-attempt22-preformal-dry-run-v2-002'-or[string]$Preformal.status-cne'PASS'-or
           [int]$Preformal.check_count-ne22-or[int]$Preformal.pass_count-ne22-or[int]$Preformal.fail_count-ne0-or@($Preformal.checks).Count-ne22-or
           [string]$Preformal.canonical_payload_sha256-cne(Get-Pr90ProbeBCanonicalSha256 $Preformal)){return $false}
        for($index=0;$index-lt22;$index+=1){$row=$Preformal.checks[$index];if([int]$row.id-ne($index+1)-or[string]$row.name-cne$checkNames[$index]-or-not[bool]$row.pass){return $false}}
        $plan=$Preformal.formal_plan;$parameters=@($plan.command_parameters);$parameterNames=@($parameters|ForEach-Object{[string]$_.name})
        $expectedParameters=@(Get-Pr90Attempt22FormalCommandParametersV2 -Config $ExpectedPlanConfig)
        if($parameters.Count-ne44-or@($parameterNames|Select-Object -Unique).Count-ne44-or@(Compare-Object $parameterNamesExpected $parameterNames -SyncWindow 0).Count-ne0-or
           @(Compare-Object $phaseExpected @($plan.phase_plan) -SyncWindow 0).Count-ne0-or@(Compare-Object $evidenceExpected @($plan.evidence_plan) -SyncWindow 0).Count-ne0-or@(Compare-Object $accountingExpected @($plan.accounting_plan) -SyncWindow 0).Count-ne0-or
           [int]$plan.deferred_binding_count-ne2-or@($plan.deferred_bindings).Count-ne2-or$plan.deferred_bindings[0]-cne'ExpectedFormalAuthorizationValidationReceiptSha256'-or$plan.deferred_bindings[1]-cne'ExpectedFormalAuthorizationSealSha256'-or
           [IO.Path]::GetFullPath([string]$plan.formal_evidence_root)-cne[IO.Path]::GetFullPath($ExpectedFormalEvidenceRoot)-or
           (ConvertTo-Pr90ProbeBCanonicalJson $parameters)-cne(ConvertTo-Pr90ProbeBCanonicalJson $expectedParameters)){return $false}
        $manifestRows=@($parameters|Where-Object{[string]$_.name-ceq'StartupToolingManifestPath'-and[string]$_.sha256-ceq$ExpectedToolingManifestSha256})
        $sealRows=@($parameters|Where-Object{[string]$_.name-ceq'StartupToolingSealPath'-and[string]$_.sha256-ceq$ExpectedToolingSealSha256})
        $finalizer=$plan.finalizer_plan;$formalRoot=[IO.Path]::GetFullPath($ExpectedFormalEvidenceRoot)
        return $manifestRows.Count-eq1-and$sealRows.Count-eq1-and[string]$finalizer.mode-ceq'FinalizeSnapshot'-and[bool]$finalizer.normal_stop_required-and[bool]$finalizer.terminal_zero_required-and[bool]$finalizer.result_written_after_finalizer-and
            [IO.Path]::GetFullPath([string]$finalizer.terminal_manifest_path)-ceq[IO.Path]::GetFullPath((Join-Path $formalRoot 'terminal-process-port-manifest.json'))-and
            [IO.Path]::GetFullPath([string]$finalizer.finalizer_result_path)-ceq[IO.Path]::GetFullPath((Join-Path $formalRoot 'formal-import-finalizer-result.json'))
    }catch{return $false}
}

function Test-Pr90Attempt22EvidenceContractsV1 {
    param(
        [AllowNull()][object]$ProbeB,
        [AllowNull()][object]$ProbeBAttestation,
        [AllowNull()][object]$ProbeBRecoveryReceipt,
        [AllowNull()][object]$Preformal,
        [Parameter(Mandatory = $true)][AllowNull()][object]$ExpectedPreformalPlanConfig,
        [Parameter(Mandatory = $true)][string]$ExpectedProbeBResultSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedProbeBAttestationSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedProbe004ResultSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedProbe004AttestationSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedProbeBExecutionStartSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedProbeBExecutionConfigSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedProbeBFinalizerResultSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedListenerForensicsSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedProductHeadSha,
        [Parameter(Mandatory = $true)][string]$ExpectedProductTreeSha,
        [Parameter(Mandatory = $true)][string]$ExpectedToolingHeadSha,
        [Parameter(Mandatory = $true)][string]$ExpectedToolingTreeSha,
        [Parameter(Mandatory = $true)][string]$ExpectedToolingManifestSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedToolingSealSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedFormalEvidenceRoot,
        [Parameter(Mandatory = $true)][string]$ExpectedProbeRecoveryToolingHeadSha,
        [Parameter(Mandatory = $true)][string]$ExpectedProbeRecoveryToolingTreeSha,
        [Parameter(Mandatory = $true)][string]$ExpectedProbeRecoveryToolingManifestSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedProbeRecoveryToolingSealSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedProbeExecutionToolingHeadSha,
        [Parameter(Mandatory = $true)][string]$ExpectedProbeExecutionToolingTreeSha,
        [Parameter(Mandatory = $true)][string]$ExpectedProbeExecutionToolingSealSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedRecoveryControllerSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedRecoveryContractModuleSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedFrozenInputInventorySha256,
        [Parameter(Mandatory = $true)][string]$ExpectedGodotGuiSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedGodotConsoleSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedBaselineSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedClassCacheSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedProbeBBaselineSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedProbeBClassCacheSha256
    )
    $errors=[Collections.Generic.List[string]]::new()
    if($ExpectedProbeBClassCacheSha256-cne$ExpectedClassCacheSha256){$errors.Add('PROBE_B_FORMAL_CLASS_CACHE_PARITY_MISMATCH')}
    if(-not(Test-Pr90Attempt22PreformalReceiptV2 -Preformal $Preformal -ExpectedPlanConfig $ExpectedPreformalPlanConfig -ExpectedFormalEvidenceRoot $ExpectedFormalEvidenceRoot -ExpectedToolingManifestSha256 $ExpectedToolingManifestSha256 -ExpectedToolingSealSha256 $ExpectedToolingSealSha256)){$errors.Add('PREFORMAL_STRUCTURE_OR_PLAN_MISMATCH')}
    if($null-eq$ProbeB){$errors.Add('PROBE_B_RESULT_MISSING_OR_UNREADABLE')}
    if($null-eq$ProbeBAttestation){$errors.Add('PROBE_B_ATTESTATION_MISSING_OR_UNREADABLE')}
    if($null-eq$ProbeBRecoveryReceipt){$errors.Add('PROBE_B_RECOVERY_RECEIPT_MISSING_OR_UNREADABLE')}
    if($null-eq$Preformal){$errors.Add('PREFORMAL_RECEIPT_MISSING_OR_UNREADABLE')}
    if($null-eq$ProbeB-or$null-eq$ProbeBAttestation-or$null-eq$ProbeBRecoveryReceipt-or$null-eq$Preformal){
        return [pscustomobject][ordered]@{status='BLOCKED';error_count=$errors.Count;errors=@($errors)}
    }
    if($null-eq$ProbeB-or[string]$ProbeB.schema-cne'Pr90ExactCloneProbeBV2ResultV1'-or[string]$ProbeB.probe_id-cne'pr90-exact-clone-startup-probe-b-v2-001'-or[string]$ProbeB.status-cne'PASS'-or[string]$ProbeB.import_finalizer_status-cne'PASS'-or
       [string]$ProbeB.product_head_sha-cne$ExpectedProductHeadSha-or[string]$ProbeB.product_tree_sha-cne$ExpectedProductTreeSha-or
       [string]$ProbeB.tooling_head_sha-cne$ExpectedProbeExecutionToolingHeadSha-or[string]$ProbeB.tooling_tree_sha-cne$ExpectedProbeExecutionToolingTreeSha-or[string]$ProbeB.tooling_seal_sha256-cne$ExpectedProbeExecutionToolingSealSha256-or
       [string]$ProbeB.probe_execution_start_sha256-cne$ExpectedProbeBExecutionStartSha256-or[string]$ProbeB.probe_execution_config_sha256-cne$ExpectedProbeBExecutionConfigSha256-or
       [string]$ProbeB.result_recovery_tooling_head_sha-cne$ExpectedProbeRecoveryToolingHeadSha-or[string]$ProbeB.result_recovery_tooling_tree_sha-cne$ExpectedProbeRecoveryToolingTreeSha-or[string]$ProbeB.result_recovery_tooling_manifest_sha256-cne$ExpectedProbeRecoveryToolingManifestSha256-or[string]$ProbeB.result_recovery_tooling_seal_sha256-cne$ExpectedProbeRecoveryToolingSealSha256-or[int]$ProbeB.runtime_reachable_tooling_hash_mismatch_count-ne0-or
       [string]$ProbeB.post_import_baseline_sha256-cne$ExpectedProbeBBaselineSha256-or[string]$ProbeB.class_cache_sha256-cne$ExpectedProbeBClassCacheSha256-or
       [string]$ProbeB.godot_gui_sha256-cne$ExpectedGodotGuiSha256-or[string]$ProbeB.godot_console_sha256-cne$ExpectedGodotConsoleSha256-or
       -not[bool]$ProbeB.bracketed_sample_model-or[int]$ProbeB.total_listener_cohort_attempt_count-lt5-or[int]$ProbeB.consecutive_stable_parity_cohort_count-lt5-or[double]$ProbeB.stable_parity_window_ms-lt1000-or
       -not[bool]$ProbeB.endpoint_listener_core_parity-or[int]$ProbeB.listener_core_parity_key_field_count-ne5-or[int]$ProbeB.matched_listener_process_enrichment_count-ne1-or[int]$ProbeB.duplicate_source_process_enrichment_count-ne0-or
       -not[bool]$ProbeB.endpoint_owner_project_match-or-not[bool]$ProbeB.endpoint_owner_mcp_session_match-or[int]$ProbeB.protected_port_multiple_owner_count-ne0-or[int]$ProbeB.foreign_listener_count-ne0){$errors.Add('PROBE_B_RESULT_CONTRACT_MISMATCH')}
    if([int]$ProbeB.milestone_pass_count-ne12-or[int]$ProbeB.milestone_fail_count-ne0-or[int]$ProbeB.milestone_receipt_count-ne12-or-not[bool]$ProbeB.milestone_sequence_green-or[int]$ProbeB.milestone_duplicate_count-ne0-or
       [string]$ProbeB.listener_forensics_sha256-cne$ExpectedListenerForensicsSha256-or-not[bool]$ProbeB.first_jsonrpc_result-or-not[bool]$ProbeB.raw_evidence_result-or-not[bool]$ProbeB.runtime_bootstrap_result-or-not[bool]$ProbeB.ready_witness_result-or-not[bool]$ProbeB.phase0_result-or
       [string]$ProbeB.import_finalizer_status-cne'PASS'-or[string]$ProbeB.finalizer_result_sha256-cne$ExpectedProbeBFinalizerResultSha256-or[string]$ProbeB.terminal_process_port_status-cne'PASS'-or-not[bool]$ProbeB.stopped_cleanly-or[bool]$ProbeB.forced_stop-or
       [int]$ProbeB.enter_play_mode_request_count-ne1-or[int]$ProbeB.custom_non_main_scene_request_count-ne1-or[int]$ProbeB.request_count-lt1-or[string]::IsNullOrWhiteSpace([string]$ProbeB.request_inventory_sha256)-or
       [int]$ProbeB.malformed_request_count-ne0-or[int]$ProbeB.unauthorized_request_count-ne0-or[int]$ProbeB.play_main_scene_count-ne0-or[int]$ProbeB.main_tscn_instance_count-ne0-or[int]$ProbeB.main_tscn_dependency_count-ne0-or
       [int]$ProbeB.product_match_count-ne0-or[int]$ProbeB.product_frame_count-ne0-or[int]$ProbeB.formal_product_result_count-ne0-or[int]$ProbeB.missing_required_evidence_count-ne0-or
       [string]$ProbeB.canonical_payload_sha256-cne(Get-Pr90ProbeBCanonicalSha256 $ProbeB)){$errors.Add('PROBE_B_DIRECT_EVIDENCE_OR_TERMINAL_MISMATCH')}
    if($null-eq$ProbeBAttestation-or[string]$ProbeBAttestation.schema-cne'Pr90ExactCloneProbeBV2AttestationV1'-or[string]$ProbeBAttestation.status-cne'SEALED'-or[int]$ProbeBAttestation.unbound_evidence_count-ne0-or[string]$ProbeBAttestation.result_sha256-cne$ExpectedProbeBResultSha256-or
       [string]$ProbeBAttestation.probe_execution_tooling_head_sha-cne$ExpectedProbeExecutionToolingHeadSha-or[string]$ProbeBAttestation.probe_execution_tooling_tree_sha-cne$ExpectedProbeExecutionToolingTreeSha-or[string]$ProbeBAttestation.probe_execution_tooling_seal_sha256-cne$ExpectedProbeExecutionToolingSealSha256-or
       [string]$ProbeBAttestation.probe_execution_start_sha256-cne$ExpectedProbeBExecutionStartSha256-or[string]$ProbeBAttestation.probe_execution_config_sha256-cne$ExpectedProbeBExecutionConfigSha256-or
       [string]$ProbeBAttestation.result_recovery_tooling_head_sha-cne$ExpectedProbeRecoveryToolingHeadSha-or[string]$ProbeBAttestation.result_recovery_tooling_tree_sha-cne$ExpectedProbeRecoveryToolingTreeSha-or[string]$ProbeBAttestation.result_recovery_tooling_manifest_sha256-cne$ExpectedProbeRecoveryToolingManifestSha256-or[string]$ProbeBAttestation.result_recovery_tooling_seal_sha256-cne$ExpectedProbeRecoveryToolingSealSha256-or
       [string]$ProbeBAttestation.post_import_baseline_sha256-cne$ExpectedProbeBBaselineSha256-or[string]$ProbeBAttestation.class_cache_sha256-cne$ExpectedProbeBClassCacheSha256-or
       [string]$ProbeBAttestation.probe004_result_sha256-cne$ExpectedProbe004ResultSha256-or[string]$ProbeBAttestation.probe004_attestation_sha256-cne$ExpectedProbe004AttestationSha256-or
       [string]$ProbeBAttestation.listener_forensics_sha256-cne$ExpectedListenerForensicsSha256-or[string]$ProbeBAttestation.finalizer_result_sha256-cne$ExpectedProbeBFinalizerResultSha256-or
       [string]$ProbeBAttestation.finalizer_result_sha256-cne[string]$ProbeB.finalizer_result_sha256-or[string]$ProbeBAttestation.terminal_manifest_sha256-cne[string]$ProbeB.terminal_manifest_sha256-or
       [int]$ProbeBAttestation.request_count-ne[int]$ProbeB.request_count-or[string]$ProbeBAttestation.request_inventory_sha256-cne[string]$ProbeB.request_inventory_sha256-or
       -not[bool]$ProbeBAttestation.bracketed_sample_model-or[int]$ProbeBAttestation.listener_core_parity_key_field_count-ne5-or[int]$ProbeBAttestation.matched_listener_process_enrichment_count-ne1-or[string]$ProbeBAttestation.raw_listener_evidence_preservation-cne'100_PERCENT'-or
       [int]$ProbeBAttestation.unbound_evidence_count-ne0-or[int]$ProbeBAttestation.probe_execution_count_delta-ne0-or[int]$ProbeBAttestation.godot_process_start_count-ne0-or[int]$ProbeBAttestation.mcp_process_start_count-ne0-or
       [int]$ProbeBAttestation.formal_mcp_execution_count-ne0-or[int]$ProbeBAttestation.authorized_run_count_consumed-ne0-or[string]$ProbeBAttestation.canonical_payload_sha256-cne(Get-Pr90ProbeBCanonicalSha256 $ProbeBAttestation)){$errors.Add('PROBE_B_ATTESTATION_CONTRACT_MISMATCH')}
    if($null-eq$ProbeBRecoveryReceipt-or[string]$ProbeBRecoveryReceipt.schema-cne'Pr90ProbeBV2ResultRecoveryReceiptV1'-or[string]$ProbeBRecoveryReceipt.status-cne'PASS'-or
       [string]$ProbeBRecoveryReceipt.result_sha256-cne$ExpectedProbeBResultSha256-or[string]$ProbeBRecoveryReceipt.attestation_sha256-cne$ExpectedProbeBAttestationSha256-or[string]$ProbeBRecoveryReceipt.probe_execution_tooling_head_sha-cne$ExpectedProbeExecutionToolingHeadSha-or[string]$ProbeBRecoveryReceipt.probe_execution_tooling_tree_sha-cne$ExpectedProbeExecutionToolingTreeSha-or[string]$ProbeBRecoveryReceipt.probe_execution_tooling_seal_sha256-cne$ExpectedProbeExecutionToolingSealSha256-or
       [string]$ProbeBRecoveryReceipt.result_recovery_tooling_head_sha-cne$ExpectedProbeRecoveryToolingHeadSha-or[string]$ProbeBRecoveryReceipt.result_recovery_tooling_tree_sha-cne$ExpectedProbeRecoveryToolingTreeSha-or[string]$ProbeBRecoveryReceipt.result_recovery_tooling_manifest_sha256-cne$ExpectedProbeRecoveryToolingManifestSha256-or[string]$ProbeBRecoveryReceipt.result_recovery_tooling_seal_sha256-cne$ExpectedProbeRecoveryToolingSealSha256-or
       [string]$ProbeBRecoveryReceipt.recovery_controller_sha256-cne$ExpectedRecoveryControllerSha256-or[string]$ProbeBRecoveryReceipt.recovery_contract_module_sha256-cne$ExpectedRecoveryContractModuleSha256-or[string]$ProbeBRecoveryReceipt.frozen_input_inventory_sha256-cne$ExpectedFrozenInputInventorySha256-or[int]$ProbeBRecoveryReceipt.frozen_input_count-ne241-or[string]$ProbeBRecoveryReceipt.frozen_input_hash_inventory_sha256-cne'af5e309da4a512bbee1cdf3118e69ac243782715484757410702234f75d94f50'-or
       [int]$ProbeBRecoveryReceipt.runtime_reachable_tooling_hash_mismatch_count-ne0-or[int]$ProbeBRecoveryReceipt.frozen_probe_modification_count-ne0-or[int]$ProbeBRecoveryReceipt.probe_execution_count_delta-ne0-or
       [int]$ProbeBRecoveryReceipt.godot_process_start_count-ne0-or[int]$ProbeBRecoveryReceipt.mcp_process_start_count-ne0-or[int]$ProbeBRecoveryReceipt.startup_probe_invocation_count-ne0-or
       [int]$ProbeBRecoveryReceipt.import_invocation_count-ne0-or[int]$ProbeBRecoveryReceipt.finalizer_invocation_count-ne0-or[int]$ProbeBRecoveryReceipt.formal_mcp_execution_count-ne0-or[int]$ProbeBRecoveryReceipt.authorized_run_count_consumed-ne0-or[string]$ProbeBRecoveryReceipt.canonical_payload_sha256-cne(Get-Pr90ProbeBCanonicalSha256 $ProbeBRecoveryReceipt)){$errors.Add('PROBE_B_RECOVERY_RECEIPT_CONTRACT_MISMATCH')}
    if($null-eq$Preformal-or[string]$Preformal.run_id-cne'pr90-attempt22-preformal-dry-run-v2-002'-or[string]$Preformal.status-cne'PASS'-or[int]$Preformal.check_count-ne22-or[int]$Preformal.pass_count-ne22-or[int]$Preformal.fail_count-ne0-or
       [string]$Preformal.tooling_head_sha-cne$ExpectedToolingHeadSha-or[string]$Preformal.tooling_tree_sha-cne$ExpectedToolingTreeSha-or[string]$Preformal.tooling_seal_sha256-cne$ExpectedToolingSealSha256-or
       [string]$Preformal.probe_b_execution_tooling_head_sha-cne$ExpectedProbeExecutionToolingHeadSha-or[string]$Preformal.probe_b_execution_tooling_tree_sha-cne$ExpectedProbeExecutionToolingTreeSha-or
       [string]$Preformal.probe_b_recovery_tooling_head_sha-cne$ExpectedProbeRecoveryToolingHeadSha-or[string]$Preformal.probe_b_recovery_tooling_tree_sha-cne$ExpectedProbeRecoveryToolingTreeSha-or
       [string]$Preformal.probe_b_post_import_baseline_sha256-cne$ExpectedProbeBBaselineSha256-or[string]$Preformal.probe_b_class_cache_sha256-cne$ExpectedProbeBClassCacheSha256-or
       [string]$Preformal.sealed_baseline_sha256-cne$ExpectedBaselineSha256-or[string]$Preformal.class_cache_sha256-cne$ExpectedClassCacheSha256-or
       [int]$Preformal.product_process_count_after-ne0-or[int]$Preformal.mcp_product_process_count-ne0-or[int]$Preformal.protected_listener_count_after-ne0-or
       [bool]$Preformal.formal_authorization_consumed-or-not[bool]$Preformal.reaches_formal_start_boundary){$errors.Add('PREFORMAL_CONTRACT_MISMATCH')}
    return [pscustomobject][ordered]@{status=if($errors.Count-eq0){'PASS'}else{'BLOCKED'};error_count=$errors.Count;errors=@($errors)}
}

function Get-Pr90ProductProcessRowsV1 {
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($process in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { [string]$_.Name -match '^Godot.*\.exe$' })) {
        $rows.Add([pscustomobject][ordered]@{pid=[int]$process.ProcessId;name=[string]$process.Name;command_line=[string]$process.CommandLine})
    }
    return @($rows)
}

function Test-Pr90McpSupportProcessCommandLineV2 {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [AllowEmptyString()][string]$CommandLine = '',
        [AllowEmptyString()][string]$IdentityText = '',
        [Parameter(Mandatory = $true)][string]$ExpectedWatchdogScriptPath,
        [int]$CurrentProcessId = $PID
    )
    if ($ProcessId -eq $CurrentProcessId -or [string]::IsNullOrWhiteSpace($CommandLine)) { return $false }
    $modeMatch = [regex]::Match($CommandLine, '(?i)(?:^|\s)-(?<mode>CommandWithArgs|CommandWithArg|CommandWithAr|CommandWithA|CommandWith|CommandWit|CommandWi|CommandW|Command|Comman|Comma|Comm|Com|Co|Cwa|C|EncodedCommand|EncodedComman|EncodedComma|EncodedComm|EncodedCom|EncodedCo|EncodedC|Encoded|Encode|Encod|Enco|Enc|En|Ec|E|File|Fil|Fi|F)(?=$|\s|:)')
    if (-not $modeMatch.Success -or [string]$modeMatch.Groups['mode'].Value -notmatch '^(?i:File|Fil|Fi|F)$') { return $false }
    $modeTail = $CommandLine.Substring($modeMatch.Index).TrimStart()
    $fileMatch = [regex]::Match($modeTail, '(?i)^-(?:File|Fil|Fi|F)(?:\s+|:)(?:"(?<path>[^"]+)"|''(?<path>[^'']+)''|(?<path>\S+))')
    if (-not $fileMatch.Success) { return $false }
    $scriptPath = [string]$fileMatch.Groups['path'].Value
    try {
        $scriptFull = [IO.Path]::GetFullPath($scriptPath)
        $expectedWatchdogFull = [IO.Path]::GetFullPath($ExpectedWatchdogScriptPath)
    } catch { return $false }
    $isWatchdog = $scriptFull.Equals($expectedWatchdogFull, [StringComparison]::OrdinalIgnoreCase)
    $isScopedIdentity = -not [string]::IsNullOrWhiteSpace($IdentityText) -and $CommandLine.Contains($IdentityText, [StringComparison]::OrdinalIgnoreCase)
    return ($isWatchdog -or $isScopedIdentity)
}

function Get-Pr90McpSupportProcessRowsV1 {
    param([string]$IdentityText = '')
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($process in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        [string]$_.Name -match '^(?:pwsh|powershell)\.exe$' -and
        (Test-Pr90McpSupportProcessCommandLineV2 -ProcessId ([int]$_.ProcessId) -CommandLine ([string]$_.CommandLine) -IdentityText $IdentityText -ExpectedWatchdogScriptPath (Join-Path $PSScriptRoot 'pr90_attempt21_mcp_startup_watchdog.ps1') -CurrentProcessId $PID)
    })) { $rows.Add([pscustomobject][ordered]@{pid=[int]$process.ProcessId;name=[string]$process.Name;command_line=[string]$process.CommandLine}) }
    return @($rows)
}

function Get-Pr90ProtectedListenerRowsV1 {
    param([int[]]$Ports = @(7576,7586))
    return @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { [int]$_.LocalPort -in $Ports } | ForEach-Object {
        [pscustomobject][ordered]@{local_address=[string]$_.LocalAddress;local_port=[int]$_.LocalPort;owning_pid=[int]$_.OwningProcess}
    })
}

function Test-Pr90Attempt22ManifestObjectV4 {
    param(
        [Parameter(Mandatory = $true)][object]$Manifest,
        [Parameter(Mandatory = $true)][string]$ExpectedProductHead,
        [Parameter(Mandatory = $true)][string]$ExpectedProductTree,
        [Parameter(Mandatory = $true)][string]$ExpectedToolingHead,
        [Parameter(Mandatory = $true)][string]$ExpectedToolingTree,
        [Parameter(Mandatory = $true)][string]$ExpectedToolingSealSha256,
        [string]$ExpectedRemoteToolingHead = '',
        [bool]$FormalEvidenceRootExists = $false,
        [string]$ObservedManifestSha256 = '',
        [string]$SidecarManifestSha256 = '',
        [string]$SealManifestSha256 = ''
    )
    $errors = [Collections.Generic.List[string]]::new()
    $names = @($Manifest.PSObject.Properties.Name)
    $requiredFields = @(Get-Pr90Attempt22RequiredFieldsV4)
    foreach ($field in $requiredFields) { if ($names -cnotcontains $field) { $errors.Add("MISSING_FIELD:$field") } }
    foreach ($field in $names) { if ($requiredFields -cnotcontains $field) { $errors.Add("UNEXPECTED_FIELD:$field") } }
    if ([string]$Manifest.authorization_schema_version -cne 'SpaceSyndicatePr90CanonicalImportAuthorityV4Attempt22') { $errors.Add('SCHEMA_MISMATCH') }
    if ([string]$Manifest.authorization_status -cne 'AUTHORIZED_FOR_ONE_EXACT_SHA_MCP_AFTER_PREREQUISITES' -or [int]$Manifest.authorized_run_count -ne 1 -or [bool]$Manifest.automatic_retry_allowed) { $errors.Add('AUTHORIZATION_POLICY_MISMATCH') }
    if ([string]$Manifest.product_head_sha -cne $ExpectedProductHead) { $errors.Add('PRODUCT_HEAD_MISMATCH') }
    if ([string]$Manifest.product_tree_sha -cne $ExpectedProductTree) { $errors.Add('PRODUCT_TREE_MISMATCH') }
    if ([string]$Manifest.tooling_head_sha -cne $ExpectedToolingHead -or [string]$Manifest.import_tooling_head_sha -cne $ExpectedToolingHead) { $errors.Add('TOOLING_HEAD_MISMATCH') }
    if ([string]$Manifest.tooling_tree_sha -cne $ExpectedToolingTree -or [string]$Manifest.import_tooling_tree_sha -cne $ExpectedToolingTree) { $errors.Add('TOOLING_TREE_MISMATCH') }
    if ([string]$Manifest.tooling_seal_sha256 -cne $ExpectedToolingSealSha256) { $errors.Add('TOOLING_SEAL_MISMATCH') }
    if ($ExpectedRemoteToolingHead -and [string]$Manifest.tooling_head_sha -cne $ExpectedRemoteToolingHead) { $errors.Add('REMOTE_TOOLING_HEAD_MISMATCH') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.probe004_result_sha256)) { $errors.Add('PROBE004_RESULT_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.probe004_attestation_sha256)) { $errors.Add('PROBE004_ATTESTATION_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_result_sha256)) { $errors.Add('PROBE_B_RESULT_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_attestation_sha256)) { $errors.Add('PROBE_B_ATTESTATION_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_post_import_baseline_sha256)) { $errors.Add('PROBE_B_BASELINE_IDENTITY_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_class_cache_sha256)) { $errors.Add('PROBE_B_CLASS_CACHE_IDENTITY_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_recovery_receipt_sha256)) { $errors.Add('PROBE_B_RECOVERY_RECEIPT_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_recovery_controller_sha256) -or [string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_recovery_contract_module_sha256)) { $errors.Add('PROBE_B_RECOVERY_EXECUTOR_IDENTITY_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.attempt22_contract_module_sha256)) { $errors.Add('ATTEMPT22_CURRENT_CONTRACT_IDENTITY_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_frozen_input_inventory_sha256)) { $errors.Add('PROBE_B_FROZEN_INPUT_INVENTORY_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_execution_start_sha256) -or [string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_execution_config_sha256)) { $errors.Add('PROBE_B_EXECUTION_IDENTITY_EVIDENCE_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_execution_tooling_head_sha) -or [string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_execution_tooling_tree_sha) -or [string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_execution_tooling_seal_sha256)) { $errors.Add('PROBE_B_EXECUTION_TOOLING_IDENTITY_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_recovery_tooling_head_sha) -or [string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_recovery_tooling_tree_sha) -or
        [string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_recovery_tooling_manifest_sha256) -or [string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_recovery_tooling_seal_sha256)) { $errors.Add('PROBE_B_RECOVERY_TOOLING_IDENTITY_MISSING') }
    if ([int]$Manifest.runtime_reachable_tooling_hash_mismatch_count -ne 0) { $errors.Add('RUNTIME_REACHABLE_TOOLING_HASH_MISMATCH') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_finalizer_result_sha256)) { $errors.Add('PROBE_B_FINALIZER_RESULT_MISSING') }
    if ([string]$Manifest.probe_b_import_finalizer_status -cne 'PASS') { $errors.Add('PROBE_B_FINALIZER_NOT_PASS') }
    if ([int]$Manifest.endpoint_ownership_contract_version -ne 2) { $errors.Add('ENDPOINT_OWNERSHIP_VERSION_MISMATCH') }
    if([int]$Manifest.listener_parity_contract_version-ne2-or[string]$Manifest.probe_b_v2_id-cne'pr90-exact-clone-startup-probe-b-v2-001'-or[string]::IsNullOrWhiteSpace([string]$Manifest.listener_forensics_sha256)){$errors.Add('LISTENER_PARITY_V2_CONTRACT_MISMATCH')}
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.preformal_dry_run_sha256)) { $errors.Add('PREFORMAL_MISSING') }
    if ([int]$Manifest.preformal_v2_check_count -ne 22 -or [int]$Manifest.preformal_v2_pass_count -ne 22 -or [int]$Manifest.preformal_v2_fail_count -ne 0) { $errors.Add('PREFORMAL_NOT_22_OF_22') }
    if ([int]$Manifest.formal_gate_1_79_receipt_pass_count -ne 79 -or [int]$Manifest.formal_gate_1_79_receipt_fail_count -ne 0) { $errors.Add('FORMAL_GATE_RECEIPT_MISMATCH') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.class_cache_sha256)) { $errors.Add('CLASS_CACHE_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.sealed_baseline_sha256)) { $errors.Add('BASELINE_MISSING') }
    if ([string]$Manifest.probe_b_class_cache_sha256 -cne [string]$Manifest.class_cache_sha256) { $errors.Add('PROBE_B_FORMAL_CLASS_CACHE_PARITY_MISMATCH') }
    if ([string]$Manifest.probe_b_post_import_baseline_sha256 -ceq [string]$Manifest.sealed_baseline_sha256) { $errors.Add('PROBE_B_FORMAL_BASELINE_IDENTITY_COLLAPSED') }
    if ([string]$Manifest.sealed_post_import_baseline_sha256 -cne [string]$Manifest.sealed_baseline_sha256) { $errors.Add('BASELINE_ALIAS_MISMATCH') }
    if ([string]$Manifest.import_finalizer_dry_run_sha256 -cne [string]$Manifest.import_finalizer_dry_run_evidence_sha256) { $errors.Add('IMPORT_FINALIZER_DRY_RUN_ALIAS_MISMATCH') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.formal_authorization_validation_receipt_path) -or [string]::IsNullOrWhiteSpace([string]$Manifest.formal_authorization_seal_path) -or
        [string]::IsNullOrWhiteSpace([string]$Manifest.formal_authorization_consumption_receipt_path) -or [string]::IsNullOrWhiteSpace([string]$Manifest.formal_prelaunch_ignored_inventory_path) -or
        [string]::IsNullOrWhiteSpace([string]$Manifest.formal_terminal_manifest_path) -or [string]::IsNullOrWhiteSpace([string]$Manifest.formal_finalizer_result_path)) { $errors.Add('FORMAL_AUTHORIZATION_OR_CLEANUP_PLAN_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.godot_executable_sha256)) { $errors.Add('GODOT_BINARY_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.godot_gui_path) -or [string]::IsNullOrWhiteSpace([string]$Manifest.godot_gui_sha256)) { $errors.Add('GODOT_GUI_IDENTITY_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.godot_console_sha256)) { $errors.Add('GODOT_CONSOLE_BINARY_MISSING') }
    if ([string]$Manifest.godot_path -cne [string]$Manifest.godot_console_path -or [string]$Manifest.godot_executable_sha256 -cne [string]$Manifest.godot_console_sha256) { $errors.Add('GODOT_COMPAT_CONSOLE_ALIAS_MISMATCH') }
    if ([string]$Manifest.godot_gui_path -ieq [string]$Manifest.godot_console_path -or [string]$Manifest.godot_gui_sha256 -ceq [string]$Manifest.godot_console_sha256) { $errors.Add('GODOT_GUI_CONSOLE_IDENTITY_COLLAPSED') }
    if ($ObservedManifestSha256 -and $SidecarManifestSha256 -and $ObservedManifestSha256 -cne $SidecarManifestSha256) { $errors.Add('MANIFEST_SIDECAR_MISMATCH') }
    if ($ObservedManifestSha256 -and $SealManifestSha256 -and $ObservedManifestSha256 -cne $SealManifestSha256) { $errors.Add('MANIFEST_SEAL_MISMATCH') }
    if ($FormalEvidenceRootExists) { $errors.Add('AUTHORIZED_RUN_ID_REUSED') }
    return [pscustomobject][ordered]@{status=if($errors.Count -eq 0){'PASS'}else{'BLOCKED'};error_count=$errors.Count;errors=@($errors)}
}

Export-ModuleMember -Function *
