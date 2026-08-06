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

For Lane F use Role A on port `7576` in this worktree:

```powershell
$Worktree = "C:\Users\zhuye\Documents\New project\space-syndicate-v075-lane-f-bd0af5c"
$Godot = "C:\Users\zhuye\AppData\Local\Programs\Godot\4.7\Godot_v4.7-stable_win64.exe"
$Launch = Join-Path $Worktree "tools\launch_role_godot_mcp.ps1"
$Invoke = Join-Path $Worktree "tools\invoke_role_godot_mcp.ps1"
$Stop = Join-Path $Worktree "tools\stop_role_godot_mcp.ps1"

& $Launch -Role A -Port 7576 -Worktree $Worktree -GodotPath $Godot `
    -Renderer forward_plus -ResolutionWidth 1600 -ResolutionHeight 960
```

The launch script creates role-local metadata under `.codex-godot`, checks
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

Run this before any validation. A merge commit must be compared with its first
parent. Do not use `HEAD^1` unquoted in PowerShell because the native argument
parser can remove the caret; derive the parent list with `git show` instead.

```powershell
$ErrorActionPreference = "Stop"
$HeadSha = (git rev-parse HEAD).Trim()
$Parents = @((git show -s --format=%P $HeadSha).Trim() -split "\s+")
if ($Parents.Count -lt 1) { throw "The target commit has no parent." }
$DiffParentSha = $Parents[0]
$Changed = @(git diff --name-only $DiffParentSha $HeadSha |
    ForEach-Object { $_.Trim() } | Where-Object { $_ })

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

"HEAD=$HeadSha"
"DIFF_PARENT=$DiffParentSha"
"SCRIPTS=$($Scripts.Count)"
"SCENES=$($Scenes.Count)"
"RESOURCES=$($Resources.Count)"
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
```

This is an attestation pipeline, not a Git implementation inside Godot: Git
supplies the SHA and first-parent diff, and the probe verifies that the two
provided SHAs are valid, different 40-character hashes while validating the
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
    [pscustomobject]@{ path = $Path; info = $Info; tree = $Tree }
}

$ScriptResults | Format-Table -AutoSize
```

There is no separate core `load_resource` tool. Use `file_exists`/`read_file`
for text/config resources and the probe's `ResourceLoader` pass for actual
loadability. `execute_code` wraps a snippet as a function body, so the
resource expression must be returned directly; a top-level `var` snippet is
not accepted by the current compiler wrapper. A read-only MCP equivalent for
a short resource list is:

```powershell
$ResourceExpressions = foreach ($Path in $Resources) {
    '{"path":"' + $Path + '","loadable":ResourceLoader.load("' +
        $Path + '") != null}'
}
$ResourceCode = 'return {"resources":[' +
    ($ResourceExpressions -join ",") + ']}'
$ResourceMcpResult = Invoke-McpJson "execute_code" @{
    code = $ResourceCode
    context_mode = "dictionary"
    safety_checks = $true
}
```

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
$null = Invoke-McpJson "get_scene_info"
$null = Invoke-McpJson "get_scene_tree" @{ max_depth = 6 }
$null = Invoke-McpJson "play_main_scene"
$null = Invoke-McpJson "wait_msec" @{ duration = 2000 }
$State = Invoke-McpJson "get_play_state"
$Events = Invoke-McpJson "get_runtime_events" @{ max_events = 200; timeout_msec = 10000 }
$Logs = Invoke-McpJson "get_console_logs" @{
    severity = "all"
    include_rotated = $false
    max_lines = 400
}
```

Capture through `capture_runtime_view`. In Funplay MCP 0.9.6 the PNG is
returned inside `result.structuredContent.result.data_uri`, not as a top-level
MCP image block. The repository helper's `-OutputImage` option only accepts a
top-level image block, so use this small wrapper for the current tool shape.
It writes only transient evidence under `.codex-godot/mcp-validation/` and
does not commit it:

```powershell
$CaptureRoot = ".codex-godot/mcp-validation"
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

$Capture1600 = Save-McpRuntimeCapture "1600x960"
$Capture1600 | Format-List
```

For `1366x768` and `1920x1080`, stop play mode and the role-local editor,
restart the same worktree and port with the requested launch resolution, and
repeat the `play_main_scene`/wait/capture sequence. This keeps the commit SHA
constant; it changes only the editor window size:

```powershell
function Restart-RoleAt([int]$Width, [int]$Height) {
    try { $null = Invoke-McpJson "exit_play_mode" } catch { }
    & $Stop -Worktree $Worktree
    Start-Sleep -Seconds 2
    & $Launch -Role A -Port 7576 -Worktree $Worktree -GodotPath $Godot `
        -Renderer forward_plus -ResolutionWidth $Width -ResolutionHeight $Height
}

Restart-RoleAt 1366 768
$null = Invoke-McpJson "play_main_scene"
$null = Invoke-McpJson "wait_msec" @{ duration = 2000 }
$Capture1366 = Save-McpRuntimeCapture "1366x768"

Restart-RoleAt 1600 960
$null = Invoke-McpJson "play_main_scene"
$null = Invoke-McpJson "wait_msec" @{ duration = 2000 }
$Capture1600 = Save-McpRuntimeCapture "1600x960"

Restart-RoleAt 1920 1080
$null = Invoke-McpJson "play_main_scene"
$null = Invoke-McpJson "wait_msec" @{ duration = 2000 }
$Capture1920 = Save-McpRuntimeCapture "1920x1080"

"Requested 1366x768 -> actual $($Capture1366.width)x$($Capture1366.height)"
"Requested 1600x960 -> actual $($Capture1600.width)x$($Capture1600.height)"
"Requested 1920x1080 -> actual $($Capture1920.width)x$($Capture1920.height)"
```

Do not assume the PNG dimensions equal the editor launch dimensions. Read the
returned size (and, independently, the PNG IHDR) and record the actual
width/height. A mismatch is a visual-acceptance gap, not a reason to relabel
the file. In the current embedded bridge, all three launch requests have been
observed as `1528x917`; this proves the bridge is callable, but does not prove
three independent responsive viewports. A standalone-window capture or a
future bridge resize capability is required to close that gap.

## Headless Read-Only Probe

The existing runner is the repository's deterministic Godot test path. It
uses the GUI Godot executable in headless mode, isolated `APPDATA`/
`LOCALAPPDATA`, bounded timeouts, process-tree cleanup, and completion-marker
checking. It refuses to overlap the live role editor, so stop Role A first:

```powershell
$null = Invoke-McpJson "exit_play_mode"
& $Stop -Worktree $Worktree

$env:V075_MCP_SCREENSHOTS = @(
    "1366x768|$($Capture1366.path)|$($Capture1366.width)|$($Capture1366.height)",
    "1600x960|$($Capture1600.path)|$($Capture1600.width)|$($Capture1600.height)",
    "1920x1080|$($Capture1920.path)|$($Capture1920.width)|$($Capture1920.height)"
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

The probe's `status=PASS` means all supplied static manifests and supplied PNG
dimensions passed. Its `v075_production_wiring_gap=true` is a failure signal
for this cutover, not an expected V0.7.4 handoff. A missing screenshot manifest
is reported as a warning, while malformed or missing supplied screenshots fail.

## Shutdown And Evidence

After runtime inspection, always stop play mode and the role editor cleanly:

```powershell
try { $null = Invoke-McpJson "exit_play_mode" } catch { }
& $Stop -Worktree $Worktree
```

Record, at minimum:

```text
target HEAD SHA and first-parent SHA
project_root, Godot version, renderer, MCP port, tool profile
tools/list count and capability status
changed script passed/total and diagnostics
changed scene opened/total
changed resource loaded/total
main scene play state, runtime event count, console error count
actual PNG dimensions for 1366x768, 1600x960, 1920x1080 requests
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
- The embedded runtime bridge returned `1528x917` for all three requested
  launch resolutions. This is a visual-tooling gap, not evidence that the
  underlying responsive layout is wrong; the runbook preserves the actual
  dimensions in the probe manifest.
- Older report vocabulary `run_project`, `get_debug_output`, and
  `stop_project` is not present in the current 78-tool catalog. Use
  `play_main_scene`/`enter_play_mode`, `get_console_logs`/
  `get_runtime_events`, and `exit_play_mode` plus the stop script.

Do not pop a preserved stash, alter `main.tscn`, or commit the transient
`.codex-godot/mcp-validation` captures as part of this runbook.
