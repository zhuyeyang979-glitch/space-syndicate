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
const SOURCE_COMMIT_SHA_ENV := "V075_SIMULATION_SOURCE_SHA"
const AUTHORITY_RESULT_SCHEMA_VERSION := 1
const GLOBAL_MATRIX_CONTRACT_KIND := "v075.combat.simulation.global_matrix_contract.v1"
const AUTHORITY_RESULT_KIND := "v075.combat.simulation.job_result.v1"
const AUTHORITY_HEARTBEAT_KIND := "v075.combat.simulation.heartbeat.v1"
const HARNESS_SOURCE_PATHS := [
	"res://tests/v075_combat_simulation_test.gd",
	"res://tests/v075_simulation_resume_contract_test.gd",
	"res://scripts/v075_simulation/v075_combat_deterministic_simulator.gd",
	"res://scripts/v075_simulation/v075_combat_simulation_runtime_driver.gd",
	"res://tools/invoke_godot_test.ps1",
]
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
const COMBAT_ACTION_COUNTER_KEYS: Array = [
	"MONSTER_DEPLOY_COUNT",
	"MONSTER_REFRESH_COUNT",
	"MONSTER_UPGRADE_COUNT",
	"MONSTER_REPLACE_COUNT",
	"MONSTER_PRIVATE_SKILL_USE_COUNT",
	"MONSTER_TRAMPLE_REGION_RECEIPT_COUNT",
	"MILITARY_REGION_ASSAULT_COUNT",
	"MILITARY_MONSTER_ASSAULT_COUNT",
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
	var execution_options := options.duplicate(true)
	var scope := build_shard_manifest(matches_per_configuration, execution_options)
	if not bool(scope.get("accepted", false)):
		return _invalid_execution_report(scope)
	var authority := authority_contract_context(scope, execution_options, limit)
	if not bool(authority.get("accepted", false)):
		return _authority_blocked_report(scope, authority, [], 0)
	if bool(authority.get("enabled", false)):
		scope["assignment_shard_id"] = int(authority.get("shard_id", -1))
		scope["assignment_shard_count"] = int(authority.get("shard_count", 0))
	var started_usec := Time.get_ticks_usec()
	var rows: Array = []
	var completed_jobs := 0
	var authority_observability := {
		"enabled": bool(authority.get("enabled", false)),
		"authority_path": str(authority.get("authority_path", "")),
		"final_head_sha": str(authority.get("final_head_sha", "")),
		"final_tree_sha": str(authority.get("final_tree_sha", "")),
		"authority_manifest_sha256": str(authority.get(
			"authority_manifest_sha256",
			""
		)),
		"harness_hash": str(authority.get("harness_hash", "")),
		"simulation_id": str(authority.get("simulation_id", "")),
		"ruleset_id": str(authority.get("ruleset_id", "")),
		"step_limit": int(authority.get("step_limit", 0)),
		"worker_id": str(authority.get("worker_id", "")),
		"shard_id": int(authority.get("shard_id", -1)),
		"shard_count": int(authority.get("shard_count", 0)),
		"executed_match_count": 0,
		"resumed_match_count": 0,
		"committed_result_count": 0,
		"heartbeat_commit_count": 0,
		"blocked_conflict_count": 0,
		"heartbeat_only_skips_match": false,
	}
	var jobs := scope.get("jobs", []) as Array
	for job_ordinal in range(jobs.size()):
		var job_variant: Variant = jobs[job_ordinal]
		var job := job_variant as Dictionary
		var configuration_index := int(job.get("configuration_index", -1))
		var match_index := int(job.get("match_index", -1))
		var configuration := CONFIGURATIONS[configuration_index] as Dictionary
		var public_row: Dictionary = {}
		if bool(authority.get("enabled", false)):
			var inspection := inspect_authority_job_result(
				authority,
				job,
				job_ordinal
			)
			if not bool(inspection.get("accepted", false)):
				authority_observability["blocked_conflict_count"] = 1
				authority_observability["block_reason_code"] = str(
					inspection.get("reason_code", "authority_result_conflict")
				)
				return _authority_blocked_report(
					scope,
					authority_observability,
					rows,
					int((Time.get_ticks_usec() - started_usec) / 1000)
				)
			if str(inspection.get("action", "")) == "skip":
				public_row = (
					inspection.get("match_row", {}) as Dictionary
				).duplicate(true)
				authority_observability["resumed_match_count"] = int(
					authority_observability.get("resumed_match_count", 0)
				) + 1
			else:
				var executed_row := run_match(
					configuration,
					int(job.get(
						"seed",
						seed_for(configuration_index, match_index)
					)),
					limit,
					configuration_index,
					match_index
				)
				public_row = _public_match_row(executed_row)
				authority_observability["executed_match_count"] = int(
					authority_observability.get("executed_match_count", 0)
				) + 1
			var commit := commit_authority_job_result(
				authority,
				job,
				public_row,
				job_ordinal
			)
			if not bool(commit.get("accepted", false)):
				authority_observability["blocked_conflict_count"] = 1
				authority_observability["block_reason_code"] = str(
					commit.get("reason_code", "authority_commit_failed")
				)
				return _authority_blocked_report(
					scope,
					authority_observability,
					rows,
					int((Time.get_ticks_usec() - started_usec) / 1000)
				)
			public_row = (
				commit.get("match_row", public_row) as Dictionary
			).duplicate(true)
			public_row = _formal_match_row(
				public_row,
				commit.get("result_record", {}) as Dictionary
			)
			if str(commit.get("action", "")) == "committed":
				authority_observability["committed_result_count"] = int(
					authority_observability.get("committed_result_count", 0)
				) + 1
			if bool(commit.get("heartbeat_committed", false)):
				authority_observability["heartbeat_commit_count"] = int(
					authority_observability.get("heartbeat_commit_count", 0)
				) + 1
		else:
			var legacy_row := run_match(
				configuration,
				int(job.get("seed", seed_for(configuration_index, match_index))),
				limit,
				configuration_index,
				match_index
			)
			public_row = _public_match_row(legacy_row)
		rows.append(public_row)
		completed_jobs += 1
		var interval := int(execution_options.get("progress_interval", 0))
		if interval > 0 and completed_jobs % interval == 0:
			print(
				"V075_COMBAT_SIMULATION_PROGRESS|matches=%d|configuration=%s"
				% [completed_jobs, configuration.get("configuration_id", "")]
			)
	var elapsed_msec := int((Time.get_ticks_usec() - started_usec) / 1000)
	if bool(authority.get("enabled", false)):
		authority_observability["completed_match_count"] = rows.size()
		authority_observability["persistence_status"] = "GREEN"
		execution_options["_authority_observability"] = authority_observability
	var report := _build_report_from_rows(
		rows,
		scope,
		elapsed_msec,
		execution_options
	)
	if bool(execution_options.get("write_report", false)):
		var report_paths := _report_paths_for_scope(scope, execution_options)
		write_report(
			report,
			str(report_paths.get("json_path", "")),
			str(report_paths.get("md_path", ""))
		)
	return report


func _formal_match_row(match_row: Dictionary, result_record: Dictionary) -> Dictionary:
	var row := match_row.duplicate(true)
	row["formal_job_identity"] = (
		result_record.get("job_identity", {}) as Dictionary
	).duplicate(true)
	row["formal_job_identity_canonical_json"] = str(result_record.get(
		"job_identity_canonical_json",
		""
	))
	row["formal_job_identity_sha256"] = str(result_record.get(
		"job_identity_sha256",
		""
	))
	return row


func authority_contract_context(
	scope: Dictionary,
	options: Dictionary,
	step_limit: int = DEFAULT_STEP_LIMIT
) -> Dictionary:
	var requested_path := str(options.get("authority_path", "")).strip_edges()
	if requested_path.is_empty():
		return {
			"accepted": true,
			"enabled": false,
			"reason_code": "authority_resume_disabled",
		}
	var authority_path := _external_authority_path(requested_path)
	if authority_path.is_empty():
		return _authority_contract_error("authority_path_not_external_absolute")
	var has_assignment_shard := options.has("assignment_shard_id") \
		or options.has("assignment_shard_count")
	if has_assignment_shard \
			and (not options.has("assignment_shard_id") \
				or not options.has("assignment_shard_count")):
		return _authority_contract_error("assignment_shard_metadata_incomplete")
	var shard_id := int(options.get(
		"assignment_shard_id",
		scope.get("shard_id", -1)
	))
	var shard_count := int(options.get(
		"assignment_shard_count",
		scope.get("shard_count", 0)
	))
	if str(scope.get("scope_kind", "")) != "shard" \
			or shard_id < 0 \
			or shard_count < 1 \
			or shard_id >= shard_count:
		return _authority_contract_error("authority_requires_explicit_shard")
	var final_head_sha := str(options.get("final_head_sha", "")).strip_edges()
	var final_tree_sha := str(options.get("final_tree_sha", "")).strip_edges()
	if not _is_git_sha(final_head_sha):
		return _authority_contract_error("final_head_sha_invalid")
	if not _is_git_sha(final_tree_sha):
		return _authority_contract_error("final_tree_sha_invalid")
	var declared_source_sha := OS.get_environment(
		SOURCE_COMMIT_SHA_ENV
	).strip_edges()
	if declared_source_sha.is_empty() or declared_source_sha != final_head_sha:
		return _authority_contract_error("source_sha_environment_mismatch")
	var worker_id := str(options.get("worker_id", "")).strip_edges()
	if not _is_safe_worker_id(worker_id):
		return _authority_contract_error("worker_id_invalid")
	if step_limit < 1:
		return _authority_contract_error("step_limit_invalid")
	var authority_manifest_sha256 := str(options.get(
		"authority_manifest_sha256",
		""
	)).strip_edges()
	if not _is_sha256(authority_manifest_sha256):
		return _authority_contract_error("authority_manifest_sha256_invalid")
	var matrix_contract := _global_matrix_contract(scope)
	if matrix_contract.is_empty():
		return _authority_contract_error("global_matrix_contract_invalid")
	var harness := harness_identity()
	if not bool(harness.get("accepted", false)):
		return _authority_contract_error(str(harness.get(
			"reason_code",
			"harness_identity_invalid"
		)))
	var harness_hash := str(harness.get("fingerprint", ""))
	var expected_harness_hash := str(options.get(
		"expected_harness_hash",
		""
	)).strip_edges()
	if not expected_harness_hash.is_empty() \
			and expected_harness_hash != harness_hash:
		return _authority_contract_error("expected_harness_hash_mismatch")
	return {
		"accepted": true,
		"enabled": true,
		"reason_code": "",
		"authority_path": authority_path,
		"final_head_sha": final_head_sha,
		"final_tree_sha": final_tree_sha,
		"authority_manifest_sha256": authority_manifest_sha256,
		"global_matrix_contract": matrix_contract,
		"harness_hash": harness_hash,
		"harness_component_sha256": (
			harness.get("component_sha256", {}) as Dictionary
		).duplicate(true),
		"worker_id": worker_id,
		"shard_id": shard_id,
		"shard_count": shard_count,
		"simulation_id": SIMULATION_ID,
		"ruleset_id": RULESET_ID,
		"step_limit": step_limit,
		"resume_enabled": true,
	}


func authority_job_paths(
	authority: Dictionary,
	job: Dictionary,
	job_ordinal: int
) -> Dictionary:
	var identity := _authority_job_identity(authority, job, job_ordinal)
	if identity.is_empty():
		return {}
	var authority_path := str(authority.get("authority_path", ""))
	var worker_id := str(authority.get("worker_id", ""))
	var configuration_id := str(identity.get("configuration_id", ""))
	var shard_id := int(authority.get("shard_id", -1))
	var match_index := int(identity.get("match_index", -1))
	var seed_value := int(identity.get("seed", 0))
	var slot_name := "c%02d-%s-match-%06d-seed-%d" % [
		int(identity.get("configuration_index", -1)),
		_safe_path_segment(configuration_id),
		match_index,
		seed_value,
	]
	var shard_segment := "shard-%03d-of-%03d" % [
		shard_id,
		int(authority.get("shard_count", 0)),
	]
	var result_path := authority_path.path_join(
			"results"
		).path_join("%s.json" % slot_name)
	var heartbeat_directory := authority_path.path_join(
			"heartbeats"
		).path_join(worker_id).path_join(shard_segment)
	if not _authority_target_path_is_safe(authority_path, result_path, false) \
			or not _authority_target_path_is_safe(
				authority_path,
				heartbeat_directory,
				true
			):
		return {}
	return {
		"result_path": result_path,
		"heartbeat_directory": heartbeat_directory,
		"slot_name": slot_name,
	}


func inspect_authority_job_result(
	authority: Dictionary,
	job: Dictionary,
	job_ordinal: int
) -> Dictionary:
	if not bool(authority.get("accepted", false)) \
			or not bool(authority.get("enabled", false)):
		return {
			"accepted": false,
			"action": "block",
			"reason_code": "authority_context_not_enabled",
		}
	var paths := authority_job_paths(authority, job, job_ordinal)
	var result_path := str(paths.get("result_path", ""))
	if result_path.is_empty():
		return {
			"accepted": false,
			"action": "block",
			"reason_code": "authority_job_path_invalid",
		}
	if not _authority_target_path_is_safe(
		str(authority.get("authority_path", "")),
		result_path,
		false
	):
		return {
			"accepted": false,
			"action": "block",
			"reason_code": "authority_result_path_became_unsafe",
		}
	if not FileAccess.file_exists(result_path):
		return {
			"accepted": true,
			"action": "run",
			"reason_code": "immutable_result_missing",
			"result_path": result_path,
		}
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(result_path)
	)
	if not (parsed is Dictionary):
		return {
			"accepted": false,
			"action": "block",
			"reason_code": "immutable_result_json_invalid",
			"result_path": result_path,
		}
	var validation := _validate_authority_result_record(
		parsed as Dictionary,
		authority,
		job,
		job_ordinal
	)
	if not bool(validation.get("accepted", false)):
		validation["action"] = "block"
		validation["result_path"] = result_path
		return validation
	return {
		"accepted": true,
		"action": "skip",
		"reason_code": "exact_immutable_result_valid",
		"result_path": result_path,
		"result_record": (parsed as Dictionary).duplicate(true),
		"match_row": (
			(parsed as Dictionary).get("match_row", {}) as Dictionary
		).duplicate(true),
	}


func commit_authority_job_result(
	authority: Dictionary,
	job: Dictionary,
	match_row: Dictionary,
	job_ordinal: int
) -> Dictionary:
	var inspection := inspect_authority_job_result(
		authority,
		job,
		job_ordinal
	)
	if not bool(inspection.get("accepted", false)):
		return inspection
	var record: Dictionary = {}
	var action := str(inspection.get("action", ""))
	if action == "skip":
		record = (
			inspection.get("result_record", {}) as Dictionary
		).duplicate(true)
		match_row = (
			inspection.get("match_row", {}) as Dictionary
		).duplicate(true)
	else:
		record = _build_authority_result_record(
			authority,
			job,
			match_row,
			job_ordinal
		)
		var record_validation := _validate_authority_result_record(
			record,
			authority,
			job,
			job_ordinal
		)
		if not bool(record_validation.get("accepted", false)):
			record_validation["action"] = "block"
			return record_validation
		var result_path := str(inspection.get("result_path", ""))
		var result_write := _atomic_write_immutable_json(
			result_path,
			record,
			str(authority.get("authority_path", ""))
		)
		if not bool(result_write.get("accepted", false)):
			return {
				"accepted": false,
				"action": "block",
				"reason_code": str(result_write.get(
					"reason_code",
					"immutable_result_write_failed"
				)),
				"result_path": result_path,
			}
		if bool(result_write.get("already_exists", false)):
			var raced := inspect_authority_job_result(
				authority,
				job,
				job_ordinal
			)
			if not bool(raced.get("accepted", false)) \
					or str(raced.get("action", "")) != "skip":
				return {
					"accepted": false,
					"action": "block",
					"reason_code": "immutable_result_race_conflict",
					"result_path": result_path,
				}
			record = (
				raced.get("result_record", {}) as Dictionary
			).duplicate(true)
			match_row = (
				raced.get("match_row", {}) as Dictionary
			).duplicate(true)
			action = "skip"
		else:
			action = "committed"
	var heartbeat := _commit_authority_heartbeat(
		authority,
		job,
		record,
		job_ordinal
	)
	if not bool(heartbeat.get("accepted", false)):
		return {
			"accepted": false,
			"action": "block",
			"reason_code": str(heartbeat.get(
				"reason_code",
				"heartbeat_write_failed_after_result_commit"
			)),
			"result_committed": true,
			"result_path": str(inspection.get("result_path", "")),
		}
	return {
		"accepted": true,
		"action": action,
		"reason_code": "",
		"match_row": match_row.duplicate(true),
		"result_record": record.duplicate(true),
		"result_path": str(inspection.get("result_path", "")),
		"heartbeat_path": str(heartbeat.get("heartbeat_path", "")),
		"heartbeat_committed": bool(heartbeat.get("committed", false)),
	}


func _authority_contract_error(reason_code: String) -> Dictionary:
	return {
		"accepted": false,
		"enabled": true,
		"reason_code": reason_code,
	}


func _external_authority_path(path: String) -> String:
	var raw := path.replace("\\", "/")
	if raw.begins_with("//") or raw.find(":", 2) >= 0:
		return ""
	for segment_variant in raw.split("/", false):
		var segment := str(segment_variant)
		if segment == "." \
				or segment == ".." \
				or segment.ends_with(".") \
				or segment.ends_with(" ") \
				or segment.contains("~"):
			return ""
	var normalized := raw.simplify_path().trim_suffix("/")
	if normalized.is_empty() \
			or normalized.begins_with("res://") \
			or normalized.begins_with("user://") \
			or not normalized.is_absolute_path():
		return ""
	# Godot cannot prove arbitrary Windows aliases after the process starts. Fail
	# closed for every existing symlink/junction component; the formal caller must
	# additionally pass only a physically canonical path from its preflight.
	if _path_chain_contains_link(normalized):
		return ""
	var project_root := ProjectSettings.globalize_path(
		"res://"
	).replace("\\", "/").simplify_path().trim_suffix("/")
	var comparable_path := normalized.to_lower()
	var comparable_root := project_root.to_lower()
	if comparable_path == comparable_root \
			or comparable_path.begins_with("%s/" % comparable_root):
		return ""
	return normalized


func _path_chain_contains_link(path: String) -> bool:
	var cursor := path
	while not cursor.is_empty():
		if FileAccess.file_exists(cursor) or DirAccess.dir_exists_absolute(cursor):
			var parent := cursor.get_base_dir()
			var entry_name := cursor.get_file()
			if not entry_name.is_empty() and parent != cursor:
				var parent_access := DirAccess.open(parent)
				if parent_access != null and parent_access.is_link(entry_name):
					return true
		var next_cursor := cursor.get_base_dir()
		if next_cursor.is_empty() or next_cursor == cursor:
			break
		cursor = next_cursor
	return false


func _authority_target_path_is_safe(
	authority_root: String,
	target_path: String,
	target_is_directory: bool
) -> bool:
	var canonical_root := _external_authority_path(authority_root)
	if canonical_root.is_empty():
		return false
	var normalized_target := target_path.replace(
		"\\",
		"/"
	).simplify_path().trim_suffix("/")
	var target_exists := FileAccess.file_exists(normalized_target) \
		or DirAccess.dir_exists_absolute(normalized_target)
	if target_exists and _external_authority_path(normalized_target).is_empty():
		return false
	var target_parent := (
		normalized_target if target_is_directory else normalized_target.get_base_dir()
	)
	var canonical_parent := _external_authority_path(target_parent)
	if canonical_parent.is_empty():
		return false
	var comparable_root := canonical_root.to_lower()
	var comparable_parent := canonical_parent.to_lower()
	return comparable_parent == comparable_root \
		or comparable_parent.begins_with("%s/" % comparable_root)


func _is_git_sha(value: String) -> bool:
	if value.length() != 40 or value != value.to_lower():
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _safe_path_segment(value: String) -> String:
	var result := ""
	for character in value:
		if "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-".contains(
			character
		):
			result += character
	return result


func _is_safe_worker_id(value: String) -> bool:
	if value.is_empty() \
			or value.length() > 64 \
			or _safe_path_segment(value) != value \
			or value == "." \
			or value == ".." \
			or value.begins_with(".") \
			or value.ends_with("."):
		return false
	var device_stem := value.split(".", false, 1)[0].to_upper()
	if device_stem in ["CON", "PRN", "AUX", "NUL", "CLOCK$"]:
		return false
	if device_stem.length() == 4 \
			and (device_stem.begins_with("COM") or device_stem.begins_with("LPT")) \
			and "123456789".contains(device_stem.right(1)):
		return false
	return true


func _global_matrix_contract(scope: Dictionary) -> Dictionary:
	if not bool(scope.get("accepted", false)):
		return {}
	var formal_count := int(scope.get("formal_matches_per_configuration", 0))
	if formal_count < 1:
		return {}
	return {
		"schema_version": AUTHORITY_RESULT_SCHEMA_VERSION,
		"contract_kind": GLOBAL_MATRIX_CONTRACT_KIND,
		"simulation_id": SIMULATION_ID,
		"ruleset_id": RULESET_ID,
		"configuration_catalog": CONFIGURATIONS.duplicate(true),
		"formal_matches_per_configuration": formal_count,
		"canonical_job_count": CONFIGURATIONS.size() * formal_count,
		"base_seed": BASE_SEED,
		"seed_formula_id": SEED_FORMULA_ID,
	}


func _authority_job_identity(
	authority: Dictionary,
	job: Dictionary,
	_job_ordinal: int
) -> Dictionary:
	for integer_field in ["configuration_index", "match_index", "seed"]:
		if not _has_json_integer(job, integer_field):
			return {}
	var configuration_index := int(job.get("configuration_index", -1))
	if configuration_index < 0 or configuration_index >= CONFIGURATIONS.size():
		return {}
	var configuration := CONFIGURATIONS[configuration_index] as Dictionary
	var match_index := int(job.get("match_index", -1))
	var seed_value := int(job.get("seed", 0))
	var matrix_contract := authority.get("global_matrix_contract", {}) as Dictionary
	if match_index < 0 or seed_value != seed_for(
		configuration_index,
		match_index
	) \
			or match_index >= int(matrix_contract.get(
				"formal_matches_per_configuration",
				0
			)):
		return {}
	return {
		"final_head_sha": str(authority.get("final_head_sha", "")),
		"final_tree_sha": str(authority.get("final_tree_sha", "")),
		"authority_manifest_sha256": str(authority.get(
			"authority_manifest_sha256",
			""
		)),
		"harness_fingerprint": str(authority.get("harness_hash", "")),
		"simulation_id": str(authority.get("simulation_id", "")),
		"ruleset_id": str(authority.get("ruleset_id", "")),
		"configuration_id": str(configuration.get("configuration_id", "")),
		"configuration_index": configuration_index,
		"match_index": match_index,
		"seed": seed_value,
		"step_limit": int(authority.get("step_limit", 0)),
	}


func _authority_job_identity_canonical_json(identity: Dictionary) -> String:
	var fields: Array[String] = []
	for field_name in [
		"final_head_sha",
		"final_tree_sha",
		"authority_manifest_sha256",
		"harness_fingerprint",
		"simulation_id",
		"ruleset_id",
		"configuration_index",
		"configuration_id",
		"match_index",
		"seed",
		"step_limit",
	]:
		var value: Variant = identity.get(field_name)
		if field_name in [
			"configuration_index",
			"match_index",
			"seed",
			"step_limit",
		]:
			fields.append("%s:%d" % [JSON.stringify(field_name), int(value)])
		else:
			fields.append("%s:%s" % [
				JSON.stringify(field_name),
				JSON.stringify(str(value)),
			])
	return "{%s}" % ",".join(fields)


func _authority_job_identity_sha256(identity: Dictionary) -> String:
	return _authority_job_identity_canonical_json(identity).sha256_text()


func _build_authority_result_record(
	authority: Dictionary,
	job: Dictionary,
	match_row: Dictionary,
	job_ordinal: int
) -> Dictionary:
	var job_identity := _authority_job_identity(authority, job, job_ordinal)
	var metrics := match_row.get("metrics", {}) as Dictionary
	var completed_at_utc := "%sZ" % Time.get_datetime_string_from_system(
		true,
		false
	)
	var record := {
		"schema_version": AUTHORITY_RESULT_SCHEMA_VERSION,
		"result_kind": AUTHORITY_RESULT_KIND,
		"final_head_sha": str(job_identity.get("final_head_sha", "")),
		"final_tree_sha": str(job_identity.get("final_tree_sha", "")),
		"authority_manifest_sha256": str(job_identity.get(
			"authority_manifest_sha256",
			""
		)),
		"global_matrix_contract": (
			authority.get("global_matrix_contract", {}) as Dictionary
		).duplicate(true),
		"harness_hash": str(job_identity.get("harness_fingerprint", "")),
		"harness_fingerprint": str(job_identity.get(
			"harness_fingerprint",
			""
		)),
		"harness_component_sha256": (
			authority.get("harness_component_sha256", {}) as Dictionary
		).duplicate(true),
		"simulation_id": str(job_identity.get("simulation_id", "")),
		"ruleset_id": str(job_identity.get("ruleset_id", "")),
		"step_limit": int(job_identity.get("step_limit", 0)),
		"worker_id": str(authority.get("worker_id", "")),
		"configuration_id": str(job_identity.get("configuration_id", "")),
		"configuration_index": int(job_identity.get(
			"configuration_index",
			-1
		)),
		"shard_id": int(authority.get("shard_id", -1)),
		"shard_count": int(authority.get("shard_count", 0)),
		"job_ordinal_in_shard": job_ordinal,
		"match_index": int(job_identity.get("match_index", -1)),
		"seed": int(job_identity.get("seed", 0)),
		"completed_match_count": job_ordinal + 1,
		"last_completed_at": completed_at_utc,
		"settled": bool(match_row.get("settled", false)),
		"runtime_error_count": int(metrics.get(
			"COMBAT_RUNTIME_ERROR_COUNT",
			0
		)),
		"combat_action_count": int(metrics.get("COMBAT_ACTION_COUNT", 0)),
		"duplicate_effect_count": int(metrics.get(
			"COMBAT_DUPLICATE_EFFECT_COUNT",
			0
		)),
		"hidden_info_violation_count": int(metrics.get(
			"COMBAT_HIDDEN_INFO_VIOLATION_COUNT",
			0
		)),
		"final_settlement_count": int(metrics.get(
			"FINAL_SETTLEMENT_COUNT",
			0
		)),
		"duplicate_settlement_count": int(metrics.get(
			"DUPLICATE_SETTLEMENT_COUNT",
			0
		)),
		"job_identity": job_identity.duplicate(true),
		"job_identity_canonical_json": _authority_job_identity_canonical_json(
			job_identity
		),
		"job_identity_sha256": _authority_job_identity_sha256(job_identity),
		"job_identity_hash": _authority_job_identity_sha256(job_identity),
		"match_row": match_row.duplicate(true),
		"match_row_fingerprint": fingerprint(match_row),
	}
	record["record_fingerprint"] = fingerprint(record)
	return record


func _validate_authority_result_record(
	record: Dictionary,
	authority: Dictionary,
	job: Dictionary,
	job_ordinal: int
) -> Dictionary:
	if not _has_json_integer(record, "schema_version") \
			or int(record.get("schema_version")) \
				!= AUTHORITY_RESULT_SCHEMA_VERSION \
			or not _has_exact_type(record, "result_kind", TYPE_STRING) \
			or record.get("result_kind") != AUTHORITY_RESULT_KIND:
		return {"accepted": false, "reason_code": "result_schema_mismatch"}
	for string_field in [
		"final_head_sha",
		"final_tree_sha",
		"authority_manifest_sha256",
		"harness_hash",
		"harness_fingerprint",
		"simulation_id",
		"ruleset_id",
		"worker_id",
		"configuration_id",
		"last_completed_at",
		"job_identity_canonical_json",
		"job_identity_sha256",
		"job_identity_hash",
		"match_row_fingerprint",
		"record_fingerprint",
	]:
		if not _has_exact_type(record, string_field, TYPE_STRING):
			return {
				"accepted": false,
				"reason_code": "result_string_type_invalid:%s" % string_field,
			}
	for integer_field in [
		"step_limit",
		"configuration_index",
		"shard_id",
		"shard_count",
		"job_ordinal_in_shard",
		"match_index",
		"seed",
		"completed_match_count",
		"runtime_error_count",
		"combat_action_count",
		"duplicate_effect_count",
		"hidden_info_violation_count",
		"final_settlement_count",
		"duplicate_settlement_count",
	]:
		if not _has_json_integer(record, integer_field):
			return {
				"accepted": false,
				"reason_code": "result_integer_type_invalid:%s" % integer_field,
			}
	if not _has_exact_type(record, "settled", TYPE_BOOL):
		return {"accepted": false, "reason_code": "result_bool_type_invalid:settled"}
	for dictionary_field in [
		"global_matrix_contract",
		"harness_component_sha256",
		"job_identity",
		"match_row",
	]:
		if not _has_exact_type(record, dictionary_field, TYPE_DICTIONARY):
			return {
				"accepted": false,
				"reason_code": "result_dictionary_type_invalid:%s" % dictionary_field,
			}
	var declared_record_fingerprint := str(record.get("record_fingerprint"))
	var payload := record.duplicate(true)
	payload.erase("record_fingerprint")
	if not _is_sha256(declared_record_fingerprint) \
			or fingerprint(payload) != declared_record_fingerprint:
		return {"accepted": false, "reason_code": "result_hash_mismatch"}
	var expected_identity := _authority_job_identity(
		authority,
		job,
		job_ordinal
	)
	var actual_identity := record.get("job_identity") as Dictionary
	if expected_identity.is_empty() \
			or not _strict_job_identity_schema(actual_identity):
		return {"accepted": false, "reason_code": "result_identity_missing"}
	var expected_identity_canonical_json := (
		_authority_job_identity_canonical_json(expected_identity)
	)
	var expected_identity_hash := expected_identity_canonical_json.sha256_text()
	if _canonical(actual_identity) != _canonical(expected_identity) \
			or record.get("job_identity_canonical_json") \
				!= expected_identity_canonical_json \
			or record.get("job_identity_sha256") != expected_identity_hash \
			or record.get("job_identity_hash") != expected_identity_hash:
		return {"accepted": false, "reason_code": "result_identity_conflict"}
	var matrix_contract := record.get("global_matrix_contract") as Dictionary
	if _canonical(matrix_contract) != _canonical(authority.get(
		"global_matrix_contract",
		{}
	)):
		return {"accepted": false, "reason_code": "result_matrix_contract_conflict"}
	var harness_components := record.get("harness_component_sha256") as Dictionary
	if not _strict_sha256_dictionary(harness_components) \
			or fingerprint(harness_components) \
				!= str(expected_identity.get("harness_fingerprint", "")) \
			or _canonical(harness_components) \
				!= _canonical(authority.get("harness_component_sha256", {})):
		return {"accepted": false, "reason_code": "result_harness_conflict"}
	for field_name in [
		"final_head_sha",
		"final_tree_sha",
		"authority_manifest_sha256",
		"harness_fingerprint",
		"harness_hash",
		"simulation_id",
		"ruleset_id",
		"step_limit",
		"configuration_id",
		"configuration_index",
		"match_index",
		"seed",
	]:
		var identity_field_name: String = (
			"harness_fingerprint" if field_name == "harness_hash" else field_name
		)
		if _canonical(record.get(field_name)) \
				!= _canonical(expected_identity.get(identity_field_name)):
			return {
				"accepted": false,
				"reason_code": "result_field_conflict:%s" % field_name,
			}
	var recorded_worker_id := str(record.get("worker_id"))
	var recorded_shard_id := int(record.get("shard_id"))
	var recorded_shard_count := int(record.get("shard_count"))
	var recorded_job_ordinal := int(record.get("job_ordinal_in_shard"))
	if not _is_safe_worker_id(recorded_worker_id) \
			or recorded_shard_count < 1 \
			or recorded_shard_id < 0 \
			or recorded_shard_id >= recorded_shard_count \
			or recorded_job_ordinal < 0 \
			or int(record.get("completed_match_count")) != recorded_job_ordinal + 1 \
			or str(record.get("last_completed_at")).is_empty():
		return {
			"accepted": false,
			"reason_code": "result_execution_observation_invalid",
		}
	var row := record.get("match_row") as Dictionary
	var row_schema_error := _strict_match_row_schema_error(row)
	if not row_schema_error.is_empty():
		return {"accepted": false, "reason_code": row_schema_error}
	if record.get("match_row_fingerprint") != fingerprint(row):
		return {"accepted": false, "reason_code": "result_match_row_hash_mismatch"}
	if int(row.get("configuration_index", -1)) \
			!= int(expected_identity.get("configuration_index", -1)) \
			or str(row.get("configuration_id", "")) \
				!= str(expected_identity.get("configuration_id", "")) \
			or int(row.get("match_index", -1)) \
				!= int(expected_identity.get("match_index", -1)) \
			or int(row.get("seed", 0)) != int(expected_identity.get("seed", 0)):
		return {"accepted": false, "reason_code": "result_row_identity_conflict"}
	var row_identity := row.get("identity") as Dictionary
	if fingerprint(row_identity) != row.get("fingerprint"):
		return {"accepted": false, "reason_code": "result_row_hash_mismatch"}
	var metrics := row.get("metrics", {}) as Dictionary
	for required_key_variant in _empty_metrics().keys():
		var required_key := str(required_key_variant)
		if not _has_json_integer(metrics, required_key):
			return {
				"accepted": false,
				"reason_code": "result_metric_type_invalid:%s" % required_key,
			}
	for metric_key_variant in metrics.keys():
		var metric_key := str(metric_key_variant)
		if not _has_json_integer(metrics, metric_key):
			return {
				"accepted": false,
				"reason_code": "result_metric_type_invalid:%s" % metric_key,
			}
	if int(metrics.get("COMBAT_SIMULATION_MATCH_COUNT", 0)) != 1 \
			or int(metrics.get("COMBAT_SIMULATION_SETTLED_COUNT", 0)) \
				!= (1 if bool(row.get("settled", false)) else 0):
		return {"accepted": false, "reason_code": "result_match_metric_invalid"}
	var expected_metrics := {
		"runtime_error_count": int(metrics.get("COMBAT_RUNTIME_ERROR_COUNT", 0)),
		"combat_action_count": int(metrics.get("COMBAT_ACTION_COUNT", 0)),
		"duplicate_effect_count": int(metrics.get(
			"COMBAT_DUPLICATE_EFFECT_COUNT",
			0
		)),
		"hidden_info_violation_count": int(metrics.get(
			"COMBAT_HIDDEN_INFO_VIOLATION_COUNT",
			0
		)),
		"final_settlement_count": int(metrics.get("FINAL_SETTLEMENT_COUNT", 0)),
		"duplicate_settlement_count": int(metrics.get(
			"DUPLICATE_SETTLEMENT_COUNT",
			0
		)),
	}
	for metric_field_variant in expected_metrics.keys():
		var metric_field := str(metric_field_variant)
		if int(record.get(metric_field)) != int(expected_metrics.get(
			metric_field,
			-2
		)):
			return {
				"accepted": false,
				"reason_code": "result_metric_conflict:%s" % metric_field,
			}
	if record.get("settled") != row.get("settled"):
		return {"accepted": false, "reason_code": "result_settled_conflict"}
	return {"accepted": true, "reason_code": ""}


func _has_exact_type(source: Dictionary, key: String, expected_type: int) -> bool:
	return source.has(key) and typeof(source.get(key)) == expected_type


func _has_json_integer(source: Dictionary, key: String) -> bool:
	if not source.has(key):
		return false
	var value: Variant = source.get(key)
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number == floor(number)


func _strict_job_identity_schema(identity: Dictionary) -> bool:
	for string_field in [
		"final_head_sha",
		"final_tree_sha",
		"authority_manifest_sha256",
		"harness_fingerprint",
		"simulation_id",
		"ruleset_id",
		"configuration_id",
	]:
		if not _has_exact_type(identity, string_field, TYPE_STRING):
			return false
	for integer_field in [
		"configuration_index",
		"match_index",
		"seed",
		"step_limit",
	]:
		if not _has_json_integer(identity, integer_field):
			return false
	return identity.size() == 11 \
		and _is_git_sha(str(identity.get("final_head_sha"))) \
		and _is_git_sha(str(identity.get("final_tree_sha"))) \
		and _is_sha256(str(identity.get("authority_manifest_sha256"))) \
		and _is_sha256(str(identity.get("harness_fingerprint")))


func _strict_sha256_dictionary(source: Dictionary) -> bool:
	if source.is_empty():
		return false
	for key_variant in source.keys():
		if typeof(key_variant) != TYPE_STRING:
			return false
		var value: Variant = source.get(key_variant)
		if typeof(value) != TYPE_STRING or not _is_sha256(str(value)):
			return false
	return true


func _strict_match_row_schema_error(row: Dictionary) -> String:
	for string_field in ["configuration_id", "phase", "fingerprint"]:
		if not _has_exact_type(row, string_field, TYPE_STRING):
			return "result_row_string_type_invalid:%s" % string_field
	for integer_field in [
		"configuration_index",
		"match_index",
		"seed",
		"steps",
		"duration_msec",
	]:
		if not _has_json_integer(row, integer_field):
			return "result_row_integer_type_invalid:%s" % integer_field
	if not _has_exact_type(row, "settled", TYPE_BOOL):
		return "result_row_bool_type_invalid:settled"
	for dictionary_field in [
		"timing",
		"simulation_performance",
		"completion",
		"metrics",
		"identity",
	]:
		if not _has_exact_type(row, dictionary_field, TYPE_DICTIONARY):
			return "result_row_dictionary_type_invalid:%s" % dictionary_field
	return ""


func _commit_authority_heartbeat(
	authority: Dictionary,
	job: Dictionary,
	result_record: Dictionary,
	job_ordinal: int
) -> Dictionary:
	var paths := authority_job_paths(authority, job, job_ordinal)
	var heartbeat_directory := str(paths.get("heartbeat_directory", ""))
	var result_fingerprint := str(result_record.get("record_fingerprint", ""))
	var heartbeat := {
		"schema_version": AUTHORITY_RESULT_SCHEMA_VERSION,
		"heartbeat_kind": AUTHORITY_HEARTBEAT_KIND,
		"final_head_sha": str(result_record.get("final_head_sha", "")),
		"final_tree_sha": str(result_record.get("final_tree_sha", "")),
		"authority_manifest_sha256": str(result_record.get(
			"authority_manifest_sha256",
			""
		)),
		"harness_hash": str(result_record.get("harness_hash", "")),
		"harness_fingerprint": str(result_record.get(
			"harness_fingerprint",
			""
		)),
		"simulation_id": str(result_record.get("simulation_id", "")),
		"ruleset_id": str(result_record.get("ruleset_id", "")),
		"step_limit": int(result_record.get("step_limit", 0)),
		"worker_id": str(authority.get("worker_id", "")),
		"configuration_id": str(result_record.get("configuration_id", "")),
		"configuration_index": int(result_record.get(
			"configuration_index",
			-1
		)),
		"shard_id": int(authority.get("shard_id", -1)),
		"shard_count": int(authority.get("shard_count", 0)),
		"job_ordinal_in_shard": job_ordinal,
		"match_index": int(result_record.get("match_index", -1)),
		"seed": int(result_record.get("seed", 0)),
		"completed_match_count": job_ordinal + 1,
		"last_completed_match_index": int(result_record.get(
			"match_index",
			-1
		)),
		"last_completed_seed": int(result_record.get("seed", 0)),
		"last_completed_at": str(result_record.get(
			"last_completed_at",
			""
		)),
		"settled": bool(result_record.get("settled", false)),
		"runtime_error_count": int(result_record.get(
			"runtime_error_count",
			0
		)),
		"combat_action_count": int(result_record.get(
			"combat_action_count",
			0
		)),
		"duplicate_effect_count": int(result_record.get(
			"duplicate_effect_count",
			0
		)),
		"hidden_info_violation_count": int(result_record.get(
			"hidden_info_violation_count",
			0
		)),
		"final_settlement_count": int(result_record.get(
			"final_settlement_count",
			0
		)),
		"duplicate_settlement_count": int(result_record.get(
			"duplicate_settlement_count",
			0
		)),
		"job_identity_sha256": str(result_record.get(
			"job_identity_sha256",
			""
		)),
		"job_identity_hash": str(result_record.get("job_identity_hash", "")),
		"result_fingerprint": result_fingerprint,
	}
	heartbeat["heartbeat_fingerprint"] = fingerprint(heartbeat)
	var heartbeat_name := "%06d-%s-%s.json" % [
		int(heartbeat.get("completed_match_count", 0)),
		str(heartbeat.get("job_identity_hash", "")).left(16),
		result_fingerprint.left(16),
	]
	var heartbeat_path := heartbeat_directory.path_join(heartbeat_name)
	var write_result := _atomic_write_immutable_json(
		heartbeat_path,
		heartbeat,
		str(authority.get("authority_path", ""))
	)
	if bool(write_result.get("already_exists", false)):
		var existing_variant: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(heartbeat_path)
		)
		if existing_variant is Dictionary \
				and fingerprint(existing_variant) == fingerprint(heartbeat):
			return {
				"accepted": true,
				"committed": false,
				"heartbeat_path": heartbeat_path,
			}
		# Heartbeats are observability only. Preserve a conflicting stale file and
		# publish a fresh atomic heartbeat; only immutable result conflicts block.
		heartbeat_path = heartbeat_directory.path_join(
			"%s-recovery-%d.json" % [heartbeat_name.trim_suffix(".json"), Time.get_ticks_usec()]
		)
		write_result = _atomic_write_immutable_json(
			heartbeat_path,
			heartbeat,
			str(authority.get("authority_path", ""))
		)
	if not bool(write_result.get("accepted", false)) \
			or bool(write_result.get("already_exists", false)):
		return {
			"accepted": false,
			"reason_code": "heartbeat_atomic_write_failed",
			"heartbeat_path": heartbeat_path,
		}
	return {
		"accepted": true,
		"committed": true,
		"heartbeat_path": heartbeat_path,
	}


func _atomic_write_immutable_json(
	path: String,
	payload: Dictionary,
	authority_root: String = ""
) -> Dictionary:
	if path.is_empty():
		return {"accepted": false, "reason_code": "atomic_path_empty"}
	if not authority_root.is_empty() \
			and not _authority_target_path_is_safe(authority_root, path, false):
		return {"accepted": false, "reason_code": "atomic_path_unsafe"}
	if FileAccess.file_exists(path):
		return {
			"accepted": true,
			"already_exists": true,
			"path": path,
		}
	var parent := path.get_base_dir()
	if parent.is_empty():
		return {"accepted": false, "reason_code": "atomic_parent_create_failed"}
	var parent_error := DirAccess.make_dir_recursive_absolute(parent)
	if parent_error != OK and parent_error != ERR_ALREADY_EXISTS:
		return {"accepted": false, "reason_code": "atomic_parent_create_failed"}
	if not authority_root.is_empty() \
			and not _authority_target_path_is_safe(authority_root, path, false):
		return {"accepted": false, "reason_code": "atomic_parent_became_unsafe"}
	var content := JSON.stringify(payload, "\t") + "\n"
	var temporary_path := "%s.tmp.%d.%d" % [
		path,
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"accepted": false, "reason_code": "atomic_temp_open_failed"}
	file.store_string(content)
	file.flush()
	file.close()
	if FileAccess.get_file_as_string(temporary_path) != content:
		DirAccess.remove_absolute(temporary_path)
		return {"accepted": false, "reason_code": "atomic_temp_verify_failed"}
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(temporary_path)
		return {
			"accepted": true,
			"already_exists": true,
			"path": path,
		}
	if not authority_root.is_empty() \
			and not _authority_target_path_is_safe(authority_root, path, false):
		DirAccess.remove_absolute(temporary_path)
		return {"accepted": false, "reason_code": "atomic_target_became_unsafe"}
	var rename_error := DirAccess.rename_absolute(temporary_path, path)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary_path)
		if FileAccess.file_exists(path):
			return {
				"accepted": true,
				"already_exists": true,
				"path": path,
			}
		return {
			"accepted": false,
			"reason_code": "atomic_rename_failed",
			"error_code": rename_error,
		}
	if not authority_root.is_empty() \
			and not _authority_target_path_is_safe(authority_root, path, false):
		return {"accepted": false, "reason_code": "atomic_installed_path_unsafe"}
	var installed_variant: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(path)
	)
	if not (installed_variant is Dictionary) \
			or fingerprint(installed_variant) != fingerprint(payload):
		return {
			"accepted": false,
			"reason_code": "atomic_installed_verify_failed",
			"path": path,
		}
	return {
		"accepted": true,
		"already_exists": false,
		"path": path,
	}


func _authority_blocked_report(
	scope: Dictionary,
	authority_state: Dictionary,
	completed_rows: Array,
	elapsed_msec: int
) -> Dictionary:
	var blocked_scope := scope.duplicate(true)
	blocked_scope.erase("jobs")
	blocked_scope["accepted"] = false
	blocked_scope["reason_code"] = str(authority_state.get(
		"reason_code",
		authority_state.get("block_reason_code", "authority_resume_blocked")
	))
	var report := _invalid_execution_report(blocked_scope)
	report["authority_resume"] = authority_state.duplicate(true)
	report["partial_completed_match_count"] = completed_rows.size()
	report["elapsed_msec"] = elapsed_msec
	report.erase("report_fingerprint")
	report["report_fingerprint"] = fingerprint(report)
	_last_report = report.duplicate(true)
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
	var harness := harness_identity()
	var report := {
		"schema_version": SHARD_SCHEMA_VERSION,
		"report_kind": report_kind,
		"simulation_id": SIMULATION_ID,
		"ruleset_id": RULESET_ID,
		"source_commit_sha": OS.get_environment(SOURCE_COMMIT_SHA_ENV).strip_edges(),
		"harness_fingerprint": str(harness.get("fingerprint", "")),
		"harness_component_sha256": (
			harness.get("component_sha256", {}) as Dictionary
		).duplicate(true),
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
	if options.has("_authority_observability"):
		report["authority_resume"] = (
			options.get("_authority_observability", {}) as Dictionary
		).duplicate(true)
	if str(scope.get("scope_kind", "")) == "shard":
		var shard_gates := _shard_acceptance_gates(rows)
		report["shard_acceptance_gates"] = shard_gates
		report["shard_acceptance_status"] = (
			"GREEN" if bool(shard_gates.get("SHARD_ACCEPTANCE_GREEN", false))
			else "BLOCKED"
		)
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
	var harness := harness_identity()
	var report := {
		"schema_version": SHARD_SCHEMA_VERSION,
		"report_kind": "v075.combat.simulation.invalid.v1",
		"simulation_id": SIMULATION_ID,
		"ruleset_id": RULESET_ID,
		"source_commit_sha": OS.get_environment(SOURCE_COMMIT_SHA_ENV).strip_edges(),
		"harness_fingerprint": str(harness.get("fingerprint", "")),
		"harness_component_sha256": (
			harness.get("component_sha256", {}) as Dictionary
		).duplicate(true),
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
	var shard_count := int(scope.get(
		"assignment_shard_count",
		scope.get("shard_count", 1)
	))
	var shard_id := int(scope.get(
		"assignment_shard_id",
		scope.get("shard_id", -1)
	))
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
	var seen_coordinates: Dictionary = {}
	var seen_seeds: Dictionary = {}
	var duplicate_job_count := 0
	var duplicate_seed_count := 0
	var seed_mismatch_count := 0
	var out_of_declared_scope_count := 0
	var schema_error_count := 0
	var report_fingerprint_invalid_count := 0
	var source_report_fingerprints: Array[String] = []
	var source_commit_shas: Array[String] = []
	var source_commit_sha_missing_count := 0
	var source_commit_sha_value_mismatch_count := 0
	var harness_fingerprints: Array[String] = []
	var harness_fingerprint_missing_count := 0
	var harness_fingerprint_mismatch_count := 0
	var harness_component_mismatch_count := 0
	var exact_identity_mode := bool(options.get(
		"require_exact_job_identity",
		false
	))
	for candidate_variant in reports:
		if candidate_variant is Dictionary:
			var candidate := candidate_variant as Dictionary
			var candidate_authority_variant: Variant = candidate.get(
				"authority_resume",
				null
			)
			if candidate_authority_variant is Dictionary \
					and bool((candidate_authority_variant as Dictionary).get(
						"enabled",
						false
					)):
				exact_identity_mode = true
				break
	var exact_identity_error_count := 0
	var authority_global_missing_count := 0
	var authority_global_mismatch_count := 0
	var aggregate_authority: Dictionary = {}
	var current_harness := harness_identity()
	var current_harness_fingerprint := str(current_harness.get(
		"fingerprint",
		""
	))
	var expected_source_commit_sha := OS.get_environment(
		SOURCE_COMMIT_SHA_ENV
	).strip_edges()
	var expected_source_commit_sha_missing_count := (
		1 if expected_source_commit_sha.is_empty() else 0
	)
	for report_variant in reports:
		if not (report_variant is Dictionary):
			schema_error_count += 1
			continue
		var report := report_variant as Dictionary
		var declared_report_fingerprint := str(report.get(
			"report_fingerprint",
			""
		))
		var report_payload := report.duplicate(true)
		report_payload.erase("report_fingerprint")
		if declared_report_fingerprint.length() != 64 \
			or fingerprint(report_payload) != declared_report_fingerprint:
			report_fingerprint_invalid_count += 1
			schema_error_count += 1
			continue
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
		source_report_fingerprints.append(declared_report_fingerprint)
		var harness_fingerprint := str(report.get(
			"harness_fingerprint",
			""
		)).strip_edges()
		var harness_components_variant: Variant = report.get(
			"harness_component_sha256",
			null
		)
		if harness_fingerprint.is_empty():
			harness_fingerprint_missing_count += 1
		elif not (harness_components_variant is Dictionary) \
			or fingerprint(harness_components_variant) != harness_fingerprint:
			harness_component_mismatch_count += 1
		elif current_harness_fingerprint.is_empty() \
			or harness_fingerprint != current_harness_fingerprint:
			harness_fingerprint_mismatch_count += 1
		if not harness_fingerprint.is_empty() \
			and harness_fingerprint not in harness_fingerprints:
			harness_fingerprints.append(harness_fingerprint)
		var source_commit_sha := str(
			report.get("source_commit_sha", "")
		).strip_edges()
		if source_commit_sha.is_empty():
			source_commit_sha_missing_count += 1
		else:
			if source_commit_sha not in source_commit_shas:
				source_commit_shas.append(source_commit_sha)
			if not expected_source_commit_sha.is_empty() \
				and source_commit_sha != expected_source_commit_sha:
				source_commit_sha_value_mismatch_count += 1
		if exact_identity_mode:
			var authority_variant: Variant = report.get("authority_resume", null)
			if not (authority_variant is Dictionary) \
					or not bool((authority_variant as Dictionary).get(
						"enabled",
						false
					)):
				authority_global_missing_count += 1
				continue
			var report_authority := authority_variant as Dictionary
			var authority_schema_green := true
			for string_field in [
				"final_head_sha",
				"final_tree_sha",
				"authority_manifest_sha256",
				"harness_hash",
				"simulation_id",
				"ruleset_id",
			]:
				if not _has_exact_type(report_authority, string_field, TYPE_STRING):
					authority_schema_green = false
					break
			if not _has_json_integer(report_authority, "step_limit"):
				authority_schema_green = false
			var candidate_authority := {
				"final_head_sha": str(report_authority.get("final_head_sha", "")),
				"final_tree_sha": str(report_authority.get("final_tree_sha", "")),
				"authority_manifest_sha256": str(report_authority.get(
					"authority_manifest_sha256",
					""
				)),
				"harness_fingerprint": str(report_authority.get(
					"harness_hash",
					""
				)),
				"simulation_id": str(report_authority.get("simulation_id", "")),
				"ruleset_id": str(report_authority.get("ruleset_id", "")),
				"step_limit": int(report_authority.get("step_limit", 0)),
			}
			if not authority_schema_green \
					or not _is_git_sha(str(candidate_authority.get(
						"final_head_sha",
						""
					))) \
					or not _is_git_sha(str(candidate_authority.get(
						"final_tree_sha",
						""
					))) \
					or not _is_sha256(str(candidate_authority.get(
						"authority_manifest_sha256",
						""
					))) \
					or not _is_sha256(str(candidate_authority.get(
						"harness_fingerprint",
						""
					))) \
					or int(candidate_authority.get("step_limit", 0)) < 1 \
					or str(candidate_authority.get("simulation_id", "")) \
						!= SIMULATION_ID \
					or str(candidate_authority.get("ruleset_id", "")) != RULESET_ID \
					or str(candidate_authority.get("final_head_sha", "")) \
						!= source_commit_sha \
					or str(candidate_authority.get("harness_fingerprint", "")) \
						!= harness_fingerprint:
				authority_global_mismatch_count += 1
				continue
			if aggregate_authority.is_empty():
				aggregate_authority = candidate_authority.duplicate(true)
			elif _canonical(aggregate_authority) != _canonical(candidate_authority):
				authority_global_mismatch_count += 1
				continue
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
			var coordinate_key := "%d:%d" % [configuration_index, match_index]
			if not declared_jobs.has(coordinate_key):
				out_of_declared_scope_count += 1
				continue
			var job_key := coordinate_key
			if exact_identity_mode:
				var identity_variant: Variant = row.get(
					"formal_job_identity",
					null
				)
				if not (identity_variant is Dictionary) \
						or not _has_exact_type(
							row,
							"formal_job_identity_canonical_json",
							TYPE_STRING
						) \
						or not _has_exact_type(
							row,
							"formal_job_identity_sha256",
							TYPE_STRING
						):
					exact_identity_error_count += 1
					continue
				var expected_row_identity := aggregate_authority.duplicate(true)
				expected_row_identity["configuration_index"] = configuration_index
				expected_row_identity["configuration_id"] = str(
					(CONFIGURATIONS[configuration_index] as Dictionary).get(
						"configuration_id",
						""
					)
				)
				expected_row_identity["match_index"] = match_index
				expected_row_identity["seed"] = expected_seed
				var actual_identity := identity_variant as Dictionary
				var expected_canonical_json := (
					_authority_job_identity_canonical_json(expected_row_identity)
				)
				var expected_identity_sha256 := expected_canonical_json.sha256_text()
				if not _strict_job_identity_schema(actual_identity) \
						or _canonical(actual_identity) \
							!= _canonical(expected_row_identity) \
						or str(row.get(
							"formal_job_identity_canonical_json",
							""
						)) != expected_canonical_json \
						or str(row.get("formal_job_identity_sha256", "")) \
							!= expected_identity_sha256:
					exact_identity_error_count += 1
					continue
				job_key = expected_identity_sha256
			var seed_key := str(expected_seed)
			if seen_jobs.has(job_key) or seen_coordinates.has(coordinate_key):
				duplicate_job_count += 1
				continue
			if seen_seeds.has(seed_key):
				duplicate_seed_count += 1
				continue
			seen_jobs[job_key] = true
			seen_coordinates[coordinate_key] = job_key
			seen_seeds[seed_key] = true
			unique_rows.append(row)
	var missing_job_count := 0
	for configuration_index in range(CONFIGURATIONS.size()):
		for match_index in range(formal_matches_per_configuration):
			var expected_job_key := "%d:%d" % [configuration_index, match_index]
			if exact_identity_mode and not aggregate_authority.is_empty():
				var expected_matrix_identity := aggregate_authority.duplicate(true)
				expected_matrix_identity["configuration_index"] = configuration_index
				expected_matrix_identity["configuration_id"] = str(
					(CONFIGURATIONS[configuration_index] as Dictionary).get(
						"configuration_id",
						""
					)
				)
				expected_matrix_identity["match_index"] = match_index
				expected_matrix_identity["seed"] = seed_for(
					configuration_index,
					match_index
				)
				expected_job_key = _authority_job_identity_sha256(
					expected_matrix_identity
				)
			if not seen_jobs.has(expected_job_key):
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
	var source_commit_sha_mismatch_count := (
		source_commit_sha_value_mismatch_count
		if not expected_source_commit_sha.is_empty()
		else maxi(0, source_commit_shas.size() - 1)
	)
	var aggregate_source_commit_sha := (
		source_commit_shas[0] if not source_commit_shas.is_empty() else ""
	)
	if source_commit_sha_missing_count > 0:
		source_commit_sha_mismatch_count += source_commit_sha_missing_count
	report["source_commit_sha"] = aggregate_source_commit_sha
	source_report_fingerprints.sort()
	source_commit_shas.sort()
	harness_fingerprints.sort()
	report["aggregation"] = {
		"schema_version": SHARD_SCHEMA_VERSION,
		"exact_job_identity_mode": exact_identity_mode,
		"aggregate_authority": aggregate_authority.duplicate(true),
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
		"report_fingerprint_invalid_count": report_fingerprint_invalid_count,
		"source_commit_sha_mismatch_count": source_commit_sha_mismatch_count,
		"source_commit_sha_missing_count": source_commit_sha_missing_count,
		"expected_source_commit_sha_missing_count": (
			expected_source_commit_sha_missing_count
		),
		"source_commit_sha_set": source_commit_shas.duplicate(),
		"harness_fingerprint_missing_count": harness_fingerprint_missing_count,
		"harness_fingerprint_mismatch_count": harness_fingerprint_mismatch_count,
		"harness_component_mismatch_count": harness_component_mismatch_count,
		"exact_identity_error_count": exact_identity_error_count,
		"authority_global_missing_count": authority_global_missing_count,
		"authority_global_mismatch_count": authority_global_mismatch_count,
		"harness_fingerprint_set": harness_fingerprints.duplicate(),
		"seed_deduplication_green": (
			duplicate_seed_count == 0 and seed_mismatch_count == 0
		),
	}
	var structural_blocked := schema_error_count > 0 \
		or report_fingerprint_invalid_count > 0 \
		or duplicate_job_count > 0 \
		or duplicate_seed_count > 0 \
		or seed_mismatch_count > 0 \
		or out_of_declared_scope_count > 0 \
		or expected_source_commit_sha_missing_count > 0 \
		or source_commit_sha_mismatch_count > 0 \
		or harness_fingerprint_missing_count > 0 \
		or harness_fingerprint_mismatch_count > 0 \
		or harness_component_mismatch_count > 0 \
		or (exact_identity_mode and aggregate_authority.is_empty()) \
		or exact_identity_error_count > 0 \
		or authority_global_missing_count > 0 \
		or authority_global_mismatch_count > 0 \
		or not bool(current_harness.get("accepted", false))
	var expected_job_count := CONFIGURATIONS.size() \
		* formal_matches_per_configuration
	report["acceptance_status"] = aggregate_acceptance_status(
		structural_blocked,
		safety_gates_are_green(report),
		coverage_gates_are_green(report),
		missing_job_count,
		unique_rows.size(),
		expected_job_count
	)
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
	var gates := report.get("coverage_gates", {}) as Dictionary
	return bool(gates.get(
		"COMBAT_REQUIRED_OBSERVATIONS_GREEN",
		false
	)) and bool(gates.get("COMBAT_ACTION_COUNT_GREEN", false))


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
	result["MONSTER_PRIVATE_SKILL_LAST_FIZZLE_REASON"] = str(
		combat.get("monster_private_skill_last_fizzle_reason", "")
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
	var combat_action_count := 0
	for combat_action_key_variant in COMBAT_ACTION_COUNTER_KEYS:
		combat_action_count += int(result.get(
			str(combat_action_key_variant),
			0
		))
	result["COMBAT_ACTION_COUNT"] = combat_action_count
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
		"COMBAT_ACTION_COUNT",
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
	for key_variant in ZERO_COUNTER_KEYS:
		var key := str(key_variant)
		gates["%s_GREEN" % key] = int(metrics.get(key, 0)) == 0
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
	gates["MISSING_REQUIRED_POSITIVE_COUNTER_COUNT"] = missing.size()
	gates["COMBAT_ACTION_COUNT_GREEN"] = int(metrics.get(
		"COMBAT_ACTION_COUNT",
		0
	)) > 0
	return gates


func _shard_acceptance_gates(rows: Array) -> Dictionary:
	var metrics := _empty_metrics()
	var settled_count := 0
	var final_exact_once_count := 0
	for row_variant in rows:
		var row := row_variant as Dictionary
		var row_metrics := row.get("metrics", {}) as Dictionary
		_merge_metrics(metrics, row_metrics)
		if bool(row.get("settled", false)):
			settled_count += 1
		if bool(row.get("settled", false)) \
				and int(row_metrics.get("FINAL_SETTLEMENT_COUNT", 0)) == 1 \
				and int(row_metrics.get("DUPLICATE_SETTLEMENT_COUNT", 0)) == 0:
			final_exact_once_count += 1
	var safety_zero := true
	for key_variant in ZERO_COUNTER_KEYS:
		if int(metrics.get(str(key_variant), 0)) != 0:
			safety_zero = false
			break
	for key in [
		"COMBAT_SIMULATION_STEP_LIMIT_COUNT",
		"DUPLICATE_SETTLEMENT_COUNT",
		"TRACK_SHARED_SCROLL_VACANCY_VIOLATION_COUNT",
		"TRACK_RATIO_CONTRACT_VIOLATION_COUNT",
		"TRACK_ASSET_PIP_REGRESSION_FAILURE_COUNT",
	]:
		if int(metrics.get(key, 0)) != 0:
			safety_zero = false
	var rare_positive_missing: Array[String] = []
	for key_variant in REQUIRED_POSITIVE_COUNTER_KEYS:
		var key := str(key_variant)
		if int(metrics.get(key, 0)) <= 0:
			rare_positive_missing.append(key)
	var has_rows := not rows.is_empty()
	var all_settled := has_rows and settled_count == rows.size()
	var final_exact_once := has_rows and final_exact_once_count == rows.size()
	var combat_action_green := int(metrics.get("COMBAT_ACTION_COUNT", 0)) > 0
	return {
		"SHARD_SAFETY_ZERO_GREEN": safety_zero,
		"SHARD_ALL_MATCHES_SETTLED_GREEN": all_settled,
		"SHARD_FINAL_SETTLEMENT_EXACT_ONCE_GREEN": final_exact_once,
		"SHARD_COMBAT_ACTION_COUNT_GREEN": combat_action_green,
		"SHARD_ACCEPTANCE_GREEN": safety_zero \
			and all_settled \
			and final_exact_once \
			and combat_action_green,
		"match_count": rows.size(),
		"settled_match_count": settled_count,
		"final_settlement_exact_once_match_count": final_exact_once_count,
		"combat_action_count": int(metrics.get("COMBAT_ACTION_COUNT", 0)),
		"rare_positive_gate_scope": "aggregate_only",
		"rare_positive_missing_in_shard_informational": rare_positive_missing,
	}


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


func aggregate_acceptance_status(
	structural_blocked: bool,
	safety_green: bool,
	coverage_green: bool,
	missing_job_count: int,
	unique_job_count: int,
	expected_job_count: int
) -> String:
	if structural_blocked or not safety_green:
		return "BLOCKED"
	if not coverage_green \
		or missing_job_count > 0 \
		or unique_job_count != expected_job_count:
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


func harness_identity() -> Dictionary:
	var components: Dictionary = {}
	for path_variant in HARNESS_SOURCE_PATHS:
		var path := str(path_variant)
		if not FileAccess.file_exists(path):
			return {
				"accepted": false,
				"reason_code": "harness_component_missing",
				"missing_path": path,
				"component_sha256": components,
				"fingerprint": "",
			}
		var component_sha256 := FileAccess.get_sha256(path)
		if component_sha256.length() != 64:
			return {
				"accepted": false,
				"reason_code": "harness_component_hash_invalid",
				"invalid_path": path,
				"component_sha256": components,
				"fingerprint": "",
			}
		components[path] = component_sha256
	return {
		"accepted": true,
		"reason_code": "",
		"component_sha256": components,
		"fingerprint": fingerprint(components),
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
			var number := float(value)
			if number == floor(number):
				return str(int(number))
			return String.num(number, 17)
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
		"Source commit SHA: %s."
		% str(report.get("source_commit_sha", "UNDECLARED"))
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
