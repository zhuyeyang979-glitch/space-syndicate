# V0.7.5 MCP Validation Runbook

This runbook validates one exact Git commit in the Lane F worktree. It covers
the Funplay MCP editor channel, changed GDScripts, changed scenes, loadable
changed resources, the configured main scene, runtime receipts/events, and
PNG captures at the requested desktop sizes. It does not change production
composition, `scenes/main.tscn`, application flow, or any V0.7.4 file.

The companion probe is
`res://tests/v075_mcp_production_probe.gd`. It is a headless, read-only
`SceneTree` script. It only reads `ProjectSettings`, `ResourceLoader`,
`FileAccess`, and environment-provided manifests; it does not instantiate
gameplay, draw RNG, write a save, or mutate the world. It prints one machine
readable line beginning with `V075_MCP_PRODUCTION_PROBE|`.

The PowerShell fences in this document are one ordered program, not independent
clipboard snippets. Execute them only through
`tools/invoke_v075_mcp_validation_runbook.ps1`. The companion extracts exactly
12 fences, parses each fence and their combined program, dot-sources them in one
scope, and owns failure cleanup in `finally`. Running a later fence after an
earlier fence failed is forbidden. Before the exact-SHA run, prove the companion
offline with:

```text
pwsh -NoProfile -File tools/invoke_v075_mcp_validation_runbook.ps1 -ValidateOnly
```

## Exact Toolchain

The repository also exposes the stdio configuration used by interactive MCP
clients:

```text
.mcp.json
  -> cmd /d /s /c tools\\funplay_mcp_stdio.cmd
  -> pnpm dlx funplay-godot-mcp@0.9.6
  -> http://127.0.0.1:<role-port>/
  -> Godot editor Funplay MCP addon
```

This runbook's auditable execution path is the already authenticated,
role-scoped HTTP JSON-RPC endpoint. `invoke_role_godot_mcp.ps1` verifies the
Godot PID/start token/executable/`--path`/endpoint owner on every call, writes
the exact HTTP response bytes outside the worktree, and only then parses the
envelope. It does not claim that the stdio wrapper transported these calls.

Use Role A on port `7576`. Supply the exact worktree and Godot executable at
run time; the runbook must not depend on a developer-specific profile path:

```powershell
if ([string]::IsNullOrWhiteSpace($env:V075_MCP_WORKTREE)) {
    throw "V075_MCP_WORKTREE is required."
}
if ([string]::IsNullOrWhiteSpace($env:V075_GODOT_PATH)) {
    throw "V075_GODOT_PATH is required."
}
$Worktree = (Resolve-Path -LiteralPath $env:V075_MCP_WORKTREE).Path
$Godot = (Resolve-Path -LiteralPath $env:V075_GODOT_PATH).Path
$Launch = Join-Path $Worktree "tools\launch_role_godot_mcp.ps1"
$Invoke = Join-Path $Worktree "tools\invoke_role_godot_mcp.ps1"
$Stop = Join-Path $Worktree "tools\stop_role_godot_mcp.ps1"
$ProcessIdentityModule = Join-Path `
    $Worktree `
    "tools\role_godot_mcp_process_identity.psm1"
Import-Module -Name $ProcessIdentityModule -Force -ErrorAction Stop
if ([string]::IsNullOrWhiteSpace($env:V075_PR90_EVIDENCE_ROOT)) {
    throw "V075_PR90_EVIDENCE_ROOT is required outside the worktree."
}
$EvidenceRoot = [IO.Path]::GetFullPath($env:V075_PR90_EVIDENCE_ROOT)
$WorktreePrefix = $Worktree.TrimEnd("\") + [IO.Path]::DirectorySeparatorChar
Assert-RunnerPathChainHasNoReparsePoint `
    -Path $Worktree `
    -Label "Exact-SHA MCP worktree"
Assert-RunnerPathChainHasNoReparsePoint `
    -Path $EvidenceRoot `
    -Label "Exact-SHA MCP evidence root"
if ($EvidenceRoot.Equals($Worktree, [StringComparison]::OrdinalIgnoreCase) `
    -or $EvidenceRoot.StartsWith($WorktreePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "V075_PR90_EVIDENCE_ROOT must be outside the worktree."
}
```

After the same-SHA manifest below is frozen, the launch script creates
role-local metadata under `.codex-godot`, checks that the returned project root
is this worktree, and waits for `get_project_info`. Do not invoke a tool before
that launch succeeds. Every call in the executable blocks below goes through
the invoke script, which adds `X-Funplay-MCP-Token` and
`MCP-Protocol-Version` from that metadata and saves the unparsed JSON-RPC
envelope outside the worktree before parsing it.

The exact core tool names used by this runbook are:

| Gate | MCP tool |
| --- | --- |
| tool discovery | JSON-RPC `tools/list`, or `list_tool_catalog` |
| project identity/reload | `get_project_info`, `get_capability_status`, `request_script_reload` |
| changed GDScript | per-file `validate_script`; project-scope `get_script_errors` with independently derived coverage |
| changed scene | `open_scene`, `get_scene_info`, `get_scene_tree` |
| file/resource presence | `file_exists`, `read_file`, read-only `execute_code` with `ResourceLoader` |
| main sample | `play_main_scene`, `get_play_state`, `get_project_setting`, `query_runtime_node`, `wait_msec` |
| real UI gameplay | `query_runtime_node`, then child-runtime `send_runtime_input`; never editor-side input as a substitute |
| visual/runtime evidence | `capture_runtime_view`, `get_runtime_events`, `get_console_logs` |
| clean stop | `exit_play_mode`, then `tools\stop_role_godot_mcp.ps1` |

The current server reports Godot `4.7-stable`, Funplay MCP `0.9.6`, profile
`core`, 78 exposed tools, zero disabled tools, and runtime bridge/play mode
capability enabled. `get_editor_protocol_status` reports the optional LSP/DAP
settings; it is diagnostic context, not a substitute for Funplay MCP.

Before the exact-SHA MCP run, use a separate clean sibling worktree at the same
frozen HEAD/tree to create the generated-UID authority. Capture a clean
preimport baseline with `tools/invoke_v075_formal_authority.ps1`, perform one
bounded Godot 4.7 controlled import and clean stop, require the tracked import
result to be the complete canonical 57-file/byte map recorded by this runbook,
restore those 57 imports exactly to HEAD, then run the tooling operation
`capture-uid-allowlist`. Store that JSON outside every worktree and freeze the
returned SHA-256 independently. The preimport and exact MCP roles must never run
concurrently. Supply the immutable inputs to the companion as:

```text
-GeneratedUidAllowlistPath <external formal_generated_uid_allowlist.v1 JSON>
-ExpectedGeneratedUidAllowlistSha256 <independently frozen lowercase 64-hex SHA>
```

The exact MCP worktree itself starts completely clean. The external allowlist
binds every expected `.gd.uid`/`.gdshader.uid` path, UID value, raw-file hash,
byte length, source mapping, HEAD, and tree. A suffix or a post-run discovery is
never cleanup authority.

## Same-SHA Manifest

Run this before any validation. For PR acceptance, the changed-file authority
is the PR merge base, not the target commit's first parent. Using the first
parent after a small closure commit can produce a false-green `0/0/0`
manifest.

```powershell
$ErrorActionPreference = "Stop"
function Invoke-CheckedGit {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $Rows = @(& git -C $Worktree @Arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git -C <worktree> $($Arguments -join ' ')"
    }
    return @($Rows)
}

$BaseMainSha = "bd0af5c99c5267cdbe7d66c01034f80db4d704fd"
if ([string]::IsNullOrWhiteSpace($env:V075_FINAL_HEAD_SHA)) {
    throw "V075_FINAL_HEAD_SHA is required after FINAL_SHA_FROZEN."
}
if ([string]::IsNullOrWhiteSpace($env:V075_FINAL_TREE_SHA)) {
    throw "V075_FINAL_TREE_SHA is required after FINAL_SHA_FROZEN."
}
$FrozenHeadSha = $env:V075_FINAL_HEAD_SHA.Trim().ToLowerInvariant()
$FrozenTreeSha = $env:V075_FINAL_TREE_SHA.Trim().ToLowerInvariant()
$Branch = "codex/v075-monster-military-combat-bd0af5c"
$WorktreeStatus = @(
    Invoke-CheckedGit -Arguments @(
        "status", "--porcelain=v1", "--untracked-files=all"
    )
)
if ($WorktreeStatus.Count -ne 0) {
    throw "Exact-SHA MCP requires a clean worktree."
}
$HeadRows = @(Invoke-CheckedGit -Arguments @("rev-parse", "HEAD"))
$TreeRows = @(Invoke-CheckedGit -Arguments @("rev-parse", "HEAD^{tree}"))
if ($HeadRows.Count -ne 1 -or $TreeRows.Count -ne 1) {
    throw "Local HEAD/tree identity was not unique."
}
$HeadSha = $HeadRows[0].Trim()
$TreeSha = $TreeRows[0].Trim()
$RemoteRows = @(
    Invoke-CheckedGit -Arguments @(
        "ls-remote", "--exit-code", "origin", "refs/heads/$Branch"
    )
)
if ($RemoteRows.Count -ne 1) {
    throw "The exact remote PR branch could not be resolved uniquely."
}
$RemoteSha = (($RemoteRows[0] -split "\s+")[0]).Trim()
if ($HeadSha -cne $FrozenHeadSha -or $TreeSha -cne $FrozenTreeSha) {
    throw "Local HEAD/tree does not match the frozen authority."
}
if ($RemoteSha -cne $HeadSha) {
    throw "Remote PR branch does not match local frozen HEAD."
}
$MergeBaseRows = @(
    Invoke-CheckedGit -Arguments @("merge-base", $BaseMainSha, $HeadSha)
)
if ($MergeBaseRows.Count -ne 1) {
    throw "PR merge base was not unique."
}
$MergeBaseSha = $MergeBaseRows[0].Trim()
if ($MergeBaseSha -cne $BaseMainSha) {
    throw "Unexpected PR merge base: expected=$BaseMainSha actual=$MergeBaseSha"
}
$DiffParentSha = $BaseMainSha
$Changed = @(Invoke-CheckedGit -Arguments @(
    "diff", "--name-only", "--diff-filter=ACMRTUXB", $DiffParentSha, $HeadSha
) |
    ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Deleted = @(Invoke-CheckedGit -Arguments @(
    "diff", "--name-only", "--diff-filter=D", $DiffParentSha, $HeadSha
) |
    ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($Deleted.Count -ne 0) {
    throw "Deleted changed paths require a separate non-loadable audit."
}
if (@($Changed | Sort-Object -Unique).Count -ne $Changed.Count) {
    throw "Changed-file manifest contains duplicate paths."
}
if (@($Changed | Where-Object { $_ -match '[;|]' }).Count -ne 0) {
    throw "Changed paths contain an unsafe manifest delimiter."
}
foreach ($Path in $Changed) {
    if (-not (Test-Path -LiteralPath (Join-Path $Worktree $Path))) {
        throw "Changed path is missing from the frozen worktree: $Path"
    }
}
$null = Invoke-CheckedGit -Arguments @(
    "diff", "--check", $DiffParentSha, $HeadSha
)

function Convert-ToResPath([string]$Path) {
    return "res://" + ($Path.Replace("\", "/"))
}

$Scripts = @($Changed | Where-Object { $_ -match "\.gd$" } |
    ForEach-Object { Convert-ToResPath $_ })
$Scenes = @($Changed | Where-Object { $_ -match "\.tscn$" } |
    ForEach-Object { Convert-ToResPath $_ })
$ResourceExtensions = @(
    ".json", ".tres", ".res", ".svg", ".png", ".jpg", ".jpeg",
    ".webp", ".exr", ".glb", ".gltf", ".gdshader", ".shader"
)
$Resources = @($Changed | Where-Object {
    $ResourceExtensions -contains ([IO.Path]::GetExtension($_).ToLowerInvariant())
} | ForEach-Object { Convert-ToResPath $_ })
if ($Scripts.Count -lt 120 -or $Scenes.Count -lt 12 -or $Resources.Count -lt 15) {
    throw "PR-wide manifest unexpectedly shrank below the established lower bounds."
}
$ManifestText = @($Changed | Sort-Object) -join "`n"
$ManifestSha256 = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
        [Text.UTF8Encoding]::new($false).GetBytes($ManifestText)
    )
).ToLowerInvariant()

"HEAD=$HeadSha"
"TREE=$TreeSha"
"DIFF_PARENT=$DiffParentSha"
"CHANGED_TOTAL=$($Changed.Count)"
"DELETED=$($Deleted.Count)"
"SCRIPTS=$($Scripts.Count)"
"SCENES=$($Scenes.Count)"
"RESOURCES=$($Resources.Count)"
"REMOTE=$RemoteSha"
"MANIFEST_SHA256=$ManifestSha256"
```

The manifest is passed to the probe without writing a report into the
repository. The delimiter is `;`; paths themselves must not contain `;` or
`|`.

```powershell
$env:V075_MCP_EXPECTED_SHA = $HeadSha
$env:V075_MCP_DIFF_PARENT_SHA = $DiffParentSha
$env:V075_MCP_MAIN_SCENE = "res://scenes/main.tscn"
$env:V075_MCP_CHANGED_SCRIPTS = $Scripts -join ";"
$env:V075_MCP_CHANGED_SCENES = $Scenes -join ";"
$env:V075_MCP_CHANGED_RESOURCES = $Resources -join ";"

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Resolve-WorktreeChildPath([string]$RelativePath) {
    if ([string]::IsNullOrWhiteSpace($RelativePath) `
        -or [IO.Path]::IsPathRooted($RelativePath)) {
        throw "Expected a nonempty worktree-relative path: $RelativePath"
    }
    $AbsolutePath = [IO.Path]::GetFullPath(
        (Join-Path $Worktree $RelativePath.Replace(
            "/",
            [IO.Path]::DirectorySeparatorChar
        ))
    )
    if (-not $AbsolutePath.StartsWith(
        $WorktreePrefix,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Worktree-relative path escaped the worktree: $RelativePath"
    }
    Assert-RunnerPathChainHasNoReparsePoint `
        -Path $AbsolutePath `
        -Label "Exact-SHA MCP worktree target"
    return $AbsolutePath
}

function Get-HeadBlobSha([string]$RelativePath) {
    $Rows = @(
        Invoke-CheckedGit -Arguments @(
            "rev-parse", "--verify", "$HeadSha`:$RelativePath"
        )
    )
    if ($Rows.Count -ne 1 `
        -or -not [regex]::IsMatch(
            $Rows[0].Trim(),
            "\A[0-9a-f]{40,64}\z",
            [Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        throw "Tracked HEAD blob identity was not unique: $RelativePath"
    }
    return $Rows[0].Trim()
}

function Get-GodotImportIdentity([string]$Path) {
    $Text = [IO.File]::ReadAllText($Path)
    $Values = [ordered]@{}
    foreach ($Name in @("importer", "type", "uid", "source_file")) {
        $Pattern = '(?m)^' + [regex]::Escape($Name) + '="([^"]+)"\s*$'
        $Match = [regex]::Match($Text, $Pattern)
        if (-not $Match.Success) {
            throw "Tracked import metadata is missing $Name`: $Path"
        }
        $Values[$Name] = $Match.Groups[1].Value
    }
    return [pscustomobject]$Values
}

function Write-AtomicUtf8Json([string]$Path, [object]$Value) {
    if (Test-Path -LiteralPath $Path) {
        throw "Refusing to overwrite immutable evidence: $Path"
    }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    $TemporaryPath = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText(
            $TemporaryPath,
            ($Value | ConvertTo-Json -Depth 30),
            [Text.UTF8Encoding]::new($false)
        )
        [IO.File]::Move($TemporaryPath, $Path, $false)
    } finally {
        if (Test-Path -LiteralPath $TemporaryPath) {
            Remove-Item -LiteralPath $TemporaryPath -Force
        }
    }
}

function Write-AtomicUtf8Text([string]$Path, [string]$Value) {
    if (Test-Path -LiteralPath $Path) {
        throw "Refusing to overwrite immutable evidence: $Path"
    }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    $TemporaryPath = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText(
            $TemporaryPath,
            $Value,
            [Text.UTF8Encoding]::new($false)
        )
        [IO.File]::Move($TemporaryPath, $Path, $false)
    } finally {
        if (Test-Path -LiteralPath $TemporaryPath) {
            Remove-Item -LiteralPath $TemporaryPath -Force
        }
    }
}

function Write-AtomicBytes([string]$Path, [byte[]]$Value) {
    if (Test-Path -LiteralPath $Path) {
        throw "Refusing to overwrite immutable evidence: $Path"
    }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    $TemporaryPath = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllBytes($TemporaryPath, $Value)
        [IO.File]::Move($TemporaryPath, $Path, $false)
    } finally {
        if (Test-Path -LiteralPath $TemporaryPath) {
            Remove-Item -LiteralPath $TemporaryPath -Force
        }
    }
}

$ValidationRunId = "{0}-{1}-{2}" -f @(
    $HeadSha.Substring(0, 12),
    [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssfffZ"),
    [guid]::NewGuid().ToString("N").Substring(0, 8)
)
$ValidationEvidenceRoot = Join-Path $EvidenceRoot $ValidationRunId
[IO.Directory]::CreateDirectory($ValidationEvidenceRoot) | Out-Null

$ExactShaManifest = [ordered]@{
    schema = "SpaceSyndicateExactShaChangedManifestV1"
    frozen_head_sha = $FrozenHeadSha
    frozen_tree_sha = $FrozenTreeSha
    remote_head_sha = $RemoteSha
    diff_parent_sha = $DiffParentSha
    manifest_sha256 = $ManifestSha256
    changed_count = $Changed.Count
    changed_paths = @($Changed | Sort-Object)
    deleted_count = $Deleted.Count
    script_count = $Scripts.Count
    scripts = @($Scripts | Sort-Object)
    scene_count = $Scenes.Count
    scenes = @($Scenes | Sort-Object)
    resource_count = $Resources.Count
    resources = @($Resources | Sort-Object)
}
$ExactShaManifestPath = Join-Path `
    $ValidationEvidenceRoot `
    "exact-sha-changed-manifest.json"

# Freeze a closed transient-artifact authority before Godot starts. The 57
# tracked imports are accepted only when every path is byte-exact HEAD or
# byte-exact canonical Godot 4.7 output; HEAD, generated subsets, and the full
# generated set are distinct closed states. Generated UID
# authority comes from a separate controlled-preimport worktree and an
# independently frozen external SHA; runtime suffix discovery is never
# authority.
$CanonicalImportAuthority = Get-RunnerCanonicalImportAuthority
$CanonicalImportPaths = [string[]]@($CanonicalImportAuthority.paths)
$CanonicalImportPathSetSha256 = Get-RunnerCanonicalPathSetSha256 `
    -Paths $CanonicalImportPaths
$CanonicalGeneratedImportHashMap = `
    $CanonicalImportAuthority.generated_content_sha256_by_path
$CanonicalGeneratedImportRows = [Collections.Generic.List[string]]::new()
foreach ($Path in $CanonicalImportPaths) {
    if ($null -eq $CanonicalGeneratedImportHashMap `
        -or -not $CanonicalGeneratedImportHashMap.Contains($Path)) {
        throw "The canonical generated import authority is missing: $Path"
    }
    $GeneratedContentSha256 = [string]$CanonicalGeneratedImportHashMap[$Path]
    if (-not [regex]::IsMatch($GeneratedContentSha256, '\A[0-9a-f]{64}\z')) {
        throw "The canonical generated import hash is invalid: $Path"
    }
    $CanonicalGeneratedImportRows.Add(
        "$Path$([char]0)$GeneratedContentSha256"
    )
}
$CanonicalGeneratedImportMapSha256 = Get-RunnerCanonicalSha256Hex -Bytes (
    [Text.UTF8Encoding]::new($false, $true).GetBytes(
        [string]::Join(
            "`n",
            [string[]]$CanonicalGeneratedImportRows.ToArray()
        )
    )
)
if ($CanonicalImportPaths.Count -ne [int]$CanonicalImportAuthority.expected_count `
    -or $CanonicalImportPathSetSha256 `
        -cne [string]$CanonicalImportAuthority.path_set_sha256 `
    -or $CanonicalGeneratedImportHashMap.Count -ne $CanonicalImportPaths.Count `
    -or $CanonicalGeneratedImportMapSha256 `
        -cne [string]$CanonicalImportAuthority.generated_map_sha256) {
    throw "The canonical tracked-import path authority is internally inconsistent."
}
$PreRunCanonicalImportMapSha256 = Get-RunnerCanonicalFileMapSha256 `
    -Root $Worktree `
    -Paths $CanonicalImportPaths
if ($PreRunCanonicalImportMapSha256 `
    -cne [string]$CanonicalImportAuthority.baseline_map_sha256) {
    throw "The tracked-import baseline differs from the frozen canonical authority."
}
$ImportCandidates = @(
    foreach ($Path in $CanonicalImportPaths) {
        $AbsolutePath = Resolve-WorktreeChildPath $Path
        [pscustomobject][ordered]@{
            path = $Path
            head_blob_sha = Get-HeadBlobSha $Path
            baseline_content_sha256 = Get-FileSha256 $AbsolutePath
            generated_content_sha256 = `
                [string]$CanonicalGeneratedImportHashMap[$Path]
        }
    }
)

if ([string]::IsNullOrWhiteSpace($env:V075_MCP_GENERATED_UID_ALLOWLIST_PATH) `
    -or [string]::IsNullOrWhiteSpace(
        $env:V075_MCP_EXPECTED_GENERATED_UID_ALLOWLIST_SHA256
    )) {
    throw (
        "V075_MCP_GENERATED_UID_ALLOWLIST_PATH and " +
        "V075_MCP_EXPECTED_GENERATED_UID_ALLOWLIST_SHA256 are required."
    )
}
$UidAllowlistValidation = Read-RunnerExactUidAllowlist `
    -Path $env:V075_MCP_GENERATED_UID_ALLOWLIST_PATH `
    -ExpectedSha256 $env:V075_MCP_EXPECTED_GENERATED_UID_ALLOWLIST_SHA256 `
    -Worktree $Worktree `
    -HeadSha $HeadSha `
    -TreeSha $TreeSha
$UidAllowlistSourcePath = [string]$UidAllowlistValidation.source_path
$UidAllowlistSourceSha256 = [string]$UidAllowlistValidation.actual_sha256
$UidAllowlistEvidencePath = Join-Path `
    $ValidationEvidenceRoot `
    "frozen-generated-uid-allowlist.json"
Write-AtomicBytes `
    -Path $UidAllowlistEvidencePath `
    -Value ([byte[]]$UidAllowlistValidation.bytes)
$UidAllowlistEvidenceSha256 = Get-FileSha256 $UidAllowlistEvidencePath
if ($UidAllowlistEvidenceSha256 -cne $UidAllowlistSourceSha256) {
    throw "The run-local UID allowlist copy differs from its frozen source."
}
$UidCandidates = @($UidAllowlistValidation.candidates)
foreach ($Candidate in $UidCandidates) {
    $AbsoluteUidPath = Resolve-WorktreeChildPath ([string]$Candidate.path)
    if (Test-Path -LiteralPath $AbsoluteUidPath) {
        throw "Clean exact-SHA preflight already contains UID: $($Candidate.path)"
    }
}
$ExactShaManifest.generated_uid_allowlist_source_path = $UidAllowlistSourcePath
$ExactShaManifest.generated_uid_allowlist_expected_sha256 = `
    $env:V075_MCP_EXPECTED_GENERATED_UID_ALLOWLIST_SHA256
$ExactShaManifest.generated_uid_allowlist_actual_sha256 = `
    $UidAllowlistSourceSha256
$ExactShaManifest.generated_uid_allowlist_evidence_path = `
    $UidAllowlistEvidencePath
$ExactShaManifest.generated_uid_allowlist_evidence_sha256 = `
    $UidAllowlistEvidenceSha256
$ExactShaManifest.generated_uid_entry_count = $UidCandidates.Count
$ExactShaManifest.generated_uid_entry_set_sha256 = `
    [string]$UidAllowlistValidation.uid_entry_set_sha256
$ExactShaManifest.canonical_import_path_set_sha256 = `
    $CanonicalImportPathSetSha256
$ExactShaManifest.canonical_import_baseline_map_sha256 = `
    $PreRunCanonicalImportMapSha256
$ExactShaManifest.canonical_import_generated_map_sha256 = `
    $CanonicalGeneratedImportMapSha256
Write-AtomicUtf8Json $ExactShaManifestPath $ExactShaManifest
$ExactShaManifestEvidenceSha256 = Get-FileSha256 $ExactShaManifestPath
$ImportCandidateMap = [Collections.Generic.Dictionary[string,object]]::new(
    [StringComparer]::Ordinal
)
foreach ($Candidate in $ImportCandidates) {
    $ImportCandidateMap.Add([string]$Candidate.path, $Candidate)
}
$UidCandidateMap = [Collections.Generic.Dictionary[string,object]]::new(
    [StringComparer]::Ordinal
)
foreach ($Candidate in $UidCandidates) {
    $UidCandidateMap.Add([string]$Candidate.path, $Candidate)
}
$TransientArtifactAuthority = [ordered]@{
    schema = "SpaceSyndicateExactShaTransientArtifactAuthorityV2"
    frozen_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
    head_sha = $HeadSha
    tree_sha = $TreeSha
    worktree = $Worktree
    canonical_import_schema = [string]$CanonicalImportAuthority.schema
    canonical_import_path_set_sha256 = $CanonicalImportPathSetSha256
    canonical_import_baseline_map_sha256 = $PreRunCanonicalImportMapSha256
    canonical_import_generated_map_sha256 = `
        [string]$CanonicalImportAuthority.generated_map_sha256
    import_candidate_count = $ImportCandidates.Count
    import_candidates = $ImportCandidates
    generated_uid_allowlist_source_path = $UidAllowlistSourcePath
    generated_uid_allowlist_source_sha256 = $UidAllowlistSourceSha256
    generated_uid_allowlist_evidence_path = $UidAllowlistEvidencePath
    generated_uid_allowlist_evidence_sha256 = $UidAllowlistEvidenceSha256
    generated_uid_entry_set_sha256 = `
        [string]$UidAllowlistValidation.uid_entry_set_sha256
    uid_candidate_count = $UidCandidates.Count
    uid_candidates = $UidCandidates
}
$TransientArtifactAuthorityPath = Join-Path `
    $ValidationEvidenceRoot `
    "transient-artifact-authority.json"
Write-AtomicUtf8Json $TransientArtifactAuthorityPath $TransientArtifactAuthority
$TransientArtifactAuthoritySha256 = Get-FileSha256 $TransientArtifactAuthorityPath

$LaunchResult = & $Launch -Role A -Port 7576 -Worktree $Worktree `
    -GodotPath $Godot -Renderer forward_plus `
    -ResolutionWidth 1600 -ResolutionHeight 960 | ConvertFrom-Json
$LaunchPid = Get-RunnerRequiredProperty $LaunchResult "pid" "role launch"
$LaunchEndpointOwnerPid = Get-RunnerRequiredProperty `
    $LaunchResult "endpoint_owner_pid" "role launch"
$LaunchWorktree = Get-RunnerRequiredProperty `
    $LaunchResult "worktree" "role launch"
if (-not (Test-RunnerJsonIntegralNumber $LaunchPid) `
    -or -not (Test-RunnerJsonIntegralNumber $LaunchEndpointOwnerPid) `
    -or [int64]$LaunchPid -le 0 `
    -or [int64]$LaunchEndpointOwnerPid -ne [int64]$LaunchPid `
    -or $LaunchWorktree -isnot [string] `
    -or -not ([string]$LaunchWorktree).Equals(
        $Worktree, [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Role A launch identity did not pass."
}
$LaunchProcessStartUtc = ConvertTo-RoleGodotProcessStartUtc `
    -Token $LaunchResult.process_start_time_utc
$LaunchLogPath = [IO.Path]::GetFullPath([string]$LaunchResult.log_path)
$ExpectedLogRoot = [IO.Path]::GetFullPath(
    (Join-Path $Worktree ".codex-godot\logs")
).TrimEnd("\") + [IO.Path]::DirectorySeparatorChar
if (-not $LaunchLogPath.StartsWith(
    $ExpectedLogRoot,
    [StringComparison]::OrdinalIgnoreCase
) -or -not (Test-Path -LiteralPath $LaunchLogPath -PathType Leaf)) {
    throw "Role A launch log is absent or outside its role-local log root."
}
$LaunchLogInfo = Get-Item -LiteralPath $LaunchLogPath
if ($LaunchLogInfo.CreationTimeUtc -lt $LaunchProcessStartUtc.AddSeconds(-2)) {
    throw "Role A launch log predates the launched process epoch."
}
"MCP_TRANSIENT_ARTIFACT_AUTHORITY_SHA256=$TransientArtifactAuthoritySha256"
"MCP_CANONICAL_IMPORT_PATH_COUNT=$($ImportCandidates.Count)"
"MCP_CANONICAL_IMPORT_PATH_SET_SHA256=$CanonicalImportPathSetSha256"
"MCP_CANONICAL_IMPORT_BASELINE_MAP_SHA256=$PreRunCanonicalImportMapSha256"
"MCP_GENERATED_UID_ALLOWLIST_SHA256=$UidAllowlistEvidenceSha256"
"MCP_GENERATED_UID_ENTRY_SET_SHA256=$($UidAllowlistValidation.uid_entry_set_sha256)"
"MCP_GENERATED_UID_AUTHORIZED_COUNT=$($UidCandidates.Count)"
```

This is an attestation pipeline, not a Git implementation inside Godot: Git
supplies the exact SHA, tree, and PR merge-base diff. Freeze the actual counts
and manifest SHA-256 in the external evidence ledger; never substitute a
first-parent count or a stale hard-coded denominator. The probe validates the
files visible at that exact worktree revision.

## Reload And Static MCP Gates

Use a small JSON helper so errors from the JSON-RPC envelope are not mistaken
for a successful tool result:

```powershell
$script:McpRawSequence = 0
$script:McpRawEvidence = [Collections.Generic.List[object]]::new()
$McpRawEvidenceRoot = Join-Path $ValidationEvidenceRoot "mcp-raw"
[IO.Directory]::CreateDirectory($McpRawEvidenceRoot) | Out-Null

function Get-McpRuntimeQueryTimeoutBudget {
    param(
        [ValidateRange(1, 600)]
        [int]$RequestedSeconds
    )
    $BridgeSeconds = [Math]::Min(30, $RequestedSeconds)
    return [pscustomobject][ordered]@{
        requested_seconds = $RequestedSeconds
        bridge_timeout_seconds = $BridgeSeconds
        bridge_timeout_msec = $BridgeSeconds * 1000
        transport_timeout_seconds = [Math]::Min(600, $BridgeSeconds + 15)
    }
}

function Get-McpRawEvidenceIntegrityGate {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Rows,
        [Parameter(Mandatory = $true)][string]$RawRoot
    )
    $Issues = [Collections.Generic.List[string]]::new()
    $FailedSequences = [Collections.Generic.HashSet[int]]::new()
    $InvokeErrorSequences = [Collections.Generic.HashSet[int]]::new()
    $RawPaths = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    $RawVerifiedCount = 0
    $RawRootFull = [IO.Path]::GetFullPath($RawRoot).TrimEnd("\", "/")
    if (-not (Test-Path -LiteralPath $RawRootFull -PathType Container)) {
        $Issues.Add("MCP raw evidence root is absent: $RawRootFull")
    }
    if ($Rows.Count -eq 0) {
        $Issues.Add("MCP raw evidence ledger is empty.")
    }
    for ($RowIndex = 0; $RowIndex -lt $Rows.Count; $RowIndex += 1) {
        $Row = $Rows[$RowIndex]
        $ExpectedSequence = $RowIndex + 1
        $Sequence = $ExpectedSequence
        $SequenceProperty = $Row.PSObject.Properties["sequence"]
        try {
            if ($null -eq $SequenceProperty -or $null -eq $SequenceProperty.Value) {
                throw "missing"
            }
            $Sequence = [Convert]::ToInt32(
                $SequenceProperty.Value,
                [Globalization.CultureInfo]::InvariantCulture
            )
        } catch {
            $Issues.Add("MCP raw row $ExpectedSequence has no integral sequence.")
            $null = $FailedSequences.Add($ExpectedSequence)
            $Sequence = $ExpectedSequence
        }
        if ($Sequence -ne $ExpectedSequence) {
            $Issues.Add(
                "MCP raw sequence is not contiguous/in-order: expected=$ExpectedSequence actual=$Sequence"
            )
            $null = $FailedSequences.Add($ExpectedSequence)
        }

        $ValidationProperty = $Row.PSObject.Properties["validation_succeeded"]
        if ($null -eq $ValidationProperty `
            -or $ValidationProperty.Value -isnot [bool] `
            -or -not [bool]$ValidationProperty.Value) {
            $Issues.Add("MCP raw row did not complete validation: sequence=$Sequence")
            $null = $FailedSequences.Add($ExpectedSequence)
        }
        $ExitProperty = $Row.PSObject.Properties["invoke_exit_code"]
        if ($null -eq $ExitProperty `
            -or $null -eq $ExitProperty.Value `
            -or [int]$ExitProperty.Value -ne 0) {
            $Issues.Add("MCP raw row has nonzero invoke exit: sequence=$Sequence")
            $null = $FailedSequences.Add($ExpectedSequence)
        }
        $InvocationFailureProperty = $Row.PSObject.Properties["invocation_failure"]
        if ($null -eq $InvocationFailureProperty `
            -or $InvocationFailureProperty.Value -isnot [bool] `
            -or [bool]$InvocationFailureProperty.Value) {
            $Issues.Add("MCP raw row has an invocation failure: sequence=$Sequence")
            $null = $FailedSequences.Add($ExpectedSequence)
        }
        $RawCreatedProperty = $Row.PSObject.Properties["raw_wire_response_created"]
        if ($null -eq $RawCreatedProperty `
            -or $RawCreatedProperty.Value -isnot [bool] `
            -or -not [bool]$RawCreatedProperty.Value) {
            $Issues.Add("MCP raw row has no wire response: sequence=$Sequence")
            $null = $FailedSequences.Add($ExpectedSequence)
        }
        $FailureStageProperty = $Row.PSObject.Properties["failure_stage"]
        $FailureMessageProperty = $Row.PSObject.Properties["failure_message"]
        if ($null -eq $FailureStageProperty `
            -or $null -eq $FailureMessageProperty `
            -or -not [string]::IsNullOrWhiteSpace(
                [string]$FailureStageProperty.Value
            ) `
            -or -not [string]::IsNullOrWhiteSpace(
                [string]$FailureMessageProperty.Value
            )) {
            $Issues.Add("MCP raw row retains a validation failure: sequence=$Sequence")
            $null = $FailedSequences.Add($ExpectedSequence)
        }

        $StartedAt = [DateTimeOffset]::MinValue
        $CompletedAt = [DateTimeOffset]::MinValue
        $ElapsedProperty = $Row.PSObject.Properties["elapsed_msec"]
        $ElapsedMsec = -1.0
        try {
            if ($null -eq $ElapsedProperty -or $null -eq $ElapsedProperty.Value) {
                throw "missing"
            }
            $ElapsedMsec = [Convert]::ToDouble(
                $ElapsedProperty.Value,
                [Globalization.CultureInfo]::InvariantCulture
            )
        } catch {
            $ElapsedMsec = -1.0
        }
        if (-not [DateTimeOffset]::TryParse(
                [string]$Row.started_at_utc,
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::RoundtripKind,
                [ref]$StartedAt
            ) `
            -or -not [DateTimeOffset]::TryParse(
                [string]$Row.completed_at_utc,
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::RoundtripKind,
                [ref]$CompletedAt
            ) `
            -or $CompletedAt -lt $StartedAt `
            -or [double]::IsNaN($ElapsedMsec) `
            -or [double]::IsInfinity($ElapsedMsec) `
            -or $ElapsedMsec -lt 0) {
            $Issues.Add("MCP raw row timing is invalid: sequence=$Sequence")
            $null = $FailedSequences.Add($ExpectedSequence)
        }

        $InvokeErrorPathProperty = $Row.PSObject.Properties["invoke_error_path"]
        $InvokeErrorSha256Property = `
            $Row.PSObject.Properties["invoke_error_sha256"]
        $InvokeErrorPath = if ($null -eq $InvokeErrorPathProperty) {
            ""
        } else {
            [string]$InvokeErrorPathProperty.Value
        }
        $InvokeErrorSha256 = if ($null -eq $InvokeErrorSha256Property) {
            ""
        } else {
            [string]$InvokeErrorSha256Property.Value
        }
        if ($null -eq $InvokeErrorPathProperty `
            -or $null -eq $InvokeErrorSha256Property `
            -or -not [string]::IsNullOrWhiteSpace($InvokeErrorPath) `
            -or -not [string]::IsNullOrWhiteSpace($InvokeErrorSha256)) {
            $Issues.Add("MCP raw row references invoke-error evidence: sequence=$Sequence")
            $null = $FailedSequences.Add($ExpectedSequence)
            $null = $InvokeErrorSequences.Add($ExpectedSequence)
        }

        $RawPath = [string]$Row.raw_path
        try {
            if ([string]::IsNullOrWhiteSpace($RawPath) `
                -or -not [IO.Path]::IsPathFullyQualified($RawPath)) {
                throw "raw path is absent or not absolute"
            }
            $RawPathFull = [IO.Path]::GetFullPath($RawPath)
            if (-not $RawPathFull.StartsWith(
                    $RawRootFull + [IO.Path]::DirectorySeparatorChar,
                    [StringComparison]::OrdinalIgnoreCase
                ) `
                -or -not $RawPaths.Add($RawPathFull) `
                -or -not (Test-Path -LiteralPath $RawPathFull -PathType Leaf)) {
                throw "raw path is outside the root, duplicate, or absent"
            }
            [byte[]]$RawBytes = [IO.File]::ReadAllBytes($RawPathFull)
            $ActualRawSha256 = [Convert]::ToHexString(
                [Security.Cryptography.SHA256]::HashData($RawBytes)
            ).ToLowerInvariant()
            $RawByteCountProperty = $Row.PSObject.Properties["raw_byte_count"]
            if ($null -eq $RawByteCountProperty `
                -or $null -eq $RawByteCountProperty.Value `
                -or [string]$Row.raw_sha256 -cnotmatch '\A[0-9a-f]{64}\z' `
                -or $ActualRawSha256 -cne [string]$Row.raw_sha256 `
                -or [int64]$RawBytes.Length `
                    -ne [int64]$RawByteCountProperty.Value) {
                throw "raw response hash/byte count differs"
            }
            $RawVerifiedCount += 1
        } catch {
            $Issues.Add("MCP raw row file integrity failed: sequence=$Sequence detail=$_")
            $null = $FailedSequences.Add($ExpectedSequence)
        }
    }
    [string[]]$OrphanInvokeErrorPaths = @()
    if (Test-Path -LiteralPath $RawRootFull -PathType Container) {
        $OrphanInvokeErrorPaths = [string[]]@(
            Get-ChildItem `
                -LiteralPath $RawRootFull `
                -Filter "*.invoke-error.json" `
                -File `
                -Recurse `
                -Force |
                ForEach-Object { $_.FullName } |
                Sort-Object
        )
    }
    foreach ($OrphanInvokeErrorPath in $OrphanInvokeErrorPaths) {
        $Issues.Add("MCP invoke-error artifact exists: $OrphanInvokeErrorPath")
    }
    [string[]]$ActualRawResponsePaths = @()
    if (Test-Path -LiteralPath $RawRootFull -PathType Container) {
        $ActualRawResponsePaths = [string[]]@(
            Get-ChildItem `
                -LiteralPath $RawRootFull `
                -Filter "*.jsonrpc.json" `
                -File `
                -Recurse `
                -Force |
                ForEach-Object { [IO.Path]::GetFullPath($_.FullName) } |
                Sort-Object
        )
    }
    $ActualRawResponseSet = [Collections.Generic.HashSet[string]]::new(
        $ActualRawResponsePaths,
        [StringComparer]::OrdinalIgnoreCase
    )
    [string[]]$OrphanRawResponsePaths = @(
        $ActualRawResponsePaths |
            Where-Object { -not $RawPaths.Contains($_) }
    )
    [string[]]$MissingRawResponsePaths = @(
        $RawPaths |
            Where-Object { -not $ActualRawResponseSet.Contains($_) } |
            Sort-Object
    )
    foreach ($OrphanRawResponsePath in $OrphanRawResponsePaths) {
        $Issues.Add("Unledgered MCP raw response exists: $OrphanRawResponsePath")
    }
    foreach ($MissingRawResponsePath in $MissingRawResponsePaths) {
        $Issues.Add("Ledger raw path is not a JSON-RPC response: $MissingRawResponsePath")
    }
    return [pscustomobject][ordered]@{
        green = $Issues.Count -eq 0
        response_count = $Rows.Count
        sequence_first = if ($Rows.Count -eq 0) { 0 } else { 1 }
        sequence_last = if ($Rows.Count -eq 0) { 0 } else { $Rows.Count }
        validated_success_count = $Rows.Count - $FailedSequences.Count
        failed_attempt_count = $FailedSequences.Count
        invoke_error_count = $InvokeErrorSequences.Count
        orphan_invoke_error_count = $OrphanInvokeErrorPaths.Count
        actual_raw_response_count = $ActualRawResponsePaths.Count
        ledger_raw_response_count = $RawPaths.Count
        orphan_raw_response_count = $OrphanRawResponsePaths.Count
        missing_raw_response_count = $MissingRawResponsePaths.Count
        raw_file_verified_count = $RawVerifiedCount
        orphan_invoke_error_paths = [object[]]$OrphanInvokeErrorPaths
        orphan_raw_response_paths = [object[]]$OrphanRawResponsePaths
        missing_raw_response_paths = [object[]]$MissingRawResponsePaths
        issues = [object[]]$Issues.ToArray()
    }
}

function Invoke-McpJson {
    param(
        [Parameter(Mandatory = $true)][string]$ToolName,
        [hashtable]$Arguments = @{},
        [string]$OutputImage = "",
        [ValidateRange(1, 600)][int]$TimeoutSeconds = 60
    )
    $InvocationStartedAtUtc = [DateTimeOffset]::UtcNow
    $InvocationStopwatch = [Diagnostics.Stopwatch]::StartNew()
    $script:McpRawSequence += 1
    $ToolSlug = [regex]::Replace($ToolName, "[^A-Za-z0-9_.-]", "_")
    $RawEvidencePath = Join-Path $McpRawEvidenceRoot (
        "{0:D4}-{1}.jsonrpc.json" -f $script:McpRawSequence, $ToolSlug
    )
    $InvokeErrorPath = Join-Path $McpRawEvidenceRoot (
        "{0:D4}-{1}.invoke-error.json" -f $script:McpRawSequence, $ToolSlug
    )
    $json = $Arguments | ConvertTo-Json -Depth 30 -Compress
    $ArgumentsSha256 = [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData(
            [Text.UTF8Encoding]::new($false).GetBytes($json)
        )
    ).ToLowerInvariant()
    $InvokeArguments = @(
        "-NoLogo", "-NoProfile", "-File", $Invoke,
        "-Worktree", $Worktree,
        "-ToolName", $ToolName,
        "-ArgumentsJson", $json,
        "-TimeoutSeconds", [string]$TimeoutSeconds,
        "-RawResponsePath", $RawEvidencePath,
        "-PassThroughToolErrors"
    )
    if ($OutputImage) {
        $InvokeArguments += @("-OutputImage", $OutputImage)
    }
    $InvokeOutput = @()
    $InvocationFailure = $null
    try {
        $InvokeOutput = @(& pwsh @InvokeArguments 2>&1)
        $InvokeExitCode = $LASTEXITCODE
    } catch {
        $InvocationFailure = $_
        $InvokeExitCode = -1
        $InvokeOutput = @($_ | Out-String)
    }
    $RawExists = Test-Path -LiteralPath $RawEvidencePath -PathType Leaf
    $InvokeErrorExists = $false
    if ($null -ne $InvocationFailure -or $InvokeExitCode -ne 0 -or -not $RawExists) {
        $InvokeError = [ordered]@{
            schema = "SpaceSyndicateMcpInvocationErrorV1"
            sequence = $script:McpRawSequence
            tool_name = $ToolName
            arguments_sha256 = $ArgumentsSha256
            failed_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
            invoke_exit_code = $InvokeExitCode
            invocation_failure = if ($null -eq $InvocationFailure) {
                $null
            } else {
                [string]$InvocationFailure
            }
            response_file_created = $RawExists
            child_output = @($InvokeOutput | ForEach-Object { [string]$_ })
        }
        Write-AtomicUtf8Json $InvokeErrorPath $InvokeError
        $InvokeErrorExists = $true
    }
    $RawBytes = if ($RawExists) {
        [IO.File]::ReadAllBytes($RawEvidencePath)
    } else {
        [byte[]]@()
    }
    $RawText = ""
    $RawDecodeFailure = $null
    if ($RawExists) {
        try {
            $RawText = [Text.UTF8Encoding]::new($false, $true).GetString($RawBytes)
        } catch {
            $RawDecodeFailure = $_
            if (-not $InvokeErrorExists) {
                Write-AtomicUtf8Json $InvokeErrorPath ([ordered]@{
                    schema = "SpaceSyndicateMcpInvocationErrorV1"
                    sequence = $script:McpRawSequence
                    tool_name = $ToolName
                    arguments_sha256 = $ArgumentsSha256
                    failed_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
                    invoke_exit_code = $InvokeExitCode
                    invocation_failure = "Raw HTTP response is not strict UTF-8: $_"
                    response_file_created = $true
                    child_output = @($InvokeOutput | ForEach-Object { [string]$_ })
                })
                $InvokeErrorExists = $true
            }
        }
    }
    $EvidenceRow = [pscustomobject]@{
        sequence = $script:McpRawSequence
        tool_name = $ToolName
        arguments = $Arguments
        arguments_sha256 = $ArgumentsSha256
        timeout_seconds = $TimeoutSeconds
        output_image = $OutputImage
        invoke_exit_code = $InvokeExitCode
        invocation_failure = $null -ne $InvocationFailure
        raw_wire_response_created = $RawExists
        raw_path = if ($RawExists) { $RawEvidencePath } else { $null }
        raw_sha256 = if ($RawExists) { Get-FileSha256 $RawEvidencePath } else { $null }
        raw_byte_count = $RawBytes.Length
        invoke_error_path = if ($InvokeErrorExists) { $InvokeErrorPath } else { $null }
        invoke_error_sha256 = if ($InvokeErrorExists) {
            Get-FileSha256 $InvokeErrorPath
        } else {
            $null
        }
        validation_succeeded = $false
        failure_stage = $null
        failure_message = $null
        started_at_utc = $InvocationStartedAtUtc.ToString("o")
        completed_at_utc = $null
        elapsed_msec = $null
    }
    $script:McpRawEvidence.Add($EvidenceRow)
    $ValidationStage = "raw_utf8"
    try {
        if ($null -ne $RawDecodeFailure) {
            throw "MCP raw HTTP response is not strict UTF-8 ($ToolName): $RawEvidencePath"
        }
        $ValidationStage = "invoke_process"
        if ($null -ne $InvocationFailure) {
            throw (
                "MCP invoke script threw before a JSON-RPC envelope could be parsed " +
                "($ToolName): error=$InvokeErrorPath detail=$InvocationFailure"
            )
        }
        if ($InvokeExitCode -ne 0) {
            throw "MCP invoke script failed ($ToolName): exit=$InvokeExitCode error=$InvokeErrorPath"
        }
        $ValidationStage = "raw_presence"
        if (-not $RawExists) {
            throw "MCP invoke produced no raw HTTP response ($ToolName): error=$InvokeErrorPath"
        }
        $ValidationStage = "raw_json"
        try {
            $response = $RawText | ConvertFrom-Json
        } catch {
            $ParseError = [ordered]@{
                schema = "SpaceSyndicateMcpInvocationErrorV1"
                sequence = $script:McpRawSequence
                tool_name = $ToolName
                arguments_sha256 = $ArgumentsSha256
                failed_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
                invoke_exit_code = $InvokeExitCode
                invocation_failure = "Raw HTTP response is not valid JSON: $_"
                response_file_created = $true
                child_output = @($InvokeOutput | ForEach-Object { [string]$_ })
            }
            Write-AtomicUtf8Json $InvokeErrorPath $ParseError
            $EvidenceRow.invoke_error_path = $InvokeErrorPath
            $EvidenceRow.invoke_error_sha256 = Get-FileSha256 $InvokeErrorPath
            throw "MCP raw HTTP response is not valid JSON ($ToolName): $RawEvidencePath"
        }
        $ValidationStage = "jsonrpc_identity"
        if ((Get-RequiredString $response "jsonrpc" "jsonrpc") -cne "2.0" `
            -or (Get-RequiredIntegralCount $response "id" "jsonrpc") -ne 1) {
            throw "MCP JSON-RPC envelope identity is invalid: $ToolName"
        }
        $ValidationStage = "jsonrpc_error"
        if ($null -ne $response.error) {
            throw ($response.error | ConvertTo-Json -Depth 20 -Compress)
        }
        $ValidationStage = "jsonrpc_result"
        $Result = Get-RequiredJsonObject $response "result" "jsonrpc"
        $ValidationStage = "tool_is_error"
        if (Get-RequiredBoolean $Result "isError" "jsonrpc.result") {
            $detail = if ($null -ne $response.result.structuredContent.error) {
                [string]$response.result.structuredContent.error
            } else {
                [string]$response.result.content[0].text
            }
            throw "MCP tool returned isError=true ($ToolName): $detail"
        }
        $Structured = $response.result.structuredContent
        if ($null -ne $Structured) {
            $SuccessProperty = $Structured.PSObject.Properties["success"]
            $ValidationStage = "structured_success_type"
            if ($null -ne $SuccessProperty `
                -and $SuccessProperty.Value -isnot [bool]) {
                throw "MCP structuredContent.success is not Boolean: $ToolName"
            }
            $ValidationStage = "structured_success_false"
            if ($null -ne $SuccessProperty -and -not $SuccessProperty.Value) {
                throw "MCP tool returned structuredContent.success=false: $ToolName"
            }
        }
        $EvidenceRow.validation_succeeded = $true
        $ValidationStage = "complete"
        return $response
    } catch {
        $EvidenceRow.failure_stage = $ValidationStage
        $EvidenceRow.failure_message = $_.Exception.Message
        throw
    } finally {
        $InvocationStopwatch.Stop()
        $EvidenceRow.completed_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
        $EvidenceRow.elapsed_msec = [Math]::Round(
            $InvocationStopwatch.Elapsed.TotalMilliseconds,
            3
        )
    }
}

function Get-RequiredJsonPropertyValue {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ObjectLabel
    )
    $Property = $Object.PSObject.Properties[$Name]
    if ($null -eq $Property -or $null -eq $Property.Value) {
        throw "Required JSON property is missing: $ObjectLabel.$Name"
    }
    return $Property.Value
}

function Get-RequiredIntegralCount {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ObjectLabel
    )
    $Value = Get-RequiredJsonPropertyValue $Object $Name $ObjectLabel
    $NumericTypes = @(
        [byte], [sbyte], [int16], [uint16], [int32], [uint32],
        [int64], [uint64], [single], [double], [decimal]
    )
    if ($Value.GetType() -notin $NumericTypes) {
        throw "Required count is not a JSON number: $ObjectLabel.$Name"
    }
    $Number = [double]$Value
    if ([double]::IsNaN($Number) `
        -or [double]::IsInfinity($Number) `
        -or [math]::Truncate($Number) -ne $Number `
        -or $Number -lt 0 `
        -or $Number -gt [int64]::MaxValue) {
        throw "Required count is not a nonnegative integer: $ObjectLabel.$Name"
    }
    return [int64]$Number
}

function Get-RequiredBoolean {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ObjectLabel
    )
    $Value = Get-RequiredJsonPropertyValue $Object $Name $ObjectLabel
    if ($Value -isnot [bool]) {
        throw "Required JSON property is not boolean: $ObjectLabel.$Name"
    }
    return [bool]$Value
}

function Get-RequiredString {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ObjectLabel,
        [switch]$AllowEmpty
    )
    $Value = Get-RequiredJsonPropertyValue $Object $Name $ObjectLabel
    if ($Value -isnot [string]) {
        throw "Required JSON property is not a string: $ObjectLabel.$Name"
    }
    if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace([string]$Value)) {
        throw "Required JSON string is empty: $ObjectLabel.$Name"
    }
    return [string]$Value
}

function Get-RequiredJsonObject {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ObjectLabel
    )
    $Value = Get-RequiredJsonPropertyValue $Object $Name $ObjectLabel
    if ($Value -isnot [pscustomobject] -and $Value -isnot [Collections.IDictionary]) {
        throw "Required JSON property is not an object: $ObjectLabel.$Name"
    }
    return $Value
}

function Assert-ExactJsonObjectKeys {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string[]]$ExpectedKeys,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $ExpectedSet = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($ExpectedKey in $ExpectedKeys) {
        if (-not $ExpectedSet.Add($ExpectedKey)) {
            throw "$Label expected-key contract contains a duplicate: $ExpectedKey"
        }
    }
    $ActualKeys = [string[]]@(
        $Object.PSObject.Properties | ForEach-Object { [string]$_.Name }
    )
    $UnexpectedKeys = [string[]]@(
        $ActualKeys | Where-Object { -not $ExpectedSet.Contains($_) }
    )
    $MissingKeys = [string[]]@(
        $ExpectedKeys | Where-Object { $ActualKeys -cnotcontains $_ }
    )
    if ($ActualKeys.Count -ne $ExpectedSet.Count `
        -or $UnexpectedKeys.Count -ne 0 `
        -or $MissingKeys.Count -ne 0) {
        throw (
            "$Label is not an exact closed JSON object: missing=[{0}] " +
            "unexpected=[{1}]" -f
            ($MissingKeys -join ","),
            ($UnexpectedKeys -join ",")
        )
    }
}

function Get-RequiredJsonArray {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ObjectLabel
    )
    $Property = $Object.PSObject.Properties[$Name]
    if ($null -eq $Property -or $null -eq $Property.Value) {
        throw "Required JSON property is missing: $ObjectLabel.$Name"
    }
    $Value = $Property.Value
    if ($Value -isnot [System.Array] -and $Value -isnot [Collections.IList]) {
        throw "Required JSON property is not an array: $ObjectLabel.$Name"
    }
    return ,$Value
}

function Get-RequiredFiniteNumber {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ObjectLabel
    )
    $Value = Get-RequiredJsonPropertyValue $Object $Name $ObjectLabel
    $NumericTypes = @(
        [byte], [sbyte], [int16], [uint16], [int32], [uint32],
        [int64], [uint64], [single], [double], [decimal]
    )
    if ($Value.GetType() -notin $NumericTypes) {
        throw "Required JSON property is not a number: $ObjectLabel.$Name"
    }
    $Number = [double]$Value
    if ([double]::IsNaN($Number) -or [double]::IsInfinity($Number)) {
        throw "Required JSON number is nonfinite: $ObjectLabel.$Name"
    }
    return $Number
}

$ProjectInfoResponse = Invoke-McpJson "get_project_info"
$ProjectInfoPayload = $ProjectInfoResponse.result.structuredContent
$ReportedProjectRoot = [IO.Path]::GetFullPath(
    (Get-RequiredString `
        $ProjectInfoPayload "project_root" "get_project_info").Replace("/", "\")
).TrimEnd("\")
if (-not $ReportedProjectRoot.Equals(
    $Worktree,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "MCP get_project_info belongs to another worktree."
}
$CapabilityResponse = Invoke-McpJson "get_capability_status"
$CapabilityPayload = $CapabilityResponse.result.structuredContent
$CapabilitySet = Get-RequiredJsonObject `
    $CapabilityPayload "capabilities" "get_capability_status"
$CapabilityProject = Get-RequiredJsonObject `
    $CapabilityPayload "project" "get_capability_status"
foreach ($CapabilityName in @(
    "mcp_server", "play_mode", "runtime_bridge_installed", "resources",
    "tool_registry"
)) {
    if (-not (Get-RequiredBoolean `
        $CapabilitySet $CapabilityName "get_capability_status.capabilities")) {
        throw "Required MCP capability is false: $CapabilityName"
    }
}
$InitialSceneOpen = Get-RequiredBoolean `
    $CapabilitySet "scene_open" "get_capability_status.capabilities"
"MCP_INITIAL_SCENE_OPEN_DIAGNOSTIC=$($InitialSceneOpen.ToString().ToLowerInvariant())"
if ((Get-RequiredIntegralCount `
        $CapabilityPayload "disabled_tool_count" "get_capability_status") -ne 0 `
    -or (Get-RequiredString `
        $CapabilityPayload "tool_profile" "get_capability_status") -cne "core" `
    -or (Get-RequiredString `
        $CapabilityProject "main_scene" "get_capability_status.project") `
        -cne "res://scenes/main.tscn" `
    -or -not ([IO.Path]::GetFullPath(
        (Get-RequiredString `
            $CapabilityProject "root" "get_capability_status.project").Replace("/", "\")
    ).TrimEnd("\")).Equals($Worktree, [StringComparison]::OrdinalIgnoreCase)) {
    throw "MCP capability status does not authorize the exact production validation path."
}
$ToolCatalogResponse = Invoke-McpJson "list_tool_catalog" @{
    profile = "core"
    include_hidden = $true
}
$ToolCatalog = $ToolCatalogResponse.result.structuredContent
$CatalogTools = Get-RequiredJsonArray $ToolCatalog "tools" "list_tool_catalog"
$CatalogToolCount = Get-RequiredIntegralCount `
    $ToolCatalog "tool_count" "list_tool_catalog"
$RequiredMcpTools = @(
    "get_project_info", "get_capability_status", "list_tool_catalog",
    "request_script_reload", "validate_script", "get_script_errors",
    "open_scene", "get_scene_info", "get_scene_tree", "file_exists",
    "read_file", "execute_code", "get_project_setting", "play_main_scene",
    "wait_msec", "get_play_state", "query_runtime_node",
    "send_runtime_input", "get_runtime_events", "capture_runtime_view",
    "get_console_logs", "exit_play_mode"
)
$CatalogToolNames = @($CatalogTools | ForEach-Object {
    Get-RequiredString $_ "name" "list_tool_catalog.tools[]"
})
$CatalogExposedNames = @($CatalogTools | Where-Object {
    Get-RequiredBoolean $_ "exposed" "list_tool_catalog.tools[]"
} | ForEach-Object { [string]$_.name })
if ((Get-RequiredString $ToolCatalog "profile" "list_tool_catalog") -cne "core" `
    -or $CatalogToolCount -ne $CatalogTools.Count `
    -or @($CatalogToolNames | Sort-Object -Unique).Count -ne $CatalogTools.Count `
    -or @(Compare-Object `
        -ReferenceObject @($RequiredMcpTools | Sort-Object) `
        -DifferenceObject @($CatalogExposedNames | Sort-Object) `
        -CaseSensitive | Where-Object SideIndicator -ceq "<=").Count -ne 0) {
    throw "MCP core tool catalog does not expose every tool required by this run."
}

# Funplay 0.9.6 can re-enter its HTTP poll loop when request_script_reload
# starts a filesystem scan before the editor's initial scan is quiescent. The
# exact run therefore waits beyond the observed cold-start window and then
# requires three independent non-scanning samples before issuing the reload.
$ReloadQuiescenceMinimumSeconds = 120
$ReloadQuiescenceStartedAt = [DateTimeOffset]::UtcNow
Start-Sleep -Seconds $ReloadQuiescenceMinimumSeconds
$ReloadScanDeadline = [DateTimeOffset]::UtcNow.AddSeconds(60)
$ReloadNonScanningSampleCount = 0
$ReloadReadinessResponses = [Collections.Generic.List[object]]::new()
do {
    $ReloadReadinessResponse = Invoke-McpJson "execute_code" @{
        code = @'
var filesystem = EditorInterface.get_resource_filesystem()
return {
    "filesystem_available": filesystem != null,
    "filesystem_scanning": true if filesystem == null else filesystem.is_scanning()
}
'@
        context_mode = "dictionary"
        include_metadata = $true
        safety_checks = $true
    }
    $ReloadReadinessResponses.Add($ReloadReadinessResponse)
    $ReloadReadinessResult = Get-RequiredJsonObject `
        $ReloadReadinessResponse.result.structuredContent `
        "result" `
        "reload readiness execute_code"
    $ReloadFilesystemAvailable = Get-RequiredBoolean `
        $ReloadReadinessResult `
        "filesystem_available" `
        "reload readiness execute_code.result"
    $ReloadFilesystemScanning = Get-RequiredBoolean `
        $ReloadReadinessResult `
        "filesystem_scanning" `
        "reload readiness execute_code.result"
    if ($ReloadFilesystemAvailable -and -not $ReloadFilesystemScanning) {
        $ReloadNonScanningSampleCount += 1
    } else {
        $ReloadNonScanningSampleCount = 0
    }
    if ($ReloadNonScanningSampleCount -lt 3) {
        Start-Sleep -Seconds 2
    }
} while (
    $ReloadNonScanningSampleCount -lt 3 `
        -and [DateTimeOffset]::UtcNow -lt $ReloadScanDeadline
)
if ($ReloadNonScanningSampleCount -ne 3) {
    throw "Godot resource filesystem did not become stably quiescent before reload."
}
$null = Invoke-McpJson "request_script_reload" @{ path = "res://" }
$ReloadQuiescenceElapsedSeconds = [Math]::Round(
    ([DateTimeOffset]::UtcNow - $ReloadQuiescenceStartedAt).TotalSeconds,
    3
)
"MCP_RELOAD_QUIESCENCE_SECONDS=$ReloadQuiescenceElapsedSeconds"
"MCP_RELOAD_NONSCANNING_SAMPLE_COUNT=$ReloadNonScanningSampleCount"
$ProjectInfoResponse | ConvertTo-Json -Depth 30
$CapabilityResponse | ConvertTo-Json -Depth 30
$ToolCatalogResponse | ConvertTo-Json -Depth 30
```

For every path in `$Scripts`, call `validate_script` with
`language=gdscript`. A valid result has `result.structuredContent.ok=true` and
zero diagnostics. `get_script_errors` is directory/project scoped in the
current Funplay build: passing a file path can return `checked=0` and must never
be counted as file coverage. Run one exact `res://` scope with a large enough
`max_files`, independently inventory every eligible project GDScript, and map
every changed script to that successful scope. For every path in `$Scenes`,
call `open_scene`, followed by `get_scene_info` and `get_scene_tree`; do not call
`save_scene`.

```powershell
$ProjectRoot = [IO.Path]::GetFullPath($Worktree).TrimEnd([char[]]@('\', '/'))
$ScriptResults = foreach ($Path in $Scripts) {
    $Response = Invoke-McpJson "validate_script" @{
        path = $Path
        language = "gdscript"
        run_build = $false
    } -TimeoutSeconds 180
    $Payload = $Response.result.structuredContent
    $ValidationSuccess = Get-RequiredBoolean $Payload "success" "validate_script"
    $ReturnedPath = Get-RequiredString $Payload "path" "validate_script"
    $ReturnedLanguage = Get-RequiredString $Payload "language" "validate_script"
    $ReturnedResourcePath = Get-RequiredString $Payload "resource_path" "validate_script"
    $ValidationMode = Get-RequiredString $Payload "validation_mode" "validate_script"
    $ReadOk = Get-RequiredBoolean $Payload "read_ok" "validate_script"
    $ValidationAttempted = Get-RequiredBoolean `
        $Payload "validation_attempted" "validate_script"
    $ValidatorProjectRoot = Get-RequiredString `
        $Payload "validator_project_root" "validate_script"
    $ValidatorProjectRootFull = [IO.Path]::GetFullPath($ValidatorProjectRoot).TrimEnd(
        [char[]]@('\', '/')
    )
    $ValidatorWorkerDiagnosticCount = Get-RequiredIntegralCount `
        $Payload "validator_worker_log_diagnostic_header_count" "validate_script"
    $ValidationOk = Get-RequiredBoolean $Payload "ok" "validate_script"
    $ErrorCode = Get-RequiredIntegralCount $Payload "error_code" "validate_script"
    $DiagnosticCount = Get-RequiredIntegralCount `
        $Payload "diagnostic_count" "validate_script"
    $Diagnostics = Get-RequiredJsonArray $Payload "diagnostics" "validate_script"
    [pscustomobject]@{
        path = $Path
        returned_path = $ReturnedPath
        returned_language = $ReturnedLanguage
        returned_resource_path = $ReturnedResourcePath
        validation_mode = $ValidationMode
        read_ok = $ReadOk
        validation_attempted = $ValidationAttempted
        validator_project_root = $ValidatorProjectRootFull
        validator_worker_diagnostic_count = $ValidatorWorkerDiagnosticCount
        ok = $ValidationSuccess `
            -and $ValidationOk `
            -and $ReturnedPath -ceq $Path `
            -and $ReturnedLanguage -ceq "gdscript" `
            -and $ReturnedResourcePath -ceq $Path `
            -and $ValidationMode -ceq "isolated_process" `
            -and $ReadOk `
            -and $ValidationAttempted `
            -and $ValidatorProjectRootFull -ceq $ProjectRoot `
            -and $ValidatorWorkerDiagnosticCount -eq 0 `
            -and $ErrorCode -eq 0 `
            -and $DiagnosticCount -eq 0 `
            -and $Diagnostics.Count -eq 0
        error_code = $ErrorCode
        diagnostic_count = $DiagnosticCount
        diagnostics = $Diagnostics
    }
}

$EligibleProjectScripts = @(
    Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File -Filter "*.gd" |
        ForEach-Object {
            $relative = [IO.Path]::GetRelativePath($ProjectRoot, $_.FullName).Replace("\", "/")
            "res://$relative"
        } |
        Sort-Object -Unique
)
$EligibleSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($Path in $EligibleProjectScripts) {
    $null = $EligibleSet.Add($Path)
}

$ProjectScriptErrorResponse = Invoke-McpJson "get_script_errors" @{
    path = "res://"
    language = "gdscript"
    max_files = 3000
    run_build = $false
} -TimeoutSeconds 180
$ProjectScriptErrorPayload = $ProjectScriptErrorResponse.result.structuredContent
$ProjectScriptSuccess = Get-RequiredBoolean `
    $ProjectScriptErrorPayload "success" "get_script_errors"
$ProjectScriptComplete = Get-RequiredBoolean `
    $ProjectScriptErrorPayload "complete" "get_script_errors"
$ProjectScriptScopeTruncated = Get-RequiredBoolean `
    $ProjectScriptErrorPayload "scope_truncated" "get_script_errors"
$ProjectScriptScanPath = Get-RequiredString `
    $ProjectScriptErrorPayload "path" "get_script_errors"
$ProjectScriptChecked = Get-RequiredIntegralCount `
    $ProjectScriptErrorPayload "checked" "get_script_errors"
$ProjectScriptRequested = Get-RequiredIntegralCount `
    $ProjectScriptErrorPayload "requested_count" "get_script_errors"
$ProjectScriptValidated = Get-RequiredIntegralCount `
    $ProjectScriptErrorPayload "validated_count" "get_script_errors"
$ProjectScriptMaxFiles = Get-RequiredIntegralCount `
    $ProjectScriptErrorPayload "max_files" "get_script_errors"
$ProjectScriptWorkerDiagnosticCount = Get-RequiredIntegralCount `
    $ProjectScriptErrorPayload `
    "validator_worker_log_diagnostic_header_count" `
    "get_script_errors"
$ProjectScriptErrorCount = Get-RequiredIntegralCount `
    $ProjectScriptErrorPayload "error_count" "get_script_errors"
$ProjectScriptErrors = Get-RequiredJsonArray `
    $ProjectScriptErrorPayload "errors" "get_script_errors"
if (-not $ProjectScriptSuccess `
    -or -not $ProjectScriptComplete `
    -or $ProjectScriptScopeTruncated `
    -or $ProjectScriptScanPath -cne "res://" `
    -or $ProjectScriptChecked -ne $EligibleProjectScripts.Count `
    -or $ProjectScriptRequested -ne $EligibleProjectScripts.Count `
    -or $ProjectScriptValidated -ne $EligibleProjectScripts.Count `
    -or $ProjectScriptMaxFiles -ne 3000 `
    -or $ProjectScriptWorkerDiagnosticCount -ne 0 `
    -or $ProjectScriptErrorCount -ne 0 `
    -or $ProjectScriptErrors.Count -ne 0) {
    throw (
        "Project script scan failed or was incomplete: path={0} checked={1}/{2} requested={3} validated={4} max_files={5} complete={6} worker_diagnostics={7} errors={8}" -f
        $ProjectScriptScanPath,
        $ProjectScriptChecked,
        $EligibleProjectScripts.Count,
        $ProjectScriptRequested,
        $ProjectScriptValidated,
        $ProjectScriptMaxFiles,
        $ProjectScriptComplete,
        $ProjectScriptWorkerDiagnosticCount,
        $ProjectScriptErrorCount
    )
}

$ScriptScopeCoverage = foreach ($Path in $Scripts) {
    $Eligible = $EligibleSet.Contains($Path)
    [pscustomobject]@{
        path = $Path
        scope = "res://"
        independently_eligible = $Eligible
        scope_checked = $ProjectScriptChecked
        scope_requested = $ProjectScriptRequested
        scope_validated = $ProjectScriptValidated
        scope_complete = $ProjectScriptComplete
        scope_truncated = $ProjectScriptScopeTruncated
        worker_diagnostic_count = $ProjectScriptWorkerDiagnosticCount
        scope_error_count = $ProjectScriptErrorCount
        covered = $Eligible `
            -and $ProjectScriptSuccess `
            -and $ProjectScriptComplete `
            -and -not $ProjectScriptScopeTruncated `
            -and $ProjectScriptChecked -eq $EligibleProjectScripts.Count `
            -and $ProjectScriptRequested -eq $EligibleProjectScripts.Count `
            -and $ProjectScriptValidated -eq $EligibleProjectScripts.Count `
            -and $ProjectScriptWorkerDiagnosticCount -eq 0 `
            -and $ProjectScriptErrorCount -eq 0
    }
}

$SceneResults = foreach ($Path in $Scenes) {
    $Open = Invoke-McpJson "open_scene" @{ path = $Path; set_inherited = $false }
    $OpenTextRows = @($Open.result.content | Where-Object { $_.type -ceq "text" })
    $OpenPassed = $Open.result.content.Count -eq 1 `
        -and $OpenTextRows.Count -eq 1 `
        -and [string]$OpenTextRows[0].text -ceq "Opened scene: $Path"
    $Info = Invoke-McpJson "get_scene_info"
    $Tree = Invoke-McpJson "get_scene_tree" @{ max_depth = 5 }
    $InfoPayload = $Info.result.structuredContent
    $TreePayload = $Tree.result.structuredContent
    $InfoPath = Get-RequiredString $InfoPayload "scene_path" "get_scene_info"
    $InfoRoot = Get-RequiredJsonObject $InfoPayload "scene_root" "get_scene_info"
    $InfoRootPath = Get-RequiredString `
        $InfoRoot "scene_file_path" "get_scene_info.scene_root"
    $InfoNodeCount = Get-RequiredIntegralCount `
        $InfoPayload "node_count" "get_scene_info"
    $TreePath = Get-RequiredString $TreePayload "scene_file_path" "get_scene_tree"
    $TreeName = Get-RequiredString $TreePayload "name" "get_scene_tree"
    $Passed = (
        $OpenPassed -and
        $InfoPath -ceq $Path -and
        $InfoRootPath -ceq $Path -and
        $InfoNodeCount -ge 1 -and
        $TreePath -ceq $Path -and
        -not [string]::IsNullOrWhiteSpace($TreeName)
    )
    [pscustomobject]@{
        path = $Path
        passed = $Passed
        open = $Open
        info = $Info
        tree = $Tree
    }
}

$ScriptResults | Format-Table -AutoSize
$ScriptPassed = @(
    $ScriptResults | Where-Object { $_.ok -and $_.diagnostic_count -eq 0 }
).Count
if ($ScriptResults.Count -ne $Scripts.Count -or $ScriptPassed -ne $Scripts.Count) {
    throw "One or more changed scripts failed MCP validation."
}
$ScriptScopeCovered = @($ScriptScopeCoverage | Where-Object covered).Count
if ($ScriptScopeCoverage.Count -ne $Scripts.Count `
    -or $ScriptScopeCovered -ne $Scripts.Count) {
    throw "Changed-script project-scope coverage is incomplete."
}
if ($SceneResults.Count -ne $Scenes.Count `
    -or @($SceneResults | Where-Object { -not $_.passed }).Count -ne 0) {
    throw "One or more changed scenes failed exact path/tree validation."
}
"MCP_CHANGED_SCRIPT_VALIDATION=$ScriptPassed/$($Scripts.Count)"
"MCP_SCRIPT_ERROR_SCOPE_COVERAGE=$ScriptScopeCovered/$($Scripts.Count)"
"MCP_PROJECT_SCRIPT_CHECKED=$ProjectScriptChecked/$($EligibleProjectScripts.Count)"
"MCP_PROJECT_SCRIPT_REQUESTED=$ProjectScriptRequested/$($EligibleProjectScripts.Count)"
"MCP_PROJECT_SCRIPT_VALIDATED=$ProjectScriptValidated/$($EligibleProjectScripts.Count)"
"MCP_PROJECT_SCRIPT_MAX_FILES=$ProjectScriptMaxFiles"
"MCP_PROJECT_SCRIPT_VALIDATION_COMPLETE=$($ProjectScriptComplete.ToString().ToLowerInvariant())"
"MCP_PROJECT_SCRIPT_SCOPE_TRUNCATED=$($ProjectScriptScopeTruncated.ToString().ToLowerInvariant())"
"MCP_PROJECT_SCRIPT_WORKER_DIAGNOSTIC_COUNT=$ProjectScriptWorkerDiagnosticCount"
"MCP_PROJECT_SCRIPT_ERROR_COUNT=$ProjectScriptErrorCount"
"MCP_CHANGED_SCENE_LOAD=$(@($SceneResults | Where-Object passed).Count)/$($Scenes.Count)"
```

There is no separate core `load_resource` tool. Split the denominator by
format: JSON must exist and parse with `JSON.parse`, while Godot resource kinds
must pass `ResourceLoader.exists/load`. Do not claim that a JSON document was
loaded by `ResourceLoader`. `execute_code` wraps a snippet as a function body,
so the expression must be returned directly; a top-level `var` snippet is not
accepted by the current compiler wrapper.

```powershell
$JsonResources = @($Resources | Where-Object { $_ -match '\.json$' })
$GodotResources = @($Resources | Where-Object { $_ -notmatch '\.json$' })
$JsonRows = @(
    foreach ($Path in $JsonResources) {
        $ExistsResponse = Invoke-McpJson "file_exists" @{ path = $Path }
        $ExistsPayload = $ExistsResponse.result.structuredContent
        $ReturnedExistsPath = Get-RequiredString `
            $ExistsPayload "path" "file_exists"
        $Exists = Get-RequiredBoolean $ExistsPayload "exists" "file_exists"
        if ($ReturnedExistsPath -cne $Path -or -not $Exists) {
            throw "Changed JSON does not exist at its exact requested path: $Path"
        }

        $ReadResponse = Invoke-McpJson "read_file" @{
            path = $Path
            max_chars = 500000
        }
        $ReadPayload = $ReadResponse.result.structuredContent
        $ReturnedReadPath = Get-RequiredString $ReadPayload "path" "read_file"
        $Content = Get-RequiredString $ReadPayload "content" "read_file" -AllowEmpty
        if ($ReturnedReadPath -cne $Path `
            -or $Content.EndsWith("`n...[truncated]", [StringComparison]::Ordinal)) {
            throw "Changed JSON read was truncated or returned the wrong path: $Path"
        }
        $RelativePath = $Path.Substring("res://".Length)
        $AbsolutePath = Resolve-WorktreeChildPath $RelativePath
        $LocalContent = [IO.File]::ReadAllText(
            $AbsolutePath,
            [Text.UTF8Encoding]::new($false, $true)
        )
        if ($Content -cne $LocalContent) {
            throw "MCP read_file content differs from the exact worktree file: $Path"
        }
        try {
            $Parsed = $Content | ConvertFrom-Json -Depth 100
        } catch {
            throw "Changed JSON parse failed ($Path): $_"
        }
        $RootType = if ($null -eq $Parsed) {
            "Null"
        } elseif ($Parsed -is [pscustomobject] -or $Parsed -is [Collections.IDictionary]) {
            "Object"
        } elseif ($Parsed -is [System.Array] -or $Parsed -is [Collections.IList]) {
            "Array"
        } elseif ($Parsed -is [string]) {
            "String"
        } elseif ($Parsed -is [bool]) {
            "Boolean"
        } else {
            "Number"
        }
        $ContentBytes = [Text.UTF8Encoding]::new($false).GetBytes($Content)
        [pscustomobject]@{
            path = $Path
            returned_exists_path = $ReturnedExistsPath
            returned_read_path = $ReturnedReadPath
            validation_kind = "json_file_exists_read_file_parse"
            extension = ".json"
            exists = $Exists
            read_complete = $true
            parsed = $true
            parsed_root_type = $RootType
            content_byte_count = $ContentBytes.Length
            content_sha256 = [Convert]::ToHexString(
                [Security.Cryptography.SHA256]::HashData($ContentBytes)
            ).ToLowerInvariant()
            worktree_file_sha256 = Get-FileSha256 $AbsolutePath
        }
    }
)
$GodotRows = @()
if ($GodotResources.Count -gt 0) {
    $GodotExpressions = foreach ($Path in $GodotResources) {
        '{"path":"' + $Path + '","validation_kind":"resource_loader","extension":"' +
            [IO.Path]::GetExtension($Path).ToLowerInvariant() +
            '","resource_type":ResourceLoader.get_resource_type("' + $Path +
            '"),"exists":ResourceLoader.exists("' + $Path +
            '"),"loadable":ResourceLoader.load("' + $Path + '") != null,' +
            '"loaded_class":ResourceLoader.load("' + $Path +
            '").get_class() if ResourceLoader.load("' + $Path + '") != null else ""}'
    }
    $ResourceCode = 'return {"godot_resources":[' +
        ($GodotExpressions -join ",") + ']}'
    $ResourceMcpResult = Invoke-McpJson "execute_code" @{
        code = $ResourceCode
        context_mode = "dictionary"
        safety_checks = $true
    }
    $ResourcePayload = $ResourceMcpResult.result.structuredContent.result
    if ($ResourcePayload -is [string]) {
        $ResourcePayload = $ResourcePayload | ConvertFrom-Json
    }
    $GodotRows = @($ResourcePayload.godot_resources)
}
$JsonPassed = @($JsonRows | Where-Object {
    $_.validation_kind -ceq "json_file_exists_read_file_parse" `
        -and $_.extension -ceq ".json" `
        -and $_.exists -is [bool] -and $_.exists `
        -and $_.read_complete -is [bool] -and $_.read_complete `
        -and $_.parsed -is [bool] -and $_.parsed `
        -and -not [string]::IsNullOrWhiteSpace([string]$_.parsed_root_type) `
        -and [int64]$_.content_byte_count -gt 0 `
        -and [string]$_.content_sha256 -match '\A[a-f0-9]{64}\z'
}).Count
$GodotPassed = @($GodotRows | Where-Object {
    (Get-RequiredString $_ "validation_kind" "resource_loader.row") `
            -ceq "resource_loader" `
        -and -not [string]::IsNullOrWhiteSpace(
            (Get-RequiredString $_ "extension" "resource_loader.row")
        ) `
        -and -not [string]::IsNullOrWhiteSpace(
            (Get-RequiredString $_ "resource_type" "resource_loader.row")
        ) `
        -and -not [string]::IsNullOrWhiteSpace(
            (Get-RequiredString $_ "loaded_class" "resource_loader.row")
        ) `
        -and (Get-RequiredBoolean $_ "exists" "resource_loader.row") `
        -and (Get-RequiredBoolean $_ "loadable" "resource_loader.row")
}).Count
$ReturnedResourcePaths = @(
    @($JsonRows + $GodotRows) | ForEach-Object { [string]$_.path }
)
if (@($ReturnedResourcePaths | Sort-Object -Unique).Count -ne $Resources.Count `
    -or @(Compare-Object `
        -ReferenceObject @($Resources | Sort-Object) `
        -DifferenceObject @($ReturnedResourcePaths | Sort-Object) `
        -CaseSensitive).Count -ne 0) {
    throw "Changed resource response paths do not exactly match the requested manifest."
}
if ($JsonRows.Count -ne $JsonResources.Count -or $JsonPassed -ne $JsonResources.Count) {
    throw "Changed JSON validation failed: $JsonPassed/$($JsonResources.Count)"
}
if ($GodotRows.Count -ne $GodotResources.Count -or $GodotPassed -ne $GodotResources.Count) {
    throw "Changed ResourceLoader-kind validation failed: $GodotPassed/$($GodotResources.Count)"
}
$ChangedResourcePassed = $JsonPassed + $GodotPassed
if ($ChangedResourcePassed -ne $Resources.Count) {
    throw "Changed resource validation failed: $ChangedResourcePassed/$($Resources.Count)"
}
"MCP_CHANGED_RESOURCE_VALIDATION=$ChangedResourcePassed/$($Resources.Count)"
"MCP_CHANGED_JSON_FILE_EXISTS_READ_PARSE=$JsonPassed/$($JsonResources.Count)"
"MCP_CHANGED_RESOURCELOADER_KIND=$GodotPassed/$($GodotResources.Count)"
$ResourceEvidence = [ordered]@{
    schema = "SpaceSyndicateExactShaChangedResourceEvidenceV1"
    requested_count = $Resources.Count
    returned_count = $ReturnedResourcePaths.Count
    json_count = $JsonRows.Count
    resource_loader_count = $GodotRows.Count
    rows = @($JsonRows + $GodotRows)
}
$ResourceEvidencePath = Join-Path $ValidationEvidenceRoot "changed-resource-evidence.json"
Write-AtomicUtf8Json $ResourceEvidencePath $ResourceEvidence
$ResourceEvidenceSha256 = Get-FileSha256 $ResourceEvidencePath
"MCP_CHANGED_RESOURCE_EVIDENCE_SHA256=$ResourceEvidenceSha256"
```

Record all three values separately: changed-resource validation, JSON parse,
and ResourceLoader-kind load. A PR whose changed resources are all JSON has a
valid ResourceLoader-kind denominator of `0/0`, not a fabricated `N/N`.

The project setting API key for the configured main scene is
`application/run/main_scene` (the file itself contains
`run/main_scene` under the `[application]` section). The probe uses the API
key, then checks that the value is `res://scenes/main.tscn`.

The headless probe remains the authoritative static-manifest pass because it
parses changed JSON and checks the main scene and V0.7.5 read-only
dependencies without instantiating gameplay. It cannot replace the live UI
action/receipt/consumption gate below.

## Main Sample And Runtime Evidence

Open and inspect the configured main scene, then run it through the real editor
bridge. The main scene is a production sample check, not a mock Bench check.
Funplay `get_play_state.current_scene_path` currently reflects
`EditorInterface.get_current_path()`, not the child process's
`SceneTree.current_scene.scene_file_path`. Therefore `res://` is a known
semantic limitation only when the project setting and independently queried
live runtime identity are all exact; it is never accepted by itself:

```powershell
$MainOpen = Invoke-McpJson "open_scene" @{ path = "res://scenes/main.tscn" }
$MainOpenTextRows = @(
    $MainOpen.result.content | Where-Object { $_.type -ceq "text" }
)
if ($MainOpen.result.content.Count -ne 1 `
    -or $MainOpenTextRows.Count -ne 1 `
    -or [string]$MainOpenTextRows[0].text -cne "Opened scene: res://scenes/main.tscn") {
    throw "Configured main scene open result did not identify the exact requested path."
}
$MainInfo = Invoke-McpJson "get_scene_info"
$MainTree = Invoke-McpJson "get_scene_tree" @{ max_depth = 6 }
if ([string]$MainInfo.result.structuredContent.scene_path -cne "res://scenes/main.tscn" `
    -or [string]$MainTree.result.structuredContent.scene_file_path -cne "res://scenes/main.tscn") {
    throw "Configured main scene did not open as the exact production scene."
}
$MainSceneSettingResponse = Invoke-McpJson "get_project_setting" @{
    key = "application/run/main_scene"
}
$MainSceneSetting = $MainSceneSettingResponse.result.structuredContent
if ([string]$MainSceneSetting.key -cne "application/run/main_scene" `
    -or [string]$MainSceneSetting.value -cne "res://scenes/main.tscn") {
    throw "ProjectSettings main scene is not the exact production main scene."
}
$RoleLocalStateRoot = [IO.Path]::GetFullPath(
    (Join-Path $Worktree ".codex-godot")
).TrimEnd("\") + [IO.Path]::DirectorySeparatorChar
$RuntimeLogPath = [IO.Path]::GetFullPath(
    (Join-Path `
        $Worktree `
        ".codex-godot\appdata-roaming\Godot\app_userdata\太空辛迪加\logs\godot.log")
)
if (-not $RuntimeLogPath.StartsWith(
    $RoleLocalStateRoot,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Expected runtime console path escaped the launched role's isolated state."
}
$ArchivedRuntimeLogSha256 = ""
if (Test-Path -LiteralPath $RuntimeLogPath -PathType Leaf) {
    $ArchivedRuntimeLogSha256 = Get-FileSha256 $RuntimeLogPath
    $ArchivedRuntimeLogPath = Join-Path `
        $ValidationEvidenceRoot `
        "preexisting-runtime-godot.log"
    if (Test-Path -LiteralPath $ArchivedRuntimeLogPath) {
        throw "Preexisting runtime log archive already exists."
    }
    [IO.File]::Copy($RuntimeLogPath, $ArchivedRuntimeLogPath, $false)
    if ((Get-FileSha256 $ArchivedRuntimeLogPath) -cne $ArchivedRuntimeLogSha256) {
        throw "Preexisting runtime log archive failed hash verification."
    }
    Remove-Item -LiteralPath $RuntimeLogPath -Force
    if (Test-Path -LiteralPath $RuntimeLogPath) {
        throw "Preexisting role-local runtime log could not be cleared."
    }
}
$PlayRequestUtc = [DateTimeOffset]::UtcNow
$ConsoleEpochIdentity = "{0}|{1}|{2}" -f @(
    [int]$LaunchResult.pid,
    $PlayRequestUtc.ToString("o"),
    $RuntimeLogPath.ToLowerInvariant()
)
$ConsoleEpochSha256 = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
        [Text.UTF8Encoding]::new($false).GetBytes($ConsoleEpochIdentity)
    )
).ToLowerInvariant()
$null = Invoke-McpJson "play_main_scene"
$null = Invoke-McpJson "wait_msec" @{ duration = 2000 }
$State = Invoke-McpJson "get_play_state"
$Events = Invoke-McpJson "get_runtime_events" @{ max_events = 200; timeout_msec = 10000 }
$StatePayload = $State.result.structuredContent
$EventsPayload = $Events.result.structuredContent
$EventResult = Get-RequiredJsonObject $EventsPayload "result" "get_runtime_events"
if (-not (Get-RequiredBoolean $StatePayload "is_playing_scene" "get_play_state")) {
    throw "Production play mode did not start."
}
$RawCurrentScenePath = Get-RequiredString `
    $StatePayload "current_scene_path" "get_play_state"
$CurrentScenePathSemanticLimitation = $RawCurrentScenePath -ceq "res://"
if (-not $CurrentScenePathSemanticLimitation `
    -and $RawCurrentScenePath -cne "res://scenes/main.tscn") {
    throw "Unexpected get_play_state current_scene_path: $RawCurrentScenePath"
}
$InitialRuntimeEvents = Get-RequiredJsonArray `
    $EventResult "events" "get_runtime_events.result"
$ReadyEvents = @($InitialRuntimeEvents | Where-Object {
    (Get-RequiredString $_ "kind" "get_runtime_events.result.events[]") -ceq "ready"
})
if (-not (Get-RequiredBoolean $EventsPayload "success" "get_runtime_events") `
    -or (Get-RequiredIntegralCount `
        $EventResult "returned_event_count" "get_runtime_events.result") -lt 1 `
    -or $ReadyEvents.Count -lt 1) {
    throw "Runtime bridge did not provide a production ready event."
}

function Get-LiveRuntimeNodeResult {
    param(
        [Parameter(Mandatory = $true)][string]$NodePath,
        [Parameter(Mandatory = $true)][string]$Label,
        [string[]]$Properties = @(),
        [int]$TimeoutSeconds = 60
    )
    $TimeoutBudget = Get-McpRuntimeQueryTimeoutBudget `
        -RequestedSeconds $TimeoutSeconds
    $Response = Invoke-McpJson "query_runtime_node" @{
        node_path = $NodePath
        properties = @($Properties)
        include_children = $false
        timeout_msec = $TimeoutBudget.bridge_timeout_msec
    } -TimeoutSeconds $TimeoutBudget.transport_timeout_seconds
    $Payload = $Response.result.structuredContent
    $Result = Get-RequiredJsonObject $Payload "result" "query_runtime_node"
    if (-not (Get-RequiredBoolean $Payload "success" "query_runtime_node") `
        -or -not (Get-RequiredBoolean $Result "found" "query_runtime_node.result")) {
        throw "Live runtime node was not found: $Label ($NodePath)"
    }
    $ExpectedAbsolutePath = if ($NodePath -ceq "current_scene") {
        "/root/Main"
    } else {
        "/root/Main/$NodePath"
    }
    if ((Get-RequiredString $Result "path" "query_runtime_node.result") `
        -cne $ExpectedAbsolutePath) {
        throw "Live runtime node path mismatch: $Label ($NodePath)"
    }
    return $Result
}

$LiveRoot = Get-LiveRuntimeNodeResult `
    -NodePath "current_scene" `
    -Label "production root"
if ((Get-RequiredString $LiveRoot "name" "query_runtime_node.production_root") `
        -cne "Main" `
    -or (Get-RequiredString $LiveRoot "type" "query_runtime_node.production_root") `
        -cne "Control" `
    -or (Get-RequiredString `
        $LiveRoot "scene_file_path" "query_runtime_node.production_root") `
        -cne "res://scenes/main.tscn" `
    -or (Get-RequiredString `
        $LiveRoot "script_path" "query_runtime_node.production_root") `
        -cne "res://scripts/v075_runtime/v075_application_bootstrap.gd") {
    throw "Live runtime root is not the exact V0.7.5 production main scene."
}
$LiveRootProperties = Get-RequiredJsonObject `
    $LiveRoot "properties" "query_runtime_node.production_root"
$LiveRootPosition = Get-RequiredJsonObject `
    $LiveRootProperties "global_position" "query_runtime_node.production_root.properties"
$LiveRootSize = Get-RequiredJsonObject `
    $LiveRootProperties "size" "query_runtime_node.production_root.properties"

$RequiredLiveNodes = @(
    [pscustomobject]@{
        path = "V075RuntimeComposition"
        name = "V075RuntimeComposition"
        scene = "res://scenes/runtime/V075RuntimeComposition.tscn"
        script = "res://scripts/v075_runtime/v075_application_flow.gd"
    },
    [pscustomobject]@{
        path = "V075GameScreen"
        name = "V075GameScreen"
        scene = "res://scenes/ui/v075/V075SampleGameScreen.tscn"
        script = "res://scripts/ui/v075/v075_sample_game_screen.gd"
    },
    [pscustomobject]@{
        path = "V075GameScreen/RootMargin/Shell/V075CombatStackHost/V075CombatOverlay/Margin/Rows/SurfaceHost/CombatSurface"
        name = "CombatSurface"
        scene = "res://scenes/ui/v075/V075CombatPlayerSurface.tscn"
        script = "res://scripts/ui/v075/v075_combat_player_surface.gd"
    }
)
foreach ($ExpectedNode in $RequiredLiveNodes) {
    $LiveNode = Get-LiveRuntimeNodeResult `
        -NodePath $ExpectedNode.path `
        -Label $ExpectedNode.name
    if ((Get-RequiredString $LiveNode "name" "query_runtime_node.required") `
            -cne $ExpectedNode.name `
        -or (Get-RequiredString `
            $LiveNode "scene_file_path" "query_runtime_node.required") `
            -cne $ExpectedNode.scene `
        -or (Get-RequiredString `
            $LiveNode "script_path" "query_runtime_node.required") `
            -cne $ExpectedNode.script) {
        throw "Live runtime production node identity mismatch: $($ExpectedNode.name)"
    }
}

"MCP_GET_PLAY_STATE_CURRENT_SCENE_PATH=$RawCurrentScenePath"
"MCP_CURRENT_SCENE_PATH_SEMANTIC_LIMITATION=$($CurrentScenePathSemanticLimitation.ToString().ToLowerInvariant())"
"MCP_LIVE_RUNTIME_MAIN_IDENTITY_GREEN=true"
```

Perform a real child-runtime UI path next. `simulate_mouse_button` runs in the
editor process and is not accepted as gameplay evidence. Query each production
button's live geometry, then send a mouse tap through `send_runtime_input`.
The required chain starts with the real configured-new-game button, then uses a
bounded sequence of the real submission-lock and finish-maintenance buttons
until the production settlement overlay appears. For every action, read the
authoritative application receipt and the screen's public `acceptance_state`
after the UI consumed that receipt; the sanity-only accelerate button is not
part of this probe:

```powershell
function Invoke-LiveRuntimeButtonTap {
    param(
        [Parameter(Mandatory = $true)][string]$NodePath,
        [Parameter(Mandatory = $true)][string]$Label,
        [string]$RequiredClipNodePath = "",
        [int]$TimeoutSeconds = 60
    )
    $Button = Get-LiveRuntimeNodeResult `
        -NodePath $NodePath `
        -Label $Label `
        -Properties @("disabled") `
        -TimeoutSeconds $TimeoutSeconds
    $ButtonProperties = Get-RequiredJsonObject `
        $Button "properties" "query_runtime_node.button"
    $ButtonRequested = Get-RequiredJsonObject `
        $Button "requested_properties" "query_runtime_node.button"
    $ButtonSize = Get-RequiredJsonObject `
        $ButtonProperties "size" "query_runtime_node.button.properties"
    $ButtonGlobalPosition = Get-RequiredJsonObject `
        $ButtonProperties "global_position" "query_runtime_node.button.properties"
    $ExpectedButtonName = ($NodePath -split "/")[-1]
    if ((Get-RequiredString $Button "name" "query_runtime_node.button") `
            -cne $ExpectedButtonName `
        -or (Get-RequiredString $Button "type" "query_runtime_node.button") `
            -cne "Button") {
        throw "Production UI button identity is invalid: $Label"
    }
    $Visible = Get-RequiredBoolean `
        $ButtonProperties "visible" "query_runtime_node.button.properties"
    $Disabled = Get-RequiredBoolean `
        $ButtonRequested "disabled" "query_runtime_node.button.requested_properties"
    $Width = Get-RequiredFiniteNumber `
        $ButtonSize "x" "query_runtime_node.button.properties.size"
    $Height = Get-RequiredFiniteNumber `
        $ButtonSize "y" "query_runtime_node.button.properties.size"
    if (-not $Visible -or $Disabled -or $Width -le 0 -or $Height -le 0) {
        throw "Production UI button is not actionable: $Label"
    }
    $Center = @{
        x = (Get-RequiredFiniteNumber `
            $ButtonGlobalPosition "x" "query_runtime_node.button.properties.global_position") `
            + ($Width / 2.0)
        y = (Get-RequiredFiniteNumber `
            $ButtonGlobalPosition "y" "query_runtime_node.button.properties.global_position") `
            + ($Height / 2.0)
    }
    $RootLeft = Get-RequiredFiniteNumber `
        $LiveRootPosition "x" "query_runtime_node.production_root.properties.global_position"
    $RootTop = Get-RequiredFiniteNumber `
        $LiveRootPosition "y" "query_runtime_node.production_root.properties.global_position"
    $RootRight = $RootLeft + (Get-RequiredFiniteNumber `
        $LiveRootSize "x" "query_runtime_node.production_root.properties.size")
    $RootBottom = $RootTop + (Get-RequiredFiniteNumber `
        $LiveRootSize "y" "query_runtime_node.production_root.properties.size")
    if ($Center.x -lt $RootLeft `
        -or $Center.x -ge $RootRight `
        -or $Center.y -lt $RootTop `
        -or $Center.y -ge $RootBottom) {
        throw "Production UI button center is outside the live viewport: $Label"
    }
    if (-not [string]::IsNullOrWhiteSpace($RequiredClipNodePath)) {
        $Clip = Get-LiveRuntimeNodeResult `
            -NodePath $RequiredClipNodePath `
            -Label "$Label interaction clip" `
            -TimeoutSeconds $TimeoutSeconds
        if ((Get-RequiredString $Clip "type" "query_runtime_node.interaction_clip") `
            -cne "ScrollContainer") {
            throw "Production UI interaction clip is not a ScrollContainer: $Label"
        }
        $ClipProperties = Get-RequiredJsonObject `
            $Clip "properties" "query_runtime_node.interaction_clip"
        $ClipPosition = Get-RequiredJsonObject `
            $ClipProperties "global_position" "query_runtime_node.interaction_clip.properties"
        $ClipSize = Get-RequiredJsonObject `
            $ClipProperties "size" "query_runtime_node.interaction_clip.properties"
        $ButtonLeft = Get-RequiredFiniteNumber `
            $ButtonGlobalPosition "x" "query_runtime_node.button.properties.global_position"
        $ButtonTop = Get-RequiredFiniteNumber `
            $ButtonGlobalPosition "y" "query_runtime_node.button.properties.global_position"
        $ButtonRight = $ButtonLeft + $Width
        $ButtonBottom = $ButtonTop + $Height
        $ClipLeft = Get-RequiredFiniteNumber `
            $ClipPosition "x" "query_runtime_node.interaction_clip.properties.global_position"
        $ClipTop = Get-RequiredFiniteNumber `
            $ClipPosition "y" "query_runtime_node.interaction_clip.properties.global_position"
        $ClipRight = $ClipLeft + (Get-RequiredFiniteNumber `
            $ClipSize "x" "query_runtime_node.interaction_clip.properties.size")
        $ClipBottom = $ClipTop + (Get-RequiredFiniteNumber `
            $ClipSize "y" "query_runtime_node.interaction_clip.properties.size")
        if ($ButtonLeft -lt $ClipLeft `
            -or $ButtonTop -lt $ClipTop `
            -or $ButtonRight -gt $ClipRight `
            -or $ButtonBottom -gt $ClipBottom) {
            throw "Production UI button is not fully inside its interaction clip: $Label"
        }
    }
    $InputResponse = Invoke-McpJson "send_runtime_input" @{
        events = @(@{
            type = "mouse_button"
            button = "left"
            position = $Center
            mode = "tap"
        })
        timeout_msec = $TimeoutSeconds * 1000
    } -TimeoutSeconds $TimeoutSeconds
    $InputPayload = $InputResponse.result.structuredContent
    $InputResult = Get-RequiredJsonObject $InputPayload "result" "send_runtime_input"
    $Rows = Get-RequiredJsonArray $InputResult "results" "send_runtime_input.result"
    if (-not (Get-RequiredBoolean $InputPayload "success" "send_runtime_input") `
        -or (Get-RequiredIntegralCount `
            $InputResult "event_count" "send_runtime_input.result") -ne 1 `
        -or $Rows.Count -ne 1 `
        -or -not (Get-RequiredBoolean `
            $Rows[0] "success" "send_runtime_input.result.results[0]")) {
        throw "Child-runtime input did not deliver one successful tap: $Label"
    }
    return [pscustomobject]@{
        label = $Label
        node_path = $NodePath
        center = $Center
        input = $InputResponse
    }
}

function Get-LiveRuntimeProperty {
    param(
        [Parameter(Mandatory = $true)][string]$NodePath,
        [Parameter(Mandatory = $true)][string]$PropertyName,
        [Parameter(Mandatory = $true)][string]$Label,
        [int]$TimeoutSeconds = 60
    )
    $Node = Get-LiveRuntimeNodeResult `
        -NodePath $NodePath `
        -Label $Label `
        -Properties @($PropertyName) `
        -TimeoutSeconds $TimeoutSeconds
    $Property = $Node.requested_properties.PSObject.Properties[$PropertyName]
    if ($null -eq $Property -or $null -eq $Property.Value) {
        throw "Live runtime property was not returned: $Label.$PropertyName"
    }
    return $Property.Value
}

function Wait-LiveRuntimeReceipt {
    param(
        [Parameter(Mandatory = $true)][string]$ExpectedIntentKind,
        [string]$PreviousIntentId = "",
        [int]$TimeoutSeconds = 60
    )
    $Deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $Receipt = Get-LiveRuntimeProperty `
            -NodePath "V075RuntimeComposition" `
            -PropertyName "_last_receipt" `
            -Label "V075RuntimeComposition" `
            -TimeoutSeconds ([Math]::Min(15, $TimeoutSeconds))
        $IntentKind = [string]$Receipt.intent_kind
        $IntentId = [string]$Receipt.intent_id
        if ($IntentKind -ceq $ExpectedIntentKind `
            -and -not [string]::IsNullOrWhiteSpace($IntentId) `
            -and ([string]::IsNullOrEmpty($PreviousIntentId) `
                -or $IntentId -cne $PreviousIntentId)) {
            return $Receipt
        }
        $null = Invoke-McpJson "wait_msec" @{ duration = 250 }
    } while ([DateTimeOffset]::UtcNow -lt $Deadline)
    throw (
        "Timed out waiting for new authoritative receipt: {0}; previous={1}" -f
        $ExpectedIntentKind,
        $PreviousIntentId
    )
}

function Get-LiveRuntimeButtonActionState {
    param(
        [Parameter(Mandatory = $true)][string]$NodePath,
        [Parameter(Mandatory = $true)][string]$Label,
        [int]$TimeoutSeconds = 30
    )
    $Button = Get-LiveRuntimeNodeResult `
        -NodePath $NodePath `
        -Label $Label `
        -Properties @("disabled") `
        -TimeoutSeconds $TimeoutSeconds
    if ((Get-RequiredString $Button "name" "button_state") `
            -cne (($NodePath -split "/")[-1]) `
        -or (Get-RequiredString $Button "type" "button_state") -cne "Button") {
        throw "Production button identity mismatch: $Label"
    }
    $Properties = Get-RequiredJsonObject `
        $Button "properties" "button_state"
    $Requested = Get-RequiredJsonObject `
        $Button "requested_properties" "button_state"
    $Size = Get-RequiredJsonObject `
        $Properties "size" "button_state.properties"
    $Visible = Get-RequiredBoolean `
        $Properties "visible" "button_state.properties"
    $Disabled = Get-RequiredBoolean `
        $Requested "disabled" "button_state.requested_properties"
    $Width = Get-RequiredFiniteNumber `
        $Size "x" "button_state.properties.size"
    $Height = Get-RequiredFiniteNumber `
        $Size "y" "button_state.properties.size"
    return [pscustomobject][ordered]@{
        actionable = $Visible -and -not $Disabled `
            -and $Width -gt 0 -and $Height -gt 0
        visible = $Visible
        disabled = $Disabled
        width = $Width
        height = $Height
    }
}

function Wait-LiveRuntimeText {
    param(
        [Parameter(Mandatory = $true)][string]$NodePath,
        [Parameter(Mandatory = $true)][string]$ExpectedText,
        [Parameter(Mandatory = $true)][string]$Label,
        [int]$TimeoutSeconds = 30
    )
    $Deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
    $LastText = ""
    do {
        $LastText = [string](Get-LiveRuntimeProperty `
            -NodePath $NodePath `
            -PropertyName "text" `
            -Label $Label `
            -TimeoutSeconds ([Math]::Min(30, $TimeoutSeconds)))
        if ($LastText -ceq $ExpectedText) {
            return $LastText
        }
        if ($LastText.StartsWith("RUNTIME FAULT", [StringComparison]::Ordinal)) {
            throw "Production UI entered a runtime fault: $LastText"
        }
        $null = Invoke-McpJson "wait_msec" @{ duration = 250 }
    } while ([DateTimeOffset]::UtcNow -lt $Deadline)
    throw "Timed out waiting for $Label text '$ExpectedText'; last='$LastText'"
}

function Get-ApplicationReceiptSucceeded {
    param([Parameter(Mandatory = $true)][object]$Receipt)
    $AcceptedProperty = $Receipt.PSObject.Properties["accepted"]
    if ($null -ne $AcceptedProperty) {
        return Get-RequiredBoolean $Receipt "accepted" "application_receipt"
    }
    return Get-RequiredBoolean $Receipt "success" "application_receipt"
}

function Assert-V075AcceptanceState {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ((Get-RequiredString $State "schema" $Label) `
            -cne "V075SampleAcceptanceStateV1" `
        -or (Get-RequiredString $State "ruleset_id" $Label) -cne "v0.7.5" `
        -or (Get-RequiredIntegralCount `
            $State "combat_direct_runtime_owner_count" $Label) -ne 0 `
        -or (Get-RequiredIntegralCount `
            $State "combat_direct_rng_owner_count" $Label) -ne 0) {
        throw "Acceptance-state identity/ownership gate failed: $Label"
    }
    return Get-RequiredJsonObject $State "interaction_counts" $Label
}

$InitialAcceptance = Get-LiveRuntimeProperty `
    -NodePath "V075GameScreen" `
    -PropertyName "acceptance_state" `
    -Label "V075GameScreen"
$InitialInteractions = Assert-V075AcceptanceState `
    $InitialAcceptance "initial_acceptance_state"
$InitialNewGameCount = Get-RequiredIntegralCount `
    $InitialInteractions "new_game" "initial_acceptance_state.interaction_counts"
$InitialAcceleratedCount = Get-RequiredIntegralCount `
    $InitialInteractions "accelerated" "initial_acceptance_state.interaction_counts"
$InitialSubmissionLockedCount = Get-RequiredIntegralCount `
    $InitialInteractions "submission_locked" "initial_acceptance_state.interaction_counts"
$InitialMaintenanceFinishedCount = Get-RequiredIntegralCount `
    $InitialInteractions "maintenance_finished" `
    "initial_acceptance_state.interaction_counts"
$InitialSettlementPresentedCount = Get-RequiredIntegralCount `
    $InitialInteractions "settlement_presented" "initial_acceptance_state.interaction_counts"

$RandomSeedTap = Invoke-LiveRuntimeButtonTap `
    -NodePath "V075GameScreen/OverlayLayer/StartOverlay/Center/Panel/Margin/Rows/SeedRow/RandomSeedButton" `
    -Label "RandomSeedButton" `
    -TimeoutSeconds 60
$SeedValue = Get-LiveRuntimeProperty `
    -NodePath "V075GameScreen/OverlayLayer/StartOverlay/Center/Panel/Margin/Rows/SeedRow/SeedInput" `
    -PropertyName "text" `
    -Label "SeedInput"
$SeedNumber = [int64]0
if (-not [int64]::TryParse(
    ([string]$SeedValue).Trim(),
    [Globalization.NumberStyles]::Integer,
    [Globalization.CultureInfo]::InvariantCulture,
    [ref]$SeedNumber
) -or $SeedNumber -le 0) {
    throw "The real RandomSeedButton did not produce a positive integer seed."
}

$RootScroll = Get-LiveRuntimeNodeResult `
    -NodePath "V075GameScreen/RootMargin" `
    -Label "RootMargin" `
    -Properties @("scroll_vertical")
if ((Get-RequiredString $RootScroll "type" "query_runtime_node.RootMargin") `
    -cne "ScrollContainer") {
    throw "RootMargin is not the production ScrollContainer."
}
$RootScrollRequested = Get-RequiredJsonObject `
    $RootScroll "requested_properties" "query_runtime_node.RootMargin"
$RootScrollProperties = Get-RequiredJsonObject `
    $RootScroll "properties" "query_runtime_node.RootMargin"
$RootScrollPosition = Get-RequiredJsonObject `
    $RootScrollProperties "global_position" "query_runtime_node.RootMargin.properties"
$RootScrollSize = Get-RequiredJsonObject `
    $RootScrollProperties "size" "query_runtime_node.RootMargin.properties"
$RootScrollVerticalBefore = Get-RequiredIntegralCount `
    $RootScrollRequested "scroll_vertical" "query_runtime_node.RootMargin.requested_properties"
$ScrollPosition = @{
    x = (Get-RequiredFiniteNumber `
        $RootScrollPosition "x" "query_runtime_node.RootMargin.properties.global_position") + (
        (Get-RequiredFiniteNumber `
            $RootScrollSize "x" "query_runtime_node.RootMargin.properties.size") * 0.1875
    )
    y = (Get-RequiredFiniteNumber `
        $RootScrollPosition "y" "query_runtime_node.RootMargin.properties.global_position") + (
        (Get-RequiredFiniteNumber `
            $RootScrollSize "y" "query_runtime_node.RootMargin.properties.size") * 0.8333333333
    )
}
$ScrollEvents = @(
    1..20 | ForEach-Object {
        @{
            type = "mouse_button"
            button = "wheel_down"
            position = $ScrollPosition
            mode = "tap"
        }
    }
)

$StartTap = Invoke-LiveRuntimeButtonTap `
    -NodePath "V075GameScreen/OverlayLayer/StartOverlay/Center/Panel/Margin/Rows/PlayerButtons/V074SettingsStack/StartConfiguredButton" `
    -Label "StartConfiguredButton" `
    -TimeoutSeconds 60
$StartReceipt = Wait-LiveRuntimeReceipt `
    -ExpectedIntentKind "new_game.start" `
    -TimeoutSeconds 60
if ((Get-RequiredString $StartReceipt "schema" "start_receipt") `
        -cne "V075ApplicationReceiptV1" `
    -or (Get-RequiredString $StartReceipt "intent_kind" "start_receipt") `
        -cne "new_game.start" `
    -or -not (Get-RequiredBoolean $StartReceipt "accepted" "start_receipt") `
    -or (Get-RequiredString $StartReceipt "reason_code" "start_receipt") `
        -cne "v075_new_game_application_flow_committed" `
    -or (Get-RequiredString $StartReceipt "ruleset_id" "start_receipt") `
        -cne "v0.7.5" `
    -or [string]::IsNullOrWhiteSpace(
        (Get-RequiredString $StartReceipt "intent_id" "start_receipt")
    ) `
    -or [string]::IsNullOrWhiteSpace(
        (Get-RequiredString $StartReceipt "match_id" "start_receipt")
    ) `
    -or [string]::IsNullOrWhiteSpace(
        (Get-RequiredString $StartReceipt "session_id" "start_receipt")
    ) `
    -or (Get-RequiredString $StartReceipt "sample_mode_id" "start_receipt") `
        -cne "NEW_V075_GAME") {
    throw "Real UI new-game action was not accepted by the production flow."
}

$ScrollResponse = Invoke-McpJson "send_runtime_input" @{
    events = $ScrollEvents
    timeout_msec = 60000
} -TimeoutSeconds 60
$ScrollPayload = $ScrollResponse.result.structuredContent
$ScrollResult = Get-RequiredJsonObject $ScrollPayload "result" "send_runtime_input.scroll"
$ScrollRows = Get-RequiredJsonArray `
    $ScrollResult "results" "send_runtime_input.scroll.result"
if (-not (Get-RequiredBoolean $ScrollPayload "success" "send_runtime_input.scroll") `
    -or (Get-RequiredIntegralCount `
        $ScrollResult "event_count" "send_runtime_input.scroll.result") `
        -ne $ScrollEvents.Count `
    -or $ScrollRows.Count -ne $ScrollEvents.Count `
    -or @($ScrollRows | Where-Object {
        -not (Get-RequiredBoolean `
            $_ "success" "send_runtime_input.scroll.result.results[]")
    }).Count -ne 0) {
    throw "RootMargin did not accept the bounded real wheel input sequence."
}
$null = Invoke-McpJson "wait_msec" @{ duration = 250 }
$RootScrollAfter = Get-LiveRuntimeNodeResult `
    -NodePath "V075GameScreen/RootMargin" `
    -Label "RootMargin after wheel input" `
    -Properties @("scroll_vertical")
$RootScrollAfterRequested = Get-RequiredJsonObject `
    $RootScrollAfter "requested_properties" "query_runtime_node.RootMargin.after"
$RootScrollVerticalAfter = Get-RequiredIntegralCount `
    $RootScrollAfterRequested "scroll_vertical" `
    "query_runtime_node.RootMargin.after.requested_properties"
if ($RootScrollVerticalAfter -le $RootScrollVerticalBefore) {
    throw (
        "RootMargin did not actually scroll: before={0} after={1}" -f
        $RootScrollVerticalBefore,
        $RootScrollVerticalAfter
    )
}

$LockButtonPath = (
    "V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/" +
    "DockRows/CommandRow/LockButton"
)
$FinishButtonPath = (
    "V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/" +
    "DockRows/CommandRow/FinishMaintenanceButton"
)
$SettlementOverlayPath = "V075GameScreen/OverlayLayer/SettlementOverlay"
$ActionStatusPath = (
    "V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/" +
    "DockRows/CommandRow/ActionStatus"
)
$GameplayTaps = @()
$GameplayReceipts = @()
$LockReceipts = @()
$FinishReceipts = @()
$PreviousIntentId = Get-RequiredString $StartReceipt "intent_id" "start_receipt"
$GameplayDeadline = [DateTimeOffset]::UtcNow.AddMinutes(10)
$MaxGameplayBatches = 32
$Settled = $false
while ([DateTimeOffset]::UtcNow -lt $GameplayDeadline) {
    $Settlement = Get-LiveRuntimeNodeResult `
        -NodePath $SettlementOverlayPath `
        -Label "SettlementOverlay" `
        -TimeoutSeconds 30
    $SettlementProperties = Get-RequiredJsonObject `
        $Settlement "properties" "SettlementOverlay"
    if (Get-RequiredBoolean `
        $SettlementProperties "visible" "SettlementOverlay.properties") {
        $Settled = $true
        break
    }
    if ($LockReceipts.Count -ge $MaxGameplayBatches `
        -or $FinishReceipts.Count -ge $MaxGameplayBatches) {
        throw "Natural production UI loop exceeded its batch bound."
    }

    $LockState = Get-LiveRuntimeButtonActionState `
        -NodePath $LockButtonPath `
        -Label "LockButton"
    if ($LockState.actionable) {
        $Tap = Invoke-LiveRuntimeButtonTap `
            -NodePath $LockButtonPath `
            -Label "LockButton" `
            -RequiredClipNodePath "V075GameScreen/RootMargin"
        $Receipt = Wait-LiveRuntimeReceipt `
            -ExpectedIntentKind "submission.lock" `
            -PreviousIntentId $PreviousIntentId
        if ((Get-RequiredString $Receipt "schema" "lock_receipt") `
                -cne "V075ApplicationReceiptV1" `
            -or -not (Get-RequiredBoolean $Receipt "accepted" "lock_receipt") `
            -or (Get-RequiredString $Receipt "reason_code" "lock_receipt") `
                -cne "submission_locked_with_full_asset_reservation" `
            -or (Get-RequiredString $Receipt "ruleset_id" "lock_receipt") `
                -cne "v0.7.5") {
            throw "Natural production LockButton receipt is invalid."
        }
        $PreviousIntentId = Get-RequiredString `
            $Receipt "intent_id" "lock_receipt"
        $null = Wait-LiveRuntimeText `
            -NodePath $ActionStatusPath `
            -ExpectedText (Get-RequiredString `
                $Receipt "reason_code" "lock_receipt") `
            -Label "ActionStatus after submission.lock"
        $GameplayTaps += $Tap
        $GameplayReceipts += $Receipt
        $LockReceipts += $Receipt
        continue
    }

    $FinishState = Get-LiveRuntimeButtonActionState `
        -NodePath $FinishButtonPath `
        -Label "FinishMaintenanceButton"
    if ($FinishState.actionable) {
        $Tap = Invoke-LiveRuntimeButtonTap `
            -NodePath $FinishButtonPath `
            -Label "FinishMaintenanceButton" `
            -RequiredClipNodePath "V075GameScreen/RootMargin"
        $Receipt = Wait-LiveRuntimeReceipt `
            -ExpectedIntentKind "maintenance.finish" `
            -PreviousIntentId $PreviousIntentId
        if ((Get-RequiredString $Receipt "schema" "finish_receipt") `
                -cne "V075ApplicationReceiptV1" `
            -or -not (Get-RequiredBoolean $Receipt "accepted" "finish_receipt") `
            -or -not (Get-RequiredBoolean $Receipt "success" "finish_receipt") `
            -or (Get-RequiredString $Receipt "reason_code" "finish_receipt") `
                -cne "maintenance_ended" `
            -or (Get-RequiredString $Receipt "ruleset_id" "finish_receipt") `
                -cne "v0.7.5") {
            throw "Natural production FinishMaintenanceButton receipt is invalid."
        }
        $PreviousIntentId = Get-RequiredString `
            $Receipt "intent_id" "finish_receipt"
        $null = Wait-LiveRuntimeText `
            -NodePath $ActionStatusPath `
            -ExpectedText (Get-RequiredString `
                $Receipt "reason_code" "finish_receipt") `
            -Label "ActionStatus after maintenance.finish"
        $GameplayTaps += $Tap
        $GameplayReceipts += $Receipt
        $FinishReceipts += $Receipt
        continue
    }

    $ActionStatus = [string](Get-LiveRuntimeProperty `
        -NodePath $ActionStatusPath `
        -PropertyName "text" `
        -Label "ActionStatus" `
        -TimeoutSeconds 30)
    if ($ActionStatus.StartsWith("RUNTIME FAULT", [StringComparison]::Ordinal)) {
        throw "Natural production UI loop entered runtime fault: $ActionStatus"
    }
    $null = Invoke-McpJson "wait_msec" @{ duration = 250 }
}
if (-not $Settled `
    -or $LockReceipts.Count -le 0 `
    -or $LockReceipts.Count -ne $FinishReceipts.Count `
    -or $GameplayReceipts.Count -le 0 `
    -or (Get-RequiredString `
        $GameplayReceipts[-1] "intent_kind" "final_gameplay_receipt") `
        -cne "maintenance.finish") {
    throw "Natural production UI chain did not settle by complete Lock/Finish batches."
}

$GameplayAcceptance = Get-LiveRuntimeProperty `
    -NodePath "V075GameScreen" `
    -PropertyName "acceptance_state" `
    -Label "V075GameScreen" `
    -TimeoutSeconds 60
$GameplayInteractions = Assert-V075AcceptanceState `
    $GameplayAcceptance "gameplay_acceptance_state"
if (-not (Get-RequiredBoolean `
        $GameplayAcceptance "match_started" "gameplay_acceptance_state") `
    -or -not (Get-RequiredBoolean `
        $GameplayAcceptance "match_completed" "gameplay_acceptance_state") `
    -or -not (Get-RequiredBoolean `
        $GameplayAcceptance "settlement_visible" "gameplay_acceptance_state") `
    -or (Get-RequiredIntegralCount `
        $GameplayInteractions "new_game" "gameplay_acceptance_state.interaction_counts") `
        -ne ($InitialNewGameCount + 1) `
    -or (Get-RequiredIntegralCount `
        $GameplayInteractions "accelerated" "gameplay_acceptance_state.interaction_counts") `
        -ne $InitialAcceleratedCount `
    -or (Get-RequiredIntegralCount `
        $GameplayInteractions "submission_locked" `
        "gameplay_acceptance_state.interaction_counts") `
        -ne ($InitialSubmissionLockedCount + $LockReceipts.Count) `
    -or (Get-RequiredIntegralCount `
        $GameplayInteractions "maintenance_finished" `
        "gameplay_acceptance_state.interaction_counts") `
        -ne ($InitialMaintenanceFinishedCount + $FinishReceipts.Count) `
    -or (Get-RequiredIntegralCount `
        $GameplayInteractions "settlement_presented" `
        "gameplay_acceptance_state.interaction_counts") `
        -ne ($InitialSettlementPresentedCount + 1)) {
    throw "Natural production UI gameplay was not consumed and settled exactly once."
}
$Debug = Get-RequiredJsonObject `
    $GameplayAcceptance "runtime_acceptance_debug" "gameplay_acceptance_state"
Assert-ExactJsonObjectKeys `
    -Object $Debug `
    -Label "gameplay_acceptance_state.runtime_acceptance_debug" `
    -ExpectedKeys @(
        "schema", "ruleset_id", "phase", "combat",
        "facility_combat_damage_receipt_count", "facility_effect_integrity",
        "combat_presentation", "combat_public_receipt_count",
        "final_settlement_count", "duplicate_settlement_count",
        "final_settlement_public_log_count",
        "final_settlement_presentation_count", "runtime_error_count",
        "hidden_info_violation_count", "combat_telemetry",
        "combat_telemetry_hidden_field_count",
        "combat_telemetry_gameplay_owner_count",
        "combat_telemetry_rng_owner_count",
        "combat_telemetry_world_mutation_count", "invalid_action_count",
        "ai_combat_invalid_target_count", "nonfinite_count"
    )
if ((Get-RequiredString `
        $Debug "schema" "gameplay_acceptance_state.runtime_acceptance_debug") `
        -cne "V075RuntimeAcceptanceDebugV1" `
    -or (Get-RequiredString `
        $Debug "ruleset_id" "gameplay_acceptance_state.runtime_acceptance_debug") `
        -cne "v0.7.5" `
    -or (Get-RequiredString `
        $Debug "phase" "gameplay_acceptance_state.runtime_acceptance_debug") `
        -cne "settled") {
    throw "Final runtime debug is not settled."
}
$CombatUi = Get-RequiredJsonObject `
    $GameplayAcceptance "combat_wrapper" "gameplay_acceptance_state"
$GameplayRuntimeErrorCount = Get-RequiredIntegralCount `
    $GameplayAcceptance "runtime_error_count" "acceptance_state"
$GameplayInvalidActionCount = Get-RequiredIntegralCount `
    $GameplayAcceptance "invalid_action_count" "acceptance_state"
$GameplayHiddenInfoViolationCount = Get-RequiredIntegralCount `
    $GameplayAcceptance "hidden_info_violation_count" "acceptance_state"
$GameplayDuplicateSettlementCount = Get-RequiredIntegralCount `
    $GameplayAcceptance "duplicate_settlement_count" "acceptance_state"
$GameplayNonfiniteCount = Get-RequiredIntegralCount `
    $GameplayAcceptance "nonfinite_count" "acceptance_state"
$CombatUiReceiptDuplicateCount = Get-RequiredIntegralCount `
    $CombatUi "receipt_duplicate_count" "acceptance_state.combat_wrapper"
if ($GameplayRuntimeErrorCount -ne 0 `
    -or $GameplayInvalidActionCount -ne 0 `
    -or $GameplayHiddenInfoViolationCount -ne 0 `
    -or $GameplayDuplicateSettlementCount -ne 0 `
    -or $GameplayNonfiniteCount -ne 0 `
    -or $CombatUiReceiptDuplicateCount -ne 0) {
    throw "Real UI production gameplay safety counters are not zero."
}
$CombatDebug = Get-RequiredJsonObject $Debug "combat" "terminal_receipt.debug"
Assert-ExactJsonObjectKeys `
    -Object $CombatDebug `
    -Label "runtime_acceptance_debug.combat" `
    -ExpectedKeys @(
        "monster_card_mode_counts", "monster_private_skill_commit_count",
        "monster_trample_region_receipt_count", "military_region_assault_count",
        "military_monster_assault_count", "runtime_error_count",
        "combat_duplicate_effect_count", "combat_effect_integrity",
        "combat_receipt_integrity"
    )
$MonsterModes = Get-RequiredJsonObject `
    $CombatDebug "monster_card_mode_counts" "terminal_receipt.debug.combat"
Assert-ExactJsonObjectKeys `
    -Object $MonsterModes `
    -Label "runtime_acceptance_debug.combat.monster_card_mode_counts" `
    -ExpectedKeys @(
        "DEPLOY_NEW", "REFRESH_EXISTING", "UPGRADE_EXISTING", "REPLACE_EXISTING"
    )
$MonsterDeployCount = Get-RequiredIntegralCount `
    $MonsterModes "DEPLOY_NEW" "terminal_receipt.debug.combat.monster_card_mode_counts"
$MonsterRefreshCount = Get-RequiredIntegralCount `
    $MonsterModes "REFRESH_EXISTING" "terminal_receipt.debug.combat.monster_card_mode_counts"
$MonsterUpgradeCount = Get-RequiredIntegralCount `
    $MonsterModes "UPGRADE_EXISTING" "terminal_receipt.debug.combat.monster_card_mode_counts"
$MonsterReplaceCount = Get-RequiredIntegralCount `
    $MonsterModes "REPLACE_EXISTING" "terminal_receipt.debug.combat.monster_card_mode_counts"
$MonsterPrivateSkillCommitCount = Get-RequiredIntegralCount `
    $CombatDebug "monster_private_skill_commit_count" "terminal_receipt.debug.combat"
$MonsterTrampleReceiptCount = Get-RequiredIntegralCount `
    $CombatDebug "monster_trample_region_receipt_count" "terminal_receipt.debug.combat"
$MilitaryRegionAssaultCount = Get-RequiredIntegralCount `
    $CombatDebug "military_region_assault_count" "terminal_receipt.debug.combat"
$MilitaryMonsterAssaultCount = Get-RequiredIntegralCount `
    $CombatDebug "military_monster_assault_count" "terminal_receipt.debug.combat"
$FacilityCombatDamageReceiptCount = Get-RequiredIntegralCount `
    $Debug "facility_combat_damage_receipt_count" "terminal_receipt.debug"
$McpCombatActionCount = $MonsterDeployCount `
    + $MonsterRefreshCount `
    + $MonsterUpgradeCount `
    + $MonsterReplaceCount `
    + $MonsterPrivateSkillCommitCount `
    + $MonsterTrampleReceiptCount `
    + $MilitaryRegionAssaultCount `
    + $MilitaryMonsterAssaultCount `
    + $FacilityCombatDamageReceiptCount
$EffectIntegrity = Get-RequiredJsonObject `
    $CombatDebug "combat_effect_integrity" "terminal_receipt.debug.combat"
$ReceiptIntegrity = Get-RequiredJsonObject `
    $CombatDebug "combat_receipt_integrity" "terminal_receipt.debug.combat"
$FacilityIntegrity = Get-RequiredJsonObject `
    $Debug "facility_effect_integrity" "terminal_receipt.debug"
$Presentation = Get-RequiredJsonObject `
    $Debug "combat_presentation" "terminal_receipt.debug"
Assert-ExactJsonObjectKeys `
    -Object $EffectIntegrity `
    -Label "runtime_acceptance_debug.combat.combat_effect_integrity" `
    -ExpectedKeys @("green", "violation_count")
Assert-ExactJsonObjectKeys `
    -Object $ReceiptIntegrity `
    -Label "runtime_acceptance_debug.combat.combat_receipt_integrity" `
    -ExpectedKeys @("green")
Assert-ExactJsonObjectKeys `
    -Object $FacilityIntegrity `
    -Label "runtime_acceptance_debug.facility_effect_integrity" `
    -ExpectedKeys @("green")
Assert-ExactJsonObjectKeys `
    -Object $Presentation `
    -Label "runtime_acceptance_debug.combat_presentation" `
    -ExpectedKeys @(
        "applied_receipt_count", "duplicate_receipt_count",
        "collision_receipt_count", "rejected_receipt_count",
        "presentation_gameplay_mutation_count", "presentation_rng_draw_delta"
    )
$McpCombatPublicReceiptCount = Get-RequiredIntegralCount `
    $Debug "combat_public_receipt_count" "terminal_receipt.debug"
$McpPresentationAppliedReceiptCount = Get-RequiredIntegralCount `
    $Presentation "applied_receipt_count" "terminal_receipt.debug.combat_presentation"
$McpUiPresentationCueConsumedCount = Get-RequiredIntegralCount `
    $CombatUi "combat_map_cue_apply_count" "acceptance_state.combat_wrapper"
$CombatSurfaceUi = Get-RequiredJsonObject `
    $CombatUi "surface" "acceptance_state.combat_wrapper"
$McpSurfacePresentationCueConsumedCount = Get-RequiredIntegralCount `
    $CombatSurfaceUi "presentation_cue_applied_count" `
    "acceptance_state.combat_wrapper.surface"
$FinalSettlementCount = Get-RequiredIntegralCount `
    $Debug "final_settlement_count" "terminal_receipt.debug"
$DuplicateSettlementCount = Get-RequiredIntegralCount `
    $Debug "duplicate_settlement_count" "terminal_receipt.debug"
$FinalSettlementPublicLogCount = Get-RequiredIntegralCount `
    $Debug "final_settlement_public_log_count" "terminal_receipt.debug"
$FinalSettlementPresentationCount = Get-RequiredIntegralCount `
    $Debug "final_settlement_presentation_count" "terminal_receipt.debug"
$DebugRuntimeErrorCount = Get-RequiredIntegralCount `
    $Debug "runtime_error_count" "terminal_receipt.debug"
$CombatRuntimeErrorCount = Get-RequiredIntegralCount `
    $CombatDebug "runtime_error_count" "terminal_receipt.debug.combat"
$DebugHiddenInfoViolationCount = Get-RequiredIntegralCount `
    $Debug "hidden_info_violation_count" "terminal_receipt.debug"
$CombatTelemetry = Get-RequiredJsonObject `
    $Debug "combat_telemetry" "terminal_receipt.debug"
Assert-ExactJsonObjectKeys `
    -Object $CombatTelemetry `
    -Label "runtime_acceptance_debug.combat_telemetry" `
    -ExpectedKeys @(
        "schema", "ruleset_id", "hidden_input_field_count",
        "opponent_skill_definition_input_count",
        "opponent_skill_target_input_count",
        "opponent_skill_cooldown_input_count",
        "instant_sequence_input_count", "warehouse_private_stock_input_count",
        "ai_private_plan_input_count", "stored_hidden_field_count",
        "gameplay_owner_count", "rng_owner_count", "world_mutation_count"
    )
if ((Get-RequiredString `
        $CombatTelemetry "schema" "terminal_receipt.debug.combat_telemetry") `
        -cne "V075CombatTelemetryServiceDebugV1" `
    -or (Get-RequiredString `
        $CombatTelemetry "ruleset_id" "terminal_receipt.debug.combat_telemetry") `
        -cne "v0.7.5") {
    throw "Combat telemetry debug identity is not the V0.7.5 service contract."
}
$CombatTelemetryHiddenInputFieldCount = Get-RequiredIntegralCount `
    $CombatTelemetry "hidden_input_field_count" `
    "terminal_receipt.debug.combat_telemetry"
$CombatTelemetryOpponentSkillDefinitionInputCount = `
    Get-RequiredIntegralCount `
        $CombatTelemetry "opponent_skill_definition_input_count" `
        "terminal_receipt.debug.combat_telemetry"
$CombatTelemetryOpponentSkillTargetInputCount = Get-RequiredIntegralCount `
    $CombatTelemetry "opponent_skill_target_input_count" `
    "terminal_receipt.debug.combat_telemetry"
$CombatTelemetryOpponentSkillCooldownInputCount = `
    Get-RequiredIntegralCount `
        $CombatTelemetry "opponent_skill_cooldown_input_count" `
        "terminal_receipt.debug.combat_telemetry"
$CombatTelemetryInstantSequenceInputCount = Get-RequiredIntegralCount `
    $CombatTelemetry "instant_sequence_input_count" `
    "terminal_receipt.debug.combat_telemetry"
$CombatTelemetryWarehousePrivateStockInputCount = `
    Get-RequiredIntegralCount `
        $CombatTelemetry "warehouse_private_stock_input_count" `
        "terminal_receipt.debug.combat_telemetry"
$CombatTelemetryAiPrivatePlanInputCount = Get-RequiredIntegralCount `
    $CombatTelemetry "ai_private_plan_input_count" `
    "terminal_receipt.debug.combat_telemetry"
$CombatTelemetryStoredHiddenFieldCount = Get-RequiredIntegralCount `
    $CombatTelemetry "stored_hidden_field_count" `
    "terminal_receipt.debug.combat_telemetry"
$CombatTelemetryGameplayOwnerCount = Get-RequiredIntegralCount `
    $CombatTelemetry "gameplay_owner_count" `
    "terminal_receipt.debug.combat_telemetry"
$CombatTelemetryRngOwnerCount = Get-RequiredIntegralCount `
    $CombatTelemetry "rng_owner_count" `
    "terminal_receipt.debug.combat_telemetry"
$CombatTelemetryWorldMutationCount = Get-RequiredIntegralCount `
    $CombatTelemetry "world_mutation_count" `
    "terminal_receipt.debug.combat_telemetry"
$CombatTelemetryHiddenFieldCount = Get-RequiredIntegralCount `
    $Debug "combat_telemetry_hidden_field_count" "terminal_receipt.debug"
$DebugCombatTelemetryGameplayOwnerCount = Get-RequiredIntegralCount `
    $Debug "combat_telemetry_gameplay_owner_count" "terminal_receipt.debug"
$DebugCombatTelemetryRngOwnerCount = Get-RequiredIntegralCount `
    $Debug "combat_telemetry_rng_owner_count" "terminal_receipt.debug"
$DebugCombatTelemetryWorldMutationCount = Get-RequiredIntegralCount `
    $Debug "combat_telemetry_world_mutation_count" "terminal_receipt.debug"
$DebugInvalidActionCount = Get-RequiredIntegralCount `
    $Debug "invalid_action_count" "terminal_receipt.debug"
$AiCombatInvalidTargetCount = Get-RequiredIntegralCount `
    $Debug "ai_combat_invalid_target_count" "terminal_receipt.debug"
$DebugNonfiniteCount = Get-RequiredIntegralCount `
    $Debug "nonfinite_count" "terminal_receipt.debug"
$CombatDuplicateEffectCount = Get-RequiredIntegralCount `
    $CombatDebug "combat_duplicate_effect_count" "terminal_receipt.debug.combat"
$EffectIntegrityViolationCount = Get-RequiredIntegralCount `
    $EffectIntegrity "violation_count" "combat_effect_integrity"
$EffectIntegrityGreen = Get-RequiredBoolean `
    $EffectIntegrity "green" "combat_effect_integrity"
$ReceiptIntegrityGreen = Get-RequiredBoolean `
    $ReceiptIntegrity "green" "combat_receipt_integrity"
$FacilityIntegrityGreen = Get-RequiredBoolean `
    $FacilityIntegrity "green" "facility_effect_integrity"
$CombatUiSharedConsumerCount = Get-RequiredIntegralCount `
    $CombatUi "presentation_shared_consumer_count" "acceptance_state.combat_wrapper"
$CombatUiSignalConnectionCount = Get-RequiredIntegralCount `
    $CombatUi "presentation_signal_connection_count" "acceptance_state.combat_wrapper"
$CombatUiSharedIdentityGreen = Get-RequiredBoolean `
    $CombatUi "presentation_shared_identity_green" "acceptance_state.combat_wrapper"
$CombatUiReceiptCount = Get-RequiredIntegralCount `
    $CombatUi "receipt_count" "acceptance_state.combat_wrapper"
$CombatUiReceiptAppliedCount = Get-RequiredIntegralCount `
    $CombatUi "receipt_applied_count" "acceptance_state.combat_wrapper"
$CombatUiReceiptRejectedCount = Get-RequiredIntegralCount `
    $CombatUi "receipt_rejected_count" "acceptance_state.combat_wrapper"
$CombatUiSuppressedDuplicateConsumeCount = Get-RequiredIntegralCount `
    $CombatUi "presentation_suppressed_duplicate_consume_count" "acceptance_state.combat_wrapper"
$PresentationDuplicateReceiptCount = Get-RequiredIntegralCount `
    $Presentation "duplicate_receipt_count" "terminal_receipt.debug.combat_presentation"
$PresentationCollisionReceiptCount = Get-RequiredIntegralCount `
    $Presentation "collision_receipt_count" "terminal_receipt.debug.combat_presentation"
$PresentationRejectedReceiptCount = Get-RequiredIntegralCount `
    $Presentation "rejected_receipt_count" "terminal_receipt.debug.combat_presentation"
$PresentationGameplayMutationCount = Get-RequiredIntegralCount `
    $Presentation "presentation_gameplay_mutation_count" "terminal_receipt.debug.combat_presentation"
$PresentationRngDrawDelta = Get-RequiredIntegralCount `
    $Presentation "presentation_rng_draw_delta" "terminal_receipt.debug.combat_presentation"
if ($McpCombatActionCount -le 0 `
    -or $McpCombatPublicReceiptCount -le 0 `
    -or $FinalSettlementCount -ne 1 `
    -or $DuplicateSettlementCount -ne 0 `
    -or $FinalSettlementPublicLogCount -ne 1 `
    -or $FinalSettlementPresentationCount -ne 1 `
    -or $DebugRuntimeErrorCount -ne 0 `
    -or $CombatRuntimeErrorCount -ne 0 `
    -or $DebugHiddenInfoViolationCount -ne 0 `
    -or $CombatTelemetryOpponentSkillDefinitionInputCount -ne 0 `
    -or $CombatTelemetryOpponentSkillTargetInputCount -ne 0 `
    -or $CombatTelemetryOpponentSkillCooldownInputCount -ne 0 `
    -or $CombatTelemetryInstantSequenceInputCount -ne 0 `
    -or $CombatTelemetryWarehousePrivateStockInputCount -ne 0 `
    -or $CombatTelemetryAiPrivatePlanInputCount -ne 0 `
    -or $CombatTelemetryStoredHiddenFieldCount -ne 0 `
    -or $CombatTelemetryGameplayOwnerCount -ne 0 `
    -or $CombatTelemetryRngOwnerCount -ne 0 `
    -or $CombatTelemetryWorldMutationCount -ne 0 `
    -or $CombatTelemetryHiddenFieldCount -ne 0 `
    -or $CombatTelemetryHiddenFieldCount `
        -ne $CombatTelemetryStoredHiddenFieldCount `
    -or $DebugCombatTelemetryGameplayOwnerCount `
        -ne $CombatTelemetryGameplayOwnerCount `
    -or $DebugCombatTelemetryRngOwnerCount -ne $CombatTelemetryRngOwnerCount `
    -or $DebugCombatTelemetryWorldMutationCount `
        -ne $CombatTelemetryWorldMutationCount `
    -or $DebugInvalidActionCount -ne 0 `
    -or $AiCombatInvalidTargetCount -ne 0 `
    -or $DebugNonfiniteCount -ne 0 `
    -or $CombatDuplicateEffectCount -ne 0 `
    -or -not $EffectIntegrityGreen `
    -or $EffectIntegrityViolationCount -ne 0 `
    -or -not $ReceiptIntegrityGreen `
    -or -not $FacilityIntegrityGreen `
    -or $McpPresentationAppliedReceiptCount -le 0 `
    -or $McpPresentationAppliedReceiptCount `
        -ne $McpCombatPublicReceiptCount `
    -or $McpUiPresentationCueConsumedCount -ne $McpPresentationAppliedReceiptCount `
    -or $McpSurfacePresentationCueConsumedCount `
        -ne $McpPresentationAppliedReceiptCount `
    -or $CombatUiSharedConsumerCount -ne 1 `
    -or $CombatUiSignalConnectionCount -ne 1 `
    -or -not $CombatUiSharedIdentityGreen `
    -or $CombatUiReceiptCount -ne 0 `
    -or $CombatUiReceiptAppliedCount -ne 0 `
    -or $CombatUiReceiptRejectedCount -ne 0 `
    -or $CombatUiSuppressedDuplicateConsumeCount -ne 0 `
    -or $PresentationDuplicateReceiptCount -ne 0 `
    -or $PresentationCollisionReceiptCount -ne 0 `
    -or $PresentationGameplayMutationCount -ne 0 `
    -or $PresentationRngDrawDelta -ne 0) {
    throw "The natural production runtime state failed the combat/safety gate."
}
$ProductionApplicationTaps = @($StartTap) + @($GameplayTaps)
$ProductionApplicationReceipts = @($StartReceipt) + @($GameplayReceipts)
$SuccessfulApplicationReceipts = @(
    $ProductionApplicationReceipts | Where-Object {
        Get-ApplicationReceiptSucceeded $_
    }
)
$UniqueApplicationReceiptIds = @(
    $ProductionApplicationReceipts |
        ForEach-Object {
            Get-RequiredString $_ "intent_id" "application_receipt"
        } |
        Sort-Object -Unique
)
$McpProductionApplicationActionCount = $ProductionApplicationTaps.Count
$McpProductionApplicationReceiptCount = $SuccessfulApplicationReceipts.Count
$McpProductionApplicationUniqueReceiptIdCount = $UniqueApplicationReceiptIds.Count
$McpProductionUiReceiptConsumedCount = `
    (Get-RequiredIntegralCount `
        $GameplayInteractions "new_game" `
        "gameplay_acceptance_state.interaction_counts") `
    - $InitialNewGameCount `
    + (Get-RequiredIntegralCount `
        $GameplayInteractions "submission_locked" `
        "gameplay_acceptance_state.interaction_counts") `
    - $InitialSubmissionLockedCount `
    + (Get-RequiredIntegralCount `
        $GameplayInteractions "maintenance_finished" `
        "gameplay_acceptance_state.interaction_counts") `
    - $InitialMaintenanceFinishedCount
$McpProductionUiInputCount = 1 + $ProductionApplicationTaps.Count
if ($McpProductionApplicationActionCount -le 2 `
    -or $McpProductionApplicationReceiptCount `
        -ne $McpProductionApplicationActionCount `
    -or $McpProductionApplicationUniqueReceiptIdCount `
        -ne $McpProductionApplicationReceiptCount `
    -or $McpProductionUiReceiptConsumedCount `
        -ne $McpProductionApplicationReceiptCount) {
    throw "Production application action/receipt/consumption counts diverged."
}
$FinalEvents = Invoke-McpJson "get_runtime_events" @{
    max_events = 200
    timeout_msec = 10000
}
$FinalEventsPayload = $FinalEvents.result.structuredContent
$FinalEventResult = Get-RequiredJsonObject `
    $FinalEventsPayload "result" "get_runtime_events.final"
$FinalRuntimeEvents = Get-RequiredJsonArray `
    $FinalEventResult "events" "get_runtime_events.final.result"
$FinalReadyEvents = @(
    $FinalRuntimeEvents |
        Where-Object {
            [string]$_.kind -ceq "ready" `
                -and [string]$_.message -ceq "Runtime bridge ready."
        }
)
$InvalidFinalRuntimeEvents = @(
    $FinalRuntimeEvents |
        Where-Object {
            $Kind = [string]$_.kind
            $Message = [string]$_.message
            ($Kind -cne "ready" -and $Kind -cne "command") `
                -or ($Kind -ceq "command" -and $Message -notmatch ': success$')
        }
)
if (-not (Get-RequiredBoolean `
        $FinalEventsPayload "success" "get_runtime_events.final") `
    -or (Get-RequiredIntegralCount `
        $FinalEventResult "returned_event_count" "get_runtime_events.final.result") `
        -ne $FinalRuntimeEvents.Count `
    -or (Get-RequiredIntegralCount `
        $FinalEventResult "event_count" "get_runtime_events.final.result") `
        -ne $FinalRuntimeEvents.Count `
    -or $FinalRuntimeEvents.Count -le 0 `
    -or $FinalRuntimeEvents.Count -ge 100 `
    -or $FinalReadyEvents.Count -ne 1 `
    -or $InvalidFinalRuntimeEvents.Count -ne 0) {
    throw "Final runtime event evidence is incomplete or contains a failed command/runtime event."
}
"MCP_PRODUCTION_GAMEPLAY_PROBE_MODE=UI_INPUT"
"MCP_PRODUCTION_RANDOM_SEED=$SeedValue"
"MCP_PRODUCTION_UI_INPUT_COUNT=$McpProductionUiInputCount"
"MCP_ROOT_SCROLL_VERTICAL_BEFORE=$RootScrollVerticalBefore"
"MCP_ROOT_SCROLL_VERTICAL_AFTER=$RootScrollVerticalAfter"
"MCP_PRODUCTION_APPLICATION_ACTION_COUNT=$McpProductionApplicationActionCount"
"MCP_PRODUCTION_APPLICATION_RECEIPT_COUNT=$McpProductionApplicationReceiptCount"
"MCP_PRODUCTION_APPLICATION_UNIQUE_RECEIPT_ID_COUNT=$McpProductionApplicationUniqueReceiptIdCount"
"MCP_PRODUCTION_ACTION_COUNT=$McpCombatActionCount"
"MCP_PRODUCTION_ACTION_COUNT_DOMAIN=combat_action"
"MCP_PRODUCTION_ACTION_COUNT_SOURCE=acceptance_state.runtime_acceptance_debug.combat_plus_facility_damage"
"MCP_PRODUCTION_RECEIPT_COUNT=$McpCombatPublicReceiptCount"
"MCP_PRODUCTION_RECEIPT_COUNT_DOMAIN=combat_public_receipt"
"MCP_PRODUCTION_RECEIPT_COUNT_SOURCE=acceptance_state.runtime_acceptance_debug.combat_public_receipt_count"
"MCP_PRODUCTION_UI_RECEIPT_CONSUMED_COUNT=$McpProductionUiReceiptConsumedCount"
"MCP_COMBAT_ACTION_COUNT=$McpCombatActionCount"
"MCP_COMBAT_PUBLIC_RECEIPT_COUNT=$McpCombatPublicReceiptCount"
"MCP_PRESENTATION_APPLIED_RECEIPT_COUNT=$McpPresentationAppliedReceiptCount"
"MCP_UI_PRESENTATION_CUE_CONSUMED_COUNT=$McpUiPresentationCueConsumedCount"
"MCP_SURFACE_PRESENTATION_CUE_CONSUMED_COUNT=$McpSurfacePresentationCueConsumedCount"
"MCP_PRESENTATION_COLLISION_RECEIPT_COUNT=$PresentationCollisionReceiptCount"
"MCP_PRESENTATION_REJECTED_RECEIPT_COUNT=$PresentationRejectedReceiptCount"
"MCP_PRESENTATION_APPLIED_EQUALS_COMBAT_PUBLIC=true"
"MCP_PRESENTATION_COLLISION_GATE=HARD_ZERO_C4_1"
"MCP_PRESENTATION_REJECTED_GATE=DIAGNOSTIC_NONBLOCKING_C4_1"
"MCP_COMBAT_TELEMETRY_HIDDEN_INPUT_FIELD_COUNT=$CombatTelemetryHiddenInputFieldCount"
"MCP_COMBAT_TELEMETRY_HIDDEN_INPUT_GATE=DIAGNOSTIC_NONBLOCKING_C4_1"
"MCP_COMBAT_TELEMETRY_PRIVATE_INPUT_COUNT=$($CombatTelemetryOpponentSkillDefinitionInputCount + $CombatTelemetryOpponentSkillTargetInputCount + $CombatTelemetryOpponentSkillCooldownInputCount + $CombatTelemetryInstantSequenceInputCount + $CombatTelemetryWarehousePrivateStockInputCount + $CombatTelemetryAiPrivatePlanInputCount)"
"MCP_COMBAT_TELEMETRY_STORED_HIDDEN_FIELD_COUNT=$CombatTelemetryStoredHiddenFieldCount"
"MCP_COMBAT_TELEMETRY_GAMEPLAY_OWNER_COUNT=$CombatTelemetryGameplayOwnerCount"
"MCP_COMBAT_TELEMETRY_RNG_OWNER_COUNT=$CombatTelemetryRngOwnerCount"
"MCP_COMBAT_TELEMETRY_WORLD_MUTATION_COUNT=$CombatTelemetryWorldMutationCount"
"MCP_FINAL_RUNTIME_EVENT_COUNT=$($FinalRuntimeEvents.Count)"
"MCP_FINAL_RUNTIME_EVENT_ERROR_COUNT=$($InvalidFinalRuntimeEvents.Count)"
"MCP_PRODUCTION_GAMEPLAY_PROBE_GREEN=true"

function Get-McpDiagnosticRows {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Lines,
        [Parameter(Mandatory = $true)]
        [ValidateSet("editor_launch", "runtime")]
        [string]$Channel,
        [Parameter(Mandatory = $true)]
        [Collections.Generic.Dictionary[string,object]]$UidCandidateMap
    )
    $CultureInvariant = [Text.RegularExpressions.RegexOptions]::CultureInvariant
    $IgnoreCaseInvariant = `
        [Text.RegularExpressions.RegexOptions]::IgnoreCase `
        -bor $CultureInvariant
    $UidRegenerationPattern = [regex]::new(
        '\AWARNING: Missing \.uid file for path "res://(?<source>[^"\r\n]+)"\. The file was re-created from cache\.\z',
        $CultureInvariant
    )
    for ($LineIndex = 0; $LineIndex -lt $Lines.Count; $LineIndex += 1) {
        $Line = [string]$Lines[$LineIndex]
        $LineNumber = $LineIndex + 1
        $RawWarning = [regex]::IsMatch(
            $Line,
            '\bWARNING\b',
            $IgnoreCaseInvariant
        )
        if ([regex]::IsMatch(
                $Line,
                '(SCRIPT ERROR|PARSE ERROR|PARSER ERROR|RUNTIME ERROR|ERROR:)',
                $IgnoreCaseInvariant
            )) {
            [pscustomobject][ordered]@{
                severity = "error"
                classification = "diagnostic_error"
                channel = $Channel
                line_number = $LineNumber
                line = $Line
                raw_warning = $RawWarning
                source_path = ""
                uid_relative_path = ""
                expected_uid_value = ""
                expected_uid_content_sha256 = ""
                expected_uid_byte_length = 0
            }
            continue
        }
        if ($Line.Contains([string][char]0) `
            -or $Line.Contains([string][char]0xFFFD)) {
            [pscustomobject][ordered]@{
                severity = "unclassified"
                classification = "invalid_console_text"
                channel = $Channel
                line_number = $LineNumber
                line = $Line
                raw_warning = $RawWarning
                source_path = ""
                uid_relative_path = ""
                expected_uid_value = ""
                expected_uid_content_sha256 = ""
                expected_uid_byte_length = 0
            }
            continue
        }
        $UidRegenerationMatch = $UidRegenerationPattern.Match($Line)
        if ($UidRegenerationMatch.Success) {
            $SourcePath = [string]$UidRegenerationMatch.Groups["source"].Value
            $UidRelativePath = "$SourcePath.uid"
            if ($Channel -cne "editor_launch") {
                [pscustomobject][ordered]@{
                    severity = "unclassified"
                    classification = "uid_regeneration_warning_wrong_channel"
                    channel = $Channel
                    line_number = $LineNumber
                    line = $Line
                    raw_warning = $true
                    source_path = $SourcePath
                    uid_relative_path = $UidRelativePath
                    expected_uid_value = ""
                    expected_uid_content_sha256 = ""
                    expected_uid_byte_length = 0
                }
                continue
            }
            if (-not $UidCandidateMap.ContainsKey($UidRelativePath)) {
                [pscustomobject][ordered]@{
                    severity = "unclassified"
                    classification = "uid_regeneration_warning_not_authorized"
                    channel = $Channel
                    line_number = $LineNumber
                    line = $Line
                    raw_warning = $true
                    source_path = $SourcePath
                    uid_relative_path = $UidRelativePath
                    expected_uid_value = ""
                    expected_uid_content_sha256 = ""
                    expected_uid_byte_length = 0
                }
                continue
            }
            $UidCandidate = $UidCandidateMap[$UidRelativePath]
            if ([string]$UidCandidate.path -cne $UidRelativePath `
                -or [string]$UidCandidate.source_path -cne $SourcePath) {
                [pscustomobject][ordered]@{
                    severity = "unclassified"
                    classification = "uid_regeneration_authority_identity_mismatch"
                    channel = $Channel
                    line_number = $LineNumber
                    line = $Line
                    raw_warning = $true
                    source_path = $SourcePath
                    uid_relative_path = $UidRelativePath
                    expected_uid_value = ""
                    expected_uid_content_sha256 = ""
                    expected_uid_byte_length = 0
                }
                continue
            }
            [pscustomobject][ordered]@{
                severity = "pending"
                classification = "pending_uid_regeneration_candidate"
                channel = $Channel
                line_number = $LineNumber
                line = $Line
                raw_warning = $true
                source_path = $SourcePath
                uid_relative_path = $UidRelativePath
                expected_uid_value = [string]$UidCandidate.uid_value
                expected_uid_content_sha256 = `
                    [string]$UidCandidate.uid_content_sha256
                expected_uid_byte_length = `
                    [int64]$UidCandidate.uid_byte_length
            }
            continue
        }
        if ($RawWarning) {
            [pscustomobject][ordered]@{
                severity = "unclassified"
                classification = "unmatched_warning"
                channel = $Channel
                line_number = $LineNumber
                line = $Line
                raw_warning = $true
                source_path = ""
                uid_relative_path = ""
                expected_uid_value = ""
                expected_uid_content_sha256 = ""
                expected_uid_byte_length = 0
            }
        }
    }
}

function Get-McpUidRegenerationPendingSetGate {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$DiagnosticRows,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$LaunchLines,
        [Parameter(Mandatory = $true)]
        [Collections.Generic.Dictionary[string,object]]$UidCandidateMap
    )
    $ExpectedSourceSet = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $ExpectedUidSet = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $ExpectedSourceDuplicateCount = 0
    foreach ($UidPath in $UidCandidateMap.Keys) {
        $Candidate = $UidCandidateMap[$UidPath]
        if (-not $ExpectedUidSet.Add([string]$UidPath)) {
            $ExpectedSourceDuplicateCount += 1
        }
        if (-not $ExpectedSourceSet.Add([string]$Candidate.source_path)) {
            $ExpectedSourceDuplicateCount += 1
        }
    }
    $PendingRows = @(
        $DiagnosticRows | Where-Object {
            [string]$_.severity -ceq "pending" `
                -and [string]$_.classification `
                    -ceq "pending_uid_regeneration_candidate"
        }
    )
    $ActualSourceSet = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $ActualUidSet = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $DuplicateSourceCount = 0
    $DuplicateUidCount = 0
    $InvalidAuthorityBindingCount = 0
    foreach ($Row in $PendingRows) {
        if (-not $ActualSourceSet.Add([string]$Row.source_path)) {
            $DuplicateSourceCount += 1
        }
        if (-not $ActualUidSet.Add([string]$Row.uid_relative_path)) {
            $DuplicateUidCount += 1
        }
        $RowUidPath = [string]$Row.uid_relative_path
        if (-not $UidCandidateMap.ContainsKey($RowUidPath)) {
            $InvalidAuthorityBindingCount += 1
            continue
        }
        $AuthorityCandidate = $UidCandidateMap[$RowUidPath]
        $LineNumberIsIntegral = $Row.line_number -is [sbyte] `
            -or $Row.line_number -is [byte] `
            -or $Row.line_number -is [int16] `
            -or $Row.line_number -is [uint16] `
            -or $Row.line_number -is [int32] `
            -or $Row.line_number -is [uint32] `
            -or $Row.line_number -is [int64] `
            -or $Row.line_number -is [uint64]
        $ExpectedLengthIsIntegral = $Row.expected_uid_byte_length -is [sbyte] `
            -or $Row.expected_uid_byte_length -is [byte] `
            -or $Row.expected_uid_byte_length -is [int16] `
            -or $Row.expected_uid_byte_length -is [uint16] `
            -or $Row.expected_uid_byte_length -is [int32] `
            -or $Row.expected_uid_byte_length -is [uint32] `
            -or $Row.expected_uid_byte_length -is [int64] `
            -or $Row.expected_uid_byte_length -is [uint64]
        $LineNumber = if ($LineNumberIsIntegral) {
            [int64]$Row.line_number
        } else {
            [int64]0
        }
        if ([string]$Row.channel -cne "editor_launch" `
            -or $Row.raw_warning -isnot [bool] `
            -or -not [bool]$Row.raw_warning `
            -or -not $LineNumberIsIntegral `
            -or $LineNumber -le 0 `
            -or $LineNumber -gt $LaunchLines.Count `
            -or [string]$Row.line -cne [string]$LaunchLines[$LineNumber - 1] `
            -or [string]$Row.line -cne (
                'WARNING: Missing .uid file for path "res://{0}". The file was re-created from cache.' -f `
                    [string]$AuthorityCandidate.source_path
            ) `
            -or [string]$Row.source_path `
                -cne [string]$AuthorityCandidate.source_path `
            -or [string]$Row.uid_relative_path `
                -cne [string]$AuthorityCandidate.path `
            -or [string]$Row.expected_uid_value `
                -cne [string]$AuthorityCandidate.uid_value `
            -or [string]$Row.expected_uid_content_sha256 `
                -cne [string]$AuthorityCandidate.uid_content_sha256 `
            -or -not $ExpectedLengthIsIntegral `
            -or [int64]$Row.expected_uid_byte_length `
                -ne [int64]$AuthorityCandidate.uid_byte_length) {
            $InvalidAuthorityBindingCount += 1
        }
    }
    $ExpectedSourcePathSetSha256 = Get-RunnerCanonicalPathSetSha256 `
        -Paths ([string[]]@($ExpectedSourceSet))
    $ExpectedUidPathSetSha256 = Get-RunnerCanonicalPathSetSha256 `
        -Paths ([string[]]@($ExpectedUidSet))
    $ActualSourcePathSetSha256 = Get-RunnerCanonicalPathSetSha256 `
        -Paths ([string[]]@($ActualSourceSet))
    $ActualUidPathSetSha256 = Get-RunnerCanonicalPathSetSha256 `
        -Paths ([string[]]@($ActualUidSet))
    $Green = $ExpectedSourceDuplicateCount -eq 0 `
        -and $PendingRows.Count -eq $UidCandidateMap.Count `
        -and $ActualSourceSet.Count -eq $UidCandidateMap.Count `
        -and $ActualUidSet.Count -eq $UidCandidateMap.Count `
        -and $DuplicateSourceCount -eq 0 `
        -and $DuplicateUidCount -eq 0 `
        -and $InvalidAuthorityBindingCount -eq 0 `
        -and $ActualSourcePathSetSha256 -ceq $ExpectedSourcePathSetSha256 `
        -and $ActualUidPathSetSha256 -ceq $ExpectedUidPathSetSha256
    return [pscustomobject][ordered]@{
        green = $Green
        authority_count = $UidCandidateMap.Count
        pending_count = $PendingRows.Count
        pending_unique_source_count = $ActualSourceSet.Count
        pending_unique_uid_count = $ActualUidSet.Count
        duplicate_source_count = $DuplicateSourceCount
        duplicate_uid_count = $DuplicateUidCount
        invalid_authority_binding_count = $InvalidAuthorityBindingCount
        expected_source_path_set_sha256 = $ExpectedSourcePathSetSha256
        actual_source_path_set_sha256 = $ActualSourcePathSetSha256
        expected_uid_path_set_sha256 = $ExpectedUidPathSetSha256
        actual_uid_path_set_sha256 = $ActualUidPathSetSha256
    }
}

```

An embedded `capture_runtime_view` is useful only as a diagnostic that the MCP
runtime bridge is alive. In Funplay MCP 0.9.6 the PNG is returned inside
`result.structuredContent.result.data_uri`. Preserve one such capture and its
actual dimensions, but never put it into the three-size acceptance manifest:

```powershell
$CaptureRoot = ".codex-godot/mcp-validation/$ValidationRunId/embedded-diagnostic"
New-Item -ItemType Directory -Force -Path (Join-Path $Worktree $CaptureRoot) | Out-Null

function Save-McpRuntimeCapture([string]$Label) {
    $Response = Invoke-McpJson "capture_runtime_view" @{
        return_data_uri = $true
        timeout_msec = 15000
    }
    $Payload = $Response.result.structuredContent.result
    $Uri = Get-RequiredString $Payload "data_uri" "capture_runtime_view.result"
    if (-not $Uri.StartsWith("data:image/png;base64,")) {
        throw "MCP capture did not return a PNG data URI: $Label"
    }
    $PngBytes = [Convert]::FromBase64String($Uri.Substring($Uri.IndexOf(",") + 1))
    if ($PngBytes.Length -lt 24) {
        throw "MCP capture PNG is too short: $Label"
    }
    $PngSignature = [byte[]](137, 80, 78, 71, 13, 10, 26, 10)
    for ($Index = 0; $Index -lt $PngSignature.Length; $Index += 1) {
        if ($PngBytes[$Index] -ne $PngSignature[$Index]) {
            throw "MCP capture PNG signature is invalid: $Label"
        }
    }
    $IhdrWidth = ([int]$PngBytes[16] -shl 24) `
        -bor ([int]$PngBytes[17] -shl 16) `
        -bor ([int]$PngBytes[18] -shl 8) `
        -bor [int]$PngBytes[19]
    $IhdrHeight = ([int]$PngBytes[20] -shl 24) `
        -bor ([int]$PngBytes[21] -shl 16) `
        -bor ([int]$PngBytes[22] -shl 8) `
        -bor [int]$PngBytes[23]
    $DeclaredSize = Get-RequiredJsonObject `
        $Payload "size" "capture_runtime_view.result"
    $DeclaredWidth = Get-RequiredIntegralCount `
        $DeclaredSize "x" "capture_runtime_view.result.size"
    $DeclaredHeight = Get-RequiredIntegralCount `
        $DeclaredSize "y" "capture_runtime_view.result.size"
    if ($IhdrWidth -le 0 -or $IhdrHeight -le 0 `
        -or $DeclaredWidth -ne $IhdrWidth `
        -or $DeclaredHeight -ne $IhdrHeight) {
        throw "MCP capture declared size and PNG IHDR differ: $Label"
    }
    $Path = Join-Path $CaptureRoot ("{0}.png" -f $Label)
    $MirrorPath = Resolve-WorktreeChildPath $Path
    Write-AtomicBytes $MirrorPath $PngBytes
    $ExternalPath = Join-Path `
        $ValidationEvidenceRoot `
        ("embedded-runtime-{0}.png" -f $Label)
    Write-AtomicBytes $ExternalPath $PngBytes
    $PngSha256 = Get-FileSha256 $ExternalPath
    if ((Get-FileSha256 $MirrorPath) -cne $PngSha256) {
        throw "MCP capture external/mirror hashes differ: $Label"
    }
    return [pscustomobject]@{
        label = $Label
        path = "res://$($Path.Replace("\", "/"))"
        external_path = $ExternalPath
        png_sha256 = $PngSha256
        png_byte_count = $PngBytes.Length
        width = $DeclaredWidth
        height = $DeclaredHeight
        ihdr_width = $IhdrWidth
        ihdr_height = $IhdrHeight
    }
}

$EmbeddedDiagnosticCapture = Save-McpRuntimeCapture "embedded-bridge"
$EmbeddedDiagnosticCapture | Format-List
```

Editor launch resolution is not a runtime viewport resize: the embedded bridge
has previously returned `1528x917` for all three requests. Exit play mode and
stop Role A, then run the repository's headed standalone orchestrator. It
starts one isolated Godot process per fixed size, binds each visible window by
PID/HWND, samples Win32 `GetClientRect` three times, and independently parses
the PNG IHDR. All output is external evidence; only ignored PNG mirrors are
written beneath `.codex-godot` for the read-only production probe:

```powershell
$PreExitPlayState = Invoke-McpJson "get_play_state"
if (-not (Get-RequiredBoolean `
    $PreExitPlayState.result.structuredContent `
    "is_playing_scene" `
    "get_play_state.pre_exit")) {
    throw "Production play mode exited before the explicit stop boundary."
}
$null = Invoke-McpJson "exit_play_mode"
$null = Invoke-McpJson "wait_msec" @{ duration = 500 }
$StoppedPlayState = Invoke-McpJson "get_play_state"
if (Get-RequiredBoolean `
    $StoppedPlayState.result.structuredContent `
    "is_playing_scene" `
    "get_play_state.post_exit") {
    throw "Production play mode remained active after exit_play_mode."
}
"MCP_PLAY_STATE_TRANSITION_REASON=explicit_exit_play_mode"
$PreStopLogs = Invoke-McpJson "get_console_logs" @{
    severity = "all"
    include_rotated = $false
    max_lines = 4000
}
$PreStopLogReadUtc = [DateTimeOffset]::UtcNow
$PostPayload = $PreStopLogs.result.structuredContent
$PostLines = Get-RequiredJsonArray $PostPayload "lines" "get_console_logs.pre_stop"
$PostLogPath = [IO.Path]::GetFullPath(
    (Get-RequiredString $PostPayload "log_path" "get_console_logs.pre_stop")
)
if (-not $PostLogPath.Equals($RuntimeLogPath, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Final runtime console is not the cleared role-local epoch log."
}
if ((Get-RequiredIntegralCount `
        $PostPayload "line_count" "get_console_logs.pre_stop") `
        -ne $PostLines.Count `
    -or $PostLines.Count -ge 4000) {
    throw "Pre-stop console reached the MCP tail limit; epoch coverage is incomplete."
}
$StopEvidencePath = Join-Path $ValidationEvidenceRoot "role-stop.stdout.json"
$StopStderrPath = Join-Path $ValidationEvidenceRoot "role-stop.stderr.txt"
$StopInvokeErrorPath = Join-Path $ValidationEvidenceRoot "role-stop.invoke-error.json"
$StopInfo = [Diagnostics.ProcessStartInfo]::new()
$StopInfo.FileName = (Get-Command pwsh -ErrorAction Stop).Source
$StopInfo.UseShellExecute = $false
$StopInfo.CreateNoWindow = $true
$StopInfo.RedirectStandardOutput = $true
$StopInfo.RedirectStandardError = $true
foreach ($Argument in @(
    "-NoLogo", "-NoProfile", "-File", $Stop, "-Worktree", $Worktree
)) {
    $null = $StopInfo.ArgumentList.Add([string]$Argument)
}
$StopProcess = [Diagnostics.Process]::new()
$StopProcess.StartInfo = $StopInfo
$StopStartFailure = $null
try {
    if (-not $StopProcess.Start()) {
        throw "Failed to start the scoped stop process."
    }
    $StopStdoutTask = $StopProcess.StandardOutput.ReadToEndAsync()
    $StopStderrTask = $StopProcess.StandardError.ReadToEndAsync()
    $StopProcess.WaitForExit()
    $StopRawText = $StopStdoutTask.GetAwaiter().GetResult()
    $StopStderrText = $StopStderrTask.GetAwaiter().GetResult()
    $StopExitCode = $StopProcess.ExitCode
} catch {
    $StopStartFailure = $_
    $StopRawText = ""
    $StopStderrText = [string]$_
    $StopExitCode = -1
} finally {
    $StopProcess.Dispose()
}
Write-AtomicUtf8Text $StopEvidencePath $StopRawText
Write-AtomicUtf8Text $StopStderrPath $StopStderrText
if ($null -ne $StopStartFailure -or $StopExitCode -ne 0) {
    Write-AtomicUtf8Json $StopInvokeErrorPath ([ordered]@{
        schema = "SpaceSyndicateRoleStopInvocationErrorV1"
        failed_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
        exit_code = $StopExitCode
        start_failure = if ($null -eq $StopStartFailure) {
            $null
        } else {
            [string]$StopStartFailure
        }
        stdout_path = $StopEvidencePath
        stdout_sha256 = Get-FileSha256 $StopEvidencePath
        stderr_path = $StopStderrPath
        stderr_sha256 = Get-FileSha256 $StopStderrPath
    })
    throw "Role A stop failed: exit=$StopExitCode evidence=$StopInvokeErrorPath"
}
try {
    $StopResult = $StopRawText | ConvertFrom-Json
} catch {
    throw "Role A stop did not return JSON: $StopEvidencePath"
}
if (-not (Get-RequiredBoolean $StopResult "stopped" "role_stop") `
    -or (Get-RequiredBoolean $StopResult "already_exited" "role_stop") `
    -or -not (Get-RequiredBoolean $StopResult "identity_verified" "role_stop") `
    -or -not (Get-RequiredBoolean `
        $StopResult "normal_close_requested" "role_stop") `
    -or (Get-RequiredBoolean $StopResult "forced_stop" "role_stop") `
    -or (Get-RequiredIntegralCount `
        $StopResult "process_count_after" "role_stop") -ne 0 `
    -or (Get-RequiredIntegralCount `
        $StopResult "endpoint_count_after" "role_stop") -ne 0 `
    -or (Get-RequiredIntegralCount $StopResult "pid" "role_stop") `
        -ne [int64]$LaunchPid) {
    throw "Role A did not stop cleanly."
}
$RoleLifecycleClosed = $true
$RoleLifecycleStopResult = $StopResult
$StopEvidenceSha256 = Get-FileSha256 $StopEvidencePath
$StopStderrSha256 = Get-FileSha256 $StopStderrPath

$FinalLogReadUtc = [DateTimeOffset]::UtcNow
if (-not (Test-Path -LiteralPath $PostLogPath -PathType Leaf)) {
    throw "Role-local runtime log disappeared after verified stop."
}
$PostLogInfo = Get-Item -LiteralPath $PostLogPath
# NTFS may tunnel CreationTime when a same-name file is deleted and recreated.
# The pre-play absence check, exact role-local path, bounded LastWriteTime, and
# whole-file hash bind this log to the current play epoch; CreationTime remains
# recorded evidence but is not an acceptance clock.
if ($PostLogInfo.LastWriteTimeUtc -lt $PlayRequestUtc.UtcDateTime.AddSeconds(-2) `
    -or $PostLogInfo.LastWriteTimeUtc -gt $FinalLogReadUtc.UtcDateTime.AddSeconds(2)) {
    throw "Final runtime console timestamps are outside the bounded play/stop epoch."
}
$RuntimeLogBytes = [IO.File]::ReadAllBytes($PostLogPath)
$null = [Text.UTF8Encoding]::new($false, $true).GetString($RuntimeLogBytes)
$RuntimeLogSha256 = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($RuntimeLogBytes)
).ToLowerInvariant()
if (-not (Test-Path -LiteralPath $LaunchLogPath -PathType Leaf)) {
    throw "PID-bound editor launch log disappeared after verified stop."
}
$RuntimeLogEvidencePath = Join-Path $ValidationEvidenceRoot "runtime-godot.final.log"
$LaunchLogEvidencePath = Join-Path $ValidationEvidenceRoot "editor-launch.final.log"
if ((Test-Path -LiteralPath $RuntimeLogEvidencePath) `
    -or (Test-Path -LiteralPath $LaunchLogEvidencePath)) {
    throw "Console evidence destination already exists."
}
[IO.File]::Copy($PostLogPath, $RuntimeLogEvidencePath, $false)
[IO.File]::Copy($LaunchLogPath, $LaunchLogEvidencePath, $false)
if ((Get-FileSha256 $RuntimeLogEvidencePath) -cne $RuntimeLogSha256 `
    -or (Get-FileSha256 $LaunchLogEvidencePath) -cne (Get-FileSha256 $LaunchLogPath)) {
    throw "External console evidence copy failed hash verification."
}
$StrictUtf8 = [Text.UTF8Encoding]::new($false, $true)
$FinalRuntimeLogLines = @([IO.File]::ReadAllLines($RuntimeLogEvidencePath, $StrictUtf8))
$LaunchLogLines = @([IO.File]::ReadAllLines($LaunchLogEvidencePath, $StrictUtf8))
$ProjectDiagnostics = @(
    Get-McpDiagnosticRows `
        -Lines ([object[]]$LaunchLogLines) `
        -Channel "editor_launch" `
        -UidCandidateMap $UidCandidateMap
)
$RuntimeDiagnostics = @(
    Get-McpDiagnosticRows `
        -Lines ([object[]]$FinalRuntimeLogLines) `
        -Channel "runtime" `
        -UidCandidateMap $UidCandidateMap
)
$McpProjectErrorCount = (
    $ProjectScriptErrorCount `
    + @($ProjectDiagnostics | Where-Object severity -eq "error").Count
)
$McpRuntimeErrorCount = @($RuntimeDiagnostics | Where-Object severity -eq "error").Count
$McpUnclassifiedDiagnosticCount = @(
    @($ProjectDiagnostics + $RuntimeDiagnostics) |
        Where-Object severity -eq "unclassified"
).Count
$McpUidRegenerationPendingRows = @(
    $ProjectDiagnostics | Where-Object {
        [string]$_.severity -ceq "pending" `
            -and [string]$_.classification `
                -ceq "pending_uid_regeneration_candidate"
    }
)
$McpRuntimePendingDiagnosticCount = @(
    $RuntimeDiagnostics | Where-Object severity -eq "pending"
).Count
$McpRawWarningCount = @(
    @($ProjectDiagnostics + $RuntimeDiagnostics) |
        Where-Object { [bool]$_.raw_warning }
).Count
$McpUidRegenerationPendingSetGate = Get-McpUidRegenerationPendingSetGate `
    -DiagnosticRows ([object[]]$ProjectDiagnostics) `
    -LaunchLines ([object[]]$LaunchLogLines) `
    -UidCandidateMap $UidCandidateMap
if ($McpProjectErrorCount -ne 0 `
    -or $McpRuntimeErrorCount -ne 0 `
    -or $McpUnclassifiedDiagnosticCount -ne 0 `
    -or $McpRuntimePendingDiagnosticCount -ne 0 `
    -or $UidCandidateMap.Count -ne 202 `
    -or $McpRawWarningCount -ne $UidCandidateMap.Count `
    -or $McpUidRegenerationPendingRows.Count -ne $UidCandidateMap.Count `
    -or -not [bool]$McpUidRegenerationPendingSetGate.green) {
    throw (
        "MCP console diagnostics did not pass the exact pending UID " +
        "regeneration candidate gate after verified role stop."
    )
}
"MCP_PROJECT_ERROR_COUNT=$McpProjectErrorCount"
"MCP_RUNTIME_ERROR_COUNT=$McpRuntimeErrorCount"
"MCP_UNCLASSIFIED_DIAGNOSTIC_COUNT=$McpUnclassifiedDiagnosticCount"
"MCP_RAW_WARNING_COUNT=$McpRawWarningCount"
"MCP_UID_REGENERATION_PENDING_COUNT=$($McpUidRegenerationPendingRows.Count)"
"MCP_UID_REGENERATION_PENDING_SOURCE_PATH_SET_SHA256=$($McpUidRegenerationPendingSetGate.actual_source_path_set_sha256)"
"MCP_UID_REGENERATION_PENDING_UID_PATH_SET_SHA256=$($McpUidRegenerationPendingSetGate.actual_uid_path_set_sha256)"
"MCP_CONSOLE_EPOCH_BOUND=true"
"MCP_CONSOLE_EPOCH_SHA256=$ConsoleEpochSha256"
"MCP_CONSOLE_PLAY_REQUEST_UTC=$($PlayRequestUtc.ToString("o"))"
"MCP_CONSOLE_PRESTOP_READ_UTC=$($PreStopLogReadUtc.ToString("o"))"
"MCP_CONSOLE_RUNTIME_PATH=$PostLogPath"
"MCP_CONSOLE_RUNTIME_CREATION_UTC=$($PostLogInfo.CreationTimeUtc.ToString("o"))"
"MCP_CONSOLE_RUNTIME_LAST_WRITE_UTC=$($PostLogInfo.LastWriteTimeUtc.ToString("o"))"
"MCP_CONSOLE_FINAL_READ_UTC=$($FinalLogReadUtc.ToString("o"))"
"MCP_CONSOLE_PREEXISTING_ARCHIVE_SHA256=$ArchivedRuntimeLogSha256"
"MCP_CONSOLE_RUNTIME_SHA256=$RuntimeLogSha256"
"MCP_CONSOLE_EDITOR_SHA256=$(Get-FileSha256 $LaunchLogEvidencePath)"
"MCP_CONSOLE_RUNTIME_BYTE_COUNT=$($RuntimeLogBytes.Length)"
"MCP_CONSOLE_RUNTIME_LINE_COUNT=$($FinalRuntimeLogLines.Count)"
"MCP_CONSOLE_EDITOR_LINE_COUNT=$($LaunchLogLines.Count)"

$McpRawEvidenceRows = [object[]]@($script:McpRawEvidence)
$McpRawEvidenceIntegrity = Get-McpRawEvidenceIntegrityGate `
    -Rows $McpRawEvidenceRows `
    -RawRoot $McpRawEvidenceRoot
if (-not [bool]$McpRawEvidenceIntegrity.green `
    -or [int]$McpRawEvidenceIntegrity.failed_attempt_count -ne 0 `
    -or [int]$McpRawEvidenceIntegrity.invoke_error_count -ne 0 `
    -or [int]$McpRawEvidenceIntegrity.orphan_invoke_error_count -ne 0 `
    -or [int]$McpRawEvidenceIntegrity.orphan_raw_response_count -ne 0 `
    -or [int]$McpRawEvidenceIntegrity.missing_raw_response_count -ne 0 `
    -or [int]$McpRawEvidenceIntegrity.actual_raw_response_count `
        -ne $McpRawEvidenceRows.Count `
    -or [int]$McpRawEvidenceIntegrity.ledger_raw_response_count `
        -ne $McpRawEvidenceRows.Count `
    -or [int]$McpRawEvidenceIntegrity.validated_success_count `
        -ne $McpRawEvidenceRows.Count `
    -or [int]$McpRawEvidenceIntegrity.raw_file_verified_count `
        -ne $McpRawEvidenceRows.Count) {
    throw (
        "MCP raw evidence ledger failed its success boundary: {0}" -f
        ($McpRawEvidenceIntegrity | ConvertTo-Json -Depth 12 -Compress)
    )
}
$McpRawEvidenceManifest = [ordered]@{
    schema = "SpaceSyndicateExactShaMcpRawEvidenceManifestV2"
    head_sha = $HeadSha
    tree_sha = $TreeSha
    launch_pid = [int]$LaunchResult.pid
    launch_process_start_utc = $LaunchProcessStartUtc.ToString("o")
    response_count = $McpRawEvidenceRows.Count
    sequence_first = [int]$McpRawEvidenceIntegrity.sequence_first
    sequence_last = [int]$McpRawEvidenceIntegrity.sequence_last
    validated_success_count = `
        [int]$McpRawEvidenceIntegrity.validated_success_count
    failed_attempt_count = [int]$McpRawEvidenceIntegrity.failed_attempt_count
    invoke_error_count = [int]$McpRawEvidenceIntegrity.invoke_error_count
    orphan_invoke_error_count = `
        [int]$McpRawEvidenceIntegrity.orphan_invoke_error_count
    actual_raw_response_count = `
        [int]$McpRawEvidenceIntegrity.actual_raw_response_count
    ledger_raw_response_count = `
        [int]$McpRawEvidenceIntegrity.ledger_raw_response_count
    orphan_raw_response_count = `
        [int]$McpRawEvidenceIntegrity.orphan_raw_response_count
    orphan_raw_response_paths = `
        [object[]]$McpRawEvidenceIntegrity.orphan_raw_response_paths
    missing_raw_response_count = `
        [int]$McpRawEvidenceIntegrity.missing_raw_response_count
    missing_raw_response_paths = `
        [object[]]$McpRawEvidenceIntegrity.missing_raw_response_paths
    raw_file_verified_count = `
        [int]$McpRawEvidenceIntegrity.raw_file_verified_count
    integrity_green = [bool]$McpRawEvidenceIntegrity.green
    integrity = $McpRawEvidenceIntegrity
    responses = $McpRawEvidenceRows
}
$McpRawEvidenceManifestPath = Join-Path `
    $ValidationEvidenceRoot `
    "mcp-raw-evidence-manifest.json"
Write-AtomicUtf8Json $McpRawEvidenceManifestPath $McpRawEvidenceManifest
$McpRawEvidenceManifestSha256 = Get-FileSha256 $McpRawEvidenceManifestPath
"MCP_RAW_RESPONSE_COUNT=$($McpRawEvidenceRows.Count)"
"MCP_RAW_VALIDATED_SUCCESS_COUNT=$($McpRawEvidenceIntegrity.validated_success_count)"
"MCP_RAW_FAILED_ATTEMPT_COUNT=$($McpRawEvidenceIntegrity.failed_attempt_count)"
"MCP_RAW_INVOKE_ERROR_COUNT=$($McpRawEvidenceIntegrity.invoke_error_count)"
"MCP_RAW_ORPHAN_INVOKE_ERROR_COUNT=$($McpRawEvidenceIntegrity.orphan_invoke_error_count)"
"MCP_RAW_ACTUAL_RESPONSE_COUNT=$($McpRawEvidenceIntegrity.actual_raw_response_count)"
"MCP_RAW_LEDGER_RESPONSE_COUNT=$($McpRawEvidenceIntegrity.ledger_raw_response_count)"
"MCP_RAW_ORPHAN_RESPONSE_COUNT=$($McpRawEvidenceIntegrity.orphan_raw_response_count)"
"MCP_RAW_MISSING_RESPONSE_COUNT=$($McpRawEvidenceIntegrity.missing_raw_response_count)"
"MCP_RAW_INTEGRITY_GREEN=$($McpRawEvidenceIntegrity.green.ToString().ToLowerInvariant())"
"MCP_RAW_EVIDENCE_MANIFEST_SHA256=$McpRawEvidenceManifestSha256"

$PostMcpCleanupIssues = [Collections.Generic.List[string]]::new()
$PostMcpTransientCleanup = Invoke-RunnerTransientFailureCleanup `
    -Worktree $Worktree `
    -EvidenceRoot $ValidationEvidenceRoot `
    -FailureId "post-mcp-pre-viewport" `
    -Context "post_mcp_pre_viewport" `
    -Issues $PostMcpCleanupIssues
if ($PostMcpCleanupIssues.Count -ne 0 `
    -or -not [bool]$PostMcpTransientCleanup.cleanup_green `
    -or [string]$PostMcpTransientCleanup.uid_state `
        -cne "EXACT_EXTERNAL_ALLOWLIST" `
    -or @(
        "HEAD_CLEAN",
        "CANONICAL_GENERATED_SUBSET",
        "CANONICAL_GENERATED_57"
    ) `
        -cnotcontains [string]$PostMcpTransientCleanup.import_state) {
    throw (
        "Post-MCP exact transient cleanup failed before headed capture: " +
        ($PostMcpCleanupIssues -join " | ")
    )
}
$PostMcpTransientObservationPath = [string](
    $PostMcpTransientCleanup.observation_evidence_path
)
if ([string]::IsNullOrWhiteSpace($PostMcpTransientObservationPath) `
    -or -not (Test-Path `
        -LiteralPath $PostMcpTransientObservationPath `
        -PathType Leaf)) {
    throw "Post-MCP transient cleanup evidence is missing."
}
$PostMcpTransientObservationSha256 = Get-FileSha256 `
    $PostMcpTransientObservationPath
$PostMcpTransientObservationBytes = [IO.File]::ReadAllBytes(
    $PostMcpTransientObservationPath
)
$PostMcpTransientObservation = (
    [Text.UTF8Encoding]::new($false, $true).GetString(
        $PostMcpTransientObservationBytes
    ) | ConvertFrom-Json
)
$PostMcpSafeUidCandidates = @(
    $PostMcpTransientObservation.safe_uid_candidates
)
$PostMcpUidEvidenceRows = @($PostMcpTransientObservation.uid_evidence)
$PostMcpSafeUidByPath = [Collections.Generic.Dictionary[string,object]]::new(
    [StringComparer]::Ordinal
)
foreach ($SafeUidCandidate in $PostMcpSafeUidCandidates) {
    $SafeUidPath = [string]$SafeUidCandidate.path
    if ($PostMcpSafeUidByPath.ContainsKey($SafeUidPath)) {
        throw "Post-MCP UID observation contains a duplicate candidate: $SafeUidPath"
    }
    $PostMcpSafeUidByPath.Add($SafeUidPath, $SafeUidCandidate)
}
$PostMcpUidEvidenceByPath = `
    [Collections.Generic.Dictionary[string,object]]::new(
        [StringComparer]::Ordinal
    )
foreach ($UidEvidenceRow in $PostMcpUidEvidenceRows) {
    $UidEvidenceRelativePath = [string]$UidEvidenceRow.path
    if ($PostMcpUidEvidenceByPath.ContainsKey($UidEvidenceRelativePath)) {
        throw (
            "Post-MCP UID observation contains duplicate byte evidence: " +
            $UidEvidenceRelativePath
        )
    }
    $PostMcpUidEvidenceByPath.Add($UidEvidenceRelativePath, $UidEvidenceRow)
}
$PostMcpRemovedUidPaths = [string[]]@(
    $PostMcpTransientCleanup.safe_uid_cleanup
)
$PostMcpRemovedUidPathSetSha256 = Get-RunnerCanonicalPathSetSha256 `
    -Paths $PostMcpRemovedUidPaths
$UidRegenerationExactByteMatchCount = 0
foreach ($AuthorizedUidPath in $UidCandidateMap.Keys) {
    if (-not $PostMcpSafeUidByPath.ContainsKey($AuthorizedUidPath) `
        -or -not $PostMcpUidEvidenceByPath.ContainsKey($AuthorizedUidPath)) {
        throw "Post-MCP UID exact-byte evidence is missing: $AuthorizedUidPath"
    }
    $AuthorizedUidCandidate = $UidCandidateMap[$AuthorizedUidPath]
    $ObservedSafeUidCandidate = $PostMcpSafeUidByPath[$AuthorizedUidPath]
    $ObservedUidEvidence = $PostMcpUidEvidenceByPath[$AuthorizedUidPath]
    $ObservedUidEvidencePath = [string]$ObservedUidEvidence.evidence_path
    if ([string]$ObservedSafeUidCandidate.source_path `
            -cne [string]$AuthorizedUidCandidate.source_path `
        -or [string]$ObservedSafeUidCandidate.uid_value `
            -cne [string]$AuthorizedUidCandidate.uid_value `
        -or [string]$ObservedSafeUidCandidate.uid_sha256 `
            -cne [string]$AuthorizedUidCandidate.uid_content_sha256 `
        -or [int64]$ObservedSafeUidCandidate.uid_byte_length `
            -ne [int64]$AuthorizedUidCandidate.uid_byte_length `
        -or [string]::IsNullOrWhiteSpace($ObservedUidEvidencePath) `
        -or -not (Test-Path `
            -LiteralPath $ObservedUidEvidencePath `
            -PathType Leaf) `
        -or [string]$ObservedUidEvidence.sha256 `
            -cne [string]$AuthorizedUidCandidate.uid_content_sha256 `
        -or [int64]$ObservedUidEvidence.byte_count `
            -ne [int64]$AuthorizedUidCandidate.uid_byte_length `
        -or (Get-FileSha256 $ObservedUidEvidencePath) `
            -cne [string]$AuthorizedUidCandidate.uid_content_sha256) {
        throw "Post-MCP UID bytes differ from authority: $AuthorizedUidPath"
    }
    $UidRegenerationExactByteMatchCount += 1
}
if ([string]$PostMcpTransientObservation.schema `
        -cne "SpaceSyndicateV075McpRunbookTransientObservationV2" `
    -or [string]$PostMcpTransientObservation.context `
        -cne "post_mcp_pre_viewport" `
    -or [string]$PostMcpTransientObservation.frozen_head -cne $HeadSha `
    -or [string]$PostMcpTransientObservation.frozen_tree -cne $TreeSha `
    -or [string]$PostMcpTransientObservation.current_head -cne $HeadSha `
    -or [string]$PostMcpTransientObservation.current_tree -cne $TreeSha `
    -or [string]$PostMcpTransientObservation.authority_sha256 `
        -cne $TransientArtifactAuthoritySha256 `
    -or [string]$PostMcpTransientObservation.generated_uid_state `
        -cne "EXACT_EXTERNAL_ALLOWLIST" `
    -or @($PostMcpTransientObservation.observation_only_reasons).Count -ne 0 `
    -or @($PostMcpTransientObservation.unsafe_uid).Count -ne 0 `
    -or @($PostMcpTransientObservation.unknown_untracked_drift).Count -ne 0 `
    -or @($PostMcpTransientObservation.unexpected_ignored_uid_paths).Count -ne 0 `
    -or [int]$PostMcpTransientObservation.generated_uid_missing_count -ne 0 `
    -or $PostMcpSafeUidByPath.Count -ne $UidCandidateMap.Count `
    -or $PostMcpUidEvidenceByPath.Count -ne $UidCandidateMap.Count `
    -or $UidRegenerationExactByteMatchCount -ne $UidCandidateMap.Count `
    -or $PostMcpRemovedUidPaths.Count -ne $UidCandidateMap.Count `
    -or $PostMcpRemovedUidPathSetSha256 `
        -cne [string]$McpUidRegenerationPendingSetGate.actual_uid_path_set_sha256) {
    throw "Post-MCP UID warning promotion evidence is incomplete or cross-epoch."
}
$PostMcpCleanupResultEvidence = [ordered]@{
    schema = "SpaceSyndicateExactShaPostMcpCleanupResultV1"
    completed_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
    head_sha = $HeadSha
    tree_sha = $TreeSha
    context = "post_mcp_pre_viewport"
    issues = @($PostMcpCleanupIssues)
    observation_only = [bool]$PostMcpTransientCleanup.observation_only
    observation_path = $PostMcpTransientObservationPath
    observation_sha256 = $PostMcpTransientObservationSha256
    import_state = [string]$PostMcpTransientCleanup.import_state
    uid_state = [string]$PostMcpTransientCleanup.uid_state
    import_restore_count = @(
        $PostMcpTransientCleanup.safe_import_cleanup
    ).Count
    uid_remove_count = @($PostMcpTransientCleanup.safe_uid_cleanup).Count
    final_head = [string]$PostMcpTransientCleanup.final_head
    final_tree = [string]$PostMcpTransientCleanup.final_tree
    final_status = @($PostMcpTransientCleanup.final_status)
    final_tracked_drift = @($PostMcpTransientCleanup.final_tracked_drift)
    final_untracked_drift = @($PostMcpTransientCleanup.final_untracked_drift)
    final_unexpected_ignored_uid_paths = @(
        $PostMcpTransientCleanup.final_unexpected_ignored_uid_paths
    )
    cleanup_green = [bool]$PostMcpTransientCleanup.cleanup_green
}
$PostMcpCleanupResultEvidencePath = Join-Path `
    $ValidationEvidenceRoot `
    "post-mcp-cleanup-result.json"
Write-AtomicUtf8Json `
    -Path $PostMcpCleanupResultEvidencePath `
    -Value $PostMcpCleanupResultEvidence
$PostMcpCleanupResultEvidenceSha256 = Get-FileSha256 `
    $PostMcpCleanupResultEvidencePath
$PostMcpObservedAtUtc = [DateTimeOffset]::MinValue
if (-not [DateTimeOffset]::TryParse(
        [string]$PostMcpTransientObservation.observed_at_utc,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::RoundtripKind,
        [ref]$PostMcpObservedAtUtc
    ) `
    -or $PostMcpObservedAtUtc -lt $FinalLogReadUtc) {
    throw "Post-MCP cleanup observation is outside the stopped Role-A epoch."
}
$UidRegenerationControlledAtUtc = [DateTimeOffset]::UtcNow
if ($PostMcpObservedAtUtc -gt $UidRegenerationControlledAtUtc) {
    throw "Post-MCP cleanup observation timestamp is in the future."
}
$UidRegenerationEditorConsoleSha256 = Get-FileSha256 $LaunchLogEvidencePath
$UidRegenerationLaunchEpochIdentity = "{0}|{1}|{2}|{3}|{4}|{5}" -f @(
    $HeadSha,
    $TreeSha,
    [int]$LaunchResult.pid,
    $LaunchProcessStartUtc.ToString("o"),
    $LaunchLogEvidencePath.ToLowerInvariant(),
    $UidRegenerationEditorConsoleSha256
)
$UidRegenerationLaunchEpochSha256 = Get-RunnerCanonicalSha256Hex -Bytes (
    [Text.UTF8Encoding]::new($false, $true).GetBytes(
        $UidRegenerationLaunchEpochIdentity
    )
)
$ControlledUidRegenerationWarningRows = @(
    foreach ($PendingUidWarning in $McpUidRegenerationPendingRows) {
        [pscustomobject][ordered]@{
            line_number = [int64]$PendingUidWarning.line_number
            line = [string]$PendingUidWarning.line
            channel = [string]$PendingUidWarning.channel
            raw_warning = [bool]$PendingUidWarning.raw_warning
            source_path = [string]$PendingUidWarning.source_path
            uid_relative_path = [string]$PendingUidWarning.uid_relative_path
            expected_uid_value = [string]$PendingUidWarning.expected_uid_value
            expected_uid_content_sha256 = `
                [string]$PendingUidWarning.expected_uid_content_sha256
            expected_uid_byte_length = `
                [int64]$PendingUidWarning.expected_uid_byte_length
            initial_classification = "pending_uid_regeneration_candidate"
            final_classification = "controlled_uid_regeneration"
        }
    }
)
$UidRegenerationWarningReceipt = [ordered]@{
    schema = "SpaceSyndicateExactShaUidRegenerationWarningReceiptV1"
    status = "CONTROLLED"
    transition = `
        "pending_uid_regeneration_candidate->controlled_uid_regeneration"
    controlled_at_utc = $UidRegenerationControlledAtUtc.ToString("o")
    cleanup_observed_at_utc = $PostMcpObservedAtUtc.ToString("o")
    head_sha = $HeadSha
    tree_sha = $TreeSha
    initial_manifest_path = $ExactShaManifestPath
    initial_manifest_evidence_sha256 = $ExactShaManifestEvidenceSha256
    initial_uid_present_count = 0
    launch_pid = [int]$LaunchResult.pid
    launch_process_start_utc = $LaunchProcessStartUtc.ToString("o")
    launch_epoch_sha256 = $UidRegenerationLaunchEpochSha256
    console_epoch_sha256 = $ConsoleEpochSha256
    runtime_console_path = $RuntimeLogEvidencePath
    runtime_console_sha256 = $RuntimeLogSha256
    editor_console_path = $LaunchLogEvidencePath
    editor_console_sha256 = $UidRegenerationEditorConsoleSha256
    allowlist_source_path = $UidAllowlistSourcePath
    allowlist_sha256 = $UidAllowlistSourceSha256
    allowlist_entry_set_sha256 = `
        [string]$UidAllowlistValidation.uid_entry_set_sha256
    allowlist_entry_count = $UidCandidateMap.Count
    raw_warning_count = $McpRawWarningCount
    pending_candidate_count = $McpUidRegenerationPendingRows.Count
    controlled_warning_count = $ControlledUidRegenerationWarningRows.Count
    runtime_warning_count = @(
        $RuntimeDiagnostics | Where-Object { [bool]$_.raw_warning }
    ).Count
    unclassified_diagnostic_count = $McpUnclassifiedDiagnosticCount
    source_path_set_sha256 = `
        [string]$McpUidRegenerationPendingSetGate.actual_source_path_set_sha256
    uid_path_set_sha256 = `
        [string]$McpUidRegenerationPendingSetGate.actual_uid_path_set_sha256
    uid_exact_state = [string]$PostMcpTransientCleanup.uid_state
    uid_exact_byte_match_count = $UidRegenerationExactByteMatchCount
    uid_cleanup_remove_count = $PostMcpRemovedUidPaths.Count
    cleanup_green = [bool]$PostMcpTransientCleanup.cleanup_green
    cleanup_context = "post_mcp_pre_viewport"
    cleanup_observation_path = $PostMcpTransientObservationPath
    cleanup_observation_sha256 = $PostMcpTransientObservationSha256
    cleanup_result_path = $PostMcpCleanupResultEvidencePath
    cleanup_result_sha256 = $PostMcpCleanupResultEvidenceSha256
    warnings = $ControlledUidRegenerationWarningRows
}
$UidRegenerationWarningReceiptPath = Join-Path `
    $ValidationEvidenceRoot `
    "uid-regeneration-warning-classification-receipt.json"
Write-AtomicUtf8Json `
    -Path $UidRegenerationWarningReceiptPath `
    -Value $UidRegenerationWarningReceipt
$UidRegenerationWarningReceiptSha256 = Get-FileSha256 `
    $UidRegenerationWarningReceiptPath
"MCP_POST_MCP_TRANSIENT_CLEANUP_GREEN=true"
"MCP_POST_MCP_TRANSIENT_OBSERVATION_SHA256=$PostMcpTransientObservationSha256"
"MCP_UID_REGENERATION_CONTROLLED_COUNT=$($ControlledUidRegenerationWarningRows.Count)"
"MCP_UID_REGENERATION_WARNING_RECEIPT_SHA256=$UidRegenerationWarningReceiptSha256"

$ViewportEvidenceRoot = Join-Path $ValidationEvidenceRoot "headed-viewports"
$ViewportRaw = & pwsh -NoLogo -NoProfile -File `
    (Join-Path $Worktree "tools\invoke_v075_responsive_viewport_capture.ps1") `
    -ProjectPath $Worktree `
    -GodotPath $Godot `
    -EvidenceRoot $ViewportEvidenceRoot `
    -SourceSha $HeadSha `
    -TreeSha $TreeSha
$ViewportExitCode = $LASTEXITCODE
$ViewportInvocationEvidencePath = Join-Path `
    $ValidationEvidenceRoot `
    "headed-viewport-invocation.stdout.txt"
Write-AtomicUtf8Text `
    $ViewportInvocationEvidencePath `
    (@($ViewportRaw) -join [Environment]::NewLine)
if ($ViewportExitCode -ne 0) {
    throw "Headed responsive viewport capture failed."
}
$ViewportAggregate = ($ViewportRaw | Select-Object -Last 1) | ConvertFrom-Json
if ((Get-RequiredString $ViewportAggregate "status" "headed_viewport_aggregate") `
        -cne "AUTOMATION_GREEN_PENDING_VISUAL_REVIEW" `
    -or (Get-RequiredIntegralCount `
        $ViewportAggregate "green_case_count" "headed_viewport_aggregate") -ne 3 `
    -or (Get-RequiredIntegralCount `
        $ViewportAggregate "distinct_png_sha256_count" "headed_viewport_aggregate") `
        -ne 3) {
    throw "Three headed viewport automation gates did not pass."
}
$ViewportAggregateEvidencePath = Join-Path `
    $ValidationEvidenceRoot `
    "headed-viewport-aggregate.json"
Write-AtomicUtf8Json $ViewportAggregateEvidencePath $ViewportAggregate
$ViewportInvocationEvidenceSha256 = Get-FileSha256 $ViewportInvocationEvidencePath
$ViewportAggregateEvidenceSha256 = Get-FileSha256 $ViewportAggregateEvidencePath
```

Each automatic case requires exact equality among the fixed requested client
size, Godot `Window.size` (the runtime `Window` viewport),
`DisplayServer.window_get_size`, external Win32 client rect immediately before
and after capture, original client capture, and independent PNG IHDR. The
Godot viewport and DisplayServer sizes are sampled again after the external
capture. The internal backing render texture and logical stretch rect are
recorded separately because the
production `canvas_items/expand` transform may render them at a different
resolution. A client/PNG mismatch fails the command; images are never resized
or relabelled. The driver
uses a typed test projection solely to populate the real production
`main.tscn -> V075RuntimeComposition -> V075SampleGameScreen -> CombatSurface`
presentation. Its receipt must remain explicit:

```text
staging_mode=typed_test_projection
natural_runtime_state=false
gameplay_acceptance=false
test_fixture_wired_into_production=false
evidence_scope=HEADED_RESPONSIVE_PRESENTATION_PREFLIGHT
```

This presentation evidence complements, but cannot replace, the live runtime
identity and real child-runtime UI action/receipt/consumption evidence above,
or the separately scoped exact-SHA simulation. Automatic success is still
`AUTOMATION_GREEN_PENDING_VISUAL_REVIEW`; inspect all three external PNGs for
combat visibility, readable military identities, text clipping, missing
textures, rival-private leakage, planet occlusion, and asset-lane overlap
before setting the three visual gates green in the external ledger.

## Headless Read-Only Probe

The existing runner is the repository's deterministic Godot test path. It
uses the GUI Godot executable in headless mode, isolated `APPDATA`/
`LOCALAPPDATA`, bounded timeouts, process-tree cleanup, and completion-marker
checking. Role A is already stopped above. The ignored manifest paths and
expected dimensions below are fixed request values, never values copied from
the captured payload:

```powershell
$env:V075_MCP_SCREENSHOTS = @(
    "1366x768|res://.codex-godot/mcp-validation/headed-responsive/v075-1366x768.png|1366|768",
    "1600x960|res://.codex-godot/mcp-validation/headed-responsive/v075-1600x960.png|1600|960",
    "1920x1080|res://.codex-godot/mcp-validation/headed-responsive/v075-1920x1080.png|1920|1080"
) -join ";"

$ProbeResult = @(& pwsh -NoProfile -File `
    (Join-Path $Worktree "tools\invoke_godot_test.ps1") `
    -ProjectPath $Worktree `
    -GodotPath $Godot `
    -TestScript "res://tests/v075_mcp_production_probe.gd" `
    -ExpectedCompletionMarker "V075_MCP_PRODUCTION_PROBE|" `
    -TimeoutSeconds 180)
$ProbeExitCode = $LASTEXITCODE
$ProbeResult
$ProbeEvidencePath = Join-Path `
    $ValidationEvidenceRoot `
    "headless-production-probe.stdout.txt"
Write-AtomicUtf8Text `
    $ProbeEvidencePath `
    (@($ProbeResult) -join [Environment]::NewLine)
$ProbeEvidenceSha256 = Get-FileSha256 $ProbeEvidencePath
if ($ProbeExitCode -ne 0) {
    throw "MCP production probe failed: exit=$ProbeExitCode evidence=$ProbeEvidencePath"
}
```

The probe's `status=PASS` means all supplied static manifests and the three
fixed-dimension PNG mirrors passed. Its `v075_production_wiring_gap=true` is a
failure signal for this cutover, not an expected V0.7.4 handoff. The external
orchestrator receipts, Win32 samples, PNG hashes, and human review remain the
visual authority; the ignored copies exist only so the probe can independently
re-read PNG signatures and IHDR dimensions.

## Shutdown And Evidence

Role A was stopped and verified before headed capture. Do not issue an
unconditional second stop. Preserve and record the parsed `$StopResult`:

```powershell
$StopResult | ConvertTo-Json -Depth 10
if (-not (Get-RequiredBoolean $StopResult "stopped" "role_stop.final") `
    -or (Get-RequiredBoolean $StopResult "already_exited" "role_stop.final") `
    -or -not (Get-RequiredBoolean `
        $StopResult "identity_verified" "role_stop.final") `
    -or -not (Get-RequiredBoolean `
        $StopResult "normal_close_requested" "role_stop.final") `
    -or (Get-RequiredBoolean $StopResult "forced_stop" "role_stop.final") `
    -or (Get-RequiredIntegralCount `
        $StopResult "process_count_after" "role_stop.final") -ne 0 `
    -or (Get-RequiredIntegralCount `
        $StopResult "endpoint_count_after" "role_stop.final") -ne 0 `
    -or (Get-RequiredIntegralCount $StopResult "pid" "role_stop.final") `
        -ne [int64]$LaunchPid) {
    throw "Final role stop evidence is not clean."
}

$CachedDrift = @(
    Invoke-CheckedGit -Arguments @(
        "-c", "core.quotepath=false", "diff", "--cached", "--name-only"
    )
)
if ($CachedDrift.Count -ne 0) {
    throw "Validation unexpectedly changed the Git index."
}
$TrackedDrift = @(
    Invoke-CheckedGit -Arguments @(
        "-c", "core.quotepath=false", "diff", "--no-renames",
        "--name-only", "HEAD", "--"
    ) |
        ForEach-Object { $_.Trim().Replace("\", "/") } |
        Where-Object { $_ }
)
$UnexpectedTracked = @(
    $TrackedDrift | Where-Object { -not $ImportCandidateMap.ContainsKey($_) }
)
if ($UnexpectedTracked.Count -ne 0) {
    throw (
        "Validation changed paths outside the frozen import authority:`n{0}" -f
        ($UnexpectedTracked -join "`n")
    )
}
$CurrentCanonicalImportRows = [object[]]@(
    foreach ($RelativeImportPath in $CanonicalImportPaths) {
        $AbsoluteImportPath = Resolve-WorktreeChildPath $RelativeImportPath
        if (-not (Test-Path -LiteralPath $AbsoluteImportPath -PathType Leaf)) {
            throw "Canonical import file is missing: $RelativeImportPath"
        }
        [pscustomobject][ordered]@{
            path = $RelativeImportPath
            content_sha256 = Get-FileSha256 $AbsoluteImportPath
        }
    }
)
$CanonicalImportAssessment = Test-RunnerCanonicalImportState `
    -CandidateMap $ImportCandidateMap `
    -ReportedPaths ([string[]]$TrackedDrift) `
    -CurrentRows $CurrentCanonicalImportRows
if (-not [bool]$CanonicalImportAssessment.green) {
    throw (
        "Tracked import drift failed the frozen per-path authority: {0}" -f
        (@($CanonicalImportAssessment.issues) -join ",")
    )
}
$CanonicalImportState = [string]$CanonicalImportAssessment.state
$TransientImports = [string[]]@($CanonicalImportAssessment.safe_paths)
$PostRunCanonicalImportMapSha256 = Get-RunnerCanonicalFileMapSha256 `
    -Root $Worktree `
    -Paths $CanonicalImportPaths
if ($CanonicalImportState -ceq "HEAD_CLEAN" `
    -and $PostRunCanonicalImportMapSha256 `
        -cne [string]$CanonicalImportAuthority.baseline_map_sha256) {
    throw "Canonical clean import map differs from the frozen HEAD baseline."
}
if ($CanonicalImportState -ceq "CANONICAL_GENERATED_57" `
    -and $PostRunCanonicalImportMapSha256 `
        -cne [string]$CanonicalImportAuthority.generated_map_sha256) {
    throw "Canonical full import map differs from the frozen generated state."
}
$ObservedImports = @(
    foreach ($RelativeImportPath in $TransientImports) {
        $Candidate = $ImportCandidateMap[$RelativeImportPath]
        $AbsoluteImportPath = Resolve-WorktreeChildPath $RelativeImportPath
        if ($null -eq $Candidate `
            -or -not (Test-Path -LiteralPath $AbsoluteImportPath -PathType Leaf) `
            -or (Get-HeadBlobSha $RelativeImportPath) `
                -cne [string]$Candidate.head_blob_sha `
            -or (Get-FileSha256 $AbsoluteImportPath) `
                -cne [string]$Candidate.generated_content_sha256) {
            throw "Canonical import HEAD identity changed: $RelativeImportPath"
        }
        [pscustomobject][ordered]@{
            path = $RelativeImportPath
            before_sha256 = [string]$Candidate.baseline_content_sha256
            after_sha256 = Get-FileSha256 $AbsoluteImportPath
        }
    }
)

$AllUntracked = @(
    Invoke-CheckedGit -Arguments @(
        "-c", "core.quotepath=false", "ls-files",
        "--others", "--exclude-standard"
    ) |
        ForEach-Object { $_.Trim().Replace("\", "/") } |
        Where-Object { $_ }
)
$UnexpectedUntracked = @(
    $AllUntracked | Where-Object { -not $UidCandidateMap.ContainsKey($_) }
)
if ($UnexpectedUntracked.Count -ne 0) {
    throw (
        "Validation created paths outside the frozen UID authority:`n{0}" -f
        ($UnexpectedUntracked -join "`n")
    )
}
$TransientUids = [string[]]@(
    $AllUntracked | Where-Object { $UidCandidateMap.ContainsKey($_) }
)
$MissingUids = [string[]]@(
    $UidCandidateMap.Keys | Where-Object { $AllUntracked -cnotcontains $_ }
)
$PostViewportUidState = if (
    $TransientUids.Count -eq 0 `
    -and $MissingUids.Count -eq $UidCandidateMap.Count
) {
    "ABSENT"
} elseif (
    $TransientUids.Count -eq $UidCandidateMap.Count `
    -and $MissingUids.Count -eq 0
) {
    "EXACT_EXTERNAL_ALLOWLIST"
} else {
    throw (
        "Post-viewport generated UID state is partial or tampered: " +
        "observed=$($TransientUids.Count) missing=$($MissingUids.Count)"
    )
}
$ExpectedPostViewportUidRemoveCount = if (
    $PostViewportUidState -ceq "EXACT_EXTERNAL_ALLOWLIST"
) { $UidCandidateMap.Count } else { 0 }
$ExpectedPostViewportUidMissingCount = if (
    $PostViewportUidState -ceq "ABSENT"
) { $UidCandidateMap.Count } else { 0 }
$IgnoredUidRows = @(
    Invoke-CheckedGit -Arguments @(
        "-c", "core.quotepath=false", "ls-files", "--others", "--ignored",
        "--exclude-standard", "--", "*.gd.uid", "*.gdshader.uid"
    ) |
        ForEach-Object { $_.Trim().Replace("\", "/") } |
        Where-Object {
            $_ -and -not $_.StartsWith(".godot/", [StringComparison]::Ordinal) `
                -and -not $_.StartsWith(
                    ".codex-godot/",
                    [StringComparison]::Ordinal
                )
        }
)
if ($IgnoredUidRows.Count -ne 0) {
    throw "Ignored generated UID files exist outside trusted cache roots."
}

$ObservedUidEvidenceRoot = Join-Path $ValidationEvidenceRoot "generated-uid-bytes"
$ObservedUids = @(
    foreach ($RelativeUidPath in @($TransientUids | Sort-Object)) {
        $Candidate = $UidCandidateMap[$RelativeUidPath]
        $AbsoluteUidPath = Resolve-WorktreeChildPath $RelativeUidPath
        $AbsoluteSourcePath = Resolve-WorktreeChildPath ([string]$Candidate.source_path)
        if (-not (Test-Path -LiteralPath $AbsoluteSourcePath -PathType Leaf) `
            -or (Get-FileSha256 $AbsoluteSourcePath) -cne [string]$Candidate.source_sha256 `
            -or (Get-HeadBlobSha ([string]$Candidate.source_path)) `
                -cne [string]$Candidate.source_head_blob_sha) {
            throw "Generated UID source identity changed: $RelativeUidPath"
        }
        $UidBytes = [IO.File]::ReadAllBytes($AbsoluteUidPath)
        $UidSha256 = Get-RunnerCanonicalSha256Hex -Bytes $UidBytes
        try {
            $UidText = [Text.UTF8Encoding]::new($false, $true).GetString($UidBytes)
        } catch {
            throw "Generated UID is not strict UTF-8: $RelativeUidPath"
        }
        $UidValue = $UidText.TrimEnd([char[]]@("`r", "`n"))
        if (-not [regex]::IsMatch(
                $UidText,
                "\Auid://[a-z0-9]+(?:\r?\n)?\z",
                [Text.RegularExpressions.RegexOptions]::CultureInvariant
            ) `
            -or $UidValue -cne [string]$Candidate.uid_value `
            -or $UidSha256 -cne [string]$Candidate.uid_content_sha256 `
            -or [int64]$UidBytes.Length -ne [int64]$Candidate.uid_byte_length) {
            throw "Generated UID value/hash/length differs: $RelativeUidPath"
        }
        $UidPathHash = Get-RunnerCanonicalSha256Hex -Bytes (
            [Text.UTF8Encoding]::new($false, $true).GetBytes($RelativeUidPath)
        )
        $UidEvidencePath = Join-Path `
            $ObservedUidEvidenceRoot `
            "$UidPathHash.uid.bin"
        Write-AtomicBytes -Path $UidEvidencePath -Value $UidBytes
        [pscustomobject][ordered]@{
            path = $RelativeUidPath
            source_path = [string]$Candidate.source_path
            source_sha256 = [string]$Candidate.source_sha256
            source_head_blob_sha = [string]$Candidate.source_head_blob_sha
            expected_uid_value = [string]$Candidate.uid_value
            actual_uid_value = $UidValue
            expected_uid_content_sha256 = `
                [string]$Candidate.uid_content_sha256
            actual_uid_content_sha256 = $UidSha256
            expected_uid_byte_length = [int64]$Candidate.uid_byte_length
            actual_uid_byte_length = [int64]$UidBytes.Length
            evidence_path = $UidEvidencePath
            evidence_sha256 = Get-FileSha256 $UidEvidencePath
        }
    }
)

$ImportDiffText = ""
if ($TransientImports.Count -gt 0) {
    $DiffArguments = @(
        "-C", $Worktree, "-c", "core.quotepath=false",
        "diff", "--binary", "--"
    ) + @($TransientImports)
    $ImportDiffText = @(& git @DiffArguments) -join "`n"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to capture raw transient import diff evidence."
    }
}
$ImportDiffPath = Join-Path $ValidationEvidenceRoot "transient-import-diff.patch"
Write-AtomicUtf8Text $ImportDiffPath $ImportDiffText
$TransientObservation = [ordered]@{
    schema = "SpaceSyndicateExactShaTransientArtifactObservationV2"
    authority_path = $TransientArtifactAuthorityPath
    authority_sha256 = $TransientArtifactAuthoritySha256
    head_sha = $HeadSha
    tree_sha = $TreeSha
    observed_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
    canonical_import_state = $CanonicalImportState
    canonical_import_path_set_sha256 = $CanonicalImportPathSetSha256
    canonical_import_postrun_map_sha256 = $PostRunCanonicalImportMapSha256
    import_diff_path = $ImportDiffPath
    import_diff_sha256 = Get-FileSha256 $ImportDiffPath
    import_count = $ObservedImports.Count
    imports = $ObservedImports
    generated_uid_allowlist_path = $UidAllowlistEvidencePath
    generated_uid_allowlist_sha256 = $UidAllowlistEvidenceSha256
    generated_uid_entry_set_sha256 = `
        [string]$UidAllowlistValidation.uid_entry_set_sha256
    generated_uid_authorized_count = $UidCandidateMap.Count
    generated_uid_state = $PostViewportUidState
    uid_count = $ObservedUids.Count
    uid_missing_count = $MissingUids.Count
    uid_unknown_count = $UnexpectedUntracked.Count
    observed_uid_subset_of_authority = $true
    generated_uid_allowlist_exact_set_match = `
        ($PostViewportUidState -ceq "EXACT_EXTERNAL_ALLOWLIST")
    uids = $ObservedUids
}
$TransientObservationPath = Join-Path `
    $ValidationEvidenceRoot `
    "transient-artifact-observation.json"
Write-AtomicUtf8Json $TransientObservationPath $TransientObservation
$TransientObservationSha256 = Get-FileSha256 $TransientObservationPath

if ($TransientImports.Count -gt 0) {
    $null = Invoke-CheckedGit -Arguments ([string[]]@(
        @("restore", "--source=HEAD", "--worktree", "--") +
        @($TransientImports)
    ))
}
$PostRestoreCanonicalImportMapSha256 = Get-RunnerCanonicalFileMapSha256 `
    -Root $Worktree `
    -Paths $CanonicalImportPaths
if ($PostRestoreCanonicalImportMapSha256 `
    -cne [string]$CanonicalImportAuthority.baseline_map_sha256) {
    throw "Canonical import restore did not reproduce the exact HEAD baseline."
}
foreach ($RelativeUidPath in $TransientUids) {
    $AbsoluteUidPath = Resolve-WorktreeChildPath $RelativeUidPath
    Remove-Item -LiteralPath $AbsoluteUidPath -Force
    if (Test-Path -LiteralPath $AbsoluteUidPath) {
        throw "Failed to remove exact frozen generated UID path: $RelativeUidPath"
    }
}
"MCP_TRANSIENT_IMPORT_RESTORE_COUNT=$($TransientImports.Count)"
"MCP_TRANSIENT_UID_REMOVE_COUNT=$($TransientUids.Count)"
"MCP_TRANSIENT_ARTIFACT_OBSERVATION_SHA256=$TransientObservationSha256"

$FinalTrackedDrift = @(
    Invoke-CheckedGit -Arguments @(
        "-c", "core.quotepath=false", "diff", "--no-renames",
        "--name-only", "HEAD", "--"
    ) |
        ForEach-Object { $_.Trim().Replace("\", "/") } |
        Where-Object { $_ }
)
$FinalUntrackedDrift = @(
    Invoke-CheckedGit -Arguments @(
        "-c", "core.quotepath=false", "ls-files",
        "--others", "--exclude-standard"
    ) |
        ForEach-Object { $_.Trim().Replace("\", "/") } |
        Where-Object { $_ }
)
$FinalIgnoredUidRows = @(
    Invoke-CheckedGit -Arguments @(
        "-c", "core.quotepath=false", "ls-files", "--others", "--ignored",
        "--exclude-standard", "--", "*.gd.uid", "*.gdshader.uid"
    ) |
        ForEach-Object { $_.Trim().Replace("\", "/") } |
        Where-Object {
            $_ -and -not $_.StartsWith(".godot/", [StringComparison]::Ordinal) `
                -and -not $_.StartsWith(
                    ".codex-godot/",
                    [StringComparison]::Ordinal
                )
        }
)
$FinalRemainingAuthorizedUidPaths = @(
    $UidCandidateMap.Keys | Where-Object {
        Test-Path -LiteralPath (Resolve-WorktreeChildPath $_)
    }
)
$ExpectedImportRestoreCount = if (
    $CanonicalImportState -ceq "CANONICAL_GENERATED_SUBSET" `
    -or $CanonicalImportState -ceq "CANONICAL_GENERATED_57"
) { $TrackedDrift.Count } else { 0 }
if ($FinalTrackedDrift.Count -ne 0 `
    -or $FinalUntrackedDrift.Count -ne 0 `
    -or $FinalIgnoredUidRows.Count -ne 0 `
    -or $FinalRemainingAuthorizedUidPaths.Count -ne 0 `
    -or $TransientImports.Count -ne $ExpectedImportRestoreCount `
    -or $TransientUids.Count -ne $ExpectedPostViewportUidRemoveCount `
    -or $MissingUids.Count -ne $ExpectedPostViewportUidMissingCount) {
    throw "Final transient cleanup identity/count re-attestation failed."
}

$FinalWorktreeStatus = @(
    Invoke-CheckedGit -Arguments @(
        "status", "--porcelain=v1", "--untracked-files=all"
    )
)
if ($FinalWorktreeStatus.Count -ne 0) {
    $DirtySummary = $FinalWorktreeStatus -join "`n"
    throw "Exact-SHA worktree changed during validation:`n$DirtySummary"
}
$FinalHeadRows = @(Invoke-CheckedGit -Arguments @("rev-parse", "HEAD"))
$FinalTreeRows = @(Invoke-CheckedGit -Arguments @("rev-parse", "HEAD^{tree}"))
if ($FinalHeadRows.Count -ne 1 -or $FinalTreeRows.Count -ne 1) {
    throw "Final local HEAD/tree identity was not unique."
}
$FinalHeadSha = $FinalHeadRows[0].Trim()
$FinalTreeSha = $FinalTreeRows[0].Trim()
$FinalMergeBaseRows = @(
    Invoke-CheckedGit -Arguments @("merge-base", $BaseMainSha, $FinalHeadSha)
)
if ($FinalMergeBaseRows.Count -ne 1) {
    throw "Final PR merge base was not unique."
}
$FinalMergeBaseSha = $FinalMergeBaseRows[0].Trim()
$FinalRemoteRows = @(
    Invoke-CheckedGit -Arguments @(
        "ls-remote", "--exit-code", "origin", "refs/heads/$Branch"
    )
)
if ($FinalRemoteRows.Count -ne 1) {
    throw "Final remote PR branch identity could not be resolved uniquely."
}
$FinalRemoteSha = (($FinalRemoteRows[0] -split "\s+")[0]).Trim()
$FinalChanged = @(
    Invoke-CheckedGit -Arguments @(
        "diff", "--name-only", "--diff-filter=ACMRTUXB",
        $DiffParentSha, $FinalHeadSha
    ) |
        ForEach-Object { $_.Trim() } | Where-Object { $_ }
)
$FinalDeleted = @(
    Invoke-CheckedGit -Arguments @(
        "diff", "--name-only", "--diff-filter=D",
        $DiffParentSha, $FinalHeadSha
    ) |
        ForEach-Object { $_.Trim() } | Where-Object { $_ }
)
$FinalChangedDelta = @(
    Compare-Object `
        -ReferenceObject @($Changed) `
        -DifferenceObject @($FinalChanged) `
        -CaseSensitive
)
$FinalManifestText = @($FinalChanged | Sort-Object) -join "`n"
$FinalManifestSha256 = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
        [Text.UTF8Encoding]::new($false).GetBytes($FinalManifestText)
    )
).ToLowerInvariant()
$FinalScripts = @($FinalChanged | Where-Object { $_ -match "\.gd$" })
$FinalScenes = @($FinalChanged | Where-Object { $_ -match "\.tscn$" })
$FinalResources = @($FinalChanged | Where-Object {
    $ResourceExtensions -contains ([IO.Path]::GetExtension($_).ToLowerInvariant())
})
$null = Invoke-CheckedGit -Arguments @(
    "diff", "--check", $DiffParentSha, $FinalHeadSha
)
if ($FinalHeadSha -cne $HeadSha `
    -or $FinalHeadSha -cne $FrozenHeadSha `
    -or $FinalTreeSha -cne $TreeSha `
    -or $FinalTreeSha -cne $FrozenTreeSha `
    -or $FinalRemoteSha -cne $RemoteSha `
    -or $FinalRemoteSha -cne $FinalHeadSha `
    -or $FinalMergeBaseSha -cne $DiffParentSha `
    -or $FinalDeleted.Count -ne 0 `
    -or $FinalChangedDelta.Count -ne 0 `
    -or $FinalManifestSha256 -cne $ManifestSha256 `
    -or $FinalScripts.Count -ne $Scripts.Count `
    -or $FinalScenes.Count -ne $Scenes.Count `
    -or $FinalResources.Count -ne $Resources.Count) {
    throw "Final exact-SHA HEAD/tree/remote/manifest re-attestation failed."
}
$FinalUidRegenerationEvidenceMismatchCount = 0
foreach ($AuthorizedUidPath in $UidCandidateMap.Keys) {
    if (-not $PostMcpUidEvidenceByPath.ContainsKey($AuthorizedUidPath)) {
        $FinalUidRegenerationEvidenceMismatchCount += 1
        continue
    }
    $FinalUidEvidenceRow = $PostMcpUidEvidenceByPath[$AuthorizedUidPath]
    $FinalUidEvidencePath = [string]$FinalUidEvidenceRow.evidence_path
    if ([string]::IsNullOrWhiteSpace($FinalUidEvidencePath) `
        -or -not (Test-Path -LiteralPath $FinalUidEvidencePath -PathType Leaf) `
        -or (Get-FileSha256 $FinalUidEvidencePath) `
            -cne [string]$UidCandidateMap[
                $AuthorizedUidPath
            ].uid_content_sha256) {
        $FinalUidRegenerationEvidenceMismatchCount += 1
    }
}
$UidRegenerationWarningReceiptReadback = $null
if (-not (Test-Path `
        -LiteralPath $UidRegenerationWarningReceiptPath `
        -PathType Leaf) `
    -or (Get-FileSha256 $UidRegenerationWarningReceiptPath) `
        -cne $UidRegenerationWarningReceiptSha256 `
    -or -not (Test-Path -LiteralPath $RuntimeLogEvidencePath -PathType Leaf) `
    -or (Get-FileSha256 $RuntimeLogEvidencePath) -cne $RuntimeLogSha256 `
    -or -not (Test-Path -LiteralPath $LaunchLogEvidencePath -PathType Leaf) `
    -or (Get-FileSha256 $LaunchLogEvidencePath) `
        -cne $UidRegenerationEditorConsoleSha256 `
    -or -not (Test-Path `
        -LiteralPath $PostMcpTransientObservationPath `
        -PathType Leaf) `
    -or (Get-FileSha256 $PostMcpTransientObservationPath) `
        -cne $PostMcpTransientObservationSha256 `
    -or -not (Test-Path `
        -LiteralPath $PostMcpCleanupResultEvidencePath `
        -PathType Leaf) `
    -or (Get-FileSha256 $PostMcpCleanupResultEvidencePath) `
        -cne $PostMcpCleanupResultEvidenceSha256 `
    -or $FinalUidRegenerationEvidenceMismatchCount -ne 0) {
    throw "The controlled UID warning receipt or its bound evidence changed."
}
$FinalRuntimeLogSha256 = Get-FileSha256 $RuntimeLogEvidencePath
$FinalRuntimeLogLines = @(
    [IO.File]::ReadAllLines($RuntimeLogEvidencePath, $StrictUtf8)
)
$FinalRuntimeDiagnostics = @(
    Get-McpDiagnosticRows `
        -Lines ([object[]]$FinalRuntimeLogLines) `
        -Channel "runtime" `
        -UidCandidateMap $UidCandidateMap
)
$FinalRuntimeWarningCount = @(
    $FinalRuntimeDiagnostics | Where-Object { [bool]$_.raw_warning }
).Count
$FinalRuntimeErrorCount = @(
    $FinalRuntimeDiagnostics | Where-Object { [string]$_.severity -ceq "error" }
).Count
$FinalRuntimeUnclassifiedCount = @(
    $FinalRuntimeDiagnostics | Where-Object {
        [string]$_.severity -ceq "unclassified"
    }
).Count
$FinalRuntimePendingCount = @(
    $FinalRuntimeDiagnostics | Where-Object { [string]$_.severity -ceq "pending" }
).Count
$FinalRuntimeDiagnosticReclassificationGreen = `
    $FinalRuntimeWarningCount -eq 0 `
    -and $FinalRuntimeErrorCount -eq 0 `
    -and $FinalRuntimeUnclassifiedCount -eq 0 `
    -and $FinalRuntimePendingCount -eq 0
if (-not $FinalRuntimeDiagnosticReclassificationGreen) {
    throw "Final runtime log no longer passes the zero-diagnostic warning gate."
}
$FinalLaunchLogLines = @(
    [IO.File]::ReadAllLines($LaunchLogEvidencePath, $StrictUtf8)
)
$FinalProjectDiagnostics = @(
    Get-McpDiagnosticRows `
        -Lines ([object[]]$FinalLaunchLogLines) `
        -Channel "editor_launch" `
        -UidCandidateMap $UidCandidateMap
)
$FinalUidRegenerationPendingSetGate = `
    Get-McpUidRegenerationPendingSetGate `
        -DiagnosticRows ([object[]]$FinalProjectDiagnostics) `
        -LaunchLines ([object[]]$FinalLaunchLogLines) `
        -UidCandidateMap $UidCandidateMap
$FinalUidRegenerationPendingRows = @(
    $FinalProjectDiagnostics | Where-Object {
        [string]$_.severity -ceq "pending" `
            -and [string]$_.classification `
                -ceq "pending_uid_regeneration_candidate"
    }
)
if (-not [bool]$FinalUidRegenerationPendingSetGate.green `
    -or $FinalUidRegenerationPendingRows.Count -ne $UidCandidateMap.Count `
    -or @($FinalProjectDiagnostics | Where-Object {
        [string]$_.severity -ceq "error" `
            -or [string]$_.severity -ceq "unclassified"
    }).Count -ne 0) {
    throw "Final editor log no longer passes the production UID warning gate."
}
$FinalUidRegenerationPendingByUid = `
    [Collections.Generic.Dictionary[string,object]]::new(
        [StringComparer]::Ordinal
    )
foreach ($FinalPendingRow in $FinalUidRegenerationPendingRows) {
    $FinalUidRegenerationPendingByUid.Add(
        [string]$FinalPendingRow.uid_relative_path,
        $FinalPendingRow
    )
}
$UidRegenerationWarningReceiptReadbackBytes = [IO.File]::ReadAllBytes(
    $UidRegenerationWarningReceiptPath
)
$UidRegenerationWarningReceiptReadback = (
    [Text.UTF8Encoding]::new($false, $true).GetString(
        $UidRegenerationWarningReceiptReadbackBytes
    ) | ConvertFrom-Json
)
$UidRegenerationWarningReceiptRows = @(
    $UidRegenerationWarningReceiptReadback.warnings
)
$InvalidUidRegenerationWarningReceiptRows = `
    [Collections.Generic.List[object]]::new()
$ReceiptUidPathSet = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal
)
foreach ($ReceiptWarningRow in $UidRegenerationWarningReceiptRows) {
    $ReceiptUidPath = [string]$ReceiptWarningRow.uid_relative_path
    if (-not $ReceiptUidPathSet.Add($ReceiptUidPath) `
        -or -not $FinalUidRegenerationPendingByUid.ContainsKey($ReceiptUidPath)) {
        $InvalidUidRegenerationWarningReceiptRows.Add($ReceiptWarningRow)
        continue
    }
    $FinalPendingRow = $FinalUidRegenerationPendingByUid[$ReceiptUidPath]
    if ([string]$ReceiptWarningRow.channel -cne "editor_launch" `
        -or $ReceiptWarningRow.raw_warning -isnot [bool] `
        -or -not [bool]$ReceiptWarningRow.raw_warning `
        -or [int64]$ReceiptWarningRow.line_number `
            -ne [int64]$FinalPendingRow.line_number `
        -or [string]$ReceiptWarningRow.line -cne [string]$FinalPendingRow.line `
        -or [string]$ReceiptWarningRow.source_path `
            -cne [string]$FinalPendingRow.source_path `
        -or [string]$ReceiptWarningRow.expected_uid_value `
            -cne [string]$FinalPendingRow.expected_uid_value `
        -or [string]$ReceiptWarningRow.expected_uid_content_sha256 `
            -cne [string]$FinalPendingRow.expected_uid_content_sha256 `
        -or [int64]$ReceiptWarningRow.expected_uid_byte_length `
            -ne [int64]$FinalPendingRow.expected_uid_byte_length `
        -or [string]$ReceiptWarningRow.initial_classification `
            -cne "pending_uid_regeneration_candidate" `
        -or [string]$ReceiptWarningRow.final_classification `
            -cne "controlled_uid_regeneration") {
        $InvalidUidRegenerationWarningReceiptRows.Add($ReceiptWarningRow)
    }
}
if ([string]$UidRegenerationWarningReceiptReadback.schema `
        -cne "SpaceSyndicateExactShaUidRegenerationWarningReceiptV1" `
    -or [string]$UidRegenerationWarningReceiptReadback.status `
        -cne "CONTROLLED" `
    -or [string]$UidRegenerationWarningReceiptReadback.transition `
        -cne "pending_uid_regeneration_candidate->controlled_uid_regeneration" `
    -or [string]$UidRegenerationWarningReceiptReadback.head_sha -cne $HeadSha `
    -or [string]$UidRegenerationWarningReceiptReadback.tree_sha -cne $TreeSha `
    -or [int]$UidRegenerationWarningReceiptReadback.launch_pid `
        -ne [int]$LaunchResult.pid `
    -or [string]$UidRegenerationWarningReceiptReadback.launch_process_start_utc `
        -cne $LaunchProcessStartUtc.ToString("o") `
    -or [string]$UidRegenerationWarningReceiptReadback.controlled_at_utc `
        -cne $UidRegenerationControlledAtUtc.ToString("o") `
    -or [string]$UidRegenerationWarningReceiptReadback.cleanup_observed_at_utc `
        -cne $PostMcpObservedAtUtc.ToString("o") `
    -or [string]$UidRegenerationWarningReceiptReadback.initial_manifest_path `
        -cne $ExactShaManifestPath `
    -or [string]$UidRegenerationWarningReceiptReadback.initial_manifest_evidence_sha256 `
        -cne $ExactShaManifestEvidenceSha256 `
    -or [int]$UidRegenerationWarningReceiptReadback.initial_uid_present_count `
        -ne 0 `
    -or [string]$UidRegenerationWarningReceiptReadback.launch_epoch_sha256 `
        -cne $UidRegenerationLaunchEpochSha256 `
    -or [string]$UidRegenerationWarningReceiptReadback.console_epoch_sha256 `
        -cne $ConsoleEpochSha256 `
    -or [string]$UidRegenerationWarningReceiptReadback.runtime_console_path `
        -cne $RuntimeLogEvidencePath `
    -or [string]$UidRegenerationWarningReceiptReadback.runtime_console_sha256 `
        -cne $FinalRuntimeLogSha256 `
    -or [string]$UidRegenerationWarningReceiptReadback.editor_console_sha256 `
        -cne $UidRegenerationEditorConsoleSha256 `
    -or [string]$UidRegenerationWarningReceiptReadback.allowlist_sha256 `
        -cne $UidAllowlistSourceSha256 `
    -or [string]$UidRegenerationWarningReceiptReadback.allowlist_entry_set_sha256 `
        -cne [string]$UidAllowlistValidation.uid_entry_set_sha256 `
    -or [int]$UidRegenerationWarningReceiptReadback.allowlist_entry_count `
        -ne $UidCandidateMap.Count `
    -or [int]$UidRegenerationWarningReceiptReadback.raw_warning_count `
        -ne $UidCandidateMap.Count `
    -or [int]$UidRegenerationWarningReceiptReadback.pending_candidate_count `
        -ne $UidCandidateMap.Count `
    -or [int]$UidRegenerationWarningReceiptReadback.controlled_warning_count `
        -ne $UidCandidateMap.Count `
    -or [int]$UidRegenerationWarningReceiptReadback.runtime_warning_count `
        -ne $FinalRuntimeWarningCount `
    -or -not $FinalRuntimeDiagnosticReclassificationGreen `
    -or [int]$UidRegenerationWarningReceiptReadback.unclassified_diagnostic_count `
        -ne 0 `
    -or [string]$UidRegenerationWarningReceiptReadback.source_path_set_sha256 `
        -cne [string]$McpUidRegenerationPendingSetGate.actual_source_path_set_sha256 `
    -or [string]$UidRegenerationWarningReceiptReadback.uid_path_set_sha256 `
        -cne [string]$McpUidRegenerationPendingSetGate.actual_uid_path_set_sha256 `
    -or [string]$UidRegenerationWarningReceiptReadback.uid_exact_state `
        -cne "EXACT_EXTERNAL_ALLOWLIST" `
    -or [int]$UidRegenerationWarningReceiptReadback.uid_exact_byte_match_count `
        -ne $UidCandidateMap.Count `
    -or [int]$UidRegenerationWarningReceiptReadback.uid_cleanup_remove_count `
        -ne $UidCandidateMap.Count `
    -or -not [bool]$UidRegenerationWarningReceiptReadback.cleanup_green `
    -or [string]$UidRegenerationWarningReceiptReadback.cleanup_context `
        -cne "post_mcp_pre_viewport" `
    -or [string]$UidRegenerationWarningReceiptReadback.cleanup_observation_path `
        -cne $PostMcpTransientObservationPath `
    -or [string]$UidRegenerationWarningReceiptReadback.cleanup_observation_sha256 `
        -cne $PostMcpTransientObservationSha256 `
    -or [string]$UidRegenerationWarningReceiptReadback.cleanup_result_path `
        -cne $PostMcpCleanupResultEvidencePath `
    -or [string]$UidRegenerationWarningReceiptReadback.cleanup_result_sha256 `
        -cne $PostMcpCleanupResultEvidenceSha256 `
    -or $UidRegenerationWarningReceiptRows.Count -ne $UidCandidateMap.Count `
    -or $ReceiptUidPathSet.Count -ne $UidCandidateMap.Count `
    -or $InvalidUidRegenerationWarningReceiptRows.Count -ne 0) {
    throw "Final controlled UID warning receipt re-attestation failed."
}
if (-not (Test-Path -LiteralPath $UidAllowlistSourcePath -PathType Leaf) `
    -or (Get-FileSha256 $UidAllowlistSourcePath) -cne $UidAllowlistSourceSha256 `
    -or (Get-FileSha256 $UidAllowlistEvidencePath) `
        -cne $UidAllowlistEvidenceSha256 `
    -or $UidAllowlistSourceSha256 `
        -cne $env:V075_MCP_EXPECTED_GENERATED_UID_ALLOWLIST_SHA256 `
    -or $FinalRemainingAuthorizedUidPaths.Count -ne 0 `
    -or $FinalUntrackedDrift.Count -ne 0 `
    -or $FinalIgnoredUidRows.Count -ne 0 `
    -or $TransientUids.Count -ne $ExpectedPostViewportUidRemoveCount `
    -or $MissingUids.Count -ne $ExpectedPostViewportUidMissingCount) {
    throw "Final generated-UID authority re-attestation failed."
}
$FinalMcpRawEvidenceManifestReadback = $null
if (-not (Test-Path `
        -LiteralPath $McpRawEvidenceManifestPath `
        -PathType Leaf) `
    -or (Get-FileSha256 $McpRawEvidenceManifestPath) `
        -cne $McpRawEvidenceManifestSha256) {
    throw "MCP raw evidence manifest changed before final re-attestation."
}
try {
    $FinalMcpRawEvidenceManifestReadback = (
        [Text.UTF8Encoding]::new($false, $true).GetString(
            [IO.File]::ReadAllBytes($McpRawEvidenceManifestPath)
        ) | ConvertFrom-Json
    )
} catch {
    throw "MCP raw evidence manifest is not strict UTF-8 JSON: $_"
}
$FinalMcpRawEvidenceRows = [object[]]@(
    $FinalMcpRawEvidenceManifestReadback.responses
)
$FinalMcpRawEvidenceIntegrity = Get-McpRawEvidenceIntegrityGate `
    -Rows $FinalMcpRawEvidenceRows `
    -RawRoot $McpRawEvidenceRoot
if ([string]$FinalMcpRawEvidenceManifestReadback.schema `
        -cne "SpaceSyndicateExactShaMcpRawEvidenceManifestV2" `
    -or [string]$FinalMcpRawEvidenceManifestReadback.head_sha -cne $HeadSha `
    -or [string]$FinalMcpRawEvidenceManifestReadback.tree_sha -cne $TreeSha `
    -or [int]$FinalMcpRawEvidenceManifestReadback.launch_pid `
        -ne [int]$LaunchResult.pid `
    -or [string]$FinalMcpRawEvidenceManifestReadback.launch_process_start_utc `
        -cne $LaunchProcessStartUtc.ToString("o") `
    -or [int]$FinalMcpRawEvidenceManifestReadback.response_count `
        -ne $McpRawEvidenceRows.Count `
    -or $FinalMcpRawEvidenceRows.Count -ne $McpRawEvidenceRows.Count `
    -or [int]$FinalMcpRawEvidenceManifestReadback.sequence_first -ne 1 `
    -or [int]$FinalMcpRawEvidenceManifestReadback.sequence_last `
        -ne $McpRawEvidenceRows.Count `
    -or [int]$FinalMcpRawEvidenceManifestReadback.validated_success_count `
        -ne $McpRawEvidenceRows.Count `
    -or [int]$FinalMcpRawEvidenceManifestReadback.failed_attempt_count -ne 0 `
    -or [int]$FinalMcpRawEvidenceManifestReadback.invoke_error_count -ne 0 `
    -or [int]$FinalMcpRawEvidenceManifestReadback.orphan_invoke_error_count -ne 0 `
    -or [int]$FinalMcpRawEvidenceManifestReadback.actual_raw_response_count `
        -ne $McpRawEvidenceRows.Count `
    -or [int]$FinalMcpRawEvidenceManifestReadback.ledger_raw_response_count `
        -ne $McpRawEvidenceRows.Count `
    -or [int]$FinalMcpRawEvidenceManifestReadback.orphan_raw_response_count `
        -ne 0 `
    -or @($FinalMcpRawEvidenceManifestReadback.orphan_raw_response_paths).Count `
        -ne 0 `
    -or [int]$FinalMcpRawEvidenceManifestReadback.missing_raw_response_count `
        -ne 0 `
    -or @($FinalMcpRawEvidenceManifestReadback.missing_raw_response_paths).Count `
        -ne 0 `
    -or [int]$FinalMcpRawEvidenceManifestReadback.raw_file_verified_count `
        -ne $McpRawEvidenceRows.Count `
    -or $FinalMcpRawEvidenceManifestReadback.integrity_green -isnot [bool] `
    -or -not [bool]$FinalMcpRawEvidenceManifestReadback.integrity_green `
    -or -not [bool]$FinalMcpRawEvidenceIntegrity.green `
    -or [int]$FinalMcpRawEvidenceIntegrity.failed_attempt_count -ne 0 `
    -or [int]$FinalMcpRawEvidenceIntegrity.invoke_error_count -ne 0 `
    -or [int]$FinalMcpRawEvidenceIntegrity.orphan_invoke_error_count -ne 0 `
    -or [int]$FinalMcpRawEvidenceIntegrity.actual_raw_response_count `
        -ne $McpRawEvidenceRows.Count `
    -or [int]$FinalMcpRawEvidenceIntegrity.ledger_raw_response_count `
        -ne $McpRawEvidenceRows.Count `
    -or [int]$FinalMcpRawEvidenceIntegrity.orphan_raw_response_count -ne 0 `
    -or [int]$FinalMcpRawEvidenceIntegrity.missing_raw_response_count -ne 0 `
    -or [int]$FinalMcpRawEvidenceIntegrity.validated_success_count `
        -ne $McpRawEvidenceRows.Count `
    -or [int]$FinalMcpRawEvidenceIntegrity.raw_file_verified_count `
        -ne $McpRawEvidenceRows.Count) {
    throw "Final MCP raw evidence ledger re-attestation failed."
}
$FinalReattestation = [ordered]@{
    schema = "SpaceSyndicateExactShaFinalReattestationV1"
    reattested_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
    initial_manifest_path = $ExactShaManifestPath
    initial_manifest_evidence_sha256 = $ExactShaManifestEvidenceSha256
    transient_authority_sha256 = $TransientArtifactAuthoritySha256
    transient_observation_sha256 = $TransientObservationSha256
    post_mcp_transient_observation_path = $PostMcpTransientObservationPath
    post_mcp_transient_observation_sha256 = `
        $PostMcpTransientObservationSha256
    post_mcp_cleanup_result_path = $PostMcpCleanupResultEvidencePath
    post_mcp_cleanup_result_sha256 = $PostMcpCleanupResultEvidenceSha256
    post_mcp_import_state = [string]$PostMcpTransientCleanup.import_state
    post_mcp_uid_state = [string]$PostMcpTransientCleanup.uid_state
    post_mcp_import_restore_count = @(
        $PostMcpTransientCleanup.safe_import_cleanup
    ).Count
    post_mcp_uid_remove_count = @(
        $PostMcpTransientCleanup.safe_uid_cleanup
    ).Count
    uid_regeneration_warning_receipt_path = `
        $UidRegenerationWarningReceiptPath
    uid_regeneration_warning_receipt_sha256 = `
        $UidRegenerationWarningReceiptSha256
    uid_regeneration_warning_status = `
        [string]$UidRegenerationWarningReceiptReadback.status
    uid_regeneration_warning_raw_count = `
        [int]$UidRegenerationWarningReceiptReadback.raw_warning_count
    uid_regeneration_warning_pending_count = `
        [int]$UidRegenerationWarningReceiptReadback.pending_candidate_count
    uid_regeneration_warning_controlled_count = `
        [int]$UidRegenerationWarningReceiptReadback.controlled_warning_count
    uid_regeneration_warning_runtime_count = `
        [int]$UidRegenerationWarningReceiptReadback.runtime_warning_count
    uid_regeneration_warning_source_path_set_sha256 = `
        [string]$UidRegenerationWarningReceiptReadback.source_path_set_sha256
    uid_regeneration_warning_uid_path_set_sha256 = `
        [string]$UidRegenerationWarningReceiptReadback.uid_path_set_sha256
    uid_regeneration_warning_launch_epoch_sha256 = `
        $UidRegenerationLaunchEpochSha256
    uid_regeneration_warning_runtime_console_path = `
        $RuntimeLogEvidencePath
    uid_regeneration_warning_runtime_console_sha256 = `
        $FinalRuntimeLogSha256
    uid_regeneration_warning_runtime_reclassification_green = `
        $FinalRuntimeDiagnosticReclassificationGreen
    uid_regeneration_warning_runtime_error_count = $FinalRuntimeErrorCount
    uid_regeneration_warning_runtime_unclassified_count = `
        $FinalRuntimeUnclassifiedCount
    uid_regeneration_warning_runtime_pending_count = $FinalRuntimePendingCount
    uid_regeneration_warning_editor_console_sha256 = `
        $UidRegenerationEditorConsoleSha256
    uid_regeneration_exact_byte_match_count = `
        $UidRegenerationExactByteMatchCount
    uid_regeneration_final_evidence_mismatch_count = `
        $FinalUidRegenerationEvidenceMismatchCount
    uid_regeneration_cleanup_green = `
        [bool]$PostMcpTransientCleanup.cleanup_green
    uid_regeneration_cleanup_observation_sha256 = `
        $PostMcpTransientObservationSha256
    canonical_import_state = $CanonicalImportState
    canonical_import_path_set_sha256 = $CanonicalImportPathSetSha256
    canonical_import_postrun_map_sha256 = $PostRunCanonicalImportMapSha256
    canonical_import_postrestore_map_sha256 = `
        $PostRestoreCanonicalImportMapSha256
    generated_uid_allowlist_source_path = $UidAllowlistSourcePath
    generated_uid_allowlist_expected_sha256 = `
        $env:V075_MCP_EXPECTED_GENERATED_UID_ALLOWLIST_SHA256
    generated_uid_allowlist_actual_sha256 = $UidAllowlistSourceSha256
    generated_uid_allowlist_evidence_path = $UidAllowlistEvidencePath
    generated_uid_allowlist_evidence_sha256 = $UidAllowlistEvidenceSha256
    generated_uid_entry_count = $UidCandidateMap.Count
    generated_uid_entry_set_sha256 = `
        [string]$UidAllowlistValidation.uid_entry_set_sha256
    post_viewport_probe_uid_state = $PostViewportUidState
    post_viewport_probe_uid_state_accepted = $true
    post_viewport_probe_uid_reappeared = `
        ($PostViewportUidState -ceq "EXACT_EXTERNAL_ALLOWLIST")
    post_viewport_probe_uid_observed_count = $TransientUids.Count
    post_viewport_probe_uid_removed_count = $TransientUids.Count
    post_viewport_probe_uid_missing_count = $MissingUids.Count
    generated_uid_observed_count = $PostMcpSafeUidByPath.Count
    generated_uid_removed_count = $PostMcpRemovedUidPaths.Count
    generated_uid_remaining_count = $FinalRemainingAuthorizedUidPaths.Count
    generated_uid_missing_count = `
        [int]$PostMcpTransientObservation.generated_uid_missing_count
    generated_uid_unknown_count = $FinalUntrackedDrift.Count
    generated_uid_ignored_unknown_count = $FinalIgnoredUidRows.Count
    generated_uid_allowlist_exact_set_match = `
        ([string]$PostMcpTransientCleanup.uid_state `
            -ceq "EXACT_EXTERNAL_ALLOWLIST")
    canonical_import_restore_count = $TransientImports.Count
    canonical_import_expected_restore_count = $ExpectedImportRestoreCount
    final_tracked_drift_count = $FinalTrackedDrift.Count
    final_untracked_drift_count = $FinalUntrackedDrift.Count
    mcp_raw_evidence_manifest_path = $McpRawEvidenceManifestPath
    mcp_raw_evidence_manifest_sha256 = $McpRawEvidenceManifestSha256
    mcp_raw_response_count = $FinalMcpRawEvidenceRows.Count
    mcp_raw_sequence_first = [int]$FinalMcpRawEvidenceIntegrity.sequence_first
    mcp_raw_sequence_last = [int]$FinalMcpRawEvidenceIntegrity.sequence_last
    mcp_raw_validated_success_count = `
        [int]$FinalMcpRawEvidenceIntegrity.validated_success_count
    mcp_raw_failed_attempt_count = `
        [int]$FinalMcpRawEvidenceIntegrity.failed_attempt_count
    mcp_raw_invoke_error_count = `
        [int]$FinalMcpRawEvidenceIntegrity.invoke_error_count
    mcp_raw_orphan_invoke_error_count = `
        [int]$FinalMcpRawEvidenceIntegrity.orphan_invoke_error_count
    mcp_raw_actual_response_count = `
        [int]$FinalMcpRawEvidenceIntegrity.actual_raw_response_count
    mcp_raw_ledger_response_count = `
        [int]$FinalMcpRawEvidenceIntegrity.ledger_raw_response_count
    mcp_raw_orphan_response_count = `
        [int]$FinalMcpRawEvidenceIntegrity.orphan_raw_response_count
    mcp_raw_orphan_response_paths = `
        [object[]]$FinalMcpRawEvidenceIntegrity.orphan_raw_response_paths
    mcp_raw_missing_response_count = `
        [int]$FinalMcpRawEvidenceIntegrity.missing_raw_response_count
    mcp_raw_missing_response_paths = `
        [object[]]$FinalMcpRawEvidenceIntegrity.missing_raw_response_paths
    mcp_raw_file_verified_count = `
        [int]$FinalMcpRawEvidenceIntegrity.raw_file_verified_count
    mcp_raw_integrity_green = [bool]$FinalMcpRawEvidenceIntegrity.green
    changed_resource_evidence_path = $ResourceEvidencePath
    changed_resource_evidence_sha256 = $ResourceEvidenceSha256
    changed_script_passed_count = $ScriptPassed
    changed_scene_passed_count = @($SceneResults | Where-Object passed).Count
    combat_public_receipt_count = $McpCombatPublicReceiptCount
    presentation_applied_receipt_count = $McpPresentationAppliedReceiptCount
    presentation_applied_equals_combat_public = `
        ($McpPresentationAppliedReceiptCount -eq $McpCombatPublicReceiptCount)
    presentation_duplicate_receipt_count = $PresentationDuplicateReceiptCount
    presentation_collision_receipt_count = $PresentationCollisionReceiptCount
    presentation_rejected_receipt_count = $PresentationRejectedReceiptCount
    presentation_collision_gate = "HARD_ZERO_C4_1"
    presentation_rejected_gate = `
        "DIAGNOSTIC_NONBLOCKING_C4_1"
    presentation_gameplay_mutation_count = $PresentationGameplayMutationCount
    presentation_rng_draw_delta = $PresentationRngDrawDelta
    combat_telemetry_hidden_input_field_count = `
        $CombatTelemetryHiddenInputFieldCount
    combat_telemetry_opponent_skill_definition_input_count = `
        $CombatTelemetryOpponentSkillDefinitionInputCount
    combat_telemetry_opponent_skill_target_input_count = `
        $CombatTelemetryOpponentSkillTargetInputCount
    combat_telemetry_opponent_skill_cooldown_input_count = `
        $CombatTelemetryOpponentSkillCooldownInputCount
    combat_telemetry_instant_sequence_input_count = `
        $CombatTelemetryInstantSequenceInputCount
    combat_telemetry_warehouse_private_stock_input_count = `
        $CombatTelemetryWarehousePrivateStockInputCount
    combat_telemetry_ai_private_plan_input_count = `
        $CombatTelemetryAiPrivatePlanInputCount
    combat_telemetry_stored_hidden_field_count = `
        $CombatTelemetryStoredHiddenFieldCount
    combat_telemetry_gameplay_owner_count = $CombatTelemetryGameplayOwnerCount
    combat_telemetry_rng_owner_count = $CombatTelemetryRngOwnerCount
    combat_telemetry_world_mutation_count = `
        $CombatTelemetryWorldMutationCount
    embedded_capture_path = $EmbeddedDiagnosticCapture.external_path
    embedded_capture_sha256 = $EmbeddedDiagnosticCapture.png_sha256
    embedded_capture_byte_count = $EmbeddedDiagnosticCapture.png_byte_count
    embedded_capture_declared_width = $EmbeddedDiagnosticCapture.width
    embedded_capture_declared_height = $EmbeddedDiagnosticCapture.height
    embedded_capture_ihdr_width = $EmbeddedDiagnosticCapture.ihdr_width
    embedded_capture_ihdr_height = $EmbeddedDiagnosticCapture.ihdr_height
    runtime_console_path = $RuntimeLogEvidencePath
    runtime_console_sha256 = $FinalRuntimeLogSha256
    runtime_diagnostic_reclassification_green = `
        $FinalRuntimeDiagnosticReclassificationGreen
    editor_console_path = $LaunchLogEvidencePath
    editor_console_sha256 = Get-FileSha256 $LaunchLogEvidencePath
    stop_evidence_path = $StopEvidencePath
    stop_evidence_sha256 = $StopEvidenceSha256
    stop_stderr_path = $StopStderrPath
    stop_stderr_sha256 = $StopStderrSha256
    viewport_invocation_evidence_path = $ViewportInvocationEvidencePath
    viewport_invocation_evidence_sha256 = $ViewportInvocationEvidenceSha256
    viewport_aggregate_evidence_path = $ViewportAggregateEvidencePath
    viewport_aggregate_evidence_sha256 = $ViewportAggregateEvidenceSha256
    headless_probe_evidence_path = $ProbeEvidencePath
    headless_probe_evidence_sha256 = $ProbeEvidenceSha256
    head_sha = $FinalHeadSha
    tree_sha = $FinalTreeSha
    remote_sha = $FinalRemoteSha
    merge_base_sha = $FinalMergeBaseSha
    manifest_sha256 = $FinalManifestSha256
    changed_count = $FinalChanged.Count
    deleted_count = $FinalDeleted.Count
    script_count = $FinalScripts.Count
    scene_count = $FinalScenes.Count
    resource_count = $FinalResources.Count
    worktree_status_count = $FinalWorktreeStatus.Count
    process_count_after = Get-RequiredIntegralCount `
        $StopResult "process_count_after" "role_stop.final"
    endpoint_count_after = Get-RequiredIntegralCount `
        $StopResult "endpoint_count_after" "role_stop.final"
    stop_pid = Get-RequiredIntegralCount $StopResult "pid" "role_stop.final"
}
$FinalReattestationPath = Join-Path `
    $ValidationEvidenceRoot `
    "exact-sha-final-reattestation.json"
Write-AtomicUtf8Json $FinalReattestationPath $FinalReattestation
$FinalReattestationSha256 = Get-FileSha256 $FinalReattestationPath
"EXACT_SHA_FINAL_REATTESTED=true"
"FINAL_HEAD=$FinalHeadSha"
"FINAL_TREE=$FinalTreeSha"
"FINAL_REMOTE=$FinalRemoteSha"
"FINAL_MANIFEST_SHA256=$FinalManifestSha256"
"FINAL_REATTESTATION_SHA256=$FinalReattestationSha256"
```

Record, at minimum:

```text
initial and final HEAD/tree/remote SHA, PR merge-base, manifest SHA, and clean status
project_root, Godot version, renderer, MCP port, tool profile
list_tool_catalog count/exposed-tool set and capability status
changed script passed/total and diagnostics
changed scene opened/total
changed-resource total, JSON parse total, and ResourceLoader-kind total
raw get_play_state path, semantic-limitation flag, and independently queried live root/node identities
real UI input mode, application action/receipt counts, combat action/public-receipt counts, and UI cue-consumption count
console epoch PID/play-start/final-log binding, final log SHA/count, raw warning/pending/controlled counts, and project/runtime/unclassified counts
canonical import path/baseline/generated map SHAs, externally frozen UID allowlist SHA/entry-set SHA,
observed UID raw hashes/lengths, controlled-warning receipt SHA, transient observation SHA, and post-clean exact restore state
requested/Window-viewport/DisplayServer/pre+post-GetClientRect/client-PNG/IHDR dimensions for all three cases
probe marker JSON and exit code
editor/runtime crash or connection gaps, with log path
```

The following are baseline/tooling observations from the Lane F environment
and must remain distinguishable from task-introduced failures:

- Forward Plus on port 7576 has been usable with Godot 4.7-stable.
- A prior first compatibility renderer import relaunch exited with native
  signal 11 while rebuilding the commercial-asset import cache; the immediate
  Forward Plus relaunch recovered. This is editor-cache evidence, not a
  gameplay receipt error.
- The final `scenes/main.tscn` must reference the V0.7.5 bootstrap,
  `V075RuntimeComposition.tscn`, and `V075SampleGameScreen.tscn`; the probe
  treats a V0.7.4-only composition as a production wiring failure.
- The embedded runtime bridge previously returned `1528x917` for all three
  requested launch resolutions. That capture is diagnostic only and is never
  admitted to the fixed three-viewport manifest; any requested/actual mismatch
  is a red visual gate.
- Older report vocabulary `run_project`, `get_debug_output`, and
  `stop_project` is not present in the current 78-tool catalog. Use
  `play_main_scene`/`enter_play_mode`, `get_console_logs`/
  `get_runtime_events`, and `exit_play_mode` plus the stop script.

Do not pop a preserved stash, alter `main.tscn`, or commit the transient
`.codex-godot/mcp-validation` captures as part of this runbook.
