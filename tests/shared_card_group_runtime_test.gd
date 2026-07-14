extends SceneTree

const RULESET_BRIDGE_SCENE := preload("res://scenes/runtime/RulesetRuntimeBridge.tscn")
const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const WINDOW_SCENE := preload("res://scenes/runtime/CardResolutionRuntimeController.tscn")

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var ruleset_bridge := RULESET_BRIDGE_SCENE.instantiate()
	var coordinator := COORDINATOR_SCENE.instantiate()
	host.add_child(ruleset_bridge)
	host.add_child(coordinator)
	coordinator.call("configure", ruleset_bridge.call("active_profile"))
	var rules: Dictionary = coordinator.call("card_group_runtime_rules")
	_expect(str((ruleset_bridge.call("active_profile") as Dictionary).get("ruleset_id", "")) == "v0.4", "global production Ruleset bridge remains the legacy compatibility namespace")
	_expect(_cadence_matches(rules), "Coordinator exposes the sole v0.6 30/20/5/5 and opening 45/35/5/5 cadence")
	_expect(int(rules.get("ordinary_card_limit", 0)) == 1 and int(rules.get("maximum_with_explicit_capability", 0)) == 3, "production rules expose ordinary one and explicit hard cap three")

	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService")
	_expect(queue != null and bool((queue.call("debug_snapshot") as Dictionary).get("service_ready", false)), "real Coordinator statically owns the configured Queue service")
	if queue == null:
		host.free()
		_finish()
		return
	queue.call("reset_state")
	var first := _submit(queue, 0, 0, _facts(0, 45.0), {})
	_expect(bool((first.get("commit", {}) as Dictionary).get("committed", false)), "first ordinary card starts sequence zero")
	var forged := _submit(queue, 0, 1, _facts(0, 44.0), {"actor_id": "player.0", "group_card_limit": 3, "max_cards": 3})
	_expect(str((forged.get("plan", {}) as Dictionary).get("reason", "")) == "group_full" and int((forged.get("plan", {}) as Dictionary).get("card_limit", 0)) == 1, "request-provided limit cannot authorize a second ordinary card")
	var capability_facts := _facts(0, 44.0)
	capability_facts.merge(_capability_facts(0, "player.0", 0, 2, 7), true)
	var second := _submit(queue, 0, 1, capability_facts, {"actor_id": "player.0", "max_cards": 3})
	var third := _submit(queue, 0, 2, capability_facts, {"actor_id": "player.0", "max_cards": 3})
	_expect(bool((second.get("commit", {}) as Dictionary).get("committed", false)) and bool((third.get("commit", {}) as Dictionary).get("committed", false)), "authoritative window-bound capability permits cards two and three")
	var fourth := _submit(queue, 0, 3, capability_facts, {"actor_id": "player.0", "max_cards": 4})
	_expect(str((fourth.get("plan", {}) as Dictionary).get("reason", "")) == "group_full" and int((fourth.get("plan", {}) as Dictionary).get("card_limit", 0)) == 3, "authoritative capability cannot exceed the hard cap")
	var public_bid_submit := _submit(queue, 1, 0, _facts(0, 10.0), {})
	_expect(str((public_bid_submit.get("plan", {}) as Dictionary).get("reason", "")) == "public_bid_phase", "public bid rejects new ordinary submissions")
	var queue_debug: Dictionary = queue.call("debug_snapshot")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(not bool(queue_debug.get("cash_authority", true)) and not bool(queue_debug.get("priority_bid_authority", true)) and main_source.contains("func _apply_card_group_wager_pool_receipt"), "cadence cutover does not move wager-pool receipt or cash ownership into Queue")

	var window := WINDOW_SCENE.instantiate()
	host.add_child(window)
	window.call("configure", rules)
	for sequence in range(3):
		window.call("reset_state")
		window.call("begin_group_window", -1.0, 0, sequence)
		var opening: Dictionary = window.call("cadence_snapshot", sequence)
		_expect(int(opening.get("total_seconds", 0)) == 45 and int(opening.get("planning_seconds", 0)) == 35, "opening sequence %d consumes 45/35/5/5" % sequence)
	window.call("reset_state")
	window.call("begin_group_window", -1.0, 0, 3)
	var standard: Dictionary = window.call("cadence_snapshot", 3)
	_expect(int(standard.get("total_seconds", 0)) == 30 and int(standard.get("planning_seconds", 0)) == 20, "sequence three consumes standard 30/20/5/5")

	var active_players := [0, 1]
	_set_all_ready(window, active_players)
	var ready_bid: Array = window.call("tick", 0.0, _window_facts(active_players))
	_expect(_has_transition(ready_bid, "all_ready_public_bid") and str(window.call("current_phase", _window_facts(active_players))) == "public_bid", "planning ready advances only to public bid")
	_set_all_ready(window, active_players)
	var ready_lock: Array = window.call("tick", 0.0, _window_facts(active_players))
	_expect(_has_transition(ready_lock, "all_ready_lock") and str(window.call("current_phase", _window_facts(active_players))) == "lock", "public-bid ready advances only to lock")
	_set_all_ready(window, active_players)
	var ready_close: Array = window.call("tick", 0.0, _window_facts(active_players))
	_expect(_has_transition(ready_close, "all_ready_lock_batch") and _has_transition(ready_close, "lock_batch"), "lock ready performs the only early batch lock")

	host.free()
	_finish()


func _cadence_matches(rules: Dictionary) -> bool:
	return int(rules.get("group_seconds", 0)) == 30 \
		and int(rules.get("planning_seconds", 0)) == 20 \
		and int(rules.get("public_bid_seconds", 0)) == 5 \
		and int(rules.get("lock_seconds", 0)) == 5 \
		and int(rules.get("opening_extended_windows", 0)) == 3 \
		and int(rules.get("opening_group_seconds", 0)) == 45 \
		and int(rules.get("opening_planning_seconds", 0)) == 35


func _submit(queue: Node, player_index: int, slot_index: int, facts: Dictionary, overrides: Dictionary) -> Dictionary:
	var request := {
		"player_index": player_index,
		"slot_index": slot_index,
		"already_queued": false,
		"play_cash_cost_cents": 0,
		"financial_margin_cents": 0,
		"available_cash_cents": 100000,
		"skill": {"name": "qa.card.%d.%d" % [player_index, slot_index], "kind": "qa", "persistent": true},
	}
	request.merge(overrides, true)
	var plan: Dictionary = queue.call("plan_submission", request, facts)
	var commit: Dictionary = {}
	if bool(plan.get("accepted", false)):
		commit = queue.call("commit_submission", plan, {
			"authorized": true,
			"inventory_committed": true,
			"play_cost_authorized": true,
			"financial_margin_authorized": true,
			"asset_authorized": true,
		})
	return {"plan": plan, "commit": commit}


func _facts(window_sequence: int, remaining: float) -> Dictionary:
	return {
		"player_count": 4,
		"batch_locked": false,
		"counter_window_active": false,
		"simultaneous_timer": remaining,
		"lock_duration": 5.0,
		"public_bid_duration": 5.0,
		"window_sequence": window_sequence,
		"reference_player": 3,
	}


func _capability_facts(player_index: int, actor_id: String, window_sequence: int, bonus_limit: int, revision: int) -> Dictionary:
	return {
		"extra_submission_capability_authoritative": true,
		"extra_submission_capability_owner_revision": revision,
		"extra_submission_capability": {
			"actor_id": actor_id,
			"player_index": player_index,
			"window_sequence": window_sequence,
			"owner_revision": revision,
			"capability_id": "qa.extra_submission.%s" % actor_id,
			"base_limit": 1,
			"bonus_limit": bonus_limit,
			"effective_limit": clampi(1 + bonus_limit, 1, 3),
			"activation_window_sequence": window_sequence,
			"expiry_window_sequence": window_sequence,
			"hard_cap": 3,
		},
	}


func _set_all_ready(window: Node, players: Array) -> void:
	for player_index_variant in players:
		window.call("set_player_ready", int(player_index_variant), true, players)


func _window_facts(players: Array) -> Dictionary:
	return {"queue_empty": false, "active_present": false, "active_player_indices": players, "lock_duration": 5.0, "public_bid_duration": 5.0}


func _has_transition(commands: Array, transition: String) -> bool:
	for command_variant in commands:
		if command_variant is Dictionary and str((command_variant as Dictionary).get("transition", "")) == transition:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Shared card group runtime test passed. checks=%d" % _checks)
	else:
		push_error("Shared card group runtime test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
