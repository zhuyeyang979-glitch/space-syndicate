extends Control
class_name V075CombatPlayerSurface

signal private_target_selection_requested(
	source_instance_id: String,
	skill_definition_id: String,
	target_contract: String
)
signal military_mission_selected(task_kind: String)

const CATALOG := preload(
	"res://resources/presentation/alpha01_card_illustration_catalog.tres"
)
const COLOR_LABELS := {
	"life": "生命",
	"energy": "能源",
	"industry": "工业",
	"technology": "科技",
	"commerce": "商业",
	"shipping": "航运",
}
const COLOR_VALUES := {
	"life": Color("#76d89b"),
	"energy": Color("#f3cd68"),
	"industry": Color("#f08a74"),
	"technology": Color("#7fb6ff"),
	"commerce": Color("#d993ef"),
	"shipping": Color("#67d8d5"),
}
const RANK_LABELS := ["", "I", "II", "III", "IV"]

@onready var _public_panel: PanelContainer = %PublicMonsterPanel
@onready var _name_label: Label = %MonsterName
@onready var _rank_label: Label = %MonsterRank
@onready var _status_label: Label = %MonsterStatus
@onready var _preferred_icon: TextureRect = %PreferredColorIcon
@onready var _preferred_label: Label = %PreferredColorLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _armor_label: Label = %ArmorLabel
@onready var _region_label: Label = %RegionLabel
@onready var _target_label: Label = %TargetLabel
@onready var _path_label: Label = %PathLabel
@onready var _unlocked_label: Label = %UnlockedSkillCount
@onready var _batch_used_badge: Label = %BatchUsedBadge
@onready var _private_grid: GridContainer = %PrivateGrid
@onready var _skill_dock: V075MonsterPrivateSkillDock = %SkillDock
@onready var _military_panel: V075MilitaryMissionPanel = %MilitaryPanel
@onready var _presentation_strip: PanelContainer = %PresentationStrip
@onready var _presentation_label: Label = %PresentationLabel

var _projection: Dictionary = {}
var _selected_public_monster: Dictionary = {}
var _layout_mode := "COMPACT"
var _viewer_is_owner := false
var _last_cue: Dictionary = {}
var _presentation_cue_fingerprints: Dictionary = {}
var _presentation_cue_applied_count := 0
var _presentation_cue_duplicate_count := 0
var _presentation_cue_collision_count := 0
var _presentation_cue_rejected_count := 0


func _ready() -> void:
	_apply_styles()
	_skill_dock.private_target_selection_requested.connect(
		_on_private_target_selection_requested
	)
	_military_panel.mission_selected.connect(
		_on_military_mission_selected
	)
	resized.connect(_resolve_layout)
	_resolve_layout()
	if _projection.is_empty():
		_render_empty()


func apply_projection(
	projection: Dictionary,
	preferred_source_instance_id := ""
) -> void:
	_projection = projection.duplicate(true)
	_selected_public_monster = _select_public_monster(
		projection.get("public_monsters", []) as Array,
		preferred_source_instance_id
	)
	_render_public_monster()
	_render_private_surfaces()
	_resolve_layout()


func show_presentation_cue(cue: Dictionary) -> Dictionary:
	var cue_id := str(cue.get("presentation_receipt_id", ""))
	if cue_id.is_empty():
		_presentation_cue_rejected_count += 1
		return _presentation_cue_result(
			false,
			"presentation_cue_identity_missing"
		)
	var fingerprint := _canonical_cue_json(cue).sha256_text()
	if _presentation_cue_fingerprints.has(cue_id):
		if str(_presentation_cue_fingerprints.get(cue_id, "")) == fingerprint:
			_presentation_cue_duplicate_count += 1
			return _presentation_cue_result(
				false,
				"presentation_cue_duplicate"
			)
		_presentation_cue_collision_count += 1
		return _presentation_cue_result(
			false,
			"presentation_cue_identity_collision"
		)
	if _count_private_skill_keys(cue) > 0:
		_presentation_cue_rejected_count += 1
		return _presentation_cue_result(
			false,
			"presentation_cue_private_field_rejected"
		)
	_presentation_cue_fingerprints[cue_id] = fingerprint
	_presentation_cue_applied_count += 1
	_last_cue = cue.duplicate(true)
	var payload := cue.get("public_payload", {}) as Dictionary
	var summary := str(payload.get("public_summary", ""))
	if summary.is_empty():
		summary = _cue_summary(str(cue.get("event_kind", "")), payload)
	_presentation_label.text = summary
	_presentation_strip.visible = not summary.is_empty()
	return _presentation_cue_result(true, "none")


func reset_presentation_cues() -> void:
	_presentation_cue_fingerprints.clear()
	_presentation_cue_applied_count = 0
	_presentation_cue_duplicate_count = 0
	_presentation_cue_collision_count = 0
	_presentation_cue_rejected_count = 0
	_last_cue = {}
	_presentation_label.text = ""
	_presentation_strip.visible = false


func debug_snapshot() -> Dictionary:
	var skill_debug := (
		_skill_dock.debug_snapshot()
		if is_instance_valid(_skill_dock)
		else {}
	)
	var military_debug := (
		_military_panel.debug_snapshot()
		if is_instance_valid(_military_panel)
		else {}
	)
	return {
		"schema": "V075CombatPlayerSurfaceDebugV1",
		"layout_mode": _layout_mode,
		"private_grid_columns": (
			_private_grid.columns
			if is_instance_valid(_private_grid)
			else 0
		),
		"viewer_is_owner": _viewer_is_owner,
		"selected_source_instance_id": str(
			_selected_public_monster.get("source_instance_id", "")
		),
		"public_monster_visible": _public_panel.visible,
		"public_preferred_color_visible":
			not _preferred_label.text.is_empty(),
		"public_projected_path_visible":
			not _path_label.text.is_empty(),
		"public_unlocked_skill_count_visible":
			not _unlocked_label.text.is_empty(),
		"owner_skill_dock": skill_debug,
		"military_panel": military_debug,
		"public_skill_card_disclosure_count":
			_public_skill_disclosure_count(),
		"military_guard_ui_count": int(
			military_debug.get("guard_ui_count", 0)
		),
		"military_task_button_count": int(
			military_debug.get("task_button_count", 0)
		),
		"military_task_kinds": (
			military_debug.get("task_kinds", []) as Array
		).duplicate(),
		"military_bound_action_ui_count": int(
			military_debug.get("bound_action_ui_count", 0)
		),
		"special_support_placeholder_count": 0,
		"presentation_cue_identity_count":
			_presentation_cue_fingerprints.size(),
		"presentation_cue_applied_count":
			_presentation_cue_applied_count,
		"presentation_cue_duplicate_count":
			_presentation_cue_duplicate_count,
		"presentation_cue_collision_count":
			_presentation_cue_collision_count,
		"presentation_cue_rejected_count":
			_presentation_cue_rejected_count,
		"last_presentation_cue_id": str(
			_last_cue.get("presentation_receipt_id", "")
		),
		"presentation_gameplay_mutation_count": 0,
		"presentation_rng_draw_delta": 0,
	}


func _select_public_monster(
	monsters: Array,
	preferred_source_instance_id: String
) -> Dictionary:
	if not preferred_source_instance_id.is_empty():
		for source_variant in monsters:
			if (
				source_variant is Dictionary
				and str(
					(source_variant as Dictionary).get(
						"source_instance_id",
						""
					)
				) == preferred_source_instance_id
			):
				return (source_variant as Dictionary).duplicate(true)
	for source_variant in monsters:
		if source_variant is Dictionary:
			return (source_variant as Dictionary).duplicate(true)
	return {}


func _render_public_monster() -> void:
	if _selected_public_monster.is_empty():
		_render_empty()
		return
	_public_panel.visible = true
	var rank := clampi(
		int(_selected_public_monster.get("rank", 1)),
		1,
		4
	)
	var status := str(
		_selected_public_monster.get("status", "active")
	)
	var color_id := str(
		_selected_public_monster.get(
			"preferred_industry_color",
			""
		)
	)
	var hp := maxi(0, int(_selected_public_monster.get("hp", 0)))
	var max_hp := maxi(
		1,
		int(_selected_public_monster.get("max_hp", 1))
	)
	_name_label.text = str(
		_selected_public_monster.get("display_name", "未命名怪兽")
	)
	_rank_label.text = "L%d · %s" % [rank, RANK_LABELS[rank]]
	_status_label.text = _status_text(status)
	_status_label.add_theme_color_override(
		"font_color",
		_status_color(status)
	)
	_preferred_icon.texture = CATALOG.resource_for_asset_key(
		StringName("icon.asset.%s" % color_id)
	) as Texture2D
	_preferred_icon.modulate = COLOR_VALUES.get(color_id, Color.WHITE)
	_preferred_icon.set_meta(
		"stable_asset_key",
		"icon.asset.%s" % color_id
	)
	_preferred_label.text = "偏好 · %s" % str(
		COLOR_LABELS.get(color_id, color_id)
	)
	_hp_bar.max_value = max_hp
	_hp_bar.value = clampi(hp, 0, max_hp)
	_hp_label.text = "HP %d / %d" % [hp, max_hp]
	_armor_label.text = "护甲 %d" % maxi(
		0,
		int(_selected_public_monster.get("armor", 0))
	)
	_region_label.text = "当前 · %s" % str(
		_selected_public_monster.get("region_id", "未知地区")
	)
	var tracked_region := str(
		_selected_public_monster.get("tracked_region_id", "")
	)
	var tracked_facility := str(
		_selected_public_monster.get("tracked_facility_id", "")
	)
	_target_label.text = (
		"追踪 · %s%s"
		% [
			tracked_region if not tracked_region.is_empty() else "待机",
			" / %s" % tracked_facility
				if not tracked_facility.is_empty()
				else "",
		]
	)
	var path := (
		_selected_public_monster.get("projected_path", []) as Array
	)
	_path_label.text = (
		"路径 · %s" % "  >  ".join(_string_array(path))
		if not path.is_empty()
		else "路径 · 本批待机"
	)
	_unlocked_label.text = "已解锁 %d 招" % maxi(
		0,
		int(
			_selected_public_monster.get(
				"unlocked_skill_count",
				0
			)
		)
	)
	var batch_used := bool(
		_selected_public_monster.get(
			"batch_active_skill_used",
			false
		)
	)
	_batch_used_badge.text = (
		"本批已使用"
		if batch_used
		else "本批可用"
	)
	_batch_used_badge.add_theme_color_override(
		"font_color",
		Color("#efbf70") if batch_used else Color("#72dda7")
	)


func _render_private_surfaces() -> void:
	var viewer_id := str(_projection.get("viewer_player_id", ""))
	var source_id := str(
		_selected_public_monster.get("source_instance_id", "")
	)
	var owner_id := str(
		_selected_public_monster.get("owner_player_id", "")
	)
	_viewer_is_owner = (
		not viewer_id.is_empty()
		and viewer_id == owner_id
	)
	var skill_source := {}
	if _viewer_is_owner:
		for source_variant in _projection.get(
			"own_monster_skill_sources",
			[]
		) as Array:
			if (
				source_variant is Dictionary
				and str(
					(source_variant as Dictionary).get(
						"source_instance_id",
						""
					)
				) == source_id
			):
				skill_source = (
					source_variant as Dictionary
				).duplicate(true)
				break
	_skill_dock.configure(
		skill_source,
		_viewer_is_owner and not skill_source.is_empty(),
		bool(_projection.get("combat_requests_allowed", false))
	)
	_military_panel.configure(
		_projection.get("military_task_options", []) as Array,
		not viewer_id.is_empty()
	)


func _render_empty() -> void:
	_public_panel.visible = false
	_viewer_is_owner = false
	_skill_dock.clear_private_data()
	_military_panel.configure([], false)


func _resolve_layout() -> void:
	if not is_instance_valid(_private_grid):
		return
	var width := size.x
	_layout_mode = "WIDE" if width >= 980.0 else "COMPACT"
	_private_grid.columns = 2 if _layout_mode == "WIDE" else 1


func _apply_styles() -> void:
	var public_style := StyleBoxFlat.new()
	public_style.bg_color = Color(0.035, 0.055, 0.09, 0.97)
	public_style.border_color = Color(0.26, 0.5, 0.66, 0.75)
	public_style.set_border_width_all(1)
	public_style.set_corner_radius_all(6)
	public_style.content_margin_left = 12.0
	public_style.content_margin_top = 10.0
	public_style.content_margin_right = 12.0
	public_style.content_margin_bottom = 10.0
	_public_panel.add_theme_stylebox_override("panel", public_style)
	_public_panel.set_meta("stable_asset_key", "ui.panel.primary")
	var strip_style := StyleBoxFlat.new()
	strip_style.bg_color = Color(0.07, 0.11, 0.14, 0.96)
	strip_style.border_color = Color(0.3, 0.73, 0.7, 0.65)
	strip_style.set_border_width_all(1)
	strip_style.set_corner_radius_all(4)
	strip_style.content_margin_left = 9.0
	strip_style.content_margin_top = 5.0
	strip_style.content_margin_right = 9.0
	strip_style.content_margin_bottom = 5.0
	_presentation_strip.add_theme_stylebox_override(
		"panel",
		strip_style
	)
	_presentation_strip.set_meta(
		"stable_asset_key",
		"ui.panel.popup"
	)


func _status_text(status: String) -> String:
	return {
		"active": "活动",
		"downed": "倒地",
		"destroyed": "已摧毁",
		"withdrawn": "已撤回",
		"hungry": "饥饿追踪",
	}.get(status, status)


func _status_color(status: String) -> Color:
	return {
		"active": Color("#72dda7"),
		"hungry": Color("#efbf70"),
		"downed": Color("#e38a73"),
		"destroyed": Color("#bd6570"),
		"withdrawn": Color("#8896a7"),
	}.get(status, Color("#b7c4d2"))


func _cue_summary(
	event_kind: String,
	payload: Dictionary
) -> String:
	match event_kind:
		"monster_deployed":
			return "怪兽已部署"
		"monster_moved":
			return "怪兽沿公开路径移动"
		"monster_trample_resolved":
			return "践踏结算 · %d 伤害" % int(
				payload.get("damage_amount", 0)
			)
		"monster_basic_attack":
			return "基础攻击 · %d 伤害" % int(
				payload.get("damage_amount", 0)
			)
		"monster_private_skill_resolved":
			return "怪兽释放技能 · 公开效果已结算"
		"military_region_assault":
			return "军队攻击地区后撤离"
		"military_monster_assault":
			return "军队攻击怪兽后撤离"
		"facility_combat_damaged":
			return "%s设施受损" % str(
				payload.get("facility_type", "")
			)
	return ""


func _public_skill_disclosure_count() -> int:
	var count := 0
	for source_variant in _projection.get(
		"public_monsters",
		[]
	) as Array:
		count += _count_private_skill_keys(source_variant)
	return count


func _count_private_skill_keys(value: Variant) -> int:
	var count := 0
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			var key := str(key_variant).to_lower()
			if (
				"skill_definition" in key
				or "asset_cost" in key
				or "cooldown" in key
				or "skill_card" in key
				or "future_skill" in key
				or "request_sequence" in key
				or "internal_order" in key
				or "private_target" in key
			):
				count += 1
			count += _count_private_skill_keys(
				dictionary.get(key_variant)
			)
	elif value is Array:
		for child_variant in value as Array:
			count += _count_private_skill_keys(child_variant)
	return count


func _presentation_cue_result(
	applied: bool,
	reason_code: String
) -> Dictionary:
	return {
		"applied": applied,
		"reason_code": reason_code,
		"applied_cue_count": _presentation_cue_applied_count,
		"duplicate_cue_count": _presentation_cue_duplicate_count,
		"collision_cue_count": _presentation_cue_collision_count,
		"rejected_cue_count": _presentation_cue_rejected_count,
	}


func _canonical_cue_json(value: Variant) -> String:
	if value is Dictionary:
		var dictionary := value as Dictionary
		var keys: Array[String] = []
		for key_variant in dictionary.keys():
			keys.append(str(key_variant))
		keys.sort()
		var fields: Array[String] = []
		for key in keys:
			fields.append(
				"%s:%s" % [
					JSON.stringify(key),
					_canonical_cue_json(dictionary.get(key)),
				]
			)
		return "{%s}" % ",".join(fields)
	if value is Array:
		var items: Array[String] = []
		for item in value as Array:
			items.append(_canonical_cue_json(item))
		return "[%s]" % ",".join(items)
	return JSON.stringify(value)


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


func _on_private_target_selection_requested(
	source_instance_id: String,
	skill_definition_id: String,
	target_contract: String
) -> void:
	private_target_selection_requested.emit(
		source_instance_id,
		skill_definition_id,
		target_contract
	)


func _on_military_mission_selected(task_kind: String) -> void:
	if task_kind not in ["assault_region", "assault_monster"]:
		return
	military_mission_selected.emit(task_kind)