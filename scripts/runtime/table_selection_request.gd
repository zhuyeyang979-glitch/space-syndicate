extends PlayerIdentityActionRequest
class_name TableSelectionRequest

var selection_kind: StringName = &""
var expected_selection_revision := -1
var map_layer_id: StringName = &""
var target_player_index := -1
var target_district_index := -1
var target_trade_product_id := ""
var target_hand_slot := -2


func validation_report() -> Dictionary:
	var identity_validation := super.validation_report()
	if not bool(identity_validation.get("valid", false)):
		return identity_validation
	if selection_kind not in [TableSelectionIntent.KIND_MAP_LAYER, TableSelectionIntent.KIND_INSPECT_PLAYER, TableSelectionIntent.KIND_SELECT_DISTRICT, TableSelectionIntent.KIND_SELECT_TRADE_PRODUCT, TableSelectionIntent.KIND_SELECT_HAND_SLOT]:
		return _invalid("selection_kind_invalid")
	if expected_selection_revision < 0:
		return _invalid("selection_revision_invalid")
	match selection_kind:
		TableSelectionIntent.KIND_MAP_LAYER:
			if not TableSelectionIntent.MAP_LAYER_IDS.has(map_layer_id):
				return _invalid("map_layer_invalid")
		TableSelectionIntent.KIND_INSPECT_PLAYER:
			if target_player_index < 0:
				return _invalid("target_player_invalid")
		TableSelectionIntent.KIND_SELECT_DISTRICT:
			if target_district_index < 0:
				return _invalid("target_district_invalid")
		TableSelectionIntent.KIND_SELECT_TRADE_PRODUCT:
			if target_trade_product_id.length() > 80 or target_trade_product_id.strip_edges() != target_trade_product_id:
				return _invalid("target_trade_product_invalid")
		TableSelectionIntent.KIND_SELECT_HAND_SLOT:
			if target_hand_slot < -1:
				return _invalid("target_hand_slot_invalid")
	return {"valid": true, "reason_code": ""}


func to_dictionary() -> Dictionary:
	var result := super.to_dictionary()
	result["selection_kind"] = selection_kind
	result["expected_selection_revision"] = expected_selection_revision
	result["map_layer_id"] = map_layer_id
	result["target_player_index"] = target_player_index
	result["target_district_index"] = target_district_index
	result["target_trade_product_id"] = target_trade_product_id
	result["target_hand_slot"] = target_hand_slot
	return result
