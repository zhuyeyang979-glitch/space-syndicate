extends SceneTree

const Core := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var request := Core.build_region_request(
		"request.withdraw",
		"mission.withdraw",
		"player.one",
		"card.military.one",
		"slot.one",
		"reservation.one",
		"region.003"
	)
	var authority := Core.build_card_authority(
		"military.line.rank.1", 1, 3, 2, "effect.line", 1
	)
	var facilities := [{
		"facility_id": "facility.market.one",
		"facility_generation": 1,
		"owner_player_id": "player.two",
		"region_id": "region.003",
		"facility_type": "market",
		"industry_id": "commerce",
		"status": "active",
	}]
	var locked := Core.lock_region_assault(
		request, authority, 8, facilities
	)
	var resolved := Core.resolve_region_assault(locked, facilities)
	var fizzled := Core.resolve_region_assault(locked, [])
	for receipt in [resolved, fizzled]:
		var withdrawal := (receipt as Dictionary).get(
			"military_withdrawal_intent", {}
		) as Dictionary
		var dbg := (receipt as Dictionary).get(
			"dbg_lifecycle_intent", {}
		) as Dictionary
		_expect(
			str(withdrawal.get("state_after", "")) == "withdrawn"
				and not bool(
					withdrawal.get("persistent_source_created", true)
				),
			"mission always withdraws"
		)
		_expect(
			str(dbg.get("expected_zone", ""))
				== "military_mission_resolving"
				and str(dbg.get("destination_zone", ""))
				== "personal_discard"
				and not bool(dbg.get("direct_mutation_allowed", true)),
			"typed intent returns card to personal discard"
		)
	print(
		"V075_MILITARY_WITHDRAW_TO_DISCARD_TEST|status=%s|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)