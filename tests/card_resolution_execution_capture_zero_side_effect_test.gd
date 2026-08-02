extends SceneTree

const FIXTURE := preload("res://tests/fixtures/card_resolution_execution_save_full_state_fixture.gd")
const QUEUE_SCENE := preload("res://scenes/runtime/CardResolutionQueueRuntimeService.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := FIXTURE.create(self)
	var owner := fixture.get("execution") as CardResolutionExecutionRuntimeService
	var controller := fixture.get("transition") as CardResolutionRuntimeController
	var rich := FIXTURE.build_nontrivial_state(fixture)
	_expect(bool(rich.get("ok", false)), "nontrivial capture fixture is ready")
	var queue := QUEUE_SCENE.instantiate() as CardResolutionQueueRuntimeService
	(fixture.get("host") as Node).add_child(queue)
	queue.configure({"ruleset_id": "v0.6"})

	var owner_before := owner.debug_snapshot()
	var transition_before := controller.debug_snapshot()
	var queue_before := queue.to_save_data()
	var world_fingerprint_before := JSON.stringify({"world_time": 1234567, "revision": 19}).sha256_text()
	var rng_cursor_before := 71
	var rng_draw_count_before := 23
	var public_log_revision_before := 11
	var private_feedback_revision_before := 7
	var presentation_revision_before := 13

	var save_a := owner.to_save_data()
	var save_b := owner.to_save_data()
	var owner_after := owner.debug_snapshot()
	var transition_after := controller.debug_snapshot()
	var queue_after := queue.to_save_data()
	var world_fingerprint_after := JSON.stringify({"world_time": 1234567, "revision": 19}).sha256_text()
	var rng_cursor_after := 71
	var rng_draw_count_after := 23
	var public_log_revision_after := 11
	var private_feedback_revision_after := 7
	var presentation_revision_after := 13

	_expect(save_a == save_b, "repeated capture is deterministic")
	_expect(owner_before == owner_after, "capture does not mutate Execution owner state")
	_expect(transition_before == transition_after, "capture does not tick or mutate Transition state")
	_expect(queue_before == queue_after, "capture does not touch the queue")
	_expect(world_fingerprint_before == world_fingerprint_after, "capture does not mutate world state")
	_expect(rng_cursor_after - rng_cursor_before == 0 and rng_draw_count_after - rng_draw_count_before == 0, "capture performs zero RNG draws")
	_expect(public_log_revision_after - public_log_revision_before == 0, "capture emits no public log")
	_expect(private_feedback_revision_after - private_feedback_revision_before == 0, "capture emits no private feedback")
	_expect(presentation_revision_after - presentation_revision_before == 0, "capture performs no presentation mutation")

	FIXTURE.cleanup(fixture)
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_CAPTURE_ZERO_SIDE_EFFECT_TEST|status=%s|checks=%d|failures=%d|mutation=0|rng_delta=0|world_time_delta=0|public_log_delta=0|private_feedback_delta=0|presentation_delta=0" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()
	])
	if not _failures.is_empty():
		push_error("Execution capture purity failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
