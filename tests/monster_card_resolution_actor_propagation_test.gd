extends SceneTree

const WORLD_STATE_SCENE := preload("res://scenes/runtime/WorldSessionState.tscn")
const SELECTION_SCENE := preload("res://scenes/runtime/TableSelectionState.tscn")
const WORLD_BRIDGE_SCENE := preload("res://scenes/runtime/MonsterRuntimeWorldBridge.tscn")
const MONSTER_SCENE := preload("res://scenes/runtime/MonsterRuntimeController.tscn")
const ROUTER_SCENE := preload("res://scenes/runtime/CardEffectRuntimeRouter.tscn")
const QUEUE_SCENE := preload("res://scenes/runtime/CardResolutionQueueRuntimeService.tscn")
const EXECUTION_SCENE := preload("res://scenes/runtime/CardResolutionExecutionRuntimeService.tscn")
const CASH_QUERY_SCENE := preload("res://scenes/runtime/MonsterWagerCashCommitmentQueryPort.tscn")
const CASH_MUTATION_SCENE := preload("res://scenes/runtime/PlayerCashMutationPort.tscn")

var _checks := 0
var _failures: Array[String] = []


class FixtureWorld:
	extends Node

	var role_cap_bonus_by_player := {}
	var scenario_signal_count := 0

	func _player_role_card_for_index(player_index: int) -> Dictionary:
		return {"monster_control_limit_bonus": int(role_cap_bonus_by_player.get(player_index, 0))}

	func _can_summon_monster_card_at_district(_skill: Dictionary, district_index: int) -> bool:
		return district_index == 0

	func _district_center(_district_index: int) -> Vector2:
		return Vector2(120.0, 240.0)

	func _owner_damage_cash_total_for_rank(rank: int) -> int:
		return 700 * maxi(1, rank)

	func _first_empty_or_new_slot(player: Dictionary) -> int:
		var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
		for index in range(slots.size()):
			if slots[index] == null:
				return index
		slots.append(null)
		player["slots"] = slots
		return slots.size() - 1

	func _make_skill(skill_name: String) -> Dictionary:
		return {
			"name": skill_name,
			"kind": "monster_bound_action",
			"hp": 48,
			"move": 18.0,
			"duration": 120.0,
			"fixed_skill_count": 1,
			"slots": [],
		}

	func _entity_world_position(entity: Dictionary) -> Vector2:
		return entity.get("world_position", Vector2.ZERO) as Vector2

	func _limited_name_list(names: Array, limit: int = 6, empty_text: String = "无") -> String:
		if names.is_empty():
			return empty_text
		var normalized: Array[String] = []
		for name_variant in names.slice(0, limit):
			normalized.append(str(name_variant))
		return "、".join(normalized)

	func _monster_card_duration_text(skill: Dictionary, _compact: bool = false) -> String:
		return "%ds" % int(skill.get("duration", 0.0))

	func _complete_scenario_signal(_signal_id: String, _public_text: String, _snapshot_key: String = "", _focus_target: String = "") -> bool:
		scenario_signal_count += 1
		return true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_queue_actor_controls_owner_and_skill_recipient()
	_verify_control_cap_uses_queue_actor()
	_verify_upgrade_uses_queue_actor()
	_verify_invalid_actor_is_atomic()
	_verify_queue_and_execution_lineage_preserve_actor()
	_verify_public_output_and_source_boundary()
	_finish()


func _verify_queue_actor_controls_owner_and_skill_recipient() -> void:
	var fixture := _fixture()
	var selection: TableSelectionState = fixture.selection
	var owner: MonsterRuntimeController = fixture.owner
	var state: WorldSessionState = fixture.state
	selection.selected_player = 2
	selection.selected_district = 0
	var receipt := _dispatch(fixture, 0, _monster_skill(owner, 0, 1), 4101)
	var monsters := owner.auto_monsters
	var players := state.players
	_check(bool(receipt.get("resolved", false)), "monster-card dispatch resolves for a valid queue actor")
	_check(monsters.size() == 1 and int((monsters[0] as Dictionary).get("owner", -1)) == 0, "queue actor owns the summoned monster while another player is inspected")
	_check(not (players[0] as Dictionary).get("slots", []).is_empty(), "bound skill is granted to the queue actor")
	_check((players[2] as Dictionary).get("slots", []).is_empty(), "inspected player receives no bound skill")
	_check(int((fixture.world as FixtureWorld).scenario_signal_count) == 1, "scenario eligibility is evaluated once for the valid queue actor")
	_cleanup(fixture)


func _verify_control_cap_uses_queue_actor() -> void:
	var blocked := _fixture()
	var blocked_owner: MonsterRuntimeController = blocked.owner
	(blocked.selection as TableSelectionState).selected_player = 1
	(blocked.selection as TableSelectionState).selected_district = 0
	blocked_owner.auto_monsters = [_seed_actor(blocked_owner, 0, 0)]
	var before_blocked := blocked_owner.auto_monsters.duplicate(true)
	var blocked_receipt := _dispatch(blocked, 0, _monster_skill(blocked_owner, 1, 1), 4201)
	_check(not bool(blocked_receipt.get("resolved", true)), "queue actor at its own cap cannot summon through an inspected player with capacity")
	_check(blocked_owner.auto_monsters == before_blocked, "cap rejection leaves the monster roster unchanged")
	_cleanup(blocked)

	var allowed := _fixture()
	var allowed_owner: MonsterRuntimeController = allowed.owner
	(allowed.selection as TableSelectionState).selected_player = 1
	(allowed.selection as TableSelectionState).selected_district = 0
	allowed_owner.auto_monsters = [_seed_actor(allowed_owner, 0, 1)]
	var allowed_receipt := _dispatch(allowed, 0, _monster_skill(allowed_owner, 1, 1), 4202)
	_check(bool(allowed_receipt.get("resolved", false)), "queue actor with capacity can summon while the inspected player is capped")
	_check(allowed_owner.auto_monsters.size() == 2 and int((allowed_owner.auto_monsters[1] as Dictionary).get("owner", -1)) == 0, "cap check and new owner both use the queue actor")
	_cleanup(allowed)


func _verify_upgrade_uses_queue_actor() -> void:
	var fixture := _fixture()
	var owner: MonsterRuntimeController = fixture.owner
	var state: WorldSessionState = fixture.state
	var selection: TableSelectionState = fixture.selection
	selection.selected_player = 2
	selection.selected_district = 0
	owner.auto_monsters = [
		_seed_actor(owner, 0, 0),
		_seed_actor(owner, 0, 2),
	]
	var upgraded_uid := int((owner.auto_monsters[0] as Dictionary).get("uid", 0))
	var receipt := _dispatch(fixture, 0, _monster_skill(owner, 0, 2), 4301)
	var players := state.players
	_check(bool(receipt.get("resolved", false)), "same-family monster card resolves as an upgrade")
	_check(int((owner.auto_monsters[0] as Dictionary).get("rank", 0)) == 2, "queue actor's same-family monster is upgraded")
	_check(int((owner.auto_monsters[1] as Dictionary).get("rank", 0)) == 1, "inspected player's same-family monster is not upgraded")
	var actor_ledger: Array = (players[0] as Dictionary).get("v06_transaction_ledger", []) as Array
	var expected_transaction_id := "monster:%d:rank.2:role-cash" % upgraded_uid
	_check(int((players[0] as Dictionary).get("cash", 0)) == 1160 and actor_ledger.any(func(row: Variant) -> bool: return row is Dictionary and str((row as Dictionary).get("transaction_id", "")) == expected_transaction_id), "upgrade reward uses the queue actor and stable monster/rank transaction identity")
	_check(not (players[0] as Dictionary).get("slots", []).is_empty() and (players[2] as Dictionary).get("slots", []).is_empty(), "upgrade skill refresh remains bound to the queue actor")
	_cleanup(fixture)


func _verify_invalid_actor_is_atomic() -> void:
	var fixture := _fixture()
	var owner: MonsterRuntimeController = fixture.owner
	var state: WorldSessionState = fixture.state
	var bridge: MonsterRuntimeWorldBridge = fixture.bridge
	var skill := _monster_skill(owner, 0, 1)
	var before_players := state.players.duplicate(true)
	var before_calls := int(bridge.debug_snapshot().get("world_call_count", -1))
	var before_uid := owner.next_auto_monster_uid
	var direct_negative := bool(owner.call("_summon_monster_from_card", -1, skill, 0))
	var direct_overflow := bool(owner.call("_summon_monster_from_card", state.players.size(), skill, 0))
	_check(not direct_negative and not direct_overflow, "MonsterRuntime rejects negative and out-of-range actors")
	_check(owner.auto_monsters.is_empty() and owner.next_auto_monster_uid == before_uid, "invalid actor creates no monster and consumes no owner sequence")
	_check(state.players == before_players and int(bridge.debug_snapshot().get("world_call_count", -2)) == before_calls, "invalid actor performs no skill, log, scenario, or world mutation")
	var router_receipt := _dispatch(fixture, -1, skill, 4401)
	_check(not bool(router_receipt.get("dispatched", true)) and str(router_receipt.get("reason", "")) == "monster_card_actor_invalid", "Router fails closed with the dedicated invalid-actor reason")
	_check(owner.auto_monsters.is_empty() and state.players == before_players, "Router rejection leaves gameplay state unchanged")
	_cleanup(fixture)


func _verify_queue_and_execution_lineage_preserve_actor() -> void:
	var entry := {
		"resolution_id": 4501,
		"queued_order": 4501,
		"player_index": 1,
		"slot_index": 0,
		"selected_district": 0,
		"consumed_on_queue": true,
		"play_cost_paid_on_queue": true,
		"skill": {"name": "QA Monster", "kind": "monster_card", "rank": 1},
	}
	var queue := QUEUE_SCENE.instantiate() as CardResolutionQueueRuntimeService
	var restored_queue := QUEUE_SCENE.instantiate() as CardResolutionQueueRuntimeService
	root.add_child(queue)
	root.add_child(restored_queue)
	queue.replace_active_entry(entry)
	var queue_checkpoint := queue.capture_runtime_checkpoint()
	var queue_restore := restored_queue.restore_runtime_checkpoint(queue_checkpoint)
	_check(bool(queue_restore.get("restored", false)) and int(restored_queue.active_entry().get("player_index", -1)) == 1, "queue checkpoint preserves the frozen actor")

	var execution := EXECUTION_SCENE.instantiate() as CardResolutionExecutionRuntimeService
	var restored_execution := EXECUTION_SCENE.instantiate() as CardResolutionExecutionRuntimeService
	root.add_child(execution)
	root.add_child(restored_execution)
	execution.configure({"ruleset_id": "v0.4"})
	restored_execution.configure({"ruleset_id": "v0.4"})
	var transaction := execution.plan_execution({"active_entry": entry, "skill": entry.skill})
	var duplicate := execution.plan_execution({"active_entry": entry, "skill": entry.skill})
	var execution_restore := restored_execution.apply_save_data(execution.to_save_data())
	var resumed := restored_execution.resume_inflight_execution(4501)
	_check(bool(transaction.get("ready", false)) and not bool(duplicate.get("ready", true)) and str(duplicate.get("reason", "")) == "already_inflight", "execution lineage accepts one plan and rejects an exact replay")
	_check(bool(execution_restore.get("applied", false)) and int((resumed.get("active_entry", {}) as Dictionary).get("player_index", -1)) == 1, "inflight execution save/restore preserves the actor")
	for node in [queue, restored_queue, execution, restored_execution]:
		node.free()


func _verify_public_output_and_source_boundary() -> void:
	var presentation := CardResolutionPresentationPort.new()
	root.add_child(presentation)
	presentation.publish_public_event({
		"event_id": "monster-actor-private",
		"event_kind": "card_aftermath",
		"resolution_id": 4601,
		"card_name": "匿名怪兽卡",
		"status": "resolved",
		"player_index": 2,
		"actor_player_index": 2,
		"hidden_owner": 2,
	})
	var public_text := JSON.stringify(presentation.public_snapshot())
	for forbidden in ["player_index", "actor_player_index", "hidden_owner"]:
		_check(not public_text.contains(forbidden), "public card presentation omits %s" % forbidden)
	presentation.free()

	var router_source := FileAccess.get_file_as_string("res://scripts/runtime/card_effect_runtime_router.gd")
	var monster_source := FileAccess.get_file_as_string("res://scripts/runtime/monster_runtime_controller.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var summon_body := _function_body(monster_source, "func _summon_monster_from_card(", "func _player_monster_control_limit(")
	_check(router_source.contains("_summon_monster_from_card(player_index, skill, int(entry.get(\"selected_district\", -1)))"), "Router explicitly forwards active-entry player_index")
	_check(not summon_body.contains("selected_player") and summon_body.contains("acting_player_index"), "monster-card summon graph has zero selected-player actor reads")
	_check(not main_source.contains("func _summon_monster_from_card("), "monster-card summon routing has no Main implementation")


func _fixture() -> Dictionary:
	var world := FixtureWorld.new()
	var state := WORLD_STATE_SCENE.instantiate() as WorldSessionState
	var selection := SELECTION_SCENE.instantiate() as TableSelectionState
	var bridge := WORLD_BRIDGE_SCENE.instantiate() as MonsterRuntimeWorldBridge
	var owner := MONSTER_SCENE.instantiate() as MonsterRuntimeController
	var router := ROUTER_SCENE.instantiate() as CardEffectRuntimeRouter
	var cash_query := CASH_QUERY_SCENE.instantiate() as MonsterWagerCashCommitmentQueryPort
	var cash_mutation := CASH_MUTATION_SCENE.instantiate() as PlayerCashMutationPort
	var identity := SimulationStateIdentity.new()
	var audit := SimulationDeterminismAudit.new()
	var authority := SimulationMutationAuthority.new()
	var nodes: Array[Node] = [world, state, selection, bridge, owner, router, cash_query, cash_mutation, identity, audit, authority]
	for node in nodes:
		root.add_child(node)
	state.players = _players()
	state.districts = [{"name": "QA Region", "destroyed": false, "center": Vector2(120.0, 240.0)}]
	bridge.bind_world(world)
	bridge.set_world_session_state(state)
	bridge.set_table_selection_state(selection)
	owner.set_world_bridge(bridge)
	cash_query.configure(state, owner)
	authority.bind_diagnostics(identity, audit)
	authority.begin_step(1)
	cash_mutation.configure(state, cash_query, authority)
	owner.set_player_cash_mutation_port(cash_mutation)
	router.set_dependencies(state, selection, owner, null, null, null, null, null, null, null, null)
	return {"world": world, "state": state, "selection": selection, "bridge": bridge, "owner": owner, "router": router, "cash_query": cash_query, "cash_mutation": cash_mutation, "identity": identity, "audit": audit, "authority": authority}


func _players() -> Array:
	var result: Array = []
	for index in range(4):
		result.append({
			"index": index,
			"name": "Player %d" % index,
			"role_name": "QA Role %d" % index,
			"slots": [],
			"cash": 1000,
			"cash_cents": 100000,
			"cash_history": [1000],
			"economic_ledger": [],
			"v06_transaction_ledger": [],
			"total_card_income": 0,
			"total_role_income": 0,
			"role_card": {
				"role_index": index,
				"name": "QA Role %d" % index,
				"monster_control_limit_bonus": 0,
				"monster_upgrade_cash": 160 if index == 0 else 0,
			},
		})
	return result


func _monster_skill(owner: MonsterRuntimeController, catalog_index: int, rank: int) -> Dictionary:
	var catalog: Dictionary = owner.call("_catalog_entry", catalog_index)
	return {
		"name": "%s QA" % str(catalog.get("name", "怪兽")),
		"kind": "monster_card",
		"catalog_index": catalog_index,
		"monster_name": str(catalog.get("name", "怪兽")),
		"rank": rank,
		"hp": maxi(1, int(catalog.get("hp", 40))),
		"move": 18.0,
		"duration": 120.0,
		"fixed_skill_count": 1,
		"starter_play_free": true,
	}


func _seed_actor(owner: MonsterRuntimeController, catalog_index: int, player_index: int) -> Dictionary:
	return owner.call("_make_auto_monster", owner.auto_monsters.size(), catalog_index, 0, player_index, 1) as Dictionary


func _dispatch(fixture: Dictionary, player_index: int, skill: Dictionary, resolution_id: int) -> Dictionary:
	return (fixture.router as CardEffectRuntimeRouter).dispatch({
		"handler_id": "monster_card",
		"active_entry": {
			"resolution_id": resolution_id,
			"queued_order": resolution_id,
			"player_index": player_index,
			"selected_district": 0,
		},
		"skill": skill.duplicate(true),
	})


func _function_body(source: String, start_marker: String, end_marker: String) -> String:
	var start := source.find(start_marker)
	var end := source.find(end_marker, start + start_marker.length())
	return source.substr(start, end - start) if start >= 0 and end > start else ""


func _cleanup(fixture: Dictionary) -> void:
	for key in ["authority", "audit", "identity", "cash_mutation", "cash_query", "router", "owner", "bridge", "selection", "state", "world"]:
		var node: Node = fixture.get(key)
		if node != null and is_instance_valid(node):
			node.free()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("MONSTER CARD ACTOR PROPAGATION: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Monster card resolution actor propagation test passed (%d/%d)." % [_checks, _checks])
		quit(0)
		return
	push_error("Monster card resolution actor propagation test failed (%d/%d):\n- %s" % [_checks - _failures.size(), _checks, "\n- ".join(_failures)])
	quit(1)
