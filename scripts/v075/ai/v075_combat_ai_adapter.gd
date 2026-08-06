extends RefCounted
class_name V075CombatAIAdapter

const RULESET_ID := "v0.7.5"
const MONSTER_CARD_MODES := [
	"DEPLOY_NEW",
	"REFRESH_EXISTING",
	"UPGRADE_EXISTING",
	"REPLACE_EXISTING",
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
const FORBIDDEN_PUBLIC_KEYS := [
	"private_skill",
	"skill_definition",
	"skill_state",
	"skill_cooldown",
	"pending_skill",
	"skill_target",
	"available_assets_by_player",
	"warehouse_private",
	"private_logistics",
	"future_military",
	"future_skill",
	"hidden_lead_order",
	"ai_private_plan",
	"authority_state",
	"rng_state",
]
const FORBIDDEN_OWN_SCOPE_KEYS := [
	"opponent_skill",
	"other_private_skill",
	"other_available_assets",
	"warehouse_private",
	"private_logistics",
	"future_military",
	"future_public_queue",
	"hidden_lead_order",
	"ai_private_plan",
]
const MODE_SCORE := {
	"DEPLOY_NEW": 720,
	"REFRESH_EXISTING": 820,
	"UPGRADE_EXISTING": 940,
	"REPLACE_EXISTING": 680,
}

var _enumeration_count := 0
var _rejection_count := 0
var _last_reason_code := "not_evaluated"


func enumerate_candidates(
	own_private_facts: Dictionary,
	public_facts: Dictionary
) -> Dictionary:
	_enumeration_count += 1
	var privacy := privacy_report(own_private_facts, public_facts)
	if not bool(privacy.get("valid", false)):
		_rejection_count += 1
		_last_reason_code = str(
			privacy.get("reason_code", "privacy_contract_invalid")
		)
		return _result([], _last_reason_code)
	if str(public_facts.get("phase", "")) in TERMINAL_PHASES:
		_last_reason_code = "terminal_combat_quiescent"
		return _result([], _last_reason_code)

	var candidates: Array[Dictionary] = []
	_append_monster_card_candidates(candidates, own_private_facts)
	_append_private_skill_candidates(
		candidates,
		own_private_facts,
		public_facts
	)
	_append_military_candidates(candidates, own_private_facts, public_facts)
	candidates.sort_custom(_candidate_precedes)
	_last_reason_code = (
		"none"
		if not candidates.is_empty()
		else "no_legal_combat_action"
	)
	return _result(candidates, _last_reason_code)


func choose_action(
	own_private_facts: Dictionary,
	public_facts: Dictionary
) -> Dictionary:
	var result := enumerate_candidates(own_private_facts, public_facts)
	var candidates := result.get("candidates", []) as Array
	if candidates.is_empty():
		return {
			"accepted": false,
			"reason_code": str(
				result.get("reason_code", "no_legal_combat_action")
			),
			"action": {},
		}
	return {
		"accepted": true,
		"reason_code": "none",
		"action": (candidates[0] as Dictionary).duplicate(true),
	}


func privacy_report(
	own_private_facts: Dictionary,
	public_facts: Dictionary
) -> Dictionary:
	var public_violation := _first_forbidden_key(
		public_facts,
		FORBIDDEN_PUBLIC_KEYS
	)
	if not public_violation.is_empty():
		return {
			"valid": false,
			"reason_code": (
				"public_facts_contains_private_field:%s"
				% public_violation
			),
			"hidden_info_violation_count": 1,
		}
	var own_scope_violation := _first_forbidden_key(
		own_private_facts,
		FORBIDDEN_OWN_SCOPE_KEYS
	)
	if not own_scope_violation.is_empty():
		return {
			"valid": false,
			"reason_code": (
				"own_facts_contains_opponent_private_field:%s"
				% own_scope_violation
			),
			"hidden_info_violation_count": 1,
		}
	var viewer_id := str(own_private_facts.get("viewer_player_id", ""))
	if viewer_id.is_empty():
		return {
			"valid": false,
			"reason_code": "viewer_player_id_missing",
			"hidden_info_violation_count": 0,
		}
	for source_variant in own_private_facts.get(
		"owned_monsters",
		[]
	) as Array:
		if not (source_variant is Dictionary):
			return {
				"valid": false,
				"reason_code": "owned_monster_invalid",
				"hidden_info_violation_count": 0,
			}
		var source := source_variant as Dictionary
		var owner_id := str(source.get("owner_player_id", viewer_id))
		if owner_id != viewer_id:
			return {
				"valid": false,
				"reason_code": "opponent_monster_in_own_private_facts",
				"hidden_info_violation_count": 1,
			}
	return {
		"valid": true,
		"reason_code": "none",
		"hidden_info_violation_count": 0,
	}


func debug_snapshot() -> Dictionary:
	return {
		"schema": "V075CombatAIAdapterDebugV1",
		"ruleset_id": RULESET_ID,
		"supported_monster_card_modes": MONSTER_CARD_MODES.duplicate(),
		"supported_military_task_kinds":
			MILITARY_TASK_KINDS.duplicate(),
		"monster_private_skill_supported": true,
		"military_guard_action_count": 0,
		"hidden_info_reader_count": 0,
		"rng_draw_count": 0,
		"enumeration_count": _enumeration_count,
		"rejection_count": _rejection_count,
		"last_reason_code": _last_reason_code,
	}


func _append_monster_card_candidates(
	candidates: Array[Dictionary],
	own_private_facts: Dictionary
) -> void:
	for card_variant in own_private_facts.get(
		"monster_card_options",
		[]
	) as Array:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		var card_instance_id := str(
			card.get("card_instance_id", "")
		)
		var definition_id := str(card.get("card_definition_id", ""))
		if card_instance_id.is_empty() or definition_id.is_empty():
			continue
		var target_by_mode := (
			card.get("prebound_target_by_mode", {}) as Dictionary
		)
		for mode_variant in card.get("legal_modes", []) as Array:
			var mode := str(mode_variant)
			if mode not in MONSTER_CARD_MODES:
				continue
			var target_id := str(target_by_mode.get(mode, ""))
			if target_id.is_empty():
				continue
			var target_field := (
				"target_region_id"
				if mode == "DEPLOY_NEW"
				else "target_source_instance_id"
			)
			var candidate := {
				"action_kind": "monster_card",
				"monster_card_mode": mode,
				"mode_prebound": true,
				"card_instance_id": card_instance_id,
				"card_definition_id": definition_id,
				target_field: target_id,
				"score": int(MODE_SCORE.get(mode, 0))
					+ clampi(int(card.get("card_rank", 1)), 1, 4) * 5,
			}
			candidate["stable_action_key"] = _stable_action_key(candidate)
			candidates.append(candidate)


func _append_private_skill_candidates(
	candidates: Array[Dictionary],
	own_private_facts: Dictionary,
	public_facts: Dictionary
) -> void:
	var available_assets := (
		own_private_facts.get(
			"available_unreserved_assets",
			{}
		) as Dictionary
	)
	for source_variant in own_private_facts.get(
		"owned_monsters",
		[]
	) as Array:
		if not (source_variant is Dictionary):
			continue
		var source := source_variant as Dictionary
		if bool(source.get("batch_active_skill_used", false)):
			continue
		if str(source.get("status", "active")) != "active":
			continue
		var source_id := str(source.get("source_instance_id", ""))
		for skill_variant in source.get("private_skills", []) as Array:
			if not (skill_variant is Dictionary):
				continue
			var skill := skill_variant as Dictionary
			if str(skill.get("state", "")) != "READY":
				continue
			var cost := (
				skill.get("asset_cost_by_color", {}) as Dictionary
			)
			if not _can_pay(cost, available_assets):
				continue
			var target := _stable_skill_target(
				str(skill.get("target_contract", "none")),
				str(own_private_facts.get("viewer_player_id", "")),
				source_id,
				public_facts
			)
			if not bool(target.get("valid", false)):
				continue
			var candidate := {
				"action_kind": "monster_private_skill",
				"execution_mode": "private_instant_serial",
				"private_request": true,
				"source_instance_id": source_id,
				"skill_definition_id": str(
					skill.get("skill_definition_id", "")
				),
				"target_contract": str(
					skill.get("target_contract", "none")
				),
				"target_kind": str(target.get("target_kind", "none")),
				"target_id": str(target.get("target_id", "")),
				"score": 880
					+ (
						80
						if bool(skill.get("ultimate", false))
						else 0
					),
			}
			if str(
				candidate.get("skill_definition_id", "")
			).is_empty():
				continue
			candidate["stable_action_key"] = _stable_action_key(
				candidate
			)
			candidates.append(candidate)


func _append_military_candidates(
	candidates: Array[Dictionary],
	own_private_facts: Dictionary,
	public_facts: Dictionary
) -> void:
	var viewer_id := str(own_private_facts.get("viewer_player_id", ""))
	var region_id := _first_enemy_facility_region(
		viewer_id,
		public_facts
	)
	var monster_id := _first_enemy_monster_id(
		viewer_id,
		public_facts
	)
	for card_variant in own_private_facts.get(
		"military_card_options",
		[]
	) as Array:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		var card_instance_id := str(
			card.get("card_instance_id", "")
		)
		if card_instance_id.is_empty():
			continue
		for task_variant in card.get(
			"legal_task_kinds",
			[]
		) as Array:
			var task_kind := str(task_variant)
			if task_kind not in MILITARY_TASK_KINDS:
				continue
			var target_id := (
				region_id
				if task_kind == "assault_region"
				else monster_id
			)
			if target_id.is_empty():
				continue
			var candidate := {
				"action_kind": "military_mission",
				"task_kind": task_kind,
				"card_instance_id": card_instance_id,
				"card_definition_id": str(
					card.get("card_definition_id", "")
				),
				"target_region_id": (
					target_id
					if task_kind == "assault_region"
					else ""
				),
				"target_monster_source_instance_id": (
					target_id
					if task_kind == "assault_monster"
					else ""
				),
				"one_shot_withdrawal": true,
				"score": (
					640
					if task_kind == "assault_monster"
					else 610
				),
			}
			candidate["stable_action_key"] = _stable_action_key(
				candidate
			)
			candidates.append(candidate)


func _stable_skill_target(
	target_contract: String,
	viewer_id: String,
	source_id: String,
	public_facts: Dictionary
) -> Dictionary:
	match target_contract:
		"none":
			return {
				"valid": true,
				"target_kind": "none",
				"target_id": "",
			}
		"self":
			return {
				"valid": not source_id.is_empty(),
				"target_kind": "monster",
				"target_id": source_id,
			}
		"enemy_facility":
			var facility_id := _first_enemy_facility_id(
				viewer_id,
				public_facts
			)
			return {
				"valid": not facility_id.is_empty(),
				"target_kind": "facility",
				"target_id": facility_id,
			}
		"enemy_monster":
			var monster_id := _first_enemy_monster_id(
				viewer_id,
				public_facts
			)
			return {
				"valid": not monster_id.is_empty(),
				"target_kind": "monster",
				"target_id": monster_id,
			}
		"region":
			var region_id := _first_public_region_id(public_facts)
			return {
				"valid": not region_id.is_empty(),
				"target_kind": "region",
				"target_id": region_id,
			}
	return {
		"valid": false,
		"target_kind": "",
		"target_id": "",
	}


func _first_enemy_facility_id(
	viewer_id: String,
	public_facts: Dictionary
) -> String:
	var candidates: Array[String] = []
	for facility_variant in public_facts.get("facilities", []) as Array:
		if not (facility_variant is Dictionary):
			continue
		var facility := facility_variant as Dictionary
		if str(facility.get("owner_player_id", "")) == viewer_id:
			continue
		if str(facility.get("status", "active")) == "destroyed":
			continue
		var facility_id := str(facility.get("facility_id", ""))
		if not facility_id.is_empty():
			candidates.append(facility_id)
	candidates.sort()
	return candidates[0] if not candidates.is_empty() else ""


func _first_enemy_facility_region(
	viewer_id: String,
	public_facts: Dictionary
) -> String:
	var candidates: Array[String] = []
	for facility_variant in public_facts.get("facilities", []) as Array:
		if not (facility_variant is Dictionary):
			continue
		var facility := facility_variant as Dictionary
		if str(facility.get("owner_player_id", "")) == viewer_id:
			continue
		if str(facility.get("status", "active")) == "destroyed":
			continue
		var region_id := str(facility.get("region_id", ""))
		if (
			not region_id.is_empty()
			and region_id not in candidates
		):
			candidates.append(region_id)
	candidates.sort()
	return candidates[0] if not candidates.is_empty() else ""


func _first_enemy_monster_id(
	viewer_id: String,
	public_facts: Dictionary
) -> String:
	var candidates: Array[String] = []
	for source_variant in public_facts.get("monsters", []) as Array:
		if not (source_variant is Dictionary):
			continue
		var source := source_variant as Dictionary
		if str(source.get("owner_player_id", "")) == viewer_id:
			continue
		if str(source.get("status", "active")) in [
			"destroyed",
			"withdrawn",
		]:
			continue
		var source_id := str(source.get("source_instance_id", ""))
		if not source_id.is_empty():
			candidates.append(source_id)
	candidates.sort()
	return candidates[0] if not candidates.is_empty() else ""


func _first_public_region_id(public_facts: Dictionary) -> String:
	var candidates: Array[String] = []
	for region_variant in public_facts.get("regions", []) as Array:
		if region_variant is Dictionary:
			var region_id := str(
				(region_variant as Dictionary).get("region_id", "")
			)
			if not region_id.is_empty():
				candidates.append(region_id)
		else:
			var region_id := str(region_variant)
			if not region_id.is_empty():
				candidates.append(region_id)
	candidates.sort()
	return candidates[0] if not candidates.is_empty() else ""


func _can_pay(cost: Dictionary, available: Dictionary) -> bool:
	for color_variant in cost.keys():
		var color_id := str(color_variant)
		var amount := int(cost.get(color_variant, 0))
		if amount < 0 or int(available.get(color_id, 0)) < amount:
			return false
	return true


func _candidate_precedes(
	left: Dictionary,
	right: Dictionary
) -> bool:
	var left_score := int(left.get("score", 0))
	var right_score := int(right.get("score", 0))
	if left_score != right_score:
		return left_score > right_score
	return str(left.get("stable_action_key", "")) < str(
		right.get("stable_action_key", "")
	)


func _stable_action_key(candidate: Dictionary) -> String:
	return "|".join([
		str(candidate.get("action_kind", "")),
		str(candidate.get("monster_card_mode", "")),
		str(candidate.get("task_kind", "")),
		str(candidate.get("card_instance_id", "")),
		str(candidate.get("source_instance_id", "")),
		str(candidate.get("skill_definition_id", "")),
		str(candidate.get("target_region_id", "")),
		str(
			candidate.get(
				"target_monster_source_instance_id",
				""
			)
		),
		str(candidate.get("target_id", "")),
	])


func _result(
	candidates: Array[Dictionary],
	reason_code: String
) -> Dictionary:
	return {
		"schema": "V075CombatAICandidateSetV1",
		"ruleset_id": RULESET_ID,
		"accepted": reason_code in [
			"none",
			"no_legal_combat_action",
			"terminal_combat_quiescent",
		],
		"reason_code": reason_code,
		"candidate_count": candidates.size(),
		"candidates": candidates.duplicate(true),
	}


func _first_forbidden_key(
	value: Variant,
	forbidden_fragments: Array
) -> String:
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			var key := str(key_variant).to_lower()
			for fragment_variant in forbidden_fragments:
				if str(fragment_variant) in key:
					return key
			var nested := _first_forbidden_key(
				dictionary.get(key_variant),
				forbidden_fragments
			)
			if not nested.is_empty():
				return nested
	elif value is Array:
		for child_variant in value as Array:
			var nested := _first_forbidden_key(
				child_variant,
				forbidden_fragments
			)
			if not nested.is_empty():
				return nested
	return ""
