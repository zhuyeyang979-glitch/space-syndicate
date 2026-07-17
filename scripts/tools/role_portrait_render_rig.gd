@tool
class_name RolePortraitRenderRig
extends Control

signal source_model_loaded(asset_id: String)
signal portrait_rendered(role_name: String, front_path: String, side_path: String)
signal pipeline_error(message: String)

const SOURCE_INDEX_PATH := "res://tools/art_pipeline/source_asset_index.json"
const ROLE_MANIFEST_PATH := "res://assets/art/role_portraits/temporary/manifest.json"
const PORTRAIT_ROOT := "res://assets/art/role_portraits/temporary/"
const CANDIDATE_PREVIEW_ROOT := "res://docs/art_qa/source_candidates/previews/"
const APPROVED_SOURCE_ROOT := "res://art_sources/unpacked/"
const SOURCE_VIEWPORT_SIZE := Vector2i(1024, 1536)
const RUNTIME_PORTRAIT_SIZE := Vector2i(512, 768)
const MODEL_EXTENSIONS := ["blend", "fbx", "gltf", "glb", "obj"]

@export var auto_render_indexed_candidates := false
@export var auto_render_bound_roles := false

@onready var portrait_viewport: SubViewport = %PortraitViewport
@onready var portrait_preview: TextureRect = %PortraitPreview
@onready var model_root: Node3D = %ModelRoot
@onready var procedural_attachment_root: Node3D = %ProceduralAttachmentRoot
@onready var orbital_collar: MeshInstance3D = %OrbitalCollar
@onready var camera_front: Camera3D = %CameraFront
@onready var camera_side: Camera3D = %CameraSide
@onready var status_label: Label = %StatusLabel
@onready var fallback_bust: Node3D = %FallbackBust
@onready var render_candidates_button: Button = %RenderCandidatesButton
@onready var fallback_button: Button = %FallbackButton

var _loaded_asset_id := ""
var _loaded_model: Node3D


func _ready() -> void:
	portrait_viewport.size = SOURCE_VIEWPORT_SIZE
	portrait_viewport.transparent_bg = true
	portrait_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	portrait_preview.texture = portrait_viewport.get_texture()
	orbital_collar.visible = false
	camera_front.current = true
	camera_side.current = false
	if not render_candidates_button.pressed.is_connected(_on_render_candidates_pressed):
		render_candidates_button.pressed.connect(_on_render_candidates_pressed)
	if not fallback_button.pressed.is_connected(show_fallback_preview):
		fallback_button.pressed.connect(show_fallback_preview)
	_set_status("渲染台就绪｜等待已授权 Quaternius 模型")
	print(
		"ROLE_PORTRAIT_RENDER_RIG_READY scene=res://scenes/tools/RolePortraitRenderRig.tscn ",
		"viewport=1024x1536 runtime_png=512x768"
	)
	if auto_render_indexed_candidates and not Engine.is_editor_hint():
		call_deferred("_run_automatic_candidate_capture")
	elif auto_render_bound_roles and not Engine.is_editor_hint():
		call_deferred("_run_automatic_bound_role_capture")


func load_indexed_asset(asset_id: String) -> Dictionary:
	var index := _load_json(SOURCE_INDEX_PATH)
	if index.is_empty():
		return _fail("source index unavailable")
	for raw_record in index.get("records", []):
		if not raw_record is Dictionary:
			continue
		var record := raw_record as Dictionary
		if str(record.get("asset_id", "")) != asset_id:
			continue
		var relative_source := str(record.get("source_path", ""))
		var resource_path := "res://%s" % relative_source
		if not resource_path.begins_with(APPROVED_SOURCE_ROOT):
			return _fail("source path is outside approved art_sources root")
		if not _is_supported_model_path(resource_path):
			return _fail("source model format is not approved")
		if not ResourceLoader.exists(resource_path):
			return _fail("indexed model has not been imported by Godot")
		var expected_hash := str(record.get("source_sha256", ""))
		var actual_hash := FileAccess.get_sha256(resource_path)
		if expected_hash.is_empty() or actual_hash != expected_hash:
			return _fail("source model SHA-256 does not match the index")
		var resource := load(resource_path)
		if not resource is PackedScene:
			return _fail("source model did not import as a PackedScene")
		_clear_loaded_model()
		var instance := (resource as PackedScene).instantiate()
		if not instance is Node3D:
			instance.queue_free()
			return _fail("source model root is not Node3D")
		_loaded_model = instance as Node3D
		_loaded_model.name = "LoadedSourceModel"
		_loaded_model.set_meta("asset_id", asset_id)
		model_root.add_child(_loaded_model)
		fallback_bust.visible = false
		_loaded_asset_id = asset_id
		_apply_common_materials(_loaded_model)
		_apply_indexed_preview_transform(record)
		_set_status("已载入：%s" % str(record.get("model_name", asset_id)))
		source_model_loaded.emit(asset_id)
		return {"ok": true, "record": record.duplicate(true)}
	return _fail("asset_id is absent from the real source index")


func prepare_role(entry: Dictionary) -> Dictionary:
	var role_name := str(entry.get("role_name", "")).strip_edges()
	var asset_id := str(entry.get("asset_id", "")).strip_edges()
	if role_name.is_empty() or asset_id.is_empty():
		return _fail("role_name and asset_id are required")
	var loaded := load_indexed_asset(asset_id)
	if not bool(loaded.get("ok", false)):
		return loaded
	_clear_attachments()
	_set_hidden_node_patterns(_loaded_model, entry.get("hidden_nodes", []))
	_apply_role_materials(_loaded_model, role_name)
	_frame_loaded_model(_is_actual_trial_role(role_name))
	for raw_attachment in entry.get("attachments", []):
		_add_simple_attachment(str(raw_attachment))
	_set_status("已准备角色：%s" % role_name)
	return {"ok": true, "role_name": role_name, "asset_id": asset_id}


func render_role(entry: Dictionary) -> Dictionary:
	var prepared := prepare_role(entry)
	if not bool(prepared.get("ok", false)):
		return prepared
	var role_name := str(entry["role_name"])
	var slug := str(entry.get("slug", "")).strip_edges()
	if slug.is_empty() or slug.contains("/") or slug.contains("\\") or slug.contains(".."):
		return _fail("safe role slug is required")
	var output_dir := PORTRAIT_ROOT + slug + "/"
	var front_path := output_dir + "front.png"
	var side_path := output_dir + "side_inward.png"
	var actual_trial := _is_actual_trial_role(role_name)
	orbital_collar.visible = not actual_trial
	_apply_camera_profile(actual_trial)

	model_root.rotation_degrees.y = 0.0
	var front_result := await _render_camera_to_png(camera_front, front_path)
	if not bool(front_result.get("ok", false)):
		return front_result
	model_root.rotation_degrees.y = -14.0 if actual_trial else -12.0
	var side_result := await _render_camera_to_png(camera_side, side_path)
	model_root.rotation_degrees.y = 0.0
	if not bool(side_result.get("ok", false)):
		return side_result
	_set_status("完成：%s｜front + side_inward" % role_name)
	portrait_rendered.emit(role_name, front_path, side_path)
	return {
		"ok": true,
		"role_name": role_name,
		"asset_id": _loaded_asset_id,
		"front_path": front_path.trim_prefix("res://"),
		"side_inward_path": side_path.trim_prefix("res://"),
		"source_size": [SOURCE_VIEWPORT_SIZE.x, SOURCE_VIEWPORT_SIZE.y],
		"runtime_size": [RUNTIME_PORTRAIT_SIZE.x, RUNTIME_PORTRAIT_SIZE.y],
	}


func render_candidate_preview(asset_id: String) -> Dictionary:
	var loaded := load_indexed_asset(asset_id)
	if not bool(loaded.get("ok", false)):
		return loaded
	_clear_attachments()
	orbital_collar.visible = true
	_apply_camera_profile(false)
	_frame_loaded_model(false)
	model_root.rotation_degrees.y = 0.0
	var output_path := CANDIDATE_PREVIEW_ROOT + asset_id + ".png"
	var result := await _render_camera_to_png(camera_front, output_path)
	if bool(result.get("ok", false)):
		_set_status("候选预览：%s" % asset_id)
	return result


func render_all_indexed_candidates() -> Dictionary:
	var index := _load_json(SOURCE_INDEX_PATH)
	var records: Array = index.get("records", [])
	if records.is_empty():
		return _fail("source index contains no real models")
	var rendered := 0
	var failures: Array[Dictionary] = []
	render_candidates_button.disabled = true
	for raw_record in records:
		if not raw_record is Dictionary:
			continue
		var asset_id := str((raw_record as Dictionary).get("asset_id", ""))
		var result := await render_candidate_preview(asset_id)
		if bool(result.get("ok", false)):
			rendered += 1
		else:
			failures.append({"asset_id": asset_id, "reason": result.get("reason", "")})
	render_candidates_button.disabled = false
	_set_status("候选渲染完成：%d / %d" % [rendered, records.size()])
	return {
		"ok": failures.is_empty(),
		"rendered": rendered,
		"total": records.size(),
		"failures": failures,
	}


func render_all_bound_roles() -> Dictionary:
	var manifest := _load_json(ROLE_MANIFEST_PATH)
	var roles_variant: Variant = manifest.get("roles", [])
	if not roles_variant is Array:
		return _fail("role manifest contains no roles array")
	var rendered: Array[Dictionary] = []
	var failures: Array[Dictionary] = []
	for raw_entry in roles_variant as Array:
		if not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		var asset_id := str(entry.get("asset_id", "")).strip_edges()
		var source_path := str(entry.get("source_path", "")).strip_edges()
		if asset_id.is_empty() or source_path.is_empty():
			continue
		var result := await render_role(entry)
		if bool(result.get("ok", false)):
			rendered.append(result)
		else:
			failures.append({
				"role_name": str(entry.get("role_name", "")),
				"reason": str(result.get("reason", "")),
			})
	_set_status("角色渲染完成：%d｜失败：%d" % [rendered.size(), failures.size()])
	return {
		"ok": failures.is_empty() and not rendered.is_empty(),
		"rendered": rendered,
		"rendered_count": rendered.size(),
		"failure_count": failures.size(),
		"failures": failures,
	}


func show_fallback_preview() -> void:
	_clear_loaded_model()
	_clear_attachments()
	fallback_bust.visible = true
	model_root.rotation = Vector3.ZERO
	_set_status("程序化半身占位｜不可登记为第三方模型成品")


func rig_snapshot() -> Dictionary:
	return {
		"scene": "res://scenes/tools/RolePortraitRenderRig.tscn",
		"loaded_asset_id": _loaded_asset_id,
		"has_real_model": is_instance_valid(_loaded_model),
		"viewport_size": [portrait_viewport.size.x, portrait_viewport.size.y],
		"runtime_png_size": [RUNTIME_PORTRAIT_SIZE.x, RUNTIME_PORTRAIT_SIZE.y],
		"transparent_background": portrait_viewport.transparent_bg,
		"required_nodes": {
			"ModelRoot": is_instance_valid(model_root),
			"ProceduralAttachmentRoot": is_instance_valid(procedural_attachment_root),
			"OrbitalCollar": is_instance_valid(orbital_collar),
			"CameraFront": is_instance_valid(camera_front),
			"CameraSide": is_instance_valid(camera_side),
			"KeyLight": has_node("%KeyLight"),
			"FillLight": has_node("%FillLight"),
			"RimLight": has_node("%RimLight"),
			"WorldEnvironment": has_node("%WorldEnvironment"),
			"TransparentSubViewport": is_instance_valid(portrait_viewport),
		},
	}


func _render_camera_to_png(camera: Camera3D, output_path: String) -> Dictionary:
	if (
		not output_path.begins_with(PORTRAIT_ROOT)
		and not output_path.begins_with(CANDIDATE_PREVIEW_ROOT)
	):
		return _fail("output path is outside an approved art-pipeline root")
	camera_front.current = camera == camera_front
	camera_side.current = camera == camera_side
	portrait_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
		portrait_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	var image := portrait_viewport.get_texture().get_image()
	if image.is_empty():
		return _fail("SubViewport returned an empty image")
	image.convert(Image.FORMAT_RGBA8)
	image.resize(
		RUNTIME_PORTRAIT_SIZE.x,
		RUNTIME_PORTRAIT_SIZE.y,
		Image.INTERPOLATE_LANCZOS
	)
	var absolute_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	if error != OK:
		return _fail("PNG save failed: %s" % error_string(error))
	return {"ok": true, "path": output_path}


func _load_json(resource_path: String) -> Dictionary:
	if not FileAccess.file_exists(resource_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(resource_path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _clear_loaded_model() -> void:
	if is_instance_valid(_loaded_model):
		if _loaded_model.get_parent() != null:
			_loaded_model.get_parent().remove_child(_loaded_model)
		_loaded_model.free()
	_loaded_model = null
	_loaded_asset_id = ""


func _clear_attachments() -> void:
	for child in procedural_attachment_root.get_children():
		procedural_attachment_root.remove_child(child)
		child.free()


func _is_supported_model_path(path: String) -> bool:
	return MODEL_EXTENSIONS.has(path.get_extension().to_lower())


func _set_hidden_node_patterns(root: Node, patterns: Array) -> void:
	var normalized := PackedStringArray()
	for raw_pattern in patterns:
		var pattern := str(raw_pattern).to_lower().strip_edges()
		if not pattern.is_empty():
			normalized.append(pattern)
	for node in root.find_children("*", "Node3D", true, false):
		var node_name := str(node.name).to_lower()
		for pattern in normalized:
			if node_name.contains(pattern):
				(node as Node3D).visible = false
				break


func _apply_common_materials(root: Node) -> void:
	for raw_mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.16, 0.25, 0.34, 1.0)
		material.metallic = 0.18
		material.roughness = 0.68
		mesh_instance.material_override = material


func _apply_indexed_preview_transform(record: Dictionary) -> void:
	if not is_instance_valid(_loaded_model):
		return
	var transform_variant: Variant = record.get("preview_transform", {})
	if not transform_variant is Dictionary:
		return
	var transform_data := transform_variant as Dictionary
	_loaded_model.position = _vector3_from_array(transform_data.get("position", []), Vector3.ZERO)
	_loaded_model.rotation_degrees = _vector3_from_array(
		transform_data.get("rotation_degrees", []),
		Vector3.ZERO
	)
	var uniform_scale := maxf(float(transform_data.get("scale", 1.0)), 0.001)
	_loaded_model.scale = Vector3.ONE * uniform_scale


func _frame_loaded_model(bust_portrait: bool) -> void:
	if not is_instance_valid(_loaded_model):
		return
	var bounds := _combined_global_aabb(_loaded_model)
	if bounds.size.length_squared() <= 0.0001:
		return
	var target_width := 2.30 if bust_portrait else 1.92
	var target_height := 4.05 if bust_portrait else 2.62
	var scale_factor := minf(
		target_width / maxf(bounds.size.x, 0.001),
		target_height / maxf(bounds.size.y, 0.001)
	)
	_loaded_model.scale *= scale_factor
	bounds = _combined_global_aabb(_loaded_model)
	if not bust_portrait:
		var target_center := Vector3(0.0, 1.55, 0.0)
		_loaded_model.global_position += target_center - bounds.get_center()
		return
	var target_top := 3.05
	var bounds_top := bounds.position.y + bounds.size.y
	_loaded_model.global_position += Vector3(
		-bounds.get_center().x,
		target_top - bounds_top,
		-bounds.get_center().z
	)


func _vector3_from_array(value: Variant, fallback: Vector3) -> Vector3:
	if not value is Array:
		return fallback
	var values := value as Array
	if values.size() != 3:
		return fallback
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _combined_global_aabb(root: Node) -> AABB:
	var found := false
	var combined := AABB()
	for raw_mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if not mesh_instance.visible or mesh_instance.mesh == null:
			continue
		var local_aabb := mesh_instance.get_aabb()
		var global_aabb := mesh_instance.global_transform * local_aabb
		if not found:
			combined = global_aabb
			found = true
		else:
			combined = combined.merge(global_aabb)
	return combined


func _add_simple_attachment(kind: String) -> void:
	match kind:
		"smuggler_antennae":
			for side in [-1.0, 1.0]:
				var stem := CylinderMesh.new()
				stem.top_radius = 0.035
				stem.bottom_radius = 0.055
				stem.height = 0.38
				_add_attachment_mesh(
					"AntennaStem",
					stem,
					Vector3(0.22 * side, 2.92, 0.04),
					Vector3(0.0, 0.0, -13.0 * side),
					Vector3.ONE,
					Color("#172a3c")
				)
				var tip := SphereMesh.new()
				tip.radius = 0.065
				tip.height = 0.13
				_add_attachment_mesh(
					"AntennaTip",
					tip,
					Vector3(0.26 * side, 3.10, 0.05),
					Vector3.ZERO,
					Vector3.ONE,
					Color("#7be6f6"),
					Color("#2aa8c3")
				)
		"wing_sheaths":
			for side in [-1.0, 1.0]:
				var sheath := BoxMesh.new()
				sheath.size = Vector3(0.16, 0.52, 0.10)
				_add_attachment_mesh(
					"WingSheath",
					sheath,
					Vector3(0.52 * side, 2.04, -0.18),
					Vector3(4.0, -8.0 * side, -13.0 * side),
					Vector3.ONE,
					Color("#182b40")
				)
		"battery_core":
			var battery := SphereMesh.new()
			battery.radius = 0.12
			battery.height = 0.24
			_add_attachment_mesh(
				"BatteryCore",
				battery,
				Vector3(0.0, 1.56, 0.54),
				Vector3.ZERO,
				Vector3(0.82, 1.18, 0.52),
				Color("#9ceaf0"),
				Color("#2cb6cc")
			)
		"heavy_shoulders":
			for side in [-1.0, 1.0]:
				var shoulder := BoxMesh.new()
				shoulder.size = Vector3(0.34, 0.22, 0.30)
				_add_attachment_mesh(
					"HeavyShoulder",
					shoulder,
					Vector3(0.48 * side, 2.02, -0.02),
					Vector3(0.0, 0.0, -7.0 * side),
					Vector3.ONE,
					Color("#24262c")
				)
		"gravity_core":
			var gravity := TorusMesh.new()
			gravity.inner_radius = 0.085
			gravity.outer_radius = 0.17
			_add_attachment_mesh(
				"GravityCore",
				gravity,
				Vector3(0.0, 1.54, 0.57),
				Vector3(90.0, 0.0, 0.0),
				Vector3.ONE,
				Color("#6d49a8"),
				Color("#3c1e72")
			)
		"leaf_crown":
			for leaf_index in 6:
				var angle := lerpf(-48.0, 48.0, float(leaf_index) / 5.0)
				var leaf := PrismMesh.new()
				leaf.size = Vector3(0.18, 0.60, 0.12)
				_add_attachment_mesh(
					"LeafCrown",
					leaf,
					Vector3((float(leaf_index) - 2.5) * 0.12, 2.88 - absf(float(leaf_index) - 2.5) * 0.025, 0.01),
					Vector3(0.0, 0.0, -angle),
					Vector3.ONE,
					Color("#315f3d")
				)
		"leaf_shoulders":
			for side in [-1.0, 1.0]:
				var leaf_shoulder := PrismMesh.new()
				leaf_shoulder.size = Vector3(0.15, 0.34, 0.09)
				_add_attachment_mesh(
					"LeafShoulder",
					leaf_shoulder,
					Vector3(0.48 * side, 1.98, -0.05),
					Vector3(4.0, 0.0, -58.0 * side),
					Vector3.ONE,
					Color("#284f34")
				)
		"gel_core":
			var gel := SphereMesh.new()
			gel.radius = 0.13
			gel.height = 0.26
			_add_attachment_mesh(
				"GelCore",
				gel,
				Vector3(0.0, 1.54, 0.55),
				Vector3.ZERO,
				Vector3(0.74, 1.34, 0.50),
				Color("#79d77d"),
				Color("#267a43")
			)
		"broadcast_screen":
			var screen := BoxMesh.new()
			screen.size = Vector3(0.70, 0.40, 0.09)
			_add_attachment_mesh(
				"BroadcastScreen",
				screen,
				Vector3(0.0, 2.50, 0.49),
				Vector3.ZERO,
				Vector3.ONE,
				Color("#05060a")
			)
			var scanline := BoxMesh.new()
			scanline.size = Vector3(0.52, 0.022, 0.022)
			_add_attachment_mesh(
				"BroadcastScanline",
				scanline,
				Vector3(0.0, 2.50, 0.56),
				Vector3.ZERO,
				Vector3.ONE,
				Color("#e4ddff"),
				Color("#8174b7")
			)
		"broadcast_collar":
			var collar := TorusMesh.new()
			collar.inner_radius = 0.44
			collar.outer_radius = 0.56
			_add_attachment_mesh(
				"BroadcastCollar",
				collar,
				Vector3(0.0, 1.92, 0.02),
				Vector3.ZERO,
				Vector3(1.0, 0.30, 0.82),
				Color("#2c1f3d")
			)
		"broadcast_wave_core":
			for bar_index in 3:
				var wave_bar := BoxMesh.new()
				wave_bar.size = Vector3(0.055, 0.13 + float(bar_index) * 0.07, 0.045)
				_add_attachment_mesh(
					"BroadcastWave",
					wave_bar,
					Vector3((float(bar_index) - 1.0) * 0.11, 1.55, 0.57),
					Vector3.ZERO,
					Vector3.ONE,
					Color("#d9d2f5"),
					Color("#6954a0")
				)
		_:
			_add_legacy_attachment(kind)


func _apply_role_materials(root: Node, role_name: String) -> void:
	if not _is_actual_trial_role(role_name):
		return
	var base_color := Color("#182838")
	var metallic := 0.22
	match role_name:
		"环港走私议会":
			base_color = Color("#101b29")
			metallic = 0.28
		"重力矿联董事会":
			base_color = Color("#202126")
			metallic = 0.48
		"光合修复会":
			base_color = Color("#183528")
			metallic = 0.10
		"幽幕播报社":
			base_color = Color("#24182f")
			metallic = 0.34
	for raw_mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.albedo_color = base_color
		material.metallic = metallic
		material.roughness = 0.78
		mesh_instance.material_override = material


func _is_actual_trial_role(role_name: String) -> bool:
	return role_name in ["环港走私议会", "重力矿联董事会", "光合修复会", "幽幕播报社"]


func _apply_camera_profile(actual_trial: bool) -> void:
	if actual_trial:
		camera_front.position = Vector3(0.0, 1.9, 4.8)
		camera_front.rotation_degrees = Vector3.ZERO
		camera_side.position = Vector3(0.0, 1.9, 4.8)
		camera_side.rotation_degrees = Vector3.ZERO
	else:
		camera_front.position = Vector3(0.0, 1.55, 5.8)
		camera_front.rotation_degrees = Vector3.ZERO
		camera_side.position = Vector3(-1.1, 1.55, 5.68)
		camera_side.rotation_degrees = Vector3(0.0, -11.0, 0.0)


func _add_legacy_attachment(kind: String) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.72, 0.88, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.05, 0.38, 0.55, 1.0)
	material.emission_energy_multiplier = 2.2
	material.metallic = 0.4
	material.roughness = 0.35
	var attachment := MeshInstance3D.new()
	attachment.name = "Attachment_%s" % kind.to_pascal_case()
	attachment.material_override = material
	if kind.ends_with("_ring") or "orbit" in kind or "halo" in kind:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.46
		torus.outer_radius = 0.52
		attachment.mesh = torus
		attachment.position = Vector3(0.0, 2.55, -0.05)
		attachment.rotation_degrees.x = 76.0
	elif "crown" in kind:
		var crown_torus := TorusMesh.new()
		crown_torus.inner_radius = 0.38
		crown_torus.outer_radius = 0.46
		attachment.mesh = crown_torus
		attachment.position = Vector3(0.0, 2.42, 0.02)
		attachment.rotation_degrees.x = 76.0
	elif "ticker" in kind:
		var ticker := BoxMesh.new()
		ticker.size = Vector3(1.2, 0.055, 0.06)
		attachment.mesh = ticker
		attachment.position = Vector3(0.0, 1.28, 0.48)
	elif "frame" in kind or "collar" in kind or "visor" in kind:
		var box := BoxMesh.new()
		box.size = Vector3(1.25, 0.12, 0.1)
		attachment.mesh = box
		attachment.position = Vector3(0.0, 2.15, 0.2)
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.15
		sphere.height = 0.3
		attachment.mesh = sphere
		attachment.position = Vector3(0.0, 1.25, 0.42)
	procedural_attachment_root.add_child(attachment)


func _add_attachment_mesh(
	name_prefix: String,
	mesh: Mesh,
	position: Vector3,
	rotation_degrees: Vector3,
	scale: Vector3,
	color: Color,
	emission: Color = Color.TRANSPARENT
) -> void:
	var attachment := MeshInstance3D.new()
	attachment.name = "Attachment_%s_%02d" % [name_prefix, procedural_attachment_root.get_child_count()]
	attachment.mesh = mesh
	attachment.position = position
	attachment.rotation_degrees = rotation_degrees
	attachment.scale = scale
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.24
	material.roughness = 0.68
	if emission.a > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 2.1
	attachment.material_override = material
	procedural_attachment_root.add_child(attachment)


func _set_status(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message


func _fail(message: String) -> Dictionary:
	_set_status("失败闭合｜%s" % message)
	pipeline_error.emit(message)
	return {"ok": false, "reason": message}


func _on_render_candidates_pressed() -> void:
	await render_all_indexed_candidates()


func _run_automatic_candidate_capture() -> void:
	var result := await render_all_indexed_candidates()
	print("ROLE_PORTRAIT_CANDIDATE_CAPTURE ", JSON.stringify(result))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if bool(result.get("ok", false)) else 1)


func _run_automatic_bound_role_capture() -> void:
	var result := await render_all_bound_roles()
	print("ROLE_PORTRAIT_BOUND_ROLE_CAPTURE ", JSON.stringify(result))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if bool(result.get("ok", false)) else 1)
