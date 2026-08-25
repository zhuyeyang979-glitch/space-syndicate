extends Control
class_name V075NewGameLoadingOverlay

signal loading_stage_changed(snapshot: Dictionary)

const TIMING_SCHEMA := "V076NewGameStartupTimingV1"
const STAGE_COUNT := 3
const NEW_GAME_INTENT_KIND := "new_game.start"
const FIRST_PLAYABLE_MARKER_TYPE := "new_game_first_playable"

@onready var _title: Label = %LoadingTitle
@onready var _stage_label: Label = %LoadingStage
@onready var _detail_label: Label = %LoadingDetail
@onready var _progress: ProgressBar = %LoadingProgress

var _active := false
var _intent_id := ""
var _stage_id := "idle"
var _stage_index := 0
var _started_msec := 0
var _first_playable_msec := 0
var _click_to_first_playable_msec := 0
var _begin_count := 0
var _first_playable_count := 0
var _failure_count := 0
var _duplicate_begin_rejection_count := 0
var _telemetry_recorded := false
var _receipt_accepted := false
var _last_failure_reason := ""
var _stage_history: Array[String] = []
var _application_flow: Node
var _game_screen: Control
var _playtest_telemetry: Node
var _sources_bound := false
var _pending_new_game_intent: Dictionary = {}
var _loading_sequence := 0
var _first_playable_scheduled := false
var _first_playable_snapshot: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func bind_sources(flow: Node, screen: Control, telemetry: Node) -> bool:
	if _sources_bound or not is_instance_valid(flow) or not is_instance_valid(screen):
		return false
	_application_flow = flow
	_game_screen = screen
	_playtest_telemetry = telemetry
	_application_flow.projection_changed.connect(_on_projection_changed)
	_application_flow.receipt_ready.connect(_on_receipt_ready)
	_sources_bound = true
	return true


## Bootstrap remains the sole signal connection and calls this typed bridge.
## The historical `application_intent_requested.connect(...)` edge therefore
## stays singular on Bootstrap; this presentation node only decides whether a
## startup request is delayed.  Returning true means the request has been
## handled (either delayed here or forwarded to the existing flow).
func intercept_application_intent(intent: Dictionary) -> bool:
	if str(intent.get("intent_kind", "")) != NEW_GAME_INTENT_KIND:
		_application_flow.call("submit_intent", intent)
		return true
	_queue_new_game_after_loading_feedback(intent)
	return true


func _queue_new_game_after_loading_feedback(intent: Dictionary) -> void:
	if not _pending_new_game_intent.is_empty():
		_duplicate_begin_rejection_count += 1
		return
	_loading_sequence += 1
	_pending_new_game_intent = intent.duplicate(true)
	_receipt_accepted = false
	_first_playable_scheduled = false
	_first_playable_snapshot = {}
	if not begin_loading(str(intent.get("intent_id", ""))):
		_pending_new_game_intent = {}
		return
	call_deferred(
		"_submit_pending_new_game_after_feedback_frames",
		_loading_sequence
	)


func _submit_pending_new_game_after_feedback_frames(sequence: int) -> void:
	await get_tree().process_frame
	if not _new_game_submission_is_current(sequence):
		return
	mark_authority_initialization_started()
	await get_tree().process_frame
	if not _new_game_submission_is_current(sequence):
		return
	_application_flow.call(
		"submit_intent",
		_pending_new_game_intent.duplicate(true)
	)


func _new_game_submission_is_current(sequence: int) -> bool:
	return (
		sequence == _loading_sequence
		and not _pending_new_game_intent.is_empty()
		and is_instance_valid(_application_flow)
	)


func _on_projection_changed(snapshot: Dictionary) -> void:
	var first_playable := (
		not _pending_new_game_intent.is_empty()
		and _is_first_playable_snapshot(snapshot)
	)
	if first_playable:
		mark_projection_received()
	if first_playable and not _first_playable_scheduled:
		_first_playable_scheduled = true
		_first_playable_snapshot = snapshot.duplicate(true)
		call_deferred(
			"_complete_new_game_loading_after_presented_frame",
			_loading_sequence
		)


func _is_first_playable_snapshot(snapshot: Dictionary) -> bool:
	return (
		bool(snapshot.get("match_started", false))
		and str(snapshot.get("phase", "idle")) not in ["idle", "failed"]
		and (snapshot.get("roster", []) as Array).size() >= 3
		and snapshot.get("unified_track", {}) is Dictionary
		and snapshot.get("legal_actions", []) is Array
	)


func _complete_new_game_loading_after_presented_frame(sequence: int) -> void:
	await get_tree().process_frame
	if not _new_game_submission_is_current(sequence) or not _receipt_accepted:
		_first_playable_scheduled = false
		return
	var timing := mark_first_playable()
	if timing.is_empty():
		return
	var recorded := false
	if is_instance_valid(_playtest_telemetry):
		recorded = bool(_playtest_telemetry.call(
			"record_presentation_event",
			"playtest_marker_recorded",
			{
				"marker_type": FIRST_PLAYABLE_MARKER_TYPE,
				"latency_ms": int(timing.get(
					"click_to_first_playable_msec",
					0
				)),
				"phase": str(_first_playable_snapshot.get("phase", "unknown")),
				"source_surface": "new_game_loading_overlay",
			}
		))
	mark_telemetry_recorded(recorded)
	_pending_new_game_intent = {}
	_first_playable_snapshot = {}
	_first_playable_scheduled = false


func _on_receipt_ready(receipt: Dictionary) -> void:
	if (
		str(receipt.get("intent_kind", "")) != NEW_GAME_INTENT_KIND
		or _pending_new_game_intent.is_empty()
		or str(receipt.get("intent_id", "")) != str(
			_pending_new_game_intent.get("intent_id", "")
		)
	):
		return
	if bool(receipt.get("accepted", false)):
		_receipt_accepted = true
		mark_receipt_accepted()
		return
	mark_failed(str(receipt.get("reason_code", "new_game_start_rejected")))
	_pending_new_game_intent = {}
	_first_playable_snapshot = {}
	_first_playable_scheduled = false


func begin_loading(intent_id: String) -> bool:
	if _active:
		_duplicate_begin_rejection_count += 1
		return false
	_active = true
	_intent_id = intent_id.strip_edges()
	_started_msec = Time.get_ticks_msec()
	_first_playable_msec = 0
	_click_to_first_playable_msec = 0
	_telemetry_recorded = false
	_receipt_accepted = false
	_last_failure_reason = ""
	_stage_history = []
	_begin_count += 1
	visible = true
	_title.text = "正在准备新对局"
	_set_stage(
		"request_received",
		1,
		"读取地图设定与玩家席位…",
		"首次进入可能需要几秒，请稍候。",
		0.35
	)
	return true


func mark_authority_initialization_started() -> void:
	if not _active:
		return
	_set_stage(
		"authority_initialization",
		2,
		"生成星球、牌轨与 AI…",
		"对局规则与结果仍由既有 Runtime 统一生成。",
		1.35
	)


func mark_projection_received() -> void:
	if not _active:
		return
	_set_stage(
		"projection_received",
		3,
		"布置主桌与可操作卡牌…",
		"世界已经就绪，正在显示第一帧主桌。",
		2.55
	)


func mark_receipt_accepted() -> void:
	if not _active:
		return
	_receipt_accepted = true
	_progress.value = 2.85
	_detail_label.text = "对局状态已确认，正在显示第一帧主桌。"


func mark_first_playable() -> Dictionary:
	if not _active or _first_playable_count >= _begin_count:
		return {}
	_first_playable_msec = Time.get_ticks_msec()
	_click_to_first_playable_msec = maxi(
		0,
		_first_playable_msec - _started_msec
	)
	_first_playable_count += 1
	_set_stage(
		"first_playable",
		STAGE_COUNT,
		"主桌已就绪",
		"可以开始行动。",
		3.0
	)
	_active = false
	visible = false
	return timing_snapshot()


func mark_failed(reason_code: String) -> void:
	if not _active:
		return
	_failure_count += 1
	_last_failure_reason = reason_code.strip_edges()
	_active = false
	_stage_id = "failed"
	_stage_index = 0
	visible = false
	loading_stage_changed.emit(debug_snapshot())


func mark_telemetry_recorded(recorded: bool) -> void:
	_telemetry_recorded = recorded


func is_loading() -> bool:
	return _active


func timing_snapshot() -> Dictionary:
	return {
		"schema": TIMING_SCHEMA,
		"intent_id": _intent_id,
		"click_to_first_playable_msec": _click_to_first_playable_msec,
		"started_msec": _started_msec,
		"first_playable_msec": _first_playable_msec,
		"measurement_clock": "Time.get_ticks_msec.presentation_only",
		"presentation_stage_count": STAGE_COUNT,
		"gameplay_owner_count": 0,
		"tick_owner_count": 0,
		"rng_owner_count": 0,
		"world_mutation_count": 0,
		"authority_initialization_async_split_count": 0,
	}


func debug_snapshot() -> Dictionary:
	var result := timing_snapshot()
	result.merge({
		"active": _active,
		"visible": visible,
		"stage_id": _stage_id,
		"stage_index": _stage_index,
		"stage_history": _stage_history.duplicate(),
		"begin_count": _begin_count,
		"first_playable_count": _first_playable_count,
		"failure_count": _failure_count,
		"duplicate_begin_rejection_count": (
			_duplicate_begin_rejection_count
		),
		"receipt_accepted": _receipt_accepted,
		"telemetry_recorded": _telemetry_recorded,
		"last_failure_reason": _last_failure_reason,
	}, true)
	return result


func _set_stage(
	stage_id: String,
	stage_index: int,
	stage_text: String,
	detail_text: String,
	progress_value: float
) -> void:
	_stage_id = stage_id
	_stage_index = stage_index
	if _stage_history.is_empty() or _stage_history[-1] != stage_id:
		_stage_history.append(stage_id)
	_stage_label.text = "阶段 %d/%d · %s" % [
		stage_index,
		STAGE_COUNT,
		stage_text,
	]
	_detail_label.text = detail_text
	_progress.value = clampf(progress_value, 0.0, float(STAGE_COUNT))
	loading_stage_changed.emit(debug_snapshot())
