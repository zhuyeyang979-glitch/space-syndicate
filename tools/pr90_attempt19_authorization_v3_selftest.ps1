[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][string]$OutputShaPath,
    [Parameter(Mandatory = $true)][string]$FixtureRoot,
    [Parameter(Mandatory = $true)][string]$ProductHead,
    [Parameter(Mandatory = $true)][string]$ProductTree,
    [Parameter(Mandatory = $true)][string]$ToolingHead,
    [Parameter(Mandatory = $true)][string]$ToolingTree,
    [Parameter(Mandatory = $true)][string]$OldImportRunnerSha256
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt19_authority_contract.psm1') -Force
if (Test-Path -LiteralPath $FixtureRoot) { throw "Self-test fixture root must be new: $FixtureRoot" }
[IO.Directory]::CreateDirectory($FixtureRoot) | Out-Null

function Write-TestText([string]$Path, [string]$Text) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}
function Write-TestJson([string]$Path, [object]$Value) { Write-TestText $Path ($Value | ConvertTo-Json -Depth 100) }
function Write-TestSidecar([string]$ManifestPath, [string]$ShaPath) { Write-TestText $ShaPath "$(Get-Sha256 $ManifestPath)  $([IO.Path]::GetFileName($ManifestPath))`n" }

$runnerPath = Join-Path $FixtureRoot 'new-runner.ps1'; Write-TestText $runnerPath 'attempt19-new-runner'
$oldRunnerPath = Join-Path $FixtureRoot 'attempt18-manifest.json'
$plainPath = Join-Path $FixtureRoot 'plain.bin'; Write-TestText $plainPath 'fixture'
$cachePath = Join-Path $FixtureRoot 'global_script_class_cache.cfg'; Write-TestText $cachePath 'class-cache-fixture'
$pass1Path = Join-Path $FixtureRoot 'pass1.json'; Write-TestJson $pass1Path ([ordered]@{schema='pass1';exit_code=0})
$pass2Path = Join-Path $FixtureRoot 'pass2.json'; Write-TestJson $pass2Path ([ordered]@{schema='pass2';exit_code=0})
$baselinePath = Join-Path $FixtureRoot 'baseline.json'
$baseline = [pscustomobject][ordered]@{schema='SpaceSyndicatePostImportAuthorityBaselineV2';head_sha=$ProductHead;tree_sha=$ProductTree;godot_version='4.7.test';godot_sha256=(Get-Sha256 $plainPath);project_godot_sha256=(Get-Sha256 $plainPath);import_pass_1_manifest_sha256=(Get-Sha256 $pass1Path);import_pass_2_manifest_sha256=(Get-Sha256 $pass2Path);class_cache_sha256=(Get-Sha256 $cachePath);post_import_baseline_sealed=$true}
Write-TestJson $baselinePath $baseline
Write-TestJson $oldRunnerPath ([ordered]@{schema='SpaceSyndicatePr90CanonicalImportAuthorityAuthorizationV2';import_authority=[ordered]@{post_import_baseline=[ordered]@{sha256=(Get-Sha256 $baselinePath)}}})
$receiptPath = Join-Path $FixtureRoot 'receipt.json'
$receipt = [pscustomobject][ordered]@{schema='SpaceSyndicatePr90CanonicalFormalGateReceiptV1';status='PASS';head_sha=$ProductHead;tree_sha=$ProductTree;gate_count=79;pass_count=79;fail_count=0;duplicate_gate_count=0;missing_gate_count=0;gate_rows=@(1..79|ForEach-Object{[pscustomobject]@{gate_id=$_;status='PASS'}});canonical_payload_sha256=''}
$receipt.canonical_payload_sha256=Get-CanonicalPayloadSha256 $receipt
Write-TestJson $receiptPath $receipt
$selftestSeedPath = Join-Path $FixtureRoot 'selftest-seed.json';$selftestSeed=[pscustomobject][ordered]@{status='PASS';case_count=15;pass_count=15;missing_prerequisite_false_accept_count=0;stale_tooling_false_accept_count=0;canonical_payload_sha256=''};$selftestSeed.canonical_payload_sha256=Get-CanonicalPayloadSha256 $selftestSeed;Write-TestJson $selftestSeedPath $selftestSeed
$finalizerPath = Join-Path $FixtureRoot 'finalizer.json'
$finalizer = [pscustomobject][ordered]@{schema='SpaceSyndicatePr90ImportFinalizerDryRunV1';status='PASS';head_sha=$ProductHead;tree_sha=$ProductTree;product_head_sha=$ProductHead;product_tree_sha=$ProductTree;tooling_head_sha=$ToolingHead;tooling_tree_sha=$ToolingTree;import_runner_sha256=(Get-Sha256 $runnerPath);baseline_sha256=(Get-Sha256 $baselinePath);formal_mcp_count=0;product_game_count=0;unknown_file_delete_count=0;user_file_delete_count=0;outside_root_delete_count=0;forensics_preservation_green=$true;safe_discard_green=$true;canonical_payload_sha256=''}
$finalizer.canonical_payload_sha256=Get-CanonicalPayloadSha256 $finalizer
Write-TestJson $finalizerPath $finalizer
$sealPath = Join-Path $FixtureRoot 'tooling-seal.json'
$seal = [pscustomobject][ordered]@{schema='SpaceSyndicatePr90Attempt19ToolingSealV1';status='SEALED';product_head_sha=$ProductHead;product_tree_sha=$ProductTree;tooling_head_sha=$ToolingHead;tooling_tree_sha=$ToolingTree;import_runner_sha256=(Get-Sha256 $runnerPath);canonical_payload_sha256=''}
$seal.canonical_payload_sha256=Get-CanonicalPayloadSha256 $seal
Write-TestJson $sealPath $seal
$controllerReceiptPath = Join-Path $FixtureRoot 'import-controller-receipt.json'
$controllerReceipt = [pscustomobject][ordered]@{schema='SpaceSyndicatePr90Attempt19ImportControllerReceiptV3';status='PASS';product_head_sha=$ProductHead;product_tree_sha=$ProductTree;import_controller_sha256=(Get-Sha256 $plainPath);bound_import_engine_sha256=(Get-Sha256 $plainPath);sealed_baseline_sha256=(Get-Sha256 $baselinePath);import_pass1_manifest_sha256=(Get-Sha256 $pass1Path);import_pass2_manifest_sha256=(Get-Sha256 $pass2Path);warmup_log_sha256=(Get-Sha256 $plainPath);class_cache_sha256=(Get-Sha256 $cachePath);class_cache_byte_identical_to_attempt18=$true;canonical_payload_sha256=''}
$controllerReceipt.canonical_payload_sha256=Get-CanonicalPayloadSha256 $controllerReceipt
Write-TestJson $controllerReceiptPath $controllerReceipt

$toolRow = [pscustomobject][ordered]@{relative_path='tools/new-runner.ps1';path=$runnerPath;byte_count=(Get-Item $runnerPath).Length;sha256=(Get-Sha256 $runnerPath);git_blob_sha=('a'*40)}
$valid = [pscustomobject][ordered]@{
    authorization_schema_version='SpaceSyndicatePr90CanonicalImportAuthorityV3';authorization_id='selftest-valid';authorization_status='AUTHORIZED_FOR_ONE_EXACT_SHA_MCP_AFTER_PREREQUISITES';created_at_utc=[DateTimeOffset]::UtcNow.ToString('o');authorized_run_count=1;automatic_retry_allowed=$false;formal_run_id='selftest-run';formal_evidence_root=(Join-Path $FixtureRoot 'future-evidence')
    product_head_sha=$ProductHead;product_tree_sha=$ProductTree;import_tooling_branch='selftest';import_tooling_head_sha=$ToolingHead;import_tooling_tree_sha=$ToolingTree;import_tooling_worktree_path=$FixtureRoot
    import_runner_path=$runnerPath;import_runner_sha256=(Get-Sha256 $runnerPath);authorization_builder_path=$plainPath;authorization_builder_sha256=(Get-Sha256 $plainPath);authorization_validator_path=$plainPath;authorization_validator_sha256=(Get-Sha256 $plainPath);authorized_tooling_file_count=1;authorized_tooling_files=@($toolRow)
    sealed_baseline_path=$baselinePath;sealed_baseline_sha256=(Get-Sha256 $baselinePath);import_pass1_manifest_path=$pass1Path;import_pass1_manifest_sha256=(Get-Sha256 $pass1Path);import_pass2_manifest_path=$pass2Path;import_pass2_manifest_sha256=(Get-Sha256 $pass2Path);warmup_log_path=$plainPath;warmup_log_sha256=(Get-Sha256 $plainPath)
    class_cache_path=$cachePath;class_cache_sha256=(Get-Sha256 $cachePath);class_cache_bytes=(Get-Item $cachePath).Length;class_cache_product_head_sha=$ProductHead;class_cache_product_tree_sha=$ProductTree;class_cache_godot_version='4.7.test';class_cache_godot_executable_sha256=(Get-Sha256 $plainPath);class_cache_source_baseline_path=$baselinePath;class_cache_source_baseline_sha256=(Get-Sha256 $baselinePath)
    formal_gate_1_79_receipt_path=$receiptPath;formal_gate_1_79_receipt_sha256=(Get-Sha256 $receiptPath);formal_gate_1_79_receipt_schema_version='SpaceSyndicatePr90CanonicalFormalGateReceiptV1';formal_gate_1_79_receipt_head_sha=$ProductHead;formal_gate_1_79_receipt_tree_sha=$ProductTree;formal_gate_1_79_receipt_gate_count=79;formal_gate_1_79_receipt_pass_count=79;formal_gate_1_79_receipt_fail_count=0;formal_gate_1_79_receipt_duplicate_gate_count=0;formal_gate_1_79_receipt_missing_gate_count=0
    import_finalizer_dry_run_path=$finalizerPath;import_finalizer_dry_run_evidence_sha256=(Get-Sha256 $finalizerPath);import_finalizer_dry_run_schema_version='SpaceSyndicatePr90ImportFinalizerDryRunV1';import_finalizer_dry_run_product_head_sha=$ProductHead;import_finalizer_dry_run_product_tree_sha=$ProductTree;import_finalizer_dry_run_tooling_head_sha=$ToolingHead;import_finalizer_dry_run_tooling_tree_sha=$ToolingTree;import_finalizer_dry_run_import_runner_sha256=(Get-Sha256 $runnerPath);import_finalizer_dry_run_baseline_sha256=(Get-Sha256 $baselinePath);import_finalizer_dry_run_status='PASS'
    godot_path=$plainPath;godot_version='4.7.test';godot_executable_sha256=(Get-Sha256 $plainPath);project_godot_path=$plainPath;project_godot_sha256=(Get-Sha256 $plainPath);cursor_runbook_path=$plainPath;cursor_runbook_sha256=(Get-Sha256 $plainPath);import_controller_path=$plainPath;import_controller_sha256=(Get-Sha256 $plainPath);import_controller_receipt_path=$controllerReceiptPath;import_controller_receipt_sha256=(Get-Sha256 $controllerReceiptPath);bound_import_engine_path=$plainPath;bound_import_engine_sha256=(Get-Sha256 $plainPath);import_finalizer_path=$plainPath;import_finalizer_sha256=(Get-Sha256 $plainPath)
    selftest_manifest_path=$selftestSeedPath;selftest_manifest_sha256=(Get-Sha256 $selftestSeedPath);formal_dry_run_path=$plainPath;formal_dry_run_sha256=(Get-Sha256 $plainPath);tooling_seal_path=$sealPath;tooling_seal_sha256=(Get-Sha256 $sealPath);old_attempt18_manifest_path=$oldRunnerPath;old_attempt18_manifest_sha256=(Get-Sha256 $oldRunnerPath);old_import_runner_sha256=$OldImportRunnerSha256;formal_mcp_execution_count=0;authorized_run_count_consumed=0;conditional_next_stages=@();canonical_payload_sha256=''
}
$valid.canonical_payload_sha256 = Get-CanonicalPayloadSha256 $valid
$validPath=Join-Path $FixtureRoot 'valid.json';$validSha=Join-Path $FixtureRoot 'valid.json.sha256';Write-TestJson $validPath $valid;Write-TestSidecar $validPath $validSha
$validResult=Get-AuthorizationValidation -ManifestPath $validPath -ManifestShaPath $validSha -ExpectedProductHead $ProductHead -ExpectedProductTree $ProductTree -ExpectedToolingHead $ToolingHead -ExpectedToolingTree $ToolingTree
if([string]$validResult.status -cne 'PASS'){throw "Self-test valid control rejected: $($validResult.errors -join ',')"}

$cases=[Collections.Generic.List[object]]::new()
function Invoke-NegativeCase([string]$Name,[scriptblock]$Mutation,[ValidateSet('normal','stale-sidecar')][string]$Mode='normal'){
    $caseRoot=Join-Path $FixtureRoot $Name;[IO.Directory]::CreateDirectory($caseRoot)|Out-Null
    $candidate=Copy-JsonObject $valid
    & $Mutation $candidate $caseRoot
    if($candidate.PSObject.Properties.Name -contains 'canonical_payload_sha256'){$candidate.canonical_payload_sha256=Get-CanonicalPayloadSha256 $candidate}
    $path=Join-Path $caseRoot 'manifest.json';$sha=Join-Path $caseRoot 'manifest.json.sha256';Write-TestJson $path $candidate
    if($Mode -ceq 'stale-sidecar'){Write-TestText $sha "$('0'*64)  manifest.json`n"}else{Write-TestSidecar $path $sha}
    $result=Get-AuthorizationValidation -ManifestPath $path -ManifestShaPath $sha -ExpectedProductHead $ProductHead -ExpectedProductTree $ProductTree -ExpectedToolingHead $ToolingHead -ExpectedToolingTree $ToolingTree
    $cases.Add([pscustomobject][ordered]@{case=$Name;expected='REJECT';actual=[string]$result.status;pass=[string]$result.status -ceq 'BLOCKED';errors=@($result.errors)})
}
Invoke-NegativeCase 'missing_class_cache_sha256' {param($m,$r)$m.PSObject.Properties.Remove('class_cache_sha256')}
Invoke-NegativeCase 'wrong_class_cache_sha256' {param($m,$r)$m.class_cache_sha256=('f'*64)}
Invoke-NegativeCase 'other_head_class_cache' {param($m,$r)$m.class_cache_product_head_sha=('1'*40)}
Invoke-NegativeCase 'missing_formal_receipt' {param($m,$r)$m.PSObject.Properties.Remove('formal_gate_1_79_receipt_path')}
Invoke-NegativeCase 'formal_receipt_78_gates' {param($m,$r)$x=Copy-JsonObject $receipt;$x.gate_count=78;$x.pass_count=78;$x.gate_rows=@($x.gate_rows|Select-Object -First 78);$p=Join-Path $r 'receipt.json';Write-TestJson $p $x;$m.formal_gate_1_79_receipt_path=$p;$m.formal_gate_1_79_receipt_sha256=Get-Sha256 $p}
Invoke-NegativeCase 'formal_receipt_failed_gate' {param($m,$r)$x=Copy-JsonObject $receipt;$x.pass_count=78;$x.fail_count=1;$p=Join-Path $r 'receipt.json';Write-TestJson $p $x;$m.formal_gate_1_79_receipt_path=$p;$m.formal_gate_1_79_receipt_sha256=Get-Sha256 $p}
Invoke-NegativeCase 'formal_receipt_wrong_head' {param($m,$r)$x=Copy-JsonObject $receipt;$x.head_sha=('2'*40);$p=Join-Path $r 'receipt.json';Write-TestJson $p $x;$m.formal_gate_1_79_receipt_path=$p;$m.formal_gate_1_79_receipt_sha256=Get-Sha256 $p}
Invoke-NegativeCase 'missing_finalizer_dry_run' {param($m,$r)$m.PSObject.Properties.Remove('import_finalizer_dry_run_path')}
Invoke-NegativeCase 'finalizer_status_not_pass' {param($m,$r)$x=Copy-JsonObject $finalizer;$x.status='BLOCKED';$p=Join-Path $r 'finalizer.json';Write-TestJson $p $x;$m.import_finalizer_dry_run_path=$p;$m.import_finalizer_dry_run_evidence_sha256=Get-Sha256 $p}
Invoke-NegativeCase 'finalizer_wrong_tooling' {param($m,$r)$x=Copy-JsonObject $finalizer;$x.tooling_head_sha=('3'*40);$p=Join-Path $r 'finalizer.json';Write-TestJson $p $x;$m.import_finalizer_dry_run_path=$p;$m.import_finalizer_dry_run_evidence_sha256=Get-Sha256 $p}
Invoke-NegativeCase 'finalizer_wrong_baseline' {param($m,$r)$x=Copy-JsonObject $finalizer;$x.baseline_sha256=('4'*64);$p=Join-Path $r 'finalizer.json';Write-TestJson $p $x;$m.import_finalizer_dry_run_path=$p;$m.import_finalizer_dry_run_evidence_sha256=Get-Sha256 $p}
Invoke-NegativeCase 'attempt18_old_manifest' {param($m,$r)$m.authorization_schema_version='SpaceSyndicatePr90CanonicalImportAuthorityAuthorizationV2'}
Invoke-NegativeCase 'stale_old_import_runner' {param($m,$r)$m.import_runner_sha256=$m.old_import_runner_sha256}
Invoke-NegativeCase 'manifest_bytes_changed_stale_sha' {param($m,$r)$m.authorization_id='bytes-changed'} 'stale-sidecar'
Invoke-NegativeCase 'manifest_seal_inconsistent' {param($m,$r)$x=Copy-JsonObject $seal;$x.import_runner_sha256=('5'*64);$p=Join-Path $r 'seal.json';Write-TestJson $p $x;$m.tooling_seal_path=$p;$m.tooling_seal_sha256=Get-Sha256 $p}

$failed=@($cases|Where-Object{-not[bool]$_.pass})
$report=[pscustomobject][ordered]@{schema='SpaceSyndicatePr90AuthorizationV3SelfTestV1';status=if($failed.Count -eq 0){'PASS'}else{'BLOCKED'};created_at_utc=[DateTimeOffset]::UtcNow.ToString('o');product_head_sha=$ProductHead;product_tree_sha=$ProductTree;tooling_head_sha=$ToolingHead;tooling_tree_sha=$ToolingTree;valid_control_status=[string]$validResult.status;case_count=$cases.Count;pass_count=@($cases|Where-Object{[bool]$_.pass}).Count;missing_prerequisite_false_accept_count=@($cases|Where-Object{-not[bool]$_.pass -and $_.case -match 'missing|class_cache|receipt|finalizer'}).Count;stale_tooling_false_accept_count=@($cases|Where-Object{-not[bool]$_.pass -and $_.case -match 'stale|seal'}).Count;formal_mcp_count=0;product_process_count=0;cases=@($cases);canonical_payload_sha256=''}
$report.canonical_payload_sha256=Get-CanonicalPayloadSha256 $report
Write-ImmutableJson -Path $OutputPath -Value $report;Write-ImmutableSha256Sidecar -Path $OutputShaPath -TargetPath $OutputPath
$report|ConvertTo-Json -Depth 100 -Compress
if([string]$report.status -cne 'PASS'){exit 2}
