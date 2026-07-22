@tool
extends PublicLogProducerPort
class_name AiBusinessCostFailOncePublicLogPort

var _fail_next_publish := true


func publish(
	event_kind: StringName,
	localization_key: StringName,
	public_values: Dictionary,
	source_revision: int,
	world_time: float,
	receipt_id := ""
) -> Dictionary:
	if _fail_next_publish:
		_fail_next_publish = false
		return {"applied": false, "reason_code": "qa_public_log_transient_failure"}
	return super.publish(event_kind, localization_key, public_values, source_revision, world_time, receipt_id)
