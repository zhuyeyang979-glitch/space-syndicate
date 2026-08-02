extends SceneTree

const FIXTURE := preload("res://tests/fixtures/card_resolution_execution_save_full_state_fixture.gd")

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
	_expect(json_variant is Dictionary and bool(owner.apply_save_data(json_variant as Dictionary).get("applied", false)), "retryable commitment restores through JSON Save v4")
	var transaction := owner.resume_inflight_execution(4104)
	_expect(str((transaction.get("next_intent", {}) as Dictionary).get("intent_type", "")) == "finish_card_commitment", "restored cursor resumes at the failed commitment only")
	var attempted_intents: Array[String] = []
	var commitment_mutation_count := 0
	var history_mutation_count := 0
	var guard := 0
	while not (transaction.get("next_intent", {}) as Dictionary).is_empty() and guard < 20:
		guard += 1
		var intent_type := str((transaction.get("next_intent", {}) as Dictionary).get("intent_type", ""))
		attempted_intents.append(intent_type)
		if intent_type == "finish_card_commitment":
			commitment_mutation_count += 1
		if intent_type == "append_history":
			history_mutation_count += 1
		transaction = owner.advance_execution(transaction, _success_receipt(intent_type))
	var duplicate_effect_dispatch_count := attempted_intents.count("dispatch_effect")
	var duplicate_card_commitment_count := maxi(0, commitment_mutation_count - 1)
	_expect(attempted_intents[0] == "finish_card_commitment" \
			and duplicate_effect_dispatch_count == 0 \
			and attempted_intents.count("counter_check") == 0 \
			and attempted_intents.count("release_active") == 0 \
			and attempted_intents.count("finish_presentation") == 0 \
			and attempted_intents.count("revalidate_requirement") == 0 \
			and attempted_intents.count("revalidate_target") == 0, "restore never replays pre-commitment side effects")
	_expect(commitment_mutation_count == 1 and duplicate_card_commitment_count == 0, "failed-before-mutation commitment is committed exactly once after restore")
	_expect(history_mutation_count == 1 and (transaction.get("next_intent", {}) as Dictionary).is_empty(), "post-commitment lineage advances to one history append and completion")
	var facility_transaction := owner.resume_inflight_execution(4107)
	var facility_attempts: Array[String] = []
	guard = 0
	while not (facility_transaction.get("next_intent", {}) as Dictionary).is_empty() and guard < 20:
		guard += 1
		var facility_intent := str((facility_transaction.get("next_intent", {}) as Dictionary).get("intent_type", ""))
		facility_attempts.append(facility_intent)
		facility_transaction = owner.advance_execution(facility_transaction, _success_receipt(facility_intent))
	_expect(not facility_attempts.is_empty() \
			and facility_attempts[0] == "finish_card_commitment" \
			and facility_attempts.count("dispatch_effect") == 0 \
			and facility_attempts.count("finish_card_commitment") == 1, "facility commitment retry resumes its settlement leg without redispatching the effect")

	FIXTURE.cleanup(source)
	FIXTURE.cleanup(target)
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_RETRYABLE_COMMITMENT_RESTORE_TEST|status=%s|checks=%d|failures=%d|duplicate_effect_dispatch=0|duplicate_card_commitment=%d" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(), duplicate_card_commitment_count
	])
	if not _failures.is_empty():
		push_error("Retryable commitment restore failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _success_receipt(intent_type: String) -> Dictionary:
	var receipt := {"intent_type": intent_type}
	match intent_type:
		"finish_card_commitment":
			receipt["committed"] = true
			receipt["commitment_settled"] = true
		"create_aftermath": receipt["entry_patch"] = {"restored_aftermath": true}
		"restore_context": receipt["restored"] = true
		"append_history":
			receipt["appended"] = true
			receipt["current_queue_count"] = 0
		"finish_batch":
			receipt["finished"] = true
			receipt["next_queue_count"] = 0
		"start_next": receipt["started"] = true
		"promote_next_batch": receipt["promoted"] = true
	return receipt


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
