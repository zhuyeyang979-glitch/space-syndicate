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
		world.replace_players([{"action_cooldown": 4.0, "slots": [{"runtime_instance_id": "bench-card", "cooldown_left": 5.0, "lock_left": 6.0}]}], true)
		var receipt := coordinator.advance_card_cooldowns(1.0)
		var player := world.players[0] as Dictionary
		var card := (player.get("slots", []) as Array)[0] as Dictionary
		_check(bool(receipt.get("advanced", false)), "coordinator advances the owner")
		_check(is_equal_approx(float(player.get("action_cooldown", -1.0)), 3.0), "action cooldown advances once")
		_check(is_equal_approx(float(card.get("cooldown_left", -1.0)), 4.0), "card cooldown advances once")
		_check(bool(coordinator.arm_persistent_card_cooldown(0, 0, "bench-card", 8.0).get("armed", false)), "coordinator arms an identity-bound persistent card")
		_check(is_equal_approx(float(card.get("cooldown_left", -1.0)), 8.0), "armed value is visible in the shared state owner")
		_check(not JSON.stringify(coordinator.card_cooldown_debug_snapshot()).contains("cash"), "debug remains privacy-safe")
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures.duplicate()}
	print("CardCooldownRuntimeControllerBench: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("CardCooldownRuntimeControllerBench failures:\n- " + "\n- ".join(failures))
	return result


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
