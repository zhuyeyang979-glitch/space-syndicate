extends SceneTree

const SIMULATOR := preload(
	"res://scripts/v075_simulation/v075_combat_deterministic_simulator.gd"
)
const SIMULATOR_PATH := (
	"res://scripts/v075_simulation/v075_combat_deterministic_simulator.gd"
)
const BASE_SEED := 900626424
const DEFAULT_SCOPE_MATCHES := 1
const DEFAULT_FORMAL_MATCHES := 400
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
	if _has_argument("--scope-only"):
		_run_scope_only()
		return
	if _has_argument("--aggregate"):
		_run_aggregate_report()
		return
	if _has_argument("--diagnostic-monster"):
		_run_monster_diagnostic()
		return
	var matches_per_configuration := _argument_int(
		"--matches-per-configuration",
		1
	)
	var step_limit := _argument_int("--step-limit", 512)
	var write_report := _has_argument("--write-report")
	var simulator := SIMULATOR.new()
	_test_shard_planner(simulator)
	var options := _simulation_options_from_arguments(write_report)
	var report := simulator.run_matrix(
		matches_per_configuration,
		step_limit,
		options
	)
	if _is_shard_options(options):
		_test_shard_report_contract(report)
	else:
		_test_report_contract(report, matches_per_configuration)
	if _has_argument("--replay"):
		_test_deterministic_replay(simulator, step_limit)
	_print_summary(report)
	_finish()


func _run_scope_only() -> void:
	var simulator := SIMULATOR.new()
	_test_shard_planner(simulator)
	var matches_per_configuration := _argument_int(
		"--matches-per-configuration",
		DEFAULT_SCOPE_MATCHES
	)
	var scope := simulator.build_shard_manifest(
		matches_per_configuration,
		_simulation_options_from_arguments(false)
	)
	print("V075_COMBAT_SIMULATION_SCOPE|%s" % JSON.stringify(scope))
	quit(0 if bool(scope.get("accepted", false)) and _failures.is_empty() else 1)


func _test_shard_planner(simulator: RefCounted) -> void:
	var explicit := simulator.build_shard_manifest(
		4,
		{
			"configuration_index_start": 1,
			"configuration_index_end_exclusive": 3,
			"match_index_start": 2,
			"match_index_end_exclusive": 4,
		}
	) as Dictionary
	_expect(
		bool(explicit.get("accepted", false))
			and int(explicit.get("requested_match_count", 0)) == 4,
		"explicit configuration and match ranges produce four jobs"
	)
	var all_jobs: Dictionary = {}
	var all_seeds: Dictionary = {}
	for shard_id in range(4):
		var shard := simulator.build_shard_manifest(
			400,
			{"shard_count": 4, "shard_id": shard_id}
		) as Dictionary
		_expect(
			bool(shard.get("accepted", false)),
			"round-robin shard %d has a valid manifest" % shard_id
		)
		for job_variant in shard.get("jobs", []) as Array:
			var job := job_variant as Dictionary
			var job_key := "%d:%d" % [
				int(job.get("configuration_index", -1)),
				int(job.get("match_index", -1)),
			]
			all_jobs[job_key] = int(all_jobs.get(job_key, 0)) + 1
			var seed_key := str(int(job.get("seed", 0)))
			all_seeds[seed_key] = int(all_seeds.get(seed_key, 0)) + 1
	_expect(
		all_jobs.size() == 2000 and _not_duplicate_counts(all_jobs),
		"four shard manifests cover each formal job exactly once"
	)
	_expect(
		all_seeds.size() == 2000 and _not_duplicate_counts(all_seeds),
		"four shard manifests cover each formal seed exactly once"
	)
	var invalid := simulator.build_shard_manifest(
		400,
		{"shard_id": 1}
	) as Dictionary
	_expect(
		not bool(invalid.get("accepted", true))
			and str(invalid.get("reason_code", ""))
				== "shard_count_required_for_shard_id",
		"shard id cannot silently run without a shard count"
	)


func _run_aggregate_report() -> void:
	var simulator := SIMULATOR.new()
	var inputs := _argument_values("--aggregate-input")
	var options := {
		"write_report": _has_argument("--write-report")
			or not _argument_value("--report-json", "").is_empty()
			or not _argument_value("--report-md", "").is_empty(),
		"report_json_path": _argument_value("--report-json", ""),
		"report_md_path": _argument_value("--report-md", ""),
		"formal_matches_per_configuration": _argument_int(
			"--formal-matches-per-configuration",
			DEFAULT_FORMAL_MATCHES
		),
	}
	var report := simulator.aggregate_report_files(inputs, options)
	var total := int(report.get("total_match_count", 0))
	if total == DEFAULT_FORMAL_MATCHES * EXPECTED_CONFIGURATION_IDS.size():
		_test_report_contract(report, DEFAULT_FORMAL_MATCHES)
	else:
		_test_aggregate_report_contract(report)
	_print_summary(report)
	_finish()


func _run_monster_diagnostic() -> void:
	var simulator := SIMULATOR.new()
	var configuration_index := clampi(
		_argument_int("--diagnostic-configuration-index", 1),
		0,
		simulator.configurations().size() - 1
	)
	var match_index := maxi(0, _argument_int("--diagnostic-match-index", 0))
	var configuration_value: Variant = simulator.configurations()[
		configuration_index
	]
	var configuration: Dictionary = {}
	if configuration_value is Dictionary:
		configuration = (configuration_value as Dictionary).duplicate(true)
	var seed_value := _argument_int(
		"--diagnostic-match-seed",
		int(simulator.seed_for(configuration_index, match_index))
	)
	configuration["map_seed"] = _argument_int(
		"--diagnostic-map-seed",
		seed_value
	)
	var row: Dictionary = simulator.run_match(
		configuration,
		seed_value,
		_argument_int("--step-limit", 512)
	)
	if _has_argument("--diagnostic-seed-scan"):
		var metrics := row.get("metrics", {}) as Dictionary
		var combat_identity := (
			(row.get("identity", {}) as Dictionary).get("combat", {})
			as Dictionary
		)
		print("V075_SEED_SCAN|%s" % JSON.stringify({
			"match_seed": seed_value,
			"map_seed": int(configuration.get("map_seed", seed_value)),
			"settled": bool(row.get("settled", false)),
			"monster_purchase": int(metrics.get(
				"MONSTER_CARD_PURCHASE_COUNT",
				0
			)),
			"monster_first_purchase_batch": int(combat_identity.get(
				"first_monster_card_purchase_batch",
				-1
			)),
			"monster_hand": int(metrics.get(
				"MONSTER_CARD_HAND_OBSERVATION_COUNT",
				0
			)),
			"monster_resolved": int(metrics.get("MONSTER_DEPLOY_COUNT", 0))
				+ int(metrics.get("MONSTER_REFRESH_COUNT", 0))
				+ int(metrics.get("MONSTER_UPGRADE_COUNT", 0))
				+ int(metrics.get("MONSTER_REPLACE_COUNT", 0)),
			"military_purchase": int(metrics.get(
				"MILITARY_CARD_PURCHASE_COUNT",
				0
			)),
			"military_first_purchase_batch": int(combat_identity.get(
				"first_military_card_purchase_batch",
				-1
			)),
			"military_hand": int(metrics.get(
				"MILITARY_CARD_HAND_OBSERVATION_COUNT",
				0
			)),
			"military_resolved": int(metrics.get(
				"MILITARY_REGION_ASSAULT_COUNT",
				0
			)) + int(metrics.get("MILITARY_MONSTER_ASSAULT_COUNT", 0)),
			"runtime_errors": int(metrics.get("COMBAT_RUNTIME_ERROR_COUNT", 0)),
		}))
		quit(0)
		return
	print(
		"V075_MONSTER_DIAGNOSTIC_RESULT|%s"
		% JSON.stringify({
			"settled": bool(row.get("settled", false)),
			"duration_msec": int(row.get("duration_msec", 0)),
			"timing": row.get("timing", {}),
			"metrics": row.get("metrics", {}),
			"simulation_performance": row.get(
				"simulation_performance",
				{}
			),
		})
	)
	quit(0)


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
	var root_cause := report.get(
		"root_cause_diagnostics",
		{}
	) as Dictionary
	_expect(
		int(root_cause.get("direct_state_injection_count", -1)) == 0,
		"root-cause diagnostics are read-only"
	)
	if (
		int(global_metrics.get("MONSTER_CARD_HAND_OBSERVATION_COUNT", 0)) > 0
		and int(global_metrics.get(
			"MONSTER_LEGAL_OPTION_OBSERVATION_COUNT",
			0
		)) == 0
	):
		var monster_rejection := root_cause.get(
			"first_monster_prebind_rejection",
			{}
		) as Dictionary
		var monster_observation := root_cause.get(
			"first_monster_prebind_observation",
			{}
		) as Dictionary
		_expect(
			(
				not str(monster_rejection.get("reason_code", "")).is_empty()
				and bool(monster_rejection.get(
					"combat_debug_unchanged",
					false
				))
			) or (
				bool(monster_observation.get("accepted", false))
				and bool(monster_observation.get(
					"combat_debug_unchanged",
					false
				))
			),
			"monster legal starvation records a non-mutating prebind outcome"
		)
	if (
		int(global_metrics.get("MILITARY_LEGAL_OPTION_OBSERVATION_COUNT", 0)) > 0
		and int(global_metrics.get(
			"MILITARY_QUEUED_ACTION_OBSERVATION_COUNT",
			0
		)) == 0
	):
		var military_rejection := root_cause.get(
			"first_military_filter_rejection",
			{}
		) as Dictionary
		_expect(
			not str(military_rejection.get("reason_code", "")).is_empty()
				and military_rejection.has("asset_color")
				and military_rejection.has("target_present")
				and military_rejection.has("target_slot_present"),
			"military queue starvation records asset, target, and slot reason"
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


func _simulation_options_from_arguments(write_report: bool) -> Dictionary:
	var options := {
		"write_report": write_report,
		"progress_interval": _argument_int("--progress-interval", 0),
	}
	var mapping := {
		"--configuration-index": "configuration_index",
		"--configuration-index-start": "configuration_index_start",
		"--configuration-index-end": "configuration_index_end_exclusive",
		"--configuration-index-end-exclusive": "configuration_index_end_exclusive",
		"--match-index-start": "match_index_start",
		"--match-index-end": "match_index_end_exclusive",
		"--match-index-end-exclusive": "match_index_end_exclusive",
		"--match-index-count": "match_index_count",
		"--shard-id": "shard_id",
		"--shard-count": "shard_count",
		"--formal-matches-per-configuration": (
			"formal_matches_per_configuration"
		),
	}
	for argument_prefix_variant in mapping.keys():
		var argument_prefix := str(argument_prefix_variant)
		var value := _argument_value(argument_prefix, "")
		if value.is_empty() or not value.is_valid_int():
			continue
		options[str(mapping.get(argument_prefix, ""))] = maxi(0, int(value))
	var report_json := _argument_value("--report-json", "")
	var report_md := _argument_value("--report-md", "")
	if not report_json.is_empty():
		options["report_json_path"] = report_json
	if not report_md.is_empty():
		options["report_md_path"] = report_md
	return options


func _is_shard_options(options: Dictionary) -> bool:
	for key in [
		"configuration_index",
		"configuration_index_start",
		"configuration_index_end_exclusive",
		"match_index_start",
		"match_index_end_exclusive",
		"match_index_count",
		"shard_id",
		"shard_count",
	]:
		if options.has(key):
			return true
	return false


func _test_shard_report_contract(report: Dictionary) -> void:
	_expect(
		str(report.get("report_kind", "")) == "v075.combat.simulation.shard.v1",
		"shard report declares the V075 shard schema"
	)
	var scope := report.get("execution_scope", {}) as Dictionary
	_expect(
		bool(scope.get("seed_deduplication", false))
			and str(scope.get("seed_formula_id", ""))
				== "base_plus_configuration_million_plus_match_7919",
		"shard scope declares deterministic seed ownership"
	)
	var rows := report.get("shard_rows", []) as Array
	_expect(
		rows.size() == int(report.get("total_match_count", -1)),
		"shard report retains one public row per executed match"
	)
	var jobs: Dictionary = {}
	var seeds: Dictionary = {}
	for row_variant in rows:
		var row := row_variant as Dictionary
		var configuration_index := int(row.get("configuration_index", -1))
		var match_index := int(row.get("match_index", -1))
		var job_key := "%d:%d" % [configuration_index, match_index]
		jobs[job_key] = int(jobs.get(job_key, 0)) + 1
		var seed := int(row.get("seed", 0))
		seeds[str(seed)] = int(seeds.get(str(seed), 0)) + 1
		_expect(
			seed == int(simulator_seed_for(configuration_index, match_index)),
			"shard row seed matches its configuration and match index"
		)
	_expect(
		_not_duplicate_counts(jobs) and _not_duplicate_counts(seeds),
		"shard rows have unique job and seed identities"
	)
	_expect(
		int((report.get("observability", {}) as Dictionary).get(
			"direct_monster_injection_count",
			-1
		)) == 0,
		"shard uses no direct state injection"
	)


func _test_aggregate_report_contract(report: Dictionary) -> void:
	_expect(
		str(report.get("report_kind", ""))
			== "v075.combat.simulation.aggregate.v1",
		"aggregate report declares the V075 aggregate schema"
	)
	var aggregation := report.get("aggregation", {}) as Dictionary
	_expect(
		int(aggregation.get("duplicate_job_count", -1)) == 0
			and int(aggregation.get("duplicate_seed_count", -1)) == 0
			and int(aggregation.get("seed_mismatch_count", -1)) == 0
			and int(aggregation.get("out_of_declared_scope_count", -1)) == 0,
		"aggregate report rejects duplicate or mismatched seeds"
	)
	_expect(
		int(aggregation.get("missing_job_count", -1)) >= 0
			and int(aggregation.get("unique_job_count", -1))
				== int(report.get("total_match_count", -2)),
		"aggregate report accounts for every unique job"
	)


func _not_duplicate_counts(counts: Dictionary) -> bool:
	for value_variant in counts.values():
		if int(value_variant) > 1:
			return false
	return true


func simulator_seed_for(configuration_index: int, match_index: int) -> int:
	return BASE_SEED + configuration_index * 1000000 + match_index * 7919


func _argument_int(prefix: String, fallback: int) -> int:
	for argument_variant in _command_line_arguments():
		var argument := str(argument_variant)
		if argument.begins_with(prefix + "="):
			var value := argument.trim_prefix(prefix + "=")
			if value.is_valid_int():
				return maxi(1, int(value))
	return fallback


func _argument_value(prefix: String, fallback: String) -> String:
	for argument_variant in _command_line_arguments():
		var argument := str(argument_variant)
		if argument.begins_with(prefix + "="):
			return argument.trim_prefix(prefix + "=")
	return fallback


func _argument_values(prefix: String) -> Array[String]:
	var result: Array[String] = []
	for argument_variant in _command_line_arguments():
		var argument := str(argument_variant)
		if argument.begins_with(prefix + "="):
			var value := argument.trim_prefix(prefix + "=")
			if not value.is_empty():
				result.append(value)
	return result


func _has_argument(expected: String) -> bool:
	for argument_variant in _command_line_arguments():
		if str(argument_variant) == expected:
			return true
	return false


func _command_line_arguments() -> Array:
	var result: Array = []
	result.append_array(OS.get_cmdline_user_args())
	result.append_array(OS.get_cmdline_args())
	return result


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
