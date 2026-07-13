extends Resource
class_name ControllerStateVersionEntryResource

@export var controller_id: String = ""
@export var save_section: String = ""
@export var state_version: int = 1
@export var required: bool = true


func to_snapshot() -> Dictionary:
	return {
		"controller_id": controller_id,
		"save_section": save_section,
		"state_version": state_version,
		"required": required,
	}
