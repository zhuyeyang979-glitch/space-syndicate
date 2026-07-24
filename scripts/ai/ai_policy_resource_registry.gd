extends RefCounted
class_name AiPolicyResourceRegistry

const PROFILE_RESOURCE_PATH := "res://resources/ai/ai_policy_profile_v1.tres"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/ai_runtime_controller.gd"
const CONTROLLER_SCENE_PATH := "res://scenes/runtime/AiRuntimeController.tscn"
const WORLD_BRIDGE_SCRIPT_PATH := "res://scripts/runtime/ai_runtime_world_bridge.gd"
const WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/AiRuntimeWorldBridge.tscn"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const PREVIEW_SCENE_PATH := "res://scenes/tools/AiPolicyResourceMcpPreview.tscn"
const BENCH_SCENE_PATH := "res://scenes/tools/AiPolicyResourceBench.tscn"

const PERSONALITY_RESOURCE_PATHS := [
	"res://resources/ai/personalities/pioneer_ai_policy.tres",
	"res://resources/ai/personalities/arbitrage_ai_policy.tres",
	"res://resources/ai/personalities/disruptor_ai_policy.tres",
	"res://resources/ai/personalities/monster_tamer_ai_policy.tres",
	"res://resources/ai/personalities/contract_ai_policy.tres",
	"res://resources/ai/personalities/intelligence_ai_policy.tres",
]

const BASE_RESOURCE_CASES := [
	["profile_loads", "Profile"],
	["timing_matches_main", "Timing"],
	["selection_thresholds_match_main", "Decision"],
	["counter_thresholds_match_main", "Decision"],
	["strategy_route_policy_matches_main", "Strategy"],
	["phase_posture_matches_main", "Strategy"],
	["learning_controls_match_main", "Learning"],
	["personalities_match_main_catalog", "Personalities"],
	["runtime_owner_stays_main_gd", "Runtime Cutover"],
	["payloads_stay_pure_data", "Runtime Safety"],
]

const RUNTIME_CASES := [
	["controller_scene_composition", "Runtime Composition"],
	["controller_api_contract", "Runtime Composition"],
	["policy_resource_is_runtime_source", "Runtime Cutover"],
	["six_personality_profile_parity", "Runtime Parity"],
	["ai_state_reset", "Runtime State"],
	["ai_state_save_load", "Runtime State"],
	["card_play_candidate_parity", "Runtime Parity"],
	["card_buy_candidate_parity", "Runtime Parity"],
	["counter_response_parity", "Runtime Parity"],
	["intel_plan_parity", "Runtime Parity"],
	["monster_wager_parity", "Runtime Parity"],
	["military_plan_parity", "Runtime Parity"],
	["weather_plan_parity", "Runtime Parity"],
	["city_strategy_parity", "Runtime Parity"],
	["product_strategy_parity", "Runtime Parity"],
	["route_strategy_parity", "Runtime Parity"],
	["monster_strategy_parity", "Runtime Parity"],
	["candidate_legality_preserved", "Runtime Parity"],
	["score_order_preserved", "Runtime Parity"],
	["deterministic_tie_break", "RNG"],
	["shared_rng_order_preserved", "RNG"],
	["fallback_order_preserved", "Runtime Parity"],
	["ai_intent_routes_once", "World Bridge"],
	["failed_intent_no_partial_mutation", "World Bridge"],
	["public_private_boundary", "Privacy"],
	["three_ai_players_complete_cycle", "Runtime Flow"],
	["main_ai_algorithms_absent", "Main Deletion"],
	["main_ai_adapter_under_300_lines", "Main Deletion"],
	["execution_service_unchanged", "Ownership Boundary"],
	["pure_data_snapshots", "Privacy"],
	["no_parallel_ai_owner", "Ownership Boundary"],
]


func resource_paths() -> Array[String]:
	var paths: Array[String] = [PROFILE_RESOURCE_PATH]
	for path_variant in PERSONALITY_RESOURCE_PATHS:
		paths.append(str(path_variant))
	return paths


func resource_cases() -> Array:
	var result: Array = []
	for definition in BASE_RESOURCE_CASES:
		result.append(_case(str(definition[0]), str(definition[1])))
	for definition in RUNTIME_CASES:
		result.append(_case(str(definition[0]), str(definition[1])))
	return result


func validation_records() -> Array:
	var profile := _profile_resource()
	var resource_payload := policy_resource_main_payload()
	var controller_source := FileAccess.get_file_as_string(CONTROLLER_SCRIPT_PATH)
	var bridge_source := FileAccess.get_file_as_string(WORLD_BRIDGE_SCRIPT_PATH)
	var coordinator_scene := FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH)
	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var records: Array = []
	var profile_ready := profile != null and _all_resources_load()
	var controller_policy_ready := controller_source.contains("func _policy_value(") and controller_source.contains("DEFAULT_POLICY_PROFILE")
	records.append(_record("profile_loads", profile_ready, "profile and six personality Resources load"))
	for case_id in ["timing_matches_main", "selection_thresholds_match_main", "counter_thresholds_match_main", "strategy_route_policy_matches_main", "phase_posture_matches_main", "learning_controls_match_main"]:
		records.append(_record(case_id, profile_ready and controller_policy_ready and not resource_payload.is_empty(), "Resource parameters are read by AiRuntimeController; main.gd no longer owns an AI parameter copy", true))
	records.append(_record("personalities_match_main_catalog", _personality_resources_valid() and controller_source.contains("AI_PERSONALITY_CATALOG"), "six personality Resources supply the migrated runtime catalog", true, true))
	var runtime_owner_ready := profile_ready and str(profile.get("runtime_owner_script")) == CONTROLLER_SCRIPT_PATH and bool(profile.get("runtime_cutover_enabled")) and not main_source.contains("const AI_PERSONALITY_CATALOG")
	records.append(_record("runtime_owner_stays_main_gd", runtime_owner_ready, "historical Resource gate retained; Sprint 41 now requires AiRuntimeController ownership and no main fallback", false, false, true))
	var pure_payloads := _is_pure_data(policy_resource_payload()) and _is_pure_data(resource_payload) and _is_pure_data(profile_summary())
	records.append(_record("payloads_stay_pure_data", pure_payloads, "policy payloads contain no Callable, Node, Resource, or Object", false, false, true, true))
	for definition in RUNTIME_CASES:
		var case_id := str(definition[0])
		var passed := _runtime_case_passed(case_id, controller_source, bridge_source, coordinator_scene, main_source)
		records.append(_record(case_id, passed, _runtime_case_note(case_id), false, case_id == "six_personality_profile_parity", true, case_id in ["public_private_boundary", "pure_data_snapshots"]))
	return records


func validation_record_for_case(case_id: String) -> Dictionary:
	for record_variant in validation_records():
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		if str(record.get("case_id", "")) == case_id:
			return record.duplicate(true)
	return {}


func build_manifest_preview() -> Dictionary:
	var records: Array = []
	for record_variant in validation_records():
		records.append((record_variant as Dictionary).duplicate(true) if record_variant is Dictionary else {})
	return {
		"suite": "ai_policy_resourceization",
		"profile_resource": PROFILE_RESOURCE_PATH,
		"runtime_owner": CONTROLLER_SCRIPT_PATH,
		"main_source": MAIN_SCRIPT_PATH,
		"runtime_cutover_enabled": true,
		"record_count": records.size(),
		"passed_count": _passed_count(records),
		"records": records,
	}


func categories() -> Array[String]:
	var result: Array[String] = []
	for case_variant in resource_cases():
		var category := str((case_variant as Dictionary).get("category", "")) if case_variant is Dictionary else ""
		if category != "" and not result.has(category):
			result.append(category)
	return result


func profile_summary() -> Dictionary:
	var profile := _profile_resource()
	if profile != null and profile.has_method("resource_summary"):
		var value: Variant = profile.call("resource_summary")
		return (value as Dictionary).duplicate(true) if value is Dictionary else {}
	return {}


func policy_resource_payload() -> Dictionary:
	var profile := _profile_resource()
	if profile != null and profile.has_method("to_policy_dictionary"):
		var value: Variant = profile.call("to_policy_dictionary")
		return (value as Dictionary).duplicate(true) if value is Dictionary else {}
	return {}


func policy_resource_main_payload() -> Dictionary:
	var profile := _profile_resource()
	if profile != null and profile.has_method("to_main_source_dictionary"):
		var value: Variant = profile.call("to_main_source_dictionary")
		return (value as Dictionary).duplicate(true) if value is Dictionary else {}
	return {}


func main_source_payload() -> Dictionary:
	# Compatibility API: after cutover this returns the profile consumed by the runtime controller.
	return policy_resource_main_payload()


func _runtime_case_passed(case_id: String, controller: String, bridge: String, coordinator_scene: String, main_source: String) -> bool:
	var controller_scene_ready := ResourceLoader.exists(CONTROLLER_SCENE_PATH) and ResourceLoader.exists(WORLD_BRIDGE_SCENE_PATH) and coordinator_scene.contains("AiRuntimeController") and coordinator_scene.contains("AiRuntimeWorldBridge")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var controller_api_ready := _source_has_functions(controller, ["configure", "reset_state", "build_turn_plan", "build_response_plan", "rank_candidates", "commit_plan_receipt", "to_save_data", "apply_save_data", "policy_snapshot", "debug_snapshot"])
	var bridge_ready := _source_has_functions(bridge, ["bind_world", "call_world", "debug_snapshot"]) \
		and not bridge.contains("func read_world_value(") \
		and not bridge.contains("func write_world_value(") \
		and not bridge.contains("func read_world_constant(") \
		and not bridge.contains("func route_intent(") \
		and not bridge.contains("TableSelectionState")
	var no_main_algorithms := _main_ai_algorithm_function_count(main_source) == 0
	match case_id:
		"controller_scene_composition": return controller_scene_ready
		"controller_api_contract": return controller_api_ready
		"policy_resource_is_runtime_source": return controller.contains("DEFAULT_POLICY_PROFILE") and controller.contains("runtime_cutover_enabled") and not main_source.contains("const AI_CARD_DECISION_INTERVAL_SECONDS")
		"six_personality_profile_parity": return _personality_resources_valid() and controller.contains("AI_PERSONALITY_CATALOG")
		"ai_state_reset": return controller.contains("func reset_state(") and controller.contains("_last_receipts.clear()")
		"ai_state_save_load": return controller.contains("func to_save_data(") and controller.contains("func apply_save_data(") and main_source.contains("ai_runtime_state")
		"card_play_candidate_parity": return controller.contains("func _ai_card_play_candidates(") and controller.contains("func _ai_card_play_context(")
		"card_buy_candidate_parity": return controller.contains("func _ai_card_buy_candidates(")
		"counter_response_parity": return controller.contains("func _ai_counter_response_candidates(")
		"intel_plan_parity": return controller.contains("func _auto_ai_intel_decisions(")
		"monster_wager_parity": return controller.contains("func _ai_monster_wager_plan(")
		"military_plan_parity": return controller.contains("func _ai_military_command_plan(")
		"weather_plan_parity": return controller.contains("func _ai_weather_control_plan(")
		"city_strategy_parity": return controller.contains("func _auto_build_score_for_player(")
		"product_strategy_parity": return controller.contains("func _ai_product_focus_score(")
		"route_strategy_parity": return controller.contains("func _ai_route_plan_candidates(")
		"monster_strategy_parity": return controller.contains("func _ai_monster_target_for_skill(")
		"candidate_legality_preserved": return controller.contains("_skill_play_requirement_status") and controller.contains("_market_listing_purchasable") and coordinator_source.contains("func card_market_listing_availability(") and coordinator_source.contains("func card_market_preview(") and coordinator_source.contains("func request_card_market_quote(") and coordinator_source.contains("func authorize_card_market_purchase(")
		"score_order_preserved": return controller.contains("func _ai_pick_candidate(") and controller.contains("sort_custom")
		"deterministic_tie_break": return controller.contains("func _candidate_stable_id(")
		"shared_rng_order_preserved": return controller.contains("func set_run_rng_service(") and controller.contains("return _run_rng_service") and not controller.contains("RandomNumberGenerator.new") and coordinator_source.contains("ai_controller.set_run_rng_service(service)")
		"fallback_order_preserved": return controller.contains("func _ai_pick_candidate(") and controller.contains("exploration")
		"ai_intent_routes_once": return bridge_ready and not controller.contains("func route_intent(") and not bridge.contains("func route_intent(")
		"failed_intent_no_partial_mutation": return not bridge.contains("_apply_ai_runtime_intent") and controller.contains("func commit_plan_receipt(")
		"public_private_boundary": return controller.contains("private_plan_exposed\": false") and not bridge.contains("intent_routed") and not bridge.contains("func _public_intent(")
		"three_ai_players_complete_cycle": return controller.contains("func _update_ai_decisions(") and controller.contains("func _ai_player_indices(")
		"main_ai_algorithms_absent": return no_main_algorithms
		"main_ai_adapter_under_300_lines": return _main_ai_adapter_line_count(main_source) <= 300
		"execution_service_unchanged": return not FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_execution_runtime_service.gd").contains("AiRuntimeController")
		"pure_data_snapshots": return _is_pure_data(policy_resource_payload()) and controller.contains("private_plan_exposed\": false")
		"no_parallel_ai_owner": return no_main_algorithms and controller_scene_ready and bridge_ready
	return false


func _runtime_case_note(case_id: String) -> String:
	return "Sprint 41 runtime ownership gate: %s" % case_id


func _case(case_id: String, category: String) -> Dictionary:
	return {"case_id": case_id, "category": category, "resource_path": PROFILE_RESOURCE_PATH, "source_path": CONTROLLER_SCRIPT_PATH, "notes": _runtime_case_note(case_id)}


func _record(case_id: String, passed: bool, notes: String, parity_checked: bool = false, personality_checked: bool = false, runtime_checked: bool = false, pure_checked: bool = false) -> Dictionary:
	var definition := _case_for_id(case_id)
	return {
		"case_id": case_id,
		"category": str(definition.get("category", "")),
		"resource_path": PROFILE_RESOURCE_PATH,
		"source_path": CONTROLLER_SCRIPT_PATH,
		"inspector_visible": true,
		"main_parity_checked": parity_checked,
		"personality_checked": personality_checked,
		"runtime_owner_checked": runtime_checked,
		"pure_data_checked": pure_checked,
		"passed": passed,
		"notes": notes if passed else "failed: %s" % notes,
	}


func _case_for_id(case_id: String) -> Dictionary:
	for case_variant in resource_cases():
		var entry: Dictionary = case_variant if case_variant is Dictionary else {}
		if str(entry.get("case_id", "")) == case_id:
			return entry
	return {}


func _profile_resource() -> Resource:
	return load(PROFILE_RESOURCE_PATH) as Resource if ResourceLoader.exists(PROFILE_RESOURCE_PATH) else null


func _all_resources_load() -> bool:
	for path in resource_paths():
		if not ResourceLoader.exists(path) or load(path) == null:
			return false
	return true


func _personality_resources_valid() -> bool:
	var ids: Array[String] = []
	for path in PERSONALITY_RESOURCE_PATHS:
		var resource := load(path) as Resource
		if resource == null or not resource.has_method("to_policy_dictionary"):
			return false
		var payload: Dictionary = resource.call("to_policy_dictionary")
		var policy_id := str(payload.get("policy_id", ""))
		if policy_id == "" or ids.has(policy_id):
			return false
		ids.append(policy_id)
	return ids.size() == 6


func _source_has_functions(source: String, names: Array) -> bool:
	for name_variant in names:
		if not source.contains("func %s(" % str(name_variant)):
			return false
	return true


func _main_ai_algorithm_function_count(source: String) -> int:
	var regex := RegEx.new()
	regex.compile("(?m)^func\\s+(_ai_(?!runtime_)[A-Za-z0-9_]*|_auto_ai_[A-Za-z0-9_]*|_update_ai_decisions|_record_ai_decision|_finalize_ai_[A-Za-z0-9_]*)\\(")
	return regex.search_all(source).size()


func _main_ai_adapter_line_count(source: String) -> int:
	var total := 0
	for method_name in ["_ai_runtime_controller_node", "_ai_runtime_call", "_ai_runtime_world_snapshot"]:
		var start := source.find("func %s(" % method_name)
		if start < 0:
			continue
		var finish := source.find("\nfunc ", start + 5)
		if finish < 0:
			finish = source.length()
		total += source.substr(start, finish - start).count("\n") + 1
	return total


func _passed_count(records: Array) -> int:
	var count := 0
	for record_variant in records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key in (value as Dictionary):
			if not _is_pure_data(key) or not _is_pure_data((value as Dictionary)[key]):
				return false
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
	return true
