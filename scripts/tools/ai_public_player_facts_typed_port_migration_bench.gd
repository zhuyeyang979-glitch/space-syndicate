@tool
extends Node

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

class HostileEarlyBindProbe:
	extends Node

	var capability := AiActorStateCapability.new()
	var enter_tree_attempted := false
	var enter_tree_accepted := false
	var ready_attempted := false
	var ready_accepted := false

	func _enter_tree() -> void:
		var port := get_parent().get_node_or_null("AiActorStatePort") as AiActorStatePort
		enter_tree_attempted = port != null
		enter_tree_accepted = port != null and port.bind_ai_capability(capability)

	func _ready() -> void:
		var port := get_parent().get_node_or_null("AiActorStatePort") as AiActorStatePort
		ready_attempted = port != null
		ready_accepted = port != null and port.bind_ai_capability(capability)


var _checks := 0
var _failures: Array[String] = []
var validation_snapshot: Dictionary = {
	"status": "pending",
	"checks": 0,
	"privacy_leaks": -1,
	"main_routes": -1,
	"hostile_early_bind_accepts": -1,
	"elimination_detail_leaks": -1,
	"invalid_target_submission_delta": -1,
	"pre_submit_rejections": -1,
}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	var hostile_early_bind := HostileEarlyBindProbe.new()
	coordinator.add_child(hostile_early_bind)
	coordinator.move_child(hostile_early_bind, 0)
	add_child(coordinator)
	await get_tree().process_frame
	var world := coordinator.world_session_state()
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var port := coordinator.get_node_or_null("AiActorStatePort") as AiActorStatePort
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var catalog := coordinator.get_node_or_null("RoleCatalogRuntimeService") as RoleCatalogRuntimeService
	var rng := coordinator.run_rng_service()
	var submission := coordinator.card_play_submission_controller()
	var ai_bridge := coordinator.get_node_or_null("AiRuntimeWorldBridge") as AiRuntimeWorldBridge
	if ai_bridge != null:
		ai_bridge.set_rng_service(rng)
		ai_bridge.set_world_session_state(world)
		ai.set_world_bridge(ai_bridge)
	_check(world != null and ai != null and port != null and session != null and catalog != null and rng != null and ai_bridge != null and submission != null, "production_composition")
	_check(hostile_early_bind.enter_tree_attempted and not hostile_early_bind.enter_tree_accepted, "hostile_enter_tree_bind_rejected")
	_check(hostile_early_bind.ready_attempted and not hostile_early_bind.ready_accepted, "hostile_ready_bind_rejected")
	var prebind_debug := port.debug_snapshot()
	_check(int(prebind_debug.get("capability_revision", 0)) == 1 and int(prebind_debug.get("capability_bind_rejection_count", 0)) >= 2, "single_capability_prebound_before_children")
	ai.configure({"ruleset_id": "v0.6"})
	session.configure({"ruleset_id": "v0.6"}, {})
	session.begin_session({"session_id": "ai-public-player-bench", "scenario_id": "bench", "seed": 47, "player_count": 4})
	world.restore({
		"players": _players(catalog),
		"districts": [],
		"game_time": 0.0,
	}, true)
	ai._ensure_player_ai_state()
	_check(port.is_ready(), "existing_port_ready")

	var world_before := world.to_save_data()
	var rng_before := rng.capture_plan_checkpoint()
	var debug_before := port.debug_snapshot()
	var roster := port.public_players_snapshot()
	var roster_text := JSON.stringify(roster)
	_check(roster.size() == 4, "one_human_three_ai_roster")
	_check(port.human_player_count() == 1 and port.ai_player_count(true) == 3, "public_counts")
	_check(port.ai_player_indices(false) == [1, 2] and port.ai_player_indices(true) == [1, 2, 3], "eliminated_ai_filter")
	_check(port.active_target_player_indices(1) == [0, 2], "stable_active_target_order")
	_check(port.public_target_label(2) == "玩家3" and port.public_target_label(99) == "未知玩家", "target_label_parity")
	_check((roster[0] as Dictionary).keys() == AiActorStatePort.PUBLIC_PLAYER_ROW_KEYS, "strict_allowlist")
	_check(not roster_text.contains("cash") and not roster_text.contains("slots") and not roster_text.contains("ai_memory") and not roster_text.contains("city_guesses") and not roster_text.contains("private_marker") and not roster_text.contains("eliminated_at") and not roster_text.contains("elimination_reason"), "privacy_redaction")
	_check(TablePresentationPureDataPolicy.is_pure_data(roster), "pure_data")
	_check(world.to_save_data() == world_before and rng.capture_plan_checkpoint() == rng_before and port.debug_snapshot() == debug_before, "query_zero_mutation_rng_log")

	var capability := ai.get("_ai_actor_state_capability") as AiActorStateCapability
	_check(capability != null and capability == coordinator.get("_ai_actor_state_capability"), "single_formal_capability_reused")
	_check(port.bind_ai_capability(capability), "idempotent_capability_bind")
	var hostile := AiActorStateCapability.new()
	_check(not port.bind_ai_capability(hostile), "hostile_rebind_rejected")
	_check(not port.ai_actor_state_snapshot(capability, 1).is_empty() and port.ai_actor_state_snapshot(hostile, 1).is_empty(), "capability_authorization_preserved")
	_check(port.ai_actor_state_snapshot(hostile_early_bind.capability, 1).is_empty(), "early_hostile_capability_has_zero_private_access")

	var plan_a := ai._ai_direct_player_interaction_plan(1, {"kind": "player_hand_disrupt", "hand_discard_count": 1})
	world.districts = [{"name": "hidden", "city": {"active": true, "owner": 0}}]
	ai.auto_monsters = [{"uid": 1, "down": false, "owner": 0}]
	var plan_b := ai._ai_direct_player_interaction_plan(1, {"kind": "player_hand_disrupt", "hand_discard_count": 1})
	(world.districts[0] as Dictionary)["city"] = {"active": true, "owner": 2}
	ai.auto_monsters = [{"uid": 1, "down": false, "owner": 2}]
	var plan_c := ai._ai_direct_player_interaction_plan(1, {"kind": "player_hand_disrupt", "hand_discard_count": 1})
	_check(int(plan_a.get("target_player", -1)) in [0, 2] and int(plan_a.get("target_player", -1)) != 3, "typed_target_identity")
	_check(int(plan_b.get("target_player", -1)) == int(plan_c.get("target_player", -2)) and int(plan_b.get("score", -1)) == int(plan_c.get("score", -2)), "hidden_owner_privacy_differential")
	_check(int(plan_c.get("direct_target_city_pressure", -1)) == 0 and int(plan_c.get("direct_target_monster_pressure", -1)) == 0, "hidden_owner_scores_removed")

	var planned_target := int(plan_a.get("target_player", -1))
	if submission != null and planned_target >= 0 and planned_target < world.players.size():
		var post_plan_players := world.players.duplicate(true)
		var post_plan_target := (post_plan_players[planned_target] as Dictionary).duplicate(true)
		post_plan_target["eliminated"] = true
		post_plan_target["eliminated_at"] = 88.0
		post_plan_target["elimination_reason"] = "BENCH_PRIVATE_REASON"
		post_plan_players[planned_target] = post_plan_target
		var submission_before := int(submission.debug_snapshot().get("submission_count", -1))
		var rejection_before := int(ai.debug_snapshot().get("card_target_pre_submit_rejection_count", -1))
		world.replace_players(post_plan_players, true)
		_check(bool(port.public_player_snapshot(planned_target).get("eliminated", false)), "planned_target_now_eliminated")
		_check(not ai._queue_skill_resolution(1, -1, -1, planned_target, -1), "eliminated_target_rejected_before_submit")
		_check(int(submission.debug_snapshot().get("submission_count", -1)) == submission_before, "rejected_target_submission_delta_zero")
		_check(int(ai.debug_snapshot().get("card_target_pre_submit_rejection_count", -1)) == rejection_before + 1, "pre_submit_rejection_count_one")

	var controller_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var port_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_actor_state_port.gd")
	var direct_body := _function_body(controller_source, "_ai_direct_player_interaction_plan")
	_check(not direct_body.contains("players") and not direct_body.contains("_player_active_city_count") and not direct_body.contains("_ai_owned_active_monster_count"), "source_negative_direct_target")
	_check(not controller_source.contains("_call_world(&\"_interaction_target_label\""), "source_negative_main_label")
	var queue_body := _function_body(controller_source, "_queue_skill_resolution")
	_check(queue_body.find("_current_public_card_target_is_valid") >= 0 and queue_body.find("submit_card_play") > queue_body.find("_current_public_card_target_is_valid"), "source_pre_submit_validation_order")
	_check(_function_body(coordinator_source, "_enter_tree").contains("_prebind_ai_actor_state_capability") and not _function_body(coordinator_source, "_wire_ai_world_typed_ports").contains("AiActorStateCapability.new()"), "source_parent_prebind_single_creation")
	_check(not _function_body(port_source, "public_players_snapshot").contains("eliminated_at") and not _function_body(port_source, "public_players_snapshot").contains("elimination_reason") and not _function_body(port_source, "_normalized_public_roster_base").contains("eliminated_at") and not _function_body(port_source, "_normalized_public_roster_base").contains("elimination_reason"), "source_public_elimination_details_absent")
	_finish()
	coordinator.queue_free()


func _players(catalog: RoleCatalogRuntimeService) -> Array:
	var result: Array = []
	for player_index in range(4):
		var role := catalog.definition_at(player_index)
		role["role_index"] = player_index
		var is_ai := player_index > 0
		var eliminated := player_index == 3
		result.append({
			"id": player_index,
			"actor_id": "player.%d" % player_index,
			"name": "Human" if player_index == 0 else "AI-%d" % player_index,
			"seat_type": "ai" if is_ai else "human",
			"is_ai": is_ai,
			"role_index": player_index,
			"role_card": role,
			"eliminated": eliminated,
			"eliminated_at": 4.0 if eliminated else -1.0,
			"elimination_reason": "bench" if eliminated else "",
			"cash": 700,
			"cash_cents": 70000,
			"slots": [{"private_marker": "HAND-%d" % player_index}],
			"discard": [],
			"city_guesses": {},
			"city_guess_confidence": {},
			"city_guess_reasons": {},
			"ai_profile": {"profile_index": maxi(0, player_index - 1), "private_marker": "PROFILE-%d" % player_index} if is_ai else {},
			"ai_memory": {"private_marker": "MEMORY-%d" % player_index, "decision_samples": [], "action_counts": {}},
			"action_cooldown": 0.0,
		})
	return result


func _function_body(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return "MISSING"
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _check(condition: bool, check_id: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(check_id)


func _finish() -> void:
	if _failures.is_empty():
		validation_snapshot = {
			"status": "PASS",
			"checks": _checks,
			"privacy_leaks": 0,
			"main_routes": 0,
			"hostile_early_bind_accepts": 0,
			"elimination_detail_leaks": 0,
			"invalid_target_submission_delta": 0,
			"pre_submit_rejections": 1,
		}
		print("AI_PUBLIC_PLAYER_FACTS_TYPED_PORT_MIGRATION_BENCH|status=PASS|checks=%d|privacy_leaks=0|main_routes=0|hostile_early_bind_accepts=0|elimination_detail_leaks=0|invalid_target_submission_delta=0|pre_submit_rejections=1" % _checks)
		get_tree().quit(0)
		return
	validation_snapshot = {
		"status": "FAIL",
		"checks": _checks,
		"failures": _failures.duplicate(),
		"privacy_leaks": -1,
		"main_routes": -1,
		"hostile_early_bind_accepts": -1,
		"elimination_detail_leaks": -1,
		"invalid_target_submission_delta": -1,
		"pre_submit_rejections": -1,
	}
	push_error("AI public player facts Bench failed: %s" % ", ".join(_failures))
	get_tree().quit(1)
