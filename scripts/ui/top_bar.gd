extends PanelContainer
class_name SpaceSyndicateTopBar

const COMPACT_PHYSICAL_WIDTH := 1400

signal end_turn_requested
signal menu_requested
signal player_inspection_requested(player_index: int)

@onready var phase_label: Label = %PhaseLabel
@onready var turn_label: Label = %TurnLabel
@onready var first_glance_rail: HFlowContainer = %FirstGlanceRail
@onready var identity_chip: Label = %IdentityChip
@onready var cash_chip: Label = %CashChip
@onready var gdp_chip: Label = %GdpChip
@onready var goal_chip: Label = %GoalChip
@onready var selected_district_chip: Label = %SelectedDistrictChip
@onready var primary_action_chip: Label = %PrimaryActionChip
@onready var weather_chip: Label = %WeatherChip
@onready var more_chip: Label = %MoreChip
@onready var resource_label: Label = %ResourceLabel
@onready var end_turn_button: Button = %EndTurnButton
@onready var menu_button: Button = %MenuButton

var _selected_detail := "未选区"
var _action_detail := "看星球"
var _weather_detail := "天气:无影响｜预报:暂无"
var _public_player_index := -1
var _owner_identity_text := "未入席"
var _inspected_public_player: Dictionary = {}


func _ready() -> void:
	_configure_chip_defaults()
	identity_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	identity_chip.focus_mode = Control.FOCUS_ALL
	identity_chip.gui_input.connect(_on_identity_chip_gui_input)
	var window := get_window()
	if window != null and not window.size_changed.is_connected(_on_window_size_changed):
		window.size_changed.connect(_on_window_size_changed)
	if not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	if not menu_button.pressed.is_connected(_on_menu_pressed):
		menu_button.pressed.connect(_on_menu_pressed)
	end_turn_button.visible = false
	_sync_responsive_visibility()


func set_state(data: Dictionary) -> void:
	var table_state_text := _first_text(data, ["table_state", "table_status", "status", "phase"], "待开桌")
	var tempo_text := _first_text(data, ["tempo", "time_text", "clock", "elapsed", "turn"], "00:00")
	var identity_text := _first_text(data, ["identity", "player", "seat"], "未入席")
	_owner_identity_text = identity_text
	var cash_text := _first_text(data, ["cash_text", "cash", "money"], "¥ --")
	var gdp_text := _first_text(data, ["gdp_text", "gdp"], "--/min")
	var goal_text := _first_text(data, ["goal_text", "goal", "target"], "--")
	var selected_text := _first_text(data, ["selected_district", "selected_region", "district"], "未选区")
	var action_text := _first_text(data, ["primary_action", "next_action", "action"], "看星球")
	var weather_text := _first_text(data, ["weather_status", "weather", "forecast"], "天气:无影响｜预报:暂无")
	_selected_detail = selected_text
	_action_detail = action_text
	_weather_detail = weather_text

	_set_status_label(phase_label, "桌态", table_state_text, 118, 12, ["桌态", "阶段"])
	_set_status_label(turn_label, "计时", tempo_text, 96, 10, ["计时", "时间", "回合", "席位"])
	_set_chip(identity_chip, "本席", identity_text, 112, 14)
	_set_chip(cash_chip, "现金", cash_text, 96, 12)
	_set_chip(gdp_chip, "GDP", gdp_text, 92, 12)
	_set_chip(goal_chip, "目标", goal_text, 148, 18)
	_set_chip(selected_district_chip, "选区", selected_text, 130, 14)
	_set_chip(primary_action_chip, "下一步", action_text, 122, 14)
	weather_chip.text = _short_chip_text(weather_text, 24)
	weather_chip.tooltip_text = weather_text
	weather_chip.custom_minimum_size = Vector2(154, 0)
	more_chip.text = "更多 3项"
	more_chip.tooltip_text = "选区: %s\n下一步: %s\n天气: %s" % [
		_selected_detail,
		_action_detail,
		_strip_known_prefix(_weather_detail, ["天气"]),
	]
	resource_label.text = str(data.get("resources", "现金 %s   GDP %s   目标 %s   下一步 %s" % [cash_text, gdp_text, goal_text, action_text]))
	var show_end_turn := bool(data.get("show_end_turn", data.get("end_turn_visible", false)))
	end_turn_button.visible = show_end_turn
	if show_end_turn:
		end_turn_button.text = str(data.get("end_turn_label", "结束"))
		end_turn_button.tooltip_text = str(data.get("end_turn_tooltip", "结算当前桌面步骤。"))
	_sync_responsive_visibility()
	_sync_inspected_identity_chip()


func bind_public_identity(player_index: int) -> void:
	_public_player_index = player_index


func set_inspected_public_player(descriptor: Dictionary) -> void:
	_inspected_public_player = {
		"player_index": int(descriptor.get("player_index", -1)),
		"public_player_name": str(descriptor.get("public_player_name", "")),
		"role_name": str(descriptor.get("role_name", "")),
	}
	set_meta("inspected_player_index", int(_inspected_public_player.get("player_index", -1)))
	_sync_inspected_identity_chip()


func _sync_inspected_identity_chip() -> void:
	var inspected_index := int(_inspected_public_player.get("player_index", -1))
	if inspected_index < 0 or inspected_index == _public_player_index:
		_set_chip(identity_chip, "本席", _owner_identity_text, 112, 14)
		return
	var public_name := str(_inspected_public_player.get("public_player_name", "玩家%d" % (inspected_index + 1)))
	_set_chip(identity_chip, "查看", public_name, 112, 14)
	identity_chip.tooltip_text = "当前查看%s（%s）；行动身份仍是本席。" % [public_name, str(_inspected_public_player.get("role_name", "公开角色"))]


func _on_identity_chip_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and _public_player_index >= 0:
		player_inspection_requested.emit(_public_player_index)


func _first_text(data: Dictionary, keys: Array, fallback: String) -> String:
	for key in keys:
		if data.has(key):
			var value := str(data.get(key, ""))
			if value.strip_edges() != "":
				return value
	return fallback


func _configure_chip_defaults() -> void:
	phase_label.custom_minimum_size = Vector2(118, 0)
	turn_label.custom_minimum_size = Vector2(96, 0)
	for status_label in [phase_label, turn_label]:
		status_label.clip_text = true
		status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for chip in [identity_chip, cash_chip, gdp_chip, goal_chip, selected_district_chip, primary_action_chip, weather_chip, more_chip]:
		chip.clip_text = true
		chip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	more_chip.custom_minimum_size = Vector2(86, 0)


func _set_status_label(label: Label, prefix: String, value: String, width: float, max_characters: int, old_prefixes: Array) -> void:
	var clean_value := _strip_known_prefix(value, old_prefixes)
	label.custom_minimum_size = Vector2(width, 0)
	label.text = "%s %s" % [prefix, _short_chip_text(clean_value, max_characters)]
	label.tooltip_text = "%s: %s" % [prefix, clean_value]


func _set_chip(label: Label, prefix: String, value: String, width: float, max_characters: int) -> void:
	label.custom_minimum_size = Vector2(width, 0)
	label.text = "%s %s" % [prefix, _short_chip_text(value, max_characters)]
	label.tooltip_text = "%s: %s" % [prefix, value]
	label.visible = true


func _strip_known_prefix(value: String, prefixes: Array) -> String:
	var result := value.strip_edges()
	for prefix_variant in prefixes:
		var prefix := str(prefix_variant)
		for separator in ["｜", ":", "：", " "]:
			var marker := "%s%s" % [prefix, separator]
			if result.begins_with(marker):
				return result.substr(marker.length()).strip_edges()
		if result == prefix:
			return ""
	return result


func _short_chip_text(value: String, max_characters: int) -> String:
	if value.length() <= max_characters:
		return value
	return value.left(maxi(1, max_characters - 1)) + "..."


func _sync_responsive_visibility() -> void:
	var compact := DisplayServer.window_get_size().x < COMPACT_PHYSICAL_WIDTH
	selected_district_chip.visible = not compact
	primary_action_chip.visible = not compact
	weather_chip.visible = not compact
	more_chip.visible = compact
	first_glance_rail.tooltip_text = more_chip.tooltip_text if compact else ""


func _on_window_size_changed() -> void:
	_sync_responsive_visibility()


func _on_end_turn_pressed() -> void:
	end_turn_requested.emit()


func _on_menu_pressed() -> void:
	menu_requested.emit()
