extends SceneTree

const RuntimeOwner := preload(
	"res://scripts/v075_runtime/v075_runtime_owner.gd"
)
const CombatOwner := preload(
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
)
const BatchCore := preload(
	"res://scripts/v075/runtime/v075_public_action_batch_core.gd"
)
const FacilityCore := preload(
	"res://scripts/v074/facility/v074_facility_runtime_core.gd"
)
const DamageIntent := preload(
	"res://scripts/v075/combat/facility_combat_damage_intent_v1.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime := RuntimeOwner.new()
	var combat := CombatOwner.new()
	root.add_child(runtime)
	root.add_child(combat)
	_expect(
		bool(runtime.bind_combat_owner(combat).get("accepted", false)),
		"production runtime binds its single combat owner"
	)
	_expect(
		bool(runtime.start_new_game(
			4,
			900626424,
			true,
			true,
			{
				"map_seed": 900626424,
				"region_count": 16,
				"geography_complexity": "STANDARD",
				"land_ocean_profile": "BALANCED",
			}
		).get("accepted", false)),
		"production V075 runtime starts"
	)

	var fixture := _mixed_batch_fixture()
	var mixed_state := fixture.get("state", {}) as Dictionary
	var facility := fixture.get("facility", {}) as Dictionary
	var queue_before := (
		mixed_state.get("authority_queue", []) as Array
	).duplicate(true)
	var cursor_before := int(mixed_state.get("resolution_cursor", -1))
	var intent := DamageIntent.build(
		"effect.runtime.bridge.first",
		str(facility.get("facility_id", "")),
		int(facility.get("facility_generation", 0)),
		1,
		"monster_ground_trample",
		"combat.runtime.bridge.first"
	)
	var applied := runtime.call(
		"_apply_facility_damage_intents",
		mixed_state,
		[intent]
	) as Dictionary
	_expect(
		bool(applied.get("accepted", false))
			and (applied.get("receipts", []) as Array).size() == 1,
		"production runtime commits one typed facility receipt"
	)
	var damaged_state := (
		applied.get("public_batch_state", {}) as Dictionary
	)
	_expect(
		(damaged_state.get("authority_queue", []) as Array) == queue_before
			and int(damaged_state.get("resolution_cursor", -2))
				== cursor_before,
		"facility damage preserves the pending mixed queue and cursor"
	)
	var debug := runtime.debug_snapshot()
	_expect(
		int(debug.get("facility_damage_bridge_receipt_count", -1)) == 1
			and int(debug.get(
				"facility_damage_bridge_direct_write_count",
				-1
			)) == 0
			and int(debug.get(
				"facility_combat_damage_receipt_count",
				-1
			)) == 1,
		"runtime exposes one bridge receipt and zero direct writes"
	)

	var replay := runtime.call(
		"_apply_facility_damage_intents",
		damaged_state,
		[intent]
	) as Dictionary
	var replay_debug := runtime.debug_snapshot()
	_expect(
		bool(replay.get("accepted", false))
			and int(replay_debug.get(
				"facility_damage_bridge_receipt_count",
				-1
			)) == 1
			and int(replay_debug.get(
				"facility_combat_damage_receipt_count",
				-1
			)) == 1,
		"production bridge replay does not duplicate damage or counters"
	)

	var stale := BatchCore.resolve_next(damaged_state)
	_expect(
		bool(stale.get("accepted", false))
			and str((stale.get("receipt", {}) as Dictionary).get(
				"outcome_id",
				""
			)) == "facility_action_fizzled",
		"damage revision makes the previously locked repair action fizzle"
	)

	var checkpoint := runtime.call(
		"_capture_combat_transaction_state"
	) as Dictionary
	var damaged_facility := _facility_by_id(
		BatchCore.facility_substate(damaged_state),
		str(facility.get("facility_id", ""))
	)
	var second_intent := DamageIntent.build(
		"effect.runtime.bridge.second",
		str(damaged_facility.get("facility_id", "")),
		int(damaged_facility.get("facility_generation", 0)),
		1,
		"monster_basic_attack",
		"combat.runtime.bridge.second"
	)
	var second := runtime.call(
		"_apply_facility_damage_intents",
		damaged_state,
		[second_intent]
	) as Dictionary
	_expect(
		bool(second.get("accepted", false))
			and int(runtime.debug_snapshot().get(
				"facility_damage_bridge_receipt_count",
				-1
			)) == 2,
		"second typed intent advances the bridge journal"
	)
	runtime.call("_restore_combat_transaction_state", checkpoint)
	var rolled_back := runtime.debug_snapshot()
	_expect(
		int(rolled_back.get("facility_damage_bridge_receipt_count", -1)) == 1
			and int(rolled_back.get(
				"facility_combat_damage_receipt_count",
				-1
			)) == 1,
		"runtime transaction rollback restores bridge ledger and counters"
	)
	_expect(
		_count_forbidden_private_fields(
			applied.get("receipts", [])
		) == 0,
		"warehouse combat receipt discloses no private stock or plan"
	)

	combat.queue_free()
	runtime.queue_free()
	_finish()


func _mixed_batch_fixture() -> Dictionary:
	var facility := FacilityCore.build_occupied_slot(
		"region.bridge.001",
		5,
		"warehouse",
		"shipping",
		3,
		"facility.bridge.warehouse.001",
		1,
		"player.one",
		3,
		1,
		1,
		"sunlit"
	)
	var repair := FacilityCore.build_repair_action(
		"action.bridge.repair.001",
		"card.bridge.repair.001",
		"player.one",
		0,
		facility,
		_zero_assets(),
		"standard",
		3
	)
	var state := BatchCore.lock_batch(
		"batch.runtime.bridge.001",
		["player.one", "player.two"],
		["player.one", "player.two"],
		{
			"player.one": [repair],
			"player.two": [],
		},
		[facility]
	)
	return {"state": state, "facility": facility}


func _facility_by_id(state: Dictionary, facility_id: String) -> Dictionary:
	for slot_variant in (
		FacilityCore.public_projection(state).get(
			"public_facility_slots",
			[]
		) as Array
	):
		var slot := slot_variant as Dictionary
		if str(slot.get("facility_id", "")) == facility_id:
			return slot.duplicate(true)
	return {}


func _zero_assets() -> Dictionary:
	return {
		"life": 0,
		"energy": 0,
		"industry": 0,
		"technology": 0,
		"commerce": 0,
		"shipping": 0,
	}


func _count_forbidden_private_fields(value: Variant) -> int:
	var count := 0
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			if (
				key == "warehouse_private_stock_disclosure_count"
				and int((value as Dictionary).get(key_variant, -1)) == 0
			):
				continue
			for fragment in [
				"warehouse_stock",
				"private_stock",
				"logistics_plan",
				"future_production",
			]:
				if str(fragment) in key:
					count += 1
			count += _count_forbidden_private_fields(
				(value as Dictionary).get(key_variant)
			)
	elif value is Array:
		for item_variant in value as Array:
			count += _count_forbidden_private_fields(item_variant)
	return count


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print(
		"V075_RUNTIME_FACILITY_BRIDGE_INTEGRATION_TEST|%s"
		% JSON.stringify({
			"status": "PASS" if _failures.is_empty() else "FAIL",
			"passed": _checks - _failures.size(),
			"total": _checks,
			"failures": _failures,
		})
	)
	quit(0 if _failures.is_empty() else 1)
