extends Control
class_name CodexAtlasSceneCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const BESTIARY_BROWSER_SCENE := "res://scenes/ui/BestiaryCodexBrowser.tscn"
const PRODUCT_BROWSER_SCENE := "res://scenes/ui/ProductCodexBrowser.tscn"
const BESTIARY_THUMBNAIL_SCENE := "res://scenes/ui/codex/BestiaryCodexThumbnailCard.tscn"
const PRODUCT_THUMBNAIL_SCENE := "res://scenes/ui/codex/ProductCodexThumbnailCard.tscn"
const SUMMARY_CARD_SCENE := "res://scenes/ui/codex/CodexBrowserSummaryCard.tscn"
const PRODUCT_BADGE_SCENE := "res://scenes/ui/codex/ProductCodexMarketBadge.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/codex_atlas_scene_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/codex_atlas_scene_cutover_sprint_12.png"

const RETIRED_FUNCTIONS := [
	"_populate_bestiary_thumbnail_page",
	"_add_bestiary_thumbnail",
	"_bestiary_public_economy_text",
	"_add_bestiary_ecology_catalog_overview",
	"_add_bestiary_ecology_info_cards",
	"_add_bestiary_hover_preview",
	"_on_bestiary_thumbnail_gui_input",
	"_add_product_ecosystem_overview",
	"_populate_product_codex_thumbnail_page",
	"_add_product_codex_thumbnail",
	"_add_product_codex_hover_preview",
	"_add_product_codex_badge",
	"_on_product_codex_thumbnail_gui_input",
	"_add_monster_art_preview",
]

@export var auto_run := true

@onready var status_label: Label = %StatusLabel
@onready var summary_label: Label = %SummaryLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var results_text: RichTextLabel = %ResultsText

var _records: Array = []
var _failures: Array[String] = []
var _main: Control = null
var _overlay: Control = null
var _main_source := ""


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_cutover_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func retired_function_names() -> Array:
	return RETIRED_FUNCTIONS.duplicate()


func cutover_cases() -> Array:
	return [
		"required_atlas_scenes_load",
		"browser_scene_contracts",
		"real_main_scene_loads",
		"bestiary_browser_scene_required",
		"product_browser_scene_required",
		"bestiary_thumbnail_scene_instances",
		"product_thumbnail_scene_instances",
		"summary_card_scene_instances",
		"product_badge_scene_reused",
		"bestiary_preview_signal_routes",
		"product_preview_signal_routes",
		"bestiary_detail_signal_routes",
		"product_detail_signal_routes",
		"page_step_signals_stable",
		"bestiary_snapshot_pure_data",
		"product_snapshot_pure_data",
		"privacy_boundary_preserved",
		"legacy_bestiary_atlas_absent",
		"legacy_product_atlas_absent",
		"all_retired_functions_and_metrics",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant: Variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {"suite": "codex-atlas-scene-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "retired_function_count": RETIRED_FUNCTIONS.size(), "record_count": records.size(), "records": records}


func run_cutover_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	_main_source = FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	await _ensure_main()
	for case_id_variant: Variant in cutover_cases():
		var case_id := str(case_id_variant)
		var record := _run_case(case_id)
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "failed"))])
	var manifest := {"suite": "codex-atlas-scene-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": _records.size(), "passed_count": _passed_count(), "retired_function_count": RETIRED_FUNCTIONS.size(), "main_metrics": _main_metrics(), "records": _records.duplicate(true)}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await _dispose_main()
	_save_screenshot()
	print("CodexAtlasSceneCutoverBench manifest: %s" % MANIFEST_PATH)
	print("CodexAtlasSceneCutoverBench report: %s" % REPORT_PATH)
	print("CodexAtlasSceneCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("CodexAtlasSceneCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("CodexAtlasSceneCutoverBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func _ensure_main() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_main = packed.instantiate() as Control if packed != null else null
	if _main == null:
		return
	_main.visible = false
	add_child(_main)
	await get_tree().process_frame
	if _main.has_method("_new_game"):
		_main.call("_new_game")
	await get_tree().process_frame
	await get_tree().process_frame
	_overlay = _main.get("menu_overlay") as Control


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	match case_id:
		"required_atlas_scenes_load":
			passed = true
			for scene_path in [BESTIARY_BROWSER_SCENE, PRODUCT_BROWSER_SCENE, BESTIARY_THUMBNAIL_SCENE, PRODUCT_THUMBNAIL_SCENE, SUMMARY_CARD_SCENE, PRODUCT_BADGE_SCENE]:
				passed = passed and load(scene_path) is PackedScene
			flags["scene_checked"] = true
			notes = "both atlases and all repeated cards are editable PackedScenes"
		"browser_scene_contracts":
			passed = _scene_has_contract(BESTIARY_BROWSER_SCENE, "set_browser") and _scene_has_contract(PRODUCT_BROWSER_SCENE, "set_browser") and _scene_has_contract(BESTIARY_THUMBNAIL_SCENE, "set_entry") and _scene_has_contract(PRODUCT_THUMBNAIL_SCENE, "set_entry")
			flags["scene_checked"] = true
			notes = "browser and thumbnail scenes expose data-in contracts"
		"real_main_scene_loads":
			passed = _main != null and _main.scene_file_path == MAIN_SCENE_PATH
			flags["main_checked"] = true
			notes = "the gate instantiates the real main scene"
		"bestiary_browser_scene_required":
			_open_bestiary_browser()
			var browser := _preview_child("BestiaryCodexBrowser")
			passed = browser != null and browser.scene_file_path == BESTIARY_BROWSER_SCENE
			flags["scene_checked"] = true
			notes = "the real monster atlas uses BestiaryCodexBrowser.tscn"
		"product_browser_scene_required":
			_open_product_browser()
			var browser := _preview_child("ProductCodexBrowser")
			passed = browser != null and browser.scene_file_path == PRODUCT_BROWSER_SCENE
			flags["scene_checked"] = true
			notes = "the real product atlas uses ProductCodexBrowser.tscn"
		"bestiary_thumbnail_scene_instances":
			_open_bestiary_browser()
			var browser := _preview_child("BestiaryCodexBrowser")
			var cards := browser.find_children("BestiaryThumbnail_*", "Control", true, false) if browser != null else []
			passed = not cards.is_empty()
			for card_variant: Variant in cards:
				passed = passed and (card_variant as Node).scene_file_path == BESTIARY_THUMBNAIL_SCENE
			flags["scene_checked"] = true
			notes = "monster entries are repeated scene instances, not raw Controls"
		"product_thumbnail_scene_instances":
			_open_product_browser()
			var browser := _preview_child("ProductCodexBrowser")
			var cards := browser.find_children("ProductThumbnail_*", "Control", true, false) if browser != null else []
			passed = not cards.is_empty()
			for card_variant: Variant in cards:
				passed = passed and (card_variant as Node).scene_file_path == PRODUCT_THUMBNAIL_SCENE
			flags["scene_checked"] = true
			notes = "product entries are repeated scene instances, not raw Controls"
		"summary_card_scene_instances":
			_open_product_browser()
			var browser := _preview_child("ProductCodexBrowser")
			var summaries := browser.find_children("CodexBrowserSummaryCard_*", "PanelContainer", true, false) if browser != null else []
			passed = summaries.size() == 4
			for summary_variant: Variant in summaries:
				passed = passed and (summary_variant as Node).scene_file_path == SUMMARY_CARD_SCENE
			flags["scene_checked"] = true
			notes = "the four product overview cards reuse one editable summary scene"
		"product_badge_scene_reused":
			_open_product_browser()
			var browser := _preview_child("ProductCodexBrowser")
			var badge := browser.find_child("ProductThumbnailBadge", true, false) if browser != null else null
			passed = badge != null and badge.scene_file_path == PRODUCT_BADGE_SCENE
			flags["scene_checked"] = true
			notes = "product thumbnails reuse the existing market-badge scene"
		"bestiary_preview_signal_routes":
			_open_bestiary_browser()
			var browser := _preview_child("BestiaryCodexBrowser")
			var snapshot := browser.call("debug_snapshot") as Dictionary if browser != null else {}
			var indices := snapshot.get("rendered_indices", []) as Array
			var target := int(indices[-1]) if not indices.is_empty() else -1
			if browser != null and target >= 0:
				browser.emit_signal("entry_preview_requested", target)
			var navigation: Dictionary = _main.call("_codex_navigation_state_snapshot") if _main != null and _main.has_method("_codex_navigation_state_snapshot") else {}
			var monster_state: Dictionary = navigation.get("monster", {}) if navigation.get("monster", {}) is Dictionary else {}
			passed = target >= 0 and int(monster_state.get("preview_index", -1)) == target and _preview_child("BestiaryCodexBrowser") != null
			flags["bridge_checked"] = true
			notes = "monster preview signals update existing catalog state without replacing the browser"
		"product_preview_signal_routes":
			_open_product_browser()
			var browser := _preview_child("ProductCodexBrowser")
			var snapshot := browser.call("debug_snapshot") as Dictionary if browser != null else {}
			var indices := snapshot.get("rendered_indices", []) as Array
			var target := int(indices[-1]) if not indices.is_empty() else -1
			if browser != null and target >= 0:
				browser.emit_signal("entry_preview_requested", target)
			var navigation: Dictionary = _main.call("_codex_navigation_state_snapshot") if _main != null and _main.has_method("_codex_navigation_state_snapshot") else {}
			var product_state: Dictionary = navigation.get("product", {}) if navigation.get("product", {}) is Dictionary else {}
			passed = target >= 0 and int(product_state.get("preview_index", -1)) == target and _preview_child("ProductCodexBrowser") != null
			flags["bridge_checked"] = true
			notes = "product preview signals update existing catalog state without replacing the browser"
		"bestiary_detail_signal_routes":
			_open_bestiary_browser()
			var browser := _preview_child("BestiaryCodexBrowser")
			if browser != null:
				browser.emit_signal("entry_detail_requested", 0)
			var detail := _preview_child("BestiaryMonsterBoardPanel")
			passed = detail != null and detail.scene_file_path == "res://scenes/ui/BestiaryDetail.tscn"
			flags["bridge_checked"] = true
			notes = "monster double-click route opens the existing detail scene"
		"product_detail_signal_routes":
			_open_product_browser()
			var browser := _preview_child("ProductCodexBrowser")
			if browser != null:
				browser.emit_signal("entry_detail_requested", 0)
			var detail := _preview_child("ProductCodexMarketBoardPanel")
			passed = detail != null and detail.scene_file_path == "res://scenes/ui/ProductCodexDetail.tscn"
			flags["bridge_checked"] = true
			notes = "product double-click route opens the existing detail scene"
		"page_step_signals_stable":
			var bestiary := (load(BESTIARY_BROWSER_SCENE) as PackedScene).instantiate() as Control
			var product := (load(PRODUCT_BROWSER_SCENE) as PackedScene).instantiate() as Control
			add_child(bestiary)
			add_child(product)
			var deltas: Array[int] = []
			bestiary.connect("page_step_requested", func(delta: int) -> void: deltas.append(delta))
			product.connect("page_step_requested", func(delta: int) -> void: deltas.append(delta))
			bestiary.find_child("BestiaryBrowserNextButton", true, false).emit_signal("pressed")
			product.find_child("ProductBrowserPreviousButton", true, false).emit_signal("pressed")
			passed = deltas == [1, -1]
			bestiary.queue_free()
			product.queue_free()
			flags["interaction_checked"] = true
			notes = "scene-owned paging preserves the existing signed delta contract"
		"bestiary_snapshot_pure_data":
			var snapshot: Variant = _main.call("_bestiary_codex_browser_snapshot") if _main != null else {}
			passed = snapshot is Dictionary and _is_pure_data(snapshot)
			flags["pure_data_checked"] = true
			notes = "monster atlas receives a pure-data snapshot"
		"product_snapshot_pure_data":
			var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
			var total := ProductMarketRuntimeController.PRODUCT_CATALOG.size()
			var snapshot: Variant = coordinator.call("product_codex_public_browser_snapshot", {"start_index": 0, "end_index": mini(total, 6), "selected_index": 0, "columns": 3, "can_page": total > 6, "page_label": "测试商品目录"}) if coordinator != null and coordinator.has_method("product_codex_public_browser_snapshot") else {}
			passed = snapshot is Dictionary and _is_pure_data(snapshot)
			flags["pure_data_checked"] = true
			notes = "product atlas receives a pure-data snapshot"
		"privacy_boundary_preserved":
			var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
			var total := ProductMarketRuntimeController.PRODUCT_CATALOG.size()
			var product_snapshot: Variant = coordinator.call("product_codex_public_browser_snapshot", {"start_index": 0, "end_index": mini(total, 6), "selected_index": 0, "columns": 3, "can_page": total > 6, "page_label": "测试商品目录"}) if coordinator != null and coordinator.has_method("product_codex_public_browser_snapshot") else {}
			var snapshots := [_main.call("_bestiary_codex_browser_snapshot"), product_snapshot] if _main != null else []
			passed = _is_pure_data(snapshots) and not _contains_private_key(snapshots)
			flags["privacy_checked"] = true
			notes = "atlas snapshots contain no hidden owner, target, discard, or plan keys"
		"legacy_bestiary_atlas_absent":
			passed = _functions_absent(RETIRED_FUNCTIONS.slice(0, 7))
			flags["deletion_checked"] = true
			notes = "the generated monster atlas closure is deleted"
		"legacy_product_atlas_absent":
			passed = _functions_absent(RETIRED_FUNCTIONS.slice(7, 13))
			flags["deletion_checked"] = true
			notes = "the generated product atlas closure is deleted"
		"all_retired_functions_and_metrics":
			var metrics := _main_metrics()
			passed = RETIRED_FUNCTIONS.size() == 14 and _functions_absent(RETIRED_FUNCTIONS) and int(metrics.get("nonblank_lines", 999999)) <= 41375 and int(metrics.get("function_count", 999999)) <= 2042 and int(metrics.get("top_level_variable_count", 999999)) <= 209 and int(metrics.get("constant_count", 999999)) <= 320
			flags["deletion_checked"] = true
			notes = "all 14 atlas helpers stay absent and main deletion metrics improve"
	return _record(case_id, passed, notes, flags)


func _open_bestiary_browser() -> void:
	if _main != null:
		_main.call("_open_bestiary_menu")


func _open_product_browser() -> void:
	if _main != null:
		_main.call("_open_product_codex_menu")


func _preview_child(node_name: String) -> Control:
	if _overlay == null or not _overlay.has_method("get_preview_host"):
		return null
	var host := _overlay.call("get_preview_host") as Control
	return host.find_child(node_name, true, false) as Control if host != null else null


func _scene_has_contract(scene_path: String, method_name: String) -> bool:
	var packed := load(scene_path) as PackedScene
	var node := packed.instantiate() if packed != null else null
	var passed := node != null and node.has_method(method_name)
	if node != null:
		node.free()
	return passed


func _functions_absent(function_names: Array) -> bool:
	for function_name_variant: Variant in function_names:
		if _main_source.contains("func %s(" % str(function_name_variant)):
			return false
	return true


func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in value:
			if str(key_variant).to_lower() in ["hidden_owner", "hidden_owner_id", "private_target", "private_discard", "private_plan", "ai_private_plan"]:
				return true
			if _contains_private_key(value[key_variant]):
				return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_private_key(item_variant):
				return true
	return false


func _record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var record := {"case_id": case_id, "main_checked": false, "scene_checked": false, "deletion_checked": false, "interaction_checked": false, "bridge_checked": false, "privacy_checked": false, "pure_data_checked": false, "passed": passed, "notes": notes}
	record.merge(flags, true)
	return record


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


func _main_metrics() -> Dictionary:
	var physical_lines := _main_source.split("\n").size()
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
	return {"physical_lines": physical_lines, "nonblank_lines": nonblank_lines, "function_count": function_count, "top_level_variable_count": variable_count, "constant_count": constant_count}


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
	summary_label.text = "%d/%d cutover cases passed" % [passed, total]
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	ownership_text.text = "[b]Scene-owned Codex atlases[/b]\nBestiaryCodexBrowser and ProductCodexBrowser own navigation, thumbnail scene instances, overview cards, hover preview, and input signals. main.gd supplies pure catalog snapshots and keeps existing routes.\n\n[b]Retired from main.gd[/b]\n14 raw-Control atlas builders plus the unused art helper.\n\n[b]Current main metrics[/b]\n%s nonblank lines - %s functions - %s vars - %s constants" % [str(metrics.get("nonblank_lines", 0)), str(metrics.get("function_count", 0)), str(metrics.get("top_level_variable_count", 0)), str(metrics.get("constant_count", 0))]
	var lines: Array[String] = []
	for record_variant: Variant in _records:
		var record := record_variant as Dictionary
		var result := "PASS" if bool(record.get("passed", false)) else "FAIL"
		lines.append("[color=%s][b]%s[/b][/color]  %s\n%s" % ["#4ade80" if result == "PASS" else "#fb7185", result, str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	var lines := ["# Codex Atlas Scene Cutover", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Retired functions: %d" % int(manifest.get("retired_function_count", 0)), "- Main nonblank lines: %d" % int(metrics.get("nonblank_lines", 0)), "", "| Case | Result | Notes |", "| --- | --- | --- |"]
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


func _dispose_main() -> void:
	if _main != null:
		for player_variant: Variant in _main.find_children("*", "AudioStreamPlayer", true, false):
			var player := player_variant as AudioStreamPlayer
			if player != null:
				player.stop()
				player.stream = null
				player.free()
		_main.queue_free()
		_main = null
		_overlay = null
	for _frame in range(4):
		await get_tree().process_frame
