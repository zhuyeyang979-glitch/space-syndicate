extends RefCounted
class_name TablePresentationViewerContext

var viewer_index := -1
var authorization_revision := 0
var authorized := false


static func denied(revision: int = 0) -> TablePresentationViewerContext:
	var context := TablePresentationViewerContext.new()
	context.authorization_revision = maxi(0, revision)
	return context


static func granted(player_index: int, revision: int) -> TablePresentationViewerContext:
	var context := TablePresentationViewerContext.new()
	context.viewer_index = player_index
	context.authorization_revision = maxi(0, revision)
	context.authorized = player_index >= 0
	return context


func can_view_subject(subject_index: int) -> bool:
	return authorized and subject_index >= 0 and subject_index == viewer_index


func to_dictionary() -> Dictionary:
	return {
		"viewer_index": viewer_index,
		"authorization_revision": authorization_revision,
		"authorized": authorized,
		"visibility_scope": "viewer_private" if authorized else "public",
	}
