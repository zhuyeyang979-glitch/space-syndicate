extends Control
class_name StandingsPublicSnapshotCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const SERVICE_SCENE := "res://scenes/runtime/StandingsPublicSnapshotService.tscn"
const SERVICE_SCRIPT := "res://scripts/runtime/standings_public_snapshot_service.gd"
const SCOREBOARD_SCENE := "res://scenes/ui/StandingsScoreboard.tscn"
const COORDINATOR_SCENE := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/standings_public_snapshot_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/standings_public_snapshot_cutover_sprint_19.png"

const RETIRED_FORMATTERS := [
	"_standings_text",
	"_standings_scoreboard_snapshot",
	"_standings_scoreboard_chip_snapshots",
	"_standings_scoreboard_seat_snapshots",
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
		"required_service_assets_load", "service_scene_contract", "standings_source_pure_data", "empty_source_safe",
		"summary_read_order_contract", "overview_card_contract", "scoreboard_chip_contract", "scoreboard_kpi_contract",
		"selected_seat_visibility", "opponent_privacy_contract", "bankrupt_public_contract", "final_visibility_contract",
		"bounded_eight_seat_contract", "coordinator_scene_composition", "coordinator_pure_data_proxy", "real_main_route_and_render",
		"open_performance_contract", "legacy_formatters_absent", "main_metrics_reduced", "output_pure_data_contract",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant: Variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {"suite": "standings-public-snapshot-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": records.size(), "retired_formatter_count": RETIRED_FORMATTERS.size(), "records": records}


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
	var manifest := {"suite": "standings-public-snapshot-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": _records.size(), "passed_count": _passed_count(), "retired_formatter_count": RETIRED_FORMATTERS.size(), "real_open_elapsed_ms": _real_open_elapsed_ms, "main_metrics": _main_metrics(), "records": _records.duplicate(true)}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await _dispose_runtime()
	_save_screenshot()
	print("StandingsPublicSnapshotCutoverBench manifest: %s" % MANIFEST_PATH)
	print("StandingsPublicSnapshotCutoverBench report: %s" % REPORT_PATH)
	print("StandingsPublicSnapshotCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("StandingsPublicSnapshotCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	print("StandingsPublicSnapshotCutoverBench real open: %dms" % _real_open_elapsed_ms)
	if not _failures.is_empty():
		push_error("StandingsPublicSnapshotCutoverBench failed:\n- %s" % "\n- ".join(_failures))
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
		var query := _main.get_node_or_null("RuntimeServices/StandingsPublicQueryPort") as StandingsPublicQueryPort
		var controller := _main.get_node_or_null("RuntimeServices/StandingsApplicationFlowController") as StandingsApplicationFlowController
		_real_snapshot = query.snapshot_for_authorized_viewer(960.0) if query != null else {}
		_real_source = _real_snapshot.duplicate(true)
		var started := Time.get_ticks_msec()
		if controller != null:
			controller.open_standings()
		_real_open_elapsed_ms = Time.get_ticks_msec() - started
	await get_tree().process_frame
	await get_tree().process_frame


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	var fixture := _compose_fixture()
	var scoreboard := fixture.get("scoreboard", {}) as Dictionary
	var seats := scoreboard.get("seats", []) as Array
	match case_id:
		"required_service_assets_load":
			passed = load(SERVICE_SCRIPT) is Script and load(SERVICE_SCENE) is PackedScene and load(SCOREBOARD_SCENE) is PackedScene and load(COORDINATOR_SCENE) is PackedScene
			flags["service_checked"] = true
			notes = "service, editable scoreboard, and coordinator assets load"
		"service_scene_contract":
			var debug := _debug_snapshot()
			passed = _service != null and _service.has_method("configure") and _service.has_method("compose") and _service.has_method("debug_snapshot")
			passed = passed and bool(debug.get("consumes_victory_snapshot", false)) and not bool(debug.get("calculates_region_control", true)) and not bool(debug.get("calculates_top_n_gdp", true)) and not bool(debug.get("sorts_final_rankings", true)) and not bool(debug.get("evaluates_private_truth", true)) and not bool(debug.get("reads_runtime_nodes", true)) and not bool(debug.get("legacy_cash_goal_presentation_active", true))
			flags["service_checked"] = true
			flags["domain_boundary_checked"] = true
			notes = "service owns presentation only; scoring, GDP, cash, and final ranking remain domain-owned"
		"standings_source_pure_data":
			passed = not _real_source.is_empty() and _is_pure_data(_real_source) and not _contains_private_key(_real_source)
			var real_scoreboard := _real_source.get("scoreboard", {}) as Dictionary
			var real_seats := real_scoreboard.get("seats", []) as Array
			passed = passed and real_seats.size() <= 8
			flags["main_checked"] = true
			flags["pure_data_checked"] = true
			flags["privacy_checked"] = true
			notes = "the scene-owned query port supplies one bounded viewer-safe standings snapshot"
		"empty_source_safe":
			var empty_snapshot: Dictionary = _service.call("compose", {"valid": false}) if _service != null else {}
			passed = str(empty_snapshot.get("summary_text", "")).contains("还没有可用玩家数据") and (empty_snapshot.get("overview_cards", []) as Array).size() == 1
			flags["summary_checked"] = true
			notes = "empty standings state stays readable and safe"
		"summary_read_order_contract":
			var text := str(fixture.get("summary_text", ""))
			passed = text.contains("局势排名") and text.contains("控制4个区域") and text.contains("Top-N个人归属GDP达到130/min") and text.contains("120秒公开审计") and text.contains("我的进度") and text.contains("未进入审计名单的对手资产继续保密")
			flags["summary_checked"] = true
			notes = "one scene service composes the full public standings read order"
		"overview_card_contract":
			var cards := fixture.get("overview_cards", []) as Array
			passed = cards.size() == 3 and _array_has_title(cards, "区域控制") and _array_has_title(cards, "胜利门槛") and _array_has_title(cards, "审计状态")
			flags["scoreboard_checked"] = true
			notes = "three former main-generated cards now belong to StandingsScoreboard"
		"scoreboard_chip_contract":
			var chips := scoreboard.get("chips", []) as Array
			passed = chips.size() == 4 and str((chips[0] as Dictionary).get("text", "")) == "控区4" and str((chips[1] as Dictionary).get("text", "")) == "Top-N 130/min" and str((chips[2] as Dictionary).get("text", "")).contains("公开审计") and str((chips[3] as Dictionary).get("text", "")) == "名单明牌"
			flags["scoreboard_checked"] = true
			notes = "goal, countdown, city value, and privacy chips remain stable"
		"scoreboard_kpi_contract":
			var kpis := scoreboard.get("kpis", []) as Array
			passed = kpis.size() == 4 and str((kpis[0] as Dictionary).get("value", "")) == "145/130" and str((kpis[1] as Dictionary).get("value", "")) == "4/4区" and str((kpis[2] as Dictionary).get("value", "")) == "1席" and _array_has_title(kpis, "公开异动")
			flags["scoreboard_checked"] = true
			flags["domain_boundary_checked"] = true
			notes = "supplied score, city, GDP, and public-shift facts are displayed without recalculation"
		"selected_seat_visibility":
			passed = seats.size() == 3 and str((seats[0] as Dictionary).get("score", "")) == "Top-N 145" and JSON.stringify(seats[0]).contains("账本¥610.00") and JSON.stringify(seats[0]).contains("控区4")
			flags["privacy_checked"] = true
			flags["scoreboard_checked"] = true
			notes = "current player receives precise viewer-owned score, cash, city, and GDP facts"
		"opponent_privacy_contract":
			var opponent_text := JSON.stringify(seats[1]) if seats.size() > 1 else ""
			passed = opponent_text.contains("进度隐藏") and opponent_text.contains("未入审计") and opponent_text.contains("经济资产保密") and not opponent_text.contains("73000") and not opponent_text.contains("secret")
			flags["privacy_checked"] = true
			flags["scoreboard_checked"] = true
			notes = "opponent score, cash, hand, and private reasoning never enter the output"
		"bankrupt_public_contract":
			var bankrupt_text := JSON.stringify(seats[2]) if seats.size() > 2 else ""
			passed = bankrupt_text.contains("出局") and bankrupt_text.contains("已淘汰") and bankrupt_text.contains("不能进入审计终点排名") and not bankrupt_text.contains("现金")
			flags["privacy_checked"] = true
			flags["scoreboard_checked"] = true
			notes = "bankruptcy remains a public state without revealing historical private data"
		"final_visibility_contract":
			var final_source := _source()
			final_source["game_over"] = true
			final_source["final_summary_text"] = "终局总结｜公开结算完成"
			var final_victory := final_source.get("victory_control", {}) as Dictionary
			final_victory["audit_roster"] = [0, 1]
			(final_victory.get("audit_entries", []) as Array).append({"player_index": 1, "top_n_gdp_per_minute": 120, "controlled_region_count": 3, "cash_ledger_cents": 73000, "economic_assets": {"project_positions": [], "contracts": [], "warehouses": [], "financial_positions": []}})
			var final_snapshot: Dictionary = _service.call("compose", final_source) if _service != null else {}
			var final_board := final_snapshot.get("scoreboard", {}) as Dictionary
			var final_output_seats := final_board.get("seats", []) as Array
			passed = str(final_snapshot.get("summary_text", "")).contains("终局总结") and str((final_output_seats[1] as Dictionary).get("score", "")) == "Top-N 120" and JSON.stringify(final_output_seats[1]).contains("账本¥730.00")
			flags["scoreboard_checked"] = true
			flags["domain_boundary_checked"] = true
			notes = "domain-supplied final visibility is rendered without service-owned ranking logic"
		"bounded_eight_seat_contract":
			var crowded_source := _source()
			var crowded_seats := crowded_source.get("seat_entries", []) as Array
			for index in range(3, 12):
				crowded_seats.append({"player_index": index, "name": "席位%d" % (index + 1), "eliminated": false, "can_view_private": false})
			var crowded_snapshot: Dictionary = _service.call("compose", crowded_source) if _service != null else {}
			passed = (((crowded_snapshot.get("scoreboard", {}) as Dictionary).get("seats", []) as Array).size() == 8)
			flags["pure_data_checked"] = true
			notes = "service bounds standings presentation to the supported eight seats"
		"coordinator_scene_composition":
			var node := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/StandingsPublicSnapshotService") if _main != null else null
			passed = node != null and node.scene_file_path == SERVICE_SCENE
			flags["service_checked"] = true
			flags["main_checked"] = true
			notes = "real main composition owns one editable standings snapshot service"
		"coordinator_pure_data_proxy":
			var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
			var snapshot: Variant = coordinator.call("compose_standings_snapshot", _source()) if coordinator != null else {}
			passed = coordinator != null and _is_pure_data(snapshot) and not _contains_private_key(snapshot)
			flags["pure_data_checked"] = true
			flags["privacy_checked"] = true
			notes = "coordinator returns a duplicated pure-data standings presentation"
		"real_main_route_and_render":
			var panel := _main.find_child("StandingsScoreboardPanel", true, false) if _main != null else null
			passed = str(_real_snapshot.get("summary_text", "")).contains("局势排名") and _real_snapshot.get("scoreboard", {}) is Dictionary and panel != null and panel.find_child("StandingsOverviewGrid", true, false) != null
			flags["main_checked"] = true
			flags["routing_checked"] = true
			notes = "real standings menu delegates once and renders the editable scoreboard with overview grid"
		"open_performance_contract":
			passed = _real_open_elapsed_ms >= 0 and _real_open_elapsed_ms < 5000
			flags["performance_checked"] = true
			notes = "real standings menu opens below the five-second gate (%dms)" % _real_open_elapsed_ms
		"legacy_formatters_absent":
			passed = RETIRED_FORMATTERS.size() == 4
			for formatter_name: String in RETIRED_FORMATTERS:
				passed = passed and not _main_source.contains("func %s(" % formatter_name)
			flags["deletion_checked"] = true
			notes = "four legacy standings presentation formatters are absent from main.gd"
		"main_metrics_reduced":
			var metrics := _main_metrics()
			passed = int(metrics.get("nonblank_lines", 999999)) < 40063 and int(metrics.get("function_count", 999999)) < 1971 and int(metrics.get("top_level_variable_count", 999999)) <= 192 and int(metrics.get("constant_count", 999999)) <= 318
			flags["deletion_checked"] = true
			notes = "main.gd shrinks below the Sprint 18 baseline in lines and functions"
		"output_pure_data_contract":
			passed = _is_pure_data(fixture) and not _contains_private_key(fixture) and not JSON.stringify(fixture).contains("secret-rival-plan")
			flags["pure_data_checked"] = true
			flags["privacy_checked"] = true
			notes = "all service output remains pure data and drops unknown private source fields"
	return _record(case_id, passed, notes, flags)


func _compose_fixture() -> Dictionary:
	return _service.call("compose", _source()) as Dictionary if _service != null else {}


func _source() -> Dictionary:
	return {
		"valid": true, "game_over": false, "selected_available": true, "selected_top_n_gdp_per_minute": 145,
		"selected_controlled_region_count": 4, "selected_cash": 610, "selected_city_count": 2,
		"selected_gdp_per_minute": 180, "selected_intel_summary": "情报待结算",
		"required_top_n_gdp_per_minute": 130, "required_controlled_region_count": 4,
		"victory_control": {"state": "audit", "audit_remaining_seconds": 90.0, "audit_roster": [0], "audit_entries": [{"player_index": 0, "top_n_gdp_per_minute": 145, "controlled_region_count": 4, "cash_ledger_cents": 61000, "economic_assets": {"project_positions": [{"slot_id": "production:0"}], "contracts": [], "warehouses": [], "financial_positions": []}}]},
		"countdown_text": "公开审计剩余90.0秒", "public_shift_count": 5, "overview_columns": 3, "kpi_columns": 4, "seat_columns": 3,
		"seat_entries": [
			{"player_index": 0, "name": "测试玩家", "eliminated": false, "can_view_private": true, "cash": 610, "active_cities": 2, "top_n_gdp_per_minute": 145, "controlled_region_count": 4, "intel_summary": "情报待结算", "gdp_per_minute": 180},
			{"player_index": 1, "name": "对手", "eliminated": false, "can_view_private": false},
			{"player_index": 2, "name": "破产席位", "eliminated": true, "can_view_private": false},
		],
		"final_summary_text": "", "private_plan": "secret-rival-plan",
	}


func _debug_snapshot() -> Dictionary:
	return _service.call("debug_snapshot") as Dictionary if _service != null else {}


func _record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var record := {"case_id": case_id, "service_checked": false, "main_checked": false, "summary_checked": false, "scoreboard_checked": false, "domain_boundary_checked": false, "routing_checked": false, "performance_checked": false, "privacy_checked": false, "pure_data_checked": false, "deletion_checked": false, "passed": passed, "notes": notes}
	record.merge(flags, true)
	return record


func _array_has_title(entries: Array, title_value: String) -> bool:
	for entry_variant: Variant in entries:
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("title", "")) == title_value:
			return true
	return false


func _private_opponents_are_redacted(entries: Array) -> bool:
	for entry_variant: Variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if not bool(entry.get("can_view_private", false)) and not bool(entry.get("eliminated", false)):
			for key in ["cash", "score", "active_cities", "gdp_per_minute", "intel_summary"]:
				if entry.has(key):
					return false
	return true


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
			if str(key_variant).to_lower() in ["owner", "owner_index", "hidden_owner", "hidden_owner_id", "private_target", "private_plan", "ai_private_plan", "hand", "private_discard"]:
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
	ownership_text.text = "[b]Scene-owned Standings snapshots[/b]\nStandingsPublicSnapshotService owns the public summary, overview cards, chips, KPIs, and viewer-safe seat cards.\n\n[b]Domain authority retained[/b]\nCash, city count, GDP, settlement estimates, final ordering, and private truth remain supplied facts.\n\n[b]Retired from main.gd[/b]\n4 Standings presentation formatters and the runtime-created overview grid.\n\n[b]Real open budget[/b]\n%s ms\n\n[b]Current main metrics[/b]\n%s nonblank lines - %s functions - %s vars - %s constants" % [str(manifest.get("real_open_elapsed_ms", -1)), str(metrics.get("nonblank_lines", 0)), str(metrics.get("function_count", 0)), str(metrics.get("top_level_variable_count", 0)), str(metrics.get("constant_count", 0))]
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
	var lines := ["# Standings Public Snapshot Cutover", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Retired formatters: %d" % int(manifest.get("retired_formatter_count", 0)), "- Real open: %dms" % int(manifest.get("real_open_elapsed_ms", -1)), "- Main nonblank lines: %d" % int(metrics.get("nonblank_lines", 0)), "", "| Case | Result | Notes |", "| --- | --- | --- |"]
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
