extends Node
class_name CardSemanticPhase1IntegrationBench

const SCHEMA := preload("res://scripts/cards/semantic/card_semantic_schema_v1.gd")
const AI_OUTCOME := preload("res://scripts/runtime/ai_outcome_vector_v1.gd")
const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const COORDINATOR_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const SERVICE_SOURCE_PATHS := [
	"res://scripts/runtime/card_semantic_catalog_service.gd",
	"res://scripts/runtime/ai_card_semantic_projection_service.gd",
	"res://scripts/runtime/card_player_face_projection_service.gd",
]
const SERVICE_NODE_NAMES := [
	"CardSemanticCatalogService",
	"AiCardSemanticProjectionService",
	"CardPlayerFaceProjectionService",
]

var integration_manifest: Dictionary = {}
var bench_complete := false
var bench_passed := false
var check_count := 0
var failure_count := 0
var duration_ms := 0.0
var _running := false


func _ready() -> void:
	call_deferred("_run_bench")


func _run_bench() -> void:
	if _running:
		return
	_running = true
	var started_usec := Time.get_ticks_usec()
	integration_manifest = evaluate(get_node_or_null("GameRuntimeCoordinator"))
	duration_ms = snappedf(float(Time.get_ticks_usec() - started_usec) / 1000.0, 0.001)
	check_count = int(integration_manifest.get("check_count", 0))
	failure_count = int(integration_manifest.get("failure_count", 0))
	bench_passed = str(integration_manifest.get("status", "FAIL")) == "PASS"
	bench_complete = true
	print(
		"CARD_SEMANTIC_PHASE1_INTEGRATION_BENCH|status=%s|checks=%d|failures=%d|duration_ms=%.3f|manifest=%s"
		% [
			str(integration_manifest.get("status", "FAIL")),
			check_count,
			failure_count,
			duration_ms,
			JSON.stringify(integration_manifest),
		]
	)


func manifest_snapshot() -> Dictionary:
	return integration_manifest.duplicate(true)


static func evaluate(coordinator: Node) -> Dictionary:
	var state := {"checks": 0, "failures": []}
	_check(state, coordinator != null, "production_coordinator_present")
	if coordinator == null:
		return _finish_manifest(state, {"coordinator_present": false})

	var counts := _service_counts(coordinator)
	_check(state, int(counts.get("card_semantic_catalog", 0)) == 1, "exactly_one_card_semantic_catalog_service")
	_check(state, int(counts.get("ai_card_semantic_projection", 0)) == 1, "exactly_one_ai_card_semantic_projection_service")
	_check(state, int(counts.get("card_player_face_projection", 0)) == 1, "exactly_one_card_player_face_projection_service")

	var catalog_service := coordinator.get_node_or_null("CardSemanticCatalogService") as CardSemanticCatalogService
	var ai_service := coordinator.get_node_or_null("AiCardSemanticProjectionService") as AiCardSemanticProjectionService
	var face_service := coordinator.get_node_or_null("CardPlayerFaceProjectionService") as CardPlayerFaceProjectionService
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	_check(state, catalog_service != null and ai_service != null and face_service != null, "typed_services_resolve")
	_check(state, rng != null, "production_rng_resolves")
	if catalog_service == null or ai_service == null or face_service == null or rng == null:
		return _finish_manifest(state, {"service_counts": counts})

	var summary := catalog_service.configure()
	var total_op_count := 0
	for count_variant in (summary.get("op_counts", {}) as Dictionary).values():
		total_op_count += int(count_variant)
	_check(state, bool(summary.get("configured", false)), "semantic_catalog_configured")
	_check(state, int(summary.get("compiled_count", 0)) == 348, "semantic_catalog_348_compiled")
	_check(state, int(summary.get("active_count", 0)) == 256, "semantic_catalog_256_active")
	_check(state, int(summary.get("projection_only_count", 0)) == 92, "semantic_catalog_92_projection_only")
	_check(state, total_op_count == 606, "semantic_catalog_606_operations")
	_check(state, int(summary.get("cache_entry_count", 0)) == 348, "semantic_catalog_cached_once")
	_check(state, not summary.has("card_ids") and not summary.has("specs") and not summary.has("cache"), "catalog_debug_is_aggregate_only")
	_check(
		state,
		not catalog_service.has_method("semantic_for_card_id")
			and not catalog_service.has_method("card_ids")
			and not catalog_service.has_method("catalog_snapshot")
			and not catalog_service.has_method("all_semantics")
			and not catalog_service.has_method("cache_snapshot"),
		"no_arbitrary_lookup_or_cache_enumeration"
	)

	var rng_before := rng.debug_snapshot()
	var source_catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_check(state, source_catalog != null, "v06_source_catalog_loads")
	var source_report: Dictionary = source_catalog.reload() if source_catalog != null else {}
	var source_snapshot: Dictionary = source_catalog.catalog_snapshot() if source_catalog != null else {}
	var cards: Array = source_snapshot.get("cards", []) as Array
	_check(state, bool(source_report.get("valid", false)) and cards.size() == 348, "v06_source_catalog_valid")

	var active_record := _first_record(cards, "commodity")
	var monster_record := _first_record(cards, "monster")
	var interaction_record := _first_record(cards, "interaction")
	_check(state, not active_record.is_empty() and not monster_record.is_empty() and not interaction_record.is_empty(), "representative_records_found")

	var active_first := _compile_record(catalog_service, active_record, 101)
	var active_second := _compile_record(catalog_service, active_record, 101)
	var active_first_spec: Dictionary = active_first.get("spec", {}) as Dictionary
	var active_second_spec: Dictionary = active_second.get("spec", {}) as Dictionary
	var active_expected := SCHEMA.canonical_json(active_second_spec)
	if not active_first_spec.is_empty():
		(active_first_spec.get("identity", {}) as Dictionary)["card_id"] = "mutated.phase1.rank_1"
	var active_third := _compile_record(catalog_service, active_record, 101)
	var active_spec: Dictionary = active_third.get("spec", {}) as Dictionary
	var monster_result := _compile_record(catalog_service, monster_record, 102)
	var monster_spec: Dictionary = monster_result.get("spec", {}) as Dictionary
	var interaction_result := _compile_record(catalog_service, interaction_record, 103)
	var interaction_spec: Dictionary = interaction_result.get("spec", {}) as Dictionary
	_check(state, bool(active_first.get("ok", false)) and bool(active_second.get("ok", false)) and bool(active_third.get("ok", false)), "active_semantic_authorized")
	_check(state, active_expected == SCHEMA.canonical_json(active_spec), "compiler_deterministic_and_detached")
	_check(state, str(active_spec.get("runtime_readiness_id", "")) == "active", "active_representative_is_active")
	_check(state, str(monster_spec.get("runtime_readiness_id", "")) == "projection_only", "monster_representative_projection_only")
	_check(state, str(interaction_spec.get("runtime_readiness_id", "")) == "projection_only", "interaction_representative_projection_only")
	_check(state, bool(SCHEMA.validate_semantic_spec(active_spec).get("valid", false)), "active_spec_uses_shared_schema")
	_check(state, bool(SCHEMA.validate_semantic_spec(monster_spec).get("valid", false)), "monster_spec_uses_shared_schema")
	_check(state, bool(SCHEMA.validate_semantic_spec(interaction_spec).get("valid", false)), "interaction_spec_uses_shared_schema")

	var active_inputs := _ai_inputs(active_spec, "active")
	var active_candidates_one := ai_service.project_candidates(
		active_spec,
		active_inputs.get("instance", {}) as Dictionary,
		active_inputs.get("world", {}) as Dictionary
	)
	var active_candidates_two := ai_service.project_candidates(
		active_spec,
		active_inputs.get("instance", {}) as Dictionary,
		active_inputs.get("world", {}) as Dictionary
	)
	var active_candidates_expected := active_candidates_two.duplicate(true)
	if not active_candidates_one.is_empty():
		(active_candidates_one[0] as Dictionary)["action_id"] = "mutated.phase1.action"
	var active_candidates_three := ai_service.project_candidates(
		active_spec,
		active_inputs.get("instance", {}) as Dictionary,
		active_inputs.get("world", {}) as Dictionary
	)
	_check(state, active_candidates_two.size() == 1 and bool((active_candidates_two[0] as Dictionary).get("legal", false)), "active_semantic_produces_legal_ai_candidate")
	_check(state, active_candidates_expected == active_candidates_three, "ai_projection_deterministic_and_detached")

	var monster_inputs := _ai_inputs(monster_spec, "monster")
	var monster_candidates := ai_service.project_candidates(
		monster_spec,
		monster_inputs.get("instance", {}) as Dictionary,
		monster_inputs.get("world", {}) as Dictionary
	)
	var interaction_inputs := _ai_inputs(interaction_spec, "interaction")
	var interaction_candidates := ai_service.project_candidates(
		interaction_spec,
		interaction_inputs.get("instance", {}) as Dictionary,
		interaction_inputs.get("world", {}) as Dictionary
	)
	_check(state, monster_candidates.is_empty(), "projection_only_monster_has_no_legal_ai_candidate")
	_check(state, interaction_candidates.is_empty(), "projection_only_interaction_has_no_legal_ai_candidate")

	var active_localization := _localization_source(active_spec)
	var monster_localization := _localization_source(monster_spec)
	var interaction_localization := _localization_source(interaction_spec)
	var active_face_one := face_service.project(active_spec, active_localization, "detail")
	var active_face_two := face_service.project(active_spec, active_localization, "detail")
	var active_face_expected := active_face_two.duplicate(true)
	if not active_face_one.is_empty():
		active_face_one["rank"] = 99
	var active_face_three := face_service.project(active_spec, active_localization, "detail")
	var monster_face := face_service.project(monster_spec, monster_localization, "detail")
	var interaction_face := face_service.project(interaction_spec, interaction_localization, "detail")
	_check(state, not active_face_two.is_empty(), "active_semantic_produces_player_face_dto")
	_check(state, active_face_expected == active_face_three, "player_face_projection_deterministic_and_detached")
	_check(state, not monster_face.is_empty(), "projection_only_monster_produces_static_player_face")
	_check(state, not interaction_face.is_empty(), "projection_only_interaction_produces_static_player_face")

	var active_candidate: Dictionary = active_candidates_three[0] as Dictionary if active_candidates_three.size() == 1 else {}
	var active_identity: Dictionary = active_spec.get("identity", {}) as Dictionary
	var same_semantic := not active_candidate.is_empty() \
		and str(active_candidate.get("card_id", "")) == str(active_identity.get("card_id", "")) \
		and str(active_face_three.get("card_id", "")) == str(active_identity.get("card_id", "")) \
		and str((active_inputs.get("world", {}) as Dictionary).get("semantic_fingerprint", "")) == str(active_spec.get("semantic_fingerprint", "")) \
		and str(active_localization.get("semantic_fingerprint", "")) == str(active_spec.get("semantic_fingerprint", ""))
	_check(state, same_semantic, "same_semantic_spec_drives_ai_and_player_projection")

	var cache_before_repeat := catalog_service.validation_snapshot()
	var repeated_candidate_count := 0
	for _index in range(64):
		repeated_candidate_count += ai_service.project_candidates(
			active_spec,
			active_inputs.get("instance", {}) as Dictionary,
			active_inputs.get("world", {}) as Dictionary
		).size()
	var cache_after_repeat := catalog_service.validation_snapshot()
	_check(state, repeated_candidate_count == 64, "repeated_ai_projection_stable")
	_check(state, cache_before_repeat == cache_after_repeat, "no_per_candidate_semantic_compilation")

	var registry := coordinator.get_node_or_null("GameSessionRuntimeController/V06SaveOwnerRegistry")
	var registry_snapshot: Dictionary = registry.call("registry_snapshot") if registry != null else {}
	var section_ids: Array = registry.call("fixed_section_order") if registry != null else []
	var save_registry_clean := _save_registry_excludes_semantic_services(registry, section_ids)
	_check(state, registry != null, "production_save_registry_resolves")
	_check(state, int(registry_snapshot.get("required_section_count", 0)) == 19 and section_ids.size() == 19, "save_registry_remains_19_sections")
	_check(state, save_registry_clean, "save_registry_has_no_semantic_or_setup_projection_section")

	var source_boundaries := _source_boundaries()
	_check(state, bool(source_boundaries.get("clean", false)), "new_services_have_no_main_rng_save_or_process_dependency")
	_check(state, bool(source_boundaries.get("ai_does_not_compile", false)), "ai_projection_never_compiles_semantics")
	var composition_source := FileAccess.get_file_as_string(COORDINATOR_PATH)
	var no_executor_connections := _composition_has_no_service_connections(composition_source)
	_check(state, no_executor_connections, "semantic_services_not_connected_to_gameplay_executors")
	var coordinator_loads := load(COORDINATOR_PATH) is PackedScene
	var main_loads := load(MAIN_SCENE_PATH) is PackedScene
	_check(state, coordinator_loads and main_loads, "production_coordinator_and_main_scene_load")

	var output_bundle := {
		"active_spec": active_spec,
		"monster_spec": monster_spec,
		"interaction_spec": interaction_spec,
		"active_candidates": active_candidates_three,
		"monster_candidates": monster_candidates,
		"interaction_candidates": interaction_candidates,
		"active_face": active_face_three,
		"monster_face": monster_face,
		"interaction_face": interaction_face,
	}
	_check(state, SCHEMA.is_pure_data(output_bundle), "all_semantic_and_projection_outputs_are_pure_data")
	var rng_after := rng.debug_snapshot()
	_check(state, rng_before == rng_after, "semantic_query_projection_rng_delta_zero")

	var evidence := {
		"coordinator_present": true,
		"coordinator_scene_path": COORDINATOR_PATH,
		"main_scene_path": MAIN_SCENE_PATH,
		"service_counts": counts,
		"catalog": {
			"configured": bool(summary.get("configured", false)),
			"compiled_count": int(summary.get("compiled_count", 0)),
			"active_count": int(summary.get("active_count", 0)),
			"projection_only_count": int(summary.get("projection_only_count", 0)),
			"operation_count": total_op_count,
			"semantic_catalog_fingerprint": str(summary.get("semantic_catalog_fingerprint", "")),
		},
		"representatives": {
			"active_card_id": str(active_identity.get("card_id", "")),
			"active_semantic_fingerprint": str(active_spec.get("semantic_fingerprint", "")),
			"monster_card_id": str((monster_spec.get("identity", {}) as Dictionary).get("card_id", "")),
			"interaction_card_id": str((interaction_spec.get("identity", {}) as Dictionary).get("card_id", "")),
		},
		"projections": {
			"active_ai_candidate_count": active_candidates_three.size(),
			"active_player_face": not active_face_three.is_empty(),
			"monster_ai_candidate_count": monster_candidates.size(),
			"monster_static_player_face": not monster_face.is_empty(),
			"interaction_ai_candidate_count": interaction_candidates.size(),
			"interaction_static_player_face": not interaction_face.is_empty(),
			"same_semantic_spec": same_semantic,
		},
		"determinism": {
			"compiler": active_expected == SCHEMA.canonical_json(active_spec),
			"ai_projection": active_candidates_expected == active_candidates_three,
			"player_face_projection": active_face_expected == active_face_three,
		},
		"cache_metrics_before_repeated_ai": _cache_metrics(cache_before_repeat),
		"cache_metrics_after_repeated_ai": _cache_metrics(cache_after_repeat),
		"no_per_candidate_compilation": cache_before_repeat == cache_after_repeat,
		"rng_unchanged": rng_before == rng_after,
		"save_registry": {
			"section_count": section_ids.size(),
			"section_ids": section_ids.duplicate(),
			"semantic_projection_sections": 0 if save_registry_clean else 1,
		},
		"boundaries": {
			"source_dependencies_clean": bool(source_boundaries.get("clean", false)),
			"ai_does_not_compile": bool(source_boundaries.get("ai_does_not_compile", false)),
			"gameplay_executor_connections": 0 if no_executor_connections else 1,
			"arbitrary_card_lookup": false,
			"cache_enumeration": false,
			"consumer_cutover_claim": false,
			"full_resume_claim": false,
		},
		"scene_loads": {
			"coordinator": coordinator_loads,
			"main": main_loads,
		},
		"outputs_pure_data": SCHEMA.is_pure_data(output_bundle),
	}
	_check(state, SCHEMA.is_pure_data(evidence), "integration_manifest_evidence_is_pure_data")
	return _finish_manifest(state, evidence)


static func _compile_record(service: CardSemanticCatalogService, record: Dictionary, revision: int) -> Dictionary:
	return service.compile_authorized({
		"schema_version": SCHEMA.SCHEMA_VERSION,
		"source_kind": "public_rack",
		"source_revision": revision,
		"visibility_scope_id": "public",
		"card_record": record.duplicate(true),
	})


static func _first_record(cards: Array, category_id: String) -> Dictionary:
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		var machine: Dictionary = card.get("machine", {}) as Dictionary
		if str(machine.get("category_id", "")) == category_id:
			return card.duplicate(true)
	return {}


static func _ai_inputs(spec: Dictionary, fixture_id: String) -> Dictionary:
	var identity: Dictionary = spec.get("identity", {}) as Dictionary
	var target: Dictionary = spec.get("target", {}) as Dictionary
	var timing_id := str((spec.get("timing", {}) as Dictionary).get("timing_id", ""))
	var source_kind := "response_window" if timing_id == "response_window" else "public_rack"
	var visibility_scope := "actor_private" if source_kind == "response_window" else "public"
	var card_id := str(identity.get("card_id", ""))
	var source_revision := ("phase1.source.%s.%s" % [fixture_id, card_id]).sha256_text()
	var instance_revision := 7
	var world_revision := 31
	var instance := {
		"schema_version": 1,
		"instance_id": "instance.phase1.%s" % fixture_id,
		"card_id": card_id,
		"source_slot": 0,
		"instance_revision": instance_revision,
		"queued": false,
		"locked": false,
		"cooldown_remaining_seconds": 0.0,
	}
	var target_fact := {
		"schema_version": 1,
		"target_id": str(target.get("target_id", "")),
		"target_identity": {
			"schema_version": 1,
			"target_id": str(target.get("target_id", "")),
			"stable_id": "target.phase1.%s" % fixture_id,
		},
		"status_id": "legal",
		"source_revision": source_revision,
		"instance_revision": instance_revision,
		"world_revision": world_revision,
		"uncertainty": 0,
		"counter_risk": 0,
		"outcome_adjustments": AI_OUTCOME.zero(),
		"explanation_tokens": ["semantic.fact.phase1_authorized"],
		"legality_fingerprint": "",
	}
	target_fact["legality_fingerprint"] = SCHEMA.fingerprint(target_fact, "legality_fingerprint")
	var world := {
		"schema_version": 1,
		"projection_id": "world_projection.phase1.%s" % fixture_id,
		"viewer_actor_id": "actor.ai.phase1",
		"visibility_scope_id": visibility_scope,
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
	world["projection_fingerprint"] = SCHEMA.fingerprint(world, "projection_fingerprint")
	return {"instance": instance, "world": world}


static func _localization_source(spec: Dictionary) -> Dictionary:
	var identity: Dictionary = spec.get("identity", {}) as Dictionary
	var target: Dictionary = spec.get("target", {}) as Dictionary
	var effects: Array = spec.get("effect_ops", []) as Array
	var card_id := str(identity.get("card_id", ""))
	var family_id := str(identity.get("family_id", ""))
	var category_id := str(identity.get("category_id", ""))
	var condition_rows: Array = []
	for condition_id in _condition_ids(spec):
		condition_rows.append({
			"condition_id": condition_id,
			"message_id": "card.condition.%s" % condition_id,
		})
	var effect_rows: Array = []
	for index in range(effects.size()):
		var op_id := str((effects[index] as Dictionary).get("op_id", ""))
		effect_rows.append({
			"order": index + 1,
			"op_id": op_id,
			"summary_message_id": "card.effect.%s.summary" % op_id,
			"detail_message_id": "card.effect.%s.detail" % op_id,
		})
	return {
		"schema_version": 1,
		"source_id": "player_face.phase1.%s" % card_id,
		"card_id": card_id,
		"semantic_fingerprint": str(spec.get("semantic_fingerprint", "")),
		"authorization_scope_id": "public",
		"authorization_revision": 1,
		"authorized": true,
		"message_ids": {
			"name": "card.name.%s" % card_id,
			"family_name": "card.family.%s" % family_id,
			"acquisition_cost": "card.cost.acquisition",
			"activation_cost": "card.cost.activation",
			"timing": "card.timing.%s" % str((spec.get("timing", {}) as Dictionary).get("timing_id", "")),
			"duration": "card.duration.semantic",
			"counterability": "card.counterability.%s" % str((spec.get("response", {}) as Dictionary).get("response_id", "")),
			"information_scope": "card.information.%s" % str((spec.get("information_policy", {}) as Dictionary).get("visibility_policy_id", "")),
		},
		"target_message_rows": [{
			"target_id": str(target.get("target_id", "")),
			"message_id": "card.target.%s" % str(target.get("target_id", "")),
		}],
		"condition_message_rows": condition_rows,
		"effect_step_message_rows": effect_rows,
		"keyword_rows": [{
			"keyword_id": "card.category.%s" % category_id,
			"label_message_id": "card.keyword.%s.label" % category_id,
			"tooltip_message_id": "card.keyword.%s.tooltip" % category_id,
			"icon_token_id": "icon.card.%s" % category_id,
			"color_token_id": "color.card.%s" % category_id,
		}],
	}


static func _condition_ids(spec: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var target: Dictionary = spec.get("target", {}) as Dictionary
	for condition_variant in target.get("filter_ids", []) as Array:
		var condition_id := str(condition_variant)
		if not result.has(condition_id):
			result.append(condition_id)
	for effect_variant in spec.get("effect_ops", []) as Array:
		var effect := effect_variant as Dictionary
		if effect.get("condition_id") is String:
			var condition_id := str(effect.get("condition_id", ""))
			if not condition_id.is_empty() and not result.has(condition_id):
				result.append(condition_id)
		if effect.get("condition_ids") is Array:
			for condition_variant in effect.get("condition_ids", []) as Array:
				var condition_id := str(condition_variant)
				if not condition_id.is_empty() and not result.has(condition_id):
					result.append(condition_id)
	return result


static func _service_counts(root: Node) -> Dictionary:
	var counts := {
		"card_semantic_catalog": 0,
		"ai_card_semantic_projection": 0,
		"card_player_face_projection": 0,
	}
	_count_services_recursive(root, counts)
	return counts


static func _count_services_recursive(node: Node, counts: Dictionary) -> void:
	if node is CardSemanticCatalogService:
		counts["card_semantic_catalog"] = int(counts["card_semantic_catalog"]) + 1
	if node is AiCardSemanticProjectionService:
		counts["ai_card_semantic_projection"] = int(counts["ai_card_semantic_projection"]) + 1
	if node is CardPlayerFaceProjectionService:
		counts["card_player_face_projection"] = int(counts["card_player_face_projection"]) + 1
	for child in node.get_children():
		_count_services_recursive(child, counts)


static func _save_registry_excludes_semantic_services(registry: Node, section_ids: Array) -> bool:
	if registry == null:
		return false
	for section_variant in section_ids:
		var section_id := str(section_variant).to_lower()
		if section_id.contains("semantic") or section_id.contains("setup") or section_id.contains("projection"):
			return false
	var bindings_variant: Variant = registry.get("bindings")
	if bindings_variant is Array:
		for binding_variant in bindings_variant as Array:
			if binding_variant == null:
				continue
			var binding_text := "%s|%s" % [
				str(binding_variant.get("section_id")),
				str(binding_variant.get("owner_path")),
			]
			for service_name in SERVICE_NODE_NAMES:
				if binding_text.contains(service_name):
					return false
	return true


static func _source_boundaries() -> Dictionary:
	var clean := true
	var ai_does_not_compile := true
	var forbidden := [
		"get_tree().current_scene",
		"/root/Main",
		"RunRngService",
		"RandomNumberGenerator",
		"randf(",
		"randi(",
		"to_save_data",
		"apply_save_data",
		"capture_resume_envelope",
		"func _process(",
		"func _physics_process(",
	]
	for path in SERVICE_SOURCE_PATHS:
		var source := FileAccess.get_file_as_string(path)
		if source.is_empty():
			clean = false
		for token in forbidden:
			if source.contains(token):
				clean = false
	var ai_source := FileAccess.get_file_as_string(SERVICE_SOURCE_PATHS[1])
	for token in ["CardSemanticCompiler", "compile_authorized", "compile_card_record", "compile_catalog_snapshot"]:
		if ai_source.contains(token):
			ai_does_not_compile = false
	return {"clean": clean, "ai_does_not_compile": ai_does_not_compile}


static func _composition_has_no_service_connections(source: String) -> bool:
	for line_variant in source.split("\n"):
		var line := str(line_variant)
		if not line.begins_with("[connection"):
			continue
		for service_name in SERVICE_NODE_NAMES:
			if line.contains(service_name):
				return false
	return true


static func _cache_metrics(snapshot: Dictionary) -> Dictionary:
	return {
		"cache_entry_count": int(snapshot.get("cache_entry_count", 0)),
		"compile_count": int(snapshot.get("compile_count", 0)),
		"cache_hit_count": int(snapshot.get("cache_hit_count", 0)),
		"compile_failure_count": int(snapshot.get("compile_failure_count", 0)),
	}


static func _check(state: Dictionary, condition: bool, failure_id: String) -> void:
	state["checks"] = int(state.get("checks", 0)) + 1
	if not condition:
		(state.get("failures", []) as Array).append(failure_id)


static func _finish_manifest(state: Dictionary, evidence: Dictionary) -> Dictionary:
	var failures: Array = (state.get("failures", []) as Array).duplicate()
	var manifest := evidence.duplicate(true)
	manifest["schema_version"] = 1
	manifest["status"] = "PASS" if failures.is_empty() else "FAIL"
	manifest["check_count"] = int(state.get("checks", 0))
	manifest["failure_count"] = failures.size()
	manifest["failures"] = failures
	return manifest