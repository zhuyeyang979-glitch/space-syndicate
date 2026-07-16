extends Control
class_name IntelDossierPublicSnapshotCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const SERVICE_SCENE := "res://scenes/runtime/IntelDossierPublicSnapshotService.tscn"
const SERVICE_SCRIPT := "res://scripts/runtime/intel_dossier_public_snapshot_service.gd"
const BOARD_SCENE := "res://scenes/ui/IntelDossierBoard.tscn"
const COORDINATOR_SCENE := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/intel_dossier_public_snapshot_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/intel_dossier_public_snapshot_cutover_sprint_21.png"
const CITY_FIXTURES := preload("res://tests/helpers/city_world_fixture_factory.gd")

const RETIRED_FORMATTERS := [
	"_focused_intel_card_action_snapshots", "_intel_dossier_chip_snapshots", "_focused_intel_card_guess_entry",
	"_focused_intel_card_evidence_card", "_focused_intel_card_evidence_lines", "_intel_card_guess_time_text",
	"_focused_intel_card_private_note", "_intel_dossier_kpi_snapshots", "_intel_board_city_lines",
	"_intel_board_card_lines", "_intel_board_monster_lines", "_intel_board_warehouse_lines",
	"_intel_board_public_city_clue_lines", "_intel_board_next_step_lines", "_add_intel_dossier_link_button",
	"_add_intel_city_guess_buttons", "_populate_intel_dossier_links", "_intel_dossier_board_snapshot",
	"_intel_city_guess_line", "_player_city_guess_confidence_summary", "_player_city_guess_reason_summary",
	"_intel_card_guess_line",
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
		"required_service_assets_load", "service_scene_contract", "intel_source_pure_data", "empty_source_safe",
		"summary_privacy_contract", "header_chip_contract", "kpi_contract", "focused_evidence_contract",
		"track_action_compatibility", "city_mark_action_ids", "confidence_action_ids", "reason_action_ids",
		"public_link_action_ids", "board_signal_forwarding", "coordinator_scene_composition", "coordinator_pure_data_proxy",
		"real_main_route_and_render", "open_performance_contract", "legacy_builders_absent_and_metrics", "private_input_rejection",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {"suite": "intel-dossier-public-snapshot-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": records.size(), "retired_formatter_count": RETIRED_FORMATTERS.size(), "records": records}


func run_cutover_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	_main_source = FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	await _prepare_runtime()
	for case_id_variant in cutover_cases():
		var case_id := str(case_id_variant)
		var record := await _run_case(case_id)
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "failed"))])
	var manifest := {"suite": "intel-dossier-public-snapshot-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": _records.size(), "passed_count": _passed_count(), "retired_formatter_count": RETIRED_FORMATTERS.size(), "real_open_elapsed_ms": _real_open_elapsed_ms, "main_metrics": _main_metrics(), "records": _records.duplicate(true)}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await _dispose_runtime()
	_save_screenshot()
	print("IntelDossierPublicSnapshotCutoverBench manifest: %s" % MANIFEST_PATH)
	print("IntelDossierPublicSnapshotCutoverBench report: %s" % REPORT_PATH)
	print("IntelDossierPublicSnapshotCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("IntelDossierPublicSnapshotCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	print("IntelDossierPublicSnapshotCutoverBench real open: %dms" % _real_open_elapsed_ms)
	if not _failures.is_empty():
		push_error("IntelDossierPublicSnapshotCutoverBench failed:\n- %s" % "\n- ".join(_failures))
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
		_seed_real_intel_city()
		await get_tree().process_frame
		_real_source = _main.call("_intel_dossier_public_source_snapshot", 0) as Dictionary
		_real_snapshot = _main.call("_intel_dossier_public_snapshot", 0) as Dictionary
		var started := Time.get_ticks_msec()
		_main.call("_open_intel_dossier_menu")
		_real_open_elapsed_ms = Time.get_ticks_msec() - started
	await get_tree().process_frame
	await get_tree().process_frame


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	var fixture := _compose_fixture()
	var board := fixture.get("board", {}) as Dictionary
	var ids := _action_ids(board)
	match case_id:
		"required_service_assets_load":
			passed = load(SERVICE_SCRIPT) is Script and load(SERVICE_SCENE) is PackedScene and load(BOARD_SCENE) is PackedScene and load(COORDINATOR_SCENE) is PackedScene
			flags["service_checked"] = true
			notes = "service, editable dossier board, and coordinator assets load"
		"service_scene_contract":
			var debug := _debug_snapshot()
			passed = _service != null and _service.has_method("configure") and _service.has_method("compose") and _service.has_method("debug_snapshot")
			passed = passed and not bool(debug.get("mutates_city_guesses", true)) and not bool(debug.get("settles_intel_cash", true)) and not bool(debug.get("reveals_city_owner_truth", true)) and not bool(debug.get("reveals_card_owner_truth", true)) and not bool(debug.get("reads_private_hands", true)) and not bool(debug.get("navigates_runtime_nodes", true)) and bool(debug.get("action_id_controls", false))
			flags["domain_boundary_checked"] = true
			notes = "service owns public presentation and intent ids, not intel rules or navigation"
		"intel_source_pure_data":
			passed = bool(_real_source.get("valid", false)) and _is_pure_data(_real_source) and not _contains_private_key(_real_source)
			flags["main_checked"] = true
			flags["pure_data_checked"] = true
			flags["privacy_checked"] = true
			notes = "real main supplies one viewer-safe bounded intel fact snapshot"
		"empty_source_safe":
			var empty_snapshot: Dictionary = _service.call("compose", {"valid": false, "reason": "无玩家"}) if _service != null else {}
			passed = str(empty_snapshot.get("summary_text", "")).contains("无玩家") and _action_ids(empty_snapshot.get("board", {}) as Dictionary).has("intel_open_economy")
			flags["summary_checked"] = true
			notes = "empty dossier remains readable and keeps a safe economy link"
		"summary_privacy_contract":
			var text := str(fixture.get("summary_text", ""))
			passed = text.contains("情报换钱") and text.contains("当前不揭示正误") and text.contains("不扫描对手现金/手牌") and not text.contains("真实业主")
			flags["summary_checked"] = true
			flags["privacy_checked"] = true
			notes = "summary explains settlement and evidence without revealing hidden truth"
		"header_chip_contract":
			var chips := board.get("chips", []) as Array
			passed = chips.size() == 4 and str((chips[0] as Dictionary).get("text", "")).contains("已选牌轨") and str((chips[2] as Dictionary).get("text", "")).contains("即时竞猜")
			flags["board_checked"] = true
			notes = "focused-track, settlement, stake, and privacy chips are scene payloads"
		"kpi_contract":
			var kpis := board.get("kpis", []) as Array
			passed = kpis.size() == 4 and JSON.stringify(kpis).contains("城市标注") and JSON.stringify(kpis).contains("公开资金线索")
			flags["board_checked"] = true
			notes = "four compact intel KPIs come from the service"
		"focused_evidence_contract":
			var clues := board.get("clues", []) as Array
			passed = clues.size() == 7 and JSON.stringify(clues[0]).contains("已选牌轨证据链") and JSON.stringify(clues[0]).contains("出价记录") and JSON.stringify(clues[0]).contains("私人推理")
			flags["board_checked"] = true
			notes = "focused anonymous-card evidence remains first and viewer-scoped"
		"track_action_compatibility":
			passed = ids.has("track_return_42") and ids.has("track_guess_42") and ids.has("track_open_轨道融资1")
			flags["action_id_checked"] = true
			notes = "existing track_return, track_guess, and track_open ids remain unchanged"
		"city_mark_action_ids":
			passed = ids.has("intel_city_mark_3_1") and ids.has("intel_city_mark_3_2") and ids.has("intel_city_clear_3")
			flags["action_id_checked"] = true
			notes = "city owner mark and clear controls are data-only ids"
		"confidence_action_ids":
			passed = ids.has("intel_city_confidence_3_1") and ids.has("intel_city_confidence_3_2") and ids.has("intel_city_confidence_3_3")
			flags["action_id_checked"] = true
			notes = "confidence controls preserve low, medium, and high intent"
		"reason_action_ids":
			passed = ids.has("intel_city_reason_3_product") and ids.has("intel_city_reason_3_card")
			flags["action_id_checked"] = true
			notes = "reason controls carry stable reason ids without Callables"
		"public_link_action_ids":
			passed = ids.has("intel_open_region_3") and ids.has("intel_open_card_轨道融资1") and ids.has("intel_open_monster_2") and ids.has("intel_open_product_活体芯片") and ids.has("intel_open_economy")
			flags["routing_checked"] = true
			notes = "region, card, monster, product, and economy navigation are intent ids"
		"board_signal_forwarding":
			passed = await _board_signal_forwarding_checked(board)
			flags["board_checked"] = true
			flags["action_id_checked"] = true
			notes = "scene-owned buttons emit action_requested(action_id)"
		"coordinator_scene_composition":
			var node := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/IntelDossierPublicSnapshotService") if _main != null else null
			passed = node != null and node.scene_file_path == SERVICE_SCENE
			flags["service_checked"] = true
			flags["main_checked"] = true
			notes = "real main composition owns one editable intel snapshot service"
		"coordinator_pure_data_proxy":
			var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
			var snapshot: Variant = coordinator.call("compose_intel_dossier_snapshot", _source()) if coordinator != null else {}
			passed = coordinator != null and _is_pure_data(snapshot) and not _contains_private_key(snapshot)
			flags["pure_data_checked"] = true
			flags["privacy_checked"] = true
			notes = "coordinator returns a duplicated viewer-safe dossier snapshot"
		"real_main_route_and_render":
			passed = await _real_main_route_and_render_checked()
			flags["main_checked"] = true
			flags["routing_checked"] = true
			flags["action_id_checked"] = true
			notes = "real intel menu renders controls/links and routes a scene-owned mark action id"
		"open_performance_contract":
			passed = _real_open_elapsed_ms >= 0 and _real_open_elapsed_ms < 5000
			flags["performance_checked"] = true
			notes = "real intel menu opens below the five-second gate (%dms)" % _real_open_elapsed_ms
		"legacy_builders_absent_and_metrics":
			passed = RETIRED_FORMATTERS.size() == 22
			for formatter_name in RETIRED_FORMATTERS:
				passed = passed and not _main_source.contains("func %s(" % str(formatter_name))
			var metrics := _main_metrics()
			passed = passed and int(metrics.get("nonblank_lines", 999999)) < 39882 and int(metrics.get("function_count", 999999)) < 1969 and int(metrics.get("top_level_variable_count", 999999)) <= 192 and int(metrics.get("constant_count", 999999)) <= 318
			flags["deletion_checked"] = true
			notes = "twenty-two legacy formatters/builders are absent and main.gd shrinks below Sprint 20"
		"private_input_rejection":
			var injected := _source()
			injected["hidden_owner"] = 7
			injected["private_hand"] = ["secret-card"]
			injected["ai_private_plan"] = "secret-route"
			var snapshot: Dictionary = _service.call("compose", injected) if _service != null else {}
			passed = _is_pure_data(snapshot) and not _contains_private_key(snapshot) and not JSON.stringify(snapshot).contains("secret-card") and not JSON.stringify(snapshot).contains("secret-route")
			flags["privacy_checked"] = true
			flags["pure_data_checked"] = true
			notes = "hidden owners, private hands, and AI plans never enter dossier output"
	return _record(case_id, passed, notes, flags)


func _seed_real_intel_city() -> void:
	if _main == null:
		return
	var players_variant: Variant = ((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players
	var districts_variant: Variant = ((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts
	if not (players_variant is Array) or (players_variant as Array).size() < 2 or not (districts_variant is Array):
		return
	var districts := districts_variant as Array
	for district_index in range(districts.size()):
		var district := districts[district_index] as Dictionary if districts[district_index] is Dictionary else {}
		if str(district.get("terrain", "land")) == "ocean" or bool(district.get("destroyed", false)) or not (district.get("city", {}) as Dictionary).is_empty():
			continue
		CITY_FIXTURES.create_city_bool(_main, 1, district_index, "Intel dossier fixture")
		return


func _real_main_route_and_render_checked() -> bool:
	if _main == null or not (_real_snapshot.get("board", {}) is Dictionary):
		return false
	var panel := _main.find_child("IntelDossierBoardPanel", true, false)
	if panel == null or panel.find_child("IntelDossierControlGrid", true, false) == null or panel.find_child("IntelDossierLinkGrid", true, false) == null:
		return false
	var city_entries := _real_source.get("city_entries", []) as Array if _real_source.get("city_entries", []) is Array else []
	if city_entries.is_empty():
		return false
	var district_index := int((city_entries[0] as Dictionary).get("district_index", -1))
	var mark_button: Button = null
	var region_button: Button = null
	for node_variant in panel.find_children("*", "Button", true, false):
		var button := node_variant as Button
		if button.text.begins_with("标玩家") and mark_button == null:
			mark_button = button
		if button.text.contains("查看区域线索") and region_button == null:
			region_button = button
	if district_index < 0 or mark_button == null or region_button == null:
		return false
	mark_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var players := ((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array
	if players.is_empty():
		return false
	var guesses := (players[0] as Dictionary).get("city_guesses", {}) as Dictionary
	return int(guesses.get(district_index, -1)) >= 0


func _board_signal_forwarding_checked(board_snapshot: Dictionary) -> bool:
	var packed := load(BOARD_SCENE) as PackedScene
	var board := packed.instantiate() as Control if packed != null else null
	if board == null:
		return false
	add_child(board)
	var emitted := []
	board.connect("action_requested", func(action_id: String) -> void: emitted.append(action_id))
	board.call("set_dossier", board_snapshot)
	await get_tree().process_frame
	var button := board.find_child("IntelDossierControlActionButton", true, false) as Button
	if button != null and not button.disabled:
		button.emit_signal("pressed")
	await get_tree().process_frame
	board.queue_free()
	await get_tree().process_frame
	return not emitted.is_empty() and str(emitted[0]).begins_with("intel_city_")


func _compose_fixture() -> Dictionary:
	return _service.call("compose", _source()) as Dictionary if _service != null else {}


func _source() -> Dictionary:
	return {
		"valid": true, "viewer_index": 0, "viewer_name": "测试玩家", "business_cycle_count": 3,
		"correct_guess_cash": 120, "wrong_guess_cost": 60, "card_guess_stake": 100, "city_final_value": 200,
		"stats": {"total_foreign": 2, "guessed": 1, "unmarked": 1, "best_cash": 120, "worst_cash": -60},
		"player_options": [{"player_index": 1, "label": "标玩家2"}, {"player_index": 2, "label": "标玩家3"}],
		"confidence_options": [{"value": 1, "label": "低"}, {"value": 2, "label": "中"}, {"value": 3, "label": "高"}],
		"reason_options": [{"id": "product", "label": "商品竞争"}, {"id": "card", "label": "卡牌条件"}],
		"city_entries": [{"district_index": 3, "name": "环城港", "guess": 1, "marked": true, "confidence": 2, "confidence_label": "中", "reason": "card", "reason_label": "卡牌条件", "priority": 88, "potential_income": 210, "warehouse_pressure": 24, "latest_clue": "活体芯片需求上升"}],
		"card_entries": [{"resolution_id": 42, "card": "轨道融资1", "card_name": "轨道融资1", "track_state": "已结算", "status": "归属待猜，可押注¥100", "target": "环城港", "requirement": "城市化份额10%", "tip": "报价¥20", "aftermath": "GDP上升", "style": "经济", "time": 12.5, "revealed": false, "focused": true}],
		"monster_entries": [{"slot": 0, "name": "吞星兽", "catalog_index": 2, "owner_text": "归属未公开", "recent_loss": 30, "total_lost": 60, "cash_pool": 140, "cash_total": 200, "clue": "受伤资金线索"}],
		"warehouse_entries": [{"name": "环城港", "owner_view": "未知业主", "pressure": 24, "count": 1, "units": 3, "products": ["活体芯片"], "latest_clue": "匿名仓储3单位"}],
		"city_clue_entries": [{"district": "环城港", "kind": "需求", "clue_products": ["活体芯片"], "linked_product": "活体芯片", "owner_visible": false, "income": 80, "clue": "需求上升"}],
		"kpi_columns": 4, "clue_columns": 3, "control_columns": 1, "link_columns": 2,
	}


func _action_ids(board: Dictionary) -> Array:
	var ids := []
	for entry_variant in board.get("actions", []) as Array: ids.append(str((entry_variant as Dictionary).get("id", "")))
	for group_variant in board.get("control_groups", []) as Array:
		for entry_variant in (group_variant as Dictionary).get("actions", []) as Array: ids.append(str((entry_variant as Dictionary).get("id", "")))
	for entry_variant in board.get("links", []) as Array: ids.append(str((entry_variant as Dictionary).get("id", "")))
	return ids


func _debug_snapshot() -> Dictionary:
	return _service.call("debug_snapshot") as Dictionary if _service != null else {}


func _record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var record := {"case_id": case_id, "service_checked": false, "main_checked": false, "summary_checked": false, "board_checked": false, "domain_boundary_checked": false, "action_id_checked": false, "routing_checked": false, "performance_checked": false, "privacy_checked": false, "pure_data_checked": false, "deletion_checked": false, "passed": passed, "notes": notes}
	record.merge(flags, true)
	return record


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT: return false
	if value is Dictionary:
		for key_variant in value:
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]): return false
	elif value is Array:
		for item_variant in value:
			if not _is_pure_data(item_variant): return false
	return true


func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in value:
			if str(key_variant).to_lower() in ["owner", "owner_index", "hidden_owner", "private_target", "private_plan", "ai_private_plan", "hand", "private_hand", "private_discard"]: return true
			if _contains_private_key(value[key_variant]): return true
	elif value is Array:
		for item_variant in value:
			if _contains_private_key(item_variant): return true
	return false


func _main_metrics() -> Dictionary:
	var nonblank_lines := 0
	var function_count := 0
	var variable_count := 0
	var constant_count := 0
	for line_variant in _main_source.split("\n"):
		var line := str(line_variant)
		if not line.strip_edges().is_empty(): nonblank_lines += 1
		if line.begins_with("func "): function_count += 1
		elif line.begins_with("var "): variable_count += 1
		elif line.begins_with("const "): constant_count += 1
	return {"nonblank_lines": nonblank_lines, "function_count": function_count, "top_level_variable_count": variable_count, "constant_count": constant_count}


func _passed_count() -> int:
	var count := 0
	for record_variant in _records:
		if bool((record_variant as Dictionary).get("passed", false)): count += 1
	return count


func _update_ui(manifest: Dictionary) -> void:
	var passed := int(manifest.get("passed_count", 0))
	var total := int(manifest.get("record_count", 0))
	status_label.text = "PASS" if passed == total else "FAIL"
	status_label.modulate = Color("#4ade80") if passed == total else Color("#fb7185")
	summary_label.text = "%d/%d ownership cases passed" % [passed, total]
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	ownership_text.text = "[b]Scene-owned Intel Dossier[/b]\nIntelDossierPublicSnapshotService owns summary, evidence cards, controls, links, and action ids.\n\n[b]Domain authority retained[/b]\nCity guesses, confidence/reason mutation, card wagers, hidden truth, settlement, and Codex navigation remain runtime-owned.\n\n[b]Retired from main.gd[/b]\n22 presentation formatters and runtime UI builders.\n\n[b]Real open budget[/b]\n%s ms\n\n[b]Current main metrics[/b]\n%s nonblank lines - %s functions - %s vars - %s constants" % [str(manifest.get("real_open_elapsed_ms", -1)), str(metrics.get("nonblank_lines", 0)), str(metrics.get("function_count", 0)), str(metrics.get("top_level_variable_count", 0)), str(metrics.get("constant_count", 0))]
	var lines: Array[String] = []
	for record_variant in _records:
		var record := record_variant as Dictionary
		var result := "PASS" if bool(record.get("passed", false)) else "FAIL"
		lines.append("[color=%s]%s[/color]  [b]%s[/b]\n%s" % ["#4ade80" if result == "PASS" else "#fb7185", result, str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)
	call_deferred("_reset_report_scroll")


func _reset_report_scroll() -> void:
	ownership_text.scroll_to_line(0)
	results_text.scroll_to_line(0)


func _markdown_report(manifest: Dictionary) -> String:
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	var lines := ["# Intel Dossier Public Snapshot Cutover", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Retired formatters/builders: %d" % int(manifest.get("retired_formatter_count", 0)), "- Real open: %dms" % int(manifest.get("real_open_elapsed_ms", -1)), "- Main nonblank lines: %d" % int(metrics.get("nonblank_lines", 0)), "", "| Case | Result | Notes |", "| --- | --- | --- |"]
	for record_variant in manifest.get("records", []):
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
		for player_variant in _main.find_children("*", "AudioStreamPlayer", true, false):
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
