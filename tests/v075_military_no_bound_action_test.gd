extends SceneTree

const Core := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var request := Core.build_region_request(
		"request.region.bound.audit",
		"mission.region.bound.audit",
		"player.one",
		"card.military.one",
		"slot.one",
		"reservation.one",
		"region.001"
	)
	var authority := Core.build_card_authority(
		"military.scout.rank.1", 1, 3, 2, "effect.scout", 1
	)
	var facilities := [{
		"facility_id": "facility.factory.one",
		"facility_generation": 1,
		"owner_player_id": "player.two",
		"region_id": "region.001",
		"facility_type": "factory",
		"industry_id": "life",
		"status": "active",
	}]
	var locked := Core.lock_region_assault(
		request, authority, 1, facilities
	)
	var receipt := Core.resolve_region_assault(locked, facilities)
	var withdrawal := receipt.get(
		"military_withdrawal_intent", {}
	) as Dictionary
	_expect(
		int(Core.contract_report().get(
			"military_bound_action_count", -1
		)) == 0,
		"military contract creates no bound action"
	)
	_expect(
		not bool(locked.get("bound_action_created", true))
			and int(receipt.get("bound_action_count", -1)) == 0
			and not bool(
				withdrawal.get("bound_action_created", true)
			),
		"lock, receipt, and withdrawal remain bound-action free"
	)
	_expect(
		int(receipt.get("persistent_source_count", -1)) == 0,
		"one-shot mission leaves no persistent source"
	)
	print(
		"V075_MILITARY_NO_BOUND_ACTION_TEST|status=%s|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)