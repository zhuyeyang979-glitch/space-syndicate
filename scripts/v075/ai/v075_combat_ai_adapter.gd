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
const FORBIDDEN_PUBLIC_EXACT_KEYS := [
	"card_action_binding",
	"authority_lineage_fingerprint",
	"immutable_identity_fingerprint",
	"authoritative_zone",
	"zone_revision",
	"lifecycle_evidence_fingerprint",
	"expected_action_lifecycle",
	"binding_fingerprint",
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
const CardDefinitionsV075 := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)
const COLORS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]
const TRACK_LOCAL_VISIBLE_CAPACITY := 10
const TRACK_REFILL_MODE := "shared_scroll_vacancy"
const TRACK_SLOW_SUSHI_MOTION := true
const TRACK_IMMEDIATE_REFILL_ON_ACQUISITION := false
const OUTER_NORMAL_CARD_RATIO_BPS := 6000
const OUTER_COMMODITY_CARD_RATIO_BPS := 4000
const NORMAL_SUBTYPE_WEIGHT_BPS := {
	"facility": 7000,
	"monster": 1500,
	"military": 1500,
}
const ACQUISITION_DOMAIN_TIE_BREAKER := {
	"facility": 30,
	"monster": 20,
	"military": 10,
}

var _enumeration_count := 0
var _rejection_count := 0
var _acquisition_enumeration_count := 0
var _acquisition_rejection_count := 0
var _natural_purchase_intent_count := 0
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
		return _result(
			[],
			_last_reason_code,
			int(privacy.get("hidden_info_violation_count", 0))
		)
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
		var result_reason := str(result.get(
			"reason_code",
			"no_legal_combat_action"
		))
		return {
			"accepted": false,
			"reason_code": result_reason,
			"hidden_info_violation_count": int(
				result.get("hidden_info_violation_count", 0)
			),
			"action": {},
		}
	return {
		"accepted": true,
		"reason_code": "none",
		"action": (candidates[0] as Dictionary).duplicate(true),
	}


func choose_private_skill(
	own_private_facts: Dictionary,
	public_facts: Dictionary
) -> Dictionary:
	var result := enumerate_candidates(own_private_facts, public_facts)
	var candidates := result.get("candidates", []) as Array
	for candidate_variant in candidates:
		if not (candidate_variant is Dictionary):
			continue
		var candidate := candidate_variant as Dictionary
		if str(candidate.get("action_kind", "")) == "monster_private_skill":
			return {
				"accepted": true,
				"reason_code": "none",
				"action": candidate.duplicate(true),
			}
	var result_reason := str(result.get(
		"reason_code",
		"no_legal_combat_action"
	))
	return {
		"accepted": false,
		"reason_code": (
			result_reason
			if result_reason not in ["none", "no_legal_combat_action"]
			else "no_ready_private_skill"
		),
		"hidden_info_violation_count": int(
			result.get("hidden_info_violation_count", 0)
		),
		"action": {},
	}


func enumerate_track_acquisition_candidates(
	own_private_facts: Dictionary,
	public_facts: Dictionary = {}
) -> Dictionary:
	_acquisition_enumeration_count += 1
	var privacy: Dictionary = privacy_report(
		own_private_facts,
		public_facts
	)
	if not bool(privacy.get("valid", false)):
		_acquisition_rejection_count += 1
		_last_reason_code = str(
			privacy.get("reason_code", "privacy_contract_invalid")
		)
		return _acquisition_result([], _last_reason_code, {
			"hidden_info_violation_count": int(
				privacy.get("hidden_info_violation_count", 0)
			),
		})
	var phase := str(public_facts.get("phase", "batch_active"))
	if phase in TERMINAL_PHASES:
		_last_reason_code = "terminal_combat_quiescent"
		return _acquisition_result([], _last_reason_code, {})
	var balance_error := _acquisition_balance_error()
	if not balance_error.is_empty():
		_acquisition_rejection_count += 1
		_last_reason_code = balance_error
		return _acquisition_result([], balance_error, {})
	var track_view: Dictionary = _track_items_view(own_private_facts)
	if not bool(track_view.get("present", false)):
		_acquisition_rejection_count += 1
		_last_reason_code = "track_projection_missing"
		return _acquisition_result([], _last_reason_code, {})
	var asset_view: Dictionary = _available_asset_view(own_private_facts)
	if not bool(asset_view.get("valid", false)):
		_acquisition_rejection_count += 1
		_last_reason_code = str(
			asset_view.get("reason_code", "asset_projection_missing")
		)
		return _acquisition_result([], _last_reason_code, {
			"track_item_count": (
				(track_view.get("items", []) as Array).size()
			),
		})
	var items: Array = track_view.get("items", []) as Array
	var available_assets: Dictionary = (
		asset_view.get("assets", {}) as Dictionary
	)
	var candidates: Array[Dictionary] = []
	var seen_instance_ids: Dictionary = {}
	var invalid_projection_row_count := 0
	for item_variant in items:
		if not (item_variant is Dictionary):
			invalid_projection_row_count += 1
			continue
		var item := item_variant as Dictionary
		var candidate: Dictionary = _track_acquisition_candidate(
			item,
			available_assets,
			own_private_facts
		)
		if candidate.is_empty():
			invalid_projection_row_count += 1
			continue
		var instance_id := str(candidate.get("source_instance_id", ""))
		if seen_instance_ids.has(instance_id):
			invalid_projection_row_count += 1
			continue
		seen_instance_ids[instance_id] = true
		candidates.append(candidate)
	candidates.sort_custom(_candidate_precedes)
	_last_reason_code = (
		"none"
		if not candidates.is_empty()
		else "no_legal_track_acquisition"
	)
	return _acquisition_result(
		candidates,
		_last_reason_code,
		{
			"track_item_count": items.size(),
			"invalid_projection_row_count": invalid_projection_row_count,
		}
	)


func enumerate_acquisition_candidates(
	own_private_facts: Dictionary,
	public_facts: Dictionary = {}
) -> Dictionary:
	return enumerate_track_acquisition_candidates(
		own_private_facts,
		public_facts
	)


func choose_track_acquisition(
	own_private_facts: Dictionary,
	public_facts: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = enumerate_track_acquisition_candidates(
		own_private_facts,
		public_facts
	)
	var candidates: Array = result.get("candidates", []) as Array
	if candidates.is_empty():
		return {
			"accepted": false,
			"reason_code": str(
				result.get(
					"reason_code",
					"no_legal_track_acquisition"
				)
			),
			"action": {},
			"acquisition_audit": (
				result.get("acquisition_audit", {}) as Dictionary
			).duplicate(true),
		}
	_natural_purchase_intent_count += 1
	var action := (candidates[0] as Dictionary).duplicate(true)
	return {
		"accepted": true,
		"reason_code": "natural_track_acquisition_intent_ready",
		"action": action,
		"acquisition_intent": action.duplicate(true),
		"acquisition_audit": (
			result.get("acquisition_audit", {}) as Dictionary
		).duplicate(true),
	}


func choose_acquisition(
	own_private_facts: Dictionary,
	public_facts: Dictionary = {}
) -> Dictionary:
	return choose_track_acquisition(
		own_private_facts,
		public_facts
	)


func audit_natural_acquisition(
	own_private_facts: Dictionary,
	public_facts: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = enumerate_track_acquisition_candidates(
		own_private_facts,
		public_facts
	)
	result["audit_only"] = true
	return result


func privacy_report(
	own_private_facts: Dictionary,
	public_facts: Dictionary
) -> Dictionary:
	var public_identity_violation := _first_exact_key(
		public_facts,
		FORBIDDEN_PUBLIC_EXACT_KEYS
	)
	if not public_identity_violation.is_empty():
		return {
			"valid": false,
			"reason_code": (
				"public_facts_contains_private_card_identity:%s"
				% public_identity_violation
			),
			"hidden_info_violation_count": 1,
		}
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
		"acquisition_enumeration_count": _acquisition_enumeration_count,
		"acquisition_rejection_count": _acquisition_rejection_count,
		"natural_purchase_intent_count": _natural_purchase_intent_count,
		"track_local_visible_capacity": TRACK_LOCAL_VISIBLE_CAPACITY,
		"track_refill_mode": TRACK_REFILL_MODE,
		"track_slow_sushi_motion": TRACK_SLOW_SUSHI_MOTION,
		"track_immediate_refill_on_acquisition": (
			TRACK_IMMEDIATE_REFILL_ON_ACQUISITION
		),
		"outer_normal_card_ratio_basis_points": (
			OUTER_NORMAL_CARD_RATIO_BPS
		),
		"outer_commodity_card_ratio_basis_points": (
			OUTER_COMMODITY_CARD_RATIO_BPS
		),
		"normal_subtype_weights_basis_points": (
			NORMAL_SUBTYPE_WEIGHT_BPS.duplicate()
		),
		"track_mutation_count": 0,
		"supply_cursor_delta_on_acquisition": 0,
		"supply_rng_draw_delta_on_acquisition": 0,
		"last_reason_code": _last_reason_code,
	}


func _acquisition_balance_error() -> String:
	var contract: Dictionary = CardDefinitionsV075.registry_contract()
	var weights: Dictionary = (
		contract.get("normal_subtype_weights_basis_points", {})
		as Dictionary
	)
	if weights != NORMAL_SUBTYPE_WEIGHT_BPS:
		return "normal_subtype_balance_contract_changed"
	if int(contract.get("outer_normal_card_ratio_basis_points", -1)) != (
		OUTER_NORMAL_CARD_RATIO_BPS
	):
		return "outer_normal_ratio_contract_changed"
	if int(contract.get("outer_commodity_card_ratio_basis_points", -1)) != (
		OUTER_COMMODITY_CARD_RATIO_BPS
	):
		return "outer_commodity_ratio_contract_changed"
	return ""


func _track_items_view(facts: Dictionary) -> Dictionary:
	var direct: Variant = facts.get("own_segment_items", null)
	if direct is Array:
		return {
			"present": true,
			"items": (direct as Array).duplicate(true),
		}
	for container_key in ["track_projection", "unified_track", "track"]:
		var container_variant: Variant = facts.get(container_key, null)
		if not (container_variant is Dictionary):
			continue
		var container := container_variant as Dictionary
		var nested_direct: Variant = container.get(
			"own_segment_items",
			null
		)
		if nested_direct is Array:
			return {
				"present": true,
				"items": (nested_direct as Array).duplicate(true),
			}
		var private_variant: Variant = container.get(
			"viewer_private_facts",
			container.get("private_facts", {})
		)
		if not (private_variant is Dictionary):
			continue
		var private_facts := private_variant as Dictionary
		var nested_items: Variant = private_facts.get(
			"own_segment_items",
			null
		)
		if nested_items is Array:
			return {
				"present": true,
				"items": (nested_items as Array).duplicate(true),
			}
	return {
		"present": false,
		"items": [],
	}


func _available_asset_view(facts: Dictionary) -> Dictionary:
	var raw: Variant = facts.get("available_unreserved_assets", null)
	if not (raw is Dictionary):
		var projection_variant: Variant = facts.get(
			"six_color_assets",
			null
		)
		if projection_variant is Dictionary:
			raw = (projection_variant as Dictionary).get(
				"own_available_assets",
				null
			)
	if not (raw is Dictionary):
		return {
			"valid": false,
			"reason_code": "asset_projection_missing",
		}
	var source := raw as Dictionary
	var assets: Dictionary = {}
	for color_id in COLORS:
		if not source.has(color_id):
			return {
				"valid": false,
				"reason_code": "asset_projection_incomplete",
			}
		var value: Variant = source.get(color_id)
		if typeof(value) != TYPE_INT or int(value) < 0:
			return {
				"valid": false,
				"reason_code": "asset_projection_invalid",
			}
		assets[color_id] = int(value)
	return {
		"valid": true,
		"reason_code": "asset_projection_valid",
		"assets": assets,
	}


func _track_acquisition_candidate(
	item: Dictionary,
	_available_assets: Dictionary,
	own_private_facts: Dictionary
) -> Dictionary:
	if str(item.get("card_kind", "")) != "normal_card":
		return {}
	if not bool(item.get("claimable", false)):
		return {}
	if item.has("claimability_state") and str(
		item.get("claimability_state", "")
	) != "claimable":
		return {}
	var instance_id := str(item.get("instance_id", ""))
	var definition_id := str(item.get("card_definition_id", ""))
	if instance_id.is_empty() or definition_id.is_empty():
		return {}
	var definition: Dictionary = CardDefinitionsV075.definition(
		definition_id
	)
	if definition.is_empty() or not bool(
		definition.get("purchase_allowed", false)
	) or not bool(definition.get("track_spawn_allowed", false)):
		return {}
	if str(definition.get("origin_class", "")) != "standard":
		return {}
	if bool(item.get("starter_badge", false)):
		return {}
	if item.has("segment_owner_id") and str(
		item.get("segment_owner_id", "")
	) != str(own_private_facts.get("viewer_player_id", "")):
		return {}
	var domain := CardDefinitionsV075.card_domain(
		str(definition.get("card_type", ""))
	)
	if not NORMAL_SUBTYPE_WEIGHT_BPS.has(domain):
		return {}
	var primary_color := str(item.get("primary_color", ""))
	if primary_color not in COLORS or primary_color != str(
		definition.get("primary_color", "")
	):
		return {}
	if not item.has("primary_asset_cost"):
		return {}
	var cost_variant: Variant = item.get("primary_asset_cost")
	if typeof(cost_variant) != TYPE_INT:
		return {}
	var cost := int(cost_variant)
	if cost < 0 or cost != int(definition.get("primary_asset_cost", -1)):
		return {}
	if item.has("level") and int(item.get("level", 0)) != int(
		definition.get("level", 0)
	):
		return {}
	var local_slot_index := maxi(0, int(item.get("local_slot_index", 0)))
	var domain_weight := int(NORMAL_SUBTYPE_WEIGHT_BPS.get(domain, 0))
	var tie_breaker := int(
		ACQUISITION_DOMAIN_TIE_BREAKER.get(domain, 0)
	)
	var score := domain_weight * 1000
	score += maxi(0, 100 - cost)
	score += maxi(0, TRACK_LOCAL_VISIBLE_CAPACITY - local_slot_index)
	score += tie_breaker
	var follow_up_contract: Dictionary = {}
	if domain == "monster":
		follow_up_contract = {
			"requires_prebound_mode": true,
			"allowed_modes": MONSTER_CARD_MODES.duplicate(),
		}
	elif domain == "military":
		follow_up_contract = {
			"requires_prebound_task": true,
			"allowed_task_kinds": MILITARY_TASK_KINDS.duplicate(),
		}
	else:
		follow_up_contract = {
			"requires_facility_target_prebind": true,
		}
	var candidate := {
		"action_kind": "track_acquisition",
		"acquisition_kind": "normal_card",
		"card_kind": "normal_card",
		"card_instance_id": instance_id,
		"source_instance_id": instance_id,
		"card_definition_id": definition_id,
		"card_domain": domain,
		"card_type": str(definition.get("card_type", "")),
		"card_rank": int(definition.get("level", 0)),
		"primary_color": primary_color,
		"primary_asset_cost": cost,
		"play_asset_cost": cost,
		"purchase_cost_source": "cash_authority",
		"track_revision": int(item.get("track_revision", 0)),
		"local_slot_index": local_slot_index,
		"claimable": true,
		"target_bound": false,
		"target_id": "",
		"mode_prebound": false,
		"follow_up_contract": follow_up_contract,
		"domain_weight_basis_points": domain_weight,
		"priority_reason": (
			"facility_economy_dominant"
			if domain == "facility"
			else "combat_card_opportunity_when_facility_unavailable"
		),
		"track_refill_mode": TRACK_REFILL_MODE,
		"slow_sushi_motion": TRACK_SLOW_SUSHI_MOTION,
		"immediate_refill_on_acquisition": (
			TRACK_IMMEDIATE_REFILL_ON_ACQUISITION
		),
		"supply_cursor_delta_on_acquisition": 0,
		"supply_rng_draw_delta_on_acquisition": 0,
		"score": score,
	}
	candidate["stable_action_key"] = _stable_action_key(candidate)
	return candidate


func _acquisition_result(
	candidates: Array[Dictionary],
	reason_code: String,
	metadata: Dictionary
) -> Dictionary:
	var domain_counts := {
		"facility": 0,
		"monster": 0,
		"military": 0,
	}
	for candidate_variant in candidates:
		var candidate := candidate_variant as Dictionary
		var domain := str(candidate.get("card_domain", ""))
		if domain_counts.has(domain):
			domain_counts[domain] = int(domain_counts.get(domain, 0)) + 1
	var top_domain := ""
	if not candidates.is_empty():
		top_domain = str((candidates[0] as Dictionary).get(
			"card_domain",
			""
		))
	var audit := {
		"baseline_root_cause_code": (
			"v074_facility_only_auto_acquisition_bypassed_combat_adapter"
		),
		"adapter_acquisition_hook": (
			"V075CombatAIAdapter.choose_track_acquisition"
		),
		"track_visible_capacity": TRACK_LOCAL_VISIBLE_CAPACITY,
		"track_item_count": int(metadata.get("track_item_count", 0)),
		"invalid_projection_row_count": int(
			metadata.get("invalid_projection_row_count", 0)
		),
		"facility_candidate_count": int(domain_counts.get("facility", 0)),
		"monster_candidate_count": int(domain_counts.get("monster", 0)),
		"military_candidate_count": int(domain_counts.get("military", 0)),
		"top_domain": top_domain,
		"facility_economy_dominant": (
			top_domain.is_empty() or top_domain == "facility"
		),
		"outer_normal_card_ratio_basis_points": (
			OUTER_NORMAL_CARD_RATIO_BPS
		),
		"outer_commodity_card_ratio_basis_points": (
			OUTER_COMMODITY_CARD_RATIO_BPS
		),
		"normal_subtype_weights_basis_points": (
			NORMAL_SUBTYPE_WEIGHT_BPS.duplicate()
		),
		"track_refill_mode": TRACK_REFILL_MODE,
		"slow_sushi_motion": TRACK_SLOW_SUSHI_MOTION,
		"immediate_refill_on_acquisition": (
			TRACK_IMMEDIATE_REFILL_ON_ACQUISITION
		),
		"supply_cursor_delta_on_acquisition": 0,
		"supply_rng_draw_delta_on_acquisition": 0,
		"track_mutation_count": 0,
		"card_injection_count": 0,
		"asset_injection_count": 0,
		"target_injection_count": 0,
		"rng_draw_count": 0,
	}
	return {
		"schema": "V075CombatAINaturalAcquisitionV1",
		"ruleset_id": RULESET_ID,
		"accepted": reason_code in [
			"none",
			"no_legal_track_acquisition",
		],
		"reason_code": reason_code,
		"candidate_count": candidates.size(),
		"candidates": candidates.duplicate(true),
		"hidden_info_violation_count": int(
			metadata.get("hidden_info_violation_count", 0)
		),
		"acquisition_audit": audit,
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
		for option_variant in card.get("options", []) as Array:
			if not (option_variant is Dictionary):
				continue
			var option := option_variant as Dictionary
			var card_instance_id := str(option.get("card_instance_id", ""))
			var definition_id := str(option.get("card_definition_id", ""))
			var mode := str(option.get("monster_card_mode", ""))
			if mode not in MONSTER_CARD_MODES:
				continue
			var card_action_binding := option.get(
				"card_action_binding",
				{}
			) as Dictionary
			if (
				card_instance_id.is_empty()
				or definition_id.is_empty()
				or str(option.get("option_id", "")).is_empty()
				or str(option.get("target_slot_id", "")).is_empty()
				or card_action_binding.is_empty()
			):
				continue
			var target_id := str(option.get(
				"target_region_id" if mode == "DEPLOY_NEW" else (
					"target_source_instance_id"
				),
				""
			))
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
				"option_id": str(option.get("option_id", "")),
				"card_instance_id": card_instance_id,
				"card_definition_id": definition_id,
				"target_slot_id": str(option.get("target_slot_id", "")),
				"card_action_binding": card_action_binding.duplicate(true),
				target_field: target_id,
				"score": int(MODE_SCORE.get(mode, 0))
					+ clampi(int(option.get("card_rank", 1)), 1, 4) * 5,
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
			if (
				str(skill.get("effect_kind", "")) == "self_heal"
				and int(source.get("hp", 0)) >= int(source.get("max_hp", 0))
			):
				continue
			var cost := (
				skill.get("asset_cost_by_color", {}) as Dictionary
			)
			if not _can_pay(cost, available_assets):
				continue
			var target_binding := skill.get("target_binding", {}) as Dictionary
			var target: Dictionary = {}
			if not target_binding.is_empty():
				target = {
					"valid": true,
					"target_kind": str(target_binding.get(
						"target_kind",
						""
					)),
					"target_id": str(target_binding.get(
						"target_id",
						""
					)),
				}
			else:
				var contract := str(skill.get("target_contract", "none"))
				target = _stable_skill_target(
					contract,
					str(own_private_facts.get("viewer_player_id", "")),
					source_id,
					public_facts
				)
			if not bool(target.get("valid", false)):
				continue
			if target_binding.is_empty():
				target_binding = _ai_target_binding(target)
			if target_binding.is_empty():
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
				"target_binding": target_binding.duplicate(true),
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
	_public_facts: Dictionary
) -> void:
	var detailed_options: Array = []
	var detailed_value: Variant = own_private_facts.get(
		"military_options",
		[]
	)
	if detailed_value is Array:
		detailed_options = (detailed_value as Array).duplicate(true)
	if detailed_options.is_empty():
		for card_variant in own_private_facts.get(
			"military_card_options",
			[]
		) as Array:
			if not (card_variant is Dictionary):
				continue
			for option_variant in (card_variant as Dictionary).get(
				"options",
				[]
			) as Array:
				if option_variant is Dictionary:
					detailed_options.append(
						(option_variant as Dictionary).duplicate(true)
					)
	for option_variant in detailed_options:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		if not bool(option.get("enabled", false)):
			continue
		var task_kind := str(option.get("task_kind", ""))
		if task_kind not in MILITARY_TASK_KINDS:
			continue
		if (
			str(option.get("option_id", "")).is_empty()
			or str(option.get("card_instance_id", "")).is_empty()
			or str(option.get("target_slot_id", "")).is_empty()
			or not (option.get("card_action_binding") is Dictionary)
			or (option.get("card_action_binding", {}) as Dictionary).is_empty()
		):
			continue
		var target_id := (
			str(option.get("target_region_id", ""))
			if task_kind == "assault_region"
			else str(option.get("target_monster_source_instance_id", ""))
		)
		if target_id.is_empty():
			continue
		var candidate := {
			"action_kind": "military_mission",
			"task_kind": task_kind,
			"option_id": str(option.get("option_id", "")),
			"card_instance_id": str(option.get("card_instance_id", "")),
			"card_definition_id": str(option.get("card_definition_id", "")),
			"card_action_binding": (
				option.get("card_action_binding", {}) as Dictionary
			).duplicate(true),
			"target_slot_id": str(option.get("target_slot_id", "")),
			"target_region_id": (
				target_id if task_kind == "assault_region" else ""
			),
			"target_monster_source_instance_id": (
				target_id if task_kind == "assault_monster" else ""
			),
			"launch_region_id": str(option.get("launch_region_id", "")),
			"asset_cost_by_color": (
				option.get("asset_cost_by_color", {}) as Dictionary
			).duplicate(true),
			"one_shot_withdrawal": true,
			"score": 640 if task_kind == "assault_monster" else 610,
		}
		if task_kind == "assault_monster":
			if not _positive_int_field(option, "target_source_generation"):
				continue
			candidate["target_source_generation"] = int(option.get(
				"target_source_generation",
				0
			))
		candidate["stable_action_key"] = _stable_action_key(candidate)
		candidates.append(candidate)


func _ai_target_binding(target: Dictionary) -> Dictionary:
	var target_kind := str(target.get("target_kind", ""))
	var target_id := str(target.get("target_id", ""))
	if target_id.is_empty():
		return {}
	var result := {
		"target_kind": target_kind,
		"target_id": target_id,
	}
	match target_kind:
		"facility":
			result["target_facility_id"] = target_id
			if target.has("target_facility_generation"):
				result["target_facility_generation"] = int(
					target.get("target_facility_generation", 0)
				)
		"region":
			result["target_region_id"] = target_id
		"monster":
			result["target_monster_source_instance_id"] = target_id
			if target.has("target_source_generation"):
				result["target_source_generation"] = int(
					target.get("target_source_generation", 0)
				)
		_:
			return {}
	return result


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
				"valid": (
					not source_id.is_empty()
					and _source_generation(source_id, public_facts) > 0
				),
				"target_kind": "monster",
				"target_id": source_id,
				"target_source_generation": _source_generation(
					source_id,
					public_facts
				),
			}
		"enemy_facility":
			var facility_id := _first_enemy_facility_id(
				viewer_id,
				public_facts
			)
			return {
				"valid": (
					not facility_id.is_empty()
					and _facility_generation(facility_id, public_facts) > 0
				),
				"target_kind": "facility",
				"target_id": facility_id,
				"target_facility_generation": _facility_generation(
					facility_id,
					public_facts
				),
			}
		"enemy_monster":
			var monster_id := _first_enemy_monster_id(
				viewer_id,
				public_facts
			)
			return {
				"valid": (
					not monster_id.is_empty()
					and _source_generation(monster_id, public_facts) > 0
				),
				"target_kind": "monster",
				"target_id": monster_id,
				"target_source_generation": _source_generation(
					monster_id,
					public_facts
				),
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


func _facility_generation(
	facility_id: String,
	public_facts: Dictionary
) -> int:
	for facility_variant in public_facts.get("facilities", []) as Array:
		var facility := facility_variant as Dictionary
		if str(facility.get("facility_id", "")) == facility_id:
			return int(facility.get("facility_generation", 0))
	return 0


func _source_generation(
	source_id: String,
	public_facts: Dictionary
) -> int:
	for source_variant in public_facts.get("monsters", []) as Array:
		var source := source_variant as Dictionary
		if str(source.get("source_instance_id", "")) == source_id:
			return int(source.get("source_generation", 0))
	return 0


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


func _positive_int_field(source: Dictionary, field_name: String) -> bool:
	return (
		source.has(field_name)
		and typeof(source.get(field_name)) == TYPE_INT
		and int(source.get(field_name)) > 0
	)


func _stable_action_key(candidate: Dictionary) -> String:
	return "|".join([
		str(candidate.get("action_kind", "")),
		str(candidate.get("monster_card_mode", "")),
		str(candidate.get("task_kind", "")),
		str(candidate.get("card_instance_id", "")),
		str(candidate.get("option_id", "")),
		str((candidate.get("card_action_binding", {}) as Dictionary).get(
			"binding_fingerprint",
			""
		)),
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
	reason_code: String,
	hidden_info_violation_count: int = 0
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
		"hidden_info_violation_count": hidden_info_violation_count,
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


func _first_exact_key(value: Variant, forbidden_keys: Array) -> String:
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			var key := str(key_variant)
			if key in forbidden_keys:
				return key
			var nested := _first_exact_key(
				dictionary.get(key_variant),
				forbidden_keys
			)
			if not nested.is_empty():
				return nested
	elif value is Array:
		for child_variant in value as Array:
			var nested := _first_exact_key(child_variant, forbidden_keys)
			if not nested.is_empty():
				return nested
	return ""
