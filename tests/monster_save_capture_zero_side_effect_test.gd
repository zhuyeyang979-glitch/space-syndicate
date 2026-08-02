extends SceneTree

const FIXTURE := preload("res://tests/fixtures/monster_save_full_state_fixture.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := FIXTURE.create(self)
	var owner = fixture.get("owner")
	var built := FIXTURE.build_nontrivial_state(fixture)
	_expect(bool(built.get("ok", false)), "zero-side-effect fixture is nontrivial")
	var before := _probe(fixture)
	var save_a: Dictionary = owner.call("to_save_data")
	var between := _probe(fixture)
	var save_b: Dictionary = owner.call("to_save_data")
	var after := _probe(fixture)
	var rng_before: Dictionary = before.get("rng", {})
	var rng_after: Dictionary = after.get("rng", {})
	var rng_delta := int(rng_after.get("draw_count", -1)) - int(rng_before.get("draw_count", -1))
	var world_time_delta := float(after.get("world_time", 0.0)) - float(before.get("world_time", 0.0))
	var public_log_delta := int(after.get("public_log_revision", 0)) - int(before.get("public_log_revision", 0))
	var private_feedback_delta := int(after.get("private_feedback_revision", 0)) - int(before.get("private_feedback_revision", 0))
	var presentation_delta := int(after.get("presentation_revision", 0)) - int(before.get("presentation_revision", 0))
	_expect(not save_a.is_empty() and save_a == save_b, "repeated Monster Save v2 capture is deterministic")
	_expect(before == between and between == after, "capture mutates zero Owner, world, RNG, log, feedback, or presentation state")
	_expect(rng_delta == 0 and world_time_delta == 0.0, "capture consumes no RNG draw and advances no world time")
	_expect(public_log_delta == 0 and private_feedback_delta == 0 and presentation_delta == 0, "capture publishes no log, feedback, or presentation revision")

	FIXTURE.cleanup(fixture)
	await process_frame
	print("MONSTER_SAVE_CAPTURE_ZERO_SIDE_EFFECT_TEST|status=%s|checks=%d|failures=%d|mutation_count=%d|rng_draw_delta=%d|world_time_delta=%s|public_log_delta=%d|private_feedback_delta=%d|presentation_revision_delta=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		0 if before == after else 1,
		rng_delta,
		str(world_time_delta),
		public_log_delta,
		private_feedback_delta,
		presentation_delta,
	])
	quit(0 if _failures.is_empty() else 1)


func _probe(fixture: Dictionary) -> Dictionary:
	var owner = fixture.get("owner")
	var world_state = fixture.get("world_state")
	var world = fixture.get("world")
	var rng = fixture.get("rng")
	var bridge = fixture.get("bridge")
	return {
		"owner": {
			"auto_monsters": owner.auto_monsters.duplicate(true),
			"next_auto_monster_uid": owner.next_auto_monster_uid,
			"next_special_monster_slot": owner.next_special_monster_slot,
			"selected_auto_monster_slot": owner.selected_auto_monster_slot,
			"active_monster_wagers": owner.active_monster_wagers.duplicate(true),
			"resolved_monster_wager_history": owner.resolved_monster_wager_history.duplicate(true),
			"monster_wager_sequence": owner.monster_wager_sequence,
			"monster_timer": owner.monster_timer,
			"special_monster_timer": owner.special_monster_timer,
			"autonomous_move_sequence": int(owner.get("_autonomous_move_sequence")),
			"auto_monster_action_sequence": owner.auto_monster_action_sequence,
			"wager_terminal_journal": (owner.get("_monster_wager_settlement_terminal_journal") as Dictionary).duplicate(true),
			"atomic_reservations": (owner.get("_monster_card_reservations_v06") as Dictionary).duplicate(true),
			"atomic_terminal_journal": (owner.get("_monster_card_terminal_journal_v06") as Dictionary).duplicate(true),
			"atomic_presentation_journal": (owner.get("_monster_card_presentation_journal_v06") as Dictionary).duplicate(true),
			"bankruptcy_estate_journal": (owner.get("_bankruptcy_estate_journal") as Dictionary).duplicate(true),
		},
		"world": world_state.call("capture_envelope_save_data"),
		"world_time": float(world_state.game_time),
		"rng": rng.call("to_save_data"),
		"public_log_revision": int(world.public_log_revision),
		"private_feedback_revision": int(world.private_feedback_revision),
		"presentation_revision": int(world.presentation_revision),
		"presentation_events": world.presentation_events.duplicate(true),
		"economic_events": world.economic_events.duplicate(true),
		"cash_snapshots": world.cash_snapshots.duplicate(true),
		"bridge": bridge.call("debug_snapshot"),
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
