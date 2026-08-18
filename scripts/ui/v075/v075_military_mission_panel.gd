extends PanelContainer
class_name V075MilitaryMissionPanel

signal mission_selected(option: Dictionary)

const CardDefinitionRegistry := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)
const CapabilityCatalog := preload(
	"res://scripts/v075/combat/v075_combat_capability_catalog.gd"
)
const TASK_KINDS := CapabilityCatalog.MILITARY_MISSION_KINDS

@onready var _region_button: Button = %AssaultRegionButton
@onready var _monster_button: Button = %AssaultMonsterButton
@onready var _region_option: OptionButton = %AssaultRegionOption
@onready var _monster_option: OptionButton = %AssaultMonsterOption

var _owner_visible := false
var _options: Array[Dictionary] = []
var _selected_by_task: Dictionary = {}
var _preferred_option_by_task: Dictionary = {}
var _invalid_option_count := 0
var _presentation_binding_failure_count := 0


func _ready() -> void:
	_apply_panel_style()
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
	_preferred_option_by_task.clear()
	for task_kind in TASK_KINDS:
		var previous := _selected_by_task.get(task_kind, {}) as Dictionary
		if not previous.is_empty():
			_preferred_option_by_task[task_kind] = previous.duplicate(true)
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
		"presentation_binding_failure_count": (
			_presentation_binding_failure_count
		),
		"button_presentation_bindings": {
			"assault_region": _button_presentation_debug(_region_button),
			"assault_monster": _button_presentation_debug(_monster_button),
		},
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
	_presentation_binding_failure_count = 0
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
	var preferred := _preferred_option_by_task.get(task_kind, {}) as Dictionary
	var preferred_index := -1
	var first_enabled_index := -1
	for option in candidates:
		var index := menu.item_count
		menu.add_item(_option_menu_label(option))
		menu.set_item_metadata(index, option.duplicate(true))
		var icon := _presentation_texture(option)
		menu.set_item_icon(index, icon)
		var presentation_green := icon != null
		if not presentation_green:
			_presentation_binding_failure_count += 1
		var enabled := (
			bool(option.get("enabled", false)) and presentation_green
		)
		menu.set_item_disabled(index, not enabled)
		if enabled and first_enabled_index < 0:
			first_enabled_index = index
		if (
			not preferred.is_empty()
			and _same_option_identity(option, preferred)
		):
			preferred_index = index
	var selected_index := preferred_index
	if selected_index >= 0 and not menu.is_item_disabled(selected_index):
		menu.select(selected_index)
		_selected_by_task[task_kind] = (
			menu.get_item_metadata(selected_index) as Dictionary
		).duplicate(true)
	else:
		menu.select(-1)
		_selected_by_task.erase(task_kind)
	menu.disabled = menu.item_count == 0 or first_enabled_index < 0


func _sync_task_controls() -> void:
	for task_kind in TASK_KINDS:
		var option := _selected_by_task.get(task_kind, {}) as Dictionary
		var button := _button_for_task(task_kind)
		button.set_meta("selected_option", option.duplicate(true))
		_bind_button_presentation(button, option)
		button.tooltip_text = _option_tooltip(option)
		button.disabled = option.is_empty() or not bool(
			option.get("enabled", false)
		) or not _option_presentation_green(option)
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
	if (
		not _option_identity_valid(option)
		or not _option_presentation_green(option)
		or not bool(option.get("enabled", false))
	):
		_invalid_option_count += 1
		return
	_selected_by_task[task_kind] = option.duplicate(true)
	_preferred_option_by_task[task_kind] = option.duplicate(true)
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
			and _option_presentation_green(option)
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


func _presentation_descriptor(option: Dictionary) -> Dictionary:
	var descriptor := CardDefinitionRegistry.presentation_descriptor(
		str(option.get("card_definition_id", ""))
	)
	if descriptor.is_empty():
		return {}
	if (
		str(descriptor.get("domain", "")) != "military"
		or not CardDefinitionRegistry.presentation_descriptor_error(
			descriptor
		).is_empty()
	):
		return {}
	return descriptor


func _presentation_texture(option: Dictionary) -> Texture2D:
	var descriptor := _presentation_descriptor(option)
	if descriptor.is_empty():
		return null
	return CardDefinitionRegistry.presentation_texture(
		str(option.get("card_definition_id", ""))
	)


func _option_presentation_green(option: Dictionary) -> bool:
	return not _presentation_descriptor(option).is_empty() \
		and _presentation_texture(option) != null


func _bind_button_presentation(button: Button, option: Dictionary) -> void:
	button.icon = null
	for meta_key in [
		"bound_card_definition_id",
		"presentation_asset_key",
		"presentation_resource_path",
	]:
		if button.has_meta(meta_key):
			button.remove_meta(meta_key)
	var descriptor := _presentation_descriptor(option)
	var texture := _presentation_texture(option)
	if descriptor.is_empty() or texture == null:
		return
	button.icon = texture
	button.set_meta(
		"bound_card_definition_id",
		str(option.get("card_definition_id", ""))
	)
	button.set_meta(
		"presentation_asset_key",
		str(descriptor.get("presentation_asset_key", ""))
	)
	button.set_meta(
		"presentation_resource_path",
		str(descriptor.get("resource_path", ""))
	)


func _button_presentation_debug(button: Button) -> Dictionary:
	if not is_instance_valid(button):
		return {}
	return {
		"card_definition_id": str(
			button.get_meta("bound_card_definition_id", "")
		),
		"presentation_asset_key": str(
			button.get_meta("presentation_asset_key", "")
		),
		"resource_path": str(
			button.get_meta("presentation_resource_path", "")
		),
		"texture_bound": button.icon != null,
		"texture_resource_path": (
			str(button.icon.resource_path) if button.icon != null else ""
		),
	}


func _option_identity_valid(option: Dictionary) -> bool:
	var task_kind := str(option.get("task_kind", ""))
	if (
		task_kind not in TASK_KINDS
		or str(option.get("action_domain", "")) != "military"
	):
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
	if not _card_action_binding_valid(option):
		return false
	if task_kind == "assault_region":
		return (
			not str(option.get("target_region_id", "")).is_empty()
			and str(option.get(
				"target_monster_source_instance_id",
				""
			)).is_empty()
			and not option.has("target_source_generation")
		)
	var target_id := str(
		option.get("target_monster_source_instance_id", "")
	)
	if target_id.is_empty():
		return false
	if not _positive_int_field(option, "target_source_generation"):
		return false
	return str(option.get("target_region_id", "")).is_empty()


func _same_option_identity(left: Dictionary, right: Dictionary) -> bool:
	for field_name in [
		"option_id",
		"owner_player_id",
		"card_instance_id",
		"card_definition_id",
		"target_slot_id",
		"task_kind",
		"target_region_id",
		"target_monster_source_instance_id",
		"action_domain",
	]:
		if str(left.get(field_name, "")) != str(right.get(field_name, "")):
			return false
	if (
		not _card_action_binding_valid(left)
		or not _card_action_binding_valid(right)
		or left.get("card_action_binding") != right.get("card_action_binding")
	):
		return false
	if str(left.get("task_kind", "")) == "assault_region":
		return (
			not left.has("target_source_generation")
			and not right.has("target_source_generation")
		)
	return (
		_positive_int_field(left, "target_source_generation")
		and _positive_int_field(right, "target_source_generation")
		and left.get("target_source_generation")
			== right.get("target_source_generation")
	)


func _card_action_binding_valid(option: Dictionary) -> bool:
	var binding_variant: Variant = option.get("card_action_binding")
	if not (binding_variant is Dictionary):
		return false
	var binding := binding_variant as Dictionary
	return (
		not binding.is_empty()
		and str(binding.get("owner_player_id", ""))
			== str(option.get("owner_player_id", ""))
		and str(binding.get("card_instance_id", ""))
			== str(option.get("card_instance_id", ""))
		and str(binding.get("card_definition_id", ""))
			== str(option.get("card_definition_id", ""))
		and binding.get("authoritative_zone") == "hand"
		and _positive_int_field(binding, "zone_revision")
		and str(binding.get("binding_fingerprint", "")).length() == 64
	)


func _positive_int_field(source: Dictionary, field_name: String) -> bool:
	return (
		source.has(field_name)
		and typeof(source.get(field_name)) == TYPE_INT
		and int(source.get(field_name)) > 0
	)


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
