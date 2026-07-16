extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const QA_SAVE_PATH := "user://test_runs/ai_card_phase_counter_owner.save"
const PRIVATE_HAND_SENTINEL := "J_PRIVATE_HUMAN_HAND_SENTINEL"
const PRIVATE_DISCARD_SENTINEL := "J_PRIVATE_HUMAN_DISCARD_SENTINEL"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_qa_save()
	var main := MAIN_SCENE.instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var save := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	_expect(save != null and bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "fixture isolates the production save path")
	root.add_child(main)
	await _wait_frames(3)
	_expect(main.has_method("_start_scenario_from_menu"), "production Main script is loaded before the owner fixture starts")
	if not main.has_method("_start_scenario_from_menu"):
		main.queue_free()
		await _wait_frames(2)
		_remove_qa_save()
		_finish()
		return
	main.call("_start_scenario_from_menu", "first_table")
	await _wait_frames(5)

	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var ai := coordinator.get_node_or_null("AiRuntimeController") if coordinator != null else null
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") if coordinator != null else null
	var timing := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/CardResolutionRuntimeController")
	_expect(coordinator != null and ai != null and queue != null and timing != null, "real Main composes AI, queue and timing owners")
	if coordinator != null and ai != null and queue != null and timing != null:
		_test_anonymous_simultaneous_card_policy(main, ai, queue, timing)
		_test_phase_counter_response(main, ai, queue, timing)

	main.queue_free()
	await _wait_frames(3)
	_remove_qa_save()
	_expect(not FileAccess.file_exists(QA_SAVE_PATH), "focused owner gate leaves no QA save residue")
	_finish()


func _test_anonymous_simultaneous_card_policy(main: Node, ai: Node, queue: Node, timing: Node) -> void:
	queue.call("reset_state")
	timing.call("reset_state")
	var players := _players(main)
	_expect(players.size() >= 3, "first-table fixture includes two AI opponents")
	if players.size() < 3:
		return
	for player_index in [1, 2]:
		var player := (players[player_index] as Dictionary).duplicate(true)
		player["action_cooldown"] = 0.0
		var card: Dictionary = main.call("_make_skill", "轨道融资1")
		card.erase("machine")
		card.erase("player")
		player["slots"] = [card]
		players[player_index] = player
	main.set("players", players)
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = _first_alive_district(main)
	main.set("card_resolution_force_duration", 5.0)
	main.set("card_resolution_force_simultaneous_window", 0.5)
	ai.set("ai_card_decision_enabled", true)

	var candidates_one: Array = ai.call("_ai_card_play_candidates", 1)
	var candidates_two: Array = ai.call("_ai_card_play_candidates", 2)
	_expect(_has_anonymous_card_candidate(candidates_one) and _has_anonymous_card_candidate(candidates_two), "two AI seats expose live anonymous card-play candidates")
	var first_result := str(ai.call("_ai_execute_card_turn", 1, true))
	var second_result := str(ai.call("_ai_execute_card_turn", 2, true))
	var raw_current: Array = queue.call("current_queue")
	var public_before_bid: Dictionary = queue.call("public_snapshot")
	_expect(first_result == "play" and second_result == "play", "two AI seats commit card-play decisions through the live owner")
	_expect(raw_current.size() == 2 and int(public_before_bid.get("current_count", 0)) == 2, "simultaneous group owns two public-bid candidates")
	_expect(_different_players(raw_current) and _all_entries_anonymous(public_before_bid.get("current", []) as Array), "simultaneous candidates retain private bindings while public entries stay anonymous")
	_expect(not _contains_private_ai_metadata(public_before_bid), "public queue projection strips AI scores, reasons and player bindings")

	timing.call("begin_group_window", -1.0, 1, 3)
	timing.set("simultaneous_timer", 11.0)
	var commands: Array = timing.call("tick", 2.0, {
		"queue_empty": false,
		"active_present": false,
		"active_counterable": false,
		"active_player_indices": [0, 1, 2],
		"lock_duration": 5.0,
		"public_bid_duration": 5.0,
	})
	_expect(str(timing.call("current_phase", {"queue_empty": false, "active_present": false})) == "public_bid", "real timing owner advances the simultaneous roster into public bid")
	_expect(_has_transition(commands, "enter_public_bid"), "public-bid transition is emitted once for the queued AI roster")


func _test_phase_counter_response(main: Node, ai: Node, queue: Node, timing: Node) -> void:
	queue.call("reset_state")
	timing.call("reset_state")
	var own_index := _first_empty_land_district(main, [])
	var rival_index := _first_empty_land_district(main, [own_index])
	_expect(own_index >= 0 and rival_index >= 0, "counter fixture finds two live land districts")
	if own_index < 0 or rival_index < 0:
		return
	var districts: Array = (main.get("districts") as Array).duplicate(true)
	var own_district := (districts[own_index] as Dictionary).duplicate(true)
	var own_city := _city_fixture(1, "J反制自城", 840, 2)
	own_district["city"] = own_city
	own_district["damage"] = 2
	own_district["panic"] = 18
	districts[own_index] = own_district
	var rival_district := (districts[rival_index] as Dictionary).duplicate(true)
	rival_district["city"] = _city_fixture(2, "J反制竞城", 420, 0)
	districts[rival_index] = rival_district
	main.set("districts", districts)
	_expect(not (main.call("_district_city", own_index) as Dictionary).is_empty(), "counter fixture exposes the AI defended city to the live owner")
	_expect(not (main.call("_district_city", rival_index) as Dictionary).is_empty(), "counter fixture exposes the rival city to the live owner")

	var players := _players(main)
	var ai_player := (players[1] as Dictionary).duplicate(true)
	ai_player["action_cooldown"] = 0.0
	var counter_card: Dictionary = main.call("_make_skill", "相位否决1")
	# This fixture isolates phase response from the separately-owned GDP-share gate.
	counter_card["play_requirement_kind"] = "none"
	counter_card["play_region_scope"] = ""
	counter_card["play_region_gdp_share_required"] = 0
	ai_player["slots"] = [counter_card]
	players[1] = ai_player
	var human := (players[0] as Dictionary).duplicate(true)
	human["slots"] = [{"name": PRIVATE_HAND_SENTINEL, "kind": "private_test_only"}]
	human["discard"] = [{"name": PRIVATE_DISCARD_SENTINEL, "kind": "private_test_only"}]
	players[0] = human
	main.set("players", players)

	var active_entry := {
		"player_index": 2,
		"slot_index": -1,
		"selected_district": own_index,
		"selected_trade_product": "环晶电池",
		"queued_order": 99001,
		"resolution_id": 99001,
		"window_sequence": 4,
		"group_id": "group_4_2",
		"group_order": 1,
		"group_size": 1,
		"public_owner_revealed": false,
		"public_owner_label": "",
		"skill": main.call("_make_skill", "轨道齐射1"),
	}
	queue.call("replace_active_entry", active_entry)
	timing.call("begin_counter", 5.0)
	ai.set("ai_card_decision_enabled", true)

	var plan_before: Dictionary = ai.call("build_response_plan", "counter_response", 1, {})
	var players_changed := _players(main)
	var changed_human := (players_changed[0] as Dictionary).duplicate(true)
	changed_human["slots"] = [{"name": "%s_CHANGED" % PRIVATE_HAND_SENTINEL, "kind": "private_test_only"}]
	changed_human["discard"] = [{"name": "%s_CHANGED" % PRIVATE_DISCARD_SENTINEL, "kind": "private_test_only"}]
	players_changed[0] = changed_human
	main.set("players", players_changed)
	var plan_after: Dictionary = ai.call("build_response_plan", "counter_response", 1, {})
	_expect(bool(plan_before.get("planned", false)) and plan_before == plan_after, "phase-response plan is invariant to another player's private hand and discard")
	_expect(str((plan_before.get("selected", {}) as Dictionary).get("policy_kind", "")) == "counter_response", "AI owner selects the live counter-response policy")

	var acted := int(ai.call("_auto_ai_counter_responses", true))
	var raw_next: Array = queue.call("next_queue")
	var public_next: Dictionary = queue.call("public_snapshot")
	var raw_entry: Dictionary = raw_next[0] as Dictionary if not raw_next.is_empty() and raw_next[0] is Dictionary else {}
	_expect(acted == 1 and raw_next.size() == 1 and bool(raw_entry.get("ai_counter_response", false)), "AI queues one counter into the owner next-batch lane")
	_expect(int(raw_entry.get("counter_target_resolution_id", -1)) == 99001 and int(raw_entry.get("counter_threat_score", 0)) > 0, "private owner entry binds the counter to the active resolution")
	_expect(int(public_next.get("next_count", 0)) == 1 and _all_entries_anonymous(public_next.get("next", []) as Array), "public projection exposes the waiting anonymous counter without its owner")
	_expect(not _contains_hidden_counter_metadata(public_next), "counter score, reason, source conversion and target binding stay out of the public projection")
	_expect(not _contains_sentinel(plan_before) and not _contains_sentinel(public_next), "AI plan and public queue never echo private human hand sentinels")


func _players(main: Node) -> Array:
	var value: Variant = main.get("players")
	return (value as Array).duplicate(true) if value is Array else []


func _first_alive_district(main: Node) -> int:
	var districts: Array = main.get("districts") if main.get("districts") is Array else []
	for index in range(districts.size()):
		if districts[index] is Dictionary and not bool((districts[index] as Dictionary).get("destroyed", false)):
			return index
	return -1


func _first_empty_land_district(main: Node, excluded: Array) -> int:
	var districts: Array = main.get("districts") if main.get("districts") is Array else []
	for index in range(districts.size()):
		if excluded.has(index) or not (districts[index] is Dictionary):
			continue
		var district: Dictionary = districts[index]
		if str(district.get("terrain", "land")) == "land" and not bool(district.get("destroyed", false)) and (district.get("city", {}) as Dictionary).is_empty():
			return index
	return -1


func _city_fixture(owner: int, label: String, last_income: int, route_damage: int) -> Dictionary:
	return {
		"active": true,
		"name": label,
		"owner": owner,
		"last_income": last_income,
		"trade_route_damage": route_damage,
		"trade_disrupted_routes": route_damage,
		"products": [{"name": "轨迹墨水", "level": 1}],
		"demands": [{"name": "环晶电池", "level": 1}],
		"warehouses": [],
	}


func _has_anonymous_card_candidate(candidates: Array) -> bool:
	for candidate_variant in candidates:
		if candidate_variant is Dictionary and str((candidate_variant as Dictionary).get("action", "")) == "出牌":
			return true
	return false


func _different_players(entries: Array) -> bool:
	var players := {}
	for entry_variant in entries:
		if entry_variant is Dictionary:
			players[int((entry_variant as Dictionary).get("player_index", -1))] = true
	return players.has(1) and players.has(2)


func _all_entries_anonymous(entries: Array) -> bool:
	if entries.is_empty():
		return false
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			return false
		var entry: Dictionary = entry_variant
		if bool(entry.get("public_owner_revealed", true)) or str(entry.get("public_owner_label", "hidden")) != "":
			return false
	return true


func _contains_private_ai_metadata(value: Variant) -> bool:
	return _contains_any_key(value, ["player_index", "ai_reason", "ai_utility_score", "score", "hand", "discard"])


func _contains_hidden_counter_metadata(value: Variant) -> bool:
	return _contains_any_key(value, [
		"ai_counter_response",
		"counter_target_resolution_id",
		"counter_target_card",
		"counter_strength",
		"counter_threat_score",
		"counter_opportunity_cost",
		"counter_reason_key",
		"counter_source_card",
		"counter_converted_monster",
	])


func _contains_any_key(value: Variant, forbidden: Array) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if forbidden.has(str(key_variant)) or _contains_any_key((value as Dictionary)[key_variant], forbidden):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_any_key(item, forbidden):
				return true
	return false


func _contains_sentinel(value: Variant) -> bool:
	return str(value).contains(PRIVATE_HAND_SENTINEL) or str(value).contains(PRIVATE_DISCARD_SENTINEL)


func _has_transition(commands: Array, transition: String) -> bool:
	for command_variant in commands:
		if command_variant is Dictionary and str((command_variant as Dictionary).get("transition", "")) == transition:
			return true
	return false


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _remove_qa_save() -> void:
	var absolute := ProjectSettings.globalize_path(QA_SAVE_PATH)
	if FileAccess.file_exists(QA_SAVE_PATH):
		DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("AI CARD PHASE COUNTER OWNER: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("AI_CARD_PHASE_COUNTER_OWNER_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	push_error("AI card phase counter owner test failed:\n- %s" % "\n- ".join(_failures))
	print("AI_CARD_PHASE_COUNTER_OWNER_TEST|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)
