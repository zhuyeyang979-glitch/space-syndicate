extends SceneTree

const STEP_SCENE := preload("res://scenes/runtime/RuntimeSimulationStep.tscn")


class TestMonster extends MonsterRuntimeController:
	var actor_state := {
		"uid": 19,
		"hp": 8,
		"position": 0,
		"linear_move_target_district": -1,
		"linear_move_elapsed": 0.0,
	}

	func simulation_mutation_snapshot_by_uid(target_uid: int) -> Dictionary:
		return actor_state.duplicate(true) if target_uid == 19 else {}

	func apply_autonomous_move_command(command: Dictionary) -> Dictionary:
		if int(command.get("actor_uid", -1)) != 19:
			return {"accepted": false, "reason": "test_actor_invalid"}
		var operation := str(command.get("operation", ""))
		if operation == "start":
			actor_state["linear_move_target_district"] = int(command.get("target_district", -1))
			return {"accepted": true, "moved": 0.0, "planned_distance": 300.0, "arrived": false}
		if operation == "advance":
			var delta := float(command.get("delta_seconds", 0.0))
			actor_state["linear_move_elapsed"] = float(actor_state.get("linear_move_elapsed", 0.0)) + delta
			var arrived := float(actor_state["linear_move_elapsed"]) >= 1.0
			if arrived:
				actor_state["position"] = int(actor_state.get("linear_move_target_district", 0))
				actor_state["linear_move_target_district"] = -1
				actor_state["linear_move_elapsed"] = 0.0
			return {"accepted": true, "moved": delta * 100.0, "arrived": arrived}
		if operation == "clear":
			actor_state["linear_move_target_district"] = -1
			return {"accepted": true, "moved": 0.0, "arrived": false}
		return {"accepted": false, "reason": "test_operation_invalid"}


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_command_authority()
	_test_deterministic_command_identity()
	_test_production_composition_and_negative_gate()
	print("simulation_autonomous_behavior_command_migration_test: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		push_error("\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _test_command_authority() -> void:
	var identity := SimulationStateIdentity.new()
	var audit := SimulationDeterminismAudit.new()
	audit.bind_identity(identity)
	var authority := SimulationMutationAuthority.new()
	authority.bind_diagnostics(identity, audit)
	var monster := TestMonster.new()
	var sink := MonsterMoveCommandSink.new()
	sink.configure(authority, monster)
	var pipeline := RuntimeCommandPipeline.new()
	pipeline.bind_monster_move_sink(sink)
	var command := {
		"command_id": "autonomous:test:1",
		"source": "monster_ai",
		"source_kind": "autonomous_monster",
		"actor_uid": 19,
		"operation": "start",
		"target_district": 3,
		"speed_mps": 100.0,
		"occurred_at_world_us": 1000000,
	}
	var outside := pipeline.dispatch_monster_move(command)
	_check(not bool(outside.get("handled", true)) and str(outside.get("reason", "")).contains("outside_active_step"), "autonomous move fails closed outside RuntimeSimulationStep")
	_check(int(monster.actor_state.get("linear_move_target_district", -1)) == -1, "outside-step autonomous command cannot mutate actor")
	_check(bool(authority.begin_step(1).get("opened", false)), "autonomous authority opens one active step")
	var started := pipeline.dispatch_monster_move(command)
	_check(bool(started.get("handled", false)) and int(monster.actor_state.get("linear_move_target_district", -1)) == 3 and float((started.get("sink_receipt", {}) as Dictionary).get("planned_distance", 0.0)) == 300.0, "MonsterMoveCommand reaches the typed sink and preserves its plan receipt")
	var duplicate := pipeline.dispatch_monster_move(command)
	_check(not bool(duplicate.get("handled", true)) and str(duplicate.get("reason", "")).contains("duplicate"), "autonomous command duplicate is rejected")
	var advance := pipeline.dispatch_monster_move({
		"command_id": "autonomous:test:2",
		"source": "monster_ai",
		"source_kind": "autonomous_monster",
		"actor_uid": 19,
		"operation": "advance",
		"delta_seconds": 1.0,
		"occurred_at_world_us": 1000001,
	})
	_check(bool(advance.get("handled", false)) and int(monster.actor_state.get("position", -1)) == 3, "autonomous advance is deterministic and mutates through the sink")
	_check(audit.recent_mutations().size() == 2, "autonomous start and advance produce bounded mutation audit records")
	authority.end_step()
	var after := pipeline.dispatch_monster_move(command)
	_check(not bool(after.get("handled", true)), "autonomous command fails closed after the simulation step")
	identity.free(); audit.free(); authority.free(); sink.free(); pipeline.free(); monster.free()


func _test_deterministic_command_identity() -> void:
	var left := RuntimeCommandEnvelope.from_monster_move({"actor_uid": 19, "operation": "advance", "delta_seconds": 0.25, "source": "monster_ai", "occurred_at_world_us": 2000000, "sequence": 1})
	var right := RuntimeCommandEnvelope.from_monster_move({"sequence": 1, "occurred_at_world_us": 2000000, "source": "monster_ai", "delta_seconds": 0.25, "operation": "advance", "actor_uid": 19})
	_check(left.get("envelope_fingerprint", "") == right.get("envelope_fingerprint", ""), "same autonomous command data has the same envelope fingerprint")
	_check(bool(RuntimeCommandEnvelope.validate(left).get("valid", false)), "typed autonomous command validates as pure data")
	var invalid := left.duplicate(true)
	(invalid["payload"] as Dictionary)["node"] = Node.new()
	_check(not bool(RuntimeCommandEnvelope.validate(invalid).get("valid", true)), "autonomous command rejects runtime object payloads")
	(invalid["payload"] as Dictionary)["node"].free()


func _test_production_composition_and_negative_gate() -> void:
	var coordinator_scene := load("res://scenes/runtime/GameRuntimeCoordinator.tscn") as PackedScene
	var coordinator := coordinator_scene.instantiate()
	root.add_child(coordinator)
	await process_frame
	_check(coordinator.get_node_or_null("MonsterMoveCommandSink") != null, "production coordinator composes one MonsterMoveCommandSink")
	var pipeline := coordinator.get_node_or_null("RuntimeCommandPipeline") as RuntimeCommandPipeline
	_check(pipeline != null and bool(pipeline.debug_snapshot().get("monster_move_ready", false)), "production pipeline binds the autonomous move sink")
	var monster_source := FileAccess.get_file_as_string("res://scripts/runtime/monster_runtime_controller.gd")
	var movement_body := _function_body(monster_source, "func _auto_monster_movement_tick()", "func _next_active_auto_monster_slot()")
	_check(movement_body.contains("dispatch_autonomous_move_command") and not movement_body.contains("_start_entity_linear_motion("), "autonomous movement decision emits commands instead of directly starting motion")
	var update_body := _function_body(monster_source, "func _update_auto_monster_linear_movement(delta: float)", "func _place_auto_miasma")
	_check(update_body.contains("dispatch_autonomous_move_command") and not update_body.contains("_advance_entity_linear_motion("), "autonomous linear movement advances through commands")
	coordinator.queue_free()
	await process_frame


func _function_body(source: String, start_marker: String, end_marker: String) -> String:
	var start := source.find(start_marker)
	var end := source.find(end_marker, start + start_marker.length())
	return source.substr(start, end - start) if start >= 0 and end > start else ""


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
