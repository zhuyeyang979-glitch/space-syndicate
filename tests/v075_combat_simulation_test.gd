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
const REQUIRED_ZERO_COUNTER_KEYS := [
	"COMBAT_SIMULATION_DEADLOCK_COUNT",
	"COMBAT_INVALID_TARGET_COUNT",
	"COMBAT_NONFINITE_COUNT",
	"COMBAT_DUPLICATE_EFFECT_COUNT",
	"COMBAT_HIDDEN_INFO_VIOLATION_COUNT",
	"MONSTER_CONTROL_CAP_VIOLATION_COUNT",
	"MONSTER_AUTONOMY_STALL_COUNT",
	"MILITARY_GUARD_ACTION_COUNT",
	"MILITARY_BOUND_ACTION_COUNT",
	"COMBAT_RUNTIME_ERROR_COUNT",
	"COMBAT_DUAL_WRITE_COUNT",
	"COMBAT_LEGACY_FALLBACK_COUNT",
	"TRACK_IMMEDIATE_AUTHORITATIVE_REFILL_COUNT",
	"TRACK_SUPPLY_CURSOR_DELTA_ON_ACQUISITION",
	"TRACK_SUPPLY_INSTANCE_SEQUENCE_DELTA_ON_ACQUISITION",
	"TRACK_SUPPLY_RNG_DRAW_DELTA_ON_ACQUISITION",
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
	if bool(options.get("write_report", false)):
		_test_written_report(simulator, report)
	if _is_shard_options(options):
		_test_shard_report_contract(report)
		_test_source_sha_aggregation(simulator, report)
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
	var disabled_authority := simulator.authority_contract_context(explicit, {}) \
		as Dictionary
	_expect(
		bool(disabled_authority.get("accepted", false))
			and not bool(disabled_authority.get("enabled", true)),
		"authority resume is opt-in and leaves the default matrix path unchanged"
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
	if bool(options.get("write_report", false)):
		_test_written_report(simulator, report)
	var total := int(report.get("total_match_count", 0))
	_test_aggregate_report_contract(report)
	if total == DEFAULT_FORMAL_MATCHES * EXPECTED_CONFIGURATION_IDS.size():
		_test_report_contract(report, DEFAULT_FORMAL_MATCHES)
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
	_test_harness_identity(report, "report")
	var expected_source_sha := OS.get_environment(
		"V075_SIMULATION_SOURCE_SHA"
	).strip_edges()
	if not expected_source_sha.is_empty():
		_expect(
			str(report.get("source_commit_sha", "")) == expected_source_sha,
			"report records the exact simulation source commit"
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
	for key in REQUIRED_ZERO_COUNTER_KEYS:
		_expect(
			int(global_metrics.get(key, -1)) == 0,
			"formal matrix records zero %s" % key
		)
	for key in REQUIRED_POSITIVE_COUNTER_KEYS:
		_expect(
			int(global_metrics.get(key, 0)) > 0,
			"formal matrix observes positive %s" % key
		)
	var coverage := report.get("coverage_gates", {}) as Dictionary
	_expect(
		coverage.get("COMBAT_REQUIRED_OBSERVATIONS_GREEN") == true
			and int(coverage.get(
				"MISSING_REQUIRED_POSITIVE_COUNTER_COUNT",
				-1
			)) == 0,
		"all required combat lifecycle observations are green"
	)
	_expect(
		int(global_metrics.get("COMBAT_ACTION_COUNT", 0)) > 0
			and coverage.get("COMBAT_ACTION_COUNT_GREEN") == true,
		"formal matrix records at least one natural combat action"
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
		"--assignment-shard-id": "assignment_shard_id",
		"--assignment-shard-count": "assignment_shard_count",
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
	var string_mapping := {
		"--authority-path": "authority_path",
		"--final-head-sha": "final_head_sha",
		"--final-tree-sha": "final_tree_sha",
		"--authority-manifest-sha256": "authority_manifest_sha256",
		"--worker-id": "worker_id",
		"--expected-harness-hash": "expected_harness_hash",
	}
	for argument_prefix_variant in string_mapping.keys():
		var argument_prefix := str(argument_prefix_variant)
		var value := _argument_value(argument_prefix, "")
		if not value.is_empty():
			options[str(string_mapping.get(argument_prefix, ""))] = value
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
		"assignment_shard_id",
		"assignment_shard_count",
	]:
		if options.has(key):
			return true
	return false


func _test_shard_report_contract(report: Dictionary) -> void:
	_expect(
		str(report.get("report_kind", "")) == "v075.combat.simulation.shard.v1",
		"shard report declares the V075 shard schema"
	)
	_test_harness_identity(report, "shard report")
	var expected_source_sha := OS.get_environment(
		"V075_SIMULATION_SOURCE_SHA"
	).strip_edges()
	if not expected_source_sha.is_empty():
		_expect(
			str(report.get("source_commit_sha", "")) == expected_source_sha,
			"shard records the exact simulation source commit"
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
	var shard_gates := report.get("shard_acceptance_gates", {}) as Dictionary
	_expect(
		str(shard_gates.get("rare_positive_gate_scope", ""))
			== "aggregate_only",
		"rare positive observations are aggregate-only, not per-shard vetoes"
	)
	var shard_required_gates_green := (
		bool(shard_gates.get("SHARD_SAFETY_ZERO_GREEN", false))
		and bool(shard_gates.get("SHARD_ALL_MATCHES_SETTLED_GREEN", false))
		and bool(shard_gates.get(
			"SHARD_FINAL_SETTLEMENT_EXACT_ONCE_GREEN",
			false
		))
		and bool(shard_gates.get("SHARD_COMBAT_ACTION_COUNT_GREEN", false))
	)
	var declared_shard_green := str(
		report.get("shard_acceptance_status", "")
	) == "GREEN"
	_expect(
		bool(shard_gates.get("SHARD_ACCEPTANCE_GREEN", false))
			== shard_required_gates_green
			and declared_shard_green == shard_required_gates_green,
		"shard acceptance uses only safety, settlement, and real action gates"
	)
	if report.has("authority_resume"):
		var authority := report.get("authority_resume", {}) as Dictionary
		_expect(
			bool(authority.get("enabled", false))
				and not bool(authority.get(
					"heartbeat_only_skips_match",
					true
				)),
			"authority resume never treats a heartbeat as a completed job"
		)


func _test_aggregate_report_contract(report: Dictionary) -> void:
	_expect(
		str(report.get("report_kind", ""))
			== "v075.combat.simulation.aggregate.v1",
		"aggregate report declares the V075 aggregate schema"
	)
	_test_harness_identity(report, "aggregate report")
	var aggregation := report.get("aggregation", {}) as Dictionary
	_expect(
		int(aggregation.get("schema_error_count", -1)) == 0
			and int(aggregation.get(
				"report_fingerprint_invalid_count",
				-1
			)) == 0
			and int(aggregation.get("out_of_declared_scope_count", -1)) == 0,
		"aggregate report rejects invalid schemas, fingerprints, or scope"
	)
	_expect(
		int(aggregation.get("harness_fingerprint_missing_count", -1)) == 0
			and int(aggregation.get(
				"harness_fingerprint_mismatch_count",
				-1
			)) == 0
			and int(aggregation.get(
				"harness_component_mismatch_count",
				-1
			)) == 0
			and (aggregation.get(
				"harness_fingerprint_set",
				[]
			) as Array).size() == 1
			and str((aggregation.get(
				"harness_fingerprint_set",
				[]
			) as Array)[0]) == str(report.get("harness_fingerprint", "")),
		"aggregate report preserves one complete harness fingerprint"
	)
	_expect(
		(aggregation.get("source_report_fingerprints", []) as Array).size()
			== int(aggregation.get("input_report_count", -1)),
		"aggregate report preserves one fingerprint per input shard"
	)
	var expected_source_sha := OS.get_environment(
		"V075_SIMULATION_SOURCE_SHA"
	).strip_edges()
	_expect(
		not expected_source_sha.is_empty()
		and str(report.get("source_commit_sha", "")) == expected_source_sha
		and int(aggregation.get(
			"expected_source_commit_sha_missing_count",
			-1
		)) == 0
		and int(aggregation.get(
			"source_commit_sha_missing_count",
			-1
		)) == 0
		and int(aggregation.get(
			"source_commit_sha_mismatch_count",
			-1
		)) == 0,
		"aggregate process declares and preserves one complete exact source SHA"
	)
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
	if int(report.get("total_match_count", 0)) \
		== DEFAULT_FORMAL_MATCHES * EXPECTED_CONFIGURATION_IDS.size():
		_expect(
			int(aggregation.get("missing_job_count", -1)) == 0
				and int(aggregation.get("unique_job_count", -1)) == 2000
				and int(aggregation.get("expected_job_count", -1)) == 2000,
			"formal aggregate covers every one of the 2000 unique jobs"
		)
	var simulator := SIMULATOR.new()
	_expect(
		simulator.aggregate_acceptance_status(
			true,
			true,
			true,
			0,
			2000,
			2000
		) == "BLOCKED",
		"structural aggregation failures override green safety and coverage"
	)


func _test_source_sha_aggregation(
	simulator: RefCounted,
	shard_report: Dictionary
) -> void:
	var expected_source_sha := OS.get_environment(
		"V075_SIMULATION_SOURCE_SHA"
	).strip_edges()
	if expected_source_sha.is_empty():
		return
	var valid := simulator.aggregate_reports(
		[shard_report],
		{"formal_matches_per_configuration": DEFAULT_FORMAL_MATCHES}
	) as Dictionary
	var valid_aggregation := valid.get("aggregation", {}) as Dictionary
	_expect(
		str(valid.get("source_commit_sha", "")) == expected_source_sha
		and int(valid_aggregation.get(
			"source_commit_sha_missing_count",
			-1
		)) == 0
		and int(valid_aggregation.get(
			"source_commit_sha_mismatch_count",
			-1
		)) == 0,
		"one complete shard source SHA survives aggregation"
	)
	OS.set_environment("V075_SIMULATION_SOURCE_SHA", "")
	var missing_expected_result := simulator.aggregate_reports(
		[shard_report],
		{"formal_matches_per_configuration": DEFAULT_FORMAL_MATCHES}
	) as Dictionary
	OS.set_environment("V075_SIMULATION_SOURCE_SHA", expected_source_sha)
	var missing_expected_aggregation := (
		missing_expected_result.get("aggregation", {}) as Dictionary
	)
	_expect(
		str(missing_expected_result.get("acceptance_status", "")) == "BLOCKED"
		and int(missing_expected_aggregation.get(
			"expected_source_commit_sha_missing_count",
			0
		)) == 1,
		"aggregate fails closed when its exact source SHA environment is absent"
	)
	var round_trip_variant: Variant = JSON.parse_string(
		JSON.stringify(shard_report)
	)
	_expect(
		round_trip_variant is Dictionary,
		"shard report survives JSON serialization and parsing"
	)
	if round_trip_variant is Dictionary:
		var round_trip_result := simulator.aggregate_reports(
			[round_trip_variant],
			{"formal_matches_per_configuration": DEFAULT_FORMAL_MATCHES}
		) as Dictionary
		var round_trip_aggregation := (
			round_trip_result.get("aggregation", {}) as Dictionary
		)
		_expect(
			int(round_trip_aggregation.get(
				"report_fingerprint_invalid_count",
				-1
			)) == 0,
			"disk-equivalent JSON preserves the shard report fingerprint"
		)
	var coverage_green := shard_report.duplicate(true)
	for row_variant in coverage_green.get("shard_rows", []) as Array:
		var row := row_variant as Dictionary
		var metrics := row.get("metrics", {}) as Dictionary
		for key in REQUIRED_POSITIVE_COUNTER_KEYS:
			metrics[key] = maxi(1, int(metrics.get(key, 0)))
		metrics["COMBAT_ACTION_COUNT"] = maxi(1, int(metrics.get(
			"COMBAT_ACTION_COUNT",
			0
		)))
		row["metrics"] = metrics
	_reseal_report(simulator, coverage_green)
	var duplicate_green_result := simulator.aggregate_reports(
		[coverage_green, coverage_green],
		{"formal_matches_per_configuration": DEFAULT_FORMAL_MATCHES}
	) as Dictionary
	var duplicate_green_aggregation := (
		duplicate_green_result.get("aggregation", {}) as Dictionary
	)
	_expect(
		str(duplicate_green_result.get("acceptance_status", "")) == "BLOCKED"
			and simulator.safety_gates_are_green(duplicate_green_result)
			and simulator.coverage_gates_are_green(duplicate_green_result)
			and int(duplicate_green_aggregation.get(
				"duplicate_job_count",
				0
			)) > 0,
		"duplicate jobs block aggregation even with green safety and coverage"
	)
	var runtime_error_report := shard_report.duplicate(true)
	var runtime_error_rows := runtime_error_report.get("shard_rows", []) as Array
	if not runtime_error_rows.is_empty():
		var runtime_error_row := runtime_error_rows[0] as Dictionary
		var runtime_error_metrics := (
			runtime_error_row.get("metrics", {}) as Dictionary
		)
		runtime_error_metrics["COMBAT_RUNTIME_ERROR_COUNT"] = 1
		runtime_error_row["metrics"] = runtime_error_metrics
	_reseal_report(simulator, runtime_error_report)
	var runtime_error_result := simulator.aggregate_reports(
		[runtime_error_report],
		{"formal_matches_per_configuration": DEFAULT_FORMAL_MATCHES}
	) as Dictionary
	_expect(
		str(runtime_error_result.get("acceptance_status", "")) == "BLOCKED"
			and not simulator.safety_gates_are_green(runtime_error_result),
		"a runtime error counter blocks aggregation"
	)
	var missing := shard_report.duplicate(true)
	missing.erase("source_commit_sha")
	_reseal_report(simulator, missing)
	var missing_result := simulator.aggregate_reports(
		[missing],
		{"formal_matches_per_configuration": DEFAULT_FORMAL_MATCHES}
	) as Dictionary
	var missing_aggregation := (
		missing_result.get("aggregation", {}) as Dictionary
	)
	_expect(
		str(missing_result.get("acceptance_status", "")) == "BLOCKED"
		and int(missing_aggregation.get(
			"source_commit_sha_missing_count",
			0
		)) == 1
		and int(missing_aggregation.get(
			"source_commit_sha_mismatch_count",
			0
		)) >= 1,
		"an all-missing shard source SHA blocks aggregation"
	)
	var mismatched := shard_report.duplicate(true)
	mismatched["source_commit_sha"] = "0000000000000000000000000000000000000000"
	_reseal_report(simulator, mismatched)
	var mismatch_result := simulator.aggregate_reports(
		[shard_report, mismatched],
		{"formal_matches_per_configuration": DEFAULT_FORMAL_MATCHES}
	) as Dictionary
	var mismatch_aggregation := (
		mismatch_result.get("aggregation", {}) as Dictionary
	)
	_expect(
		str(mismatch_result.get("acceptance_status", "")) == "BLOCKED"
		and int(mismatch_aggregation.get(
			"source_commit_sha_mismatch_count",
			0
		)) >= 1,
		"mismatched shard source SHAs block aggregation"
	)
	var tampered := shard_report.duplicate(true)
	tampered["source_commit_sha"] = "1111111111111111111111111111111111111111"
	var tampered_result := simulator.aggregate_reports(
		[tampered],
		{"formal_matches_per_configuration": DEFAULT_FORMAL_MATCHES}
	) as Dictionary
	var tampered_aggregation := (
		tampered_result.get("aggregation", {}) as Dictionary
	)
	_expect(
		str(tampered_result.get("acceptance_status", "")) == "BLOCKED"
		and int(tampered_aggregation.get(
			"report_fingerprint_invalid_count",
			0
		)) == 1,
		"a tampered shard report fingerprint blocks aggregation"
	)
	var missing_harness := shard_report.duplicate(true)
	missing_harness.erase("harness_fingerprint")
	missing_harness.erase("harness_component_sha256")
	_reseal_report(simulator, missing_harness)
	var missing_harness_result := simulator.aggregate_reports(
		[missing_harness],
		{"formal_matches_per_configuration": DEFAULT_FORMAL_MATCHES}
	) as Dictionary
	var missing_harness_aggregation := (
		missing_harness_result.get("aggregation", {}) as Dictionary
	)
	_expect(
		str(missing_harness_result.get("acceptance_status", "")) == "BLOCKED"
		and int(missing_harness_aggregation.get(
			"harness_fingerprint_missing_count",
			0
		)) == 1,
		"a missing shard harness fingerprint blocks aggregation"
	)
	var mismatched_harness := shard_report.duplicate(true)
	var mismatched_components := (
		mismatched_harness.get("harness_component_sha256", {}) as Dictionary
	).duplicate(true)
	mismatched_components[SIMULATOR_PATH] = (
		"2222222222222222222222222222222222222222222222222222222222222222"
	)
	mismatched_harness["harness_component_sha256"] = mismatched_components
	mismatched_harness["harness_fingerprint"] = simulator.fingerprint(
		mismatched_components
	)
	_reseal_report(simulator, mismatched_harness)
	var mismatched_harness_result := simulator.aggregate_reports(
		[mismatched_harness],
		{"formal_matches_per_configuration": DEFAULT_FORMAL_MATCHES}
	) as Dictionary
	var mismatched_harness_aggregation := (
		mismatched_harness_result.get("aggregation", {}) as Dictionary
	)
	_expect(
		str(mismatched_harness_result.get("acceptance_status", "")) == "BLOCKED"
		and int(mismatched_harness_aggregation.get(
			"harness_fingerprint_mismatch_count",
			0
		)) == 1,
		"a mismatched shard harness fingerprint blocks aggregation"
	)


func _test_written_report(simulator: RefCounted, report: Dictionary) -> void:
	var json_path := _argument_value("--report-json", "")
	if not json_path.is_empty():
		var parsed_variant: Variant = null
		if FileAccess.file_exists(json_path):
			parsed_variant = JSON.parse_string(
				FileAccess.get_file_as_string(json_path)
			)
		_expect(
			parsed_variant is Dictionary,
			"written JSON report exists and parses as a dictionary"
		)
		if parsed_variant is Dictionary:
			var parsed := parsed_variant as Dictionary
			var payload := parsed.duplicate(true)
			var declared_fingerprint := str(payload.get(
				"report_fingerprint",
				""
			))
			payload.erase("report_fingerprint")
			_expect(
				declared_fingerprint == str(report.get(
					"report_fingerprint",
					""
				))
					and declared_fingerprint == simulator.fingerprint(payload),
				"written JSON report round-trips its sealed fingerprint"
			)
	var md_path := _argument_value("--report-md", "")
	if not md_path.is_empty():
		_expect(
			FileAccess.file_exists(md_path)
				and not FileAccess.get_file_as_string(md_path).is_empty(),
			"written Markdown report exists and is nonempty"
		)


func _test_harness_identity(report: Dictionary, label: String) -> void:
	var simulator := SIMULATOR.new()
	var expected := simulator.harness_identity() as Dictionary
	_expect(
		bool(expected.get("accepted", false))
			and str(report.get("harness_fingerprint", ""))
				== str(expected.get("fingerprint", ""))
			and (report.get(
				"harness_component_sha256",
				{}
			) as Dictionary) == (expected.get(
				"component_sha256",
				{}
			) as Dictionary),
		"%s records the current immutable harness identity" % label
	)
	var payload := report.duplicate(true)
	var declared_fingerprint := str(payload.get("report_fingerprint", ""))
	payload.erase("report_fingerprint")
	_expect(
		declared_fingerprint.length() == 64
			and declared_fingerprint == simulator.fingerprint(payload),
		"%s fingerprint seals its complete payload" % label
	)


func _reseal_report(simulator: RefCounted, report: Dictionary) -> void:
	report.erase("report_fingerprint")
	report["report_fingerprint"] = simulator.fingerprint(report)


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
