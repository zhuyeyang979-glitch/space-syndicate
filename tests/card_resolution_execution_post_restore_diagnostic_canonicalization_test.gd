extends SceneTree

const FIXTURE := preload("res://tests/fixtures/card_resolution_execution_save_full_state_fixture.gd")
const PROJECTION := preload("res://scripts/tools/execution_authoritative_restore_projection_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FIXTURE.create(self)
	var rich := FIXTURE.build_nontrivial_state(source)
	_expect(bool(rich.get("ok", false)), "source creates noncanonical pre-restore diagnostic state")
	var source_owner := source.get("execution") as CardResolutionExecutionRuntimeService
	var source_debug := source_owner.debug_snapshot()
	_expect(str(source_debug.get("last_phase", "")) != "restored" \
			and not PROJECTION.POST_RESTORE_REASONS.has(str(source_debug.get("last_reason", ""))) \
			and source_debug.get("last_summary") is Dictionary, "source phase and reason are genuinely noncanonical while summary shape is valid")
	var save_a := rich.get("save", {}) as Dictionary

	var target := FIXTURE.create(self)
	var target_owner := target.get("execution") as CardResolutionExecutionRuntimeService
	var applied := target_owner.apply_save_data(save_a)
	var report := PROJECTION.diagnostic_canonicalization(target_owner)
	_expect(bool(applied.get("applied", false)), "Save v4 restore succeeds")
	_expect(bool(report.get("post_restore_diagnostic_phase_canonical", false)), "last_phase canonicalizes to restored")
	_expect(bool(report.get("post_restore_diagnostic_reason_canonical", false)), "last_reason canonicalizes to an attested restore reason")
	_expect(bool(report.get("post_restore_diagnostic_summary_canonical", false)), "last_summary canonicalizes to an empty Dictionary")
	_expect(int(report.get("diagnostic_fields_persisted_to_save_count", -1)) == 0 \
			and not save_a.has("last_phase") and not save_a.has("last_reason") and not save_a.has("last_summary"), "diagnostic fields are not persisted into Save v4")

	FIXTURE.cleanup(source)
	FIXTURE.cleanup(target)
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_POST_RESTORE_DIAGNOSTIC_CANONICALIZATION_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()
	])
	if not _failures.is_empty():
		push_error("Execution diagnostic canonicalization failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
