@tool
extends PanelContainer
class_name SpaceSyndicatePlayerCardDock

signal card_selected(card_data: Dictionary)
signal card_hovered(card_data: Dictionary)
signal card_unhovered
signal card_unselected(card_data: Dictionary)
signal card_target_selection_requested(card_data: Dictionary)
signal presentation_audio_event_requested(event_id: String, payload: Dictionary)
signal game_action_offer_requested(
	offer: Dictionary,
	submission_kind: String,
	parameters: Dictionary,
	target_overrides: Dictionary
)

const CARD_FACE_SCENE := preload("res://scenes/ui/CardFace.tscn")
const PERFORMANCE_SAMPLE_LIMIT := 128
const PROJECTION := preload("res://scripts/presentation/player_card_dock_projection_v1.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const HOVER_SCALE := 1.08
const HOVER_LIFT_PIXELS := 28.0
const HOVER_DURATION_SECONDS := 0.12
const DRAG_DEADZONE_PIXELS := 8.0
const DRAG_LIFT_DURATION_SECONDS := 0.11
const DRAG_MAX_TILT_RADIANS := deg_to_rad(4.0)

@onready var capacity_summary: Label = %CardDockCapacitySummary
@onready var bound_title: Label = %BoundActionTitle
@onready var normal_title: Label = %NormalHandTitle
@onready var commodity_title: Label = %CommodityTitle
@onready var bound_cards: HBoxContainer = %BoundActionCards
@onready var normal_cards: HBoxContainer = %NormalHandCards
@onready var commodity_cards: HBoxContainer = %CommodityCards
@onready var feedback: SpaceSyndicateCardDockActionFeedback = %CardDockActionFeedback

var _projection: Dictionary = {}
var _bound_viewer_index := -1
var _bound_authorization_revision := 0
var _selected_identity := ""
var _target_selection_identity := ""
var _target_selection_summary := ""
var _card_nodes: Array[Control] = []
var _card_node_by_identity: Dictionary = {}
var _apply_count := 0
var _reject_count := 0
var _duplicate_count := 0
var _stale_count := 0
var _conflict_count := 0
var _last_signature := ""
var _render_usec_samples: Array[int] = []
var _visual_tweens: Dictionary = {}
var _local_order_by_pool: Dictionary = {}
var _pointer_card: Control = null
var _pointer_pool_id := StringName()
var _pointer_press_global_position := Vector2.ZERO
var _pointer_origin_index := -1
var _pointer_dragging := false
var _local_reorder_count := 0
var _invalid_drag_bounce_count := 0


func apply_projection(value: Dictionary) -> bool:
	var render_started_usec := Time.get_ticks_usec()
	if not bool(PROJECTION.validation_report(value).get("valid", false)) \
			or _bound_viewer_index < 0 or _bound_authorization_revision <= 0 \
			or int(value.get("viewer_index", -1)) != _bound_viewer_index \
			or int(value.get("authorization_revision", 0)) != _bound_authorization_revision:
		_reject_count += 1
		return false
	var next_revision := int(value.get("source_revision", -1))
	var current_revision := int(_projection.get("source_revision", -1))
	var signature := str(value.get("projection_fingerprint", ""))
	if current_revision >= 0 and next_revision < current_revision:
		_stale_count += 1
		return false
	if signature == _last_signature:
		_duplicate_count += 1
		return true
	if current_revision >= 0 and next_revision == current_revision:
		_conflict_count += 1
		return false
	_projection = PROJECTION.detached_copy(value)
	_last_signature = signature
	_render_projection()
	_record_performance_sample(_render_usec_samples, Time.get_ticks_usec() - render_started_usec)
	_apply_count += 1
	return true


func bind_viewer(viewer_index: int, authorization_revision: int) -> void:
	if viewer_index == _bound_viewer_index and authorization_revision == _bound_authorization_revision:
		return
	_bound_viewer_index = viewer_index
	_bound_authorization_revision = authorization_revision
	clear_projection()


func clear_projection() -> void:
	_projection = {}
	_selected_identity = ""
	_target_selection_identity = ""
	_target_selection_summary = ""
	_last_signature = ""
	_clear_cards()
	capacity_summary.text = "V0.6 共享容量｜0 / 5"
	bound_title.text = "绑定行动 0｜不占上限"
	normal_title.text = "普通牌 0"
	commodity_title.text = "商品牌 0"
	feedback.clear_feedback()


func set_action_feedback(action_id: String, state: String, detail: String) -> void:
	feedback.apply_feedback(
		action_id,
		state,
		detail,
		maxi(0, int(_projection.get("source_revision", 0)))
	)


func clear_action_feedback() -> void:
	feedback.clear_feedback()


func begin_target_selection(identity: String, target_summary: String) -> bool:
	var row := _row_by_identity(&"commodity_cards", identity)
	if row.is_empty() or target_summary.is_empty() \
			or str(row.get("legal_target_summary", "")) != target_summary:
		return false
	_target_selection_identity = identity
	_target_selection_summary = target_summary
	feedback.apply_feedback(
		"commodity-target-selection",
		"pending",
		"目标模式｜请选择星球区域；核心只接受唯一匹配的同产业工厂或市场。",
		maxi(0, int(row.get("source_revision", 0)))
	)
	return true


func cancel_target_selection(clear_feedback := false) -> void:
	_target_selection_identity = ""
	_target_selection_summary = ""
	if clear_feedback:
		feedback.clear_feedback()


func target_selection_active() -> bool:
	return not _target_selection_identity.is_empty()


func submit_target_selection(region_id: String) -> String:
	if region_id.is_empty() or not target_selection_active():
		return "invalid"
	var row := _row_by_identity(&"commodity_cards", _target_selection_identity)
	if row.is_empty() or str(row.get("legal_target_summary", "")) != _target_selection_summary:
		cancel_target_selection()
		return "invalid"
	var offer: Dictionary = row.get("game_action_offer", {}) as Dictionary
	if not bool(OFFER.validation_report(offer).get("valid", false)):
		return "waiting"
	var targets := OFFER.target_ids(offer)
	if str(targets.get("region_id", "")) != region_id:
		return "waiting"
	if str(offer.get("legality_state", "disabled")) != "available" \
			or str(row.get("play_state", "disabled")) != "available":
		feedback.apply_feedback(
			"commodity-target-selection",
			"blocked",
			"该区域没有唯一合法的同产业工厂或市场，请选择其他区域。",
			maxi(0, int(row.get("source_revision", 0)))
		)
		return "blocked"
	if not _submit_offer(&"commodity_cards", row, "human_click"):
		return "blocked"
	cancel_target_selection()
	return "submitted"


func debug_snapshot() -> Dictionary:
	return {
		"apply_count": _apply_count,
		"reject_count": _reject_count,
		"duplicate_count": _duplicate_count,
		"stale_count": _stale_count,
		"conflict_count": _conflict_count,
		"source_revision": int(_projection.get("source_revision", -1)),
		"viewer_index": _bound_viewer_index,
		"authorization_revision": _bound_authorization_revision,
		"capacity_mode": str(_projection.get("capacity_mode", "")),
		"normal_card_count": _pool_node_count(normal_cards),
		"commodity_card_count": _pool_node_count(commodity_cards),
		"bound_action_count": _pool_node_count(bound_cards),
		"visible_card_count": _visible_card_count(),
		"selected_identity": _selected_identity,
		"target_selection_active": target_selection_active(),
		"target_selection_identity": _target_selection_identity,
		"target_selection_summary": _target_selection_summary,
		"action_entry_count": 1,
		"hover_scale": HOVER_SCALE,
		"hover_lift_pixels": HOVER_LIFT_PIXELS,
		"hover_duration_ms": int(HOVER_DURATION_SECONDS * 1000.0),
		"drag_deadzone_pixels": DRAG_DEADZONE_PIXELS,
		"drag_lift_duration_ms": int(DRAG_LIFT_DURATION_SECONDS * 1000.0),
		"drag_max_tilt_degrees": rad_to_deg(DRAG_MAX_TILT_RADIANS),
		"local_reorder_count": _local_reorder_count,
		"invalid_drag_bounce_count": _invalid_drag_bounce_count,
		"commodity_inventory_render_p95_ms": _p95_milliseconds(_render_usec_samples),
		"commodity_inventory_render_sample_count": _render_usec_samples.size(),
		"mutates_gameplay": false,
		"reads_world_state": false,
	}


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


func _render_projection() -> void:
	var normal: Array = _projection.get("normal_cards", []) as Array
	var commodities: Array = _projection.get("commodity_cards", []) as Array
	var bound: Array = _projection.get("bound_actions", []) as Array
	bound_title.text = "绑定行动 %d｜不占上限" % bound.size()
	normal_title.text = "普通牌 %d" % normal.size()
	commodity_title.text = "商品牌 %d" % commodities.size()
	if str(_projection.get("capacity_mode", "")) == PROJECTION.CAPACITY_MODE_SHARED_V06:
		capacity_summary.text = "当前 V0.6 共享容量｜%d / %d" % [
			int(_projection.get("shared_capacity_count", 0)),
			int(_projection.get("shared_capacity_limit", 5)),
		]
	else:
		capacity_summary.text = "独立容量｜普通 %d / %d · 商品 %d / %d" % [
			normal.size(), int(_projection.get("normal_limit", 5)),
			commodities.size(), int(_projection.get("commodity_limit", 5)),
		]
	_render_pool(&"bound_actions", bound, bound_cards)
	_render_pool(&"normal_cards", normal, normal_cards)
	_render_pool(&"commodity_cards", commodities, commodity_cards)
	_refresh_card_node_cache()
	if not _identity_exists(_selected_identity):
		_selected_identity = ""
		feedback.clear_feedback()
	if not _identity_exists(_target_selection_identity):
		cancel_target_selection()


func _render_pool(pool_id: StringName, rows: Array, host: HBoxContainer) -> void:
	var desired: Dictionary = {}
	var ordered_rows := _rows_in_local_order(pool_id, rows)
	for index in range(ordered_rows.size()):
		var row_variant: Variant = ordered_rows[index]
		var row := row_variant as Dictionary
		var identity := _card_identity(pool_id, row)
		if identity.is_empty():
			continue
		desired[identity] = true
		var card := _card_node_by_identity.get(identity) as Control
		if card == null or not is_instance_valid(card) or card.get_parent() != host:
			card = _create_card_node(pool_id, identity)
			host.add_child(card)
			_card_node_by_identity[identity] = card
		card.set_meta("player_card_dock_row", row.duplicate(true))
		var card_data := _card_face_data(pool_id, row)
		if card.has_method("set_card_data"):
			card.call("set_card_data", card_data)
		if card.has_method("set_interaction_state"):
			card.call("set_interaction_state", {
				"selected": identity == _selected_identity,
				"disabled": not _card_available(pool_id, row),
			})
		host.move_child(card, mini(index, host.get_child_count() - 1))
	for child in host.get_children():
		var control := child as Control
		var identity := str(control.get_meta("player_card_dock_identity", "")) if control != null else ""
		if identity.is_empty() or desired.has(identity):
			continue
		if _card_node_by_identity.get(identity) == control:
			_card_node_by_identity.erase(identity)
		host.remove_child(child)
		child.queue_free()


func _create_card_node(pool_id: StringName, identity: String) -> Control:
	var card := CARD_FACE_SCENE.instantiate() as Control
	card.custom_minimum_size = Vector2(104, 100)
	card.focus_mode = Control.FOCUS_ALL
	card.set_meta("player_card_dock_pool", pool_id)
	card.set_meta("player_card_dock_identity", identity)
	card.set_meta("commercial_hovered", false)
	card.set_meta("commercial_focused", false)
	card.set_meta("commercial_dragging", false)
	if card.has_signal("card_clicked"):
		card.connect("card_clicked", _on_card_clicked.bind(pool_id, card))
	if card.has_signal("card_double_clicked"):
		card.connect("card_double_clicked", _on_card_double_clicked.bind(pool_id, card))
	card.mouse_entered.connect(_on_card_hovered.bind(pool_id, card))
	card.mouse_exited.connect(_on_card_unhovered.bind(pool_id, card))
	card.focus_entered.connect(_on_card_focus_entered.bind(pool_id, card))
	card.focus_exited.connect(_on_card_focus_exited.bind(pool_id, card))
	card.gui_input.connect(_on_card_gui_input.bind(pool_id, card))
	card.resized.connect(_sync_card_pivot.bind(card))
	call_deferred("_sync_card_rest_position", card)
	return card


func _card_face_data(pool_id: StringName, row: Dictionary) -> Dictionary:
	var offer: Dictionary = row.get("game_action_offer", {}) as Dictionary
	var identity := _card_identity(pool_id, row)
	var display_name := str(row.get("display_name", "卡牌"))
	var rank := int(row.get("rank", row.get("level", 1)))
	var category := str(row.get("category_id", row.get("color_id", row.get("action_class", "行动"))))
	var effect := _card_detail(pool_id, row)
	return {
		"id": identity,
		"name": display_name,
		"illustration_key": str(row.get("illustration_key", "")),
		"type": category,
		"kind": category,
		"rank": maxi(1, rank),
		"stats": "L%d" % maxi(1, rank) if pool_id == &"commodity_cards" else str(maxi(1, rank)),
		"effect": effect,
		"summary": effect,
		"presentation": "dock_mini",
		"card_frame_key": _frame_key_for_pool(pool_id),
		"play_state": "available" if _card_available(pool_id, row) else "disabled",
		"block_reason": str(row.get(
			"disabled_reason_text",
			row.get("disabled_reason_id", "action-disabled")
		)),
		"actionable": _card_available(pool_id, row),
		"pool_id": str(pool_id),
		"legal_target_summary": str(row.get("legal_target_summary", "")),
		"source_revision": int(row.get("source_revision", 0)),
		"game_action_offer": offer.duplicate(true),
		"actions": [{
			"id": str(offer.get("semantic_action_id", "")),
			"label": "使用",
			"disabled": not _card_available(pool_id, row),
			"game_action_offer": offer.duplicate(true),
		}],
	}


func _on_card_clicked(_face_data: Dictionary, pool_id: StringName, card: Control) -> void:
	var row := _row_for_card(card)
	if row.is_empty():
		return
	var identity := _card_identity(pool_id, row)
	if identity == _selected_identity:
		_selected_identity = ""
		if identity == _target_selection_identity:
			cancel_target_selection()
		card_unselected.emit(_card_face_data(pool_id, row))
		_request_presentation_audio("ui.cancel")
		feedback.clear_feedback()
	else:
		if pool_id != &"commodity_cards":
			cancel_target_selection()
		_selected_identity = identity
		var data := _card_face_data(pool_id, row)
		card_selected.emit(data)
		_request_presentation_audio("card.select")
		feedback.show_card_snapshot(pool_id, row)
	_sync_selection_visuals()


func _on_card_double_clicked(_face_data: Dictionary, pool_id: StringName, card: Control) -> void:
	var row := _row_for_card(card)
	if row.is_empty():
		return
	if _requires_scene_target_selection(pool_id, row):
		_request_scene_target_selection(pool_id, row)
		return
	_on_card_clicked({}, pool_id, card)
	_submit_offer(pool_id, row, "human_click")


func _on_card_hovered(pool_id: StringName, card: Control) -> void:
	var row := _row_for_card(card)
	if row.is_empty():
		return
	card.set_meta("commercial_hovered", true)
	_apply_card_interaction_state(pool_id, card, row)
	if not bool(card.get_meta("commercial_dragging", false)):
		_animate_card(card, true, false)
	var data := _card_face_data(pool_id, row)
	card_hovered.emit(data)
	_request_presentation_audio("ui.hover")
	feedback.show_card_snapshot(pool_id, row)


func _on_card_unhovered(pool_id: StringName, card: Control) -> void:
	card.set_meta("commercial_hovered", false)
	var row := _row_for_card(card)
	_apply_card_interaction_state(pool_id, card, row)
	if not bool(card.get_meta("commercial_dragging", false)) \
			and not bool(card.get_meta("commercial_focused", false)):
		_animate_card(card, false, false)
	card_unhovered.emit()
	if _selected_identity.is_empty():
		feedback.clear_feedback()


func _on_card_focus_entered(pool_id: StringName, card: Control) -> void:
	card.set_meta("commercial_focused", true)
	_apply_card_interaction_state(pool_id, card, _row_for_card(card))
	if not bool(card.get_meta("commercial_dragging", false)):
		_animate_card(card, true, false)
	_request_presentation_audio("ui.hover")


func _on_card_focus_exited(pool_id: StringName, card: Control) -> void:
	card.set_meta("commercial_focused", false)
	_apply_card_interaction_state(pool_id, card, _row_for_card(card))
	if not bool(card.get_meta("commercial_dragging", false)) \
			and not bool(card.get_meta("commercial_hovered", false)):
		_animate_card(card, false, false)


func _on_card_gui_input(event: InputEvent, pool_id: StringName, card: Control) -> void:
	var row := _row_for_card(card)
	if row.is_empty() or event == null:
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_begin_pointer_interaction(pool_id, card, mouse_button.global_position)
			else:
				_finish_pointer_interaction(mouse_button.global_position)
			return
	if event is InputEventMouseMotion and _pointer_card == card:
		_update_pointer_interaction((event as InputEventMouseMotion).global_position)
		return
	if not event.is_action_pressed("ui_accept"):
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.echo:
		return
	var identity := _card_identity(pool_id, row)
	if identity.is_empty():
		return
	if identity == _selected_identity:
		if _requires_scene_target_selection(pool_id, row):
			_request_scene_target_selection(pool_id, row)
		elif _card_available(pool_id, row):
			_submit_offer(pool_id, row, "human_click")
	else:
		_on_card_clicked({}, pool_id, card)
	get_viewport().set_input_as_handled()


func _requires_scene_target_selection(pool_id: StringName, row: Dictionary) -> bool:
	return pool_id == &"commodity_cards" \
		and not str(row.get("legal_target_summary", "")).is_empty()


func _request_scene_target_selection(pool_id: StringName, row: Dictionary) -> void:
	var identity := _card_identity(pool_id, row)
	if identity.is_empty():
		feedback.show_card_snapshot(pool_id, row)
		return
	var data := _card_face_data(pool_id, row)
	if identity != _selected_identity:
		_selected_identity = identity
		card_selected.emit(data)
	card_target_selection_requested.emit(data)
	_sync_selection_visuals()


func _submit_offer(pool_id: StringName, row: Dictionary, submission_kind: String) -> bool:
	if not _card_available(pool_id, row):
		feedback.show_card_snapshot(pool_id, row)
		return false
	var offer: Dictionary = row.get("game_action_offer", {}) as Dictionary
	if not bool(OFFER.validation_report(offer).get("valid", false)):
		return false
	game_action_offer_requested.emit(offer.duplicate(true), submission_kind, {}, {})
	feedback.apply_feedback(
		str(offer.get("semantic_action_id", "card-action")),
		"pending",
		"已提交到正式行动入口，等待权威回执。",
		int(row.get("source_revision", 0))
	)
	return true


func _sync_selection_visuals() -> void:
	for card in _card_nodes:
		if card != null:
			var pool_id := StringName(str(card.get_meta("player_card_dock_pool", "")))
			var row := _row_for_card(card)
			_apply_card_interaction_state(pool_id, card, row)


func _card_available(pool_id: StringName, row: Dictionary) -> bool:
	return bool(row.get("enabled", false)) if pool_id == &"bound_actions" \
		else str(row.get("play_state", "disabled")) == "available"


func _card_identity(pool_id: StringName, row: Dictionary) -> String:
	match pool_id:
		&"normal_cards":
			return str(row.get("card_instance_id", ""))
		&"commodity_cards":
			return str(row.get("commodity_card_instance_id", ""))
		&"bound_actions":
			return str(row.get("bound_action_instance_id", ""))
	return ""


func _card_detail(pool_id: StringName, row: Dictionary) -> String:
	if not _card_available(pool_id, row):
		return "暂不可用｜%s" % str(row.get(
			"disabled_reason_text",
			row.get("disabled_reason_id", "action-disabled")
		))
	if pool_id == &"commodity_cards":
		return "%s · L%d｜%s" % [
			str(row.get("color_id", "商品")),
			int(row.get("level", 1)),
			str(row.get("legal_target_summary", "选择合法设施或市场")),
		]
	if pool_id == &"bound_actions":
		return "%s来源｜冷却 %d｜次数 %s" % [
			str(row.get("source_entity_kind", "实体")),
			int(row.get("cooldown", 0)),
			"不限" if int(row.get("charges", -1)) < 0 else str(row.get("charges", 0)),
		]
	return "通过正式行动入口使用"


func _identity_exists(identity: String) -> bool:
	if identity.is_empty():
		return false
	for key in ["normal_cards", "commodity_cards", "bound_actions"]:
		for row_variant in _projection.get(key, []) as Array:
			if _card_identity(StringName(key), row_variant as Dictionary) == identity:
				return true
	return false


func _visible_card_count() -> int:
	var count := 0
	for card in _card_nodes:
		if card != null and card.is_visible_in_tree():
			count += 1
	return count


func _pool_node_count(host: HBoxContainer) -> int:
	return host.get_child_count() if host != null else 0


func _clear_cards() -> void:
	_cancel_pointer_interaction()
	for tween_variant in _visual_tweens.values():
		var tween := tween_variant as Tween
		if tween != null and tween.is_valid():
			tween.kill()
	_visual_tweens.clear()
	_card_nodes.clear()
	_card_node_by_identity.clear()
	for host in [bound_cards, normal_cards, commodity_cards]:
		for child in host.get_children():
			host.remove_child(child)
			child.queue_free()


func _row_for_card(card: Control) -> Dictionary:
	return (card.get_meta("player_card_dock_row", {}) as Dictionary).duplicate(true) \
		if card != null and card.get_meta("player_card_dock_row", {}) is Dictionary else {}


func _row_by_identity(pool_id: StringName, identity: String) -> Dictionary:
	if identity.is_empty():
		return {}
	for row_variant in _projection.get(str(pool_id), []) as Array:
		if row_variant is Dictionary \
				and _card_identity(pool_id, row_variant as Dictionary) == identity:
			return (row_variant as Dictionary).duplicate(true)
	return {}


func _refresh_card_node_cache() -> void:
	_card_nodes.clear()
	for host in [bound_cards, normal_cards, commodity_cards]:
		for child in host.get_children():
			if child is Control:
				_card_nodes.append(child as Control)


func _frame_key_for_pool(pool_id: StringName) -> String:
	match pool_id:
		&"normal_cards":
			return "card.frame.normal"
		&"commodity_cards":
			return "card.frame.commodity"
		&"bound_actions":
			return "card.frame.bound_action"
	return ""


func _rows_in_local_order(pool_id: StringName, rows: Array) -> Array:
	var row_by_identity: Dictionary = {}
	var projection_order: Array[String] = []
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		var identity := _card_identity(pool_id, row)
		if identity.is_empty():
			continue
		row_by_identity[identity] = row
		projection_order.append(identity)
	var result: Array = []
	var resolved_order: Array[String] = []
	var stored_order: Array = _local_order_by_pool.get(str(pool_id), []) as Array
	for identity_variant in stored_order:
		var identity := str(identity_variant)
		if not row_by_identity.has(identity):
			continue
		result.append(row_by_identity[identity])
		resolved_order.append(identity)
		row_by_identity.erase(identity)
	for identity in projection_order:
		if not row_by_identity.has(identity):
			continue
		result.append(row_by_identity[identity])
		resolved_order.append(identity)
	_local_order_by_pool[str(pool_id)] = resolved_order
	return result


func _begin_pointer_interaction(pool_id: StringName, card: Control, global_position: Vector2) -> void:
	_cancel_pointer_interaction()
	_pointer_card = card
	_pointer_pool_id = pool_id
	_pointer_press_global_position = global_position
	_pointer_origin_index = card.get_index()
	_pointer_dragging = false
	card.set_meta("commercial_pressed", true)
	_apply_card_interaction_state(pool_id, card, _row_for_card(card))


func _update_pointer_interaction(global_position: Vector2) -> void:
	if _pointer_card == null or not is_instance_valid(_pointer_card):
		_cancel_pointer_interaction()
		return
	var delta := global_position - _pointer_press_global_position
	if not _pointer_dragging and delta.length() < DRAG_DEADZONE_PIXELS:
		return
	if not _pointer_dragging:
		_pointer_dragging = true
		_pointer_card.set_meta("commercial_pressed", false)
		_pointer_card.set_meta("commercial_dragging", true)
		_sync_card_rest_position(_pointer_card)
		_animate_card(_pointer_card, true, true)
		_request_presentation_audio("card.drag_start")
	_apply_card_interaction_state(_pointer_pool_id, _pointer_card, _row_for_card(_pointer_card))
	_pointer_card.rotation = clampf(
		delta.x / 180.0 * DRAG_MAX_TILT_RADIANS,
		-DRAG_MAX_TILT_RADIANS,
		DRAG_MAX_TILT_RADIANS
	)
	var host := _pointer_card.get_parent() as HBoxContainer
	if host == null or not host.get_global_rect().grow(12.0).has_point(global_position):
		return
	var target_index := _child_index_for_global_x(host, global_position.x)
	if target_index != _pointer_card.get_index():
		host.move_child(_pointer_card, target_index)
		_capture_host_order(_pointer_pool_id, host)


func _finish_pointer_interaction(global_position: Vector2) -> void:
	if _pointer_card == null or not is_instance_valid(_pointer_card):
		_cancel_pointer_interaction()
		return
	var card := _pointer_card
	var pool_id := _pointer_pool_id
	var host := card.get_parent() as HBoxContainer
	var valid_local_drop := _pointer_dragging and host != null \
		and host.get_global_rect().grow(12.0).has_point(global_position)
	if _pointer_dragging and valid_local_drop:
		_capture_host_order(pool_id, host)
		_local_reorder_count += 1
		_request_presentation_audio("card.drop")
	elif _pointer_dragging:
		if host != null and _pointer_origin_index >= 0:
			host.move_child(card, mini(_pointer_origin_index, host.get_child_count() - 1))
			_capture_host_order(pool_id, host)
		_invalid_drag_bounce_count += 1
		_request_presentation_audio("ui.cancel")
	card.set_meta("commercial_pressed", false)
	card.set_meta("commercial_dragging", false)
	card.set_meta("commercial_drop_invalid", _pointer_dragging and not valid_local_drop)
	_apply_card_interaction_state(pool_id, card, _row_for_card(card))
	_pointer_card = null
	_pointer_pool_id = StringName()
	_pointer_origin_index = -1
	_pointer_dragging = false
	call_deferred("_settle_card_after_layout", card, pool_id)


func _cancel_pointer_interaction() -> void:
	if _pointer_card != null and is_instance_valid(_pointer_card):
		_pointer_card.set_meta("commercial_pressed", false)
		_pointer_card.set_meta("commercial_dragging", false)
		_pointer_card.set_meta("commercial_drop_invalid", false)
	_pointer_card = null
	_pointer_pool_id = StringName()
	_pointer_origin_index = -1
	_pointer_dragging = false


func _settle_card_after_layout(card: Control, pool_id: StringName) -> void:
	if card == null or not is_instance_valid(card):
		return
	_sync_card_rest_position(card)
	card.set_meta("commercial_drop_invalid", false)
	_apply_card_interaction_state(pool_id, card, _row_for_card(card))
	var elevated := bool(card.get_meta("commercial_hovered", false)) \
		or bool(card.get_meta("commercial_focused", false))
	_animate_card(card, elevated, false)


func _request_presentation_audio(event_id: String) -> void:
	presentation_audio_event_requested.emit(event_id, {"surface": "player_card_dock"})


func _child_index_for_global_x(host: HBoxContainer, global_x: float) -> int:
	var target := maxi(0, host.get_child_count() - 1)
	for index in range(host.get_child_count()):
		var sibling := host.get_child(index) as Control
		if sibling == null or sibling == _pointer_card:
			continue
		if global_x < sibling.global_position.x + sibling.size.x * 0.5:
			return index
	return target


func _capture_host_order(pool_id: StringName, host: HBoxContainer) -> void:
	var order: Array[String] = []
	for child in host.get_children():
		if child is Control:
			var identity := str((child as Control).get_meta("player_card_dock_identity", ""))
			if not identity.is_empty():
				order.append(identity)
	_local_order_by_pool[str(pool_id)] = order


func _apply_card_interaction_state(pool_id: StringName, card: Control, row: Dictionary) -> void:
	if card == null or not card.has_method("set_interaction_state"):
		return
	var identity := str(card.get_meta("player_card_dock_identity", ""))
	card.call("set_interaction_state", {
		"hovered": bool(card.get_meta("commercial_hovered", false)) \
			or bool(card.get_meta("commercial_focused", false)),
		"selected": identity == _selected_identity,
		"dragging": bool(card.get_meta("commercial_dragging", false)),
		"pressed": bool(card.get_meta("commercial_pressed", false)),
		"returning": bool(card.get_meta("commercial_drop_invalid", false)),
		"disabled": not _card_available(pool_id, row),
		"drop_valid": bool(card.get_meta("commercial_dragging", false)),
		"drop_invalid": bool(card.get_meta("commercial_drop_invalid", false)),
	})


func _sync_card_pivot(card: Control) -> void:
	if card != null and is_instance_valid(card):
		card.pivot_offset = card.size * 0.5


func _sync_card_rest_position(card: Control) -> void:
	if card == null or not is_instance_valid(card) or bool(card.get_meta("commercial_dragging", false)):
		return
	card.set_meta("commercial_rest_position", card.position)
	_sync_card_pivot(card)


func _animate_card(card: Control, elevated: bool, dragging: bool) -> void:
	if card == null or not is_instance_valid(card):
		return
	var identity := str(card.get_meta("player_card_dock_identity", str(card.get_instance_id())))
	var previous := _visual_tweens.get(identity) as Tween
	if previous != null and previous.is_valid():
		previous.kill()
	var rest_position: Vector2 = card.get_meta("commercial_rest_position", card.position) as Vector2
	var target_position := rest_position - Vector2(0.0, HOVER_LIFT_PIXELS) if elevated else rest_position
	var duration := DRAG_LIFT_DURATION_SECONDS if dragging else HOVER_DURATION_SECONDS
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE * (HOVER_SCALE if elevated else 1.0), duration)
	tween.tween_property(card, "position", target_position, duration)
	if not dragging:
		tween.tween_property(card, "rotation", 0.0, duration)
	card.z_index = 40 if dragging else (20 if elevated else 0)
	_visual_tweens[identity] = tween
