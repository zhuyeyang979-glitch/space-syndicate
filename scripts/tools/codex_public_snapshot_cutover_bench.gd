extends Control
class_name CodexPublicSnapshotCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const SERVICE_SCENE := "res://scenes/runtime/CodexPublicSnapshotService.tscn"
const SERVICE_SCRIPT := "res://scripts/runtime/codex_public_snapshot_service.gd"
const COORDINATOR_SCENE := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const REGION_SOURCE_SERVICE_SCENE := "res://scenes/runtime/RegionCodexPublicSourceService.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/codex_public_snapshot_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/codex_public_snapshot_cutover_sprint_14.png"

const RETIRED_FORMATTERS := [
	"_role_codex_text", "_role_codex_route_tags", "_role_codex_route_label", "_role_codex_economy_line",
	"_role_codex_intel_line", "_role_codex_control_line", "_role_codex_opening_hint", "_role_codex_privacy_line",
	"_role_codex_identity_board_snapshot", "_role_codex_card_face_snapshot", "_region_codex_accent",
	"_region_codex_terrain_icon", "_region_codex_city_status_text", "_region_codex_supply_text",
	"_region_codex_demand_text", "_region_codex_monster_attraction_text", "_region_codex_public_clue_text",
	"_region_codex_income_preview_text", "_region_codex_detail_snapshot", "_region_codex_chip_snapshots",
	"_region_codex_kpi_snapshots", "_region_codex_clue_snapshots", "_region_codex_text",
]

@export var auto_run := true

@onready var status_label: Label = %StatusLabel
@onready var summary_label: Label = %SummaryLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var results_text: RichTextLabel = %ResultsText

var _service: Node
var _region_source_service: Node
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
		"required_service_assets_load", "service_scene_contract", "role_source_pure_data", "role_summary_parity",
		"role_board_shape", "role_economy_variants", "role_control_variants", "role_privacy_boundary",
		"region_source_pure_data", "region_summary_city", "region_summary_no_city", "region_detail_shape",
		"region_public_scope_chip", "region_public_clue_safe", "coordinator_scene_composition", "coordinator_pure_data_proxy",
		"real_main_role_route", "real_main_region_route", "legacy_role_region_formatters_absent", "deletion_metrics_and_privacy",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant: Variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite": "codex-public-snapshot-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(), "retired_formatter_count": RETIRED_FORMATTERS.size(), "records": records,
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
		"suite": "codex-public-snapshot-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH,
		"record_count": _records.size(), "passed_count": _passed_count(), "retired_formatter_count": RETIRED_FORMATTERS.size(),
		"main_metrics": _main_metrics(), "records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await _dispose_runtime()
	_save_screenshot()
	print("CodexPublicSnapshotCutoverBench manifest: %s" % MANIFEST_PATH)
	print("CodexPublicSnapshotCutoverBench report: %s" % REPORT_PATH)
	print("CodexPublicSnapshotCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("CodexPublicSnapshotCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("CodexPublicSnapshotCutoverBench failed:\n- %s" % "\n- ".join(_failures))
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
	_region_source_service = _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RegionCodexPublicSourceService") if _main != null else null


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	match case_id:
		"required_service_assets_load":
			passed = load(SERVICE_SCRIPT) is Script and load(SERVICE_SCENE) is PackedScene and load(COORDINATOR_SCENE) is PackedScene
			flags["service_checked"] = true
			notes = "service script, editable scene, and coordinator composition load"
		"service_scene_contract":
			passed = _service != null
			for method_name in ["configure", "compose_role", "compose_region", "role_route_label", "debug_snapshot"]:
				passed = passed and _service.has_method(method_name)
			flags["service_checked"] = true
			notes = "service exposes Role, Region, route-label, and debug contracts"
		"role_source_pure_data":
			var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
			var snapshot: Dictionary = coordinator.call("role_codex_public_snapshot", 0, {}) if coordinator != null else {}
			passed = not snapshot.is_empty() and _is_pure_data(snapshot)
			flags["role_checked"] = true
			flags["pure_data_checked"] = true
			notes = "the role catalog source owner composes public role facts without Node, Resource, Object, or Callable"
		"role_summary_parity":
			var snapshot: Dictionary = _service.call("compose_role", _role_source()) if _service != null else {}
			passed = str(snapshot.get("summary_text", "")).contains("角色卡｜第1/8张｜星港金融团｜轨道商人")
			flags["role_checked"] = true
			notes = "scene-owned formatter preserves the existing role summary hierarchy"
		"role_board_shape":
			var snapshot: Dictionary = _service.call("compose_role", _role_source()) if _service != null else {}
			var board: Dictionary = snapshot.get("board", {}) if snapshot.get("board", {}) is Dictionary else {}
			passed = (board.get("kpis", []) as Array).size() == 4 and (board.get("routes", []) as Array).size() == 6 and (board.get("chips", []) as Array).size() >= 2 and board.get("face", {}) is Dictionary
			flags["role_checked"] = true
			notes = "RoleCodexIdentityBoard receives the stable chip, KPI, route, and face shape"
		"role_economy_variants":
			var source := _role_source()
			var role_card: Dictionary = source.get("role_card", {}).duplicate(true)
			role_card["resource_cash_product"] = "深海菌毯"
			role_card["resource_cash_amount"] = 55
			role_card["monster_upgrade_cash"] = 160
			source["role_card"] = role_card
			var snapshot: Dictionary = _service.call("compose_role", source) if _service != null else {}
			var economy := str(snapshot.get("economy_line", ""))
			passed = economy.contains("环晶电池区域购牌+1") and economy.contains("深海菌毯城市+¥55/min") and economy.contains("升兽+¥160")
			flags["role_checked"] = true
			notes = "product, recurring cash, and upgrade economy labels retain prior values"
		"role_control_variants":
			var source := _role_source()
			var role_card: Dictionary = source.get("role_card", {}).duplicate(true)
			role_card["military_control_limit_bonus"] = 1
			source["role_card"] = role_card
			var snapshot: Dictionary = _service.call("compose_role", source) if _service != null else {}
			var control := str(snapshot.get("control_line", ""))
			passed = control.contains("怪兽上限2") and control.contains("军队上限2") and not control.contains("全图购牌")
			flags["role_checked"] = true
			notes = "unit limits remain public while retired global-market privilege copy stays absent"
		"role_privacy_boundary":
			var source := _role_source()
			source["private_plan"] = "never-copy-this"
			var snapshot: Dictionary = _service.call("compose_role", source) if _service != null else {}
			passed = not _contains_private_key(snapshot) and str((snapshot.get("board", {}) as Dictionary).get("tooltip", "")).contains("公开身份牌")
			flags["role_checked"] = true
			flags["privacy_checked"] = true
			notes = "unknown private role input is not copied into public presentation"
		"region_source_pure_data":
			var source: Dictionary = _region_source_service.call("compose_source", 0) if _region_source_service != null else {}
			passed = bool(source.get("valid", false)) and _is_pure_data(source) and not _contains_private_key(source)
			flags["region_checked"] = true
			flags["pure_data_checked"] = true
			flags["privacy_checked"] = true
			notes = "scene-owned Region source service exposes viewer-invariant public facts only"
		"region_summary_city":
			var snapshot: Dictionary = _service.call("compose_region", _region_source(true)) if _service != null else {}
			passed = str(snapshot.get("summary_text", "")).contains("公开设施：") and str(snapshot.get("summary_text", "")).contains("区域GDP公开汇总:180/min")
			flags["region_checked"] = true
			notes = "developed-region summary exposes public facilities and aggregate regional GDP"
		"region_summary_no_city":
			var snapshot: Dictionary = _service.call("compose_region", _region_source(false)) if _service != null else {}
			passed = str(snapshot.get("summary_text", "")).contains("公开设施：暂无") and str(snapshot.get("summary_text", "")).contains("环晶电池")
			flags["region_checked"] = true
			notes = "undeveloped region preserves public production without inventing a city owner"
		"region_detail_shape":
			var snapshot: Dictionary = _service.call("compose_region", _region_source(true)) if _service != null else {}
			var detail: Dictionary = snapshot.get("detail", {}) if snapshot.get("detail", {}) is Dictionary else {}
			passed = str(detail.get("icon", "")) == "▣" and (detail.get("kpis", []) as Array).size() == 4 and (detail.get("clues", []) as Array).size() == 6 and (detail.get("chips", []) as Array).size() == 6
			flags["region_checked"] = true
			notes = "RegionCodexDetail receives stable icon, chip, KPI, and clue lanes"
		"region_public_scope_chip":
			var snapshot: Dictionary = _service.call("compose_region", _region_source(true)) if _service != null else {}
			var chips: Array = (snapshot.get("detail", {}) as Dictionary).get("chips", []) as Array
			passed = _array_has_text(chips, "公开资料") and _array_has_text(chips, "公开市场") and not _array_has_text(chips, "当前选中")
			flags["region_checked"] = true
			notes = "Region chips describe public scope without viewer-local selection state"
		"region_public_clue_safe":
			var source := _region_source(true)
			source["hidden_owner"] = 2
			source["private_target"] = "secret"
			var snapshot: Dictionary = _service.call("compose_region", source) if _service != null else {}
			passed = not _contains_private_key(snapshot) and str(snapshot.get("summary_text", "")).contains("现金、手牌、私密库存")
			flags["region_checked"] = true
			flags["privacy_checked"] = true
			notes = "public clue output states the v0.6 privacy boundary and strips injected private keys"
		"coordinator_scene_composition":
			var node := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CodexPublicSnapshotService") if _main != null else null
			passed = node != null and node.scene_file_path == SERVICE_SCENE and _region_source_service != null and _region_source_service.scene_file_path == REGION_SOURCE_SERVICE_SCENE
			flags["service_checked"] = true
			flags["main_checked"] = true
			notes = "real main composition owns one editable CodexPublicSnapshotService scene"
		"coordinator_pure_data_proxy":
			var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
			var role_snapshot: Variant = coordinator.call("compose_codex_role_snapshot", _role_source()) if coordinator != null else {}
			var region_snapshot: Variant = coordinator.call("region_codex_public_snapshot", 0) if coordinator != null else {}
			passed = coordinator != null and coordinator.has_method("codex_role_route_label") and coordinator.has_method("region_codex_public_snapshot") and _is_pure_data(role_snapshot) and _is_pure_data(region_snapshot)
			flags["pure_data_checked"] = true
			notes = "coordinator proxies duplicated pure-data snapshots only"
		"real_main_role_route":
			var role_card: Dictionary = _main.call("_make_player_role_card", 0) if _main != null else {}
			var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
			var snapshot: Dictionary = coordinator.call("role_codex_public_snapshot", 0, {}) if coordinator != null else {}
			passed = not snapshot.is_empty() and snapshot.get("board", {}) is Dictionary and str(snapshot.get("summary_text", "")).contains(str(role_card.get("name", "")))
			flags["main_checked"] = true
			flags["role_checked"] = true
			flags["routing_checked"] = true
			notes = "real main Role route delegates source facts to the service"
		"real_main_region_route":
			var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
			var snapshot: Dictionary = coordinator.call("region_codex_public_snapshot", 0) if coordinator != null else {}
			passed = not snapshot.is_empty() and snapshot.get("detail", {}) is Dictionary and str(snapshot.get("summary_text", "")).contains("区域可提供卡牌")
			flags["main_checked"] = true
			flags["region_checked"] = true
			flags["routing_checked"] = true
			notes = "real main Region route delegates viewer-safe world facts to the service"
		"legacy_role_region_formatters_absent":
			passed = true
			for formatter_name in RETIRED_FORMATTERS:
				passed = passed and not _main_source.contains("func %s(" % formatter_name)
			flags["deletion_checked"] = true
			notes = "all 23 duplicated Role/Region formatters stay absent from main.gd"
		"deletion_metrics_and_privacy":
			var metrics := _main_metrics()
			var service_debug: Dictionary = _service.call("debug_snapshot") if _service != null else {}
			passed = int(metrics.get("nonblank_lines", 999999)) <= 40986 and int(metrics.get("function_count", 999999)) <= 2019 and int(metrics.get("top_level_variable_count", 999999)) <= 192 and int(metrics.get("constant_count", 999999)) <= 320
			passed = passed and not _contains_private_key(service_debug) and not bool(service_debug.get("legacy_main_formatter_active", true))
			flags["deletion_checked"] = true
			flags["privacy_checked"] = true
			notes = "Sprint 14 main metrics shrink and service debug reports no legacy formatter authority"
	return _record(case_id, passed, notes, flags)


func _role_source() -> Dictionary:
	return {
		"role_card": {"name": "星港金融团", "species": "轨道商人", "trait": "融资网络", "flavor": "公开经营，隐藏收益。", "bonus_card_product": "环晶电池", "monster_control_limit_bonus": 1, "card_history_residual_catalog_charges": 2},
		"index": 0, "total": 8, "passive_text": "每轮第一次商品购牌获得折扣。", "starting_cash_delta": 50,
		"accent": Color("#38bdf8"), "kpi_columns": 4, "route_columns": 3,
		"face": {"name": "星港金融团", "effect": "测试", "type": "角色", "rank": "轨道商人"}, "face_effect": "公开身份牌效果。",
	}


func _region_source(city_active: bool) -> Dictionary:
	return {
		"valid": true, "index": 1, "total": 12, "name": "极光港", "terrain": "ice", "terrain_label": "冰原", "economic_focus_label": "工业",
		"destroyed": false, "hp_total": 12, "hp_now": 8, "trade_route_load": 2,
		"card_count": 4, "facility_count": 2 if city_active else 0, "city_last_income": 180 if city_active else 0,
		"facility_entries": [
			{"facility_id": "facility:test:0", "facility_type": "生产设施", "rank": 2, "owner_kind": "player", "owner_player_index": 0},
			{"facility_id": "facility:test:1", "facility_type": "物流设施", "rank": 1, "owner_kind": "player", "owner_player_index": 1},
		] if city_active else [],
		"supply_text": "环晶电池 ¥90", "demand_text": "深海菌毯 ¥120", "weather_text": "极光风暴", "connection_summary": "连接3区",
		"card_choice_summary": "轨道融资1、城市经营1", "monster_entries": [{"ordinal": 1, "name": "岩甲兽", "reason": "偏好仓储"}],
		"public_clue": "公开牌轨显示工业投资。", "card_names": ["轨道融资1", "城市经营1"],
		"income_detail_lines": ["公开生产贡献 160", "公开吞吐贡献 +20"] if city_active else [],
		"products": ["环晶电池"],
	}


func _record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var record := {"case_id": case_id, "service_checked": false, "main_checked": false, "role_checked": false, "region_checked": false, "routing_checked": false, "privacy_checked": false, "pure_data_checked": false, "deletion_checked": false, "passed": passed, "notes": notes}
	record.merge(flags, true)
	return record


func _array_has_text(entries: Array, text_value: String) -> bool:
	for entry_variant: Variant in entries:
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("text", "")) == text_value:
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
			if str(key_variant).to_lower() in ["owner", "hidden_owner", "hidden_owner_id", "private_target", "private_discard", "private_plan", "ai_private_plan"]:
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
	ownership_text.text = "[b]Scene-owned public Codex snapshots[/b]\nCodexPublicSnapshotService owns Role and Region summary, board, chip, KPI, clue, and card-face presentation.\n\n[b]Retired from main.gd[/b]\n23 duplicated formatters.\n\n[b]Current main metrics[/b]\n%s nonblank lines - %s functions - %s vars - %s constants" % [str(metrics.get("nonblank_lines", 0)), str(metrics.get("function_count", 0)), str(metrics.get("top_level_variable_count", 0)), str(metrics.get("constant_count", 0))]
	var lines: Array[String] = []
	for record_variant: Variant in _records:
		var record := record_variant as Dictionary
		var result := "PASS" if bool(record.get("passed", false)) else "FAIL"
		lines.append("[color=%s][b]%s[/b][/color]  %s\n%s" % ["#4ade80" if result == "PASS" else "#fb7185", result, str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	var lines := ["# Codex Public Snapshot Cutover", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Retired formatters: %d" % int(manifest.get("retired_formatter_count", 0)), "- Main nonblank lines: %d" % int(metrics.get("nonblank_lines", 0)), "", "| Case | Result | Notes |", "| --- | --- | --- |"]
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
