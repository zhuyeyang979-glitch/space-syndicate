extends SceneTree

const Core := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := Core.contract_report()
	_expect(
		bool(contract.get("military_card_normal_dbg_member", false))
			and contract.get("military_card_lifecycle") == [
				"normal_hand",
				"committed_escrow",
				"military_mission_resolving",
				"withdrawn",
				"personal_discard",
				"normal_reshuffle",
				"future_draw",
			]
			and contract.get("post_resolution_intent_order") == [
				"military_withdrawal",
				"personal_discard",
			]
			and str(
				contract.get(
					"military_card_destination_after_mission", ""
				)
			) == "personal_discard"
			and bool(
				contract.get(
					"military_card_reshuffle_eligible", false
				)
			),
		"military card retains normal DBG membership"
	)
	var request := Core.build_region_request(
		"request.dbg",
		"mission.dbg",
		"player.one",
		"card.military.dbg.001",
		"slot.one",
		"reservation.one",
		"region.001"
	)
	var authority := Core.build_card_authority(
		"military.line.rank.1", 1, 2, 2, "effect.line", 1
	)
	var facilities := [{
		"facility_id": "facility.factory.one",
		"facility_generation": 1,
		"owner_player_id": "player.two",
		"region_id": "region.001",
		"facility_type": "factory",
		"industry_id": "energy",
		"status": "active",
	}]
	var locked := Core.lock_region_assault(
		request, authority, 1, facilities
	)
	var receipt := Core.resolve_region_assault(locked, facilities)
	var intent := receipt.get("dbg_lifecycle_intent", {}) as Dictionary
	_expect(
		str(intent.get("card_instance_id", ""))
			== "card.military.dbg.001"
			and bool(intent.get("normal_dbg_member", false))
			and bool(intent.get("reshuffle_eligible", false)),
		"discarded military instance is eligible for normal reshuffle"
	)
	_expect(
		not bool(intent.get("direct_mutation_allowed", true))
			and int(receipt.get("direct_dbg_write_count", -1)) == 0,
		"mission core delegates all DBG mutation"
	)
	print(
		"V075_MILITARY_DBG_RESHUFFLE_TEST|status=%s|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)