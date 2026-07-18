extends RefCounted
class_name WorldSessionEnvelopeCodec

const SCHEMA_VERSION := 1
const MIN_ACTIVE_PLAYERS := 3
const MAX_ACTIVE_PLAYERS := 8
const MAX_ROLE_INDEX := 23
const PUBLIC_REVEAL_CONFIDENCE := 100
const INT_MAP_TAG := "__world_session_dictionary_entries_v1"
const ROOT_KEYS := [
	"schema_version",
	"players",
	"districts",
	"game_time",
	"map_width_m",
	"map_height_m",
	"world_geometry_revision",
]
const PLAYER_RUNTIME_REQUIRED_KEYS := [
	"id",
	"name",
	"seat_type",
	"is_ai",
	"ai_profile",
	"ai_memory",
	"role_index",
	"role_card",
	"base_starting_cash",
	"role_starting_cash_delta",
	"starting_cash_total",
	"cash",
	"cash_cents",
	"cash_history",
	"v06_transaction_ledger",
	"eliminated",
	"eliminated_at",
	"elimination_reason",
	"economic_ledger",
	"city_guesses",
	"city_guess_confidence",
	"city_guess_reasons",
	"known_contract_parties",
	"cities_built",
	"total_card_spend",
	"card_purchase_count",
	"total_build_spend",
	"total_card_income",
	"total_role_income",
	"total_business_spend",
	"action_cooldown",
	"queued_card_tip",
	"slots",
]
const PLAYER_ENVELOPE_REQUIRED_KEYS := [
	"id",
	"name",
	"seat_type",
	"is_ai",
	"ai_profile",
	"ai_memory",
	"role_index",
	"role_card",
	"base_starting_cash",
	"role_starting_cash_delta",
	"starting_cash_total",
	"cash",
	"cash_cents",
	"cash_history",
	"v06_transaction_ledger",
	"eliminated",
	"eliminated_at",
	"elimination_reason",
	"economic_ledger",
	"city_intel_records",
	"known_contract_parties",
	"cities_built",
	"total_card_spend",
	"card_purchase_count",
	"total_build_spend",
	"total_card_income",
	"total_role_income",
	"total_business_spend",
	"action_cooldown",
	"queued_card_tip",
	"slots",
]
const DISTRICT_REQUIRED_KEYS := [
	"region_id",
	"name",
	"center",
	"polygon",
	"area_m2",
	"radius_m",
	"hp",
	"damage",
	"last_damage_source",
	"last_damage_amount",
	"last_damage_time",
	"destroyed",
	"miasma",
	"terrain",
	"terrain_label",
	"products",
	"demands",
	"neighbors",
	"transport_score",
	"city",
]
const CITY_INTEL_FIELDS := [
	"district_index",
	"suspected_player_index",
	"confidence",
	"reason",
	"reason_kind",
]
const CITY_GUESS_REASONS := [
	"product",
	"route",
	"card",
	"monster",
	"role",
	"intuition",
]


static func capture(runtime_state: Dictionary, ordered_role_names: Array[String] = []) -> Dictionary:
	var root_validation := _validate_runtime_root(runtime_state)
	if not bool(root_validation.get("accepted", false)):
		return root_validation
	var players: Array = runtime_state.get("players", [])
	var districts: Array = runtime_state.get("districts", [])
	var encoded_players: Array = []
	for viewer_index in range(players.size()):
		var player_result := _capture_player(players[viewer_index], viewer_index, players.size(), districts.size(), ordered_role_names)
		if not bool(player_result.get("accepted", false)):
			return player_result
		encoded_players.append((player_result.get("value", {}) as Dictionary).duplicate(true))
	var encoded_districts: Array = []
	for district_index in range(districts.size()):
		var district_result := _capture_district(districts[district_index], district_index, players.size(), districts.size())
		if not bool(district_result.get("accepted", false)):
			return district_result
		encoded_districts.append((district_result.get("value", {}) as Dictionary).duplicate(true))
	return {
		"accepted": true,
		"reason_code": "world_session_envelope_ready",
		"normalized_state": {
			"schema_version": SCHEMA_VERSION,
			"players": encoded_players,
			"districts": encoded_districts,
			"game_time": float(runtime_state.get("game_time", 0.0)),
			"map_width_m": float(runtime_state.get("map_width_m", 0.0)),
			"map_height_m": float(runtime_state.get("map_height_m", 0.0)),
			"world_geometry_revision": int(runtime_state.get("world_geometry_revision", 0)),
		},
	}


static func normalize(candidate: Dictionary, ordered_role_names: Array[String] = []) -> Dictionary:
	if not _has_exact_keys(candidate, ROOT_KEYS) or int(candidate.get("schema_version", -1)) != SCHEMA_VERSION:
		return _rejection("world_session_schema_invalid")
	if not (candidate.get("players") is Array) or not (candidate.get("districts") is Array):
		return _rejection("world_session_collections_invalid")
	var players: Array = candidate.get("players", [])
	var districts: Array = candidate.get("districts", [])
	if not _valid_player_count(players.size()) or (players.is_empty() and not districts.is_empty()):
		return _rejection("world_session_player_count_invalid")
	if not players.is_empty() and ordered_role_names.size() != 24:
		return _rejection("world_session_role_catalog_unavailable")
	if not _nonnegative_finite(candidate.get("game_time")) \
			or not _positive_finite(candidate.get("map_width_m")) \
			or not _positive_finite(candidate.get("map_height_m")) \
			or not (candidate.get("world_geometry_revision") is int) \
			or int(candidate.get("world_geometry_revision", -1)) < 0:
		return _rejection("world_session_geometry_invalid")
	var runtime_players: Array = []
	var normalized_players: Array = []
	var role_indices: Dictionary = {}
	for viewer_index in range(players.size()):
		var player_result := _normalize_player(players[viewer_index], viewer_index, players.size(), districts.size(), ordered_role_names)
		if not bool(player_result.get("accepted", false)):
			return player_result
		var runtime_player: Dictionary = player_result.get("runtime_value", {})
		var role_index := int(runtime_player.get("role_index", -1))
		if role_indices.has(role_index):
			return _rejection("world_session_duplicate_role_index")
		role_indices[role_index] = true
		runtime_players.append(runtime_player.duplicate(true))
		normalized_players.append((player_result.get("normalized_value", {}) as Dictionary).duplicate(true))
	var runtime_districts: Array = []
	var normalized_districts: Array = []
	var region_ids: Dictionary = {}
	for district_index in range(districts.size()):
		var district_result := _normalize_district(districts[district_index], district_index, players.size(), districts.size())
		if not bool(district_result.get("accepted", false)):
			return district_result
		var runtime_district: Dictionary = district_result.get("runtime_value", {})
		var region_id := str(runtime_district.get("region_id", ""))
		if region_ids.has(region_id):
			return _rejection("world_session_duplicate_region_id")
		region_ids[region_id] = true
		runtime_districts.append(runtime_district.duplicate(true))
		normalized_districts.append((district_result.get("normalized_value", {}) as Dictionary).duplicate(true))
	var normalized := {
		"schema_version": SCHEMA_VERSION,
		"players": normalized_players,
		"districts": normalized_districts,
		"game_time": float(candidate.get("game_time", 0.0)),
		"map_width_m": float(candidate.get("map_width_m", 0.0)),
		"map_height_m": float(candidate.get("map_height_m", 0.0)),
		"world_geometry_revision": int(candidate.get("world_geometry_revision", 0)),
	}
	return {
		"accepted": true,
		"reason_code": "world_session_envelope_valid",
		"normalized_state": normalized,
		"runtime_state": {
			"schema_version": 1,
			"players": runtime_players,
			"districts": runtime_districts,
			"game_time": normalized.game_time,
			"map_width_m": normalized.map_width_m,
			"map_height_m": normalized.map_height_m,
			"world_geometry_revision": normalized.world_geometry_revision,
		},
	}


static func empty_state() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"players": [],
		"districts": [],
		"game_time": 0.0,
		"map_width_m": WorldSessionState.DEFAULT_MAP_WIDTH_M,
		"map_height_m": WorldSessionState.DEFAULT_MAP_HEIGHT_M,
		"world_geometry_revision": 0,
	}


static func _validate_runtime_root(runtime_state: Dictionary) -> Dictionary:
	if not _has_exact_keys(runtime_state, ROOT_KEYS) \
			or not (runtime_state.get("schema_version") is int) \
			or int(runtime_state.get("schema_version")) != 1 \
			or not (runtime_state.get("players") is Array) \
			or not (runtime_state.get("districts") is Array):
		return _rejection("world_session_runtime_shape_invalid")
	var players: Array = runtime_state.get("players", [])
	var districts: Array = runtime_state.get("districts", [])
	if not _valid_player_count(players.size()) or (players.is_empty() and not districts.is_empty()):
		return _rejection("world_session_player_count_invalid")
	if not _nonnegative_finite(runtime_state.get("game_time")) \
			or not _positive_finite(runtime_state.get("map_width_m")) \
			or not _positive_finite(runtime_state.get("map_height_m")) \
			or not (runtime_state.get("world_geometry_revision") is int) \
			or int(runtime_state.get("world_geometry_revision", -1)) < 0:
		return _rejection("world_session_geometry_invalid")
	return {"accepted": true}


static func _capture_player(value: Variant, viewer_index: int, player_count: int, district_count: int, ordered_role_names: Array[String]) -> Dictionary:
	if not (value is Dictionary):
		return _rejection("world_session_player_invalid")
	var player := (value as Dictionary).duplicate(true)
	if not _has_required_keys(player, PLAYER_RUNTIME_REQUIRED_KEYS):
		return _rejection("world_session_player_field_missing")
	var identity_validation := _validate_player_identity(player, viewer_index, ordered_role_names)
	if not bool(identity_validation.get("accepted", false)):
		return identity_validation
	var shape_validation := _validate_player_shape(player, false)
	if not bool(shape_validation.get("accepted", false)):
		return shape_validation
	var intel_result := _capture_city_intel(player, viewer_index, player_count, district_count)
	if not bool(intel_result.get("accepted", false)):
		return intel_result
	player.erase("city_guesses")
	player.erase("city_guess_confidence")
	player.erase("city_guess_reasons")
	player["city_intel_records"] = (intel_result.get("records", []) as Array).duplicate(true)
	var encoded := _encode_data(player)
	if not bool(encoded.get("accepted", false)) or not (encoded.get("value") is Dictionary):
		return _rejection("world_session_player_not_data_only")
	return {"accepted": true, "value": (encoded.get("value") as Dictionary).duplicate(true)}


static func _normalize_player(value: Variant, viewer_index: int, player_count: int, district_count: int, ordered_role_names: Array[String]) -> Dictionary:
	if not (value is Dictionary):
		return _rejection("world_session_player_invalid")
	var decoded := _decode_data(value)
	if not bool(decoded.get("accepted", false)) or not (decoded.get("value") is Dictionary):
		return _rejection("world_session_player_not_data_only")
	var player := (decoded.get("value") as Dictionary).duplicate(true)
	if not _has_required_keys(player, PLAYER_ENVELOPE_REQUIRED_KEYS):
		return _rejection("world_session_player_field_missing")
	var identity_validation := _validate_player_identity(player, viewer_index, ordered_role_names)
	if not bool(identity_validation.get("accepted", false)):
		return identity_validation
	var shape_validation := _validate_player_shape(player, true)
	if not bool(shape_validation.get("accepted", false)):
		return shape_validation
	if not (player.get("city_intel_records") is Array):
		return _rejection("world_session_city_intel_invalid")
	var intel_result := _normalize_city_intel(player.get("city_intel_records", []), viewer_index, player_count, district_count)
	if not bool(intel_result.get("accepted", false)):
		return intel_result
	player.erase("city_intel_records")
	player["city_guesses"] = (intel_result.get("guesses", {}) as Dictionary).duplicate(true)
	player["city_guess_confidence"] = (intel_result.get("confidence", {}) as Dictionary).duplicate(true)
	player["city_guess_reasons"] = (intel_result.get("reasons", {}) as Dictionary).duplicate(true)
	var recaptured := _capture_player(player, viewer_index, player_count, district_count, ordered_role_names)
	if not bool(recaptured.get("accepted", false)):
		return recaptured
	return {
		"accepted": true,
		"runtime_value": player,
		"normalized_value": (recaptured.get("value") as Dictionary).duplicate(true),
	}


static func _validate_player_identity(player: Dictionary, viewer_index: int, ordered_role_names: Array[String]) -> Dictionary:
	for required in ["id", "name", "seat_type", "is_ai", "role_index", "role_card"]:
		if not player.has(required):
			return _rejection("world_session_player_field_missing")
	if not (player.get("id") is int) or int(player.get("id", -1)) != viewer_index:
		return _rejection("world_session_player_id_invalid")
	if not (player.get("name") is String) or str(player.get("name", "")).strip_edges().is_empty():
		return _rejection("world_session_player_name_invalid")
	if not (player.get("seat_type") is String) or str(player.get("seat_type", "")) not in ["human", "ai"] \
			or not (player.get("is_ai") is bool) \
			or bool(player.get("is_ai", false)) != (str(player.get("seat_type", "")) == "ai"):
		return _rejection("world_session_player_seat_invalid")
	if not (player.get("role_index") is int):
		return _rejection("world_session_role_invalid")
	var role_index := int(player.get("role_index", -1))
	var role_card: Dictionary = player.get("role_card", {}) if player.get("role_card", {}) is Dictionary else {}
	if role_index < 0 or role_index > MAX_ROLE_INDEX \
			or int(role_card.get("role_index", -1)) != role_index \
			or ordered_role_names.size() <= role_index \
			or str(role_card.get("name", "")) != ordered_role_names[role_index]:
		return _rejection("world_session_role_invalid")
	return {"accepted": true}


static func _validate_player_shape(player: Dictionary, envelope_shape: bool) -> Dictionary:
	for field in ["ai_profile", "ai_memory", "role_card", "known_contract_parties"]:
		if not (player.get(field) is Dictionary):
			return _rejection("world_session_player_field_type_invalid")
	for field in ["cash_history", "v06_transaction_ledger", "economic_ledger", "slots"]:
		if not (player.get(field) is Array):
			return _rejection("world_session_player_field_type_invalid")
	for field in [
		"base_starting_cash",
		"role_starting_cash_delta",
		"starting_cash_total",
		"cash",
		"cash_cents",
		"cities_built",
		"total_card_spend",
		"card_purchase_count",
		"total_build_spend",
		"total_card_income",
		"total_role_income",
		"total_business_spend",
		"queued_card_tip",
	]:
		if not (player.get(field) is int):
			return _rejection("world_session_player_field_type_invalid")
	if not (player.get("eliminated") is bool) \
			or not (player.get("elimination_reason") is String) \
			or not _finite_number(player.get("eliminated_at")) \
			or not _nonnegative_finite(player.get("action_cooldown")):
		return _rejection("world_session_player_field_type_invalid")
	if envelope_shape:
		if not (player.get("city_intel_records") is Array):
			return _rejection("world_session_player_field_type_invalid")
	else:
		for field in ["city_guesses", "city_guess_confidence", "city_guess_reasons"]:
			if not (player.get(field) is Dictionary):
				return _rejection("world_session_player_field_type_invalid")
	return {"accepted": true}


static func _capture_city_intel(player: Dictionary, viewer_index: int, player_count: int, district_count: int) -> Dictionary:
	var guesses: Dictionary = player.get("city_guesses", {}) if player.get("city_guesses", {}) is Dictionary else {}
	var confidence: Dictionary = player.get("city_guess_confidence", {}) if player.get("city_guess_confidence", {}) is Dictionary else {}
	var reasons: Dictionary = player.get("city_guess_reasons", {}) if player.get("city_guess_reasons", {}) is Dictionary else {}
	var guess_keys := _canonical_district_keys(guesses)
	var confidence_keys := _canonical_district_keys(confidence)
	var reason_keys := _canonical_district_keys(reasons)
	if not bool(guess_keys.get("accepted", false)) \
			or not bool(confidence_keys.get("accepted", false)) \
			or not bool(reason_keys.get("accepted", false)):
		return _rejection("world_session_city_intel_key_invalid")
	var keys: Array = guess_keys.get("keys", [])
	if keys != confidence_keys.get("keys", []) or keys != reason_keys.get("keys", []):
		return _rejection("world_session_city_intel_key_mismatch")
	var records: Array = []
	for district_index_variant in keys:
		var district_index := int(district_index_variant)
		var guessed_player := int(_dictionary_value_for_district(guesses, district_index, -1))
		var confidence_value := int(_dictionary_value_for_district(confidence, district_index, 0))
		var reason := str(_dictionary_value_for_district(reasons, district_index, ""))
		var record_validation := _validate_city_intel_record(district_index, guessed_player, confidence_value, reason, viewer_index, player_count, district_count)
		if not bool(record_validation.get("accepted", false)):
			return record_validation
		records.append({
			"district_index": district_index,
			"suspected_player_index": guessed_player,
			"confidence": confidence_value,
			"reason": reason,
			"reason_kind": "public_reveal" if confidence_value == PUBLIC_REVEAL_CONFIDENCE else "player_note",
		})
	return {"accepted": true, "records": records}


static func _normalize_city_intel(value: Variant, viewer_index: int, player_count: int, district_count: int) -> Dictionary:
	if not (value is Array):
		return _rejection("world_session_city_intel_invalid")
	var guesses: Dictionary = {}
	var confidence: Dictionary = {}
	var reasons: Dictionary = {}
	var previous_district := -1
	for record_variant in value as Array:
		if not (record_variant is Dictionary) or not _has_exact_keys(record_variant as Dictionary, CITY_INTEL_FIELDS):
			return _rejection("world_session_city_intel_record_invalid")
		var record := record_variant as Dictionary
		if not (record.get("district_index") is int) \
				or not (record.get("suspected_player_index") is int) \
				or not (record.get("confidence") is int) \
				or not (record.get("reason") is String) \
				or not (record.get("reason_kind") is String):
			return _rejection("world_session_city_intel_record_invalid")
		var district_index := int(record.get("district_index", -1))
		var guessed_player := int(record.get("suspected_player_index", -1))
		var confidence_value := int(record.get("confidence", 0))
		var reason := str(record.get("reason", ""))
		var expected_kind := "public_reveal" if confidence_value == PUBLIC_REVEAL_CONFIDENCE else "player_note"
		if str(record.get("reason_kind", "")) != expected_kind or district_index <= previous_district:
			return _rejection("world_session_city_intel_order_invalid")
		var validation := _validate_city_intel_record(district_index, guessed_player, confidence_value, reason, viewer_index, player_count, district_count)
		if not bool(validation.get("accepted", false)):
			return validation
		guesses[district_index] = guessed_player
		confidence[district_index] = confidence_value
		reasons[district_index] = reason
		previous_district = district_index
	return {"accepted": true, "guesses": guesses, "confidence": confidence, "reasons": reasons}


static func _validate_city_intel_record(district_index: int, guessed_player: int, confidence: int, reason: String, viewer_index: int, player_count: int, district_count: int) -> Dictionary:
	if district_index < 0 or district_index >= district_count \
			or guessed_player < 0 or guessed_player >= player_count \
			or guessed_player == viewer_index:
		return _rejection("world_session_city_intel_binding_invalid")
	if confidence == PUBLIC_REVEAL_CONFIDENCE:
		if reason.strip_edges().is_empty() or reason.length() > 96:
			return _rejection("world_session_city_intel_reveal_reason_invalid")
	elif confidence not in [1, 2, 3] or reason not in CITY_GUESS_REASONS:
		return _rejection("world_session_city_intel_value_invalid")
	return {"accepted": true}


static func _capture_district(value: Variant, district_index: int, player_count: int, district_count: int) -> Dictionary:
	if not (value is Dictionary):
		return _rejection("world_session_district_invalid")
	var district := (value as Dictionary).duplicate(true)
	if not _has_required_keys(district, DISTRICT_REQUIRED_KEYS):
		return _rejection("world_session_district_field_missing")
	var validation := _validate_district_identity(district, district_index, player_count, district_count)
	if not bool(validation.get("accepted", false)):
		return validation
	var encoded := _encode_data(district)
	if not bool(encoded.get("accepted", false)) or not (encoded.get("value") is Dictionary):
		return _rejection("world_session_district_not_data_only")
	return {"accepted": true, "value": (encoded.get("value") as Dictionary).duplicate(true)}


static func _normalize_district(value: Variant, district_index: int, player_count: int, district_count: int) -> Dictionary:
	if not (value is Dictionary):
		return _rejection("world_session_district_invalid")
	var decoded := _decode_data(value)
	if not bool(decoded.get("accepted", false)) or not (decoded.get("value") is Dictionary):
		return _rejection("world_session_district_not_data_only")
	var district := (decoded.get("value") as Dictionary).duplicate(true)
	if not _has_required_keys(district, DISTRICT_REQUIRED_KEYS):
		return _rejection("world_session_district_field_missing")
	var validation := _validate_district_identity(district, district_index, player_count, district_count)
	if not bool(validation.get("accepted", false)):
		return validation
	var recaptured := _capture_district(district, district_index, player_count, district_count)
	if not bool(recaptured.get("accepted", false)):
		return recaptured
	return {
		"accepted": true,
		"runtime_value": district,
		"normalized_value": (recaptured.get("value") as Dictionary).duplicate(true),
	}


static func _validate_district_identity(district: Dictionary, district_index: int, player_count: int, district_count: int) -> Dictionary:
	if str(district.get("region_id", "")) != "region.%03d" % district_index \
			or str(district.get("name", "")).strip_edges().is_empty() \
			or not (district.get("center") is Vector2) \
			or not _finite_vector2(district.get("center")) \
			or not (district.get("polygon") is Array) \
			or (district.get("polygon") as Array).size() < 3:
		return _rejection("world_session_district_identity_invalid")
	for point_variant in district.get("polygon", []) as Array:
		if not (point_variant is Vector2) or not _finite_vector2(point_variant):
			return _rejection("world_session_district_polygon_invalid")
	if not _positive_finite(district.get("area_m2")) \
			or not _positive_finite(district.get("radius_m")) \
			or not _nonnegative_finite(district.get("hp")) \
			or not _nonnegative_finite(district.get("damage")) \
			or not (district.get("last_damage_source") is String) \
			or not _nonnegative_finite(district.get("last_damage_amount")) \
			or not _finite_number(district.get("last_damage_time")) \
			or not (district.get("destroyed") is bool) \
			or not (district.get("miasma") is bool) \
			or not (district.get("terrain") is String) \
			or not (district.get("terrain_label") is String) \
			or not (district.get("products") is Array) \
			or not (district.get("demands") is Array) \
			or not _positive_finite(district.get("transport_score")):
		return _rejection("world_session_district_field_type_invalid")
	if not (district.get("neighbors") is Array):
		return _rejection("world_session_district_neighbors_invalid")
	var neighbors: Dictionary = {}
	for neighbor_variant in district.get("neighbors", []) as Array:
		if not (neighbor_variant is int):
			return _rejection("world_session_district_neighbors_invalid")
		var neighbor := int(neighbor_variant)
		if neighbor < 0 or neighbor >= district_count or neighbor == district_index or neighbors.has(neighbor):
			return _rejection("world_session_district_neighbors_invalid")
		neighbors[neighbor] = true
	if not (district.get("city") is Dictionary):
		return _rejection("world_session_city_invalid")
	var city: Dictionary = district.get("city", {})
	if not city.is_empty() and city.has("owner"):
		if not (city.get("owner") is int) or int(city.get("owner", -1)) < 0 or int(city.get("owner", -1)) >= player_count:
			return _rejection("world_session_city_owner_invalid")
	return {"accepted": true}


static func _encode_data(value: Variant) -> Dictionary:
	if value == null or value is bool or value is int or value is String:
		return {"accepted": true, "value": value}
	if value is StringName:
		return {"accepted": true, "value": str(value)}
	if value is float:
		return {"accepted": is_finite(value), "value": value, "reason_code": "world_session_float_invalid"}
	if value is Vector2:
		return {"accepted": _finite_vector2(value), "value": value, "reason_code": "world_session_vector_invalid"}
	if value is Color:
		var color := value as Color
		var valid := is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a)
		return {"accepted": valid, "value": value, "reason_code": "world_session_color_invalid"}
	if value is Array:
		var result: Array = []
		for item in value as Array:
			var encoded := _encode_data(item)
			if not bool(encoded.get("accepted", false)):
				return encoded
			result.append(encoded.get("value"))
		return {"accepted": true, "value": result}
	if value is Dictionary:
		var dictionary := value as Dictionary
		if dictionary.has(INT_MAP_TAG):
			return _rejection("world_session_reserved_key_collision")
		var all_string_keys := true
		for key_variant in dictionary.keys():
			if not (key_variant is String or key_variant is StringName):
				all_string_keys = false
				break
		if all_string_keys:
			var result: Dictionary = {}
			for key_variant in dictionary.keys():
				var encoded := _encode_data(dictionary[key_variant])
				if not bool(encoded.get("accepted", false)):
					return encoded
				result[str(key_variant)] = encoded.get("value")
			return {"accepted": true, "value": result}
		var entries: Array = []
		for key_variant in dictionary.keys():
			var key_kind := ""
			var key_value: Variant
			if key_variant is int:
				key_kind = "int"
				key_value = int(key_variant)
			elif key_variant is String or key_variant is StringName:
				key_kind = "string"
				key_value = str(key_variant)
			else:
				return _rejection("world_session_dictionary_key_invalid")
			var encoded := _encode_data(dictionary[key_variant])
			if not bool(encoded.get("accepted", false)):
				return encoded
			entries.append({"key_kind": key_kind, "key": key_value, "value": encoded.get("value")})
		entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return "%s:%s" % [left.key_kind, str(left.key)] < "%s:%s" % [right.key_kind, str(right.key)]
		)
		return {"accepted": true, "value": {INT_MAP_TAG: entries}}
	return _rejection("world_session_variant_type_forbidden")


static func _decode_data(value: Variant) -> Dictionary:
	if value == null or value is bool or value is int or value is String:
		return {"accepted": true, "value": value}
	if value is float:
		return {"accepted": is_finite(value), "value": value, "reason_code": "world_session_float_invalid"}
	if value is Vector2:
		return {"accepted": _finite_vector2(value), "value": value, "reason_code": "world_session_vector_invalid"}
	if value is Color:
		var color := value as Color
		var valid := is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a)
		return {"accepted": valid, "value": value, "reason_code": "world_session_color_invalid"}
	if value is Array:
		var result: Array = []
		for item in value as Array:
			var decoded := _decode_data(item)
			if not bool(decoded.get("accepted", false)):
				return decoded
			result.append(decoded.get("value"))
		return {"accepted": true, "value": result}
	if value is Dictionary:
		var dictionary := value as Dictionary
		if dictionary.has(INT_MAP_TAG):
			if dictionary.keys().size() != 1 or not (dictionary.get(INT_MAP_TAG) is Array):
				return _rejection("world_session_encoded_dictionary_invalid")
			var result: Dictionary = {}
			for entry_variant in dictionary.get(INT_MAP_TAG, []) as Array:
				if not (entry_variant is Dictionary) or not _has_exact_keys(entry_variant as Dictionary, ["key_kind", "key", "value"]):
					return _rejection("world_session_encoded_dictionary_invalid")
				var entry := entry_variant as Dictionary
				var key: Variant
				match str(entry.get("key_kind", "")):
					"int":
						if not (entry.get("key") is int):
							return _rejection("world_session_encoded_dictionary_key_invalid")
						key = int(entry.get("key"))
					"string":
						if not (entry.get("key") is String):
							return _rejection("world_session_encoded_dictionary_key_invalid")
						key = str(entry.get("key"))
					_:
						return _rejection("world_session_encoded_dictionary_key_invalid")
				if result.has(key):
					return _rejection("world_session_encoded_dictionary_duplicate")
				var decoded := _decode_data(entry.get("value"))
				if not bool(decoded.get("accepted", false)):
					return decoded
				result[key] = decoded.get("value")
			return {"accepted": true, "value": result}
		var result: Dictionary = {}
		for key_variant in dictionary.keys():
			if not (key_variant is String or key_variant is StringName):
				return _rejection("world_session_dictionary_key_invalid")
			var decoded := _decode_data(dictionary[key_variant])
			if not bool(decoded.get("accepted", false)):
				return decoded
			result[str(key_variant)] = decoded.get("value")
		return {"accepted": true, "value": result}
	return _rejection("world_session_variant_type_forbidden")


static func _canonical_district_keys(dictionary: Dictionary) -> Dictionary:
	var keys: Array[int] = []
	for key_variant in dictionary.keys():
		var key := -1
		if key_variant is int:
			key = int(key_variant)
		elif key_variant is String and str(key_variant).is_valid_int() and str(int(str(key_variant))) == str(key_variant):
			key = int(str(key_variant))
		else:
			return _rejection("world_session_city_intel_key_invalid")
		if key < 0 or keys.has(key):
			return _rejection("world_session_city_intel_key_invalid")
		keys.append(key)
	keys.sort()
	return {"accepted": true, "keys": keys}


static func _dictionary_value_for_district(dictionary: Dictionary, district_index: int, fallback: Variant) -> Variant:
	if dictionary.has(district_index):
		return dictionary[district_index]
	var string_key := str(district_index)
	return dictionary.get(string_key, fallback)


static func _valid_player_count(count: int) -> bool:
	return count == 0 or (count >= MIN_ACTIVE_PLAYERS and count <= MAX_ACTIVE_PLAYERS)


static func _nonnegative_finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0


static func _positive_finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _finite_vector2(value: Variant) -> bool:
	return value is Vector2 and is_finite((value as Vector2).x) and is_finite((value as Vector2).y)


static func _has_exact_keys(dictionary: Dictionary, keys: Array) -> bool:
	if dictionary.keys().size() != keys.size():
		return false
	for key_variant in keys:
		if not dictionary.has(str(key_variant)):
			return false
	return true


static func _has_required_keys(dictionary: Dictionary, keys: Array) -> bool:
	for key_variant in keys:
		if not dictionary.has(str(key_variant)):
			return false
	return true


static func _rejection(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code}
