extends Control
class_name ScenarioRuntimeGlueCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const CONTROLLER_SCENE_PATH := "res://scenes/runtime/ScenarioRuntimeController.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/scenario_runtime_glue_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/scenario_runtime_glue_cutover_sprint_5.png"
const FIRST_TABLE_SIGNALS := [
	"district_selected",
	"monster_summoned",
	"rack_opened",
	"card_bought",
	"card_played",
	"city_development_resolved",
	"economy_checked",
	"followup_card_bought",
	"followup_card_played",
	"track_selected",
	"ai_public_action_observed",
	"public_clue_read",
	"monster_pressure_observed",
	"route_chosen",
]

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
	print("ScenarioRuntimeGlueCutoverBench ready: auto_run=%s editor_hint=%s" % [auto_run, Engine.is_editor_hint()])
	_configure_runtime()
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_cutover_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func cutover_cases() -> Array:
	return [
		"controller_scene_composition",
		"real_scenario_catalog_eight_entries",
		"first_table_definition_loads",
		"first_table_start_phase_select_district",
		"irrelevant_signal_rejected",
		"out_of_order_signal_rejected",
		"expected_signal_advances",
		"duplicate_signal_idempotent",
		"full_first_table_fourteen_phase_sequence",
		"snapshot_key_updates_from_phase",
		"phase_timer_and_failed_attempts",
		"coach_close_reopen_state",
		"action_log_public_entry",
		"action_log_private_viewer_filter",
		"developer_log_hidden_from_player",
		"visual_event_request_descriptor_only",
		"mission_completion_emitted_once",
		"restart_reset_deterministic",
		"current_v1_save_non_persistence_parity",
		"real_main_delegates_and_legacy_authority_inactive",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite": "scenario-runtime-glue-cutover-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"records": records,
	}


func run_cutover_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	_configure_runtime()
	_real_main = await _prepare_real_main()
	for case_id_variant in cutover_cases():
		var case_id := str(case_id_variant)
		var record := _run_case(case_id)
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "failed"))])
	await _release_real_main()
	await get_tree().process_frame
	await get_tree().process_frame
	var manifest := {
		"suite": "scenario-runtime-glue-cutover-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": _records.size(),
		"passed_count": _passed_count(),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("ScenarioRuntimeGlueCutoverBench manifest: %s" % MANIFEST_PATH)
	print("ScenarioRuntimeGlueCutoverBench report: %s" % REPORT_PATH)
	print("ScenarioRuntimeGlueCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("ScenarioRuntimeGlueCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("ScenarioRuntimeGlueCutoverBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	match case_id:
		"controller_scene_composition":
			var controller := _controller_node()
			passed = controller != null and controller.scene_file_path == CONTROLLER_SCENE_PATH
			flags["controller_ready"] = _controller_ready()
			notes = "GameRuntimeCoordinator composes the editable scenario authority"
		"real_scenario_catalog_eight_entries":
			var catalog: Array = coordinator.call("scenario_catalog")
			passed = catalog.size() == 8 and _is_data_only(catalog)
			flags["pure_data_checked"] = true
			notes = "the existing ScenarioLoader catalog remains the single eight-scenario source"
		"first_table_definition_loads":
			var definition: Dictionary = coordinator.call("scenario_definition", "first_table")
			var phases: Array = definition.get("phases", []) if definition.get("phases", []) is Array else []
			passed = str(definition.get("id", "")) == "first_table" and phases.size() == 14 and _is_data_only(definition)
			flags["pure_data_checked"] = true
			notes = "first_table keeps its authored fourteen-phase definition"
		"first_table_start_phase_select_district":
			var start := _start_first_table(10.0)
			var phase := _phase(_progress(10.0))
			passed = bool(start.get("started", false)) and str(phase.get("id", "")) == "select_district"
			flags.merge(_phase_flags({}, phase), true)
			notes = "starting first_table selects its real first phase"
		"irrelevant_signal_rejected":
			_start_first_table(0.0)
			var before := _phase(_progress(0.0))
			var result := _complete("not_a_real_signal", 1.0)
			var after := _phase(_progress(1.0))
			passed = not bool(result.get("accepted", true)) and str(result.get("reason", "")) == "out_of_order_signal" and str(after.get("id", "")) == str(before.get("id", ""))
			flags.merge(_result_flags(before, after, result, "not_a_real_signal"), true)
			notes = "irrelevant signals cannot mutate progress"
		"out_of_order_signal_rejected":
			_start_first_table(0.0)
			var before := _phase(_progress(0.0))
			var result := _complete("monster_summoned", 1.0)
			var after := _phase(_progress(1.0))
			passed = not bool(result.get("accepted", true)) and str(result.get("reason", "")) == "out_of_order_signal" and str(after.get("id", "")) == "select_district"
			flags.merge(_result_flags(before, after, result, "monster_summoned"), true)
			notes = "a valid later signal is rejected until its phase becomes current"
		"expected_signal_advances":
			_start_first_table(0.0)
			var before := _phase(_progress(0.0))
			var result := _complete("district_selected", 1.0, "after_select")
			var after := _phase(_progress(1.0))
			passed = bool(result.get("accepted", false)) and str(after.get("id", "")) == "first_summon"
			flags.merge(_result_flags(before, after, result, "district_selected"), true)
			notes = "the expected success signal advances exactly one phase"
		"duplicate_signal_idempotent":
			_start_first_table(0.0)
			_complete("district_selected", 1.0, "after_select")
			var before := _phase(_progress(1.0))
			var duplicate := _complete("district_selected", 2.0, "after_select")
			var after := _phase(_progress(2.0))
			passed = not bool(duplicate.get("accepted", true)) and bool(duplicate.get("duplicate", false)) and str(after.get("id", "")) == str(before.get("id", ""))
			flags.merge(_result_flags(before, after, duplicate, "district_selected"), true)
			flags["duplicate_checked"] = true
			notes = "accepted signals are idempotent and cannot advance twice"
		"full_first_table_fourteen_phase_sequence":
			_start_first_table(0.0)
			var accepted_count := 0
			for index in range(FIRST_TABLE_SIGNALS.size()):
				var result := _complete(str(FIRST_TABLE_SIGNALS[index]), float(index + 1), "phase_%d" % index)
				accepted_count += 1 if bool(result.get("accepted", false)) else 0
			var progress := _progress(15.0)
			passed = accepted_count == 14 and bool(progress.get("completed", false)) and int(progress.get("current_index", -1)) == 14
			flags["accepted"] = passed
			flags["phase_after"] = "done"
			notes = "the unchanged first_table sequence completes in fourteen ordered signals"
		"snapshot_key_updates_from_phase":
			_start_first_table(0.0)
			var result := _complete("district_selected", 1.0, "after_select")
			var state := _state(1.0)
			passed = str(result.get("snapshot_key", "")) == "after_select" and str(state.get("active_snapshot_key", "")) == "after_select"
			flags["accepted"] = bool(result.get("accepted", false))
			flags["submitted_signal"] = "district_selected"
			notes = "replay snapshot ownership follows the accepted phase transition"
		"phase_timer_and_failed_attempts":
			_start_first_table(10.0)
			coordinator.call("record_runtime_scenario_failed_attempt", "select_district", _log_entry("hint", "Need help", "private recovery", "debug-only", 0, "start"), 16.0)
			var progress := _progress(16.0)
			var state := _state(16.0)
			passed = int(progress.get("failed_attempts", 0)) == 1 and is_equal_approx(float(progress.get("stuck_seconds", -1.0)), 6.0) and is_equal_approx(float(state.get("phase_started_at", -1.0)), 10.0)
			flags["log_checked"] = true
			notes = "failed attempts increment without resetting the current phase timer"
		"coach_close_reopen_state":
			_start_first_table(0.0)
			coordinator.call("set_runtime_scenario_coach_closed", true)
			var closed := _progress(0.0)
			coordinator.call("set_runtime_scenario_coach_closed", false)
			var reopened := _progress(0.0)
			passed = bool(closed.get("closed_to_chip", false)) and not bool(reopened.get("closed_to_chip", true))
			notes = "coach collapse state is scene-owned and reversible"
		"action_log_public_entry":
			_start_first_table(0.0)
			coordinator.call("record_runtime_scenario_action", _log_entry("public", "Public move", "", "", 0, "start"))
			var log: Array = coordinator.call("runtime_scenario_viewer_action_log", 3, false)
			passed = log.size() == 1 and str((log[0] as Dictionary).get("text", "")) == "Public move"
			flags["log_checked"] = true
			notes = "public action entries are visible to every viewer"
		"action_log_private_viewer_filter":
			_start_first_table(0.0)
			coordinator.call("record_runtime_scenario_action", _log_entry("private", "Public shell", "viewer-zero-only", "", 0, "start"))
			var owner_log: Array = coordinator.call("runtime_scenario_viewer_action_log", 0, false)
			var rival_log: Array = coordinator.call("runtime_scenario_viewer_action_log", 2, false)
			var owner_text := JSON.stringify(owner_log)
			var rival_text := JSON.stringify(rival_log)
			passed = owner_text.contains("viewer-zero-only") and not rival_text.contains("viewer-zero-only")
			flags["log_checked"] = true
			flags["privacy_checked"] = true
			notes = "private log text is only merged for its owning viewer"
		"developer_log_hidden_from_player":
			_start_first_table(0.0)
			coordinator.call("record_runtime_scenario_action", _log_entry("developer", "Public shell", "", "true_owner=player3", 0, "start"))
			var player_log: Array = coordinator.call("runtime_scenario_viewer_action_log", 0, false)
			var developer_log: Array = coordinator.call("runtime_scenario_viewer_action_log", 0, true)
			passed = not JSON.stringify(player_log).contains("true_owner") and JSON.stringify(developer_log).contains("true_owner")
			flags["log_checked"] = true
			flags["privacy_checked"] = true
			notes = "developer diagnostics stay outside player-facing action logs"
		"visual_event_request_descriptor_only":
			_start_first_table(0.0)
			var request: Dictionary = coordinator.call("build_runtime_scenario_visual_event_request", "first_table", "after_select", "district_selected")
			var encoded := JSON.stringify(request)
			passed = _is_data_only(request) and str(request.get("scenario_id", "")) == "first_table" and not encoded.contains("true_owner") and not encoded.contains("private_cash") and not encoded.contains("ai_score")
			flags["privacy_checked"] = true
			flags["pure_data_checked"] = true
			notes = "visual requests contain descriptors only and apply the migrated privacy filter"
		"mission_completion_emitted_once":
			_start_first_table(0.0)
			var final_result := {}
			for index in range(FIRST_TABLE_SIGNALS.size()):
				final_result = _complete(str(FIRST_TABLE_SIGNALS[index]), float(index + 1), "phase_%d" % index)
			var duplicate := _complete("route_chosen", 20.0, "complete")
			passed = bool(final_result.get("scenario_completed", false)) and bool(final_result.get("completion_first_report", false)) and not bool(duplicate.get("completion_first_report", true))
			flags["accepted"] = true
			flags["duplicate_checked"] = true
			notes = "mission completion produces one first-report edge and duplicate completion is inert"
		"restart_reset_deterministic":
			_start_first_table(0.0)
			_complete("district_selected", 1.0, "after_select")
			coordinator.call("record_runtime_scenario_action", _log_entry("extra", "Extra", "", "", 0, "after_select"))
			_start_first_table(100.0)
			var state := _state(100.0)
			var progress := _progress(100.0)
			passed = str(_phase(progress).get("id", "")) == "select_district" and (state.get("completed_signals", {}) as Dictionary).is_empty() and (state.get("action_log_entries", []) as Array).is_empty()
			notes = "starting the same scenario clears transient progress, coach state, and log deterministically"
		"current_v1_save_non_persistence_parity":
			var result := _exercise_real_main_save_boundary()
			passed = bool(result.get("version_ok", false)) and bool(result.get("path_ok", false)) and bool(result.get("detail_absent", false))
			flags["persistence_parity_checked"] = true
			flags["main_delegation_checked"] = true
			notes = "v1 save version/path remain unchanged and detailed scenario progress stays transient"
		"real_main_delegates_and_legacy_authority_inactive":
			var result := _exercise_real_main_delegation()
			passed = bool(result.get("controller_ready", false)) and bool(result.get("active_ok", false)) and bool(result.get("phase_ok", false)) and bool(result.get("legacy_removed", false)) and bool(result.get("metrics_gate", false))
			flags["controller_ready"] = bool(result.get("controller_ready", false))
			flags["main_delegation_checked"] = true
			flags["pure_data_checked"] = true
			notes = "real main delegates through the coordinator and retains no mirrored scenario authority"
	return _record(case_id, passed, notes, flags)


func _configure_runtime() -> void:
	if coordinator != null and ruleset_bridge != null:
		coordinator.call("configure", ruleset_bridge.call("debug_snapshot"))


func _controller_node() -> Node:
	return coordinator.get_node_or_null("ScenarioRuntimeController") if coordinator != null else null


func _controller_ready() -> bool:
	var controller := _controller_node()
	var debug: Dictionary = controller.call("debug_snapshot") if controller != null else {}
	return bool(debug.get("controller_ready", false)) and bool(debug.get("controller_authoritative", false))


func _start_first_table(now_seconds: float) -> Dictionary:
	return coordinator.call("start_runtime_scenario", "first_table", now_seconds) if coordinator != null else {}


func _progress(now_seconds: float) -> Dictionary:
	return coordinator.call("runtime_scenario_progress", now_seconds) if coordinator != null else {}


func _state(now_seconds: float) -> Dictionary:
	return coordinator.call("runtime_scenario_state", now_seconds) if coordinator != null else {}


func _phase(progress: Dictionary) -> Dictionary:
	var value: Variant = progress.get("current_phase", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _complete(signal_id: String, now_seconds: float, snapshot_key: String = "") -> Dictionary:
	return coordinator.call("complete_runtime_scenario_signal", signal_id, {
		"time": "%02d:%02d" % [floori(now_seconds / 60.0), int(now_seconds) % 60],
		"public_text": "Completed %s" % signal_id,
		"private_text": "",
		"developer_text": "signal:%s" % signal_id,
		"viewer_index": 0,
		"snapshot_key": snapshot_key,
		"focus_target": "scenario_coach",
	}, now_seconds) if coordinator != null else {}


func _log_entry(phase_id: String, public_text: String, private_text: String, developer_text: String, viewer_index: int, snapshot_key: String) -> Dictionary:
	return {
		"time": "00:01",
		"phase_id": phase_id,
		"public_text": public_text,
		"private_text": private_text,
		"developer_text": developer_text,
		"viewer_index": viewer_index,
		"snapshot_key": snapshot_key,
		"focus_target": "scenario_coach",
	}


func _phase_flags(before: Dictionary, after: Dictionary) -> Dictionary:
	return {
		"phase_before": str(before.get("id", "")),
		"phase_after": str(after.get("id", "")),
	}


func _result_flags(before: Dictionary, after: Dictionary, result: Dictionary, signal_id: String) -> Dictionary:
	return {
		"phase_before": str(before.get("id", "")),
		"submitted_signal": signal_id,
		"phase_after": str(after.get("id", "")),
		"accepted": bool(result.get("accepted", false)),
		"duplicate_checked": bool(result.get("duplicate", false)),
	}


func _prepare_real_main() -> Control:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	var main := packed.instantiate() as Control
	if main == null:
		return null
	main.visible = false
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.set_process(false)
	return main


func _exercise_real_main_save_boundary() -> Dictionary:
	if _real_main == null:
		return {}
	_real_main.call("_start_scenario_from_menu", "first_table")
	var payload: Dictionary = _real_main.call("_capture_run_state")
	var real_coordinator := _real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var detail_keys := ["active_scenario_id", "active_scenario_snapshot_key", "scenario_completed_signals", "scenario_phase_failed_attempts", "scenario_phase_started_at", "scenario_coach_closed", "scenario_action_log_entries", "scenario_runtime"]
	var detail_absent := true
	for key_variant in detail_keys:
		if payload.has(str(key_variant)):
			detail_absent = false
	return {
		"version_ok": int(payload.get("version", -1)) == 1 and real_coordinator != null and int(real_coordinator.call("run_save_version")) == 1,
		"path_ok": real_coordinator != null and str(real_coordinator.call("default_run_save_path")) == "user://space_syndicate_current_run.save",
		"detail_absent": detail_absent,
	}


func _exercise_real_main_delegation() -> Dictionary:
	if _real_main == null:
		return {}
	_real_main.call("_start_scenario_from_menu", "first_table")
	var real_coordinator := _real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var debug: Dictionary = real_coordinator.call("debug_snapshot") if real_coordinator != null else {}
	var scenario_debug: Dictionary = debug.get("scenario_runtime", {}) if debug.get("scenario_runtime", {}) is Dictionary else {}
	var progress: Dictionary = real_coordinator.call("runtime_scenario_progress", 0.0) if real_coordinator != null else {}
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var legacy_tokens := [
		"var active_scenario_id",
		"var active_scenario_snapshot_key",
		"var scenario_completed_signals",
		"var scenario_phase_failed_attempts",
		"var scenario_phase_started_at",
		"var scenario_coach_closed",
		"var scenario_action_log_entries",
		"ScenarioLoaderScript",
		"ScenarioProgressScript",
		"SCENARIO_VISUAL_EVENT_FORBIDDEN_KEYS",
	]
	var legacy_removed := true
	for token_variant in legacy_tokens:
		if source.contains(str(token_variant)):
			legacy_removed = false
	var metrics := _main_source_metrics(source)
	return {
		"controller_ready": bool(scenario_debug.get("controller_ready", false)) and bool(scenario_debug.get("controller_authoritative", false)),
		"active_ok": real_coordinator != null and str(real_coordinator.call("active_runtime_scenario_id")) == "first_table",
		"phase_ok": str(_phase(progress).get("id", "")) == "select_district",
		"legacy_removed": legacy_removed,
		"metrics_gate": int(metrics.get("nonblank", 999999)) < 46673 and int(metrics.get("functions", 999999)) < 2220 and int(metrics.get("variables", 999999)) < 262 and int(metrics.get("constants", 999999)) < 345,
	}


func _main_source_metrics(source: String) -> Dictionary:
	var nonblank := 0
	var functions := 0
	var variables := 0
	var constants := 0
	for line in source.split("\n"):
		if line.strip_edges() != "":
			nonblank += 1
		if line.begins_with("func "):
			functions += 1
		elif line.begins_with("var "):
			variables += 1
		elif line.begins_with("const "):
			constants += 1
	return {"nonblank": nonblank, "functions": functions, "variables": variables, "constants": constants}


func _release_real_main() -> void:
	if _real_main != null and is_instance_valid(_real_main):
		var audio_players: Array[AudioStreamPlayer] = []
		for player_variant in _real_main.find_children("*", "AudioStreamPlayer", true, false):
			var player := player_variant as AudioStreamPlayer
			if player != null:
				player.stop()
				audio_players.append(player)
		await get_tree().create_timer(0.2).timeout
		for player in audio_players:
			if is_instance_valid(player):
				player.stream = null
				player.free()
		_real_main.set("table_bgm_player", null)
		_real_main.set("table_sfx_players", {})
		_real_main.queue_free()
	_real_main = null


func _record(case_id: String, passed: bool, notes: String, overrides: Dictionary = {}) -> Dictionary:
	var record := {
		"case_id": case_id,
		"scenario_id": "first_table",
		"phase_before": "",
		"submitted_signal": "",
		"phase_after": "",
		"accepted": false,
		"duplicate_checked": false,
		"log_checked": false,
		"privacy_checked": false,
		"main_delegation_checked": false,
		"persistence_parity_checked": false,
		"pure_data_checked": false,
		"controller_ready": _controller_ready(),
		"passed": passed,
		"notes": notes,
	}
	record.merge(overrides, true)
	return record


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not _is_data_only(key) or not _is_data_only(value[key]):
				return false
		return true
	return false


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for path in [MANIFEST_PATH, REPORT_PATH, SCREENSHOT_PATH]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("cannot write %s" % path)
		return
	file.store_string(content)
	file.close()


func _markdown_report(manifest: Dictionary) -> String:
	var lines := [
		"# Scenario Runtime Glue Cutover",
		"",
		"Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"",
		"| Case | Result | Notes |",
		"| --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | %s |" % [str(record.get("case_id", "")), "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines) + "\n"


func _update_ui(manifest: Dictionary) -> void:
	var passed := int(manifest.get("passed_count", 0))
	var total := int(manifest.get("record_count", 0))
	summary_label.text = "%d/%d ownership cases passed" % [passed, total]
	status_label.text = "PASS" if passed == total else "FAIL"
	status_label.add_theme_color_override("font_color", Color("#22c55e") if passed == total else Color("#ef4444"))
	ownership_text.text = "[b]ScenarioRuntimeController[/b]\n- active scenario and replay snapshot key\n- ordered completion signals and phase timing\n- failed attempts and coach collapse state\n- privacy-filtered ScenarioActionLog\n- pure visual-event request descriptors\n\n[b]main.gd compatibility boundary[/b]\n- first_table authored gameplay execution\n- Campaign reward and navigation\n- GameScreen / Coach presentation\n- no mirrored Scenario progress authority\n\n[b]Persistence[/b]\nDetailed Scenario progress remains transient in v1 saves."


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("viewport screenshot is empty")
		return
	var error := image.save_png(SCREENSHOT_PATH)
	if error != OK:
		_failures.append("screenshot save failed: %s" % error_string(error))


func _passed_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count
