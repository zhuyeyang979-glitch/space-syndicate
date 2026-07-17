extends RefCounted
class_name TablePresentationApplyReceipt

var refresh_receipt_id := ""
var sequence := 0
var kind: StringName = &""
var applied := false
var reason_code := ""
var snapshot_revision := 0
var target_revision := 0


func to_dictionary() -> Dictionary:
	return {
		"refresh_receipt_id": refresh_receipt_id,
		"sequence": sequence,
		"kind": str(kind),
		"applied": applied,
		"reason_code": reason_code,
		"snapshot_revision": snapshot_revision,
		"target_revision": target_revision,
	}
