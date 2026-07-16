extends SceneTree

const SCENE := preload("res://scenes/tools/RolePortraitRenderRig.tscn")
const MANIFEST_PATH := "res://assets/art/role_portraits/temporary/manifest.json"
const INDEX_PATH := "res://tools/art_pipeline/source_asset_index.json"

var checks := 0
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rig := SCENE.instantiate()
	root.add_child(rig)
	await process_frame
	_check(rig.has_method("rig_snapshot"), "scene root exposes RolePortraitRenderRig API")
	if rig.has_method("rig_snapshot"):
		var snapshot: Dictionary = rig.rig_snapshot()
		_check(snapshot.get("viewport_size", []) == [1024, 1536], "source viewport is 1024x1536")
		_check(snapshot.get("runtime_png_size", []) == [512, 768], "runtime PNG is 512x768")
		_check(bool(snapshot.get("transparent_background", false)), "SubViewport is transparent")
		var nodes: Dictionary = snapshot.get("required_nodes", {})
		for node_name in [
			"ModelRoot",
			"ProceduralAttachmentRoot",
			"OrbitalCollar",
			"CameraFront",
			"CameraSide",
			"KeyLight",
			"FillLight",
			"RimLight",
			"WorldEnvironment",
			"TransparentSubViewport",
		]:
			_check(bool(nodes.get(node_name, false)), "required rig node: %s" % node_name)

	var manifest := _json(MANIFEST_PATH)
	var roles: Array = manifest.get("roles", [])
	_check(roles.size() == 24, "manifest has 24 role-name bindings")
	var names := {}
	var rendered_count := 0
	for raw_entry in roles:
		_check(raw_entry is Dictionary, "role entry is a dictionary")
		if not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		var role_name := str(entry.get("role_name", ""))
		_check(not role_name.is_empty(), "role uses stable Chinese name key")
		_check(not names.has(role_name), "role key is unique: %s" % role_name)
		names[role_name] = true
		if str(entry.get("status", "")) == "rendered":
			rendered_count += 1
			var source_path := str(entry.get("source_path", ""))
			var front_path := str(entry.get("front_path", ""))
			var side_path := str(entry.get("side_inward_path", ""))
			_check(source_path.begins_with("art_sources/unpacked/"), "rendered source stays in approved cache: %s" % role_name)
			_check(not str(entry.get("asset_id", "")).is_empty(), "rendered role has indexed asset id: %s" % role_name)
			_check(FileAccess.file_exists("res://%s" % front_path), "rendered front PNG exists: %s" % role_name)
			_check(FileAccess.file_exists("res://%s" % side_path), "rendered side PNG exists: %s" % role_name)
		else:
			_check(entry.get("source_path") == null, "pending source path is not invented: %s" % role_name)
			_check(entry.get("front_path") == null, "pending front PNG is not invented: %s" % role_name)
			_check(entry.get("side_inward_path") == null, "pending side PNG is not invented: %s" % role_name)
	_check(rendered_count == 8, "four original portraits plus four actual-model trial roles are rendered")
	for required_role in ["环港走私议会", "重力矿联董事会", "光合修复会", "幽幕播报社"]:
		var required_entry: Dictionary = {}
		for entry_variant in roles:
			if entry_variant is Dictionary and str((entry_variant as Dictionary).get("role_name", "")) == required_role:
				required_entry = entry_variant as Dictionary
				break
		_check(str(required_entry.get("status", "")) == "rendered", "actual trial role is rendered: %s" % required_role)
		_check(str(required_entry.get("candidate_pack_id", "")) == "free_assets_fixed_commit", "actual trial role uses fixed CC0 source: %s" % required_role)

	var index := _json(INDEX_PATH)
	_check(index.get("records", []) is Array, "source index records are machine-readable")
	_check(
		str(manifest.get("runtime_policy", "")) == "pre_rendered_png_only",
		"manifest forbids runtime third-party model loading"
	)
	rig.queue_free()
	await process_frame
	if failures.is_empty():
		print("ART_PIPELINE_SCENE_TEST PASS checks=%d failures=0" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("ART_PIPELINE_SCENE_TEST FAIL checks=%d failures=%d" % [checks, failures.size()])
		quit(1)


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
