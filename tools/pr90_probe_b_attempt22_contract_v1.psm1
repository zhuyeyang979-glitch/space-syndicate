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
        'authorization_negative_test_pass_count','authorization_negative_test_fail_count','attempt22_authorization_missing_contract_count','godot_console_path','godot_console_sha256',
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

function Test-Pr90Attempt22FormalRepairSelfTestReceiptV1 {
    param([AllowNull()][object]$Receipt)
    $requiredCases=@(
        'ATTEMPT19_COMPAT_IMPORT_RUNNER_BOUND_IN_TOOLING_AUTHORITY',
        'RECOVERY_IDENTITY_SEPARATE_FROM_FORMAL_TOOLING',
        'PROBE_B_AND_FORMAL_BASELINE_IDENTITIES_SEPARATED',
        'FORMAL_AUTHORIZATION_SEAL_AND_ATOMIC_CONSUMPTION_BOUND',
        'FORMAL_STATE_MACHINE_ACCOUNTING_CONSUMED',
        'FORMAL_RESULT_AFTER_CLEANUP_AND_FINALIZER_ONLY',
        'STALE_326_SELFTEST_REJECTED',
        'STALE_V1_SELFTEST_REJECTED'
    )
    if($null-eq$Receipt){return $false}
    $requiredFields=@('schema','selftest_revision','status','created_at_utc','base_tooling_selftest_case_count','base_tooling_selftest_pass_count','new_selftest_case_count','new_selftest_pass_count','new_selftest_failure_count','total_tooling_selftest_pass_count','total_tooling_selftest_failure_count','authorization_negative_test_count','authorization_negative_test_pass_count','authorization_negative_test_fail_count','false_green_count','missing_prerequisite_false_accept_count','stale_tooling_false_accept_count','missing_probe_b_false_accept_count','invalid_preformal_false_accept_count','reused_run_id_false_accept_count','selftest_report_version_exact_match','selftest_unknown_version_false_accept_count','selftest_missing_version_false_accept_count','stale_326_report_accept_count','stale_326_report_rejection_green','historical_326_report_mutation_count','powershell_parse_error_count','powershell_parameter_binding_exception_count','selftest_case_name_inventory_sha256','parameter_binding_failures','cases','canonical_payload_sha256')
    if(@(Compare-Object -ReferenceObject $requiredFields -DifferenceObject @($Receipt.PSObject.Properties.Name)).Count-ne0){return $false}
    $revision=Get-Pr90ProbeBOptionalPropertyValueV1 -InputObject $Receipt -Name 'selftest_revision'
    if([string]$Receipt.schema-cne'Pr90ProbeBV2ResultRecoveryToolingSelfTestV1'-or[string]$Receipt.status-cne'PASS'-or
       [string]$revision-cne'PR90_ATTEMPT22_FORMAL_BASELINE_IDENTITY_SPLIT_V2'-or[int]$Receipt.base_tooling_selftest_pass_count-ne326-or
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
        if($diffRows.Count-ne5-or@($diffRows|Where-Object{[string]$_.status-cne'M'}).Count-ne0-or@($diffPaths|Select-Object -Unique).Count-ne5-or@(Compare-Object $expectedDiff $diffPaths).Count-ne0){return $false}
        $rows=@($Manifest.tooling_files);$paths=@($rows|ForEach-Object{([string]$_.relative_path).Replace('\','/')}|Sort-Object);$basePaths=@($BaseManifest.tooling_files|ForEach-Object{([string]$_.relative_path).Replace('\','/')}|Sort-Object)
        if([int]$Manifest.tooling_file_count-ne$rows.Count-or$rows.Count-ne@($paths|Select-Object -Unique).Count-or@(Compare-Object $basePaths $paths).Count-ne0){return $false}
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
    if ([string]::IsNullOrWhiteSpace([string]$Manifest.godot_console_sha256)) { $errors.Add('GODOT_CONSOLE_BINARY_MISSING') }
    if ($ObservedManifestSha256 -and $SidecarManifestSha256 -and $ObservedManifestSha256 -cne $SidecarManifestSha256) { $errors.Add('MANIFEST_SIDECAR_MISMATCH') }
    if ($ObservedManifestSha256 -and $SealManifestSha256 -and $ObservedManifestSha256 -cne $SealManifestSha256) { $errors.Add('MANIFEST_SEAL_MISMATCH') }
    if ($FormalEvidenceRootExists) { $errors.Add('AUTHORIZED_RUN_ID_REUSED') }
    return [pscustomobject][ordered]@{status=if($errors.Count -eq 0){'PASS'}else{'BLOCKED'};error_count=$errors.Count;errors=@($errors)}
}

Export-ModuleMember -Function *
