extends Control
class_name LegacyPlayerSurfaceRetirementBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const CARD_PRESENTATION_SERVICE_SCENE := "res://scenes/runtime/CardPresentationRuntimeService.tscn"
const TABLE_VIEWMODEL_SERVICE_SCENE := "res://scenes/runtime/GameTableViewModelRuntimeService.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/legacy_player_surface_retirement/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/card_presentation_viewmodel_hard_cutover_sprint_42.png"

const RETIRED_FUNCTION_NAMES := [
	"_dismiss_opening_guide", "_add_opening_guide_task_card", "_add_opening_guide_step_chip", "_add_opening_guide_next_step_card", "_add_opening_guide_timeline", "_add_opening_guide_panel",
	"_monster_wager_side_stake", "_add_selected_card_resolution_guess_panel", "_district_context_goods_text", "_selected_district_tile_icon", "_selected_district_focus_text", "_selected_district_plate_accent",
	"_add_selected_district_tile_plate", "_add_selected_district_chip_rail", "_add_selected_district_action_lamp", "_add_selected_district_action_lamp_rail", "_make_selected_district_action_button", "_add_selected_district_action_grid", "_add_selected_district_action_panel",
	"_player_public_role_name", "_player_seat_button_text", "_player_seat_button_tooltip", "_inspected_player_index", "_inspect_player_public_profile", "_clear_player_public_inspection", "_player_seat_public_chip_entries",
	"_add_player_seat_public_chip", "_add_player_seat_card", "_add_player_seat_inspector", "_add_player_seat_strip", "_add_player_hand_rack_chip", "_player_resource_cube_entries", "_add_player_resource_cube", "_add_player_resource_cube_rail",
	"_player_hand_rack_overall_state_text", "_add_player_hand_rack", "_action_tray_module_entries", "_add_action_tray_module_chip", "_add_action_tray_module_rail", "_main_action_dock_entries", "_add_main_action_dock_button",
	"_action_dock_readiness_entries", "_player_table_state_lamp_entries", "_add_player_table_state_lamp", "_add_player_table_state_lamp_rail", "_add_action_dock_readiness_chip", "_add_action_dock_readiness_rail", "_add_main_action_dock",
	"_add_player_dashboard_action_button", "_dashboard_primary_action_data", "_add_player_dashboard_primary_action_strip", "_add_player_dashboard_action_dock", "_player_dashboard_district_summary_text", "_add_player_dashboard_district_summary", "_add_player_action_tray",
	"_add_bid_control_chip", "_add_bid_control_card", "_respond_to_active_contract", "_respond_to_pending_contract", "_add_empty_card_slot", "_add_role_card_face", "_add_first_summon_prompt", "_first_summon_chip_entries",
	"_first_summon_drop_zone_short_text", "_first_summon_drop_zone_text", "_first_summon_prompt_text", "_role_card_art_stats", "_role_card_tooltip", "_player_private_status_text", "_player_tableau_chip_entries", "_player_tableau_visibility_text",
	"_add_player_identity_mini_card", "_add_player_tableau_chip", "_player_tableau_goal_meter_data", "_add_player_tableau_progress_chip", "_add_player_tableau_progress_rail", "_add_player_tableau_goal_meter", "_add_player_tableau_strip",
	"_connect_hand_card_hover", "_set_hand_card_hover", "_animate_hand_card_hover", "_finish_hand_card_hover_reset",
	"_goal_hint_body", "_goal_hint_accent", "_goal_hint_chip_entries", "_table_goal_condition_chip", "_table_goal_condition_entries", "_add_table_goal_prompt",
	"_hand_card_state_chip_entries", "_add_hand_card_play_state_rail", "_add_hand_card_play_lamp", "_add_card_face_chip_rail", "_add_card_face",
	"_add_action_button", "_add_selected_district_card_list", "_add_district_card_button",
	"_runtime_right_inspector_snapshot_source", "_runtime_selected_card_track_entry_snapshot", "_runtime_selected_hand_card_snapshot", "_runtime_hand_card_inspector_snapshot_source", "_runtime_card_track_inspector_snapshot_source", "_runtime_card_fact_label",
	"_runtime_card_track_snapshot_source", "_runtime_card_resolution_track_snapshot_source", "_runtime_card_resolution_track_phase_text", "_runtime_card_resolution_track_summary_text", "_runtime_card_resolution_track_response_text", "_runtime_card_resolution_track_pending_decision", "_runtime_real_card_track_entry_count",
	"_runtime_scenario_demo_card_track_entry", "_runtime_card_track_event_snapshots", "_runtime_card_track_entry_snapshot", "_runtime_card_track_kind", "_runtime_hand_card_snapshots", "_runtime_hand_card_drop_label",
	"_card_category_icon", "_card_route_icon", "_card_icon_for_card", "_card_icon_type_label", "_card_icon_route_label", "_card_icon_legend_text", "_card_codex_category_for_card", "_card_primary_type_label", "_card_subtype_label", "_card_type_line",
	"_hand_card_action_text", "_hand_card_state_primary_text", "_card_face_chip_entries", "_card_face_route_text", "_card_theme_color", "_card_rules_text", "_card_face_quick_effect_text", "_card_strategy_route_label", "_card_use_case_text_for_skill", "_card_strategy_use_text", "_card_strategy_summary", "_card_key_rule_facts", "_card_art_stats", "_card_rule_facts", "_card_detail_tooltip",
	"_card_resolution_track_slot_index_text", "_card_resolution_track_state_number", "_card_resolution_track_entry_tooltip", "_card_resolution_track_badge_texts", "_card_resolution_track_visible_badge_texts", "_card_resolution_track_compact_badge_text", "_card_resolution_track_visual_badges", "_card_resolution_track_badge_color", "_card_resolution_overlay_badge_texts", "_card_resolution_contract_badge_text", "_card_resolution_requirement_badge_text",
	"_card_resolution_animation_catalog_text", "_card_resolution_animation_text", "_card_resolution_animation_stages", "_card_resolution_stage_index", "_card_resolution_display_progress", "_card_resolution_stage_label", "_card_resolution_visual_cue_text", "_card_resolution_target_text", "_card_resolution_aftermath_clue_text", "_card_resolution_effect_radius", "_card_resolution_effect_style", "_card_resolution_effect_style_label", "_card_resolution_stage_effect_label",
]

@export var auto_run := true

@onready var status_label: Label = %StatusLabel
@onready var summary_label: Label = %SummaryLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var results_text: RichTextLabel = %ResultsText

var _records: Array = []
var _failures: Array[String] = []
var _main: Control = null
var _main_source := ""
var _runtime_snapshot: Dictionary = {}


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_retirement_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func retired_function_names() -> Array:
	return RETIRED_FUNCTION_NAMES.duplicate()


func retirement_cases() -> Array:
	return [
		"real_main_scene_loads",
		"sceneized_player_board_present",
		"sceneized_hand_rack_present",
		"sceneized_action_dock_present",
		"sceneized_bid_board_present",
		"legacy_player_refresh_absent",
		"legacy_seat_renderer_absent",
		"legacy_hand_renderer_absent",
		"legacy_action_tray_absent",
		"legacy_district_renderer_absent",
		"legacy_first_summon_renderer_absent",
		"legacy_tableau_renderer_absent",
		"legacy_contract_ui_wrapper_absent",
		"runtime_player_snapshot_pure_data",
		"card_selection_bridge_present",
		"action_bridge_present",
		"privacy_boundary_preserved",
		"card_presentation_service_composition",
		"table_viewmodel_service_composition",
		"card_presentation_runtime_source",
		"hand_card_viewmodel_owned_by_service",
		"right_inspector_owned_by_service",
		"public_track_viewmodel_privacy",
		"coordinator_pure_data_routes",
		"presentation_rule_boundary_preserved",
		"legacy_presentation_and_snapshot_owners_absent",
		"retired_function_set_absent",
	]


func build_retirement_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in retirement_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite": "legacy-player-surface-retirement-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"retired_function_count": RETIRED_FUNCTION_NAMES.size(),
		"records": records,
	}


func run_retirement_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	_main_source = FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	await _ensure_main()
	for case_id_variant in retirement_cases():
		var case_id := str(case_id_variant)
		var record := _run_case(case_id)
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "failed"))])
	var manifest := {
		"suite": "legacy-player-surface-retirement-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": _records.size(),
		"passed_count": _passed_count(),
		"retired_function_count": RETIRED_FUNCTION_NAMES.size(),
		"main_metrics": _main_metrics(),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	var audio_players: Array[AudioStreamPlayer] = []
	if _main != null:
		for player_variant in _main.find_children("*", "AudioStreamPlayer", true, false):
			var player := player_variant as AudioStreamPlayer
			if player != null:
				player.stop()
				audio_players.append(player)
		await get_tree().create_timer(0.2).timeout
		for player in audio_players:
			if is_instance_valid(player):
				player.stream = null
				player.free()
		_main.set("table_bgm_player", null)
		_main.set("table_sfx_players", {})
		_main.queue_free()
		_main = null
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("LegacyPlayerSurfaceRetirementBench manifest: %s" % MANIFEST_PATH)
	print("LegacyPlayerSurfaceRetirementBench report: %s" % REPORT_PATH)
	print("LegacyPlayerSurfaceRetirementBench screenshot: %s" % SCREENSHOT_PATH)
	print("LegacyPlayerSurfaceRetirementBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("LegacyPlayerSurfaceRetirementBench failed:\n- %s" % "\n- ".join(_failures))
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
	if _main.has_method("_new_game"):
		_main.set("configured_player_count", 4)
		_main.set("configured_ai_player_count", 3)
		_main.call("_new_game")
		await get_tree().process_frame
	if _main.has_method("_runtime_table_snapshot"):
		var snapshot_variant: Variant = _main.call("_runtime_table_snapshot")
		_runtime_snapshot = snapshot_variant if snapshot_variant is Dictionary else {}


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	var screen := _main.get_node_or_null("RuntimeGameScreen") as Control if _main != null else null
	var player_board := screen.find_child("PlayerBoard", true, false) if screen != null else null
	var hand_rack := screen.find_child("HandRack", true, false) if screen != null else null
	var action_dock := screen.find_child("PlayerMainActionDock", true, false) if screen != null else null
	var bid_board := screen.find_child("PublicBidDecisionPanel", true, false) if screen != null else null
	var coordinator := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _main != null else null
	var card_presentation_service := coordinator.get_node_or_null("CardPresentationRuntimeService") if coordinator != null else null
	var table_viewmodel_service := coordinator.get_node_or_null("GameTableViewModelRuntimeService") if coordinator != null else null
	match case_id:
		"real_main_scene_loads":
			passed = _main != null and _main.scene_file_path == MAIN_SCENE_PATH
			flags["main_checked"] = true
			notes = "the gate instantiates the real main scene"
		"sceneized_player_board_present":
			passed = player_board != null and player_board.scene_file_path == "res://scenes/ui/PlayerBoard.tscn"
			flags["scene_checked"] = true
			notes = "PlayerBoard is the only player tableau renderer"
		"sceneized_hand_rack_present":
			passed = hand_rack != null and hand_rack.scene_file_path == "res://scenes/ui/HandRack.tscn" and load("res://scenes/ui/CardFace.tscn") is PackedScene
			flags["scene_checked"] = true
			notes = "HandRack and CardFace own card-node synchronization, presentation, hover, selection, and drag input"
		"sceneized_action_dock_present":
			passed = action_dock != null and action_dock.scene_file_path == "res://scenes/ui/ActionDock.tscn"
			flags["scene_checked"] = true
			notes = "ActionDock owns player command rendering"
		"sceneized_bid_board_present":
			passed = bid_board != null and bid_board.scene_file_path == "res://scenes/ui/BidBoard.tscn" and player_board.find_child("PlayerBidBoard", true, false) == null
			flags["scene_checked"] = true
			notes = "BidBoard owns transient public-bid controls under Overlay while PlayerBoard reserves zero permanent space"
		"legacy_player_refresh_absent":
			passed = _tokens_absent(["func _refresh_player_panel", "func _player_panel_structure_signature", "func _refresh_player_panel_live_values", "player_panel_signature", "func _add_table_goal_prompt", "func _table_goal_condition_entries", "func _goal_hint_chip_entries"])
			flags["deletion_checked"] = true
			notes = "the generated player-panel refresh and obsolete table-goal prompt paths are gone"
		"legacy_seat_renderer_absent":
			passed = _tokens_absent(["func _add_player_seat_card", "func _add_player_seat_inspector", "func _add_player_seat_strip", "func _inspect_player_public_profile"])
			flags["deletion_checked"] = true
			notes = "the generated public-seat renderer is gone"
		"legacy_hand_renderer_absent":
			passed = _tokens_absent(["func _add_player_hand_rack", "func _add_empty_card_slot", "func _add_role_card_face", "func _add_card_face(", "func _add_card_face_chip_rail", "func _add_hand_card_play_lamp", "func _add_hand_card_play_state_rail", "func _connect_hand_card_hover", "CardArtViewScript", "HAND_CARD_HOVER_"])
			flags["deletion_checked"] = true
			notes = "the generated hand/card renderer, private hover tween, and direct CardArt preload are gone"
		"legacy_action_tray_absent":
			passed = _tokens_absent(["func _add_player_action_tray", "func _add_main_action_dock", "func _add_bid_control_card", "func _main_action_dock_entries"])
			flags["deletion_checked"] = true
			notes = "the generated command tray and bid card are gone"
		"legacy_district_renderer_absent":
			passed = _tokens_absent(["func _add_selected_district_action_panel", "func _add_selected_district_tile_plate", "func _add_selected_district_action_grid", "func _add_selected_district_card_list", "func _add_district_card_button", "func _add_action_button("])
			passed = passed and load("res://scenes/ui/DistrictSupplyDrawer.tscn") is PackedScene and load("res://scenes/ui/DistrictSupplyMarketCard.tscn") is PackedScene and load("res://scenes/ui/DistrictSupplyPreviewCard.tscn") is PackedScene
			flags["scene_checked"] = true
			flags["deletion_checked"] = true
			notes = "district supply uses Drawer, MarketCard, and PreviewCard scenes; the generated card list is gone"
		"legacy_first_summon_renderer_absent":
			passed = _tokens_absent(["func _add_first_summon_prompt", "func _first_summon_chip_entries", "func _first_summon_prompt_text"])
			flags["deletion_checked"] = true
			notes = "first-summon feedback renders through the current action/coach surfaces"
		"legacy_tableau_renderer_absent":
			passed = _tokens_absent(["func _add_player_tableau_strip", "func _add_player_identity_mini_card", "func _add_player_tableau_goal_meter"])
			flags["deletion_checked"] = true
			notes = "the old generated resource tableau is gone"
		"legacy_contract_ui_wrapper_absent":
			passed = _tokens_absent(["func _respond_to_active_contract", "func _respond_to_pending_contract("])
			flags["deletion_checked"] = true
			notes = "contract UI uses the player-aware action bridge without obsolete wrappers"
		"runtime_player_snapshot_pure_data":
			passed = not _runtime_snapshot.is_empty() and _is_pure_data(_runtime_snapshot)
			flags["snapshot_checked"] = true
			flags["pure_data_checked"] = true
			notes = "sceneized player state crosses the boundary as data only"
		"card_selection_bridge_present":
			passed = _main != null and _main.has_method("_on_runtime_game_screen_card_selected") and _main_source.contains("func _runtime_hand_card_fact_sources") and not _main_source.contains("func _runtime_hand_card_snapshots")
			flags["bridge_checked"] = true
			notes = "card selection still enters the existing runtime action adapter while hand ViewModels are service-owned"
		"action_bridge_present":
			passed = _main != null and _main.has_method("_on_runtime_game_screen_action_requested") and _main_source.contains("func _activate_runtime_quick_action")
			flags["bridge_checked"] = true
			notes = "scene-owned buttons preserve existing action ids and handlers"
		"privacy_boundary_preserved":
			passed = _is_pure_data(_runtime_snapshot) and not _contains_forbidden_key(_runtime_snapshot)
			flags["privacy_checked"] = true
			flags["pure_data_checked"] = true
			notes = "the player snapshot contains no hidden-owner or private-hand keys"
		"card_presentation_service_composition":
			var debug: Dictionary = card_presentation_service.call("debug_snapshot") if card_presentation_service != null and card_presentation_service.has_method("debug_snapshot") else {}
			passed = card_presentation_service != null and card_presentation_service.scene_file_path == CARD_PRESENTATION_SERVICE_SCENE and card_presentation_service.has_method("compose_card") and card_presentation_service.has_method("compose_hand_card") and card_presentation_service.has_method("compose_resolution") and bool(debug.get("service_authoritative", false)) and bool(debug.get("owns_resolution_presentation", false))
			flags["scene_checked"] = true
			flags["service_checked"] = true
			notes = "CardPresentationRuntimeService is the editable card color/icon/route/copy owner"
		"table_viewmodel_service_composition":
			var debug: Dictionary = table_viewmodel_service.call("debug_snapshot") if table_viewmodel_service != null and table_viewmodel_service.has_method("debug_snapshot") else {}
			passed = table_viewmodel_service != null and table_viewmodel_service.scene_file_path == TABLE_VIEWMODEL_SERVICE_SCENE and table_viewmodel_service.has_method("compose_table") and table_viewmodel_service.has_method("compose_card_surfaces") and table_viewmodel_service.has_method("compose_resolution_overlay_badges") and bool(debug.get("service_authoritative", false)) and bool(debug.get("owns_resolution_overlay_badges", false))
			flags["scene_checked"] = true
			flags["service_checked"] = true
			notes = "GameTableViewModelRuntimeService owns TableSnapshot, hand, track, and inspector assembly"
		"card_presentation_runtime_source":
			var diagnostics: Node = coordinator.gameplay_balance_diagnostics_service() if coordinator is GameRuntimeCoordinator else null
			var one_glance: Dictionary = diagnostics.card_one_glance_source("城市融资1") if diagnostics != null else {}
			passed = str(one_glance.get("use_case", "")) == "加城市GDP" and str(one_glance.get("route", "")) == "城市成长" and str(one_glance.get("quick_effect", "")).begins_with("加城市GDP｜") and _is_pure_data(one_glance)
			flags["service_checked"] = true
			flags["pure_data_checked"] = true
			notes = "real card facts route through the authoritative presentation service"
		"hand_card_viewmodel_owned_by_service":
			var runtime_player_board := _runtime_snapshot.get("player_board", {}) as Dictionary
			var hand_cards := runtime_player_board.get("hand_cards", []) as Array
			var first_card := hand_cards[0] as Dictionary if not hand_cards.is_empty() and hand_cards[0] is Dictionary else {}
			passed = not first_card.is_empty() and first_card.has("use_case") and first_card.has("play_state") and first_card.has("drop_label") and not _main_source.contains("func _runtime_hand_card_snapshots(")
			flags["snapshot_checked"] = true
			flags["deletion_checked"] = true
			notes = "hand-card presentation is composed outside main.gd while action ids remain play_<slot>"
		"right_inspector_owned_by_service":
			var inspector := _runtime_snapshot.get("right_inspector", {}) as Dictionary
			var deep_links := inspector.get("deep_links", []) as Array
			passed = not inspector.is_empty() and _action_has_id(deep_links, "detail_region") and _action_has_id(deep_links, "detail_cards") and not _main_source.contains("func _runtime_right_inspector_snapshot_source(")
			flags["snapshot_checked"] = true
			flags["deletion_checked"] = true
			notes = "RightInspector assembly and selected-card precedence belong to the ViewModel service"
		"public_track_viewmodel_privacy":
			var track := _runtime_snapshot.get("card_track", []) as Array
			var encoded := JSON.stringify(track)
			passed = _is_pure_data(track) and not encoded.contains("player_index") and not encoded.contains("hidden_owner") and not encoded.contains("private_target") and not _main_source.contains("func _runtime_card_track_entry_snapshot(")
			flags["privacy_checked"] = true
			flags["pure_data_checked"] = true
			flags["deletion_checked"] = true
			notes = "public track ViewModels strip private owners and targets after consuming domain facts"
		"coordinator_pure_data_routes":
			var skill: Dictionary = coordinator.call("card_definition", "城市融资1") if coordinator != null else {}
			var source: Dictionary = _main.call("_card_presentation_source", "城市融资1", skill, 0, -1) if _main != null and _main.has_method("_card_presentation_source") else {}
			var presentation: Dictionary = coordinator.call("compose_card_presentation", source) if coordinator != null and coordinator.has_method("compose_card_presentation") else {}
			var resolution_source: Dictionary = _main.call("_card_resolution_presentation_source", skill, {"selected_district": 0}, 1.0, true) if _main != null and _main.has_method("_card_resolution_presentation_source") else {}
			var resolution: Dictionary = coordinator.call("compose_card_resolution_presentation", resolution_source) if coordinator != null and coordinator.has_method("compose_card_resolution_presentation") else {}
			passed = _is_pure_data(source) and _is_pure_data(presentation) and _is_pure_data(resolution_source) and _is_pure_data(resolution) and str(presentation.get("use_case", "")) == "加城市GDP" and str(resolution.get("animation_text", "")) != ""
			flags["service_checked"] = true
			flags["pure_data_checked"] = true
			notes = "coordinator exposes data-only presentation routes without Node or Callable payloads"
		"presentation_rule_boundary_preserved":
			var card_debug: Dictionary = card_presentation_service.call("debug_snapshot") if card_presentation_service != null else {}
			var table_debug: Dictionary = table_viewmodel_service.call("debug_snapshot") if table_viewmodel_service != null else {}
			var eligibility_service := coordinator.get_node_or_null("CardPlayEligibilityRuntimeService") if coordinator != null else null
			var eligibility_debug: Dictionary = eligibility_service.call("debug_snapshot") if eligibility_service != null and eligibility_service.has_method("debug_snapshot") else {}
			passed = _main != null and not _main.has_method("_hand_card_play_state") and not _main.has_method("_skill_play_requirement_status") and _main.has_method("_card_price") and bool(eligibility_debug.get("service_authoritative", false)) and not bool(card_debug.get("calculates_card_price", true)) and not bool(card_debug.get("calculates_play_legality", true)) and not bool(table_debug.get("calculates_play_legality", true))
			flags["rule_boundary_checked"] = true
			notes = "CardPlayEligibilityRuntimeService owns legality while price, effects, and mutations retain their existing owners"
		"legacy_presentation_and_snapshot_owners_absent":
			passed = not _main_source.contains("TableSnapshotScript") and not _main_source.contains("func _card_theme_color(") and not _main_source.contains("func _card_use_case_text_for_skill(") and not _main_source.contains("func _card_rule_facts(") and not _main_source.contains("func _runtime_card_track_snapshot_source(") and not _main_source.contains("func _runtime_right_inspector_snapshot_source(") and not _main_source.contains("func _card_resolution_animation_text(") and not _main_source.contains("func _card_resolution_effect_style(")
			flags["deletion_checked"] = true
			notes = "main.gd no longer owns parallel card presentation, TableSnapshot, track, hand, or inspector algorithms"
		"retired_function_set_absent":
			passed = RETIRED_FUNCTION_NAMES.size() == 164
			for function_name_variant in RETIRED_FUNCTION_NAMES:
				passed = passed and not _main_source.contains("func %s(" % str(function_name_variant))
			flags["deletion_checked"] = true
			notes = "all 164 call-graph-closed legacy player/card presentation helpers remain deleted"
	return _record(case_id, passed, notes, flags)


func _tokens_absent(tokens: Array) -> bool:
	for token_variant in tokens:
		if _main_source.contains(str(token_variant)):
			return false
	return true


func _action_has_id(actions: Array, action_id: String) -> bool:
	for action_variant in actions:
		if action_variant is Dictionary and str((action_variant as Dictionary).get("id", "")) == action_id:
			return true
	return false


func _record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var record := {
		"case_id": case_id,
		"main_checked": false,
		"scene_checked": false,
		"deletion_checked": false,
		"snapshot_checked": false,
		"bridge_checked": false,
		"service_checked": false,
		"rule_boundary_checked": false,
		"privacy_checked": false,
		"pure_data_checked": false,
		"retired_function_count": RETIRED_FUNCTION_NAMES.size(),
		"passed": passed,
		"notes": notes,
	}
	for key_variant in flags.keys():
		record[key_variant] = flags[key_variant]
	return record


func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in value.keys():
			var key := str(key_variant)
			if key in ["hidden_owner", "owner_player_index", "private_hand", "private_discard"]:
				return true
			if _contains_forbidden_key(value[key_variant]):
				return true
	elif value is Array:
		for item in value:
			if _contains_forbidden_key(item):
				return true
	return false


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
	return true


func _main_metrics() -> Dictionary:
	var physical_lines := _main_source.split("\n").size()
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
	return {"physical_lines": physical_lines, "nonblank_lines": nonblank_lines, "function_count": function_count, "top_level_variable_count": variable_count, "constant_count": constant_count}


func _passed_count() -> int:
	var count := 0
	for record_variant in _records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		if bool(record.get("passed", false)):
			count += 1
	return count


func _update_ui(manifest: Dictionary) -> void:
	var passed := int(manifest.get("passed_count", 0))
	var total := int(manifest.get("record_count", 0))
	status_label.text = "PASS" if passed == total else "FAIL"
	status_label.modulate = Color("#4ade80") if passed == total else Color("#fb7185")
	summary_label.text = "%d/%d retirement cases passed" % [passed, total]
	var metrics: Dictionary = manifest.get("main_metrics", {}) if manifest.get("main_metrics", {}) is Dictionary else {}
	ownership_text.text = "[b]Scene-owned card presentation[/b]\nCardPresentationRuntimeService owns colors, icons, routes, use cases, card copy, chips, hand-card ViewModels, and resolution cinematic presentation. GameTableViewModelRuntimeService owns hand, track, resolution-overlay badges, RightInspector, and TableSnapshot assembly. main.gd supplies domain facts and receives existing action ids.\n\n[b]Retired closure[/b]\n164 generated player/card presentation and snapshot helpers are deleted.\n\n[b]Current main metrics[/b]\n%s nonblank lines · %s functions · %s vars · %s constants" % [str(metrics.get("nonblank_lines", 0)), str(metrics.get("function_count", 0)), str(metrics.get("top_level_variable_count", 0)), str(metrics.get("constant_count", 0))]
	var lines: Array[String] = []
	for record_variant in _records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		var result := "PASS" if bool(record.get("passed", false)) else "FAIL"
		lines.append("[color=%s][b]%s[/b][/color]  %s\n%s" % ["#4ade80" if result == "PASS" else "#fb7185", result, str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)


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


func _markdown_report(manifest: Dictionary) -> String:
	var metrics: Dictionary = manifest.get("main_metrics", {}) if manifest.get("main_metrics", {}) is Dictionary else {}
	var lines := ["# Card Presentation / ViewModel Hard Cutover", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Retired functions: %d" % int(manifest.get("retired_function_count", 0)), "- Main nonblank lines: %d" % int(metrics.get("nonblank_lines", 0)), "", "| Case | Result | Notes |", "| --- | --- | --- |"]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | %s |" % [str(record.get("case_id", "")), "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines) + "\n"


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
