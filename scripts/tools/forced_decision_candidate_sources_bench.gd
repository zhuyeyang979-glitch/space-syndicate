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
		var scheduler := coordinator.get_node_or_null("ForcedDecisionRuntimeScheduler") as ForcedDecisionRuntimeScheduler
		if scheduler != null:
			scheduler.configure(["monster_wager", "counter_response", "other_choice"])
		var target := coordinator.get_node_or_null("CardTargetChoiceRuntimeController") as CardTargetChoiceRuntimeController
		var sources := coordinator.get_node_or_null("ForcedDecisionCandidateSources") as ForcedDecisionCandidateSources
		_check(target != null, "target owner exists")
		_check(sources != null, "candidate sources exist")
		if target != null and sources != null:
			target.begin_choice(CardTargetChoiceRuntimeController.KIND_MONSTER, 0, 1)
			var receipt := coordinator.synchronize_forced_decisions()
			_check(bool(receipt.get("synchronized", false)), "sources synchronize")
			var active := coordinator.active_forced_decision(0)
			_check(str(active.get("kind", "")) == "monster_target_choice", "owner sees private decision")
			_check(not bool(coordinator.active_forced_decision(1).get("visible_to_viewer", true)), "other seat sees anonymous placeholder")
			_check(not JSON.stringify(sources.debug_snapshot()).contains("player_index"), "debug omits private binding")
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures.duplicate()}
	print("ForcedDecisionCandidateSourcesBench: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("ForcedDecisionCandidateSourcesBench failures:\n- " + "\n- ".join(failures))
	return result


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
