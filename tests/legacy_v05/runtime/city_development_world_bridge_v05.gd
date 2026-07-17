@tool
extends Node
class_name CityDevelopmentWorldBridge

# Historical v0.5 fixture only. Production v0.6 has no city-project share bridge.

const PROJECT_BRIDGE := preload("res://tests/legacy_v05/economy/city_product_project_bridge_v05.gd")

var _world: Node
var _network_controller: Node
var _network_world_bridge: Node
var _product_market_controller: Node
var _capture_count := 0
var _preflight_count := 0
var _commit_count := 0
var _rollback_count := 0
var _event_apply_count := 0
var _last_result: Dictionary = {}
var _applied_event_receipts: Dictionary = {}


func bind_world(world: Node) -> void:
	_world = world


func set_runtime_dependencies(network_controller: Node, network_world_bridge: Node, product_market_controller: Node) -> void:
	_network_controller = network_controller
	_network_world_bridge = network_world_bridge
	_product_market_controller = product_market_controller


func reset_state() -> void:
	_capture_count = 0
	_preflight_count = 0
	_commit_count = 0
	_rollback_count = 0
	_event_apply_count = 0
	_last_result = {}
	_applied_event_receipts.clear()


func has_world() -> bool:
	return _world != null and is_instance_valid(_world)


func capture_settlement_facts(request: Dictionary) -> Dictionary:
	if not has_world():
		return {}
	_capture_count += 1
	var player_index := int(request.get("player_index", -1))
	var district_index := int(request.get("district_index", -1))
	var players_variant: Variant = _world.get("players")
	var districts_variant: Variant = _world.get("districts")
	var players: Array = (players_variant as Array).duplicate(true) if players_variant is Array else []
	var districts: Array = (districts_variant as Array).duplicate(true) if districts_variant is Array else []
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true) if player_index >= 0 and player_index < players.size() and players[player_index] is Dictionary else {}
	var district: Dictionary = (districts[district_index] as Dictionary).duplicate(true) if district_index >= 0 and district_index < districts.size() and districts[district_index] is Dictionary else {}
	var local_products: Array = []
	if district_index >= 0 and district_index < districts.size() and _world.has_method("_district_local_product_names"):
		var local_variant: Variant = _world.call("_district_local_product_names", district_index)
		local_products = (local_variant as Array).duplicate(true) if local_variant is Array else []
	var skill: Dictionary = (request.get("skill", {}) as Dictionary).duplicate(true) if request.get("skill", {}) is Dictionary else {}
	var contribution_units := maxi(1, int(skill.get("contribution_units", 1)))
	var next_transport_level := clampi(int(district.get("transport_level", 2)) + contribution_units, 1, 5)
	var next_transport_score := float(district.get("transport_score", 1.0))
	if _world.has_method("_transport_score_from_level"):
		next_transport_score = float(_world.call("_transport_score_from_level", next_transport_level, str(district.get("terrain", "land")) == "ocean"))
	var center := Vector2.ZERO
	if district_index >= 0 and _world.has_method("_district_center"):
		var center_variant: Variant = _world.call("_district_center", district_index)
		if center_variant is Vector2:
			center = center_variant
	var accent := Color("#67e8f9")
	if player_index >= 0 and _world.has_method("_player_color"):
		var accent_variant: Variant = _world.call("_player_color", player_index)
		if accent_variant is Color:
			accent = accent_variant
	var city_variant: Variant = district.get("city", {})
	var city: Dictionary = (city_variant as Dictionary).duplicate(true) if city_variant is Dictionary else {}
	var network_debug: Dictionary = _network_controller.call("debug_snapshot", -1) if _network_controller != null and _network_controller.has_method("debug_snapshot") else {}
	var market_debug: Dictionary = _product_market_controller.call("debug_snapshot") if _product_market_controller != null and _product_market_controller.has_method("debug_snapshot") else {}
	var facts := {
		"player_index": player_index,
		"district_index": district_index,
		"player_count": players.size(),
		"district_count": districts.size(),
		"game_over": bool(_world.call("_runtime_session_finished")) if _world.has_method("_runtime_session_finished") else false,
		"player_eliminated": bool(_world.call("_player_is_eliminated", player_index)) if player_index >= 0 and player_index < players.size() and _world.has_method("_player_is_eliminated") else false,
		"action_cooldown": float(player.get("action_cooldown", 0.0)),
		"district_destroyed": bool(district.get("destroyed", false)),
		"terrain": str(district.get("terrain", "land")),
		"city_active": not city.is_empty() and bool(city.get("active", true)),
		"player": _pure_data(player),
		"district": _pure_data(district),
		"local_product_ids": _pure_data(local_products),
		"game_time": float(_world.get("game_time")),
		"legacy_turn_seconds": float(_world.call("_legacy_turns_to_seconds", 1)) if _world.has_method("_legacy_turns_to_seconds") else 30.0,
		"project_sequence": int(_network_controller.call("project_sequence")) if _network_controller != null and _network_controller.has_method("project_sequence") else -1,
		"downstream_owner_readiness": {
			"network": bool(network_debug.get("controller_ready", false)),
			"gdp": bool(network_debug.get("controller_ready", false)),
			"market": bool(market_debug.get("controller_ready", false)),
		},
		"next_transport_level": next_transport_level,
		"next_transport_score": next_transport_score,
		"economic_focus_label": str(_world.call("_district_economy_focus_label", str(district.get("economic_focus", "balanced")))) if _world.has_method("_district_economy_focus_label") else str(district.get("economic_focus_label", "均衡区")),
		"district_name": str(district.get("name", "区域")),
		"district_center": {"x": center.x, "y": center.y},
		"district_radius": float(district.get("radius_m", 70.0)),
		"player_accent": "#%s" % accent.to_html(false),
	}
	facts["facts_fingerprint"] = _facts_fingerprint(facts)
	return facts


func capture_site_facts(player_index: int, district_index: int, require_empty_city := true, require_cooldown := false) -> Dictionary:
	var facts := capture_settlement_facts({"player_index": player_index, "district_index": district_index, "skill": {}})
	facts["require_empty_city"] = require_empty_city
	facts["require_cooldown"] = require_cooldown
	return facts


func preflight_settlement(plan: Dictionary) -> Dictionary:
	_preflight_count += 1
	if not _runtime_ready():
		return {"valid": false, "reason": "runtime_dependencies_unavailable", "reason_code": "runtime_dependencies_unavailable", "facts": {}}
	if not bool(plan.get("valid", false)):
		var plan_reason := str(plan.get("reason_code", plan.get("reason", "plan_invalid")))
		return {"valid": false, "reason": plan_reason, "reason_code": plan_reason, "facts": {}}
	var request: Dictionary = plan.get("request", {}) as Dictionary if plan.get("request", {}) is Dictionary else {}
	var facts := capture_settlement_facts(request)
	if facts.is_empty():
		return {"valid": false, "reason": "world_facts_unavailable", "reason_code": "world_facts_unavailable", "facts": {}}
	if str(plan.get("facts_fingerprint", "")) != str(facts.get("facts_fingerprint", "")):
		return {"valid": false, "reason": "world_facts_changed", "reason_code": "world_facts_changed", "facts": facts}
	if int(plan.get("expected_project_sequence", -1)) != int(facts.get("project_sequence", -2)):
		return {"valid": false, "reason": "project_sequence_changed", "reason_code": "project_sequence_changed", "facts": facts}
	return {"valid": true, "reason": "", "reason_code": "", "facts": facts}


func apply_settlement_plan(plan: Dictionary) -> Dictionary:
	var preflight := preflight_settlement(plan)
	if not bool(preflight.get("valid", false)):
		return _failure_receipt(plan, str(preflight.get("reason", "preflight_failed")), false)
	var players_variant: Variant = _world.get("players")
	var districts_variant: Variant = _world.get("districts")
	if not (players_variant is Array) or not (districts_variant is Array):
		return _failure_receipt(plan, "world_state_missing", false)
	var original_players := (players_variant as Array).duplicate(true)
	var original_districts := (districts_variant as Array).duplicate(true)
	var original_selected_product := str(_world.get("selected_trade_product"))
	var network_save: Dictionary = _network_controller.call("to_save_data") if _network_controller.has_method("to_save_data") else {}
	var market_save: Dictionary = _product_market_controller.call("to_save_data") if _product_market_controller.has_method("to_save_data") else {}
	var rng_state: Variant = null
	var rng_variant: Variant = _world.get("rng")
	if rng_variant is RandomNumberGenerator:
		rng_state = (rng_variant as RandomNumberGenerator).state
	var claim_variant: Variant = _network_controller.call("claim_project_sequence_if", int(plan.get("expected_project_sequence", -1)))
	var claim: Dictionary = claim_variant if claim_variant is Dictionary else {}
	if not bool(claim.get("claimed", false)):
		return _failure_receipt(plan, str(claim.get("reason", "project_sequence_claim_failed")), false)
	var players := original_players.duplicate(true)
	var districts := original_districts.duplicate(true)
	var player_index := int(plan.get("player_index", -1))
	var district_index := int(plan.get("district_index", -1))
	if player_index < 0 or player_index >= players.size() or district_index < 0 or district_index >= districts.size():
		_rollback(original_players, original_districts, original_selected_product, network_save, market_save, rng_state)
		return _failure_receipt(plan, "commit_indices_invalid", true)
	# The plan is intentionally pure data. Apply only the owned deltas to copies of
	# the real world records so Vector2/Color values elsewhere in those records stay typed.
	var staged_player: Dictionary = (plan.get("staged_player", {}) as Dictionary).duplicate(true)
	var committed_player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
	committed_player["cities_built"] = int(staged_player.get("cities_built", committed_player.get("cities_built", 0)))
	players[player_index] = committed_player
	var staged_district: Dictionary = (plan.get("staged_district", {}) as Dictionary).duplicate(true)
	var committed_district: Dictionary = (districts[district_index] as Dictionary).duplicate(true)
	committed_district["hp"] = int(staged_district.get("hp", committed_district.get("hp", 10)))
	committed_district["damage"] = int(staged_district.get("damage", committed_district.get("damage", 0)))
	committed_district["transport_level"] = int(staged_district.get("transport_level", committed_district.get("transport_level", 2)))
	committed_district["transport_score"] = float(staged_district.get("transport_score", committed_district.get("transport_score", 1.0)))
	committed_district["city"] = (staged_district.get("city", {}) as Dictionary).duplicate(true) if staged_district.get("city", {}) is Dictionary else {}
	districts[district_index] = committed_district
	_world.set("players", players)
	_world.set("districts", districts)
	_world.set("selected_trade_product", str(plan.get("product_id", "")))
	_invalidate_network_cache()
	var network_variant: Variant = _network_controller.call("refresh_networks")
	var network_receipt: Dictionary = network_variant if network_variant is Dictionary else {}
	if not bool(network_receipt.get("valid", false)):
		_rollback(original_players, original_districts, original_selected_product, network_save, market_save, rng_state)
		return _failure_receipt(plan, "network_refresh_failed", true)
	var market_variant: Variant = _product_market_controller.call("refresh_prices")
	var market_receipt: Dictionary = market_variant if market_variant is Dictionary else {}
	if market_receipt.is_empty():
		_rollback(original_players, original_districts, original_selected_product, network_save, market_save, rng_state)
		return _failure_receipt(plan, "market_refresh_failed", true)
	_invalidate_network_cache()
	var competition := int(_network_controller.call("competition_matches", district_index))
	var breakdown_variant: Variant = _network_controller.call("city_gdp_breakdown", district_index, competition)
	var breakdown: Dictionary = breakdown_variant if breakdown_variant is Dictionary else {}
	if breakdown.is_empty():
		_rollback(original_players, original_districts, original_selected_product, network_save, market_save, rng_state)
		return _failure_receipt(plan, "gdp_refresh_failed", true)
	districts_variant = _world.get("districts")
	districts = (districts_variant as Array).duplicate(true) if districts_variant is Array else []
	if district_index < 0 or district_index >= districts.size() or not (districts[district_index] is Dictionary):
		_rollback(original_players, original_districts, original_selected_product, network_save, market_save, rng_state)
		return _failure_receipt(plan, "district_missing_after_refresh", true)
	var district: Dictionary = (districts[district_index] as Dictionary).duplicate(true)
	var city_variant: Variant = district.get("city", {})
	var city: Dictionary = (city_variant as Dictionary).duplicate(true) if city_variant is Dictionary else {}
	var own_share := 0.0
	var project_gdp := 0
	for project_variant in PROJECT_BRIDGE.private_projects(city, player_index):
		if not (project_variant is Dictionary):
			continue
		var project: Dictionary = project_variant
		if str(project.get("project_id", "")) == str(plan.get("project_id", "")):
			own_share = float(project.get("own_share_percent", 0.0))
			project_gdp = int(project.get("current_gdp", 0))
			break
	_commit_count += 1
	_last_result = {
		"applied": true,
		"reason": "",
		"district_index": district_index,
		"project_id": str(plan.get("project_id", "")),
		"slot_id": str(plan.get("slot_id", "")),
		"generation": int(plan.get("generation", 0)),
		"created_city_surface": bool(plan.get("created_city_surface", false)),
		"rollback_used": false,
	}
	return {
		"applied": true,
		"committed": true,
		"reason": "",
		"reason_code": "",
		"event_receipt_id": "%s:%d" % [str(plan.get("project_id", "")), int(plan.get("expected_project_sequence", -1))],
		"player_index": player_index,
		"district_index": district_index,
		"product_id": str(plan.get("product_id", "")),
		"project_direction": str(plan.get("project_direction", "")),
		"project_id": str(plan.get("project_id", "")),
		"slot_id": str(plan.get("slot_id", "")),
		"slot_index": int(plan.get("slot_index", -1)),
		"generation": int(plan.get("generation", 0)),
		"project_rank": int(plan.get("project_rank", 1)),
		"action_id": str(plan.get("action_id", "")),
		"source_kind": "city_development_card",
		"source_label": str(plan.get("source_label", "城市发展牌")),
		"created_city_surface": bool(plan.get("created_city_surface", false)),
		"current_gdp": project_gdp,
		"own_share_percent": own_share,
		"district_name": str(plan.get("district_name", "区域")),
		"district_center": (plan.get("district_center", {}) as Dictionary).duplicate(true) if plan.get("district_center", {}) is Dictionary else {},
		"district_radius": float(plan.get("district_radius", 70.0)),
		"player_accent": str(plan.get("player_accent", "#67e8f9")),
		"refresh_order": ["network", "market", "gdp", "project_allocation"],
		"network_refresh_checked": true,
		"market_refresh_checked": true,
		"gdp_assignment_checked": true,
		"rollback_used": false,
		"public_receipt": {
			"project_id": str(plan.get("project_id", "")),
			"district_index": district_index,
			"product_id": str(plan.get("product_id", "")),
			"project_direction": str(plan.get("project_direction", "")),
			"created_city_surface": bool(plan.get("created_city_surface", false)),
			"current_gdp": project_gdp,
			"refresh_order": ["network", "market", "gdp", "project_allocation"],
		},
	}


func apply_post_commit_intents(finalized: Dictionary) -> Dictionary:
	if not has_world() or not bool(finalized.get("committed", false)):
		return {"applied": false, "reason": "settlement_not_committed"}
	var receipt_id := str(finalized.get("event_receipt_id", ""))
	if receipt_id != "" and bool(_applied_event_receipts.get(receipt_id, false)):
		return {"applied": false, "reason": "event_receipt_already_applied"}
	var intents: Dictionary = finalized.get("event_intents", {}) as Dictionary if finalized.get("event_intents", {}) is Dictionary else {}
	for event_variant in intents.get("private_economic_events", []):
		if event_variant is Dictionary and _world.has_method("_record_player_economic_event"):
			var event: Dictionary = event_variant
			_world.call("_record_player_economic_event", int(event.get("player_index", -1)), str(event.get("category", "")), str(event.get("source", "")), int(event.get("amount", 0)), str(event.get("detail", "")))
	for effect_variant in intents.get("map_effects", []):
		if effect_variant is Dictionary and _world.has_method("_add_map_event_effect"):
			var effect: Dictionary = effect_variant
			_world.call("_add_map_event_effect", str(effect.get("kind", "")), _point(effect.get("position", {})), Color.from_string(str(effect.get("accent", "#67e8f9")), Color("#67e8f9")), str(effect.get("label", "")), float(effect.get("duration", 1.0)), float(effect.get("radius", 70.0)))
	for pulse_variant in intents.get("district_pulses", []):
		if pulse_variant is Dictionary and _world.has_method("_pulse_district"):
			var pulse: Dictionary = pulse_variant
			_world.call("_pulse_district", int(pulse.get("district_index", -1)), Color.from_string(str(pulse.get("accent", "#67e8f9")), Color("#67e8f9")))
	for callout_variant in intents.get("public_callouts", []):
		if callout_variant is Dictionary and _world.has_method("_add_action_callout"):
			var callout: Dictionary = callout_variant
			_world.call("_add_action_callout", str(callout.get("title", "")), str(callout.get("badge", "")), str(callout.get("detail", "")), Color.from_string(str(callout.get("accent", "#67e8f9")), Color("#67e8f9")), _point(callout.get("position", {})))
	for signal_variant in intents.get("scenario_signals", []):
		if signal_variant is Dictionary and _world.has_method("_complete_scenario_signal"):
			var signal_intent: Dictionary = signal_variant
			_world.call("_complete_scenario_signal", str(signal_intent.get("signal_id", "")), str(signal_intent.get("message", "")), str(signal_intent.get("step", "")), str(signal_intent.get("surface", "")))
	if receipt_id != "":
		_applied_event_receipts[receipt_id] = true
	_event_apply_count += 1
	return {"applied": true, "reason": "", "event_receipt_id": receipt_id}


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": _runtime_ready(),
		"world_bound": has_world(),
		"owns_runtime_state": false,
		"owns_rules": false,
		"capture_count": _capture_count,
		"preflight_count": _preflight_count,
		"commit_count": _commit_count,
		"rollback_count": _rollback_count,
		"event_apply_count": _event_apply_count,
		"last_result": _last_result.duplicate(true),
	}


func _runtime_ready() -> bool:
	return has_world() and _network_controller != null and is_instance_valid(_network_controller) and _network_world_bridge != null and is_instance_valid(_network_world_bridge) and _product_market_controller != null and is_instance_valid(_product_market_controller)


func _rollback(players: Array, districts: Array, selected_product: String, network_save: Dictionary, market_save: Dictionary, rng_state: Variant) -> void:
	_world.set("players", players.duplicate(true))
	_world.set("districts", districts.duplicate(true))
	_world.set("selected_trade_product", selected_product)
	if _network_controller.has_method("apply_save_data"):
		_network_controller.call("apply_save_data", network_save.duplicate(true))
	if _product_market_controller.has_method("apply_save_data"):
		_product_market_controller.call("apply_save_data", market_save.duplicate(true))
	var rng_variant: Variant = _world.get("rng")
	if rng_state != null and rng_variant is RandomNumberGenerator:
		(rng_variant as RandomNumberGenerator).state = int(rng_state)
	_invalidate_network_cache()
	_rollback_count += 1


func _invalidate_network_cache() -> void:
	if _network_world_bridge != null and _network_world_bridge.has_method("invalidate_snapshot_cache"):
		_network_world_bridge.call("invalidate_snapshot_cache")


func _failure_receipt(plan: Dictionary, reason: String, rollback_used: bool) -> Dictionary:
	_last_result = {
		"applied": false,
		"reason": reason,
		"district_index": int(plan.get("district_index", -1)),
		"project_id": str(plan.get("project_id", "")),
		"created_city_surface": bool(plan.get("created_city_surface", false)),
		"rollback_used": rollback_used,
	}
	return {
		"applied": false,
		"committed": false,
		"reason": reason,
		"reason_code": reason,
		"project_id": str(plan.get("project_id", "")),
		"district_index": int(plan.get("district_index", -1)),
		"rollback_used": rollback_used,
	}


func _facts_fingerprint(facts: Dictionary) -> String:
	return JSON.stringify({
		"player_index": int(facts.get("player_index", -1)),
		"district_index": int(facts.get("district_index", -1)),
		"player": facts.get("player", {}),
		"district": facts.get("district", {}),
		"project_sequence": int(facts.get("project_sequence", -1)),
	}).sha256_text()


func _pure_data(value: Variant) -> Variant:
	if value == null or value is bool or value is int or value is float or value is String or value is StringName:
		return str(value) if value is StringName else value
	if value is Vector2:
		return {"x": (value as Vector2).x, "y": (value as Vector2).y}
	if value is Color:
		return "#%s" % (value as Color).to_html(true)
	if value is Array:
		var result: Array = []
		for item in value as Array:
			result.append(_pure_data(item))
		return result
	if value is Dictionary:
		var result := {}
		for key_variant in (value as Dictionary).keys():
			result[str(key_variant)] = _pure_data((value as Dictionary).get(key_variant))
		return result
	return null


func _point(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		return Vector2(float((value as Dictionary).get("x", 0.0)), float((value as Dictionary).get("y", 0.0)))
	return Vector2.ZERO
