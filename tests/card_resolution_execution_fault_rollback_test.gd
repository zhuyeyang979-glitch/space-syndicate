extends SceneTree

const FIXTURE := preload("res://tests/fixtures/card_resolution_execution_save_full_state_fixture.gd")
const SAVE_CODEC := preload("res://scripts/runtime/card_resolution_execution_save_wire_codec_v4.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FIXTURE.create(self)
	var rich := FIXTURE.build_nontrivial_state(source)
	var checkpoint_a := rich.get("save", {}) as Dictionary
	var target := FIXTURE.create(self)
	var owner := target.get("execution") as CardResolutionExecutionRuntimeService
	_expect(bool(owner.apply_save_data(checkpoint_a).get("applied", false)), "fault target starts from checkpoint A")

	var forged_runtime := (SAVE_CODEC.decode_save_state(checkpoint_a).get("value", {}) as Dictionary).duplicate(true)
	var records := forged_runtime.get("inflight_execution_transactions", []) as Array
	var forged_transaction := (records[0] as Dictionary).duplicate(true)
	var forged_intent := (forged_transaction.get("next_intent") as Dictionary).duplicate(true)
	forged_intent["intent_type"] = "dispatch_effect"
	forged_intent["handler_id"] = str(forged_transaction.get("handler_id", ""))
	forged_transaction["next_intent"] = forged_intent
	records[0] = forged_transaction
	forged_runtime["inflight_execution_transactions"] = records
	var forged_wire := SAVE_CODEC.encode_save_state(forged_runtime).get("value", {}) as Dictionary
	var before_fault := owner.to_save_data()
	var rejected := owner.apply_save_data(forged_wire)
	_expect(not bool(rejected.get("applied", true)), "forged intent lineage fails strict preflight")
	_expect(owner.to_save_data() == before_fault, "preflight failure leaves owner, Transition, and world-facing state untouched")

	var controller := target.get("transition") as CardResolutionRuntimeController
	owner.resume_inflight_execution(4104)
	controller.reset_state()
	controller.begin_active_display(0.875)
	var state_after_hypothetical_downstream_fault := owner.to_save_data()
	_expect(state_after_hypothetical_downstream_fault != checkpoint_a, "a prior owner apply can be observed before a downstream registry fault")
	var rollback := owner.apply_save_data(checkpoint_a)
	var checkpoint_b := owner.to_save_data()
	_expect(bool(rollback.get("applied", false)) and checkpoint_b == checkpoint_a, "registry fault rollback restores exact checkpoint A")

	FIXTURE.cleanup(source)
	FIXTURE.cleanup(target)
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_FAULT_ROLLBACK_TEST|status=%s|checks=%d|failures=%d|rollback_green=%s" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(), str(checkpoint_b == checkpoint_a).to_lower()
	])
	if not _failures.is_empty():
		push_error("Execution fault rollback failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
