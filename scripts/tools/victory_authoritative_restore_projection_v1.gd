extends RefCounted
class_name VictoryAuthoritativeRestoreProjectionV1

const SAVE_WIRE_CODEC := preload("res://scripts/runtime/victory_control_save_wire_codec_v3.gd")
const PROJECTION_FIELDS := [
	"state",
	"qualification_elapsed_by_player",
	"audit_roster",
	"audit_remaining_seconds",
	"outcome_sequence",
	"outcome_receipt",
]


static func project(save_wire: Dictionary) -> Dictionary:
	var decoded := SAVE_WIRE_CODEC.decode_save_state(save_wire)
	if not bool(decoded.get("ok", false)):
		return {"ok": false, "reason_code": str(decoded.get("reason_code", "victory_projection_decode_failed"))}
	var owner_state := decoded.get("value", {}) as Dictionary
	var payload: Dictionary = owner_state.get("victory_control_runtime", {}) \
			if owner_state.get("victory_control_runtime", {}) is Dictionary else {}
	var projection: Dictionary = {}
	for field in PROJECTION_FIELDS:
		if not payload.has(field):
			return {"ok": false, "reason_code": "victory_projection_field_missing"}
		projection[field] = _detached(payload.get(field))
	return {"ok": true, "value": projection}


static func _detached(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
