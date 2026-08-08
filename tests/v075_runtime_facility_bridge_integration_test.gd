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
const FacilityDamageBridge := preload(
	"res://scripts/v075/combat/v075_facility_combat_damage_bridge.gd"
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
	var applied_receipts := applied.get("receipts", []) as Array
	var applied_new_receipts := (
		applied.get("newly_committed_receipts", []) as Array
	)
	_expect(
		bool(applied.get("accepted", false))
			and applied_receipts.size() == 1
			and applied_new_receipts.size() == 1
			and applied_new_receipts[0] == applied_receipts[0],
		"fresh facility commit returns one prior-response receipt and one newly committed receipt"
	)
	var damaged_state := (
		applied.get("public_batch_state", {}) as Dictionary
	)
	var damaged_facility := _facility_by_id(
		BatchCore.facility_substate(damaged_state),
		str(facility.get("facility_id", ""))
	)
	var applied_receipt := applied_receipts[0] as Dictionary
	_expect(
		(damaged_state.get("authority_queue", []) as Array) == queue_before
			and int(damaged_state.get("resolution_cursor", -2))
				== cursor_before,
		"facility damage preserves the pending mixed queue and cursor"
	)
	_expect(
		int(damaged_facility.get("damage_points", -1))
			== int(facility.get("damage_points", -2)) + 1
			and int(damaged_facility.get("damage_revision", -1))
				== int(facility.get("damage_revision", -2)) + 1
			and int(applied_receipt.get("damage_revision_after", -1))
				== int(applied_receipt.get("damage_revision_before", -2)) + 1
			and int(applied_receipt.get("region_revision_after", -1))
				== int(applied_receipt.get("region_revision_before", -2)) + 1,
		"fresh facility commit advances HP damage and authoritative revisions exactly once"
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
	var initial_observers_before := _observer_snapshot(runtime)
	runtime.call("_emit_facility_damage_events", applied_new_receipts)
	_expect(
		_observer_delta_green(
			initial_observers_before,
			_observer_snapshot(runtime),
			1,
			1,
			0
		),
		"fresh facility commit publishes once to public, presentation, and telemetry observers"
	)
	var emitted_commit_snapshot := _mutation_snapshot(runtime)

	var replay := runtime.call(
		"_apply_facility_damage_intents",
		damaged_state,
		[intent]
	) as Dictionary
	var replay_receipts := replay.get("receipts", []) as Array
	var replay_new_receipts := (
		replay.get("newly_committed_receipts", []) as Array
	)
	_expect(
		bool(replay.get("accepted", false))
			and replay_receipts.size() == 1
			and replay_receipts[0] == applied_receipts[0]
			and replay_new_receipts.is_empty()
			and replay.get("public_batch_state", {}) == damaged_state,
		"exact commit replay returns the prior receipt but no newly committed receipt"
	)
	runtime.call("_emit_facility_damage_events", replay_new_receipts)
	_expect(
		_mutation_snapshot(runtime) == emitted_commit_snapshot,
		"exact commit replay has zero HP, revision, bridge, public, presentation, and telemetry delta"
	)
	var facility_resolution_checkpoint := runtime.call(
		"_capture_resolution_checkpoint",
		"player.one",
		"facility",
		"action.runtime.bridge.rollback.probe",
		""
	) as Dictionary
	_expect(
		not (facility_resolution_checkpoint.get(
			"runtime_combat",
			{}
		) as Dictionary).is_empty(),
		"facility resolution checkpoint captures the outer combat transaction with no source card"
	)
	var facility_resolution_expected := _resolution_rollback_snapshot(runtime)
	runtime.set("_facility_damage_bridge_state", {})
	runtime.set("_processed_facility_damage_intents", {})
	runtime.set("_facility_effect_commit_witness", {})
	runtime.set("_combat_public_history", [{"corrupted": true}])
	runtime.set("_combat_public_receipt_count", 999)
	var facility_resolution_rollback := runtime.call(
		"_rollback_resolution_checkpoint",
		facility_resolution_checkpoint
	) as Dictionary
	_expect(
		bool(facility_resolution_rollback.get("accepted", false))
			and _resolution_rollback_snapshot(runtime)
				== facility_resolution_expected,
		"facility resolution rollback restores bridge, processed, witness, and public receipt ledgers exactly"
	)

	var second_intent := DamageIntent.build(
		"effect.runtime.bridge.second",
		str(damaged_facility.get("facility_id", "")),
		int(damaged_facility.get("facility_generation", 0)),
		1,
		"monster_basic_attack",
		"combat.runtime.bridge.second"
	)
	var mixed_observers_before := _observer_snapshot(runtime)
	var mixed_apply := runtime.call(
		"_apply_facility_damage_intents",
		damaged_state,
		[intent, second_intent]
	) as Dictionary
	var mixed_receipts := mixed_apply.get("receipts", []) as Array
	var mixed_new_receipts := (
		mixed_apply.get("newly_committed_receipts", []) as Array
	)
	var twice_damaged_state := (
		mixed_apply.get("public_batch_state", {}) as Dictionary
	)
	var twice_damaged_facility := _facility_by_id(
		BatchCore.facility_substate(twice_damaged_state),
		str(facility.get("facility_id", ""))
	)
	_expect(
		bool(mixed_apply.get("accepted", false))
			and mixed_receipts.size() == 2
			and mixed_receipts[0] == applied_receipts[0]
			and mixed_new_receipts.size() == 1
			and mixed_new_receipts[0] == mixed_receipts[1],
		"mixed replay-then-fresh input preserves response order while exposing only the fresh receipt"
	)
	_expect(
		int(twice_damaged_facility.get("damage_points", -1))
			== int(damaged_facility.get("damage_points", -2)) + 1
			and int(twice_damaged_facility.get("damage_revision", -1))
				== int(damaged_facility.get("damage_revision", -2)) + 1,
		"mixed replay-then-fresh input mutates HP and revision only for the fresh intent"
	)
	runtime.call("_emit_facility_damage_events", mixed_new_receipts)
	var mixed_observers_after := _observer_snapshot(runtime)
	_expect(
		_observer_delta_green(
			mixed_observers_before,
			mixed_observers_after,
			1,
			1,
			0
		),
		"mixed replay-then-fresh publication emits exactly one public, presentation, and telemetry receipt"
	)
	var mixed_replay_snapshot := _mutation_snapshot(runtime)
	var mixed_replay := runtime.call(
		"_apply_facility_damage_intents",
		twice_damaged_state,
		[intent, second_intent]
	) as Dictionary
	var mixed_replay_receipts := mixed_replay.get("receipts", []) as Array
	var mixed_replay_new := (
		mixed_replay.get("newly_committed_receipts", []) as Array
	)
	_expect(
		bool(mixed_replay.get("accepted", false))
			and mixed_replay_receipts == mixed_receipts
			and mixed_replay_new.is_empty()
			and mixed_replay.get("public_batch_state", {})
				== twice_damaged_state,
		"mixed exact replay returns both prior receipts in order and no new publication work"
	)
	runtime.call("_emit_facility_damage_events", mixed_replay_new)
	_expect(
		_mutation_snapshot(runtime) == mixed_replay_snapshot,
		"mixed exact replay has zero authority and observer delta"
	)

	var destroyed_fixture := _mixed_batch_fixture()
	var destroyed_state := (
		destroyed_fixture.get("state", {}) as Dictionary
	)
	var destroyed_facility := (
		destroyed_fixture.get("facility", {}) as Dictionary
	)
	var destroy_intent := DamageIntent.build(
		"effect.runtime.bridge.destroy",
		str(destroyed_facility.get("facility_id", "")),
		int(destroyed_facility.get("facility_generation", 0)),
		12,
		"monster_basic_attack",
		"combat.runtime.bridge.destroy"
	)
	var stale_after_destroy := DamageIntent.build(
		"effect.runtime.bridge.stale.after.destroy",
		str(destroyed_facility.get("facility_id", "")),
		int(destroyed_facility.get("facility_generation", 0)),
		1,
		"monster_ground_trample",
		"combat.runtime.bridge.stale.after.destroy"
	)
	var destroy_batch := runtime.call(
		"_apply_facility_damage_intents",
		destroyed_state,
		[destroy_intent, stale_after_destroy]
	) as Dictionary
	var destroy_receipts := destroy_batch.get("receipts", []) as Array
	var destroy_new_receipts := (
		destroy_batch.get("newly_committed_receipts", []) as Array
	)
	_expect(
		bool(destroy_batch.get("accepted", false))
			and destroy_receipts.size() == 2
			and destroy_new_receipts == destroy_receipts
			and bool((destroy_receipts[0] as Dictionary).get(
				"facility_destroyed",
				false
			))
			and not bool((destroy_receipts[1] as Dictionary).get(
				"accepted",
				true
			))
			and int((destroy_receipts[1] as Dictionary).get(
				"applied_damage",
				-1
			)) == 0
			and str((destroy_receipts[1] as Dictionary).get(
				"reason_code",
				""
			)) == "facility_combat_damage_target_missing",
		"a target destroyed earlier in one boundary commits a zero-damage fizzle"
	)
	var destroy_debug := runtime.debug_snapshot()
	_expect(
		int(destroy_debug.get("facility_combat_damage_receipt_count", -1)) == 3
		and int(destroy_debug.get("facility_combat_damage_fizzle_count", -1)) == 1
		and int(destroy_debug.get("facility_damage_bridge_receipt_count", -1)) == 3,
		"a stale-target fizzle is separate from three actual bridge damage receipts"
	)
	var destroy_observers_before := _observer_snapshot(runtime)
	runtime.call("_emit_facility_damage_events", destroy_new_receipts)
	var destroy_observers_after := _observer_snapshot(runtime)
	_expect(
		_observer_delta_green(
			destroy_observers_before,
			destroy_observers_after,
			2,
			1,
			1
		),
		"fresh destroy and fizzle each publish exactly once"
	)
	var destroy_replay_snapshot := _mutation_snapshot(runtime)
	var destroy_replay := runtime.call(
		"_apply_facility_damage_intents",
		destroy_batch.get("public_batch_state", {}) as Dictionary,
		[destroy_intent, stale_after_destroy]
	) as Dictionary
	var destroy_replay_receipts := (
		destroy_replay.get("receipts", []) as Array
	)
	var destroy_replay_new := (
		destroy_replay.get("newly_committed_receipts", []) as Array
	)
	_expect(
		bool(destroy_replay.get("accepted", false))
			and destroy_replay_receipts == destroy_receipts
			and destroy_replay_new.is_empty()
			and destroy_replay.get("public_batch_state", {})
				== destroy_batch.get("public_batch_state", {}),
		"fresh commit and fresh fizzle both replay as prior receipts with an empty new list"
	)
	runtime.call("_emit_facility_damage_events", destroy_replay_new)
	_expect(
		_mutation_snapshot(runtime) == destroy_replay_snapshot,
		"destroy and fizzle replay has zero HP, revision, bridge, public, presentation, and telemetry delta"
	)
	var public_history := runtime.get("_combat_public_history") as Array
	var fizzle_event := public_history[public_history.size() - 1] as Dictionary
	_expect(
		str(fizzle_event.get("event_kind", ""))
			== "facility_combat_damage_fizzled"
		and str(fizzle_event.get("facility_damage_state", "")) == "fizzled"
			and int(fizzle_event.get("damage_amount", -1)) == 0,
		"a zero-damage fizzle never publishes a facility damaged event"
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
	_expect(
		_count_forbidden_private_fields(
			applied.get("receipts", [])
		) == 0,
		"warehouse combat receipt discloses no private stock or plan"
	)

	var receipt_key := "%s|%s" % [
		str(intent.get("combat_receipt_id", "")),
		str(intent.get("target_facility_id", "")),
	]
	var positive_checkpoint := runtime.call(
		"_capture_combat_transaction_state"
	) as Dictionary
	var positive_witness := (
		positive_checkpoint.get(
			"facility_effect_commit_witness",
			{}
		) as Dictionary
	).duplicate(true)
	var original_witness := (
		positive_witness.get(receipt_key, {}) as Dictionary
	).duplicate(true)
	var fresh_bridge := runtime.call(
		"_build_facility_damage_bridge_state",
		BatchCore.facility_substate(damaged_state)
	) as Dictionary
	var direct_control := FacilityDamageBridge.apply_intent(
		fresh_bridge,
		intent
	)
	var direct_control_facility := _facility_by_id(
		direct_control.get("facility_state", {}) as Dictionary,
		str(facility.get("facility_id", ""))
	)
	_expect(
		bool(FacilityDamageBridge.validation_report(fresh_bridge).get(
			"valid",
			false
		))
			and (fresh_bridge.get("receipt_journal", {}) as Dictionary).is_empty()
			and bool(direct_control.get("accepted", false))
			and not bool(direct_control.get("duplicate", true))
			and int(direct_control_facility.get("damage_points", -1))
				== int(damaged_facility.get("damage_points", -2)) + 1
			and int(direct_control_facility.get("damage_revision", -1))
				== int(damaged_facility.get("damage_revision", -2)) + 1,
		"negative control proves a legal fresh empty bridge would apply the same intent a second time"
	)
	runtime.set("_facility_damage_bridge_state", fresh_bridge.duplicate(true))
	runtime.set("_processed_facility_damage_intents", {})
	runtime.set(
		"_facility_effect_commit_witness",
		{receipt_key: original_witness.duplicate(true)}
	)
	var divergence_mutation_before := _mutation_snapshot(runtime)
	var damaged_state_before_divergence := damaged_state.duplicate(true)
	var debug_before_divergence := runtime.debug_snapshot()
	var divergence := runtime.call(
		"_apply_facility_damage_intents",
		damaged_state,
		[intent]
	) as Dictionary
	var debug_after_divergence := runtime.debug_snapshot()
	var effect_integrity := (
		(debug_after_divergence.get("combat", {}) as Dictionary).get(
		"combat_effect_integrity",
		{}
		) as Dictionary
	)
	_expect(
		not bool(divergence.get("accepted", true))
			and str(divergence.get("reason_code", ""))
				== "facility_damage_native_ledger_divergence"
			and _mutation_snapshot(runtime)
				== divergence_mutation_before
			and damaged_state == damaged_state_before_divergence
			and int(debug_after_divergence.get(
				"facility_combat_damage_receipt_count",
				-1
			)) == int(debug_before_divergence.get(
				"facility_combat_damage_receipt_count",
				-2
			))
			and int((debug_after_divergence.get(
				"combat",
				{}
			) as Dictionary).get("combat_duplicate_effect_count", 0)) >= 1
			and int(effect_integrity.get(
				"outer_facility_duplicate_commit_count",
				0
			)) >= 1,
		"outer facility witness rejects native-ledger loss before a second HP mutation"
	)
	runtime.call("_restore_combat_transaction_state", positive_checkpoint)

	for corruption_id in [
		"witness_schema",
		"witness_outcome",
		"witness_receipt_fingerprint",
		"processed_receipt_fingerprint",
	]:
		runtime.call(
			"_restore_combat_transaction_state",
			positive_checkpoint
		)
		_expect(
			_install_integrity_corruption(
				runtime,
				receipt_key,
				str(corruption_id)
			),
			"integrity corruption fixture installs: %s" % corruption_id
		)
		var corruption_before := _mutation_snapshot(runtime)
		var damaged_state_before_corruption := damaged_state.duplicate(true)
		var corrupted_replay := runtime.call(
			"_apply_facility_damage_intents",
			damaged_state,
			[intent]
		) as Dictionary
		_expect(
			not bool(corrupted_replay.get("accepted", true))
				and not str(corrupted_replay.get(
					"reason_code",
					""
				)).is_empty()
				and _mutation_snapshot(runtime) == corruption_before
				and damaged_state == damaged_state_before_corruption,
			"%s corruption fails closed with zero authority, HP, public, presentation, or telemetry mutation"
			% corruption_id
		)
	runtime.call("_restore_combat_transaction_state", positive_checkpoint)

	combat.queue_free()
	runtime.queue_free()
	_finish()


func _observer_snapshot(runtime: Object) -> Dictionary:
	var debug := runtime.call("debug_snapshot") as Dictionary
	var presentation := (
		debug.get("combat_presentation", {}) as Dictionary
	)
	var telemetry := debug.get("combat_telemetry", {}) as Dictionary
	return {
		"public_history": (
			runtime.get("_combat_public_history") as Array
		).duplicate(true),
		"presentation": presentation.duplicate(true),
		"telemetry": telemetry.duplicate(true),
		"public_receipt_count": int(debug.get(
			"combat_public_receipt_count",
			-1
		)),
		"presentation_applied_receipt_count": int(presentation.get(
			"applied_receipt_count",
			-1
		)),
		"presentation_duplicate_receipt_count": int(presentation.get(
			"duplicate_receipt_count",
			-1
		)),
		"presentation_rejected_receipt_count": int(presentation.get(
			"rejected_receipt_count",
			-1
		)),
		"telemetry_receipt_input_count": int(telemetry.get(
			"receipt_input_count",
			-1
		)),
		"telemetry_duplicate_source_count": int(telemetry.get(
			"duplicate_source_count",
			-1
		)),
	}


func _observer_delta_green(
	before: Dictionary,
	after: Dictionary,
	expected_new_receipts: int,
	expected_presentation_applied: int,
	expected_presentation_rejected: int
) -> bool:
	return (
		expected_new_receipts >= 0
		and expected_presentation_applied >= 0
		and expected_presentation_rejected >= 0
		and int(after.get("public_receipt_count", -1))
			== int(before.get("public_receipt_count", -2))
				+ expected_new_receipts
		and (after.get("public_history", []) as Array).size()
			== (before.get("public_history", []) as Array).size()
				+ expected_new_receipts
		and int(after.get(
			"presentation_applied_receipt_count",
			-1
		)) == int(before.get(
			"presentation_applied_receipt_count",
			-2
		)) + expected_presentation_applied
		and int(after.get(
			"presentation_rejected_receipt_count",
			-1
		)) == int(before.get(
			"presentation_rejected_receipt_count",
			-2
		)) + expected_presentation_rejected
		and int(after.get(
			"presentation_duplicate_receipt_count",
			-1
		)) == int(before.get(
			"presentation_duplicate_receipt_count",
			-2
		))
		and int(after.get(
			"telemetry_receipt_input_count",
			-1
		)) == int(before.get(
			"telemetry_receipt_input_count",
			-2
		)) + expected_new_receipts
		and int(after.get(
			"telemetry_duplicate_source_count",
			-1
		)) == int(before.get(
			"telemetry_duplicate_source_count",
			-2
		)) + expected_presentation_applied
	)


func _mutation_snapshot(runtime: Object) -> Dictionary:
	var debug := runtime.call("debug_snapshot") as Dictionary
	return {
		"bridge_state": (
			runtime.get("_facility_damage_bridge_state") as Dictionary
		).duplicate(true),
		"processed_intents": (
			runtime.get("_processed_facility_damage_intents") as Dictionary
		).duplicate(true),
		"effect_witness": (
			runtime.get("_facility_effect_commit_witness") as Dictionary
		).duplicate(true),
		"facility_bridge_receipt_count": int(debug.get(
			"facility_damage_bridge_receipt_count",
			-1
		)),
		"facility_bridge_direct_write_count": int(debug.get(
			"facility_damage_bridge_direct_write_count",
			-1
		)),
		"facility_receipt_count": int(debug.get(
			"facility_combat_damage_receipt_count",
			-1
		)),
		"facility_fizzle_count": int(debug.get(
			"facility_combat_damage_fizzle_count",
			-1
		)),
		"observers": _observer_snapshot(runtime),
	}


func _resolution_rollback_snapshot(runtime: Object) -> Dictionary:
	return {
		"bridge_state": (
			runtime.get("_facility_damage_bridge_state") as Dictionary
		).duplicate(true),
		"processed_intents": (
			runtime.get("_processed_facility_damage_intents") as Dictionary
		).duplicate(true),
		"effect_witness": (
			runtime.get("_facility_effect_commit_witness") as Dictionary
		).duplicate(true),
		"public_history": (
			runtime.get("_combat_public_history") as Array
		).duplicate(true),
		"public_receipt_count": int(runtime.get(
			"_combat_public_receipt_count"
		)),
	}


func _install_integrity_corruption(
	runtime: Object,
	receipt_key: String,
	corruption_id: String
) -> bool:
	if corruption_id in [
		"witness_schema",
		"witness_outcome",
		"witness_receipt_fingerprint",
	]:
		var witnesses := (
			runtime.get("_facility_effect_commit_witness") as Dictionary
		).duplicate(true)
		if not witnesses.has(receipt_key):
			return false
		var witness := (
			witnesses.get(receipt_key, {}) as Dictionary
		).duplicate(true)
		match corruption_id:
			"witness_schema":
				witness["schema"] = "V075FacilityEffectCommitWitnessCorrupt"
			"witness_outcome":
				witness["outcome_class"] = "unknown"
			"witness_receipt_fingerprint":
				witness["receipt_fingerprint"] = "0".repeat(64)
		witnesses[receipt_key] = witness
		runtime.set("_facility_effect_commit_witness", witnesses)
		return true
	if corruption_id == "processed_receipt_fingerprint":
		var processed := (
			runtime.get("_processed_facility_damage_intents") as Dictionary
		).duplicate(true)
		if not processed.has(receipt_key):
			return false
		var processed_row := (
			processed.get(receipt_key, {}) as Dictionary
		).duplicate(true)
		var receipt := (
			processed_row.get("receipt", {}) as Dictionary
		).duplicate(true)
		receipt["receipt_fingerprint"] = "0".repeat(64)
		processed_row["receipt"] = receipt
		processed[receipt_key] = processed_row
		runtime.set("_processed_facility_damage_intents", processed)
		return true
	return false


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
