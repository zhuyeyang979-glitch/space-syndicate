extends Node

const SINK_SCRIPT := preload("res://scripts/runtime/card_target_choice_response_sink.gd")


func _ready() -> void:
	var coordinator := get_node_or_null("GameRuntimeCoordinator") as GameRuntimeCoordinator
	var sink := coordinator.card_target_choice_response_sink() if coordinator != null else null
	var forced_port := coordinator.get_node_or_null("ForcedDecisionResponsePort") if coordinator != null else null
	var checks := [
		coordinator != null,
		sink != null,
		sink != null and sink.get_script() == SINK_SCRIPT,
		forced_port is ForcedDecisionResponsePort,
		bool(sink.debug_snapshot().get("typed_response_required", false)) if sink != null else false,
		not bool(sink.debug_snapshot().get("references_main", true)) if sink != null else false,
		not bool(sink.debug_snapshot().get("owns_target_choice", true)) if sink != null else false,
		not bool(sink.debug_snapshot().get("owns_card_queue", true)) if sink != null else false,
		not bool(sink.debug_snapshot().get("owns_monster_roster", true)) if sink != null else false,
		bool(sink.debug_snapshot().get("choice_reservation_required", false)) if sink != null else false,
		bool(sink.debug_snapshot().get("stable_monster_uid_required", false)) if sink != null else false,
	]
	var passed := 0
	for check in checks:
		if bool(check):
			passed += 1
	print("CARD_TARGET_CHOICE_RESPONSE_SINK_BENCH PASS %d/%d" % [passed, checks.size()])
	if passed != checks.size():
		push_error("CardTargetChoiceResponseSink production composition failed")
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(0 if passed == checks.size() else 1)
