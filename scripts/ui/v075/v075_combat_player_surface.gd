extends Control
class_name V075CombatPlayerSurface

signal private_target_selection_requested(request: Dictionary)
signal military_mission_selected(option: Dictionary)
signal responsive_minimum_resolved(preferred_height: float)

const CATALOG := preload(
	"res://resources/presentation/alpha01_card_illustration_catalog.tres"
)
const ResponsiveAcceptanceAudit := preload(
	"res://scripts/ui/v075/v075_responsive_acceptance_audit.gd"
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
const PRESENTATION_HISTORY_LIMIT := 4
const PRIVATE_TWO_COLUMN_MIN_CONTENT_WIDTH := 620.0
const LAYOUT_EPSILON := 0.5

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
@onready var _info_grid: GridContainer = (
	$Rows/PublicMonsterPanel/Margin/Rows/InfoRow
)
@onready var _private_grid: GridContainer = %PrivateGrid
@onready var _rows: VBoxContainer = $Rows
@onready var _skill_dock: V075MonsterPrivateSkillDock = %SkillDock
@onready var _military_panel: V075MilitaryMissionPanel = %MilitaryPanel
@onready var _presentation_strip: PanelContainer = %PresentationStrip
@onready var _cue_icon: TextureRect = %CueIcon
@onready var _presentation_label: Label = %PresentationLabel
@onready var _cue_asset_label: Label = %CueAssetLabel
@onready var _cue_progress: ProgressBar = %CueProgress

var _projection: Dictionary = {}
var _selected_public_monster: Dictionary = {}
var _layout_mode := "COMPACT"
var _viewer_is_owner := false
var _viewer_can_submit_military := false
var _last_cue: Dictionary = {}
var _presentation_history: Array[String] = []
var _presentation_cue_fingerprints: Dictionary = {}
var _presentation_cue_applied_count := 0
var _presentation_cue_duplicate_count := 0
var _presentation_cue_collision_count := 0
var _presentation_cue_rejected_count := 0
var _presentation_animation_count := 0
var _presentation_tween: Tween
var _layout_settle_scheduled := false
var _last_resolved_preferred_height := -1.0


func _ready() -> void:
	_apply_styles()
	_presentation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_presentation_label.max_lines_visible = PRESENTATION_HISTORY_LIMIT
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
	call_deferred("_resolve_layout")


func preferred_content_height() -> float:
	if not is_instance_valid(_rows):
		return 410.0
	var content_height := _rows.get_combined_minimum_size().y + 20.0
	return maxf(410.0, content_height)


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
	if not summary.is_empty():
		_presentation_history.push_front(summary)
		while _presentation_history.size() > PRESENTATION_HISTORY_LIMIT:
			_presentation_history.pop_back()
	_presentation_label.text = "\n".join(_presentation_history)
	var asset_keys := cue.get("asset_keys", []) as Array
	_cue_asset_label.text = _presentation_asset_caption(asset_keys)
	_cue_icon.texture = _first_cue_texture(asset_keys)
	_cue_icon.modulate = _cue_color(str(cue.get("event_kind", "")))
	_cue_icon.visible = _cue_icon.texture != null
	_cue_progress.value = 0.0
	if _presentation_tween != null and _presentation_tween.is_valid():
		_presentation_tween.kill()
	_presentation_tween = create_tween()
	_presentation_tween.set_trans(Tween.TRANS_SINE)
	_presentation_tween.set_ease(Tween.EASE_OUT)
	_presentation_tween.tween_property(_cue_progress, "value", 100.0, 0.34)
	_presentation_animation_count += 1
	_presentation_strip.visible = not _presentation_history.is_empty()
	_schedule_layout_settle()
	return _presentation_cue_result(true, "none")


func reset_presentation_cues() -> void:
	_presentation_cue_fingerprints.clear()
	_presentation_cue_applied_count = 0
	_presentation_cue_duplicate_count = 0
	_presentation_cue_collision_count = 0
	_presentation_cue_rejected_count = 0
	_presentation_animation_count = 0
	_last_cue = {}
	_presentation_history.clear()
	_presentation_label.text = ""
	_cue_asset_label.text = ""
	_cue_icon.texture = null
	_cue_icon.visible = false
	_cue_progress.value = 0.0
	if _presentation_tween != null and _presentation_tween.is_valid():
		_presentation_tween.kill()
	_presentation_strip.visible = false
	_schedule_layout_settle()


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
		"viewer_can_submit_military": _viewer_can_submit_military,
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
		"military_option_identity_count": int(
			military_debug.get("option_identity_count", 0)
		),
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
		"presentation_animation_count": _presentation_animation_count,
		"presentation_asset_key_visible": not _cue_asset_label.text.is_empty(),
		"presentation_event_kind_visible": not str(
			_last_cue.get("event_kind", "")
		).is_empty(),
		"last_presentation_cue_id": str(
			_last_cue.get("presentation_receipt_id", "")
		),
		"presentation_history_count": _presentation_history.size(),
		"presentation_history": _presentation_history.duplicate(),
		"presentation_gameplay_mutation_count": 0,
		"presentation_rng_draw_delta": 0,
	}


func debug_geometry_audit() -> Dictionary:
	var audit := ResponsiveAcceptanceAudit.audit_control_tree(self)
	audit["schema"] = "V075CombatSurfaceGeometryAuditV2"
	audit["private_grid_columns"] = _private_grid.columns
	audit["layout_mode"] = _layout_mode
	audit["rows_combined_minimum_height"] = (
		_rows.get_combined_minimum_size().y
	)
	audit["preferred_content_height"] = preferred_content_height()
	audit["surface_custom_minimum_height"] = custom_minimum_size.y
	return audit


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
	var selected_generation := int(
		_selected_public_monster.get("source_generation", 0)
	)
	_viewer_is_owner = (
		not viewer_id.is_empty()
		and viewer_id == owner_id
		and _positive_int_field(
			_selected_public_monster,
			"source_generation"
		)
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
				and str(
					(source_variant as Dictionary).get(
						"owner_player_id",
						""
					)
				) == viewer_id
				and _positive_int_field(
					source_variant as Dictionary,
					"source_generation"
				)
				and (source_variant as Dictionary).get("source_generation")
					== _selected_public_monster.get("source_generation")
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
	var military_options: Array = []
	for option_variant in _projection.get(
		"military_task_options",
		[]
	) as Array:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		if str(option.get("owner_player_id", "")) != viewer_id:
			continue
		if str(option.get("action_domain", "military")) != "military":
			continue
		military_options.append(option.duplicate(true))
	_viewer_can_submit_military = not military_options.is_empty()
	_military_panel.configure(military_options, _viewer_can_submit_military)


func _render_empty() -> void:
	_public_panel.visible = false
	_viewer_is_owner = false
	_viewer_can_submit_military = false
	_skill_dock.clear_private_data()
	_military_panel.configure([], false)


func _resolve_layout() -> void:
	if not is_instance_valid(_private_grid):
		return
	var width := size.x
	var available_width := maxf(0.0, width - 20.0)
	var required_two_column_width := maxf(
		PRIVATE_TWO_COLUMN_MIN_CONTENT_WIDTH,
		_skill_dock.get_combined_minimum_size().x
		+ _military_panel.get_combined_minimum_size().x
		+ float(_private_grid.get_theme_constant("h_separation"))
	)
	var two_column := available_width >= required_two_column_width
	_layout_mode = "WIDE" if two_column else "COMPACT"
	var private_columns := 2 if two_column else 1
	# The three public-fact groups are a row at normal widths and a readable
	# vertical stack at the 480px acceptance viewport. No child is clipped.
	var info_columns := 1 if available_width < 520.0 else 3
	var column_count_changed := (
		_private_grid.columns != private_columns
		or _info_grid.columns != info_columns
	)
	_private_grid.columns = private_columns
	_info_grid.columns = info_columns
	if column_count_changed:
		_private_grid.queue_sort()
		_info_grid.queue_sort()
		_rows.queue_sort()
	_schedule_layout_settle()


func _schedule_layout_settle() -> void:
	if _layout_settle_scheduled:
		return
	_layout_settle_scheduled = true
	# GridContainer publishes its new combined minimum after the queued sort.
	# The outer production ScrollContainer must consume that settled value,
	# otherwise a one-column layout can be clipped at the previous height.
	call_deferred("_prepare_settled_layout_minimum")


func _prepare_settled_layout_minimum() -> void:
	_private_grid.update_minimum_size()
	_info_grid.update_minimum_size()
	_rows.update_minimum_size()
	_private_grid.queue_sort()
	_info_grid.queue_sort()
	_rows.queue_sort()
	call_deferred("_publish_settled_layout_minimum")


func _publish_settled_layout_minimum() -> void:
	_layout_settle_scheduled = false
	var resolved_height := preferred_content_height()
	if (
		_last_resolved_preferred_height >= 0.0
		and absf(resolved_height - _last_resolved_preferred_height)
			<= LAYOUT_EPSILON
	):
		return
	_last_resolved_preferred_height = resolved_height
	responsive_minimum_resolved.emit(resolved_height)


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
		"monster_refreshed":
			return "同族怪兽恢复 %d%% 最大生命" % int(
				payload.get("refresh_percent", 0)
			)
		"monster_upgraded":
			return "怪兽升级至 L%d" % int(
				payload.get("new_rank", payload.get("source_rank", 1))
			)
		"monster_replaced":
			return "旧怪兽撤回 · 新怪兽已部署"
		"monster_moved":
			return "怪兽沿公开路径移动"
		"monster_trample_resolved":
			return "践踏 %s · %d 伤害" % [
				str(payload.get("region_id", "")),
				int(payload.get(
					"region_damage_budget",
					payload.get("damage_amount", 0)
				)),
			]
		"monster_basic_attack":
			return "基础攻击 · %d 伤害" % int(
				payload.get("damage_amount", 0)
			)
		"monster_private_skill_resolved":
			return "怪兽释放技能 · 公开效果已结算"
		"monster_skill_cooldown_started":
			return "怪兽技能进入冷却"
		"monster_skill_ready":
			return "怪兽技能冷却完成"
		"monster_damaged":
			return "怪兽受到 %d 伤害" % int(
				payload.get("damage_amount", 0)
			)
		"monster_downed":
			return "怪兽倒地"
		"monster_destroyed":
			return "怪兽被摧毁"
		"monster_withdrawn":
			return "怪兽已撤回"
		"military_region_assault":
			return "军队完成地区攻击"
		"military_monster_assault":
			return "军队完成怪兽攻击"
		"military_withdrawn":
			return "军队任务完成 · 已撤离并弃置"
		"facility_combat_damaged":
			return "%s设施受损" % str(
				payload.get("facility_type", "")
			)
		"armor_absorbed":
			return "护甲吸收伤害"
	return ""


func _first_cue_texture(asset_keys: Array) -> Texture2D:
	for key_variant in asset_keys:
		var resource := CATALOG.resource_for_asset_key(
			StringName(str(key_variant))
		)
		if resource is Texture2D:
			return resource as Texture2D
	var fallback := CATALOG.resource_for_asset_key(&"icon.board.target")
	return fallback as Texture2D if fallback is Texture2D else null


func _presentation_asset_caption(asset_keys: Array) -> String:
	if asset_keys.is_empty():
		return "效果"
	var captions: Array[String] = []
	for key_variant in asset_keys.slice(0, mini(2, asset_keys.size())):
		var key := str(key_variant)
		var suffix := key.rsplit(".", true, 1)[-1]
		captions.append(suffix.replace("_", " "))
	return " · ".join(captions)


func _cue_color(event_kind: String) -> Color:
	if event_kind.begins_with("military_"):
		return Color("#ef9a74")
	if event_kind == "facility_combat_damaged":
		return Color("#e4bd69")
	if event_kind == "monster_trample_resolved":
		return Color("#d9a36b")
	if event_kind == "monster_private_skill_resolved":
		return Color("#ba9bff")
	return Color("#74d9c6")


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


func _on_private_target_selection_requested(request: Dictionary) -> void:
	var canonical_request := _current_private_skill_request(request)
	if canonical_request.is_empty():
		return
	private_target_selection_requested.emit(canonical_request)


func _on_military_mission_selected(option: Dictionary) -> void:
	if (
		not _viewer_can_submit_military
		or option.is_empty()
		or str(option.get("owner_player_id", "")) != str(
			_projection.get("viewer_player_id", "")
		)
		or str(option.get("task_kind", "")) not in [
		"assault_region",
		"assault_monster",
		]
	):
		return
	var canonical_option := _current_military_option(option)
	if canonical_option.is_empty():
		return
	military_mission_selected.emit(canonical_option)


func _current_private_skill_request(candidate: Dictionary) -> Dictionary:
	if not _viewer_is_owner or candidate.is_empty():
		return {}
	var viewer_id := str(_projection.get("viewer_player_id", ""))
	var source_id := str(_selected_public_monster.get(
		"source_instance_id",
		""
	))
	var source_generation := int(_selected_public_monster.get(
		"source_generation",
		0
	))
	var skill_id := str(candidate.get("skill_definition_id", ""))
	if (
		viewer_id.is_empty()
		or source_id.is_empty()
		or not _positive_int_field(
			_selected_public_monster,
			"source_generation"
		)
		or str(candidate.get("source_instance_id", "")) != source_id
		or not _positive_int_field(candidate, "source_generation")
		or candidate.get("source_generation")
			!= _selected_public_monster.get("source_generation")
		or skill_id.is_empty()
	):
		return {}
	for source_variant in _projection.get(
		"own_monster_skill_sources",
		[]
	) as Array:
		if not (source_variant is Dictionary):
			continue
		var source := source_variant as Dictionary
		if (
			str(source.get("source_instance_id", "")) != source_id
			or str(source.get("owner_player_id", "")) != viewer_id
			or not _positive_int_field(source, "source_generation")
			or source.get("source_generation")
				!= candidate.get("source_generation")
		):
			continue
		for skill_variant in source.get("skills", []) as Array:
			if not (skill_variant is Dictionary):
				continue
			var skill := skill_variant as Dictionary
			if (
				str(skill.get("skill_definition_id", "")) != skill_id
				or not bool(skill.get("can_request", false))
				or str(skill.get("state", "")) != "READY"
			):
				continue
			var expected_binding := skill.get("target_binding", {}) as Dictionary
			var candidate_binding := candidate.get("target_binding", {}) as Dictionary
			var expected_contract := skill.get("target_contract", {}) as Dictionary
			var candidate_contract := candidate.get("target_contract", {}) as Dictionary
			if (
				expected_binding.is_empty()
				or not _same_flat_dictionary(
					candidate_binding,
					expected_binding
				)
				or not _same_flat_dictionary(
					candidate_contract,
					expected_contract
				)
			):
				return {}
			return {
				"source_instance_id": source_id,
				"source_generation": source_generation,
				"skill_definition_id": skill_id,
				"target_binding": expected_binding.duplicate(true),
				"target_contract": expected_contract.duplicate(true),
			}
	return {}


func _current_military_option(candidate: Dictionary) -> Dictionary:
	var viewer_id := str(_projection.get("viewer_player_id", ""))
	if (
		viewer_id.is_empty()
		or str(candidate.get("owner_player_id", "")) != viewer_id
		or str(candidate.get("action_domain", "")) != "military"
		or not _card_action_binding_valid(candidate, viewer_id)
	):
		return {}
	var task_kind := str(candidate.get("task_kind", ""))
	if (
		(task_kind == "assault_monster" and (
			not _positive_int_field(candidate, "target_source_generation")
		))
		or (task_kind == "assault_region" and candidate.has(
			"target_source_generation"
		))
		or task_kind not in ["assault_region", "assault_monster"]
	):
		return {}
	for option_variant in _projection.get("military_task_options", []) as Array:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		if (
			bool(option.get("enabled", false))
			and _same_military_option_identity(candidate, option)
		):
			return option.duplicate(true)
	return {}


func _same_military_option_identity(
	left: Dictionary,
	right: Dictionary
) -> bool:
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
		not _card_action_binding_valid(
			left,
			str(left.get("owner_player_id", ""))
		)
		or not _card_action_binding_valid(
			right,
			str(right.get("owner_player_id", ""))
		)
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


func _card_action_binding_valid(
	option: Dictionary,
	expected_owner_id: String
) -> bool:
	var binding_variant: Variant = option.get("card_action_binding")
	if not (binding_variant is Dictionary):
		return false
	var binding := binding_variant as Dictionary
	return (
		not binding.is_empty()
		and str(binding.get("owner_player_id", "")) == expected_owner_id
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


func _same_flat_dictionary(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for key_variant in left.keys():
		if (
			not right.has(key_variant)
			or left.get(key_variant) != right.get(key_variant)
		):
			return false
	return true
