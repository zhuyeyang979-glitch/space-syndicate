extends SceneTree

const DRIVER_SCHEMA := 1
const DRIVER_ID := "full_run_quality_driver_v1"
const SEED_ALGORITHM := "space-syndicate-full-run-quality-v1:sha256-positive31"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const SESSION_PATH := "GameSessionRuntimeController"
const REGISTRY_PATH := "V06SaveOwnerRegistry"
const SAVE_COORDINATOR_PATH := "GameSaveRuntimeCoordinator"
const QA_SAVE_ROOT := "user://test_runs/full_run_quality/"
const REQUIRED_SECTION_COUNT := 18
const HEARTBEAT_INTERVAL_SECONDS := 5
const DEFAULT_MAX_WALL_SECONDS := 120
const EXIT_INVALID_ARGUMENTS := 2
const EXIT_CAPABILITY_INCOMPLETE := 3
const EXIT_EXECUTION_NOT_IMPLEMENTED := 4
const EXIT_RUNTIME_COMPOSITION_UNAVAILABLE := 5

const FIXED_SEEDS: Array[int] = [
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

const HEARTBEAT_PUBLIC_KEYS := [
	"type",
	"schema",
	"driver",
	"run_id",
	"seed_index",
	"seed",
	"seq",
	"driver_s",
	"world_s",
	"phase",
	"status",
	"session_state",
	"victory_state",
	"decision",
	"queue",
	"counts",
	"last_turning_point",
]
const SUMMARY_PUBLIC_KEYS := [
	"type",
	"schema",
	"driver",
	"algorithm",
	"run_id",
	"seed_index",
	"seed",
	"completed",
	"status",
	"failure_code",
	"qa_save_scope",
	"capability",
	"stages",
	"save",
	"pacing",
	"actions",
	"softlocks",
	"turning_points",
	"timeouts",
	"wall_ms",
]
const CAPABILITY_PUBLIC_KEYS := [
	"registry_valid",
	"required_sections",
	"transactional_sections",
	"unsupported_sections",
	"resume_ready",
	"rng_continuation_ready",
	"player_continuation_ready",
	"exact_resume_ready",
	"capture_probe_ok",
	"capture_fail_closed",
]
const STAGE_ORDER := [
	"capability_preflight",
	"setup",
	"tick",
	"save_checkpoint",
	"restore",
	"terminal",
	"settlement",
]

var _started_msec := 0
var _heartbeat_sequence := 0


func _init() -> void:
	_started_msec = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	if not bool(options.get("valid", false)):
		_emit_summary(_base_summary(options, "invalid_arguments", "invalid_arguments", {}))
		quit(EXIT_INVALID_ARGUMENTS)
		return

	var seed_index := int(options.get("seed_index", 0))
	var seed := FIXED_SEEDS[seed_index]
	var head := _head_token()
	var qa_scope := qa_save_directory(head, seed)
	_emit_heartbeat(seed_index, seed, "capability_preflight", "running")

	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		var missing_scene := _base_summary(options, "blocked_by_capability", "runtime_composition_unavailable", {})
		missing_scene["qa_save_scope"] = qa_scope
		_emit_summary(missing_scene)
		quit(EXIT_RUNTIME_COMPOSITION_UNAVAILABLE)
		return

	var main_instance := packed.instantiate()
	if main_instance == null:
		var missing_instance := _base_summary(options, "blocked_by_capability", "runtime_composition_unavailable", {})
		missing_instance["qa_save_scope"] = qa_scope
		_emit_summary(missing_instance)
		quit(EXIT_RUNTIME_COMPOSITION_UNAVAILABLE)
		return

	main_instance.process_mode = Node.PROCESS_MODE_DISABLED
	if main_instance is CanvasItem:
		(main_instance as CanvasItem).visible = false
	var coordinator := main_instance.get_node_or_null(COORDINATOR_PATH)
	var session := coordinator.get_node_or_null(SESSION_PATH) if coordinator != null else null
	var save_coordinator := session.get_node_or_null(SAVE_COORDINATOR_PATH) if session != null else null
	var qa_save_file := "%srun.save" % qa_scope
	var qa_path_ready := save_coordinator != null \
		and save_coordinator.has_method("set_qa_default_save_path_override") \
		and bool(save_coordinator.call("set_qa_default_save_path_override", qa_save_file))
	root.add_child(main_instance)
	await process_frame

	if _wall_timed_out(int(options.get("max_wall_seconds", DEFAULT_MAX_WALL_SECONDS))):
		_cleanup_main(main_instance)
		var timed_out := _base_summary(options, "blocked_by_capability", "preflight_timeout", {})
		timed_out["qa_save_scope"] = qa_scope
		timed_out["timeouts"] = [{"phase": "capability_preflight", "limit_s": int(options.get("max_wall_seconds", DEFAULT_MAX_WALL_SECONDS))}]
		_emit_summary(timed_out)
		quit(EXIT_CAPABILITY_INCOMPLETE)
		return

	var registry := session.get_node_or_null(REGISTRY_PATH) if session != null else null
	var capability := _capability_preflight(coordinator, registry, qa_path_ready)
	var capability_ready := bool(capability.get("ready", false))
	var public_capability: Dictionary = capability.get("public", {}) if capability.get("public", {}) is Dictionary else {}
	_emit_heartbeat(seed_index, seed, "capability_preflight", "ready" if capability_ready else "blocked_by_capability")
	_cleanup_main(main_instance)

	if not capability_ready:
		var blocked := _base_summary(options, "blocked_by_capability", "restore_capability_incomplete", public_capability)
		blocked["qa_save_scope"] = qa_scope
		blocked["stages"] = _stage_statuses("failed", "blocked_by_capability")
		_emit_summary(blocked)
		quit(EXIT_CAPABILITY_INCOMPLETE)
		return

	if bool(options.get("preflight_only", false)):
		var ready := _base_summary(options, "preflight_ready", "", public_capability)
		ready["qa_save_scope"] = qa_scope
		ready["stages"] = _stage_statuses("passed", "not_requested")
		_emit_summary(ready)
		quit(0)
		return

	var execution_blocked := _base_summary(options, "blocked_by_driver_implementation", "full_run_execution_not_implemented", public_capability)
	execution_blocked["qa_save_scope"] = qa_scope
	execution_blocked["stages"] = _stage_statuses("passed", "blocked_by_driver_implementation")
	_emit_summary(execution_blocked)
	quit(EXIT_EXECUTION_NOT_IMPLEMENTED)


func _capability_preflight(coordinator: Node, registry: Node, qa_path_ready: bool) -> Dictionary:
	var snapshot: Dictionary = {}
	var capture_probe: Dictionary = {}
	if registry != null and registry.has_method("registry_snapshot"):
		var snapshot_variant: Variant = registry.call("registry_snapshot")
		if snapshot_variant is Dictionary:
			snapshot = (snapshot_variant as Dictionary).duplicate(true)
	if registry != null and registry.has_method("capture_resume_envelope"):
		var capture_variant: Variant = registry.call("capture_resume_envelope", {
			"envelope_id": "full-run-capability-probe",
			"write_id": "full-run-capability-probe",
		})
		if capture_variant is Dictionary:
			capture_probe = capture_variant as Dictionary

	var continuation := _continuation_capability_snapshot(coordinator)
	var registry_valid := bool(snapshot.get("valid", false)) and qa_path_ready
	var required_sections := int(snapshot.get("required_section_count", 0))
	var transactional_sections := int(snapshot.get("transactional_section_count", 0))
	var unsupported_sections := int(snapshot.get("unsupported_section_count", REQUIRED_SECTION_COUNT))
	var resume_ready := bool(snapshot.get("resume_ready", false))
	var rng_ready := bool(continuation.get("rng_state_transactional", false)) \
		and bool(continuation.get("rng_authority_unique", false))
	var player_ready := bool(continuation.get("complete_player_state_transactional", false)) \
		and bool(continuation.get("player_state_authority_unique", false))
	var exact_resume_ready := bool(continuation.get("exact_resume_transactional", false))
	var capture_probe_ok := bool(capture_probe.get("ok", false)) \
		and str(capture_probe.get("reason_code", "")) == "resume_envelope_captured"
	var capture_fail_closed := not bool(capture_probe.get("ok", true)) \
		and str(capture_probe.get("reason_code", "")) == "restore_capability_incomplete" \
		and not capture_probe.has("envelope")
	var ready := registry_valid \
		and required_sections == REQUIRED_SECTION_COUNT \
		and transactional_sections == REQUIRED_SECTION_COUNT \
		and unsupported_sections == 0 \
		and resume_ready \
		and rng_ready \
		and player_ready \
		and exact_resume_ready \
		and capture_probe_ok
	return {
		"ready": ready,
		"public": {
			"registry_valid": registry_valid,
			"required_sections": maxi(0, required_sections),
			"transactional_sections": maxi(0, transactional_sections),
			"unsupported_sections": maxi(0, unsupported_sections),
			"resume_ready": resume_ready,
			"rng_continuation_ready": rng_ready,
			"player_continuation_ready": player_ready,
			"exact_resume_ready": exact_resume_ready,
			"capture_probe_ok": capture_probe_ok,
			"capture_fail_closed": capture_fail_closed,
		},
	}


func _continuation_capability_snapshot(coordinator: Node) -> Dictionary:
	if coordinator == null:
		return {}
	if coordinator.has_method("full_run_restore_capabilities"):
		var direct_variant: Variant = coordinator.call("full_run_restore_capabilities")
		if direct_variant is Dictionary:
			return (direct_variant as Dictionary).duplicate(true)
	if coordinator.has_method("debug_snapshot"):
		var debug_variant: Variant = coordinator.call("debug_snapshot")
		if debug_variant is Dictionary:
			var debug := debug_variant as Dictionary
			var capability_variant: Variant = debug.get("full_run_restore_capabilities")
			if capability_variant is Dictionary:
				return (capability_variant as Dictionary).duplicate(true)
	return {}


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var result := {
		"valid": true,
		"preflight_only": false,
		"seed_index": 0,
		"max_wall_seconds": DEFAULT_MAX_WALL_SECONDS,
	}
	var index := 0
	while index < arguments.size():
		var argument := str(arguments[index])
		if argument == "--preflight-only":
			result["preflight_only"] = true
		elif argument.begins_with("--seed-index="):
			if not _assign_integer_option(result, "seed_index", argument.trim_prefix("--seed-index="), 0, FIXED_SEEDS.size() - 1):
				result["valid"] = false
		elif argument == "--seed-index":
			index += 1
			if index >= arguments.size() or not _assign_integer_option(result, "seed_index", str(arguments[index]), 0, FIXED_SEEDS.size() - 1):
				result["valid"] = false
		elif argument.begins_with("--max-wall-seconds="):
			if not _assign_integer_option(result, "max_wall_seconds", argument.trim_prefix("--max-wall-seconds="), 1, 86400):
				result["valid"] = false
		elif argument == "--max-wall-seconds":
			index += 1
			if index >= arguments.size() or not _assign_integer_option(result, "max_wall_seconds", str(arguments[index]), 1, 86400):
				result["valid"] = false
		else:
			result["valid"] = false
		index += 1
	return result


func _assign_integer_option(target: Dictionary, key: String, text: String, minimum: int, maximum: int) -> bool:
	if not text.is_valid_int():
		return false
	var value := text.to_int()
	if value < minimum or value > maximum:
		return false
	target[key] = value
	return true


func _emit_heartbeat(seed_index: int, seed: int, phase: String, status: String) -> void:
	_heartbeat_sequence += 1
	_emit_ndjson({
		"type": "heartbeat",
		"schema": DRIVER_SCHEMA,
		"driver": DRIVER_ID,
		"run_id": "seed-%02d" % seed_index,
		"seed_index": seed_index,
		"seed": seed,
		"seq": _heartbeat_sequence,
		"driver_s": _elapsed_seconds(),
		"world_s": 0.0,
		"phase": phase,
		"status": status,
		"session_state": "not_started",
		"victory_state": "not_started",
		"decision": {"kind": "none", "epoch": 0, "blocking": false},
		"queue": {"state": "not_started", "pending_count": 0},
		"counts": {"actions": 0, "invalid": 0, "softlocks": 0},
		"last_turning_point": "",
	})


func _base_summary(options: Dictionary, status: String, failure_code: String, capability: Dictionary) -> Dictionary:
	var seed_index := clampi(int(options.get("seed_index", 0)), 0, FIXED_SEEDS.size() - 1)
	return {
		"type": "summary",
		"schema": DRIVER_SCHEMA,
		"driver": DRIVER_ID,
		"algorithm": SEED_ALGORITHM,
		"run_id": "seed-%02d" % seed_index,
		"seed_index": seed_index,
		"seed": FIXED_SEEDS[seed_index],
		"completed": false,
		"status": status,
		"failure_code": failure_code,
		"qa_save_scope": qa_save_directory(_head_token(), FIXED_SEEDS[seed_index]),
		"capability": capability.duplicate(true),
		"stages": _stage_statuses("not_run", "not_run"),
		"save": {
			"attempted": false,
			"write_ok": false,
			"read_ok": false,
			"preflight_ok": false,
			"apply_ok": false,
			"sections_equal": false,
		},
		"pacing": {
			"human_source_s": 0.0,
			"first_sale_s": 0.0,
			"first_ai_public_action_s": 0.0,
			"qualification_s": 0.0,
			"audit_s": 0.0,
			"settlement_s": 0.0,
		},
		"actions": {
			"attempted": 0,
			"committed": 0,
			"rejected_retryable": 0,
			"rejected_invalid": 0,
			"reason_codes": {},
		},
		"softlocks": {"suspected": 0, "recovered": 0, "terminal": 0, "max_s": 0.0},
		"turning_points": [],
		"timeouts": [],
		"wall_ms": maxi(0, Time.get_ticks_msec() - _started_msec),
	}


func _stage_statuses(preflight_status: String, downstream_status: String) -> Dictionary:
	var statuses := {}
	for stage in STAGE_ORDER:
		statuses[stage] = preflight_status if stage == "capability_preflight" else downstream_status
	return statuses


func _emit_summary(summary: Dictionary) -> void:
	_emit_ndjson(summary)


func _emit_ndjson(payload: Dictionary) -> void:
	print(JSON.stringify(payload))


func _cleanup_main(main_instance: Node) -> void:
	if main_instance == null:
		return
	if main_instance.get_parent() != null:
		main_instance.get_parent().remove_child(main_instance)
	main_instance.free()


func _elapsed_seconds() -> float:
	return maxf(0.0, float(Time.get_ticks_msec() - _started_msec) / 1000.0)


func _wall_timed_out(max_wall_seconds: int) -> bool:
	return Time.get_ticks_msec() - _started_msec >= max_wall_seconds * 1000


func _head_token() -> String:
	var configured := OS.get_environment("SPACE_SYNDICATE_GIT_HEAD").strip_edges()
	return _safe_path_segment(configured if not configured.is_empty() else "local")


static func qa_save_directory(head: String, seed: int) -> String:
	return "%s%s/%d/" % [QA_SAVE_ROOT, _safe_path_segment(head), seed]


static func public_output_contract() -> Dictionary:
	return {
		"heartbeat_keys": HEARTBEAT_PUBLIC_KEYS.duplicate(),
		"summary_keys": SUMMARY_PUBLIC_KEYS.duplicate(),
		"capability_keys": CAPABILITY_PUBLIC_KEYS.duplicate(),
		"stage_order": STAGE_ORDER.duplicate(),
		"heartbeat_interval_seconds": HEARTBEAT_INTERVAL_SECONDS,
	}


static func _safe_path_segment(value: String) -> String:
	var result := ""
	for index in range(value.length()):
		var code := value.unicode_at(index)
		var allowed := (code >= 48 and code <= 57) \
			or (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122) \
			or code in [45, 95]
		result += String.chr(code) if allowed else "_"
	result = result.strip_edges().trim_prefix("_").trim_suffix("_")
	return result.substr(0, 64) if not result.is_empty() else "local"
