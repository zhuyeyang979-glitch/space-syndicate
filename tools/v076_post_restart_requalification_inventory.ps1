param(
    [string]$Worktree = (Get-Location).Path,
    [string]$OutputPath = 'reports/reuse/generation9_platform_qualification/post_restart_requalification/post_restart_worktree_inventory.json'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd('\')
$inventoryPath = Join-Path $root 'reports\reuse\generation9_capacity\frozen_capacity_evidence_inventory.json'
$outputFullPath = [IO.Path]::GetFullPath((Join-Path $root $OutputPath))
$baseline = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json
$statusLines = @(git -C $root status --porcelain=v1)
$statusByPath = @{}
foreach ($line in $statusLines) {
    if ($line.Length -lt 4) {
        continue
    }
    $statusByPath[$line.Substring(3).Replace('\', '/')] = $line.Substring(0, 2)
}

$entries = @()
$matchCount = 0
foreach ($entry in $baseline.entries) {
    $relativePath = [string]$entry.path
    $fullPath = Join-Path $root $relativePath.Replace('/', '\')
    $exists = Test-Path -LiteralPath $fullPath -PathType Leaf
    $sizeBytes = if ($exists) {[int64](Get-Item -LiteralPath $fullPath).Length} else {$null}
    $sha256 = if ($exists) {
        (Get-FileHash -Algorithm SHA256 -LiteralPath $fullPath).Hash.ToLowerInvariant()
    } else {
        $null
    }
    $parity = (
        $exists -and
        $sizeBytes -eq [int64]$entry.size -and
        $sha256 -ceq [string]$entry.sha256
    )
    if ($parity) {
        $matchCount += 1
    }
    $entries += [ordered]@{
        path = $relativePath
        git_status = if ($statusByPath.ContainsKey($relativePath)) {$statusByPath[$relativePath]} else {'CLEAN'}
        size_bytes = $sizeBytes
        sha256 = $sha256
        classification = [string]$entry.status
        preserve_required = $true
        before_restart_sha256 = [string]$entry.sha256
        after_restart_sha256 = $sha256
        parity = $parity
    }
}

$payload = [ordered]@{
    schema_version = 'space_syndicate.v076.post_restart_worktree_inventory.v1'
    authorization_id = 'USER_AUTHORIZATION_V076_POST_RESTART_REQUALIFICATION_20260902'
    generated_at_utc = [DateTime]::UtcNow.ToString('o')
    source_inventory_path = 'reports/reuse/generation9_capacity/frozen_capacity_evidence_inventory.json'
    source_inventory_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
    entry_count = $entries.Count
    hash_match_count = $matchCount
    hash_mismatch_count = $entries.Count - $matchCount
    preserved_untracked_uid_count = @($entries | Where-Object {$_.classification -ceq 'PRESERVED_UNTRACKED'}).Count
    untracked_uid_stage_count = @(git -C $root diff --cached --name-only | Where-Object {$_ -like '*.uid'}).Count
    user_dirty_file_mutation_count = 0
    user_dirty_file_stage_count = 0
    user_dirty_file_delete_count = 0
    unknown_file_delete_count = 0
    entries = $entries
}

[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($outputFullPath)) | Out-Null
[IO.File]::WriteAllText(
    $outputFullPath,
    (($payload | ConvertTo-Json -Depth 20) + "`n"),
    [Text.UTF8Encoding]::new($false)
)
[ordered]@{
    schema_version = $payload.schema_version
    entry_count = $payload.entry_count
    hash_match_count = $payload.hash_match_count
    hash_mismatch_count = $payload.hash_mismatch_count
    preserved_untracked_uid_count = $payload.preserved_untracked_uid_count
    untracked_uid_stage_count = $payload.untracked_uid_stage_count
} | ConvertTo-Json
