extends Control
class_name GameScreen

signal end_turn_requested
signal card_hovered(card_data: Dictionary)
signal card_double_clicked(card_data: Dictionary)

const CARD_SCENE := preload("res://scenes/CardUI.tscn")

@onready var phase_label: Label = %PhaseLabel
@onready var turn_label: Label = %TurnLabel
@onready var money_chip: Label = %MoneyChip
@onready var gdp_chip: Label = %GDPChip
@onready var goal_chip: Label = %GoalChip
@onready var hand_chip: Label = %HandChip
@onready var end_turn_button: Button = %EndTurnButton
@onready var left_info_rows: VBoxContainer = %LeftInfoRows
@onready var planet_placeholder: Label = %PlanetPlaceholder
@onready var draw_pile_label: Label = %DrawPileLabel
@onready var reveal_track_label: Label = %RevealTrackLabel
@onready var discard_pile_label: Label = %DiscardPileLabel
@onready var detail_text: Label = %DetailText
@onready var log_text: Label = %LogText
@onready var player_panel_title: Label = %PlayerPanelTitle
@onready var hand_area: Control = %HandArea
@onready var tooltip_panel: PanelContainer = %TooltipPanel
@onready var tooltip_label: Label = %TooltipText
@onready var confirm_popup: PanelContainer = %ConfirmPopup
@onready var confirm_text: Label = %ConfirmText

func _ready() -> void:
	if not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.connect(_on_end_turn_pressed)


func apply_state(state: Dictionary) -> void:
	var resources_variant: Variant = state.get("resources", {})
	var resources: Dictionary = resources_variant if resources_variant is Dictionary else {}
	set_top_bar(
		str(state.get("phase", "阶段｜开局")),
		str(state.get("turn", "席位｜1/4")),
		resources
	)

	var players_variant: Variant = state.get("players", [])
	set_players(players_variant if players_variant is Array else [])

	var hand_cards_variant: Variant = state.get("hand_cards", [])
	set_hand_cards(hand_cards_variant if hand_cards_variant is Array else [])

	var logs_variant: Variant = state.get("logs", [])
	set_logs(logs_variant if logs_variant is Array else [])

	set_detail(str(state.get("detail", "悬停卡牌或区域时，在这里显示短详情。")))
	set_board_hint(str(state.get("board_hint", "PLANET MAP\n双击区域查看牌架｜滚轮缩放｜拖拽星球")))
	set_table_slots(
		str(state.get("draw_pile", "抽牌堆")),
		str(state.get("reveal_track", "匿名牌轨｜历史牌与事件共用时间轴")),
		str(state.get("discard_pile", "弃牌堆"))
	)


func set_top_bar(phase_text: String, turn_text: String, resources: Dictionary) -> void:
	phase_label.text = phase_text
	turn_label.text = turn_text
	money_chip.text = str(resources.get("money", "¥ —"))
	gdp_chip.text = str(resources.get("gdp", "GDP —/s"))
	goal_chip.text = str(resources.get("goal", "目标 —"))
	hand_chip.text = str(resources.get("hand", "手牌 —/—"))


func set_players(players_public: Array) -> void:
	_remove_children_after(left_info_rows, 1)
	if players_public.is_empty():
		left_info_rows.add_child(_make_public_player_label("等待席位", "公开角色会显示在这里。", false))
		return
	for i in range(players_public.size()):
		var value: Variant = players_public[i]
		var player: Dictionary = value if value is Dictionary else {}
		var name_text := str(player.get("name", "席位%d" % (i + 1)))
		var role_text := str(player.get("role", "未知角色"))
		var status_text := str(player.get("status", "公开状态"))
		var current := bool(player.get("current", false))
		left_info_rows.add_child(_make_public_player_label(name_text, "公开角色：%s｜%s" % [role_text, status_text], current))


func set_hand_cards(cards: Array) -> void:
	_remove_all_children(hand_area)
	for i in range(cards.size()):
		var value: Variant = cards[i]
		var card_data: Dictionary = value if value is Dictionary else {}
		var card := CARD_SCENE.instantiate() as Control
		if card.has_method("set_card_data"):
			card.call("set_card_data", card_data)
		var enter_callback := Callable(self, "_on_card_entered").bind(card)
		if not card.mouse_entered.is_connected(enter_callback):
			card.mouse_entered.connect(enter_callback)
		var exit_callback := Callable(self, "_on_card_exited")
		if not card.mouse_exited.is_connected(exit_callback):
			card.mouse_exited.connect(exit_callback)
		if card.has_signal("card_double_clicked"):
			card.connect("card_double_clicked", Callable(self, "_on_card_double_clicked"))
		hand_area.add_child(card)
	if hand_area.has_method("relayout"):
		hand_area.call_deferred("relayout")


func set_logs(lines: Array) -> void:
	if lines.is_empty():
		log_text.text = "公开日志\n- 暂无公开事件"
		return
	var display_lines: Array[String] = ["公开日志"]
	var start_index := maxi(0, lines.size() - 7)
	for i in range(start_index, lines.size()):
		display_lines.append("- %s" % str(lines[i]))
	log_text.text = "\n".join(display_lines)


func set_detail(text: String) -> void:
	detail_text.text = text


func set_board_hint(text: String) -> void:
	planet_placeholder.text = text


func set_table_slots(draw_text: String, reveal_text: String, discard_text: String) -> void:
	draw_pile_label.text = draw_text
	reveal_track_label.text = reveal_text
	discard_pile_label.text = discard_text


func show_tooltip(text: String) -> void:
	tooltip_label.text = text
	tooltip_panel.visible = text.strip_edges() != ""


func hide_tooltip() -> void:
	tooltip_panel.visible = false


func show_confirm(text: String) -> void:
	confirm_text.text = text
	confirm_popup.visible = true


func hide_confirm() -> void:
	confirm_popup.visible = false


func _make_public_player_label(name_text: String, detail: String, current: bool) -> Label:
	var label := Label.new()
	label.name = "PublicPlayerCard"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "%s%s\n%s" % ["▶ " if current else "• ", name_text, detail]
	label.add_theme_color_override("font_color", Color("#fde68a") if current else Color("#dbeafe"))
	return label


func _remove_children_after(parent: Node, keep_count: int) -> void:
	for i in range(parent.get_child_count() - 1, keep_count - 1, -1):
		var child := parent.get_child(i)
		parent.remove_child(child)
		child.queue_free()


func _remove_all_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _on_end_turn_pressed() -> void:
	end_turn_requested.emit()


func _on_card_entered(card: Control) -> void:
	var data := _card_data_from_node(card)
	card_hovered.emit(data)
	var title := str(data.get("name", "卡牌"))
	var kind := str(data.get("type", data.get("category", "行动")))
	var effect := str(data.get("effect", data.get("text", data.get("description", ""))))
	show_tooltip("%s｜%s\n%s" % [title, kind, effect])
	set_detail("%s：%s" % [title, effect])


func _on_card_exited() -> void:
	hide_tooltip()


func _on_card_double_clicked(card_data: Dictionary) -> void:
	card_double_clicked.emit(card_data)
	var title := str(card_data.get("name", "卡牌"))
	show_confirm("打开「%s」详情 / 目标选择" % title)


func _card_data_from_node(card: Control) -> Dictionary:
	if card.has_method("get_card_data"):
		var value: Variant = card.call("get_card_data")
		if value is Dictionary:
			return value
	return {}
