extends Control
class_name PlanetMapRenderCutoverBench

const OUTPUT_DIR := "user://space_syndicate_design_qa/planet_map_render_cutover/"
const PREVIEW_SCENE := preload("res://scenes/tools/PlanetMapMcpPreview.tscn")

@export var auto_run := true
@export var auto_quit_after_suite := false

@onready var status_label: Label = %CutoverBenchStatusLabel
@onready var preview_host: Control = %CutoverBenchPreviewHost

var _suite_running := false
var _last_manifest := {}


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_cutover_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func cutover_cases() -> Array:
	return [
		{"fixture_id": "globe_overview", "variant": "sceneized_base"},
		{"fixture_id": "selected_district", "variant": "sceneized_selection"},
		{"fixture_id": "local_zoom", "variant": "sceneized_local"},
		{"fixture_id": "underlay_guides", "variant": "sceneized_underlay"},
		{"fixture_id": "event_effects", "variant": "sceneized_feedback"},
		{"fixture_id": "render_cutover", "variant": "sceneized_cutover"},
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_variant in cutover_cases():
		var case: Dictionary = case_variant if case_variant is Dictionary else {}
		records.append({
			"fixture_id": str(case.get("fixture_id", "")),
			"variant": str(case.get("variant", "")),
			"sceneized_visual_cutover_enabled": true,
			"legacy_draw_fallback_used": false,
			"scale_hint_sceneized": true,
			"underlay_visible": true,
			"feedback_checked": str(case.get("fixture_id", "")) in ["underlay_guides", "event_effects", "render_cutover"],
			"signals_compatible": true,
			"methods_compatible": true,
			"passed": false,
			"notes": "Preview manifest only; run_cutover_suite records live results.",
		})
	return {
		"suite": "planet_map_render_cutover",
		"output_dir": OUTPUT_DIR,
		"records": records,
	}


func run_cutover_suite() -> void:
	if _suite_running:
		return
	_suite_running = true
	_set_status("Running PlanetMap render cutover suite...")
	var preview := _ensure_preview()
	var records: Array = []
	var all_passed := preview != null
	if preview == null:
		push_error("PlanetMapRenderCutoverBench could not instantiate PlanetMapMcpPreview.")
	else:
		for case_variant in cutover_cases():
			var case: Dictionary = case_variant if case_variant is Dictionary else {}
			var record := await _run_cutover_case(preview, case)
			records.append(record)
			all_passed = all_passed and bool(record.get("passed", false))
	var manifest := {
		"suite": "planet_map_render_cutover",
		"output_dir": OUTPUT_DIR,
		"record_count": records.size(),
		"passed_count": _passed_count(records),
		"records": records,
	}
	_last_manifest = manifest
	var paths := _write_outputs(manifest)
	var manifest_path := str(paths.get("manifest", "%smanifest.json" % OUTPUT_DIR))
	var report_path := str(paths.get("report", "%sreport.md" % OUTPUT_DIR))
	print("PlanetMapRenderCutoverBench manifest: %s" % manifest_path)
	print("PlanetMapRenderCutoverBench report: %s" % report_path)
	if all_passed:
		_set_status("Render cutover passed: %d/%d | %s" % [_passed_count(records), records.size(), manifest_path])
	else:
		_set_status("Render cutover failed: %d/%d | %s" % [_passed_count(records), records.size(), manifest_path])
		push_error("PlanetMapRenderCutoverBench failed. See %s" % manifest_path)
	_suite_running = false
	if auto_quit_after_suite:
		await get_tree().create_timer(0.25).timeout
		get_tree().quit(0 if all_passed else 1)


func _ensure_preview() -> Control:
	if preview_host == null:
		return null
	var existing := preview_host.find_child("PlanetMapMcpPreview", true, false) as Control
	if existing != null:
		return existing
	var preview := PREVIEW_SCENE.instantiate() as Control
	if preview == null:
		return null
	preview.name = "PlanetMapMcpPreview"
	preview_host.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return preview


func _run_cutover_case(preview: Control, case: Dictionary) -> Dictionary:
	var fixture_id := str(case.get("fixture_id", ""))
	var applied := bool(preview.call("apply_fixture", fixture_id)) if preview.has_method("apply_fixture") else false
	await get_tree().process_frame
	await get_tree().process_frame
	var snapshot_variant: Variant = preview.call("current_map_debug_snapshot") if preview.has_method("current_map_debug_snapshot") else {}
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var cutover_enabled := bool(snapshot.get("sceneized_visual_cutover_enabled", false))
	var legacy_used := bool(snapshot.get("legacy_draw_fallback_used", true))
	var scale_hint_sceneized := bool(snapshot.get("scale_hint_sceneized", false))
	var underlay_visible := bool(snapshot.get("globe_backdrop_sceneized", false)) and bool(snapshot.get("orbit_guide_sceneized", false)) and bool(snapshot.get("focus_range_overlay_sceneized", false))
	var feedback_checked := _feedback_surface_ok(fixture_id, snapshot)
	var map_view := _map_view(preview)
	var signals_compatible := map_view != null and map_view.has_signal("district_selected") and map_view.has_signal("district_double_clicked")
	var methods_compatible := map_view != null and map_view.has_method("set_map") and map_view.has_method("focus_district") and map_view.has_method("get_district_at_control_position")
	var passed := applied and cutover_enabled and not legacy_used and scale_hint_sceneized and underlay_visible and feedback_checked and signals_compatible and methods_compatible
	var notes := "sceneized render primary"
	if not passed:
		notes = "applied=%s cutover=%s legacy=%s scale=%s underlay=%s feedback=%s signals=%s methods=%s" % [
			str(applied),
			str(cutover_enabled),
			str(legacy_used),
			str(scale_hint_sceneized),
			str(underlay_visible),
			str(feedback_checked),
			str(signals_compatible),
			str(methods_compatible),
		]
	return {
		"fixture_id": fixture_id,
		"variant": str(case.get("variant", "")),
		"sceneized_visual_cutover_enabled": cutover_enabled,
		"legacy_draw_fallback_used": legacy_used,
		"scale_hint_sceneized": scale_hint_sceneized,
		"underlay_visible": underlay_visible,
		"feedback_checked": feedback_checked,
		"signals_compatible": signals_compatible,
		"methods_compatible": methods_compatible,
		"passed": passed,
		"notes": notes,
	}


func _map_view(preview: Control) -> Control:
	if preview == null:
		return null
	return preview.find_child("PlanetMapView", true, false) as Control


func _feedback_surface_ok(fixture_id: String, snapshot: Dictionary) -> bool:
	if fixture_id in ["underlay_guides", "event_effects", "render_cutover"]:
		return int(snapshot.get("movement_trail_count", 0)) > 0 \
			and int(snapshot.get("map_event_effect_count", 0)) > 0 \
			and int(snapshot.get("action_callout_count", 0)) > 0
	return int(snapshot.get("district_polygon_count", 0)) > 0 and int(snapshot.get("district_node_count", 0)) > 0


func _write_outputs(manifest: Dictionary) -> Dictionary:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var manifest_path := "%smanifest.json" % OUTPUT_DIR
	var report_path := "%sreport.md" % OUTPUT_DIR
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file != null:
		manifest_file.store_string(JSON.stringify(manifest, "\t"))
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(_build_report(manifest))
	return {"manifest": manifest_path, "report": report_path}


func _build_report(manifest: Dictionary) -> String:
	var lines := [
		"# Planet Map Render Cutover QA",
		"",
		"Output: `%s`" % OUTPUT_DIR,
		"",
		"| Fixture | Variant | Cutover | Legacy Fallback | Scale Hint | Underlay | Feedback | Signals | Methods | Passed | Notes |",
		"| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
	]
	var records: Array = manifest.get("records", []) if manifest.get("records", []) is Array else []
	for record_variant in records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % [
			str(record.get("fixture_id", "")),
			str(record.get("variant", "")),
			str(record.get("sceneized_visual_cutover_enabled", false)),
			str(record.get("legacy_draw_fallback_used", false)),
			str(record.get("scale_hint_sceneized", false)),
			str(record.get("underlay_visible", false)),
			str(record.get("feedback_checked", false)),
			str(record.get("signals_compatible", false)),
			str(record.get("methods_compatible", false)),
			str(record.get("passed", false)),
			str(record.get("notes", "")),
		])
	return "\n".join(lines)


func _passed_count(records: Array) -> int:
	var count := 0
	for record_variant in records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		if bool(record.get("passed", false)):
			count += 1
	return count


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
