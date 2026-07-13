extends RefCounted
class_name CompendiumContentRegistry

const CARD_DIR := "res://resources/compendium/cards/"
const PRODUCT_DIR := "res://resources/compendium/products/"
const MONSTER_DIR := "res://resources/compendium/monsters/"
const PRIVACY_TOKENS := ["hidden_owner", "private_target", "private_discard"]

var _loaded := false
var _entries_by_id: Dictionary = {}
var _resource_paths_by_id: Dictionary = {}


func entry_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for id in _entries_by_id.keys():
		result.append(str(id))
	result.sort()
	return result


func all_entries() -> Array:
	_ensure_loaded()
	var result: Array = []
	for id in entry_ids():
		result.append(entry_payload(id))
	return result


func entries_by_type(entry_type: String) -> Array:
	_ensure_loaded()
	var result: Array = []
	for id in entry_ids():
		var entry: Resource = _entries_by_id.get(id) as Resource
		if entry != null and entry.has_method("entry_kind") and str(entry.call("entry_kind")) == entry_type:
			result.append(entry_payload(id))
	return result


func entry_payload(entry_id: String) -> Dictionary:
	_ensure_loaded()
	var entry: Resource = _entries_by_id.get(entry_id) as Resource
	if entry == null:
		return {}
	var payload: Dictionary = {}
	if entry.has_method("to_payload"):
		var payload_variant: Variant = entry.call("to_payload")
		if payload_variant is Dictionary:
			payload = payload_variant as Dictionary
	payload["entry_id"] = entry_id
	payload["entry_type"] = str(entry.call("entry_kind")) if entry.has_method("entry_kind") else ""
	payload["resource_path"] = str(_resource_paths_by_id.get(entry_id, ""))
	var sanitized_payload: Variant = _sanitize_payload(payload)
	return sanitized_payload as Dictionary if sanitized_payload is Dictionary else {}


func to_card_codex_payload(entry_id: String) -> Dictionary:
	_ensure_loaded()
	var entry: Resource = _entries_by_id.get(entry_id) as Resource
	if entry != null and entry.has_method("to_card_codex_payload"):
		var payload_variant: Variant = entry.call("to_card_codex_payload")
		var sanitized_payload: Variant = _sanitize_payload(payload_variant)
		return sanitized_payload as Dictionary if sanitized_payload is Dictionary else {}
	return {}


func to_product_codex_payload(entry_id: String) -> Dictionary:
	_ensure_loaded()
	var entry: Resource = _entries_by_id.get(entry_id) as Resource
	if entry != null and entry.has_method("to_product_codex_payload"):
		var payload_variant: Variant = entry.call("to_product_codex_payload")
		var sanitized_payload: Variant = _sanitize_payload(payload_variant)
		return sanitized_payload as Dictionary if sanitized_payload is Dictionary else {}
	return {}


func to_bestiary_payload(entry_id: String) -> Dictionary:
	_ensure_loaded()
	var entry: Resource = _entries_by_id.get(entry_id) as Resource
	if entry != null and entry.has_method("to_bestiary_payload"):
		var payload_variant: Variant = entry.call("to_bestiary_payload")
		var sanitized_payload: Variant = _sanitize_payload(payload_variant)
		return sanitized_payload as Dictionary if sanitized_payload is Dictionary else {}
	return {}


func resource_path_for(entry_id: String) -> String:
	_ensure_loaded()
	return str(_resource_paths_by_id.get(entry_id, ""))


func validate_entries() -> Array:
	_ensure_loaded()
	var records: Array = []
	var seen: Dictionary = {}
	for id in entry_ids():
		var entry: Resource = _entries_by_id.get(id) as Resource
		var entry_type := str(entry.call("entry_kind")) if entry != null and entry.has_method("entry_kind") else ""
		var resource_path := resource_path_for(id)
		var payload: Dictionary = entry_payload(id)
		var missing: Array = entry.call("required_fields_missing") if entry != null and entry.has_method("required_fields_missing") else ["resource"]
		var payload_checked := _is_pure_data(payload)
		var privacy_checked := _privacy_checked(payload)
		var ui_payload_checked := false
		match entry_type:
			"card":
				ui_payload_checked = not to_card_codex_payload(id).is_empty()
			"product":
				ui_payload_checked = not to_product_codex_payload(id).is_empty()
			"monster":
				ui_payload_checked = not to_bestiary_payload(id).is_empty()
			_:
				ui_payload_checked = not payload.is_empty()
		var duplicate := seen.has(id)
		seen[id] = true
		var passed := not duplicate and missing.is_empty() and payload_checked and privacy_checked and ui_payload_checked
		records.append({
			"case_id": "resource_%s" % id,
			"entry_id": id,
			"entry_type": entry_type,
			"resource_path": resource_path,
			"payload_checked": payload_checked and missing.is_empty(),
			"privacy_checked": privacy_checked,
			"ui_payload_checked": ui_payload_checked,
			"passed": passed,
			"notes": "ok" if passed else "duplicate=%s missing=%s payload=%s privacy=%s ui=%s" % [str(duplicate), str(missing), str(payload_checked), str(privacy_checked), str(ui_payload_checked)],
		})
	return records


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_load_dir(CARD_DIR)
	_load_dir(PRODUCT_DIR)
	_load_dir(MONSTER_DIR)


func _load_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			continue
		var path := dir_path + file_name
		var resource: Resource = load(path) as Resource
		if resource == null:
			continue
		for entry in _entry_resources_from(resource):
			_register_entry(entry, path, file_name.get_basename())
	dir.list_dir_end()


func _entry_resources_from(resource: Resource) -> Array[Resource]:
	var result: Array[Resource] = []
	if resource.has_method("entry_kind"):
		result.append(resource)
	elif resource.has_method("entry_resources"):
		var packed_entries: Variant = resource.call("entry_resources")
		if packed_entries is Array:
			for entry_variant in packed_entries:
				var entry: Resource = entry_variant as Resource
				if entry != null and entry.has_method("entry_kind"):
					result.append(entry)
	return result


func _register_entry(entry: Resource, resource_path: String, fallback_id: String) -> void:
	var id := str(entry.get("entry_id"))
	if id.strip_edges() == "":
		id = fallback_id
	_entries_by_id[id] = entry
	_resource_paths_by_id[id] = "%s#%s" % [resource_path, id]


func _sanitize_payload(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value.keys():
			result[_sanitize_payload(key)] = _sanitize_payload(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_sanitize_payload(item))
		return result
	if value is PackedStringArray:
		var result: Array[String] = []
		for item in value:
			result.append(str(item))
		return result
	if value is Color:
		return "#%s" % (value as Color).to_html(false)
	if value is Callable or value is Object:
		return str(value)
	return value


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key in value.keys():
			if not _is_pure_data(key) or not _is_pure_data(value[key]):
				return false
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
	return true


func _privacy_checked(value: Variant) -> bool:
	var text := JSON.stringify(value).to_lower()
	for token in PRIVACY_TOKENS:
		if text.contains(token):
			return false
	return true
