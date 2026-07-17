extends Control
class_name GameSessionSaveOwnershipBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const SAVE_SCENE_PATH := "res://scenes/runtime/GameSaveRuntimeCoordinator.tscn"
const SMOKE_TEST_PATH := "res://tests/smoke_test.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/game_session_save_ownership/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/game_session_save_ownership_sprint_2.png"
const ROUNDTRIP_PATH := OUTPUT_DIR + "roundtrip_v1.save"
const LEGACY_PATH := OUTPUT_DIR + "legacy_optional_fields_v1.save"
const MALFORMED_PATH := OUTPUT_DIR + "malformed_variant.save"
const REAL_MAIN_PATH := OUTPUT_DIR + "real_main_delegation_v1.save"
const QA_DEFAULT_PATH := "user://space_syndicate_design_qa/test_runs/game_session_save_ownership.save"
const EXPECTED_SAVE_VERSION := 1
const EXPECTED_DEFAULT_PATH := "user://space_syndicate_current_run.save"

@export var auto_run := true

@onready var ruleset_bridge: Node = %RulesetRuntimeBridge
@onready var coordinator: Node = %GameRuntimeCoordinator
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText

var _records: Array = []
var _failures: Array[String] = []
var _real_main: Control = null


func _ready() -> void:
	_configure_runtime()
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_ownership_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func ownership_cases() -> Array:
	return [
		"controller_scene_composition",
		"idle_session_state",
		"begin_first_table_session",
		"session_identity_preserved",
		"pause_resume_lifecycle",
		"dirty_state_after_runtime_action",
		"save_version_unchanged",
		"default_save_path_unchanged",
		"qa_default_path_override_accepts_test_root",
		"qa_default_path_override_rejects_player_path",
		"real_main_uses_isolated_default_path",
		"smoke_test_declares_isolated_save_scope",
		"compose_current_save_semantic_parity",
		"qa_save_write_read_roundtrip",
		"load_current_save_format",
		"load_legacy_compatible_fixture",
		"malformed_json_safe_failure",
		"missing_optional_fields_normalized",
		"real_main_save_delegates_to_controller",
		"real_main_load_delegates_to_controller",
		"controller_state_survives_save_roundtrip",
		"private_runtime_data_not_in_debug_snapshot",
		"no_node_callable_resource_in_payloads",
		"main_legacy_file_io_inactive",
	]


func build_ownership_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in ownership_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite": "game-session-save-ownership-v1",
		"output_dir": OUTPUT_DIR,
		"record_count": records.size(),
		"records": records,
	}


func run_ownership_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_files()
	_configure_runtime()
	_real_main = await _prepare_real_main()
	for case_id_variant in ownership_cases():
		var case_id := str(case_id_variant)
		var record := _run_case(case_id)
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "failed"))])
	_release_real_main()
	await get_tree().process_frame
	var manifest := {
		"suite": "game-session-save-ownership-v1",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": _records.size(),
		"passed_count": _passed_count(),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_bench_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("GameSessionSaveOwnershipBench manifest: %s" % MANIFEST_PATH)
	print("GameSessionSaveOwnershipBench report: %s" % REPORT_PATH)
	print("GameSessionSaveOwnershipBench screenshot: %s" % SCREENSHOT_PATH)
	print("GameSessionSaveOwnershipBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("GameSessionSaveOwnershipBench failed:\n- %s" % "\n- ".join(_failures))


func _run_case(case_id: String) -> Dictionary:
	var session := _session_node()
	var save := _save_node()
	var passed := false
	var notes := ""
	var flags := {}
	match case_id:
		"controller_scene_composition":
			passed = coordinator != null and session != null and save != null and session.scene_file_path == "res://scenes/runtime/GameSessionRuntimeController.tscn" and save.scene_file_path == "res://scenes/runtime/GameSaveRuntimeCoordinator.tscn"
			notes = "scene-owned coordinator/session/save composition"
		"idle_session_state":
			coordinator.call("reset_state")
			passed = str(session.call("session_state")) == "idle"
			notes = "reset returns session lifecycle to idle"
		"begin_first_table_session":
			var summary: Dictionary = coordinator.call("begin_session", _session_fixture())
			passed = str(summary.get("session_state", "")) == "running" and str(summary.get("scenario_id", "")) == "first_table"
			notes = "first_table begins as a running v0.4 session"
		"session_identity_preserved":
			var summary: Dictionary = session.call("session_summary")
			passed = str(summary.get("session_id", "")) == "qa_first_table" and int(summary.get("seed", 0)) == 424242 and str(summary.get("ruleset_id", "")) == "v0.4"
			notes = "safe session identity remains stable in memory"
		"pause_resume_lifecycle":
			coordinator.call("pause_session")
			var paused := str(session.call("session_state")) == "paused"
			coordinator.call("resume_session")
			passed = paused and str(session.call("session_state")) == "running"
			notes = "pause and resume are owned by GameSessionRuntimeController"
		"dirty_state_after_runtime_action":
			coordinator.call("mark_session_dirty", "qa_runtime_action")
			var debug: Dictionary = session.call("debug_snapshot")
			var summary: Dictionary = debug.get("session", {}) if debug.get("session", {}) is Dictionary else {}
			passed = bool(summary.get("dirty", false)) and str(debug.get("dirty_reason", "")) == "qa_runtime_action"
			notes = "runtime action marks the session dirty without copying domain state"
		"save_version_unchanged":
			passed = int(coordinator.call("run_save_version")) == EXPECTED_SAVE_VERSION
			flags["payload_parity_checked"] = true
			notes = "current-run save version remains 1"
		"default_save_path_unchanged":
			passed = str(coordinator.call("default_run_save_path")) == EXPECTED_DEFAULT_PATH
			flags["payload_parity_checked"] = true
			notes = "player default path is unchanged"
		"qa_default_path_override_accepts_test_root":
			var probe := _fresh_save_probe()
			if probe != null:
				var accepted := bool(probe.call("set_qa_default_save_path_override", QA_DEFAULT_PATH))
				probe.call("configure")
				var operation: Dictionary = probe.call("operation_snapshot")
				passed = accepted and bool(operation.get("configured", false)) and bool(operation.get("qa_save_path_override_active", false)) and str(operation.get("default_save_path", "")) == QA_DEFAULT_PATH
				probe.free()
			flags["qa_isolation_checked"] = true
			notes = "QA override accepts only the dedicated user:// test_runs root"
		"qa_default_path_override_rejects_player_path":
			var probe := _fresh_save_probe()
			if probe != null:
				var rejected := not bool(probe.call("set_qa_default_save_path_override", EXPECTED_DEFAULT_PATH))
				probe.call("configure")
				var operation: Dictionary = probe.call("operation_snapshot")
				passed = rejected and not bool(operation.get("qa_save_path_override_active", false)) and str(operation.get("default_save_path", "")) == EXPECTED_DEFAULT_PATH
				probe.free()
			flags["qa_isolation_checked"] = true
			notes = "QA override cannot redirect through the player's production save path"
		"real_main_uses_isolated_default_path":
			var main_save := _real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator") if _real_main != null else null
			var operation: Dictionary = main_save.call("operation_snapshot") if main_save != null else {}
			passed = str(operation.get("default_save_path", "")) == QA_DEFAULT_PATH and bool(operation.get("qa_save_path_override_active", false))
			flags["qa_isolation_checked"] = true
			notes = "real main is isolated before _ready or menu save-status reads run"
		"smoke_test_declares_isolated_save_scope":
			var source := FileAccess.get_file_as_string(SMOKE_TEST_PATH)
			passed = source.contains("set_qa_default_save_path_override") and source.contains("user://space_syndicate_design_qa/test_runs/") and not source.contains("main.set(\"run_save_path\"")
			flags["qa_isolation_checked"] = true
			notes = "legacy smoke test no longer writes a removed Main property or uses the player slot"
		"compose_current_save_semantic_parity":
			var domain := _domain_fixture()
			var payload: Dictionary = coordinator.call("compose_run_save_payload", domain)
			var expected := domain.duplicate(true)
			expected["version"] = EXPECTED_SAVE_VERSION
			passed = payload == expected and payload.keys().size() == domain.keys().size() + 1
			flags["payload_parity_checked"] = true
			notes = "flat v1 envelope adds only the existing version field"
		"qa_save_write_read_roundtrip":
			var write_result: Dictionary = coordinator.call("request_run_save", ROUNDTRIP_PATH, _domain_fixture())
			var read_result: Dictionary = coordinator.call("read_run_save", ROUNDTRIP_PATH)
			var expected: Dictionary = coordinator.call("compose_run_save_payload", _domain_fixture())
			passed = bool(write_result.get("ok", false)) and bool(read_result.get("ok", false)) and read_result.get("payload", {}) == expected
			flags["roundtrip_checked"] = true
			notes = "QA-only Variant-binary write/read roundtrip"
		"load_current_save_format":
			var load_result: Dictionary = coordinator.call("request_run_load", ROUNDTRIP_PATH)
			passed = bool(load_result.get("ok", false)) and int(load_result.get("save_version", 0)) == EXPECTED_SAVE_VERSION
			coordinator.call("complete_run_load", OK if passed else ERR_INVALID_DATA)
			flags["roundtrip_checked"] = true
			notes = "current v1 format loads through the new owner"
		"load_legacy_compatible_fixture":
			var legacy := _minimal_domain_fixture()
			legacy["players"] = [{"name": "Legacy", "slots": [{"charge": 2, "control": 1, "name": "旧卡"}]}]
			var payload: Dictionary = coordinator.call("compose_run_save_payload", legacy)
			_write_variant_file(LEGACY_PATH, payload)
			var read_result: Dictionary = coordinator.call("read_run_save", LEGACY_PATH)
			var loaded_players: Array = (read_result.get("payload", {}) as Dictionary).get("players", []) if read_result.get("payload", {}) is Dictionary else []
			var slot: Dictionary = (((loaded_players[0] as Dictionary).get("slots", []) as Array)[0] as Dictionary) if not loaded_players.is_empty() else {}
			passed = bool(read_result.get("ok", false)) and not slot.has("charge") and not slot.has("control") and str(slot.get("name", "")) == "旧卡"
			flags["legacy_compatibility_checked"] = true
			notes = "v1 optional fields and legacy card fields normalize safely"
		"malformed_json_safe_failure":
			_write_variant_file(MALFORMED_PATH, "not a Dictionary")
			var result: Dictionary = coordinator.call("request_run_load", MALFORMED_PATH)
			passed = not bool(result.get("ok", false)) and int(result.get("error_code", OK)) == ERR_INVALID_DATA
			flags["legacy_compatibility_checked"] = true
			notes = "malformed Variant data returns structured ERR_INVALID_DATA"
		"missing_optional_fields_normalized":
			var minimal := _minimal_domain_fixture()
			var payload: Dictionary = coordinator.call("compose_run_save_payload", minimal)
			_write_variant_file(LEGACY_PATH, payload)
			var result: Dictionary = coordinator.call("read_run_save", LEGACY_PATH)
			passed = bool(result.get("ok", false)) and (result.get("payload", {}) as Dictionary).keys().size() == 3
			flags["legacy_compatibility_checked"] = true
			notes = "only version, players, and districts are required"
		"real_main_save_delegates_to_controller":
			passed = _real_main != null and int(_real_main.call("_save_run", REAL_MAIN_PATH)) == OK
			if passed:
				var main_save := _real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
				var operation: Dictionary = main_save.call("operation_snapshot") if main_save != null else {}
				passed = str(operation.get("last_operation", "")) == "write" and str(operation.get("last_path", "")) == REAL_MAIN_PATH
			flags["main_delegation_checked"] = true
			notes = "real main save wrapper delegates file I/O to GameSaveRuntimeCoordinator"
		"real_main_load_delegates_to_controller":
			if _real_main != null:
				((_real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time = 99.0
				passed = int(_real_main.call("_load_run", REAL_MAIN_PATH)) == OK and not is_equal_approx(float(((_real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time), 99.0)
			flags["main_delegation_checked"] = true
			notes = "real main load wrapper applies payload returned by the new coordinator"
		"controller_state_survives_save_roundtrip":
			coordinator.call("begin_session", _session_fixture())
			coordinator.call("mark_session_dirty", "roundtrip")
			var write_result: Dictionary = coordinator.call("request_run_save", ROUNDTRIP_PATH, _domain_fixture())
			var load_result: Dictionary = coordinator.call("request_run_load", ROUNDTRIP_PATH)
			coordinator.call("complete_run_load", OK if bool(load_result.get("ok", false)) else ERR_INVALID_DATA)
			var summary: Dictionary = session.call("session_summary")
			passed = bool(write_result.get("ok", false)) and bool(load_result.get("ok", false)) and str(summary.get("session_state", "")) == "running" and str(summary.get("save_state", "")) == "clean"
			flags["roundtrip_checked"] = true
			notes = "session lifecycle and save-operation state recover after roundtrip"
		"private_runtime_data_not_in_debug_snapshot":
			var private_setup := _session_fixture()
			private_setup["hidden_owner"] = 3
			private_setup["private_hand"] = ["secret_card"]
			private_setup["ai_private_plan"] = "secret_plan"
			coordinator.call("begin_session", private_setup)
			var encoded := JSON.stringify(session.call("debug_snapshot"))
			passed = not encoded.contains("hidden_owner") and not encoded.contains("secret_card") and not encoded.contains("secret_plan")
			flags["privacy_checked"] = true
			notes = "debug snapshot exposes only whitelisted session metadata"
		"no_node_callable_resource_in_payloads":
			passed = _is_data_only(session.call("debug_snapshot")) and _is_data_only(save.call("operation_snapshot")) and _is_data_only(coordinator.call("debug_snapshot"))
			flags["pure_data_checked"] = true
			notes = "all public debug snapshots remain data-only"
		"main_legacy_file_io_inactive":
			var main_script := _real_main.get_script() as Script if _real_main != null else null
			var source := FileAccess.get_file_as_string(main_script.resource_path) if main_script != null else ""
			passed = not source.contains("FileAccess") and not source.contains("store_var(") and not source.contains("get_var(") and not source.contains("RUN_SAVE_VERSION") and not source.contains("RUN_SAVE_PATH") and source.contains("request_run_save") and source.contains("request_run_load") and source.contains("_capture_run_domain_state_compatibility_adapter")
			flags["main_delegation_checked"] = true
			notes = "main keeps domain adapters but no save-format or file-I/O authority"
	return _record(case_id, passed, notes, flags)


func _configure_runtime() -> void:
	if coordinator == null or ruleset_bridge == null:
		return
	var ruleset_snapshot: Dictionary = ruleset_bridge.call("debug_snapshot")
	coordinator.call("configure", ruleset_snapshot)


func _session_node() -> Node:
	return coordinator.get_node_or_null("GameSessionRuntimeController") if coordinator != null else null


func _save_node() -> Node:
	var session := _session_node()
	return session.get_node_or_null("GameSaveRuntimeCoordinator") if session != null else null


func _session_fixture() -> Dictionary:
	return {
		"session_id": "qa_first_table",
		"scenario_id": "first_table",
		"ruleset_id": "v0.4",
		"seed": 424242,
		"player_count": 4,
		"ai_player_count": 3,
		"difficulty": "intro",
		"mission_title": "First Table",
	}


func _domain_fixture() -> Dictionary:
	return {
		"rng_state": 424242,
		"players": [{"name": "Player 1", "cash": 100}],
		"districts": [{"name": "QA District", "destroyed": false}],
		"skill_market": ["轨道融资1"],
		"product_market": {"能源": 12},
		"card_resolution_queue": [],
		"active_monster_wagers": [],
		"pending_discard_purchase": {},
		"game_time": 12.5,
	}


func _minimal_domain_fixture() -> Dictionary:
	return {"players": [], "districts": []}


func _prepare_real_main() -> Control:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	var main := packed.instantiate() as Control
	if main == null:
		return null
	main.name = "RealMainDelegationGate"
	main.visible = false
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var save := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	if save == null or not save.has_method("set_qa_default_save_path_override") or not bool(save.call("set_qa_default_save_path_override", QA_DEFAULT_PATH)):
		main.free()
		return null
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	return main


func _release_real_main() -> void:
	if _real_main == null:
		return
	for player_variant in _real_main.find_children("*", "AudioStreamPlayer", true, false):
		var player := player_variant as AudioStreamPlayer
		if player != null:
			player.stop()
			player.stream = null
	_real_main.queue_free()
	_real_main = null


func _record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var session := _session_node()
	return {
		"case_id": case_id,
		"session_state": str(session.call("session_state")) if session != null else "missing",
		"save_version": int(coordinator.call("run_save_version")) if coordinator != null else 0,
		"save_path": str(coordinator.call("default_run_save_path")) if coordinator != null else "",
		"payload_parity_checked": bool(flags.get("payload_parity_checked", false)),
		"roundtrip_checked": bool(flags.get("roundtrip_checked", false)),
		"legacy_compatibility_checked": bool(flags.get("legacy_compatibility_checked", false)),
		"main_delegation_checked": bool(flags.get("main_delegation_checked", false)),
		"qa_isolation_checked": bool(flags.get("qa_isolation_checked", false)),
		"privacy_checked": bool(flags.get("privacy_checked", false)),
		"pure_data_checked": bool(flags.get("pure_data_checked", false)),
		"passed": passed,
		"notes": notes,
	}


func _prepare_output_files() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for path in [MANIFEST_PATH, REPORT_PATH, SCREENSHOT_PATH, ROUNDTRIP_PATH, LEGACY_PATH, MALFORMED_PATH, REAL_MAIN_PATH, QA_DEFAULT_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_variant_file(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_var(value, false)
	file.close()


func _fresh_save_probe() -> Node:
	var packed := load(SAVE_SCENE_PATH) as PackedScene
	return packed.instantiate() if packed != null else null


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()


func _passed_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _markdown_report(manifest: Dictionary) -> String:
	var lines: Array[String] = [
		"# Game Session & Save Ownership QA",
		"",
		"- Format: Godot Variant binary (`store_var/get_var`)",
		"- Save version: `%d`" % EXPECTED_SAVE_VERSION,
		"- Player default path: `%s`" % EXPECTED_DEFAULT_PATH,
		"- QA output: `%s`" % OUTPUT_DIR,
		"- Passed: **%d/%d**" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"",
		"| Case | State | Parity | Roundtrip | Legacy | Main | QA isolation | Privacy | Pure | Passed | Notes |",
		"| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % [
			str(record.get("case_id", "")),
			str(record.get("session_state", "")),
			str(record.get("payload_parity_checked", false)),
			str(record.get("roundtrip_checked", false)),
			str(record.get("legacy_compatibility_checked", false)),
			str(record.get("main_delegation_checked", false)),
			str(record.get("qa_isolation_checked", false)),
			str(record.get("privacy_checked", false)),
			str(record.get("pure_data_checked", false)),
			str(record.get("passed", false)),
			str(record.get("notes", "")).replace("|", "/"),
		])
	return "\n".join(lines) + "\n"


func _update_bench_ui(manifest: Dictionary) -> void:
	var passed := int(manifest.get("passed_count", 0))
	var total := int(manifest.get("record_count", 0))
	if summary_label != null:
		summary_label.text = "Session/save ownership: %d/%d | v1 Variant binary" % [passed, total]
	if status_label != null:
		status_label.text = "PASS" if passed == total else "FAIL | %s" % "; ".join(_failures)
		status_label.modulate = Color("#86efac") if passed == total else Color("#fca5a5")
	if ownership_text != null:
		ownership_text.text = "[b]GameSessionRuntimeController[/b]\n• lifecycle and safe identity\n• dirty/save operation state\n• no gameplay world copy\n\n[b]GameSaveRuntimeCoordinator[/b]\n• version 1 and production default path\n• QA-only user:// test_runs override\n• Variant-binary validation and file I/O\n\n[b]main.gd compatibility boundary[/b]\n• collect/apply domain fields\n• no save path or format authority"


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(ProjectSettings.globalize_path(SCREENSHOT_PATH))


func _is_data_only(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT or value is Callable:
		return false
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
	elif value is Array:
		for item_variant in value:
			if not _is_data_only(item_variant):
				return false
	return true
