extends RefCounted
class_name V075AICombatActionCandidateV1

const CapabilityCatalog := preload(
	"res://scripts/v075/combat/v075_combat_capability_catalog.gd"
)

const SCHEMA_VERSION := "1.0.0"
const CONTRACT_ID := "v075.ai.combat_action_candidate.v1"
const VARIANT_MONSTER_CARD := "MonsterCardCandidate"
const VARIANT_MILITARY_MISSION := "MilitaryMissionCandidate"
const MAX_DEPTH := 12
const CARD_ACTION_BINDING_SCHEMA_ID := (
	"v07.personal_dbg.authoritative_card_action_binding.v1"
)
const CARD_ACTION_LIFECYCLE_ID := (
	"v075.combat.queue_resolve_personal_discard"
)
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
const MONSTER_ACTION_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"request_id",
	"card_instance_id",
	"card_definition_id",
	"owner_player_id",
	"card_rank",
	"monster_card_mode",
	"target_source_instance_id",
	"target_source_generation",
	"expected_hp_revision",
	"expected_region_revision",
	"deployment_region_id",
	"bound_state_revision",
	"definition_snapshot",
	"prebound",
	"mode_auto_conversion_allowed",
	"action_fingerprint",
]
const MONSTER_BASE_FIELDS := [
	"schema_version", "contract_id", "variant_type", "candidate_id",
	"actor_player_id", "actor_id", "card_instance_id",
	"card_definition_id", "card_generation", "card_action_binding",
	"action_domain", "action_kind", "monster_card_mode",
	"target_binding", "prebound_monster_action",
	"expected_world_revision", "expected_hp_revision", "asset_cost",
	"card_rank",
	"primary_color", "primary_asset_cost", "enabled",
	"legality_reason", "public_information_fingerprint",
	"private_information_fingerprint", "priority_features",
	"mode_prebound", "target_bound", "runtime_reselection_allowed",
	"runtime_mode_conversion_allowed", "option_id", "target_slot_id",
	"target_region_id", "target_source_instance_id", "score",
	"candidate_fingerprint",
]
const MILITARY_BASE_FIELDS := [
	"schema_version", "contract_id", "variant_type", "candidate_id",
	"actor_player_id", "owner_player_id", "card_instance_id",
	"card_definition_id", "card_generation", "card_action_binding",
	"action_domain", "action_kind", "military_mission_kind",
	"task_kind", "target_binding", "military_target_envelope",
	"expected_world_revision", "asset_cost", "primary_color",
	"primary_asset_cost", "enabled", "disabled_reason",
	"legality_reason", "public_information_fingerprint",
	"private_information_fingerprint", "priority_features",
	"mode_prebound", "target_bound", "runtime_reselection_allowed",
	"runtime_mode_conversion_allowed", "one_shot_withdrawal",
	"option_id", "target_slot_id", "target_region_id",
	"target_monster_source_instance_id", "asset_cost_by_color",
	"score", "candidate_fingerprint",
]
const MONSTER_TARGET_REFRESH_FIELDS := [
	"target_kind",
	"target_source_instance_id",
	"target_source_generation",
	"expected_hp_revision",
]
const MONSTER_TARGET_SOURCE_FIELDS := [
	"target_kind",
	"target_source_instance_id",
	"target_source_generation",
]
const MONSTER_TARGET_REGION_FIELDS := [
	"target_kind",
	"target_region_id",
	"expected_region_revision",
]
const MONSTER_TARGET_REPLACE_FIELDS := [
	"target_kind",
	"withdraw_source_id",
	"withdraw_source_generation",
	"deploy_target_region_id",
	"expected_region_revision",
]
const MILITARY_REGION_ENVELOPE_FIELDS := [
	"schema_version", "contract_id", "task_kind",
	"public_information_fingerprint", "envelope_fingerprint",
	"target_region_id", "expected_region_revision",
	"locked_enemy_facility_ids", "facility_generations",
	"region_damage_budget",
]
const MILITARY_MONSTER_ENVELOPE_FIELDS := [
	"schema_version", "contract_id", "task_kind",
	"public_information_fingerprint", "envelope_fingerprint",
	"target_monster_source_instance_id", "target_source_generation",
	"target_monster_revision", "target_monster_owner_player_id",
	"public_target_region_id", "monster_damage",
]


static func monster_candidate(option: Dictionary, score: int) -> Dictionary:
	var card_context := _card_context(option)
	if card_context.is_empty():
		return {}
	var action_variant: Variant = option.get("prebound_monster_action", null)
	if not (action_variant is Dictionary):
		return {}
	var action := action_variant as Dictionary
	var mode := str(option.get("monster_card_mode", ""))
	if (
		not CapabilityCatalog.is_monster_card_mode(mode)
		or str(action.get("monster_card_mode", "")) != mode
		or action.get("prebound") != true
		or action.get("mode_auto_conversion_allowed") != false
		or str(action.get("card_instance_id", ""))
			!= str(option.get("card_instance_id", ""))
		or str(action.get("card_definition_id", ""))
			!= str(option.get("card_definition_id", ""))
		or str(action.get("owner_player_id", ""))
			!= str(option.get("actor_id", ""))
		or not _positive_int(action, "bound_state_revision")
		or not _fingerprint(action.get("action_fingerprint"))
	):
		return {}
	var target_binding := _monster_target_binding(option, action, mode)
	if target_binding.is_empty():
		return {}
	var result := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": CONTRACT_ID,
		"variant_type": VARIANT_MONSTER_CARD,
		"candidate_id": str(option.get("option_id", "")),
		"actor_player_id": str(option.get("actor_id", "")),
		"actor_id": str(option.get("actor_id", "")),
		"card_instance_id": str(option.get("card_instance_id", "")),
		"card_definition_id": str(option.get("card_definition_id", "")),
		"card_generation": int(card_context.get("card_generation", 0)),
		"card_action_binding": (
			option.get("card_action_binding", {}) as Dictionary
		).duplicate(true),
		"action_domain": "monster",
		"action_kind": "monster_card",
		"monster_card_mode": mode,
		"target_binding": target_binding,
		"prebound_monster_action": action.duplicate(true),
		"expected_world_revision": int(action.get("bound_state_revision", 0)),
		"expected_hp_revision": int(action.get("expected_hp_revision", -1)),
		"asset_cost": _asset_cost(option),
		"card_rank": int(option.get("card_rank", action.get("card_rank", 0))),
		"primary_color": str(option.get("primary_color", "")),
		"primary_asset_cost": _primary_asset_cost(option),
		"enabled": true,
		"legality_reason": "current_legal_action",
		"public_information_fingerprint": _hash(target_binding),
		"private_information_fingerprint": _hash({
			"card_instance_id": option.get("card_instance_id"),
			"binding_fingerprint": (
				option.get("card_action_binding", {}) as Dictionary
			).get("binding_fingerprint"),
		}),
		"priority_features": {"score": score},
		"mode_prebound": true,
		"target_bound": true,
		"runtime_reselection_allowed": false,
		"runtime_mode_conversion_allowed": false,
		"option_id": str(option.get("option_id", "")),
		"target_slot_id": str(option.get("target_slot_id", "")),
		"target_region_id": str(option.get("target_region_id", "")),
		"target_source_instance_id": str(option.get("target_source_instance_id", "")),
		"score": score,
		"candidate_fingerprint": "",
	}
	if target_binding.has("target_source_generation"):
		result["target_source_generation"] = int(
			target_binding.get("target_source_generation", 0)
		)
	if target_binding.has("expected_region_revision"):
		result["expected_region_revision"] = int(
			target_binding.get("expected_region_revision", 0)
		)
	if mode == CapabilityCatalog.MONSTER_MODE_REPLACE_EXISTING:
		result["target_source_generation"] = int(
			target_binding.get("withdraw_source_generation", 0)
		)
		result["withdraw_source_id"] = str(
			target_binding.get("withdraw_source_id", "")
		)
		result["withdraw_source_generation"] = int(
			target_binding.get("withdraw_source_generation", 0)
		)
		result["deploy_target_region_id"] = str(
			target_binding.get("deploy_target_region_id", "")
		)
	if mode == CapabilityCatalog.MONSTER_MODE_UPGRADE_EXISTING:
		result["target_rank"] = int(action.get("card_rank", 0))
	result["candidate_fingerprint"] = _candidate_identity_fingerprint(result)
	return result if validation_report(result).get("valid", false) else {}


static func military_candidate(option: Dictionary, score: int) -> Dictionary:
	var card_context := _card_context(option)
	if card_context.is_empty():
		return {}
	var mission_kind := str(option.get("task_kind", ""))
	var envelope_variant: Variant = option.get("military_target_envelope", null)
	if (
		not CapabilityCatalog.is_military_mission_kind(mission_kind)
		or not (envelope_variant is Dictionary)
		or not _positive_int(option, "expected_world_revision")
	):
		return {}
	var envelope := envelope_variant as Dictionary
	if not _military_envelope_valid(envelope, mission_kind):
		return {}
	var result := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": CONTRACT_ID,
		"variant_type": VARIANT_MILITARY_MISSION,
		"candidate_id": str(option.get("option_id", "")),
		"actor_player_id": str(option.get("owner_player_id", "")),
		"owner_player_id": str(option.get("owner_player_id", "")),
		"card_instance_id": str(option.get("card_instance_id", "")),
		"card_definition_id": str(option.get("card_definition_id", "")),
		"card_generation": int(card_context.get("card_generation", 0)),
		"card_action_binding": (
			option.get("card_action_binding", {}) as Dictionary
		).duplicate(true),
		"action_domain": "military",
		"action_kind": "military_mission",
		"military_mission_kind": mission_kind,
		"task_kind": mission_kind,
		"target_binding": envelope.duplicate(true),
		"military_target_envelope": envelope.duplicate(true),
		"expected_world_revision": int(option.get("expected_world_revision", 0)),
		"asset_cost": _asset_cost(option),
		"primary_color": str(option.get("primary_color", "")),
		"primary_asset_cost": _primary_asset_cost(option),
		"enabled": true,
		"disabled_reason": "none",
		"legality_reason": "current_legal_action",
		"public_information_fingerprint": str(
			envelope.get("public_information_fingerprint", "")
		),
		"private_information_fingerprint": _hash({
			"card_instance_id": option.get("card_instance_id"),
			"binding_fingerprint": (
				option.get("card_action_binding", {}) as Dictionary
			).get("binding_fingerprint"),
		}),
		"priority_features": {"score": score},
		"mode_prebound": true,
		"target_bound": true,
		"runtime_reselection_allowed": false,
		"runtime_mode_conversion_allowed": false,
		"one_shot_withdrawal": true,
		"option_id": str(option.get("option_id", "")),
		"target_slot_id": str(option.get("target_slot_id", "")),
		"target_region_id": str(option.get("target_region_id", "")),
		"target_monster_source_instance_id": str(
			option.get("target_monster_source_instance_id", "")
		),
		"asset_cost_by_color": _asset_cost(option),
		"score": score,
		"candidate_fingerprint": "",
	}
	if mission_kind == CapabilityCatalog.MILITARY_MISSION_ASSAULT_REGION:
		result["expected_region_revision"] = int(
			envelope.get("expected_region_revision", -1)
		)
	else:
		result["target_source_generation"] = int(
			envelope.get("target_source_generation", 0)
		)
	result["candidate_fingerprint"] = _candidate_identity_fingerprint(result)
	return result if validation_report(result).get("valid", false) else {}


static func validation_report(value: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not (value is Dictionary) or not _closed_data(value):
		errors.append("candidate_not_closed_data")
		return _report(errors)
	var candidate := value as Dictionary
	if (
		typeof(candidate.get("schema_version")) != TYPE_STRING
		or str(candidate.get("schema_version", "")) != SCHEMA_VERSION
	):
		errors.append("candidate_schema_version_invalid")
	if (
		typeof(candidate.get("contract_id")) != TYPE_STRING
		or str(candidate.get("contract_id", "")) != CONTRACT_ID
	):
		errors.append("candidate_contract_id_invalid")
	var variant_type := str(candidate.get("variant_type", ""))
	if variant_type == VARIANT_MONSTER_CARD:
		_validate_monster_candidate(candidate, errors)
	elif variant_type == VARIANT_MILITARY_MISSION:
		_validate_military_candidate(candidate, errors)
	else:
		errors.append("candidate_variant_unknown")
	_validate_common_candidate(candidate, errors)
	var fingerprint := str(candidate.get("candidate_fingerprint", ""))
	if (
		not _fingerprint(fingerprint)
		or fingerprint != _candidate_identity_fingerprint(candidate)
	):
		errors.append("candidate_fingerprint_invalid")
	return _report(errors)


static func _validate_common_candidate(
	candidate: Dictionary,
	errors: Array[String]
) -> void:
	for field_name in [
		"candidate_id", "actor_player_id", "card_instance_id",
		"card_definition_id", "option_id", "target_slot_id",
	]:
		if typeof(candidate.get(field_name)) != TYPE_STRING or str(
			candidate.get(field_name, "")
		).is_empty():
			errors.append("candidate_identity_invalid_%s" % field_name)
	if candidate.get("candidate_id") != candidate.get("option_id"):
		errors.append("candidate_option_identity_mismatch")
	if not _positive_int(candidate, "card_generation"):
		errors.append("candidate_card_generation_invalid")
	if not _positive_int(candidate, "expected_world_revision"):
		errors.append("candidate_world_revision_invalid")
	for flag_name in ["enabled", "mode_prebound", "target_bound"]:
		if candidate.get(flag_name) != true:
			errors.append("candidate_required_flag_invalid_%s" % flag_name)
	for flag_name in [
		"runtime_reselection_allowed", "runtime_mode_conversion_allowed",
	]:
		if candidate.get(flag_name) != false:
			errors.append("candidate_forbidden_flag_invalid_%s" % flag_name)
	if candidate.get("legality_reason") != "current_legal_action":
		errors.append("candidate_legality_reason_invalid")
	if typeof(candidate.get("score")) != TYPE_INT:
		errors.append("candidate_score_invalid")
	var features_variant: Variant = candidate.get("priority_features")
	if not (features_variant is Dictionary):
		errors.append("candidate_priority_features_invalid")
	else:
		var features := features_variant as Dictionary
		if (
			not _exact_fields(features, ["score"])
			or typeof(features.get("score")) != TYPE_INT
			or features.get("score") != candidate.get("score")
		):
			errors.append("candidate_priority_features_invalid")
	if not _asset_cost_valid(candidate.get("asset_cost")):
		errors.append("candidate_asset_cost_invalid")
	if (
		typeof(candidate.get("primary_color")) != TYPE_STRING
		or str(candidate.get("primary_color", "")).is_empty()
		or not _nonnegative_int(candidate, "primary_asset_cost")
	):
		errors.append("candidate_primary_asset_cost_invalid")
	var expected_cost := {}
	if int(candidate.get("primary_asset_cost", 0)) > 0:
		expected_cost[str(candidate.get("primary_color", ""))] = int(
			candidate.get("primary_asset_cost", 0)
		)
	if candidate.get("asset_cost") != expected_cost:
		errors.append("candidate_asset_cost_projection_mismatch")
	var binding_variant: Variant = candidate.get("card_action_binding")
	if not (binding_variant is Dictionary) or not _card_binding_valid(
		binding_variant as Dictionary,
		candidate
	):
		errors.append("candidate_card_action_binding_invalid")
	var public_fingerprint := str(
		candidate.get("public_information_fingerprint", "")
	)
	var private_fingerprint := str(
		candidate.get("private_information_fingerprint", "")
	)
	if not _fingerprint(public_fingerprint):
		errors.append("candidate_public_information_fingerprint_invalid")
	if (
		not _fingerprint(private_fingerprint)
		or private_fingerprint != _hash({
			"card_instance_id": candidate.get("card_instance_id"),
			"binding_fingerprint": (
				candidate.get("card_action_binding") as Dictionary
			).get("binding_fingerprint"),
		})
	):
		errors.append("candidate_private_information_fingerprint_invalid")
	if candidate.has("stable_action_key") and (
		typeof(candidate.get("stable_action_key")) != TYPE_STRING
		or str(candidate.get("stable_action_key", "")).is_empty()
	):
		errors.append("candidate_stable_action_key_invalid")


static func _validate_monster_candidate(
	candidate: Dictionary,
	errors: Array[String]
) -> void:
	var mode := str(candidate.get("monster_card_mode", ""))
	var expected_fields := MONSTER_BASE_FIELDS.duplicate()
	match mode:
		CapabilityCatalog.MONSTER_MODE_DEPLOY_NEW:
			expected_fields.append("expected_region_revision")
		CapabilityCatalog.MONSTER_MODE_REFRESH_EXISTING:
			expected_fields.append("target_source_generation")
		CapabilityCatalog.MONSTER_MODE_UPGRADE_EXISTING:
			expected_fields.append_array([
				"target_source_generation", "target_rank",
			])
		CapabilityCatalog.MONSTER_MODE_REPLACE_EXISTING:
			expected_fields.append_array([
				"target_source_generation", "expected_region_revision",
				"withdraw_source_id", "withdraw_source_generation",
				"deploy_target_region_id",
			])
	if candidate.has("stable_action_key"):
		expected_fields.append("stable_action_key")
	if not _exact_fields(candidate, expected_fields):
		errors.append("monster_candidate_fields_invalid")
	if (
		candidate.get("action_domain") != "monster"
		or candidate.get("action_kind") != "monster_card"
		or candidate.get("actor_id") != candidate.get("actor_player_id")
		or not CapabilityCatalog.is_monster_card_mode(mode)
		or not _positive_int(candidate, "card_rank")
	):
		errors.append("monster_candidate_variant_invalid")
	if (
		typeof(candidate.get("expected_hp_revision")) != TYPE_INT
		or (
			mode == CapabilityCatalog.MONSTER_MODE_REFRESH_EXISTING
			and int(candidate.get("expected_hp_revision", -1)) < 0
		)
		or (
			mode != CapabilityCatalog.MONSTER_MODE_REFRESH_EXISTING
			and int(candidate.get("expected_hp_revision", -2)) != -1
		)
	):
		errors.append("monster_candidate_hp_revision_invalid")
	var action_variant: Variant = candidate.get("prebound_monster_action")
	var target_variant: Variant = candidate.get("target_binding")
	if not (action_variant is Dictionary) or not (target_variant is Dictionary):
		errors.append("monster_candidate_binding_type_invalid")
		return
	var action := action_variant as Dictionary
	var target := target_variant as Dictionary
	if not _monster_action_valid(action, candidate):
		errors.append("monster_candidate_prebound_action_invalid")
	if not _monster_target_binding_valid(target, candidate, action, mode):
		errors.append("monster_candidate_target_binding_invalid")
	if candidate.get("public_information_fingerprint") != _hash(target):
		errors.append("monster_candidate_public_fingerprint_mismatch")


static func _validate_military_candidate(
	candidate: Dictionary,
	errors: Array[String]
) -> void:
	var mission_kind := str(candidate.get("military_mission_kind", ""))
	var expected_fields := MILITARY_BASE_FIELDS.duplicate()
	if mission_kind == CapabilityCatalog.MILITARY_MISSION_ASSAULT_REGION:
		expected_fields.append("expected_region_revision")
	else:
		expected_fields.append("target_source_generation")
	if candidate.has("stable_action_key"):
		expected_fields.append("stable_action_key")
	if not _exact_fields(candidate, expected_fields):
		errors.append("military_candidate_fields_invalid")
	if (
		candidate.get("action_domain") != "military"
		or candidate.get("action_kind") != "military_mission"
		or candidate.get("owner_player_id") != candidate.get("actor_player_id")
		or candidate.get("task_kind") != mission_kind
		or not CapabilityCatalog.is_military_mission_kind(mission_kind)
		or candidate.get("one_shot_withdrawal") != true
		or candidate.get("disabled_reason") != "none"
	):
		errors.append("military_candidate_variant_invalid")
	var envelope_variant: Variant = candidate.get("military_target_envelope")
	if not (envelope_variant is Dictionary):
		errors.append("military_candidate_envelope_type_invalid")
		return
	var envelope := envelope_variant as Dictionary
	if (
		candidate.get("target_binding") != envelope
		or not _military_envelope_valid(envelope, mission_kind)
	):
		errors.append("military_candidate_envelope_invalid")
	if candidate.get("public_information_fingerprint") != envelope.get(
		"public_information_fingerprint"
	):
		errors.append("military_candidate_public_fingerprint_mismatch")
	if candidate.get("asset_cost_by_color") != candidate.get("asset_cost"):
		errors.append("military_candidate_asset_cost_mismatch")
	if mission_kind == CapabilityCatalog.MILITARY_MISSION_ASSAULT_REGION:
		if (
			candidate.get("target_region_id") != envelope.get("target_region_id")
			or candidate.get("expected_region_revision")
				!= envelope.get("expected_region_revision")
			or not str(candidate.get(
				"target_monster_source_instance_id", ""
			)).is_empty()
		):
			errors.append("military_region_candidate_lineage_invalid")
	else:
		if (
			candidate.get("target_monster_source_instance_id")
				!= envelope.get("target_monster_source_instance_id")
			or candidate.get("target_source_generation")
				!= envelope.get("target_source_generation")
			or not str(candidate.get("target_region_id", "")).is_empty()
		):
			errors.append("military_monster_candidate_lineage_invalid")


static func _card_binding_valid(
	binding: Dictionary,
	candidate: Dictionary
) -> bool:
	if not _exact_fields(binding, CARD_ACTION_BINDING_FIELDS):
		return false
	if (
		binding.get("schema_id") != CARD_ACTION_BINDING_SCHEMA_ID
		or binding.get("schema_version") != 1
		or binding.get("authority_domain_id") != "v07.personal_dbg"
		or binding.get("owner_player_id") != candidate.get("actor_player_id")
		or binding.get("card_instance_id") != candidate.get("card_instance_id")
		or binding.get("card_definition_id") != candidate.get("card_definition_id")
		or binding.get("authoritative_zone") != "hand"
		or binding.get("zone_revision") != candidate.get("card_generation")
		or binding.get("expected_action_lifecycle") != CARD_ACTION_LIFECYCLE_ID
	):
		return false
	for field_name in [
		"authority_lineage_fingerprint", "immutable_identity_fingerprint",
		"lifecycle_evidence_fingerprint", "binding_fingerprint",
	]:
		if not _fingerprint(binding.get(field_name)):
			return false
	return binding.get("binding_fingerprint") == _hash_without(
		binding, "binding_fingerprint"
	)


static func _monster_action_valid(
	action: Dictionary,
	candidate: Dictionary
) -> bool:
	return (
		_exact_fields(action, MONSTER_ACTION_FIELDS)
		and action.get("schema_version") == "1.0.0"
		and action.get("contract_id") == "v075.monster_card_prebound_action.v1"
		and action.get("ruleset_id") == "v0.7.5"
		and action.get("card_instance_id") == candidate.get("card_instance_id")
		and action.get("card_definition_id") == candidate.get("card_definition_id")
		and action.get("owner_player_id") == candidate.get("actor_player_id")
		and action.get("card_rank") == candidate.get("card_rank")
		and action.get("monster_card_mode") == candidate.get("monster_card_mode")
		and action.get("bound_state_revision") == candidate.get("expected_world_revision")
		and action.get("expected_hp_revision") == candidate.get("expected_hp_revision")
		and action.get("expected_region_revision")
			== candidate.get("expected_region_revision", -1)
		and action.get("prebound") == true
		and action.get("mode_auto_conversion_allowed") == false
		and _fingerprint(action.get("action_fingerprint"))
		and action.get("action_fingerprint") == _hash_without(
			action, "action_fingerprint"
		)
	)


static func _monster_target_binding_valid(
	target: Dictionary,
	candidate: Dictionary,
	action: Dictionary,
	mode: String
) -> bool:
	if (
		candidate.get("target_region_id") != action.get("deployment_region_id")
		or candidate.get("target_source_instance_id")
			!= action.get("target_source_instance_id")
	):
		return false
	if mode == CapabilityCatalog.MONSTER_MODE_DEPLOY_NEW:
		return (
			_exact_fields(target, MONSTER_TARGET_REGION_FIELDS)
			and target.get("target_kind") == "region"
			and target.get("target_region_id") == action.get("deployment_region_id")
			and target.get("expected_region_revision")
				== candidate.get("expected_region_revision")
			and str(action.get("target_source_instance_id", "")).is_empty()
			and action.get("target_source_generation") == 0
		)
	if mode == CapabilityCatalog.MONSTER_MODE_REPLACE_EXISTING:
		return (
			_exact_fields(target, MONSTER_TARGET_REPLACE_FIELDS)
			and target.get("target_kind") == "monster_replace"
			and target.get("withdraw_source_id")
				== action.get("target_source_instance_id")
			and target.get("withdraw_source_generation")
				== action.get("target_source_generation")
			and target.get("deploy_target_region_id")
				== action.get("deployment_region_id")
			and target.get("expected_region_revision")
				== candidate.get("expected_region_revision")
			and candidate.get("withdraw_source_id") == target.get("withdraw_source_id")
			and candidate.get("withdraw_source_generation")
				== target.get("withdraw_source_generation")
			and candidate.get("deploy_target_region_id")
				== target.get("deploy_target_region_id")
			and candidate.get("target_source_generation")
				== action.get("target_source_generation")
		)
	var expected_target_fields := (
		MONSTER_TARGET_REFRESH_FIELDS
		if mode == CapabilityCatalog.MONSTER_MODE_REFRESH_EXISTING
		else MONSTER_TARGET_SOURCE_FIELDS
	)
	var valid: bool = (
		_exact_fields(target, expected_target_fields)
		and target.get("target_kind") == "monster_source"
		and target.get("target_source_instance_id")
			== action.get("target_source_instance_id")
		and target.get("target_source_generation")
			== action.get("target_source_generation")
		and candidate.get("target_source_generation")
			== action.get("target_source_generation")
	)
	if mode == CapabilityCatalog.MONSTER_MODE_REFRESH_EXISTING:
		valid = valid and target.get("expected_hp_revision") == (
			action.get("expected_hp_revision")
		)
	if mode == CapabilityCatalog.MONSTER_MODE_UPGRADE_EXISTING:
		valid = valid and candidate.get("target_rank") == action.get("card_rank")
	return valid


static func _monster_target_binding(
	option: Dictionary,
	action: Dictionary,
	mode: String
) -> Dictionary:
	var target_source_id := str(action.get("target_source_instance_id", ""))
	var target_generation := int(action.get("target_source_generation", 0))
	var deployment_region_id := str(action.get("deployment_region_id", ""))
	if (
		str(option.get("target_source_instance_id", "")) != target_source_id
		or str(option.get("target_region_id", "")) != deployment_region_id
	):
		return {}
	if mode == CapabilityCatalog.MONSTER_MODE_DEPLOY_NEW:
		if (
			not target_source_id.is_empty()
			or target_generation != 0
			or deployment_region_id.is_empty()
			or not _nonnegative_int(option, "expected_region_revision")
		):
			return {}
		return {
			"target_kind": "region",
			"target_region_id": deployment_region_id,
			"expected_region_revision": int(option.get("expected_region_revision", -1)),
		}
	if target_source_id.is_empty() or target_generation < 1:
		return {}
	if mode == CapabilityCatalog.MONSTER_MODE_REFRESH_EXISTING:
		if (
			not _nonnegative_int(option, "expected_hp_revision")
			or option.get("expected_hp_revision")
				!= action.get("expected_hp_revision")
		):
			return {}
		return {
			"target_kind": "monster_source",
			"target_source_instance_id": target_source_id,
			"target_source_generation": target_generation,
			"expected_hp_revision": int(option.get("expected_hp_revision", -1)),
		}
	if mode == CapabilityCatalog.MONSTER_MODE_REPLACE_EXISTING:
		if deployment_region_id.is_empty() or not _nonnegative_int(
			option,
			"expected_region_revision"
		):
			return {}
		return {
			"target_kind": "monster_replace",
			"withdraw_source_id": target_source_id,
			"withdraw_source_generation": target_generation,
			"deploy_target_region_id": deployment_region_id,
			"expected_region_revision": int(option.get("expected_region_revision", -1)),
		}
	return {
		"target_kind": "monster_source",
		"target_source_instance_id": target_source_id,
		"target_source_generation": target_generation,
	}


static func _military_envelope_valid(envelope: Dictionary, mission_kind: String) -> bool:
	var expected_fields := (
		MILITARY_REGION_ENVELOPE_FIELDS
		if mission_kind == CapabilityCatalog.MILITARY_MISSION_ASSAULT_REGION
		else MILITARY_MONSTER_ENVELOPE_FIELDS
	)
	if (
		not _exact_fields(envelope, expected_fields) or
		envelope.get("schema_version") != "1.0.0"
		or envelope.get("contract_id") != "v075.military.target_envelope.v1"
		or envelope.get("task_kind") != mission_kind
		or not _fingerprint(envelope.get("public_information_fingerprint"))
		or not _fingerprint(envelope.get("envelope_fingerprint"))
		or envelope.get("envelope_fingerprint")
			!= _hash_without(envelope, "envelope_fingerprint")
	):
		return false
	var public_payload := envelope.duplicate(true)
	public_payload.erase("public_information_fingerprint")
	public_payload.erase("envelope_fingerprint")
	if envelope.get("public_information_fingerprint") != _hash(public_payload):
		return false
	if mission_kind == CapabilityCatalog.MILITARY_MISSION_ASSAULT_REGION:
		var facility_ids_variant: Variant = envelope.get("locked_enemy_facility_ids")
		var generations_variant: Variant = envelope.get("facility_generations")
		if not (facility_ids_variant is Array) or not (generations_variant is Dictionary):
			return false
		var facility_ids := facility_ids_variant as Array
		var generations := generations_variant as Dictionary
		var sorted_ids: Array[String] = []
		for facility_id_variant in facility_ids:
			if typeof(facility_id_variant) != TYPE_STRING:
				return false
			var facility_id := str(facility_id_variant)
			if facility_id.is_empty() or facility_id in sorted_ids:
				return false
			sorted_ids.append(facility_id)
		sorted_ids.sort()
		if sorted_ids != facility_ids or generations.size() != sorted_ids.size():
			return false
		for facility_id in sorted_ids:
			if (
				not generations.has(facility_id)
				or typeof(generations.get(facility_id)) != TYPE_INT
				or int(generations.get(facility_id, 0)) < 1
			):
				return false
		return (
			not str(envelope.get("target_region_id", "")).is_empty()
			and _nonnegative_int(envelope, "expected_region_revision")
			and not facility_ids.is_empty()
			and _positive_int(envelope, "region_damage_budget")
		)
	return (
		not str(envelope.get("target_monster_source_instance_id", "")).is_empty()
		and _positive_int(envelope, "target_source_generation")
		and _nonnegative_int(envelope, "target_monster_revision")
		and not str(envelope.get("target_monster_owner_player_id", "")).is_empty()
		and not str(envelope.get("public_target_region_id", "")).is_empty()
		and _positive_int(envelope, "monster_damage")
	)


static func _asset_cost_valid(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	for key_variant in (value as Dictionary).keys():
		if (
			typeof(key_variant) != TYPE_STRING
			or str(key_variant).is_empty()
			or typeof((value as Dictionary).get(key_variant)) != TYPE_INT
			or int((value as Dictionary).get(key_variant, -1)) < 0
		):
			return false
	return true


static func _exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _card_context(option: Dictionary) -> Dictionary:
	for field_name in [
		"option_id",
		"card_instance_id",
		"card_definition_id",
		"target_slot_id",
	]:
		if str(option.get(field_name, "")).is_empty():
			return {}
	var binding_variant: Variant = option.get("card_action_binding", null)
	if not (binding_variant is Dictionary):
		return {}
	var binding := binding_variant as Dictionary
	if (
		not _positive_int(binding, "zone_revision")
		or str(binding.get("card_instance_id", ""))
			!= str(option.get("card_instance_id", ""))
		or str(binding.get("card_definition_id", ""))
			!= str(option.get("card_definition_id", ""))
		or not _fingerprint(binding.get("binding_fingerprint"))
	):
		return {}
	return {"card_generation": int(binding.get("zone_revision", 0))}


static func _primary_asset_cost(option: Dictionary) -> int:
	var canonical: Variant = option.get("primary_asset_cost", null)
	if canonical != null:
		return maxi(0, int(canonical)) if typeof(canonical) == TYPE_INT else -1
	var legacy: Variant = option.get("asset_cost", null)
	if typeof(legacy) == TYPE_INT:
		return maxi(0, int(legacy))
	var color_id := str(option.get("primary_color", ""))
	if legacy is Dictionary and not color_id.is_empty():
		var amount: Variant = (legacy as Dictionary).get(color_id, null)
		return maxi(0, int(amount)) if typeof(amount) == TYPE_INT else -1
	return -1


static func _asset_cost(option: Dictionary) -> Dictionary:
	var direct: Variant = option.get("asset_cost_by_color", null)
	if direct is Dictionary:
		return (direct as Dictionary).duplicate(true)
	var canonical: Variant = option.get("asset_cost", null)
	if canonical is Dictionary:
		return (canonical as Dictionary).duplicate(true)
	var color_id := str(option.get("primary_color", ""))
	var amount := _primary_asset_cost(option)
	return {color_id: amount} if not color_id.is_empty() and amount > 0 else {}


static func _report(errors: Array[String]) -> Dictionary:
	return {
		"valid": errors.is_empty(),
		"reason_code": "none" if errors.is_empty() else errors[0],
		"error_count": errors.size(),
		"errors": errors,
	}


static func _positive_int(source: Dictionary, field_name: String) -> bool:
	return source.has(field_name) and typeof(source.get(field_name)) == TYPE_INT and int(source.get(field_name)) > 0


static func _nonnegative_int(source: Dictionary, field_name: String) -> bool:
	return source.has(field_name) and typeof(source.get(field_name)) == TYPE_INT and int(source.get(field_name)) >= 0


static func _fingerprint(value: Variant) -> bool:
	var text := str(value)
	return text.length() == 64 and text.is_valid_hex_number(false)


static func _hash_without(value: Dictionary, field_name: String) -> String:
	var copy := value.duplicate(true)
	copy.erase(field_name)
	return _hash(copy)


static func _candidate_identity_fingerprint(value: Dictionary) -> String:
	var copy := value.duplicate(true)
	for field_name in [
		"candidate_fingerprint",
		"priority_features",
		"score",
		"stable_action_key",
	]:
		copy.erase(field_name)
	return _hash(copy)


static func _hash(value: Variant) -> String:
	return _canonical_json(value).sha256_text()


static func _canonical_json(value: Variant) -> String:
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array[String] = []
		for key_variant in source.keys():
			keys.append(str(key_variant))
		keys.sort()
		var pairs: Array[String] = []
		for key in keys:
			pairs.append("%s:%s" % [JSON.stringify(key), _canonical_json(source.get(key))])
		return "{%s}" % ",".join(pairs)
	if value is Array:
		var rows: Array[String] = []
		for child in value as Array:
			rows.append(_canonical_json(child))
		return "[%s]" % ",".join(rows)
	return JSON.stringify(value)


static func _closed_data(value: Variant, depth: int = 0) -> bool:
	if depth > MAX_DEPTH:
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if typeof(key_variant) != TYPE_STRING or not _closed_data((value as Dictionary).get(key_variant), depth + 1):
				return false
		return true
	if value is Array:
		for child in value as Array:
			if not _closed_data(child, depth + 1):
				return false
		return true
	return typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_STRING]
