extends Control
class_name FinalSettlementPublicSnapshotCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const SERVICE_SCENE := "res://scenes/runtime/FinalSettlementPublicSnapshotService.tscn"
const SERVICE_SCRIPT := "res://scripts/runtime/final_settlement_public_snapshot_service.gd"
const BOARD_SCENE := "res://scenes/ui/FinalSettlementBoard.tscn"
const COORDINATOR_SCENE := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/final_settlement_public_snapshot_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/final_settlement_public_snapshot_cutover_sprint_20.png"

const RETIRED_FORMATTERS := [
	"_final_settlement_board_snapshot",
	"_final_settlement_money_source_snapshots",
	"_final_settlement_rank_snapshots",
	"_final_settlement_event_lines",
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
		"required_service_assets_load", "service_scene_contract", "final_source_pure_data", "empty_source_safe",
		"summary_read_order_contract", "header_chip_contract", "winner_kpi_contract", "money_leader_kpi_contract",
		"key_map_contract", "money_source_contract", "rank_track_contract", "public_event_contract",
		"after_action_contract", "bounded_eight_seat_contract", "coordinator_scene_composition", "coordinator_pure_data_proxy",
		"real_main_route_and_render", "open_performance_contract", "legacy_formatters_absent_and_metrics", "private_input_rejection",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant: Variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {"suite": "final-settlement-public-snapshot-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": records.size(), "retired_formatter_count": RETIRED_FORMATTERS.size(), "records": records}


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
	var manifest := {"suite": "final-settlement-public-snapshot-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": _records.size(), "passed_count": _passed_count(), "retired_formatter_count": RETIRED_FORMATTERS.size(), "real_open_elapsed_ms": _real_open_elapsed_ms, "main_metrics": _main_metrics(), "records": _records.duplicate(true)}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await _dispose_runtime()
	_save_screenshot()
	print("FinalSettlementPublicSnapshotCutoverBench manifest: %s" % MANIFEST_PATH)
	print("FinalSettlementPublicSnapshotCutoverBench report: %s" % REPORT_PATH)
	print("FinalSettlementPublicSnapshotCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("FinalSettlementPublicSnapshotCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	print("FinalSettlementPublicSnapshotCutoverBench real open: %dms" % _real_open_elapsed_ms)
	if not _failures.is_empty():
		push_error("FinalSettlementPublicSnapshotCutoverBench failed:\n- %s" % "\n- ".join(_failures))
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
		var rankings := _main.call("_final_score_rankings") as Array
		_real_source = _main.call("_final_settlement_public_source_snapshot", "QA终局", rankings) as Dictionary
		_real_snapshot = _main.call("_final_settlement_public_snapshot", "QA终局", rankings) as Dictionary
		var started := Time.get_ticks_msec()
		_main.call("_open_final_settlement_menu", "QA终局", rankings)
		_real_open_elapsed_ms = Time.get_ticks_msec() - started
	await get_tree().process_frame
	await get_tree().process_frame


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	var fixture := _compose_fixture()
	var board := fixture.get("board", {}) as Dictionary
	match case_id:
		"required_service_assets_load":
			passed = load(SERVICE_SCRIPT) is Script and load(SERVICE_SCENE) is PackedScene and load(BOARD_SCENE) is PackedScene and load(COORDINATOR_SCENE) is PackedScene
			flags["service_checked"] = true
			notes = "service, editable postgame board, and coordinator assets load"
		"service_scene_contract":
			var debug := _debug_snapshot()
			passed = _service != null and _service.has_method("configure") and _service.has_method("compose") and _service.has_method("debug_snapshot")
			passed = passed and not bool(debug.get("calculates_final_score", true)) and not bool(debug.get("sorts_final_rankings", true)) and not bool(debug.get("calculates_city_clearance", true)) and not bool(debug.get("calculates_intel_cash", true)) and not bool(debug.get("reads_private_hands", true)) and not bool(debug.get("reads_runtime_nodes", true))
			flags["service_checked"] = true
			flags["domain_boundary_checked"] = true
			notes = "service owns presentation only; final scoring and economy facts remain domain-owned"
		"final_source_pure_data":
			passed = bool(_real_source.get("valid", false)) and _is_pure_data(_real_source) and not _contains_private_key(_real_source) and (_real_source.get("rank_entries", []) as Array).size() <= 8
			flags["main_checked"] = true
			flags["pure_data_checked"] = true
			flags["privacy_checked"] = true
			notes = "real main supplies one bounded public postgame fact snapshot"
		"empty_source_safe":
			var empty_snapshot: Dictionary = _service.call("compose", {"valid": false, "reason": "无玩家"}) if _service != null else {}
			passed = str(empty_snapshot.get("summary_text", "")).contains("无玩家") and ((((empty_snapshot.get("board", {}) as Dictionary).get("actions", []) as Array).size() == 3))
			flags["summary_checked"] = true
			notes = "empty postgame state remains readable and actionable"
		"summary_read_order_contract":
			var text := str(fixture.get("summary_text", ""))
			passed = text.contains("游戏结束") and text.contains("赛后板") and text.contains("公开/终局结算数据") and text.contains("开局准备")
			flags["summary_checked"] = true
			notes = "one scene service composes the full public postgame read order"
		"header_chip_contract":
			var chips := board.get("chips", []) as Array
			passed = chips.size() == 3 and str((chips[0] as Dictionary).get("text", "")) == "胜者:测试玩家" and str((chips[1] as Dictionary).get("text", "")) == "目标¥1200" and str((chips[2] as Dictionary).get("text", "")) == "城值¥100"
			flags["board_checked"] = true
			notes = "winner, goal, and city-clearance chips follow supplied facts"
		"winner_kpi_contract":
			var kpis := board.get("kpis", []) as Array
			passed = kpis.size() == 4 and str((kpis[0] as Dictionary).get("body", "")).contains("结算资金¥980")
			flags["board_checked"] = true
			flags["domain_boundary_checked"] = true
			notes = "winner KPI displays the supplied final score without recalculation"
		"money_leader_kpi_contract":
			var kpis := board.get("kpis", []) as Array
			passed = str((kpis[1] as Dictionary).get("body", "")).contains("城收:测试玩家 ¥260") and str((kpis[1] as Dictionary).get("body", "")).contains("卡牌:对手 ¥140")
			flags["board_checked"] = true
			notes = "income-leader KPI preserves supplied city, card, and role totals"
		"key_map_contract":
			var kpis := board.get("kpis", []) as Array
			passed = str((kpis[2] as Dictionary).get("body", "")).contains("关键城市") and str((kpis[2] as Dictionary).get("body", "")).contains("末期GDP¥88")
			flags["board_checked"] = true
			notes = "key-map KPI renders supplied public city identity and final GDP"
		"money_source_contract":
			var entries := board.get("money_sources", []) as Array
			passed = entries.size() == 2 and JSON.stringify(entries[0]).contains("起手:基础¥500") and JSON.stringify(entries[0]).contains("现金¥720") and JSON.stringify(entries[0]).contains("支出¥260")
			flags["board_checked"] = true
			notes = "money cards preserve supplied starting, settlement, income, and spend facts"
		"rank_track_contract":
			var ranks := board.get("ranks", []) as Array
			passed = ranks.size() == 2 and str((ranks[0] as Dictionary).get("score", "")) == "¥980" and str((ranks[1] as Dictionary).get("score", "")) == "¥830"
			flags["board_checked"] = true
			flags["domain_boundary_checked"] = true
			notes = "service preserves domain-supplied final ordering instead of sorting"
		"public_event_contract":
			var lines := board.get("event_lines", []) as Array
			passed = "｜".join(lines).contains("轨道融资") and "｜".join(lines).contains("岩甲兽") and "｜".join(lines).contains("关键城市") and "｜".join(lines).contains("已结算3张匿名牌")
			flags["board_checked"] = true
			notes = "public card, monster, map, and track events remain readable"
		"after_action_contract":
			var actions := board.get("actions", []) as Array
			passed = actions.size() == 3 and _array_has_id(actions, "standings") and _array_has_id(actions, "economy") and _array_has_id(actions, "new_run")
			flags["routing_checked"] = true
			notes = "existing standings, economy, and new-run action ids remain intact"
		"bounded_eight_seat_contract":
			var crowded_source := _source()
			var crowded_ranks := crowded_source.get("rank_entries", []) as Array
			for index in range(2, 12):
				crowded_ranks.append({"player_index": index, "name": "席位%d" % (index + 1), "score": 100 - index, "cash": 100, "active_cities": 0, "gdp_per_minute": 0, "city_income": 0, "card_income": 0, "intel_cash": 0, "identity": "公开路线"})
			var crowded_snapshot: Dictionary = _service.call("compose", crowded_source) if _service != null else {}
			passed = ((((crowded_snapshot.get("board", {}) as Dictionary).get("ranks", []) as Array).size() == 8))
			flags["pure_data_checked"] = true
			notes = "service bounds postgame ranking presentation to eight seats"
		"coordinator_scene_composition":
			var node := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/FinalSettlementPublicSnapshotService") if _main != null else null
			passed = node != null and node.scene_file_path == SERVICE_SCENE
			flags["service_checked"] = true
			flags["main_checked"] = true
			notes = "real main composition owns one editable final-settlement service"
		"coordinator_pure_data_proxy":
			var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
			var snapshot: Variant = coordinator.call("compose_final_settlement_snapshot", _source()) if coordinator != null else {}
			passed = coordinator != null and _is_pure_data(snapshot) and not _contains_private_key(snapshot)
			flags["pure_data_checked"] = true
			flags["privacy_checked"] = true
			notes = "coordinator returns a duplicated pure-data postgame presentation"
		"real_main_route_and_render":
			var panel := _main.find_child("FinalSettlementBoardPanel", true, false) if _main != null else null
			passed = str(_real_snapshot.get("summary_text", "")).contains("游戏结束") and _real_snapshot.get("board", {}) is Dictionary and panel != null and panel.find_child("FinalSettlementRankTrack", true, false) != null
			flags["main_checked"] = true
			flags["routing_checked"] = true
			notes = "real final menu delegates once and renders the editable postgame board"
		"open_performance_contract":
			passed = _real_open_elapsed_ms >= 0 and _real_open_elapsed_ms < 5000
			flags["performance_checked"] = true
			notes = "real final menu opens below the five-second gate (%dms)" % _real_open_elapsed_ms
		"legacy_formatters_absent_and_metrics":
			passed = RETIRED_FORMATTERS.size() == 4
			for formatter_name: String in RETIRED_FORMATTERS:
				passed = passed and not _main_source.contains("func %s(" % formatter_name)
			var metrics := _main_metrics()
			passed = passed and int(metrics.get("nonblank_lines", 999999)) < 39997 and int(metrics.get("function_count", 999999)) < 1970 and int(metrics.get("top_level_variable_count", 999999)) <= 192 and int(metrics.get("constant_count", 999999)) <= 318
			flags["deletion_checked"] = true
			notes = "four legacy postgame formatters are absent and main.gd shrinks below Sprint 19"
		"private_input_rejection":
			var injected := _source()
			injected["private_hand"] = ["secret-card"]
			injected["ai_private_plan"] = "secret-route"
			var snapshot: Dictionary = _service.call("compose", injected) if _service != null else {}
			passed = _is_pure_data(snapshot) and not _contains_private_key(snapshot) and not JSON.stringify(snapshot).contains("secret-card") and not JSON.stringify(snapshot).contains("secret-route")
			flags["privacy_checked"] = true
			flags["pure_data_checked"] = true
			notes = "private hands, private reasoning, and AI routes never enter postgame output"
	return _record(case_id, passed, notes, flags)


func _compose_fixture() -> Dictionary:
	return _service.call("compose", _source()) as Dictionary if _service != null else {}


func _source() -> Dictionary:
	return {
		"valid": true, "reason": "终局倒计时结束", "winner_name": "测试玩家", "winner_score": 980, "cash_goal": 1200, "city_final_value": 100,
		"top_city_income_name": "测试玩家", "top_city_income_amount": 260, "top_card_income_name": "对手", "top_card_income_amount": 140, "top_role_income_name": "测试玩家", "top_role_income_amount": 90,
		"top_card_impact": "关键卡牌：轨道融资改变GDP", "monster_impact": "怪兽影响：岩甲兽破坏商路", "resolved_card_count": 3,
		"map_facts": {"active_city_count": 3, "destroyed_district_count": 1, "active_monster_count": 1, "monster_count": 2, "key_city": {"valid": true, "name": "关键城市", "owner_name": "测试玩家", "last_income": 88}},
		"money_source_entries": [{"rank": 0, "player_index": 0, "name": "测试玩家", "score": 980, "cash": 720, "base_start_cash": 500, "role_start_bonus": 20, "start_cash": 520, "city_income": 260, "card_income": 80, "role_income": 90, "card_spend": 120, "build_spend": 100, "business_spend": 40, "city_clearance": 200, "active_cities": 2, "gdp_per_minute": 180, "intel_cash": 60, "eliminated": false}, {"rank": 1, "player_index": 1, "name": "对手", "score": 830, "cash": 630, "base_start_cash": 500, "role_start_bonus": 0, "start_cash": 500, "city_income": 180, "card_income": 140, "role_income": 40, "card_spend": 90, "build_spend": 100, "business_spend": 30, "city_clearance": 100, "active_cities": 1, "gdp_per_minute": 90, "intel_cash": 100, "eliminated": false}],
		"rank_entries": [{"player_index": 0, "name": "测试玩家", "score": 980, "cash": 720, "active_cities": 2, "gdp_per_minute": 180, "city_income": 260, "card_income": 80, "intel_cash": 60, "identity": "城市经营"}, {"player_index": 1, "name": "对手", "score": 830, "cash": 630, "active_cities": 1, "gdp_per_minute": 90, "city_income": 180, "card_income": 140, "intel_cash": 100, "identity": "卡牌控制"}],
		"kpi_columns": 4, "money_columns": 2, "rank_columns": 2,
	}


func _debug_snapshot() -> Dictionary:
	return _service.call("debug_snapshot") as Dictionary if _service != null else {}


func _record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var record := {"case_id": case_id, "service_checked": false, "main_checked": false, "summary_checked": false, "board_checked": false, "domain_boundary_checked": false, "routing_checked": false, "performance_checked": false, "privacy_checked": false, "pure_data_checked": false, "deletion_checked": false, "passed": passed, "notes": notes}
	record.merge(flags, true)
	return record


func _array_has_id(entries: Array, id_value: String) -> bool:
	for entry_variant: Variant in entries:
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("id", "")) == id_value:
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
			if str(key_variant).to_lower() in ["owner", "owner_index", "hidden_owner", "private_target", "private_plan", "ai_private_plan", "hand", "private_hand", "private_discard"]:
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
	ownership_text.text = "[b]Scene-owned Final Settlement snapshots[/b]\nFinalSettlementPublicSnapshotService owns the postgame summary, chips, KPIs, money cards, public events, rank track, and after-actions.\n\n[b]Domain authority retained[/b]\nFinal score, ordering, city clearance, intel cash, income totals, and map facts remain supplied.\n\n[b]Retired from main.gd[/b]\n4 postgame presentation formatters.\n\n[b]Real open budget[/b]\n%s ms\n\n[b]Current main metrics[/b]\n%s nonblank lines - %s functions - %s vars - %s constants" % [str(manifest.get("real_open_elapsed_ms", -1)), str(metrics.get("nonblank_lines", 0)), str(metrics.get("function_count", 0)), str(metrics.get("top_level_variable_count", 0)), str(metrics.get("constant_count", 0))]
	var lines: Array[String] = []
	for record_variant: Variant in _records:
		var record := record_variant as Dictionary
		var result := "PASS" if bool(record.get("passed", false)) else "FAIL"
		lines.append("[color=%s][b]%s[/b][/color]  %s\n%s" % ["#4ade80" if result == "PASS" else "#fb7185", result, str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)
	ownership_text.scroll_to_line(0)
	results_text.scroll_to_line(0)
	call_deferred("_reset_report_scroll")


func _reset_report_scroll() -> void:
	ownership_text.scroll_to_line(0)
	results_text.scroll_to_line(0)


func _markdown_report(manifest: Dictionary) -> String:
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	var lines := ["# Final Settlement Public Snapshot Cutover", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Retired formatters: %d" % int(manifest.get("retired_formatter_count", 0)), "- Real open: %dms" % int(manifest.get("real_open_elapsed_ms", -1)), "- Main nonblank lines: %d" % int(metrics.get("nonblank_lines", 0)), "", "| Case | Result | Notes |", "| --- | --- | --- |"]
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
