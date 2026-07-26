extends Node
class_name AiCardSemanticProjectionBench

const COMPILER := preload("res://scripts/cards/semantic/card_semantic_compiler_v1.gd")
const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"

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
		for op_variant in scenario.get("ops", []) as Array:
			seen_ops.append(str(op_variant))
		var candidates := service.project_candidates(
			fixture.get("spec", {}) as Dictionary,
			fixture.get("instance", {}) as Dictionary,
			fixture.get("world", {}) as Dictionary
		)
		var spec := fixture.get("spec", {}) as Dictionary
		if str(spec.get("runtime_readiness_id", "")) != "active":
			_check(
				candidates.is_empty(),
				"representative_%s_projection_only" % scenario.get("id", "")
			)
			_check(fixture == before, "zero_input_mutation_%s" % scenario.get("id", ""))
			continue
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
	var projection_only_spec := interaction_fixture.get("spec", {}) as Dictionary
	var instance := interaction_fixture.get("instance", {}) as Dictionary
	var interaction_world := interaction_fixture.get("world", {}) as Dictionary
	_check(
		service.project_candidates(
			projection_only_spec, instance, interaction_world
		).is_empty(),
		"catalog_projection_only_never_emits_legal_candidate"
	)
	for readiness_id in ["active", "not_acquirable"]:
		var non_executable_spec := projection_only_spec.duplicate(true)
		non_executable_spec["runtime_readiness_id"] = readiness_id
		refingerprint_spec(non_executable_spec)
		var rebound_world := interaction_world.duplicate(true)
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

	var active_fixture := make_case(representative_scenarios()[0] as Dictionary)
	var active_spec := active_fixture.get("spec", {}) as Dictionary
	var active_instance := active_fixture.get("instance", {}) as Dictionary
	var active_world := active_fixture.get("world", {}) as Dictionary
	var zero_risk_world := active_world.duplicate(true)
	var target := (zero_risk_world.get("legal_targets", []) as Array)[0] as Dictionary
	target["counter_risk"] = 0
	refingerprint_target(target)
	refingerprint_world(zero_risk_world)
	var zero_risk_candidates := service.project_candidates(
		active_spec, active_instance, zero_risk_world
	)
	_check(zero_risk_candidates.size() == 1, "registered_active_zero_risk_candidate_emitted")
	if zero_risk_candidates.size() == 1:
		var candidate := zero_risk_candidates[0] as Dictionary
		_check(int(candidate.get("counter_risk", -1)) == 0, "registered_active_has_no_fixed_risk")
		_check(
			int((candidate.get("projected_outcomes", {}) as Dictionary).get(
				"counter_risk", -1
			)) == 0,
			"registered_active_outcome_has_no_fixed_risk"
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
	var card_id := _representative_card_id(scenario_id)
	var source_kind := str(scenario.get("source_kind", "own_hand"))
	var source_slot := 3
	var instance_revision := 7
	var world_revision := 101
	var spec := _registered_spec(card_id)
	var target_id := str(
		(spec.get("target", {}) as Dictionary).get("target_id", "")
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
			"target_id": target_id,
			"target_identity": {
				"schema_version": 1,
				"target_id": target_id,
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


static func _representative_card_id(scenario_id: String) -> String:
	match scenario_id:
		"install_rate":
			return "commodity.star_dew_berry.rank_1"
		"build_facility", "upgrade_facility", "repair_facility":
			return "facility.factory.life.rank_1"
		"deploy_unit":
			return "unit.monster.spore_tide_emperor.rank_1"
		"upgrade_unit":
			return "unit.military.planetary_defense_force.rank_1"
		"modify_supply":
			return "supply_demand.near_land_supply.rank_1"
		"modify_demand":
			return "supply_demand.remote_sea_order.rank_1"
		"discard", "lock":
			return "interaction.starlink_dismantle.rank_1"
		"steal":
			return "interaction.shadow_warehouse_traction.rank_1"
		"counter":
			return "interaction.phase_veto.rank_1"
	return ""


static func _registered_spec(card_id: String) -> Dictionary:
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	if catalog == null or not bool(catalog.reload().get("valid", false)):
		return {}
	var snapshot := catalog.catalog_snapshot()
	var record := catalog.card_snapshot(card_id)
	var result := COMPILER.new().compile_card_record(
		record,
		str(snapshot.get("catalog_id", ""))
	)
	return (result.get("spec", {}) as Dictionary).duplicate(true) \
		if bool(result.get("ok", false)) else {}


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
