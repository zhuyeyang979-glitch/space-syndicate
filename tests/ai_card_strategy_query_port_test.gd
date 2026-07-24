extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const CARD_CATALOG := preload("res://resources/cards/runtime/card_runtime_catalog_v04.tres")
const EXPECTED_ROUTE_DIGEST := "f3b21021d0314416994d7c29f3b9b0eb8ee4e12779502c0f2b44a1713dc9e537"
const EXPECTED_ROUTE_COUNTS := {
	"city_growth": 35,
	"direct_interaction": 20,
	"finance_speculation": 30,
	"intel_supply": 13,
	"monster_pressure": 89,
	"tactical_support": 43,
}

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	coordinator.configure({"ruleset_id": "v0.6"})
	await process_frame
	var port := coordinator.get_node_or_null("AiCardStrategyQueryPort") as AiCardStrategyQueryPort
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	var world := coordinator.world_session_state()
	_expect(
		port != null and ai != null and rng != null and world != null,
		"production composition owns one AI card strategy query port"
	)
	if port == null or ai == null or rng == null or world == null:
		coordinator.queue_free()
		await process_frame
		_finish()
		return
	_expect(
		port.is_ready()
			and port.development_routes().size() == 7
			and bool(port.debug_snapshot().get("returns_pure_data", false)),
		"strategy query reads the valid seven-route public catalog"
	)
	var world_before := world.to_save_data()
	var rng_before := rng.capture_plan_checkpoint()
	var routes: Array[String] = []
	var counts := {}
	for card_id_variant in CARD_CATALOG.ordered_card_ids():
		var card_id := str(card_id_variant)
		var skill := CARD_CATALOG.definition(card_id)
		var skill_before := skill.duplicate(true)
		var route_id := port.route_id_for_card(skill)
		var ai_route_id := str(ai.call("_card_development_route_id", skill))
		_expect(
			route_id == ai_route_id,
			"AI uses the typed strategy route for %s" % card_id
		)
		_expect(
			skill == skill_before,
			"strategy query leaves %s detached facts unchanged" % card_id
		)
		routes.append("%s:%s" % [card_id, route_id])
		counts[route_id] = int(counts.get(route_id, 0)) + 1
	_expect(
		CARD_CATALOG.ordered_card_ids().size() == 230,
		"characterization covers all 230 authored rank resources"
	)
	_expect(
		JSON.stringify(routes).sha256_text() == EXPECTED_ROUTE_DIGEST,
		"candidate route identity and ordering preserve the frozen pre-cutover digest"
	)
	_expect(
		counts == EXPECTED_ROUTE_COUNTS,
		"route distribution preserves the frozen pre-cutover classification"
	)
	_expect(
		world.to_save_data() == world_before
			and rng.capture_plan_checkpoint() == rng_before,
		"strategy queries mutate no world state and consume zero RNG"
	)
	var port_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/ai_card_strategy_query_port.gd"
	)
	for forbidden in [
		"Main",
		"TableSelectionState",
		"GameplayBalanceDiagnostics",
		"WorldSessionState",
		"current_scene",
		"/root/",
		"callv(",
		"has_method(",
	]:
		_expect(
			not port_source.contains(forbidden),
			"strategy query port excludes dependency %s" % forbidden
		)
	var ai_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/ai_runtime_controller.gd"
	)
	var route_helper_start := ai_source.find("func _card_development_route_id(")
	var route_helper_end := ai_source.find(
		"func _development_route_label(",
		route_helper_start
	)
	var route_helper_source := ai_source.substr(
		route_helper_start,
		route_helper_end - route_helper_start
	)
	_expect(
		route_helper_start >= 0 and route_helper_end > route_helper_start
			and route_helper_source.contains("_ai_card_strategy_query_port")
			and not route_helper_source.contains("_gameplay_balance_diagnostics_service"),
		"normal AI card classification cannot enter diagnostics"
	)
	coordinator.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AI card strategy query port passed (%d checks)." % _checks)
		print("AI_CARD_STRATEGY_QUERY_PORT_COMPLETE")
		quit(0)
		return
	push_error("AI card strategy query port failures:\n- " + "\n- ".join(_failures))
	quit(1)