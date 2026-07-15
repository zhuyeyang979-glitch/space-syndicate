extends SceneTree

const DriverScript := preload("res://scripts/tools/full_run_quality_driver.gd")
const DRIVER_PATH := "res://scripts/tools/full_run_quality_driver.gd"
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
const FORBIDDEN_DRIVER_TOKENS := [
	"_capture_run_state",
	"_apply_run_state",
	"_save_run",
	"planet_destroyed",
	"resolve_special_outcome",
	"resolve_victory_outcome",
	"_apply_victory_outcome_receipt",
	"scripts/main.gd",
	"ActionResult",
	"scenes/ui/",
]
const FORBIDDEN_PUBLIC_KEYS := [
	"envelope",
	"raw_envelope",
	"hand",
	"discard",
	"cash",
	"owner",
	"ai_memory",
	"ai_plan",
	"private_fingerprint",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string(DRIVER_PATH)
	_expect(not source.is_empty(), "driver source is readable")
	_expect(DriverScript.FIXED_SEEDS == EXPECTED_SEEDS and DriverScript.FIXED_SEEDS.size() == 20, "driver locks the twenty audited deterministic seeds")
	_expect(DriverScript.SEED_ALGORITHM == "space-syndicate-full-run-quality-v1:sha256-positive31", "seed algorithm carries a stable version label")
	_expect(source.contains("--preflight-only") and source.contains("--seed-index") and source.contains("--max-wall-seconds"), "driver exposes the three bounded command-line options")
	_expect(source.contains("OS.get_cmdline_user_args()") and source.contains("DEFAULT_MAX_WALL_SECONDS") and source.contains("_wall_timed_out"), "arguments and wall timeout are explicit")

	_expect(source.contains("res://scenes/main.tscn") and source.contains("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"), "driver loads the real Main scene and current Coordinator composition")
	_expect(source.contains("registry_snapshot") and source.contains("capture_resume_envelope"), "driver asks the current registry for public capability and a fail-closed capture probe")
	_expect(source.contains("required_sections == REQUIRED_SECTION_COUNT") and source.contains("transactional_sections == REQUIRED_SECTION_COUNT"), "driver requires all eighteen sections to be transactional")
	_expect(source.contains("rng_state_transactional") and source.contains("rng_authority_unique"), "driver requires explicit unique RNG continuation authority")
	_expect(source.contains("complete_player_state_transactional") and source.contains("player_state_authority_unique"), "driver requires explicit complete player continuation authority")
	_expect(source.contains("restore_capability_incomplete") and source.contains("EXIT_CAPABILITY_INCOMPLETE") and DriverScript.EXIT_CAPABILITY_INCOMPLETE != 0, "incomplete restore capability exits fail-closed with a nonzero code")

	_expect(source.contains("blocked_by_capability") and source.contains("blocked_by_driver_implementation"), "unreachable stages never masquerade as completed runs")
	_expect(source.contains('"completed": false') and not source.contains('"completed": true'), "driver skeleton contains no direct success placeholder")
	_expect(source.contains("HEARTBEAT_INTERVAL_SECONDS := 5") and source.contains('"type": "heartbeat"') and source.contains('"type": "summary"'), "five-second heartbeat and NDJSON summary contracts are declared")
	_expect(source.count("print(") == 1 and source.contains("print(JSON.stringify(payload))"), "all console output uses the single NDJSON emitter")

	var qa_scope := DriverScript.qa_save_directory("abc123", EXPECTED_SEEDS[0])
	_expect(qa_scope == "user://test_runs/full_run_quality/abc123/%d/" % EXPECTED_SEEDS[0], "QA save scope is isolated by head and seed")
	_expect(source.contains("set_qa_default_save_path_override") and source.contains('"attempted": false'), "preflight installs an isolated path and does not claim a save attempt")
	_expect(not source.contains("FileAccess.open") and not source.contains("DirAccess.make_dir") and not source.contains("ResourceSaver.save"), "preflight skeleton performs no direct file write")

	var public_contract: Dictionary = DriverScript.public_output_contract()
	_expect(_same_members(public_contract.get("heartbeat_keys", []) as Array, DriverScript.HEARTBEAT_PUBLIC_KEYS), "heartbeat schema is explicit and stable")
	_expect(_same_members(public_contract.get("summary_keys", []) as Array, DriverScript.SUMMARY_PUBLIC_KEYS), "summary schema is explicit and stable")
	_expect(_same_members(public_contract.get("capability_keys", []) as Array, DriverScript.CAPABILITY_PUBLIC_KEYS), "capability output is aggregate-only")
	_expect(_public_contract_is_safe(public_contract), "public schemas exclude raw continuation and hidden-state fields")

	for token in FORBIDDEN_DRIVER_TOKENS:
		_expect(not source.contains(token), "driver excludes forbidden runtime shortcut: %s" % token)
	_expect(not source.contains('.call("tick_') and not source.contains('.set("cash"') and not source.contains('.set("gdp"'), "driver does not tick child owners or mutate economic state")
	_finish()


func _public_contract_is_safe(contract: Dictionary) -> bool:
	for list_variant in contract.values():
		if not (list_variant is Array):
			continue
		for key_variant in list_variant as Array:
			var key := str(key_variant).to_lower()
			for forbidden in FORBIDDEN_PUBLIC_KEYS:
				if key == forbidden:
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
		print("FULL_RUN_QUALITY_DRIVER_CONTRACT|status=PASS|checks=%d|failures=0|seed_count=%d" % [_checks, EXPECTED_SEEDS.size()])
		quit(0)
		return
	for failure in _failures:
		push_error("FULL_RUN_QUALITY_DRIVER_CONTRACT: %s" % failure)
	print("FULL_RUN_QUALITY_DRIVER_CONTRACT|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)
