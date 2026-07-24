extends SceneTree

const BASELINE_PATH := "res://docs/migration/main_gd_budget_baseline.json"
const LEDGER_PATH := "res://docs/migration/main_gd_cutover_ledger.json"
const MAIN_PATH := "res://scripts/main.gd"
const VALID_STATUSES := ["pending", "migrating", "cut_over", "blocked"]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var baseline := _json(BASELINE_PATH)
	var ledger := _json(LEDGER_PATH)
	_expect(not baseline.is_empty(), "main budget baseline loads")
	_expect(not ledger.is_empty(), "main cutover ledger loads")
	_expect(
		str(baseline.get("baseline_commit", "")) == "689c77af4867e2f85fc1edf356e1f7abb295bc7a",
		"budget baseline is pinned to onboarding-purge commit"
	)

	var main_source := FileAccess.get_file_as_string(MAIN_PATH) if FileAccess.file_exists(MAIN_PATH) else ""
	var metrics := _main_metrics(main_source)
	_expect(not main_source.contains("func _process("), "Main no longer owns the authoritative frame callback")
	_expect(not main_source.contains("func _physics_process("), "Main has no physics-process replacement loop")
	for retired_navigation_action in ["\"codex_region\":", "\"codex_cards\":", "\"inspect\":", "track_open_"]:
		_expect(not main_source.contains(retired_navigation_action), "Main no longer routes table navigation action %s" % retired_navigation_action)
	for retired_target_choice_symbol in [
		"TEMP_DECISION_MONSTER_TARGET", "TEMP_DECISION_PLAYER_TARGET", "_has_pending_target_choice",
		"_has_pending_player_target_choice", "_pending_target_skill", "_pending_player_target_skill",
		"_begin_target_monster_choice", "_begin_target_player_choice", "_clear_pending_target_choice",
		"_clear_pending_player_target_choice", "_cancel_pending_target_choice", "_cancel_pending_player_target_choice",
		"_choose_pending_target_monster", "_choose_pending_target_player",
	]:
		_expect(not main_source.contains(retired_target_choice_symbol), "Main no longer owns target-choice symbol %s" % retired_target_choice_symbol)
	_expect(not main_source.contains("target_monster_") and not main_source.contains("target_player_"), "Main no longer routes target option identifiers")
	_expect(not main_source.contains("TEMP_DECISION_MONSTER_WAGER"), "Main no longer owns the monster-wager response constant")
	_expect(not main_source.contains("action_id.begins_with(\"monster_wager:\")") and not main_source.contains("._place_monster_wager_percent"), "Main no longer parses or dispatches monster-wager responses")
	_expect(not main_source.contains("_victory_control_escrow_cents") and not main_source.contains("&\"active_monster_wagers\"") and not main_source.contains("&\"resolved_monster_wager_history\"") and not main_source.contains("&\"monster_wager_sequence\"") and not main_source.contains("&\"public_card_bid_monster_wager_pool\""), "Main no longer proxies wager settlement state or escrow")
	_expect(not main_source.contains("_update_monster_wagers") and not main_source.contains("tick_wagers"), "Main has no active monster-wager tick path")
	_expect(not main_source.contains("func _active_bottom_countdown_state("), "Main no longer aggregates forced-decision countdown presentation state")
	for retired_developer_balance_symbol in [
		"developer_balance_panel",
		"_developer_balance_greybox_enabled",
		"_build_developer_balance_greybox",
	]:
		_expect(not main_source.contains(retired_developer_balance_symbol), "Main no longer owns developer diagnostics symbol %s" % retired_developer_balance_symbol)
	var runtime_loop_source := FileAccess.get_file_as_string("res://scripts/runtime/runtime_loop.gd")
	var runtime_ports_source := FileAccess.get_file_as_string("res://scripts/runtime/runtime_world_ports.gd")
	var runtime_phases_source := FileAccess.get_file_as_string("res://scripts/runtime/runtime_phase_coordinator.gd")
	var coordinator_scene := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var ai_eligibility_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_card_eligibility_query_port.gd")
	var ai_region_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_region_knowledge_query_port.gd")
	var ai_city_inference_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_city_inference_command_port.gd")
	_expect(
		coordinator_scene.count("[node name=\"AiCardEligibilityQueryPort\"") == 1
			and ai_eligibility_source.contains("class_name AiCardEligibilityQueryPort")
			and not ai_eligibility_source.contains("TableSelectionState")
			and not ai_eligibility_source.contains("to_save_data"),
		"production composition owns one stateless actor-scoped AI card eligibility port"
	)
	_expect(
		coordinator_scene.count("[node name=\"AiRegionKnowledgeQueryPort\"") == 1
			and coordinator_scene.count("[node name=\"AiCityInferenceCommandPort\"") == 1
			and ai_region_source.contains("func bind_ai_capabilities(")
			and ai_city_inference_source.contains("func bind_ai_capabilities(")
			and not ai_region_source.contains("func bind_ai_capability(")
			and not ai_city_inference_source.contains("func bind_ai_capability(")
			and ai_region_source.contains("_capabilities_by_actor.get(actor_index) == capability")
			and ai_city_inference_source.contains("_capabilities_by_actor.get(actor_index) == capability")
			and not ai_source.contains("var _ai_region_knowledge_capability:"),
		"region knowledge and city inference use actor-scoped capability maps"
	)
	_expect(
		ai_region_source.contains("\"rival_warehouse_exposed\": false")
			and ai_region_source.contains("if actual_owner == actor_index:")
			and not ai_region_source.contains("\"warehouse_stockpile_count\": maxi"),
		"AI region projection keeps warehouse facts behind own-actor authorization"
	)
	for retired_ai_eligibility_route in [
		"_call_world(&\"_best_player_gdp_share_district\"",
		"_call_world(&\"_card_play_requirement_snapshot\"",
		"_call_world(&\"_card_play_eligibility_snapshot\"",
		"_call_world(&\"_log_card_play_rejection\"",
	]:
		_expect(
			not ai_source.contains(retired_ai_eligibility_route),
			"AI card eligibility route remains retired: %s" % retired_ai_eligibility_route
		)
	_expect(
		not main_source.contains("func _best_player_gdp_share_district("),
		"Main keeps the AI-only best-share helper physically deleted"
	)
	for retired_monster_definition_helper in [
		"_monster_mobility_summary_from_fields",
		"_monster_name_from_card_name",
		"_is_monster_card_name",
		"_monster_card_definition",
		"_is_monster_technique_card_name",
		"_monster_technique_definition",
	]:
		_expect(
			not main_source.contains("func %s(" % retired_monster_definition_helper),
			"Main retires monster definition helper %s" % retired_monster_definition_helper
		)
	var card_definition_bridge_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/card_runtime_definition_world_bridge.gd"
	)
	_expect(
		not card_definition_bridge_source.contains("var _world")
			and not card_definition_bridge_source.contains("func bind_world(")
			and not card_definition_bridge_source.contains(".has_method(")
			and not card_definition_bridge_source.contains(".call("),
		"card definition bridge has no Main binding or arbitrary dispatch"
	)
	_expect(runtime_loop_source.contains("func _process(real_delta: float)"), "scene-owned RuntimeLoop owns the frame callback")
	_expect(not runtime_loop_source.contains("/root/Main") and not runtime_loop_source.contains("current_scene") and not runtime_loop_source.contains("scripts/main.gd"), "RuntimeLoop has no Main callback or lookup")
	_expect(not runtime_loop_source.contains("get_node") and not runtime_loop_source.contains("get_parent") and runtime_loop_source.contains("RuntimePhaseCoordinator") and not runtime_loop_source.contains("RuntimeWorldPorts"), "RuntimeLoop depends only on one explicitly injected phase coordinator")
	_expect(coordinator_scene.count("[node name=\"RuntimeLoop\"") == 1, "production composition contains exactly one RuntimeLoop")
	_expect(coordinator_scene.count("[node name=\"RuntimeWorldPorts\"") == 1 and runtime_ports_source.contains("port_count\": 7"), "production composition contains one seven-port boundary")
	_expect(coordinator_scene.count("[node name=\"RuntimePhaseCoordinator\"") == 1 and runtime_phases_source.contains("phase_count\": 6"), "production composition contains one six-phase coordination boundary")
	_expect(not main_source.contains("func _on_victory_outcome_applied") and not main_source.contains("var log_lines"), "Main owns neither victory presentation nor public log storage")
	_expect(not main_source.contains("func _city_markers_for_selected_player") and not main_source.contains("func _auto_monster_markers"), "Main no longer assembles public map markers")
	_expect(not main_source.contains("_card_resolution_presentation_source") and not main_source.contains("_card_resolution_presentation_snapshot"), "Main no longer owns card-resolution presentation source or snapshot methods")
	_expect(not FileAccess.file_exists("res://scripts/runtime/contract_runtime_world_bridge.gd"), "retired contract response bridge is absent")
	var victory_bridge_source := FileAccess.get_file_as_string("res://scripts/runtime/victory_control_world_bridge.gd")
	_expect(not victory_bridge_source.contains("apply_outcome_receipt") and not victory_bridge_source.contains("_on_victory_outcome_applied"), "victory fact bridge has no Main presentation callback")
	var baseline_metrics: Dictionary = baseline.get("main", {})
	for key in [
		"physical_lines",
		"nonblank_lines",
		"methods",
		"top_level_variables",
		"constants",
		"signals",
		"top_level_preloads",
	]:
		_expect(
			int(metrics.get(key, 0)) <= int(baseline_metrics.get(key, 0)),
			"main budget does not increase: %s" % key
		)

	var domains: Array = ledger.get("domains", []) if ledger.get("domains", []) is Array else []
	_expect(domains.size() >= 10, "ledger covers every extinction domain")
	var names: Array[String] = []
	for domain_variant in domains:
		var domain: Dictionary = domain_variant
		var name := str(domain.get("domain", ""))
		var status := str(domain.get("status", ""))
		_expect(name != "" and not names.has(name), "ledger domain names are unique")
		_expect(VALID_STATUSES.has(status), "ledger status is valid: %s" % name)
		if status == "cut_over":
			_expect(bool(domain.get("old_path_deleted", false)), "cut-over domain deleted old path: %s" % name)
			_expect(bool(domain.get("duplicate_execution_checked", false)), "cut-over domain checked duplicates: %s" % name)
		names.append(name)

	var agents := FileAccess.get_file_as_string("res://AGENTS.md")
	_expect(agents.contains("## main.gd Extinction Policy"), "AGENTS carries permanent main extinction policy")
	_expect(
		agents.contains("No production task may") and agents.contains("monotonically reduce"),
		"AGENTS policy freezes new Main ownership and requires monotonic reduction"
	)
	_finish()


func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _main_metrics(source: String) -> Dictionary:
	var lines := source.split("\n", false)
	var nonblank := 0
	var methods := 0
	var variables := 0
	var constants := 0
	var signals := 0
	var preloads := 0
	for line_variant in lines:
		var line := str(line_variant)
		if line.strip_edges() != "":
			nonblank += 1
		if line.begins_with("func "):
			methods += 1
		elif line.begins_with("var "):
			variables += 1
		elif line.begins_with("const "):
			constants += 1
			if line.contains("preload("):
				preloads += 1
		elif line.begins_with("signal "):
			signals += 1
	return {
		"physical_lines": lines.size(),
		"nonblank_lines": nonblank,
		"methods": methods,
		"top_level_variables": variables,
		"constants": constants,
		"signals": signals,
		"top_level_preloads": preloads,
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Main.gd architecture gate passed (%d checks)." % _checks)
		quit(0)
		return
	push_error("Main.gd architecture gate failed:\n- " + "\n- ".join(_failures))
	quit(1)
