extends SceneTree

const SERVICE_SCENE := preload(
	"res://scenes/runtime/AiCardSemanticProjectionService.tscn"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var service := SERVICE_SCENE.instantiate() as AiCardSemanticProjectionService
	root.add_child(service)
	await process_frame
	_expect(service != null, "service scene instantiates")
	if service == null:
		_finish()
		return

	_test_representative_candidates(service)
	_test_determinism_and_detachment(service)
	_test_provenance_and_revision_failures(service)
	_test_schema_and_privacy_failures(service)
	_test_instance_availability(service)
	_test_readiness_and_counterability(service)
	_test_debug_boundary(service)
	_test_bounded_projection_cost(service)
	service.queue_free()
	await process_frame
	_finish()


func _test_representative_candidates(
	service: AiCardSemanticProjectionService
) -> void:
	var expected_dimensions := {
		"install_rate": {"self_economy": 1, "route_control": 1},
		"build_facility": {"self_economy": 1, "board_control": 1, "defense": 1},
		"upgrade_facility": {"self_economy": 1, "board_control": 1, "tempo": 1},
		"repair_facility": {"self_economy": 1, "tempo": 1, "defense": 1},
		"deploy_unit": {"board_control": 1, "tempo": 1, "defense": 1},
		"upgrade_same_family_unit": {"board_control": 1, "defense": 1},
		"modify_supply": {"self_economy": 1, "route_control": 1, "variance": 1},
		"modify_demand": {"self_economy": 1, "victory_progress": 1, "variance": 1},
		"discard_random": {"opponent_economy": -1, "hand_advantage": 1, "tempo": 1},
		"steal_random": {"opponent_economy": -1, "hand_advantage": 2, "variance": 1},
		"lock_random": {"hand_advantage": 1, "tempo": 1, "variance": 1},
		"counter_action": {"tempo": 1, "defense": 1},
	}
	var emitted_ops: Array[String] = []
	for scenario_variant in AiCardSemanticProjectionBench.representative_scenarios():
		var scenario := scenario_variant as Dictionary
		var fixture := AiCardSemanticProjectionBench.make_case(scenario)
		var fixture_before := fixture.duplicate(true)
		var candidates := service.project_candidates(
			fixture.get("spec", {}) as Dictionary,
			fixture.get("instance", {}) as Dictionary,
			fixture.get("world", {}) as Dictionary
		)
		_expect(
			candidates.size() == 1,
			"representative scenario %s emits one proven target"
				% scenario.get("id", "")
		)
		if candidates.size() != 1:
			continue
		var candidate := candidates[0] as Dictionary
		_expect(
			candidate.keys() == AiCardSemanticProjectionService.CANDIDATE_KEYS,
			"candidate uses the frozen exact schema"
		)
		var outcomes := candidate.get("projected_outcomes", {}) as Dictionary
		_expect(
			outcomes.keys() == AiCardSemanticProjectionService.OUTCOME_DIMENSIONS,
			"projected outcome uses exactly eleven neutral dimensions"
		)
		_expect(
			str(candidate.get("information_scope_id", "")) == "actor_private"
				and bool(candidate.get("legal", false))
				and str(candidate.get("rejection_reason_id", "")) == "none",
			"candidate is actor-private and legality-proof backed"
		)
		_expect(
			(candidate.get("activation_cost", {}) as Dictionary).keys()
				== AiCardSemanticProjectionService.ACTIVATION_COST_KEYS,
			"candidate carries only detached activation cost"
		)
		_expect(
			not candidate.has("ai_value")
				and not _contains_key_recursive(candidate, "score")
				and not _contains_key_recursive(candidate, "weight"),
			"candidate carries no AI scalar or policy weight"
		)
		_expect(
			TablePresentationPureDataPolicy.is_pure_data(candidate),
			"candidate is detached pure data"
		)
		_expect(fixture == fixture_before, "projection does not mutate any input")
		for op_variant in scenario.get("ops", []) as Array:
			var op_id := str(op_variant)
			emitted_ops.append(op_id)
			_expect(
				(candidate.get("explanation_tokens", []) as Array).has(
					"semantic.op.%s" % op_id
				),
				"candidate exposes a stable explanation token for %s" % op_id
			)
			var expected := expected_dimensions.get(op_id, {}) as Dictionary
			for dimension_variant in expected.keys():
				var dimension := str(dimension_variant)
				_expect(
					int(outcomes.get(dimension, 0)) == int(expected.get(dimension, 0)),
					"%s projects neutral %s" % [op_id, dimension]
				)
	for required_op in AiCardSemanticProjectionBench.representative_op_ids():
		_expect(emitted_ops.has(required_op), "representative op %s covered" % required_op)


func _test_determinism_and_detachment(
	service: AiCardSemanticProjectionService
) -> void:
	var scenario := AiCardSemanticProjectionBench.representative_scenarios()[0] as Dictionary
	var fixture := AiCardSemanticProjectionBench.make_case(
		scenario,
		["facility.zeta", "facility.alpha", "facility.middle"]
	)
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
	_expect(first == second, "identical projection inputs are byte-stable")
	_expect(first.size() == 3, "all supplied typed legal targets are represented")
	if first.size() == 3:
		var ordered_ids: Array[String] = []
		for candidate_variant in first:
			ordered_ids.append(str(
				((candidate_variant as Dictionary).get("target_identity", {}) as Dictionary)
					.get("stable_id", "")
			))
		_expect(
			ordered_ids == ["facility.alpha", "facility.middle", "facility.zeta"],
			"candidate ordering ignores supplied target enumeration order"
		)
		for candidate_variant in first:
			var candidate := candidate_variant as Dictionary
			_expect(
				str(candidate.get("candidate_fingerprint", ""))
					== AiCardSemanticProjectionService.fingerprint_record(
						candidate,
						"candidate_fingerprint"
					),
				"candidate fingerprint follows canonical sorted-key JSON"
			)
		(first[0] as Dictionary)["action_id"] = "mutated.output"
		((first[1] as Dictionary).get("projected_outcomes", {}) as Dictionary)[
			"self_economy"
		] = 999
		var third := service.project_candidates(
			fixture.get("spec", {}) as Dictionary,
			fixture.get("instance", {}) as Dictionary,
			fixture.get("world", {}) as Dictionary
		)
		_expect(
			str((third[0] as Dictionary).get("action_id", "")) != "mutated.output"
				and int(((third[1] as Dictionary).get("projected_outcomes", {}) as Dictionary).get(
					"self_economy",
					0
				)) != 999,
			"returned candidates share no mutable service payload"
		)


func _test_provenance_and_revision_failures(
	service: AiCardSemanticProjectionService
) -> void:
	var fixture := AiCardSemanticProjectionBench.make_case(
		AiCardSemanticProjectionBench.representative_scenarios()[0] as Dictionary
	)
	var spec := fixture.get("spec", {}) as Dictionary
	var instance := fixture.get("instance", {}) as Dictionary
	var world := fixture.get("world", {}) as Dictionary

	var private_public_source := world.duplicate(true)
	private_public_source["visibility_scope_id"] = "actor_private"
	AiCardSemanticProjectionBench.refingerprint_world(private_public_source)
	_expect(
		service.project_candidates(spec, instance, private_public_source).is_empty(),
		"public rack with private provenance is rejected"
	)

	var forged_source := world.duplicate(true)
	forged_source["source_kind"] = "catalog_lookup"
	AiCardSemanticProjectionBench.refingerprint_world(forged_source)
	_expect(
		service.project_candidates(spec, instance, forged_source).is_empty(),
		"arbitrary catalog lookup provenance is rejected"
	)

	var stale_instance := instance.duplicate(true)
	stale_instance["instance_revision"] = int(stale_instance.get("instance_revision", 0)) + 1
	_expect(
		service.project_candidates(spec, stale_instance, world).is_empty(),
		"stale instance revision is rejected"
	)

	var stale_world := world.duplicate(true)
	stale_world["world_revision"] = int(stale_world.get("world_revision", 0)) + 1
	AiCardSemanticProjectionBench.refingerprint_world(stale_world)
	_expect(
		service.project_candidates(spec, instance, stale_world).is_empty(),
		"legal proof from a stale world revision is rejected"
	)

	var stale_source := world.duplicate(true)
	stale_source["source_revision"] = "b".repeat(64)
	AiCardSemanticProjectionBench.refingerprint_world(stale_source)
	_expect(
		service.project_candidates(spec, instance, stale_source).is_empty(),
		"legal proof from a stale source revision is rejected"
	)

	var stale_semantic_spec := spec.duplicate(true)
	(stale_semantic_spec.get("identity", {}) as Dictionary)["rank"] = 3
	AiCardSemanticProjectionBench.refingerprint_spec(stale_semantic_spec)
	_expect(
		service.project_candidates(stale_semantic_spec, instance, world).is_empty(),
		"world projection cannot authorize a different semantic revision"
	)

	var stale_legality := world.duplicate(true)
	var target := (stale_legality.get("legal_targets", []) as Array)[0] as Dictionary
	(target.get("explanation_tokens", []) as Array).append("semantic.fact.tampered")
	AiCardSemanticProjectionBench.refingerprint_world(stale_legality)
	_expect(
		service.project_candidates(spec, instance, stale_legality).is_empty(),
		"tampered legality proof fingerprint is rejected"
	)

	var no_proof := world.duplicate(true)
	no_proof["legal_targets"] = []
	AiCardSemanticProjectionBench.refingerprint_world(no_proof)
	_expect(
		service.project_candidates(spec, instance, no_proof).is_empty(),
		"absence of typed legal targets fails closed"
	)


func _test_schema_and_privacy_failures(
	service: AiCardSemanticProjectionService
) -> void:
	var fixture := AiCardSemanticProjectionBench.make_case(
		AiCardSemanticProjectionBench.representative_scenarios()[0] as Dictionary
	)
	var spec := fixture.get("spec", {}) as Dictionary
	var instance := fixture.get("instance", {}) as Dictionary
	var world := fixture.get("world", {}) as Dictionary

	var unknown_op := spec.duplicate(true)
	((unknown_op.get("effect_ops", []) as Array)[0] as Dictionary)["op_id"] = "future.op"
	AiCardSemanticProjectionBench.refingerprint_spec(unknown_op)
	_expect(
		service.project_candidates(unknown_op, instance, world).is_empty(),
		"unknown operation fails closed"
	)

	var unknown_root := spec.duplicate(true)
	unknown_root["future_semantic_field"] = true
	AiCardSemanticProjectionBench.refingerprint_spec(unknown_root)
	_expect(
		service.project_candidates(unknown_root, instance, world).is_empty(),
		"unknown semantic root field fails closed"
	)

	var bad_rank := spec.duplicate(true)
	(bad_rank.get("identity", {}) as Dictionary)["rank"] = 2.5
	AiCardSemanticProjectionBench.refingerprint_spec(bad_rank)
	_expect(
		service.project_candidates(bad_rank, instance, world).is_empty(),
		"malformed identity fails closed"
	)

	var bad_op_value := spec.duplicate(true)
	((bad_op_value.get("effect_ops", []) as Array)[0] as Dictionary)[
		"rate_units_per_minute"
	] = "two"
	AiCardSemanticProjectionBench.refingerprint_spec(bad_op_value)
	_expect(
		service.project_candidates(bad_op_value, instance, world).is_empty(),
		"wrongly typed operation magnitude fails closed"
	)

	var rival_private := world.duplicate(true)
	rival_private["rival_private"] = {"opponent_hand": ["secret.card"]}
	AiCardSemanticProjectionBench.refingerprint_world(rival_private)
	_expect(
		service.project_candidates(spec, instance, rival_private).is_empty(),
		"rival-private fields are rejected recursively"
	)

	var hidden_owner := world.duplicate(true)
	var hidden_target := (hidden_owner.get("legal_targets", []) as Array)[0] as Dictionary
	(hidden_target.get("target_identity", {}) as Dictionary)["hidden_owner"] = "actor.rival"
	AiCardSemanticProjectionBench.refingerprint_target(hidden_target)
	AiCardSemanticProjectionBench.refingerprint_world(hidden_owner)
	_expect(
		service.project_candidates(spec, instance, hidden_owner).is_empty(),
		"hidden owner fields are rejected recursively"
	)

	var future_bag := world.duplicate(true)
	future_bag["future_bag_keys"] = ["future.card.1"]
	AiCardSemanticProjectionBench.refingerprint_world(future_bag)
	_expect(
		service.project_candidates(spec, instance, future_bag).is_empty(),
		"future supply bag keys are rejected"
	)

	var policy_value := spec.duplicate(true)
	((policy_value.get("effect_ops", []) as Array)[0] as Dictionary)["ai_value"] = 500
	AiCardSemanticProjectionBench.refingerprint_spec(policy_value)
	_expect(
		service.project_candidates(policy_value, instance, world).is_empty(),
		"AI scalar fields are rejected even with a fresh semantic fingerprint"
	)

	var forbidden_object := Node.new()
	var impure_instance := instance.duplicate(true)
	impure_instance["forbidden_object"] = forbidden_object
	_expect(
		service.project_candidates(spec, impure_instance, world).is_empty(),
		"Object-bearing input fails closed"
	)
	forbidden_object.free()


func _test_instance_availability(
	service: AiCardSemanticProjectionService
) -> void:
	var fixture := AiCardSemanticProjectionBench.make_case(
		AiCardSemanticProjectionBench.representative_scenarios()[1] as Dictionary
	)
	var spec := fixture.get("spec", {}) as Dictionary
	var instance := fixture.get("instance", {}) as Dictionary
	var world := fixture.get("world", {}) as Dictionary
	for flag in ["queued", "locked"]:
		var unavailable := instance.duplicate(true)
		unavailable[flag] = true
		_expect(
			service.project_candidates(spec, unavailable, world).is_empty(),
			"%s instance cannot produce an action candidate" % flag
		)
	var cooling := instance.duplicate(true)
	cooling["cooldown_remaining_seconds"] = 0.001
	_expect(
		service.project_candidates(spec, cooling, world).is_empty(),
		"cooling instance cannot produce an action candidate"
	)


func _test_readiness_and_counterability(
	service: AiCardSemanticProjectionService
) -> void:
	var interaction_fixture := AiCardSemanticProjectionBench.make_case(
		AiCardSemanticProjectionBench.representative_scenarios()[8] as Dictionary
	)
	var active_spec := interaction_fixture.get("spec", {}) as Dictionary
	var instance := interaction_fixture.get("instance", {}) as Dictionary
	var active_world := interaction_fixture.get("world", {}) as Dictionary
	for readiness_id in ["projection_only", "not_acquirable"]:
		var non_executable_spec := active_spec.duplicate(true)
		non_executable_spec["runtime_readiness_id"] = readiness_id
		AiCardSemanticProjectionBench.refingerprint_spec(non_executable_spec)
		var rebound_world := active_world.duplicate(true)
		rebound_world["semantic_fingerprint"] = str(
			non_executable_spec.get("semantic_fingerprint", "")
		)
		AiCardSemanticProjectionBench.refingerprint_world(rebound_world)
		_expect(
			service.project_candidates(
				non_executable_spec, instance, rebound_world
			).is_empty(),
			"interaction %s readiness cannot emit a legal candidate" % readiness_id
		)

	var zero_risk_world := active_world.duplicate(true)
	var target := (zero_risk_world.get("legal_targets", []) as Array)[0] as Dictionary
	target["counter_risk"] = 0
	AiCardSemanticProjectionBench.refingerprint_target(target)
	AiCardSemanticProjectionBench.refingerprint_world(zero_risk_world)
	var zero_risk_candidates := service.project_candidates(
		active_spec, instance, zero_risk_world
	)
	_expect(zero_risk_candidates.size() == 1, "active counterable interaction remains legal")
	if zero_risk_candidates.size() == 1:
		var candidate := zero_risk_candidates[0] as Dictionary
		_expect(
			int(candidate.get("counter_risk", -1)) == 0,
			"counterability alone leaves candidate counter risk at zero"
		)
		_expect(
			int((candidate.get("projected_outcomes", {}) as Dictionary).get(
				"counter_risk", -1
			)) == 0,
			"counterability alone leaves outcome counter risk at zero"
		)
		_expect(
			(candidate.get("explanation_tokens", []) as Array).has(
				"semantic.response.counterable"
			),
			"counterability remains available as a neutral explanation token"
		)


func _test_debug_boundary(service: AiCardSemanticProjectionService) -> void:
	var counters := service.debug_counters()
	_expect(counters.size() == 10, "debug surface has only its fixed counters")
	for key_variant in counters.keys():
		_expect(str(key_variant).ends_with("_count"), "debug key is a counter")
		_expect(counters.get(key_variant) is int, "debug value is an integer count")
	_expect(
		not counters.has("candidates")
			and not counters.has("last_candidate")
			and not counters.has("world_projection"),
		"debug surface retains no candidate or input payload"
	)


func _test_bounded_projection_cost(
	service: AiCardSemanticProjectionService
) -> void:
	var fixture := AiCardSemanticProjectionBench.make_case(
		AiCardSemanticProjectionBench.representative_scenarios()[6] as Dictionary
	)
	var started_usec := Time.get_ticks_usec()
	var emitted := 0
	for _iteration in range(400):
		emitted += service.project_candidates(
			fixture.get("spec", {}) as Dictionary,
			fixture.get("instance", {}) as Dictionary,
			fixture.get("world", {}) as Dictionary
		).size()
	var duration_msec := float(Time.get_ticks_usec() - started_usec) / 1000.0
	_expect(emitted == 400, "bounded loop emits one candidate per legal target")
	_expect(
		duration_msec < 5000.0,
		"400 pure-data projections complete within 5 seconds (%.2f ms)"
			% duration_msec
	)
	print(
		"AI_CARD_SEMANTIC_PROJECTION_PERF|iterations=400|duration_ms=%.3f"
		% duration_msec
	)


func _contains_key_recursive(value: Variant, expected_key: String) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) == expected_key \
					or _contains_key_recursive((value as Dictionary).get(key_variant), expected_key):
				return true
	elif value is Array:
		for child_variant in value as Array:
			if _contains_key_recursive(child_variant, expected_key):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AI card semantic projection passed (%d checks)." % _checks)
		print("AI_CARD_SEMANTIC_PROJECTION_TEST_COMPLETE")
		quit(0)
		return
	for failure in _failures:
		push_error("AI card semantic projection failed: %s" % failure)
	quit(1)
