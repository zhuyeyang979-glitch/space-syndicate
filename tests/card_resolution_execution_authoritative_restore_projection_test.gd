extends SceneTree

const FIXTURE := preload("res://tests/fixtures/card_resolution_execution_save_full_state_fixture.gd")
const PROJECTION := preload("res://scripts/tools/execution_authoritative_restore_projection_v1.gd")
const CODEC := preload("res://scripts/runtime/card_resolution_execution_save_wire_codec_v4.gd")

var _checks := 0
var _failures: Array[String] = []
var _scenario_count := 0
var _logical_state_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var idle := FIXTURE.create(self)
	_logical_state_count += 1
	_run_projection_case("idle", idle, (idle.get("execution") as Node).call("to_save_data"))
	FIXTURE.cleanup(idle)

	var transition_scenarios := FIXTURE.build_transition_scenarios(self)
	for scenario in transition_scenarios:
		_logical_state_count += 1
		_run_projection_case(str(scenario.get("scenario_id", "")), scenario.get("fixture", {}) as Dictionary, scenario.get("save", {}) as Dictionary)
		FIXTURE.cleanup(scenario.get("fixture", {}) as Dictionary)

	var rich := FIXTURE.create(self)
	var rich_result := FIXTURE.build_nontrivial_state(rich)
	_expect(bool(rich_result.get("ok", false)), "nontrivial exact-once fixture is valid")
	var rich_save := rich_result.get("save", {}) as Dictionary
	for scenario_id in [
		"retryable_commitment",
		"retryable_history",
		"pending_settlement",
		"nonempty_transition_lineage",
		"promoted_batch",
	]:
		_logical_state_count += 1
		_expect(_rich_state_has_witness(rich_save, scenario_id), "%s has a concrete persisted witness" % scenario_id)
	_run_projection_case("nontrivial_exact_once_bundle", rich, rich_save)
	FIXTURE.cleanup(rich)

	_expect(_scenario_count == 7 and _logical_state_count == 11, "seven unique Save states cover all eleven required logical states")
	_expect(_checks == 42, "every unique Save state executes all five projection gates")
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_AUTHORITATIVE_RESTORE_PROJECTION_TEST|status=%s|checks=%d|failures=%d|scenarios=%d" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(), _scenario_count
	])
	if not _failures.is_empty():
		push_error("Execution authoritative projection failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _run_projection_case(scenario_id: String, source_fixture: Dictionary, save_a: Dictionary) -> void:
	_scenario_count += 1
	var source_owner := source_fixture.get("execution") as CardResolutionExecutionRuntimeService
	var source_transition := source_fixture.get("transition") as CardResolutionRuntimeController
	var projection_a := PROJECTION.capture(source_owner, source_transition)
	var target := FIXTURE.create(self)
	var target_owner := target.get("execution") as CardResolutionExecutionRuntimeService
	var target_transition := target.get("transition") as CardResolutionRuntimeController
	var applied := target_owner.apply_save_data(save_a)
	var projection_b := PROJECTION.capture(target_owner, target_transition)
	var save_b := target_owner.to_save_data()
	var comparison := PROJECTION.compare(projection_a, projection_b)
	var diagnostics := PROJECTION.diagnostic_canonicalization(target_owner)
	_expect(bool(projection_a.get("ok", false)) and bool(projection_b.get("ok", false)), "%s projections validate" % scenario_id)
	_expect(bool(applied.get("applied", false)) and save_a == save_b, "%s Save A equals Save B" % scenario_id)
	_expect(bool(comparison.get("green", false)), "%s authoritative projection A equals B" % scenario_id)
	_expect(int(projection_b.get("field_coverage_percent", 0)) == 100 \
			and int(projection_b.get("save_v4_field_omission_count", -1)) == 0 \
			and int(projection_b.get("exact_once_field_omission_count", -1)) == 0 \
			and bool(projection_b.get("typed_authoritative_query_parity", false)), "%s projection covers every Save field and typed query" % scenario_id)
	_expect(bool(diagnostics.get("ok", false)), "%s diagnostics canonicalize independently" % scenario_id)
	FIXTURE.cleanup(target)


func _rich_state_has_witness(save: Dictionary, scenario_id: String) -> bool:
	var decoded := CODEC.decode_save_state(save)
	if not bool(decoded.get("ok", false)) or not (decoded.get("value") is Dictionary):
		return false
	var runtime := decoded.get("value") as Dictionary
	var inflight := runtime.get("inflight_execution_transactions", []) as Array
	match scenario_id:
		"retryable_commitment":
			return _has_next_intent(inflight, "finish_card_commitment", "retryable")
		"retryable_history":
			return _has_next_intent(inflight, "append_history", "retryable")
		"pending_settlement":
			return not (runtime.get("pending_settlements", []) as Array).is_empty()
		"nonempty_transition_lineage":
			return not ((runtime.get("transition_controller", {}) as Dictionary).get("card_transition_applied_lineage", []) as Array).is_empty()
		"promoted_batch":
			return _has_next_intent(inflight, "promote_next_batch", "ready")
	return false


func _has_next_intent(records: Array, intent_type: String, status: String) -> bool:
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record := record_variant as Dictionary
		var next_intent := record.get("next_intent", {}) as Dictionary
		if str(record.get("status", "")) == status and str(next_intent.get("intent_type", "")) == intent_type:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
