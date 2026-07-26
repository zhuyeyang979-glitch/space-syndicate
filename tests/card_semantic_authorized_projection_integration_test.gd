extends SceneTree

const COORDINATOR_SCENE := preload(
	"res://scenes/runtime/GameRuntimeCoordinator.tscn"
)
const BENCH_SCENE_PATH := (
	"res://scenes/tools/CardSemanticSourceAuthorizationBench.tscn"
)
const BENCH_SCRIPT := preload(
	"res://scripts/tools/card_semantic_source_authorization_bench.gd"
)

var _checks := 0
var _failures: Array[String] = []
var _started_usec := 0


func _init() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	_expect(coordinator != null, "production coordinator instantiates")
	if coordinator == null:
		_finish({})
		return
	root.add_child(coordinator)
	await process_frame
	var result := BENCH_SCRIPT.evaluate(coordinator)
	_expect(
		str(result.get("status", "FAIL")) == "PASS",
		"real-scene integration passes: %s"
			% JSON.stringify(result.get("failures", []))
	)
	_expect(
		int(result.get("failure_count", -1)) == 0
			and int(result.get("check_count", 0)) >= 15,
		"integration executes the focused contract"
	)
	_expect(
		int(result.get("active_candidate_count", -1)) == 1,
		"active authorized source emits one candidate"
	)
	_expect(
		int(result.get("projection_only_candidate_count", -1)) == 0,
		"projection-only authorized source emits no candidate"
	)
	_expect(
		int(result.get("compile_delta", -1)) == 0
			and bool(result.get("projection_cache_delta_zero", false)),
		"authorization has compile delta zero and projection leaves cache unchanged"
	)
	_expect(
		bool(result.get("rng_unchanged", false)),
		"authorization and projection leave RNG unchanged"
	)
	_expect(
		int(result.get("projection_iterations", -1)) == 100
			and int(result.get("repeated_candidate_count", -1)) == 100
			and bool(result.get("projection_deterministic", false)),
		"100 authorized projections are complete and deterministic"
	)
	_expect(
		float(result.get("projection_100_ms", 60000.0))
			< float(result.get("projection_time_limit_ms", 0.0)),
		"100 authorized projections stay within the timing bound"
	)
	_expect(
		bool(result.get("debug_no_raw_leak", false)),
		"source and projection debug snapshots leak no raw card data"
	)
	_expect(
		TablePresentationPureDataPolicy.is_pure_data(result),
		"result snapshot is detached pure data"
	)
	_expect(load(BENCH_SCENE_PATH) is PackedScene, "real-scene bench loads")

	coordinator.queue_free()
	await process_frame
	_finish(result)


func _expect(condition: bool, failure_id: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(failure_id)


func _finish(result: Dictionary) -> void:
	var duration_ms := snappedf(
		float(Time.get_ticks_usec() - _started_usec) / 1000.0,
		0.001
	)
	_expect(duration_ms < 60000.0, "focused integration stays below 60 seconds")
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"CARD_SEMANTIC_AUTHORIZED_PROJECTION_INTEGRATION_TEST_COMPLETE|status=%s|checks=%d|failures=%d|duration_ms=%.3f|bench_checks=%d|details=%s"
		% [
			status,
			_checks,
			_failures.size(),
			duration_ms,
			int(result.get("check_count", 0)),
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
