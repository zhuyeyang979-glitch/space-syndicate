extends Node
class_name CardSemanticSourceAuthorizationBench

const FIXTURE := preload(
	"res://scripts/tools/card_semantic_source_authorization_fixture.gd"
)
const PROJECTION_ITERATIONS := 100
const PROJECTION_TIME_LIMIT_MS := 5000.0

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

	var cache_before_timing := FIXTURE.catalog_metrics(
		catalog.validation_snapshot()
	)
	var timing_started_usec := Time.get_ticks_usec()
	var repeated_candidate_count := 0
	var deterministic := true
	for _index in range(PROJECTION_ITERATIONS):
		var candidates := projection.project_authorized_source(
			active_bundle,
			active_world
		)
		repeated_candidate_count += candidates.size()
		if candidates != active_candidates:
			deterministic = false
	var projection_100_ms := snappedf(
		float(Time.get_ticks_usec() - timing_started_usec) / 1000.0,
		0.001
	)
	var cache_after := FIXTURE.catalog_metrics(catalog.validation_snapshot())
	var rng_after := rng.capture_plan_checkpoint()
	_check(
		state,
		repeated_candidate_count == PROJECTION_ITERATIONS,
		"100_authorized_projections_emit_100_candidates"
	)
	_check(state, deterministic, "100_authorized_projections_are_deterministic")
	_check(
		state,
		projection_100_ms < PROJECTION_TIME_LIMIT_MS,
		"100_authorized_projection_timing_is_bounded"
	)
	_check(
		state,
		int(cache_after.get("compile_count", -1))
			== int(cache_before.get("compile_count", -2))
			and int(cache_after.get("cache_entry_count", -1))
				== int(cache_before.get("cache_entry_count", -2)),
		"authorization_and_projection_compile_delta_zero"
	)
	_check(
		state,
		cache_before_timing == cache_after,
		"100_projection_loop_does_not_touch_compile_cache"
	)
	_check(state, rng_before == rng_after, "authorization_projection_rng_delta_zero")

	var source_debug := source.debug_snapshot()
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
		"projection_time_limit_ms": PROJECTION_TIME_LIMIT_MS,
		"projection_deterministic": deterministic,
		"compile_cache_before": cache_before,
		"compile_cache_before_timing": cache_before_timing,
		"compile_cache_after": cache_after,
		"compile_delta": (
			int(cache_after.get("compile_count", -1))
			- int(cache_before.get("compile_count", -1))
		),
		"projection_cache_delta_zero": cache_before_timing == cache_after,
		"rng_before": rng_before,
		"rng_after": rng_after,
		"rng_unchanged": rng_before == rng_after,
		"source_debug": source_debug,
		"projection_debug": projection_debug,
		"debug_no_raw_leak": debug_clean,
	})


static func _accepted(bundle: Dictionary) -> bool:
	return bundle.keys() == CardSemanticSourceAuthorizationPort.RESULT_KEYS \
		and bundle.get("schema_version") == 1 \
		and bundle.get("accepted") == true \
		and str(bundle.get("reason_id", "")) == "authorized" \
		and SemanticWireV1.is_fingerprint(bundle.get("bundle_fingerprint"))


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
