extends Control
class_name ProductCodexPublicSnapshotCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const SERVICE_SCENE := "res://scenes/runtime/ProductCodexPublicSnapshotService.tscn"
const SERVICE_SCRIPT := "res://scripts/runtime/product_codex_public_snapshot_service.gd"
const COORDINATOR_SCENE := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/product_codex_public_snapshot_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/product_codex_public_snapshot_cutover_sprint_16.png"

const RETIRED_FORMATTERS := [
	"_product_codex_browser_entry_snapshot", "_product_codex_detail_snapshot", "_product_codex_detail_chip_snapshots",
	"_product_codex_detail_kpi_snapshots", "_product_codex_strategy_snapshots", "_product_codex_public_clue_summary",
	"_product_codex_preview_text", "_product_strategy_summary_text", "_product_primary_strategy_tag",
	"_product_futures_warehouse_codex_text", "_product_warehouse_city_public_text", "_product_monster_focus_strategy_text",
	"_product_clue_preview_text", "_product_related_card_names", "_product_monster_focus_names",
	"_product_codex_color", "_product_codex_secondary_color", "_product_codex_tooltip",
	"_product_related_district_names", "_product_codex_text",
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
var _real_product_name := ""


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_cutover_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func retired_formatter_names() -> Array:
	return RETIRED_FORMATTERS.duplicate()


func cutover_cases() -> Array:
	return [
		"required_service_assets_load", "service_scene_contract", "product_source_pure_data", "product_summary_parity",
		"browser_entry_shape", "detail_shape", "detail_chip_contract", "detail_kpi_contract",
		"strategy_facts_supplied_not_calculated", "futures_warehouse_public_contract", "monster_focus_public_contract", "related_content_contract",
		"city_clue_sanitization", "empty_source_safe", "privacy_boundary", "coordinator_scene_composition",
		"coordinator_pure_data_proxy", "real_main_browser_route", "real_main_detail_route", "legacy_product_formatters_absent_and_metrics",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant: Variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite": "product-codex-public-snapshot-cutover-v04",
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
		"suite": "product-codex-public-snapshot-cutover-v04",
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
	print("ProductCodexPublicSnapshotCutoverBench manifest: %s" % MANIFEST_PATH)
	print("ProductCodexPublicSnapshotCutoverBench report: %s" % REPORT_PATH)
	print("ProductCodexPublicSnapshotCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("ProductCodexPublicSnapshotCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("ProductCodexPublicSnapshotCutoverBench failed:\n- %s" % "\n- ".join(_failures))
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
		var names: Array = _main.call("_product_catalog_names")
		_real_product_name = str(names[0]) if not names.is_empty() else ""


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	match case_id:
		"required_service_assets_load":
			passed = load(SERVICE_SCRIPT) is Script and load(SERVICE_SCENE) is PackedScene and load(COORDINATOR_SCENE) is PackedScene
			flags["service_checked"] = true
			notes = "product snapshot service assets and coordinator load"
		"service_scene_contract":
			var debug: Dictionary = _service.call("debug_snapshot") if _service != null else {}
			passed = _service != null and _service.has_method("configure") and _service.has_method("compose") and _service.has_method("debug_snapshot")
			passed = passed and not bool(debug.get("calculates_market_price", true)) and not bool(debug.get("calculates_strategy_scores", true)) and not bool(debug.get("reads_runtime_nodes", true))
			flags["service_checked"] = true
			flags["market_checked"] = true
			flags["strategy_checked"] = true
			notes = "service composes presentation without owning market or strategy algorithms"
		"product_source_pure_data":
			var source: Dictionary = _main.call("_product_codex_public_source_snapshot", _real_product_name, 0, true) if _main != null else {}
			passed = bool(source.get("valid", false)) and _is_pure_data(source) and not _contains_private_key(source)
			flags["main_checked"] = true
			flags["pure_data_checked"] = true
			flags["privacy_checked"] = true
			notes = "main gathers only sanitized public product facts"
		"product_summary_parity":
			var snapshot: Dictionary = _compose_fixture()
			passed = str(snapshot.get("summary_text", "")).contains("商品详情｜第3/12种｜环晶电池") and str(snapshot.get("summary_text", "")).contains("策略摘要")
			flags["market_checked"] = true
			notes = "scene-owned formatter preserves the existing product summary hierarchy"
		"browser_entry_shape":
			var browser := _compose_fixture().get("browser_entry", {}) as Dictionary
			var badge := browser.get("badge", {}) as Dictionary
			passed = int(browser.get("catalog_index", -1)) == 2 and bool(browser.get("selected", false)) and str(badge.get("name", "")) == "环晶电池" and str(browser.get("tooltip", "")).contains("双击")
			flags["routing_checked"] = true
			notes = "ProductCodexBrowser receives stable thumbnail, badge, selection, and tooltip data"
		"detail_shape":
			var detail := _compose_fixture().get("detail", {}) as Dictionary
			passed = str(detail.get("title", "")).contains("环晶电池") and detail.get("badge", {}) is Dictionary and (detail.get("strategies", []) as Array).size() == 6
			flags["market_checked"] = true
			notes = "ProductCodexDetail receives a stable scene-owned payload"
		"detail_chip_contract":
			var chips := ((_compose_fixture().get("detail", {}) as Dictionary).get("chips", []) as Array)
			passed = chips.size() == 7 and _array_has_text(chips, "¥92") and _array_has_text(chips, "供2") and _array_has_text(chips, "波4")
			flags["market_checked"] = true
			notes = "price, base, trend, supply, demand, disruption, and volatility chips remain stable"
		"detail_kpi_contract":
			var kpis := ((_compose_fixture().get("detail", {}) as Dictionary).get("kpis", []) as Array)
			passed = kpis.size() == 4 and _array_has_title(kpis, "价格") and _array_has_title(kpis, "主策略") and _array_has_title(kpis, "天气") and _array_has_title(kpis, "牌路")
			flags["market_checked"] = true
			notes = "market, strategy, weather, and card-route KPI contract remains stable"
		"strategy_facts_supplied_not_calculated":
			var snapshot := _compose_fixture()
			var detail := snapshot.get("detail", {}) as Dictionary
			var strategies := detail.get("strategies", []) as Array
			var debug: Dictionary = _service.call("debug_snapshot") if _service != null else {}
			passed = str(snapshot.get("summary_text", "")).contains("看涨88 / 囤货63") and str((strategies[0] as Dictionary).get("tooltip", "")).contains("需求和断路") and not bool(debug.get("calculates_strategy_scores", true))
			flags["strategy_checked"] = true
			notes = "service renders the supplied ranking exactly and never recomputes scores"
		"futures_warehouse_public_contract":
			var snapshot := _compose_fixture()
			passed = str(snapshot.get("preview_text", "")).contains("匿名期货") and str(snapshot.get("summary_text", "")).contains("仓库:临港城")
			flags["futures_checked"] = true
			flags["privacy_checked"] = true
			notes = "anonymous futures counts and public warehouse location remain readable without owner identity"
		"monster_focus_public_contract":
			var detail := _compose_fixture().get("detail", {}) as Dictionary
			var strategies := detail.get("strategies", []) as Array
			passed = str((strategies[2] as Dictionary).get("body", "")).contains("岩甲兽") and str((strategies[2] as Dictionary).get("tooltip", "")).contains("仓库吸引")
			flags["market_checked"] = true
			notes = "public monster resource preference remains a supplied ecological fact"
		"related_content_contract":
			var detail := _compose_fixture().get("detail", {}) as Dictionary
			var kpis := detail.get("kpis", []) as Array
			var strategies := detail.get("strategies", []) as Array
			passed = str((kpis[3] as Dictionary).get("value", "")).contains("商品看涨1") and str((strategies[3] as Dictionary).get("body", "")).contains("临港区") and str((strategies[4] as Dictionary).get("body", "")).contains("首都圈")
			flags["routing_checked"] = true
			notes = "related cards and supply/demand districts remain public navigation facts"
		"city_clue_sanitization":
			var detail := _compose_fixture().get("detail", {}) as Dictionary
			var clue_card := (detail.get("strategies", []) as Array)[5] as Dictionary
			passed = str(clue_card.get("body", "")).contains("业主未知") and not str(clue_card.get("tooltip", "")).contains("owner") and not _contains_private_key(detail)
			flags["privacy_checked"] = true
			notes = "city clues expose evidence labels but never a hidden owner identifier"
		"empty_source_safe":
			var snapshot: Dictionary = _service.call("compose", {"valid": false}) if _service != null else {}
			passed = str(snapshot.get("summary_text", "")) == "" and (snapshot.get("detail", {}) as Dictionary).is_empty()
			flags["market_checked"] = true
			notes = "invalid product source returns a safe empty presentation"
		"privacy_boundary":
			var source := _source()
			source["hidden_owner"] = 2
			source["private_plan"] = "secret"
			source["cash"] = 9999
			var snapshot: Dictionary = _service.call("compose", source) if _service != null else {}
			passed = not _contains_private_key(snapshot) and _is_pure_data(snapshot) and not JSON.stringify(snapshot).contains("secret")
			flags["privacy_checked"] = true
			flags["pure_data_checked"] = true
			notes = "private owner, plan, and cash input is never copied to public output"
		"coordinator_scene_composition":
			var node := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductCodexPublicSnapshotService") if _main != null else null
			passed = node != null and node.scene_file_path == SERVICE_SCENE
			flags["service_checked"] = true
			flags["main_checked"] = true
			notes = "real main composition owns one editable product snapshot service"
		"coordinator_pure_data_proxy":
			var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
			var snapshot: Variant = coordinator.call("compose_product_codex_snapshot", _source()) if coordinator != null else {}
			passed = coordinator != null and _is_pure_data(snapshot) and not _contains_private_key(snapshot)
			flags["pure_data_checked"] = true
			flags["privacy_checked"] = true
			notes = "coordinator exposes a duplicated pure-data product presentation only"
		"real_main_browser_route":
			var browser: Dictionary = _main.call("_product_codex_browser_snapshot") if _main != null else {}
			passed = not (browser.get("entries", []) as Array).is_empty() and browser.get("preview", {}) is Dictionary and _is_pure_data(browser)
			flags["main_checked"] = true
			flags["routing_checked"] = true
			notes = "real product atlas delegates entry and preview composition through the service"
		"real_main_detail_route":
			var snapshot: Dictionary = _main.call("_product_codex_public_snapshot", _real_product_name, 0, true) if _main != null else {}
			passed = _real_product_name != "" and str(snapshot.get("summary_text", "")).contains(_real_product_name) and snapshot.get("detail", {}) is Dictionary
			flags["main_checked"] = true
			flags["routing_checked"] = true
			notes = "real product detail route delegates sanitized facts through the coordinator"
		"legacy_product_formatters_absent_and_metrics":
			passed = RETIRED_FORMATTERS.size() == 20
			for formatter_name in RETIRED_FORMATTERS:
				passed = passed and not _main_source.contains("func %s(" % formatter_name)
			var metrics := _main_metrics()
			var debug: Dictionary = _service.call("debug_snapshot") if _service != null else {}
			passed = passed and int(metrics.get("nonblank_lines", 999999)) < 40859 and int(metrics.get("function_count", 999999)) < 2010
			passed = passed and int(metrics.get("top_level_variable_count", 999999)) <= 192 and int(metrics.get("constant_count", 999999)) <= 320
			passed = passed and not bool(debug.get("calculates_market_price", true)) and not bool(debug.get("calculates_strategy_scores", true)) and not bool(debug.get("legacy_main_formatter_active", true))
			flags["deletion_checked"] = true
			flags["market_checked"] = true
			flags["strategy_checked"] = true
			notes = "twenty Product formatters retired while market and strategy authority remain outside the service"
	return _record(case_id, passed, notes, flags)


func _compose_fixture() -> Dictionary:
	return _service.call("compose", _source()) as Dictionary if _service != null else {}


func _source() -> Dictionary:
	return {
		"valid": true, "index": 2, "total": 12, "selected": true, "name": "环晶电池",
		"profile": {"category": "能源", "route": "高波动能源线", "terrain": "陆地", "use": "连接生产城、需求城和怪兽压力。", "hook": "追踪需求与断路形成的价格窗口。", "glyph": "◇", "accent": Color("#22c55e"), "secondary": Color("#f8fafc")},
		"market": {"current_price": 92, "base_price": 70, "tier": "高价档", "trend_text": "+8", "price_path_text": "70→78→92", "supply": 2, "demand": 5, "disrupted": 1, "volatility": 4, "weather_text": "太阳风令能源需求上升。"},
		"strategy_rankings": [{"label": "看涨", "score": 88, "hint": "需求和断路正在支撑价格。"}, {"label": "囤货", "score": 63, "hint": "仓储公开但仍有收益窗口。"}],
		"futures_public_full": "匿名期货 看涨2 / 看跌1", "futures_public_compact": "匿名期货 ↑2 ↓1",
		"warehouse_public_entries": [{"name": "临港城", "pressure": 7, "count": 2, "units": 4, "duration": "18s"}],
		"monster_focus_names": ["岩甲兽", "电弧兽"], "related_card_names": ["商品看涨1", "港仓囤货1"],
		"supply_district_names": ["临港区"], "demand_district_names": ["首都圈"],
		"public_clue_lines": ["T+30s｜临港城｜业主未知｜类型:市场｜需求上升"], "public_clue_labels": ["临港城/市场"],
	}


func _record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var record := {"case_id": case_id, "product_name": "环晶电池", "service_checked": false, "main_checked": false, "market_checked": false, "strategy_checked": false, "futures_checked": false, "routing_checked": false, "privacy_checked": false, "pure_data_checked": false, "deletion_checked": false, "passed": passed, "notes": notes}
	record.merge(flags, true)
	return record


func _array_has_text(entries: Array, text_value: String) -> bool:
	for entry_variant: Variant in entries:
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("text", "")) == text_value:
			return true
	return false


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
	ownership_text.text = "[b]Scene-owned Product Codex snapshots[/b]\nProductCodexPublicSnapshotService owns public summaries, thumbnails, details, chips, KPIs, strategy cards, and tooltips.\n\n[b]Domain authority retained[/b]\nMarket prices, strategy scores, futures, warehouse pressure, monster focus, and city clues are supplied facts.\n\n[b]Retired from main.gd[/b]\n20 Product presentation formatters.\n\n[b]Current main metrics[/b]\n%s nonblank lines - %s functions - %s vars - %s constants" % [str(metrics.get("nonblank_lines", 0)), str(metrics.get("function_count", 0)), str(metrics.get("top_level_variable_count", 0)), str(metrics.get("constant_count", 0))]
	var lines: Array[String] = []
	for record_variant: Variant in _records:
		var record := record_variant as Dictionary
		var result := "PASS" if bool(record.get("passed", false)) else "FAIL"
		lines.append("[color=%s][b]%s[/b][/color]  %s\n%s" % ["#4ade80" if result == "PASS" else "#fb7185", result, str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	var lines := ["# Product Codex Public Snapshot Cutover", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Retired formatters: %d" % int(manifest.get("retired_formatter_count", 0)), "- Main nonblank lines: %d" % int(metrics.get("nonblank_lines", 0)), "", "| Case | Result | Notes |", "| --- | --- | --- |"]
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
