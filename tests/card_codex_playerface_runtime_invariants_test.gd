extends SceneTree

const HANDLER_REGISTRY := preload(
	"res://scripts/semantic/operation_handler_registry.gd"
)
const SEMANTIC_SCENE := preload(
	"res://scenes/runtime/CardSemanticCatalogService.tscn"
)
const LOCALIZATION_SCENE := preload(
	"res://scenes/runtime/CardPlayerFacePublicLocalizationSourceService.tscn"
)
const PROJECTION_SCENE := preload(
	"res://scenes/runtime/CardPlayerFaceProjectionService.tscn"
)
const SNAPSHOT_SCENE := preload(
	"res://scenes/runtime/CardCodexPublicSnapshotService.tscn"
)
const SOURCE_SCENE := preload(
	"res://scenes/runtime/CardCodexPublicSourceService.tscn"
)

const MAIN_PATH := "res://scripts/main.gd"
const MAIN_BASELINE_SHA256 := \
	"0c76d2c58c98f8c70f6f893a2872fc937bd621c68ec94a07b552be2bc763326c"
const AI_RUNTIME_PATH := "res://scripts/runtime/ai_runtime_controller.gd"
const SAVE_REGISTRY_PATH := "res://scripts/runtime/v06_save_owner_registry.gd"
const AI_DEBT_REPORT_PATH := \
	"res://reports/cards/ai_direct_field_read_migration.json"
const AI_RAW_READ_BATCH1_REPORT_PATH := \
	"res://reports/cards/ai_raw_read_ratchet_batch1.json"
const RUNTIME_ROOT := "res://scripts/runtime"
const AI_PROJECTION_SERVICE_PATH := \
	"res://scripts/runtime/ai_card_semantic_projection_service.gd"
const SOURCE_AUTHORIZATION_PATH := \
	"res://scripts/runtime/card_semantic_source_authorization_port.gd"
const INTERACTION_OBSERVATION_SERVICE_PATH := \
	"res://scripts/runtime/ai_card_interaction_observation_service.gd"
const INTERACTION_OBSERVATION_SCHEMA_PATH := \
	"res://scripts/semantic/ai_card_interaction_observation_v1.gd"
const INTERACTION_POLICY_COMPATIBILITY_SCHEMA_PATH := \
	"res://scripts/semantic/ai_card_interaction_policy_compatibility_v1.gd"
const COORDINATOR_SCENE_PATH := \
	"res://scenes/runtime/GameRuntimeCoordinator.tscn"

const PR_PLAYERFACE_PRODUCTION_PATHS := [
	"res://scripts/presentation/authorized_card_player_face_localization_source_v1.gd",
	"res://scripts/presentation/player_card_codex_dto_v1.gd",
	"res://scripts/presentation/player_card_codex_family_ladder_dto_v1.gd",
	"res://scripts/runtime/card_player_face_public_localization_source_service.gd",
	"res://scripts/runtime/card_player_face_projection_service.gd",
	"res://scripts/runtime/card_semantic_catalog_service.gd",
	"res://scripts/runtime/card_codex_public_source_service.gd",
	"res://scripts/runtime/card_codex_public_source_adapter.gd",
	"res://scripts/runtime/card_codex_public_snapshot_service.gd",
	"res://scripts/viewmodels/card_codex_browser_snapshot.gd",
	"res://scripts/viewmodels/card_codex_detail_snapshot.gd",
	"res://scenes/runtime/CardPlayerFacePublicLocalizationSourceService.tscn",
	"res://scenes/runtime/CardCodexPublicSourceService.tscn",
]
const DYNAMIC_POLICY_FIELDS := [
	"weather_type",
	"direct_interaction_role",
	"futures_direction",
	"strategic_role",
]
const ORIGIN_AI_DEBT := {
	"value_reads": 225,
	"presence_checks": 5,
	"functions": 33,
	"keys": 71,
}
const EXPECTED_AI_DEBT := {
	"value_reads": 219,
	"presence_checks": 5,
	"functions": 31,
	"keys": 69,
}

var _checks := 0
var _failures: Array[String] = []
var _started_usec := 0
var _runtime_metrics := {
	"compile_before": -1,
	"compile_after": -1,
	"catalog_cache_hits_before": -1,
	"catalog_cache_hits_after": -1,
	"catalog_snapshot_count": -1,
	"catalog_reload_count": -1,
	"dto_count": -1,
	"family_count": -1,
	"dto_cache_hits": -1,
	"family_cache_hits": -1,
}
var _ai_metrics := EXPECTED_AI_DEBT.duplicate(true)


func _init() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	_scan_production_composition()
	_scan_save_rng_main_and_execution_boundaries()
	_scan_ai_consumer_and_raw_read_ratchets()
	await _exercise_real_codex_chain()
	_expect(
		Time.get_ticks_usec() - _started_usec < 60_000_000,
		"focused invariant gate completes within 60 seconds"
	)
	_finish()


func _scan_production_composition() -> void:
	var scene_source := _read_text(COORDINATOR_SCENE_PATH)
	_expect(
		_count_occurrences(
			scene_source,
			'[node name="CardPlayerFacePublicLocalizationSourceService" parent="." instance=ExtResource("139_card_player_face_public_localization")]'
		) == 1,
		"production coordinator composes exactly one localization source scene instance"
	)
	_expect(
		_count_occurrences(
			scene_source,
			'[node name="CardCodexPublicSourceService" parent="." instance=ExtResource("73_card_codex_public_source")]'
		) == 1,
		"production coordinator composes exactly one Card Codex source scene instance"
	)
	_expect(
		_count_occurrences(
			scene_source,
			'path="res://scenes/runtime/CardPlayerFacePublicLocalizationSourceService.tscn"'
		) == 1,
		"coordinator has exactly one public localization scene dependency"
	)
	_expect(
		_count_occurrences(
			scene_source,
			'path="res://scenes/runtime/CardCodexPublicSourceService.tscn"'
		) == 1,
		"coordinator has exactly one Card Codex source scene dependency"
	)


func _scan_save_rng_main_and_execution_boundaries() -> void:
	var fixed_sections := _string_array_constant(
		_read_text(SAVE_REGISTRY_PATH),
		"FIXED_SECTION_ORDER"
	)
	var unique_sections: Dictionary = {}
	var semantic_or_localization_sections: Array[String] = []
	for section_variant in fixed_sections:
		var section_id := str(section_variant)
		unique_sections[section_id] = true
		var normalized := section_id.to_lower()
		if normalized.contains("semantic") \
				or normalized.contains("localization") \
				or normalized.contains("player_face") \
				or normalized.contains("codex"):
			semantic_or_localization_sections.append(section_id)
	_expect(
		fixed_sections.size() == 19 and unique_sections.size() == 19,
		"Save Registry remains exactly 19 unique sections"
	)
	_expect(
		semantic_or_localization_sections.is_empty(),
		"semantic/localization/Codex Save section count remains zero"
	)

	var production_sources := _source_map(PR_PLAYERFACE_PRODUCTION_PATHS)
	_expect(
		production_sources.size() == PR_PLAYERFACE_PRODUCTION_PATHS.size(),
		"all PR PlayerFace production boundary files are readable"
	)
	var rng_hits := _token_hits(production_sources, [
		"RunRngService",
		"RandomNumberGenerator",
		"func randomize(",
		"func randi(",
		"func randi_range(",
		"func randf(",
		"func randf_range(",
		"rand_from_seed(",
		"detached_randi_range(",
		"detached_randf_range(",
	])
	_expect(
		rng_hits.is_empty(),
		"PlayerFace production boundary adds no RNG owner, draw, or API: %s"
			% str(rng_hits)
	)
	var save_owner_hits := _token_hits(production_sources, [
		"register_save_owner(",
		"save_section_id",
		"func to_save_data(",
		"func apply_save_data(",
	])
	_expect(
		save_owner_hits.is_empty(),
		"PlayerFace production boundary adds no Save owner/API: %s"
			% str(save_owner_hits)
	)

	_expect(
		_sha256_file(MAIN_PATH) == MAIN_BASELINE_SHA256,
		"Main source bytes remain unchanged from origin/main@46b356f"
	)
	var main_source := _read_text(MAIN_PATH)
	var main_duty_hits: Array[String] = []
	for token in [
		"PlayerCardCodexDTO",
		"CardPlayerFacePublicLocalizationSourceService",
		"authorize_public_codex_record",
		"project_authorized_public_detail",
		"card_player_face_public_localization",
	]:
		if main_source.contains(token):
			main_duty_hits.append(token)
	_expect(
		main_duty_hits.is_empty(),
		"Main gains no Codex semantic/localization duty: %s" % str(main_duty_hits)
	)

	var rules_hits := _token_hits(production_sources, [
		"RulesProjection",
		"RuleExecutionPlan",
		"register_handler(",
	])
	_expect(
		rules_hits.is_empty(),
		"PlayerFace production boundary adds no RulesProjection or handler registration: %s"
			% str(rules_hits)
	)
	var runtime_sources := _gd_source_map_recursive(RUNTIME_ROOT)
	var handler_call_sources := runtime_sources.duplicate()
	handler_call_sources.erase(
		"res://scripts/semantic/operation_handler_registry.gd"
	)
	_expect(
		_token_hits(handler_call_sources, ["register_handler("]).is_empty(),
		"production runtime has zero executable handler registration calls"
	)
	var registry := HANDLER_REGISTRY.new()
	var rejected := registry.register_handler({})
	_expect(
		not bool(rejected.get("ok", true))
			and str(rejected.get("status_id", ""))
				== "executable_handler_registration_unavailable"
			and not bool(rejected.get("active_readiness_certified", true)),
		"OperationHandlerRegistry remains metadata-only and fail closed"
	)
	registry.free()


func _scan_ai_consumer_and_raw_read_ratchets() -> void:
	var runtime_sources := _gd_source_map_recursive(RUNTIME_ROOT)
	runtime_sources.erase(AI_PROJECTION_SERVICE_PATH)
	var ai_consumer_hits := _token_hits(runtime_sources, [
		"AiCardSemanticProjectionService",
		"project_authorized_source(",
		'call("project_authorized_source"',
		"project_candidates(",
		'call("project_candidates"',
	])
	_expect(
		ai_consumer_hits.is_empty(),
		"production AI semantic consumer count remains zero: %s"
			% str(ai_consumer_hits)
	)
	var coordinator_scene := _read_text(COORDINATOR_SCENE_PATH)
	_expect(
		_count_occurrences(
			coordinator_scene,
			'[node name="AiCardInteractionObservationService"'
		) == 1
			and _count_occurrences(
				coordinator_scene,
				'path="res://scenes/runtime/AiCardInteractionObservationService.tscn"'
			) == 1,
		"production coordinator composes exactly one interaction observation service"
	)
	var ai_source := _read_text(AI_RUNTIME_PATH)
	_expect(
		ai_source.contains("AiCardInteractionObservationService")
			and ai_source.contains("observe_own_hand_interaction"),
		"production AI consumes only the narrow interaction observation service"
	)
	var observation_callers := runtime_sources.duplicate()
	observation_callers.erase(INTERACTION_OBSERVATION_SERVICE_PATH)
	_expect(
		_paths_calling_tokens(
			observation_callers,
			["observe_own_hand_interaction"]
		) == [AI_RUNTIME_PATH],
		"only production AI invokes the actor-private observation entrypoint"
	)
	for forbidden_direct_source_token in [
		"CardSemanticSourceAuthorizationPort",
		"authorize_own_hand_card",
		"authorize_source(",
	]:
		_expect(
			not ai_source.contains(forbidden_direct_source_token),
			"production AI cannot consume source authorization directly: %s"
				% forbidden_direct_source_token
		)
	var source_consumers := runtime_sources.duplicate()
	source_consumers.erase(SOURCE_AUTHORIZATION_PATH)
	var source_consumer_paths := _paths_calling_tokens(
		source_consumers,
		["authorize_own_hand_card", "authorize_source"]
	)
	_expect(
		source_consumer_paths == [INTERACTION_OBSERVATION_SERVICE_PATH],
		"only interaction observation consumes source authorization: %s"
			% [source_consumer_paths]
	)

	var report := _json_object(AI_DEBT_REPORT_PATH)
	var deterministic_counts := _dictionary(
		report.get("deterministic_counts", {})
	)
	var report_counts := {
		"value_reads": int(deterministic_counts.get("value_reads_total", -1)),
		"presence_checks": int(
			deterministic_counts.get("field_presence_checks", -1)
		),
		"functions": int(deterministic_counts.get("distinct_functions", -1)),
		"keys": int(deterministic_counts.get("distinct_field_keys", -1)),
	}
	_expect(
		report_counts == ORIGIN_AI_DEBT,
		"AI raw-read report remains exactly 225 value / 5 presence / 33 functions / 71 keys"
	)
	var batch_report := _json_object(AI_RAW_READ_BATCH1_REPORT_PATH)
	var batch_counts := _dictionary(batch_report.get("current_lock", {}))
	var current_report_counts := {
		"value_reads": int(batch_counts.get("value_reads", -1)),
		"presence_checks": int(batch_counts.get("presence_checks", -1)),
		"functions": int(batch_counts.get("functions", -1)),
		"keys": int(batch_counts.get("keys", -1)),
	}
	_expect(
		current_report_counts == EXPECTED_AI_DEBT,
		"Batch 1 report freezes the exact 219/5/31/69 current lock"
	)
	_expect(
		int(current_report_counts.get("value_reads", -1))
			<= int(ORIGIN_AI_DEBT.get("value_reads", -1))
			and int(current_report_counts.get("presence_checks", -1))
				<= int(ORIGIN_AI_DEBT.get("presence_checks", -1))
			and int(current_report_counts.get("functions", -1))
				<= int(ORIGIN_AI_DEBT.get("functions", -1))
			and int(current_report_counts.get("keys", -1))
				<= int(ORIGIN_AI_DEBT.get("keys", -1)),
		"Batch 1 debt metrics are monotonic from the immutable origin"
	)
	var removed_signatures: Array = batch_report.get(
		"removed_read_signatures",
		[]
	) as Array
	_expect(
		batch_report.get("removed_origin_rows", []) == ["R03", "R04"]
			and removed_signatures.size() == 6,
		"Batch 1 current lock removes exactly the six R03/R04 signatures"
	)
	_scan_batch1_new_service_raw_aliases(report)
	_scan_source_owner_policy_compatibility(batch_report)
	_ai_metrics = _scan_ai_runtime_raw_reads()
	_expect(
		_ai_metrics == EXPECTED_AI_DEBT,
		"live AiRuntimeController raw reads remain exactly 219/5/31/69: %s"
			% str(_ai_metrics)
	)
	for removal_variant in removed_signatures:
		if not (removal_variant is Dictionary):
			continue
		var removal := removal_variant as Dictionary
		var function_block := _function_block(
			ai_source,
			str(removal.get("function", ""))
		)
		var field_id := str(removal.get("field", ""))
		_expect(
			not function_block.contains('"%s"' % field_id),
			"removed R03/R04 raw signature cannot reappear: %s::%s"
				% [str(removal.get("function", "")), field_id]
		)


func _scan_batch1_new_service_raw_aliases(origin_report: Dictionary) -> void:
	var service_source := _read_text(INTERACTION_OBSERVATION_SERVICE_PATH)
	_expect(not service_source.is_empty(), "Batch 1 interaction observation service is readable")
	var batch1_sources := _source_map([
		INTERACTION_OBSERVATION_SERVICE_PATH,
		INTERACTION_OBSERVATION_SCHEMA_PATH,
		INTERACTION_POLICY_COMPATIBILITY_SCHEMA_PATH,
	])
	_expect(
		batch1_sources.size() == 3,
		"all three Batch 1 interaction observation production files are readable"
	)
	var origin_keys: Dictionary = {}
	for row_variant in origin_report.get("migration_rows", []):
		if not (row_variant is Dictionary):
			continue
		var occurrences := _dictionary(
			(row_variant as Dictionary).get("field_occurrences", {})
		)
		for field_variant in occurrences.keys():
			origin_keys[str(field_variant)] = true
	var reviewed_op_fields := ["target_cash_penalty", "steal_fail_cash"]
	_expect(
		_count_occurrences(service_source, 'op.get("target_cash_penalty"') == 1
			and _count_occurrences(
				service_source,
				'op.get("steal_fail_cash"'
			) == 1,
		"two exact semantic-op adapter reads are reviewed and no others are added"
	)
	var escaped_keys: Array[String] = []
	for path_variant in batch1_sources.keys():
		var path := str(path_variant)
		var source := str(batch1_sources[path])
		for field_variant in origin_keys.keys():
			var field_id := str(field_variant)
			if path == INTERACTION_OBSERVATION_SERVICE_PATH \
					and reviewed_op_fields.has(field_id):
				continue
			if source.contains('"%s"' % field_id):
				escaped_keys.append("%s:%s" % [path, field_id])
	escaped_keys.sort()
	_expect(
		escaped_keys.is_empty(),
		"new observation files contain no unreviewed historical raw-key alias: %s"
			% [escaped_keys]
	)
	for forbidden_alias_token in [
		"effect_payload",
		"source_skill",
		"counter_skill",
		"role_card",
		"raw_payload",
		"raw_card",
	]:
		_expect(
			not service_source.contains(forbidden_alias_token),
			"new interaction observation service contains no raw alias helper escape: %s"
				% forbidden_alias_token
		)
	var raw_carrier_regex := RegEx.new()
	raw_carrier_regex.compile(
		"\\b(skill|source_skill|counter_skill|role_card|raw_payload|raw_card|"
			+ "card_record|card_definition)\\b"
	)
	var raw_carrier_hits: Array[String] = []
	for path_variant in batch1_sources.keys():
		var path := str(path_variant)
		for match_variant in raw_carrier_regex.search_all(
			str(batch1_sources[path])
		):
			raw_carrier_hits.append(
				"%s:%s" % [
					path,
					(match_variant as RegExMatch).get_string(1),
				]
			)
	_expect(
		raw_carrier_hits.is_empty(),
		"new observation files contain no raw carrier or alias identifier: %s"
			% [raw_carrier_hits]
	)


func _scan_source_owner_policy_compatibility(batch_report: Dictionary) -> void:
	var source := _read_text(SOURCE_AUTHORIZATION_PATH)
	var schema := _read_text(INTERACTION_POLICY_COMPATIBILITY_SCHEMA_PATH)
	var function_block := _function_block(
		source,
		"_legacy_interaction_policy_facts"
	)
	var raw_keys: Array[String] = [
		"kind",
		"hand_discard_count",
		"hand_steal_count",
		"hand_lock_seconds",
		"target_cash_penalty",
		"steal_fail_cash",
	]
	var read_regex := RegEx.new()
	read_regex.compile(
		"\\bcard\\.get\\(\\s*\"(%s)\"" % "|".join(raw_keys)
	)
	var observed: Dictionary = {}
	for match_variant in read_regex.search_all(function_block):
		var field_id := (match_variant as RegExMatch).get_string(1)
		observed[field_id] = int(observed.get(field_id, 0)) + 1
	var expected: Dictionary = {}
	for field_id in raw_keys:
		expected[field_id] = 1
	_expect(
		observed == expected
			and read_regex.search_all(source).size() == raw_keys.size(),
		"owner compatibility bridge contains exactly six isolated raw reads"
	)
	var schema_aliases: Array[String] = []
	for field_id in raw_keys:
		if schema.contains('"%s"' % field_id):
			schema_aliases.append(field_id)
	_expect(
		schema_aliases.is_empty(),
		"owner raw keys cannot escape into the wire compatibility schema"
	)
	var owner_lock := _dictionary(batch_report.get(
		"source_owner_compatibility_lock",
		{}
	))
	var combined := _dictionary(batch_report.get(
		"combined_historical_ai_policy_read_ledger",
		{}
	))
	_expect(
		int(owner_lock.get("value_reads", -1)) == 6
			and int(owner_lock.get("presence_checks", -1)) == 0
			and int(owner_lock.get("functions", -1)) == 1
			and int(owner_lock.get("keys", -1)) == 6
			and int(combined.get("value_reads", -1)) == 225
			and int(combined.get("presence_checks", -1)) == 5
			and int(combined.get("functions", -1)) == 32
			and int(combined.get("keys", -1)) == 71,
		"ratchet report distinguishes AI reduction from retained owner bridge"
	)


func _exercise_real_codex_chain() -> void:
	var semantic := SEMANTIC_SCENE.instantiate() as CardSemanticCatalogService
	var localization := LOCALIZATION_SCENE.instantiate() \
		as CardPlayerFacePublicLocalizationSourceService
	var projection := PROJECTION_SCENE.instantiate() \
		as CardPlayerFaceProjectionService
	var snapshot := SNAPSHOT_SCENE.instantiate() \
		as CardCodexPublicSnapshotService
	var source := SOURCE_SCENE.instantiate() as CardCodexPublicSourceService
	_expect(
		semantic != null and localization != null and projection != null \
			and snapshot != null and source != null,
		"real Codex PlayerFace production services instantiate"
	)
	if semantic == null or localization == null or projection == null \
			or snapshot == null or source == null:
		_free_nodes([source, snapshot, projection, localization, semantic])
		return

	semantic.configure_on_ready = false
	root.add_child(semantic)
	root.add_child(localization)
	root.add_child(projection)
	root.add_child(snapshot)
	root.add_child(source)
	await process_frame

	snapshot.configure({})
	var semantic_configuration := semantic.configure()
	var semantic_before := semantic.validation_snapshot()
	_runtime_metrics["compile_before"] = int(
		semantic_before.get("compile_count", -1)
	)
	_runtime_metrics["catalog_cache_hits_before"] = int(
		semantic_before.get("cache_hit_count", -1)
	)
	var localization_configuration := localization.configure(semantic)
	var source_configuration := source.configure({
		"player_face_projection": projection,
		"public_localization_source": localization,
		"semantic_catalog": semantic,
		"snapshot": snapshot,
	})
	_expect(
		bool(semantic_configuration.get("configured", false))
			and bool(localization_configuration.get("configured", false))
			and bool(source_configuration.get("service_ready", false)),
		"real semantic/localization/PlayerFace/Codex chain configures"
	)
	if not bool(source_configuration.get("service_ready", false)):
		_free_nodes([source, snapshot, projection, localization, semantic])
		return

	var configured_debug := source.debug_snapshot()
	var ids: Array[String] = source.ordered_card_ids("all")
	var request := {
		"names": ids,
		"columns": 5,
		"rows": 8,
		"page_index": 0,
		"filter_id": "all",
		"selected_card": ids[0] if not ids.is_empty() else "",
		"run_pool_count": 0,
		"district_supply_count": 0,
	}
	var browser := source.compose_browser(request)
	var hover := source.compose_card_facts(ids[0], 0) \
		if not ids.is_empty() else {}
	var detail := source.compose_detail(ids[0], 0, ids.size()) \
		if not ids.is_empty() else {}
	var final_debug := source.debug_snapshot()
	var semantic_after := semantic.validation_snapshot()

	_runtime_metrics["compile_after"] = int(
		semantic_after.get("compile_count", -1)
	)
	_runtime_metrics["catalog_cache_hits_after"] = int(
		semantic_after.get("cache_hit_count", -1)
	)
	_runtime_metrics["catalog_snapshot_count"] = int(
		final_debug.get("catalog_snapshot_count", -1)
	)
	_runtime_metrics["catalog_reload_count"] = int(
		final_debug.get("catalog_reload_count", -1)
	)
	_runtime_metrics["dto_count"] = int(
		final_debug.get("cached_dto_count", -1)
	)
	_runtime_metrics["family_count"] = int(
		final_debug.get("cached_family_ladder_count", -1)
	)
	_runtime_metrics["dto_cache_hits"] = int(
		final_debug.get("dto_cache_hit_count", -1)
	)
	_runtime_metrics["family_cache_hits"] = int(
		final_debug.get("family_ladder_cache_hit_count", -1)
	)

	_expect(
		ids.size() == 348
			and int(final_debug.get("cached_dto_count", 0)) == 348
			and int(final_debug.get("cached_card_facts_count", 0)) == 348
			and int(final_debug.get("cached_family_ladder_count", 0)) == 87
			and int(final_debug.get("cached_upgrade_facts_count", 0)) == 87,
		"source cache contains exactly 348 DTO/facts and 87 family ladders"
	)
	_expect(
		(browser.get("cards") is Array)
			and (browser.get("cards") as Array).size() == 40
			and bool(hover.get("valid", false))
			and not detail.is_empty(),
		"real browser, hover, and detail paths return production snapshots"
	)
	_expect(
		int(semantic_after.get("compile_count", -1))
				== int(semantic_before.get("compile_count", -2))
			and int(final_debug.get("semantic_compile_delta", -1)) == 0,
		"localization, source configure, browser, hover, and detail compile delta is zero"
	)
	_expect(
		int(configured_debug.get("catalog_snapshot_count", -1)) == 1
			and int(final_debug.get("catalog_snapshot_count", -1)) == 1
			and int(final_debug.get("catalog_reload_count", -1)) == 0
			and int(configured_debug.get(
				"catalog_record_authorization_count", -1
			)) == 348
			and int(final_debug.get(
				"catalog_record_authorization_count", -2
			)) == 348,
		"catalog snapshot is built once, reload count is zero, and interactive reads do not reauthorize"
	)
	_expect(
		int(final_debug.get("dto_projection_count", -1)) == 348
			and int(final_debug.get("localization_issue_count", -1)) == 348
			and int(final_debug.get("dto_cache_hit_count", 0)) > 0
			and int(final_debug.get("family_ladder_cache_hit_count", 0)) > 0,
		"interactive paths use the sealed DTO and family caches"
	)
	_expect(
		int(semantic_after.get("cache_hit_count", -1))
				>= int(semantic_before.get("cache_hit_count", -2)) + 696,
		"348 localization and 348 public authorization reads hit the semantic cache"
	)
	_free_nodes([source, snapshot, projection, localization, semantic])


func _scan_ai_runtime_raw_reads() -> Dictionary:
	var source := _read_text(AI_RUNTIME_PATH)
	var value_regex := RegEx.new()
	var presence_regex := RegEx.new()
	value_regex.compile(
		"\\b(evaluated_skill|source_skill|counter_skill|role_card|skill|role)"
			+ "\\.get\\(\\s*\"([a-z0-9_]+)\""
	)
	presence_regex.compile(
		"\\b(evaluated_skill|source_skill|counter_skill|role_card|skill|role)"
			+ "\\.has\\(\\s*\"([a-z0-9_]+)\""
	)
	var value_count := 0
	var presence_count := 0
	var functions: Dictionary = {}
	var keys: Dictionary = {}
	var current_function := ""
	for raw_line in source.split("\n"):
		var line := str(raw_line)
		var stripped := line.strip_edges()
		if stripped.begins_with("func "):
			current_function = stripped.trim_prefix("func ").get_slice("(", 0)
		for match_variant in value_regex.search_all(line):
			var match_result := match_variant as RegExMatch
			value_count += 1
			functions[current_function] = true
			keys[match_result.get_string(2)] = true
		for match_variant in presence_regex.search_all(line):
			var match_result := match_variant as RegExMatch
			presence_count += 1
			functions[current_function] = true
			keys[match_result.get_string(2)] = true

	var dynamic_shape_valid := \
		_count_occurrences(source, "skill.has(field_name)") == 1 \
		and _count_occurrences(source, "skill[field_name]") == 1 \
		and _count_nonliteral_receiver_calls(source) == 1 \
		and _count_nonliteral_receiver_indexes(source) == 1
	_expect(
		dynamic_shape_valid,
		"AI raw-read ratchet retains one audited four-field dynamic policy loop"
	)
	for field_id in DYNAMIC_POLICY_FIELDS:
		value_count += 1
		presence_count += 1
		functions["_ai_policy_family_for_kind"] = true
		keys[field_id] = true
	return {
		"value_reads": value_count,
		"presence_checks": presence_count,
		"functions": functions.size(),
		"keys": keys.size(),
	}


func _gd_source_map_recursive(root_path: String) -> Dictionary:
	var paths: Array[String] = []
	_collect_gd_paths(root_path, paths)
	return _source_map(paths)


func _collect_gd_paths(directory_path: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		_expect(false, "production source directory is readable: %s" % directory_path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var child_path := "%s/%s" % [directory_path, entry]
			if directory.current_is_dir():
				_collect_gd_paths(child_path, paths)
			elif entry.ends_with(".gd"):
				paths.append(child_path)
		entry = directory.get_next()
	directory.list_dir_end()


func _source_map(paths: Array) -> Dictionary:
	var result: Dictionary = {}
	for path_variant in paths:
		var path := str(path_variant)
		if FileAccess.file_exists(path):
			result[path] = _read_text(path)
	return result


func _token_hits(sources: Dictionary, tokens: Array) -> Array[String]:
	var hits: Array[String] = []
	for path_variant in sources.keys():
		var path := str(path_variant)
		var source := str(sources.get(path, ""))
		for token_variant in tokens:
			var token := str(token_variant)
			if source.contains(token):
				hits.append("%s:%s" % [path, token])
	return hits


func _paths_calling_tokens(sources: Dictionary, tokens: Array) -> Array[String]:
	var paths: Array[String] = []
	for path_variant in sources.keys():
		var path := str(path_variant)
		var source := str(sources.get(path, ""))
		for token_variant in tokens:
			if source.contains(str(token_variant)):
				paths.append(path)
				break
	paths.sort()
	return paths


func _function_block(source: String, function_id: String) -> String:
	var lines: Array[String] = []
	var collecting := false
	for raw_line in source.split("\n"):
		var line := str(raw_line)
		var stripped := line.strip_edges()
		if stripped.begins_with("func "):
			if collecting:
				break
			collecting = stripped.begins_with("func %s(" % function_id)
		if collecting:
			lines.append(line)
	return "\n".join(lines)


func _json_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_expect(false, "JSON report exists: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(_read_text(path))
	_expect(parsed is Dictionary, "JSON report parses: %s" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _sha256_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()


func _read_text(path: String) -> String:
	return FileAccess.get_file_as_bytes(path).get_string_from_utf8() \
		if FileAccess.file_exists(path) else ""


func _count_nonliteral_receiver_calls(source: String) -> int:
	var regex := RegEx.new()
	regex.compile(
		"\\b(evaluated_skill|source_skill|counter_skill|role_card|skill|role)"
			+ "\\.(get|has)\\(\\s*[a-zA-Z_][a-zA-Z0-9_]*"
	)
	return regex.search_all(source).size()


func _count_nonliteral_receiver_indexes(source: String) -> int:
	var regex := RegEx.new()
	regex.compile(
		"\\b(evaluated_skill|source_skill|counter_skill|role_card|skill|role)"
			+ "\\[\\s*[a-zA-Z_][a-zA-Z0-9_]*\\s*\\]"
	)
	return regex.search_all(source).size()


func _count_occurrences(source: String, token: String) -> int:
	return 0 if token.is_empty() else source.split(token).size() - 1


func _string_array_constant(source: String, constant_id: String) -> Array[String]:
	var result: Array[String] = []
	var collecting := false
	var literal_regex := RegEx.new()
	literal_regex.compile('"([a-z0-9_]+)"')
	for raw_line in source.split("\n"):
		var line := str(raw_line).strip_edges()
		if not collecting:
			collecting = line.begins_with("const %s := [" % constant_id)
			continue
		if line == "]":
			break
		var match_result := literal_regex.search(line)
		if match_result != null:
			result.append(match_result.get_string(1))
	return result


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _free_nodes(nodes: Array) -> void:
	for node_variant in nodes:
		if node_variant is Node and is_instance_valid(node_variant):
			(node_variant as Node).free()


func _expect(condition: bool, failure_id: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(failure_id)


func _finish() -> void:
	var duration_ms := snappedf(
		float(Time.get_ticks_usec() - _started_usec) / 1000.0,
		0.001
	)
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"CARD_CODEX_PLAYERFACE_RUNTIME_INVARIANTS_TEST|status=%s|checks=%d|failures=%d|duration_ms=%.3f|compile_before=%d|compile_after=%d|catalog_cache_hits_before=%d|catalog_cache_hits_after=%d|catalog_snapshot_count=%d|catalog_reload_count=%d|dto_count=%d|family_count=%d|dto_cache_hits=%d|family_cache_hits=%d|ai_value_reads=%d|ai_presence_checks=%d|ai_functions=%d|ai_keys=%d|details=%s"
		% [
			status,
			_checks,
			_failures.size(),
			duration_ms,
			int(_runtime_metrics.get("compile_before", -1)),
			int(_runtime_metrics.get("compile_after", -1)),
			int(_runtime_metrics.get("catalog_cache_hits_before", -1)),
			int(_runtime_metrics.get("catalog_cache_hits_after", -1)),
			int(_runtime_metrics.get("catalog_snapshot_count", -1)),
			int(_runtime_metrics.get("catalog_reload_count", -1)),
			int(_runtime_metrics.get("dto_count", -1)),
			int(_runtime_metrics.get("family_count", -1)),
			int(_runtime_metrics.get("dto_cache_hits", -1)),
			int(_runtime_metrics.get("family_cache_hits", -1)),
			int(_ai_metrics.get("value_reads", -1)),
			int(_ai_metrics.get("presence_checks", -1)),
			int(_ai_metrics.get("functions", -1)),
			int(_ai_metrics.get("keys", -1)),
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
