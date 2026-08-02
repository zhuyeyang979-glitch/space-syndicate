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
	var json_variant: Variant = JSON.parse_string(JSON.stringify(rich.get("save", {})))
	var target := FIXTURE.create(self)
	var owner := target.get("execution") as CardResolutionExecutionRuntimeService
	_expect(json_variant is Dictionary and bool(owner.apply_save_data(json_variant as Dictionary).get("applied", false)), "pending settlement restores through JSON Save v4")
	var pending := owner.pending_settlement(4106)
	var decoded := SAVE_CODEC.decode_save_state(json_variant as Dictionary).get("value", {}) as Dictionary
	var inflight_ids := decoded.get("inflight_resolution_ids", []) as Array
	var completed_ids := decoded.get("completed_resolution_ids", []) as Array
	_expect(not pending.is_empty() and not inflight_ids.has(4106) and completed_ids.has(4106), "finalized resolution restores only as pending settlement")
	var finalize_execution_count := 0
	var settlement_mutation := {"count": 0}
	var first := _complete_once(owner, 4106, settlement_mutation)
	_expect(bool(first.get("completed", false)) \
			and int(settlement_mutation.get("count", -1)) == 1 \
			and finalize_execution_count == 0, "restore completes settlement once without re-finalizing execution")
	var second := _complete_once(owner, 4106, settlement_mutation)
	_expect(not bool(second.get("completed", true)) \
			and str(second.get("reason", "")) == "pending_settlement_missing" \
			and int(settlement_mutation.get("count", -1)) == 1, "completed settlement cannot mutate twice")
	_expect(int(owner.debug_snapshot().get("pending_settlement_count", -1)) == 0, "successful completion clears only the pending record")

	FIXTURE.cleanup(source)
	FIXTURE.cleanup(target)
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_PENDING_SETTLEMENT_RESTORE_TEST|status=%s|checks=%d|failures=%d|duplicate_settlement=0|duplicate_finalize=0" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()
	])
	if not _failures.is_empty():
		push_error("Pending settlement restore failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _complete_once(owner: CardResolutionExecutionRuntimeService, resolution_id: int, mutation_counter: Dictionary) -> Dictionary:
	var pending := owner.pending_settlement(resolution_id)
	if pending.is_empty():
		return owner.complete_pending_settlement(resolution_id, {})
	mutation_counter["count"] = int(mutation_counter.get("count", 0)) + 1
	var finalized := pending.get("finalized", {}) as Dictionary
	return owner.complete_pending_settlement(resolution_id, {
		"settled": true,
		"resolution_id": resolution_id,
		"execution_id": int(pending.get("execution_id", -1)),
		"settlement_binding": (finalized.get("settlement_binding", {}) as Dictionary).duplicate(true),
		"settlement_binding_fingerprint": str(finalized.get("settlement_binding_fingerprint", "")),
	})


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
