extends RefCounted
class_name TableActionPresentationProjection

var viewer_index := -1
var revision := 0
var authorization_revision := 0
var authorized := false
var availability: Dictionary = {}
var forced_decision: Dictionary = {}
var purchase: Dictionary = {}
var target_choices: Dictionary = {}
var card_track: Dictionary = {}


func to_dictionary() -> Dictionary:
	if not authorized:
		return {
			"schema_version": 1,
			"viewer_index": viewer_index,
			"revision": revision,
			"authorization_revision": authorization_revision,
			"authorized": false,
			"visibility_scope": "denied",
		}
	for value in [availability, forced_decision, purchase, target_choices, card_track]:
		if not TablePresentationPureDataPolicy.is_pure_data(value):
			return {}
	return {
		"schema_version": 1,
		"viewer_index": viewer_index,
		"revision": revision,
		"authorization_revision": authorization_revision,
		"authorized": true,
		"availability": TablePresentationPureDataPolicy.detached_copy(availability),
		"forced_decision": TablePresentationPureDataPolicy.detached_copy(forced_decision),
		"purchase": TablePresentationPureDataPolicy.detached_copy(purchase),
		"target_choices": TablePresentationPureDataPolicy.detached_copy(target_choices),
		"card_track": TablePresentationPureDataPolicy.detached_copy(card_track),
		"visibility_scope": "viewer_private",
	}
