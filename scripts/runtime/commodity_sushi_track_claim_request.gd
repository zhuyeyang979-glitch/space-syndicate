extends RefCounted
class_name CommoditySushiTrackClaimRequest

var viewer_index := -1
var commodity_slot_id := ""
var commodity_card_id := ""
var snapshot_revision := -1
var belt_revision := -1
var visibility_revision := -1
var request_revision := 0


func validation_report() -> Dictionary:
	var errors: Array[String] = []
	if viewer_index < 0:
		errors.append("viewer_index_invalid")
	if commodity_slot_id.strip_edges().is_empty():
		errors.append("commodity_slot_id_missing")
	if commodity_card_id.strip_edges().is_empty():
		errors.append("commodity_card_id_missing")
	if snapshot_revision < 0 or belt_revision < 0 or visibility_revision <= 0:
		errors.append("snapshot_binding_invalid")
	if request_revision <= 0:
		errors.append("request_revision_invalid")
	return {"valid": errors.is_empty(), "errors": errors}


func canonical_key() -> String:
	return "%d|%s|%s|%d|%d|%d|%d" % [
		viewer_index,
		commodity_slot_id,
		commodity_card_id,
		snapshot_revision,
		belt_revision,
		visibility_revision,
		request_revision,
	]
