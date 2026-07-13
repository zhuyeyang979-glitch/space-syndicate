extends Control
class_name CompendiumCodexInteractionBench

const OUTPUT_DIR := "user://space_syndicate_design_qa/compendium_codex/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/compendium_codex_sprint_1.png"
const PREVIEW_SCENE := preload("res://scenes/tools/CompendiumCodexMcpPreview.tscn")
const FIXTURES_SCRIPT := preload("res://scripts/tools/compendium_codex_mcp_preview_fixtures.gd")

@export var auto_run := true
@export var auto_quit_after_suite := false

@onready var status_label: Label = %CompendiumCodexInteractionStatusLabel
@onready var preview_host: Control = %CompendiumCodexInteractionPreviewHost
@onready var summary_label: Label = %CompendiumCodexInteractionSummaryLabel

var _suite_running := false


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_interaction_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func interaction_cases() -> Array:
	return [
		{"case_id": "filter_chip_signal", "fixture_id": "card_browser_grid", "interaction": "filter", "expected_signal": "filter_selected", "expected_value": "monster"},
		{"case_id": "page_previous_signal", "fixture_id": "card_browser_grid", "interaction": "page_previous", "expected_signal": "page_step_requested", "expected_value": "page_-1"},
		{"case_id": "thumbnail_preview_signal", "fixture_id": "card_browser_grid", "interaction": "thumbnail_preview", "expected_signal": "card_preview_requested", "expected_value": "phase_beast_i"},
		{"case_id": "thumbnail_detail_signal", "fixture_id": "card_browser_grid", "interaction": "thumbnail_detail", "expected_signal": "card_detail_requested", "expected_value": "phase_beast_i"},
		{"case_id": "product_long_text_layout", "fixture_id": "product_market_detail", "interaction": "layout", "expected_signal": "", "expected_value": "ProductCodexMarketKpiCard"},
		{"case_id": "bestiary_action_long_text_layout", "fixture_id": "monster_bestiary_detail", "interaction": "layout", "expected_signal": "", "expected_value": "BestiaryMonsterActionCard"},
		{"case_id": "empty_payload_safe_state", "fixture_id": "empty_payload_safe_state", "interaction": "empty", "expected_signal": "", "expected_value": "CompendiumCodexEmptyStateLayer"},
		{"case_id": "fixtures_are_pure_data", "fixture_id": "mixed_compendium_hub", "interaction": "pure_data", "expected_signal": "", "expected_value": "pure"},
		{"case_id": "privacy_sanitization", "fixture_id": "long_text_stress", "interaction": "privacy", "expected_signal": "", "expected_value": "sanitized"},
	]


func build_interaction_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_variant in interaction_cases():
		var case: Dictionary = case_variant if case_variant is Dictionary else {}
		records.append({
			"case_id": str(case.get("case_id", "")),
			"fixture_id": str(case.get("fixture_id", "")),
			"component": "",
			"interaction": str(case.get("interaction", "")),
			"emitted_signal": "",
			"emitted_value": "",
			"layout_checked": false,
			"privacy_checked": false,
			"pure_data_checked": false,
			"passed": false,
			"notes": "Preview manifest only; run_interaction_suite records live results.",
		})
	return {
		"suite": "compendium_codex_interactions",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"records": records,
	}


func run_interaction_suite() -> void:
	if _suite_running:
		return
	_suite_running = true
	_set_status("Running Compendium Codex interaction suite...")
	_prepare_output_dir()
	var preview := _ensure_preview()
	var records: Array = []
	var all_passed := preview != null
	if preview == null:
		push_error("CompendiumCodexInteractionBench could not instantiate CompendiumCodexMcpPreview.")
	else:
		for case_variant in interaction_cases():
			var case: Dictionary = case_variant if case_variant is Dictionary else {}
			var record := await _run_interaction_case(preview, case)
			records.append(record)
			all_passed = all_passed and bool(record.get("passed", false))
	var manifest := {
		"suite": "compendium_codex_interactions",
		"output_dir": OUTPUT_DIR,
		"preview_scene": "res://scenes/tools/CompendiumCodexMcpPreview.tscn",
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"passed_count": _passed_count(records),
		"records": records,
	}
	_write_text_file(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text_file(REPORT_PATH, _build_report(manifest))
	await _settle_frames(2)
	_write_screenshot()
	print("CompendiumCodexInteractionBench manifest: %s" % MANIFEST_PATH)
	print("CompendiumCodexInteractionBench report: %s" % REPORT_PATH)
	print("CompendiumCodexInteractionBench screenshot: %s" % SCREENSHOT_PATH)
	if all_passed:
		_set_status("Compendium codex interactions passed: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
	else:
		_set_status("Compendium codex interactions failed: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
		push_error("CompendiumCodexInteractionBench failed. See %s" % MANIFEST_PATH)
	_suite_running = false
	if auto_quit_after_suite:
		await get_tree().create_timer(0.25).timeout
		get_tree().quit(0 if all_passed else 1)


func _ensure_preview() -> Control:
	if preview_host == null:
		return null
	var existing := preview_host.find_child("CompendiumCodexMcpPreview", true, false) as Control
	if existing != null:
		return existing
	var preview := PREVIEW_SCENE.instantiate() as Control
	if preview == null:
		return null
	preview.name = "CompendiumCodexMcpPreview"
	preview_host.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return preview


func _run_interaction_case(preview: Control, case: Dictionary) -> Dictionary:
	var case_id := str(case.get("case_id", ""))
	var fixture_id := str(case.get("fixture_id", ""))
	var interaction := str(case.get("interaction", ""))
	var expected_value := str(case.get("expected_value", ""))
	_set_status("Running %s / %s..." % [case_id, fixture_id])
	var applied := bool(preview.call("apply_fixture", fixture_id)) if preview.has_method("apply_fixture") else false
	await _settle_frames(4)
	var emitted_signal := ""
	var emitted_value := ""
	var layout_checked := false
	var pure_data_checked := true
	var privacy_checked := _privacy_checked(preview)
	match interaction:
		"filter":
			var chip := _find_filter_chip(preview, expected_value)
			if chip != null:
				chip.emit_signal("pressed")
				await _settle_frames(2)
			emitted_signal = "filter_selected"
			var action_ids: Array = preview.call("last_action_ids") if preview.has_method("last_action_ids") else []
			emitted_value = str(action_ids.back()) if not action_ids.is_empty() else ""
			layout_checked = chip != null
		"page_previous":
			var previous := preview.find_child("CardCodexThumbnailPreviousButton", true, false) as Button
			if previous != null:
				previous.emit_signal("pressed")
				await _settle_frames(2)
			emitted_signal = "page_step_requested"
			var action_ids: Array = preview.call("last_action_ids") if preview.has_method("last_action_ids") else []
			emitted_value = str(action_ids.back()) if not action_ids.is_empty() else ""
			layout_checked = previous != null
		"thumbnail_preview":
			var thumb := preview.find_child("CardCodexThumbnailCard", true, false)
			if thumb != null and thumb.has_method("simulate_preview_for_test"):
				thumb.call("simulate_preview_for_test")
				await _settle_frames(2)
			emitted_signal = "card_preview_requested"
			var preview_cards: Array = preview.call("last_preview_cards") if preview.has_method("last_preview_cards") else []
			emitted_value = str(preview_cards.back()) if not preview_cards.is_empty() else ""
			layout_checked = thumb != null
		"thumbnail_detail":
			var thumb := preview.find_child("CardCodexThumbnailCard", true, false)
			if thumb != null and thumb.has_method("simulate_detail_for_test"):
				thumb.call("simulate_detail_for_test")
				await _settle_frames(2)
			emitted_signal = "card_detail_requested"
			var detail_cards: Array = preview.call("last_detail_cards") if preview.has_method("last_detail_cards") else []
			emitted_value = str(detail_cards.back()) if not detail_cards.is_empty() else ""
			layout_checked = thumb != null
		"layout":
			layout_checked = preview.find_child(expected_value, true, false) != null
			emitted_value = expected_value if layout_checked else ""
		"empty":
			layout_checked = preview.find_child(expected_value, true, false) != null
			emitted_value = expected_value if layout_checked else ""
		"pure_data":
			var fixtures := FIXTURES_SCRIPT.new()
			pure_data_checked = _all_fixtures_pure(fixtures)
			layout_checked = pure_data_checked
			emitted_value = "pure" if pure_data_checked else "impure"
		"privacy":
			layout_checked = true
			emitted_value = "sanitized" if privacy_checked else "leaked"
		_:
			layout_checked = false
	var value_ok := expected_value == "" or emitted_value == expected_value
	var passed := applied and layout_checked and privacy_checked and pure_data_checked and value_ok
	var notes := "interaction ok"
	if not passed:
		notes = "applied=%s layout=%s privacy=%s pure=%s emitted=%s expected=%s" % [str(applied), str(layout_checked), str(privacy_checked), str(pure_data_checked), emitted_value, expected_value]
	return {
		"case_id": case_id,
		"fixture_id": fixture_id,
		"component": _component_name(preview),
		"interaction": interaction,
		"emitted_signal": emitted_signal,
		"emitted_value": emitted_value,
		"layout_checked": layout_checked,
		"privacy_checked": privacy_checked,
		"pure_data_checked": pure_data_checked,
		"passed": passed,
		"notes": notes,
	}


func _component_name(preview: Control) -> String:
	if preview == null:
		return ""
	var component_markers := {
		"CardCodexBrowserPanel": "CardCodexBrowser",
		"CardCodexDetailPanel": "CardCodexDetail",
		"ProductCodexMarketBoardPanel": "ProductCodexDetail",
		"BestiaryMonsterBoardPanel": "BestiaryDetail",
		"CompendiumHubBoardPanel": "CompendiumHubBoard",
		"CompendiumCodexEmptyStateLayer": "CompendiumCodexEmptyStateLayer",
	}
	for node_name in component_markers.keys():
		var node := preview.find_child(str(node_name), true, false)
		if node != null:
			return str(component_markers[node_name])
	return ""


func _find_filter_chip(root_node: Node, filter_id: String) -> Button:
	if root_node == null:
		return null
	for node in root_node.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.has_method("filter_id") and str(button.call("filter_id")) == filter_id:
			return button
	return null


func _privacy_checked(root_node: Node) -> bool:
	var text := _node_tree_text(root_node).to_lower()
	for token in ["hidden_owner", "private_target", "private_discard"]:
		if text.contains(token):
			return false
	return true


func _all_fixtures_pure(fixtures: RefCounted) -> bool:
	for fixture_id in fixtures.call("fixture_ids"):
		var data: Dictionary = fixtures.call("fixture", str(fixture_id))
		if fixtures.has_method("is_pure_data") and not bool(fixtures.call("is_pure_data", data)):
			return false
	return true


func _node_tree_text(node: Node) -> String:
	if node == null:
		return ""
	var parts: Array[String] = [str(node.name)]
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	elif node is LineEdit:
		parts.append((node as LineEdit).text)
	for child in node.get_children():
		parts.append(_node_tree_text(child))
	return " ".join(parts)


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))


func _write_text_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write %s" % path)
		return
	file.store_string(text)
	file.close()


func _build_report(manifest: Dictionary) -> String:
	var lines: Array[String] = [
		"# Compendium Codex Interaction QA",
		"",
		"Output: `%s`" % OUTPUT_DIR,
		"Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"",
		"| Case | Fixture | Component | Passed | Notes |",
		"| --- | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | %s | %s | %s |" % [
			str(record.get("case_id", "")),
			str(record.get("fixture_id", "")),
			str(record.get("component", "")),
			str(record.get("passed", false)),
			str(record.get("notes", "")).replace("|", "/"),
		])
	return "\n".join(lines) + "\n"


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
	if summary_label != null:
		summary_label.text = text


func _write_screenshot() -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	image.save_png(SCREENSHOT_PATH)


func _settle_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await get_tree().process_frame
