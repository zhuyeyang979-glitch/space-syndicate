extends SceneTree

const Core := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var facilities: Array = []
	for index in range(4):
		facilities.append({
			"facility_id": "facility.enemy.%02d" % index,
			"facility_generation": 1,
			"owner_player_id": "player.two",
			"region_id": "region.009",
			"facility_type": ["factory", "market", "warehouse"][index % 3],
			"industry_id": "life",
			"status": "active",
		})
	var request := Core.build_region_request(
		"request.no.replication",
		"mission.no.replication",
		"player.one",
		"card.military.one",
		"slot.one",
		"reservation.one",
		"region.009"
	)
	var authority := Core.build_card_authority(
		"military.line.rank.1", 1, 5, 3, "effect.line", 2
	)
	var locked := Core.lock_region_assault(
		request, authority, 1, facilities
	)
	var receipt := Core.resolve_region_assault(locked, facilities)
	var intents := receipt.get("facility_damage_intents", []) as Array
	var summed := 0
	var full_budget_target_count := 0
	for intent_variant in intents:
		var amount := int(
			(intent_variant as Dictionary).get("damage_amount", 0)
		)
		summed += amount
		if amount == 5:
			full_budget_target_count += 1
	_expect(
		summed == 5
			and int(receipt.get("allocated_damage_total", -1)) == 5,
		"facility count does not multiply total damage"
	)
	_expect(
		full_budget_target_count == 0,
		"no facility receives a replicated full budget"
	)
	print(
		"V075_MILITARY_REGION_NO_FULL_DAMAGE_REPLICATION_TEST|status=%s|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)