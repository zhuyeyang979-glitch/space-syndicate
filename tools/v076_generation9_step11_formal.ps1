param(
    [Parameter(Mandatory = $true)][string]$EvidenceRoot,
    [string]$Worktree = (Get-Location).Path,
    [string]$GodotPath = 'C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe',
    [int]$Port = 23207,
    [int]$Seed = 917592522,
    [uint64]$MinimumAvailableCommitBytes = 8589934592,
    [int]$ExternalSeedFocusTimeoutSeconds = 300,
    [int]$RuntimeReadyTimeoutSeconds = 120,
    [int]$NewGameReadyTimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'
$authorizationId = 'USER_AUTHORIZATION_V076_COMMIT_CAPACITY_AND_GENERATION9_20260902'
$generationId = 9
$evidenceId = 9695
$expectedProductHead = 'b33e460610776564dac3616bd341fa829316b1e2'
$expectedProductTree = '449018413600b57b9d503b9610c9ae79e3c8eee1'
$root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd('\')
$out = [IO.Path]::GetFullPath($EvidenceRoot)
$invokeTool = Join-Path $root 'tools\invoke_role_godot_mcp.ps1'
$launchTool = Join-Path $root 'tools\launch_role_godot_mcp.ps1'
$stopTool = Join-Path $root 'tools\stop_role_godot_mcp.ps1'
$environmentSealRelative = 'reports/reuse/full_convergence/generation9/generation9_environment_seal_repair_004.json'
$authorizationRelative = 'reports/reuse/full_convergence/generation9/generation9_authorization_manifest_repair_004.json'
$qualificationSealRelative = 'reports/reuse/generation9_platform_qualification/generation9_platform_qualification_seal_001.json'
$passPairRelative = 'reports/reuse/generation9_platform_qualification/platform_qualification_pass_pair_001.json'
$postRestartSealRelative = 'reports/reuse/generation9_platform_qualification/post_restart_requalification/post_restart_requalification_seal.json'
$classCacheRelative = '.godot/global_script_class_cache.cfg'
$compositionPath = '/root/Main/V075RuntimeComposition'
$runtimePath = "$compositionPath/V075RuntimeOwner"
$privateOwnerPath = "$compositionPath/V076PrivateDirectActionInputOwnerV1"
$etaOwnerPath = "$compositionPath/V076MilitaryPhysicalEtaOwnerV1"
$kernelPath = "$compositionPath/V076DeterministicKernel"
$legacyCombatPath = "$compositionPath/V075CombatRuntimeOwner"
$screenPath = '/root/Main/V075GameScreen'
$startOverlayPath = "$screenPath/OverlayLayer/StartOverlay"
$commercialMenuPath = "$screenPath/OverlayLayer/CommercialShellSurfaceLayer/MenuModalOverlay"
$seedPath = "$startOverlayPath/Center/Panel/Margin/Rows/SeedRow/SeedInput"
$startConfiguredPath = "$startOverlayPath/Center/Panel/Margin/Rows/PlayerButtons/V074SettingsStack/StartConfiguredButton"
$trackRailPath = "$screenPath/RootMargin/Shell/TrackPanel/TrackMargin/TrackRows/TrackScroll/TrackRail"
$handRailPath = "$screenPath/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/HandScroll/HandRail"
$targetRailPath = "$screenPath/RootMargin/Shell/TargetPanel/TargetMargin/TargetRow/TargetScroll/TargetRail"
$confirmPath = "$screenPath/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/QueuePanel/QueueRows/CurrentActionPanel/ActionMargin/ActionRows/ActionButtons/CurrentActionConfirmButton"
$lockPath = "$screenPath/RootMargin/Shell/DockPanel/DockMargin/DockRows/CommandRow/LockButton"
$finishMaintenancePath = "$screenPath/RootMargin/Shell/DockPanel/DockMargin/DockRows/CommandRow/FinishMaintenanceButton"
$targetSearchPath = "$screenPath/PlaytestUtilityLayer/PlaytestSafeArea/V074TargetRailFloat/V074VirtualizedTargetRail/RailRows/Body/SearchInput"
$regionPopupPath = "$screenPath/OverlayLayer/RegionPopup"
$focusRequestPath = Join-Path $out 'external-seed-focus-request.json'
$focusCompletePath = Join-Path $out 'external-seed-focus-complete.json'
$preflightPath = Join-Path $out 'preflight.json'
$blockedPath = Join-Path $out 'pre-execution-blocked.json'
$consumptionPath = Join-Path $out 'formal-execution-consumption.json'
$resultPath = Join-Path $out 'formal-execution-result.json'
$connection = $null
$formalConsumed = $false
$cleanup = $null
$failure = $null
$startedAt = [DateTime]::UtcNow
$stepReceipts = [Collections.Generic.List[object]]::new()

function Write-Json {
    param([string]$Path, [object]$Value)
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 100 -Compress) + "`n"), [Text.UTF8Encoding]::new($false))
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-AvailableCommitBytes {
    return [uint64](Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).FreeVirtualMemory * 1024
}

function Get-BootId {
    return [int64](Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' -Name BootId -ErrorAction Stop).BootId
}

function Get-ExactGodotRows {
    return @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
        [string]$_.Name -match '^Godot.*\.exe$' -and [string]$_.CommandLine -like "*$root*"
    })
}

function Get-ListenerCount {
    return @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue).Count
}

function Invoke-RoleTool {
    param([string]$ToolName, [string]$EvidenceName, [hashtable]$Arguments = @{}, [int]$TimeoutSeconds = 60)
    $rawPath = Join-Path $out ("raw\" + $EvidenceName)
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($rawPath)) | Out-Null
    $raw = & $invokeTool -ToolName $ToolName -ArgumentsJson ($Arguments | ConvertTo-Json -Compress -Depth 100) -Worktree $root -TimeoutSeconds $TimeoutSeconds -RawResponsePath $rawPath
    if ($LASTEXITCODE -ne 0) { throw "MCP_TOOL_FAILED:${ToolName}:$LASTEXITCODE" }
    return ($raw | Select-Object -Last 1 | ConvertFrom-Json -Depth 100)
}

function Get-Inner {
    param([object]$Outer)
    $text = [string](@($Outer.result.content | Where-Object {[string]$_.type -eq 'text'})[0].text)
    if ([string]::IsNullOrWhiteSpace($text)) { throw 'MCP_RESPONSE_TEXT_MISSING' }
    return ($text | ConvertFrom-Json -Depth 100)
}

function Query-Node {
    param([string]$Name, [string]$Path, [string[]]$Properties, [switch]$Children, [int]$MaxDepth = 2, [int]$MaxNodes = 80)
    $inner = Get-Inner (Invoke-RoleTool -ToolName 'query_runtime_node' -EvidenceName $Name -Arguments @{
        node_path=$Path; properties=$Properties; include_children=[bool]$Children; max_depth=$MaxDepth; max_nodes=$MaxNodes; timeout_msec=10000
    })
    if (-not [bool]$inner.success) { throw "RUNTIME_QUERY_FAILED:$Path" }
    return $inner.result
}

function Send-Input {
    param([string]$Name, [hashtable]$Arguments)
    $inner = Get-Inner (Invoke-RoleTool -ToolName 'send_runtime_input' -EvidenceName $Name -Arguments $Arguments)
    if (-not [bool]$inner.success) { throw "RUNTIME_INPUT_FAILED:$Name" }
    return $inner.result
}

function Get-Props {
    param([object]$Node)
    if ($null -ne $Node.requested_properties) { return $Node.requested_properties }
    return $Node.properties
}

function Get-Center {
    param([object]$Node)
    $p = Get-Props $Node
    return [ordered]@{x=[double]$p.global_position.x + [double]$p.size.x / 2.0; y=[double]$p.global_position.y + [double]$p.size.y / 2.0}
}

function Click-Node {
    param([string]$Name, [object]$Node)
    Send-Input -Name $Name -Arguments @{type='mouse_button';button=1;mode='tap';position=(Get-Center $Node)} | Out-Null
}

function Query-Clickable {
    param([string]$Name, [string]$Path)
    $node = Query-Node -Name $Name -Path $Path -Properties @('text','visible','disabled','global_position','size')
    $p = Get-Props $node
    if (-not [bool]$p.visible -or [bool]$p.disabled -or [double]$p.size.x -le 0 -or [double]$p.size.y -le 0) { throw "CONTROL_NOT_CLICKABLE:$Path" }
    return $node
}

function Flatten-Tree {
    param([object]$Tree)
    $result = [Collections.Generic.List[object]]::new()
    $queue = [Collections.Generic.Queue[object]]::new()
    $queue.Enqueue($Tree)
    while ($queue.Count -gt 0) {
        $node = $queue.Dequeue(); $result.Add($node)
        foreach ($child in @($node.children)) { if ($null -ne $child) {$queue.Enqueue($child)} }
    }
    return @($result)
}

function Find-ButtonByText {
    param([string]$Name, [string]$Text, [int]$TimeoutSeconds = 30)
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $tree = Query-Node -Name "$Name-tree.jsonrpc.json" -Path '/root/Main' -Properties @('text','visible','disabled','global_position','size') -Children -MaxDepth 8 -MaxNodes 500
        $matches = @(Flatten-Tree $tree.tree | Where-Object {
            [string]$_.type -eq 'Button' -and [string]$_.properties.text -ceq $Text -and [bool]$_.properties.visible -and -not [bool]$_.properties.disabled
        })
        if ($matches.Count -eq 1) { return $matches[0] }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "UNIQUE_BUTTON_NOT_FOUND:$Text"
}

function Wait-Runtime {
    param([string]$Name, [scriptblock]$Predicate, [int]$TimeoutSeconds = 90)
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $index = 0
    do {
        $index++
        $node = Query-Node -Name ("{0}-{1:d3}.jsonrpc.json" -f $Name,$index) -Path $runtimePath -Properties @('_batch_number','_phase','_seed','_invalid_action_count','_runtime_error_count','_v075_snapshot')
        $p = Get-Props $node
        if (& $Predicate $p) { return $p }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "RUNTIME_WAIT_TIMEOUT:$Name"
}

function Capture-View {
    param([string]$Name)
    $outer = Invoke-RoleTool -ToolName 'capture_runtime_view' -EvidenceName "$Name.jsonrpc.json" -Arguments @{return_data_uri=$true;timeout_msec=10000}
    $inner = Get-Inner $outer
    if (-not [bool]$inner.success -or -not [bool]$inner.result.captured) { throw "SCREENSHOT_FAILED:$Name" }
    $uri = [string]$inner.result.data_uri
    if ($uri -notmatch '^data:image/png;base64,(.+)$') { throw "SCREENSHOT_DATA_INVALID:$Name" }
    $path = Join-Path $out ("screenshots\$Name.png")
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
    [IO.File]::WriteAllBytes($path, [Convert]::FromBase64String($Matches[1]))
    return $path
}

function Select-FirstTargetAndConfirm {
    param([int]$Batch, [int]$Card)
    $rail = Query-Node -Name "batch$Batch-card$Card-hand.jsonrpc.json" -Path $handRailPath -Properties @('visible','global_position','size') -Children -MaxDepth 1 -MaxNodes 10
    $cards = @(Flatten-Tree $rail.tree | Where-Object {[string]$_.script_path -eq 'res://scripts/ui/v075/v075_interactive_card_face.gd' -and [bool]$_.properties.visible})
    if ($cards.Count -lt 1) { throw "HAND_CARD_MISSING:batch=${Batch}:card=$Card" }
    Click-Node -Name "batch$Batch-card$Card-select.jsonrpc.json" -Node $cards[0]
    $targetRail = Query-Node -Name "batch$Batch-card$Card-target-rail.jsonrpc.json" -Path $targetRailPath -Properties @('text','visible','global_position','size') -Children -MaxDepth 1 -MaxNodes 5
    $toggle = @(Flatten-Tree $targetRail.tree | Where-Object {[string]$_.type -eq 'Button' -and [bool]$_.properties.visible})
    if ($toggle.Count -ne 1) { throw "TARGET_TOGGLE_MISSING:batch=${Batch}:card=$Card" }
    Click-Node -Name "batch$Batch-card$Card-open-targets.jsonrpc.json" -Node $toggle[0]
    $search = Query-Clickable -Name "batch$Batch-card$Card-target-search.jsonrpc.json" -Path $targetSearchPath
    Click-Node -Name "batch$Batch-card$Card-focus-target-search.jsonrpc.json" -Node $search
    Send-Input -Name "batch$Batch-card$Card-first-target.jsonrpc.json" -Arguments @{events=@(@{type='key';key='down';mode='tap'},@{type='key';key='enter';mode='tap'})} | Out-Null
    Click-Node -Name "batch$Batch-card$Card-confirm.jsonrpc.json" -Node (Query-Clickable -Name "batch$Batch-card$Card-confirm-query.jsonrpc.json" -Path $confirmPath)
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        $state = Get-Props (Query-Node -Name "batch$Batch-card$Card-idle.jsonrpc.json" -Path $screenPath -Properties @('_current_action_mode','_action_submission_pending'))
        if ([string]$state._current_action_mode -eq 'idle' -and -not [bool]$state._action_submission_pending) { return }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "CARD_SUBMISSION_DID_NOT_SETTLE:batch=${Batch}:card=$Card"
}

function Complete-NormalBatch {
    param([int]$Batch)
    1..5 | ForEach-Object { Select-FirstTargetAndConfirm -Batch $Batch -Card $_ }
    Click-Node -Name "batch$Batch-lock.jsonrpc.json" -Node (Query-Clickable -Name "batch$Batch-lock-query.jsonrpc.json" -Path $lockPath)
    [void](Wait-Runtime -Name "batch$Batch-maintenance" -TimeoutSeconds 180 -Predicate {param($p) [int]$p._batch_number -eq $Batch -and [string]$p._phase -eq 'maintenance'})
    Click-Node -Name "batch$Batch-finish-maintenance.jsonrpc.json" -Node (Query-Clickable -Name "batch$Batch-finish-maintenance-query.jsonrpc.json" -Path $finishMaintenancePath)
    [void](Wait-Runtime -Name "batch$Batch-next-submission" -TimeoutSeconds 30 -Predicate {param($p) [int]$p._batch_number -eq ($Batch + 1) -and [string]$p._phase -eq 'submission'})
}

function Wait-And-Finish-EmptyBatch {
    param([int]$Batch)
    [void](Wait-Runtime -Name "batch$Batch-empty-maintenance" -TimeoutSeconds 180 -Predicate {param($p) [int]$p._batch_number -eq $Batch -and [string]$p._phase -eq 'maintenance'})
    Click-Node -Name "batch$Batch-empty-finish-maintenance.jsonrpc.json" -Node (Query-Clickable -Name "batch$Batch-empty-finish-maintenance-query.jsonrpc.json" -Path $finishMaintenancePath)
    [void](Wait-Runtime -Name "batch$Batch-empty-next-submission" -TimeoutSeconds 30 -Predicate {param($p) [int]$p._batch_number -eq ($Batch + 1) -and [string]$p._phase -eq 'submission'})
}

function Stop-Normally {
    $exit = $null
    try { $exit = Get-Inner (Invoke-RoleTool -ToolName 'exit_play_mode' -EvidenceName 'cleanup-exit-play-mode.jsonrpc.json' -Arguments @{}) } catch {}
    $stopRaw = & $stopTool -Role Supervisor -Port $Port -Worktree $root
    $stopExit = $LASTEXITCODE
    $stopValue = if ($stopExit -eq 0) {$stopRaw | Select-Object -Last 1 | ConvertFrom-Json} else {$null}
    Start-Sleep -Milliseconds 500
    $cleanup = [ordered]@{
        exit_play_mode = if ($null -ne $exit -and [bool]$exit.success) {'PASS'} else {'FAIL'}
        stop_role_godot_mcp = if ($stopExit -eq 0) {'PASS'} else {'FAIL'}
        editor_pid_after = @(Get-ExactGodotRows).Count
        game_pid_after = @(Get-ExactGodotRows | Where-Object {[string]$_.CommandLine -match '--path'}).Count
        listener_count_after = Get-ListenerCount
        stopped = if ($null -ne $stopValue) {[bool]$stopValue.stopped} else {$false}
        forced_stop = if ($null -ne $stopValue) {[bool]$stopValue.forced_stop} else {$true}
    }
    return $cleanup
}

try {
    [IO.Directory]::CreateDirectory($out) | Out-Null
    $head = (& git -C $root rev-parse HEAD).Trim()
    $tree = (& git -C $root rev-parse 'HEAD^{tree}').Trim()
    $trackedDelta = @(& git -C $root status --porcelain=v1 --untracked-files=no)
    $environmentSealPath = Join-Path $root $environmentSealRelative
    $authorizationPath = Join-Path $root $authorizationRelative
    $environment = Get-Content -LiteralPath $environmentSealPath -Raw | ConvertFrom-Json -Depth 100 -DateKind String
    $authorization = Get-Content -LiteralPath $authorizationPath -Raw | ConvertFrom-Json -Depth 100 -DateKind String
    $availableCommit = Get-AvailableCommitBytes
    $bootId = Get-BootId
    $godotCount = @(Get-ExactGodotRows).Count
    $listenerCount = Get-ListenerCount
    $importPendingCount = @(Get-ChildItem -LiteralPath (Join-Path $root '.godot\imported') -File -Recurse -ErrorAction Stop | Where-Object {$_.Name -match '\.(tmp|importing)$'}).Count
    $stabilityStart = [DateTimeOffset]::Parse(
        [string]$environment.sealed_at_utc,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::AssumeUniversal
    ).UtcDateTime
    $stabilityIds = @(7,18,19,20,41,51,55,129,153,1001)
    $newStabilityEvents = @(Get-WinEvent -FilterHashtable @{LogName='System';StartTime=$stabilityStart.ToLocalTime()} -ErrorAction SilentlyContinue | Where-Object {$stabilityIds -contains [int]$_.Id -and $_.TimeCreated.ToUniversalTime() -ge $stabilityStart}).Count
    $checks = [ordered]@{
        head_matches_environment_commit = ($head -eq (& git -C $root log -1 --format=%H -- $environmentSealRelative).Trim())
        tree_matches_head = ($tree -eq (& git -C $root rev-parse 'HEAD^{tree}').Trim())
        tracked_delta_count = $trackedDelta.Count
        environment_seal_status = [string]$environment.status
        authorization_status = [string]$authorization.status
        authorization_id_match = ([string]$environment.authorization_id -eq $authorizationId -and [string]$authorization.authorization_id -eq $authorizationId)
        generation_id_match = ([int]$environment.generation_id -eq $generationId -and [int]$authorization.generation_id -eq $generationId)
        evidence_id_match = ([int]$environment.new_evidence_id -eq $evidenceId -and [int]$authorization.new_evidence_id -eq $evidenceId)
        product_identity_match = ([string]$environment.product_subject_head_sha -eq $expectedProductHead -and [string]$environment.product_subject_tree_sha -eq $expectedProductTree)
        seed_match = ([int64]$environment.selected_seed -eq $Seed)
        boot_id_expected = [int64]$environment.current_boot_id
        boot_id_actual = $bootId
        new_stability_event_count = $newStabilityEvents
        available_commit_bytes = $availableCommit
        minimum_available_commit_bytes = $MinimumAvailableCommitBytes
        import_pending_count = $importPendingCount
        godot_process_count = $godotCount
        listener_count = $listenerCount
        qualification_seal_sha256_match = ([string]$environment.platform_qualification_seal_sha256 -eq (Get-Sha256 (Join-Path $root $qualificationSealRelative)))
        pass_pair_sha256_match = ([string]$environment.platform_pass_pair_sha256 -eq (Get-Sha256 (Join-Path $root $passPairRelative)))
        post_restart_seal_sha256_match = ([string]$environment.post_restart_requalification_seal_sha256 -eq (Get-Sha256 (Join-Path $root $postRestartSealRelative)))
        class_cache_sha256_match = ([string]$environment.class_cache_sha256 -eq (Get-Sha256 (Join-Path $root $classCacheRelative)))
        authorization_manifest_sha256_match = ([string]$environment.authorization_manifest_sha256 -eq (Get-Sha256 $authorizationPath))
        godot_binary_sha256_match = ([string]$environment.godot_binary_sha256 -eq (Get-Sha256 ([string]$authorization.godot_binary_path)))
        mcp_config_sha256_match = ([string]$environment.mcp_config_sha256 -eq (Get-Sha256 (Join-Path $root ([string]$authorization.mcp_config_path))))
        canonical_import_manifest_sha256_match = ([string]$environment.canonical_import_manifest_sha256 -eq (Get-Sha256 (Join-Path $root ([string]$authorization.canonical_import_manifest_path))))
        receipt_schema_sha256_match = ([string]$environment.receipt_schema_sha256 -eq (Get-Sha256 (Join-Path $root ([string]$authorization.receipt_schema_path))))
        receipt_validator_sha256_match = ([string]$environment.receipt_validator_sha256 -eq (Get-Sha256 (Join-Path $root ([string]$authorization.receipt_validator_path))))
        receipt_selftest_sha256_match = ([string]$environment.receipt_selftest_sha256 -eq (Get-Sha256 (Join-Path $root ([string]$authorization.receipt_selftest_path))))
        required_workflow_sha256_match = ([string]$environment.required_workflow_sha256 -eq (Get-Sha256 (Join-Path $root ([string]$authorization.required_workflow_path))))
        formal_runner_sha256_match = ([string]$environment.formal_runner_sha256 -eq (Get-Sha256 (Join-Path $root ([string]$authorization.formal_runner_path))))
        formal_runner_selftest_sha256_match = ([string]$environment.formal_runner_selftest_sha256 -eq (Get-Sha256 (Join-Path $root ([string]$authorization.formal_runner_selftest_path))))
        tooling_seal_sha256_match = ([string]$environment.tooling_seal_sha256 -eq (Get-Sha256 (Join-Path $root ([string]$authorization.tooling_seal_path))))
        formal_execution_count_before = [int]$environment.formal_execution_count_before
        automatic_retry = [bool]$environment.automatic_retry
    }
    Write-Json -Path $preflightPath -Value ([ordered]@{schema_version='space_syndicate.v076.generation9_formal_preflight.v1';authorization_id=$authorizationId;generation_id=$generationId;head_sha=$head;tree_sha=$tree;checked_at_utc=[DateTime]::UtcNow.ToString('o');checks=$checks})
    $preflightPass = (
        $checks.head_matches_environment_commit -and $checks.tree_matches_head -and $checks.tracked_delta_count -eq 0 -and
        $checks.environment_seal_status -eq 'SEALED_PRE_EXECUTION' -and $checks.authorization_status -eq 'SEALED' -and
        $checks.authorization_id_match -and $checks.generation_id_match -and $checks.evidence_id_match -and
        $checks.product_identity_match -and $checks.seed_match -and $checks.boot_id_actual -eq $checks.boot_id_expected -and
        $checks.new_stability_event_count -eq 0 -and $checks.available_commit_bytes -ge $MinimumAvailableCommitBytes -and
        $checks.import_pending_count -eq 0 -and $checks.godot_process_count -eq 0 -and $checks.listener_count -eq 0 -and
        $checks.qualification_seal_sha256_match -and $checks.pass_pair_sha256_match -and
        $checks.post_restart_seal_sha256_match -and $checks.class_cache_sha256_match -and
        $checks.authorization_manifest_sha256_match -and $checks.godot_binary_sha256_match -and
        $checks.mcp_config_sha256_match -and $checks.canonical_import_manifest_sha256_match -and
        $checks.receipt_schema_sha256_match -and $checks.receipt_validator_sha256_match -and
        $checks.receipt_selftest_sha256_match -and $checks.required_workflow_sha256_match -and
        $checks.formal_runner_sha256_match -and $checks.formal_runner_selftest_sha256_match -and
        $checks.tooling_seal_sha256_match -and
        $checks.formal_execution_count_before -eq 0 -and -not $checks.automatic_retry
    )
    if (-not $preflightPass) {
        Write-Json -Path $blockedPath -Value ([ordered]@{schema_version='space_syndicate.v076.generation9_pre_execution_blocked.v1';status='PRE_EXECUTION_BLOCKED';generation9_formal_execution_count=0;automatic_retry_count=0;preflight_sha256=(Get-Sha256 $preflightPath);created_at_utc=[DateTime]::UtcNow.ToString('o')})
        throw 'PRE_EXECUTION_BLOCKED'
    }

    $launchRaw = & $launchTool -Role Supervisor -Port $Port -Worktree $root -GodotPath $GodotPath -Renderer compatibility -ToolProfile full -ResolutionWidth 1600 -ResolutionHeight 960 -StartupTimeoutSeconds 90
    if ($LASTEXITCODE -ne 0) { throw "FORMAL_GODOT_PROCESS_START_FAILED:$LASTEXITCODE" }
    $connection = $launchRaw | Select-Object -Last 1 | ConvertFrom-Json
    $formalConsumed = $true
    Write-Json -Path $consumptionPath -Value ([ordered]@{schema_version='space_syndicate.v076.generation9_formal_execution_consumption.v1';status='CONSUMED';authorization_id=$authorizationId;generation_id=$generationId;formal_execution_count=1;automatic_retry_count=0;first_product_process_pid=[int]$connection.pid;execution_head_sha=$head;execution_tree_sha=$tree;consumed_at_utc=[DateTime]::UtcNow.ToString('o')})

    $projectInfo = Get-Inner (Invoke-RoleTool -ToolName 'get_project_info' -EvidenceName 'project-info.jsonrpc.json' -Arguments @{})
    if ([string]$projectInfo.tool_profile -ne 'full' -or [int]$projectInfo.server_port -ne $Port) { throw 'MCP_ENDPOINT_IDENTITY_MISMATCH' }
    $bridge = Get-Inner (Invoke-RoleTool -ToolName 'get_runtime_bridge_status' -EvidenceName 'runtime-bridge-bootstrap.jsonrpc.json' -Arguments @{})
    if (-not [bool]$bridge.installed -or -not [bool]$bridge.script_exists) { throw 'RUNTIME_BRIDGE_UNAVAILABLE' }
    Invoke-RoleTool -ToolName 'play_main_scene' -EvidenceName 'play-main-scene.jsonrpc.json' -Arguments @{} | Out-Null
    $readyDeadline = [DateTime]::UtcNow.AddSeconds($RuntimeReadyTimeoutSeconds)
    do {
        $runtimeStatus = Get-Inner (Invoke-RoleTool -ToolName 'get_runtime_bridge_status' -EvidenceName 'runtime-ready-poll.jsonrpc.json' -Arguments @{})
        if ([bool]$runtimeStatus.state_exists -and [string]$runtimeStatus.state.status -eq 'running' -and [string]$runtimeStatus.state.current_scene.path -eq '/root/Main') { break }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $readyDeadline)
    if (-not [bool]$runtimeStatus.state_exists -or [string]$runtimeStatus.state.status -ne 'running' -or [string]$runtimeStatus.state.current_scene.path -ne '/root/Main') { throw 'RUNTIME_READY_TIMEOUT' }

    $commercialButton = Find-ButtonByText -Name 'commercial-new-game' -Text '开始新局'
    Click-Node -Name 'commercial-new-game-click.jsonrpc.json' -Node $commercialButton
    $overlayDeadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        $startOverlay = Get-Props (Query-Node -Name 'start-overlay.jsonrpc.json' -Path $startOverlayPath -Properties @('visible','global_position','size'))
        $commercialOverlay = Get-Props (Query-Node -Name 'commercial-overlay.jsonrpc.json' -Path $commercialMenuPath -Properties @('visible'))
        if ([bool]$startOverlay.visible -and -not [bool]$commercialOverlay.visible) { break }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $overlayDeadline)
    if (-not [bool]$startOverlay.visible -or [bool]$commercialOverlay.visible) { throw 'START_OVERLAY_OCCLUDED' }

    $seedNode = Query-Clickable -Name 'seed-before-entry.jsonrpc.json' -Path $seedPath
    $seedCenter = Get-Center $seedNode
    Write-Json -Path $focusRequestPath -Value ([ordered]@{schema_version='space_syndicate.v076.external_seed_focus_request.v2';authorization_id=$authorizationId;formal_attempt_id='formal-attempt-001';requested_at_utc=[DateTime]::UtcNow.ToString('o');editor_pid=[int]$connection.pid;exact_window_title='太空辛迪加 (DEBUG)';required_window_match_count=1;node_path=$seedPath;runtime_viewport_center=$seedCenter;runtime_viewport_coordinate_advisory_only=$true;computer_use_coordinate_space='WINDOW_RELATIVE_INCLUDING_WINDOW_CHROME';computer_use_required_screenshot_frame='FULL_WINDOW_FRAME';required_action='ACTIVATE_UNIQUE_EXACT_GODOT_WINDOW_AND_CLICK_VISIBLE_SEED_INPUT_ONCE';forbidden_action='DIRECT_RUNTIME_SEED_INJECTION'})
    $focusDeadline = [DateTime]::UtcNow.AddSeconds($ExternalSeedFocusTimeoutSeconds)
    do { if (Test-Path -LiteralPath $focusCompletePath) {break}; Start-Sleep -Milliseconds 250 } while ([DateTime]::UtcNow -lt $focusDeadline)
    if (-not (Test-Path -LiteralPath $focusCompletePath)) { throw 'EXTERNAL_SEED_FOCUS_TIMEOUT' }
    $focus = Get-Content -LiteralPath $focusCompletePath -Raw | ConvertFrom-Json
    if ([string]$focus.status -ne 'PASS' -or [int]$focus.editor_pid -ne [int]$connection.pid -or [string]$focus.exact_window_title -ne '太空辛迪加 (DEBUG)' -or [int]$focus.window_match_count -ne 1 -or [int]$focus.window_activation_count -ne 1 -or [int]$focus.seed_field_click_count -ne 1 -or [int]$focus.direct_runtime_seed_injection_count -ne 0 -or -not [bool]$focus.full_window_frame_screenshot_used -or [bool]$focus.runtime_viewport_coordinate_used_for_click) { throw 'EXTERNAL_SEED_FOCUS_WITNESS_INVALID' }
    $clearEvents = @(); 1..12 | ForEach-Object {$clearEvents += @{type='key';key='backspace';mode='tap'}}
    Send-Input -Name 'seed-clear.jsonrpc.json' -Arguments @{events=$clearEvents} | Out-Null
    $seedEvents = @(); foreach($character in ([string]$Seed).ToCharArray()) {$seedEvents += @{type='key';key=[string]$character;mode='tap'}}
    Send-Input -Name 'seed-entry.jsonrpc.json' -Arguments @{events=$seedEvents} | Out-Null
    $seedVisible = [string](Get-Props (Query-Node -Name 'seed-visible-readback.jsonrpc.json' -Path $seedPath -Properties @('text'))).text
    if ($seedVisible -ne [string]$Seed) { throw "SEED_VISIBLE_READBACK_MISMATCH:$seedVisible" }
    Click-Node -Name 'start-configured-game.jsonrpc.json' -Node (Query-Clickable -Name 'start-configured-query.jsonrpc.json' -Path $startConfiguredPath)
    $readyGame = Wait-Runtime -Name 'new-game-ready' -TimeoutSeconds $NewGameReadyTimeoutSeconds -Predicate {param($p) [int64]$p._seed -eq $Seed -and [int]$p._batch_number -eq 1 -and [string]$p._phase -eq 'submission'}
    $composition = Get-Props (Query-Node -Name 'new-game-seed-receipt.jsonrpc.json' -Path $compositionPath -Properties @('_last_new_game_receipt','_v076_production_seed'))
    if ([int64]$composition._last_new_game_receipt.seed -ne $Seed -or [int64]$composition._v076_production_seed -ne $Seed) { throw 'SEED_RECEIPT_MISMATCH' }
    $skip = Find-ButtonByText -Name 'tutorial-skip' -Text '跳过全部'
    Click-Node -Name 'tutorial-skip-click.jsonrpc.json' -Node $skip
    $trackSnapshot = Get-Props (Query-Node -Name 'initial-track-snapshot.jsonrpc.json' -Path $runtimePath -Properties @('_v075_snapshot'))
    $segment = @($trackSnapshot._v075_snapshot.unified_track.viewer_private_facts.own_segment_items)
    $militaryItem = @($segment | Where-Object {[string]$_.card_definition_id -eq 'military.air_superiority_fighter.shipping.rank_1'})
    if ($militaryItem.Count -ne 1 -or [int]$militaryItem[0].local_slot_index -ne 1) { throw 'MILITARY_TRACK_CARD_IDENTITY_MISMATCH' }
    $trackRail = Query-Node -Name 'track-rail-geometry.jsonrpc.json' -Path $trackRailPath -Properties @('visible','global_position','size') -Children -MaxDepth 1 -MaxNodes 20
    $trackCards = @(Flatten-Tree $trackRail.tree | Where-Object {[string]$_.script_path -eq 'res://scripts/ui/v075/v075_interactive_card_face.gd' -and [bool]$_.properties.visible})
    if ($trackCards.Count -lt 2) { throw 'TRACK_CARD_GEOMETRY_INCOMPLETE' }
    Click-Node -Name 'select-military-track-card.jsonrpc.json' -Node $trackCards[1]
    Click-Node -Name 'confirm-military-track-acquire.jsonrpc.json' -Node (Query-Clickable -Name 'confirm-military-track-acquire-query.jsonrpc.json' -Path $confirmPath)
    [void](Capture-View -Name '01-military-card-acquired')
    $idleDeadline = [DateTime]::UtcNow.AddSeconds(15)
    do {$actionState=Get-Props(Query-Node -Name 'track-acquire-idle.jsonrpc.json' -Path $screenPath -Properties @('_current_action_mode','_action_submission_pending'));if([string]$actionState._current_action_mode -eq 'idle' -and -not [bool]$actionState._action_submission_pending){break};Start-Sleep -Milliseconds 200}while([DateTime]::UtcNow-lt$idleDeadline)
    if ([string]$actionState._current_action_mode -ne 'idle') { throw 'TRACK_ACQUISITION_DID_NOT_SETTLE' }

    Complete-NormalBatch -Batch 1
    Complete-NormalBatch -Batch 2
    $batch3 = Wait-Runtime -Name 'batch3-hand' -TimeoutSeconds 20 -Predicate {param($p) @($p._v075_snapshot.personal_dbg.facts.hand | Where-Object {[string]$_.card_definition_id -eq 'military.air_superiority_fighter.shipping.rank_1'}).Count -eq 1}
    $hand = @($batch3._v075_snapshot.personal_dbg.facts.hand)
    $militaryIndex = -1
    for($index=0;$index-lt$hand.Count;$index++){if([string]$hand[$index].card_definition_id -eq 'military.air_superiority_fighter.shipping.rank_1'){$militaryIndex=$index;break}}
    if ($militaryIndex -lt 0) { throw 'MILITARY_CARD_NOT_DRAWN_IN_BATCH3' }
    $handRail = Query-Node -Name 'batch3-hand-geometry.jsonrpc.json' -Path $handRailPath -Properties @('visible','global_position','size') -Children -MaxDepth 1 -MaxNodes 10
    $handCards = @(Flatten-Tree $handRail.tree | Where-Object {[string]$_.script_path -eq 'res://scripts/ui/v075/v075_interactive_card_face.gd' -and [bool]$_.properties.visible})
    Click-Node -Name 'batch3-select-military-card.jsonrpc.json' -Node $handCards[$militaryIndex]
    $popup = Query-Node -Name 'batch3-military-popup-tree.jsonrpc.json' -Path $regionPopupPath -Properties @('text','visible','global_position','size') -Children -MaxDepth 8 -MaxNodes 100
    $popupNodes = @(Flatten-Tree $popup.tree)
    $optionButton = @($popupNodes | Where-Object {[string]$_.type -eq 'OptionButton' -and [bool]$_.properties.visible})
    $chooseButton = @($popupNodes | Where-Object {[string]$_.type -eq 'Button' -and [string]$_.properties.text -eq '选择地区' -and [bool]$_.properties.visible})
    if ($optionButton.Count -ne 1 -or $chooseButton.Count -ne 1) { throw 'MILITARY_REGION_SELECTOR_NOT_UNIQUE' }
    $screenMilitary = Get-Props (Query-Node -Name 'batch3-military-options.jsonrpc.json' -Path $screenPath -Properties @('_combat_projection'))
    $options = @($screenMilitary._combat_projection.military_task_options | Where-Object {[string]$_.task_kind -eq 'assault_region'} | Sort-Object option_id)
    $regionIndex = -1
    for($index=0;$index-lt$options.Count;$index++){if([string]$options[$index].target_region_id -eq 'region.005'){$regionIndex=$index;break}}
    if ($regionIndex -lt 0) { throw 'REGION_005_NOT_LEGAL' }
    Click-Node -Name 'batch3-open-region-option.jsonrpc.json' -Node $optionButton[0]
    $selectEvents = @(@{type='key';key='home';mode='tap'}); if($regionIndex -gt 0){1..$regionIndex | ForEach-Object {$selectEvents += @{type='key';key='down';mode='tap'}}}; $selectEvents += @{type='key';key='enter';mode='tap'}
    Send-Input -Name 'batch3-select-region005.jsonrpc.json' -Arguments @{events=$selectEvents} | Out-Null
    Click-Node -Name 'batch3-choose-region005.jsonrpc.json' -Node $chooseButton[0]
    $bound = Get-Props (Query-Node -Name 'batch3-bound-military-target.jsonrpc.json' -Path $screenPath -Properties @('_current_action_mode','_pending_confirm_binding','_selected_card_id'))
    if ([string]$bound._pending_confirm_binding.target_region_id -ne 'region.005' -or [string]$bound._pending_confirm_binding.task_kind -ne 'assault_region') { throw 'MILITARY_TARGET_BINDING_MISMATCH' }
    [void](Capture-View -Name '02-assault-region-ready-to-confirm')
    Click-Node -Name 'batch3-confirm-military-action.jsonrpc.json' -Node (Query-Clickable -Name 'batch3-confirm-military-query.jsonrpc.json' -Path $confirmPath)
    $immediatePrivate = Get-Props (Query-Node -Name 'military-private-owner-immediate.jsonrpc.json' -Path $privateOwnerPath -Properties @('_collision_count','_rejection_count','_submitted_result_by_id','_submission_fingerprint_by_id','_intake_settlement_result_by_id','_settlement_fingerprint_by_id'))
    $immediateEta = Get-Props (Query-Node -Name 'military-eta-owner-immediate.jsonrpc.json' -Path $etaOwnerPath -Properties @('_calculation_count','_rejection_count'))
    $resolutionDeadline = [DateTime]::UtcNow.AddSeconds(60)
    do {
        $finalPrivate = Get-Props (Query-Node -Name 'military-private-owner-resolution-poll.jsonrpc.json' -Path $privateOwnerPath -Properties @('_collision_count','_rejection_count','_submitted_result_by_id','_submission_fingerprint_by_id','_intake_settlement_result_by_id','_settlement_fingerprint_by_id','_damage_settlement_by_id'))
        if (@($finalPrivate._damage_settlement_by_id.PSObject.Properties).Count -eq 1) { break }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $resolutionDeadline)
    if (@($finalPrivate._damage_settlement_by_id.PSObject.Properties).Count -ne 1) { throw 'MILITARY_NATURAL_RESOLUTION_TIMEOUT' }
    [void](Capture-View -Name '03-assault-region-resolved-and-withdrawn')

    Wait-And-Finish-EmptyBatch -Batch 3
    Wait-And-Finish-EmptyBatch -Batch 4
    $majorRound = Wait-Runtime -Name 'major-round-barrier' -TimeoutSeconds 30 -Predicate {param($p) [int]$p._batch_number -eq 5 -and [string]$p._phase -eq 'submission'}
    [void](Capture-View -Name '04-complete-major-round-barrier')
    $finalPrivate = Get-Props (Query-Node -Name 'final-private-owner.jsonrpc.json' -Path $privateOwnerPath -Properties @('_collision_count','_rejection_count','_submitted_result_by_id','_submission_fingerprint_by_id','_intake_settlement_result_by_id','_settlement_fingerprint_by_id','_damage_settlement_by_id'))
    $finalEta = Get-Props (Query-Node -Name 'final-eta-owner.jsonrpc.json' -Path $etaOwnerPath -Properties @('_calculation_count','_rejection_count'))
    $finalKernel = Get-Props (Query-Node -Name 'final-kernel.jsonrpc.json' -Path $kernelPath -Properties @('_current_tick','_domain_states','_last_rejection','_rejection_count'))
    $finalComposition = Get-Props (Query-Node -Name 'final-application-flow.jsonrpc.json' -Path $compositionPath -Properties @('_v076_private_military_receipt_count','_v076_production_ready','_last_new_game_receipt','_v076_production_seed'))
    $finalRuntime = Get-Props (Query-Node -Name 'final-runtime-owner.jsonrpc.json' -Path $runtimePath -Properties @('_batch_number','_phase','_invalid_action_count','_invalid_action_reasons','_runtime_error_count','_v076_asset_consequence_projection_count','_v076_asset_consequence_projection_failure_count','_v076_last_asset_consequence_witness','_v076_military_consequence_collision_count','_v076_military_consequence_presentation_count','_v076_production_military_submission_by_uid','_v075_snapshot'))
    $finalLegacy = Get-Props (Query-Node -Name 'final-legacy-combat-writer.jsonrpc.json' -Path $legacyCombatPath -Properties @('_combat_receipt_journal','_military_region_assault_count','_military_withdraw_count','_processed_missions','_runtime_error_count'))
    $finalScreen = Get-Props (Query-Node -Name 'final-production-screen.jsonrpc.json' -Path $screenPath -Properties @('acceptance_state','_current_action_mode','_action_submission_pending'))
    $stepReceipts.Add([ordered]@{step='seed';visible_text=$seedVisible;config_model_seed=[int64]$composition._v076_production_seed;new_game_receipt_seed=[int64]$composition._last_new_game_receipt.seed;runtime_seed=[int64]$readyGame._seed})
    $stepReceipts.Add([ordered]@{step='military_immediate';private_owner=$immediatePrivate;eta_owner=$immediateEta})
    $stepReceipts.Add([ordered]@{step='military_final';private_owner=$finalPrivate;eta_owner=$finalEta;kernel=$finalKernel;application_flow=$finalComposition;runtime_owner=$finalRuntime;legacy_combat_owner=$finalLegacy;production_screen=$finalScreen})
} catch {
    $failure = $_
} finally {
    if ($formalConsumed -or @(Get-ExactGodotRows).Count -ne 0 -or (Test-Path -LiteralPath (Join-Path $root '.codex-godot\connection.json'))) {
        try {$cleanup = Stop-Normally} catch {if($null-eq$failure){$failure=$_}}
    }
}

$endedAt = [DateTime]::UtcNow
$status = if ($null -eq $failure -and $formalConsumed -and $null -ne $cleanup -and $cleanup.exit_play_mode -eq 'PASS' -and $cleanup.stop_role_godot_mcp -eq 'PASS' -and $cleanup.editor_pid_after -eq 0 -and $cleanup.game_pid_after -eq 0 -and $cleanup.listener_count_after -eq 0 -and $cleanup.stopped -and -not $cleanup.forced_stop) {'PASS'} elseif(-not$formalConsumed){'PRE_EXECUTION_BLOCKED'} else {'FAIL'}
$result = [ordered]@{
    schema_version='space_syndicate.v076.generation9_formal_execution_result.v1'
    status=$status
    authorization_id=$authorizationId
    generation_id=$generationId
    new_evidence_id=$evidenceId
    formal_execution_count=if($formalConsumed){1}else{0}
    automatic_retry_count=0
    execution_head_sha=if(Test-Path $preflightPath){[string](Get-Content $preflightPath -Raw|ConvertFrom-Json).head_sha}else{$null}
    execution_tree_sha=if(Test-Path $preflightPath){[string](Get-Content $preflightPath -Raw|ConvertFrom-Json).tree_sha}else{$null}
    subject_head_sha=$expectedProductHead
    subject_tree_sha=$expectedProductTree
    selected_seed=$Seed
    player_count=4
    production_scene_path='res://scenes/main.tscn'
    started_at_utc=$startedAt.ToString('o')
    ended_at_utc=$endedAt.ToString('o')
    godot_binary_sha256=if(Test-Path -LiteralPath $GodotPath){Get-Sha256 $GodotPath}else{$null}
    mcp_connection=$connection
    mcp_project_info=$projectInfo
    failure=if($null-eq$failure){$null}else{[string]$failure.Exception.Message}
    step_receipts=@($stepReceipts)
    process_cleanup=$cleanup
}
Write-Json -Path $resultPath -Value $result
$result | ConvertTo-Json -Depth 20 -Compress
if ($status -ne 'PASS') { exit 1 }
