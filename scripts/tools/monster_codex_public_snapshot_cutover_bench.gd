extends Control
class_name MonsterCodexPublicSnapshotCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const SERVICE_SCENE := "res://scenes/runtime/MonsterCodexPublicSnapshotService.tscn"
const SERVICE_SCRIPT := "res://scripts/runtime/monster_codex_public_snapshot_service.gd"
const COORDINATOR_SCENE := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/monster_codex_public_snapshot_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/monster_codex_public_snapshot_cutover_sprint_15.png"

const RETIRED_FORMATTERS := [
	"_bestiary_codex_browser_entry_snapshot", "_bestiary_public_resource_text", "_bestiary_bound_ladder_text",
	"_bestiary_public_identity_text", "_bestiary_detail_snapshot", "_bestiary_detail_chip_snapshots",
	"_bestiary_detail_kpi_snapshots", "_bestiary_detail_action_snapshots", "_bestiary_action_probability_short",
	"_bestiary_action_probability_tooltip", "_bestiary_preview_text", "_bestiary_monster_card_preview_text",
	"_bestiary_detail_tooltip", "_bestiary_text",
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


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_cutover_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func retired_formatter_names() -> Array:
	return RETIRED_FORMATTERS.duplicate()


func cutover_cases() -> Array:
	return [
		"required_service_assets_load", "service_scene_contract", "monster_source_pure_data", "monster_summary_parity",
		"browser_entry_shape", "detail_shape", "detail_chip_contract", "detail_kpi_contract",
		"action_probability_board", "action_probability_tooltip", "bound_monster_card_preview", "ecology_identity_contract",
		"empty_source_safe", "privacy_boundary", "coordinator_scene_composition", "coordinator_pure_data_proxy",
		"real_main_browser_route", "real_main_detail_route", "legacy_monster_formatters_absent", "deletion_metrics_and_privacy",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant: Variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {"suite": "monster-codex-public-snapshot-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": records.size(), "retired_formatter_count": RETIRED_FORMATTERS.size(), "records": records}


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
	var manifest := {"suite": "monster-codex-public-snapshot-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": _records.size(), "passed_count": _passed_count(), "retired_formatter_count": RETIRED_FORMATTERS.size(), "main_metrics": _main_metrics(), "records": _records.duplicate(true)}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await _dispose_runtime()
	_save_screenshot()
	print("MonsterCodexPublicSnapshotCutoverBench manifest: %s" % MANIFEST_PATH)
	print("MonsterCodexPublicSnapshotCutoverBench report: %s" % REPORT_PATH)
	print("MonsterCodexPublicSnapshotCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("MonsterCodexPublicSnapshotCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("MonsterCodexPublicSnapshotCutoverBench failed:\n- %s" % "\n- ".join(_failures))
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


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	match case_id:
		"required_service_assets_load":
			passed = load(SERVICE_SCRIPT) is Script and load(SERVICE_SCENE) is PackedScene and load(COORDINATOR_SCENE) is PackedScene
			flags["service_checked"] = true
			notes = "monster public snapshot service assets and coordinator load"
		"service_scene_contract":
			passed = _service != null and _service.has_method("configure") and _service.has_method("compose") and _service.has_method("debug_snapshot")
			flags["service_checked"] = true
			notes = "service exposes pure composition and debug contracts"
		"monster_source_pure_data":
			var source: Dictionary = _main.call("_monster_codex_public_source_snapshot", 0, true) if _main != null else {}
			passed = bool(source.get("valid", false)) and _is_pure_data(source) and not _contains_private_key(source)
			flags["monster_checked"] = true
			flags["pure_data_checked"] = true
			flags["privacy_checked"] = true
			notes = "main gathers ecology, probability, and bound-card public facts only"
		"monster_summary_parity":
			var snapshot: Dictionary = _service.call("compose", _source()) if _service != null else {}
			passed = str(snapshot.get("summary_text", "")).contains("怪兽详情｜第1/8只｜岩甲兽") and str(snapshot.get("summary_text", "")).contains("正面经济天气")
			flags["monster_checked"] = true
			notes = "scene-owned formatter preserves existing detail summary hierarchy"
		"browser_entry_shape":
			var snapshot: Dictionary = _service.call("compose", _source()) if _service != null else {}
			var browser: Dictionary = snapshot.get("browser_entry", {}) if snapshot.get("browser_entry", {}) is Dictionary else {}
			passed = bool(browser.get("selected", false)) and str(browser.get("stats", "")).contains("HP18") and browser.get("art", {}) is Dictionary
			flags["monster_checked"] = true
			notes = "BestiaryCodexBrowser receives stable thumbnail, stats, identity, tooltip, and art"
		"detail_shape":
			var detail: Dictionary = (_service.call("compose", _source()) as Dictionary).get("detail", {}) if _service != null else {}
			passed = str(detail.get("title", "")).contains("怪兽单位档案") and detail.get("art", {}) is Dictionary and (detail.get("actions", []) as Array).size() == 1
			flags["monster_checked"] = true
			notes = "BestiaryDetail receives a stable scene-owned payload"
		"detail_chip_contract":
			var detail: Dictionary = (_service.call("compose", _source()) as Dictionary).get("detail", {}) if _service != null else {}
			var chips: Array = detail.get("chips", []) if detail.get("chips", []) is Array else []
			passed = chips.size() == 6 and _array_has_text(chips, "HP18") and _array_has_text(chips, "相遇50m")
			flags["monster_checked"] = true
			notes = "HP, armor, speed, movement, resource, and encounter chips remain stable"
		"detail_kpi_contract":
			var detail: Dictionary = (_service.call("compose", _source()) as Dictionary).get("detail", {}) if _service != null else {}
			var kpis: Array = detail.get("kpis", []) if detail.get("kpis", []) is Array else []
			passed = kpis.size() == 4 and _array_has_title(kpis, "生态位") and _array_has_title(kpis, "固定技能成长")
			flags["monster_checked"] = true
			notes = "ecology, economy, action role, and bound-skill KPIs retain prior shape"
		"action_probability_board":
			var detail: Dictionary = (_service.call("compose", _source()) as Dictionary).get("detail", {}) if _service != null else {}
			var action: Dictionary = (detail.get("actions", []) as Array)[0] as Dictionary
			passed = str(action.get("probability", "")) == "I 25%/30%｜IV 35%/40%" and str(action.get("facts", "")).contains("伤害5")
			flags["probability_checked"] = true
			notes = "service formats supplied I/IV open/destroyed probability facts without recalculating"
		"action_probability_tooltip":
			var detail: Dictionary = (_service.call("compose", _source()) as Dictionary).get("detail", {}) if _service != null else {}
			var action: Dictionary = (detail.get("actions", []) as Array)[0] as Dictionary
			passed = str(action.get("probability_tooltip", "")).contains("IV破坏后40%") and str(action.get("tooltip", "")).contains("攻击城市")
			flags["probability_checked"] = true
			notes = "probability tooltip and action body preserve public explanation"
		"bound_monster_card_preview":
			var snapshot: Dictionary = _service.call("compose", _source()) if _service != null else {}
			passed = str(snapshot.get("card_preview_text", "")).contains("岩甲兽 I") and str(snapshot.get("card_preview_text", "")).contains("¥260")
			flags["card_checked"] = true
			notes = "bound monster card preview uses supplied real card identity, price, and region rule"
		"ecology_identity_contract":
			var snapshot: Dictionary = _service.call("compose", _source()) if _service != null else {}
			passed = str(snapshot.get("public_identity_text", "")).contains("生态位:陆行") and str(snapshot.get("bound_ladder_text", "")).contains("IV:3张")
			flags["monster_checked"] = true
			notes = "movement role and I-IV bound-skill ladder remain public and readable"
		"empty_source_safe":
			var snapshot: Dictionary = _service.call("compose", {"valid": false}) if _service != null else {}
			passed = str(snapshot.get("card_preview_text", "")) == "怪兽卡：暂无" and (snapshot.get("detail", {}) as Dictionary).is_empty()
			flags["monster_checked"] = true
			notes = "invalid catalog source returns a safe empty presentation"
		"privacy_boundary":
			var source := _source()
			source["hidden_owner"] = 2
			source["private_plan"] = "secret"
			var snapshot: Dictionary = _service.call("compose", source) if _service != null else {}
			passed = not _contains_private_key(snapshot) and _is_pure_data(snapshot)
			flags["privacy_checked"] = true
			flags["pure_data_checked"] = true
			notes = "unknown owner and private-plan input is never copied to public output"
		"coordinator_scene_composition":
			var node := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterCodexPublicSnapshotService") if _main != null else null
			passed = node != null and node.scene_file_path == SERVICE_SCENE
			flags["service_checked"] = true
			flags["main_checked"] = true
			notes = "real main composition owns one editable monster snapshot service"
		"coordinator_pure_data_proxy":
			var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
			var snapshot: Variant = coordinator.call("compose_monster_codex_snapshot", _source()) if coordinator != null else {}
			passed = coordinator != null and _is_pure_data(snapshot) and not _contains_private_key(snapshot)
			flags["pure_data_checked"] = true
			flags["privacy_checked"] = true
			notes = "coordinator exposes duplicated pure-data monster presentation only"
		"real_main_browser_route":
			var browser: Dictionary = _main.call("_bestiary_codex_browser_snapshot") if _main != null else {}
			passed = not (browser.get("entries", []) as Array).is_empty() and browser.get("preview", {}) is Dictionary and _is_pure_data(browser)
			flags["main_checked"] = true
			flags["routing_checked"] = true
			notes = "real atlas route delegates entry and preview composition to the service"
		"real_main_detail_route":
			var snapshot: Dictionary = _main.call("_monster_codex_public_snapshot", 0, true) if _main != null else {}
			passed = str(snapshot.get("summary_text", "")).contains(str((_main.call("_catalog_entry", 0) as Dictionary).get("name", ""))) and snapshot.get("detail", {}) is Dictionary
			flags["main_checked"] = true
			flags["routing_checked"] = true
			notes = "real monster detail route delegates public source facts through the coordinator"
		"legacy_monster_formatters_absent":
			passed = true
			for formatter_name in RETIRED_FORMATTERS:
				passed = passed and not _main_source.contains("func %s(" % formatter_name)
			flags["deletion_checked"] = true
			notes = "all 14 retired monster presentation formatters stay absent from main.gd"
		"deletion_metrics_and_privacy":
			var metrics := _main_metrics()
			var debug: Dictionary = _service.call("debug_snapshot") if _service != null else {}
			passed = int(metrics.get("nonblank_lines", 999999)) <= 40859 and int(metrics.get("function_count", 999999)) <= 2010 and int(metrics.get("top_level_variable_count", 999999)) <= 192 and int(metrics.get("constant_count", 999999)) <= 320
			passed = passed and not bool(debug.get("calculates_action_weights", true)) and not bool(debug.get("legacy_main_formatter_active", true)) and not _contains_private_key(debug)
			flags["deletion_checked"] = true
			flags["privacy_checked"] = true
			notes = "Sprint 15 shrinks main while probability authority remains outside the formatter"
	return _record(case_id, passed, notes, flags)


func _source() -> Dictionary:
	return {
		"valid": true, "index": 0, "total": 8, "selected": true,
		"entry": {"name": "岩甲兽", "style": "重装陆行怪兽。", "hp": 18, "armor": 3, "resource_focus": ["环晶电池"]},
		"ecology": {"movement_archetype": "陆行", "movement_traits": ["重装"], "role_tags": ["破坏", "仓储压力"], "bound_skill_counts": [1, 2, 2, 3], "summon_access": "monster_zone", "resource_drain": 2, "max_damage": 5, "economy_boon": {"label": "矿脉富集"}, "rank_iv_shift": "破坏行动上升"},
		"profile": {"accent": Color("#fb7185")}, "accent": Color("#fb7185"), "move_text": "80m/s", "art_move_text": "80m/s", "ecology_move_text": "80m/s", "max_range_text": "120m", "encounter_range_text": "50m", "mobility_summary": "陆地稳定移动", "action_summary": "撞击/掠夺", "rank_iv_shift_summary": "破坏权重+2", "level_labels": ["I", "II", "III", "IV"],
		"actions": [{"name": "撞击", "text": "攻击城市并制造热度。", "tags": ["攻击"], "facts": "伤害5｜热度+1", "i_open": "25%", "i_destroyed": "30%", "iv_open": "35%", "iv_destroyed": "40%", "probability_tooltip": "I开局25% / I破坏后30%\nIV开局35% / IV破坏后40%"}],
		"monster_card": {"valid": true, "display_name": "岩甲兽 I", "price": 260, "region_text": "不限区"},
	}


func _record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var record := {"case_id": case_id, "service_checked": false, "main_checked": false, "monster_checked": false, "probability_checked": false, "card_checked": false, "routing_checked": false, "privacy_checked": false, "pure_data_checked": false, "deletion_checked": false, "passed": passed, "notes": notes}
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
			if str(key_variant).to_lower() in ["owner", "hidden_owner", "hidden_owner_id", "private_target", "private_plan", "ai_private_plan"]:
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
	ownership_text.text = "[b]Scene-owned monster Codex snapshots[/b]\nMonsterCodexPublicSnapshotService owns public summary, thumbnail, detail, chips, KPIs, action cards, and tooltips.\n\n[b]Retired from main.gd[/b]\n14 monster presentation formatters.\n\n[b]Current main metrics[/b]\n%s nonblank lines - %s functions - %s vars - %s constants" % [str(metrics.get("nonblank_lines", 0)), str(metrics.get("function_count", 0)), str(metrics.get("top_level_variable_count", 0)), str(metrics.get("constant_count", 0))]
	var lines: Array[String] = []
	for record_variant: Variant in _records:
		var record := record_variant as Dictionary
		var result := "PASS" if bool(record.get("passed", false)) else "FAIL"
		lines.append("[color=%s][b]%s[/b][/color]  %s\n%s" % ["#4ade80" if result == "PASS" else "#fb7185", result, str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	var lines := ["# Monster Codex Public Snapshot Cutover", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Retired formatters: %d" % int(manifest.get("retired_formatter_count", 0)), "- Main nonblank lines: %d" % int(metrics.get("nonblank_lines", 0)), "", "| Case | Result | Notes |", "| --- | --- | --- |"]
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
