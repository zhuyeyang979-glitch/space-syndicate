@tool
extends Resource
class_name CardRuntimePackResource

@export var pack_id: StringName = &""
@export var display_name := ""
@export var families: Array[Resource] = []


func family_ids() -> Array:
	var result: Array = []
	for family_resource in families:
		if family_resource != null:
			result.append(str(family_resource.get("family_id")))
	return result


func debug_snapshot() -> Dictionary:
	return {
		"pack_id": str(pack_id),
		"display_name": display_name,
		"family_ids": family_ids(),
	}
