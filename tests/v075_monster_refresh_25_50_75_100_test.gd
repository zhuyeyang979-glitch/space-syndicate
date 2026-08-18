extends SceneTree

const Core := preload(
	"res://scripts/v075/monster/v075_monster_source_core.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var expected_by_rank := {
		1: 100,
		2: 200,
		3: 300,
		4: 400,
	}
	for card_rank in range(1, 5):
		var source_id := "monster.alpha.refresh.%d" % card_rank
		var source := Core.build_source_snapshot(
			_definition(),
			source_id,
			"player.alpha",
			"region.a",
			4,
			0,
			"downed",
			1,
			"card.origin.%d" % card_rank
		)
		var state := Core.new_state(
			["player.alpha"],
			{},
			[source]
		)
		var result := _resolve(
			state,
			card_rank,
			source_id,
			"card.refresh.%d" % card_rank
		)
		var receipt := result.get("receipt", {}) as Dictionary
		var refreshed := Core.source_snapshot(
			result.get("state", {}) as Dictionary,
			source_id
		)
		var expected := int(expected_by_rank.get(card_rank, -1))
		_expect(
			result.get("accepted") == true
			and receipt.get("refresh_percent")
			== card_rank * 25
			and receipt.get("healing_amount_requested") == expected
			and receipt.get("healing_amount_applied") == expected
			and refreshed.get("hp") == expected
			and refreshed.get("rank") == 4,
			"rank %d refresh applies exact %d percent integer healing"
			% [card_rank, card_rank * 25]
		)
	var capped := Core.build_source_snapshot(
		_definition(),
		"monster.alpha.refresh.cap",
		"player.alpha",
		"region.a",
		4,
		350,
		"active",
		1,
		"card.origin.cap"
	)
	var capped_result := _resolve(
		Core.new_state(["player.alpha"], {}, [capped]),
		3,
		"monster.alpha.refresh.cap",
		"card.refresh.cap"
	)
	var capped_receipt := (
		capped_result.get("receipt", {}) as Dictionary
	)
	var capped_source := Core.source_snapshot(
		capped_result.get("state", {}) as Dictionary,
		"monster.alpha.refresh.cap"
	)
	_expect(
		capped_receipt.get("healing_amount_requested") == 300
		and capped_receipt.get("healing_amount_applied") == 50
		and capped_source.get("hp") == 400,
		"refresh applies no overheal beyond max HP"
	)
	_expect(
		Core.contract_snapshot().get("refresh_percent_by_rank")
		== {"1": 25, "2": 50, "3": 75, "4": 100},
		"core publishes frozen 25/50/75/100 contract"
	)
	_finish()


func _resolve(
	state: Dictionary,
	card_rank: int,
	target_source_id: String,
	card_id: String
) -> Dictionary:
	var request := {
		"request_id": "request.%s" % card_id,
		"card_instance_id": card_id,
		"card_definition_id": "definition.%s" % card_id,
		"owner_player_id": "player.alpha",
		"card_rank": card_rank,
		"monster_card_mode": Core.MODE_REFRESH_EXISTING,
		"target_region_id": "",
		"target_source_instance_id": target_source_id,
	}
	var bound := Core.prebind_card_mode(
		state,
		request,
		_definition()
	)
	if not bool(bound.get("accepted", false)):
		return bound
	return Core.resolve_prebound_card(
		state,
		bound.get("action", {}) as Dictionary
	)


func _definition() -> Dictionary:
	return {
		"source_definition_id": "monster.alpha.source",
		"monster_family_id": "alpha",
		"preferred_industry_color": "life",
		"facility_type_preference": ["factory", "market", "warehouse"],
		"base_detection_range_hops": 2,
		"movement_profile": "ground_trample",
		"movement_budget_milli_arc_by_rank": [1000, 1200, 1400, 1600],
		"max_hp_by_rank": [400, 400, 400, 400],
		"armor_by_rank": [0, 1, 2, 3],
		"active_skill_definition_ids": [
			"skill.alpha.1",
			"skill.alpha.2",
			"skill.alpha.3",
			"skill.alpha.4",
		],
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for failure in _failures:
		push_error(
			"V075_MONSTER_REFRESH_25_50_75_100_TEST|FAIL|%s"
			% failure
		)
	print(
		"V075_MONSTER_REFRESH_25_50_75_100_TEST|%s|checks=%d|failures=%d"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
		]
	)
	quit(0 if _failures.is_empty() else 1)
