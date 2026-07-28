extends PanelContainer
class_name TopCommoditySushiTrack

const ITEM_SCENE := preload("res://scenes/ui/table/TopCommoditySushiTrackItem.tscn")
const ITEM_NODE_SCRIPT := preload("res://scripts/ui/table/top_commodity_sushi_track_item.gd")
const ITEM_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/commodity_sushi_track_item_snapshot.gd")
const SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/commodity_sushi_track_snapshot.gd")

const STRUCTURED_CLAIM_FAILURE_CODES: Array[String] = [
	"commodity_inventory_full",
	"shared_hand_capacity_full",
	"stale_source_revision",
	"item_already_claimed",
	"item_not_visible",
	"item_not_claimable",
	"actor_authorization_invalid",
	"session_not_running",
	"request_duplicate",
	"request_collision",
	# Active v0.6 Action Spine result vocabulary. These aliases remain presentation-only.
	"claim_request_invalid",
	"snapshot_stale",
	"commodity_slot_changed",
	"commodity_slot_unavailable",
	"viewer_binding_unavailable",
	"inventory_full",
	"claim_failed",
	"forced_decision_blocking",
]
const PERFORMANCE_SAMPLE_LIMIT := 128
const RAPID_SOURCE_ADVANCE_GUARD_MSEC := 360

signal item_focused(item: ITEM_SNAPSHOT_SCRIPT)
signal claim_requested(item: ITEM_SNAPSHOT_SCRIPT)
signal claim_feedback_changed(feedback: Dictionary)

@onready var phase_label: Label = %CommodityTrackPhaseLabel
@onready var count_label: Label = %CommodityTrackCountLabel
@onready var item_host: HBoxContainer = %CommodityTrackItemHost
@onready var empty_label: Label = %CommodityTrackEmptyLabel
@onready var belt_viewport: Control = $TrackMargin/TrackRows/BeltViewport

var _snapshot: SNAPSHOT_SCRIPT
var _item_nodes_by_id: Dictionary = {}
var _selected_slot_id := ""
var _last_snapshot_revision := -1
var _last_snapshot_fingerprint := ""
var _created_node_count := 0
var _reused_node_count := 0
var _removed_node_count := 0
var _stale_rejection_count := 0
var _duplicate_id_rejection_count := 0
var _pending_claims_by_identity: Dictionary = {}
var _successful_claim_identities: Dictionary = {}
var _claim_submission_count := 0
var _duplicate_claim_suppression_count := 0
var _claim_result_success_count := 0
var _claim_result_failure_count := 0
var _invalid_claim_result_count := 0
var _stale_claim_result_count := 0
var _last_claim_feedback: Dictionary = {}
var _source_render_usec_samples: Array[int] = []
var _hover_to_focus_usec_samples: Array[int] = []
var _click_to_intent_usec_samples: Array[int] = []
var _pointer_owner_slot_id := ""
var _hovered_pointer_slot_id := ""
var _suppress_double_click_release := false
var _scoped_pointer_capture_count := 0
var _scoped_pointer_release_count := 0
var _scoped_handled_event_count := 0
var _belt_motion := 0.0
var _last_claim_submission_msec := -RAPID_SOURCE_ADVANCE_GUARD_MSEC


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	set_process(true)
	_apply_panel_style()
	_update_density()


func set_snapshot(snapshot: SNAPSHOT_SCRIPT) -> bool:
	var render_started_usec := Time.get_ticks_usec()
	if snapshot == null or not snapshot.is_valid():
		_stale_rejection_count += 1
		return false
	var data := snapshot.to_dictionary()
	var fingerprint := JSON.stringify(data, "", true)
	if snapshot.snapshot_revision < _last_snapshot_revision:
		_stale_rejection_count += 1
		return false
	if snapshot.snapshot_revision == _last_snapshot_revision:
		if fingerprint == _last_snapshot_fingerprint:
			return true
		_stale_rejection_count += 1
		return false
	var seen_ids: Dictionary = {}
	for item in snapshot.items:
		if seen_ids.has(item.commodity_slot_id):
			_duplicate_id_rejection_count += 1
			return false
		seen_ids[item.commodity_slot_id] = true
	_reconcile_claim_state(snapshot)
	_snapshot = SNAPSHOT_SCRIPT.new().apply_dictionary(data)
	_last_snapshot_revision = snapshot.snapshot_revision
	_last_snapshot_fingerprint = fingerprint
	_sync_item_nodes()
	_sync_header()
	_record_performance_sample(_source_render_usec_samples, Time.get_ticks_usec() - render_started_usec)
	return true


func set_snapshot_dictionary(data: Dictionary) -> bool:
	return set_snapshot(SNAPSHOT_SCRIPT.new().apply_dictionary(data))


func item_snapshot_by_id(slot_id: String) -> ITEM_SNAPSHOT_SCRIPT:
	return _snapshot.item_by_id(slot_id) if _snapshot != null and _snapshot.is_valid() else null


func selected_item_snapshot() -> ITEM_SNAPSHOT_SCRIPT:
	return item_snapshot_by_id(_selected_slot_id)


func bind_pending_request_revision(slot_id: String, request_revision: int) -> bool:
	if slot_id.strip_edges().is_empty() or request_revision <= 0:
		return false
	var identity := _pending_identity_for_slot(slot_id)
	if identity.is_empty():
		return false
	var pending: Dictionary = _pending_claims_by_identity.get(identity, {}) \
		if _pending_claims_by_identity.get(identity, {}) is Dictionary else {}
	if pending.is_empty():
		return false
	pending["request_revision"] = request_revision
	_pending_claims_by_identity[identity] = pending
	return true


func apply_claim_result(result: Dictionary) -> bool:
	if not _claim_result_has_structured_shape(result):
		_invalid_claim_result_count += 1
		return false
	var slot_id := str(result.get("focus_target", "")).strip_edges()
	var identity := _pending_identity_for_slot(slot_id)
	if identity.is_empty():
		_stale_claim_result_count += 1
		return false
	var pending: Dictionary = _pending_claims_by_identity.get(identity, {}) \
		if _pending_claims_by_identity.get(identity, {}) is Dictionary else {}
	var expected_request_revision := int(pending.get("request_revision", 0))
	var result_request_revision := int(result.get("request_revision", 0))
	if expected_request_revision > 0 and result_request_revision != expected_request_revision:
		_stale_claim_result_count += 1
		return false
	var success := bool(result.get("success", false))
	var code := "" if success else str(result.get("failure_code", "")).strip_edges()
	var feedback := _structured_feedback(code, result, success)
	_pending_claims_by_identity.erase(identity)
	if success:
		_successful_claim_identities[identity] = true
		_claim_result_success_count += 1
	else:
		_claim_result_failure_count += 1
	_last_claim_feedback = feedback.duplicate(true)
	var item_node := _item_nodes_by_id.get(slot_id) as ITEM_NODE_SCRIPT
	if item_node != null and item_node.source_identity() == identity:
		item_node.set_pending(false)
		item_node.set_action_feedback(feedback)
	claim_feedback_changed.emit(feedback.duplicate(true))
	return true


func reject_pending_claim(
	slot_id: String,
	failure_code: String,
	explanation: String,
	suggested_action := ""
) -> bool:
	return apply_claim_result({
		"success": false,
		"failure_code": failure_code,
		"focus_target": slot_id,
		"request_revision": _pending_request_revision_for_slot(slot_id),
		"explanation": explanation,
		"suggested_action": suggested_action,
	})


func structured_failure_codes() -> Array[String]:
	return STRUCTURED_CLAIM_FAILURE_CODES.duplicate()


func feedback_for_failure_code(failure_code: String) -> Dictionary:
	return _structured_feedback(failure_code, {}, false)


func debug_snapshot() -> Dictionary:
	return {
		"snapshot_revision": _last_snapshot_revision,
		"rendered_item_count": _item_nodes_by_id.size(),
		"rendered_slot_ids": _ordered_rendered_ids(),
		"selected_slot_id": _selected_slot_id,
		"created_node_count": _created_node_count,
		"reused_node_count": _reused_node_count,
		"removed_node_count": _removed_node_count,
		"stale_rejection_count": _stale_rejection_count,
		"duplicate_id_rejection_count": _duplicate_id_rejection_count,
		"pending_claim_count": _pending_claims_by_identity.size(),
		"pending_claim_identities": _sorted_dictionary_keys(_pending_claims_by_identity),
		"successful_claim_identity_count": _successful_claim_identities.size(),
		"claim_submission_count": _claim_submission_count,
		"duplicate_claim_suppression_count": _duplicate_claim_suppression_count,
		"claim_result_success_count": _claim_result_success_count,
		"claim_result_failure_count": _claim_result_failure_count,
		"invalid_claim_result_count": _invalid_claim_result_count,
		"stale_claim_result_count": _stale_claim_result_count,
		"last_claim_feedback": _last_claim_feedback.duplicate(true),
		"commodity_source_render_p95_ms": _p95_milliseconds(_source_render_usec_samples),
		"commodity_source_render_sample_count": _source_render_usec_samples.size(),
		"commodity_hover_p95_ms": _p95_milliseconds(_hover_to_focus_usec_samples),
		"commodity_hover_sample_count": _hover_to_focus_usec_samples.size(),
		"single_click_to_intent_p95_ms": _p95_milliseconds(_click_to_intent_usec_samples),
		"single_click_to_intent_sample_count": _click_to_intent_usec_samples.size(),
		"pointer_owner_slot_id": _pointer_owner_slot_id,
		"scoped_pointer_capture_count": _scoped_pointer_capture_count,
		"scoped_pointer_release_count": _scoped_pointer_release_count,
		"scoped_handled_event_count": _scoped_handled_event_count,
		"structured_failure_codes": structured_failure_codes(),
		"claim_button_count": find_children("*", "Button", true, false).size(),
		"direct_inventory_mutation_count": 0,
		"direct_track_mutation_count": 0,
		"cards_are_stationary": true,
		"belt_decoration_moves": true,
		"clear_all_rebuild_count": 0,
	}


func _process(delta: float) -> void:
	_belt_motion = fmod(_belt_motion + maxf(0.0, delta) * 18.0, 24.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event == null:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if not _pointer_owner_slot_id.is_empty():
			var pointer_owner := _item_nodes_by_id.get(_pointer_owner_slot_id) as ITEM_NODE_SCRIPT
			if pointer_owner != null:
				pointer_owner.update_pointer_gesture(motion.global_position)
			_mark_scoped_pointer_handled()
			return
		var hovered_item := _item_node_at_screen_position(motion.global_position)
		var hovered_slot_id := _slot_id_for_item_node(hovered_item)
		if hovered_slot_id != _hovered_pointer_slot_id:
			_hovered_pointer_slot_id = hovered_slot_id
			if hovered_item != null:
				hovered_item.notify_pointer_hover()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		var pressed_item := _item_node_at_screen_position(mouse_event.global_position)
		if mouse_event.double_click:
			if pressed_item == null:
				return
			_suppress_double_click_release = true
			_duplicate_claim_suppression_count += 1
			_mark_scoped_pointer_handled()
			return
		if not _pointer_owner_slot_id.is_empty():
			return
		var pressed_slot_id := _slot_id_for_item_node(pressed_item)
		if pressed_item == null or pressed_slot_id.is_empty():
			return
		_pointer_owner_slot_id = pressed_slot_id
		pressed_item.begin_pointer_gesture(mouse_event.global_position)
		_scoped_pointer_capture_count += 1
		_mark_scoped_pointer_handled()
		return
	if _suppress_double_click_release:
		_suppress_double_click_release = false
		_mark_scoped_pointer_handled()
		return
	if _pointer_owner_slot_id.is_empty():
		return
	var released_item := _item_nodes_by_id.get(_pointer_owner_slot_id) as ITEM_NODE_SCRIPT
	_pointer_owner_slot_id = ""
	if released_item != null:
		released_item.finish_pointer_gesture(mouse_event.global_position)
	_scoped_pointer_release_count += 1
	_mark_scoped_pointer_handled()


func _draw() -> void:
	var y := size.y - 17.0
	draw_line(Vector2(10.0, y), Vector2(size.x - 10.0, y), Color("#38bdf8", 0.22), 2.0)
	var x := -24.0 + _belt_motion
	while x < size.x:
		draw_line(Vector2(x, y - 4.0), Vector2(x + 10.0, y + 4.0), Color("#f8fafc", 0.16), 2.0)
		x += 24.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_density()


func _sync_item_nodes() -> void:
	var wanted: Dictionary = {}
	for item in _snapshot.items:
		wanted[item.commodity_slot_id] = true
		var item_node := _item_nodes_by_id.get(item.commodity_slot_id) as ITEM_NODE_SCRIPT
		if item_node == null:
			item_node = ITEM_SCENE.instantiate() as ITEM_NODE_SCRIPT
			if item_node == null:
				continue
			item_node.name = "CommoditySlot_%s" % _safe_node_name(item.commodity_slot_id)
			item_host.add_child(item_node)
			item_node.item_focused.connect(_on_item_focused)
			item_node.claim_requested.connect(_on_claim_requested)
			_item_nodes_by_id[item.commodity_slot_id] = item_node
			_created_node_count += 1
		else:
			_reused_node_count += 1
		var source_identity := _source_identity_for(_snapshot, item)
		item_node.set_item(item, source_identity)
		item_node.set_pending(_pending_claims_by_identity.has(source_identity), source_identity)
	for existing_id_variant in _item_nodes_by_id.keys():
		var existing_id := str(existing_id_variant)
		if wanted.has(existing_id):
			continue
		var stale_node := _item_nodes_by_id.get(existing_id) as Node
		_item_nodes_by_id.erase(existing_id)
		if stale_node != null:
			stale_node.queue_free()
		_removed_node_count += 1
		if _selected_slot_id == existing_id:
			_selected_slot_id = ""
	for index in range(_snapshot.items.size()):
		var item := _snapshot.items[index]
		var item_node := _item_nodes_by_id.get(item.commodity_slot_id) as Control
		if item_node != null and item_node.get_index() != index:
			item_host.move_child(item_node, index)
	_sync_selected_state()


func _sync_header() -> void:
	phase_label.text = _snapshot.public_refresh_phase if _snapshot != null else ""
	count_label.text = "%d 件公开商品" % _item_nodes_by_id.size()
	empty_label.text = _snapshot.empty_text if _snapshot != null else "共享商品带尚未就绪。"
	empty_label.visible = _item_nodes_by_id.is_empty()
	item_host.visible = not _item_nodes_by_id.is_empty()


func _on_item_focused(item: ITEM_SNAPSHOT_SCRIPT) -> void:
	if item == null or not item.is_valid():
		return
	_selected_slot_id = item.commodity_slot_id
	_sync_selected_state()
	var item_node := _item_nodes_by_id.get(item.commodity_slot_id) as ITEM_NODE_SCRIPT
	if item_node != null and item_node.last_focus_started_usec() > 0:
		_record_performance_sample(
			_hover_to_focus_usec_samples,
			Time.get_ticks_usec() - item_node.last_focus_started_usec()
		)
	item_focused.emit(item)


func _on_claim_requested(item: ITEM_SNAPSHOT_SCRIPT) -> void:
	if item == null or not item.is_valid() or _snapshot == null or not _snapshot.is_valid():
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec - _last_claim_submission_msec < RAPID_SOURCE_ADVANCE_GUARD_MSEC:
		_duplicate_claim_suppression_count += 1
		return
	var current_item := _snapshot.item_by_id(item.commodity_slot_id)
	if current_item == null or current_item.commodity_card_id != item.commodity_card_id or not current_item.claimable:
		return
	var identity := _source_identity_for(_snapshot, current_item)
	if identity.is_empty() or _pending_claims_by_identity.has(identity) or _successful_claim_identities.has(identity):
		_duplicate_claim_suppression_count += 1
		return
	_pending_claims_by_identity[identity] = {
		"slot_id": current_item.commodity_slot_id,
		"commodity_card_id": current_item.commodity_card_id,
		"snapshot_revision": _snapshot.snapshot_revision,
		"belt_revision": _snapshot.belt_revision,
		"visibility_revision": _snapshot.visibility_revision,
		"request_revision": 0,
	}
	_last_claim_submission_msec = now_msec
	var item_node := _item_nodes_by_id.get(current_item.commodity_slot_id) as ITEM_NODE_SCRIPT
	if item_node != null:
		item_node.set_action_feedback({})
		item_node.set_pending(true, identity)
	_claim_submission_count += 1
	if item_node != null and item_node.last_activation_started_usec() > 0:
		_record_performance_sample(
			_click_to_intent_usec_samples,
			Time.get_ticks_usec() - item_node.last_activation_started_usec()
		)
	_on_item_focused(item)
	claim_requested.emit(current_item)


func _reconcile_claim_state(next_snapshot: SNAPSHOT_SCRIPT) -> void:
	var valid_identities: Dictionary = {}
	for item in next_snapshot.items:
		valid_identities[_source_identity_for(next_snapshot, item)] = true
	for identity_variant in _pending_claims_by_identity.keys():
		var identity := str(identity_variant)
		if not valid_identities.has(identity):
			_pending_claims_by_identity.erase(identity)
	for identity_variant in _successful_claim_identities.keys():
		var identity := str(identity_variant)
		if not valid_identities.has(identity):
			_successful_claim_identities.erase(identity)


func _source_identity_for(snapshot: SNAPSHOT_SCRIPT, item: ITEM_SNAPSHOT_SCRIPT) -> String:
	if snapshot == null or not snapshot.is_valid() or item == null or not item.is_valid():
		return ""
	return "%s|%s|%d|%d|%d" % [
		item.commodity_slot_id,
		item.commodity_card_id,
		snapshot.snapshot_revision,
		snapshot.belt_revision,
		snapshot.visibility_revision,
	]


func _pending_identity_for_slot(slot_id: String) -> String:
	var matches: Array[String] = []
	for identity_variant in _pending_claims_by_identity.keys():
		var identity := str(identity_variant)
		var pending: Dictionary = _pending_claims_by_identity.get(identity, {}) \
			if _pending_claims_by_identity.get(identity, {}) is Dictionary else {}
		if str(pending.get("slot_id", "")) == slot_id:
			matches.append(identity)
	matches.sort()
	return matches[0] if matches.size() == 1 else ""


func _pending_request_revision_for_slot(slot_id: String) -> int:
	var identity := _pending_identity_for_slot(slot_id)
	if identity.is_empty():
		return 0
	var pending: Dictionary = _pending_claims_by_identity.get(identity, {}) \
		if _pending_claims_by_identity.get(identity, {}) is Dictionary else {}
	return int(pending.get("request_revision", 0))


func _claim_result_has_structured_shape(result: Dictionary) -> bool:
	if not result.has("success") or not result.has("focus_target") or not result.has("request_revision"):
		return false
	var success := bool(result.get("success", false))
	var failure_code := str(result.get("failure_code", "")).strip_edges()
	return not str(result.get("focus_target", "")).strip_edges().is_empty() \
		and int(result.get("request_revision", 0)) >= 0 \
		and (success or not failure_code.is_empty())


func _structured_feedback(code: String, result: Dictionary, success: bool) -> Dictionary:
	var normalized_code := code.strip_edges()
	var supported := success or STRUCTURED_CLAIM_FAILURE_CODES.has(normalized_code)
	var label := "已领取" if success else _failure_label(normalized_code)
	var detail := str(result.get("explanation", "")).strip_edges()
	if detail.is_empty():
		detail = "商品已由权威库存接收。" if success else "领取条件在提交前发生变化。"
	return {
		"success": success,
		"failure_code": "" if success else normalized_code,
		"supported_failure_code": supported,
		"label": label,
		"detail": detail,
		"suggestion": str(result.get("suggested_action", "")).strip_edges(),
		"request_revision": int(result.get("request_revision", 0)),
		"focus_target": str(result.get("focus_target", "")).strip_edges(),
	}


func _failure_label(code: String) -> String:
	match code:
		"commodity_inventory_full", "shared_hand_capacity_full", "inventory_full":
			return "容量已满"
		"stale_source_revision", "snapshot_stale":
			return "来源已刷新"
		"item_already_claimed", "commodity_slot_changed":
			return "已被领取"
		"item_not_visible":
			return "当前不可见"
		"item_not_claimable", "commodity_slot_unavailable":
			return "当前不可领取"
		"actor_authorization_invalid", "viewer_binding_unavailable":
			return "席位无权领取"
		"session_not_running":
			return "对局未运行"
		"request_duplicate":
			return "请求已处理"
		"request_collision":
			return "请求冲突"
		"forced_decision_blocking":
			return "先完成当前决策"
		_:
			return "领取未完成"


func _sorted_dictionary_keys(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key_variant in source.keys():
		result.append(str(key_variant))
	result.sort()
	return result


func _record_performance_sample(samples: Array[int], elapsed_usec: int) -> void:
	samples.append(maxi(0, elapsed_usec))
	if samples.size() > PERFORMANCE_SAMPLE_LIMIT:
		samples.pop_front()


func _p95_milliseconds(samples: Array[int]) -> float:
	if samples.is_empty():
		return 0.0
	var ordered: Array[int] = samples.duplicate()
	ordered.sort()
	var index := mini(ordered.size() - 1, ceili(float(ordered.size()) * 0.95) - 1)
	return float(ordered[index]) / 1000.0


func _sync_selected_state() -> void:
	for slot_id_variant in _item_nodes_by_id.keys():
		var slot_id := str(slot_id_variant)
		var item_node := _item_nodes_by_id.get(slot_id) as ITEM_NODE_SCRIPT
		if item_node != null:
			item_node.set_selected(slot_id == _selected_slot_id)


func _item_node_at_screen_position(screen_position: Vector2) -> ITEM_NODE_SCRIPT:
	if belt_viewport == null or not belt_viewport.is_visible_in_tree() \
			or not belt_viewport.get_global_rect().has_point(screen_position):
		return null
	var children := item_host.get_children()
	for index in range(children.size() - 1, -1, -1):
		var child := children[index]
		if child is ITEM_NODE_SCRIPT:
			var item_node := child as ITEM_NODE_SCRIPT
			if item_node.is_visible_in_tree() and item_node.get_global_rect().has_point(screen_position):
				return item_node
	return null


func _slot_id_for_item_node(item_node: ITEM_NODE_SCRIPT) -> String:
	if item_node == null:
		return ""
	var item := item_node.item_snapshot()
	return item.commodity_slot_id if item != null and item.is_valid() else ""


func _mark_scoped_pointer_handled() -> void:
	_scoped_handled_event_count += 1
	get_viewport().set_input_as_handled()


func _ordered_rendered_ids() -> Array[String]:
	var result: Array[String] = []
	for child in item_host.get_children():
		if child is ITEM_NODE_SCRIPT:
			var item := (child as ITEM_NODE_SCRIPT).item_snapshot()
			if item != null:
				result.append(item.commodity_slot_id)
	return result


func _update_density() -> void:
	var viewport_height := get_viewport_rect().size.y if is_inside_tree() else 960.0
	custom_minimum_size.y = 140.0 if viewport_height >= 900.0 else 132.0
	for node_variant in _item_nodes_by_id.values():
		if node_variant is Control:
			(node_variant as Control).custom_minimum_size = Vector2(92, 88)


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#030b16", 0.96)
	style.border_color = Color("#334155")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	add_theme_stylebox_override("panel", style)


func _safe_node_name(value: String) -> String:
	return value.replace(".", "_").replace(":", "_").replace("/", "_")
