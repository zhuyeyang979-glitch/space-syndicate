extends Control
class_name NewGameSetupPageCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const PAGE_SCENE_PATH := "res://scenes/ui/NewGameSetupPage.tscn"
const PAGE_SCRIPT_PATH := "res://scripts/ui/new_game_setup_page.gd"
const LOBBY_SCENE_PATH := "res://scenes/ui/NewGameSetupLobby.tscn"
const OPTION_BOARD_SCENE_PATH := "res://scenes/ui/NewGameSetupOptionBoard.tscn"
const SEAT_CARD_SCENE_PATH := "res://scenes/ui/NewGameSetupSeatCard.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/new_game_setup_page_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/new_game_setup_page_cutover_sprint_22.png"

const RETIRED_BUILDERS := [
	"_add_new_game_setup_lobby_panel",
	"_on_new_game_setup_option_selected",
	"_add_new_game_setup_option_board",
	"_add_new_game_setup_summary_chips",
	"_new_game_setup_seat_grid_columns",
	"_add_new_game_setup_seat_card",
	"_set_configured_role_random_for_player_from_new_game_menu",
]

const RETIRED_PRELOADS := [
	"NewGameSetupLobbyScene",
	"NewGameSetupOptionBoardScene",
	"NewGameSetupSeatCardScene",
]

@export var auto_run := true

@onready var status_label: Label = %StatusLabel
@onready var summary_label: Label = %SummaryLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var results_text: RichTextLabel = %ResultsText

var _page: Control
var _main: Control
var _real_page: Control
var _main_source := ""
var _real_snapshot: Dictionary = {}
var _page_emitted_actions: Array[String] = []
var _records: Array = []
var _failures: Array[String] = []
var _real_open_elapsed_ms := -1


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_cutover_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func retired_builder_names() -> Array:
	return RETIRED_BUILDERS.duplicate()


func cutover_cases() -> Array:
	return [
		"required_assets_load", "page_scene_contract", "summary_chip_contract", "lobby_composition",
		"option_board_composition", "seat_scroll_contract", "seat_card_count", "two_column_layout",
		"player_count_action_id", "ai_count_action_id", "challenge_depth_action_id", "role_step_action_id",
		"role_random_action_id", "monster_step_action_id", "primary_action_ids", "real_main_route_and_render",
		"real_main_action_routing", "open_performance_contract", "legacy_builders_absent_and_metrics", "pure_data_and_privacy",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite": "new-game-setup-page-cutover-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"retired_builder_count": RETIRED_BUILDERS.size(),
		"records": records,
	}


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
	var manifest := {
		"suite": "new-game-setup-page-cutover-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": _records.size(),
		"passed_count": _passed_count(),
		"retired_builder_count": RETIRED_BUILDERS.size(),
		"real_open_elapsed_ms": _real_open_elapsed_ms,
		"main_metrics": _main_metrics(),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await _dispose_runtime()
	_save_screenshot()
	print("NewGameSetupPageCutoverBench manifest: %s" % MANIFEST_PATH)
	print("NewGameSetupPageCutoverBench report: %s" % REPORT_PATH)
	print("NewGameSetupPageCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("NewGameSetupPageCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	print("NewGameSetupPageCutoverBench real open: %dms" % _real_open_elapsed_ms)
	if not _failures.is_empty():
		push_error("NewGameSetupPageCutoverBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func _prepare_runtime() -> void:
	var page_packed := load(PAGE_SCENE_PATH) as PackedScene
	_page = page_packed.instantiate() as Control if page_packed != null else null
	if _page != null:
		_page.visible = false
		add_child(_page)
		_page.connect("action_requested", _on_page_action_requested)
	await get_tree().process_frame
	if _page != null:
		_page.call("set_page", _fixture_snapshot())
	await get_tree().process_frame
	await get_tree().process_frame

	var main_packed := load(MAIN_SCENE_PATH) as PackedScene
	_main = main_packed.instantiate() as Control if main_packed != null else null
	if _main != null:
		_main.visible = false
		add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	if _main != null and _main.has_method("_open_new_game_setup_menu"):
		var started := Time.get_ticks_msec()
		_main.call("_open_new_game_setup_menu")
		_real_open_elapsed_ms = Time.get_ticks_msec() - started
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if _main != null:
		_real_page = _main.find_child("NewGameSetupPage", true, false) as Control
		if _main.has_method("_new_game_setup_page_snapshot"):
			_real_snapshot = _main.call("_new_game_setup_page_snapshot") as Dictionary


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	match case_id:
		"required_assets_load":
			passed = load(PAGE_SCRIPT_PATH) is Script and load(PAGE_SCENE_PATH) is PackedScene
			passed = passed and load(LOBBY_SCENE_PATH) is PackedScene and load(OPTION_BOARD_SCENE_PATH) is PackedScene and load(SEAT_CARD_SCENE_PATH) is PackedScene
			flags["page_checked"] = true
			notes = "page and all three editable setup child scenes load"
		"page_scene_contract":
			passed = _page != null and _page.has_method("set_page") and _page.has_signal("action_requested")
			for node_name in ["NewGameSetupSummaryChipRail", "NewGameSetupLobbyPanel", "NewGameSetupOptionBoard", "NewGameSetupSeatScroll", "NewGameSetupSeatGrid", "NewGameSetupActionRow"]:
				passed = passed and _page.find_child(node_name, true, false) != null
			flags["page_checked"] = true
			notes = "one editable page owns the summary, setup boards, seats, hint, and commands"
		"summary_chip_contract":
			var rail := _page.find_child("NewGameSetupSummaryChipRail", true, false) if _page != null else null
			passed = rail != null and rail.get_child_count() == 7 and _node_text_contains(rail, "角色不重复") and _node_text_contains(rail, "首召独立")
			flags["snapshot_checked"] = true
			notes = "seven compact setup facts render in the scene-owned summary rail"
		"lobby_composition":
			var lobby := _page.find_child("NewGameSetupLobbyPanel", true, false) if _page != null else null
			passed = lobby != null and lobby.scene_file_path == LOBBY_SCENE_PATH
			passed = passed and lobby.find_child("NewGameSetupFlowTrack", true, false).get_child_count() == 3
			passed = passed and lobby.find_child("NewGameSetupReadinessRail", true, false).get_child_count() == 3
			flags["lobby_checked"] = true
			notes = "real lobby scene owns flow and readiness composition"
		"option_board_composition":
			var board := _page.find_child("NewGameSetupOptionBoard", true, false) if _page != null else null
			var option_grid := board.find_child("NewGameSetupOptionGrid", true, false) if board != null else null
			passed = board != null and board.scene_file_path == OPTION_BOARD_SCENE_PATH
			passed = passed and option_grid != null and option_grid.get_child_count() == 3
			flags["options_checked"] = true
			notes = "real option board owns player, AI, and challenge cards"
		"seat_scroll_contract":
			var scroll := _page.find_child("NewGameSetupSeatScroll", true, false) as ScrollContainer if _page != null else null
			var grid := _page.find_child("NewGameSetupSeatGrid", true, false) as GridContainer if _page != null else null
			passed = scroll != null and grid != null and scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
			flags["seats_checked"] = true
			notes = "seat cards live in a stable vertical scroll container"
		"seat_card_count":
			var seats := _seat_nodes(_page)
			passed = seats.size() == 2
			for seat_variant in seats:
				passed = passed and (seat_variant as Control).scene_file_path == SEAT_CARD_SCENE_PATH
			flags["seats_checked"] = true
			notes = "fixture creates exactly two real editable seat-card instances"
		"two_column_layout":
			var grid := _page.find_child("NewGameSetupSeatGrid", true, false) as GridContainer if _page != null else null
			passed = grid != null and grid.columns == 2 and grid.custom_minimum_size.x >= 0.0
			flags["seats_checked"] = true
			notes = "page snapshot controls one/two-column seat layout without rebuilding the container"
		"player_count_action_id":
			passed = await _button_emits("4席", "setup_player_count_4")
			flags["action_id_checked"] = true
			notes = "player-count option emits a stable setup_player_count action id"
		"ai_count_action_id":
			passed = await _button_emits("AI3", "setup_ai_count_3")
			flags["action_id_checked"] = true
			notes = "AI-count option emits a stable setup_ai_count action id"
		"challenge_depth_action_id":
			passed = await _button_emits("纵深2", "setup_challenge_depth_2")
			flags["action_id_checked"] = true
			notes = "challenge option emits a stable setup_challenge_depth action id"
		"role_step_action_id":
			passed = await _named_button_emits("NewGameSetupNextRoleButton", "setup_role_step_0_1")
			flags["action_id_checked"] = true
			notes = "seat role cycling emits player and direction as pure intent data"
		"role_random_action_id":
			passed = await _named_button_emits("NewGameSetupRandomRoleButton", "setup_role_random_0")
			flags["action_id_checked"] = true
			notes = "AI random-role selection emits one stable action id"
		"monster_step_action_id":
			passed = await _named_button_emits("NewGameSetupNextMonsterButton", "setup_monster_step_0_1")
			flags["action_id_checked"] = true
			notes = "starter-monster cycling emits player and direction as pure intent data"
		"primary_action_ids":
			passed = await _primary_actions_checked()
			flags["action_id_checked"] = true
			notes = "recommended, start, back, and return-table commands are static scene buttons"
		"real_main_route_and_render":
			passed = _real_main_route_and_render_checked()
			flags["main_checked"] = true
			flags["routing_checked"] = true
			notes = "real main menu instantiates one complete NewGameSetupPage scene"
		"real_main_action_routing":
			passed = await _real_main_action_routing_checked()
			flags["main_checked"] = true
			flags["routing_checked"] = true
			flags["action_id_checked"] = true
			notes = "real scene action updates configured player count and rebuilds three seat cards"
		"open_performance_contract":
			passed = _real_open_elapsed_ms >= 0 and _real_open_elapsed_ms < 5000
			flags["performance_checked"] = true
			notes = "real setup page opens below the five-second gate (%dms)" % _real_open_elapsed_ms
		"legacy_builders_absent_and_metrics":
			passed = RETIRED_BUILDERS.size() == 7
			for builder_name in RETIRED_BUILDERS:
				passed = passed and not _main_source.contains("func %s(" % str(builder_name))
			for preload_name in RETIRED_PRELOADS:
				passed = passed and not _main_source.contains("const %s " % str(preload_name))
			passed = passed and _main_source.contains("NewGameSetupPageScene.instantiate()") and _main_source.contains("func _on_new_game_setup_action_requested(")
			var metrics := _main_metrics()
			passed = passed and int(metrics.get("nonblank_lines", 999999)) < 39527 and int(metrics.get("function_count", 999999)) < 1951 and int(metrics.get("top_level_variable_count", 999999)) <= 192 and int(metrics.get("constant_count", 999999)) <= 318
			flags["deletion_checked"] = true
			notes = "seven obsolete setup wrappers/builders and three child preloads are absent"
		"pure_data_and_privacy":
			passed = _is_pure_data(_real_snapshot) and not _contains_private_key(_real_snapshot)
			var injected := _fixture_snapshot()
			injected["hidden_owner"] = "QA_SECRET_OWNER"
			injected["private_hand"] = ["QA_SECRET_CARD"]
			if _page != null:
				_page.call("set_page", injected)
			await get_tree().process_frame
			var rendered_text := _node_text(_page)
			passed = passed and not rendered_text.contains("QA_SECRET_OWNER") and not rendered_text.contains("QA_SECRET_CARD")
			flags["privacy_checked"] = true
			flags["pure_data_checked"] = true
			notes = "setup snapshot is pure data and ignores injected hidden-owner/private-hand fields"
	return _record(case_id, passed, notes, flags)


func _fixture_snapshot() -> Dictionary:
	return {
		"accent": Color("#38bdf8"),
		"summary_chips": [
			{"text": "席位 2"}, {"text": "真人 1"}, {"text": "电脑对手1"}, {"text": "挑战纵深2"},
			{"text": "目标¥1000"}, {"text": "角色不重复"}, {"text": "首召独立"},
		],
		"lobby": {
			"title": "开桌流程",
			"columns": 3,
			"chips": [{"text": "PVE 2席"}],
			"steps": [
				{"title": "1｜席位", "body": "2席"}, {"title": "2｜挑战", "body": "纵深2"}, {"title": "3｜开局", "body": "首召"},
			],
			"readiness": [{"text": "角色不重复"}, {"text": "首召独立"}, {"text": "AI策略隐藏"}],
		},
		"options": {
			"title": "开局参数",
			"columns": 3,
			"cards": [
				{"title": "玩家席位", "detail": "桌面规模", "options": [{"id": "player_count", "value": 2, "text": "2席", "pressed": true}, {"id": "player_count", "value": 4, "text": "4席"}]},
				{"title": "电脑对手", "detail": "AI数量", "options": [{"id": "ai_count", "value": 1, "text": "AI1", "pressed": true}, {"id": "ai_count", "value": 3, "text": "AI3"}]},
				{"title": "挑战层级", "detail": "星球纵深", "options": [{"id": "challenge_depth", "value": 1, "text": "纵深1"}, {"id": "challenge_depth", "value": 2, "text": "纵深2", "pressed": true}]},
			],
		},
		"seat_columns": 2,
		"seat_scroll_height": 320.0,
		"seats": [_seat_fixture(0, "真人/本地", false), _seat_fixture(1, "电脑对手", true)],
		"hint": "角色公开；首召匿名。",
		"can_return_table": true,
	}


func _seat_fixture(player_index: int, seat_label: String, is_ai: bool) -> Dictionary:
	return {
		"player_index": player_index,
		"chips": [{"text": "P%d" % (player_index + 1)}, {"text": seat_label}],
		"identity": {"chips": [{"text": "公开角色"}], "cards": [{"title": "信息边界", "body": "只读公开动作"}]},
		"passive_text": "角色被动：测试",
		"role_label": "测试角色%d" % (player_index + 1),
		"role_random": is_ai,
		"show_random_role": is_ai,
		"monster_label": "测试怪兽%d" % (player_index + 1),
		"starter_note": "首召匿名",
		"card_faces": [],
	}


func _on_page_action_requested(action_id: String) -> void:
	_page_emitted_actions.append(action_id)


func _button_emits(button_text: String, expected_action_id: String) -> bool:
	var button := _find_button_with_text(_page, button_text)
	return await _emit_button_checked(button, expected_action_id)


func _named_button_emits(button_name: String, expected_action_id: String) -> bool:
	var button := _page.find_child(button_name, true, false) as Button if _page != null else null
	return await _emit_button_checked(button, expected_action_id)


func _emit_button_checked(button: Button, expected_action_id: String) -> bool:
	_page_emitted_actions.clear()
	if button == null:
		return false
	button.emit_signal("pressed")
	await get_tree().process_frame
	return _page_emitted_actions == [expected_action_id]


func _primary_actions_checked() -> bool:
	var expected := {
		"FirstRunRecommendedSetupButton": "setup_recommended",
		"NewGameSetupStartButton": "setup_start",
		"NewGameSetupBackButton": "setup_back",
		"NewGameSetupReturnTableButton": "setup_return_table",
	}
	for button_name in expected:
		if not await _named_button_emits(str(button_name), str(expected[button_name])):
			return false
	return true


func _real_main_route_and_render_checked() -> bool:
	if _main == null or _real_page == null or _real_page.scene_file_path != PAGE_SCENE_PATH:
		return false
	for child_name in ["NewGameSetupLobbyPanel", "NewGameSetupOptionBoard", "NewGameSetupSeatScroll", "NewGameSetupActionRow"]:
		if _real_page.find_child(child_name, true, false) == null:
			return false
	var configured_count := int(_main.get("configured_player_count"))
	return _seat_nodes(_real_page).size() == configured_count


func _real_main_action_routing_checked() -> bool:
	if _main == null or _real_page == null:
		return false
	_real_page.emit_signal("action_requested", "setup_player_count_3")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var refreshed_page := _main.find_child("NewGameSetupPage", true, false) as Control
	return int(_main.get("configured_player_count")) == 3 and refreshed_page != null and _seat_nodes(refreshed_page).size() == 3


func _seat_nodes(page: Control) -> Array:
	if page == null:
		return []
	var grid := page.find_child("NewGameSetupSeatGrid", true, false)
	return grid.get_children() if grid != null else []


func _find_button_with_text(root: Node, button_text: String) -> Button:
	if root == null:
		return null
	for node_variant in root.find_children("*", "Button", true, false):
		var button := node_variant as Button
		if button != null and button.text == button_text:
			return button
	return null


func _node_text_contains(root: Node, needle: String) -> bool:
	return _node_text(root).contains(needle)


func _node_text(root: Node) -> String:
	if root == null:
		return ""
	var parts: Array[String] = []
	if root is Label:
		parts.append((root as Label).text)
	elif root is Button:
		parts.append((root as Button).text)
	for child in root.get_children():
		parts.append(_node_text(child))
	return "\n".join(parts)


func _record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var record := {
		"case_id": case_id,
		"page_checked": false,
		"snapshot_checked": false,
		"lobby_checked": false,
		"options_checked": false,
		"seats_checked": false,
		"action_id_checked": false,
		"main_checked": false,
		"routing_checked": false,
		"performance_checked": false,
		"privacy_checked": false,
		"pure_data_checked": false,
		"deletion_checked": false,
		"passed": passed,
		"notes": notes,
	}
	record.merge(flags, true)
	return record


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant in value:
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item_variant in value:
			if not _is_pure_data(item_variant):
				return false
	return true


func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in value:
			if str(key_variant).to_lower() in ["owner", "owner_index", "hidden_owner", "private_target", "private_plan", "ai_private_plan", "hand", "private_hand", "private_discard"]:
				return true
			if _contains_private_key(value[key_variant]):
				return true
	elif value is Array:
		for item_variant in value:
			if _contains_private_key(item_variant):
				return true
	return false


func _main_metrics() -> Dictionary:
	var nonblank_lines := 0
	var function_count := 0
	var variable_count := 0
	var constant_count := 0
	for line_variant in _main_source.split("\n"):
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
	for record_variant in _records:
		if bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _update_ui(manifest: Dictionary) -> void:
	var passed := int(manifest.get("passed_count", 0))
	var total := int(manifest.get("record_count", 0))
	status_label.text = "PASS" if passed == total else "FAIL"
	status_label.modulate = Color("#4ade80") if passed == total else Color("#fb7185")
	summary_label.text = "%d/%d ownership cases passed" % [passed, total]
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	ownership_text.text = "[b]Scene-owned setup page[/b]\nNewGameSetupPage owns summary, lobby, option board, seat scroll, seat cards, hint, and command buttons.\n\n[b]Runtime authority retained[/b]\nRole/monster configuration, recommended setup, run creation, and navigation remain existing domain actions.\n\n[b]Retired from main.gd[/b]\n7 generated-page builders/wrappers and 3 child-scene preloads.\n\n[b]Real open budget[/b]\n%s ms\n\n[b]Current main metrics[/b]\n%s nonblank lines - %s functions - %s vars - %s constants" % [str(manifest.get("real_open_elapsed_ms", -1)), str(metrics.get("nonblank_lines", 0)), str(metrics.get("function_count", 0)), str(metrics.get("top_level_variable_count", 0)), str(metrics.get("constant_count", 0))]
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
	var lines := [
		"# New Game Setup Page Cutover",
		"",
		"- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"- Retired builders/wrappers: %d" % int(manifest.get("retired_builder_count", 0)),
		"- Real open: %dms" % int(manifest.get("real_open_elapsed_ms", -1)),
		"- Main nonblank lines: %d" % int(metrics.get("nonblank_lines", 0)),
		"",
		"| Case | Result | Notes |",
		"| --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
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
		for player_variant in _main.find_children("*", "AudioStreamPlayer", true, false):
			var player := player_variant as AudioStreamPlayer
			if player != null:
				player.stop()
				player.stream = null
		_main.queue_free()
		_main = null
		_real_page = null
	if _page != null:
		_page.queue_free()
		_page = null
	for _frame in range(4):
		await get_tree().process_frame
