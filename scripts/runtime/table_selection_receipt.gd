extends RefCounted
class_name TableSelectionReceipt

var request_id := ""
var accepted := false
var reason_code := ""
var selection_kind: StringName = TableSelectionIntent.KIND_MAP_LAYER
var viewer_index := -1
var authorization_revision := 0
var session_revision := 0
var map_layer_id: StringName = &""
var effective_map_layer_id: StringName = &"all"
var previous_inspected_player_index := -1
var inspected_player_index := -1
var changed := false
var applied := false
var selection_revision_before := -1
var selection_revision_after := -1
var presentation_refresh_requested := false
var idempotent_replay := false
var request_id_collision := false
var gameplay_mutation_delta := 0
var presentation_refresh_mask: Array[StringName] = []


func to_dictionary() -> Dictionary:
	return {
		"request_id": request_id,
		"accepted": accepted,
		"reason_code": reason_code,
		"selection_kind": selection_kind,
		"viewer_index": viewer_index,
		"authorization_revision": authorization_revision,
		"session_revision": session_revision,
		"map_layer_id": map_layer_id,
		"effective_map_layer_id": effective_map_layer_id,
		"previous_inspected_player_index": previous_inspected_player_index,
		"inspected_player_index": inspected_player_index,
		"changed": changed,
		"applied": applied,
		"selection_revision_before": selection_revision_before,
		"selection_revision_after": selection_revision_after,
		"presentation_refresh_requested": presentation_refresh_requested,
		"idempotent_replay": idempotent_replay,
		"request_id_collision": request_id_collision,
		"gameplay_mutation_delta": gameplay_mutation_delta,
		"presentation_refresh_mask": presentation_refresh_mask.duplicate(),
	}
