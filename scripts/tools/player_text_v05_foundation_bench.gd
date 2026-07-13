extends Control
class_name PlayerTextV05FoundationBench

const PlayerTextSpecScript := preload("res://scripts/presentation/player_text_spec_v05.gd")
const VisibilityContractScript := preload("res://scripts/presentation/player_text_visibility_contract_v05.gd")
const ResolverScript := preload("res://scripts/presentation/player_text_locale_resolver_v05.gd")
const CatalogValidatorScript := preload("res://scripts/presentation/player_text_catalog_validator_v05.gd")
const GeneratedTextSanitizerScript := preload("res://scripts/presentation/player_generated_text_sanitizer_v05.gd")

const TEXT_CATALOG_PATH := "res://resources/localization/player_text_schema_v05.tres"
const UNIT_CATALOG_PATH := "res://resources/localization/unit_display_catalog_v05.tres"
const TRANSLATION_PATH := "res://localization/v05/player_text_zh_Hans.po"
const MIGRATION_REGISTRY_PATH := "res://resources/migrations/card_text_v04_to_v05_registry.tres"
const V05_CARD_CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v05.tres"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const RULESET_BRIDGE_SCRIPT_PATH := "res://scripts/runtime/ruleset_runtime_bridge.gd"
const CARD_CATALOG_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_runtime_catalog_service.gd"
const SAVE_COORDINATOR_SCRIPT_PATH := "res://scripts/runtime/game_save_runtime_coordinator.gd"
const EXPECTED_MAIN_SHA256 := "6BD3F293EC2E92AEB81A39C80266314BE6A308D2C03ECD58FD8DB22958CAE699"
const EXPECTED_MAIN_TOTAL_LINES := 22867
const EXPECTED_MAIN_NONBLANK_LINES := 20209
const EXPECTED_MAIN_FUNCTIONS := 1285
const OUTPUT_DIR := "user://space_syndicate_design_qa/player_text_v05_foundation/"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/player_text_v05_foundation_sprint_1.png"

const CASE_IDS := [
	"schema_resource_loads",
	"unit_catalog_loads",
	"catalog_validator_passes",
	"valid_player_visible_spec",
	"valid_player_assistive_spec",
	"valid_player_generated_spec",
	"machine_identifier_release_rejected",
	"developer_diagnostic_release_rejected",
	"translator_metadata_release_rejected",
	"unknown_audience_rejected",
	"non_pure_args_rejected",
	"unexpected_spec_field_rejected",
	"public_player_allowed",
	"public_spectator_allowed",
	"private_owner_allowed",
	"private_other_denied",
	"private_spectator_denied",
	"endgame_before_denied",
	"endgame_after_allowed",
	"spectator_sanitized_allowed",
	"spectator_unsanitized_denied",
	"developer_only_nondeveloper_denied",
	"developer_only_dev_allowed",
	"visibility_before_localization",
	"hidden_extra_arg_rejected",
	"denied_payload_not_resolved",
	"default_zh_hans_resolves",
	"assistive_key_resolves",
	"typed_integer_formats",
	"currency_cents_formats",
	"basis_points_formats",
	"seconds_formats",
	"gdp_per_minute_formats",
	"localized_term_formats",
	"missing_argument_rejected",
	"wrong_argument_type_rejected",
	"unknown_key_safe_fallback",
	"safe_fallback_hides_raw_key",
	"locale_reresolves_snapshot",
	"pseudolocalization_expands_50_percent",
	"pseudolocalization_preserves_placeholder",
	"raw_card_id_rejected",
	"raw_action_id_rejected",
	"raw_error_rejected",
	"node_path_and_stack_rejected",
	"player_generated_sanitized_and_limited",
	"registry_239_blocked_and_stable_ids",
	"production_v04_unchanged_and_pure_data",
]

@export var auto_run: bool = true
var _last_manifest: Dictionary = {}

@onready var summary_label: Label = $Margin/Layout/SummaryLabel
@onready var status_label: Label = $Margin/Layout/StatusLabel
@onready var case_list: RichTextLabel = $Margin/Layout/CaseList
@onready var output_label: Label = $Margin/Layout/OutputLabel


func _ready() -> void:
	if auto_run:
		call_deferred("run_foundation_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func foundation_cases() -> Array:
	return CASE_IDS.duplicate()


func build_foundation_manifest_preview() -> Dictionary:
	var records: Array[Dictionary] = []
	for case_id_variant in CASE_IDS:
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite_id": "player_text_v05_foundation",
		"ruleset_id": "v0.5",
		"runtime_active": false,
		"record_count": records.size(),
		"records": records,
	}


func run_foundation_suite() -> void:
	status_label.text = "Running SS05-01A text foundation checks..."
	var records := _evaluate_cases()
	var passed_count := 0
	for record in records:
		if bool(record.get("passed", false)):
			passed_count += 1
	_last_manifest = {
		"suite_id": "player_text_v05_foundation",
		"ruleset_id": "v0.5",
		"runtime_active": false,
		"production_runtime_ruleset": "v0.4",
		"record_count": records.size(),
		"passed_count": passed_count,
		"failed_count": records.size() - passed_count,
		"records": records,
	}
	_update_ui(records, passed_count)
	_write_outputs(_last_manifest)
	await get_tree().process_frame
	_capture_screenshot()
	print("PlayerTextV05FoundationBench: %d/%d passed" % [passed_count, records.size()])
	print("PlayerTextV05FoundationBench manifest: %smanifest.json" % OUTPUT_DIR)
	print("PlayerTextV05FoundationBench report: %sreport.md" % OUTPUT_DIR)
	if passed_count != records.size() or records.size() != 48:
		push_error("PlayerTextV05FoundationBench failed: %d/%d" % [passed_count, records.size()])


func debug_snapshot() -> Dictionary:
	return _last_manifest.duplicate(true)


func _evaluate_cases() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var catalog: Resource = load(TEXT_CATALOG_PATH)
	var unit_catalog: Resource = load(UNIT_CATALOG_PATH)
	var resolver: RefCounted = ResolverScript.new()
	var catalog_validation: Dictionary = CatalogValidatorScript.validate(catalog)
	records.append(_record("schema_resource_loads", catalog != null and ResourceLoader.exists(TRANSLATION_PATH), "schema and zh_Hans PO load"))
	records.append(_record("unit_catalog_loads", unit_catalog != null and (unit_catalog.debug_snapshot().get("entries", []) as Array).size() == 4, "four canonical units"))
	records.append(_record("catalog_validator_passes", bool(catalog_validation.get("valid", false)), str(catalog_validation.get("errors", []))))

	var visible_spec := _status_spec("public")
	var assistive_spec := _spec("ui.error.generic_safe.a11y", "player_assistive", "public", {}, -1, false)
	var generated_result: Dictionary = GeneratedTextSanitizerScript.sanitize("Pilot [b]One[/b]", 32)
	var generated_spec := _spec("ui.player_generated.value", "player_generated", "public", {"text": str(generated_result.get("sanitized_text", ""))}, -1, true)
	records.append(_validation_record("valid_player_visible_spec", visible_spec, catalog, true, true))
	records.append(_validation_record("valid_player_assistive_spec", assistive_spec, catalog, true, true))
	records.append(_validation_record("valid_player_generated_spec", generated_spec, catalog, true, true))
	records.append(_validation_record("machine_identifier_release_rejected", _spec("internal.card.identifier", "machine_identifier", "developer_only"), catalog, true, false))
	records.append(_validation_record("developer_diagnostic_release_rejected", _spec("debug.raw.error", "developer_diagnostic", "developer_only"), catalog, true, false))
	records.append(_validation_record("translator_metadata_release_rejected", _spec("translator.note.placeholder", "translator_metadata", "developer_only"), catalog, true, false))
	var unknown_audience := visible_spec.duplicate(true)
	unknown_audience["audience"] = "qa_unknown"
	records.append(_validation_record("unknown_audience_rejected", unknown_audience, catalog, true, false))
	var object_arg := visible_spec.duplicate(true)
	object_arg["args"] = {"status": Node.new()}
	records.append(_validation_record("non_pure_args_rejected", object_arg, catalog, true, false))
	(object_arg["args"] as Dictionary)["status"].free()
	var extra_field := visible_spec.duplicate(true)
	extra_field["hidden_owner"] = 2
	records.append(_validation_record("unexpected_spec_field_rejected", extra_field, catalog, true, false))

	records.append(_authorization_record("public_player_allowed", visible_spec, _viewer(0), true))
	records.append(_authorization_record("public_spectator_allowed", visible_spec, _viewer(-1, true), true))
	var private_spec := _status_spec("viewer_private", 1)
	records.append(_authorization_record("private_owner_allowed", private_spec, _viewer(1), true))
	records.append(_authorization_record("private_other_denied", private_spec, _viewer(2), false))
	records.append(_authorization_record("private_spectator_denied", private_spec, _viewer(-1, true), false))
	var endgame_spec := _status_spec("revealed_at_endgame")
	records.append(_authorization_record("endgame_before_denied", endgame_spec, _viewer(0), false))
	records.append(_authorization_record("endgame_after_allowed", endgame_spec, _viewer(0, false, true), true))
	var spectator_spec := _status_spec("spectator_sanitized", -1, true)
	records.append(_authorization_record("spectator_sanitized_allowed", spectator_spec, _viewer(-1, true), true))
	var unsafe_spectator_spec := _status_spec("spectator_sanitized", -1, false)
	records.append(_authorization_record("spectator_unsanitized_denied", unsafe_spectator_spec, _viewer(-1, true), false))
	var developer_spec := _status_spec("developer_only")
	records.append(_authorization_record("developer_only_nondeveloper_denied", developer_spec, _viewer(0), false))
	records.append(_authorization_record("developer_only_dev_allowed", developer_spec, _viewer(0, false, false, true), true))
	var private_resolution: Dictionary = resolver.resolve(private_spec, _viewer(2), catalog, unit_catalog)
	records.append(_record("visibility_before_localization", not bool(private_resolution.get("visible", true)) and str(private_resolution.get("text", "")).is_empty(), "unauthorized text is never composed", "player_visible", "viewer_private", false, "ui.qa.status"))
	var hidden_arg_spec := visible_spec.duplicate(true)
	hidden_arg_spec["args"] = {"status": "READY", "hidden_owner": 2}
	records.append(_validation_record("hidden_extra_arg_rejected", hidden_arg_spec, catalog, true, false))
	var denied_resolution: Dictionary = resolver.resolve(_status_spec("viewer_private", 4, true, "SECRET"), _viewer(0), catalog, unit_catalog)
	records.append(_record("denied_payload_not_resolved", not bool(denied_resolution.get("visible", true)) and not str(denied_resolution.get("text", "")).contains("SECRET"), "denied payload has no fallback text", "player_visible", "viewer_private", false, "ui.qa.status"))

	var public_resolution: Dictionary = resolver.resolve(visible_spec, _viewer(0), catalog, unit_catalog)
	records.append(_record("default_zh_hans_resolves", bool(public_resolution.get("visible", false)) and str(public_resolution.get("text", "")).contains("状态"), str(public_resolution.get("text", ""))))
	var blocked_spec := _spec("ui.card.play.blocked.industry_capacity", "player_visible", "viewer_private", {"industry_name": "term.industry.industry", "required_capacity": 3, "current_capacity": 1}, 0)
	var blocked_resolution: Dictionary = resolver.resolve(blocked_spec, _viewer(0), catalog, unit_catalog)
	records.append(_record("assistive_key_resolves", str(blocked_resolution.get("assistive_text", "")).contains("当前产能"), str(blocked_resolution.get("assistive_text", "")), "player_assistive", "viewer_private", true, "ui.card.play.blocked.industry_capacity.a11y"))
	records.append(_record("typed_integer_formats", str(blocked_resolution.get("text", "")).contains("3") and str(blocked_resolution.get("text", "")).contains("1"), str(blocked_resolution.get("text", ""))))
	var currency_resolution := _resolve_value(resolver, catalog, unit_catalog, "ui.qa.currency_amount", "amount", 12345)
	records.append(_record("currency_cents_formats", str(currency_resolution.get("text", "")).contains("123.45 资金"), str(currency_resolution.get("text", ""))))
	var influence_resolution := _resolve_value(resolver, catalog, unit_catalog, "ui.qa.influence", "influence", 3050)
	records.append(_record("basis_points_formats", str(influence_resolution.get("text", "")).contains("30.50%"), str(influence_resolution.get("text", ""))))
	var seconds_resolution := _resolve_value(resolver, catalog, unit_catalog, "ui.qa.duration", "duration", 8)
	records.append(_record("seconds_formats", str(seconds_resolution.get("text", "")).contains("8秒"), str(seconds_resolution.get("text", ""))))
	var gdp_resolution := _resolve_value(resolver, catalog, unit_catalog, "ui.qa.gdp_rate", "rate", 60)
	records.append(_record("gdp_per_minute_formats", str(gdp_resolution.get("text", "")).contains("60 GDP/min"), str(gdp_resolution.get("text", ""))))
	records.append(_record("localized_term_formats", str(blocked_resolution.get("text", "")).contains("工业产业"), str(blocked_resolution.get("text", ""))))
	var missing_arg := blocked_spec.duplicate(true)
	(missing_arg["args"] as Dictionary).erase("current_capacity")
	records.append(_validation_record("missing_argument_rejected", missing_arg, catalog, true, false))
	var wrong_type := blocked_spec.duplicate(true)
	(wrong_type["args"] as Dictionary)["required_capacity"] = 3.5
	records.append(_validation_record("wrong_argument_type_rejected", wrong_type, catalog, true, false))
	var unknown_key_spec := visible_spec.duplicate(true)
	unknown_key_spec["message_key"] = "ui.unknown.private_identifier"
	var unknown_resolution: Dictionary = resolver.resolve(unknown_key_spec, _viewer(0), catalog, unit_catalog)
	records.append(_record("unknown_key_safe_fallback", bool(unknown_resolution.get("used_safe_fallback", false)) and str(unknown_resolution.get("text", "")).contains("暂时无法显示"), str(unknown_resolution.get("diagnostic_code", ""))))
	records.append(_record("safe_fallback_hides_raw_key", not str(unknown_resolution.get("text", "")).contains("ui.unknown") and not str(unknown_resolution.get("assistive_text", "")).contains("ui.unknown"), "raw key remains diagnostic-only"))
	var locale_before := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var rerendered: Dictionary = resolver.resolve(visible_spec, _viewer(0), catalog, unit_catalog, "zh_Hans")
	var locale_restored := TranslationServer.get_locale() == "en"
	TranslationServer.set_locale(locale_before)
	records.append(_record("locale_reresolves_snapshot", locale_restored and str(rerendered.get("text", "")).contains("状态"), "resolver restores the caller locale"))
	var pseudo_source := "Amount {amount}"
	var pseudo_text := str(resolver.pseudolocalize_for_qa(pseudo_source, 0.5))
	records.append(_record("pseudolocalization_expands_50_percent", pseudo_text.length() >= ceili(float(pseudo_source.length()) * 1.5), pseudo_text))
	records.append(_record("pseudolocalization_preserves_placeholder", pseudo_text.contains("{amount}"), pseudo_text))
	records.append(_forbidden_arg_record("raw_card_id_rejected", "card_id", "card.city_financing.rank_1", catalog))
	records.append(_forbidden_arg_record("raw_action_id_rejected", "action_id", "play_card", catalog))
	records.append(_forbidden_arg_record("raw_error_rejected", "error", "Invalid node /root/Main", catalog))
	var path_stack_spec := visible_spec.duplicate(true)
	path_stack_spec["args"] = {"status": "READY", "node_path": "/root/Main", "stack_trace": "frame 1"}
	records.append(_validation_record("node_path_and_stack_rejected", path_stack_spec, catalog, true, false))
	var generated_resolution: Dictionary = resolver.resolve(generated_spec, _viewer(0), catalog, unit_catalog)
	var sanitized_text := str(generated_result.get("sanitized_text", ""))
	var generated_ok: bool = bool(generated_result.get("valid", false)) and sanitized_text.length() <= 32 and not sanitized_text.contains("[b]") and str(generated_resolution.get("text", "")) == sanitized_text
	records.append(_record("player_generated_sanitized_and_limited", generated_ok, sanitized_text, "player_generated", "public", true, "ui.player_generated.value"))

	var registry: Resource = load(MIGRATION_REGISTRY_PATH)
	var registry_validation: Dictionary = registry.validation_snapshot() if registry != null else {"valid": false}
	var v05_catalog: Resource = load(V05_CARD_CATALOG_PATH)
	var stable_v05_ids: bool = v05_catalog != null
	if v05_catalog != null:
		for card_id_variant in v05_catalog.card_ids():
			stable_v05_ids = stable_v05_ids and PlayerTextSpecScript.is_stable_ascii_id(str(card_id_variant))
	var release_ready_ids: Array = v05_catalog.get("release_ready_card_ids") as Array if v05_catalog != null else []
	var public_pool_ids: Array = v05_catalog.get("public_pool_card_ids") as Array if v05_catalog != null else []
	var registry_ok: bool = bool(registry_validation.get("valid", false)) and int(registry_validation.get("entry_count", 0)) == 239 and int(registry_validation.get("blocked_count", 0)) == 239 and int(registry_validation.get("release_ready_count", -1)) == 0 and int(registry_validation.get("stable_id_count", 0)) == 5 and stable_v05_ids and release_ready_ids.is_empty() and public_pool_ids.is_empty()
	records.append(_record("registry_239_blocked_and_stable_ids", registry_ok, "239 blocked; 5 reviewed stable IDs; 0 release-ready"))
	var main_metrics := _source_metrics(MAIN_SCRIPT_PATH)
	var bridge_source := _read_text(RULESET_BRIDGE_SCRIPT_PATH)
	var catalog_service_source := _read_text(CARD_CATALOG_SERVICE_SCRIPT_PATH)
	var save_source := _read_text(SAVE_COORDINATOR_SCRIPT_PATH)
	var production_unchanged: bool = str(main_metrics.get("sha256", "")) == EXPECTED_MAIN_SHA256 and int(main_metrics.get("total_lines", 0)) == EXPECTED_MAIN_TOTAL_LINES and int(main_metrics.get("nonblank_lines", 0)) == EXPECTED_MAIN_NONBLANK_LINES and int(main_metrics.get("functions", 0)) == EXPECTED_MAIN_FUNCTIONS and bridge_source.contains("space_syndicate_ruleset_v04.tres") and not bridge_source.contains("space_syndicate_ruleset_v05.tres") and catalog_service_source.contains("card_runtime_catalog_v04.tres") and not catalog_service_source.contains("card_runtime_catalog_v05.tres") and save_source.contains("const CURRENT_SAVE_VERSION := 1") and not _read_text(MAIN_SCRIPT_PATH).contains("PlayerTextV05")
	var pure_outputs: bool = PlayerTextSpecScript.is_pure_data(catalog.debug_snapshot()) and PlayerTextSpecScript.is_pure_data(unit_catalog.debug_snapshot()) and PlayerTextSpecScript.is_pure_data(registry.debug_snapshot()) and PlayerTextSpecScript.is_pure_data(public_resolution)
	records.append(_record("production_v04_unchanged_and_pure_data", production_unchanged and pure_outputs, "%s; runtime text owner inactive" % str(main_metrics), "developer_diagnostic", "developer_only", true))
	return records


func _spec(message_key: String, audience: String, scope: String, args: Dictionary = {}, viewer_index: int = -1, sanitized: bool = false) -> Dictionary:
	return {
		"message_key": message_key,
		"args": args.duplicate(true),
		"audience": audience,
		"visibility_scope": scope,
		"viewer_index": viewer_index,
		"surface": "status",
		"severity": "informational",
		"assistive_message_key": "",
		"developer_event_code": "QA_PLAYER_TEXT_FOUNDATION",
		"sanitized": sanitized,
	}


func _status_spec(scope: String, viewer_index: int = -1, sanitized: bool = false, status: String = "READY") -> Dictionary:
	return _spec("ui.qa.status", "player_visible", scope, {"status": status}, viewer_index, sanitized)


func _viewer(viewer_index: int, spectator: bool = false, endgame: bool = false, developer: bool = false) -> Dictionary:
	return {
		"viewer_index": viewer_index,
		"is_spectator": spectator,
		"endgame_reveal": endgame,
		"developer_mode": developer,
	}


func _validation_record(case_id: String, spec: Dictionary, catalog: Resource, release_mode: bool, expected_valid: bool) -> Dictionary:
	var validation: Dictionary = PlayerTextSpecScript.validate_spec(spec, catalog, release_mode)
	return _record(case_id, bool(validation.get("valid", false)) == expected_valid, str(validation.get("errors", [])), str(spec.get("audience", "")), str(spec.get("visibility_scope", "")), false, str(spec.get("message_key", "")))


func _authorization_record(case_id: String, spec: Dictionary, viewer: Dictionary, expected_allowed: bool) -> Dictionary:
	var authorization: Dictionary = VisibilityContractScript.authorize(spec, viewer)
	return _record(case_id, bool(authorization.get("allowed", false)) == expected_allowed, str(authorization.get("reason", "")), str(spec.get("audience", "")), str(spec.get("visibility_scope", "")), bool(authorization.get("allowed", false)), str(spec.get("message_key", "")))


func _resolve_value(resolver: RefCounted, catalog: Resource, unit_catalog: Resource, message_key: String, arg_key: String, value: int) -> Dictionary:
	return resolver.call("resolve", _spec(message_key, "player_visible", "public", {arg_key: value}), _viewer(0), catalog, unit_catalog, "zh_Hans", true)


func _forbidden_arg_record(case_id: String, arg_key: String, value: Variant, catalog: Resource) -> Dictionary:
	var spec := _status_spec("public")
	(spec["args"] as Dictionary)[arg_key] = value
	return _validation_record(case_id, spec, catalog, true, false)


func _record(case_id: String, passed: bool, notes: String, audience: String = "player_visible", visibility_scope: String = "public", authorized: bool = true, message_key: String = "") -> Dictionary:
	return {
		"case_id": case_id,
		"audience": audience,
		"visibility_scope": visibility_scope,
		"authorized": authorized,
		"message_key": message_key,
		"privacy_checked": true,
		"pure_data_checked": true,
		"passed": passed,
		"notes": notes,
	}


func _source_metrics(path: String) -> Dictionary:
	var source := _read_text(path)
	var lines := source.split("\n", true)
	if not lines.is_empty() and lines[lines.size() - 1].is_empty():
		lines.remove_at(lines.size() - 1)
	var nonblank_lines := 0
	var functions := 0
	for line in lines:
		if not line.strip_edges().is_empty():
			nonblank_lines += 1
		if line.begins_with("func "):
			functions += 1
	return {
		"sha256": _file_sha256(path),
		"total_lines": lines.size(),
		"nonblank_lines": nonblank_lines,
		"functions": functions,
	}


func _file_sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(file.get_buffer(file.get_length()))
	file.close()
	return context.finish().hex_encode().to_upper()


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


func _update_ui(records: Array[Dictionary], passed_count: int) -> void:
	summary_label.text = "SS05-01A Player Text  %d / %d" % [passed_count, records.size()]
	status_label.text = "PASS - RUNTIME INACTIVE" if passed_count == records.size() and records.size() == 48 else "REVIEW REQUIRED"
	status_label.modulate = Color("7ddf9b") if passed_count == records.size() and records.size() == 48 else Color("ff8f83")
	var lines: Array[String] = []
	for record in records:
		lines.append("[color=%s]%s[/color]  %s  [color=#8da0b8]%s[/color]" % ["#7ddf9b" if bool(record.passed) else "#ff8f83", "PASS" if bool(record.passed) else "FAIL", str(record.case_id), str(record.visibility_scope)])
	case_list.text = "\n".join(lines)
	output_label.text = "%smanifest.json  |  report.md" % OUTPUT_DIR


func _write_outputs(manifest: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var manifest_file := FileAccess.open("%smanifest.json" % OUTPUT_DIR, FileAccess.WRITE)
	if manifest_file != null:
		manifest_file.store_string(JSON.stringify(manifest, "\t", false))
		manifest_file.close()
	var report_lines: Array[String] = [
		"# Player-Facing Text v0.5 Foundation",
		"",
		"- Result: %d/%d passed" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"- Production runtime: v0.4 (unchanged)",
		"- v0.5 text role: authoring and QA foundation; runtime inactive",
		"- Card migration registry: 239 blocked, 5 proposed stable IDs, 0 release-ready",
		"",
		"| Case | Audience | Visibility | Result | Notes |",
		"| --- | --- | --- | --- | --- |",
	]
	for record in manifest.get("records", []):
		report_lines.append("| %s | %s | %s | %s | %s |" % [str(record.case_id), str(record.audience), str(record.visibility_scope), "PASS" if bool(record.passed) else "FAIL", str(record.notes).replace("|", "\\|")])
	var report_file := FileAccess.open("%sreport.md" % OUTPUT_DIR, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string("\n".join(report_lines))
		report_file.close()


func _capture_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return
	var result := image.save_png(SCREENSHOT_PATH)
	if result != OK:
		push_warning("PlayerTextV05FoundationBench screenshot failed: %s" % error_string(result))
