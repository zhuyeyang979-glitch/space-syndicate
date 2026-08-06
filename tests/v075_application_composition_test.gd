extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const V075_BOOTSTRAP_PATH := "res://scripts/v075_runtime/v075_application_bootstrap.gd"
const V075_FLOW_PATH := "res://scripts/v075_runtime/v075_application_flow.gd"
const V075_RULESET_PATH := "res://scripts/v075_runtime/v075_ruleset_runtime_owner.gd"
const V075_RUNTIME_PATH := "res://scripts/v075_runtime/v075_runtime_owner.gd"
const V075_COMPOSITION_PATH := "res://scenes/runtime/V075RuntimeComposition.tscn"
const V075_COMBAT_OWNER_PATH := "res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
const V075_SCREEN_PATH := "res://scenes/ui/v075/V075SampleGameScreen.tscn"
const V075_SCREEN_SCRIPT_PATH := "res://scripts/ui/v075/v075_sample_game_screen.gd"
const V073_TELEMETRY_SCENE_PATH := "res://scenes/playtest/V073PlaytestTelemetryService.tscn"
const V073_TELEMETRY_SCRIPT_PATH := "res://scripts/playtest/v073_playtest_telemetry_service.gd"
const V074_COMPOSITION_PATH := "res://scenes/runtime/V074RuntimeComposition.tscn"
const LEGACY_MAIN_PATH := "res://scripts/main.gd"
const LEGACY_MAIN_UID_PATH := "res://scripts/main.gd.uid"

var _checks := 0
var _failures: Array[String] = []
var _main_combat_owner_count := 0
var _composition_combat_owner_count := 0
var _composition_telemetry_count := 0
var _v074_composition_reachable_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_required_files()
	var main_source := _read_text(MAIN_SCENE_PATH)
	_test_main_static_contract(main_source)
	_test_v075_source_contracts()
	_test_scene_instantiation()
	_finish()


func _test_required_files() -> void:
	for path in [
		MAIN_SCENE_PATH,
		V075_BOOTSTRAP_PATH,
		V075_FLOW_PATH,
		V075_RULESET_PATH,
		V075_RUNTIME_PATH,
		V075_COMPOSITION_PATH,
		V075_COMBAT_OWNER_PATH,
		V075_SCREEN_PATH,
		V075_SCREEN_SCRIPT_PATH,
		V073_TELEMETRY_SCENE_PATH,
		V073_TELEMETRY_SCRIPT_PATH,
	]:
		_expect(
			FileAccess.file_exists(path),
			"required V075 production dependency exists: %s" % path
		)
	_expect(
		not FileAccess.file_exists(LEGACY_MAIN_PATH),
		"scripts/main.gd is physically absent"
	)
	_expect(
		not FileAccess.file_exists(LEGACY_MAIN_UID_PATH),
		"scripts/main.gd.uid is physically absent"
	)
	_expect(
		FileAccess.file_exists(V074_COMPOSITION_PATH),
		"historical V074 composition remains available for negative reachability test"
	)


func _test_main_static_contract(main_source: String) -> void:
	_expect(
		not main_source.is_empty(),
		"main.tscn can be read by the production gate"
	)
	for path in [V075_BOOTSTRAP_PATH, V075_COMPOSITION_PATH, V075_SCREEN_PATH]:
		_expect(
			_count_occurrences(main_source, path) == 1,
			"main.tscn references exactly one V075 entry dependency: %s" % path
		)
	for path in [
		"res://scripts/v074_runtime/v074_application_bootstrap.gd",
		V074_COMPOSITION_PATH,
		"res://scenes/ui/v074/V074SampleGameScreen.tscn",
	]:
		_expect(
			not main_source.contains(path),
			"main.tscn has no retired V074 production entry reference: %s" % path
		)
	_expect(
		_count_occurrences(
			main_source,
			"[node name=\"V075RuntimeComposition\""
		) == 1,
		"main.tscn has one V075 composition instance"
	)
	_expect(
		_count_occurrences(main_source, "[node name=\"V075GameScreen\"") == 1,
		"main.tscn has one V075 screen instance"
	)
	_expect(
		_count_occurrences(
			main_source,
			"[node name=\"V074RuntimeComposition\""
		) == 0,
		"main.tscn does not instantiate V074RuntimeComposition"
	)
	_expect(
		_count_occurrences(main_source, "[node name=\"V074GameScreen\"") == 0,
		"main.tscn does not instantiate V074GameScreen"
	)


func _test_v075_source_contracts() -> void:
	var composition_source := _read_text(V075_COMPOSITION_PATH)
	if composition_source.is_empty():
		return
	_expect(
		_count_occurrences(composition_source, V075_FLOW_PATH) == 1,
		"V075 composition has one application flow script"
	)
	_expect(
		_count_occurrences(composition_source, V075_RULESET_PATH) == 1,
		"V075 composition has one ruleset owner script"
	)
	_expect(
		_count_occurrences(composition_source, V075_RUNTIME_PATH) == 1,
		"V075 composition has one V075 runtime owner script"
	)
	_expect(
		_count_occurrences(composition_source, V075_COMBAT_OWNER_PATH) == 1,
		"V075 composition has one combat owner script dependency"
	)
	_expect(
		_count_occurrences(composition_source, V073_TELEMETRY_SCENE_PATH) == 1,
		"V075 composition has one V073 playtest telemetry service"
	)
	_expect(
		_count_occurrences(composition_source, "V075RuntimeComposition") == 1,
		"V075 composition has one named root"
	)
	_expect(
		not composition_source.contains(V074_COMPOSITION_PATH),
		"V075 composition does not reach V074 runtime composition"
	)
	for retired_path in [
		"res://scenes/runtime/MonsterRuntimeController.tscn",
		"res://scenes/runtime/MilitaryRuntimeController.tscn",
		"res://scenes/runtime/MonsterWagerResponseSink.tscn",
	]:
		_expect(
			not composition_source.contains(retired_path),
			"V075 composition has no retired combat fallback: %s" % retired_path
		)
	for source_path in [V075_BOOTSTRAP_PATH, V075_FLOW_PATH, V075_RUNTIME_PATH]:
		var source := _read_text(source_path)
		_expect(
			not source.contains(V074_COMPOSITION_PATH),
			"V075 production script has no V074 composition fallback: %s" % source_path
		)


func _test_scene_instantiation() -> void:
	var main_instance := _instantiate_scene(MAIN_SCENE_PATH, "main scene")
	if main_instance != null:
		var main_bootstrap_count := _count_nodes_with_script(
			main_instance,
			V075_BOOTSTRAP_PATH
		)
		var main_screen_count := _count_nodes_with_script(
			main_instance,
			V075_SCREEN_SCRIPT_PATH
		)
		var main_composition_count := _count_nodes_with_script(
			main_instance,
			V075_FLOW_PATH
		)
		_main_combat_owner_count = _count_nodes_with_script(
			main_instance,
			V075_COMBAT_OWNER_PATH
		)
		_v074_composition_reachable_count = _count_nodes_with_scene_path(
			main_instance,
			V074_COMPOSITION_PATH
		)
		_expect(
			main_bootstrap_count == 1,
			"instantiated main has exactly one V075 bootstrap"
		)
		_expect(
			main_screen_count == 1,
			"instantiated main has exactly one V075 screen"
		)
		_expect(
			main_composition_count == 1,
			"instantiated main has exactly one V075 application flow"
		)
		_expect(
			_main_combat_owner_count == 1,
			"instantiated main reaches exactly one combat owner"
		)
		_expect(
			_v074_composition_reachable_count == 0,
			"instantiated main cannot reach V074 runtime composition"
		)
		main_instance.free()

	var composition_instance := _instantiate_scene(
		V075_COMPOSITION_PATH,
		"V075 runtime composition"
	)
	if composition_instance != null:
		_test_composition_instance(composition_instance)
		composition_instance.free()

	var screen_instance := _instantiate_scene(V075_SCREEN_PATH, "V075 screen")
	if screen_instance != null:
		_expect(
			_count_nodes_with_script(screen_instance, V075_SCREEN_SCRIPT_PATH) == 1,
			"instantiated V075 screen has one wrapper script"
		)
		screen_instance.free()


func _test_composition_instance(composition: Node) -> void:
	var flow_nodes := _nodes_with_script(composition, V075_FLOW_PATH)
	var ruleset_nodes := _nodes_with_script(composition, V075_RULESET_PATH)
	var runtime_nodes := _nodes_with_script(composition, V075_RUNTIME_PATH)
	var combat_nodes := _nodes_with_script(composition, V075_COMBAT_OWNER_PATH)
	var telemetry_nodes := _nodes_with_script(
		composition,
		V073_TELEMETRY_SCRIPT_PATH
	)
	_composition_combat_owner_count = combat_nodes.size()
	_composition_telemetry_count = telemetry_nodes.size()
	_expect(
		_script_path(composition) == V075_FLOW_PATH,
		"V075 composition root owns the V075 application flow"
	)
	_expect(flow_nodes.size() == 1, "V075 composition has one application flow")
	_expect(ruleset_nodes.size() == 1, "V075 composition has one ruleset owner")
	_expect(runtime_nodes.size() == 1, "V075 composition has one V075 runtime owner")
	_expect(
		_composition_combat_owner_count == 1,
		"V075 composition has exactly one combat owner"
	)
	_expect(
		_composition_telemetry_count == 1,
		"V075 composition has exactly one V073 telemetry service"
	)
	_expect(
		_count_nodes_with_scene_path(composition, V074_COMPOSITION_PATH) == 0,
		"V075 composition instance cannot reach V074 composition"
	)

	if ruleset_nodes.size() == 1:
		var identity_variant: Variant = ruleset_nodes[0].call("identity_snapshot")
		_expect(identity_variant is Dictionary, "V075 ruleset owner returns identity")
		if identity_variant is Dictionary:
			var identity := identity_variant as Dictionary
			_expect(str(identity.get("ruleset_id", "")) == "v0.7.5", "entry identity is V0.7.5")
			_expect(str(identity.get("constitution_id", "")) == "space_syndicate.v075.complete", "entry constitution is V075")
			_expect(str(identity.get("sample_mode_id", "")) == "NEW_V075_GAME", "entry mode is NEW_V075_GAME")
			_expect(str(identity.get("sample_build_id", "")) == "alpha_0_5_c2.v075.monster_military.v1", "entry build identity is V075 combat")
			_expect(bool(identity.get("new_game_only", false)), "V075 entry is new-game-only")
			_expect(not bool(identity.get("save_enabled", true)), "V075 production Save is disabled")
			_expect(int(identity.get("current_supported_region_count_min", 0)) == 6, "V075 inherits six-region minimum")
			_expect(int(identity.get("current_supported_region_count_max", 0)) == 30, "V075 inherits thirty-region maximum")

	if combat_nodes.size() == 1:
		var debug_variant: Variant = combat_nodes[0].call("debug_snapshot")
		_expect(debug_variant is Dictionary, "combat owner exposes a debug contract")
		if debug_variant is Dictionary:
			var debug := debug_variant as Dictionary
			_expect(int(debug.get("combat_runtime_owner_count", 0)) == 1, "combat owner count is one")
			_expect(int(debug.get("combat_state_writer_count", 0)) == 1, "combat state writer count is one")
			_expect(int(debug.get("combat_dual_authority_count", -1)) == 0, "combat has no dual authority")
			_expect(int(debug.get("combat_legacy_fallback_count", -1)) == 0, "combat has no legacy fallback")
			_expect(int(debug.get("combat_direct_map_write_count", -1)) == 0, "combat does not write map directly")
			_expect(int(debug.get("combat_direct_facility_write_count", -1)) == 0, "combat does not write facilities directly")

	if telemetry_nodes.size() == 1:
		var telemetry_debug_variant: Variant = telemetry_nodes[0].call("debug_snapshot")
		_expect(telemetry_debug_variant is Dictionary, "V073 telemetry exposes a debug contract")
		if telemetry_debug_variant is Dictionary:
			var telemetry_debug := telemetry_debug_variant as Dictionary
			_expect(int(telemetry_debug.get("gameplay_owner_count", -1)) == 0, "telemetry owns no gameplay")
			_expect(int(telemetry_debug.get("save_owner_count", -1)) == 0, "telemetry owns no Save")
			_expect(int(telemetry_debug.get("rng_owner_count", -1)) == 0, "telemetry owns no RNG")
			_expect(int(telemetry_debug.get("world_mutation_count", -1)) == 0, "telemetry mutates no world state")


func _instantiate_scene(path: String, label: String) -> Node:
	if not FileAccess.file_exists(path):
		return null
	var resource: Resource = ResourceLoader.load(path)
	_expect(resource != null, "%s resource loads" % label)
	if resource == null or not resource is PackedScene:
		_expect(false, "%s is a PackedScene" % label)
		return null
	var instance: Node = (resource as PackedScene).instantiate()
	_expect(instance != null, "%s instantiates" % label)
	return instance


func _nodes_with_script(root_node: Node, script_path: String) -> Array[Node]:
	var nodes: Array[Node] = []
	var all_nodes: Array[Node] = []
	_collect_nodes(root_node, all_nodes)
	for node in all_nodes:
		if _script_path(node) == script_path:
			nodes.append(node)
	return nodes


func _count_nodes_with_script(root_node: Node, script_path: String) -> int:
	return _nodes_with_script(root_node, script_path).size()


func _count_nodes_with_scene_path(root_node: Node, scene_path: String) -> int:
	var count := 0
	var all_nodes: Array[Node] = []
	_collect_nodes(root_node, all_nodes)
	for node in all_nodes:
		if node.scene_file_path == scene_path:
			count += 1
	return count


func _collect_nodes(node: Node, result: Array[Node]) -> void:
	result.append(node)
	for child_variant in node.get_children():
		var child := child_variant as Node
		if child != null:
			_collect_nodes(child, result)


func _script_path(node: Node) -> String:
	var script: Variant = node.get_script()
	if script is Script:
		return (script as Script).resource_path
	return ""


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _count_occurrences(source: String, needle: String) -> int:
	if needle.is_empty():
		return 0
	var count := 0
	var cursor := 0
	while cursor < source.length():
		var index := source.find(needle, cursor)
		if index < 0:
			break
		count += 1
		cursor = index + needle.length()
	return count


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	var passed := _checks - _failures.size()
	var status := "PASS" if _failures.is_empty() else "FAIL"
	var summary_format := (
		"V075_APPLICATION_COMPOSITION_TEST"
		+ "|status=%s|passed=%d|total=%d"
		+ "|main_combat_owner_count=%d|composition_combat_owner_count=%d"
		+ "|composition_telemetry_count=%d|v074_composition_reachable_count=%d"
		+ "|details=%s"
	)
	print(summary_format % [
		status,
		passed,
		_checks,
		_main_combat_owner_count,
		_composition_combat_owner_count,
		_composition_telemetry_count,
		_v074_composition_reachable_count,
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)