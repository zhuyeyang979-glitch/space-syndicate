extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	var market := coordinator.get_node_or_null("ProductMarketRuntimeController") as ProductMarketRuntimeController
	var monster := coordinator.get_node_or_null("MonsterRuntimeController") as MonsterRuntimeController
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	_expect(market != null and monster != null and ai != null, "production composition exposes market, monster, and AI owners")
	var market_event_connected := false
	if market != null and ai != null:
		market_event_connected = _has_connection(
			market.market_cycle_completed.get_connections(),
			ai,
			&"apply_market_cycle_event"
		)
	_expect(market_event_connected, "market cycles reach AI through one typed scene-owned signal")
	var monster_event_connected := false
	if monster != null and ai != null:
		monster_event_connected = _has_connection(
			monster.monster_wager_opened.get_connections(),
			ai,
			&"apply_monster_wager_open_event"
		)
	_expect(monster_event_connected, "monster wager openings reach AI through one revision-bound signal")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var market_source := FileAccess.get_file_as_string("res://scripts/runtime/product_market_runtime_controller.gd")
	var monster_source := FileAccess.get_file_as_string("res://scripts/runtime/monster_runtime_controller.gd")
	_expect(not main_source.contains("ai_runtime_call") and not main_source.contains("_ai_runtime_call"), "Main has no dynamic AI dispatch or fallback")
	_expect(not coordinator_source.contains("func ai_runtime_call") and not coordinator_source.contains("AiRuntimeController method unavailable"), "coordinator has no arbitrary AI deputy")
	_expect(
		coordinator_source.contains("market_cycle_completed.connect(ai.apply_market_cycle_event)")
			and coordinator_source.contains("monster_wager_opened.connect(ai.apply_monster_wager_open_event)"),
		"composition binds concrete market and monster callbacks"
	)
	_expect(
		ai_source.contains("func apply_market_cycle_event(cycle_count: int)")
			and ai_source.contains("func apply_monster_wager_open_event(wager_id: int, settlement_revision: int)"),
		"AI exposes typed domain events instead of a method-name gateway"
	)
	_expect(
		not monster_source.contains("_ai_runtime_call")
			and monster_source.contains("monster_wager_opened.emit(monster_wager_sequence, _monster_wager_settlement_revision)"),
		"monster owner emits a revision-bound event without Main dispatch"
	)
	var emit_offset := market_source.find("market_cycle_completed.emit(business_cycle_count)")
	var legacy_offset := market_source.find("_world_bridge.call_world(\"_on_product_market_cycle_completed\"")
	_expect(emit_offset >= 0 and legacy_offset > emit_offset, "AI market work stays before legacy cash-history refresh ordering")
	if ai != null:
		var stale_market := ai.apply_market_cycle_event(-1)
		_expect(not bool(stale_market.get("accepted", true)) and str(stale_market.get("reason_code", "")) == "ai_market_cycle_event_stale", "invalid cycle events fail closed")
		var stale_wager := ai.apply_monster_wager_open_event(-1, -1)
		_expect(not bool(stale_wager.get("accepted", true)) and str(stale_wager.get("reason_code", "")) == "ai_monster_wager_open_event_stale", "invalid wager-open events fail closed")
		var debug := ai.debug_snapshot()
		_expect(
			bool(debug.get("typed_market_cycle_event_boundary", false))
				and bool(debug.get("typed_monster_wager_open_event_boundary", false))
				and int(debug.get("market_cycle_event_count", -1)) == 0,
			"debug evidence records typed zero-dispatch boundaries"
		)
	coordinator.queue_free()
	await process_frame
	_finish()


func _has_connection(connections: Array, target: Object, method_name: StringName) -> bool:
	for connection_variant in connections:
		var connection: Dictionary = connection_variant if connection_variant is Dictionary else {}
		var callable_variant: Variant = connection.get("callable")
		if callable_variant is Callable:
			var callback := callable_variant as Callable
			if callback.get_object() == target and callback.get_method() == method_name:
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AI runtime dynamic dispatch retirement passed (%d checks)." % _checks)
		print("AI_RUNTIME_DYNAMIC_DISPATCH_RETIREMENT_COMPLETE")
		quit(0)
		return
	push_error("AI runtime dynamic dispatch retirement failures:\n- " + "\n- ".join(_failures))
	quit(1)