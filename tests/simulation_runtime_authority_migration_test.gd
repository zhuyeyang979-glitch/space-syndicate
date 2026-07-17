extends SceneTree

const STEP_SCENE := preload("res://scenes/runtime/RuntimeSimulationStep.tscn")


class TestMonster extends MonsterRuntimeController:
	var hp := 10

	func simulation_mutation_snapshot_by_uid(target_uid: int) -> Dictionary:
		return {"target_monster_uid": target_uid, "hp": hp} if target_uid == 7 else {}

	func apply_external_damage_by_uid(command: Dictionary) -> Dictionary:
		if int(command.get("target_monster_uid", -1)) != 7 or int(command.get("damage", 0)) <= 0:
			return {"accepted": false, "reason": "test_target_rejected", "applied_damage": 0}
		var applied := mini(hp, int(command.get("damage", 0)))
		hp -= applied
		return {"accepted": true, "reason": "", "applied_damage": applied}


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_projection_contract()
	_test_authority_and_mutation_command()
	_test_production_composition_and_negative_gate()
	print("simulation_runtime_authority_migration_test: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		push_error("\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _test_projection_contract() -> void:
	var projection := SimulationStateProjectionContract.build(
		{"monster:7": {"hp": 10}},
		{"player:0": {"balance_fingerprint": "abc"}},
		{"step_index": 2, "active_phase": "simulation"},
		[{"command_type": "military_monster_damage", "command_id": "c1", "order_index": 0}],
		{"world_effective_us": 5000000, "cooldown_us": 1000000},
		{"monster": 2}
	)
	_check(bool(SimulationStateProjectionContract.validate(projection).get("valid", false)), "projection contract accepts the required internal sections")
	var reordered := {"deterministic_timers": projection.deterministic_timers, "pending_commands": projection.pending_commands, "phase_state": projection.phase_state, "resources": projection.resources, "authoritative_entities": projection.authoritative_entities, "owner_revisions": projection.owner_revisions, "schema_version": projection.schema_version}
	var identity := SimulationStateIdentity.new()
	var left := identity.identify(projection)
	var right := identity.identify(reordered)
	_check(left.get("fingerprint") == right.get("fingerprint"), "full projection fingerprint is stable across dictionary insertion order")
	var bad := projection.duplicate(true)
	bad["ui_state"] = {"hovered": true}
	_check(not bool(SimulationStateProjectionContract.validate(bad).get("valid", true)), "projection rejects presentation/UI contamination")
	var node := Node.new()
	bad = projection.duplicate(true)
	bad["authoritative_entities"] = {"node": node}
	_check(not bool(SimulationStateProjectionContract.validate(bad).get("valid", true)), "projection rejects runtime object contamination")
	node.free(); identity.free()


func _test_authority_and_mutation_command() -> void:
	var identity := SimulationStateIdentity.new()
	var audit := SimulationDeterminismAudit.new()
	audit.bind_identity(identity)
	var authority := SimulationMutationAuthority.new()
	authority.bind_diagnostics(identity, audit)
	var monster := TestMonster.new()
	var sink := MilitaryMonsterDamageCommandSink.new()
	sink.configure(authority, monster)
	var pipeline := RuntimeCommandPipeline.new()
	pipeline.bind_military_monster_damage_sink(sink)
	var command := {"command_id": "authority:test:1", "source": "test_military", "source_kind": "military_command", "source_entity_id": "resolution:11", "target_monster_uid": 7, "damage": 3, "occurred_at_world_us": 1000000}
	var outside := pipeline.dispatch_military_monster_damage(command)
	_check(not bool(outside.get("handled", true)) and str(outside.get("reason", "")).contains("outside_active_step"), "mutation command fails closed outside RuntimeSimulationStep")
	_check(monster.hp == 10, "outside-step command cannot mutate monster state")
	_check(bool(authority.begin_step(1).get("opened", false)), "authority opens exactly one active simulation step")
	var applied := pipeline.dispatch_military_monster_damage(command)
	_check(bool(applied.get("handled", false)) and int(applied.get("sink_receipt", {}).get("applied_damage", 0)) == 3, "typed military damage command mutates through the sink")
	_check(monster.hp == 7 and audit.recent_mutations().size() == 1, "mutation owner and audit receive one deterministic mutation")
	var duplicate := pipeline.dispatch_military_monster_damage(command)
	_check(not bool(duplicate.get("handled", true)) and str(duplicate.get("reason", "")).contains("duplicate"), "duplicate command is rejected without a second mutation")
	authority.end_step()
	var after := pipeline.dispatch_military_monster_damage(command)
	_check(not bool(after.get("handled", true)), "closed simulation step rejects subsequent mutation commands")
	_check(int(audit.deterministic_violations().size()) >= 1, "authority bypasses are visible in development violations")
	audit.free(); authority.free(); sink.free(); pipeline.free(); monster.free(); identity.free()


func _test_production_composition_and_negative_gate() -> void:
	var step := STEP_SCENE.instantiate() as RuntimeSimulationStep
	root.add_child(step)
	await process_frame
	_check(step.mutation_authority != null and step.mutation_authority.debug_snapshot().get("ready", false), "production RuntimeSimulationStep composes the mutation authority")
	_check(step.get_child_count() == 4, "production step has one identity, RNG boundary, audit and authority")
	var military_source := FileAccess.get_file_as_string("res://scripts/runtime/military_runtime_controller.gd")
	var monster_source := FileAccess.get_file_as_string("res://scripts/runtime/monster_runtime_controller.gd")
	var pipeline_source := FileAccess.get_file_as_string("res://scripts/runtime/runtime_command_pipeline.gd")
	_check(not military_source.contains("_monster_runtime_controller.take_external_damage("), "military controller no longer owns the legacy direct monster mutation")
	_check(not monster_source.contains("func take_external_damage("), "monster owner no longer exposes the legacy slot-based mutation entry")
	_check(pipeline_source.contains("TYPE_MILITARY_MONSTER_DAMAGE") and pipeline_source.contains("dispatch_military_monster_damage"), "command pipeline exposes the typed military damage command")
	step.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
