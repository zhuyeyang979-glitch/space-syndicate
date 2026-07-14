extends Node
class_name V06SaveOwnerRegistryFakeOwner

@export var section_id := ""
@export var owner_state: Dictionary = {}
@export var fail_once_live_apply := false

var apply_count := 0


func configure(configured_section_id: String, initial_value: int) -> void:
	section_id = configured_section_id
	owner_state = {
		"section_id": section_id,
		"value": initial_value,
		"position": Vector2(initial_value, initial_value + 1),
		"tint": Color(0.1, 0.2, 0.3, 0.4),
		"private_cash_cents": 98765432100,
		"private_hand": ["V06_OWNER_REGISTRY_PRIVATE_HAND"],
		"owner_truth": "V06_OWNER_REGISTRY_OWNER_TRUTH",
		"ai_plan": "V06_OWNER_REGISTRY_AI_PLAN",
	}


func to_save_data() -> Dictionary:
	return owner_state.duplicate(true)


func apply_save_data(data: Dictionary) -> Dictionary:
	if not _valid_state(data):
		return {"applied": false, "reason_code": "fake_owner_state_invalid"}
	apply_count += 1
	if fail_once_live_apply and is_inside_tree():
		fail_once_live_apply = false
		owner_state = data.duplicate(true)
		owner_state["value"] = int(owner_state.get("value", 0)) + 1
		return {"applied": false, "reason_code": "fake_owner_injected_partial_failure"}
	owner_state = data.duplicate(true)
	return {"applied": true, "reason_code": "fake_owner_state_applied"}


func arm_fail_once() -> void:
	fail_once_live_apply = true


func current_value() -> int:
	return int(owner_state.get("value", -1))


func _valid_state(data: Dictionary) -> bool:
	return str(data.get("section_id", "")) == section_id \
		and typeof(data.get("value", null)) == TYPE_INT \
		and data.get("position") is Vector2 \
		and data.get("tint") is Color \
		and typeof(data.get("private_cash_cents", null)) == TYPE_INT \
		and data.get("private_hand") is Array \
		and typeof(data.get("owner_truth", null)) == TYPE_STRING \
		and typeof(data.get("ai_plan", null)) == TYPE_STRING
