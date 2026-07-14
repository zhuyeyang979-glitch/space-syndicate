extends Control
class_name CodexSceneHardCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const CODEX_SURFACE_SCENE_PATH := "res://scenes/ui/CodexCompendiumSurface.tscn"
const CODEX_SURFACE_SCRIPT_PATH := "res://scripts/ui/codex_compendium_surface.gd"
const COMPENDIUM_HUB_SNAPSHOT_SCRIPT_PATH := "res://scripts/viewmodels/compendium_hub_snapshot.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/codex_scene_hard_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/codex_scene_hard_cutover_sprint_11.png"

const REQUIRED_SCENES := {
	"codex_surface": CODEX_SURFACE_SCENE_PATH,
	"compendium_hub": "res://scenes/ui/CompendiumHubBoard.tscn",
	"card_browser": "res://scenes/ui/CardCodexBrowser.tscn",
	"card_detail": "res://scenes/ui/CardCodexDetail.tscn",
	"bestiary_browser": "res://scenes/ui/BestiaryCodexBrowser.tscn",
	"bestiary_detail": "res://scenes/ui/BestiaryDetail.tscn",
	"product_browser": "res://scenes/ui/ProductCodexBrowser.tscn",
	"product_detail": "res://scenes/ui/ProductCodexDetail.tscn",
	"region_detail": "res://scenes/ui/RegionCodexDetail.tscn",
	"role_detail": "res://scenes/ui/RoleCodexIdentityBoard.tscn",
}

const PRESENTATION_RETIRED_FUNCTIONS := [
	"_add_compendium_hub_board",
	"_compendium_hub_snapshot",
	"_on_compendium_hub_action_requested",
	"_hide_global_menu_navigation_for_catalog",
	"_set_catalog_local_navigation",
	"_add_bestiary_codex_browser",
	"_bestiary_codex_browser_node",
	"_add_bestiary_detail",
	"_refresh_bestiary_hover_preview_only",
	"_add_card_codex_browser",
	"_card_codex_browser_node",
	"_refresh_card_codex_hover_preview_only",
	"_add_role_codex_identity_board_panel",
	"_add_product_codex_browser",
	"_product_codex_browser_node",
	"_refresh_product_codex_hover_preview_only",
	"_add_product_codex_detail_preview",
	"_add_product_codex_detail",
	"_add_card_codex_detail",
	"_add_bestiary_monster_card_link",
	"_add_region_codex_detail",
]

const RETIRED_FUNCTIONS := [
	"_add_bestiary_monster_board_panel",
	"_add_bestiary_monster_chip",
	"_add_bestiary_monster_kpi",
	"_add_bestiary_monster_action_card",
	"_populate_card_codex_thumbnail_page",
	"_add_card_codex_thumbnail",
	"_add_card_codex_thumbnail_chip_rail",
	"_add_card_codex_hover_preview",
	"_on_card_codex_thumbnail_gui_input",
	"_add_product_codex_market_board_panel",
	"_add_product_codex_market_chip",
	"_add_product_codex_market_kpi",
	"_add_product_codex_strategy_card",
	"_add_card_codex_filter_buttons",
	"_add_card_codex_detail_layout",
	"_add_card_codex_tcg_summary_panel",
	"_add_card_codex_tactical_strip",
	"_add_card_codex_tactical_card",
	"_add_card_codex_tcg_chip",
	"_add_card_level_gradient_cards",
	"_add_card_level_gradient_step_card",
	"_add_region_codex_tile_board_panel",
	"_add_region_codex_kpi",
	"_add_region_codex_clue_card",
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
var _card_names: Array = []


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_cutover_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func retired_function_names() -> Array:
	return RETIRED_FUNCTIONS.duplicate()


func presentation_retired_function_names() -> Array:
	return PRESENTATION_RETIRED_FUNCTIONS.duplicate()


func cutover_cases() -> Array:
	return [
		"required_codex_scenes_load",
		"required_scene_contracts",
		"real_main_scene_loads",
		"single_sceneized_menu_overlay",
		"card_browser_scene_required",
		"card_browser_signal_routes_detail",
		"card_detail_scene_required",
		"bestiary_detail_scene_required",
		"product_detail_scene_required",
		"region_detail_scene_required",
		"role_detail_scene_required",
		"legacy_card_browser_renderer_absent",
		"legacy_card_detail_renderer_absent",
		"legacy_bestiary_detail_renderer_absent",
		"legacy_product_detail_renderer_absent",
		"legacy_region_detail_renderer_absent",
		"all_retired_functions_absent",
		"required_scene_error_boundary_present",
		"codex_snapshots_pure_data",
		"privacy_boundary_preserved",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant: Variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite": "codex-scene-hard-cutover-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"retired_function_count": RETIRED_FUNCTIONS.size(),
		"presentation_retired_function_count": PRESENTATION_RETIRED_FUNCTIONS.size(),
		"record_count": records.size(),
		"records": records,
	}


func run_cutover_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	_main_source = FileAccess.get_file_as_string(MAIN_SCRIPT_PATH).replace("\r\n", "\n")
	await _ensure_main()
	for case_id_variant: Variant in cutover_cases():
		var case_id := str(case_id_variant)
		var record := _run_case(case_id)
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "failed"))])
	var manifest := {
		"suite": "codex-scene-hard-cutover-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": _records.size(),
		"passed_count": _passed_count(),
		"retired_function_count": RETIRED_FUNCTIONS.size(),
		"presentation_retired_function_count": PRESENTATION_RETIRED_FUNCTIONS.size(),
		"main_metrics": _main_metrics(),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await _dispose_main()
	_save_screenshot()
	print("CodexSceneHardCutoverBench manifest: %s" % MANIFEST_PATH)
	print("CodexSceneHardCutoverBench report: %s" % REPORT_PATH)
	print("CodexSceneHardCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("CodexSceneHardCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("CodexSceneHardCutoverBench failed:\n- %s" % "\n- ".join(_failures))
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
	var names_variant: Variant = _main.call("_card_codex_names") if _main.has_method("_card_codex_names") else []
	_card_names = names_variant if names_variant is Array else []


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	match case_id:
		"required_codex_scenes_load":
			passed = true
			for scene_path_variant: Variant in REQUIRED_SCENES.values():
				passed = passed and load(str(scene_path_variant)) is PackedScene
			flags["scene_checked"] = true
			notes = "all six Codex surfaces are editable PackedScenes"
		"required_scene_contracts":
			var contracts := {
				"codex_surface": "set_page",
				"compendium_hub": "set_hub",
				"card_browser": "set_browser",
				"card_detail": "set_detail",
				"bestiary_browser": "set_browser",
				"bestiary_detail": "set_monster",
				"product_browser": "set_browser",
				"product_detail": "set_product",
				"region_detail": "set_region",
				"role_detail": "set_role",
			}
			passed = true
			for scene_id_variant: Variant in contracts:
				var packed := load(str(REQUIRED_SCENES.get(scene_id_variant, ""))) as PackedScene
				var node := packed.instantiate() if packed != null else null
				passed = passed and node != null and node.has_method(str(contracts.get(scene_id_variant, "")))
				if node != null:
					node.free()
			flags["scene_checked"] = true
			notes = "the static Codex host and each child scene expose data-in renderer contracts"
		"real_main_scene_loads":
			passed = _main != null and _main.scene_file_path == MAIN_SCENE_PATH
			flags["main_checked"] = true
			notes = "the gate instantiates the real main scene"
		"single_sceneized_menu_overlay":
			var overlays := _main.find_children("MenuModalOverlay", "Control", true, false) if _main != null else []
			var surface := _overlay.call("get_codex_surface") as Control if _overlay != null and _overlay.has_method("get_codex_surface") else null
			passed = _overlay != null and _overlay.scene_file_path == "res://scenes/ui/MenuOverlay.tscn" and overlays.size() == 1 and surface != null and surface.scene_file_path == CODEX_SURFACE_SCENE_PATH
			flags["scene_checked"] = true
			notes = "one MenuOverlay owns one static CodexCompendiumSurface"
		"card_browser_scene_required":
			if _main != null:
				_main.call("_open_card_codex_from_compendium")
			var browser := _preview_child("CardCodexBrowserPanel")
			passed = browser != null and browser.scene_file_path == str(REQUIRED_SCENES.get("card_browser", "")) and browser.has_signal("card_detail_requested")
			flags["scene_checked"] = true
			notes = "the real card atlas uses CardCodexBrowser.tscn"
		"card_browser_signal_routes_detail":
			var browser := _preview_child("CardCodexBrowserPanel")
			var card_name := str(_card_names[0]) if not _card_names.is_empty() else ""
			if browser != null and card_name != "":
				browser.emit_signal("card_detail_requested", card_name)
			var detail := _preview_child("CardCodexDetailPanel")
			passed = detail != null and detail.scene_file_path == str(REQUIRED_SCENES.get("card_detail", ""))
			flags["bridge_checked"] = true
			notes = "the scene-owned browser signal reaches the existing detail route"
		"card_detail_scene_required":
			var detail := _preview_child("CardCodexDetailPanel")
			passed = detail != null and detail.has_method("set_detail")
			flags["scene_checked"] = true
			notes = "card detail has no generated fallback surface"
		"bestiary_detail_scene_required":
			if _main != null:
				_main.call("_open_bestiary_menu", 0)
			var detail := _preview_child("BestiaryMonsterBoardPanel")
			passed = detail != null and detail.scene_file_path == str(REQUIRED_SCENES.get("bestiary_detail", ""))
			flags["scene_checked"] = true
			notes = "monster detail uses BestiaryDetail.tscn"
		"product_detail_scene_required":
			if _main != null:
				_main.call("_open_product_codex_detail", 0)
			var detail := _preview_child("ProductCodexMarketBoardPanel")
			passed = detail != null and detail.scene_file_path == str(REQUIRED_SCENES.get("product_detail", ""))
			flags["scene_checked"] = true
			notes = "product detail uses ProductCodexDetail.tscn"
		"region_detail_scene_required":
			if _main != null:
				_main.call("_open_region_codex_menu", 0)
			var detail := _preview_child("RegionCodexTileBoardPanel")
			passed = detail != null and detail.scene_file_path == str(REQUIRED_SCENES.get("region_detail", ""))
			flags["scene_checked"] = true
			notes = "region detail uses RegionCodexDetail.tscn"
		"role_detail_scene_required":
			if _main != null:
				_main.call("_open_role_codex_menu", 0)
			var detail := _preview_child("RoleCodexIdentityBoardPanel")
			passed = detail != null and detail.scene_file_path == str(REQUIRED_SCENES.get("role_detail", ""))
			flags["scene_checked"] = true
			notes = "role detail uses RoleCodexIdentityBoard.tscn"
		"legacy_card_browser_renderer_absent":
			passed = _functions_absent(["_populate_card_codex_thumbnail_page", "_add_card_codex_thumbnail", "_add_card_codex_thumbnail_chip_rail", "_add_card_codex_hover_preview", "_add_card_codex_filter_buttons", "_on_card_codex_thumbnail_gui_input"])
			flags["deletion_checked"] = true
			notes = "the card atlas cannot rebuild a generated browser"
		"legacy_card_detail_renderer_absent":
			passed = _functions_absent(["_add_card_codex_detail_layout", "_add_card_codex_tcg_summary_panel", "_add_card_codex_tactical_strip", "_add_card_codex_tactical_card", "_add_card_codex_tcg_chip", "_add_card_level_gradient_cards", "_add_card_level_gradient_step_card"])
			flags["deletion_checked"] = true
			notes = "the generated card-detail renderer is deleted"
		"legacy_bestiary_detail_renderer_absent":
			passed = _functions_absent(["_add_bestiary_monster_board_panel", "_add_bestiary_monster_chip", "_add_bestiary_monster_kpi", "_add_bestiary_monster_action_card"])
			flags["deletion_checked"] = true
			notes = "the generated bestiary-detail renderer is deleted"
		"legacy_product_detail_renderer_absent":
			passed = _functions_absent(["_add_product_codex_market_board_panel", "_add_product_codex_market_chip", "_add_product_codex_market_kpi", "_add_product_codex_strategy_card"])
			flags["deletion_checked"] = true
			notes = "the generated product-detail renderer is deleted"
		"legacy_region_detail_renderer_absent":
			passed = _functions_absent(["_add_region_codex_tile_board_panel", "_add_region_codex_kpi", "_add_region_codex_clue_card"])
			flags["deletion_checked"] = true
			notes = "the generated region-detail renderer is deleted"
		"all_retired_functions_absent":
			passed = RETIRED_FUNCTIONS.size() == 24 and _functions_absent(RETIRED_FUNCTIONS)
			flags["deletion_checked"] = true
			notes = "the complete 24-function renderer closure stays absent"
		"required_scene_error_boundary_present":
			var surface_source := FileAccess.get_file_as_string(CODEX_SURFACE_SCRIPT_PATH)
			var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/menu_overlay.gd")
			passed = surface_source.contains("generated fallbacks are disabled") and surface_source.contains("func _contract_surfaces()") and not surface_source.contains("find_child(")
			for component_name in ["CompendiumHubBoardPanel", "CardCodexBrowserPanel", "CardCodexDetailPanel", "BestiaryCodexBrowser", "BestiaryMonsterBoardPanel", "ProductCodexBrowser", "ProductCodexMarketBoardPanel", "RegionCodexTileBoardPanel", "RoleCodexIdentityBoardPanel"]:
				passed = passed and surface_source.contains("\"%s\"" % component_name)
			for scene_path_variant: Variant in REQUIRED_SCENES.values():
				passed = passed and not _main_source.contains(str(scene_path_variant))
			passed = passed and _functions_absent(PRESENTATION_RETIRED_FUNCTIONS)
			passed = passed and overlay_source.contains("child.is_in_group(\"persistent_menu_surface\")")
			passed = passed and _main_source.count("menu_overlay.call(\"clear_preview\")") >= 17
			passed = passed and _main_source.count("menu_overlay.call(\"clear_preview\")\n\tmenu_preview_box.visible = true") >= 15
			passed = passed and _main_source.contains("menu_overlay.call(\"clear_preview\")\n\t\tmenu_preview_box.visible = true")
			passed = passed and not _main_source.contains("child.is_in_group(\"persistent_menu_surface\")")
			flags["bridge_checked"] = true
			flags["deletion_checked"] = true
			notes = "MenuOverlay owns static Surface cleanup while main has no Codex scene preload, UI-group policy, or legacy renderer"
		"codex_snapshots_pure_data":
			var snapshots := _codex_snapshots()
			passed = snapshots.size() == 7 and _is_pure_data(snapshots)
			flags["pure_data_checked"] = true
			notes = "the hub and all six Codex content boundaries receive data-only snapshots"
		"privacy_boundary_preserved":
			var snapshots := _codex_snapshots()
			passed = not _contains_private_key(snapshots)
			flags["privacy_checked"] = true
			notes = "Codex snapshots contain no hidden-owner, private-target, or private-discard keys"
	return _record(case_id, passed, notes, flags)


func _preview_child(node_name: String) -> Control:
	if _overlay == null or not _overlay.has_method("get_preview_host"):
		return null
	var host := _overlay.call("get_preview_host") as Control
	return host.find_child(node_name, true, false) as Control if host != null else null


func _codex_snapshots() -> Array:
	if _main == null:
		return []
	var card_name := str(_card_names[0]) if not _card_names.is_empty() else ""
	var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var skill: Dictionary = coordinator.call("card_definition", card_name) if coordinator != null and card_name != "" else {}
	var role_card: Dictionary = _main.call("_make_player_role_card", 0)
	var region_snapshot := _main.call("_region_codex_public_snapshot", 0) as Dictionary
	var role_snapshot := _main.call("_role_codex_public_snapshot", role_card, 0, 1) as Dictionary
	var hub_script := load(COMPENDIUM_HUB_SNAPSHOT_SCRIPT_PATH) as Script
	var hub_snapshot: Dictionary = hub_script.call("compose", 960.0) as Dictionary if hub_script != null else {}
	return [
		hub_snapshot,
		_main.call("_card_codex_public_browser_snapshot", _card_names),
		(_main.call("_card_codex_public_detail_snapshot", card_name, skill, 0, maxi(1, _card_names.size())) as Dictionary).get("detail", {}),
		(_main.call("_monster_codex_public_snapshot", 0, true) as Dictionary).get("detail", {}),
		(_main.call("_product_codex_public_snapshot", str((_main.call("_product_catalog_names") as Array)[0]), 0, true) as Dictionary).get("detail", {}),
		region_snapshot.get("detail", {}),
		role_snapshot.get("board", {}),
	]


func _functions_absent(function_names: Array) -> bool:
	for function_name_variant: Variant in function_names:
		if _main_source.contains("func %s(" % str(function_name_variant)):
			return false
	return true


func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in value:
			var key := str(key_variant).to_lower()
			if key in ["hidden_owner", "hidden_owner_id", "private_target", "private_discard", "private_plan", "ai_private_plan"]:
				return true
			if _contains_private_key(value[key_variant]):
				return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_private_key(item_variant):
				return true
	return false


func _record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var record := {
		"case_id": case_id,
		"main_checked": false,
		"scene_checked": false,
		"deletion_checked": false,
		"bridge_checked": false,
		"privacy_checked": false,
		"pure_data_checked": false,
		"passed": passed,
		"notes": notes,
	}
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
	ownership_text.text = "[b]Scene-owned Codex surfaces[/b]\nCodexCompendiumSurface statically owns the hub, browser, and detail scenes. main.gd only builds pure public snapshots and routes actions.\n\n[b]Retired from main.gd[/b]\n24 earlier generated renderers plus %d presentation-construction, find-child, and local-navigation helpers.\n\n[b]Current main metrics[/b]\n%s nonblank lines - %s functions - %s vars - %s constants" % [PRESENTATION_RETIRED_FUNCTIONS.size(), str(metrics.get("nonblank_lines", 0)), str(metrics.get("function_count", 0)), str(metrics.get("top_level_variable_count", 0)), str(metrics.get("constant_count", 0))]
	var lines: Array[String] = []
	for record_variant: Variant in _records:
		var record := record_variant as Dictionary
		var result := "PASS" if bool(record.get("passed", false)) else "FAIL"
		lines.append("[color=%s][b]%s[/b][/color]  %s\n%s" % ["#4ade80" if result == "PASS" else "#fb7185", result, str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	var lines := ["# Codex Scene Hard Cutover", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Earlier retired functions: %d" % int(manifest.get("retired_function_count", 0)), "- Presentation retired functions: %d" % int(manifest.get("presentation_retired_function_count", 0)), "- Main nonblank lines: %d" % int(metrics.get("nonblank_lines", 0)), "", "| Case | Result | Notes |", "| --- | --- | --- |"]
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
