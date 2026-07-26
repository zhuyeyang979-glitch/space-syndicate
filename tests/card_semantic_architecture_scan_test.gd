extends SceneTree

const SAVE_REGISTRY := preload("res://scripts/runtime/v06_save_owner_registry.gd")

const AI_DEBT_REPORT_PATH := "res://reports/cards/ai_direct_field_read_migration.json"
const NAME_KIND_REPORT_PATH := "res://reports/semantic_program/name_and_kind_special_case_audit.json"
const AI_RUNTIME_PATH := "res://scripts/runtime/ai_runtime_controller.gd"
const CATALOG_SERVICE_PATH := "res://scripts/runtime/card_semantic_catalog_service.gd"
const SOURCE_AUTHORIZATION_PATH := "res://scripts/runtime/card_semantic_source_authorization_port.gd"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"

const SEMANTIC_SOURCE_PATHS := [
	"res://scripts/cards/semantic/card_semantic_schema_v1.gd",
	"res://scripts/cards/semantic/card_semantic_compiler_v1.gd",
	"res://scripts/cards/semantic/authorized_card_semantic_envelope_v1.gd",
	"res://scripts/cards/semantic/card_instance_decision_state_v1.gd",
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
	_scan_authorized_source_boundary()
	_scan_save_registry_contract()
	_scan_ai_raw_field_debt()
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
	var expected_methods: Array[String] = [
		"authorize_semantic_spec",
		"compile_authorized",
		"configure",
		"debug_snapshot",
		"validation_snapshot",
	]
	_expect(
		public_methods == expected_methods,
		"CardSemanticCatalogService exposes only authorized semantic access and aggregate diagnostics"
	)
	for forbidden in [
		"func semantic_for_card_id",
		"func card_ids",
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


func _scan_authorized_source_boundary() -> void:
	var source := FileAccess.get_file_as_string(SOURCE_AUTHORIZATION_PATH)
	var coordinator_scene := FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH)
	_expect(not source.is_empty(), "authorized semantic source port is readable")
	_expect(
		_count_occurrences(
			coordinator_scene,
			'[node name="CardSemanticSourceAuthorizationPort"'
		) == 1,
		"production coordinator composes exactly one source authorization port"
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
		"authorize_own_hand_card",
		"authorize_source",
		"bind_ai_capability",
		"debug_snapshot",
		"is_ready",
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


func _scan_ai_raw_field_debt() -> void:
	var report := _json_object(AI_DEBT_REPORT_PATH)
	if report.is_empty():
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

	var violations: Array[String] = []
	for signature_variant in observed_values.keys():
		var signature := str(signature_variant)
		if not expected_values.has(signature) or int(observed_values[signature]) > int(expected_values.get(signature, 0)):
			violations.append("value:%s:%d" % [signature, int(observed_values[signature])])
	for signature_variant in observed_presence.keys():
		var signature := str(signature_variant)
		if not expected_presence.has(signature) or int(observed_presence[signature]) > int(expected_presence.get(signature, 0)):
			violations.append("presence:%s:%d" % [signature, int(observed_presence[signature])])
	var observed_value_count := _sum_dictionary_values(observed_values)
	var observed_presence_count := _sum_dictionary_values(observed_presence)
	_debt_snapshot = {
		"value_reads": observed_value_count,
		"presence_checks": observed_presence_count,
		"functions": observed_functions.size(),
		"keys": observed_keys.size(),
		"new_violations": violations.size(),
	}
	_expect(observed_value_count <= 225, "AI raw value-read debt does not exceed 225")
	_expect(observed_presence_count <= 5, "AI raw presence-check debt does not exceed 5")
	_expect(observed_functions.size() <= 33 and observed_keys.size() <= 71, "AI raw debt functions and keys only ratchet downward")
	_expect(violations.is_empty(), "AI has no raw field read outside the report allowlist: %s" % [violations])


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


func _json_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_expect(false, "JSON report exists: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(parsed is Dictionary, "JSON report parses: %s" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _signature(function_id: String, field_id: String) -> String:
	return "%s::%s" % [function_id, field_id]


func _sum_dictionary_values(values: Dictionary) -> int:
	var total := 0
	for value_variant in values.values():
		total += int(value_variant)
	return total


func _count_occurrences(source: String, token: String) -> int:
	if token.is_empty():
		return 0
	return source.split(token).size() - 1


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
