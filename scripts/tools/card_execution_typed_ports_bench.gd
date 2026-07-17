extends Node

@export var auto_run := true

const TYPED_OWNER_NAMES := [
	"CardResolutionHistoryRuntimeService",
	"CardResolutionPresentationPort",
	"CardIntelRuntimeService",
	"CardEffectRuntimeRouter",
	"CardCommitmentRuntimeService",
	"CardCounterSettlementRuntimeService",
	"CardPlaySubmissionRuntimeController",
]

var checks := 0
var failures: Array[String] = []


func _ready() -> void:
	if auto_run:
		call_deferred("run_bench")


func run_bench() -> Dictionary:
	checks = 0
	failures.clear()
	var coordinator := get_node_or_null("GameRuntimeCoordinator") as GameRuntimeCoordinator
	_check(coordinator != null, "production coordinator exists")
	if coordinator != null:
		for owner_name in TYPED_OWNER_NAMES:
			_check(coordinator.find_children(owner_name, "", true, false).size() == 1, "%s exists exactly once" % owner_name)
		var execution := coordinator.get_node_or_null("CardResolutionExecutionWorldBridge") as CardResolutionExecutionWorldBridge
		var submission := coordinator.get_node_or_null("CardPlaySubmissionRuntimeController") as CardPlaySubmissionRuntimeController
		var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
		_check(execution != null and int(execution.debug_snapshot().get("dynamic_main_access_count", -1)) == 0, "execution port has zero Main dynamics")
		_check(submission != null and bool(submission.debug_snapshot().get("shared_human_ai_entry", false)), "shared human/AI submission owner is ready")
		var ai_debug := ai.debug_snapshot() if ai != null else {}
		_check(bool(ai_debug.get("typed_card_submission_bound", false)) and bool(ai_debug.get("typed_card_history_bound", false)), "AI typed dependencies are bound")
	var execution_source := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_execution_world_bridge.gd")
	_check(not execution_source.contains("world.call") and not execution_source.contains("world.get") and not execution_source.contains("world.set"), "source contains no dynamic world access")
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures.duplicate()}
	print("CardExecutionTypedPortsBench: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("CardExecutionTypedPortsBench failures:\n- " + "\n- ".join(failures))
	return result


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
