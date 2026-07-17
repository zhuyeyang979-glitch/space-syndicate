extends RefCounted
class_name TableActionPresentationProjection

var viewer_index := -1
var revision := 0
var availability: Dictionary = {}
var forced_decision: Dictionary = {}
var purchase: Dictionary = {}
var target_choices: Dictionary = {}
var card_track: Dictionary = {}


func to_dictionary() -> Dictionary:
	return {
		"schema_version": 1,
		"viewer_index": viewer_index,
		"revision": revision,
		"availability": availability.duplicate(true),
		"forced_decision": forced_decision.duplicate(true),
		"purchase": purchase.duplicate(true),
		"target_choices": target_choices.duplicate(true),
		"card_track": card_track.duplicate(true),
		"visibility_scope": "viewer_private" if viewer_index >= 0 else "public",
	}
