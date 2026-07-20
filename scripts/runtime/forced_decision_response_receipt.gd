extends RefCounted
class_name ForcedDecisionResponseReceipt

const SCHEMA_VERSION := 1

var schema_version := SCHEMA_VERSION
var request_id := ""
var decision_id := ""
var decision_kind: StringName = &""
var decision_revision := 0
var option_id := ""
var viewer_index := -1
var accepted := false
var emitted := false
var idempotent_replay := false
var request_id_collision := false
var reason_code := ""
var gameplay_mutation_delta := 0


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"request_id": request_id,
		"decision_id": decision_id,
		"decision_kind": decision_kind,
		"decision_revision": decision_revision,
		"option_id": option_id,
		"viewer_index": viewer_index,
		"accepted": accepted,
		"emitted": emitted,
		"idempotent_replay": idempotent_replay,
		"request_id_collision": request_id_collision,
		"reason_code": reason_code,
		"gameplay_mutation_delta": gameplay_mutation_delta,
	}
