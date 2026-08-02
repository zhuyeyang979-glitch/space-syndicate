extends SceneTree

const FIXTURE := preload("res://tests/fixtures/card_resolution_execution_save_full_state_fixture.gd")
const HISTORY_SCENE := preload("res://scenes/runtime/CardResolutionHistoryRuntimeService.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FIXTURE.create(self)
	var rich := FIXTURE.build_nontrivial_state(source)
	var history_source := HISTORY_SCENE.instantiate() as CardResolutionHistoryRuntimeService
	(source.get("host") as Node).add_child(history_source)
	history_source.configure({})
	var history_entry := {"resolution_id": 4105, "resolved": true, "resolution_outcome": "resolved"}
	_expect(bool(history_source.append_resolved(history_entry).get("appended", false)), "History mutation succeeds before its response is lost")
	var execution_json_variant: Variant = JSON.parse_string(JSON.stringify(rich.get("save", {})))
	var history_checkpoint := history_source.to_save_data()

	var target := FIXTURE.create(self)
	var owner := target.get("execution") as CardResolutionExecutionRuntimeService
	var history_target := HISTORY_SCENE.instantiate() as CardResolutionHistoryRuntimeService
	(target.get("host") as Node).add_child(history_target)
	history_target.configure({})
	_expect(execution_json_variant is Dictionary \
			and bool(owner.apply_save_data(execution_json_variant as Dictionary).get("applied", false)) \
			and bool(history_target.apply_save_data(history_checkpoint).get("applied", false)), "Execution and History owners restore together")
	var transaction := owner.resume_inflight_execution(4105)
	_expect(str((transaction.get("next_intent", {}) as Dictionary).get("intent_type", "")) == "append_history", "restored cursor resumes only the uncertain history acknowledgement")
	var before_retry := history_target.debug_snapshot()
	var history_retry := history_target.append_resolved(history_entry)
	var appended_or_duplicate := bool(history_retry.get("appended", false)) or bool(history_retry.get("duplicate", false))
	transaction = owner.advance_execution(transaction, {
		"intent_type": "append_history",
		"appended": appended_or_duplicate,
		"current_queue_count": 0,
	})
	var after_retry := history_target.debug_snapshot()
	_expect(bool(history_retry.get("duplicate", false)) \
			and int(after_retry.get("history_count", -1)) == 1 \
			and int(after_retry.get("append_count", -1)) == int(before_retry.get("append_count", -2)), "duplicate history acknowledgement causes zero duplicate history mutation")
	_expect(str((transaction.get("next_intent", {}) as Dictionary).get("intent_type", "")) == "finish_batch" \
			and bool(transaction.get("effect_dispatched", false)) \
			and bool(transaction.get("commitment_checked", false)), "effect and commitment stay completed without replay")
	transaction = owner.advance_execution(transaction, {
		"intent_type": "finish_batch",
		"finished": true,
		"next_queue_count": 0,
	})
	_expect((transaction.get("next_intent", {}) as Dictionary).is_empty(), "history retry continues once to completion")

	FIXTURE.cleanup(source)
	FIXTURE.cleanup(target)
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_RETRYABLE_HISTORY_RESTORE_TEST|status=%s|checks=%d|failures=%d|duplicate_effect_dispatch=0|duplicate_history_append=0" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()
	])
	if not _failures.is_empty():
		push_error("Retryable history restore failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
