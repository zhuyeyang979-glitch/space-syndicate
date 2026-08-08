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

## Exact Toolchain

The repository's real MCP path is:

```text
.mcp.json
  -> cmd /d /s /c tools\\funplay_mcp_stdio.cmd
  -> pnpm dlx funplay-godot-mcp@0.9.6
  -> http://127.0.0.1:<role-port>/
  -> Godot editor Funplay MCP addon
```

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
if ([string]::IsNullOrWhiteSpace($env:V075_PR90_EVIDENCE_ROOT)) {
    throw "V075_PR90_EVIDENCE_ROOT is required outside the worktree."
}
$EvidenceRoot = [IO.Path]::GetFullPath($env:V075_PR90_EVIDENCE_ROOT)
$WorktreePrefix = $Worktree.TrimEnd("\") + [IO.Path]::DirectorySeparatorChar
if ($EvidenceRoot.Equals($Worktree, [StringComparison]::OrdinalIgnoreCase) `
    -or $EvidenceRoot.StartsWith($WorktreePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "V075_PR90_EVIDENCE_ROOT must be outside the worktree."
}
```

After the same-SHA manifest below is frozen, the launch script creates
role-local metadata under `.codex-godot`, checks
that the returned project root is this worktree, and waits for
`get_project_info`. Every subsequent call must go through the invoke script,
which adds `X-Funplay-MCP-Token` and `MCP-Protocol-Version` from that metadata:

```powershell
& $Invoke -Worktree $Worktree -ToolName get_project_info
& $Invoke -Worktree $Worktree -ToolName get_capability_status
& $Invoke -Worktree $Worktree -ToolName request_script_reload `
    -ArgumentsJson '{"path":"res://"}'
```

The exact core tool names used by this runbook are:

| Gate | MCP tool |
| --- | --- |
| tool discovery | JSON-RPC `tools/list`, or `list_tool_catalog` |
| project identity/reload | `get_project_info`, `get_capability_status`, `request_script_reload` |
| changed GDScript | `validate_script`, then `get_script_errors` for diagnostics |
| changed scene | `open_scene`, `get_scene_info`, `get_scene_tree` |
| file/resource presence | `file_exists`, `read_file`, read-only `execute_code` with `ResourceLoader` |
| main sample | `play_main_scene`, `enter_play_mode`, `get_play_state`, `wait_msec` |
| visual/runtime evidence | `capture_runtime_view`, `get_runtime_events`, `get_console_logs` |
| clean stop | `exit_play_mode`, then `tools\stop_role_godot_mcp.ps1` |

The current server reports Godot `4.7-stable`, Funplay MCP `0.9.6`, profile
`core`, 78 exposed tools, zero disabled tools, and runtime bridge/play mode
capability enabled. `get_editor_protocol_status` reports the optional LSP/DAP
settings; it is diagnostic context, not a substitute for Funplay MCP.

## Same-SHA Manifest

Run this before any validation. For PR acceptance, the changed-file authority
is the PR merge base, not the target commit's first parent. Using the first
parent after a small closure commit can produce a false-green `0/0/0`
manifest.

```powershell
$ErrorActionPreference = "Stop"
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
$WorktreeStatus = @(git -C $Worktree status --porcelain=v1 --untracked-files=all)
if ($WorktreeStatus.Count -ne 0) {
    throw "Exact-SHA MCP requires a clean worktree."
}
$HeadSha = (git -C $Worktree rev-parse HEAD).Trim()
$TreeSha = (git -C $Worktree rev-parse "HEAD^{tree}").Trim()
$RemoteRows = @(git -C $Worktree ls-remote --exit-code origin "refs/heads/$Branch")
if ($LASTEXITCODE -ne 0 -or $RemoteRows.Count -ne 1) {
    throw "The exact remote PR branch could not be resolved uniquely."
}
$RemoteSha = (($RemoteRows[0] -split "\s+")[0]).Trim()
if ($HeadSha -cne $FrozenHeadSha -or $TreeSha -cne $FrozenTreeSha) {
    throw "Local HEAD/tree does not match the frozen authority."
}
if ($RemoteSha -cne $HeadSha) {
    throw "Remote PR branch does not match local frozen HEAD."
}
$MergeBaseSha = (git -C $Worktree merge-base $BaseMainSha $HeadSha).Trim()
if ($MergeBaseSha -cne $BaseMainSha) {
    throw "Unexpected PR merge base: expected=$BaseMainSha actual=$MergeBaseSha"
}
$DiffParentSha = $BaseMainSha
$Changed = @(git -C $Worktree diff --name-only --diff-filter=ACMRTUXB `
    $DiffParentSha $HeadSha |
    ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Deleted = @(git -C $Worktree diff --name-only --diff-filter=D `
    $DiffParentSha $HeadSha |
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
git -C $Worktree diff --check $DiffParentSha $HeadSha
if ($LASTEXITCODE -ne 0) {
    throw "PR-wide git diff --check failed."
}

function Convert-ToResPath([string]$Path) {
    return "res://" + ($Path.Replace("\\", "/"))
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

$LaunchResult = & $Launch -Role A -Port 7576 -Worktree $Worktree `
    -GodotPath $Godot -Renderer forward_plus `
    -ResolutionWidth 1600 -ResolutionHeight 960 | ConvertFrom-Json
if ([int]$LaunchResult.pid -le 0 `
    -or [int]$LaunchResult.endpoint_owner_pid -ne [int]$LaunchResult.pid `
    -or -not ([string]$LaunchResult.worktree).Equals(
        $Worktree, [StringComparison]::OrdinalIgnoreCase
    )) {
    throw "Role A launch identity did not pass."
}
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
function Invoke-McpJson {
    param(
        [Parameter(Mandatory = $true)][string]$ToolName,
        [hashtable]$Arguments = @{},
        [string]$OutputImage = ""
    )
    $json = $Arguments | ConvertTo-Json -Depth 30 -Compress
    $raw = if ($OutputImage) {
        & $Invoke -Worktree $Worktree -ToolName $ToolName `
            -ArgumentsJson $json -OutputImage $OutputImage
    } else {
        & $Invoke -Worktree $Worktree -ToolName $ToolName `
            -ArgumentsJson $json
    }
    $response = $raw | ConvertFrom-Json
    if ($null -ne $response.error) {
        throw ($response.error | ConvertTo-Json -Depth 20 -Compress)
    }
    if ($null -eq $response.result) {
        throw "MCP tool returned no JSON-RPC result: $ToolName"
    }
    if ([bool]$response.result.isError) {
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
        if ($null -ne $SuccessProperty -and -not [bool]$SuccessProperty.Value) {
            throw "MCP tool returned structuredContent.success=false: $ToolName"
        }
    }
    return $response
}

$null = Invoke-McpJson "get_project_info"
$null = Invoke-McpJson "get_capability_status"
$null = Invoke-McpJson "request_script_reload" @{ path = "res://" }
```

For every path in `$Scripts`, call `validate_script` with
`language=gdscript`. A valid result has `result.structuredContent.ok=true` and
zero diagnostics. For every path in `$Scenes`, call `open_scene`, followed by
`get_scene_info` and `get_scene_tree`; do not call `save_scene`.

```powershell
$ScriptResults = foreach ($Path in $Scripts) {
    $Response = Invoke-McpJson "validate_script" @{
        path = $Path
        language = "gdscript"
        run_build = $false
    }
    [pscustomobject]@{
        path = $Path
        ok = [bool]$Response.result.structuredContent.ok
        diagnostics = [int]$Response.result.structuredContent.diagnostic_count
    }
}

$SceneResults = foreach ($Path in $Scenes) {
    $null = Invoke-McpJson "open_scene" @{ path = $Path; set_inherited = $false }
    $Info = Invoke-McpJson "get_scene_info"
    $Tree = Invoke-McpJson "get_scene_tree" @{ max_depth = 5 }
    $InfoPayload = $Info.result.structuredContent
    $TreePayload = $Tree.result.structuredContent
    $Passed = (
        [string]$InfoPayload.scene_path -ceq $Path -and
        [string]$InfoPayload.scene_root.scene_file_path -ceq $Path -and
        [int]$InfoPayload.node_count -ge 1 -and
        [string]$TreePayload.scene_file_path -ceq $Path -and
        -not [string]::IsNullOrWhiteSpace([string]$TreePayload.name)
    )
    [pscustomobject]@{ path = $Path; passed = $Passed; info = $Info; tree = $Tree }
}

$ScriptResults | Format-Table -AutoSize
$ScriptPassed = @(
    $ScriptResults | Where-Object { $_.ok -and $_.diagnostics -eq 0 }
).Count
if ($ScriptResults.Count -ne $Scripts.Count -or $ScriptPassed -ne $Scripts.Count) {
    throw "One or more changed scripts failed MCP validation."
}
if ($SceneResults.Count -ne $Scenes.Count `
    -or @($SceneResults | Where-Object { -not $_.passed }).Count -ne 0) {
    throw "One or more changed scenes failed exact path/tree validation."
}
"MCP_CHANGED_SCRIPT_VALIDATION=$ScriptPassed/$($Scripts.Count)"
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
$JsonExpressions = foreach ($Path in $JsonResources) {
    '{"path":"' + $Path + '","exists":FileAccess.file_exists("' +
        $Path + '"),"parsed":JSON.parse_string(FileAccess.get_file_as_string("' +
        $Path + '")) is Dictionary}'
}
$GodotExpressions = foreach ($Path in $GodotResources) {
    '{"path":"' + $Path + '","exists":ResourceLoader.exists("' +
        $Path + '"),"loadable":ResourceLoader.load("' + $Path + '") != null}'
}
$ResourceCode = 'return {"json":[' + ($JsonExpressions -join ",") +
    '],"godot_resources":[' + ($GodotExpressions -join ",") + ']}'
$ResourceMcpResult = Invoke-McpJson "execute_code" @{
    code = $ResourceCode
    context_mode = "dictionary"
    safety_checks = $true
}
$ResourcePayload = $ResourceMcpResult.result.structuredContent.result
if ($ResourcePayload -is [string]) {
    $ResourcePayload = $ResourcePayload | ConvertFrom-Json
}
$JsonRows = @($ResourcePayload.json)
$GodotRows = @($ResourcePayload.godot_resources)
$JsonPassed = @($JsonRows | Where-Object { $_.exists -and $_.parsed }).Count
$GodotPassed = @($GodotRows | Where-Object { $_.exists -and $_.loadable }).Count
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
"MCP_CHANGED_RESOURCE_LOAD=$ChangedResourcePassed/$($Resources.Count)"
"MCP_CHANGED_JSON_PARSE=$JsonPassed/$($JsonResources.Count)"
"MCP_CHANGED_RESOURCELOADER_KIND=$GodotPassed/$($GodotResources.Count)"
```

Record all three values separately: changed-resource validation, JSON parse,
and ResourceLoader-kind load. A PR whose changed resources are all JSON has a
valid ResourceLoader-kind denominator of `0/0`, not a fabricated `N/N`.

The project setting API key for the configured main scene is
`application/run/main_scene` (the file itself contains
`run/main_scene` under the `[application]` section). The probe uses the API
key, then checks that the value is `res://scenes/main.tscn`.

The headless probe remains the authoritative complete pass because it also
parses changed JSON and checks the main scene and V0.7.5 read-only
dependencies without instantiating gameplay.

## Main Sample And Runtime Evidence

Open and inspect the configured main scene, then run it through the real editor
bridge. The main scene is a production sample check, not a mock Bench check:

```powershell
$null = Invoke-McpJson "open_scene" @{ path = "res://scenes/main.tscn" }
$MainInfo = Invoke-McpJson "get_scene_info"
$MainTree = Invoke-McpJson "get_scene_tree" @{ max_depth = 6 }
if ([string]$MainInfo.result.structuredContent.scene_path -cne "res://scenes/main.tscn" `
    -or [string]$MainTree.result.structuredContent.scene_file_path -cne "res://scenes/main.tscn") {
    throw "Configured main scene did not open as the exact production scene."
}
$PrePlayLogs = Invoke-McpJson "get_console_logs" @{
    severity = "all"
    include_rotated = $false
    max_lines = 4000
}
$null = Invoke-McpJson "play_main_scene"
$null = Invoke-McpJson "wait_msec" @{ duration = 2000 }
$State = Invoke-McpJson "get_play_state"
$Events = Invoke-McpJson "get_runtime_events" @{ max_events = 200; timeout_msec = 10000 }
$StatePayload = $State.result.structuredContent
$EventsPayload = $Events.result.structuredContent
$EventResult = $EventsPayload.result
if (-not [bool]$StatePayload.is_playing_scene `
    -or [string]$StatePayload.current_scene_path -cne "res://scenes/main.tscn") {
    throw "Production main scene is not the active runtime scene."
}
$ReadyEvents = @($EventResult.events | Where-Object { [string]$_.kind -eq "ready" })
if (-not [bool]$EventsPayload.success `
    -or [int]$EventResult.returned_event_count -lt 1 `
    -or $ReadyEvents.Count -lt 1) {
    throw "Runtime bridge did not provide a production ready event."
}

function Get-McpDiagnosticRows([object[]]$Lines) {
    foreach ($LineValue in $Lines) {
        $Line = [string]$LineValue
        if ($Line -match '(?i)(SCRIPT ERROR|PARSE ERROR|PARSER ERROR|RUNTIME ERROR|ERROR:)') {
            [pscustomobject]@{ severity = "error"; line = $Line }
        } elseif ($Line -match '(?i)WARNING:' `
            -or $Line.Contains([string][char]0) `
            -or $Line.Contains([string][char]0xFFFD)) {
            [pscustomobject]@{ severity = "unclassified"; line = $Line }
        }
    }
}

$PrePayload = $PrePlayLogs.result.structuredContent
$PreLines = @($PrePayload.lines)
```

An embedded `capture_runtime_view` is useful only as a diagnostic that the MCP
runtime bridge is alive. In Funplay MCP 0.9.6 the PNG is returned inside
`result.structuredContent.result.data_uri`. Preserve one such capture and its
actual dimensions, but never put it into the three-size acceptance manifest:

```powershell
$CaptureRoot = ".codex-godot/mcp-validation/embedded-diagnostic"
New-Item -ItemType Directory -Force -Path (Join-Path $Worktree $CaptureRoot) | Out-Null

function Save-McpRuntimeCapture([string]$Label) {
    $Response = Invoke-McpJson "capture_runtime_view" @{
        return_data_uri = $true
        timeout_msec = 15000
    }
    $Payload = $Response.result.structuredContent.result
    $Uri = [string]$Payload.data_uri
    if (-not $Uri.StartsWith("data:image/png;base64,")) {
        throw "MCP capture did not return a PNG data URI: $Label"
    }
    $Path = Join-Path $CaptureRoot ("{0}.png" -f $Label)
    [IO.File]::WriteAllBytes(
        (Join-Path $Worktree $Path),
        [Convert]::FromBase64String($Uri.Substring($Uri.IndexOf(",") + 1))
    )
    return [pscustomobject]@{
        label = $Label
        path = "res://$($Path.Replace("\", "/"))"
        width = [int]$Payload.size.x
        height = [int]$Payload.size.y
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
$null = Invoke-McpJson "exit_play_mode"
$null = Invoke-McpJson "wait_msec" @{ duration = 500 }
$StoppedPlayState = Invoke-McpJson "get_play_state"
if ([bool]$StoppedPlayState.result.structuredContent.is_playing_scene) {
    throw "Production play mode remained active after exit_play_mode."
}
$FinalLogs = Invoke-McpJson "get_console_logs" @{
    severity = "all"
    include_rotated = $false
    max_lines = 4000
}
$PostPayload = $FinalLogs.result.structuredContent
$PostLines = @($PostPayload.lines)
if ([string]$PrePayload.log_path -cne [string]$PostPayload.log_path `
    -or $PostLines.Count -lt $PreLines.Count) {
    throw "Console log source changed or truncated during runtime validation."
}
for ($Index = 0; $Index -lt $PreLines.Count; $Index += 1) {
    if ([string]$PreLines[$Index] -cne [string]$PostLines[$Index]) {
        throw "Pre-play console baseline is not a prefix of the final editor log."
    }
}
$ProjectDiagnostics = @(Get-McpDiagnosticRows $PreLines)
$RuntimeDiagnostics = @(
    Get-McpDiagnosticRows @($PostLines | Select-Object -Skip $PreLines.Count)
)
$McpProjectErrorCount = @($ProjectDiagnostics | Where-Object severity -eq "error").Count
$McpRuntimeErrorCount = @($RuntimeDiagnostics | Where-Object severity -eq "error").Count
$McpUnclassifiedDiagnosticCount = @(
    @($ProjectDiagnostics + $RuntimeDiagnostics) |
        Where-Object severity -eq "unclassified"
).Count
if ($McpProjectErrorCount -ne 0 `
    -or $McpRuntimeErrorCount -ne 0 `
    -or $McpUnclassifiedDiagnosticCount -ne 0) {
    throw "MCP console diagnostics are not clean after capture and play-mode exit."
}
"MCP_PROJECT_ERROR_COUNT=$McpProjectErrorCount"
"MCP_RUNTIME_ERROR_COUNT=$McpRuntimeErrorCount"
"MCP_UNCLASSIFIED_DIAGNOSTIC_COUNT=$McpUnclassifiedDiagnosticCount"

$StopResult = & $Stop -Worktree $Worktree | ConvertFrom-Json
if (-not [bool]$StopResult.stopped `
    -or [bool]$StopResult.already_exited `
    -or -not [bool]$StopResult.identity_verified `
    -or -not [bool]$StopResult.normal_close_requested `
    -or [bool]$StopResult.forced_stop `
    -or [int]$StopResult.process_count_after -ne 0 `
    -or [int]$StopResult.endpoint_count_after -ne 0) {
    throw "Role A did not stop cleanly."
}
$ViewportEvidenceRoot = Join-Path $EvidenceRoot "mcp\headed-viewports"
$ViewportRaw = & pwsh -NoLogo -NoProfile -File `
    (Join-Path $Worktree "tools\invoke_v075_responsive_viewport_capture.ps1") `
    -ProjectPath $Worktree `
    -GodotPath $Godot `
    -EvidenceRoot $ViewportEvidenceRoot `
    -SourceSha $HeadSha `
    -TreeSha $TreeSha
if ($LASTEXITCODE -ne 0) {
    throw "Headed responsive viewport capture failed."
}
$ViewportAggregate = ($ViewportRaw | Select-Object -Last 1) | ConvertFrom-Json
if ($ViewportAggregate.status -ne "AUTOMATION_GREEN_PENDING_VISUAL_REVIEW" `
    -or $ViewportAggregate.green_case_count -ne 3 `
    -or $ViewportAggregate.distinct_png_sha256_count -ne 3) {
    throw "Three headed viewport automation gates did not pass."
}
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

This presentation evidence complements, but cannot replace, the natural
runtime identity/action coverage from the exact-SHA formal simulation and MCP
runtime event inspection. Automatic success is still
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

$ProbeResult = & pwsh -NoProfile -File `
    (Join-Path $Worktree "tools\invoke_godot_test.ps1") `
    -ProjectPath $Worktree `
    -GodotPath $Godot `
    -TestScript "res://tests/v075_mcp_production_probe.gd" `
    -ExpectedCompletionMarker "V075_MCP_PRODUCTION_PROBE|" `
    -TimeoutSeconds 180
$ProbeExitCode = $LASTEXITCODE
$ProbeResult
if ($ProbeExitCode -ne 0) { throw "MCP production probe failed: $ProbeExitCode" }
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
if (-not $StopResult.stopped `
    -or $StopResult.already_exited `
    -or -not $StopResult.identity_verified `
    -or -not $StopResult.normal_close_requested `
    -or $StopResult.forced_stop `
    -or $StopResult.process_count_after -ne 0 `
    -or $StopResult.endpoint_count_after -ne 0) {
    throw "Final role stop evidence is not clean."
}
```

Record, at minimum:

```text
target HEAD/tree SHA, remote branch SHA, and PR merge-base diff parent
project_root, Godot version, renderer, MCP port, tool profile
tools/list count and capability status
changed script passed/total and diagnostics
changed scene opened/total
changed-resource total, JSON parse total, and ResourceLoader-kind total
main scene play state, runtime event count, console error count
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
