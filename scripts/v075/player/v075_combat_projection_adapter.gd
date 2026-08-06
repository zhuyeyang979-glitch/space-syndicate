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
			var normalized_contract := _normalized_target_contract(
				skill.get("target_contract", {})
			)
			projected_skill["target_contract"] = normalized_contract
			var target_binding := skill.get("target_binding", {}) as Dictionary
			if target_binding.is_empty():
				target_binding = _derive_target_binding(
					normalized_contract,
					source,
					authority_snapshot,
					viewer_player_id
				)
			projected_skill["target_binding"] = target_binding.duplicate(true)
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
			"source_generation": int(source.get("source_generation", 0)),
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
	var result: Array[Dictionary] = []
	var options_variant: Variant = facts.get("military_options", [])
	if not (options_variant is Array):
		return []
	for option_variant in options_variant as Array:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		if not _military_option_valid(option, viewer_player_id):
			continue
		var projected := {
			"option_id": str(option.get("option_id", "")),
			"owner_player_id": viewer_player_id,
			"card_instance_id": str(option.get("card_instance_id", "")),
			"card_definition_id": str(option.get("card_definition_id", "")),
			"card_generation": maxi(1, int(option.get("card_generation", 1))),
			"target_slot_id": str(option.get("target_slot_id", "")),
			"task_kind": str(option.get("task_kind", "")),
			"target_region_id": str(option.get("target_region_id", "")),
			"target_monster_source_instance_id": str(option.get(
				"target_monster_source_instance_id",
				""
			)),
			"target_source_generation": int(option.get(
				"target_source_generation",
				0
			)),
			"launch_region_id": str(option.get("launch_region_id", "")),
			"asset_cost_by_color": (
				option.get("asset_cost_by_color", {}) as Dictionary
			).duplicate(true),
			"display_name": (
				"攻击地区"
				if str(option.get("task_kind", "")) == "assault_region"
				else "攻击怪兽"
			),
			"icon_asset_key": (
				"icon.board.target"
				if str(option.get("task_kind", "")) == "assault_region"
				else "vfx.monster.attack_smoke"
			),
			"enabled": combat_requests_allowed and bool(
				option.get("enabled", false)
			),
			"disabled_reason": str(option.get("disabled_reason", "none")),
			"action_domain": "military",
		}
		result.append(projected)
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("option_id", "")) < str(
			right.get("option_id", "")
		)
	)
	return result


func _normalized_target_contract(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	var legacy := str(value)
	var kind: String = str({
		"self": "self_source",
		"enemy_facility": "enemy_public_facility",
		"enemy_monster": "enemy_public_monster",
		"region": "enemy_facilities_in_public_region",
	}.get(legacy, legacy))
	return {"target_kind": kind} if not legacy.is_empty() else {}


func _derive_target_binding(
	contract: Dictionary,
	source: Dictionary,
	authority_snapshot: Dictionary,
	viewer_player_id: String
) -> Dictionary:
	var target_kind := str(contract.get("target_kind", ""))
	var source_id := str(source.get("source_instance_id", ""))
	var source_generation := int(source.get("source_generation", 0))
	if target_kind == "self_source":
		return {
			"target_kind": "monster",
			"target_id": source_id,
			"target_source_generation": source_generation,
		}
	if target_kind == "enemy_public_facility":
		var facility_id := str(source.get("tracked_facility_id", ""))
		if facility_id.is_empty():
			for facility_variant in authority_snapshot.get("public_facilities", []) as Array:
				var facility := facility_variant as Dictionary
				if str(facility.get("owner_player_id", "")) == viewer_player_id:
					continue
				if str(facility.get("status", "active")) == "destroyed":
					continue
				facility_id = str(facility.get("facility_id", ""))
				if not facility_id.is_empty():
					break
		if facility_id.is_empty():
			return {}
		return {
			"target_kind": "facility",
			"target_id": facility_id,
			"target_facility_id": facility_id,
		}
	if target_kind in [
		"enemy_facilities_in_public_region",
		"enemy_facilities_in_current_region",
	]:
		var region_id := (
			str(source.get("region_id", ""))
			if target_kind == "enemy_facilities_in_current_region"
			else str(source.get("tracked_region_id", ""))
		)
		if region_id.is_empty():
			return {}
		return {
			"target_kind": "region",
			"target_id": region_id,
			"target_region_id": region_id,
		}
	if target_kind == "enemy_public_monster":
		var monster_ids: Array[String] = []
		for monster_variant in authority_snapshot.get("public_monsters", []) as Array:
			var monster := monster_variant as Dictionary
			if str(monster.get("owner_player_id", "")) == viewer_player_id:
				continue
			if str(monster.get("status", "active")) != "active":
				continue
			var id := str(monster.get("source_instance_id", ""))
			if not id.is_empty():
				monster_ids.append(id)
		monster_ids.sort()
		if monster_ids.is_empty():
			return {}
		var selected_id := monster_ids[0]
		for monster_variant in authority_snapshot.get("public_monsters", []) as Array:
			var monster := monster_variant as Dictionary
			if str(monster.get("source_instance_id", "")) == selected_id:
				return {
					"target_kind": "monster",
					"target_id": selected_id,
					"target_source_generation": int(monster.get("source_generation", 0)),
				}
	return {}


func _military_option_valid(option: Dictionary, viewer_player_id: String) -> bool:
	if str(option.get("action_domain", "military")) != "military":
		return false
	if str(option.get("owner_player_id", viewer_player_id)) != viewer_player_id:
		return false
	for field_name in [
		"option_id",
		"card_instance_id",
		"card_definition_id",
		"target_slot_id",
	]:
		if str(option.get(field_name, "")).is_empty():
			return false
	var task_kind := str(option.get("task_kind", ""))
	if task_kind == "assault_region":
		return not str(option.get("target_region_id", "")).is_empty()
	if task_kind == "assault_monster":
		return not str(option.get(
			"target_monster_source_instance_id",
			""
		)).is_empty()
	return false


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
