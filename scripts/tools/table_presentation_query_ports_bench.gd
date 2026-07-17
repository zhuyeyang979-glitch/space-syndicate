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
	_check(coordinator != null, "production coordinator exists")
	if coordinator != null:
		var state := coordinator.world_session_state()
		state.replace_players([
			{"name": "本地", "is_ai": false, "cash": 1000, "slots": [{"name": "发展牌", "rank": 1}], "city_guesses": {1: 1}},
			{"name": "AI", "is_ai": true, "cash": 9999, "slots": [{"name": "秘密牌"}], "ai_plan": "SECRET"},
		], true)
		state.replace_districts([
			{"region_id": "a", "name": "甲", "center": Vector2(80, 80), "city": {"owner": 0, "active": true, "level": 1}},
			{"region_id": "b", "name": "乙", "center": Vector2(240, 80), "city": {"owner": 1, "active": true, "level": 1}},
		], true)
		var ports := coordinator.table_presentation_query_ports()
		_check(ports != null, "query ports are production composed")
		_check(coordinator.presentation_authorized_viewer_index() == 0, "local viewer is authorized")
		_check(coordinator.presentation_private_world_projection(0, 0).authorized, "own private query succeeds")
		_check(not coordinator.presentation_private_world_projection(0, 1).authorized, "opponent private query fails closed")
		var public_json := JSON.stringify(coordinator.presentation_public_world_projection().to_dictionary())
		_check(not public_json.contains("9999") and not public_json.contains("秘密牌") and not public_json.contains("SECRET"), "public world projection redacts opponent private values")
		var map_json := JSON.stringify(coordinator.presentation_public_map_projection(0).to_dictionary())
		_check(not map_json.contains("\"owner\"") and not map_json.contains("owner_truth"), "map projection omits owner truth")
		var log_result := coordinator.record_public_log_event(&"bench", &"bench.public", {"message": "公开事件"}, 1, 1.0, "bench-1")
		_check(bool(log_result.get("applied", false)), "typed public log owner accepts a valid receipt")
		var victory := ports.capture_victory_advance({"public_snapshot": {"state": "qualification", "remaining_seconds": 3.0}})
		_check(victory != null and victory.is_valid(), "typed victory presentation receipt is valid")
		var debug := ports.debug_snapshot()
		_check(not bool(debug.get("references_main", true)) and not bool(debug.get("owns_refresh_cadence", true)), "query ports own neither Main access nor cadence")
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures.duplicate()}
	print("TablePresentationQueryPortsBench: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("TablePresentationQueryPortsBench failures:\n- " + "\n- ".join(failures))
	return result


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
