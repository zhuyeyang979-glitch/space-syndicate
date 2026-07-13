extends Resource
class_name ControllerStateVersionRegistryResource

@export var ruleset_id: String = "v0.5"
@export var entries: Array[ControllerStateVersionEntryResource] = []


func required_versions() -> Dictionary:
	var result: Dictionary = {}
	for entry in entries:
		if entry != null and entry.required:
			result[entry.controller_id] = entry.state_version
	return result


func validation_snapshot() -> Dictionary:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for entry in entries:
		if entry == null or entry.controller_id.is_empty() or entry.save_section.is_empty():
			errors.append("controller_entry_incomplete")
			continue
		if seen.has(entry.controller_id):
			errors.append("duplicate_controller:%s" % entry.controller_id)
		else:
			seen[entry.controller_id] = true
		if entry.state_version <= 0:
			errors.append("state_version_invalid:%s" % entry.controller_id)
	return {"valid": errors.is_empty(), "errors": errors, "controller_count": seen.size()}


func debug_snapshot() -> Dictionary:
	var snapshots: Array[Dictionary] = []
	for entry in entries:
		if entry != null:
			snapshots.append(entry.to_snapshot())
	return {"ruleset_id": ruleset_id, "entries": snapshots, "required_versions": required_versions()}
