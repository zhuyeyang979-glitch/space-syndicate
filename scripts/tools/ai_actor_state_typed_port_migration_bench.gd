@tool
extends Node

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

var _checks := 0
var _failures: Array[String] = []
var validation_snapshot: Dictionary = {
	"status": "pending",
	"checks": 0,
	"privacy_leaks": 0,
	"partial_batch_mutations": 0,
}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	add_child(coordinator)
	await get_tree().process_frame
	var world := coordinator.world_session_state()
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var port := coordinator.get_node_or_null("AiActorStatePort") as AiActorStatePort
	var game_session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	_check(world != null and ai != null and port != null and game_session != null and rng != null, "production_composition")
	_check(port.is_ready() and bool(ai.debug_snapshot().get("typed_actor_state_bound", false)), "typed_actor_state_ready")

	ai.configure({"ruleset_id": "v0.6"})
	game_session.configure({"ruleset_id": "v0.6"}, {})
	var started := game_session.begin_session({
		"session_id": "ai-actor-state-bench",
		"scenario_id": "bench",
		"seed": 83,
		"player_count": 4,
	})
	_check(str(started.get("session_state", "")) == GameSessionRuntimeController.STATE_RUNNING, "game_session_running")
	world.restore({
		"players": [
			_player("Human", "HUMAN_PRIVATE", false, -1),
			_player("AI-A", "ACTOR_A_PRIVATE", true, 0),
			_player("AI-B", "ACTOR_B_PRIVATE", true, 1),
			_player("AI-C", "ACTOR_C_PRIVATE", true, 2, true),
		],
		"districts": [],
		"game_time": 14.0,
	}, true)
	ai._ensure_player_ai_state()
	var capability := ai.get("_ai_actor_state_capability") as AiActorStateCapability
	_check(capability != null, "opaque_capability_bound")

	var rng_before := rng.capture_plan_checkpoint()
	var world_before_queries := world.to_save_data()
	var roster := port.public_players_snapshot()
	var roster_text := JSON.stringify(roster)
	_check(port.ai_player_indices(true) == [1, 2, 3] and port.ai_player_indices(false) == [1, 2], "typed_ai_roster")
	_check(not roster_text.contains("PRIVATE") and not roster_text.contains("ai_memory") and not roster_text.contains("cash"), "public_roster_redacted")
	var actor_a := port.ai_actor_state_snapshot(capability, 1)
	var actor_a_text := JSON.stringify(actor_a)
	_check(actor_a_text.contains("ACTOR_A_PRIVATE") and not actor_a_text.contains("ACTOR_B_PRIVATE") and not actor_a_text.contains("ACTOR_C_PRIVATE"), "actor_private_isolation")
	_check(not actor_a.has("cash") and not actor_a.has("slots") and not actor_a.has("action_cooldown") and not actor_a.has("city_guesses"), "deferred_private_domains_excluded")
	_check(port.ai_actor_state_snapshot(AiActorStateCapability.new(), 1).is_empty() and port.ai_actor_state_snapshot(capability, 0).is_empty(), "forged_or_human_query_rejected")
	var capture := port.capture_ai_state_batch_receipt(capability, true)
	var forged_capture := port.capture_ai_state_batch_receipt(AiActorStateCapability.new(), true)
	var roster_checkpoint := world.to_save_data()
	world.replace_players([_player("Human-A", "HUMAN_A_PRIVATE", false, -1), _player("Human-B", "HUMAN_B_PRIVATE", false, -1)], true)
	var zero_ai_capture := port.capture_ai_state_batch_receipt(capability, true)
	var zero_ai_apply := port.apply_ai_state_batch(capability, [])
	var forged_zero_ai_apply := port.apply_ai_state_batch(AiActorStateCapability.new(), [])
	var zero_ai_saved := ai.to_save_data()
	var zero_ai_timer := ai.ai_card_decision_timer
	ai.ai_card_decision_timer += 9.0
	var zero_ai_restore := ai.apply_save_data(zero_ai_saved)
	world.apply_save_data(roster_checkpoint)
	_check(bool(capture.get("captured", false)) and (capture.get("rows", []) as Array).size() == 3 and bool(zero_ai_capture.get("captured", false)) and (zero_ai_capture.get("rows", []) as Array).is_empty() and not bool(forged_capture.get("captured", true)), "typed_capture_receipt")
	var truncated_direct_apply := port.apply_ai_state_batch(capability, [])
	_check(bool(zero_ai_apply.get("accepted", false)) and not bool(forged_zero_ai_apply.get("accepted", true)) and not bool(truncated_direct_apply.get("accepted", true)) and str(truncated_direct_apply.get("reason_code", "")) == "ai_actor_state_batch_roster_mismatch", "empty_batch_capability_and_roster_guard")
	_check(bool(zero_ai_restore.get("applied", false)) and int(zero_ai_restore.get("player_state_count", -1)) == 0 and is_equal_approx(ai.ai_card_decision_timer, zero_ai_timer), "controller_zero_ai_roundtrip")
	actor_a = port.ai_actor_state_snapshot(capability, 1)
	_check(world.to_save_data() == world_before_queries and rng.capture_plan_checkpoint() == rng_before, "query_zero_mutation_and_rng")

	var profile := (actor_a.get("ai_profile", {}) as Dictionary).duplicate(true)
	var memory := (actor_a.get("ai_memory", {}) as Dictionary).duplicate(true)
	memory["last_plan"] = "typed-bench"
	var first := port.commit_ai_state(capability, 1, {"ai_profile": profile, "ai_memory": memory}, str(actor_a.get("state_revision", "")))
	var after_first := port.ai_actor_state_snapshot(capability, 1)
	var replay := port.commit_ai_state(capability, 1, {"ai_profile": profile, "ai_memory": memory}, str(after_first.get("state_revision", "")))
	var stale := port.commit_ai_state(capability, 1, {"ai_profile": profile, "ai_memory": memory}, str(actor_a.get("state_revision", "")))
	_check(bool(first.get("accepted", false)) and bool(first.get("changed", false)), "cas_commit_once")
	_check(bool(replay.get("accepted", false)) and not bool(replay.get("changed", true)), "cas_replay_idempotent")
	_check(not bool(stale.get("accepted", true)) and str(stale.get("reason_code", "")) == "ai_actor_state_revision_changed", "stale_revision_rejected")
	var rebase_source := port.ai_actor_state_snapshot(capability, 1)
	var desired_memory := (rebase_source.get("ai_memory", {}) as Dictionary).duplicate(true)
	desired_memory["rebased_local_marker"] = "local"
	var concurrent_memory := (rebase_source.get("ai_memory", {}) as Dictionary).duplicate(true)
	concurrent_memory["concurrent_marker"] = "concurrent"
	port.commit_ai_state(capability, 1, {"ai_profile": rebase_source.get("ai_profile", {}), "ai_memory": concurrent_memory}, str(rebase_source.get("state_revision", "")))
	var rebased_commit := ai._commit_ai_memory(1, desired_memory, rebase_source)
	var rebased_memory := port.ai_actor_state_snapshot(capability, 1).get("ai_memory", {}) as Dictionary
	_check(bool(rebased_commit.get("accepted", false)) and bool(rebased_commit.get("rebased", false)) and rebased_memory.get("rebased_local_marker") == "local" and rebased_memory.get("concurrent_marker") == "concurrent", "stale_memory_rebased_once")
	var conflict_source := port.ai_actor_state_snapshot(capability, 1)
	var conflict_desired := (conflict_source.get("ai_memory", {}) as Dictionary).duplicate(true)
	var desired_counts := (conflict_desired.get("action_counts", {}) as Dictionary).duplicate(true)
	desired_counts["desired"] = 1
	conflict_desired["action_counts"] = desired_counts
	var conflict_concurrent := (conflict_source.get("ai_memory", {}) as Dictionary).duplicate(true)
	var concurrent_counts := (conflict_concurrent.get("action_counts", {}) as Dictionary).duplicate(true)
	concurrent_counts["concurrent"] = 1
	conflict_concurrent["action_counts"] = concurrent_counts
	port.commit_ai_state(capability, 1, {"ai_profile": conflict_source.get("ai_profile", {}), "ai_memory": conflict_concurrent}, str(conflict_source.get("state_revision", "")))
	var conflict_commit := ai._commit_ai_memory(1, conflict_desired, conflict_source)
	_check(not bool(conflict_commit.get("accepted", true)) and str(conflict_commit.get("rebase_rejected", "")) == "actor_state_memory_conflict", "nested_memory_conflict_rejected")
	var delete_seed := port.ai_actor_state_snapshot(capability, 1)
	var delete_seed_memory := (delete_seed.get("ai_memory", {}) as Dictionary).duplicate(true)
	delete_seed_memory["delete_conflict_key"] = "baseline"
	port.commit_ai_state(capability, 1, {"ai_profile": delete_seed.get("ai_profile", {}), "ai_memory": delete_seed_memory}, str(delete_seed.get("state_revision", "")))
	var delete_source := port.ai_actor_state_snapshot(capability, 1)
	var delete_desired := (delete_source.get("ai_memory", {}) as Dictionary).duplicate(true)
	delete_desired["delete_conflict_key"] = "local-update"
	var delete_concurrent := (delete_source.get("ai_memory", {}) as Dictionary).duplicate(true)
	delete_concurrent.erase("delete_conflict_key")
	port.commit_ai_state(capability, 1, {"ai_profile": delete_source.get("ai_profile", {}), "ai_memory": delete_concurrent}, str(delete_source.get("state_revision", "")))
	var delete_conflict := ai._commit_ai_memory(1, delete_desired, delete_source)
	_check(not bool(delete_conflict.get("accepted", true)) and not (port.ai_actor_state_snapshot(capability, 1).get("ai_memory", {}) as Dictionary).has("delete_conflict_key"), "update_delete_conflict_rejected")
	var reverse_delete_seed := port.ai_actor_state_snapshot(capability, 1)
	var reverse_seed_memory := (reverse_delete_seed.get("ai_memory", {}) as Dictionary).duplicate(true)
	reverse_seed_memory["reverse_delete_conflict_key"] = "baseline"
	port.commit_ai_state(capability, 1, {"ai_profile": reverse_delete_seed.get("ai_profile", {}), "ai_memory": reverse_seed_memory}, str(reverse_delete_seed.get("state_revision", "")))
	var reverse_delete_source := port.ai_actor_state_snapshot(capability, 1)
	var reverse_delete_desired := (reverse_delete_source.get("ai_memory", {}) as Dictionary).duplicate(true)
	reverse_delete_desired.erase("reverse_delete_conflict_key")
	var reverse_delete_concurrent := (reverse_delete_source.get("ai_memory", {}) as Dictionary).duplicate(true)
	reverse_delete_concurrent["reverse_delete_conflict_key"] = "concurrent-update"
	port.commit_ai_state(capability, 1, {"ai_profile": reverse_delete_source.get("ai_profile", {}), "ai_memory": reverse_delete_concurrent}, str(reverse_delete_source.get("state_revision", "")))
	var reverse_delete_conflict := ai._commit_ai_memory(1, reverse_delete_desired, reverse_delete_source)
	_check(not bool(reverse_delete_conflict.get("accepted", true)) and str((port.ai_actor_state_snapshot(capability, 1).get("ai_memory", {}) as Dictionary).get("reverse_delete_conflict_key", "")) == "concurrent-update", "delete_update_conflict_rejected")
	_check(ai._committed_change_count({"accepted": true, "changed": true}, 2) == 2 and ai._committed_change_count({"accepted": true, "changed": false}, 2) == 0, "finalization_count_requires_change")

	var invalid_batch := port.capture_ai_state_batch(capability, true)
	((invalid_batch[0] as Dictionary).get("ai_memory", {}) as Dictionary)["batch_marker"] = "A"
	((invalid_batch[1] as Dictionary).get("ai_memory", {}) as Dictionary)["batch_marker"] = "B"
	(invalid_batch[1] as Dictionary)["expected_revision"] = "stale"
	var before_invalid_batch := world.to_save_data()
	var invalid_batch_receipt := port.apply_ai_state_batch(capability, invalid_batch)
	_check(not bool(invalid_batch_receipt.get("accepted", true)) and world.to_save_data() == before_invalid_batch, "batch_preflight_before_apply")
	var valid_batch := port.capture_ai_state_batch(capability, true)
	((valid_batch[0] as Dictionary).get("ai_memory", {}) as Dictionary)["batch_marker"] = "A"
	((valid_batch[1] as Dictionary).get("ai_memory", {}) as Dictionary)["batch_marker"] = "B"
	var valid_batch_receipt := port.apply_ai_state_batch(capability, valid_batch)
	_check(bool(valid_batch_receipt.get("accepted", false)) and int(valid_batch_receipt.get("changed_count", 0)) == 2, "atomic_batch_commit")
	_check(str((port.ai_actor_state_snapshot(capability, 1).get("ai_memory", {}) as Dictionary).get("batch_marker", "")) == "A" and str((port.ai_actor_state_snapshot(capability, 2).get("ai_memory", {}) as Dictionary).get("batch_marker", "")) == "B", "batch_actor_isolation")
	var pre_replacement_revision := str(port.ai_actor_state_snapshot(capability, 1).get("state_revision", ""))
	var replacement_actor := port.ai_actor_state_snapshot(capability, 1)
	var replacement_memory := (replacement_actor.get("ai_memory", {}) as Dictionary).duplicate(true)
	replacement_memory["replacement_marker"] = true
	world.replace_players(world.players.duplicate(true), true)
	var stale_after_replacement := port.commit_ai_state(capability, 1, {"ai_profile": replacement_actor.get("ai_profile", {}), "ai_memory": replacement_memory}, pre_replacement_revision)
	_check(not bool(stale_after_replacement.get("accepted", true)), "players_replacement_invalidates_revision")
	var generation_source := port.ai_actor_state_snapshot(capability, 1)
	var generation_memory := (generation_source.get("ai_memory", {}) as Dictionary).duplicate(true)
	generation_memory["old_session_marker"] = true
	world.replace_players(world.players.duplicate(true), true)
	var generation_commit := ai._commit_ai_memory(1, generation_memory, generation_source)
	_check(not bool(generation_commit.get("accepted", true)) and str(generation_commit.get("rebase_rejected", "")) == "actor_state_generation_changed", "controller_rebase_generation_guard")

	var pre_restore_revision := str(port.ai_actor_state_snapshot(capability, 1).get("state_revision", ""))
	var restored := world.apply_save_data(world.to_save_data())
	var post_restore := port.ai_actor_state_snapshot(capability, 1)
	var post_restore_memory := (post_restore.get("ai_memory", {}) as Dictionary).duplicate(true)
	post_restore_memory["restore_marker"] = true
	var stale_after_restore := port.commit_ai_state(capability, 1, {"ai_profile": post_restore.get("ai_profile", {}), "ai_memory": post_restore_memory}, pre_restore_revision)
	_check(bool(restored.get("applied", false)) and not bool(stale_after_restore.get("accepted", true)), "restore_epoch_invalidates_revision")

	var saved_ai := ai.to_save_data()
	_check(not saved_ai.is_empty(), "complete_save_capture")
	var changed_actor := port.ai_actor_state_snapshot(capability, 1)
	var changed_memory := (changed_actor.get("ai_memory", {}) as Dictionary).duplicate(true)
	changed_memory["checkpoint_marker"] = "changed"
	port.commit_ai_state(capability, 1, {"ai_profile": changed_actor.get("ai_profile", {}), "ai_memory": changed_memory}, str(changed_actor.get("state_revision", "")))
	var applied_ai := ai.apply_save_data(saved_ai)
	_check(bool(applied_ai.get("applied", false)) and not (port.ai_actor_state_snapshot(capability, 1).get("ai_memory", {}) as Dictionary).has("checkpoint_marker"), "ai_checkpoint_roundtrip")
	var truncated_ai := saved_ai.duplicate(true)
	(truncated_ai.get("player_states", []) as Array).pop_back()
	var before_truncated := world.to_save_data()
	var truncated_receipt := ai.apply_save_data(truncated_ai)
	_check(not bool(truncated_receipt.get("applied", true)) and str(truncated_receipt.get("reason_code", "")) == "ai_save_actor_roster_mismatch" and world.to_save_data() == before_truncated, "truncated_roster_rejected")
	var local_checkpoint := ai.capture_new_session_checkpoint()
	var old_world := world.to_save_data()
	world.replace_players([world.players[0], world.players[1]], true)
	var local_restore := ai.restore_new_session_checkpoint(local_checkpoint)
	_check(int(local_checkpoint.get("schema_version", 0)) == 2 and not local_checkpoint.has("save_data") and bool(local_restore.get("restored", false)), "local_checkpoint_roster_independent")
	world.apply_save_data(old_world)
	_check(rng.capture_plan_checkpoint() == rng_before, "actor_state_zero_rng")

	var registry_scene := FileAccess.get_file_as_string("res://scenes/runtime/V06SaveOwnerRegistry.tscn")
	_check(not registry_scene.contains("AiActorStatePort") and registry_scene.count("section_id =") == 19, "save_registry_unchanged")
	var controller_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var strategy_body := _function_body(controller_source, "_ai_refresh_strategy_intent")
	var strategy_candidates_at := strategy_body.find("_ai_strategy_candidates")
	var route_body := _function_body(controller_source, "_ai_refresh_route_plan")
	var route_candidates_at := route_body.find("_ai_route_plan_candidates")
	_check(strategy_candidates_at >= 0 and strategy_body.find("var actor_state := _ai_actor_state_snapshot", strategy_candidates_at) > strategy_candidates_at, "nested_strategy_cas_refresh")
	_check(route_candidates_at >= 0 and route_body.find("var actor_state := _ai_actor_state_snapshot", route_candidates_at) > route_candidates_at, "nested_route_plan_cas_refresh")
	_check(not controller_source.contains("player[\"ai_profile\"]") and not controller_source.contains("player[\"ai_memory\"]"), "no_whole_player_actor_state_write")
	var debug := port.debug_snapshot()
	_check(bool(debug.get("ai_state_commit_requires_revision", false)) and bool(debug.get("batch_preflight_before_apply", false)), "debug_contract_evidence")
	_finish()


func _player(name: String, marker: String, is_ai: bool, profile_index: int, eliminated := false) -> Dictionary:
	return {
		"name": name,
		"seat_type": "ai" if is_ai else "human",
		"is_ai": is_ai,
		"eliminated": eliminated,
		"cash": 700,
		"action_cooldown": 0.0,
		"slots": [{"private_marker": marker}],
		"city_guesses": {},
		"city_guess_confidence": {},
		"city_guess_reasons": {},
		"ai_profile": {"profile_index": profile_index, "private_marker": marker} if is_ai else {},
		"ai_memory": {"private_marker": marker, "decision_samples": [], "action_counts": {}},
	}


func _check(condition: bool, check_id: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(check_id)


func _function_body(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return "MISSING"
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _finish() -> void:
	if _failures.is_empty():
		validation_snapshot = {
			"status": "PASS",
			"checks": _checks,
			"privacy_leaks": 0,
			"partial_batch_mutations": 0,
		}
		print("AI_ACTOR_STATE_TYPED_PORT_MIGRATION_BENCH|status=PASS|checks=%d|privacy_leaks=0|partial_batch_mutations=0" % _checks)
		if DisplayServer.get_name() == "headless":
			get_tree().quit(0)
		else:
			print("AI_ACTOR_STATE_TYPED_PORT_MIGRATION_BENCH|event=awaiting_mcp_stop")
		return
	validation_snapshot = {
		"status": "FAIL",
		"checks": _checks,
		"failures": _failures.duplicate(),
		"privacy_leaks": -1,
		"partial_batch_mutations": -1,
	}
	push_error("AI actor state typed-port migration Bench failed: %s" % ", ".join(_failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
