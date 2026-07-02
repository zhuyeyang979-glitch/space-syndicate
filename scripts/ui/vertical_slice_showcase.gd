extends Control
class_name VerticalSliceShowcase

const DIRECTOR_SCRIPT := preload("res://scripts/ui/showcase_director.gd")
const HAND_RACK_SCENE := preload("res://scenes/ui/HandRack.tscn")
const VISUAL_EVENT_LAYER_SCENE := preload("res://scenes/ui/VisualEventLayer.tscn")
const TARGETING_OVERLAY_SCENE := preload("res://scenes/ui/TargetingOverlay.tscn")

@export var reduced_motion := false

var _director: Variant
var _stage_label: Label
var _phase_label: Label
var _inspector_title: Label
var _inspector_body: Label
var _resource_label: Label
var _bid_label: Label
var _balance_panel: PanelContainer
var _balance_body: Label
var _public_track_slots: Array[PanelContainer] = []
var _hand_rack: Control
var _visual_layer: Control
var _targeting_overlay: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_director = DIRECTOR_SCRIPT.new()
	_director.name = "ShowcaseDirector"
	add_child(_director)
	_director.call("load_sequence")
	_build_showcase_ui()
	play_stage("board_idle")


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if _visual_layer != null:
		_visual_layer.set("reduced_motion", enabled)
	if _targeting_overlay != null:
		_targeting_overlay.set("reduced_motion", enabled)


func set_showcase_time(seconds: float) -> void:
	var stage: Dictionary = _director.call("stage_for_time", seconds)
	play_stage(str(stage.get("id", "board_idle")))


func play_stage(stage_id: String) -> void:
	if _director == null:
		return
	var snapshot: Dictionary = _director.call("stage_snapshot", stage_id)
	var title := str(snapshot.get("title", ""))
	_stage_label.text = title
	_phase_label.text = "%s｜%s" % [str(snapshot.get("id", "")), "45 秒商业垂直切片"]
	_inspector_title.text = "当前解释｜%s" % title
	_inspector_body.text = str(snapshot.get("inspector", ""))
	_stage_hand_state(stage_id)
	_stage_track_state(stage_id)
	_stage_balance_preview(stage_id)
	var events_variant: Variant = snapshot.get("events", [])
	var events: Array = events_variant if events_variant is Array else []
	_visual_layer.call("set_visual_events", events, reduced_motion)
	_stage_targeting(snapshot)


func get_showcase_contract() -> Dictionary:
	return {
		"stage_ids": _director.call("get_stage_ids") if _director != null else [],
		"duration": _director.call("get_duration_seconds") if _director != null else 0.0,
		"reduced_motion": reduced_motion,
		"has_visual_layer": _visual_layer != null,
		"has_targeting_overlay": _targeting_overlay != null,
		"has_hand_rack": _hand_rack != null,
	}


func _build_showcase_ui() -> void:
	for child in get_children():
		if child != _director:
			child.queue_free()
	_public_track_slots.clear()
	var background := ColorRect.new()
	background.name = "ShowcaseSpaceBackdrop"
	background.color = Color("#020617")
	_fill(background)
	add_child(background)

	var top_panel := _panel("ShowcasePublicTrack", Color("#07111f"), Color("#355070"))
	_place(top_panel, 0.02, 0.02, 0.98, 0.145)
	add_child(top_panel)
	var top_rows := VBoxContainer.new()
	top_rows.name = "ShowcasePublicTrackRows"
	top_rows.add_theme_constant_override("separation", 8)
	top_panel.add_child(top_rows)
	_stage_label = _label("炉石级垂直切片", 16, HORIZONTAL_ALIGNMENT_CENTER)
	top_rows.add_child(_stage_label)
	_phase_label = _label("board_idle", 12, HORIZONTAL_ALIGNMENT_CENTER)
	top_rows.add_child(_phase_label)
	var slot_row := HBoxContainer.new()
	slot_row.name = "ShowcasePublicTrackSlotRow"
	slot_row.add_theme_constant_override("separation", 8)
	top_rows.add_child(slot_row)
	for i in range(6):
		var slot := _panel("ShowcasePublicTrackSlot%d" % i, Color("#111827"), Color("#334155"))
		slot.custom_minimum_size = Vector2(0, 42)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := _label("匿名牌 #%d\n等待" % (i + 1), 11, HORIZONTAL_ALIGNMENT_CENTER)
		label.name = "ShowcasePublicTrackSlotLabel"
		slot.add_child(label)
		slot_row.add_child(slot)
		_public_track_slots.append(slot)

	var board_panel := _panel("ShowcasePlanetStage", Color("#02091c"), Color("#1d4ed8"))
	_place(board_panel, 0.04, 0.17, 0.78, 0.73)
	add_child(board_panel)
	_build_board_stage(board_panel)

	var inspector := _panel("ShowcaseRightInspector", Color("#111827"), Color("#475569"))
	_place(inspector, 0.80, 0.17, 0.98, 0.73)
	add_child(inspector)
	var inspector_rows := VBoxContainer.new()
	inspector_rows.name = "ShowcaseRightInspectorRows"
	inspector_rows.add_theme_constant_override("separation", 10)
	inspector.add_child(inspector_rows)
	_inspector_title = _label("当前解释", 15, HORIZONTAL_ALIGNMENT_CENTER)
	inspector_rows.add_child(_inspector_title)
	_inspector_body = _label("展示说明", 13, HORIZONTAL_ALIGNMENT_LEFT)
	_inspector_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_rows.add_child(_inspector_body)
	var inspector_hint := _label("隐藏信息边界：只显示公开轨、公开竞价和本地示例数据。", 11, HORIZONTAL_ALIGNMENT_LEFT)
	inspector_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_rows.add_child(inspector_hint)

	var bottom_panel := _panel("ShowcaseBottomTable", Color("#061527"), Color("#0f766e"))
	_place(bottom_panel, 0.04, 0.75, 0.98, 0.97)
	add_child(bottom_panel)
	_build_bottom_table(bottom_panel)

	_visual_layer = VISUAL_EVENT_LAYER_SCENE.instantiate() as Control
	_visual_layer.name = "ShowcaseVisualEventLayer"
	_fill(_visual_layer)
	add_child(_visual_layer)
	_targeting_overlay = TARGETING_OVERLAY_SCENE.instantiate() as Control
	_targeting_overlay.name = "ShowcaseTargetingOverlay"
	_fill(_targeting_overlay)
	add_child(_targeting_overlay)


func _build_board_stage(parent: PanelContainer) -> void:
	var stage := Control.new()
	stage.name = "ShowcaseBoardSurface"
	stage.clip_contents = false
	parent.add_child(stage)
	_fill(stage)
	var title := _label("星球战斗桌面", 15, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 8)
	title.size = Vector2(1080, 28)
	stage.add_child(title)
	var board := Control.new()
	board.name = "ShowcasePlanetBoardPlate"
	board.position = Vector2(250, 70)
	board.size = Vector2(520, 420)
	stage.add_child(board)
	var board_bg := ColorRect.new()
	board_bg.name = "ShowcasePlanetBoardBackground"
	board_bg.position = Vector2.ZERO
	board_bg.size = board.size
	board_bg.color = Color("#071a2f")
	board.add_child(board_bg)
	var board_border := ReferenceRect.new()
	board_border.name = "ShowcasePlanetBoardBorder"
	board_border.position = Vector2.ZERO
	board_border.size = board.size
	board_border.border_color = Color("#2563eb")
	board_border.border_width = 2.0
	board.add_child(board_border)
	var regions := [
		{"name": "寒冠洋", "pos": Vector2(34, 50), "size": Vector2(210, 150), "color": Color("#0e7490")},
		{"name": "雾港城", "pos": Vector2(252, 76), "size": Vector2(180, 116), "color": Color("#166534")},
		{"name": "试玩罗盘", "pos": Vector2(150, 220), "size": Vector2(245, 145), "color": Color("#854d0e")},
		{"name": "商路中继", "pos": Vector2(54, 230), "size": Vector2(98, 98), "color": Color("#1d4ed8")},
	]
	for region_data in regions:
		var region := ColorRect.new()
		region.name = "ShowcaseRegion_%s" % str(region_data.get("name", ""))
		region.position = region_data.get("pos", Vector2.ZERO)
		region.size = region_data.get("size", Vector2(100, 80))
		region.color = region_data.get("color", Color("#1f2937"))
		board.add_child(region)
		var label := _label(str(region_data.get("name", "")), 13, HORIZONTAL_ALIGNMENT_CENTER)
		label.position = region.position + Vector2(0, region.size.y * 0.38)
		label.size = Vector2(region.size.x, 24)
		board.add_child(label)
	var city := _label("城市\nHP 18\nGDP +24", 13, HORIZONTAL_ALIGNMENT_CENTER)
	city.name = "ShowcaseCityToken"
	city.position = Vector2(820, 310)
	city.size = Vector2(104, 88)
	city.add_theme_color_override("font_color", Color("#fde68a"))
	stage.add_child(city)
	var monster := _label("怪兽\n威胁", 13, HORIZONTAL_ALIGNMENT_CENTER)
	monster.name = "ShowcaseMonsterToken"
	monster.position = Vector2(690, 265)
	monster.size = Vector2(90, 70)
	monster.add_theme_color_override("font_color", Color("#f0abfc"))
	stage.add_child(monster)
	_balance_panel = _panel("ShowcaseBalancePreview", Color("#111827"), Color("#f59e0b"))
	_balance_panel.position = Vector2(785, 62)
	_balance_panel.size = Vector2(300, 250)
	_balance_panel.visible = false
	stage.add_child(_balance_panel)
	_balance_body = _label("价格曲线报告", 12, HORIZONTAL_ALIGNMENT_LEFT)
	_balance_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_balance_panel.add_child(_balance_body)


func _build_bottom_table(parent: PanelContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "ShowcaseBottomRows"
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var resource_panel := _panel("ShowcaseResourceStrip", Color("#111827"), Color("#facc15"))
	resource_panel.custom_minimum_size = Vector2(230, 0)
	row.add_child(resource_panel)
	_resource_label = _label("本席 玩家1\n现金 ¥2080\nGDP 0/min\n目标 2420", 13, HORIZONTAL_ALIGNMENT_CENTER)
	resource_panel.add_child(_resource_label)
	_hand_rack = HAND_RACK_SCENE.instantiate() as Control
	_hand_rack.name = "ShowcaseHandRack"
	_hand_rack.custom_minimum_size = Vector2(0, 170)
	_hand_rack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_hand_rack)
	if _hand_rack.has_method("set_cards"):
		_hand_rack.call("set_cards", _showcase_hand_cards())
	var bid_panel := _panel("ShowcaseBidBoardPreview", Color("#111827"), Color("#22c55e"))
	bid_panel.custom_minimum_size = Vector2(280, 0)
	row.add_child(bid_panel)
	_bid_label = _label("公开竞价\n我的 ¥0｜最高 ¥20\n保守 / 追平 / 压过\n领跑：匿名牌 #3", 12, HORIZONTAL_ALIGNMENT_CENTER)
	bid_panel.add_child(_bid_label)


func _showcase_hand_cards() -> Array:
	return [
		{"id": "showcase_orbital_finance", "name": "轨道融资", "cost": "2", "type": "经济", "rank": "I", "effect": "城市现金流小幅上升。", "actions": [{"id": "play_showcase_0", "label": "出牌"}]},
		{"id": "showcase_beast", "name": "抱雾海皇", "cost": "6", "type": "怪兽", "rank": "I", "effect": "召唤并压迫城市。", "actions": [{"id": "play_showcase_1", "label": "出牌"}]},
		{"id": "showcase_intel", "name": "公开悬赏", "cost": "1", "type": "情报", "rank": "I", "effect": "公开轨留下线索。", "actions": [{"id": "play_showcase_2", "label": "出牌"}]},
		{"id": "showcase_locked", "name": "冷却卡", "cost": "4", "type": "互动", "rank": "II", "effect": "冷却中，不能出牌。", "drop_enabled": false, "actionable": false, "play_state": "冷却中", "block_reason": "冷却中", "actions": [{"id": "play_showcase_3", "label": "出牌", "disabled": true}]},
	]


func _stage_hand_state(stage_id: String) -> void:
	if _hand_rack == null:
		return
	if _hand_rack.has_method("set_hovered_card"):
		_hand_rack.call("set_hovered_card", null)
	if _hand_rack.has_method("clear_dragged_card"):
		_hand_rack.call("clear_dragged_card")
	if _hand_rack.has_method("clear_selected_card"):
		_hand_rack.call("clear_selected_card")
	var card0 := _hand_card_at(0)
	var card1 := _hand_card_at(1)
	var card3 := _hand_card_at(3)
	if card0 != null and _hand_rack.has_method("set_selected_card"):
		_hand_rack.call("set_selected_card", card0)
	if stage_id == "card_hover" and card0 != null:
		_hand_rack.call("set_hovered_card", card0)
	if stage_id == "card_drag_valid" and card1 != null:
		_hand_rack.call("set_dragged_card", card1, true)
	if stage_id == "card_drag_invalid" and card3 != null:
		_hand_rack.call("set_dragged_card", card3, false)


func _stage_targeting(snapshot: Dictionary) -> void:
	if _targeting_overlay == null:
		return
	var targeting_variant: Variant = snapshot.get("targeting", {})
	if targeting_variant is Dictionary and not (targeting_variant as Dictionary).is_empty():
		var targeting: Dictionary = targeting_variant
		targeting["from"] = Vector2(760, 610)
		targeting["to"] = Vector2(710, 430) if bool(targeting.get("valid", false)) else Vector2(555, 430)
		_targeting_overlay.call("set_state", targeting)
	else:
		_targeting_overlay.call("clear_targeting")


func _stage_track_state(stage_id: String) -> void:
	for i in range(_public_track_slots.size()):
		var slot := _public_track_slots[i]
		var active := (stage_id == "public_track_reveal" and i == 2) or (stage_id == "bid_highlight" and i == 2) or (stage_id.begins_with("card_play") and i == 1)
		slot.add_theme_stylebox_override("panel", _style(Color("#211827") if active else Color("#111827"), Color("#f472b6") if active else Color("#334155"), 2 if active else 1, 6))
		var label := slot.find_child("ShowcasePublicTrackSlotLabel", true, false) as Label
		if label != null:
			label.text = "匿名牌 #%d\n%s" % [i + 1, "revealed / 竞价 ¥20" if active else "等待"]
	_bid_label.text = "公开竞价\n我的 ¥0｜最高 ¥20\n保守 / 追平 / 压过\n%s" % ("领跑：匿名牌 #3" if stage_id == "bid_highlight" else "下批等待 3 张")


func _stage_balance_preview(stage_id: String) -> void:
	if _balance_panel == null:
		return
	_balance_panel.visible = stage_id == "balance_report_preview"
	if _balance_body != null:
		_balance_body.text = "价格曲线报告\n\n过低 Top 20：轨道融资 II、公开悬赏 II...\n过高 Top 20：竞价施压 II、归属标记...\n梯度异常：城市抢修 IV 偏低\n首局推荐：轨道融资、城市抢修、商路点火"


func _hand_card_at(index: int) -> Control:
	if _hand_rack == null:
		return null
	var cards: Array[Control] = []
	for child in _hand_rack.get_children():
		if child is Control and not (child is Label):
			cards.append(child as Control)
	if index < 0 or index >= cards.size():
		return null
	return cards[index]


func _panel(node_name: String, bg: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", _style(bg, border, 1, 8))
	return panel


func _style(bg: Color, border: Color, width: int = 1, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style


func _label(text: String, font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#e5e7eb"))
	return label


func _fill(node: Control) -> void:
	node.layout_mode = 1
	node.set_anchors_preset(Control.PRESET_FULL_RECT)


func _place(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	node.layout_mode = 1
	node.anchor_left = left
	node.anchor_top = top
	node.anchor_right = right
	node.anchor_bottom = bottom
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0
