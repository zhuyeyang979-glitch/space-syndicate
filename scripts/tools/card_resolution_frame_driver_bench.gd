extends Node

@export var auto_run := true
var checks := 0
var failures: Array[String] = []


func _ready() -> void:
	if auto_run:
		call_deferred("run_bench")


func run_bench() -> Dictionary:
	checks = 0
	failures.clear()
	var coordinator := get_node_or_null("GameRuntimeCoordinator") as GameRuntimeCoordinator
	_check(coordinator != null, "coordinator exists")
	if coordinator != null:
		var world := coordinator.world_session_state()
		world.replace_players([{"public_name": "local"}, {"public_name": "rival"}], true)
		var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService
		var controller := coordinator.get_node_or_null("CardResolutionRuntimeController") as CardResolutionRuntimeController
		var driver := coordinator.get_node_or_null("CardResolutionFrameDriver") as CardResolutionFrameDriver
		_check(queue != null and controller != null and driver != null, "production timing graph exists")
		if queue != null and controller != null and driver != null:
			queue.replace_active_entry({"resolution_id": 77, "skill": {"kind": "player_hand_disrupt"}})
			controller.begin_active_display(0.25)
			var commands := coordinator.advance_card_resolution_frame(0.25)
			_check(commands.size() == 2, "frame emits reveal and counter commands")
			_check(str((commands[0] as Dictionary).get("transition", "")) == "show_active", "reveal command stays first")
			_check(str((commands[1] as Dictionary).get("transition", "")) == "begin_counter", "counter command stays second")
			_check(int(coordinator.card_resolution_frame_driver_debug().get("tick_count", -1)) == 1, "one frame advances one timing tick")
			_check(not JSON.stringify(coordinator.card_resolution_frame_driver_debug()).contains("cash"), "debug remains privacy-safe")
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures.duplicate()}
	print("CardResolutionFrameDriverBench: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("CardResolutionFrameDriverBench failures:\n- " + "\n- ".join(failures))
	return result


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
