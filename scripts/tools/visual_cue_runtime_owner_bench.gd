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
		coordinator.reset_visual_cues()
		coordinator.configure_visual_cue_world_bounds(100.0, 100.0)
		coordinator.add_visual_trail(Vector2(10, 10), Vector2(20, 20), Color.WHITE, "move", 1.0)
		coordinator.add_visual_action_callout("怪兽", "攻击", "公开演出", Color.RED, Vector2(20, 20), 1.0)
		coordinator.pulse_visual_district(0, Color.YELLOW)
		var snapshot := coordinator.visual_cue_public_snapshot()
		_check((snapshot.get("movement_trails", []) as Array).size() == 1, "trail is stored")
		_check((snapshot.get("action_callouts", []) as Array).size() == 1, "callout is stored")
		_check(float((coordinator.visual_cue_districts_with_pulses([{"name": "A"}])[0] as Dictionary).get("pulse", 0.0)) > 0.0, "pulse is presentation-only")
		coordinator.advance_visual_cues(2.0)
		_check((coordinator.visual_cue_public_snapshot().get("movement_trails", []) as Array).is_empty(), "world delta expires trail")
		_check(not JSON.stringify(coordinator.visual_cue_debug_snapshot()).contains("公开演出"), "debug omits cue payload")
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures.duplicate()}
	print("VisualCueRuntimeOwnerBench: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("VisualCueRuntimeOwnerBench failures:\n- " + "\n- ".join(failures))
	return result


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
