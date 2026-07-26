extends RefCounted
class_name CardSemanticSchemaV1

const SCHEMA_VERSION := 1
const ASSET_KEYS := ["life", "energy", "industry", "technology", "commerce", "shipping", "generic"]
const CATEGORY_IDS := ["commodity", "facility", "supply_demand", "monster", "military", "interaction", "organization"]
const INDUSTRY_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping", "generic"]
const TIMING_IDS := ["main_action", "response_window"]
const TARGET_IDS := [
	"facility.same_industry", "district.active", "unit.same_family", "player.opponent",
	"response.incoming_direct_interaction", "world.global", "organization.self_slot",
]
const SELECTION_IDS := ["actor_choice", "automatic", "trigger_context"]
const CARDINALITY_IDS := ["exactly_one", "all_matching"]
const TARGET_FILTER_IDS := [
	"facility.kind.factory_or_market", "industry.same_as_card",
	"district.state.active_or_undeveloped_or_ruined", "facility.slot.unique_by_kind",
	"unit.kind.monster", "unit.kind.military", "unit.region_or_same_family",
	"unit.controller.any", "unit.controller.actor", "hand.discardable",
	"interaction.direct", "world.matching_goods", "world.matching_factories",
	"organization.slot.available_or_same_family",
]
const RESPONSE_IDS := ["none", "counterable", "counter"]
const RUNTIME_READINESS_IDS := ["active", "projection_only", "not_acquirable"]
const SOURCE_KINDS := ["own_hand", "public_rack", "public_reveal", "response_window"]
const SOURCE_VISIBILITY_SCOPES := {
	"own_hand": ["actor_private"],
	"public_rack": ["public"],
	"public_reveal": ["public"],
	"response_window": ["actor_private", "response_authorized"],
}
const FACILITY_PROFILE_FIELDS := {
	"factory": ["profile_id", "production_capacity_units_per_minute", "shared_hp_contribution", "shared_hp_profile_id", "rent_enabled", "rent_rate_profile_id"],
	"market": ["profile_id", "demand_capacity_units_per_minute", "shared_hp_contribution", "shared_hp_profile_id", "rent_enabled", "rent_rate_profile_id"],
	"road": ["profile_id", "throughput_units_per_minute", "speed_multiplier", "shared_hp_contribution", "shared_hp_profile_id", "rent_enabled", "rent_rate_profile_id"],
	"port": ["profile_id", "throughput_units_per_minute", "speed_multiplier", "shared_hp_contribution", "shared_hp_profile_id", "rent_enabled", "rent_rate_profile_id"],
	"spaceport": ["profile_id", "throughput_units_per_minute", "speed_multiplier", "shared_hp_contribution", "shared_hp_profile_id", "rent_enabled", "rent_rate_profile_id"],
	"warehouse": ["profile_id", "storage_capacity_units", "inbound_throughput_units_per_minute", "outbound_throughput_units_per_minute", "shared_hp_contribution", "shared_hp_profile_id", "rent_enabled", "rent_rate_profile_id"],
}
const ORGANIZATION_CAPABILITY_FIELDS := {
	"asset_conversion": ["capability_id", "asset_conversion_bonus_bp", "asset_conversion_bonus_cap_milli_per_second", "scope_id"],
	"hand_capacity": ["capability_id", "base_ordinary_hand_limit", "ordinary_hand_limit", "ordinary_hand_limit_bonus", "absolute_hand_limit_cap", "scope_id"],
	"military_command": ["capability_id", "base_controlled_military_count_limit", "base_primary_military_rank_limit", "controlled_military_count_limit", "primary_military_rank_limit", "secondary_military_rank_limit"],
	"monster_binding": ["capability_id", "base_controlled_monster_count_limit", "base_primary_monster_rank_limit", "controlled_monster_count_limit", "primary_monster_rank_limit", "secondary_monster_rank_limit", "foreign_upgrade_rank_limit_source_id", "foreign_upgrade_does_not_transfer_control", "foreign_same_name_upgrade_must_respect_target_limits"],
	"action_bandwidth": ["capability_id", "ordinary_submission_bonus", "extra_submission_asset_surcharge", "ordinary_submission_hard_cap", "burst_window_period", "burst_submission_bonus", "burst_submission_surcharge", "window_start_snapshot_required", "response_cards_ignore_ordinary_submission_limit", "public_same_source_aura_id"],
}
const OP_FIELDS := {
	"install_rate": ["op_id", "rate_subject_id", "rate_axis_id", "industry_id", "rate_units_per_minute", "valid_facility_kind_ids", "persistence_id"],
	"build_facility": ["op_id", "condition_id", "facility_kind_id", "industry_id", "card_rank", "facility_profile"],
	"upgrade_facility": ["op_id", "condition_id", "facility_kind_id", "industry_id", "card_rank", "facility_profile"],
	"repair_facility": ["op_id", "condition_id", "facility_kind_id", "industry_id", "card_rank", "repair_policy_id"],
	"deploy_unit": ["op_id", "condition_id", "unit_kind_id", "unit_family_id", "card_rank", "stats_source_id"],
	"upgrade_same_family_unit": ["op_id", "condition_id", "unit_kind_id", "unit_family_id", "card_rank", "target_controller_scope_id", "control_transfer_id", "rank_cap_policy_id", "recipient_policy_id", "stats_source_id"],
	"extend_presence": ["op_id", "condition_id", "duration_seconds", "presence_time_policy_id", "refresh_total_presence_time", "rank4_repeat_policy_id"],
	"heal_unit": ["op_id", "condition_id", "heal_policy_id"],
	"modify_supply": ["op_id", "amount_units", "allocation_basis_id", "distance_rule_id", "required_route_tag_id", "route_tag_match_mode_id", "requires_positive_controller_matching_product_gdp", "requires_real_market_or_factory_nodes", "requires_real_production_factory", "uses_real_route_capacity", "creates_one_time_physical_goods", "is_permanent_installation"],
	"modify_demand": ["op_id", "amount_units", "allocation_basis_id", "distance_rule_id", "required_route_tag_id", "route_tag_match_mode_id", "requires_positive_controller_matching_product_gdp", "requires_real_market_or_factory_nodes", "requires_real_market_node", "uses_real_route_capacity", "may_exceed_persistent_demand"],
	"discard_random": ["op_id", "count", "target_cash_penalty"],
	"steal_random": ["op_id", "count", "steal_fail_cash"],
	"lock_random": ["op_id", "duration_seconds"],
	"counter_action": ["op_id", "counter_strength", "counter_window_seconds", "response_depth", "target_scope_id", "refund_cash", "private_trace_count"],
	"install_organization_upgrade": ["op_id", "organization_axis_id", "organization_family_id", "organization_rank", "slot_cost", "slot_limit", "install_policy_id", "stack_policy_id", "replacement_requires_higher_rank", "equal_or_lower_rank_resolution_id", "activation_window_offset", "activation_snapshot_timing_id", "persistence_id", "required_controller_gdp_min", "required_positive_gdp_color_count", "public_clue_kind_id", "counterplay_tag_ids", "ordinary_submission_cost", "counts_as_normal_card_submission", "anti_snowball_cap", "capability"],
	"military_move": ["op_id"],
	"military_guard": ["op_id"],
	"military_strike": ["op_id"],
	"global_order": ["op_id"],
	"global_supply_spawn": ["op_id"],
}


static func validate_semantic_spec(value: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not (value is Dictionary):
		return _result(["spec:not_dictionary"])
	var spec: Dictionary = value
	_check_exact_keys(spec, [
		"schema_version", "source_catalog_id", "source_definition_fingerprint", "semantic_fingerprint",
		"identity", "cost", "timing", "target", "effect_ops", "response",
		"information_policy", "runtime_readiness_id",
	], "spec", errors)
	if not _is_int_value(spec.get("schema_version")) or int(spec.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("spec:schema_version")
	if not is_stable_id(str(spec.get("source_catalog_id", ""))):
		errors.append("spec:source_catalog_id")
	if not _is_sha256(str(spec.get("source_definition_fingerprint", ""))):
		errors.append("spec:source_definition_fingerprint")
	if not _is_sha256(str(spec.get("semantic_fingerprint", ""))):
		errors.append("spec:semantic_fingerprint")
	_validate_identity(spec.get("identity"), errors)
	_validate_cost(spec.get("cost"), errors)
	_validate_timing(spec.get("timing"), errors)
	_validate_target(spec.get("target"), errors)
	_validate_effect_ops(spec.get("effect_ops"), errors)
	_validate_response(spec.get("response"), errors)
	_validate_information_policy(spec.get("information_policy"), errors)
	if not RUNTIME_READINESS_IDS.has(str(spec.get("runtime_readiness_id", ""))):
		errors.append("spec:runtime_readiness_id")
	if not is_pure_data(spec):
		errors.append("spec:not_pure_data")
	if errors.is_empty() and fingerprint(spec, "semantic_fingerprint") != str(spec.get("semantic_fingerprint", "")):
		errors.append("spec:semantic_fingerprint_mismatch")
	return _result(errors)


static func validate_effect_op(value: Variant) -> Dictionary:
	var errors: Array[String] = []
	_validate_effect_op_into(value, "op", errors)
	return _result(errors)


static func validate_authorized_envelope(value: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not (value is Dictionary):
		return _result(["envelope:not_dictionary"])
	var envelope: Dictionary = value
	_check_exact_keys(envelope, ["schema_version", "source_kind", "source_revision", "visibility_scope_id", "card_record"], "envelope", errors)
	if not _is_int_value(envelope.get("schema_version")) or int(envelope.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("envelope:schema_version")
	var source_kind := str(envelope.get("source_kind", ""))
	if not SOURCE_KINDS.has(source_kind):
		errors.append("envelope:source_kind")
	var revision: Variant = envelope.get("source_revision")
	if not ((_is_int_value(revision) and int(revision) >= 0) or (revision is String and is_stable_id(str(revision)))):
		errors.append("envelope:source_revision")
	var visibility_scope_id := str(envelope.get("visibility_scope_id", ""))
	if SOURCE_VISIBILITY_SCOPES.has(source_kind) and not (SOURCE_VISIBILITY_SCOPES[source_kind] as Array).has(visibility_scope_id):
		errors.append("envelope:visibility_scope_id")
	if not (envelope.get("card_record") is Dictionary):
		errors.append("envelope:card_record")
	return _result(errors)


static func is_pure_data(value: Variant) -> bool:
	if value == null or value is bool or value is int or value is String:
		return true
	if value is float:
		return is_finite(float(value))
	if value is Array:
		for item in value:
			if not is_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if not (key is String) or not is_pure_data((value as Dictionary)[key]):
				return false
		return true
	return false


static func canonical_json(value: Variant) -> String:
	if not is_pure_data(value):
		return ""
	if value == null:
		return "null"
	if value is bool or value is int or value is float or value is String:
		return JSON.stringify(value)
	if value is Array:
		var parts: Array[String] = []
		for item in value:
			parts.append(canonical_json(item))
		return "[" + ",".join(parts) + "]"
	var dictionary: Dictionary = value
	var keys: Array[String] = []
	for key in dictionary.keys():
		keys.append(str(key))
	keys.sort()
	var members: Array[String] = []
	for key in keys:
		members.append(JSON.stringify(key) + ":" + canonical_json(dictionary[key]))
	return "{" + ",".join(members) + "}"


static func fingerprint(value: Variant, omitted_key := "") -> String:
	var input: Variant = detached_copy(value)
	if not omitted_key.is_empty() and input is Dictionary:
		(input as Dictionary).erase(omitted_key)
	var canonical := canonical_json(input)
	return canonical.sha256_text() if not canonical.is_empty() else ""


static func detached_copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


static func is_stable_id(value: String) -> bool:
	if value.is_empty() or value.length() > 160:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		var valid := (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 46 or code == 95 or code == 45
		if not valid or (index == 0 and not (code >= 97 and code <= 122)):
			return false
	return true

static func _validate_identity(value: Variant, errors: Array[String]) -> void:
	if not (value is Dictionary):
		errors.append("identity:not_dictionary")
		return
	var identity: Dictionary = value
	_check_allowed_keys(identity, ["card_id", "family_id", "rank", "category_id", "available_for_acquisition"], ["industry_id"], "identity", errors)
	var card_id := str(identity.get("card_id", ""))
	var family_id := str(identity.get("family_id", ""))
	var rank := int(identity.get("rank", 0)) if _is_int_value(identity.get("rank")) else 0
	if not is_stable_id(card_id) or not is_stable_id(family_id) or card_id != "%s.rank_%d" % [family_id, rank]:
		errors.append("identity:ranked_id")
	if rank < 1 or rank > 4:
		errors.append("identity:rank")
	if not CATEGORY_IDS.has(str(identity.get("category_id", ""))):
		errors.append("identity:category_id")
	if identity.has("industry_id") and not INDUSTRY_IDS.has(str(identity.get("industry_id", ""))):
		errors.append("identity:industry_id")
	if not (identity.get("available_for_acquisition") is bool):
		errors.append("identity:available_for_acquisition")


static func _validate_cost(value: Variant, errors: Array[String]) -> void:
	if not (value is Dictionary):
		errors.append("cost:not_dictionary")
		return
	var cost: Dictionary = value
	_check_exact_keys(cost, ["acquisition", "activation"], "cost", errors)
	var acquisition: Variant = cost.get("acquisition")
	if not (acquisition is Dictionary):
		errors.append("cost:acquisition")
	else:
		_check_exact_keys(acquisition, ["acquisition_kind", "purchase_cash"], "cost.acquisition", errors)
		if not is_stable_id(str((acquisition as Dictionary).get("acquisition_kind", ""))):
			errors.append("cost:acquisition_kind")
		_validate_nonnegative_int((acquisition as Dictionary).get("purchase_cash"), "cost:purchase_cash", errors)
	var activation: Variant = cost.get("activation")
	if not (activation is Dictionary):
		errors.append("cost:activation")
	else:
		_check_exact_keys(activation, ASSET_KEYS, "cost.activation", errors)
		for key in ASSET_KEYS:
			_validate_nonnegative_int((activation as Dictionary).get(key), "cost.activation:%s" % key, errors)


static func _validate_timing(value: Variant, errors: Array[String]) -> void:
	if not (value is Dictionary):
		errors.append("timing:not_dictionary")
		return
	_check_exact_keys(value, ["timing_id"], "timing", errors)
	if not TIMING_IDS.has(str((value as Dictionary).get("timing_id", ""))):
		errors.append("timing:timing_id")


static func _validate_target(value: Variant, errors: Array[String]) -> void:
	if not (value is Dictionary):
		errors.append("target:not_dictionary")
		return
	var target: Dictionary = value
	_check_exact_keys(target, ["target_id", "selection_id", "cardinality_id", "filter_ids"], "target", errors)
	if not TARGET_IDS.has(str(target.get("target_id", ""))):
		errors.append("target:target_id")
	if not SELECTION_IDS.has(str(target.get("selection_id", ""))):
		errors.append("target:selection_id")
	if not CARDINALITY_IDS.has(str(target.get("cardinality_id", ""))):
		errors.append("target:cardinality_id")
	_validate_id_array(target.get("filter_ids"), TARGET_FILTER_IDS, "target:filter_ids", errors)


static func _validate_effect_ops(value: Variant, errors: Array[String]) -> void:
	if not (value is Array) or (value as Array).is_empty():
		errors.append("effect_ops:empty_or_invalid")
		return
	for index in range((value as Array).size()):
		_validate_effect_op_into((value as Array)[index], "effect_ops[%d]" % index, errors)


static func _validate_response(value: Variant, errors: Array[String]) -> void:
	if not (value is Dictionary):
		errors.append("response:not_dictionary")
		return
	_check_exact_keys(value, ["response_id"], "response", errors)
	if not RESPONSE_IDS.has(str((value as Dictionary).get("response_id", ""))):
		errors.append("response:response_id")


static func _validate_information_policy(value: Variant, errors: Array[String]) -> void:
	if not (value is Dictionary):
		errors.append("information_policy:not_dictionary")
		return
	_check_exact_keys(value, ["visibility_policy_id"], "information_policy", errors)
	if str((value as Dictionary).get("visibility_policy_id", "")) != "authorized_source_only":
		errors.append("information_policy:visibility_policy_id")


static func _validate_effect_op_into(value: Variant, path: String, errors: Array[String]) -> void:
	if not (value is Dictionary):
		errors.append("%s:not_dictionary" % path)
		return
	var op: Dictionary = value
	var op_id := str(op.get("op_id", ""))
	if not OP_FIELDS.has(op_id):
		errors.append("%s:op_id" % path)
		return
	_check_exact_keys(op, OP_FIELDS[op_id], path, errors)
	for key_variant in op.keys():
		var key := str(key_variant)
		if key.ends_with("_id") and not is_stable_id(str(op.get(key, ""))):
			errors.append("%s:%s" % [path, key])
	match op_id:
		"install_rate":
			if str(op.get("rate_subject_id", "")) != "card_family" or str(op.get("rate_axis_id", "")) != "production_or_demand_by_facility_kind" or str(op.get("persistence_id", "")) != "until_facility_destroyed":
				errors.append("%s:rate_policy" % path)
			if not INDUSTRY_IDS.has(str(op.get("industry_id", ""))):
				errors.append("%s:industry_id" % path)
			_validate_positive_int(op.get("rate_units_per_minute"), "%s:rate_units_per_minute" % path, errors)
			_validate_id_array(op.get("valid_facility_kind_ids"), ["factory", "market"], "%s:valid_facility_kind_ids" % path, errors)
		"build_facility", "upgrade_facility":
			var expected_condition := "facility_slot.empty_or_district_ruined" if op_id == "build_facility" else "facility.same_kind_lower_rank"
			if str(op.get("condition_id", "")) != expected_condition:
				errors.append("%s:condition_id" % path)
			_validate_facility_fields(op, path, errors)
			_validate_facility_profile(op.get("facility_profile"), str(op.get("facility_kind_id", "")), "%s:facility_profile" % path, errors)
		"repair_facility":
			if str(op.get("condition_id", "")) != "facility.same_kind_equal_or_higher_rank" or str(op.get("repair_policy_id", "")) != "established_facility_repair":
				errors.append("%s:repair_policy" % path)
			_validate_facility_fields(op, path, errors)
		"deploy_unit":
			if str(op.get("condition_id", "")) != "same_family_unit_absent" or str(op.get("stats_source_id", "")) != "unit_profile":
				errors.append("%s:deployment_policy" % path)
			_validate_unit_identity(op, path, errors)
		"upgrade_same_family_unit":
			if str(op.get("condition_id", "")) != "same_family_unit_lower_rank" or str(op.get("stats_source_id", "")) != "unit_profile":
				errors.append("%s:upgrade_policy" % path)
			_validate_unit_identity(op, path, errors)
			_validate_unit_upgrade_policy(op, path, errors)
		"extend_presence":
			if str(op.get("condition_id", "")) != "same_family_unit_present" or str(op.get("presence_time_policy_id", "")) != "add_to_remaining_time" or str(op.get("rank4_repeat_policy_id", "")) != "heal_to_full_and_extend" or op.get("refresh_total_presence_time") != false:
				errors.append("%s:presence_policy" % path)
			_validate_positive_int(op.get("duration_seconds"), "%s:duration_seconds" % path, errors)
		"heal_unit":
			if str(op.get("condition_id", "")) != "same_family_unit_present" or str(op.get("heal_policy_id", "")) != "to_full":
				errors.append("%s:heal_policy" % path)
		"modify_supply":
			_validate_supply_demand_common(op, path, errors)
			for key in ["requires_real_production_factory", "creates_one_time_physical_goods"]:
				if op.get(key) != true:
					errors.append("%s:%s" % [path, key])
			if op.get("is_permanent_installation") != false:
				errors.append("%s:is_permanent_installation" % path)
		"modify_demand":
			_validate_supply_demand_common(op, path, errors)
			if op.get("requires_real_market_node") != true or op.get("may_exceed_persistent_demand") != true:
				errors.append("%s:demand_policy" % path)
		"discard_random":
			_validate_positive_int(op.get("count"), "%s:count" % path, errors)
			_validate_nonnegative_int(op.get("target_cash_penalty"), "%s:target_cash_penalty" % path, errors)
		"steal_random":
			_validate_positive_int(op.get("count"), "%s:count" % path, errors)
			_validate_nonnegative_int(op.get("steal_fail_cash"), "%s:steal_fail_cash" % path, errors)
		"lock_random":
			_validate_positive_int(op.get("duration_seconds"), "%s:duration_seconds" % path, errors)
		"counter_action":
			_validate_positive_int(op.get("counter_strength"), "%s:counter_strength" % path, errors)
			_validate_positive_int(op.get("counter_window_seconds"), "%s:counter_window_seconds" % path, errors)
			_validate_positive_int(op.get("response_depth"), "%s:response_depth" % path, errors)
			_validate_nonnegative_int(op.get("refund_cash"), "%s:refund_cash" % path, errors)
			_validate_nonnegative_int(op.get("private_trace_count"), "%s:private_trace_count" % path, errors)
			if str(op.get("target_scope_id", "")) != "direct_player_interaction":
				errors.append("%s:target_scope_id" % path)
		"install_organization_upgrade":
			_validate_organization_op(op, path, errors)


static func _validate_facility_fields(op: Dictionary, path: String, errors: Array[String]) -> void:
	if not FACILITY_PROFILE_FIELDS.has(str(op.get("facility_kind_id", ""))):
		errors.append("%s:facility_kind_id" % path)
	if not INDUSTRY_IDS.has(str(op.get("industry_id", ""))):
		errors.append("%s:industry_id" % path)
	_validate_rank(op.get("card_rank"), "%s:card_rank" % path, errors)


static func _validate_facility_profile(value: Variant, facility_kind_id: String, path: String, errors: Array[String]) -> void:
	if not (value is Dictionary) or not FACILITY_PROFILE_FIELDS.has(facility_kind_id):
		errors.append("%s:not_dictionary_or_kind" % path)
		return
	var profile: Dictionary = value
	_check_exact_keys(profile, FACILITY_PROFILE_FIELDS[facility_kind_id], path, errors)
	if str(profile.get("profile_id", "")) != facility_kind_id:
		errors.append("%s:profile_id" % path)
	for key in ["production_capacity_units_per_minute", "demand_capacity_units_per_minute", "throughput_units_per_minute", "storage_capacity_units", "inbound_throughput_units_per_minute", "outbound_throughput_units_per_minute", "shared_hp_contribution"]:
		if profile.has(key):
			_validate_positive_int(profile.get(key), "%s:%s" % [path, key], errors)
	if profile.has("speed_multiplier") and (not (profile.get("speed_multiplier") is float or profile.get("speed_multiplier") is int) or not is_finite(float(profile.get("speed_multiplier"))) or float(profile.get("speed_multiplier")) <= 0.0):
		errors.append("%s:speed_multiplier" % path)
	if str(profile.get("shared_hp_profile_id", "")) != "equal_contribution_by_rank" or str(profile.get("rent_rate_profile_id", "")) != "pending_first_playtest_table" or profile.get("rent_enabled") != true:
		errors.append("%s:profile_policy" % path)


static func _validate_unit_identity(op: Dictionary, path: String, errors: Array[String]) -> void:
	if not ["monster", "military"].has(str(op.get("unit_kind_id", ""))):
		errors.append("%s:unit_kind_id" % path)
	if not is_stable_id(str(op.get("unit_family_id", ""))):
		errors.append("%s:unit_family_id" % path)
	_validate_rank(op.get("card_rank"), "%s:card_rank" % path, errors)


static func _validate_unit_upgrade_policy(op: Dictionary, path: String, errors: Array[String]) -> void:
	var kind := str(op.get("unit_kind_id", ""))
	if kind == "monster":
		if str(op.get("target_controller_scope_id", "")) != "any" or str(op.get("control_transfer_id", "")) != "preserve_existing_controller" or str(op.get("rank_cap_policy_id", "")) != "target_controller_organization_cap" or str(op.get("recipient_policy_id", "")) != "existing_unit_controller":
			errors.append("%s:monster_upgrade_policy" % path)
	elif kind == "military":
		if str(op.get("target_controller_scope_id", "")) != "actor" or str(op.get("control_transfer_id", "")) != "preserve_actor_control" or str(op.get("rank_cap_policy_id", "")) != "established_military_cap" or str(op.get("recipient_policy_id", "")) != "actor":
			errors.append("%s:military_upgrade_policy" % path)


static func _validate_supply_demand_common(op: Dictionary, path: String, errors: Array[String]) -> void:
	_validate_positive_int(op.get("amount_units"), "%s:amount_units" % path, errors)
	if str(op.get("allocation_basis_id", "")) != "matching_product_gdp_share_30s" or str(op.get("route_tag_match_mode_id", "")) != "any_segment_in_multimodal_route":
		errors.append("%s:allocation_policy" % path)
	if not ["near_lte_2", "remote_gt_2"].has(str(op.get("distance_rule_id", ""))) or not ["land", "sea"].has(str(op.get("required_route_tag_id", ""))):
		errors.append("%s:route_filter" % path)
	for key in ["requires_positive_controller_matching_product_gdp", "requires_real_market_or_factory_nodes", "uses_real_route_capacity"]:
		if op.get(key) != true:
			errors.append("%s:%s" % [path, key])


static func _validate_organization_op(op: Dictionary, path: String, errors: Array[String]) -> void:
	var axis := str(op.get("organization_axis_id", ""))
	if not ORGANIZATION_CAPABILITY_FIELDS.has(axis) or not is_stable_id(str(op.get("organization_family_id", ""))):
		errors.append("%s:organization_identity" % path)
	_validate_rank(op.get("organization_rank"), "%s:organization_rank" % path, errors)
	for key in ["slot_cost", "slot_limit", "activation_window_offset", "required_positive_gdp_color_count", "ordinary_submission_cost"]:
		_validate_positive_int(op.get(key), "%s:%s" % [path, key], errors)
	_validate_nonnegative_int(op.get("required_controller_gdp_min"), "%s:required_controller_gdp_min" % path, errors)
	if str(op.get("install_policy_id", "")) != "upgrade_highest_rank_only" or str(op.get("stack_policy_id", "")) != "highest_rank_nonstacking" or str(op.get("equal_or_lower_rank_resolution_id", "")) != "reject_before_consume" or str(op.get("activation_snapshot_timing_id", "")) != "next_window_start" or str(op.get("persistence_id", "")) != "run":
		errors.append("%s:organization_policy" % path)
	if op.get("replacement_requires_higher_rank") != true or op.get("counts_as_normal_card_submission") != true:
		errors.append("%s:organization_flags" % path)
	if not is_stable_id(str(op.get("public_clue_kind_id", ""))):
		errors.append("%s:public_clue_kind_id" % path)
	_validate_id_array(op.get("counterplay_tag_ids"), [], "%s:counterplay_tag_ids" % path, errors, false)
	var cap: Variant = op.get("anti_snowball_cap")
	if not (cap is Dictionary):
		errors.append("%s:anti_snowball_cap" % path)
	else:
		_check_exact_keys(cap, ["kind_id", "value"], "%s:anti_snowball_cap" % path, errors)
		if not is_stable_id(str((cap as Dictionary).get("kind_id", ""))):
			errors.append("%s:anti_snowball_cap.kind_id" % path)
		_validate_nonnegative_int((cap as Dictionary).get("value"), "%s:anti_snowball_cap.value" % path, errors)
	_validate_organization_capability(op.get("capability"), axis, "%s:capability" % path, errors)


static func _validate_organization_capability(value: Variant, axis: String, path: String, errors: Array[String]) -> void:
	if not (value is Dictionary) or not ORGANIZATION_CAPABILITY_FIELDS.has(axis):
		errors.append("%s:not_dictionary_or_axis" % path)
		return
	var capability: Dictionary = value
	_check_exact_keys(capability, ORGANIZATION_CAPABILITY_FIELDS[axis], path, errors)
	if str(capability.get("capability_id", "")) != axis:
		errors.append("%s:capability_id" % path)
	for key_variant in capability.keys():
		var key := str(key_variant)
		var field: Variant = capability[key]
		if key == "capability_id":
			continue
		if key.ends_with("_id"):
			if not is_stable_id(str(field)):
				errors.append("%s:%s" % [path, key])
		elif field is bool:
			pass
		elif not _is_int_value(field) or int(field) < 0:
			errors.append("%s:%s" % [path, key])


static func _validate_id_array(value: Variant, allowed: Array, path: String, errors: Array[String], require_allowed := true) -> void:
	if not (value is Array) or (value as Array).is_empty():
		errors.append("%s:invalid" % path)
		return
	var seen: Dictionary = {}
	for item in value:
		var id := str(item)
		if not (item is String) or not is_stable_id(id) or seen.has(id) or (require_allowed and not allowed.has(id)):
			errors.append("%s:item" % path)
			return
		seen[id] = true


static func _check_exact_keys(value: Dictionary, expected: Array, path: String, errors: Array[String]) -> void:
	var actual_keys: Array[String] = []
	for key in value.keys():
		actual_keys.append(str(key))
	var expected_keys: Array[String] = []
	for key in expected:
		expected_keys.append(str(key))
	actual_keys.sort()
	expected_keys.sort()
	if actual_keys != expected_keys:
		errors.append("%s:keys" % path)


static func _check_allowed_keys(value: Dictionary, required: Array, optional: Array, path: String, errors: Array[String]) -> void:
	for key in required:
		if not value.has(key):
			errors.append("%s:missing_%s" % [path, key])
	var allowed := required + optional
	for key in value.keys():
		if not allowed.has(str(key)):
			errors.append("%s:extra_%s" % [path, key])


static func _validate_nonnegative_int(value: Variant, path: String, errors: Array[String]) -> void:
	if not _is_int_value(value) or int(value) < 0:
		errors.append(path)


static func _validate_positive_int(value: Variant, path: String, errors: Array[String]) -> void:
	if not _is_int_value(value) or int(value) <= 0:
		errors.append(path)


static func _validate_rank(value: Variant, path: String, errors: Array[String]) -> void:
	if not _is_int_value(value) or int(value) < 1 or int(value) > 4:
		errors.append(path)


static func _is_int_value(value: Variant) -> bool:
	return value is int


static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


static func _result(errors: Array) -> Dictionary:
	return {"valid": errors.is_empty(), "errors": errors.duplicate()}