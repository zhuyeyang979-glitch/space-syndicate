extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	var world := coordinator.world_session_state()
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var port := coordinator.get_node_or_null("AiActorStatePort") as AiActorStatePort
	var game_session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var catalog := coordinator.get_node_or_null("RoleCatalogRuntimeService") as RoleCatalogRuntimeService
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	_expect(world != null and ai != null and port != null and game_session != null and catalog != null and rng != null, "production composition owns one actor-state port and the existing authorities")
	_expect(port.is_ready() and bool(ai.debug_snapshot().get("typed_actor_state_bound", false)), "production composition binds the opaque actor-state capability")

	ai.configure({"ruleset_id": "v0.6"})
	game_session.configure({"ruleset_id": "v0.6"}, {})
	var started := game_session.begin_session({"session_id": "ai-actor-state-focused", "scenario_id": "focused", "seed": 71, "player_count": 4})
	_expect(str(started.get("session_state", "")) == GameSessionRuntimeController.STATE_RUNNING, "fixture starts through GameSession authority")
	world.restore({
		"players": [
			_player(catalog, 0, "人类", false, "HUMAN_PRIVATE", -1),
			_player(catalog, 1, "AI-A", true, "AI_A_PRIVATE", 0),
			_player(catalog, 2, "AI-B", true, "AI_B_PRIVATE", 1),
			_player(catalog, 3, "AI-C", true, "AI_C_PRIVATE", 2, true),
		],
		"districts": [],
		"game_time": 12.0,
	}, true)
	ai._ensure_player_ai_state()
	var capability := ai.get("_ai_actor_state_capability") as AiActorStateCapability
	_expect(capability != null, "controller owns the opaque actor-state capability")

	var rng_before := rng.capture_plan_checkpoint()
	var world_before_queries := world.to_save_data()
	var public_roster := port.public_players_snapshot()
	var public_text := JSON.stringify(public_roster)
	_expect(public_roster.size() == 4 and TablePresentationPureDataPolicy.is_pure_data(public_roster), "public roster is detached pure data")
	_expect(not public_text.contains("PRIVATE") and not public_text.contains("ai_memory") and not public_text.contains("cash") and not public_text.contains("slots"), "public roster leaks no private state")
	_expect(port.ai_player_indices(true) == [1, 2, 3] and port.ai_player_indices(false) == [1, 2], "AI enumeration preserves eliminated filtering semantics")
	_expect(ai._ai_player_count() == 3 and ai._ai_player_indices() == [1, 2], "controller identity helpers consume the typed roster")
	_expect(ai._player_is_ai(1) and not ai._player_is_ai(0) and ai._player_is_eliminated(3), "typed identity and elimination queries preserve public seat semantics")

	var actor_a := port.ai_actor_state_snapshot(capability, 1)
	var actor_text := JSON.stringify(actor_a)
	_expect(str(actor_a.get("visibility_scope", "")) == "actor_private" and str(actor_a.get("state_revision", "")) != "", "authorized AI receives a revision-bound private state snapshot")
	_expect(actor_text.contains("AI_A_PRIVATE") and not actor_text.contains("AI_B_PRIVATE") and not actor_text.contains("AI_C_PRIVATE"), "actor snapshot contains only the requested AI state")
	_expect(not actor_a.has("cash") and not actor_a.has("slots") and not actor_a.has("discard") and not actor_a.has("action_cooldown") and not actor_a.has("city_guesses"), "narrow actor-state snapshot excludes deferred private domains")
	_expect(port.ai_actor_state_snapshot(AiActorStateCapability.new(), 1).is_empty() and port.ai_actor_state_snapshot(capability, 0).is_empty(), "forged capability and human actor fail closed")
	var authorized_capture := port.capture_ai_state_batch_receipt(capability, true)
	var forged_capture := port.capture_ai_state_batch_receipt(AiActorStateCapability.new(), true)
	var roster_checkpoint := world.to_save_data()
	world.replace_players([_player(catalog, 0, "人类-A", false, "HUMAN_A_PRIVATE", -1), _player(catalog, 1, "人类-B", false, "HUMAN_B_PRIVATE", -1)], true)
	var zero_ai_capture := port.capture_ai_state_batch_receipt(capability, true)
	var zero_ai_apply := port.apply_ai_state_batch(capability, [])
	var forged_zero_ai_apply := port.apply_ai_state_batch(AiActorStateCapability.new(), [])
	var zero_ai_saved := ai.to_save_data()
	var zero_ai_timer := ai.ai_card_decision_timer
	ai.ai_card_decision_timer += 9.0
	var zero_ai_restore := ai.apply_save_data(zero_ai_saved)
	world.apply_save_data(roster_checkpoint)
	_expect(bool(authorized_capture.get("captured", false)) and (authorized_capture.get("rows", []) as Array).size() == 3 and bool(zero_ai_capture.get("captured", false)) and (zero_ai_capture.get("rows", []) as Array).is_empty() and not bool(forged_capture.get("captured", true)), "typed checkpoint capture distinguishes a valid zero-AI roster from capture failure")
	var truncated_direct_apply := port.apply_ai_state_batch(capability, [])
	_expect(bool(zero_ai_apply.get("accepted", false)) and not bool(forged_zero_ai_apply.get("accepted", true)) and not bool(truncated_direct_apply.get("accepted", true)) and str(truncated_direct_apply.get("reason_code", "")) == "ai_actor_state_batch_roster_mismatch", "batch apply validates capability and the exact current AI roster even for an empty payload")
	_expect(bool(zero_ai_restore.get("applied", false)) and int(zero_ai_restore.get("player_state_count", -1)) == 0 and is_equal_approx(ai.ai_card_decision_timer, zero_ai_timer), "controller save capture and apply roundtrip a legitimate zero-AI roster without inventing actor state")
	actor_a = port.ai_actor_state_snapshot(capability, 1)
	var detached_actor := actor_a.duplicate(true)
	(detached_actor.get("ai_memory", {}) as Dictionary)["private_marker"] = "MUTATED_COPY"
	_expect(str((port.ai_actor_state_snapshot(capability, 1).get("ai_memory", {}) as Dictionary).get("private_marker", "")) == "AI_A_PRIVATE", "actor-state snapshots are detached")
	_expect(world.to_save_data() == world_before_queries and rng.capture_plan_checkpoint() == rng_before, "typed actor queries perform zero mutation and consume zero RNG")

	var profile_a := (actor_a.get("ai_profile", {}) as Dictionary).duplicate(true)
	var memory_a := (actor_a.get("ai_memory", {}) as Dictionary).duplicate(true)
	memory_a["last_plan"] = "typed actor state"
	var missing_revision := port.commit_ai_state(capability, 1, {"ai_profile": profile_a, "ai_memory": memory_a})
	var extra_key := port.commit_ai_state(capability, 1, {"ai_profile": profile_a, "ai_memory": memory_a, "cash": 999}, str(actor_a.get("state_revision", "")))
	_expect(not bool(missing_revision.get("accepted", true)) and not bool(extra_key.get("accepted", true)), "missing revision and extra patch fields are rejected")
	var accepted := port.commit_ai_state(capability, 1, {"ai_profile": profile_a, "ai_memory": memory_a}, str(actor_a.get("state_revision", "")))
	var after_accept := port.ai_actor_state_snapshot(capability, 1)
	var replay := port.commit_ai_state(capability, 1, {"ai_profile": profile_a, "ai_memory": memory_a}, str(after_accept.get("state_revision", "")))
	var stale := port.commit_ai_state(capability, 1, {"ai_profile": profile_a, "ai_memory": memory_a}, str(actor_a.get("state_revision", "")))
	_expect(bool(accepted.get("accepted", false)) and bool(accepted.get("changed", false)), "revision-bound actor state commit changes the WorldSession record once")
	_expect(bool(replay.get("accepted", false)) and not bool(replay.get("changed", true)), "same state replay is idempotent")
	_expect(not bool(stale.get("accepted", true)) and str(stale.get("reason_code", "")) == "ai_actor_state_revision_changed", "stale revision fails closed")
	var rebase_source := port.ai_actor_state_snapshot(capability, 1)
	var desired_memory := (rebase_source.get("ai_memory", {}) as Dictionary).duplicate(true)
	desired_memory["rebased_local_marker"] = "local"
	var concurrent_memory := (rebase_source.get("ai_memory", {}) as Dictionary).duplicate(true)
	concurrent_memory["concurrent_marker"] = "concurrent"
	port.commit_ai_state(capability, 1, {"ai_profile": rebase_source.get("ai_profile", {}), "ai_memory": concurrent_memory}, str(rebase_source.get("state_revision", "")))
	var rebased_commit := ai._commit_ai_memory(1, desired_memory, rebase_source)
	var rebased_memory := port.ai_actor_state_snapshot(capability, 1).get("ai_memory", {}) as Dictionary
	_expect(bool(rebased_commit.get("accepted", false)) and bool(rebased_commit.get("rebased", false)) and rebased_memory.get("rebased_local_marker") == "local" and rebased_memory.get("concurrent_marker") == "concurrent", "controller rebases one stale memory commit without overwriting a concurrent top-level update")
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
	var conflict_memory := port.ai_actor_state_snapshot(capability, 1).get("ai_memory", {}) as Dictionary
	_expect(not bool(conflict_commit.get("accepted", true)) and str(conflict_commit.get("rebase_rejected", "")) == "actor_state_memory_conflict" and (conflict_memory.get("action_counts", {}) as Dictionary).has("concurrent") and not (conflict_memory.get("action_counts", {}) as Dictionary).has("desired"), "same-key nested concurrent memory updates fail closed instead of overwriting latest state")
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
	_expect(not bool(delete_conflict.get("accepted", true)) and str(delete_conflict.get("rebase_rejected", "")) == "actor_state_memory_conflict" and not (port.ai_actor_state_snapshot(capability, 1).get("ai_memory", {}) as Dictionary).has("delete_conflict_key"), "update-versus-delete conflict fails closed without resurrecting a removed memory key")
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
	_expect(not bool(reverse_delete_conflict.get("accepted", true)) and str(reverse_delete_conflict.get("rebase_rejected", "")) == "actor_state_memory_conflict" and str((port.ai_actor_state_snapshot(capability, 1).get("ai_memory", {}) as Dictionary).get("reverse_delete_conflict_key", "")) == "concurrent-update", "delete-versus-update conflict fails closed without discarding the concurrent value")
	_expect(ai._committed_change_count({"accepted": true, "changed": true}, 3) == 3 and ai._committed_change_count({"accepted": true, "changed": false}, 3) == 0 and ai._committed_change_count({"accepted": false, "changed": false}, 3) == 0, "finalization counts only an accepted changed commit at runtime")

	var current := port.ai_actor_state_snapshot(capability, 1)
	var nonfinite_memory := (current.get("ai_memory", {}) as Dictionary).duplicate(true)
	nonfinite_memory["bad_value"] = INF
	var nonfinite := port.commit_ai_state(capability, 1, {"ai_profile": current.get("ai_profile", {}), "ai_memory": nonfinite_memory}, str(current.get("state_revision", "")))
	var retired_memory := (current.get("ai_memory", {}) as Dictionary).duplicate(true)
	retired_memory["contract_response"] = {"accepted": true}
	var retired := port.commit_ai_state(capability, 1, {"ai_profile": current.get("ai_profile", {}), "ai_memory": retired_memory}, str(current.get("state_revision", "")))
	_expect(not bool(nonfinite.get("accepted", true)) and not bool(retired.get("accepted", true)), "nonfinite and retired payloads fail closed")

	var batch := port.capture_ai_state_batch(capability, true)
	_expect(batch.size() == 3 and (batch[2] as Dictionary).get("player_index", -1) == 3, "checkpoint batch includes eliminated AI without exposing a rival through public projection")
	var invalid_batch := batch.duplicate(true)
	((invalid_batch[0] as Dictionary).get("ai_memory", {}) as Dictionary)["batch_marker"] = "A"
	((invalid_batch[1] as Dictionary).get("ai_memory", {}) as Dictionary)["batch_marker"] = "B"
	(invalid_batch[1] as Dictionary)["expected_revision"] = "stale"
	var before_invalid_batch := world.to_save_data()
	var invalid_batch_receipt := port.apply_ai_state_batch(capability, invalid_batch)
	_expect(not bool(invalid_batch_receipt.get("accepted", true)) and world.to_save_data() == before_invalid_batch, "batch preflight rejects every row before any mutation")
	var valid_batch := port.capture_ai_state_batch(capability, true)
	((valid_batch[0] as Dictionary).get("ai_memory", {}) as Dictionary)["batch_marker"] = "A"
	((valid_batch[1] as Dictionary).get("ai_memory", {}) as Dictionary)["batch_marker"] = "B"
	var valid_batch_receipt := port.apply_ai_state_batch(capability, valid_batch)
	_expect(bool(valid_batch_receipt.get("accepted", false)) and int(valid_batch_receipt.get("changed_count", 0)) == 2, "valid batch applies both changed actors atomically")
	_expect(str((port.ai_actor_state_snapshot(capability, 1).get("ai_memory", {}) as Dictionary).get("batch_marker", "")) == "A" and str((port.ai_actor_state_snapshot(capability, 2).get("ai_memory", {}) as Dictionary).get("batch_marker", "")) == "B", "atomic batch preserves each actor's isolated memory")
	var revision_before_replacement := str(port.ai_actor_state_snapshot(capability, 1).get("state_revision", ""))
	var replacement_state := port.ai_actor_state_snapshot(capability, 1)
	var replacement_memory := (replacement_state.get("ai_memory", {}) as Dictionary).duplicate(true)
	replacement_memory["replacement_marker"] = true
	world.replace_players(world.players.duplicate(true), true)
	var stale_after_replacement := port.commit_ai_state(capability, 1, {"ai_profile": replacement_state.get("ai_profile", {}), "ai_memory": replacement_memory}, revision_before_replacement)
	_expect(not bool(stale_after_replacement.get("accepted", true)), "players replacement invalidates a snapshot even when profile and memory values are identical")
	var controller_generation_source := port.ai_actor_state_snapshot(capability, 1)
	var controller_generation_memory := (controller_generation_source.get("ai_memory", {}) as Dictionary).duplicate(true)
	controller_generation_memory["old_session_marker"] = true
	world.replace_players(world.players.duplicate(true), true)
	var cross_generation_commit := ai._commit_ai_memory(1, controller_generation_memory, controller_generation_source)
	_expect(not bool(cross_generation_commit.get("accepted", true)) and str(cross_generation_commit.get("rebase_rejected", "")) == "actor_state_generation_changed" and not (port.ai_actor_state_snapshot(capability, 1).get("ai_memory", {}) as Dictionary).has("old_session_marker"), "controller never rebases private memory across a players-replacement generation")

	var revision_before_restore := str(port.ai_actor_state_snapshot(capability, 1).get("state_revision", ""))
	var restore_data := world.to_save_data()
	var restored := world.apply_save_data(restore_data)
	var post_restore_state := port.ai_actor_state_snapshot(capability, 1)
	var post_restore_memory := (post_restore_state.get("ai_memory", {}) as Dictionary).duplicate(true)
	post_restore_memory["restore_marker"] = true
	var stale_after_restore := port.commit_ai_state(capability, 1, {"ai_profile": post_restore_state.get("ai_profile", {}), "ai_memory": post_restore_memory}, revision_before_restore)
	_expect(bool(restored.get("applied", false)) and not bool(stale_after_restore.get("accepted", true)), "WorldSession restore invalidates pre-restore actor revisions")

	var saved_ai := ai.to_save_data()
	_expect(not saved_ai.is_empty(), "controller save capture returns a complete typed actor roster")
	var changed_state := port.ai_actor_state_snapshot(capability, 1)
	var changed_memory := (changed_state.get("ai_memory", {}) as Dictionary).duplicate(true)
	changed_memory["save_restore_marker"] = "changed"
	port.commit_ai_state(capability, 1, {"ai_profile": changed_state.get("ai_profile", {}), "ai_memory": changed_memory}, str(changed_state.get("state_revision", "")))
	var applied_ai := ai.apply_save_data(saved_ai)
	_expect(bool(applied_ai.get("applied", false)) and not (port.ai_actor_state_snapshot(capability, 1).get("ai_memory", {}) as Dictionary).has("save_restore_marker"), "controller checkpoint roundtrips through the actor-state batch port")
	var malformed_ai := saved_ai.duplicate(true)
	(malformed_ai.get("player_states", []) as Array)[1]["player_index"] = 0
	var before_malformed := world.to_save_data()
	var timer_before := ai.ai_card_decision_timer
	malformed_ai["ai_card_decision_timer"] = timer_before + 99.0
	var malformed_receipt := ai.apply_save_data(malformed_ai)
	_expect(not bool(malformed_receipt.get("applied", true)) and world.to_save_data() == before_malformed and is_equal_approx(ai.ai_card_decision_timer, timer_before), "malformed checkpoint fails before actor or timer mutation")
	var truncated_ai := saved_ai.duplicate(true)
	(truncated_ai.get("player_states", []) as Array).pop_back()
	truncated_ai["ai_card_decision_timer"] = timer_before + 77.0
	var before_truncated := world.to_save_data()
	var truncated_receipt := ai.apply_save_data(truncated_ai)
	_expect(not bool(truncated_receipt.get("applied", true)) and str(truncated_receipt.get("reason_code", "")) == "ai_save_actor_roster_mismatch" and world.to_save_data() == before_truncated and is_equal_approx(ai.ai_card_decision_timer, timer_before), "truncated actor roster fails closed before actor or timer mutation")

	var valid_world_checkpoint := world.to_save_data()
	var unsafe_players := world.players.duplicate(true)
	var unsafe_actor := (unsafe_players[1] as Dictionary).duplicate(true)
	var unsafe_memory := (unsafe_actor.get("ai_memory", {}) as Dictionary).duplicate(true)
	unsafe_memory["nonfinite_capture"] = INF
	unsafe_actor["ai_memory"] = unsafe_memory
	unsafe_players[1] = unsafe_actor
	world.replace_players(unsafe_players, true)
	var unsafe_capture := port.capture_ai_state_batch_receipt(capability, true)
	_expect(not bool(unsafe_capture.get("captured", true)) and ai.to_save_data().is_empty(), "unsafe actor payload makes the complete save capture fail closed instead of truncating")
	world.apply_save_data(valid_world_checkpoint)

	var local_checkpoint := ai.capture_new_session_checkpoint()
	var old_world_checkpoint := world.to_save_data()
	world.replace_players([world.players[0], world.players[1]], true)
	ai.ai_card_decision_timer += 20.0
	var local_restore := ai.restore_new_session_checkpoint(local_checkpoint)
	_expect(int(local_checkpoint.get("schema_version", 0)) == 2 and not local_checkpoint.has("save_data") and bool(local_restore.get("restored", false)), "new-session rollback restores controller-local state independently of the replacement roster")
	world.apply_save_data(old_world_checkpoint)

	var profile_indices: Array = []
	for player_index in range(1, 8):
		profile_indices.append(int((ai.new_session_identity_for_seat(player_index, 1).get("ai_profile", {}) as Dictionary).get("profile_index", -1)))
	_expect(profile_indices == [0, 1, 2, 3, 4, 5, 0], "six personality assignment and wrap order remain frozen")
	_expect(rng.capture_plan_checkpoint() == rng_before, "all actor-state queries and commits consume zero RNG")
	var debug := port.debug_snapshot()
	_expect(bool(debug.get("ai_state_commit_requires_revision", false)) and bool(debug.get("batch_preflight_before_apply", false)) and int(debug.get("batch_rollback_count", -1)) == 0, "debug evidence records CAS and preflight-before-apply invariants")

	_run_source_negative_gates()
	coordinator.queue_free()
	await process_frame
	_finish()


func _player(catalog: RoleCatalogRuntimeService, player_index: int, name: String, is_ai: bool, marker: String, profile_index: int, eliminated := false) -> Dictionary:
	var role := catalog.definition_at(player_index)
	role["role_index"] = player_index
	return {
		"id": player_index,
		"name": name,
		"seat_type": "ai" if is_ai else "human",
		"is_ai": is_ai,
		"role_index": player_index,
		"role_card": role,
		"eliminated": eliminated,
		"eliminated_at": 1.0 if eliminated else -1.0,
		"elimination_reason": "fixture" if eliminated else "",
		"cash": 700,
		"action_cooldown": 0.0,
		"slots": [{"private_marker": marker}],
		"discard": [marker],
		"city_guesses": {},
		"city_guess_confidence": {},
		"city_guess_reasons": {},
		"ai_profile": {"profile_index": profile_index, "name": "profile-%d" % profile_index, "private_marker": marker} if is_ai else {"private_marker": marker},
		"ai_memory": {"private_marker": marker, "decision_samples": [], "action_counts": {}},
	}


func _run_source_negative_gates() -> void:
	var controller_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var port_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_actor_state_port.gd")
	var registry_scene := FileAccess.get_file_as_string("res://scenes/runtime/V06SaveOwnerRegistry.tscn")
	for function_name in ["_player_is_ai", "_player_is_eliminated", "_ai_player_count", "_ai_player_indices", "_ai_profile_for_player", "_ai_memory_for_player"]:
		var body := _function_body(controller_source, function_name)
		_expect(body != "MISSING", "%s exists for source-negative inspection" % function_name)
		_expect(not body.contains("_call_world") and not body.contains("players"), "%s contains no Main or whole-player access" % function_name)
	for function_name in ["_ai_refresh_game_phase", "_record_ai_decision", "_finalize_ai_decision_rewards", "finalize_victory_outcome_learning", "_ai_refresh_economic_focus", "_ai_refresh_strategy_intent", "_ai_refresh_route_plan"]:
		var body := _function_body(controller_source, function_name)
		_expect(body != "MISSING", "%s exists for source-negative inspection" % function_name)
		_expect(not body.contains("player.get(\"ai_memory\"") and not body.contains("player[\"ai_memory\"]") and not body.contains("players[player_index] = player"), "%s contains no direct world-record AI memory access" % function_name)
		_expect(body.contains("_ai_actor_state_snapshot") or body.contains("_ai_memory_for_player") or body.contains("_commit_ai_memory"), "%s consumes the actor-state typed boundary" % function_name)
	_expect(_function_body(controller_source, "to_save_data").contains("capture_ai_state_batch") and _function_body(controller_source, "apply_save_data").contains("apply_ai_state_batch"), "controller checkpoint capture/apply uses the atomic actor-state batch port")
	_expect(not controller_source.contains("player[\"ai_profile\"]") and not controller_source.contains("player[\"ai_memory\"]"), "controller has no direct whole-player actor-state write")
	_expect(not _function_body(controller_source, "capture_new_session_checkpoint").contains("to_save_data") and not _function_body(controller_source, "restore_new_session_checkpoint").contains("apply_save_data"), "new-session rollback leaves player-record restoration to WorldSession authority")
	for function_name in ["_ai_refresh_game_phase", "_record_ai_decision", "_ai_refresh_economic_focus", "_ai_refresh_strategy_intent", "_ai_refresh_route_plan"]:
		var body := _function_body(controller_source, function_name)
		_expect(body.contains("var commit := _commit_ai_memory") and body.contains("commit.get(\"accepted\""), "%s handles the final actor-state receipt" % function_name)
	for function_name in ["_finalize_ai_decision_rewards", "finalize_victory_outcome_learning"]:
		var body := _function_body(controller_source, function_name)
		_expect(body.contains("_committed_change_count(commit"), "%s delegates counting to the behavior-tested changed-commit rule" % function_name)
	var strategy_body := _function_body(controller_source, "_ai_refresh_strategy_intent")
	var strategy_candidates_at := strategy_body.find("_ai_strategy_candidates")
	var strategy_commit_snapshot_at := strategy_body.find("var actor_state := _ai_actor_state_snapshot", strategy_candidates_at)
	_expect(strategy_candidates_at >= 0 and strategy_commit_snapshot_at > strategy_candidates_at, "strategy refresh re-reads actor memory after nested phase updates")
	var route_body := _function_body(controller_source, "_ai_refresh_route_plan")
	var route_candidates_at := route_body.find("_ai_route_plan_candidates")
	var route_commit_snapshot_at := route_body.find("var actor_state := _ai_actor_state_snapshot", route_candidates_at)
	_expect(route_candidates_at >= 0 and route_commit_snapshot_at > route_candidates_at, "route-plan refresh re-reads actor memory after nested strategy updates")
	_expect(not controller_source.contains("_call_world(&\"_player_is_ai\"") and not controller_source.contains("_call_world(&\"_player_is_eliminated\""), "actor identity uses no Main method-name route")
	var snapshot_keys_start := port_source.find("const AI_STATE_SNAPSHOT_KEYS")
	var snapshot_keys_end := port_source.find("@export var world_session_state_path", snapshot_keys_start)
	var snapshot_keys := port_source.substr(snapshot_keys_start, snapshot_keys_end - snapshot_keys_start) if snapshot_keys_start >= 0 and snapshot_keys_end > snapshot_keys_start else "MISSING"
	_expect(snapshot_keys != "MISSING", "narrow actor-state allowlist exists for source inspection")
	_expect(not snapshot_keys.contains("cash") and not snapshot_keys.contains("slots") and not snapshot_keys.contains("action_cooldown") and not snapshot_keys.contains("city_guesses"), "narrow state allowlist excludes deferred actor-private domains")
	_expect(not registry_scene.contains("AiActorStatePort") and registry_scene.count("section_id =") == 19, "actor-state migration adds no Save Owner or registry section")


func _function_body(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return "MISSING"
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AI actor state typed-port migration passed (%d checks)." % _checks)
		print("AI_ACTOR_STATE_TYPED_PORT_MIGRATION_COMPLETE")
		quit(0)
		return
	push_error("AI actor state typed-port migration failed:\n- " + "\n- ".join(_failures))
	quit(1)
