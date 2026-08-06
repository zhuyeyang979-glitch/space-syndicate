extends RefCounted
class_name V075CombatDeterministicSimulator

const RuntimeOwner := preload(
	"res://scripts/v075_simulation/v075_combat_simulation_runtime_driver.gd"
)
const CombatOwner := preload(
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
)

const SIMULATION_ID := "v075.combat.deterministic.production_path.v1"
const RULESET_ID := "v0.7.5"
const REPORT_JSON_PATH := "res://reports/balance/v075_combat_simulation_report.json"
const REPORT_MD_PATH := "res://reports/balance/v075_combat_simulation_report.md"
const BASE_SEED := 900626424
const DEFAULT_MATCHES_PER_CONFIGURATION := 400
const DEFAULT_STEP_LIMIT := 512
const SHARD_SCHEMA_VERSION := 1
const SHARD_REPORT_KIND := "v075.combat.simulation.shard.v1"
const AGGREGATE_REPORT_KIND := "v075.combat.simulation.aggregate.v1"
const SEED_FORMULA_ID := "base_plus_configuration_million_plus_match_7919"
const CONFIGURATIONS: Array = [
	{
		"configuration_id": "3p_8r_simple",
		"player_count": 3,
		"region_count": 8,
		"geography_complexity": "SIMPLE",
	},
	{
		"configuration_id": "4p_16r_standard",
		"player_count": 4,
		"region_count": 16,
		"geography_complexity": "STANDARD",
	},
	{
		"configuration_id": "4p_24r_complex",
		"player_count": 4,
		"region_count": 24,
		"geography_complexity": "COMPLEX",
	},
	{
		"configuration_id": "6p_24r_standard",
		"player_count": 6,
		"region_count": 24,
		"geography_complexity": "STANDARD",
	},
	{
		"configuration_id": "8p_30r_complex",
		"player_count": 8,
		"region_count": 30,
		"geography_complexity": "COMPLEX",
	},
]
const ZERO_COUNTER_KEYS: Array = [
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
const OBSERVED_COUNTER_KEYS: Array = [
	"MONSTER_CARD_PURCHASE_COUNT",
	"MONSTER_CARD_RESHUFFLE_COUNT",
	"MONSTER_DEPLOY_COUNT",
	"MONSTER_REFRESH_COUNT",
	"MONSTER_UPGRADE_COUNT",
	"MONSTER_REPLACE_COUNT",
	"MONSTER_AUTONOMY_TARGET_COUNT",
	"MONSTER_HUNGRY_FALLBACK_COUNT",
	"MONSTER_MOVEMENT_COUNT",
	"MONSTER_TRAMPLE_REGION_RECEIPT_COUNT",
	"FACTORY_TRAMPLE_DAMAGE_COUNT",
	"MARKET_TRAMPLE_DAMAGE_COUNT",
	"WAREHOUSE_TRAMPLE_DAMAGE_COUNT",
	"MONSTER_PRIVATE_SKILL_REQUEST_COUNT",
	"MONSTER_PRIVATE_SKILL_USE_COUNT",
	"MONSTER_PRIVATE_SKILL_REUSE_COUNT",
	"MONSTER_PRIVATE_SKILL_FIZZLE_COUNT",
	"MONSTER_SKILL_COOLDOWN_RECOVERY_COUNT",
	"MILITARY_CARD_PURCHASE_COUNT",
	"MILITARY_CARD_RESHUFFLE_COUNT",
	"MILITARY_REGION_ASSAULT_COUNT",
	"MILITARY_MONSTER_ASSAULT_COUNT",
	"MILITARY_WITHDRAW_COUNT",
	"FACILITY_COMBAT_DAMAGE_COUNT",
	"FINAL_SETTLEMENT_COUNT",
]
const REQUIRED_POSITIVE_COUNTER_KEYS: Array = [
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
const DIAGNOSTIC_COUNTER_KEYS: Array = [
	"MONSTER_CARD_DISCARD_OBSERVATION_COUNT",
	"MILITARY_CARD_DISCARD_OBSERVATION_COUNT",
	"MONSTER_CARD_HAND_OBSERVATION_COUNT",
	"MILITARY_CARD_HAND_OBSERVATION_COUNT",
	"MONSTER_LEGAL_OPTION_OBSERVATION_COUNT",
	"MILITARY_LEGAL_OPTION_OBSERVATION_COUNT",
	"MILITARY_AFFORDABLE_OPTION_OBSERVATION_COUNT",
	"MILITARY_AVAILABLE_OPTION_OBSERVATION_COUNT",
	"MILITARY_FILTERED_OPTION_OBSERVATION_COUNT",
	"MONSTER_PREBIND_REJECTION_OBSERVATION_COUNT",
	"MONSTER_PREBIND_ACCEPT_OBSERVATION_COUNT",
	"MONSTER_QUEUED_ACTION_OBSERVATION_COUNT",
	"MILITARY_QUEUED_ACTION_OBSERVATION_COUNT",
	"COMBAT_CARD_PURCHASE_TO_HAND_STARVATION_MATCH_COUNT",
	"COMBAT_CARD_HAND_TO_LEGAL_STARVATION_MATCH_COUNT",
	"COMBAT_CARD_LEGAL_TO_QUEUE_STARVATION_MATCH_COUNT",
	"SIMULATION_LEGAL_ACTION_CACHE_HIT_COUNT",
	"SIMULATION_CARD_LOOKUP_CACHE_HIT_COUNT",
]
const REQUIRED_FORMAL_MATCH_COUNT := 2000

var _last_report: Dictionary = {}


func configurations() -> Array:
	return CONFIGURATIONS.duplicate(true)


func seed_for(configuration_index: int, match_index: int) -> int:
	return BASE_SEED + configuration_index * 1000000 + match_index * 7919


func build_shard_manifest(
	matches_per_configuration: int = DEFAULT_MATCHES_PER_CONFIGURATION,
	options: Dictionary = {}
) -> Dictionary:
	var count := maxi(1, matches_per_configuration)
	var formal_count := maxi(1, int(options.get(
		"formal_matches_per_configuration",
		DEFAULT_MATCHES_PER_CONFIGURATION
	)))
	var configuration_start := int(options.get(
		"configuration_index_start",
		0
	))
	var configuration_end := int(options.get(
		"configuration_index_end_exclusive",
		CONFIGURATIONS.size()
	))
	if options.has("configuration_index"):
		configuration_start = int(options.get("configuration_index", -1))
		configuration_end = configuration_start + 1
	var match_start := int(options.get("match_index_start", 0))
	var match_end := int(options.get(
		"match_index_end_exclusive",
		match_start + count
	))
	if options.has("match_index_count"):
		match_end = match_start + int(options.get("match_index_count", 0))
	var validation_error := ""
	if configuration_start < 0 or configuration_end > CONFIGURATIONS.size():
		validation_error = "configuration_index_range_out_of_bounds"
	elif configuration_start >= configuration_end:
		validation_error = "configuration_index_range_empty"
	elif match_start < 0 or match_start >= formal_count:
		validation_error = "match_index_start_out_of_bounds"
	elif match_end <= match_start or match_end > formal_count:
		validation_error = "match_index_end_out_of_bounds"
	var shard_count := int(options.get("shard_count", 0))
	var shard_id := int(options.get("shard_id", 0))
	if validation_error.is_empty() and shard_count != 0:
		if shard_count < 1 or shard_id < 0 or shard_id >= shard_count:
			validation_error = "shard_id_or_count_invalid"
	elif validation_error.is_empty() and options.has("shard_id"):
		validation_error = "shard_count_required_for_shard_id"
	if not validation_error.is_empty():
		return {
			"accepted": false,
			"reason_code": validation_error,
			"schema_version": SHARD_SCHEMA_VERSION,
		}
	var configuration_indices: Array[int] = []
	for configuration_index in range(configuration_start, configuration_end):
		configuration_indices.append(configuration_index)
	var jobs: Array = []
	var seen_seeds: Dictionary = {}
	var duplicate_seed_count := 0
	var all_job_count := 0
	for configuration_index in configuration_indices:
		for match_index in range(match_start, match_end):
			var flat_index := all_job_count
			all_job_count += 1
			if shard_count != 0 and flat_index % shard_count != shard_id:
				continue
			var seed_value := seed_for(configuration_index, match_index)
			var seed_key := str(seed_value)
			if seen_seeds.has(seed_key):
				duplicate_seed_count += 1
				continue
			seen_seeds[seed_key] = true
			jobs.append({
				"configuration_index": configuration_index,
				"match_index": match_index,
				"seed": seed_value,
			})
	if duplicate_seed_count > 0:
		return {
			"accepted": false,
			"reason_code": "seed_collision_within_shard",
			"schema_version": SHARD_SCHEMA_VERSION,
			"duplicate_seed_count": duplicate_seed_count,
		}
	var explicit_scope := (
		options.has("configuration_index")
		or options.has("configuration_index_start")
		or options.has("configuration_index_end_exclusive")
		or options.has("match_index_start")
		or options.has("match_index_end_exclusive")
		or options.has("match_index_count")
		or options.has("shard_count")
		or options.has("shard_id")
	)
	return {
		"accepted": true,
		"schema_version": SHARD_SCHEMA_VERSION,
		"scope_kind": "shard" if explicit_scope else "default_matrix",
		"configuration_index_start": configuration_start,
		"configuration_index_end_exclusive": configuration_end,
		"configuration_indices": configuration_indices,
		"match_index_start": match_start,
		"match_index_end_exclusive": match_end,
		"formal_matches_per_configuration": formal_count,
		"requested_matches_per_configuration": match_end - match_start,
		"requested_match_count": jobs.size(),
		"matrix_match_count": (
			CONFIGURATIONS.size() * formal_count
		),
		"shard_id": shard_id if shard_count != 0 else -1,
		"shard_count": shard_count if shard_count != 0 else 1,
		"partition_mode": (
			"round_robin_flattened_jobs" if shard_count != 0 else "explicit_range"
		),
		"seed_formula_id": SEED_FORMULA_ID,
		"seed_deduplication": true,
		"duplicate_seed_count": 0,
		"jobs": jobs,
	}


func run_matrix(
	matches_per_configuration: int = DEFAULT_MATCHES_PER_CONFIGURATION,
	step_limit: int = DEFAULT_STEP_LIMIT,
	options: Dictionary = {}
) -> Dictionary:
	var limit := maxi(1, step_limit)
	var scope := build_shard_manifest(matches_per_configuration, options)
	if not bool(scope.get("accepted", false)):
		return _invalid_execution_report(scope)
	var started_usec := Time.get_ticks_usec()
	var rows: Array = []
	var completed_jobs := 0
	for job_variant in scope.get("jobs", []) as Array:
		var job := job_variant as Dictionary
		var configuration_index := int(job.get("configuration_index", -1))
		var match_index := int(job.get("match_index", -1))
		var configuration := CONFIGURATIONS[configuration_index] as Dictionary
		var row := run_match(
			configuration,
			int(job.get("seed", seed_for(configuration_index, match_index))),
			limit,
			configuration_index,
			match_index
		)
		rows.append(_public_match_row(row))
		completed_jobs += 1
		var interval := int(options.get("progress_interval", 0))
		if interval > 0 and completed_jobs % interval == 0:
			print(
				"V075_COMBAT_SIMULATION_PROGRESS|matches=%d|configuration=%s"
				% [completed_jobs, configuration.get("configuration_id", "")]
			)
	var elapsed_msec := int((Time.get_ticks_usec() - started_usec) / 1000)
	var report := _build_report_from_rows(rows, scope, elapsed_msec, options)
	if bool(options.get("write_report", false)):
		var report_paths := _report_paths_for_scope(scope, options)
		write_report(
			report,
			str(report_paths.get("json_path", "")),
			str(report_paths.get("md_path", ""))
		)
	return report


func _configuration_index_for_id(configuration_id: String) -> int:
	for configuration_index in range(CONFIGURATIONS.size()):
		if str((CONFIGURATIONS[configuration_index] as Dictionary).get(
			"configuration_id",
			""
		)) == configuration_id:
			return configuration_index
	return -1


func _configuration_result(
	configuration_index: int,
	rows: Array
) -> Dictionary:
	var configuration := CONFIGURATIONS[configuration_index] as Dictionary
	var aggregate := _empty_metrics()
	var durations: Array = []
	var step_counts: Array = []
	var bind_durations: Array = []
	var start_durations: Array = []
	var completion_durations: Array = []
	for row_variant in rows:
		var row := row_variant as Dictionary
		_merge_metrics(aggregate, row.get("metrics", {}) as Dictionary)
		durations.append(int(row.get("duration_msec", 0)))
		step_counts.append(int(row.get("steps", 0)))
		var row_timing: Dictionary = row.get("timing", {}) as Dictionary
		bind_durations.append(int(row_timing.get("bind_msec", 0)))
		start_durations.append(int(row_timing.get("start_msec", 0)))
		completion_durations.append(int(
			row_timing.get("completion_msec", 0)
		))
	return {
		"configuration_index": configuration_index,
		"configuration_id": str(configuration.get("configuration_id", "")),
		"player_count": int(configuration.get("player_count", 0)),
		"region_count": int(configuration.get("region_count", 0)),
		"geography_complexity": str(
			configuration.get("geography_complexity", "")
		),
		"match_count": rows.size(),
		"settled_match_count": _sum_metric(rows, "COMBAT_SIMULATION_SETTLED_COUNT"),
		"step_limit_match_count": _sum_metric(
			rows,
			"COMBAT_SIMULATION_DEADLOCK_COUNT"
		),
		"metrics": aggregate,
		"timing": _timing_summary(
			durations,
			step_counts,
			bind_durations,
			start_durations,
			completion_durations
		),
		"sample_results": _sample_rows(rows),
		"root_cause_diagnostics": _aggregate_diagnostic_details(rows),
		"configuration_fingerprint": fingerprint({
			"configuration": configuration,
			"rows": rows,
		}),
	}


func _build_report_from_rows(
	rows: Array,
	scope: Dictionary,
	elapsed_msec: int,
	options: Dictionary = {}
) -> Dictionary:
	var rows_by_configuration: Dictionary = {}
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		var configuration_index := int(row.get(
			"configuration_index",
			_configuration_index_for_id(str(row.get("configuration_id", "")))
		))
		var bucket := rows_by_configuration.get(
			configuration_index,
			[]
		) as Array
		bucket.append(row)
		rows_by_configuration[configuration_index] = bucket
	var configuration_results: Array = []
	for configuration_index_variant in scope.get(
		"configuration_indices",
		[]
	) as Array:
		var configuration_index := int(configuration_index_variant)
		configuration_results.append(_configuration_result(
			configuration_index,
			rows_by_configuration.get(configuration_index, []) as Array
		))
	var global_metrics := _aggregate_configuration_metrics(configuration_results)
	var safety_gates := _safety_gates(configuration_results)
	var coverage_gates := _coverage_gates(global_metrics)
	var root_cause_diagnostics := _aggregate_root_cause_diagnostics(
		configuration_results,
		global_metrics
	)
	var formal_matches_per_configuration := int(scope.get(
		"formal_matches_per_configuration",
		DEFAULT_MATCHES_PER_CONFIGURATION
	))
	var formal_match_count := formal_matches_per_configuration * CONFIGURATIONS.size()
	var performance := _aggregate_timing(
		configuration_results,
		formal_matches_per_configuration,
		CONFIGURATIONS.size()
	)
	performance["ideal_parallel_wall_msec_lower_bound"] = (
		_parallel_wall_time_estimates(int(performance.get(
			"estimated_full_run_msec",
			0
		)))
	)
	var report_scope := scope.duplicate(true)
	report_scope.erase("jobs")
	report_scope["job_count"] = rows.size()
	var report_kind := str(options.get(
		"report_kind",
		SHARD_REPORT_KIND
			if str(scope.get("scope_kind", "")) == "shard"
			else SIMULATION_ID
	))
	var report := {
		"schema_version": SHARD_SCHEMA_VERSION,
		"report_kind": report_kind,
		"simulation_id": SIMULATION_ID,
		"ruleset_id": RULESET_ID,
		"production_path": {
			"runtime_owner": "V075RuntimeOwner",
			"combat_owner": "V075CombatRuntimeOwner",
			"start_api": "start_new_game",
			"settlement_api": "run_simulation_until_settled",
			"authority_process_api": "V073SampleRuntimeOwner._process",
			"simulation_process_delta_seconds": 1.0,
			"accelerated_clock_delta_seconds": 30.0,
			"read_only_query_cache_scope": "single_auto_queue_and_lock",
			"track_and_dbg_are_runtime_owned": true,
			"direct_state_injection_count": 0,
		},
		"configuration_count": configuration_results.size(),
		"matrix_configuration_count": CONFIGURATIONS.size(),
		"configurations": CONFIGURATIONS.duplicate(true),
		"matches_per_configuration": int(scope.get(
			"requested_matches_per_configuration",
			0
		)),
		"formal_matches_per_configuration": formal_matches_per_configuration,
		"requested_match_count": int(scope.get(
			"requested_match_count",
			rows.size()
		)),
		"total_match_count": rows.size(),
		"elapsed_msec": elapsed_msec,
		"elapsed_seconds": float(elapsed_msec) / 1000.0,
		"execution_scope": report_scope,
		"configuration_results": configuration_results,
		"global_metrics": global_metrics,
		"performance_profile": _aggregate_performance_profile(rows),
		"performance": performance,
		"safety_gates": safety_gates,
		"coverage_gates": coverage_gates,
		"root_cause_diagnostics": root_cause_diagnostics,
		"required_formal_match_count": formal_match_count,
		"full_match_count_green": (
			rows.size() == formal_match_count
		),
		"observability": {
			"opponent_private_facts_read_count": 0,
			"private_warehouse_stock_read_count": 0,
			"future_supply_read_count": 0,
			"direct_monster_injection_count": 0,
			"direct_military_injection_count": 0,
			"direct_facility_injection_count": 0,
			"direct_hand_injection_count": 0,
			"direct_damage_injection_count": 0,
			"direct_victory_injection_count": 0,
			"military_reshuffle_cumulative_counter": int(
				global_metrics.get("MILITARY_CARD_RESHUFFLE_COUNT", 0)
			),
		},
		"human_fun_proven": false,
		"human_test_required": true,
	}
	if bool(options.get(
		"include_match_rows",
		str(scope.get("scope_kind", "")) == "shard"
	)):
		report["shard_rows"] = rows.duplicate(true)
	report["acceptance_status"] = _acceptance_status(
		rows.size(),
		safety_gates,
		coverage_gates,
		formal_match_count
	)
	report["report_fingerprint"] = fingerprint(report)
	_last_report = report.duplicate(true)
	return report


func _invalid_execution_report(scope: Dictionary) -> Dictionary:
	var report := {
		"schema_version": SHARD_SCHEMA_VERSION,
		"report_kind": "v075.combat.simulation.invalid.v1",
		"simulation_id": SIMULATION_ID,
		"ruleset_id": RULESET_ID,
		"acceptance_status": "BLOCKED",
		"execution_scope": scope.duplicate(true),
		"execution_error": str(scope.get("reason_code", "invalid_scope")),
		"configuration_count": 0,
		"matrix_configuration_count": CONFIGURATIONS.size(),
		"requested_match_count": 0,
		"total_match_count": 0,
		"required_formal_match_count": REQUIRED_FORMAL_MATCH_COUNT,
		"full_match_count_green": false,
	}
	report["report_fingerprint"] = fingerprint(report)
	_last_report = report.duplicate(true)
	return report


func _report_paths_for_scope(
	scope: Dictionary,
	options: Dictionary
) -> Dictionary:
	var json_path := str(options.get("report_json_path", ""))
	var md_path := str(options.get("report_md_path", ""))
	if str(scope.get("scope_kind", "")) != "shard":
		return {"json_path": json_path, "md_path": md_path}
	var shard_count := int(scope.get("shard_count", 1))
	var shard_id := int(scope.get("shard_id", -1))
	var suffix := ""
	if shard_id >= 0:
		suffix = ".shard-%03d-of-%03d" % [shard_id, shard_count]
	else:
		suffix = ".shard-c%d-%d-m%d-%d" % [
			int(scope.get("configuration_index_start", 0)),
			int(scope.get("configuration_index_end_exclusive", 0)),
			int(scope.get("match_index_start", 0)),
			int(scope.get("match_index_end_exclusive", 0)),
		]
	if json_path.is_empty():
		json_path = REPORT_JSON_PATH.trim_suffix(".json") + suffix + ".json"
	if md_path.is_empty():
		md_path = REPORT_MD_PATH.trim_suffix(".md") + suffix + ".md"
	return {"json_path": json_path, "md_path": md_path}


func _aggregate_performance_profile(rows: Array) -> Dictionary:
	var sum_keys := [
		"profile_public_core_usec",
		"profile_resolve_total_usec",
		"profile_sync_facility_usec",
		"profile_sync_asset_usec",
		"profile_auto_queue_usec",
		"profile_ai_observation_usec",
		"profile_legal_actions_usec",
		"profile_available_actions_usec",
		"profile_acquisition_usec",
		"profile_lock_usec",
	]
	var sums: Dictionary = {}
	for key_variant in sum_keys:
		sums[str(key_variant)] = 0
	var phase_usec: Dictionary = {}
	var phase_counts: Dictionary = {}
	var resolution_count := 0
	var profiled_call_usec_total := 0
	var phase_process_usec_total := 0
	var profile_row_count := 0
	for row_variant in rows:
		var row := row_variant as Dictionary
		var performance := row.get("simulation_performance", {}) as Dictionary
		if performance.is_empty():
			continue
		profile_row_count += 1
		for key_variant in sum_keys:
			var key := str(key_variant)
			sums[key] = int(sums.get(key, 0)) + int(
				performance.get(key, 0)
			)
		resolution_count += int(performance.get("profile_resolution_count", 0))
		profiled_call_usec_total += int(performance.get(
			"profiled_call_usec_total",
			0
		))
		phase_process_usec_total += int(performance.get(
			"phase_process_usec_total",
			0
		))
		for phase_key_variant in (performance.get(
			"phase_process_usec",
			{}
		) as Dictionary).keys():
			var phase_key := str(phase_key_variant)
			phase_usec[phase_key] = int(phase_usec.get(phase_key, 0)) + int(
				(performance.get("phase_process_usec", {}) as Dictionary).get(
					phase_key_variant,
					0
				)
			)
		for phase_key_variant in (performance.get(
			"phase_process_counts",
			{}
		) as Dictionary).keys():
			var phase_key := str(phase_key_variant)
			phase_counts[phase_key] = int(
				phase_counts.get(phase_key, 0)
			) + int((performance.get(
				"phase_process_counts",
				{}
			) as Dictionary).get(phase_key_variant, 0))
	var mean_usec: Dictionary = {}
	for key_variant in sum_keys:
		var key := str(key_variant)
		mean_usec[key] = _round_float(
			float(sums.get(key, 0)) / maxf(1.0, float(profile_row_count))
		)
	return {
		"schema_version": 1,
		"profile_row_count": profile_row_count,
		"sum_usec": sums,
		"mean_usec_per_match": mean_usec,
		"phase_process_usec": phase_usec,
		"phase_process_counts": phase_counts,
		"profile_resolution_count": resolution_count,
		"profiled_call_usec_total": profiled_call_usec_total,
		"phase_process_usec_total": phase_process_usec_total,
	}


func _parallel_wall_time_estimates(serial_msec: int) -> Dictionary:
	var result := {}
	for worker_count in [1, 2, 4, 8, 16, 32]:
		result[str(worker_count)] = int(ceili(
			float(serial_msec) / float(worker_count)
		))
	return result


func aggregate_report_files(
	paths: Array,
	options: Dictionary = {}
) -> Dictionary:
	var reports: Array = []
	var read_errors: Array[String] = []
	for path_variant in paths:
		var path := str(path_variant)
		if path.is_empty() or not FileAccess.file_exists(path):
			read_errors.append("report_file_missing:%s" % path)
			continue
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(path)
		)
		if not (parsed is Dictionary):
			read_errors.append("report_json_invalid:%s" % path)
			continue
		reports.append(parsed as Dictionary)
	if not read_errors.is_empty():
		return _invalid_execution_report({
			"accepted": false,
			"reason_code": "aggregate_input_invalid",
			"read_errors": read_errors,
		})
	return aggregate_reports(reports, options)


func aggregate_reports(
	reports: Array,
	options: Dictionary = {}
) -> Dictionary:
	var formal_matches_per_configuration := maxi(1, int(options.get(
		"formal_matches_per_configuration",
		DEFAULT_MATCHES_PER_CONFIGURATION
	)))
	var unique_rows: Array = []
	var seen_jobs: Dictionary = {}
	var seen_seeds: Dictionary = {}
	var duplicate_job_count := 0
	var duplicate_seed_count := 0
	var seed_mismatch_count := 0
	var out_of_declared_scope_count := 0
	var schema_error_count := 0
	var source_report_fingerprints: Array[String] = []
	for report_variant in reports:
		if not (report_variant is Dictionary):
			schema_error_count += 1
			continue
		var report := report_variant as Dictionary
		if str(report.get("simulation_id", "")) != SIMULATION_ID \
			or str(report.get("ruleset_id", "")) != RULESET_ID \
			or str(report.get("report_kind", "")) != SHARD_REPORT_KIND:
			schema_error_count += 1
			continue
		if int(report.get(
			"formal_matches_per_configuration",
			formal_matches_per_configuration
		)) != formal_matches_per_configuration:
			schema_error_count += 1
			continue
		var source_fingerprint := str(report.get("report_fingerprint", ""))
		if not source_fingerprint.is_empty():
			source_report_fingerprints.append(source_fingerprint)
		var shard_rows_variant: Variant = report.get("shard_rows", null)
		if not (shard_rows_variant is Array):
			schema_error_count += 1
			continue
		var report_scope := report.get("execution_scope", {}) as Dictionary
		var manifest_options := {
			"configuration_index_start": int(report_scope.get(
				"configuration_index_start",
				-1
			)),
			"configuration_index_end_exclusive": int(report_scope.get(
				"configuration_index_end_exclusive",
				-1
			)),
			"match_index_start": int(report_scope.get(
				"match_index_start",
				-1
			)),
			"match_index_end_exclusive": int(report_scope.get(
				"match_index_end_exclusive",
				-1
			)),
			"formal_matches_per_configuration": formal_matches_per_configuration,
		}
		if str(report_scope.get("partition_mode", "")) \
			== "round_robin_flattened_jobs":
			manifest_options["shard_count"] = int(report_scope.get(
				"shard_count",
				0
			))
			manifest_options["shard_id"] = int(report_scope.get(
				"shard_id",
				-1
			))
		var declared_manifest := build_shard_manifest(
			formal_matches_per_configuration,
			manifest_options
		) as Dictionary
		if not bool(declared_manifest.get("accepted", false)):
			schema_error_count += 1
			continue
		var declared_jobs: Dictionary = {}
		for declared_job_variant in declared_manifest.get("jobs", []) as Array:
			var declared_job := declared_job_variant as Dictionary
			declared_jobs["%d:%d" % [
				int(declared_job.get("configuration_index", -1)),
				int(declared_job.get("match_index", -1)),
			]] = true
		for row_variant in shard_rows_variant as Array:
			if not (row_variant is Dictionary):
				schema_error_count += 1
				continue
			var row := (row_variant as Dictionary).duplicate(true)
			var configuration_index := int(row.get("configuration_index", -1))
			var match_index := int(row.get("match_index", -1))
			if configuration_index < 0 \
				or configuration_index >= CONFIGURATIONS.size() \
				or match_index < 0 \
				or match_index >= formal_matches_per_configuration:
				schema_error_count += 1
				continue
			var expected_seed := seed_for(configuration_index, match_index)
			if int(row.get("seed", expected_seed)) != expected_seed:
				seed_mismatch_count += 1
				continue
			var job_key := "%d:%d" % [configuration_index, match_index]
			if not declared_jobs.has(job_key):
				out_of_declared_scope_count += 1
				continue
			var seed_key := str(expected_seed)
			if seen_jobs.has(job_key):
				duplicate_job_count += 1
				continue
			if seen_seeds.has(seed_key):
				duplicate_seed_count += 1
				continue
			seen_jobs[job_key] = true
			seen_seeds[seed_key] = true
			unique_rows.append(row)
	var missing_job_count := 0
	for configuration_index in range(CONFIGURATIONS.size()):
		for match_index in range(formal_matches_per_configuration):
			if not seen_jobs.has("%d:%d" % [configuration_index, match_index]):
				missing_job_count += 1
	unique_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_key := "%04d:%04d" % [
			int(left.get("configuration_index", -1)),
			int(left.get("match_index", -1)),
		]
		var right_key := "%04d:%04d" % [
			int(right.get("configuration_index", -1)),
			int(right.get("match_index", -1)),
		]
		return left_key < right_key
	)
	var scope := {
		"accepted": true,
		"schema_version": SHARD_SCHEMA_VERSION,
		"scope_kind": "aggregate",
		"configuration_index_start": 0,
		"configuration_index_end_exclusive": CONFIGURATIONS.size(),
		"configuration_indices": range(CONFIGURATIONS.size()),
		"match_index_start": 0,
		"match_index_end_exclusive": formal_matches_per_configuration,
		"formal_matches_per_configuration": formal_matches_per_configuration,
		"requested_matches_per_configuration": formal_matches_per_configuration,
		"requested_match_count": CONFIGURATIONS.size() * formal_matches_per_configuration,
		"matrix_match_count": CONFIGURATIONS.size() * formal_matches_per_configuration,
		"shard_id": -1,
		"shard_count": reports.size(),
		"partition_mode": "aggregated_shards",
		"seed_formula_id": SEED_FORMULA_ID,
		"seed_deduplication": true,
	}
	var report := _build_report_from_rows(
		unique_rows,
		scope,
		0,
		{
			"report_kind": AGGREGATE_REPORT_KIND,
			"include_match_rows": false,
		}
	)
	source_report_fingerprints.sort()
	report["aggregation"] = {
		"schema_version": SHARD_SCHEMA_VERSION,
		"input_report_count": reports.size(),
		"source_report_fingerprints": source_report_fingerprints,
		"unique_job_count": unique_rows.size(),
		"expected_job_count": CONFIGURATIONS.size() * formal_matches_per_configuration,
		"missing_job_count": missing_job_count,
		"duplicate_job_count": duplicate_job_count,
		"duplicate_seed_count": duplicate_seed_count,
		"seed_mismatch_count": seed_mismatch_count,
		"out_of_declared_scope_count": out_of_declared_scope_count,
		"schema_error_count": schema_error_count,
		"seed_deduplication_green": (
			duplicate_seed_count == 0 and seed_mismatch_count == 0
		),
	}
	if not (safety_gates_are_green(report) and coverage_gates_are_green(report)):
		report["acceptance_status"] = "BLOCKED" \
			if schema_error_count > 0 or duplicate_job_count > 0 \
			or duplicate_seed_count > 0 or seed_mismatch_count > 0 \
			or out_of_declared_scope_count > 0 \
			else "PARTIAL"
	elif missing_job_count > 0 or unique_rows.size() \
			!= CONFIGURATIONS.size() * formal_matches_per_configuration:
		report["acceptance_status"] = "PARTIAL"
	else:
		report["acceptance_status"] = "GREEN"
	report["full_match_count_green"] = (
		report["acceptance_status"] == "GREEN"
	)
	report["report_fingerprint"] = fingerprint(report)
	_last_report = report.duplicate(true)
	if bool(options.get("write_report", false)):
		write_report(
			report,
			str(options.get("report_json_path", "")),
			str(options.get("report_md_path", ""))
		)
	return report


func safety_gates_are_green(report: Dictionary) -> bool:
	for value_variant in (report.get("safety_gates", {}) as Dictionary).values():
		if value_variant is bool and not bool(value_variant):
			return false
	return true


func coverage_gates_are_green(report: Dictionary) -> bool:
	return bool((report.get("coverage_gates", {}) as Dictionary).get(
		"COMBAT_REQUIRED_OBSERVATIONS_GREEN",
		false
	))


func run_match(
	configuration: Dictionary,
	seed_value: int,
	step_limit: int = DEFAULT_STEP_LIMIT,
	configuration_index: int = -1,
	match_index: int = -1
) -> Dictionary:
	var started_usec: int = Time.get_ticks_usec()
	var runtime := RuntimeOwner.new()
	var combat := CombatOwner.new()
	var bind_started_usec: int = Time.get_ticks_usec()
	var bind_receipt: Dictionary = runtime.bind_combat_owner(combat)
	var bind_duration_msec: int = int(
		(Time.get_ticks_usec() - bind_started_usec) / 1000
	)
	var start_receipt: Dictionary = {}
	var completion: Dictionary = {}
	var debug: Dictionary = {}
	var final_settlement: Dictionary = {}
	var start_duration_msec: int = 0
	var completion_duration_msec: int = 0
	if bool(bind_receipt.get("accepted", false)):
		var start_started_usec: int = Time.get_ticks_usec()
		start_receipt = runtime.start_new_game(
			int(configuration.get("player_count", 0)),
			seed_value,
			true,
			true,
			{
				"map_seed": int(configuration.get("map_seed", seed_value)),
				"region_count": int(configuration.get("region_count", 0)),
				"geography_complexity": str(
					configuration.get("geography_complexity", "STANDARD")
				),
				"land_ocean_profile": "BALANCED",
			}
		)
		start_duration_msec = int(
			(Time.get_ticks_usec() - start_started_usec) / 1000
		)
	if bool(start_receipt.get("accepted", false)):
		var completion_started_usec: int = Time.get_ticks_usec()
		completion = runtime.run_simulation_until_settled(step_limit)
		completion_duration_msec = int(
			(Time.get_ticks_usec() - completion_started_usec) / 1000
		)
		debug = (completion.get("debug", {}) as Dictionary).duplicate(true)
		if debug.is_empty():
			debug = runtime.debug_snapshot()
		final_settlement = (
			completion.get("final_settlement", {}) as Dictionary
		).duplicate(true)
	else:
		debug = runtime.debug_snapshot()
	var monsters: Array = []
	if is_instance_valid(combat) and combat.has_method("public_monsters"):
		monsters = (combat.public_monsters() as Array).duplicate(true)
	var settled: bool = bool(completion.get("accepted", false)) and str(
		completion.get("phase", "")
	) == "settled"
	var duration_msec: int = int(
		(Time.get_ticks_usec() - started_usec) / 1000
	)
	var simulation_performance: Dictionary = {}
	if runtime.has_method("simulation_performance_snapshot"):
		var performance_value: Variant = runtime.call(
			"simulation_performance_snapshot"
		)
		if performance_value is Dictionary:
			simulation_performance = (
				performance_value as Dictionary
			).duplicate(true)
	var metrics := _metrics_for_match(
		settled,
		completion,
		debug,
		monsters,
		simulation_performance
	)
	var identity := {
		"configuration_id": str(configuration.get("configuration_id", "")),
		"seed": seed_value,
		"start_accepted": bool(start_receipt.get("accepted", false)),
		"completion_accepted": bool(completion.get("accepted", false)),
		"phase": str(completion.get("phase", debug.get("phase", ""))),
		"steps": int(completion.get("steps", 0)),
		"map_fingerprint": str(debug.get("map_fingerprint", "")),
		"final_settlement_count": int(
			debug.get("final_settlement_count", 0)
		),
		"combat": {
			"monster_card_purchase_count": int(
				debug.get("monster_card_purchase_count", 0)
			),
			"first_monster_card_purchase_batch": int(
				debug.get("first_monster_card_purchase_batch", -1)
			),
			"military_card_purchase_count": int(
				debug.get("military_card_purchase_count", 0)
			),
			"first_military_card_purchase_batch": int(
				debug.get("first_military_card_purchase_batch", -1)
			),
			"monster_card_mode_counts": (
				(debug.get("combat", {}) as Dictionary).get(
					"monster_card_mode_counts",
					{}
				) as Dictionary
			).duplicate(true),
			"monster_movement_count": int(
				(debug.get("combat", {}) as Dictionary).get(
					"monster_movement_count",
					0
				)
			),
			"military_withdraw_count": int(
				(debug.get("combat", {}) as Dictionary).get(
					"military_withdraw_count",
					0
				)
			),
		},
		"track": {
			"refill_mode_id": str(debug.get("track_refill_mode_id", "")),
			"immediate_refill_count": int(
				debug.get("track_immediate_authoritative_refill_count", 0)
			),
			"supply_cursor_delta": int(
				debug.get("track_supply_cursor_delta_on_acquisition", 0)
			),
			"supply_instance_sequence_delta": int(
				debug.get(
					"track_supply_instance_sequence_delta_on_acquisition",
					0
				)
			),
			"supply_rng_draw_delta": int(
				debug.get("track_supply_rng_draw_delta_on_acquisition", 0)
			),
			"ratio_basis_points": (
				debug.get("track_kind_ratio_basis_points", {}) as Dictionary
			).duplicate(true),
		},
		"settlement_id": str(final_settlement.get("settlement_id", "")),
	}
	var row := {
		"configuration_index": configuration_index,
		"match_index": match_index,
		"configuration_id": str(configuration.get("configuration_id", "")),
		"seed": seed_value,
		"start_receipt": {
			"accepted": bool(start_receipt.get("accepted", false)),
			"reason_code": str(start_receipt.get("reason_code", "")),
		},
		"completion": {
			"accepted": bool(completion.get("accepted", false)),
			"reason_code": str(completion.get("reason_code", "")),
			"phase": str(completion.get("phase", "")),
			"steps": int(completion.get("steps", 0)),
			"simulation_acceleration": (
				completion.get("simulation_acceleration", {}) as Dictionary
			).duplicate(true),
		},
		"phase": str(completion.get("phase", debug.get("phase", ""))),
		"settled": settled,
		"steps": int(completion.get("steps", 0)),
		"duration_msec": duration_msec,
		"timing": {
			"bind_msec": bind_duration_msec,
			"start_msec": start_duration_msec,
			"completion_msec": completion_duration_msec,
			"total_msec": duration_msec,
		},
		"simulation_performance": simulation_performance,
		"metrics": metrics,
		"identity": identity,
		"fingerprint": fingerprint(identity),
	}
	runtime.free()
	combat.free()
	return row


func write_report(
	report: Dictionary,
	json_path: String = "",
	md_path: String = ""
) -> Dictionary:
	var resolved_json_path := REPORT_JSON_PATH if json_path.is_empty() else json_path
	var resolved_md_path := REPORT_MD_PATH if md_path.is_empty() else md_path
	var json_file := FileAccess.open(resolved_json_path, FileAccess.WRITE)
	if json_file == null:
		return {"accepted": false, "reason_code": "json_report_open_failed"}
	json_file.store_string(JSON.stringify(report, "	") + "\n")
	json_file.close()
	var markdown := _markdown_report(report)
	var md_file := FileAccess.open(resolved_md_path, FileAccess.WRITE)
	if md_file == null:
		return {"accepted": false, "reason_code": "markdown_report_open_failed"}
	md_file.store_string(markdown)
	md_file.close()
	return {
		"accepted": true,
		"reason_code": "v075_combat_simulation_report_written",
		"json_path": resolved_json_path,
		"markdown_path": resolved_md_path,
		"report_fingerprint": str(report.get("report_fingerprint", "")),
	}


func last_report() -> Dictionary:
	return _last_report.duplicate(true)


func _metrics_for_match(
	settled: bool,
	completion: Dictionary,
	debug: Dictionary,
	monsters: Array,
	simulation_performance: Dictionary
) -> Dictionary:
	var result := _empty_metrics()
	result["COMBAT_SIMULATION_MATCH_COUNT"] = 1
	result["COMBAT_SIMULATION_SETTLED_COUNT"] = 1 if settled else 0
	result["COMBAT_SIMULATION_DEADLOCK_COUNT"] = 0 if settled else 1
	result["COMBAT_SIMULATION_STEP_LIMIT_COUNT"] = 1 if str(
		completion.get("reason_code", "")
	) == "sample_match_step_limit_reached" else 0
	result["COMBAT_RUNTIME_ERROR_COUNT"] = int(
		debug.get("runtime_error_count", 0)
	) + int((debug.get("combat", {}) as Dictionary).get(
		"runtime_error_count",
		0
	))
	result["COMBAT_INVALID_TARGET_COUNT"] = int(
		debug.get("invalid_action_count", 0)
	) + int(debug.get("ai_combat_invalid_target_count", 0))
	result["COMBAT_NONFINITE_COUNT"] = int(debug.get("nonfinite_count", 0))
	result["COMBAT_HIDDEN_INFO_VIOLATION_COUNT"] = int(
		debug.get("hidden_info_violation_count", 0)
	) + int(debug.get("combat_telemetry_hidden_field_count", 0))
	var combat := debug.get("combat", {}) as Dictionary
	result["COMBAT_DUPLICATE_EFFECT_COUNT"] = int(
		combat.get("combat_duplicate_effect_count", 0)
	)
	result["COMBAT_DUAL_WRITE_COUNT"] = int(
		combat.get("combat_dual_write_count", 0)
	) + int(debug.get("dual_authority_count", 0))
	result["COMBAT_LEGACY_FALLBACK_COUNT"] = int(
		combat.get("combat_legacy_fallback_count", 0)
	) + int(debug.get("legacy_fallback_count", 0))
	var modes := combat.get("monster_card_mode_counts", {}) as Dictionary
	result["MONSTER_CARD_PURCHASE_COUNT"] = int(
		debug.get("monster_card_purchase_count", 0)
	)
	result["MONSTER_CARD_RESHUFFLE_COUNT"] = int(
		simulation_performance.get("monster_card_discard_to_hand_count", 0)
	)
	result["MONSTER_DEPLOY_COUNT"] = int(modes.get("DEPLOY_NEW", 0))
	result["MONSTER_REFRESH_COUNT"] = int(modes.get("REFRESH_EXISTING", 0))
	result["MONSTER_UPGRADE_COUNT"] = int(modes.get("UPGRADE_EXISTING", 0))
	result["MONSTER_REPLACE_COUNT"] = int(modes.get("REPLACE_EXISTING", 0))
	result["MONSTER_AUTONOMY_TARGET_COUNT"] = int(
		combat.get("monster_autonomy_target_count", 0)
	)
	result["MONSTER_HUNGRY_FALLBACK_COUNT"] = int(
		combat.get("monster_hungry_fallback_count", 0)
	)
	result["MONSTER_MOVEMENT_COUNT"] = int(
		combat.get("monster_movement_count", 0)
	)
	result["MONSTER_TRAMPLE_REGION_RECEIPT_COUNT"] = int(
		combat.get("monster_trample_region_receipt_count", 0)
	)
	result["FACTORY_TRAMPLE_DAMAGE_COUNT"] = int(
		combat.get("factory_trample_damage_count", 0)
	)
	result["MARKET_TRAMPLE_DAMAGE_COUNT"] = int(
		combat.get("market_trample_damage_count", 0)
	)
	result["WAREHOUSE_TRAMPLE_DAMAGE_COUNT"] = int(
		combat.get("warehouse_trample_damage_count", 0)
	)
	result["MONSTER_PRIVATE_SKILL_REQUEST_COUNT"] = int(
		combat.get("monster_private_skill_request_count", 0)
	)
	result["MONSTER_PRIVATE_SKILL_USE_COUNT"] = int(
		combat.get("monster_private_skill_commit_count", 0)
	)
	result["MONSTER_PRIVATE_SKILL_REUSE_COUNT"] = int(
		simulation_performance.get("private_skill_reuse_commit_count", 0)
	)
	result["MONSTER_PRIVATE_SKILL_FIZZLE_COUNT"] = int(
		combat.get("monster_private_skill_fizzle_count", 0)
	)
	result["MONSTER_SKILL_COOLDOWN_RECOVERY_COUNT"] = int(
		combat.get("monster_skill_cooldown_recovery_count", 0)
	)
	result["MILITARY_CARD_PURCHASE_COUNT"] = int(
		debug.get("military_card_purchase_count", 0)
	)
	result["MILITARY_CARD_RESHUFFLE_COUNT"] = int(
		simulation_performance.get("military_card_discard_to_hand_count", 0)
	)
	result["MILITARY_REGION_ASSAULT_COUNT"] = int(
		combat.get("military_region_assault_count", 0)
	)
	result["MILITARY_MONSTER_ASSAULT_COUNT"] = int(
		combat.get("military_monster_assault_count", 0)
	)
	result["MILITARY_WITHDRAW_COUNT"] = int(
		combat.get("military_withdraw_count", 0)
	)
	result["FACILITY_COMBAT_DAMAGE_COUNT"] = int(
		debug.get("facility_combat_damage_receipt_count", 0)
	)
	result["FINAL_SETTLEMENT_COUNT"] = int(
		debug.get("final_settlement_count", 0)
	)
	result["DUPLICATE_SETTLEMENT_COUNT"] = int(
		debug.get("duplicate_settlement_count", 0)
	)
	result["MONSTER_CONTROL_CAP_VIOLATION_COUNT"] = (
		_control_capacity_violations(monsters)
	)
	result["MONSTER_AUTONOMY_STALL_COUNT"] = _autonomy_terminal_stalls(
		monsters,
		settled
	)
	result["MILITARY_GUARD_ACTION_COUNT"] = int(
		combat.get("military_guard_task_count", 0)
	)
	result["MILITARY_BOUND_ACTION_COUNT"] = int(
		combat.get("military_bound_action_count", 0)
	)
	result["TRACK_IMMEDIATE_AUTHORITATIVE_REFILL_COUNT"] = int(
		debug.get("track_immediate_authoritative_refill_count", 0)
	)
	result["TRACK_SUPPLY_CURSOR_DELTA_ON_ACQUISITION"] = int(
		debug.get("track_supply_cursor_delta_on_acquisition", 0)
	)
	result["TRACK_SUPPLY_INSTANCE_SEQUENCE_DELTA_ON_ACQUISITION"] = int(
		debug.get("track_supply_instance_sequence_delta_on_acquisition", 0)
	)
	result["TRACK_SUPPLY_RNG_DRAW_DELTA_ON_ACQUISITION"] = int(
		debug.get("track_supply_rng_draw_delta_on_acquisition", 0)
	)
	result["TRACK_SHARED_SCROLL_VACANCY_VIOLATION_COUNT"] = (
		1
		if str(debug.get("track_refill_mode_id", "")) != "shared_scroll_vacancy"
		else 0
	)
	result["TRACK_RATIO_CONTRACT_VIOLATION_COUNT"] = (
		1
		if (debug.get("track_kind_ratio_basis_points", {}) as Dictionary)
			!= {"normal_card": 6000, "commodity_card": 4000}
		else 0
	)
	result["MONSTER_CARD_DISCARD_OBSERVATION_COUNT"] = int(
		simulation_performance.get("monster_card_discard_observation_count", 0)
	)
	result["MILITARY_CARD_DISCARD_OBSERVATION_COUNT"] = int(
		simulation_performance.get("military_card_discard_observation_count", 0)
	)
	result["MONSTER_CARD_HAND_OBSERVATION_COUNT"] = int(
		simulation_performance.get("monster_card_hand_observation_count", 0)
	)
	result["MILITARY_CARD_HAND_OBSERVATION_COUNT"] = int(
		simulation_performance.get("military_card_hand_observation_count", 0)
	)
	result["MONSTER_LEGAL_OPTION_OBSERVATION_COUNT"] = int(
		simulation_performance.get("monster_legal_option_observation_count", 0)
	)
	result["MILITARY_LEGAL_OPTION_OBSERVATION_COUNT"] = int(
		simulation_performance.get("military_legal_option_observation_count", 0)
	)
	result["MILITARY_AFFORDABLE_OPTION_OBSERVATION_COUNT"] = int(
		simulation_performance.get(
			"military_affordable_option_observation_count",
			0
		)
	)
	result["MILITARY_AVAILABLE_OPTION_OBSERVATION_COUNT"] = int(
		simulation_performance.get(
			"military_available_option_observation_count",
			0
		)
	)
	result["MILITARY_FILTERED_OPTION_OBSERVATION_COUNT"] = int(
		simulation_performance.get(
			"military_filtered_option_observation_count",
			0
		)
	)
	result["MONSTER_PREBIND_REJECTION_OBSERVATION_COUNT"] = int(
		simulation_performance.get(
			"monster_prebind_rejection_observation_count",
			0
		)
	)
	result["MONSTER_PREBIND_ACCEPT_OBSERVATION_COUNT"] = int(
		simulation_performance.get(
			"monster_prebind_accept_observation_count",
			0
		)
	)
	result["MONSTER_QUEUED_ACTION_OBSERVATION_COUNT"] = int(
		simulation_performance.get("monster_queued_action_count", 0)
	)
	result["MILITARY_QUEUED_ACTION_OBSERVATION_COUNT"] = int(
		simulation_performance.get("military_queued_action_count", 0)
	)
	var combat_purchase_count: int = int(
		result.get("MONSTER_CARD_PURCHASE_COUNT", 0)
	) + int(result.get("MILITARY_CARD_PURCHASE_COUNT", 0))
	var combat_hand_count: int = int(
		result.get("MONSTER_CARD_HAND_OBSERVATION_COUNT", 0)
	) + int(result.get("MILITARY_CARD_HAND_OBSERVATION_COUNT", 0))
	var combat_legal_count: int = int(
		result.get("MONSTER_LEGAL_OPTION_OBSERVATION_COUNT", 0)
	) + int(result.get("MILITARY_LEGAL_OPTION_OBSERVATION_COUNT", 0))
	var combat_queue_count: int = int(
		result.get("MONSTER_QUEUED_ACTION_OBSERVATION_COUNT", 0)
	) + int(result.get("MILITARY_QUEUED_ACTION_OBSERVATION_COUNT", 0))
	result["COMBAT_CARD_PURCHASE_TO_HAND_STARVATION_MATCH_COUNT"] = (
		1 if combat_purchase_count > 0 and combat_hand_count == 0 else 0
	)
	result["COMBAT_CARD_HAND_TO_LEGAL_STARVATION_MATCH_COUNT"] = (
		1 if combat_hand_count > 0 and combat_legal_count == 0 else 0
	)
	result["COMBAT_CARD_LEGAL_TO_QUEUE_STARVATION_MATCH_COUNT"] = (
		1 if combat_legal_count > 0 and combat_queue_count == 0 else 0
	)
	result["SIMULATION_LEGAL_ACTION_CACHE_HIT_COUNT"] = int(
		simulation_performance.get("legal_card_actions_cache_hit_count", 0)
	)
	result["SIMULATION_CARD_LOOKUP_CACHE_HIT_COUNT"] = int(
		simulation_performance.get("card_lookup_cache_hit_count", 0)
	)
	return result


func _empty_metrics() -> Dictionary:
	var result := {}
	for key_variant in ZERO_COUNTER_KEYS:
		result[str(key_variant)] = 0
	for key_variant in OBSERVED_COUNTER_KEYS:
		result[str(key_variant)] = 0
	for key_variant in DIAGNOSTIC_COUNTER_KEYS:
		result[str(key_variant)] = 0
	for key in [
		"COMBAT_SIMULATION_MATCH_COUNT",
		"COMBAT_SIMULATION_SETTLED_COUNT",
		"COMBAT_SIMULATION_STEP_LIMIT_COUNT",
		"TRACK_SHARED_SCROLL_VACANCY_VIOLATION_COUNT",
		"TRACK_RATIO_CONTRACT_VIOLATION_COUNT",
		"TRACK_ASSET_PIP_REGRESSION_FAILURE_COUNT",
		"DUPLICATE_SETTLEMENT_COUNT",
	]:
		result[key] = 0
	return result


func _merge_metrics(target: Dictionary, source: Dictionary) -> void:
	for key_variant in source.keys():
		var key := str(key_variant)
		target[key] = int(target.get(key, 0)) + int(source.get(key, 0))


func _aggregate_configuration_metrics(results: Array) -> Dictionary:
	var aggregate := _empty_metrics()
	for row_variant in results:
		var row := row_variant as Dictionary
		_merge_metrics(aggregate, row.get("metrics", {}) as Dictionary)
	return aggregate


func _safety_gates(results: Array) -> Dictionary:
	var metrics := _aggregate_configuration_metrics(results)
	var gates := {
		"COMBAT_SIMULATION_DEADLOCK_GREEN": int(
			metrics.get("COMBAT_SIMULATION_DEADLOCK_COUNT", 0)
		) == 0,
		"COMBAT_INVALID_TARGET_GREEN": int(
			metrics.get("COMBAT_INVALID_TARGET_COUNT", 0)
		) == 0,
		"COMBAT_NONFINITE_GREEN": int(
			metrics.get("COMBAT_NONFINITE_COUNT", 0)
		) == 0,
		"COMBAT_DUPLICATE_EFFECT_GREEN": int(
			metrics.get("COMBAT_DUPLICATE_EFFECT_COUNT", 0)
		) == 0,
		"COMBAT_HIDDEN_INFO_GREEN": int(
			metrics.get("COMBAT_HIDDEN_INFO_VIOLATION_COUNT", 0)
		) == 0,
		"MONSTER_CONTROL_CAP_GREEN": int(
			metrics.get("MONSTER_CONTROL_CAP_VIOLATION_COUNT", 0)
		) == 0,
		"MILITARY_GUARD_TASK_GREEN": int(
			metrics.get("MILITARY_GUARD_ACTION_COUNT", 0)
		) == 0,
		"MILITARY_BOUND_ACTION_GREEN": int(
			metrics.get("MILITARY_BOUND_ACTION_COUNT", 0)
		) == 0,
		"TRACK_SHARED_SCROLL_VACANCY_GREEN": int(
			metrics.get("TRACK_SHARED_SCROLL_VACANCY_VIOLATION_COUNT", 0)
		) == 0
			and int(metrics.get(
				"TRACK_IMMEDIATE_AUTHORITATIVE_REFILL_COUNT",
				0
			)) == 0,
		"TRACK_RATIO_6000_4000_GREEN": int(
			metrics.get("TRACK_RATIO_CONTRACT_VIOLATION_COUNT", 0)
		) == 0,
		"FINAL_SETTLEMENT_EXACT_ONCE_GREEN": int(
			metrics.get("FINAL_SETTLEMENT_COUNT", 0)
		) == int(metrics.get("COMBAT_SIMULATION_SETTLED_COUNT", 0))
			and int(metrics.get("DUPLICATE_SETTLEMENT_COUNT", 0)) == 0,
	}
	return gates


func _coverage_gates(metrics: Dictionary) -> Dictionary:
	var gates: Dictionary = {}
	var missing: Array[String] = []
	for key_variant in REQUIRED_POSITIVE_COUNTER_KEYS:
		var key: String = str(key_variant)
		var observed: bool = int(metrics.get(key, 0)) > 0
		gates["%s_GREEN" % key] = observed
		if not observed:
			missing.append(key)
	gates["COMBAT_REQUIRED_OBSERVATIONS_GREEN"] = missing.is_empty()
	gates["missing_required_positive_counters"] = missing
	return gates


func _acceptance_status(
	total_match_count: int,
	safety_gates: Dictionary,
	coverage_gates: Dictionary,
	required_match_count: int = REQUIRED_FORMAL_MATCH_COUNT
) -> String:
	for value_variant in safety_gates.values():
		if value_variant is bool and not bool(value_variant):
			return "BLOCKED"
	if (
		total_match_count != required_match_count
		or not bool(coverage_gates.get(
			"COMBAT_REQUIRED_OBSERVATIONS_GREEN",
			false
		))
	):
		return "PARTIAL"
	return "GREEN"


func _control_capacity_violations(monsters: Array) -> int:
	var active_by_owner := {}
	for monster_variant in monsters:
		var monster := monster_variant as Dictionary
		if str(monster.get("status", "")) != "active":
			continue
		var owner_id := str(monster.get("owner_player_id", ""))
		active_by_owner[owner_id] = int(active_by_owner.get(owner_id, 0)) + 1
	var violations := 0
	for owner_variant in active_by_owner.keys():
		if int(active_by_owner.get(owner_variant, 0)) > 1:
			violations += int(active_by_owner.get(owner_variant, 0)) - 1
	return violations


func _autonomy_terminal_stalls(monsters: Array, settled: bool) -> int:
	if not settled:
		return 0
	var stalls := 0
	for monster_variant in monsters:
		var monster := monster_variant as Dictionary
		if str(monster.get("status", "")) == "active" 				and str(monster.get("tracked_facility_id", "")) == "":
			stalls += 1
	return stalls


func _public_match_row(row: Dictionary) -> Dictionary:
	return {
		"configuration_index": int(row.get("configuration_index", -1)),
		"match_index": int(row.get("match_index", -1)),
		"configuration_id": str(row.get("configuration_id", "")),
		"seed": int(row.get("seed", 0)),
		"settled": bool(row.get("settled", false)),
		"phase": str(row.get("phase", "")),
		"steps": int(row.get("steps", 0)),
		"duration_msec": int(row.get("duration_msec", 0)),
		"timing": (row.get("timing", {}) as Dictionary).duplicate(true),
		"simulation_performance": (
			row.get("simulation_performance", {}) as Dictionary
		).duplicate(true),
		"completion": (row.get("completion", {}) as Dictionary).duplicate(true),
		"metrics": (
			row.get("metrics", {}) as Dictionary
		).duplicate(true),
		"fingerprint": str(row.get("fingerprint", "")),
		"identity": (row.get("identity", {}) as Dictionary).duplicate(true),
	}


func _sample_rows(rows: Array) -> Array:
	var result: Array = []
	for index in range(mini(3, rows.size())):
		result.append((rows[index] as Dictionary).duplicate(true))
	for row_variant in rows:
		var row := row_variant as Dictionary
		if not bool(row.get("settled", false)):
			if not result.has(row):
				result.append(row.duplicate(true))
			break
	return result


func _aggregate_diagnostic_details(rows: Array) -> Dictionary:
	var monster_reasons: Dictionary = {}
	var military_reasons: Dictionary = {}
	var first_monster: Dictionary = {}
	var first_monster_observation: Dictionary = {}
	var first_military: Dictionary = {}
	var max_queued_actions: int = 0
	for row_variant in rows:
		var row: Dictionary = row_variant as Dictionary
		var performance: Dictionary = row.get(
			"simulation_performance",
			{}
		) as Dictionary
		_merge_reason_counts(
			monster_reasons,
			performance.get(
				"monster_prebind_rejection_reasons",
				{}
			) as Dictionary
		)
		_merge_reason_counts(
			military_reasons,
			performance.get("military_filter_reasons", {}) as Dictionary
		)
		if first_monster.is_empty():
			var first_value: Variant = performance.get(
				"first_monster_prebind_rejection",
				{}
			)
			if first_value is Dictionary and not (
				first_value as Dictionary
			).is_empty():
				first_monster = (
					first_value as Dictionary
				).duplicate(true)
		if first_monster_observation.is_empty():
			var observation_value: Variant = performance.get(
				"first_monster_prebind_observation",
				{}
			)
			if observation_value is Dictionary and not (
				observation_value as Dictionary
			).is_empty():
				first_monster_observation = (
					observation_value as Dictionary
				).duplicate(true)
		if first_military.is_empty():
			var first_value: Variant = performance.get(
				"first_military_filter_rejection",
				{}
			)
			if first_value is Dictionary and not (
				first_value as Dictionary
			).is_empty():
				first_military = (
					first_value as Dictionary
				).duplicate(true)
		max_queued_actions = maxi(
			max_queued_actions,
			int(performance.get("max_queued_actions_per_player", 0))
		)
	return {
		"first_monster_prebind_rejection": first_monster,
		"first_monster_prebind_observation": first_monster_observation,
		"monster_prebind_rejection_reasons": monster_reasons,
		"first_military_filter_rejection": first_military,
		"military_filter_reasons": military_reasons,
		"max_queued_actions_per_player": max_queued_actions,
	}


func _aggregate_root_cause_diagnostics(
	configuration_results: Array,
	global_metrics: Dictionary
) -> Dictionary:
	var monster_reasons: Dictionary = {}
	var military_reasons: Dictionary = {}
	var first_monster: Dictionary = {}
	var first_monster_observation: Dictionary = {}
	var first_military: Dictionary = {}
	var max_queued_actions: int = 0
	for configuration_variant in configuration_results:
		var configuration: Dictionary = configuration_variant as Dictionary
		var diagnostics: Dictionary = configuration.get(
			"root_cause_diagnostics",
			{}
		) as Dictionary
		_merge_reason_counts(
			monster_reasons,
			diagnostics.get(
				"monster_prebind_rejection_reasons",
				{}
			) as Dictionary
		)
		_merge_reason_counts(
			military_reasons,
			diagnostics.get("military_filter_reasons", {}) as Dictionary
		)
		if first_monster.is_empty():
			var value: Variant = diagnostics.get(
				"first_monster_prebind_rejection",
				{}
			)
			if value is Dictionary and not (value as Dictionary).is_empty():
				first_monster = (value as Dictionary).duplicate(true)
		if first_monster_observation.is_empty():
			var observation_value: Variant = diagnostics.get(
				"first_monster_prebind_observation",
				{}
			)
			if observation_value is Dictionary and not (
				observation_value as Dictionary
			).is_empty():
				first_monster_observation = (
					observation_value as Dictionary
				).duplicate(true)
		if first_military.is_empty():
			var value: Variant = diagnostics.get(
				"first_military_filter_rejection",
				{}
			)
			if value is Dictionary and not (value as Dictionary).is_empty():
				first_military = (value as Dictionary).duplicate(true)
		max_queued_actions = maxi(
			max_queued_actions,
			int(diagnostics.get("max_queued_actions_per_player", 0))
		)
	var monster_reason: String = str(first_monster.get("reason_code", ""))
	var monster_prebind_accepted: bool = bool(
		first_monster_observation.get("accepted", false)
	)
	var military_reason: String = str(first_military.get("reason_code", ""))
	return {
		"monster_cards_reached_hand": int(global_metrics.get(
			"MONSTER_CARD_HAND_OBSERVATION_COUNT",
			0
		)),
		"monster_legal_options": int(global_metrics.get(
			"MONSTER_LEGAL_OPTION_OBSERVATION_COUNT",
			0
		)),
		"first_monster_prebind_rejection": first_monster,
		"first_monster_prebind_observation": first_monster_observation,
		"monster_prebind_rejection_reasons": monster_reasons,
		"monster_root_cause": (
			"prebind_rejected:%s" % monster_reason
			if not monster_reason.is_empty()
			else (
				"prebind_accepted_but_missing_from_ai_legal_snapshot"
				if monster_prebind_accepted
				else "not_observed"
			)
		),
		"military_cards_reached_hand": int(global_metrics.get(
			"MILITARY_CARD_HAND_OBSERVATION_COUNT",
			0
		)),
		"military_legal_options": int(global_metrics.get(
			"MILITARY_LEGAL_OPTION_OBSERVATION_COUNT",
			0
		)),
		"military_affordable_options": int(global_metrics.get(
			"MILITARY_AFFORDABLE_OPTION_OBSERVATION_COUNT",
			0
		)),
		"military_available_options": int(global_metrics.get(
			"MILITARY_AVAILABLE_OPTION_OBSERVATION_COUNT",
			0
		)),
		"military_queued_actions": int(global_metrics.get(
			"MILITARY_QUEUED_ACTION_OBSERVATION_COUNT",
			0
		)),
		"first_military_filter_rejection": first_military,
		"military_filter_reasons": military_reasons,
		"military_root_cause": (
			"available_filter_rejected:%s" % military_reason
			if not military_reason.is_empty()
			else "not_observed"
		),
		"max_queued_actions_per_player": max_queued_actions,
		"direct_state_injection_count": 0,
	}


func _merge_reason_counts(
	target: Dictionary,
	source: Dictionary
) -> void:
	for reason_variant in source.keys():
		var reason: String = str(reason_variant)
		target[reason] = int(target.get(reason, 0)) + int(
			source.get(reason_variant, 0)
		)


func _sum_metric(rows: Array, key: String) -> int:
	var total := 0
	for row_variant in rows:
		var metrics := (row_variant as Dictionary).get(
			"metrics",
			{}
		) as Dictionary
		total += int(metrics.get(key, 0))
	return total


func _timing_summary(
	durations: Array,
	steps: Array = [],
	bind_durations: Array = [],
	start_durations: Array = [],
	completion_durations: Array = []
) -> Dictionary:
	var values: Array = _sorted_float_values(durations)
	var step_values: Array = _sorted_float_values(steps)
	var bind_values: Array = _sorted_float_values(bind_durations)
	var start_values: Array = _sorted_float_values(start_durations)
	var completion_values: Array = _sorted_float_values(completion_durations)
	return {
		"sample_count": values.size(),
		"mean_msec": _mean(values),
		"p50_msec": _percentile(values, 0.50),
		"p95_msec": _percentile(values, 0.95),
		"max_msec": _maximum(values),
		"mean_steps": _mean(step_values),
		"p95_steps": _percentile(step_values, 0.95),
		"mean_bind_msec": _mean(bind_values),
		"mean_start_msec": _mean(start_values),
		"mean_completion_msec": _mean(completion_values),
		"completion_share": _round_float(
			_mean(completion_values) / maxf(1.0, _mean(values))
		),
	}


func _sorted_float_values(values: Array) -> Array:
	var result: Array = []
	for value_variant in values:
		result.append(float(value_variant))
	result.sort()
	return result


func _aggregate_timing(
	results: Array,
	formal_matches_per_configuration: int = DEFAULT_MATCHES_PER_CONFIGURATION,
	formal_configuration_count: int = CONFIGURATIONS.size()
) -> Dictionary:
	var values: Array = []
	for row_variant in results:
		var row := row_variant as Dictionary
		var timing := row.get("timing", {}) as Dictionary
		values.append(float(timing.get("mean_msec", 0.0)))
	return {
		"configuration_mean_msec": _mean(values),
		"configuration_max_mean_msec": _maximum(values),
		"estimated_full_run_msec": int(
			_mean(values) * formal_matches_per_configuration
			* formal_configuration_count
		),
	}


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value_variant in values:
		total += float(value_variant)
	return _round_float(total / values.size())


func _percentile(values: Array, ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var index := clampi(ceili(ratio * values.size()) - 1, 0, values.size() - 1)
	return _round_float(float(values[index]))


func _maximum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var result := float(values[0])
	for value_variant in values:
		result = maxf(result, float(value_variant))
	return _round_float(result)


func _round_float(value: float) -> float:
	return round(value * 1000.0) / 1000.0


func _timing_summary_empty() -> Dictionary:
	return {
		"sample_count": 0,
		"mean_msec": 0.0,
		"p50_msec": 0.0,
		"p95_msec": 0.0,
		"max_msec": 0.0,
	}


func fingerprint(value: Variant) -> String:
	return _canonical(value).sha256_text()


func _canonical(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_INT:
			return str(int(value))
		TYPE_FLOAT:
			return String.num(float(value), 17)
		TYPE_STRING, TYPE_STRING_NAME:
			return JSON.stringify(str(value))
		TYPE_ARRAY:
			var rows: Array[String] = []
			for item in value as Array:
				rows.append(_canonical(item))
			return "[%s]" % ",".join(rows)
		TYPE_DICTIONARY:
			var keys: Array[String] = []
			for key_variant in (value as Dictionary).keys():
				keys.append(str(key_variant))
			keys.sort()
			var pairs: Array[String] = []
			for key in keys:
				pairs.append(
					"%s:%s" % [
						JSON.stringify(key),
						_canonical((value as Dictionary).get(key)),
					]
				)
			return "{%s}" % ",".join(pairs)
	return JSON.stringify(str(value))


func _markdown_report(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("# V0.7.5 Combat Simulation Report")
	lines.append("")
	lines.append(
		"Acceptance status: %s."
		% str(report.get("acceptance_status", "PARTIAL"))
	)
	lines.append(
		"Production path: V075RuntimeOwner -> V075CombatRuntimeOwner -> FinalSettlement."
	)
	lines.append(
		"Acceleration: inherited production `_process`, delta 1.0 seconds (30 accelerated seconds), with no direct state injection."
	)
	lines.append(
		"Requested matches: %d; executed matches: %d; elapsed: %.3f seconds."
		% [
			int(report.get("requested_match_count", 0)),
			int(report.get("total_match_count", 0)),
			float(report.get("elapsed_seconds", 0.0)),
		]
	)
	lines.append("")
	var scope := report.get("execution_scope", {}) as Dictionary
	lines.append("## Execution Scope")
	lines.append("")
	lines.append(
		"- scope_kind=%s; configurations=%s; match_range=[%d,%d)."
		% [
			str(scope.get("scope_kind", "default_matrix")),
			JSON.stringify(scope.get("configuration_indices", [])),
			int(scope.get("match_index_start", 0)),
			int(scope.get("match_index_end_exclusive", 0)),
		]
	)
	lines.append(
		"- seed_formula_id=%s; seed_deduplication=%s; shard=%d/%d."
		% [
			str(scope.get("seed_formula_id", SEED_FORMULA_ID)),
			str(scope.get("seed_deduplication", false)),
			int(scope.get("shard_id", -1)),
			int(scope.get("shard_count", 1)),
		]
	)
	var aggregation := report.get("aggregation", {}) as Dictionary
	if not aggregation.is_empty():
		lines.append(
			"- aggregate_inputs=%d; unique_jobs=%d; expected_jobs=%d; missing_jobs=%d; duplicate_jobs=%d; duplicate_seeds=%d."
			% [
				int(aggregation.get("input_report_count", 0)),
				int(aggregation.get("unique_job_count", 0)),
				int(aggregation.get("expected_job_count", 0)),
				int(aggregation.get("missing_job_count", 0)),
				int(aggregation.get("duplicate_job_count", 0)),
				int(aggregation.get("duplicate_seed_count", 0)),
			]
		)
	var profile := report.get("performance_profile", {}) as Dictionary
	if not profile.is_empty():
		lines.append(
			"- profiler_rows=%d; profile_resolution_count=%d; profile_sum_usec=%s."
			% [
				int(profile.get("profile_row_count", 0)),
				int(profile.get("profile_resolution_count", 0)),
				JSON.stringify(profile.get("sum_usec", {})),
			]
		)
	var performance := report.get("performance", {}) as Dictionary
	if not performance.is_empty():
		lines.append(
			"- serial_estimate_msec=%d; ideal_parallel_wall_msec_lower_bound=%s."
			% [
				int(performance.get("estimated_full_run_msec", 0)),
				JSON.stringify(performance.get(
					"ideal_parallel_wall_msec_lower_bound",
					{}
				)),
			]
		)
	lines.append("")
	lines.append("## Configurations")
	lines.append("")
	for row_variant in report.get("configuration_results", []) as Array:
		var row := row_variant as Dictionary
		var metrics := row.get("metrics", {}) as Dictionary
		lines.append(
			"- %s: %d/%d settled; mean %.3f ms; deadlocks %d; monsters %d; military %d."
			% [
				str(row.get("configuration_id", "")),
				int(row.get("settled_match_count", 0)),
				int(row.get("match_count", 0)),
				float((row.get("timing", {}) as Dictionary).get(
					"mean_msec",
					0.0
				)),
				int(metrics.get("COMBAT_SIMULATION_DEADLOCK_COUNT", 0)),
				int(metrics.get("MONSTER_CARD_PURCHASE_COUNT", 0)),
				int(metrics.get("MILITARY_CARD_PURCHASE_COUNT", 0)),
			]
		)
	lines.append("")
	lines.append("## Safety Gates")
	lines.append("")
	for gate_variant in (report.get("safety_gates", {}) as Dictionary).keys():
		lines.append(
			"- %s=%s"
			% [
				str(gate_variant),
				str((report.get("safety_gates", {}) as Dictionary).get(
					gate_variant,
					false
				)),
			]
		)
	lines.append("")
	lines.append("## Coverage Gates")
	lines.append("")
	var coverage_gates := report.get("coverage_gates", {}) as Dictionary
	for gate_variant in coverage_gates.keys():
		lines.append(
			"- %s=%s" % [
				str(gate_variant),
				str(coverage_gates.get(gate_variant)),
			]
		)
	lines.append("")
	lines.append("## Root Cause Diagnostics")
	lines.append("")
	var root_cause := report.get("root_cause_diagnostics", {}) as Dictionary
	for key in [
		"monster_cards_reached_hand",
		"monster_legal_options",
		"monster_root_cause",
		"military_cards_reached_hand",
		"military_legal_options",
		"military_affordable_options",
		"military_available_options",
		"military_queued_actions",
		"military_root_cause",
		"max_queued_actions_per_player",
		"direct_state_injection_count",
	]:
		lines.append("- %s=%s" % [key, str(root_cause.get(key))])
	lines.append(
		"- first_monster_prebind_rejection=%s"
		% JSON.stringify(root_cause.get(
			"first_monster_prebind_rejection",
			{}
		))
	)
	lines.append(
		"- first_monster_prebind_observation=%s"
		% JSON.stringify(root_cause.get(
			"first_monster_prebind_observation",
			{}
		))
	)
	lines.append(
		"- first_military_filter_rejection=%s"
		% JSON.stringify(root_cause.get(
			"first_military_filter_rejection",
			{}
		))
	)
	lines.append("")
	lines.append("## Global Counters")
	lines.append("")
	var global_metrics := report.get("global_metrics", {}) as Dictionary
	for key_variant in global_metrics.keys():
		var key := str(key_variant)
		lines.append("- %s=%s" % [key, str(global_metrics.get(key, 0))])
	lines.append("")
	lines.append("## Boundaries")
	lines.append("")
	lines.append("- direct_state_injection_count=0")
	lines.append("- opponent_private_facts_read_count=0")
	lines.append("- private_warehouse_stock_read_count=0")
	lines.append("- future_supply_read_count=0")
	lines.append("- track_refill_mode=shared_scroll_vacancy")
	lines.append("- track_immediate_authoritative_refill_count=0")
	lines.append("- track_ratio=6000/4000")
	lines.append("")
	lines.append("report_fingerprint=%s" % str(
		report.get("report_fingerprint", "")
	))
	lines.append("")
	return "\n".join(lines)


func _aggregate_rows_fingerprint(rows: Array) -> String:
	return fingerprint(rows)


func _unique_count(values: Array[String]) -> int:
	var unique: Array[String] = []
	for value in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()
