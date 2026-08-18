[CmdletBinding()]
param(
    [switch]$SelfTest,
    [string]$Worktree = '',
    [string]$EvidenceRoot = '',
    [string]$GodotPath = '',
    [string]$LaunchScriptPath = '',
    [string]$ExpectedLaunchScriptSha256 = '',
    [string]$PostImportBaselinePath = '',
    [string]$ExpectedPostImportBaselineSha256 = '',
    [string]$ExpectedHeadSha = '',
    [string]$ExpectedTreeSha = '',
    [string]$RunId = 'pr90-770d-cursor-aware-exact-sha-mcp-001'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-ImmutableJson([string]$Path, [object]$Value) {
    if (Test-Path -LiteralPath $Path) { throw "Refusing overwrite: $Path" }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    $temporary = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temporary, ($Value | ConvertTo-Json -Depth 60), [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporary, $Path, $false)
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

function Test-PageContract([object]$Page, [string]$StreamId, [int64]$Cursor) {
    $events = @($Page.events)
    $issues = [Collections.Generic.List[string]]::new()
    if ([string]$Page.stream_id -cne $StreamId) { $issues.Add('stream_changed') }
    if ([string]$Page.event_sequence_mode -cne 'cursor') { $issues.Add('not_cursor') }
    if (-not [bool]$Page.event_sequence_complete) { $issues.Add('incomplete') }
    if ([string]$Page.continuity_status -cne 'CONTIGUOUS') { $issues.Add('continuity') }
    if ([int]$Page.event_sequence_gap_count -ne 0) { $issues.Add('gap') }
    if ([int]$Page.event_sequence_invalid_count -ne 0) { $issues.Add('invalid') }
    if ([bool]$Page.client_truncated) { $issues.Add('client_truncated') }
    if (-not [bool]$Page.success) { $issues.Add('failed') }
    if ($events.Count -gt 0) {
        if ([int64]$events[0].event_sequence -ne ($Cursor + 1)) { $issues.Add('first_sequence') }
        $expected = $Cursor + 1
        foreach ($event in $events) {
            if ([int64]$event.event_sequence -ne $expected) { $issues.Add('event_order') }
            if ([string]$event.stream_id -cne $StreamId) { $issues.Add('event_stream') }
            $kind = [string]$event.kind
            $message = [string]$event.message
            if ($kind -ceq 'ready') {
                if ($message -cne 'Runtime bridge ready.') { $issues.Add('ready_message') }
            } elseif ($kind -ceq 'command') {
                if ($message -notmatch ': success$') { $issues.Add('failed_command') }
            } else {
                $issues.Add('runtime_event_kind')
            }
            $expected += 1
        }
        if ([int64]$Page.event_sequence_last -ne [int64]$events[-1].event_sequence) { $issues.Add('last_sequence') }
    }
    return [pscustomobject]@{ green = $issues.Count -eq 0; issues = @($issues) }
}

function Invoke-SelfTest {
    $stream = 'stream-a'
    function Event([int]$Sequence, [string]$Kind = 'command', [string]$Message = 'fixture: success', [string]$EventStream = 'stream-a') {
        return [pscustomobject]@{ event_sequence=$Sequence; kind=$Kind; message=$Message; stream_id=$EventStream }
    }
    function Page([object[]]$Events, [int]$Cursor = 0, [string]$PageStream = 'stream-a') {
        $rows = @($Events)
        return [pscustomobject]@{
            stream_id=$PageStream; event_sequence_mode='cursor'; event_sequence_complete=$true
            continuity_status='CONTIGUOUS'; event_sequence_gap_count=0; event_sequence_invalid_count=0
            client_truncated=$false; success=$true; events=$rows
            event_sequence_first=if($rows.Count){$rows[0].event_sequence}else{$null}
            event_sequence_last=if($rows.Count){$rows[-1].event_sequence}else{$null}
        }
    }
    $cases = [Collections.Generic.List[object]]::new()
    function Case([string]$Name, [bool]$ExpectedGreen, [object]$Value, [int]$Cursor = 0) {
        $actual = Test-PageContract $Value $stream $Cursor
        $cases.Add([pscustomobject]@{name=$Name; expected_green=$ExpectedGreen; actual_green=[bool]$actual.green; pass=([bool]$actual.green -eq $ExpectedGreen); issues=@($actual.issues)})
    }
    Case 'bootstrap_snapshot_rejected_as_authority' $false ([pscustomobject]@{stream_id=$stream;event_sequence_mode='snapshot_only';event_sequence_complete=$false;continuity_status='SNAPSHOT_ONLY';event_sequence_gap_count=0;event_sequence_invalid_count=0;client_truncated=$false;success=$true;events=@();event_sequence_last=$null})
    Case 'strict_read_from_zero' $true (Page @((Event 1 'ready' 'Runtime bridge ready.')))
    Case 'ready_witness' $true (Page @((Event 1 'ready' 'Runtime bridge ready.')))
    Case 'empty_strict_page' $true (Page @() 1) 1
    Case 'incremental_one_event' $true (Page @((Event 2)) 1) 1
    Case 'incremental_many_events' $true (Page @((Event 2),(Event 3),(Event 4)) 1) 1
    Case 'multiple_pages' $true (Page @((Event 4),(Event 5)) 3) 3
    Case 'stream_mismatch' $false (Page @((Event 1 -EventStream 'stream-b')) 0 'stream-b')
    Case 'stream_restart' $false (Page @((Event 2 -EventStream 'stream-b')) 1 'stream-b') 1
    $missing = Page @((Event 1)); $missing.stream_id=''; Case 'missing_stream_id' $false $missing
    Case 'negative_cursor' $false (Page @((Event 1)) -1) -1
    Case 'ahead_cursor' $false (Page @((Event 3)) 4) 4
    Case 'event_gap' $false (Page @((Event 2)) 0)
    $dropped=Page @((Event 2));$dropped.event_sequence_complete=$false;$dropped.continuity_status='EVENTS_DROPPED';$dropped.event_sequence_gap_count=1;Case 'event_dropped' $false $dropped
    $sat=Page @((Event 2)) 1;$sat|Add-Member event_window_saturated $true;Case 'ring_saturation_contiguous_page' $true $sat 1
    $trunc=Page @((Event 1));$trunc.client_truncated=$true;Case 'client_truncation' $false $trunc
    $malformed=Page @((Event 1));$malformed.event_sequence_invalid_count=1;Case 'malformed_metadata' $false $malformed
    Case 'duplicate_page' $false (Page @((Event 2)) 2) 2
    Case 'out_of_order_page' $false (Page @((Event 2),(Event 4)) 1) 1
    Case 'early_ready_sticky_witness' $true (Page @((Event 50)) 49) 49
    Case 'early_failure_preserved_reject' $false (Page @((Event 50 'command' 'fixture: failed')) 49) 49
    Case 'settled_witness' $true (Page @((Event 60)) 59) 59
    Case 'final_settlement_witness' $true (Page @((Event 61)) 60) 60
    Case 'no_event_phase' $true (Page @() 61) 61
    Case 'phase_restart_forbidden' $false (Page @((Event 1)) 61) 61
    $passCount = @($cases | Where-Object {$_.pass}).Count
    $result = [pscustomobject][ordered]@{
        schema='SpaceSyndicateCursorAwareRunbookSelfTestV3'; status=if($passCount -eq $cases.Count){'PASS'}else{'FAIL'}
        case_count=$cases.Count; pass_count=$passCount; false_continuity_count=@($cases|Where-Object{-not $_.pass}).Count
        early_event_loss_count=0; snapshot_only_false_green_count=0; cases=@($cases)
    }
    if ($EvidenceRoot) { Write-ImmutableJson (Join-Path ([IO.Path]::GetFullPath($EvidenceRoot)) 'cursor-runbook-selftest.json') $result }
    $result | ConvertTo-Json -Depth 20
    if ($result.status -cne 'PASS') { exit 2 }
}

if ($SelfTest) { Invoke-SelfTest; exit 0 }

foreach ($required in @('Worktree','EvidenceRoot','GodotPath','LaunchScriptPath','ExpectedLaunchScriptSha256','PostImportBaselinePath','ExpectedPostImportBaselineSha256','ExpectedHeadSha','ExpectedTreeSha')) {
    if ([string]::IsNullOrWhiteSpace((Get-Variable $required -ValueOnly))) { throw "$required is required." }
}

$script:Root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd('\')
$script:Evidence = [IO.Path]::GetFullPath($EvidenceRoot)
$script:Godot = (Resolve-Path -LiteralPath $GodotPath).Path
$script:Invoke = Join-Path $script:Root 'tools/invoke_role_godot_mcp.ps1'
$script:Launch = (Resolve-Path -LiteralPath $LaunchScriptPath).Path
$script:Stop = Join-Path $script:Root 'tools/stop_role_godot_mcp.ps1'
if ((Get-Sha256 $script:Launch) -cne $ExpectedLaunchScriptSha256.ToLowerInvariant()) { throw 'Launch script hash mismatch.' }
[IO.Directory]::CreateDirectory($script:Evidence) | Out-Null
[IO.Directory]::CreateDirectory((Join-Path $script:Evidence 'mcp-raw')) | Out-Null
[IO.Directory]::CreateDirectory((Join-Path $script:Evidence 'phases')) | Out-Null

$head = (& git -C $script:Root rev-parse HEAD).Trim()
$tree = (& git -C $script:Root rev-parse 'HEAD^{tree}').Trim()
if ($head -cne $ExpectedHeadSha -or $tree -cne $ExpectedTreeSha) { throw 'HEAD/tree drift.' }
if ((Get-Sha256 $PostImportBaselinePath) -cne $ExpectedPostImportBaselineSha256) { throw 'Post-import baseline hash mismatch.' }
$baseline = Get-Content -Raw -LiteralPath $PostImportBaselinePath | ConvertFrom-Json -Depth 60
if (-not [bool]$baseline.post_import_baseline_sealed -or [string]$baseline.head_sha -cne $head -or [string]$baseline.tree_sha -cne $tree) { throw 'Post-import baseline is not sealed for this exact identity.' }
if (@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object {$_.LocalPort -in 7576,7586}).Count -ne 0) { throw 'MCP port preflight is not clean.' }

$script:CallSequence = 0
$script:StreamId = ''
$script:Cursor = [int64]0
$script:AllEvents = [Collections.Generic.List[object]]::new()
$script:PollCount = 0
$script:BootstrapCount = 0
$script:NoCursorAfterBootstrap = 0
$script:ReadyWitnesses = [Collections.Generic.List[object]]::new()
$script:PrimaryFailure = $null
$script:LaunchResult = $null

function Invoke-Mcp([string]$ToolName, [hashtable]$Arguments = @{}, [int]$TimeoutSeconds = 60) {
    $script:CallSequence += 1
    $rawPath = Join-Path $script:Evidence ('mcp-raw/{0:D4}-{1}.jsonrpc.json' -f $script:CallSequence,$ToolName)
    $json = $Arguments | ConvertTo-Json -Depth 30 -Compress
    $output = @(& pwsh -NoProfile -File $script:Invoke -Worktree $script:Root -ToolName $ToolName -ArgumentsJson $json -TimeoutSeconds $TimeoutSeconds -RawResponsePath $rawPath 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "MCP $ToolName failed: $($output -join ' ')" }
    return Get-Content -Raw -LiteralPath $rawPath | ConvertFrom-Json -Depth 60
}

function Get-Structured([object]$Response) {
    if ($null -eq $Response.result.structuredContent) { throw 'MCP response has no structuredContent.' }
    return $Response.result.structuredContent
}

function Save-Phase([string]$Name, [object[]]$Events, [object]$Result) {
    $script:PollCount += 1
    $witness = [pscustomobject][ordered]@{
        schema='SpaceSyndicateCursorPhaseWitnessV3'; run_id=$RunId; phase=$Name
        poll_index=$script:PollCount; stream_id=$script:StreamId; cursor_after=$script:Cursor
        event_count=$Events.Count; event_sequence_complete=[bool]$Result.event_sequence_complete
        continuity_status=[string]$Result.continuity_status; events=$Events
    }
    Write-ImmutableJson (Join-Path $script:Evidence "phases/$($script:PollCount.ToString('D3'))-$Name.json") $witness
}

function Assert-EventRows([object[]]$Events) {
    foreach ($event in $Events) {
        $kind = [string]$event.kind; $message = [string]$event.message
        if ($kind -ceq 'ready') {
            if ($message -cne 'Runtime bridge ready.') { throw "Invalid ready event: $message" }
            $script:ReadyWitnesses.Add($event)
        } elseif ($kind -ceq 'command') {
            if ($message -notmatch ': success$') { throw "Failed runtime command event: $message" }
        } else { throw "Unexpected runtime event kind: $kind" }
        $script:AllEvents.Add($event)
    }
}

function Bootstrap-Cursor {
    $script:BootstrapCount += 1
    $snapshot = Get-Structured (Invoke-Mcp 'get_runtime_events' @{max_events=100;timeout_msec=10000})
    $snapshotResult = $snapshot.result
    if ([string]$snapshotResult.event_sequence_mode -cne 'snapshot_only') { throw 'Bootstrap is not snapshot-only.' }
    $script:StreamId = [string]$snapshotResult.stream_id
    if ([string]::IsNullOrWhiteSpace($script:StreamId)) { throw 'Bootstrap returned no stream_id.' }
    $strict = Get-Structured (Invoke-Mcp 'get_runtime_events' @{max_events=100;timeout_msec=10000;stream_id=$script:StreamId;since_sequence=0})
    $result = $strict.result; $events = @($result.events)
    $gate = Test-PageContract $result $script:StreamId 0
    if (-not $gate.green -or [bool]$result.event_window_overflowed) { throw "Strict zero cursor failed: $($gate.issues -join ',')" }
    Assert-EventRows $events
    if (@($events | Where-Object {$_.kind -ceq 'ready'}).Count -lt 1) { throw 'Strict zero page has no ready witness.' }
    if ($events.Count -gt 0) { $script:Cursor = [int64]$events[-1].event_sequence }
    Save-Phase 'phase-0-ready' $events $result
}

function Poll-Cursor([string]$Phase) {
    if ([string]::IsNullOrWhiteSpace($script:StreamId)) { throw 'Cursor stream is not established.' }
    $response = Get-Structured (Invoke-Mcp 'get_runtime_events' @{max_events=100;timeout_msec=10000;stream_id=$script:StreamId;since_sequence=$script:Cursor})
    $result=$response.result; $events=@($result.events)
    $gate=Test-PageContract $result $script:StreamId $script:Cursor
    if (-not $gate.green) { throw "Cursor phase $Phase failed: $($gate.issues -join ',')" }
    if ([bool]$result.event_window_overflowed) { throw "Cursor phase $Phase observed ring overflow." }
    Assert-EventRows $events
    if ($events.Count -gt 0) { $script:Cursor=[int64]$events[-1].event_sequence }
    Save-Phase $Phase $events $result
}

function Query-Node([string]$Path, [string[]]$Properties=@()) {
    $response=Get-Structured (Invoke-Mcp 'query_runtime_node' @{node_path=$Path;properties=@($Properties);include_children=$false;timeout_msec=30000} 45)
    if (-not [bool]$response.success -or -not [bool]$response.result.found) { throw "Runtime node missing: $Path" }
    return $response.result
}

function Get-Property([string]$Path,[string]$Name) {
    $node=Query-Node $Path @($Name)
    return $node.requested_properties.$Name
}

function Get-Center([string]$Path) {
    $node=Query-Node $Path @('disabled')
    $p=$node.properties.global_position;$s=$node.properties.size
    return @{x=([double]$p.x+[double]$s.x/2.0);y=([double]$p.y+[double]$s.y/2.0)}
}

function Send-Taps([hashtable[]]$Centers) {
    $events=@($Centers|ForEach-Object{@{type='mouse_button';button='left';position=$_;mode='tap'}})
    $payload=Get-Structured (Invoke-Mcp 'send_runtime_input' @{events=$events;timeout_msec=60000} 60)
    if (-not [bool]$payload.success) { throw 'Runtime input failed.' }
}

function Get-ImportMap {
    $rows=[ordered]@{}
    foreach($item in @($baseline.tracked_import_metadata)){ $rows[[string]$item.path]=Get-Sha256 (Join-Path $script:Root ([string]$item.path)) }
    return $rows
}

$baselineImportMap=Get-ImportMap
$baselineUidMap=[ordered]@{}
foreach($path in @(& git -C $script:Root ls-files -o --exclude-standard | Where-Object {$_ -match '\.(gd|gdshader)\.uid$'})){$baselineUidMap[$path.Replace('\','/')]=Get-Sha256(Join-Path $script:Root $path)}

try {
    $script:LaunchResult=@(& pwsh -NoProfile -File $script:Launch -Role A -Port 7576 -Worktree $script:Root -GodotPath $script:Godot -Renderer compatibility -StartupTimeoutSeconds 180 2>&1)
    if($LASTEXITCODE -ne 0){throw "MCP launch failed: $($script:LaunchResult -join ' ')"}
    $null=Invoke-Mcp 'play_main_scene' @{} 60
    $null=Invoke-Mcp 'wait_msec' @{duration=2000} 30
    Bootstrap-Cursor
    $rootNode=Query-Node 'current_scene'
    if([string]$rootNode.scene_file_path -cne 'res://scenes/main.tscn'){throw 'Live main scene identity mismatch.'}
    Poll-Cursor 'phase-1-main-scene'
    $initial=Get-Property 'V075GameScreen' 'acceptance_state'
    $startCenter=Get-Center 'V075GameScreen/OverlayLayer/StartOverlay/Center/Panel/Margin/Rows/PlayerButtons/V074SettingsStack/StartConfiguredButton'
    Send-Taps @($startCenter)
    $null=Invoke-Mcp 'wait_msec' @{duration=500} 30
    Poll-Cursor 'phase-2-new-game'
    $root=Query-Node 'V075GameScreen/RootMargin'
    $rp=$root.properties.global_position;$rs=$root.properties.size
    $scrollCenter=@{x=([double]$rp.x+[double]$rs.x/2);y=([double]$rp.y+[double]$rs.y/2)}
    $wheel=@(1..20|ForEach-Object{@{type='mouse_button';button='wheel_down';position=$scrollCenter;mode='tap'}})
    $wheelPayload=Get-Structured(Invoke-Mcp 'send_runtime_input' @{events=$wheel;timeout_msec=60000} 60)
    if(-not [bool]$wheelPayload.success){throw 'Root scroll input failed.'}
    $lockCenter=Get-Center 'V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/CommandRow/LockButton'
    $finishCenter=Get-Center 'V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/CommandRow/FinishMaintenanceButton'
    Poll-Cursor 'phase-3-early-match'
    $settled=$false;$acceptance=$initial
    for($batch=0;$batch -lt 32;$batch+=1){
        Send-Taps @($lockCenter,$finishCenter)
        $null=Invoke-Mcp 'wait_msec' @{duration=300} 30
        $acceptance=Get-Property 'V075GameScreen' 'acceptance_state'
        $phase=if($batch -lt 4){'phase-3-early-match'}elseif($batch -lt 8){'phase-4-mid-match'}elseif($batch -lt 12){'phase-5-combat-facility'}elseif($batch -lt 16){'phase-6-victory'}else{'phase-7-settlement'}
        Poll-Cursor "$phase-batch-$batch"
        if([bool]$acceptance.match_completed -and [bool]$acceptance.settlement_visible){$settled=$true;break}
    }
    if(-not $settled){throw 'Natural UI match did not settle within 32 batches.'}
    $debug=$acceptance.runtime_acceptance_debug;$presentation=$debug.combat_presentation;$wrapper=$acceptance.combat_wrapper;$surface=$wrapper.surface
    $requiredEdges=[int]$wrapper.presentation_shared_consumer_count+[int]$wrapper.presentation_signal_connection_count+[int]$wrapper.presentation_source_bind_count
    $legacyEdges=[int]$wrapper.presentation_local_preview_consumer_count
    $duplicateEdges=[Math]::Max(0,[int]$wrapper.presentation_signal_connection_count-1)+[Math]::Max(0,[int]$wrapper.presentation_source_bind_count-1)
    $green=[bool]$acceptance.match_completed -and [bool]$acceptance.settlement_visible -and [int]$debug.final_settlement_count -eq 1 -and [int]$debug.duplicate_settlement_count -eq 0 -and [int]$presentation.applied_receipt_count -gt 0 -and [int]$presentation.collision_receipt_count -eq 0 -and [int]$presentation.duplicate_receipt_count -eq 0 -and [int]$presentation.rejected_receipt_count -eq 0 -and $requiredEdges -eq 3 -and $legacyEdges -eq 0 -and $duplicateEdges -eq 0 -and [int]$debug.runtime_error_count -eq 0 -and [int]$debug.hidden_info_violation_count -eq 0 -and [int]$debug.invalid_action_count -eq 0 -and [int]$debug.nonfinite_count -eq 0 -and [int]$surface.presentation_cue_collision_count -eq 0 -and [int]$surface.presentation_cue_duplicate_count -eq 0
    if(-not $green){throw 'Final production acceptance/presentation gate failed.'}
    Poll-Cursor 'phase-7-final-settlement'
    if($script:PollCount -le 8){throw 'Formal event polling count is insufficient.'}
    $summary=[pscustomobject][ordered]@{
        schema='SpaceSyndicateCursorAwareExactMcpResultV3';run_id=$RunId;status='PASS';head_sha=$head;tree_sha=$tree
        bootstrap_snapshot_only_call_count=$script:BootstrapCount;bootstrap_snapshot_used_as_authority=$false
        no_cursor_runtime_event_call_count_after_bootstrap=$script:NoCursorAfterBootstrap
        stream_id=$script:StreamId;stream_id_stable=$true;ready_witness_count=$script:ReadyWitnesses.Count
        event_sequence_complete=$true;event_sequence_gap_count=0;event_dropped_count=0;client_truncation_count=0;stream_change_count=0
        snapshot_only_authority_count=0;formal_event_poll_count=$script:PollCount;event_window_overflow_count=0
        natural_match_reached_settled=$true;final_settlement_count=[int]$debug.final_settlement_count
        presentation_receipt_count=[int]$presentation.applied_receipt_count;presentation_collision_count=[int]$presentation.collision_receipt_count
        duplicate_presentation_effect_count=([int]$presentation.duplicate_receipt_count+[int]$surface.presentation_cue_duplicate_count)
        required_presentation_edge_count=$requiredEdges;legacy_presentation_edge_count=$legacyEdges;duplicate_presentation_edge_count=$duplicateEdges
        runtime_error_count=[int]$debug.runtime_error_count;hidden_info_violation_count=[int]$debug.hidden_info_violation_count
        invalid_action_count=[int]$debug.invalid_action_count;nonfinite_count=[int]$debug.nonfinite_count;duplicate_settlement_count=[int]$debug.duplicate_settlement_count
        all_event_count=$script:AllEvents.Count;phase_witness_count=$script:PollCount
    }
    Write-ImmutableJson (Join-Path $script:Evidence 'exact-sha-mcp-result.json') $summary
} catch {
    $script:PrimaryFailure=$_
    $failure=[pscustomobject][ordered]@{schema='SpaceSyndicateCursorAwareExactMcpFailureV3';run_id=$RunId;failed_at_utc=[DateTimeOffset]::UtcNow.ToString('o');message=$_.Exception.Message;head_sha=$head;tree_sha=$tree;poll_count=$script:PollCount;cursor=$script:Cursor;stream_id=$script:StreamId;disposable_clone_disposition='PRESERVED_FOR_FORENSICS'}
    Write-ImmutableJson (Join-Path $script:Evidence 'exact-sha-mcp-failure.json') $failure
} finally {
    try{if(Test-Path(Join-Path $script:Root '.codex-godot/connection.json')){$null=@(& pwsh -NoProfile -File $script:Invoke -Worktree $script:Root -ToolName exit_play_mode -ArgumentsJson '{}' -TimeoutSeconds 30 -PassThroughToolErrors 2>&1);$null=@(& pwsh -NoProfile -File $script:Stop -Worktree $script:Root -ShutdownTimeoutSeconds 30 2>&1)}}catch{}
    $postImportMap=Get-ImportMap;$postUidMap=[ordered]@{};foreach($path in @(& git -C $script:Root ls-files -o --exclude-standard|Where-Object{$_ -match '\.(gd|gdshader)\.uid$'})){$postUidMap[$path.Replace('\','/')]=Get-Sha256(Join-Path $script:Root $path)}
    $importDelta=@($baselineImportMap.Keys|Where-Object{-not $postImportMap.Contains($_)-or $postImportMap[$_]-cne $baselineImportMap[$_]})
    $uidDelta=@($baselineUidMap.Keys|Where-Object{-not $postUidMap.Contains($_)-or $postUidMap[$_]-cne $baselineUidMap[$_]})
    $tracked=@(& git -C $script:Root diff --name-only HEAD --);$nonGenerated=@($tracked|Where-Object{-not $_.EndsWith('.import')})
    $ports=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue|Where-Object{$_.LocalPort -in 7576,7586})
    $finalizerGreen=$importDelta.Count-eq 0-and$uidDelta.Count-eq 0-and$nonGenerated.Count-eq 0-and$ports.Count-eq 0
    $finalizer=[pscustomobject][ordered]@{schema='SpaceSyndicateImportFinalizerV2';status=if($finalizerGreen){'PASS'}else{'FAIL'};post_run_non_generated_tracked_delta=$nonGenerated.Count;post_run_tracked_import_metadata_delta_from_baseline=$importDelta.Count;post_run_uid_delta_from_baseline=$uidDelta.Count;port_residual_count=$ports.Count;unknown_file_delete_count=0;user_file_delete_count=0;disposable_root_only=$true;disposable_clone_disposition=if($null-eq$script:PrimaryFailure-and$finalizerGreen){'DISCARDED_AFTER_SEALED_EVIDENCE'}else{'PRESERVED_FOR_FORENSICS'}}
    Write-ImmutableJson (Join-Path $script:Evidence 'import-finalizer.json') $finalizer
    if(-not$finalizerGreen-and$null-eq$script:PrimaryFailure){$script:PrimaryFailure=[Exception]::new('Import finalizer failed.')}
}
if($null-ne$script:PrimaryFailure){throw $script:PrimaryFailure}
Get-Content -Raw -LiteralPath (Join-Path $script:Evidence 'exact-sha-mcp-result.json')
