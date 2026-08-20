[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ConfigPath,
    [Parameter(Mandatory = $true)][string]$ExpectedConfigSha256
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$configActualSha=(Get-FileHash -LiteralPath $ConfigPath -Algorithm SHA256).Hash.ToLowerInvariant()
if($configActualSha-cne$ExpectedConfigSha256.ToLowerInvariant()){throw 'Recovery config hash mismatch.'}
$config=Get-Content -Raw -LiteralPath $ConfigPath|ConvertFrom-Json -Depth 100
if([string]$config.schema-cne'Pr90ProbeBV2ResultRecoveryConfigV1'-or[string]$config.probe_id-cne'pr90-exact-clone-startup-probe-b-v2-001'){throw 'Recovery config identity mismatch.'}
$recoveryRoot=(Resolve-Path -LiteralPath ([string]$config.recovery_tooling_worktree)).Path
$relativeController='tools/pr90_exact_clone_probe_b_postrun_recovery_controller_v1.ps1'
$relativeContract='tools/pr90_probe_b_attempt22_contract_v1.psm1'
$controllerPath=[IO.Path]::GetFullPath((Join-Path $recoveryRoot $relativeController))
$contractPath=[IO.Path]::GetFullPath((Join-Path $recoveryRoot $relativeContract))
if([IO.Path]::GetFullPath($PSCommandPath)-cne$controllerPath-or[IO.Path]::GetFullPath($PSScriptRoot)-cne[IO.Path]::GetFullPath((Join-Path $recoveryRoot 'tools'))){throw 'Recovery controller must execute from the configured Tooling worktree.'}
$recoveryHead=(& git -C $recoveryRoot rev-parse HEAD).Trim();$recoveryTree=(& git -C $recoveryRoot rev-parse 'HEAD^{tree}').Trim();$recoveryParent=(& git -C $recoveryRoot rev-parse 'HEAD^').Trim()
if($recoveryHead-cne[string]$config.recovery_tooling_head_sha-or$recoveryTree-cne[string]$config.recovery_tooling_tree_sha-or$recoveryParent-cne[string]$config.recovery_tooling_parent_sha-or$recoveryParent-cne'2ebb2df9a1c649e8527b045939e9d6e47b98f17c'){throw 'Recovery Tooling identity mismatch.'}
if(@(& git -C $recoveryRoot status --porcelain=v1 --untracked-files=all).Count-ne0){throw 'Recovery Tooling worktree must be clean.'}
$recoveryManifestPath=[IO.Path]::GetFullPath([string]$config.recovery_tooling_manifest_path)
$recoverySealPath=[IO.Path]::GetFullPath([string]$config.recovery_tooling_seal_path)
$manifestActualSha=(Get-FileHash -LiteralPath $recoveryManifestPath -Algorithm SHA256).Hash.ToLowerInvariant();$sealActualSha=(Get-FileHash -LiteralPath $recoverySealPath -Algorithm SHA256).Hash.ToLowerInvariant()
if($manifestActualSha-cne[string]$config.recovery_tooling_manifest_sha256-or$sealActualSha-cne[string]$config.recovery_tooling_seal_sha256){throw 'Recovery Tooling authority hash mismatch.'}
$recoveryManifest=Get-Content -Raw -LiteralPath $recoveryManifestPath|ConvertFrom-Json -Depth 100
$recoverySeal=Get-Content -Raw -LiteralPath $recoverySealPath|ConvertFrom-Json -Depth 100
$controllerSha=(Get-FileHash -LiteralPath $controllerPath -Algorithm SHA256).Hash.ToLowerInvariant();$contractSha=(Get-FileHash -LiteralPath $contractPath -Algorithm SHA256).Hash.ToLowerInvariant()
if([string]$recoveryManifest.schema-cne'Pr90ProbeBV2ResultRecoveryToolingManifestV1'-or[string]$recoveryManifest.status-cne'READY'-or[string]$recoveryManifest.tooling_head_sha-cne$recoveryHead-or[string]$recoveryManifest.tooling_tree_sha-cne$recoveryTree-or[int]$recoveryManifest.runtime_reachable_tooling_hash_mismatch_count-ne0-or
   [string]$recoveryManifest.probe_b_recovery_controller_sha256-cne$controllerSha-or[string]$recoveryManifest.probe_b_recovery_contract_module_sha256-cne$contractSha-or
   [string]$recoverySeal.schema-cne'Pr90ProbeBV2ResultRecoveryToolingSealV1'-or[string]$recoverySeal.status-cne'SEALED'-or[string]$recoverySeal.manifest_sha256-cne$manifestActualSha-or[string]$recoverySeal.probe_b_recovery_controller_sha256-cne$controllerSha-or[string]$recoverySeal.probe_b_recovery_contract_module_sha256-cne$contractSha){throw 'Recovery Tooling authority contract mismatch.'}
foreach($selfBinding in @(@($relativeController,$controllerPath,$controllerSha),@($relativeContract,$contractPath,$contractSha))){
    $relative=[string]$selfBinding[0];$path=[string]$selfBinding[1];$sha=[string]$selfBinding[2]
    $row=@($recoveryManifest.tooling_files|Where-Object{([string]$_.relative_path).Replace('\','/')-ceq$relative})
    $commitBlob=(& git -C $recoveryRoot rev-parse "HEAD:$relative").Trim();$workingBlob=(& git -C $recoveryRoot hash-object -- $path).Trim()
    if($row.Count-ne1-or[IO.Path]::GetFullPath([string]$row[0].path)-cne$path-or[string]$row[0].sha256-cne$sha-or[string]$row[0].git_blob_sha-cne$commitBlob-or$workingBlob-cne$commitBlob){throw "Recovery controller self-binding mismatch: $relative"}
}
Import-Module $contractPath -Force
$frozenRoot=(Resolve-Path -LiteralPath ([string]$config.frozen_probe_root)).Path
$outputRoot=[IO.Path]::GetFullPath([string]$config.output_root)
if(Test-Path -LiteralPath $outputRoot){throw 'Recovery output root must be new.'}
$frozenPrefix=$frozenRoot.TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
$outputPrefix=$outputRoot.TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
if($outputPrefix.StartsWith($frozenPrefix,[StringComparison]::OrdinalIgnoreCase)-or$frozenPrefix.StartsWith($outputPrefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Recovery output root must be external to the frozen Probe root.'}
$executionConfigPath=[IO.Path]::GetFullPath([string]$config.execution_config_path)
$executionStartPath=[IO.Path]::GetFullPath([string]$config.execution_start_path)
if((Get-Pr90ProbeBSha256 $executionConfigPath)-cne[string]$config.execution_config_sha256-or(Get-Pr90ProbeBSha256 $executionStartPath)-cne[string]$config.execution_start_sha256){throw 'Frozen execution config/start hash mismatch.'}
$executionConfig=Get-Content -Raw -LiteralPath $executionConfigPath|ConvertFrom-Json -Depth 100
$executionStart=Get-Content -Raw -LiteralPath $executionStartPath|ConvertFrom-Json -Depth 100
if([IO.Path]::GetFullPath([string]$executionConfig.probe_root)-cne$frozenRoot-or[string]$executionStart.config_sha256-cne[string]$config.execution_config_sha256-or[int]$executionStart.execution_count-ne1){throw 'Frozen execution lineage mismatch.'}
$inputInventoryPath=[IO.Path]::GetFullPath([string]$config.frozen_input_inventory_path)
$inputInventorySidecarPath=[IO.Path]::GetFullPath("$inputInventoryPath.sha256")
if($inputInventoryPath-ceq$frozenRoot-or$inputInventoryPath.StartsWith($frozenPrefix,[StringComparison]::OrdinalIgnoreCase)-or$inputInventorySidecarPath.StartsWith($frozenPrefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Frozen input inventory and sidecar must be external to the frozen Probe root.'}
if((Get-Pr90ProbeBSha256 $inputInventoryPath)-cne[string]$config.frozen_input_inventory_sha256-or-not(Test-Pr90ProbeBShaSidecar $inputInventoryPath $inputInventorySidecarPath)){throw 'Frozen input inventory file hash mismatch.'}
$frozenInventory=Get-Content -Raw -LiteralPath $inputInventoryPath|ConvertFrom-Json -Depth 100
$actualFrozenInventory=Get-Pr90ProbeBFileInventoryV1 -Paths @($frozenInventory.inputs.path)
if([string]$frozenInventory.schema-cne'Pr90ProbeBV2FrozenInputInventoryV1'-or[string]$frozenInventory.status-cne'FROZEN'-or[string]$frozenInventory.tooling_head_sha-cne$recoveryHead-or[string]$frozenInventory.tooling_tree_sha-cne$recoveryTree-or[string]$frozenInventory.inventory_builder_sha256-cne[string]$recoveryManifest.probe_b_frozen_input_inventory_builder_sha256-or[string]$frozenInventory.contract_module_sha256-cne$contractSha-or[int]$frozenInventory.input_count-ne241-or[string]$frozenInventory.input_inventory_sha256-cne'af5e309da4a512bbee1cdf3118e69ac243782715484757410702234f75d94f50'-or
   $actualFrozenInventory.count-ne[int]$frozenInventory.input_count-or[string]$actualFrozenInventory.inventory_sha256-cne[string]$frozenInventory.input_inventory_sha256){throw 'Frozen input inventory content drifted.'}
$resultBuilderPath=[IO.Path]::GetFullPath([string]$config.result_builder_path)
$attestationBuilderPath=[IO.Path]::GetFullPath([string]$config.attestation_builder_path)
foreach($binding in @(@($resultBuilderPath,[string]$config.result_builder_sha256,'result_builder'),@($attestationBuilderPath,[string]$config.attestation_builder_sha256,'attestation_builder'))){
    if((Get-Pr90ProbeBSha256 ([string]$binding[0]))-cne[string]$binding[1]){throw "Recovery Tooling binding mismatch: $($binding[2])"}
    $row=@($recoveryManifest.tooling_files|Where-Object{[IO.Path]::GetFullPath([string]$_.path)-ceq[IO.Path]::GetFullPath([string]$binding[0])-and[string]$_.sha256-ceq[string]$binding[1]})
    if($row.Count-ne1){throw "Recovery Tooling binding is absent from the sealed inventory: $($binding[2])"}
}
$forbiddenFrozenOutputs=@('pr90_exact_clone_startup_probe_b_v2_result.json','pr90_exact_clone_startup_probe_b_v2_result.json.sha256','pr90_exact_clone_startup_probe_b_v2_result.md','pr90_exact_clone_startup_probe_b_v2_attestation.json','pr90_exact_clone_startup_probe_b_v2_attestation.json.sha256','probe-b-controller-result.json','probe-b-controller-result.json.sha256')
if(@($forbiddenFrozenOutputs|Where-Object{Test-Path -LiteralPath (Join-Path $frozenRoot $_)}).Count-ne0){throw 'Frozen Probe root contains an unexpected post-run output.'}
$frozenRootInventoryBefore=Get-Pr90ProbeBFileInventoryV1 -Paths @(Get-ChildItem -LiteralPath $frozenRoot -File -Recurse|Sort-Object FullName|Select-Object -ExpandProperty FullName)
$processesBefore=@(Get-Pr90ProductProcessRowsV1);$mcpBefore=@(Get-Pr90McpSupportProcessRowsV1);$listenersBefore=@(Get-Pr90ProtectedListenerRowsV1)
if($processesBefore.Count-ne0-or$mcpBefore.Count-ne0-or$listenersBefore.Count-ne0){throw 'Offline recovery requires zero Godot/MCP processes and protected listeners.'}
$outputParent=[IO.Path]::GetDirectoryName($outputRoot)
[IO.Directory]::CreateDirectory($outputParent)|Out-Null
$stageRoot=Join-Path $outputParent ('.'+[IO.Path]::GetFileName($outputRoot)+'.staging.'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($stageRoot)|Out-Null
try{
    $resultPath=Join-Path $stageRoot 'pr90_exact_clone_startup_probe_b_v2_result.json'
    $resultMarkdownPath=Join-Path $stageRoot 'pr90_exact_clone_startup_probe_b_v2_result.md'
    $finalResultPath=Join-Path $outputRoot 'pr90_exact_clone_startup_probe_b_v2_result.json'
    $attestationPath=Join-Path $stageRoot 'pr90_exact_clone_startup_probe_b_v2_attestation.json'
    $finalAttestationPath=Join-Path $outputRoot 'pr90_exact_clone_startup_probe_b_v2_attestation.json'
    $resultOutput=@(& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File $resultBuilderPath -ProbeId ([string]$config.probe_id) -EvidenceRoot (Join-Path $frozenRoot 'evidence') `
        -ProductHeadSha ([string]$config.product_head_sha) -ProductTreeSha ([string]$config.product_tree_sha) -ToolingHeadSha ([string]$executionConfig.tooling_head_sha) -ToolingTreeSha ([string]$executionConfig.tooling_tree_sha) `
        -ToolingSealPath ([string]$executionConfig.tooling_seal_path) -PostImportBaselinePath ([string]$config.post_import_baseline_path) -ClassCachePath ([string]$config.class_cache_path) -GodotGuiPath ([string]$executionConfig.godot_gui_path) -GodotConsolePath ([string]$executionConfig.godot_console_path) `
        -FinalizerResultPath (Join-Path $frozenRoot 'import-finalizer-result.json') -TerminalManifestPath (Join-Path $frozenRoot 'terminal-process-port-manifest.json') -ProbeScenePath ([string]$executionConfig.probe_scene_path) -ExpectedProbeSceneSha256 ([string]$executionConfig.probe_scene_sha256) `
        -SceneIsolationAuditPath (Join-Path $frozenRoot 'preparation/probe-scene-isolation-audit.json') -ListenerForensicsPath ([string]$executionConfig.listener_forensics_path) -ExpectedListenerForensicsSha256 ([string]$executionConfig.listener_forensics_sha256) `
        -ExecutionStartPath $executionStartPath -ExpectedExecutionStartSha256 ([string]$config.execution_start_sha256) -ExecutionConfigPath $executionConfigPath -ExpectedExecutionConfigSha256 ([string]$config.execution_config_sha256) `
        -RecoveryToolingHeadSha $recoveryHead -RecoveryToolingTreeSha $recoveryTree -RecoveryToolingManifestPath $recoveryManifestPath -RecoveryToolingSealPath $recoverySealPath -OutputPath $resultPath -OutputMarkdownPath $resultMarkdownPath)
    if($LASTEXITCODE-ne0-or-not(Test-Path -LiteralPath $resultPath -PathType Leaf)){throw "Offline Result builder failed: $([string]::Join(' | ',[string[]]$resultOutput))"}
    $attestationOutput=@(& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File $attestationBuilderPath -ProbeId ([string]$config.probe_id) -ResultPath $resultPath -BoundResultPath $finalResultPath `
        -EvidenceRoot (Join-Path $frozenRoot 'evidence') -Probe004ResultPath ([string]$executionConfig.probe004_result_path) -ExpectedProbe004ResultSha256 ([string]$executionConfig.probe004_result_sha256) -Probe004AttestationPath ([string]$executionConfig.probe004_attestation_path) -ExpectedProbe004AttestationSha256 ([string]$executionConfig.probe004_attestation_sha256) `
        -PostImportBaselinePath ([string]$config.post_import_baseline_path) -ClassCachePath ([string]$config.class_cache_path) -SceneIsolationAuditPath (Join-Path $frozenRoot 'preparation/probe-scene-isolation-audit.json') -ExpectedProbeSceneSha256 ([string]$executionConfig.probe_scene_sha256) `
        -ListenerForensicsPath ([string]$executionConfig.listener_forensics_path) -ExpectedListenerForensicsSha256 ([string]$executionConfig.listener_forensics_sha256) -FinalizerResultPath (Join-Path $frozenRoot 'import-finalizer-result.json') -TerminalManifestPath (Join-Path $frozenRoot 'terminal-process-port-manifest.json') `
        -RecoveryToolingManifestPath $recoveryManifestPath -RecoveryToolingSealPath $recoverySealPath -OutputPath $attestationPath)
    if($LASTEXITCODE-ne0-or-not(Test-Path -LiteralPath $attestationPath -PathType Leaf)){throw "Offline Attestation builder failed: $([string]::Join(' | ',[string[]]$attestationOutput))"}
    $result=Get-Content -Raw -LiteralPath $resultPath|ConvertFrom-Json -Depth 100
    $attestation=Get-Content -Raw -LiteralPath $attestationPath|ConvertFrom-Json -Depth 100
    if([string]$result.status-cne'PASS'-or[string]$attestation.status-cne'SEALED'-or[string]$attestation.result_sha256-cne(Get-Pr90ProbeBSha256 $resultPath)){throw 'Recovered Result/Attestation contract is not green.'}
    $actualFrozenInventoryAfter=Get-Pr90ProbeBFileInventoryV1 -Paths @($frozenInventory.inputs.path)
    $frozenRootInventoryAfter=Get-Pr90ProbeBFileInventoryV1 -Paths @(Get-ChildItem -LiteralPath $frozenRoot -File -Recurse|Sort-Object FullName|Select-Object -ExpandProperty FullName)
    if($actualFrozenInventoryAfter.count-ne[int]$frozenInventory.input_count-or[string]$actualFrozenInventoryAfter.inventory_sha256-cne[string]$frozenInventory.input_inventory_sha256-or
       $frozenRootInventoryAfter.count-ne$frozenRootInventoryBefore.count-or[string]$frozenRootInventoryAfter.inventory_sha256-cne[string]$frozenRootInventoryBefore.inventory_sha256-or
       @($forbiddenFrozenOutputs|Where-Object{Test-Path -LiteralPath (Join-Path $frozenRoot $_)}).Count-ne0){throw 'Frozen Probe evidence changed during offline recovery.'}
    $processesAfter=@(Get-Pr90ProductProcessRowsV1);$mcpAfter=@(Get-Pr90McpSupportProcessRowsV1);$listenersAfter=@(Get-Pr90ProtectedListenerRowsV1)
    if($processesAfter.Count-ne0-or$mcpAfter.Count-ne0-or$listenersAfter.Count-ne0){throw 'A process or protected listener appeared during offline recovery.'}
    $receiptPath=Join-Path $stageRoot 'probe-b-v2-result-recovery-receipt.json'
    $receipt=[pscustomobject][ordered]@{
        schema='Pr90ProbeBV2ResultRecoveryReceiptV1';status='PASS';created_at_utc=[DateTimeOffset]::UtcNow.ToString('o');probe_id=[string]$config.probe_id
        recovery_config_path=[IO.Path]::GetFullPath($ConfigPath);recovery_config_sha256=Get-Pr90ProbeBSha256 $ConfigPath;frozen_probe_root=$frozenRoot;frozen_probe_modification_count=0
        frozen_input_inventory_path=$inputInventoryPath;frozen_input_inventory_sha256=Get-Pr90ProbeBSha256 $inputInventoryPath;frozen_input_count=[int]$frozenInventory.input_count;frozen_input_hash_inventory_sha256=[string]$frozenInventory.input_inventory_sha256
        frozen_probe_root_file_count_before=$frozenRootInventoryBefore.count;frozen_probe_root_file_count_after=$frozenRootInventoryAfter.count;frozen_probe_root_inventory_sha256_before=$frozenRootInventoryBefore.inventory_sha256;frozen_probe_root_inventory_sha256_after=$frozenRootInventoryAfter.inventory_sha256
        probe_execution_tooling_head_sha=[string]$executionConfig.tooling_head_sha;probe_execution_tooling_tree_sha=[string]$executionConfig.tooling_tree_sha;probe_execution_tooling_seal_sha256=[string]$executionConfig.tooling_seal_sha256
        result_recovery_tooling_head_sha=$recoveryHead;result_recovery_tooling_tree_sha=$recoveryTree;result_recovery_tooling_manifest_sha256=Get-Pr90ProbeBSha256 $recoveryManifestPath;result_recovery_tooling_seal_sha256=Get-Pr90ProbeBSha256 $recoverySealPath;recovery_controller_sha256=$controllerSha;recovery_contract_module_sha256=$contractSha;runtime_reachable_tooling_hash_mismatch_count=0
        result_path=$finalResultPath;result_sha256=Get-Pr90ProbeBSha256 $resultPath;attestation_path=$finalAttestationPath;attestation_sha256=Get-Pr90ProbeBSha256 $attestationPath
        probe_execution_count_delta=0;godot_process_start_count=0;mcp_process_start_count=0;startup_probe_invocation_count=0;import_invocation_count=0;finalizer_invocation_count=0;formal_mcp_execution_count=0;authorized_run_count_consumed=0
        godot_process_count_before=0;godot_process_count_after=0;mcp_process_count_before=0;mcp_process_count_after=0;protected_listener_count_before=0;protected_listener_count_after=0;canonical_payload_sha256=''
    }
    $receipt.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $receipt
    Write-Pr90ProbeBImmutableJson -Path $receiptPath -Value $receipt -WriteSha256Sidecar|Out-Null
    [IO.Directory]::Move($stageRoot,$outputRoot)
    $finalReceiptPath=Join-Path $outputRoot 'probe-b-v2-result-recovery-receipt.json'
    Get-Content -Raw -LiteralPath $finalReceiptPath
}finally{
    if(Test-Path -LiteralPath $stageRoot -PathType Container){Remove-Item -LiteralPath $stageRoot -Recurse -Force}
}
