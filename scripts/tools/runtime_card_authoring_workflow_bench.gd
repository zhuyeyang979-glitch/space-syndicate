extends Control
class_name RuntimeCardAuthoringWorkflowBench

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v04.tres"
const INTEGRITY_PATH := "res://tests/fixtures/runtime_card_catalog_v04_integrity.json"
const WORKSPACE_SCENE_PATH := "res://scenes/tools/RuntimeCardAuthoringWorkspace.tscn"
const INSPECTOR_PLUGIN_PATH := "res://addons/space_syndicate_design_qa/card_runtime_authoring_inspector_plugin.gd"
const INSPECTOR_PANEL_PATH := "res://addons/space_syndicate_design_qa/CardRuntimeAuthoringInspectorPanel.tscn"
const EDITOR_PLUGIN_PATH := "res://addons/space_syndicate_design_qa/space_syndicate_design_qa_plugin.gd"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/runtime_card_authoring/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/runtime_card_authoring_workflow_sprint_59.png"

const CASE_IDS := [
	"validator_script_loads",
	"change_review_script_loads",
	"authoring_service_script_loads",
	"catalog_resource_loads",
	"catalog_has_ten_packs",
	"catalog_has_120_families",
	"catalog_has_239_authored_cards",
	"output_is_user_scoped",
	"authoritative_catalog_validates",
	"all_49_kinds_remain_registered",
	"sample_family_validates",
	"sample_rank_validates",
	"duplicate_rank_is_blocked",
	"identity_mismatch_is_blocked",
	"unknown_kind_is_blocked",
	"runtime_field_is_blocked",
	"external_financial_field_is_blocked",
	"non_data_value_is_blocked",
	"approved_integrity_is_clean",
	"modified_card_is_detected",
	"added_card_is_detected",
	"removed_card_is_detected",
	"working_baseline_enables_field_diff",
	"catalog_order_change_is_detected",
	"derived_rank_impacts_are_reported",
	"consumer_review_checklist_is_complete",
	"baseline_writes_under_user",
	"change_review_json_writes",
	"change_review_markdown_writes",
	"workspace_scene_composition",
	"workspace_public_api",
	"inspector_plugin_loads",
	"inspector_panel_composition",
	"editor_plugin_registers_inspector",
	"manifest_and_review_are_pure_data",
	"runtime_catalog_ownership_is_unchanged",
]

@export var auto_run := true

@onready var workspace: RuntimeCardAuthoringWorkspace = %RuntimeCardAuthoringWorkspace
@onready var summary_label: Label = %AuthoringBenchSummaryLabel
@onready var status_label: Label = %AuthoringBenchStatusLabel
@onready var cases_text: RichTextLabel = %AuthoringBenchCasesText

var _service := CardRuntimeAuthoringService.new()
var _validator := CardRuntimeAuthoringValidator.new()
var _reviewer := CardRuntimeChangeReviewService.new()
var _catalog: CardRuntimeCatalogResource
var _integrity: Dictionary = {}
var _index: Dictionary = {}
var _current_snapshot: Dictionary = {}
var _sample_family: CardRuntimeFamilyResource
var _sample_rank: CardRuntimeRankResource
var _clean_review: Dictionary = {}
var _modified_review: Dictionary = {}
var _added_review: Dictionary = {}
var _removed_review: Dictionary = {}
var _baseline_review: Dictionary = {}
var _order_review: Dictionary = {}
var _validation: Dictionary = {}
var _baseline_result: Dictionary = {}
var _written_review: Dictionary = {}
var _records: Array = []
var _failures: Array[String] = []


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_authoring_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func authoring_cases() -> Array:
	return CASE_IDS.duplicate()


func build_authoring_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id in CASE_IDS:
		records.append(_record(str(case_id), false, "preview"))
	return {
		"suite": "runtime-card-authoring-workflow-sprint-59",
		"ruleset_id": "v0.4",
		"case_count": CASE_IDS.size(),
		"runtime_owner": "CardRuntimeCatalogService",
		"editor_only": true,
		"records": records,
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
	}


func run_authoring_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	if not _prepare_inputs():
		push_error("RuntimeCardAuthoringWorkflowBench could not load the authoritative catalog inputs.")
		await _quit_after_result(false)
		return
	for case_id in CASE_IDS:
		var passed := _case_pass(str(case_id))
		_records.append(_record(str(case_id), passed, _case_note(str(case_id), passed)))
		if not passed:
			_failures.append(str(case_id))
	var manifest := _manifest()
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "  ", false))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("RuntimeCardAuthoringWorkflowBench: %d/%d passed" % [_count_passed(), CASE_IDS.size()])
	print("RuntimeCardAuthoringWorkflowBench manifest: %s" % MANIFEST_PATH)
	print("RuntimeCardAuthoringWorkflowBench report: %s" % REPORT_PATH)
	print("RuntimeCardAuthoringWorkflowBench baseline: %s" % CardRuntimeAuthoringService.BASELINE_PATH)
	print("RuntimeCardAuthoringWorkflowBench change review: %s" % CardRuntimeAuthoringService.REVIEW_JSON_PATH)
	print("RuntimeCardAuthoringWorkflowBench screenshot: %s" % SCREENSHOT_PATH)
	if not _failures.is_empty():
		push_error("RuntimeCardAuthoringWorkflowBench failed: %s" % ", ".join(_failures))
	await _quit_after_result(_failures.is_empty())


func _prepare_inputs() -> bool:
	_catalog = load(CATALOG_PATH) as CardRuntimeCatalogResource
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INTEGRITY_PATH))
	_integrity = (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
	if _catalog == null or _integrity.is_empty():
		return false
	_service.configure()
	_index = _service.authoring_index()
	_validation = _service.validate_catalog()
	_current_snapshot = _reviewer.catalog_snapshot(_catalog)
	_find_sample_resources()
	_clean_review = _reviewer.compare_snapshots(_current_snapshot, {}, _integrity)
	_modified_review = _review_after_definition_change()
	_added_review = _review_after_added_card()
	_removed_review = _review_after_removed_card()
	_baseline_review = _review_after_definition_change(_current_snapshot)
	_order_review = _review_after_order_change()
	_baseline_result = _service.capture_baseline()
	_written_review = _service.build_change_review(true)
	return bool(_index.get("valid", false)) and _sample_family != null and _sample_rank != null


func _find_sample_resources() -> void:
	for pack_resource in _catalog.packs:
		var pack := pack_resource as CardRuntimePackResource
		if pack == null:
			continue
		for family_resource in pack.families:
			var family := family_resource as CardRuntimeFamilyResource
			if family == null or family.authored_ranks.is_empty():
				continue
			var rank_resource := family.authored_ranks[0] as CardRuntimeRankResource
			if rank_resource != null:
				_sample_family = family
				_sample_rank = rank_resource
				return


func _case_pass(case_id: String) -> bool:
	match case_id:
		"validator_script_loads": return load("res://scripts/cards/card_runtime_authoring_validator.gd") != null
		"change_review_script_loads": return load("res://scripts/cards/card_runtime_change_review_service.gd") != null
		"authoring_service_script_loads": return load("res://scripts/cards/card_runtime_authoring_service.gd") != null
		"catalog_resource_loads": return _catalog != null
		"catalog_has_ten_packs": return int(_index.get("pack_count", 0)) == 10
		"catalog_has_120_families": return int(_index.get("family_count", 0)) == 120
		"catalog_has_239_authored_cards": return int(_index.get("card_count", 0)) == 239
		"output_is_user_scoped": return OUTPUT_DIR.begins_with("user://") and not OUTPUT_DIR.contains("res://reports")
		"authoritative_catalog_validates": return bool(_validation.get("valid", false))
		"all_49_kinds_remain_registered": return int(_catalog.validation_report().get("kind_count", 0)) == 49
		"sample_family_validates": return bool(_validator.validate_family(_sample_family, _catalog).get("valid", false))
		"sample_rank_validates": return bool(_validator.validate_rank(_sample_rank, _sample_family, _catalog).get("valid", false))
		"duplicate_rank_is_blocked": return _duplicate_rank_is_blocked()
		"identity_mismatch_is_blocked": return _identity_mismatch_is_blocked()
		"unknown_kind_is_blocked": return _authored_field_is_blocked("kind", "authoring_unknown_kind", "kind_registered")
		"runtime_field_is_blocked": return _authored_field_is_blocked("owner", 2, "runtime_field:owner")
		"external_financial_field_is_blocked": return _authored_field_is_blocked("margin_cash", 100, "external_financial_field:margin_cash")
		"non_data_value_is_blocked": return _non_data_value_is_blocked()
		"approved_integrity_is_clean": return int(_clean_review.get("change_count", -1)) == 0 and str(_clean_review.get("review_status", "")) == "clean"
		"modified_card_is_detected": return int(_modified_review.get("changed_count", 0)) == 1
		"added_card_is_detected": return int(_added_review.get("added_count", 0)) == 1
		"removed_card_is_detected": return int(_removed_review.get("removed_count", 0)) == 1
		"working_baseline_enables_field_diff": return _first_field_change_count(_baseline_review) > 0
		"catalog_order_change_is_detected": return bool((_order_review.get("order_changes", {}) as Dictionary).get("catalog_order_changed", false))
		"derived_rank_impacts_are_reported": return not (_modified_review.get("derived_impacts", []) as Array).is_empty()
		"consumer_review_checklist_is_complete": return (_clean_review.get("consumer_review_checks", []) as Array).size() >= 9
		"baseline_writes_under_user": return bool(_baseline_result.get("captured", false)) and str(_baseline_result.get("path", "")).begins_with("user://") and FileAccess.file_exists(str(_baseline_result.get("path", "")))
		"change_review_json_writes": return str(_written_review.get("review_json_path", "")).begins_with("user://") and FileAccess.file_exists(str(_written_review.get("review_json_path", "")))
		"change_review_markdown_writes": return str(_written_review.get("review_markdown_path", "")).begins_with("user://") and FileAccess.file_exists(str(_written_review.get("review_markdown_path", "")))
		"workspace_scene_composition": return _workspace_scene_composition_ok()
		"workspace_public_api": return workspace != null and workspace.has_method("refresh_index") and workspace.has_method("select_family") and workspace.has_method("select_card") and workspace.has_method("validate_selected") and workspace.has_method("capture_baseline") and workspace.has_method("build_change_review") and workspace.has_method("debug_snapshot")
		"inspector_plugin_loads": return load(INSPECTOR_PLUGIN_PATH) != null
		"inspector_panel_composition": return _inspector_panel_composition_ok()
		"editor_plugin_registers_inspector": return _editor_plugin_registration_ok()
		"manifest_and_review_are_pure_data": return _is_data_only(build_authoring_manifest_preview()) and _is_data_only(_written_review)
		"runtime_catalog_ownership_is_unchanged": return _runtime_ownership_unchanged()
	return false


func _duplicate_rank_is_blocked() -> bool:
	var duplicate_family := _sample_family.duplicate(true) as CardRuntimeFamilyResource
	if duplicate_family == null:
		return false
	duplicate_family.authored_ranks.append(duplicate_family.authored_ranks[0])
	var report := _validator.validate_family(duplicate_family, _catalog)
	return not bool(report.get("valid", true)) and _report_has_check(report, "family_rank_numbers_unique")


func _identity_mismatch_is_blocked() -> bool:
	var altered := _sample_rank.duplicate(true) as CardRuntimeRankResource
	if altered == null:
		return false
	altered.card_id = "invalid_identity1"
	var report := _validator.validate_rank(altered, _sample_family, _catalog)
	return not bool(report.get("valid", true)) and _report_has_check(report, "card_id_matches_family_rank")


func _authored_field_is_blocked(field_name: String, value: Variant, expected_error: String) -> bool:
	var altered := _sample_rank.duplicate(true) as CardRuntimeRankResource
	if altered == null:
		return false
	if field_name == "kind":
		altered.kind = StringName(str(value))
	else:
		var keys := Array(altered.authored_keys)
		if not keys.has(field_name):
			keys.append(field_name)
		altered.authored_keys = PackedStringArray(keys)
		altered.effect_parameters = altered.effect_parameters.duplicate(true)
		altered.effect_parameters[field_name] = value
	var report := _validator.validate_rank(altered, _sample_family, _catalog)
	return not bool(report.get("valid", true)) and JSON.stringify(report).contains(expected_error)


func _non_data_value_is_blocked() -> bool:
	var probe := Node.new()
	var blocked := _authored_field_is_blocked("qa_probe", probe, "non_data_value:qa_probe")
	probe.free()
	return blocked


func _review_after_definition_change(baseline: Dictionary = {}) -> Dictionary:
	var changed := _current_snapshot.duplicate(true)
	var cards: Dictionary = (changed.get("cards", {}) as Dictionary).duplicate(true)
	var card_id := _first_card_id(cards)
	var card_record: Dictionary = (cards.get(card_id, {}) as Dictionary).duplicate(true)
	var definition: Dictionary = (card_record.get("definition", {}) as Dictionary).duplicate(true)
	definition["text"] = "%s [QA change]" % str(definition.get("text", ""))
	card_record["definition"] = definition
	card_record["definition_hash"] = _reviewer.definition_hash(definition)
	cards[card_id] = card_record
	changed["cards"] = cards
	return _reviewer.compare_snapshots(changed, baseline, _integrity)


func _review_after_added_card() -> Dictionary:
	var changed := _current_snapshot.duplicate(true)
	var cards: Dictionary = (changed.get("cards", {}) as Dictionary).duplicate(true)
	var definition := {"kind": "qa", "move": 0, "damage": 0, "text": "QA only", "range": 0, "cost": 0}
	cards["QA工作流1"] = {"card_id": "QA工作流1", "family_id": "QA工作流", "pack_id": "qa", "resource_path": "", "definition_hash": _reviewer.definition_hash(definition), "definition": definition}
	changed["cards"] = cards
	return _reviewer.compare_snapshots(changed, {}, _integrity)


func _review_after_removed_card() -> Dictionary:
	var changed := _current_snapshot.duplicate(true)
	var cards: Dictionary = (changed.get("cards", {}) as Dictionary).duplicate(true)
	cards.erase(_first_card_id(cards))
	changed["cards"] = cards
	return _reviewer.compare_snapshots(changed, {}, _integrity)


func _review_after_order_change() -> Dictionary:
	var changed := _current_snapshot.duplicate(true)
	changed["catalog_order_sha256"] = "qa-order-change"
	return _reviewer.compare_snapshots(changed, {}, _integrity)


func _first_card_id(cards: Dictionary) -> String:
	var ids: Array[String] = []
	for card_id_variant in cards:
		ids.append(str(card_id_variant))
	ids.sort()
	return ids[0] if not ids.is_empty() else ""


func _first_field_change_count(review: Dictionary) -> int:
	var changes: Array = review.get("changed_cards", []) if review.get("changed_cards", []) is Array else []
	if changes.is_empty() or not (changes[0] is Dictionary):
		return 0
	return ((changes[0] as Dictionary).get("field_changes", []) as Array).size()


func _report_has_check(report: Dictionary, check_id: String) -> bool:
	for check_variant in report.get("checks", []):
		var check: Dictionary = check_variant if check_variant is Dictionary else {}
		if str(check.get("check_id", "")) == check_id and not bool(check.get("passed", true)):
			return true
	return false


func _workspace_scene_composition_ok() -> bool:
	var packed := load(WORKSPACE_SCENE_PATH) as PackedScene
	if packed == null:
		return false
	var instance := packed.instantiate()
	var required := ["AuthoringPackOption", "AuthoringFamilyList", "AuthoringCardList", "AuthoringValidationOutput", "AuthoringReviewOutput", "CaptureAuthoringBaselineButton", "BuildAuthoringReviewButton"]
	var valid := true
	for node_name in required:
		valid = valid and instance.find_child(str(node_name), true, false) != null
	instance.free()
	return valid


func _inspector_panel_composition_ok() -> bool:
	var packed := load(INSPECTOR_PANEL_PATH) as PackedScene
	if packed == null:
		return false
	var instance := packed.instantiate()
	var required := ["ValidateAuthoringTargetButton", "CaptureCardBaselineButton", "BuildCardChangeReviewButton", "RunCardAuthoringQaButton", "OpenCardAuthoringCatalogButton", "OpenCardAuthoringOutputButton"]
	var valid := true
	for node_name in required:
		valid = valid and instance.find_child(str(node_name), true, false) != null
	instance.free()
	return valid


func _editor_plugin_registration_ok() -> bool:
	var source := FileAccess.get_file_as_string(EDITOR_PLUGIN_PATH)
	return source.contains("add_inspector_plugin") and source.contains("remove_inspector_plugin") and source.contains("card_runtime_authoring_inspector_plugin.gd")


func _runtime_ownership_unchanged() -> bool:
	var service_snapshot := _service.debug_snapshot()
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	return str(service_snapshot.get("runtime_owner_unchanged", "")) == "CardRuntimeCatalogService" and bool(service_snapshot.get("editor_only", false)) and not main_source.contains("CardRuntimeAuthoringService") and not coordinator_source.contains("CardRuntimeAuthoringService") and ResourceLoader.exists(MAIN_SCENE_PATH) and ResourceLoader.exists(COORDINATOR_SCENE_PATH)


func _record(case_id: String, passed: bool, notes: String) -> Dictionary:
	return {
		"case_id": case_id,
		"validator_checked": case_id.contains("valid") or case_id.contains("blocked") or case_id.contains("catalog"),
		"review_checked": case_id.contains("review") or case_id.contains("detected") or case_id.contains("baseline") or case_id.contains("impact"),
		"inspector_checked": case_id.contains("inspector") or case_id.contains("workspace") or case_id.contains("editor_plugin"),
		"pure_data_checked": case_id.contains("pure_data") or case_id.contains("ownership"),
		"passed": passed,
		"notes": notes,
	}


func _manifest() -> Dictionary:
	return {
		"suite": "runtime-card-authoring-workflow-sprint-59",
		"ruleset_id": "v0.4",
		"case_count": CASE_IDS.size(),
		"passed_count": _count_passed(),
		"runtime_owner": "CardRuntimeCatalogService",
		"editor_only": true,
		"catalog_path": CATALOG_PATH,
		"pack_count": int(_index.get("pack_count", 0)),
		"family_count": int(_index.get("family_count", 0)),
		"card_count": int(_index.get("card_count", 0)),
		"validation": _validation.duplicate(true),
		"change_review": _written_review.duplicate(true),
		"records": _records.duplicate(true),
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
	}


func _count_passed() -> int:
	var passed := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			passed += 1
	return passed


func _case_note(case_id: String, passed: bool) -> String:
	return "%s: %s" % ["Verified" if passed else "Failed", case_id.replace("_", " ")]


func _update_ui(manifest: Dictionary) -> void:
	summary_label.text = "239 cards | 120 families | 10 packs | %d/%d workflow checks" % [int(manifest.get("passed_count", 0)), CASE_IDS.size()]
	status_label.text = "PASS - Inspector authoring is review-gated" if _failures.is_empty() else "AUTHORING WORKFLOW FAILURE"
	var lines: Array[String] = []
	for record_variant in _records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("%s  %s" % ["PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("case_id", ""))])
	cases_text.text = "\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines: Array[String] = [
		"# Runtime Card Authoring Workflow - Sprint 59", "",
		"- Result: %d/%d" % [int(manifest.get("passed_count", 0)), CASE_IDS.size()],
		"- Runtime owner: `CardRuntimeCatalogService`",
		"- Authoring surface: Godot Inspector + RuntimeCardAuthoringWorkspace",
		"- Outputs: `user://space_syndicate_design_qa/runtime_card_authoring/`", "",
		"## Cases", "", "| Case | Passed | Notes |", "| --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | %s |" % [str(record.get("case_id", "")), str(record.get("passed", false)), str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines) + "\n"


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for file_name in ["manifest.json", "report.md", "change_review.json", "change_review.md", "working_baseline.json"]:
		var path := OUTPUT_DIR + str(file_name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("write:%s" % path)
		return
	file.store_string(content)
	file.close()


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_failures.append("screenshot_unavailable")
		return
	var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if image.save_png(absolute_path) != OK:
		_failures.append("screenshot_write")


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array or value is PackedStringArray:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName) or not _is_data_only(value[key]):
				return false
		return true
	return false


func _quit_after_result(success: bool) -> void:
	if DisplayServer.get_name() == "headless":
		for _frame in range(3):
			await get_tree().process_frame
		get_tree().quit(0 if success else 1)
	else:
		await get_tree().create_timer(12.0).timeout
		get_tree().quit(0 if success else 1)
