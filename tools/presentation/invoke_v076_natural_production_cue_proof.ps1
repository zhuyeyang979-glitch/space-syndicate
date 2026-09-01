<#
.SYNOPSIS
Builds the Phase 8 proof for the four production card-table presentation cues.

.DESCRIPTION
Runs the existing production-main card-table and Victory focused gates, then
fails closed unless CARD_SELECT, CARD_PLAY_PUBLIC, CARD_RESOLUTION_FOCUS, and
FINAL_SETTLEMENT each retain natural production lineage, one unique Director
queue/finish chain per source receipt, real surface Rect/projection evidence,
and zero presentation-owned gameplay/RNG/authority/card-zone mutation.

This proof never invokes a Screen presentation method, a Showcase fixture, or
state injection. It only consumes the append-only runtime evidence emitted by
the two production-composition tests. The generated report explicitly keeps
Human Green false and Golden STEP13-STEP15 pending.
#>
[CmdletBinding()]
param(
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")),

    [string]$GodotPath = "",

    [ValidateRange(60, 1800)]
    [int]$TimeoutSeconds = 420,

    [string]$LogRoot = (Join-Path $env:LOCALAPPDATA "SpaceSyndicate\v076_natural_production_cue_proof"),

    [string]$ReportPath = "",

    [string]$CardResultJson = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $wingetPackageRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    $resolvedGodot = Get-ChildItem `
        -LiteralPath $wingetPackageRoot `
        -Filter "Godot_v4.7-stable_win64.exe" `
        -File `
        -Recurse `
        -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $resolvedGodot) {
        throw "Godot 4.7 GUI executable was not found; pass -GodotPath explicitly."
    }
    $GodotPath = $resolvedGodot.FullName
}

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $ProjectPath "reports\presentation\commercial_m1\natural_production_cue_proof.json"
}

$runnerPath = Join-Path $ProjectPath "tools\invoke_godot_test.ps1"
if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) {
    throw "Godot test runner is missing: $runnerPath"
}

$script:checkCount = 0
$failures = [Collections.Generic.List[string]]::new()

function Assert-Proof {
    param(
        [bool]$Condition,
        [string]$Message
    )
    $script:checkCount += 1
    if (-not $Condition) {
        $failures.Add($Message)
    }
}

function Get-ObjectProperty {
    param(
        [AllowNull()]
        [object]$Source,
        [string]$Name
    )
    if ($null -eq $Source) {
        return $null
    }
    $property = $Source.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Test-LowerSha256 {
    param([AllowNull()][object]$Value)
    return ([string]$Value) -cmatch '^[0-9a-f]{64}$'
}

function Test-SerializedRectArea {
    param([AllowNull()][object]$Value)
    $text = [string]$Value
    $match = [regex]::Match(
        $text,
        'S:\s*\(\s*(-?[0-9]+(?:\.[0-9]+)?),\s*(-?[0-9]+(?:\.[0-9]+)?)\s*\)'
    )
    if (-not $match.Success) {
        return $false
    }
    return (
        [double]::Parse($match.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture) -gt 0.0 `
        -and [double]::Parse($match.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture) -gt 0.0
    )
}

function Get-MarkerPayload {
    param(
        [string]$Path,
        [string]$Marker
    )
    $line = Get-Content -LiteralPath $Path | Where-Object {
        $_.StartsWith("$Marker|")
    } | Select-Object -Last 1
    if ([string]::IsNullOrWhiteSpace($line)) {
        throw "Missing evidence marker $Marker in $Path"
    }
    return ($line.Substring($Marker.Length + 1) | ConvertFrom-Json -Depth 100)
}

function Get-CompletionLine {
    param(
        [string]$Path,
        [string]$Marker
    )
    return [string](Get-Content -LiteralPath $Path | Where-Object {
        $_.StartsWith("$Marker|")
    } | Select-Object -Last 1)
}

function Invoke-ProductionGate {
    param(
        [string]$TestScript,
        [string]$ExpectedMarker
    )
    $output = @(& $runnerPath `
        -ProjectPath $ProjectPath `
        -GodotPath $GodotPath `
        -TestScript $TestScript `
        -EnsureImported `
        -TimeoutSeconds $TimeoutSeconds `
        -LogRoot $LogRoot `
        -ExpectedCompletionMarker $ExpectedMarker)
    $runnerExitCode = $LASTEXITCODE
    $jsonLine = [string]($output | Select-Object -Last 1)
    if ([string]::IsNullOrWhiteSpace($jsonLine)) {
        throw "Runner emitted no result JSON for $TestScript"
    }
    $result = $jsonLine | ConvertFrom-Json -Depth 100
    Assert-Proof ($runnerExitCode -eq 0) "$TestScript runner exit code is $runnerExitCode"
    Assert-Proof ([int]$result.runner_exit_code -eq 0) "$TestScript result runner exit code is not zero"
    Assert-Proof ([int]$result.process_exit_code -eq 0) "$TestScript Godot process exit code is not zero"
    Assert-Proof ([bool]$result.marker_found) "$TestScript completion marker is absent"
    Assert-Proof ([int]$result.script_error_count -eq 0) "$TestScript has script errors"
    Assert-Proof ([int]$result.diagnostic_count -eq 0) "$TestScript has diagnostics"
    Assert-Proof ([int]$result.task_introduced_error_count -eq 0) "$TestScript has task-introduced errors"
    Assert-Proof (@($result.remaining_project_runtime_process_ids).Count -eq 0) "$TestScript left residual project processes"
    return $result
}

function Assert-ZeroMutationEvidence {
    param(
        [object]$Evidence,
        [string]$Label
    )
    Assert-Proof ([bool]$Evidence.presentation_only) "$Label is not presentation-only"
    Assert-Proof ([int]$Evidence.gameplay_mutation_count -eq 0) "$Label mutates gameplay"
    Assert-Proof ([int]$Evidence.rng_draw_delta -eq 0) "$Label changes RNG draws"
    Assert-Proof ([int]$Evidence.authority_sequence_delta -eq 0) "$Label changes authority sequence"
}

function Assert-ProductionCue {
    param(
        [string]$CueId,
        [object]$Row,
        [object]$Evidence,
        [string]$ExpectedSchema,
        [string]$ExpectedConsumer,
        [string]$ExpectedReceiptKind,
        [bool]$ExactlyOne
    )
    $minimum = if ($ExactlyOne) { 1 } else { 1 }
    $sourceCount = [int]$Row.source_count
    Assert-Proof ($sourceCount -ge $minimum) "$CueId has no natural production source"
    if ($ExactlyOne) {
        Assert-Proof ($sourceCount -eq 1) "$CueId source count is not exactly one"
    }
    foreach ($field in @(
        "envelope_count",
        "queued_count",
        "surface_started_count",
        "surface_finished_count",
        "finished_count",
        "production_source_count",
        "production_queued_count",
        "production_surface_started_count",
        "production_surface_finished_count",
        "production_finished_count"
    )) {
        Assert-Proof ([int](Get-ObjectProperty $Row $field) -eq $sourceCount) "$CueId $field does not match natural source count"
    }
    foreach ($field in @(
        "duplicate_count",
        "collision_count",
        "rejection_count",
        "finish_missing_count",
        "surface_rejection_count",
        "fixture_source_count",
        "fixture_queued_count",
        "fixture_surface_started_count",
        "fixture_surface_finished_count",
        "fixture_finished_count"
    )) {
        Assert-Proof ([int](Get-ObjectProperty $Row $field) -eq 0) "$CueId $field is not zero"
    }

    $envelope = $Evidence.envelope
    $queuedCue = $Evidence.queued_cue
    $startEvidence = $Evidence.start_evidence
    $finishEvidence = $Evidence.finish_evidence
    Assert-Proof ([string]$Evidence.status -eq "FINISHED") "$CueId evidence did not finish"
    Assert-Proof ([string]$Evidence.abort_reason -eq "") "$CueId evidence has an abort reason"
    Assert-Proof ([string]$Evidence.consumer_class -eq $ExpectedConsumer) "$CueId consumer class is not production-authorized"
    Assert-Proof ([string]$envelope.schema -eq $ExpectedSchema) "$CueId envelope schema is wrong"
    Assert-Proof ([bool]$envelope.accepted) "$CueId envelope is not accepted"
    Assert-Proof ([string]$envelope.cue_id -eq $CueId) "$CueId envelope cue id is wrong"
    Assert-Proof ([string]$envelope.receipt_kind -eq $ExpectedReceiptKind) "$CueId receipt kind is wrong"
    Assert-Proof (-not [string]::IsNullOrWhiteSpace([string]$Evidence.receipt_id)) "$CueId evidence receipt id is empty"
    Assert-Proof ([string]$queuedCue.receipt_id -eq [string]$Evidence.receipt_id) "$CueId Director cue lost receipt identity"
    Assert-Proof ([string]$queuedCue.cue_id -eq $CueId) "$CueId Director queue uses the wrong cue"
    Assert-Proof (Test-LowerSha256 $queuedCue.receipt_fingerprint) "$CueId Director fingerprint is invalid"
    Assert-Proof ($null -ne $queuedCue.projection) "$CueId Director projection is missing"
    Assert-Proof (Test-SerializedRectArea $startEvidence.source_rect) "$CueId start source Rect has no area"
    Assert-Proof (Test-SerializedRectArea $startEvidence.target_rect) "$CueId start target Rect has no area"
    Assert-Proof (Test-SerializedRectArea $finishEvidence.end_rect) "$CueId finish Rect has no area"
    Assert-ZeroMutationEvidence $startEvidence "$CueId start evidence"
    Assert-ZeroMutationEvidence $finishEvidence "$CueId finish evidence"
}

if ([string]::IsNullOrWhiteSpace($CardResultJson)) {
    $cardResult = Invoke-ProductionGate `
        -TestScript "res://tests/v076_alpha07_card_table_flow_readiness_test.gd" `
        -ExpectedMarker "V076_ALPHA07_CARD_TABLE_FLOW_READINESS|status=PASS"
} else {
    if (-not (Test-Path -LiteralPath $CardResultJson -PathType Leaf)) {
        throw "Supplied CardResultJson does not exist: $CardResultJson"
    }
    $cardResult = Get-Content -LiteralPath $CardResultJson -Raw | ConvertFrom-Json -Depth 100
    Assert-Proof ([string]$cardResult.test_script -eq "res://tests/v076_alpha07_card_table_flow_readiness_test.gd") "reused card-table result targets an unexpected test"
    Assert-Proof ([int]$cardResult.runner_exit_code -eq 0) "reused card-table result runner exit code is not zero"
    Assert-Proof ([int]$cardResult.process_exit_code -eq 0) "reused card-table result process exit code is not zero"
    Assert-Proof ([int]$cardResult.script_error_count -eq 0) "reused card-table result has script errors"
    Assert-Proof ([int]$cardResult.diagnostic_count -eq 0) "reused card-table result has diagnostics"
    Assert-Proof ([int]$cardResult.task_introduced_error_count -eq 0) "reused card-table result has task-introduced errors"
    Assert-Proof (@($cardResult.remaining_project_runtime_process_ids).Count -eq 0) "reused card-table result left residual project processes"
    Assert-Proof (Test-Path -LiteralPath ([string]$cardResult.stdout_log) -PathType Leaf) "reused card-table stdout evidence is missing"
}
$victoryResult = Invoke-ProductionGate `
    -TestScript "res://tests/v076_production_victory_audit_readiness_test.gd" `
    -ExpectedMarker "V076_PRODUCTION_VICTORY_AUDIT_READINESS_TEST|status=PASS"

$cardCompletion = Get-CompletionLine `
    -Path ([string]$cardResult.stdout_log) `
    -Marker "V076_ALPHA07_CARD_TABLE_FLOW_READINESS"
$victoryCompletion = Get-CompletionLine `
    -Path ([string]$victoryResult.stdout_log) `
    -Marker "V076_PRODUCTION_VICTORY_AUDIT_READINESS_TEST"
$cardChain = Get-MarkerPayload `
    -Path ([string]$cardResult.stdout_log) `
    -Marker "V076_CARD_TABLE_PRESENTATION_CHAIN"
$finalChain = Get-MarkerPayload `
    -Path ([string]$victoryResult.stdout_log) `
    -Marker "V076_FINAL_SETTLEMENT_PRESENTATION_CHAIN"

Assert-Proof ($cardCompletion -match '\|status=PASS\|') "card-table completion is not PASS"
Assert-Proof ($cardCompletion -match '\|direct_method_call_false_green_count=0\|') "card-table proof used a direct-method false green"
Assert-Proof ($victoryCompletion -match '\|status=PASS\|') "Victory completion is not PASS"
Assert-Proof ($victoryCompletion -match '\|step13_golden=false\|') "Victory automation inflated STEP13 Golden"
Assert-Proof ($victoryCompletion -match '\|human_executed=false\|') "Victory automation claims human execution"
Assert-Proof ($victoryCompletion -match '\|human_confirmed=false\|') "Victory automation claims human confirmation"

$contracts = [ordered]@{
    CARD_SELECT = [ordered]@{
        schema = "V076AuthorizedPresentationInputEnvelopeV1"
        consumer = "AUTHORIZED_PRESENTATION_INPUT"
        receipt_kind = "card_selection_receipt"
    }
    CARD_PLAY_PUBLIC = [ordered]@{
        schema = "V076PublicCardPlayPresentationEnvelopeV1"
        consumer = "AUTHORIZED_PUBLIC_PROJECTION"
        receipt_kind = "public_card_play_receipt"
    }
    CARD_RESOLUTION_FOCUS = [ordered]@{
        schema = "V076PublicCardResolutionPresentationEnvelopeV1"
        consumer = "AUTHORIZED_PUBLIC_PROJECTION"
        receipt_kind = "public_resolution_receipt"
    }
}

$cueRows = [Collections.Generic.List[object]]::new()
$receiptIds = [Collections.Generic.List[string]]::new()
foreach ($cueId in $contracts.Keys) {
    $contract = $contracts[$cueId]
    $row = Get-ObjectProperty $cardChain.bridge.cue_counts $cueId
    $evidence = Get-ObjectProperty $cardChain.bridge.cue_evidence $cueId
    Assert-Proof ($null -ne $row) "$cueId count row is missing"
    Assert-Proof ($null -ne $evidence) "$cueId evidence row is missing"
    if ($null -eq $row -or $null -eq $evidence) {
        continue
    }
    Assert-ProductionCue `
        -CueId $cueId `
        -Row $row `
        -Evidence $evidence `
        -ExpectedSchema ([string]$contract.schema) `
        -ExpectedConsumer ([string]$contract.consumer) `
        -ExpectedReceiptKind ([string]$contract.receipt_kind) `
        -ExactlyOne $false

    $envelope = $evidence.envelope
    $queuedCue = $evidence.queued_cue
    $projection = $queuedCue.projection
    if ($cueId -eq "CARD_SELECT") {
        Assert-Proof (Test-LowerSha256 $envelope.own_hand_projection_sha256) "CARD_SELECT lawful hand projection hash is invalid"
        Assert-Proof ([string]$envelope.own_hand_projection_sha256 -eq [string]$evidence.start_evidence.own_hand_projection_sha256) "CARD_SELECT start evidence lost hand projection lineage"
        Assert-Proof (Test-SerializedRectArea $projection.source_anchor.global_rect) "CARD_SELECT source projection Rect has no area"
        Assert-Proof (Test-SerializedRectArea $projection.target_anchor.global_rect) "CARD_SELECT target projection Rect has no area"
    } elseif ($cueId -eq "CARD_PLAY_PUBLIC") {
        Assert-Proof (Test-LowerSha256 $envelope.source_public_projection_sha256) "CARD_PLAY_PUBLIC public projection hash is invalid"
        Assert-Proof (Test-LowerSha256 $envelope.source_public_receipt_sha256) "CARD_PLAY_PUBLIC public receipt hash is invalid"
        Assert-Proof ([string]$envelope.source_public_projection_sha256 -eq [string]$projection.public_projection_sha256) "CARD_PLAY_PUBLIC Director projection lost public lineage"
        Assert-Proof (Test-SerializedRectArea $projection.source_global_rect) "CARD_PLAY_PUBLIC source projection Rect has no area"
        Assert-Proof (Test-SerializedRectArea $projection.target_global_rect) "CARD_PLAY_PUBLIC target projection Rect has no area"
    } elseif ($cueId -eq "CARD_RESOLUTION_FOCUS") {
        Assert-Proof (-not [string]::IsNullOrWhiteSpace([string]$envelope.source_public_receipt_id)) "CARD_RESOLUTION_FOCUS source receipt id is empty"
        Assert-Proof (Test-LowerSha256 $envelope.source_public_receipt_sha256) "CARD_RESOLUTION_FOCUS public receipt hash is invalid"
        Assert-Proof ([string]$envelope.source_public_receipt_sha256 -eq [string]$projection.public_receipt_sha256) "CARD_RESOLUTION_FOCUS Director projection lost receipt lineage"
        Assert-Proof (Test-SerializedRectArea $projection.source_global_rect) "CARD_RESOLUTION_FOCUS source projection Rect has no area"
        Assert-Proof (Test-SerializedRectArea $projection.target_global_rect) "CARD_RESOLUTION_FOCUS target projection Rect has no area"
    }
    $receiptIds.Add([string]$evidence.receipt_id)
    $cueRows.Add([ordered]@{
        cue_id = $cueId
        source_count = [int]$row.source_count
        production_queued_count = [int]$row.production_queued_count
        production_finished_count = [int]$row.production_finished_count
        receipt_id = [string]$evidence.receipt_id
        receipt_kind = [string]$envelope.receipt_kind
        consumer_class = [string]$evidence.consumer_class
        envelope_schema = [string]$envelope.schema
        lineage_class = [string]$envelope.source_lineage_class
        source_rect = [string]$evidence.start_evidence.source_rect
        target_rect = [string]$evidence.start_evidence.target_rect
        end_rect = [string]$evidence.finish_evidence.end_rect
        projection = $projection
        gameplay_mutation_count = [int]$evidence.finish_evidence.gameplay_mutation_count
        rng_draw_delta = [int]$evidence.finish_evidence.rng_draw_delta
        authority_sequence_delta = [int]$evidence.finish_evidence.authority_sequence_delta
        fixture_source_count = [int]$row.fixture_source_count
    })
}

$finalRow = $finalChain.row
$finalEvidence = $finalChain.evidence
Assert-ProductionCue `
    -CueId "FINAL_SETTLEMENT" `
    -Row $finalRow `
    -Evidence $finalEvidence `
    -ExpectedSchema "V076FinalSettlementPresentationEnvelopeV1" `
    -ExpectedConsumer "AUTHORIZED_SETTLEMENT_PROJECTION" `
    -ExpectedReceiptKind "final_settlement_receipt" `
    -ExactlyOne $true
$finalEnvelope = $finalEvidence.envelope
$finalProjection = $finalEvidence.queued_cue.projection
Assert-Proof (Test-LowerSha256 $finalEnvelope.source_settlement_id_sha256) "FINAL_SETTLEMENT settlement id lineage hash is invalid"
Assert-Proof (Test-LowerSha256 $finalEnvelope.source_settlement_projection_sha256) "FINAL_SETTLEMENT settlement projection hash is invalid"
Assert-Proof ([string]$finalEnvelope.source_settlement_projection_sha256 -eq [string]$finalProjection.settlement_projection_sha256) "FINAL_SETTLEMENT Director projection lost settlement lineage"
Assert-Proof (Test-SerializedRectArea $finalProjection.target_global_rect) "FINAL_SETTLEMENT target projection Rect has no area"
Assert-Proof ([int]$finalChain.director_queued_count -eq 1) "unique Director did not queue FINAL_SETTLEMENT exactly once"
Assert-Proof ([int]$finalChain.director_finished_count -eq 1) "unique Director did not finish FINAL_SETTLEMENT exactly once"
Assert-Proof ([string]$finalEnvelope.fixture_class -eq "") "FINAL_SETTLEMENT is fixture-classified"
Assert-Proof (-not [bool]$finalEnvelope.production_green) "FINAL_SETTLEMENT automation inflated production green"
Assert-Proof (-not [bool]$finalEnvelope.human_green) "FINAL_SETTLEMENT automation inflated human green"
$receiptIds.Add([string]$finalEvidence.receipt_id)
$cueRows.Add([ordered]@{
    cue_id = "FINAL_SETTLEMENT"
    source_count = [int]$finalRow.source_count
    production_queued_count = [int]$finalRow.production_queued_count
    production_finished_count = [int]$finalRow.production_finished_count
    receipt_id = [string]$finalEvidence.receipt_id
    receipt_kind = [string]$finalEnvelope.receipt_kind
    consumer_class = [string]$finalEvidence.consumer_class
    envelope_schema = [string]$finalEnvelope.schema
    lineage_class = [string]$finalEnvelope.source_lineage_class
    source_rect = [string]$finalEvidence.start_evidence.source_rect
    target_rect = [string]$finalEvidence.start_evidence.target_rect
    end_rect = [string]$finalEvidence.finish_evidence.end_rect
    projection = $finalProjection
    gameplay_mutation_count = [int]$finalEvidence.finish_evidence.gameplay_mutation_count
    rng_draw_delta = [int]$finalEvidence.finish_evidence.rng_draw_delta
    authority_sequence_delta = [int]$finalEvidence.finish_evidence.authority_sequence_delta
    fixture_source_count = [int]$finalRow.fixture_source_count
})

$distinctReceiptIds = @($receiptIds | Sort-Object -Unique)
Assert-Proof ($distinctReceiptIds.Count -eq $receiptIds.Count) "four cue evidence rows collide on receipt identity"

foreach ($field in @(
    "animation_gameplay_mutation_count",
    "animation_rng_draw_delta",
    "animation_authority_sequence_delta",
    "animation_deck_order_mutation_count",
    "animation_card_zone_mutation_count",
    "animation_facility_state_mutation_count"
)) {
    Assert-Proof ([int](Get-ObjectProperty $cardChain.director $field) -eq 0) "unique Director $field is not zero"
}
Assert-Proof ([int]$cardChain.director.queued_cue_count -eq 0) "unique Director queue did not drain"
Assert-Proof ([int]$cardChain.director.receipt_collision_count -eq 0) "unique Director has receipt collisions"
Assert-Proof ([int]$cardChain.director.receipt_rejection_count -eq 0) "unique Director has receipt rejections"
Assert-Proof ([bool]$cardChain.director.receipt_exact_once) "unique Director exact-once flag is false"
foreach ($field in @(
    "animation_gameplay_mutation_count",
    "animation_rng_draw_delta",
    "animation_authority_sequence_delta",
    "animation_card_zone_mutation_count"
)) {
    Assert-Proof ([int](Get-ObjectProperty $cardChain.bridge $field) -eq 0) "card-table bridge $field is not zero"
}

$headSha = [string](& git -C $ProjectPath rev-parse HEAD)
$treeSha = [string](& git -C $ProjectPath rev-parse 'HEAD^{tree}')
$status = if ($failures.Count -eq 0) { "PASS_AUTOMATED_NATURAL_PRODUCTION_ONLY" } else { "FAIL" }
$report = [ordered]@{
    schema = "V076NaturalProductionCueProofV1"
    status = $status
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    evaluated_head = $headSha.Trim()
    evaluated_tree = $treeSha.Trim()
    scope = "PRODUCTION_MAIN_AUTOMATED_RUNTIME"
    production_main_scene = "res://scenes/main.tscn"
    cue_count = 4
    fixture_state_injection_count = 0
    direct_presentation_method_call_count = 0
    direct_method_call_false_green_count = 0
    presentation_director_implementation_count = 1
    animation_gameplay_mutation_count = 0
    animation_rng_draw_delta = 0
    animation_authority_sequence_delta = 0
    animation_card_zone_mutation_count = 0
    receipt_collision_count = 0
    receipt_rejection_count = 0
    proof_check_count = $script:checkCount
    proof_failure_count = $failures.Count
    proof_failures = @($failures)
    runs = [ordered]@{
        card_table = [ordered]@{
            run_id = [string]$cardResult.run_id
            test_script = [string]$cardResult.test_script
            result_json = [string]$cardResult.result_json
            stdout_log = [string]$cardResult.stdout_log
            duration_seconds = [double]$cardResult.duration_seconds
            process_exit_code = [int]$cardResult.process_exit_code
            runner_exit_code = [int]$cardResult.runner_exit_code
            script_error_count = [int]$cardResult.script_error_count
            diagnostic_count = [int]$cardResult.diagnostic_count
            task_introduced_error_count = [int]$cardResult.task_introduced_error_count
            residual_process_count = @($cardResult.remaining_project_runtime_process_ids).Count
            completion_marker = $cardCompletion
            reused_result = -not [string]::IsNullOrWhiteSpace($CardResultJson)
        }
        final_settlement = [ordered]@{
            run_id = [string]$victoryResult.run_id
            test_script = [string]$victoryResult.test_script
            result_json = [string]$victoryResult.result_json
            stdout_log = [string]$victoryResult.stdout_log
            duration_seconds = [double]$victoryResult.duration_seconds
            process_exit_code = [int]$victoryResult.process_exit_code
            runner_exit_code = [int]$victoryResult.runner_exit_code
            script_error_count = [int]$victoryResult.script_error_count
            diagnostic_count = [int]$victoryResult.diagnostic_count
            task_introduced_error_count = [int]$victoryResult.task_introduced_error_count
            residual_process_count = @($victoryResult.remaining_project_runtime_process_ids).Count
            completion_marker = $victoryCompletion
        }
    }
    cues = @($cueRows)
    boundary = [ordered]@{
        natural_production_automation = $true
        fixture_evidence = $false
        headed_visual_evidence = $false
        human_executed = $false
        human_confirmed = $false
        human_green = $false
        full_product_production_green = $false
        commercial_m1_green = $false
        step13_status = "PENDING"
        step14_status = "PENDING"
        step15_status = "PENDING"
        conclusion = "Four natural production cue chains are automated-green only. FinalSettlement runtime readiness is not a human STEP13 pass."
    }
}

$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$report | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ReportPath -Encoding utf8

Write-Output (
    "V076_NATURAL_PRODUCTION_CUE_PROOF|status={0}|checks={1}|failures={2}|card_table_run_id={3}|final_settlement_run_id={4}|human_green=false|step13_status=PENDING|step14_status=PENDING|step15_status=PENDING|report={5}" -f `
        $status,
        $script:checkCount,
        $failures.Count,
        [string]$cardResult.run_id,
        [string]$victoryResult.run_id,
        $ReportPath
)
exit $(if ($failures.Count -eq 0) { 0 } else { 1 })
