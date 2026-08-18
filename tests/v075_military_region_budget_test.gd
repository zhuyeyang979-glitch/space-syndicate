extends SceneTree

const Core := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var facilities := [
		{
			"slot_id": "slot.region.006.factory.life.00",
			"region_id": "region.006",
			"facility_type": "factory",
			"industry_id": "life",
			"occupancy": "empty",
			"facility_id": null,
			"facility_generation": null,
			"owner_id": null,
		},
		_facility("facility.warehouse.c", "warehouse", "shipping"),
		_facility("facility.factory.a", "factory", "industry"),
		_facility("facility.market.b", "market", "commerce"),
	]
	var request := Core.build_region_request(
		"request.region.budget",
		"mission.region.budget",
		"player.one",
		"card.military.one",
		"slot.one",
		"reservation.one",
		"region.006"
	)
	var authority := Core.build_card_authority(
		"military.line.rank.2", 2, 8, 4, "effect.line", 3
	)
	var locked := Core.lock_region_assault(
		request, authority, 12, facilities
	)
	var receipt := Core.resolve_region_assault(locked, facilities)
	var damage := {}
	for intent_variant in receipt.get(
		"facility_damage_intents", []
	) as Array:
		var intent := intent_variant as Dictionary
		damage[str(intent.get("target_facility_id", ""))] = int(
			intent.get("damage_amount", 0)
		)
	_expect(
		damage == {
			"facility.factory.a": 3,
			"facility.market.b": 3,
			"facility.warehouse.c": 2,
		},
		"stable round robin allocates one point per pass"
	)
	_expect(
		int(receipt.get("allocated_damage_total", -1)) == 8,
		"allocated total equals the fixed card budget"
	)
	_expect(
		bool(Core.receipt_validation_report(receipt).get("valid", false)),
		"budget receipt validates"
	)
	print(
		"V075_MILITARY_REGION_BUDGET_TEST|status=%s|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)


func _facility(
	facility_id: String, facility_type: String, industry_id: String
) -> Dictionary:
	return {
		"facility_id": facility_id,
		"facility_generation": 1,
		"owner_player_id": "player.two",
		"region_id": "region.006",
		"facility_type": facility_type,
		"industry_id": industry_id,
		"status": "active",
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
