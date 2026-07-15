extends SceneTree

const REPORT_PATH := "res://reports/ui/production_acceptance/e_quality_evidence_sidecar.md"
const ACCEPTANCE_PATH := "res://reports/ui/production_acceptance/acceptance_results.json"
const RUN_SUMMARY_PATH := "res://reports/ui/production_acceptance/run_summary.json"
const CAPTURE_ROOT := "res://reports/ui/production_acceptance/"
const EXPECTED_CAPTURE_FILES := {
	"first_run_core_table": "01_first_run_core_table_1280x720.png",
	"weather_forecast": "02_weather_forecast_1280x720.png",
	"weather_active": "03_weather_active_1280x720.png",
	"weather_dual": "04_weather_dual_1280x720.png",
	"economy_scrolled": "05_economy_scrolled_1280x720.png",
	"economy_reopened": "06_economy_reopened_1280x720.png",
	"table_modules": "07_card_track_inspector_player_board_1280x720.png",
}
const REQUIRED_REPORT_FACTS := [
	"PARTIAL EVIDENCE; NOT A COMPLETE-MATCH PASS",
	"## Covered real-table evidence at 1280x720",
	"## Missing 1280x720 screenshot matrix",
	"first_run.buy_card",
	"scripted_ui_action_disabled:coach_buy_card",
	"attempted 2, progressed 2",
	"18 required save sections, 8 transactional sections",
	"10 unsupported sections",
	"resume_ready=false",
	"supported=false",
	"attempted=false",
	"reason_code=restore_capability_incomplete",
	"Only seed index 0 was run",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var report := FileAccess.get_file_as_string(REPORT_PATH)
	var acceptance := _read_json_dictionary(ACCEPTANCE_PATH)
	var run_summary := _read_json_dictionary(RUN_SUMMARY_PATH)
	_expect(not report.is_empty(), "focused sidecar report is readable")
	_expect(not acceptance.is_empty() and not run_summary.is_empty(), "production acceptance manifests are readable")

	_expect(str(acceptance.get("status", "")) == "PASS", "headed acceptance manifest records its scoped PASS")
	var capture_size: Array = acceptance.get("capture_size", []) if acceptance.get("capture_size", []) is Array else []
	_expect(capture_size.size() == 2 and int(capture_size[0]) == 1280 and int(capture_size[1]) == 720, "headed acceptance manifest is exactly 1280x720")
	_expect(str(run_summary.get("source_revision", "")) == "0c25b3a421f06fc66dc8cbad172b70334c916f77", "sidecar audits the recorded acceptance revision without rebasing its claim")
	_expect(bool(run_summary.get("default_save_metadata_and_sha256_unchanged", false)), "acceptance records default-save isolation")

	var captures: Dictionary = acceptance.get("captures", {}) if acceptance.get("captures", {}) is Dictionary else {}
	_expect(captures.size() == EXPECTED_CAPTURE_FILES.size(), "primary acceptance has exactly the seven audited capture states")
	for capture_key_variant in EXPECTED_CAPTURE_FILES:
		var capture_key := str(capture_key_variant)
		var expected_file := str(EXPECTED_CAPTURE_FILES[capture_key])
		var capture: Dictionary = captures.get(capture_key, {}) if captures.get(capture_key, {}) is Dictionary else {}
		_expect(str(capture.get("file", "")) == expected_file, "%s maps to its audited 1280 capture" % capture_key)
		_expect(bool(capture.get("pass", false)), "%s retains passing structured metrics" % capture_key)
		_expect(FileAccess.file_exists(CAPTURE_ROOT + expected_file), "%s exists as real evidence" % expected_file)

	for fact_variant in REQUIRED_REPORT_FACTS:
		var fact := str(fact_variant)
		_expect(report.contains(fact), "sidecar states required boundary: %s" % fact)
	_expect(report.count("| MISSING |") == 12, "missing screenshot matrix keeps twelve explicit unproven states")
	_expect(report.contains("does not prove") and report.contains("must not be cited as restore evidence"), "sidecar distinguishes isolation from save/restore proof")
	_finish()


func _read_json_dictionary(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("QUALITY_EVIDENCE_SIDECAR|status=PASS|checks=%d|failures=0|complete_match_claim=false" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("QUALITY_EVIDENCE_SIDECAR: %s" % failure)
	print("QUALITY_EVIDENCE_SIDECAR|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)
