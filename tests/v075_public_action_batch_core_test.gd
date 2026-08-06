extends SceneTree

const BatchCore := preload(
	"res://scripts/v075/runtime/v075_public_action_batch_core.gd"
)
const FacilityCore := preload(
	"res://scripts/v074/facility/v074_facility_runtime_core.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var players := ["player.one", "player.two"]
	var hidden_order := ["player.two", "player.one"]
	var slot := FacilityCore.build_empty_slot(
		"region.000", 0, "factory", "life", 0
	)
	var facility_action := FacilityCore.build_new_action(
		"action.batch.1.player.one.00",
		"card.player.one.factory",
		"player.one",
		0,
		slot,
		_zero_assets(),
		"standard",
		1
	)
	var monster_action := {
		"action_id": "action.batch.1.player.one.01",
		"actor_id": "player.one",
		"local_action_index": 1,
		"action_domain": "monster",
		"source_card_instance_id": "card.player.one.monster",
		"combat_binding": {"card_mode": "DEPLOY_NEW"},
	}
	var military_action := {
		"action_id": "action.batch.1.player.two.00",
		"actor_id": "player.two",
		"local_action_index": 0,
		"action_domain": "military",
		"source_card_instance_id": "card.player.two.military",
		"combat_binding": {"task_kind": "assault_region"},
	}
	var state := BatchCore.lock_batch(
		"batch.v075.test.1",
		players,
		hidden_order,
		{
			"player.one": [facility_action, monster_action],
			"player.two": [military_action],
		},
		[slot]
	)
	_expect(not state.is_empty(), "mixed batch locks")
	_expect(
		bool(BatchCore.validation_report(state).get("valid", false)),
		"mixed batch state validates"
	)
	var queue := state.get("authority_queue", []) as Array
	_expect(queue.size() == 3, "mixed queue contains three actions")
	_expect(
		str((queue[0] as Dictionary).get("action_domain", "")) == "military"
		and str((queue[1] as Dictionary).get("action_domain", "")) == "facility"
		and str((queue[2] as Dictionary).get("action_domain", "")) == "monster",
		"hidden lead layered order is stable across domains"
	)

	var first := BatchCore.resolve_next(state)
	_expect(bool(first.get("accepted", false)), "military entry resolves")
	_expect(
		str((first.get("receipt", {}) as Dictionary).get("outcome_id", ""))
		== "combat_action_ready",
		"military entry delegates to combat authority"
	)
	state = (first.get("state", {}) as Dictionary).duplicate(true)
	var second := BatchCore.resolve_next(state)
	_expect(bool(second.get("accepted", false)), "facility entry resolves")
	_expect(
		str((second.get("receipt", {}) as Dictionary).get("outcome_id", ""))
		== "facility_action_resolved",
		"facility entry remains owned by facility core"
	)
	state = (second.get("state", {}) as Dictionary).duplicate(true)
	var facility_state := BatchCore.facility_substate(state)
	var public_slots := (
		FacilityCore.public_projection(facility_state).get(
			"public_facility_slots", []
		) as Array
	)
	var built := public_slots[0] as Dictionary
	var facility_id := str(built.get("facility_id", ""))
	_expect(not facility_id.is_empty(), "facility delegate creates target")
	var generation := int(built.get("facility_generation", 0))
	var damage_one := FacilityCore.apply_v075_combat_damage_intent(
		facility_state,
		{
			"source_effect_id": "effect.monster.trample.1",
			"target_facility_id": facility_id,
			"expected_generation": generation,
			"damage_amount": 2,
			"damage_kind": "monster_trample",
			"combat_receipt_id": "combat.receipt.1",
		},
		{1: 4, 2: 8, 3: 12, 4: 16}
	)
	_expect(bool(damage_one.get("accepted", false)), "first damage commits")
	_expect(
		not bool((damage_one.get("receipt", {}) as Dictionary).get("destroyed", true)),
		"first damage leaves facility active"
	)
	facility_state = (damage_one.get("state", {}) as Dictionary).duplicate(true)
	var damage_two := FacilityCore.apply_v075_combat_damage_intent(
		facility_state,
		{
			"source_effect_id": "effect.military.region.2",
			"target_facility_id": facility_id,
			"expected_generation": generation,
			"damage_amount": 2,
			"damage_kind": "military_region_assault",
			"combat_receipt_id": "combat.receipt.2",
		},
		{1: 4, 2: 8, 3: 12, 4: 16}
	)
	_expect(bool(damage_two.get("accepted", false)), "second damage commits")
	_expect(
		bool((damage_two.get("receipt", {}) as Dictionary).get("destroyed", false)),
		"damage threshold destroys facility exactly once"
	)
	var destroyed_slots := (
		FacilityCore.public_projection(
			damage_two.get("state", {}) as Dictionary
		).get("public_facility_slots", []) as Array
	)
	_expect(
		str((destroyed_slots[0] as Dictionary).get("occupancy", "")) == "empty",
		"destroyed facility returns its registered slot to empty"
	)
	state = BatchCore.replace_facility_substate(
		state,
		damage_two.get("state", {}) as Dictionary
	)
	_expect(not state.is_empty(), "mixed authority accepts facility port result")
	var third := BatchCore.resolve_next(state)
	_expect(bool(third.get("accepted", false)), "monster entry resolves")
	_expect(
		str((third.get("state", {}) as Dictionary).get("status", "")) == "resolved",
		"mixed batch reaches resolved status"
	)
	_finish()


func _zero_assets() -> Dictionary:
	return {
		"life": 0,
		"energy": 0,
		"industry": 0,
		"technology": 0,
		"commerce": 0,
		"shipping": 0,
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print(
		"V075_PUBLIC_ACTION_BATCH_CORE_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
