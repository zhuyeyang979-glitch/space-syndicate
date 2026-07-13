extends Control
class_name MenuShellRuntimeCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const MENU_OVERLAY_SCENE_PATH := "res://scenes/ui/MenuOverlay.tscn"
const QUICK_NAV_SCENE_PATH := "res://scenes/ui/MenuQuickNavigation.tscn"
const PRESENTATION_SETTINGS_SCENE_PATH := "res://scenes/ui/PresentationSettingsPanel.tscn"
const SCENARIO_PAUSE_ACTIONS_SCENE_PATH := "res://scenes/ui/ScenarioPauseActionsPanel.tscn"
const GlobalNavigationRegistryScript := preload("res://scripts/tools/global_ui_navigation_characterization_registry.gd")
const OUTPUT_DIR := "user://space_syndicate_design_qa/menu_shell_runtime_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/menu_shell_runtime_cutover_sprint_24.png"
const GLOBAL_NAVIGATION_OUTPUT_DIR := "user://space_syndicate_design_qa/global_ui_navigation_characterization/"
const GLOBAL_NAVIGATION_MANIFEST_PATH := GLOBAL_NAVIGATION_OUTPUT_DIR + "manifest.json"
const GLOBAL_NAVIGATION_REPORT_PATH := GLOBAL_NAVIGATION_OUTPUT_DIR + "report.md"
const GLOBAL_NAVIGATION_SCREENSHOT_PATH := "user://space_syndicate_design_qa/global_ui_navigation_characterization_sprint_67.png"

@export var auto_run := true

@onready var status_label: Label = %StatusLabel
@onready var summary_label: Label = %SummaryLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var results_text: RichTextLabel = %ResultsText

var _records: Array = []
var _global_navigation_records: Array = []
var _failures: Array[String] = []
var _main: Control = null
var _overlay: Control = null
var _main_source := ""
var _last_quick_action_id := ""


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_cutover_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func global_navigation_output_dir() -> String:
	return GLOBAL_NAVIGATION_OUTPUT_DIR


func global_navigation_cases() -> Array:
	return GlobalNavigationRegistryScript.case_ids()


func global_navigation_surface_registry() -> Array:
	return GlobalNavigationRegistryScript.surface_registry()


func global_navigation_deletion_candidates() -> Array:
	return GlobalNavigationRegistryScript.deletion_candidates()


func cutover_cases() -> Array:
	return [
		"quick_navigation_scene_loads",
		"overlay_scene_composition",
		"seven_editable_buttons",
		"real_main_scene_loads",
		"real_main_uses_embedded_overlay",
		"menu_overlay_fallback_preload_absent",
		"legacy_menu_builder_absent",
		"legacy_shell_node_state_absent",
		"legacy_quick_nav_builder_absent",
		"pure_quick_nav_payload",
		"root_menu_hides_quick_navigation",
		"subpage_shows_quick_navigation",
		"active_page_is_disabled",
		"enabled_action_emits_id",
		"quick_action_routes_real_main",
		"responsive_layout_owned_by_overlay",
		"catalog_navigation_owned_by_overlay",
		"overlay_debug_snapshot_pure_data",
		"settings_scenes_load",
		"campaign_settings_static_actions",
		"scenario_settings_static_actions",
		"pause_actions_static_actions",
		"real_main_settings_routes",
		"legacy_settings_builders_absent",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant: Variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite": "menu-shell-runtime-cutover-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"records": records,
	}


func build_global_navigation_manifest_preview() -> Dictionary:
	var records: Array = []
	for source_variant: Variant in GlobalNavigationRegistryScript.characterization_cases():
		var record := (source_variant as Dictionary).duplicate(true)
		record["observed"] = false
		record["pure_data_checked"] = _is_pure_data(record)
		records.append(record)
	return {
		"suite": "global-ui-navigation-characterization-v04-sprint-67",
		"output_dir": GLOBAL_NAVIGATION_OUTPUT_DIR,
		"screenshot_path": GLOBAL_NAVIGATION_SCREENSHOT_PATH,
		"record_count": records.size(),
		"surface_registry": global_navigation_surface_registry(),
		"deletion_candidates": global_navigation_deletion_candidates(),
		"records": records,
	}


func run_cutover_suite() -> void:
	_records.clear()
	_global_navigation_records.clear()
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
	_run_global_navigation_characterization()
	var manifest := {
		"suite": "menu-shell-runtime-cutover-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": _records.size(),
		"passed_count": _passed_count(),
		"main_metrics": _main_metrics(),
		"records": _records.duplicate(true),
	}
	var global_manifest := {
		"suite": "global-ui-navigation-characterization-v04-sprint-67",
		"output_dir": GLOBAL_NAVIGATION_OUTPUT_DIR,
		"screenshot_path": GLOBAL_NAVIGATION_SCREENSHOT_PATH,
		"record_count": _global_navigation_records.size(),
		"observed_count": _global_observed_count(),
		"aligned_count": _global_aligned_count(),
		"main_metrics": _main_metrics(),
		"surface_registry": global_navigation_surface_registry(),
		"deletion_candidates": global_navigation_deletion_candidates(),
		"records": _global_navigation_records.duplicate(true),
	}
	if int(global_manifest.get("observed_count", 0)) != int(global_manifest.get("record_count", 0)):
		_failures.append("global navigation characterization did not observe every registered case")
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_write_text(GLOBAL_NAVIGATION_MANIFEST_PATH, JSON.stringify(global_manifest, "\t"))
	_write_text(GLOBAL_NAVIGATION_REPORT_PATH, _global_navigation_markdown_report(global_manifest))
	_update_ui(manifest, global_manifest)
	await _dispose_main()
	_save_screenshot()
	print("MenuShellRuntimeCutoverBench manifest: %s" % MANIFEST_PATH)
	print("MenuShellRuntimeCutoverBench report: %s" % REPORT_PATH)
	print("MenuShellRuntimeCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("MenuShellRuntimeCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	print("GlobalUiNavigationCharacterization manifest: %s" % GLOBAL_NAVIGATION_MANIFEST_PATH)
	print("GlobalUiNavigationCharacterization report: %s" % GLOBAL_NAVIGATION_REPORT_PATH)
	print("GlobalUiNavigationCharacterization screenshot: %s" % GLOBAL_NAVIGATION_SCREENSHOT_PATH)
	print("GlobalUiNavigationCharacterization observed: %d/%d; aligned: %d/%d" % [_global_observed_count(), _global_navigation_records.size(), _global_aligned_count(), _global_navigation_records.size()])
	if not _failures.is_empty():
		push_error("MenuShellRuntimeCutoverBench failed:\n- %s" % "\n- ".join(_failures))
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
	await get_tree().process_frame
	_overlay = _main.find_child("MenuModalOverlay", true, false) as Control
	if _overlay != null and _overlay.has_signal("quick_nav_action_requested"):
		_overlay.connect("quick_nav_action_requested", func(action_id: String) -> void:
			_last_quick_action_id = action_id
		)


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	match case_id:
		"quick_navigation_scene_loads":
			passed = load(QUICK_NAV_SCENE_PATH) is PackedScene
			flags["scene_checked"] = true
			notes = "MenuQuickNavigation is an editable PackedScene"
		"overlay_scene_composition":
			var overlay_source := FileAccess.get_file_as_string(MENU_OVERLAY_SCENE_PATH)
			passed = overlay_source.contains(QUICK_NAV_SCENE_PATH) and overlay_source.contains("MenuQuickNavigation")
			flags["scene_checked"] = true
			notes = "MenuOverlay embeds the quick-navigation scene"
		"seven_editable_buttons":
			var quick_nav := _overlay.find_child("MenuQuickNavigation", true, false) if _overlay != null else null
			passed = quick_nav != null
			for node_name in ["MenuQuickNavSetupButton", "MenuQuickNavScenarioButton", "MenuQuickNavStandingsButton", "MenuQuickNavEconomyButton", "MenuQuickNavIntelButton", "MenuQuickNavRulesButton", "MenuQuickNavCompendiumButton"]:
				passed = passed and quick_nav != null and quick_nav.find_child(node_name, true, false) is Button
			flags["scene_checked"] = true
			notes = "all seven navigation commands are editor-visible Button nodes"
		"real_main_scene_loads":
			passed = _main != null and _main.scene_file_path == MAIN_SCENE_PATH
			flags["main_checked"] = true
			notes = "the gate instantiates the real main scene"
		"real_main_uses_embedded_overlay":
			passed = _overlay != null and _overlay.scene_file_path == MENU_OVERLAY_SCENE_PATH and _main.get("menu_overlay") == _overlay
			flags["main_checked"] = true
			flags["scene_checked"] = true
			notes = "main binds OverlayLayer's MenuOverlay without a parallel instance"
		"menu_overlay_fallback_preload_absent":
			passed = not _main_source.contains("const MenuOverlayScene") and not _main_source.contains("MenuOverlayScene.instantiate")
			flags["deletion_checked"] = true
			notes = "main cannot preload or instantiate a fallback menu shell"
		"legacy_menu_builder_absent":
			passed = not _main_source.contains("func _build_menu_overlay") and _main_source.contains("func _bind_menu_overlay_scene")
			flags["deletion_checked"] = true
			notes = "the runtime menu builder is replaced by a required-scene binder"
		"legacy_shell_node_state_absent":
			var retired_tokens := ["var menu_surface_panel", "var menu_shell_margin", "var menu_title_label", "var menu_context_label", "var menu_body_label", "var menu_continue_button", "var menu_bestiary_prev_button"]
			passed = true
			for token_variant: Variant in retired_tokens:
				passed = passed and not _main_source.contains(str(token_variant))
			flags["deletion_checked"] = true
			notes = "main no longer mirrors scene-owned shell nodes as state"
		"legacy_quick_nav_builder_absent":
			passed = not _main_source.contains("func _add_menu_quick_nav_button") and not _main_source.contains("menu_quick_nav_buttons")
			flags["deletion_checked"] = true
			notes = "quick navigation no longer creates controls or stores Button objects in main"
		"pure_quick_nav_payload":
			var payload: Variant = _main.call("_menu_quick_nav_entries") if _main != null and _main.has_method("_menu_quick_nav_entries") else []
			passed = payload is Array and (payload as Array).size() == 7 and _is_pure_data(payload)
			flags["pure_data_checked"] = true
			notes = "main sends seven data-only action descriptors"
		"root_menu_hides_quick_navigation":
			if _main != null:
				_main.call("_open_main_menu")
			var snapshot := _overlay.call("debug_snapshot") as Dictionary if _overlay != null else {}
			var quick := snapshot.get("quick_navigation", {}) as Dictionary
			passed = bool(snapshot.get("root_table_menu", false)) and not bool(quick.get("visible", true))
			flags["interaction_checked"] = true
			notes = "the full-screen lobby keeps branch navigation out of the first viewport"
		"subpage_shows_quick_navigation":
			if _main != null:
				_main.call("_open_standings_menu")
			var snapshot := _overlay.call("debug_snapshot") as Dictionary if _overlay != null else {}
			var quick := snapshot.get("quick_navigation", {}) as Dictionary
			passed = str(snapshot.get("title", "")) == "局势排名" and bool(quick.get("visible", false)) and (quick.get("rendered", []) as Array).size() == 7
			flags["interaction_checked"] = true
			notes = "operational subpages expose all branch shortcuts"
		"active_page_is_disabled":
			var snapshot := _overlay.call("debug_snapshot") as Dictionary if _overlay != null else {}
			var quick := snapshot.get("quick_navigation", {}) as Dictionary
			passed = str(quick.get("active_id", "")) == "standings" and _rendered_action_disabled(quick, "standings")
			flags["interaction_checked"] = true
			notes = "the current branch remains visible but cannot reopen itself"
		"enabled_action_emits_id":
			_last_quick_action_id = ""
			var economy_button := _overlay.find_child("MenuQuickNavEconomyButton", true, false) as Button if _overlay != null else null
			if economy_button != null:
				economy_button.emit_signal("pressed")
			passed = _last_quick_action_id == "economy"
			flags["interaction_checked"] = true
			notes = "scene-owned buttons emit the existing string action id"
		"quick_action_routes_real_main":
			var snapshot := _overlay.call("debug_snapshot") as Dictionary if _overlay != null else {}
			passed = str(snapshot.get("title", "")) == "经济总览"
			flags["bridge_checked"] = true
			notes = "the emitted economy id reaches main's existing menu route"
		"responsive_layout_owned_by_overlay":
			var desktop_width := float(_overlay.call("available_content_width", Vector2(1600, 960))) if _overlay != null else 0.0
			var compact_width := float(_overlay.call("available_content_width", Vector2(800, 600))) if _overlay != null else 0.0
			passed = desktop_width > 260.0 and compact_width >= 260.0 and _overlay.has_method("refresh_current_layout")
			flags["layout_checked"] = true
			notes = "content sizing and responsive shell layout live in MenuOverlay"
		"catalog_navigation_owned_by_overlay":
			if _overlay != null:
				_overlay.call("set_catalog_navigation", {"prev_visible": true, "next_visible": true, "back_visible": true, "back_text": "返回缩略图"})
			var snapshot := _overlay.call("debug_snapshot") as Dictionary if _overlay != null else {}
			passed = bool(snapshot.get("catalog_navigation_visible", false))
			flags["interaction_checked"] = true
			notes = "catalog navigation visibility remains scene-owned"
		"overlay_debug_snapshot_pure_data":
			var snapshot: Variant = _overlay.call("debug_snapshot") if _overlay != null else {}
			passed = snapshot is Dictionary and _is_pure_data(snapshot)
			flags["pure_data_checked"] = true
			notes = "MenuOverlay QA state contains no Node, Object, Resource, or Callable"
		"settings_scenes_load":
			passed = load(PRESENTATION_SETTINGS_SCENE_PATH) is PackedScene and load(SCENARIO_PAUSE_ACTIONS_SCENE_PATH) is PackedScene
			flags["scene_checked"] = true
			notes = "presentation settings and scenario pause actions are editable PackedScenes"
		"campaign_settings_static_actions":
			if _main != null:
				_main.call("_open_campaign_settings_menu")
			var panel := _settings_panel()
			var snapshot: Dictionary = panel.call("debug_snapshot") as Dictionary if panel != null and panel.has_method("debug_snapshot") else {}
			var expected_ids := ["campaign_toggle_teaching_hints", "campaign_cycle_animation_intensity", "campaign_cycle_font_scale", "campaign_toggle_colorblind", "campaign_cycle_ui_volume", "campaign_cycle_bgm_volume", "campaign_reset_progress", "campaign_settings_back"]
			passed = panel != null and str(snapshot.get("mode", "")) == "campaign" and _snapshot_action_ids(snapshot) == expected_ids and _static_buttons_exist(panel, ["CampaignTeachingHintsButton", "CampaignAnimationButton", "CampaignFontScaleButton", "CampaignColorblindButton", "CampaignUiVolumeButton", "CampaignBgmVolumeButton", "CampaignResetProgressButton", "CampaignSettingsBackButton"])
			flags["scene_checked"] = true
			flags["interaction_checked"] = true
			flags["pure_data_checked"] = _is_pure_data(snapshot)
			notes = "campaign presentation settings render eight static scene-owned action ids"
		"scenario_settings_static_actions":
			if _main != null:
				_main.call("_open_scenario_settings_menu")
			var panel := _settings_panel()
			var snapshot: Dictionary = panel.call("debug_snapshot") as Dictionary if panel != null and panel.has_method("debug_snapshot") else {}
			var expected_ids := ["scenario_toggle_teaching_hints", "scenario_toggle_auto_pause", "scenario_cycle_font_scale", "scenario_settings_back"]
			passed = panel != null and str(snapshot.get("mode", "")) == "scenario" and _snapshot_action_ids(snapshot) == expected_ids and _static_buttons_exist(panel, ["ScenarioTeachingHintsButton", "ScenarioAutoPauseButton", "ScenarioFontScaleButton", "ScenarioSettingsBackButton"])
			flags["scene_checked"] = true
			flags["interaction_checked"] = true
			flags["pure_data_checked"] = _is_pure_data(snapshot)
			notes = "scenario presentation settings render four static scene-owned action ids"
		"pause_actions_static_actions":
			var coordinator := _main.find_child("GameRuntimeCoordinator", true, false) if _main != null else null
			if coordinator != null and coordinator.has_method("start_runtime_scenario"):
				coordinator.call("start_runtime_scenario", "first_table", 0.0)
			if _main != null:
				_main.call("_open_pause_menu")
			var panel := _pause_actions_panel()
			var snapshot: Dictionary = panel.call("debug_snapshot") as Dictionary if panel != null and panel.has_method("debug_snapshot") else {}
			var expected_ids := ["scenario_pause_restart", "scenario_pause_choose", "scenario_pause_log", "scenario_pause_replay", "scenario_pause_settings"]
			passed = panel != null and _snapshot_action_ids(snapshot) == expected_ids and _static_buttons_exist(panel, ["ScenarioPauseRestartButton", "ScenarioPauseChooseButton", "ScenarioPauseLogButton", "ScenarioPauseReplayButton", "ScenarioPauseSettingsButton"])
			flags["scene_checked"] = true
			flags["interaction_checked"] = true
			flags["pure_data_checked"] = _is_pure_data(snapshot)
			notes = "active-scenario pause commands are five static scene-owned buttons"
		"real_main_settings_routes":
			var pause_panel := _pause_actions_panel()
			var settings_button := pause_panel.find_child("ScenarioPauseSettingsButton", true, false) as Button if pause_panel != null else null
			if settings_button != null:
				settings_button.emit_signal("pressed")
			var scenario_title := _overlay_title()
			var scenario_panel := _settings_panel()
			var scenario_back := scenario_panel.find_child("ScenarioSettingsBackButton", true, false) as Button if scenario_panel != null else null
			if scenario_back != null:
				scenario_back.emit_signal("pressed")
			var browser_title := _overlay_title()
			if _main != null:
				_main.call("_open_campaign_settings_menu")
			var campaign_panel := _settings_panel()
			var campaign_back := campaign_panel.find_child("CampaignSettingsBackButton", true, false) as Button if campaign_panel != null else null
			if campaign_back != null:
				campaign_back.emit_signal("pressed")
			var campaign_title := _overlay_title()
			passed = scenario_title == "剧本教学设置" and browser_title == "试玩剧本" and campaign_title == "新手战役"
			flags["bridge_checked"] = true
			flags["interaction_checked"] = true
			notes = "pause settings, scenario back, and campaign back ids reach existing real-main routes"
		"legacy_settings_builders_absent":
			var retired_tokens := ["func _add_campaign_settings_button", "func _scenario_settings_summary_text", "func _add_scenario_pause_actions(", "func _add_main_menu_section", "func _menu_section_style"]
			passed = _main_source.contains("PresentationSettingsPanelScene.instantiate()") and _main_source.contains("ScenarioPauseActionsPanelScene.instantiate()") and _main_source.contains("func _on_presentation_menu_action_requested")
			for token_variant: Variant in retired_tokens:
				passed = passed and not _main_source.contains(str(token_variant))
			flags["deletion_checked"] = true
			flags["bridge_checked"] = true
			notes = "main keeps pure descriptors and one action router; all three generated-control branches are absent"
	return _record(case_id, passed, notes, flags)


func _run_global_navigation_characterization() -> void:
	for source_variant: Variant in GlobalNavigationRegistryScript.characterization_cases():
		var source := (source_variant as Dictionary).duplicate(true)
		print("GlobalUiNavigationCharacterization case: %s" % str(source.get("case_id", "")))
		var observation := _observe_global_navigation_case(str(source.get("case_id", "")))
		source["resolved_action"] = str(observation.get("resolved_action", source.get("documented_current_action", "")))
		source["observed"] = bool(observation.get("observed", false))
		if observation.has("focus_before"):
			source["focus_before"] = str(observation.get("focus_before", "untracked"))
		if observation.has("focus_after"):
			source["focus_after"] = str(observation.get("focus_after", "untracked"))
		source["contract_aligned"] = bool(source.get("observed", false)) and str(source.get("resolved_action", "")) == str(source.get("expected_action", ""))
		source["pure_data_checked"] = _is_pure_data(source)
		_global_navigation_records.append(source)
	_reset_navigation_surfaces()


func _observe_global_navigation_case(case_id: String) -> Dictionary:
	var result := {"observed": false, "resolved_action": "unobserved"}
	if _main == null:
		return result
	match case_id:
		"navigation_call_graph_complete":
			result = _source_observation(["func _unhandled_input(", "func _show_menu(", "func _close_menu(", "func _back_from_catalog_menu("], "main_scattered_routes")
		"current_escape_precedence_recorded":
			var input_source := _main_input_source()
			var map_position := input_source.find("full_map_overlay")
			var menu_position := input_source.find("menu_overlay")
			var pause_position := input_source.find("_open_pause_menu()")
			result = {"observed": map_position >= 0 and menu_position > map_position and pause_position > menu_position, "resolved_action": "fullscreen_map_then_menu_then_pause"}
		"gameplay_escape_opens_pause":
			_reset_navigation_surfaces()
			_dispatch_escape()
			result = {"observed": _menu_visible(), "resolved_action": "open_pause_menu" if _overlay_title() == "暂停菜单" else "open_unknown_menu"}
		"pause_escape_returns_game":
			_reset_navigation_surfaces()
			_main.call("_open_pause_menu")
			_dispatch_escape()
			result = {"observed": not _menu_visible(), "resolved_action": "close_menu_resume_game" if not _menu_visible() else "pause_menu_remains"}
		"fullscreen_map_escape_closes_map_only":
			_reset_navigation_surfaces()
			_main.call("_open_fullscreen_map")
			_dispatch_escape()
			var map_surface := _runtime_surface("FullscreenMapOverlay")
			result = {"observed": map_surface != null, "resolved_action": "close_fullscreen_map" if map_surface != null and not map_surface.visible and not _menu_visible() else "unexpected_map_back_route"}
		"menu_root_escape_behavior":
			_reset_navigation_surfaces()
			_main.call("_open_main_menu")
			_dispatch_escape()
			result = {"observed": true, "resolved_action": "close_root_menu" if not _menu_visible() else "root_menu_remains"}
		"exit_requires_confirmation":
			result = _source_observation(["\"quit\":", "_quit_game()", "func _quit_game()", "get_tree().quit()"], "quit_immediately")
		"confirm_modal_precedes_menu":
			_reset_navigation_surfaces()
			var layer := _overlay_layer()
			if layer != null and layer.has_method("show_confirm"):
				layer.call("show_confirm", "Navigation characterization confirmation")
				_dispatch_escape()
				var confirm := layer.find_child("ConfirmPanel", true, false) as Control
				result = {"observed": confirm != null, "resolved_action": "open_pause_keep_confirmation" if _menu_visible() and confirm != null and confirm.visible else "confirmation_route_changed"}
		"temporary_decision_not_bypassed":
			_reset_navigation_surfaces()
			var layer := _overlay_layer()
			if layer != null and layer.has_method("show_temporary_decision"):
				layer.call("show_temporary_decision", {"kind": "discard_purchase", "title": "Private discard", "summary": "Choose one card.", "actions": [{"id": "discard_slot_0", "label": "Slot 1"}]})
				_dispatch_escape()
				result = {"observed": _temporary_decision_visible(), "resolved_action": "open_pause_keep_forced_decision" if _menu_visible() and _temporary_decision_visible() else "forced_decision_route_changed"}
		"side_drawer_closes_before_pause":
			_reset_navigation_surfaces()
			var layer := _overlay_layer()
			if layer != null and layer.has_method("show_side_drawer"):
				layer.call("show_side_drawer", {"title": "Public detail", "summary": "Navigation characterization"})
				_dispatch_escape()
				var drawer := layer.find_child("SideDrawerPanel", true, false) as Control
				result = {"observed": drawer != null, "resolved_action": "open_pause_keep_side_drawer" if _menu_visible() and drawer != null and drawer.visible else "side_drawer_route_changed"}
		"card_detail_closes_before_parent":
			result = _source_observation(["func _back_from_catalog_menu(", "card_codex_show_detail = false", "_update_card_codex_menu()"], "close_codex_detail")
		"district_supply_drawer_closes_before_pause":
			_reset_navigation_surfaces()
			var drawer := _runtime_surface("DistrictSupplySideDrawerOverlay")
			if drawer != null:
				drawer.visible = true
				_dispatch_escape()
				result = {"observed": true, "resolved_action": "open_pause_keep_district_supply" if _menu_visible() and drawer.visible else "district_supply_route_changed"}
		"nested_codex_detail_returns_atlas":
			result = _source_observation(["card_codex_show_detail = false", "bestiary_show_detail = false", "product_codex_show_detail = false"], "close_codex_detail")
		"codex_atlas_returns_compendium":
			result = _source_observation(["\"compendium\":", "_open_compendium_menu()"], "open_compendium")
		"codex_from_intel_returns_intel":
			result = _source_observation(["\"intel\":", "_open_intel_dossier_menu()"], "open_intel_dossier")
		"codex_from_economy_returns_economy":
			result = _source_observation(["\"economy\":", "_open_economy_overview_menu()"], "open_economy_overview")
		"codex_from_standings_returns_standings":
			result = _source_observation(["\"standings\":", "_open_standings_menu()"], "open_standings")
		"codex_from_game_returns_game":
			result = _source_observation(["\"game\":", "_close_menu()"], "close_menu_resume_game")
		"campaign_briefing_back":
			result = _source_observation(["{\"id\": \"campaign_menu\", \"label\": \"返回战役\"}", "elif action_id == \"campaign_menu\":", "_open_campaign_menu()"], "open_campaign_menu")
		"campaign_settings_back":
			result = _source_observation(["\"campaign_settings_back\"", "_open_campaign_menu()"], "open_campaign_menu")
		"campaign_reward_recap_back":
			result = _source_observation(["{\"id\": \"campaign_reward\", \"label\": \"返回奖励\"}", "{\"id\": \"campaign_menu\", \"label\": \"战役地图\"}"], "open_reward_or_campaign_menu")
		"scenario_settings_back":
			result = _source_observation(["\"scenario_settings_back\"", "_open_scenario_browser_menu()"], "open_scenario_browser")
		"scenario_log_replay_back":
			result = _source_observation(["func _open_scenario_action_log_menu(", "func _open_scenario_replay_menu(", "\"main_menu_requested\": Callable(self, \"_open_main_menu\")"], "open_main_menu")
		"new_game_setup_back":
			result = _source_observation(["func _open_new_game_setup_menu(", "\"main_menu_requested\": Callable(self, \"_open_main_menu\")"], "open_main_menu")
		"focus_restores_to_opener":
			result = {"observed": not _main_source.contains("focus_restore_path") and not _main_source.contains("gui_get_focus_owner"), "resolved_action": "focus_untracked", "focus_before": "opener_button", "focus_after": "untracked"}
		"freed_focus_uses_safe_fallback":
			result = {"observed": not _main_source.contains("focus_first_enabled_parent") and not _main_source.contains("focus_restore_path"), "resolved_action": "no_global_focus_fallback", "focus_before": "freed_opener", "focus_after": "untracked"}
		"keyboard_controller_pointer_parity":
			var input_source := _main_input_source()
			result = {"observed": input_source.contains("InputEventKey") and input_source.contains("KEY_ESCAPE") and not input_source.contains("ui_cancel"), "resolved_action": "key_escape_only"}
		"repeat_escape_debounced":
			_reset_navigation_surfaces()
			_dispatch_escape(true)
			result = {"observed": not _menu_visible(), "resolved_action": "ignore_echo" if not _menu_visible() else "echo_routed"}
		"no_direct_quit_from_match":
			var input_source := _main_input_source()
			result = {"observed": input_source.contains("_open_pause_menu()") and not input_source.contains("_quit_game") and not input_source.contains("get_tree().quit"), "resolved_action": "open_pause_menu"}
		"save_navigation_legacy_parity":
			var controller := _codex_navigation_controller()
			var snapshot: Variant = controller.call("to_legacy_save_snapshot") if controller != null and controller.has_method("to_legacy_save_snapshot") else {}
			result = {"observed": snapshot is Dictionary and (snapshot as Dictionary).size() == 12 and _is_pure_data(snapshot), "resolved_action": "codex_legacy_keys_roundtrip"}
		"pure_navigation_snapshot":
			var has_global_snapshot := _main.has_method("global_navigation_snapshot") or _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GlobalUiNavigationRuntimeController") != null
			result = {"observed": not has_global_snapshot, "resolved_action": "global_snapshot_missing" if not has_global_snapshot else "pure_global_surface_stack_snapshot"}
		"sprint68_deletion_candidates_complete":
			var candidates: Array = global_navigation_deletion_candidates()
			result = {"observed": candidates.size() == 8 and _is_pure_data(candidates), "resolved_action": "deletion_list_recorded"}
	return result


func _source_observation(tokens: Array, resolved_action: String) -> Dictionary:
	var bundle := _navigation_source_bundle()
	var observed := true
	for token_variant: Variant in tokens:
		observed = observed and bundle.contains(str(token_variant))
	return {"observed": observed, "resolved_action": resolved_action}


func _navigation_source_bundle() -> String:
	var paths := [
		MAIN_SCRIPT_PATH,
		"res://scripts/ui/menu_overlay.gd",
		"res://scripts/ui/overlay_layer.gd",
		"res://scripts/viewmodels/campaign_briefing_snapshot.gd",
		"res://scripts/viewmodels/campaign_reward_snapshot.gd",
		"res://scripts/viewmodels/match_recap_snapshot.gd",
	]
	var parts: Array[String] = []
	for path_variant: Variant in paths:
		parts.append(FileAccess.get_file_as_string(str(path_variant)))
	return "\n".join(parts)


func _main_input_source() -> String:
	var start := _main_source.find("func _unhandled_input(")
	if start < 0:
		return ""
	var finish := _main_source.find("\nfunc ", start + 6)
	return _main_source.substr(start) if finish < 0 else _main_source.substr(start, finish - start)


func _dispatch_escape(echo_event: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	event.echo = echo_event
	_main.call("_unhandled_input", event)


func _reset_navigation_surfaces() -> void:
	if _main == null:
		return
	var layer := _overlay_layer()
	if layer != null:
		if layer.has_method("hide_confirm"):
			layer.call("hide_confirm")
		if layer.has_method("hide_side_drawer"):
			layer.call("hide_side_drawer")
	var full_map := _runtime_surface("FullscreenMapOverlay")
	if full_map != null:
		full_map.visible = false
	var district_supply := _runtime_surface("DistrictSupplySideDrawerOverlay")
	if district_supply != null:
		district_supply.visible = false
	if _menu_visible():
		_main.call("_close_menu")


func _overlay_layer() -> Node:
	return _main.find_child("OverlayLayer", true, false) if _main != null else null


func _runtime_surface(node_name: String) -> Control:
	return _main.find_child(node_name, true, false) as Control if _main != null else null


func _codex_navigation_controller() -> Node:
	return _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CodexNavigationRuntimeController") if _main != null else null


func _menu_visible() -> bool:
	return _overlay != null and _overlay.visible


func _temporary_decision_visible() -> bool:
	var layer := _overlay_layer()
	if layer == null:
		return false
	for node_name in ["TemporaryDecisionModal", "MonsterWagerDecisionPanel", "ContractResponseDecisionPanel", "TemporaryChoiceDecisionPanel"]:
		var panel := layer.find_child(node_name, true, false) as Control
		if panel != null and panel.visible:
			return true
	return false


func _settings_panel() -> Control:
	return _main.find_child("PresentationSettingsPanel", true, false) as Control if _main != null else null


func _pause_actions_panel() -> Control:
	return _main.find_child("ScenarioPauseActionsPanel", true, false) as Control if _main != null else null


func _overlay_title() -> String:
	var snapshot: Dictionary = _overlay.call("debug_snapshot") as Dictionary if _overlay != null else {}
	return str(snapshot.get("title", ""))


func _snapshot_action_ids(snapshot: Dictionary) -> Array:
	var action_ids: Array = []
	for entry_variant: Variant in snapshot.get("rendered_actions", []):
		if entry_variant is Dictionary:
			action_ids.append(str((entry_variant as Dictionary).get("id", "")))
	return action_ids


func _static_buttons_exist(panel: Control, node_names: Array) -> bool:
	if panel == null:
		return false
	for node_name_variant: Variant in node_names:
		if not (panel.find_child(str(node_name_variant), true, false) is Button):
			return false
	return true


func _rendered_action_disabled(quick_snapshot: Dictionary, action_id: String) -> bool:
	for entry_variant: Variant in quick_snapshot.get("rendered", []):
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("id", "")) == action_id:
			return bool((entry_variant as Dictionary).get("disabled", false))
	return false


func _record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var record := {
		"case_id": case_id,
		"main_checked": false,
		"scene_checked": false,
		"deletion_checked": false,
		"interaction_checked": false,
		"bridge_checked": false,
		"layout_checked": false,
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


func _global_observed_count() -> int:
	var count := 0
	for record_variant: Variant in _global_navigation_records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("observed", false)):
			count += 1
	return count


func _global_aligned_count() -> int:
	var count := 0
	for record_variant: Variant in _global_navigation_records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("contract_aligned", false)):
			count += 1
	return count


func _update_ui(manifest: Dictionary, global_manifest: Dictionary) -> void:
	var passed := int(manifest.get("passed_count", 0))
	var total := int(manifest.get("record_count", 0))
	status_label.text = "PASS" if passed == total else "FAIL"
	status_label.modulate = Color("#4ade80") if passed == total else Color("#fb7185")
	summary_label.text = "%d/%d cutover | global %d/%d observed | %d/%d aligned" % [passed, total, int(global_manifest.get("observed_count", 0)), int(global_manifest.get("record_count", 0)), int(global_manifest.get("aligned_count", 0)), int(global_manifest.get("record_count", 0))]
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	ownership_text.text = "[b]Scene-owned menu presentation[/b]\nMenuOverlay and MenuQuickNavigation own the shell; PresentationSettingsPanel and ScenarioPauseActionsPanel own settings and pause commands.\n\n[b]Sprint 67 finding[/b]\nGlobal Back/focus ownership is still split. Characterization records behavior without adding a parallel runtime controller.\n\n[b]Current main metrics[/b]\n%s nonblank lines · %s functions · %s vars · %s constants" % [str(metrics.get("nonblank_lines", 0)), str(metrics.get("function_count", 0)), str(metrics.get("top_level_variable_count", 0)), str(metrics.get("constant_count", 0))]
	var lines: Array[String] = []
	for record_variant: Variant in _records:
		var record := record_variant as Dictionary
		var result := "PASS" if bool(record.get("passed", false)) else "FAIL"
		lines.append("[color=%s][b]%s[/b][/color]  %s\n%s" % ["#4ade80" if result == "PASS" else "#fb7185", result, str(record.get("case_id", "")), str(record.get("notes", ""))])
	lines.append("[color=#38bdf8][b]GLOBAL NAVIGATION CHARACTERIZATION[/b][/color]")
	for record_variant: Variant in _global_navigation_records:
		var record := record_variant as Dictionary
		var result := "ALIGNED" if bool(record.get("contract_aligned", false)) else "GAP"
		lines.append("[color=%s][b]%s[/b][/color]  %s\n%s -> %s" % ["#4ade80" if result == "ALIGNED" else "#facc15", result, str(record.get("case_id", "")), str(record.get("resolved_action", "")), str(record.get("expected_action", ""))])
	results_text.text = "\n\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var metrics := manifest.get("main_metrics", {}) as Dictionary
	var lines := ["# Menu Presentation Runtime Cutover", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Main nonblank lines: %d" % int(metrics.get("nonblank_lines", 0)), "", "| Case | Result | Notes |", "| --- | --- | --- |"]
	for record_variant: Variant in manifest.get("records", []):
		var record := record_variant as Dictionary
		lines.append("| %s | %s | %s |" % [str(record.get("case_id", "")), "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines) + "\n"


func _global_navigation_markdown_report(manifest: Dictionary) -> String:
	var lines := [
		"# Global UI Navigation Characterization Sprint 67",
		"",
		"- Observed: %d/%d" % [int(manifest.get("observed_count", 0)), int(manifest.get("record_count", 0))],
		"- Contract aligned: %d/%d" % [int(manifest.get("aligned_count", 0)), int(manifest.get("record_count", 0))],
		"- Production main.gd modified: no",
		"",
		"## Surface Registry",
		"",
		"| Surface | Kind | Parent | Dismiss policy |",
		"| --- | --- | --- | --- |",
	]
	for surface_variant: Variant in manifest.get("surface_registry", []):
		var surface := surface_variant as Dictionary
		lines.append("| %s | %s | %s | %s |" % [str(surface.get("surface_id", "")), str(surface.get("surface_kind", "")), str(surface.get("parent_surface_id", "")), str(surface.get("dismiss_policy", ""))])
	lines.append_array(["", "## Cases", "", "| Case | Observed | Current | Expected | Aligned | Risk |", "| --- | --- | --- | --- | --- | --- |"])
	for record_variant: Variant in manifest.get("records", []):
		var record := record_variant as Dictionary
		lines.append("| %s | %s | %s | %s | %s | %s |" % [str(record.get("case_id", "")), "yes" if bool(record.get("observed", false)) else "no", str(record.get("resolved_action", "")).replace("|", "/"), str(record.get("expected_action", "")).replace("|", "/"), "yes" if bool(record.get("contract_aligned", false)) else "no", str(record.get("risk", ""))])
	lines.append_array(["", "## Sprint 68 Deletion Candidates", "", "| Symbol | Scope | Replacement |", "| --- | --- | --- |"])
	for candidate_variant: Variant in manifest.get("deletion_candidates", []):
		var candidate := candidate_variant as Dictionary
		lines.append("| %s | %s | %s |" % [str(candidate.get("symbol", "")), str(candidate.get("scope", "")), str(candidate.get("replacement", ""))])
	return "\n".join(lines) + "\n"


func _prepare_output_dir() -> void:
	for output_dir_variant: Variant in [OUTPUT_DIR, GLOBAL_NAVIGATION_OUTPUT_DIR]:
		var absolute_dir := ProjectSettings.globalize_path(str(output_dir_variant))
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
	for screenshot_path_variant: Variant in [SCREENSHOT_PATH, GLOBAL_NAVIGATION_SCREENSHOT_PATH]:
		var absolute_path := ProjectSettings.globalize_path(str(screenshot_path_variant))
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
