extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const RUN_SEED := 900626424
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const SAVE_PATH := "GameSessionRuntimeController/GameSaveRuntimeCoordinator"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_source_contract()
	var main := MAIN_SCENE.instantiate()
	var coordinator := main.get_node_or_null(COORDINATOR_PATH)
	var save_coordinator := coordinator.get_node_or_null(SAVE_PATH) if coordinator != null else null
	_expect(save_coordinator != null and bool(save_coordinator.call(
		"set_qa_default_save_path_override",
		"user://test_runs/first_run_coach_purchase_recovery/run.save"
	)), "QA save path is isolated before Main enters the tree")
	main.visible = false
	root.add_child(main)
	await _frames(8)

	var setup: Dictionary = main.call("_first_run_recommended_setup")
	main.set("configured_player_count", 4)
	main.set("configured_ai_player_count", 3)
	main.set("configured_role_indices", (setup.get("role_indices", []) as Array).duplicate(true))
	main.set("configured_starter_monster_indices", (setup.get("starter_monster_indices", []) as Array).duplicate(true))
	(main.get("rng") as RandomNumberGenerator).seed = RUN_SEED
	main.call("_start_scenario_from_menu", "first_table")
	await _frames(10)
	main.set_process(false)

	_expect(str(main.call("_active_runtime_scenario_id")) == "first_table", "focused run uses the authored first_table scenario")
	if not main.has_method("_first_run_coach_rack_purchase_target") or not main.has_method("_first_run_coach_quote_for_target"):
		_expect(false, "production exposes the stable-rack Coach target and quote helpers")
		await _finish(main, save_coordinator)
		return
	_expect(bool(main.call("_activate_first_run_coach_action", "coach_select_district")), "coach selects the current recommended district")
	_expect(bool(main.call("_activate_first_run_coach_action", "coach_open_rack")), "coach opens that district's live public rack")
	var player_index := int(main.call("_first_run_coach_player_index"))
	var district_index := int(main.get("district_supply_open_district"))
	var target: Dictionary = main.call("_first_run_coach_rack_purchase_target", player_index, district_index)
	_expect(not target.is_empty(), "coach resolves one stable recommendation from the opened public rack")
	_expect(int(target.get("district_index", -1)) == district_index, "recommendation stays bound to the opened district")
	var listing: Dictionary = target.get("listing", {}) if target.get("listing", {}) is Dictionary else {}
	_expect(
		str(target.get("card_id", "")) == str(listing.get("card_id", ""))
			and str(target.get("item_id", "")) == str(listing.get("item_id", ""))
			and str(target.get("supply_revision", "")) == str(listing.get("supply_revision", "")),
		"recommendation binds card, item and supply revision before quoting"
	)

	var quote_once: Dictionary = main.call("_first_run_coach_quote_for_target", player_index, target)
	var quote_twice: Dictionary = main.call("_first_run_coach_quote_for_target", player_index, target)
	var quote_id := str(quote_once.get("quote_id", ""))
	_expect(
		not quote_id.is_empty()
			and bool(quote_once.get("quote_active", false))
			and quote_id == str(quote_twice.get("quote_id", "")),
		"coach obtains one five-second quote and reuses it while active"
	)

	var runtime_players: Array = main.get("players") if main.get("players") is Array else []
	var runtime_player: Dictionary = runtime_players[player_index] if player_index >= 0 and player_index < runtime_players.size() and runtime_players[player_index] is Dictionary else {}
	var actor_id := str(runtime_player.get("actor_id", "player.%d" % player_index))
	var player_before: Dictionary = coordinator.call("v06_card_player_snapshot", actor_id)
	var rack_before: Dictionary = coordinator.call("region_supply_public_rack", str(target.get("region_id", "")))
	var slots_before := _region_slots(rack_before)
	var bought := bool(main.call("_activate_first_run_coach_action", "coach_buy_card"))
	await _frames(4)
	var player_after: Dictionary = coordinator.call("v06_card_player_snapshot", actor_id)
	var rack_after: Dictionary = coordinator.call("region_supply_public_rack", str(target.get("region_id", "")))
	var slots_after := _region_slots(rack_after)
	var slot_index := int(target.get("slot_index", -1))
	var scenario_state_variant: Variant = main.call("_runtime_scenario_state")
	var scenario_state: Dictionary = scenario_state_variant if scenario_state_variant is Dictionary else {}
	var completed: Dictionary = scenario_state.get("completed_signals", {}) if scenario_state.get("completed_signals", {}) is Dictionary else {}
	if not bought:
		print("FIRST_RUN_COACH_DIAG|target=%s|quote=%s|logs=%s" % [
			JSON.stringify(target),
			JSON.stringify(quote_once),
			JSON.stringify(main.get("log_lines")),
		])
	_expect(bought, "one Coach Buy action commits the currently recommended rack card")
	_expect(
		int(player_after.get("card_purchase_count", 0)) == int(player_before.get("card_purchase_count", 0)) + 1,
		"successful Coach purchase enters the authoritative player inventory exactly once"
	)
	_expect(bool(completed.get("card_bought", false)), "successful Coach purchase emits the real card_bought scenario signal")
	_expect(
		slot_index >= 0
			and slot_index < slots_before.size()
			and slot_index < slots_after.size()
			and str((slots_before[slot_index] as Dictionary).get("item_id", "")) == str(target.get("item_id", ""))
			and str((slots_after[slot_index] as Dictionary).get("item_id", "")) != str(target.get("item_id", "")),
		"the purchased stable listing is replaced only after the real transaction commits"
	)

	await _finish(main, save_coordinator)


func _verify_source_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var action_source := _function_source(source, "_activate_first_run_coach_action")
	var target_source := _function_source(source, "_first_run_coach_rack_purchase_target")
	var quote_source := _function_source(source, "_first_run_coach_quote_for_target")
	_expect(
		action_source.contains("_first_run_coach_rack_purchase_target")
			and action_source.contains("_first_run_coach_quote_for_target")
			and action_source.contains("_buy_card_for_player_from_district"),
		"Coach Buy chains stable recommendation, quote and existing purchase entry"
	)
	_expect(
		not action_source.contains("_can_buy_card_from_district")
			and not target_source.contains("v06_first_table_facility")
			and not quote_source.contains("v06_first_table_facility"),
		"Coach Buy has no deleted eligibility helper or fixed facility-market dependency"
	)


func _region_slots(snapshot: Dictionary) -> Array:
	var regions: Array = snapshot.get("regions", []) if snapshot.get("regions", []) is Array else []
	if regions.is_empty() or not (regions[0] is Dictionary):
		return []
	var slots_variant: Variant = (regions[0] as Dictionary).get("slots", [])
	return (slots_variant as Array).duplicate(true) if slots_variant is Array else []


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var finish := source.find("\nfunc ", start + 5)
	if finish < 0:
		finish = source.length()
	return source.substr(start, finish - start)


func _finish(main: Node, save_coordinator: Node) -> void:
	if save_coordinator != null:
		save_coordinator.call("clear_qa_default_save_path_override")
	if main != null and is_instance_valid(main):
		if main.get_parent() == root:
			root.remove_child(main)
		main.free()
	await _frames(3)
	print("FIRST_RUN_COACH_PURCHASE_RECOVERY_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error(message)


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
