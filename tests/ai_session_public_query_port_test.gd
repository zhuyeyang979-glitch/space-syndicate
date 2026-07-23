extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const EXPECTED_FIELDS := [
	"session_id", "session_revision", "session_state", "session_finished",
	"world_effective_time", "game_time", "business_cycle_revision",
	"player_count", "district_count", "map_width_m", "map_height_m",
	"challenge_depth", "active_resolution_present", "public_phase",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	coordinator.configure({"ruleset_id": "v0.6"})
	var port := coordinator.get_node_or_null("AiSessionPublicQueryPort") as AiSessionPublicQueryPort
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var world := coordinator.world_session_state()
	var clock := coordinator.get_node_or_null("WorldEffectiveClockRuntimeController") as WorldEffectiveClockRuntimeController
	var market := coordinator.get_node_or_null("ProductMarketRuntimeController") as ProductMarketRuntimeController
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	_expect(port != null and session != null and world != null and clock != null and market != null and queue != null and rng != null, "production composition exposes the session query and all existing authorities")
	_expect(port != null and port.is_ready(), "session public query resolves only explicit domain owners")
	session.configure({"ruleset_id": "v0.6"}, {})
	var started := session.begin_session({
		"session_id": "ai-session-public-focused",
		"scenario_id": "focused",
		"seed": 97,
		"player_count": 4,
		"ai_player_count": 3,
		"difficulty": "深度II",
	})
	world.restore({
		"players": [{"name": "Human", "cash": 999}, {"name": "AI-A"}, {"name": "AI-B"}, {"name": "AI-C"}],
		"districts": [{"region_id": "region:a", "owner_index": 0}, {"region_id": "region:b", "owner_index": 1}],
		"game_time": 12.5,
		"map_width_m": 1600.0,
		"map_height_m": 900.0,
	}, true)
	clock.restore_seconds(9.25)
	var world_before := world.to_save_data()
	var session_before := session.session_summary()
	var clock_before := clock.snapshot()
	var market_before := market.runtime_state_snapshot()
	var queue_before: Dictionary = queue.capture_runtime_checkpoint()
	var rng_before := rng.capture_plan_checkpoint()
	var snapshot := port.public_snapshot()
	var detached := snapshot.duplicate(true)
	detached["session_id"] = "mutated-copy"
	var snapshot_again := port.public_snapshot()
	_expect(snapshot.keys().size() == EXPECTED_FIELDS.size() and _has_exact_fields(snapshot), "snapshot uses the exact public session allowlist")
	_expect(str(started.get("session_state", "")) == GameSessionRuntimeController.STATE_RUNNING and str(snapshot.get("session_id", "")) == "ai-session-public-focused" and int(snapshot.get("session_revision", -1)) == session.session_start_revision(), "session identity and revision come from GameSession authority")
	_expect(not bool(snapshot.get("session_finished", true)) and str(snapshot.get("session_state", "")) == GameSessionRuntimeController.STATE_RUNNING, "running state is projected without Main")
	_expect(is_equal_approx(float(snapshot.get("world_effective_time", -1.0)), 9.25) and is_equal_approx(float(snapshot.get("game_time", -1.0)), 12.5), "effective clock and world time remain distinct typed facts")
	_expect(int(snapshot.get("player_count", -1)) == 4 and int(snapshot.get("district_count", -1)) == 2, "only collection counts cross the session boundary")
	_expect(is_equal_approx(float(snapshot.get("map_width_m", 0.0)), 1600.0) and is_equal_approx(float(snapshot.get("map_height_m", 0.0)), 900.0), "public map dimensions roundtrip")
	_expect(int(snapshot.get("challenge_depth", -1)) == 2 and not bool(snapshot.get("active_resolution_present", true)) and not str(snapshot.get("public_phase", "")).is_empty(), "challenge, active-resolution presence, and public phase are explicit")
	_expect(not snapshot.has("players") and not snapshot.has("districts") and not snapshot.has("cash") and not JSON.stringify(snapshot).contains("999"), "snapshot contains no whole collections or private cash")
	_expect(_pure(snapshot) and snapshot_again.get("session_id") != detached.get("session_id"), "snapshot is detached pure data")
	_expect(world.to_save_data() == world_before and session.session_summary() == session_before and clock.snapshot() == clock_before and market.runtime_state_snapshot() == market_before and queue.capture_runtime_checkpoint() == queue_before and rng.capture_plan_checkpoint() == rng_before, "queries perform zero mutation and consume zero RNG")
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	_expect(ai != null and is_equal_approx(float(ai.game_time), 12.5) and not bool(ai.session_finished), "AiRuntimeController consumes the typed session facts")
	session.finish_session({"outcome_id": "focused-finished"})
	_expect(bool(ai.session_finished), "finished state refreshes through the typed session query")
	var controller_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	_expect(not controller_source.contains("_call_world(&\"_runtime_session_finished\"") and not controller_source.contains("_world_value(&\"game_time\""), "session and time have no generic Main/world fallback")
	var debug := port.debug_snapshot()
	_expect(bool(debug.get("port_ready", false)) and int(debug.get("query_count", 0)) >= 2 and not bool(debug.get("returns_whole_players", true)) and not bool(debug.get("returns_whole_districts", true)) and not bool(debug.get("references_main", true)), "debug evidence records the narrow zero-Main contract")
	coordinator.queue_free()
	await process_frame
	_finish()


func _has_exact_fields(snapshot: Dictionary) -> bool:
	for field_variant in EXPECTED_FIELDS:
		if not snapshot.has(str(field_variant)):
			return false
	return true


func _pure(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT or value is Callable:
		return false
	if value is Dictionary:
		for key in (value as Dictionary):
			if not _pure(key) or not _pure((value as Dictionary)[key]):
				return false
	elif value is Array:
		for item in value as Array:
			if not _pure(item):
				return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AI session public query port passed (%d checks)." % _checks)
		print("AI_SESSION_PUBLIC_QUERY_PORT_COMPLETE")
		quit(0)
		return
	push_error("AI session public query port failures:\n- " + "\n- ".join(_failures))
	quit(1)
