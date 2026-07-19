extends RefCounted
class_name TableSelectionReceipt

var request_id := ""
var accepted := false
var reason_code := ""
var selection_kind: StringName = &""
var viewer_index := -1
var map_layer_id: StringName = &""
var effective_map_layer_id: StringName = &"all"
var changed := false
var selection_revision_before := -1
var selection_revision_after := -1
var presentation_refresh_requested := false
var idempotent_replay := false
var request_id_collision := false
var gameplay_mutation_delta := 0


func to_dictionary() -> Dictionary:
	return {
		"request_id": request_id,
		"accepted": accepted,
		"reason_code": reason_code,
		"selection_kind": selection_kind,
		"viewer_index": viewer_index,
		"map_layer_id": map_layer_id,
		"effective_map_layer_id": effective_map_layer_id,
		"changed": changed,
		"selection_revision_before": selection_revision_before,
		"selection_revision_after": selection_revision_after,
		"presentation_refresh_requested": presentation_refresh_requested,
		"idempotent_replay": idempotent_replay,
		"request_id_collision": request_id_collision,
		"gameplay_mutation_delta": gameplay_mutation_delta,
	}
