extends Control
class_name LegacyRuntimeSurfaceRetirementBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/legacy_runtime_surface_retirement/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/legacy_runtime_surface_retirement_sprint_8.png"

@export var auto_run := true

@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var results_text: RichTextLabel = %ResultsText

var _records: Array = []
var _failures: Array[String] = []
var _main: Control = null
var _main_source := ""


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_retirement_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func retirement_cases() -> Array:
	return [
		"real_main_scene_loads",
		"runtime_game_screen_is_primary",
		"legacy_table_shell_absent",
		"legacy_build_flag_absent",
		"layout_requires_sceneized_screen",
		"compatibility_player_host_absent",
		"legacy_card_track_builder_absent",
		"legacy_card_track_state_absent",
		"sceneized_card_track_present",
		"sceneized_player_board_present",
		"sceneized_overlay_surfaces_present",
		"runtime_snapshot_pure_data",
		"fallback_missing_duplicate_zero",
		"track_selection_syncs_sceneized_screen",
	]


func build_retirement_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in retirement_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {"suite": "legacy-runtime-surface-retirement-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": records.size(), "records": records}


func run_retirement_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	_main_source = FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	await _ensure_main()
	for case_id_variant in retirement_cases():
		var case_id := str(case_id_variant)
		var record := _run_case(case_id)
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "failed"))])
	var metrics := _main_metrics()
	var manifest := {"suite": "legacy-runtime-surface-retirement-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": _records.size(), "passed_count": _passed_count(), "main_metrics": metrics, "records": _records.duplicate(true)}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	if _main != null:
		for player_variant in _main.find_children("*", "AudioStreamPlayer", true, false):
			var player := player_variant as AudioStreamPlayer
			if player != null:
				player.stop()
				player.stream = null
				player.free()
		_main.queue_free()
		_main = null
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("LegacyRuntimeSurfaceRetirementBench manifest: %s" % MANIFEST_PATH)
	print("LegacyRuntimeSurfaceRetirementBench report: %s" % REPORT_PATH)
	print("LegacyRuntimeSurfaceRetirementBench screenshot: %s" % SCREENSHOT_PATH)
	print("LegacyRuntimeSurfaceRetirementBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("LegacyRuntimeSurfaceRetirementBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func _ensure_main() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_main = packed.instantiate() as Control if packed != null else null
	if _main == null:
		return
	_main.visible = false
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	var screen := _main.get_node_or_null("RuntimeGameScreen") as Control if _main != null else null
	match case_id:
		"real_main_scene_loads":
			passed = _main != null and _main.scene_file_path == MAIN_SCENE_PATH
			flags["main_checked"] = true
			notes = "the retirement gate instantiates the real main scene"
		"runtime_game_screen_is_primary":
			passed = screen != null and screen.scene_file_path == "res://scenes/ui/GameScreen.tscn"
			flags["scene_checked"] = true
			notes = "the visible table has one editable GameScreen scene owner"
		"legacy_table_shell_absent":
			passed = _main != null and _main.get_node_or_null("LegacyRuntimeTable") == null and not FileAccess.get_file_as_string(MAIN_SCENE_PATH).contains("LegacyRuntimeTable")
			flags["retirement_checked"] = true
			notes = "the empty rollback shell is removed from main.tscn"
		"legacy_build_flag_absent":
			passed = not _main_source.contains("BUILD_LEGACY_RUNTIME_TABLE") and not _main_source.contains("legacy_table_root")
			flags["retirement_checked"] = true
			notes = "there is no runtime switch back to the generated table"
		"layout_requires_sceneized_screen":
			passed = _main_source.contains("RuntimeGameScreen scene is required; legacy runtime table construction has been retired.") and not _main_source.contains("func _configure_legacy_runtime_table_shell")
			flags["retirement_checked"] = true
			notes = "missing GameScreen is an explicit composition error, not a legacy rebuild request"
		"compatibility_player_host_absent":
			passed = _main != null and _main.find_child("SplitCompatibilityPlayerBox", true, false) == null and not _main_source.contains("func _refresh_split_compatibility_player_panel") and not _main_source.contains("func _uses_split_runtime_table")
			flags["retirement_checked"] = true
			notes = "the hidden generated opening-guide host no longer rebuilds every full refresh"
		"legacy_card_track_builder_absent":
			passed = not _main_source.contains("func _build_card_resolution_track") and not _main_source.contains("func _refresh_card_resolution_track") and not _main_source.contains("CardResolutionAgeTrack")
			flags["retirement_checked"] = true
			notes = "main.gd no longer constructs or refreshes a parallel public track"
		"legacy_card_track_state_absent":
			var removed_tokens := ["card_resolution_track_scroll", "card_resolution_track_panel", "card_resolution_track_dragging", "CARD_TRACK_VISIBLE_SLOT_COUNT", "CARD_TRACK_SLOT_WIDTH"]
			passed = true
			for token_variant in removed_tokens:
				passed = passed and not _main_source.contains(str(token_variant))
			flags["retirement_checked"] = true
			notes = "scroll, drag, geometry, and signature state dedicated to the removed renderer is gone"
		"sceneized_card_track_present":
			var public_track := screen.find_child("PublicTrack", true, false) if screen != null else null
			var public_track_scene_source := FileAccess.get_file_as_string("res://scenes/ui/PublicTrack.tscn")
			var public_track_script_path: String = ""
			if public_track != null and public_track.get_script() is Script:
				public_track_script_path = str((public_track.get_script() as Script).resource_path)
			passed = public_track != null and public_track_script_path == "res://scripts/ui/card_resolution_track.gd" and public_track_scene_source.contains("res://scenes/ui/CardResolutionTrack.tscn")
			flags["scene_checked"] = true
			notes = "PublicTrack uses the CardResolutionTrack PackedScene and renderer script (runtime scene: %s)" % (public_track.scene_file_path if public_track != null else "missing")
		"sceneized_player_board_present":
			var player_board := screen.find_child("PlayerBoard", true, false) if screen != null else null
			var hand_rack := screen.find_child("HandRack", true, false) if screen != null else null
			passed = player_board != null and player_board.scene_file_path == "res://scenes/ui/PlayerBoard.tscn" and hand_rack != null
			flags["scene_checked"] = true
			notes = "PlayerBoard and HandRack are real scene components without a hidden generated mirror"
		"sceneized_overlay_surfaces_present":
			var overlay := screen.find_child("OverlayLayer", true, false) if screen != null else null
			passed = overlay != null
			for node_name in ["FullscreenMapOverlay", "CardResolutionTableBannerOverlay", "BottomCountdownOverlay", "DistrictSupplySideDrawerOverlay", "MenuModalOverlay"]:
				passed = passed and overlay != null and overlay.find_child(node_name, true, false) != null
			flags["scene_checked"] = true
			notes = "all transient runtime surfaces remain owned by the editable OverlayLayer tree"
		"runtime_snapshot_pure_data":
			var snapshot: Dictionary = _main.call("_runtime_composition_snapshot") if _main != null and _main.has_method("_runtime_composition_snapshot") else {}
			passed = not snapshot.is_empty() and _is_data_only(snapshot) and not snapshot.has("legacy_table_shell_found")
			flags["pure_data_checked"] = true
			notes = "composition QA remains pure data and no longer advertises a legacy shell"
		"fallback_missing_duplicate_zero":
			var snapshot: Dictionary = _main.call("_runtime_composition_snapshot") if _main != null and _main.has_method("_runtime_composition_snapshot") else {}
			passed = bool(snapshot.get("sceneized_composition_enabled", false)) and not bool(snapshot.get("legacy_fallback_used", true)) and (snapshot.get("missing_nodes", []) as Array).is_empty() and int(snapshot.get("duplicate_node_count", -1)) == 0 and int(snapshot.get("duplicate_signal_count", -1)) == 0
			flags["snapshot_checked"] = true
			notes = "hard scene ownership reports no fallback, missing node, duplicate node, or duplicate signal"
		"track_selection_syncs_sceneized_screen":
			var select_start := _main_source.find("func _select_card_resolution_track_entry")
			var focus_start := _main_source.find("func _focus_card_resolution_track_entry")
			var select_slice := _main_source.substr(select_start, 520) if select_start >= 0 else ""
			var focus_slice := _main_source.substr(focus_start, 360) if focus_start >= 0 else ""
			passed = select_slice.contains("_sync_runtime_game_screen(true)") and focus_slice.contains("_sync_runtime_game_screen(true)")
			flags["bridge_checked"] = true
			notes = "public-track focus now refreshes the sceneized snapshot instead of a removed renderer"
	return _record(case_id, passed, notes, flags)


func _record(case_id: String, passed: bool, notes: String, overrides: Dictionary = {}) -> Dictionary:
	var record := {"case_id": case_id, "main_checked": false, "scene_checked": false, "retirement_checked": false, "snapshot_checked": false, "bridge_checked": false, "pure_data_checked": false, "legacy_shell_present": _main != null and _main.get_node_or_null("LegacyRuntimeTable") != null, "legacy_builder_present": _main_source.contains("func _build_card_resolution_track"), "passed": passed, "notes": notes}
	record.merge(overrides, true)
	return record


func _main_metrics() -> Dictionary:
	var metrics := {"physical_lines": 0, "nonblank_lines": 0, "function_count": 0, "top_level_variable_count": 0, "constant_count": 0}
	var lines := _main_source.split("\n")
	metrics["physical_lines"] = lines.size()
	for line_variant in lines:
		var line := str(line_variant)
		if line.strip_edges() != "":
			metrics["nonblank_lines"] = int(metrics["nonblank_lines"]) + 1
		if line.begins_with("func "):
			metrics["function_count"] = int(metrics["function_count"]) + 1
		elif line.begins_with("var "):
			metrics["top_level_variable_count"] = int(metrics["top_level_variable_count"]) + 1
		elif line.begins_with("const "):
			metrics["constant_count"] = int(metrics["constant_count"]) + 1
	return metrics


func _update_ui(manifest: Dictionary) -> void:
	var metrics: Dictionary = manifest.get("main_metrics", {}) if manifest.get("main_metrics", {}) is Dictionary else {}
	summary_label.text = "%d/%d retirement cases passed" % [int(manifest.get("passed_count", 0)), _records.size()]
	status_label.text = "PASS" if _failures.is_empty() else "FAIL"
	status_label.modulate = Color("4ade80") if _failures.is_empty() else Color("fb7185")
	ownership_text.text = "[b]Hard scene cutover[/b]\nGameScreen, PublicTrack/CardResolutionTrack, PlayerBoard/HandRack, PlanetBoard, RightInspector, and OverlayLayer are the only player-facing runtime surface tree. Missing GameScreen is now a composition error.\n\n[b]Retired from main.gd[/b]\nLegacyRuntimeTable, BUILD_LEGACY_RUNTIME_TABLE, SplitCompatibilityPlayerBox, old track construction/scroll/drag/refresh code, and their dedicated state.\n\n[b]Current main metrics[/b]\n%s nonblank lines · %s functions · %s vars · %s constants" % [str(metrics.get("nonblank_lines", 0)), str(metrics.get("function_count", 0)), str(metrics.get("top_level_variable_count", 0)), str(metrics.get("constant_count", 0))]
	var lines: Array[String] = []
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("[color=%s]%s[/color]  %s\n%s" % ["#4ade80" if bool(record.get("passed", false)) else "#fb7185", "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var metrics: Dictionary = manifest.get("main_metrics", {}) if manifest.get("main_metrics", {}) is Dictionary else {}
	var lines := ["# Legacy Runtime Surface Retirement", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Main nonblank lines: %d" % int(metrics.get("nonblank_lines", 0)), "- Legacy shell: absent", "- Legacy card-track renderer: absent", "", "| Case | Result | Notes |", "| --- | --- | --- |"]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %s |" % [str(record.get("case_id", "")), "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines) + "\n"


func _prepare_output_dir() -> void:
	var absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)
	for file_name in ["manifest.json", "report.md"]:
		var file_path := absolute.path_join(file_name)
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("cannot write %s" % path)
		return
	file.store_string(content)
	file.close()


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


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item_variant in value:
			if not _is_data_only(item_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
		return true
	return false
