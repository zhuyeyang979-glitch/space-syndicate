extends RefCounted
class_name CardSemanticCompilerV1

const SCHEMA := preload("res://scripts/cards/semantic/card_semantic_schema_v1.gd")
const SOURCE_SCHEMA_VERSION := "v0.6"
const SOURCE_RECORD_KEYS := ["machine", "player", "developer"]
const SOURCE_MACHINE_KEYS := [
	"card_id", "family_id", "rank", "category_id", "industry_id", "acquisition_kind",
	"purchase_cash", "asset_cost", "counts_toward_hand_limit", "merge_policy", "maximum_rank",
	"effect_kind", "target_kind", "effect_payload", "available_for_acquisition", "resolution_policy",
]
const EFFECT_CONTRACTS := {
	"install_commodity_rate": {"category_id": "commodity", "target_kind": "same_industry_factory_or_market"},
	"build_upgrade_or_repair_facility": {"category_id": "facility", "target_kind": "region_unique_facility_slot"},
	"global_order_budget": {"category_id": "supply_demand", "target_kind": "global_matching_goods"},
	"global_supply_spawn": {"category_id": "supply_demand", "target_kind": "global_matching_factories"},
	"deploy_or_upgrade_monster": {"category_id": "monster", "target_kind": "region_or_existing_same_family_monster"},
	"deploy_or_upgrade_military": {"category_id": "military", "target_kind": "region_or_owned_same_family_military"},
	"player_hand_disrupt": {"category_id": "interaction", "target_kind": "opponent_discardable_hand"},
	"player_hand_steal": {"category_id": "interaction", "target_kind": "opponent_discardable_hand"},
	"card_counter": {"category_id": "interaction", "target_kind": "incoming_direct_player_interaction"},
	"install_organization_upgrade": {"category_id": "organization", "target_kind": "self_organization_slot"},
}
const FACILITY_COMMON_PAYLOAD_KEYS := [
	"allowed_region_states", "card_rank", "facility_kind", "industry_id", "operation_policy",
	"rent_enabled", "rent_rate_profile", "shared_hp_contribution", "shared_hp_profile",
]
const FACILITY_CAPACITY_KEYS := {
	"factory": ["production_capacity_units_per_minute"],
	"market": ["demand_capacity_units_per_minute"],
	"road": ["throughput_units_per_minute", "speed_multiplier"],
	"port": ["throughput_units_per_minute", "speed_multiplier"],
	"spaceport": ["throughput_units_per_minute", "speed_multiplier"],
	"warehouse": ["storage_capacity_units", "inbound_throughput_units_per_minute", "outbound_throughput_units_per_minute"],
}
const ORGANIZATION_COMMON_PAYLOAD_KEYS := [
	"organization_axis", "organization_family_id", "organization_rank", "organization_slot_cost",
	"organization_slot_limit", "install_policy", "stack_policy", "replacement_requires_higher_rank",
	"equal_or_lower_rank_resolution", "activation_window_offset", "activation_snapshot_timing",
	"persistence", "required_own_gdp_min", "required_positive_gdp_color_count", "public_clue_kind",
	"counterplay_tags", "direct_player_interaction", "counterable", "phase_veto_eligible",
	"ordinary_submission_cost", "counts_as_normal_card_submission", "ai_effect_tags", "anti_snowball_cap",
]
const ORGANIZATION_AXIS_PAYLOAD_KEYS := {
	"asset_conversion": ["asset_conversion_bonus_bp", "asset_conversion_bonus_cap_milli_per_second", "scope"],
	"hand_capacity": ["base_ordinary_hand_limit", "ordinary_hand_limit", "ordinary_hand_limit_bonus", "absolute_hand_limit_cap", "scope"],
	"military_command": ["base_controlled_military_count_limit", "base_primary_military_rank_limit", "controlled_military_count_limit", "primary_military_rank_limit", "secondary_military_rank_limit"],
	"monster_binding": ["base_controlled_monster_count_limit", "base_primary_monster_rank_limit", "controlled_monster_count_limit", "primary_monster_rank_limit", "secondary_monster_rank_limit", "foreign_same_name_upgrade_must_respect_target_owner_limits", "foreign_upgrade_rank_limit_source", "foreign_upgrade_does_not_transfer_control"],
	"action_bandwidth": ["ordinary_submission_bonus", "extra_submission_asset_surcharge", "ordinary_submission_hard_cap", "burst_window_period", "burst_submission_bonus", "burst_submission_surcharge", "window_start_snapshot_required", "response_cards_ignore_ordinary_submission_limit", "public_same_source_aura"],
}

var _cache: Dictionary = {}
var _compile_count := 0
var _cache_hit_count := 0
var _failure_count := 0


func compile_authorized(envelope: Dictionary, source_catalog_id: String) -> Dictionary:
	var envelope_report: Dictionary = SCHEMA.validate_authorized_envelope(envelope)
	if not bool(envelope_report.get("valid", false)):
		return _failure(_prefixed_errors("authorized_envelope", envelope_report.get("errors", [])))
	return compile_card_record(envelope["card_record"], source_catalog_id)


func compile_card_record(card_record: Dictionary, source_catalog_id: String) -> Dictionary:
	var errors := _validate_card_record(card_record, source_catalog_id)
	if not errors.is_empty():
		_failure_count += 1
		return _failure(errors)
	var machine: Dictionary = (card_record["machine"] as Dictionary).duplicate(true)
	var source_definition_fingerprint: String = SCHEMA.fingerprint({
		"source_catalog_id": source_catalog_id,
		"machine": machine,
	})
	if source_definition_fingerprint.is_empty():
		_failure_count += 1
		return _failure(["source_definition_fingerprint_failed"])
	var cache_key := "%d:%s" % [SCHEMA.SCHEMA_VERSION, source_definition_fingerprint]
	if _cache.has(cache_key):
		_cache_hit_count += 1
		return _success(SCHEMA.detached_copy(_cache[cache_key]), source_definition_fingerprint, true)
	var compiled := _compile_uncached(machine, source_catalog_id, source_definition_fingerprint)
	if not bool(compiled.get("ok", false)):
		_failure_count += 1
		return compiled
	var spec: Dictionary = compiled.get("spec", {})
	_cache[cache_key] = spec.duplicate(true)
	_compile_count += 1
	return _success(spec.duplicate(true), source_definition_fingerprint, false)


func compile_catalog_snapshot(catalog_snapshot: Dictionary) -> Dictionary:
	var catalog_id := str(catalog_snapshot.get("catalog_id", ""))
	var cards_value: Variant = catalog_snapshot.get("cards")
	if not SCHEMA.is_stable_id(catalog_id) or not (cards_value is Array):
		return {
			"ok": false, "source_catalog_id": catalog_id, "source_record_count": 0,
			"compiled_count": 0, "active_count": 0, "projection_only_count": 0,
			"not_acquirable_count": 0, "op_counts": {}, "errors": ["catalog_snapshot_invalid"],
			"source_catalog_fingerprint": "", "semantic_catalog_fingerprint": "",
		}
	var cards: Array = cards_value
	var machines: Array = []
	var semantic_fingerprints: Array = []
	var errors: Array = []
	var op_counts: Dictionary = {}
	var readiness_counts := {"active": 0, "projection_only": 0, "not_acquirable": 0}
	var compiled_count := 0
	for index in range(cards.size()):
		var record_value: Variant = cards[index]
		if record_value is Dictionary and (record_value as Dictionary).get("machine") is Dictionary:
			machines.append(((record_value as Dictionary)["machine"] as Dictionary).duplicate(true))
		else:
			machines.append({})
		var result := compile_card_record(record_value if record_value is Dictionary else {}, catalog_id)
		if not bool(result.get("ok", false)):
			var card_id := ""
			if record_value is Dictionary and (record_value as Dictionary).get("machine") is Dictionary:
				card_id = str(((record_value as Dictionary)["machine"] as Dictionary).get("card_id", ""))
			errors.append({"record_index": index, "card_id": card_id, "error_ids": result.get("errors", []).duplicate()})
			continue
		var spec: Dictionary = result.get("spec", {})
		compiled_count += 1
		semantic_fingerprints.append(str(spec.get("semantic_fingerprint", "")))
		var readiness_id := str(spec.get("runtime_readiness_id", ""))
		readiness_counts[readiness_id] = int(readiness_counts.get(readiness_id, 0)) + 1
		for op_value in (spec.get("effect_ops", []) as Array):
			var op_id := str((op_value as Dictionary).get("op_id", "")) if op_value is Dictionary else ""
			op_counts[op_id] = int(op_counts.get(op_id, 0)) + 1
	return {
		"ok": errors.is_empty(),
		"source_catalog_id": catalog_id,
		"source_record_count": cards.size(),
		"compiled_count": compiled_count,
		"active_count": int(readiness_counts["active"]),
		"projection_only_count": int(readiness_counts["projection_only"]),
		"not_acquirable_count": int(readiness_counts["not_acquirable"]),
		"op_counts": op_counts.duplicate(true),
		"errors": errors.duplicate(true),
		"source_catalog_fingerprint": SCHEMA.fingerprint({"source_catalog_id": catalog_id, "machines": machines}),
		"semantic_catalog_fingerprint": SCHEMA.fingerprint({"schema_version": SCHEMA.SCHEMA_VERSION, "semantic_fingerprints": semantic_fingerprints}),
	}


func cache_metrics() -> Dictionary:
	return {
		"cache_entry_count": _cache.size(),
		"compile_count": _compile_count,
		"cache_hit_count": _cache_hit_count,
		"failure_count": _failure_count,
	}


func _compile_uncached(machine: Dictionary, source_catalog_id: String, source_definition_fingerprint: String) -> Dictionary:
	var effect_kind := str(machine.get("effect_kind", ""))
	var effect_ops := _effect_ops(machine)
	if effect_ops.is_empty():
		return _failure(["effect_mapping_unsupported:%s" % effect_kind], source_definition_fingerprint)
	var available := bool(machine.get("available_for_acquisition", false))
	var readiness_id := "projection_only" if effect_kind == "install_organization_upgrade" else ("active" if available else "not_acquirable")
	var identity := {
		"card_id": str(machine.get("card_id", "")),
		"family_id": str(machine.get("family_id", "")),
		"rank": int(machine.get("rank", 0)),
		"category_id": str(machine.get("category_id", "")),
		"industry_id": str(machine.get("industry_id", "")),
		"available_for_acquisition": available,
	}
	var spec := {
		"schema_version": SCHEMA.SCHEMA_VERSION,
		"source_catalog_id": source_catalog_id,
		"source_definition_fingerprint": source_definition_fingerprint,
		"semantic_fingerprint": "",
		"identity": identity,
		"cost": {
			"acquisition": {
				"acquisition_kind": str(machine.get("acquisition_kind", "")),
				"purchase_cash": int(machine.get("purchase_cash", 0)),
			},
			"activation": _normalized_asset_cost(machine.get("asset_cost", {})),
		},
		"timing": {"timing_id": "response_window" if effect_kind == "card_counter" else "main_action"},
		"target": _target_spec(machine),
		"effect_ops": effect_ops,
		"response": {"response_id": _response_id(effect_kind)},
		"information_policy": {"visibility_policy_id": "authorized_source_only"},
		"runtime_readiness_id": readiness_id,
	}
	spec["semantic_fingerprint"] = SCHEMA.fingerprint(spec, "semantic_fingerprint")
	var report: Dictionary = SCHEMA.validate_semantic_spec(spec)
	if not bool(report.get("valid", false)):
		return _failure(_prefixed_errors("semantic_schema", report.get("errors", [])), source_definition_fingerprint)
	return _success(spec, source_definition_fingerprint, false)


func _validate_card_record(card_record: Dictionary, source_catalog_id: String) -> Array[String]:
	var errors: Array[String] = []
	if not SCHEMA.is_stable_id(source_catalog_id):
		errors.append("source_catalog_id_invalid")
	_check_source_keys(card_record, SOURCE_RECORD_KEYS, "card_record", errors)
	for block_id in SOURCE_RECORD_KEYS:
		if not (card_record.get(block_id) is Dictionary):
			errors.append("card_record_%s_invalid" % block_id)
	if not (card_record.get("machine") is Dictionary):
		return errors
	_validate_machine(card_record["machine"], errors)
	return errors


func _validate_machine(machine: Dictionary, errors: Array[String]) -> void:
	_check_source_keys(machine, SOURCE_MACHINE_KEYS, "machine", errors)
	var card_id := str(machine.get("card_id", ""))
	var family_id := str(machine.get("family_id", ""))
	var rank := int(machine.get("rank", 0)) if _is_integral_source_number(machine.get("rank")) else 0
	if not SCHEMA.is_stable_id(card_id) or not SCHEMA.is_stable_id(family_id) or card_id != "%s.rank_%d" % [family_id, rank]:
		errors.append("machine_ranked_identity_invalid")
	if rank < 1 or rank > 4:
		errors.append("machine_rank_invalid")
	if not SCHEMA.CATEGORY_IDS.has(str(machine.get("category_id", ""))):
		errors.append("machine_category_invalid")
	if not SCHEMA.INDUSTRY_IDS.has(str(machine.get("industry_id", ""))):
		errors.append("machine_industry_invalid")
	if not ["commodity_belt_free", "dynamic_market_cash", "starter_or_dynamic_market_cash"].has(str(machine.get("acquisition_kind", ""))):
		errors.append("machine_acquisition_kind_invalid")
	_validate_nonnegative_source_int(machine.get("purchase_cash"), "machine_purchase_cash_invalid", errors)
	_validate_asset_cost(machine.get("asset_cost"), errors)
	if machine.get("counts_toward_hand_limit") != true or str(machine.get("merge_policy", "")) != "manual_same_family_same_rank_or_auto_once_when_full" or machine.get("maximum_rank") != 4:
		errors.append("machine_inventory_policy_invalid")
	if not (machine.get("available_for_acquisition") is bool) or str(machine.get("resolution_policy", "")) != "reject_before_consume_if_unowned":
		errors.append("machine_resolution_policy_invalid")
	var effect_kind := str(machine.get("effect_kind", ""))
	if not EFFECT_CONTRACTS.has(effect_kind):
		errors.append("machine_effect_kind_unknown")
		return
	var contract: Dictionary = EFFECT_CONTRACTS[effect_kind]
	if str(machine.get("category_id", "")) != str(contract["category_id"]) or str(machine.get("target_kind", "")) != str(contract["target_kind"]):
		errors.append("machine_effect_target_contract_invalid")
	if not (machine.get("effect_payload") is Dictionary):
		errors.append("machine_effect_payload_invalid")
		return
	_validate_effect_payload(effect_kind, machine["effect_payload"], machine, errors)


func _validate_effect_payload(effect_kind: String, payload: Dictionary, machine: Dictionary, errors: Array[String]) -> void:
	match effect_kind:
		"install_commodity_rate": _validate_commodity_payload(payload, machine, errors)
		"build_upgrade_or_repair_facility": _validate_facility_payload(payload, machine, errors)
		"global_order_budget": _validate_order_payload(payload, errors)
		"global_supply_spawn": _validate_supply_payload(payload, errors)
		"deploy_or_upgrade_monster": _validate_monster_payload(payload, machine, errors)
		"deploy_or_upgrade_military": _validate_military_payload(payload, machine, errors)
		"player_hand_disrupt": _validate_disrupt_payload(payload, errors)
		"player_hand_steal": _validate_steal_payload(payload, errors)
		"card_counter": _validate_counter_payload(payload, errors)
		"install_organization_upgrade": _validate_organization_payload(payload, machine, errors)

func _validate_commodity_payload(payload: Dictionary, machine: Dictionary, errors: Array[String]) -> void:
	_check_source_keys(payload, ["product_id", "industry_id", "rate_per_minute", "valid_facility_kinds", "persistence"], "commodity_payload", errors)
	if not (payload.get("product_id") is String) or str(payload.get("product_id", "")).strip_edges().is_empty():
		errors.append("commodity_product_id_missing")
	if str(payload.get("industry_id", "")) != str(machine.get("industry_id", "")):
		errors.append("commodity_industry_mismatch")
	_validate_positive_source_int(payload.get("rate_per_minute"), "commodity_rate_invalid", errors)
	if not _array_equals(payload.get("valid_facility_kinds"), ["factory", "market"]):
		errors.append("commodity_facility_kinds_invalid")
	if str(payload.get("persistence", "")) != "until_facility_destroyed":
		errors.append("commodity_persistence_invalid")


func _validate_facility_payload(payload: Dictionary, machine: Dictionary, errors: Array[String]) -> void:
	var facility_kind := str(payload.get("facility_kind", ""))
	if not FACILITY_CAPACITY_KEYS.has(facility_kind):
		errors.append("facility_kind_unknown")
		return
	_check_source_keys(payload, FACILITY_COMMON_PAYLOAD_KEYS + FACILITY_CAPACITY_KEYS[facility_kind], "facility_payload", errors)
	if not _array_equals(payload.get("allowed_region_states"), ["active", "undeveloped", "ruined"]):
		errors.append("facility_region_states_invalid")
	if payload.get("card_rank") != machine.get("rank"):
		errors.append("facility_rank_mismatch")
	var machine_industry := str(machine.get("industry_id", ""))
	var payload_industry := str(payload.get("industry_id", ""))
	if ["factory", "market"].has(facility_kind):
		if payload_industry != machine_industry or machine_industry == "generic":
			errors.append("facility_industry_invalid")
	elif payload_industry != "" or machine_industry != "generic":
		errors.append("facility_neutral_industry_invalid")
	if str(payload.get("operation_policy", "")) != "empty_build_higher_rank_upgrade_same_or_lower_repair" or payload.get("rent_enabled") != true or str(payload.get("rent_rate_profile", "")) != "pending_first_playtest_table" or str(payload.get("shared_hp_profile", "")) != "equal_contribution_by_rank":
		errors.append("facility_policy_invalid")
	_validate_positive_source_int(payload.get("shared_hp_contribution"), "facility_shared_hp_invalid", errors)
	for key in FACILITY_CAPACITY_KEYS[facility_kind]:
		if str(key) == "speed_multiplier":
			if not (payload.get(key) is float or payload.get(key) is int) or not is_finite(float(payload.get(key))) or float(payload.get(key)) <= 0.0:
				errors.append("facility_speed_multiplier_invalid")
		else:
			_validate_positive_source_int(payload.get(key), "facility_%s_invalid" % key, errors)


func _validate_order_payload(payload: Dictionary, errors: Array[String]) -> void:
	_check_source_keys(payload, [
		"allocation_basis", "budget_units", "distance_rule", "may_exceed_persistent_demand",
		"required_route_tag", "requires_positive_owner_matching_product_gdp", "requires_real_market_node",
		"requires_real_market_or_factory_nodes", "route_tag_match_mode", "uses_real_route_capacity",
	], "order_payload", errors)
	_validate_positive_source_int(payload.get("budget_units"), "order_budget_invalid", errors)
	if str(payload.get("allocation_basis", "")) != "matching_product_gdp_share_30s" or str(payload.get("distance_rule", "")) != "remote_gt_2" or str(payload.get("required_route_tag", "")) != "sea" or str(payload.get("route_tag_match_mode", "")) != "any_segment_in_multimodal_route":
		errors.append("order_filter_policy_invalid")
	for key in ["may_exceed_persistent_demand", "requires_positive_owner_matching_product_gdp", "requires_real_market_node", "requires_real_market_or_factory_nodes", "uses_real_route_capacity"]:
		if payload.get(key) != true:
			errors.append("order_%s_invalid" % key)


func _validate_supply_payload(payload: Dictionary, errors: Array[String]) -> void:
	_check_source_keys(payload, [
		"allocation_basis", "creates_one_time_physical_goods", "distance_rule", "is_permanent_installation",
		"required_route_tag", "requires_legal_production_factory", "requires_positive_owner_matching_product_gdp",
		"requires_real_market_or_factory_nodes", "route_tag_match_mode", "spawn_units", "uses_real_route_capacity",
	], "supply_payload", errors)
	_validate_positive_source_int(payload.get("spawn_units"), "supply_units_invalid", errors)
	if str(payload.get("allocation_basis", "")) != "matching_product_gdp_share_30s" or str(payload.get("distance_rule", "")) != "near_lte_2" or str(payload.get("required_route_tag", "")) != "land" or str(payload.get("route_tag_match_mode", "")) != "any_segment_in_multimodal_route":
		errors.append("supply_filter_policy_invalid")
	for key in ["creates_one_time_physical_goods", "requires_legal_production_factory", "requires_positive_owner_matching_product_gdp", "requires_real_market_or_factory_nodes", "uses_real_route_capacity"]:
		if payload.get(key) != true:
			errors.append("supply_%s_invalid" % key)
	if payload.get("is_permanent_installation") != false:
		errors.append("supply_permanence_invalid")


func _validate_monster_payload(payload: Dictionary, machine: Dictionary, errors: Array[String]) -> void:
	_check_source_keys(payload, [
		"bound_skill_recipient", "card_rank", "heal_to_full_on_upgrade", "monster_family_id",
		"ownership_transfer_on_upgrade", "presence_time_policy", "rank4_repeat_behavior",
		"refresh_total_presence_time", "same_name_upgrade_extend_seconds", "starter_conflict_policy",
		"unit_profile_owns_stats", "upgrade_respects_target_owner_rank_cap", "upgrade_target_same_family_any_owner",
	], "monster_payload", errors)
	if not SCHEMA.is_stable_id(str(payload.get("monster_family_id", ""))) or payload.get("card_rank") != machine.get("rank"):
		errors.append("monster_identity_invalid")
	if str(payload.get("bound_skill_recipient", "")) != "existing_monster_owner" or str(payload.get("presence_time_policy", "")) != "add_to_remaining_time" or str(payload.get("rank4_repeat_behavior", "")) != "heal_to_full_and_extend_60_seconds" or str(payload.get("starter_conflict_policy", "")) != "private_reselect":
		errors.append("monster_policy_invalid")
	if payload.get("heal_to_full_on_upgrade") != true or payload.get("ownership_transfer_on_upgrade") != false or payload.get("refresh_total_presence_time") != false or payload.get("unit_profile_owns_stats") != true or payload.get("upgrade_respects_target_owner_rank_cap") != true or payload.get("upgrade_target_same_family_any_owner") != true:
		errors.append("monster_flags_invalid")
	if payload.get("same_name_upgrade_extend_seconds") != 60:
		errors.append("monster_presence_duration_invalid")


func _validate_military_payload(payload: Dictionary, machine: Dictionary, errors: Array[String]) -> void:
	_check_source_keys(payload, [
		"bound_action_profile_review_pending", "bound_actions_excluded_from_hand_limit",
		"bound_actions_require_assets", "card_rank", "military_family_id",
		"region_damage_requires_explicit_unit_action", "unit_profile_owns_stats",
	], "military_payload", errors)
	if not SCHEMA.is_stable_id(str(payload.get("military_family_id", ""))) or payload.get("card_rank") != machine.get("rank"):
		errors.append("military_identity_invalid")
	for key in ["bound_action_profile_review_pending", "bound_actions_excluded_from_hand_limit", "bound_actions_require_assets", "region_damage_requires_explicit_unit_action", "unit_profile_owns_stats"]:
		if payload.get(key) != true:
			errors.append("military_%s_invalid" % key)


func _validate_disrupt_payload(payload: Dictionary, errors: Array[String]) -> void:
	_check_source_keys(payload, ["counterable", "direct_player_interaction", "hand_discard_count", "hand_lock_seconds", "target_cash_penalty"], "disrupt_payload", errors)
	if payload.get("counterable") != true or payload.get("direct_player_interaction") != true:
		errors.append("disrupt_response_policy_invalid")
	_validate_positive_source_int(payload.get("hand_discard_count"), "disrupt_count_invalid", errors)
	_validate_nonnegative_source_int(payload.get("hand_lock_seconds"), "disrupt_lock_invalid", errors)
	_validate_nonnegative_source_int(payload.get("target_cash_penalty"), "disrupt_cash_invalid", errors)


func _validate_steal_payload(payload: Dictionary, errors: Array[String]) -> void:
	_check_source_keys(payload, ["counterable", "direct_player_interaction", "hand_lock_seconds", "hand_steal_count", "steal_fail_cash"], "steal_payload", errors)
	if payload.get("counterable") != true or payload.get("direct_player_interaction") != true:
		errors.append("steal_response_policy_invalid")
	_validate_nonnegative_source_int(payload.get("hand_lock_seconds"), "steal_lock_invalid", errors)
	_validate_positive_source_int(payload.get("hand_steal_count"), "steal_count_invalid", errors)
	_validate_nonnegative_source_int(payload.get("steal_fail_cash"), "steal_cash_invalid", errors)


func _validate_counter_payload(payload: Dictionary, errors: Array[String]) -> void:
	_check_source_keys(payload, ["counter_strength", "counter_window_seconds", "private_trace_count", "refund_cash", "response_depth", "target_scope"], "counter_payload", errors)
	_validate_positive_source_int(payload.get("counter_strength"), "counter_strength_invalid", errors)
	_validate_nonnegative_source_int(payload.get("private_trace_count"), "counter_trace_invalid", errors)
	_validate_nonnegative_source_int(payload.get("refund_cash"), "counter_refund_invalid", errors)
	if not (payload.get("counter_window_seconds") is float or payload.get("counter_window_seconds") is int) or float(payload.get("counter_window_seconds")) != 5.0 or payload.get("response_depth") != 1 or str(payload.get("target_scope", "")) != "direct_player_interaction":
		errors.append("counter_response_policy_invalid")


func _validate_organization_payload(payload: Dictionary, machine: Dictionary, errors: Array[String]) -> void:
	var axis := str(payload.get("organization_axis", ""))
	if not ORGANIZATION_AXIS_PAYLOAD_KEYS.has(axis):
		errors.append("organization_axis_unknown")
		return
	_check_source_keys(payload, ORGANIZATION_COMMON_PAYLOAD_KEYS + ORGANIZATION_AXIS_PAYLOAD_KEYS[axis], "organization_payload", errors)
	if not SCHEMA.is_stable_id(str(payload.get("organization_family_id", ""))) or str(payload.get("organization_family_id", "")) != str(machine.get("family_id", "")) or payload.get("organization_rank") != machine.get("rank"):
		errors.append("organization_identity_invalid")
	for key in ["organization_slot_cost", "organization_slot_limit", "activation_window_offset", "required_positive_gdp_color_count", "ordinary_submission_cost"]:
		_validate_positive_source_int(payload.get(key), "organization_%s_invalid" % key, errors)
	_validate_nonnegative_source_int(payload.get("required_own_gdp_min"), "organization_gdp_min_invalid", errors)
	if str(payload.get("install_policy", "")) != "upgrade_highest_rank_only" or str(payload.get("stack_policy", "")) != "highest_rank_nonstacking" or str(payload.get("equal_or_lower_rank_resolution", "")) != "reject_before_consume" or str(payload.get("activation_snapshot_timing", "")) != "next_window_start" or str(payload.get("persistence", "")) != "run" or str(payload.get("public_clue_kind", "")) != "installed_organization_axis_aura":
		errors.append("organization_policy_invalid")
	if payload.get("replacement_requires_higher_rank") != true or payload.get("direct_player_interaction") != false or payload.get("counterable") != false or payload.get("phase_veto_eligible") != false or payload.get("counts_as_normal_card_submission") != true:
		errors.append("organization_flags_invalid")
	_validate_source_id_array(payload.get("counterplay_tags"), "organization_counterplay_tags_invalid", errors)
	_validate_source_id_array(payload.get("ai_effect_tags"), "organization_ai_effect_tags_invalid", errors)
	var cap: Variant = payload.get("anti_snowball_cap")
	if not (cap is Dictionary):
		errors.append("organization_anti_snowball_cap_invalid")
	else:
		_check_source_keys(cap, ["kind", "value"], "organization_anti_snowball_cap", errors)
		if not SCHEMA.is_stable_id(str((cap as Dictionary).get("kind", ""))):
			errors.append("organization_anti_snowball_kind_invalid")
		_validate_nonnegative_source_int((cap as Dictionary).get("value"), "organization_anti_snowball_value_invalid", errors)
	_validate_organization_axis_payload(axis, payload, errors)


func _validate_organization_axis_payload(axis: String, payload: Dictionary, errors: Array[String]) -> void:
	match axis:
		"asset_conversion":
			_validate_positive_source_int(payload.get("asset_conversion_bonus_bp"), "organization_conversion_bonus_invalid", errors)
			_validate_positive_source_int(payload.get("asset_conversion_bonus_cap_milli_per_second"), "organization_conversion_cap_invalid", errors)
			if str(payload.get("scope", "")) != "same_color_gdp_only":
				errors.append("organization_conversion_scope_invalid")
		"hand_capacity":
			for key in ["base_ordinary_hand_limit", "ordinary_hand_limit", "ordinary_hand_limit_bonus", "absolute_hand_limit_cap"]:
				_validate_positive_source_int(payload.get(key), "organization_%s_invalid" % key, errors)
			if str(payload.get("scope", "")) != "ordinary_hand_only":
				errors.append("organization_hand_scope_invalid")
		"military_command":
			for key in ["base_controlled_military_count_limit", "base_primary_military_rank_limit", "controlled_military_count_limit", "primary_military_rank_limit", "secondary_military_rank_limit"]:
				_validate_nonnegative_source_int(payload.get(key), "organization_%s_invalid" % key, errors)
		"monster_binding":
			for key in ["base_controlled_monster_count_limit", "base_primary_monster_rank_limit", "controlled_monster_count_limit", "primary_monster_rank_limit", "secondary_monster_rank_limit"]:
				_validate_nonnegative_source_int(payload.get(key), "organization_%s_invalid" % key, errors)
			if payload.get("foreign_same_name_upgrade_must_respect_target_owner_limits") != true or payload.get("foreign_upgrade_does_not_transfer_control") != true or str(payload.get("foreign_upgrade_rank_limit_source", "")) != "target_current_owner_organization_snapshot":
				errors.append("organization_monster_foreign_upgrade_policy_invalid")
		"action_bandwidth":
			for key in ["ordinary_submission_bonus", "extra_submission_asset_surcharge", "ordinary_submission_hard_cap", "burst_window_period", "burst_submission_bonus", "burst_submission_surcharge"]:
				_validate_nonnegative_source_int(payload.get(key), "organization_%s_invalid" % key, errors)
			if payload.get("window_start_snapshot_required") != true or payload.get("response_cards_ignore_ordinary_submission_limit") != true or not SCHEMA.is_stable_id(str(payload.get("public_same_source_aura", ""))):
				errors.append("organization_action_bandwidth_policy_invalid")

func _target_spec(machine: Dictionary) -> Dictionary:
	match str(machine.get("effect_kind", "")):
		"install_commodity_rate":
			return {"target_id": "facility.same_industry", "selection_id": "actor_choice", "cardinality_id": "exactly_one", "filter_ids": ["facility.kind.factory_or_market", "industry.same_as_card"]}
		"build_upgrade_or_repair_facility":
			return {"target_id": "district.active", "selection_id": "actor_choice", "cardinality_id": "exactly_one", "filter_ids": ["district.state.active_or_undeveloped_or_ruined", "facility.slot.unique_by_kind"]}
		"deploy_or_upgrade_monster":
			return {"target_id": "unit.same_family", "selection_id": "actor_choice", "cardinality_id": "exactly_one", "filter_ids": ["unit.kind.monster", "unit.region_or_same_family", "unit.controller.any"]}
		"deploy_or_upgrade_military":
			return {"target_id": "unit.same_family", "selection_id": "actor_choice", "cardinality_id": "exactly_one", "filter_ids": ["unit.kind.military", "unit.region_or_same_family", "unit.controller.actor"]}
		"player_hand_disrupt", "player_hand_steal":
			return {"target_id": "player.opponent", "selection_id": "actor_choice", "cardinality_id": "exactly_one", "filter_ids": ["hand.discardable"]}
		"card_counter":
			return {"target_id": "response.incoming_direct_interaction", "selection_id": "trigger_context", "cardinality_id": "exactly_one", "filter_ids": ["interaction.direct"]}
		"global_order_budget":
			return {"target_id": "world.global", "selection_id": "automatic", "cardinality_id": "all_matching", "filter_ids": ["world.matching_goods"]}
		"global_supply_spawn":
			return {"target_id": "world.global", "selection_id": "automatic", "cardinality_id": "all_matching", "filter_ids": ["world.matching_factories"]}
		"install_organization_upgrade":
			return {"target_id": "organization.self_slot", "selection_id": "actor_choice", "cardinality_id": "exactly_one", "filter_ids": ["organization.slot.available_or_same_family"]}
	return {}


func _response_id(effect_kind: String) -> String:
	if effect_kind == "card_counter":
		return "counter"
	if effect_kind == "player_hand_disrupt" or effect_kind == "player_hand_steal":
		return "counterable"
	return "none"


func _effect_ops(machine: Dictionary) -> Array:
	var payload: Dictionary = machine.get("effect_payload", {})
	var rank := int(machine.get("rank", 0))
	match str(machine.get("effect_kind", "")):
		"install_commodity_rate":
			return [{
				"op_id": "install_rate",
				"rate_subject_id": "card_family",
				"rate_axis_id": "production_or_demand_by_facility_kind",
				"industry_id": str(payload.get("industry_id", "")),
				"rate_units_per_minute": int(payload.get("rate_per_minute", 0)),
				"valid_facility_kind_ids": (payload.get("valid_facility_kinds", []) as Array).duplicate(),
				"persistence_id": str(payload.get("persistence", "")),
			}]
		"build_upgrade_or_repair_facility":
			var profile := _facility_profile(payload)
			var common := {
				"facility_kind_id": str(payload.get("facility_kind", "")),
				"industry_id": str(machine.get("industry_id", "")),
				"card_rank": rank,
			}
			return [
				_merge(common, {"op_id": "build_facility", "condition_id": "facility_slot.empty_or_district_ruined", "facility_profile": profile.duplicate(true)}),
				_merge(common, {"op_id": "upgrade_facility", "condition_id": "facility.same_kind_lower_rank", "facility_profile": profile.duplicate(true)}),
				_merge(common, {"op_id": "repair_facility", "condition_id": "facility.same_kind_equal_or_higher_rank", "repair_policy_id": "established_facility_repair"}),
			]
		"deploy_or_upgrade_monster":
			var monster_family_id := str(payload.get("monster_family_id", ""))
			return [
				{"op_id": "deploy_unit", "condition_id": "same_family_unit_absent", "unit_kind_id": "monster", "unit_family_id": monster_family_id, "card_rank": rank, "stats_source_id": "unit_profile"},
				{"op_id": "upgrade_same_family_unit", "condition_id": "same_family_unit_lower_rank", "unit_kind_id": "monster", "unit_family_id": monster_family_id, "card_rank": rank, "target_controller_scope_id": "any", "control_transfer_id": "preserve_existing_controller", "rank_cap_policy_id": "target_controller_organization_cap", "recipient_policy_id": "existing_unit_controller", "stats_source_id": "unit_profile"},
				{"op_id": "extend_presence", "condition_id": "same_family_unit_present", "duration_seconds": int(payload.get("same_name_upgrade_extend_seconds", 0)), "presence_time_policy_id": "add_to_remaining_time", "refresh_total_presence_time": bool(payload.get("refresh_total_presence_time", true)), "rank4_repeat_policy_id": "heal_to_full_and_extend"},
				{"op_id": "heal_unit", "condition_id": "same_family_unit_present", "heal_policy_id": "to_full"},
			]
		"deploy_or_upgrade_military":
			var military_family_id := str(payload.get("military_family_id", ""))
			return [
				{"op_id": "deploy_unit", "condition_id": "same_family_unit_absent", "unit_kind_id": "military", "unit_family_id": military_family_id, "card_rank": rank, "stats_source_id": "unit_profile"},
				{"op_id": "upgrade_same_family_unit", "condition_id": "same_family_unit_lower_rank", "unit_kind_id": "military", "unit_family_id": military_family_id, "card_rank": rank, "target_controller_scope_id": "actor", "control_transfer_id": "preserve_actor_control", "rank_cap_policy_id": "established_military_cap", "recipient_policy_id": "actor", "stats_source_id": "unit_profile"},
			]
		"global_order_budget":
			return [{
				"op_id": "modify_demand", "amount_units": int(payload.get("budget_units", 0)),
				"allocation_basis_id": str(payload.get("allocation_basis", "")), "distance_rule_id": str(payload.get("distance_rule", "")),
				"required_route_tag_id": str(payload.get("required_route_tag", "")), "route_tag_match_mode_id": str(payload.get("route_tag_match_mode", "")),
				"requires_positive_controller_matching_product_gdp": bool(payload.get("requires_positive_owner_matching_product_gdp", false)),
				"requires_real_market_or_factory_nodes": bool(payload.get("requires_real_market_or_factory_nodes", false)),
				"requires_real_market_node": bool(payload.get("requires_real_market_node", false)),
				"uses_real_route_capacity": bool(payload.get("uses_real_route_capacity", false)),
				"may_exceed_persistent_demand": bool(payload.get("may_exceed_persistent_demand", false)),
			}]
		"global_supply_spawn":
			return [{
				"op_id": "modify_supply", "amount_units": int(payload.get("spawn_units", 0)),
				"allocation_basis_id": str(payload.get("allocation_basis", "")), "distance_rule_id": str(payload.get("distance_rule", "")),
				"required_route_tag_id": str(payload.get("required_route_tag", "")), "route_tag_match_mode_id": str(payload.get("route_tag_match_mode", "")),
				"requires_positive_controller_matching_product_gdp": bool(payload.get("requires_positive_owner_matching_product_gdp", false)),
				"requires_real_market_or_factory_nodes": bool(payload.get("requires_real_market_or_factory_nodes", false)),
				"requires_real_production_factory": bool(payload.get("requires_legal_production_factory", false)),
				"uses_real_route_capacity": bool(payload.get("uses_real_route_capacity", false)),
				"creates_one_time_physical_goods": bool(payload.get("creates_one_time_physical_goods", false)),
				"is_permanent_installation": bool(payload.get("is_permanent_installation", true)),
			}]
		"player_hand_disrupt":
			var disrupt_ops: Array = [{"op_id": "discard_random", "count": int(payload.get("hand_discard_count", 0)), "target_cash_penalty": int(payload.get("target_cash_penalty", 0))}]
			if int(payload.get("hand_lock_seconds", 0)) > 0:
				disrupt_ops.append({"op_id": "lock_random", "duration_seconds": int(payload.get("hand_lock_seconds", 0))})
			return disrupt_ops
		"player_hand_steal":
			var steal_ops: Array = [{"op_id": "steal_random", "count": int(payload.get("hand_steal_count", 0)), "steal_fail_cash": int(payload.get("steal_fail_cash", 0))}]
			if int(payload.get("hand_lock_seconds", 0)) > 0:
				steal_ops.append({"op_id": "lock_random", "duration_seconds": int(payload.get("hand_lock_seconds", 0))})
			return steal_ops
		"card_counter":
			return [{
				"op_id": "counter_action", "counter_strength": int(payload.get("counter_strength", 0)),
				"counter_window_seconds": int(float(payload.get("counter_window_seconds", 0.0))),
				"response_depth": int(payload.get("response_depth", 0)), "target_scope_id": str(payload.get("target_scope", "")),
				"refund_cash": int(payload.get("refund_cash", 0)), "private_trace_count": int(payload.get("private_trace_count", 0)),
			}]
		"install_organization_upgrade":
			return [_organization_op(payload)]
	return []


func _facility_profile(payload: Dictionary) -> Dictionary:
	var profile := {
		"profile_id": str(payload.get("facility_kind", "")),
		"shared_hp_contribution": int(payload.get("shared_hp_contribution", 0)),
		"shared_hp_profile_id": str(payload.get("shared_hp_profile", "")),
		"rent_enabled": bool(payload.get("rent_enabled", false)),
		"rent_rate_profile_id": str(payload.get("rent_rate_profile", "")),
	}
	for key in FACILITY_CAPACITY_KEYS.get(str(payload.get("facility_kind", "")), []):
		profile[key] = payload.get(key) if str(key) == "speed_multiplier" else int(payload.get(key, 0))
	return profile


func _organization_op(payload: Dictionary) -> Dictionary:
	var anti_cap: Dictionary = payload.get("anti_snowball_cap", {})
	return {
		"op_id": "install_organization_upgrade",
		"organization_axis_id": str(payload.get("organization_axis", "")),
		"organization_family_id": str(payload.get("organization_family_id", "")),
		"organization_rank": int(payload.get("organization_rank", 0)),
		"slot_cost": int(payload.get("organization_slot_cost", 0)),
		"slot_limit": int(payload.get("organization_slot_limit", 0)),
		"install_policy_id": str(payload.get("install_policy", "")),
		"stack_policy_id": str(payload.get("stack_policy", "")),
		"replacement_requires_higher_rank": bool(payload.get("replacement_requires_higher_rank", false)),
		"equal_or_lower_rank_resolution_id": str(payload.get("equal_or_lower_rank_resolution", "")),
		"activation_window_offset": int(payload.get("activation_window_offset", 0)),
		"activation_snapshot_timing_id": str(payload.get("activation_snapshot_timing", "")),
		"persistence_id": str(payload.get("persistence", "")),
		"required_controller_gdp_min": int(payload.get("required_own_gdp_min", 0)),
		"required_positive_gdp_color_count": int(payload.get("required_positive_gdp_color_count", 0)),
		"public_clue_kind_id": str(payload.get("public_clue_kind", "")),
		"counterplay_tag_ids": (payload.get("counterplay_tags", []) as Array).duplicate(),
		"ordinary_submission_cost": int(payload.get("ordinary_submission_cost", 0)),
		"counts_as_normal_card_submission": bool(payload.get("counts_as_normal_card_submission", false)),
		"anti_snowball_cap": {"kind_id": str(anti_cap.get("kind", "")), "value": int(anti_cap.get("value", 0))},
		"capability": _organization_capability(payload),
	}


func _organization_capability(payload: Dictionary) -> Dictionary:
	var axis := str(payload.get("organization_axis", ""))
	match axis:
		"asset_conversion":
			return {"capability_id": axis, "asset_conversion_bonus_bp": int(payload.get("asset_conversion_bonus_bp", 0)), "asset_conversion_bonus_cap_milli_per_second": int(payload.get("asset_conversion_bonus_cap_milli_per_second", 0)), "scope_id": str(payload.get("scope", ""))}
		"hand_capacity":
			return {"capability_id": axis, "base_ordinary_hand_limit": int(payload.get("base_ordinary_hand_limit", 0)), "ordinary_hand_limit": int(payload.get("ordinary_hand_limit", 0)), "ordinary_hand_limit_bonus": int(payload.get("ordinary_hand_limit_bonus", 0)), "absolute_hand_limit_cap": int(payload.get("absolute_hand_limit_cap", 0)), "scope_id": str(payload.get("scope", ""))}
		"military_command":
			return {"capability_id": axis, "base_controlled_military_count_limit": int(payload.get("base_controlled_military_count_limit", 0)), "base_primary_military_rank_limit": int(payload.get("base_primary_military_rank_limit", 0)), "controlled_military_count_limit": int(payload.get("controlled_military_count_limit", 0)), "primary_military_rank_limit": int(payload.get("primary_military_rank_limit", 0)), "secondary_military_rank_limit": int(payload.get("secondary_military_rank_limit", 0))}
		"monster_binding":
			return {"capability_id": axis, "base_controlled_monster_count_limit": int(payload.get("base_controlled_monster_count_limit", 0)), "base_primary_monster_rank_limit": int(payload.get("base_primary_monster_rank_limit", 0)), "controlled_monster_count_limit": int(payload.get("controlled_monster_count_limit", 0)), "primary_monster_rank_limit": int(payload.get("primary_monster_rank_limit", 0)), "secondary_monster_rank_limit": int(payload.get("secondary_monster_rank_limit", 0)), "foreign_upgrade_rank_limit_source_id": str(payload.get("foreign_upgrade_rank_limit_source", "")), "foreign_upgrade_does_not_transfer_control": bool(payload.get("foreign_upgrade_does_not_transfer_control", false)), "foreign_same_name_upgrade_must_respect_target_limits": bool(payload.get("foreign_same_name_upgrade_must_respect_target_owner_limits", false))}
		"action_bandwidth":
			return {"capability_id": axis, "ordinary_submission_bonus": int(payload.get("ordinary_submission_bonus", 0)), "extra_submission_asset_surcharge": int(payload.get("extra_submission_asset_surcharge", 0)), "ordinary_submission_hard_cap": int(payload.get("ordinary_submission_hard_cap", 0)), "burst_window_period": int(payload.get("burst_window_period", 0)), "burst_submission_bonus": int(payload.get("burst_submission_bonus", 0)), "burst_submission_surcharge": int(payload.get("burst_submission_surcharge", 0)), "window_start_snapshot_required": bool(payload.get("window_start_snapshot_required", false)), "response_cards_ignore_ordinary_submission_limit": bool(payload.get("response_cards_ignore_ordinary_submission_limit", false)), "public_same_source_aura_id": str(payload.get("public_same_source_aura", ""))}
	return {}


func _validate_asset_cost(value: Variant, errors: Array[String]) -> void:
	if not (value is Dictionary):
		errors.append("machine_asset_cost_invalid")
		return
	_check_source_keys(value, SCHEMA.ASSET_KEYS, "machine_asset_cost", errors)
	for key in SCHEMA.ASSET_KEYS:
		_validate_nonnegative_source_int((value as Dictionary).get(key), "machine_asset_cost_%s_invalid" % key, errors)


func _check_source_keys(value: Dictionary, expected: Array, path: String, errors: Array[String]) -> void:
	var actual: Array[String] = []
	var required: Array[String] = []
	for key in value.keys():
		actual.append(str(key))
	for key in expected:
		required.append(str(key))
	actual.sort()
	required.sort()
	if actual != required:
		errors.append("%s_keys_invalid" % path)


func _validate_nonnegative_source_int(value: Variant, error_id: String, errors: Array[String]) -> void:
	if not _is_integral_source_number(value) or int(value) < 0:
		errors.append(error_id)


func _validate_positive_source_int(value: Variant, error_id: String, errors: Array[String]) -> void:
	if not _is_integral_source_number(value) or int(value) <= 0:
		errors.append(error_id)


func _is_integral_source_number(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_finite(float(value)) and float(value) == floor(float(value))


func _validate_source_id_array(value: Variant, error_id: String, errors: Array[String]) -> void:
	if not (value is Array) or (value as Array).is_empty():
		errors.append(error_id)
		return
	var seen: Dictionary = {}
	for item in value:
		var id := str(item)
		if not (item is String) or not SCHEMA.is_stable_id(id) or seen.has(id):
			errors.append(error_id)
			return
		seen[id] = true


func _array_equals(value: Variant, expected: Array) -> bool:
	return value is Array and (value as Array) == expected


func _merge(left: Dictionary, right: Dictionary) -> Dictionary:
	var merged := left.duplicate(true)
	merged.merge(right, true)
	return merged


func _prefixed_errors(prefix: String, errors_value: Variant) -> Array[String]:
	var result: Array[String] = []
	if errors_value is Array:
		for error in errors_value:
			result.append("%s:%s" % [prefix, str(error)])
	return result


func _success(spec: Dictionary, source_definition_fingerprint: String, cache_hit: bool) -> Dictionary:
	return {
		"ok": true,
		"spec": spec.duplicate(true),
		"errors": [],
		"source_definition_fingerprint": source_definition_fingerprint,
		"cache_hit": cache_hit,
	}


func _failure(errors: Array, source_definition_fingerprint := "") -> Dictionary:
	return {
		"ok": false,
		"spec": {},
		"errors": errors.duplicate(),
		"source_definition_fingerprint": source_definition_fingerprint,
		"cache_hit": false,
	}

func _normalized_asset_cost(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var normalized: Dictionary = {}
	for key in SCHEMA.ASSET_KEYS:
		normalized[key] = int(source.get(key, 0))
	return normalized