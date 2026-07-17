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
	var service := get_node_or_null("CardResolutionHistoryRuntimeService")
	_check(service != null, "history service exists")
	if service != null:
		service.configure({"history_limit": 2})
		var appended: Dictionary = service.append_resolved({
			"resolution_id": 91,
			"player_index": 2,
			"skill": {"name": "相位否决", "kind": "card_counter"},
			"public_owner_revealed": false,
		})
		_check(bool(appended.get("appended", false)), "resolution appends")
		_check(bool(service.append_resolved({"resolution_id": 91}).get("duplicate", false)), "duplicate is rejected")
		_check(not JSON.stringify(service.public_history_snapshot()).contains("player_index"), "public projection hides actor")
		_check(bool(service.reveal_owner(91, "归属：玩家3").get("revealed", false)), "owner label reveals")
		_check(JSON.stringify(service.public_history_snapshot()).contains("归属：玩家3"), "revealed label reaches public projection")
		var saved: Dictionary = service.to_save_data()
		service.reset_state()
		_check(bool(service.apply_save_data(saved).get("applied", false)) and service.to_save_data() == saved, "save roundtrip is exact")
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures.duplicate()}
	print("CardResolutionHistoryRuntimeServiceBench: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("CardResolutionHistoryRuntimeServiceBench failures:\n- " + "\n- ".join(failures))
	return result


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
