extends SceneTree

const CONTROLLER_SCENE_PATH := "res://scenes/runtime/VictoryControlRuntimeController.tscn"
const POST_SETTLEMENT_CHECKPOINT := "post_world_settlement"
const EXPECTED_REASON := "public_audit_complete"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_split_boundary_reproducer()
	_test_partition_equivalence_and_exact_once()
	_test_no_early_resolution_above_epsilon()
	_test_save_load_near_endpoint()
	_test_checkpoint_negative_delta_and_pause_contracts()
	_finish()


func _test_split_boundary_reproducer() -> void:
	var controller := _new_controller("split boundary")
	if controller == null:
		return
	var world := _eligible_world()
	controller.call("advance_world_effective", 5.0, world)
	controller.call("advance_world_effective", 5.0, world)
	_expect(str((controller.call("public_snapshot") as Dictionary).get("state", "")) == "audit", "qualification 5+5 enters audit")
	controller.call("advance_world_effective", 119.99, world)
	var endpoint: Dictionary = controller.call("advance_world_effective", 0.01, world)
	var receipt: Dictionary = controller.call("outcome_receipt")
	_expect(str(endpoint.get("state", "")) == "resolved", "audit 119.99+0.01 resolves at the same 120-second boundary")
	_expect(not str(receipt.get("outcome_id", "")).is_empty() and str(receipt.get("reason_code", "")) == EXPECTED_REASON, "split endpoint emits one public_audit_complete outcome")
	_expect(int((controller.call("debug_snapshot") as Dictionary).get("outcome_sequence", -1)) == 1, "split endpoint outcome sequence is exactly one")
	controller.free()


func _test_partition_equivalence_and_exact_once() -> void:
	var single := _completed_controller([10.0], [120.0], "single-step")
	var split := _completed_controller([5.0, 5.0], [119.99, 0.01], "split-step")
	var granular := _completed_controller(_repeated_delta(0.1, 100), _repeated_delta(0.1, 1200), "granular-step")
	if single == null or split == null or granular == null:
		_free_controllers([single, split, granular])
		return
	var single_receipt: Dictionary = single.call("outcome_receipt")
	var split_receipt: Dictionary = split.call("outcome_receipt")
	var granular_receipt: Dictionary = granular.call("outcome_receipt")
	_expect(not single_receipt.is_empty() and single_receipt == split_receipt and split_receipt == granular_receipt, "single, split, and granular partitions produce the same outcome receipt")
	var before_replay := split_receipt.duplicate(true)
	split.call("advance_world_effective", 120.0, _eligible_world())
	split.call("advance_world_effective", 0.01, _eligible_world())
	_expect(split.call("outcome_receipt") == before_replay, "advance replay after resolution does not emit or mutate a second receipt")
	_expect(int((split.call("debug_snapshot") as Dictionary).get("outcome_sequence", -1)) == 1, "advance replay keeps outcome sequence at one")
	_free_controllers([single, split, granular])


func _test_no_early_resolution_above_epsilon() -> void:
	var controller := _new_controller("epsilon lower bound")
	if controller == null:
		return
	var world := _eligible_world()
	controller.call("advance_world_effective", 10.0, world)
	controller.call("advance_world_effective", 119.999998, world)
	var pending: Dictionary = controller.call("public_snapshot")
	_expect(str(pending.get("state", "")) == "audit" and (controller.call("outcome_receipt") as Dictionary).is_empty(), "more than one microsecond remaining never resolves early")
	_expect(float(pending.get("audit_remaining_seconds", 0.0)) > 0.000001, "above-epsilon remainder remains observable")
	controller.call("advance_world_effective", 0.000002, world)
	_expect(str((controller.call("public_snapshot") as Dictionary).get("state", "")) == "resolved", "consuming the true remainder resolves normally")
	controller.free()


func _test_save_load_near_endpoint() -> void:
	var source := _new_controller("near-end save source")
	var restored := _new_controller("near-end save restore")
	if source == null or restored == null:
		_free_controllers([source, restored])
		return
	var world := _eligible_world()
	source.call("advance_world_effective", 5.0, world)
	source.call("advance_world_effective", 5.0, world)
	source.call("advance_world_effective", 119.99, world)
	var applied: Dictionary = restored.call("apply_save_data", source.call("to_save_data"))
	_expect(bool(applied.get("applied", false)) and str((restored.call("public_snapshot") as Dictionary).get("state", "")) == "audit", "near-end audit save loads without changing lifecycle state")
	restored.call("advance_world_effective", 0.01, world)
	_expect(str((restored.call("public_snapshot") as Dictionary).get("state", "")) == "resolved", "restored near-end audit resolves with the remaining split delta")
	_free_controllers([source, restored])

	var checkpoint_source := _new_controller("epsilon save source")
	var checkpoint_restored := _new_controller("epsilon save restore")
	if checkpoint_source == null or checkpoint_restored == null:
		_free_controllers([checkpoint_source, checkpoint_restored])
		return
	var stale_world := _eligible_world("")
	checkpoint_source.call("advance_world_effective", 10.0, stale_world)
	var waiting: Dictionary = checkpoint_source.call("advance_world_effective", 119.9999995, stale_world)
	_expect(str(waiting.get("state", "")) == "audit" and str(waiting.get("reason", "")) == "awaiting_post_world_settlement_checkpoint", "epsilon endpoint still waits for the required settlement checkpoint")
	var checkpoint_applied: Dictionary = checkpoint_restored.call("apply_save_data", checkpoint_source.call("to_save_data"))
	checkpoint_restored.call("advance_world_effective", 0.0, _eligible_world())
	_expect(bool(checkpoint_applied.get("applied", false)) and str((checkpoint_restored.call("public_snapshot") as Dictionary).get("state", "")) == "resolved", "loaded epsilon endpoint resolves on zero-delta checkpoint re-evaluation")
	_free_controllers([checkpoint_source, checkpoint_restored])


func _test_checkpoint_negative_delta_and_pause_contracts() -> void:
	var checkpoint_controller := _new_controller("checkpoint")
	if checkpoint_controller != null:
		var stale_world := _eligible_world("")
		checkpoint_controller.call("advance_world_effective", 10.0, stale_world)
		var waiting: Dictionary = checkpoint_controller.call("advance_world_effective", 120.0, stale_world)
		_expect(str(waiting.get("state", "")) == "audit" and str(waiting.get("reason", "")) == "awaiting_post_world_settlement_checkpoint" and (checkpoint_controller.call("outcome_receipt") as Dictionary).is_empty(), "expired audit cannot resolve before post_world_settlement")
		checkpoint_controller.call("advance_world_effective", 0.0, _eligible_world())
		_expect(str((checkpoint_controller.call("public_snapshot") as Dictionary).get("state", "")) == "resolved", "zero-delta re-evaluation resolves after the checkpoint becomes authoritative")
		checkpoint_controller.free()

	var negative_controller := _new_controller("negative delta")
	if negative_controller != null:
		var negative: Dictionary = negative_controller.call("advance_world_effective", -0.01, _eligible_world())
		_expect(not bool(negative.get("valid", true)) and str(negative.get("reason", "")) == "negative_delta_invalid" and str(negative.get("state", "")) == "idle", "negative delta remains invalid and does not advance the lifecycle")
		negative_controller.free()

	var paused_controller := _new_controller("pause")
	if paused_controller != null:
		var world := _eligible_world()
		paused_controller.call("advance_world_effective", 10.0, world)
		var before_pause := float((paused_controller.call("public_snapshot") as Dictionary).get("audit_remaining_seconds", -1.0))
		var paused_world := _eligible_world()
		paused_world["clock_pause"] = {"menu_paused": true}
		var paused: Dictionary = paused_controller.call("advance_world_effective", 120.0, paused_world)
		var after_pause := float((paused_controller.call("public_snapshot") as Dictionary).get("audit_remaining_seconds", -2.0))
		_expect(str(paused.get("reason", "")) == "paused" and is_equal_approx(before_pause, after_pause) and (paused_controller.call("outcome_receipt") as Dictionary).is_empty(), "pause consumes no audit time and emits no outcome")
		paused_controller.free()


func _completed_controller(qualification_deltas: Array, audit_deltas: Array, label: String) -> Node:
	var controller := _new_controller(label)
	if controller == null:
		return null
	var world := _eligible_world()
	for delta_variant in qualification_deltas:
		controller.call("advance_world_effective", float(delta_variant), world)
	for delta_variant in audit_deltas:
		controller.call("advance_world_effective", float(delta_variant), world)
	_expect(str((controller.call("public_snapshot") as Dictionary).get("state", "")) == "resolved", "%s reaches resolved" % label)
	return controller


func _new_controller(label: String) -> Node:
	var packed := load(CONTROLLER_SCENE_PATH) as PackedScene
	_expect(packed != null, "%s controller scene loads" % label)
	if packed == null:
		return null
	var controller := packed.instantiate()
	_expect(controller != null, "%s controller instantiates" % label)
	if controller == null:
		return null
	root.add_child(controller)
	var configured: Dictionary = controller.call("configure")
	_expect(bool(configured.get("configured", false)), "%s controller configures from v0.6 resources" % label)
	if not bool(configured.get("configured", false)):
		controller.free()
		return null
	return controller


func _eligible_world(checkpoint: String = POST_SETTLEMENT_CHECKPOINT) -> Dictionary:
	var regions: Array = [
		_region(0, 7200, {"0": 3600}),
		_region(1, 7200, {"0": 3600}),
		_region(2, 0, {}),
		_region(3, 0, {}),
		_region(4, 0, {}),
	]
	return {
		"schema_version": "v0.6.victory-world.2",
		"players": [
			{"player_index": 0, "eliminated": false, "cash_ledger_cents": 10000, "audit_assets": {}},
			{"player_index": 1, "eliminated": false, "cash_ledger_cents": 5000, "audit_assets": {}},
		],
		"regions": regions,
		"clock_pause": {},
		"settlement_checkpoint": checkpoint,
	}


func _region(index: int, gdp_cents: int, player_gdp: Dictionary) -> Dictionary:
	return {
		"region_id": "region.%04d" % index,
		"district_index": index,
		"lifecycle_state": "active",
		"destroyed": false,
		"region_gdp_per_minute_cents": gdp_cents,
		"player_gdp_by_index": player_gdp.duplicate(true),
	}


func _repeated_delta(delta_seconds: float, count: int) -> Array:
	var result: Array = []
	for _index in range(count):
		result.append(delta_seconds)
	return result


func _free_controllers(controllers: Array) -> void:
	for controller_variant in controllers:
		if controller_variant is Node and is_instance_valid(controller_variant):
			(controller_variant as Node).free()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print("VICTORY_CONTROL_SPLIT_DELTA_PRECISION_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(_failures.size())
