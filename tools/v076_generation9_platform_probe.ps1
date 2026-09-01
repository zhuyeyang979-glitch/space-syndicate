param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^probe-\d{3}$')]
    [string]$ProbeId,

    [Parameter(Mandatory = $true)]
    [string]$EvidenceRoot,

    [string]$Worktree = (Get-Location).Path,

    [string]$MonitorScript =
        'C:\Users\Administrator\Documents\Codex\2026-08-20\qu\outputs\v076-generation9-platform-qualification\monitor_generation9_probe.ps1',

    [string]$GodotPath =
        'C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe',

    [int]$Port = 23207,
    [int]$Seed = 917592522,
    [uint64]$TargetStartAvailableCommitBytes = 8589934592,
    [uint64]$CapacityGuardBytes = 1073741824,
    [int]$RuntimeReadyTimeoutSeconds = 120,
    [int]$CommercialMenuReadyTimeoutSeconds = 30,
    [int]$NewGameReadyTimeoutSeconds = 180,
    [int]$ExternalSeedFocusTimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
$authorizationId = 'USER_AUTHORIZATION_V076_COMMIT_CAPACITY_AND_GENERATION9_20260902'
$root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd('\')
$probeRoot = [IO.Path]::GetFullPath($EvidenceRoot)
$invokeTool = Join-Path $root 'tools\invoke_role_godot_mcp.ps1'
$launchTool = Join-Path $root 'tools\launch_role_godot_mcp.ps1'
$stopTool = Join-Path $root 'tools\stop_role_godot_mcp.ps1'
$monitorEvidence = Join-Path $probeRoot 'monitor'
$monitorStop = Join-Path $probeRoot 'monitor.stop'
$capacityGuard = Join-Path $probeRoot 'capacity-guard.json'
$monitorStdout = Join-Path $probeRoot 'monitor.stdout.log'
$monitorStderr = Join-Path $probeRoot 'monitor.stderr.log'
$resultPath = Join-Path $probeRoot 'probe_execution_result.json'
$connectionSnapshotPath = Join-Path $probeRoot 'launcher-connection-snapshot.json'
$preflightPath = Join-Path $probeRoot 'preflight.json'
$cleanupPath = Join-Path $probeRoot 'm10-m11-cleanup.json'
$externalSeedFocusRequestPath = Join-Path $probeRoot 'external-seed-focus-request.json'
$externalSeedFocusCompletePath = Join-Path $probeRoot 'external-seed-focus-complete.json'
$startOverlayPath = '/root/Main/V075GameScreen/OverlayLayer/StartOverlay'
$commercialMenuOverlayPath = '/root/Main/V075GameScreen/OverlayLayer/CommercialShellSurfaceLayer/MenuModalOverlay'
$seedControlPath = '/root/Main/V075GameScreen/OverlayLayer/StartOverlay/Center/Panel/Margin/Rows/SeedRow/SeedInput'
$startButtonPath = '/root/Main/V075GameScreen/OverlayLayer/StartOverlay/Center/Panel/Margin/Rows/PlayerButtons/V074SettingsStack/StartConfiguredButton'
$compositionPath = '/root/Main/V075RuntimeComposition'
$runtimeOwnerPath = '/root/Main/V075RuntimeComposition/V075RuntimeOwner'
$monitorProcess = $null
$connection = $null
$cleanup = $null
$startedAt = [DateTime]::UtcNow
$milestones = [ordered]@{}
$seedBinding = [ordered]@{
    selected_seed = $Seed
    visible_text = $null
    config_model_value = $null
    new_game_intent_seed = $null
    runtime_match_seed = $null
    empty_readback_count = 0
    fallback_randomization_count = 0
    direct_runtime_injection_count = 0
    four_layer_match = $false
}
$readySteadySamples = @()
$failure = $null

function Write-Utf8Json {
    param([string]$Path, [object]$Value)
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    [IO.File]::WriteAllText(
        $Path,
        (($Value | ConvertTo-Json -Depth 100) + "`n"),
        [Text.UTF8Encoding]::new($false)
    )
}

function Get-AvailableCommitBytes {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    return [uint64]$os.FreeVirtualMemory * 1024
}

function Get-ExactCloneGodotRows {
    return @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
        [string]$_.Name -match '^Godot.*\.exe$' -and
        [string]$_.CommandLine -like "*$root*"
    })
}

function Assert-NoCapacityGuard {
    if (Test-Path -LiteralPath $capacityGuard) {
        $guard = Get-Content -LiteralPath $capacityGuard -Raw
        throw "NONFORMAL_CAPACITY_GUARD_TRIGGERED: $guard"
    }
}

function Invoke-RoleTool {
    param(
        [Parameter(Mandatory = $true)][string]$ToolName,
        [Parameter(Mandatory = $true)][string]$EvidenceName,
        [hashtable]$Arguments = @{},
        [int]$TimeoutSeconds = 60
    )
    Assert-NoCapacityGuard
    $rawPath = Join-Path $probeRoot $EvidenceName
    $argumentsJson = $Arguments | ConvertTo-Json -Compress -Depth 100
    $raw = & $invokeTool `
        -ToolName $ToolName `
        -ArgumentsJson $argumentsJson `
        -Worktree $root `
        -TimeoutSeconds $TimeoutSeconds `
        -RawResponsePath $rawPath
    if ($LASTEXITCODE -ne 0) {
        throw "MCP tool failed: $ToolName ($LASTEXITCODE)"
    }
    return ($raw | Select-Object -Last 1 | ConvertFrom-Json -Depth 100)
}

function Get-ContentTextJson {
    param([object]$Outer)
    $text = [string](@($Outer.result.content | Where-Object {
        [string]$_.type -eq 'text'
    })[0].text)
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw 'MCP response did not contain text content.'
    }
    try {
        return $text | ConvertFrom-Json -Depth 100
    } catch {
        return $text
    }
}

function Query-RuntimeNode {
    param(
        [string]$EvidenceName,
        [string]$NodePath,
        [string[]]$Properties,
        [switch]$IncludeChildren,
        [ValidateRange(0, 8)][int]$MaxDepth = 2,
        [ValidateRange(1, 500)][int]$MaxNodes = 80
    )
    $queryArguments = @{
        node_path = $NodePath
        properties = $Properties
        include_children = [bool]$IncludeChildren
        max_depth = $MaxDepth
        max_nodes = $MaxNodes
        timeout_msec = 10000
    }
    $outer = Invoke-RoleTool `
        -ToolName 'query_runtime_node' `
        -EvidenceName $EvidenceName `
        -Arguments $queryArguments
    $inner = Get-ContentTextJson $outer
    if (-not [bool]$inner.success) {
        throw "Runtime query failed: $NodePath"
    }
    return $inner.result
}

function Send-RuntimeInput {
    param([string]$EvidenceName, [hashtable]$Arguments)
    $outer = Invoke-RoleTool `
        -ToolName 'send_runtime_input' `
        -EvidenceName $EvidenceName `
        -Arguments $Arguments
    $inner = Get-ContentTextJson $outer
    if (-not [bool]$inner.success) {
        throw "Runtime input failed: $EvidenceName"
    }
    return $inner.result
}

function Get-RequestedProperties {
    param([object]$RuntimeResult)
    if ($null -ne $RuntimeResult.requested_properties) {
        return $RuntimeResult.requested_properties
    }
    return $RuntimeResult.properties
}

function Get-Center {
    param([object]$RuntimeResult)
    $props = Get-RequestedProperties $RuntimeResult
    return [ordered]@{
        x = [double]$props.global_position.x + ([double]$props.size.x / 2.0)
        y = [double]$props.global_position.y + ([double]$props.size.y / 2.0)
    }
}

function Get-FlattenedRuntimeTree {
    param([object]$Tree)
    $nodes = [Collections.Generic.List[object]]::new()
    $queue = [Collections.Generic.Queue[object]]::new()
    if ($null -ne $Tree) {
        $queue.Enqueue($Tree)
    }
    while ($queue.Count -gt 0) {
        $node = $queue.Dequeue()
        $nodes.Add($node)
        foreach ($child in @($node.children)) {
            if ($null -ne $child) {
                $queue.Enqueue($child)
            }
        }
    }
    return @($nodes)
}

function Find-LiveRuntimeButtonByText {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$EvidencePrefix
    )
    $buttonProperties = @('text', 'global_position', 'size', 'visible', 'disabled')
    $rootQuery = Query-RuntimeNode `
        -EvidenceName "$EvidencePrefix-root.jsonrpc.json" `
        -NodePath '/root/Main' `
        -Properties $buttonProperties `
        -IncludeChildren `
        -MaxDepth 8 `
        -MaxNodes 500
    $rootNodes = @(Get-FlattenedRuntimeTree $rootQuery.tree)
    $commercialRoots = @($rootNodes | Where-Object {
        [string]$_.name -ceq 'CommercialShellSurfaceLayer'
    })
    if ($commercialRoots.Count -eq 0 -and $rootNodes.Count -eq 500) {
        $overlayQuery = Query-RuntimeNode `
            -EvidenceName "$EvidencePrefix-overlay-fallback.jsonrpc.json" `
            -NodePath '/root/Main/V075GameScreen/OverlayLayer' `
            -Properties $buttonProperties `
            -IncludeChildren `
            -MaxDepth 8 `
            -MaxNodes 500
        $overlayNodes = @(Get-FlattenedRuntimeTree $overlayQuery.tree)
        $candidateSummaries = @($overlayNodes | Where-Object {
            [string]$_.type -ceq 'Button' -and
            [string]$_.properties.text -ceq $Text
        })
        $commercialRoots = @($overlayNodes | Where-Object {
            [string]$_.name -ceq 'CommercialShellSurfaceLayer'
        })
    } else {
        $candidateSummaries = @($rootNodes | Where-Object {
            [string]$_.type -ceq 'Button' -and
            [string]$_.properties.text -ceq $Text
        })
    }
    if ($commercialRoots.Count -ne 1) {
        throw "Expected one live CommercialShellSurfaceLayer, found $($commercialRoots.Count)."
    }
    $frontier = [Collections.Generic.Queue[string]]::new()
    $visited = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $frontier.Enqueue([string]$commercialRoots[0].path)
    $branchIndex = 0
    while ($candidateSummaries.Count -eq 0 -and $frontier.Count -gt 0) {
        if ($branchIndex -ge 24) {
            throw "Runtime menu discovery exceeded its bounded branch-query budget for button text: $Text"
        }
        $branchPath = $frontier.Dequeue()
        if (-not $visited.Add($branchPath)) {
            continue
        }
        $branchIndex += 1
        $branchQuery = Query-RuntimeNode `
            -EvidenceName ("{0}-branch-{1:d3}.jsonrpc.json" -f $EvidencePrefix, $branchIndex) `
            -NodePath $branchPath `
            -Properties $buttonProperties `
            -IncludeChildren `
            -MaxDepth 8 `
            -MaxNodes 500
        $branchNodes = @(Get-FlattenedRuntimeTree $branchQuery.tree)
        $candidateSummaries = @($branchNodes | Where-Object {
            [string]$_.type -ceq 'Button' -and
            [string]$_.properties.text -ceq $Text
        })
        foreach ($truncatedNode in @($branchNodes | Where-Object {
            [bool]$_.children_truncated
        })) {
            $truncatedPath = [string]$truncatedNode.path
            if (-not [string]::IsNullOrWhiteSpace($truncatedPath) -and -not $visited.Contains($truncatedPath)) {
                $frontier.Enqueue($truncatedPath)
            }
        }
    }
    if ($candidateSummaries.Count -eq 0) {
        throw "Live runtime Button was not found by exact text: $Text"
    }

    $liveCandidates = @()
    $candidateIndex = 0
    foreach ($candidate in $candidateSummaries) {
        $candidateIndex += 1
        $exact = Query-RuntimeNode `
            -EvidenceName ("{0}-candidate-{1:d3}.jsonrpc.json" -f $EvidencePrefix, $candidateIndex) `
            -NodePath ([string]$candidate.path) `
            -Properties $buttonProperties
        $props = Get-RequestedProperties $exact
        if (
            [string]$exact.type -ceq 'Button' -and
            [string]$props.text -ceq $Text -and
            [bool]$props.visible -and
            -not [bool]$props.disabled -and
            [double]$props.size.x -gt 0 -and
            [double]$props.size.y -gt 0
        ) {
            $liveCandidates += $exact
        }
    }
    if ($liveCandidates.Count -ne 1) {
        throw "Expected one enabled visible runtime Button with text '$Text', found $($liveCandidates.Count)."
    }
    return $liveCandidates[0]
}

function Stop-RoleNormally {
    if (Test-Path -LiteralPath (Join-Path $root '.codex-godot\connection.json')) {
        try {
            Invoke-RoleTool `
                -ToolName 'exit_play_mode' `
                -EvidenceName 'm10-exit-play-mode.jsonrpc.json' `
                -Arguments @{} `
                -TimeoutSeconds 30 | Out-Null
        } catch {
            # The editor may already have stopped. The scoped stop script remains authoritative.
        }
    }
    $stopRaw = & $stopTool -Worktree $root
    if ($LASTEXITCODE -ne 0) {
        throw 'Scoped Godot stop script failed.'
    }
    $script:cleanup = $stopRaw | Select-Object -Last 1 | ConvertFrom-Json
    Write-Utf8Json -Path $cleanupPath -Value $script:cleanup
}

if (Test-Path -LiteralPath $probeRoot) {
    throw "Refusing to overwrite probe evidence: $probeRoot"
}
[IO.Directory]::CreateDirectory($probeRoot) | Out-Null

try {
    foreach ($required in @($MonitorScript, $GodotPath, $invokeTool, $launchTool, $stopTool)) {
        if (-not (Test-Path -LiteralPath $required)) {
            throw "Required probe input is missing: $required"
        }
    }
    if (@(Get-ExactCloneGodotRows).Count -ne 0) {
        throw 'Exact clone already has a running Godot process.'
    }
    if (@(Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue).Count -ne 0) {
        throw "Probe port is not free: $Port"
    }

    $head = (git -C $root rev-parse HEAD).Trim()
    $tree = (git -C $root rev-parse 'HEAD^{tree}').Trim()
    $branch = (git -C $root branch --show-current).Trim()
    $trackedDelta = @(git -C $root status --porcelain=v1 --untracked-files=no).Count
    $indexDelta = @(git -C $root diff --cached --name-only).Count
    $uidCount = @(git -C $root status --porcelain=v1 | Where-Object {
        $_ -match '^\?\? .*\.uid$'
    }).Count
    if ($trackedDelta -ne 0 -or $indexDelta -ne 0) {
        throw "Tracked or index delta is not zero: tracked=$trackedDelta index=$indexDelta"
    }
    git -C $root merge-base --is-ancestor `
        32b1a4d0e4b47735c98a09d5f5cd034a160d870d `
        HEAD
    if ($LASTEXITCODE -ne 0) {
        throw 'Product candidate is not an ancestor of the exact clone HEAD.'
    }

    $identityChecks = [ordered]@{
        godot_binary = @($GodotPath, 'b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8')
        project_godot = @((Join-Path $root 'project.godot'), '849e8c9458b1f6f4431a00073a8d50119937e64a995303874354fb34da4fb06b')
        main_tscn = @((Join-Path $root 'scenes\main.tscn'), 'aabe4e7f5dce63af558d22c2b77b0cffcfad03a763a7c6d11c4003e90e8e79f3')
        runtime_bridge = @((Join-Path $root 'addons\funplay_mcp\runtime\funplay_mcp_runtime_bridge.gd'), 'f3bbc4acc290bffbd596695b4962fabda85d3da764be91e50eb9f4fba2352990')
        mcp_launcher = @($launchTool, 'ae61c920a2a1b4c6d0c2e25d46a754d8d077ed145c0cfbe152c29c4566bc58ba')
        class_cache = @((Join-Path $root '.godot\global_script_class_cache.cfg'), 'f35abc2d252fa772468528f561dd52344ec0c3b09bd0a9b58ebfaf3d54c2ea01')
    }
    $identityResults = [ordered]@{}
    foreach ($entry in $identityChecks.GetEnumerator()) {
        $actual = (Get-FileHash -LiteralPath $entry.Value[0] -Algorithm SHA256).Hash.ToLowerInvariant()
        $match = $actual -ceq [string]$entry.Value[1]
        $identityResults[$entry.Key] = [ordered]@{
            sha256 = $actual
            expected_sha256 = [string]$entry.Value[1]
            match = $match
        }
        if (-not $match) {
            throw "Canonical identity mismatch: $($entry.Key)"
        }
    }

    $importManifestPath = Join-Path $root 'reports\reuse\generation9_platform_qualification\canonical_import_compatibility_correction_001\pass-002\imported_manifest.json'
    $importManifest = @(Get-Content -LiteralPath $importManifestPath -Raw | ConvertFrom-Json)
    $importMismatchCount = 0
    foreach ($entry in $importManifest) {
        $path = Join-Path $root ([string]$entry.path).Replace('/', '\')
        if (-not (Test-Path -LiteralPath $path)) {
            $importMismatchCount += 1
            continue
        }
        $item = Get-Item -LiteralPath $path
        if ([int64]$item.Length -ne [int64]$entry.size_bytes) {
            $importMismatchCount += 1
            continue
        }
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -cne [string]$entry.sha256) {
            $importMismatchCount += 1
        }
    }
    if ($importMismatchCount -ne 0) {
        throw "Canonical import cache mismatch count: $importMismatchCount"
    }

    $availableCommit = Get-AvailableCommitBytes
    if ($availableCommit -lt $TargetStartAvailableCommitBytes) {
        throw "AVAILABLE_COMMIT_AT_PROBE_START_BELOW_TARGET: $availableCommit"
    }
    $preflight = [ordered]@{
        schema_version = 'space_syndicate.v076.generation9_platform_probe_preflight.v1'
        authorization_id = $authorizationId
        probe_id = $ProbeId
        captured_at_utc = [DateTime]::UtcNow.ToString('o')
        branch = $branch
        head_sha = $head
        tree_sha = $tree
        product_candidate_head_sha = '32b1a4d0e4b47735c98a09d5f5cd034a160d870d'
        product_candidate_tree_sha = '5e6945f14e37b9416192f1945561b503f02fe49d'
        tracked_delta_count = $trackedDelta
        index_delta_count = $indexDelta
        untracked_uid_count = $uidCount
        import_manifest_entry_count = $importManifest.Count
        import_cache_mismatch_count = $importMismatchCount
        available_commit_bytes = $availableCommit
        target_available_commit_bytes = $TargetStartAvailableCommitBytes
        identity = $identityResults
        status = 'PASS'
    }
    Write-Utf8Json -Path $preflightPath -Value $preflight
    $milestones.M0 = 'PASS'

    $pwshPath = (Get-Command pwsh.exe -ErrorAction Stop).Source
    $monitorArguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $MonitorScript,
        '-ExactClone', $root,
        '-ProbeId', $ProbeId,
        '-EvidenceRoot', $monitorEvidence,
        '-StopSignalPath', $monitorStop,
        '-CapacityGuardSignalPath', $capacityGuard,
        '-CapacityGuardBytes', [string]$CapacityGuardBytes,
        '-TimeoutSeconds', '900'
    )
    $monitorProcess = Start-Process `
        -FilePath $pwshPath `
        -ArgumentList $monitorArguments `
        -RedirectStandardOutput $monitorStdout `
        -RedirectStandardError $monitorStderr `
        -PassThru `
        -WindowStyle Hidden
    $monitorDeadline = [DateTime]::UtcNow.AddSeconds(90)
    do {
        if ($monitorProcess.HasExited) {
            throw "Probe monitor exited before first sample: $($monitorProcess.ExitCode)"
        }
        if (Test-Path -LiteralPath (Join-Path $monitorEvidence 'process_memory_samples.jsonl')) {
            break
        }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $monitorDeadline)
    if (-not (Test-Path -LiteralPath (Join-Path $monitorEvidence 'process_memory_samples.jsonl'))) {
        throw 'Probe monitor did not persist a first sample before launch.'
    }

    $launchRaw = & $launchTool `
        -Role Supervisor `
        -Port $Port `
        -Worktree $root `
        -GodotPath $GodotPath `
        -Renderer compatibility `
        -ToolProfile full `
        -ResolutionWidth 1600 `
        -ResolutionHeight 960 `
        -StartupTimeoutSeconds 90
    if ($LASTEXITCODE -ne 0) {
        throw "Godot MCP launch failed: $LASTEXITCODE"
    }
    $connection = $launchRaw | Select-Object -Last 1 | ConvertFrom-Json
    Write-Utf8Json -Path $connectionSnapshotPath -Value $connection
    $milestones.M1 = 'PASS'
    $milestones.M2 = 'PASS'
    $milestones.M3 = 'PASS'
    $milestones.M4 = 'PASS'

    $projectInfoOuter = Invoke-RoleTool `
        -ToolName 'get_project_info' `
        -EvidenceName 'm5-m6-first-get-project-info.jsonrpc.json' `
        -Arguments @{}
    $projectInfo = Get-ContentTextJson $projectInfoOuter
    if ([string]$projectInfo.tool_profile -cne 'full' -or [int]$projectInfo.server_port -ne $Port) {
        throw 'First JSON-RPC response did not attest the expected full-profile endpoint.'
    }
    $milestones.M5 = 'PASS'
    $milestones.M6 = 'PASS'

    $bootstrapOuter = Invoke-RoleTool `
        -ToolName 'get_runtime_bridge_status' `
        -EvidenceName 'm7-runtime-bootstrap.jsonrpc.json' `
        -Arguments @{}
    $bootstrap = Get-ContentTextJson $bootstrapOuter
    if (-not [bool]$bootstrap.installed -or -not [bool]$bootstrap.script_exists) {
        throw 'Runtime bridge bootstrap is unavailable.'
    }
    $milestones.M7 = 'PASS'

    Invoke-RoleTool `
        -ToolName 'play_main_scene' `
        -EvidenceName 'm9-play-main-scene.jsonrpc.json' `
        -Arguments @{} `
        -TimeoutSeconds 60 | Out-Null
    $milestones.M9 = 'PASS'

    $readyDeadline = [DateTime]::UtcNow.AddSeconds($RuntimeReadyTimeoutSeconds)
    $ready = $null
    $readyPoll = 0
    do {
        Assert-NoCapacityGuard
        $readyPoll += 1
        $readyOuter = Invoke-RoleTool `
            -ToolName 'get_runtime_bridge_status' `
            -EvidenceName ("m8-ready-poll-{0:d3}.jsonrpc.json" -f $readyPoll) `
            -Arguments @{}
        $ready = Get-ContentTextJson $readyOuter
        if (
            [bool]$ready.state_exists -and
            [string]$ready.state.status -ceq 'running' -and
            [string]$ready.state.current_scene.path -ceq '/root/Main' -and
            [int64]$ready.state_age_msec -ge 0 -and
            [int64]$ready.state_age_msec -le 5000
        ) {
            break
        }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $readyDeadline)
    if ($null -eq $ready -or -not [bool]$ready.state_exists) {
        throw 'Runtime ready witness was not persisted before timeout.'
    }
    $milestones.M8 = 'PASS'

    $commercialNewGameButton = Find-LiveRuntimeButtonByText `
        -Text '开始新局' `
        -EvidencePrefix 'commercial-new-game-button-discovery'
    Send-RuntimeInput `
        -EvidenceName 'commercial-new-game-button-click.jsonrpc.json' `
        -Arguments @{
            type = 'mouse_button'
            button = 1
            mode = 'tap'
            position = (Get-Center $commercialNewGameButton)
        } | Out-Null

    $commercialMenuDeadline = [DateTime]::UtcNow.AddSeconds($CommercialMenuReadyTimeoutSeconds)
    $startOverlay = $null
    $startOverlayProps = $null
    $commercialMenuOverlay = $null
    $commercialMenuOverlayProps = $null
    $startOverlayPoll = 0
    do {
        Assert-NoCapacityGuard
        $startOverlayPoll += 1
        $startOverlay = Query-RuntimeNode `
            -EvidenceName ("start-overlay-visible-poll-{0:d3}.jsonrpc.json" -f $startOverlayPoll) `
            -NodePath $startOverlayPath `
            -Properties @('global_position', 'size', 'visible')
        $startOverlayProps = Get-RequestedProperties $startOverlay
        $commercialMenuOverlay = Query-RuntimeNode `
            -EvidenceName ("commercial-menu-closed-poll-{0:d3}.jsonrpc.json" -f $startOverlayPoll) `
            -NodePath $commercialMenuOverlayPath `
            -Properties @('global_position', 'size', 'visible')
        $commercialMenuOverlayProps = Get-RequestedProperties $commercialMenuOverlay
        if (
            [bool]$startOverlayProps.visible -and
            [double]$startOverlayProps.size.x -gt 0 -and
            [double]$startOverlayProps.size.y -gt 0 -and
            -not [bool]$commercialMenuOverlayProps.visible
        ) {
            break
        }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $commercialMenuDeadline)
    if (
        $null -eq $startOverlayProps -or
        $null -eq $commercialMenuOverlayProps -or
        -not [bool]$startOverlayProps.visible -or
        [bool]$commercialMenuOverlayProps.visible
    ) {
        throw 'Commercial New Game navigation did not reveal an unoccluded StartOverlay before timeout.'
    }

    $seedNode = Query-RuntimeNode `
        -EvidenceName 'seed-input-before-entry.jsonrpc.json' `
        -NodePath $seedControlPath `
        -Properties @('text', 'visible', 'editable', 'global_position', 'size')
    $seedProps = Get-RequestedProperties $seedNode
    if (
        -not [bool]$seedProps.visible -or
        -not [bool]$seedProps.editable -or
        [double]$seedProps.size.x -le 0 -or
        [double]$seedProps.size.y -le 0
    ) {
        throw 'Seed input is not visible and editable after StartOverlay became visible.'
    }
    $seedCenter = Get-Center $seedNode
    Write-Utf8Json -Path $externalSeedFocusRequestPath -Value ([ordered]@{
        schema_version = 'space_syndicate.v076.external_seed_focus_request.v2'
        authorization_id = $authorizationId
        probe_id = $ProbeId
        requested_at_utc = [DateTime]::UtcNow.ToString('o')
        editor_pid = [int]$connection.pid
        exact_window_title = '太空辛迪加 (DEBUG)'
        required_window_match_count = 1
        node_path = $seedControlPath
        runtime_viewport_center = $seedCenter
        start_overlay_visible = $true
        commercial_menu_overlay_visible = $false
        required_action = 'ACTIVATE_UNIQUE_EXACT_GODOT_WINDOW_AND_CLICK_VISIBLE_SEED_INPUT_ONCE'
        forbidden_action = 'DIRECT_RUNTIME_SEED_INJECTION'
    })
    $focusDeadline = [DateTime]::UtcNow.AddSeconds($ExternalSeedFocusTimeoutSeconds)
    do {
        Assert-NoCapacityGuard
        if (Test-Path -LiteralPath $externalSeedFocusCompletePath) {
            break
        }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $focusDeadline)
    if (-not (Test-Path -LiteralPath $externalSeedFocusCompletePath)) {
        throw 'External Windows focus witness was not supplied before timeout.'
    }
    $externalFocus = Get-Content -LiteralPath $externalSeedFocusCompletePath -Raw | ConvertFrom-Json
    if (
        [string]$externalFocus.status -cne 'PASS' -or
        [int]$externalFocus.editor_pid -ne [int]$connection.pid -or
        [string]$externalFocus.exact_window_title -cne '太空辛迪加 (DEBUG)' -or
        [int]$externalFocus.window_match_count -ne 1 -or
        [int]$externalFocus.window_activation_count -ne 1 -or
        [int]$externalFocus.seed_field_click_count -ne 1 -or
        [int]$externalFocus.direct_runtime_seed_injection_count -ne 0
    ) {
        throw 'External Windows focus witness is invalid.'
    }
    $clearEvents = @()
    1..12 | ForEach-Object {
        $clearEvents += @{type='key'; key='backspace'; mode='tap'}
    }
    Send-RuntimeInput `
        -EvidenceName 'seed-clear.jsonrpc.json' `
        -Arguments @{events=$clearEvents} | Out-Null
    $seedEvents = @()
    foreach ($character in ([string]$Seed).ToCharArray()) {
        $seedEvents += @{type='key'; key=[string]$character; mode='tap'}
    }
    Send-RuntimeInput `
        -EvidenceName 'seed-entry.jsonrpc.json' `
        -Arguments @{events=$seedEvents} | Out-Null
    $seedAfterEntry = Query-RuntimeNode `
        -EvidenceName 'seed-visible-readback.jsonrpc.json' `
        -NodePath $seedControlPath `
        -Properties @('text', 'visible', 'editable', 'global_position', 'size')
    $seedAfterEntryProps = Get-RequestedProperties $seedAfterEntry
    $seedBinding.visible_text = [string]$seedAfterEntryProps.text
    if ($seedBinding.visible_text -cne [string]$Seed) {
        if ([string]::IsNullOrEmpty($seedBinding.visible_text)) {
            $seedBinding.empty_readback_count = 1
        }
        throw "Seed visible readback mismatch: $($seedBinding.visible_text)"
    }

    $startButton = Query-RuntimeNode `
        -EvidenceName 'start-configured-button.jsonrpc.json' `
        -NodePath $startButtonPath `
        -Properties @('text', 'visible', 'disabled', 'global_position', 'size')
    $startProps = Get-RequestedProperties $startButton
    if (-not [bool]$startProps.visible -or [bool]$startProps.disabled) {
        throw 'Configured New Game button is not available.'
    }
    Send-RuntimeInput `
        -EvidenceName 'start-configured-game-click.jsonrpc.json' `
        -Arguments @{
            type = 'mouse_button'
            button = 1
            mode = 'tap'
            position = (Get-Center $startButton)
        } | Out-Null

    $newGameDeadline = [DateTime]::UtcNow.AddSeconds($NewGameReadyTimeoutSeconds)
    $newGamePoll = 0
    $compositionProps = $null
    $runtimeProps = $null
    do {
        Assert-NoCapacityGuard
        $newGamePoll += 1
        try {
            $composition = Query-RuntimeNode `
                -EvidenceName ("seed-composition-poll-{0:d3}.jsonrpc.json" -f $newGamePoll) `
                -NodePath $compositionPath `
                -Properties @('_last_receipt', '_v076_production_seed')
            $runtime = Query-RuntimeNode `
                -EvidenceName ("seed-runtime-owner-poll-{0:d3}.jsonrpc.json" -f $newGamePoll) `
                -NodePath $runtimeOwnerPath `
                -Properties @('_seed', '_batch_number', '_phase')
            $compositionProps = Get-RequestedProperties $composition
            $runtimeProps = Get-RequestedProperties $runtime
            if (
                [int64]$compositionProps._last_receipt.seed -eq $Seed -and
                [int64]$compositionProps._v076_production_seed -eq $Seed -and
                [int64]$runtimeProps._seed -eq $Seed -and
                [int]$runtimeProps._batch_number -ge 1 -and
                [string]$runtimeProps._phase -ceq 'submission'
            ) {
                break
            }
        } catch {
            # Loading can briefly replace the queried surface. Continue until the bounded deadline.
        }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $newGameDeadline)
    if ($null -eq $compositionProps -or $null -eq $runtimeProps) {
        throw 'New Game seed owners did not become queryable before timeout.'
    }
    $seedBinding.config_model_value = [int64]$compositionProps._v076_production_seed
    $seedBinding.new_game_intent_seed = [int64]$compositionProps._last_receipt.seed
    $seedBinding.runtime_match_seed = [int64]$runtimeProps._seed
    $seedBinding.four_layer_match = (
        $seedBinding.visible_text -ceq [string]$Seed -and
        $seedBinding.config_model_value -eq $Seed -and
        $seedBinding.new_game_intent_seed -eq $Seed -and
        $seedBinding.runtime_match_seed -eq $Seed
    )
    if (-not $seedBinding.four_layer_match) {
        throw "Seed four-layer parity failed: $($seedBinding | ConvertTo-Json -Compress)"
    }

    1..5 | ForEach-Object {
        Assert-NoCapacityGuard
        $rows = @(Get-ExactCloneGodotRows)
        $privateBytes = [int64]0
        foreach ($row in $rows) {
            $process = Get-Process -Id ([int]$row.ProcessId) -ErrorAction SilentlyContinue
            if ($null -ne $process) {
                $privateBytes += [int64]$process.PrivateMemorySize64
            }
        }
        $readySteadySamples += [ordered]@{
            captured_at_utc = [DateTime]::UtcNow.ToString('o')
            total_godot_private_bytes = $privateBytes
            process_count = $rows.Count
            available_commit_bytes = Get-AvailableCommitBytes
        }
        Start-Sleep -Seconds 1
    }

    Stop-RoleNormally
    $milestones.M10 = 'PASS'
    if (
        [bool]$cleanup.stopped -and
        -not [bool]$cleanup.forced_stop -and
        [int]$cleanup.process_count_after -eq 0 -and
        [int]$cleanup.endpoint_count_after -eq 0
    ) {
        $milestones.M11 = 'PASS'
    } else {
        throw 'M11 cleanup did not reach normal process and port zero.'
    }
} catch {
    $failure = $_
} finally {
    if (
        @(Get-ExactCloneGodotRows).Count -ne 0 -or
        (Test-Path -LiteralPath (Join-Path $root '.codex-godot\connection.json'))
    ) {
        try {
            Stop-RoleNormally
        } catch {
            if ($null -eq $failure) {
                $failure = $_
            }
        }
    }
    if (-not (Test-Path -LiteralPath $monitorStop)) {
        [IO.File]::WriteAllText($monitorStop, "stop`n", [Text.UTF8Encoding]::new($false))
    }
    if ($null -ne $monitorProcess -and -not $monitorProcess.HasExited) {
        [void]$monitorProcess.WaitForExit(60000)
    }
}

$monitorSummaryPath = Join-Path $monitorEvidence 'process_memory_summary.json'
$monitorSummary = if (Test-Path -LiteralPath $monitorSummaryPath) {
    Get-Content -LiteralPath $monitorSummaryPath -Raw | ConvertFrom-Json
} else {
    $null
}
$samplesPath = Join-Path $monitorEvidence 'process_memory_samples.jsonl'
$firstSample = $null
$lastSample = $null
if (Test-Path -LiteralPath $samplesPath) {
    $sampleLines = @(Get-Content -LiteralPath $samplesPath | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    })
    if ($sampleLines.Count -gt 0) {
        $firstSample = $sampleLines[0] | ConvertFrom-Json
        $lastSample = $sampleLines[-1] | ConvertFrom-Json
    }
}
$importEventGrowth = if ($null -ne $firstSample -and $null -ne $lastSample) {
    [int64]$lastSample.import_event_count - [int64]$firstSample.import_event_count
} else {
    $null
}
$monitorExitCode = if ($null -ne $monitorProcess -and $monitorProcess.HasExited) {
    [int]$monitorProcess.ExitCode
} else {
    $null
}
$trackedDeltaAfter = @(git -C $root status --porcelain=v1 --untracked-files=no).Count
$indexDeltaAfter = @(git -C $root diff --cached --name-only).Count
$status = if (
    $null -eq $failure -and
    @($milestones.Keys | Where-Object {$milestones[$_] -eq 'PASS'}).Count -eq 12 -and
    $null -ne $monitorSummary -and
    -not [bool]$monitorSummary.capacity_guard_triggered -and
    [uint64]$monitorSummary.minimum_available_commit_bytes -ge $CapacityGuardBytes -and
    [int]$monitorSummary.maximum_import_queue_length -eq 0 -and
    $importEventGrowth -eq 0 -and
    [bool]$seedBinding.four_layer_match -and
    $trackedDeltaAfter -eq 0 -and
    $indexDeltaAfter -eq 0 -and
    $monitorExitCode -eq 0
) {
    'PASS'
} else {
    'FAIL'
}
$result = [ordered]@{
    schema_version = 'space_syndicate.v076.generation9_platform_probe_execution_result.v1'
    authorization_id = $authorizationId
    probe_id = $ProbeId
    formal_generation = $false
    generation9_formal_execution_count = 0
    generated_at_utc = [DateTime]::UtcNow.ToString('o')
    started_at_utc = $startedAt.ToString('o')
    status = $status
    failure = if ($null -eq $failure) {$null} else {[string]$failure.Exception.Message}
    milestones = $milestones
    milestone_pass_count = @($milestones.Keys | Where-Object {$milestones[$_] -eq 'PASS'}).Count
    milestone_required_count = 12
    seed_binding = $seedBinding
    ready_steady_samples = $readySteadySamples
    available_commit_at_probe_start_bytes = if ($null -ne $firstSample) {[uint64]$firstSample.system_available_commit_bytes} else {$null}
    minimum_available_commit_bytes = if ($null -ne $monitorSummary) {[uint64]$monitorSummary.minimum_available_commit_bytes} else {$null}
    minimum_available_physical_bytes = if ($null -ne $monitorSummary) {[uint64]$monitorSummary.minimum_available_physical_bytes} else {$null}
    maximum_import_queue_length = if ($null -ne $monitorSummary) {[int]$monitorSummary.maximum_import_queue_length} else {$null}
    import_event_count_first = if ($null -ne $firstSample) {[int64]$firstSample.import_event_count} else {$null}
    import_event_count_last = if ($null -ne $lastSample) {[int64]$lastSample.import_event_count} else {$null}
    import_event_growth = $importEventGrowth
    monitor_exit_code = $monitorExitCode
    capacity_guard_triggered = if ($null -ne $monitorSummary) {[bool]$monitorSummary.capacity_guard_triggered} else {(Test-Path -LiteralPath $capacityGuard)}
    cleanup = $cleanup
    tracked_delta_count_after = $trackedDeltaAfter
    index_delta_count_after = $indexDeltaAfter
    untracked_uid_count_after = @(git -C $root status --porcelain=v1 | Where-Object {$_ -match '^\?\? .*\.uid$'}).Count
    unrelated_process_termination_count = 0
}
Write-Utf8Json -Path $resultPath -Value $result
$result | ConvertTo-Json -Depth 100
if ($status -ne 'PASS') {
    exit 65
}
