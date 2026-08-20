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
        'probe_b_finalizer_result_path','probe_b_finalizer_result_sha256','probe_b_import_finalizer_status','preformal_dry_run_path','preformal_dry_run_sha256','preformal_v2_check_count',
        'preformal_v2_pass_count','preformal_v2_fail_count','authorization_seal_builder_path','authorization_seal_builder_sha256',
        'probe_b_controller_sha256','probe_b_result_builder_sha256','probe_b_attestation_builder_sha256',
        'probe_b_finalizer_binding_sha256','preformal_v2_controller_sha256','authorization_negative_test_count',
        'authorization_negative_test_pass_count','authorization_negative_test_fail_count','attempt22_authorization_missing_contract_count','godot_console_path','godot_console_sha256',
        'sealed_post_import_baseline_sha256','import_finalizer_dry_run_sha256'
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
    return ($MissingContractCount -eq 0 -and $BaseSelfTestPassCount -eq 104 -and $NewSelfTestCaseCount -ge 30 -and
        $NewSelfTestPassCount -eq $NewSelfTestCaseCount -and $FailureCount -eq 0 -and
        $PowerShellParseErrorCount -eq 0 -and $ParameterBindingExceptionCount -eq 0)
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

function Test-Pr90Attempt22EvidenceContractsV1 {
    param(
        [AllowNull()][object]$ProbeB,
        [AllowNull()][object]$ProbeBAttestation,
        [AllowNull()][object]$Preformal,
        [Parameter(Mandatory = $true)][string]$ExpectedProbeBResultSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedProductHeadSha,
        [Parameter(Mandatory = $true)][string]$ExpectedProductTreeSha,
        [Parameter(Mandatory = $true)][string]$ExpectedToolingHeadSha,
        [Parameter(Mandatory = $true)][string]$ExpectedToolingTreeSha,
        [Parameter(Mandatory = $true)][string]$ExpectedToolingSealSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedGodotGuiSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedGodotConsoleSha256
    )
    $errors=[Collections.Generic.List[string]]::new()
    if($null-eq$ProbeB-or[string]$ProbeB.schema-cne'Pr90ExactCloneProbeBV2ResultV1'-or[string]$ProbeB.probe_id-cne'pr90-exact-clone-startup-probe-b-v2-001'-or[string]$ProbeB.status-cne'PASS'-or[string]$ProbeB.import_finalizer_status-cne'PASS'-or
       [string]$ProbeB.product_head_sha-cne$ExpectedProductHeadSha-or[string]$ProbeB.product_tree_sha-cne$ExpectedProductTreeSha-or
       [string]$ProbeB.tooling_head_sha-cne$ExpectedToolingHeadSha-or[string]$ProbeB.tooling_tree_sha-cne$ExpectedToolingTreeSha-or
       [string]$ProbeB.tooling_seal_sha256-cne$ExpectedToolingSealSha256-or[string]$ProbeB.godot_gui_sha256-cne$ExpectedGodotGuiSha256-or[string]$ProbeB.godot_console_sha256-cne$ExpectedGodotConsoleSha256-or
       -not[bool]$ProbeB.bracketed_sample_model-or[int]$ProbeB.total_listener_cohort_attempt_count-lt5-or[int]$ProbeB.consecutive_stable_parity_cohort_count-lt5-or[double]$ProbeB.stable_parity_window_ms-lt1000-or
       -not[bool]$ProbeB.endpoint_listener_core_parity-or[int]$ProbeB.listener_core_parity_key_field_count-ne5-or[int]$ProbeB.matched_listener_process_enrichment_count-ne1-or[int]$ProbeB.duplicate_source_process_enrichment_count-ne0-or
       -not[bool]$ProbeB.endpoint_owner_project_match-or-not[bool]$ProbeB.endpoint_owner_mcp_session_match-or[int]$ProbeB.protected_port_multiple_owner_count-ne0-or[int]$ProbeB.foreign_listener_count-ne0){$errors.Add('PROBE_B_RESULT_CONTRACT_MISMATCH')}
    if($null-eq$ProbeBAttestation-or[string]$ProbeBAttestation.schema-cne'Pr90ExactCloneProbeBV2AttestationV1'-or[string]$ProbeBAttestation.status-cne'SEALED'-or[int]$ProbeBAttestation.unbound_evidence_count-ne0-or[string]$ProbeBAttestation.result_sha256-cne$ExpectedProbeBResultSha256-or
       -not[bool]$ProbeBAttestation.bracketed_sample_model-or[int]$ProbeBAttestation.listener_core_parity_key_field_count-ne5-or[int]$ProbeBAttestation.matched_listener_process_enrichment_count-ne1-or[string]$ProbeBAttestation.raw_listener_evidence_preservation-cne'100_PERCENT'){$errors.Add('PROBE_B_ATTESTATION_CONTRACT_MISMATCH')}
    if($null-eq$Preformal-or[string]$Preformal.run_id-cne'pr90-attempt22-preformal-dry-run-v2-002'-or[string]$Preformal.status-cne'PASS'-or[int]$Preformal.check_count-ne22-or[int]$Preformal.pass_count-ne22-or[int]$Preformal.fail_count-ne0-or
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

function Get-Pr90McpSupportProcessRowsV1 {
    param([string]$IdentityText = '')
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($process in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        [string]$_.Name -match '^(?:pwsh|powershell)\.exe$' -and
        (([string]$_.CommandLine).Contains('pr90_attempt21_mcp_startup_watchdog.ps1',[StringComparison]::OrdinalIgnoreCase) -or
         ($IdentityText -and ([string]$_.CommandLine).Contains($IdentityText,[StringComparison]::OrdinalIgnoreCase)))
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
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.probe_b_finalizer_result_sha256)) { $errors.Add('PROBE_B_FINALIZER_RESULT_MISSING') }
    if ([string]$Manifest.probe_b_import_finalizer_status -cne 'PASS') { $errors.Add('PROBE_B_FINALIZER_NOT_PASS') }
    if ([int]$Manifest.endpoint_ownership_contract_version -ne 2) { $errors.Add('ENDPOINT_OWNERSHIP_VERSION_MISMATCH') }
    if([int]$Manifest.listener_parity_contract_version-ne2-or[string]$Manifest.probe_b_v2_id-cne'pr90-exact-clone-startup-probe-b-v2-001'-or[string]::IsNullOrWhiteSpace([string]$Manifest.listener_forensics_sha256)){$errors.Add('LISTENER_PARITY_V2_CONTRACT_MISMATCH')}
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.preformal_dry_run_sha256)) { $errors.Add('PREFORMAL_MISSING') }
    if ([int]$Manifest.preformal_v2_check_count -ne 22 -or [int]$Manifest.preformal_v2_pass_count -ne 22 -or [int]$Manifest.preformal_v2_fail_count -ne 0) { $errors.Add('PREFORMAL_NOT_22_OF_22') }
    if ([int]$Manifest.formal_gate_1_79_receipt_pass_count -ne 79 -or [int]$Manifest.formal_gate_1_79_receipt_fail_count -ne 0) { $errors.Add('FORMAL_GATE_RECEIPT_MISMATCH') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.class_cache_sha256)) { $errors.Add('CLASS_CACHE_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.sealed_baseline_sha256)) { $errors.Add('BASELINE_MISSING') }
    if ([string]$Manifest.sealed_post_import_baseline_sha256 -cne [string]$Manifest.sealed_baseline_sha256) { $errors.Add('BASELINE_ALIAS_MISMATCH') }
    if ([string]$Manifest.import_finalizer_dry_run_sha256 -cne [string]$Manifest.import_finalizer_dry_run_evidence_sha256) { $errors.Add('IMPORT_FINALIZER_DRY_RUN_ALIAS_MISMATCH') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.godot_executable_sha256)) { $errors.Add('GODOT_BINARY_MISSING') }
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.godot_console_sha256)) { $errors.Add('GODOT_CONSOLE_BINARY_MISSING') }
    if ($ObservedManifestSha256 -and $SidecarManifestSha256 -and $ObservedManifestSha256 -cne $SidecarManifestSha256) { $errors.Add('MANIFEST_SIDECAR_MISMATCH') }
    if ($ObservedManifestSha256 -and $SealManifestSha256 -and $ObservedManifestSha256 -cne $SealManifestSha256) { $errors.Add('MANIFEST_SEAL_MISMATCH') }
    if ($FormalEvidenceRootExists) { $errors.Add('AUTHORIZED_RUN_ID_REUSED') }
    return [pscustomobject][ordered]@{status=if($errors.Count -eq 0){'PASS'}else{'BLOCKED'};error_count=$errors.Count;errors=@($errors)}
}

Export-ModuleMember -Function *
