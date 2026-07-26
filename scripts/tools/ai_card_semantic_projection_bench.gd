extends Node
class_name AiCardSemanticProjectionBench

var bench_status := "RUNNING"
var check_count := 0
var failure_count := 0
var representative_candidate_count := 0
var debug_counters_snapshot := {}
var debug_counter_count := 0
var non_executable_readiness_count := 0
var _failures: Array[String] = []


func _ready() -> void:
	await _run()


func _run() -> void:
	var service := get_node_or_null(
		"AiCardSemanticProjectionService"
	) as AiCardSemanticProjectionService
	_check(service != null, "service_scene_dependency")
	if service == null:
		await _finish()
		return

	var seen_ops: Array[String] = []
	for scenario_variant in representative_scenarios():
		var scenario := scenario_variant as Dictionary
		var fixture := make_case(scenario)
		var before := fixture.duplicate(true)
		var candidates := service.project_candidates(
			fixture.get("spec", {}) as Dictionary,
			fixture.get("instance", {}) as Dictionary,
			fixture.get("world", {}) as Dictionary
		)
		_check(candidates.size() == 1, "representative_%s" % scenario.get("id", ""))
		if candidates.size() != 1:
			continue
		representative_candidate_count += 1
		var candidate := candidates[0] as Dictionary
		_check(
			candidate.keys() == AiCardSemanticProjectionService.CANDIDATE_KEYS,
			"candidate_schema_%s" % scenario.get("id", "")
		)
		_check(
			(candidate.get("projected_outcomes", {}) as Dictionary).keys()
				== AiCardSemanticProjectionService.OUTCOME_DIMENSIONS,
			"outcome_schema_%s" % scenario.get("id", "")
		)
		_check(
			bool(candidate.get("legal", false))
				and str(candidate.get("rejection_reason_id", "")) == "none"
				and str(candidate.get("information_scope_id", "")) == "actor_private",
			"legal_private_candidate_%s" % scenario.get("id", "")
		)
		_check(
			(candidate.get("activation_cost", {}) as Dictionary).keys()
				== AiCardSemanticProjectionService.ACTIVATION_COST_KEYS
				and not candidate.has("acquisition_cost")
				and not candidate.has("ai_value"),
			"neutral_cost_boundary_%s" % scenario.get("id", "")
		)
		_check(
			str(candidate.get("candidate_fingerprint", "")).length() == 64
				and str(candidate.get("candidate_fingerprint", ""))
					== AiCardSemanticProjectionService.fingerprint_record(
						candidate,
						"candidate_fingerprint"
					),
			"candidate_fingerprint_%s" % scenario.get("id", "")
		)
		_check(
			TablePresentationPureDataPolicy.is_pure_data(candidate),
			"pure_candidate_%s" % scenario.get("id", "")
		)
		_check(fixture == before, "zero_input_mutation_%s" % scenario.get("id", ""))
		for op_variant in scenario.get("ops", []) as Array:
			var op_id := str(op_variant)
			seen_ops.append(op_id)
			_check(
				(candidate.get("explanation_tokens", []) as Array).has(
					"semantic.op.%s" % op_id
				),
				"op_token_%s" % op_id
			)

	for required_op in representative_op_ids():
		_check(seen_ops.has(required_op), "representative_coverage_%s" % required_op)

	_run_determinism_checks(service)
	_run_negative_checks(service)
	_run_readiness_and_counterability_checks(service)
	_run_source_checks(service)
	var counters := service.debug_counters()
	debug_counters_snapshot = counters.duplicate(true)
	debug_counter_count = counters.size()
	non_executable_readiness_count = int(
		counters.get("non_executable_readiness_count", -1)
	)
	_check(counters.size() == 10, "debug_counter_schema")
	for value_variant in counters.values():
		_check(value_variant is int, "debug_values_are_counts_only")
	_check(
		int(counters.get("candidate_emission_count", 0)) >= representative_candidate_count,
		"debug_emission_count"
	)
	await _finish()


func _run_determinism_checks(service: AiCardSemanticProjectionService) -> void:
	var scenario := representative_scenarios()[0] as Dictionary
	var fixture := make_case(scenario, ["facility.zeta", "facility.alpha"])
	var first := service.project_candidates(
		fixture.get("spec", {}) as Dictionary,
		fixture.get("instance", {}) as Dictionary,
		fixture.get("world", {}) as Dictionary
	)
	var second := service.project_candidates(
		fixture.get("spec", {}) as Dictionary,
		fixture.get("instance", {}) as Dictionary,
		fixture.get("world", {}) as Dictionary
	)
	_check(first == second and first.size() == 2, "deterministic_repeat")
	if first.size() == 2:
		_check(
			str(((first[0] as Dictionary).get("target_identity", {}) as Dictionary).get(
				"stable_id",
				""
			)) == "facility.alpha"
				and str(((first[1] as Dictionary).get("target_identity", {}) as Dictionary).get(
					"stable_id",
					""
				)) == "facility.zeta",
			"deterministic_target_order"
		)
		(first[0] as Dictionary)["action_id"] = "mutated.copy"
		var detached_again := service.project_candidates(
			fixture.get("spec", {}) as Dictionary,
			fixture.get("instance", {}) as Dictionary,
			fixture.get("world", {}) as Dictionary
		)
		_check(
			str((detached_again[0] as Dictionary).get("action_id", "")) != "mutated.copy",
			"detached_candidate_copy"
		)


func _run_negative_checks(service: AiCardSemanticProjectionService) -> void:
	var fixture := make_case(representative_scenarios()[0] as Dictionary)
	var spec := fixture.get("spec", {}) as Dictionary
	var instance := fixture.get("instance", {}) as Dictionary
	var world := fixture.get("world", {}) as Dictionary

	var unknown_op := spec.duplicate(true)
	((unknown_op.get("effect_ops", []) as Array)[0] as Dictionary)["op_id"] = "future_unknown_op"
	refingerprint_spec(unknown_op)
	_check(service.project_candidates(unknown_op, instance, world).is_empty(), "unknown_op_rejected")

	var unknown_field := spec.duplicate(true)
	((unknown_field.get("effect_ops", []) as Array)[0] as Dictionary)["unexpected_field"] = 1
	refingerprint_spec(unknown_field)
	_check(service.project_candidates(unknown_field, instance, world).is_empty(), "unknown_op_field_rejected")

	var malformed := spec.duplicate(true)
	malformed.erase("target")
	_check(service.project_candidates(malformed, instance, world).is_empty(), "malformed_spec_rejected")

	var unauthorized := world.duplicate(true)
	unauthorized["visibility_scope_id"] = "actor_private"
	refingerprint_world(unauthorized)
	_check(service.project_candidates(spec, instance, unauthorized).is_empty(), "public_scope_forgery_rejected")

	var rival_private := world.duplicate(true)
	rival_private["rival_private"] = {"hand": ["secret.card"]}
	refingerprint_world(rival_private)
	_check(service.project_candidates(spec, instance, rival_private).is_empty(), "rival_private_rejected")

	var hidden_owner := world.duplicate(true)
	var hidden_targets := hidden_owner.get("legal_targets", []) as Array
	((hidden_targets[0] as Dictionary).get("target_identity", {}) as Dictionary)["hidden_owner"] = "actor.rival"
	refingerprint_target(hidden_targets[0] as Dictionary)
	refingerprint_world(hidden_owner)
	_check(service.project_candidates(spec, instance, hidden_owner).is_empty(), "hidden_owner_rejected")

	var future_bag := world.duplicate(true)
	future_bag["future_bag_keys"] = ["future.card"]
	refingerprint_world(future_bag)
	_check(service.project_candidates(spec, instance, future_bag).is_empty(), "future_bag_rejected")

	var stale_instance := instance.duplicate(true)
	stale_instance["instance_revision"] = int(stale_instance.get("instance_revision", 0)) + 1
	_check(service.project_candidates(spec, stale_instance, world).is_empty(), "stale_instance_rejected")

	var stale_world := world.duplicate(true)
	stale_world["world_revision"] = int(stale_world.get("world_revision", 0)) + 1
	refingerprint_world(stale_world)
	_check(service.project_candidates(spec, instance, stale_world).is_empty(), "stale_world_rejected")

	var stale_legality := world.duplicate(true)
	var stale_target := (stale_legality.get("legal_targets", []) as Array)[0] as Dictionary
	(stale_target.get("explanation_tokens", []) as Array).append("semantic.fact.changed")
	refingerprint_world(stale_legality)
	_check(service.project_candidates(spec, instance, stale_legality).is_empty(), "stale_legality_rejected")

	var no_proof := world.duplicate(true)
	no_proof["legal_targets"] = []
	refingerprint_world(no_proof)
	_check(service.project_candidates(spec, instance, no_proof).is_empty(), "missing_legal_proof_fails_closed")

	var wrong_target := world.duplicate(true)
	var wrong_fact := (wrong_target.get("legal_targets", []) as Array)[0] as Dictionary
	wrong_fact["target_id"] = "district.active"
	var wrong_identity := wrong_fact.get("target_identity", {}) as Dictionary
	wrong_identity["target_id"] = "district.active"
	wrong_identity["stable_id"] = "district.1"
	refingerprint_target(wrong_fact)
	refingerprint_world(wrong_target)
	_check(service.project_candidates(spec, instance, wrong_target).is_empty(), "target_contract_mismatch_rejected")

	for unavailable_key in ["queued", "locked"]:
		var unavailable := instance.duplicate(true)
		unavailable[unavailable_key] = true
		_check(
			service.project_candidates(spec, unavailable, world).is_empty(),
			"%s_instance_rejected" % unavailable_key
		)
	var cooling := instance.duplicate(true)
	cooling["cooldown_remaining_seconds"] = 0.25
	_check(service.project_candidates(spec, cooling, world).is_empty(), "cooldown_instance_rejected")

	var impure := instance.duplicate(true)
	var forbidden_node := Node.new()
	impure["forbidden_object"] = forbidden_node
	_check(service.project_candidates(spec, impure, world).is_empty(), "object_input_rejected")
	forbidden_node.free()

	var ai_value_spec := spec.duplicate(true)
	((ai_value_spec.get("effect_ops", []) as Array)[0] as Dictionary)["ai_value"] = 999
	refingerprint_spec(ai_value_spec)
	_check(service.project_candidates(ai_value_spec, instance, world).is_empty(), "ai_value_rejected")


func _run_readiness_and_counterability_checks(
	service: AiCardSemanticProjectionService
) -> void:
	var interaction_fixture := make_case(representative_scenarios()[8] as Dictionary)
	var active_spec := interaction_fixture.get("spec", {}) as Dictionary
	var instance := interaction_fixture.get("instance", {}) as Dictionary
	var active_world := interaction_fixture.get("world", {}) as Dictionary
	for readiness_id in ["projection_only", "not_acquirable"]:
		var non_executable_spec := active_spec.duplicate(true)
		non_executable_spec["runtime_readiness_id"] = readiness_id
		refingerprint_spec(non_executable_spec)
		var rebound_world := active_world.duplicate(true)
		rebound_world["semantic_fingerprint"] = str(
			non_executable_spec.get("semantic_fingerprint", "")
		)
		refingerprint_world(rebound_world)
		_check(
			service.project_candidates(
				non_executable_spec, instance, rebound_world
			).is_empty(),
			"%s_never_emits_legal_candidate" % readiness_id
		)

	var zero_risk_world := active_world.duplicate(true)
	var target := (zero_risk_world.get("legal_targets", []) as Array)[0] as Dictionary
	target["counter_risk"] = 0
	refingerprint_target(target)
	refingerprint_world(zero_risk_world)
	var zero_risk_candidates := service.project_candidates(
		active_spec, instance, zero_risk_world
	)
	_check(zero_risk_candidates.size() == 1, "counterable_zero_risk_candidate_emitted")
	if zero_risk_candidates.size() == 1:
		var candidate := zero_risk_candidates[0] as Dictionary
		_check(int(candidate.get("counter_risk", -1)) == 0, "counterable_has_no_fixed_risk")
		_check(
			int((candidate.get("projected_outcomes", {}) as Dictionary).get(
				"counter_risk", -1
			)) == 0,
			"counterable_outcome_has_no_fixed_risk"
		)
		_check(
			(candidate.get("explanation_tokens", []) as Array).has(
				"semantic.response.counterable"
			),
			"counterable_explanation_is_semantic_only"
		)


func _run_source_checks(_service: AiCardSemanticProjectionService) -> void:
	var service_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/ai_card_semantic_projection_service.gd"
	)
	var source := service_source + FileAccess.get_file_as_string(
		"res://scripts/runtime/ai_card_semantic_projection_input_v1.gd"
	) + FileAccess.get_file_as_string(
		"res://scripts/runtime/ai_outcome_vector_v1.gd"
	)
	for forbidden in [
		"/root/" + "Main",
		"current_" + "scene",
		".call(",
		"has_method(",
		"get_tree(",
		"= load(",
		"ResourceLoader.load(",
		"randf(",
		"randi(",
		"card_runtime_catalog_v06.json",
		"ai_runtime_controller.gd",
	]:
		_check(not source.contains(forbidden), "source_forbids_%s" % forbidden)
	_check(not source.contains("func _process("), "no_process_loop")
	_check(not source.contains("func _physics_process("), "no_physics_loop")
	_check(not source.contains("enumerate_catalog"), "no_catalog_enumeration_api")
	_check(not source.contains("lookup_card"), "no_card_id_lookup_api")
	_check(
		service_source.contains(
			"res://scripts/cards/semantic/card_semantic_schema_v1.gd"
		),
		"shared_semantic_schema_preloaded"
	)
	for duplicate_schema_symbol in [
		"const SPEC_KEYS", "const CATEGORY_IDS", "const OP_FIELDS",
		"const FACILITY_PROFILE_FIELDS", "const ORGANIZATION_CAPABILITY_FIELDS",
		"func _valid_semantic_spec", "func semantic_spec_error",
	]:
		_check(
			not source.contains(duplicate_schema_symbol),
			"no_duplicate_%s" % duplicate_schema_symbol.to_snake_case()
		)
	_check(not source.contains("response_counter_risk"), "no_fixed_counter_risk_prior")


func _check(condition: bool, label: String) -> void:
	check_count += 1
	if condition:
		return
	_failures.append(label)
	failure_count = _failures.size()
	push_error("AI_CARD_SEMANTIC_PROJECTION_BENCH: %s" % label)


func _finish() -> void:
	failure_count = _failures.size()
	bench_status = "PASS" if _failures.is_empty() else "FAIL"
	print(
		"AI_CARD_SEMANTIC_PROJECTION_BENCH|status=%s|checks=%d|failures=%d|representative_candidates=%d"
		% [bench_status, check_count, failure_count, representative_candidate_count]
	)
	var hold_seconds := 0.1 if DisplayServer.get_name() == "headless" else 30.0
	await get_tree().create_timer(hold_seconds).timeout
	get_tree().quit(0 if _failures.is_empty() else 1)


static func representative_op_ids() -> Array[String]:
	return [
		"install_rate",
		"build_facility",
		"upgrade_facility",
		"repair_facility",
		"deploy_unit",
		"upgrade_same_family_unit",
		"modify_supply",
		"modify_demand",
		"discard_random",
		"steal_random",
		"lock_random",
		"counter_action",
	]


static func representative_scenarios() -> Array:
	return [
		_scenario("install_rate", ["install_rate"], "facility.same_industry", "public_rack"),
		_scenario("build_facility", ["build_facility"], "district.active"),
		_scenario("upgrade_facility", ["upgrade_facility"], "facility.same_industry"),
		_scenario("repair_facility", ["repair_facility"], "facility.same_industry"),
		_scenario("deploy_unit", ["deploy_unit"], "unit.same_family"),
		_scenario("upgrade_unit", ["upgrade_same_family_unit"], "unit.same_family"),
		_scenario("modify_supply", ["modify_supply"], "world.global"),
		_scenario("modify_demand", ["modify_demand"], "world.global"),
		_scenario(
			"discard", ["discard_random"], "player.opponent",
			"own_hand", "main_action", "counterable"
		),
		_scenario(
			"steal", ["steal_random"], "player.opponent",
			"own_hand", "main_action", "counterable"
		),
		_scenario(
			"lock", ["lock_random"], "player.opponent",
			"own_hand", "main_action", "counterable"
		),
		_scenario(
			"counter",
			["counter_action"],
			"response.incoming_direct_interaction",
			"response_window",
			"response_window",
			"counter"
		),
	]


static func _scenario(
	scenario_id: String,
	ops: Array,
	target_id: String,
	source_kind := "own_hand",
	timing_id := "main_action",
	response_id := "none"
) -> Dictionary:
	return {
		"id": scenario_id,
		"ops": ops.duplicate(),
		"target_id": target_id,
		"source_kind": source_kind,
		"timing_id": timing_id,
		"response_id": response_id,
	}


static func make_case(scenario: Dictionary, target_ids: Array = []) -> Dictionary:
	var scenario_id := str(scenario.get("id", "fixture"))
	var card_id := "fixture.%s.rank_2" % scenario_id
	var source_kind := str(scenario.get("source_kind", "own_hand"))
	var source_slot := 3
	var instance_revision := 7
	var world_revision := 101
	var spec := make_spec(
		card_id,
		scenario.get("ops", []) as Array,
		str(scenario.get("target_id", "world.global")),
		str(scenario.get("timing_id", "main_action")),
		str(scenario.get("response_id", "none")),
		source_kind == "public_rack"
	)
	var instance := {
		"schema_version": 1,
		"instance_id": "instance.%s" % scenario_id,
		"card_id": card_id,
		"source_slot": source_slot,
		"instance_revision": instance_revision,
		"queued": false,
		"locked": false,
		"cooldown_remaining_seconds": 0.0,
	}
	var source_revision := JSON.stringify([
		"authorized_source_v1",
		scenario_id,
		source_kind,
	]).sha256_text()
	var stable_targets := target_ids.duplicate()
	if stable_targets.is_empty():
		stable_targets.append("target.%s" % scenario_id)
	var legal_targets: Array = []
	for stable_id_variant in stable_targets:
		var target_fact := {
			"schema_version": 1,
			"target_id": str(scenario.get("target_id", "world.global")),
			"target_identity": {
				"schema_version": 1,
				"target_id": str(scenario.get("target_id", "world.global")),
				"stable_id": str(stable_id_variant),
			},
			"status_id": "legal",
			"source_revision": source_revision,
			"instance_revision": instance_revision,
			"world_revision": world_revision,
			"uncertainty": 3,
			"counter_risk": 5,
			"outcome_adjustments": zero_outcome_adjustments(),
			"explanation_tokens": ["semantic.fact.fixture_authorized"],
			"legality_fingerprint": "",
		}
		refingerprint_target(target_fact)
		legal_targets.append(target_fact)
	var world := {
		"schema_version": 1,
		"projection_id": "world_projection.%s" % scenario_id,
		"viewer_actor_id": "actor.ai.1",
		"visibility_scope_id": "public"
			if source_kind in ["public_rack", "public_reveal"] else "actor_private",
		"source_kind": source_kind,
		"source_revision": source_revision,
		"semantic_fingerprint": str(spec.get("semantic_fingerprint", "")),
		"card_id": card_id,
		"instance_id": str(instance.get("instance_id", "")),
		"source_slot": source_slot,
		"instance_revision": instance_revision,
		"world_revision": world_revision,
		"legal_targets": legal_targets,
		"projection_fingerprint": "",
	}
	refingerprint_world(world)
	return {"spec": spec, "instance": instance, "world": world}


static func make_spec(
	card_id: String,
	ops: Array,
	target_id: String,
	timing_id: String,
	response_id: String,
	available_for_acquisition: bool
) -> Dictionary:
	var effect_ops: Array = []
	for op_variant in ops:
		effect_ops.append(make_effect_op(str(op_variant)))
	var family_id := card_id.trim_suffix(".rank_2")
	var first_op_id := str(ops[0]) if not ops.is_empty() else ""
	var spec := {
		"schema_version": 1,
		"source_catalog_id": "card_runtime_catalog_v06",
		"source_definition_fingerprint": JSON.stringify([
			"authorized_definition_v1",
			card_id,
		]).sha256_text(),
		"semantic_fingerprint": "",
		"identity": {
			"card_id": card_id,
			"family_id": family_id,
			"rank": 2,
			"category_id": category_for_op(first_op_id),
			"industry_id": "energy",
			"available_for_acquisition": available_for_acquisition,
		},
		"cost": {
			"acquisition": {
				"acquisition_kind": "dynamic_market_cash",
				"purchase_cash": 12,
			},
			"activation": {
				"life": 0,
				"energy": 0,
				"industry": 0,
				"technology": 0,
				"commerce": 1,
				"shipping": 0,
				"generic": 1,
			},
		},
		"timing": {"timing_id": timing_id},
		"target": {
			"target_id": target_id,
			"selection_id": target_selection_id(target_id),
			"cardinality_id": target_cardinality_id(target_id),
			"filter_ids": target_filter_ids(target_id, first_op_id),
		},
		"effect_ops": effect_ops,
		"response": {"response_id": response_id},
		"information_policy": {"visibility_policy_id": "authorized_source_only"},
		"runtime_readiness_id": "active",
	}
	refingerprint_spec(spec)
	return spec


static func make_effect_op(op_id: String) -> Dictionary:
	match op_id:
		"install_rate":
			return {
				"op_id": op_id,
				"rate_subject_id": "card_family",
				"rate_axis_id": "production_or_demand_by_facility_kind",
				"industry_id": "energy",
				"rate_units_per_minute": 2,
				"valid_facility_kind_ids": ["factory", "market"],
				"persistence_id": "until_facility_destroyed",
			}
		"build_facility", "upgrade_facility":
			return {
				"op_id": op_id,
				"condition_id": "facility_slot.empty_or_district_ruined"
					if op_id == "build_facility" else "facility.same_kind_lower_rank",
				"facility_kind_id": "factory",
				"industry_id": "energy",
				"card_rank": 2,
				"facility_profile": {
					"profile_id": "factory",
					"production_capacity_units_per_minute": 2,
					"shared_hp_contribution": 1,
					"shared_hp_profile_id": "equal_contribution_by_rank",
					"rent_enabled": true,
					"rent_rate_profile_id": "pending_first_playtest_table",
				},
			}
		"repair_facility":
			return {
				"op_id": op_id,
				"condition_id": "facility.same_kind_equal_or_higher_rank",
				"facility_kind_id": "factory",
				"industry_id": "energy",
				"card_rank": 2,
				"repair_policy_id": "established_facility_repair",
			}
		"deploy_unit":
			return {
				"op_id": op_id,
				"condition_id": "same_family_unit_absent",
				"unit_kind_id": "military",
				"unit_family_id": "fixture.unit",
				"card_rank": 2,
				"stats_source_id": "unit_profile",
			}
		"upgrade_same_family_unit":
			return {
				"op_id": op_id,
				"condition_id": "same_family_unit_lower_rank",
				"unit_kind_id": "military",
				"unit_family_id": "fixture.unit",
				"card_rank": 2,
				"target_controller_scope_id": "actor",
				"control_transfer_id": "preserve_actor_control",
				"rank_cap_policy_id": "established_military_cap",
				"recipient_policy_id": "actor",
				"stats_source_id": "unit_profile",
			}
		"extend_presence":
			return {
				"op_id": op_id,
				"condition_id": "same_family_unit_present",
				"duration_seconds": 60,
				"presence_time_policy_id": "add_to_remaining_time",
				"refresh_total_presence_time": false,
				"rank4_repeat_policy_id": "heal_to_full_and_extend",
			}
		"heal_unit":
			return {
				"op_id": op_id,
				"condition_id": "same_family_unit_present",
				"heal_policy_id": "to_full",
			}
		"modify_supply":
			return {
				"op_id": op_id,
				"amount_units": 2,
				"allocation_basis_id": "matching_product_gdp_share_30s",
				"distance_rule_id": "near_lte_2",
				"required_route_tag_id": "land",
				"route_tag_match_mode_id": "any_segment_in_multimodal_route",
				"requires_positive_controller_matching_product_gdp": true,
				"requires_real_market_or_factory_nodes": true,
				"requires_real_production_factory": true,
				"uses_real_route_capacity": true,
				"creates_one_time_physical_goods": true,
				"is_permanent_installation": false,
			}
		"modify_demand":
			return {
				"op_id": op_id,
				"amount_units": 2,
				"allocation_basis_id": "matching_product_gdp_share_30s",
				"distance_rule_id": "remote_gt_2",
				"required_route_tag_id": "sea",
				"route_tag_match_mode_id": "any_segment_in_multimodal_route",
				"requires_positive_controller_matching_product_gdp": true,
				"requires_real_market_or_factory_nodes": true,
				"requires_real_market_node": true,
				"uses_real_route_capacity": true,
				"may_exceed_persistent_demand": true,
			}
		"discard_random":
			return {"op_id": op_id, "count": 1, "target_cash_penalty": 0}
		"steal_random":
			return {"op_id": op_id, "count": 1, "steal_fail_cash": 0}
		"lock_random":
			return {"op_id": op_id, "duration_seconds": 5}
		"counter_action":
			return {
				"op_id": op_id,
				"counter_strength": 1,
				"counter_window_seconds": 5,
				"response_depth": 1,
				"target_scope_id": "direct_player_interaction",
				"refund_cash": 0,
				"private_trace_count": 0,
			}
	return {"op_id": op_id}


static func category_for_op(op_id: String) -> String:
	if op_id == "install_rate":
		return "commodity"
	if op_id in ["build_facility", "upgrade_facility", "repair_facility"]:
		return "facility"
	if op_id in ["modify_supply", "modify_demand", "global_order", "global_supply_spawn"]:
		return "supply_demand"
	if op_id in ["deploy_unit", "upgrade_same_family_unit", "extend_presence", "heal_unit"]:
		return "military"
	if op_id == "install_organization_upgrade":
		return "organization"
	return "interaction"


static func target_selection_id(target_id: String) -> String:
	if target_id == "response.incoming_direct_interaction":
		return "trigger_context"
	if target_id == "world.global":
		return "automatic"
	return "actor_choice"


static func target_cardinality_id(target_id: String) -> String:
	return "all_matching" if target_id == "world.global" else "exactly_one"


static func target_filter_ids(target_id: String, op_id: String) -> Array:
	match target_id:
		"facility.same_industry":
			return ["facility.kind.factory_or_market", "industry.same_as_card"]
		"district.active":
			return [
				"district.state.active_or_undeveloped_or_ruined",
				"facility.slot.unique_by_kind",
			]
		"unit.same_family":
			return ["unit.kind.military", "unit.region_or_same_family", "unit.controller.actor"]
		"player.opponent":
			return ["hand.discardable"]
		"response.incoming_direct_interaction":
			return ["interaction.direct"]
		"world.global":
			return ["world.matching_factories"] \
				if op_id == "modify_supply" else ["world.matching_goods"]
		"organization.self_slot":
			return ["organization.slot.available_or_same_family"]
	return []


static func zero_outcome_adjustments() -> Dictionary:
	var result := {}
	for dimension in AiCardSemanticProjectionService.OUTCOME_DIMENSIONS:
		result[dimension] = 0
	return result


static func refingerprint_spec(spec: Dictionary) -> void:
	spec["semantic_fingerprint"] = AiCardSemanticProjectionService.fingerprint_record(
		spec,
		"semantic_fingerprint"
	)


static func refingerprint_target(target: Dictionary) -> void:
	target["legality_fingerprint"] = AiCardSemanticProjectionService.fingerprint_record(
		target,
		"legality_fingerprint"
	)


static func refingerprint_world(world: Dictionary) -> void:
	world["projection_fingerprint"] = AiCardSemanticProjectionService.fingerprint_record(
		world,
		"projection_fingerprint"
	)
