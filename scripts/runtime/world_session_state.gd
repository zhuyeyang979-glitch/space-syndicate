@tool
extends Node
class_name WorldSessionState

signal players_replaced(player_count: int)
signal districts_replaced(district_count: int)
signal game_time_changed(game_time: float)
signal session_restored(summary: Dictionary)

var _players: Array = []
var _districts: Array = []
var _game_time := 0.0

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


func reset() -> Dictionary:
	_players = []
	_districts = []
	_game_time = 0.0
	var summary := debug_snapshot()
	players_replaced.emit(0)
	districts_replaced.emit(0)
	game_time_changed.emit(0.0)
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


func restore(data: Dictionary, duplicate_collections := true) -> Dictionary:
	var next_players: Array = data.get("players", []) if data.get("players", []) is Array else []
	var next_districts: Array = data.get("districts", []) if data.get("districts", []) is Array else []
	_players = next_players.duplicate(true) if duplicate_collections else next_players
	_districts = next_districts.duplicate(true) if duplicate_collections else next_districts
	_game_time = maxf(0.0, float(data.get("game_time", 0.0)))
	var summary := debug_snapshot()
	players_replaced.emit(_players.size())
	districts_replaced.emit(_districts.size())
	game_time_changed.emit(_game_time)
	session_restored.emit(summary)
	return summary


func internal_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"players": _players.duplicate(true),
		"districts": _districts.duplicate(true),
		"game_time": _game_time,
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
		"owns_world_session_state": true,
		"private_payload_exposed": false,
	}
