extends SceneTree

const Core := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var request := Core.build_monster_request(
		"request.monster.assault",
		"mission.monster.assault",
		"player.one",
		"card.military.one",
		"slot.one",
		"reservation.one",
		"monster.enemy.001"
	)
	var authority := Core.build_card_authority(
		"military.hammer.rank.3", 3, 7, 9, "effect.hammer", 5
	)
	var locked := Core.lock_monster_assault(
		request,
		authority,
		[_monster(4, 12, "region.002", "monster.enemy.001")]
	)
	var receipt := Core.resolve_monster_assault(
		locked,
		[_monster(4, 12, "region.002", "monster.enemy.001")]
	)
	var intents := receipt.get("monster_damage_intents", []) as Array
	var intent := intents[0] as Dictionary if intents.size() == 1 else {}
	_expect(
		str(receipt.get("outcome", "")) == "resolved"
			and intents.size() == 1,
		"monster mission resolves exactly one attack"
	)
	_expect(
		str(intent.get("target_monster_source_instance_id", ""))
			== "monster.enemy.001"
			and int(intent.get("expected_source_generation", -1)) == 4
			and int(intent.get("damage_amount", -1)) == 9,
		"attack preserves locked source identity and generation"
	)
	_expect(
		str(intent.get("public_target_region_id", "")) == "region.002"
			and int(intent.get("observed_source_revision", -1)) == 12,
		"attack preserves the exact locked revision and public region"
	)
	var drifted := Core.resolve_monster_assault(
		locked,
		[_monster(4, 14, "region.019", "monster.enemy.001")]
	)
	_expect(
		str(drifted.get("outcome", "")) == "fizzled"
			and str(drifted.get("reason_code", ""))
				== "locked_monster_target_invalid"
			and (drifted.get("monster_damage_intents", []) as Array).is_empty()
			and int(drifted.get("retarget_count", -1)) == 0,
		"revision or region drift fizzles without current-state retargeting"
	)
	_expect(
		str(receipt.get("mission_state_after", "")) == "withdrawn",
		"military withdraws after the single attack"
	)
	print(
		"V075_MILITARY_MONSTER_ASSAULT_TEST|status=%s|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)


func _monster(
	generation: int,
	revision: int,
	region_id: String,
	source_id: String
) -> Dictionary:
	return {
		"source_instance_id": source_id,
		"source_generation": generation,
		"damage_revision": revision,
		"owner_player_id": "player.two",
		"region_id": region_id,
		"status": "active",
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)