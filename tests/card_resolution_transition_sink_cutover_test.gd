extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

class FakeExecutionService extends CardResolutionExecutionRuntimeService:
	var completed_ids: Dictionary = {}

	func resolution_completed(resolution_id: int) -> bool:
		return completed_ids.has(str(resolution_id))

	func plan_execution(request: Dictionary) -> Dictionary:
		var entry: Dictionary = request.get("active_entry", {}) if request.get("active_entry", {}) is Dictionary else {}
		return {
			"status": STATUS_READY,
			"ready": true,
			"resolution_id": int(entry.get("resolution_id", -1)),
			"active_entry": entry.duplicate(true),
			"next_intent": {"intent_type": "fake_intent"},
		}

	func advance_execution(transaction: Dictionary, _receipt: Dictionary) -> Dictionary:
		var result := transaction.duplicate(true)
		result["next_intent"] = {}
		return result

	func finalize_execution(transaction: Dictionary) -> Dictionary:
		var resolution_id := int(transaction.get("resolution_id", -1))
		completed_ids[str(resolution_id)] = true
		var binding := {
			"resolution_id": resolution_id,
			"execution_id": int(transaction.get("execution_id", -1)),
			"resolved": bool(transaction.get("resolved", false)),
			"countered": bool(transaction.get("countered", false)),
			"effect_dispatched": bool(transaction.get("effect_dispatched", false)),
			"history_appended": bool(transaction.get("history_appended", false)),
			"continuation_kind": str(transaction.get("continuation_kind", "normal")),
		}
		return {
			"completed": true,
			"reason": "completed",
			"resolution_id": resolution_id,
			"execution_id": int(transaction.get("execution_id", -1)),
			"resolved": bool(binding["resolved"]),
			"countered": bool(binding["countered"]),
			"effect_dispatched": bool(binding["effect_dispatched"]),
			"history_appended": bool(binding["history_appended"]),
			"continuation_kind": str(binding["continuation_kind"]),
			"settlement_binding": binding,
			"settlement_binding_fingerprint": JSON.stringify(binding).sha256_text(),
		}


class FakeExecutionPort extends CardResolutionExecutionWorldBridge:
	func apply_intent(_transaction: Dictionary) -> Dictionary:
		return {"intent_type": "fake_intent", "handled": true}

	func start_next_transition() -> Dictionary:
		return {"intent_type": "start_next", "started": true, "reason": "started"}

	func lock_batch_transition() -> Dictionary:
		return {"handled": true, "reason": "locked"}

	func settle_finalized_execution(_transaction: Dictionary, _finalized: Dictionary) -> Dictionary:
		return {
			"settled": true,
			"reason": "settled",
			"resolution_id": int(_finalized.get("resolution_id", -1)),
			"execution_id": int(_finalized.get("execution_id", -1)),
			"settlement_binding": (_finalized.get("settlement_binding", {}) as Dictionary).duplicate(true),
			"settlement_binding_fingerprint": str(_finalized.get("settlement_binding_fingerprint", "")),
		}

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	_test_sink_exact_once_and_faults()
	_test_fully_applied_replay_requires_complete_valid_batch()
	_test_all_twelve_transition_handlers()
	_test_execution_lineage_roundtrip()
	_test_public_privacy()
	_test_production_cutover_contract()
	if _failures.is_empty():
		print("Card resolution transition sink cutover test passed. checks=%d" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_fully_applied_replay_requires_complete_valid_batch() -> void:
	var harness := _make_harness(true)
	var controller := harness.controller as CardResolutionRuntimeController
	var sink := harness.sink as CardResolutionTransitionSink
	controller.begin_group_window(11.0, 0, 3)
	var commands: Array = controller.tick(20.0, _group_facts())
	_expect(_transition_names(commands) == ["enter_public_bid", "enter_lock", "show_group_window", "lock_batch"], "replay security fixture emits one complete four-command batch")
	var first := sink.apply_transition_batch(commands)
	_expect(bool(first.get("handled", false)) and int(first.get("command_count", -1)) == 4, "replay security fixture applies the complete batch once")
	var exact_replay := sink.apply_transition_batch(commands)
	_expect(bool(exact_replay.get("replayed", false)) and int(exact_replay.get("command_count", -1)) == 4, "only the exact complete authored batch replays successfully")
	var before_invalid := sink.debug_snapshot()

	var subset: Array = commands.slice(0, commands.size() - 1)
	var subset_receipt := sink.apply_transition_batch(subset)
	_expect(not bool(subset_receipt.get("handled", true)) and str(subset_receipt.get("reason", "")) == "incomplete_transition_batch", "fully-applied command subset fails closed before replay lookup")

	var reordered := commands.duplicate(true)
	var reordered_first: Variant = reordered[0]
	reordered[0] = reordered[1]
	reordered[1] = reordered_first
	var reordered_receipt := sink.apply_transition_batch(reordered)
	_expect(not bool(reordered_receipt.get("handled", true)) and str(reordered_receipt.get("reason", "")) == "non_contiguous_order", "fully-applied reordered batch fails closed")

	var repeated := commands.duplicate(true)
	repeated[1] = (commands[0] as Dictionary).duplicate(true)
	var repeated_receipt := sink.apply_transition_batch(repeated)
	_expect(not bool(repeated_receipt.get("handled", true)) and ["non_contiguous_order", "duplicate_command_id_in_batch"].has(str(repeated_receipt.get("reason", ""))), "fully-applied duplicate command id fails closed")

	var illegal_kind := commands.duplicate(true)
	(illegal_kind[0] as Dictionary)["transition"] = "unknown_transition"
	var illegal_kind_receipt := sink.apply_transition_batch(illegal_kind)
	_expect(not bool(illegal_kind_receipt.get("handled", true)) and str(illegal_kind_receipt.get("reason", "")) == "unknown_transition", "fully-applied illegal transition kind fails closed")

	var bad_fingerprint := commands.duplicate(true)
	(bad_fingerprint[0] as Dictionary)["command_fingerprint"] = "forged"
	var bad_fingerprint_receipt := sink.apply_transition_batch(bad_fingerprint)
	_expect(not bool(bad_fingerprint_receipt.get("handled", true)) and str(bad_fingerprint_receipt.get("reason", "")) == "command_fingerprint_mismatch", "fully-applied fingerprint mismatch fails closed")

	var after_invalid := sink.debug_snapshot()
	_expect(int(after_invalid.get("applied_count", -1)) == int(before_invalid.get("applied_count", -2)), "invalid replay shapes never reapply a transition")
	_expect(int(after_invalid.get("duplicate_count", -1)) == int(before_invalid.get("duplicate_count", -2)), "invalid replay shapes never increment exact-replay accounting")
	_expect(bool(sink.apply_transition_batch(commands).get("replayed", false)), "valid complete replay remains available after rejected replay attempts")

	var next_commands: Array = controller.tick(0.0, _group_facts())
	_expect(_transition_names(next_commands) == ["start_next"] and bool(sink.apply_transition_batch(next_commands).get("handled", false)), "second authored batch applies before cross-batch replay test")
	var mixed := [(commands[0] as Dictionary).duplicate(true), (next_commands[0] as Dictionary).duplicate(true)]
	var mixed_receipt := sink.apply_transition_batch(mixed)
	_expect(not bool(mixed_receipt.get("handled", true)) and str(mixed_receipt.get("reason", "")) == "stale_command_revision", "fully-applied cross-revision batch fails closed")

	_free_harness(harness)


func _test_all_twelve_transition_handlers() -> void:
	var observed: Dictionary = {}

	var active_harness := _make_harness(true)
	var active_controller := active_harness.controller as CardResolutionRuntimeController
	var active_queue := active_harness.queue as CardResolutionQueueRuntimeService
	var active_sink := active_harness.sink as CardResolutionTransitionSink
	active_queue.replace_active_entry({"resolution_id": 41, "player_index": 0, "skill": {"name": "测试牌", "kind": "ordinary"}})
	active_controller.begin_active_display(0.0)
	var active_commands := active_controller.tick(0.1, _active_facts("41", true, 0.0))
	var active_receipt := active_sink.apply_transition_batch(active_commands)
	_expect(bool(active_receipt.get("handled", false)), "show/begin-counter/complete batch routes through the sink")
	_record_transitions(observed, active_commands)

	var start_harness := _make_harness(true)
	var start_controller := start_harness.controller as CardResolutionRuntimeController
	start_controller.batch_locked = true
	var start_commands := start_controller.tick(0.1, _empty_facts())
	_expect(bool((start_harness.sink as CardResolutionTransitionSink).apply_transition_batch(start_commands).get("handled", false)), "start-next transition routes through the typed lifecycle port")
	_record_transitions(observed, start_commands)

	var empty_harness := _make_harness(true)
	var empty_commands := (empty_harness.controller as CardResolutionRuntimeController).tick(0.1, _empty_facts())
	_expect(bool((empty_harness.sink as CardResolutionTransitionSink).apply_transition_batch(empty_commands).get("handled", false)), "hide-overlay transition routes through the public presentation port")
	_record_transitions(observed, empty_commands)

	var large_harness := _make_harness(true)
	var large_controller := large_harness.controller as CardResolutionRuntimeController
	large_controller.begin_group_window(11.0, 0, 3)
	var large_commands := large_controller.tick(20.0, _group_facts())
	_expect(bool((large_harness.sink as CardResolutionTransitionSink).apply_transition_batch(large_commands).get("handled", false)), "large-delta phase and lock batch routes in producer order")
	_record_transitions(observed, large_commands)

	for phase_case in ["planning", "public_bid", "lock"]:
		var ready_harness := _make_harness(true)
		var ready_controller := ready_harness.controller as CardResolutionRuntimeController
		var remaining := 30.0 if phase_case == "planning" else (10.0 if phase_case == "public_bid" else 5.0)
		ready_controller.begin_group_window(remaining, 0, 3)
		ready_controller.set_player_ready(0, true, [0, 1])
		ready_controller.set_player_ready(1, true, [0, 1])
		var ready_commands := ready_controller.tick(0.0, _group_facts())
		_expect(bool((ready_harness.sink as CardResolutionTransitionSink).apply_transition_batch(ready_commands).get("handled", false)), "all-ready %s batch routes through the sink" % phase_case)
		_record_transitions(observed, ready_commands)
		_free_harness(ready_harness)

	var expected := ["show_active", "begin_counter", "complete_active", "start_next", "show_group_window", "enter_public_bid", "enter_lock", "all_ready_public_bid", "all_ready_lock", "all_ready_lock_batch", "lock_batch", "hide_overlay"]
	for transition in expected:
		_expect(observed.has(transition), "sink handler coverage includes %s" % transition)
	for owned_harness in [active_harness, start_harness, empty_harness, large_harness]:
		_free_harness(owned_harness)


func _test_sink_exact_once_and_faults() -> void:
	var harness := _make_harness()
	var controller := harness.controller as CardResolutionRuntimeController
	var sink := harness.sink as CardResolutionTransitionSink
	var presentation := harness.presentation as CardResolutionPresentationPort
	var commands := controller.tick(0.1, _empty_facts())
	_expect(_transition_names(commands) == ["hide_overlay"], "empty frame emits the exact hide-overlay batch")
	var first := sink.apply_transition_batch(commands)
	_expect(bool(first.get("handled", false)) and int(first.get("command_count", -1)) == 1, "sink consumes one validated frame batch")
	_expect(not bool(presentation.public_snapshot().get("overlay", {}).get("visible", true)), "hide transition updates only the scene-owned presentation port")
	var duplicate := sink.apply_transition_batch(commands)
	_expect(bool(duplicate.get("handled", false)) and bool(duplicate.get("replayed", false)) and str(duplicate.get("reason", "")) == "already_applied", "exact command replay is a no-op success")
	_expect(int(sink.debug_snapshot().get("applied_count", -1)) == 1 and int(sink.debug_snapshot().get("duplicate_count", -1)) == 1, "duplicate replay never increments the applied mutation count")

	var saved := (harness.execution as CardResolutionExecutionRuntimeService).to_save_data()
	var restored_harness := _make_harness()
	var restored_controller := restored_harness.controller as CardResolutionRuntimeController
	var restored_sink := restored_harness.sink as CardResolutionTransitionSink
	var restored_apply := (restored_harness.execution as CardResolutionExecutionRuntimeService).apply_save_data(saved)
	_expect(bool(restored_apply.get("transition_checkpoint_restored", false)), "production execution save owner restores the transition producer and applied-command checkpoint")
	var restored_replay := restored_sink.apply_transition_batch(commands)
	_expect(bool(restored_replay.get("replayed", false)), "persisted command lineage rejects replay after load without reapplying")
	var restored_before_invalid := (restored_harness.execution as CardResolutionExecutionRuntimeService).to_save_data()
	var tampered_save := saved.duplicate(true)
	var tampered_checkpoint := (tampered_save.get("transition_controller", {}) as Dictionary).duplicate(true)
	var tampered_lineage := (tampered_checkpoint.get("card_transition_applied_lineage", []) as Array).duplicate(true)
	tampered_lineage.append((tampered_lineage[0] as Dictionary).duplicate(true))
	tampered_checkpoint["card_transition_applied_lineage"] = tampered_lineage
	tampered_save["transition_controller"] = tampered_checkpoint
	var rejected_restore := (restored_harness.execution as CardResolutionExecutionRuntimeService).apply_save_data(tampered_save)
	_expect(not bool(rejected_restore.get("applied", true)) and (restored_harness.execution as CardResolutionExecutionRuntimeService).to_save_data() == restored_before_invalid, "tampered transition checkpoint fails closed before either save owner mutates")

	var before_harness := _make_harness()
	var before_controller := before_harness.controller as CardResolutionRuntimeController
	var before_sink := before_harness.sink as CardResolutionTransitionSink
	var before_commands := before_controller.tick(0.1, _empty_facts())
	var before_id := str((before_commands[0] as Dictionary).get("command_id", ""))
	before_sink.inject_test_failure_before(before_id)
	var before_failure := before_sink.apply_transition_batch(before_commands)
	_expect(not bool(before_failure.get("handled", true)) and str(before_failure.get("reason", "")) == "fault_injected_before_dispatch", "fault-before-dispatch leaves the command unapplied")
	_expect(int(before_controller.transition_lineage_snapshot().get("applied_command_count", -1)) == 0, "fault-before-dispatch writes no lineage")
	_expect(bool(before_sink.apply_transition_batch(before_commands).get("handled", false)), "prepared command resumes successfully after a pre-dispatch fault")

	var after_harness := _make_harness()
	var after_controller := after_harness.controller as CardResolutionRuntimeController
	var after_sink := after_harness.sink as CardResolutionTransitionSink
	var after_commands := after_controller.tick(0.1, _empty_facts())
	var after_id := str((after_commands[0] as Dictionary).get("command_id", ""))
	after_sink.inject_test_failure_after_handler(after_id)
	var after_failure := after_sink.apply_transition_batch(after_commands)
	_expect(not bool(after_failure.get("handled", true)) and str(after_failure.get("reason", "")) == "fault_injected_after_handler", "post-handler fault is observable before lineage finalize")
	_expect(int(after_controller.transition_lineage_snapshot().get("applied_command_count", -1)) == 0, "post-handler fault does not falsely finalize lineage")
	_expect(bool(after_sink.apply_transition_batch(after_commands).get("handled", false)), "idempotent presentation handler resumes and finalizes after a post-handler fault")
	for owned_harness in [harness, restored_harness, before_harness, after_harness]:
		_free_harness(owned_harness)


func _test_execution_lineage_roundtrip() -> void:
	var execution := CardResolutionExecutionRuntimeService.new()
	execution.configure({})
	var apply := execution.apply_save_data({
		"schema_version": 1,
		"transaction_sequence": 9,
		"completed_resolution_ids": [3, 8],
		"inflight_resolution_ids": [],
	})
	_expect(bool(apply.get("applied", false)) and execution.resolution_completed(3) and execution.resolution_completed(8), "execution exact-once IDs restore through the typed save API")
	var saved := execution.to_save_data()
	var restored := CardResolutionExecutionRuntimeService.new()
	restored.configure({})
	var restored_apply := restored.apply_save_data(saved)
	_expect(bool(restored_apply.get("applied", false)) and restored.to_save_data() == saved, "execution lineage save roundtrip is exact")
	var before := restored.to_save_data()
	var invalid := restored.apply_save_data({"schema_version": 1, "transaction_sequence": 0, "completed_resolution_ids": [3, 3], "inflight_resolution_ids": []})
	_expect(not bool(invalid.get("applied", true)) and restored.to_save_data() == before, "invalid execution lineage fails closed without partial mutation")
	execution.free()
	restored.free()


func _test_public_privacy() -> void:
	var presentation := CardResolutionPresentationPort.new()
	var sentinel := "PRIVATE_SENTINEL_7F3A"
	var published := presentation.publish_public_event({
		"event_id": "privacy-event",
		"event_kind": "card_resolution_phase",
		"summary": "公开阶段更新",
		"player_index": 6,
		"cash": sentinel,
		"hand": [sentinel],
		"true_owner": sentinel,
		"ai_plan": {"pressure_bucket": sentinel},
		"aftermath_clue": {"target_player": sentinel, "hidden_owner_id": sentinel},
	})
	var encoded := JSON.stringify(published)
	_expect(bool(published.get("published", false)), "public transition receipt publishes through the allowlisted port")
	for forbidden in ["player_index", "cash", "hand", "true_owner", "ai_plan", "pressure_bucket", "target_player", "hidden_owner_id", sentinel]:
		_expect(not encoded.contains(forbidden), "public transition receipt excludes %s" % forbidden)
	presentation.free()


func _test_production_cutover_contract() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate()
	var sinks := coordinator.find_children("CardResolutionTransitionSink", "", true, false)
	var drivers := coordinator.find_children("CardResolutionFrameDriver", "", true, false)
	_expect(sinks.size() == 1 and drivers.size() == 1, "production composition contains exactly one frame driver and one transition sink")
	var sink_source := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_transition_sink.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/" + "main.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_expect(not sink_source.contains("func _process(") and not sink_source.contains("Main") and not sink_source.contains("current_scene"), "transition sink is not a second tick owner and never discovers Main")
	_expect(coordinator_source.contains("func advance_card_resolution_frame(delta: float) -> Dictionary"), "Coordinator exposes one high-level receipt instead of a command Array")
	_expect(main_source.contains("advance_card_resolution_frame(scaled_delta)") and not main_source.contains("for command_variant in _game_runtime_coordinator_node().advance_card_resolution_frame"), "Main performs one high-level advance and never sees frame commands")
	for retired in ["_apply_card_resolution_controller_transition", "_complete_active_card_resolution", "_start_next_card_resolution", "_lock_card_resolution_batch", "_finish_card_resolution_batch", "_promote_next_card_resolution_batch", "_announce_card_counter_response_window"]:
		_expect(not main_source.contains("func %s(" % retired), "retired Main frame path is physically absent: %s" % retired)
	coordinator.free()


func _make_harness(use_fake_execution: bool = false) -> Dictionary:
	var controller := CardResolutionRuntimeController.new()
	var queue := CardResolutionQueueRuntimeService.new()
	queue.configure({
		"ruleset_id": "v0.6",
		"card_group": {
			"group_seconds": 30,
			"planning_seconds": 20,
			"public_bid_seconds": 5,
			"lock_seconds": 5,
			"opening_extended_windows": 3,
			"opening_group_seconds": 45,
			"opening_planning_seconds": 35,
			"ordinary_card_limit": 1,
			"maximum_with_explicit_capability": 3,
		},
	})
	var world := WorldSessionState.new()
	world.players = [{"name": "本地玩家", "eliminated": false}, {"name": "对手", "eliminated": false}]
	var execution: CardResolutionExecutionRuntimeService = FakeExecutionService.new() if use_fake_execution else CardResolutionExecutionRuntimeService.new()
	execution.configure({})
	execution.set_transition_checkpoint_owner(controller)
	var execution_port: CardResolutionExecutionWorldBridge = FakeExecutionPort.new() if use_fake_execution else CardResolutionExecutionWorldBridge.new()
	var presentation := CardResolutionPresentationPort.new()
	var eligibility := CardPlayEligibilityRuntimeService.new()
	var monster := MonsterRuntimeController.new()
	var sink := CardResolutionTransitionSink.new()
	sink.configure(controller, queue, world, execution, execution_port, presentation, eligibility, monster)
	return {
		"controller": controller,
		"queue": queue,
		"world": world,
		"execution": execution,
		"execution_port": execution_port,
		"presentation": presentation,
		"eligibility": eligibility,
		"monster": monster,
		"sink": sink,
	}


func _empty_facts() -> Dictionary:
	return {
		"queue_empty": true,
		"active_present": false,
		"active_counterable": false,
		"active_id": "",
		"lock_duration": 5.0,
		"public_bid_duration": 5.0,
		"counter_duration": 5.0,
		"active_player_indices": [0, 1],
	}


func _active_facts(active_id: String, counterable: bool, counter_duration: float) -> Dictionary:
	var facts := _empty_facts()
	facts["queue_empty"] = false
	facts["active_present"] = true
	facts["active_counterable"] = counterable
	facts["active_id"] = active_id
	facts["counter_duration"] = counter_duration
	return facts


func _group_facts() -> Dictionary:
	var facts := _empty_facts()
	facts["queue_empty"] = false
	return facts


func _record_transitions(observed: Dictionary, commands: Array) -> void:
	for transition in _transition_names(commands):
		observed[transition] = true


func _free_harness(harness: Dictionary) -> void:
	var freed: Dictionary = {}
	for value in harness.values():
		if value is Node and is_instance_valid(value):
			var instance_id := (value as Node).get_instance_id()
			if not freed.has(instance_id):
				freed[instance_id] = true
				(value as Node).free()


func _transition_names(commands: Array) -> Array[String]:
	var result: Array[String] = []
	for command_variant in commands:
		if command_variant is Dictionary:
			result.append(str((command_variant as Dictionary).get("transition", "")))
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
