extends SceneTree

const SCHEMA := preload("res://scripts/cards/semantic/card_semantic_schema_v1.gd")
const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const BENCH_SCRIPT := preload("res://scripts/tools/card_semantic_phase1_integration_bench.gd")

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

	var manifest: Dictionary = BENCH_SCRIPT.evaluate(coordinator)
	_expect(str(manifest.get("status", "FAIL")) == "PASS", "integration manifest passes: %s" % JSON.stringify(manifest.get("failures", [])))
	_expect(int(manifest.get("failure_count", -1)) == 0, "integration manifest has zero failures")
	_expect(int(manifest.get("check_count", 0)) >= 40, "integration manifest executes the focused contract matrix")
	_expect(SCHEMA.is_pure_data(manifest), "integration manifest is detached pure data")

	var service_counts: Dictionary = manifest.get("service_counts", {}) as Dictionary
	_expect(int(service_counts.get("card_semantic_catalog", 0)) == 1, "one catalog service")
	_expect(int(service_counts.get("ai_card_semantic_projection", 0)) == 1, "one AI projection service")
	_expect(int(service_counts.get("card_player_face_projection", 0)) == 1, "one PlayerFace projection service")

	var catalog: Dictionary = manifest.get("catalog", {}) as Dictionary
	_expect(
		int(catalog.get("compiled_count", 0)) == 348
			and int(catalog.get("active_count", 0)) == 256
			and int(catalog.get("projection_only_count", 0)) == 92
			and int(catalog.get("operation_count", 0)) == 606,
		"production catalog reports 348/256/92/606"
	)
	var projections: Dictionary = manifest.get("projections", {}) as Dictionary
	_expect(int(projections.get("active_ai_candidate_count", 0)) == 1, "active representative emits one AI candidate")
	_expect(bool(projections.get("active_player_face", false)), "active representative emits PlayerFace DTO")
	_expect(int(projections.get("monster_ai_candidate_count", -1)) == 0 and bool(projections.get("monster_static_player_face", false)), "monster is projection-only for AI and visible to PlayerFace")
	_expect(int(projections.get("interaction_ai_candidate_count", -1)) == 0 and bool(projections.get("interaction_static_player_face", false)), "interaction is projection-only for AI and visible to PlayerFace")
	_expect(bool(projections.get("same_semantic_spec", false)), "same semantic spec drives AI and PlayerFace")

	var determinism: Dictionary = manifest.get("determinism", {}) as Dictionary
	_expect(bool(determinism.get("compiler", false)) and bool(determinism.get("ai_projection", false)) and bool(determinism.get("player_face_projection", false)), "compiler and both projections are deterministic and detached")
	_expect(bool(manifest.get("rng_unchanged", false)), "semantic and projection work consumes no live RNG")
	_expect(bool(manifest.get("no_per_candidate_compilation", false)), "repeated AI projection does not compile")
	_expect(manifest.get("cache_metrics_before_repeated_ai", {}) == manifest.get("cache_metrics_after_repeated_ai", {}), "compiler cache metrics stay unchanged during candidate projection")

	var save_registry: Dictionary = manifest.get("save_registry", {}) as Dictionary
	_expect(int(save_registry.get("section_count", 0)) == 19 and int(save_registry.get("semantic_projection_sections", -1)) == 0, "v3/v0.6 registry remains exactly 19 sections")
	var boundaries: Dictionary = manifest.get("boundaries", {}) as Dictionary
	_expect(bool(boundaries.get("source_dependencies_clean", false)), "new services have no Main/current-scene/RNG/save/process-loop dependency")
	_expect(bool(boundaries.get("ai_does_not_compile", false)), "AI service does not compile semantics")
	_expect(int(boundaries.get("gameplay_executor_connections", -1)) == 0, "semantic services have no gameplay executor connection")
	_expect(not bool(boundaries.get("arbitrary_card_lookup", true)) and not bool(boundaries.get("cache_enumeration", true)), "catalog exposes no arbitrary lookup or cache enumeration")
	_expect(not bool(boundaries.get("consumer_cutover_claim", true)) and not bool(boundaries.get("full_resume_claim", true)), "integration makes no consumer cutover or full resume claim")
	_expect(bool(manifest.get("outputs_pure_data", false)), "all semantic, candidate, and DTO outputs are pure data")
	var scene_loads: Dictionary = manifest.get("scene_loads", {}) as Dictionary
	_expect(bool(scene_loads.get("coordinator", false)) and bool(scene_loads.get("main", false)), "production coordinator and main scene load without parse errors")

	coordinator.queue_free()
	await process_frame
	_finish(manifest)


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)


func _finish(manifest: Dictionary) -> void:
	var duration_ms := snappedf(float(Time.get_ticks_usec() - _started_usec) / 1000.0, 0.001)
	_expect(duration_ms < 60000.0, "focused test stays below 60 seconds")
	if _failures.is_empty():
		print(
			"CARD_SEMANTIC_PHASE1_INTEGRATION_TEST|status=PASS|checks=%d|failures=0|duration_ms=%.3f|semantic_fingerprint=%s"
			% [
				_checks,
				duration_ms,
				str((manifest.get("catalog", {}) as Dictionary).get("semantic_catalog_fingerprint", "")),
			]
		)
		quit(0)
		return
	for failure in _failures:
		push_error("Card semantic Phase 1 integration failed: %s" % failure)
	print(
		"CARD_SEMANTIC_PHASE1_INTEGRATION_TEST|status=FAIL|checks=%d|failures=%d|duration_ms=%.3f|details=%s"
		% [_checks, _failures.size(), duration_ms, JSON.stringify(_failures)]
	)
	quit(1)