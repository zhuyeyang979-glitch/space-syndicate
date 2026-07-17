extends RefCounted
class_name WorldSessionPublicProjection

var revision := 0
var game_time := 0.0
var players: Array = []
var districts: Array = []


func to_dictionary() -> Dictionary:
	if not TablePresentationPureDataPolicy.is_pure_data(players) \
		or not TablePresentationPureDataPolicy.is_pure_data(districts):
		return {}
	return {
		"schema_version": 1,
		"revision": revision,
		"game_time": game_time,
		"players": TablePresentationPureDataPolicy.detached_copy(players),
		"districts": TablePresentationPureDataPolicy.detached_copy(districts),
		"visibility_scope": "public",
	}
