@tool
extends Resource
class_name V06SaveOwnerBindingResource

const RESTORE_TRANSACTIONAL := "transactional"
const RESTORE_UNSUPPORTED := "unsupported"

@export var section_id := ""
@export var owner_id := ""
@export var state_version := 1
@export var owner_path: NodePath
@export var capture_method := ""
@export var preflight_method := ""
@export var apply_method := ""
@export var rollback_method := ""
@export_enum("transactional", "unsupported") var restore_mode := RESTORE_UNSUPPORTED
@export var unsupported_reason := "capability_not_registered"


func is_transactional() -> bool:
	return restore_mode == RESTORE_TRANSACTIONAL


func contract_snapshot() -> Dictionary:
	return {
		"section_id": section_id,
		"owner_id": owner_id,
		"state_version": state_version,
		"restore_mode": restore_mode,
		"preflight_method": preflight_method,
		"unsupported_reason": "" if is_transactional() else unsupported_reason,
	}
