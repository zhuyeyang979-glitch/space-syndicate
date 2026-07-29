extends Control
class_name PlayerTurnMcpPreview

signal action_requested(action_id: String)

const FixturesScript = preload("res://scripts/tools/player_turn_mcp_preview_fixtures.gd")
const ContextDetailProjectionScript = preload("res://scripts/presentation/context_detail_projection_v1.gd")

@onready var state_list: ItemList = %PlayerTurnStateList
@onready var current_state_label: Label = %PlayerTurnCurrentStateLabel
@onready var status_label: Label = %PlayerTurnStatusLabel
@onready var selected_card_label: Label = %PlayerTurnSelectedCardLabel
@onready var action_summary_label: Label = %PlayerTurnActionSummaryLabel
@onready var disabled_reason_label: Label = %PlayerTurnDisabledReasonLabel
@onready var public_track: Node = %PublicTrack
@onready var player_board: Node = %PlayerBoard
@onready var selected_card_face: Control = %SelectedCardFace
@onready var context_detail_drawer: Node = %ContextDetailDrawer
@onready var last_action_label: Label = %PlayerTurnLastActionLabel

var _fixtures: RefCounted
var _current_fixture: Dictionary = {}
var _selected_id := "normal_hand"
var _context_detail_revision := 0


func _ready() -> void:
	_fixtures = FixturesScript.new()
	if context_detail_drawer != null and context_detail_drawer.has_method("bind_viewer"):
		context_detail_drawer.call("bind_viewer", 0, 1)
	_connect_state_list()
	_connect_component_signals()
	_populate_state_list()
	show_preview_id(_selected_id)


func preview_ids() -> Array[String]:
	if _fixtures == null:
		return []
	var ids_variant: Variant = _fixtures.call("preview_ids")
	var result: Array[String] = []
	if ids_variant is Array:
		for id in ids_variant:
			result.append(str(id))
	return result


func selected_preview_id() -> String:
	return _selected_id


func current_fixture() -> Dictionary:
	return _current_fixture.duplicate(true)


func show_preview_id(id: String) -> void:
	if _fixtures == null:
		return
	var data_variant: Variant = _fixtures.call("fixture", id)
	if not (data_variant is Dictionary):
		return
	var data: Dictionary = (data_variant as Dictionary).duplicate(true)
	_current_fixture = data
	_selected_id = str(data.get("id", id))
	_sync_state_list_selection()
	_apply_fixture(data)


func show_empty_hand() -> void:
	show_preview_id("empty_hand")


func show_normal_hand() -> void:
	show_preview_id("normal_hand")


func show_selected_enabled_card() -> void:
	show_preview_id("selected_enabled_card")


func show_selected_disabled_card() -> void:
	show_preview_id("selected_disabled_card")


func show_hovered_card() -> void:
	show_preview_id("hovered_card")


func show_drag_preview() -> void:
	show_preview_id("drag_preview")


func show_context_detail_card() -> void:
	show_preview_id("context_detail_card")


func show_public_track_selection() -> void:
	show_preview_id("public_track_selection")


func show_temporary_decision_pending_hint() -> void:
	show_preview_id("temporary_decision_pending_hint")


func _connect_state_list() -> void:
	if state_list == null:
		return
	var callback := Callable(self, "_on_state_selected")
	if not state_list.item_selected.is_connected(callback):
		state_list.item_selected.connect(callback)


func _connect_component_signals() -> void:
	for node in [player_board]:
		if node == null:
			continue
		if node.has_signal("action_requested"):
			var action_callback := Callable(self, "_on_action_requested")
			if not node.is_connected("action_requested", action_callback):
				node.connect("action_requested", action_callback)
	if player_board != null and player_board.has_signal("card_selected"):
		var card_callback := Callable(self, "_on_card_selected")
		if not player_board.is_connected("card_selected", card_callback):
			player_board.connect("card_selected", card_callback)


func _populate_state_list() -> void:
	if state_list == null or _fixtures == null:
		return
	state_list.clear()
	for id in preview_ids():
		state_list.add_item(str(_fixtures.call("preview_label", id)))
		state_list.set_item_metadata(state_list.item_count - 1, id)


func _sync_state_list_selection() -> void:
	if state_list == null:
		return
	for index in range(state_list.item_count):
		if str(state_list.get_item_metadata(index)) == _selected_id:
			state_list.select(index)
			return


func _apply_fixture(data: Dictionary) -> void:
	var player_state: Dictionary = data.get("player_state", {}) if data.get("player_state", {}) is Dictionary else {}
	var selected_card: Dictionary = data.get("selected_card", {}) if data.get("selected_card", {}) is Dictionary else {}
	var public_entries: Array = data.get("public_track", []) if data.get("public_track", []) is Array else []
	var context_detail: Dictionary = data.get("context_detail", {}) if data.get("context_detail", {}) is Dictionary else {}
	if player_board != null and player_board.has_method("set_player_state"):
		player_board.call("set_player_state", player_state)
	if public_track != null and public_track.has_method("set_entries"):
		public_track.call("set_entries", public_entries)
	_apply_selected_card_face(selected_card, str(data.get("hand_focus", "none")))
	_apply_context_detail(data, selected_card, context_detail)
	_apply_labels(data, player_state, selected_card)
	_apply_hand_focus(data)


func _apply_selected_card_face(card: Dictionary, hand_focus: String) -> void:
	if selected_card_face == null:
		return
	selected_card_face.visible = not card.is_empty()
	if card.is_empty():
		return
	var display_data := card.duplicate(true)
	display_data["presentation"] = "inspector_full"
	if selected_card_face.has_method("set_card_data"):
		selected_card_face.call("set_card_data", display_data)
	if selected_card_face.has_method("set_interaction_state"):
		selected_card_face.call("set_interaction_state", {
			"hovered": hand_focus == "hovered",
			"selected": hand_focus in ["selected", "drag_invalid"],
			"dragging": hand_focus == "drag_invalid",
			"drop_valid": hand_focus != "drag_invalid",
			"drop_invalid": hand_focus == "drag_invalid",
		})


func _apply_context_detail(data: Dictionary, selected_card: Dictionary, fallback_context: Dictionary) -> void:
	if context_detail_drawer == null or not context_detail_drawer.has_method("apply_projection"):
		return
	_context_detail_revision += 1
	var projection := _build_context_detail_projection(data, selected_card, fallback_context)
	if not projection.is_empty():
		context_detail_drawer.call("apply_projection", projection)


func _build_context_detail_projection(
	data: Dictionary,
	selected_card: Dictionary,
	fallback_context: Dictionary
) -> Dictionary:
	if str(data.get("context_detail_mode", "context")) == "card" and not selected_card.is_empty():
		return _normal_card_projection(selected_card)
	if str(data.get("id", "")) == "public_track_selection":
		return _public_track_projection(fallback_context)
	return _region_context_projection(fallback_context)


func _normal_card_projection(card: Dictionary) -> Dictionary:
	var card_id := str(card.get("id", card.get("card_id", "preview_card")))
	var disabled_reason := str(card.get("disabled_reason", ""))
	return ContextDetailProjectionScript.build({
		"schema_version": ContextDetailProjectionScript.SCHEMA_VERSION,
		"viewer_index": 0,
		"authorization_revision": 1,
		"source_revision": _context_detail_revision,
		"context_id": card_id,
		"context_kind": ContextDetailProjectionScript.KIND_NORMAL_CARD,
		"visibility_scope": "viewer_private",
		"title": str(card.get("name", "卡牌详情")),
		"subtitle": str(card.get("use_case", "")),
		"content": {
			"card_instance_id": card_id,
			"card_semantic_id": card_id,
			"display_name": str(card.get("name", "预览卡牌")),
			"illustration_key": str(card.get("illustration_key", "preview_card")),
			"timing_text": str(card.get("requirement", "")),
			"target_text": str(card.get("target", "")),
			"effect_text": str(card.get("effect", "")),
			"duration_text": str(card.get("duration", "单次结算")),
			"visibility_text": "仅当前查看者",
			"keyword_tokens": ["preview"],
			"disabled_reason_id": "preview_blocked" if not disabled_reason.is_empty() else "none",
			"disabled_reason_text": disabled_reason,
		},
		"navigation_intents": [],
	})


func _region_context_projection(context: Dictionary) -> Dictionary:
	var district: Dictionary = context.get("district", {}) if context.get("district", {}) is Dictionary else {}
	return ContextDetailProjectionScript.build({
		"schema_version": ContextDetailProjectionScript.SCHEMA_VERSION,
		"viewer_index": 0,
		"authorization_revision": 1,
		"source_revision": _context_detail_revision,
		"context_id": "preview_region_facility",
		"context_kind": ContextDetailProjectionScript.KIND_REGION_FACILITY,
		"visibility_scope": "public",
		"title": str(district.get("title", "当前选区")),
		"subtitle": str(context.get("why", "")),
		"content": {
			"facility_id": "preview_facility",
			"region_id": "preview_region",
			"display_name": str(district.get("title", "当前选区")),
			"illustration_key": "preview_region",
			"public_status": "preview_only",
			"summary": str(district.get("summary", "桌边上下文预览。")),
			"detail": str(district.get("full_detail", "只读详情，不调用规则函数。")),
		},
		"navigation_intents": [],
	})


func _public_track_projection(context: Dictionary) -> Dictionary:
	var district: Dictionary = context.get("district", {}) if context.get("district", {}) is Dictionary else {}
	return ContextDetailProjectionScript.build({
		"schema_version": ContextDetailProjectionScript.SCHEMA_VERSION,
		"viewer_index": 0,
		"authorization_revision": 1,
		"source_revision": _context_detail_revision,
		"context_id": "preview_public_track",
		"context_kind": ContextDetailProjectionScript.KIND_PUBLIC_TRACK,
		"visibility_scope": "public",
		"title": str(district.get("title", "公共轨道")),
		"subtitle": str(context.get("why", "")),
		"content": {
			"resolution_id": "preview_resolution",
			"card_semantic_id": "preview_public_card",
			"display_name": str(district.get("title", "公共轨道")),
			"illustration_key": "preview_public_track",
			"public_status": "preview_only",
			"summary": str(district.get("summary", "公开线索预览。")),
			"detail": str(district.get("full_detail", "只展示公开信息。")),
			"keyword_tokens": ["preview", "public"],
		},
		"navigation_intents": [],
	})


func _apply_labels(data: Dictionary, player_state: Dictionary, selected_card: Dictionary) -> void:
	if current_state_label != null:
		current_state_label.text = "State: %s" % str(data.get("label", data.get("id", "")))
	if status_label != null:
		status_label.text = str(data.get("status", ""))
	if selected_card_label != null:
		selected_card_label.text = "Selected: %s" % (str(selected_card.get("name", "-")) if not selected_card.is_empty() else "-")
	if action_summary_label != null:
		action_summary_label.text = _action_summary(player_state, selected_card)
	if disabled_reason_label != null:
		var disabled_reason := str(data.get("disabled_reason", selected_card.get("disabled_reason", ""))).strip_edges()
		disabled_reason_label.visible = disabled_reason != ""
		disabled_reason_label.text = "Disabled: %s" % disabled_reason if disabled_reason != "" else ""


func _apply_hand_focus(data: Dictionary) -> void:
	var hand_rack := _hand_rack()
	if hand_rack == null:
		return
	if hand_rack.has_method("clear_dragged_card"):
		hand_rack.call("clear_dragged_card")
	if hand_rack.has_method("set_hovered_card"):
		hand_rack.call("set_hovered_card", null)
	var focus := str(data.get("hand_focus", "none"))
	var selected_card_id := str(data.get("selected_card_id", ""))
	if focus == "none" or selected_card_id == "":
		return
	var card := _hand_card_by_id(selected_card_id)
	if card == null:
		return
	match focus:
		"hovered":
			if hand_rack.has_method("set_hovered_card"):
				hand_rack.call("set_hovered_card", card)
		"drag_invalid":
			if hand_rack.has_method("set_dragged_card"):
				hand_rack.call("set_dragged_card", card, false)
		_:
			if hand_rack.has_method("set_selected_card"):
				hand_rack.call("set_selected_card", card)


func _hand_rack() -> Node:
	if player_board == null:
		return null
	return player_board.find_child("HandRack", true, false)


func _hand_card_by_id(card_id: String) -> Control:
	var hand_rack := _hand_rack()
	if hand_rack == null:
		return null
	for child in hand_rack.get_children():
		if not (child is Control):
			continue
		var control := child as Control
		if control.has_method("get_card_data"):
			var data_variant: Variant = control.call("get_card_data")
			var data: Dictionary = data_variant if data_variant is Dictionary else {}
			if str(data.get("id", data.get("card_id", ""))) == card_id:
				return control
	return null


func _action_summary(player_state: Dictionary, selected_card: Dictionary) -> String:
	var actions: Array = []
	if not selected_card.is_empty() and selected_card.get("actions", []) is Array:
		actions = selected_card.get("actions", [])
	elif player_state.get("actions", []) is Array:
		actions = player_state.get("actions", [])
	var enabled := 0
	var disabled := 0
	var first_enabled := "-"
	for action_variant in actions:
		var action: Dictionary = action_variant if action_variant is Dictionary else {}
		if bool(action.get("disabled", false)):
			disabled += 1
		else:
			enabled += 1
			if first_enabled == "-":
				first_enabled = str(action.get("label", action.get("id", "-")))
	return "Actions: %d enabled / %d disabled | Next: %s" % [enabled, disabled, first_enabled]


func _on_state_selected(index: int) -> void:
	if state_list == null or index < 0 or index >= state_list.item_count:
		return
	show_preview_id(str(state_list.get_item_metadata(index)))


func _on_card_selected(card_data: Dictionary) -> void:
	var updated := _current_fixture.duplicate(true)
	updated["selected_card"] = card_data.duplicate(true)
	updated["selected_card_id"] = str(card_data.get("id", card_data.get("card_id", "")))
	updated["hand_focus"] = "selected"
	updated["context_detail_mode"] = "card"
	_current_fixture = updated
	_apply_selected_card_face(card_data, "selected")
	_apply_context_detail(updated, card_data, {})
	_apply_labels(updated, updated.get("player_state", {}), card_data)


func _on_action_requested(action_id: String) -> void:
	if last_action_label != null:
		last_action_label.text = "Last action: %s" % action_id
	action_requested.emit(action_id)
