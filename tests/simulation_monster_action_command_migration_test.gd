extends SceneTree

class TestMonster extends MonsterRuntimeController:
	var actor_state := {"uid": 19, "hp": 8, "armor": 0, "position": 0, "action_count": 0}

	func simulation_mutation_snapshot_by_uid(target_uid: int) -> Dictionary:
		return actor_state.duplicate(true) if target_uid == 19 else {}

	func apply_autonomous_action_command(command: Dictionary) -> Dictionary:
		if int(command.get("actor_uid", -1)) != 19:
			return {"accepted": false, "reason": "test_actor_invalid"}
		actor_state["action_count"] = int(actor_state.get("action_count", 0)) + 1
		actor_state["hp"] = int(actor_state.get("hp", 0)) - int(command.get("action", {}).get("damage", 0))
		return {"accepted": true, "action_index": int(command.get("action_index", -1))}


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var identity := SimulationStateIdentity.new()
	var audit := SimulationDeterminismAudit.new()
	audit.bind_identity(identity)
	var authority := SimulationMutationAuthority.new()
	authority.bind_diagnostics(identity, audit)
	var monster := TestMonster.new()
	var sink := MonsterActionCommandSink.new()
	sink.configure(authority, monster)
	var pipeline := RuntimeCommandPipeline.new()
	pipeline.bind_monster_action_sink(sink)
	var command := {
		"command_id": "monster-action:test:1",
		"source": "monster_ai",
		"source_kind": "autonomous_monster",
		"actor_uid": 19,
		"action_index": 0,
		"action": {"name": "测试脉冲", "damage": 2},
		"target_district": 0,
		"occurred_at_world_us": 1000000,
		"sequence": 1,
	}
	var outside := pipeline.dispatch_monster_action(command)
	_check(not bool(outside.get("handled", true)) and str(outside.get("reason", "")).contains("outside_active_step"), "monster action fails closed outside RuntimeSimulationStep")
	_check(int(monster.actor_state.get("action_count", 0)) == 0, "outside-step action cannot mutate actor")
	_check(bool(authority.begin_step(1).get("opened", false)), "monster action authority opens one active step")
	var applied := pipeline.dispatch_monster_action(command)
	_check(bool(applied.get("handled", false)) and int(monster.actor_state.get("action_count", 0)) == 1 and int(monster.actor_state.get("hp", 0)) == 6, "typed monster action reaches sink and mutates once")
	var duplicate := pipeline.dispatch_monster_action(command)
	_check(not bool(duplicate.get("handled", true)) and str(duplicate.get("reason", "")).contains("duplicate"), "duplicate monster action command is rejected")
	_check(audit.recent_mutations().size() == 1, "monster action produces one mutation audit record")
	authority.end_step()
	var left := RuntimeCommandEnvelope.from_monster_action(command)
	var reordered := RuntimeCommandEnvelope.from_monster_action({"sequence": 1, "occurred_at_world_us": 1000000, "target_district": 0, "action": {"damage": 2, "name": "测试脉冲"}, "action_index": 0, "actor_uid": 19, "source": "monster_ai", "source_kind": "autonomous_monster", "command_id": "monster-action:test:1"})
	_check(str(left.get("envelope_fingerprint", "")) == str(reordered.get("envelope_fingerprint", "")), "same action command data has stable fingerprint")
	_check(bool(RuntimeCommandEnvelope.validate(left).get("valid", false)), "monster action command validates as pure data")
	var invalid := left.duplicate(true)
	(invalid["payload"] as Dictionary)["node"] = Node.new()
	_check(not bool(RuntimeCommandEnvelope.validate(invalid).get("valid", true)), "monster action rejects runtime object payload")
	(invalid["payload"] as Dictionary)["node"].free()
	_check(int(pipeline.debug_snapshot().get("supported_command_type_count", 0)) == 4 and bool(pipeline.debug_snapshot().get("monster_action_ready", false)), "pipeline advertises typed monster action")
	var coordinator_scene := load("res://scenes/runtime/GameRuntimeCoordinator.tscn") as PackedScene
	var coordinator := coordinator_scene.instantiate()
	root.add_child(coordinator)
	await process_frame
	var production_pipeline := coordinator.get_node_or_null("RuntimeCommandPipeline") as RuntimeCommandPipeline
	_check(coordinator.get_node_or_null("MonsterActionCommandSink") != null, "production coordinator composes one MonsterActionCommandSink")
	_check(production_pipeline != null and bool(production_pipeline.debug_snapshot().get("monster_action_ready", false)), "production pipeline binds the special-action sink")
	coordinator.queue_free()
	await process_frame
	var source := FileAccess.get_file_as_string("res://scripts/runtime/monster_runtime_controller.gd")
	var body := _function_body(source, "func _auto_special_monster_tick_for_slot(slot: int)", "func apply_autonomous_action_command")
	_check(body.contains("dispatch_autonomous_action_command") and not body.contains("_damage_district(") and not body.contains("_auto_monster_take_damage("), "special action decision emits command without direct mutation")
	print("simulation_monster_action_command_migration_test: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		push_error("\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _function_body(source: String, start_marker: String, end_marker: String) -> String:
	var start := source.find(start_marker)
	var end := source.find(end_marker, start + start_marker.length())
	return source.substr(start, end - start) if start >= 0 and end > start else ""


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
