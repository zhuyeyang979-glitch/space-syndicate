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
	var initial_facility_revision := int(
		BatchCore.facility_substate(state).get("revision", 0)
	)
	_expect(queue.size() == 3, "mixed queue contains three actions")
	_expect(
		str((queue[0] as Dictionary).get("action_domain", "")) == "military"
		and str((queue[1] as Dictionary).get("action_domain", "")) == "facility"
		and str((queue[2] as Dictionary).get("action_domain", "")) == "monster",
		"hidden lead layered order is stable across domains"
	)

	var strict_first := BatchCore.resolve_next(state)
	var first := BatchCore.resolve_next_authority_owned(state)
	_expect(
		first == strict_first,
		"authority-owned transition is byte-value identical to strict transition"
	)
	_expect(bool(first.get("accepted", false)), "military entry resolves")
	_expect(
		str((first.get("receipt", {}) as Dictionary).get("outcome_id", ""))
		== "combat_action_ready",
		"military entry delegates to combat authority"
	)
	_cross_batch_combat_receipt_identity_regression(
		players,
		hidden_order,
		military_action,
		slot,
		str((first.get("receipt", {}) as Dictionary).get("receipt_id", ""))
	)
	state = (first.get("state", {}) as Dictionary).duplicate(true)
	var second := BatchCore.resolve_next(state)
	_expect(bool(second.get("accepted", false)), "facility entry resolves")
	if not bool(second.get("accepted", false)):
		_finish()
		return
	_expect(
		str((second.get("receipt", {}) as Dictionary).get("outcome_id", ""))
		== "facility_action_resolved",
		"facility entry remains owned by facility core"
	)
	state = (second.get("state", {}) as Dictionary).duplicate(true)
	var facility_state := BatchCore.facility_substate(state)
	var facility_receipt := second.get("receipt", {}) as Dictionary
	_expect(
		int(facility_state.get("revision", 0))
			== initial_facility_revision
		and int(facility_receipt.get("state_revision", -1))
			== int(state.get("revision", 0)),
		"mixed authority revision advances while the empty-queue substate stays valid"
	)
	var facility_projection := BatchCore.public_projection(state)
	_expect(
		int(facility_projection.get("state_revision", -1))
			== int(state.get("revision", 0))
		and int(facility_projection.get("facility_substate_revision", -1))
			== initial_facility_revision,
		"V075 projection exposes outer revision without rewriting V074 history"
	)
	_expect(
		int((state.get("processed_action_ids", {}) as Dictionary).get(
			str(facility_receipt.get("action_id", "")),
			-1
		)) == 1,
		"outer mixed authority journals the facility action exactly once"
	)
	_cross_batch_facility_receipt_identity_regression(
		players,
		hidden_order,
		facility_action,
		slot,
		str(facility_receipt.get("receipt_id", ""))
	)
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
	_combat_before_facility_index_regression(slot)
	_authority_owned_ledger_tamper_regression(
		players,
		hidden_order,
		military_action,
		slot
	)
	_finish()


func _cross_batch_combat_receipt_identity_regression(
	players: Array,
	hidden_order: Array,
	military_action: Dictionary,
	slot: Dictionary,
	first_receipt_id: String
) -> void:
	var next_batch := BatchCore.lock_batch(
		"batch.v075.test.receipt.next",
		players,
		hidden_order,
		{
			"player.one": [],
			"player.two": [military_action],
		},
		[slot]
	)
	_expect(not next_batch.is_empty(), "cross-batch receipt fixture locks")
	if next_batch.is_empty():
		return
	var next_result := BatchCore.resolve_next(next_batch)
	var next_receipt_id := str(
		(next_result.get("receipt", {}) as Dictionary).get("receipt_id", "")
	)
	_expect(
		bool(next_result.get("accepted", false))
		and not first_receipt_id.is_empty()
		and not next_receipt_id.is_empty()
		and next_receipt_id != first_receipt_id,
		"combat atomic receipt ids are unique across batches"
	)


func _cross_batch_facility_receipt_identity_regression(
	players: Array,
	hidden_order: Array,
	facility_action: Dictionary,
	slot: Dictionary,
	first_receipt_id: String
) -> void:
	var next_batch := BatchCore.lock_batch(
		"batch.v075.test.facility.receipt.next",
		players,
		hidden_order,
		{
			"player.one": [facility_action],
			"player.two": [],
		},
		[slot]
	)
	_expect(not next_batch.is_empty(), "cross-batch facility receipt fixture locks")
	if next_batch.is_empty():
		return
	var next_result := BatchCore.resolve_next(next_batch)
	var next_receipt_id := str(
		(next_result.get("receipt", {}) as Dictionary).get("receipt_id", "")
	)
	_expect(
		bool(next_result.get("accepted", false))
		and not first_receipt_id.is_empty()
		and not next_receipt_id.is_empty()
		and next_receipt_id != first_receipt_id,
		"facility atomic receipt ids are unique across batches"
	)


func _authority_owned_ledger_tamper_regression(
	players: Array,
	hidden_order: Array,
	military_action: Dictionary,
	slot: Dictionary
) -> void:
	var state := BatchCore.lock_batch(
		"batch.v075.test.ledger.tamper",
		players,
		hidden_order,
		{
			"player.one": [],
			"player.two": [military_action],
		},
		[slot]
	)
	var resolved := BatchCore.resolve_next_authority_owned(state)
	_expect(bool(resolved.get("accepted", false)), "ledger tamper fixture resolves")
	if not bool(resolved.get("accepted", false)):
		return
	var tampered := (
		resolved.get("state", {}) as Dictionary
	).duplicate(true)
	tampered["processed_action_ids"] = {}
	tampered = BatchCore._seal(tampered)
	var rejected := BatchCore.resolve_next_authority_owned(tampered)
	_expect(
		not bool(rejected.get("accepted", true))
		and str(rejected.get("reason_code", ""))
			== "public_action_authority_state_invalid",
		"authority-owned fast path rejects a resealed ledger mismatch"
	)


func _combat_before_facility_index_regression(slot: Dictionary) -> void:
	var monster_action := {
		"action_id": "action.batch.2.player.one.00",
		"actor_id": "player.one",
		"local_action_index": 0,
		"action_domain": "monster",
		"source_card_instance_id": "card.player.one.monster.first",
		"combat_binding": {"card_mode": "DEPLOY_NEW"},
	}
	var facility_action := FacilityCore.build_new_action(
		"action.batch.2.player.one.01",
		"card.player.one.factory.second",
		"player.one",
		1,
		slot,
		_zero_assets(),
		"standard",
		1
	)
	var player_two_facility_action := FacilityCore.build_new_action(
		"action.batch.2.player.two.00",
		"card.player.two.factory.first",
		"player.two",
		0,
		slot,
		_zero_assets(),
		"standard",
		1
	)
	var state := BatchCore.lock_batch(
		"batch.v075.test.2",
		["player.one", "player.two"],
		["player.one", "player.two"],
		{
			"player.one": [monster_action, facility_action],
			"player.two": [player_two_facility_action],
		},
		[slot]
	)
	_expect(not state.is_empty(), "combat-first mixed batch locks")
	if state.is_empty():
		return
	var queue := state.get("authority_queue", []) as Array
	_expect(queue.size() == 3, "combat-first mixed queue contains all actions")
	_expect(
		str((queue[0] as Dictionary).get("action_domain", "")) == "monster"
		and int((queue[0] as Dictionary).get("local_action_index", -1)) == 0
		and str((queue[1] as Dictionary).get("action_domain", "")) == "facility"
		and str((queue[1] as Dictionary).get("actor_id", "")) == "player.two"
		and int((queue[1] as Dictionary).get("local_action_index", -1)) == 0
		and str((queue[2] as Dictionary).get("action_domain", "")) == "facility"
		and str((queue[2] as Dictionary).get("actor_id", "")) == "player.one"
		and int((queue[2] as Dictionary).get("local_action_index", -1)) == 1,
		"mixed authority preserves original local indexes and order"
	)
	var facility_state := BatchCore.facility_substate(state)
	_expect(
		bool(FacilityCore.validation_report(facility_state).get("valid", false)),
		"authoritative facility snapshot validates before mixed resolution"
	)
	_expect(
		str(facility_state.get("status", "")) == "resolved",
		"facility snapshot carries state without a competing delegate queue"
	)
	var first := BatchCore.resolve_next(state)
	_expect(bool(first.get("accepted", false)), "combat-first entry resolves")
	state = (first.get("state", {}) as Dictionary).duplicate(true)
	var second := BatchCore.resolve_next(state)
	_expect(bool(second.get("accepted", false)), "first facility after combat resolves")
	_expect(
		str((second.get("receipt", {}) as Dictionary).get("action_id", ""))
		== "action.batch.2.player.two.00"
		and
		str((second.get("receipt", {}) as Dictionary).get("outcome_id", ""))
		== "facility_action_resolved",
		"global mixed order selects player two's facility first"
	)
	state = (second.get("state", {}) as Dictionary).duplicate(true)
	var third := BatchCore.resolve_next(state)
	_expect(bool(third.get("accepted", false)), "second facility resolves in mixed order")
	_expect(
		str((third.get("receipt", {}) as Dictionary).get("action_id", ""))
		== "action.batch.2.player.one.01"
		and str((third.get("state", {}) as Dictionary).get("status", "")) == "resolved",
		"later conflicting facility fizzles without delegate reordering"
	)


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
