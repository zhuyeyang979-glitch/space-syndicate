extends SceneTree

const Core := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var request := Core.build_monster_request(
		"request.no.retarget",
		"mission.no.retarget",
		"player.one",
		"card.military.one",
		"slot.one",
		"reservation.one",
		"monster.locked.001"
	)
	var authority := Core.build_card_authority(
		"military.hammer.rank.1", 1, 3, 4, "effect.hammer", 2
	)
	var locked := Core.lock_monster_assault(
		request,
		authority,
		[_monster("monster.locked.001", 2, 7)]
	)
	var replacement := _monster("monster.replacement.001", 1, 1)
	var receipt := Core.resolve_monster_assault(
		locked,
		[replacement]
	)
	_expect(
		str(receipt.get("outcome", "")) == "fizzled",
		"missing locked identity fizzles"
	)
	_expect(
		(receipt.get("monster_damage_intents", []) as Array).is_empty()
			and int(receipt.get("retarget_count", -1)) == 0,
		"replacement target is never selected"
	)
	_expect(
		str(
			(receipt.get("dbg_lifecycle_intent", {}) as Dictionary).get(
				"destination_zone", ""
			)
		) == "personal_discard",
		"fizzled mission still completes its DBG lifecycle"
	)
	print(
		"V075_MILITARY_NO_RETARGET_TEST|status=%s|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)


func _monster(
	source_id: String, generation: int, revision: int
) -> Dictionary:
	return {
		"source_instance_id": source_id,
		"source_generation": generation,
		"source_revision": revision,
		"owner_player_id": "player.two",
		"region_id": "region.004",
		"status": "active",
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)