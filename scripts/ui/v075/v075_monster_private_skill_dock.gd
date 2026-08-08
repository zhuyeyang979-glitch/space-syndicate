extends PanelContainer
class_name V075MonsterPrivateSkillDock

signal private_target_selection_requested(request: Dictionary)

const CATALOG := preload(
	"res://resources/presentation/alpha01_card_illustration_catalog.tres"
)
const COLOR_IDS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]
const COLOR_VALUES := {
	"life": Color("#76d89b"),
	"energy": Color("#f3cd68"),
	"industry": Color("#f08a74"),
	"technology": Color("#7fb6ff"),
	"commerce": Color("#d993ef"),
	"shipping": Color("#67d8d5"),
}
const STATE_LABELS := {
	"READY": "就绪",
	"PENDING_SAFE_BOUNDARY": "等待安全边界",
	"RESOLVING": "结算中",
	"COOLDOWN": "冷却",
	"DISABLED": "不可用",
	"LOCKED_BY_RANK": "等级锁定",
	"REVOKED": "已撤销",
}
const TARGET_LABELS := {
	"none": "无需目标",
	"self": "自身",
	"enemy_facility": "敌方设施",
	"enemy_monster": "敌方怪兽",
	"region": "地区",
	"self_source": "自身",
	"enemy_public_facility": "敌方设施",
	"enemy_public_monster": "敌方怪兽",
	"enemy_facilities_in_public_region": "地区",
	"enemy_facilities_in_current_region": "当前地区",
}

@onready var _title_label: Label = %TitleLabel
@onready var _privacy_badge: Label = %PrivacyBadge
@onready var _empty_label: Label = %EmptyLabel
@onready var _skill_scroll: ScrollContainer = %SkillScroll
@onready var _skill_cards: HBoxContainer = %SkillCards

var _source: Dictionary = {}
var _owner_visible := false
var _requests_allowed := false
var _rendered_cost_pip_count := 0
var _state_counts: Dictionary = {}
var _invalid_target_binding_count := 0


func _ready() -> void:
	_apply_panel_style()
	_privacy_badge.set_meta(
		"accessibility_label",
		"怪兽技能牌仅当前所有者可见"
	)
	if _source.is_empty():
		_render()


func configure(
	skill_source: Dictionary,
	owner_visible: bool,
	requests_allowed: bool
) -> void:
	var source_identity_valid := (
		owner_visible
		and not str(skill_source.get("source_instance_id", "")).is_empty()
		and _positive_int_field(skill_source, "source_generation")
		and not str(skill_source.get("owner_player_id", "")).is_empty()
	)
	_source = skill_source.duplicate(true) if source_identity_valid else {}
	_owner_visible = source_identity_valid
	_requests_allowed = requests_allowed
	_render()


func clear_private_data() -> void:
	_source.clear()
	_owner_visible = false
	_requests_allowed = false
	_render()


func debug_snapshot() -> Dictionary:
	return {
		"schema": "V075MonsterPrivateSkillDockDebugV1",
		"owner_visible": _owner_visible,
		"visible": visible,
		"source_instance_id": (
			str(_source.get("source_instance_id", ""))
			if _owner_visible
			else ""
		),
		"skill_card_count": (
			_skill_cards.get_child_count()
			if is_instance_valid(_skill_cards)
			else 0
		),
		"rendered_cost_pip_count": _rendered_cost_pip_count,
		"state_counts": _state_counts.duplicate(true),
		"ultimate_card_count": _ultimate_card_count(),
		"public_batch_queue_member": false,
		"normal_hand_member": false,
		"private_target_signal_contract": true,
		"private_target_binding_dictionary": true,
		"invalid_target_binding_count": _invalid_target_binding_count,
		"gameplay_mutation_count": 0,
		"rng_draw_count": 0,
	}


func _render() -> void:
	if not is_instance_valid(_skill_cards):
		return
	_clear_children(_skill_cards)
	_rendered_cost_pip_count = 0
	_state_counts.clear()
	_invalid_target_binding_count = 0
	visible = _owner_visible
	if not _owner_visible:
		return
	var monster_name := str(
		_source.get("monster_display_name", "怪兽")
	)
	_title_label.text = "%s · 私密技能" % monster_name
	var skills := _source.get("skills", []) as Array
	for skill_variant in skills:
		if not (skill_variant is Dictionary):
			continue
		var skill := skill_variant as Dictionary
		var target_binding := skill.get("target_binding", {}) as Dictionary
		if not _target_binding_valid(skill, target_binding):
			_invalid_target_binding_count += 1
			continue
		_skill_cards.add_child(_build_skill_card(skill))
	var rendered_skill_count := _skill_cards.get_child_count()
	_empty_label.visible = rendered_skill_count == 0
	_skill_scroll.visible = rendered_skill_count > 0


func _build_skill_card(skill: Dictionary) -> Button:
	var state := str(skill.get("state", "DISABLED"))
	_state_counts[state] = int(_state_counts.get(state, 0)) + 1
	var can_request := (
		_requests_allowed
		and bool(skill.get("can_request", false))
		and state == "READY"
	)
	var target_binding := skill.get("target_binding", {}) as Dictionary
	if not _target_binding_valid(skill, target_binding):
		can_request = false
	var button := Button.new()
	button.name = "Skill_%s" % _safe_node_name(
		str(skill.get("skill_definition_id", "unknown"))
	)
	button.custom_minimum_size = Vector2(148.0, 116.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
		if can_request
		else Control.CURSOR_FORBIDDEN
	)
	button.disabled = not can_request
	button.text = ""
	button.set_meta(
		"skill_definition_id",
		str(skill.get("skill_definition_id", ""))
	)
	button.set_meta(
		"target_binding",
		target_binding.duplicate(true)
	)
	button.set_meta("skill_state", state)
	button.set_meta(
		"asset_cost_by_color",
		(skill.get("asset_cost_by_color", {}) as Dictionary).duplicate(true)
	)
	button.set_meta("ultimate", bool(skill.get("ultimate", false)))
	button.tooltip_text = _tooltip_text(skill)
	button.set_meta("accessibility_label", button.tooltip_text)
	_apply_skill_style(button, state, bool(skill.get("ultimate", false)))
	button.pressed.connect(
		_on_skill_pressed.bind(_skill_request(skill, target_binding))
	)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 7)
	button.add_child(margin)

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 4)
	margin.add_child(rows)

	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_theme_constant_override("separation", 4)
	rows.add_child(name_row)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = str(skill.get("display_name", "未命名技能"))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 14)
	name_row.add_child(name_label)
	if bool(skill.get("ultimate", false)):
		var ultimate_label := Label.new()
		ultimate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ultimate_label.text = "终极"
		ultimate_label.add_theme_color_override(
			"font_color",
			Color("#ffd779")
		)
		ultimate_label.add_theme_font_size_override("font_size", 11)
		name_row.add_child(ultimate_label)

	var state_label := Label.new()
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_label.text = _state_text(skill)
	state_label.add_theme_color_override(
		"font_color",
		_state_color(state)
	)
	state_label.add_theme_font_size_override("font_size", 12)
	rows.add_child(state_label)

	var target_label := Label.new()
	target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_label.text = "目标 · %s" % str(
		TARGET_LABELS.get(
			_target_kind(skill),
			"指定目标"
		)
	)
	target_label.add_theme_color_override(
		"font_color",
		Color("#aebed1")
	)
	target_label.add_theme_font_size_override("font_size", 11)
	rows.add_child(target_label)

	var cost_row := HBoxContainer.new()
	cost_row.name = "CostPips"
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_theme_constant_override("separation", 2)
	rows.add_child(cost_row)
	var cost_caption := Label.new()
	cost_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_caption.text = "消耗"
	cost_caption.add_theme_color_override(
		"font_color",
		Color("#8194aa")
	)
	cost_caption.add_theme_font_size_override("font_size", 10)
	cost_row.add_child(cost_caption)
	_populate_cost_pips(
		cost_row,
		skill.get("asset_cost_by_color", {}) as Dictionary
	)
	return button


func _populate_cost_pips(
	row: HBoxContainer,
	cost_by_color: Dictionary
) -> void:
	var pip_count := 0
	for color_id in COLOR_IDS:
		var amount := maxi(0, int(cost_by_color.get(color_id, 0)))
		for _pip_index in range(amount):
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(14.0, 14.0)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.texture = CATALOG.resource_for_asset_key(
				StringName("icon.asset.%s" % color_id)
			) as Texture2D
			icon.modulate = COLOR_VALUES.get(color_id, Color.WHITE)
			icon.set_meta("asset_color_id", color_id)
			icon.set_meta(
				"stable_asset_key",
				"icon.asset.%s" % color_id
			)
			row.add_child(icon)
			pip_count += 1
			_rendered_cost_pip_count += 1
	if pip_count == 0:
		var free_label := Label.new()
		free_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		free_label.text = "无"
		free_label.add_theme_color_override(
			"font_color",
			Color("#80d8ae")
		)
		free_label.add_theme_font_size_override("font_size", 10)
		row.add_child(free_label)


func _state_text(skill: Dictionary) -> String:
	var state := str(skill.get("state", "DISABLED"))
	if state == "COOLDOWN":
		return "%s · %d批" % [
			STATE_LABELS[state],
			maxi(0, int(skill.get("cooldown_remaining_batches", 0))),
		]
	return str(STATE_LABELS.get(state, state))


func _tooltip_text(skill: Dictionary) -> String:
	var cost_parts: Array[String] = []
	var costs := skill.get("asset_cost_by_color", {}) as Dictionary
	for color_id in COLOR_IDS:
		var amount := int(costs.get(color_id, 0))
		if amount > 0:
			cost_parts.append("%s%d" % [color_id, amount])
	return "%s；状态%s；目标%s；消耗%s；冷却剩余%d批%s" % [
		str(skill.get("display_name", "未命名技能")),
		_state_text(skill),
		str(
			TARGET_LABELS.get(
				_target_kind(skill),
				"指定目标"
			)
		),
		"、".join(cost_parts) if not cost_parts.is_empty() else "无",
		maxi(0, int(skill.get("cooldown_remaining_batches", 0))),
		"；终极技能" if bool(skill.get("ultimate", false)) else "",
	]


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.09, 0.96)
	style.border_color = Color(0.35, 0.67, 0.82, 0.68)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)
	set_meta("stable_asset_key", "ui.panel.primary")


func _apply_skill_style(
	button: Button,
	state: String,
	ultimate: bool
) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.085, 0.13, 0.98)
	normal.border_color = (
		Color("#d9b75c")
		if ultimate
		else Color("#36546d")
	)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.075, 0.12, 0.18, 1.0)
	hover.border_color = _state_color(state)
	hover.set_border_width_all(2)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.035, 0.05, 0.075, 0.92)
	disabled.border_color = Color(0.22, 0.28, 0.35, 0.7)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled)


func _state_color(state: String) -> Color:
	match state:
		"READY":
			return Color("#72dda7")
		"COOLDOWN":
			return Color("#f0bd63")
		"PENDING_SAFE_BOUNDARY", "RESOLVING":
			return Color("#72c7ef")
		"LOCKED_BY_RANK":
			return Color("#9e88cb")
		_:
			return Color("#8793a2")


func _ultimate_card_count() -> int:
	var count := 0
	for skill_variant in _source.get("skills", []) as Array:
		if (
			skill_variant is Dictionary
			and bool((skill_variant as Dictionary).get("ultimate", false))
		):
			count += 1
	return count


func _on_skill_pressed(request: Dictionary) -> void:
	if not _owner_visible or not _requests_allowed:
		return
	var source_instance_id := str(request.get("source_instance_id", ""))
	var skill_definition_id := str(request.get("skill_definition_id", ""))
	var target_binding := request.get("target_binding", {}) as Dictionary
	if (
		source_instance_id.is_empty()
		or skill_definition_id.is_empty()
		or not _positive_int_field(request, "source_generation")
		or not _target_binding_valid(request, target_binding)
	):
		return
	private_target_selection_requested.emit(request.duplicate(true))


func _skill_request(skill: Dictionary, target_binding: Dictionary) -> Dictionary:
	return {
		"source_instance_id": str(_source.get("source_instance_id", "")),
		"source_generation": int(_source.get("source_generation", 0)),
		"skill_definition_id": str(skill.get("skill_definition_id", "")),
		"target_binding": target_binding.duplicate(true),
		"target_contract": (
			(skill.get("target_contract", {}) as Dictionary).duplicate(true)
			if skill.get("target_contract", {}) is Dictionary
			else {}
		),
	}


func _target_kind(skill: Dictionary) -> String:
	var contract: Variant = skill.get("target_contract", {})
	if contract is Dictionary:
		return str((contract as Dictionary).get("target_kind", "none"))
	return str(contract)


func _target_binding_valid(skill: Dictionary, binding: Dictionary) -> bool:
	var target_kind := _target_kind(skill)
	var binding_kind := str(binding.get("target_kind", ""))
	var target_id := str(binding.get("target_id", ""))
	if binding.is_empty() or target_id.is_empty():
		return false
	if target_kind in ["self", "self_source"]:
		return (
			binding_kind == "monster"
			and target_id == str(_source.get("source_instance_id", ""))
			and _positive_int_field(binding, "target_source_generation")
			and binding.get("target_source_generation")
				== _source.get("source_generation")
			and not binding.has("target_facility_id")
			and not binding.has("target_region_id")
			and (
				not binding.has("target_monster_source_instance_id")
				or str(binding.get(
					"target_monster_source_instance_id",
					""
				)) == target_id
			)
		)
	if target_kind == "enemy_public_facility":
		return (
			binding_kind == "facility"
			and str(binding.get("target_facility_id", "")) == target_id
			and _positive_int_field(
				binding,
				"target_facility_generation"
			)
			and not binding.has("target_region_id")
			and not binding.has("target_monster_source_instance_id")
			and not binding.has("target_source_generation")
		)
	if target_kind in [
		"enemy_facilities_in_public_region",
		"enemy_facilities_in_current_region",
	]:
		return (
			binding_kind == "region"
			and str(binding.get("target_region_id", "")) == target_id
			and not binding.has("target_facility_id")
			and not binding.has("target_facility_generation")
			and not binding.has("target_monster_source_instance_id")
			and not binding.has("target_source_generation")
		)
	if target_kind == "enemy_public_monster":
		return (
			binding_kind == "monster"
			and _positive_int_field(binding, "target_source_generation")
			and not binding.has("target_facility_id")
			and not binding.has("target_facility_generation")
			and not binding.has("target_region_id")
			and (
				not binding.has("target_monster_source_instance_id")
				or str(binding.get(
					"target_monster_source_instance_id",
					""
				)) == target_id
			)
		)
	return false


func _positive_int_field(source: Dictionary, field_name: String) -> bool:
	return (
		source.has(field_name)
		and typeof(source.get(field_name)) == TYPE_INT
		and int(source.get(field_name)) > 0
	)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _safe_node_name(value: String) -> String:
	var result := ""
	for character in value:
		var code := character.unicode_at(0)
		var valid := (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or character in ["_", "-"]
		)
		result += character if valid else "_"
	return result
