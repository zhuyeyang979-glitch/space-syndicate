extends Resource
class_name ClockDomainRegistryResource

@export var ruleset_id: String = "v0.5"
@export var entries: Array[ClockDomainEntryResource] = []


func timer_ids() -> Array[String]:
	var result: Array[String] = []
	for entry in entries:
		if entry != null:
			result.append(entry.timer_id)
	return result


func timer_snapshot(timer_id: String) -> Dictionary:
	for entry in entries:
		if entry != null and entry.timer_id == timer_id:
			return entry.to_snapshot()
	return {}


func validation_snapshot() -> Dictionary:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for entry in entries:
		if entry == null or entry.timer_id.is_empty():
			errors.append("timer_id_missing")
			continue
		if seen.has(entry.timer_id):
			errors.append("duplicate_timer:%s" % entry.timer_id)
		else:
			seen[entry.timer_id] = true
		if entry.duration_seconds <= 0:
			errors.append("duration_invalid:%s" % entry.timer_id)
		if not ["world_effective", "interaction_effective", "forced_ui_realtime", "battle_effective"].has(entry.clock_domain):
			errors.append("clock_domain_invalid:%s" % entry.timer_id)
	return {"valid": errors.is_empty(), "errors": errors, "timer_count": seen.size(), "timer_ids": timer_ids()}


func debug_snapshot() -> Dictionary:
	var timer_snapshots: Array[Dictionary] = []
	for entry in entries:
		if entry != null:
			timer_snapshots.append(entry.to_snapshot())
	return {"ruleset_id": ruleset_id, "timers": timer_snapshots}
