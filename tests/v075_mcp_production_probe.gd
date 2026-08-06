extends SceneTree

const PROBE_SCHEMA := "V075McpProductionProbeV1"
const DEFAULT_MAIN_SCENE := "res://scenes/main.tscn"
const MCP_CONFIG_PATH := "res://.mcp.json"
const MCP_BRIDGE_SCRIPT_PATH := "res://tools/funplay_mcp_stdio.cmd"
const MCP_LAUNCH_SCRIPT_PATH := "res://tools/launch_role_godot_mcp.ps1"
const MCP_INVOKE_SCRIPT_PATH := "res://tools/invoke_role_godot_mcp.ps1"
const MCP_STOP_SCRIPT_PATH := "res://tools/stop_role_godot_mcp.ps1"
const APPLICATION_FLOW_PATH := "res://scripts/v075_runtime/v075_application_flow.gd"
const APPLICATION_BOOTSTRAP_PATH := "res://scripts/v075_runtime/v075_application_bootstrap.gd"
const RUNTIME_COMPOSITION_PATH := "res://scenes/runtime/V075RuntimeComposition.tscn"
const SAMPLE_SCREEN_PATH := "res://scenes/ui/v075/V075SampleGameScreen.tscn"
const SAMPLE_SCREEN_SCRIPT_PATH := "res://scripts/ui/v075/v075_sample_game_screen.gd"
const PNG_SIGNATURE := [
	137, 80, 78, 71, 13, 10, 26, 10
]

var _checks := 0
var _failures: Array[String] = []
var _warnings: Array[String] = []
var _loaded_script_count := 0
var _loaded_scene_count := 0
var _loaded_resource_count := 0
var _parsed_json_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var target_sha := _environment("V075_MCP_EXPECTED_SHA")
	var parent_sha := _environment("V075_MCP_DIFF_PARENT_SHA")
	var main_scene := _normalise_path(
		_environment("V075_MCP_MAIN_SCENE", DEFAULT_MAIN_SCENE)
	)
	var script_manifest := _manifest("V075_MCP_CHANGED_SCRIPTS")
	var scene_manifest := _manifest("V075_MCP_CHANGED_SCENES")
	var resource_manifest := _manifest("V075_MCP_CHANGED_RESOURCES")
	var screenshot_manifest := _manifest("V075_MCP_SCREENSHOTS")

	_check(
		_is_sha(target_sha),
		"expected_sha_is_a_40_character_hex_commit"
	)
	_check(
		_is_sha(parent_sha),
		"diff_parent_sha_is_a_40_character_hex_commit"
	)
	_check(
		target_sha != parent_sha,
		"target_sha_differs_from_diff_parent_sha"
	)

	var configured_main := str(
		ProjectSettings.get_setting("application/run/main_scene", "")
	)
	_check(
		configured_main == main_scene,
		"project_main_scene_matches_manifest:%s:%s"
			% [configured_main, main_scene]
	)
	_check_file(MCP_CONFIG_PATH, "mcp_config")
	_check_file(MCP_BRIDGE_SCRIPT_PATH, "mcp_stdio_bridge")
	_check_file(MCP_LAUNCH_SCRIPT_PATH, "mcp_launch_script")
	_check_file(MCP_INVOKE_SCRIPT_PATH, "mcp_invoke_script")
	_check_file(MCP_STOP_SCRIPT_PATH, "mcp_stop_script")
	_check_file("res://project.godot", "project_file")
	_check_file(main_scene, "configured_main_scene")
	_check_resource(main_scene, "configured_main_scene_load")

	var mcp_config := _read_text(MCP_CONFIG_PATH)
	var bridge_script := _read_text(MCP_BRIDGE_SCRIPT_PATH)
	_check(
		"funplay_mcp_stdio.cmd" in mcp_config,
		"mcp_config_points_to_role_stdio_bridge"
	)
	_check(
		"funplay-godot-mcp@0.9.6" in bridge_script,
		"stdio_bridge_pins_funplay_mcp_0_9_6"
	)

	var main_text := _read_text(main_scene)
	var v075_wiring := {
		"bootstrap": "v075_application_bootstrap.gd" in main_text,
		"composition": "V075RuntimeComposition.tscn" in main_text,
		"screen": "V075SampleGameScreen.tscn" in main_text,
	}
	var v075_wired := true
	for wiring_variant in v075_wiring.values():
		v075_wired = v075_wired and bool(wiring_variant)
	_check(
		v075_wired,
		"v075_main_scene_production_wiring_is_connected"
	)
	for wiring_key in v075_wiring.keys():
		_check(
			bool(v075_wiring.get(wiring_key, false)),
			"v075_main_scene_wiring:%s" % str(wiring_key)
		)
	var flow_checks := {
		"application_flow": _resource_loadable(
			APPLICATION_FLOW_PATH,
			"script"
		),
		"application_bootstrap": _resource_loadable(
			APPLICATION_BOOTSTRAP_PATH,
			"script"
		),
		"runtime_composition": _resource_loadable(
			RUNTIME_COMPOSITION_PATH,
			"scene"
		),
		"sample_screen": _resource_loadable(
			SAMPLE_SCREEN_PATH,
			"scene"
		),
		"sample_screen_script": _resource_loadable(
			SAMPLE_SCREEN_SCRIPT_PATH,
			"script"
		),
	}
	for key_variant in flow_checks.keys():
		_check(
			bool(flow_checks.get(key_variant, false)),
			"v075_read_only_dependency_loads:%s" % str(key_variant)
		)

	var script_result := _validate_manifest(
		script_manifest,
		"script"
	)
	var scene_result := _validate_manifest(
		scene_manifest,
		"scene"
	)
	var resource_result := _validate_manifest(
		resource_manifest,
		"resource"
	)
	var screenshot_result := _validate_screenshots(
		screenshot_manifest
	)

	if script_manifest.is_empty():
		_warnings.append("changed_script_manifest_not_supplied")
	if scene_manifest.is_empty():
		_warnings.append("changed_scene_manifest_not_supplied")
	if resource_manifest.is_empty():
		_warnings.append("changed_resource_manifest_not_supplied")
	if screenshot_manifest.is_empty():
		_warnings.append("screenshot_manifest_not_supplied")

	var report := {
		"schema": PROBE_SCHEMA,
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"expected_sha": target_sha,
		"diff_parent_sha": parent_sha,
		"sha_attestation": {
			"source": "runbook_git_rev_parse",
			"same_sha_manifest": (
				_is_sha(target_sha)
				and _is_sha(parent_sha)
				and target_sha != parent_sha
			),
		},
		"project": {
			"configured_main_scene": configured_main,
			"manifest_main_scene": main_scene,
			"main_scene_loadable": _resource_loadable(
				main_scene,
				"scene"
			),
			"v075_main_scene_wired": v075_wired,
			"v075_main_scene_wiring": v075_wiring.duplicate(),
			"v075_production_wiring_gap": not v075_wired,
		},
		"mcp_config": {
			"config_path": MCP_CONFIG_PATH,
			"stdio_bridge_path": MCP_BRIDGE_SCRIPT_PATH,
			"funplay_version_pinned": (
				"funplay-godot-mcp@0.9.6" in bridge_script
			),
		},
		"read_only_dependencies": flow_checks,
		"changed_manifests": {
			"scripts": script_result,
			"scenes": scene_result,
			"resources": resource_result,
		},
		"screenshots": screenshot_result,
		"mutation_contract": {
			"writes_performed": 0,
			"gameplay_instances_created": 0,
			"world_mutation_count": 0,
			"rng_draw_delta": 0,
			"save_write_count": 0,
		},
		"loader_counts": {
			"scripts": _loaded_script_count,
			"scenes": _loaded_scene_count,
			"resources": _loaded_resource_count,
			"json_documents": _parsed_json_count,
		},
		"checks": _checks,
		"failures": _failures,
		"warnings": _warnings,
	}
	print("V075_MCP_PRODUCTION_PROBE|" + JSON.stringify(report))
	quit(0 if _failures.is_empty() else 1)


func _environment(name: String, fallback := "") -> String:
	var value := OS.get_environment(name).strip_edges()
	return fallback if value.is_empty() else value


func _manifest(name: String) -> Array[String]:
	var raw := OS.get_environment(name)
	var result: Array[String] = []
	if raw.is_empty():
		return result
	var normalised := raw.replace("\r", "").replace("\n", ";")
	for piece in normalised.split(";", false):
		var value := str(piece).strip_edges()
		if not value.is_empty():
			result.append(value)
	return result


func _normalise_path(raw: String) -> String:
	var value := raw.strip_edges().replace("\\", "/")
	if value.begins_with("res://"):
		return value
	return "res://" + value.trim_prefix("/")


func _is_sha(value: String) -> bool:
	if value.length() != 40:
		return false
	for character in value.to_lower():
		if "0123456789abcdef".find(character) < 0:
			return false
	return true


func _check_file(path: String, label: String) -> void:
	_check(
		FileAccess.file_exists(path),
		"%s_exists:%s" % [label, path]
	)


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _resource_loadable(path: String, kind: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var loaded: Resource = ResourceLoader.load(path)
	if loaded == null:
		return false
	if kind == "script" and not (loaded is Script):
		return false
	if kind == "scene" and not (loaded is PackedScene):
		return false
	return true


func _check_resource(path: String, label: String) -> void:
	var kind := "scene" if path.get_extension().to_lower() == "tscn" else "resource"
	var loaded := _resource_loadable(path, kind)
	_check(loaded, "%s_loads:%s" % [label, path])
	if loaded:
		if kind == "scene":
			_loaded_scene_count += 1
		else:
			_loaded_resource_count += 1


func _validate_manifest(
	entries: Array[String],
	kind: String
) -> Dictionary:
	var result := {
		"provided": not entries.is_empty(),
		"count": entries.size(),
		"passed": 0,
		"failed": 0,
		"paths": [],
	}
	for raw_variant in entries:
		var path := _normalise_path(str(raw_variant))
		var loaded := false
		if kind == "script":
			loaded = _resource_loadable(path, "script")
			if loaded:
				_loaded_script_count += 1
		elif kind == "scene":
			loaded = _resource_loadable(path, "scene")
			if loaded:
				_loaded_scene_count += 1
		else:
			loaded = _resource_or_json_loadable(path)
			if loaded:
				_loaded_resource_count += 1
		(result["paths"] as Array).append({
			"path": path,
			"loadable": loaded,
		})
		if loaded:
			result["passed"] = int(result["passed"]) + 1
		else:
			result["failed"] = int(result["failed"]) + 1
			_failures.append(
				"changed_%s_not_loadable:%s" % [kind, path]
			)
	return result


func _resource_or_json_loadable(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var extension := path.get_extension().to_lower()
	if extension == "json":
		var parser := JSON.new()
		var error := parser.parse(_read_text(path))
		if error != OK:
			return false
		_parsed_json_count += 1
		return true
	if not ResourceLoader.exists(path):
		return false
	return ResourceLoader.load(path) != null


func _validate_screenshots(entries: Array[String]) -> Dictionary:
	var result := {
		"provided": not entries.is_empty(),
		"count": entries.size(),
		"passed": 0,
		"failed": 0,
		"items": [],
	}
	for raw_variant in entries:
		var parts := str(raw_variant).split("|", false)
		if parts.size() < 4:
			result["failed"] = int(result["failed"]) + 1
			_failures.append(
				"screenshot_manifest_entry_requires_label_path_width_height:%s"
					% str(raw_variant)
			)
			continue
		var label := str(parts[0]).strip_edges()
		var path := _normalise_path(str(parts[1]))
		var expected_width := int(parts[2])
		var expected_height := int(parts[3])
		var item := {
			"label": label,
			"path": path,
			"expected_width": expected_width,
			"expected_height": expected_height,
			"exists": false,
			"png": false,
			"width": 0,
			"height": 0,
		}
		if not FileAccess.file_exists(path):
			result["failed"] = int(result["failed"]) + 1
			_failures.append("screenshot_missing:%s" % path)
			(result["items"] as Array).append(item)
			continue
		item["exists"] = true
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			result["failed"] = int(result["failed"]) + 1
			_failures.append("screenshot_open_failed:%s" % path)
			(result["items"] as Array).append(item)
			continue
		var bytes := file.get_buffer(file.get_length())
		var valid_png := _has_png_signature(bytes)
		item["png"] = valid_png
		if valid_png and bytes.size() >= 24:
			item["width"] = _read_u32_be(bytes, 16)
			item["height"] = _read_u32_be(bytes, 20)
		var dimensions_match := (
			valid_png
			and int(item["width"]) == expected_width
			and int(item["height"]) == expected_height
		)
		if not dimensions_match:
			result["failed"] = int(result["failed"]) + 1
			_failures.append(
				"screenshot_dimensions_mismatch:%s:%dx%d"
					% [path, int(item["width"]), int(item["height"])]
			)
		else:
			result["passed"] = int(result["passed"]) + 1
		(result["items"] as Array).append(item)
	return result


func _has_png_signature(bytes: PackedByteArray) -> bool:
	if bytes.size() < PNG_SIGNATURE.size():
		return false
	for index in range(PNG_SIGNATURE.size()):
		if bytes[index] != PNG_SIGNATURE[index]:
			return false
	return true


func _read_u32_be(bytes: PackedByteArray, offset: int) -> int:
	return (
		(int(bytes[offset]) << 24)
		| (int(bytes[offset + 1]) << 16)
		| (int(bytes[offset + 2]) << 8)
		| int(bytes[offset + 3])
	)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
