extends SceneTree

const SIMULATOR := preload(
	"res://scripts/v075_simulation/v075_combat_deterministic_simulator.gd"
)
const SIMULATOR_PATH := (
	"res://scripts/v075_simulation/v075_combat_deterministic_simulator.gd"
)
const EXPECTED_CONFIGURATION_IDS := [
	"3p_8r_simple",
	"4p_16r_standard",
	"4p_24r_complex",
	"6p_24r_standard",
	"8p_30r_complex",
]
const REQUIRED_POSITIVE_COUNTER_KEYS := [
	"MONSTER_CARD_PURCHASE_COUNT",
	"MONSTER_CARD_RESHUFFLE_COUNT",
	"MONSTER_DEPLOY_COUNT",
	"MONSTER_REFRESH_COUNT",
	"MONSTER_UPGRADE_COUNT",
	"MONSTER_REPLACE_COUNT",
	"MONSTER_AUTONOMY_TARGET_COUNT",
	"MONSTER_MOVEMENT_COUNT",
	"MONSTER_TRAMPLE_REGION_RECEIPT_COUNT",
	"MONSTER_PRIVATE_SKILL_REQUEST_COUNT",
	"MONSTER_PRIVATE_SKILL_USE_COUNT",
	"MONSTER_PRIVATE_SKILL_REUSE_COUNT",
	"MONSTER_SKILL_COOLDOWN_RECOVERY_COUNT",
	"MILITARY_CARD_PURCHASE_COUNT",
	"MILITARY_CARD_RESHUFFLE_COUNT",
	"MILITARY_REGION_ASSAULT_COUNT",
	"MILITARY_MONSTER_ASSAULT_COUNT",
	"MILITARY_WITHDRAW_COUNT",
	"FACILITY_COMBAT_DAMAGE_COUNT",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if _has_argument("--parse-only"):
		print(
			"V075_COMBAT_SIMULATION_TEST|status=PARSE_ONLY_PASS"
		)
		quit(0)
		return
	var matches_per_configuration := _argument_int(
		"--matches-per-configuration",
		1
	)
	var step_limit := _argument_int("--step-limit", 512)
	var write_report := _has_argument("--write-report")
	var simulator := SIMULATOR.new()
	var report := simulator.run_matrix(
		matches_per_configuration,
		step_limit,
		{
			"write_report": write_report,
			"progress_interval": _argument_int("--progress-interval", 0),
		}
	)
	_test_report_contract(report, matches_per_configuration)
	if _has_argument("--replay"):
		_test_deterministic_replay(simulator, step_limit)
	_print_summary(report)
	_finish()


func _test_report_contract(
	report: Dictionary,
	matches_per_configuration: int
) -> void:
	_expect(
		str(report.get("simulation_id", "")) ==
			"v075.combat.deterministic.production_path.v1",
		"report uses the V075 production-path simulation identity"
	)
	_expect(
		str(report.get("ruleset_id", "")) == "v0.7.5",
		"report uses the V0.7.5 ruleset"
	)
	_expect(
		int(report.get("configuration_count", 0)) == 5,
		"report covers exactly five requested configurations"
	)
	_expect(
		int(report.get("total_match_count", 0))
			== matches_per_configuration * 5,
		"report match total equals configuration matrix"
	)
	var configuration_ids: Array[String] = []
	for row_variant in report.get("configuration_results", []) as Array:
		var row := row_variant as Dictionary
		var configuration_id := str(row.get("configuration_id", ""))
		configuration_ids.append(configuration_id)
		_expect(
			int(row.get("match_count", 0)) == matches_per_configuration,
			"%s has the requested match count" % configuration_id
		)
		_expect(
			int(row.get("settled_match_count", 0))
				== matches_per_configuration,
			"%s reaches FinalSettlement in the focused sample"
			% configuration_id
		)
		var metrics := row.get("metrics", {}) as Dictionary
		_expect(
			int(metrics.get(
				"TRACK_SHARED_SCROLL_VACANCY_VIOLATION_COUNT",
				1
			)) == 0,
			"%s preserves shared scroll vacancy" % configuration_id
		)
		_expect(
			int(metrics.get(
				"TRACK_RATIO_CONTRACT_VIOLATION_COUNT",
				1
			)) == 0,
			"%s preserves the 6000/4000 track ratio" % configuration_id
		)
	_expect(
		configuration_ids == EXPECTED_CONFIGURATION_IDS,
		"configuration ordering and identities are stable"
	)
	var path := report.get("production_path", {}) as Dictionary
	_expect(
		int(path.get("direct_state_injection_count", -1)) == 0
			and path.get("track_and_dbg_are_runtime_owned") == true
			and str(path.get("settlement_api", ""))
				== "run_simulation_until_settled"
			and str(path.get("authority_process_api", ""))
				== "V073SampleRuntimeOwner._process"
			and float(path.get("simulation_process_delta_seconds", 0.0))
				== 1.0,
		"simulation uses runtime-owned track and DBG with no direct injection"
	)
	var observability := report.get("observability", {}) as Dictionary
	for key in [
		"opponent_private_facts_read_count",
		"private_warehouse_stock_read_count",
		"future_supply_read_count",
		"direct_monster_injection_count",
		"direct_military_injection_count",
		"direct_facility_injection_count",
		"direct_hand_injection_count",
		"direct_damage_injection_count",
		"direct_victory_injection_count",
	]:
		_expect(
			int(observability.get(key, -1)) == 0,
			"simulation records zero %s" % key
		)
	var source := FileAccess.get_file_as_string(SIMULATOR_PATH)
	for forbidden in [
		"MonsterSourceCore.new_state",
		"MilitaryMissionCore",
		"FacilityCore.build",
		"DBG_CORE.new",
		"set_monster_state",
		"set_hand_state",
		"inject_damage",
		"force_victory",
	]:
		_expect(
			not source.contains(forbidden),
			"simulator does not call forbidden injection surface %s"
			% forbidden
		)
	var gates := report.get("safety_gates", {}) as Dictionary
	_expect(
		gates.get("TRACK_SHARED_SCROLL_VACANCY_GREEN") == true
			and gates.get("TRACK_RATIO_6000_4000_GREEN") == true,
		"V0.7.4 ten-card slow vacancy and ratio gates remain green"
	)
	var global_metrics := report.get("global_metrics", {}) as Dictionary
	_expect(
		not _has_case_insensitive_duplicate_keys(global_metrics),
		"global metrics have unique case-insensitive JSON keys"
	)
	for row_variant in report.get("configuration_results", []) as Array:
		var row := row_variant as Dictionary
		_expect(
			not _has_case_insensitive_duplicate_keys(
				row.get("metrics", {}) as Dictionary
			),
			"%s metrics have unique case-insensitive JSON keys"
			% str(row.get("configuration_id", ""))
		)
	for key in REQUIRED_POSITIVE_COUNTER_KEYS:
		_expect(
			int(global_metrics.get(key, 0)) > 0,
			"formal matrix observes positive %s" % key
		)
	var coverage := report.get("coverage_gates", {}) as Dictionary
	_expect(
		coverage.get("COMBAT_REQUIRED_OBSERVATIONS_GREEN") == true,
		"all required combat lifecycle observations are green"
	)
	if matches_per_configuration == 400:
		_expect(
			int(report.get("total_match_count", 0)) == 2000
				and str(report.get("acceptance_status", "")) == "GREEN",
			"formal 400/configuration run is a GREEN 2000-match report"
		)
	_expect(
		str(report.get("report_fingerprint", "")).length() == 64,
		"report has a SHA-256 fingerprint"
	)


func _test_deterministic_replay(
	simulator: RefCounted,
	step_limit: int
) -> void:
	var configuration_value: Variant = simulator.configurations()[0]
	var configuration: Dictionary = {}
	if configuration_value is Dictionary:
		configuration = (configuration_value as Dictionary).duplicate(true)
	var seed_value: int = int(simulator.seed_for(0, 0))
	var first_value: Variant = simulator.run_match(
		configuration,
		seed_value,
		step_limit
	)
	var first: Dictionary = {}
	if first_value is Dictionary:
		first = (first_value as Dictionary).duplicate(true)
	var second_value: Variant = simulator.run_match(
		configuration,
		seed_value,
		step_limit
	)
	var second: Dictionary = {}
	if second_value is Dictionary:
		second = (second_value as Dictionary).duplicate(true)
	_expect(
		str(first.get("fingerprint", "")) ==
			str(second.get("fingerprint", "")),
		"same configuration and seed produce the same terminal fingerprint"
	)
	_expect(
		first.get("identity", {}) == second.get("identity", {}),
		"same configuration and seed produce the same rule identity"
	)


func _print_summary(report: Dictionary) -> void:
	var metrics := report.get("global_metrics", {}) as Dictionary
	print(
		"V075_COMBAT_SIMULATION_TEST|status=%s|matches=%d|settled=%d|deadlocks=%d|invalid=%d|hidden=%d|duration_ms=%d|fingerprint=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			int(report.get("total_match_count", 0)),
			int(metrics.get("COMBAT_SIMULATION_SETTLED_COUNT", 0)),
			int(metrics.get("COMBAT_SIMULATION_DEADLOCK_COUNT", 0)),
			int(metrics.get("COMBAT_INVALID_TARGET_COUNT", 0)),
			int(metrics.get("COMBAT_HIDDEN_INFO_VIOLATION_COUNT", 0)),
			int(report.get("elapsed_msec", 0)),
			str(report.get("report_fingerprint", "")),
		]
	)


func _argument_int(prefix: String, fallback: int) -> int:
	for argument_variant in OS.get_cmdline_user_args():
		var argument := str(argument_variant)
		if argument.begins_with(prefix + "="):
			var value := argument.trim_prefix(prefix + "=")
			if value.is_valid_int():
				return maxi(1, int(value))
	return fallback


func _has_argument(expected: String) -> bool:
	for argument_variant in OS.get_cmdline_user_args():
		if str(argument_variant) == expected:
			return true
	return false


func _has_case_insensitive_duplicate_keys(values: Dictionary) -> bool:
	var seen: Dictionary = {}
	for key_variant in values.keys():
		var normalized: String = str(key_variant).to_lower()
		if seen.has(normalized):
			return true
		seen[normalized] = true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(
		"V075_COMBAT_SIMULATION_TEST: %s" % message
	)


func _finish() -> void:
	print(
		"V075_COMBAT_SIMULATION_TEST_RESULT|status=%s|checks=%d|failures=%d"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
		]
	)
	if not _failures.is_empty():
		print(
			"V075_COMBAT_SIMULATION_TEST_RESULT|first_failure=%s"
			% _failures[0]
		)
	quit(0 if _failures.is_empty() else 1)
