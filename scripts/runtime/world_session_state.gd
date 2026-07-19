@tool
extends Node
class_name WorldSessionState

const EnvelopeCodec := preload("res://scripts/runtime/world_session_envelope_codec.gd")

signal players_replaced(player_count: int)
signal districts_replaced(district_count: int)
signal game_time_changed(game_time: float)
signal world_geometry_changed(width_m: float, height_m: float, revision: int)
signal session_restored(summary: Dictionary)
signal city_inference_changed(viewer_index: int, region_id: String, owner_revision: String)

const DEFAULT_MAP_WIDTH_M := 1400.0
const DEFAULT_MAP_HEIGHT_M := 950.0
const CITY_GUESS_CONFIDENCE_LOW := 1
const CITY_GUESS_CONFIDENCE_MEDIUM := 2
const CITY_GUESS_CONFIDENCE_HIGH := 3
const CITY_GUESS_AUTHORIZED_REVEAL := 100
const CITY_GUESS_REASON_IDS := ["product", "route", "card", "monster", "role", "intuition"]

@export var role_catalog_path: NodePath

var _players: Array = []
var _districts: Array = []
var _game_time := 0.0
var _map_width_m := DEFAULT_MAP_WIDTH_M
var _map_height_m := DEFAULT_MAP_HEIGHT_M
var _world_geometry_revision := 0
var _city_inference_mutation_count := 0

var players: Array:
	get:
		return _players
	set(value):
		replace_players(value)

var districts: Array:
	get:
		return _districts
	set(value):
		replace_districts(value)

var game_time: float:
	get:
		return _game_time
	set(value):
		set_game_time(value)

var map_width_m: float:
	get:
		return _map_width_m

var map_height_m: float:
	get:
		return _map_height_m


func reset() -> Dictionary:
	_players = []
	_districts = []
	_game_time = 0.0
	_map_width_m = DEFAULT_MAP_WIDTH_M
	_map_height_m = DEFAULT_MAP_HEIGHT_M
	_world_geometry_revision += 1
	_city_inference_mutation_count = 0
	var summary := debug_snapshot()
	players_replaced.emit(0)
	districts_replaced.emit(0)
	game_time_changed.emit(0.0)
	world_geometry_changed.emit(_map_width_m, _map_height_m, _world_geometry_revision)
	session_restored.emit(summary)
	return summary


func replace_players(value: Array, duplicate := false) -> Array:
	_players = value.duplicate(true) if duplicate else value
	players_replaced.emit(_players.size())
	return _players


func replace_districts(value: Array, duplicate := false) -> Array:
	_districts = value.duplicate(true) if duplicate else value
	districts_replaced.emit(_districts.size())
	return _districts


func set_game_time(value: float) -> float:
	var normalized := maxf(0.0, value)
	if not is_equal_approx(normalized, _game_time):
		_game_time = normalized
		game_time_changed.emit(_game_time)
	else:
		_game_time = normalized
	return _game_time


func advance_game_time(delta: float) -> float:
	if delta <= 0.0:
		return _game_time
	return set_game_time(_game_time + delta)


func configure_world_geometry(width_m: float, height_m: float) -> Dictionary:
	var normalized_width := maxf(1.0, width_m)
	var normalized_height := maxf(1.0, height_m)
	if not is_equal_approx(normalized_width, _map_width_m) or not is_equal_approx(normalized_height, _map_height_m):
		_map_width_m = normalized_width
		_map_height_m = normalized_height
		_world_geometry_revision += 1
		world_geometry_changed.emit(_map_width_m, _map_height_m, _world_geometry_revision)
	else:
		_map_width_m = normalized_width
		_map_height_m = normalized_height
	return public_world_geometry_snapshot()


func public_world_geometry_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"revision": _world_geometry_revision,
		"width_m": _map_width_m,
		"height_m": _map_height_m,
		"world_rect": Rect2(Vector2.ZERO, Vector2(_map_width_m, _map_height_m)),
		"visibility_scope": "public",
	}


func public_lifecycle_snapshot() -> Dictionary:
	return {
		"available": not _players.is_empty(),
		"session_revision": _world_geometry_revision,
		"world_time": _game_time,
		"session_state": "empty" if _players.is_empty() else "active",
		"session_finished": false,
		"visibility_scope": "public",
	}


func public_intel_projection() -> Dictionary:
	var public_players: Array = []
	for player_index in range(_players.size()):
		var player: Dictionary = _players[player_index] if _players[player_index] is Dictionary else {}
		var role: Dictionary = player.get("role_card", {}) if player.get("role_card", {}) is Dictionary else {}
		public_players.append({
			"player_index": player_index,
			"public_player_name": str(player.get("name", "玩家%d" % (player_index + 1))),
			"role_index": int(player.get("role_index", role.get("role_index", -1))),
			"role_name": str(role.get("name", "")),
			"eliminated": bool(player.get("eliminated", false)),
			"visibility_scope": "public",
		})
	var public_regions: Array = []
	for district_index in range(_districts.size()):
		if not (_districts[district_index] is Dictionary):
			continue
		var district := _districts[district_index] as Dictionary
		var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
		public_regions.append({
			"district_index": district_index,
			"region_id": _region_id_for_district(district_index),
			"name": str(district.get("name", "区域%d" % (district_index + 1))),
			"destroyed": bool(district.get("destroyed", false)),
			"terrain": str(district.get("terrain", "land")),
			"products": _canonical_string_array(district.get("products", [])),
			"demands": _canonical_string_array(district.get("demands", [])),
			"damage": maxi(0, int(district.get("damage", 0))),
			"city_present": not city.is_empty(),
			"city_active": not city.is_empty() and bool(city.get("active", true)),
			"city_level": maxi(0, int(city.get("level", 0))),
			"city_products": _canonical_string_array(city.get("products", [])),
			"city_demands": _canonical_string_array(city.get("demands", [])),
			"city_last_income": int(city.get("last_income", 0)),
			"city_competition_matches": maxi(0, int(city.get("competition_matches", 0))),
			"visibility_scope": "public",
		})
	return {
		"schema_version": 1,
		"visibility_scope": "public",
		"players": public_players,
		"regions": public_regions,
		"world_time": _game_time,
	}


func city_inference_projection(viewer_index: int) -> Dictionary:
	if viewer_index < 0 or viewer_index >= _players.size():
		return {}
	var player: Dictionary = _players[viewer_index] if _players[viewer_index] is Dictionary else {}
	return {
		"schema_version": 1,
		"visibility_scope": "viewer_private",
		"viewer_index": viewer_index,
		"viewer_name": str(player.get("name", "玩家%d" % (viewer_index + 1))),
		"owner_revision": city_inference_owner_revision(viewer_index),
		"records": _city_inference_records(viewer_index),
		"foreign_active_region_ids": _foreign_active_region_ids(viewer_index),
	}


func city_inference_owner_revision(viewer_index: int) -> String:
	if viewer_index < 0 or viewer_index >= _players.size():
		return ""
	var region_state: Array = []
	for district_index in range(_districts.size()):
		if not (_districts[district_index] is Dictionary):
			continue
		var district := _districts[district_index] as Dictionary
		var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
		region_state.append([
			_region_id_for_district(district_index),
			bool(district.get("destroyed", false)),
			not city.is_empty() and bool(city.get("active", true)),
		])
	return _stable_hash({
		"viewer_index": viewer_index,
		"player_count": _players.size(),
		"regions": region_state,
		"records": _city_inference_records(viewer_index),
	})


func region_id_for_district(district_index: int) -> String:
	return _region_id_for_district(district_index)


func district_index_for_region_id(region_id: String) -> int:
	var normalized := region_id.strip_edges()
	if normalized.is_empty() or normalized != region_id:
		return -1
	for district_index in range(_districts.size()):
		if _region_id_for_district(district_index) == normalized:
			return district_index
	return -1


func set_city_owner_guess(
	viewer_index: int,
	region_id: String,
	suspected_player_index: int,
	confidence: int,
	reason_id: String,
	expected_owner_revision: String
) -> Dictionary:
	var before := city_inference_owner_revision(viewer_index)
	var validation := _validate_manual_city_mutation(viewer_index, region_id, expected_owner_revision, before)
	if not bool(validation.get("valid", false)):
		return _city_inference_result(false, false, str(validation.get("reason_code", "city_inference_invalid")), before, before)
	if suspected_player_index < 0 or suspected_player_index >= _players.size() or suspected_player_index == viewer_index:
		return _city_inference_result(false, false, "city_suspect_invalid", before, before)
	if confidence not in [CITY_GUESS_CONFIDENCE_LOW, CITY_GUESS_CONFIDENCE_MEDIUM, CITY_GUESS_CONFIDENCE_HIGH]:
		return _city_inference_result(false, false, "city_confidence_invalid", before, before)
	if not CITY_GUESS_REASON_IDS.has(reason_id):
		return _city_inference_result(false, false, "city_reason_invalid", before, before)
	var district_index := int(validation.get("district_index", -1))
	var current := _city_inference_record(viewer_index, district_index)
	if int(current.get("confidence", 0)) == CITY_GUESS_AUTHORIZED_REVEAL:
		return _city_inference_result(false, false, "authorized_reveal_locked", before, before)
	if int(current.get("suspected_player_index", -1)) == suspected_player_index \
			and int(current.get("confidence", 0)) == confidence \
			and str(current.get("reason_id", "")) == reason_id:
		return _city_inference_result(true, false, "unchanged", before, before)
	var player := (_players[viewer_index] as Dictionary).duplicate(true)
	var guesses: Dictionary = player.get("city_guesses", {}) if player.get("city_guesses", {}) is Dictionary else {}
	var confidences: Dictionary = player.get("city_guess_confidence", {}) if player.get("city_guess_confidence", {}) is Dictionary else {}
	var reasons: Dictionary = player.get("city_guess_reasons", {}) if player.get("city_guess_reasons", {}) is Dictionary else {}
	guesses = guesses.duplicate(true)
	confidences = confidences.duplicate(true)
	reasons = reasons.duplicate(true)
	guesses[district_index] = suspected_player_index
	confidences[district_index] = confidence
	reasons[district_index] = reason_id
	player["city_guesses"] = guesses
	player["city_guess_confidence"] = confidences
	player["city_guess_reasons"] = reasons
	_players[viewer_index] = player
	return _commit_city_inference(viewer_index, region_id, before, "city_owner_guess_set")


func clear_city_owner_guess(viewer_index: int, region_id: String, expected_owner_revision: String) -> Dictionary:
	var before := city_inference_owner_revision(viewer_index)
	var validation := _validate_manual_city_mutation(viewer_index, region_id, expected_owner_revision, before)
	if not bool(validation.get("valid", false)):
		return _city_inference_result(false, false, str(validation.get("reason_code", "city_inference_invalid")), before, before)
	var district_index := int(validation.get("district_index", -1))
	var current := _city_inference_record(viewer_index, district_index)
	if int(current.get("confidence", 0)) == CITY_GUESS_AUTHORIZED_REVEAL:
		return _city_inference_result(false, false, "authorized_reveal_locked", before, before)
	if current.is_empty():
		return _city_inference_result(true, false, "unchanged", before, before)
	var player := (_players[viewer_index] as Dictionary).duplicate(true)
	for field in ["city_guesses", "city_guess_confidence", "city_guess_reasons"]:
		var values: Dictionary = player.get(field, {}) if player.get(field, {}) is Dictionary else {}
		values = values.duplicate(true)
		values.erase(district_index)
		player[field] = values
	_players[viewer_index] = player
	return _commit_city_inference(viewer_index, region_id, before, "city_owner_guess_cleared")


func set_city_guess_confidence(viewer_index: int, region_id: String, confidence: int, expected_owner_revision: String) -> Dictionary:
	var before := city_inference_owner_revision(viewer_index)
	var validation := _validate_manual_city_mutation(viewer_index, region_id, expected_owner_revision, before)
	if not bool(validation.get("valid", false)):
		return _city_inference_result(false, false, str(validation.get("reason_code", "city_inference_invalid")), before, before)
	if confidence not in [CITY_GUESS_CONFIDENCE_LOW, CITY_GUESS_CONFIDENCE_MEDIUM, CITY_GUESS_CONFIDENCE_HIGH]:
		return _city_inference_result(false, false, "city_confidence_invalid", before, before)
	var district_index := int(validation.get("district_index", -1))
	var current := _city_inference_record(viewer_index, district_index)
	if current.is_empty():
		return _city_inference_result(false, false, "city_guess_missing", before, before)
	if int(current.get("confidence", 0)) == CITY_GUESS_AUTHORIZED_REVEAL:
		return _city_inference_result(false, false, "authorized_reveal_locked", before, before)
	if int(current.get("confidence", 0)) == confidence:
		return _city_inference_result(true, false, "unchanged", before, before)
	var player := (_players[viewer_index] as Dictionary).duplicate(true)
	var confidences: Dictionary = (player.get("city_guess_confidence", {}) as Dictionary).duplicate(true)
	confidences[district_index] = confidence
	player["city_guess_confidence"] = confidences
	_players[viewer_index] = player
	return _commit_city_inference(viewer_index, region_id, before, "city_guess_confidence_set")


func set_city_guess_reason(viewer_index: int, region_id: String, reason_id: String, expected_owner_revision: String) -> Dictionary:
	var before := city_inference_owner_revision(viewer_index)
	var validation := _validate_manual_city_mutation(viewer_index, region_id, expected_owner_revision, before)
	if not bool(validation.get("valid", false)):
		return _city_inference_result(false, false, str(validation.get("reason_code", "city_inference_invalid")), before, before)
	if not CITY_GUESS_REASON_IDS.has(reason_id):
		return _city_inference_result(false, false, "city_reason_invalid", before, before)
	var district_index := int(validation.get("district_index", -1))
	var current := _city_inference_record(viewer_index, district_index)
	if current.is_empty():
		return _city_inference_result(false, false, "city_guess_missing", before, before)
	if int(current.get("confidence", 0)) == CITY_GUESS_AUTHORIZED_REVEAL:
		return _city_inference_result(false, false, "authorized_reveal_locked", before, before)
	if str(current.get("reason_id", "")) == reason_id:
		return _city_inference_result(true, false, "unchanged", before, before)
	var player := (_players[viewer_index] as Dictionary).duplicate(true)
	var reasons: Dictionary = (player.get("city_guess_reasons", {}) as Dictionary).duplicate(true)
	reasons[district_index] = reason_id
	player["city_guess_reasons"] = reasons
	_players[viewer_index] = player
	return _commit_city_inference(viewer_index, region_id, before, "city_guess_reason_set")


func apply_authorized_city_reveal(viewer_index: int, region_id: String, owner_index: int, source_reason: String) -> Dictionary:
	var before := city_inference_owner_revision(viewer_index)
	var district_index := district_index_for_region_id(region_id)
	var subject_validation := _validate_foreign_active_city(viewer_index, district_index)
	if not bool(subject_validation.get("valid", false)):
		return _city_inference_result(false, false, str(subject_validation.get("reason_code", "city_subject_invalid")), before, before)
	var normalized_reason := source_reason.strip_edges()
	if normalized_reason.is_empty() or normalized_reason != source_reason or normalized_reason.length() > 96:
		return _city_inference_result(false, false, "authorized_reveal_reason_invalid", before, before)
	if owner_index != int(subject_validation.get("owner_index", -1)):
		return _city_inference_result(false, false, "authorized_reveal_owner_mismatch", before, before)
	var current := _city_inference_record(viewer_index, district_index)
	if int(current.get("suspected_player_index", -1)) == owner_index \
			and int(current.get("confidence", 0)) == CITY_GUESS_AUTHORIZED_REVEAL \
			and str(current.get("reason_id", "")) == normalized_reason:
		return _city_inference_result(true, false, "unchanged", before, before)
	var player := (_players[viewer_index] as Dictionary).duplicate(true)
	var guesses: Dictionary = player.get("city_guesses", {}) if player.get("city_guesses", {}) is Dictionary else {}
	var confidences: Dictionary = player.get("city_guess_confidence", {}) if player.get("city_guess_confidence", {}) is Dictionary else {}
	var reasons: Dictionary = player.get("city_guess_reasons", {}) if player.get("city_guess_reasons", {}) is Dictionary else {}
	guesses = guesses.duplicate(true)
	confidences = confidences.duplicate(true)
	reasons = reasons.duplicate(true)
	guesses[district_index] = owner_index
	confidences[district_index] = CITY_GUESS_AUTHORIZED_REVEAL
	reasons[district_index] = normalized_reason
	player["city_guesses"] = guesses
	player["city_guess_confidence"] = confidences
	player["city_guess_reasons"] = reasons
	_players[viewer_index] = player
	return _commit_city_inference(viewer_index, region_id, before, "authorized_city_reveal_set")


func restore(data: Dictionary, duplicate_collections := true) -> Dictionary:
	var next_players: Array = data.get("players", []) if data.get("players", []) is Array else []
	var next_districts: Array = data.get("districts", []) if data.get("districts", []) is Array else []
	_players = next_players.duplicate(true) if duplicate_collections else next_players
	_districts = next_districts.duplicate(true) if duplicate_collections else next_districts
	_game_time = maxf(0.0, float(data.get("game_time", 0.0)))
	_map_width_m = maxf(1.0, float(data.get("map_width_m", DEFAULT_MAP_WIDTH_M)))
	_map_height_m = maxf(1.0, float(data.get("map_height_m", DEFAULT_MAP_HEIGHT_M)))
	_world_geometry_revision = maxi(0, int(data.get("world_geometry_revision", _world_geometry_revision + 1)))
	var summary := debug_snapshot()
	players_replaced.emit(_players.size())
	districts_replaced.emit(_districts.size())
	game_time_changed.emit(_game_time)
	world_geometry_changed.emit(_map_width_m, _map_height_m, _world_geometry_revision)
	session_restored.emit(summary)
	return summary


func internal_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"players": _players.duplicate(true),
		"districts": _districts.duplicate(true),
		"game_time": _game_time,
		"map_width_m": _map_width_m,
		"map_height_m": _map_height_m,
		"world_geometry_revision": _world_geometry_revision,
	}


func to_save_data() -> Dictionary:
	return internal_snapshot()


func capture_envelope_save_data() -> Dictionary:
	return EnvelopeCodec.capture(internal_snapshot(), _ordered_role_names())


func preflight_envelope_save_data(data: Dictionary) -> Dictionary:
	return EnvelopeCodec.normalize(data, _ordered_role_names())


func apply_envelope_save_data(data: Dictionary) -> Dictionary:
	var normalization := EnvelopeCodec.normalize(data, _ordered_role_names())
	if not bool(normalization.get("accepted", false)):
		return {
			"applied": false,
			"reason_code": str(normalization.get("reason_code", "world_session_envelope_invalid")),
		}
	var runtime_state: Dictionary = normalization.get("runtime_state", {})
	var summary := restore(runtime_state, true)
	return {
		"applied": true,
		"reason_code": "world_session_envelope_restored",
		"summary": summary,
	}


func capture_runtime_checkpoint() -> Dictionary:
	return internal_snapshot()


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if int(checkpoint.get("schema_version", -1)) != 1 \
			or not (checkpoint.get("players", []) is Array) \
			or not (checkpoint.get("districts", []) is Array):
		return {"applied": false, "reason_code": "world_session_checkpoint_invalid"}
	restore(checkpoint, true)
	return {"applied": true, "reason_code": "world_session_checkpoint_restored"}


func apply_save_data(data: Dictionary) -> Dictionary:
	if int(data.get("schema_version", -1)) != 1:
		return {
			"applied": false,
			"reason_code": "world_session_save_invalid",
		}
	var summary := restore(data, true)
	return {
		"applied": true,
		"reason_code": "world_session_restored",
		"summary": summary,
	}


func debug_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"player_count": _players.size(),
		"district_count": _districts.size(),
		"game_time": _game_time,
		"map_width_m": _map_width_m,
		"map_height_m": _map_height_m,
		"world_geometry_revision": _world_geometry_revision,
		"city_inference_mutation_count": _city_inference_mutation_count,
		"city_inference_projection_is_viewer_scoped": true,
		"authorized_reveal_confidence": CITY_GUESS_AUTHORIZED_REVEAL,
		"world_geometry_is_authoritative": true,
		"owns_world_session_state": true,
		"private_payload_exposed": false,
	}


func _validate_manual_city_mutation(viewer_index: int, region_id: String, expected_owner_revision: String, current_revision: String) -> Dictionary:
	if viewer_index < 0 or viewer_index >= _players.size():
		return {"valid": false, "reason_code": "viewer_invalid"}
	if expected_owner_revision.is_empty() or expected_owner_revision != current_revision:
		return {"valid": false, "reason_code": "owner_revision_stale"}
	var district_index := district_index_for_region_id(region_id)
	var subject_validation := _validate_foreign_active_city(viewer_index, district_index)
	if not bool(subject_validation.get("valid", false)):
		return subject_validation
	return {"valid": true, "district_index": district_index}


func _validate_foreign_active_city(viewer_index: int, district_index: int) -> Dictionary:
	if viewer_index < 0 or viewer_index >= _players.size():
		return {"valid": false, "reason_code": "viewer_invalid"}
	if district_index < 0 or district_index >= _districts.size() or not (_districts[district_index] is Dictionary):
		return {"valid": false, "reason_code": "city_subject_missing"}
	var district := _districts[district_index] as Dictionary
	var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
	if bool(district.get("destroyed", false)) or city.is_empty() or not bool(city.get("active", true)):
		return {"valid": false, "reason_code": "city_subject_inactive"}
	var owner_index := int(city.get("owner", -1))
	if owner_index < 0 or owner_index >= _players.size():
		return {"valid": false, "reason_code": "city_owner_invalid"}
	if owner_index == viewer_index:
		return {"valid": false, "reason_code": "own_city_subject"}
	return {"valid": true, "owner_index": owner_index}


func _city_inference_records(viewer_index: int) -> Array:
	var records: Array = []
	if viewer_index < 0 or viewer_index >= _players.size() or not (_players[viewer_index] is Dictionary):
		return records
	var player := _players[viewer_index] as Dictionary
	var guesses: Dictionary = player.get("city_guesses", {}) if player.get("city_guesses", {}) is Dictionary else {}
	var district_indices: Array[int] = []
	for key_variant in guesses.keys():
		var district_index := int(key_variant)
		if district_index >= 0 and district_index < _districts.size() and not district_indices.has(district_index):
			district_indices.append(district_index)
	district_indices.sort()
	for district_index in district_indices:
		var record := _city_inference_record(viewer_index, district_index)
		if not record.is_empty():
			records.append(record)
	return records


func _foreign_active_region_ids(viewer_index: int) -> Array:
	var result: Array[String] = []
	for district_index in range(_districts.size()):
		var validation := _validate_foreign_active_city(viewer_index, district_index)
		if bool(validation.get("valid", false)):
			result.append(_region_id_for_district(district_index))
	return result


func _city_inference_record(viewer_index: int, district_index: int) -> Dictionary:
	if viewer_index < 0 or viewer_index >= _players.size() or not (_players[viewer_index] is Dictionary):
		return {}
	var player := _players[viewer_index] as Dictionary
	var guesses: Dictionary = player.get("city_guesses", {}) if player.get("city_guesses", {}) is Dictionary else {}
	if not guesses.has(district_index) and not guesses.has(str(district_index)):
		return {}
	var suspected_player_index := int(_dictionary_index_value(guesses, district_index, -1))
	var confidences: Dictionary = player.get("city_guess_confidence", {}) if player.get("city_guess_confidence", {}) is Dictionary else {}
	var reasons: Dictionary = player.get("city_guess_reasons", {}) if player.get("city_guess_reasons", {}) is Dictionary else {}
	var confidence := int(_dictionary_index_value(confidences, district_index, CITY_GUESS_CONFIDENCE_MEDIUM))
	var reason_id := str(_dictionary_index_value(reasons, district_index, "intuition"))
	return {
		"district_index": district_index,
		"region_id": _region_id_for_district(district_index),
		"suspected_player_index": suspected_player_index,
		"confidence": confidence,
		"reason_id": reason_id,
		"reason_kind": "public_reveal" if confidence == CITY_GUESS_AUTHORIZED_REVEAL else "manual",
		"authorized_reveal": confidence == CITY_GUESS_AUTHORIZED_REVEAL,
	}


func _commit_city_inference(viewer_index: int, region_id: String, before_revision: String, reason_code: String) -> Dictionary:
	_city_inference_mutation_count += 1
	var after_revision := city_inference_owner_revision(viewer_index)
	city_inference_changed.emit(viewer_index, region_id, after_revision)
	return _city_inference_result(true, true, reason_code, before_revision, after_revision)


func _city_inference_result(applied: bool, changed: bool, reason_code: String, before_revision: String, after_revision: String) -> Dictionary:
	return {
		"applied": applied,
		"changed": changed,
		"reason_code": reason_code,
		"owner_revision_before": before_revision,
		"owner_revision_after": after_revision,
	}


func _dictionary_index_value(values: Dictionary, district_index: int, fallback: Variant) -> Variant:
	if values.has(district_index):
		return values[district_index]
	if values.has(str(district_index)):
		return values[str(district_index)]
	return fallback


func _region_id_for_district(district_index: int) -> String:
	if district_index < 0 or district_index >= _districts.size() or not (_districts[district_index] is Dictionary):
		return ""
	return str((_districts[district_index] as Dictionary).get("region_id", "region.%03d" % district_index))


func _canonical_string_array(value: Variant) -> Array:
	var result: Array[String] = []
	if value is Array:
		for item_variant in value as Array:
			if not (item_variant is String or item_variant is StringName):
				continue
			var item := str(item_variant).strip_edges()
			if not item.is_empty() and not result.has(item):
				result.append(item)
	result.sort()
	return result


func _stable_hash(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(value).to_utf8_buffer())
	return context.finish().hex_encode()


func _ordered_role_names() -> Array[String]:
	var catalog := get_node_or_null(role_catalog_path)
	if catalog == null or not catalog.has_method("ordered_role_names"):
		return []
	var names_variant: Variant = catalog.call("ordered_role_names")
	if not (names_variant is Array):
		return []
	var names: Array[String] = []
	for name_variant in names_variant as Array:
		names.append(str(name_variant))
	return names
