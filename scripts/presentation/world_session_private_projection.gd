extends RefCounted
class_name WorldSessionPrivateProjection

var viewer_index := -1
var subject_index := -1
var authorization_revision := 0
var authorized := false
var player: Dictionary = {}


func to_dictionary() -> Dictionary:
	if authorized and not TablePresentationPureDataPolicy.is_pure_data(player):
		return {}
	return {
		"schema_version": 1,
		"viewer_index": viewer_index,
		"subject_index": subject_index,
		"authorization_revision": authorization_revision,
		"authorized": authorized,
		"player": TablePresentationPureDataPolicy.detached_copy(player) if authorized else {},
		"visibility_scope": "viewer_private" if authorized else "denied",
	}
