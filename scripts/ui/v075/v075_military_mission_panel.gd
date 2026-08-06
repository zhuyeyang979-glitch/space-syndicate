extends PanelContainer
class_name V075MilitaryMissionPanel

signal mission_selected(option: Dictionary)

const CATALOG := preload(
	"res://resources/presentation/alpha01_card_illustration_catalog.tres"
)
const TASK_KINDS := [
	"assault_region",
	"assault_monster",
]

@onready var _region_button: Button = %AssaultRegionButton
@onready var _monster_button: Button = %AssaultMonsterButton
@onready var _region_option: OptionButton = %AssaultRegionOption
@onready var _monster_option: OptionButton = %AssaultMonsterOption

var _owner_visible := false
var _options: Array[Dictionary] = []
var _selected_by_task: Dictionary = {}
var _preferred_option_id_by_task: Dictionary = {}
var _invalid_option_count := 0


func _ready() -> void:
	_apply_panel_style()
	_region_button.icon = CATALOG.resource_for_asset_key(
		&"icon.board.target"
	) as Texture2D
	_monster_button.icon = CATALOG.resource_for_asset_key(
		&"vfx.monster.attack_smoke"
	) as Texture2D
	_region_button.set_meta(
		"stable_asset_key",
		"icon.board.target"
	)
	_monster_button.set_meta(
		"stable_asset_key",
		"vfx.monster.attack_smoke"
	)
	_region_button.pressed.connect(
		_on_task_pressed.bind("assault_region")
	)
	_monster_button.pressed.connect(
		_on_task_pressed.bind("assault_monster")
	)
	_region_option.item_selected.connect(
		_on_option_selected.bind("assault_region")
	)
	_monster_option.item_selected.connect(
		_on_option_selected.bind("assault_monster")
	)
	_apply_button_style(_region_button)
	_apply_button_style(_monster_button)
	_apply_option_style(_region_option)
	_apply_option_style(_monster_option)
	if _options.is_empty():
		_render()


func configure(
	options: Array,
	owner_visible := true
) -> void:
	_preferred_option_id_by_task.clear()
	for task_kind in TASK_KINDS:
		var previous := _selected_by_task.get(task_kind, {}) as Dictionary
		if not previous.is_empty():
			_preferred_option_id_by_task[task_kind] = str(
				previous.get("option_id", "")
			)
	_options.clear()
	_selected_by_task.clear()
	for option_variant in options:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		if (
			str(option.get("task_kind", "")) in TASK_KINDS
			and not str(option.get("owner_player_id", "")).is_empty()
		):
			_options.append(option.duplicate(true))
	_owner_visible = owner_visible
	_render()


func debug_snapshot() -> Dictionary:
	var labels := [
		_region_button.text if is_instance_valid(_region_button) else "",
		_monster_button.text if is_instance_valid(_monster_button) else "",
	]
	var guard_count := 0
	for label in labels:
		if "保护" in label or "防守" in label or "guard" in label.to_lower():
			guard_count += 1
	return {
		"schema": "V075MilitaryMissionPanelDebugV1",
		"visible": visible,
		"owner_visible": _owner_visible,
		"task_button_count": 2,
		"task_kinds": TASK_KINDS.duplicate(),
		"option_identity_count": _selected_by_task.size(),
		"option_menu_item_count": (
			_region_option.item_count + _monster_option.item_count
			if is_instance_valid(_region_option) and is_instance_valid(_monster_option)
			else 0
		),
		"selected_option_ids": {
			"assault_region": str(
				(_selected_by_task.get("assault_region", {}) as Dictionary).get(
					"option_id", ""
				)
			),
			"assault_monster": str(
				(_selected_by_task.get("assault_monster", {}) as Dictionary).get(
					"option_id", ""
				)
			),
		},
		"invalid_option_count": _invalid_option_count,
		"guard_ui_count": guard_count,
		"bound_action_ui_count": 0,
		"military_skill_dock_count": 0,
		"persistent_source_ui_count": 0,
		"one_shot_withdrawal_copy_present": true,
	}


func _render() -> void:
	if (
		not is_instance_valid(_region_button)
		or not is_instance_valid(_region_option)
	):
		return
	visible = _owner_visible and not _options.is_empty()
	_selected_by_task.clear()
	_invalid_option_count = 0
	for task_kind in TASK_KINDS:
		var candidates: Array[Dictionary] = []
		for option in _options:
			if str(option.get("task_kind", "")) != task_kind:
				continue
			if _option_identity_valid(option):
				candidates.append(option)
			else:
				_invalid_option_count += 1
		candidates.sort_custom(_option_precedes)
		_populate_option_menu(task_kind, candidates)
	_sync_task_controls()


func _populate_option_menu(
	task_kind: String,
	candidates: Array[Dictionary]
) -> void:
	var menu := _menu_for_task(task_kind)
	menu.clear()
	var preferred_id := str(
		_preferred_option_id_by_task.get(task_kind, "")
	)
	var preferred_index := -1
	var first_enabled_index := -1
	for option in candidates:
		var index := menu.item_count
		menu.add_item(_option_menu_label(option))
		menu.set_item_metadata(index, option.duplicate(true))
		var enabled := bool(option.get("enabled", false))
		menu.set_item_disabled(index, not enabled)
		if enabled and first_enabled_index < 0:
			first_enabled_index = index
		if str(option.get("option_id", "")) == preferred_id:
			preferred_index = index
	var selected_index := preferred_index
	if selected_index < 0 or menu.is_item_disabled(selected_index):
		selected_index = first_enabled_index
	if selected_index < 0 and menu.item_count > 0:
		selected_index = 0
	if selected_index >= 0:
		menu.select(selected_index)
		_selected_by_task[task_kind] = (
			menu.get_item_metadata(selected_index) as Dictionary
		).duplicate(true)
	else:
		_selected_by_task.erase(task_kind)
	menu.disabled = menu.item_count == 0 or first_enabled_index < 0


func _sync_task_controls() -> void:
	for task_kind in TASK_KINDS:
		var option := _selected_by_task.get(task_kind, {}) as Dictionary
		var button := _button_for_task(task_kind)
		button.set_meta("selected_option", option.duplicate(true))
		button.tooltip_text = _option_tooltip(option)
		button.disabled = option.is_empty() or not bool(
			option.get("enabled", false)
		)
		button.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
			if not button.disabled
			else Control.CURSOR_FORBIDDEN
		)


func _on_option_selected(index: int, task_kind: String) -> void:
	if not _owner_visible or task_kind not in TASK_KINDS:
		return
	var menu := _menu_for_task(task_kind)
	if index < 0 or index >= menu.item_count:
		return
	var option := menu.get_item_metadata(index) as Dictionary
	if not _option_identity_valid(option) or not bool(option.get("enabled", false)):
		_invalid_option_count += 1
		return
	_selected_by_task[task_kind] = option.duplicate(true)
	_preferred_option_id_by_task[task_kind] = str(option.get("option_id", ""))
	_sync_task_controls()


func select_option_id(task_kind: String, option_id: String) -> bool:
	if task_kind not in TASK_KINDS or option_id.is_empty():
		return false
	var menu := _menu_for_task(task_kind)
	for index in range(menu.item_count):
		var option := menu.get_item_metadata(index) as Dictionary
		if (
			str(option.get("option_id", "")) == option_id
			and _option_identity_valid(option)
			and bool(option.get("enabled", false))
		):
			menu.select(index)
			_on_option_selected(index, task_kind)
			return true
	return false


func _menu_for_task(task_kind: String) -> OptionButton:
	return _region_option if task_kind == "assault_region" else _monster_option




func _option_menu_label(option: Dictionary) -> String:
	var task_kind := str(option.get("task_kind", ""))
	var target := (
		str(option.get("target_region_id", ""))
		if task_kind == "assault_region"
		else str(option.get("target_monster_source_instance_id", ""))
	)
	return "%s · %s" % [
		"地区目标" if task_kind == "assault_region" else "怪兽目标",
		target,
	]


func _on_task_pressed(task_kind: String) -> void:
	if not _owner_visible or task_kind not in TASK_KINDS:
		return
	var button := (
		_region_button
		if task_kind == "assault_region"
		else _monster_button
	)
	if button.disabled:
		return
	var option := button.get_meta("selected_option", {}) as Dictionary
	if not _option_identity_valid(option):
		return
	mission_selected.emit(option.duplicate(true))


func _button_for_task(task_kind: String) -> Button:
	return _region_button if task_kind == "assault_region" else _monster_button


func _option_identity_valid(option: Dictionary) -> bool:
	var task_kind := str(option.get("task_kind", ""))
	if task_kind not in TASK_KINDS:
		return false
	for field_name in [
		"option_id",
		"owner_player_id",
		"card_instance_id",
		"card_definition_id",
		"target_slot_id",
	]:
		if str(option.get(field_name, "")).is_empty():
			return false
	if option.has("card_generation") and int(option.get("card_generation", 0)) < 1:
		return false
	if task_kind == "assault_region":
		return not str(option.get("target_region_id", "")).is_empty()
	var target_id := str(
		option.get("target_monster_source_instance_id", "")
	)
	if target_id.is_empty():
		return false
	if option.has("target_source_generation") and int(
		option.get("target_source_generation", 0)
	) < 1:
		return false
	return true


func _option_precedes(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("option_id", "")) < str(right.get("option_id", ""))


func _option_tooltip(option: Dictionary) -> String:
	var task := str(option.get("task_kind", ""))
	var target := (
		str(option.get("target_region_id", ""))
		if task == "assault_region"
		else str(option.get("target_monster_source_instance_id", ""))
	)
	return "%s · %s · %s" % [
		str(option.get("card_definition_id", "军队")),
		target,
		str(option.get("option_id", "")),
	]


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.055, 0.075, 0.97)
	style.border_color = Color(0.64, 0.35, 0.31, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)
	set_meta("stable_asset_key", "ui.panel.primary")


func _apply_button_style(button: Button) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.expand_icon = true
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.095, 0.075, 0.075, 0.98)
	normal.border_color = Color("#714943")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.17, 0.09, 0.08, 1.0)
	hover.border_color = Color("#df806f")
	hover.set_border_width_all(2)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.045, 0.045, 0.055, 0.9)
	disabled.border_color = Color(0.25, 0.25, 0.29, 0.7)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled)


func _apply_option_style(menu: OptionButton) -> void:
	menu.custom_minimum_size = Vector2(144.0, 30.0)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.fit_to_longest_item = false
	menu.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	menu.tooltip_text = "选择已预绑定的军队牌与目标"
