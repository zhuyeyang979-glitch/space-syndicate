extends SceneTree

const DriverScript := preload("res://scripts/tools/full_run_quality_driver.gd")
const SnapshotScript := preload("res://scripts/viewmodels/full_run_quality_snapshot.gd")
const DRIVER_PATH := "res://scripts/tools/full_run_quality_driver.gd"
const SNAPSHOT_PATH := "res://scripts/viewmodels/full_run_quality_snapshot.gd"
const EXPECTED_SEEDS: Array[int] = [
	900626424,
	865984508,
	1419123495,
	1471257297,
	2038431333,
	948459684,
	1635321996,
	1280235321,
	899123644,
	43885519,
	950436207,
	102090361,
	124449428,
	545676743,
	1471036570,
	1968730869,
	1969748911,
	853285161,
	1765914414,
	1515999483,
]
const REQUIRED_TELEMETRY_KEYS := [
	"seed",
	"phase",
	"elapsed",
	"decision_window",
	"settlement",
	"invalid_actions",
	"nonfinite",
	"last_event",
]
const FORBIDDEN_DRIVER_TOKENS := [
	"_capture_run_state",
	"_apply_run_state",
	"_save_run",
	"resolve_victory_outcome",
	"advance_victory_control",
	"finish_session",
	"_apply_victory_outcome_receipt",
	"set(\"cash\"",
	"set(\"gdp\"",
	"scripts/main.gd",
	"scenes/ui/",
]
const FORBIDDEN_PUBLIC_KEYS := [
	"players",
	"cash",
	"cash_cents",
	"hand",
	"slots",
	"discard",
	"owner",
	"owner_id",
	"owner_player_index",
	"hidden_owner",
	"city_guesses",
	"ai_memory",
	"ai_plan",
	"utility_scores",
	"raw_envelope",
	"envelope",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var driver_source := FileAccess.get_file_as_string(DRIVER_PATH)
	var snapshot_source := FileAccess.get_file_as_string(SNAPSHOT_PATH)
	_expect(not driver_source.is_empty() and not snapshot_source.is_empty(), "driver and telemetry source are readable")
	_expect(DriverScript.DRIVER_ID == "full_run_quality_driver_v2" and DriverScript.FIXED_SEEDS == EXPECTED_SEEDS, "driver carries one versioned execution contract and the audited seed set")
	_expect(bool(DriverScript.public_output_contract().get("single_run_only", false)), "this atomic block executes one seed and cannot claim a twenty-run completion rate")
	_expect(DriverScript.SIMULATION_TIME_SCALE > 1.0 and driver_source.contains('main_instance.set("time_scale", SIMULATION_TIME_SCALE)'), "test-only time acceleration stays inside the driver and does not add a production UI control")

	_expect(driver_source.contains("res://scenes/main.tscn") and driver_source.contains("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"), "driver instantiates the real Main scene and current Coordinator composition")
	_expect(driver_source.contains("_first_run_recommended_setup") and driver_source.contains("_confirm_start_new_run_from_setup"), "driver starts the real recommended four-seat session")
	_expect(driver_source.contains('runtime_screen.emit_signal("action_requested", action_id)'), "scripted human submits only action ids through the real GameScreen signal")
	_expect(driver_source.contains("world_effective_clock_snapshot") and driver_source.contains("victory_control_public_snapshot") and driver_source.contains("active_forced_decision"), "telemetry reads the authoritative clock, public victory state, and viewer-scoped decision window")
	_expect(driver_source.contains("FinalSettlementRuntimeComposition") and driver_source.contains("last_public_snapshot"), "driver observes the real final-settlement composition without forcing an outcome")
	_expect(driver_source.contains("registry_snapshot") and driver_source.contains("capture_resume_envelope") and driver_source.contains("restore_capability_incomplete"), "save continuation remains explicitly fail-closed while owner coverage is incomplete")
	_expect(driver_source.contains("scripted_ui_action_no_progress") and driver_source.contains("scripted_ui_action_disabled") and driver_source.contains("scripted_guidance_exhausted_before_settlement"), "driver reports an exact scripted-player stall or disabled action instead of claiming completion")
	_expect(driver_source.contains("observation_window_elapsed_before_settlement") and driver_source.contains("driver_wall_timeout"), "bounded observation and wall timeout have distinct failure codes")
	_expect(not driver_source.contains('"completion_rate"') and not driver_source.contains('"completed_runs"'), "single-run output cannot masquerade as aggregate quality evidence")

	for token in FORBIDDEN_DRIVER_TOKENS:
		_expect(not driver_source.contains(token), "driver excludes forbidden runtime shortcut: %s" % token)
	_expect(driver_source.count("print(") == 1 and driver_source.contains("print(JSON.stringify(payload))"), "all driver console output uses one NDJSON emitter")

	var sample := SnapshotScript.compose({
		"seed": EXPECTED_SEEDS[0],
		"phase": "decision_window.contract_response",
		"elapsed": {"wall_seconds": 2.5, "world_seconds": 10.0},
		"decision_window": {
			"active": true,
			"kind": "contract_response",
			"priority_group": "contract_response",
			"blocks_global_time": true,
			"blocks_player_actions": true,
			"visible_to_scripted_player": true,
		},
		"settlement": {
			"state": "audit",
			"completed": false,
			"outcome_id": "",
			"reason_code": "",
			"winner_count": 0,
			"presentation_ready": false,
		},
		"invalid_actions": {"count": 1, "last_reason_code": "ui_action_no_progress"},
		"last_event": "action_requested:contract_accept",
		"observed_public_facts": {"clock": 10.0, "probe": INF},
	})
	_expect(bool(sample.get("valid", false)) and int(sample.get("seed", 0)) == EXPECTED_SEEDS[0], "telemetry accepts aggregate public facts and preserves the fixed seed")
	_expect(_contains_all(sample, REQUIRED_TELEMETRY_KEYS), "telemetry exposes seed, phase, elapsed, decision, settlement, invalid-action, nonfinite, and last-event fields")
	_expect(str(sample.get("phase", "")) == "decision_window.contract_response", "telemetry keeps the exact public decision phase")
	_expect(int((sample.get("invalid_actions", {}) as Dictionary).get("count", 0)) == 1, "telemetry preserves the aggregate invalid-action count")
	_expect(int((sample.get("nonfinite", {}) as Dictionary).get("count", 0)) == 1 and (sample.get("nonfinite", {}) as Dictionary).get("paths", []) == ["public.probe"], "telemetry detects a non-finite public runtime fact without serializing its value")
	_expect(not _contains_forbidden_key(sample), "composed telemetry contains no player cash, hand, owner truth, or AI-private key")

	var rejected := SnapshotScript.compose({
		"seed": EXPECTED_SEEDS[0],
		"phase": "play",
		"hand": ["PRIVATE_CARD_SENTINEL"],
	})
	_expect(not bool(rejected.get("valid", true)) and str((rejected.get("invalid_actions", {}) as Dictionary).get("last_reason_code", "")) == "telemetry_input_not_public", "telemetry fails closed before a private hand can enter the public output")
	_expect(not JSON.stringify(rejected).contains("PRIVATE_CARD_SENTINEL"), "fail-closed telemetry never echoes a private value")

	var contract: Dictionary = DriverScript.public_output_contract()
	var telemetry_contract: Dictionary = contract.get("telemetry", {}) if contract.get("telemetry", {}) is Dictionary else {}
	_expect(_same_members(telemetry_contract.get("public_keys", []) as Array, SnapshotScript.PUBLIC_KEYS), "driver publishes the exact telemetry schema")
	_expect(_same_members(contract.get("capability_keys", []) as Array, DriverScript.CAPABILITY_PUBLIC_KEYS), "capability output is explicit and aggregate-only")
	_expect(_public_contract_is_safe(contract), "driver and telemetry contracts exclude private runtime fields")

	var qa_scope := DriverScript.qa_save_directory("abc123", EXPECTED_SEEDS[0])
	_expect(qa_scope == "user://test_runs/full_run_quality/abc123/%d/" % EXPECTED_SEEDS[0], "QA save scope is isolated by head and seed")
	_finish()


func _contains_all(source: Dictionary, keys: Array) -> bool:
	for key_variant in keys:
		if not source.has(str(key_variant)):
			return false
	return true


func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if FORBIDDEN_PUBLIC_KEYS.has(str(key_variant).to_lower()):
				return true
			if _contains_forbidden_key((value as Dictionary).get(key_variant)):
				return true
		return false
	if value is Array:
		for item_variant in value as Array:
			if _contains_forbidden_key(item_variant):
				return true
	return false


func _public_contract_is_safe(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			if FORBIDDEN_PUBLIC_KEYS.has(key):
				return false
			if not _public_contract_is_safe((value as Dictionary).get(key_variant)):
				return false
		return true
	if value is Array:
		for item_variant in value as Array:
			if str(item_variant).to_lower() in FORBIDDEN_PUBLIC_KEYS:
				return false
			if not _public_contract_is_safe(item_variant):
				return false
	return true


func _same_members(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for value in left:
		if not right.has(value):
			return false
	return true


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("FULL_RUN_QUALITY_DRIVER_CONTRACT|status=PASS|checks=%d|failures=0|single_run=true" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("FULL_RUN_QUALITY_DRIVER_CONTRACT: %s" % failure)
	print("FULL_RUN_QUALITY_DRIVER_CONTRACT|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)
