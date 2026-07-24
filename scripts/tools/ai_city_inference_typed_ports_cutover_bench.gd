@tool
extends Node

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

var _checks := 0
var _failures: Array[String] = []
var validation_snapshot: Dictionary = {
	"status": "pending",
	"checks": 0,
	"privacy_leaks": 0,
	"duplicate_mutations": 0,
}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	add_child(coordinator)
	await get_tree().process_frame
	var world := coordinator.world_session_state()
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var actor_port := coordinator.get_node_or_null("AiActorStatePort") as AiActorStatePort
	var region_port := coordinator.get_node_or_null("AiRegionKnowledgeQueryPort") as AiRegionKnowledgeQueryPort
	var command_port := coordinator.get_node_or_null("AiCityInferenceCommandPort") as AiCityInferenceCommandPort
	var game_session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var catalog := coordinator.get_node_or_null("RoleCatalogRuntimeService") as RoleCatalogRuntimeService
	_check(world != null and ai != null and actor_port != null and region_port != null and command_port != null and game_session != null, "production_composition")
	_check(actor_port.is_ready() and region_port.is_ready(), "typed_ports_ready")
	game_session.configure({"ruleset_id": "v0.6"}, {})
	var started_session := game_session.begin_session({"session_id": "ai-city-inference-bench", "scenario_id": "bench", "seed": 31, "player_count": 3})
	_check(str(started_session.get("session_state", "")) == GameSessionRuntimeController.STATE_RUNNING, "game_session_running")

	world.restore({
		"players": _players(catalog),
		"districts": [
			{"region_id": "region.000", "name": "AI-A城", "destroyed": false, "city": {"active": true, "owner": 1, "products": [{"name": "生命"}], "demands": ["能源"]}},
			{"region_id": "region.001", "name": "匿名城", "destroyed": false, "city": {"active": true, "owner": 2, "products": [{"name": "能源"}], "demands": ["生命"], "last_income": 40, "public_clues": ["能源卡牌公开线索"]}},
		],
		"game_time": 10.0,
	}, true)
	var capability := ai.get("_ai_region_knowledge_capability") as AiRegionKnowledgeCapability
	var before_mutation := int(world.debug_snapshot().get("city_inference_mutation_count", 0))
	var snapshot := region_port.actor_intelligence_snapshot(capability, 1)
	var rival_snapshot := region_port.actor_intelligence_snapshot(capability, 2)
	_check(not snapshot.is_empty() and not rival_snapshot.is_empty(), "viewer_scoped_queries")
	_check(int(world.debug_snapshot().get("city_inference_mutation_count", 0)) == before_mutation, "query_zero_mutation")
	var hidden_city := _region_city(snapshot, "region.001")
	_check(int(hidden_city.get("owner", -1)) == -1 and str(hidden_city.get("owner_knowledge", "")) == "public_unknown", "hidden_owner_redacted")

	var revision := str(snapshot.get("owner_revision", ""))
	var first := command_port.submit_guess(capability, "bench:city:1", 1, "region.001", 2, 2, "card", revision)
	var replay := command_port.submit_guess(capability, "bench:city:1", 1, "region.001", 2, 2, "card", revision)
	var conflict := command_port.submit_guess(capability, "bench:city:1", 1, "region.001", 0, 1, "route", revision)
	_check(bool(first.get("applied", false)) and bool(first.get("changed", false)), "typed_command_applied")
	_check(bool(replay.get("idempotent_replay", false)), "exact_once_replay")
	_check(not bool(conflict.get("applied", true)), "command_id_conflict_rejected")
	_check(int(world.debug_snapshot().get("city_inference_mutation_count", 0)) == before_mutation + 1, "duplicate_mutation_zero")
	var after := region_port.actor_intelligence_snapshot(capability, 1)
	var other_after := region_port.actor_intelligence_snapshot(capability, 2)
	_check(int(_region_city(after, "region.001").get("owner", -1)) == 2, "own_guess_visible")
	_check(int(_region_city(other_after, "region.001").get("owner", -1)) == 2 and str(_region_city(other_after, "region.001").get("owner_knowledge", "")) == "actor_own", "other_actor_sees_only_own_city")
	_check(not FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_world_bridge.gd").contains("apply_city_owner_guess"), "generic_bridge_mutation_removed")
	_check(not FileAccess.get_file_as_string("res://scripts/%s.%s" % ["main", "gd"]).contains("CITY_GUESS_CONFIDENCE_"), "main_inference_constants_removed")

	if _failures.is_empty():
		validation_snapshot = {
			"status": "PASS",
			"checks": _checks,
			"privacy_leaks": 0,
			"duplicate_mutations": 0,
		}
		print("AI_CITY_INFERENCE_TYPED_PORTS_BENCH|status=PASS|checks=%d|privacy_leaks=0|duplicate_mutations=0" % _checks)
		if DisplayServer.get_name() == "headless":
			get_tree().quit(0)
		else:
			print("AI_CITY_INFERENCE_TYPED_PORTS_BENCH|event=awaiting_mcp_stop")
		return
	validation_snapshot = {
		"status": "FAIL",
		"checks": _checks,
		"failures": _failures.duplicate(),
		"privacy_leaks": -1,
		"duplicate_mutations": -1,
	}
	push_error("AI city inference typed ports Bench failed: %s" % ", ".join(_failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)


func _players(catalog: RoleCatalogRuntimeService) -> Array:
	var result: Array = []
	var names: Array[String] = ["人类", "AI-A", "AI-B"]
	for player_index in range(names.size()):
		var role := catalog.definition_at(player_index)
		role["role_index"] = player_index
		var is_ai := player_index > 0
		var player := {
			"id": player_index,
			"name": names[player_index],
			"is_ai": is_ai,
			"seat_type": "ai" if is_ai else "human",
			"role_index": player_index,
			"role_card": role,
			"eliminated": false,
			"eliminated_at": -1.0,
			"elimination_reason": "",
			"city_guesses": {},
			"city_guess_confidence": {},
			"city_guess_reasons": {},
		}
		if is_ai:
			player["ai_profile"] = {}
			player["ai_memory"] = {}
		result.append(player)
	return result


func _region_city(snapshot: Dictionary, region_id: String) -> Dictionary:
	for region_variant in snapshot.get("regions", []) as Array:
		if not (region_variant is Dictionary):
			continue
		var region := region_variant as Dictionary
		if str(region.get("region_id", "")) == region_id:
			return (region.get("city", {}) as Dictionary).duplicate(true) \
				if region.get("city", {}) is Dictionary else {}
	return {}


func _check(condition: bool, check_id: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(check_id)
