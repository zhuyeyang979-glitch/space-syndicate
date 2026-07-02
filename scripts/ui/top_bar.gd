extends PanelContainer
class_name SpaceSyndicateTopBar

signal end_turn_requested
signal menu_requested

@onready var phase_label: Label = %PhaseLabel
@onready var turn_label: Label = %TurnLabel
@onready var identity_chip: Label = %IdentityChip
@onready var cash_chip: Label = %CashChip
@onready var gdp_chip: Label = %GdpChip
@onready var goal_chip: Label = %GoalChip
@onready var selected_district_chip: Label = %SelectedDistrictChip
@onready var primary_action_chip: Label = %PrimaryActionChip
@onready var weather_chip: Label = %WeatherChip
@onready var resource_label: Label = %ResourceLabel
@onready var end_turn_button: Button = %EndTurnButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	_configure_chip_defaults()
	if not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	if not menu_button.pressed.is_connected(_on_menu_pressed):
		menu_button.pressed.connect(_on_menu_pressed)
	end_turn_button.visible = false


func set_state(data: Dictionary) -> void:
	var phase_text := str(data.get("phase", "开局"))
	var turn_text := str(data.get("turn", "席位 --"))
	var identity_text := _first_text(data, ["identity", "player", "seat"], "未入席")
	var cash_text := _first_text(data, ["cash_text", "cash", "money"], "¥ --")
	var gdp_text := _first_text(data, ["gdp_text", "gdp"], "--/min")
	var goal_text := _first_text(data, ["goal_text", "goal", "target"], "--")
	var selected_text := _first_text(data, ["selected_district", "selected_region", "district"], "未选区")
	var action_text := _first_text(data, ["primary_action", "next_action", "action"], "看星球")
	var weather_text := _first_text(data, ["weather_status", "weather", "forecast"], "天气:无影响｜预报:暂无")

	phase_label.text = _short_chip_text(phase_text, 12)
	phase_label.tooltip_text = phase_text
	turn_label.text = _short_chip_text(turn_text, 10)
	turn_label.tooltip_text = turn_text
	_set_chip(identity_chip, "本席", identity_text, 112, 14)
	_set_chip(cash_chip, "现金", cash_text, 96, 12)
	_set_chip(gdp_chip, "GDP", gdp_text, 92, 12)
	_set_chip(goal_chip, "目标", goal_text, 108, 14)
	_set_chip(selected_district_chip, "选区", selected_text, 130, 14)
	_set_chip(primary_action_chip, "下一步", action_text, 122, 14)
	weather_chip.text = _short_chip_text(weather_text, 24)
	weather_chip.tooltip_text = weather_text
	weather_chip.custom_minimum_size = Vector2(154, 0)
	resource_label.text = str(data.get("resources", "现金 %s   GDP %s   目标 %s   下一步 %s" % [cash_text, gdp_text, goal_text, action_text]))
	var show_end_turn := bool(data.get("show_end_turn", data.get("end_turn_visible", false)))
	end_turn_button.visible = show_end_turn
	if show_end_turn:
		end_turn_button.text = str(data.get("end_turn_label", "结束"))
		end_turn_button.tooltip_text = str(data.get("end_turn_tooltip", "结算当前桌面步骤。"))


func _first_text(data: Dictionary, keys: Array, fallback: String) -> String:
	for key in keys:
		if data.has(key):
			var value := str(data.get(key, ""))
			if value.strip_edges() != "":
				return value
	return fallback


func _configure_chip_defaults() -> void:
	phase_label.custom_minimum_size = Vector2(104, 0)
	turn_label.custom_minimum_size = Vector2(78, 0)
	for chip in [identity_chip, cash_chip, gdp_chip, goal_chip, selected_district_chip, primary_action_chip, weather_chip]:
		chip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _set_chip(label: Label, prefix: String, value: String, width: float, max_characters: int) -> void:
	label.custom_minimum_size = Vector2(width, 0)
	label.text = "%s %s" % [prefix, _short_chip_text(value, max_characters)]
	label.tooltip_text = "%s: %s" % [prefix, value]
	label.visible = true


func _short_chip_text(value: String, max_characters: int) -> String:
	if value.length() <= max_characters:
		return value
	return value.left(maxi(1, max_characters - 1)) + "..."


func _on_end_turn_pressed() -> void:
	end_turn_requested.emit()


func _on_menu_pressed() -> void:
	menu_requested.emit()
