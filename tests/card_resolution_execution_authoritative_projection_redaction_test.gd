extends SceneTree

const FIXTURE := preload("res://tests/fixtures/card_resolution_execution_save_full_state_fixture.gd")
const PROJECTION := preload("res://scripts/tools/execution_authoritative_restore_projection_v1.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FIXTURE.create(self)
	var rich := FIXTURE.build_nontrivial_state(source)
	var source_projection := PROJECTION.capture(
		source.get("execution") as Node,
		source.get("transition") as Node
	)
	var target := FIXTURE.create(self)
	var owner := target.get("execution") as CardResolutionExecutionRuntimeService
	var applied := owner.apply_save_data(rich.get("save", {}) as Dictionary)
	var target_projection := PROJECTION.capture(owner, target.get("transition") as Node)
	var comparison := PROJECTION.compare(source_projection, target_projection)
	var diagnostics := PROJECTION.diagnostic_canonicalization(owner)
	var exact_once := {
		"green": true,
		"duplicate_effect_dispatch_count": 0,
		"duplicate_card_commitment_count": 0,
		"duplicate_history_append_count": 0,
		"duplicate_settlement_count": 0,
		"duplicate_transition_command_apply_count": 0,
	}
	var evidence := PROJECTION.redacted_evidence(
		source_projection, target_projection, comparison, diagnostics, exact_once
	)
	_expect(bool(rich.get("ok", false)) and bool(applied.get("applied", false)), "nontrivial private fixture restores before redaction")
	_expect(_has_exact_fields(evidence, PROJECTION.REDACTED_EVIDENCE_FIELDS), "redacted evidence uses one exact schema")
	_expect(WIRE.is_closed_data(evidence) and bool(evidence.get("private_payload_redacted", false)), "redacted evidence is closed and marked private-safe")
	_expect((evidence.get("parity_excluded_paths", []) as Array) == [
		"$.owner_debug.last_phase",
		"$.owner_debug.last_reason",
	] and int(evidence.get("parity_exclusion_wildcard_count", -1)) == 0, "only two attested paths are excluded and no wildcard exists")
	var serialized := JSON.stringify(evidence)
	var forbidden_count := 0
	for forbidden in [
		'"projection":',
		'"decoded_runtime":',
		'"skill":',
		'"selection_context":',
		'"active_entry":',
		'"target_binding":',
		'"inflight_execution_transactions":',
		'"pending_settlements":',
	]:
		if serialized.contains(forbidden):
			forbidden_count += 1
	_expect(forbidden_count == 0, "redacted evidence contains no wire, private transaction, target, or pending records")
	FIXTURE.cleanup(source)
	FIXTURE.cleanup(target)
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_AUTHORITATIVE_PROJECTION_REDACTION_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Execution authoritative projection redaction failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant: Variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
