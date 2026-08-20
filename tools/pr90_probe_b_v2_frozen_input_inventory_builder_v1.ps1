[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$FrozenProbeRoot,
    [Parameter(Mandatory = $true)][string]$ExecutionConfigPath,
    [Parameter(Mandatory = $true)][string]$ExpectedExecutionConfigSha256,
    [int]$ExpectedInputCount = 241,
    [string]$ExpectedInputInventorySha256 = 'af5e309da4a512bbee1cdf3118e69ac243782715484757410702234f75d94f50',
    [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Resolve-Path -LiteralPath $FrozenProbeRoot).Path
$outputFull=[IO.Path]::GetFullPath($OutputPath)
$rootPrefix=$root.TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
if($outputFull-ceq$root-or$outputFull.StartsWith($rootPrefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Frozen input inventory output and sidecar must be external to the frozen Probe root.'}
if((Test-Path -LiteralPath $outputFull)-or(Test-Path -LiteralPath "$outputFull.sha256")){throw 'Frozen input inventory output must be new.'}
$toolingRoot=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$relativeBuilder='tools/pr90_probe_b_v2_frozen_input_inventory_builder_v1.ps1'
$relativeContract='tools/pr90_probe_b_attempt22_contract_v1.psm1'
$builderPath=[IO.Path]::GetFullPath((Join-Path $toolingRoot $relativeBuilder))
$contractPath=[IO.Path]::GetFullPath((Join-Path $toolingRoot $relativeContract))
if([IO.Path]::GetFullPath($PSCommandPath)-cne$builderPath){throw 'Frozen input inventory builder must execute from its Tooling worktree path.'}
$toolingHead=(& git -C $toolingRoot rev-parse HEAD).Trim();$toolingTree=(& git -C $toolingRoot rev-parse 'HEAD^{tree}').Trim()
if(@(& git -C $toolingRoot status --porcelain=v1 --untracked-files=all).Count-ne0){throw 'Frozen input inventory builder requires a clean Tooling worktree.'}
$builderBlob=(& git -C $toolingRoot rev-parse "HEAD:$relativeBuilder").Trim();$builderWorkBlob=(& git -C $toolingRoot hash-object -- $builderPath).Trim()
$contractBlob=(& git -C $toolingRoot rev-parse "HEAD:$relativeContract").Trim();$contractWorkBlob=(& git -C $toolingRoot hash-object -- $contractPath).Trim()
if($builderBlob-cne$builderWorkBlob-or$contractBlob-cne$contractWorkBlob){throw 'Frozen input inventory builder or contract bytes do not match the clean commit.'}
$builderSha=(Get-FileHash -LiteralPath $builderPath -Algorithm SHA256).Hash.ToLowerInvariant();$contractSha=(Get-FileHash -LiteralPath $contractPath -Algorithm SHA256).Hash.ToLowerInvariant()
Import-Module $contractPath -Force
if((Get-Pr90ProbeBSha256 $ExecutionConfigPath)-cne$ExpectedExecutionConfigSha256.ToLowerInvariant()){throw 'Frozen execution config hash mismatch.'}
$config=Get-Content -Raw -LiteralPath $ExecutionConfigPath|ConvertFrom-Json -Depth 100
if([string]$config.schema-cne'Pr90ExactCloneProbeBV2ExecutionConfigV1'-or[string]$config.probe_id-cne'pr90-exact-clone-startup-probe-b-v2-001'-or[IO.Path]::GetFullPath([string]$config.probe_root)-cne$root){throw 'Frozen execution config identity mismatch.'}
$sceneAuditPath=Join-Path $root 'preparation/probe-scene-isolation-audit.json'
$sceneAudit=Get-Content -Raw -LiteralPath $sceneAuditPath|ConvertFrom-Json -Depth 100
$paths=[Collections.Generic.List[string]]::new()
foreach($file in @(Get-ChildItem -LiteralPath $root -File)){$paths.Add($file.FullName)}
foreach($file in @(Get-ChildItem -LiteralPath (Join-Path $root 'preparation') -File -Recurse)){$paths.Add($file.FullName)}
foreach($file in @(Get-ChildItem -LiteralPath (Join-Path $root 'evidence') -File -Recurse|Where-Object{$_.FullName-notmatch'\\role-local-runtime-metadata\\'})){$paths.Add($file.FullName)}
$external=@(
    (Join-Path $root 'exact-product-clone/project.godot'),
    (Join-Path $root 'exact-product-clone/.godot/global_script_class_cache.cfg'),
    $ExecutionConfigPath,
    [string]$config.tooling_manifest_path,"$([string]$config.tooling_manifest_path).sha256",
    [string]$config.tooling_seal_path,"$([string]$config.tooling_seal_path).sha256",
    [string]$config.listener_forensics_path,
    [string]$config.probe004_result_path,"$([string]$config.probe004_result_path).sha256",
    [string]$config.probe004_attestation_path,"$([string]$config.probe004_attestation_path).sha256",
    [string]$config.godot_gui_path,[string]$config.godot_console_path
)+@($sceneAudit.resource_files.path)
foreach($path in $external){if(-not[string]::IsNullOrWhiteSpace([string]$path)-and(Test-Path -LiteralPath $path -PathType Leaf)){$paths.Add([string]$path)}else{throw "Frozen recovery input is missing: $path"}}
$inventory=Get-Pr90ProbeBFileInventoryV1 -Paths @($paths|Sort-Object -Unique)
$green=($inventory.count-eq$ExpectedInputCount-and[string]$inventory.inventory_sha256-ceq$ExpectedInputInventorySha256.ToLowerInvariant())
if(-not$green){throw "Frozen input inventory identity mismatch: count=$($inventory.count); sha=$($inventory.inventory_sha256)"}
$result=[pscustomobject][ordered]@{
    schema='Pr90ProbeBV2FrozenInputInventoryV1';status='FROZEN';created_at_utc=[DateTimeOffset]::UtcNow.ToString('o');probe_id=[string]$config.probe_id
    frozen_probe_root=$root;execution_config_path=[IO.Path]::GetFullPath($ExecutionConfigPath);execution_config_sha256=Get-Pr90ProbeBSha256 $ExecutionConfigPath
    tooling_head_sha=$toolingHead;tooling_tree_sha=$toolingTree;inventory_builder_sha256=$builderSha;contract_module_sha256=$contractSha
    input_count=$inventory.count;input_inventory_sha256=$inventory.inventory_sha256;inputs=$inventory.rows
    role_local_runtime_metadata_excluded=$true;frozen_probe_modification_count=0;probe_execution_count_delta=0;formal_mcp_execution_count=0;canonical_payload_sha256=''
}
$result.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $result
Write-Pr90ProbeBImmutableJson -Path $outputFull -Value $result -WriteSha256Sidecar|Out-Null
$result|ConvertTo-Json -Depth 100 -Compress
