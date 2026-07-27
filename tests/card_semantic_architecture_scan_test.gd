extends SceneTree

const SAVE_REGISTRY := preload("res://scripts/runtime/v06_save_owner_registry.gd")

const AI_DEBT_REPORT_PATH := "res://reports/cards/ai_direct_field_read_migration.json"
const AI_RAW_READ_BATCH1_REPORT_PATH := \
	"res://reports/cards/ai_raw_read_ratchet_batch1.json"
const NAME_KIND_REPORT_PATH := "res://reports/semantic_program/name_and_kind_special_case_audit.json"
const AI_RUNTIME_PATH := "res://scripts/runtime/ai_runtime_controller.gd"
const CATALOG_SERVICE_PATH := "res://scripts/runtime/card_semantic_catalog_service.gd"
const SOURCE_AUTHORIZATION_PATH := "res://scripts/runtime/card_semantic_source_authorization_port.gd"
const AI_PROJECTION_SERVICE_PATH := \
	"res://scripts/runtime/ai_card_semantic_projection_service.gd"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const COORDINATOR_SCRIPT_PATH := "res://scripts/runtime/game_runtime_coordinator.gd"
const INTERACTION_OBSERVATION_SERVICE_PATH := \
	"res://scripts/runtime/ai_card_interaction_observation_service.gd"
const INTERACTION_OBSERVATION_SCHEMA_PATH := \
	"res://scripts/semantic/ai_card_interaction_observation_v1.gd"
const INTERACTION_POLICY_COMPATIBILITY_SCHEMA_PATH := \
	"res://scripts/semantic/ai_card_interaction_policy_compatibility_v1.gd"
const INTERACTION_LEGACY_SOURCE_BUNDLE_PATH := \
	"res://scripts/semantic/ai_card_interaction_legacy_source_bundle_v1.gd"
const LEGACY_V04_REFERENCE_ADAPTER_PATH := \
	"res://scripts/cards/semantic/card_v04_interaction_semantic_reference_adapter_v1.gd"
const INTERACTION_OBSERVATION_SCENE_PATH := \
	"res://scenes/runtime/AiCardInteractionObservationService.tscn"
const INTERACTION_OBSERVATION_TEST_PATH := \
	"res://tests/ai_card_interaction_observation_test.gd"
const GENUINE_V04_COMPATIBILITY_TEST_PATH := \
	"res://tests/ai_card_interaction_genuine_v04_compatibility_test.gd"
const CARD_CODEX_SOURCE_PATH := \
	"res://scripts/runtime/card_codex_public_source_service.gd"
const PLAYER_FACE_PROJECTION_SERVICE_PATH := \
	"res://scripts/runtime/card_player_face_projection_service.gd"
const PUBLIC_LOCALIZATION_SOURCE_PATH := \
	"res://scripts/runtime/card_player_face_public_localization_source_service.gd"
const LEGACY_V04_REFERENCE_ADAPTER := preload(
	"res://scripts/cards/semantic/card_v04_interaction_semantic_reference_adapter_v1.gd"
)
const INTERACTION_LEGACY_SOURCE_BUNDLE := preload(
	"res://scripts/semantic/ai_card_interaction_legacy_source_bundle_v1.gd"
)
const EXPECTED_LEGACY_V04_INTERACTION_REFERENCE_HASHES := [
	"049375e10ed990fc6195cdfdd4a46d3a038465398ce538680810f76afe0ca970",
	"19a845ba97fc178ae46a8ae0b4f38677d1142eab8042ab39f762c9b6a227cdc2",
	"5d0ac6306835115dbdff9c6236bd530a55e44d7e35905bdf2994ead30c9c2a37",
	"5fb4535d1cc88a1ef94eb61123584b9d3f3877f14449c6def1f315bdb7b022d1",
	"6bde0574c509fe021f385119d50e47f6e637fe633f8206c3ee5f694633581215",
	"71d597ba77c4d4beff36fc46a3320a5603ca6e892798ec04b8957990607c4ce0",
	"9c9c76c6e245d411a2ae193cc2e87ef2df29065f7659ae434b79bd4d2750c756",
	"e162388ed17821f3a972e09a4483ee548e1f523c23fe200863c0dff5fbb151fe",
]

const SEMANTIC_SOURCE_PATHS := [
	"res://scripts/cards/semantic/card_semantic_schema_v1.gd",
	"res://scripts/cards/semantic/card_semantic_compiler_v1.gd",
	"res://scripts/cards/semantic/authorized_card_semantic_envelope_v1.gd",
	"res://scripts/cards/semantic/card_instance_decision_state_v1.gd",
	LEGACY_V04_REFERENCE_ADAPTER_PATH,
	INTERACTION_LEGACY_SOURCE_BUNDLE_PATH,
	"res://scripts/semantic/ai_card_interaction_policy_compatibility_v1.gd",
	"res://scripts/runtime/card_semantic_catalog_service.gd",
	"res://scripts/runtime/card_semantic_source_authorization_port.gd",
	"res://scripts/runtime/ai_card_semantic_projection_service.gd",
	"res://scripts/runtime/ai_card_semantic_projection_input_v1.gd",
	"res://scripts/runtime/ai_outcome_vector_v1.gd",
	"res://scripts/runtime/card_player_face_projection_service.gd",
	"res://scripts/presentation/player_face_dto_v1.gd",
]
const AI_SEMANTIC_SOURCE_PATHS := [
	"res://scripts/runtime/ai_card_semantic_projection_service.gd",
	"res://scripts/runtime/ai_card_semantic_projection_input_v1.gd",
	"res://scripts/runtime/ai_outcome_vector_v1.gd",
	"res://scripts/cards/semantic/card_instance_decision_state_v1.gd",
	INTERACTION_LEGACY_SOURCE_BUNDLE_PATH,
]
const PLAYER_FACE_SOURCE_PATHS := [
	"res://scripts/runtime/card_player_face_projection_service.gd",
	"res://scripts/presentation/player_face_dto_v1.gd",
]
const CARD_SCHEMA_TABLE_IDS := [
	"ASSET_KEYS",
	"CATEGORY_IDS",
	"INDUSTRY_IDS",
	"TIMING_IDS",
	"TARGET_IDS",
	"SELECTION_IDS",
	"CARDINALITY_IDS",
	"TARGET_FILTER_IDS",
	"RESPONSE_IDS",
	"RUNTIME_READINESS_IDS",
	"SOURCE_KINDS",
	"SOURCE_VISIBILITY_SCOPES",
	"FACILITY_PROFILE_FIELDS",
	"ORGANIZATION_CAPABILITY_FIELDS",
	"OP_FIELDS",
]
const DYNAMIC_POLICY_FIELDS := [
	"weather_type",
	"direct_interaction_role",
	"futures_direction",
	"strategic_role",
]
const RAW_ACCESS_RECEIVER_TOKEN_LIMIT := 32
const PROJECT_PRODUCTION_GDSCRIPT_EXCLUDED_PREFIXES := [
	"res://tests/",
	"res://tools/",
	"res://addons/",
	"res://reports/",
	"res://scripts/tools/",
]

var _checks := 0
var _failures: Array[String] = []
var _started_usec := 0
var _debt_snapshot := {
	"value_reads": -1,
	"presence_checks": -1,
	"functions": -1,
	"keys": -1,
	"new_violations": -1,
}


func _init() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	_scan_semantic_source_boundaries()
	_scan_ai_projection_boundary()
	_scan_player_face_boundary()
	_scan_catalog_service_surface()
	_scan_codex_only_player_face_cutover()
	_scan_authorized_source_boundary()
	_scan_legacy_v04_interaction_reference_bridge()
	_scan_ai_interaction_observation_boundary()
	_scan_source_owner_policy_compatibility_bridge()
	_scan_save_registry_contract()
	_scan_ai_raw_field_debt()
	_scan_project_production_direct_literal_access_lock()
	_scan_name_kind_audit()
	_finish()


func _scan_semantic_source_boundaries() -> void:
	var sources := _source_map(SEMANTIC_SOURCE_PATHS)
	_expect(sources.size() == SEMANTIC_SOURCE_PATHS.size(), "all semantic production sources are readable")
	var dependency_tokens := [
		"/root/Main",
		"res://scripts/main.gd",
		"get_tree().current_scene",
		"current_scene",
	]
	var save_tokens := [
		"FileAccess",
		"DirAccess",
		"to_save_data",
		"apply_save_data",
		"save_section",
		"compose_envelope",
		"restore_envelope",
	]
	var rng_tokens := [
		"randomize(",
		"randi(",
		"randf(",
		"rand_from_seed(",
		"RandomNumberGenerator",
		"RunRngService",
	]
	_expect(_token_hits(sources, dependency_tokens).is_empty(), "semantic sources have no Main or current-scene dependency")
	_expect(_token_hits(sources, save_tokens).is_empty(), "semantic sources own no save or filesystem surface")
	_expect(_token_hits(sources, rng_tokens).is_empty(), "semantic sources consume no RNG")
	_expect(_token_hits(sources, ["Callable", "Object"]).is_empty(), "semantic sources carry no Callable or Object payload")

	var node_payload_hits: Array[String] = []
	var localized_source_hits: Array[String] = []
	for path_variant in sources.keys():
		var path := str(path_variant)
		var source := str(sources[path])
		var node_payload_source := source.replace("extends Node", "").replace("NodePath", "")
		if _count_occurrences(node_payload_source, "Node") != 0:
			node_payload_hits.append(path)
		if _contains_non_ascii(source):
			localized_source_hits.append(path)
	_expect(node_payload_hits.is_empty(), "Node appears only as a service base class, never as payload data")
	_expect(localized_source_hits.is_empty(), "semantic production source contains no localized rule literals")

	var compiler_and_ai := _combined_source([
		"res://scripts/cards/semantic/card_semantic_compiler_v1.gd",
		"res://scripts/runtime/ai_card_semantic_projection_service.gd",
		"res://scripts/runtime/ai_card_semantic_projection_input_v1.gd",
		"res://scripts/runtime/ai_outcome_vector_v1.gd",
	])
	for forbidden in [
		"card_record[\"player\"]",
		"card_record.get(\"player\"",
		"short_effect",
		"rules_text",
		"tooltip",
		"localized_text",
		"raw_text",
	]:
		_expect(not compiler_and_ai.contains(forbidden), "compiler and AI omit localized rule source: %s" % forbidden)


func _scan_ai_projection_boundary() -> void:
	var source := _combined_source(AI_SEMANTIC_SOURCE_PATHS)
	for forbidden in [
		"effect_payload",
		".get(\"skill\"",
		"[\"skill\"]",
		"skill.get(",
		"skill.has(",
		"compile_",
		".compile(",
		"catalog_snapshot(",
		"exact_definition(",
		"derived_definition(",
		".reload(",
		"CardRuntimeCatalog",
	]:
		_expect(not source.contains(forbidden), "AI semantic projection omits raw or catalog operation: %s" % forbidden)
	_expect(not source.replace("preload(", "").contains("load("), "AI candidate projection performs no runtime load")
	for table_id in CARD_SCHEMA_TABLE_IDS:
		_expect(not source.contains("const %s " % table_id), "AI projection does not duplicate Card schema table %s" % table_id)


func _scan_player_face_boundary() -> void:
	var source := _combined_source(PLAYER_FACE_SOURCE_PATHS)
	var service_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/card_player_face_projection_service.gd"
	)
	_expect(
		service_source.contains('preload("res://scripts/cards/semantic/card_semantic_schema_v1.gd")')
			and service_source.contains("CardSemanticSchema.validate_semantic_spec(spec)"),
		"PlayerFace delegates semantic validation to the sole Card schema"
	)
	for table_id in CARD_SCHEMA_TABLE_IDS:
		_expect(not source.contains("const %s " % table_id), "PlayerFace does not duplicate Card schema table %s" % table_id)
	for alias_id in ["cost", "price", "play_cost", "effect", "text", "description", "type", "category", "level", "stats"]:
		_expect(not source.contains('"%s":' % alias_id), "PlayerFace emits no legacy alias %s" % alias_id)
	for alias_id in ["price", "play_cost", "effect", "text", "description", "type", "category", "level", "stats"]:
		_expect(
			not source.contains('.get("%s"' % alias_id) and not source.contains('["%s"]' % alias_id),
			"PlayerFace reads no legacy alias %s" % alias_id
		)
	_expect(
		not service_source.contains(".contains(")
			and not service_source.contains(".begins_with(")
			and not service_source.contains(".ends_with("),
		"PlayerFace service performs no text or suffix rule inference"
	)


func _scan_catalog_service_surface() -> void:
	var source := FileAccess.get_file_as_string(CATALOG_SERVICE_PATH)
	var public_methods: Array[String] = []
	for raw_line in source.split("\n"):
		var line := str(raw_line).strip_edges()
		if not line.begins_with("func "):
			continue
		var method_id := line.trim_prefix("func ").get_slice("(", 0).strip_edges()
		if not method_id.begins_with("_"):
			public_methods.append(method_id)
	public_methods.sort()
	var pre_codex_methods: Array[String] = [
		"authorize_semantic_spec",
		"compile_authorized",
		"configure",
		"debug_snapshot",
		"validation_snapshot",
	]
	var expected_methods: Array[String] = [
		"authorize_public_codex_record",
		"authorize_v04_interaction_effect_witness",
	]
	expected_methods.append_array(pre_codex_methods)
	expected_methods.sort()
	_expect(
		public_methods == expected_methods,
		"CardSemanticCatalogService exposes only authorized semantic access and aggregate diagnostics"
	)
	var catalog_method_delta := public_methods.duplicate()
	for method_id in pre_codex_methods:
		catalog_method_delta.erase(method_id)
	_expect(
		catalog_method_delta == [
			"authorize_public_codex_record",
			"authorize_v04_interaction_effect_witness",
		],
		"catalog adds only public Codex authorization and the closed v0.4 effect witness"
	)
	var public_codex_block := _function_block(
		source,
		"authorize_public_codex_record"
	)
	_expect(
		public_codex_block.begins_with(
			"func authorize_public_codex_record(request: Dictionary) -> Dictionary:"
		),
		"public Codex authorization accepts only the closed record request"
	)
	_expect(
		public_codex_block.contains('request.get("catalog_member_id"')
			and public_codex_block.contains('request.get("catalog_ordinal"')
			and public_codex_block.contains(
				'request.get("catalog_membership_fingerprint"'
			)
			and public_codex_block.contains(
				'request.get("source_record_fingerprint"'
			)
			and public_codex_block.contains('request.get("card_record"')
			and public_codex_block.contains(
				"_authorized_card_ids_by_catalog_ordinal[catalog_ordinal] != card_id"
			)
			and public_codex_block.contains(
				"_authorized_record_canonical_by_card_id.get(card_id"
			),
		"public Codex authorization binds an exact catalog member and full record"
	)
	var arbitrary_access_methods: Array[String] = []
	for method_id in public_methods:
		if method_id.contains("card_id") \
				or method_id.begins_with("get_") \
				or method_id.begins_with("find_") \
				or method_id.begins_with("lookup_") \
				or method_id.begins_with("list_") \
				or method_id.begins_with("enumerate_") \
				or method_id.begins_with("all_"):
			arbitrary_access_methods.append(method_id)
	_expect(
		arbitrary_access_methods.is_empty(),
		"catalog exposes no arbitrary-ID lookup or enumeration method"
	)
	for forbidden in [
		"func semantic_for_card_id",
		"func semantic_spec_for_card_id",
		"func authorize_card_id",
		"func authorize_public_card_id",
		"func card_ids",
		"func ordered_card_ids",
		"func list_",
		"func enumerate_",
		"func catalog_snapshot",
		"func cache_snapshot",
		"func compiled_specs",
		"func all_specs",
		"_cache.keys",
		'"specs":',
		'"card_ids":',
		'"cache_entries":',
	]:
		_expect(not source.contains(forbidden), "catalog service exposes no semantic enumeration: %s" % forbidden)


func _scan_codex_only_player_face_cutover() -> void:
	var production_sources := _production_source_map()
	var expected_token_paths := {
		"authorize_public_codex_record": [
			CATALOG_SERVICE_PATH,
			CARD_CODEX_SOURCE_PATH,
		],
		"project_authorized_public_detail": [
			PLAYER_FACE_PROJECTION_SERVICE_PATH,
			CARD_CODEX_SOURCE_PATH,
		],
		"issue_for_exact_record": [
			PUBLIC_LOCALIZATION_SOURCE_PATH,
			CARD_CODEX_SOURCE_PATH,
		],
		"verify_bundle": [
			PUBLIC_LOCALIZATION_SOURCE_PATH,
			CARD_CODEX_SOURCE_PATH,
		],
	}
	for token_variant in expected_token_paths.keys():
		var token := str(token_variant)
		var observed_paths: Array[String] = []
		for path_variant in production_sources.keys():
			var path := str(path_variant)
			if str(production_sources[path]).contains(token):
				observed_paths.append(path)
		observed_paths.sort()
		var expected_paths: Array = expected_token_paths[token]
		expected_paths.sort()
		_expect(
			observed_paths == expected_paths,
			"Card PlayerFace production API is Codex-only: %s paths=%s"
				% [token, observed_paths]
		)
	var codex_dto_paths: Array[String] = []
	for path_variant in production_sources.keys():
		var path := str(path_variant)
		if str(production_sources[path]).contains("player_card_codex_"):
			codex_dto_paths.append(path)
	var non_codex_dto_consumers: Array[String] = []
	for path in codex_dto_paths:
		if not path.contains("card_codex"):
			non_codex_dto_consumers.append(path)
	_expect(
		not codex_dto_paths.is_empty() and non_codex_dto_consumers.is_empty(),
		"PlayerCardCodex DTO has no market, hand, track, AI, or Rules consumer"
	)
	var player_face_dto_source := FileAccess.get_file_as_string(
		"res://scripts/presentation/player_face_dto_v1.gd"
	)
	_expect(
		not player_face_dto_source.contains('"codex"'),
		"PlayerFaceDTOv1 surface enum remains frozen; Codex uses its specialization"
	)


func _scan_authorized_source_boundary() -> void:
	var source := FileAccess.get_file_as_string(SOURCE_AUTHORIZATION_PATH)
	var coordinator_scene := FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH)
	var coordinator_source := FileAccess.get_file_as_string(COORDINATOR_SCRIPT_PATH)
	_expect(not source.is_empty(), "authorized semantic source port is readable")
	_expect(
		_count_occurrences(
			coordinator_scene,
			'[node name="CardSemanticSourceAuthorizationPort"'
		) == 1,
		"production coordinator composes exactly one source authorization port"
	)
	var source_wiring_block := _function_block(
		coordinator_source,
		"_wire_card_semantic_source_authorization_port"
	)
	_expect(
		not source_wiring_block.is_empty()
			and not source_wiring_block.contains(".is_ready("),
		"pre-session fail-closed readiness is not reported as a startup error"
	)
	for forbidden in [
		"world_session_state_path",
		"WorldSessionState",
		".players",
		"world_session_state()",
		"current_scene",
		"res://scripts/main.gd",
		"/root/Main",
		"v06_card_definition",
		"v06_card_player_snapshot",
		"card_snapshot(",
		"catalog_snapshot(",
		"ordered_card_ids(",
		"card_ids(",
		"register_handler(",
		"RuleExecutionPlan",
		"RulesProjection",
		"to_save_data",
		"apply_save_data",
		"register_save_owner",
		"RunRngService",
		"RandomNumberGenerator",
		"randf(",
		"randi(",
		"func _process(",
		"func _physics_process(",
	]:
		_expect(
			not source.contains(forbidden),
			"source authorization port omits forbidden dependency: %s" % forbidden
		)
	var public_methods: Array[String] = []
	for raw_line in source.split("\n"):
		var line := str(raw_line).strip_edges()
		if line.begins_with("func "):
			var method_id := line.trim_prefix("func ").get_slice("(", 0).strip_edges()
			if not method_id.begins_with("_"):
				public_methods.append(method_id)
	public_methods.sort()
	var expected_methods: Array[String] = [
		"authorize_own_hand_interaction_policy_compatibility",
		"authorize_own_hand_card",
		"authorize_own_hand_v04_interaction_observation_source",
		"authorize_source",
		"bind_actor_capability",
		"bind_ai_capability",
		"debug_snapshot",
		"is_ready",
		"seal_actor_capabilities",
		"validate_authorized_bundle",
	]
	expected_methods.sort()
	_expect(
		public_methods == expected_methods,
		"source authorization port exposes only the closed own-hand surface"
	)
	var production_consumer_source := "\n".join([
		FileAccess.get_file_as_string(AI_RUNTIME_PATH),
		FileAccess.get_file_as_string("res://scripts/main.gd"),
		FileAccess.get_file_as_string(
			"res://scripts/runtime/card_presentation_runtime_service.gd"
		),
	])
	for forbidden_consumer in [
		"CardSemanticSourceAuthorizationPort",
		"project_authorized_source(",
		"AiCardSemanticProjectionService",
	]:
		_expect(
			not production_consumer_source.contains(forbidden_consumer),
			"production AI/UI/Main has no semantic cutover consumer: %s"
				% forbidden_consumer
		)
	var production_sources := _production_source_map()
	_expect(
		production_sources.size() > SEMANTIC_SOURCE_PATHS.size(),
		"semantic cutover ratchet scans the complete production script tree"
	)
	var compatibility_consumers := production_sources.duplicate()
	compatibility_consumers.erase(AI_PROJECTION_SERVICE_PATH)
	_expect(
		_token_hits(compatibility_consumers, ["project_candidates"]).is_empty(),
		"production scripts cannot call the compatibility projection entry"
	)
	_expect(
		_token_hits(
			compatibility_consumers,
			["project_authorized_source"]
		).is_empty(),
		"production scripts cannot activate the authorized shadow projection"
	)
	var source_consumers := production_sources.duplicate()
	source_consumers.erase(SOURCE_AUTHORIZATION_PATH)
	var source_consumer_paths := _paths_calling_tokens(
		source_consumers,
		["authorize_own_hand_card", "authorize_source"]
	)
	_expect(
		source_consumer_paths == [INTERACTION_OBSERVATION_SERVICE_PATH],
		"only the interaction observation service consumes source authorization: %s"
			% [source_consumer_paths]
	)


func _scan_legacy_v04_interaction_reference_bridge() -> void:
	var adapter_source := FileAccess.get_file_as_string(
		LEGACY_V04_REFERENCE_ADAPTER_PATH
	)
	var bundle_source := FileAccess.get_file_as_string(
		INTERACTION_LEGACY_SOURCE_BUNDLE_PATH
	)
	var source_port := FileAccess.get_file_as_string(SOURCE_AUTHORIZATION_PATH)
	var catalog_service := FileAccess.get_file_as_string(CATALOG_SERVICE_PATH)
	_expect(
		not adapter_source.is_empty()
			and not bundle_source.is_empty()
			and not source_port.is_empty()
			and not catalog_service.is_empty(),
		"legacy v0.4 interaction bridge sources are readable"
	)

	var entries: Dictionary = (
		LEGACY_V04_REFERENCE_ADAPTER.ENTRY_BY_LEGACY_ID_FINGERPRINT
	)
	var observed_hashes: Array[String] = []
	var entry_shape_failures: Array[String] = []
	var family_ranks: Dictionary = {}
	var expected_entry_keys := [
		"interaction_kind_id",
		"semantic_card_id",
		"semantic_family_id",
		"semantic_rank",
	]
	for hash_variant in entries.keys():
		var legacy_id_hash := str(hash_variant)
		observed_hashes.append(legacy_id_hash)
		var entry_value: Variant = entries.get(hash_variant)
		if not (entry_value is Dictionary):
			entry_shape_failures.append("%s:not_dictionary" % legacy_id_hash)
			continue
		var entry := entry_value as Dictionary
		var entry_keys: Array = entry.keys()
		entry_keys.sort()
		if entry_keys != expected_entry_keys:
			entry_shape_failures.append("%s:keys=%s" % [legacy_id_hash, entry_keys])
		var family_id := str(entry.get("semantic_family_id", ""))
		var rank := int(entry.get("semantic_rank", 0))
		var ranks: Array = family_ranks.get(family_id, []) as Array
		ranks.append(rank)
		family_ranks[family_id] = ranks
	observed_hashes.sort()
	_expect(
		observed_hashes == EXPECTED_LEGACY_V04_INTERACTION_REFERENCE_HASHES,
		"legacy v0.4 adapter retains exactly the eight reviewed ID hashes"
	)
	_expect(
		entry_shape_failures.is_empty(),
		"legacy v0.4 reference entries remain closed: %s"
			% [entry_shape_failures]
	)
	var expected_family_ranks := {
		"interaction.shadow_warehouse_traction": [1, 2, 3, 4],
		"interaction.starlink_dismantle": [1, 2, 3, 4],
	}
	for family_variant in family_ranks.keys():
		(family_ranks[family_variant] as Array).sort()
	_expect(
		family_ranks == expected_family_ranks,
		"legacy v0.4 reference maps only two reviewed families at ranks I-IV"
	)
	var resolve_block := _function_block(adapter_source, "resolve")
	_expect(
		resolve_block.contains("source_card_id.sha256_text()")
			and resolve_block.contains(
				"ENTRY_BY_LEGACY_ID_FINGERPRINT.get("
			),
		"legacy v0.4 identity resolution is an exact hashed-ID lookup"
	)
	for parser_token in [
		".contains(",
		".begins_with(",
		".ends_with(",
		".split(",
		".substr(",
		".to_int(",
		"RegEx",
		"display_name",
		"roman",
	]:
		_expect(
			not resolve_block.to_lower().contains(parser_token.to_lower()),
			"legacy v0.4 reference resolve is parser-free: %s" % parser_token
		)

	var reviewed_runtime_only_keys: Array = (
		LEGACY_V04_REFERENCE_ADAPTER.REVIEWED_RUNTIME_ONLY_KEYS.duplicate()
	)
	var expected_runtime_only_keys := [
		"card_id",
		"cooldown",
		"cooldown_left",
		"counts_toward_hand_limit",
		"display_name",
		"lock_left",
		"persistent",
		"play_region_gdp_share_required",
		"play_region_scope",
		"play_requirement_kind",
		"queued_for_resolution",
		"runtime_instance_id",
		"supply_product",
		"use_case",
	]
	reviewed_runtime_only_keys.sort()
	expected_runtime_only_keys.sort()
	_expect(
		reviewed_runtime_only_keys == expected_runtime_only_keys,
		"legacy v0.4 runtime-only fields remain an exact reviewed allowlist"
	)
	var runtime_match_block := _function_block(
		adapter_source,
		"_runtime_card_matches_definition"
	)
	_expect(
		runtime_match_block.contains(
			"for runtime_key in REVIEWED_RUNTIME_ONLY_KEYS"
		)
			and runtime_match_block.contains(
				"definition_key != definition_key.to_lower()"
			)
			and runtime_match_block.contains(
				"runtime_key != runtime_key.to_lower()"
			)
			and runtime_match_block.contains(
				"not allowed_keys.has(runtime_key)"
			),
		"legacy v0.4 adapter normalizes every key and rejects unknown fields"
	)
	var v04_hostile_test_source := FileAccess.get_file_as_string(
		GENUINE_V04_COMPATIBILITY_TEST_PATH
	)
	var v04_adversarial_block := _function_block(
		v04_hostile_test_source,
		"_run_adversarial_cases"
	)
	_expect(
		not v04_adversarial_block.is_empty()
			and v04_adversarial_block.contains('"future_private_value"')
			and v04_adversarial_block.contains('"Effect_Payload"')
			and v04_adversarial_block.contains(
				'"unknown extra value channel"'
			)
			and v04_adversarial_block.contains(
				'"case-variant value channel"'
			)
			and v04_adversarial_block.contains("observation.is_empty()"),
		"v0.4 hostile coverage rejects unknown and non-normalized runtime keys"
	)

	var generic_authorize_block := _function_block(
		source_port,
		"_authorize_own_hand_card"
	)
	var generic_material_block := _function_block(source_port, "_source_material")
	_expect(
		generic_authorize_block.contains("_source_material(attestation)")
			and not generic_authorize_block.contains(
				"_legacy_v04_interaction_material"
			),
		"generic source authorization cannot fall through to the v0.4 adapter"
	)
	_expect(
		generic_material_block.contains(
			'for block_id in ["machine", "player", "developer"]'
		)
			and generic_material_block.contains(
				'var card_id := str(machine.get("card_id", ""))'
			)
			and not generic_material_block.contains(
				"LEGACY_V04_INTERACTION_REFERENCE"
			)
			and not generic_material_block.contains("exact_definition("),
		"generic source authorization still rejects flat v0.4 card records"
	)
	for forbidden_catalog_copy in [
		"CardRuntimeCatalogV06Resource",
		"card_runtime_catalog_v06_resource.gd",
		"_authorized_record_canonical_by_card_id",
		"_authorized_specs_by_card_id",
		"_public_catalog_membership_fingerprint",
	]:
		_expect(
			not source_port.contains(forbidden_catalog_copy),
			"source port embeds no v0.6 catalog/resource copy: %s"
				% forbidden_catalog_copy
		)

	var production_sources := _production_source_map()
	var v04_source_callers := production_sources.duplicate()
	v04_source_callers.erase(SOURCE_AUTHORIZATION_PATH)
	_expect(
		_paths_calling_tokens(
			v04_source_callers,
			["authorize_own_hand_v04_interaction_observation_source"]
		) == [INTERACTION_OBSERVATION_SERVICE_PATH],
		"only the observation service calls v0.4 own-hand source authorization"
	)
	var witness_callers := production_sources.duplicate()
	witness_callers.erase(CATALOG_SERVICE_PATH)
	_expect(
		_paths_calling_tokens(
			witness_callers,
			["authorize_v04_interaction_effect_witness"]
		) == [SOURCE_AUTHORIZATION_PATH],
		"only the source authorization port calls the v0.4 effect witness"
	)

	var bundle_core_fields: Array = INTERACTION_LEGACY_SOURCE_BUNDLE.CORE_FIELDS
	var bundle_fields: Array = INTERACTION_LEGACY_SOURCE_BUNDLE.FIELDS
	var forbidden_wire_fields := [
		"card",
		"card_definition",
		"card_record",
		"developer",
		"effect_payload",
		"legacy_definition",
		"machine",
		"player",
		"raw_card",
		"raw_payload",
		"runtime_card",
		"skill",
		"source_skill",
		"static_record",
	]
	var leaked_wire_fields: Array[String] = []
	for field_id in forbidden_wire_fields:
		if bundle_core_fields.has(field_id) or bundle_fields.has(field_id):
			leaked_wire_fields.append(field_id)
	_expect(
		bundle_core_fields.size() == 19
			and bundle_fields.size() == 21
			and leaked_wire_fields.is_empty(),
		"legacy source wire bundle is closed and carries no raw/full card: %s"
			% [leaked_wire_fields]
	)
	_expect(
		bundle_source.contains("WIRE.exact_fields(unsealed, CORE_FIELDS)")
			and bundle_source.contains("WIRE.exact_fields(bundle, FIELDS)")
			and bundle_source.contains(
				"POLICY_COMPATIBILITY.validate("
			)
			and not bundle_source.contains("exact_definition(")
			and not bundle_source.contains("catalog_snapshot("),
		"legacy source bundle validates closed nested data without catalog access"
	)


func _scan_ai_interaction_observation_boundary() -> void:
	var service_source := FileAccess.get_file_as_string(
		INTERACTION_OBSERVATION_SERVICE_PATH
	)
	var service_scene := FileAccess.get_file_as_string(
		INTERACTION_OBSERVATION_SCENE_PATH
	)
	var coordinator_scene := FileAccess.get_file_as_string(
		COORDINATOR_SCENE_PATH
	)
	var coordinator_source := FileAccess.get_file_as_string(
		COORDINATOR_SCRIPT_PATH
	)
	var ai_source := FileAccess.get_file_as_string(AI_RUNTIME_PATH)
	_expect(not service_source.is_empty(), "interaction observation service is readable")
	_expect(not service_scene.is_empty(), "interaction observation service scene is readable")
	_expect(not coordinator_source.is_empty(), "production coordinator script is readable")
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
	_expect(
		service_scene.contains(
			'path="res://scripts/runtime/ai_card_interaction_observation_service.gd"'
		),
		"interaction observation scene owns the narrow service script"
	)
	_expect(
		ai_source.contains("AiCardInteractionObservationService")
			and ai_source.contains("observe_own_hand_interaction"),
		"AiRuntimeController consumes the narrow interaction observation service"
	)
	var observation_callers := _production_source_map()
	observation_callers.erase(INTERACTION_OBSERVATION_SERVICE_PATH)
	_expect(
		_paths_calling_tokens(
			observation_callers,
			["observe_own_hand_interaction"]
		) == [AI_RUNTIME_PATH],
		"only AiRuntimeController may invoke the actor-private observation entrypoint"
	)
	var bind_consumer_block := _function_block(
		service_source,
		"bind_consumer_capabilities"
	)
	var observe_block := _function_block(
		service_source,
		"observe_own_hand_interaction"
	)
	var validate_block := _function_block(
		service_source,
		"validate_observation"
	)
	var capability_match_block := _function_block(
		service_source,
		"_consumer_capability_matches"
	)
	var capability_unique_block := _function_block(
		service_source,
		"_capability_values_are_unique"
	)
	_expect(
		service_source.contains(
			"ai_card_interaction_observation_capability.gd"
		)
			and not bind_consumer_block.is_empty()
			and _function_block(
				service_source,
				"bind_consumer_capability"
			).is_empty()
			and bind_consumer_block.contains("_consumer_capability_by_actor")
			and bind_consumer_block.contains("_same_actor_indices(")
			and bind_consumer_block.contains("_same_capability_map(")
			and bind_consumer_block.contains(
				"_capability_values_are_unique(normalized)"
			)
			and capability_unique_block.contains("seen.has(capability)"),
		"consumer capabilities are one-shot bound as an actor-indexed map"
	)
	_expect(
		observe_block.contains("consumer_capability: RefCounted")
			and observe_block.contains("actor_index: int")
			and observe_block.contains(
				"_consumer_capability_matches(actor_index, consumer_capability)"
			)
			and validate_block.contains("consumer_capability: RefCounted")
			and validate_block.contains("actor_index: int")
			and validate_block.contains(
				"_consumer_capability_matches(actor_index, consumer_capability)"
			)
			and capability_match_block.contains(
				"_consumer_capability_by_actor.has(actor_index)"
			)
			and capability_match_block.contains(
				"_consumer_capability_by_actor.get(actor_index) == capability"
			),
		"observation issue and validation require the token bound to that actor"
	)
	var coordinator_bind_block := _function_block(
		coordinator_source,
		"_prebind_ai_card_interaction_observation_service"
	)
	_expect(
		coordinator_source.contains(
			"var _ai_card_interaction_observation_capability_by_actor: Dictionary"
		)
			and coordinator_bind_block.contains(
				"_card_semantic_source_capability_by_actor.keys()"
			)
			and coordinator_bind_block.contains(
				"AI_CARD_INTERACTION_OBSERVATION_CAPABILITY.new()"
			)
			and coordinator_bind_block.contains("bind_consumer_capabilities(")
			and coordinator_bind_block.contains(
				"_ai_card_interaction_observation_capability_by_actor"
			),
		"Coordinator derives and binds one consumer capability per source actor"
	)
	var ai_bind_block := _function_block(
		ai_source,
		"set_card_interaction_observation_source"
	)
	var ai_observe_block := _function_block(
		ai_source,
		"_authorized_card_interaction_observation"
	)
	_expect(
		ai_source.contains(
			"var _ai_card_interaction_observation_capability_by_actor: Dictionary"
		)
			and ai_bind_block.contains("consumer_capabilities: Dictionary")
			and ai_bind_block.contains(
				"_capability_values_are_unique(normalized)"
			)
			and ai_bind_block.contains("_same_identity_map(")
			and ai_bind_block.contains(
				"_ai_card_interaction_observation_capability_by_actor"
			)
			and ai_observe_block.contains(".has(")
			and ai_observe_block.contains(".get(player_index)")
			and ai_observe_block.contains("player_index"),
		"AiRuntimeController selects only the capability bound to its active actor"
	)
	var singular_capability_regex := RegEx.new()
	singular_capability_regex.compile(
		"\\b(_ai_card_interaction_observation_capability|_consumer_capability)\\b"
	)
	var singular_capability_hits: Array[String] = []
	for source_pair in [
		[INTERACTION_OBSERVATION_SERVICE_PATH, service_source],
		[AI_RUNTIME_PATH, ai_source],
		[COORDINATOR_SCRIPT_PATH, coordinator_source],
	]:
		var pair := source_pair as Array
		if singular_capability_regex.search(str(pair[1])) != null:
			singular_capability_hits.append(str(pair[0]))
	_expect(
		singular_capability_hits.is_empty(),
		"production exposes no legacy singular consumer capability field: %s"
			% [singular_capability_hits]
	)
	var service_debug_block := _function_block(service_source, "debug_snapshot")
	var ai_debug_block := _function_block(ai_source, "debug_snapshot")
	_expect(
		service_debug_block.contains('"consumer_capability_count"')
			and service_debug_block.contains(
				'"exposes_consumer_capability": false'
			)
			and not service_debug_block.contains(
				'"_consumer_capability_by_actor"'
			)
			and ai_debug_block.contains(
				'"card_interaction_observation_consumer_capability_count"'
			)
			and ai_debug_block.contains(
				'"card_interaction_observation_exposes_capabilities": false'
			)
			and not ai_debug_block.contains(
				'"_ai_card_interaction_observation_capability_by_actor"'
			),
		"debug snapshots expose counts and booleans, never token maps"
	)
	var observation_test_source := FileAccess.get_file_as_string(
		INTERACTION_OBSERVATION_TEST_PATH
	)
	var actor_rejection_test_block := _function_block(
		observation_test_source,
		"_test_capability_binding_actor_and_slot_rejections"
	)
	_expect(
		actor_rejection_test_block.contains(
			'"one consumer token cannot be initially aliased to multiple actors"'
		)
			and actor_rejection_test_block.contains(
				'"AI consumer rejects an actor map with aliased token identities"'
			)
			and actor_rejection_test_block.contains(
			'"actor-one consumer token cannot read another AI viewer"'
		)
			and actor_rejection_test_block.contains(
				'"actor-one consumer token cannot validate another AI viewer"'
			)
			and actor_rejection_test_block.contains(
				'"other AI actor authorizes only its own bound hand owner and slot"'
			)
			and actor_rejection_test_block.contains(
				"other_actor_capability"
			),
		"hostile tests lock cross-actor read and validation rejection"
	)
	for forbidden_direct_source_token in [
		"CardSemanticSourceAuthorizationPort",
		"authorize_own_hand_card",
		"authorize_source(",
	]:
		_expect(
			not ai_source.contains(forbidden_direct_source_token),
			"AiRuntimeController cannot consume source authorization directly: %s"
				% forbidden_direct_source_token
		)
	for forbidden_service_token in [
		"effect_payload",
		"source_skill",
		"counter_skill",
		"role_card",
		"raw_payload",
		"raw_card",
		"v06_card_definition",
		"resolve_definition",
		"catalog_snapshot(",
		"ordered_card_ids(",
		"card_ids(",
		"AiCardSemanticProjectionService",
		"project_authorized_source(",
		"project_candidates(",
		"RuleExecutionPlan",
		"RulesProjection",
		"register_handler(",
		"register_save_owner",
		"to_save_data",
		"apply_save_data",
		"RunRngService",
		"RandomNumberGenerator",
		"randf(",
		"randi(",
		"res://scripts/main.gd",
		"/root/Main",
		"current_scene",
		".players",
	]:
		_expect(
			not service_source.contains(forbidden_service_token),
			"interaction observation service omits forbidden dependency: %s"
				% forbidden_service_token
		)
	var origin_report := _json_object(AI_DEBT_REPORT_PATH)
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
		var occurrences: Dictionary = (row_variant as Dictionary).get(
			"field_occurrences",
			{}
		) as Dictionary
		for field_variant in occurrences.keys():
			origin_keys[str(field_variant)] = true
	var reviewed_op_fields := ["target_cash_penalty", "steal_fail_cash"]
	_expect(
		_count_occurrences(
			service_source,
			'op.get("target_cash_penalty"'
		) == 1
			and _count_occurrences(
				service_source,
				'op.get("steal_fail_cash"'
			) == 1,
		"only two exact validated semantic-op adapter reads retain legacy field IDs"
	)
	var escaped_raw_keys: Array[String] = []
	for path_variant in batch1_sources.keys():
		var path := str(path_variant)
		var source := str(batch1_sources[path])
		for field_variant in origin_keys.keys():
			var field_id := str(field_variant)
			if path == INTERACTION_OBSERVATION_SERVICE_PATH \
					and reviewed_op_fields.has(field_id):
				continue
			if source.contains('"%s"' % field_id):
				escaped_raw_keys.append("%s:%s" % [path, field_id])
	escaped_raw_keys.sort()
	_expect(
		escaped_raw_keys.is_empty(),
		"new observation files contain no unreviewed historical raw-key alias: %s"
			% [escaped_raw_keys]
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


func _scan_save_registry_contract() -> void:
	var fixed_order: Array = SAVE_REGISTRY.FIXED_SECTION_ORDER.duplicate()
	var seen: Dictionary = {}
	var semantic_sections: Array[String] = []
	for section_variant in fixed_order:
		var section_id := str(section_variant)
		seen[section_id] = true
		if section_id.contains("semantic"):
			semantic_sections.append(section_id)
	_expect(fixed_order.size() == 19 and seen.size() == 19, "fixed Save Registry remains exactly 19 unique sections")
	_expect(semantic_sections.is_empty(), "fixed Save Registry adds no semantic section")
	_expect(
		_token_hits(_source_map(SEMANTIC_SOURCE_PATHS), ["save_section", "register_save_owner"]).is_empty(),
		"new semantic production sources register no Save owner"
	)


func _scan_source_owner_policy_compatibility_bridge() -> void:
	var source := FileAccess.get_file_as_string(SOURCE_AUTHORIZATION_PATH)
	var schema := FileAccess.get_file_as_string(
		INTERACTION_POLICY_COMPATIBILITY_SCHEMA_PATH
	)
	_expect(
		not source.is_empty() and not schema.is_empty(),
		"source-owner policy compatibility sources are readable"
	)
	var function_id := "_legacy_interaction_policy_facts"
	var function_block := _function_block(source, function_id)
	var raw_keys: Array[String] = [
		"kind",
		"hand_discard_count",
		"hand_steal_count",
		"hand_lock_seconds",
		"target_cash_penalty",
		"steal_fail_cash",
	]
	var key_pattern := "|".join(raw_keys)
	var read_regex := RegEx.new()
	read_regex.compile(
		"\\bcard\\.get\\(\\s*\"(%s)\"" % key_pattern
	)
	var observed: Dictionary = {}
	for match_variant in read_regex.search_all(function_block):
		var field_id := (match_variant as RegExMatch).get_string(1)
		observed[field_id] = int(observed.get(field_id, 0)) + 1
	var expected: Dictionary = {}
	for field_id in raw_keys:
		expected[field_id] = 1
	_expect(
		observed == expected,
		"source-owner bridge locks exactly six multiline-safe card reads: %s"
			% [observed]
	)
	_expect(
		read_regex.search_all(source).size() == raw_keys.size(),
		"source-owner compatibility keys appear on card.get only in one function"
	)
	var presence_regex := RegEx.new()
	presence_regex.compile(
		"\\bcard\\.has\\(\\s*\"(%s)\"" % key_pattern
	)
	var dynamic_regex := RegEx.new()
	dynamic_regex.compile(
		"\\bcard\\.(get|has)\\(\\s*[a-zA-Z_][a-zA-Z0-9_]*"
	)
	_expect(
		presence_regex.search_all(source).is_empty()
			and dynamic_regex.search_all(function_block).is_empty(),
		"source-owner bridge has zero presence checks and zero dynamic raw keys"
	)
	var escaped_schema_keys: Array[String] = []
	for field_id in raw_keys:
		if schema.contains('"%s"' % field_id):
			escaped_schema_keys.append(field_id)
	_expect(
		escaped_schema_keys.is_empty(),
		"wire policy schema carries renamed fields, not source raw-key aliases"
	)
	var callers: Array[String] = []
	for path_variant in _production_source_map().keys():
		var path := str(path_variant)
		if path == SOURCE_AUTHORIZATION_PATH:
			continue
		var call_count := _count_occurrences(
			FileAccess.get_file_as_string(path),
			"authorize_own_hand_interaction_policy_compatibility"
		)
		if call_count > 0:
			callers.append("%s:%d" % [path, call_count])
	_expect(
		callers == ["%s:2" % INTERACTION_OBSERVATION_SERVICE_PATH],
		"only the observation service consumes the source-owner bridge: %s"
			% [callers]
	)
	var batch_report := _json_object(AI_RAW_READ_BATCH1_REPORT_PATH)
	var owner_lock := batch_report.get(
		"source_owner_compatibility_lock",
		{}
	) as Dictionary
	var combined_lock := batch_report.get(
		"combined_historical_ai_policy_read_ledger",
		{}
	) as Dictionary
	_expect(
		int(owner_lock.get("value_reads", -1)) == 6
			and int(owner_lock.get("presence_checks", -1)) == 0
			and int(owner_lock.get("functions", -1)) == 1
			and int(owner_lock.get("keys", -1)) == 6,
		"report freezes the 6/0/1/6 owner compatibility ledger"
	)
	_expect(
		int(combined_lock.get("value_reads", -1)) == 225
			and int(combined_lock.get("presence_checks", -1)) == 5
			and int(combined_lock.get("functions", -1)) == 32
			and int(combined_lock.get("keys", -1)) == 71,
		"report honestly retains the combined 225/5/32/71 historical policy ledger"
	)


func _scan_ai_raw_field_debt() -> void:
	var report := _json_object(AI_DEBT_REPORT_PATH)
	var batch_report := _json_object(AI_RAW_READ_BATCH1_REPORT_PATH)
	if report.is_empty() or batch_report.is_empty():
		return
	var counts: Dictionary = report.get("deterministic_counts", {}) as Dictionary
	_expect(
		int(counts.get("value_reads_total", -1)) == 225
			and int(counts.get("field_presence_checks", -1)) == 5
			and int(counts.get("distinct_functions", -1)) == 33
			and int(counts.get("distinct_field_keys", -1)) == 71,
		"AI debt report freezes the 225/5/33/71 baseline"
	)
	var rows: Array = report.get("migration_rows", []) as Array
	var expected_values: Dictionary = {}
	var expected_presence: Dictionary = {}
	var expected_functions: Dictionary = {}
	var expected_keys: Dictionary = {}
	var row_value_sum := 0
	var row_presence_sum := 0
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		var function_id := str(row.get("function", ""))
		expected_functions[function_id] = true
		row_value_sum += int(row.get("value_read_count", 0))
		row_presence_sum += int(row.get("presence_check_count", 0))
		var occurrences: Dictionary = row.get("field_occurrences", {}) as Dictionary
		for field_variant in occurrences.keys():
			var field_id := str(field_variant)
			expected_keys[field_id] = true
			expected_values[_signature(function_id, field_id)] = (occurrences[field_variant] as Array).size()
		if int(row.get("presence_check_count", 0)) > 0:
			if function_id == "_ai_policy_family_for_kind":
				for field_id in DYNAMIC_POLICY_FIELDS:
					expected_presence[_signature(function_id, field_id)] = 1
			elif function_id == "_ai_play_requirement_metadata":
				expected_presence[_signature(function_id, "play_requirement_district")] = 1
			else:
				_failures.append("unclassified presence-check report row: %s" % function_id)
	_expect(rows.size() == 33 and expected_functions.size() == 33, "AI debt report has 33 closed migration rows")
	_expect(row_value_sum == 225 and row_presence_sum == 5 and expected_keys.size() == 71, "AI debt report rows reconcile to 225/5/71")
	var batch_origin: Dictionary = batch_report.get("historical_origin", {}) as Dictionary
	var current_lock: Dictionary = batch_report.get("current_lock", {}) as Dictionary
	_expect(
		int(batch_origin.get("value_reads", -1)) == 225
			and int(batch_origin.get("presence_checks", -1)) == 5
			and int(batch_origin.get("functions", -1)) == 33
			and int(batch_origin.get("keys", -1)) == 71,
		"Batch 1 ratchet preserves the historical 225/5/33/71 origin"
	)
	_expect(
		int(current_lock.get("value_reads", -1)) == 219
			and int(current_lock.get("presence_checks", -1)) == 5
			and int(current_lock.get("functions", -1)) == 31
			and int(current_lock.get("keys", -1)) == 69,
		"Batch 1 report freezes the exact 219/5/31/69 current lock"
	)
	var removed_rows: Array = batch_report.get("removed_origin_rows", []) as Array
	var removed_signatures: Array = batch_report.get(
		"removed_read_signatures",
		[]
	) as Array
	_expect(
		removed_rows == ["R03", "R04"] and removed_signatures.size() == 6,
		"Batch 1 removes exactly the six R03/R04 raw-read signatures"
	)
	var removed_signature_ids: Dictionary = {}
	for removal_variant in removed_signatures:
		if not (removal_variant is Dictionary):
			_failures.append("invalid Batch 1 removed signature row")
			continue
		var removal := removal_variant as Dictionary
		var function_id := str(removal.get("function", ""))
		var field_id := str(removal.get("field", ""))
		var signature := _signature(function_id, field_id)
		removed_signature_ids[signature] = true
		_expect(
			expected_values.has(signature)
				and int(expected_values.get(signature, 0))
					== int(removal.get("origin_count", -1))
				and int(removal.get("current_count", -1)) == 0,
			"Batch 1 removal is anchored to one historical signature: %s"
				% signature
		)
		expected_values.erase(signature)
	var current_expected_functions: Dictionary = {}
	var current_expected_keys: Dictionary = {}
	for signature_variant in expected_values.keys():
		var parts := str(signature_variant).split("::", false, 1)
		if parts.size() == 2:
			current_expected_functions[str(parts[0])] = true
			current_expected_keys[str(parts[1])] = true
	for signature_variant in expected_presence.keys():
		var parts := str(signature_variant).split("::", false, 1)
		if parts.size() == 2:
			current_expected_functions[str(parts[0])] = true
			current_expected_keys[str(parts[1])] = true
	_expect(
		_sum_dictionary_values(expected_values) == 219
			and _sum_dictionary_values(expected_presence) == 5
			and current_expected_functions.size() == 31
			and current_expected_keys.size() == 69,
		"historical allowlist minus R03/R04 reconciles exactly to 219/5/31/69"
	)
	_expect(
		int(current_lock.get("value_reads", -1))
			<= int(batch_origin.get("value_reads", -1))
			and int(current_lock.get("presence_checks", -1))
				<= int(batch_origin.get("presence_checks", -1))
			and int(current_lock.get("functions", -1))
				<= int(batch_origin.get("functions", -1))
			and int(current_lock.get("keys", -1))
				<= int(batch_origin.get("keys", -1)),
		"Batch 1 metrics are monotonic from the immutable historical origin"
	)

	var source := FileAccess.get_file_as_string(AI_RUNTIME_PATH)
	_expect(not source.contains("effect_payload"), "global AI source does not read effect_payload directly")
	var value_regex := RegEx.new()
	var presence_regex := RegEx.new()
	value_regex.compile("\\b(evaluated_skill|source_skill|counter_skill|role_card|skill|role)\\.get\\(\\s*\"([a-z0-9_]+)\"")
	presence_regex.compile("\\b(evaluated_skill|source_skill|counter_skill|role_card|skill|role)\\.has\\(\\s*\"([a-z0-9_]+)\"")
	var observed_values: Dictionary = {}
	var observed_presence: Dictionary = {}
	var observed_functions: Dictionary = {}
	var observed_keys: Dictionary = {}
	var current_function := ""
	for raw_line in source.split("\n"):
		var line := str(raw_line)
		var stripped := line.strip_edges()
		if stripped.begins_with("func "):
			current_function = stripped.trim_prefix("func ").get_slice("(", 0).strip_edges()
		for match_variant in value_regex.search_all(line):
			var match_result := match_variant as RegExMatch
			var field_id := match_result.get_string(2)
			var signature := _signature(current_function, field_id)
			observed_values[signature] = int(observed_values.get(signature, 0)) + 1
			observed_functions[current_function] = true
			observed_keys[field_id] = true
		for match_variant in presence_regex.search_all(line):
			var match_result := match_variant as RegExMatch
			var field_id := match_result.get_string(2)
			var signature := _signature(current_function, field_id)
			observed_presence[signature] = int(observed_presence.get(signature, 0)) + 1
			observed_functions[current_function] = true
			observed_keys[field_id] = true

	var dynamic_shape_valid := _count_occurrences(source, "skill.has(field_name)") == 1 \
		and _count_occurrences(source, "skill[field_name]") == 1 \
		and _count_nonliteral_receiver_calls(source) == 1 \
		and _count_nonliteral_receiver_indexes(source) == 1
	_expect(dynamic_shape_valid, "the sole dynamic raw-field loop remains the four-field reported policy loop")
	for field_id in DYNAMIC_POLICY_FIELDS:
		var signature := _signature("_ai_policy_family_for_kind", field_id)
		observed_values[signature] = int(observed_values.get(signature, 0)) + 1
		observed_presence[signature] = int(observed_presence.get(signature, 0)) + 1
		observed_functions["_ai_policy_family_for_kind"] = true
		observed_keys[field_id] = true

	var violations := _signature_count_mismatches(
		expected_values,
		observed_values,
		"value"
	)
	violations.append_array(_signature_count_mismatches(
		expected_presence,
		observed_presence,
		"presence"
	))
	for signature_variant in removed_signature_ids.keys():
		var signature := str(signature_variant)
		if observed_values.has(signature):
			violations.append(
				"removed_signature_reappeared:%s:%d"
					% [signature, int(observed_values.get(signature, 0))]
			)
	var observed_value_count := _sum_dictionary_values(observed_values)
	var observed_presence_count := _sum_dictionary_values(observed_presence)
	_debt_snapshot = {
		"value_reads": observed_value_count,
		"presence_checks": observed_presence_count,
		"functions": observed_functions.size(),
		"keys": observed_keys.size(),
		"new_violations": violations.size(),
	}
	_expect(observed_value_count == 219, "AI raw value-read debt is exactly 219")
	_expect(observed_presence_count == 5, "AI raw presence-check debt is exactly 5")
	_expect(
		observed_functions.size() == 31 and observed_keys.size() == 69,
		"AI raw debt is locked to exactly 31 functions and 69 keys"
	)
	_expect(
		violations.is_empty(),
		"AI raw reads equal the historical allowlist minus R03/R04: %s"
			% [violations]
	)


func _scan_project_production_direct_literal_access_lock() -> void:
	var historical_report := _json_object(AI_DEBT_REPORT_PATH)
	var batch_report := _json_object(AI_RAW_READ_BATCH1_REPORT_PATH)
	if historical_report.is_empty() or batch_report.is_empty():
		return
	var historical_keys := _historical_raw_key_set(historical_report)
	_expect(
		historical_keys.size() == 71,
		"project direct-literal ratchet derives all 71 historical audit keys"
	)
	_scan_direct_literal_access_self_tests(historical_keys)
	var production_sources := _project_production_source_map()
	var excluded_hits: Array[String] = []
	for path_variant in production_sources.keys():
		var path := str(path_variant)
		for prefix in PROJECT_PRODUCTION_GDSCRIPT_EXCLUDED_PREFIXES:
			if path.begins_with(prefix):
				excluded_hits.append(path)
	_expect(
		excluded_hits.is_empty(),
		"project production source map excludes only the frozen non-production prefixes"
	)
	_expect(
		_dictionary_key_has_prefix(production_sources, "res://resources/"),
		"project production source map includes resource GDScript"
	)
	var observed := _direct_literal_access_snapshot(
		production_sources,
		historical_keys
	)
	observed["production_gdscript_file_count"] = production_sources.size()
	var lock: Dictionary = batch_report.get(
		"project_production_direct_literal_access_lock",
		{}
	) as Dictionary
	var expected_lock_keys: Array[String] = [
		"access_form_counts",
		"distinct_literal_key_count",
		"distinct_signature_count",
		"historical_key_count",
		"historical_key_source",
		"literal_key_set_fingerprint",
		"matched_file_count",
		"matched_historical_key_count",
		"occurrence_count",
		"per_file_counts",
		"production_gdscript_file_count",
		"receiver_token_limit",
		"scanner_algorithm_id",
		"schema_version",
		"scope_excluded_prefixes",
		"scope_root",
		"signature_fields",
		"signature_fingerprint",
	]
	expected_lock_keys.sort()
	_expect(
		_sorted_string_keys(lock) == expected_lock_keys,
		"project production direct-literal access lock is a closed object"
	)
	_expect(
		int(lock.get("schema_version", 0)) == 2
			and str(lock.get("scanner_algorithm_id", ""))
				== "gdscript_project_direct_literal_access_token_scan_v2"
			and str(lock.get("scope_root", "")) == "res://"
			and lock.get("scope_excluded_prefixes", [])
				== PROJECT_PRODUCTION_GDSCRIPT_EXCLUDED_PREFIXES
			and str(lock.get("historical_key_source", ""))
				== AI_DEBT_REPORT_PATH
			and int(lock.get("historical_key_count", -1))
				== historical_keys.size()
			and int(lock.get("receiver_token_limit", -1))
				== RAW_ACCESS_RECEIVER_TOKEN_LIMIT,
		"project direct-literal access lock freezes scope and algorithm"
	)
	_expect(
		lock.get("signature_fields", []) == [
			"path",
			"function",
			"key",
			"access_form",
			"normalized_receiver",
			"normalized_access_expression",
		],
		"project direct-literal signatures freeze all identity fields"
	)
	var locked_per_file := _integer_dictionary(
		lock.get("per_file_counts", {})
	)
	var locked_access_forms := _integer_dictionary(
		lock.get("access_form_counts", {})
	)
	_expect(
		int(lock.get("occurrence_count", -1))
			== int(observed.get("occurrence_count", -2))
			and int(lock.get("distinct_literal_key_count", -1))
				== int(observed.get("distinct_literal_key_count", -2))
			and int(lock.get("distinct_signature_count", -1))
				== int(observed.get("distinct_signature_count", -2))
			and int(lock.get("matched_file_count", -1))
				== int(observed.get("matched_file_count", -2))
			and int(lock.get("matched_historical_key_count", -1))
				== int(observed.get("matched_historical_key_count", -2))
			and int(lock.get("production_gdscript_file_count", -1))
				== int(observed.get("production_gdscript_file_count", -2))
			and str(lock.get("literal_key_set_fingerprint", ""))
				== str(observed.get("literal_key_set_fingerprint", "missing"))
			and str(lock.get("signature_fingerprint", ""))
				== str(observed.get("signature_fingerprint", "missing"))
			and locked_per_file == observed.get("per_file_counts", {})
			and locked_access_forms == observed.get("access_form_counts", {}),
		"all project production direct literal accesses match the closed lock: %s"
			% [JSON.stringify(observed)]
	)
	_expect(
		int(observed.get("matched_historical_key_count", -1)) == 71,
		"project direct-literal lock separately covers 71/71 historical audit keys"
	)


func _scan_direct_literal_access_self_tests(
	historical_keys: Dictionary
) -> void:
	var hostile_path := "res://scripts/runtime/__direct_literal_hostile__.gd"
	var hostile_source := (
		"func probe():\n"
		+ "\tvar bracket = payload[\n\t\t\"kind\"\n\t]\n"
		+ "\tvar multiline = payload.get(\n\t\t\"kind\"\n\t)\n"
		+ "\tvar unknown = payload.get(\"future_private_value\")\n"
		+ "\tvar raw_value = payload.get(r\"kind\")\n"
		+ "\treturn payload.has(&\"kind\")\n"
	)
	var hostile_rows := _direct_literal_access_rows(
		{hostile_path: hostile_source}
	)
	var hostile_forms := {"bracket": 0, "get": 0, "has": 0}
	var hostile_keys: Dictionary = {}
	var hostile_shape_valid := hostile_rows.size() == 5
	for row_variant in hostile_rows:
		var row := row_variant as Dictionary
		var access_form := str(row.get("access_form", ""))
		var key := str(row.get("key", ""))
		hostile_forms[access_form] = int(hostile_forms.get(access_form, 0)) + 1
		hostile_keys[key] = int(hostile_keys.get(key, 0)) + 1
		hostile_shape_valid = hostile_shape_valid \
			and str(row.get("path", "")) == hostile_path \
			and str(row.get("function", "")) == "probe" \
			and str(row.get("normalized_receiver", "")) == "payload"
	_expect(
		hostile_shape_valid
			and hostile_forms == {"bracket": 1, "get": 3, "has": 1}
			and hostile_keys == {"future_private_value": 1, "kind": 4},
		"direct-literal scanner catches unknown, raw, StringName, and multiline forms"
	)
	var ignored_source := (
		"func probe():\n"
		+ "\t# payload.get(\"kind\")\n"
		+ "\tvar prose = \"payload.has(\\\"kind\\\")\"\n"
		+ "\treturn prose\n"
	)
	_expect(
		_direct_literal_access_rows({hostile_path: ignored_source}).is_empty(),
		"direct-literal scanner ignores comments and prose"
	)
	var skill_snapshot := _direct_literal_access_snapshot(
		{hostile_path: "func probe():\n\treturn skill.get(\"kind\")\n"},
		historical_keys
	)
	var payload_snapshot := _direct_literal_access_snapshot(
		{hostile_path: "func probe():\n\treturn payload.get(\"kind\")\n"},
		historical_keys
	)
	var helper_snapshot := _direct_literal_access_snapshot(
		{hostile_path: "func moved_helper():\n\treturn skill.get(\"kind\")\n"},
		historical_keys
	)
	var future_snapshot := _direct_literal_access_snapshot(
		{
			hostile_path:
				"func probe():\n"
				+ "\tvar known = skill.get(\"kind\")\n"
				+ "\treturn payload.get(\"future_private_value\")\n"
		},
		historical_keys
	)
	var resource_snapshot := _direct_literal_access_snapshot(
		{
			"res://resources/content/__direct_literal_hostile__.gd":
				"func probe():\n\treturn skill.get(\"kind\")\n"
		},
		historical_keys
	)
	_expect(
		str(skill_snapshot.get("signature_fingerprint", ""))
			!= str(payload_snapshot.get("signature_fingerprint", ""))
			and str(skill_snapshot.get("signature_fingerprint", ""))
				!= str(helper_snapshot.get("signature_fingerprint", ""))
			and str(skill_snapshot.get("signature_fingerprint", ""))
				!= str(resource_snapshot.get("signature_fingerprint", "")),
		"receiver, helper, and resource-path relocation change the signature fingerprint"
	)
	_expect(
		int(future_snapshot.get("occurrence_count", 0)) == 2
			and int(future_snapshot.get("distinct_literal_key_count", 0)) == 2
			and int(future_snapshot.get("matched_historical_key_count", 0)) == 1
			and str(future_snapshot.get("signature_fingerprint", ""))
				!= str(skill_snapshot.get("signature_fingerprint", ""))
			and str(future_snapshot.get("literal_key_set_fingerprint", ""))
				!= str(skill_snapshot.get("literal_key_set_fingerprint", "")),
		"unknown future literal keys change both structural and key-set locks"
	)


func _scan_name_kind_audit() -> void:
	var report := _json_object(NAME_KIND_REPORT_PATH)
	if report.is_empty():
		return
	var totals: Dictionary = report.get("totals", {}) as Dictionary
	var by_disposition: Dictionary = totals.get("by_disposition", {}) as Dictionary
	var findings: Array = report.get("findings", []) as Array
	var observed := {"REMOVE": 0, "MOVE": 0, "KEEP": 0}
	for finding_variant in findings:
		if finding_variant is Dictionary:
			var disposition := str((finding_variant as Dictionary).get("disposition", ""))
			observed[disposition] = int(observed.get(disposition, 0)) + 1
	_expect(int(report.get("schema_version", 0)) == 1, "name/kind audit schema parses")
	_expect(
		int(totals.get("finding_count", -1)) == 57 and findings.size() == 57,
		"name/kind audit closes 57 finding groups"
	)
	_expect(
		int(by_disposition.get("REMOVE", -1)) == 16
			and int(by_disposition.get("MOVE", -1)) == 33
			and int(by_disposition.get("KEEP", -1)) == 8
			and observed == {"REMOVE": 16, "MOVE": 33, "KEEP": 8},
		"name/kind audit dispositions close as REMOVE16/MOVE33/KEEP8"
	)


func _historical_raw_key_set(report: Dictionary) -> Dictionary:
	var keys: Dictionary = {}
	for row_variant in report.get("migration_rows", []):
		if not (row_variant is Dictionary):
			continue
		var occurrences: Dictionary = (row_variant as Dictionary).get(
			"field_occurrences",
			{}
		) as Dictionary
		for key_variant in occurrences.keys():
			keys[str(key_variant)] = true
	return keys


func _direct_literal_access_snapshot(
	sources: Dictionary,
	historical_keys: Dictionary
) -> Dictionary:
	var rows := _direct_literal_access_rows(sources)
	var canonical_signatures: Array[String] = []
	var unique_signatures: Dictionary = {}
	var literal_keys: Dictionary = {}
	var matched_historical_keys: Dictionary = {}
	var per_file_counts: Dictionary = {}
	var access_form_counts := {
		"bracket": 0,
		"get": 0,
		"has": 0,
	}
	for row_variant in rows:
		var row := row_variant as Dictionary
		var canonical := JSON.stringify([
			str(row.get("path", "")),
			str(row.get("function", "")),
			str(row.get("key", "")),
			str(row.get("access_form", "")),
			str(row.get("normalized_receiver", "")),
			str(row.get("normalized_access_expression", "")),
		])
		canonical_signatures.append(canonical)
		unique_signatures[canonical] = true
		var path := str(row.get("path", ""))
		var key := str(row.get("key", ""))
		var access_form := str(row.get("access_form", ""))
		literal_keys[key] = true
		if historical_keys.has(key):
			matched_historical_keys[key] = true
		per_file_counts[path] = int(per_file_counts.get(path, 0)) + 1
		access_form_counts[access_form] = int(
			access_form_counts.get(access_form, 0)
		) + 1
	canonical_signatures.sort()
	var ordered_literal_keys := _sorted_string_keys(literal_keys)
	return {
		"occurrence_count": rows.size(),
		"distinct_literal_key_count": literal_keys.size(),
		"distinct_signature_count": unique_signatures.size(),
		"matched_file_count": per_file_counts.size(),
		"matched_historical_key_count": matched_historical_keys.size(),
		"access_form_counts": access_form_counts,
		"per_file_counts": per_file_counts,
		"literal_key_set_fingerprint": "\n".join(
			ordered_literal_keys
		).sha256_text(),
		"signature_fingerprint": "\n".join(
			canonical_signatures
		).sha256_text(),
	}


func _direct_literal_access_rows(sources: Dictionary) -> Array:
	var rows: Array = []
	var ordered_paths := _sorted_string_keys(sources)
	for path in ordered_paths:
		var tokens := _lex_gdscript(str(sources[path]))
		var current_function := "<class_scope>"
		for index in range(tokens.size()):
			var token := tokens[index] as Dictionary
			var token_text := str(token.get("text", ""))
			if str(token.get("kind", "")) == "identifier" \
					and token_text == "func":
				var function_index := _next_non_continuation_token(
					tokens,
					index + 1
				)
				if function_index < tokens.size():
					var function_token := tokens[function_index] as Dictionary
					if str(function_token.get("kind", "")) == "identifier":
						current_function = str(function_token.get("text", ""))
			if token_text == ".":
				var method_index := _next_non_continuation_token(
					tokens,
					index + 1
				)
				var open_index := _next_non_continuation_token(
					tokens,
					method_index + 1
				)
				if method_index >= tokens.size() or open_index >= tokens.size():
					continue
				var method_token := tokens[method_index] as Dictionary
				var method := str(method_token.get("text", ""))
				if str(method_token.get("kind", "")) != "identifier" \
						or not ["get", "has"].has(method) \
						or str((tokens[open_index] as Dictionary).get("text", "")) \
							!= "(":
					continue
				var receiver_end := _previous_non_continuation_token(
					tokens,
					index - 1
				)
				if receiver_end < 0 \
						or not _can_end_receiver(tokens[receiver_end] as Dictionary):
					continue
				var literal_index := _literal_token_index(
					tokens,
					open_index + 1
				)
				if literal_index >= tokens.size():
					continue
				var literal_token := tokens[literal_index] as Dictionary
				var key := str(literal_token.get("value", ""))
				if str(literal_token.get("kind", "")) != "string":
					continue
				var receiver := _normalized_receiver(tokens, receiver_end)
				rows.append(_direct_literal_access_row(
					path,
					current_function,
					key,
					method,
					receiver
				))
			elif token_text == "[":
				var receiver_end := _previous_non_continuation_token(
					tokens,
					index - 1
				)
				if receiver_end < 0 \
						or not _can_end_receiver(tokens[receiver_end] as Dictionary):
					continue
				var literal_index := _literal_token_index(tokens, index + 1)
				if literal_index >= tokens.size():
					continue
				var close_index := _next_non_continuation_token(
					tokens,
					literal_index + 1
				)
				if close_index >= tokens.size() \
						or str((tokens[close_index] as Dictionary).get("text", "")) \
							!= "]":
					continue
				var literal_token := tokens[literal_index] as Dictionary
				var key := str(literal_token.get("value", ""))
				if str(literal_token.get("kind", "")) != "string":
					continue
				var receiver := _normalized_receiver(tokens, receiver_end)
				rows.append(_direct_literal_access_row(
					path,
					current_function,
					key,
					"bracket",
					receiver
				))
	return rows


func _direct_literal_access_row(
	path: String,
	function_id: String,
	key: String,
	access_form: String,
	receiver: String
) -> Dictionary:
	var key_literal := JSON.stringify(key)
	var expression := "%s[%s]" % [receiver, key_literal] \
		if access_form == "bracket" \
		else "%s.%s(%s)" % [receiver, access_form, key_literal]
	return {
		"path": path,
		"function": function_id,
		"key": key,
		"access_form": access_form,
		"normalized_receiver": receiver,
		"normalized_access_expression": expression,
	}


func _lex_gdscript(source: String) -> Array:
	var tokens: Array = []
	var index := 0
	while index < source.length():
		var code := source.unicode_at(index)
		if code == 32 or code == 9 or code == 10 or code == 13:
			index += 1
			continue
		var character := source.substr(index, 1)
		if character == "#":
			while index < source.length() \
					and source.unicode_at(index) != 10:
				index += 1
			continue
		if character == "r" and index + 1 < source.length() \
				and ["\"", "'"].has(source.substr(index + 1, 1)):
			var parsed := _read_gdscript_string(source, index + 1, true)
			tokens.append({
				"kind": "string",
				"text": str(parsed.get("value", "")),
				"value": str(parsed.get("value", "")),
			})
			index = int(parsed.get("next_index", source.length()))
			continue
		if character == "\"" or character == "'":
			var parsed := _read_gdscript_string(source, index)
			tokens.append({
				"kind": "string",
				"text": str(parsed.get("value", "")),
				"value": str(parsed.get("value", "")),
			})
			index = int(parsed.get("next_index", source.length()))
			continue
		if _is_identifier_start(code):
			var start := index
			index += 1
			while index < source.length() \
					and _is_identifier_part(source.unicode_at(index)):
				index += 1
			tokens.append({
				"kind": "identifier",
				"text": source.substr(start, index - start),
			})
			continue
		if code >= 48 and code <= 57:
			var start := index
			index += 1
			while index < source.length():
				var number_code := source.unicode_at(index)
				if not ((number_code >= 48 and number_code <= 57) \
						or (number_code >= 65 and number_code <= 70) \
						or (number_code >= 97 and number_code <= 102) \
						or number_code == 95):
					break
				index += 1
			tokens.append({
				"kind": "number",
				"text": source.substr(start, index - start),
			})
			continue
		tokens.append({
			"kind": "symbol",
			"text": character,
		})
		index += 1
	return tokens


func _read_gdscript_string(
	source: String,
	start: int,
	raw_literal := false
) -> Dictionary:
	var quote := source.substr(start, 1)
	var triple := start + 2 < source.length() \
		and source.substr(start, 3) == quote + quote + quote
	var delimiter_size := 3 if triple else 1
	var index := start + delimiter_size
	var value := ""
	while index < source.length():
		if triple and index + 2 < source.length() \
				and source.substr(index, 3) == quote + quote + quote:
			return {
				"value": value,
				"next_index": index + 3,
			}
		var character := source.substr(index, 1)
		if not triple and character == quote:
			return {
				"value": value,
				"next_index": index + 1,
			}
		if character == "\\" and index + 1 < source.length():
			var escaped := source.substr(index + 1, 1)
			if raw_literal:
				if escaped == quote:
					value += quote
					index += 2
				else:
					value += "\\"
					index += 1
				continue
			var unicode_width := 0
			if escaped == "x":
				unicode_width = 2
			elif escaped == "u":
				unicode_width = 4
			elif escaped == "U":
				unicode_width = 8
			if unicode_width > 0 \
					and index + 2 + unicode_width <= source.length():
				var hex_text := source.substr(index + 2, unicode_width)
				if _is_hex_sequence(hex_text):
					value += String.chr(hex_text.hex_to_int())
					index += 2 + unicode_width
					continue
			match escaped:
				"n": value += "\n"
				"r": value += "\r"
				"t": value += "\t"
				"b": value += "\b"
				"f": value += "\f"
				"v": value += "\v"
				"a": value += String.chr(7)
				"\n": pass
				_: value += escaped
			index += 2
			continue
		value += character
		index += 1
	return {
		"value": value,
		"next_index": source.length(),
	}


func _is_hex_sequence(value: String) -> bool:
	if value.is_empty():
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not ((code >= 48 and code <= 57) \
				or (code >= 65 and code <= 70) \
				or (code >= 97 and code <= 102)):
			return false
	return true


func _is_identifier_start(code: int) -> bool:
	return code == 95 \
		or (code >= 65 and code <= 90) \
		or (code >= 97 and code <= 122) \
		or code > 127


func _is_identifier_part(code: int) -> bool:
	return _is_identifier_start(code) or (code >= 48 and code <= 57)


func _literal_token_index(tokens: Array, start_index: int) -> int:
	var index := _next_non_continuation_token(tokens, start_index)
	if index < tokens.size() \
			and str((tokens[index] as Dictionary).get("text", "")) == "&":
		index = _next_non_continuation_token(tokens, index + 1)
	return index


func _next_non_continuation_token(tokens: Array, start_index: int) -> int:
	var index := start_index
	while index < tokens.size() \
			and str((tokens[index] as Dictionary).get("text", "")) == "\\":
		index += 1
	return index


func _previous_non_continuation_token(tokens: Array, start_index: int) -> int:
	var index := start_index
	while index >= 0 \
			and str((tokens[index] as Dictionary).get("text", "")) == "\\":
		index -= 1
	return index


func _can_end_receiver(token: Dictionary) -> bool:
	var kind := str(token.get("kind", ""))
	var text := str(token.get("text", ""))
	if kind == "identifier":
		return not [
			"and",
			"as",
			"await",
			"const",
			"elif",
			"else",
			"for",
			"func",
			"if",
			"in",
			"match",
			"not",
			"or",
			"return",
			"static",
			"var",
			"when",
			"while",
		].has(text)
	return kind == "string" or kind == "number" \
		or [")", "]", "}"].has(text)


func _normalized_receiver(tokens: Array, receiver_end: int) -> String:
	var receiver_start := _receiver_start_index(tokens, receiver_end)
	receiver_start = maxi(
		receiver_start,
		receiver_end - RAW_ACCESS_RECEIVER_TOKEN_LIMIT + 1
	)
	var normalized := ""
	for index in range(receiver_start, receiver_end + 1):
		var token := tokens[index] as Dictionary
		if str(token.get("text", "")) == "\\":
			continue
		normalized += _canonical_token(token)
	return normalized


func _receiver_start_index(tokens: Array, receiver_end: int) -> int:
	var start := _receiver_atom_start(tokens, receiver_end)
	while start >= 2:
		var dot_index := _previous_non_continuation_token(tokens, start - 1)
		if dot_index < 1 \
				or str((tokens[dot_index] as Dictionary).get("text", "")) != ".":
			break
		var left_end := _previous_non_continuation_token(tokens, dot_index - 1)
		if left_end < 0 or not _can_end_receiver(tokens[left_end] as Dictionary):
			break
		start = _receiver_atom_start(tokens, left_end)
	return start


func _receiver_atom_start(tokens: Array, receiver_end: int) -> int:
	if receiver_end < 0:
		return 0
	var token := tokens[receiver_end] as Dictionary
	var text := str(token.get("text", ""))
	if not [")", "]", "}"].has(text):
		return receiver_end
	var opening := "(" if text == ")" else "[" if text == "]" else "{"
	var opening_index := _matching_open_token(
		tokens,
		receiver_end,
		opening,
		text
	)
	if opening_index < 0:
		return receiver_end
	var previous := _previous_non_continuation_token(tokens, opening_index - 1)
	if previous >= 0 and _can_end_receiver(tokens[previous] as Dictionary):
		return _receiver_start_index(tokens, previous)
	return opening_index


func _matching_open_token(
	tokens: Array,
	close_index: int,
	opening: String,
	closing: String
) -> int:
	var depth := 0
	for index in range(close_index, -1, -1):
		var text := str((tokens[index] as Dictionary).get("text", ""))
		if text == closing:
			depth += 1
		elif text == opening:
			depth -= 1
			if depth == 0:
				return index
	return -1


func _canonical_token(token: Dictionary) -> String:
	if str(token.get("kind", "")) == "string":
		return JSON.stringify(str(token.get("value", "")))
	return str(token.get("text", ""))


func _source_map(paths: Array) -> Dictionary:
	var result: Dictionary = {}
	for path_variant in paths:
		var path := str(path_variant)
		if not FileAccess.file_exists(path):
			_failures.append("missing source: %s" % path)
			continue
		var source := FileAccess.get_file_as_string(path)
		if source.is_empty():
			_failures.append("empty source: %s" % path)
			continue
		result[path] = source
	return result


func _production_source_map() -> Dictionary:
	var paths: Array[String] = []
	_collect_gdscript_paths("res://scripts", paths)
	paths.sort()
	var production_paths: Array[String] = []
	for path in paths:
		if not path.begins_with("res://scripts/tools/"):
			production_paths.append(path)
	return _source_map(production_paths)


func _project_production_source_map() -> Dictionary:
	var paths: Array[String] = []
	_collect_gdscript_paths("res://", paths)
	paths.sort()
	var production_paths: Array[String] = []
	for path in paths:
		var excluded := false
		for prefix in PROJECT_PRODUCTION_GDSCRIPT_EXCLUDED_PREFIXES:
			if path.begins_with(prefix):
				excluded = true
				break
		if not excluded:
			production_paths.append(path)
	return _source_map(production_paths)


func _collect_gdscript_paths(
	directory_path: String,
	paths: Array[String]
) -> void:
	for file_name in DirAccess.get_files_at(directory_path):
		if file_name.ends_with(".gd"):
			paths.append(directory_path.path_join(file_name))
	for child_name in DirAccess.get_directories_at(directory_path):
		if not child_name.begins_with("."):
			_collect_gdscript_paths(
				directory_path.path_join(child_name),
				paths
			)


func _dictionary_key_has_prefix(values: Dictionary, prefix: String) -> bool:
	for key_variant in values.keys():
		if str(key_variant).begins_with(prefix):
			return true
	return false


func _combined_source(paths: Array) -> String:
	var chunks: Array[String] = []
	var sources := _source_map(paths)
	for path_variant in paths:
		var path := str(path_variant)
		if sources.has(path):
			chunks.append(str(sources[path]))
	return "\n".join(chunks)


func _token_hits(sources: Dictionary, tokens: Array) -> Array[String]:
	var hits: Array[String] = []
	for path_variant in sources.keys():
		var path := str(path_variant)
		var source := str(sources[path])
		for token_variant in tokens:
			var token := str(token_variant)
			if source.contains(token):
				hits.append("%s:%s" % [path, token])
	return hits


func _paths_calling_tokens(sources: Dictionary, tokens: Array) -> Array[String]:
	var paths: Array[String] = []
	for path_variant in sources.keys():
		var path := str(path_variant)
		var source := str(sources[path])
		for token_variant in tokens:
			if source.contains(str(token_variant)):
				paths.append(path)
				break
	paths.sort()
	return paths


func _json_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_expect(false, "JSON report exists: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(parsed is Dictionary, "JSON report parses: %s" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _sorted_string_keys(values: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key_variant in values.keys():
		keys.append(str(key_variant))
	keys.sort()
	return keys


func _integer_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (value is Dictionary):
		return result
	for key_variant in (value as Dictionary).keys():
		result[str(key_variant)] = int((value as Dictionary)[key_variant])
	return result


func _signature(function_id: String, field_id: String) -> String:
	return "%s::%s" % [function_id, field_id]


func _sum_dictionary_values(values: Dictionary) -> int:
	var total := 0
	for value_variant in values.values():
		total += int(value_variant)
	return total


func _signature_count_mismatches(
	expected: Dictionary,
	observed: Dictionary,
	access_id: String
) -> Array[String]:
	var signatures: Dictionary = {}
	for signature_variant in expected.keys():
		signatures[str(signature_variant)] = true
	for signature_variant in observed.keys():
		signatures[str(signature_variant)] = true
	var ordered_signatures: Array[String] = []
	for signature_variant in signatures.keys():
		ordered_signatures.append(str(signature_variant))
	ordered_signatures.sort()
	var mismatches: Array[String] = []
	for signature in ordered_signatures:
		var expected_count := int(expected.get(signature, 0))
		var observed_count := int(observed.get(signature, 0))
		if observed_count != expected_count:
			mismatches.append(
				"%s:%s:expected=%d:observed=%d"
					% [access_id, signature, expected_count, observed_count]
			)
	return mismatches


func _count_occurrences(source: String, token: String) -> int:
	if token.is_empty():
		return 0
	return source.split(token).size() - 1


func _function_block(source: String, function_id: String) -> String:
	var lines: Array[String] = []
	var collecting := false
	for raw_line in source.split("\n"):
		var line := str(raw_line)
		var stripped := line.strip_edges()
		if stripped.begins_with("func ") \
				or stripped.begins_with("static func "):
			if collecting:
				break
			collecting = stripped.begins_with("func %s(" % function_id) \
				or stripped.begins_with("static func %s(" % function_id)
		if collecting:
			lines.append(line)
	return "\n".join(lines)


func _count_nonliteral_receiver_calls(source: String) -> int:
	var regex := RegEx.new()
	regex.compile("\\b(evaluated_skill|source_skill|counter_skill|role_card|skill|role)\\.(get|has)\\(\\s*[a-zA-Z_][a-zA-Z0-9_]*")
	return regex.search_all(source).size()


func _count_nonliteral_receiver_indexes(source: String) -> int:
	var regex := RegEx.new()
	regex.compile("\\b(evaluated_skill|source_skill|counter_skill|role_card|skill|role)\\[\\s*[a-zA-Z_][a-zA-Z0-9_]*\\s*\\]")
	return regex.search_all(source).size()


func _contains_non_ascii(source: String) -> bool:
	for index in range(source.length()):
		if source.unicode_at(index) > 127:
			return true
	return false


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var elapsed_usec := Time.get_ticks_usec() - _started_usec
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"CARD_SEMANTIC_ARCHITECTURE_SCAN|status=%s|checks=%d|failures=%d|elapsed_usec=%d|value_reads=%d|presence_checks=%d|functions=%d|keys=%d|new_violations=%d"
		% [
			status,
			_checks,
			_failures.size(),
			elapsed_usec,
			int(_debt_snapshot.get("value_reads", -1)),
			int(_debt_snapshot.get("presence_checks", -1)),
			int(_debt_snapshot.get("functions", -1)),
			int(_debt_snapshot.get("keys", -1)),
			int(_debt_snapshot.get("new_violations", -1)),
		]
	)
	for failure in _failures:
		push_error("CARD_SEMANTIC_ARCHITECTURE_SCAN: %s" % failure)
	print("CARD_SEMANTIC_ARCHITECTURE_SCAN_COMPLETE")
	quit(0 if _failures.is_empty() else 1)
