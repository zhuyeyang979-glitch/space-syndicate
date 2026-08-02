extends SceneTree

const FIXTURE := preload("res://tests/fixtures/card_resolution_execution_save_full_state_fixture.gd")
const SAVE_CODEC := preload("res://scripts/runtime/card_resolution_execution_save_wire_codec_v4.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := FIXTURE.create(self)
	var owner := fixture.get("execution") as CardResolutionExecutionRuntimeService
	var controller := fixture.get("transition") as CardResolutionRuntimeController
	var rich := FIXTURE.build_nontrivial_state(fixture)
	var checkpoint_a := rich.get("save", {}) as Dictionary
	_expect(bool(rich.get("ok", false)) and bool(owner.preflight_save_data(checkpoint_a).get("accepted", false)), "Registry captures a valid Execution Save v4 checkpoint A")
	var raw_a := SAVE_CODEC.decode_save_state(checkpoint_a).get("value", {}) as Dictionary

	var resumed := owner.resume_inflight_execution(4104)
	_expect(str(resumed.get("status", "")) == "ready", "transaction state changes after checkpoint capture")
	var pending := owner.pending_settlement(4106)
	var finalized := pending.get("finalized", {}) as Dictionary
	var settlement_receipt := {
		"settled": true,
		"resolution_id": 4106,
		"execution_id": int(pending.get("execution_id", -1)),
		"settlement_binding": (finalized.get("settlement_binding", {}) as Dictionary).duplicate(true),
		"settlement_binding_fingerprint": str(finalized.get("settlement_binding_fingerprint", "")),
	}
	_expect(bool(owner.complete_pending_settlement(4106, settlement_receipt).get("completed", false)), "pending settlement changes after checkpoint capture")
	controller.reset_state()
	controller.begin_group_window(-1.0, 1, 0)
	controller.begin_active_display(1.75)
	var mutated := owner.to_save_data()
	_expect(mutated != checkpoint_a, "timer, cadence, transaction, settlement, and lineage mutations change the checkpoint")

	var rollback := owner.apply_save_data(checkpoint_a)
	var checkpoint_b := owner.to_save_data()
	_expect(bool(rollback.get("applied", false)) and checkpoint_b == checkpoint_a, "registry-managed rollback restores checkpoint B equal to A")
	var raw_b := SAVE_CODEC.decode_save_state(checkpoint_b).get("value", {}) as Dictionary
	var transition_a := raw_a.get("transition_controller", {}) as Dictionary
	var transition_b := raw_b.get("transition_controller", {}) as Dictionary
	_expect(transition_a == transition_b, "timer, cadence, and Transition lineage restore exactly")
	_expect(raw_a.get("inflight_execution_transactions") == raw_b.get("inflight_execution_transactions"), "inflight transactions restore exactly")
	_expect(raw_a.get("pending_settlements") == raw_b.get("pending_settlements"), "pending settlement restores exactly")
	_expect(not owner.has_method("capture_runtime_checkpoint") and not owner.has_method("restore_runtime_checkpoint"), "rollback uses to_save_data/apply_save_data without a second checkpoint API")

	FIXTURE.cleanup(fixture)
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_REGISTRY_MANAGED_CHECKPOINT_TEST|status=%s|checks=%d|failures=%d|a_equals_b=%s" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(), str(checkpoint_a == checkpoint_b).to_lower()
	])
	if not _failures.is_empty():
		push_error("Execution registry-managed checkpoint failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
