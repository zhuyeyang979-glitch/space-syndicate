extends Control
class_name EconomyDashboardPublicSnapshotCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const SERVICE_SCENE := "res://scenes/runtime/EconomyDashboardPublicSnapshotService.tscn"
const SERVICE_SCRIPT := "res://scripts/runtime/economy_dashboard_public_snapshot_service.gd"
const DASHBOARD_SCENE := "res://scenes/ui/EconomyDashboard.tscn"
const COORDINATOR_SCENE := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/economy_dashboard_public_snapshot_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/economy_dashboard_public_snapshot_cutover_sprint_18.png"

const RETIRED_FORMATTERS := [
	"_economy_dashboard_snapshot", "_economy_dashboard_chip_snapshots", "_economy_dashboard_kpi_snapshots",
	"_economy_dashboard_decision_snapshots", "_economy_dashboard_top_product_value", "_economy_dashboard_top_city_value",
	"_economy_dashboard_product_lines", "_economy_dashboard_city_lines", "_economy_dashboard_card_aftermath_lines",
	"_economy_dashboard_risk_lines", "_economy_dashboard_next_step_lines", "_economy_overview_text",
	"_public_situation_summary_text", "_sort_economy_product_cold_entry", "_economy_product_line", "_economy_city_income_line",
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
var _real_source: Dictionary = {}
var _real_snapshot: Dictionary = {}
var _real_open_elapsed_ms := -1


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_cutover_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func retired_formatter_names() -> Array:
	return RETIRED_FORMATTERS.duplicate()


func cutover_cases() -> Array:
	return [
		"required_service_assets_load", "service_scene_contract", "economy_source_pure_data", "empty_source_safe",
		"summary_read_order_contract", "overview_card_contract", "dashboard_chip_contract", "dashboard_kpi_contract",
		"decision_route_contract", "hot_product_lane_contract", "cold_opportunity_lane_contract", "city_lane_privacy_contract",
		"aftermath_lane_contract", "risk_lane_privacy_contract", "next_step_lane_contract", "coordinator_scene_composition",
		"coordinator_pure_data_proxy", "real_main_route_and_render", "bounded_source_and_open_performance", "legacy_economy_formatters_absent_and_metrics",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant: Variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {"suite": "economy-dashboard-public-snapshot-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": records.size(), "retired_formatter_count": RETIRED_FORMATTERS.size(), "records": records}


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
	var manifest := {"suite": "economy-dashboard-public-snapshot-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": _records.size(), "passed_count": _passed_count(), "retired_formatter_count": RETIRED_FORMATTERS.size(), "real_open_elapsed_ms": _real_open_elapsed_ms, "main_metrics": _main_metrics(), "records": _records.duplicate(true)}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await _dispose_runtime()
	_save_screenshot()
	print("EconomyDashboardPublicSnapshotCutoverBench manifest: %s" % MANIFEST_PATH)
	print("EconomyDashboardPublicSnapshotCutoverBench report: %s" % REPORT_PATH)
	print("EconomyDashboardPublicSnapshotCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("EconomyDashboardPublicSnapshotCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	print("EconomyDashboardPublicSnapshotCutoverBench real open: %dms" % _real_open_elapsed_ms)
	if not _failures.is_empty():
		push_error("EconomyDashboardPublicSnapshotCutoverBench failed:\n- %s" % "\n- ".join(_failures))
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
		_real_source = _main.call("_economy_dashboard_public_source_snapshot") as Dictionary
		_real_snapshot = _main.call("_economy_dashboard_public_snapshot") as Dictionary
		var started := Time.get_ticks_msec()
		_main.call("_open_economy_overview_menu")
		_real_open_elapsed_ms = Time.get_ticks_msec() - started
	await get_tree().process_frame
	await get_tree().process_frame


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	var fixture := _compose_fixture()
	var dashboard := fixture.get("dashboard", {}) as Dictionary
	match case_id:
		"required_service_assets_load":
			passed = load(SERVICE_SCRIPT) is Script and load(SERVICE_SCENE) is PackedScene and load(DASHBOARD_SCENE) is PackedScene and load(COORDINATOR_SCENE) is PackedScene
			flags["service_checked"] = true
			notes = "service, editable dashboard, and coordinator assets load"
		"service_scene_contract":
			var debug := _debug_snapshot()
			passed = _service != null and _service.has_method("configure") and _service.has_method("compose") and _service.has_method("debug_snapshot")
			passed = passed and not bool(debug.get("calculates_product_prices", true)) and not bool(debug.get("calculates_city_income", true)) and not bool(debug.get("calculates_cashflow", true)) and not bool(debug.get("evaluates_private_truth", true)) and not bool(debug.get("reads_runtime_nodes", true))
			flags["service_checked"] = true
			flags["economy_boundary_checked"] = true
			notes = "service owns presentation only; product, city, and cashflow rules remain domain-owned"
		"economy_source_pure_data":
			passed = bool(_real_source.get("valid", false)) and _is_pure_data(_real_source) and not _contains_private_key(_real_source)
			flags["main_checked"] = true
			flags["pure_data_checked"] = true
			flags["privacy_checked"] = true
			notes = "real main supplies one bounded viewer-safe economy fact snapshot"
		"empty_source_safe":
			var empty_snapshot: Dictionary = _service.call("compose", {"valid": false}) if _service != null else {}
			passed = str(empty_snapshot.get("summary_text", "")).contains("还没有当前局经济数据") and (empty_snapshot.get("overview_cards", []) as Array).size() == 1
			flags["summary_checked"] = true
			notes = "empty economy state stays readable and safe"
		"summary_read_order_contract":
			var text := str(fixture.get("summary_text", ""))
			passed = text.contains("经济总览") and text.contains("商品热榜") and text.contains("商路收入前景") and text.contains("GDP趋势") and text.contains("玩家经济流水")
			flags["summary_checked"] = true
			notes = "one scene service composes the full public economy read order"
		"overview_card_contract":
			var cards := fixture.get("overview_cards", []) as Array
			passed = cards.size() == 4 and _array_has_title(cards, "经济速览") and _array_has_title(cards, "商品热榜") and _array_has_title(cards, "公开异动") and _array_has_title(cards, "匿名线索")
			flags["dashboard_checked"] = true
			notes = "four former main-generated cards now belong to EconomyDashboard"
		"dashboard_chip_contract":
			var chips := dashboard.get("chips", []) as Array
			passed = chips.size() == 3 and str((chips[0] as Dictionary).get("text", "")) == "刷新3" and str((chips[1] as Dictionary).get("text", "")) == "怪兽1"
			flags["dashboard_checked"] = true
			notes = "refresh, monster, and weather chips remain stable"
		"dashboard_kpi_contract":
			var kpis := dashboard.get("kpis", []) as Array
			passed = kpis.size() == 4 and str((kpis[0] as Dictionary).get("value", "")) == "240" and _array_has_title(kpis, "商品热度") and _array_has_title(kpis, "城市前景") and _array_has_title(kpis, "公开线索")
			flags["dashboard_checked"] = true
			flags["economy_boundary_checked"] = true
			notes = "supplied GDP, product, city, and clue facts are displayed without recalculation"
		"decision_route_contract":
			var decisions := dashboard.get("decisions", []) as Array
			passed = decisions.size() == 3 and _array_has_title(decisions, "扩GDP") and _array_has_title(decisions, "护商路") and _array_has_title(decisions, "压竞争")
			flags["dashboard_checked"] = true
			notes = "three public next-decision routes remain intact"
		"hot_product_lane_contract":
			var lanes := dashboard.get("lanes", []) as Array
			passed = lanes.size() == 6 and str((lanes[0] as Dictionary).get("title", "")) == "商品热榜" and str(((lanes[0] as Dictionary).get("lines", [""]) as Array)[0]).contains("环晶电池")
			flags["dashboard_checked"] = true
			notes = "hot lane follows supplied domain ranking"
		"cold_opportunity_lane_contract":
			var lanes := dashboard.get("lanes", []) as Array
			passed = str((lanes[1] as Dictionary).get("title", "")) == "低价机会" and str(((lanes[1] as Dictionary).get("lines", [""]) as Array)[0]).contains("低温藻")
			flags["dashboard_checked"] = true
			notes = "service owns presentation sorting by supplied cold score"
		"city_lane_privacy_contract":
			var lanes := dashboard.get("lanes", []) as Array
			var city_line := str(((lanes[2] as Dictionary).get("lines", [""]) as Array)[0])
			passed = city_line.contains("临港城") and city_line.contains("己方") and not city_line.contains("owner_index")
			flags["privacy_checked"] = true
			flags["dashboard_checked"] = true
			notes = "city lane renders viewer-safe owner labels only"
		"aftermath_lane_contract":
			var lanes := dashboard.get("lanes", []) as Array
			passed = str(((lanes[3] as Dictionary).get("lines", [""]) as Array)[0]).contains("归属待猜")
			flags["dashboard_checked"] = true
			flags["privacy_checked"] = true
			notes = "anonymous card aftermath remains public without owner identity"
		"risk_lane_privacy_contract":
			var lanes := dashboard.get("lanes", []) as Array
			var risk_text := "｜".join((lanes[4] as Dictionary).get("lines", []) as Array)
			passed = risk_text.contains("岩甲兽") and risk_text.contains("临港城") and risk_text.contains("归属未公开") and not _contains_private_key(lanes[4])
			flags["privacy_checked"] = true
			flags["dashboard_checked"] = true
			notes = "monster and warehouse risk exposes clues, never hidden ownership"
		"next_step_lane_contract":
			var lanes := dashboard.get("lanes", []) as Array
			passed = ((lanes[5] as Dictionary).get("lines", []) as Array).size() == 4 and str(((lanes[5] as Dictionary).get("lines", [""]) as Array)[3]).contains("做空")
			flags["dashboard_checked"] = true
			notes = "next-step lane remains a compact four-line read"
		"coordinator_scene_composition":
			var node := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/EconomyDashboardPublicSnapshotService") if _main != null else null
			passed = node != null and node.scene_file_path == SERVICE_SCENE
			flags["service_checked"] = true
			flags["main_checked"] = true
			notes = "real main composition owns one editable economy dashboard service"
		"coordinator_pure_data_proxy":
			var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
			var snapshot: Variant = coordinator.call("compose_economy_dashboard_snapshot", _source()) if coordinator != null else {}
			passed = coordinator != null and _is_pure_data(snapshot) and not _contains_private_key(snapshot)
			flags["pure_data_checked"] = true
			flags["privacy_checked"] = true
			notes = "coordinator returns a duplicated pure-data economy presentation"
		"real_main_route_and_render":
			var panel := _main.find_child("EconomyDashboardPanel", true, false) if _main != null else null
			passed = str(_real_snapshot.get("summary_text", "")).contains("经济总览") and _real_snapshot.get("dashboard", {}) is Dictionary and panel != null and panel.find_child("EconomyDashboardOverviewGrid", true, false) != null
			flags["main_checked"] = true
			flags["routing_checked"] = true
			notes = "real economy menu delegates once and renders the editable dashboard with overview grid"
		"bounded_source_and_open_performance":
			passed = (_real_source.get("product_entries", []) as Array).size() <= 64 and (_real_source.get("city_entries", []) as Array).size() <= 64 and (_real_source.get("card_aftermath_entries", []) as Array).size() <= 5 and (_real_source.get("city_clue_entries", []) as Array).size() <= 6 and (_real_source.get("monster_clue_entries", []) as Array).size() <= 5 and (_real_source.get("warehouse_entries", []) as Array).size() <= 5 and _real_open_elapsed_ms >= 0 and _real_open_elapsed_ms < 5000
			flags["performance_checked"] = true
			flags["pure_data_checked"] = true
			notes = "real source lists are bounded and the economy menu opens below the five-second gate (%dms)" % _real_open_elapsed_ms
		"legacy_economy_formatters_absent_and_metrics":
			passed = RETIRED_FORMATTERS.size() == 16
			for formatter_name: String in RETIRED_FORMATTERS:
				passed = passed and not _main_source.contains("func %s(" % formatter_name)
			var metrics := _main_metrics()
			var debug := _debug_snapshot()
			passed = passed and int(metrics.get("nonblank_lines", 999999)) < 40366 and int(metrics.get("function_count", 999999)) < 1984 and int(metrics.get("top_level_variable_count", 999999)) <= 192 and int(metrics.get("constant_count", 999999)) <= 318
			passed = passed and not bool(debug.get("calculates_product_prices", true)) and not bool(debug.get("calculates_city_income", true)) and not bool(debug.get("calculates_cashflow", true)) and not bool(debug.get("legacy_main_formatter_active", true))
			flags["deletion_checked"] = true
			flags["economy_boundary_checked"] = true
			notes = "sixteen Economy Dashboard formatters retired while economy algorithms remain outside the service"
	return _record(case_id, passed, notes, flags)


func _compose_fixture() -> Dictionary:
	return _service.call("compose", _source()) as Dictionary if _service != null else {}


func _source() -> Dictionary:
	return {
		"valid": true, "selected_name": "测试玩家", "selected_gdp_per_minute": 240, "business_cycle_count": 3, "monster_count": 1, "weather_text": "太阳风：能源需求上升", "clue_count": 4, "kpi_columns": 4, "lane_columns": 3, "overview_columns": 4, "current_product_names": ["环晶电池", "低温藻"],
		"product_entries": [{"name": "环晶电池", "price": 92, "base_price": 70, "gap": 22, "trend": 8, "tier": "高价档", "supply": 2, "demand": 5, "disrupted": 1, "volatility": 4, "weather": "需求+", "status_tags": ["热门"], "path": "70→92", "heat_score": 100, "cold_score": -20}, {"name": "低温藻", "price": 28, "base_price": 50, "gap": -22, "trend": -3, "tier": "低价档", "supply": 7, "demand": 1, "disrupted": 0, "volatility": 2, "weather": "无", "status_tags": ["供给压制"], "path": "50→28", "heat_score": -10, "cold_score": 120}],
		"city_entries": [{"name": "临港城", "owner_view": "己方", "intel_hint": "情报：已知", "income": 36, "last_income": 30, "gdp_trend": "GDP趋势：+6", "breakdown": "生产12+需求12+交通12", "status_tags": ["畅通"], "contract": "有效", "supplied": 1, "demand_count": 1, "disrupted": 0, "competition": 0, "flow": "畅通", "products": ["环晶电池"], "demands": ["低温藻"]}],
		"card_aftermath_entries": [{"resolved_time": 12.0, "style": "金融", "card": "轨道融资 I", "target": "临港城", "owner_known": false, "clue": "GDP上升", "tip_clue": "报价20"}],
		"city_clue_entries": [{"time": 14.0, "district": "临港区", "owner_visible": false, "kind": "市场", "clue_products": ["环晶电池"], "income": 36, "products": ["环晶电池"], "demands": ["低温藻"], "clue": "需求上升"}],
		"monster_clue_entries": [{"slot": 0, "name": "岩甲兽", "rank": 1, "owner_text": "归属未公开", "recent_loss": 5, "recent_damage": 10, "recent_source": "城市炮火", "recent_time": 18.0, "total_lost": 5, "cash_pool": 45, "cash_total": 50, "down": false, "clue": "受伤资金变化"}],
		"warehouse_entries": [{"name": "临港城", "owner_view": "业主未知", "intel_hint": "情报：无", "pressure": 7, "count": 2, "units": 4, "products": ["环晶电池"], "seconds_left": 18.0, "potential_income": 36, "latest_clue": "仓储公开"}],
		"player_cash_entries": [{"name": "测试玩家", "private": false, "eliminated": false, "score_label": "可见预估", "visible_score": 800, "visible_cash": 600, "city_count": 1, "intel_summary": "情报待结算", "last_cycle": 20, "role_income": 8, "gdp_per_minute": 240, "recent_delta": 12, "window_delta": 20, "path": "580→600", "ledger": "城市+20"}, {"name": "对手", "private": true, "eliminated": false}],
		"inference_lines": ["城市私标：临港城→玩家2", "公开卡牌归属：轨道融资待猜"],
	}


func _debug_snapshot() -> Dictionary:
	return _service.call("debug_snapshot") as Dictionary if _service != null else {}


func _record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var record := {"case_id": case_id, "service_checked": false, "main_checked": false, "summary_checked": false, "dashboard_checked": false, "economy_boundary_checked": false, "routing_checked": false, "performance_checked": false, "privacy_checked": false, "pure_data_checked": false, "deletion_checked": false, "passed": passed, "notes": notes}
	record.merge(flags, true)
	return record


func _array_has_title(entries: Array, title_value: String) -> bool:
	for entry_variant: Variant in entries:
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("title", "")) == title_value: return true
	return false


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT: return false
	if value is Dictionary:
		for key_variant: Variant in value:
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]): return false
	elif value is Array:
		for item_variant: Variant in value:
			if not _is_pure_data(item_variant): return false
	return true


func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in value:
			if str(key_variant).to_lower() in ["owner", "owner_index", "hidden_owner", "hidden_owner_id", "private_target", "private_plan", "ai_private_plan", "cash", "hand", "private_discard"]: return true
			if _contains_private_key(value[key_variant]): return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_private_key(item_variant): return true
	return false


func _main_metrics() -> Dictionary:
	var nonblank_lines := 0
	var function_count := 0
	var variable_count := 0
	var constant_count := 0
	for line_variant: Variant in _main_source.split("\n"):
		var line := str(line_variant)
		if not line.strip_edges().is_empty(): nonblank_lines += 1
		if line.begins_with("func "): function_count += 1
		elif line.begins_with("var "): variable_count += 1
		elif line.begins_with("const "): constant_count += 1
	return {"nonblank_lines": nonblank_lines, "function_count": function_count, "top_level_variable_count": variable_count, "constant_count": constant_count}


func _passed_count() -> int:
	var count := 0
	for record_variant: Variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)): count += 1
	return count


func _update_ui(manifest: Dictionary) -> void:
	var passed := int(manifest.get("passed_count", 0))
	var total := int(manifest.get("record_count", 0))
	status_label.text = "PASS" if passed == total else "FAIL"
	status_label.modulate = Color("#4ade80") if passed == total else Color("#fb7185")
	summary_label.text = "%d/%d ownership cases passed" % [passed, total]
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	ownership_text.text = "[b]Scene-owned Economy Dashboard snapshots[/b]\nEconomyDashboardPublicSnapshotService owns the public summary, overview cards, chips, KPIs, decisions, and six lanes.\n\n[b]Domain authority retained[/b]\nProduct prices, city income, GDP, cashflow, clues, and private truth remain supplied facts.\n\n[b]Retired from main.gd[/b]\n16 Economy presentation and cold-sort helpers.\n\n[b]Real open budget[/b]\n%s ms\n\n[b]Current main metrics[/b]\n%s nonblank lines - %s functions - %s vars - %s constants" % [str(manifest.get("real_open_elapsed_ms", -1)), str(metrics.get("nonblank_lines", 0)), str(metrics.get("function_count", 0)), str(metrics.get("top_level_variable_count", 0)), str(metrics.get("constant_count", 0))]
	var lines: Array[String] = []
	for record_variant: Variant in _records:
		var record := record_variant as Dictionary
		var result := "PASS" if bool(record.get("passed", false)) else "FAIL"
		lines.append("[color=%s][b]%s[/b][/color]  %s\n%s" % ["#4ade80" if result == "PASS" else "#fb7185", result, str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	var lines := ["# Economy Dashboard Public Snapshot Cutover", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Retired formatters: %d" % int(manifest.get("retired_formatter_count", 0)), "- Real open: %dms" % int(manifest.get("real_open_elapsed_ms", -1)), "- Main nonblank lines: %d" % int(metrics.get("nonblank_lines", 0)), "", "| Case | Result | Notes |", "| --- | --- | --- |"]
	for record_variant: Variant in manifest.get("records", []):
		var record := record_variant as Dictionary
		lines.append("| %s | %s | %s |" % [str(record.get("case_id", "")), "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines) + "\n"


func _prepare_output_dir() -> void:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	for file_name in ["manifest.json", "report.md"]:
		var absolute_path := absolute_dir.path_join(file_name)
		if FileAccess.file_exists(absolute_path): DirAccess.remove_absolute(absolute_path)


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("cannot write %s" % path)
		return
	file.store_string(content)


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless": return
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_failures.append("viewport image unavailable")
		return
	var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	if error != OK: _failures.append("screenshot save failed: %s" % error_string(error))


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
	for _frame in range(4): await get_tree().process_frame
