extends PanelContainer
class_name V075MilitaryMissionPanel

signal mission_selected(task_kind: String)

const CATALOG := preload(
	"res://resources/presentation/alpha01_card_illustration_catalog.tres"
)
const TASK_KINDS := [
	"assault_region",
	"assault_monster",
]

@onready var _region_button: Button = %AssaultRegionButton
@onready var _monster_button: Button = %AssaultMonsterButton

var _owner_visible := false
var _options: Array[Dictionary] = []


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
	_apply_button_style(_region_button)
	_apply_button_style(_monster_button)
	if _options.is_empty():
		_render()


func configure(
	options: Array,
	owner_visible := true
) -> void:
	_options.clear()
	for option_variant in options:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		if str(option.get("task_kind", "")) in TASK_KINDS:
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
		"guard_ui_count": guard_count,
		"bound_action_ui_count": 0,
		"military_skill_dock_count": 0,
		"persistent_source_ui_count": 0,
		"one_shot_withdrawal_copy_present": true,
	}


func _render() -> void:
	if not is_instance_valid(_region_button):
		return
	visible = _owner_visible and not _options.is_empty()
	var enabled_by_kind := {
		"assault_region": false,
		"assault_monster": false,
	}
	for option in _options:
		var task_kind := str(option.get("task_kind", ""))
		enabled_by_kind[task_kind] = bool(option.get("enabled", false))
	_region_button.disabled = not bool(
		enabled_by_kind.get("assault_region", false)
	)
	_monster_button.disabled = not bool(
		enabled_by_kind.get("assault_monster", false)
	)
	_region_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
		if not _region_button.disabled
		else Control.CURSOR_FORBIDDEN
	)
	_monster_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
		if not _monster_button.disabled
		else Control.CURSOR_FORBIDDEN
	)


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
	mission_selected.emit(task_kind)


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
