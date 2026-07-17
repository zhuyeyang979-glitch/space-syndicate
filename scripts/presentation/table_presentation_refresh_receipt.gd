extends RefCounted
class_name TablePresentationRefreshReceipt

const VALID_KINDS := [&"live", &"map", &"full", &"developer"]

var receipt_id := ""
var sequence := 0
var kind: StringName = &""
var source_revision := 0
var real_delta := 0.0


func is_valid() -> bool:
	return not receipt_id.is_empty() and sequence > 0 and VALID_KINDS.has(kind) and source_revision >= 0 and real_delta >= 0.0
