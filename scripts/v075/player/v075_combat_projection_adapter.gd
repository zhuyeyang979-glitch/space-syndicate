extends RefCounted
class_name V075CombatProjectionAdapter

const CardDefinitionRegistry := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)
const CapabilityCatalog := preload(
	"res://scripts/v075/combat/v075_combat_capability_catalog.gd"
)
const CombatCandidate := preload(
	"res://scripts/v075/ai/v075_ai_combat_action_candidate_v1.gd"
)
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
	"unlocked_skill_count",
	"batch_active_skill_used",
	"status",
]
const OWNER_NAVIGATION_FIELDS := [
	"tracked_region_id",
	"tracked_facility_id",
	"projected_path",
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
const MILITARY_TASK_KINDS := CapabilityCatalog.MILITARY_MISSION_KINDS
const CARD_ACTION_BINDING_FIELDS := [
	"schema_id",
	"schema_version",
	"authority_domain_id",
	"authority_lineage_fingerprint",
	"owner_player_id",
	"card_instance_id",
	"card_definition_id",
	"immutable_identity_fingerprint",
	"authoritative_zone",
	"zone_revision",
	"lifecycle_evidence_fingerprint",
	"expected_action_lifecycle",
	"binding_fingerprint",
]
const PRIVATE_CARD_IDENTITY_KEYS := [
	"card_action_binding",
	"authority_lineage_fingerprint",
	"immutable_identity_fingerprint",
	"authoritative_zone",
	"zone_revision",
	"lifecycle_evidence_fingerprint",
	"expected_action_lifecycle",
	"binding_fingerprint",
	"candidate_fingerprint",
	"prebound_monster_action",
	"action_fingerprint",
	"definition_snapshot",
	"bound_state_revision",
	"military_target_envelope",
	"envelope_fingerprint",
	"combat_private_facts",
	"combat_candidates",
	"monster_mode_candidates",
	"military_mission_candidates",
	"military_options",
	"target_binding",
	"public_information_fingerprint",
	"private_information_fingerprint",
	"priority_features",
	"expected_world_revision",
	"expected_region_revision",
	"target_source_generation",
	"target_generation",
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
	var terminal_quiescence: Variant = authority_snapshot.get(
		"terminal_quiescence",
		{}
	)
	var terminal_combat_quiescent := (
		phase in TERMINAL_PHASES
		and terminal_quiescence is Dictionary
		and bool((terminal_quiescence as Dictionary).get("green", false))
	)
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
				_project_public_monster(
					source_variant as Dictionary,
					viewer_player_id
				)
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
		"terminal_combat_quiescent": terminal_combat_quiescent,
		"monster_mode_capabilities": CapabilityCatalog.monster_card_modes(),
		"military_mission_capabilities": CapabilityCatalog.military_mission_kinds(),
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
			"terminal_combat_quiescent": terminal_combat_quiescent,
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


func private_card_identity_leak_count(value: Variant) -> int:
	return _count_exact_keys(value, PRIVATE_CARD_IDENTITY_KEYS)


func privacy_report(projection: Dictionary) -> Dictionary:
	var viewer_id := str(projection.get("viewer_player_id", ""))
	var public_monsters := projection.get("public_monsters", []) as Array
	var public_scope := projection.duplicate(true)
	public_scope.erase("own_monster_skill_sources")
	public_scope.erase("military_task_options")
	var private_card_identity_disclosure_count := (
		private_card_identity_leak_count(public_scope)
	)
	var public_disclosure_count := 0
	var opponent_future_target_disclosure_count := 0
	for source_variant in public_monsters:
		if not (source_variant is Dictionary):
			public_disclosure_count += 1
			continue
		var source := source_variant as Dictionary
		public_disclosure_count += _forbidden_fragment_count(
			source,
			PUBLIC_MONSTER_FORBIDDEN_FRAGMENTS
		)
		if str(source.get("owner_player_id", "")) != viewer_id:
			for field in OWNER_NAVIGATION_FIELDS:
				if source.has(field):
					opponent_future_target_disclosure_count += 1
	var opponent_private_disclosure_count := 0
	var stale_private_source_count := 0
	var invalid_private_skill_identity_count := 0
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
			continue
		if not _private_source_identity_current(
			source,
			viewer_id,
			public_monsters
		):
			stale_private_source_count += 1
			continue
		for skill_variant in source.get("skills", []) as Array:
			if not (skill_variant is Dictionary):
				invalid_private_skill_identity_count += 1
				continue
			var skill := skill_variant as Dictionary
			if not _skill_target_binding_valid(
				skill,
				source,
				viewer_id,
				projection
			):
				invalid_private_skill_identity_count += 1
	var invalid_military_task_count := 0
	for option_variant in projection.get(
		"military_task_options",
		[]
	) as Array:
		if not (option_variant is Dictionary):
			invalid_military_task_count += 1
			continue
		if not _military_option_valid(
			option_variant as Dictionary,
			viewer_id,
			projection
		):
			invalid_military_task_count += 1
	var valid := (
		public_disclosure_count == 0
		and private_card_identity_disclosure_count == 0
		and opponent_future_target_disclosure_count == 0
		and opponent_private_disclosure_count == 0
		and stale_private_source_count == 0
		and invalid_private_skill_identity_count == 0
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
		"private_card_identity_disclosure_count": (
			private_card_identity_disclosure_count
		),
		"future_skill_target_disclosure_count":
			_count_exact_key(projection.get("public_monsters", []), "future_skill_target"),
		"opponent_future_target_disclosure_count":
			opponent_future_target_disclosure_count,
		"opponent_private_skill_disclosure_count":
			opponent_private_disclosure_count,
		"stale_private_source_count": stale_private_source_count,
		"invalid_private_skill_identity_count":
			invalid_private_skill_identity_count,
		"invalid_military_task_count": invalid_military_task_count,
	}


func debug_snapshot() -> Dictionary:
	return {
		"schema": "V075CombatProjectionAdapterDebugV1",
		"ruleset_id": RULESET_ID,
		"projection_count": _projection_count,
		"public_monster_field_count": PUBLIC_MONSTER_FIELDS.size(),
		"owner_navigation_field_count": OWNER_NAVIGATION_FIELDS.size(),
		"military_task_kinds": MILITARY_TASK_KINDS.duplicate(),
		"military_guard_ui_count": 0,
		"last_privacy_report": _last_privacy_report.duplicate(true),
	}


func _project_public_monster(
	source: Dictionary,
	viewer_player_id: String
) -> Dictionary:
	var projected := {}
	for field in PUBLIC_MONSTER_FIELDS:
		if source.has(field):
			projected[field] = _safe_copy(source.get(field))
	if (
		not viewer_player_id.is_empty()
		and str(source.get("owner_player_id", "")) == viewer_player_id
	):
		for field in OWNER_NAVIGATION_FIELDS:
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
		if not _private_source_identity_current(
			source,
			viewer_player_id,
			authority_snapshot.get("public_monsters", []) as Array
		):
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
			if not _skill_target_binding_valid(
				skill,
				source,
				viewer_player_id,
				authority_snapshot
			):
				continue
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
		if not _military_option_valid(
			option,
			viewer_player_id,
			authority_snapshot
		):
			continue
		var task_kind := str(option.get("task_kind", ""))
		var card_definition_id := str(
			option.get("card_definition_id", "")
		)
		var presentation := (
			CardDefinitionRegistry.presentation_descriptor(
				card_definition_id
			)
		)
		if presentation.is_empty():
			continue
		var projected := {
			"option_id": str(option.get("option_id", "")),
			"candidate_id": str(option.get("candidate_id", "")),
			"candidate_fingerprint": str(option.get("candidate_fingerprint", "")),
			"owner_player_id": viewer_player_id,
			"card_instance_id": str(option.get("card_instance_id", "")),
			"card_definition_id": card_definition_id,
			"card_generation": int(option.get("card_generation", 0)),
			"card_action_binding": (
				option.get("card_action_binding", {}) as Dictionary
			).duplicate(true),
			"target_slot_id": str(option.get("target_slot_id", "")),
			"task_kind": task_kind,
			"target_region_id": str(option.get("target_region_id", "")),
			"target_monster_source_instance_id": str(option.get(
				"target_monster_source_instance_id",
				""
			)),
			"asset_cost_by_color": (
				option.get("asset_cost_by_color", {}) as Dictionary
			).duplicate(true),
			"primary_color": str(option.get("primary_color", "")),
			"asset_cost": int(option.get("asset_cost", 0)),
			"primary_asset_cost": int(option.get("primary_asset_cost", 0)),
			"expected_world_revision": int(option.get("expected_world_revision", 0)),
			"military_target_envelope": (
				option.get("military_target_envelope", {}) as Dictionary
			).duplicate(true),
			"target_binding": (
				option.get("target_binding", {}) as Dictionary
			).duplicate(true),
			"display_name": (
				"攻击地区"
				if task_kind == "assault_region"
				else "攻击怪兽"
			),
			"icon_asset_key": str(
				presentation.get("presentation_asset_key", "")
			),
			"presentation_resource_path": str(
				presentation.get("resource_path", "")
			),
			"enabled": combat_requests_allowed and bool(
				option.get("enabled", false)
			),
			"disabled_reason": str(option.get("disabled_reason", "none")),
			"action_domain": "military",
		}
		if task_kind == "assault_monster":
			projected["target_source_generation"] = int(option.get(
				"target_source_generation",
				0
			))
		else:
			projected["expected_region_revision"] = int(
				option.get("expected_region_revision", -1)
			)
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


func _private_source_identity_current(
	source: Dictionary,
	viewer_player_id: String,
	public_monsters: Array
) -> bool:
	var source_id := str(source.get("source_instance_id", ""))
	var source_generation := int(source.get("source_generation", 0))
	return (
		not viewer_player_id.is_empty()
		and str(source.get("owner_player_id", "")) == viewer_player_id
		and not source_id.is_empty()
		and _positive_int_field(source, "source_generation")
		and _public_monster_identity_current(
			source_id,
			source_generation,
			viewer_player_id,
			public_monsters,
			false
		)
	)


func _skill_target_binding_valid(
	skill: Dictionary,
	source: Dictionary,
	viewer_player_id: String,
	authority_snapshot: Dictionary
) -> bool:
	if str(skill.get("skill_definition_id", "")).is_empty():
		return false
	var contract := _normalized_target_contract(
		skill.get("target_contract", {})
	)
	var authored_kind := str(contract.get("target_kind", ""))
	var binding_variant: Variant = skill.get("target_binding", {})
	if not (binding_variant is Dictionary):
		return false
	var binding := binding_variant as Dictionary
	var binding_kind := str(binding.get("target_kind", ""))
	var target_id := str(binding.get("target_id", ""))
	if binding.is_empty() or target_id.is_empty():
		return false
	if authored_kind == "self_source":
		return (
			binding_kind == "monster"
			and target_id == str(source.get("source_instance_id", ""))
			and _positive_int_field(binding, "target_source_generation")
			and _positive_int_field(source, "source_generation")
			and binding.get("target_source_generation")
				== source.get("source_generation")
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
	if authored_kind == "enemy_public_facility":
		if (
			binding_kind != "facility"
			or str(binding.get("target_facility_id", "")) != target_id
			or not _positive_int_field(
				binding,
				"target_facility_generation"
			)
			or binding.has("target_region_id")
			or binding.has("target_monster_source_instance_id")
			or binding.has("target_source_generation")
		):
			return false
		return _facility_binding_current(
			binding,
			viewer_player_id,
			authority_snapshot.get("public_facilities", []) as Array
		)
	if authored_kind in [
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
	if authored_kind == "enemy_public_monster":
		if (
			binding_kind != "monster"
			or not _positive_int_field(binding, "target_source_generation")
			or binding.has("target_facility_id")
			or binding.has("target_facility_generation")
			or binding.has("target_region_id")
			or (
				binding.has("target_monster_source_instance_id")
				and str(binding.get(
					"target_monster_source_instance_id",
					""
				)) != target_id
			)
		):
			return false
		return _public_monster_identity_current(
			target_id,
			int(binding.get("target_source_generation", 0)),
			viewer_player_id,
			authority_snapshot.get("public_monsters", []) as Array,
			true
		)
	return false


func _facility_binding_current(
	binding: Dictionary,
	viewer_player_id: String,
	public_facilities: Array
) -> bool:
	# Some combat projections intentionally omit the public facility roster.
	# In that shape the positive typed generation remains mandatory and the
	# runtime authority performs the final exact-generation comparison.
	if public_facilities.is_empty():
		return true
	var target_id := str(binding.get("target_id", ""))
	var target_generation := int(binding.get(
		"target_facility_generation",
		0
	))
	for facility_variant in public_facilities:
		if not (facility_variant is Dictionary):
			continue
		var facility := facility_variant as Dictionary
		var owner_id := str(facility.get(
			"owner_player_id",
			facility.get("owner_id", "")
		))
		if (
			str(facility.get("facility_id", "")) == target_id
			and _positive_int_field(facility, "facility_generation")
			and int(facility.get("facility_generation", 0)) == target_generation
			and owner_id != viewer_player_id
			and str(facility.get("status", "active")) != "destroyed"
		):
			return true
	return false


func _public_monster_identity_current(
	source_instance_id: String,
	source_generation: int,
	viewer_player_id: String,
	public_monsters: Array,
	require_rival: bool
) -> bool:
	if source_instance_id.is_empty() or source_generation < 1:
		return false
	for monster_variant in public_monsters:
		if not (monster_variant is Dictionary):
			continue
		var monster := monster_variant as Dictionary
		var owner_id := str(monster.get("owner_player_id", ""))
		if (
			str(monster.get("source_instance_id", "")) != source_instance_id
			or not _positive_int_field(monster, "source_generation")
			or int(monster.get("source_generation", 0)) != source_generation
			or (
				require_rival
				and (
					owner_id == viewer_player_id
					or str(monster.get("status", "active")) != "active"
				)
			)
			or (not require_rival and owner_id != viewer_player_id)
		):
			continue
		return true
	return false


func _military_option_valid(
	option: Dictionary,
	viewer_player_id: String,
	authority_snapshot: Dictionary
) -> bool:
	var normalized := CombatCandidate.military_candidate(option, 0)
	if (
		normalized.is_empty()
		or normalized.get("candidate_fingerprint")
			!= option.get("candidate_fingerprint")
	):
		return false
	if str(option.get("action_domain", "military")) != "military":
		return false
	if (
		viewer_player_id.is_empty()
		or str(option.get("owner_player_id", "")) != viewer_player_id
	):
		return false
	for field_name in [
		"option_id",
		"card_instance_id",
		"card_definition_id",
		"target_slot_id",
	]:
		if str(option.get(field_name, "")).is_empty():
			return false
	if not _card_action_binding_valid_for_option(
		option.get("card_action_binding", {}) as Dictionary,
		option,
		viewer_player_id
	):
		return false
	var task_kind := str(option.get("task_kind", ""))
	if task_kind == "assault_region":
		return (
			not str(option.get("target_region_id", "")).is_empty()
			and str(option.get(
				"target_monster_source_instance_id",
				""
			)).is_empty()
			and not option.has("target_source_generation")
		)
	if task_kind == "assault_monster":
		var target_id := str(option.get(
			"target_monster_source_instance_id",
			""
		))
		var target_generation := int(option.get(
			"target_source_generation",
			0
		))
		if (
			target_id.is_empty()
			or not _positive_int_field(option, "target_source_generation")
			or not str(option.get("target_region_id", "")).is_empty()
		):
			return false
		return _public_monster_identity_current(
			target_id,
			target_generation,
			viewer_player_id,
			authority_snapshot.get("public_monsters", []) as Array,
			true
		)
	return false


func _card_action_binding_valid_for_option(
	binding: Dictionary,
	option: Dictionary,
	viewer_player_id: String
) -> bool:
	if binding.size() != CARD_ACTION_BINDING_FIELDS.size():
		return false
	for field_name in CARD_ACTION_BINDING_FIELDS:
		if not binding.has(field_name):
			return false
	if (
		binding.get("schema_id")
			!= "v07.personal_dbg.authoritative_card_action_binding.v1"
		or binding.get("schema_version") != 1
		or binding.get("authority_domain_id") != "v07.personal_dbg"
		or str(binding.get("owner_player_id", "")) != viewer_player_id
		or str(binding.get("card_instance_id", ""))
			!= str(option.get("card_instance_id", ""))
		or str(binding.get("card_definition_id", ""))
			!= str(option.get("card_definition_id", ""))
		or binding.get("authoritative_zone") != "hand"
		or not _positive_int_field(binding, "zone_revision")
		or binding.get("expected_action_lifecycle")
			!= "v075.combat.queue_resolve_personal_discard"
	):
		return false
	for fingerprint_field in [
		"authority_lineage_fingerprint",
		"immutable_identity_fingerprint",
		"lifecycle_evidence_fingerprint",
		"binding_fingerprint",
	]:
		var fingerprint := str(binding.get(fingerprint_field, ""))
		if fingerprint.length() != 64 or not fingerprint.is_valid_hex_number(false):
			return false
	return true


func _positive_int_field(source: Dictionary, field_name: String) -> bool:
	return (
		source.has(field_name)
		and typeof(source.get(field_name)) == TYPE_INT
		and int(source.get(field_name)) > 0
	)


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


func _count_exact_keys(value: Variant, expected_keys: Array) -> int:
	var count := 0
	for expected_key_variant in expected_keys:
		count += _count_exact_key(value, str(expected_key_variant))
	return count
