@tool
extends Node
class_name WorldSessionState

signal players_replaced(player_count: int)
signal districts_replaced(district_count: int)
signal game_time_changed(game_time: float)
signal world_geometry_changed(width_m: float, height_m: float, revision: int)
signal session_restored(summary: Dictionary)

const DEFAULT_MAP_WIDTH_M := 1400.0
const DEFAULT_MAP_HEIGHT_M := 950.0

var _players: Array = []
var _districts: Array = []
var _game_time := 0.0
var _map_width_m := DEFAULT_MAP_WIDTH_M
var _map_height_m := DEFAULT_MAP_HEIGHT_M
var _world_geometry_revision := 0

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
		"world_geometry_is_authoritative": true,
		"owns_world_session_state": true,
		"private_payload_exposed": false,
	}
