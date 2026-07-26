extends SceneTree

const ADAPTER_SCRIPT := preload(
	"res://scripts/runtime/card_codex_public_source_adapter.gd"
)

const SOURCE_PATH := \
	"res://scripts/runtime/card_codex_public_source_service.gd"
const SNAPSHOT_PATH := \
	"res://scripts/runtime/card_codex_public_snapshot_service.gd"
const ADAPTER_PATH := \
	"res://scripts/runtime/card_codex_public_source_adapter.gd"
const BROWSER_SNAPSHOT_PATH := \
	"res://scripts/viewmodels/card_codex_browser_snapshot.gd"
const DETAIL_SNAPSHOT_PATH := \
	"res://scripts/viewmodels/card_codex_detail_snapshot.gd"
const PLAYER_FACE_PROJECTION_PATH := \
	"res://scripts/runtime/card_player_face_projection_service.gd"
const LOCALIZATION_SOURCE_PATH := \
	"res://scripts/runtime/card_player_face_public_localization_source_service.gd"
const LOCALIZATION_SCHEMA_PATH := \
	"res://scripts/presentation/authorized_card_player_face_localization_source_v1.gd"
const CODEX_DTO_PATH := \
	"res://scripts/presentation/player_card_codex_dto_v1.gd"
const FAMILY_LADDER_DTO_PATH := \
	"res://scripts/presentation/player_card_codex_family_ladder_dto_v1.gd"
const SEMANTIC_CATALOG_PATH := \
	"res://scripts/runtime/card_semantic_catalog_service.gd"
const OWN_HAND_AUTHORIZATION_PATH := \
	"res://scripts/runtime/card_semantic_source_authorization_port.gd"
const AI_RUNTIME_PATH := "res://scripts/runtime/ai_runtime_controller.gd"
const MAIN_PATH := "res://scripts/main.gd"
const COORDINATOR_SCENE_PATH := \
	"res://scenes/runtime/GameRuntimeCoordinator.tscn"
const COORDINATOR_SCRIPT_PATH := \
	"res://scripts/runtime/game_runtime_coordinator.gd"

const CODEX_CONSUMER_PATHS := [
	SOURCE_PATH,
	SNAPSHOT_PATH,
	ADAPTER_PATH,
	BROWSER_SNAPSHOT_PATH,
	DETAIL_SNAPSHOT_PATH,
]
const PLAYER_PROJECTION_BOUNDARY_PATHS := [
	SOURCE_PATH,
	SNAPSHOT_PATH,
	ADAPTER_PATH,
	BROWSER_SNAPSHOT_PATH,
	DETAIL_SNAPSHOT_PATH,
	PLAYER_FACE_PROJECTION_PATH,
	LOCALIZATION_SOURCE_PATH,
	LOCALIZATION_SCHEMA_PATH,
	CODEX_DTO_PATH,
	FAMILY_LADDER_DTO_PATH,
]
const COMPATIBILITY_ALIAS_PATHS := [
	ADAPTER_PATH,
	SNAPSHOT_PATH,
	DETAIL_SNAPSHOT_PATH,
]
const EXPECTED_COMPATIBILITY_ALIAS_COUNTS := {
	ADAPTER_PATH: {"cost": 2, "price": 2, "play_cost": 1},
	SNAPSHOT_PATH: {"cost": 1, "price": 1, "play_cost": 0},
	DETAIL_SNAPSHOT_PATH: {"cost": 1, "price": 1, "play_cost": 0},
}
const EXPECTED_RETIREMENT_KEYS := [
	"card_name",
	"cost",
	"effect",
	"kind",
	"price",
	"rank",
	"roman",
	"route",
	"type",
]

var _checks := 0
var _failures: Array[String] = []
var _started_usec := 0


func _init() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	_test_sources_are_present()
	_test_raw_rule_reads_and_text_inference_are_absent()
	_test_stable_identity_boundary()
	_test_compatibility_alias_allowlist()
	_test_dependency_and_execution_boundaries()
	_test_compile_call_sites()
	_test_composition_and_consumer_boundaries()
	_finish()


func _test_sources_are_present() -> void:
	for path in PLAYER_PROJECTION_BOUNDARY_PATHS:
		_expect(
			FileAccess.file_exists(path)
				and not FileAccess.get_file_as_string(path).is_empty(),
			"production source is readable: %s" % path
		)


func _test_raw_rule_reads_and_text_inference_are_absent() -> void:
	var consumer_sources := _source_map(CODEX_CONSUMER_PATHS)
	for forbidden_read in [
		'.get("player"',
		'.get("developer"',
		'.get("effect_payload"',
		'.get("effect_kind"',
		'.get("target_kind"',
		'["effect_payload"]',
		'["effect_kind"]',
		'["target_kind"]',
	]:
		_expect(
			_token_hits(consumer_sources, [forbidden_read]).is_empty(),
			"Codex DTO consumers omit raw rule read: %s" % forbidden_read
		)

	var combined := _combined_source(CODEX_CONSUMER_PATHS)
	for forbidden_inference in [
		"target_kind.contains",
		"effect_kind.contains",
		"kind.contains",
		"_tactical_timing_text",
		"_tactical_combo_text",
		"_tactical_clue_text",
		"strategy_route_label",
		"requires_target",
		"targets_player",
		"targets_monster",
		"recommended_target",
		"use_case",
	]:
		_expect(
			not combined.contains(forbidden_inference),
			"Codex path omits legacy rule inference: %s" % forbidden_inference
		)

	var localization_source := FileAccess.get_file_as_string(
		LOCALIZATION_SOURCE_PATH
	)
	var prose_branch_hits: Array[String] = []
	for raw_line in localization_source.split("\n"):
		var line := str(raw_line).strip_edges()
		if (line.begins_with("if ") or line.begins_with("elif ") \
				or line.begins_with("match ")) \
				and (line.contains('player.get("effect"') \
					or line.contains('player.get("target"') \
					or line.contains('player.get("timing"') \
					or line.contains('player.get("duration"') \
					or line.contains('player.get("next_step"') \
					or line.contains('player.get("name"')):
			prose_branch_hits.append(line)
	_expect(
		prose_branch_hits.is_empty(),
		"trusted localization never branches on authored player prose"
	)


func _test_stable_identity_boundary() -> void:
	var source := FileAccess.get_file_as_string(SOURCE_PATH)
	var resolve_block := _function_block(source, "resolve_card_id")
	_expect(not resolve_block.is_empty(), "stable Card Codex identity entry exists")
	_expect(
		resolve_block.contains("_dto_by_card_id.has(card_id)"),
		"Card Codex identity accepts only a cached stable card_id"
	)
	for forbidden in [
		"display_name",
		"family_name",
		"roman",
		"RegEx",
		"ends_with",
		"trim_suffix",
		"to_int",
		"split(",
		"\u602a\u517d\u00b7",
	]:
		_expect(
			not resolve_block.contains(forbidden),
			"stable identity resolver does not parse localized/rank text: %s"
				% forbidden
		)

	var consumer_source := _combined_source(CODEX_CONSUMER_PATHS)
	for forbidden_helper in [
		"_rank_number(",
		"_rank_from_name(",
		"_roman_rank(",
		"_resolve_monster_card_id(",
		"name_to_card_id",
	]:
		_expect(
			not consumer_source.contains(forbidden_helper),
			"Codex path has no localized identity helper: %s" % forbidden_helper
		)


func _test_compatibility_alias_allowlist() -> void:
	var alias_regex := RegEx.new()
	alias_regex.compile('"(cost|price|play_cost)"\\s*:')
	for path in COMPATIBILITY_ALIAS_PATHS:
		var counts := {"cost": 0, "price": 0, "play_cost": 0}
		var source := FileAccess.get_file_as_string(path)
		for raw_line in source.split("\n"):
			for match_variant in alias_regex.search_all(str(raw_line)):
				var alias_id := (match_variant as RegExMatch).get_string(1)
				counts[alias_id] = int(counts.get(alias_id, 0)) + 1
		_expect(
			counts == EXPECTED_COMPATIBILITY_ALIAS_COUNTS[path],
			"legacy cost aliases stay on the exact path/count allowlist: %s actual=%s"
				% [path, counts]
		)

	var non_compatibility_paths: Array = CODEX_CONSUMER_PATHS.duplicate()
	for compatibility_path in COMPATIBILITY_ALIAS_PATHS:
		non_compatibility_paths.erase(compatibility_path)
	for path in non_compatibility_paths:
		var source := FileAccess.get_file_as_string(path)
		_expect(
			alias_regex.search(source) == null,
			"legacy cost aliases do not escape the compatibility boundary: %s"
				% path
		)

	var retirement_keys: Array = \
		ADAPTER_SCRIPT.COMPATIBILITY_ALIAS_RETIREMENT.keys()
	retirement_keys.sort()
	var expected_keys: Array = EXPECTED_RETIREMENT_KEYS.duplicate()
	expected_keys.sort()
	_expect(
		retirement_keys == expected_keys,
		"compatibility alias retirement list is closed and cannot grow silently"
	)
	for alias_id in retirement_keys:
		var row := ADAPTER_SCRIPT.COMPATIBILITY_ALIAS_RETIREMENT.get(
			alias_id,
			{}
		) as Dictionary
		var row_keys: Array = row.keys()
		row_keys.sort()
		_expect(
			row_keys == ["consumer", "remove_when", "replacement"] \
				and not str(row.get("consumer", "")).is_empty() \
				and not str(row.get("remove_when", "")).is_empty() \
				and not str(row.get("replacement", "")).is_empty(),
			"compatibility alias has an exact retirement record: %s" % alias_id
		)
	_expect(
		_count_occurrences(
			FileAccess.get_file_as_string(ADAPTER_PATH),
			'.get("play_cost"'
		) == 0,
		"play_cost is denied but never consumed"
	)


func _test_dependency_and_execution_boundaries() -> void:
	var sources := _source_map(PLAYER_PROJECTION_BOUNDARY_PATHS)
	for forbidden_dependency in [
		"/root/Main",
		"res://scripts/main.gd",
		"get_tree().current_scene",
		"current_scene",
		"to_save_data(",
		"apply_save_data(",
		"register_save_owner(",
		"request_save(",
		"RunRngService",
		"RandomNumberGenerator",
		"randomize(",
		"randi(",
		"randf(",
		"AiRuntimeController",
		"AiCardSemanticProjectionService",
		"RulesProjection",
		"RuleExecutionPlan",
		"OperationHandlerRegistry",
		"register_handler(",
		"func _process(",
		"func _physics_process(",
	]:
		_expect(
			_token_hits(sources, [forbidden_dependency]).is_empty(),
			"Player projection boundary omits forbidden dependency: %s"
				% forbidden_dependency
		)

	var main_source := FileAccess.get_file_as_string(MAIN_PATH)
	for forbidden_main_responsibility in [
		"PlayerCardCodexDTO",
		"CardPlayerFacePublicLocalizationSourceService",
		"project_authorized_public_detail",
		"authorize_public_codex_record",
		"card_player_face_public_localization",
	]:
		_expect(
			not main_source.contains(forbidden_main_responsibility),
			"Main gains no Card Codex semantic responsibility: %s"
				% forbidden_main_responsibility
		)

	var own_hand_source := FileAccess.get_file_as_string(
		OWN_HAND_AUTHORIZATION_PATH
	)
	_expect(
		not own_hand_source.contains("public_codex") \
			and not own_hand_source.contains("codex_public") \
			and not own_hand_source.contains("CardPlayerFace"),
		"public Codex authorization does not expand the own-hand port"
	)


func _test_compile_call_sites() -> void:
	var compile_calls: Array[String] = []
	for path in PLAYER_PROJECTION_BOUNDARY_PATHS:
		var current_function := "<top_level>"
		for raw_line in FileAccess.get_file_as_string(path).split("\n"):
			var line := str(raw_line).strip_edges()
			if line.begins_with("func "):
				current_function = line.trim_prefix("func ").get_slice("(", 0)
			if line.contains("compile_authorized(") \
					or line.contains(".compile_record(") \
					or line.contains(".compile("):
				compile_calls.append("%s::%s" % [path, current_function])
	for call_site in compile_calls:
		_expect(
			call_site == "%s::configure" % LOCALIZATION_SOURCE_PATH,
			"semantic compilation is initialization-only: %s" % call_site
		)
	var source := FileAccess.get_file_as_string(SOURCE_PATH)
	for render_entry in [
		"compose_browser_source",
		"compose_browser",
		"compose_card_facts",
		"compose_upgrades",
		"compose_detail",
	]:
		var block := _function_block(source, render_entry)
		_expect(
			not block.contains("compile_") \
				and not block.contains("catalog_snapshot(") \
				and not block.contains(".reload("),
			"render/hover/detail entry performs no compile or catalog reload: %s"
				% render_entry
		)


func _test_composition_and_consumer_boundaries() -> void:
	var coordinator_scene := FileAccess.get_file_as_string(
		COORDINATOR_SCENE_PATH
	)
	_expect(
		_count_occurrences(
			coordinator_scene,
			'[node name="CardCodexPublicSourceService"'
		) == 1,
		"production coordinator composes exactly one Card Codex source"
	)
	_expect(
		_count_occurrences(
			coordinator_scene,
			'[node name="CardPlayerFacePublicLocalizationSourceService"'
		) == 1,
		"production coordinator composes exactly one public localization owner"
	)
	_expect(
		_count_occurrences(
			coordinator_scene,
			'[node name="CardPlayerFaceProjectionService"'
		) == 1,
		"production coordinator composes exactly one Card PlayerFace projector"
	)
	var coordinator_source := FileAccess.get_file_as_string(
		COORDINATOR_SCRIPT_PATH
	)
	_expect(
		coordinator_source.contains(
			'card_codex_public_source.call("bind_dependencies"'
		) \
			and not coordinator_source.contains(
				'card_codex_public_source.call("configure"'
			),
		"production startup binds Codex dependencies without eagerly building all DTOs"
	)
	var snapshot_source := FileAccess.get_file_as_string(SNAPSHOT_PATH)
	_expect(
		not snapshot_source.contains("CardSemanticSpec") \
			and not snapshot_source.contains("统一玩家投影") \
			and not snapshot_source.contains("结构化语义"),
		"player-visible Codex copy contains no implementation architecture narration"
	)

	var catalog_source := FileAccess.get_file_as_string(SEMANTIC_CATALOG_PATH)
	var localization_source := FileAccess.get_file_as_string(
		LOCALIZATION_SOURCE_PATH
	)
	for forbidden_api in [
		"func public_semantic_spec_for_card_id",
		"func authorize_public_codex_card_id",
		"func public_semantic_catalog_snapshot",
	]:
		_expect(
			not catalog_source.contains(forbidden_api),
			"semantic catalog exposes no arbitrary public lookup: %s" % forbidden_api
		)
	for forbidden_api in [
		"func issue_for_card_id",
		"func localization_for_card_id",
		"func catalog_snapshot",
		"func enumerate",
	]:
		_expect(
			not localization_source.contains(forbidden_api),
			"localization owner exposes no arbitrary lookup/enumeration: %s"
				% forbidden_api
		)

	var ai_source := FileAccess.get_file_as_string(AI_RUNTIME_PATH)
	for forbidden_ai_consumer in [
		"PlayerCardCodexDTO",
		"CardPlayerFacePublicLocalizationSourceService",
		"project_authorized_public_detail",
		"authorize_public_codex_record",
		"card_codex_public",
	]:
		_expect(
			not ai_source.contains(forbidden_ai_consumer),
			"production AI does not consume the Codex PlayerFace path: %s"
				% forbidden_ai_consumer
		)


func _source_map(paths: Array) -> Dictionary:
	var result: Dictionary = {}
	for path_variant in paths:
		var path := str(path_variant)
		if FileAccess.file_exists(path):
			result[path] = FileAccess.get_file_as_string(path)
	return result


func _combined_source(paths: Array) -> String:
	var chunks: Array[String] = []
	for path_variant in paths:
		chunks.append(FileAccess.get_file_as_string(str(path_variant)))
	return "\n".join(chunks)


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


func _count_occurrences(source: String, token: String) -> int:
	return 0 if token.is_empty() else source.split(token).size() - 1


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
		"CARD_CODEX_PLAYERFACE_ARCHITECTURE_SCAN_TEST|status=%s|checks=%d|failures=%d|duration_ms=%.3f|details=%s"
		% [
			status,
			_checks,
			_failures.size(),
			duration_ms,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
