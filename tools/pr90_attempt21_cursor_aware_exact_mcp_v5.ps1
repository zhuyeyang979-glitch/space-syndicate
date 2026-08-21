[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('PRE_FORMAL_EXACT_MCP_DRY_RUN','FORMAL_EXACT_SHA_MCP')][string]$ExecutionMode,
    [Parameter(Mandatory = $true)][string]$RunId,
    [Parameter(Mandatory = $true)][string]$Worktree,
    [Parameter(Mandatory = $true)][string]$EvidenceRoot,
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ExpectedHeadSha,
    [Parameter(Mandatory = $true)][string]$ExpectedTreeSha,
    [Parameter(Mandatory = $true)][string]$LaunchScriptPath,
    [Parameter(Mandatory = $true)][string]$ExpectedLaunchScriptSha256,
    [Parameter(Mandatory = $true)][string]$StopScriptPath,
    [Parameter(Mandatory = $true)][string]$ExpectedStopScriptSha256,
    [Parameter(Mandatory = $true)][string]$WatchdogScriptPath,
    [Parameter(Mandatory = $true)][string]$ExpectedWatchdogScriptSha256,
    [Parameter(Mandatory = $true)][string]$StateMachineScriptPath,
    [Parameter(Mandatory = $true)][string]$ExpectedStateMachineSha256,
    [Parameter(Mandatory = $true)][string]$ContractScriptPath,
    [Parameter(Mandatory = $true)][string]$ExpectedContractSha256,
    [string]$SealedBaselinePath = '',
    [string]$ExpectedSealedBaselineSha256 = '',
    [string]$StartupToolingManifestPath = '',
    [string]$ExpectedStartupToolingManifestSha256 = '',
    [string]$StartupToolingSealPath = '',
    [string]$ExpectedStartupToolingSealSha256 = '',
    [string]$FormalAuthorizationValidationReceiptPath = '',
    [string]$ExpectedFormalAuthorizationValidationReceiptSha256 = '',
    [string]$FormalAuthorizationSealPath = '',
    [string]$ExpectedFormalAuthorizationSealSha256 = '',
    [string]$FormalAuthorizationConsumptionReceiptPath = '',
    [string]$Attempt22ContractScriptPath = '',
    [string]$ExpectedAttempt22ContractSha256 = '',
    [string]$ExpectedRunbookSha256 = '',
    [string]$ImportFinalizerBindingPath = '',
    [string]$ExpectedImportFinalizerBindingSha256 = '',
    [string]$ImportRunnerPath = '',
    [string]$ExpectedImportRunnerSha256 = '',
    [string]$ClassCachePath = '',
    [string]$ExpectedClassCacheSha256 = '',
    [string]$GodotGuiPath = '',
    [string]$ExpectedGodotGuiSha256 = '',
    [string]$FormalPrelaunchIgnoredInventoryPath = '',
    [string]$FormalTerminalManifestPath = '',
    [string]$FormalFinalizerResultPath = '',
    [switch]$AllowFormalContinuation,
    [ValidateRange(1,65535)][int]$Port = 7576
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($ExecutionMode -ceq 'FORMAL_EXACT_SHA_MCP' -and -not $AllowFormalContinuation) {
    throw 'Formal v5 continuation requires explicit AllowFormalContinuation; dry-run never crosses play_main_scene.'
}
if ($ExecutionMode -ceq 'FORMAL_EXACT_SHA_MCP' -and @(
    $FormalAuthorizationValidationReceiptPath,$FormalAuthorizationSealPath,$FormalAuthorizationConsumptionReceiptPath,
    $Attempt22ContractScriptPath,$ExpectedAttempt22ContractSha256,$ExpectedRunbookSha256,$ImportFinalizerBindingPath,
    $ExpectedImportFinalizerBindingSha256,$ImportRunnerPath,$ExpectedImportRunnerSha256,$ClassCachePath,
    $ExpectedClassCacheSha256,$GodotGuiPath,$ExpectedGodotGuiSha256,$FormalPrelaunchIgnoredInventoryPath,
    $FormalTerminalManifestPath,$FormalFinalizerResultPath
    | Where-Object { [string]::IsNullOrWhiteSpace([string]$_) }).Count -ne 0) {
    throw 'Formal v5 requires the complete sealed authorization, consumption, cleanup, and finalizer plan.'
}

function Assert-FormalHashBinding {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Expected,[Parameter(Mandatory=$true)][string]$Name)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Formal v5 missing $Name file: $Path" }
    $actual=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -cne $Expected.ToLowerInvariant()) { throw "Formal v5 $Name hash mismatch." }
    return $actual
}

$root=(Resolve-Path -LiteralPath $Worktree).Path.TrimEnd('\')
$formalAuthorizationSealSha='';$consumptionSha='';$prelaunchSha='';$prelaunchFull='';$terminalFull='';$finalizerFull='';$currentToolingHead='';$currentToolingTree='';$formalSeal=$null
if($ExecutionMode -ceq 'FORMAL_EXACT_SHA_MCP'){
$null=Assert-FormalHashBinding -Path $PSCommandPath -Expected $ExpectedRunbookSha256 -Name 'runbook'
$null=Assert-FormalHashBinding -Path $StateMachineScriptPath -Expected $ExpectedStateMachineSha256 -Name 'state machine'
$null=Assert-FormalHashBinding -Path $ContractScriptPath -Expected $ExpectedContractSha256 -Name 'startup contract'
$null=Assert-FormalHashBinding -Path $Attempt22ContractScriptPath -Expected $ExpectedAttempt22ContractSha256 -Name 'Attempt 22 contract'
$null=Assert-FormalHashBinding -Path $ImportFinalizerBindingPath -Expected $ExpectedImportFinalizerBindingSha256 -Name 'formal finalizer binding'
$null=Assert-FormalHashBinding -Path $ImportRunnerPath -Expected $ExpectedImportRunnerSha256 -Name 'import runner'
$null=Assert-FormalHashBinding -Path $ClassCachePath -Expected $ExpectedClassCacheSha256 -Name 'class cache'
$null=Assert-FormalHashBinding -Path $GodotGuiPath -Expected $ExpectedGodotGuiSha256 -Name 'Godot GUI executable'
$null=Assert-FormalHashBinding -Path $FormalAuthorizationValidationReceiptPath -Expected $ExpectedFormalAuthorizationValidationReceiptSha256 -Name 'authorization validation receipt'
$formalAuthorizationSealSha=Assert-FormalHashBinding -Path $FormalAuthorizationSealPath -Expected $ExpectedFormalAuthorizationSealSha256 -Name 'authorization seal'
$formalSeal=Get-Content -Raw -LiteralPath $FormalAuthorizationSealPath|ConvertFrom-Json -Depth 100
$null=Assert-FormalHashBinding -Path $GodotPath -Expected ([string]$formalSeal.godot_console_sha256) -Name 'Godot console executable'
$null=Assert-FormalHashBinding -Path $StartupToolingManifestPath -Expected $ExpectedStartupToolingManifestSha256 -Name 'Tooling manifest'
$null=Assert-FormalHashBinding -Path $StartupToolingSealPath -Expected $ExpectedStartupToolingSealSha256 -Name 'Tooling seal'

Import-Module (Resolve-Path -LiteralPath $Attempt22ContractScriptPath).Path -Force
Import-Module (Resolve-Path -LiteralPath $StateMachineScriptPath).Path -Force
Import-Module (Resolve-Path -LiteralPath $ContractScriptPath).Path -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt19_authority_contract.psm1') -Force

$evidenceFull=[IO.Path]::GetFullPath($EvidenceRoot)
$consumptionFull=[IO.Path]::GetFullPath($FormalAuthorizationConsumptionReceiptPath)
$prelaunchFull=[IO.Path]::GetFullPath($FormalPrelaunchIgnoredInventoryPath)
$terminalFull=[IO.Path]::GetFullPath($FormalTerminalManifestPath)
$finalizerFull=[IO.Path]::GetFullPath($FormalFinalizerResultPath)
if($terminalFull-cne[IO.Path]::GetFullPath((Join-Path $evidenceFull 'terminal-process-port-manifest.json'))-or
   $finalizerFull-cne[IO.Path]::GetFullPath((Join-Path $evidenceFull 'formal-import-finalizer-result.json'))){throw 'Formal terminal/finalizer paths must be the exact authorized EvidenceRoot children.'}
foreach($path in @($evidenceFull,$consumptionFull,$prelaunchFull,$terminalFull,$finalizerFull)){if(Test-Path -LiteralPath $path){throw "Formal v5 authorized output path already exists: $path"}}
if($consumptionFull.StartsWith("$evidenceFull\",[StringComparison]::OrdinalIgnoreCase)-or$prelaunchFull.StartsWith("$evidenceFull\",[StringComparison]::OrdinalIgnoreCase)){throw 'Formal consumption and prelaunch inventory evidence must be outside the runtime EvidenceRoot.'}

$head=(& git -C $root rev-parse HEAD).Trim();$tree=(& git -C $root rev-parse 'HEAD^{tree}').Trim()
if($LASTEXITCODE-ne0-or$head-cne$ExpectedHeadSha-or$tree-cne$ExpectedTreeSha){throw 'Formal product worktree identity mismatch.'}
$expectedClassCachePath=[IO.Path]::GetFullPath((Join-Path $root '.godot/global_script_class_cache.cfg'))
if([IO.Path]::GetFullPath($ClassCachePath)-cne$expectedClassCachePath){throw 'Formal class-cache path is not inside the exact product worktree.'}
$validation=Get-Content -Raw -LiteralPath $FormalAuthorizationValidationReceiptPath|ConvertFrom-Json -Depth 100
$toolingManifest=Get-Content -Raw -LiteralPath $StartupToolingManifestPath|ConvertFrom-Json -Depth 100
$toolingSeal=Get-Content -Raw -LiteralPath $StartupToolingSealPath|ConvertFrom-Json -Depth 100
$currentToolingHead=(& git -C $PSScriptRoot rev-parse HEAD).Trim();$currentToolingTree=(& git -C $PSScriptRoot rev-parse 'HEAD^{tree}').Trim()
$toolingStatus=@(& git -C $PSScriptRoot status --porcelain=v1 --untracked-files=all)
$toolingInventoryMismatch=[Collections.Generic.List[string]]::new()
foreach($row in @($toolingManifest.tooling_files)){
    $relative=([string]$row.relative_path).Replace('/','\');$path=Join-Path (Split-Path -Parent $PSScriptRoot) $relative
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)-or(Get-Pr90ProbeBSha256 $path)-cne[string]$row.sha256){$toolingInventoryMismatch.Add([string]$row.relative_path);continue}
    $blob=(& git -C $PSScriptRoot rev-parse "HEAD:$([string]$row.relative_path)").Trim();if($LASTEXITCODE-ne0-or$blob-cne[string]$row.git_blob_sha){$toolingInventoryMismatch.Add([string]$row.relative_path)}
}
$authorityGreen=([string]$validation.schema-ceq'Pr90Attempt22AuthorizationValidationV4'-and[string]$validation.status-ceq'PASS'-and-not[bool]$validation.authorization_consumed-and
    [string]$validation.authorized_run_id-ceq$RunId-and[IO.Path]::GetFullPath([string]$validation.formal_evidence_root)-ceq$evidenceFull-and
    [string]$validation.product_head_sha-ceq$ExpectedHeadSha-and[string]$validation.product_tree_sha-ceq$ExpectedTreeSha-and
    [string]$validation.tooling_head_sha-ceq$currentToolingHead-and[string]$validation.tooling_tree_sha-ceq$currentToolingTree-and
    [string]$formalSeal.schema-ceq'Pr90Attempt22AuthorizationSealV4'-and[string]$formalSeal.status-ceq'SEALED'-and[string]$formalSeal.authorized_run_id-ceq$RunId-and
    [IO.Path]::GetFullPath([string]$formalSeal.formal_evidence_root)-ceq$evidenceFull-and[string]$formalSeal.product_head_sha-ceq$ExpectedHeadSha-and[string]$formalSeal.product_tree_sha-ceq$ExpectedTreeSha-and
    [string]$formalSeal.tooling_head_sha-ceq$currentToolingHead-and[string]$formalSeal.tooling_tree_sha-ceq$currentToolingTree-and
    [string]$formalSeal.tooling_manifest_sha256-ceq$ExpectedStartupToolingManifestSha256-and[string]$formalSeal.tooling_seal_sha256-ceq$ExpectedStartupToolingSealSha256-and
    [string]$formalSeal.attempt22_contract_module_sha256-ceq$ExpectedAttempt22ContractSha256-and
    [string]$formalSeal.validation_receipt_sha256-ceq$ExpectedFormalAuthorizationValidationReceiptSha256-and
    [IO.Path]::GetFullPath([string]$formalSeal.authorization_consumption_receipt_path)-ceq$consumptionFull-and
    [IO.Path]::GetFullPath([string]$formalSeal.formal_prelaunch_ignored_inventory_path)-ceq$prelaunchFull-and
    [IO.Path]::GetFullPath([string]$formalSeal.formal_terminal_manifest_path)-ceq$terminalFull-and[IO.Path]::GetFullPath([string]$formalSeal.formal_finalizer_result_path)-ceq$finalizerFull-and
    [string]$formalSeal.sealed_baseline_sha256-ceq$ExpectedSealedBaselineSha256-and[string]$formalSeal.class_cache_sha256-ceq$ExpectedClassCacheSha256-and
    [string]$formalSeal.godot_gui_sha256-ceq$ExpectedGodotGuiSha256-and[string]$formalSeal.import_finalizer_sha256-ceq$ExpectedImportFinalizerBindingSha256-and[string]$formalSeal.import_runner_sha256-ceq$ExpectedImportRunnerSha256-and
    [string]$toolingManifest.status-ceq'READY'-and[string]$toolingManifest.tooling_head_sha-ceq$currentToolingHead-and[string]$toolingManifest.tooling_tree_sha-ceq$currentToolingTree-and
    [string]$toolingManifest.canonical_payload_sha256-ceq(Get-Pr90ProbeBCanonicalSha256 $toolingManifest)-and$toolingStatus.Count-eq0-and$toolingInventoryMismatch.Count-eq0-and
    [string]$toolingSeal.status-ceq'SEALED'-and[string]$toolingSeal.tooling_head_sha-ceq$currentToolingHead-and[string]$toolingSeal.tooling_tree_sha-ceq$currentToolingTree-and[string]$toolingSeal.manifest_sha256-ceq$ExpectedStartupToolingManifestSha256-and[string]$toolingSeal.canonical_payload_sha256-ceq(Get-Pr90ProbeBCanonicalSha256 $toolingSeal))
if(-not$authorityGreen){throw 'Formal v5 authorization, Tooling, or planned cleanup identity mismatch.'}

$prestartProductProcesses=@(Get-Pr90ProductProcessRowsV1);$prestartMcpProcesses=@(Get-Pr90McpSupportProcessRowsV1);$prestartListeners=@(Get-Pr90ProtectedListenerRowsV1)
if($prestartProductProcesses.Count-ne0-or$prestartMcpProcesses.Count-ne0-or$prestartListeners.Count-ne0){
    $prestartBoundary=[pscustomobject][ordered]@{product_processes=@($prestartProductProcesses);mcp_support_processes=@($prestartMcpProcesses);protected_listeners=@($prestartListeners)}
    throw "Formal prestart process/port boundary is not empty; authorization remains unconsumed. boundary=$($prestartBoundary|ConvertTo-Json -Depth 20 -Compress)"
}
$baseline=Get-Content -Raw -LiteralPath $SealedBaselinePath|ConvertFrom-Json -Depth 100
$baselineState=New-FinalizerStateFromBaseline $baseline
$prelaunchState=Get-CurrentFinalizerState -Worktree $root
$prelaunchStateGreen=([string]$prelaunchState.head_sha-ceq[string]$baselineState.head_sha-and[string]$prelaunchState.tree_sha-ceq[string]$baselineState.tree_sha-and
    [int]$prelaunchState.tracked_non_generated_delta_count-eq0-and[string]$prelaunchState.tracked_import_path_set_sha256-ceq[string]$baselineState.tracked_import_path_set_sha256-and
    [string]$prelaunchState.tracked_import_byte_map_sha256-ceq[string]$baselineState.tracked_import_byte_map_sha256-and[string]$prelaunchState.untracked_uid_path_set_sha256-ceq[string]$baselineState.untracked_uid_path_set_sha256-and
    [string]$prelaunchState.untracked_uid_byte_map_sha256-ceq[string]$baselineState.untracked_uid_byte_map_sha256-and[int]$prelaunchState.unknown_untracked_count-eq0-and
    [int]$prelaunchState.unknown_ignored_count-eq0-and[string]$prelaunchState.class_cache_sha256-ceq[string]$baselineState.class_cache_sha256)
if(-not$prelaunchStateGreen){throw 'Formal product worktree does not match the complete sealed finalizer baseline before process creation.'}
$ignoredPaths=@(& git -C $root -c core.quotePath=false ls-files -o -i --exclude-standard|ForEach-Object{$_.Replace('\','/')}|Sort-Object -Unique)
if($LASTEXITCODE-ne0){throw 'Unable to inventory formal prelaunch ignored paths.'}
$ignoredHash=Get-Pr90ProbeBStringSetSha256 -Rows $ignoredPaths
if($ignoredPaths.Count-ne[int]$baseline.ignored_sidecar_count-or$ignoredHash-cne[string]$baseline.ignored_sidecar_path_set_sha256){throw 'Formal prelaunch ignored inventory does not match the sealed post-import baseline.'}
$prelaunch=[pscustomobject][ordered]@{schema='Pr90ProbeBPrelaunchIgnoredPathInventoryV1';status='SEALED';created_at_utc=[DateTimeOffset]::UtcNow.ToString('o');authorized_run_id=$RunId;product_head_sha=$ExpectedHeadSha;product_tree_sha=$ExpectedTreeSha;baseline_sha256=$ExpectedSealedBaselineSha256;complete_finalizer_state_green=$prelaunchStateGreen;complete_finalizer_state=$prelaunchState;complete_finalizer_state_sha256=Get-StartupCanonicalSha256 -Value $prelaunchState;ignored_path_count=$ignoredPaths.Count;ignored_path_set_sha256=$ignoredHash;ignored_paths=$ignoredPaths;canonical_payload_sha256=''}
$prelaunch.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $prelaunch
Write-Pr90ProbeBImmutableJson -Path $prelaunchFull -Value $prelaunch -WriteSha256Sidecar|Out-Null
$prelaunchSha=Get-Pr90ProbeBSha256 $prelaunchFull
}else{
    $null=Assert-FormalHashBinding -Path $StateMachineScriptPath -Expected $ExpectedStateMachineSha256 -Name 'state machine'
    $null=Assert-FormalHashBinding -Path $ContractScriptPath -Expected $ExpectedContractSha256 -Name 'startup contract'
    Import-Module (Resolve-Path -LiteralPath $StateMachineScriptPath).Path -Force
    Import-Module (Resolve-Path -LiteralPath $ContractScriptPath).Path -Force
}

$state=$null;$stateInvocationFailure=$null
try{
$state = Invoke-Pr90McpStartupStateMachine `
    -ExecutionMode $ExecutionMode `
    -RunId $RunId `
    -ProbeIdentity 'pr90-attempt21-v5-cursor-runbook' `
    -Worktree $Worktree `
    -EvidenceRoot $EvidenceRoot `
    -GodotPath $GodotPath `
    -ExpectedHeadSha $ExpectedHeadSha `
    -ExpectedTreeSha $ExpectedTreeSha `
    -LaunchScriptPath $LaunchScriptPath `
    -ExpectedLaunchScriptSha256 $ExpectedLaunchScriptSha256 `
    -StopScriptPath $StopScriptPath `
    -ExpectedStopScriptSha256 $ExpectedStopScriptSha256 `
    -WatchdogScriptPath $WatchdogScriptPath `
    -ExpectedWatchdogScriptSha256 $ExpectedWatchdogScriptSha256 `
    -ExpectedStateMachineSha256 $ExpectedStateMachineSha256 `
    -ExpectedContractSha256 $ExpectedContractSha256 `
    -SealedBaselinePath $SealedBaselinePath `
    -ExpectedSealedBaselineSha256 $ExpectedSealedBaselineSha256 `
    -StartupToolingManifestPath $StartupToolingManifestPath `
    -ExpectedStartupToolingManifestSha256 $ExpectedStartupToolingManifestSha256 `
    -StartupToolingSealPath $StartupToolingSealPath `
    -ExpectedStartupToolingSealSha256 $ExpectedStartupToolingSealSha256 `
    -FormalAuthorizationValidationReceiptPath $FormalAuthorizationValidationReceiptPath `
    -ExpectedFormalAuthorizationValidationReceiptSha256 $ExpectedFormalAuthorizationValidationReceiptSha256 `
    -FormalAuthorizationSealPath $FormalAuthorizationSealPath `
    -ExpectedFormalAuthorizationSealSha256 $ExpectedFormalAuthorizationSealSha256 `
    -FormalAuthorizationConsumptionReceiptPath $FormalAuthorizationConsumptionReceiptPath `
    -Port $Port `
    -KeepRunningAfterM11:($ExecutionMode -ceq 'FORMAL_EXACT_SHA_MCP')
}catch{$stateInvocationFailure=$_}
if($null-eq$state){
    [IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($EvidenceRoot))|Out-Null
    $state=[pscustomobject]@{summary=[pscustomobject]@{status='BLOCKED';failure_detail=if($null-ne$stateInvocationFailure){$stateInvocationFailure.Exception.Message}else{'state machine returned null'};stop_pending=$false;stops_cleanly=$false;forced_stop=$false;unrelated_process_termination_count=0};godot_pid=0;endpoint_owner_pid=0;endpoint_owner_creation_filetime_utc='';endpoint_owner_session_id=0;endpoint_owner_user_sid='';process_start_utc='';watchdog_child=$null;watchdog_stop_path='';stream_id='';cursor_after=[int64]0}
}
$formalAuthorizationConsumed=Test-Path -LiteralPath $FormalAuthorizationConsumptionReceiptPath -PathType Leaf
$formalMcpExecutionCount=if($formalAuthorizationConsumed){1}else{0};$authorizedRunCountConsumed=$formalMcpExecutionCount
if($formalAuthorizationConsumed){
    $consumptionSha=Get-Pr90ProbeBSha256 $FormalAuthorizationConsumptionReceiptPath
    $consumption=Get-Content -Raw -LiteralPath $FormalAuthorizationConsumptionReceiptPath|ConvertFrom-Json -Depth 100
    if([string]$consumption.schema-cne'Pr90Attempt22AuthorizationConsumptionV1'-or[string]$consumption.status-cne'CONSUMED'-or[string]$consumption.authorized_run_id-cne$RunId-or
       [int]$consumption.formal_mcp_execution_count-ne1-or[int]$consumption.authorized_run_count_consumed-ne1-or[string]$consumption.canonical_payload_sha256-cne(Get-Pr90ProbeBCanonicalSha256 $consumption)){
        $stateInvocationFailure=[InvalidOperationException]::new('Formal authorization consumption receipt is malformed after process creation.')
    }
}

if ($ExecutionMode -ceq 'PRE_FORMAL_EXACT_MCP_DRY_RUN') {
    $state.summary | ConvertTo-Json -Depth 100 -Compress
    if([string]$state.summary.status-ceq'PASS'){exit 0}else{exit 2}
}

$invokeScript = Join-Path $PSScriptRoot 'invoke_role_godot_mcp.ps1'
$invokeBindingFailure=$null;$m5Receipt=$null;$m5Connection=$null;$endpointOwnershipAttestation=$null;$endpointOwnershipAttestationPath=Join-Path $EvidenceRoot 'endpoint-ownership-v2-attestation.json'
try {
    $m5ReceiptPath=Join-Path $EvidenceRoot 'milestones/05-M5-mcp_endpoint_owner_v2_verified.receipt.json'
    if(-not(Test-Pr90ProbeBShaSidecar -TargetPath $m5ReceiptPath -SidecarPath "$m5ReceiptPath.sha256")-or-not(Test-Pr90ProbeBShaSidecar -TargetPath $endpointOwnershipAttestationPath -SidecarPath "$endpointOwnershipAttestationPath.sha256")){throw 'Formal V2 invoker M5 evidence sidecar mismatch.'}
    $m5Receipt=Get-Content -Raw -LiteralPath $m5ReceiptPath|ConvertFrom-Json -Depth 100
    $m5ConnectionPath=[IO.Path]::GetFullPath([string]$m5Receipt.connection_path);$expectedConnectionPath=[IO.Path]::GetFullPath((Join-Path $root '.codex-godot/connection.json'))
    if($m5ConnectionPath-cne$expectedConnectionPath-or-not(Test-Path -LiteralPath $m5ConnectionPath -PathType Leaf)-or(Get-Pr90ProbeBSha256 $m5ConnectionPath)-cne[string]$m5Receipt.connection_sha256){throw 'Formal V2 invoker connection evidence identity mismatch.'}
    $m5Connection=Get-Content -Raw -LiteralPath $m5ConnectionPath|ConvertFrom-Json -Depth 100;$endpointOwnershipAttestation=Get-Content -Raw -LiteralPath $endpointOwnershipAttestationPath|ConvertFrom-Json -Depth 100
    if([IO.Path]::GetFullPath([string]$m5Receipt.evidence_path)-cne[IO.Path]::GetFullPath($endpointOwnershipAttestationPath)-or
       (Get-Pr90ProbeBSha256 $endpointOwnershipAttestationPath)-cne[string]$m5Receipt.evidence_sha256-or
       -not(Test-Pr90FormalM5InvocationBindingV1 -M5Receipt $m5Receipt -Connection $m5Connection -EndpointOwnershipAttestation $endpointOwnershipAttestation `
        -ExpectedRunId $RunId -ExpectedExecutionMode $ExecutionMode -ExpectedPort $Port -ExpectedGodotPid ([int]$state.godot_pid) `
        -ExpectedLaunchSessionId ([string]$state.launch_session_id) -ExpectedEndpointOwnerPid ([int]$state.endpoint_owner_pid))){throw 'Formal V2 invoker M5 evidence identity mismatch.'}
} catch {$invokeBindingFailure=$_}
$callIndex = 1000
$streamId = [string]$state.stream_id
$cursor = [int64]$state.cursor_after
$startupStreamId = $streamId
$startupCursorAfter = $cursor
$mainRuntimeStreamId = ''
$mainStreamTransitionPath = ''
$mainStreamTransitionSha = ''
$allEvents = [Collections.Generic.List[object]]::new()
$readyWitnesses = [Collections.Generic.List[object]]::new()
$pollCount = 0
$primaryFailure = if($null-ne$stateInvocationFailure){$stateInvocationFailure}elseif([string]$state.summary.status-cne'PASS'){[InvalidOperationException]::new("Formal startup state machine blocked: $([string]$state.summary.failure_detail)")}elseif($null-ne$invokeBindingFailure){$invokeBindingFailure}else{$null}
$formalPayload=$null

function Get-FormalStructured {
    param([object]$Response)
    if ($null -eq $Response.result.structuredContent) { throw 'MCP response has no structuredContent.' }
    return $Response.result.structuredContent
}

function Invoke-FormalMcp {
    param([string]$ToolName, [hashtable]$Arguments = @{}, [int]$TimeoutSeconds = 60)
    if($null-ne$script:invokeBindingFailure-or$null-eq$script:m5Receipt-or$null-eq$script:m5Connection-or$null-eq$script:endpointOwnershipAttestation){throw 'Formal V2 invoker M5 identity binding is not green; no HTTP request is permitted.'}
    $script:callIndex += 1
    $raw = Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-{1}.jsonrpc.json' -f $script:callIndex,$ToolName)
    $requestPath = Join-Path $EvidenceRoot ('requests/{0:D4}-{1}.json' -f $script:callIndex,$ToolName)
    $requestRow=[pscustomobject][ordered]@{schema='SpaceSyndicateFormalMcpRequestV1';run_id=$RunId;call_index=$script:callIndex;tool_name=$ToolName;arguments=[pscustomobject]$Arguments;timeout_seconds=$TimeoutSeconds;canonical_payload_sha256=''}
    $requestRow.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $requestRow
    Write-StartupImmutableJson -Path $requestPath -Value $requestRow -WriteSha256Sidecar|Out-Null
    $json = $Arguments | ConvertTo-Json -Depth 40 -Compress
    $output = @(& pwsh -NoProfile -File $script:invokeScript -Worktree $root -ToolName $ToolName -ArgumentsJson $json -TimeoutSeconds $TimeoutSeconds -RawResponsePath $raw `
        -ExpectedControlProcessId ([int]$m5Connection.control_process_pid) -ExpectedControlProcessStartUtc ([string]$m5Connection.process_start_time_utc) -ExpectedLaunchSessionId ([string]$m5Connection.launch_session_id) `
        -ExpectedControlProcessSha256 ([string]$formalSeal.godot_console_sha256) -ExpectedPort $Port -ExpectedConnectionSha256 ([string]$m5Receipt.connection_sha256) `
        -EndpointOwnershipAttestationPath $endpointOwnershipAttestationPath -ExpectedEndpointOwnershipAttestationSha256 ([string]$m5Receipt.evidence_sha256) `
        -ExpectedEndpointOwnerPid ([int]$m5Connection.endpoint_owner_pid) -ExpectedEndpointOwnerPath $GodotGuiPath -ExpectedEndpointOwnerSha256 ([string]$formalSeal.godot_gui_sha256) `
        -ExpectedEndpointOwnerCreationFiletimeUtc ([string]$m5Connection.endpoint_owner_creation_time_filetime_utc) -ExpectedEndpointOwnerSessionId ([int]$m5Connection.endpoint_owner_windows_session_id) `
        -ExpectedEndpointOwnerUserSid ([string]$m5Connection.endpoint_owner_user_sid) 2>&1)
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $raw)) { throw "Formal v5 MCP call $ToolName failed: $($output -join ' ')" }
    return Get-Content -Raw -LiteralPath $raw | ConvertFrom-Json -Depth 100
}

function Test-FormalPageContract {
    param([object]$Page, [string]$ExpectedStream, [int64]$ExpectedCursor)
    $events = @($Page.events); $issues = [Collections.Generic.List[string]]::new()
    if ([string]$Page.stream_id -cne $ExpectedStream) { $issues.Add('stream_changed') }
    if ([string]$Page.event_sequence_mode -cne 'cursor') { $issues.Add('not_cursor') }
    if (-not [bool]$Page.event_sequence_complete) { $issues.Add('incomplete') }
    if ([string]$Page.continuity_status -cne 'CONTIGUOUS') { $issues.Add('continuity') }
    if ([int]$Page.event_sequence_gap_count -ne 0) { $issues.Add('gap') }
    if ([int]$Page.event_sequence_invalid_count -ne 0) { $issues.Add('invalid') }
    if ([bool]$Page.client_truncated) { $issues.Add('client_truncated') }
    if (-not [bool]$Page.success) { $issues.Add('failed') }
    $expected = $ExpectedCursor + 1
    foreach ($event in $events) {
        if ([int64]$event.event_sequence -ne $expected) { $issues.Add('event_order') }
        if ([string]$event.stream_id -cne $ExpectedStream) { $issues.Add('event_stream') }
        if ([string]$event.kind -ceq 'ready') {
            if ([string]$event.message -cne 'Runtime bridge ready.') { $issues.Add('ready_message') }
            $readyWitnesses.Add($event)
        } elseif ([string]$event.kind -ceq 'command') {
            if ([string]$event.message -notmatch ': success$') { $issues.Add('failed_command') }
        } else { $issues.Add('unexpected_event_kind') }
        $allEvents.Add($event); $expected += 1
    }
    return [pscustomobject]@{green=$issues.Count -eq 0;issues=@($issues);events=$events}
}

function Poll-FormalCursor {
    param([string]$Phase,[int]$InnerTimeoutMsec=10000,[int]$OuterTimeoutSeconds=60)
    $payload = Get-FormalStructured (Invoke-FormalMcp -ToolName 'get_runtime_events' -Arguments @{max_events=100;timeout_msec=$InnerTimeoutMsec;stream_id=$streamId;since_sequence=$cursor} -TimeoutSeconds $OuterTimeoutSeconds)
    $result = $payload.result
    $check = Test-FormalPageContract -Page $result -ExpectedStream $streamId -ExpectedCursor $cursor
    if (-not $check.green -or [bool]$result.event_window_overflowed) { throw "Formal cursor phase $Phase failed: $($check.issues -join ',')" }
    if (@($check.events).Count -gt 0) { $script:cursor = [int64]$check.events[-1].event_sequence }
    $script:pollCount += 1
    $phasePath = Join-Path $EvidenceRoot ("phases/{0:D3}-$Phase.json" -f $script:pollCount)
    $phaseRow = [ordered]@{schema='SpaceSyndicateCursorPhaseWitnessV5';run_id=$RunId;phase=$Phase;poll_index=$script:pollCount;stream_id=$streamId;cursor_after=$cursor;event_count=@($check.events).Count;event_sequence_complete=[bool]$result.event_sequence_complete;continuity_status=[string]$result.continuity_status;events=@($check.events)}
    if (-not (Test-Path -LiteralPath $phasePath)) { Write-StartupImmutableJson -Path $phasePath -Value $phaseRow -WriteSha256Sidecar | Out-Null }
    return $result
}

function Set-FormalMainRuntimeStream {
    $snapshotCallIndex=$script:callIndex+1
    $snapshotPayload=Get-FormalStructured (Invoke-FormalMcp -ToolName 'get_runtime_events' -Arguments @{max_events=100;timeout_msec=10000} -TimeoutSeconds 60)
    $snapshotPage=$snapshotPayload.result
    $candidateStreamId=[string]$snapshotPage.stream_id
    $readyCallIndex=$script:callIndex+1
    $readyPayload=Get-FormalStructured (Invoke-FormalMcp -ToolName 'get_runtime_events' -Arguments @{max_events=100;timeout_msec=10000;stream_id=$candidateStreamId;since_sequence=0} -TimeoutSeconds 60)
    $readyPage=$readyPayload.result
    if(-not(Test-Pr90FormalMainRuntimeStreamTransitionV1 -StartupStreamId $startupStreamId -SnapshotPage $snapshotPage -ReadyPage $readyPage)){throw 'Formal main runtime stream transition or fresh ready witness is invalid.'}
    $readyCheck=Test-FormalPageContract -Page $readyPage -ExpectedStream $candidateStreamId -ExpectedCursor 0
    if(-not$readyCheck.green){throw "Formal main runtime ready page failed: $($readyCheck.issues -join ',')"}
    $snapshotRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-get_runtime_events.json' -f $snapshotCallIndex)
    $snapshotRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-get_runtime_events.jsonrpc.json' -f $snapshotCallIndex)
    $readyRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-get_runtime_events.json' -f $readyCallIndex)
    $readyRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-get_runtime_events.jsonrpc.json' -f $readyCallIndex)
    foreach($requiredPath in @($snapshotRequestPath,$snapshotRawPath,$readyRequestPath,$readyRawPath)){if(-not(Test-Path -LiteralPath $requiredPath -PathType Leaf)){throw "Formal stream transition evidence missing: $requiredPath"}}
    $transition=[pscustomobject][ordered]@{schema='SpaceSyndicateMainRuntimeStreamTransitionV1';run_id=$RunId;status='PASS';intentional_restart_reason='exit_probe_then_play_main_scene';transition_index=1;expected_transition_count=1;unexpected_transition_count=0;startup_stream_id=$startupStreamId;startup_cursor_after=$startupCursorAfter;main_runtime_stream_id=$candidateStreamId;main_cursor_after=[int64]$readyPage.event_sequence_last;main_stream_id_stable=$true;snapshot_request_path=[IO.Path]::GetFullPath($snapshotRequestPath);snapshot_request_sha256=Get-Pr90ProbeBSha256 $snapshotRequestPath;snapshot_raw_path=[IO.Path]::GetFullPath($snapshotRawPath);snapshot_raw_sha256=Get-Pr90ProbeBSha256 $snapshotRawPath;ready_request_path=[IO.Path]::GetFullPath($readyRequestPath);ready_request_sha256=Get-Pr90ProbeBSha256 $readyRequestPath;ready_raw_path=[IO.Path]::GetFullPath($readyRawPath);ready_raw_sha256=Get-Pr90ProbeBSha256 $readyRawPath;canonical_payload_sha256=''}
    $transition.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $transition
    $transitionPath=Join-Path $EvidenceRoot 'phases/000-main-runtime-stream-transition.json'
    Write-StartupImmutableJson -Path $transitionPath -Value $transition -WriteSha256Sidecar|Out-Null
    $script:streamId=$candidateStreamId
    $script:cursor=[int64]$readyPage.event_sequence_last
    $script:mainRuntimeStreamId=$candidateStreamId
    $script:mainStreamTransitionPath=[IO.Path]::GetFullPath($transitionPath)
    $script:mainStreamTransitionSha=Get-Pr90ProbeBSha256 $transitionPath
}

function Get-FormalNode {
    param([string]$Path, [string[]]$Properties=@())
    $payload = Get-FormalStructured (Invoke-FormalMcp -ToolName 'query_runtime_node' -Arguments @{node_path=$Path;properties=@($Properties);include_children=$false;timeout_msec=30000} -TimeoutSeconds 45)
    if (-not [bool]$payload.success -or -not [bool]$payload.result.found) { throw "Runtime node missing: $Path" }
    return $payload.result
}

function Get-FormalNodeTree {
    param([string]$Path,[int]$MaxDepth=5,[int]$MaxNodes=200)
    $payload=Get-FormalStructured (Invoke-FormalMcp -ToolName 'query_runtime_node' -Arguments @{node_path=$Path;properties=@();include_children=$true;max_depth=$MaxDepth;max_nodes=$MaxNodes;timeout_msec=30000} -TimeoutSeconds 45)
    if(-not[bool]$payload.success-or-not[bool]$payload.result.found-or[bool]$payload.result.tree_truncated){throw "Runtime node tree missing or truncated: $Path"}
    return $payload.result.tree
}

function Invoke-FormalDynamicNodeQuery {
    param(
        [Parameter(Mandatory=$true)][string]$StableParentPath,
        [Parameter(Mandatory=$true)][string]$Path,
        [string[]]$Properties=@()
    )
    $queryCallIndex=$script:callIndex+1;$invocationFailure=$null
    try{$null=Invoke-FormalMcp -ToolName 'query_runtime_node' -Arguments @{node_path=$Path;properties=@($Properties);include_children=$false;timeout_msec=30000} -TimeoutSeconds 45}catch{$invocationFailure=$_}
    $requestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-query_runtime_node.json' -f $queryCallIndex)
    $rawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-query_runtime_node.jsonrpc.json' -f $queryCallIndex)
    if(-not(Test-Path -LiteralPath $requestPath -PathType Leaf)-or-not(Test-Path -LiteralPath $rawPath -PathType Leaf)){
        if($null-ne$invocationFailure){throw $invocationFailure}
        throw "Dynamic runtime node query evidence is incomplete: $Path"
    }
    $request=Get-Content -Raw -LiteralPath $requestPath|ConvertFrom-Json -Depth 100 -DateKind String
    $rawResponse=Get-Content -Raw -LiteralPath $rawPath|ConvertFrom-Json -Depth 100 -DateKind String
    $classification=Get-Pr90FormalDynamicNodeQueryClassV1 -Request $request -RawResponse $rawResponse -ExpectedRunId $RunId -ExpectedCallIndex $queryCallIndex -ExpectedPath $Path -StableParentPath $StableParentPath -ExpectedProperties @($Properties)
    $record=[ordered]@{classification=$classification;call_index=$queryCallIndex;candidate_path=$Path;stable_parent_path=$StableParentPath;request_path=[IO.Path]::GetFullPath($requestPath);request_sha256=Get-Pr90ProbeBSha256 $requestPath;raw_path=[IO.Path]::GetFullPath($rawPath);raw_sha256=Get-Pr90ProbeBSha256 $rawPath;result=$null}
    if($classification-ceq'FOUND'){
        if($null-ne$invocationFailure){throw $invocationFailure}
        $record.result=$rawResponse.result.structuredContent.result
        return [pscustomobject]$record
    }
    if($classification-ceq'EXACT_NOT_FOUND'){return [pscustomobject]$record}
    if($null-ne$invocationFailure){throw $invocationFailure}
    throw "Dynamic runtime node query returned a foreign result: $Path"
}

function Get-FormalTreeRows {
    param([Parameter(Mandatory=$true)][object]$Root)
    $rows=[Collections.Generic.List[object]]::new();$stack=[Collections.Generic.Stack[object]]::new();$stack.Push($Root)
    while($stack.Count-gt0){
        $row=$stack.Pop();$rows.Add($row)
        $children=@()
        if($null-ne$row.PSObject.Properties['children']){$children=@($row.children)}
        for($index=$children.Count-1;$index-ge0;$index-=1){$stack.Push($children[$index])}
    }
    return @($rows)
}

function Get-FormalTreeCenter {
    param([Parameter(Mandatory=$true)][object]$Row)
    if(-not[bool]$Row.properties.visible-or[double]$Row.properties.size.x-le0-or[double]$Row.properties.size.y-le0){throw "Runtime UI node is not visibly actionable: $($Row.path)"}
    return @{x=([double]$Row.properties.global_position.x+[double]$Row.properties.size.x/2.0);y=([double]$Row.properties.global_position.y+[double]$Row.properties.size.y/2.0)}
}

function Get-FormalRootGatedCenter {
    param(
        [Parameter(Mandatory=$true)][object]$Node,
        [Parameter(Mandatory=$true)][object]$ViewportNode,
        [Parameter(Mandatory=$true)][string]$Context
    )
    $center=Get-Pr90FormalRootActionCenterV1 -Node $Node -ViewportNode $ViewportNode
    if($null-eq$center){throw "Formal refreshed action center is not root-viewport actionable: $Context"}
    return $center
}

function Find-FormalHandCard {
    param(
        [ValidateSet('military','facility')][string]$Domain,
        [string]$ExpectedDefinitionId='',
        [string]$ExpectedSourceInstanceId='',
        [int]$MaximumScrollAttempts=16,
        [int]$MaximumTransientRebindCount=4
    )
    $railPath='V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/HandScroll/HandRail'
    $viewportPath='V075GameScreen/RootMargin';$previousDecision=$null;$scrollCount=0;$scrollAttemptCount=0;$notFoundRebindCount=0;$semanticFingerprint=$null
    $resolutionLedger=[Collections.Generic.List[object]]::new()
    while($true){
        $viewportQueryCallIndex=$script:callIndex+1;$viewport=Get-FormalNode -Path $viewportPath -Properties @()
        $queryCallIndex=$script:callIndex+1;$tree=Get-FormalNodeTree -Path $railPath -MaxDepth 5 -MaxNodes 160
        $candidate=Get-Pr90FormalCardCandidateV1 -Tree $tree -Surface hand -Domain $Domain -TreeTruncated $false
        if($null-eq$candidate){
            if($resolutionLedger.Count-eq0){return $null}
            throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: dynamic hand candidate disappeared after semantic identity observation'
        }
        if(-not(Test-Pr90FormalImmediateAutoGeneratedChildPathV1 -Path ([string]$candidate.path) -StableParentPath $railPath)){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: a production hand card must be the immediate auto-generated child selected from the current HandRail snapshot'}
        $candidateFingerprint=[pscustomobject][ordered]@{domain=$Domain;ui_text=[string]$candidate.ui_text;direct_child_ordinal=[int]$candidate.direct_child_ordinal;script_path='res://scripts/ui/v073/v073_sample_card_button.gd'}
        if($null-eq$semanticFingerprint){$semanticFingerprint=$candidateFingerprint}elseif((ConvertTo-Pr90ProbeBCanonicalJson $semanticFingerprint)-cne(ConvertTo-Pr90ProbeBCanonicalJson $candidateFingerprint)){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: dynamic hand rebind changed the selected card semantic identity'}
        $nodeProperties=if($Domain-ceq'military'){@('_payload')}else{@()}
        $nodeQuery=Invoke-FormalDynamicNodeQuery -StableParentPath $railPath -Path ([string]$candidate.path) -Properties $nodeProperties
        $viewportEvidence=Get-FormalMcpEvidenceRecord -CallIndex $viewportQueryCallIndex -ToolName query_runtime_node
        $treeEvidence=Get-FormalMcpEvidenceRecord -CallIndex $queryCallIndex -ToolName query_runtime_node
        $attemptRow=[ordered]@{attempt_index=($resolutionLedger.Count+1);outcome='';candidate_path=[string]$candidate.path;candidate_ui_text=[string]$candidate.ui_text;candidate_direct_child_ordinal=[int]$candidate.direct_child_ordinal;viewport_query_call_index=$viewportQueryCallIndex;viewport_request_path=[string]$viewportEvidence.request_path;viewport_request_sha256=[string]$viewportEvidence.request_sha256;viewport_raw_path=[string]$viewportEvidence.raw_path;viewport_raw_sha256=[string]$viewportEvidence.raw_sha256;tree_query_call_index=$queryCallIndex;tree_request_path=[string]$treeEvidence.request_path;tree_request_sha256=[string]$treeEvidence.request_sha256;tree_raw_path=[string]$treeEvidence.raw_path;tree_raw_sha256=[string]$treeEvidence.raw_sha256;node_query_call_index=[int]$nodeQuery.call_index;node_request_path=[string]$nodeQuery.request_path;node_request_sha256=[string]$nodeQuery.request_sha256;node_raw_path=[string]$nodeQuery.raw_path;node_raw_sha256=[string]$nodeQuery.raw_sha256;scroll_input_call_index=0;scroll_direction='';scroll_request_path='';scroll_request_sha256='';scroll_raw_path='';scroll_raw_sha256=''}
        if([string]$nodeQuery.classification-ceq'EXACT_NOT_FOUND'){
            $attemptRow.outcome='EXACT_TRANSIENT_NOT_FOUND';$resolutionLedger.Add([pscustomobject]$attemptRow);$notFoundRebindCount+=1
            if($notFoundRebindCount-gt$MaximumTransientRebindCount){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: dynamic hand identity exhausted its exact NOT_FOUND rebind budget'}
            $null=Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=50} -TimeoutSeconds 30
            continue
        }
        $node=$nodeQuery.result
        $candidatePath=[string]$candidate.path
        $expectedRuntimePath=if($candidatePath.StartsWith('/root/Main/',[StringComparison]::Ordinal)){$candidatePath}else{'/root/Main/'+$candidatePath}
        if([string]$node.path-cne$expectedRuntimePath-or[string]$node.type-cne'PanelContainer'-or[string]$node.script_path-cne'res://scripts/ui/v073/v073_sample_card_button.gd'){
            throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: dynamic hand leaf identity diverged from the latest semantic tree snapshot'
        }
        $decision=Get-Pr90FormalTapViewportDecisionV1 -Center (Get-Pr90FormalNodeCenterV1 -Node $node) -ViewportNode $viewport
        if([bool]$decision.green){
            $candidate.properties=$node.properties;$candidate.center=Get-FormalRootGatedCenter -Node $node -ViewportNode $viewport -Context ([string]$candidate.path)
            $candidate|Add-Member -NotePropertyName query_call_index -NotePropertyValue $queryCallIndex
            $candidate|Add-Member -NotePropertyName viewport_query_call_index -NotePropertyValue $viewportQueryCallIndex
            $candidate|Add-Member -NotePropertyName node_query_call_index -NotePropertyValue ([int]$nodeQuery.call_index)
            if($Domain-ceq'military'){
                if([string]::IsNullOrWhiteSpace($ExpectedDefinitionId)){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: a military hand card cannot be accepted without an exact private definition identity'}
                $payload=$node.requested_properties._payload
            if($null-eq$payload){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: the public military hand card did not expose its owner-private identity payload'}
            $instanceId=[string]$payload.instance_id
            if([string]$payload.definition_id-cne$ExpectedDefinitionId-or[string]$payload.card_definition_id-cne$ExpectedDefinitionId-or[string]::IsNullOrWhiteSpace($instanceId)-or[string]$payload.card_instance_id-cne$instanceId-or
                (-not[string]::IsNullOrWhiteSpace($ExpectedSourceInstanceId)-and$instanceId-ceq$ExpectedSourceInstanceId)-or
                [string]$payload.origin_class-cne'standard'-or[string]$payload.primary_color-cne'life'-or[int]$payload.primary_asset_cost-ne2-or
                [string]$payload.asset_cost_profile-cne'v075_military_track_color_rank_1'-or[int]$payload.level-ne1-or$payload.starter_badge-isnot[bool]-or[bool]$payload.starter_badge){
                throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: the public military hand card is not the privately bound acquired submarine-fleet identity'
            }
                $candidate|Add-Member -NotePropertyName private_payload_query_call_index -NotePropertyValue ([int]$nodeQuery.call_index)
            $candidate|Add-Member -NotePropertyName private_definition_id -NotePropertyValue ([string]$payload.definition_id)
            $candidate|Add-Member -NotePropertyName private_instance_id -NotePropertyValue $instanceId
            $candidate|Add-Member -NotePropertyName private_origin_class -NotePropertyValue ([string]$payload.origin_class)
            $candidate|Add-Member -NotePropertyName private_primary_color -NotePropertyValue ([string]$payload.primary_color)
            $candidate|Add-Member -NotePropertyName private_primary_asset_cost -NotePropertyValue ([int]$payload.primary_asset_cost)
            $candidate|Add-Member -NotePropertyName private_asset_cost_profile -NotePropertyValue ([string]$payload.asset_cost_profile)
            $candidate|Add-Member -NotePropertyName private_level -NotePropertyValue ([int]$payload.level)
            $candidate|Add-Member -NotePropertyName private_starter_badge -NotePropertyValue ([bool]$payload.starter_badge)
            }else{$candidate|Add-Member -NotePropertyName private_payload_query_call_index -NotePropertyValue 0}
            $attemptRow.outcome='FOUND_ACTIONABLE';$resolutionLedger.Add([pscustomobject]$attemptRow)
            $candidate|Add-Member -NotePropertyName stable_parent_path -NotePropertyValue $railPath
            $candidate|Add-Member -NotePropertyName transient_not_found_count -NotePropertyValue $notFoundRebindCount
            $candidate|Add-Member -NotePropertyName scroll_count -NotePropertyValue $scrollCount
            $candidate|Add-Member -NotePropertyName resolution_attempts -NotePropertyValue @($resolutionLedger)
            return $candidate
        }
        if([string]$decision.classification-cne'VERTICAL_OUT_OF_BOUNDS'){throw "Formal semantic hand candidate cannot be reached by vertical scrolling: $($candidate.path) ($($decision.classification))"}
        if($null-ne$previousDecision-and-not(Test-Pr90FormalTapViewportProgressV1 -Before $previousDecision -After $decision)){throw 'Formal semantic hand-card viewport scroll did not converge'}
        if($scrollAttemptCount-ge$MaximumScrollAttempts){throw 'Formal semantic hand-card viewport remained off-screen after bounded scrolling'}
        $viewportCenter=@{x=([double]$viewport.properties.global_position.x+[double]$viewport.properties.size.x-8.0);y=([double]$viewport.properties.global_position.y+[double]$viewport.properties.size.y/2.0)}
        if(-not(Test-Pr90FormalTapCenterInScreenV1 -Center $viewportCenter)){throw 'Formal semantic hand-card scroll anchor is outside the formal input surface'}
        $scrollEvents=@(1..4|ForEach-Object{@{type='mouse_button';button=[string]$decision.direction;position=$viewportCenter;mode='tap'}})
        $scrollInputCallIndex=$script:callIndex+1;$null=Send-FormalRuntimeEvents -Events $scrollEvents
        $scrollEvidence=Get-FormalMcpEvidenceRecord -CallIndex $scrollInputCallIndex -ToolName send_runtime_input
        $attemptRow.outcome='SCROLLED';$attemptRow.scroll_input_call_index=$scrollInputCallIndex;$attemptRow.scroll_direction=[string]$decision.direction;$attemptRow.scroll_request_path=[string]$scrollEvidence.request_path;$attemptRow.scroll_request_sha256=[string]$scrollEvidence.request_sha256;$attemptRow.scroll_raw_path=[string]$scrollEvidence.raw_path;$attemptRow.scroll_raw_sha256=[string]$scrollEvidence.raw_sha256;$resolutionLedger.Add([pscustomobject]$attemptRow)
        $null=Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=200} -TimeoutSeconds 30
        $scrollCount+=4;$scrollAttemptCount+=1;$previousDecision=$decision
    }
    throw 'Formal semantic hand-card navigation exhausted unexpectedly'
}

function Find-FormalTrackCard {
    param([ValidateSet('military')][string]$Domain='military')
    $railPath='V075GameScreen/RootMargin/Shell/TrackPanel/TrackMargin/TrackRows/TrackScroll/TrackRail'
    $tree=Get-FormalNodeTree -Path $railPath -MaxDepth 5 -MaxNodes 240
    $candidate=Get-Pr90FormalCardCandidateV1 -Tree $tree -Surface track -Domain $Domain -TreeTruncated $false
    if($null-ne$candidate){
        $viewport=Move-FormalRootViewportToNode -TargetPath ([string]$candidate.path)
        $queryCallIndex=$script:callIndex+1
        $tree=Get-FormalNodeTree -Path $railPath -MaxDepth 5 -MaxNodes 240
        $candidate=Get-Pr90FormalCardCandidateV1 -Tree $tree -Surface track -Domain $Domain -TreeTruncated $false
        if($null-eq$candidate){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: deterministic TrackCard_05 disappeared after root navigation'}
        $candidate.center=Get-FormalRootGatedCenter -Node $candidate -ViewportNode $viewport.viewport_node -Context ([string]$candidate.path)
        $candidate|Add-Member -NotePropertyName query_call_index -NotePropertyValue $queryCallIndex
        $candidate|Add-Member -NotePropertyName viewport_query_call_index -NotePropertyValue ([int]$viewport.viewport_query_call_index)
    }
    return $candidate
}

function Ensure-FormalCombatSurfaceVisible {
    $surfacePath='V075GameScreen/RootMargin/Shell/V075CombatStackHost/V075CombatOverlay/Margin/Rows/SurfaceHost/CombatSurface'
    $collapsePath='V075GameScreen/RootMargin/Shell/V075CombatStackHost/V075CombatOverlay/Margin/Rows/Header/CollapseButton'
    $initialQueryCallIndex=$script:callIndex+1
    $surfaceBefore=Get-FormalNode -Path $surfacePath -Properties @()
    $expandPerformed=$false;$expandCallIndex=0
    if(-not[bool]$surfaceBefore.properties.visible){
        $collapseViewport=Move-FormalRootViewportToNode -TargetPath $collapsePath
        $collapse=Get-FormalNode -Path $collapsePath -Properties @('disabled')
        if([bool]$collapse.requested_properties.disabled-or-not[bool]$collapse.properties.visible-or[double]$collapse.properties.size.x-le0-or[double]$collapse.properties.size.y-le0){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: the public combat-surface expand control is not actionable'}
        $collapseCenter=Get-FormalRootGatedCenter -Node $collapse -ViewportNode $collapseViewport.viewport_node -Context $collapsePath
        $expandCallIndex=$script:callIndex+1;$null=Send-FormalTaps @($collapseCenter)
        $expandPerformed=$true;$null=Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=200} -TimeoutSeconds 30
    }
    $null=Move-FormalRootViewportToNode -TargetPath $surfacePath
    $readyQueryCallIndex=$script:callIndex+1
    $surfaceAfter=Get-FormalNode -Path $surfacePath -Properties @()
    if(-not[bool]$surfaceAfter.properties.visible-or[double]$surfaceAfter.properties.size.x-le0-or[double]$surfaceAfter.properties.size.y-le0){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: the production combat surface did not become visibly actionable'}
    return [pscustomobject][ordered]@{path=$surfacePath;surface_before=$surfaceBefore;surface_after=$surfaceAfter;initial_query_call_index=$initialQueryCallIndex;ready_query_call_index=$readyQueryCallIndex;expand_performed=$expandPerformed;expand_call_index=$expandCallIndex}
}

function Get-FormalMilitaryMissionChoice {
    $surface=Ensure-FormalCombatSurfaceVisible
    $panelPath="$($surface.path)/Rows/PrivateGrid/MilitaryPanel"
    $panelQueryCallIndex=$script:callIndex+1
    $militaryPanel=Get-FormalNode -Path $panelPath -Properties @()
    if(-not[bool]$militaryPanel.properties.visible-or[double]$militaryPanel.properties.size.x-le0-or[double]$militaryPanel.properties.size.y-le0){return $null}
    $base="$($surface.path)/Rows/PrivateGrid/MilitaryPanel/Margin/Rows"
    foreach($candidate in @(@('assault_region','Region'),@('assault_monster','Monster'))){
        $optionPath="$base/TargetMenus/Assault$($candidate[1])Option";$buttonPath="$base/TaskButtons/Assault$($candidate[1])Button"
        $optionViewport=Move-FormalRootViewportToNode -TargetPath $optionPath
        $optionQueryCallIndex=$script:callIndex+1
        $optionBefore=Get-FormalNode -Path $optionPath -Properties @('disabled','item_count','selected')
        if([bool]$optionBefore.requested_properties.disabled-or[int]$optionBefore.requested_properties.item_count-le0-or[int]$optionBefore.requested_properties.selected-ne-1-or-not[bool]$optionBefore.properties.visible-or[double]$optionBefore.properties.size.x-le0-or[double]$optionBefore.properties.size.y-le0){continue}
        $optionSelectCallIndex=$script:callIndex+1
        $optionCenter=Get-FormalRootGatedCenter -Node $optionBefore -ViewportNode $optionViewport.viewport_node -Context $optionPath
        $null=Send-FormalRuntimeEvents @(@{type='mouse_button';button='left';position=$optionCenter;mode='tap'},@{type='action';action='ui_down';mode='tap'},@{type='action';action='ui_accept';mode='tap'})
        $null=Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=200} -TimeoutSeconds 30
        $optionResultQueryCallIndex=$script:callIndex+1
        $optionAfter=Get-FormalNode -Path $optionPath -Properties @('disabled','item_count','selected')
        $buttonViewport=Move-FormalRootViewportToNode -TargetPath $buttonPath
        $buttonQueryCallIndex=$script:callIndex+1
        $buttonAfter=Get-FormalNode -Path $buttonPath -Properties @('disabled')
        $missionUiGreen=Test-Pr90FormalMilitaryMissionUiTransitionV1 `
            -SurfaceBefore $surface.surface_before `
            -SurfaceAfter $surface.surface_after `
            -MilitaryPanelAfter $militaryPanel `
            -OptionBefore $optionBefore `
            -OptionAfter $optionAfter `
            -TaskButtonAfter $buttonAfter `
            -MissionKind ([string]$candidate[0]) `
            -SurfaceExpandPerformed ([bool]$surface.expand_performed)
        if(-not$missionUiGreen){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: military option selection did not enable the exact production task button'}
        $buttonCenter=Get-FormalRootGatedCenter -Node $buttonAfter -ViewportNode $buttonViewport.viewport_node -Context $buttonPath
        return [pscustomobject][ordered]@{mission_kind=[string]$candidate[0];path=$buttonPath;text=[string]$buttonAfter.properties.text;query_call_index=$buttonQueryCallIndex;center=$buttonCenter;panel_path=$panelPath;panel_query_call_index=$panelQueryCallIndex;option_path=$optionPath;option_item_count=[int]$optionBefore.requested_properties.item_count;option_selected_before=[int]$optionBefore.requested_properties.selected;option_selected_after=[int]$optionAfter.requested_properties.selected;option_query_call_index=$optionQueryCallIndex;option_select_call_index=$optionSelectCallIndex;option_result_query_call_index=$optionResultQueryCallIndex;surface=$surface}
    }
    return $null
}

function Get-FormalFirstChoiceButton {
    param([string]$Path,[string]$RequiredNamePattern='',[string]$RequiredTextPattern='',[switch]$RequireUniqueMatch,[int]$MaximumScrollAttempts=16,[int]$MaximumTransientRebindCount=4)
    $viewportPath='V075GameScreen/RootMargin';$previousDecision=$null;$notFoundRebindCount=0;$semanticFingerprint=$null;$scrollCount=0;$scrollAttemptCount=0
    $resolutionLedger=[Collections.Generic.List[object]]::new()
    while($true){
        $viewportQueryCallIndex=$script:callIndex+1;$viewport=Get-FormalNode -Path $viewportPath -Properties @()
        $treeQueryCallIndex=$script:callIndex+1;$tree=Get-FormalNodeTree -Path $Path -MaxDepth 4 -MaxNodes 100
        $row=Get-Pr90FormalFirstChoiceTreeRowV1 -Tree $tree -RequiredNamePattern $RequiredNamePattern -RequiredTextPattern $RequiredTextPattern -RequireUniqueMatch:$RequireUniqueMatch
        if($null-eq$row){
            if($resolutionLedger.Count-eq0){return $null}
            throw "SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: dynamic choice disappeared after semantic identity observation: $Path"
        }
        if(-not(Test-Pr90FormalImmediateChildPathV1 -Path ([string]$row.path) -StableParentPath $Path)){throw "SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: semantic choice is not an immediate child of its stable parent: $Path"}
        $rowText=[string]$row.properties.text;$rowName=[string]$row.name
        $fingerprint=[pscustomobject][ordered]@{name=if(Test-Pr90FormalAutoGeneratedNodePathV1 -Path ([string]$row.path)){''}else{$rowName};text=$rowText;direct_child_ordinal=[int]$row.direct_child_ordinal}
        if($null-eq$semanticFingerprint){$semanticFingerprint=$fingerprint}elseif((ConvertTo-Pr90ProbeBCanonicalJson $semanticFingerprint)-cne(ConvertTo-Pr90ProbeBCanonicalJson $fingerprint)){throw "SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: semantic choice identity drifted while rebinding: $Path"}
        $nodeQuery=Invoke-FormalDynamicNodeQuery -StableParentPath $Path -Path ([string]$row.path) -Properties @('disabled')
        $viewportEvidence=Get-FormalMcpEvidenceRecord -CallIndex $viewportQueryCallIndex -ToolName query_runtime_node;$treeEvidence=Get-FormalMcpEvidenceRecord -CallIndex $treeQueryCallIndex -ToolName query_runtime_node
        $attemptRow=[ordered]@{attempt_index=($resolutionLedger.Count+1);outcome='';candidate_path=[string]$row.path;candidate_name=$rowName;candidate_text=$rowText;candidate_direct_child_ordinal=[int]$row.direct_child_ordinal;viewport_query_call_index=$viewportQueryCallIndex;viewport_request_path=[string]$viewportEvidence.request_path;viewport_request_sha256=[string]$viewportEvidence.request_sha256;viewport_raw_path=[string]$viewportEvidence.raw_path;viewport_raw_sha256=[string]$viewportEvidence.raw_sha256;tree_query_call_index=$treeQueryCallIndex;tree_request_path=[string]$treeEvidence.request_path;tree_request_sha256=[string]$treeEvidence.request_sha256;tree_raw_path=[string]$treeEvidence.raw_path;tree_raw_sha256=[string]$treeEvidence.raw_sha256;node_query_call_index=[int]$nodeQuery.call_index;node_request_path=[string]$nodeQuery.request_path;node_request_sha256=[string]$nodeQuery.request_sha256;node_raw_path=[string]$nodeQuery.raw_path;node_raw_sha256=[string]$nodeQuery.raw_sha256;scroll_input_call_index=0;scroll_direction='';scroll_request_path='';scroll_request_sha256='';scroll_raw_path='';scroll_raw_sha256=''}
        if([string]$nodeQuery.classification-ceq'EXACT_NOT_FOUND'){
            $attemptRow.outcome='EXACT_TRANSIENT_NOT_FOUND';$resolutionLedger.Add([pscustomobject]$attemptRow);$notFoundRebindCount+=1
            if($notFoundRebindCount-gt$MaximumTransientRebindCount){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: dynamic choice identity exhausted its exact NOT_FOUND rebind budget'}
            $null=Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=50} -TimeoutSeconds 30
            continue
        }
        $node=$nodeQuery.result;$rowPath=[string]$row.path;$expectedRuntimePath=if($rowPath.StartsWith('/root/Main/',[StringComparison]::Ordinal)){$rowPath}else{'/root/Main/'+$rowPath}
        if([string]$node.path-cne$expectedRuntimePath-or[string]$node.type-cne'Button'-or[string]$node.name-cne$rowName-or$node.properties.text-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$node.properties.text)-or[string]$node.properties.text-cne$rowText){throw "SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: current choice leaf diverged from its latest semantic tree snapshot: $Path"}
        $disabled=$node.requested_properties.disabled
        if($disabled-isnot[bool]-or[bool]$disabled){return $null}
        $decision=Get-Pr90FormalTapViewportDecisionV1 -Center (Get-Pr90FormalNodeCenterV1 -Node $node) -ViewportNode $viewport
        if([bool]$decision.green){
            $attemptRow.outcome='FOUND_ACTIONABLE';$resolutionLedger.Add([pscustomobject]$attemptRow)
            $choiceCenter=Get-FormalRootGatedCenter -Node $node -ViewportNode $viewport -Context ([string]$row.path)
            return [pscustomobject][ordered]@{path=[string]$row.path;name=$rowName;text=$rowText;center=$choiceCenter;stable_parent_path=$Path;viewport_query_call_index=$viewportQueryCallIndex;tree_query_call_index=$treeQueryCallIndex;node_query_call_index=[int]$nodeQuery.call_index;transient_not_found_count=$notFoundRebindCount;scroll_count=$scrollCount;resolution_attempts=@($resolutionLedger)}
        }
        if([string]$decision.classification-cne'VERTICAL_OUT_OF_BOUNDS'){throw "Formal semantic choice cannot be reached by vertical scrolling: $Path ($($decision.classification))"}
        if($null-ne$previousDecision-and-not(Test-Pr90FormalTapViewportProgressV1 -Before $previousDecision -After $decision)){throw "Formal semantic choice viewport scroll did not converge: $Path"}
        if($scrollAttemptCount-ge$MaximumScrollAttempts){throw "Formal semantic choice remained off-screen after bounded scrolling: $Path"}
        $viewportCenter=@{x=([double]$viewport.properties.global_position.x+[double]$viewport.properties.size.x-8.0);y=([double]$viewport.properties.global_position.y+[double]$viewport.properties.size.y/2.0)}
        if(-not(Test-Pr90FormalTapCenterInScreenV1 -Center $viewportCenter)){throw 'Formal semantic choice scroll anchor is outside the formal input surface'}
        $scrollEvents=@(1..4|ForEach-Object{@{type='mouse_button';button=[string]$decision.direction;position=$viewportCenter;mode='tap'}})
        $scrollInputCallIndex=$script:callIndex+1;$null=Send-FormalRuntimeEvents -Events $scrollEvents;$scrollEvidence=Get-FormalMcpEvidenceRecord -CallIndex $scrollInputCallIndex -ToolName send_runtime_input
        $attemptRow.outcome='SCROLLED';$attemptRow.scroll_input_call_index=$scrollInputCallIndex;$attemptRow.scroll_direction=[string]$decision.direction;$attemptRow.scroll_request_path=[string]$scrollEvidence.request_path;$attemptRow.scroll_request_sha256=[string]$scrollEvidence.request_sha256;$attemptRow.scroll_raw_path=[string]$scrollEvidence.raw_path;$attemptRow.scroll_raw_sha256=[string]$scrollEvidence.raw_sha256;$resolutionLedger.Add([pscustomobject]$attemptRow)
        $null=Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=200} -TimeoutSeconds 30;$scrollCount+=4;$scrollAttemptCount+=1;$previousDecision=$decision
    }
    throw "Formal semantic choice navigation exhausted unexpectedly: $Path"
}

function Get-FormalMcpEvidenceRecord {
    param([int]$CallIndex,[ValidateSet('query_runtime_node','send_runtime_input')][string]$ToolName)
    $requestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-{1}.json' -f $CallIndex,$ToolName)
    $rawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-{1}.jsonrpc.json' -f $CallIndex,$ToolName)
    foreach($requiredPath in @($requestPath,$rawPath)){if(-not(Test-Path -LiteralPath $requiredPath -PathType Leaf)){throw "Formal MCP evidence missing: $requiredPath"}}
    return [pscustomobject][ordered]@{request_path=[IO.Path]::GetFullPath($requestPath);request_sha256=Get-Pr90ProbeBSha256 $requestPath;raw_path=[IO.Path]::GetFullPath($rawPath);raw_sha256=Get-Pr90ProbeBSha256 $rawPath}
}

function Get-FormalProperty {
    param([string]$Path, [string]$Name)
    return (Get-FormalNode -Path $Path -Properties @($Name)).requested_properties.$Name
}

function Get-FormalCenter {
    param([string]$Path)
    $node = Get-FormalNode -Path $Path -Properties @('disabled')
    return @{x=([double]$node.properties.global_position.x + [double]$node.properties.size.x / 2.0);y=([double]$node.properties.global_position.y + [double]$node.properties.size.y / 2.0)}
}

function Move-FormalRootViewportToNode {
    param([Parameter(Mandatory=$true)][string]$TargetPath,[int]$MaximumScrollAttempts=16)
    if(Test-Pr90FormalAutoGeneratedNodePathV1 -Path $TargetPath){throw "Auto-generated runtime node paths cannot be used as durable viewport targets: $TargetPath"}
    $viewportPath='V075GameScreen/RootMargin';$previousDecision=$null;$scrollCount=0
    for($attempt=0;$attempt-le$MaximumScrollAttempts;$attempt+=1){
        $viewportQueryCallIndex=$script:callIndex+1;$viewport=Get-FormalNode -Path $viewportPath -Properties @()
        $targetQueryCallIndex=$script:callIndex+1;$target=Get-FormalNode -Path $TargetPath -Properties @()
        if(-not[bool]$target.properties.visible-or[double]$target.properties.size.x-le0-or[double]$target.properties.size.y-le0){throw "Formal viewport target is not visibly actionable: $TargetPath"}
        $targetCenter=@{x=([double]$target.properties.global_position.x+[double]$target.properties.size.x/2.0);y=([double]$target.properties.global_position.y+[double]$target.properties.size.y/2.0)}
        $decision=Get-Pr90FormalTapViewportDecisionV1 -Center $targetCenter -ViewportNode $viewport
        if([bool]$decision.green){return [pscustomobject][ordered]@{target_path=$TargetPath;center=$decision.center;viewport_node=$viewport;viewport_query_call_index=$viewportQueryCallIndex;target_query_call_index=$targetQueryCallIndex;scroll_count=$scrollCount}}
        if([string]$decision.classification-cne'VERTICAL_OUT_OF_BOUNDS'){throw "Formal viewport target cannot be reached by vertical scrolling: $TargetPath ($($decision.classification))"}
        if($null-ne$previousDecision-and-not(Test-Pr90FormalTapViewportProgressV1 -Before $previousDecision -After $decision)){throw "Formal viewport scroll did not converge toward target: $TargetPath"}
        if($attempt-eq$MaximumScrollAttempts){throw "Formal viewport target remained off-screen after bounded scrolling: $TargetPath"}
        $viewportCenter=@{x=([double]$viewport.properties.global_position.x+[double]$viewport.properties.size.x-8.0);y=([double]$viewport.properties.global_position.y+[double]$viewport.properties.size.y/2.0)}
        if(-not(Test-Pr90FormalTapCenterInScreenV1 -Center $viewportCenter)){throw 'Formal root viewport scroll anchor is outside the formal input surface'}
        $scrollEvents=@(1..4|ForEach-Object{@{type='mouse_button';button=[string]$decision.direction;position=$viewportCenter;mode='tap'}})
        $null=Send-FormalRuntimeEvents -Events $scrollEvents;$null=Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=200} -TimeoutSeconds 30
        $scrollCount+=4;$previousDecision=$decision
    }
    throw "Formal viewport target navigation exhausted unexpectedly: $TargetPath"
}

function Send-FormalRuntimeEvents {
    param([object[]]$Events)
    $payload = Get-FormalStructured (Invoke-FormalMcp -ToolName 'send_runtime_input' -Arguments @{events=$events;timeout_msec=60000} -TimeoutSeconds 60)
    $commandId=[string]$payload.command_id
    if (-not [bool]$payload.success -or [string]$payload.command-cne'send_input' -or [string]::IsNullOrWhiteSpace($commandId) -or
        -not[bool]$payload.response.success -or [string]$payload.response.command-cne'send_input' -or [string]$payload.response.id-cne$commandId) { throw 'Formal runtime input failed or returned an unbound command identity.' }
    return $commandId
}

function Send-FormalTaps {
    param([object[]]$Centers)
    $events=@($Centers|ForEach-Object{$center=ConvertTo-Pr90FormalTapCenterV1 -Center $_;if($null-eq$center-or-not(Test-Pr90FormalTapCenterInScreenV1 -Center $center)){throw 'Formal tap center is invalid or outside the formal input surface'};@{type='mouse_button';button='left';position=$center;mode='tap'}})
    if($events.Count-ne$Centers.Count-or$events.Count-eq0){throw 'Formal tap center normalization did not preserve exact cardinality'}
    return Send-FormalRuntimeEvents -Events $events
}

function Wait-FormalPostInputBridgeReadiness {
    param(
        [Parameter(Mandatory=$true)][string]$ExpectedCommandId,
        [Parameter(Mandatory=$true)][string]$ExpectedStreamId,
        [Parameter(Mandatory=$true)][int64]$MinimumCursorAfter,
        [int]$MaximumWaitSeconds=60
    )
    $attemptRows=[Collections.Generic.List[object]]::new();$firstGreen=$null;$secondGreen=$null;$lastStatus=$null;$lastObservationClass='MCP_STATUS_UNAVAILABLE';$hardFailureClass='';$sawProductReadinessStall=$false
    $started=[DateTimeOffset]::UtcNow;$deadline=$started.AddSeconds($MaximumWaitSeconds)
    while([DateTimeOffset]::UtcNow-lt$deadline){
        $statusCallIndex=$script:callIndex+1;$statusPayload=$null;$errorText=''
        try{$statusPayload=Get-FormalStructured (Invoke-FormalMcp -ToolName 'get_runtime_bridge_status' -Arguments @{} -TimeoutSeconds 10);$lastStatus=$statusPayload}catch{$errorText=$_.Exception.Message}
        $minimumModified=if($null-eq$firstGreen){[long]0}else{[long]$firstGreen.state_modified_unix}
        $effectiveMinimumCursor=if($null-eq$firstGreen){$MinimumCursorAfter}else{[Math]::Max([int64]$MinimumCursorAfter,[int64]$firstGreen.state.runtime_event_cursor.buffered_last_event_sequence)}
        $lastObservationClass=Get-Pr90FormalPostInputReadinessObservationClassV1 -Status $statusPayload -ObservationError $errorText -ExpectedStreamId $ExpectedStreamId -MinimumCursorAfter $effectiveMinimumCursor -ExpectedCommandId $ExpectedCommandId -AllowPendingExpectedCommandState ($null-eq$firstGreen)
        $sampleGreen=Test-Pr90FormalPostInputBridgeReadinessSampleV1 -Status $statusPayload -ExpectedStreamId $ExpectedStreamId -MinimumCursorAfter $effectiveMinimumCursor -ExpectedCommandId $ExpectedCommandId -MinimumStateModifiedUnix $minimumModified -MaximumStateAgeMsec 2500
        if($lastObservationClass-in@('READINESS_IDENTITY_GREEN','AWAITING_EXPECTED_COMMAND_HEARTBEAT','AWAITING_POST_COMMAND_RUNNING_HEARTBEAT')-and-not$sampleGreen){$sawProductReadinessStall=$true}
        $requestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-get_runtime_bridge_status.json' -f $statusCallIndex);$rawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-get_runtime_bridge_status.jsonrpc.json' -f $statusCallIndex)
        $attemptRows.Add([pscustomobject][ordered]@{call_index=$statusCallIndex;sample_green=$sampleGreen;observation_class=$lastObservationClass;effective_minimum_cursor=$effectiveMinimumCursor;state_status=if($null-ne$statusPayload){[string]$statusPayload.state.status}else{''};state_modified_unix=if($null-ne$statusPayload){[long]$statusPayload.state_modified_unix}else{0};state_age_msec=if($null-ne$statusPayload){[long]$statusPayload.state_age_msec}else{-1};stream_id=if($null-ne$statusPayload){[string]$statusPayload.state.runtime_event_cursor.stream_id}else{''};cursor_after=if($null-ne$statusPayload){[int64]$statusPayload.state.runtime_event_cursor.buffered_last_event_sequence}else{0};last_command_id=if($null-ne$statusPayload){[string]$statusPayload.state.last_command_id}else{''};request_path=[IO.Path]::GetFullPath($requestPath);request_sha256=if(Test-Path -LiteralPath $requestPath -PathType Leaf){Get-Pr90ProbeBSha256 $requestPath}else{''};raw_path=[IO.Path]::GetFullPath($rawPath);raw_sha256=if(Test-Path -LiteralPath $rawPath -PathType Leaf){Get-Pr90ProbeBSha256 $rawPath}else{''};error=$errorText})
        if($lastObservationClass-in@('RUNTIME_EVENT_OVERFLOW','RUNTIME_IDENTITY_DRIFT','RUNTIME_CURSOR_REGRESSION')){$hardFailureClass=$lastObservationClass;break}
        if($sampleGreen){if($null-eq$firstGreen){$firstGreen=$statusPayload}else{$secondGreen=$statusPayload;break}}
        Start-Sleep -Milliseconds 1000
    }
    $passed=[string]::IsNullOrWhiteSpace($hardFailureClass)-and$null-ne$firstGreen-and$null-ne$secondGreen
    $failureClass=Resolve-Pr90FormalPostInputReadinessOutcomeV1 -Passed $passed -HardFailureClass $hardFailureClass -SawProductReadinessStall $sawProductReadinessStall -LastObservationClass $lastObservationClass
    $witness=[pscustomobject][ordered]@{schema='SpaceSyndicatePostInputBridgeReadinessV1';run_id=$RunId;status=if($passed){'PASS'}else{'BLOCKED'};failure_class=$failureClass;hard_failure_class=$hardFailureClass;saw_product_readiness_stall=$sawProductReadinessStall;expected_stream_id=$ExpectedStreamId;expected_command_id=$ExpectedCommandId;minimum_cursor_after=$MinimumCursorAfter;maximum_wait_seconds=$MaximumWaitSeconds;maximum_state_age_msec=2500;attempt_count=$attemptRows.Count;first_heartbeat_state_modified_unix=if($null-ne$firstGreen){[long]$firstGreen.state_modified_unix}else{0};first_heartbeat_cursor_after=if($null-ne$firstGreen){[int64]$firstGreen.state.runtime_event_cursor.buffered_last_event_sequence}else{0};second_heartbeat_state_modified_unix=if($null-ne$secondGreen){[long]$secondGreen.state_modified_unix}else{0};second_heartbeat_cursor_after=if($null-ne$secondGreen){[int64]$secondGreen.state.runtime_event_cursor.buffered_last_event_sequence}else{0};last_observation_class=$lastObservationClass;last_observed_state_modified_unix=if($null-ne$lastStatus){[long]$lastStatus.state_modified_unix}else{0};last_observed_state_age_msec=if($null-ne$lastStatus){[long]$lastStatus.state_age_msec}else{-1};last_observed_stream_id=if($null-ne$lastStatus){[string]$lastStatus.state.runtime_event_cursor.stream_id}else{''};last_observed_cursor_after=if($null-ne$lastStatus){[int64]$lastStatus.state.runtime_event_cursor.buffered_last_event_sequence}else{0};last_observed_command_id=if($null-ne$lastStatus){[string]$lastStatus.state.last_command_id}else{''};attempts=@($attemptRows);canonical_payload_sha256=''}
    $witness.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $witness
    $witnessPath=Join-Path $EvidenceRoot 'phases/002-phase-2-post-input-bridge-readiness.json'
    Write-StartupImmutableJson -Path $witnessPath -Value $witness -WriteSha256Sidecar|Out-Null
    if(-not$passed){throw "${failureClass}: post-input bridge did not produce two fresh exact-identity heartbeats within $MaximumWaitSeconds seconds."}
    return $secondGreen
}

try {
    if($null-ne$primaryFailure){throw $primaryFailure}
    $null = Invoke-FormalMcp -ToolName 'exit_play_mode' -Arguments @{} -TimeoutSeconds 30
    $null = Invoke-FormalMcp -ToolName 'play_main_scene' -Arguments @{} -TimeoutSeconds 60
    $null = Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=2000} -TimeoutSeconds 30
    Set-FormalMainRuntimeStream
    Poll-FormalCursor -Phase 'phase-1-main-scene' | Out-Null
    $rootNode = Get-FormalNode -Path 'current_scene'
    if ([string]$rootNode.scene_file_path -cne 'res://scenes/main.tscn') { throw 'Formal v5 main-scene identity mismatch.' }
    $deterministicMatchSeed=900626424
    $seedInputPath='V075GameScreen/OverlayLayer/StartOverlay/Center/Panel/Margin/Rows/SeedRow/SeedInput'
    $seedInputCallIndex=$script:callIndex+1
    $seedInputValue=[string](Get-FormalProperty -Path $seedInputPath -Name 'text')
    $seedRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-query_runtime_node.json' -f $seedInputCallIndex);$seedRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-query_runtime_node.jsonrpc.json' -f $seedInputCallIndex)
    foreach($requiredPath in @($seedRequestPath,$seedRawPath)){if(-not(Test-Path -LiteralPath $requiredPath -PathType Leaf)){throw "Formal combat seed evidence missing: $requiredPath"}}
    if($seedInputValue-cne[string]$deterministicMatchSeed){throw "SCENARIO_COMBAT_SEED_IDENTITY_MISMATCH: expected $deterministicMatchSeed, observed $seedInputValue"}
    $startCenter = Get-FormalCenter 'V075GameScreen/OverlayLayer/StartOverlay/Center/Panel/Margin/Rows/PlayerButtons/V074SettingsStack/StartConfiguredButton'
    $startInputCommandId=Send-FormalTaps @($startCenter)
    Wait-FormalPostInputBridgeReadiness -ExpectedCommandId $startInputCommandId -ExpectedStreamId $streamId -MinimumCursorAfter ($cursor+1) -MaximumWaitSeconds 60|Out-Null
    Poll-FormalCursor -Phase 'phase-2-new-game' -InnerTimeoutMsec 30000 -OuterTimeoutSeconds 60 | Out-Null
    $baselineAcceptanceCallIndex=$script:callIndex+1;$acceptance=Get-FormalProperty -Path 'V075GameScreen' -Name 'acceptance_state'
    $baselineRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-query_runtime_node.json' -f $baselineAcceptanceCallIndex);$baselineRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-query_runtime_node.jsonrpc.json' -f $baselineAcceptanceCallIndex)
    foreach($requiredPath in @($baselineRequestPath,$baselineRawPath)){if(-not(Test-Path -LiteralPath $requiredPath -PathType Leaf)){throw "Formal combat baseline evidence missing: $requiredPath"}}
    $initialWrapper=$acceptance.combat_wrapper
    $combatBaseline=[pscustomobject][ordered]@{combat_wrapper=$initialWrapper}
    Poll-FormalCursor -Phase 'phase-3-early-match' | Out-Null
    $settled=$false;$combatTrackAcquisition=$null;$combatScenarioWitness=$null;$combatScenarioWitnessPath='';$combatScenarioWitnessSha='';$facilityAdvanceActionCount=0;$facilityAdvanceSteps=[Collections.Generic.List[object]]::new();$facilityBatchTransitions=[Collections.Generic.List[object]]::new()
    for ($batch=0; $batch -lt 32; $batch += 1) {
        if($null-eq$combatTrackAcquisition){
            $combatCardRegistryPath=Join-Path $Worktree 'scripts/v075/cards/v075_card_definition_registry.gd'
            $combatCardRegistrySha256=Get-Pr90ProbeBSha256 $combatCardRegistryPath
            if($combatCardRegistrySha256-cne'0a06f99a7ed010595865ed7d1c339fe15516586891e60c2c912729a745d92932'){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: sealed V075 combat card registry source identity mismatch'}
            $preAcquireHandQueryCallIndex=$script:callIndex+1
            $preAcquireHandTree=Get-FormalNodeTree -Path 'V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/HandScroll/HandRail' -MaxDepth 5 -MaxNodes 160
            if($null-ne(Get-Pr90FormalCardCandidateV1 -Tree $preAcquireHandTree -Surface hand -Domain military -TreeTruncated $false)){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: the fixed-seed initial hand unexpectedly already contains a public military card'}
            $preAcquireHandEvidence=Get-FormalMcpEvidenceRecord -CallIndex $preAcquireHandQueryCallIndex -ToolName query_runtime_node
            $trackMilitary=Find-FormalTrackCard
            if($null-eq$trackMilitary){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: deterministic TrackCard_05 military card is absent'}
            $trackPayloadQueryCallIndex=$script:callIndex+1
            $trackPayloadResult=Get-FormalNode -Path ([string]$trackMilitary.path) -Properties @('_payload')
            $trackPayload=$trackPayloadResult.requested_properties._payload
            if($null-eq$trackPayload-or[string]$trackPayload.instance_id-cne'track.card.00000005'-or[string]$trackPayload.card_definition_id-cne'military.submarine_fleet.life.rank_1'-or
                [string]$trackPayload.card_kind-cne'normal_card'-or[int]$trackPayload.level-ne1-or[string]$trackPayload.primary_color-cne'life'-or[int]$trackPayload.local_slot_index-ne5-or
                $trackPayload.claimable-isnot[bool]-or-not[bool]$trackPayload.claimable-or[string]$trackPayload.claimability_state-cne'claimable'-or[string]$trackPayload.origin_class-cne'standard'-or
                [string]$trackPayload.asset_cost_profile-cne'v075_military_track_color_rank_1'-or[int]$trackPayload.primary_asset_cost-ne2-or$trackPayload.starter_badge-isnot[bool]-or[bool]$trackPayload.starter_badge-or
                [int]$trackPayload.track_revision-ne4-or[int]$trackPayload.claimable_from_scroll_sequence-ne0){
                throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: deterministic TrackCard_05 private payload identity mismatch'
            }
            $trackBefore=[int]$acceptance.interaction_counts.track_acquired;$visibleBefore=[int]$acceptance.track_player_projection_visible_card_count;$realBefore=[int]$acceptance.track_current_real_card_count;$vacancyBefore=[int]$acceptance.track_vacancy_slot_count;$invalidBefore=[int]$acceptance.invalid_action_count
            $acquireTapCallIndex=$script:callIndex+1;$null=Send-FormalTaps @($trackMilitary.center)
            $null=Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=350} -TimeoutSeconds 30
            $acquireAcceptanceCallIndex=$script:callIndex+1;$acquireAcceptance=Get-FormalProperty -Path 'V075GameScreen' -Name 'acceptance_state'
            $trackAfter=[int]$acquireAcceptance.interaction_counts.track_acquired;$visibleAfter=[int]$acquireAcceptance.track_player_projection_visible_card_count;$realAfter=[int]$acquireAcceptance.track_current_real_card_count;$vacancyAfter=[int]$acquireAcceptance.track_vacancy_slot_count
            if($trackAfter-$trackBefore-ne1-or$visibleAfter-$visibleBefore-ne-1-or$realAfter-$realBefore-ne-1-or$vacancyAfter-$vacancyBefore-ne1-or
                [int]$acquireAcceptance.track_ui_render_capacity-ne10-or[int]$acquireAcceptance.track_physical_slot_count-ne10-or[int]$acquireAcceptance.track_vacancy_interactive_count-ne0-or[int]$acquireAcceptance.track_duplicate_instance_count-ne0-or
                [int]$acquireAcceptance.track_immediate_authoritative_refill_count-ne0-or[int]$acquireAcceptance.track_supply_rng_draw_delta_on_acquisition-ne0-or[int]$acquireAcceptance.track_supply_cursor_delta_on_acquisition-ne0-or[int]$acquireAcceptance.track_supply_instance_sequence_delta_on_acquisition-ne0-or
                [int]$acquireAcceptance.invalid_action_count-ne$invalidBefore){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: deterministic military Track acquisition postcondition mismatch'}
            $acquireRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-send_runtime_input.json' -f $acquireTapCallIndex);$acquireRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-send_runtime_input.jsonrpc.json' -f $acquireTapCallIndex)
            $trackRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-query_runtime_node.json' -f ([int]$trackMilitary.query_call_index));$trackRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-query_runtime_node.jsonrpc.json' -f ([int]$trackMilitary.query_call_index))
            $acquireAcceptanceRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-query_runtime_node.json' -f $acquireAcceptanceCallIndex);$acquireAcceptanceRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-query_runtime_node.jsonrpc.json' -f $acquireAcceptanceCallIndex)
            $trackPayloadEvidence=Get-FormalMcpEvidenceRecord -CallIndex $trackPayloadQueryCallIndex -ToolName query_runtime_node
            $trackViewportEvidence=Get-FormalMcpEvidenceRecord -CallIndex ([int]$trackMilitary.viewport_query_call_index) -ToolName query_runtime_node
            foreach($requiredPath in @($trackRequestPath,$trackRawPath,$trackViewportEvidence.request_path,$trackViewportEvidence.raw_path,$trackPayloadEvidence.request_path,$trackPayloadEvidence.raw_path,$acquireRequestPath,$acquireRawPath,$acquireAcceptanceRequestPath,$acquireAcceptanceRawPath)){if(-not(Test-Path -LiteralPath $requiredPath -PathType Leaf)){throw "Formal combat track acquisition evidence missing: $requiredPath"}}
            $combatTrackAcquisition=[pscustomobject][ordered]@{card_domain='military';card_node_path=[string]$trackMilitary.path;card_ui_text=[string]$trackMilitary.ui_text;private_definition_id=[string]$trackPayload.card_definition_id;private_instance_id=[string]$trackPayload.instance_id;private_origin_class=[string]$trackPayload.origin_class;private_primary_color=[string]$trackPayload.primary_color;private_primary_asset_cost=[int]$trackPayload.primary_asset_cost;initial_public_military_hand_candidate_count=0;pre_acquire_hand_request_path=[string]$preAcquireHandEvidence.request_path;pre_acquire_hand_request_sha256=[string]$preAcquireHandEvidence.request_sha256;pre_acquire_hand_raw_path=[string]$preAcquireHandEvidence.raw_path;pre_acquire_hand_raw_sha256=[string]$preAcquireHandEvidence.raw_sha256;track_viewport_request_path=[string]$trackViewportEvidence.request_path;track_viewport_request_sha256=[string]$trackViewportEvidence.request_sha256;track_viewport_raw_path=[string]$trackViewportEvidence.raw_path;track_viewport_raw_sha256=[string]$trackViewportEvidence.raw_sha256;track_request_path=[IO.Path]::GetFullPath($trackRequestPath);track_request_sha256=Get-Pr90ProbeBSha256 $trackRequestPath;track_raw_path=[IO.Path]::GetFullPath($trackRawPath);track_raw_sha256=Get-Pr90ProbeBSha256 $trackRawPath;track_payload_request_path=[string]$trackPayloadEvidence.request_path;track_payload_request_sha256=[string]$trackPayloadEvidence.request_sha256;track_payload_raw_path=[string]$trackPayloadEvidence.raw_path;track_payload_raw_sha256=[string]$trackPayloadEvidence.raw_sha256;track_acquired_before=$trackBefore;track_acquired_after=$trackAfter;track_acquired_delta=($trackAfter-$trackBefore);track_visible_card_delta=($visibleAfter-$visibleBefore);track_real_card_delta=($realAfter-$realBefore);track_vacancy_delta=($vacancyAfter-$vacancyBefore);request_path=[IO.Path]::GetFullPath($acquireRequestPath);request_sha256=Get-Pr90ProbeBSha256 $acquireRequestPath;raw_path=[IO.Path]::GetFullPath($acquireRawPath);raw_sha256=Get-Pr90ProbeBSha256 $acquireRawPath;acceptance_request_path=[IO.Path]::GetFullPath($acquireAcceptanceRequestPath);acceptance_request_sha256=Get-Pr90ProbeBSha256 $acquireAcceptanceRequestPath;acceptance_raw_path=[IO.Path]::GetFullPath($acquireAcceptanceRawPath);acceptance_raw_sha256=Get-Pr90ProbeBSha256 $acquireAcceptanceRawPath}
            $combatTrackAcquisition|Add-Member -NotePropertyName private_asset_cost_profile -NotePropertyValue ([string]$trackPayload.asset_cost_profile)
            $combatTrackAcquisition|Add-Member -NotePropertyName private_track_revision -NotePropertyValue ([int]$trackPayload.track_revision)
            $combatTrackAcquisition|Add-Member -NotePropertyName private_claimable_from_scroll_sequence -NotePropertyValue ([int]$trackPayload.claimable_from_scroll_sequence)
            $combatTrackAcquisition|Add-Member -NotePropertyName card_definition_registry_sha256 -NotePropertyValue $combatCardRegistrySha256
            $acceptance=$acquireAcceptance
        }
        if($null-eq$combatScenarioWitness){
            $militaryCard=Find-FormalHandCard -Domain 'military' -ExpectedDefinitionId ([string]$combatTrackAcquisition.private_definition_id) -ExpectedSourceInstanceId ([string]$combatTrackAcquisition.private_instance_id)
            $missionChoice=$null;$cardSelectionAcceptance=$null;$cardTapCallIndex=0;$cardAcceptanceCallIndex=0;$cardSelectedBefore=0;$cardSelectedAfter=0
            if($null-ne$militaryCard){
                $cardSelectedBefore=[int]$acceptance.interaction_counts.card_selected;$cardInvalidBefore=[int]$acceptance.invalid_action_count
                $cardTapCallIndex=$script:callIndex+1;$null=Send-FormalTaps @($militaryCard.center)
                $null=Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=250} -TimeoutSeconds 30
                $cardAcceptanceCallIndex=$script:callIndex+1;$cardSelectionAcceptance=Get-FormalProperty -Path 'V075GameScreen' -Name 'acceptance_state';$cardSelectedAfter=[int]$cardSelectionAcceptance.interaction_counts.card_selected
                if($cardSelectedAfter-$cardSelectedBefore-ne1-or[int]$cardSelectionAcceptance.invalid_action_count-ne$cardInvalidBefore){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: the acquired military card was not selected through the production hand UI'}
                $acceptance=$cardSelectionAcceptance
                $missionChoice=Get-FormalMilitaryMissionChoice
                if($null-eq$missionChoice){
                    $freshSelectedMilitary=Find-FormalHandCard -Domain 'military' -ExpectedDefinitionId ([string]$combatTrackAcquisition.private_definition_id) -ExpectedSourceInstanceId ([string]$combatTrackAcquisition.private_instance_id)
                    if($null-eq$freshSelectedMilitary-or[string]$freshSelectedMilitary.private_instance_id-cne[string]$militaryCard.private_instance_id){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: the selected military card could not be freshly rebound for safe deselection'}
                    $null=Send-FormalTaps @($freshSelectedMilitary.center)
                    $null=Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=200} -TimeoutSeconds 30
                    $acceptance=Get-FormalProperty -Path 'V075GameScreen' -Name 'acceptance_state'
                }
            }
            if($null-ne$militaryCard-and$null-ne$missionChoice){
                $militaryIntentBefore=[int]$acceptance.combat_wrapper.military_intent_count;$missionTapCallIndex=$script:callIndex+1;$null=Send-FormalTaps @($missionChoice.center)
                $null=Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=300} -TimeoutSeconds 30
                $acceptanceCallIndex=$script:callIndex+1;$missionAcceptance=Get-FormalProperty -Path 'V075GameScreen' -Name 'acceptance_state';$militaryIntentAfter=[int]$missionAcceptance.combat_wrapper.military_intent_count
                if($militaryIntentAfter-$militaryIntentBefore-ne1){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: military mission was not legally submitted through the UI'}
                $handRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-query_runtime_node.json' -f ([int]$militaryCard.query_call_index));$handRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-query_runtime_node.jsonrpc.json' -f ([int]$militaryCard.query_call_index))
                $handViewportRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-query_runtime_node.json' -f ([int]$militaryCard.viewport_query_call_index));$handViewportRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-query_runtime_node.jsonrpc.json' -f ([int]$militaryCard.viewport_query_call_index))
                $handPayloadRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-query_runtime_node.json' -f ([int]$militaryCard.private_payload_query_call_index));$handPayloadRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-query_runtime_node.jsonrpc.json' -f ([int]$militaryCard.private_payload_query_call_index))
                $cardRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-send_runtime_input.json' -f $cardTapCallIndex);$cardRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-send_runtime_input.jsonrpc.json' -f $cardTapCallIndex)
                $cardAcceptanceRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-query_runtime_node.json' -f $cardAcceptanceCallIndex);$cardAcceptanceRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-query_runtime_node.jsonrpc.json' -f $cardAcceptanceCallIndex)
                $surfaceInitialQueryRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-query_runtime_node.json' -f ([int]$missionChoice.surface.initial_query_call_index));$surfaceInitialQueryRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-query_runtime_node.jsonrpc.json' -f ([int]$missionChoice.surface.initial_query_call_index))
                $surfaceReadyQueryRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-query_runtime_node.json' -f ([int]$missionChoice.surface.ready_query_call_index));$surfaceReadyQueryRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-query_runtime_node.jsonrpc.json' -f ([int]$missionChoice.surface.ready_query_call_index))
                $missionPanelQueryRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-query_runtime_node.json' -f ([int]$missionChoice.panel_query_call_index));$missionPanelQueryRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-query_runtime_node.jsonrpc.json' -f ([int]$missionChoice.panel_query_call_index))
                $surfaceExpandRequestPath='';$surfaceExpandRawPath=''
                if([bool]$missionChoice.surface.expand_performed){$surfaceExpandRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-send_runtime_input.json' -f ([int]$missionChoice.surface.expand_call_index));$surfaceExpandRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-send_runtime_input.jsonrpc.json' -f ([int]$missionChoice.surface.expand_call_index))}
                $missionOptionQueryRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-query_runtime_node.json' -f ([int]$missionChoice.option_query_call_index));$missionOptionQueryRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-query_runtime_node.jsonrpc.json' -f ([int]$missionChoice.option_query_call_index))
                $missionOptionRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-send_runtime_input.json' -f ([int]$missionChoice.option_select_call_index));$missionOptionRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-send_runtime_input.jsonrpc.json' -f ([int]$missionChoice.option_select_call_index))
                $missionOptionResultQueryRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-query_runtime_node.json' -f ([int]$missionChoice.option_result_query_call_index));$missionOptionResultQueryRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-query_runtime_node.jsonrpc.json' -f ([int]$missionChoice.option_result_query_call_index))
                $missionQueryRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-query_runtime_node.json' -f ([int]$missionChoice.query_call_index));$missionQueryRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-query_runtime_node.jsonrpc.json' -f ([int]$missionChoice.query_call_index))
                $missionRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-send_runtime_input.json' -f $missionTapCallIndex);$missionRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-send_runtime_input.jsonrpc.json' -f $missionTapCallIndex)
                $acceptanceRequestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-query_runtime_node.json' -f $acceptanceCallIndex);$acceptanceRawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-query_runtime_node.jsonrpc.json' -f $acceptanceCallIndex)
                $scenarioRequiredPaths=@($seedRequestPath,$seedRawPath,$baselineRequestPath,$baselineRawPath,[string]$combatTrackAcquisition.pre_acquire_hand_request_path,[string]$combatTrackAcquisition.pre_acquire_hand_raw_path,[string]$combatTrackAcquisition.track_viewport_request_path,[string]$combatTrackAcquisition.track_viewport_raw_path,[string]$combatTrackAcquisition.track_request_path,[string]$combatTrackAcquisition.track_raw_path,[string]$combatTrackAcquisition.track_payload_request_path,[string]$combatTrackAcquisition.track_payload_raw_path,$handViewportRequestPath,$handViewportRawPath,$handRequestPath,$handRawPath,$handPayloadRequestPath,$handPayloadRawPath,$cardRequestPath,$cardRawPath,$cardAcceptanceRequestPath,$cardAcceptanceRawPath,$surfaceInitialQueryRequestPath,$surfaceInitialQueryRawPath,$surfaceReadyQueryRequestPath,$surfaceReadyQueryRawPath,$missionPanelQueryRequestPath,$missionPanelQueryRawPath,$missionOptionQueryRequestPath,$missionOptionQueryRawPath,$missionOptionRequestPath,$missionOptionRawPath,$missionOptionResultQueryRequestPath,$missionOptionResultQueryRawPath,$missionQueryRequestPath,$missionQueryRawPath,$missionRequestPath,$missionRawPath,$acceptanceRequestPath,$acceptanceRawPath)
                $resolutionLedgers=[Collections.Generic.List[object]]::new();foreach($attemptRow in @($militaryCard.resolution_attempts)){$resolutionLedgers.Add($attemptRow)};foreach($facilityStepRow in @($facilityAdvanceSteps)){foreach($ledgerName in @('facility_hand_resolution_attempts','target_opener_resolution_attempts','target_resolution_attempts')){foreach($attemptRow in @($facilityStepRow.$ledgerName)){$resolutionLedgers.Add($attemptRow)}}}
                foreach($attemptRow in @($resolutionLedgers)){foreach($pathField in @('viewport_request_path','viewport_raw_path','tree_request_path','tree_raw_path','node_request_path','node_raw_path','scroll_request_path','scroll_raw_path')){$candidateEvidencePath=[string]$attemptRow.$pathField;if(-not[string]::IsNullOrWhiteSpace($candidateEvidencePath)){$scenarioRequiredPaths+=$candidateEvidencePath}}}
                if([bool]$missionChoice.surface.expand_performed){$scenarioRequiredPaths+=@($surfaceExpandRequestPath,$surfaceExpandRawPath)}
                foreach($requiredPath in $scenarioRequiredPaths){if(-not(Test-Path -LiteralPath $requiredPath -PathType Leaf)){throw "Formal combat scenario evidence missing: $requiredPath"}}
                $combatScenarioWitness=[pscustomobject][ordered]@{schema='SpaceSyndicateFormalCombatScenarioWitnessV1';run_id=$RunId;status='PASS';deterministic_match_seed=$deterministicMatchSeed;seed_input_path=$seedInputPath;seed_input_value=$seedInputValue;seed_request_path=[IO.Path]::GetFullPath($seedRequestPath);seed_request_sha256=Get-Pr90ProbeBSha256 $seedRequestPath;seed_raw_path=[IO.Path]::GetFullPath($seedRawPath);seed_raw_sha256=Get-Pr90ProbeBSha256 $seedRawPath;baseline_request_path=[IO.Path]::GetFullPath($baselineRequestPath);baseline_request_sha256=Get-Pr90ProbeBSha256 $baselineRequestPath;baseline_raw_path=[IO.Path]::GetFullPath($baselineRawPath);baseline_raw_sha256=Get-Pr90ProbeBSha256 $baselineRawPath;initial_public_military_hand_candidate_count=[int]$combatTrackAcquisition.initial_public_military_hand_candidate_count;pre_acquire_hand_request_path=[string]$combatTrackAcquisition.pre_acquire_hand_request_path;pre_acquire_hand_request_sha256=[string]$combatTrackAcquisition.pre_acquire_hand_request_sha256;pre_acquire_hand_raw_path=[string]$combatTrackAcquisition.pre_acquire_hand_raw_path;pre_acquire_hand_raw_sha256=[string]$combatTrackAcquisition.pre_acquire_hand_raw_sha256;acquired_card_domain=[string]$combatTrackAcquisition.card_domain;acquired_card_node_path=[string]$combatTrackAcquisition.card_node_path;acquired_card_ui_text=[string]$combatTrackAcquisition.card_ui_text;acquired_card_definition_id=[string]$combatTrackAcquisition.private_definition_id;acquired_card_instance_id=[string]$combatTrackAcquisition.private_instance_id;acquired_card_origin_class=[string]$combatTrackAcquisition.private_origin_class;acquired_card_primary_color=[string]$combatTrackAcquisition.private_primary_color;acquired_card_primary_asset_cost=[int]$combatTrackAcquisition.private_primary_asset_cost;track_acquired_before=[int]$combatTrackAcquisition.track_acquired_before;track_acquired_after=[int]$combatTrackAcquisition.track_acquired_after;track_acquired_delta=[int]$combatTrackAcquisition.track_acquired_delta;track_visible_card_delta=[int]$combatTrackAcquisition.track_visible_card_delta;track_real_card_delta=[int]$combatTrackAcquisition.track_real_card_delta;track_vacancy_delta=[int]$combatTrackAcquisition.track_vacancy_delta;track_request_path=[string]$combatTrackAcquisition.track_request_path;track_request_sha256=[string]$combatTrackAcquisition.track_request_sha256;track_raw_path=[string]$combatTrackAcquisition.track_raw_path;track_raw_sha256=[string]$combatTrackAcquisition.track_raw_sha256;track_payload_request_path=[string]$combatTrackAcquisition.track_payload_request_path;track_payload_request_sha256=[string]$combatTrackAcquisition.track_payload_request_sha256;track_payload_raw_path=[string]$combatTrackAcquisition.track_payload_raw_path;track_payload_raw_sha256=[string]$combatTrackAcquisition.track_payload_raw_sha256;acquire_request_path=[string]$combatTrackAcquisition.request_path;acquire_request_sha256=[string]$combatTrackAcquisition.request_sha256;acquire_raw_path=[string]$combatTrackAcquisition.raw_path;acquire_raw_sha256=[string]$combatTrackAcquisition.raw_sha256;acquire_acceptance_request_path=[string]$combatTrackAcquisition.acceptance_request_path;acquire_acceptance_request_sha256=[string]$combatTrackAcquisition.acceptance_request_sha256;acquire_acceptance_raw_path=[string]$combatTrackAcquisition.acceptance_raw_path;acquire_acceptance_raw_sha256=[string]$combatTrackAcquisition.acceptance_raw_sha256;facility_advance_steps=@($facilityAdvanceSteps);facility_batch_transitions=@($facilityBatchTransitions);staged_card_domain='military';staged_card_node_path=[string]$militaryCard.path;staged_card_ui_text=[string]$militaryCard.ui_text;staged_card_definition_id=[string]$militaryCard.private_definition_id;staged_card_instance_id=[string]$militaryCard.private_instance_id;staged_card_origin_class=[string]$militaryCard.private_origin_class;staged_card_primary_color=[string]$militaryCard.private_primary_color;staged_card_primary_asset_cost=[int]$militaryCard.private_primary_asset_cost;mission_kind=[string]$missionChoice.mission_kind;mission_button_path=[string]$missionChoice.path;mission_button_text=[string]$missionChoice.text;military_intent_before=$militaryIntentBefore;military_intent_after=$militaryIntentAfter;military_intent_delta=($militaryIntentAfter-$militaryIntentBefore);hand_request_path=[IO.Path]::GetFullPath($handRequestPath);hand_request_sha256=Get-Pr90ProbeBSha256 $handRequestPath;hand_raw_path=[IO.Path]::GetFullPath($handRawPath);hand_raw_sha256=Get-Pr90ProbeBSha256 $handRawPath;hand_payload_request_path=[IO.Path]::GetFullPath($handPayloadRequestPath);hand_payload_request_sha256=Get-Pr90ProbeBSha256 $handPayloadRequestPath;hand_payload_raw_path=[IO.Path]::GetFullPath($handPayloadRawPath);hand_payload_raw_sha256=Get-Pr90ProbeBSha256 $handPayloadRawPath;mission_query_request_path=[IO.Path]::GetFullPath($missionQueryRequestPath);mission_query_request_sha256=Get-Pr90ProbeBSha256 $missionQueryRequestPath;mission_query_raw_path=[IO.Path]::GetFullPath($missionQueryRawPath);mission_query_raw_sha256=Get-Pr90ProbeBSha256 $missionQueryRawPath;mission_request_path=[IO.Path]::GetFullPath($missionRequestPath);mission_request_sha256=Get-Pr90ProbeBSha256 $missionRequestPath;mission_raw_path=[IO.Path]::GetFullPath($missionRawPath);mission_raw_sha256=Get-Pr90ProbeBSha256 $missionRawPath;acceptance_request_path=[IO.Path]::GetFullPath($acceptanceRequestPath);acceptance_request_sha256=Get-Pr90ProbeBSha256 $acceptanceRequestPath;acceptance_raw_path=[IO.Path]::GetFullPath($acceptanceRawPath);acceptance_raw_sha256=Get-Pr90ProbeBSha256 $acceptanceRawPath;canonical_payload_sha256=''}
                $combatScenarioWitness|Add-Member -NotePropertyName facility_advance_action_count -NotePropertyValue $facilityAdvanceActionCount
                $combatScenarioWitness|Add-Member -NotePropertyName card_selected_before -NotePropertyValue $cardSelectedBefore
                $combatScenarioWitness|Add-Member -NotePropertyName card_selected_after -NotePropertyValue $cardSelectedAfter
                $combatScenarioWitness|Add-Member -NotePropertyName card_selected_delta -NotePropertyValue ($cardSelectedAfter-$cardSelectedBefore)
                $combatScenarioWitness|Add-Member -NotePropertyName hand_viewport_request_path -NotePropertyValue ([IO.Path]::GetFullPath($handViewportRequestPath))
                $combatScenarioWitness|Add-Member -NotePropertyName hand_viewport_request_sha256 -NotePropertyValue (Get-Pr90ProbeBSha256 $handViewportRequestPath)
                $combatScenarioWitness|Add-Member -NotePropertyName hand_viewport_raw_path -NotePropertyValue ([IO.Path]::GetFullPath($handViewportRawPath))
                $combatScenarioWitness|Add-Member -NotePropertyName hand_viewport_raw_sha256 -NotePropertyValue (Get-Pr90ProbeBSha256 $handViewportRawPath)
                $combatScenarioWitness|Add-Member -NotePropertyName hand_resolution_attempts -NotePropertyValue @($militaryCard.resolution_attempts)
                $combatScenarioWitness|Add-Member -NotePropertyName hand_transient_not_found_count -NotePropertyValue ([int]$militaryCard.transient_not_found_count)
                $combatScenarioWitness|Add-Member -NotePropertyName hand_scroll_count -NotePropertyValue ([int]$militaryCard.scroll_count)
                $combatScenarioWitness|Add-Member -NotePropertyName track_viewport_request_path -NotePropertyValue ([string]$combatTrackAcquisition.track_viewport_request_path)
                $combatScenarioWitness|Add-Member -NotePropertyName track_viewport_request_sha256 -NotePropertyValue ([string]$combatTrackAcquisition.track_viewport_request_sha256)
                $combatScenarioWitness|Add-Member -NotePropertyName track_viewport_raw_path -NotePropertyValue ([string]$combatTrackAcquisition.track_viewport_raw_path)
                $combatScenarioWitness|Add-Member -NotePropertyName track_viewport_raw_sha256 -NotePropertyValue ([string]$combatTrackAcquisition.track_viewport_raw_sha256)
                $combatScenarioWitness|Add-Member -NotePropertyName combat_surface_path -NotePropertyValue ([string]$missionChoice.surface.path)
                $combatScenarioWitness|Add-Member -NotePropertyName combat_surface_initial_visible -NotePropertyValue ([bool]$missionChoice.surface.surface_before.properties.visible)
                $combatScenarioWitness|Add-Member -NotePropertyName combat_surface_final_visible -NotePropertyValue ([bool]$missionChoice.surface.surface_after.properties.visible)
                $combatScenarioWitness|Add-Member -NotePropertyName combat_surface_expand_performed -NotePropertyValue ([bool]$missionChoice.surface.expand_performed)
                $combatScenarioWitness|Add-Member -NotePropertyName mission_option_path -NotePropertyValue ([string]$missionChoice.option_path)
                $combatScenarioWitness|Add-Member -NotePropertyName mission_panel_path -NotePropertyValue ([string]$missionChoice.panel_path)
                $combatScenarioWitness|Add-Member -NotePropertyName mission_option_item_count -NotePropertyValue ([int]$missionChoice.option_item_count)
                $combatScenarioWitness|Add-Member -NotePropertyName mission_option_selected_before -NotePropertyValue ([int]$missionChoice.option_selected_before)
                $combatScenarioWitness|Add-Member -NotePropertyName mission_option_selected_after -NotePropertyValue ([int]$missionChoice.option_selected_after)
                foreach($evidenceField in @(
                    @('surface_initial_query_request',$surfaceInitialQueryRequestPath),@('surface_initial_query_raw',$surfaceInitialQueryRawPath),
                    @('surface_ready_query_request',$surfaceReadyQueryRequestPath),@('surface_ready_query_raw',$surfaceReadyQueryRawPath),
                    @('card_request',$cardRequestPath),@('card_raw',$cardRawPath),
                    @('card_acceptance_request',$cardAcceptanceRequestPath),@('card_acceptance_raw',$cardAcceptanceRawPath),
                    @('mission_panel_query_request',$missionPanelQueryRequestPath),@('mission_panel_query_raw',$missionPanelQueryRawPath),
                    @('mission_option_query_request',$missionOptionQueryRequestPath),@('mission_option_query_raw',$missionOptionQueryRawPath),
                    @('mission_option_request',$missionOptionRequestPath),@('mission_option_raw',$missionOptionRawPath),
                    @('mission_option_result_query_request',$missionOptionResultQueryRequestPath),@('mission_option_result_query_raw',$missionOptionResultQueryRawPath)
                )){
                    $combatScenarioWitness|Add-Member -NotePropertyName ($evidenceField[0]+'_path') -NotePropertyValue ([IO.Path]::GetFullPath([string]$evidenceField[1]))
                    $combatScenarioWitness|Add-Member -NotePropertyName ($evidenceField[0]+'_sha256') -NotePropertyValue (Get-Pr90ProbeBSha256 ([string]$evidenceField[1]))
                }
                if([bool]$missionChoice.surface.expand_performed){
                    $combatScenarioWitness|Add-Member -NotePropertyName surface_expand_request_path -NotePropertyValue ([IO.Path]::GetFullPath($surfaceExpandRequestPath))
                    $combatScenarioWitness|Add-Member -NotePropertyName surface_expand_request_sha256 -NotePropertyValue (Get-Pr90ProbeBSha256 $surfaceExpandRequestPath)
                    $combatScenarioWitness|Add-Member -NotePropertyName surface_expand_raw_path -NotePropertyValue ([IO.Path]::GetFullPath($surfaceExpandRawPath))
                    $combatScenarioWitness|Add-Member -NotePropertyName surface_expand_raw_sha256 -NotePropertyValue (Get-Pr90ProbeBSha256 $surfaceExpandRawPath)
                }
                $combatScenarioWitness|Add-Member -NotePropertyName acquired_card_asset_cost_profile -NotePropertyValue ([string]$combatTrackAcquisition.private_asset_cost_profile)
                $combatScenarioWitness|Add-Member -NotePropertyName acquired_card_track_revision -NotePropertyValue ([int]$combatTrackAcquisition.private_track_revision)
                $combatScenarioWitness|Add-Member -NotePropertyName acquired_card_claimable_from_scroll_sequence -NotePropertyValue ([int]$combatTrackAcquisition.private_claimable_from_scroll_sequence)
                $combatScenarioWitness|Add-Member -NotePropertyName staged_card_asset_cost_profile -NotePropertyValue ([string]$militaryCard.private_asset_cost_profile)
                $combatScenarioWitness|Add-Member -NotePropertyName staged_card_level -NotePropertyValue ([int]$militaryCard.private_level)
                $combatScenarioWitness|Add-Member -NotePropertyName staged_card_starter_badge -NotePropertyValue ([bool]$militaryCard.private_starter_badge)
                $combatScenarioWitness|Add-Member -NotePropertyName card_definition_registry_sha256 -NotePropertyValue ([string]$combatTrackAcquisition.card_definition_registry_sha256)
                $combatScenarioWitness.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $combatScenarioWitness
                $combatScenarioWitnessPath=Join-Path $EvidenceRoot 'phases/004-formal-combat-scenario-witness.json';Write-StartupImmutableJson -Path $combatScenarioWitnessPath -Value $combatScenarioWitness -WriteSha256Sidecar|Out-Null
                $combatScenarioWitnessSha=Get-Pr90ProbeBSha256 $combatScenarioWitnessPath;$acceptance=$missionAcceptance
            }
            if($null-eq$combatScenarioWitness){
                for($actionSlot=0;$actionSlot-lt5;$actionSlot+=1){
                    $facilityCard=Find-FormalHandCard -Domain 'facility'
                    if($null-eq$facilityCard){break}
                    $beforeSelected=[int]$acceptance.interaction_counts.card_selected;$beforeTarget=[int]$acceptance.interaction_counts.target_bound;$beforeQueue=[int]$acceptance.queue_count;$beforeInvalid=[int]$acceptance.invalid_action_count
                    $facilityCardTapCallIndex=$script:callIndex+1;$null=Send-FormalTaps @($facilityCard.center);$null=Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=200} -TimeoutSeconds 30
                    $targetRailOpen=Get-FormalFirstChoiceButton -Path 'V075GameScreen/RootMargin/Shell/TargetPanel/TargetMargin/TargetRow/TargetScroll/TargetRail' -RequiredTextPattern '^目标列表 · \d+$' -RequireUniqueMatch
                    if($null-eq$targetRailOpen-or[string]$targetRailOpen.text-cnotlike'目标列表 · *'){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: facility target list opener is unavailable'}
                    $targetRailOpenTapCallIndex=$script:callIndex+1;$null=Send-FormalTaps @($targetRailOpen.center);$null=Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=200} -TimeoutSeconds 30
                    $facilityTarget=Get-FormalFirstChoiceButton -Path 'V075GameScreen/PlaytestUtilityLayer/PlaytestSafeArea/V074TargetRailFloat/V074VirtualizedTargetRail/RailRows/Body/TargetScroll/VirtualContent/Rows' -RequiredNamePattern '^VirtualTargetRow\d{2}$'
                    if($null-eq$facilityTarget){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: virtualized facility target rail has no legal enabled binding'}
                    $facilityTargetTapCallIndex=$script:callIndex+1;$null=Send-FormalTaps @($facilityTarget.center);$null=Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=250} -TimeoutSeconds 30
                    $facilityAcceptanceCallIndex=$script:callIndex+1;$acceptance=Get-FormalProperty -Path 'V075GameScreen' -Name 'acceptance_state'
                    if([int]$acceptance.interaction_counts.card_selected-ne($beforeSelected+1)-or[int]$acceptance.interaction_counts.target_bound-ne($beforeTarget+1)-or[int]$acceptance.queue_count-ne($beforeQueue+1)-or[int]$acceptance.invalid_action_count-ne$beforeInvalid){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: deterministic facility hand-advance action was not legally queued'}
                    $facilityAdvanceActionCount+=1
                    $facilityStep=[ordered]@{step_index=$facilityAdvanceActionCount;batch_index=$batch;action_slot=$actionSlot;card_node_path=[string]$facilityCard.path;card_ui_text=[string]$facilityCard.ui_text;target_opener_path=[string]$targetRailOpen.path;target_opener_text=[string]$targetRailOpen.text;target_node_path=[string]$facilityTarget.path;target_ui_text=[string]$facilityTarget.text;facility_hand_resolution_attempts=@($facilityCard.resolution_attempts);target_opener_resolution_attempts=@($targetRailOpen.resolution_attempts);target_resolution_attempts=@($facilityTarget.resolution_attempts);facility_hand_transient_not_found_count=[int]$facilityCard.transient_not_found_count;target_opener_transient_not_found_count=[int]$targetRailOpen.transient_not_found_count;target_transient_not_found_count=[int]$facilityTarget.transient_not_found_count;card_selected_before=$beforeSelected;card_selected_after=[int]$acceptance.interaction_counts.card_selected;target_bound_before=$beforeTarget;target_bound_after=[int]$acceptance.interaction_counts.target_bound;queue_before=$beforeQueue;queue_after=[int]$acceptance.queue_count;invalid_action_before=$beforeInvalid;invalid_action_after=[int]$acceptance.invalid_action_count}
                    foreach($evidenceSpec in @(
                        @('facility_hand_viewport_query',[int]$facilityCard.viewport_query_call_index,'query_runtime_node'),@('facility_hand_query',[int]$facilityCard.query_call_index,'query_runtime_node'),@('facility_hand_node_query',[int]$facilityCard.node_query_call_index,'query_runtime_node'),@('facility_card',[int]$facilityCardTapCallIndex,'send_runtime_input'),
                        @('target_opener_viewport_query',[int]$targetRailOpen.viewport_query_call_index,'query_runtime_node'),@('target_opener_tree_query',[int]$targetRailOpen.tree_query_call_index,'query_runtime_node'),@('target_opener_node_query',[int]$targetRailOpen.node_query_call_index,'query_runtime_node'),@('target_opener',[int]$targetRailOpenTapCallIndex,'send_runtime_input'),
                        @('target_viewport_query',[int]$facilityTarget.viewport_query_call_index,'query_runtime_node'),@('target_tree_query',[int]$facilityTarget.tree_query_call_index,'query_runtime_node'),@('target_node_query',[int]$facilityTarget.node_query_call_index,'query_runtime_node'),@('target',[int]$facilityTargetTapCallIndex,'send_runtime_input'),
                        @('acceptance',[int]$facilityAcceptanceCallIndex,'query_runtime_node')
                    )){
                        $record=Get-FormalMcpEvidenceRecord -CallIndex ([int]$evidenceSpec[1]) -ToolName ([string]$evidenceSpec[2]);$prefix=[string]$evidenceSpec[0]
                        $facilityStep[$prefix+'_request_path']=[string]$record.request_path;$facilityStep[$prefix+'_request_sha256']=[string]$record.request_sha256;$facilityStep[$prefix+'_raw_path']=[string]$record.raw_path;$facilityStep[$prefix+'_raw_sha256']=[string]$record.raw_sha256
                    }
                    $facilityAdvanceSteps.Add([pscustomobject]$facilityStep)
                }
            }
        }
        $lockViewport=Move-FormalRootViewportToNode -TargetPath 'V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/CommandRow/LockButton';$null=Send-FormalTaps @($lockViewport.center)
        $null=Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=120} -TimeoutSeconds 30
        $finishViewport=Move-FormalRootViewportToNode -TargetPath 'V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/CommandRow/FinishMaintenanceButton';$null=Send-FormalTaps @($finishViewport.center)
        $null = Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=300} -TimeoutSeconds 30
        $postBatchAcceptanceCallIndex=$script:callIndex+1;$acceptance = Get-FormalProperty -Path 'V075GameScreen' -Name 'acceptance_state'
        if($null-ne$combatTrackAcquisition-and$null-eq$combatScenarioWitness-and$batch-lt2-and$facilityAdvanceActionCount-eq(($batch+1)*5)){
            if([int]$acceptance.interaction_counts.card_selected-ne$facilityAdvanceActionCount-or[int]$acceptance.interaction_counts.target_bound-ne$facilityAdvanceActionCount-or[int]$acceptance.queue_count-ne0-or[int]$acceptance.invalid_action_count-ne0){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: new-batch acceptance did not preserve cumulative interaction counts while resetting the queued action count'}
            $batchTransitionEvidence=Get-FormalMcpEvidenceRecord -CallIndex $postBatchAcceptanceCallIndex -ToolName query_runtime_node
            $facilityBatchTransitions.Add([pscustomobject][ordered]@{transition_index=$batch+1;prior_batch_index=$batch;next_batch_index=$batch+1;card_selected_count=[int]$acceptance.interaction_counts.card_selected;target_bound_count=[int]$acceptance.interaction_counts.target_bound;queue_count=[int]$acceptance.queue_count;invalid_action_count=[int]$acceptance.invalid_action_count;acceptance_request_path=[string]$batchTransitionEvidence.request_path;acceptance_request_sha256=[string]$batchTransitionEvidence.request_sha256;acceptance_raw_path=[string]$batchTransitionEvidence.raw_path;acceptance_raw_sha256=[string]$batchTransitionEvidence.raw_sha256})
        }
        $phase = if($batch -lt 4){'phase-3-early-match'}elseif($batch -lt 8){'phase-4-mid-match'}elseif($batch -lt 12){'phase-5-combat-facility'}elseif($batch -lt 16){'phase-6-victory'}else{'phase-7-settlement'}
        Poll-FormalCursor -Phase "$phase-batch-$batch" | Out-Null
        if ([bool]$acceptance.match_completed -and [bool]$acceptance.settlement_visible) { $settled = $true; break }
    }
    if (-not $settled) { throw 'Formal v5 natural UI match did not settle within 32 batches.' }
    if($null-eq$combatScenarioWitness){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: the bounded five-action hand advance did not carry the purchased military card into a legal mission before settlement'}
    $debug = $acceptance.runtime_acceptance_debug; $presentation = $debug.combat_presentation; $wrapper = $acceptance.combat_wrapper; $surface = $wrapper.surface
    $requiredEdges = [int]$wrapper.presentation_shared_consumer_count + [int]$wrapper.presentation_signal_connection_count + [int]$wrapper.presentation_source_bind_count
    $legacyEdges = [int]$wrapper.presentation_local_preview_consumer_count
    $duplicateEdges = [Math]::Max(0,[int]$wrapper.presentation_signal_connection_count-1) + [Math]::Max(0,[int]$wrapper.presentation_source_bind_count-1)
    $combatGate=Get-Pr90FormalCombatPresentationGateV1 -BeforeAcceptance $combatBaseline -AfterAcceptance $acceptance -ScenarioWitness $combatScenarioWitness
    if([string]$combatGate.classification-ceq'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED'){throw 'SCENARIO_COMBAT_PRECONDITION_NOT_REACHED: no nonempty combat source receipt followed the witnessed UI action'}
    if(-not[bool]$combatGate.green){throw "PRODUCT_PRESENTATION_CHAIN_FAILURE: $($combatGate.classification)"}
    $green = [bool]$acceptance.match_completed -and [bool]$acceptance.settlement_visible -and [int]$debug.final_settlement_count -eq 1 -and [int]$debug.duplicate_settlement_count -eq 0 -and $requiredEdges -eq 3 -and $legacyEdges -eq 0 -and $duplicateEdges -eq 0 -and [int]$debug.runtime_error_count -eq 0 -and [int]$debug.hidden_info_violation_count -eq 0 -and [int]$debug.invalid_action_count -eq 0 -and [int]$debug.nonfinite_count -eq 0
    if (-not $green) { throw 'Formal v5 production acceptance gate failed after the combat presentation chain passed.' }
    Poll-FormalCursor -Phase 'phase-7-final-settlement' | Out-Null
    if ($pollCount -le 8) { throw 'Formal v5 cursor polling count is insufficient.' }
    $formalPayload = [ordered]@{startup_milestones=12;startup_raw_count=@(Get-ChildItem -LiteralPath (Join-Path $EvidenceRoot 'mcp-raw') -File -ErrorAction SilentlyContinue).Count;startup_phase0_count=1;startup_stream_id=$startupStreamId;main_runtime_stream_id=$mainRuntimeStreamId;expected_stream_transition_count=1;unexpected_stream_transition_count=0;main_stream_id_stable=$true;main_stream_transition_path=$mainStreamTransitionPath;main_stream_transition_sha256=$mainStreamTransitionSha;ready_witness_count=@($readyWitnesses).Count;formal_event_poll_count=$pollCount;natural_match_reached_settled=$true;deterministic_match_seed=$deterministicMatchSeed;combat_scenario_witness_path=[IO.Path]::GetFullPath($combatScenarioWitnessPath);combat_scenario_witness_sha256=$combatScenarioWitnessSha;combat_source_receipt_count=[int]$combatGate.source_count;combat_presentation_receipt_count=[int]$combatGate.presentation_count;combat_map_cue_count=[int]$combatGate.map_cue_count;combat_surface_cue_count=[int]$combatGate.surface_cue_count;final_settlement_count=[int]$debug.final_settlement_count;presentation_receipt_count=[int]$presentation.applied_receipt_count;presentation_collision_count=[int]$presentation.collision_receipt_count;duplicate_presentation_effect_count=([int]$presentation.duplicate_receipt_count+[int]$surface.presentation_cue_duplicate_count);required_presentation_edge_count=$requiredEdges;legacy_presentation_edge_count=$legacyEdges;duplicate_presentation_edge_count=$duplicateEdges;runtime_error_count=[int]$debug.runtime_error_count;hidden_info_violation_count=[int]$debug.hidden_info_violation_count;invalid_action_count=[int]$debug.invalid_action_count;nonfinite_count=[int]$debug.nonfinite_count;duplicate_settlement_count=[int]$debug.duplicate_settlement_count}
} catch {
    $primaryFailure = $_
} finally {
    $stateStopPending=($null-ne$state.summary.PSObject.Properties['stop_pending']-and[bool]$state.summary.stop_pending)
    $stateStopsCleanly=($null-ne$state.summary.PSObject.Properties['stops_cleanly']-and[bool]$state.summary.stops_cleanly)
    $stateForcedStop=($null-ne$state.summary.PSObject.Properties['forced_stop']-and[bool]$state.summary.forced_stop)
    $exitPlayGreen=if($stateStopPending){$false}else{$true};$stopGreen=if($stateStopPending){$true}else{$stateStopsCleanly};$stopForced=$stateForcedStop;$stopExitCode=if($stopGreen){0}else{-1};$stopDetail=if($stateStopPending){'formal continuation pending'}else{'startup state-machine cleanup'};$watchdogStopped=$true
    $unrelatedTerminationCount=if($null-ne$state.summary.PSObject.Properties['unrelated_process_termination_count']){[int]$state.summary.unrelated_process_termination_count}else{0}
    $connectionMetadataPresent=Test-Path -LiteralPath (Join-Path $root '.codex-godot/connection.json') -PathType Leaf
    if($stateStopPending){
        if($connectionMetadataPresent){try{$null=Invoke-FormalMcp -ToolName 'exit_play_mode' -Arguments @{} -TimeoutSeconds 30;$exitPlayGreen=$true}catch{$exitPlayGreen=$false;$stopDetail="exit_play_mode: $($_.Exception.Message)"}}
        if([int]$state.godot_pid-gt0){
        try{
            $stopReceipt=Stop-StateGodot -ControlProcessId ([int]$state.godot_pid) -ProcessStartUtc ([string]$state.process_start_utc) -GodotPath $GodotPath -Worktree $root -Port $Port -StopScriptPath $StopScriptPath `
                -EndpointOwnerPid ([int]$state.endpoint_owner_pid) -EndpointOwnerCreationFiletimeUtc ([string]$state.endpoint_owner_creation_filetime_utc) -EndpointOwnerSessionId ([int]$state.endpoint_owner_session_id) -EndpointOwnerUserSid ([string]$state.endpoint_owner_user_sid)
            $stopExitCode=if([bool]$stopReceipt.stopped){0}else{2};$stopGreen=[bool]$stopReceipt.stopped;$stopForced=[bool]$stopReceipt.forced_stop;$stopDetail=ConvertTo-Pr90ProbeBCanonicalJson $stopReceipt
            $unrelatedTerminationCount+=[int]$stopReceipt.unrelated_process_termination_count
        }catch{$stopGreen=$false;$stopExitCode=2;$stopDetail="scoped_v2_stop: $($_.Exception.Message)"}
        }else{$stopGreen=$false;$stopExitCode=2;$stopDetail='scoped_v2_stop: formal continuation did not preserve a control process identity'}
    }
    if($null-ne$state-and[bool]$state.summary.stop_pending){$watchdogStopped=Stop-Pr90McpStartupWatchdog -State $state -TimeoutSeconds 15}
}

$productBeforeFinalizer=@(Get-Pr90ProductProcessRowsV1);$mcpBeforeFinalizer=@(Get-Pr90McpSupportProcessRowsV1);$listenersBeforeFinalizer=@(Get-Pr90ProtectedListenerRowsV1)
$preFinalizerZero=($productBeforeFinalizer.Count-eq0-and$mcpBeforeFinalizer.Count-eq0-and$listenersBeforeFinalizer.Count-eq0)
$finalizerExitCode=-1;$finalizerStatus='BLOCKED';$finalizerInvoked=$false;$finalizerReceiptGreen=$false;$finalizerDetail='cleanup_not_green'
if($exitPlayGreen-and$stopGreen-and-not$stopForced-and$watchdogStopped-and$preFinalizerZero){
    $finalizerInvoked=$true
    $finalizerOutput=@(& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File $ImportFinalizerBindingPath -Worktree $root -BaselinePath $SealedBaselinePath -ClassCachePath $ClassCachePath -GodotPath $GodotPath -ProductHeadSha $ExpectedHeadSha -ProductTreeSha $ExpectedTreeSha -ImportRunnerPath $ImportRunnerPath -ExpectedImportRunnerSha256 $ExpectedImportRunnerSha256 -PrelaunchIgnoredInventoryPath $prelaunchFull -ExpectedPrelaunchIgnoredInventorySha256 $prelaunchSha -OutputPath $finalizerFull 2>&1)
    $finalizerExitCode=$LASTEXITCODE
    if(Test-Path -LiteralPath $finalizerFull -PathType Leaf){
        try{
            $finalizerReceipt=Get-Content -Raw -LiteralPath $finalizerFull|ConvertFrom-Json -Depth 100;$finalizerStatus=[string]$finalizerReceipt.status;$finalizerDetail=[string]::Join(' | ',[string[]]$finalizerOutput)
            $rawFinalizerPath=[string]$finalizerReceipt.raw_state_path;$normalizedFinalizerPath=[string]$finalizerReceipt.normalized_state_path;$runnerFinalizerPath=[string]$finalizerReceipt.runner_result_path
            $finalizerReceiptGreen=([string]$finalizerReceipt.schema-ceq'Pr90ProbeBImportFinalizerBindingV1'-and$finalizerStatus-ceq'PASS'-and[string]$finalizerReceipt.product_head_sha-ceq$ExpectedHeadSha-and[string]$finalizerReceipt.product_tree_sha-ceq$ExpectedTreeSha-and
                [string]$finalizerReceipt.baseline_sha256-ceq$ExpectedSealedBaselineSha256-and[string]$finalizerReceipt.class_cache_sha256-ceq$ExpectedClassCacheSha256-and[bool]$finalizerReceipt.raw_state_green-and[bool]$finalizerReceipt.baseline_ignored_path_set_match-and
                [int]$finalizerReceipt.disallowed_ignored_count-eq0-and[bool]$finalizerReceipt.runner_invoked-and[int]$finalizerReceipt.runner_exit_code-eq0-and[int]$finalizerReceipt.post_run_non_generated_tracked_delta-eq0-and
                [int]$finalizerReceipt.post_run_tracked_import_metadata_delta_from_baseline-eq0-and[int]$finalizerReceipt.post_run_unknown_untracked_count-eq0-and[int]$finalizerReceipt.post_run_unknown_ignored_count-eq0-and-not[bool]$finalizerReceipt.deletion_performed-and
                [string]$finalizerReceipt.canonical_payload_sha256-ceq(Get-Pr90ProbeBCanonicalSha256 $finalizerReceipt)-and(Test-Path -LiteralPath $rawFinalizerPath -PathType Leaf)-and(Get-Pr90ProbeBSha256 $rawFinalizerPath)-ceq[string]$finalizerReceipt.raw_state_sha256-and
                (Test-Path -LiteralPath $normalizedFinalizerPath -PathType Leaf)-and(Get-Pr90ProbeBSha256 $normalizedFinalizerPath)-ceq[string]$finalizerReceipt.normalized_state_sha256-and(Test-Path -LiteralPath $runnerFinalizerPath -PathType Leaf)-and(Get-Pr90ProbeBSha256 $runnerFinalizerPath)-ceq[string]$finalizerReceipt.runner_result_sha256)
        }catch{$finalizerStatus='BLOCKED';$finalizerReceiptGreen=$false;$finalizerDetail=$_.Exception.Message}
    }else{$finalizerDetail="Finalizer produced no receipt: $([string]::Join(' | ',[string[]]$finalizerOutput))"}
}
if(-not(Test-Path -LiteralPath $finalizerFull)){
    $skipped=[pscustomobject][ordered]@{schema='Pr90FormalImportFinalizerNotRunV1';status='BLOCKED';created_at_utc=[DateTimeOffset]::UtcNow.ToString('o');authorized_run_id=$RunId;reason=$finalizerDetail;pre_finalizer_process_count=$productBeforeFinalizer.Count;pre_finalizer_mcp_process_count=$mcpBeforeFinalizer.Count;pre_finalizer_protected_listener_count=$listenersBeforeFinalizer.Count;canonical_payload_sha256=''}
    $skipped.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $skipped;Write-Pr90ProbeBImmutableJson -Path $finalizerFull -Value $skipped -WriteSha256Sidecar|Out-Null
}
$finalizerSha=Get-Pr90ProbeBSha256 $finalizerFull
$productAfter=@(Get-Pr90ProductProcessRowsV1);$mcpAfter=@(Get-Pr90McpSupportProcessRowsV1);$listenersAfter=@(Get-Pr90ProtectedListenerRowsV1)
$terminalGreen=($exitPlayGreen-and$stopGreen-and-not$stopForced-and$watchdogStopped-and$preFinalizerZero-and$finalizerInvoked-and$finalizerExitCode-eq0-and$finalizerReceiptGreen-and$productAfter.Count-eq0-and$mcpAfter.Count-eq0-and$listenersAfter.Count-eq0-and$unrelatedTerminationCount-eq0)
$terminal=[pscustomobject][ordered]@{schema='Pr90Attempt22FormalTerminalManifestV1';status=if($terminalGreen){'PASS'}else{'BLOCKED'};created_at_utc=[DateTimeOffset]::UtcNow.ToString('o');authorization_id=[string]$formalSeal.authorization_id;authorized_run_id=$RunId;formal_authorization_consumed=$formalAuthorizationConsumed;formal_mcp_execution_count=$formalMcpExecutionCount;authorized_run_count_consumed=$authorizedRunCountConsumed;connection_metadata_present_at_cleanup=$connectionMetadataPresent;exit_play_mode_clean=$exitPlayGreen;stop_script_exit_code=$stopExitCode;stop_script_green=$stopGreen;stop_script_forced=$stopForced;stop_detail=$stopDetail;watchdog_stopped=$watchdogStopped;product_process_count_before_finalizer=$productBeforeFinalizer.Count;mcp_process_count_before_finalizer=$mcpBeforeFinalizer.Count;protected_listener_count_before_finalizer=$listenersBeforeFinalizer.Count;finalizer_invoked=$finalizerInvoked;finalizer_exit_code=$finalizerExitCode;finalizer_status=$finalizerStatus;finalizer_receipt_green=$finalizerReceiptGreen;finalizer_sha256=$finalizerSha;product_process_count_after=$productAfter.Count;mcp_process_count_after=$mcpAfter.Count;port_7576_count_after=@($listenersAfter|Where-Object{[int]$_.local_port-eq7576}).Count;port_7586_count_after=@($listenersAfter|Where-Object{[int]$_.local_port-eq7586}).Count;unrelated_process_termination_count=$unrelatedTerminationCount;canonical_payload_sha256=''}
$terminal.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $terminal;Write-Pr90ProbeBImmutableJson -Path $terminalFull -Value $terminal -WriteSha256Sidecar|Out-Null
$terminalSha=Get-Pr90ProbeBSha256 $terminalFull
$finalGreen=($null-eq$primaryFailure-and$null-ne$formalPayload-and$formalAuthorizationConsumed-and$terminalGreen-and$finalizerExitCode-eq0-and$finalizerStatus-ceq'PASS')
if($finalGreen){
    $formalResult=[ordered]@{schema='SpaceSyndicateCursorAwareExactMcpResultV5';run_id=$RunId;status='PASS';head_sha=$ExpectedHeadSha;tree_sha=$ExpectedTreeSha;tooling_head_sha=$currentToolingHead;tooling_tree_sha=$currentToolingTree;authorization_seal_sha256=$formalAuthorizationSealSha;authorization_consumption_receipt_sha256=$consumptionSha;formal_authorization_consumed=$formalAuthorizationConsumed;formal_mcp_execution_count=$formalMcpExecutionCount;authorized_run_count_consumed=$authorizedRunCountConsumed;automatic_retry_allowed=$false;terminal_manifest_sha256=$terminalSha;terminal_status='PASS';finalizer_result_sha256=$finalizerSha;finalizer_status='PASS';canonical_payload_sha256=''}
    foreach($entry in $formalPayload.GetEnumerator()){$formalResult[$entry.Key]=$entry.Value}
    $formalResult.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $formalResult;Write-Pr90ProbeBImmutableJson -Path (Join-Path $EvidenceRoot 'exact-sha-mcp-result.json') -Value $formalResult -WriteSha256Sidecar|Out-Null
    $formalResult|ConvertTo-Json -Depth 100 -Compress
    exit 0
}
$failureMessage=if($null-eq$primaryFailure){'Formal cleanup, terminal, or finalizer contract failed.'}elseif($null-ne$primaryFailure.Exception){$primaryFailure.Exception.Message}else{[string]$primaryFailure}
$failure=[ordered]@{schema='SpaceSyndicateCursorAwareExactMcpFailureV5';run_id=$RunId;failed_at_utc=[DateTimeOffset]::UtcNow.ToString('o');message=$failureMessage;head_sha=$ExpectedHeadSha;tree_sha=$ExpectedTreeSha;cursor=$cursor;stream_id=$streamId;startup_state_machine_result=$state.summary;authorization_seal_sha256=$formalAuthorizationSealSha;authorization_consumption_receipt_sha256=$consumptionSha;formal_authorization_consumed=$formalAuthorizationConsumed;formal_mcp_execution_count=$formalMcpExecutionCount;authorized_run_count_consumed=$authorizedRunCountConsumed;automatic_retry_allowed=$false;terminal_manifest_sha256=$terminalSha;terminal_status=[string]$terminal.status;finalizer_result_sha256=$finalizerSha;finalizer_status=$finalizerStatus;disposable_clone_disposition='PRESERVED_FOR_FORENSICS';canonical_payload_sha256=''}
$failure.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $failure;Write-Pr90ProbeBImmutableJson -Path (Join-Path $EvidenceRoot 'exact-sha-mcp-failure.json') -Value $failure -WriteSha256Sidecar|Out-Null
$failure|ConvertTo-Json -Depth 100 -Compress
exit 2
