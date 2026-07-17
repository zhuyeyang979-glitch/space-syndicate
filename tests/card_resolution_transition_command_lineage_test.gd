extends SceneTree

const CONTROLLER_SCENE := "res://scenes/runtime/CardResolutionRuntimeController.tscn"
const EXPECTED_TRANSITIONS := [
	"show_active",
	"begin_counter",
	"complete_active",
	"start_next",
	"show_group_window",
	"enter_public_bid",
	"enter_lock",
	"all_ready_public_bid",
	"all_ready_lock",
	"all_ready_lock_batch",
	"lock_batch",
	"hide_overlay",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(CONTROLLER_SCENE) as PackedScene
	_expect(packed != null, "controller scene loads")
	if packed == null:
		_finish()
		return
	var controller := packed.instantiate() as Node
	root.add_child(controller)
	var observed: Dictionary = {}

	controller.call("reset_state")
	controller.call("begin_active_display", 0.1)
	_record_batch(controller, controller.call("tick", 0.2, _facts(true, true, true, "resolution_counter")), observed)
	_record_batch(controller, controller.call("tick", 6.0, _facts(true, true, true, "resolution_counter")), observed)

	controller.call("reset_state")
	controller.set("batch_locked", true)
	_record_batch(controller, controller.call("tick", 0.0, _facts(false, false)), observed)

	controller.call("reset_state")
	_record_batch(controller, controller.call("tick", 0.0, _facts(true, false)), observed)

	controller.call("reset_state")
	controller.call("begin_group_window", -1.0, 0, 3)
	_record_batch(controller, controller.call("tick", 0.0, _facts(false, false)), observed)
	controller.set("simultaneous_timer", 11.0)
	_record_batch(controller, controller.call("tick", 2.0, _facts(false, false)), observed)
	controller.set("simultaneous_timer", 6.0)
	_record_batch(controller, controller.call("tick", 2.0, _facts(false, false)), observed)

	controller.call("reset_state")
	controller.call("begin_group_window", -1.0, 0, 3)
	_record_batch(controller, controller.call("tick", 60.0, _facts(false, false)), observed)

	controller.call("reset_state")
	controller.call("begin_group_window", -1.0, 0, 3)
	var active_players := [0, 1]
	_set_all_ready(controller, active_players)
	_record_batch(controller, controller.call("tick", 0.0, _facts(false, false, false, "", active_players)), observed)
	_set_all_ready(controller, active_players)
	_record_batch(controller, controller.call("tick", 0.0, _facts(false, false, false, "", active_players)), observed)
	_set_all_ready(controller, active_players)
	_record_batch(controller, controller.call("tick", 0.0, _facts(false, false, false, "", active_players)), observed)

	for transition in EXPECTED_TRANSITIONS:
		_expect(observed.has(transition), "transition %s carries deterministic lineage" % transition)
	_expect(observed.size() == EXPECTED_TRANSITIONS.size(), "producer inventory remains exactly twelve transition kinds")

	_test_complete_order_matrix(packed)
	_test_exact_once_and_ordering(packed)
	_test_save_roundtrip_and_legacy_defaults(packed)
	_test_bounded_lineage(packed)

	controller.queue_free()
	_finish()


func _test_complete_order_matrix(packed: PackedScene) -> void:
	var controller := packed.instantiate() as Node
	root.add_child(controller)
	var trace_index := 0

	controller.call("reset_state")
	controller.call("begin_active_display", 5.0)
	_expect_trace(controller.call("tick", 1.0, _facts(true, true, false, "101")), ["show_active"], trace_index)
	trace_index += 1
	controller.call("reset_state")
	controller.call("begin_active_display", 0.1)
	_expect_trace(controller.call("tick", 0.2, _facts(true, true, true, "resolution_102")), ["show_active", "begin_counter"], trace_index)
	trace_index += 1
	controller.call("reset_state")
	controller.call("begin_active_display", 0.1)
	_expect_trace(controller.call("tick", 0.2, _facts(true, true, true, "103", [], 0.0)), ["show_active", "begin_counter", "complete_active"], trace_index)
	trace_index += 1
	controller.call("reset_state")
	controller.call("begin_active_display", 0.1)
	_expect_trace(controller.call("tick", 0.2, _facts(true, true, false, "104")), ["show_active", "complete_active"], trace_index)
	trace_index += 1
	controller.call("reset_state")
	controller.call("begin_counter", 5.0)
	_expect_trace(controller.call("tick", 1.0, _facts(true, true, true, "105")), ["show_active"], trace_index)
	trace_index += 1
	controller.call("reset_state")
	controller.call("begin_counter", 0.1)
	_expect_trace(controller.call("tick", 0.2, _facts(true, true, true, "106")), ["show_active", "complete_active"], trace_index)
	trace_index += 1

	controller.call("reset_state")
	controller.set("batch_locked", true)
	_expect_trace(controller.call("tick", 0.0, _facts(false, false)), ["start_next"], trace_index)
	trace_index += 1
	controller.call("reset_state")
	_expect_trace(controller.call("tick", 0.0, _facts(true, false)), ["hide_overlay"], trace_index)
	trace_index += 1
	_expect_trace(controller.call("tick", 0.0, _facts(true, false)), [], trace_index)
	trace_index += 1

	controller.call("reset_state")
	controller.call("begin_group_window", -1.0, 0, 3)
	_expect_trace(controller.call("tick", 0.0, _facts(false, false)), ["show_group_window"], trace_index)
	trace_index += 1
	controller.call("reset_state")
	controller.call("begin_group_window", -1.0, 0, 3)
	controller.set("simultaneous_timer", 11.0)
	_expect_trace(controller.call("tick", 2.0, _facts(false, false)), ["enter_public_bid", "show_group_window"], trace_index)
	trace_index += 1
	controller.call("reset_state")
	controller.call("begin_group_window", -1.0, 0, 3)
	controller.set("simultaneous_timer", 6.0)
	_expect_trace(controller.call("tick", 2.0, _facts(false, false)), ["enter_lock", "show_group_window"], trace_index)
	trace_index += 1
	controller.call("reset_state")
	controller.call("begin_group_window", -1.0, 0, 3)
	_expect_trace(controller.call("tick", 60.0, _facts(false, false)), ["enter_public_bid", "enter_lock", "show_group_window", "lock_batch"], trace_index)
	trace_index += 1

	var active_players := [0, 1]
	controller.call("reset_state")
	controller.call("begin_group_window", -1.0, 0, 3)
	_set_all_ready(controller, active_players)
	_expect_trace(controller.call("tick", 0.0, _facts(false, false, false, "", active_players)), ["all_ready_public_bid", "enter_public_bid", "show_group_window"], trace_index)
	trace_index += 1
	_set_all_ready(controller, active_players)
	_expect_trace(controller.call("tick", 0.0, _facts(false, false, false, "", active_players)), ["all_ready_lock", "enter_lock", "show_group_window"], trace_index)
	trace_index += 1
	_set_all_ready(controller, active_players)
	_expect_trace(controller.call("tick", 0.0, _facts(false, false, false, "", active_players)), ["all_ready_lock_batch", "lock_batch"], trace_index)
	trace_index += 1

	_expect(trace_index == 16, "order matrix covers sixteen complete producer traces")
	controller.queue_free()


func _test_exact_once_and_ordering(packed: PackedScene) -> void:
	var controller := packed.instantiate() as Node
	root.add_child(controller)
	controller.call("begin_group_window", -1.0, 0, 3)
	var first_batch: Array = controller.call("tick", 0.0, _facts(false, false))
	_expect(bool((controller.call("validate_transition_batch", first_batch) as Dictionary).get("valid", false)), "fresh complete batch validates without mutation")
	var first_command: Dictionary = first_batch[0]
	var first_mark: Dictionary = controller.call("mark_transition_command_applied", first_command, {"status": "presented"})
	_expect(bool(first_mark.get("accepted", false)), "first command mark is accepted")
	var applied: Dictionary = controller.call(
		"transition_command_applied",
		str(first_command.get("command_id", "")),
		str(first_command.get("command_fingerprint", ""))
	)
	_expect(bool(applied.get("applied", false)), "exact id and fingerprint query reports applied")
	var wrong_fingerprint: Dictionary = controller.call("transition_command_applied", str(first_command.get("command_id", "")), "wrong")
	_expect(not bool(wrong_fingerprint.get("applied", true)) and str(wrong_fingerprint.get("reason", "")) == "applied_fingerprint_mismatch", "applied query fails closed on fingerprint mismatch")
	var duplicate: Dictionary = controller.call("mark_transition_command_applied", first_command, {"status": "presented"})
	_expect(not bool(duplicate.get("accepted", true)) and str(duplicate.get("reason", "")) == "duplicate_command" and bool(duplicate.get("exact_once", false)), "duplicate command is rejected as exact-once replay")

	var active_players := [0, 1]
	_set_all_ready(controller, active_players)
	var ordered_batch: Array = controller.call("tick", 0.0, _facts(false, false, false, "", active_players))
	_expect(ordered_batch.size() == 3 and bool((controller.call("validate_transition_batch", ordered_batch) as Dictionary).get("valid", false)), "multi-command batch validates contiguous producer order")
	var out_of_order: Dictionary = controller.call("mark_transition_command_applied", ordered_batch[2], {})
	_expect(not bool(out_of_order.get("accepted", true)) and str(out_of_order.get("reason", "")) == "out_of_order_command", "later command cannot be marked before earlier command")
	for command_variant in ordered_batch:
		var mark_result: Dictionary = controller.call("mark_transition_command_applied", command_variant as Dictionary, {})
		_expect(bool(mark_result.get("accepted", false)), "ordered command %d is accepted" % int((command_variant as Dictionary).get("order_index", -1)))

	var reordered := ordered_batch.duplicate(true)
	var swap: Variant = reordered[0]
	reordered[0] = reordered[1]
	reordered[1] = swap
	var reordered_result: Dictionary = controller.call("validate_transition_batch", reordered)
	_expect(not bool(reordered_result.get("valid", true)) and str(reordered_result.get("reason", "")) == "non_contiguous_order", "batch validator rejects reordered commands without mutation")
	var tampered := (ordered_batch[0] as Dictionary).duplicate(true)
	tampered["window_phase"] = "tampered"
	var tampered_result: Dictionary = controller.call("validate_transition_batch", [tampered, ordered_batch[1], ordered_batch[2]])
	_expect(not bool(tampered_result.get("valid", true)) and str(tampered_result.get("reason", "")) == "command_fingerprint_mismatch", "batch validator rejects payload tampering")
	var stale_mark: Dictionary = controller.call("mark_transition_command_applied", first_command, {})
	_expect(not bool(stale_mark.get("accepted", true)) and str(stale_mark.get("reason", "")) == "stale_command_revision", "stale command revision fails closed")
	controller.queue_free()


func _test_save_roundtrip_and_legacy_defaults(packed: PackedScene) -> void:
	var source := packed.instantiate() as Node
	root.add_child(source)
	source.call("begin_group_window", -1.0, 0, 3)
	var commands: Array = source.call("tick", 0.0, _facts(false, false))
	source.call("mark_transition_command_applied", commands[0], {"public_receipt": "shown"})
	var before: Dictionary = source.call("transition_lineage_snapshot")
	var save_data: Dictionary = source.call("to_save_data")
	var restored := packed.instantiate() as Node
	root.add_child(restored)
	restored.call("apply_save_data", save_data)
	var after: Dictionary = restored.call("transition_lineage_snapshot")
	_expect(after == before, "save/load restores command revision, order and exact-once lineage exactly")
	var restored_duplicate: Dictionary = restored.call("mark_transition_command_applied", commands[0], {"public_receipt": "shown"})
	_expect(str(restored_duplicate.get("reason", "")) == "duplicate_command", "restored lineage still rejects an already-applied command")

	var legacy := packed.instantiate() as Node
	root.add_child(legacy)
	legacy.call("apply_save_data", {"card_resolution_timer": 2.0})
	var legacy_snapshot: Dictionary = legacy.call("transition_lineage_snapshot")
	_expect(int(legacy_snapshot.get("batch_revision", -1)) == 0 and int(legacy_snapshot.get("applied_command_count", -1)) == 0, "legacy save defaults to empty safe lineage")
	_expect(int(legacy_snapshot.get("last_applied_batch_revision", -2)) == -1 and int(legacy_snapshot.get("last_applied_order_index", -2)) == -1, "legacy save defaults to no applied cursor")
	source.queue_free()
	restored.queue_free()
	legacy.queue_free()


func _test_bounded_lineage(packed: PackedScene) -> void:
	var controller := packed.instantiate() as Node
	root.add_child(controller)
	controller.call("begin_group_window", -1.0, 0, 3)
	var first_command_id := ""
	for index in range(260):
		var commands: Array = controller.call("tick", 0.0, _facts(false, false))
		var command := commands[0] as Dictionary
		if index == 0:
			first_command_id = str(command.get("command_id", ""))
		var mark_result: Dictionary = controller.call("mark_transition_command_applied", command, {"index": index})
		if not bool(mark_result.get("accepted", false)):
			_expect(false, "bounded lineage setup command %d applies" % index)
			break
	var snapshot: Dictionary = controller.call("transition_lineage_snapshot")
	_expect(int(snapshot.get("applied_command_count", 0)) == 256, "applied command lineage is bounded at 256 entries")
	_expect(not (snapshot.get("applied_command_ids", []) as Array).has(first_command_id), "bounded lineage evicts the oldest applied identity")
	controller.queue_free()


func _record_batch(controller: Node, commands: Array, observed: Dictionary) -> void:
	var validation: Dictionary = controller.call("validate_transition_batch", commands)
	_expect(bool(validation.get("valid", false)), "producer batch revision %d validates" % int(validation.get("batch_revision", -1)))
	for command_index in range(commands.size()):
		var command := commands[command_index] as Dictionary
		var transition := str(command.get("transition", ""))
		observed[transition] = true
		_expect(int(command.get("revision", -1)) == int(command.get("batch_revision", -2)), "%s revision aliases the batch revision" % transition)
		_expect(int(command.get("order_index", -1)) == command_index, "%s has deterministic contiguous order" % transition)
		_expect(not str(command.get("command_id", "")).is_empty(), "%s has deterministic command id" % transition)
		_expect(str(command.get("command_fingerprint", "")).length() == 64, "%s has SHA-256 payload fingerprint" % transition)
		_expect(command.has("window_sequence") and command.has("resolution_id"), "%s carries explicit window and safe resolution identity" % transition)
		_expect(str(command.get("visibility_scope", "")) == "public", "%s declares public transition visibility" % transition)
		_expect(bool(command.get("requires_gameplay_mutation", false)) == ["complete_active", "start_next", "lock_batch"].has(transition), "%s declares the correct gameplay mutation boundary" % transition)
		_expect(bool(command.get("requires_presentation_receipt", false)), "%s requires one presentation receipt" % transition)


func _set_all_ready(controller: Node, player_indices: Array) -> void:
	for player_index_variant in player_indices:
		controller.call("set_player_ready", int(player_index_variant), true, player_indices)


func _expect_trace(commands: Array, expected: Array, trace_index: int) -> void:
	var actual: Array[String] = []
	for command_variant in commands:
		actual.append(str((command_variant as Dictionary).get("transition", "")))
	_expect(actual == expected, "complete producer trace %02d is %s" % [trace_index + 1, str(expected)])


func _facts(queue_empty: bool, active_present: bool, counterable: bool = false, active_id: String = "", active_players: Array = [], counter_duration: float = 5.0) -> Dictionary:
	return {
		"queue_empty": queue_empty,
		"active_present": active_present,
		"active_counterable": counterable,
		"active_id": active_id,
		"lock_duration": 5.0,
		"public_bid_duration": 5.0,
		"counter_duration": counter_duration,
		"active_player_indices": active_players.duplicate(),
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("CARD TRANSITION LINEAGE: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Card resolution transition command lineage test passed. checks=%d" % _checks)
		quit(0)
		return
	push_error("Card resolution transition command lineage test failed:\n- %s" % "\n- ".join(_failures))
	quit(1)
