extends Control
class_name V075MilitaryMissionBench

const MilitaryCore := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)

@onready var status_label: Label = %StatusLabel

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_bench")


func _run_bench() -> void:
	status_label.text = "Running V0.7.5 military mission contracts..."
	var authority := _authority()
	var region_request := MilitaryCore.build_region_request(
		"request.military.region.001",
		"mission.region.001",
		"player.alpha",
		"card.military.alpha.001",
		"action.slot.alpha.001",
		"reservation.alpha.001",
		"region.007"
	)
	var facilities := _facilities()
	var region_lock := MilitaryCore.lock_region_assault(
		region_request,
		authority,
		14,
		facilities
	)
	var region_receipt := MilitaryCore.resolve_region_assault(
		region_lock,
		facilities
	)
	_expect(
		bool(
			MilitaryCore.mission_lock_validation_report(
				region_lock
			).get("valid", false)
		),
		"region lock validates"
	)
	_expect(
		bool(
			MilitaryCore.receipt_validation_report(
				region_receipt
			).get("valid", false)
		),
		"region receipt validates"
	)
	var region_intents := (
		region_receipt.get("facility_damage_intents", []) as Array
	)
	_expect(
		int(region_receipt.get("allocated_damage_total", 0)) == 8
			and region_intents.size() == 3
			and _damage_by_target(region_intents) == {
				"facility.factory.a": 3,
				"facility.market.b": 3,
				"facility.warehouse.c": 2,
			},
		"fixed total budget is distributed by stable round robin"
	)
	_expect(
		not JSON.stringify(region_lock).contains("stock.secret.42")
			and not JSON.stringify(region_receipt).contains(
				"stock.secret.42"
			),
		"warehouse private stock never enters mission data"
	)
	var partially_invalid := facilities.duplicate(true)
	(partially_invalid[0] as Dictionary)["facility_generation"] = 2
	var skipped_receipt := MilitaryCore.resolve_region_assault(
		region_lock,
		partially_invalid
	)
	_expect(
		int(skipped_receipt.get("allocated_damage_total", 0)) == 8
			and (
				skipped_receipt.get("facility_damage_intents", []) as Array
			).size() == 2
			and int(skipped_receipt.get("retarget_count", -1)) == 0,
		"invalid locked target is skipped without adding a target"
	)
	var monster_request := MilitaryCore.build_monster_request(
		"request.military.monster.001",
		"mission.monster.001",
		"player.alpha",
		"card.military.alpha.002",
		"action.slot.alpha.002",
		"reservation.alpha.002",
		"monster.rival.001"
	)
	var monster_lock := MilitaryCore.lock_monster_assault(
		monster_request,
		authority,
		[_monster("monster.rival.001", 4, 9, "player.beta", "region.003")]
	)
	var moved_monster := _monster(
		"monster.rival.001",
		4,
		10,
		"player.beta",
		"region.011"
	)
	var monster_receipt := MilitaryCore.resolve_monster_assault(
		monster_lock,
		[moved_monster]
	)
	var monster_intents := (
		monster_receipt.get("monster_damage_intents", []) as Array
	)
	_expect(
		bool(
			MilitaryCore.receipt_validation_report(
				monster_receipt
			).get("valid", false)
		)
			and monster_intents.size() == 1
			and str(
				(monster_intents[0] as Dictionary).get(
					"target_monster_source_instance_id", ""
				)
			) == "monster.rival.001"
			and str(
				(monster_intents[0] as Dictionary).get(
					"public_target_region_id", ""
				)
			) == "region.011",
		"monster mission follows current public region for locked identity"
	)
	var no_retarget_receipt := MilitaryCore.resolve_monster_assault(
		monster_lock,
		[
			_monster(
				"monster.rival.999",
				1,
				1,
				"player.gamma",
				"region.011"
			),
		]
	)
	_expect(
		str(no_retarget_receipt.get("outcome", "")) == "fizzled"
			and (
				no_retarget_receipt.get(
					"monster_damage_intents", []
				) as Array
			).is_empty()
			and int(no_retarget_receipt.get("retarget_count", -1)) == 0,
		"missing locked monster fizzles without retarget"
	)
	for receipt in [
		region_receipt,
		skipped_receipt,
		monster_receipt,
		no_retarget_receipt,
	]:
		var dbg := (receipt as Dictionary).get(
			"dbg_lifecycle_intent", {}
		) as Dictionary
		_expect(
			str(dbg.get("destination_zone", "")) == "personal_discard"
				and bool(dbg.get("reshuffle_eligible", false))
				and not bool(dbg.get("direct_mutation_allowed", true)),
			"every mission returns the normal card through typed DBG intent"
		)
	var contract := MilitaryCore.contract_report()
	_expect(
		contract.get("military_task_kinds")
			== ["assault_region", "assault_monster"]
			and int(contract.get("military_guard_task_count", -1)) == 0
			and int(contract.get("military_bound_action_count", -1)) == 0
			and int(
				contract.get("military_persistent_source_count", -1)
			) == 0,
		"contract exposes exactly two one-shot missions"
	)
	var passed := _failures.is_empty()
	status_label.text = "PASS" if passed else "FAIL"
	print(
		"V075_MILITARY_MISSION_BENCH|status=%s|checks=%d|failures=%s"
		% [
			"PASS" if passed else "FAIL",
			_checks,
			JSON.stringify(_failures),
		]
	)
	get_tree().quit(0 if passed else 1)


func _authority() -> Dictionary:
	return MilitaryCore.build_card_authority(
		"military.v075.patrol.rank_2",
		2,
		8,
		6,
		"effect.military.patrol.rank_2",
		31
	)


func _facilities() -> Array:
	return [
		{
			"facility_id": "facility.warehouse.c",
			"facility_generation": 1,
			"owner_player_id": "player.delta",
			"region_id": "region.007",
			"facility_type": "warehouse",
			"industry_id": "shipping",
			"status": "active",
			"warehouse_stock": ["stock.secret.42"],
			"logistics_plan": {"next": "private"},
		},
		{
			"facility_id": "facility.market.b",
			"facility_generation": 3,
			"owner_player_id": "player.beta",
			"region_id": "region.007",
			"facility_type": "market",
			"industry_id": "commerce",
			"status": "damaged",
		},
		{
			"facility_id": "facility.factory.a",
			"facility_generation": 2,
			"owner_player_id": "player.gamma",
			"region_id": "region.007",
			"facility_type": "factory",
			"industry_id": "industry",
			"status": "active",
		},
	]


func _monster(
	source_instance_id: String,
	source_generation: int,
	source_revision: int,
	owner_player_id: String,
	region_id: String
) -> Dictionary:
	return {
		"source_instance_id": source_instance_id,
		"source_generation": source_generation,
		"source_revision": source_revision,
		"owner_player_id": owner_player_id,
		"region_id": region_id,
		"status": "active",
	}


func _damage_by_target(intents: Array) -> Dictionary:
	var result := {}
	for intent_variant in intents:
		var intent := intent_variant as Dictionary
		result[str(intent.get("target_facility_id", ""))] = int(
			intent.get("damage_amount", 0)
		)
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)