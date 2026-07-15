extends PanelContainer
class_name SpaceSyndicateCardResolutionTrack

signal track_action_requested(action_id: String)
signal card_slot_selected(slot_id: String)
signal track_entry_selected(entry: Dictionary)
signal track_entry_opened(entry: Dictionary)
signal track_entry_hovered(entry: Dictionary)
signal track_entry_unhovered(entry: Dictionary)

const CardResolutionTrackSlotScene := preload("res://scenes/ui/CardResolutionTrackSlot.tscn")
const SLOT_HEIGHT := 34.0
const SLOT_MIN_WIDTH := 146.0
const SLOT_MAX_WIDTH := 216.0
const PRIVATE_TOKENS := ["hidden_owner", "private_owner", "private_target", "owner_secret", "secret_owner", "private_discard"]
const PRIVATE_ENTRY_KEYS := [
	"hidden_owner",
	"hidden_owner_id",
	"private_owner",
	"private_target",
	"owner_secret",
	"secret_owner",
	"private_discard",
	"private_hand",
	"opponent_hand",
	"opponent_cash",
	"true_owner",
	"owner",
	"owner_id",
	"owner_index",
	"player_index",
	"viewer_index",
	"cash",
	"cash_cents",
	"exact_cash",
	"hand",
	"hand_size",
]

@export var compact_public_track := false

@onready var title_label: Label = %TrackTitleLabel
@onready var phase_label: Label = %TrackPhaseLabel
@onready var summary_label: Label = %TrackSummaryLabel
@onready var history_rail: HBoxContainer = %HistoryRail
@onready var active_resolution_slot: HBoxContainer = %ActiveResolutionSlot
@onready var queue_rail: HBoxContainer = %QueueRail
@onready var next_queue_rail: HBoxContainer = %NextQueueRail
@onready var auction_response_layer: PanelContainer = %AuctionResponseLayer
@onready var auction_response_label: Label = %AuctionResponseLabel
@onready var auction_response_action_row: HBoxContainer = %AuctionResponseActionRow
@onready var auction_response_disabled_reason_label: Label = %AuctionResponseDisabledReasonLabel
@onready var privacy_hint_layer: PanelContainer = %PrivacyHintLayer
@onready var privacy_hint_label: Label = %PrivacyHintLabel
@onready var empty_state_layer: PanelContainer = %EmptyStateLayer
@onready var empty_state_label: Label = %EmptyStateLabel
@onready var track_rows: VBoxContainer = $TrackRows
@onready var track_header: Control = %TrackHeader
@onready var history_panel: Control = $TrackRows/TrackBody/HistoryPanel
@onready var active_panel: Control = $TrackRows/TrackBody/ActivePanel
@onready var queue_panel: Control = $TrackRows/TrackBody/QueuePanel
@onready var queue_label: Label = $TrackRows/TrackBody/QueuePanel/QueueRows/QueueLabel
@onready var queue_scroll: ScrollContainer = $TrackRows/TrackBody/QueuePanel/QueueRows/QueueScroll
@onready var next_panel: Control = $TrackRows/TrackBody/NextPanel

var _track_state: Dictionary = {}
var _entries_signature := ""
var _hovered_track_action := ""
var _selected_entry_id := ""
var _selected_resolution_id := -1


func _ready() -> void:
	add_theme_stylebox_override("panel", _track_panel_style())
	_sync_density_mode()


func set_entries(entries: Array) -> void:
	set_track_state({
		"title": "公共牌轨",
		"phase": _phase_from_entries(entries),
		"summary": "匿名出牌、竞价、当前展示和历史线索都在这里。",
		"entries": entries,
		"privacy_hint": "归属未公开前只显示待猜线索。",
	})


func set_track_state(data: Dictionary) -> void:
	var state := _sanitize_state(data)
	var next_signature := var_to_str(state)
	if next_signature == _entries_signature:
		return
	_entries_signature = next_signature
	_track_state = state
	_sync_selected_identity_from_state()
	_sync_header()
	_sync_layers()
	_sync_rails()
	_sync_density_mode()


func set_hovered_track_action(action_id: String) -> void:
	var normalized := action_id.strip_edges()
	if normalized == _hovered_track_action:
		return
	_hovered_track_action = normalized
	_sync_hovered_slots()


func get_debug_snapshot() -> Dictionary:
	return {
		"title": title_label.text if title_label != null else "",
		"phase": phase_label.text if phase_label != null else "",
		"entry_count": _all_entries().size(),
		"history_count": history_rail.get_child_count() if history_rail != null else 0,
		"active_count": active_resolution_slot.get_child_count() if active_resolution_slot != null else 0,
		"queue_count": queue_rail.get_child_count() if queue_rail != null else 0,
		"next_count": next_queue_rail.get_child_count() if next_queue_rail != null else 0,
		"auction_visible": auction_response_layer != null and auction_response_layer.visible,
		"privacy_visible": privacy_hint_layer != null and privacy_hint_layer.visible,
		"empty_visible": empty_state_layer != null and empty_state_layer.visible,
		"has_private_text": _contains_private_text(self),
		"exposes_sceneized_resolution_track": true,
		"selected_entry_id": _selected_entry_id,
		"selected_resolution_id": _selected_resolution_id,
		"selected_slot_ids": _selected_slot_ids(),
		"response_action_count": auction_response_action_row.get_child_count() if auction_response_action_row != null else 0,
		"disabled_reason_visible": auction_response_disabled_reason_label != null and auction_response_disabled_reason_label.visible,
	}


func _sync_header() -> void:
	if title_label != null:
		title_label.text = str(_track_state.get("title", "公共牌轨"))
	if phase_label != null:
		phase_label.text = str(_track_state.get("phase", "等待"))
	if summary_label != null:
		summary_label.text = str(_track_state.get("summary", "等待玩家出牌。"))


func _sync_layers() -> void:
	var auction: Dictionary = _track_state.get("auction_response", {}) if _track_state.get("auction_response", {}) is Dictionary else {}
	var auction_visible := bool(auction.get("active", false)) or bool(_track_state.get("auction_open", false)) or str(_track_state.get("phase", "")).contains("竞")
	if auction_response_layer != null:
		auction_response_layer.visible = auction_visible
	if auction_response_label != null:
		auction_response_label.text = str(auction.get("summary", "竞价/响应窗口开启，公开报价会影响结算顺序。"))
	_sync_response_actions(auction)
	var privacy_text := str(_track_state.get("privacy_hint", "匿名来源只显示公开线索，不显示隐藏归属。"))
	if privacy_hint_layer != null:
		privacy_hint_layer.visible = privacy_text.strip_edges() != ""
	if privacy_hint_label != null:
		privacy_hint_label.text = privacy_text
	var empty_visible := _all_entries().is_empty()
	if empty_state_layer != null:
		empty_state_layer.visible = empty_visible
	if empty_state_label != null:
		empty_state_label.text = str(_track_state.get("empty_text", "牌轨空闲，等待玩家出牌。"))


func _sync_rails() -> void:
	_clear_container(history_rail)
	_clear_container(active_resolution_slot)
	_clear_container(queue_rail)
	_clear_container(next_queue_rail)
	if _is_compact_public_track():
		var compact_entries := _all_entries()
		_add_entries(queue_rail, compact_entries, "queue")
		if compact_entries.is_empty():
			_add_ghost_slot(queue_rail)
		return
	var groups := _grouped_entries()
	_add_entries(history_rail, groups.get("history", []), "history")
	_add_entries(active_resolution_slot, groups.get("active", []), "active")
	_add_entries(queue_rail, groups.get("queue", []), "queue")
	_add_entries(next_queue_rail, groups.get("next", []), "next")
	if _all_entries().is_empty():
		_add_ghost_slot(queue_rail)


func _grouped_entries() -> Dictionary:
	var grouped := {"history": [], "active": [], "queue": [], "next": []}
	for entry_variant in _all_entries():
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var lane := _entry_lane(entry)
		(grouped[lane] as Array).append(entry)
	return grouped


func _all_entries() -> Array:
	var entries: Array = _track_state.get("entries", []) if _track_state.get("entries", []) is Array else []
	if not entries.is_empty():
		return entries
	var result: Array = []
	for key in ["history_entries", "active_entries", "queue_entries", "next_entries"]:
		var lane_entries: Array = _track_state.get(key, []) if _track_state.get(key, []) is Array else []
		result.append_array(lane_entries)
	return result


func _add_entries(parent: Container, entries: Array, lane: String) -> void:
	if parent == null:
		return
	for index in range(entries.size()):
		var entry: Dictionary = entries[index] if entries[index] is Dictionary else {}
		_add_slot(parent, entry, index, lane)


func _add_slot(parent: Container, entry: Dictionary, index: int, lane: String) -> void:
	var slot := CardResolutionTrackSlotScene.instantiate() as Control
	if slot == null:
		return
	parent.add_child(slot)
	var slot_entry := entry.duplicate(true)
	if not slot_entry.has("slot"):
		slot_entry["slot"] = _slot_label(lane, index)
	if not slot_entry.has("active"):
		slot_entry["active"] = lane == "active" or (lane == "queue" and index == 0)
	if _entry_matches_selected_identity(slot_entry):
		slot_entry["selected"] = true
	var options := {
		"hovered_action": _hovered_track_action,
		"slot_width": _slot_width(slot_entry, lane),
		"slot_height": SLOT_HEIGHT,
		"compact": _is_compact_public_track(),
	}
	if slot.has_method("configure"):
		slot.call("configure", slot_entry, index, options)
	_configure_slot_pointer_input(slot)
	if _is_compact_public_track() and index == 0:
		slot.name = "PublicTrackSlot"
	else:
		slot.name = "CardResolutionTrackSlot_%s_%02d" % [lane.capitalize(), index + 1]
	_connect_slot(slot)


func _add_ghost_slot(parent: Container) -> void:
	if parent == null:
		return
	_add_slot(parent, {
		"id": "empty_track",
		"label": "等待出牌",
		"state": "空闲",
		"owner_hint": "待猜",
		"tooltip": "当前没有正在结算或等待结算的公开牌。",
		"disabled": true,
		"accent": "#64748b",
	}, 0, "queue")


func _connect_slot(slot: Node) -> void:
	if slot.has_signal("entry_selected"):
		slot.connect("entry_selected", Callable(self, "_on_slot_selected"))
	if slot.has_signal("entry_opened"):
		slot.connect("entry_opened", Callable(self, "_on_slot_opened"))
	if slot.has_signal("entry_hovered"):
		slot.connect("entry_hovered", Callable(self, "_on_slot_hovered"))
	if slot.has_signal("entry_unhovered"):
		slot.connect("entry_unhovered", Callable(self, "_on_slot_unhovered"))


func _on_slot_selected(entry: Dictionary) -> void:
	_selected_entry_id = _entry_public_id(entry)
	_selected_resolution_id = _entry_resolution_id(entry)
	_sync_selected_slot_visuals()
	card_slot_selected.emit(_selected_entry_id)
	track_entry_selected.emit(entry.duplicate(true))
	var action_id := _track_select_action(entry)
	if action_id != "":
		track_action_requested.emit(action_id)


func _on_slot_opened(entry: Dictionary) -> void:
	track_entry_opened.emit(entry.duplicate(true))
	var action_id := _track_open_action(entry)
	if action_id != "":
		track_action_requested.emit(action_id)


func _on_slot_hovered(entry: Dictionary) -> void:
	track_entry_hovered.emit(entry.duplicate(true))


func _on_slot_unhovered(entry: Dictionary) -> void:
	track_entry_unhovered.emit(entry.duplicate(true))


func _sync_response_actions(auction: Dictionary) -> void:
	if auction_response_action_row == null:
		return
	_clear_container(auction_response_action_row)
	var actions := _response_actions(auction)
	var disabled_reasons: Array[String] = []
	auction_response_action_row.visible = not actions.is_empty()
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		var action_id := str(action.get("id", "")).strip_edges()
		var label := _safe_text(str(action.get("label", action_id))).strip_edges()
		if action_id == "" and label == "":
			continue
		var button := Button.new()
		button.name = _action_button_name(action_id)
		button.text = label if label != "" else action_id
		button.disabled = bool(action.get("disabled", false))
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = _safe_text(str(action.get("tooltip", action.get("reason", ""))))
		button.set_meta("track_action_id", action_id)
		button.set_meta("track_action_disabled", button.disabled)
		if button.disabled:
			var reason := _safe_text(str(action.get("reason", action.get("disabled_reason", "")))).strip_edges()
			if reason != "":
				disabled_reasons.append(reason)
		else:
			button.pressed.connect(func() -> void:
				track_action_requested.emit(action_id)
			)
		auction_response_action_row.add_child(button)
	if auction_response_disabled_reason_label != null:
		auction_response_disabled_reason_label.visible = not disabled_reasons.is_empty()
		auction_response_disabled_reason_label.text = " / ".join(disabled_reasons)


func _response_actions(auction: Dictionary) -> Array:
	var actions: Array = auction.get("actions", []) if auction.get("actions", []) is Array else []
	if not actions.is_empty():
		return actions
	for entry_variant in _all_entries():
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if not bool(entry.get("active", false)) and _entry_lane(entry) != "active":
			continue
		var entry_actions: Array = entry.get("actions", []) if entry.get("actions", []) is Array else []
		if not entry_actions.is_empty():
			return entry_actions
	return []


func _action_button_name(action_id: String) -> String:
	var normalized := action_id.strip_edges().replace(":", "_").replace("/", "_").replace("-", "_")
	if normalized == "":
		normalized = "unnamed"
	return "CardResolutionTrackAction_%s" % normalized


func _sync_selected_slot_visuals() -> void:
	for rail in [history_rail, active_resolution_slot, queue_rail, next_queue_rail]:
		if rail == null:
			continue
		for child in rail.get_children():
			var child_entry: Dictionary = child.call("track_entry") if child.has_method("track_entry") else {}
			if child.has_method("set_selected_visual"):
				child.call("set_selected_visual", _entry_matches_selected_identity(child_entry))


func _selected_slot_ids() -> Array[String]:
	var result: Array[String] = []
	for rail in [history_rail, active_resolution_slot, queue_rail, next_queue_rail]:
		if rail == null:
			continue
		for child in rail.get_children():
			if not child.has_method("track_entry"):
				continue
			var entry_variant: Variant = child.call("track_entry")
			var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
			if child.has_method("is_selected_slot") and bool(child.call("is_selected_slot")):
				result.append(str(entry.get("id", entry.get("resolution_id", ""))))
	return result


func _sync_hovered_slots() -> void:
	for rail in [history_rail, active_resolution_slot, queue_rail, next_queue_rail]:
		if rail == null:
			continue
		for child in rail.get_children():
			if child.has_method("set_hovered_visual"):
				var hover_action := str(child.get_meta("hover_action", "")).strip_edges()
				child.call("set_hovered_visual", _hovered_track_action != "" and hover_action == _hovered_track_action)


func _clear_container(container: Container) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _sanitize_state(data: Dictionary) -> Dictionary:
	var state := data.duplicate(true)
	for key in ["entries", "history_entries", "active_entries", "queue_entries", "next_entries"]:
		if not (state.get(key, []) is Array):
			continue
		var sanitized: Array = []
		for entry_variant in state.get(key, []):
			if entry_variant is Dictionary:
				sanitized.append(_safe_entry(entry_variant as Dictionary))
		state[key] = sanitized
	if state.has("privacy_hint"):
		state["privacy_hint"] = _safe_text(str(state.get("privacy_hint", "")))
	if state.has("summary"):
		state["summary"] = _safe_text(str(state.get("summary", "")))
	if state.get("auction_response", {}) is Dictionary:
		state["auction_response"] = _safe_response_payload(state.get("auction_response", {}) as Dictionary)
	return state


func _safe_entry(entry: Dictionary) -> Dictionary:
	var safe_variant: Variant = _sanitize_public_value(entry)
	var result: Dictionary = safe_variant if safe_variant is Dictionary else {}
	for key in ["label", "title", "summary", "detail", "full_detail", "tooltip", "owner_hint", "state"]:
		if result.has(key):
			result[key] = _safe_text(str(result.get(key, "")))
	var owner_hint := str(result.get("owner_hint", "")).strip_edges()
	if _has_private_token(owner_hint):
		result["owner_hint"] = "待猜"
	return result


func _sync_selected_identity_from_state() -> void:
	for entry_variant in _all_entries():
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if not bool(entry.get("selected", entry.get("focused", false))):
			continue
		_selected_entry_id = _entry_public_id(entry)
		_selected_resolution_id = _entry_resolution_id(entry)
		return
	_selected_entry_id = ""
	_selected_resolution_id = -1


func _entry_matches_selected_identity(entry: Dictionary) -> bool:
	var resolution_id := _entry_resolution_id(entry)
	if _selected_resolution_id >= 0 and resolution_id >= 0:
		return resolution_id == _selected_resolution_id
	var entry_id := _entry_public_id(entry)
	return _selected_entry_id != "" and entry_id == _selected_entry_id


func _entry_public_id(entry: Dictionary) -> String:
	return str(entry.get("id", entry.get("resolution_id", ""))).strip_edges()


func _entry_resolution_id(entry: Dictionary) -> int:
	return int(entry.get("resolution_id", -1))


func _track_select_action(entry: Dictionary) -> String:
	var action_id := str(entry.get("select_action", "")).strip_edges()
	if action_id != "":
		return action_id
	if bool(entry.get("disabled", false)) or _entry_lane(entry) == "history" and str(entry.get("kind", "")).to_lower() == "event":
		return ""
	var resolution_id := _entry_resolution_id(entry)
	return "track_select_%d" % resolution_id if resolution_id >= 0 else ""


func _track_open_action(entry: Dictionary) -> String:
	var action_id := str(entry.get("open_action", "")).strip_edges()
	if action_id != "":
		return action_id
	var card_name := str(entry.get("card_name", "")).strip_edges()
	return "track_open_%s" % card_name if card_name != "" else ""


func _configure_slot_pointer_input(slot: Control) -> void:
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	for child in slot.get_children():
		_set_pointer_passthrough_recursive(child)


func _set_pointer_passthrough_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_pointer_passthrough_recursive(child)


func _safe_text(text: String) -> String:
	return "匿名线索" if _has_private_token(text) else text


func _safe_response_payload(payload: Dictionary) -> Dictionary:
	var safe_variant: Variant = _sanitize_public_value(payload)
	var result: Dictionary = safe_variant if safe_variant is Dictionary else {}
	if result.has("summary"):
		result["summary"] = _safe_text(str(result.get("summary", "")))
	var actions: Array = result.get("actions", []) if result.get("actions", []) is Array else []
	var safe_actions: Array = []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = (action_variant as Dictionary).duplicate(true)
		for key in ["label", "tooltip", "reason", "disabled_reason"]:
			if action.has(key):
				action[key] = _safe_text(str(action.get(key, "")))
		safe_actions.append(action)
	result["actions"] = safe_actions
	return result


func _sanitize_public_value(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary_result: Dictionary = {}
		for key_variant in value:
			var key := str(key_variant).to_lower()
			if _is_private_entry_key(key):
				continue
			dictionary_result[key_variant] = _sanitize_public_value((value as Dictionary)[key_variant])
		return dictionary_result
	if value is Array:
		var array_result: Array = []
		for entry_variant in value:
			array_result.append(_sanitize_public_value(entry_variant))
		return array_result
	if value is String:
		return _safe_text(value)
	return value


func _is_private_entry_key(key: String) -> bool:
	return PRIVATE_ENTRY_KEYS.has(key) or key.begins_with("private_") or key.begins_with("hidden_")


func _entry_lane(entry: Dictionary) -> String:
	var kind := str(entry.get("kind", "")).to_lower()
	var state := str(entry.get("state", ""))
	if kind in ["history", "resolved", "event"] or state.begins_with("已") or state.contains("历史") or state.contains("事件"):
		return "history"
	if kind in ["active", "current", "reveal"] or state.begins_with("当前") or state.contains("展示"):
		return "active"
	if kind in ["next"] or state.begins_with("下批") or state.begins_with("N"):
		return "next"
	return "queue"


func _slot_label(lane: String, index: int) -> String:
	match lane:
		"history":
			return "✓"
		"active":
			return "0"
		"next":
			return "N%d" % (index + 1)
	return "+%d" % (index + 1)


func _slot_width(entry: Dictionary, lane: String) -> float:
	var label := str(entry.get("label", "公共牌"))
	var meta := str(entry.get("owner_hint", "")) + str(entry.get("cost", ""))
	var base := float(label.length() * 8 + meta.length() * 6 + 74)
	if lane == "active":
		base += 34.0
	return clampf(base, SLOT_MIN_WIDTH, SLOT_MAX_WIDTH)


func _phase_from_entries(entries: Array) -> String:
	if entries.is_empty():
		return "等待"
	for entry_variant in entries:
		if entry_variant is Dictionary:
			var lane := _entry_lane(entry_variant as Dictionary)
			if lane == "active":
				return "展示中"
	return "队列"


func _contains_private_text(node: Node) -> bool:
	if node == null:
		return false
	if node is Label and _has_private_token((node as Label).text):
		return true
	if node is Button and _has_private_token((node as Button).text):
		return true
	if node is Control and _has_private_token((node as Control).tooltip_text):
		return true
	for child in node.get_children():
		if _contains_private_text(child):
			return true
	return false


func _sync_density_mode() -> void:
	var compact := _is_compact_public_track()
	var compact_response_visible := compact and _compact_response_visible()
	if compact:
		custom_minimum_size = Vector2(custom_minimum_size.x, 82.0 if compact_response_visible else 44.0)
	if track_rows != null:
		track_rows.add_theme_constant_override("separation", 0 if compact else 5)
	if track_header != null:
		track_header.visible = not compact
	if history_panel != null:
		history_panel.visible = not compact
	if active_panel != null:
		active_panel.visible = not compact
	if next_panel != null:
		next_panel.visible = not compact
	if queue_panel != null:
		queue_panel.visible = true
		if compact:
			queue_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	if queue_label != null:
		queue_label.visible = not compact
	if queue_scroll != null and compact:
		queue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		queue_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		queue_scroll.custom_minimum_size = Vector2(0, SLOT_HEIGHT)
	if compact:
		if auction_response_layer != null:
			auction_response_layer.visible = compact_response_visible
		if privacy_hint_layer != null:
			privacy_hint_layer.visible = false
		if empty_state_layer != null:
			empty_state_layer.visible = false


func _is_compact_public_track() -> bool:
	return compact_public_track or name == "PublicTrack"


func _compact_response_visible() -> bool:
	var auction: Dictionary = _track_state.get("auction_response", {}) if _track_state.get("auction_response", {}) is Dictionary else {}
	if not bool(auction.get("active", false)) and not bool(_track_state.get("auction_open", false)) and not str(_track_state.get("phase", "")).contains("竞") and not str(_track_state.get("phase", "")).contains("响应"):
		return false
	return not _response_actions(auction).is_empty()


func _has_private_token(text: String) -> bool:
	var lower := text.to_lower()
	for token in PRIVATE_TOKENS:
		if lower.contains(token):
			return true
	return false


func _track_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(Color("#f59e0b"), 0.055)
	style.border_color = Color("#334155").lerp(Color("#f59e0b"), 0.32)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6 if _is_compact_public_track() else 8)
	style.set_content_margin(SIDE_LEFT, 6.0 if _is_compact_public_track() else 8.0)
	style.set_content_margin(SIDE_RIGHT, 6.0 if _is_compact_public_track() else 8.0)
	style.set_content_margin(SIDE_TOP, 2.0 if _is_compact_public_track() else 6.0)
	style.set_content_margin(SIDE_BOTTOM, 2.0 if _is_compact_public_track() else 6.0)
	return style
