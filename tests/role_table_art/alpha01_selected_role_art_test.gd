extends SceneTree

const CatalogScript := preload("res://scripts/presentation/role_portrait_catalog.gd")
const SkinScene := preload("res://scenes/ui/player_seat/PlayerSeatPortraitSkin.tscn")
const ROLE_NAMES := [
	"深海菌毯使团",
	"离子军购局",
	"孪星兽栏同盟",
	"蜂巢防务议会",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog = CatalogScript.new()
	var texture_paths := {}
	var texture_hashes := {}
	for role_name in ROLE_NAMES:
		_expect(catalog.has_role(role_name), "%s exists in the role-art manifest" % role_name)
		var entry: Dictionary = catalog.entry_for_role(role_name)
		_expect(str(entry.get("status", "")) == "rendered", "%s is rendered" % role_name)
		_expect(str(entry.get("quality_tier", "")) == "alpha01_generated_original", "%s has explicit generated-original tier" % role_name)
		_expect(str(entry.get("identity_signature", "")) != "", "%s has an identity signature" % role_name)
		for view_kind in ["front", "side_inward"]:
			var path := str(entry.get("%s_path" % view_kind, ""))
			var expected_hash := str(entry.get("%s_sha256" % view_kind, ""))
			_expect(path.begins_with("assets/art/role_portraits/temporary/"), "%s %s stays inside the portrait catalog root" % [role_name, view_kind])
			var resource_path := "res://%s" % path
			_expect(ResourceLoader.exists(resource_path), "%s %s is imported by Godot" % [role_name, view_kind])
			var texture := catalog.portrait_texture_or_null(role_name, view_kind) as Texture2D
			_expect(texture != null, "%s %s resolves through RolePortraitCatalog" % [role_name, view_kind])
			if texture == null:
				continue
			_expect(not bool(texture.get_meta("role_portrait_is_placeholder", true)), "%s %s is never the procedural fallback" % [role_name, view_kind])
			var image := texture.get_image()
			_expect(image != null and not image.is_empty(), "%s %s Texture2D exposes image data" % [role_name, view_kind])
			if image == null or image.is_empty():
				continue
			_expect(image.get_width() == 512 and image.get_height() == 768, "%s %s imports at 512x768" % [role_name, view_kind])
			_expect(image.get_format() == Image.FORMAT_RGBA8, "%s %s imports as RGBA8" % [role_name, view_kind])
			var alpha_range := _sample_alpha_range(image)
			_expect(alpha_range.x <= 0.01 and alpha_range.y >= 0.99, "%s %s preserves transparent background and opaque subject" % [role_name, view_kind])
			_expect(FileAccess.get_sha256(resource_path) == expected_hash, "%s %s runtime PNG hash matches manifest" % [role_name, view_kind])
			texture_paths[resource_path] = true
			texture_hashes[expected_hash] = true
		await _verify_skin(role_name, "front", "front", false)
		await _verify_skin(role_name, "left", "side_inward", false)
		await _verify_skin(role_name, "right", "side_inward", true)
	_expect(texture_paths.size() == 8, "all eight runtime paths are unique")
	_expect(texture_hashes.size() == 8, "all eight runtime hashes are unique")
	_finish()


func _verify_skin(role_name: String, direction: String, expected_view: String, expected_flip: bool) -> void:
	var skin := SkinScene.instantiate()
	root.add_child(skin)
	await process_frame
	var available: bool = skin.apply_public_view_model({
		"seat_index": 0,
		"player_display_name": "Alpha QA",
		"public_role_name": role_name,
		"player_color": Color("#38bdf8"),
		"public_status": "waiting",
		"inward_direction": direction,
		"depth_class": "mid",
	})
	var snapshot: Dictionary = skin.public_debug_snapshot()
	_expect(available and skin.visible, "%s %s activates PlayerSeatPortraitSkin" % [role_name, direction])
	_expect(str(snapshot.get("portrait_view", "")) == expected_view, "%s %s selects %s" % [role_name, direction, expected_view])
	_expect(bool(snapshot.get("flip_horizontal", not expected_flip)) == expected_flip, "%s %s flip contract is correct" % [role_name, direction])
	_expect(int(snapshot.get("mouse_filter", -1)) == Control.MOUSE_FILTER_IGNORE, "%s %s skin does not block table input" % [role_name, direction])
	skin.queue_free()
	await process_frame


func _sample_alpha_range(image: Image) -> Vector2:
	var minimum_alpha := 1.0
	var maximum_alpha := 0.0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var alpha := image.get_pixel(x, y).a
			minimum_alpha = minf(minimum_alpha, alpha)
			maximum_alpha = maxf(maximum_alpha, alpha)
	return Vector2(minimum_alpha, maximum_alpha)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("ALPHA01_SELECTED_ROLE_ART_TEST: %s" % message)


func _finish() -> void:
	print("ALPHA01_SELECTED_ROLE_ART_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	for failure in _failures:
		print("FAIL|%s" % failure)
	quit(_failures.size())
