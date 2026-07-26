extends SceneTree

const SCHEMA := preload("res://scripts/cards/semantic/card_semantic_schema_v1.gd")
const COMPILER := preload("res://scripts/cards/semantic/card_semantic_compiler_v1.gd")
const AI_OUTCOME := preload("res://scripts/runtime/ai_outcome_vector_v1.gd")
const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const CATALOG_SERVICE_SCENE := preload(
	"res://scenes/runtime/CardSemanticCatalogService.tscn"
)
const AI_SERVICE_SCENE := preload(
	"res://scenes/runtime/AiCardSemanticProjectionService.tscn"
)

var _checks := 0
var _failures: Array[String] = []
var _started_usec := 0


func _init() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	var catalog_service := CATALOG_SERVICE_SCENE.instantiate() as CardSemanticCatalogService
	var ai_service := AI_SERVICE_SCENE.instantiate() as AiCardSemanticProjectionService
	root.add_child(catalog_service)
	root.add_child(ai_service)
	await process_frame
	_expect(catalog_service != null and ai_service != null, "services_instantiate")
	if catalog_service == null or ai_service == null:
		_finish()
		return
	var summary := catalog_service.validation_snapshot()
	_expect(bool(summary.get("configured", false)), "authoritative_catalog_configured")
	_expect(int(summary.get("cache_entry_count", 0)) == 348, "catalog_cache_sealed_at_348")

	var source_catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_expect(source_catalog != null, "source_catalog_loads")
	if source_catalog == null:
		_finish()
		return
	var source_report := source_catalog.reload()
	var source_snapshot := source_catalog.catalog_snapshot()
	var catalog_id := str(source_snapshot.get("catalog_id", ""))
	_expect(bool(source_report.get("valid", false)), "source_catalog_valid")

	var active_record := source_catalog.card_snapshot(
		"commodity.star_dew_berry.rank_1"
	)
	var projection_record := source_catalog.card_snapshot(
		"interaction.starlink_dismantle.rank_1"
	)
	_expect(not active_record.is_empty(), "active_record_found")
	_expect(not projection_record.is_empty(), "projection_only_record_found")

	var valid_result := catalog_service.compile_authorized(
		_envelope(active_record, 1)
	)
	var active_spec := valid_result.get("spec", {}) as Dictionary
	_expect(
		bool(valid_result.get("ok", false))
			and bool(valid_result.get("cache_hit", false))
			and str(active_spec.get("runtime_readiness_id", "")) == "active",
		"registered_record_returns_cached_active_spec"
	)
	var authorized_active := catalog_service.authorize_semantic_spec(active_spec)
	_expect(
		bool(authorized_active.get("ok", false))
			and (authorized_active.get("spec", {}) as Dictionary) == active_spec,
		"registered_semantic_spec_is_authorized"
	)

	var forged_record := active_record.duplicate(true)
	var forged_machine := forged_record.get("machine", {}) as Dictionary
	forged_machine["card_id"] = "forged.external.rank_1"
	forged_machine["family_id"] = "forged.external"
	_expect(
		bool(COMPILER.new().compile_card_record(forged_record, catalog_id).get("ok", false)),
		"forged_external_record_is_structurally_compilable"
	)
	var metrics_before_forged := _cache_metrics(catalog_service.validation_snapshot())
	var forged_result := catalog_service.compile_authorized(_envelope(forged_record, 2))
	var metrics_after_forged := _cache_metrics(catalog_service.validation_snapshot())
	_expect_closed(forged_result, "forged_external_record_rejected")
	_expect(metrics_before_forged == metrics_after_forged, "forged_record_cache_delta_zero")

	var same_id_record := active_record.duplicate(true)
	var same_id_payload := (
		(same_id_record.get("machine", {}) as Dictionary).get("effect_payload", {})
		as Dictionary
	)
	same_id_payload["rate_per_minute"] = int(
		same_id_payload.get("rate_per_minute", 0)
	) + 1
	_expect(
		bool(COMPILER.new().compile_card_record(same_id_record, catalog_id).get("ok", false)),
		"same_id_changed_payload_is_structurally_compilable"
	)
	var metrics_before_same_id := _cache_metrics(catalog_service.validation_snapshot())
	var same_id_result := catalog_service.compile_authorized(_envelope(same_id_record, 3))
	var metrics_after_same_id := _cache_metrics(catalog_service.validation_snapshot())
	_expect_closed(same_id_result, "same_id_changed_payload_rejected")
	_expect(metrics_before_same_id == metrics_after_same_id, "same_id_payload_cache_delta_zero")

	var projection_result := catalog_service.compile_authorized(
		_envelope(projection_record, 4)
	)
	var projection_spec := projection_result.get("spec", {}) as Dictionary
	_expect(
		bool(projection_result.get("ok", false))
			and str(projection_spec.get("runtime_readiness_id", "")) == "projection_only",
		"registered_projection_only_spec_compiles"
	)
	var projection_inputs := _ai_inputs(projection_spec, "projection")
	_expect(
		ai_service.project_candidates(
			projection_spec,
			projection_inputs.get("instance", {}) as Dictionary,
			projection_inputs.get("world", {}) as Dictionary
		).is_empty(),
		"registered_projection_only_spec_is_not_legal"
	)

	var forged_readiness := projection_spec.duplicate(true)
	forged_readiness["runtime_readiness_id"] = "active"
	_refingerprint_spec(forged_readiness)
	_expect(
		bool(SCHEMA.validate_semantic_spec(forged_readiness).get("valid", false)),
		"forged_readiness_has_valid_plain_fingerprint"
	)
	var forged_readiness_inputs := _ai_inputs(forged_readiness, "forged_readiness")
	_expect(
		ai_service.project_candidates(
			forged_readiness,
			forged_readiness_inputs.get("instance", {}) as Dictionary,
			forged_readiness_inputs.get("world", {}) as Dictionary
		).is_empty(),
		"caller_resigned_active_readiness_rejected"
	)
	_expect(
		not bool(catalog_service.authorize_semantic_spec(forged_readiness).get("ok", true)),
		"catalog_rejects_resigned_readiness"
	)

	var forged_fingerprint := active_spec.duplicate(true)
	forged_fingerprint["source_definition_fingerprint"] = "b".repeat(64)
	_refingerprint_spec(forged_fingerprint)
	_expect(
		bool(SCHEMA.validate_semantic_spec(forged_fingerprint).get("valid", false)),
		"forged_source_fingerprint_is_schema_valid"
	)
	var forged_fingerprint_inputs := _ai_inputs(forged_fingerprint, "forged_fingerprint")
	_expect(
		ai_service.project_candidates(
			forged_fingerprint,
			forged_fingerprint_inputs.get("instance", {}) as Dictionary,
			forged_fingerprint_inputs.get("world", {}) as Dictionary
		).is_empty(),
		"caller_resigned_source_fingerprint_rejected"
	)

	var active_inputs := _ai_inputs(active_spec, "active")
	var cache_before_ai := _cache_metrics(catalog_service.validation_snapshot())
	var active_candidates := ai_service.project_candidates(
		active_spec,
		active_inputs.get("instance", {}) as Dictionary,
		active_inputs.get("world", {}) as Dictionary
	)
	var cache_after_ai := _cache_metrics(catalog_service.validation_snapshot())
	_expect(
		active_candidates.size() == 1
			and bool((active_candidates[0] as Dictionary).get("legal", false)),
		"valid_registered_spec_emits_one_legal_candidate"
	)
	_expect(cache_before_ai == cache_after_ai, "ai_authorization_does_not_compile")

	ai_service.queue_free()
	catalog_service.queue_free()
	await process_frame
	_finish()


func _envelope(record: Dictionary, revision: int) -> Dictionary:
	return {
		"schema_version": SCHEMA.SCHEMA_VERSION,
		"source_kind": "public_rack",
		"source_revision": revision,
		"visibility_scope_id": "public",
		"card_record": record.duplicate(true),
	}


func _ai_inputs(spec: Dictionary, fixture_id: String) -> Dictionary:
	var identity := spec.get("identity", {}) as Dictionary
	var target := spec.get("target", {}) as Dictionary
	var card_id := str(identity.get("card_id", ""))
	var target_id := str(target.get("target_id", ""))
	var source_revision := ("authorization.%s" % fixture_id).sha256_text()
	var instance_revision := 7
	var world_revision := 11
	var instance := {
		"schema_version": 1,
		"instance_id": "instance.authorization.%s" % fixture_id,
		"card_id": card_id,
		"source_slot": 0,
		"instance_revision": instance_revision,
		"queued": false,
		"locked": false,
		"cooldown_remaining_seconds": 0.0,
	}
	var target_fact := {
		"schema_version": 1,
		"target_id": target_id,
		"target_identity": {
			"schema_version": 1,
			"target_id": target_id,
			"stable_id": "target.authorization.%s" % fixture_id,
		},
		"status_id": "legal",
		"source_revision": source_revision,
		"instance_revision": instance_revision,
		"world_revision": world_revision,
		"uncertainty": 0,
		"counter_risk": 0,
		"outcome_adjustments": AI_OUTCOME.zero(),
		"explanation_tokens": ["semantic.fact.catalog_authorized"],
		"legality_fingerprint": "",
	}
	target_fact["legality_fingerprint"] = SCHEMA.fingerprint(
		target_fact, "legality_fingerprint"
	)
	var timing_id := str((spec.get("timing", {}) as Dictionary).get("timing_id", ""))
	var source_kind := "response_window" if timing_id == "response_window" else "public_rack"
	var visibility_scope_id := "response_authorized" \
		if source_kind == "response_window" else "public"
	var world := {
		"schema_version": 1,
		"projection_id": "world.authorization.%s" % fixture_id,
		"viewer_actor_id": "actor.ai.authorization",
		"visibility_scope_id": visibility_scope_id,
		"source_kind": source_kind,
		"source_revision": source_revision,
		"semantic_fingerprint": str(spec.get("semantic_fingerprint", "")),
		"card_id": card_id,
		"instance_id": str(instance.get("instance_id", "")),
		"source_slot": 0,
		"instance_revision": instance_revision,
		"world_revision": world_revision,
		"legal_targets": [target_fact],
		"projection_fingerprint": "",
	}
	world["projection_fingerprint"] = SCHEMA.fingerprint(
		world, "projection_fingerprint"
	)
	return {"instance": instance, "world": world}


func _refingerprint_spec(spec: Dictionary) -> void:
	spec["semantic_fingerprint"] = SCHEMA.fingerprint(
		spec, "semantic_fingerprint"
	)


func _cache_metrics(snapshot: Dictionary) -> Dictionary:
	return {
		"cache_entry_count": int(snapshot.get("cache_entry_count", 0)),
		"compile_count": int(snapshot.get("compile_count", 0)),
		"cache_hit_count": int(snapshot.get("cache_hit_count", 0)),
		"compile_failure_count": int(snapshot.get("compile_failure_count", 0)),
	}


func _expect_closed(result: Dictionary, failure_id: String) -> void:
	_expect(
		not bool(result.get("ok", true))
			and (result.get("spec", {}) as Dictionary).is_empty(),
		failure_id
	)


func _expect(condition: bool, failure_id: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(failure_id)


func _finish() -> void:
	var duration_ms := snappedf(
		float(Time.get_ticks_usec() - _started_usec) / 1000.0,
		0.001
	)
	if _failures.is_empty():
		print(
			"CARD_SEMANTIC_AUTHORIZATION_BOUNDARY_TEST|status=PASS|checks=%d|failures=0|duration_ms=%.3f"
			% [_checks, duration_ms]
		)
		quit(0)
		return
	print(
		"CARD_SEMANTIC_AUTHORIZATION_BOUNDARY_TEST|status=FAIL|checks=%d|failures=%d|duration_ms=%.3f|details=%s"
		% [_checks, _failures.size(), duration_ms, JSON.stringify(_failures)]
	)
	quit(1)
