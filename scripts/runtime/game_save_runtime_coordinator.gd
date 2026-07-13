@tool
extends Node
class_name GameSaveRuntimeCoordinator

const CURRENT_SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://space_syndicate_current_run.save"
const QA_SAVE_ROOT := "user://space_syndicate_design_qa/test_runs/"
const FORMAT_ID := "godot_variant_binary"

var _save_version := CURRENT_SAVE_VERSION
var _default_save_path := DEFAULT_SAVE_PATH
var _qa_default_save_path_override := ""
var _configured := false
var _last_operation := "idle"
var _last_operation_state := "clean"
var _last_error_code: int = OK
var _last_path := ""


func configure(configured_save_version: int = CURRENT_SAVE_VERSION, configured_default_save_path: String = DEFAULT_SAVE_PATH) -> void:
	_save_version = configured_save_version
	var configured_path := configured_default_save_path.strip_edges()
	_default_save_path = _qa_default_save_path_override if not _qa_default_save_path_override.is_empty() else configured_path
	var production_path_valid := _qa_default_save_path_override.is_empty() and _default_save_path == DEFAULT_SAVE_PATH
	var qa_path_valid := not _qa_default_save_path_override.is_empty() and _is_qa_save_path(_default_save_path)
	_configured = _save_version == CURRENT_SAVE_VERSION and (production_path_valid or qa_path_valid)


func set_qa_default_save_path_override(path: String) -> bool:
	var normalized := path.strip_edges()
	if normalized.is_empty():
		_qa_default_save_path_override = ""
		return true
	if not _is_qa_save_path(normalized):
		return false
	_qa_default_save_path_override = normalized
	return true


func clear_qa_default_save_path_override() -> void:
	_qa_default_save_path_override = ""


func save_version() -> int:
	return _save_version


func default_save_path() -> String:
	return _default_save_path


func resolved_save_path(path: String = "") -> String:
	return _default_save_path if path.strip_edges() == "" else path


func compose_save_payload(_session_payload: Dictionary, domain_sections: Dictionary) -> Dictionary:
	if not _is_data_only(domain_sections):
		return {}
	var payload := normalize_save_payload(domain_sections)
	payload["version"] = _save_version
	return payload


func validate_save_payload(payload: Dictionary) -> Dictionary:
	if not _is_data_only(payload):
		return _validation_result(false, ERR_INVALID_DATA, "payload contains runtime objects")
	if int(payload.get("version", 0)) != _save_version:
		return _validation_result(false, ERR_INVALID_DATA, "unsupported save version")
	if not (payload.get("players", null) is Array):
		return _validation_result(false, ERR_INVALID_DATA, "players must be an Array")
	if not (payload.get("districts", null) is Array):
		return _validation_result(false, ERR_INVALID_DATA, "districts must be an Array")
	return _validation_result(true, OK, "")


func normalize_save_payload(payload: Dictionary) -> Dictionary:
	var normalized_variant: Variant = _strip_legacy_card_runtime_fields(payload)
	return (normalized_variant as Dictionary).duplicate(true) if normalized_variant is Dictionary else {}


func write_save(path: String, payload: Dictionary) -> Dictionary:
	var resolved_path := resolved_save_path(path)
	var validation := validate_save_payload(payload)
	if not bool(validation.get("valid", false)):
		return _operation_result("write", false, int(validation.get("error_code", ERR_INVALID_DATA)), resolved_path, {}, FileAccess.file_exists(resolved_path))
	var absolute_path := ProjectSettings.globalize_path(resolved_path)
	var make_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if make_error != OK:
		return _operation_result("write", false, make_error, resolved_path, {}, FileAccess.file_exists(resolved_path))
	var file := FileAccess.open(resolved_path, FileAccess.WRITE)
	if file == null:
		return _operation_result("write", false, FileAccess.get_open_error(), resolved_path, {}, FileAccess.file_exists(resolved_path))
	file.store_var(payload, false)
	file.close()
	return _operation_result("write", true, OK, resolved_path, {}, true)


func read_save(path: String = "") -> Dictionary:
	var resolved_path := resolved_save_path(path)
	if not FileAccess.file_exists(resolved_path):
		return _operation_result("read", false, ERR_FILE_NOT_FOUND, resolved_path, {}, false)
	var file := FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		return _operation_result("read", false, FileAccess.get_open_error(), resolved_path, {}, true)
	var state_variant: Variant = file.get_var(false)
	file.close()
	if not (state_variant is Dictionary):
		return _operation_result("read", false, ERR_INVALID_DATA, resolved_path, {}, true)
	var normalized := normalize_save_payload(state_variant as Dictionary)
	var validation := validate_save_payload(normalized)
	if not bool(validation.get("valid", false)):
		return _operation_result("read", false, int(validation.get("error_code", ERR_INVALID_DATA)), resolved_path, {}, true)
	return _operation_result("read", true, OK, resolved_path, normalized, true)


func has_valid_save(path: String = "") -> bool:
	return bool(read_save(path).get("ok", false))


func extract_section(payload: Dictionary, section_id: String) -> Variant:
	var value: Variant = payload.get(section_id)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value


func build_save_summary(payload: Dictionary, _scoring_rules: Dictionary) -> Dictionary:
	var saved_players: Array = payload.get("players", []) if payload.get("players", []) is Array else []
	var saved_districts: Array = payload.get("districts", []) if payload.get("districts", []) is Array else []
	return {
		"game_time": float(payload.get("game_time", 0.0)),
		"business_cycle_count": int(payload.get("business_cycle_count", 0)),
		"player_count": saved_players.size(),
		"active_city_total": _saved_active_city_total_count(saved_districts),
		"leader_text": _saved_victory_status_text(payload, saved_players),
	}


func operation_snapshot() -> Dictionary:
	return {
		"configured": _configured,
		"format": FORMAT_ID,
		"save_version": _save_version,
		"default_save_path": _default_save_path,
		"qa_save_path_override_active": not _qa_default_save_path_override.is_empty(),
		"qa_save_root": QA_SAVE_ROOT,
		"last_operation": _last_operation,
		"operation_state": _last_operation_state,
		"last_error_code": _last_error_code,
		"last_path": _last_path,
	}


func debug_snapshot() -> Dictionary:
	return operation_snapshot()


func _validation_result(valid: bool, error_code: int, reason: String) -> Dictionary:
	return {
		"valid": valid,
		"error_code": error_code,
		"reason": reason,
		"save_version": _save_version,
		"format": FORMAT_ID,
	}


func _operation_result(operation: String, ok: bool, error_code: int, path: String, payload: Dictionary, exists: bool) -> Dictionary:
	_last_operation = operation
	_last_operation_state = "clean" if ok else "failed"
	_last_error_code = error_code
	_last_path = path
	return {
		"ok": ok,
		"error_code": error_code,
		"path": path,
		"exists": exists,
		"payload": payload.duplicate(true),
		"save_version": _save_version,
		"format": FORMAT_ID,
	}


func _strip_legacy_card_runtime_fields(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary := (value as Dictionary).duplicate(true)
		dictionary.erase("charge")
		dictionary.erase("control")
		for key_variant in dictionary.keys():
			dictionary[key_variant] = _strip_legacy_card_runtime_fields(dictionary[key_variant])
		return dictionary
	if value is Array:
		var array := (value as Array).duplicate(true)
		for index in range(array.size()):
			array[index] = _strip_legacy_card_runtime_fields(array[index])
		return array
	return value


func _saved_victory_status_text(payload: Dictionary, saved_players: Array) -> String:
	var wrapped: Dictionary = payload.get("victory_control_runtime", {}) if payload.get("victory_control_runtime", {}) is Dictionary else {}
	var victory: Dictionary = wrapped.get("victory_control_runtime", wrapped) if wrapped.get("victory_control_runtime", wrapped) is Dictionary else {}
	var receipt: Dictionary = victory.get("outcome_receipt", {}) if victory.get("outcome_receipt", {}) is Dictionary else {}
	var winners: Array = receipt.get("winner_player_indices", []) if receipt.get("winner_player_indices", []) is Array else []
	if not winners.is_empty():
		var names: Array[String] = []
		for winner_variant in winners:
			var player_index := int(winner_variant)
			if player_index >= 0 and player_index < saved_players.size() and saved_players[player_index] is Dictionary:
				names.append(str((saved_players[player_index] as Dictionary).get("name", "玩家%d" % (player_index + 1))))
		return "胜者 %s" % "、".join(names)
	var state := str(victory.get("state", "idle"))
	return {
		"qualification": "胜利资格确认中",
		"audit": "公开审计进行中",
		"cooldown": "审计冷却中",
		"resolved": "审计已结算",
	}.get(state, "尚未进入胜利审计") as String


func _saved_active_city_total_count(saved_districts: Array) -> int:
	var total := 0
	for district_variant in saved_districts:
		if district_variant is Dictionary:
			var city: Dictionary = (district_variant as Dictionary).get("city", {}) if (district_variant as Dictionary).get("city", {}) is Dictionary else {}
			if _saved_city_is_active(city):
				total += 1
	return total


func _saved_active_city_count(saved_districts: Array, player_index: int) -> int:
	var total := 0
	for district_variant in saved_districts:
		if district_variant is Dictionary:
			var city: Dictionary = (district_variant as Dictionary).get("city", {}) if (district_variant as Dictionary).get("city", {}) is Dictionary else {}
			if _saved_city_is_active(city) and int(city.get("owner", -1)) == player_index:
				total += 1
	return total


func _saved_city_is_active(city: Dictionary) -> bool:
	return not city.is_empty() and bool(city.get("active", true))


func _is_data_only(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT or value is Callable:
		return false
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
	elif value is Array:
		for item_variant in value:
			if not _is_data_only(item_variant):
				return false
	return true


func _is_qa_save_path(path: String) -> bool:
	return path.begins_with(QA_SAVE_ROOT) and path.ends_with(".save") and not path.contains("..")
