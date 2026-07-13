extends Control
class_name CardCodexPublicSnapshotCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const SERVICE_SCENE := "res://scenes/runtime/CardCodexPublicSnapshotService.tscn"
const SERVICE_SCRIPT := "res://scripts/runtime/card_codex_public_snapshot_service.gd"
const BROWSER_VIEWMODEL := "res://scripts/viewmodels/card_codex_browser_snapshot.gd"
const DETAIL_VIEWMODEL := "res://scripts/viewmodels/card_codex_detail_snapshot.gd"
const COORDINATOR_SCENE := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/card_codex_public_snapshot_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/card_codex_public_snapshot_cutover_sprint_17.png"

const RETIRED_FORMATTERS := [
	"_card_codex_grid_text", "_card_codex_browser_snapshot", "_card_codex_browser_filter_sources",
	"_card_codex_browser_card_sources", "_card_codex_browser_card_source", "_card_codex_browser_preview_source",
	"_card_codex_text", "_card_codex_tactical_timing_text", "_card_codex_tactical_combo_text",
	"_card_codex_tactical_clue_text", "_card_codex_tactical_entries", "_card_codex_detail_snapshot",
	"_card_codex_detail_source", "_card_codex_detail_card_face_snapshot", "_card_codex_detail_summary_snapshot",
	"_card_codex_detail_read_chips", "_card_codex_detail_fact_snapshots", "_card_codex_detail_upgrade_snapshots",
	"_card_codex_detail_resolution_snapshot",
]

@export var auto_run := true

@onready var status_label: Label = %StatusLabel
@onready var summary_label: Label = %SummaryLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var results_text: RichTextLabel = %ResultsText

var _service: Node
var _main: Control
var _main_source := ""
var _records: Array = []
var _failures: Array[String] = []
var _real_card_name := ""
var _real_card_names: Array = []


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_cutover_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func retired_formatter_names() -> Array:
	return RETIRED_FORMATTERS.duplicate()


func cutover_cases() -> Array:
	return [
		"required_service_assets_load", "service_scene_contract", "existing_viewmodels_reused", "card_source_pure_data",
		"browser_summary_contract", "browser_card_contract", "browser_filter_contract", "browser_preview_contract",
		"detail_summary_contract", "detail_card_face_contract", "detail_tactical_contract", "detail_fact_contract",
		"detail_upgrade_contract", "detail_resolution_contract", "empty_source_safe", "privacy_boundary",
		"coordinator_scene_composition", "coordinator_pure_data_proxy", "real_main_browser_and_detail_routes", "legacy_card_formatters_absent_and_metrics",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant: Variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite": "card-codex-public-snapshot-cutover-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"retired_formatter_count": RETIRED_FORMATTERS.size(),
		"records": records,
	}


func run_cutover_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	_main_source = FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	await _prepare_runtime()
	for case_id_variant: Variant in cutover_cases():
		var case_id := str(case_id_variant)
		var record := _run_case(case_id)
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "failed"))])
	var manifest := {
		"suite": "card-codex-public-snapshot-cutover-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": _records.size(),
		"passed_count": _passed_count(),
		"retired_formatter_count": RETIRED_FORMATTERS.size(),
		"main_metrics": _main_metrics(),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await _dispose_runtime()
	_save_screenshot()
	print("CardCodexPublicSnapshotCutoverBench manifest: %s" % MANIFEST_PATH)
	print("CardCodexPublicSnapshotCutoverBench report: %s" % REPORT_PATH)
	print("CardCodexPublicSnapshotCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("CardCodexPublicSnapshotCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("CardCodexPublicSnapshotCutoverBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func _prepare_runtime() -> void:
	var service_packed := load(SERVICE_SCENE) as PackedScene
	_service = service_packed.instantiate() if service_packed != null else null
	if _service != null:
		add_child(_service)
		_service.call("configure", {})
	var main_packed := load(MAIN_SCENE_PATH) as PackedScene
	_main = main_packed.instantiate() as Control if main_packed != null else null
	if _main != null:
		_main.visible = false
		add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	if _main != null and _main.has_method("_new_game"):
		_main.call("_new_game")
	await get_tree().process_frame
	await get_tree().process_frame
	if _main != null:
		_real_card_names = _main.call("_card_codex_names") as Array
		_real_card_name = str(_real_card_names[0]) if not _real_card_names.is_empty() else ""


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	match case_id:
		"required_service_assets_load":
			passed = load(SERVICE_SCRIPT) is Script and load(SERVICE_SCENE) is PackedScene and load(BROWSER_VIEWMODEL) is Script and load(DETAIL_VIEWMODEL) is Script and load(COORDINATOR_SCENE) is PackedScene
			flags["service_checked"] = true
			notes = "card service, existing ViewModels, and coordinator assets load"
		"service_scene_contract":
			var debug := _debug_snapshot()
			passed = _service != null and _service.has_method("configure") and _service.has_method("compose_browser") and _service.has_method("compose_detail") and _service.has_method("debug_snapshot")
			passed = passed and not bool(debug.get("calculates_card_price", true)) and not bool(debug.get("calculates_card_effects", true)) and not bool(debug.get("calculates_play_requirements", true)) and not bool(debug.get("reads_runtime_nodes", true))
			flags["service_checked"] = true
			flags["rule_boundary_checked"] = true
			notes = "service owns presentation only; card prices, effects, and legality remain domain-owned"
		"existing_viewmodels_reused":
			var debug := _debug_snapshot()
			passed = bool(debug.get("uses_existing_browser_viewmodel", false)) and bool(debug.get("uses_existing_detail_viewmodel", false))
			flags["service_checked"] = true
			notes = "scene service reuses both established Card Codex ViewModels"
		"card_source_pure_data":
			var source: Dictionary = _main.call("_card_codex_public_card_facts", _real_card_name, 0) if _main != null and _real_card_name != "" else {}
			passed = bool(source.get("valid", false)) and _is_pure_data(source) and not _contains_private_key(source)
			flags["main_checked"] = true
			flags["pure_data_checked"] = true
			flags["privacy_checked"] = true
			notes = "main supplies sanitized public card facts without runtime objects"
		"browser_summary_contract":
			var browser := _compose_browser_fixture()
			passed = str(browser.get("summary_text", "")).contains("本局牌池12张") and str(browser.get("summary_text", "")).contains("区域补给6张")
			flags["browser_checked"] = true
			notes = "browser summary preserves filter, page, and public pool counts"
		"browser_card_contract":
			var cards := _compose_browser_fixture().get("cards", []) as Array
			passed = cards.size() == 1 and str((cards[0] as Dictionary).get("card_name", "")) == "轨道融资1" and str((cards[0] as Dictionary).get("hint", "")).contains("双击")
			flags["browser_checked"] = true
			notes = "browser receives one stable public thumbnail entry"
		"browser_filter_contract":
			var filters := _compose_browser_fixture().get("filters", []) as Array
			passed = filters.size() == 1 and str((filters[0] as Dictionary).get("id", "")) == "all" and bool((filters[0] as Dictionary).get("active", false)) and str((filters[0] as Dictionary).get("text", "")).contains("·1")
			flags["browser_checked"] = true
			notes = "filter metadata survives ViewModel normalization"
		"browser_preview_contract":
			var preview := _compose_browser_fixture().get("preview", {}) as Dictionary
			passed = str(preview.get("title", "")).contains("轨道融资") and str(preview.get("body", "")).contains("I→IV")
			flags["browser_checked"] = true
			notes = "hover preview remains concise and route-aware"
		"detail_summary_contract":
			var snapshot := _compose_detail_fixture()
			passed = str(snapshot.get("summary_text", "")).contains("轨道融资") and str(snapshot.get("summary_text", "")).contains("¥140")
			flags["detail_checked"] = true
			notes = "detail summary preserves identity, price, route, and target copy"
		"detail_card_face_contract":
			var face := (_compose_detail_fixture().get("detail", {}) as Dictionary).get("card_face", {}) as Dictionary
			passed = str(face.get("name", "")).contains("轨道融资") and str(face.get("cost", "")) == "¥140" and str(face.get("effect", "")).contains("GDP")
			flags["detail_checked"] = true
			notes = "CardFace receives a normalized public card presentation"
		"detail_tactical_contract":
			var tactical := ((_compose_detail_fixture().get("detail", {}) as Dictionary).get("tactical", {}) as Dictionary).get("entries", []) as Array
			passed = tactical.size() == 3 and str((tactical[0] as Dictionary).get("title", "")) == "何时拿" and str((tactical[2] as Dictionary).get("body", "")).contains("经济实力线索")
			flags["detail_checked"] = true
			flags["privacy_checked"] = true
			notes = "tactical timing, combo, and public clue cards remain viewer-safe"
		"detail_fact_contract":
			var facts := ((_compose_detail_fixture().get("detail", {}) as Dictionary).get("facts", []) as Array)
			passed = facts.size() == 4 and _array_has_title(facts, "◎ 牌面定位") and _array_has_title(facts, "¥ 费用与门槛") and _array_has_title(facts, "✦ 核心效果") and _array_has_title(facts, "◈ 关键数值")
			flags["detail_checked"] = true
			flags["rule_boundary_checked"] = true
			notes = "four public fact cards render supplied rule facts without recalculation"
		"detail_upgrade_contract":
			var upgrades := ((_compose_detail_fixture().get("detail", {}) as Dictionary).get("upgrades", []) as Array)
			passed = upgrades.size() == 2 and str((upgrades[0] as Dictionary).get("roman", "")) == "I" and str((upgrades[1] as Dictionary).get("roman", "")) == "II"
			flags["detail_checked"] = true
			notes = "supplied I-IV gradient entries remain presentation data"
		"detail_resolution_contract":
			var resolution := ((_compose_detail_fixture().get("detail", {}) as Dictionary).get("resolution", {}) as Dictionary)
			passed = str(resolution.get("title", "")) == "◇ 结算演出" and str(resolution.get("body", "")).contains("城市高亮") and str(resolution.get("meta", "")).contains("匿名")
			flags["detail_checked"] = true
			flags["privacy_checked"] = true
			notes = "resolution animation copy remains public and anonymous"
		"empty_source_safe":
			var snapshot: Dictionary = _service.call("compose_detail", {"valid": false}) if _service != null else {}
			passed = str(snapshot.get("summary_text", "")) == "" and (snapshot.get("detail", {}) as Dictionary).is_empty()
			flags["detail_checked"] = true
			notes = "invalid card source returns a safe empty presentation"
		"privacy_boundary":
			var source := _card_source()
			source["hidden_owner"] = 3
			source["private_plan"] = "secret-card-plan"
			source["hand"] = ["hidden-card"]
			var snapshot: Dictionary = _service.call("compose_detail", source) if _service != null else {}
			passed = _is_pure_data(snapshot) and not _contains_private_key(snapshot) and not JSON.stringify(snapshot).contains("secret-card-plan") and not JSON.stringify(snapshot).contains("hidden-card")
			flags["privacy_checked"] = true
			flags["pure_data_checked"] = true
			notes = "hidden owner, private plan, and hand input never reach public output"
		"coordinator_scene_composition":
			var node := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardCodexPublicSnapshotService") if _main != null else null
			passed = node != null and node.scene_file_path == SERVICE_SCENE
			flags["service_checked"] = true
			flags["main_checked"] = true
			notes = "real main composition owns one editable Card snapshot service"
		"coordinator_pure_data_proxy":
			var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
			var browser: Variant = coordinator.call("compose_card_codex_browser", _browser_source()) if coordinator != null else {}
			var detail: Variant = coordinator.call("compose_card_codex_detail", _card_source()) if coordinator != null else {}
			passed = coordinator != null and _is_pure_data(browser) and _is_pure_data(detail) and not _contains_private_key(browser) and not _contains_private_key(detail)
			flags["pure_data_checked"] = true
			flags["privacy_checked"] = true
			notes = "coordinator exposes duplicated pure-data browser and detail payloads"
		"real_main_browser_and_detail_routes":
			var catalog_coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
			var skill: Dictionary = catalog_coordinator.call("card_definition", _real_card_name) if catalog_coordinator != null and _real_card_name != "" else {}
			var browser: Dictionary = _main.call("_card_codex_public_browser_snapshot", _real_card_names) if _main != null else {}
			var detail: Dictionary = _main.call("_card_codex_public_detail_snapshot", _real_card_name, skill, 0, maxi(1, _real_card_names.size())) if _main != null and _real_card_name != "" else {}
			passed = _real_card_name != "" and not (browser.get("cards", []) as Array).is_empty() and str(detail.get("summary_text", "")).contains(_real_card_name.trim_suffix("1")) and detail.get("detail", {}) is Dictionary and _is_pure_data(browser) and _is_pure_data(detail)
			flags["main_checked"] = true
			flags["routing_checked"] = true
			notes = "real Card browser and detail routes delegate sanitized facts through the coordinator"
		"legacy_card_formatters_absent_and_metrics":
			passed = RETIRED_FORMATTERS.size() == 19
			for formatter_name: String in RETIRED_FORMATTERS:
				passed = passed and not _main_source.contains("func %s(" % formatter_name)
			var metrics := _main_metrics()
			var debug := _debug_snapshot()
			passed = passed and int(metrics.get("nonblank_lines", 999999)) < 40584 and int(metrics.get("function_count", 999999)) < 1997
			passed = passed and int(metrics.get("top_level_variable_count", 999999)) <= 192 and int(metrics.get("constant_count", 999999)) < 320
			passed = passed and not bool(debug.get("calculates_card_price", true)) and not bool(debug.get("calculates_card_effects", true)) and not bool(debug.get("calculates_play_requirements", true)) and not bool(debug.get("legacy_main_formatter_active", true))
			flags["deletion_checked"] = true
			flags["rule_boundary_checked"] = true
			notes = "nineteen Card presentation formatters retired while all card-rule authority remains outside the service"
	return _record(case_id, passed, notes, flags)


func _compose_browser_fixture() -> Dictionary:
	return _service.call("compose_browser", _browser_source()) as Dictionary if _service != null else {}


func _compose_detail_fixture() -> Dictionary:
	return _service.call("compose_detail", _card_source()) as Dictionary if _service != null else {}


func _browser_source() -> Dictionary:
	var card := _card_source()
	return {
		"names": ["轨道融资1"], "columns": 3, "rows": 2, "page_index": 0, "filter_id": "all", "selected_card": "轨道融资1",
		"filter_label": "全部牌", "icon_legend": "◆城市 / ◇商品", "run_pool_count": 12, "district_supply_count": 6,
		"filters": [{"id": "all", "label": "全部", "short_label": "全部", "icon": "◆", "count": 1, "accent": Color("#38bdf8")}],
		"cards": [card], "preview_card": card,
	}


func _card_source() -> Dictionary:
	return {
		"valid": true, "index": 0, "total": 12, "card_name": "轨道融资1", "display_name": "轨道融资 I", "icon": "◆", "family": "轨道融资", "kind": "city_growth", "rank": 1, "rank_label": "I", "tag_text": "城市 / 金融", "accent": Color("#38bdf8"),
		"price": 140, "category_label": "城市牌", "icon_route_label": "城市成长", "subtype_label": "融资", "source_type_label": "普通卡", "supply_layer": "区域补给",
		"art_stats": "GDP+20 / 交通+1", "use_case": "建立第一条稳定收入路线。", "strategy_route_label": "城市成长", "strategy_summary": "城市成长｜先发展再滚动收益", "strategy_use_text": "提高城市GDP与交通效率。",
		"quick_effect_compact": "目标城市GDP提高", "quick_effect_full": "令目标城市GDP提高20。", "full_effect_text": "令目标城市GDP提高20，并提高交通效率。", "rules_text_compact": "选择己方城市｜GDP+20", "level_gradient_text": "I:+20 / II:+30 / III:+40 / IV:+55", "detail_tooltip": "轨道融资 I\n公开卡面与规则", "face_route_text": "◆城市成长｜融资",
		"requires_target_monster": false, "targets_player": false, "targets_monster": false, "play_region_share_required": 25, "play_region_scope_label": "目标城市", "panic": 0, "route_damage": 0, "persistent": false, "play_requirement_text": "目标城市GDP份额≥25%", "key_rule_facts": ["GDP+20", "交通+1"],
		"read_chips": [{"text": "¥140", "tooltip": "购买价格", "fg": Color("#fde68a")}, {"text": "份额25%", "tooltip": "出牌门槛", "fg": Color("#93c5fd")}],
		"upgrades": [
			{"roman": "I", "price": 140, "strength_band": "基础", "preview": "GDP+20", "display_name": "轨道融资 I", "full_effect_text": "GDP+20", "accent": Color("#38bdf8"), "fill_weight": 0.10},
			{"roman": "II", "price": 140, "strength_band": "强化", "preview": "GDP+30", "display_name": "轨道融资 II", "full_effect_text": "GDP+30", "accent": Color("#67e8f9"), "fill_weight": 0.13},
		],
		"resolution_animation_text": "卡面公开 / 城市高亮 / GDP数字上浮",
	}


func _debug_snapshot() -> Dictionary:
	return _service.call("debug_snapshot") as Dictionary if _service != null else {}


func _record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var record := {"case_id": case_id, "card_name": "轨道融资1", "service_checked": false, "main_checked": false, "browser_checked": false, "detail_checked": false, "rule_boundary_checked": false, "routing_checked": false, "privacy_checked": false, "pure_data_checked": false, "deletion_checked": false, "passed": passed, "notes": notes}
	record.merge(flags, true)
	return record


func _array_has_title(entries: Array, title_value: String) -> bool:
	for entry_variant: Variant in entries:
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("title", "")) == title_value:
			return true
	return false


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant: Variant in value:
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item_variant: Variant in value:
			if not _is_pure_data(item_variant):
				return false
	return true


func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in value:
			if str(key_variant).to_lower() in ["owner", "owner_index", "hidden_owner", "hidden_owner_id", "private_target", "private_plan", "ai_private_plan", "cash", "hand", "private_discard"]:
				return true
			if _contains_private_key(value[key_variant]):
				return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_private_key(item_variant):
				return true
	return false


func _main_metrics() -> Dictionary:
	var nonblank_lines := 0
	var function_count := 0
	var variable_count := 0
	var constant_count := 0
	for line_variant: Variant in _main_source.split("\n"):
		var line := str(line_variant)
		if not line.strip_edges().is_empty():
			nonblank_lines += 1
		if line.begins_with("func "):
			function_count += 1
		elif line.begins_with("var "):
			variable_count += 1
		elif line.begins_with("const "):
			constant_count += 1
	return {"nonblank_lines": nonblank_lines, "function_count": function_count, "top_level_variable_count": variable_count, "constant_count": constant_count}


func _passed_count() -> int:
	var count := 0
	for record_variant: Variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _update_ui(manifest: Dictionary) -> void:
	var passed := int(manifest.get("passed_count", 0))
	var total := int(manifest.get("record_count", 0))
	status_label.text = "PASS" if passed == total else "FAIL"
	status_label.modulate = Color("#4ade80") if passed == total else Color("#fb7185")
	summary_label.text = "%d/%d ownership cases passed" % [passed, total]
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	ownership_text.text = "[b]Scene-owned Card Codex snapshots[/b]\nCardCodexPublicSnapshotService owns browser summaries, thumbnails, previews, detail cards, tactical copy, facts, upgrades, and resolution copy.\n\n[b]Existing ViewModels retained[/b]\nCardCodexBrowserSnapshot and CardCodexDetailSnapshot remain the normalized UI contracts.\n\n[b]Domain authority retained[/b]\nPrices, effects, legality, target rules, and upgrade facts are supplied by the game domain.\n\n[b]Retired from main.gd[/b]\n19 Card presentation formatters.\n\n[b]Current main metrics[/b]\n%s nonblank lines - %s functions - %s vars - %s constants" % [str(metrics.get("nonblank_lines", 0)), str(metrics.get("function_count", 0)), str(metrics.get("top_level_variable_count", 0)), str(metrics.get("constant_count", 0))]
	var lines: Array[String] = []
	for record_variant: Variant in _records:
		var record := record_variant as Dictionary
		var result := "PASS" if bool(record.get("passed", false)) else "FAIL"
		lines.append("[color=%s][b]%s[/b][/color]  %s\n%s" % ["#4ade80" if result == "PASS" else "#fb7185", result, str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	var lines := ["# Card Codex Public Snapshot Cutover", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Retired formatters: %d" % int(manifest.get("retired_formatter_count", 0)), "- Main nonblank lines: %d" % int(metrics.get("nonblank_lines", 0)), "", "| Case | Result | Notes |", "| --- | --- | --- |"]
	for record_variant: Variant in manifest.get("records", []):
		var record := record_variant as Dictionary
		lines.append("| %s | %s | %s |" % [str(record.get("case_id", "")), "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines) + "\n"


func _prepare_output_dir() -> void:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	for file_name in ["manifest.json", "report.md"]:
		var absolute_path := absolute_dir.path_join(file_name)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("cannot write %s" % path)
		return
	file.store_string(content)


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_failures.append("viewport image unavailable")
		return
	var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	if error != OK:
		_failures.append("screenshot save failed: %s" % error_string(error))


func _dispose_runtime() -> void:
	if _main != null:
		for player_variant: Variant in _main.find_children("*", "AudioStreamPlayer", true, false):
			var player := player_variant as AudioStreamPlayer
			if player != null:
				player.stop()
				player.stream = null
		_main.queue_free()
		_main = null
	if _service != null:
		_service.queue_free()
		_service = null
	for _frame in range(4):
		await get_tree().process_frame
