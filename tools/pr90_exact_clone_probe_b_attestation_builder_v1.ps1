[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProbeId,
    [Parameter(Mandatory = $true)][string]$ResultPath,
    [Parameter(Mandatory = $true)][string]$EvidenceRoot,
    [Parameter(Mandatory = $true)][string]$Probe004ResultPath,
    [Parameter(Mandatory = $true)][string]$ExpectedProbe004ResultSha256,
    [Parameter(Mandatory = $true)][string]$Probe004AttestationPath,
    [Parameter(Mandatory = $true)][string]$ExpectedProbe004AttestationSha256,
    [Parameter(Mandatory = $true)][string]$PostImportBaselinePath,
    [Parameter(Mandatory = $true)][string]$ClassCachePath,
    [Parameter(Mandatory = $true)][string]$SceneIsolationAuditPath,
    [Parameter(Mandatory = $true)][string]$ExpectedProbeSceneSha256,
    [Parameter(Mandatory = $true)][string]$FinalizerResultPath,
    [Parameter(Mandatory = $true)][string]$TerminalManifestPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_probe_b_attempt22_contract_v1.psm1') -Force
$result = Get-Content -Raw -LiteralPath $ResultPath | ConvertFrom-Json -Depth 100
$receiptPaths = @(Get-ChildItem -LiteralPath (Join-Path $EvidenceRoot 'milestones') -Filter '*.receipt.json' -File | Where-Object{$_.Name-match'^\d{2}-M(?:[0-9]|1[01])-.*\.receipt\.json$'} | Sort-Object Name | Select-Object -ExpandProperty FullName)
$receipts = Get-Pr90ProbeBFileInventoryV1 -Paths $receiptPaths
$rawPaths = @(Get-ChildItem -LiteralPath (Join-Path $EvidenceRoot 'mcp-raw') -Filter '*.json' -File | Sort-Object FullName | Select-Object -ExpandProperty FullName)
$raw = Get-Pr90ProbeBFileInventoryV1 -Paths $rawPaths
$requestPaths = @(Get-ChildItem -LiteralPath (Join-Path $EvidenceRoot 'requests') -Filter '*.json' -File | Sort-Object FullName | Select-Object -ExpandProperty FullName)
$requests = Get-Pr90ProbeBFileInventoryV1 -Paths $requestPaths
$bootstrap = Join-Path $EvidenceRoot 'witnesses/runtime-stream-bootstrap.json'
$bridgeReady = Join-Path $EvidenceRoot 'witnesses/runtime-bridge-ready-status.json'
$ready = Join-Path $EvidenceRoot 'witnesses/ready-witness.json'
$phase0 = Join-Path $EvidenceRoot 'phases/000-phase-0-ready.json'
$endpointAttestation = Join-Path $EvidenceRoot 'endpoint-ownership-v2-attestation.json'
$endpointSamples = Join-Path $EvidenceRoot 'endpoint-ownership-v2-samples.json'
$probe004Result=Get-Content -Raw -LiteralPath $Probe004ResultPath|ConvertFrom-Json -Depth 100
$probe004Attestation=Get-Content -Raw -LiteralPath $Probe004AttestationPath|ConvertFrom-Json -Depth 100
$sceneIsolation=Get-Content -Raw -LiteralPath $SceneIsolationAuditPath|ConvertFrom-Json -Depth 100
$sceneIsolationGreen=Test-Pr90ProbeBSceneIsolationContractV1 -Audit $sceneIsolation -ExpectedScenePath ([string]$result.authorized_probe_scene_path) -ExpectedSceneSha256 $ExpectedProbeSceneSha256
$probe004Bound=((Get-Pr90ProbeBSha256 $Probe004ResultPath)-ceq$ExpectedProbe004ResultSha256-and(Get-Pr90ProbeBSha256 $Probe004AttestationPath)-ceq$ExpectedProbe004AttestationSha256-and
    [string]$probe004Result.status-ceq'PASS'-and[string]$probe004Result.probe_id-ceq'pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-004'-and[string]$probe004Attestation.status-ceq'SEALED'-and
    [string]$probe004Attestation.probe_id-ceq'pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-004'-and[string]$probe004Attestation.result_sha256-ceq$ExpectedProbe004ResultSha256)
$allBound = ([string]$result.status -ceq 'PASS' -and $receipts.count -eq 12 -and[bool]$result.milestone_sequence_green-and[int]$result.milestone_duplicate_count-eq0-and $raw.count -gt 0 -and
    $requests.count-gt0-and[string]$result.request_inventory_sha256-ceq[string]$requests.inventory_sha256-and[int]$result.request_count-eq[int]$requests.count-and
    $probe004Bound-and$sceneIsolationGreen-and[string]$result.authorized_probe_scene_sha256-ceq$ExpectedProbeSceneSha256-and[string]$result.scene_isolation_audit_sha256-ceq(Get-Pr90ProbeBSha256 $SceneIsolationAuditPath)-and-not[string]::IsNullOrWhiteSpace([string]$result.godot_gui_sha256)-and-not[string]::IsNullOrWhiteSpace([string]$result.godot_console_sha256)-and
    (Test-Path -LiteralPath $endpointAttestation -PathType Leaf) -and (Test-Path -LiteralPath $endpointSamples -PathType Leaf) -and
    (Test-Path -LiteralPath $bridgeReady -PathType Leaf) -and (Test-Path -LiteralPath $bootstrap -PathType Leaf) -and (Test-Path -LiteralPath $ready -PathType Leaf) -and (Test-Path -LiteralPath $phase0 -PathType Leaf))
$attestation = [pscustomobject][ordered]@{
    schema='Pr90ExactCloneProbeBAttestationV1';probe_id=$ProbeId;status=if($allBound){'SEALED'}else{'BLOCKED'};created_at_utc=[DateTimeOffset]::UtcNow.ToString('o')
    result_path=[IO.Path]::GetFullPath($ResultPath);result_sha256=Get-Pr90ProbeBSha256 $ResultPath
    milestone_receipt_count=$receipts.count;milestone_receipt_inventory_sha256=$receipts.inventory_sha256;milestone_receipts=$receipts.rows
    probe004_result_sha256=Get-Pr90ProbeBSha256 $Probe004ResultPath;probe004_attestation_sha256=Get-Pr90ProbeBSha256 $Probe004AttestationPath
    godot_gui_sha256=[string]$result.godot_gui_sha256;godot_console_sha256=[string]$result.godot_console_sha256
    scene_isolation_audit_sha256=Get-Pr90ProbeBSha256 $SceneIsolationAuditPath;main_tscn_instance_count=[int]$sceneIsolation.main_tscn_instance_count
    post_import_baseline_sha256=Get-Pr90ProbeBSha256 $PostImportBaselinePath;class_cache_sha256=Get-Pr90ProbeBSha256 $ClassCachePath
    raw_mcp_evidence_count=$raw.count;raw_mcp_evidence_inventory_sha256=$raw.inventory_sha256;raw_mcp_evidence=$raw.rows
    request_count=$requests.count;request_inventory_sha256=$requests.inventory_sha256;request_inventory=$requests.rows
    endpoint_ownership_attestation_sha256=if(Test-Path -LiteralPath $endpointAttestation){Get-Pr90ProbeBSha256 $endpointAttestation}else{''}
    endpoint_ownership_samples_sha256=if(Test-Path -LiteralPath $endpointSamples){Get-Pr90ProbeBSha256 $endpointSamples}else{''}
    runtime_bridge_ready_status_sha256=if(Test-Path -LiteralPath $bridgeReady){Get-Pr90ProbeBSha256 $bridgeReady}else{''}
    runtime_bootstrap_sha256=if(Test-Path -LiteralPath $bootstrap){Get-Pr90ProbeBSha256 $bootstrap}else{''}
    ready_witness_sha256=if(Test-Path -LiteralPath $ready){Get-Pr90ProbeBSha256 $ready}else{''}
    phase0_sha256=if(Test-Path -LiteralPath $phase0){Get-Pr90ProbeBSha256 $phase0}else{''}
    finalizer_result_sha256=Get-Pr90ProbeBSha256 $FinalizerResultPath;terminal_manifest_sha256=Get-Pr90ProbeBSha256 $TerminalManifestPath
    unbound_evidence_count=if($allBound){0}else{1};formal_mcp_execution_count=0;authorized_run_count_consumed=0;canonical_payload_sha256=''
}
$attestation.canonical_payload_sha256 = Get-Pr90ProbeBCanonicalSha256 $attestation
Write-Pr90ProbeBImmutableJson -Path $OutputPath -Value $attestation -WriteSha256Sidecar | Out-Null
$attestation | ConvertTo-Json -Depth 100 -Compress
if (-not $allBound) { exit 2 }
