extends Control
class_name CardUISkinLab

const CARD_FIXTURE_PATH := "res://data/ui/card_ui_skin_lab_cards_v06.json"
const CARD_ILLUSTRATION_MANIFEST_PATH := "res://data/art/card_illustration_manifest_v06.json"
const LAB_STATES := ["normal", "hovered", "selected", "disabled", "drop_valid", "resolving", "hidden"]

@onready var commodity_belt: Control = %CommodityBelt
@onready var planet_map: Control = %PlanetMapView
@onready var hand_rack: Control = %HandRack
@onready var right_inspector: Control = %RightInspector
@onready var inspector_card: Control = %InspectorCardFace
@onready var inspector_card_host: Control = %InspectorCardHost
@onready var hidden_preview: Control = %HiddenCommodityPreview
@onready var targeting_overlay: Control = %TargetingOverlay
@onready var drop_target: Control = %DropTarget
@onready var settlement_stage: Control = %CardSettlementStage
@onready var settlement_card: Control = %CardSettlementStage.get_node("StageMargin/StageRows/SettlementCardFace") as Control
@onready var transit_card: Control = %TransitCard
@onready var state_status_label: Label = %StateStatusLabel
@onready var inspector_context_label: Label = %InspectorContextLabel

var _records: Array = []
var _cards: Array = []
var _illustration_style_keys: Dictionary = {}
var _current_state := "drop_valid"
var _settlement_tween: Tween = null


func _ready() -> void:
	set_meta("mcp_sceneized_component", "CardUISkinLab")
	set_meta("ruleset_contract", "v0.6-presentation-only")
	_load_illustration_manifest()
	_load_card_fixtures()
	_connect_scene_controls()
	_configure_belt()
	_configure_planet()
	_configure_hand()
	if _cards.size() >= 6:
		settlement_stage.call("set_card_view_model", _cards[5])
	set_lab_state(_current_state)
	call_deferred("_refresh_targeting_geometry")
	print("SKIN_LAB|event=ready|cards=%d|sceneized=true|rules_unchanged=true" % _cards.size())


func set_lab_state(state_id: String) -> void:
	var normalized := state_id.strip_edges().to_lower()
	if not normalized in LAB_STATES:
		push_warning("Card UI Skin Lab ignored an unknown state id.")
		return
	_ensure_hand_cards()
	_current_state = normalized
	_reset_hand_focus()
	var card_index := _state_card_index(normalized)
	var card := _hand_card_at(card_index)
	match normalized:
		"hovered":
			hand_rack.call("set_hovered_card", card)
		"selected":
			hand_rack.call("set_selected_card", card)
		"disabled":
			hand_rack.call("set_selected_card", card)
		"drop_valid":
			hand_rack.call("set_hovered_card", card)
			hand_rack.call("set_dragged_card", card, true)
		"resolving":
			hand_rack.call("set_selected_card", card)
			call_deferred("_play_settlement_transition")
	_update_state_copy(normalized)
	_update_inspector(card_index, normalized)
	call_deferred("_refresh_targeting_geometry")


func get_lab_snapshot() -> Dictionary:
	var belt_snapshot: Dictionary = {}
	if commodity_belt.has_method("get_debug_snapshot"):
		var belt_variant: Variant = commodity_belt.call("get_debug_snapshot")
		belt_snapshot = belt_variant if belt_variant is Dictionary else {}
	var map_snapshot: Dictionary = {}
	if planet_map.has_method("get_sceneization_debug_snapshot"):
		var map_variant: Variant = planet_map.call("get_sceneization_debug_snapshot")
		map_snapshot = map_variant if map_variant is Dictionary else {}
	return {
		"component": "CardUISkinLab",
		"godot_scene_runtime": true,
		"ruleset": "v0.6 presentation fixtures",
		"card_count": _cards.size(),
		"current_state": _current_state,
		"supported_states": LAB_STATES.duplicate(),
		"player_text_fields": ["name", "rank", "type", "industry", "cost", "timing", "target", "short_effect", "effect", "duration", "visibility", "keywords", "play_state", "disabled_reason", "next_step"],
		"machine_only_fields": ["card_id", "effect_kind", "visibility_scope", "source_rule", "reason_code"],
		"developer_only_fields": ["fixture_state", "art_status", "note", "resource_path", "illustration_path", "illustration_profile", "illustration_visual_source_id", "license", "attribution", "raw_error"],
		"authored_style_key_count": _illustration_style_keys.size(),
		"belt": belt_snapshot,
		"map": map_snapshot,
	}


func get_player_text_leak_report() -> Dictionary:
	var forbidden_tokens := [
		"card_id",
		"action_id",
		"reason_code",
		"visual_source_id",
		"sprite_key",
		"license",
		"attribution",
		"upstream_source_id",
		"cc0",
		"cc by",
		"cc-by",
		"res://",
		"raw error",
		"_draw",
		"effectlayer",
		"map node",
		"sceneized render",
		"unknown",
	]
	var leaks: Array = []
	for node in find_children("*", "Control", true, false):
		var control := node as Control
		var player_texts: Array[String] = []
		if control is Label:
			player_texts.append((control as Label).text)
		elif control is Button:
			player_texts.append((control as Button).text)
		elif control is RichTextLabel:
			player_texts.append((control as RichTextLabel).text)
		if control.tooltip_text.strip_edges() != "":
			player_texts.append(control.tooltip_text)
		for player_text in player_texts:
			var lowered := player_text.to_lower()
			for token in forbidden_tokens:
				if lowered.contains(token):
					leaks.append({"node": str(control.get_path()), "token": token})
	return {"clean": leaks.is_empty(), "leak_count": leaks.size(), "leaks": leaks}


func _load_card_fixtures() -> void:
	var file := FileAccess.open(CARD_FIXTURE_PATH, FileAccess.READ)
	if file == null:
		push_error("Card UI Skin Lab could not open its fixture catalog.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("Card UI Skin Lab fixture catalog is not valid JSON.")
		return
	var source_cards: Array = (parsed as Dictionary).get("cards", []) if (parsed as Dictionary).get("cards", []) is Array else []
	for index in range(source_cards.size()):
		if not (source_cards[index] is Dictionary):
			continue
		var record: Dictionary = (source_cards[index] as Dictionary).duplicate(true)
		_records.append(record)
		_cards.append(_player_view_model(record, index))
	if _cards.size() != 6:
		push_error("Card UI Skin Lab requires exactly six v0.6 representative cards.")


func _load_illustration_manifest() -> void:
	var file := FileAccess.open(CARD_ILLUSTRATION_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_warning("Card UI Skin Lab illustration manifest is unavailable; procedural art remains active.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("Card UI Skin Lab illustration manifest is invalid; procedural art remains active.")
		return
	var style_keys_variant: Variant = (parsed as Dictionary).get("style_keys", {})
	if style_keys_variant is Dictionary:
		_illustration_style_keys = (style_keys_variant as Dictionary).duplicate(true)


func _player_view_model(record: Dictionary, index: int) -> Dictionary:
	var player: Dictionary = record.get("player", {}) if record.get("player", {}) is Dictionary else {}
	var machine: Dictionary = record.get("machine", {}) if record.get("machine", {}) is Dictionary else {}
	var developer: Dictionary = record.get("developer", {}) if record.get("developer", {}) is Dictionary else {}
	var view_model := player.duplicate(true)
	# Internal identity remains in the view model for stable hand reconciliation, but no
	# player-facing component is allowed to render it or use it as fallback copy.
	var card_id := str(machine.get("card_id", "skin_lab_card_%d" % index))
	view_model["id"] = card_id
	var illustration_variant: Variant = _illustration_style_keys.get(card_id, {})
	if illustration_variant is Dictionary:
		var illustration: Dictionary = illustration_variant
		var illustration_path := str(illustration.get("illustration_path", "")).strip_edges()
		if illustration_path != "":
			view_model["illustration_path"] = illustration_path
			view_model["illustration_visual_source_id"] = str(illustration.get("visual_source_id", ""))
			view_model["illustration_profile"] = _illustration_runtime_profile(illustration)
	view_model["summary"] = str(player.get("short_effect", ""))
	view_model["route"] = str(player.get("industry", "通用"))
	view_model["skin_variant"] = "orbital_table_premium"
	view_model["keywords_authoritative"] = true
	view_model["kind"] = _presentation_kind(str(player.get("type", "")))
	view_model["drop_enabled"] = str(player.get("disabled_reason", "")).strip_edges() == ""
	view_model["selected"] = str(developer.get("fixture_state", "")) == "selected"
	view_model["actions"] = [_localized_action_for(view_model, index)]
	return view_model


func _illustration_runtime_profile(illustration: Dictionary) -> Dictionary:
	var allowed_fields := [
		"source_type",
		"visual_source_id",
		"sprite_key",
		"sprite_cell",
		"layout_variant",
		"palette_variant",
		"effect_variant",
		"composition_variant",
		"motif_family",
		"first_run_art_focus",
		"illustration_anchor",
		"fit_mode",
		"tint_mode",
		"semantic_motif",
		"texture_filter",
		"overlay_intensity",
	]
	var runtime_profile := {}
	for field_variant in allowed_fields:
		var field := str(field_variant)
		if illustration.has(field):
			runtime_profile[field] = illustration[field]
	return runtime_profile


func _localized_action_for(card: Dictionary, index: int) -> Dictionary:
	var disabled_reason := str(card.get("disabled_reason", "")).strip_edges()
	var labels := ["安装商品", "建造设施", "提交订单", "释放供货", "部署怪兽", "提交反制"]
	return {
		"id": "skin_lab_action_%d" % index,
		"label": labels[index] if index < labels.size() else "执行操作",
		"disabled": disabled_reason != "",
		"reason": disabled_reason,
		"next_step": str(card.get("next_step", "")),
	}


func _presentation_kind(type_text: String) -> String:
	if type_text.contains("商品"):
		return "commodity"
	if type_text.contains("设施"):
		return "facility"
	if type_text.contains("怪兽"):
		return "monster"
	if type_text.contains("反制"):
		return "counter"
	if type_text.contains("供需"):
		return "supply_demand"
	return "action"


func _configure_belt() -> void:
	var hidden_payloads: Array = []
	for index in range(5):
		hidden_payloads.append({
			"industry_color": ["#22c55e", "#f97316", "#94a3b8", "#38bdf8", "#c084fc"][index],
			"direction": "right",
			"position_hint": index + 1,
		})
	var visible_cards: Array = []
	visible_cards.append(_belt_commodity("环晶电池", "能源", "#f97316", "◉", "belt_energy"))
	visible_cards.append(_belt_commodity("星露莓", "生命", "#22c55e", "✦", "belt_life"))
	visible_cards.append(_belt_commodity("重力陶瓷", "工业", "#94a3b8", "⬢", "belt_industry"))
	commodity_belt.call("set_view_snapshot", {
		"revision": 6,
		"visibility_label": "清晰区 3 / 8",
		"rank_hint": "领先档 · 可见窗口缩短",
		"obscured": hidden_payloads,
		"visible": visible_cards,
	})


func _belt_commodity(name_text: String, industry_text: String, accent_text: String, glyph_text: String, internal_key: String) -> Dictionary:
	return {
		"card_key": internal_key,
		"name": name_text,
		"rank": "I",
		"type": "商品牌",
		"industry": industry_text,
		"route": industry_text,
		"cost": "免费",
		"glyph": glyph_text,
		"accent": accent_text,
		"action_label": "可领取",
		"timing": "商品进入清晰区时",
		"target": "你的手牌",
		"short_effect": "领取后加入手牌；不支付现金。",
		"effect": "从商品履带领取这张商品牌并加入手牌。领取本身不支付现金。",
		"duration": "领取后进入手牌",
		"visibility": "清晰区中的名称、产业与等级对你可见",
		"keywords": [{"text": industry_text}, {"text": "免费领取"}],
		"play_state": "可以领取",
		"next_step": "点击商品牌领取",
		"skin_variant": "orbital_table_premium",
		"keywords_authoritative": true,
		"actions": [{"id": "skin_lab_claim_commodity", "label": "领取商品"}],
	}


func _configure_planet() -> void:
	planet_map.call(
		"set_map",
		_convert_districts(_skin_lab_districts()),
		1400.0,
		950.0,
		-1,
		_convert_colors(["#0ea5e9", "#22c55e", "#f59e0b", "#a855f7", "#14b8a6"]),
		_convert_vector_entries([{"from": [420, 650], "to": [700, 250], "label": "远程货流", "color": "#38bdf8", "duration": 8.0, "life": 8.0}], ["from", "to"]),
		[],
		[],
		_convert_vector_entries(_convert_color_entries([{"name": "孢雾海皇", "position": [760, 430], "label": "A", "glyph": "兽", "motif": "自动战斗", "color": "#ef4444", "secondary": "#fde68a"}], ["color", "secondary"]), ["position"]),
		[],
		_convert_routes([
			{"product": "能源商品", "points": [[310, 260], [700, 250], [1050, 340]], "disrupted": false, "show_marker": false},
			{"product": "生命商品", "points": [[420, 650], [700, 250], [900, 650]], "disrupted": false, "show_marker": false},
		]),
		"能源商品",
		"all"
	)
	planet_map.call("set_preview_note", "真实星球桌面 · 航班式弧线商路 · 共享目标反馈")


func _skin_lab_districts() -> Array:
	return [
		{"name": "寒冠洋", "terrain": "海域", "center": [310, 260], "radius_m": 82, "hp": 92, "damage": 8, "panic": 18, "products": ["航运", "生命"], "polygon": [[175, 155], [455, 175], [470, 330], [210, 350]]},
		{"name": "雾港城", "terrain": "港区", "center": [700, 250], "radius_m": 78, "hp": 84, "damage": 16, "panic": 34, "products": ["能源", "商贸"], "polygon": [[570, 160], [835, 150], [860, 335], [600, 350]]},
		{"name": "铁脊盆地", "terrain": "工业区", "center": [1050, 340], "radius_m": 76, "hp": 96, "damage": 4, "panic": 12, "products": ["工业", "科技"], "polygon": [[925, 240], [1190, 255], [1200, 425], [955, 450]]},
		{"name": "镜海群岛", "terrain": "海域", "center": [420, 650], "radius_m": 80, "hp": 88, "damage": 12, "panic": 26, "products": ["生命", "航运"], "polygon": [[275, 545], [535, 530], [570, 720], [305, 745]]},
		{"name": "星穹台地", "terrain": "高地区", "center": [900, 650], "radius_m": 84, "hp": 90, "damage": 10, "panic": 22, "products": ["科技", "商贸"], "polygon": [[760, 535], [1040, 545], [1060, 735], [790, 745]]},
	]


func _configure_hand() -> void:
	hand_rack.call("set_cards", _cards)
	if hand_rack.has_signal("card_hovered"):
		hand_rack.connect("card_hovered", Callable(self, "_on_hand_card_hovered"))
	if hand_rack.has_signal("card_selected"):
		hand_rack.connect("card_selected", Callable(self, "_on_hand_card_selected"))
	if hand_rack.has_signal("card_drag_preview_moved"):
		hand_rack.connect("card_drag_preview_moved", Callable(self, "_on_hand_drag_moved"))
	if hand_rack.has_signal("card_drag_preview_ended"):
		hand_rack.connect("card_drag_preview_ended", Callable(self, "_on_hand_drag_ended"))


func _connect_scene_controls() -> void:
	var state_buttons := {
		%NormalStateButton: "normal",
		%HoveredStateButton: "hovered",
		%SelectedStateButton: "selected",
		%DisabledStateButton: "disabled",
		%DropValidStateButton: "drop_valid",
		%ResolvingStateButton: "resolving",
		%HiddenStateButton: "hidden",
	}
	for button_variant in state_buttons.keys():
		var button := button_variant as Button
		var state_id: String = state_buttons[button_variant]
		button.pressed.connect(func() -> void: set_lab_state(state_id))
	%SettlementDemoButton.pressed.connect(func() -> void: set_lab_state("resolving"))
	%TargetDemoButton.pressed.connect(func() -> void: set_lab_state("drop_valid"))
	commodity_belt.connect("visible_card_focused", Callable(self, "_on_belt_card_focused"))


func _reset_hand_focus() -> void:
	hand_rack.call("set_hovered_card", null)
	hand_rack.call("clear_selected_card")
	hand_rack.call("clear_dragged_card")
	targeting_overlay.call("clear_targeting")


func _update_inspector(card_index: int, state_id: String) -> void:
	var is_hidden := state_id == "hidden"
	inspector_card_host.visible = not is_hidden
	hidden_preview.visible = is_hidden
	if is_hidden:
		inspector_context_label.text = "隐藏商品｜只公开产业颜色与移动方向"
		right_inspector.call("set_context", {
			"title": "隐藏商品",
			"why": "你当前只能识别产业颜色；不可领取，也不会泄露名称或效果。",
			"district": {
				"title": "情报受限",
				"summary": "排名越高，可清晰看到的履带区段越短。",
				"full_detail": "下一步｜等待商品进入你的清晰区。",
				"chips": [{"text": "不可领取"}, {"text": "颜色公开"}],
			},
			"actions": [{"id": "skin_lab_wait_hidden", "label": "等待进入清晰区", "disabled": true, "reason": "商品仍在隐藏区"}],
		})
		return
	if card_index < 0 or card_index >= _cards.size():
		return
	var card: Dictionary = _cards[card_index]
	var preview := card.duplicate(true)
	preview["presentation"] = "full"
	preview["effect"] = str(card.get("short_effect", card.get("summary", "")))
	inspector_card.call("set_card_data", preview)
	inspector_card.call("set_interaction_state", _preview_interaction_state(state_id))
	inspector_context_label.text = "%s｜%s｜%s" % [str(card.get("type", "卡牌")), str(card.get("industry", "通用")), str(card.get("play_state", ""))]
	right_inspector.call("show_card", card)


func _preview_interaction_state(state_id: String) -> Dictionary:
	return {
		"hovered": state_id == "hovered",
		"selected": state_id == "selected",
		"disabled": state_id == "disabled",
		"dragging": state_id == "drop_valid",
		"drop_valid": state_id == "drop_valid",
		"drop_invalid": false,
		"resolving": state_id == "resolving",
	}


func _update_state_copy(state_id: String) -> void:
	var copies := {
		"normal": "正常｜实体阴影与稳定层级",
		"hovered": "悬停｜抬升、放大，邻牌平滑让位",
		"selected": "选中｜持续金色边缘光",
		"disabled": "不可用｜原因与下一步同时显示",
		"drop_valid": "可投放｜合法槽位与目标连线同步",
		"resolving": "结算中｜牌进入公共结算区并锁定输入",
		"hidden": "隐藏商品｜仅显示产业颜色，不可领取",
	}
	state_status_label.text = str(copies.get(state_id, "卡牌状态"))
	drop_target.visible = state_id == "drop_valid"
	settlement_stage.modulate = Color.WHITE if state_id == "resolving" else Color(0.76, 0.83, 0.9, 0.72)


func _refresh_targeting_geometry() -> void:
	if _current_state != "drop_valid" or not is_instance_valid(targeting_overlay):
		targeting_overlay.call("clear_targeting")
		return
	var source := _hand_card_at(4)
	if source == null:
		return
	var overlay_origin := targeting_overlay.global_position
	var from_point := source.get_global_rect().get_center() - overlay_origin
	var to_point := drop_target.get_global_rect().get_center() - overlay_origin
	targeting_overlay.call("set_targeting", from_point, to_point, true, "松开部署", "雾港城 · 合法槽位")


func _play_settlement_transition() -> void:
	if _cards.size() < 6:
		return
	if _settlement_tween != null and _settlement_tween.is_valid():
		_settlement_tween.kill()
	var source := _hand_card_at(5)
	var source_rect := source.get_global_rect() if source != null else Rect2(Vector2(size.x * 0.42, size.y * 0.78), Vector2(112, 156))
	var source_rotation := source.rotation if source != null else 0.0
	var target_rect := settlement_card.get_global_rect()
	var display: Dictionary = (_cards[5] as Dictionary).duplicate(true)
	display["presentation"] = "mini_hand"
	transit_card.call("set_card_data", display)
	transit_card.call("set_interaction_state", {"resolving": true, "selected": true})
	transit_card.position = source_rect.position
	transit_card.size = source_rect.size
	transit_card.pivot_offset = source_rect.size * 0.5
	transit_card.scale = Vector2.ONE
	transit_card.rotation = source_rotation
	transit_card.visible = true
	transit_card.modulate = Color.WHITE
	if source != null:
		hand_rack.remove_child(source)
		source.queue_free()
		hand_rack.call("relayout", false)
	_settlement_tween = create_tween().set_parallel(true)
	_settlement_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_settlement_tween.tween_property(transit_card, "position", target_rect.position, 0.38)
	_settlement_tween.tween_property(transit_card, "size", target_rect.size, 0.38)
	_settlement_tween.tween_property(transit_card, "rotation", 0.0, 0.32)
	_settlement_tween.tween_property(transit_card, "modulate", Color(1.0, 0.92, 0.68, 0.96), 0.24)
	_settlement_tween.chain().tween_callback(func() -> void: transit_card.visible = false)


func _state_card_index(state_id: String) -> int:
	return {"normal": 0, "hovered": 2, "selected": 1, "disabled": 3, "drop_valid": 4, "resolving": 5}.get(state_id, -1)


func _hand_card_at(index: int) -> Control:
	if index < 0:
		return null
	var cards: Array[Control] = []
	for child in hand_rack.get_children():
		if child is Control and child.has_method("get_card_data"):
			cards.append(child as Control)
	return cards[index] if index < cards.size() else null


func _ensure_hand_cards() -> void:
	var live_count := 0
	for child in hand_rack.get_children():
		if child is Control and child.has_method("get_card_data"):
			live_count += 1
	if live_count != _cards.size():
		hand_rack.call("set_cards", _cards)


func _on_hand_card_hovered(card_data: Dictionary) -> void:
	if _current_state == "drop_valid":
		return
	var index := _card_index_from_internal_identity(card_data)
	if index >= 0:
		_update_inspector(index, "hovered")


func _on_hand_card_selected(card_data: Dictionary) -> void:
	var index := _card_index_from_internal_identity(card_data)
	if index >= 0:
		_update_inspector(index, "selected")


func _on_hand_drag_moved(_card_data: Dictionary, _screen_position: Vector2) -> void:
	_current_state = "drop_valid"
	_update_state_copy(_current_state)
	_refresh_targeting_geometry()


func _on_hand_drag_ended(_card_data: Dictionary) -> void:
	targeting_overlay.call("clear_targeting")


func _on_belt_card_focused(card_view_model: Dictionary) -> void:
	var index := _card_index_from_internal_identity(card_view_model)
	if index >= 0:
		_update_inspector(index, "hovered")
	elif str(card_view_model.get("name", "")).strip_edges() != "":
		inspector_card_host.visible = true
		hidden_preview.visible = false
		var preview := card_view_model.duplicate(true)
		preview["presentation"] = "full"
		preview["effect"] = str(card_view_model.get("short_effect", "领取后加入手牌。"))
		inspector_card.call("set_card_data", preview)
		inspector_card.call("set_interaction_state", {"hovered": true})
		inspector_context_label.text = "商品履带｜%s｜可以领取" % str(card_view_model.get("industry", "商品"))
		right_inspector.call("show_card", card_view_model)


func _card_index_from_internal_identity(card_data: Dictionary) -> int:
	var identity := str(card_data.get("id", ""))
	for index in range(_cards.size()):
		if str((_cards[index] as Dictionary).get("id", "")) == identity:
			return index
	return -1


func _convert_districts(source: Variant) -> Array:
	var result: Array = []
	if not (source is Array):
		return result
	for entry_variant in source:
		if entry_variant is Dictionary:
			var entry: Dictionary = (entry_variant as Dictionary).duplicate(true)
			entry["center"] = _to_vector2(entry.get("center", [0, 0]))
			entry["polygon"] = _point_array(entry.get("polygon", []))
			result.append(entry)
	return result


func _convert_colors(source: Variant) -> Array:
	var result: Array = []
	if source is Array:
		for value in source:
			result.append(Color(str(value)))
	return result


func _convert_routes(source: Variant) -> Array:
	var result: Array = []
	if not (source is Array):
		return result
	for route_variant in source:
		if route_variant is Dictionary:
			var route: Dictionary = (route_variant as Dictionary).duplicate(true)
			route["points"] = _point_array(route.get("points", []))
			result.append(route)
	return result


func _convert_vector_entries(source: Variant, fields: Array) -> Array:
	var result: Array = []
	if not (source is Array):
		return result
	for entry_variant in source:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = (entry_variant as Dictionary).duplicate(true)
		for field_variant in fields:
			var field := str(field_variant)
			if entry.has(field):
				entry[field] = _to_vector2(entry[field])
		result.append(entry)
	return result


func _convert_color_entries(source: Variant, fields: Array) -> Array:
	var result: Array = []
	if not (source is Array):
		return result
	for entry_variant in source:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = (entry_variant as Dictionary).duplicate(true)
		for field_variant in fields:
			var field := str(field_variant)
			if entry.has(field) and entry[field] is String:
				entry[field] = Color(str(entry[field]))
		result.append(entry)
	return result


func _point_array(source: Variant) -> Array:
	var result: Array = []
	if source is Array:
		for value in source:
			result.append(_to_vector2(value))
	return result


func _to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return Vector2.ZERO
