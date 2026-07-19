extends RefCounted
class_name SessionStartReceipt

var accepted := false
var applied := false
var idempotent := false
var in_progress := false
var reason_code := "session_start_rejected"
var request_id := ""
var plan_fingerprint := ""
var failing_stage := ""
var rollback_complete := true
var operation_sequence := 0
var trace: Array[String] = []
var details: Dictionary = {}


static func from_dictionary(data: Dictionary) -> SessionStartReceipt:
	var receipt := SessionStartReceipt.new()
	receipt.accepted = bool(data.get("accepted", false))
	receipt.applied = bool(data.get("applied", false))
	receipt.idempotent = bool(data.get("idempotent", false))
	receipt.in_progress = bool(data.get("in_progress", false))
	receipt.reason_code = str(data.get("reason_code", "session_start_rejected"))
	receipt.request_id = str(data.get("request_id", ""))
	receipt.plan_fingerprint = str(data.get("plan_fingerprint", ""))
	receipt.failing_stage = str(data.get("failing_stage", ""))
	receipt.rollback_complete = bool(data.get("rollback_complete", true))
	receipt.operation_sequence = int(data.get("operation_sequence", 0))
	for value in (data.get("trace", []) as Array):
		receipt.trace.append(str(value))
	receipt.details = (data.get("details", {}) as Dictionary).duplicate(true)
	return receipt


func to_dictionary() -> Dictionary:
	return {
		"accepted": accepted,
		"applied": applied,
		"idempotent": idempotent,
		"in_progress": in_progress,
		"reason_code": reason_code,
		"request_id": request_id,
		"plan_fingerprint": plan_fingerprint,
		"failing_stage": failing_stage,
		"rollback_complete": rollback_complete,
		"operation_sequence": operation_sequence,
		"trace": trace.duplicate(),
		"details": details.duplicate(true),
	}
