extends RefCounted
class_name WorldSessionPublicProjection

var revision := 0
var game_time := 0.0
var players: Array = []
var districts: Array = []


func to_dictionary() -> Dictionary:
	return {
		"schema_version": 1,
		"revision": revision,
		"game_time": game_time,
		"players": players.duplicate(true),
		"districts": districts.duplicate(true),
		"visibility_scope": "public",
	}
