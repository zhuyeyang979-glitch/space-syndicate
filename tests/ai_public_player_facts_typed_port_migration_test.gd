extends SceneTree

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


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	var hostile_early_bind := HostileEarlyBindProbe.new()
	coordinator.add_child(hostile_early_bind)
	coordinator.move_child(hostile_early_bind, 0)
	root.add_child(coordinator)
	await process_frame
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
	_expect(world != null and ai != null and port != null and session != null and catalog != null and rng != null and ai_bridge != null, "production composition exposes every authoritative dependency")
	_expect(submission != null, "production composition exposes the existing CardPlay submission boundary")
	_expect(hostile_early_bind.enter_tree_attempted and not hostile_early_bind.enter_tree_accepted, "first child hostile bind is rejected during its enter-tree callback")
	_expect(hostile_early_bind.ready_attempted and not hostile_early_bind.ready_accepted, "first child hostile bind remains rejected during its ready callback")
	var prebind_debug := port.debug_snapshot()
	_expect(int(prebind_debug.get("capability_revision", 0)) == 1 and int(prebind_debug.get("capability_bind_rejection_count", 0)) >= 2, "Coordinator prebinds one formal capability before hostile child lifecycle attempts")
	_expect(port.is_ready(), "existing AiActorStatePort is composition-ready")
	ai.configure({"ruleset_id": "v0.6"})
	session.configure({"ruleset_id": "v0.6"}, {})

	for seat_count in [3, 4, 6, 8]:
		_begin_fixture(session, world, catalog, seat_count, -1, "roster-%d" % seat_count)
		var rows := port.public_players_snapshot()
		var indices: Array = []
		for row_variant in rows:
			indices.append(int((row_variant as Dictionary).get("player_index", -1)))
		_expect(rows.size() == seat_count, "%d-player public roster is complete" % seat_count)
		_expect(indices == range(seat_count), "%d-player public roster has stable seat order" % seat_count)
		_expect(int((rows[0] as Dictionary).get("session_revision", -1)) == session.session_start_revision(), "%d-player rows bind current session revision" % seat_count)
		_expect(str((rows[seat_count - 1] as Dictionary).get("public_player_name", "")) == "AI-%d" % seat_count, "%d-player public name is preserved" % seat_count)

	_begin_fixture(session, world, catalog, 4, 3, "public-contract")
	ai._ensure_player_ai_state()
	var capability := ai.get("_ai_actor_state_capability") as AiActorStateCapability
	var rows := port.public_players_snapshot()
	var row0 := rows[0] as Dictionary
	var row1 := rows[1] as Dictionary
	var row3 := rows[3] as Dictionary
	_expect(capability != null, "controller receives the opaque actor capability")
	_expect(capability == coordinator.get("_ai_actor_state_capability"), "AI controller reuses the Coordinator's single prebound capability instance")
	_expect(row0.keys() == AiActorStatePort.PUBLIC_PLAYER_ROW_KEYS, "public row uses the exact schema-1 allowlist")
	_expect(int(row0.get("schema_version", 0)) == 1 and str(row0.get("visibility_scope", "")) == "public", "public row declares schema and visibility")
	_expect(str(row0.get("session_id", "")) == "public-contract", "public row binds session identity")
	_expect(str(row0.get("source_revision", "")).length() == 64 and str(row0.get("fingerprint", "")).length() == 64, "public row carries deterministic source and row fingerprints")
	_expect(int(row0.get("public_seat_order", -1)) == 0 and int(row3.get("public_seat_order", -1)) == 3, "public seat order matches stable indices")
	_expect(str(row1.get("role_name", "")) == str(catalog.public_definition_at(1).get("name", "")), "role name is catalog-authoritative")
	_expect(port.public_role_definition(1).get("role_index", -1) == 1 and str(port.public_role_definition(1).get("role_name", "")) == str(row1.get("role_name", "")), "public role API returns the validated definition")
	_expect(port.human_player_count(true) == 1 and port.ai_player_count(true) == 3, "human and total AI counts preserve product semantics")
	_expect(port.ai_player_count(false) == 2 and port.ai_player_indices(false) == [1, 2] and port.ai_player_indices(true) == [1, 2, 3], "active and total AI enumeration preserve elimination semantics")
	_expect(port.active_target_player_indices(1) == [0, 2], "typed target enumeration excludes self and eliminated players")
	_expect(port.public_target_label(2) == "玩家3" and port.public_target_label(99) == "未知玩家", "target labels preserve 玩家N and 未知玩家 parity")
	_expect(port.public_player_name(2) == "AI-3", "public-name API preserves the visible custom name separately")
	_expect(port.is_player_eliminated(3) and not port.is_player_eliminated(2), "elimination state is public and strict")
	_expect(not row3.has("eliminated_at") and not row3.has("elimination_reason"), "public rows expose elimination state without private elimination details")
	_expect(port.is_current_public_player_snapshot(row1), "current public row validates")
	_expect(not port.is_current_public_player_snapshot({"player_index": 1}), "partial public row fails closed")

	var public_text := JSON.stringify(rows)
	for forbidden in ["cash", "slots", "discard", "warehouse", "futures", "ai_profile", "ai_memory", "decision_samples", "city_guesses", "hidden_owner", "private_marker", "eliminated_at", "elimination_reason"]:
		_expect(not public_text.contains(forbidden), "public roster excludes %s" % forbidden)
	_expect(TablePresentationPureDataPolicy.is_pure_data(rows), "public roster is pure data")
	var detached := row1.duplicate(true)
	detached["public_player_name"] = "MUTATED"
	_expect(port.public_player_name(1) == "AI-2", "public rows are detached")
	var repeat_rows := port.public_players_snapshot()
	_expect(repeat_rows == rows, "same public authority produces an identical snapshot")
	_expect(str((repeat_rows[1] as Dictionary).get("fingerprint", "")) == str(row1.get("fingerprint", "")), "public fingerprint is deterministic")

	var world_before_query := world.to_save_data()
	var rng_before_query := rng.capture_plan_checkpoint()
	var debug_before_query := port.debug_snapshot()
	port.public_players_snapshot()
	port.public_player_snapshot(2)
	port.public_role_definition(2)
	port.public_active_target_rows(1)
	port.human_player_count()
	port.ai_player_count()
	var debug_after_query := port.debug_snapshot()
	_expect(world.to_save_data() == world_before_query, "public query mutates no gameplay state")
	_expect(rng.capture_plan_checkpoint() == rng_before_query, "public query consumes zero RNG")
	_expect(debug_after_query == debug_before_query and int(debug_after_query.get("public_query_count", -1)) == 0, "public query is literal zero object mutation")
	_expect(bool(debug_after_query.get("public_query_literal_zero_mutation", false)), "debug contract records literal zero mutation")
	_expect(not bool(debug_after_query.get("public_snapshot_exposes_elimination_details", true)), "debug contract records zero public elimination-detail exposure")

	_expect(port.bind_ai_capability(capability), "binding the same capability is idempotent")
	var hostile_capability := AiActorStateCapability.new()
	_expect(not port.bind_ai_capability(hostile_capability), "hostile capability replacement is rejected")
	_expect(not port.ai_actor_state_snapshot(capability, 1).is_empty(), "authorized capability remains active after hostile rebind")
	_expect(port.ai_actor_state_snapshot(hostile_capability, 1).is_empty(), "hostile capability cannot read actor-private state")
	_expect(port.ai_actor_state_snapshot(hostile_early_bind.capability, 1).is_empty(), "early hostile child capability never gains actor-private read authority")

	var baseline_players := world.players.duplicate(true)
	var stale_before_replace := port.public_player_snapshot(1)
	var malformed_non_dictionary := baseline_players.duplicate(true)
	malformed_non_dictionary[1] = "bad-row"
	world.replace_players(malformed_non_dictionary, true)
	_expect(port.public_players_snapshot().is_empty(), "non-Dictionary row fails the whole roster closed")
	world.replace_players(baseline_players, true)
	_expect(not port.is_current_public_player_snapshot(stale_before_replace), "players replacement invalidates the old source revision")

	var duplicate_id := baseline_players.duplicate(true)
	(duplicate_id[2] as Dictionary)["id"] = 1
	world.replace_players(duplicate_id, true)
	_expect(port.public_players_snapshot().is_empty(), "duplicate player identity fails closed")
	var role_mismatch := baseline_players.duplicate(true)
	((role_mismatch[1] as Dictionary).get("role_card", {}) as Dictionary)["name"] = "错误角色"
	world.replace_players(role_mismatch, true)
	_expect(port.public_players_snapshot().is_empty(), "role index and name mismatch fails closed")
	var seat_mismatch := baseline_players.duplicate(true)
	(seat_mismatch[1] as Dictionary)["is_ai"] = false
	world.replace_players(seat_mismatch, true)
	_expect(port.public_players_snapshot().is_empty(), "seat type and AI flag mismatch fails closed")
	var missing_name := baseline_players.duplicate(true)
	(missing_name[1] as Dictionary).erase("name")
	world.replace_players(missing_name, true)
	_expect(port.public_players_snapshot().is_empty(), "missing public identity field fails closed")
	world.replace_players(baseline_players, true)

	var session_a_row := port.public_player_snapshot(1)
	session.begin_session({"session_id": "same-roster-new-session", "scenario_id": "focused", "seed": 19, "player_count": 4})
	var session_b_row := port.public_player_snapshot(1)
	_expect(not session_b_row.is_empty() and str(session_b_row.get("session_id", "")) == "same-roster-new-session", "same roster in a new session produces a new bound row")
	_expect(str(session_a_row.get("fingerprint", "")) != str(session_b_row.get("fingerprint", "")), "new session changes deterministic row fingerprint")
	_expect(not port.is_current_public_player_snapshot(session_a_row), "old session row is stale")
	var pre_restore_row := session_b_row.duplicate(true)
	var saved_world := world.to_save_data()
	var restore_receipt := world.apply_save_data(saved_world)
	var post_restore_row := port.public_player_snapshot(1)
	_expect(bool(restore_receipt.get("applied", false)), "WorldSession restore succeeds")
	_expect(str(pre_restore_row.get("fingerprint", "")) == str(post_restore_row.get("fingerprint", "")), "exact restore preserves authoritative public fingerprint")
	_expect(str(pre_restore_row.get("source_revision", "")) != str(post_restore_row.get("source_revision", "")), "restore rotates source revision")
	_expect(not port.is_current_public_player_snapshot(pre_restore_row), "pre-restore row fails current validation")

	var private_before := port.public_players_snapshot()
	var rival := world.players[2] as Dictionary
	rival["cash"] = 999999
	rival["slots"] = [{"private_marker": "RIVAL_HAND"}]
	rival["discard"] = ["PRIVATE_DISCARD"]
	rival["private_warehouse"] = {"stock": 99}
	rival["private_futures"] = {"position": 99}
	rival["city_guesses"] = {"0": 1}
	rival["eliminated_at"] = 999.0
	rival["elimination_reason"] = "RIVAL_PRIVATE_REASON"
	rival["ai_memory"] = {"decision_samples": [{"private": true}], "private_marker": "RIVAL_MEMORY"}
	world.players[2] = rival
	_expect(port.public_players_snapshot() == private_before, "private player mutations do not change public roster")
	_expect(JSON.stringify(port.public_players_snapshot()) == JSON.stringify(private_before), "privacy differential leaves serialized public facts unchanged")

	world.districts = [
		{"name": "隐藏城市", "city": {"active": true, "owner": 0}},
	]
	ai.auto_monsters = [{"uid": 1, "down": false, "owner": 0}]
	ai._ai_direct_player_interaction_plan(1, {"kind": "player_hand_disrupt", "hand_discard_count": 1})
	var plan_rng_before := rng.capture_plan_checkpoint()
	var plan_a := ai._ai_direct_player_interaction_plan(1, {"kind": "player_hand_disrupt", "hand_discard_count": 1})
	(world.districts[0] as Dictionary)["city"] = {"active": true, "owner": 2}
	ai.auto_monsters = [{"uid": 1, "down": false, "owner": 2}]
	var plan_b := ai._ai_direct_player_interaction_plan(1, {"kind": "player_hand_disrupt", "hand_discard_count": 1})
	_expect(int(plan_a.get("target_player", -1)) in [0, 2] and int(plan_a.get("target_player", -1)) != 3, "direct interaction chooses only a typed active target")
	_expect(int(plan_a.get("direct_target_city_pressure", -1)) == 0 and int(plan_a.get("direct_target_monster_pressure", -1)) == 0, "direct interaction no longer scores hidden owner aggregates")
	_expect(int(plan_a.get("target_player", -1)) == int(plan_b.get("target_player", -2)) and int(plan_a.get("score", -1)) == int(plan_b.get("score", -2)), "hidden city and monster owner changes do not affect public target scoring")
	_expect(rng.capture_plan_checkpoint() == plan_rng_before, "public target scoring consumes zero RNG")
	_expect(str(plan_a.get("reason", "")).contains("玩家"), "direct interaction reason keeps fixed public target label")

	var planned_target := int(plan_a.get("target_player", -1))
	if submission != null and planned_target >= 0 and planned_target < world.players.size():
		var post_plan_players := world.players.duplicate(true)
		var post_plan_target := (post_plan_players[planned_target] as Dictionary).duplicate(true)
		post_plan_target["eliminated"] = true
		post_plan_target["eliminated_at"] = 77.0
		post_plan_target["elimination_reason"] = "AFTER_PLAN_PRIVATE_REASON"
		post_plan_players[planned_target] = post_plan_target
		var submission_before := int(submission.debug_snapshot().get("submission_count", -1))
		var rejection_before := int(ai.debug_snapshot().get("card_target_pre_submit_rejection_count", -1))
		world.replace_players(post_plan_players, true)
		var current_target_row := port.public_player_snapshot(planned_target)
		_expect(not current_target_row.is_empty() and bool(current_target_row.get("eliminated", false)), "planned target can become publicly eliminated before card submission")
		_expect(not ai._queue_skill_resolution(1, -1, -1, planned_target, -1), "plan target eliminated after planning is rejected before card submission")
		_expect(not ai._queue_skill_resolution(1, -1, -1, 1, -1), "self target is rejected before card submission")
		_expect(not ai._queue_skill_resolution(1, -1, -1, 99, -1), "missing target is rejected before card submission")
		var submission_after := int(submission.debug_snapshot().get("submission_count", -1))
		var rejection_after := int(ai.debug_snapshot().get("card_target_pre_submit_rejection_count", -1))
		_expect(submission_after == submission_before, "all invalid current targets produce zero CardPlay submission attempts")
		_expect(rejection_after - rejection_before == 3, "AI records exactly three pre-submit target rejections")

	_begin_fixture(session, world, catalog, 8, -1, "build-order")
	ai._ensure_player_ai_state()
	rng.set_seed(98765)
	var production_before := rng.capture_plan_checkpoint()
	var reference_rng := RunRngService.new()
	reference_rng.set_seed(98765)
	var expected_order: Array = [1, 2, 3, 4, 5, 6, 7]
	for index in range(expected_order.size()):
		var swap_index := reference_rng.randi_range(index, expected_order.size() - 1)
		var temporary = expected_order[index]
		expected_order[index] = expected_order[swap_index]
		expected_order[swap_index] = temporary
	var actual_order := ai._rival_build_player_order()
	var production_after := rng.capture_plan_checkpoint()
	_expect(actual_order == expected_order, "build order preserves the frozen Fisher-Yates result")
	_expect(int(production_after.get("draw_count", 0)) - int(production_before.get("draw_count", 0)) == 7, "build order consumes exactly one draw per AI seat")
	_expect(int(production_after.get("rng_state", 0)) == int(reference_rng.capture_plan_checkpoint().get("rng_state", -1)), "build order preserves terminal RNG state")
	var profile_indices: Array = []
	var profile_names: Dictionary = {}
	for player_index in range(1, 8):
		var identity := ai.new_session_identity_for_seat(player_index, 1)
		var profile := identity.get("ai_profile", {}) as Dictionary
		profile_indices.append(int(profile.get("profile_index", -1)))
		profile_names[str(profile.get("name", ""))] = true
	_expect(profile_indices == [0, 1, 2, 3, 4, 5, 0], "six personality assignment and wrap order remain frozen")
	_expect(profile_names.size() == 6, "AI personality count remains six")

	_run_source_negative_gates()
	coordinator.queue_free()
	await process_frame
	_finish()


func _begin_fixture(session: GameSessionRuntimeController, world: WorldSessionState, catalog: RoleCatalogRuntimeService, seat_count: int, eliminated_index: int, session_id: String) -> void:
	session.begin_session({"session_id": session_id, "scenario_id": "focused", "seed": 19, "player_count": seat_count})
	world.restore({
		"players": _players(seat_count, catalog, eliminated_index),
		"districts": [],
		"game_time": 0.0,
	}, true)


func _players(seat_count: int, catalog: RoleCatalogRuntimeService, eliminated_index: int) -> Array:
	var result: Array = []
	for player_index in range(seat_count):
		var role_index := player_index
		var role := catalog.definition_at(role_index)
		role["role_index"] = role_index
		var is_ai := player_index > 0
		var eliminated := player_index == eliminated_index
		result.append({
			"id": player_index,
			"actor_id": "player.%d" % player_index,
			"name": "人类" if player_index == 0 else "AI-%d" % (player_index + 1),
			"seat_type": "ai" if is_ai else "human",
			"is_ai": is_ai,
			"role_index": role_index,
			"role_card": role,
			"eliminated": eliminated,
			"eliminated_at": 12.0 if eliminated else -1.0,
			"elimination_reason": "公开淘汰" if eliminated else "",
			"cash": 700 + player_index,
			"cash_cents": (700 + player_index) * 100,
			"slots": [{"private_marker": "HAND-%d" % player_index}],
			"discard": ["DISCARD-%d" % player_index],
			"private_warehouse": {"private_marker": "WAREHOUSE-%d" % player_index},
			"private_futures": {"private_marker": "FUTURES-%d" % player_index},
			"city_guesses": {"0": player_index},
			"city_guess_confidence": {"0": 2},
			"city_guess_reasons": {"0": "private"},
			"ai_profile": {"profile_index": maxi(0, player_index - 1), "private_marker": "PROFILE-%d" % player_index} if is_ai else {},
			"ai_memory": {"private_marker": "MEMORY-%d" % player_index, "decision_samples": [], "action_counts": {}},
			"action_cooldown": 0.0,
		})
	return result


func _run_source_negative_gates() -> void:
	var controller_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var port_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_actor_state_port.gd")
	var port_scene := FileAccess.get_file_as_string("res://scenes/runtime/AiActorStatePort.tscn")
	for function_name in ["_public_player_count", "_public_player_snapshot", "_public_active_target_rows", "_player_is_ai", "_player_is_eliminated", "_ai_player_count", "_ai_player_indices", "_player_role_card_for_index", "_interaction_target_label"]:
		var body := _function_body(controller_source, function_name)
		_expect(body != "MISSING", "%s exists for source inspection" % function_name)
		_expect(not body.contains("_call_world") and not body.contains("players") and not body.contains("TableSelectionState"), "%s has no generic player route" % function_name)
	var direct_body := _function_body(controller_source, "_ai_direct_player_interaction_plan")
	_expect(not direct_body.contains("players") and not direct_body.contains("_player_active_city_count") and not direct_body.contains("_ai_owned_active_monster_count"), "direct target plan contains no whole roster or hidden owner scoring")
	_expect(direct_body.contains("_public_active_target_rows") and direct_body.contains("_public_victory_audit_row"), "direct target plan consumes typed roster and public Victory audit only")
	_expect(not controller_source.contains("_call_world(&\"_interaction_target_label\""), "AI target labels have no Main method-name route")
	_expect(not _function_body(controller_source, "_player_role_card_for_index").contains("_call_monster"), "AI public role lookup has no Monster bridge")
	var target_guard_body := _function_body(controller_source, "_current_public_card_target_is_valid")
	_expect(target_guard_body.contains("_public_player_snapshot") and target_guard_body.contains("target_player == player_index") and target_guard_body.contains("eliminated"), "pre-submit target guard uses the current typed public row and rejects self or eliminated targets")
	var queue_body := _function_body(controller_source, "_queue_skill_resolution")
	var validation_position := queue_body.find("_current_public_card_target_is_valid")
	var submission_position := queue_body.find("submit_card_play")
	_expect(validation_position >= 0 and submission_position > validation_position, "current typed target validation is physically before CardPlay submission")
	var coordinator_enter_body := _function_body(coordinator_source, "_enter_tree")
	var coordinator_prebind_body := _function_body(coordinator_source, "_prebind_ai_actor_state_capability")
	var coordinator_wire_body := _function_body(coordinator_source, "_wire_ai_world_typed_ports")
	_expect(coordinator_enter_body.contains("_prebind_ai_actor_state_capability"), "Coordinator prebinds actor capability from the parent enter-tree callback")
	_expect(coordinator_prebind_body.count("AiActorStateCapability.new()") == 1 and not coordinator_wire_body.contains("AiActorStateCapability.new()"), "Coordinator has one capability creation site and normal wiring only reuses it")
	_expect(port_scene.contains("game_session_runtime_controller_path") and port_scene.contains("role_catalog_runtime_service_path"), "port scene declares session and role authorities")
	_expect(port_source.contains("PUBLIC_PLAYER_SCHEMA_VERSION := 1") and port_source.contains("PUBLIC_PLAYER_ROW_KEYS"), "port source freezes schema-1 exact allowlist")
	var public_snapshot_body := _function_body(port_source, "public_players_snapshot")
	var public_base_body := _function_body(port_source, "_normalized_public_roster_base")
	_expect(not public_snapshot_body.contains("eliminated_at") and not public_snapshot_body.contains("elimination_reason") and not public_base_body.contains("eliminated_at") and not public_base_body.contains("elimination_reason"), "public row and base contain no elimination timing or reason fields")
	_expect(not public_snapshot_body.contains("_public_query_count"), "public snapshot performs no counter mutation")


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
	if _failures.is_empty() and _checks >= 48:
		print("AI public player facts typed-port migration passed (%d checks)." % _checks)
		print("AI_PUBLIC_PLAYER_FACTS_TYPED_PORT_MIGRATION_COMPLETE")
		quit(0)
		return
	push_error("AI public player facts typed-port migration failed (%d checks):\n- %s" % [_checks, "\n- ".join(_failures)])
	quit(1)
