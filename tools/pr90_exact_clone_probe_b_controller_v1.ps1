[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$ConfigPath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_probe_b_attempt22_contract_v1.psm1') -Force

function New-ProbeSceneIsolationAuditV1 {
    param([string]$Worktree,[string]$ProbeScenePath,[string]$ExpectedProbeSceneSha256)
    $root=(Resolve-Path -LiteralPath $Worktree).Path
    $queue=[Collections.Generic.Queue[string]]::new();$queue.Enqueue($ProbeScenePath)
    $visited=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $paths=[Collections.Generic.List[string]]::new();$unresolved=[Collections.Generic.List[string]]::new();$mainReferences=[Collections.Generic.List[string]]::new();$dynamicLoadSites=[Collections.Generic.List[string]]::new()
    while($queue.Count-gt0){
        $resourcePath=$queue.Dequeue()
        if(-not$visited.Add($resourcePath)){continue}
        if($resourcePath-in@('res://scenes/main.tscn','res://main.tscn')){$mainReferences.Add($resourcePath);continue}
        if(-not$resourcePath.StartsWith('res://',[StringComparison]::Ordinal)){$unresolved.Add($resourcePath);continue}
        $relative=$resourcePath.Substring(6).Replace('/',[IO.Path]::DirectorySeparatorChar)
        $full=[IO.Path]::GetFullPath((Join-Path $root $relative))
        if(-not$full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)-or-not(Test-Path -LiteralPath $full -PathType Leaf)){$unresolved.Add($resourcePath);continue}
        $paths.Add($full)
        if([IO.Path]::GetExtension($full)-notin@('.gd','.tscn','.tres','.cfg')){continue}
        $text=[IO.File]::ReadAllText($full)
        foreach($match in [regex]::Matches($text,'res://[A-Za-z0-9_./@+\-]+')){$dependency=[string]$match.Value;if($dependency-in@('res://scenes/main.tscn','res://main.tscn')){$mainReferences.Add($dependency)}else{$queue.Enqueue($dependency)}}
        foreach($match in [regex]::Matches($text,'(?im)\b(?:load|preload)\s*\(\s*(?!["'']res://)')){$dynamicLoadSites.Add("$resourcePath@$($match.Index)")}
    }
    $projectPath=Join-Path $root 'project.godot';$projectText=[IO.File]::ReadAllText($projectPath)
    $autoloadPaths=@([regex]::Matches($projectText,'(?m)^\s*[A-Za-z0-9_]+\s*=\s*"\*?(res://[^"]+)"\s*$')|ForEach-Object{$_.Groups[1].Value})
    $autoloadGreen=$autoloadPaths.Count-eq1-and[string]$autoloadPaths[0]-ceq'res://addons/funplay_mcp/runtime/funplay_mcp_runtime_bridge.gd'
    if($autoloadGreen){$autoloadFull=Join-Path $root ([string]$autoloadPaths[0]).Substring(6).Replace('/',[IO.Path]::DirectorySeparatorChar);if(Test-Path -LiteralPath $autoloadFull -PathType Leaf){$paths.Add([IO.Path]::GetFullPath($autoloadFull))}else{$autoloadGreen=$false}}
    $inventory=Get-Pr90ProbeBFileInventoryV1 -Paths @($paths|Sort-Object -Unique)
    $sceneFull=Join-Path $root $ProbeScenePath.Substring(6).Replace('/',[IO.Path]::DirectorySeparatorChar)
    $sceneSha=Get-Pr90ProbeBSha256 $sceneFull
    $green=$ProbeScenePath-ceq'res://scenes/runtime/ActionResultPresentationService.tscn'-and$sceneSha-ceq$ExpectedProbeSceneSha256-and$mainReferences.Count-eq0-and$dynamicLoadSites.Count-eq0-and$unresolved.Count-eq0-and$autoloadGreen
    $audit=[pscustomobject][ordered]@{schema='Pr90ProbeBSceneIsolationAuditV1';status=if($green){'PASS'}else{'BLOCKED'};authorized_probe_scene_path=$ProbeScenePath;authorized_probe_scene_sha256=$sceneSha;autoload_paths=$autoloadPaths;autoload_contract_green=$autoloadGreen;resource_file_count=$inventory.count;resource_inventory_sha256=$inventory.inventory_sha256;resource_files=$inventory.rows;unresolved_resource_count=$unresolved.Count;unresolved_resources=@($unresolved);dynamic_resource_load_count=$dynamicLoadSites.Count;dynamic_resource_load_sites=@($dynamicLoadSites);main_tscn_dependency_count=$mainReferences.Count;main_tscn_dependencies=@($mainReferences);main_tscn_instance_count=0;proof_method='exact custom scene request + sealed recursive static scene/script dependency graph + exact runtime bridge autoload';canonical_payload_sha256=''}
    $audit.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $audit
    return $audit
}

$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json -Depth 100
if ([string]$config.schema -cne 'Pr90ExactCloneProbeBV2ExecutionConfigV1') { throw 'Probe B V2 config schema mismatch.' }
if ([string]$config.probe_id -cne 'pr90-exact-clone-startup-probe-b-v2-001') { throw 'Probe B V2 identity mismatch.' }
if([string]$config.probe_scene_path-cne'res://scenes/runtime/ActionResultPresentationService.tscn'-or[string]$config.probe_scene_sha256-cne'f3a1fb397e820adb4beddc0f641e7c77173b1e4f6fe609796a8887cabdf8adc8'){throw 'Authorized Probe B scene identity mismatch.'}
$probeRoot = [IO.Path]::GetFullPath([string]$config.probe_root)
if (Test-Path -LiteralPath $probeRoot) { throw 'Probe B root must be new.' }
if (@(Get-Pr90ProductProcessRowsV1).Count -ne 0) { throw 'A Godot product process is already running.' }
if (@(Get-Pr90McpSupportProcessRowsV1).Count -ne 0) { throw 'An MCP support or watchdog process is already running.' }
if (@(Get-Pr90ProtectedListenerRowsV1).Count -ne 0) { throw 'A protected endpoint is already listening.' }
$toolingRoot = (Resolve-Path -LiteralPath ([string]$config.tooling_worktree)).Path
$toolingHead = (& git -C $toolingRoot rev-parse HEAD).Trim()
$toolingTree = (& git -C $toolingRoot rev-parse 'HEAD^{tree}').Trim()
$toolingParent = (& git -C $toolingRoot rev-parse 'HEAD^').Trim()
if ($toolingHead -cne [string]$config.tooling_head_sha -or $toolingTree -cne [string]$config.tooling_tree_sha -or $toolingParent -cne [string]$config.tooling_parent_sha) { throw 'Tooling identity mismatch.' }
if (@(& git -C $toolingRoot status --porcelain=v1 --untracked-files=all).Count -ne 0) { throw 'Tooling worktree must be clean.' }
if ((Get-Pr90ProbeBSha256 $config.tooling_manifest_path) -cne [string]$config.tooling_manifest_sha256 -or (Get-Pr90ProbeBSha256 $config.tooling_seal_path) -cne [string]$config.tooling_seal_sha256) { throw 'Tooling manifest/seal hash mismatch.' }
if((Get-Pr90ProbeBSha256 ([string]$config.godot_gui_path))-cne[string]$config.godot_gui_sha256-or(Get-Pr90ProbeBSha256 ([string]$config.godot_console_path))-cne[string]$config.godot_console_sha256){throw 'Godot GUI/console binary identity mismatch.'}
$expectedListenerForensicsSha='9d95f7af6d4784b7ee218a570e2a668567e7d6ac58e7194b5863f5fdd6610f3f'
if([string]$config.listener_forensics_sha256-cne$expectedListenerForensicsSha-or(Get-Pr90ProbeBSha256 ([string]$config.listener_forensics_path))-cne$expectedListenerForensicsSha){throw 'Frozen 23-sample listener forensics identity mismatch.'}
$listenerForensics=Get-Content -Raw -LiteralPath ([string]$config.listener_forensics_path)|ConvertFrom-Json -Depth 100
if([string]$listenerForensics.status-cne'ROOT_CAUSE_RESOLVED'-or[int]$listenerForensics.sample_count-ne23-or[int]$listenerForensics.old_parity_count-ne0-or[int]$listenerForensics.listener_core_equal_sample_count-ne23-or[string]$listenerForensics.root_cause_class-cne'J'-or[bool]$listenerForensics.characterization_probe_required-or[int]$listenerForensics.characterization_probe_execution_count-ne0){throw 'Frozen listener forensics contract mismatch.'}
$expectedProbe004ResultSha='d49898f69f962dadadab3067e9f47cf153545bd0d77ab6e7a816845fa092494b'
$expectedProbe004AttestationSha='c518b7226839a3853a718637d2f57e531904ab41e12cf44d86070fe318ff4b0d'
if([string]$config.probe004_result_sha256-cne$expectedProbe004ResultSha-or[string]$config.probe004_attestation_sha256-cne$expectedProbe004AttestationSha-or
   (Get-Pr90ProbeBSha256 ([string]$config.probe004_result_path))-cne$expectedProbe004ResultSha-or(Get-Pr90ProbeBSha256 ([string]$config.probe004_attestation_path))-cne$expectedProbe004AttestationSha){throw 'Frozen Probe 004 byte identity mismatch.'}
$probe004Result=Get-Content -Raw -LiteralPath ([string]$config.probe004_result_path)|ConvertFrom-Json -Depth 100
$probe004Attestation=Get-Content -Raw -LiteralPath ([string]$config.probe004_attestation_path)|ConvertFrom-Json -Depth 100
if([string]$probe004Result.schema-cne'SpaceSyndicatePr90EndpointOwnershipV2PostRepairM0M11ResultV1'-or[string]$probe004Result.status-cne'PASS'-or[string]$probe004Result.probe_id-cne'pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-004'-or[int]$probe004Result.milestone_count-ne12){throw 'Frozen Probe 004 result contract mismatch.'}
if([string]$probe004Attestation.schema-cne'SpaceSyndicatePr90EndpointOwnershipV2PostRepairM0M11AttestationV1'-or[string]$probe004Attestation.status-cne'SEALED'-or[string]$probe004Attestation.probe_id-cne'pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-004'-or
   [string]$probe004Attestation.result_sha256-cne$expectedProbe004ResultSha-or[string]$probe004Attestation.tooling_head_sha-cne'7eda5b355759dbad952beeebd16e3b2d3b20b4f0'-or[string]$probe004Attestation.tooling_tree_sha-cne'41c9cd45e57e987036102dcf10cd1c34385f864b'-or
   [string]$probe004Attestation.product_head_sha-cne[string]$config.product_head_sha-or[string]$probe004Attestation.product_tree_sha-cne[string]$config.product_tree_sha-or[int]$probe004Attestation.post_repair_probe_execution_count-ne1-or[int]$probe004Attestation.new_probe_execution_count-ne1-or
   [bool]$probe004Attestation.automatic_retry_allowed-or[int]$probe004Attestation.formal_mcp_execution_count-ne0-or[int]$probe004Attestation.authorized_run_count_consumed-ne0-or-not[bool]$probe004Attestation.post_repair_m0_m11_probe_green-or[bool]$probe004Attestation.tooling_bytes_changed_by_probe){throw 'Frozen Probe 004 attestation contract mismatch.'}
$toolingManifest=Get-Content -Raw -LiteralPath ([string]$config.tooling_manifest_path)|ConvertFrom-Json -Depth 100
$toolingSeal=Get-Content -Raw -LiteralPath ([string]$config.tooling_seal_path)|ConvertFrom-Json -Depth 100
if([string]$toolingManifest.schema-cne'Pr90ListenerParityV2ToolingManifestV1'-or[string]$toolingManifest.status-cne'READY'-or-not[bool]$toolingManifest.startup_probe_b_authorization_eligible-or
   [string]$toolingManifest.tooling_head_sha-cne$toolingHead-or[string]$toolingManifest.tooling_tree_sha-cne$toolingTree-or[string]$toolingManifest.tooling_parent_sha-cne$toolingParent-or
   [string]$toolingManifest.authorized_probe_scene_path-cne[string]$config.probe_scene_path-or[string]$toolingManifest.authorized_probe_scene_sha256-cne[string]$config.probe_scene_sha256-or
   [string]$toolingManifest.authorized_probe_b_v2_id-cne[string]$config.probe_id-or[int]$toolingManifest.listener_parity_contract_version-ne2-or-not[bool]$toolingManifest.bracketed_sample_model-or[int]$toolingManifest.listener_core_parity_key_field_count-ne5-or
   [int]$toolingManifest.observer_specific_field_in_key_count-ne0-or[int]$toolingManifest.process_enrichment_field_in_key_count-ne0-or[string]$toolingManifest.listener_forensics_sha256-cne$expectedListenerForensicsSha-or[int]$toolingManifest.characterization_probe_execution_count-ne0-or
   [int]$toolingManifest.new_tooling_diff_count-ne19-or[int]$toolingManifest.total_selftest_pass_count-lt211-or[int]$toolingManifest.total_selftest_failure_count-ne0-or
   [string]$toolingManifest.canonical_payload_sha256-cne(Get-Pr90ProbeBCanonicalSha256 $toolingManifest)){throw 'Tooling manifest is not cross-bound to the exact executable identity.'}
if([string]$toolingSeal.schema-cne'Pr90ListenerParityV2ToolingSealV1'-or[string]$toolingSeal.status-cne'SEALED'-or[string]$toolingSeal.tooling_head_sha-cne$toolingHead-or[string]$toolingSeal.tooling_tree_sha-cne$toolingTree-or
   [string]$toolingSeal.tooling_parent_sha-cne$toolingParent-or[string]$toolingSeal.manifest_sha256-cne[string]$config.tooling_manifest_sha256-or
   [string]$toolingSeal.authorized_probe_scene_path-cne[string]$config.probe_scene_path-or[string]$toolingSeal.authorized_probe_scene_sha256-cne[string]$config.probe_scene_sha256-or
   [string]$toolingSeal.authorized_probe_b_v2_id-cne[string]$config.probe_id-or[int]$toolingSeal.listener_parity_contract_version-ne2-or[string]$toolingSeal.listener_core_normalizer_sha256-cne[string]$toolingManifest.listener_core_normalizer_sha256-or[string]$toolingSeal.bracketed_cohort_controller_sha256-cne[string]$toolingManifest.bracketed_cohort_controller_sha256-or
   [string]$toolingSeal.listener_forensics_sha256-cne$expectedListenerForensicsSha-or[int]$toolingSeal.characterization_probe_execution_count-ne0-or
   [string]$toolingSeal.canonical_payload_sha256-cne(Get-Pr90ProbeBCanonicalSha256 $toolingSeal)){throw 'Tooling seal is not cross-bound to the exact manifest and executable identity.'}
$actualToolingInventory=Get-Pr90ProbeBFileInventoryV1 -Paths @($toolingManifest.tooling_files.path)
if([int]$toolingManifest.tooling_file_count-ne@($toolingManifest.tooling_files).Count-or[string]$toolingManifest.tooling_file_hash_inventory_sha256-cne[string]$actualToolingInventory.inventory_sha256){throw 'Tooling manifest file inventory mismatch.'}
$remoteRef = "refs/heads/$([string]$config.tooling_remote_branch)"
$remoteLine = @(& git -C $toolingRoot ls-remote --heads ([string]$config.tooling_repository) $remoteRef)
if ($LASTEXITCODE -ne 0 -or $remoteLine.Count -ne 1 -or ([string]$remoteLine[0]).Split("`t")[0] -cne $toolingHead) { throw 'Remote Tooling identity mismatch.' }
foreach ($binding in @($config.tooling_bindings.PSObject.Properties)) {
    if ((Get-Pr90ProbeBSha256 ([string]$binding.Value.path)) -cne [string]$binding.Value.sha256) { throw "Tooling binding mismatch: $($binding.Name)" }
    $boundRows=@($toolingManifest.tooling_files|Where-Object{[IO.Path]::GetFullPath([string]$_.path)-ceq[IO.Path]::GetFullPath([string]$binding.Value.path)-and[string]$_.sha256-ceq[string]$binding.Value.sha256})
    if($boundRows.Count-ne1){throw "Tooling binding is absent from sealed manifest inventory: $($binding.Name)"}
}
$requiredBindingNames=@('import_controller','import_finalizer_dry_run','import_runner','startup_probe','launch','stop','startup_watchdog','startup_state_machine','startup_contract','getnettcp_listener_adapter','netstat_listener_adapter','listener_core_normalizer','bracketed_cohort_controller','listener_parity_contract','endpoint_ownership_validator','listener_selftest','finalizer_binding','result_builder','attestation_builder')
if(@($requiredBindingNames|Where-Object{$config.tooling_bindings.PSObject.Properties.Name-cnotcontains$_}).Count-ne0){throw 'Required sealed Tooling binding is missing.'}

[IO.Directory]::CreateDirectory($probeRoot) | Out-Null
$clone = Join-Path $probeRoot 'exact-product-clone'
$preparation = Join-Path $probeRoot 'preparation'
[IO.Directory]::CreateDirectory($preparation) | Out-Null
$cloneOutput = @(& git clone --no-checkout --no-tags ([string]$config.product_repository) $clone 2>&1)
if ($LASTEXITCODE -ne 0) { throw "Exact clone failed: $([string]::Join(' | ',[string[]]$cloneOutput))" }
& git -C $clone -c advice.detachedHead=false checkout --detach ([string]$config.product_head_sha) | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Exact product checkout failed.' }
$productHead = (& git -C $clone rev-parse HEAD).Trim()
$productTree = (& git -C $clone rev-parse 'HEAD^{tree}').Trim()
if ($productHead -cne [string]$config.product_head_sha -or $productTree -cne [string]$config.product_tree_sha) { throw 'Exact clone product identity mismatch.' }
if (@(& git -C $clone status --porcelain=v1 --untracked-files=all).Count -ne 0) { throw 'Exact clone is not initially clean.' }
$sceneIsolationAuditPath=Join-Path $preparation 'probe-scene-isolation-audit.json'
$sceneIsolationAudit=New-ProbeSceneIsolationAuditV1 -Worktree $clone -ProbeScenePath ([string]$config.probe_scene_path) -ExpectedProbeSceneSha256 ([string]$config.probe_scene_sha256)
Write-Pr90ProbeBImmutableJson -Path $sceneIsolationAuditPath -Value $sceneIsolationAudit -WriteSha256Sidecar|Out-Null
if(-not(Test-Pr90ProbeBSceneIsolationContractV1 -Audit $sceneIsolationAudit -ExpectedScenePath ([string]$config.probe_scene_path) -ExpectedSceneSha256 ([string]$config.probe_scene_sha256))){throw 'Probe B custom scene isolation audit failed.'}

$importEvidence = Join-Path $preparation 'import-evidence'
$importProfile = Join-Path $preparation 'import-profile'
$importReceipt = Join-Path $preparation 'import-controller-receipt.json'
$importOutput = @(& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File ([string]$config.tooling_bindings.import_controller.path) `
    -Worktree $clone -EvidenceRoot $importEvidence -ProfileRoot $importProfile -GodotPath ([string]$config.godot_gui_path) `
    -ExpectedHeadSha ([string]$config.product_head_sha) -ExpectedTreeSha ([string]$config.product_tree_sha) `
    -LegacyImportEnginePath ([string]$config.legacy_import_engine_path) -ExpectedLegacyImportEngineSha256 ([string]$config.legacy_import_engine_sha256) `
    -SourceClassCachePath ([string]$config.source_class_cache_path) -ExpectedSourceClassCacheSha256 ([string]$config.source_class_cache_sha256) `
    -OutputReceiptPath $importReceipt -OutputReceiptShaPath "$importReceipt.sha256")
if ($LASTEXITCODE -ne 0) { throw "Canonical import failed: $([string]::Join(' | ',[string[]]$importOutput))" }
$baseline = Join-Path $importEvidence 'post-import-authority-baseline.json'
$classCache = Join-Path $clone '.godot/global_script_class_cache.cfg'
$importReceiptObject = Get-Content -Raw -LiteralPath $importReceipt | ConvertFrom-Json -Depth 100
if ([string]$importReceiptObject.status -cne 'PASS' -or -not [bool]$importReceiptObject.import_pass1_2_path_set_parity -or
    -not [bool]$importReceiptObject.import_pass1_2_byte_parity -or [int]$importReceiptObject.import_pass2_new_mutation_count -ne 0 -or
    [int]$importReceiptObject.tracked_import_metadata_unknown_count -ne 0) { throw 'Canonical import receipt is not green.' }
$finalizerDryRunPath = Join-Path $preparation 'import-finalizer-dry-run-v4.json'
$finalizerDryRunOutput = @(& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File ([string]$config.tooling_bindings.import_finalizer_dry_run.path) `
    -OutputPath $finalizerDryRunPath -OutputShaPath "$finalizerDryRunPath.sha256" -ProductHeadSha ([string]$config.product_head_sha) `
    -ProductTreeSha ([string]$config.product_tree_sha) -ToolingHeadSha $toolingHead -ToolingTreeSha $toolingTree `
    -ImportRunnerPath ([string]$config.tooling_bindings.import_runner.path) -BaselinePath $baseline -ExpectedBaselineSha256 (Get-Pr90ProbeBSha256 $baseline) `
    -ClassCachePath $classCache -GodotPath ([string]$config.godot_gui_path) -ExpectedGodotVersion ([string]$config.godot_version) -CloneRoot $clone)
if ($LASTEXITCODE -ne 0) { throw "Import finalizer dry-run failed: $([string]::Join(' | ',[string[]]$finalizerDryRunOutput))" }
$baselineObject=Get-Content -Raw -LiteralPath $baseline|ConvertFrom-Json -Depth 100
$prelaunchIgnoredPaths=@(& git -C $clone -c core.quotePath=false ls-files -o -i --exclude-standard|ForEach-Object{$_.Replace('\','/')}|Sort-Object -Unique)
if($LASTEXITCODE-ne0){throw 'Unable to capture prelaunch ignored path inventory.'}
$prelaunchIgnoredSetSha=Get-Pr90ProbeBStringSetSha256 $prelaunchIgnoredPaths
if($prelaunchIgnoredPaths.Count-ne[int]$baselineObject.ignored_sidecar_count-or$prelaunchIgnoredSetSha-cne[string]$baselineObject.ignored_sidecar_path_set_sha256){throw 'Prelaunch ignored path inventory does not match the sealed post-import baseline.'}
$prelaunchIgnoredInventoryPath=Join-Path $preparation 'prelaunch-ignored-path-inventory.json'
$prelaunchIgnoredInventory=[pscustomobject][ordered]@{schema='Pr90ProbeBPrelaunchIgnoredPathInventoryV1';product_head_sha=[string]$config.product_head_sha;product_tree_sha=[string]$config.product_tree_sha;baseline_sha256=Get-Pr90ProbeBSha256 $baseline;ignored_path_count=$prelaunchIgnoredPaths.Count;ignored_path_set_sha256=$prelaunchIgnoredSetSha;ignored_paths=$prelaunchIgnoredPaths;canonical_payload_sha256=''}
$prelaunchIgnoredInventory.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $prelaunchIgnoredInventory
Write-Pr90ProbeBImmutableJson -Path $prelaunchIgnoredInventoryPath -Value $prelaunchIgnoredInventory -WriteSha256Sidecar|Out-Null

if(@(Get-Pr90ProductProcessRowsV1).Count-ne0-or@(Get-Pr90McpSupportProcessRowsV1).Count-ne0-or@(Get-Pr90ProtectedListenerRowsV1).Count-ne0){throw 'A process or protected listener appeared before the Probe B authorization boundary.'}
if(@(& git -C $toolingRoot status --porcelain=v1 --untracked-files=all).Count-ne0){throw 'Tooling mutated before the Probe B authorization boundary.'}
$remoteLine=@(& git -C $toolingRoot ls-remote --heads ([string]$config.tooling_repository) $remoteRef)
if($LASTEXITCODE-ne0-or$remoteLine.Count-ne1-or([string]$remoteLine[0]).Split("`t")[0]-cne$toolingHead){throw 'Remote Tooling identity drifted before the Probe B authorization boundary.'}

$runtimeEvidence = Join-Path $probeRoot 'evidence'
$runtimeProfile = Join-Path $probeRoot 'runtime-profile'
[IO.Directory]::CreateDirectory($runtimeProfile) | Out-Null
$executionStart = [pscustomobject][ordered]@{
    schema='Pr90ExactCloneProbeBV2ExecutionStartV1';probe_id=[string]$config.probe_id;execution_count=1;probe_b_v2_authorization_consumed=1;authorized_run_count_consumed=0;started_utc=[DateTimeOffset]::UtcNow.ToString('o')
    config_path=[IO.Path]::GetFullPath($ConfigPath);config_sha256=Get-Pr90ProbeBSha256 $ConfigPath;product_head_sha=$productHead;product_tree_sha=$productTree
    tooling_head_sha=$toolingHead;tooling_tree_sha=$toolingTree;tooling_seal_sha256=Get-Pr90ProbeBSha256 $config.tooling_seal_path
    listener_forensics_sha256=$expectedListenerForensicsSha;listener_parity_root_cause_class='J';characterization_probe_execution_count=0
    clone_path_fingerprint=(Get-Pr90ProbeBCanonicalSha256 ([pscustomobject]@{path=$clone.ToLowerInvariant();canonical_payload_sha256=''}))
    isolated_profile=$runtimeProfile;evidence_root=$runtimeEvidence;play_main_scene_count=0;product_match_count=0;formal_mcp_execution_count=0;canonical_payload_sha256=''
}
$executionStart.canonical_payload_sha256 = Get-Pr90ProbeBCanonicalSha256 $executionStart
Write-Pr90ProbeBImmutableJson -Path (Join-Path $probeRoot 'probe-b-execution-start.json') -Value $executionStart -WriteSha256Sidecar | Out-Null

$savedEnvironment = [ordered]@{USERPROFILE=$env:USERPROFILE;APPDATA=$env:APPDATA;LOCALAPPDATA=$env:LOCALAPPDATA;TEMP=$env:TEMP;TMP=$env:TMP}
$startupExitCode = -1
try {
    foreach ($directory in @('profile','appdata-roaming','appdata-local','temp')) { [IO.Directory]::CreateDirectory((Join-Path $runtimeProfile $directory)) | Out-Null }
    $env:USERPROFILE=Join-Path $runtimeProfile 'profile';$env:APPDATA=Join-Path $runtimeProfile 'appdata-roaming';$env:LOCALAPPDATA=Join-Path $runtimeProfile 'appdata-local';$env:TEMP=Join-Path $runtimeProfile 'temp';$env:TMP=$env:TEMP
    $startupOutput = @(& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File ([string]$config.tooling_bindings.startup_probe.path) `
        -ExecutionMode PRE_FORMAL_STARTUP_PROBE -RunId ([string]$config.probe_id) -ProbeIdentity ([string]$config.probe_id) `
        -Worktree $clone -EvidenceRoot $runtimeEvidence -GodotPath ([string]$config.godot_console_path) `
        -ExpectedHeadSha ([string]$config.product_head_sha) -ExpectedTreeSha ([string]$config.product_tree_sha) `
        -LaunchScriptPath ([string]$config.tooling_bindings.launch.path) -ExpectedLaunchScriptSha256 ([string]$config.tooling_bindings.launch.sha256) `
        -StopScriptPath ([string]$config.tooling_bindings.stop.path) -ExpectedStopScriptSha256 ([string]$config.tooling_bindings.stop.sha256) `
        -WatchdogScriptPath ([string]$config.tooling_bindings.startup_watchdog.path) -ExpectedWatchdogScriptSha256 ([string]$config.tooling_bindings.startup_watchdog.sha256) `
        -StateMachineScriptPath ([string]$config.tooling_bindings.startup_state_machine.path) -ExpectedStateMachineSha256 ([string]$config.tooling_bindings.startup_state_machine.sha256) `
        -ContractScriptPath ([string]$config.tooling_bindings.startup_contract.path) -ExpectedContractSha256 ([string]$config.tooling_bindings.startup_contract.sha256) `
        -ProbeScenePath ([string]$config.probe_scene_path) -SealedBaselinePath $baseline -ExpectedSealedBaselineSha256 (Get-Pr90ProbeBSha256 $baseline) `
        -StartupToolingManifestPath ([string]$config.tooling_manifest_path) -ExpectedStartupToolingManifestSha256 ([string]$config.tooling_manifest_sha256) `
        -StartupToolingSealPath ([string]$config.tooling_seal_path) -ExpectedStartupToolingSealSha256 ([string]$config.tooling_seal_sha256) -Port 7576)
    $startupExitCode = $LASTEXITCODE
} finally {
    $env:USERPROFILE=$savedEnvironment.USERPROFILE;$env:APPDATA=$savedEnvironment.APPDATA;$env:LOCALAPPDATA=$savedEnvironment.LOCALAPPDATA;$env:TEMP=$savedEnvironment.TEMP;$env:TMP=$savedEnvironment.TMP
}
$startupContractCrash=($startupExitCode -notin @(0,2))

$finalizerPath = Join-Path $probeRoot 'import-finalizer-result.json'
$finalizerExitCode=-1
$finalizerOutput=@()
$runtimePreservationFailure=''
try{
    $runtimeLocal = Join-Path $clone '.codex-godot'
    if (Test-Path -LiteralPath $runtimeLocal -PathType Container) {
        $preservedRuntime = Join-Path $runtimeEvidence 'role-local-runtime-metadata'
        Copy-Item -LiteralPath $runtimeLocal -Destination $preservedRuntime -Recurse
    }
}catch{$runtimePreservationFailure=$_.Exception.Message}
finally{
    $finalizerOutput = @(& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File ([string]$config.tooling_bindings.finalizer_binding.path) `
        -Worktree $clone -BaselinePath $baseline -ClassCachePath $classCache -GodotPath ([string]$config.godot_gui_path) `
        -ProductHeadSha ([string]$config.product_head_sha) -ProductTreeSha ([string]$config.product_tree_sha) `
        -ImportRunnerPath ([string]$config.tooling_bindings.import_runner.path) -ExpectedImportRunnerSha256 ([string]$config.tooling_bindings.import_runner.sha256) `
        -PrelaunchIgnoredInventoryPath $prelaunchIgnoredInventoryPath -ExpectedPrelaunchIgnoredInventorySha256 (Get-Pr90ProbeBSha256 $prelaunchIgnoredInventoryPath) -OutputPath $finalizerPath)
    $finalizerExitCode=$LASTEXITCODE
}
if ($finalizerExitCode -notin @(0,2)-or-not(Test-Path -LiteralPath $finalizerPath -PathType Leaf)) { throw "Probe B import finalizer failed outside its PASS/BLOCKED evidence contract: exit=$finalizerExitCode; $([string]::Join(' | ',[string[]]$finalizerOutput))" }
$processRows = @(Get-Pr90ProductProcessRowsV1)
$mcpRows = @(Get-Pr90McpSupportProcessRowsV1 -IdentityText ([string]$config.probe_id))
$listenerRows = @(Get-Pr90ProtectedListenerRowsV1)
$terminal = [pscustomobject][ordered]@{
    schema='Pr90ExactCloneProbeBTerminalManifestV1';probe_id=[string]$config.probe_id;status=if($processRows.Count -eq 0 -and $mcpRows.Count -eq 0 -and $listenerRows.Count -eq 0){'PASS'}else{'BLOCKED'}
    created_at_utc=[DateTimeOffset]::UtcNow.ToString('o');godot_process_count=$processRows.Count;mcp_process_count=$mcpRows.Count
    port_7576_count=@($listenerRows|Where-Object{$_.local_port -eq 7576}).Count;port_7586_count=@($listenerRows|Where-Object{$_.local_port -eq 7586}).Count
    process_rows=$processRows;mcp_process_rows=$mcpRows;listener_rows=$listenerRows;unrelated_process_termination_count=0;canonical_payload_sha256=''
}
$terminal.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $terminal
$terminalPath=Join-Path $probeRoot 'terminal-process-port-manifest.json'
Write-Pr90ProbeBImmutableJson -Path $terminalPath -Value $terminal -WriteSha256Sidecar | Out-Null
$resultPath=Join-Path $probeRoot 'pr90_exact_clone_startup_probe_b_v2_result.json'
$resultMarkdown=Join-Path $probeRoot 'pr90_exact_clone_startup_probe_b_v2_result.md'
& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File ([string]$config.tooling_bindings.result_builder.path) -ProbeId ([string]$config.probe_id) -EvidenceRoot $runtimeEvidence `
    -ProductHeadSha ([string]$config.product_head_sha) -ProductTreeSha ([string]$config.product_tree_sha) -ToolingHeadSha $toolingHead -ToolingTreeSha $toolingTree `
    -ToolingSealPath ([string]$config.tooling_seal_path) -PostImportBaselinePath $baseline -ClassCachePath $classCache -GodotGuiPath ([string]$config.godot_gui_path) -GodotConsolePath ([string]$config.godot_console_path) -FinalizerResultPath $finalizerPath `
    -TerminalManifestPath $terminalPath -ProbeScenePath ([string]$config.probe_scene_path) -ExpectedProbeSceneSha256 ([string]$config.probe_scene_sha256) -SceneIsolationAuditPath $sceneIsolationAuditPath `
    -ListenerForensicsPath ([string]$config.listener_forensics_path) -ExpectedListenerForensicsSha256 ([string]$config.listener_forensics_sha256) -OutputPath $resultPath -OutputMarkdownPath $resultMarkdown | Out-Null
$resultExitCode=$LASTEXITCODE
if ($resultExitCode -notin @(0,2)-or-not(Test-Path -LiteralPath $resultPath -PathType Leaf)) { throw 'Probe B V2 result builder failed outside its PASS/BLOCKED evidence contract.' }
$attestationPath=Join-Path $probeRoot 'pr90_exact_clone_startup_probe_b_v2_attestation.json'
& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File ([string]$config.tooling_bindings.attestation_builder.path) -ProbeId ([string]$config.probe_id) -ResultPath $resultPath `
    -EvidenceRoot $runtimeEvidence -Probe004ResultPath ([string]$config.probe004_result_path) -ExpectedProbe004ResultSha256 ([string]$config.probe004_result_sha256) -Probe004AttestationPath ([string]$config.probe004_attestation_path) -ExpectedProbe004AttestationSha256 ([string]$config.probe004_attestation_sha256) `
    -PostImportBaselinePath $baseline -ClassCachePath $classCache -SceneIsolationAuditPath $sceneIsolationAuditPath -ExpectedProbeSceneSha256 ([string]$config.probe_scene_sha256) `
    -ListenerForensicsPath ([string]$config.listener_forensics_path) -ExpectedListenerForensicsSha256 ([string]$config.listener_forensics_sha256) -FinalizerResultPath $finalizerPath -TerminalManifestPath $terminalPath -OutputPath $attestationPath | Out-Null
$attestationExitCode=$LASTEXITCODE
if ($attestationExitCode -notin @(0,2)-or-not(Test-Path -LiteralPath $attestationPath -PathType Leaf)) { throw 'Probe B V2 attestation builder failed outside its SEALED/BLOCKED evidence contract.' }
$resultObject=Get-Content -Raw -LiteralPath $resultPath|ConvertFrom-Json -Depth 100
$attestationObject=Get-Content -Raw -LiteralPath $attestationPath|ConvertFrom-Json -Depth 100
$controllerGreen=(-not$startupContractCrash-and[string]::IsNullOrWhiteSpace($runtimePreservationFailure)-and$startupExitCode-eq0-and$resultExitCode-eq0-and$attestationExitCode-eq0-and[string]$resultObject.status-ceq'PASS'-and[string]$attestationObject.status-ceq'SEALED')
$final = [pscustomobject][ordered]@{schema='Pr90ExactCloneProbeBV2ControllerResultV1';probe_id=[string]$config.probe_id;status=if($controllerGreen){'PASS'}else{'BLOCKED'};probe_execution_count=1;startup_exit_code=$startupExitCode;startup_contract_crash=$startupContractCrash;runtime_preservation_failure=$runtimePreservationFailure;milestone_failure_automatic_scoped_cleanup=$true;external_manual_cleanup_required_count=0;m5_failure_finalizer_execution_count=1;result_path=$resultPath;result_sha256=Get-Pr90ProbeBSha256 $resultPath;attestation_path=$attestationPath;attestation_sha256=Get-Pr90ProbeBSha256 $attestationPath;formal_mcp_execution_count=0;authorized_run_count_consumed=0;canonical_payload_sha256=''}
$final.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $final
Write-Pr90ProbeBImmutableJson -Path (Join-Path $probeRoot 'probe-b-controller-result.json') -Value $final -WriteSha256Sidecar | Out-Null
$final | ConvertTo-Json -Depth 100 -Compress
if(-not$controllerGreen){exit 2}
