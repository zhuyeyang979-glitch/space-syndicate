extends SceneTree

const SIMULATOR := preload(
	"res://scripts/v075_simulation/v075_combat_deterministic_simulator.gd"
)
const CONTRACT_HEAD_SHA := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const CONTRACT_TREE_SHA := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const CONFLICT_TREE_SHA := "cccccccccccccccccccccccccccccccccccccccc"
const AUTHORITY_MANIFEST_SHA256 := (
	"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
)
const CONFLICT_AUTHORITY_MANIFEST_SHA256 := (
	"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
)
const CONTRACT_STEP_LIMIT := 17

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous_source_sha := OS.get_environment("V075_SIMULATION_SOURCE_SHA")
	OS.set_environment("V075_SIMULATION_SOURCE_SHA", CONTRACT_HEAD_SHA)
	var authority_root := ProjectSettings.globalize_path(
		"user://v075_simulation_resume_contract_%d" % OS.get_process_id()
	).replace("\\", "/").simplify_path()
	_remove_tree(authority_root)
	var simulator := SIMULATOR.new()
	var scope: Dictionary = simulator.build_shard_manifest(
		3,
		{
			"configuration_index": 0,
			"match_index_start": 0,
			"match_index_end_exclusive": 3,
			"formal_matches_per_configuration": 3,
		}
	)
	_expect(bool(scope.get("accepted", false)), "contract shard manifest is valid")
	var authority: Dictionary = simulator.authority_contract_context(
		scope,
		{
			"authority_path": authority_root,
			"final_head_sha": CONTRACT_HEAD_SHA,
			"final_tree_sha": CONTRACT_TREE_SHA,
			"authority_manifest_sha256": AUTHORITY_MANIFEST_SHA256,
			"worker_id": "contract-worker-0",
			"assignment_shard_id": 2,
			"assignment_shard_count": 7,
		},
		CONTRACT_STEP_LIMIT
	)
	_expect(
		bool(authority.get("accepted", false))
			and bool(authority.get("enabled", false)),
		"external exact-identity authority context is accepted"
	)
	var unsafe_worker_options := {
		"authority_path": authority_root,
		"final_head_sha": CONTRACT_HEAD_SHA,
		"final_tree_sha": CONTRACT_TREE_SHA,
		"authority_manifest_sha256": AUTHORITY_MANIFEST_SHA256,
		"worker_id": "CON",
		"assignment_shard_id": 2,
		"assignment_shard_count": 7,
	}
	_expect(
		not bool((simulator.authority_contract_context(
			scope,
			unsafe_worker_options,
			CONTRACT_STEP_LIMIT
		) as Dictionary).get("accepted", true)),
		"reserved or path-alias worker identifiers fail closed"
	)
	var jobs := scope.get("jobs", []) as Array
	var heartbeat_only_job := jobs[0] as Dictionary
	var completed_job := jobs[2] as Dictionary
	var completed_row := _synthetic_row(simulator, completed_job, 0, 3)
	var first_commit: Dictionary = simulator.commit_authority_job_result(
		authority,
		completed_job,
		completed_row,
		2
	)
	_expect(
		bool(first_commit.get("accepted", false))
			and str(first_commit.get("action", "")) == "committed",
		"first completion commits one immutable result"
	)
	_expect(
		FileAccess.file_exists(str(first_commit.get("result_path", "")))
			and FileAccess.file_exists(str(first_commit.get(
				"heartbeat_path",
				""
			))),
		"result is installed before its result-bound heartbeat is observable"
	)
	var committed_record := first_commit.get("result_record", {}) as Dictionary
	var planner_canonical_json := (
		'{"final_head_sha":"%s","final_tree_sha":"%s",'
		+ '"authority_manifest_sha256":"%s","harness_fingerprint":"%s",'
		+ '"simulation_id":"v075.combat.deterministic.production_path.v1",'
		+ '"ruleset_id":"v0.7.5","configuration_index":0,'
		+ '"configuration_id":"3p_8r_simple","match_index":2,'
		+ '"seed":900642262,"step_limit":17}'
	) % [
		CONTRACT_HEAD_SHA,
		CONTRACT_TREE_SHA,
		AUTHORITY_MANIFEST_SHA256,
		str(committed_record.get("harness_fingerprint", "")),
	]
	_expect(
		str(committed_record.get("job_identity_canonical_json", ""))
			== planner_canonical_json
			and str(committed_record.get("job_identity_sha256", ""))
				== planner_canonical_json.sha256_text(),
		"job identity canonical JSON and SHA align with the PowerShell planner"
	)
	var resumed: Dictionary = simulator.inspect_authority_job_result(
		authority,
		completed_job,
		2
	)
	_expect(
		bool(resumed.get("accepted", false))
			and str(resumed.get("action", "")) == "skip"
			and simulator.fingerprint(
				resumed.get("match_row", {}) as Dictionary
			) == simulator.fingerprint(completed_row),
		"an exact valid immutable result resumes without rerunning the job"
	)
	var reassigned_scope: Dictionary = simulator.build_shard_manifest(
		1,
		{
			"configuration_index": 0,
			"match_index_start": 2,
			"match_index_end_exclusive": 3,
			"formal_matches_per_configuration": 3,
		}
	)
	var reassigned_jobs := reassigned_scope.get("jobs", []) as Array
	var reassigned_job := reassigned_jobs[0] as Dictionary
	var reassigned_options := {
		"authority_path": authority_root,
		"final_head_sha": CONTRACT_HEAD_SHA,
		"final_tree_sha": CONTRACT_TREE_SHA,
		"authority_manifest_sha256": AUTHORITY_MANIFEST_SHA256,
		"worker_id": "contract-worker-1",
		"assignment_shard_id": 5,
		"assignment_shard_count": 7,
	}
	var reassigned_authority: Dictionary = simulator.authority_contract_context(
		reassigned_scope,
		reassigned_options,
		CONTRACT_STEP_LIMIT
	)
	var reassigned: Dictionary = simulator.inspect_authority_job_result(
		reassigned_authority,
		reassigned_job,
		0
	)
	_expect(
		bool(reassigned.get("accepted", false))
			and str(reassigned.get("action", "")) == "skip",
		"worker, shard, range, and ordinal reassignment preserves exact-job resume"
	)
	var reassigned_commit: Dictionary = simulator.commit_authority_job_result(
		reassigned_authority,
		reassigned_job,
		{},
		0
	)
	var reassigned_heartbeat := JSON.parse_string(FileAccess.get_file_as_string(
		str(reassigned_commit.get("heartbeat_path", ""))
	)) as Dictionary
	_expect(
		bool(reassigned_commit.get("accepted", false))
			and str(reassigned_commit.get("action", "")) == "skip"
			and str(reassigned_heartbeat.get("worker_id", ""))
				== "contract-worker-1"
			and int(reassigned_heartbeat.get("shard_id", -1)) == 5
			and int(reassigned_heartbeat.get("job_ordinal_in_shard", -1)) == 0
			and int(reassigned_heartbeat.get("completed_match_count", -1)) == 1,
		"resume heartbeat records the current assignment, not the old result writer"
	)
	var conflicting_authority: Dictionary = simulator.authority_contract_context(
		reassigned_scope,
		{
			"authority_path": authority_root,
			"final_head_sha": CONTRACT_HEAD_SHA,
			"final_tree_sha": CONFLICT_TREE_SHA,
			"authority_manifest_sha256": AUTHORITY_MANIFEST_SHA256,
			"worker_id": "contract-worker-1",
			"assignment_shard_id": 5,
			"assignment_shard_count": 7,
		},
		CONTRACT_STEP_LIMIT
	)
	var conflict: Dictionary = simulator.inspect_authority_job_result(
		conflicting_authority,
		reassigned_job,
		0
	)
	_expect(
		not bool(conflict.get("accepted", true))
			and str(conflict.get("action", "")) == "block"
			and str(conflict.get("reason_code", "")).begins_with(
				"result_"
			),
		"tree, SHA, harness, or job identity conflicts block resume"
	)
	var step_drift_authority: Dictionary = simulator.authority_contract_context(
		reassigned_scope,
		reassigned_options,
		CONTRACT_STEP_LIMIT + 1
	)
	_expect(
		not bool((simulator.inspect_authority_job_result(
			step_drift_authority,
			reassigned_job,
			0
		) as Dictionary).get("accepted", true)),
		"step-limit drift blocks an otherwise identical immutable result"
	)
	var authority_drift_options := reassigned_options.duplicate(true)
	authority_drift_options["authority_manifest_sha256"] = (
		CONFLICT_AUTHORITY_MANIFEST_SHA256
	)
	var authority_drift: Dictionary = simulator.authority_contract_context(
		reassigned_scope,
		authority_drift_options,
		CONTRACT_STEP_LIMIT
	)
	_expect(
		not bool((simulator.inspect_authority_job_result(
			authority_drift,
			reassigned_job,
			0
		) as Dictionary).get("accepted", true)),
		"frozen external authority manifest drift blocks resume"
	)
	var seed_drift_job := reassigned_job.duplicate(true)
	seed_drift_job["seed"] = int(seed_drift_job.get("seed", 0)) + 1
	_expect(
		not bool((simulator.inspect_authority_job_result(
			reassigned_authority,
			seed_drift_job,
			0
		) as Dictionary).get("accepted", true)),
		"seed drift blocks before an immutable result can be reused"
	)
	var valid_record := first_commit.get("result_record", {}) as Dictionary
	var string_number_record := valid_record.duplicate(true)
	string_number_record["completed_match_count"] = "3"
	_refresh_record_fingerprint(simulator, string_number_record)
	_expect(
		not bool((simulator.call(
			"_validate_authority_result_record",
			string_number_record,
			authority,
			completed_job,
			2
		) as Dictionary).get("accepted", true)),
		"string-number coercion cannot validate as an integer result field"
	)
	var string_bool_record := valid_record.duplicate(true)
	var string_bool_row := (
		string_bool_record.get("match_row", {}) as Dictionary
	).duplicate(true)
	string_bool_row["settled"] = "true"
	string_bool_record["match_row"] = string_bool_row
	string_bool_record["match_row_fingerprint"] = simulator.fingerprint(
		string_bool_row
	)
	_refresh_record_fingerprint(simulator, string_bool_record)
	_expect(
		not bool((simulator.call(
			"_validate_authority_result_record",
			string_bool_record,
			authority,
			completed_job,
			2
		) as Dictionary).get("accepted", true)),
		"string-bool coercion cannot validate as a settled result field"
	)
	var formal_row := simulator.call(
		"_formal_match_row",
		completed_row,
		valid_record
	) as Dictionary
	var exact_report := simulator.call(
		"_build_report_from_rows",
		[formal_row],
		scope,
		0,
		{
			"report_kind": "v075.combat.simulation.shard.v1",
			"include_match_rows": true,
			"_authority_observability": authority.duplicate(true),
		}
	) as Dictionary
	var mixed_step_report := exact_report.duplicate(true)
	var mixed_step_authority := (
		mixed_step_report.get("authority_resume", {}) as Dictionary
	).duplicate(true)
	mixed_step_authority["step_limit"] = CONTRACT_STEP_LIMIT + 1
	mixed_step_report["authority_resume"] = mixed_step_authority
	_refresh_report_fingerprint(simulator, mixed_step_report)
	var mixed_authority_report := exact_report.duplicate(true)
	var mixed_authority := (
		mixed_authority_report.get("authority_resume", {}) as Dictionary
	).duplicate(true)
	mixed_authority["authority_manifest_sha256"] = (
		CONFLICT_AUTHORITY_MANIFEST_SHA256
	)
	mixed_authority_report["authority_resume"] = mixed_authority
	_refresh_report_fingerprint(simulator, mixed_authority_report)
	var mixed_tree_report := exact_report.duplicate(true)
	var mixed_tree_authority := (
		mixed_tree_report.get("authority_resume", {}) as Dictionary
	).duplicate(true)
	mixed_tree_authority["final_tree_sha"] = CONFLICT_TREE_SHA
	mixed_tree_report["authority_resume"] = mixed_tree_authority
	_refresh_report_fingerprint(simulator, mixed_tree_report)
	var mixed_aggregate := simulator.aggregate_reports(
		[
			exact_report,
			mixed_step_report,
			mixed_authority_report,
			mixed_tree_report,
		],
		{
			"formal_matches_per_configuration": 3,
			"require_exact_job_identity": true,
		}
	) as Dictionary
	var mixed_aggregation := mixed_aggregate.get("aggregation", {}) as Dictionary
	_expect(
		str(mixed_aggregate.get("acceptance_status", "")) == "BLOCKED"
			and bool(mixed_aggregation.get("exact_job_identity_mode", false))
			and int(mixed_aggregation.get(
				"authority_global_mismatch_count",
				0
			)) == 3,
		"aggregate rejects mixed step-limit, authority, and tree shard evidence"
	)
	var second_paths: Dictionary = simulator.authority_job_paths(
		authority,
		heartbeat_only_job,
		0
	)
	var heartbeat_directory := str(second_paths.get(
		"heartbeat_directory",
		""
	))
	DirAccess.make_dir_recursive_absolute(heartbeat_directory)
	var heartbeat_only_path := heartbeat_directory.path_join(
		"heartbeat-only-fixture.json"
	)
	var heartbeat_only_file := FileAccess.open(
		heartbeat_only_path,
		FileAccess.WRITE
	)
	if heartbeat_only_file != null:
		heartbeat_only_file.store_string(
			JSON.stringify({"heartbeat_kind": "fixture_without_result"}) + "\n"
		)
		heartbeat_only_file.close()
	var heartbeat_only: Dictionary = simulator.inspect_authority_job_result(
		authority,
		heartbeat_only_job,
		0
	)
	_expect(
		bool(heartbeat_only.get("accepted", false))
			and str(heartbeat_only.get("action", "")) == "run",
		"heartbeat-only state never skips an unfinished exact job"
	)
	_expect(
		not _contains_temporary_file(authority_root),
		"successful atomic installs leave no temporary result or heartbeat"
	)
	_remove_tree(authority_root)
	OS.set_environment("V075_SIMULATION_SOURCE_SHA", previous_source_sha)
	print(
		"V075_SIMULATION_RESUME_CONTRACT|checks=%d|failures=%d|status=%s"
		% [_checks, _failures.size(), "PASS" if _failures.is_empty() else "FAIL"]
	)
	for failure in _failures:
		print("FAIL: %s" % failure)
	quit(0 if _failures.is_empty() else 1)


func _synthetic_row(
	simulator: RefCounted,
	job: Dictionary,
	configuration_index: int,
	combat_action_count: int
) -> Dictionary:
	var configuration := (
		simulator.configurations()[configuration_index] as Dictionary
	)
	var identity := {
		"configuration_id": str(configuration.get("configuration_id", "")),
		"seed": int(job.get("seed", 0)),
		"start_accepted": true,
		"completion_accepted": true,
		"phase": "settled",
		"steps": 1,
		"map_fingerprint": "contract-map",
		"final_settlement_count": 1,
		"combat": {},
		"track": {},
		"settlement_id": "contract-settlement",
	}
	var metrics := simulator.call("_empty_metrics") as Dictionary
	metrics["COMBAT_SIMULATION_MATCH_COUNT"] = 1
	metrics["COMBAT_SIMULATION_SETTLED_COUNT"] = 1
	metrics["COMBAT_SIMULATION_STEP_LIMIT_COUNT"] = 0
	metrics["TRACK_SHARED_SCROLL_VACANCY_VIOLATION_COUNT"] = 0
	metrics["TRACK_RATIO_CONTRACT_VIOLATION_COUNT"] = 0
	metrics["COMBAT_ACTION_COUNT"] = combat_action_count
	metrics["FINAL_SETTLEMENT_COUNT"] = 1
	metrics["DUPLICATE_SETTLEMENT_COUNT"] = 0
	return {
		"configuration_index": configuration_index,
		"match_index": int(job.get("match_index", -1)),
		"configuration_id": str(configuration.get("configuration_id", "")),
		"seed": int(job.get("seed", 0)),
		"settled": true,
		"phase": "settled",
		"steps": 1,
		"duration_msec": 1,
		"timing": {},
		"simulation_performance": {},
		"completion": {"accepted": true, "phase": "settled", "steps": 1},
		"metrics": metrics,
		"fingerprint": simulator.fingerprint(identity),
		"identity": identity,
	}


func _refresh_record_fingerprint(
	simulator: RefCounted,
	record: Dictionary
) -> void:
	record.erase("record_fingerprint")
	record["record_fingerprint"] = simulator.fingerprint(record)


func _refresh_report_fingerprint(
	simulator: RefCounted,
	report: Dictionary
) -> void:
	report.erase("report_fingerprint")
	report["report_fingerprint"] = simulator.fingerprint(report)


func _contains_temporary_file(root_path: String) -> bool:
	var directory := DirAccess.open(root_path)
	if directory == null:
		return false
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := root_path.path_join(entry)
		if directory.current_is_dir():
			if _contains_temporary_file(path):
				directory.list_dir_end()
				return true
		elif entry.contains(".tmp."):
			directory.list_dir_end()
			return true
		entry = directory.get_next()
	directory.list_dir_end()
	return false


func _remove_tree(root_path: String) -> void:
	var directory := DirAccess.open(root_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := root_path.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(path)
		else:
			DirAccess.remove_absolute(path)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(root_path)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
