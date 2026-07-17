@tool
class_name RolePortraitCatalog
extends RefCounted

const DEFAULT_MANIFEST_PATH := "res://assets/art/role_portraits/temporary/manifest.json"
const ALLOWED_PORTRAIT_ROOT := "res://assets/art/role_portraits/temporary/"

var manifest_path: String = DEFAULT_MANIFEST_PATH
var _entries_by_role: Dictionary = {}
var _texture_cache: Dictionary = {}
var _load_reason := "manifest_not_loaded"


func _init(source_manifest_path: String = DEFAULT_MANIFEST_PATH) -> void:
	manifest_path = source_manifest_path
	reload()


func reload() -> bool:
	_entries_by_role.clear()
	_texture_cache.clear()
	if not _is_safe_manifest_path(manifest_path):
		_load_reason = "manifest_path_rejected"
		return false
	if not FileAccess.file_exists(manifest_path):
		_load_reason = "manifest_missing"
		return false
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		_load_reason = "manifest_unreadable"
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_load_reason = "manifest_invalid_json"
		return false
	var entries := _manifest_entries(parsed as Dictionary)
	for entry_variant in entries:
		if not entry_variant is Dictionary:
			continue
		var entry := (entry_variant as Dictionary).duplicate(true)
		var role_name := _role_key(entry)
		if role_name.is_empty() or _entries_by_role.has(role_name):
			continue
		_entries_by_role[role_name] = entry
	_load_reason = "ok" if not _entries_by_role.is_empty() else "manifest_empty"
	return not _entries_by_role.is_empty()


func has_role(role_name: String) -> bool:
	return _entries_by_role.has(role_name)


func entry_for_role(role_name: String) -> Dictionary:
	if not _entries_by_role.has(role_name):
		return {}
	return (_entries_by_role[role_name] as Dictionary).duplicate(true)


func portrait_texture(role_name: String, view_kind: String = "front") -> Texture2D:
	var resolved := portrait_texture_or_null(role_name, view_kind)
	if resolved != null:
		return resolved
	return _missing_portrait_texture(role_name, "side_inward" if view_kind == "side_inward" else "front")


func portrait_texture_or_null(role_name: String, view_kind: String = "front") -> Texture2D:
	var normalized_view := "side_inward" if view_kind == "side_inward" else "front"
	var cache_key := "%s|%s" % [role_name, normalized_view]
	if _texture_cache.has(cache_key):
		var cached: Variant = _texture_cache[cache_key]
		return cached as Texture2D if cached is Texture2D else null
	var entry := entry_for_role(role_name)
	var path := _portrait_path(entry, normalized_view)
	var texture: Texture2D
	if _is_safe_portrait_path(path) and ResourceLoader.exists(path):
		var loaded := ResourceLoader.load(path)
		if loaded is Texture2D:
			texture = loaded as Texture2D
			texture.set_meta("role_portrait_is_placeholder", false)
			texture.set_meta("role_portrait_path", path)
			texture.set_meta("role_portrait_source_model", str(entry.get("source_path", "")))
			texture.set_meta("role_portrait_render_variant", normalized_view)
	_texture_cache[cache_key] = texture
	return texture


func has_rendered_portrait(role_name: String, view_kind: String = "front") -> bool:
	return portrait_texture_or_null(role_name, view_kind) != null


func portrait_availability(role_name: String, view_kind: String = "front") -> Dictionary:
	var normalized_view := "side_inward" if view_kind == "side_inward" else "front"
	var entry := entry_for_role(role_name)
	var path := _portrait_path(entry, normalized_view)
	var available := portrait_texture_or_null(role_name, normalized_view) != null
	return {
		"available": available,
		"is_placeholder": not available,
		"role_known": not entry.is_empty(),
		"view_kind": normalized_view,
		"reason": "ok" if available else ("portrait_pending" if not entry.is_empty() else "role_unknown"),
		"path": path if available else "",
		"source_model": str(entry.get("source_path", "")),
	}


func public_role_names() -> PackedStringArray:
	var names := PackedStringArray()
	for role_name_variant in _entries_by_role.keys():
		names.append(str(role_name_variant))
	names.sort()
	return names


func developer_snapshot() -> Dictionary:
	return {
		"available": not _entries_by_role.is_empty(),
		"manifest_path": manifest_path,
		"role_count": _entries_by_role.size(),
		"reason": _load_reason,
	}


func _manifest_entries(manifest: Dictionary) -> Array:
	if manifest.get("roles", null) is Array:
		return manifest["roles"] as Array
	if manifest.get("roles", null) is Dictionary:
		var rows: Array = []
		for role_name_variant in (manifest["roles"] as Dictionary).keys():
			var value: Variant = (manifest["roles"] as Dictionary)[role_name_variant]
			if not value is Dictionary:
				continue
			var row := (value as Dictionary).duplicate(true)
			row["role_name"] = str(role_name_variant)
			rows.append(row)
		return rows
	for key in ["entries", "portraits", "role_portraits"]:
		if manifest.get(key, null) is Array:
			return manifest[key] as Array
	return []


func _role_key(entry: Dictionary) -> String:
	for key in ["role_name", "stable_key", "name", "display_name"]:
		var value := str(entry.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""


func _portrait_path(entry: Dictionary, view_kind: String) -> String:
	if entry.is_empty():
		return ""
	var keys := ["side_inward", "side_inward_path", "side_path"] if view_kind == "side_inward" else ["front", "front_path"]
	for key in keys:
		var direct := str(entry.get(key, "")).strip_edges()
		if not direct.is_empty():
			return _normalize_portrait_path(direct)
	var derived: Variant = entry.get("derived_png_paths", {})
	if derived is Dictionary:
		var nested := str((derived as Dictionary).get(view_kind, "")).strip_edges()
		if not nested.is_empty():
			return _normalize_portrait_path(nested)
	return ""


func _normalize_portrait_path(path: String) -> String:
	var normalized := path.replace("\\", "/")
	if normalized.begins_with("res://"):
		return normalized
	if normalized.begins_with("assets/"):
		return "res://%s" % normalized
	return "%s%s" % [ALLOWED_PORTRAIT_ROOT, normalized]


func _is_safe_manifest_path(path: String) -> bool:
	return path == DEFAULT_MANIFEST_PATH and not path.contains("..")


func _is_safe_portrait_path(path: String) -> bool:
	return path.begins_with(ALLOWED_PORTRAIT_ROOT) and not path.contains("..") and path.to_lower().ends_with(".png")


func _missing_portrait_texture(role_name: String, view_kind: String) -> Texture2D:
	var image := Image.create(256, 384, false, Image.FORMAT_RGBA8)
	image.fill(Color("#26080b"))
	var red := Color("#ef3340")
	image.fill_rect(Rect2i(0, 0, 256, 12), red)
	image.fill_rect(Rect2i(0, 372, 256, 12), red)
	image.fill_rect(Rect2i(0, 0, 12, 384), red)
	image.fill_rect(Rect2i(244, 0, 12, 384), red)
	for stripe in 8:
		image.fill_rect(Rect2i(24 + stripe * 28, 82, 12, 220), Color("#6f151d"))
	var texture := ImageTexture.create_from_image(image)
	texture.set_meta("role_portrait_is_placeholder", true)
	texture.set_meta("role_portrait_missing_role", role_name)
	texture.set_meta("role_portrait_render_variant", view_kind)
	return texture
