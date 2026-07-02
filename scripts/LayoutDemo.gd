extends Control

const HAND_RACK_SCENE := preload("res://scenes/ui/HandRack.tscn")

const SAMPLE_CARDS := [
	{"name": "轨道融资", "cost": "2", "type": "经济", "rank": "I", "effect": "城市现金流小幅上升。", "accent": Color(0.42, 0.66, 0.96)},
	{"name": "雾港合约", "cost": "3", "type": "合约", "rank": "II", "effect": "连接两个区域的一种供需。", "accent": Color(0.52, 0.82, 0.76)},
	{"name": "相位否决", "cost": "1", "type": "互动", "rank": "I", "effect": "抵消一张直接作用于玩家的牌。", "accent": Color(0.72, 0.56, 0.96)},
	{"name": "深海军港", "cost": "4", "type": "军队", "rank": "II", "effect": "部署一支适合海域的短期部队。", "accent": Color(0.34, 0.74, 0.88)},
	{"name": "陨壳巨兽", "cost": "5", "type": "怪兽", "rank": "III", "effect": "召唤或升级一只偏好矿物的怪兽。", "accent": Color(0.92, 0.42, 0.36)},
	{"name": "商品期货", "cost": "2", "type": "金融", "rank": "I", "effect": "押注一种商品短时间涨跌。", "accent": Color(0.94, 0.74, 0.32)},
	{"name": "航道修复", "cost": "2", "type": "商品", "rank": "II", "effect": "修复受损商路并提升流速。", "accent": Color(0.39, 0.88, 0.52)},
]

@onready var hand_rows: VBoxContainer = %HandRows
@onready var table_slots: HBoxContainer = %TableSlots
@onready var log_text: Label = %LogText

func _ready() -> void:
	_build_table_slots()
	_build_hand_samples()
	log_text.text = "灰盒布局日志\n- 中央桌面保留星球主位\n- 右侧只放短详情和公开日志\n- 手牌由 HandRack v3 自己布局，不交给 HBox 硬挤\n- 示例覆盖 hover / selected / drag / invalid drop / disabled"


func _build_table_slots() -> void:
	for child in table_slots.get_children():
		child.queue_free()
	table_slots.add_child(_make_slot("抽牌堆", "区域牌池入口"))
	table_slots.add_child(_make_slot("牌轨", "匿名牌 / 公开事件"))
	table_slots.add_child(_make_slot("桌面槽位", "合约、赌局、天气"))
	table_slots.add_child(_make_slot("弃牌堆", "当前玩家私有"))


func _build_hand_samples() -> void:
	for child in hand_rows.get_children():
		child.queue_free()
	for count in [0, 1, 5, 10, 15]:
		hand_rows.add_child(_make_hand_sample(count))


func _make_hand_sample(count: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 292)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	panel.add_child(rows)

	var title := Label.new()
	title.text = "%d 张手牌" % count
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)

	var hand := HAND_RACK_SCENE.instantiate() as Control
	hand.name = "HandRackFeelDemo%d" % count
	hand.custom_minimum_size = Vector2(0, 236)
	hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(hand)

	var cards: Array = []
	for i in range(count):
		cards.append(_sample_card_data(i, count))
	if hand.has_method("set_cards"):
		hand.call("set_cards", cards)
		hand.call_deferred("relayout")
	call_deferred("_stage_hand_sample_state", hand, count)
	return panel


func _sample_card_data(index: int, count: int) -> Dictionary:
	var data: Dictionary = SAMPLE_CARDS[index % SAMPLE_CARDS.size()].duplicate()
	data["id"] = "layout_demo_%d_%d" % [count, index]
	data["presentation"] = "mini_hand"
	data["detail_policy"] = "right_inspector"
	data["actions"] = [{"id": "play_%d" % index, "label": "出牌", "disabled": false}]
	if index >= SAMPLE_CARDS.size():
		data["rank"] = ["I", "II", "III", "IV"][index % 4]
	if count >= 15 and index == 7:
		data["play_state"] = "冷却"
		data["drop_enabled"] = false
		data["actionable"] = false
		data["block_reason"] = "冷却中，不能拖到地图。"
		data["actions"] = [{"id": "play_%d" % index, "label": "出牌", "disabled": true}]
	return data


func _stage_hand_sample_state(hand: Control, count: int) -> void:
	if hand == null or not is_instance_valid(hand):
		return
	if count == 1 and hand.get_child_count() >= 1 and hand.has_method("set_selected_card"):
		hand.call("set_selected_card", hand.get_child(0))
	elif count == 5 and hand.get_child_count() >= 3 and hand.has_method("set_hovered_card"):
		hand.call("set_hovered_card", hand.get_child(2))
	elif count == 10 and hand.get_child_count() >= 6:
		if hand.has_method("set_selected_card"):
			hand.call("set_selected_card", hand.get_child(4))
		if hand.has_method("set_dragged_card"):
			hand.call("set_dragged_card", hand.get_child(5), true)
	elif count == 15 and hand.get_child_count() >= 8 and hand.has_method("set_dragged_card"):
		hand.call("set_dragged_card", hand.get_child(7), false)


func _make_slot(title_text: String, detail_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 100)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	panel.add_child(rows)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)

	var detail := Label.new()
	detail.text = detail_text
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(detail)
	return panel
