[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ConfigPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][string]$OutputShaPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt19_authority_contract.psm1') -Force
$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json -Depth 100
$root = (Resolve-Path -LiteralPath $config.tooling_worktree_path).Path
$head = (& git -C $root rev-parse HEAD).Trim()
$tree = (& git -C $root rev-parse 'HEAD^{tree}').Trim()
if ($LASTEXITCODE -ne 0 -or $head -cne [string]$config.tooling_head_sha -or $tree -cne [string]$config.tooling_tree_sha) { throw 'Tooling identity mismatch.' }
if (@(& git -C $root status --porcelain=v1).Count -ne 0) { throw 'Tooling worktree is not clean.' }
$files = [Collections.Generic.List[object]]::new()
foreach ($pathValue in @($config.authorized_tooling_paths)) {
    $path = (Resolve-Path -LiteralPath ([string]$pathValue)).Path
    if (-not (Test-PathWithinRoot -Path $path -Root $root)) { throw "Tooling file is outside tooling root: $path" }
    $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\','/')
    $files.Add([pscustomobject][ordered]@{
        relative_path = $relative
        path = $path
        byte_count = (Get-Item -LiteralPath $path).Length
        sha256 = Get-Sha256 $path
        git_blob_sha = (& git -C $root hash-object -- $relative).Trim()
    })
}
$files = @($files | Sort-Object relative_path)
$seal = [pscustomobject][ordered]@{
    schema = 'SpaceSyndicatePr90Attempt19ToolingSealV1'
    seal_id = 'pr90-attempt19-tooling-seal-001'
    status = 'SEALED'
    sealed_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    product_head_sha = [string]$config.product_head_sha
    product_tree_sha = [string]$config.product_tree_sha
    tooling_branch = [string]$config.tooling_branch
    tooling_head_sha = $head
    tooling_tree_sha = $tree
    tooling_worktree_path = $root
    import_runner_path = [IO.Path]::GetFullPath([string]$config.import_runner_path)
    import_runner_sha256 = Get-Sha256 $config.import_runner_path
    authorization_builder_sha256 = Get-Sha256 $config.authorization_builder_path
    authorization_validator_sha256 = Get-Sha256 $config.authorization_validator_path
    import_finalizer_sha256 = Get-Sha256 $config.import_finalizer_path
    tooling_selftest_manifest_path = [IO.Path]::GetFullPath([string]$config.selftest_manifest_path)
    tooling_selftest_manifest_sha256 = Get-Sha256 $config.selftest_manifest_path
    formal_dry_run_path = [IO.Path]::GetFullPath([string]$config.formal_dry_run_path)
    formal_dry_run_sha256 = Get-Sha256 $config.formal_dry_run_path
    canonical_formal_receipt_path = [IO.Path]::GetFullPath([string]$config.formal_receipt_path)
    canonical_formal_receipt_sha256 = Get-Sha256 $config.formal_receipt_path
    import_finalizer_dry_run_path = [IO.Path]::GetFullPath([string]$config.finalizer_dry_run_path)
    import_finalizer_dry_run_sha256 = Get-Sha256 $config.finalizer_dry_run_path
    sealed_baseline_sha256 = Get-Sha256 $config.sealed_baseline_path
    authorized_tooling_file_count = $files.Count
    authorized_tooling_files = $files
    product_code_change_count = 0
    test_oracle_change_count = 0
    formal_mcp_execution_count = 0
    canonical_payload_sha256 = ''
}
$seal.canonical_payload_sha256 = Get-CanonicalPayloadSha256 $seal
Write-ImmutableJson -Path $OutputPath -Value $seal
Write-ImmutableSha256Sidecar -Path $OutputShaPath -TargetPath $OutputPath
$seal | ConvertTo-Json -Depth 100 -Compress
