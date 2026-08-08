extends SceneTree

const Core := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var request := Core.build_region_request(
		"request.warehouse.privacy",
		"mission.warehouse.privacy",
		"player.one",
		"card.military.one",
		"slot.one",
		"reservation.one",
		"region.012"
	)
	var authority := Core.build_card_authority(
		"military.line.rank.1", 1, 4, 2, "effect.line", 1
	)
	var warehouse := {
		"facility_id": "facility.warehouse.private",
		"facility_generation": 3,
		"owner_player_id": "player.two",
		"region_id": "region.012",
		"facility_type": "warehouse",
		"industry_id": "shipping",
		"status": "damaged",
		"warehouse_stock": ["secret.cargo.900"],
		"private_stock": {"secret.cargo.900": 5},
		"inventory": ["secret.cargo.901"],
		"logistics_plan": {"next_region": "region.secret"},
	}
	var locked := Core.lock_region_assault(
		request, authority, 22, [warehouse]
	)
	var receipt := Core.resolve_region_assault(locked, [warehouse])
	var serialized := JSON.stringify({
		"locked": locked,
		"receipt": receipt,
	})
	for private_token in [
		"warehouse_stock",
		"private_stock",
		"inventory",
		"logistics_plan",
		"secret.cargo.900",
		"region.secret",
	]:
		_expect(
			not serialized.contains(private_token),
			"private token is absent: %s" % private_token
		)
	_expect(
		str(receipt.get("outcome", "")) == "resolved"
			and (
				receipt.get("facility_damage_intents", []) as Array
			).size() == 1,
		"public warehouse identity remains a legal combat target"
	)
	_expect(
		int(
			Core.contract_report().get(
				"direct_facility_write_count", -1
			)
		) == 0,
		"combat remains outside warehouse state ownership"
	)
	print(
		"V075_WAREHOUSE_COMBAT_PRIVACY_TEST|status=%s|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)