extends Node
class_name CardSemanticSourceAuthorizationBench

const FIXTURE := preload(
	"res://scripts/tools/card_semantic_source_authorization_fixture.gd"
)
const PROJECTION_SAMPLE_ITERATIONS := 100
const PROJECTION_ITERATIONS := 400
const PROJECTION_TIME_LIMIT_MS := 5000.0
const BUNDLE_BUILD_TIME_LIMIT_MS := 5000.0
const AUTHORIZED_TO_DIRECT_RATIO_LIMIT := 10.0

var bench_status := "PENDING"
var check_count := 0
var failure_count := 0
var result_snapshot: Dictionary = {}
var _running := false


func _ready() -> void:
	call_deferred("_run_bench")


func _run_bench() -> void:
	if _running:
		return
	_running = true
	var coordinator := get_node_or_null(
		"GameRuntimeCoordinator"
	) as GameRuntimeCoordinator
	result_snapshot = evaluate(coordinator)
	bench_status = str(result_snapshot.get("status", "FAIL"))
	check_count = int(result_snapshot.get("check_count", 0))
	failure_count = int(result_snapshot.get("failure_count", 0))
	print(
		"CARD_SEMANTIC_SOURCE_AUTHORIZATION_BENCH|status=%s|checks=%d|failures=%d|result=%s"
		% [
			bench_status,
			check_count,
			failure_count,
			JSON.stringify(result_snapshot),
		]
	)
	var hold_seconds := 0.1 if DisplayServer.get_name() == "headless" else 30.0
	await get_tree().create_timer(hold_seconds).timeout
	get_tree().quit(0 if bench_status == "PASS" else 1)


static func evaluate(coordinator: GameRuntimeCoordinator) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	var state := {"checks": 0, "failures": []}
	_check(state, coordinator != null, "production_coordinator_present")
	if coordinator == null:
		return _finish(state, started_usec, {})
	var fixture := FIXTURE.configure_coordinator(
		coordinator,
		"semantic.source.authorization.bench"
	)
	_check(state, not fixture.is_empty(), "real_coordinator_fixture_configured")
	if fixture.is_empty():
		return _finish(state, started_usec, {})
	var source := fixture.get("source") as CardSemanticSourceAuthorizationPort
	var catalog := fixture.get("catalog") as CardSemanticCatalogService
	var projection := fixture.get("projection") as AiCardSemanticProjectionService
	var capability := fixture.get("capability") as AiActorHandInventoryCapability
	var rng := fixture.get("rng") as RunRngService
	_check(
		state,
		source != null
			and catalog != null
			and projection != null
			and capability != null
			and rng != null,
		"integrated_production_dependencies_resolve"
	)
	if source == null or catalog == null or projection == null \
			or capability == null or rng == null:
		return _finish(state, started_usec, {})
	_check(state, source.is_ready(), "source_authorization_port_ready")
	_check(
		state,
		coordinator.find_children(
			"CardSemanticSourceAuthorizationPort",
			"",
			true,
			false
		).size() == 1,
		"one_source_authorization_port_in_real_coordinator"
	)

	var rng_before := rng.capture_plan_checkpoint()
	var cache_before := FIXTURE.catalog_metrics(catalog.validation_snapshot())
	var active_bundle := source.authorize_own_hand_card(
		capability,
		FIXTURE.AI_ACTOR_INDEX,
		FIXTURE.ACTIVE_SLOT_INDEX,
		"bench-active"
	)
	_check(state, _accepted(active_bundle), "active_own_hand_source_authorized")
	var active_world := FIXTURE.clipped_world_projection(
		active_bundle,
		"bench.active"
	)
	var active_candidates := projection.project_authorized_source(
		active_bundle,
		active_world
	)
	_check(
		state,
		active_candidates.size() == 1
			and bool((active_candidates[0] as Dictionary).get("legal", false)),
		"active_authorized_source_emits_one_legal_candidate"
	)
	var active_candidate := active_candidates[0] as Dictionary \
		if active_candidates.size() == 1 else {}
	_check(
		state,
		active_candidate.keys() == AiCardSemanticProjectionService.CANDIDATE_KEYS
			and str(active_candidate.get("card_id", ""))
				== FIXTURE.ACTIVE_CARD_ID
			and str(active_candidate.get("information_scope_id", ""))
				== "actor_private",
		"active_candidate_schema_identity_and_scope"
	)
	_run_hostile_world_projection_checks(
		state,
		projection,
		active_bundle,
		active_world
	)

	var projection_only_bundle := source.authorize_own_hand_card(
		capability,
		FIXTURE.AI_ACTOR_INDEX,
		FIXTURE.PROJECTION_ONLY_SLOT_INDEX,
		"bench-projection-only"
	)
	var projection_only_spec := projection_only_bundle.get(
		"semantic_spec",
		{}
	) as Dictionary
	_check(
		state,
		_accepted(projection_only_bundle)
			and str(projection_only_spec.get("runtime_readiness_id", ""))
				== "projection_only",
		"projection_only_readiness_is_catalog_owned"
	)
	var projection_only_candidates := projection.project_authorized_source(
		projection_only_bundle,
		FIXTURE.clipped_world_projection(
			projection_only_bundle,
			"bench.projection-only"
		)
	)
	_check(
		state,
		projection_only_candidates.is_empty(),
		"projection_only_authorized_source_emits_no_candidate"
	)

	var active_spec := active_bundle.get("semantic_spec", {}) as Dictionary
	var active_decision_state := active_bundle.get(
		"instance_decision_state", {}
	) as Dictionary
	var direct_instance := CardInstanceDecisionStateV1.to_ai_projection_input(
		active_decision_state
	)
	var cache_before_direct := FIXTURE.catalog_metrics(
		catalog.validation_snapshot()
	)
	var direct_started_usec := Time.get_ticks_usec()
	var direct_projection_100_ms := -1.0
	var direct_candidate_count := 0
	var direct_deterministic := true
	for index in range(PROJECTION_ITERATIONS):
		var direct_candidates := projection.project_candidates(
			active_spec,
			direct_instance,
			active_world
		)
		direct_candidate_count += direct_candidates.size()
		if direct_candidates != active_candidates:
			direct_deterministic = false
		if index + 1 == PROJECTION_SAMPLE_ITERATIONS:
			direct_projection_100_ms = snappedf(
				float(Time.get_ticks_usec() - direct_started_usec) / 1000.0,
				0.001
			)
	var direct_projection_400_ms := snappedf(
		float(Time.get_ticks_usec() - direct_started_usec) / 1000.0,
		0.001
	)
	var cache_before_timing := FIXTURE.catalog_metrics(
		catalog.validation_snapshot()
	)
	_check(
		state,
		direct_candidate_count == PROJECTION_ITERATIONS
			and direct_deterministic,
		"400_direct_fixture_projections_are_complete_and_deterministic"
	)
	_check(
		state,
		direct_projection_100_ms > 0.0
			and direct_projection_400_ms < PROJECTION_TIME_LIMIT_MS
			and direct_projection_400_ms - direct_projection_100_ms
				<= direct_projection_100_ms * 4.0 + 50.0,
		"direct_fixture_projection_throughput_is_bounded"
	)
	_check(
		state,
		cache_before_direct == cache_before_timing,
		"direct_fixture_projection_does_not_touch_compile_cache"
	)
	var source_debug_before_timing := source.debug_snapshot()
	var timing_started_usec := Time.get_ticks_usec()
	var projection_100_ms := -1.0
	var repeated_candidate_count := 0
	var deterministic := true
	for index in range(PROJECTION_ITERATIONS):
		var candidates := projection.project_authorized_source(
			active_bundle,
			active_world
		)
		repeated_candidate_count += candidates.size()
		if candidates != active_candidates:
			deterministic = false
		if index + 1 == PROJECTION_SAMPLE_ITERATIONS:
			projection_100_ms = snappedf(
				float(Time.get_ticks_usec() - timing_started_usec) / 1000.0,
				0.001
			)
	var projection_400_ms := snappedf(
		float(Time.get_ticks_usec() - timing_started_usec) / 1000.0,
		0.001
	)
	var cache_after_projection := FIXTURE.catalog_metrics(
		catalog.validation_snapshot()
	)
	var source_debug_after_timing := source.debug_snapshot()
	var hand_snapshot_query_delta := _counter_delta(
		source_debug_before_timing,
		source_debug_after_timing,
		"hand_snapshot_query_count"
	)
	var source_revalidation_delta := _counter_delta(
		source_debug_before_timing,
		source_debug_after_timing,
		"source_revalidation_count"
	)
	var actor_state_query_proxy_delta := _counter_delta(
		source_debug_before_timing,
		source_debug_after_timing,
		"actor_state_query_proxy_count"
	)
	var card_inventory_policy_query_lower_bound_delta := _counter_delta(
		source_debug_before_timing,
		source_debug_after_timing,
		"card_inventory_policy_query_lower_bound_count"
	)
	var catalog_compile_request_delta := _counter_delta(
		source_debug_before_timing,
		source_debug_after_timing,
		"catalog_compile_request_count"
	)
	var catalog_spec_authorization_delta := _counter_delta(
		source_debug_before_timing,
		source_debug_after_timing,
		"catalog_spec_authorization_count"
	)
	var detached_bundle_copy_delta := _counter_delta(
		source_debug_before_timing,
		source_debug_after_timing,
		"detached_bundle_copy_count"
	)
	_check(
		state,
		repeated_candidate_count == PROJECTION_ITERATIONS,
		"400_authorized_projections_emit_400_candidates"
	)
	_check(state, deterministic, "400_authorized_projections_are_deterministic")
	_check(
		state,
		projection_100_ms > 0.0
			and projection_400_ms < PROJECTION_TIME_LIMIT_MS
			and projection_400_ms - projection_100_ms
				<= projection_100_ms * 4.0 + 50.0,
		"authorized_projection_throughput_is_bounded"
	)
	_check(
		state,
		int(cache_after_projection.get("compile_count", -1))
			== int(cache_before.get("compile_count", -2))
			and int(cache_after_projection.get("cache_entry_count", -1))
				== int(cache_before.get("cache_entry_count", -2)),
		"authorization_and_projection_compile_delta_zero"
	)
	_check(
		state,
		cache_before_timing == cache_after_projection,
		"400_projection_loop_does_not_touch_compile_cache"
	)
	var authorized_to_direct_ratio := projection_400_ms \
		/ direct_projection_400_ms if direct_projection_400_ms > 0.0 else -1.0
	_check(
		state,
		authorized_to_direct_ratio > 0.0
			and authorized_to_direct_ratio
				<= AUTHORIZED_TO_DIRECT_RATIO_LIMIT,
		"authorized_projection_stays_below_order_of_magnitude_regression"
	)
	_check(
		state,
		hand_snapshot_query_delta == PROJECTION_ITERATIONS
			and source_revalidation_delta == PROJECTION_ITERATIONS,
		"400_projection_loop_revalidates_one_current_hand_snapshot_each"
	)
	_check(
		state,
		actor_state_query_proxy_delta == PROJECTION_ITERATIONS
			and card_inventory_policy_query_lower_bound_delta
				== PROJECTION_ITERATIONS * 3,
		"400_projection_loop_query_work_is_explicit_and_bounded"
	)
	_check(
		state,
		catalog_compile_request_delta == 0
			and catalog_spec_authorization_delta == PROJECTION_ITERATIONS,
		"400_projection_loop_authorizes_cached_specs_without_compiling"
	)
	_check(
		state,
		detached_bundle_copy_delta == PROJECTION_ITERATIONS,
		"400_projection_loop_returns_one_detached_bundle_copy_each"
	)

	var source_debug_before_build := source_debug_after_timing
	var cache_before_build := cache_after_projection
	var build_started_usec := Time.get_ticks_usec()
	var bundle_build_100_ms := -1.0
	var bundle_build_success_count := 0
	for index in range(PROJECTION_ITERATIONS):
		var built_bundle := source.authorize_own_hand_card(
			capability,
			FIXTURE.AI_ACTOR_INDEX,
			FIXTURE.ACTIVE_SLOT_INDEX,
			"bench-bundle-build-%03d" % index
		)
		if _accepted(built_bundle):
			bundle_build_success_count += 1
		if index + 1 == PROJECTION_SAMPLE_ITERATIONS:
			bundle_build_100_ms = snappedf(
				float(Time.get_ticks_usec() - build_started_usec) / 1000.0,
				0.001
			)
	var bundle_build_400_ms := snappedf(
		float(Time.get_ticks_usec() - build_started_usec) / 1000.0,
		0.001
	)
	var source_debug_after_build := source.debug_snapshot()
	var cache_after := FIXTURE.catalog_metrics(catalog.validation_snapshot())
	var bundle_build_hand_query_delta := _counter_delta(
		source_debug_before_build,
		source_debug_after_build,
		"hand_snapshot_query_count"
	)
	var bundle_build_revalidation_delta := _counter_delta(
		source_debug_before_build,
		source_debug_after_build,
		"source_revalidation_count"
	)
	var bundle_build_actor_query_proxy_delta := _counter_delta(
		source_debug_before_build,
		source_debug_after_build,
		"actor_state_query_proxy_count"
	)
	var bundle_build_inventory_policy_lower_bound_delta := _counter_delta(
		source_debug_before_build,
		source_debug_after_build,
		"card_inventory_policy_query_lower_bound_count"
	)
	var bundle_build_compile_request_delta := _counter_delta(
		source_debug_before_build,
		source_debug_after_build,
		"catalog_compile_request_count"
	)
	var bundle_build_spec_authorization_delta := _counter_delta(
		source_debug_before_build,
		source_debug_after_build,
		"catalog_spec_authorization_count"
	)
	var bundle_build_detached_copy_delta := _counter_delta(
		source_debug_before_build,
		source_debug_after_build,
		"detached_bundle_copy_count"
	)
	var expected_journal_eviction_delta := maxi(
		0,
		int(source_debug_before_build.get("journal_entry_count", 0))
			+ PROJECTION_ITERATIONS
			- CardSemanticSourceAuthorizationPort.JOURNAL_LIMIT
	)
	_check(
		state,
		bundle_build_success_count == PROJECTION_ITERATIONS,
		"400_authorized_bundle_builds_succeed"
	)
	_check(
		state,
		bundle_build_100_ms > 0.0
			and bundle_build_400_ms < BUNDLE_BUILD_TIME_LIMIT_MS
			and bundle_build_400_ms - bundle_build_100_ms
				<= bundle_build_100_ms * 4.0 + 50.0,
		"100_and_400_authorized_bundle_build_timings_are_bounded"
	)
	_check(
		state,
		bundle_build_hand_query_delta == PROJECTION_ITERATIONS * 2
			and bundle_build_revalidation_delta == PROJECTION_ITERATIONS
			and bundle_build_actor_query_proxy_delta == PROJECTION_ITERATIONS * 2
			and bundle_build_inventory_policy_lower_bound_delta
				== PROJECTION_ITERATIONS * 6,
		"authorized_bundle_build_query_work_is_explicit_and_bounded"
	)
	_check(
		state,
		bundle_build_compile_request_delta == PROJECTION_ITERATIONS
			and bundle_build_spec_authorization_delta == PROJECTION_ITERATIONS
			and bundle_build_detached_copy_delta == PROJECTION_ITERATIONS,
		"authorized_bundle_build_uses_one_cached_spec_and_copy_each"
	)
	_check(
		state,
		int(cache_after.get("compile_count", -1))
			== int(cache_before_build.get("compile_count", -2))
			and int(cache_after.get("cache_entry_count", -1))
				== int(cache_before_build.get("cache_entry_count", -2))
			and int(cache_after.get("cache_hit_count", -1))
				== int(cache_before_build.get("cache_hit_count", -2))
					+ PROJECTION_ITERATIONS,
		"400_bundle_builds_are_cache_hits_with_compile_delta_zero"
	)
	_check(
		state,
		int(source_debug_after_build.get("journal_entry_count", -1))
			== CardSemanticSourceAuthorizationPort.JOURNAL_LIMIT
			and int(source_debug_after_build.get(
				"journal_eviction_count", -1
			)) == int(source_debug_before_build.get(
				"journal_eviction_count", -2
			)) + expected_journal_eviction_delta,
		"bundle_build_pressure_keeps_the_fingerprint_journal_bounded"
	)
	var rng_after := rng.capture_plan_checkpoint()
	_check(state, rng_before == rng_after, "authorization_projection_rng_delta_zero")

	var source_debug := source_debug_after_build
	var projection_debug := projection.debug_snapshot()
	var debug_clean := _debug_has_no_raw_leak(
		source_debug,
		projection_debug
	)
	_check(state, debug_clean, "debug_snapshots_have_no_raw_card_or_instance_leak")
	_check(
		state,
		SemanticWireV1.is_closed_data(source_debug)
			and TablePresentationPureDataPolicy.is_pure_data(projection_debug),
		"debug_snapshots_are_detached_data"
	)

	return _finish(state, started_usec, {
		"active_candidate_count": active_candidates.size(),
		"projection_only_candidate_count": projection_only_candidates.size(),
		"projection_iterations": PROJECTION_ITERATIONS,
		"repeated_candidate_count": repeated_candidate_count,
		"projection_100_ms": projection_100_ms,
		"projection_400_ms": projection_400_ms,
		"projection_time_limit_ms": PROJECTION_TIME_LIMIT_MS,
		"projection_deterministic": deterministic,
		"direct_projection_100_ms": direct_projection_100_ms,
		"direct_projection_400_ms": direct_projection_400_ms,
		"direct_projection_deterministic": direct_deterministic,
		"authorized_to_direct_ratio": authorized_to_direct_ratio,
		"authorized_to_direct_ratio_limit": AUTHORIZED_TO_DIRECT_RATIO_LIMIT,
		"bundle_build_iterations": PROJECTION_ITERATIONS,
		"bundle_build_success_count": bundle_build_success_count,
		"bundle_build_100_ms": bundle_build_100_ms,
		"bundle_build_400_ms": bundle_build_400_ms,
		"bundle_build_time_limit_ms": BUNDLE_BUILD_TIME_LIMIT_MS,
		"compile_cache_before": cache_before,
		"compile_cache_before_timing": cache_before_timing,
		"compile_cache_after_projection": cache_after_projection,
		"compile_cache_before_build": cache_before_build,
		"compile_cache_after": cache_after,
		"compile_delta": (
			int(cache_after.get("compile_count", -1))
			- int(cache_before.get("compile_count", -1))
		),
		"projection_cache_delta_zero": (
			cache_before_timing == cache_after_projection
		),
		"hand_snapshot_query_delta": hand_snapshot_query_delta,
		"source_revalidation_delta": source_revalidation_delta,
		"actor_state_query_proxy_delta": actor_state_query_proxy_delta,
		"card_inventory_policy_query_lower_bound_delta": (
			card_inventory_policy_query_lower_bound_delta
		),
		"catalog_compile_request_delta": catalog_compile_request_delta,
		"catalog_spec_authorization_delta": catalog_spec_authorization_delta,
		"detached_bundle_copy_delta": detached_bundle_copy_delta,
		"bundle_build_hand_query_delta": bundle_build_hand_query_delta,
		"bundle_build_revalidation_delta": bundle_build_revalidation_delta,
		"bundle_build_actor_query_proxy_delta": (
			bundle_build_actor_query_proxy_delta
		),
		"bundle_build_inventory_policy_lower_bound_delta": (
			bundle_build_inventory_policy_lower_bound_delta
		),
		"bundle_build_compile_request_delta": (
			bundle_build_compile_request_delta
		),
		"bundle_build_spec_authorization_delta": (
			bundle_build_spec_authorization_delta
		),
		"bundle_build_detached_copy_delta": bundle_build_detached_copy_delta,
		"rng_before": rng_before,
		"rng_after": rng_after,
		"rng_unchanged": rng_before == rng_after,
		"source_debug": source_debug,
		"projection_debug": projection_debug,
		"debug_no_raw_leak": debug_clean,
	})


static func _run_hostile_world_projection_checks(
	state: Dictionary,
	projection: AiCardSemanticProjectionService,
	bundle: Dictionary,
	world: Dictionary
) -> void:
	var cases := [
		{"id": "viewer", "key": "viewer_actor_id", "value": "player.2"},
		{
			"id": "source_kind",
			"key": "source_kind",
			"value": "public_rack",
			"visibility_scope_id": "public",
		},
		{
			"id": "card",
			"key": "card_id",
			"value": FIXTURE.PROJECTION_ONLY_CARD_ID,
		},
		{
			"id": "instance",
			"key": "instance_id",
			"value": "fixture:semantic:forged:01",
		},
		{"id": "slot", "key": "source_slot", "value": 1},
		{
			"id": "source_revision",
			"key": "source_revision",
			"value": "e".repeat(64),
		},
		{
			"id": "instance_revision",
			"key": "instance_revision",
			"value": "d".repeat(64),
		},
	]
	for case_variant in cases:
		var case := case_variant as Dictionary
		var hostile_world := world.duplicate(true)
		hostile_world[str(case.get("key", ""))] = case.get("value")
		if case.has("visibility_scope_id"):
			hostile_world["visibility_scope_id"] = case.get(
				"visibility_scope_id"
			)
		_resign_world_projection(hostile_world)
		_check(
			state,
			projection.project_authorized_source(
				bundle,
				hostile_world
			).is_empty(),
			"hostile_authorized_projection_rejects_%s_binding"
				% str(case.get("id", "unknown"))
		)


static func _resign_world_projection(world: Dictionary) -> void:
	var targets := (world.get("legal_targets", []) as Array).duplicate(true)
	for index in range(targets.size()):
		var target := targets[index] as Dictionary
		target["source_revision"] = world.get("source_revision")
		target["instance_revision"] = world.get("instance_revision")
		target["world_revision"] = world.get("world_revision")
		target["legality_fingerprint"] = CardSemanticSchemaV1.fingerprint(
			target,
			"legality_fingerprint"
		)
		targets[index] = target
	world["legal_targets"] = targets
	world["projection_fingerprint"] = CardSemanticSchemaV1.fingerprint(
		world,
		"projection_fingerprint"
	)


static func _accepted(bundle: Dictionary) -> bool:
	return bundle.keys() == CardSemanticSourceAuthorizationPort.RESULT_KEYS \
		and bundle.get("schema_version") == 1 \
		and bundle.get("accepted") == true \
		and str(bundle.get("reason_id", "")) == "authorized" \
		and SemanticWireV1.is_fingerprint(bundle.get("bundle_fingerprint"))


static func _counter_delta(
	before: Dictionary,
	after: Dictionary,
	key: String
) -> int:
	return int(after.get(key, -1)) - int(before.get(key, -1))


static func _debug_has_no_raw_leak(
	source_debug: Dictionary,
	projection_debug: Dictionary
) -> bool:
	var text := JSON.stringify({
		"source": source_debug,
		"projection": projection_debug,
	})
	for forbidden in [
		FIXTURE.ACTIVE_CARD_ID,
		FIXTURE.PROJECTION_ONLY_CARD_ID,
		"fixture:semantic:active:01",
		"fixture:semantic:projection-only:01",
		"\"card_record\"",
		"\"machine\"",
		"\"player\"",
		"\"developer\"",
	]:
		if text.contains(forbidden):
			return false
	return true


static func _check(state: Dictionary, condition: bool, failure_id: String) -> void:
	state["checks"] = int(state.get("checks", 0)) + 1
	if not condition:
		(state.get("failures", []) as Array).append(failure_id)


static func _finish(
	state: Dictionary,
	started_usec: int,
	evidence: Dictionary
) -> Dictionary:
	var result := evidence.duplicate(true)
	var failures := (state.get("failures", []) as Array).duplicate()
	result["schema_version"] = 1
	result["status"] = "PASS" if failures.is_empty() else "FAIL"
	result["check_count"] = int(state.get("checks", 0))
	result["failure_count"] = failures.size()
	result["failures"] = failures
	result["duration_ms"] = snappedf(
		float(Time.get_ticks_usec() - started_usec) / 1000.0,
		0.001
	)
	return result
