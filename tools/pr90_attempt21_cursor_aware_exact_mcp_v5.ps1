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

function Get-FormalProperty {
    param([string]$Path, [string]$Name)
    return (Get-FormalNode -Path $Path -Properties @($Name)).requested_properties.$Name
}

function Get-FormalCenter {
    param([string]$Path)
    $node = Get-FormalNode -Path $Path -Properties @('disabled')
    return @{x=([double]$node.properties.global_position.x + [double]$node.properties.size.x / 2.0);y=([double]$node.properties.global_position.y + [double]$node.properties.size.y / 2.0)}
}

function Send-FormalTaps {
    param([hashtable[]]$Centers)
    $events = @($Centers | ForEach-Object { @{type='mouse_button';button='left';position=$_;mode='tap'} })
    $payload = Get-FormalStructured (Invoke-FormalMcp -ToolName 'send_runtime_input' -Arguments @{events=$events;timeout_msec=60000} -TimeoutSeconds 60)
    $commandId=[string]$payload.command_id
    if (-not [bool]$payload.success -or [string]$payload.command-cne'send_input' -or [string]::IsNullOrWhiteSpace($commandId) -or
        -not[bool]$payload.response.success -or [string]$payload.response.command-cne'send_input' -or [string]$payload.response.id-cne$commandId) { throw 'Formal runtime input failed or returned an unbound command identity.' }
    return $commandId
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
        if($lastObservationClass-in@('READINESS_IDENTITY_GREEN','AWAITING_EXPECTED_COMMAND_HEARTBEAT')-and-not$sampleGreen){$sawProductReadinessStall=$true}
        $requestPath=Join-Path $EvidenceRoot ('requests/{0:D4}-get_runtime_bridge_status.json' -f $statusCallIndex);$rawPath=Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-get_runtime_bridge_status.jsonrpc.json' -f $statusCallIndex)
        $attemptRows.Add([pscustomobject][ordered]@{call_index=$statusCallIndex;sample_green=$sampleGreen;observation_class=$lastObservationClass;effective_minimum_cursor=$effectiveMinimumCursor;state_modified_unix=if($null-ne$statusPayload){[long]$statusPayload.state_modified_unix}else{0};state_age_msec=if($null-ne$statusPayload){[long]$statusPayload.state_age_msec}else{-1};stream_id=if($null-ne$statusPayload){[string]$statusPayload.state.runtime_event_cursor.stream_id}else{''};cursor_after=if($null-ne$statusPayload){[int64]$statusPayload.state.runtime_event_cursor.buffered_last_event_sequence}else{0};last_command_id=if($null-ne$statusPayload){[string]$statusPayload.state.last_command_id}else{''};request_path=[IO.Path]::GetFullPath($requestPath);request_sha256=if(Test-Path -LiteralPath $requestPath -PathType Leaf){Get-Pr90ProbeBSha256 $requestPath}else{''};raw_path=[IO.Path]::GetFullPath($rawPath);raw_sha256=if(Test-Path -LiteralPath $rawPath -PathType Leaf){Get-Pr90ProbeBSha256 $rawPath}else{''};error=$errorText})
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
    $initial = Get-FormalProperty -Path 'V075GameScreen' -Name 'acceptance_state'
    $startCenter = Get-FormalCenter 'V075GameScreen/OverlayLayer/StartOverlay/Center/Panel/Margin/Rows/PlayerButtons/V074SettingsStack/StartConfiguredButton'
    $startInputCommandId=Send-FormalTaps @($startCenter)
    Wait-FormalPostInputBridgeReadiness -ExpectedCommandId $startInputCommandId -ExpectedStreamId $streamId -MinimumCursorAfter ($cursor+1) -MaximumWaitSeconds 60|Out-Null
    Poll-FormalCursor -Phase 'phase-2-new-game' -InnerTimeoutMsec 30000 -OuterTimeoutSeconds 60 | Out-Null
    $rootNode = Get-FormalNode -Path 'V075GameScreen/RootMargin' -Properties @()
    $scrollCenter = @{x=([double]$rootNode.properties.global_position.x + [double]$rootNode.properties.size.x / 2.0);y=([double]$rootNode.properties.global_position.y + [double]$rootNode.properties.size.y / 2.0)}
    $wheel = @(1..20 | ForEach-Object { @{type='mouse_button';button='wheel_down';position=$scrollCenter;mode='tap'} })
    $wheelPayload = Get-FormalStructured (Invoke-FormalMcp -ToolName 'send_runtime_input' -Arguments @{events=$wheel;timeout_msec=60000} -TimeoutSeconds 60)
    if (-not [bool]$wheelPayload.success) { throw 'Formal v5 scroll input failed.' }
    $lockCenter = Get-FormalCenter 'V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/CommandRow/LockButton'
    $finishCenter = Get-FormalCenter 'V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/CommandRow/FinishMaintenanceButton'
    Poll-FormalCursor -Phase 'phase-3-early-match' | Out-Null
    $settled = $false; $acceptance = $initial
    for ($batch=0; $batch -lt 32; $batch += 1) {
        $null=Send-FormalTaps @($lockCenter,$finishCenter)
        $null = Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=300} -TimeoutSeconds 30
        $acceptance = Get-FormalProperty -Path 'V075GameScreen' -Name 'acceptance_state'
        $phase = if($batch -lt 4){'phase-3-early-match'}elseif($batch -lt 8){'phase-4-mid-match'}elseif($batch -lt 12){'phase-5-combat-facility'}elseif($batch -lt 16){'phase-6-victory'}else{'phase-7-settlement'}
        Poll-FormalCursor -Phase "$phase-batch-$batch" | Out-Null
        if ([bool]$acceptance.match_completed -and [bool]$acceptance.settlement_visible) { $settled = $true; break }
    }
    if (-not $settled) { throw 'Formal v5 natural UI match did not settle within 32 batches.' }
    $debug = $acceptance.runtime_acceptance_debug; $presentation = $debug.combat_presentation; $wrapper = $acceptance.combat_wrapper; $surface = $wrapper.surface
    $requiredEdges = [int]$wrapper.presentation_shared_consumer_count + [int]$wrapper.presentation_signal_connection_count + [int]$wrapper.presentation_source_bind_count
    $legacyEdges = [int]$wrapper.presentation_local_preview_consumer_count
    $duplicateEdges = [Math]::Max(0,[int]$wrapper.presentation_signal_connection_count-1) + [Math]::Max(0,[int]$wrapper.presentation_source_bind_count-1)
    $green = [bool]$acceptance.match_completed -and [bool]$acceptance.settlement_visible -and [int]$debug.final_settlement_count -eq 1 -and [int]$debug.duplicate_settlement_count -eq 0 -and [int]$presentation.applied_receipt_count -gt 0 -and [int]$presentation.collision_receipt_count -eq 0 -and [int]$presentation.duplicate_receipt_count -eq 0 -and [int]$presentation.rejected_receipt_count -eq 0 -and $requiredEdges -eq 3 -and $legacyEdges -eq 0 -and $duplicateEdges -eq 0 -and [int]$debug.runtime_error_count -eq 0 -and [int]$debug.hidden_info_violation_count -eq 0 -and [int]$debug.invalid_action_count -eq 0 -and [int]$debug.nonfinite_count -eq 0 -and [int]$surface.presentation_cue_collision_count -eq 0 -and [int]$surface.presentation_cue_duplicate_count -eq 0
    if (-not $green) { throw 'Formal v5 production acceptance/presentation gate failed.' }
    Poll-FormalCursor -Phase 'phase-7-final-settlement' | Out-Null
    if ($pollCount -le 8) { throw 'Formal v5 cursor polling count is insufficient.' }
    $formalPayload = [ordered]@{startup_milestones=12;startup_raw_count=@(Get-ChildItem -LiteralPath (Join-Path $EvidenceRoot 'mcp-raw') -File -ErrorAction SilentlyContinue).Count;startup_phase0_count=1;startup_stream_id=$startupStreamId;main_runtime_stream_id=$mainRuntimeStreamId;expected_stream_transition_count=1;unexpected_stream_transition_count=0;main_stream_id_stable=$true;main_stream_transition_path=$mainStreamTransitionPath;main_stream_transition_sha256=$mainStreamTransitionSha;ready_witness_count=@($readyWitnesses).Count;formal_event_poll_count=$pollCount;natural_match_reached_settled=$true;final_settlement_count=[int]$debug.final_settlement_count;presentation_receipt_count=[int]$presentation.applied_receipt_count;presentation_collision_count=[int]$presentation.collision_receipt_count;duplicate_presentation_effect_count=([int]$presentation.duplicate_receipt_count+[int]$surface.presentation_cue_duplicate_count);required_presentation_edge_count=$requiredEdges;legacy_presentation_edge_count=$legacyEdges;duplicate_presentation_edge_count=$duplicateEdges;runtime_error_count=[int]$debug.runtime_error_count;hidden_info_violation_count=[int]$debug.hidden_info_violation_count;invalid_action_count=[int]$debug.invalid_action_count;nonfinite_count=[int]$debug.nonfinite_count;duplicate_settlement_count=[int]$debug.duplicate_settlement_count}
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
