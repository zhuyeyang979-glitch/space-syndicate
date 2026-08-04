extends RefCounted
class_name V074LegacyMainRetirementAudit

const AUDIT_SCHEMA_VERSION := 1
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const V074_BOOTSTRAP_PATH := (
	"res://scripts/v074_runtime/v074_application_bootstrap.gd"
)
const LEGACY_MAIN_PATH := "res://scripts/" + "main.gd"
const LEGACY_MAIN_UID_PATH := LEGACY_MAIN_PATH + ".uid"
const LEGACY_MAIN_RESOURCE_TOKEN := "scripts/" + "main.gd"
const LEGACY_MAIN_UID := "uid://" + "3cmrttqsu44h"
const ROOT_MAIN_TOKEN := "/root/" + "Main"
const ACTIVE_V074_TEST_PREFIX := "v074_"
const TEXT_SUFFIXES: Array[String] = [
	".gd",
	".tscn",
	".tres",
	".res",
	".gdshader",
]
const COMPATIBILITY_WRAPPER_NAMES: Array[String] = [
	"main_legacy.gd",
	"main_old.gd",
	"main_compat.gd",
	"legacy_main_adapter.gd",
	"main_monolith_v2.gd",
]
const BOOTSTRAP_ALLOWED_METHODS: Array[String] = [
	"_ready",
	"_on_application_intent_requested",
	"_on_projection_changed",
	"_on_receipt_ready",
	"_on_final_settlement_presented",
	"_on_runtime_fault_presented",
]
const BOOTSTRAP_DOMAIN_RULE_TOKENS: Array[String] = [
	"V074MapGenesisCore",
	"V074FacilityTypeRegistry",
	"warehouse_runtime",
	"facility_contention",
	"solar_efficiency",
	"victory_rule",
	"ai_policy",
]
const BOOTSTRAP_GAMEPLAY_MUTATION_TOKENS: Array[String] = [
	".set(",
	"advance_world",
	"resolve_batch",
	"apply_damage",
	"build_facility",
	"mutate_world",
]
const BOOTSTRAP_SAVE_OWNER_TOKENS: Array[String] = [
	"SaveOwner",
	"request_save",
	"request_load",
	"to_save_data",
	"apply_save_data",
	"FileAccess",
	"DirAccess",
]
const BOOTSTRAP_RNG_OWNER_TOKENS: Array[String] = [
	"RandomNumberGenerator",
	"RunRngService",
	"randf(",
	"randi(",
	"rand_from_seed(",
]


static func production_dependency_closure() -> Array[String]:
	var queue: Array[String] = [MAIN_SCENE_PATH]
	var visited: Dictionary = {}
	var result: Array[String] = []
	var resource_pattern := RegEx.new()
	resource_pattern.compile(
		"res://[A-Za-z0-9_./@-]+\\.(?:gd|tscn|tres|res|gdshader)"
	)
	while not queue.is_empty():
		var path: String = str(queue.pop_front())
		if visited.has(path):
			continue
		visited[path] = true
		result.append(path)
		if not FileAccess.file_exists(path):
			continue
		var source := FileAccess.get_file_as_string(path)
		for match_variant in resource_pattern.search_all(source):
			var match_result := match_variant as RegExMatch
			var dependency := match_result.get_string()
			if (
				not visited.has(dependency)
				and FileAccess.file_exists(dependency)
			):
				queue.append(dependency)
	result.sort()
	return result


static func production_reference_records() -> Array[Dictionary]:
	return reference_records(production_dependency_closure())


static func active_v074_test_paths() -> Array[String]:
	var result: Array[String] = []
	for path in collect_files("res://tests", [".gd"]):
		if path.get_file().begins_with(ACTIVE_V074_TEST_PREFIX):
			result.append(path)
	result.sort()
	return result


static func active_v074_test_reference_records() -> Array[Dictionary]:
	return reference_records(active_v074_test_paths())


static func reference_records(paths: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var tokens: Array[String] = [
		LEGACY_MAIN_RESOURCE_TOKEN,
		LEGACY_MAIN_UID,
		ROOT_MAIN_TOKEN,
	]
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		var lines := FileAccess.get_file_as_string(path).replace(
			"\r\n",
			"\n"
		).split("\n")
		for line_index in range(lines.size()):
			var line := str(lines[line_index])
			for token in tokens:
				if _line_is_executable_reference(line, token):
					result.append({
						"path": path,
						"line": line_index + 1,
						"token": token,
					})
	return result


static func _line_is_executable_reference(line: String, token: String) -> bool:
	if not line.contains(token):
		return false
	var source := line.strip_edges()
	if source.begins_with("#"):
		return false
	if token == ROOT_MAIN_TOKEN:
		return (
			source.contains("get_node(")
			or source.contains("get_node_or_null(")
			or source.contains("NodePath(")
		)
	return (
		source.contains("load(")
		or source.contains("ext_resource")
		or source.contains("ResourceLoader.")
		or source.contains("FileAccess.get_file_as_string(")
	)


static func compatibility_wrapper_paths() -> Array[String]:
	var result: Array[String] = []
	for path in collect_files("res://scripts", [".gd"]):
		if COMPATIBILITY_WRAPPER_NAMES.has(path.get_file()):
			result.append(path)
	result.sort()
	return result


static func bootstrap_audit(
	path: String = V074_BOOTSTRAP_PATH
) -> Dictionary:
	var exists := FileAccess.file_exists(path)
	var source := FileAccess.get_file_as_string(path) if exists else ""
	var methods := method_names(source)
	var unexpected_methods: Array[String] = []
	for method_name in methods:
		if not BOOTSTRAP_ALLOWED_METHODS.has(method_name):
			unexpected_methods.append(method_name)
	return {
		"path": path,
		"exists": exists,
		"line_count": source_line_count(source),
		"method_names": methods,
		"unexpected_methods": unexpected_methods,
		"domain_rule_count": token_occurrence_count(
			source,
			BOOTSTRAP_DOMAIN_RULE_TOKENS
		),
		"gameplay_mutation_count": token_occurrence_count(
			source,
			BOOTSTRAP_GAMEPLAY_MUTATION_TOKENS
		),
		"save_owner_count": token_occurrence_count(
			source,
			BOOTSTRAP_SAVE_OWNER_TOKENS
		),
		"rng_owner_count": token_occurrence_count(
			source,
			BOOTSTRAP_RNG_OWNER_TOKENS
		),
		"legacy_main_reference_count": token_occurrence_count(
			source,
			[
				LEGACY_MAIN_RESOURCE_TOKEN,
				LEGACY_MAIN_UID,
				ROOT_MAIN_TOKEN,
			]
		),
	}


static func method_names(source: String) -> Array[String]:
	var result: Array[String] = []
	var method_pattern := RegEx.new()
	method_pattern.compile("(?m)^func\\s+([A-Za-z0-9_]+)\\s*\\(")
	for match_variant in method_pattern.search_all(source):
		var match_result := match_variant as RegExMatch
		result.append(match_result.get_string(1))
	return result


static func source_line_count(source: String) -> int:
	if source.is_empty():
		return 0
	return source.replace("\r\n", "\n").split("\n").size()


static func token_occurrence_count(
	source: String,
	tokens: Array[String]
) -> int:
	var total := 0
	for token in tokens:
		total += source.count(token)
	return total


static func collect_files(
	root_path: String,
	suffixes: Array[String]
) -> Array[String]:
	var result: Array[String] = []
	_collect_files_recursive(root_path, suffixes, result)
	result.sort()
	return result


static func _collect_files_recursive(
	root_path: String,
	suffixes: Array[String],
	result: Array[String]
) -> void:
	var directory := DirAccess.open(root_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != ".." and not entry.begins_with("."):
			var path := root_path.path_join(entry)
			if directory.current_is_dir():
				_collect_files_recursive(path, suffixes, result)
			elif _has_suffix(path, suffixes):
				result.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


static func _has_suffix(path: String, suffixes: Array[String]) -> bool:
	for suffix in suffixes:
		if path.ends_with(suffix):
			return true
	return false
