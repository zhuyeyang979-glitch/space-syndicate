extends Control
class_name FirstMissionRuntimeMainBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const CARD_AUTHORING_SERVICE_SCRIPT := preload("res://scripts/cards/card_runtime_authoring_service.gd")
const OUTPUT_DIR := "user://space_syndicate_design_qa/first_mission_runtime_main/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/first_playable_balance_pacing_sprint_61.png"
const VIEWPORT_SIZE := Vector2i(1600, 960)
const PRIVATE_TOKENS := ["hidden_owner", "private_owner", "private_target", "private_discard", "owner_secret", "secret_owner"]
const CORE_CITY_ECONOMY_KINDS := ["city_revenue_boost", "cash_gain", "region_economy_shift"]
const CORE_PRODUCT_ROUTE_KINDS := ["city_product_shift", "city_product_upgrade", "city_demand_shift", "route_flow_boon", "product_contract_boon"]
const CORE_MONSTER_KINDS := ["monster_lure"]
const CORE_INTEL_COUNTER_KINDS := ["intel_city_reveal", "intel_card_trace", "card_counter"]
const CORE_RECOVERY_KINDS := ["route_insurance", "market_stabilize"]
const PACING_CASE_MILESTONES := {
	"first_development_card_timing": "first_development_card",
	"first_positive_income_timing": "first_positive_income",
	"second_card_timing": "second_card",
	"first_public_clue_timing": "first_public_clue",
	"first_monster_pressure_timing": "first_monster_pressure",
}

@export var auto_run_on_ready := true
@export var quit_when_complete := true
@export_range(0.0, 20.0, 0.5) var quit_delay_seconds := 8.0

@onready var status_label: Label = %FirstMissionRuntimeMainStatusLabel
@onready var summary_label: Label = %FirstMissionRuntimeMainSummaryLabel
@onready var preview_viewport: SubViewport = %FirstMissionRuntimeMainPreviewViewport

var _failures: Array[String] = []
var _emitted_action_ids: Array[String] = []
var _track_action_ids: Array[String] = []
var _connected_screen: Node = null
var _connected_track: Node = null
var _followup_prepositioned_observed := false


func _ready() -> void:
	if preview_viewport != null:
		preview_viewport.size = VIEWPORT_SIZE
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		preview_viewport.gui_disable_input = false
	if auto_run_on_ready:
		call_deferred("_run_flow_suite_and_maybe_quit")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func flow_cases() -> Array:
	return [
		_case("start_first_mission", "start_first_mission", "start_first_mission", "Start authored first_table content from the real main scene and recommended first-run entry."),
		_case("select_recommended_district", "coach_action", "coach_select_district", "Select the recommended first district through the GameScreen action signal."),
		_case("summon_starter_monster", "coach_action", "coach_first_summon", "Summon the real configured Rank I starter monster through existing card rules."),
		_case("open_real_district_supply", "coach_action", "coach_open_rack", "Open a district supply unlocked by the real monster adjacency rules."),
		_case("land_rack_guarantees_city_development", "rack_guarantee", "", "Verify every live land rack keeps one real city_development card from the Inspector resource pack."),
		_case("buy_city_development_card", "coach_action", "coach_buy_card", "Buy the real local-product city development card through existing purchase rules."),
		_case("inspect_and_play_city_development", "coach_action", "coach_play_card", "Inspect and submit the development card through the real anonymous resolution track."),
		_case("observe_first_public_facility", "facility_resolution", "", "Resolve the purchased economic card into a real public facility."),
		_case("receive_first_positive_gdp_or_cash_tick", "positive_income", "coach_check_economy", "Settle project-share realtime cashflow and inspect the real economy overview."),
		_case("buy_followup_business_card", "coach_action", "coach_buy_followup_card", "Buy the real 城市融资1 follow-up after the first project exists."),
		_case("play_followup_business_card", "coach_action", "coach_play_followup_card", "Submit the follow-up business card through the existing action and signal flow."),
		_case("observe_public_resolution_track", "coach_action", "coach_inspect_track", "Read the real public CardResolutionTrack without exposing its hidden owner or project shares."),
		_case("observe_ai_public_action", "ai_public_action", "coach_observe_ai_public_action", "Let the existing AI perform a legal public economy action while keeping policy details private."),
		_case("read_public_clue_without_owner_leak", "public_clue", "coach_inspect_clues", "Open the real intel surface and read public evidence without owner leakage."),
		_case("monster_pressure_visible", "monster_pressure", "coach_inspect_monster_pressure", "Advance the existing monster action loop and inspect sceneized map pressure."),
		_case("mission_completion_feedback", "mission_completion", "coach_choose_route_growth", "Choose a follow-up route and verify the authored mission summary without ending the whole match."),
		_case("core_set_ids_exist", "core_content_gate", "", "Verify first_table references one authoritative 20-card Rank I core set from the runtime catalog."),
		_case("core_set_resources_validate", "core_content_gate", "", "Validate every featured Family/Rank Resource with the existing authoring validator."),
		_case("rank_i_entry_cards_available", "core_content_gate", "", "Verify all core entry cards are real Rank I public-pool cards."),
		_case("teaching_supply_reachable", "core_content_gate", "", "Verify the dynamic development guarantee and authored follow-up sequence remain reachable through real supply."),
		_case("first_enabled_card_is_clear", "core_content_gate", "", "Find a currently enabled core card and verify its existing eligibility presentation is concise and actionable."),
		_case("disabled_reason_is_actionable", "core_content_gate", "", "Verify a core counter card remains visible with a stable, useful disabled reason outside its response window."),
		_case("economy_route_payoff_visible", "core_content_gate", "", "Connect the core economy/route family set to the real positive GDP or cashflow feedback."),
		_case("monster_response_card_visible", "core_content_gate", "", "Verify a real core monster-response card and live sceneized monster pressure are both visible."),
		_case("public_clue_privacy_preserved", "core_content_gate", "", "Verify core intel cards support public clues without exposing owner or private target data."),
		_case("ai_can_use_core_set_without_private_leak", "core_content_gate", "", "Verify an AI player can legally evaluate and rank a core-set action without publishing its private plan."),
		_case("pacing_profile_15_to_30_minutes", "pacing_gate", "", "Verify first_table authors one 15-30 minute pacing window without changing realtime rules."),
		_case("milestone_telemetry_records_real_game_time", "pacing_gate", "", "Verify the real ScenarioRuntimeController records ordered scenario-game-time timestamps."),
		_case("first_development_card_timing", "pacing_gate", "", "Measure when the first real development card is purchased."),
		_case("first_positive_income_timing", "pacing_gate", "", "Measure when positive GDP or cashflow is first confirmed."),
		_case("second_card_timing", "pacing_gate", "", "Measure when the authored second card is purchased."),
		_case("first_public_clue_timing", "pacing_gate", "", "Measure when the first public clue is read without owner leakage."),
		_case("first_monster_pressure_timing", "pacing_gate", "", "Measure when live monster pressure is first observed."),
		_case("mission_completion_budget", "pacing_gate", "", "Verify all measured milestones stay under their warning budgets and the mission keeps a 30-minute ceiling."),
		_case("local_product_development_supply_stable", "pacing_gate", "", "Verify a local-product development card remains recognized outside the preferred product list."),
		_case("followup_supply_prepositioned", "pacing_gate", "", "Verify the second card was present in the real project district rack before the Coach purchase action."),
		_case("privacy_boundary_runtime", "privacy", "", "Ensure visible runtime UI and manifest records do not expose private owner/target/discard tokens."),
	]


func build_flow_manifest_preview() -> Dictionary:
	var records: Array = []
	for flow_case_variant in flow_cases():
		var flow_case: Dictionary = flow_case_variant if flow_case_variant is Dictionary else {}
		records.append(_preview_record(flow_case))
	return {
		"version": "first-playable-balance-pacing-v1",
		"output_dir": OUTPUT_DIR,
		"main_scene": MAIN_SCENE_PATH,
		"screenshot_path": SCREENSHOT_PATH,
		"authored_content": {},
		"pacing_profile": {},
		"pacing_evaluation": {},
		"case_count": records.size(),
		"records": records,
	}


func run_flow_suite() -> void:
	await _run_flow_suite_internal()


func _run_flow_suite_and_maybe_quit() -> void:
	var exit_code := await _run_flow_suite_internal()
	if quit_when_complete and get_tree() != null:
		if quit_delay_seconds > 0.0:
			await get_tree().create_timer(quit_delay_seconds).timeout
		get_tree().quit(exit_code)


func _run_flow_suite_internal() -> int:
	_failures.clear()
	_emitted_action_ids.clear()
	_track_action_ids.clear()
	_followup_prepositioned_observed = false
	_set_status("Preparing First Mission Runtime Main bench...")
	if not _prepare_output_dir():
		return _finish_flow_suite([])
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_failures.append("Main scene could not load: %s" % MAIN_SCENE_PATH)
		return _finish_flow_suite([])
	var viewport := _active_viewport()
	_clear_viewport(viewport)
	var main := packed.instantiate() as Control
	if main == null:
		_failures.append("Main scene root was not Control.")
		return _finish_flow_suite([])
	main.name = "FirstMissionRuntimeMain"
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(main)
	_configure_main_for_bench(main)
	await _pump_frames(16)
	var records: Array = []
	for flow_case_variant in flow_cases():
		var flow_case: Dictionary = flow_case_variant if flow_case_variant is Dictionary else {}
		print("FirstMissionRuntimeMainBench case: %s" % str(flow_case.get("case_id", "")))
		var record := await _run_case(main, flow_case)
		records.append(record)
	_save_viewport_screenshot(viewport, SCREENSHOT_PATH)
	var manifest := {
		"version": "first-playable-balance-pacing-v1",
		"output_dir": OUTPUT_DIR,
		"main_scene": MAIN_SCENE_PATH,
		"screenshot_path": SCREENSHOT_PATH,
		"authored_content": _authored_content_snapshot(main),
		"pacing_profile": _pacing_profile(main),
		"pacing_evaluation": _pacing_evaluation(main),
		"measurement_note": "Observed seconds come from the automated real-main QA path; human playtests use the same ScenarioRuntimeController timestamps against the authored 15-30 minute window.",
		"case_count": records.size(),
		"passed_count": _passed_count(records),
		"records": records,
	}
	_write_text_file(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text_file(REPORT_PATH, _build_markdown_report(manifest))
	_connected_screen = null
	_connected_track = null
	if is_instance_valid(main):
		viewport.remove_child(main)
		main.queue_free()
		await _pump_frames(4)
	return _finish_flow_suite(records)


func _run_case(main: Control, flow_case: Dictionary) -> Dictionary:
	var case_id := str(flow_case.get("case_id", ""))
	var interaction := str(flow_case.get("interaction", ""))
	var expected_action_id := str(flow_case.get("expected_action_id", ""))
	_set_status("Running first mission runtime case: %s..." % case_id)
	var clicked_action_id := expected_action_id
	var emitted_action_id := ""
	var coach_checked := false
	var player_board_checked := false
	var track_checked := false
	var map_checked := false
	var overlay_checked := false
	var privacy_checked := false
	var content_checked := true
	var income_checked := true
	var ai_public_action_checked := true
	var monster_pressure_checked := true
	var mission_complete_checked := true
	var rack_guarantee_checked := true
	var project_checked := true
	var second_card_checked := true
	var core_content_checked := true
	var pacing_checked := true
	var supply_pacing_checked := true
	match interaction:
		"start_first_mission":
			clicked_action_id = "start_first_mission"
			if main.has_method("start_first_mission_runtime"):
				main.call("start_first_mission_runtime")
			else:
				if main.has_method("_apply_recommended_first_run_setup"):
					main.call("_apply_recommended_first_run_setup")
				if main.has_method("_start_scenario_from_menu"):
					main.call("_start_scenario_from_menu", "first_table")
			await _pump_frames(24)
			_configure_main_for_bench(main)
			_connect_runtime_signals(main)
			coach_checked = _scenario_id(main) == "first_table" and _coach_surface_checked(main)
			player_board_checked = _runtime_screen(main) != null and _core_surface_present(_runtime_screen(main))
			track_checked = _track_checked(main, false)
			map_checked = _map_checked(main)
			overlay_checked = _overlay_checked(main, false)
			content_checked = _authored_runtime_ids_checked(_authored_content_snapshot(main)) and _recommended_setup_checked(main)
		"coach_action":
			if case_id == "inspect_and_play_city_development" or case_id == "play_followup_business_card":
				await _prepare_teaching_card_inspection(main)
				await _wait_for_player_action_ready(main)
			var purchase_count_before := _player_card_purchase_count(main)
			emitted_action_id = await _request_screen_action(main, expected_action_id)
			match case_id:
				"summon_starter_monster":
					await _wait_for_active_monster(main)
				"buy_city_development_card", "buy_followup_business_card":
					var purchased := await _wait_for_card_purchase(main, purchase_count_before)
					if not purchased:
						emitted_action_id = await _request_screen_action(main, expected_action_id)
						await _wait_for_card_purchase(main, purchase_count_before)
				"inspect_and_play_city_development":
					await _wait_for_track_activity(main)
				"play_followup_business_card":
					await _wait_for_followup_card_resolution(main)
			coach_checked = _coach_surface_checked(main)
			player_board_checked = _player_board_checked(main)
			track_checked = _track_checked(main, ["inspect_and_play_city_development", "play_followup_business_card", "observe_public_resolution_track"].has(case_id))
			map_checked = _map_checked(main)
			overlay_checked = _overlay_checked(main, false)
			var content := _authored_content_snapshot(main)
			content_checked = _authored_runtime_ids_checked(content)
			match case_id:
				"select_recommended_district":
					content_checked = content_checked and int(content.get("district_index", -1)) >= 0 and str(content.get("teaching_product_id", "")) != ""
				"summon_starter_monster":
					content_checked = content_checked and _starter_monster_checked(main, content)
				"open_real_district_supply":
					content_checked = content_checked and int(main.get("district_supply_open_district")) >= 0
				"buy_city_development_card":
					content_checked = content_checked and _teaching_card_owned(main, content)
				"inspect_and_play_city_development":
					content_checked = content_checked and _right_inspector_card_checked(main)
				"buy_followup_business_card":
					second_card_checked = _followup_card_owned(main)
				"play_followup_business_card":
					second_card_checked = _followup_card_played(main)
					if not second_card_checked:
						print("First Table follow-up diagnostic: %s" % JSON.stringify(_followup_card_debug(main)))
				"observe_public_resolution_track":
					content_checked = content_checked and int(main.get("selected_card_resolution_id")) >= 0
		"rack_guarantee":
			clicked_action_id = ""
			emitted_action_id = ""
			rack_guarantee_checked = _land_rack_development_guarantee_checked(main)
			content_checked = _authored_runtime_ids_checked(_authored_content_snapshot(main))
			coach_checked = _coach_surface_checked(main)
			player_board_checked = _player_board_checked(main)
			track_checked = _track_checked(main, false)
			map_checked = _map_checked(main)
			overlay_checked = _overlay_checked(main, false)
		"project_resolution":
			clicked_action_id = ""
			emitted_action_id = ""
			project_checked = await _wait_for_player_project(main)
			var project_content := _authored_content_snapshot(main)
			_followup_prepositioned_observed = _followup_present_in_project_supply(main, project_content)
			content_checked = _authored_runtime_ids_checked(project_content) and bool(project_content.get("city_present", false)) and not str(project_content.get("facility_summary_text", "")).contains("尚未")
			coach_checked = _coach_surface_checked(main)
			player_board_checked = _player_board_checked(main)
			track_checked = _track_checked(main, true)
			map_checked = _map_checked(main)
			overlay_checked = _overlay_checked(main, false)
		"positive_income":
			var market_controller := _product_market_controller(main)
			if market_controller != null:
				market_controller.call("market_tick")
			if main.has_method("_settle_city_cashflow_seconds"):
				main.call("_settle_city_cashflow_seconds", 120.0)
			await _sync_main(main)
			emitted_action_id = await _request_screen_action(main, expected_action_id)
			var income_content := _authored_content_snapshot(main)
			income_checked = bool(income_content.get("positive_income_observed", false))
			content_checked = _authored_runtime_ids_checked(income_content)
			coach_checked = _coach_surface_checked(main)
			player_board_checked = _player_board_checked(main)
			track_checked = _track_checked(main, true)
			map_checked = _map_checked(main)
			overlay_checked = _overlay_checked(main, false)
		"ai_public_action":
			emitted_action_id = await _request_screen_action(main, expected_action_id)
			var ai_content := _authored_content_snapshot(main)
			ai_public_action_checked = bool(ai_content.get("ai_public_action_seen", false)) and int(ai_content.get("public_clue_count", 0)) > 0
			if not ai_public_action_checked:
				print("First Table AI public action diagnostic: %s" % JSON.stringify(_ai_public_action_debug(main)))
			content_checked = _authored_runtime_ids_checked(ai_content)
			coach_checked = _coach_surface_checked(main)
			player_board_checked = _player_board_checked(main)
			track_checked = _track_checked(main, true)
			map_checked = _map_checked(main)
			overlay_checked = _overlay_checked(main, false)
		"public_clue":
			emitted_action_id = await _request_screen_action(main, expected_action_id)
			var clue_content := _authored_content_snapshot(main)
			content_checked = _authored_runtime_ids_checked(clue_content) and int(clue_content.get("public_clue_count", 0)) > 0
			coach_checked = _coach_surface_checked(main)
			player_board_checked = _player_board_checked(main)
			track_checked = _track_checked(main, true)
			map_checked = _map_checked(main)
			overlay_checked = _overlay_checked(main, false)
		"monster_pressure":
			var cue_count_before := _runtime_visual_cue_count(main)
			var monsters := _monster_controller(main)
			if monsters != null and monsters.has_method("_monster_tick"):
				monsters.call("_monster_tick")
			await _pump_frames(20)
			emitted_action_id = await _request_screen_action(main, expected_action_id)
			var pressure_content := _authored_content_snapshot(main)
			monster_pressure_checked = bool(pressure_content.get("monster_pressure_seen", false)) \
				and bool(pressure_content.get("monster_pressure_visible", false)) \
				and (_runtime_visual_cue_count(main) > cue_count_before or _node_tree_text(_map_view(main)).contains(str(pressure_content.get("visible_monster_name", "怪兽"))))
			content_checked = _authored_runtime_ids_checked(pressure_content)
			coach_checked = _coach_surface_checked(main)
			player_board_checked = _player_board_checked(main)
			track_checked = _track_checked(main, true)
			map_checked = _map_checked(main)
			overlay_checked = _overlay_checked(main, false)
		"mission_completion":
			emitted_action_id = await _request_screen_action(main, expected_action_id)
			var completion_content := _authored_content_snapshot(main)
			mission_complete_checked = _mission_summary_checked(main)
			content_checked = _authored_runtime_ids_checked(completion_content)
			coach_checked = _coach_surface_checked(main)
			player_board_checked = _player_board_checked(main)
			track_checked = _track_checked(main, true)
			map_checked = _map_checked(main)
			overlay_checked = _overlay_checked(main, false)
		"core_content_gate":
			clicked_action_id = ""
			emitted_action_id = ""
			var core_content := _authored_content_snapshot(main)
			core_content_checked = _core_content_case_checked(main, case_id)
			content_checked = _authored_runtime_ids_checked(core_content) and core_content_checked
			coach_checked = _coach_surface_checked(main)
			player_board_checked = _player_board_checked(main)
			track_checked = _track_checked(main, false)
			map_checked = _map_checked(main)
			overlay_checked = _overlay_checked(main, false)
		"pacing_gate":
			clicked_action_id = ""
			emitted_action_id = ""
			pacing_checked = _pacing_case_checked(main, case_id)
			supply_pacing_checked = _supply_pacing_case_checked(main, case_id)
			content_checked = _authored_runtime_ids_checked(_authored_content_snapshot(main)) and pacing_checked and supply_pacing_checked
			coach_checked = _coach_surface_checked(main)
			player_board_checked = _player_board_checked(main)
			track_checked = _track_checked(main, false)
			map_checked = _map_checked(main)
			overlay_checked = _overlay_checked(main, false)
		"privacy":
			clicked_action_id = ""
			emitted_action_id = ""
			coach_checked = _coach_surface_checked(main)
			player_board_checked = _player_board_checked(main)
			track_checked = _track_checked(main, false)
			map_checked = _map_checked(main)
			overlay_checked = _overlay_checked(main, false)
		_:
			_failures.append("unknown first mission runtime case: %s" % case_id)
	privacy_checked = _privacy_checked(main, flow_case)
	var passed := coach_checked and player_board_checked and track_checked and map_checked and overlay_checked and privacy_checked \
		and content_checked and income_checked and ai_public_action_checked and monster_pressure_checked and mission_complete_checked \
		and rack_guarantee_checked and project_checked and second_card_checked and core_content_checked and pacing_checked and supply_pacing_checked
	if not passed:
		_failures.append("%s failed: clicked=%s emitted=%s coach=%s board=%s track=%s map=%s overlay=%s privacy=%s content=%s income=%s ai=%s monster=%s complete=%s core=%s pacing=%s supply=%s" % [
			case_id,
			clicked_action_id,
			emitted_action_id,
			str(coach_checked),
			str(player_board_checked),
			str(track_checked),
			str(map_checked),
			str(overlay_checked),
			str(privacy_checked),
			str(content_checked),
			str(income_checked),
			str(ai_public_action_checked),
			str(monster_pressure_checked),
			str(mission_complete_checked),
			str(core_content_checked),
			str(pacing_checked),
			str(supply_pacing_checked),
		])
	var pacing_record := _pacing_record_for_case(main, case_id)
	var record := {
		"case_id": case_id,
		"scenario_id": _scenario_id(main),
		"clicked_action_id": clicked_action_id,
		"emitted_action_id": emitted_action_id,
		"coach_checked": coach_checked,
		"player_board_checked": player_board_checked,
		"track_checked": track_checked,
		"map_checked": map_checked,
		"overlay_checked": overlay_checked,
		"privacy_checked": privacy_checked,
		"content_checked": content_checked,
		"income_checked": income_checked,
		"ai_public_action_checked": ai_public_action_checked,
		"monster_pressure_checked": monster_pressure_checked,
		"mission_complete_checked": mission_complete_checked,
		"rack_guarantee_checked": rack_guarantee_checked,
		"project_checked": project_checked,
		"second_card_checked": second_card_checked,
		"core_content_checked": core_content_checked,
		"pacing_checked": pacing_checked,
		"supply_pacing_checked": supply_pacing_checked,
		"observed_seconds": float(pacing_record.get("observed_seconds", -1.0)),
		"target_seconds": float(pacing_record.get("target_seconds", -1.0)),
		"warning_seconds": float(pacing_record.get("warning_seconds", -1.0)),
		"pace_status": str(pacing_record.get("status", "not_applicable")),
		"passed": passed,
		"notes": str(flow_case.get("notes", "")),
	}
	if summary_label != null:
		summary_label.text = "%s\n%s: %s" % [summary_label.text, case_id, "PASS" if passed else "FAIL"]
	return record


func _case(case_id: String, interaction: String, expected_action_id: String, notes: String) -> Dictionary:
	return {
		"case_id": case_id,
		"scenario_id": "first_table",
		"interaction": interaction,
		"expected_action_id": expected_action_id,
		"notes": notes,
	}


func _preview_record(flow_case: Dictionary) -> Dictionary:
	return {
		"case_id": str(flow_case.get("case_id", "")),
		"scenario_id": str(flow_case.get("scenario_id", "first_table")),
		"clicked_action_id": str(flow_case.get("expected_action_id", "")),
		"emitted_action_id": "",
		"coach_checked": false,
		"player_board_checked": false,
		"track_checked": false,
		"map_checked": false,
		"overlay_checked": false,
		"privacy_checked": false,
		"content_checked": false,
		"income_checked": false,
		"ai_public_action_checked": false,
		"monster_pressure_checked": false,
		"mission_complete_checked": false,
		"rack_guarantee_checked": false,
		"project_checked": false,
		"second_card_checked": false,
		"core_content_checked": false,
		"pacing_checked": false,
		"supply_pacing_checked": false,
		"observed_seconds": -1.0,
		"target_seconds": -1.0,
		"warning_seconds": -1.0,
		"pace_status": "preview",
		"passed": false,
		"notes": str(flow_case.get("notes", "")),
	}


func _connect_runtime_signals(main: Control) -> void:
	var screen := _runtime_screen(main)
	if screen != null and screen != _connected_screen:
		_connected_screen = screen
		if screen.has_signal("action_requested"):
			screen.connect("action_requested", func(action_id: String) -> void:
				_emitted_action_ids.append(action_id)
			)
	var track := _public_track(main)
	if track != null and track != _connected_track:
		_connected_track = track
		if track.has_signal("track_action_requested"):
			track.connect("track_action_requested", func(action_id: String) -> void:
				_track_action_ids.append(action_id)
			)


func _configure_main_for_bench(main: Control) -> void:
	if main == null:
		return
	main.set("card_resolution_force_duration", 0.05)
	main.set("card_resolution_force_simultaneous_window", 0.0)
	for timer_name in ["monster_timer", "special_monster_timer"]:
		main.set(timer_name, 3600.0)
	var market_controller := _product_market_controller(main)
	if market_controller != null:
		var market_state: Dictionary = market_controller.call("to_save_data")
		market_state["market_timer"] = 3600.0
		market_controller.call("apply_save_data", market_state)


func _monster_controller(main: Control) -> Node:
	return main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterRuntimeController") if main != null else null


func _product_market_controller(main: Control) -> Node:
	return main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductMarketRuntimeController") if main != null else null


func _card_definition(main: Control, card_id: String) -> Dictionary:
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if main != null else null
	var value: Variant = coordinator.call("card_definition", card_id) if coordinator != null and coordinator.has_method("card_definition") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _coordinator(main: Control) -> Node:
	return main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if main != null else null


func _ai_controller(main: Control) -> Node:
	return main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiRuntimeController") if main != null else null


func _resolved_content_catalog(main: Control) -> Dictionary:
	if main == null or not main.has_method("_first_table_resolved_content_catalog"):
		return {}
	var value: Variant = main.call("_first_table_resolved_content_catalog")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _core_content_case_checked(main: Control, case_id: String) -> bool:
	var content := _authored_content_snapshot(main)
	var resolved_catalog := _resolved_content_catalog(main)
	var core_ids := _string_values(content.get("featured_card_ids", []))
	match case_id:
		"core_set_ids_exist":
			return _core_set_ids_checked(main, core_ids)
		"core_set_resources_validate":
			return _core_set_resources_validate(core_ids)
		"rank_i_entry_cards_available":
			return _core_rank_i_public_pool_checked(main, core_ids)
		"teaching_supply_reachable":
			return _teaching_supply_reachable_checked(main, content, resolved_catalog)
		"first_enabled_card_is_clear":
			return _first_enabled_core_card_clear(main, core_ids)
		"disabled_reason_is_actionable":
			return _core_disabled_reason_actionable(main, core_ids)
		"economy_route_payoff_visible":
			return _core_economy_route_payoff_checked(main, content, core_ids)
		"monster_response_card_visible":
			return _core_monster_response_checked(main, content, core_ids)
		"public_clue_privacy_preserved":
			return _core_public_clue_privacy_checked(main, content, core_ids)
		"ai_can_use_core_set_without_private_leak":
			return _ai_core_card_route_checked(main, core_ids)
	return false


func _core_set_ids_checked(main: Control, core_ids: Array[String]) -> bool:
	if core_ids.size() != 20 or not _unique_strings(core_ids):
		return false
	var category_counts := {
		"city_economy": 0,
		"product_route": 0,
		"monster": 0,
		"intel_counter": 0,
		"recovery": 0,
	}
	for card_id in core_ids:
		var definition := _card_definition(main, card_id)
		if definition.is_empty() or str(definition.get("text", "")).strip_edges().is_empty():
			return false
		var kind := str(definition.get("kind", ""))
		if CORE_CITY_ECONOMY_KINDS.has(kind):
			category_counts["city_economy"] = int(category_counts["city_economy"]) + 1
		elif CORE_PRODUCT_ROUTE_KINDS.has(kind):
			category_counts["product_route"] = int(category_counts["product_route"]) + 1
		elif CORE_MONSTER_KINDS.has(kind):
			category_counts["monster"] = int(category_counts["monster"]) + 1
		elif CORE_INTEL_COUNTER_KINDS.has(kind):
			category_counts["intel_counter"] = int(category_counts["intel_counter"]) + 1
		elif CORE_RECOVERY_KINDS.has(kind):
			category_counts["recovery"] = int(category_counts["recovery"]) + 1
		else:
			return false
	return int(category_counts["city_economy"]) == 6 \
		and int(category_counts["product_route"]) == 5 \
		and int(category_counts["monster"]) == 2 \
		and int(category_counts["intel_counter"]) == 4 \
		and int(category_counts["recovery"]) == 3


func _core_set_resources_validate(core_ids: Array[String]) -> bool:
	var service: RefCounted = CARD_AUTHORING_SERVICE_SCRIPT.new()
	var configured: Dictionary = service.call("configure")
	if not bool(configured.get("configured", false)):
		return false
	for card_id in core_ids:
		var result: Dictionary = service.call("validate_card_id", card_id)
		if not bool(result.get("valid", false)):
			print("First Table core card validation failed: %s %s" % [card_id, JSON.stringify(result.get("errors", []))])
			return false
	return core_ids.size() == 20


func _core_rank_i_public_pool_checked(main: Control, core_ids: Array[String]) -> bool:
	var coordinator := _coordinator(main)
	if coordinator == null or not coordinator.has_method("card_catalog_public_pool"):
		return false
	var public_pool_value: Variant = coordinator.call("card_catalog_public_pool")
	var public_pool: Array = public_pool_value if public_pool_value is Array else []
	for card_id in core_ids:
		if not public_pool.has(card_id) or int(coordinator.call("card_rank", card_id)) != 1:
			return false
	return core_ids.size() == 20


func _teaching_supply_reachable_checked(main: Control, content: Dictionary, resolved_catalog: Dictionary) -> bool:
	var teaching_card_id := str(content.get("teaching_card_id", ""))
	var runtime_ids := _string_values(resolved_catalog.get("runtime_card_ids", []))
	var followup_ids := _string_values(resolved_catalog.get("followup_card_ids", []))
	var coordinator := _coordinator(main)
	if coordinator == null or teaching_card_id == "" or not runtime_ids.has(teaching_card_id):
		return false
	var public_pool_value: Variant = coordinator.call("card_catalog_public_pool")
	var public_pool: Array = public_pool_value if public_pool_value is Array else []
	for card_id in followup_ids:
		if not runtime_ids.has(card_id) or not public_pool.has(card_id):
			return false
	return followup_ids == ["城市融资1", "商品换线1", "诱导电波1", "业主透镜1"] \
		and str(resolved_catalog.get("followup_card_id", "")) == "城市融资1" \
		and _land_rack_development_guarantee_checked(main)


func _first_enabled_core_card_clear(main: Control, core_ids: Array[String]) -> bool:
	for card_id in core_ids:
		var skill := _card_definition(main, card_id)
		var eligibility: Dictionary = main.call("_card_play_eligibility_snapshot", _player_index(main), skill, "rule", {}) if main.has_method("_card_play_eligibility_snapshot") else {}
		if not bool(eligibility.get("allowed", false)) or not bool(eligibility.get("actionable", false)):
			continue
		var presentation: Dictionary = main.call("_card_play_presentation_snapshot", eligibility, skill) if main.has_method("_card_play_presentation_snapshot") else {}
		return bool(presentation.get("actionable", false)) \
			and not str(presentation.get("label", "")).strip_edges().is_empty() \
			and not str(presentation.get("detail", "")).strip_edges().is_empty()
	return false


func _core_disabled_reason_actionable(main: Control, core_ids: Array[String]) -> bool:
	if not core_ids.has("相位否决1"):
		return false
	var coordinator := _coordinator(main)
	var skill := _card_definition(main, "相位否决1")
	if coordinator == null or skill.is_empty():
		return false
	var facts: Dictionary = coordinator.call("card_play_world_facts", _player_index(main), skill, {})
	facts["counter_window_active"] = false
	facts["active_resolution_present"] = false
	var eligibility: Dictionary = coordinator.call("evaluate_card_play", {"player_index": _player_index(main), "skill": skill, "evaluation_mode": "rule"}, facts)
	var presentation: Dictionary = coordinator.call("compose_card_play_eligibility", eligibility, {"card_name": "相位否决1", "display_name": "相位否决 I"})
	return not bool(eligibility.get("allowed", true)) \
		and str(eligibility.get("reason_code", "")) == "counter_window_closed" \
		and not bool(presentation.get("actionable", true)) \
		and not str(presentation.get("detail", "")).strip_edges().is_empty()


func _core_economy_route_payoff_checked(main: Control, content: Dictionary, core_ids: Array[String]) -> bool:
	var has_route_card := false
	for card_id in core_ids:
		if CORE_PRODUCT_ROUTE_KINDS.has(str(_card_definition(main, card_id).get("kind", ""))):
			has_route_card = true
			break
	return has_route_card and bool(content.get("positive_income_observed", false)) \
		and (int(content.get("gdp_per_minute", 0)) > 0 or int(content.get("cashflow_paid_total", 0)) > 0) \
		and _track_checked(main, true)


func _core_monster_response_checked(main: Control, content: Dictionary, core_ids: Array[String]) -> bool:
	var response_ready := false
	for card_id in core_ids:
		var skill := _card_definition(main, card_id)
		if not CORE_MONSTER_KINDS.has(str(skill.get("kind", ""))):
			continue
		var target: Dictionary = main.call("_card_play_target_snapshot", skill) if main.has_method("_card_play_target_snapshot") else {}
		if bool(target.get("targets_monster", false)) and bool(target.get("target_ready", false)):
			response_ready = true
			break
	return response_ready and bool(content.get("monster_pressure_seen", false)) and bool(content.get("monster_pressure_visible", false))


func _core_public_clue_privacy_checked(main: Control, content: Dictionary, core_ids: Array[String]) -> bool:
	var intel_count := 0
	for card_id in core_ids:
		if str(_card_definition(main, card_id).get("kind", "")).begins_with("intel_"):
			intel_count += 1
	return intel_count >= 3 and int(content.get("public_clue_count", 0)) > 0 \
		and _privacy_checked(main, {"case_id": "public_clue_privacy_preserved", "featured_card_ids": core_ids})


func _ai_core_card_route_checked(main: Control, core_ids: Array[String]) -> bool:
	if _player_count(main) < 2 or not core_ids.has("轨道融资1"):
		return false
	var coordinator := _coordinator(main)
	var ai_controller := _ai_controller(main)
	var skill := _card_definition(main, "轨道融资1")
	if coordinator == null or ai_controller == null or skill.is_empty():
		return false
	var ai_index := 1
	var facts: Dictionary = coordinator.call("card_play_world_facts", ai_index, skill, {})
	var eligibility: Dictionary = coordinator.call("evaluate_card_play", {"player_index": ai_index, "skill": skill, "evaluation_mode": "rule"}, facts)
	if not bool(eligibility.get("allowed", false)):
		return false
	var candidate := {
		"candidate_id": "first_table_core_cash_gain",
		"action_id": "play_card",
		"card_id": "轨道融资1",
		"score": 100,
		"weight": 100,
	}
	var plan: Dictionary = ai_controller.call("build_turn_plan", ai_index, {"candidates": [candidate], "context_revision": 60})
	var selected: Dictionary = plan.get("selected", {}) if plan.get("selected", {}) is Dictionary else {}
	return bool(plan.get("planned", false)) and str(selected.get("card_id", "")) == "轨道融资1" \
		and _value_has_private_token(plan) == false


func _pacing_profile(main: Control) -> Dictionary:
	var coordinator := _coordinator(main)
	var value: Variant = coordinator.call("first_table_pacing_profile") if coordinator != null and coordinator.has_method("first_table_pacing_profile") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _pacing_evaluation(main: Control) -> Dictionary:
	var coordinator := _coordinator(main)
	var value: Variant = coordinator.call("first_table_evaluate_pacing", _scenario_state(main)) if coordinator != null and coordinator.has_method("first_table_evaluate_pacing") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _pacing_record_for_case(main: Control, case_id: String) -> Dictionary:
	var milestone_id := str(PACING_CASE_MILESTONES.get(case_id, ""))
	if milestone_id == "":
		return {}
	for record_variant in _pacing_evaluation(main).get("records", []):
		if record_variant is Dictionary and str((record_variant as Dictionary).get("id", "")) == milestone_id:
			return (record_variant as Dictionary).duplicate(true)
	return {}


func _pacing_case_checked(main: Control, case_id: String) -> bool:
	var profile := _pacing_profile(main)
	var evaluation := _pacing_evaluation(main)
	match case_id:
		"pacing_profile_15_to_30_minutes":
			return str(profile.get("measurement_kind", "")) == "scenario_game_time" \
				and float(profile.get("recommended_min_seconds", 0.0)) == 900.0 \
				and float(profile.get("target_duration_seconds", 0.0)) == 1200.0 \
				and float(profile.get("recommended_max_seconds", 0.0)) == 1800.0 \
				and (profile.get("milestones", []) as Array).size() == 6 \
				and not _value_has_private_token(profile)
		"milestone_telemetry_records_real_game_time":
			return _timed_signals_ordered(_scenario_state(main))
		"first_development_card_timing", "first_positive_income_timing", "second_card_timing", "first_public_clue_timing", "first_monster_pressure_timing":
			var record := _pacing_record_for_case(main, case_id)
			return bool(record.get("reached", false)) and bool(record.get("upper_bound_met", false)) and float(record.get("observed_seconds", -1.0)) >= 0.0
		"mission_completion_budget":
			var completion_seconds := float(evaluation.get("completion_elapsed_seconds", -1.0))
			return bool(evaluation.get("pacing_gate_passed", false)) and completion_seconds >= 0.0 and completion_seconds <= float(profile.get("recommended_max_seconds", 0.0)) and str(evaluation.get("recommended_window_status", "")) in ["fast", "within_window"]
		"local_product_development_supply_stable", "followup_supply_prepositioned":
			return true
	return false


func _supply_pacing_case_checked(main: Control, case_id: String) -> bool:
	match case_id:
		"local_product_development_supply_stable":
			var content := _authored_content_snapshot(main)
			var teaching_card_id := str(content.get("teaching_card_id", ""))
			return teaching_card_id != "" and (_resolved_content_catalog(main).get("runtime_card_ids", []) as Array).has(teaching_card_id)
		"followup_supply_prepositioned":
			return _followup_prepositioned_observed
	return true


func _timed_signals_ordered(runtime_state: Dictionary) -> bool:
	var completed_times_variant: Variant = runtime_state.get("completed_signal_times", {})
	if not (completed_times_variant is Dictionary):
		return false
	var completed_times: Dictionary = completed_times_variant
	var expected_signals := ["district_selected", "monster_summoned", "rack_opened", "card_bought", "card_played", "public_facility_committed", "economy_checked", "followup_card_bought", "followup_card_played", "track_selected", "ai_public_action_observed", "public_clue_read", "monster_pressure_observed", "route_chosen"]
	var previous_time := float(runtime_state.get("scenario_started_at", 0.0))
	for signal_id_variant in expected_signals:
		var signal_id := str(signal_id_variant)
		if not completed_times.has(signal_id):
			return false
		var completed_at := float(completed_times.get(signal_id, -1.0))
		if completed_at < previous_time:
			return false
		previous_time = completed_at
	return _is_data_only(runtime_state)


func _followup_present_in_project_supply(main: Control, content: Dictionary) -> bool:
	var district_index := int(content.get("district_index", -1))
	var followup_card_id := str(_resolved_content_catalog(main).get("followup_card_id", ""))
	var districts: Array = main.get("districts") if main != null and main.get("districts") is Array else []
	if district_index < 0 or district_index >= districts.size() or followup_card_id == "" or not (districts[district_index] is Dictionary):
		return false
	var district: Dictionary = districts[district_index]
	var choices: Array = district.get("card_choices", []) if district.get("card_choices", []) is Array else []
	var sources: Dictionary = district.get("card_sources", {}) if district.get("card_sources", {}) is Dictionary else {}
	return choices.has(followup_card_id) and str(sources.get(followup_card_id, "")) == "首局任务第二张经营牌"


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item_variant in value:
			if not _is_data_only(item_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
		return true
	return false


func _string_values(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array or value is PackedStringArray:
		for item in value:
			var text_value := str(item)
			if text_value != "":
				result.append(text_value)
	return result


func _unique_strings(values: Array[String]) -> bool:
	var seen := {}
	for value in values:
		if seen.has(value):
			return false
		seen[value] = true
	return true


func _value_has_private_token(value: Variant) -> bool:
	var probe := JSON.stringify(value).to_lower()
	for token in PRIVATE_TOKENS:
		if probe.contains(token):
			return true
	return false


func _monster_wager_freezes(main: Control) -> bool:
	var monsters := _monster_controller(main)
	return bool(monsters.call("_monster_wager_freezes_game")) if monsters != null and monsters.has_method("_monster_wager_freezes_game") else false


func _request_screen_action(main: Control, action_id: String) -> String:
	_connect_runtime_signals(main)
	var before := _emitted_action_ids.size()
	var screen := _runtime_screen(main)
	if screen != null and screen.has_method("_on_action_requested"):
		screen.call("_on_action_requested", action_id)
	elif main.has_method("_on_runtime_game_screen_action_requested"):
		main.call("_on_runtime_game_screen_action_requested", action_id)
	await _pump_frames(16)
	_connect_runtime_signals(main)
	return _latest_since(_emitted_action_ids, before)


func _runtime_screen(main: Control) -> Control:
	if main == null:
		return null
	var value: Variant = main.get("runtime_game_screen")
	if value is Control:
		return value as Control
	return main.find_child("RuntimeGameScreen", true, false) as Control


func _player_board(main: Control) -> Control:
	var screen := _runtime_screen(main)
	return screen.find_child("PlayerBoard", true, false) as Control if screen != null else null


func _public_track(main: Control) -> Control:
	var screen := _runtime_screen(main)
	return screen.find_child("PublicTrack", true, false) as Control if screen != null else null


func _map_view(main: Control) -> Control:
	var screen := _runtime_screen(main)
	if screen == null:
		return null
	return screen.find_child("PlanetMapView", true, false) as Control


func _overlay(main: Control) -> Node:
	var screen := _runtime_screen(main)
	return screen.find_child("OverlayLayer", true, false) if screen != null else null


func _scenario_id(main: Control) -> String:
	return str(_scenario_state(main).get("active_scenario_id", ""))


func _scenario_state(main: Control) -> Dictionary:
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if main != null else null
	var value: Variant = coordinator.call("runtime_scenario_state", float(main.get("game_time"))) if coordinator != null else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _player_index(main: Control) -> int:
	if main != null and main.has_method("_runtime_snapshot_player_index"):
		return int(main.call("_runtime_snapshot_player_index"))
	return 0


func _player_count(main: Control) -> int:
	var players_value: Variant = main.get("players")
	var players: Array = players_value if players_value is Array else []
	return players.size()


func _player_card_purchase_count(main: Control) -> int:
	var players_value: Variant = main.get("players")
	var players: Array = players_value if players_value is Array else []
	var player_index := _player_index(main)
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return 0
	return int((players[player_index] as Dictionary).get("card_purchase_count", 0))


func _wait_for_active_monster(main: Control, max_frames: int = 480) -> bool:
	for _frame in range(maxi(1, max_frames)):
		var monsters := _monster_controller(main)
		if monsters != null and monsters.has_method("_active_auto_monster_count") and int(monsters.call("_active_auto_monster_count")) > 0:
			return true
		if main.has_method("_update_card_resolution_queue"):
			main.call("_update_card_resolution_queue", 0.5)
		await get_tree().process_frame
	return false


func _wait_for_player_city(main: Control, max_frames: int = 180) -> bool:
	for _frame in range(maxi(1, max_frames)):
		var content := _authored_content_snapshot(main)
		if bool(content.get("city_present", false)):
			return true
		await get_tree().process_frame
	return false


func _wait_for_player_project(main: Control, max_frames: int = 480) -> bool:
	for _frame in range(maxi(1, max_frames)):
		var content := _authored_content_snapshot(main)
		var owned_facilities: Array = content.get("owned_facilities", []) if content.get("owned_facilities", []) is Array else []
		if bool(content.get("city_present", false)) and not owned_facilities.is_empty():
			var signals: Dictionary = _scenario_state(main).get("completed_signals", {})
			if bool(signals.get("public_facility_committed", false)):
				return true
		if main.has_method("_update_card_resolution_queue"):
			main.call("_update_card_resolution_queue", 0.5)
		await get_tree().process_frame
	return false


func _wait_for_card_purchase(main: Control, purchase_count_before: int, max_frames: int = 180) -> bool:
	for _frame in range(maxi(1, max_frames)):
		if _player_card_purchase_count(main) > purchase_count_before:
			return true
		await get_tree().process_frame
	return false


func _wait_for_track_activity(main: Control, max_frames: int = 480) -> bool:
	for _frame in range(maxi(1, max_frames)):
		if _track_checked(main, true):
			return true
		await get_tree().process_frame
	return false


func _wait_for_followup_card_resolution(main: Control, max_frames: int = 480) -> bool:
	for _frame in range(maxi(1, max_frames)):
		if _followup_card_played(main):
			return true
		if main != null and main.has_method("_update_card_resolution_queue"):
			main.call("_update_card_resolution_queue", 0.5)
		await get_tree().process_frame
	return false


func _wait_for_player_action_ready(main: Control, max_steps: int = 120) -> bool:
	var player_index := _player_index(main)
	for _step in range(maxi(1, max_steps)):
		var players_value: Variant = main.get("players")
		var players: Array = players_value if players_value is Array else []
		if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
			return false
		if float((players[player_index] as Dictionary).get("action_cooldown", 0.0)) <= 0.0:
			return true
		if main.has_method("_update_realtime_cooldowns"):
			main.call("_update_realtime_cooldowns", 1.0 / 30.0)
		await get_tree().process_frame
	return false


func _recommended_setup_checked(main: Control) -> bool:
	var players_value: Variant = main.get("players")
	var players: Array = players_value if players_value is Array else []
	if _scenario_id(main) != "first_table" or players.is_empty():
		return false
	var player_index := clampi(_player_index(main), 0, players.size() - 1)
	var player: Dictionary = players[player_index] if players[player_index] is Dictionary else {}
	var hand: Array = player.get("hand", []) if player.get("hand", []) is Array else []
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	return _runtime_screen(main) != null and (not hand.is_empty() or not slots.is_empty())


func _authored_content_snapshot(main: Control) -> Dictionary:
	if main == null or not main.has_method("_first_table_runtime_content_snapshot"):
		return {}
	var value: Variant = main.call("_first_table_runtime_content_snapshot", _player_index(main))
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _authored_runtime_ids_checked(content: Dictionary) -> bool:
	if str(content.get("scenario_id", "")) != "first_table":
		return false
	var card_ids: Array = content.get("teaching_card_ids", []) if content.get("teaching_card_ids", []) is Array else []
	var monster_ids: Array = content.get("starter_monster_ids", []) if content.get("starter_monster_ids", []) is Array else []
	var product_ids: Array = content.get("preferred_product_ids", []) if content.get("preferred_product_ids", []) is Array else []
	var teaching_card_id := str(content.get("teaching_card_id", ""))
	var starter_monster_id := str(content.get("starter_monster_id", ""))
	var teaching_product_id := str(content.get("teaching_product_id", ""))
	return teaching_card_id != "" and card_ids.has(teaching_card_id) \
		and starter_monster_id != "" and monster_ids.has(starter_monster_id) \
		and teaching_product_id != "" and (product_ids.has(teaching_product_id) or not product_ids.is_empty())


func _starter_monster_checked(main: Control, content: Dictionary) -> bool:
	var monsters := _monster_controller(main)
	var active_count := int(monsters.call("_active_auto_monster_count")) if monsters != null and monsters.has_method("_active_auto_monster_count") else 0
	var monster_ids: Array = content.get("starter_monster_ids", []) if content.get("starter_monster_ids", []) is Array else []
	return active_count > 0 and monster_ids.has(str(content.get("starter_monster_id", "")))


func _teaching_card_owned(main: Control, content: Dictionary) -> bool:
	var players_value: Variant = main.get("players")
	var players: Array = players_value if players_value is Array else []
	var player_index := _player_index(main)
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return false
	var player: Dictionary = players[player_index]
	if int(player.get("card_purchase_count", 0)) <= 0:
		return false
	var teaching_card_id := str(content.get("teaching_card_id", ""))
	for slot_variant in player.get("slots", []):
		if slot_variant is Dictionary and str((slot_variant as Dictionary).get("name", "")) == teaching_card_id:
			return true
	return false


func _followup_card_owned(main: Control) -> bool:
	var players_value: Variant = main.get("players")
	var players: Array = players_value if players_value is Array else []
	var player_index := _player_index(main)
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return false
	for slot_variant in (players[player_index] as Dictionary).get("slots", []):
		if slot_variant is Dictionary and str((slot_variant as Dictionary).get("name", "")).begins_with("城市融资"):
			return true
	return false


func _followup_card_played(main: Control) -> bool:
	var signals: Dictionary = _scenario_state(main).get("completed_signals", {})
	return bool(signals.get("followup_card_played", false))


func _followup_card_debug(main: Control) -> Dictionary:
	var players_value: Variant = main.get("players")
	var players: Array = players_value if players_value is Array else []
	var player_index := _player_index(main)
	var player: Dictionary = players[player_index] if player_index >= 0 and player_index < players.size() and players[player_index] is Dictionary else {}
	var log_value: Variant = main.get("log_lines")
	var logs: Array = log_value if log_value is Array else []
	var result := {
		"selected_district": int(main.get("selected_district")),
		"selected_player": int(main.get("selected_player")),
		"player_index": player_index,
		"game_over": bool(main.get("game_over")),
		"action_cooldown": float(player.get("action_cooldown", -1.0)),
		"can_selected_player_act": bool(main.call("_can_selected_player_act")) if main.has_method("_can_selected_player_act") else false,
		"pending_monster_target": bool(main.call("_has_pending_target_choice")) if main.has_method("_has_pending_target_choice") else false,
		"pending_player_target": bool(main.call("_has_pending_player_target_choice")) if main.has_method("_has_pending_player_target_choice") else false,
		"card_group_phase": str(main.call("_card_group_window_phase")) if main.has_method("_card_group_window_phase") else "",
		"card_group_locked": bool(main.get("card_resolution_batch_locked")),
		"monster_wager_freezes": _monster_wager_freezes(main),
		"active_resolution": not (main.get("active_card_resolution") as Dictionary).is_empty() if main.get("active_card_resolution") is Dictionary else false,
		"queue_count": (main.get("card_resolution_queue") as Array).size() if main.get("card_resolution_queue") is Array else 0,
		"signals": (_scenario_state(main).get("completed_signals", {}) as Dictionary).duplicate(true),
		"log_tail": logs.slice(maxi(0, logs.size() - 8)),
		"cards": [],
	}
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return result
	for slot_variant in (players[player_index] as Dictionary).get("slots", []):
		if not (slot_variant is Dictionary):
			continue
		var skill: Dictionary = slot_variant as Dictionary
		if not str(skill.get("name", "")).begins_with("城市融资"):
			continue
		var eligibility: Dictionary = main.call("_card_play_eligibility_snapshot", player_index, skill, "hand", {}) if main.has_method("_card_play_eligibility_snapshot") else {}
		var state: Dictionary = main.call("_card_play_presentation_snapshot", eligibility, skill) if main.has_method("_card_play_presentation_snapshot") else {}
		(result["cards"] as Array).append({"name": skill.get("name", ""), "state": state})
	return result


func _ai_public_action_debug(main: Control) -> Dictionary:
	var result := {
		"scenario_id": _scenario_id(main),
		"public_clue_count": int(main.call("_first_table_public_clue_count")) if main.has_method("_first_table_public_clue_count") else -1,
		"active_cities": [],
		"ai_candidates": [],
		"log_tail": [],
	}
	var districts_value: Variant = main.get("districts")
	var districts: Array = districts_value if districts_value is Array else []
	var active_indices: Array = main.call("_active_city_district_indices") if main.has_method("_active_city_district_indices") else []
	for district_index_variant in active_indices:
		var district_index := int(district_index_variant)
		if district_index < 0 or district_index >= districts.size() or not (districts[district_index] is Dictionary):
			continue
		var district: Dictionary = districts[district_index]
		var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
		(result["active_cities"] as Array).append({"district_index": district_index, "district_name": str(district.get("name", "")), "owner": int(city.get("owner", -1))})
	var ai_order: Array = main.call("_ai_runtime_call", "_rival_build_player_order") if main.has_method("_ai_runtime_call") else []
	for player_index_variant in ai_order:
		var player_index := int(player_index_variant)
		var target := int(main.call("_ai_runtime_call", "_auto_build_target_for_player", [player_index])) if main.has_method("_ai_runtime_call") else -1
		(result["ai_candidates"] as Array).append({"player_index": player_index, "target_district": target})
	var logs_value: Variant = main.get("log_lines")
	var logs: Array = logs_value if logs_value is Array else []
	result["log_tail"] = logs.slice(maxi(0, logs.size() - 12))
	return result


func _land_rack_development_guarantee_checked(main: Control) -> bool:
	var districts_value: Variant = main.get("districts")
	var districts: Array = districts_value if districts_value is Array else []
	var checked_land_count := 0
	for district_variant in districts:
		if not (district_variant is Dictionary):
			continue
		var district: Dictionary = district_variant as Dictionary
		if bool(district.get("destroyed", false)) or str(district.get("terrain", "land")) != "land":
			continue
		checked_land_count += 1
		var has_development := false
		for card_variant in district.get("card_choices", []):
			var card_name := str(card_variant)
			var skill := _card_definition(main, card_name)
			if str(skill.get("kind", "")) == "city_development":
				has_development = true
				break
		if not has_development:
			return false
	return checked_land_count > 0


func _prepare_teaching_card_inspection(main: Control) -> void:
	var slot_index := -1
	if main.has_method("_first_table_city_development_hand_slot"):
		slot_index = int(main.call("_first_table_city_development_hand_slot", _player_index(main)))
	if slot_index < 0 and main.has_method("_first_table_followup_hand_slot"):
		slot_index = int(main.call("_first_table_followup_hand_slot", _player_index(main)))
	if slot_index < 0 and main.has_method("_first_actionable_teachable_hand_slot"):
		slot_index = int(main.call("_first_actionable_teachable_hand_slot", _player_index(main)))
	if slot_index >= 0:
		main.set("selected_runtime_card_slot", slot_index)
	await _sync_main(main)


func _right_inspector_card_checked(main: Control) -> bool:
	var screen := _runtime_screen(main)
	var inspector := screen.find_child("RightInspector", true, false) as Control if screen != null else null
	if inspector == null or not inspector.visible:
		return false
	var text := _node_tree_text(inspector)
	return text.contains("用途") or text.contains("条件") or text.contains("效果") or text.contains("融资") or text.contains("项目")


func _runtime_visual_cue_count(main: Control) -> int:
	var total := 0
	for property_name in ["action_callouts", "movement_trails", "map_event_effects"]:
		var value: Variant = main.get(property_name)
		if value is Array:
			total += (value as Array).size()
	return total


func _mission_summary_checked(main: Control) -> bool:
	if not main.has_method("_runtime_scenario_coach_snapshot_source"):
		return false
	var value: Variant = main.call("_runtime_scenario_coach_snapshot_source", _player_index(main))
	var snapshot: Dictionary = value if value is Dictionary else {}
	var summary := str(snapshot.get("completion_summary", ""))
	var signals: Dictionary = _scenario_state(main).get("completed_signals", {})
	var checked := bool(snapshot.get("completed", false)) and bool(signals.get("route_chosen", false)) and summary.contains("整局仍继续")
	if not checked:
		print("First Table completion diagnostic: completed=%s route=%s phase=%s summary=%s signals=%s" % [
			str(snapshot.get("completed", false)),
			str(signals.get("route_chosen", false)),
			str((snapshot.get("current_phase", {}) as Dictionary).get("id", "") if snapshot.get("current_phase", {}) is Dictionary else ""),
			summary,
			JSON.stringify(signals),
		])
	return checked


func _core_surface_present(screen: Control) -> bool:
	if screen == null:
		return false
	for node_name in ["TopBar", "PlayerBoard", "HandRack", "RightInspector", "PublicTrack", "PlanetBoard", "PlanetMapView", "OverlayLayer", "ScenarioCoach", "FirstRunCoach"]:
		if screen.find_child(node_name, true, false) == null:
			return false
	return true


func _coach_surface_checked(main: Control) -> bool:
	var screen := _runtime_screen(main)
	if screen == null:
		return false
	var scenario_coach := screen.find_child("ScenarioCoach", true, false) as Control
	var first_run_coach := screen.find_child("FirstRunCoach", true, false) as Control
	var text := _node_tree_text(screen)
	var has_first_mission_copy := text.contains("first_table") or text.contains("首") or text.contains("推荐")
	return scenario_coach != null and first_run_coach != null and _scenario_id(main) == "first_table" and (has_first_mission_copy or scenario_coach.visible or first_run_coach.visible)


func _player_board_checked(main: Control) -> bool:
	var board := _player_board(main)
	if board == null or not board.visible:
		return false
	var text := _node_tree_text(board)
	return text.contains("手牌") or text.contains("下一步") or text.contains("首局")


func _track_checked(main: Control, require_activity: bool) -> bool:
	var track := _public_track(main)
	if track == null or not track.visible:
		return false
	if not track.has_method("get_debug_snapshot"):
		return true
	var snapshot: Dictionary = track.call("get_debug_snapshot")
	if not bool(snapshot.get("exposes_sceneized_resolution_track", false)) or bool(snapshot.get("has_private_text", false)):
		return false
	if require_activity:
		return int(snapshot.get("entry_count", 0)) >= 1 or int(main.get("selected_card_resolution_id")) >= 0 or _node_tree_text(track).contains("公开")
	return true


func _map_checked(main: Control) -> bool:
	var map_view := _map_view(main)
	if map_view == null or not map_view.visible:
		return false
	if not map_view.has_method("get_sceneization_debug_snapshot"):
		return true
	var snapshot: Dictionary = map_view.call("get_sceneization_debug_snapshot")
	return bool(snapshot.get("sceneized_visual_cutover_enabled", false)) and not bool(snapshot.get("legacy_draw_fallback_used", true)) and int(snapshot.get("district_count", 0)) >= 1


func _overlay_checked(main: Control, require_visible_decision: bool) -> bool:
	var overlay := _overlay(main)
	if overlay == null or not overlay.has_signal("temporary_decision_action_requested"):
		return false
	if not require_visible_decision:
		var visible_panel_found := false
		for panel_name in ["MonsterWagerDecisionPanel", "ContractResponseDecisionPanel", "TemporaryChoiceDecisionPanel", "ConfirmPanel"]:
			var panel := overlay.find_child(panel_name, true, false) as Control
			if panel != null and panel.visible:
				visible_panel_found = true
		if not visible_panel_found:
			return true
		if main.has_method("_runtime_temporary_decision_snapshot_source"):
			var decision_value: Variant = main.call("_runtime_temporary_decision_snapshot_source", _player_index(main))
			return decision_value is Dictionary and not (decision_value as Dictionary).is_empty()
		return false
	var choice_panel := overlay.find_child("TemporaryChoiceDecisionPanel", true, false) as Control
	return choice_panel != null and choice_panel.visible and _node_tree_text(choice_panel).contains("目标")


func _privacy_checked(main: Control, flow_case: Dictionary) -> bool:
	var screen := _runtime_screen(main)
	var text := _node_tree_text(screen).to_lower()
	for token in PRIVATE_TOKENS:
		if text.contains(token):
			return false
	var probe := JSON.stringify({"case": flow_case, "authored_content": _authored_content_snapshot(main)}).to_lower()
	for token in PRIVATE_TOKENS:
		if probe.contains(token):
			return false
	return true


func _sync_main(main: Control) -> void:
	if main != null and main.has_method("_sync_runtime_game_screen"):
		main.call("_sync_runtime_game_screen", true)
	await _pump_frames(12)
	_connect_runtime_signals(main)


func _node_tree_text(node: Node) -> String:
	if node == null:
		return ""
	var pieces: Array[String] = []
	_collect_text(node, pieces)
	return "\n".join(pieces)


func _collect_text(node: Node, pieces: Array[String]) -> void:
	if node is Label:
		pieces.append((node as Label).text)
	elif node is Button:
		pieces.append((node as Button).text)
	elif node is LineEdit:
		pieces.append((node as LineEdit).text)
	if node is Control:
		var tooltip := (node as Control).tooltip_text
		if tooltip != "":
			pieces.append(tooltip)
	for child in node.get_children():
		_collect_text(child, pieces)


func _latest_string(values: Array[String]) -> String:
	if values.is_empty():
		return ""
	return values[values.size() - 1]


func _latest_since(values: Array[String], before_count: int) -> String:
	if values.size() <= before_count:
		return ""
	return values[values.size() - 1]


func _active_viewport() -> SubViewport:
	if preview_viewport != null:
		preview_viewport.size = VIEWPORT_SIZE
		return preview_viewport
	var viewport := SubViewport.new()
	viewport.name = "FirstMissionRuntimeMainPreviewViewport"
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = false
	add_child(viewport)
	return viewport


func _clear_viewport(viewport: SubViewport) -> void:
	for child in viewport.get_children():
		viewport.remove_child(child)
		child.queue_free()


func _prepare_output_dir() -> bool:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var make_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if make_error != OK:
		_failures.append("failed to create output dir %s: %s" % [OUTPUT_DIR, str(make_error)])
		return false
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		_failures.append("failed to open output dir %s" % OUTPUT_DIR)
		return false
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".json") or file_name.ends_with(".md")):
			var remove_error := dir.remove(file_name)
			if remove_error != OK:
				_failures.append("failed to remove old output %s: %s" % [file_name, str(remove_error)])
		file_name = dir.get_next()
	dir.list_dir_end()
	return true


func _save_viewport_screenshot(viewport: SubViewport, path: String) -> void:
	if viewport == null:
		return
	var absolute_path := ProjectSettings.globalize_path(path)
	var dir := absolute_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var image: Image = null
	if DisplayServer.get_name().to_lower() == "headless":
		image = Image.create_empty(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, false, Image.FORMAT_RGBA8)
		image.fill(Color("#020617"))
	else:
		image = viewport.get_texture().get_image()
	if image == null:
		return
	var err := image.save_png(absolute_path)
	if err != OK:
		_failures.append("failed to save screenshot %s: %s" % [path, str(err)])


func _write_text_file(path: String, text: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	var dir := absolute_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_failures.append("failed to write %s: %s" % [path, str(FileAccess.get_open_error())])
		return
	file.store_string(text)
	file.close()


func _build_markdown_report(manifest: Dictionary) -> String:
	var authored_content: Dictionary = manifest.get("authored_content", {}) if manifest.get("authored_content", {}) is Dictionary else {}
	var pacing_profile: Dictionary = manifest.get("pacing_profile", {}) if manifest.get("pacing_profile", {}) is Dictionary else {}
	var pacing_evaluation: Dictionary = manifest.get("pacing_evaluation", {}) if manifest.get("pacing_evaluation", {}) is Dictionary else {}
	var lines: Array[String] = [
		"# First Playable Balance & Pacing QA",
		"",
		"- Main scene: `%s`" % MAIN_SCENE_PATH,
		"- Output dir: `%s`" % OUTPUT_DIR,
		"- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("case_count", 0))],
		"- Runtime content: `%s` / `%s` / `%s`" % [str(authored_content.get("teaching_card_id", "")), str(authored_content.get("teaching_product_id", "")), str(authored_content.get("starter_monster_id", ""))],
		"- Follow-up card set: `%s`" % ", ".join(authored_content.get("featured_card_ids", []) as Array),
		"- Economy result: `%s` / GDP `%d` per minute / cashflow paid `%d`" % [str(authored_content.get("facility_summary_text", "")), int(authored_content.get("gdp_per_minute", 0)), int(authored_content.get("cashflow_paid_total", 0))],
		"- Public evidence: `%d` clue(s); no hidden owner fields are written." % int(authored_content.get("public_clue_count", 0)),
		"- Human pacing window: `%d-%d` seconds; authored target `%d` seconds." % [int(pacing_profile.get("recommended_min_seconds", 0)), int(pacing_profile.get("recommended_max_seconds", 0)), int(pacing_profile.get("target_duration_seconds", 0))],
		"- Automated real-main observation: `%0.2f` seconds; status `%s`." % [float(pacing_evaluation.get("completion_elapsed_seconds", -1.0)), str(pacing_evaluation.get("recommended_window_status", "pending"))],
		"- Measurement note: %s" % str(manifest.get("measurement_note", "")),
		"",
		"| Case | Observed | Target | Warning | Pace | Supply | Passed | Notes |",
		"| --- | ---: | ---: | ---: | --- | --- | --- | --- |",
	]
	var records: Array = manifest.get("records", []) if manifest.get("records", []) is Array else []
	for record_variant in records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %.2f | %.2f | %.2f | %s | %s | %s | %s |" % [
			str(record.get("case_id", "")),
			float(record.get("observed_seconds", -1.0)),
			float(record.get("target_seconds", -1.0)),
			float(record.get("warning_seconds", -1.0)),
			str(record.get("pace_status", "not_applicable")),
			"yes" if bool(record.get("supply_pacing_checked", false)) else "no",
			"yes" if bool(record.get("passed", false)) else "no",
			str(record.get("notes", "")).replace("|", "/"),
		])
	return "\n".join(lines)


func _finish_flow_suite(records: Array) -> int:
	var passed := _passed_count(records)
	var total := records.size()
	var ok := _failures.is_empty() and total > 0 and passed == total
	var summary := "First Playable Balance & Pacing QA complete: %d/%d passed. manifest=%s report=%s screenshot=%s" % [passed, total, MANIFEST_PATH, REPORT_PATH, SCREENSHOT_PATH]
	_set_status(summary)
	print(summary)
	if not ok:
		for failure in _failures:
			push_error(failure)
	return 0 if ok else 1


func _passed_count(records: Array) -> int:
	var count := 0
	for record_variant in records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _pump_frames(count: int) -> void:
	for _i in range(maxi(1, count)):
		await get_tree().process_frame
