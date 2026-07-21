extends Node

const SINK_SCRIPT := preload("res://scripts/runtime/monster_wager_response_sink.gd")


func _ready() -> void:
	var coordinator := get_node_or_null("GameRuntimeCoordinator") as GameRuntimeCoordinator
	var sink := coordinator.get_node_or_null("MonsterWagerResponseSink") if coordinator != null else null
	var forced_port := coordinator.get_node_or_null("ForcedDecisionResponsePort") if coordinator != null else null
	var checks := [
		coordinator != null,
		sink != null,
		sink != null and sink.get_script() == SINK_SCRIPT,
		forced_port is ForcedDecisionResponsePort,
		bool(sink.debug_snapshot().get("typed_response_required", false)) if sink != null else false,
		bool(sink.debug_snapshot().get("live_action_binding_required", false)) if sink != null else false,
		not bool(sink.debug_snapshot().get("references_main", true)) if sink != null else false,
		not bool(sink.debug_snapshot().get("owns_wager_state", true)) if sink != null else false,
		not bool(sink.debug_snapshot().get("owns_player_cash", true)) if sink != null else false,
		not bool(sink.debug_snapshot().get("owns_public_pool", true)) if sink != null else false,
		not bool(sink.debug_snapshot().get("owns_save_state", true)) if sink != null else false,
	]
	var passed := 0
	for check in checks:
		if bool(check):
			passed += 1
	print("MONSTER_WAGER_RESPONSE_SINK_BENCH PASS %d/%d" % [passed, checks.size()])
	if passed != checks.size():
		push_error("MonsterWagerResponseSink production composition failed")
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(0 if passed == checks.size() else 1)
