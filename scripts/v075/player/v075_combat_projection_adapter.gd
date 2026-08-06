extends RefCounted
class_name V075CombatProjectionAdapter

const RULESET_ID := "v0.7.5"
const PUBLIC_MONSTER_FIELDS := [
	"source_instance_id",
	"source_generation",
	"monster_family_id",
	"owner_player_id",
	"display_name",
	"model_asset_key",
	"rank",
	"hp",
	"max_hp",
	"armor",
	"preferred_industry_color",
	"region_id",
	"tracked_region_id",
	"tracked_facility_id",
	"projected_path",
	"unlocked_skill_count",
	"batch_active_skill_used",
	"status",
]
const PRIVATE_SKILL_FIELDS := [
	"skill_definition_id",
	"display_name",
	"state",
	"asset_cost_by_color",
	"target_contract",
	"cooldown_remaining_batches",
	"ultimate",
	"required_rank",
	"public_effect_id",
]
const MILITARY_TASK_KINDS := [
	"assault_region",
	"assault_monster",
]
const TERMINAL_PHASES := [
	"victory_pending",
	"victory_resolved",
	"final_settlement",
	"terminal",
]
const PUBLIC_MONSTER_FORBIDDEN_FRAGMENTS := [
	"skill_definition",
	"skill_name",
	"skill_card",
	"asset_cost",
	"cooldown",
	"private",
	"future_skill",
	"selected_skill",
	"instant_sequence",
	"internal_order",
]

var _projection_count := 0
var _last_privacy_report: Dictionary = {}


func project_for_viewer(
	authority_snapshot: Dictionary,
	viewer_player_id: String
) -> Dictionary:
	_projection_count += 1
	var phase := str(authority_snapshot.get("phase", "batch_active"))
	var combat_requests_allowed := phase not in TERMINAL_PHASES
	var public_monsters: Array[Dictionary] = []
	var source_rows: Variant = authority_snapshot.get(
		"public_monsters",
		authority_snapshot.get("monsters", [])
	)
	if source_rows is Array:
		for source_variant in source_rows as Array:
			if not (source_variant is Dictionary):
				continue
			public_monsters.append(
				_project_public_monster(source_variant as Dictionary)
			)
	public_monsters.sort_custom(_public_monster_precedes)

	var own_skill_sources := _project_owner_skill_sources(
		authority_snapshot,
		viewer_player_id,
		combat_requests_allowed
	)
	var military_options := _project_military_options(
		authority_snapshot,
		viewer_player_id,
		combat_requests_allowed
	)
	var projection := {
		"schema": "V075CombatPlayerProjectionV1",
		"ruleset_id": RULESET_ID,
		"viewer_player_id": viewer_player_id,
		"phase": phase,
		"combat_requests_allowed": combat_requests_allowed,
		"terminal_combat_quiescent": phase in TERMINAL_PHASES,
		"public_monsters": public_monsters,
		"own_monster_skill_sources": own_skill_sources,
		"military_task_options": military_options,
		"public_monster_count": public_monsters.size(),
		"own_private_skill_source_count": own_skill_sources.size(),
	}
	_last_privacy_report = privacy_report(projection)
	if not bool(_last_privacy_report.get("valid", false)):
		return {
			"schema": "V075CombatPlayerProjectionV1",
			"ruleset_id": RULESET_ID,
			"viewer_player_id": viewer_player_id,
			"phase": phase,
			"combat_requests_allowed": false,
			"terminal_combat_quiescent": phase in TERMINAL_PHASES,
			"public_monsters": [],
			"own_monster_skill_sources": [],
			"military_task_options": [],
			"public_monster_count": 0,
			"own_private_skill_source_count": 0,
			"projection_rejected": true,
			"reason_code": str(
				_last_privacy_report.get(
					"reason_code",
					"privacy_projection_invalid"
				)
			),
		}
	return projection


func public_projection(authority_snapshot: Dictionary) -> Dictionary:
	var projection := project_for_viewer(authority_snapshot, "")
	projection.erase("viewer_player_id")
	projection.erase("own_monster_skill_sources")
	projection.erase("own_private_skill_source_count")
	projection.erase("military_task_options")
	projection["visibility_scope"] = "public_only"
	return projection


func privacy_report(projection: Dictionary) -> Dictionary:
	var public_disclosure_count := 0
	for source_variant in projection.get("public_monsters", []) as Array:
		if not (source_variant is Dictionary):
			public_disclosure_count += 1
			continue
		public_disclosure_count += _forbidden_fragment_count(
			source_variant,
			PUBLIC_MONSTER_FORBIDDEN_FRAGMENTS
		)
	var viewer_id := str(projection.get("viewer_player_id", ""))
	var opponent_private_disclosure_count := 0
	for source_variant in projection.get(
		"own_monster_skill_sources",
		[]
	) as Array:
		if not (source_variant is Dictionary):
			opponent_private_disclosure_count += 1
			continue
		var source := source_variant as Dictionary
		if str(source.get("owner_player_id", "")) != viewer_id:
			opponent_private_disclosure_count += 1
	var invalid_military_task_count := 0
	for option_variant in projection.get(
		"military_task_options",
		[]
	) as Array:
		if not (option_variant is Dictionary):
			invalid_military_task_count += 1
			continue
		if str(
			(option_variant as Dictionary).get("task_kind", "")
		) not in MILITARY_TASK_KINDS:
			invalid_military_task_count += 1
	var valid := (
		public_disclosure_count == 0
		and opponent_private_disclosure_count == 0
		and invalid_military_task_count == 0
	)
	return {
		"valid": valid,
		"reason_code": (
			"none"
			if valid
			else "combat_projection_privacy_invalid"
		),
		"public_skill_card_disclosure_count": public_disclosure_count,
		"future_skill_target_disclosure_count":
			_count_exact_key(projection.get("public_monsters", []), "future_skill_target"),
		"opponent_private_skill_disclosure_count":
			opponent_private_disclosure_count,
		"invalid_military_task_count": invalid_military_task_count,
	}


func debug_snapshot() -> Dictionary:
	return {
		"schema": "V075CombatProjectionAdapterDebugV1",
		"ruleset_id": RULESET_ID,
		"projection_count": _projection_count,
		"public_monster_field_count": PUBLIC_MONSTER_FIELDS.size(),
		"military_task_kinds": MILITARY_TASK_KINDS.duplicate(),
		"military_guard_ui_count": 0,
		"last_privacy_report": _last_privacy_report.duplicate(true),
	}


func _project_public_monster(source: Dictionary) -> Dictionary:
	var projected := {}
	for field in PUBLIC_MONSTER_FIELDS:
		if source.has(field):
			projected[field] = _safe_copy(source.get(field))
	if not projected.has("projected_path"):
		projected["projected_path"] = []
	if not projected.has("unlocked_skill_count"):
		projected["unlocked_skill_count"] = 0
	if not projected.has("batch_active_skill_used"):
		projected["batch_active_skill_used"] = false
	if not projected.has("status"):
		projected["status"] = "active"
	return projected


func _project_owner_skill_sources(
	authority_snapshot: Dictionary,
	viewer_player_id: String,
	combat_requests_allowed: bool
) -> Array[Dictionary]:
	if viewer_player_id.is_empty():
		return []
	var zones_by_player := (
		authority_snapshot.get(
			"private_skill_zones_by_player",
			{}
		) as Dictionary
	)
	var viewer_zone: Variant = zones_by_player.get(viewer_player_id, [])
	if not (viewer_zone is Array):
		return []
	var result: Array[Dictionary] = []
	for source_variant in viewer_zone as Array:
		if not (source_variant is Dictionary):
			continue
		var source := source_variant as Dictionary
		if str(source.get("owner_player_id", "")) != viewer_player_id:
			continue
		var source_status := str(source.get("status", "active"))
		var batch_used := bool(
			source.get("batch_active_skill_used", false)
		)
		var projected_skills: Array[Dictionary] = []
		for skill_variant in source.get("skills", []) as Array:
			if not (skill_variant is Dictionary):
				continue
			var skill := skill_variant as Dictionary
			var projected_skill := {}
			for field in PRIVATE_SKILL_FIELDS:
				if skill.has(field):
					projected_skill[field] = _safe_copy(
						skill.get(field)
					)
			var state := str(projected_skill.get("state", "DISABLED"))
			projected_skill["can_request"] = (
				combat_requests_allowed
				and not batch_used
				and source_status == "active"
				and state == "READY"
			)
			projected_skills.append(projected_skill)
		projected_skills.sort_custom(_private_skill_precedes)
		result.append({
			"source_instance_id": str(
				source.get("source_instance_id", "")
			),
			"owner_player_id": viewer_player_id,
			"monster_display_name": str(
				source.get("monster_display_name", "")
			),
			"rank": int(source.get("rank", 1)),
			"status": source_status,
			"batch_active_skill_used": batch_used,
			"skills": projected_skills,
		})
	result.sort_custom(_private_source_precedes)
	return result


func _project_military_options(
	authority_snapshot: Dictionary,
	viewer_player_id: String,
	combat_requests_allowed: bool
) -> Array[Dictionary]:
	if viewer_player_id.is_empty():
		return []
	var private_by_player := (
		authority_snapshot.get(
			"private_player_facts_by_player",
			{}
		) as Dictionary
	)
	var viewer_facts: Variant = private_by_player.get(
		viewer_player_id,
		{}
	)
	if not (viewer_facts is Dictionary):
		return []
	var facts := viewer_facts as Dictionary
	if not bool(facts.get("military_card_selected", false)):
		return []
	return [
		{
			"task_kind": "assault_region",
			"display_name": "攻击地区",
			"icon_asset_key": "icon.board.target",
			"enabled": combat_requests_allowed and bool(
				facts.get("can_assault_region", false)
			),
		},
		{
			"task_kind": "assault_monster",
			"display_name": "攻击怪兽",
			"icon_asset_key": "vfx.monster.attack_smoke",
			"enabled": combat_requests_allowed and bool(
				facts.get("can_assault_monster", false)
			),
		},
	]


func _public_monster_precedes(
	left: Dictionary,
	right: Dictionary
) -> bool:
	return str(left.get("source_instance_id", "")) < str(
		right.get("source_instance_id", "")
	)


func _private_source_precedes(
	left: Dictionary,
	right: Dictionary
) -> bool:
	return str(left.get("source_instance_id", "")) < str(
		right.get("source_instance_id", "")
	)


func _private_skill_precedes(
	left: Dictionary,
	right: Dictionary
) -> bool:
	var left_rank := int(left.get("required_rank", 0))
	var right_rank := int(right.get("required_rank", 0))
	if left_rank != right_rank:
		return left_rank < right_rank
	return str(left.get("skill_definition_id", "")) < str(
		right.get("skill_definition_id", "")
	)


func _safe_copy(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value


func _forbidden_fragment_count(
	value: Variant,
	fragments: Array
) -> int:
	var count := 0
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			var key := str(key_variant).to_lower()
			for fragment_variant in fragments:
				if str(fragment_variant) in key:
					count += 1
					break
			count += _forbidden_fragment_count(
				dictionary.get(key_variant),
				fragments
			)
	elif value is Array:
		for child_variant in value as Array:
			count += _forbidden_fragment_count(child_variant, fragments)
	return count


func _count_exact_key(value: Variant, expected_key: String) -> int:
	var count := 0
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			if str(key_variant) == expected_key:
				count += 1
			count += _count_exact_key(
				dictionary.get(key_variant),
				expected_key
			)
	elif value is Array:
		for child_variant in value as Array:
			count += _count_exact_key(child_variant, expected_key)
	return count
