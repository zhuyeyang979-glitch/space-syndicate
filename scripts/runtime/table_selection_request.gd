extends PlayerIdentityActionRequest
class_name TableSelectionRequest

var selection_kind: StringName = &""
var expected_selection_revision := -1
var map_layer_id: StringName = &""
var target_player_index := -1


func validation_report() -> Dictionary:
	var identity_validation := super.validation_report()
	if not bool(identity_validation.get("valid", false)):
		return identity_validation
	if selection_kind not in [TableSelectionIntent.KIND_MAP_LAYER, TableSelectionIntent.KIND_INSPECT_PLAYER]:
		return _invalid("selection_kind_invalid")
	if expected_selection_revision < 0:
		return _invalid("selection_revision_invalid")
	if selection_kind == TableSelectionIntent.KIND_MAP_LAYER:
		if not TableSelectionIntent.MAP_LAYER_IDS.has(map_layer_id):
			return _invalid("map_layer_invalid")
	elif target_player_index < 0:
		return _invalid("target_player_invalid")
	return {"valid": true, "reason_code": ""}


func to_dictionary() -> Dictionary:
	var result := super.to_dictionary()
	result["selection_kind"] = selection_kind
	result["expected_selection_revision"] = expected_selection_revision
	result["map_layer_id"] = map_layer_id
	result["target_player_index"] = target_player_index
	return result
