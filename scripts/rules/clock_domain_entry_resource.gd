extends Resource
class_name ClockDomainEntryResource

@export var timer_id: String = ""
@export var duration_seconds: int = 0
@export var clock_domain: String = "world_effective"
@export var menu_pause_behavior: String = "pause"
@export var readonly_pause_behavior: String = "pause"
@export var forced_decision_behavior: String = "pause"
@export var monster_wager_freeze_behavior: String = "pause"
@export var save_restore_behavior: String = "remaining"


func to_snapshot() -> Dictionary:
	return {
		"timer_id": timer_id,
		"duration_seconds": duration_seconds,
		"clock_domain": clock_domain,
		"menu_pause_behavior": menu_pause_behavior,
		"readonly_pause_behavior": readonly_pause_behavior,
		"forced_decision_behavior": forced_decision_behavior,
		"monster_wager_freeze_behavior": monster_wager_freeze_behavior,
		"save_restore_behavior": save_restore_behavior,
	}
