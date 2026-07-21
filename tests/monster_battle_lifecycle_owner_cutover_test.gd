extends SceneTree

const MONSTER_SCENE := preload("res://scenes/runtime/MonsterRuntimeController.tscn")
const RNG_SCENE := preload("res://scenes/runtime/RunRngService.tscn")
const BATTLE_LIFECYCLE_POLICY := preload("res://scripts/runtime/monster_battle_lifecycle_policy_v06.gd")

class FakeWorld:
	extends Node

	var logs: Array = []
	var economic_events: Array = []
	var cash_snapshots: Array = []

	func _ruleset_timing_seconds(rule_id: StringName) -> float:
		return 20.0 if rule_id == &"monster_wager_reopen_cooldown_seconds" else 0.0

	func _entity_world_position(entity: Dictionary) -> Vector2:
		var value: Variant = entity.get("world_position", Vector2.ZERO)
		return value if value is Vector2 else Vector2.ZERO

	func _wrapped_distance(from_position: Vector2, to_position: Vector2) -> float:
		return from_position.distance_to(to_position)

	func _monster_action_animation_profile(_monster_name: String, _action: Dictionary, _action_index: int = -1) -> Dictionary:
		return {"profile": "test"}

	func _monster_knockback_model(action_or_skill: Dictionary, _actor: Dictionary = {}) -> Dictionary:
		return {
			"knockback_m": float(action_or_skill.get("knockback", 0.0)),
			"knockback_duration_seconds": 0.5,
		}

	func _start_entity_linear_motion(entity: Dictionary, target_position: Vector2, _speed_mps: float, _source: String, _movement_mode: String = "", _max_distance_m: float = -1.0, _arrival_action: String = "") -> float:
		var before := _entity_world_position(entity)
		entity["world_position"] = target_position
		return before.distance_to(target_position)

	func _advance_entity_linear_motion(_entity: Dictionary, _delta_seconds: float) -> Dictionary:
		return {"moved": 0.0, "arrived": false}

	func _entity_has_linear_motion(_entity: Dictionary) -> bool:
		return false

	func _player_name(player_index: int) -> String:
		return "玩家%d" % player_index

	func _limited_name_list(names: Array, limit: int = 6, empty_text: String = "无") -> String:
		if names.is_empty():
			return empty_text
		return "、".join(names.slice(0, mini(limit, names.size())))

	func _record_player_economic_event(player_index: int, kind: String, label: String, amount: int, detail: String = "") -> void:
		economic_events.append({"player_index": player_index, "kind": kind, "label": label, "amount": amount, "detail": detail})

	func _record_player_cash_snapshot(player_index: int) -> void:
		cash_snapshots.append(player_index)

	func _ai_runtime_call(_method_name: StringName, _arguments: Array = []) -> Variant:
		return null


var _checks := 0
var _failures: Array[String] = []
var _host: Node
var _world: WorldSessionState
var _fake_world: FakeWorld
var _monster: MonsterRuntimeController
var _identity: SimulationStateIdentity
var _audit: SimulationDeterminismAudit
var _authority: SimulationMutationAuthority
var _pipeline: RuntimeCommandPipeline
var _sink: MonsterActionCommandSink


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_fixture()
	_test_decision_and_battle_timers_are_separate()
	_test_opening_attack_command_exact_once()
	_test_save_before_and_after_opening_attack()
	_test_early_end_and_overlap_guards()
	_test_public_privacy_and_source_negative()
	print("MONSTER_BATTLE_LIFECYCLE_OWNER_CUTOVER %d/%d" % [_checks - _failures.size(), _checks])
	_host.free()
	if not _failures.is_empty():
		push_error("\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _build_fixture() -> void:
	_host = Node.new()
	root.add_child(_host)
	_world = WorldSessionState.new()
	_world.name = "WorldSessionState"
	_world.players = [
		{"id": "player-0", "name": "玩家0", "cash": 1000, "cash_cents": 100000, "eliminated": false},
		{"id": "player-1", "name": "玩家1", "cash": 1000, "cash_cents": 100000, "eliminated": false},
	]
	_world.districts = [
		{"name": "A区", "destroyed": false, "miasma": false, "terrain": "land", "products": [], "demands": []},
		{"name": "B区", "destroyed": false, "miasma": false, "terrain": "land", "products": [], "demands": []},
	]
	_world.game_time = 10.0
	_host.add_child(_world)
	_fake_world = FakeWorld.new()
	_fake_world.name = "FakeWorld"
	_host.add_child(_fake_world)
	var rng := RNG_SCENE.instantiate() as RunRngService
	rng.seed = 13
	_host.add_child(rng)
	var bridge := MonsterRuntimeWorldBridge.new()
	bridge.name = "MonsterRuntimeWorldBridge"
	bridge.set_world_session_state(_world)
	bridge.set_rng_service(rng)
	bridge.bind_world(_fake_world)
	_host.add_child(bridge)
	_monster = MONSTER_SCENE.instantiate() as MonsterRuntimeController
	_monster.name = "MonsterRuntimeController"
	_monster.set_world_bridge(bridge)
	_host.add_child(_monster)
	var configured := _monster.configure_battle_lifecycle_v06({"wager_seconds": 15.0, "battle_limit_seconds": 60.0})
	_expect(bool(configured.get("configured", false)), "battle lifecycle rules configure 15s decision plus 60s battle")
	_identity = SimulationStateIdentity.new()
	_audit = SimulationDeterminismAudit.new()
	_audit.bind_identity(_identity)
	_authority = SimulationMutationAuthority.new()
	_authority.bind_diagnostics(_identity, _audit)
	_sink = MonsterActionCommandSink.new()
	_sink.configure(_authority, _monster)
	_pipeline = RuntimeCommandPipeline.new()
	_pipeline.bind_monster_action_sink(_sink)
	_monster.set_runtime_command_pipeline(_pipeline)
	_seed_monsters()


func _test_decision_and_battle_timers_are_separate() -> void:
	var wager_id := _open_wager()
	_expect(wager_id > 0 and _monster.open_wager_decision_count() == 1, "opening a wager creates one forced 15-second decision")
	_monster.tick_battle_lifecycles(10.0)
	var entry := _active_entry(wager_id)
	_expect(is_equal_approx(float(entry.get("decision_remaining_seconds", 0.0)), 15.0), "battle tick cannot consume the decision timer")
	_monster.tick_wager_decisions_realtime(4.0)
	entry = _active_entry(wager_id)
	_expect(is_equal_approx(float(entry.get("decision_remaining_seconds", 0.0)), 11.0) and is_equal_approx(float(entry.get("battle_remaining_seconds", 0.0)), 60.0), "real-time decision tick does not consume battle time")
	_submit_minimum(wager_id, 0, &"a")
	_submit_minimum(wager_id, 1, &"b")
	entry = _active_entry(wager_id)
	_expect(str(entry.get("lifecycle_phase", "")) == BATTLE_LIFECYCLE_POLICY.PHASE_BATTLE and _monster.open_wager_decision_count() == 0, "all responses close the modal decision and enter battle")
	_expect(not _monster.has_open_monster_wager_decision(), "battle phase no longer freezes card play")
	var cash_before := JSON.stringify(_world.players)
	_monster.tick_wager_decisions_realtime(15.0)
	_expect(JSON.stringify(_world.players) == cash_before and is_equal_approx(float(_active_entry(wager_id).get("battle_remaining_seconds", 0.0)), 60.0), "decision tick after closure cannot settle or age the battle")
	_run_battle_step(59.999)
	entry = _active_entry(wager_id)
	_expect(not entry.is_empty() and float(entry.get("battle_remaining_seconds", 0.0)) > 0.0, "battle remains active just before the 60-second cap")
	_run_battle_step(0.002)
	_expect(_active_entry(wager_id).is_empty() and _monster.resolved_wagers_snapshot().size() == 1, "battle settles exactly after the 60-second cap")


func _test_opening_attack_command_exact_once() -> void:
	_seed_monsters()
	var wager_id := _open_wager()
	_submit_minimum(wager_id, 0, &"a")
	_submit_minimum(wager_id, 1, &"b")
	var mutation_count_before := _audit.recent_mutations().size()
	_run_battle_step(0.0)
	var entry := _active_entry(wager_id)
	_expect(bool(entry.get("opening_attack_applied", false)) and not entry.has("pending_attack"), "first battle tick applies the opening strike through the command pipeline once")
	_expect(int((_monster.auto_monsters[1] as Dictionary).get("hp", 0)) == 37, "opening strike damage reaches the target monster")
	_expect(_audit.recent_mutations().size() == mutation_count_before + 1, "opening strike records one simulation mutation audit")
	var command_matches := _monster.monster_battle_opening_attack_command_matches({
		"command_id": str(entry.get("opening_attack_command_id", "")),
		"actor_uid": 101,
		"target_monster_uid": 102,
		"action_index": 0,
		"action": {"name": "测试爪击", "range": 999.0, "damage": 3, "knockback": 0.0},
		"wager_id": wager_id,
		"settlement_revision": int(entry.get("settlement_revision", -1)),
	})
	_expect(command_matches, "owner records the exact applied opening command binding")
	_run_battle_step(1.0)
	_expect(int((_monster.auto_monsters[1] as Dictionary).get("hp", 0)) == 37 and _audit.recent_mutations().size() == mutation_count_before + 1, "later battle ticks do not replay the opening strike")
	var forged := {
		"command_id": str(entry.get("opening_attack_command_id", "")),
		"actor_uid": 101,
		"target_monster_uid": 999,
		"action_kind": "battle_opening_attack",
		"action_index": 0,
		"action": {"name": "测试爪击", "range": 999.0, "damage": 3, "knockback": 0.0},
		"target_district": 0,
		"wager_id": wager_id,
		"settlement_revision": int(entry.get("settlement_revision", -1)),
		"context": "QA opening",
		"source": "monster_battle_lifecycle",
		"occurred_at_world_us": 10000000,
		"sequence": int(entry.get("settlement_revision", 0)),
	}
	var rejected := _pipeline.dispatch_monster_action(forged)
	_expect(not bool(rejected.get("handled", true)) and not str(rejected.get("reason", "")).is_empty(), "forged battle opening command is rejected")


func _test_save_before_and_after_opening_attack() -> void:
	_seed_monsters()
	var wager_id := _open_wager()
	_submit_minimum(wager_id, 0, &"a")
	_submit_minimum(wager_id, 1, &"b")
	var before_attack_save := _monster.to_save_data()
	var restored_before := _restore_monster(before_attack_save)
	_monster = restored_before
	_sink.configure(_authority, _monster)
	_run_battle_step(0.0)
	_expect(int((_monster.auto_monsters[1] as Dictionary).get("hp", 0)) == 37 and bool(_active_entry(wager_id).get("opening_attack_applied", false)), "pre-attack save replays the opening strike once after load")
	var after_attack_save := _monster.to_save_data()
	var restored_after := _restore_monster(after_attack_save)
	_monster = restored_after
	_sink.configure(_authority, _monster)
	var after_load_mutations := _audit.recent_mutations().size()
	_run_battle_step(0.0)
	_expect(int((_monster.auto_monsters[1] as Dictionary).get("hp", 0)) == 37 and _audit.recent_mutations().size() == after_load_mutations, "post-attack save does not replay the already applied opening strike")
	var invalid := after_attack_save.duplicate(true)
	var wagers: Array = invalid.get("active_monster_wagers", []) as Array
	var forged: Dictionary = (wagers[0] as Dictionary).duplicate(true)
	forged["decision_remaining_seconds"] = 4.0
	wagers[0] = forged
	invalid["active_monster_wagers"] = wagers
	var invalid_controller := _restore_monster_without_assert(invalid)
	_expect(invalid_controller == null, "save load rejects a battle with a reopened decision timer")


func _test_early_end_and_overlap_guards() -> void:
	_seed_monsters()
	var wager_id := _open_wager()
	_expect(int(_monster.call("_open_monster_wager_for_pair", 0, 1, "duplicate QA")) == wager_id, "duplicate pair returns the active wager id")
	_expect(int(_monster.call("_open_monster_wager_for_pair", 1, 2, "overlap QA")) == -1, "same monster cannot enter a second unresolved battle")
	_submit_minimum(wager_id, 0, &"a")
	_submit_minimum(wager_id, 1, &"b")
	var target := (_monster.auto_monsters[1] as Dictionary).duplicate(true)
	target["down"] = true
	_monster.auto_monsters[1] = target
	var cash_before := JSON.stringify(_world.players)
	_run_battle_step(0.0)
	_expect(_active_entry(wager_id).is_empty() and _monster.resolved_wagers_snapshot().size() == 1 and JSON.stringify(_world.players) == cash_before, "downed combatant ends battle immediately through the zero-damage settlement branch")
	_world.game_time = 31.0
	_expect(int(_monster.call("_open_monster_wager_for_pair", 0, 2, "third entrant after resolution")) > wager_id, "resolved battle releases the combatants for later encounters")


func _test_public_privacy_and_source_negative() -> void:
	_seed_monsters()
	var wager_id := _open_wager()
	var public := _monster.monster_wager_presentation_for_viewer(0)
	var encoded := JSON.stringify(public)
	for forbidden in ["opening_cash", "locked_competitor_uids", "battle_roster_fingerprint", "pending_attack", "opening_attack_command_id", "owner_truth", "ai_plan"]:
		_expect(not encoded.contains(forbidden), "public wager presentation excludes %s" % forbidden)
	_submit_minimum(wager_id, 0, &"a")
	_submit_minimum(wager_id, 1, &"b")
	var actor_snapshot := _monster.monster_wager_decision_snapshot_for_actor(wager_id, 0)
	_expect(actor_snapshot.is_empty(), "decision query closes when battle starts")
	var monster_source := FileAccess.get_file_as_string("res://scripts/runtime/monster_runtime_controller.gd")
	_expect(monster_source.contains("dispatch_autonomous_action_command") and monster_source.contains("tick_battle_lifecycles"), "battle lifecycle uses typed command dispatch and explicit world tick API")


func _seed_monsters() -> void:
	_monster.reset_state()
	_world.game_time = 10.0
	_world.players = [
		{"id": "player-0", "name": "玩家0", "cash": 1000, "cash_cents": 100000, "eliminated": false},
		{"id": "player-1", "name": "玩家1", "cash": 1000, "cash_cents": 100000, "eliminated": false},
	]
	_monster.configure_battle_lifecycle_v06({"wager_seconds": 15.0, "battle_limit_seconds": 60.0})
	_monster.set_runtime_command_pipeline(_pipeline)
	_monster.next_auto_monster_uid = 104
	_monster.auto_monsters = [
		{"slot": 0, "uid": 101, "name": "怪兽A", "position": 0, "world_position": Vector2(0.0, 0.0), "down": false, "owner": -1, "hp": 40, "max_hp": 40, "armor": 0, "movement_traits": [], "actions": []},
		{"slot": 1, "uid": 102, "name": "怪兽B", "position": 0, "world_position": Vector2(20.0, 0.0), "down": false, "owner": -1, "hp": 40, "max_hp": 40, "armor": 0, "movement_traits": [], "actions": []},
		{"slot": 2, "uid": 103, "name": "怪兽C", "position": 1, "world_position": Vector2(220.0, 0.0), "down": false, "owner": -1, "hp": 40, "max_hp": 40, "armor": 0, "movement_traits": [], "actions": []},
	]


func _open_wager() -> int:
	var pending_attack := {
		"attacker_slot": 0,
		"target_slot": 1,
		"action_index": 0,
		"action": {"name": "测试爪击", "range": 999.0, "damage": 3, "knockback": 0.0},
		"context": "QA opening",
	}
	return int(_monster.call("_open_monster_wager_for_pair", 0, 1, "QA battle lifecycle", pending_attack))


func _submit_minimum(wager_id: int, player_index: int, side: StringName) -> Dictionary:
	var entry := _active_entry(wager_id)
	var percent := int(entry.get("base_percent", 5))
	var receipt := _monster.submit_monster_wager_response(wager_id, player_index, side, percent)
	_expect(bool(receipt.get("applied", false)), "player %d wager response is accepted at the current base percent" % player_index)
	return receipt


func _run_battle_step(delta: float) -> void:
	_expect(bool(_authority.begin_step(_authority.current_step_index() + 1).get("opened", false)), "simulation mutation step opens for battle tick")
	_monster.tick_battle_lifecycles(delta)
	_authority.end_step()


func _active_entry(wager_id: int) -> Dictionary:
	for entry_variant: Variant in _monster.active_monster_wagers:
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("wager_id", -1)) == wager_id:
			return (entry_variant as Dictionary).duplicate(true)
	return {}


func _restore_monster(save_data: Dictionary) -> MonsterRuntimeController:
	var restored := _restore_monster_without_assert(save_data)
	_expect(restored != null, "monster save/load applies valid lifecycle state")
	return restored


func _restore_monster_without_assert(save_data: Dictionary) -> MonsterRuntimeController:
	var restored := MONSTER_SCENE.instantiate() as MonsterRuntimeController
	restored.set_world_bridge(_monster.get("_world_bridge") as MonsterRuntimeWorldBridge)
	restored.configure_battle_lifecycle_v06({"wager_seconds": 15.0, "battle_limit_seconds": 60.0})
	restored.set_runtime_command_pipeline(_pipeline)
	_host.add_child(restored)
	var receipt := restored.apply_save_data(save_data)
	if bool(receipt.get("applied", false)):
		return restored
	restored.queue_free()
	return null


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)
