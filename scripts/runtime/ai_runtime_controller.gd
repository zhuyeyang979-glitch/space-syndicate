@tool
extends Node
class_name AiRuntimeController

const CardPlayRequirementPolicyScript := preload("res://scripts/cards/card_play_requirement_policy.gd")
const DEFAULT_POLICY_PROFILE := preload("res://resources/ai/ai_policy_profile_v1.tres")
const AiV06EconomyActionPortScript := preload("res://scripts/runtime/ai_v06_economy_action_port.gd")

const AI_V06_FACILITY_BOOTSTRAP_POLICY_KIND := "v06_facility_bootstrap"
const AI_V06_FACILITY_CATEGORY := "facility"
const AI_V06_FACILITY_EFFECT_KIND := "build_upgrade_or_repair_facility"

@export var policy_profile: Resource = DEFAULT_POLICY_PROFILE

var _world_bridge: Node
var _monster_runtime_controller: MonsterRuntimeController
var _military_runtime_controller: MilitaryRuntimeController
var _weather_runtime_controller: WeatherRuntimeController
var _contract_runtime_controller: ContractRuntimeController
var _product_market_runtime_controller: ProductMarketRuntimeController
var _city_gdp_derivative_runtime_controller: CityGdpDerivativeRuntimeController
var _card_definition_bridge: CardRuntimeDefinitionWorldBridge
var _gameplay_balance_diagnostics_service: GameplayBalanceDiagnosticsRuntimeService
var _victory_control_runtime_controller: VictoryControlRuntimeController
var _route_network_runtime_controller: RouteNetworkRuntimeController
var _v06_economy_action_port: RefCounted
var _ruleset_snapshot: Dictionary = {}
var _policy_main_payload: Dictionary = {}
var _configured := false
var _last_receipts: Array = []
var _v06_facility_bootstrap_attempt_count := 0
var _v06_facility_bootstrap_success_count := 0
var _v06_facility_bootstrap_last_public := {
	"state": "idle",
	"reason_code": "ai_v06_facility_bootstrap_idle",
}
var ai_card_decision_timer := 2.2
var ai_auction_reaction_timer := 0.7
var ai_intel_decision_timer := 5.5
var ai_card_decision_enabled := true


func set_world_bridge(bridge: Node) -> void:
	_world_bridge = bridge


func set_monster_runtime_controller(controller: MonsterRuntimeController) -> void:
	_monster_runtime_controller = controller


func set_military_runtime_controller(controller: MilitaryRuntimeController) -> void:
	_military_runtime_controller = controller


func set_weather_runtime_controller(controller: WeatherRuntimeController) -> void:
	_weather_runtime_controller = controller


func set_contract_runtime_controller(controller: ContractRuntimeController) -> void:
	_contract_runtime_controller = controller


func set_product_market_runtime_controller(controller: ProductMarketRuntimeController) -> void:
	_product_market_runtime_controller = controller


func set_city_gdp_derivative_runtime_controller(controller: CityGdpDerivativeRuntimeController) -> void:
	_city_gdp_derivative_runtime_controller = controller


func set_card_definition_bridge(bridge: CardRuntimeDefinitionWorldBridge) -> void:
	_card_definition_bridge = bridge


func set_gameplay_balance_diagnostics_service(service: GameplayBalanceDiagnosticsRuntimeService) -> void:
	_gameplay_balance_diagnostics_service = service


func set_victory_control_runtime_controller(controller: VictoryControlRuntimeController) -> void:
	_victory_control_runtime_controller = controller


func set_route_network_runtime_controller(controller: RouteNetworkRuntimeController) -> void:
	_route_network_runtime_controller = controller


func set_v06_economy_action_port(port: RefCounted) -> Dictionary:
	_v06_economy_action_port = port
	return _ai_v06_economy_port_capability()


func configure(ruleset_snapshot: Dictionary, supplied_profile: Resource = null) -> void:
	_ruleset_snapshot = ruleset_snapshot.duplicate(true)
	if supplied_profile != null:
		policy_profile = supplied_profile
	if policy_profile == null:
		_configured = false
		push_error("AiRuntimeController requires an AI Policy Profile Resource.")
		return
	if not bool(policy_profile.get("runtime_cutover_enabled")):
		_configured = false
		push_error("AiRuntimeController refuses an AI Policy Profile with runtime cutover disabled.")
		return
	if not policy_profile.has_method("to_main_source_dictionary"):
		_configured = false
		push_error("AiRuntimeController policy profile cannot provide runtime parameters.")
		return
	var payload_variant: Variant = policy_profile.call("to_main_source_dictionary")
	_policy_main_payload = (payload_variant as Dictionary).duplicate(true) if payload_variant is Dictionary else {}
	_configured = not _policy_main_payload.is_empty()
	if _configured:
		ai_card_decision_timer = float(_policy_value("timing", "card_decision_interval_seconds", 2.2))
		ai_auction_reaction_timer = float(_policy_value("timing", "auction_reaction_interval_seconds", 0.7))
		ai_intel_decision_timer = float(_policy_value("timing", "intel_decision_interval_seconds", 5.5))


func reset_state() -> void:
	ai_card_decision_timer = float(_policy_value("timing", "card_decision_interval_seconds", 2.2))
	ai_auction_reaction_timer = float(_policy_value("timing", "auction_reaction_interval_seconds", 0.7))
	ai_intel_decision_timer = float(_policy_value("timing", "intel_decision_interval_seconds", 5.5))
	ai_card_decision_enabled = true
	_last_receipts.clear()
	_v06_facility_bootstrap_attempt_count = 0
	_v06_facility_bootstrap_success_count = 0
	_v06_facility_bootstrap_last_public = {
		"state": "idle",
		"reason_code": "ai_v06_facility_bootstrap_idle",
	}


func tick(delta: float) -> void:
	if not _configured or not _world_ready():
		return
	_update_ai_decisions(delta)


func ensure_player_state() -> void:
	if _configured and _world_ready():
		_ensure_player_ai_state()


func build_turn_plan(player_index: int, world_snapshot: Dictionary) -> Dictionary:
	if not _configured or not _world_ready():
		return {"planned": false, "reason": "controller_not_ready", "player_index": player_index}
	var supplied_variant: Variant = world_snapshot.get("candidates", [])
	var candidates: Array = (supplied_variant as Array).duplicate(true) if supplied_variant is Array else []
	if candidates.is_empty():
		candidates.append_array(_ai_card_play_candidates(player_index))
		candidates.append_array(_ai_card_buy_candidates(player_index))
	var ranked := rank_candidates(player_index, candidates, world_snapshot)
	var selected: Dictionary = ranked[0] if not ranked.is_empty() and ranked[0] is Dictionary else {}
	return {
		"planned": not selected.is_empty(),
		"player_index": player_index,
		"candidate_count": ranked.size(),
		"selected": selected.duplicate(true),
		"context_revision": int(world_snapshot.get("context_revision", -1)),
	}


func build_response_plan(response_kind: String, player_index: int, context: Dictionary) -> Dictionary:
	if not _configured or not _world_ready():
		return {"planned": false, "reason": "controller_not_ready", "response_kind": response_kind, "player_index": player_index}
	var candidates: Array = []
	match response_kind:
		"counter_response":
			candidates = _ai_counter_response_candidates(player_index)
		"contract_response":
			candidates = _ai_contract_response_candidates(player_index, context)
		"monster_wager":
			var wager_plan := _ai_monster_wager_plan(player_index, context)
			if not wager_plan.is_empty():
				candidates.append(wager_plan)
		_:
			var supplied: Variant = context.get("candidates", [])
			candidates = (supplied as Array).duplicate(true) if supplied is Array else []
	var ranked := rank_candidates(player_index, candidates, context)
	return {
		"planned": not ranked.is_empty(),
		"response_kind": response_kind,
		"player_index": player_index,
		"candidate_count": ranked.size(),
		"selected": (ranked[0] as Dictionary).duplicate(true) if not ranked.is_empty() and ranked[0] is Dictionary else {},
	}


func rank_candidates(_player_index: int, candidates: Array, _context: Dictionary = {}) -> Array:
	var ranked: Array = []
	for candidate_variant in candidates:
		if candidate_variant is Dictionary:
			ranked.append((candidate_variant as Dictionary).duplicate(true))
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := int(left.get("score", left.get("weight", 0)))
		var right_score := int(right.get("score", right.get("weight", 0)))
		if left_score != right_score:
			return left_score > right_score
		return _candidate_stable_id(left) < _candidate_stable_id(right)
	)
	return ranked


func commit_plan_receipt(receipt: Dictionary) -> Dictionary:
	var normalized := {
		"intent_id": str(receipt.get("intent_id", "")),
		"action_id": str(receipt.get("action_id", "")),
		"applied": bool(receipt.get("applied", false)),
		"reason": str(receipt.get("reason", "")),
		"context_revision": int(receipt.get("context_revision", -1)),
	}
	_last_receipts.append(normalized)
	while _last_receipts.size() > 24:
		_last_receipts.pop_front()
	return normalized.duplicate(true)


func route_intent(intent: Dictionary) -> Dictionary:
	if _world_bridge == null or not _world_bridge.has_method("route_intent"):
		return {"applied": false, "reason": "world_bridge_missing", "intent_id": str(intent.get("intent_id", ""))}
	var receipt_variant: Variant = _world_bridge.call("route_intent", intent)
	var receipt: Dictionary = (receipt_variant as Dictionary).duplicate(true) if receipt_variant is Dictionary else {}
	commit_plan_receipt(receipt)
	return receipt


func to_save_data() -> Dictionary:
	var player_states: Array = []
	if _world_ready():
		for player_index in range(players.size()):
			if not _player_is_ai(player_index):
				continue
			var player: Dictionary = players[player_index]
			player_states.append({
				"player_index": player_index,
				"ai_profile": (player.get("ai_profile", {}) as Dictionary).duplicate(true) if player.get("ai_profile", {}) is Dictionary else {},
				"ai_memory": (player.get("ai_memory", {}) as Dictionary).duplicate(true) if player.get("ai_memory", {}) is Dictionary else {},
			})
	return {
		"ai_card_decision_timer": ai_card_decision_timer,
		"ai_auction_reaction_timer": ai_auction_reaction_timer,
		"ai_intel_decision_timer": ai_intel_decision_timer,
		"ai_card_decision_enabled": ai_card_decision_enabled,
		"player_states": player_states,
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	ai_card_decision_timer = maxf(0.1, float(data.get("ai_card_decision_timer", _policy_value("timing", "card_decision_interval_seconds", 2.2))))
	ai_auction_reaction_timer = maxf(0.1, float(data.get("ai_auction_reaction_timer", _policy_value("timing", "auction_reaction_interval_seconds", 0.7))))
	ai_intel_decision_timer = maxf(0.1, float(data.get("ai_intel_decision_timer", _policy_value("timing", "intel_decision_interval_seconds", 5.5))))
	ai_card_decision_enabled = bool(data.get("ai_card_decision_enabled", true))
	if _world_ready():
		for state_variant in data.get("player_states", []):
			if not (state_variant is Dictionary):
				continue
			var state: Dictionary = state_variant
			var player_index := int(state.get("player_index", -1))
			if player_index < 0 or player_index >= players.size():
				continue
			var player: Dictionary = players[player_index]
			if state.get("ai_profile", {}) is Dictionary:
				player["ai_profile"] = (state.get("ai_profile", {}) as Dictionary).duplicate(true)
			if state.get("ai_memory", {}) is Dictionary:
				player["ai_memory"] = (state.get("ai_memory", {}) as Dictionary).duplicate(true)
			players[player_index] = player
		_ensure_player_ai_state()
	return {"applied": true, "player_state_count": int((data.get("player_states", []) as Array).size()) if data.get("player_states", []) is Array else 0}


func policy_snapshot() -> Dictionary:
	if policy_profile == null or not policy_profile.has_method("to_policy_dictionary"):
		return {}
	var value: Variant = policy_profile.call("to_policy_dictionary")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func debug_snapshot(_viewer_index: int = -1) -> Dictionary:
	var profile := policy_snapshot()
	return {
		"controller_ready": _configured and _world_ready(),
		"runtime_owner": "res://scripts/runtime/ai_runtime_controller.gd",
		"runtime_cutover_enabled": bool(profile.get("runtime_cutover_enabled", false)),
		"policy_profile_id": str(profile.get("profile_id", "")),
		"ai_player_count": _ai_player_count() if _world_ready() else 0,
		"timers": {
			"card_decision": ai_card_decision_timer,
			"auction_reaction": ai_auction_reaction_timer,
			"intel_decision": ai_intel_decision_timer,
		},
		"receipt_count": _last_receipts.size(),
		"shared_rng": _world_ready() and rng != null,
		"weather_controller_bound": _weather_runtime_controller != null,
		"contract_controller_bound": _contract_runtime_controller != null,
		"victory_control_controller_bound": _victory_control_runtime_controller != null,
		"private_plan_exposed": false,
	}


func _candidate_stable_id(candidate: Dictionary) -> String:
	return "%s|%s|%s|%d|%d" % [
		str(candidate.get("candidate_id", candidate.get("kind", candidate.get("action_id", "")))),
		str(candidate.get("card_id", candidate.get("skill_name", candidate.get("name", "")))),
		str(candidate.get("product", "")),
		int(candidate.get("target_index", candidate.get("district_index", -1))),
		int(candidate.get("slot_index", -1)),
	]


func _world_ready() -> bool:
	return _world_bridge != null and _world_bridge.has_method("has_world") and bool(_world_bridge.call("has_world"))


func _world_value(property_name: StringName, default_value: Variant = null) -> Variant:
	return _world_bridge.call("read_world_value", property_name, default_value) if _world_ready() else default_value


func _write_world_value(property_name: StringName, value: Variant) -> void:
	if _world_ready():
		_world_bridge.call("write_world_value", property_name, value)


func _world_constant(constant_name: StringName, default_value: Variant = null) -> Variant:
	return _world_bridge.call("read_world_constant", constant_name, default_value) if _world_ready() else default_value


func _call_world(method_name: StringName, arguments: Array = []) -> Variant:
	return _world_bridge.call("call_world", method_name, arguments) if _world_ready() else null


func _call_monster(method_name: StringName, arguments: Array = []) -> Variant:
	if _monster_runtime_controller == null or not _monster_runtime_controller.has_method(method_name):
		return null
	return _monster_runtime_controller.callv(method_name, arguments)


func _policy_value(group: String, field: String, default_value: Variant) -> Variant:
	var group_variant: Variant = _policy_main_payload.get(group, {})
	return (group_variant as Dictionary).get(field, default_value) if group_variant is Dictionary else default_value


var active_monster_wagers:
	get:
		return _monster_runtime_controller.active_monster_wagers if _monster_runtime_controller != null else []
	set(value):
		if _monster_runtime_controller != null and value is Array:
			_monster_runtime_controller.active_monster_wagers = (value as Array).duplicate(true)

var auto_monsters:
	get:
		return _monster_runtime_controller.auto_monsters if _monster_runtime_controller != null else []
	set(value):
		if _monster_runtime_controller != null and value is Array:
			_monster_runtime_controller.auto_monsters = (value as Array).duplicate(true)

var business_cycle_count:
	get:
		return _product_market_runtime_controller.business_cycle_count if _product_market_runtime_controller != null else 0

var card_resolution_auction_open:
	get:
		return _world_value(&"card_resolution_auction_open", false)
	set(value):
		_write_world_value(&"card_resolution_auction_open", value)

var card_resolution_batch_locked:
	get:
		return _world_value(&"card_resolution_batch_locked", false)
	set(value):
		_write_world_value(&"card_resolution_batch_locked", value)

var card_resolution_counter_window_active:
	get:
		return _world_value(&"card_resolution_counter_window_active", false)
	set(value):
		_write_world_value(&"card_resolution_counter_window_active", value)

var configured_ai_player_count:
	get:
		return _world_value(&"configured_ai_player_count", 0)
	set(value):
		_write_world_value(&"configured_ai_player_count", value)

var configured_player_count:
	get:
		return _world_value(&"configured_player_count", 0)
	set(value):
		_write_world_value(&"configured_player_count", value)

var districts:
	get:
		return _world_value(&"districts", [])
	set(value):
		_write_world_value(&"districts", value)

var session_finished:
	get:
		return bool(_call_world(&"_runtime_session_finished"))

var game_time:
	get:
		return _world_value(&"game_time", 0.0)
	set(value):
		_write_world_value(&"game_time", value)

var military_units:
	get:
		return _military_runtime_controller.roster_snapshot(true) if _military_runtime_controller != null else []

var pending_contract_offers:
	get:
		return _contract_runtime_controller.pending_offers_snapshot(true) if _contract_runtime_controller != null else []
	set(value):
		if _contract_runtime_controller != null and value is Array:
			var save_data := _contract_runtime_controller.to_save_data()
			save_data["pending_contract_offers"] = (value as Array).duplicate(true)
			_contract_runtime_controller.apply_save_data(save_data)

var players:
	get:
		return _world_value(&"players", [])
	set(value):
		_write_world_value(&"players", value)

var product_market:
	get:
		return _product_market_runtime_controller.runtime_state_snapshot().get("product_market", {}) if _product_market_runtime_controller != null else {}

var resolved_card_history:
	get:
		return _world_value(&"resolved_card_history", [])
	set(value):
		_write_world_value(&"resolved_card_history", value)

var rng:
	get:
		return _world_value(&"rng", null)
	set(value):
		_write_world_value(&"rng", value)

var selected_card_resolution_id:
	get:
		return _world_value(&"selected_card_resolution_id", 0)
	set(value):
		_write_world_value(&"selected_card_resolution_id", value)

var selected_contract_source_district:
	get:
		return int(_contract_runtime_controller.selection_snapshot().get("source_district", -1)) if _contract_runtime_controller != null else -1
	set(value):
		if _contract_runtime_controller != null:
			var selection := _contract_runtime_controller.selection_snapshot()
			_contract_runtime_controller.set_selection_state(int(value), int(selection.get("target_district", -1)))

var selected_contract_target_district:
	get:
		return int(_contract_runtime_controller.selection_snapshot().get("target_district", -1)) if _contract_runtime_controller != null else -1
	set(value):
		if _contract_runtime_controller != null:
			var selection := _contract_runtime_controller.selection_snapshot()
			_contract_runtime_controller.set_selection_state(int(selection.get("source_district", -1)), int(value))

var selected_district:
	get:
		return _world_value(&"selected_district", 0)
	set(value):
		_write_world_value(&"selected_district", value)

var selected_player:
	get:
		return _world_value(&"selected_player", 0)
	set(value):
		_write_world_value(&"selected_player", value)

var selected_trade_product:
	get:
		return _world_value(&"selected_trade_product", "")
	set(value):
		_write_world_value(&"selected_trade_product", value)

var victory_control_active:
	get:
		return str(_victory_public_snapshot().get("state", "idle")) in ["qualification", "audit"]

var victory_control_remaining_seconds:
	get:
		var snapshot := _victory_public_snapshot()
		match str(snapshot.get("state", "idle")):
			"qualification": return float(snapshot.get("qualification_remaining_seconds", 0.0))
			"audit": return float(snapshot.get("audit_remaining_seconds", 0.0))
		return 0.0

var AI_CARD_DECISION_INTERVAL_SECONDS:
	get:
		return float(_policy_value("timing", "card_decision_interval_seconds", 2.2))

var AI_AUCTION_REACTION_INTERVAL_SECONDS:
	get:
		return float(_policy_value("timing", "auction_reaction_interval_seconds", 0.7))

var AI_INTEL_DECISION_INTERVAL_SECONDS:
	get:
		return float(_policy_value("timing", "intel_decision_interval_seconds", 5.5))

var AI_CARD_BUY_MIN_CASH_RESERVE:
	get:
		return int(_policy_value("selection", "card_buy_min_cash_reserve", 260))

var AI_DECISION_SAMPLE_LIMIT:
	get:
		return int(_policy_value("selection", "decision_sample_limit", 48))

var AI_CANDIDATE_SAMPLE_LIMIT:
	get:
		return int(_policy_value("selection", "candidate_sample_limit", 8))

var AI_INTEL_MIN_CITY_SCORE:
	get:
		return int(_policy_value("selection", "intel_min_city_score", 78))

var AI_INTEL_MIN_CARD_SCORE:
	get:
		return int(_policy_value("selection", "intel_min_card_score", 125))

var AI_INTEL_ACTIONS_PER_TICK:
	get:
		return int(_policy_value("selection", "intel_actions_per_tick", 2))

var AI_COUNTER_RESPONSE_MIN_SCORE:
	get:
		return int(_policy_value("counter", "counter_response_min_score", 160))

var AI_COUNTER_RESPONSE_CONFIDENT_SCORE:
	get:
		return int(_policy_value("counter", "counter_response_confident_score", 270))

var AI_ECONOMIC_FOCUS_TOP_LIMIT:
	get:
		return int(_policy_value("strategy", "economic_focus_top_limit", 3))

var AI_ECONOMIC_FOCUS_MATCH_BONUS:
	get:
		return int(_policy_value("strategy", "economic_focus_match_bonus", 85))

var AI_STRATEGY_MATCH_BONUS:
	get:
		return int(_policy_value("strategy", "strategy_match_bonus", 92))

var AI_STRATEGY_TOP_LIMIT:
	get:
		return int(_policy_value("strategy", "strategy_top_limit", 3))

var AI_ROUTE_PLAN_MATCH_BONUS:
	get:
		return int(_policy_value("strategy", "route_plan_match_bonus", 78))

var AI_ROUTE_PLAN_TOP_LIMIT:
	get:
		return int(_policy_value("strategy", "route_plan_top_limit", 4))

var AI_ROUTE_PLAN_SWITCH_MARGIN:
	get:
		return int(_policy_value("strategy", "route_plan_switch_margin", 140))

var AI_ROUTE_PLAN_ENTRENCHED_SWITCH_MARGIN:
	get:
		return int(_policy_value("strategy", "route_plan_entrenched_switch_margin", 360))

var AI_ENDGAME_GOAL_RATIO:
	get:
		return float(_policy_value("phase", "endgame_goal_ratio", 0.72))

var AI_ENDGAME_CYCLE:
	get:
		return int(_policy_value("phase", "endgame_cycle", 7))

var AI_OPENING_CYCLE_MAX:
	get:
		return int(_policy_value("phase", "opening_cycle_max", 1))

var AI_LEAD_MARGIN:
	get:
		return int(_policy_value("phase", "lead_margin", 280))

var AI_TRAILING_MARGIN:
	get:
		return int(_policy_value("phase", "trailing_margin", 360))

var AI_LEARNING_REWARD_CLAMP:
	get:
		return int(_policy_value("learning", "learning_reward_clamp", 1200))

var AI_LEARNING_VALUE_CLAMP:
	get:
		return float(_policy_value("learning", "learning_value_clamp", 90.0))

var AI_LEARNING_BONUS_CLAMP:
	get:
		return int(_policy_value("learning", "learning_bonus_clamp", 140))

var AI_LEARNING_BASE_RATE:
	get:
		return float(_policy_value("learning", "learning_base_rate", 0.22))

var AI_EPISODE_REWARD_CLAMP:
	get:
		return int(_policy_value("learning", "episode_reward_clamp", 1800))

var AI_EPISODE_SAMPLE_DECAY:
	get:
		return float(_policy_value("learning", "episode_sample_decay", 0.88))

var AI_EPISODE_WIN_BONUS:
	get:
		return int(_policy_value("learning", "episode_win_bonus", 420))

var AI_EPISODE_GOAL_BONUS:
	get:
		return int(_policy_value("learning", "episode_goal_bonus", 240))

var AI_PERSONALITY_CATALOG:
	get:
		var personalities: Variant = _policy_main_payload.get("personalities", [])
		return personalities if personalities is Array else []

var AUTO_MONSTER_ENCOUNTER_RANGE_METERS:
	get:
		return _world_constant(&"AUTO_MONSTER_ENCOUNTER_RANGE_METERS")

var CITY_GUESS_CONFIDENCE_DEFAULT:
	get:
		return _world_constant(&"CITY_GUESS_CONFIDENCE_DEFAULT")

var CITY_GUESS_CONFIDENCE_HIGH:
	get:
		return _world_constant(&"CITY_GUESS_CONFIDENCE_HIGH")

var CITY_GUESS_CONFIDENCE_LOW:
	get:
		return _world_constant(&"CITY_GUESS_CONFIDENCE_LOW")

var CITY_GUESS_CONFIDENCE_MEDIUM:
	get:
		return _world_constant(&"CITY_GUESS_CONFIDENCE_MEDIUM")

var CITY_GUESS_REASON_CARD:
	get:
		return _world_constant(&"CITY_GUESS_REASON_CARD")

var CITY_GUESS_REASON_DEFAULT:
	get:
		return _world_constant(&"CITY_GUESS_REASON_DEFAULT")

var CITY_GUESS_REASON_INTUITION:
	get:
		return _world_constant(&"CITY_GUESS_REASON_INTUITION")

var CITY_GUESS_REASON_PRODUCT:
	get:
		return _world_constant(&"CITY_GUESS_REASON_PRODUCT")

var CITY_GUESS_REASON_ROUTE:
	get:
		return _world_constant(&"CITY_GUESS_REASON_ROUTE")

var CONTRACT_RESPONSE_PENDING:
	get:
		return ContractRuntimeController.RESPONSE_PENDING

var DEFAULT_AOE_RADIUS_METERS:
	get:
		return _world_constant(&"DEFAULT_AOE_RADIUS_METERS")

var ACTION_CALLOUT_DURATION:
	get:
		return _world_constant(&"ACTION_CALLOUT_DURATION")

var ECONOMY_LEGACY_TURN_SECONDS:
	get:
		return _world_constant(&"ECONOMY_LEGACY_TURN_SECONDS")

var MAX_PLAYER_COUNT:
	get:
		return _world_constant(&"MAX_PLAYER_COUNT")

var MIN_PLAYER_COUNT:
	get:
		return _world_constant(&"MIN_PLAYER_COUNT")

var NEARBY_RADIUS_METERS:
	get:
		return _world_constant(&"NEARBY_RADIUS_METERS")

var PLAYER_HAND_LIMIT:
	get:
		return _world_constant(&"PLAYER_HAND_LIMIT")

var PRODUCT_CATALOG:
	get:
		return ProductMarketRuntimeController.PRODUCT_CATALOG

var RIVAL_AUTO_BUILD_BASE_CITY_CAP:
	get:
		return _world_constant(&"RIVAL_AUTO_BUILD_BASE_CITY_CAP")

var RIVAL_AUTO_BUILD_CHANCE_PERCENT:
	get:
		return _world_constant(&"RIVAL_AUTO_BUILD_CHANCE_PERCENT")

var RIVAL_AUTO_BUILD_MAX_CITY_CAP:
	get:
		return _world_constant(&"RIVAL_AUTO_BUILD_MAX_CITY_CAP")

var RIVAL_AUTO_BUILD_MAX_PER_CYCLE:
	get:
		return _world_constant(&"RIVAL_AUTO_BUILD_MAX_PER_CYCLE")

var RIVAL_AUTO_BUILD_MIN_CASH_RESERVE:
	get:
		return _world_constant(&"RIVAL_AUTO_BUILD_MIN_CASH_RESERVE")

var RIVAL_BUSINESS_ACTION_CHANCE_PERCENT:
	get:
		return _world_constant(&"RIVAL_BUSINESS_ACTION_CHANCE_PERCENT")

var RIVAL_BUSINESS_ACTION_COST:
	get:
		return _world_constant(&"RIVAL_BUSINESS_ACTION_COST")

var RIVAL_BUSINESS_ACTION_MAX_PER_CYCLE:
	get:
		return _world_constant(&"RIVAL_BUSINESS_ACTION_MAX_PER_CYCLE")

var WEATHER_DURATION_MIN_SECONDS:
	get:
		return WeatherRuntimeController.DURATION_MIN_SECONDS

var WEATHER_FORECAST_LEAD_MAX_SECONDS:
	get:
		return WeatherRuntimeController.FORECAST_LEAD_MAX_SECONDS

var WEATHER_FORECAST_LEAD_MIN_SECONDS:
	get:
		return WeatherRuntimeController.FORECAST_LEAD_MIN_SECONDS

var WEATHER_TYPES:
	get:
		return WeatherRuntimeController.WEATHER_TYPES

var WEATHER_ZONE_MAX:
	get:
		return WeatherRuntimeController.ZONE_MAX

# World fact and mutation adapters. Decision ownership stays above this boundary.

func _ruleset_timing_seconds(rule_id: StringName) -> float:
	return _call_monster(&"_ruleset_timing_seconds", [rule_id])

func _card_resolution_current_queue() -> Array:
	return _call_world(&"_card_resolution_current_queue")

func _card_resolution_next_queue() -> Array:
	return _call_world(&"_card_resolution_next_queue")

func _card_resolution_active_entry() -> Dictionary:
	return _call_world(&"_card_resolution_active_entry")

func _store_card_resolution_entry(entry: Dictionary) -> bool:
	return _call_world(&"_store_card_resolution_entry", [entry])

func _card_owner_guess_stake_for_player(viewer_index: int) -> int:
	return _call_world(&"_card_owner_guess_stake_for_player", [viewer_index])

func _guess_card_resolution_owner_for_player(viewer_index: int, resolution_id: int, guessed_player: int, announce: bool = true) -> bool:
	return _call_world(&"_guess_card_resolution_owner_for_player", [viewer_index, resolution_id, guessed_player, announce])

func _intel_city_guess_entries(viewer_index: int, limit: int = 6) -> Array:
	return _call_world(&"_intel_city_guess_entries", [viewer_index, limit])

func _city_intel_priority_score(entry: Dictionary) -> int:
	return _call_world(&"_city_intel_priority_score", [entry])

func _normalized_city_guess_confidence(confidence: int) -> int:
	return _call_world(&"_normalized_city_guess_confidence", [confidence])

func _public_card_resolution_owner_entries() -> Array:
	return _call_world(&"_public_card_resolution_owner_entries")

func _victory_public_snapshot() -> Dictionary:
	if _victory_control_runtime_controller == null or not _victory_control_runtime_controller.has_method("public_snapshot"):
		return {}
	var value: Variant = _victory_control_runtime_controller.call("public_snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}

func _victory_private_snapshot(player_index: int) -> Dictionary:
	if _victory_control_runtime_controller == null or not _victory_control_runtime_controller.has_method("private_snapshot"):
		return {}
	var value: Variant = _victory_control_runtime_controller.call("private_snapshot", player_index)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}

func _victory_candidate(player_index: int) -> Dictionary:
	var value: Variant = _victory_private_snapshot(player_index).get("own_candidate", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}

func _victory_top_n_gdp(player_index: int) -> int:
	return maxi(0, int(_victory_candidate(player_index).get("top_n_gdp_per_minute", 0)))

func _victory_controlled_regions(player_index: int) -> int:
	return maxi(0, int(_victory_candidate(player_index).get("controlled_region_count", 0)))

func _victory_dynamic_rule() -> Dictionary:
	var public_rule: Variant = _victory_public_snapshot().get("victory_rule", {})
	if public_rule is Dictionary and not (public_rule as Dictionary).is_empty():
		return (public_rule as Dictionary).duplicate(true)
	return {}

func _victory_required_gdp() -> int:
	return maxi(0, int(_victory_dynamic_rule().get("required_top_k_gdp_per_minute", 0)))

func _victory_required_regions() -> int:
	return maxi(0, int(_victory_dynamic_rule().get("required_region_count", 0)))

func _victory_timer_total_seconds() -> float:
	if _victory_control_runtime_controller == null or not _victory_control_runtime_controller.has_method("timer_duration"):
		return 1.0
	var state := str(_victory_public_snapshot().get("state", "idle"))
	var timer_id := "public_audit" if state == "audit" else "victory_qualification"
	return maxf(1.0, float(_victory_control_runtime_controller.call("timer_duration", timer_id)))

func _victory_visible_rankings(viewer_index: int) -> Array:
	var by_player := {}
	for entry_variant in _victory_public_snapshot().get("audit_entries", []):
		if entry_variant is Dictionary:
			by_player[str(int((entry_variant as Dictionary).get("player_index", -1)))] = (entry_variant as Dictionary).duplicate(true)
	var own_candidate := _victory_candidate(viewer_index)
	if not own_candidate.is_empty():
		by_player[str(viewer_index)] = own_candidate
	var result: Array = []
	for entry_variant in by_player.values():
		if entry_variant is Dictionary:
			result.append((entry_variant as Dictionary).duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		for key in ["top_k_gdp_per_minute_cents", "controlled_region_count", "cash_ledger_cents"]:
			if int(left.get(key, 0)) != int(right.get(key, 0)):
				return int(left.get(key, 0)) > int(right.get(key, 0))
		return int(left.get("player_index", -1)) < int(right.get("player_index", -1))
	)
	return result

func _visible_score_leader_entry(viewer_index: int) -> Dictionary:
	var rankings := _victory_visible_rankings(viewer_index)
	if rankings.is_empty():
		return {"player_index": viewer_index, "score": _victory_top_n_gdp(viewer_index)}
	var leader := (rankings[0] as Dictionary).duplicate(true)
	leader["score"] = int(leader.get("top_n_gdp_per_minute", 0))
	return leader

func _victory_outcome_rankings() -> Array:
	var receipt_variant: Variant = _victory_public_snapshot().get("outcome_receipt", {})
	if not (receipt_variant is Dictionary):
		return []
	var rankings_variant: Variant = (receipt_variant as Dictionary).get("rankings", [])
	return (rankings_variant as Array).duplicate(true) if rankings_variant is Array else []

func _victory_rank_for_player(rankings: Array, player_index: int) -> int:
	for rank in range(rankings.size()):
		if rankings[rank] is Dictionary and int((rankings[rank] as Dictionary).get("player_index", -1)) == player_index:
			return rank
	return rankings.size()

func _player_is_eliminated(player_index: int) -> bool:
	return _call_world(&"_player_is_eliminated", [player_index])

func _product_count_summary(counts: Dictionary, limit: int = 4, empty_text: String = "暂无") -> String:
	return _call_world(&"_product_count_summary", [counts, limit, empty_text])

func _product_strategy_scores(product_name: String) -> Dictionary:
	return _call_world(&"_product_strategy_scores", [product_name])

func _ensure_product_market_catalog() -> void:
	if _product_market_runtime_controller != null:
		_product_market_runtime_controller.ensure_catalog()

func _limited_name_list(names: Array, limit: int = 6, empty_text: String = "无") -> String:
	return _call_monster(&"_limited_name_list", [names, limit, empty_text])

func _player_product_flow(player_index: int, product_name: String) -> int:
	return _call_world(&"_player_product_flow", [player_index, product_name])

func _first_player_flow_product(player_index: int) -> String:
	return _call_world(&"_first_player_flow_product", [player_index])

func _best_player_flow_product(player_index: int, required: int = 1, preferred_products: Array = []) -> String:
	return _call_world(&"_best_player_flow_product", [player_index, required, preferred_products])

func _skill_play_product(skill: Dictionary, player_index: int) -> String:
	return _call_world(&"_skill_play_product", [skill, player_index])

func _skill_play_flow_required(skill: Dictionary, _player_index: int = -1) -> int:
	return _call_world(&"_skill_play_flow_required", [skill, _player_index])

func _skill_play_region_scope(skill: Dictionary) -> String:
	return str(_skill_play_requirement_status(selected_player, skill).get("scope", CardPlayRequirementPolicyScript.SCOPE_OWN_BEST_REGION))

func _best_player_gdp_share_district(player_index: int) -> int:
	return _call_world(&"_best_player_gdp_share_district", [player_index])

func _skill_play_requirement_status(player_index: int, skill: Dictionary) -> Dictionary:
	var value: Variant = _call_world(&"_card_play_requirement_snapshot", [player_index, skill])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}

func _skill_play_cash_cost(skill: Dictionary) -> int:
	return int(_skill_play_requirement_status(selected_player, skill).get("cash_cost", 0))

func _can_play_skill_now(player_index: int, skill: Dictionary, show_log: bool = true) -> bool:
	var value: Variant = _call_world(&"_card_play_eligibility_snapshot", [player_index, skill, "rule", {}])
	var result: Dictionary = value if value is Dictionary else {}
	if not bool(result.get("allowed", false)) and show_log:
		_call_world(&"_log_card_play_rejection", [result, skill])
	return bool(result.get("allowed", false))

func _signed_int_text(value: int) -> String:
	return _call_world(&"_signed_int_text", [value])

func _card_price(skill_name: String, district_index: int = -1, player_index: int = -1) -> int:
	return _call_world(&"_card_price", [skill_name, district_index, player_index])

func _card_strength_budget_points(card_name: String) -> int:
	return _gameplay_balance_diagnostics_service.card_budget_points_for_id(card_name) if _gameplay_balance_diagnostics_service != null else 0

func _product_price(product_name: String) -> int:
	return _product_market_runtime_controller.product_price(product_name) if _product_market_runtime_controller != null else 0

func _active_auto_monster_count() -> int:
	return _call_monster(&"_active_auto_monster_count")

func _auto_monster_slot_by_uid(uid: int) -> int:
	return _call_monster(&"_auto_monster_slot_by_uid", [uid])

func _military_unit_type_label(unit_or_skill: Dictionary) -> String:
	return _military_runtime_controller.unit_type_label(unit_or_skill) if _military_runtime_controller != null else "行星防卫军"

func _can_deploy_military_card_at_district(skill: Dictionary, district_index: int) -> bool:
	return _military_runtime_controller.can_deploy_at_district(skill, district_index) if _military_runtime_controller != null else false

func _military_unit_terrain_move_multiplier(unit_or_skill: Dictionary, district_index: int) -> float:
	return _military_runtime_controller.terrain_move_multiplier(unit_or_skill, district_index) if _military_runtime_controller != null else 1.0

func _military_unit_mobility_summary(unit_or_skill: Dictionary) -> String:
	return _military_runtime_controller.mobility_summary(unit_or_skill) if _military_runtime_controller != null else ""

func _military_unit_index_by_uid(uid: int) -> int:
	return _military_runtime_controller.unit_index_by_uid(uid) if _military_runtime_controller != null else -1

func _owned_active_military_unit_index(player_index: int) -> int:
	return _military_runtime_controller.owned_active_unit_index(player_index) if _military_runtime_controller != null else -1

func _make_skill(skill_name: String) -> Dictionary:
	var skill := _skill_definition(skill_name)
	skill["name"] = skill_name
	skill = CardPlayRequirementPolicyScript.apply_to_card(skill_name, skill)
	skill["cooldown"] = float(skill.get("cooldown", 0.0))
	skill["cooldown_left"] = 0.0
	skill["lock_left"] = 0.0
	return skill

func _player_role_card_for_index(player_index: int) -> Dictionary:
	return _call_monster(&"_player_role_card_for_index", [player_index])

func _district_or_city_has_product(district_index: int, product_name: String) -> bool:
	return _call_world(&"_district_or_city_has_product", [district_index, product_name])

func _skill_exists(skill_name: String) -> bool:
	return _card_definition_bridge.has_runtime_card(skill_name) if _card_definition_bridge != null else false

func _skill_definition(skill_name: String) -> Dictionary:
	return _card_definition_bridge.resolve_definition(skill_name) if _card_definition_bridge != null else {}

func _refresh_ui() -> void:
	return _call_monster(&"_refresh_ui")

func _district_city(index: int) -> Dictionary:
	return _call_monster(&"_district_city", [index])

func _city_is_active(city: Dictionary) -> bool:
	return _call_monster(&"_city_is_active", [city])

func _city_product_names(city: Dictionary) -> Array:
	return _call_monster(&"_city_product_names", [city])

func _city_demand_names(city: Dictionary) -> Array:
	return _call_monster(&"_city_demand_names", [city])

func _normalize_city_public_clue_entry(value: Variant) -> Dictionary:
	return _call_world(&"_normalize_city_public_clue_entry", [value])

func _apply_rival_business_action(player_index: int, action: Dictionary) -> bool:
	return _call_world(&"_apply_rival_business_action", [player_index, action])

func _mark_city_guess_for_player(viewer_index: int, city_index: int, guessed_player: int, confidence: int = CITY_GUESS_CONFIDENCE_DEFAULT, reason: String = CITY_GUESS_REASON_DEFAULT) -> bool:
	return _call_world(&"_mark_city_guess_for_player", [viewer_index, city_index, guessed_player, confidence, reason])

func _private_known_card_owner_for_entry(viewer_index: int, entry: Dictionary) -> int:
	return _call_world(&"_private_known_card_owner_for_entry", [viewer_index, entry])

func _traceable_card_entries(preferred_resolution_id: int = -1, limit: int = 1) -> Array:
	return _call_world(&"_traceable_card_entries", [preferred_resolution_id, limit])

func _traceable_contract_entries(preferred_resolution_id: int = -1, limit: int = 1) -> Array:
	return _contract_runtime_controller.traceable_contract_entries(preferred_resolution_id, limit) if _contract_runtime_controller != null else []

func _monster_wager_base_percent(entry: Dictionary) -> int:
	return _call_monster(&"_monster_wager_base_percent", [entry])

func _monster_wager_clamped_percent(entry: Dictionary, percent: int) -> int:
	return _call_monster(&"_monster_wager_clamped_percent", [entry, percent])

func _monster_wager_amount_for_percent(player_index: int, percent: int) -> int:
	return _call_monster(&"_monster_wager_amount_for_percent", [player_index, percent])

func _pending_contract_offers_for_player(player_index: int) -> Array:
	return _contract_runtime_controller.offers_for_player(player_index) if _contract_runtime_controller != null else []

func _contract_accept_effect_summary(skill: Dictionary) -> String:
	return _contract_runtime_controller.accept_effect_summary(skill) if _contract_runtime_controller != null else "无额外奖励"

func _contract_decline_effect_summary(skill: Dictionary) -> String:
	return _contract_runtime_controller.decline_effect_summary(skill) if _contract_runtime_controller != null else "无额外惩罚"

func _respond_to_pending_contract_for_player(player_index: int, contract_id: int, accept: bool, announce: bool = true) -> bool:
	return bool(_contract_runtime_controller.respond_to_offer(player_index, contract_id, accept, announce).get("committed", false)) if _contract_runtime_controller != null else false

func _development_route_archetypes() -> Array:
	return _gameplay_balance_diagnostics_service.development_routes() if _gameplay_balance_diagnostics_service != null else []

func _card_development_route_id(skill: Dictionary) -> String:
	return _gameplay_balance_diagnostics_service.route_id_for_card(skill) if _gameplay_balance_diagnostics_service != null else "tactical_support"

func _development_route_label(route_id: String) -> String:
	return _gameplay_balance_diagnostics_service.route_label(route_id) if _gameplay_balance_diagnostics_service != null else "即时战术"

func _development_route_pressure_card_entry(card_name: String, skill: Dictionary) -> Dictionary:
	return _gameplay_balance_diagnostics_service.development_route_pressure_card_entry(card_name, skill) if _gameplay_balance_diagnostics_service != null else {}

func _development_route_pressure_audit() -> Dictionary:
	return _gameplay_balance_diagnostics_service.development_route_pressure_audit() if _gameplay_balance_diagnostics_service != null else {}

func _duration_short_text(seconds: float) -> String:
	return _call_monster(&"_duration_short_text", [seconds])

func _skill_duration_seconds(skill: Dictionary, seconds_key: String, turns_key: String, default_turns: int = 0) -> float:
	return _call_world(&"_skill_duration_seconds", [skill, seconds_key, turns_key, default_turns])

func _city_gdp_derivative_duration_seconds(skill: Dictionary) -> float:
	return float(_city_gdp_derivative_terms(skill).get("duration_seconds", 0.0))

func _can_summon_monster_card_at_district(skill: Dictionary, district_index: int) -> bool:
	return _call_monster(&"_can_summon_monster_card_at_district", [skill, district_index])

func _short_card_text(text: String, max_len: int) -> String:
	return _call_world(&"_short_card_text", [text, max_len])

func _queue_monster_card_as_counter(player_index: int, slot_index: int, source_skill: Dictionary) -> bool:
	return _call_world(&"_queue_monster_card_as_counter", [player_index, slot_index, source_skill])

func _ensure_configured_ai_player_count() -> void:
	return _call_world(&"_ensure_configured_ai_player_count")

func _configured_human_player_count() -> int:
	return _call_world(&"_configured_human_player_count")

func _player_is_ai(player_index: int) -> bool:
	return _call_world(&"_player_is_ai", [player_index])

func _player_facing_text_snapshot() -> Array:
	return _call_world(&"_player_facing_text_snapshot")

func _counter_skill_for_ai_candidate(player_index: int, source_skill: Dictionary) -> Dictionary:
	if _is_counter_skill(source_skill):
		return source_skill.duplicate(true)
	if not _can_convert_monster_card_to_counter(player_index, source_skill):
		return {}
	var counter_rank := clampi(_skill_rank(String(source_skill.get("name", ""))), 1, 4)
	return _make_skill("相位否决%d" % counter_rank)

func _catalog_entry(index: int) -> Dictionary:
	return _call_monster(&"_catalog_entry", [index])

func _canonical_card_supply_name(skill_name: String) -> String:
	return _call_world(&"_canonical_card_supply_name", [skill_name])

func _district_supply_card_ids(district_index: int) -> Array:
	var value: Variant = _call_world(&"_district_supply_card_ids", [district_index])
	return (value as Array).duplicate() if value is Array else []

func _alive_district_indices() -> Array:
	return _call_world(&"_alive_district_indices")

func _weather_template(type_id: String) -> Dictionary:
	return _weather_runtime_controller.template(type_id) if _weather_runtime_controller != null else {}

func _weather_label(type_id: String) -> String:
	return _weather_runtime_controller.label(type_id) if _weather_runtime_controller != null else type_id

func _weather_zone_count_for_planet() -> int:
	return _weather_runtime_controller.zone_count_for_planet() if _weather_runtime_controller != null else 1


func _weather_type_ids() -> Array:
	return _weather_runtime_controller.weather_type_ids() if _weather_runtime_controller != null else []


func _weather_preview_districts(anchor_index: int, zone_count: int) -> Array:
	return _weather_runtime_controller.preview_districts(anchor_index, zone_count) if _weather_runtime_controller != null else []

func _weighted_pick_index(weights: Array) -> int:
	return _call_monster(&"_weighted_pick_index", [weights])

func _card_display_name(card_name: String) -> String:
	return _call_world(&"_card_display_name", [card_name])

func _district_event_weight(index: int) -> int:
	return _call_world(&"_district_event_weight", [index])

func _monster_resource_match_score(actor: Dictionary, index: int) -> int:
	return _call_monster(&"_monster_resource_match_score", [actor, index])

func _route_network_load_for_legacy_region(index: int) -> int:
	return _route_network_runtime_controller.route_load_for_legacy_region(index) if _route_network_runtime_controller != null else 0

func _market_listing_purchasable(district_index: int) -> bool:
	return _call_world(&"_district_market_currently_purchasable", [district_index])

func _skill_rank(skill_name: String) -> int:
	return _card_definition_bridge.rank(skill_name) if _card_definition_bridge != null else 0

func _queued_card_entry_index_for_player(player_index: int) -> int:
	return _call_world(&"_queued_card_entry_index_for_player", [player_index])

func _next_batch_card_entry_index_for_player(player_index: int) -> int:
	return _call_world(&"_next_batch_card_entry_index_for_player", [player_index])

func _find_highest_family_card_slot(player: Dictionary, skill_name: String) -> int:
	return _call_world(&"_find_highest_family_card_slot", [player, skill_name])

func _player_counted_hand_size(player: Dictionary) -> int:
	return _call_world(&"_player_counted_hand_size", [player])

func _discardable_hand_slots_for_purchase(player: Dictionary) -> Array:
	return _call_world(&"_discardable_hand_slots_for_purchase", [player])

func _player_can_receive_card_with_discard(player: Dictionary, skill_name: String) -> bool:
	return _call_world(&"_player_can_receive_card_with_discard", [player, skill_name])

func _purchase_requires_discard(player: Dictionary, skill_name: String) -> bool:
	return _call_world(&"_purchase_requires_discard", [player, skill_name])

func _city_warehouse_stockpile_pressure(city: Dictionary) -> int:
	return _call_monster(&"_city_warehouse_stockpile_pressure", [city])

func _product_futures_duration_seconds(skill: Dictionary) -> float:
	var terms := _product_futures_terms(skill)
	return float(terms.get("duration_seconds", 0.0))

func _product_futures_terms(skill: Dictionary) -> Dictionary:
	if _product_market_runtime_controller == null:
		return {}
	return _product_market_runtime_controller.futures_terms(skill)


func _city_gdp_derivative_terms(skill: Dictionary) -> Dictionary:
	if _city_gdp_derivative_runtime_controller == null:
		return {}
	return _city_gdp_derivative_runtime_controller.derivative_terms(skill)


func _city_gdp_derivative_risk_adjusted_value(terms: Dictionary) -> int:
	var maximum_gain := maxi(0, int(terms.get("maximum_gain", 0)))
	var maximum_loss := maxi(0, int(terms.get("maximum_loss", 0)))
	var margin_cash := maxi(0, int(terms.get("margin_cash", 0)))
	return int(round((float(maximum_gain) - float(maximum_loss) * 0.45 - float(margin_cash) * 0.12) / 10.0))

func _interaction_target_label(player_index: int) -> String:
	return _call_world(&"_interaction_target_label", [player_index])

func _buy_card_for_player_from_district(player_index: int, district_index: int, skill_name: String, anonymous: bool = false, ignore_cooldown: bool = false, discard_slot: int = -1) -> bool:
	return _call_world(&"_buy_card_for_player_from_district", [player_index, district_index, skill_name, anonymous, ignore_cooldown, discard_slot])

func _skill_targets_monster(skill: Dictionary) -> bool:
	var value: Variant = _call_world(&"_card_play_target_snapshot", [skill])
	return bool((value as Dictionary).get("targets_monster", false)) if value is Dictionary else false

func _skill_targets_player(skill: Dictionary) -> bool:
	var value: Variant = _call_world(&"_card_play_target_snapshot", [skill])
	return bool((value as Dictionary).get("targets_player", false)) if value is Dictionary else false

func _playable_card_resolution_coverage_report() -> Dictionary:
	return _gameplay_balance_diagnostics_service.playable_card_resolution_coverage_report() if _gameplay_balance_diagnostics_service != null else {}

func _card_can_open_counter_window(entry: Dictionary) -> bool:
	return _call_world(&"_card_can_open_counter_window", [entry])

func _card_resolution_entry_card_label(entry: Dictionary) -> String:
	return _call_world(&"_card_resolution_entry_card_label", [entry])

func _queue_skill_resolution(player_index: int, slot_index: int, target_slot: int = -1, target_player: int = -1) -> bool:
	return _call_world(&"_queue_skill_resolution", [player_index, slot_index, target_slot, target_player])

func _is_counter_skill(skill: Dictionary) -> bool:
	var value: Variant = _call_world(&"_card_play_target_snapshot", [skill])
	return bool((value as Dictionary).get("is_counter", false)) if value is Dictionary else false

func _can_convert_monster_card_to_counter(player_index: int, skill: Dictionary) -> bool:
	var value: Variant = _call_world(&"_card_play_eligibility_snapshot", [player_index, skill, "hand", {}])
	return str((value as Dictionary).get("reason_code", "")) == "counter_conversion_ready" if value is Dictionary else false

func _skill_is_counterable_player_interaction(skill: Dictionary) -> bool:
	var value: Variant = _call_world(&"_card_play_target_snapshot", [skill])
	return bool((value as Dictionary).get("counterable_player_interaction", false)) if value is Dictionary else false

func _append_unique_string(result: Array, value: String) -> void:
	return _call_monster(&"_append_unique_string", [result, value])

func _monster_wager_entry_index_by_id(wager_id: int) -> int:
	return _call_monster(&"_monster_wager_entry_index_by_id", [wager_id])

func _monster_wager_current_slot(entry: Dictionary, side: String) -> int:
	return _call_monster(&"_monster_wager_current_slot", [entry, side])

func _monster_wager_competitors(entry: Dictionary) -> Array:
	return _call_monster(&"_monster_wager_competitors", [entry])

func _monster_wager_damage_for_side(entry: Dictionary, side: String) -> int:
	return _call_monster(&"_monster_wager_damage_for_side", [entry, side])

func _monster_wager_player_side(entry: Dictionary, player_index: int) -> String:
	return _call_monster(&"_monster_wager_player_side", [entry, player_index])

func _place_monster_wager_percent(wager_id: int, side: String, stake_percent: int = 0, player_index: int = -1, forced: bool = false, metadata: Dictionary = {}) -> bool:
	return _call_monster(&"_place_monster_wager_percent", [wager_id, side, stake_percent, player_index, forced, metadata])

func _monster_wager_actor_expected_damage_score(actor: Dictionary) -> int:
	return _call_monster(&"_monster_wager_actor_expected_damage_score", [actor])

func _active_city_district_indices() -> Array:
	return _route_network_runtime_controller.active_region_legacy_indices() if _route_network_runtime_controller != null else []

func _player_active_city_count(player_index: int) -> int:
	return _call_world(&"_player_active_city_count", [player_index])

func _city_competition_matches(district_index: int) -> int:
	return _call_world(&"_city_competition_matches", [district_index])

func _route_network_routes_for_legacy_region(district_index: int) -> Array:
	return _route_network_runtime_controller.routes_for_legacy_region(district_index) if _route_network_runtime_controller != null else []

func _city_cycle_income(district_index: int, competition_matches: int) -> int:
	return _call_world(&"_city_cycle_income", [district_index, competition_matches])

func _city_cycle_income_breakdown(district_index: int, competition_matches: int) -> Dictionary:
	return _call_world(&"_city_cycle_income_breakdown", [district_index, competition_matches])

func _add_action_callout(actor: String, action: String, detail: String, color: Color, world_position: Vector2, duration: float = ACTION_CALLOUT_DURATION) -> void:
	return _call_monster(&"_add_action_callout", [actor, action, detail, color, world_position, duration])

func _auto_monster_target_weight_parts(actor: Dictionary, index: int) -> Dictionary:
	return _call_monster(&"_auto_monster_target_weight_parts", [actor, index])

func _auto_monster_target_weight(actor: Dictionary, index: int) -> int:
	return _call_monster(&"_auto_monster_target_weight", [actor, index])

func _auto_monster_target_factor_summary(actor: Dictionary, index: int) -> String:
	return _call_monster(&"_auto_monster_target_factor_summary", [actor, index])

func _district_center(index: int) -> Vector2:
	return _call_monster(&"_district_center", [index])

func _entity_world_position(entity: Dictionary) -> Vector2:
	return _call_monster(&"_entity_world_position", [entity])

func _wrapped_distance(from_position: Vector2, to_position: Vector2) -> float:
	return _call_monster(&"_wrapped_distance", [from_position, to_position])

func _entity_distance_to_district(entity: Dictionary, district_index: int) -> float:
	return _call_monster(&"_entity_distance_to_district", [entity, district_index])

func _meters_text(value: float) -> String:
	return _call_monster(&"_meters_text", [value])

func _log(message: String) -> void:
	return _call_monster(&"_log", [message])

# Migrated AI decision ownership.

func _sort_ai_candidate_score_desc(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("score", 0)) > int(b.get("score", 0))


func _sort_ai_focus_score_desc(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("score", 0)) > int(b.get("score", 0))

func _ai_sample_development_route_id(sample: Dictionary) -> String:
	var route_id := String(sample.get("development_route", ""))
	if route_id != "":
		return route_id
	var best_route := ""
	var best_score := -2147483648
	var candidates_variant: Variant = sample.get("candidates", [])
	if candidates_variant is Array:
		for candidate_variant in (candidates_variant as Array):
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			var candidate_route := String(candidate.get("development_route", ""))
			if candidate_route == "":
				continue
			var candidate_score := int(candidate.get("score", 0))
			if best_route == "" or candidate_score > best_score:
				best_route = candidate_route
				best_score = candidate_score
	return best_route
func _ai_profile_development_route_summary(player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= players.size():
		return {}
	var player: Dictionary = players[player_index]
	var profile_variant: Variant = player.get("ai_profile", {})
	if not (profile_variant is Dictionary):
		return {}
	var preferences_variant: Variant = (profile_variant as Dictionary).get("route_preferences", {})
	if not (preferences_variant is Dictionary):
		return {}
	var preferences := preferences_variant as Dictionary
	var best_route := ""
	var best_bias := 1.0
	for route_variant in preferences.keys():
		var route_id := String(route_variant)
		var bias := float(preferences.get(route_id, 1.0))
		if bias > best_bias:
			best_bias = bias
			best_route = route_id
	if best_route == "":
		return {}
	return {
		"route_id": best_route,
		"label": _development_route_label(best_route),
		"count": 0,
		"score": int(round((best_bias - 1.0) * 100.0)),
		"source": "性格偏好",
	}
func _ai_development_route_sample_summary(player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= players.size():
		return {}
	var player: Dictionary = players[player_index]
	var memory_variant: Variant = player.get("ai_memory", {})
	if not (memory_variant is Dictionary):
		return _ai_profile_development_route_summary(player_index)
	var samples_variant: Variant = (memory_variant as Dictionary).get("decision_samples", [])
	if not (samples_variant is Array):
		return _ai_profile_development_route_summary(player_index)
	var route_stats := {}
	for sample_variant in (samples_variant as Array):
		if not (sample_variant is Dictionary):
			continue
		var sample := sample_variant as Dictionary
		var route_id := _ai_sample_development_route_id(sample)
		if route_id == "":
			continue
		var stat: Dictionary = {}
		if route_stats.has(route_id):
			stat = (route_stats[route_id] as Dictionary).duplicate(true)
		else:
			stat = {
				"route_id": route_id,
				"label": _development_route_label(route_id),
				"count": 0,
				"score": 0,
				"source": "决策样本",
			}
		stat["count"] = int(stat.get("count", 0)) + 1
		stat["score"] = int(stat.get("score", 0)) + maxi(1, int(sample.get("score", 0)))
		route_stats[route_id] = stat
	var best_summary := {}
	for route_variant in route_stats.keys():
		var stat := route_stats[route_variant] as Dictionary
		var stat_score := int(stat.get("score", 0))
		var best_score := int(best_summary.get("score", 0))
		var stat_count := int(stat.get("count", 0))
		var best_count := int(best_summary.get("count", 0))
		var better_summary := best_summary.is_empty() or stat_score > best_score or (stat_score == best_score and stat_count > best_count)
		if better_summary:
			best_summary = stat
	if best_summary.is_empty():
		return _ai_profile_development_route_summary(player_index)
	return best_summary
func _ai_development_route_summary_text(player_index: int) -> String:
	var summary := _ai_development_route_sample_summary(player_index)
	if summary.is_empty():
		return "发展路线未定"
	var label := String(summary.get("label", "即时战术"))
	var count := int(summary.get("count", 0))
	var source := String(summary.get("source", ""))
	if count > 0:
		return "发展路线:%s×%d" % [label, count]
	if source != "":
		return "发展路线:%s(%s)" % [label, source]
	return "发展路线:%s" % label
func _rival_auto_city_cap() -> int:
	return clampi(
		RIVAL_AUTO_BUILD_BASE_CITY_CAP + int(float(business_cycle_count) / 3.0),
		RIVAL_AUTO_BUILD_BASE_CITY_CAP,
		RIVAL_AUTO_BUILD_MAX_CITY_CAP
	)
func _rival_build_player_order() -> Array:
	var result := []
	for i in range(players.size()):
		if not _player_is_ai(i):
			continue
		result.append(i)
	for i in range(result.size()):
		var swap_index := int(rng.randi_range(i, result.size() - 1))
		var tmp = result[i]
		result[i] = result[swap_index]
		result[swap_index] = tmp
	return result
func _district_product_overlap_with_rival_cities(player_index: int, district_index: int) -> int:
	if district_index < 0 or district_index >= districts.size():
		return 0
	var local_products: Array = districts[district_index].get("products", [])
	if local_products.is_empty():
		return 0
	var matches := 0
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		if int(city.get("owner", -1)) == player_index:
			continue
		for product_name in _city_product_names(city):
			if local_products.has(product_name):
				matches += 1
	return matches
func _district_ocean_neighbor_count(district_index: int) -> int:
	if district_index < 0 or district_index >= districts.size():
		return 0
	var count := 0
	for neighbor_variant in districts[district_index].get("neighbors", []):
		var neighbor := int(neighbor_variant)
		if neighbor >= 0 and neighbor < districts.size() and String(districts[neighbor].get("terrain", "land")) == "ocean":
			count += 1
	return count
func _auto_build_monster_risk_score(district_index: int) -> int:
	if district_index < 0 or district_index >= districts.size():
		return 0
	var risk := int(round(float(districts[district_index].get("panic", 0)) / 4.0))
	for actor_variant in auto_monsters:
		var actor: Dictionary = actor_variant
		if bool(actor.get("down", false)):
			continue
		var distance := _entity_distance_to_district(actor, district_index)
		if distance <= AUTO_MONSTER_ENCOUNTER_RANGE_METERS:
			risk += 54
		elif distance <= NEARBY_RADIUS_METERS:
			risk += 34
		elif distance <= NEARBY_RADIUS_METERS * 1.75:
			risk += 16
		risk += _monster_resource_match_score(actor, district_index) * 8
	return risk
func _active_city_indices_for_player(player_index: int) -> Array:
	var result := []
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		if int(_district_city(city_index).get("owner", -1)) == player_index:
			result.append(city_index)
	return result
func _competing_city_indices_for_product(player_index: int, product_name: String) -> Array:
	var result := []
	if product_name == "":
		return result
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		if int(city.get("owner", -1)) == player_index:
			continue
		if _city_product_names(city).has(product_name):
			result.append(city_index)
	return result
func _rival_business_candidates_for_player(player_index: int) -> Array:
	var result := []
	if player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return result
	if int(players[player_index].get("cash", 0)) < RIVAL_BUSINESS_ACTION_COST:
		return result
	_ensure_product_market_catalog()
	var focus_product := _ai_focus_product(player_index)
	var strategy_intent := _ai_strategy_intent(player_index)
	var strategy_score := _ai_strategy_score(player_index)
	var route_product := _ai_route_plan_product(player_index)
	var route_stage := _ai_route_plan_stage(player_index)
	var plan_route_score := _ai_route_plan_score(player_index)
	var phase_info := _ai_refresh_game_phase(player_index)
	var phase := String(phase_info.get("phase", "midgame"))
	var posture := String(phase_info.get("posture", "contesting"))
	for own_city_index_variant in _active_city_indices_for_player(player_index):
		var own_city_index := int(own_city_index_variant)
		var own_city := _district_city(own_city_index)
		for product_name_variant in _city_product_names(own_city):
			var product_name := String(product_name_variant)
			var entry: Dictionary = product_market.get(product_name, {})
			var price := int(entry.get("price", entry.get("base_price", _product_price(product_name))))
			var demand_score := int(entry.get("demand", 0))
			var supply_score := int(entry.get("supply", 0))
			var competitors := _competing_city_indices_for_product(player_index, product_name)
			var price_score := 35 + int(round(float(price) / 6.0)) + demand_score * 5 - supply_score * 2 + competitors.size() * 22
			if product_name == focus_product:
				price_score += AI_ECONOMIC_FOCUS_MATCH_BONUS
			var price_strategy_bonus := _ai_strategy_bonus_for_candidate(player_index, "product_speculation", own_city_index, product_name, player_index)
			price_score += price_strategy_bonus
			var price_route_bonus := _ai_route_plan_bonus_for_candidate(player_index, "product_speculation", own_city_index, product_name, player_index)
			price_score += price_route_bonus
			var price_phase_bonus := _ai_phase_bonus_for_candidate(player_index, "product_speculation", own_city_index, product_name, player_index)
			price_score += price_phase_bonus
			var price_learning_bonus := _ai_learning_bonus(player_index, "price_pump", strategy_intent, route_stage, product_name, "匿名商业")
			price_score += price_learning_bonus
			var price_signature := _ai_profile_signature_bonus_for_candidate(player_index, "product_speculation", own_city_index, product_name, player_index)
			var price_signature_bonus := int(price_signature.get("bonus", 0))
			price_score += price_signature_bonus
			var price_victory := _ai_victory_race_bonus_for_candidate(player_index, "product_speculation", own_city_index, product_name, player_index)
			var price_victory_bonus := int(price_victory.get("bonus", 0))
			price_score += price_victory_bonus
			result.append({
				"kind": "price_pump",
				"own_city": own_city_index,
				"product": product_name,
				"score": max(1, price_score),
				"focus_product": focus_product,
				"focus_bonus": AI_ECONOMIC_FOCUS_MATCH_BONUS if product_name == focus_product else 0,
				"strategy_intent": strategy_intent,
				"strategy_score": strategy_score,
				"strategy_bonus": price_strategy_bonus,
				"route_plan_product": route_product,
				"route_plan_stage": route_stage,
				"route_plan_score": plan_route_score,
				"route_plan_bonus": price_route_bonus,
				"game_phase": phase,
				"competitive_posture": posture,
				"score_gap_to_leader": int(phase_info.get("gap", 0)),
				"leader_index": int(phase_info.get("leader_index", -1)),
				"phase_bonus": price_phase_bonus,
				"policy_kind": "price_pump",
				"learning_bonus": price_learning_bonus,
				"profile_signature_bonus": price_signature_bonus,
				"profile_signature_family": String(price_signature.get("family", "")),
				"profile_signature_route": String(price_signature.get("route", "")),
				"profile_signature_reason": String(price_signature.get("reason", "")),
				"victory_race_bonus": price_victory_bonus,
				"victory_race_role": String(price_victory.get("role", "")),
				"victory_race_reason": String(price_victory.get("reason", "")),
			})
			for target_city_variant in competitors:
				var target_city_index := int(target_city_variant)
				var target_city := _district_city(target_city_index)
				var route_score := 42 + int(round(float(price) / 5.0))
				route_score += (target_city.get("trade_routes", []) as Array).size() * 4
				route_score += int(float(int(target_city.get("last_income", 0))) / 8.0)
				route_score += int(target_city.get("competition_matches", 0)) * 7
				if product_name == focus_product:
					route_score += AI_ECONOMIC_FOCUS_MATCH_BONUS + 24
				var route_strategy_bonus := _ai_strategy_bonus_for_candidate(player_index, "route_sabotage", target_city_index, product_name, int(target_city.get("owner", -1)))
				route_score += route_strategy_bonus
				var sabotage_route_bonus := _ai_route_plan_bonus_for_candidate(player_index, "route_sabotage", target_city_index, product_name, int(target_city.get("owner", -1)))
				route_score += sabotage_route_bonus
				var sabotage_phase_bonus := _ai_phase_bonus_for_candidate(player_index, "route_sabotage", target_city_index, product_name, int(target_city.get("owner", -1)))
				route_score += sabotage_phase_bonus
				var sabotage_learning_bonus := _ai_learning_bonus(player_index, "route_sabotage", strategy_intent, route_stage, product_name, "匿名商业")
				route_score += sabotage_learning_bonus
				var sabotage_signature := _ai_profile_signature_bonus_for_candidate(player_index, "route_sabotage", target_city_index, product_name, int(target_city.get("owner", -1)))
				var sabotage_signature_bonus := int(sabotage_signature.get("bonus", 0))
				route_score += sabotage_signature_bonus
				var sabotage_victory := _ai_victory_race_bonus_for_candidate(player_index, "route_sabotage", target_city_index, product_name, int(target_city.get("owner", -1)))
				var sabotage_victory_bonus := int(sabotage_victory.get("bonus", 0))
				route_score += sabotage_victory_bonus
				result.append({
					"kind": "route_sabotage",
					"own_city": own_city_index,
					"target_city": target_city_index,
					"product": product_name,
					"score": max(1, route_score),
					"focus_product": focus_product,
					"focus_bonus": AI_ECONOMIC_FOCUS_MATCH_BONUS + 24 if product_name == focus_product else 0,
					"strategy_intent": strategy_intent,
					"strategy_score": strategy_score,
					"strategy_bonus": route_strategy_bonus,
					"route_plan_product": route_product,
					"route_plan_stage": route_stage,
					"route_plan_score": plan_route_score,
					"route_plan_bonus": sabotage_route_bonus,
					"game_phase": phase,
					"competitive_posture": posture,
					"score_gap_to_leader": int(phase_info.get("gap", 0)),
					"leader_index": int(phase_info.get("leader_index", -1)),
					"phase_bonus": sabotage_phase_bonus,
					"policy_kind": "route_sabotage",
					"learning_bonus": sabotage_learning_bonus,
					"profile_signature_bonus": sabotage_signature_bonus,
					"profile_signature_family": String(sabotage_signature.get("family", "")),
					"profile_signature_route": String(sabotage_signature.get("route", "")),
					"profile_signature_reason": String(sabotage_signature.get("reason", "")),
					"victory_race_bonus": sabotage_victory_bonus,
					"victory_race_role": String(sabotage_victory.get("role", "")),
					"victory_race_reason": String(sabotage_victory.get("reason", "")),
				})
	return result
func _pick_rival_business_action(player_index: int) -> Dictionary:
	var candidates := _rival_business_candidates_for_player(player_index)
	if candidates.is_empty():
		return {}
	var weights := []
	for candidate_variant in candidates:
		var candidate: Dictionary = candidate_variant
		weights.append(int(candidate.get("score", 1)))
	var picked := _weighted_pick_index(weights)
	if picked < 0:
		return {}
	return candidates[picked] as Dictionary
func _auto_rival_business_actions(force: bool = false) -> int:
	if session_finished or players.size() <= 1:
		return 0
	var acted := 0
	var limit: int = int(players.size()) - 1 if force else int(RIVAL_BUSINESS_ACTION_MAX_PER_CYCLE)
	for player_index_variant in _rival_build_player_order():
		if acted >= limit:
			break
		var player_index := int(player_index_variant)
		if int(players[player_index].get("cash", 0)) < RIVAL_BUSINESS_ACTION_COST:
			continue
		if not force and rng.randi_range(1, 100) > RIVAL_BUSINESS_ACTION_CHANCE_PERCENT:
			continue
		var action := _pick_rival_business_action(player_index)
		if action.is_empty():
			continue
		if _apply_rival_business_action(player_index, action):
			var target := int(action.get("target_city", action.get("own_city", -1)))
			_record_ai_decision(
				player_index,
				"匿名商业",
				target,
				int(action.get("score", 0)),
				"商品:%s｜阶段:%s/%s+%d｜经济焦点:%s｜焦点加成%d｜策略:%s｜策略加成%d｜路线:%s/%s｜路线加成%d｜性格签名+%d:%s｜终局竞速+%d:%s" % [
					String(action.get("product", "未知")),
					_ai_game_phase_label(String(action.get("game_phase", "midgame"))),
					_ai_competitive_posture_label(String(action.get("competitive_posture", "contesting"))),
					int(action.get("phase_bonus", 0)),
					String(action.get("focus_product", "")),
					int(action.get("focus_bonus", 0)),
					String(action.get("strategy_intent", "")),
					int(action.get("strategy_bonus", 0)),
					String(action.get("route_plan_product", "")),
					_ai_route_plan_stage_label(String(action.get("route_plan_stage", ""))),
					int(action.get("route_plan_bonus", 0)),
					int(action.get("profile_signature_bonus", 0)),
					String(action.get("profile_signature_reason", "")),
					int(action.get("victory_race_bonus", 0)),
					String(action.get("victory_race_reason", "")),
				],
				[],
				{"policy_kind": String(action.get("policy_kind", action.get("kind", ""))), "product": String(action.get("product", "")), "focus_product": String(action.get("focus_product", "")), "focus_bonus": int(action.get("focus_bonus", 0)), "strategy_intent": String(action.get("strategy_intent", "")), "strategy_score": int(action.get("strategy_score", 0)), "strategy_bonus": int(action.get("strategy_bonus", 0)), "route_plan_product": String(action.get("route_plan_product", "")), "route_plan_stage": String(action.get("route_plan_stage", "")), "route_plan_score": int(action.get("route_plan_score", 0)), "route_plan_bonus": int(action.get("route_plan_bonus", 0)), "profile_signature_bonus": int(action.get("profile_signature_bonus", 0)), "profile_signature_family": String(action.get("profile_signature_family", "")), "profile_signature_route": String(action.get("profile_signature_route", "")), "profile_signature_reason": String(action.get("profile_signature_reason", "")), "victory_race_bonus": int(action.get("victory_race_bonus", 0)), "victory_race_role": String(action.get("victory_race_role", "")), "victory_race_reason": String(action.get("victory_race_reason", "")), "game_phase": String(action.get("game_phase", "midgame")), "competitive_posture": String(action.get("competitive_posture", "contesting")), "score_gap_to_leader": int(action.get("score_gap_to_leader", 0)), "leader_index": int(action.get("leader_index", -1)), "phase_bonus": int(action.get("phase_bonus", 0)), "learning_bonus": int(action.get("learning_bonus", 0))}
			)
			acted += 1
	if acted > 0:
		_log("经营暗流：%d次匿名商业行动留下公开线索，但没有揭示真实业主。" % acted)
		_refresh_ui()
	return acted
func _ai_development_route_preference_audit() -> Dictionary:
	var coverage := {}
	for profile_variant in AI_PERSONALITY_CATALOG:
		var profile: Dictionary = profile_variant
		var preferences_variant: Variant = profile.get("route_preferences", {})
		if not (preferences_variant is Dictionary):
			continue
		var preferences: Dictionary = preferences_variant
		for route_variant in preferences.keys():
			var route_id := String(route_variant)
			if float(preferences.get(route_id, 1.0)) > 1.001:
				coverage[route_id] = int(coverage.get(route_id, 0)) + 1
	return coverage
func _ai_profile_primary_development_route(profile: Dictionary) -> Dictionary:
	var preferences_variant: Variant = profile.get("route_preferences", {})
	if not (preferences_variant is Dictionary):
		return {}
	var preferences := preferences_variant as Dictionary
	var best_route := ""
	var best_bias := 1.0
	for route_variant in preferences.keys():
		var route_id := String(route_variant)
		var bias := float(preferences.get(route_id, 1.0))
		if bias > best_bias:
			best_bias = bias
			best_route = route_id
	if best_route == "":
		return {}
	return {
		"route_id": best_route,
		"label": _development_route_label(best_route),
		"bias": best_bias,
	}
func _ai_development_route_diversity_audit() -> Dictionary:
	var core_routes := []
	for route_variant in _development_route_archetypes():
		var route: Dictionary = route_variant
		if bool(route.get("required_for_ai_baseline", false)):
			core_routes.append(String(route.get("id", "")))
	var primary_counts := {}
	var profile_entries := []
	for profile_variant in AI_PERSONALITY_CATALOG:
		var profile: Dictionary = profile_variant
		var primary := _ai_profile_primary_development_route(profile)
		var route_id := String(primary.get("route_id", ""))
		if route_id != "":
			primary_counts[route_id] = int(primary_counts.get(route_id, 0)) + 1
		var secondary_routes := []
		var preferences_variant: Variant = profile.get("route_preferences", {})
		if preferences_variant is Dictionary:
			var preferences := preferences_variant as Dictionary
			for route_variant in preferences.keys():
				var secondary_id := String(route_variant)
				if secondary_id == route_id:
					continue
				if float(preferences.get(secondary_id, 1.0)) > 1.001:
					secondary_routes.append(_development_route_label(secondary_id))
		profile_entries.append({
			"profile": String(profile.get("name", "AI")),
			"style": String(profile.get("style", "")),
			"primary_route": route_id,
			"primary_label": String(primary.get("label", "未定")),
			"primary_bias": float(primary.get("bias", 1.0)),
			"secondary_routes": secondary_routes,
		})
	var covered_core_routes := []
	var missing_core_routes := []
	for route_variant in core_routes:
		var route_id := String(route_variant)
		if int(primary_counts.get(route_id, 0)) > 0:
			covered_core_routes.append(route_id)
		else:
			missing_core_routes.append(route_id)
	return {
		"profile_count": AI_PERSONALITY_CATALOG.size(),
		"core_route_count": core_routes.size(),
		"covered_core_route_count": covered_core_routes.size(),
		"core_routes": core_routes,
		"covered_core_routes": covered_core_routes,
		"missing_core_routes": missing_core_routes,
		"primary_counts": primary_counts,
		"profiles": profile_entries,
	}
func _ai_development_route_diversity_summary() -> String:
	var audit := _ai_development_route_diversity_audit()
	var counts := audit.get("primary_counts", {}) as Dictionary
	var pieces := []
	for route_variant in (audit.get("core_routes", []) as Array):
		var route_id := String(route_variant)
		var count := int(counts.get(route_id, 0))
		if count > 0:
			pieces.append("%s×%d" % [_development_route_label(route_id), count])
	var missing_labels := []
	for route_variant in (audit.get("missing_core_routes", []) as Array):
		missing_labels.append(_development_route_label(String(route_variant)))
	return "%d类AI性格｜核心路线%d/%d覆盖｜主偏好:%s%s" % [
		int(audit.get("profile_count", 0)),
		int(audit.get("covered_core_route_count", 0)),
		int(audit.get("core_route_count", 0)),
		" / ".join(pieces) if not pieces.is_empty() else "暂无",
		"" if missing_labels.is_empty() else "｜缺口:%s" % " / ".join(missing_labels),
	]
func _ai_profile_route_action_report() -> Dictionary:
	var profiles_by_index := {}
	for profile_index in range(AI_PERSONALITY_CATALOG.size()):
		var profile: Dictionary = AI_PERSONALITY_CATALOG[profile_index]
		var primary := _ai_profile_primary_development_route(profile)
		profiles_by_index[profile_index] = {
			"profile_index": profile_index,
			"profile": String(profile.get("name", "AI")),
			"style": String(profile.get("style", "")),
			"primary_route": String(primary.get("route_id", "")),
			"primary_label": String(primary.get("label", "未定")),
			"player_count": 0,
			"sample_count": 0,
			"route_sample_count": 0,
			"primary_route_count": 0,
			"route_counts": {},
			"action_counts": {},
		}
	var distinct_routes := {}
	for player_index_variant in _ai_player_indices():
		var player_index := int(player_index_variant)
		if player_index < 0 or player_index >= players.size():
			continue
		var player: Dictionary = players[player_index]
		var profile_variant: Variant = player.get("ai_profile", {})
		if not (profile_variant is Dictionary):
			continue
		var profile := profile_variant as Dictionary
		var profile_index := int(profile.get("profile_index", -1))
		if profile_index < 0 or profile_index >= AI_PERSONALITY_CATALOG.size() or not profiles_by_index.has(profile_index):
			continue
		var entry := (profiles_by_index[profile_index] as Dictionary).duplicate(true)
		entry["player_count"] = int(entry.get("player_count", 0)) + 1
		var route_counts := (entry.get("route_counts", {}) as Dictionary).duplicate(true)
		var action_counts := (entry.get("action_counts", {}) as Dictionary).duplicate(true)
		var memory_variant: Variant = player.get("ai_memory", {})
		var samples := []
		if memory_variant is Dictionary:
			var samples_variant: Variant = (memory_variant as Dictionary).get("decision_samples", [])
			if samples_variant is Array:
				samples = samples_variant as Array
		for sample_variant in samples:
			if not (sample_variant is Dictionary):
				continue
			var sample := sample_variant as Dictionary
			entry["sample_count"] = int(entry.get("sample_count", 0)) + 1
			var action_kind := String(sample.get("kind", ""))
			if action_kind != "":
				action_counts[action_kind] = int(action_counts.get(action_kind, 0)) + 1
			var route_id := _ai_sample_development_route_id(sample)
			if route_id == "":
				continue
			route_counts[route_id] = int(route_counts.get(route_id, 0)) + 1
			distinct_routes[route_id] = true
			entry["route_sample_count"] = int(entry.get("route_sample_count", 0)) + 1
			if route_id == String(entry.get("primary_route", "")):
				entry["primary_route_count"] = int(entry.get("primary_route_count", 0)) + 1
		entry["route_counts"] = route_counts
		entry["action_counts"] = action_counts
		entry["has_route_action"] = int(entry.get("route_sample_count", 0)) > 0
		entry["has_primary_route_action"] = int(entry.get("primary_route_count", 0)) > 0
		profiles_by_index[profile_index] = entry
	var entries := []
	var missing_route_profiles := []
	var missing_primary_profiles := []
	var primary_covered := 0
	for profile_index in range(AI_PERSONALITY_CATALOG.size()):
		var entry := profiles_by_index[profile_index] as Dictionary
		if int(entry.get("route_sample_count", 0)) <= 0:
			missing_route_profiles.append(String(entry.get("profile", "AI")))
		if String(entry.get("primary_route", "")) != "" and int(entry.get("primary_route_count", 0)) <= 0:
			missing_primary_profiles.append(String(entry.get("profile", "AI")))
		else:
			primary_covered += 1
		entries.append(entry)
	return {
		"profile_count": AI_PERSONALITY_CATALOG.size(),
		"simulated_profile_count": entries.size() - missing_route_profiles.size(),
		"covered_distinct_route_count": distinct_routes.size(),
		"distinct_routes": distinct_routes.keys(),
		"primary_covered_profile_count": primary_covered,
		"missing_route_profiles": missing_route_profiles,
		"missing_primary_profiles": missing_primary_profiles,
		"profiles": entries,
	}
func _ai_profile_route_action_summary(report: Dictionary = {}) -> String:
	var source := report
	if source.is_empty():
		source = _ai_profile_route_action_report()
	var pieces := []
	for entry_variant in (source.get("profiles", []) as Array):
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var primary_label := String(entry.get("primary_label", "未定"))
		var primary_count := int(entry.get("primary_route_count", 0))
		var route_count := int(entry.get("route_sample_count", 0))
		pieces.append("%s:%s×%d/路线样本%d" % [
			String(entry.get("profile", "AI")),
			primary_label,
			primary_count,
			route_count,
		])
	var missing_route := source.get("missing_route_profiles", []) as Array
	var missing_primary := source.get("missing_primary_profiles", []) as Array
	return "AI路线行动报告：profile %d/%d有路线样本｜核心路线覆盖%d｜主偏好覆盖%d/%d｜%s%s%s" % [
		int(source.get("simulated_profile_count", 0)),
		int(source.get("profile_count", 0)),
		int(source.get("covered_distinct_route_count", 0)),
		int(source.get("primary_covered_profile_count", 0)),
		int(source.get("profile_count", 0)),
		"；".join(pieces),
		"" if missing_route.is_empty() else "｜缺路线样本:%s" % "、".join(missing_route),
		"" if missing_primary.is_empty() else "｜缺主偏好:%s" % "、".join(missing_primary),
	]
func _ai_live_route_balance_report() -> Dictionary:
	var required_core_routes := []
	for route_variant in _development_route_archetypes():
		var route: Dictionary = route_variant
		if bool(route.get("required_for_ai_baseline", false)):
			required_core_routes.append(String(route.get("id", "")))
	var route_counts := {}
	var route_score_totals := {}
	var action_counts := {}
	var player_entries := []
	var ai_count := 0
	var route_sample_ai_count := 0
	var money_progress_ai_count := 0
	var primary_route_player_count := 0
	var total_route_samples := 0
	var total_samples := 0
	for player_index_variant in _ai_player_indices():
		var player_index := int(player_index_variant)
		if player_index < 0 or player_index >= players.size():
			continue
		ai_count += 1
		var player: Dictionary = players[player_index]
		var profile: Dictionary = player.get("ai_profile", {}) as Dictionary
		var primary := _ai_profile_primary_development_route(profile)
		var primary_route := String(primary.get("route_id", ""))
		var memory_variant: Variant = player.get("ai_memory", {})
		var samples := []
		if memory_variant is Dictionary:
			var samples_variant: Variant = (memory_variant as Dictionary).get("decision_samples", [])
			if samples_variant is Array:
				samples = samples_variant as Array
		var player_route_counts := {}
		var player_action_counts := {}
		var player_route_score := {}
		var player_route_samples := 0
		var player_primary_samples := 0
		for sample_variant in samples:
			if not (sample_variant is Dictionary):
				continue
			var sample := sample_variant as Dictionary
			total_samples += 1
			var action_kind := String(sample.get("kind", ""))
			if action_kind != "":
				action_counts[action_kind] = int(action_counts.get(action_kind, 0)) + 1
				player_action_counts[action_kind] = int(player_action_counts.get(action_kind, 0)) + 1
			var route_id := _ai_sample_development_route_id(sample)
			if route_id == "":
				continue
			player_route_samples += 1
			total_route_samples += 1
			player_route_counts[route_id] = int(player_route_counts.get(route_id, 0)) + 1
			route_counts[route_id] = int(route_counts.get(route_id, 0)) + 1
			var score := maxi(0, int(sample.get("score", 0)))
			player_route_score[route_id] = int(player_route_score.get(route_id, 0)) + score
			route_score_totals[route_id] = int(route_score_totals.get(route_id, 0)) + score
			if route_id == primary_route:
				player_primary_samples += 1
		if player_route_samples > 0:
			route_sample_ai_count += 1
		if player_primary_samples > 0:
			primary_route_player_count += 1
		var top_route := ""
		var top_route_score := -1
		for route_variant in player_route_score.keys():
			var route_id := String(route_variant)
			var score := int(player_route_score.get(route_id, 0))
			var count := int(player_route_counts.get(route_id, 0))
			var best_count := int(player_route_counts.get(top_route, 0)) if top_route != "" else -1
			if score > top_route_score or (score == top_route_score and count > best_count):
				top_route = route_id
				top_route_score = score
		var money_progress := maxi(0, int(player.get("total_city_income", 0))) \
			+ maxi(0, int(player.get("total_card_income", 0))) \
			+ maxi(0, int(player.get("total_role_income", 0)))
		var board_progress := int(player.get("cities_built", 0)) \
			+ _player_active_city_count(player_index) \
			+ _ai_owned_active_monster_count(player_index)
		var victory_top_n_gdp := _victory_top_n_gdp(player_index)
		var spent_pressure := maxi(0, int(player.get("total_card_spend", 0))) \
			+ maxi(0, int(player.get("total_build_spend", 0))) \
			+ maxi(0, int(player.get("total_business_spend", 0)))
		var has_money_progress := money_progress > 0
		if has_money_progress:
			money_progress_ai_count += 1
		player_entries.append({
			"player_index": player_index,
			"profile": String(profile.get("name", "AI")),
			"primary_route": primary_route,
			"primary_label": String(primary.get("label", "未定")),
			"sample_count": samples.size(),
			"route_sample_count": player_route_samples,
			"primary_route_count": player_primary_samples,
			"top_route": top_route,
			"top_route_label": _development_route_label(top_route),
			"top_route_score": maxi(0, top_route_score),
			"route_counts": player_route_counts,
			"action_counts": player_action_counts,
			"money_progress": money_progress,
			"victory_top_n_gdp_per_minute": victory_top_n_gdp,
			"victory_controlled_region_count": _victory_controlled_regions(player_index),
			"spent_pressure": spent_pressure,
			"board_progress": board_progress,
			"has_money_progress": has_money_progress,
		})
	var covered_core_routes := []
	var missing_core_routes := []
	for route_variant in required_core_routes:
		var route_id := String(route_variant)
		if int(route_counts.get(route_id, 0)) > 0:
			covered_core_routes.append(route_id)
		else:
			missing_core_routes.append(route_id)
	var strongest_route := ""
	var strongest_score := -1
	for route_variant in route_score_totals.keys():
		var route_id := String(route_variant)
		var score := int(route_score_totals.get(route_id, 0))
		if score > strongest_score:
			strongest_route = route_id
			strongest_score = score
	var minimum_money_progress := maxi(1, ai_count - 1)
	var minimum_primary := mini(ai_count, 4)
	var minimum_core_routes := mini(required_core_routes.size(), 4)
	var action_kind_count := action_counts.keys().size()
	var issues := []
	if ai_count <= 0:
		issues.append("没有AI席位")
	if route_sample_ai_count < ai_count:
		issues.append("部分AI缺少路线样本:%d/%d" % [route_sample_ai_count, ai_count])
	if money_progress_ai_count < minimum_money_progress:
		issues.append("经济推进AI不足:%d/%d" % [money_progress_ai_count, minimum_money_progress])
	if covered_core_routes.size() < minimum_core_routes:
		issues.append("实战核心路线不足:%d/%d" % [covered_core_routes.size(), minimum_core_routes])
	if primary_route_player_count < minimum_primary:
		issues.append("主偏好命中不足:%d/%d" % [primary_route_player_count, minimum_primary])
	if action_kind_count < 3:
		issues.append("行动种类不足:%d" % action_kind_count)
	return {
		"ok": issues.is_empty(),
		"issues": issues,
		"ai_count": ai_count,
		"route_sample_ai_count": route_sample_ai_count,
		"money_progress_ai_count": money_progress_ai_count,
		"primary_route_player_count": primary_route_player_count,
		"total_sample_count": total_samples,
		"total_route_sample_count": total_route_samples,
		"required_core_routes": required_core_routes,
		"covered_core_routes": covered_core_routes,
		"missing_core_routes": missing_core_routes,
		"covered_core_route_count": covered_core_routes.size(),
		"distinct_route_count": route_counts.keys().size(),
		"route_counts": route_counts,
		"route_score_totals": route_score_totals,
		"strongest_route": strongest_route,
		"strongest_route_label": _development_route_label(strongest_route),
		"strongest_route_score": maxi(0, strongest_score),
		"action_counts": action_counts,
		"action_kind_count": action_kind_count,
		"players": player_entries,
		"minimum_money_progress": minimum_money_progress,
		"minimum_primary": minimum_primary,
		"minimum_core_routes": minimum_core_routes,
	}
func _ai_live_route_balance_summary(report: Dictionary = {}) -> String:
	var source := report
	if source.is_empty():
		source = _ai_live_route_balance_report()
	var route_pieces := []
	var route_counts: Dictionary = source.get("route_counts", {}) as Dictionary
	for route_variant in route_counts.keys():
		var route_id := String(route_variant)
		route_pieces.append("%s×%d" % [_development_route_label(route_id), int(route_counts.get(route_id, 0))])
	var issues := source.get("issues", []) as Array
	return "AI实战路线审计：AI%d｜有路线样本%d｜经济推进%d｜核心路线%d/%d｜主偏好%d｜行动%d类｜最强:%s(%d)%s｜%s" % [
		int(source.get("ai_count", 0)),
		int(source.get("route_sample_ai_count", 0)),
		int(source.get("money_progress_ai_count", 0)),
		int(source.get("covered_core_route_count", 0)),
		(source.get("required_core_routes", []) as Array).size(),
		int(source.get("primary_route_player_count", 0)),
		int(source.get("action_kind_count", 0)),
		String(source.get("strongest_route_label", "未定")),
		int(source.get("strongest_route_score", 0)),
		"" if issues.is_empty() else "｜问题:%s" % "、".join(issues),
		"；".join(route_pieces) if not route_pieces.is_empty() else "暂无路线样本",
	]
func _ai_sample_viability_entry(sample: Dictionary) -> Dictionary:
	var route_id := _ai_sample_development_route_id(sample)
	var kind := String(sample.get("kind", ""))
	var policy_kind := String(sample.get("policy_kind", ""))
	var card_name := String(sample.get("card_name", ""))
	var canonical_card := _canonical_card_supply_name(card_name)
	if canonical_card == "" and _skill_exists(card_name):
		canonical_card = card_name
	var skill := _skill_definition(canonical_card) if canonical_card != "" else {}
	if route_id == "" and not skill.is_empty():
		route_id = _card_development_route_id(skill)
	if route_id == "":
		route_id = _ai_development_route_for_kind(policy_kind if policy_kind != "" else kind, skill)
	if route_id == "":
		route_id = "tactical_support"
	var score := maxi(0, int(sample.get("score", 0)))
	var money_score := 0
	var disruption_score := 0
	var protection_score := 0
	var intel_supply_score := 0
	var gate_score := 0
	var clue_score := 0
	var pressure_score := 0
	if not skill.is_empty():
		var pressure := _development_route_pressure_card_entry(canonical_card, skill)
		money_score += int(pressure.get("money_score", 0))
		disruption_score += int(pressure.get("disruption_score", 0))
		protection_score += int(pressure.get("protection_score", 0))
		intel_supply_score += int(pressure.get("intel_supply_score", 0))
		gate_score += int(pressure.get("gate_score", 0))
		clue_score += int(pressure.get("public_clue_score", 0))
		pressure_score += int(pressure.get("total_pressure", 0))
	if policy_kind == "city_build" or kind == "城市化":
		route_id = "city_growth"
		money_score += 160
		gate_score += 90
		clue_score += 55
		pressure_score += 150
	if policy_kind.contains("contract") or kind.contains("合约"):
		if route_id == "tactical_support":
			route_id = "contract_route"
		money_score += 95
		gate_score += 75
		clue_score += 65
		pressure_score += 110
	if policy_kind.contains("futures") or policy_kind.contains("gdp") or policy_kind.contains("price") or policy_kind.contains("product_speculation"):
		if route_id == "tactical_support":
			route_id = "finance_speculation"
		money_score += 110
		gate_score += 70
		clue_score += 70
		pressure_score += 120
	if policy_kind.contains("route_sabotage") or policy_kind.contains("monster") or policy_kind.contains("weather") or policy_kind.contains("news"):
		if route_id == "tactical_support":
			route_id = "monster_pressure"
		disruption_score += 130
		clue_score += 60
		gate_score += 55
		pressure_score += 135
	if policy_kind.contains("intel") or kind.contains("情报") or policy_kind.contains("supply") or policy_kind.contains("card_access"):
		if route_id == "tactical_support":
			route_id = "intel_supply"
		intel_supply_score += 120
		gate_score += 55
		clue_score += 40
		pressure_score += 95
	if policy_kind.contains("direct") or policy_kind.contains("hand") or policy_kind.contains("control") or policy_kind.contains("barrage"):
		if route_id == "tactical_support":
			route_id = "direct_interaction"
		disruption_score += 125
		clue_score += 90
		gate_score += 75
		pressure_score += 130
	if int(sample.get("focus_bonus", 0)) > 0 or int(sample.get("route_plan_bonus", 0)) > 0 or int(sample.get("strategy_bonus", 0)) > 0:
		pressure_score += int(float(mini(180, int(sample.get("focus_bonus", 0)) + int(sample.get("route_plan_bonus", 0)) + int(sample.get("strategy_bonus", 0)))) / 2.0)
	if int(sample.get("phase_bonus", 0)) > 0 or int(sample.get("victory_race_bonus", 0)) > 0:
		pressure_score += int(float(mini(160, int(sample.get("phase_bonus", 0)) + int(sample.get("victory_race_bonus", 0)))) / 2.0)
	var weighted_score := score + pressure_score + money_score + disruption_score + protection_score + intel_supply_score
	return {
		"route_id": route_id,
		"route_label": _development_route_label(route_id),
		"score": score,
		"weighted_score": weighted_score,
		"money_score": money_score,
		"disruption_score": disruption_score,
		"protection_score": protection_score,
		"intel_supply_score": intel_supply_score,
		"gate_score": gate_score,
		"public_clue_score": clue_score,
		"pressure_score": pressure_score,
		"card_name": canonical_card if canonical_card != "" else card_name,
		"kind": kind,
		"policy_kind": policy_kind,
	}
func _ai_route_viability_report() -> Dictionary:
	var route_entries := {}
	var required_routes := []
	var static_pressure_report := _development_route_pressure_audit()
	var static_by_route := {}
	for static_route_variant in (static_pressure_report.get("routes", []) as Array):
		if not (static_route_variant is Dictionary):
			continue
		var static_route := static_route_variant as Dictionary
		static_by_route[String(static_route.get("id", ""))] = static_route
	for route_variant in _development_route_archetypes():
		var route: Dictionary = route_variant
		var route_id := String(route.get("id", "tactical_support"))
		if bool(route.get("required_for_ai_baseline", false)):
			required_routes.append(route_id)
		var static_entry: Dictionary = static_by_route.get(route_id, {})
		route_entries[route_id] = {
			"id": route_id,
			"label": String(route.get("label", _development_route_label(route_id))),
			"required_for_ai_baseline": bool(route.get("required_for_ai_baseline", false)),
			"sample_count": 0,
			"player_count": 0,
			"primary_player_count": 0,
			"total_score": 0,
			"top_score": 0,
			"money_score": 0,
			"disruption_score": 0,
			"protection_score": 0,
			"intel_supply_score": 0,
			"gate_score": int(static_entry.get("gate_score", 0)),
			"public_clue_score": int(static_entry.get("public_clue_score", 0)),
			"static_pressure": int(static_entry.get("total_pressure", 0)),
			"static_status": String(static_entry.get("status", "")),
			"ai_profile_count": int(static_entry.get("primary_ai_profiles", 0)),
			"sample_cards": static_entry.get("sample_cards", []),
			"players": [],
			"top_samples": [],
			"viable": false,
			"notes": [],
		}
	var route_players := {}
	var primary_route_players := {}
	for player_index_variant in _ai_player_indices():
		var player_index := int(player_index_variant)
		if player_index < 0 or player_index >= players.size():
			continue
		var player: Dictionary = players[player_index]
		var profile: Dictionary = player.get("ai_profile", {}) as Dictionary
		var primary := _ai_profile_primary_development_route(profile)
		var primary_route := String(primary.get("route_id", ""))
		var samples := []
		var memory_variant: Variant = player.get("ai_memory", {})
		if memory_variant is Dictionary:
			var samples_variant: Variant = (memory_variant as Dictionary).get("decision_samples", [])
			if samples_variant is Array:
				samples = samples_variant as Array
		for sample_variant in samples:
			if not (sample_variant is Dictionary):
				continue
			var sample := sample_variant as Dictionary
			var viability := _ai_sample_viability_entry(sample)
			var route_id := String(viability.get("route_id", "tactical_support"))
			if not route_entries.has(route_id):
				route_id = "tactical_support"
			var entry: Dictionary = route_entries[route_id]
			entry["sample_count"] = int(entry.get("sample_count", 0)) + 1
			entry["total_score"] = int(entry.get("total_score", 0)) + int(viability.get("weighted_score", 0))
			entry["top_score"] = maxi(int(entry.get("top_score", 0)), int(viability.get("weighted_score", 0)))
			entry["money_score"] = int(entry.get("money_score", 0)) + int(viability.get("money_score", 0))
			entry["disruption_score"] = int(entry.get("disruption_score", 0)) + int(viability.get("disruption_score", 0))
			entry["protection_score"] = int(entry.get("protection_score", 0)) + int(viability.get("protection_score", 0))
			entry["intel_supply_score"] = int(entry.get("intel_supply_score", 0)) + int(viability.get("intel_supply_score", 0))
			entry["gate_score"] = int(entry.get("gate_score", 0)) + int(viability.get("gate_score", 0))
			entry["public_clue_score"] = int(entry.get("public_clue_score", 0)) + int(viability.get("public_clue_score", 0))
			if not route_players.has(route_id):
				route_players[route_id] = []
			var players_for_route: Array = route_players[route_id]
			if not players_for_route.has(player_index):
				players_for_route.append(player_index)
				route_players[route_id] = players_for_route
			if primary_route == route_id:
				if not primary_route_players.has(route_id):
					primary_route_players[route_id] = []
				var primary_players: Array = primary_route_players[route_id]
				if not primary_players.has(player_index):
					primary_players.append(player_index)
					primary_route_players[route_id] = primary_players
			var top_samples: Array = entry.get("top_samples", [])
			top_samples.append({
				"player_index": player_index,
				"score": int(viability.get("weighted_score", 0)),
				"card_name": String(viability.get("card_name", "")),
				"kind": String(viability.get("kind", "")),
				"policy_kind": String(viability.get("policy_kind", "")),
			})
			top_samples.sort_custom(Callable(self, "_sort_ai_candidate_score_desc"))
			if top_samples.size() > 4:
				top_samples.resize(4)
			entry["top_samples"] = top_samples
			route_entries[route_id] = entry
	var routes := []
	var viable_required_routes := []
	var missing_required_routes := []
	var issues := []
	for route_id_variant in route_entries.keys():
		var route_id := String(route_id_variant)
		var entry: Dictionary = route_entries[route_id]
		var players_for_route: Array = route_players.get(route_id, [])
		var primary_players: Array = primary_route_players.get(route_id, [])
		entry["player_count"] = players_for_route.size()
		entry["primary_player_count"] = primary_players.size()
		entry["players"] = players_for_route
		var route_pressure := int(entry.get("static_pressure", 0)) + int(entry.get("total_score", 0))
		var route_money := int(entry.get("money_score", 0))
		var route_disruption := int(entry.get("disruption_score", 0))
		var route_protection := int(entry.get("protection_score", 0))
		var route_intel := int(entry.get("intel_supply_score", 0))
		var has_route_value := route_money > 0 or route_disruption > 0 or route_protection > 0 or route_intel > 0 or int(entry.get("static_pressure", 0)) >= 160
		var has_ai_access := int(entry.get("player_count", 0)) > 0 or int(entry.get("primary_player_count", 0)) > 0 or int(entry.get("ai_profile_count", 0)) > 0
		var has_readable_gates := int(entry.get("gate_score", 0)) >= 120 and int(entry.get("public_clue_score", 0)) >= 80
		var viable := has_route_value and has_ai_access and has_readable_gates and route_pressure >= 260
		var notes := []
		if not has_route_value:
			notes.append("缺收益/压制/防御/信息价值")
		if not has_ai_access:
			notes.append("缺AI偏好或实战样本")
		if not has_readable_gates:
			notes.append("门槛/线索不足")
		if route_pressure < 260:
			notes.append("可追目标压力不足")
		entry["route_pressure"] = route_pressure
		entry["viable"] = viable
		entry["notes"] = notes
		if bool(entry.get("required_for_ai_baseline", false)):
			if viable:
				viable_required_routes.append(route_id)
			else:
				missing_required_routes.append(route_id)
				issues.append("%s:%s" % [_development_route_label(route_id), "、".join(notes)])
		routes.append(entry)
	var minimum_viable_required_routes := mini(required_routes.size(), 5)
	var ok := viable_required_routes.size() >= minimum_viable_required_routes
	if not ok and issues.is_empty():
		issues.append("可追目标路线不足:%d/%d" % [viable_required_routes.size(), minimum_viable_required_routes])
	return {
		"ok": ok,
		"issues": issues,
		"routes": routes,
		"required_routes": required_routes,
		"viable_required_routes": viable_required_routes,
		"missing_required_routes": missing_required_routes,
		"viable_required_route_count": viable_required_routes.size(),
		"minimum_viable_required_routes": minimum_viable_required_routes,
	}
func _ai_route_viability_summary(report: Dictionary = {}) -> String:
	var source := report
	if source.is_empty():
		source = _ai_route_viability_report()
	var pieces := []
	for entry_variant in (source.get("routes", []) as Array):
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if not bool(entry.get("required_for_ai_baseline", false)):
			continue
		pieces.append("%s:%s 压%d 样%d AI%d" % [
			String(entry.get("label", _development_route_label(String(entry.get("id", ""))))),
			"可追" if bool(entry.get("viable", false)) else "待补",
			int(entry.get("route_pressure", 0)),
			int(entry.get("sample_count", 0)),
			int(entry.get("player_count", 0)),
		])
	var issues := source.get("issues", []) as Array
	return "AI路线可达性审计：可追核心路线%d/%d%s｜%s" % [
		int(source.get("viable_required_route_count", 0)),
		int(source.get("minimum_viable_required_routes", 0)),
		"" if issues.is_empty() else "｜问题:%s" % "；".join(issues),
		"；".join(pieces) if not pieces.is_empty() else "暂无路线",
	]
func _ai_sample_primary_product(sample: Dictionary) -> String:
	var product_candidates := [
		String(sample.get("product", "")),
		String(sample.get("route_plan_product", "")),
		String(sample.get("focus_product", "")),
	]
	for product_variant in product_candidates:
		var product_name := String(product_variant)
		if product_name != "" and PRODUCT_CATALOG.has(product_name):
			return product_name
	var candidates_variant: Variant = sample.get("candidates", [])
	if candidates_variant is Array:
		var best_product := ""
		var best_score := -2147483648
		for candidate_variant in (candidates_variant as Array):
			if not (candidate_variant is Dictionary):
				continue
			var candidate := candidate_variant as Dictionary
			var candidate_product := String(candidate.get("product", ""))
			if candidate_product == "" or not PRODUCT_CATALOG.has(candidate_product):
				candidate_product = String(candidate.get("route_plan_product", ""))
			if candidate_product == "" or not PRODUCT_CATALOG.has(candidate_product):
				candidate_product = String(candidate.get("focus_product", ""))
			if candidate_product == "" or not PRODUCT_CATALOG.has(candidate_product):
				continue
			var candidate_score := int(candidate.get("score", 0))
			if best_product == "" or candidate_score > best_score:
				best_product = candidate_product
				best_score = candidate_score
		return best_product
	return ""
func _ai_product_sample_policy_family(sample: Dictionary) -> String:
	var kind := String(sample.get("kind", ""))
	var policy_kind := String(sample.get("policy_kind", ""))
	var strategic_role := String(sample.get("strategic_role", ""))
	if String(sample.get("futures_direction", "")) != "" or policy_kind.contains("futures") or kind == "product_futures":
		return "期货"
	if kind.contains("合约") or kind == "area_trade_contract" or policy_kind.contains("contract") or String(sample.get("contract_response_role", "")) != "":
		return "合约"
	if String(sample.get("weather_type", "")) != "" or policy_kind.contains("weather") or kind == "weather_control":
		return "天气"
	if String(sample.get("direct_interaction_role", "")) != "" or policy_kind.contains("direct") or kind.contains("直接") or ["city_control_dispute", "global_barrage"].has(kind):
		return "直接互动"
	if policy_kind.contains("monster_lure") or kind == "monster_lure" or strategic_role.contains("怪兽") or kind.contains("怪兽诱导"):
		return "怪兽诱导"
	if kind == "城市化" or policy_kind == "city_build":
		return "城市化"
	if kind == "区域购牌":
		return "购牌"
	if kind == "匿名出牌":
		return "出牌"
	if kind.contains("商业") or policy_kind.contains("route_sabotage") or policy_kind.contains("price_pump") or policy_kind.contains("product") or policy_kind.contains("market"):
		return "经营动作"
	if kind.contains("军队") or policy_kind.contains("military"):
		return "军队"
	if kind.contains("情报") or policy_kind.contains("intel"):
		return "情报"
	return "其他"
func _ai_product_route_bridge_report() -> Dictionary:
	var player_entries := []
	var product_counts := {}
	var route_stage_counts := {}
	var policy_family_counts := {}
	var development_route_counts := {}
	var ai_count := 0
	var sampled_ai_count := 0
	var product_sample_ai_count := 0
	var route_product_ai_count := 0
	var focus_product_ai_count := 0
	var total_sample_count := 0
	var product_sample_count := 0
	var route_product_sample_count := 0
	var focus_product_sample_count := 0
	var aligned_sample_count := 0
	var distinct_products := []
	for player_index_variant in _ai_player_indices():
		var player_index := int(player_index_variant)
		if player_index < 0 or player_index >= players.size():
			continue
		ai_count += 1
		var player: Dictionary = players[player_index]
		var profile: Dictionary = player.get("ai_profile", {}) as Dictionary
		var memory_variant: Variant = player.get("ai_memory", {})
		var samples := []
		if memory_variant is Dictionary:
			var samples_variant: Variant = (memory_variant as Dictionary).get("decision_samples", [])
			if samples_variant is Array:
				samples = samples_variant as Array
		if not samples.is_empty():
			sampled_ai_count += 1
		var player_products := []
		var player_policy_families := {}
		var player_sample_count := 0
		var player_product_sample_count := 0
		var player_route_product_sample_count := 0
		var player_focus_product_sample_count := 0
		var player_aligned_sample_count := 0
		for sample_variant in samples:
			if not (sample_variant is Dictionary):
				continue
			var sample := sample_variant as Dictionary
			player_sample_count += 1
			total_sample_count += 1
			var direct_product := String(sample.get("product", ""))
			var route_product := String(sample.get("route_plan_product", ""))
			var focus_product := String(sample.get("focus_product", ""))
			var primary_product := _ai_sample_primary_product(sample)
			if primary_product != "":
				player_product_sample_count += 1
				product_sample_count += 1
				product_counts[primary_product] = int(product_counts.get(primary_product, 0)) + 1
				_append_unique_string(player_products, primary_product)
				_append_unique_string(distinct_products, primary_product)
			if route_product != "" and PRODUCT_CATALOG.has(route_product):
				player_route_product_sample_count += 1
				route_product_sample_count += 1
			if focus_product != "" and PRODUCT_CATALOG.has(focus_product):
				player_focus_product_sample_count += 1
				focus_product_sample_count += 1
			if direct_product != "" and PRODUCT_CATALOG.has(direct_product) and (direct_product == route_product or direct_product == focus_product):
				player_aligned_sample_count += 1
				aligned_sample_count += 1
			var route_stage := String(sample.get("route_plan_stage", ""))
			if route_stage != "":
				route_stage_counts[route_stage] = int(route_stage_counts.get(route_stage, 0)) + 1
			var development_route := _ai_sample_development_route_id(sample)
			if development_route != "":
				development_route_counts[development_route] = int(development_route_counts.get(development_route, 0)) + 1
			var family := _ai_product_sample_policy_family(sample)
			policy_family_counts[family] = int(policy_family_counts.get(family, 0)) + 1
			player_policy_families[family] = int(player_policy_families.get(family, 0)) + 1
		if player_product_sample_count > 0:
			product_sample_ai_count += 1
		if player_route_product_sample_count > 0:
			route_product_ai_count += 1
		if player_focus_product_sample_count > 0:
			focus_product_ai_count += 1
		player_entries.append({
			"player_index": player_index,
			"profile": String(profile.get("name", "AI")),
			"sample_count": player_sample_count,
			"product_sample_count": player_product_sample_count,
			"route_product_sample_count": player_route_product_sample_count,
			"focus_product_sample_count": player_focus_product_sample_count,
			"aligned_sample_count": player_aligned_sample_count,
			"focus_product": String((player.get("ai_memory", {}) as Dictionary).get("economic_focus_product", "")) if player.get("ai_memory", {}) is Dictionary else "",
			"route_plan_product": String((player.get("ai_memory", {}) as Dictionary).get("route_plan_product", "")) if player.get("ai_memory", {}) is Dictionary else "",
			"route_plan_stage": String((player.get("ai_memory", {}) as Dictionary).get("route_plan_stage", "")) if player.get("ai_memory", {}) is Dictionary else "",
			"products": player_products,
			"policy_families": player_policy_families,
		})
	var minimum_product_ai := ai_count
	var minimum_route_product_ai := maxi(1, ai_count - 1)
	var minimum_distinct_products := mini(4, PRODUCT_CATALOG.size())
	var minimum_policy_families := 3
	var minimum_route_stages := 2
	var minimum_development_routes := 3
	var minimum_aligned_samples := maxi(1, int(ceil(float(maxi(1, ai_count)) / 2.0)))
	var issues := []
	if ai_count <= 0:
		issues.append("没有AI席位")
	if sampled_ai_count < ai_count:
		issues.append("部分AI缺少决策样本:%d/%d" % [sampled_ai_count, ai_count])
	if product_sample_ai_count < minimum_product_ai:
		issues.append("商品样本AI不足:%d/%d" % [product_sample_ai_count, minimum_product_ai])
	if route_product_ai_count < minimum_route_product_ai:
		issues.append("路线商品AI不足:%d/%d" % [route_product_ai_count, minimum_route_product_ai])
	if distinct_products.size() < minimum_distinct_products:
		issues.append("覆盖商品不足:%d/%d" % [distinct_products.size(), minimum_distinct_products])
	if policy_family_counts.keys().size() < minimum_policy_families:
		issues.append("策略族不足:%d/%d" % [policy_family_counts.keys().size(), minimum_policy_families])
	if route_stage_counts.keys().size() < minimum_route_stages:
		issues.append("路线阶段不足:%d/%d" % [route_stage_counts.keys().size(), minimum_route_stages])
	if development_route_counts.keys().size() < minimum_development_routes:
		issues.append("发展路线不足:%d/%d" % [development_route_counts.keys().size(), minimum_development_routes])
	if aligned_sample_count < minimum_aligned_samples:
		issues.append("商品/焦点/路线对齐样本不足:%d/%d" % [aligned_sample_count, minimum_aligned_samples])
	return {
		"ok": issues.is_empty(),
		"issues": issues,
		"ai_count": ai_count,
		"sampled_ai_count": sampled_ai_count,
		"product_sample_ai_count": product_sample_ai_count,
		"route_product_ai_count": route_product_ai_count,
		"focus_product_ai_count": focus_product_ai_count,
		"total_sample_count": total_sample_count,
		"product_sample_count": product_sample_count,
		"route_product_sample_count": route_product_sample_count,
		"focus_product_sample_count": focus_product_sample_count,
		"aligned_sample_count": aligned_sample_count,
		"distinct_product_count": distinct_products.size(),
		"product_counts": product_counts,
		"route_stage_counts": route_stage_counts,
		"route_stage_count": route_stage_counts.keys().size(),
		"policy_family_counts": policy_family_counts,
		"policy_family_count": policy_family_counts.keys().size(),
		"development_route_counts": development_route_counts,
		"development_route_count": development_route_counts.keys().size(),
		"players": player_entries,
		"minimum_product_ai": minimum_product_ai,
		"minimum_route_product_ai": minimum_route_product_ai,
		"minimum_distinct_products": minimum_distinct_products,
		"minimum_policy_families": minimum_policy_families,
		"minimum_route_stages": minimum_route_stages,
		"minimum_development_routes": minimum_development_routes,
		"minimum_aligned_samples": minimum_aligned_samples,
	}
func _ai_product_route_bridge_summary(report: Dictionary = {}) -> String:
	var source := report
	if source.is_empty():
		source = _ai_product_route_bridge_report()
	var issues := source.get("issues", []) as Array
	return "AI商品路线桥接审计：AI%d｜有样本%d｜商品样本AI%d｜路线商品AI%d｜样本%d/%d｜对齐%d｜商品%d｜阶段%d｜发展路线%d｜策略族%d%s｜商品:%s｜策略:%s" % [
		int(source.get("ai_count", 0)),
		int(source.get("sampled_ai_count", 0)),
		int(source.get("product_sample_ai_count", 0)),
		int(source.get("route_product_ai_count", 0)),
		int(source.get("product_sample_count", 0)),
		int(source.get("total_sample_count", 0)),
		int(source.get("aligned_sample_count", 0)),
		int(source.get("distinct_product_count", 0)),
		int(source.get("route_stage_count", 0)),
		int(source.get("development_route_count", 0)),
		int(source.get("policy_family_count", 0)),
		"" if issues.is_empty() else "｜问题:%s" % "、".join(issues),
		_product_count_summary(source.get("product_counts", {}) as Dictionary, 5, "暂无"),
		_product_count_summary(source.get("policy_family_counts", {}) as Dictionary, 5, "暂无"),
	]
func _ai_policy_families_for_development_route(route_id: String) -> Array:
	match route_id:
		"city_growth":
			return ["城市化", "经营动作", "出牌", "购牌"]
		"contract_route":
			return ["合约", "经营动作", "出牌", "购牌"]
		"finance_speculation":
			return ["期货", "经营动作", "出牌", "购牌"]
		"monster_pressure":
			return ["怪兽诱导", "经营动作", "出牌", "购牌"]
		"intel_supply":
			return ["情报", "购牌", "出牌"]
		"direct_interaction":
			return ["直接互动", "经营动作", "出牌", "购牌"]
	return ["出牌", "购牌"]
func _ai_signature_policy_families_for_development_route(route_id: String) -> Array:
	match route_id:
		"city_growth":
			return ["城市化"]
		"contract_route":
			return ["合约"]
		"finance_speculation":
			return ["期货"]
		"monster_pressure":
			return ["怪兽诱导"]
		"intel_supply":
			return ["情报"]
		"direct_interaction":
			return ["直接互动"]
	return []
func _ai_profile_expected_route_ids(profile: Dictionary) -> Array:
	var result := []
	var primary := _ai_profile_primary_development_route(profile)
	var primary_route := String(primary.get("route_id", ""))
	if primary_route != "":
		_append_unique_string(result, primary_route)
	var preferences_variant: Variant = profile.get("route_preferences", {})
	if preferences_variant is Dictionary:
		var preferences := preferences_variant as Dictionary
		for route_variant in preferences.keys():
			var route_id := String(route_variant)
			if route_id == "" or float(preferences.get(route_id, 1.0)) < 1.05:
				continue
			_append_unique_string(result, route_id)
	return result
func _ai_profile_expected_policy_families(profile: Dictionary) -> Array:
	var result := []
	for route_variant in _ai_profile_expected_route_ids(profile):
		for family_variant in _ai_policy_families_for_development_route(String(route_variant)):
			_append_unique_string(result, String(family_variant))
	return result
func _ai_profile_signature_policy_families(profile: Dictionary) -> Array:
	var result := []
	for route_variant in _ai_profile_expected_route_ids(profile):
		for family_variant in _ai_signature_policy_families_for_development_route(String(route_variant)):
			_append_unique_string(result, String(family_variant))
	return result
func _ai_profile_strategy_identity_report() -> Dictionary:
	var profiles_by_index := {}
	for profile_index in range(AI_PERSONALITY_CATALOG.size()):
		var profile: Dictionary = AI_PERSONALITY_CATALOG[profile_index]
		var primary := _ai_profile_primary_development_route(profile)
		var expected_routes := _ai_profile_expected_route_ids(profile)
		var expected_families := _ai_profile_expected_policy_families(profile)
		var signature_families := _ai_profile_signature_policy_families(profile)
		profiles_by_index[profile_index] = {
			"profile_index": profile_index,
			"profile": String(profile.get("name", "AI")),
			"style": String(profile.get("style", "")),
			"primary_route": String(primary.get("route_id", "")),
			"primary_label": String(primary.get("label", "未定")),
			"expected_routes": expected_routes,
			"expected_families": expected_families,
			"signature_families": signature_families,
			"player_count": 0,
			"sample_count": 0,
			"product_sample_count": 0,
			"primary_route_count": 0,
			"expected_route_count": 0,
			"expected_family_count": 0,
			"signature_family_count": 0,
			"signature_bonus_sample_count": 0,
			"signature_bonus_total": 0,
			"route_counts": {},
			"family_counts": {},
			"product_counts": {},
			"strategy_intent_counts": {},
			"policy_kind_counts": {},
		}
	var ai_count := 0
	var global_primary_routes := {}
	var global_signature_families := {}
	var global_expected_families := {}
	var global_signature_bonus_profiles := {}
	for player_index_variant in _ai_player_indices():
		var player_index := int(player_index_variant)
		if player_index < 0 or player_index >= players.size():
			continue
		ai_count += 1
		var player: Dictionary = players[player_index]
		var profile_variant: Variant = player.get("ai_profile", {})
		if not (profile_variant is Dictionary):
			continue
		var profile := profile_variant as Dictionary
		var profile_index := int(profile.get("profile_index", -1))
		if profile_index < 0 or profile_index >= AI_PERSONALITY_CATALOG.size() or not profiles_by_index.has(profile_index):
			continue
		var entry := (profiles_by_index[profile_index] as Dictionary).duplicate(true)
		entry["player_count"] = int(entry.get("player_count", 0)) + 1
		var expected_routes := entry.get("expected_routes", []) as Array
		var expected_families := entry.get("expected_families", []) as Array
		var signature_families := entry.get("signature_families", []) as Array
		var route_counts := (entry.get("route_counts", {}) as Dictionary).duplicate(true)
		var family_counts := (entry.get("family_counts", {}) as Dictionary).duplicate(true)
		var product_counts := (entry.get("product_counts", {}) as Dictionary).duplicate(true)
		var strategy_intent_counts := (entry.get("strategy_intent_counts", {}) as Dictionary).duplicate(true)
		var policy_kind_counts := (entry.get("policy_kind_counts", {}) as Dictionary).duplicate(true)
		var memory_variant: Variant = player.get("ai_memory", {})
		var samples := []
		if memory_variant is Dictionary:
			var samples_variant: Variant = (memory_variant as Dictionary).get("decision_samples", [])
			if samples_variant is Array:
				samples = samples_variant as Array
		for sample_variant in samples:
			if not (sample_variant is Dictionary):
				continue
			var sample := sample_variant as Dictionary
			entry["sample_count"] = int(entry.get("sample_count", 0)) + 1
			var route_id := _ai_sample_development_route_id(sample)
			if route_id != "":
				route_counts[route_id] = int(route_counts.get(route_id, 0)) + 1
				if route_id == String(entry.get("primary_route", "")):
					entry["primary_route_count"] = int(entry.get("primary_route_count", 0)) + 1
					global_primary_routes[route_id] = true
				if expected_routes.has(route_id):
					entry["expected_route_count"] = int(entry.get("expected_route_count", 0)) + 1
			var family := _ai_product_sample_policy_family(sample)
			if family != "":
				family_counts[family] = int(family_counts.get(family, 0)) + 1
				if expected_families.has(family):
					entry["expected_family_count"] = int(entry.get("expected_family_count", 0)) + 1
					global_expected_families[family] = true
				if signature_families.has(family):
					entry["signature_family_count"] = int(entry.get("signature_family_count", 0)) + 1
					global_signature_families[family] = true
			var product_name := _ai_sample_primary_product(sample)
			if product_name != "":
				entry["product_sample_count"] = int(entry.get("product_sample_count", 0)) + 1
				product_counts[product_name] = int(product_counts.get(product_name, 0)) + 1
			var strategy_intent := String(sample.get("strategy_intent", ""))
			if strategy_intent != "":
				strategy_intent_counts[strategy_intent] = int(strategy_intent_counts.get(strategy_intent, 0)) + 1
			var policy_kind := String(sample.get("policy_kind", ""))
			if policy_kind != "":
				policy_kind_counts[policy_kind] = int(policy_kind_counts.get(policy_kind, 0)) + 1
			var profile_signature_bonus := int(sample.get("profile_signature_bonus", 0))
			if profile_signature_bonus > 0:
				entry["signature_bonus_sample_count"] = int(entry.get("signature_bonus_sample_count", 0)) + 1
				entry["signature_bonus_total"] = int(entry.get("signature_bonus_total", 0)) + profile_signature_bonus
				global_signature_bonus_profiles[profile_index] = true
		entry["route_counts"] = route_counts
		entry["family_counts"] = family_counts
		entry["product_counts"] = product_counts
		entry["strategy_intent_counts"] = strategy_intent_counts
		entry["policy_kind_counts"] = policy_kind_counts
		profiles_by_index[profile_index] = entry
	var entries := []
	var simulated_profile_count := 0
	var identity_profile_count := 0
	var missing_identity_profiles := []
	for profile_index in range(AI_PERSONALITY_CATALOG.size()):
		var entry := profiles_by_index[profile_index] as Dictionary
		var player_count := int(entry.get("player_count", 0))
		if player_count > 0:
			simulated_profile_count += 1
		var has_identity := player_count > 0 \
			and int(entry.get("sample_count", 0)) > 0 \
			and int(entry.get("primary_route_count", 0)) > 0 \
			and int(entry.get("expected_route_count", 0)) > 0 \
			and int(entry.get("expected_family_count", 0)) > 0 \
			and int(entry.get("signature_bonus_sample_count", 0)) > 0 \
			and int(entry.get("product_sample_count", 0)) > 0
		entry["identity_ready"] = has_identity
		if has_identity:
			identity_profile_count += 1
		elif player_count > 0:
			missing_identity_profiles.append(String(entry.get("profile", "AI")))
		entries.append(entry)
	var expected_simulated_profiles := mini(AI_PERSONALITY_CATALOG.size(), ai_count)
	var minimum_identity_profiles := expected_simulated_profiles
	var minimum_primary_routes := mini(5, expected_simulated_profiles)
	var minimum_expected_families := mini(4, expected_simulated_profiles)
	var minimum_signature_families := mini(3, expected_simulated_profiles)
	var minimum_signature_bonus_profiles := expected_simulated_profiles
	var issues := []
	if ai_count <= 0:
		issues.append("没有AI席位")
	if simulated_profile_count < expected_simulated_profiles:
		issues.append("实战性格覆盖不足:%d/%d" % [simulated_profile_count, expected_simulated_profiles])
	if identity_profile_count < minimum_identity_profiles:
		issues.append("性格身份不足:%d/%d" % [identity_profile_count, minimum_identity_profiles])
	if global_primary_routes.keys().size() < minimum_primary_routes:
		issues.append("主路线种类不足:%d/%d" % [global_primary_routes.keys().size(), minimum_primary_routes])
	if global_expected_families.keys().size() < minimum_expected_families:
		issues.append("预期行动族不足:%d/%d" % [global_expected_families.keys().size(), minimum_expected_families])
	if global_signature_families.keys().size() < minimum_signature_families:
		issues.append("签名行动族不足:%d/%d" % [global_signature_families.keys().size(), minimum_signature_families])
	if global_signature_bonus_profiles.keys().size() < minimum_signature_bonus_profiles:
		issues.append("签名评分命中不足:%d/%d" % [global_signature_bonus_profiles.keys().size(), minimum_signature_bonus_profiles])
	return {
		"ok": issues.is_empty(),
		"issues": issues,
		"ai_count": ai_count,
		"profile_count": AI_PERSONALITY_CATALOG.size(),
		"simulated_profile_count": simulated_profile_count,
		"identity_profile_count": identity_profile_count,
		"missing_identity_profiles": missing_identity_profiles,
		"distinct_primary_route_count": global_primary_routes.keys().size(),
		"expected_family_covered_count": global_expected_families.keys().size(),
		"signature_family_covered_count": global_signature_families.keys().size(),
		"signature_bonus_profile_count": global_signature_bonus_profiles.keys().size(),
		"covered_primary_routes": global_primary_routes.keys(),
		"covered_expected_families": global_expected_families.keys(),
		"covered_signature_families": global_signature_families.keys(),
		"signature_bonus_profiles": global_signature_bonus_profiles.keys(),
		"profiles": entries,
		"expected_simulated_profiles": expected_simulated_profiles,
		"minimum_identity_profiles": minimum_identity_profiles,
		"minimum_primary_routes": minimum_primary_routes,
		"minimum_expected_families": minimum_expected_families,
		"minimum_signature_families": minimum_signature_families,
		"minimum_signature_bonus_profiles": minimum_signature_bonus_profiles,
	}
func _ai_profile_strategy_identity_summary(report: Dictionary = {}) -> String:
	var source := report
	if source.is_empty():
		source = _ai_profile_strategy_identity_report()
	var profile_pieces := []
	for entry_variant in (source.get("profiles", []) as Array):
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if int(entry.get("player_count", 0)) <= 0:
			continue
		profile_pieces.append("%s:%s 路线%d/行动%d/签名%d/加权%d/商品%d" % [
			String(entry.get("profile", "AI")),
			String(entry.get("primary_label", "未定")),
			int(entry.get("primary_route_count", 0)),
			int(entry.get("expected_family_count", 0)),
			int(entry.get("signature_family_count", 0)),
			int(entry.get("signature_bonus_sample_count", 0)),
			int(entry.get("product_sample_count", 0)),
		])
	var issues := source.get("issues", []) as Array
	return "AI性格身份审计：AI%d｜性格%d/%d｜身份%d/%d｜主路线%d｜预期行动族%d｜签名行动族%d｜签名加权%d%s｜%s" % [
		int(source.get("ai_count", 0)),
		int(source.get("simulated_profile_count", 0)),
		int(source.get("expected_simulated_profiles", 0)),
		int(source.get("identity_profile_count", 0)),
		int(source.get("minimum_identity_profiles", 0)),
		int(source.get("distinct_primary_route_count", 0)),
		int(source.get("expected_family_covered_count", 0)),
		int(source.get("signature_family_covered_count", 0)),
		int(source.get("signature_bonus_profile_count", 0)),
		"" if issues.is_empty() else "｜问题:%s" % "、".join(issues),
		"；".join(profile_pieces) if not profile_pieces.is_empty() else "暂无AI性格样本",
	]
func _ai_player_count() -> int:
	var count := 0
	for i in range(players.size()):
		if _player_is_ai(i):
			count += 1
	return count
func _ai_player_indices() -> Array:
	var result := []
	for i in range(players.size()):
		if _player_is_ai(i) and not _player_is_eliminated(i):
			result.append(i)
	return result
func _ai_profile_for_config_index(player_index: int) -> Dictionary:
	if AI_PERSONALITY_CATALOG.is_empty():
		return {}
	var human_count := _configured_human_player_count()
	var ai_order: int = maxi(0, player_index - human_count)
	var profile_index := wrapi(ai_order, 0, AI_PERSONALITY_CATALOG.size())
	var profile := (AI_PERSONALITY_CATALOG[profile_index] as Dictionary).duplicate(true)
	profile["profile_index"] = profile_index
	return profile
func _empty_ai_memory() -> Dictionary:
	return {
		"decision_samples": [],
		"action_counts": {},
		"last_plan": "等待牌局决策",
		"economic_focus_product": "",
		"economic_focus_score": 0,
		"economic_focus_reason": "尚未形成商品焦点",
		"economic_focus_cycle": -1,
		"economic_focus_rankings": [],
		"strategic_intent": "",
		"strategic_intent_score": 0,
		"strategic_intent_reason": "尚未形成多步策略意图",
		"strategic_intent_cycle": -1,
		"strategic_intent_rankings": [],
		"route_plan_product": "",
		"route_plan_stage": "",
		"route_plan_score": 0,
		"route_plan_reason": "尚未形成商品路线计划",
		"route_plan_cycle": -1,
		"route_plan_target_city": -1,
		"route_plan_partner_district": -1,
		"route_plan_rankings": [],
		"game_phase": "opening",
		"competitive_posture": "contesting",
		"score_gap_to_leader": 0,
		"leader_index": -1,
		"phase_reason": "开局：召唤自愿，优先城市发展牌和基础经营牌。",
		"learned_policy_values": {},
		"learning_updates": 0,
		"learning_last_reward": 0,
		"learning_last_tags": [],
		"episode_learning_updates": 0,
		"episode_last_reward": 0,
		"episode_last_top_n_gdp": 0,
		"episode_last_controlled_regions": 0,
		"episode_last_rank": -1,
		"episode_last_result": "",
		"training_note": "记录状态向量、候选评分、Top-N归属GDP、区域控制和公开审计结果，并把版本化胜负结果回写到行动/策略/路线偏好。",
	}
func _ensure_player_ai_state() -> void:
	if players.is_empty():
		return
	configured_player_count = clampi(max(configured_player_count, players.size()), MIN_PLAYER_COUNT, MAX_PLAYER_COUNT)
	_ensure_configured_ai_player_count()
	var human_count: int = maxi(1, players.size() - configured_ai_player_count)
	for i in range(players.size()):
		var player: Dictionary = players[i]
		var seat_type := String(player.get("seat_type", "ai" if i >= human_count else "human"))
		var is_ai := seat_type == "ai" or bool(player.get("is_ai", false))
		if not player.has("last_cycle_income"):
			player["last_cycle_income"] = 0
		if not player.has("last_cashflow_income"):
			player["last_cashflow_income"] = int(player.get("last_cycle_income", 0))
		if not player.has("cashflow_remainder"):
			player["cashflow_remainder"] = 0.0
		if not player.has("total_city_income"):
			player["total_city_income"] = 0
		if not player.has("total_role_income"):
			player["total_role_income"] = 0
		player["seat_type"] = "ai" if is_ai else "human"
		player["is_ai"] = is_ai
		if is_ai:
			if not (player.get("ai_profile", {}) is Dictionary) or (player.get("ai_profile", {}) as Dictionary).is_empty():
				player["ai_profile"] = _ai_profile_for_config_index(i)
			if not (player.get("ai_memory", {}) is Dictionary):
				player["ai_memory"] = _empty_ai_memory()
			else:
				var memory := (player.get("ai_memory", {}) as Dictionary).duplicate(true)
				if not (memory.get("decision_samples", []) is Array):
					memory["decision_samples"] = []
				if not (memory.get("action_counts", {}) is Dictionary):
					memory["action_counts"] = {}
				if String(memory.get("last_plan", "")) == "":
					memory["last_plan"] = "等待牌局决策"
				if String(memory.get("economic_focus_product", "")) == "":
					memory["economic_focus_product"] = ""
				if not memory.has("economic_focus_score"):
					memory["economic_focus_score"] = 0
				if String(memory.get("economic_focus_reason", "")) == "":
					memory["economic_focus_reason"] = "尚未形成商品焦点"
				if not memory.has("economic_focus_cycle"):
					memory["economic_focus_cycle"] = -1
				if not (memory.get("economic_focus_rankings", []) is Array):
					memory["economic_focus_rankings"] = []
				if String(memory.get("strategic_intent", "")) == "":
					memory["strategic_intent"] = ""
				if not memory.has("strategic_intent_score"):
					memory["strategic_intent_score"] = 0
				if String(memory.get("strategic_intent_reason", "")) == "":
					memory["strategic_intent_reason"] = "尚未形成多步策略意图"
				if not memory.has("strategic_intent_cycle"):
					memory["strategic_intent_cycle"] = -1
				if not (memory.get("strategic_intent_rankings", []) is Array):
					memory["strategic_intent_rankings"] = []
				if String(memory.get("route_plan_product", "")) == "":
					memory["route_plan_product"] = ""
				if String(memory.get("route_plan_stage", "")) == "":
					memory["route_plan_stage"] = ""
				if not memory.has("route_plan_score"):
					memory["route_plan_score"] = 0
				if String(memory.get("route_plan_reason", "")) == "":
					memory["route_plan_reason"] = "尚未形成商品路线计划"
				if not memory.has("route_plan_cycle"):
					memory["route_plan_cycle"] = -1
				if not memory.has("route_plan_target_city"):
					memory["route_plan_target_city"] = -1
				if not memory.has("route_plan_partner_district"):
					memory["route_plan_partner_district"] = -1
				if not (memory.get("route_plan_rankings", []) is Array):
					memory["route_plan_rankings"] = []
				if String(memory.get("game_phase", "")) == "":
					memory["game_phase"] = "opening"
				if String(memory.get("competitive_posture", "")) == "":
					memory["competitive_posture"] = "contesting"
				if not memory.has("score_gap_to_leader"):
					memory["score_gap_to_leader"] = 0
				if not memory.has("leader_index"):
					memory["leader_index"] = -1
				if String(memory.get("phase_reason", "")) == "":
					memory["phase_reason"] = "开局：召唤自愿，优先城市发展牌和基础经营牌。"
				if not (memory.get("learned_policy_values", {}) is Dictionary):
					memory["learned_policy_values"] = {}
				if not memory.has("learning_updates"):
					memory["learning_updates"] = 0
				if not memory.has("learning_last_reward"):
					memory["learning_last_reward"] = 0
				if not (memory.get("learning_last_tags", []) is Array):
					memory["learning_last_tags"] = []
				if not memory.has("episode_learning_updates"):
					memory["episode_learning_updates"] = 0
				if not memory.has("episode_last_reward"):
					memory["episode_last_reward"] = 0
				if not memory.has("episode_last_top_n_gdp"):
					memory["episode_last_top_n_gdp"] = 0
				if not memory.has("episode_last_controlled_regions"):
					memory["episode_last_controlled_regions"] = 0
				if not memory.has("episode_last_rank"):
					memory["episode_last_rank"] = -1
				if not memory.has("episode_last_result"):
					memory["episode_last_result"] = ""
				if String(memory.get("training_note", "")) == "":
					memory["training_note"] = "记录状态向量、候选评分、Top-N归属GDP、区域控制和公开审计结果，并把版本化胜负结果回写到行动/策略/路线偏好。"
				player["ai_memory"] = memory
		else:
			player["ai_profile"] = {}
			player["ai_memory"] = {}
		players[i] = player
func _ai_owned_active_monster_count(player_index: int) -> int:
	var count := 0
	for actor_variant in auto_monsters:
		var actor: Dictionary = actor_variant
		if not bool(actor.get("down", false)) and int(actor.get("owner", -1)) == player_index:
			count += 1
	return count
func _ai_score_gap_to_leader(player_index: int) -> int:
	var leader := _visible_score_leader_entry(player_index)
	if int(leader.get("player_index", -1)) < 0:
		return 0
	return _victory_top_n_gdp(player_index) - int(leader.get("score", 0))
func _ai_game_phase(player_index: int) -> String:
	var score := _victory_top_n_gdp(player_index)
	var gdp_goal := _victory_required_gdp()
	if victory_control_active or score >= int(round(float(gdp_goal) * AI_ENDGAME_GOAL_RATIO)) or business_cycle_count >= AI_ENDGAME_CYCLE:
		return "endgame"
	if business_cycle_count <= AI_OPENING_CYCLE_MAX or _ai_owned_active_monster_count(player_index) <= 0 or _player_active_city_count(player_index) <= 0:
		return "opening"
	return "midgame"
func _ai_competitive_posture(player_index: int) -> String:
	var leader := _visible_score_leader_entry(player_index)
	var leader_index := int(leader.get("player_index", -1))
	var gap := _ai_score_gap_to_leader(player_index)
	if leader_index == player_index and abs(gap) <= AI_LEAD_MARGIN:
		return "leader"
	if leader_index == player_index:
		return "leader"
	if gap <= -maxi(1, int(round(float(_victory_required_gdp()) * 0.15))):
		return "trailing"
	return "contesting"
func _ai_endgame_urgency_score(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	var score := 0
	var own_gdp := _victory_top_n_gdp(player_index)
	var gdp_goal := _victory_required_gdp()
	var gdp_gap := maxi(0, gdp_goal - own_gdp)
	var region_gap := maxi(0, _victory_required_regions() - _victory_controlled_regions(player_index))
	var leader_gap := _ai_score_gap_to_leader(player_index)
	if gdp_gap > 0:
		score += mini(95, int(round(float(gdp_gap) * 95.0 / float(gdp_goal))))
	score += region_gap * 35
	if leader_gap < 0:
		score += mini(115, int(round(float(abs(leader_gap)) * 115.0 / float(gdp_goal))))
	if victory_control_active:
		var elapsed_ratio := clampf(1.0 - (victory_control_remaining_seconds / _victory_timer_total_seconds()), 0.0, 1.0)
		score += 55 + int(round(elapsed_ratio * 120.0))
		if victory_control_remaining_seconds <= 20.0:
			score += 45
	return clampi(score, 0, 260)
func _ai_game_phase_reason(_player_index: int, phase: String, posture: String, gap: int) -> String:
	match phase:
		"opening":
			return "开局：召唤自愿；通过发展牌建立商品项目，再买基础经营牌。"
		"endgame":
			return "后期：%s，Top-N GDP距离领先者%s；围绕区域控制和公开审计冲刺、防守或压制。" % [
				_ai_competitive_posture_label(posture),
				_signed_int_text(gap),
			]
	return "中局：围绕商品路线强化GDP，并开始保护己方收益或攻击竞争城市。"
func _ai_refresh_game_phase(player_index: int, force: bool = false) -> Dictionary:
	if player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return {
			"phase": "human",
			"posture": "human",
			"gap": 0,
			"leader_index": -1,
			"reason": "真人玩家",
		}
	var player: Dictionary = players[player_index]
	var memory := (player.get("ai_memory", _empty_ai_memory()) as Dictionary).duplicate(true)
	var leader := _visible_score_leader_entry(player_index)
	var leader_index := int(leader.get("player_index", -1))
	var gap := _ai_score_gap_to_leader(player_index)
	var phase := _ai_game_phase(player_index)
	var posture := _ai_competitive_posture(player_index)
	if not force and String(memory.get("game_phase", "")) == phase and String(memory.get("competitive_posture", "")) == posture and int(memory.get("score_gap_to_leader", 0)) == gap and int(memory.get("leader_index", -1)) == leader_index:
		return {
			"phase": phase,
			"posture": posture,
			"gap": gap,
			"leader_index": leader_index,
			"reason": String(memory.get("phase_reason", "")),
		}
	var reason := _ai_game_phase_reason(player_index, phase, posture, gap)
	memory["game_phase"] = phase
	memory["competitive_posture"] = posture
	memory["score_gap_to_leader"] = gap
	memory["leader_index"] = leader_index
	memory["phase_reason"] = reason
	player["ai_memory"] = memory
	players[player_index] = player
	return {
		"phase": phase,
		"posture": posture,
		"gap": gap,
		"leader_index": leader_index,
		"reason": reason,
	}
func _ai_game_phase_label(phase: String) -> String:
	match phase:
		"opening":
			return "开局"
		"midgame":
			return "中局"
		"endgame":
			return "后期"
	return "未知阶段"
func _ai_competitive_posture_label(posture: String) -> String:
	match posture:
		"leader":
			return "领先"
		"trailing":
			return "落后"
		"contesting":
			return "争夺中"
	return "未知态势"
func _ai_best_city_for_owner(owner_index: int, prefer_damaged: bool = false) -> int:
	var best_index := -1
	var best_score := -999999
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		if int(city.get("owner", -1)) != owner_index:
			continue
		var score := int(city.get("last_income", 0)) + _city_cycle_income(city_index, _city_competition_matches(city_index))
		score += (city.get("products", []) as Array).size() * 28
		score += (city.get("demands", []) as Array).size() * 18
		score -= int(city.get("trade_route_damage", 0)) * 22
		score -= int(districts[city_index].get("damage", 0)) * 14
		score += _city_warehouse_stockpile_pressure(city) * 2
		if prefer_damaged:
			score += int(city.get("trade_route_damage", 0)) * 74 + int(districts[city_index].get("damage", 0)) * 36
		if score > best_score:
			best_score = score
			best_index = city_index
	return best_index
func _ai_best_pressure_target_city(player_index: int) -> int:
	var leader := _visible_score_leader_entry(player_index)
	var leader_index := int(leader.get("player_index", -1))
	if leader_index >= 0 and leader_index != player_index:
		var leader_city := _ai_best_city_for_owner(leader_index, _ai_competitive_posture(player_index) == "trailing")
		if leader_city >= 0:
			return leader_city
	return _ai_best_city_district(player_index, false)
func _ai_direct_interaction_target_player(player_index: int) -> int:
	var plan := _ai_direct_player_interaction_plan(player_index, {})
	return int(plan.get("target_player", -1))
func _ai_public_card_owner_signal_for_player(viewer_index: int, target_player: int) -> int:
	if viewer_index < 0 or viewer_index >= players.size() or target_player < 0 or target_player >= players.size():
		return 0
	var score := 0
	var scanned := 0
	for i in range(resolved_card_history.size() - 1, -1, -1):
		var entry_variant: Variant = resolved_card_history[i]
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var known_owner := int(entry.get("player_index", -1)) if bool(entry.get("public_owner_revealed", false)) else _private_known_card_owner_for_entry(viewer_index, entry)
		if known_owner != target_player:
			continue
		var skill: Dictionary = entry.get("skill", {}) as Dictionary
		var card_name := String(skill.get("name", entry.get("card_name", "")))
		var kind := String(skill.get("kind", ""))
		score += 18 + mini(95, int(float(_card_strength_budget_points(card_name)) / 3.0))
		if _ai_pressure_kind(kind, skill):
			score += 26
		if _ai_defense_kind(kind, skill):
			score += 18
		scanned += 1
		if scanned >= 5:
			break
	return score
func _ai_direct_player_interaction_plan(player_index: int, skill: Dictionary) -> Dictionary:
	if player_index < 0 or player_index >= players.size() or players.size() <= 1:
		return {}
	var kind := String(skill.get("kind", "player_hand_disrupt"))
	var phase_info := _ai_refresh_game_phase(player_index)
	var leader_index := int(phase_info.get("leader_index", -1))
	var posture := String(phase_info.get("posture", "contesting"))
	var self_estimate := _victory_top_n_gdp(player_index)
	var hand_effect_pressure := int(skill.get("hand_discard_count", 0)) * 118 \
		+ int(skill.get("hand_steal_count", 0)) * 154 \
		+ int(round(float(skill.get("hand_lock_seconds", 0.0)) * 4.0)) \
		+ int(float(int(skill.get("target_cash_penalty", 0))) / 2.0)
	if hand_effect_pressure <= 0:
		hand_effect_pressure = 75
	var receive_pressure := 0
	if kind == "player_hand_steal":
		var actor: Dictionary = players[player_index]
		if _player_counted_hand_size(actor) < PLAYER_HAND_LIMIT:
			receive_pressure += 46
		else:
			receive_pressure += int(float(maxi(0, int(skill.get("steal_fail_cash", 0)))) / 3.0) - 32
	var best := {}
	var best_score := -999999
	for i in range(players.size()):
		if i == player_index:
			continue
		var settlement := _victory_top_n_gdp(i)
		var settlement_gap := settlement - self_estimate
		var city_pressure := _player_active_city_count(i) * 74
		var monster_pressure := _ai_owned_active_monster_count(i) * 42
		var public_signal := _ai_public_card_owner_signal_for_player(player_index, i)
		var leader_bonus := 0
		if i == leader_index:
			leader_bonus = 245 + int(float(_ai_endgame_urgency_score(player_index)) / 2.0)
		var posture_bonus := 0
		if posture == "trailing":
			posture_bonus = 92 + int(float(maxi(0, settlement_gap)) / 12.0)
		elif posture == "leader":
			posture_bonus = 38
		var score := 90 \
			+ int(float(settlement) / 24.0) \
			+ int(float(maxi(0, settlement_gap)) / 10.0) \
			+ city_pressure \
			+ monster_pressure \
			+ public_signal \
			+ leader_bonus \
			+ posture_bonus \
			+ hand_effect_pressure \
			+ receive_pressure
		score += (i * 13 + player_index * 7 + business_cycle_count) % 17
		var role := "pressure_high_value_player"
		if i == leader_index:
			role = "pressure_leader_hand"
		elif public_signal >= 80:
			role = "pressure_revealed_operator"
		elif city_pressure >= 140:
			role = "pressure_city_operator"
		elif monster_pressure >= 84:
			role = "pressure_monster_operator"
		if score > best_score:
			best_score = score
			best = {
				"policy_kind": "direct_%s" % kind,
				"target_player": i,
				"target_owner": i,
				"direct_interaction_role": role,
				"direct_interaction_score": score,
				"direct_target_settlement": settlement,
				"direct_target_gap": settlement_gap,
				"direct_target_city_pressure": city_pressure,
				"direct_target_monster_pressure": monster_pressure,
				"direct_target_public_card_signal": public_signal,
				"direct_effect_pressure": hand_effect_pressure,
				"score": score,
				"reason": "直接互动%s｜%s｜估值差%d｜公开牌线索%d｜效果压强%d" % [
					_interaction_target_label(i),
					role,
					settlement_gap,
					public_signal,
					hand_effect_pressure,
				],
			}
	return best
func _ai_direct_city_target_score(player_index: int, district_index: int, skill: Dictionary) -> int:
	if district_index < 0 or district_index >= districts.size():
		return -999999
	var city := _district_city(district_index)
	if not _city_is_active(city):
		return -999999
	var city_owner := int(city.get("owner", -1))
	if city_owner == player_index:
		return -999999
	var kind := String(skill.get("kind", "city_control_dispute"))
	var phase_info := _ai_refresh_game_phase(player_index)
	var leader_index := int(phase_info.get("leader_index", -1))
	var income := int(city.get("last_income", _city_cycle_income(district_index, _city_competition_matches(district_index))))
	var route_load := (city.get("trade_routes", []) as Array).size()
	var warehouse_pressure := _city_warehouse_stockpile_pressure(city)
	var route_damage := int(city.get("trade_route_damage", 0)) + int(city.get("trade_disrupted_routes", 0))
	var district_damage := int(districts[district_index].get("damage", 0))
	var score := 80 + maxi(0, _ai_city_target_score(player_index, district_index, false, false))
	score += int(float(income) / 2.0) + route_load * 22 + warehouse_pressure * 2
	if city_owner == leader_index and leader_index != player_index:
		score += 155 + int(float(_ai_endgame_urgency_score(player_index)) / 2.0)
	if kind == "city_control_dispute":
		score += int(skill.get("control_gdp_penalty", 0)) * 3 + int(round(float(skill.get("control_block_seconds", 0.0)) / 2.0))
		score += int(float(maxi(0, income)) / 3.0)
	elif kind == "global_barrage":
		score += maxi(1, int(skill.get("global_barrage_target_count", 1))) * 18
		score += maxi(0, int(skill.get("global_barrage_damage", 0))) * 82
		score += maxi(0, int(skill.get("global_barrage_route_damage", 0))) * 64
		score += maxi(0, 5 - district_damage) * 12
	if route_damage > 0:
		score += route_damage * (34 if kind == "global_barrage" else 18)
	return score
func _ai_direct_city_interaction_plan(player_index: int, skill: Dictionary) -> Dictionary:
	if player_index < 0 or player_index >= players.size():
		return {}
	var kind := String(skill.get("kind", "city_control_dispute"))
	var best_city := -1
	var best_score := -999999
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var score := _ai_direct_city_target_score(player_index, city_index, skill)
		if score > best_score:
			best_score = score
			best_city = city_index
	if best_city < 0:
		return {}
	var city := _district_city(best_city)
	var city_owner := int(city.get("owner", -1))
	var warehouse_pressure := _city_warehouse_stockpile_pressure(city)
	var route_damage := int(city.get("trade_route_damage", 0)) + int(city.get("trade_disrupted_routes", 0))
	var district_damage := int(districts[best_city].get("damage", 0))
	var expected_damage := 0
	var role := "freeze_rival_city"
	if kind == "global_barrage":
		expected_damage = maxi(1, int(skill.get("global_barrage_target_count", 1))) * maxi(1, int(skill.get("global_barrage_damage", 1)))
		role = "barrage_rival_cluster"
		if warehouse_pressure > 0:
			role = "barrage_warehouse_cluster"
	elif warehouse_pressure > 0:
		role = "freeze_warehouse_city"
	var leader_index := int(_ai_refresh_game_phase(player_index).get("leader_index", -1))
	if city_owner == leader_index and leader_index != player_index:
		role = "%s_leader" % role
	return {
		"policy_kind": "direct_%s" % kind,
		"district": best_city,
		"target_city": best_city,
		"target_owner": city_owner,
		"direct_interaction_role": role,
		"direct_interaction_score": best_score,
		"direct_city_pressure": best_score,
		"direct_city_gdp": int(city.get("last_income", 0)),
		"direct_city_warehouse_pressure": warehouse_pressure,
		"direct_city_route_damage": route_damage,
		"direct_city_damage": district_damage,
		"direct_barrage_target_count": maxi(1, int(skill.get("global_barrage_target_count", 1))) if kind == "global_barrage" else 0,
		"direct_barrage_expected_damage": expected_damage,
		"score": best_score,
		"reason": "直接城市互动｜%s｜%s｜GDP/min%d｜仓储压强%d｜商路损伤%d" % [
			role,
			String(districts[best_city].get("name", "城市")),
			int(city.get("last_income", 0)),
			warehouse_pressure,
			route_damage,
		],
	}
func _ai_pressure_kind(kind: String, skill: Dictionary = {}) -> bool:
	if ["route_sabotage", "panic_shift", "news_event", "monster_lure", "mudslide", "area_damage", "special_monster_delay", "player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage"].has(kind):
		return true
	if kind == "weather_control":
		return _ai_weather_definition_has_risk(String(skill.get("weather_type", "")))
	if kind == "city_gdp_derivative":
		var terms := _city_gdp_derivative_terms(skill)
		return String(terms.get("direction", "up")) == "down" and not bool(terms.get("insurance", false))
	if kind == "region_economy_shift":
		return int(skill.get("production_delta", 0)) + int(skill.get("transport_delta", 0)) + int(skill.get("consumption_delta", 0)) < 0
	return false
func _ai_defense_kind(kind: String, skill: Dictionary = {}) -> bool:
	if ["route_insurance", "route_flow_boon", "city_revenue_boost", "city_contract_boon", "city_product_upgrade", "city_demand_shift", "market_stabilize"].has(kind):
		return true
	if kind == "weather_control":
		return _ai_weather_definition_has_opportunity(String(skill.get("weather_type", "")))
	if kind == "city_gdp_derivative":
		var terms := _city_gdp_derivative_terms(skill)
		return String(terms.get("direction", "up")) == "up" or bool(terms.get("insurance", false))
	if kind == "region_economy_shift":
		return int(skill.get("production_delta", 0)) + int(skill.get("transport_delta", 0)) + int(skill.get("consumption_delta", 0)) > 0
	return false


func _ai_weather_definition_has_risk(type_id: String) -> bool:
	var definition := _weather_template(type_id)
	if definition.is_empty():
		return false
	for key in ["route_efficiency_multiplier", "land_movement_multiplier", "ocean_movement_multiplier", "air_movement_multiplier", "ranged_effect_multiplier", "intel_effect_multiplier"]:
		if float(definition.get(key, 1.0)) < 0.999:
			return true
	if float(definition.get("region_damage_per_second", 0.0)) > 0.0 or float(definition.get("flying_risk_multiplier", 1.0)) > 1.001 or float(definition.get("city_maintenance_multiplier", 1.0)) > 1.001:
		return true
	for effect_variant in (definition.get("product_effects", {}) as Dictionary).values():
		if effect_variant is Dictionary:
			var effect := effect_variant as Dictionary
			if float(effect.get("production_multiplier", 1.0)) < 0.999 or float(effect.get("demand_multiplier", 1.0)) < 0.999 or float(effect.get("price_growth_multiplier", 1.0)) < 0.999:
				return true
	return false


func _ai_weather_definition_has_opportunity(type_id: String) -> bool:
	var definition := _weather_template(type_id)
	if definition.is_empty():
		return false
	for key in ["product_price_growth_multiplier", "production_multiplier", "demand_multiplier", "route_efficiency_multiplier", "land_movement_multiplier", "ocean_movement_multiplier", "air_movement_multiplier", "ranged_effect_multiplier", "knockback_multiplier", "orbital_effect_multiplier", "monster_preference_multiplier", "monster_speed_multiplier", "monster_armor_multiplier"]:
		if float(definition.get(key, 1.0)) > 1.001:
			return true
	for effect_variant in (definition.get("product_effects", {}) as Dictionary).values():
		if effect_variant is Dictionary:
			var effect := effect_variant as Dictionary
			if float(effect.get("production_multiplier", 1.0)) > 1.001 or float(effect.get("demand_multiplier", 1.0)) > 1.001 or float(effect.get("price_growth_multiplier", 1.0)) > 1.001:
				return true
	return false


func _ai_phase_bonus_for_candidate(player_index: int, kind: String, _district_index: int, product_name: String = "", target_owner: int = -999, skill: Dictionary = {}) -> int:
	var phase_info := _ai_refresh_game_phase(player_index)
	var phase := String(phase_info.get("phase", "midgame"))
	var posture := String(phase_info.get("posture", "contesting"))
	var leader_index := int(phase_info.get("leader_index", -1))
	var helpful_target := target_owner == player_index
	var harmful_target := target_owner >= 0 and target_owner != player_index
	var targets_leader := leader_index >= 0 and target_owner == leader_index and leader_index != player_index
	var endgame_urgency := _ai_endgame_urgency_score(player_index)
	var urgency_half := int(round(float(endgame_urgency) / 2.0))
	var urgency_third := int(round(float(endgame_urgency) / 3.0))
	var urgency_fifth := int(round(float(endgame_urgency) / 5.0))
	var bonus := 0
	match phase:
		"opening":
			if kind == "monster_card":
				bonus += 420 if _ai_owned_active_monster_count(player_index) <= 0 else 40
			if kind == "city_build":
				bonus += 150 if _player_active_city_count(player_index) <= 0 else 55
			if ["cash_gain", "supply_draw"].has(kind):
				bonus += 60
			if _ai_pressure_kind(kind, skill):
				bonus -= 35
		"midgame":
			if _ai_defense_kind(kind, skill) and helpful_target:
				bonus += 55
			if _ai_pressure_kind(kind, skill) and harmful_target:
				bonus += 65
			if product_name != "" and (product_name == _ai_focus_product(player_index) or product_name == _ai_route_plan_product(player_index)):
				bonus += 38
		"endgame":
			if posture == "leader":
				if _ai_defense_kind(kind, skill) and (helpful_target or target_owner == -999):
					bonus += 145 + endgame_urgency
				if ["cash_gain", "market_stabilize"].has(kind):
					bonus += 90 + urgency_half
				if _ai_pressure_kind(kind, skill) and harmful_target:
					bonus += 35 + urgency_fifth
			elif posture == "trailing":
				if _ai_pressure_kind(kind, skill) and (targets_leader or harmful_target):
					bonus += 170 + endgame_urgency
				if kind == "city_gdp_derivative" and String(_city_gdp_derivative_terms(skill).get("direction", "up")) == "down":
					bonus += 95 + urgency_half
				if ["cash_gain", "product_speculation"].has(kind):
					bonus += 70 + urgency_third
			else:
				if _ai_defense_kind(kind, skill) and helpful_target:
					bonus += 80 + urgency_half
				if _ai_pressure_kind(kind, skill) and (targets_leader or harmful_target):
					bonus += 90 + urgency_half
	return bonus
func _ai_victory_race_bonus_for_candidate(player_index: int, kind: String, district_index: int, product_name: String = "", target_owner: int = -999, skill: Dictionary = {}) -> Dictionary:
	var result := {
		"bonus": 0,
		"role": "",
		"reason": "",
	}
	if player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return result
	var phase_info := _ai_refresh_game_phase(player_index)
	var phase := String(phase_info.get("phase", "midgame"))
	var posture := String(phase_info.get("posture", "contesting"))
	var leader_index := int(phase_info.get("leader_index", -1))
	var leader_score := int(_visible_score_leader_entry(player_index).get("score", 0))
	var own_score := _victory_top_n_gdp(player_index)
	var gdp_goal := _victory_required_gdp()
	var gdp_gap := gdp_goal - own_score
	var leader_goal_gap := gdp_goal - leader_score
	var urgency := _ai_endgame_urgency_score(player_index)
	var is_endgame_pressure: bool = phase == "endgame" or bool(victory_control_active) or own_score >= int(round(float(gdp_goal) * 0.82)) or leader_score >= int(round(float(gdp_goal) * 0.86))
	if not is_endgame_pressure:
		return result
	var resolved_owner := target_owner
	if resolved_owner == -999 and district_index >= 0 and district_index < districts.size():
		var city := _district_city(district_index)
		if _city_is_active(city):
			resolved_owner = int(city.get("owner", -1))
	var helpful_target := resolved_owner == player_index
	var harmful_target := resolved_owner >= 0 and resolved_owner != player_index
	var targets_leader := leader_index >= 0 and leader_index != player_index and resolved_owner == leader_index
	var route_id := _ai_development_route_for_kind(kind, skill)
	var product_match := product_name != "" and (product_name == _ai_focus_product(player_index) or product_name == _ai_route_plan_product(player_index))
	var pressure := _ai_pressure_kind(kind, skill)
	var defense := _ai_defense_kind(kind, skill)
	var bonus := 0
	var role := "race_to_audit"
	var reasons := []
	if victory_control_active and leader_index >= 0 and leader_index != player_index:
		role = "break_audit_lead"
		if pressure and (targets_leader or harmful_target):
			bonus += 160 + urgency
			reasons.append("阻断审计领先+%d" % (160 + urgency))
		if kind == "city_gdp_derivative" and String(_city_gdp_derivative_terms(skill).get("direction", "")) == "down":
			bonus += 95 + int(round(float(urgency) / 2.0))
			reasons.append("做空领先GDP")
		if route_id == "finance_speculation":
			bonus += 46
			reasons.append("终局金融反扑")
	elif posture == "leader" or gdp_gap <= 0 or own_score >= int(round(float(gdp_goal) * 0.9)):
		role = "protect_lead"
		if defense and (helpful_target or resolved_owner == -999):
			bonus += 125 + int(round(float(urgency) / 2.0))
			reasons.append("保护领先+%d" % (125 + int(round(float(urgency) / 2.0))))
		if ["cash_gain", "market_stabilize"].has(kind):
			bonus += 70
			reasons.append("锁定现金")
		if route_id == "city_growth" and helpful_target:
			bonus += 38
			reasons.append("稳住GDP")
		if pressure and harmful_target:
			bonus += 28
			reasons.append("低风险牵制")
	elif posture == "trailing" or gdp_gap > 0 and leader_goal_gap <= 0:
		role = "last_push"
		if pressure and (targets_leader or harmful_target):
			bonus += 115 + urgency
			reasons.append("追分压制+%d" % (115 + urgency))
		if route_id == "finance_speculation":
			bonus += 70 + int(round(float(urgency) / 3.0))
			reasons.append("高杠杆追分")
		if ["cash_gain", "product_speculation"].has(kind):
			bonus += 54
			reasons.append("补审计末级现金比较")
	else:
		role = "race_to_audit"
		if defense and helpful_target:
			bonus += 58 + int(round(float(urgency) / 3.0))
			reasons.append("护住收益")
		if pressure and (targets_leader or harmful_target):
			bonus += 70 + int(round(float(urgency) / 3.0))
			reasons.append("压制领先线")
		if route_id == "city_growth" and helpful_target:
			bonus += 44
			reasons.append("冲刺GDP")
	if product_match:
		bonus += 18
		reasons.append("商品路线吻合")
	result["bonus"] = clampi(bonus, 0, 260)
	result["role"] = role
	result["reason"] = "、".join(reasons) if not reasons.is_empty() else "审计竞速观察"
	return result
func _ai_observation_vector(player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= players.size():
		return {}
	var focus_product := _ai_focus_product(player_index)
	var phase_info := _ai_refresh_game_phase(player_index)
	var player: Dictionary = players[player_index]
	var memory := (player.get("ai_memory", _empty_ai_memory()) as Dictionary)
	var total_flow := 0
	for product_variant in PRODUCT_CATALOG:
		total_flow += _player_product_flow(player_index, String(product_variant))
	return {
		"cash": int(player.get("cash", 0)),
		"victory_top_n_gdp_per_minute": _victory_top_n_gdp(player_index),
		"victory_controlled_region_count": _victory_controlled_regions(player_index),
		"counted_hand": _player_counted_hand_size(player),
		"cities": _player_active_city_count(player_index),
		"owned_monsters": _ai_owned_active_monster_count(player_index),
		"field_monsters": _active_auto_monster_count(),
		"total_product_flow": total_flow,
		"focus_product": focus_product,
		"focus_flow": _player_product_flow(player_index, focus_product),
		"focus_score": _ai_focus_score(player_index),
		"strategy_intent": _ai_strategy_intent(player_index),
		"strategy_score": _ai_strategy_score(player_index),
		"route_plan_product": _ai_route_plan_product(player_index),
		"route_plan_stage": _ai_route_plan_stage(player_index),
		"route_plan_score": _ai_route_plan_score(player_index),
		"game_phase": String(phase_info.get("phase", "midgame")),
		"competitive_posture": String(phase_info.get("posture", "contesting")),
		"score_gap_to_leader": int(phase_info.get("gap", 0)),
		"leader_index": int(phase_info.get("leader_index", -1)),
		"endgame_urgency": _ai_endgame_urgency_score(player_index),
		"learning_updates": int(memory.get("learning_updates", 0)),
		"episode_learning_updates": int(memory.get("episode_learning_updates", 0)),
		"learned_policy_count": (memory.get("learned_policy_values", {}) as Dictionary).size(),
		"victory_gdp_gap": maxi(0, _victory_required_gdp() - _victory_top_n_gdp(player_index)),
		"victory_region_gap": maxi(0, _victory_required_regions() - _victory_controlled_regions(player_index)),
		"queue_current": _card_resolution_current_queue().size(),
		"queue_next": _card_resolution_next_queue().size(),
		"auction_open": card_resolution_auction_open,
		"cycle": business_cycle_count,
	}
func _ai_candidate_training_view(candidate: Dictionary) -> Dictionary:
	var result := {}
	for field_name in _ai_training_metadata_field_names():
		if candidate.has(field_name):
			result[field_name] = candidate[field_name]
	return result
func _ai_training_metadata_field_names() -> Array:
	return ["action", "card_name", "kind", "policy_kind", "score", "district", "target_slot", "target_player", "target_city", "target_owner", "product", "price", "reason", "guessed_player", "resolution_id", "stake", "stake_percent", "confidence", "reason_key", "attack_value", "resource_match", "product_overlap", "distance_m", "strategic_role", "focus_product", "focus_score", "focus_bonus", "strategy_intent", "strategy_score", "strategy_bonus", "route_plan_product", "route_plan_stage", "route_plan_score", "route_plan_bonus", "route_gap_bonus", "route_gap_penalty", "route_gap_reason", "route_gap_field_match", "development_route", "development_route_label", "development_route_bias", "development_route_bonus", "route_inventory_bonus", "route_inventory_penalty", "route_hand_total", "route_hand_playable", "route_hand_blocked", "futures_direction", "futures_signal", "futures_market_score", "futures_stockpile_score", "futures_stockpile_units", "futures_duration_seconds", "futures_multiplier_x100", "futures_margin_cash", "futures_maximum_gain", "futures_maximum_loss", "futures_risk_adjusted_ev", "futures_warehouse_city", "futures_warehouse_required", "futures_product_flow", "futures_play_district", "futures_reason", "military_command", "military_command_role", "military_command_score", "military_command_distance_m", "military_unit_uid", "military_unit_type", "military_deploy_role", "military_deploy_score", "military_deploy_terrain", "military_deploy_route_load", "military_deploy_monster_risk", "military_deploy_district", "counter_target_resolution_id", "counter_target_card", "counter_strength", "counter_threat_score", "counter_opportunity_cost", "counter_reason_key", "counter_source_card", "counter_converted_monster", "counter_card_name", "weather_type", "weather_plan_role", "weather_plan_score", "weather_zone_count", "weather_target_terrain", "weather_covered_cities", "weather_route_load", "weather_own_value", "weather_rival_value", "weather_neutral_value", "weather_product_bonus", "weather_terrain_bonus", "direct_interaction_role", "direct_interaction_score", "direct_target_settlement", "direct_target_gap", "direct_target_city_pressure", "direct_target_monster_pressure", "direct_target_public_card_signal", "direct_effect_pressure", "direct_city_pressure", "direct_city_gdp", "direct_city_warehouse_pressure", "direct_city_route_damage", "direct_city_damage", "direct_barrage_target_count", "direct_barrage_expected_damage", "ai_wager_score", "ai_wager_confidence", "ai_wager_reason_key", "ai_wager_owner_bias", "ai_wager_city_bias", "ai_wager_expected_damage", "ai_wager_stake_percent", "game_phase", "competitive_posture", "score_gap_to_leader", "leader_index", "endgame_urgency", "phase_bonus", "victory_race_bonus", "victory_race_role", "victory_race_reason", "generic_effect_bonus", "profile_signature_bonus", "profile_signature_family", "profile_signature_route", "profile_signature_reason", "learning_bonus", "playability_bonus", "hand_pressure_penalty", "requires_discard", "discard_keep_value", "counted_hand", "play_requirement_kind", "play_requirement_scope", "required_share_percent", "current_share_percent", "qualifying_district", "requirement_satisfied"]
func _ai_candidate_training_views(candidates: Array) -> Array:
	var ordered := candidates.duplicate(true)
	ordered.sort_custom(Callable(self, "_sort_ai_candidate_score_desc"))
	var result := []
	for i in range(mini(AI_CANDIDATE_SAMPLE_LIMIT, ordered.size())):
		if ordered[i] is Dictionary:
			result.append(_ai_candidate_training_view(ordered[i] as Dictionary))
	return result


# --- Test-only Agent policy / hidden-information audit helpers ---
func _ai_audit_score_component_fields() -> Array:
	return [
		"focus_bonus",
		"strategy_bonus",
		"route_plan_bonus",
		"route_gap_bonus",
		"development_route_bonus",
		"phase_bonus",
		"victory_race_bonus",
		"generic_effect_bonus",
		"profile_signature_bonus",
		"learning_bonus",
		"playability_bonus",
		"military_deploy_score",
		"military_command_score",
		"weather_plan_score",
		"direct_interaction_score",
		"counter_threat_score",
		"counter_opportunity_cost",
		"futures_signal",
		"futures_market_score",
		"futures_stockpile_score",
		"ai_wager_score",
		"ai_wager_confidence",
		"ai_wager_owner_bias",
		"ai_wager_city_bias",
	]
func _ai_candidate_has_score_components(candidate: Dictionary) -> bool:
	for field_variant in _ai_audit_score_component_fields():
		if candidate.has(String(field_variant)):
			return true
	return false
func _ai_candidate_empty_field_notes(group_name: String, candidate_index: int, candidate: Dictionary) -> Array:
	var result := []
	for field_variant in ["action", "card_name", "kind", "policy_kind"]:
		var field_name := String(field_variant)
		if candidate.has(field_name) and String(candidate.get(field_name, "")) == "":
			result.append("%s[%d].%s" % [group_name, candidate_index, field_name])
	return result
func _ai_candidate_negative_anomaly_notes(group_name: String, candidate_index: int, candidate: Dictionary) -> Array:
	var result := []
	for field_variant in ["score", "price", "stake", "stake_percent", "confidence"]:
		var field_name := String(field_variant)
		if candidate.has(field_name) and int(candidate.get(field_name, 0)) < 0:
			result.append("%s[%d].%s=%d" % [group_name, candidate_index, field_name, int(candidate.get(field_name, 0))])
	return result
func _ai_policy_candidate_group_audit(group_name: String, candidates: Array) -> Dictionary:
	var policy_kinds := {}
	var samples := []
	var missing_policy_kind := []
	var missing_training_metadata := []
	var missing_score_components := []
	var empty_fields := []
	var negative_anomalies := []
	var score_field_count := 0
	var score_component_count := 0
	for i in range(candidates.size()):
		if not (candidates[i] is Dictionary):
			empty_fields.append("%s[%d]:not_dictionary" % [group_name, i])
			continue
		var candidate: Dictionary = candidates[i]
		var policy_kind := String(candidate.get("policy_kind", ""))
		if policy_kind == "":
			missing_policy_kind.append("%s[%d]" % [group_name, i])
		else:
			policy_kinds[policy_kind] = int(policy_kinds.get(policy_kind, 0)) + 1
		if candidate.has("score"):
			score_field_count += 1
		if _ai_candidate_has_score_components(candidate):
			score_component_count += 1
		else:
			missing_score_components.append("%s[%d]" % [group_name, i])
		var training_view := _ai_candidate_training_view(candidate)
		if not training_view.has("policy_kind") or not training_view.has("score"):
			missing_training_metadata.append("%s[%d]" % [group_name, i])
		empty_fields.append_array(_ai_candidate_empty_field_notes(group_name, i, candidate))
		negative_anomalies.append_array(_ai_candidate_negative_anomaly_notes(group_name, i, candidate))
		if samples.size() < AI_CANDIDATE_SAMPLE_LIMIT:
			samples.append(training_view)
	return {
		"group": group_name,
		"count": candidates.size(),
		"has_candidates": not candidates.is_empty(),
		"policy_kinds": policy_kinds,
		"policy_kind_count": policy_kinds.size(),
		"score_field_count": score_field_count,
		"score_component_count": score_component_count,
		"training_metadata_count": candidates.size() - missing_training_metadata.size(),
		"missing_policy_kind": missing_policy_kind,
		"missing_training_metadata": missing_training_metadata,
		"missing_score_components": missing_score_components,
		"empty_fields": empty_fields,
		"negative_anomalies": negative_anomalies,
		"samples": samples,
	}
func _ai_contract_policy_candidates_for_audit(player_index: int) -> Array:
	var result := []
	if not _player_is_ai(player_index):
		return result
	for offer_variant in _pending_contract_offers_for_player(player_index):
		if offer_variant is Dictionary:
			result.append_array(_ai_contract_response_candidates(player_index, offer_variant as Dictionary))
	return result
func _ai_intel_policy_candidates_for_audit(player_index: int) -> Array:
	var result := []
	if not _player_is_ai(player_index):
		return result
	result.append_array(_ai_city_guess_candidates(player_index))
	result.append_array(_ai_card_guess_candidates(player_index))
	return result
func _ai_monster_wager_policy_candidates_for_audit(player_index: int) -> Array:
	var result := []
	if not _player_is_ai(player_index):
		return result
	for wager_variant in active_monster_wagers:
		if not (wager_variant is Dictionary):
			continue
		var plan := _ai_monster_wager_plan(player_index, wager_variant as Dictionary)
		if plan.is_empty():
			continue
		plan["action"] = "monster_wager"
		if not plan.has("policy_kind"):
			plan["policy_kind"] = "monster_wager"
		result.append(plan)
	return result
func _ai_filtered_policy_candidates_for_audit(candidates: Array, label: String) -> Array:
	var result := []
	for candidate_variant in candidates:
		if not (candidate_variant is Dictionary):
			continue
		var candidate: Dictionary = candidate_variant
		var kind := String(candidate.get("kind", ""))
		var policy_kind := String(candidate.get("policy_kind", ""))
		var strategic_role := String(candidate.get("strategic_role", ""))
		if kind.contains(label) or policy_kind.contains(label) or strategic_role.contains(label):
			result.append(candidate)
	return result
func _ai_policy_candidate_audit(player_index: int) -> Dictionary:
	var play_candidates := _ai_card_play_candidates(player_index)
	var buy_candidates := _ai_card_buy_candidates(player_index)
	var military_candidates := _ai_filtered_policy_candidates_for_audit(play_candidates + buy_candidates, "military")
	var weather_candidates := _ai_filtered_policy_candidates_for_audit(play_candidates + buy_candidates, "weather")
	var groups := {
		"card_play": _ai_policy_candidate_group_audit("card_play", play_candidates),
		"card_buy": _ai_policy_candidate_group_audit("card_buy", buy_candidates),
		"counter": _ai_policy_candidate_group_audit("counter", _ai_counter_response_candidates(player_index)),
		"contract": _ai_policy_candidate_group_audit("contract", _ai_contract_policy_candidates_for_audit(player_index)),
		"intel": _ai_policy_candidate_group_audit("intel", _ai_intel_policy_candidates_for_audit(player_index)),
		"monster_wager": _ai_policy_candidate_group_audit("monster_wager", _ai_monster_wager_policy_candidates_for_audit(player_index)),
		"military": _ai_policy_candidate_group_audit("military", military_candidates),
		"weather": _ai_policy_candidate_group_audit("weather", weather_candidates),
	}
	var missing_policy_kind := []
	var missing_training_metadata := []
	var missing_score_components := []
	var empty_fields := []
	var negative_anomalies := []
	var groups_with_candidates := []
	for group_name_variant in groups.keys():
		var group_name := String(group_name_variant)
		var group: Dictionary = groups[group_name]
		if bool(group.get("has_candidates", false)):
			groups_with_candidates.append(group_name)
		missing_policy_kind.append_array(group.get("missing_policy_kind", []) as Array)
		missing_training_metadata.append_array(group.get("missing_training_metadata", []) as Array)
		missing_score_components.append_array(group.get("missing_score_components", []) as Array)
		empty_fields.append_array(group.get("empty_fields", []) as Array)
		negative_anomalies.append_array(group.get("negative_anomalies", []) as Array)
	return {
		"player_index": player_index,
		"is_ai": _player_is_ai(player_index),
		"groups": groups,
		"groups_with_candidates": groups_with_candidates,
		"candidate_count": play_candidates.size() + buy_candidates.size(),
		"missing_policy_kind": missing_policy_kind,
		"missing_training_metadata": missing_training_metadata,
		"missing_score_components": missing_score_components,
		"empty_fields": empty_fields,
		"negative_anomalies": negative_anomalies,
	}
func _monster_target_weight_audit() -> Dictionary:
	var factor_keys := ["base", "panic", "city", "competition", "warehouse", "resource", "distance", "miasma", "monster"]
	var actor_reports := []
	var destroyed_zero_ok := true
	var any_positive_alive := false
	var factor_key_presence := {}
	for key_variant in factor_keys:
		factor_key_presence[String(key_variant)] = false
	for actor_index in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[actor_index]
		if bool(actor.get("down", false)):
			continue
		var district_reports := []
		var positive_alive_count := 0
		for district_index in range(districts.size()):
			var parts := _auto_monster_target_weight_parts(actor, district_index)
			var weight := _auto_monster_target_weight(actor, district_index)
			var destroyed := bool((districts[district_index] as Dictionary).get("destroyed", false))
			if destroyed and weight != 0:
				destroyed_zero_ok = false
			if not destroyed and weight > 0:
				positive_alive_count += 1
				any_positive_alive = true
			for key_variant in factor_keys:
				var key := String(key_variant)
				if parts.has(key):
					factor_key_presence[key] = true
			if district_reports.size() < 12:
				district_reports.append({
					"district": district_index,
					"destroyed": destroyed,
					"weight": weight,
					"parts": parts,
					"summary": _auto_monster_target_factor_summary(actor, district_index),
				})
		actor_reports.append({
			"actor_index": actor_index,
			"name": String(actor.get("name", "怪兽")),
			"positive_alive_count": positive_alive_count,
			"districts": district_reports,
		})
	return {
		"actor_count": actor_reports.size(),
		"factor_keys": factor_keys,
		"factor_key_presence": factor_key_presence,
		"destroyed_zero_ok": destroyed_zero_ok,
		"any_positive_alive": any_positive_alive,
		"actors": actor_reports,
	}
func _hidden_info_leak_audit() -> Dictionary:
	var forbidden_terms := [
		"ai_reason",
		"ai_utility_score",
		"route_plan_score",
		"pressure bucket",
		"pressure_bucket",
		"decision_samples",
		"learning_bonus",
		"rival exact hand",
		"rival exact discard",
		"private route plan",
		"exact AI score",
	]
	var texts := _player_facing_text_snapshot()
	var leaks := []
	for text_index in range(texts.size()):
		var text := String(texts[text_index])
		var lower_text := text.to_lower()
		for term_variant in forbidden_terms:
			var term := String(term_variant)
			if lower_text.contains(term.to_lower()):
				leaks.append({
					"term": term,
					"text_index": text_index,
					"excerpt": _short_card_text(text, 96),
				})
	return {
		"checked_text_count": texts.size(),
		"leak_count": leaks.size(),
		"leaks": leaks,
		"test_only": true,
		"internal_metadata_terms_allowed": forbidden_terms,
	}
func _agent_policy_audit_report() -> Dictionary:
	var player_reports := []
	for player_index_variant in _ai_player_indices():
		player_reports.append(_ai_policy_candidate_audit(int(player_index_variant)))
	var coverage := _playable_card_resolution_coverage_report()
	return {
		"test_only": true,
		"ai_player_count": player_reports.size(),
		"ai_players": player_reports,
		"monster_target": _monster_target_weight_audit(),
		"hidden_info": _hidden_info_leak_audit(),
		"playable_card_resolution_coverage": coverage,
		"playable_missing_handlers": (coverage.get("missing", []) as Array).duplicate(true),
	}
func _ai_learning_tags(action_kind: String = "", policy_kind: String = "", strategy_intent: String = "", route_stage: String = "", product_name: String = "") -> Array:
	var tags := []
	var candidates := [
		"action:%s" % action_kind if action_kind != "" else "",
		"policy:%s" % policy_kind if policy_kind != "" else "",
		"strategy:%s" % strategy_intent if strategy_intent != "" else "",
		"route:%s" % route_stage if route_stage != "" else "",
		"product:%s" % product_name if product_name != "" else "",
	]
	for tag_variant in candidates:
		var tag := String(tag_variant)
		if tag != "" and not tags.has(tag):
			tags.append(tag)
	return tags
func _ai_learning_tags_for_sample(sample: Dictionary) -> Array:
	var tags := _ai_learning_tags(
		String(sample.get("kind", "")),
		String(sample.get("policy_kind", sample.get("strategic_role", ""))),
		String(sample.get("strategy_intent", "")),
		String(sample.get("route_plan_stage", "")),
		String(sample.get("route_plan_product", sample.get("focus_product", "")))
	)
	var direct_product := String(sample.get("product", ""))
	if direct_product != "":
		var product_tag := "product:%s" % direct_product
		if not tags.has(product_tag):
			tags.append(product_tag)
	var development_route := String(sample.get("development_route", ""))
	if development_route != "":
		var development_tag := "development_route:%s" % development_route
		if not tags.has(development_tag):
			tags.append(development_tag)
	return tags
func _ai_learning_reward_for_sample(sample: Dictionary) -> int:
	var gdp_reward := int(sample.get("reward_victory_gdp", 0)) * 5
	var region_reward := int(sample.get("reward_victory_regions", 0)) * 60
	var cash_reward := int(sample.get("reward_cash", 0))
	return clampi(gdp_reward + region_reward + int(round(float(cash_reward) * 0.05)), -AI_LEARNING_REWARD_CLAMP, AI_LEARNING_REWARD_CLAMP)
func _ai_learning_rate_for_player(player_index: int) -> float:
	var exploration := float(_ai_profile_for_player(player_index).get("exploration", 0.15))
	return clampf(AI_LEARNING_BASE_RATE + exploration * 0.35, 0.18, 0.38)
func _ai_apply_learning_tags(player_index: int, memory: Dictionary, tags: Array, reward_score: int) -> Dictionary:
	if tags.is_empty():
		return memory
	var target_value := clampf(float(reward_score) / 10.0, -AI_LEARNING_VALUE_CLAMP, AI_LEARNING_VALUE_CLAMP)
	var learning_rate := _ai_learning_rate_for_player(player_index)
	var values := (memory.get("learned_policy_values", {}) as Dictionary).duplicate(true)
	for tag_variant in tags:
		var tag := String(tag_variant)
		if tag == "":
			continue
		var entry := (values.get(tag, {}) as Dictionary).duplicate(true)
		var old_value := float(entry.get("value", 0.0))
		entry["value"] = clampf(lerpf(old_value, target_value, learning_rate), -AI_LEARNING_VALUE_CLAMP, AI_LEARNING_VALUE_CLAMP)
		entry["samples"] = int(entry.get("samples", 0)) + 1
		entry["reward_total"] = int(entry.get("reward_total", 0)) + reward_score
		entry["last_reward"] = reward_score
		entry["last_cycle"] = business_cycle_count
		values[tag] = entry
	memory["learned_policy_values"] = values
	memory["learning_updates"] = int(memory.get("learning_updates", 0)) + tags.size()
	memory["learning_last_reward"] = reward_score
	memory["learning_last_tags"] = tags
	return memory
func _ai_apply_learning_sample(player_index: int, memory: Dictionary, sample: Dictionary) -> Dictionary:
	if bool(sample.get("learning_applied", false)):
		return memory
	var reward_score := _ai_learning_reward_for_sample(sample)
	var tags := _ai_learning_tags_for_sample(sample)
	return _ai_apply_learning_tags(player_index, memory, tags, reward_score)
func _ai_learned_tag_bonus(player_index: int, tag: String) -> int:
	if tag == "" or player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return 0
	var memory := ((players[player_index] as Dictionary).get("ai_memory", _empty_ai_memory()) as Dictionary)
	var values := memory.get("learned_policy_values", {}) as Dictionary
	var entry := values.get(tag, {}) as Dictionary
	var sample_count := int(entry.get("samples", 0))
	if sample_count <= 0:
		return 0
	var confidence := float(sample_count) / float(sample_count + 2)
	return int(round(float(entry.get("value", 0.0)) * confidence))
func _ai_learning_bonus(player_index: int, policy_kind: String = "", strategy_intent: String = "", route_stage: String = "", product_name: String = "", action_kind: String = "") -> int:
	var bonus := 0
	for tag_variant in _ai_learning_tags(action_kind, policy_kind, strategy_intent, route_stage, product_name):
		bonus += _ai_learned_tag_bonus(player_index, String(tag_variant))
	return clampi(bonus, -AI_LEARNING_BONUS_CLAMP, AI_LEARNING_BONUS_CLAMP)
func _record_ai_decision(player_index: int, kind: String, target_index: int, score: int, reason: String, candidates: Array = [], metadata: Dictionary = {}) -> void:
	if not _player_is_ai(player_index):
		return
	_ai_refresh_economic_focus(player_index)
	var phase_info := _ai_refresh_game_phase(player_index)
	var observation := _ai_observation_vector(player_index)
	var player: Dictionary = players[player_index]
	var memory := (player.get("ai_memory", _empty_ai_memory()) as Dictionary).duplicate(true)
	var samples := (memory.get("decision_samples", []) as Array).duplicate(true)
	var focus_product := String(memory.get("economic_focus_product", ""))
	var sample := {
		"time": game_time,
		"cycle": business_cycle_count,
		"kind": kind,
		"target": target_index,
		"score": score,
		"reason": reason,
		"state": observation,
		"candidates": _ai_candidate_training_views(candidates),
		"focus_product": focus_product,
		"focus_score": int(memory.get("economic_focus_score", 0)),
		"focus_reason": String(memory.get("economic_focus_reason", "")),
		"strategy_intent": String(memory.get("strategic_intent", "")),
		"strategy_score": int(memory.get("strategic_intent_score", 0)),
		"strategy_reason": String(memory.get("strategic_intent_reason", "")),
		"route_plan_product": String(memory.get("route_plan_product", "")),
		"route_plan_stage": String(memory.get("route_plan_stage", "")),
		"route_plan_score": int(memory.get("route_plan_score", 0)),
		"route_plan_reason": String(memory.get("route_plan_reason", "")),
		"game_phase": String(phase_info.get("phase", "midgame")),
		"competitive_posture": String(phase_info.get("posture", "contesting")),
		"score_gap_to_leader": int(phase_info.get("gap", 0)),
		"leader_index": int(phase_info.get("leader_index", -1)),
		"phase_reason": String(phase_info.get("reason", "")),
		"endgame_urgency": _ai_endgame_urgency_score(player_index),
		"baseline_cash": int(player.get("cash", 0)),
		"baseline_victory_gdp": int(observation.get("victory_top_n_gdp_per_minute", 0)),
		"baseline_victory_regions": int(observation.get("victory_controlled_region_count", 0)),
		"reward_cash": 0,
		"reward_victory_gdp": 0,
		"reward_victory_regions": 0,
		"reward_score": 0,
		"reward_finalized": false,
		"learning_applied": false,
	}
	# Candidate metadata may contain its own card `kind`; it must never replace
	# the decision envelope kind (for example `匿名出牌`). Training and audits
	# depend on both levels remaining distinct.
	var reserved_sample_fields := ["time", "cycle", "kind", "target", "state", "candidates", "reward_cash", "reward_victory_gdp", "reward_victory_regions", "reward_score", "reward_finalized", "learning_applied"]
	for key_variant in metadata.keys():
		if reserved_sample_fields.has(String(key_variant)):
			continue
		sample[key_variant] = metadata[key_variant]
	samples.append(sample)
	while samples.size() > AI_DECISION_SAMPLE_LIMIT:
		samples.pop_front()
	memory["decision_samples"] = samples
	var action_counts := (memory.get("action_counts", {}) as Dictionary).duplicate(true)
	action_counts[kind] = int(action_counts.get(kind, 0)) + 1
	memory["action_counts"] = action_counts
	memory["last_plan"] = "%s｜目标%d｜评分%d｜%s" % [kind, target_index + 1, score, reason]
	player["ai_memory"] = memory
	players[player_index] = player
func _finalize_ai_decision_rewards() -> int:
	var finalized := 0
	for player_index_variant in _ai_player_indices():
		var player_index := int(player_index_variant)
		var player: Dictionary = players[player_index]
		var memory := (player.get("ai_memory", _empty_ai_memory()) as Dictionary).duplicate(true)
		var samples := (memory.get("decision_samples", []) as Array).duplicate(true)
		var changed := false
		for i in range(samples.size()):
			if not (samples[i] is Dictionary):
				continue
			var sample: Dictionary = samples[i]
			if bool(sample.get("reward_finalized", false)) or int(sample.get("cycle", business_cycle_count)) >= business_cycle_count:
				continue
			sample["reward_cash"] = int(player.get("cash", 0)) - int(sample.get("baseline_cash", int(player.get("cash", 0))))
			sample["reward_victory_gdp"] = _victory_top_n_gdp(player_index) - int(sample.get("baseline_victory_gdp", 0))
			sample["reward_victory_regions"] = _victory_controlled_regions(player_index) - int(sample.get("baseline_victory_regions", 0))
			sample["reward_score"] = _ai_learning_reward_for_sample(sample)
			sample["reward_finalized"] = true
			sample["reward_cycle"] = business_cycle_count
			memory = _ai_apply_learning_sample(player_index, memory, sample)
			sample["learning_tags"] = _ai_learning_tags_for_sample(sample)
			sample["learning_applied"] = true
			samples[i] = sample
			finalized += 1
			changed = true
		if changed:
			memory["decision_samples"] = samples
			player["ai_memory"] = memory
			players[player_index] = player
	return finalized
func _ai_episode_reward_for_player(player_index: int, rankings: Array, winner_indices: Array) -> Dictionary:
	var rank := _victory_rank_for_player(rankings, player_index)
	var entry := {}
	if rank >= 0 and rank < rankings.size() and rankings[rank] is Dictionary:
		entry = (rankings[rank] as Dictionary).duplicate(true)
	var top_n_gdp := int(entry.get("top_n_gdp_per_minute", 0))
	var controlled_regions := int(entry.get("controlled_region_count", 0))
	var winner := winner_indices.has(player_index)
	var reward := top_n_gdp * 4 + controlled_regions * 80
	if winner:
		reward += AI_EPISODE_WIN_BONUS + AI_EPISODE_GOAL_BONUS
	else:
		reward -= 95 * maxi(1, rank)
	var seat_span := maxi(1, players.size() - 1)
	reward += int(round((float(maxi(0, seat_span - rank)) / float(seat_span)) * 220.0)) - 90
	return {
		"reward": clampi(reward, -AI_EPISODE_REWARD_CLAMP, AI_EPISODE_REWARD_CLAMP),
		"top_n_gdp_per_minute": top_n_gdp,
		"controlled_region_count": controlled_regions,
		"cash_ledger_cents": int(entry.get("cash_ledger_cents", 0)),
		"rank": rank,
		"winner": winner,
		"co_victory": winner and winner_indices.size() > 1,
		"result": "共同胜利" if winner and winner_indices.size() > 1 else ("胜利" if winner else "未获胜"),
	}
func _ai_episode_sample_reward(base_reward: int, sample: Dictionary) -> int:
	var sample_cycle := int(sample.get("cycle", business_cycle_count))
	var age := maxi(0, business_cycle_count - sample_cycle)
	var decayed := int(round(float(base_reward) * pow(AI_EPISODE_SAMPLE_DECAY, float(age))))
	return clampi(decayed, -AI_EPISODE_REWARD_CLAMP, AI_EPISODE_REWARD_CLAMP)
func finalize_victory_outcome_learning(receipt: Dictionary) -> int:
	if players.is_empty() or receipt.is_empty() or not (receipt.get("rankings", []) is Array) or not (receipt.get("winner_player_indices", []) is Array):
		return 0
	var rankings := (receipt.get("rankings", []) as Array).duplicate(true)
	var winner_indices := (receipt.get("winner_player_indices", []) as Array).duplicate()
	var reason := str(receipt.get("reason_code", "victory_resolved"))
	var updated := 0
	for player_index_variant in _ai_player_indices():
		var player_index := int(player_index_variant)
		var player: Dictionary = players[player_index]
		var memory := (player.get("ai_memory", _empty_ai_memory()) as Dictionary).duplicate(true)
		var samples := (memory.get("decision_samples", []) as Array).duplicate(true)
		var episode := _ai_episode_reward_for_player(player_index, rankings, winner_indices)
		var base_reward := int(episode.get("reward", 0))
		var sample_updates := 0
		for i in range(samples.size()):
			if not (samples[i] is Dictionary):
				continue
			var sample: Dictionary = samples[i]
			if bool(sample.get("episode_reward_finalized", false)):
				continue
			var sample_reward := _ai_episode_sample_reward(base_reward, sample)
			sample["episode_reward_score"] = sample_reward
			sample["episode_base_reward"] = base_reward
			sample["episode_top_n_gdp_per_minute"] = int(episode.get("top_n_gdp_per_minute", 0))
			sample["episode_controlled_region_count"] = int(episode.get("controlled_region_count", 0))
			sample["episode_cash_ledger_cents"] = int(episode.get("cash_ledger_cents", 0))
			sample["episode_rank"] = int(episode.get("rank", -1))
			sample["episode_winner"] = bool(episode.get("winner", false))
			sample["episode_co_victory"] = bool(episode.get("co_victory", false))
			sample["episode_result"] = String(episode.get("result", ""))
			sample["episode_reason"] = reason
			sample["episode_reward_cycle"] = business_cycle_count
			sample["episode_reward_finalized"] = true
			var episode_tags := _ai_learning_tags_for_sample(sample)
			sample["episode_learning_tags"] = episode_tags
			memory = _ai_apply_learning_tags(player_index, memory, episode_tags, sample_reward)
			sample["episode_learning_applied"] = true
			samples[i] = sample
			sample_updates += 1
		if sample_updates <= 0:
			continue
		memory["decision_samples"] = samples
		memory["episode_learning_updates"] = int(memory.get("episode_learning_updates", 0)) + sample_updates
		memory["episode_last_reward"] = base_reward
		memory["episode_last_top_n_gdp"] = int(episode.get("top_n_gdp_per_minute", 0))
		memory["episode_last_controlled_regions"] = int(episode.get("controlled_region_count", 0))
		memory["episode_last_rank"] = int(episode.get("rank", -1))
		memory["episode_last_result"] = String(episode.get("result", ""))
		player["ai_memory"] = memory
		players[player_index] = player
		updated += sample_updates
	return updated
func _ai_profile_for_player(player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= players.size():
		return {}
	var profile_variant: Variant = (players[player_index] as Dictionary).get("ai_profile", {})
	return profile_variant as Dictionary if profile_variant is Dictionary else {}
func _ai_development_route_bias(player_index: int, route_id: String) -> float:
	var profile := _ai_profile_for_player(player_index)
	var preferences_variant: Variant = profile.get("route_preferences", {})
	if not (preferences_variant is Dictionary):
		return 1.0
	var preferences: Dictionary = preferences_variant
	return clampf(float(preferences.get(route_id, 1.0)), 0.65, 1.65)
func _ai_development_route_bonus(player_index: int, route_id: String) -> int:
	return int(round((_ai_development_route_bias(player_index, route_id) - 1.0) * 120.0))
func _ai_development_route_learning_bonus(player_index: int, route_id: String) -> int:
	if route_id == "":
		return 0
	return _ai_learned_tag_bonus(player_index, "development_route:%s" % route_id)
func _ai_product_rival_city_count(player_index: int, product_name: String) -> int:
	var count := 0
	if product_name == "":
		return count
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		if int(city.get("owner", -1)) == player_index:
			continue
		if _city_product_names(city).has(product_name) or _city_demand_names(city).has(product_name):
			count += 1
	return count
func _ai_product_market_signal_score(product_name: String) -> int:
	if product_name == "":
		return 0
	_ensure_product_market_catalog()
	var entry: Dictionary = product_market.get(product_name, {})
	if entry.is_empty():
		return int(float(_product_price(product_name)) / 3.0)
	var price := int(entry.get("price", entry.get("base_price", _product_price(product_name))))
	var base_price := int(entry.get("base_price", price))
	var demand := int(entry.get("demand", 0))
	var supply := int(entry.get("supply", 0))
	var temporary_demand := int(entry.get("temporary_demand_pressure", 0))
	var temporary_supply := int(entry.get("temporary_supply_pressure", 0))
	var contract_demand := int(entry.get("market_contract_demand", 0))
	var contract_supply := int(entry.get("market_contract_supply", 0))
	var score := int(round(float(price) / 3.0))
	score += max(0, price - base_price) / 2
	score += demand * 9
	score -= supply * 4
	score += temporary_demand * 12
	score -= temporary_supply * 5
	score += contract_demand * 14
	score -= contract_supply * 5
	score += int(round((float(entry.get("growth_multiplier", 1.0)) - 1.0) * 50.0))
	score += int(round((float(entry.get("route_flow_multiplier", 1.0)) - 1.0) * 42.0))
	return score
func _ai_product_city_exposure_score(player_index: int, product_name: String) -> int:
	if product_name == "":
		return 0
	var score := _player_product_flow(player_index, product_name) * 74
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		var city_owner := int(city.get("owner", -1))
		var product_match := _city_product_names(city).has(product_name)
		var demand_match := _city_demand_names(city).has(product_name)
		if city_owner == player_index:
			if product_match:
				score += 72 + int(float(int(city.get("last_income", 0))) / 4.0)
			if demand_match:
				score += 46
			for route_variant in city.get("trade_routes", []):
				var route: Dictionary = route_variant
				if String(route.get("product", "")) == product_name and not bool(route.get("disrupted", false)):
					score += 34
		elif product_match or demand_match:
			score += 26
			if product_match and _player_product_flow(player_index, product_name) > 0:
				score += 44
	return score
func _ai_product_focus_score(player_index: int, product_name: String) -> int:
	if product_name == "" or not PRODUCT_CATALOG.has(product_name):
		return -999
	var score := _ai_product_market_signal_score(product_name)
	score += _ai_product_city_exposure_score(player_index, product_name)
	var role := _player_role_card_for_index(player_index)
	if String(role.get("resource_cash_product", "")) == product_name:
		score += 155 + int(role.get("resource_cash_amount", 0))
	if String(role.get("bonus_card_product", "")) == product_name:
		score += 120
	var rival_count := _ai_product_rival_city_count(player_index, product_name)
	score += rival_count * (32 + (_player_product_flow(player_index, product_name) * 8))
	var gdp_gap := maxi(0, _victory_required_gdp() - _victory_top_n_gdp(player_index))
	if gdp_gap > 0:
		score += int(round(float(gdp_gap) / 15.0)) * (8 + int(round(float(_product_price(product_name)) / 35.0)))
	if _player_product_flow(player_index, product_name) <= 0 and String(role.get("resource_cash_product", "")) != product_name and String(role.get("bonus_card_product", "")) != product_name:
		score -= 45
	return score
func _ai_focus_reason(player_index: int, product_name: String, score: int) -> String:
	if product_name == "":
		return "尚未形成商品焦点"
	var gdp_gap := maxi(0, _victory_required_gdp() - _victory_top_n_gdp(player_index))
	return "%s｜流动%d｜市价¥%d｜竞品城%d｜审计GDP缺口%d/min｜评分%d" % [
		product_name,
		_player_product_flow(player_index, product_name),
		_product_price(product_name),
		_ai_product_rival_city_count(player_index, product_name),
		gdp_gap,
		score,
	]
func _ai_refresh_economic_focus(player_index: int, force: bool = false) -> String:
	if player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return ""
	var player: Dictionary = players[player_index]
	var memory := (player.get("ai_memory", _empty_ai_memory()) as Dictionary).duplicate(true)
	var cached_product := String(memory.get("economic_focus_product", ""))
	if not force and int(memory.get("economic_focus_cycle", -1)) == business_cycle_count and cached_product != "" and PRODUCT_CATALOG.has(cached_product):
		return cached_product
	var rankings := []
	for product_variant in PRODUCT_CATALOG:
		var product_name := String(product_variant)
		if product_name == "":
			continue
		rankings.append({
			"product": product_name,
			"score": _ai_product_focus_score(player_index, product_name),
			"flow": _player_product_flow(player_index, product_name),
			"price": _product_price(product_name),
			"rivals": _ai_product_rival_city_count(player_index, product_name),
		})
	if rankings.is_empty():
		return ""
	rankings.sort_custom(Callable(self, "_sort_ai_focus_score_desc"))
	var best := rankings[0] as Dictionary
	var best_product := String(best.get("product", ""))
	var best_score := int(best.get("score", 0))
	var compact_rankings := []
	for i in range(mini(AI_ECONOMIC_FOCUS_TOP_LIMIT, rankings.size())):
		compact_rankings.append(rankings[i])
	memory["economic_focus_product"] = best_product
	memory["economic_focus_score"] = best_score
	memory["economic_focus_reason"] = _ai_focus_reason(player_index, best_product, best_score)
	memory["economic_focus_cycle"] = business_cycle_count
	memory["economic_focus_rankings"] = compact_rankings
	player["ai_memory"] = memory
	players[player_index] = player
	return best_product
func _ai_focus_product(player_index: int) -> String:
	if player_index < 0 or player_index >= players.size():
		return ""
	if not _player_is_ai(player_index):
		return _first_player_flow_product(player_index)
	return _ai_refresh_economic_focus(player_index)
func _ai_focus_score(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return 0
	_ai_refresh_economic_focus(player_index)
	var memory := ((players[player_index] as Dictionary).get("ai_memory", _empty_ai_memory()) as Dictionary)
	return int(memory.get("economic_focus_score", 0))
func _ai_own_route_threat_score(player_index: int) -> int:
	var score := 0
	for city_index_variant in _active_city_indices_for_player(player_index):
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		score += int(city.get("trade_route_damage", 0)) * 84
		score += int(city.get("trade_disrupted_routes", 0)) * 46
		score += int(districts[city_index].get("damage", 0)) * 18
		score += int(float(int(districts[city_index].get("panic", 0))) / 3.0)
		score += _city_warehouse_stockpile_pressure(city)
		for actor_variant in auto_monsters:
			var actor: Dictionary = actor_variant
			if bool(actor.get("down", false)):
				continue
			var distance := _entity_distance_to_district(actor, city_index)
			if distance <= AUTO_MONSTER_ENCOUNTER_RANGE_METERS:
				score += 68
			elif distance <= NEARBY_RADIUS_METERS:
				score += 44
			elif distance <= NEARBY_RADIUS_METERS * 1.6:
				score += 22
			score += _monster_resource_match_score(actor, city_index) * 18
	return score
func _ai_focus_rival_pressure_score(player_index: int) -> int:
	var focus := _ai_focus_product(player_index)
	if focus == "":
		return 0
	var score := 0
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		if int(city.get("owner", -1)) == player_index:
			continue
		var product_match := _city_product_names(city).has(focus)
		var demand_match := _city_demand_names(city).has(focus)
		if not product_match and not demand_match:
			continue
		score += _ai_rival_city_pressure_score(player_index, city_index)
		if product_match:
			score += 58 + _player_product_flow(player_index, focus) * 14
		if demand_match:
			score += 24
	return score
func _ai_growth_need_score(player_index: int) -> int:
	var focus := _ai_focus_product(player_index)
	var gdp_gap := maxi(0, _victory_required_gdp() - _victory_top_n_gdp(player_index))
	var score := 58 + int(float(gdp_gap) / 4.0)
	score += maxi(0, 2 - _player_active_city_count(player_index)) * 115
	if focus != "":
		score += maxi(0, 3 - _player_product_flow(player_index, focus)) * 64
		score += int(float(_ai_focus_score(player_index)) / 5.0)
	return score
func _ai_strategy_candidates(player_index: int) -> Array:
	var focus := _ai_focus_product(player_index)
	var phase_info := _ai_refresh_game_phase(player_index)
	var phase := String(phase_info.get("phase", "midgame"))
	var posture := String(phase_info.get("posture", "contesting"))
	var phase_label := _ai_game_phase_label(phase)
	var posture_label := _ai_competitive_posture_label(posture)
	var gdp_gap := maxi(0, _victory_required_gdp() - _victory_top_n_gdp(player_index))
	var route_threat := _ai_own_route_threat_score(player_index)
	var rival_pressure := _ai_focus_rival_pressure_score(player_index)
	var growth_need := _ai_growth_need_score(player_index)
	var established_competition_bonus := 0
	var growth_overextension_penalty := 0
	if phase != "opening" and _player_active_city_count(player_index) > 0 and rival_pressure >= 260:
		established_competition_bonus = mini(320, int(float(rival_pressure) / 2.0))
		if focus != "" and _player_product_flow(player_index, focus) > 0:
			established_competition_bonus += 65
		growth_overextension_penalty = mini(150, int(float(rival_pressure) / 4.0))
	var defend_learning := _ai_learning_bonus(player_index, "", "defend_routes", "", focus, "战略选择")
	var disrupt_learning := _ai_learning_bonus(player_index, "", "disrupt_competitors", "", focus, "战略选择")
	var grow_learning := _ai_learning_bonus(player_index, "", "grow_focus", "", focus, "战略选择")
	var defend_phase_bonus := 0
	var disrupt_phase_bonus := 0
	var grow_phase_bonus := 0
	match phase:
		"opening":
			grow_phase_bonus += 150
			defend_phase_bonus += 20
			disrupt_phase_bonus -= 35
		"midgame":
			grow_phase_bonus += 45
			defend_phase_bonus += mini(80, int(float(route_threat) / 3.0))
			disrupt_phase_bonus += mini(90, int(float(rival_pressure) / 3.0))
		"endgame":
			if posture == "leader":
				defend_phase_bonus += 170
				grow_phase_bonus += 45
				disrupt_phase_bonus += 20
			elif posture == "trailing":
				disrupt_phase_bonus += 185
				grow_phase_bonus += 75
				defend_phase_bonus += int(float(route_threat) / 2.0)
			else:
				disrupt_phase_bonus += 90
				defend_phase_bonus += 80
				grow_phase_bonus += 50
	return [
		{
			"intent": "defend_routes",
			"score": 42 + route_threat + int(float(route_threat) / 2.0) + int(round(float(gdp_gap) / 8.0)) + defend_phase_bonus + defend_learning,
			"game_phase": phase,
			"competitive_posture": posture,
			"phase_bonus": defend_phase_bonus,
			"learning_bonus": defend_learning,
			"reason": "保卫商路｜%s/%s｜威胁%d｜审计GDP缺口%d/min｜阶段%d｜学习%d" % [phase_label, posture_label, route_threat, gdp_gap, defend_phase_bonus, defend_learning],
		},
		{
			"intent": "disrupt_competitors",
			"score": 54 + rival_pressure + _player_product_flow(player_index, focus) * 18 + established_competition_bonus + disrupt_phase_bonus + disrupt_learning,
			"game_phase": phase,
			"competitive_posture": posture,
			"phase_bonus": disrupt_phase_bonus,
			"learning_bonus": disrupt_learning,
			"reason": "压制竞品｜%s/%s｜焦点%s｜竞品压力%d｜成型竞品%d｜阶段%d｜学习%d" % [phase_label, posture_label, focus if focus != "" else "未定", rival_pressure, established_competition_bonus, disrupt_phase_bonus, disrupt_learning],
		},
		{
			"intent": "grow_focus",
			"score": growth_need + grow_phase_bonus + grow_learning - growth_overextension_penalty,
			"game_phase": phase,
			"competitive_posture": posture,
			"phase_bonus": grow_phase_bonus,
			"learning_bonus": grow_learning,
			"reason": "扩张焦点｜%s/%s｜焦点%s｜成长需求%d｜竞品牵制-%d｜阶段%d｜学习%d" % [phase_label, posture_label, focus if focus != "" else "未定", growth_need, growth_overextension_penalty, grow_phase_bonus, grow_learning],
		},
	]
func _ai_refresh_strategy_intent(player_index: int, force: bool = false) -> Dictionary:
	if player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return {}
	_ai_refresh_economic_focus(player_index, force)
	var player: Dictionary = players[player_index]
	var memory := (player.get("ai_memory", _empty_ai_memory()) as Dictionary).duplicate(true)
	var cached_intent := String(memory.get("strategic_intent", ""))
	if not force and int(memory.get("strategic_intent_cycle", -1)) == business_cycle_count and cached_intent != "":
		return {
			"intent": cached_intent,
			"score": int(memory.get("strategic_intent_score", 0)),
			"reason": String(memory.get("strategic_intent_reason", "")),
		}
	var rankings := _ai_strategy_candidates(player_index)
	if rankings.is_empty():
		return {}
	rankings.sort_custom(Callable(self, "_sort_ai_candidate_score_desc"))
	var best := rankings[0] as Dictionary
	var compact_rankings := []
	for i in range(mini(AI_STRATEGY_TOP_LIMIT, rankings.size())):
		compact_rankings.append(rankings[i])
	memory["strategic_intent"] = String(best.get("intent", "grow_focus"))
	memory["strategic_intent_score"] = int(best.get("score", 0))
	memory["strategic_intent_reason"] = String(best.get("reason", ""))
	memory["strategic_intent_cycle"] = business_cycle_count
	memory["strategic_intent_rankings"] = compact_rankings
	player["ai_memory"] = memory
	players[player_index] = player
	return best
func _ai_strategy_intent(player_index: int) -> String:
	var strategy := _ai_refresh_strategy_intent(player_index)
	return String(strategy.get("intent", ""))
func _ai_strategy_score(player_index: int) -> int:
	var strategy := _ai_refresh_strategy_intent(player_index)
	return int(strategy.get("score", 0))
func _ai_strategy_bonus_for_candidate(player_index: int, kind: String, district_index: int, product_name: String = "", target_owner: int = -999, skill: Dictionary = {}) -> int:
	var strategy := _ai_refresh_strategy_intent(player_index)
	var intent := String(strategy.get("intent", ""))
	if intent == "":
		return 0
	var focus := _ai_focus_product(player_index)
	var resolved_owner := target_owner
	if resolved_owner == -999 and district_index >= 0 and district_index < districts.size():
		var city := _district_city(district_index)
		if _city_is_active(city):
			resolved_owner = int(city.get("owner", -1))
	var bonus := 0
	var derivative_terms := _city_gdp_derivative_terms(skill) if kind == "city_gdp_derivative" else {}
	match intent:
		"defend_routes":
			if ["route_insurance", "special_monster_delay", "route_flow_boon", "region_economy_shift", "weather_control"].has(kind) or (kind == "city_gdp_derivative" and (String(derivative_terms.get("direction", "up")) == "up" or bool(derivative_terms.get("insurance", false)))):
				bonus += AI_STRATEGY_MATCH_BONUS
			if resolved_owner == player_index:
				bonus += mini(120, int(float(_ai_own_route_threat_score(player_index)) / 3.0))
		"disrupt_competitors":
			if ["route_sabotage", "panic_shift", "news_event", "weather_control", "monster_lure", "mudslide", "area_damage", "city_gdp_derivative", "player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage"].has(kind):
				bonus += AI_STRATEGY_MATCH_BONUS
			if resolved_owner >= 0 and resolved_owner != player_index:
				bonus += 70
			if focus != "" and product_name == focus:
				bonus += 46
		"grow_focus":
			if ["city_build", "city_revenue_boost", "city_product_upgrade", "city_product_shift", "city_demand_shift", "city_contract_boon", "route_flow_boon", "product_speculation", "city_gdp_derivative", "product_contract_boon", "product_growth_boon", "cash_gain", "area_trade_contract", "region_economy_shift", "news_event", "weather_control"].has(kind):
				bonus += AI_STRATEGY_MATCH_BONUS
			if focus != "" and product_name == focus:
				bonus += 54
			if district_index >= 0:
				bonus += mini(90, int(float(_ai_district_focus_score(player_index, district_index)) / 2.0))
	return max(0, bonus)
func _ai_development_route_for_kind(kind: String, skill: Dictionary = {}) -> String:
	if not skill.is_empty():
		var route_id := _card_development_route_id(skill)
		if route_id != "":
			return route_id
	match kind:
		"city_build", "city_revenue_boost", "city_product_upgrade", "city_product_shift", "city_demand_shift", "city_contract_boon", "route_flow_boon", "region_economy_shift", "route_insurance":
			return "city_growth"
		"area_trade_contract", "product_contract_boon":
			return "contract_route"
		"product_speculation", "product_futures", "city_gdp_derivative", "market_stabilize", "product_growth_boon", "cash_gain":
			return "finance_speculation"
		"monster_card", "monster_bound_action", "monster_lure", "monster_takeover", "mudslide", "special_monster_delay", "news_event", "weather_control", "route_sabotage", "panic_shift":
			return "monster_pressure"
		"intel_city_reveal", "intel_card_trace", "intel_contract_trace", "supply_draw":
			return "intel_supply"
		"player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage", "card_counter":
			return "direct_interaction"
		"military_force", "military_command":
			return "direct_interaction"
	return "tactical_support"
func _ai_policy_family_for_kind(kind: String, skill: Dictionary = {}) -> String:
	var probe := {
		"kind": kind,
		"policy_kind": kind,
	}
	for field_name in ["weather_type", "direct_interaction_role", "contract_response_role", "futures_direction", "strategic_role"]:
		if skill.has(field_name):
			probe[field_name] = skill[field_name]
	return _ai_product_sample_policy_family(probe)
func _ai_profile_route_preference_bonus(profile: Dictionary, route_id: String) -> int:
	if route_id == "":
		return 0
	var preferences_variant: Variant = profile.get("route_preferences", {})
	if not (preferences_variant is Dictionary):
		return 0
	var preferences := preferences_variant as Dictionary
	var bias := float(preferences.get(route_id, 1.0))
	if bias <= 1.0:
		return 0
	return int(round((bias - 1.0) * 150.0))
func _ai_profile_signature_bonus_for_candidate(player_index: int, kind: String, district_index: int, product_name: String = "", target_owner: int = -999, skill: Dictionary = {}) -> Dictionary:
	var result := {
		"bonus": 0,
		"family": "",
		"route": "",
		"reason": "",
	}
	if player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index) or kind == "":
		return result
	var profile := _ai_profile_for_player(player_index)
	var route_id := _ai_development_route_for_kind(kind, skill)
	var family := _ai_policy_family_for_kind(kind, skill)
	var expected_routes := _ai_profile_expected_route_ids(profile)
	var expected_families := _ai_profile_expected_policy_families(profile)
	var signature_families := _ai_profile_signature_policy_families(profile)
	var bonus := 0
	var reasons := []
	var route_preference_bonus := _ai_profile_route_preference_bonus(profile, route_id)
	if route_id != "" and expected_routes.has(route_id):
		bonus += 42 + route_preference_bonus
		reasons.append("%s路线+%d" % [_development_route_label(route_id), 42 + route_preference_bonus])
	if family != "" and expected_families.has(family):
		bonus += 24
		reasons.append("%s行动+24" % family)
	if family != "" and signature_families.has(family):
		bonus += 58
		reasons.append("签名%s+58" % family)
	if product_name != "" and (product_name == _ai_focus_product(player_index) or product_name == _ai_route_plan_product(player_index)):
		bonus += 20
		reasons.append("商品吻合+20")
	var resolved_owner := target_owner
	if resolved_owner == -999 and district_index >= 0 and district_index < districts.size():
		var city := _district_city(district_index)
		if _city_is_active(city):
			resolved_owner = int(city.get("owner", -1))
	if route_id == "city_growth" and resolved_owner == player_index:
		bonus += 18
		reasons.append("己方成长+18")
	elif ["monster_pressure", "direct_interaction"].has(route_id) and resolved_owner >= 0 and resolved_owner != player_index:
		bonus += 24
		reasons.append("压制目标+24")
	result["bonus"] = clampi(bonus, 0, 180)
	result["family"] = family
	result["route"] = route_id
	result["reason"] = "、".join(reasons) if not reasons.is_empty() else "无签名偏置"
	return result
func _ai_owned_city_product_count(player_index: int, product_name: String, demand_side: bool = false) -> int:
	if product_name == "":
		return 0
	var count := 0
	for city_index_variant in _active_city_indices_for_player(player_index):
		var city := _district_city(int(city_index_variant))
		if demand_side:
			if _city_demand_names(city).has(product_name):
				count += 1
		elif _city_product_names(city).has(product_name):
			count += 1
	return count
func _ai_city_touches_product(city: Dictionary, product_name: String) -> bool:
	if product_name == "":
		return false
	return _city_product_names(city).has(product_name) or _city_demand_names(city).has(product_name)
func _ai_district_touches_product(district_index: int, product_name: String) -> bool:
	if product_name == "" or district_index < 0 or district_index >= districts.size():
		return false
	var district: Dictionary = districts[district_index]
	if (district.get("products", []) as Array).has(product_name) or (district.get("demands", []) as Array).has(product_name):
		return true
	var city := _district_city(district_index)
	return _city_is_active(city) and _ai_city_touches_product(city, product_name)
func _ai_product_route_threat_score(player_index: int, product_name: String) -> int:
	if product_name == "":
		return 0
	var score := 0
	for city_index_variant in _active_city_indices_for_player(player_index):
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		var related := _ai_city_touches_product(city, product_name)
		for route_variant in city.get("trade_routes", []):
			var route: Dictionary = route_variant
			if String(route.get("product", "")) == product_name:
				related = true
				if bool(route.get("disrupted", false)):
					score += 58
		if not related:
			continue
		score += int(city.get("trade_route_damage", 0)) * 92
		score += int(city.get("trade_disrupted_routes", 0)) * 54
		score += int(districts[city_index].get("damage", 0)) * 18
		score += int(float(int(districts[city_index].get("panic", 0))) / 4.0)
	return score
func _ai_best_owned_route_city_for_product(player_index: int, product_name: String, prefer_damaged: bool = false) -> int:
	var best_index := -1
	var best_score := -1
	for city_index_variant in _active_city_indices_for_player(player_index):
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		var score := 20 + _ai_city_target_score(player_index, city_index, true, prefer_damaged)
		if _city_product_names(city).has(product_name):
			score += 120
		if _city_demand_names(city).has(product_name):
			score += 82
		for route_variant in city.get("trade_routes", []):
			var route: Dictionary = route_variant
			if String(route.get("product", "")) == product_name:
				score += 48
				if bool(route.get("disrupted", false)):
					score += 66
		if score > best_score:
			best_score = score
			best_index = city_index
	return best_index
func _ai_best_rival_route_city_for_product(player_index: int, product_name: String) -> Dictionary:
	var best := {"index": -1, "score": 0}
	if product_name == "":
		return best
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		if int(city.get("owner", -1)) == player_index:
			continue
		if not _ai_city_touches_product(city, product_name):
			continue
		var score := _ai_rival_city_pressure_score(player_index, city_index)
		if _city_product_names(city).has(product_name):
			score += 80
		if _city_demand_names(city).has(product_name):
			score += 34
		if score > int(best.get("score", 0)):
			best["index"] = city_index
			best["score"] = score
	return best
func _ai_route_plan_stage_label(stage: String) -> String:
	match stage:
		"build_supply":
			return "补供给城市"
		"create_demand":
			return "制造需求"
		"strengthen_route":
			return "强化商路"
		"defend_route":
			return "保护路线"
		"attack_rival":
			return "打击竞品"
	return "观察路线"
func _ai_strategy_intent_label(intent: String) -> String:
	match intent:
		"grow_focus":
			return "扩张GDP"
		"defend_routes":
			return "保护商路"
		"disrupt_competitors":
			return "压制竞品"
	return "观察局势"
func _ai_route_plan_candidates(player_index: int) -> Array:
	var result := []
	if player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return result
	_ensure_product_market_catalog()
	var focus := _ai_focus_product(player_index)
	var strategy := _ai_strategy_intent(player_index)
	var gdp_gap := maxi(0, _victory_required_gdp() - _victory_top_n_gdp(player_index))
	for product_variant in PRODUCT_CATALOG:
		var product_name := String(product_variant)
		if product_name == "":
			continue
		var flow := _player_product_flow(player_index, product_name)
		var supply_count := _ai_owned_city_product_count(player_index, product_name, false)
		var demand_count := _ai_owned_city_product_count(player_index, product_name, true)
		var route_threat := _ai_product_route_threat_score(player_index, product_name)
		var rival := _ai_best_rival_route_city_for_product(player_index, product_name)
		var rival_pressure := int(rival.get("score", 0))
		var seed_district := -1
		var stage := "strengthen_route"
		if supply_count <= 0:
			stage = "build_supply"
		elif demand_count <= 0:
			stage = "create_demand"
		elif flow <= 0:
			stage = "strengthen_route"
		elif route_threat >= 170 or strategy == "defend_routes":
			stage = "defend_route"
		elif rival_pressure >= 260 or strategy == "disrupt_competitors":
			stage = "attack_rival"
		var target_city := _ai_best_owned_route_city_for_product(player_index, product_name, stage == "defend_route")
		var score := 70 + int(float(_ai_product_market_signal_score(product_name)) / 2.0) + int(round(float(_product_price(product_name)) / 8.0))
		score += flow * 46 + supply_count * 34 + demand_count * 28
		score += int(round(float(gdp_gap) / 10.0))
		if product_name == focus:
			score += AI_ROUTE_PLAN_MATCH_BONUS + int(float(_ai_focus_score(player_index)) / 4.0)
		match stage:
			"build_supply":
				score += 150 + maxi(0, 2 - supply_count) * 70
				if seed_district >= 0:
					score += 85
					if _ai_district_touches_product(seed_district, product_name):
						score += 70
			"create_demand":
				score += 132 + maxi(0, 2 - demand_count) * 56
			"defend_route":
				score += 112 + route_threat
			"attack_rival":
				score += 92 + rival_pressure
			_:
				score += 118 + flow * 24
		var learning_bonus := _ai_learning_bonus(player_index, "", strategy, stage, product_name, "路线规划")
		score += learning_bonus
		result.append({
			"product": product_name,
			"stage": stage,
			"score": maxi(1, score),
			"learning_bonus": learning_bonus,
			"flow": flow,
			"supply_cities": supply_count,
			"demand_cities": demand_count,
			"route_threat": route_threat,
			"rival_pressure": rival_pressure,
			"target_city": target_city,
			"rival_city": int(rival.get("index", -1)),
			"partner_district": seed_district,
			"reason": "%s｜%s｜流动%d｜供给城%d｜需求城%d｜威胁%d｜竞品%d｜学习%d" % [
				product_name,
				_ai_route_plan_stage_label(stage),
				flow,
				supply_count,
				demand_count,
				route_threat,
				rival_pressure,
				learning_bonus,
			],
		})
	return result
func _ai_refresh_route_plan(player_index: int, force: bool = false) -> Dictionary:
	if player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return {}
	_ai_refresh_economic_focus(player_index, force)
	var player: Dictionary = players[player_index]
	var memory := (player.get("ai_memory", _empty_ai_memory()) as Dictionary).duplicate(true)
	var cached_product := String(memory.get("route_plan_product", ""))
	var cached_stage := String(memory.get("route_plan_stage", ""))
	if not force and int(memory.get("route_plan_cycle", -1)) == business_cycle_count and cached_product != "" and cached_stage != "":
		return {
			"product": cached_product,
			"stage": cached_stage,
			"score": int(memory.get("route_plan_score", 0)),
			"reason": String(memory.get("route_plan_reason", "")),
			"target_city": int(memory.get("route_plan_target_city", -1)),
			"partner_district": int(memory.get("route_plan_partner_district", -1)),
		}
	var rankings := _ai_route_plan_candidates(player_index)
	if rankings.is_empty():
		return {}
	rankings.sort_custom(Callable(self, "_sort_ai_candidate_score_desc"))
	var best := rankings[0] as Dictionary
	if cached_product != "" and cached_product != String(best.get("product", "")):
		for candidate_variant in rankings:
			var incumbent := candidate_variant as Dictionary
			if String(incumbent.get("product", "")) != cached_product:
				continue
			var made_progress := false
			for previous_variant in memory.get("route_plan_rankings", []):
				var previous := previous_variant as Dictionary
				if String(previous.get("product", "")) != cached_product:
					continue
				made_progress = (
					int(incumbent.get("flow", 0)) > int(previous.get("flow", 0))
					or int(incumbent.get("supply_cities", 0)) > int(previous.get("supply_cities", 0))
					or int(incumbent.get("demand_cities", 0)) > int(previous.get("demand_cities", 0))
				)
				break
			var switch_margin := int(AI_ROUTE_PLAN_SWITCH_MARGIN)
			if int(incumbent.get("flow", 0)) > 0 or int(incumbent.get("supply_cities", 0)) > 0 or int(incumbent.get("demand_cities", 0)) > 0:
				switch_margin = AI_ROUTE_PLAN_ENTRENCHED_SWITCH_MARGIN
			if made_progress or int(incumbent.get("score", 0)) + switch_margin >= int(best.get("score", 0)):
				best = incumbent.duplicate(true)
				if made_progress:
					best["reason"] = "%s｜既有路线刚取得进展，继续推进" % String(best.get("reason", ""))
				else:
					best["reason"] = "%s｜延续既有路线，切换门槛%d" % [
						String(best.get("reason", "")),
						switch_margin,
					]
			break
	var compact_rankings := []
	for i in range(mini(AI_ROUTE_PLAN_TOP_LIMIT, rankings.size())):
		compact_rankings.append(rankings[i])
	memory["route_plan_product"] = String(best.get("product", ""))
	memory["route_plan_stage"] = String(best.get("stage", ""))
	memory["route_plan_score"] = int(best.get("score", 0))
	memory["route_plan_reason"] = String(best.get("reason", ""))
	memory["route_plan_cycle"] = business_cycle_count
	memory["route_plan_target_city"] = int(best.get("target_city", -1))
	memory["route_plan_partner_district"] = int(best.get("partner_district", -1))
	memory["route_plan_rankings"] = compact_rankings
	player["ai_memory"] = memory
	players[player_index] = player
	return best
func _ai_route_plan_product(player_index: int) -> String:
	var plan := _ai_refresh_route_plan(player_index)
	return String(plan.get("product", ""))
func _ai_route_plan_stage(player_index: int) -> String:
	var plan := _ai_refresh_route_plan(player_index)
	return String(plan.get("stage", ""))
func _ai_route_plan_score(player_index: int) -> int:
	var plan := _ai_refresh_route_plan(player_index)
	return int(plan.get("score", 0))
func _ai_route_plan_bonus_for_candidate(player_index: int, kind: String, district_index: int, product_name: String = "", target_owner: int = -999, skill: Dictionary = {}) -> int:
	var plan := _ai_refresh_route_plan(player_index)
	var plan_product := String(plan.get("product", ""))
	var stage := String(plan.get("stage", ""))
	if plan_product == "" or stage == "":
		return 0
	var resolved_owner := target_owner
	if resolved_owner == -999 and district_index >= 0 and district_index < districts.size():
		var city := _district_city(district_index)
		if _city_is_active(city):
			resolved_owner = int(city.get("owner", -1))
	var product_match := product_name == plan_product
	if not product_match:
		product_match = _ai_district_touches_product(district_index, plan_product)
	var bonus := 0
	var derivative_terms := _city_gdp_derivative_terms(skill) if kind == "city_gdp_derivative" else {}
	if product_match:
		bonus += AI_ROUTE_PLAN_MATCH_BONUS
	match stage:
		"build_supply":
			if kind == "city_build":
				bonus += 110
				if district_index == int(plan.get("partner_district", -1)):
					bonus += 180
				if product_match:
					bonus += 70
			elif ["city_product_shift", "area_trade_contract", "product_contract_boon", "region_economy_shift"].has(kind) and product_match:
				bonus += 72
		"create_demand":
			if ["city_demand_shift", "area_trade_contract", "product_contract_boon", "route_flow_boon", "city_contract_boon"].has(kind) and product_match:
				bonus += 118
			if resolved_owner == player_index:
				bonus += 42
		"strengthen_route":
			if ["route_flow_boon", "city_revenue_boost", "city_product_upgrade", "city_contract_boon", "product_speculation", "city_gdp_derivative", "product_contract_boon", "product_growth_boon", "area_trade_contract", "news_event", "weather_control"].has(kind) and product_match:
				bonus += 108
			if resolved_owner == player_index:
				bonus += 34
		"defend_route":
			if ["route_insurance", "special_monster_delay", "route_flow_boon", "region_economy_shift", "city_demand_shift", "weather_control"].has(kind) or (kind == "city_gdp_derivative" and bool(derivative_terms.get("insurance", false))):
				bonus += 96
			if resolved_owner == player_index:
				bonus += mini(132, int(float(_ai_product_route_threat_score(player_index, plan_product)) / 2.0))
		"attack_rival":
			if ["route_sabotage", "monster_lure", "panic_shift", "news_event", "weather_control", "mudslide", "area_damage", "region_economy_shift", "city_gdp_derivative", "player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage"].has(kind):
				bonus += 116
			if resolved_owner >= 0 and resolved_owner != player_index:
				bonus += 76
			if product_match:
				bonus += 44
	return max(0, bonus)
func _ai_play_requirement_metadata(player_index: int, skill: Dictionary, planned_district: int = -1) -> Dictionary:
	var evaluated_skill := skill.duplicate(true)
	var scope := _skill_play_region_scope(evaluated_skill)
	var has_locked_requirement_district := evaluated_skill.has("play_requirement_district")
	var requirement_district := int(evaluated_skill.get("play_requirement_district", planned_district))
	if not has_locked_requirement_district:
		if scope == CardPlayRequirementPolicyScript.SCOPE_OWN_BEST_REGION:
			requirement_district = _best_player_gdp_share_district(player_index)
		elif scope == CardPlayRequirementPolicyScript.SCOPE_CONTRACT_SOURCE_REGION and planned_district < 0:
			requirement_district = selected_contract_source_district
	if requirement_district >= 0:
		evaluated_skill["play_requirement_district"] = requirement_district
	var status := _skill_play_requirement_status(player_index, evaluated_skill)
	return {
		"play_requirement_kind": String(status.get("kind", "none")),
		"play_requirement_scope": String(status.get("scope", scope)),
		"required_share_percent": int(status.get("required_share_percent", 0)),
		"current_share_percent": float(status.get("current_share_percent", 0.0)),
		"qualifying_district": int(status.get("qualifying_district", -1)),
		"requirement_satisfied": bool(status.get("requirement_satisfied", false)),
	}
func _ai_route_hand_inventory(player_index: int, route_id: String) -> Dictionary:
	var result := {
		"total": 0,
		"playable": 0,
		"blocked_flow": 0,
		"blocked_region_share": 0,
		"blocked_cash": 0,
		"blocked_gap": 0,
	}
	if player_index < 0 or player_index >= players.size() or route_id == "":
		return result
	var player: Dictionary = players[player_index]
	var slots_variant: Variant = player.get("slots", [])
	if not (slots_variant is Array):
		return result
	var cash := int(player.get("cash", 0))
	for slot_variant in (slots_variant as Array):
		if not (slot_variant is Dictionary):
			continue
		var skill := slot_variant as Dictionary
		if bool(skill.get("queued_for_resolution", false)) or float(skill.get("lock_left", 0.0)) > 0.0:
			continue
		if _card_development_route_id(skill) != route_id:
			continue
		result["total"] = int(result.get("total", 0)) + 1
		var requirement := _ai_play_requirement_metadata(player_index, skill, _best_player_gdp_share_district(player_index))
		var cash_cost := _skill_play_cash_cost(skill)
		if bool(requirement.get("requirement_satisfied", false)) and cash >= cash_cost:
			result["playable"] = int(result.get("playable", 0)) + 1
		else:
			if not bool(requirement.get("requirement_satisfied", false)):
				result["blocked_flow"] = int(result.get("blocked_flow", 0)) + 1
				result["blocked_region_share"] = int(result.get("blocked_region_share", 0)) + 1
				result["blocked_gap"] = int(result.get("blocked_gap", 0)) + maxi(0, int(requirement.get("required_share_percent", 0)) - int(floor(float(requirement.get("current_share_percent", 0.0)))))
			if cash < cash_cost:
				result["blocked_cash"] = int(result.get("blocked_cash", 0)) + 1
	return result
func _ai_route_inventory_adjustment(player_index: int, route_id: String, required: int, available: int, counted_hand: int, route_bonus: int, development_route_bonus: int) -> Dictionary:
	var inventory := _ai_route_hand_inventory(player_index, route_id)
	var total := int(inventory.get("total", 0))
	var playable := int(inventory.get("playable", 0))
	var blocked_flow := int(inventory.get("blocked_flow", 0))
	var blocked_gap := int(inventory.get("blocked_gap", 0))
	var adjustment := {
		"bonus": 0,
		"penalty": 0,
		"total": total,
		"playable": playable,
		"blocked_flow": blocked_flow,
		"blocked_gap": blocked_gap,
	}
	var candidate_playable := required <= 0 or available >= required
	if candidate_playable:
		if total > 0 and playable <= 0:
			adjustment["bonus"] = int(adjustment.get("bonus", 0)) + 42
		if blocked_flow > 0:
			adjustment["bonus"] = int(adjustment.get("bonus", 0)) + mini(64, 18 + blocked_gap * 10)
		if route_bonus > 0 or development_route_bonus > 0:
			adjustment["bonus"] = int(adjustment.get("bonus", 0)) + 18
	else:
		if blocked_flow > 0:
			adjustment["penalty"] = int(adjustment.get("penalty", 0)) + 46 + blocked_flow * 28 + blocked_gap * 12 + counted_hand * 8
		elif total >= 2:
			adjustment["penalty"] = int(adjustment.get("penalty", 0)) + 30 + total * 16
		if counted_hand >= PLAYER_HAND_LIMIT - 1:
			adjustment["penalty"] = int(adjustment.get("penalty", 0)) + 36
	return adjustment
func _ai_route_gap_adjustment(player_index: int, skill: Dictionary, district_index: int, product_name: String = "", target_owner: int = -999) -> Dictionary:
	var result := {
		"bonus": 0,
		"penalty": 0,
		"stage": "",
		"product": "",
		"field_match": 0,
		"reason": "",
	}
	var plan := _ai_refresh_route_plan(player_index)
	var plan_product := String(plan.get("product", ""))
	var stage := String(plan.get("stage", ""))
	if plan_product == "" or stage == "" or skill.is_empty():
		return result
	result["stage"] = stage
	result["product"] = plan_product
	var kind := String(skill.get("kind", ""))
	var resolved_owner := target_owner
	if resolved_owner == -999 and district_index >= 0 and district_index < districts.size():
		var city := _district_city(district_index)
		if _city_is_active(city):
			resolved_owner = int(city.get("owner", -1))
	var product_match := product_name == plan_product
	if not product_match:
		var contract_products_variant: Variant = skill.get("contract_products", [])
		if contract_products_variant is Array:
			product_match = (contract_products_variant as Array).has(plan_product)
	if not product_match and district_index >= 0:
		product_match = _ai_district_touches_product(district_index, plan_product)
	var field_match := 1 if product_match else 0
	var production_delta := int(skill.get("production_delta", 0)) + int(skill.get("accept_production_delta", 0))
	var transport_delta := int(skill.get("transport_delta", 0)) + int(skill.get("accept_transport_delta", 0))
	var consumption_delta := int(skill.get("consumption_delta", 0)) + int(skill.get("accept_consumption_delta", 0))
	var decline_pressure := maxi(0, -int(skill.get("decline_production_delta", 0))) + maxi(0, -int(skill.get("decline_transport_delta", 0))) + maxi(0, -int(skill.get("decline_consumption_delta", 0))) + int(skill.get("decline_route_damage", 0))
	var supply_boost := maxi(0, production_delta) + int(skill.get("contract_add_products", 0)) + int(skill.get("product_shift", 0))
	var demand_boost := maxi(0, consumption_delta) + int(skill.get("contract_add_demands", 0)) + int(skill.get("demand_shift", 0)) + int(ceil(float(maxi(0, int(skill.get("market_demand_pressure", 0)))) / 2.0))
	var traffic_boost := maxi(0, transport_delta) + int(skill.get("repair_routes", 0))
	var flow_multiplier := float(skill.get("route_flow_multiplier", 1.0))
	if flow_multiplier > 1.001:
		traffic_boost += maxi(1, int(round((flow_multiplier - 1.0) * 4.0)))
	var growth_boost := supply_boost + demand_boost + traffic_boost
	var derivative_terms := _city_gdp_derivative_terms(skill) if kind == "city_gdp_derivative" else {}
	growth_boost += int(float(int(skill.get("revenue_amount", 0))) / 55.0) + int(float(int(skill.get("contract_income", 0))) / 65.0) + int(float(maxi(0, int(skill.get("cash", 0)))) / 240.0)
	if float(skill.get("growth_multiplier", 1.0)) > 1.001:
		growth_boost += int(round((float(skill.get("growth_multiplier", 1.0)) - 1.0) * 3.0))
	if String(derivative_terms.get("direction", "")) == "up":
		growth_boost += maxi(1, int(round(float(derivative_terms.get("multiplier", 1.0)))))
	var insurance_strength := 0
	if bool(derivative_terms.get("insurance", false)):
		insurance_strength = maxi(1, int(round(float(derivative_terms.get("multiplier", 1.0))))) + int(float(int(derivative_terms.get("destroy_bonus", 0))) / 260.0)
	var pressure_strength := maxi(0, -production_delta) + maxi(0, -transport_delta) + maxi(0, -consumption_delta)
	pressure_strength += int(skill.get("route_damage", 0)) + int(skill.get("damage", 0)) + decline_pressure
	pressure_strength += int(float(int(skill.get("panic", 0))) / 22.0) + int(ceil(float(maxi(0, int(skill.get("market_supply_pressure", 0)))) / 2.0))
	if String(derivative_terms.get("direction", "")) == "down" and insurance_strength <= 0:
		pressure_strength += maxi(1, int(round(float(derivative_terms.get("multiplier", 1.0))))) + int(float(int(derivative_terms.get("destroy_bonus", 0))) / 240.0)
	pressure_strength += int(skill.get("hand_discard_count", 0)) + int(skill.get("hand_steal_count", 0)) * 2 + int(float(int(skill.get("control_gdp_penalty", 0))) / 45.0) + int(skill.get("global_barrage_damage", 0)) * maxi(1, int(skill.get("global_barrage_target_count", 0)))
	if ["monster_lure", "mudslide", "area_damage", "weather_control", "news_event", "route_sabotage", "panic_shift", "player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage"].has(kind):
		pressure_strength += 1
	var bonus := 0
	var penalty := 0
	var reasons := []
	if product_match:
		bonus += 24
	match stage:
		"build_supply":
			if supply_boost > 0:
				bonus += 84 + supply_boost * 42
				field_match += 2
				reasons.append("补供给")
			elif traffic_boost > 0 and resolved_owner == player_index:
				bonus += 28 + traffic_boost * 16
				reasons.append("供给城交通")
		"create_demand":
			if demand_boost > 0:
				bonus += 140 + demand_boost * 56
				field_match += 2
				reasons.append("补需求")
			elif traffic_boost > 0:
				bonus += 38 + traffic_boost * 20
				reasons.append("接通需求")
			elif supply_boost > 0:
				penalty += 180 + supply_boost * 60
				reasons.append("暂缓补供给")
		"strengthen_route":
			if growth_boost > 0:
				bonus += 58 + growth_boost * 24
				field_match += 1
				reasons.append("放大GDP")
			if traffic_boost > 0:
				bonus += 42 + traffic_boost * 24
				field_match += 1
				reasons.append("提速商路")
		"defend_route":
			var threat := _ai_product_route_threat_score(player_index, plan_product)
			if traffic_boost > 0 or int(skill.get("repair_routes", 0)) > 0 or kind == "route_insurance":
				bonus += 78 + (traffic_boost + int(skill.get("repair_routes", 0))) * 35 + mini(150, int(float(threat) / 2.0))
				field_match += 2
				reasons.append("修复/保险")
			if insurance_strength > 0 and resolved_owner == player_index:
				bonus += 84 + insurance_strength * 42 + mini(150, int(float(_ai_city_gdp_insurance_score(player_index, district_index)) / 4.0))
				field_match += 2
				reasons.append("GDP保单")
			if pressure_strength > 0 and resolved_owner == player_index:
				penalty += 60 + pressure_strength * 34
				reasons.append("避免自伤")
		"attack_rival":
			if pressure_strength > 0:
				bonus += 92 + pressure_strength * 38
				field_match += 2
				reasons.append("压制竞品")
			if resolved_owner >= 0 and resolved_owner != player_index:
				bonus += 54
				field_match += 1
				reasons.append("命中敌城")
	if resolved_owner == player_index and pressure_strength > 0 and stage != "attack_rival":
		penalty += pressure_strength * 26
	elif resolved_owner >= 0 and resolved_owner != player_index and growth_boost > 0 and stage != "attack_rival":
		penalty += growth_boost * 18
	if product_match and reasons.is_empty():
		reasons.append("商品吻合")
	result["bonus"] = maxi(0, bonus)
	result["penalty"] = maxi(0, penalty)
	result["field_match"] = field_match
	result["reason"] = "、".join(reasons)
	return result
func _ai_district_focus_score(player_index: int, district_index: int) -> int:
	var focus := _ai_focus_product(player_index)
	if focus == "" or district_index < 0 or district_index >= districts.size():
		return 0
	var score := 0
	if (districts[district_index].get("products", []) as Array).has(focus):
		score += AI_ECONOMIC_FOCUS_MATCH_BONUS + int(round(float(_product_price(focus)) / 4.0))
	if (districts[district_index].get("demands", []) as Array).has(focus):
		score += 48
	var city := _district_city(district_index)
	if _city_is_active(city):
		if _city_product_names(city).has(focus):
			score += 72
		if _city_demand_names(city).has(focus):
			score += 36
	return score
func _ai_product_for_skill(player_index: int, skill: Dictionary) -> String:
	var explicit := String(skill.get("play_product", ""))
	if explicit != "":
		return explicit
	var focus := _ai_focus_product(player_index)
	var route_product := _ai_route_plan_product(player_index)
	var kind := String(skill.get("kind", ""))
	var harmful_supply := int(skill.get("price_delta", 0)) < 0 or int(skill.get("market_supply_pressure", 0)) > int(skill.get("market_demand_pressure", 0))
	if harmful_supply:
		var rival_product := _ai_preferred_product(player_index, true)
		if rival_product != "":
			return rival_product
	if route_product != "" and (_player_product_flow(player_index, route_product) > 0 or ["product_speculation", "product_futures", "product_contract_boon", "product_growth_boon", "market_stabilize", "city_product_shift", "city_demand_shift", "region_economy_shift", "area_trade_contract", "news_event", "weather_control"].has(kind)):
		return route_product
	if focus != "" and (_player_product_flow(player_index, focus) > 0 or ["product_speculation", "product_futures", "product_contract_boon", "product_growth_boon", "market_stabilize", "city_product_shift", "city_demand_shift", "region_economy_shift", "news_event", "weather_control"].has(kind)):
		return focus
	return _skill_play_product(skill, player_index)
func _ai_first_alive_district() -> int:
	for i in range(districts.size()):
		if not bool(districts[i].get("destroyed", false)):
			return i
	return -1
func _ai_city_target_score(player_index: int, district_index: int, own_city: bool, prefer_damaged: bool = false) -> int:
	var city := _district_city(district_index)
	if not _city_is_active(city):
		return -1
	var is_owned := int(city.get("owner", -1)) == player_index
	if is_owned != own_city:
		return -1
	var score := 30
	score += int(city.get("last_income", 0))
	score += (city.get("products", []) as Array).size() * 28
	score += (city.get("demands", []) as Array).size() * 18
	score += (city.get("trade_routes", []) as Array).size() * 10
	score += int(city.get("competition_matches", 0)) * 8
	var warehouse_pressure := _city_warehouse_stockpile_pressure(city)
	if warehouse_pressure > 0:
		if prefer_damaged:
			score += warehouse_pressure
		elif own_city:
			score += int(float(warehouse_pressure) / 3.0)
		else:
			score += warehouse_pressure * 2
	var focus := _ai_focus_product(player_index)
	if focus != "":
		if _city_product_names(city).has(focus):
			score += 82 if own_city else 96
		if _city_demand_names(city).has(focus):
			score += 44 if own_city else 34
		if not own_city and _player_product_flow(player_index, focus) > 0 and _city_product_names(city).has(focus):
			score += 78
	if prefer_damaged:
		score += int(city.get("trade_route_damage", 0)) * 80
		score += int(districts[district_index].get("damage", 0)) * 20
	else:
		score -= int(city.get("trade_route_damage", 0)) * 6
	return score
func _ai_best_city_district(player_index: int, own_city: bool, prefer_damaged: bool = false) -> int:
	var best_index := -1
	var best_score := -1
	for district_index_variant in _active_city_district_indices():
		var district_index := int(district_index_variant)
		var score := _ai_city_target_score(player_index, district_index, own_city, prefer_damaged)
		if score > best_score:
			best_score = score
			best_index = district_index
	return best_index
func _ai_preferred_product(player_index: int, use_rivals: bool = false) -> String:
	var focus := _ai_focus_product(player_index)
	if focus != "":
		if not use_rivals and _player_product_flow(player_index, focus) > 0:
			return focus
		if use_rivals and not _competing_city_indices_for_product(player_index, focus).is_empty():
			return focus
	var scores := {}
	for district_index_variant in _active_city_district_indices():
		var district_index := int(district_index_variant)
		var city := _district_city(district_index)
		var is_owned := int(city.get("owner", -1)) == player_index
		if is_owned == use_rivals:
			continue
		for product_variant in _city_product_names(city):
			var product_name := String(product_variant)
			scores[product_name] = int(scores.get(product_name, 0)) + 50 + int(round(float(_product_price(product_name)) / 4.0))
		for demand_variant in _city_demand_names(city):
			var demand_name := String(demand_variant)
			scores[demand_name] = int(scores.get(demand_name, 0)) + 25 + int(round(float(_product_price(demand_name)) / 7.0))
	var best_product := ""
	var best_score := -1
	for product_variant in PRODUCT_CATALOG:
		var product_name := String(product_variant)
		var score := int(scores.get(product_name, 0))
		if score <= 0 and scores.is_empty():
			score = _product_price(product_name)
		if score > best_score:
			best_score = score
			best_product = product_name
	return best_product
func _ai_monster_card_landing_score(player_index: int, skill: Dictionary, district_index: int) -> int:
	if not _can_summon_monster_card_at_district(skill, district_index):
		return -1
	var score := 40
	var district: Dictionary = districts[district_index]
	var catalog_index := int(skill.get("catalog_index", 0))
	var template := _catalog_entry(catalog_index)
	var probe := {"resource_focus": (template.get("resource_focus", []) as Array).duplicate(true)}
	score += _monster_resource_match_score(probe, district_index) * 28
	for product_variant in district.get("products", []):
		score += int(round(float(_product_price(String(product_variant))) / 8.0))
	score += int(round(float(district.get("transport_score", 1.0)) * 15.0))
	score += _district_supply_card_ids(district_index).size() * 7
	var city := _district_city(district_index)
	if _city_is_active(city):
		if int(city.get("owner", -1)) == player_index:
			score -= 120
		else:
			score += 130 + int(city.get("last_income", 0))
	score -= int(district.get("damage", 0)) * 8
	return score
func _ai_best_monster_card_district(player_index: int, skill: Dictionary) -> int:
	var monster_name := String(skill.get("monster_name", ""))
	for actor_variant in auto_monsters:
		var actor: Dictionary = actor_variant
		if not bool(actor.get("down", false)) and int(actor.get("owner", -1)) == player_index and String(actor.get("name", "")) == monster_name and int(actor.get("rank", 1)) < 4:
			return int(actor.get("position", _ai_first_alive_district()))
	var best_index := -1
	var best_score := -1
	for i in range(districts.size()):
		var score := _ai_monster_card_landing_score(player_index, skill, i)
		if score > best_score:
			best_score = score
			best_index = i
	return best_index
func _ai_monster_target_for_skill(player_index: int, skill: Dictionary) -> int:
	var bound_uid := int(skill.get("bound_monster_uid", 0))
	if bound_uid > 0:
		var bound_slot := _auto_monster_slot_by_uid(bound_uid)
		if bound_slot >= 0 and not bool((auto_monsters[bound_slot] as Dictionary).get("down", false)):
			return bound_slot
	var kind := String(skill.get("kind", ""))
	var prefer_foreign := ["monster_lure", "special_monster_delay", "mudslide", "monster_takeover"].has(kind)
	var best_slot := -1
	var best_score := -1
	for slot in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[slot]
		if bool(actor.get("down", false)):
			continue
		var is_owned := int(actor.get("owner", -1)) == player_index
		if prefer_foreign and is_owned:
			continue
		if not prefer_foreign and not is_owned:
			continue
		var score := int(actor.get("rank", 1)) * 45 + int(actor.get("hp", 0)) + int(actor.get("armor", 0)) * 8
		if prefer_foreign:
			score += int(float(int(actor.get("owner_damage_cash_pool", 0))) / 20.0)
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot
func _ai_best_district_near_monster(player_index: int, monster_slot: int, range_limit: float = -1.0) -> int:
	if monster_slot < 0 or monster_slot >= auto_monsters.size():
		return _ai_best_city_district(player_index, false)
	var actor: Dictionary = auto_monsters[monster_slot]
	var best_index := -1
	var best_score := -1
	for i in range(districts.size()):
		if bool(districts[i].get("destroyed", false)):
			continue
		if range_limit > 0.0 and _entity_distance_to_district(actor, i) > range_limit:
			continue
		var score := _district_event_weight(i)
		var city := _district_city(i)
		if _city_is_active(city):
			score += 100 if int(city.get("owner", -1)) != player_index else -120
		if score > best_score:
			best_score = score
			best_index = i
	if best_index >= 0:
		return best_index
	return int(actor.get("position", _ai_first_alive_district()))
func _ai_city_product_overlap_score(player_index: int, target_city_index: int) -> int:
	var target_city := _district_city(target_city_index)
	if not _city_is_active(target_city):
		return 0
	var target_products := _city_product_names(target_city)
	var target_demands := _city_demand_names(target_city)
	var score := 0
	for own_city_index_variant in _active_city_indices_for_player(player_index):
		var own_city := _district_city(int(own_city_index_variant))
		for product_variant in _city_product_names(own_city):
			var product_name := String(product_variant)
			if target_products.has(product_name):
				score += 56 + int(round(float(_product_price(product_name)) / 8.0))
			if target_demands.has(product_name):
				score += 18
		for demand_variant in _city_demand_names(own_city):
			var demand_name := String(demand_variant)
			if target_products.has(demand_name):
				score += 26
	return score
func _ai_rival_city_pressure_score(player_index: int, district_index: int) -> int:
	if district_index < 0 or district_index >= districts.size() or bool(districts[district_index].get("destroyed", false)):
		return -1
	var city := _district_city(district_index)
	if not _city_is_active(city):
		return -1
	var city_owner := int(city.get("owner", -1))
	if city_owner == player_index:
		return -1
	var competition := _city_competition_matches(district_index)
	var breakdown := _city_cycle_income_breakdown(district_index, competition)
	var score := 150
	score += int(breakdown.get("net", 0))
	score += int(city.get("last_income", 0))
	score += _ai_city_product_overlap_score(player_index, district_index)
	score += (city.get("trade_routes", []) as Array).size() * 20
	score += _route_network_load_for_legacy_region(district_index) * 14
	score += _city_product_names(city).size() * 24
	score += _city_demand_names(city).size() * 14
	score += _city_warehouse_stockpile_pressure(city) * 2
	score += competition * 18
	score -= int(city.get("trade_route_damage", 0)) * 12
	score -= int(districts[district_index].get("damage", 0)) * 5
	if city_owner < 0:
		score -= 25
	return maxi(1, score)
func _ai_monster_lure_plan(player_index: int, _skill: Dictionary, range_limit: float = -1.0) -> Dictionary:
	var best := {}
	var best_score := -1
	for slot in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[slot]
		if bool(actor.get("down", false)):
			continue
		var actor_owner := int(actor.get("owner", -1))
		for city_index_variant in _active_city_district_indices():
			var city_index := int(city_index_variant)
			var attack_value := _ai_rival_city_pressure_score(player_index, city_index)
			if attack_value <= 0:
				continue
			var distance := _entity_distance_to_district(actor, city_index)
			if range_limit > 0.0 and distance > range_limit:
				continue
			var resource_match := _monster_resource_match_score(actor, city_index)
			var product_overlap := _ai_city_product_overlap_score(player_index, city_index)
			var score := attack_value
			score += product_overlap * 2
			if product_overlap > 0:
				score += 42
			score += resource_match * 70
			score += int(actor.get("rank", 1)) * 36
			score += int(float(int(actor.get("hp", 0))) / 2.0)
			score += _route_network_load_for_legacy_region(city_index) * 8
			score -= int(round(distance / 34.0))
			if actor_owner == player_index:
				score -= 28
			elif actor_owner >= 0:
				score += 36
			else:
				score += 12
			if int(actor.get("position", -1)) == city_index:
				score += 34
			if score <= best_score:
				continue
			var city := _district_city(city_index)
			var target_products := _city_product_names(city)
			var product_name := String(target_products[0]) if not target_products.is_empty() else _ai_preferred_product(player_index, true)
			best_score = score
			best = {
				"target_slot": slot,
				"district": city_index,
				"target_city": city_index,
				"target_owner": int(city.get("owner", -1)),
				"product": product_name,
				"score": maxi(1, score),
				"attack_value": attack_value,
				"resource_match": resource_match,
				"product_overlap": product_overlap,
				"distance_m": int(round(distance)),
				"strategic_role": "monster_lure",
				"reason": "诱导怪%d·%s压向%s｜城市价值%d｜竞品压力%d｜资源吻合%d｜距离%s" % [
					slot + 1,
					String(actor.get("name", "怪兽")),
					String(districts[city_index].get("name", "竞争城市")),
					attack_value,
					product_overlap,
					resource_match,
					_meters_text(distance),
				],
			}
	return best
func _ai_monster_delay_plan(player_index: int, _skill: Dictionary) -> Dictionary:
	var best := {}
	var best_score := -1
	for slot in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[slot]
		if bool(actor.get("down", false)) or int(actor.get("owner", -1)) == player_index:
			continue
		for city_index_variant in _active_city_indices_for_player(player_index):
			var city_index := int(city_index_variant)
			var city_score := _ai_city_target_score(player_index, city_index, true, false)
			if city_score <= 0:
				continue
			var distance := _entity_distance_to_district(actor, city_index)
			var resource_match := _monster_resource_match_score(actor, city_index)
			var score := 72 + city_score + resource_match * 42 + int(actor.get("rank", 1)) * 25 - int(round(distance / 28.0))
			if score <= best_score:
				continue
			best_score = score
			best = {
				"target_slot": slot,
				"district": city_index,
				"target_city": city_index,
				"target_owner": player_index,
				"score": maxi(1, score),
				"attack_value": city_score,
				"resource_match": resource_match,
				"distance_m": int(round(distance)),
				"strategic_role": "monster_delay",
				"reason": "延后怪%d·%s接近己方%s｜防守价值%d｜距离%s" % [
					slot + 1,
					String(actor.get("name", "怪兽")),
					String(districts[city_index].get("name", "城市")),
					city_score,
					_meters_text(distance),
				],
			}
	return best
func _ai_card_kind_bias(player_index: int, kind: String) -> float:
	var profile := _ai_profile_for_player(player_index)
	if kind == "card_counter":
		return maxf(float(profile.get("business_bias", 1.0)), float(profile.get("economy_bias", 1.0))) * 0.86
	if kind == "military_force" or kind == "military_command":
		return (float(profile.get("monster_bias", 1.0)) + float(profile.get("business_bias", 1.0))) * 0.5
	if kind == "monster_card" or kind == "monster_bound_action" or _skill_targets_monster({"kind": kind}):
		return float(profile.get("monster_bias", 1.0))
	if ["route_sabotage", "panic_shift", "monster_takeover", "mudslide", "special_monster_delay"].has(kind):
		return float(profile.get("business_bias", 1.0))
	return float(profile.get("economy_bias", 1.0))
func _ai_counter_entry_target_city(entry: Dictionary) -> int:
	var district_index := int(entry.get("selected_district", -1))
	if district_index >= 0 and district_index < districts.size() and _city_is_active(_district_city(district_index)):
		return district_index
	return -1
func _ai_counter_entry_target_owner(entry: Dictionary) -> int:
	var target_player := int(entry.get("target_player", -1))
	if target_player >= 0 and target_player < players.size():
		return target_player
	var target_city := _ai_counter_entry_target_city(entry)
	if target_city >= 0:
		return int(_district_city(target_city).get("owner", -1))
	return -1
func _ai_counter_nearest_owned_city_pressure(player_index: int, district_index: int) -> int:
	if district_index < 0 or district_index >= districts.size():
		return 0
	var best := 0
	for city_variant in _active_city_indices_for_player(player_index):
		var city_index := int(city_variant)
		var distance := _wrapped_distance(_district_center(city_index), _district_center(district_index))
		var score := maxi(0, 220 - int(round(distance))) + int(float(_ai_city_target_score(player_index, city_index, true, true)) / 4.0)
		if score > best:
			best = score
	return best
func _ai_counter_target_threat(player_index: int, target_entry: Dictionary) -> Dictionary:
	if target_entry.is_empty():
		return {"score": -999999, "reason_key": "no_target", "summary": "没有可反制目标。"}
	var skill: Dictionary = target_entry.get("skill", {}) as Dictionary
	if skill.is_empty() or _is_counter_skill(skill):
		return {"score": -999999, "reason_key": "not_counterable", "summary": "当前牌不可反制。"}
	if not _skill_is_counterable_player_interaction(skill):
		return {"score": -999999, "reason_key": "not_player_interaction", "summary": "相位否决只响应直接玩家互动牌。"}
	if int(target_entry.get("player_index", -1)) == player_index:
		return {"score": -999999, "reason_key": "own_card", "summary": "AI不会反制自己已经提交的匿名牌。"}
	var kind := String(skill.get("kind", ""))
	var derivative_terms := _city_gdp_derivative_terms(skill) if kind == "city_gdp_derivative" else {}
	var district_index := int(target_entry.get("selected_district", -1))
	var target_player := int(target_entry.get("target_player", -1))
	var target_owner := _ai_counter_entry_target_owner(target_entry)
	var own_city_target := target_owner == player_index
	var rival_city_target := target_owner >= 0 and target_owner != player_index
	var direct_self_target := target_player == player_index
	var phase_info := _ai_refresh_game_phase(player_index)
	var leader_index := int(phase_info.get("leader_index", -1))
	var posture := String(phase_info.get("posture", "contesting"))
	var score := 0
	var reasons := []
	if direct_self_target:
		var direct_pressure := int(skill.get("hand_discard_count", 0)) * 165 \
			+ int(skill.get("hand_steal_count", 0)) * 215 \
			+ int(round(float(skill.get("hand_lock_seconds", 0.0)) * 8.0))
		if direct_pressure > 0:
			score += direct_pressure + 80
			reasons.append("直接打击自己+%d" % (direct_pressure + 80))
	if own_city_target:
		var city := _district_city(district_index)
		var negative_delta := maxi(0, -int(skill.get("production_delta", 0))) \
			+ maxi(0, -int(skill.get("transport_delta", 0))) \
			+ maxi(0, -int(skill.get("consumption_delta", 0))) \
			+ maxi(0, -int(skill.get("accept_production_delta", 0))) \
			+ maxi(0, -int(skill.get("accept_transport_delta", 0))) \
			+ maxi(0, -int(skill.get("accept_consumption_delta", 0)))
		var route_damage := maxi(0, int(skill.get("route_damage", 0))) \
			+ maxi(0, int(skill.get("decline_route_damage", 0))) \
			+ maxi(0, int(skill.get("global_barrage_route_damage", 0))) \
			+ maxi(0, int(skill.get("military_strike_route_damage", 0)))
		var area_damage := maxi(0, int(skill.get("damage", 0))) + maxi(0, int(skill.get("global_barrage_damage", 0)))
		var city_pressure := negative_delta * 128 + route_damage * 132 + area_damage * 118
		city_pressure += maxi(0, int(skill.get("control_gdp_penalty", 0))) * 3
		city_pressure += int(float(maxi(0, int(skill.get("decline_cash_penalty", 0)))) / 2.0)
		city_pressure += _city_warehouse_stockpile_pressure(city)
		city_pressure += int(float(_ai_city_target_score(player_index, district_index, true, true)) / 3.0)
		if city_pressure > 0:
			score += city_pressure
			reasons.append("保护己城+%d" % city_pressure)
		if String(derivative_terms.get("direction", "")) == "down" and float(derivative_terms.get("multiplier", 0.0)) > 0.0:
			var gdp_short_pressure := 175 + int(round(float(derivative_terms.get("multiplier", 1.0)) * 90.0)) + int(float(int(derivative_terms.get("destroy_bonus", 0))) / 8.0)
			score += gdp_short_pressure
			reasons.append("阻止己城做空+%d" % gdp_short_pressure)
	if rival_city_target:
		var positive_delta := maxi(0, int(skill.get("production_delta", 0))) \
			+ maxi(0, int(skill.get("transport_delta", 0))) \
			+ maxi(0, int(skill.get("consumption_delta", 0))) \
			+ maxi(0, int(skill.get("accept_production_delta", 0))) \
			+ maxi(0, int(skill.get("accept_transport_delta", 0))) \
			+ maxi(0, int(skill.get("accept_consumption_delta", 0)))
		var rival_boost := positive_delta * 78 \
			+ int(float(int(skill.get("revenue_amount", 0))) / 3.0) \
			+ int(float(int(skill.get("contract_income", 0))) / 4.0) \
			+ maxi(0, int(skill.get("repair_routes", 0))) * 64
		var flow_multiplier := float(skill.get("route_flow_multiplier", skill.get("accept_route_flow_multiplier", 1.0)))
		if flow_multiplier > 1.001:
			rival_boost += int(round((flow_multiplier - 1.0) * 160.0))
		if String(derivative_terms.get("direction", "")) == "up" and float(derivative_terms.get("multiplier", 0.0)) > 0.0:
			rival_boost += 110 + int(round(float(derivative_terms.get("multiplier", 1.0)) * 72.0))
		if target_owner == leader_index and leader_index != player_index:
			rival_boost += 70 + int(float(_ai_endgame_urgency_score(player_index)) / 2.0)
		if posture == "trailing":
			rival_boost += 35
		if rival_boost > 0:
			score += rival_boost
			reasons.append("阻止竞品增益+%d" % rival_boost)
	if kind == "monster_card":
		var monster_pressure := int(skill.get("hp", 0)) * 2 \
			+ int(skill.get("fixed_skill_count", 0)) * 48 \
			+ maxi(1, _skill_rank(String(skill.get("name", "")))) * 74 \
			+ int(float(_ai_counter_nearest_owned_city_pressure(player_index, district_index)) / 2.0)
		if monster_pressure > 0:
			score += monster_pressure
			reasons.append("阻止新怪兽+%d" % monster_pressure)
	elif kind == "monster_lure" or kind == "special_monster_delay":
		var monster_impact := maxi(0, int(skill.get("damage", 0))) * 72 \
			+ int(round(float(skill.get("lure_speedup", 0.0)) * 30.0)) \
			+ _ai_counter_nearest_owned_city_pressure(player_index, district_index)
		if monster_impact > 0:
			score += monster_impact
			reasons.append("阻止怪兽压线+%d" % monster_impact)
	elif kind == "global_barrage":
		var own_city_count := _active_city_indices_for_player(player_index).size()
		var barrage_pressure := own_city_count * maxi(1, int(skill.get("global_barrage_target_count", 1))) * (int(skill.get("global_barrage_damage", 0)) * 44 + int(skill.get("global_barrage_route_damage", 0)) * 36)
		if own_city_target:
			barrage_pressure += 90
		if barrage_pressure > 0:
			score += barrage_pressure
			reasons.append("压制全场齐射+%d" % barrage_pressure)
	elif kind == "area_trade_contract" and own_city_target:
		var contract_pressure := int(float(maxi(0, int(skill.get("decline_cash_penalty", 0)))) / 2.0) \
			+ maxi(0, int(skill.get("decline_route_damage", 0))) * 90 \
			+ maxi(0, -int(skill.get("decline_transport_delta", 0))) * 80 \
			+ maxi(0, -int(skill.get("decline_consumption_delta", 0))) * 70
		if contract_pressure > 0:
			score += contract_pressure
			reasons.append("拆解惩罚合约+%d" % contract_pressure)
	elif kind == "weather_control":
		var weather_pressure := int(float(_ai_counter_nearest_owned_city_pressure(player_index, district_index)) / 2.0) + int(skill.get("weather_zone_count", 1)) * 28
		if own_city_target:
			weather_pressure += 75
		if weather_pressure > 0:
			score += weather_pressure
			reasons.append("阻止天气改写+%d" % weather_pressure)
	if reasons.is_empty():
		reasons.append("公开字段威胁较低")
	return {
		"score": score,
		"reason_key": "self_defense" if own_city_target or direct_self_target else ("leader_denial" if target_owner == leader_index and leader_index != player_index else ("rival_boost_denial" if rival_city_target else kind)),
		"summary": "；".join(reasons),
		"target_owner": target_owner,
		"target_city": district_index,
	}
func _ai_counter_opportunity_cost(source_skill: Dictionary, counter_skill: Dictionary) -> int:
	var counter_rank := maxi(1, _skill_rank(String(counter_skill.get("name", source_skill.get("name", "")))))
	var cost := 70 + counter_rank * 34 + int(counter_skill.get("counter_strength", 1)) * 24
	cost += int(counter_skill.get("cost", 0)) * 9
	cost -= int(float(int(counter_skill.get("counter_refund", 0))) / 4.0) + int(counter_skill.get("counter_trace", 0)) * 28
	if String(source_skill.get("kind", "")) == "monster_card":
		var source_rank := maxi(1, _skill_rank(String(source_skill.get("name", ""))))
		cost += 185 + source_rank * 76 + int(float(int(source_skill.get("hp", 0))) / 3.0) + int(source_skill.get("fixed_skill_count", 0)) * 46
	return maxi(35, cost)
func _ai_counter_response_candidate(player_index: int, slot_index: int, source_skill: Dictionary, target_entry: Dictionary = {}) -> Dictionary:
	if not _player_is_ai(player_index):
		return {}
	if _card_resolution_active_entry().is_empty() or not card_resolution_counter_window_active:
		return {}
	if _queued_card_entry_index_for_player(player_index) >= 0 or _next_batch_card_entry_index_for_player(player_index) >= 0:
		return {}
	var entry := _card_resolution_active_entry() if target_entry.is_empty() else target_entry
	if not _card_can_open_counter_window(entry):
		return {}
	var counter_skill := _counter_skill_for_ai_candidate(player_index, source_skill)
	if counter_skill.is_empty():
		return {}
	if not _can_play_skill_now(player_index, counter_skill, false):
		return {}
	var threat := _ai_counter_target_threat(player_index, entry)
	var threat_score := int(threat.get("score", -999999))
	if threat_score <= 0:
		return {}
	var counter_strength := maxi(1, int(counter_skill.get("counter_strength", 1)))
	var opportunity_cost := _ai_counter_opportunity_cost(source_skill, counter_skill)
	var phase_info := _ai_refresh_game_phase(player_index)
	var score := threat_score + counter_strength * 38 + int(float(int(counter_skill.get("counter_refund", 0))) / 2.0) + int(counter_skill.get("counter_trace", 0)) * 64 - opportunity_cost
	if String(phase_info.get("posture", "contesting")) == "leader" and String(threat.get("reason_key", "")) == "self_defense":
		score += 56
	elif String(phase_info.get("posture", "contesting")) == "trailing" and String(threat.get("reason_key", "")) != "self_defense":
		score += 44
	score += int(float(_ai_endgame_urgency_score(player_index)) / 4.0)
	if score < AI_COUNTER_RESPONSE_MIN_SCORE:
		return {}
	var card_name := String(source_skill.get("name", "相位否决"))
	var counter_name := String(counter_skill.get("name", "相位否决"))
	var converts_monster := not _is_counter_skill(source_skill)
	var product_name := _skill_play_product(counter_skill, player_index)
	var learning_bonus := clampi(
		_ai_learning_bonus(player_index, "counter_response", String(_ai_strategy_intent(player_index)), String(_ai_route_plan_stage(player_index)), product_name, "相位反制"),
		-AI_LEARNING_BONUS_CLAMP,
		AI_LEARNING_BONUS_CLAMP
	)
	if learning_bonus != 0:
		score += learning_bonus
	return {
		"action": "相位反制",
		"slot_index": slot_index,
		"card_name": card_name,
		"kind": String(counter_skill.get("kind", "card_counter")),
		"policy_kind": "counter_response",
		"district": int(entry.get("selected_district", _ai_first_alive_district())),
		"target_slot": -1,
		"target_player": int(entry.get("target_player", -1)),
		"target_city": int(threat.get("target_city", -1)),
		"target_owner": int(threat.get("target_owner", -1)),
		"product": product_name,
		"score": maxi(1, score),
		"counter_target_resolution_id": int(entry.get("resolution_id", entry.get("queued_order", -1))),
		"counter_target_card": _card_resolution_entry_card_label(entry),
		"counter_strength": counter_strength,
		"counter_threat_score": threat_score,
		"counter_opportunity_cost": opportunity_cost,
		"counter_reason_key": String(threat.get("reason_key", "")),
		"counter_source_card": card_name if converts_monster else "",
		"counter_converted_monster": converts_monster,
		"counter_card_name": counter_name,
		"game_phase": String(phase_info.get("phase", "midgame")),
		"competitive_posture": String(phase_info.get("posture", "contesting")),
		"score_gap_to_leader": int(phase_info.get("gap", 0)),
		"leader_index": int(phase_info.get("leader_index", -1)),
		"endgame_urgency": _ai_endgame_urgency_score(player_index),
		"learning_bonus": learning_bonus,
		"reason": "%s%s｜目标:%s｜威胁%d｜机会成本%d｜强度%d｜%s" % [
			"怪兽牌改写为" if converts_monster else "",
			_card_display_name(counter_name),
			_card_resolution_entry_card_label(entry),
			threat_score,
			opportunity_cost,
			counter_strength,
			String(threat.get("summary", "")),
		],
	}
func _ai_weather_city_value(player_index: int, district_index: int) -> int:
	if district_index < 0 or district_index >= districts.size():
		return 0
	var city := _district_city(district_index)
	if not _city_is_active(city):
		return 0
	var city_owner := int(city.get("owner", -1))
	if city_owner == player_index:
		return maxi(1, _ai_city_target_score(player_index, district_index, true, true))
	if city_owner >= 0:
		return maxi(1, _ai_rival_city_pressure_score(player_index, district_index))
	var income := int(city.get("last_income", _city_cycle_income(district_index, _city_competition_matches(district_index))))
	return maxi(1, 100 + income + _route_network_load_for_legacy_region(district_index) * 16)
func _ai_weather_city_effect(player_index: int, district_index: int, type_id: String) -> Dictionary:
	var city := _district_city(district_index)
	if not _city_is_active(city):
		return {"score": 0, "owner": -1, "positive": 0, "negative": 0, "value": 0}
	var template := _weather_template(type_id)
	var production_multiplier := float(template.get("production_multiplier", 1.0))
	var transport_multiplier := float(template.get("route_efficiency_multiplier", template.get("transport_multiplier", 1.0)))
	if String(districts[district_index].get("terrain", "land")) == "ocean":
		transport_multiplier *= float(template.get("ocean_movement_multiplier", 1.0))
	var consumption_multiplier := float(template.get("demand_multiplier", 1.0))
	var route_load := _route_network_load_for_legacy_region(district_index)
	var product_weight := 110 + _city_product_names(city).size() * 34 + int(float(int(city.get("last_income", 0))) / 10.0)
	var transport_weight := 120 + route_load * 48 + (_route_network_routes_for_legacy_region(district_index) as Array).size() * 36 + int(round(float(districts[district_index].get("transport_score", 1.0)) * 28.0))
	var consumption_weight := 92 + _city_demand_names(city).size() * 30
	var positive := int(round(maxf(0.0, production_multiplier - 1.0) * product_weight * 5.0)) \
		+ int(round(maxf(0.0, transport_multiplier - 1.0) * transport_weight * 5.0)) \
		+ int(round(maxf(0.0, consumption_multiplier - 1.0) * consumption_weight * 5.0))
	var negative := int(round(maxf(0.0, 1.0 - production_multiplier) * product_weight * 5.0)) \
		+ int(round(maxf(0.0, 1.0 - transport_multiplier) * transport_weight * 5.0)) \
		+ int(round(maxf(0.0, 1.0 - consumption_multiplier) * consumption_weight * 5.0))
	var city_owner := int(city.get("owner", -1))
	var city_value := _ai_weather_city_value(player_index, district_index)
	var score := 0
	if city_owner == player_index:
		score = positive * 3 - negative * 4
		score += int(float(city_value) / 5.0) if positive >= negative else -int(float(city_value) / 6.0)
	elif city_owner >= 0:
		score = negative * 4 - positive * 5
		score += int(float(city_value) / 6.0) if negative > positive else -int(float(city_value) / 8.0)
	else:
		score = negative * 2 - positive + int(float(city_value) / 10.0)
	return {
		"score": score,
		"owner": city_owner,
		"positive": positive,
		"negative": negative,
		"value": city_value,
		"route_load": route_load,
	}
func _ai_weather_empty_district_effect(player_index: int, district_index: int, type_id: String) -> int:
	if district_index < 0 or district_index >= districts.size():
		return 0
	var template := _weather_template(type_id)
	var terrain := String(districts[district_index].get("terrain", "land"))
	var transport_multiplier := float(template.get("route_efficiency_multiplier", template.get("transport_multiplier", 1.0)))
	if terrain == "ocean":
		transport_multiplier *= float(template.get("ocean_movement_multiplier", 1.0))
	var route_load := _route_network_load_for_legacy_region(district_index)
	var score := 0
	if terrain == "ocean" and transport_multiplier > 1.001:
		score += 48 + int(round((transport_multiplier - 1.0) * 220.0)) + route_load * 42
	elif transport_multiplier < 0.999 and route_load > 0:
		score += int(round((1.0 - transport_multiplier) * 180.0)) + route_load * 18
	var focus := _ai_focus_product(player_index)
	var route_product := _ai_route_plan_product(player_index)
	for product_variant in districts[district_index].get("products", []):
		var product_name := String(product_variant)
		if product_name != "" and (product_name == focus or product_name == route_product):
			score += 28
	for demand_variant in districts[district_index].get("demands", []):
		var demand_name := String(demand_variant)
		if demand_name != "" and (demand_name == focus or demand_name == route_product):
			score += 22
	return score
func _ai_weather_control_plan(player_index: int, skill: Dictionary) -> Dictionary:
	if String(skill.get("kind", "")) != "weather_control":
		return {}
	var weather_type_ids := _weather_type_ids()
	if weather_type_ids.is_empty():
		return {}
	var type_id := String(skill.get("weather_type", ""))
	if not weather_type_ids.has(type_id):
		type_id = str(weather_type_ids[0])
	var zone_count := clampi(int(skill.get("weather_zone_count", _weather_zone_count_for_planet())), 1, WEATHER_ZONE_MAX)
	var best := {}
	var best_score := -999999
	var phase_info := _ai_refresh_game_phase(player_index)
	var posture := String(phase_info.get("posture", "contesting"))
	var route_product := _ai_route_plan_product(player_index)
	var focus_product := _ai_focus_product(player_index)
	for anchor_variant in _alive_district_indices():
		var anchor := int(anchor_variant)
		var covered := _weather_preview_districts(anchor, zone_count)
		if covered.is_empty():
			continue
		var own_value := 0
		var rival_value := 0
		var neutral_value := 0
		var route_load := 0
		var covered_cities := 0
		var best_city := -1
		var best_city_score := -999999
		var best_owner := -1
		var terrain_bonus := 0
		var product_bonus := 0
		for covered_variant in covered:
			var district_index := int(covered_variant)
			route_load += _route_network_load_for_legacy_region(district_index)
			if String(districts[district_index].get("terrain", "land")) == "ocean":
				var weather_template := _weather_template(type_id)
				var ocean_transport := float(weather_template.get("route_efficiency_multiplier", weather_template.get("transport_multiplier", 1.0))) * float(weather_template.get("ocean_movement_multiplier", 1.0))
				if ocean_transport > 1.001:
					terrain_bonus += 58 + int(round((ocean_transport - 1.0) * 180.0))
				elif ocean_transport < 0.999:
					terrain_bonus += 20
			var empty_score := _ai_weather_empty_district_effect(player_index, district_index, type_id)
			neutral_value += empty_score
			var city := _district_city(district_index)
			if _city_is_active(city):
				covered_cities += 1
				var city_effect := _ai_weather_city_effect(player_index, district_index, type_id)
				var city_owner := int(city_effect.get("owner", -1))
				var city_score := int(city_effect.get("score", 0))
				if city_owner == player_index:
					own_value += city_score
				elif city_owner >= 0:
					rival_value += city_score
				else:
					neutral_value += int(float(city_score) / 2.0)
				if city_score > best_city_score:
					best_city_score = city_score
					best_city = district_index
					best_owner = city_owner
				for product_variant in _city_product_names(city):
					var product_name := String(product_variant)
					if product_name != "" and (product_name == route_product or product_name == focus_product):
						product_bonus += 44
				for demand_variant in _city_demand_names(city):
					var demand_name := String(demand_variant)
					if demand_name != "" and (demand_name == route_product or demand_name == focus_product):
						product_bonus += 32
		var template := _weather_template(type_id)
		var transport_multiplier := float(template.get("route_efficiency_multiplier", template.get("transport_multiplier", 1.0)))
		var production_multiplier := float(template.get("production_multiplier", 1.0))
		var consumption_multiplier := float(template.get("demand_multiplier", 1.0))
		var role := "weather_pressure"
		var score := 80 + zone_count * 20 + route_load * 12 + product_bonus
		var helpful_bias := maxi(0, own_value) + maxi(0, int(float(neutral_value) / 2.0))
		var harmful_bias := maxi(0, rival_value)
		if transport_multiplier > 1.001 or production_multiplier > 1.001 or consumption_multiplier > 1.001:
			score += helpful_bias + terrain_bonus
			if helpful_bias + terrain_bonus >= harmful_bias:
				role = "boost_own_route"
			else:
				score += int(float(harmful_bias) / 2.0)
				role = "deny_rival_route"
		if production_multiplier < 0.999 or transport_multiplier < 0.999 or consumption_multiplier < 0.999:
			score += harmful_bias
			if harmful_bias > helpful_bias:
				role = "suppress_rival_city"
			else:
				score -= int(float(maxi(0, -own_value)) / 2.0)
		if posture == "leader" and role == "boost_own_route":
			score += 45
		elif posture == "trailing" and role != "boost_own_route":
			score += 58
		if best_city < 0:
			best_city = anchor
			best_owner = -1
		if score > best_score:
			best_score = score
			best = {
				"policy_kind": "weather_control_%s" % type_id,
				"district": anchor,
				"target_city": best_city,
				"target_owner": best_owner,
				"score": maxi(1, score),
				"weather_type": type_id,
				"weather_plan_role": role,
				"weather_plan_score": maxi(1, score),
				"weather_zone_count": zone_count,
				"weather_target_terrain": String(districts[anchor].get("terrain", "land")),
				"weather_covered_cities": covered_cities,
				"weather_route_load": route_load,
				"weather_own_value": own_value,
				"weather_rival_value": rival_value,
				"weather_neutral_value": neutral_value,
				"weather_product_bonus": product_bonus,
				"weather_terrain_bonus": terrain_bonus,
				"product": String(skill.get("play_product", focus_product if focus_product != "" else route_product)),
				"reason": "天气规划｜%s｜%s｜锚点%s｜覆盖%d区/%d城｜己方%d｜竞品%d｜商路%d｜商品%d" % [
					_weather_label(type_id),
					role,
					String(districts[anchor].get("name", "区域")),
					covered.size(),
					covered_cities,
					own_value,
					rival_value,
					route_load,
					product_bonus,
				],
			}
	return best
func _ai_city_gdp_insurance_score(player_index: int, district_index: int) -> int:
	if district_index < 0 or district_index >= districts.size():
		return -1
	var city := _district_city(district_index)
	if not _city_is_active(city) or int(city.get("owner", -1)) != player_index:
		return -1
	var last_income := int(city.get("last_income", _city_cycle_income(district_index, _city_competition_matches(district_index))))
	var damage := int(districts[district_index].get("damage", 0))
	var disrupted := int(city.get("trade_disrupted_routes", 0)) + int(city.get("trade_route_damage", 0))
	var score := 90 + maxi(0, last_income)
	score += damage * 58 + disrupted * 72 + int(float(int(districts[district_index].get("panic", 0))) / 2.0)
	score += _city_warehouse_stockpile_pressure(city)
	score += int(float(_auto_build_monster_risk_score(district_index)) / 2.0)
	score += _route_network_load_for_legacy_region(district_index) * 12
	score += _ai_district_focus_score(player_index, district_index)
	return score
func _ai_best_city_for_gdp_insurance(player_index: int) -> int:
	var best_index := -1
	var best_score := -1
	for index_variant in _active_city_indices_for_player(player_index):
		var index := int(index_variant)
		var score := _ai_city_gdp_insurance_score(player_index, index)
		if score > best_score:
			best_score = score
			best_index = index
	return best_index
func _ai_best_city_for_gdp_derivative(player_index: int, direction: String, skill: Dictionary = {}) -> int:
	if bool(_city_gdp_derivative_terms(skill).get("insurance", false)):
		return _ai_best_city_for_gdp_insurance(player_index)
	var best_index := -1
	var best_score := -999999
	for index_variant in _active_city_district_indices():
		var index := int(index_variant)
		var city := _district_city(index)
		var city_owner := int(city.get("owner", -1))
		var last_income := int(city.get("last_income", _city_cycle_income(index, _city_competition_matches(index))))
		var damage := int(districts[index].get("damage", 0))
		var disrupted := int(city.get("trade_disrupted_routes", 0)) + int(city.get("trade_route_damage", 0))
		var warehouse_pressure := _city_warehouse_stockpile_pressure(city)
		var score := last_income
		if direction == "up":
			score += 180 if city_owner == player_index else 30
			score += _ai_district_focus_score(player_index, index)
			score -= damage * 34 + disrupted * 42
			if city_owner == player_index:
				score += int(float(warehouse_pressure) / 4.0)
		else:
			score += 150 if city_owner >= 0 and city_owner != player_index else -40
			score += damage * 52 + disrupted * 62 + int(float(int(districts[index].get("panic", 0))) / 2.0)
			score += int(float(_ai_district_focus_score(player_index, index)) / 3.0)
			if city_owner >= 0 and city_owner != player_index:
				score += warehouse_pressure * 2
			elif city_owner == player_index:
				score -= int(float(warehouse_pressure) / 2.0)
		if score > best_score:
			best_score = score
			best_index = index
	return best_index
func _ai_product_futures_direction_label(direction: String) -> String:
	match direction:
		"down":
			return "看跌"
	return "看涨"
func _ai_product_futures_policy_kind(skill: Dictionary) -> String:
	var terms := _product_futures_terms(skill)
	if bool(terms.get("requires_warehouse", false)):
		return "product_futures_stockpile"
	return "product_futures_%s" % String(terms.get("direction", "up"))
func _ai_product_futures_product_score(player_index: int, skill: Dictionary, product_name: String) -> int:
	if product_name == "" or not PRODUCT_CATALOG.has(product_name):
		return -999999
	var terms := _product_futures_terms(skill)
	if terms.is_empty():
		return -999999
	var direction := String(terms.get("direction", "up"))
	var scores := _product_strategy_scores(product_name)
	var stockpile_required := bool(terms.get("requires_warehouse", false))
	var market_score := int(scores.get("short", 0)) if direction == "down" else int(scores.get("long", 0))
	if stockpile_required:
		market_score = maxi(market_score, int(scores.get("stockpile", 0)))
	var required := _skill_play_flow_required(skill, player_index)
	var flow := _player_product_flow(player_index, product_name)
	var pressure_score := int(skill.get("market_supply_pressure", 0)) * 34 if direction == "down" else int(skill.get("market_demand_pressure", 0)) * 34
	var multiplier_score := int(round(maxf(0.1, float(terms.get("multiplier", 1.0))) * 72.0))
	var unit_score := maxi(1, int(terms.get("units", 1))) * (38 if stockpile_required else 18)
	var margin_cash := maxi(1, int(terms.get("margin_cash", 1)))
	var maximum_gain := maxi(0, int(terms.get("maximum_gain", 0)))
	var maximum_loss := maxi(0, int(terms.get("maximum_loss", 0)))
	var risk_adjusted_ev := int(round(float(maximum_gain) * 0.55 - float(maximum_loss) * 0.45))
	var capital_efficiency := int(round(float(risk_adjusted_ev) * 100.0 / float(margin_cash)))
	var lock_penalty := int(round(_product_futures_duration_seconds(skill) / 3.0)) + (46 if stockpile_required else 18)
	var score := market_score * 2 + pressure_score + multiplier_score + unit_score + int(float(risk_adjusted_ev) / 3.0) + capital_efficiency - lock_penalty
	score += flow * 36
	if required > 0 and flow < required:
		score -= (required - flow) * 140
	var focus := _ai_focus_product(player_index)
	if product_name == focus and focus != "":
		score += 95
	var route_product := _ai_route_plan_product(player_index)
	if product_name == route_product and route_product != "":
		score += 80
	if _ai_product_rival_city_count(player_index, product_name) > 0 and direction == "down":
		score += 62
	return score
func _ai_product_for_futures_skill(player_index: int, skill: Dictionary, preferred_product: String = "") -> String:
	var candidates := []
	var seen := {}
	var required := _skill_play_flow_required(skill, player_index)
	for product_variant in [preferred_product, _ai_route_plan_product(player_index), _ai_focus_product(player_index), _best_player_flow_product(player_index, required, [preferred_product]), _ai_preferred_product(player_index), _ai_preferred_product(player_index, true), _skill_play_product(skill, player_index)]:
		var product_name := String(product_variant)
		if product_name == "" or seen.has(product_name) or not PRODUCT_CATALOG.has(product_name):
			continue
		seen[product_name] = true
		candidates.append(product_name)
	for product_variant in PRODUCT_CATALOG:
		var catalog_product := String(product_variant)
		if catalog_product == "" or seen.has(catalog_product):
			continue
		if required > 0 and _player_product_flow(player_index, catalog_product) < required:
			continue
		seen[catalog_product] = true
		candidates.append(catalog_product)
	if candidates.is_empty():
		for product_variant in PRODUCT_CATALOG:
			var fallback_product := String(product_variant)
			if fallback_product != "" and not seen.has(fallback_product):
				seen[fallback_product] = true
				candidates.append(fallback_product)
	var best_product := ""
	var best_score := -999999
	for candidate_variant in candidates:
		var candidate_product := String(candidate_variant)
		var score := _ai_product_futures_product_score(player_index, skill, candidate_product)
		if score > best_score:
			best_score = score
			best_product = candidate_product
	return best_product
func _ai_best_warehouse_city_for_product(player_index: int, product_name: String) -> int:
	var best_index := -1
	var best_score := -999999
	for index_variant in _active_city_indices_for_player(player_index):
		var index := int(index_variant)
		var city := _district_city(index)
		var score := 80 + _ai_city_target_score(player_index, index, true, false)
		if _city_product_names(city).has(product_name):
			score += 130
		if _city_demand_names(city).has(product_name):
			score += 92
		score += int(float(int(city.get("last_income", 0))) / 4.0)
		score += int(round(float(districts[index].get("transport_score", 1.0)) * 36.0))
		score += _route_network_load_for_legacy_region(index) * 12
		score -= int(districts[index].get("damage", 0)) * 34
		score -= int(city.get("trade_route_damage", 0)) * 38
		score -= int(city.get("trade_disrupted_routes", 0)) * 28
		score -= int(float(_auto_build_monster_risk_score(index)) / 3.0)
		if score > best_score:
			best_score = score
			best_index = index
	return best_index
func _ai_product_futures_plan(player_index: int, skill: Dictionary, preferred_product: String = "") -> Dictionary:
	if String(skill.get("kind", "")) != "product_futures":
		return {}
	var product_name := _ai_product_for_futures_skill(player_index, skill, preferred_product)
	if product_name == "" or not PRODUCT_CATALOG.has(product_name):
		return {}
	var terms := _product_futures_terms(skill)
	if terms.is_empty():
		return {}
	var direction := String(terms.get("direction", "up"))
	if not ["up", "down"].has(direction):
		return {}
	var stockpile_required := bool(terms.get("requires_warehouse", false))
	var district_index := _ai_best_owned_route_city_for_product(player_index, product_name, false)
	if district_index < 0:
		district_index = _ai_best_city_district(player_index, true)
	if district_index < 0:
		district_index = _ai_first_alive_district()
	var warehouse_city := -1
	if stockpile_required:
		warehouse_city = _ai_best_warehouse_city_for_product(player_index, product_name)
		if warehouse_city < 0:
			return {}
		district_index = warehouse_city
	var scores := _product_strategy_scores(product_name)
	var market_score := int(scores.get("short", 0)) if direction == "down" else int(scores.get("long", 0))
	var stockpile_score := int(scores.get("stockpile", 0))
	var futures_score := maxi(1, _ai_product_futures_product_score(player_index, skill, product_name))
	var flow := _player_product_flow(player_index, product_name)
	var target_owner := -999
	if district_index >= 0 and district_index < districts.size():
		var target_city := _district_city(district_index)
		if _city_is_active(target_city):
			target_owner = int(target_city.get("owner", -1))
	var result := {
		"policy_kind": _ai_product_futures_policy_kind(skill),
		"district": district_index,
		"product": product_name,
		"target_city": warehouse_city if warehouse_city >= 0 else district_index,
		"target_owner": target_owner,
		"futures_direction": direction,
		"futures_signal": futures_score,
		"futures_market_score": market_score,
		"futures_stockpile_score": stockpile_score,
		"futures_stockpile_units": maxi(1, int(terms.get("units", 1))),
		"futures_duration_seconds": int(round(_product_futures_duration_seconds(skill))),
		"futures_multiplier_x100": int(round(maxf(0.1, float(terms.get("multiplier", 1.0))) * 100.0)),
		"futures_margin_cash": int(terms.get("margin_cash", 0)),
		"futures_maximum_gain": int(terms.get("maximum_gain", 0)),
		"futures_maximum_loss": int(terms.get("maximum_loss", 0)),
		"futures_risk_adjusted_ev": int(round(float(int(terms.get("maximum_gain", 0))) * 0.55 - float(int(terms.get("maximum_loss", 0))) * 0.45)),
		"futures_warehouse_city": warehouse_city,
		"futures_warehouse_required": stockpile_required,
		"futures_product_flow": flow,
		"reason": "%s%s｜%s评分%d｜流动%d｜倍率×%.2f｜%s%s后结算" % [
			product_name,
			"港仓囤货" if stockpile_required else "商品期货",
			_ai_product_futures_direction_label(direction),
			futures_score,
			flow,
			maxf(0.1, float(terms.get("multiplier", 1.0))),
			("仓库:%s｜" % String(districts[warehouse_city].get("name", "城市"))) if warehouse_city >= 0 else "",
			_duration_short_text(_product_futures_duration_seconds(skill)),
		],
	}
	return result
func _ai_generic_card_effect_score(player_index: int, skill: Dictionary, district_index: int, product_name: String = "", target_owner: int = -999) -> int:
	var score := 0
	var harmful_target := target_owner >= 0 and target_owner != player_index
	var helpful_target := target_owner == player_index
	var target_city := _district_city(district_index)
	var warehouse_pressure := _city_warehouse_stockpile_pressure(target_city) if _city_is_active(target_city) else 0
	score += int(float(int(skill.get("cash", 0))) / 4.0)
	score += int(skill.get("draw_amount", 0)) * 45
	score += int(skill.get("trace_card_count", 0)) * 42
	score += int(skill.get("reveal_city_count", 0)) * 48
	score += int(skill.get("trace_contract_count", 0)) * 45
	score += int(skill.get("hand_discard_count", 0)) * (82 if harmful_target or target_owner == -999 else -30)
	score += int(skill.get("hand_steal_count", 0)) * (112 if harmful_target or target_owner == -999 else -45)
	score += int(round(float(skill.get("hand_lock_seconds", 0.0)) * 2.0)) if harmful_target or target_owner == -999 else 0
	score += int(skill.get("control_gdp_penalty", 0)) * (2 if harmful_target else -1)
	score += int(round(float(skill.get("control_block_seconds", 0.0)) / 2.5)) if harmful_target else 0
	score += int(skill.get("global_barrage_target_count", 0)) * 36 + int(skill.get("global_barrage_damage", 0)) * 72 + int(skill.get("global_barrage_route_damage", 0)) * 58
	if warehouse_pressure > 0 and int(skill.get("global_barrage_damage", 0)) > 0 and (harmful_target or target_owner == -999):
		score += warehouse_pressure
	score += int(skill.get("counter_strength", 0)) * 58 + int(float(int(skill.get("counter_refund", 0))) / 3.0) + int(skill.get("counter_trace", 0)) * 42
	score += int(skill.get("military_hp", 0)) * 7 + int(skill.get("military_damage", 0)) * 70 + int(skill.get("fixed_skill_count", 0)) * 26
	score += int(round(float(skill.get("military_move", 0.0)) / 18.0)) + int(round(float(skill.get("military_range", 0.0)) / 20.0))
	score += int(round(float(skill.get("military_duration_seconds", 0.0)) / 1.5))
	score += int(skill.get("military_gdp_penalty", 0)) * (5 if harmful_target or target_owner == -999 else 1)
	score += int(skill.get("military_strike_route_damage", 0)) * (74 if harmful_target or target_owner == -999 else 18)
	match String(skill.get("military_command", "")):
		"move":
			score += 42
		"guard":
			score += 76 if helpful_target or target_owner == -999 else 22
			if helpful_target:
				score += int(float(warehouse_pressure) / 2.0)
		"strike_district":
			score += 88 if harmful_target or target_owner == -999 else -30
			if harmful_target or target_owner == -999:
				score += warehouse_pressure
		"attack_monster":
			score += 96 if not auto_monsters.is_empty() else 18
	score += int(float(int(skill.get("revenue_amount", 0))) / 2.0)
	score += int(float(int(skill.get("contract_income", 0)) * maxi(1, int(ceil(float(_skill_duration_seconds(skill, "contract_seconds", "contract_turns", 1)) / float(ECONOMY_LEGACY_TURN_SECONDS))))) / 5.0)
	score += int(round((float(skill.get("route_flow_multiplier", 1.0)) - 1.0) * 120.0)) if helpful_target else 0
	score += int(skill.get("repair_routes", 0)) * (55 if helpful_target else 18)
	var economy_delta := int(skill.get("production_delta", 0)) + int(skill.get("transport_delta", 0)) + int(skill.get("consumption_delta", 0))
	if economy_delta > 0:
		score += economy_delta * (60 if helpful_target else 24)
	elif economy_delta < 0:
		score += abs(economy_delta) * (70 if harmful_target else -45)
	var route_damage := int(skill.get("route_damage", 0)) + int(skill.get("decline_route_damage", 0))
	if route_damage > 0:
		score += route_damage * (75 if harmful_target else 15)
		if warehouse_pressure > 0 and harmful_target:
			score += int(float(warehouse_pressure) / 2.0)
	var area_damage := int(skill.get("damage", 0))
	if area_damage > 0:
		score += area_damage * (58 if harmful_target else 22)
		if warehouse_pressure > 0 and harmful_target:
			score += int(float(warehouse_pressure) / 2.0)
	var demand_pressure := int(skill.get("market_demand_pressure", 0))
	var supply_pressure := int(skill.get("market_supply_pressure", 0))
	if product_name != "":
		if product_name == _ai_focus_product(player_index) or product_name == _ai_route_plan_product(player_index):
			score += abs(demand_pressure - supply_pressure) * 18
		score += int(float(int(skill.get("price_delta", 0))) / 2.0)
	if String(skill.get("kind", "")) == "product_futures":
		var futures_plan := _ai_product_futures_plan(player_index, skill, product_name)
		if not futures_plan.is_empty():
			var futures_bonus := int(futures_plan.get("futures_signal", 0))
			score += futures_bonus
			if bool(futures_plan.get("futures_warehouse_required", false)):
				score += int(futures_plan.get("futures_stockpile_units", 1)) * 24
			if String(futures_plan.get("product", "")) == _ai_focus_product(player_index) or String(futures_plan.get("product", "")) == _ai_route_plan_product(player_index):
				score += 54
	var derivative_terms := _city_gdp_derivative_terms(skill) if String(skill.get("kind", "")) == "city_gdp_derivative" else {}
	var gdp_multiplier := float(derivative_terms.get("multiplier", 0.0))
	if gdp_multiplier > 0.0:
		var direction := String(derivative_terms.get("direction", "up"))
		var city := _district_city(district_index)
		var last_income := int(city.get("last_income", 0))
		var risk := int(districts[district_index].get("damage", 0)) * 26 + int(city.get("trade_disrupted_routes", 0)) * 32 if district_index >= 0 and district_index < districts.size() else 0
		if direction == "up":
			score += int(round(gdp_multiplier * 55.0)) + (80 if helpful_target else 20) + maxi(0, int(float(last_income) / 6.0) - risk)
		elif bool(derivative_terms.get("insurance", false)):
			score += int(round(gdp_multiplier * 58.0)) + (105 if helpful_target else -40) + risk + int(float(int(derivative_terms.get("destroy_bonus", 0))) / 10.0)
			if helpful_target:
				score += int(float(warehouse_pressure) / 2.0)
		else:
			score += int(round(gdp_multiplier * 68.0)) + (90 if harmful_target else 20) + risk + int(float(int(derivative_terms.get("destroy_bonus", 0))) / 8.0)
			if harmful_target or target_owner == -999:
				score += warehouse_pressure
		score += _city_gdp_derivative_risk_adjusted_value(derivative_terms)
	if String(skill.get("kind", "")) == "weather_control":
		var weather_plan := _ai_weather_control_plan(player_index, skill)
		score += int(skill.get("weather_zone_count", 1)) * 42
		score += int(round(float(skill.get("weather_duration_seconds", WEATHER_DURATION_MIN_SECONDS)) / 3.0))
		score += maxi(0, int(round((WEATHER_FORECAST_LEAD_MAX_SECONDS - float(skill.get("weather_forecast_lead_seconds", WEATHER_FORECAST_LEAD_MIN_SECONDS))) / 3.0)))
		if not weather_plan.is_empty():
			score += int(float(int(weather_plan.get("weather_plan_score", 0))) / 3.0)
			var weather_role := String(weather_plan.get("weather_plan_role", ""))
			var strategy_intent := _ai_strategy_intent(player_index)
			if (weather_role == "boost_own_route" and ["grow_focus", "defend_routes"].has(strategy_intent)) \
				or (weather_role != "boost_own_route" and strategy_intent == "disrupt_competitors"):
				score += 28
	return score
func _ai_military_deploy_plan_for_district(player_index: int, skill: Dictionary, district_index: int) -> Dictionary:
	if not _can_deploy_military_card_at_district(skill, district_index):
		return {}
	var military_type := String(skill.get("military_type", "defense"))
	var prefers_offense := ["bomber", "missile", "submarine"].has(military_type)
	var prefers_sea_routes := ["submarine", "warship"].has(military_type)
	var city := _district_city(district_index)
	var city_owner := int(city.get("owner", -1)) if _city_is_active(city) else -1
	var terrain := String(districts[district_index].get("terrain", "land"))
	var terrain_multiplier := _military_unit_terrain_move_multiplier(skill, district_index)
	var income := int(city.get("last_income", _city_cycle_income(district_index, _city_competition_matches(district_index)))) if _city_is_active(city) else 0
	var route_pressure := int(city.get("trade_route_damage", 0)) + int(city.get("trade_disrupted_routes", 0)) if _city_is_active(city) else 0
	var warehouse_pressure := _city_warehouse_stockpile_pressure(city) if _city_is_active(city) else 0
	var route_load := _route_network_load_for_legacy_region(district_index)
	var monster_risk := _auto_build_monster_risk_score(district_index)
	var damage := int(districts[district_index].get("damage", 0))
	var panic := int(districts[district_index].get("panic", 0))
	var stat_score := int(skill.get("military_hp", 0)) * 2 \
		+ int(skill.get("military_damage", 0)) * 18 \
		+ int(round(float(skill.get("military_range", 0.0)) / 24.0)) \
		+ int(round(float(skill.get("military_move", 0.0)) / 26.0)) \
		+ int(round(float(skill.get("military_duration_seconds", 0.0)) / 2.0))
	var defense_score := 0
	var strike_score := 0
	var monster_score := monster_risk + int(skill.get("military_damage", 0)) * 42 + int(round(float(skill.get("military_range", 0.0)) / 18.0))
	var route_score := route_load * (36 if prefers_sea_routes else 18) + int(skill.get("military_strike_route_damage", 0)) * 62
	var staging_score := int(round(terrain_multiplier * 70.0)) + int(float(stat_score) / 3.0)
	if city_owner == player_index:
		defense_score = 100 + int(float(income) / 4.0) + damage * 48 + int(float(panic) / 2.0) + route_pressure * 64 + warehouse_pressure * 2 + monster_risk
		defense_score += _ai_district_focus_score(player_index, district_index)
		if not prefers_offense:
			defense_score += 80
		if military_type == "defense":
			defense_score += 160
	elif city_owner >= 0:
		strike_score = 96 + _ai_rival_city_pressure_score(player_index, district_index) + int(float(income) / 7.0)
		strike_score += warehouse_pressure * (3 if prefers_offense else 1)
		strike_score += int(skill.get("military_gdp_penalty", 0)) * 7 + int(skill.get("military_strike_route_damage", 0)) * 86
		strike_score += route_load * 18 + route_pressure * 28
		if prefers_offense:
			strike_score += 105
		elif military_type == "defense":
			strike_score = int(round(float(strike_score) * 0.42))
	if prefers_sea_routes and terrain == "ocean":
		route_score += 92
	if military_type == "tank" and terrain == "land":
		defense_score += 58
		staging_score += 48
	if military_type == "fighter":
		monster_score += 84
	if military_type == "missile":
		monster_score += 56
		strike_score += 50
	if military_type == "warship" and terrain == "ocean":
		defense_score += 48
		route_score += 68
	if military_type == "submarine" and terrain == "ocean":
		strike_score += 62
		route_score += 82
	var role := "terrain_staging"
	var role_score := staging_score
	if defense_score > role_score:
		role = "guard_own_city"
		role_score = defense_score
	if strike_score > role_score:
		role = "strike_rival_city"
		role_score = strike_score
	if monster_score > role_score:
		role = "intercept_monster"
		role_score = monster_score
	if route_score > role_score:
		role = "route_control"
		role_score = route_score
	var total_score := 52 + int(round(terrain_multiplier * 36.0)) + stat_score + role_score
	var target_city := district_index if _city_is_active(city) else -1
	var reason_label: String = String({
		"guard_own_city": "护航己方城市",
		"strike_rival_city": "压制竞争城市",
		"intercept_monster": "截击怪兽威胁",
		"route_control": "控制商路节点",
		"terrain_staging": "占据适配地形",
	}.get(role, "军事部署"))
	return {
		"district": district_index,
		"target_city": target_city,
		"target_owner": city_owner,
		"score": maxi(1, total_score),
		"military_deploy_role": role,
		"military_deploy_score": maxi(1, role_score),
		"military_deploy_terrain": terrain,
		"military_deploy_route_load": route_load,
		"military_deploy_monster_risk": monster_risk,
		"military_unit_type": military_type,
		"strategic_role": role,
		"reason": "部署%s｜%s｜%s｜地形×%.2f｜GDP%d｜商路%d｜仓储%d｜怪兽%d" % [
			_military_unit_type_label(skill),
			String(reason_label),
			String(districts[district_index].get("name", "区域")),
			terrain_multiplier,
			income,
			route_load + route_pressure,
			warehouse_pressure,
			monster_risk,
		],
	}
func _ai_military_deploy_plan(player_index: int, skill: Dictionary) -> Dictionary:
	if String(skill.get("kind", "")) != "military_force":
		return {}
	var best := {}
	var best_score := -999999
	for index in range(districts.size()):
		var plan := _ai_military_deploy_plan_for_district(player_index, skill, index)
		if plan.is_empty():
			continue
		var score := int(plan.get("score", 0))
		if score > best_score:
			best_score = score
			best = plan
	if not best.is_empty():
		best["policy_kind"] = "military_force_%s" % String(best.get("military_deploy_role", "deploy"))
	return best
func _ai_best_military_deploy_district(player_index: int, skill: Dictionary) -> int:
	var plan := _ai_military_deploy_plan(player_index, skill)
	return int(plan.get("district", -1)) if not plan.is_empty() else -1
func _ai_military_unit_for_command(player_index: int, skill: Dictionary) -> Dictionary:
	var bound_uid := int(skill.get("bound_military_uid", 0))
	if bound_uid > 0:
		var bound_index := _military_unit_index_by_uid(bound_uid)
		if bound_index >= 0:
			var bound_unit: Dictionary = military_units[bound_index]
			if int(bound_unit.get("owner", -1)) == player_index and float(bound_unit.get("cooldown_left", 0.0)) <= 0.0:
				return bound_unit.duplicate(true)
	var fallback_index := _owned_active_military_unit_index(player_index)
	if fallback_index >= 0:
		var unit: Dictionary = military_units[fallback_index]
		if float(unit.get("cooldown_left", 0.0)) <= 0.0:
			return unit.duplicate(true)
	return {}
func _ai_military_guard_target(player_index: int, unit: Dictionary, command_range: float) -> Dictionary:
	var best := {}
	var best_score := -999999
	for city_index_variant in _active_city_indices_for_player(player_index):
		var city_index := int(city_index_variant)
		if _entity_distance_to_district(unit, city_index) > command_range:
			continue
		var city := _district_city(city_index)
		var damage := int(districts[city_index].get("damage", 0))
		var panic := int(districts[city_index].get("panic", 0))
		var route_damage := int(city.get("trade_route_damage", 0))
		var disrupted := int(city.get("trade_disrupted_routes", 0))
		var warehouse_pressure := _city_warehouse_stockpile_pressure(city)
		var monster_risk := _auto_build_monster_risk_score(city_index)
		var income := int(city.get("last_income", _city_cycle_income(city_index, _city_competition_matches(city_index))))
		var score := 96 + int(float(income) / 4.0) + damage * 54 + int(float(panic) / 2.0) + route_damage * 92 + disrupted * 48 + warehouse_pressure + int(float(monster_risk) / 2.0)
		score += _ai_district_focus_score(player_index, city_index)
		if score > best_score:
			best_score = score
			best = {
				"district": city_index,
				"target_city": city_index,
				"target_owner": player_index,
				"score": maxi(1, score),
				"military_command_role": "guard_city",
				"military_command_score": maxi(1, score),
				"military_command_distance_m": int(round(_entity_distance_to_district(unit, city_index))),
				"reason": "军令保卫己方%s｜GDP%d｜区域伤%d｜断路%d｜仓储%d｜怪兽风险%d" % [
					String(districts[city_index].get("name", "城市")),
					income,
					damage,
					route_damage + disrupted,
					warehouse_pressure,
					monster_risk,
				],
			}
	return best
func _ai_military_strike_target(player_index: int, unit: Dictionary, command_range: float) -> Dictionary:
	var best := {}
	var best_score := -999999
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		var city_owner := int(city.get("owner", -1))
		if city_owner == player_index or city_owner < 0:
			continue
		if _entity_distance_to_district(unit, city_index) > command_range:
			continue
		var attack_value := _ai_rival_city_pressure_score(player_index, city_index)
		var warehouse_pressure := _city_warehouse_stockpile_pressure(city)
		var route_load := _route_network_load_for_legacy_region(city_index)
		var route_damage := int(city.get("trade_route_damage", 0)) + int(city.get("trade_disrupted_routes", 0))
		var score := 110 + attack_value + warehouse_pressure * 2 + route_load * 16 + route_damage * 24
		score += int(unit.get("damage", 1)) * 54 + int(unit.get("military_gdp_penalty", 0)) * 5 + int(unit.get("military_strike_route_damage", 0)) * 72
		score += int(float(_ai_district_focus_score(player_index, city_index)) / 2.0)
		if score > best_score:
			best_score = score
			best = {
				"district": city_index,
				"target_city": city_index,
				"target_owner": city_owner,
				"score": maxi(1, score),
				"attack_value": attack_value,
				"military_command_role": "strike_rival_city",
				"military_command_score": maxi(1, score),
				"military_command_distance_m": int(round(_entity_distance_to_district(unit, city_index))),
				"reason": "军令轰击竞品%s｜城市价值%d｜仓储%d｜商路%d｜火力%d" % [
					String(districts[city_index].get("name", "城市")),
					attack_value,
					warehouse_pressure,
					route_load,
					int(unit.get("damage", 1)),
				],
			}
	return best
func _ai_military_monster_target(player_index: int, unit: Dictionary, command_range: float) -> Dictionary:
	var best := {}
	var best_score := -999999
	for slot in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[slot]
		if bool(actor.get("down", false)):
			continue
		var distance := _wrapped_distance(_entity_world_position(unit), _entity_world_position(actor))
		if distance > command_range:
			continue
		var monster_position := int(actor.get("position", -1))
		var nearest_own_city_distance := 999999.0
		var nearest_own_city := -1
		for city_index_variant in _active_city_indices_for_player(player_index):
			var city_index := int(city_index_variant)
			var city_distance := _entity_distance_to_district(actor, city_index)
			if city_distance < nearest_own_city_distance:
				nearest_own_city_distance = city_distance
				nearest_own_city = city_index
		var resource_pressure := _monster_resource_match_score(actor, monster_position) if monster_position >= 0 and monster_position < districts.size() else 0
		var monster_owner := int(actor.get("owner", -1))
		var score := 72 + int(actor.get("rank", 1)) * 42 + int(actor.get("hp", 0)) * 3 + resource_pressure * 65 + int(unit.get("damage", 1)) * 58
		if nearest_own_city >= 0:
			score += maxi(0, 260 - int(round(nearest_own_city_distance))) * 2
			score += int(float(_ai_city_target_score(player_index, nearest_own_city, true, true)) / 4.0)
		if monster_owner == player_index:
			score -= 120
		elif monster_owner >= 0:
			score += 50
		if score > best_score:
			best_score = score
			best = {
				"target_slot": slot,
				"district": monster_position if monster_position >= 0 else int(unit.get("position", _ai_first_alive_district())),
				"target_city": nearest_own_city,
				"target_owner": player_index if nearest_own_city >= 0 else -999,
				"score": maxi(1, score),
				"resource_match": resource_pressure,
				"distance_m": int(round(distance)),
				"military_command_role": "attack_threat_monster",
				"military_command_score": maxi(1, score),
				"military_command_distance_m": int(round(distance)),
				"reason": "军令猎兽怪%d·%s｜距离%s｜资源威胁%d｜己城距离%s｜火力%d" % [
					slot + 1,
					String(actor.get("name", "怪兽")),
					_meters_text(distance),
					resource_pressure,
					_meters_text(nearest_own_city_distance) if nearest_own_city >= 0 else "未知",
					int(unit.get("damage", 1)),
				],
			}
	return best
func _ai_military_move_target(player_index: int, unit: Dictionary) -> Dictionary:
	var best := {}
	var best_score := -999999
	var unit_type := String(unit.get("military_type", "defense"))
	for index in range(districts.size()):
		if bool(districts[index].get("destroyed", false)):
			continue
		var city := _district_city(index)
		var city_owner := int(city.get("owner", -1)) if _city_is_active(city) else -1
		var distance := _entity_distance_to_district(unit, index)
		var terrain_multiplier := _military_unit_terrain_move_multiplier(unit, index)
		var score := int(round(terrain_multiplier * 55.0)) - int(round(distance / 20.0))
		if city_owner == player_index:
			score += 80 + int(float(_ai_city_target_score(player_index, index, true, true)) / 3.0)
			score += int(float(_auto_build_monster_risk_score(index)) / 2.0)
		elif city_owner >= 0:
			score += 65 + int(float(_ai_rival_city_pressure_score(player_index, index)) / 4.0)
			if ["bomber", "missile", "submarine", "warship"].has(unit_type):
				score += 70
		score += _route_network_load_for_legacy_region(index) * (18 if ["submarine", "warship"].has(unit_type) else 8)
		if String(districts[index].get("terrain", "land")) == "ocean" and ["submarine", "warship"].has(unit_type):
			score += 85
		if String(districts[index].get("terrain", "land")) == "land" and unit_type == "tank":
			score += 65
		if distance <= 5.0:
			score -= 160
		if score > best_score:
			best_score = score
			best = {
				"district": index,
				"target_city": index if _city_is_active(city) else -1,
				"target_owner": city_owner,
				"score": maxi(1, score),
				"military_command_role": "reposition",
				"military_command_score": maxi(1, score),
				"military_command_distance_m": int(round(distance)),
				"reason": "军令前进至%s｜地形×%.2f｜距离%s｜角色:%s" % [
					String(districts[index].get("name", "区域")),
					terrain_multiplier,
					_meters_text(distance),
					unit_type,
				],
			}
	return best
func _ai_military_command_plan(player_index: int, skill: Dictionary) -> Dictionary:
	if String(skill.get("kind", "")) != "military_command":
		return {}
	var unit := _ai_military_unit_for_command(player_index, skill)
	if unit.is_empty():
		return {}
	var command := String(skill.get("military_command", ""))
	var command_range := maxf(80.0, float(unit.get("range", skill.get("range", 220.0))))
	var plan := {}
	match command:
		"guard":
			plan = _ai_military_guard_target(player_index, unit, command_range)
		"strike_district":
			plan = _ai_military_strike_target(player_index, unit, command_range)
		"attack_monster":
			plan = _ai_military_monster_target(player_index, unit, command_range)
		"move":
			plan = _ai_military_move_target(player_index, unit)
	if plan.is_empty():
		return {}
	plan["policy_kind"] = "military_command_%s" % command
	plan["military_unit_uid"] = int(unit.get("uid", 0))
	plan["military_unit_type"] = String(unit.get("military_type", "defense"))
	plan["military_command"] = command
	plan["strategic_role"] = String(plan.get("military_command_role", command))
	return plan
func _ai_card_play_context(player_index: int, slot_index: int, skill: Dictionary) -> Dictionary:
	var kind := String(skill.get("kind", ""))
	var own_city := _ai_best_city_district(player_index, true)
	var rival_city := _ai_best_pressure_target_city(player_index)
	var fallback := own_city if own_city >= 0 else _ai_first_alive_district()
	var focus_product := _ai_focus_product(player_index)
	var planned_product := _ai_product_for_skill(player_index, skill)
	var route_product := _ai_route_plan_product(player_index)
	var route_stage := _ai_route_plan_stage(player_index)
	var phase_info := _ai_refresh_game_phase(player_index)
	var endgame_urgency := _ai_endgame_urgency_score(player_index)
	var development_route := _card_development_route_id(skill)
	var development_route_bias := _ai_development_route_bias(player_index, development_route)
	var context := {
		"action": "出牌",
		"slot_index": slot_index,
		"card_name": String(skill.get("name", "卡牌")),
		"kind": kind,
		"policy_kind": kind,
		"district": fallback,
		"target_slot": -1,
		"target_player": -1,
		"product": planned_product,
		"focus_product": focus_product,
		"focus_score": _ai_focus_score(player_index),
		"focus_bonus": 0,
		"strategy_intent": _ai_strategy_intent(player_index),
		"strategy_score": _ai_strategy_score(player_index),
		"strategy_bonus": 0,
		"route_plan_product": route_product,
		"route_plan_stage": route_stage,
		"route_plan_score": _ai_route_plan_score(player_index),
		"route_plan_bonus": 0,
		"route_gap_bonus": 0,
		"route_gap_penalty": 0,
		"route_gap_reason": "",
		"route_gap_field_match": 0,
		"development_route": development_route,
		"development_route_label": _development_route_label(development_route),
		"development_route_bias": development_route_bias,
		"development_route_bonus": 0,
		"game_phase": String(phase_info.get("phase", "midgame")),
		"competitive_posture": String(phase_info.get("posture", "contesting")),
		"score_gap_to_leader": int(phase_info.get("gap", 0)),
		"leader_index": int(phase_info.get("leader_index", -1)),
		"endgame_urgency": endgame_urgency,
		"phase_bonus": 0,
		"learning_bonus": 0,
		"contract_source": -1,
		"contract_target": -1,
		"score": 70 + maxi(0, int(skill.get("cost", 2))) * 12 + maxi(1, _skill_rank(String(skill.get("name", "")))) * 9,
		"reason": "按卡牌强度、目标价值、GDP份额、路线计划与AI性格评分",
	}
	if kind == "card_counter":
		return _ai_counter_response_candidate(player_index, slot_index, skill)
	if kind == "monster_card":
		context["district"] = _ai_best_monster_card_district(player_index, skill)
		context["score"] = 1180 if bool(skill.get("starter_play_free", false)) else int(context["score"]) + 150
	elif kind == "monster_bound_action":
		var bound_slot := _ai_monster_target_for_skill(player_index, skill)
		if bound_slot < 0:
			return {}
		context["target_slot"] = bound_slot
		context["district"] = _ai_best_district_near_monster(player_index, bound_slot)
		context["score"] = int(context["score"]) + 95
	elif kind == "monster_lure":
		var lure_plan := _ai_monster_lure_plan(player_index, skill)
		if lure_plan.is_empty():
			return {}
		var base_lure_score := int(context["score"])
		context.merge(lure_plan, true)
		context["score"] = base_lure_score + int(lure_plan.get("score", 0))
		context["reason"] = String(lure_plan.get("reason", "诱导怪兽压向竞争城市"))
	elif kind == "mudslide":
		var mudslide_plan := _ai_monster_lure_plan(player_index, skill, float(skill.get("range", DEFAULT_AOE_RADIUS_METERS)))
		if mudslide_plan.is_empty():
			return {}
		var base_mudslide_score := int(context["score"])
		context.merge(mudslide_plan, true)
		context["score"] = base_mudslide_score + int(mudslide_plan.get("score", 0)) + int(skill.get("damage", 1)) * 45
		context["reason"] = "AOE打击｜%s" % String(mudslide_plan.get("reason", "锁定竞争城市"))
	elif kind == "special_monster_delay":
		var delay_plan := _ai_monster_delay_plan(player_index, skill)
		if delay_plan.is_empty():
			return {}
		var base_delay_score := int(context["score"])
		context.merge(delay_plan, true)
		context["score"] = base_delay_score + int(delay_plan.get("score", 0))
		context["reason"] = String(delay_plan.get("reason", "延后威胁怪兽"))
	elif kind == "military_command":
		var command_plan := _ai_military_command_plan(player_index, skill)
		if command_plan.is_empty():
			return {}
		var base_command_score := int(context["score"])
		context.merge(command_plan, true)
		context["score"] = base_command_score + int(command_plan.get("score", 0))
		context["reason"] = String(command_plan.get("reason", "执行军令"))
	elif _skill_targets_monster(skill):
		var target_slot := _ai_monster_target_for_skill(player_index, skill)
		if target_slot < 0:
			return {}
		context["target_slot"] = target_slot
		var target_range := float(skill.get("range", -1.0)) if kind == "mudslide" else -1.0
		context["district"] = _ai_best_district_near_monster(player_index, target_slot, target_range)
		context["score"] = int(context["score"]) + 80
	elif _skill_targets_player(skill):
		var direct_plan := _ai_direct_player_interaction_plan(player_index, skill)
		if direct_plan.is_empty():
			return {}
		var base_direct_score := int(context["score"])
		context.merge(direct_plan, true)
		context["district"] = rival_city if rival_city >= 0 else fallback
		context["score"] = base_direct_score + int(direct_plan.get("score", 0))
		context["reason"] = String(direct_plan.get("reason", "直接互动压制目标玩家｜公开目标但隐藏出牌者"))
	elif kind == "military_force":
		var military_plan := _ai_military_deploy_plan(player_index, skill)
		if military_plan.is_empty():
			return {}
		var base_military_score := int(context["score"])
		context.merge(military_plan, true)
		context["score"] = base_military_score + int(military_plan.get("score", 0))
		context["reason"] = "%s｜%s" % [
			String(military_plan.get("reason", "部署军队")),
			_military_unit_mobility_summary(skill),
		]
	elif kind == "area_trade_contract":
		if own_city < 0 or rival_city < 0:
			return {}
		context["contract_source"] = own_city
		context["contract_target"] = rival_city
		context["district"] = rival_city
		var source_products := _city_product_names(_district_city(own_city))
		if focus_product != "" and source_products.has(focus_product):
			context["product"] = focus_product
			context["focus_bonus"] = int(context.get("focus_bonus", 0)) + AI_ECONOMIC_FOCUS_MATCH_BONUS
		elif not source_products.is_empty():
			context["product"] = String(source_products[0])
		context["score"] = int(context["score"]) + 110 + int(float(int(skill.get("accept_cash", 0))) / 3.0)
	elif ["city_revenue_boost", "city_product_upgrade", "city_product_shift", "city_demand_shift", "city_contract_boon", "route_flow_boon"].has(kind):
		if own_city < 0:
			return {}
		context["district"] = own_city
		context["score"] = int(context["score"]) + 90
		context["focus_bonus"] = int(context.get("focus_bonus", 0)) + _ai_district_focus_score(player_index, own_city)
	elif kind == "route_insurance":
		var damaged_city := _ai_best_city_district(player_index, true, true)
		if damaged_city < 0 or int(_district_city(damaged_city).get("trade_route_damage", 0)) <= 0:
			var route_city := _ai_best_owned_route_city_for_product(player_index, route_product, false) if route_product != "" else -1
			damaged_city = route_city if route_city >= 0 else own_city
		if damaged_city < 0:
			return {}
		context["district"] = damaged_city
		var defense_city := _district_city(damaged_city)
		context["target_city"] = damaged_city
		context["target_owner"] = int(defense_city.get("owner", -1))
		var route_pressure := int(defense_city.get("trade_route_damage", 0)) + int(defense_city.get("trade_disrupted_routes", 0))
		context["score"] = int(context["score"]) \
			+ route_pressure * 70 \
			+ int(skill.get("repair_routes", 0)) * 36 \
			+ int(float(int(skill.get("revenue_amount", 0))) / 2.0) \
			+ int(round(maxf(0.0, float(skill.get("route_flow_multiplier", 1.0)) - 1.0) * 130.0))
		context["reason"] = "保护己方城市商路｜断路压力%d｜修复%d｜流通×%.2f" % [
			route_pressure,
			int(skill.get("repair_routes", 0)),
			float(skill.get("route_flow_multiplier", 1.0)),
		]
	elif kind == "product_futures":
		var futures_plan := _ai_product_futures_plan(player_index, skill, planned_product)
		if futures_plan.is_empty():
			return {}
		context.merge(futures_plan, true)
	elif kind == "city_gdp_derivative":
		var derivative_terms := _city_gdp_derivative_terms(skill)
		if derivative_terms.is_empty():
			return {}
		var gdp_direction := String(derivative_terms.get("direction", "up"))
		var gdp_target := _ai_best_city_for_gdp_derivative(player_index, gdp_direction, skill)
		if gdp_target < 0:
			return {}
		context["district"] = gdp_target
		var gdp_insurance := bool(derivative_terms.get("insurance", false))
		context["policy_kind"] = "%s_%s" % [kind, "insurance" if gdp_insurance else gdp_direction]
		context["target_city"] = gdp_target
		context["target_owner"] = int(_district_city(gdp_target).get("owner", -1))
		context["score"] = int(context["score"]) + 110 + int(round(float(derivative_terms.get("multiplier", 1.0)) * 35.0)) + int(float(int(derivative_terms.get("destroy_bonus", 0))) / 10.0) + _city_gdp_derivative_risk_adjusted_value(derivative_terms)
		if gdp_insurance:
			context["score"] = int(context["score"]) + int(float(_ai_city_gdp_insurance_score(player_index, gdp_target)) / 3.0)
		context["reason"] = "匿名%s%sGDP｜倍率×%.2f｜持仓%s" % [
			"灾害保单对冲" if gdp_insurance else ("买涨" if gdp_direction == "up" else "做空"),
			districts[gdp_target]["name"],
			float(derivative_terms.get("multiplier", 1.0)),
			_duration_short_text(_city_gdp_derivative_duration_seconds(skill)),
		]
	elif kind == "news_event":
		if rival_city < 0:
			return {}
		context["district"] = rival_city
		context["target_city"] = rival_city
		context["target_owner"] = int(_district_city(rival_city).get("owner", -1))
		context["product"] = _ai_preferred_product(player_index, true)
		if String(context.get("product", "")) == focus_product and focus_product != "":
			context["focus_bonus"] = int(context.get("focus_bonus", 0)) + AI_ECONOMIC_FOCUS_MATCH_BONUS
		context["score"] = int(context["score"]) + 115 + int(skill.get("panic", 0)) + int(skill.get("route_damage", 0)) * 45
	elif kind == "weather_control":
		var weather_plan := _ai_weather_control_plan(player_index, skill)
		if weather_plan.is_empty():
			return {}
		var base_weather_score := int(context["score"])
		context.merge(weather_plan, true)
		context["score"] = base_weather_score + int(weather_plan.get("score", 0))
		context["reason"] = "%s｜%s后生效" % [
			String(weather_plan.get("reason", "改写天气预报")),
			_duration_short_text(float(skill.get("weather_forecast_lead_seconds", WEATHER_FORECAST_LEAD_MIN_SECONDS))),
		]
	elif ["route_sabotage", "panic_shift"].has(kind):
		if rival_city < 0:
			return {}
		context["district"] = rival_city
		context["target_city"] = rival_city
		context["target_owner"] = int(_district_city(rival_city).get("owner", -1))
		context["product"] = _ai_preferred_product(player_index, true)
		if String(context.get("product", "")) == focus_product and focus_product != "":
			context["focus_bonus"] = int(context.get("focus_bonus", 0)) + AI_ECONOMIC_FOCUS_MATCH_BONUS
		context["score"] = int(context["score"]) + 105
	elif kind == "region_economy_shift":
		var net_shift := int(skill.get("production_delta", 0)) + int(skill.get("transport_delta", 0)) + int(skill.get("consumption_delta", 0))
		context["district"] = own_city if net_shift >= 0 else rival_city
		if int(context["district"]) < 0:
			return {}
		var shifted_city := _district_city(int(context["district"]))
		if _city_is_active(shifted_city):
			context["target_city"] = int(context["district"])
			context["target_owner"] = int(shifted_city.get("owner", -1))
		context["focus_bonus"] = int(context.get("focus_bonus", 0)) + _ai_district_focus_score(player_index, int(context["district"]))
	elif kind == "city_control_dispute":
		var control_plan := _ai_direct_city_interaction_plan(player_index, skill)
		if control_plan.is_empty():
			return {}
		var base_control_score := int(context["score"])
		context.merge(control_plan, true)
		context["score"] = base_control_score + int(control_plan.get("score", 0)) + int(skill.get("control_gdp_penalty", 0)) * 2
		context["reason"] = "%s｜GDP惩罚%d" % [
			String(control_plan.get("reason", "冻结竞争城市产权")),
			int(skill.get("control_gdp_penalty", 0)),
		]
	elif kind == "global_barrage":
		var barrage_plan := _ai_direct_city_interaction_plan(player_index, skill)
		if barrage_plan.is_empty():
			return {}
		var base_barrage_score := int(context["score"])
		context.merge(barrage_plan, true)
		context["score"] = base_barrage_score + int(barrage_plan.get("score", 0)) + int(skill.get("global_barrage_target_count", 1)) * 24 + int(skill.get("global_barrage_damage", 1)) * 58
		context["reason"] = "%s｜目标数%d｜伤害%d" % [
			String(barrage_plan.get("reason", "全场齐射压制高价值城市")),
			int(skill.get("global_barrage_target_count", 1)),
			int(skill.get("global_barrage_damage", 1)),
		]
	elif kind == "intel_city_reveal":
		if rival_city < 0:
			return {}
		context["district"] = rival_city
		context["score"] = int(context["score"]) + 88 + _city_intel_priority_score({"potential_income": int(_district_city(rival_city).get("last_income", 0)), "last_income": int(_district_city(rival_city).get("last_income", 0)), "competition": _city_competition_matches(rival_city), "disrupted": int(_district_city(rival_city).get("trade_disrupted_routes", 0)), "products": _city_product_names(_district_city(rival_city)), "demands": _city_demand_names(_district_city(rival_city)), "marked": false})
	elif kind == "intel_card_trace":
		if _traceable_card_entries(selected_card_resolution_id, 1).is_empty():
			return {}
		context["district"] = _ai_first_alive_district()
		context["score"] = int(context["score"]) + 95 + resolved_card_history.size() * 4
	elif kind == "intel_contract_trace":
		if _traceable_contract_entries(selected_card_resolution_id, 1).is_empty():
			return {}
		context["district"] = _ai_first_alive_district()
		context["score"] = int(context["score"]) + 100 + pending_contract_offers.size() * 18
	elif kind == "supply_draw":
		context["district"] = -1
		for i in range(districts.size()):
			if _market_listing_purchasable(i) and not _district_supply_card_ids(i).is_empty():
				context["district"] = i
				break
		if int(context["district"]) < 0:
			return {}
	elif ["cash_gain", "product_speculation", "product_contract_boon", "market_stabilize", "product_growth_boon"].has(kind):
		context["score"] = int(context["score"]) + int(float(int(skill.get("cash", 0))) / 3.0) + 45
	if int(context.get("district", -1)) < 0:
		return {}
	var requirement_district := int(context.get("district", -1))
	if _skill_play_region_scope(skill) == CardPlayRequirementPolicyScript.SCOPE_CONTRACT_SOURCE_REGION:
		requirement_district = int(context.get("contract_source", requirement_district))
	var requirement_metadata := _ai_play_requirement_metadata(player_index, skill, requirement_district)
	if not bool(requirement_metadata.get("requirement_satisfied", false)):
		return {}
	context.merge(requirement_metadata, true)
	var product_name := String(context.get("product", ""))
	if focus_product != "" and product_name == focus_product:
		context["focus_bonus"] = int(context.get("focus_bonus", 0)) + AI_ECONOMIC_FOCUS_MATCH_BONUS
		context["score"] = int(context["score"]) + int(context.get("focus_bonus", 0))
	var required := _skill_play_flow_required(skill, player_index)
	if required > 0:
		var explicit_play_product := String(skill.get("play_product", ""))
		product_name = explicit_play_product
		if product_name == "":
			var preferred_play_products := []
			var context_product := String(context.get("product", ""))
			if context_product != "":
				preferred_play_products.append(context_product)
			if route_product != "":
				preferred_play_products.append(route_product)
			if focus_product != "":
				preferred_play_products.append(focus_product)
			var playable_product := _best_player_flow_product(player_index, required, preferred_play_products)
			if playable_product != "":
				product_name = playable_product
			elif context_product != "":
				product_name = context_product
			else:
				product_name = _skill_play_product(skill, player_index)
		context["product"] = product_name
		var available := _player_product_flow(player_index, product_name)
		if available < required:
			return {}
		context["score"] = int(context["score"]) + available * 8
	if kind == "product_futures":
		var refreshed_futures_plan := _ai_product_futures_plan(player_index, skill, String(context.get("product", "")))
		if refreshed_futures_plan.is_empty():
			return {}
		context.merge(refreshed_futures_plan, true)
	var cash_cost := _skill_play_cash_cost(skill)
	if int((players[player_index] as Dictionary).get("cash", 0)) < cash_cost:
		return {}
	var target_owner := -999
	var context_district := int(context.get("district", -1))
	if context.has("target_owner"):
		target_owner = int(context.get("target_owner", -999))
	elif context_district >= 0 and context_district < districts.size():
		var target_city := _district_city(context_district)
		if _city_is_active(target_city):
			target_owner = int(target_city.get("owner", -1))
	var strategy_bonus := _ai_strategy_bonus_for_candidate(player_index, kind, context_district, String(context.get("product", "")), target_owner, skill)
	if strategy_bonus > 0:
		context["strategy_bonus"] = int(context.get("strategy_bonus", 0)) + strategy_bonus
		context["score"] = int(context["score"]) + strategy_bonus
	var route_bonus := _ai_route_plan_bonus_for_candidate(player_index, kind, context_district, String(context.get("product", "")), target_owner, skill)
	if route_bonus > 0:
		context["route_plan_bonus"] = int(context.get("route_plan_bonus", 0)) + route_bonus
		context["score"] = int(context["score"]) + route_bonus
	var route_gap := _ai_route_gap_adjustment(player_index, skill, context_district, String(context.get("product", "")), target_owner)
	var route_gap_bonus := int(route_gap.get("bonus", 0))
	var route_gap_penalty := int(route_gap.get("penalty", 0))
	if route_gap_bonus != 0 or route_gap_penalty != 0:
		context["route_gap_bonus"] = route_gap_bonus
		context["route_gap_penalty"] = route_gap_penalty
		context["route_gap_reason"] = String(route_gap.get("reason", ""))
		context["route_gap_field_match"] = int(route_gap.get("field_match", 0))
		context["score"] = int(context["score"]) + route_gap_bonus - route_gap_penalty
		if String(route_gap.get("reason", "")) != "":
			context["reason"] = "%s｜路线缺口:%s +%d/-%d" % [
				String(context.get("reason", "按卡牌策略评分")),
				String(route_gap.get("reason", "")),
				route_gap_bonus,
				route_gap_penalty,
			]
	var development_route_bonus := _ai_development_route_bonus(player_index, development_route)
	if development_route_bonus != 0:
		context["development_route_bonus"] = development_route_bonus
		context["score"] = int(context["score"]) + development_route_bonus
	var phase_bonus := _ai_phase_bonus_for_candidate(player_index, kind, context_district, String(context.get("product", "")), target_owner, skill)
	if phase_bonus != 0:
		context["phase_bonus"] = phase_bonus
		context["score"] = int(context["score"]) + phase_bonus
	var victory_race := _ai_victory_race_bonus_for_candidate(player_index, kind, context_district, String(context.get("product", "")), target_owner, skill)
	var victory_race_bonus := int(victory_race.get("bonus", 0))
	if victory_race_bonus != 0:
		context["victory_race_bonus"] = victory_race_bonus
		context["victory_race_role"] = String(victory_race.get("role", ""))
		context["victory_race_reason"] = String(victory_race.get("reason", ""))
		context["score"] = int(context["score"]) + victory_race_bonus
		context["reason"] = "%s｜终局竞速+%d:%s" % [
			String(context.get("reason", "按卡牌策略评分")),
			victory_race_bonus,
			String(victory_race.get("reason", "")),
		]
	var generic_bonus := _ai_generic_card_effect_score(player_index, skill, context_district, String(context.get("product", "")), target_owner)
	if generic_bonus != 0:
		context["generic_effect_bonus"] = generic_bonus
		context["score"] = int(context["score"]) + generic_bonus
	var profile_signature := _ai_profile_signature_bonus_for_candidate(player_index, kind, context_district, String(context.get("product", "")), target_owner, skill)
	var profile_signature_bonus := int(profile_signature.get("bonus", 0))
	if profile_signature_bonus != 0:
		context["profile_signature_bonus"] = profile_signature_bonus
		context["profile_signature_family"] = String(profile_signature.get("family", ""))
		context["profile_signature_route"] = String(profile_signature.get("route", ""))
		context["profile_signature_reason"] = String(profile_signature.get("reason", ""))
		context["score"] = int(context["score"]) + profile_signature_bonus
		context["reason"] = "%s｜性格签名+%d:%s" % [
			String(context.get("reason", "按卡牌策略评分")),
			profile_signature_bonus,
			String(profile_signature.get("reason", "")),
		]
	var learning_bonus := clampi(
		_ai_learning_bonus(player_index, String(context.get("policy_kind", kind)), String(context.get("strategy_intent", "")), String(context.get("route_plan_stage", "")), String(context.get("product", "")), "匿名出牌")
		+ _ai_development_route_learning_bonus(player_index, development_route),
		-AI_LEARNING_BONUS_CLAMP,
		AI_LEARNING_BONUS_CLAMP
	)
	if learning_bonus != 0:
		context["learning_bonus"] = learning_bonus
		context["score"] = int(context["score"]) + learning_bonus
	context["score"] = maxi(1, int(round(float(context["score"]) * _ai_card_kind_bias(player_index, kind))))
	return context
func _ai_card_play_candidates(player_index: int) -> Array:
	var result := []
	if not _player_is_ai(player_index) or float((players[player_index] as Dictionary).get("action_cooldown", 0.0)) > 0.0:
		return result
	if _queued_card_entry_index_for_player(player_index) >= 0 or _next_batch_card_entry_index_for_player(player_index) >= 0:
		return result
	var slots: Array = (players[player_index] as Dictionary).get("slots", [])
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var skill: Dictionary = slots[slot_index]
		if bool(skill.get("queued_for_resolution", false)) or float(skill.get("cooldown_left", 0.0)) > 0.0 or float(skill.get("lock_left", 0.0)) > 0.0:
			continue
		var context := _ai_card_play_context(player_index, slot_index, skill)
		if not context.is_empty():
			result.append(context)
	return result
func _ai_card_buy_candidates(player_index: int) -> Array:
	var result := []
	if not _player_is_ai(player_index) or float((players[player_index] as Dictionary).get("action_cooldown", 0.0)) > 0.0:
		return result
	var player: Dictionary = players[player_index]
	var cash := int(player.get("cash", 0))
	var profile := _ai_profile_for_player(player_index)
	var focus_product := _ai_focus_product(player_index)
	var strategy_intent := _ai_strategy_intent(player_index)
	var strategy_score := _ai_strategy_score(player_index)
	var route_product := _ai_route_plan_product(player_index)
	var route_stage := _ai_route_plan_stage(player_index)
	var route_score := _ai_route_plan_score(player_index)
	var phase_info := _ai_refresh_game_phase(player_index)
	var phase := String(phase_info.get("phase", "midgame"))
	var posture := String(phase_info.get("posture", "contesting"))
	var endgame_urgency := _ai_endgame_urgency_score(player_index)
	var phase_label := _ai_game_phase_label(phase)
	var posture_label := _ai_competitive_posture_label(posture)
	var counted_hand := _player_counted_hand_size(player)
	for district_index in range(districts.size()):
		if not _market_listing_purchasable(district_index) or bool(districts[district_index].get("destroyed", false)):
			continue
		for card_variant in _district_supply_card_ids(district_index):
			var card_name := _canonical_card_supply_name(String(card_variant))
			if card_name == "" or not _player_can_receive_card_with_discard(player, card_name):
				continue
			var price := _card_price(card_name, district_index, player_index)
			if cash - price < AI_CARD_BUY_MIN_CASH_RESERVE:
				continue
			var skill := _make_skill(card_name)
			var kind := String(skill.get("kind", ""))
			var development_route := _card_development_route_id(skill)
			var development_route_bias := _ai_development_route_bias(player_index, development_route)
			var development_route_bonus := _ai_development_route_bonus(player_index, development_route)
			var score := 55 + int(skill.get("cost", 2)) * 11 - int(round(float(price) / 12.0))
			var needs_discard := _purchase_requires_discard(player, card_name)
			var discard_slot := -1
			var discard_keep_value := 0
			var hand_pressure_penalty := 0
			if needs_discard:
				discard_slot = _ai_discard_slot_for_purchase(player_index, card_name)
				if discard_slot < 0:
					continue
				discard_keep_value = _ai_discard_keep_value(player_index, discard_slot)
				hand_pressure_penalty = maxi(45, int(round(float(discard_keep_value) * 0.55)) + 30)
			var focus_bonus := int(float(_ai_district_focus_score(player_index, district_index)) / 2.0)
			var family_slot := _find_highest_family_card_slot(player, card_name)
			if family_slot >= 0:
				score += 85
			var product_name := _ai_product_for_skill(player_index, skill)
			var futures_plan := {}
			if kind == "product_futures":
				futures_plan = _ai_product_futures_plan(player_index, skill, product_name)
				if bool(_product_futures_terms(skill).get("requires_warehouse", false)) and futures_plan.is_empty():
					continue
				if not futures_plan.is_empty():
					product_name = String(futures_plan.get("product", product_name))
			var military_plan := {}
			var military_deploy_bonus := 0
			if kind == "military_force":
				military_plan = _ai_military_deploy_plan(player_index, skill)
				if military_plan.is_empty():
					continue
				military_deploy_bonus = int(float(int(military_plan.get("score", 0))) / 2.0)
			var required := _skill_play_flow_required(skill, player_index)
			var available := _player_product_flow(player_index, product_name)
			var probable_play_district := _best_player_gdp_share_district(player_index)
			var requirement_metadata := _ai_play_requirement_metadata(player_index, skill, probable_play_district)
			var required_share_percent := int(requirement_metadata.get("required_share_percent", 0))
			var current_share_percent := int(floor(float(requirement_metadata.get("current_share_percent", 0.0))))
			var requirement_satisfied := bool(requirement_metadata.get("requirement_satisfied", false))
			var playability_bonus := 0
			var strategy_bonus := _ai_strategy_bonus_for_candidate(player_index, kind, district_index, product_name, -999, skill)
			var route_bonus := _ai_route_plan_bonus_for_candidate(player_index, kind, district_index, product_name, -999, skill)
			var target_owner := -999
			var city := _district_city(district_index)
			if _city_is_active(city):
				target_owner = int(city.get("owner", -1))
			var generic_bonus := _ai_generic_card_effect_score(player_index, skill, district_index, product_name, target_owner)
			var phase_bonus := _ai_phase_bonus_for_candidate(player_index, kind, district_index, product_name, target_owner, skill)
			var victory_race := _ai_victory_race_bonus_for_candidate(player_index, kind, district_index, product_name, target_owner, skill)
			var victory_race_bonus := int(victory_race.get("bonus", 0))
			var profile_signature := _ai_profile_signature_bonus_for_candidate(player_index, kind, district_index, product_name, target_owner, skill)
			var profile_signature_bonus := int(profile_signature.get("bonus", 0))
			var route_gap := _ai_route_gap_adjustment(player_index, skill, district_index, product_name, target_owner)
			var route_gap_bonus := int(route_gap.get("bonus", 0))
			var route_gap_penalty := int(route_gap.get("penalty", 0))
			var route_gap_reason := String(route_gap.get("reason", ""))
			var route_gap_field_match := int(route_gap.get("field_match", 0))
			var route_inventory := _ai_route_inventory_adjustment(player_index, development_route, required, available, counted_hand, route_bonus, development_route_bonus)
			var route_inventory_bonus := int(route_inventory.get("bonus", 0))
			var route_inventory_penalty := int(route_inventory.get("penalty", 0))
			var route_hand_total := int(route_inventory.get("total", 0))
			var route_hand_playable := int(route_inventory.get("playable", 0))
			var route_hand_blocked := int(route_inventory.get("blocked_flow", 0))
			var learning_bonus := clampi(
				_ai_learning_bonus(player_index, kind, strategy_intent, route_stage, product_name, "区域购牌")
				+ _ai_development_route_learning_bonus(player_index, development_route),
				-AI_LEARNING_BONUS_CLAMP,
				AI_LEARNING_BONUS_CLAMP
			)
			if requirement_satisfied:
				playability_bonus = 55 + mini(45, maxi(0, current_share_percent))
			else:
				playability_bonus = -(required_share_percent - current_share_percent) * (4 + counted_hand)
			score += playability_bonus
			if needs_discard:
				score -= hand_pressure_penalty
			elif counted_hand >= PLAYER_HAND_LIMIT - 1 and not requirement_satisfied:
				hand_pressure_penalty = 38 + maxi(0, required_share_percent - current_share_percent) * 4
				score -= hand_pressure_penalty
			if focus_product != "" and product_name == focus_product:
				focus_bonus += AI_ECONOMIC_FOCUS_MATCH_BONUS
			if ["product_speculation", "product_futures", "product_contract_boon", "product_growth_boon", "city_product_shift", "city_demand_shift", "route_flow_boon", "region_economy_shift"].has(kind) and focus_bonus > 0:
				score += focus_bonus
			if strategy_bonus > 0:
				score += strategy_bonus
			if route_bonus > 0:
				score += route_bonus
			if route_gap_bonus != 0:
				score += route_gap_bonus
			if route_gap_penalty != 0:
				score -= route_gap_penalty
			if development_route_bonus != 0:
				score += development_route_bonus
			if route_inventory_bonus != 0:
				score += route_inventory_bonus
			if route_inventory_penalty != 0:
				score -= route_inventory_penalty
			if generic_bonus != 0:
				score += generic_bonus
			if profile_signature_bonus != 0:
				score += profile_signature_bonus
			if military_deploy_bonus != 0:
				score += military_deploy_bonus
			if phase_bonus != 0:
				score += phase_bonus
			if victory_race_bonus != 0:
				score += victory_race_bonus
			if learning_bonus != 0:
				score += learning_bonus
			var role := _player_role_card_for_index(player_index)
			if String(role.get("bonus_card_product", "")) != "" and _district_or_city_has_product(district_index, String(role.get("bonus_card_product", ""))):
				score += 65
			score = maxi(1, int(round(float(score) * _ai_card_kind_bias(player_index, kind))))
			var candidate := {
				"action": "购牌",
				"card_name": card_name,
				"kind": kind,
				"policy_kind": kind,
				"district": district_index,
				"product": product_name,
				"price": price,
				"score": score,
				"focus_product": focus_product,
				"focus_score": _ai_focus_score(player_index),
				"focus_bonus": focus_bonus,
				"strategy_intent": strategy_intent,
				"strategy_score": strategy_score,
				"strategy_bonus": strategy_bonus,
				"route_plan_product": route_product,
				"route_plan_stage": route_stage,
				"route_plan_score": route_score,
				"route_plan_bonus": route_bonus,
				"route_gap_bonus": route_gap_bonus,
				"route_gap_penalty": route_gap_penalty,
				"route_gap_reason": route_gap_reason,
				"route_gap_field_match": route_gap_field_match,
				"development_route": development_route,
				"development_route_label": _development_route_label(development_route),
				"development_route_bias": development_route_bias,
				"development_route_bonus": development_route_bonus,
				"route_inventory_bonus": route_inventory_bonus,
				"route_inventory_penalty": route_inventory_penalty,
				"route_hand_total": route_hand_total,
				"route_hand_playable": route_hand_playable,
				"route_hand_blocked": route_hand_blocked,
				"game_phase": phase,
				"competitive_posture": posture,
				"score_gap_to_leader": int(phase_info.get("gap", 0)),
				"leader_index": int(phase_info.get("leader_index", -1)),
				"endgame_urgency": endgame_urgency,
				"phase_bonus": phase_bonus,
				"victory_race_bonus": victory_race_bonus,
				"victory_race_role": String(victory_race.get("role", "")),
				"victory_race_reason": String(victory_race.get("reason", "")),
				"generic_effect_bonus": generic_bonus,
				"profile_signature_bonus": profile_signature_bonus,
				"profile_signature_family": String(profile_signature.get("family", "")),
				"profile_signature_route": String(profile_signature.get("route", "")),
				"profile_signature_reason": String(profile_signature.get("reason", "")),
				"learning_bonus": learning_bonus,
				"playability_bonus": playability_bonus,
				"hand_pressure_penalty": hand_pressure_penalty,
				"requires_discard": needs_discard,
				"discard_slot": discard_slot,
				"discard_keep_value": discard_keep_value,
				"counted_hand": counted_hand,
				"reason": "%s｜费用¥%d｜GDP份额%d/%d%%｜可打出%s｜手压-%d｜路线缺口%s+%d/-%d｜路线库存%d/%d/%d +%d/-%d｜阶段%s/%s+%d｜终局紧迫%d｜终局竞速+%d:%s｜策略%s+%d｜商品路线%s/%s+%d｜发展%s+%d｜性格签名+%d:%s｜学习%d｜探索率%.0f%%" % [
					_card_display_name(card_name),
					price,
					current_share_percent,
					required_share_percent,
					_signed_int_text(playability_bonus),
					hand_pressure_penalty,
					"%s:" % route_gap_reason if route_gap_reason != "" else "",
					route_gap_bonus,
					route_gap_penalty,
					route_hand_total,
					route_hand_playable,
					route_hand_blocked,
					route_inventory_bonus,
					route_inventory_penalty,
					phase_label,
					posture_label,
					phase_bonus,
					endgame_urgency,
					victory_race_bonus,
					String(victory_race.get("reason", "")),
					strategy_intent if strategy_intent != "" else "未定",
					strategy_bonus,
					route_product if route_product != "" else "未定",
					_ai_route_plan_stage_label(route_stage),
					route_bonus,
					_development_route_label(development_route),
					development_route_bonus,
					profile_signature_bonus,
					String(profile_signature.get("reason", "")),
					learning_bonus,
					float(profile.get("exploration", 0.15)) * 100.0,
				],
			}
			candidate.merge(requirement_metadata, true)
			if not futures_plan.is_empty():
				for field_name in ["policy_kind", "target_city", "target_owner", "futures_direction", "futures_signal", "futures_market_score", "futures_stockpile_score", "futures_stockpile_units", "futures_duration_seconds", "futures_multiplier_x100", "futures_margin_cash", "futures_maximum_gain", "futures_maximum_loss", "futures_risk_adjusted_ev", "futures_warehouse_city", "futures_warehouse_required", "futures_product_flow"]:
					if futures_plan.has(field_name):
						candidate[field_name] = futures_plan[field_name]
				candidate["futures_play_district"] = int(futures_plan.get("district", -1))
				candidate["futures_reason"] = String(futures_plan.get("reason", ""))
				candidate["reason"] = "%s｜期货信号%d｜%s" % [
					String(candidate.get("reason", "")),
					int(futures_plan.get("futures_signal", 0)),
					String(futures_plan.get("reason", "")),
				]
			if not military_plan.is_empty():
				for field_name in ["policy_kind", "target_city", "target_owner", "military_deploy_role", "military_deploy_score", "military_deploy_terrain", "military_deploy_route_load", "military_deploy_monster_risk", "military_unit_type", "strategic_role"]:
					if military_plan.has(field_name):
						candidate[field_name] = military_plan[field_name]
				candidate["military_deploy_district"] = int(military_plan.get("district", -1))
				candidate["reason"] = "%s｜军事部署+%d｜%s" % [
					String(candidate.get("reason", "")),
					military_deploy_bonus,
					String(military_plan.get("reason", "")),
				]
			result.append(candidate)
	return result
func _ai_pick_candidate(player_index: int, candidates: Array, force: bool = false) -> Dictionary:
	if candidates.is_empty():
		return {}
	var ordered := candidates.duplicate(true)
	ordered.sort_custom(Callable(self, "_sort_ai_candidate_score_desc"))
	var exploration := float(_ai_profile_for_player(player_index).get("exploration", 0.15))
	if force or ordered.size() == 1 or rng.randf() >= exploration:
		return ordered[0] as Dictionary
	var top_count := mini(4, ordered.size())
	var weights := []
	for i in range(top_count):
		weights.append(maxi(1, int((ordered[i] as Dictionary).get("score", 1))))
	var picked := _weighted_pick_index(weights)
	return ordered[picked] as Dictionary if picked >= 0 else ordered[0] as Dictionary
func _ai_card_decision_metadata(candidate: Dictionary, target_slot: int) -> Dictionary:
	var metadata := {
		"card_name": String(candidate.get("card_name", "")),
		"target_slot": target_slot,
		"target_player": int(candidate.get("target_player", -1)),
	}
	for field_name in _ai_training_metadata_field_names():
		if candidate.has(field_name):
			metadata[field_name] = candidate[field_name]
	return metadata
func _ai_queue_play_candidate(player_index: int, candidate: Dictionary, all_candidates: Array = []) -> bool:
	var slot_index := int(candidate.get("slot_index", -1))
	var target_slot := int(candidate.get("target_slot", -1))
	var target_player := int(candidate.get("target_player", -1))
	var previous_player := int(selected_player)
	var previous_district := int(selected_district)
	var previous_product := str(selected_trade_product)
	var previous_source := int(selected_contract_source_district)
	var previous_target := int(selected_contract_target_district)
	selected_player = player_index
	selected_district = int(candidate.get("district", _ai_first_alive_district()))
	selected_trade_product = String(candidate.get("product", ""))
	selected_contract_source_district = int(candidate.get("contract_source", -1))
	selected_contract_target_district = int(candidate.get("contract_target", -1))
	var queued := _queue_skill_resolution(player_index, slot_index, target_slot, target_player)
	if queued:
		var queue_index := _queued_card_entry_index_for_player(player_index)
		var in_next_batch := false
		if queue_index < 0:
			queue_index = _next_batch_card_entry_index_for_player(player_index)
			in_next_batch = true
		if queue_index >= 0:
			var entry: Dictionary = (_card_resolution_next_queue()[queue_index] if in_next_batch else _card_resolution_current_queue()[queue_index]) as Dictionary
			entry["ai_utility_score"] = int(candidate.get("score", 0))
			entry["ai_reason"] = String(candidate.get("reason", ""))
			_store_card_resolution_entry(entry)
		var decision_metadata := _ai_card_decision_metadata(candidate, target_slot)
		if String(decision_metadata.get("focus_product", "")) == "":
			decision_metadata["focus_product"] = _ai_focus_product(player_index)
			decision_metadata["focus_score"] = _ai_focus_score(player_index)
		if String(decision_metadata.get("strategy_intent", "")) == "":
			decision_metadata["strategy_intent"] = _ai_strategy_intent(player_index)
			decision_metadata["strategy_score"] = _ai_strategy_score(player_index)
		if String(decision_metadata.get("route_plan_product", "")) == "":
			decision_metadata["route_plan_product"] = _ai_route_plan_product(player_index)
			decision_metadata["route_plan_stage"] = _ai_route_plan_stage(player_index)
			decision_metadata["route_plan_score"] = _ai_route_plan_score(player_index)
		_record_ai_decision(
			player_index,
			"匿名出牌",
			int(candidate.get("district", -1)),
			int(candidate.get("score", 0)),
			"%s｜目标%s｜%s" % [
				String(candidate.get("card_name", "卡牌")),
				("玩家%d" % (target_player + 1)) if target_player >= 0 else ("怪兽%d" % (target_slot + 1) if target_slot >= 0 else "当前区域/商品"),
				String(candidate.get("reason", "按卡牌策略评分")),
			],
			all_candidates,
			decision_metadata
		)
	selected_player = previous_player
	selected_district = previous_district
	selected_trade_product = previous_product
	selected_contract_source_district = previous_source
	selected_contract_target_district = previous_target
	return queued
func ai_v06_facility_bootstrap_public_snapshot() -> Dictionary:
	var capability := _ai_v06_economy_port_capability()
	return {
		"available": bool(capability.get("available", false)),
		"revision": 1,
		"reason_code": str(_v06_facility_bootstrap_last_public.get("reason_code", "ai_v06_facility_bootstrap_idle")),
		"state": str(_v06_facility_bootstrap_last_public.get("state", "idle")),
		"attempt_count": _v06_facility_bootstrap_attempt_count,
		"success_count": _v06_facility_bootstrap_success_count,
	}


func execute_v06_facility_bootstrap_cycle(force: bool = false) -> Dictionary:
	return _auto_ai_v06_facility_bootstrap(force)


func _ai_v06_economy_port_capability() -> Dictionary:
	if _v06_economy_action_port == null or not is_instance_valid(_v06_economy_action_port) or not _v06_economy_action_port.has_method("capability_snapshot"):
		return {
			"available": false,
			"revision": 0,
			"reason_code": "ai_v06_economy_port_unavailable",
		}
	var value_variant: Variant = _v06_economy_action_port.call("capability_snapshot")
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {
		"available": false,
		"revision": 0,
		"reason_code": "ai_v06_economy_port_capability_invalid",
	}


func _ai_v06_facility_failure(reason_code: String, attempted: bool = false) -> Dictionary:
	return {
		"available": false,
		"attempted": attempted,
		"committed": false,
		"finalized": false,
		"reason_code": reason_code,
	}


func _ai_v06_actor_id(player_index: int) -> String:
	if player_index < 0 or _v06_economy_action_port == null or not _v06_economy_action_port.has_method("actor_id_for_player_index"):
		return ""
	var identity_variant: Variant = _v06_economy_action_port.call("actor_id_for_player_index", player_index)
	var identity: Dictionary = identity_variant if identity_variant is Dictionary else {}
	if not bool(identity.get("available", false)):
		return ""
	return str(identity.get("actor_id", "")).strip_edges()


func _ai_v06_starter_status(actor_id: String) -> Dictionary:
	if actor_id.is_empty() or _monster_runtime_controller == null or not _monster_runtime_controller.has_method("monster_starter_state_snapshot_v06"):
		return {
			"available": false,
			"reason_code": "ai_v06_starter_owner_unavailable",
		}
	var value_variant: Variant = _monster_runtime_controller.call("monster_starter_state_snapshot_v06", actor_id)
	if not (value_variant is Dictionary):
		return {
			"available": false,
			"reason_code": "ai_v06_starter_snapshot_invalid",
		}
	var snapshot := value_variant as Dictionary
	if not bool(snapshot.get("available", false)):
		return {
			"available": false,
			"reason_code": str(snapshot.get("reason_code", "ai_v06_starter_snapshot_unavailable")),
		}
	if str(snapshot.get("state", "")) != "summoned" or int(snapshot.get("unit_uid", 0)) <= 0:
		return {
			"available": false,
			"reason_code": "ai_v06_starter_not_completed",
		}
	return {
		"available": true,
		"reason_code": "ai_v06_starter_completed",
	}


func _ai_v06_authoritative_target_region(primary: Dictionary, fallback: Dictionary = {}) -> String:
	for snapshot in [primary, fallback]:
		var target_region_id := str((snapshot as Dictionary).get("target_region_id", "")).strip_edges()
		if not target_region_id.is_empty():
			return target_region_id
		var legal_regions_variant: Variant = (snapshot as Dictionary).get("legal_region_ids", [])
		if not (legal_regions_variant is Array):
			continue
		for region_id_variant in legal_regions_variant as Array:
			var region_id := str(region_id_variant).strip_edges()
			if not region_id.is_empty():
				return region_id
	return ""


func _ai_v06_facility_card_binding(player_snapshot: Dictionary, expected_card_id: String = "") -> Dictionary:
	var cards_variant: Variant = player_snapshot.get("cards", [])
	if not (cards_variant is Array):
		return {}
	for card_variant in cards_variant as Array:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		if not bool(card.get("bootstrap_eligible", false)) \
				or str(card.get("category_id", "")) != AI_V06_FACILITY_CATEGORY \
				or int(card.get("rank", 0)) != 1 \
				or str(card.get("effect_kind", "")) != AI_V06_FACILITY_EFFECT_KIND:
			continue
		if not expected_card_id.is_empty() and str(card.get("card_id", "")) != expected_card_id:
			continue
		var slot_index := int(card.get("slot_index", -1))
		var runtime_instance_id := str(card.get("runtime_instance_id", "")).strip_edges()
		if slot_index < 0 or runtime_instance_id.is_empty():
			continue
		return {
			"slot_index": slot_index,
			"runtime_instance_id": runtime_instance_id,
		}
	return {}


func _ai_v06_facility_listing(market_snapshot: Dictionary) -> Dictionary:
	var listing_variant: Variant = market_snapshot.get("listing", {})
	if not (listing_variant is Dictionary):
		return {}
	var listing := listing_variant as Dictionary
	if not bool(listing.get("canonical", false)) \
			or not bool(listing.get("bootstrap_eligible", false)) \
			or str(listing.get("category_id", "")) != AI_V06_FACILITY_CATEGORY \
			or int(listing.get("rank", 0)) != 1 \
			or str(listing.get("effect_kind", "")) != AI_V06_FACILITY_EFFECT_KIND:
		return {}
	var item_id := str(listing.get("item_id", "")).strip_edges()
	var card_id := str(listing.get("card_id", "")).strip_edges()
	var purchase_cash := int(listing.get("purchase_cash", -1))
	if item_id.is_empty() or card_id.is_empty() or purchase_cash < 0:
		return {}
	return {
		"item_id": item_id,
		"card_id": card_id,
		"purchase_cash": purchase_cash,
		"target_region_id": str(listing.get("target_region_id", "")).strip_edges(),
		"legal_region_ids": (listing.get("legal_region_ids", []) as Array).duplicate(true) if listing.get("legal_region_ids", []) is Array else [],
	}


func _ai_v06_facility_bootstrap_candidate(player_index: int, force: bool = false) -> Dictionary:
	var capability := _ai_v06_economy_port_capability()
	if not bool(capability.get("available", false)):
		return _ai_v06_facility_failure(str(capability.get("reason_code", "ai_v06_economy_port_unavailable")))
	if not _configured or not _world_ready() or player_index < 0 or not _player_is_ai(player_index) or _player_is_eliminated(player_index):
		return _ai_v06_facility_failure("ai_v06_facility_player_unavailable")
	var world_players: Array = players
	if player_index >= world_players.size() or not (world_players[player_index] is Dictionary):
		return _ai_v06_facility_failure("ai_v06_facility_player_unavailable")
	var world_player := world_players[player_index] as Dictionary
	if not force and float(world_player.get("action_cooldown", 0.0)) > 0.0:
		return _ai_v06_facility_failure("ai_v06_facility_action_cooldown")
	var actor_id := _ai_v06_actor_id(player_index)
	if actor_id.is_empty():
		return _ai_v06_facility_failure("ai_v06_facility_actor_missing")
	var starter_status := _ai_v06_starter_status(actor_id)
	if not bool(starter_status.get("available", false)):
		return _ai_v06_facility_failure(str(starter_status.get("reason_code", "ai_v06_starter_not_completed")))
	var source_variant: Variant = _v06_economy_action_port.call("economic_source_snapshot", actor_id)
	var source_snapshot: Dictionary = (source_variant as Dictionary).duplicate(true) if source_variant is Dictionary else {}
	if not bool(source_snapshot.get("available", false)):
		return _ai_v06_facility_failure(str(source_snapshot.get("reason_code", "ai_v06_economic_source_unavailable")))
	var source_revision := int(source_snapshot.get("revision", -1))
	if source_revision < 0:
		return _ai_v06_facility_failure("ai_v06_economic_source_revision_invalid")
	if bool(source_snapshot.get("has_source", false)):
		return _ai_v06_facility_failure("ai_v06_economic_source_already_exists")
	if bool(source_snapshot.get("bootstrap_finalized", false)):
		return _ai_v06_facility_failure("ai_v06_facility_bootstrap_already_finalized")
	var player_variant: Variant = _v06_economy_action_port.call("player_snapshot", actor_id)
	var player_snapshot: Dictionary = (player_variant as Dictionary).duplicate(true) if player_variant is Dictionary else {}
	if not bool(player_snapshot.get("available", false)):
		return _ai_v06_facility_failure(str(player_snapshot.get("reason_code", "ai_v06_player_snapshot_unavailable")))
	var player_revision := int(player_snapshot.get("revision", -1))
	if player_revision < 0 or not player_snapshot.has("cash"):
		return _ai_v06_facility_failure("ai_v06_player_snapshot_invalid")
	var existing_card := _ai_v06_facility_card_binding(player_snapshot)
	if not existing_card.is_empty():
		var existing_target_region_id := _ai_v06_authoritative_target_region(source_snapshot)
		if existing_target_region_id.is_empty():
			return _ai_v06_facility_failure("ai_v06_facility_authoritative_target_unavailable")
		return {
			"available": true,
			"reason_code": "ai_v06_facility_existing_card_ready",
			"policy_kind": AI_V06_FACILITY_BOOTSTRAP_POLICY_KIND,
			"action_kind": "play_existing_facility",
			"player_index": player_index,
			"actor_id": actor_id,
			"region_id": existing_target_region_id,
			"expected_player_revision": player_revision,
			"expected_source_revision": source_revision,
			"purchase_required": false,
		}
	var market_variant: Variant = _v06_economy_action_port.call("market_snapshot", actor_id)
	var market_snapshot: Dictionary = (market_variant as Dictionary).duplicate(true) if market_variant is Dictionary else {}
	if not bool(market_snapshot.get("available", false)):
		return _ai_v06_facility_failure(str(market_snapshot.get("reason_code", "ai_v06_market_snapshot_unavailable")))
	var market_revision := int(market_snapshot.get("revision", -1))
	var listing := _ai_v06_facility_listing(market_snapshot)
	if market_revision < 0 or listing.is_empty():
		return _ai_v06_facility_failure("ai_v06_canonical_rank_i_facility_unavailable")
	var region_id := _ai_v06_authoritative_target_region(listing, source_snapshot)
	if region_id.is_empty():
		return _ai_v06_facility_failure("ai_v06_facility_authoritative_target_unavailable")
	if int(player_snapshot.get("cash", -1)) < int(listing.get("purchase_cash", 0)):
		return _ai_v06_facility_failure("ai_v06_facility_cash_insufficient")
	return {
		"available": true,
		"reason_code": "ai_v06_facility_purchase_ready",
		"policy_kind": AI_V06_FACILITY_BOOTSTRAP_POLICY_KIND,
		"action_kind": "purchase_and_play_facility",
		"player_index": player_index,
		"actor_id": actor_id,
		"region_id": region_id,
		"item_id": str(listing.get("item_id", "")),
		"card_id": str(listing.get("card_id", "")),
		"expected_market_revision": market_revision,
		"expected_player_revision": player_revision,
		"expected_source_revision": source_revision,
		"purchase_required": true,
	}


func _ai_v06_facility_transaction_id(operation: String, binding: Dictionary) -> String:
	return "ai-v06-%s:%s" % [operation, JSON.stringify(binding).sha256_text()]


func _ai_execute_v06_facility_bootstrap_for_player(player_index: int, force: bool = false) -> Dictionary:
	var candidate := _ai_v06_facility_bootstrap_candidate(player_index, force)
	if not bool(candidate.get("available", false)):
		return candidate
	var actor_id := str(candidate.get("actor_id", ""))
	var expected_card_id := str(candidate.get("card_id", ""))
	if bool(candidate.get("purchase_required", false)):
		var purchase_transaction_id := _ai_v06_facility_transaction_id("facility-purchase", {
			"actor_id": actor_id,
			"item_id": str(candidate.get("item_id", "")),
			"market_revision": int(candidate.get("expected_market_revision", -1)),
			"player_revision": int(candidate.get("expected_player_revision", -1)),
			"source_revision": int(candidate.get("expected_source_revision", -1)),
		})
		var purchase_variant: Variant = _v06_economy_action_port.call(
			"purchase_rank_i_facility",
			actor_id,
			str(candidate.get("item_id", "")),
			purchase_transaction_id,
			int(candidate.get("expected_market_revision", -1)),
			int(candidate.get("expected_player_revision", -1)),
			int(candidate.get("expected_source_revision", -1))
		)
		var purchase: Dictionary = (purchase_variant as Dictionary).duplicate(true) if purchase_variant is Dictionary else {}
		if not bool(purchase.get("available", false)) or not bool(purchase.get("committed", false)):
			return _ai_v06_facility_failure(str(purchase.get("reason_code", "ai_v06_facility_purchase_rejected")), true)
	var player_variant: Variant = _v06_economy_action_port.call("player_snapshot", actor_id)
	var player_snapshot: Dictionary = (player_variant as Dictionary).duplicate(true) if player_variant is Dictionary else {}
	if not bool(player_snapshot.get("available", false)):
		return _ai_v06_facility_failure(str(player_snapshot.get("reason_code", "ai_v06_player_snapshot_unavailable")), true)
	var card_binding := _ai_v06_facility_card_binding(player_snapshot, expected_card_id)
	if card_binding.is_empty():
		return _ai_v06_facility_failure("ai_v06_purchased_facility_binding_missing", true)
	var runtime_instance_id := str(card_binding.get("runtime_instance_id", ""))
	var play_transaction_id := _ai_v06_facility_transaction_id("facility-play", {
		"actor_id": actor_id,
		"region_id": str(candidate.get("region_id", "")),
		"runtime_instance_id": runtime_instance_id,
	})
	var play_variant: Variant = _v06_economy_action_port.call("play_runtime_card", {
		"actor_id": actor_id,
		"slot_index": int(card_binding.get("slot_index", -1)),
		"runtime_instance_id": runtime_instance_id,
		"transaction_id": play_transaction_id,
		"region_id": str(candidate.get("region_id", "")),
		"expected_player_revision": int(player_snapshot.get("revision", -1)),
		"expected_source_revision": int(candidate.get("expected_source_revision", -1)),
	})
	var play: Dictionary = (play_variant as Dictionary).duplicate(true) if play_variant is Dictionary else {}
	if not bool(play.get("available", false)) or not bool(play.get("committed", false)):
		return _ai_v06_facility_failure(str(play.get("reason_code", "ai_v06_facility_play_rejected")), true)
	var finalization: Dictionary = play.get("effect_finalization", {}) if play.get("effect_finalization", {}) is Dictionary else {}
	if not bool(play.get("finalized", finalization.get("finalized", false))):
		return _ai_v06_facility_failure("ai_v06_facility_play_not_finalized", true)
	return {
		"available": true,
		"attempted": true,
		"committed": true,
		"finalized": true,
		"reason_code": "ai_v06_facility_bootstrap_finalized",
	}


func _auto_ai_v06_facility_bootstrap(force: bool = false) -> Dictionary:
	if session_finished or not ai_card_decision_enabled:
		return {
			"available": false,
			"revision": 1,
			"acted": 0,
			"attempted": 0,
			"reason_code": "ai_v06_facility_bootstrap_disabled",
		}
	var acted := 0
	var attempted := 0
	for player_index_variant in _ai_player_indices():
		var result := _ai_execute_v06_facility_bootstrap_for_player(int(player_index_variant), force)
		if bool(result.get("attempted", false)):
			attempted += 1
			_v06_facility_bootstrap_attempt_count += 1
		if bool(result.get("committed", false)) and bool(result.get("finalized", false)):
			acted = 1
			_v06_facility_bootstrap_success_count += 1
			break
	var port_available := bool(_ai_v06_economy_port_capability().get("available", false))
	var public_reason := "ai_v06_facility_bootstrap_finalized" if acted > 0 else (
		"ai_v06_facility_bootstrap_attempted" if attempted > 0 else (
			"ai_v06_facility_bootstrap_no_action" if port_available else "ai_v06_facility_bootstrap_unavailable"
		)
	)
	_v06_facility_bootstrap_last_public = {
		"state": "finalized" if acted > 0 else ("attempted" if attempted > 0 else "idle"),
		"reason_code": public_reason,
	}
	return {
		"available": port_available,
		"revision": 1,
		"acted": acted,
		"attempted": attempted,
		"reason_code": public_reason,
	}


func _ai_execute_card_turn(player_index: int, force: bool = false) -> String:
	var play_candidates := _ai_card_play_candidates(player_index)
	var play_choice := _ai_pick_candidate(player_index, play_candidates, force)
	if not play_choice.is_empty() and _ai_queue_play_candidate(player_index, play_choice, play_candidates):
		return "play"
	var buy_candidates := _ai_card_buy_candidates(player_index)
	var buy_choice := _ai_pick_candidate(player_index, buy_candidates, force)
	if buy_choice.is_empty():
		return "wait"
	var district_index := int(buy_choice.get("district", -1))
	var card_name := String(buy_choice.get("card_name", ""))
	if _buy_card_for_player_from_district(player_index, district_index, card_name, true, force, int(buy_choice.get("discard_slot", -1))):
		_record_ai_decision(
			player_index,
			"区域购牌",
			district_index,
			int(buy_choice.get("score", 0)),
			String(buy_choice.get("reason", "按价格、流动与手牌协同评分")),
			buy_candidates,
			{
				"card_name": card_name,
				"price": int(buy_choice.get("price", 0)),
				"product": String(buy_choice.get("product", "")),
				"focus_product": String(buy_choice.get("focus_product", "")),
				"focus_score": int(buy_choice.get("focus_score", 0)),
				"focus_bonus": int(buy_choice.get("focus_bonus", 0)),
				"strategy_intent": String(buy_choice.get("strategy_intent", "")),
				"strategy_score": int(buy_choice.get("strategy_score", 0)),
				"strategy_bonus": int(buy_choice.get("strategy_bonus", 0)),
				"route_plan_product": String(buy_choice.get("route_plan_product", "")),
				"route_plan_stage": String(buy_choice.get("route_plan_stage", "")),
				"route_plan_score": int(buy_choice.get("route_plan_score", 0)),
				"route_plan_bonus": int(buy_choice.get("route_plan_bonus", 0)),
				"route_gap_bonus": int(buy_choice.get("route_gap_bonus", 0)),
				"route_gap_penalty": int(buy_choice.get("route_gap_penalty", 0)),
				"route_gap_reason": String(buy_choice.get("route_gap_reason", "")),
				"route_gap_field_match": int(buy_choice.get("route_gap_field_match", 0)),
				"development_route": String(buy_choice.get("development_route", "")),
				"development_route_label": String(buy_choice.get("development_route_label", "")),
				"development_route_bias": float(buy_choice.get("development_route_bias", 1.0)),
				"development_route_bonus": int(buy_choice.get("development_route_bonus", 0)),
				"route_inventory_bonus": int(buy_choice.get("route_inventory_bonus", 0)),
				"route_inventory_penalty": int(buy_choice.get("route_inventory_penalty", 0)),
				"route_hand_total": int(buy_choice.get("route_hand_total", 0)),
				"route_hand_playable": int(buy_choice.get("route_hand_playable", 0)),
				"route_hand_blocked": int(buy_choice.get("route_hand_blocked", 0)),
				"game_phase": String(buy_choice.get("game_phase", "")),
				"competitive_posture": String(buy_choice.get("competitive_posture", "")),
				"score_gap_to_leader": int(buy_choice.get("score_gap_to_leader", 0)),
				"leader_index": int(buy_choice.get("leader_index", -1)),
				"endgame_urgency": int(buy_choice.get("endgame_urgency", 0)),
				"phase_bonus": int(buy_choice.get("phase_bonus", 0)),
				"victory_race_bonus": int(buy_choice.get("victory_race_bonus", 0)),
				"victory_race_role": String(buy_choice.get("victory_race_role", "")),
				"victory_race_reason": String(buy_choice.get("victory_race_reason", "")),
				"generic_effect_bonus": int(buy_choice.get("generic_effect_bonus", 0)),
				"profile_signature_bonus": int(buy_choice.get("profile_signature_bonus", 0)),
				"profile_signature_family": String(buy_choice.get("profile_signature_family", "")),
				"profile_signature_route": String(buy_choice.get("profile_signature_route", "")),
				"profile_signature_reason": String(buy_choice.get("profile_signature_reason", "")),
				"policy_kind": String(buy_choice.get("policy_kind", buy_choice.get("kind", ""))),
				"learning_bonus": int(buy_choice.get("learning_bonus", 0)),
				"playability_bonus": int(buy_choice.get("playability_bonus", 0)),
				"hand_pressure_penalty": int(buy_choice.get("hand_pressure_penalty", 0)),
				"requires_discard": bool(buy_choice.get("requires_discard", false)),
				"discard_keep_value": int(buy_choice.get("discard_keep_value", 0)),
				"counted_hand": int(buy_choice.get("counted_hand", 0)),
			}
		)
		return "buy"
	return "wait"
func _auto_ai_card_decisions(force: bool = false) -> int:
	if session_finished or not ai_card_decision_enabled:
		return 0
	var acted := 0
	for player_index_variant in _ai_player_indices():
		var result := _ai_execute_card_turn(int(player_index_variant), force)
		if result != "wait":
			acted += 1
	return acted
func _ai_counter_response_candidates(player_index: int) -> Array:
	var result := []
	if not _player_is_ai(player_index) or not card_resolution_counter_window_active or _card_resolution_active_entry().is_empty():
		return result
	if float((players[player_index] as Dictionary).get("action_cooldown", 0.0)) > 0.0:
		return result
	if _queued_card_entry_index_for_player(player_index) >= 0 or _next_batch_card_entry_index_for_player(player_index) >= 0:
		return result
	var slots: Array = (players[player_index] as Dictionary).get("slots", [])
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var source_skill: Dictionary = slots[slot_index]
		if bool(source_skill.get("queued_for_resolution", false)) or float(source_skill.get("cooldown_left", 0.0)) > 0.0 or float(source_skill.get("lock_left", 0.0)) > 0.0:
			continue
		var candidate := _ai_counter_response_candidate(player_index, slot_index, source_skill)
		if not candidate.is_empty():
			result.append(candidate)
	return result
func _ai_queue_counter_response_candidate(player_index: int, candidate: Dictionary, all_candidates: Array = []) -> bool:
	var slot_index := int(candidate.get("slot_index", -1))
	if player_index < 0 or player_index >= players.size():
		return false
	var slots: Array = (players[player_index] as Dictionary).get("slots", [])
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return false
	var source_skill: Dictionary = slots[slot_index]
	var previous_player := int(selected_player)
	var previous_district := int(selected_district)
	var previous_product := str(selected_trade_product)
	selected_player = player_index
	selected_district = int(candidate.get("district", int(_card_resolution_active_entry().get("selected_district", _ai_first_alive_district()))))
	selected_trade_product = String(candidate.get("product", _skill_play_product(source_skill, player_index)))
	var queued := false
	if bool(candidate.get("counter_converted_monster", false)):
		queued = _queue_monster_card_as_counter(player_index, slot_index, source_skill)
	else:
		queued = _queue_skill_resolution(player_index, slot_index, -1)
	if queued:
		var queue_index := _next_batch_card_entry_index_for_player(player_index)
		var in_next_batch := true
		if queue_index < 0:
			queue_index = _queued_card_entry_index_for_player(player_index)
			in_next_batch = false
		if queue_index >= 0:
			var entry: Dictionary = (_card_resolution_next_queue()[queue_index] if in_next_batch else _card_resolution_current_queue()[queue_index]) as Dictionary
			entry["ai_utility_score"] = int(candidate.get("score", 0))
			entry["ai_reason"] = String(candidate.get("reason", "相位反制"))
			entry["ai_counter_response"] = true
			for field_name in ["counter_target_resolution_id", "counter_target_card", "counter_strength", "counter_threat_score", "counter_opportunity_cost", "counter_reason_key", "counter_source_card", "counter_converted_monster", "counter_card_name", "target_city", "target_owner", "game_phase", "competitive_posture", "score_gap_to_leader", "leader_index", "endgame_urgency", "learning_bonus"]:
				if candidate.has(field_name):
					entry[field_name] = candidate[field_name]
			_store_card_resolution_entry(entry)
		_record_ai_decision(
			player_index,
			"相位反制",
			int(candidate.get("counter_target_resolution_id", -1)),
			int(candidate.get("score", 0)),
			String(candidate.get("reason", "相位反制")),
			all_candidates,
			{
				"policy_kind": "counter_response",
				"card_name": String(candidate.get("card_name", "")),
				"counter_card_name": String(candidate.get("counter_card_name", "")),
				"counter_target_resolution_id": int(candidate.get("counter_target_resolution_id", -1)),
				"counter_target_card": String(candidate.get("counter_target_card", "")),
				"counter_strength": int(candidate.get("counter_strength", 0)),
				"counter_threat_score": int(candidate.get("counter_threat_score", 0)),
				"counter_opportunity_cost": int(candidate.get("counter_opportunity_cost", 0)),
				"counter_reason_key": String(candidate.get("counter_reason_key", "")),
				"counter_source_card": String(candidate.get("counter_source_card", "")),
				"counter_converted_monster": bool(candidate.get("counter_converted_monster", false)),
				"target_city": int(candidate.get("target_city", -1)),
				"target_owner": int(candidate.get("target_owner", -1)),
				"product": String(candidate.get("product", "")),
				"game_phase": String(candidate.get("game_phase", "")),
				"competitive_posture": String(candidate.get("competitive_posture", "")),
				"score_gap_to_leader": int(candidate.get("score_gap_to_leader", 0)),
				"leader_index": int(candidate.get("leader_index", -1)),
				"endgame_urgency": int(candidate.get("endgame_urgency", 0)),
				"learning_bonus": int(candidate.get("learning_bonus", 0)),
			}
		)
	selected_player = previous_player
	selected_district = previous_district
	selected_trade_product = previous_product
	return queued
func _auto_ai_counter_responses(force: bool = false) -> int:
	if not ai_card_decision_enabled or not card_resolution_counter_window_active or _card_resolution_active_entry().is_empty():
		return 0
	var candidates := []
	for player_index_variant in _ai_player_indices():
		var player_index := int(player_index_variant)
		for candidate_variant in _ai_counter_response_candidates(player_index):
			if candidate_variant is Dictionary:
				var candidate: Dictionary = candidate_variant
				candidate["player_index"] = player_index
				candidates.append(candidate)
	if candidates.is_empty():
		return 0
	candidates.sort_custom(Callable(self, "_sort_ai_candidate_score_desc"))
	for candidate_variant in candidates:
		var candidate: Dictionary = candidate_variant
		var score := int(candidate.get("score", 0))
		if not force and score < AI_COUNTER_RESPONSE_MIN_SCORE:
			continue
		if not force and score < AI_COUNTER_RESPONSE_CONFIDENT_SCORE:
			var chance := clampf(0.32 + float(score - AI_COUNTER_RESPONSE_MIN_SCORE) / float(maxi(1, AI_COUNTER_RESPONSE_CONFIDENT_SCORE - AI_COUNTER_RESPONSE_MIN_SCORE)) * 0.44, 0.08, 0.76)
			if rng.randf() > chance:
				continue
		var player_index := int(candidate.get("player_index", -1))
		var player_candidates := []
		for peer_variant in candidates:
			if peer_variant is Dictionary and int((peer_variant as Dictionary).get("player_index", -1)) == player_index:
				player_candidates.append(peer_variant)
		if _ai_queue_counter_response_candidate(player_index, candidate, player_candidates):
			return 1
	return 0
func _ai_contract_response_candidates(player_index: int, entry: Dictionary) -> Array:
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	var source_index := int(entry.get("contract_source_district", -1))
	var target_index := int(entry.get("contract_target_district", -1))
	var products: Array = entry.get("contract_products", []) as Array
	var source_owner := -1
	if source_index >= 0 and source_index < districts.size():
		source_owner = int(_district_city(source_index).get("owner", -1))
	var target_city := _district_city(target_index)
	var accept_score := 62
	accept_score += int(float(int(skill.get("accept_cash", 0))) / 3.0)
	accept_score += maxi(0, int(skill.get("accept_production_delta", 0))) * 34
	accept_score += maxi(0, int(skill.get("accept_transport_delta", 0))) * 42
	accept_score += maxi(0, int(skill.get("accept_consumption_delta", 0))) * 32
	var accept_route_flow := float(skill.get("accept_route_flow_multiplier", 1.0))
	if accept_route_flow > 1.001:
		accept_score += int(round((accept_route_flow - 1.0) * 230.0)) + maxi(1, int(ceil(_skill_duration_seconds(skill, "route_flow_seconds", "route_flow_turns", 1) / ECONOMY_LEGACY_TURN_SECONDS))) * 8
	accept_score += maxi(0, int(skill.get("contract_add_products", 0))) * 38
	accept_score += maxi(0, int(skill.get("contract_add_demands", 0))) * 42
	accept_score -= maxi(0, int(skill.get("contract_remove_products", 0))) * 16
	accept_score -= maxi(0, int(skill.get("contract_remove_demands", 0))) * 16
	accept_score += products.size() * 15
	if _city_is_active(target_city):
		accept_score += int(target_city.get("trade_route_damage", 0)) * 14
		accept_score += maxi(0, 4 - (target_city.get("demands", []) as Array).size()) * 12
	if source_owner == player_index:
		accept_score += 58
	var route_product := _ai_route_plan_product(player_index)
	var route_stage := _ai_route_plan_stage(player_index)
	var route_score := _ai_route_plan_score(player_index)
	var contract_matches_route := route_product != "" and (products.has(route_product) or _ai_district_touches_product(source_index, route_product) or _ai_district_touches_product(target_index, route_product))
	var accept_route_bonus := 0
	if contract_matches_route:
		accept_route_bonus += AI_ROUTE_PLAN_MATCH_BONUS
		if ["create_demand", "strengthen_route", "defend_route"].has(route_stage):
			accept_route_bonus += 82
	if source_owner == player_index and route_product != "":
		accept_route_bonus += 46
	accept_score += accept_route_bonus
	var contract_product_tag := route_product if contract_matches_route else _limited_name_list(products, 1, "")
	var accept_learning_bonus := _ai_learning_bonus(player_index, "contract_accept", "", route_stage, contract_product_tag, "匿名合约签约")
	accept_score += accept_learning_bonus
	var reject_score := 54
	if source_owner >= 0 and source_owner != player_index:
		reject_score += 42
	reject_score += maxi(0, int(skill.get("contract_remove_products", 0)) + int(skill.get("contract_remove_demands", 0))) * 10
	var reject_route_bonus := 0
	if source_owner >= 0 and source_owner != player_index and route_stage == "attack_rival" and contract_matches_route:
		reject_route_bonus += 72
	reject_score += reject_route_bonus
	var reject_learning_bonus := _ai_learning_bonus(player_index, "contract_reject", "", route_stage, contract_product_tag, "匿名合约拒签")
	reject_score += reject_learning_bonus
	var decline_badness := 0
	decline_badness += int(float(int(skill.get("decline_cash_penalty", 0))) / 3.0)
	decline_badness += maxi(0, -int(skill.get("decline_production_delta", 0))) * 38
	decline_badness += maxi(0, -int(skill.get("decline_transport_delta", 0))) * 44
	decline_badness += maxi(0, -int(skill.get("decline_consumption_delta", 0))) * 34
	decline_badness += maxi(0, int(skill.get("decline_route_damage", 0))) * 52
	accept_score += decline_badness
	reject_score -= int(round(float(decline_badness) * 0.55))
	var target_gdp := 0
	var target_route_damage := 0
	var target_product_count := 0
	var target_demand_count := 0
	if _city_is_active(target_city):
		target_gdp = int(target_city.get("last_gdp", target_city.get("last_income", 0)))
		target_route_damage = int(target_city.get("trade_route_damage", 0)) + int(target_city.get("trade_disrupted_routes", 0))
		target_product_count = (target_city.get("products", []) as Array).size()
		target_demand_count = (target_city.get("demands", []) as Array).size()
	var accept_economic_delta := int(skill.get("accept_cash", 0))
	accept_economic_delta += int(skill.get("accept_production_delta", 0)) * 26
	accept_economic_delta += int(skill.get("accept_transport_delta", 0)) * 32
	accept_economic_delta += int(skill.get("accept_consumption_delta", 0)) * 24
	accept_economic_delta += int(round(maxf(0.0, accept_route_flow - 1.0) * 120.0))
	accept_economic_delta += maxi(0, int(skill.get("contract_add_products", 0))) * 26
	accept_economic_delta += maxi(0, int(skill.get("contract_add_demands", 0))) * 30
	accept_economic_delta -= maxi(0, int(skill.get("contract_remove_products", 0)) + int(skill.get("contract_remove_demands", 0))) * 14
	var decline_economic_delta := -int(skill.get("decline_cash_penalty", 0))
	decline_economic_delta += int(skill.get("decline_production_delta", 0)) * 26
	decline_economic_delta += int(skill.get("decline_transport_delta", 0)) * 32
	decline_economic_delta += int(skill.get("decline_consumption_delta", 0)) * 24
	decline_economic_delta -= maxi(0, int(skill.get("decline_route_damage", 0))) * 38
	var accept_role := "accept_economic_gain"
	if decline_badness >= 90:
		accept_role = "accept_avoid_punishment"
	elif accept_route_bonus > 0:
		accept_role = "accept_route_plan"
	elif source_owner == player_index:
		accept_role = "accept_self_supply"
	var reject_role := "reject_low_value"
	if source_owner >= 0 and source_owner != player_index and reject_route_bonus > 0:
		reject_role = "reject_rival_route"
	elif source_owner >= 0 and source_owner != player_index:
		reject_role = "reject_rival_supply"
	return [
		{
			"action": "签约",
			"card_name": String(skill.get("name", "区域供需合约")),
			"kind": "area_trade_contract_response",
			"policy_kind": "contract_accept",
			"district": target_index,
			"product": _limited_name_list(products, 3, "未指定"),
			"score": maxi(1, accept_score),
			"reason": "签约奖励:%s｜拒签代价:%s｜商品:%s" % [
				_contract_accept_effect_summary(skill),
				_contract_decline_effect_summary(skill),
				_limited_name_list(products, 3, "未指定"),
			],
			"route_plan_product": route_product,
			"route_plan_stage": route_stage,
			"route_plan_score": route_score,
			"route_plan_bonus": accept_route_bonus,
			"learning_bonus": accept_learning_bonus,
			"contract_response_role": accept_role,
			"contract_source_district": source_index,
			"contract_target_district": target_index,
			"contract_source_owner": source_owner,
			"contract_target_gdp": target_gdp,
			"contract_target_route_damage": target_route_damage,
			"contract_target_product_count": target_product_count,
			"contract_target_demand_count": target_demand_count,
			"contract_route_match": 1 if contract_matches_route else 0,
			"contract_accept_value": maxi(1, accept_score),
			"contract_reject_value": maxi(1, reject_score),
			"contract_response_margin": accept_score - reject_score,
			"contract_decline_risk": decline_badness,
			"contract_accept_economic_delta": accept_economic_delta,
			"contract_decline_economic_delta": decline_economic_delta,
		},
		{
			"action": "拒签",
			"card_name": String(skill.get("name", "区域供需合约")),
			"kind": "area_trade_contract_response",
			"policy_kind": "contract_reject",
			"district": target_index,
			"product": _limited_name_list(products, 3, "未指定"),
			"score": maxi(1, reject_score),
			"reason": "拒绝可能避免帮对手供给区扩张｜拒签惩罚:%s" % _contract_decline_effect_summary(skill),
			"route_plan_product": route_product,
			"route_plan_stage": route_stage,
			"route_plan_score": route_score,
			"route_plan_bonus": reject_route_bonus,
			"learning_bonus": reject_learning_bonus,
			"contract_response_role": reject_role,
			"contract_source_district": source_index,
			"contract_target_district": target_index,
			"contract_source_owner": source_owner,
			"contract_target_gdp": target_gdp,
			"contract_target_route_damage": target_route_damage,
			"contract_target_product_count": target_product_count,
			"contract_target_demand_count": target_demand_count,
			"contract_route_match": 1 if contract_matches_route else 0,
			"contract_accept_value": maxi(1, accept_score),
			"contract_reject_value": maxi(1, reject_score),
			"contract_response_margin": reject_score - accept_score,
			"contract_decline_risk": decline_badness,
			"contract_accept_economic_delta": accept_economic_delta,
			"contract_decline_economic_delta": decline_economic_delta,
		},
	]
func _update_ai_contract_responses(force: bool = false) -> int:
	if pending_contract_offers.is_empty():
		return 0
	var responded := 0
	var offers_snapshot: Array = pending_contract_offers.duplicate(true)
	for offer_variant in offers_snapshot:
		if not (offer_variant is Dictionary):
			continue
		var entry: Dictionary = offer_variant
		if String(entry.get("contract_response", CONTRACT_RESPONSE_PENDING)) != CONTRACT_RESPONSE_PENDING:
			continue
		var contract_owner := int(entry.get("contract_target_owner", -1))
		if not _player_is_ai(contract_owner):
			continue
		if not force and float(entry.get("contract_decision_timer", _ruleset_timing_seconds(&"contract_window_seconds"))) > _ruleset_timing_seconds(&"contract_window_seconds") - 1.0:
			continue
		var candidates := _ai_contract_response_candidates(contract_owner, entry)
		var choice := _ai_pick_candidate(contract_owner, candidates, force)
		if choice.is_empty():
			continue
		var accept := String(choice.get("action", "")) == "签约"
		var contract_id := int(entry.get("contract_offer_id", entry.get("resolution_id", -1)))
		_record_ai_decision(
			contract_owner,
			"匿名合约%s" % String(choice.get("action", "回应")),
			int(entry.get("contract_target_district", -1)),
			int(choice.get("score", 0)),
			String(choice.get("reason", "按奖励、惩罚和是否帮对手评分")),
			candidates,
			{
				"card_name": String((entry.get("skill", {}) as Dictionary).get("name", "区域供需合约")),
				"contract_offer_id": contract_id,
				"contract_response": String(choice.get("action", "")),
				"policy_kind": String(choice.get("policy_kind", "")),
				"route_plan_product": String(choice.get("route_plan_product", "")),
				"route_plan_stage": String(choice.get("route_plan_stage", "")),
				"route_plan_score": int(choice.get("route_plan_score", 0)),
				"route_plan_bonus": int(choice.get("route_plan_bonus", 0)),
				"learning_bonus": int(choice.get("learning_bonus", 0)),
				"product": String(choice.get("product", "")),
				"contract_response_role": String(choice.get("contract_response_role", "")),
				"contract_source_district": int(choice.get("contract_source_district", -1)),
				"contract_target_district": int(choice.get("contract_target_district", -1)),
				"contract_source_owner": int(choice.get("contract_source_owner", -1)),
				"contract_target_gdp": int(choice.get("contract_target_gdp", 0)),
				"contract_target_route_damage": int(choice.get("contract_target_route_damage", 0)),
				"contract_route_match": int(choice.get("contract_route_match", 0)),
				"contract_accept_value": int(choice.get("contract_accept_value", 0)),
				"contract_reject_value": int(choice.get("contract_reject_value", 0)),
				"contract_response_margin": int(choice.get("contract_response_margin", 0)),
				"contract_decline_risk": int(choice.get("contract_decline_risk", 0)),
				"contract_accept_economic_delta": int(choice.get("contract_accept_economic_delta", 0)),
				"contract_decline_economic_delta": int(choice.get("contract_decline_economic_delta", 0)),
			}
		)
		if _respond_to_pending_contract_for_player(contract_owner, contract_id, accept, false):
			_log("目标城市业主匿名%s了一份合约；系统只公开结果，不公开是哪位玩家回应。" % ("签署" if accept else "拒绝"))
			responded += 1
	return responded
func _ai_public_player_product_signal(viewer_index: int, guessed_player: int, product_name: String) -> int:
	if viewer_index < 0 or viewer_index >= players.size() or guessed_player < 0 or guessed_player >= players.size() or product_name == "":
		return 0
	var signal_score := 0
	var viewer: Dictionary = players[viewer_index]
	var guesses: Dictionary = viewer.get("city_guesses", {})
	var confidences: Dictionary = viewer.get("city_guess_confidence", {})
	for city_key in guesses.keys():
		if int(guesses.get(city_key, -1)) != guessed_player:
			continue
		var city_index := int(city_key)
		if city_index < 0 or city_index >= districts.size():
			continue
		var city := _district_city(city_index)
		if not _city_is_active(city):
			continue
		var confidence := _normalized_city_guess_confidence(int(confidences.get(city_key, CITY_GUESS_CONFIDENCE_DEFAULT)))
		var confidence_weight := 16 + confidence * 12
		if _city_product_names(city).has(product_name):
			signal_score += confidence_weight + 18
		if _city_demand_names(city).has(product_name):
			signal_score += confidence_weight
		var public_clues: Array = city.get("public_clues", [])
		for clue_variant in public_clues:
			var clue := _normalize_city_public_clue_entry(clue_variant)
			if (clue.get("products", []) as Array).has(product_name):
				signal_score += 8 + confidence * 3
	for entry_variant in _public_card_resolution_owner_entries():
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if not bool(entry.get("public_owner_revealed", false)) or int(entry.get("player_index", -1)) != guessed_player:
			continue
		if String(entry.get("play_requirement_product", "")) == product_name:
			signal_score += 34
		var skill: Dictionary = entry.get("skill", {}) as Dictionary
		if String(skill.get("play_product", "")) == product_name:
			signal_score += 24
	return signal_score
func _ai_city_guess_owner_candidate(viewer_index: int, city_entry: Dictionary, guessed_player: int) -> Dictionary:
	var city_index := int(city_entry.get("district_index", -1))
	if city_index < 0 or city_index >= districts.size() or guessed_player < 0 or guessed_player >= players.size() or guessed_player == viewer_index:
		return {}
	var city := _district_city(city_index)
	if not _city_is_active(city):
		return {}
	var score := int(city_entry.get("priority", 0)) + 18
	var reason_key := str(CITY_GUESS_REASON_INTUITION)
	var reason_bits := []
	for product_variant in _city_product_names(city):
		var product_name := String(product_variant)
		var product_signal := _ai_public_player_product_signal(viewer_index, guessed_player, product_name)
		if product_signal > 0:
			score += product_signal
			reason_key = CITY_GUESS_REASON_PRODUCT
			reason_bits.append("%s商品线索+%d" % [product_name, product_signal])
	for demand_variant in _city_demand_names(city):
		var demand_name := String(demand_variant)
		var demand_signal := int(float(_ai_public_player_product_signal(viewer_index, guessed_player, demand_name)) / 2.0)
		if demand_signal > 0:
			score += demand_signal
			if reason_key == CITY_GUESS_REASON_INTUITION:
				reason_key = CITY_GUESS_REASON_ROUTE
			reason_bits.append("%s需求线索+%d" % [demand_name, demand_signal])
	var latest_clue := String(city_entry.get("latest_clue", ""))
	if latest_clue != "" and latest_clue != "暂无公开线索":
		score += 14
		if latest_clue.contains("卡") or latest_clue.contains("牌"):
			reason_key = CITY_GUESS_REASON_CARD
		reason_bits.append("公开线索")
	var current_guess := int(city_entry.get("guess", -1))
	var current_confidence := int(city_entry.get("confidence", 0))
	if current_guess == guessed_player:
		score += 10 - current_confidence * 3
	elif current_guess >= 0:
		score -= 18 + current_confidence * 10
	if reason_bits.is_empty():
		score += 5 + ((city_index + guessed_player * 3 + business_cycle_count) % 11)
		reason_bits.append("低置信直觉")
	var learning_bonus := _ai_learning_bonus(viewer_index, "city_owner_guess", "", "", "", "城市业主推理")
	score += learning_bonus
	var confidence := int(CITY_GUESS_CONFIDENCE_LOW)
	if score >= 150:
		confidence = CITY_GUESS_CONFIDENCE_HIGH
	elif score >= 105:
		confidence = CITY_GUESS_CONFIDENCE_MEDIUM
	return {
		"action": "城市业主标注",
		"kind": "city_owner_guess",
		"policy_kind": "city_owner_guess",
		"district": city_index,
		"guessed_player": guessed_player,
		"confidence": confidence,
		"reason_key": reason_key,
		"learning_bonus": learning_bonus,
		"score": maxi(1, score),
		"reason": "%s→玩家%d｜%s" % [
			String(districts[city_index].get("name", "城市")),
			guessed_player + 1,
			"、".join(reason_bits),
		],
	}
func _ai_city_guess_candidates(player_index: int) -> Array:
	var result := []
	if not _player_is_ai(player_index):
		return result
	for entry_variant in _intel_city_guess_entries(player_index, 12):
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if bool(entry.get("marked", false)) and int(entry.get("confidence", 0)) >= CITY_GUESS_CONFIDENCE_HIGH:
			continue
		var best := {}
		for guessed_player in range(players.size()):
			var candidate := _ai_city_guess_owner_candidate(player_index, entry, guessed_player)
			if candidate.is_empty():
				continue
			if best.is_empty() or int(candidate.get("score", 0)) > int(best.get("score", 0)):
				best = candidate
		if not best.is_empty():
			result.append(best)
	return result
func _ai_apply_city_guess_candidate(player_index: int, candidate: Dictionary, all_candidates: Array) -> bool:
	var district_index := int(candidate.get("district", -1))
	var guessed_player := int(candidate.get("guessed_player", -1))
	if not _mark_city_guess_for_player(player_index, district_index, guessed_player, int(candidate.get("confidence", CITY_GUESS_CONFIDENCE_LOW)), String(candidate.get("reason_key", CITY_GUESS_REASON_INTUITION))):
		return false
	_record_ai_decision(
		player_index,
		"城市业主推理",
		district_index,
		int(candidate.get("score", 0)),
		String(candidate.get("reason", "按公开商品和城市线索标注")),
		all_candidates,
		{
			"policy_kind": String(candidate.get("policy_kind", "city_owner_guess")),
			"guessed_player": guessed_player,
			"confidence": int(candidate.get("confidence", 0)),
			"reason_key": String(candidate.get("reason_key", "")),
			"learning_bonus": int(candidate.get("learning_bonus", 0)),
		}
	)
	return true
func _ai_card_guess_candidate_for_owner(player_index: int, entry: Dictionary, guessed_player: int) -> Dictionary:
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	if resolution_id < 0 or guessed_player < 0 or guessed_player >= players.size() or guessed_player == player_index:
		return {}
	if bool(entry.get("public_owner_revealed", false)):
		return {}
	var actual_owner := int(entry.get("player_index", -1))
	if actual_owner == player_index:
		return {}
	var guessers: Array = entry.get("guessers", [])
	if guessers.has(player_index):
		return {}
	var stake := _card_owner_guess_stake_for_player(player_index)
	if int((players[player_index] as Dictionary).get("cash", 0)) < stake + AI_CARD_BUY_MIN_CASH_RESERVE:
		return {}
	var score := 48
	var reason_bits := []
	var private_known := _private_known_card_owner_for_entry(player_index, entry)
	if private_known == guessed_player:
		score += 180
		reason_bits.append("私有追帧命中")
	elif private_known >= 0:
		score -= 90
	var product_name := String(entry.get("play_requirement_product", ""))
	if product_name != "":
		var product_signal := _ai_public_player_product_signal(player_index, guessed_player, product_name)
		if product_signal > 0:
			score += product_signal + 20
			reason_bits.append("%s区域亲和" % product_name)
	var selected_city := int(entry.get("selected_district", -1))
	if selected_city >= 0 and selected_city < districts.size():
		var guesses: Dictionary = (players[player_index] as Dictionary).get("city_guesses", {})
		if int(guesses.get(selected_city, -1)) == guessed_player:
			score += 26
			reason_bits.append("目标城市私标吻合")
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	var kind := String(skill.get("kind", ""))
	for previous_variant in resolved_card_history:
		if not (previous_variant is Dictionary):
			continue
		var previous := previous_variant as Dictionary
		if not bool(previous.get("public_owner_revealed", false)) or int(previous.get("player_index", -1)) != guessed_player:
			continue
		var previous_skill: Dictionary = previous.get("skill", {}) as Dictionary
		if String(previous_skill.get("kind", "")) == kind:
			score += 18
			reason_bits.append("已揭示同类牌")
			break
	if reason_bits.is_empty():
		score += ((resolution_id + guessed_player * 5 + business_cycle_count) % 13)
		reason_bits.append("弱线索试探")
	var learning_bonus := _ai_learning_bonus(player_index, "card_owner_guess", "", "", product_name, "卡牌归属押注")
	score += learning_bonus
	return {
		"action": "卡牌归属押注",
		"kind": "card_owner_guess",
		"policy_kind": "card_owner_guess",
		"resolution_id": resolution_id,
		"card_name": _card_resolution_entry_card_label(entry),
		"guessed_player": guessed_player,
		"stake": stake,
		"district": selected_city,
		"product": product_name,
		"learning_bonus": learning_bonus,
		"score": maxi(1, score),
		"reason": "轨道#%d《%s》→玩家%d｜%s" % [
			resolution_id,
			_card_resolution_entry_card_label(entry),
			guessed_player + 1,
			"、".join(reason_bits),
		],
	}
func _ai_card_guess_candidates(player_index: int) -> Array:
	var result := []
	if not _player_is_ai(player_index):
		return result
	for i in range(resolved_card_history.size() - 1, -1, -1):
		var entry_variant: Variant = resolved_card_history[i]
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if bool(entry.get("public_owner_revealed", false)):
			continue
		var best := {}
		for guessed_player in range(players.size()):
			var candidate := _ai_card_guess_candidate_for_owner(player_index, entry, guessed_player)
			if candidate.is_empty():
				continue
			if best.is_empty() or int(candidate.get("score", 0)) > int(best.get("score", 0)):
				best = candidate
		if not best.is_empty():
			result.append(best)
	return result
func _ai_apply_card_guess_candidate(player_index: int, candidate: Dictionary, all_candidates: Array) -> bool:
	_record_ai_decision(
		player_index,
		"卡牌归属押注",
		int(candidate.get("resolution_id", -1)),
		int(candidate.get("score", 0)),
		String(candidate.get("reason", "按公开条件与私有线索押注")),
		all_candidates,
		{
			"policy_kind": String(candidate.get("policy_kind", "card_owner_guess")),
			"resolution_id": int(candidate.get("resolution_id", -1)),
			"guessed_player": int(candidate.get("guessed_player", -1)),
			"stake": int(candidate.get("stake", 0)),
			"card_name": String(candidate.get("card_name", "")),
			"product": String(candidate.get("product", "")),
			"learning_bonus": int(candidate.get("learning_bonus", 0)),
		}
	)
	return _guess_card_resolution_owner_for_player(player_index, int(candidate.get("resolution_id", -1)), int(candidate.get("guessed_player", -1)), true)
func _auto_ai_intel_decisions(force: bool = false) -> int:
	if session_finished or not ai_card_decision_enabled:
		return 0
	var acted := 0
	for player_index_variant in _ai_player_indices():
		var player_index := int(player_index_variant)
		var city_candidates := _ai_city_guess_candidates(player_index)
		var city_choice := _ai_pick_candidate(player_index, city_candidates, force)
		if not city_choice.is_empty() and (force or int(city_choice.get("score", 0)) >= AI_INTEL_MIN_CITY_SCORE):
			if _ai_apply_city_guess_candidate(player_index, city_choice, city_candidates):
				acted += 1
		if acted >= AI_INTEL_ACTIONS_PER_TICK and not force:
			return acted
		var card_candidates := _ai_card_guess_candidates(player_index)
		var card_choice := _ai_pick_candidate(player_index, card_candidates, force)
		if not card_choice.is_empty() and (force or int(card_choice.get("score", 0)) >= AI_INTEL_MIN_CARD_SCORE):
			if _ai_apply_card_guess_candidate(player_index, card_choice, card_candidates):
				acted += 1
		if acted >= AI_INTEL_ACTIONS_PER_TICK and not force:
			return acted
	return acted
func _update_ai_decisions(delta: float) -> void:
	if not ai_card_decision_enabled or players.is_empty():
		return
	ai_auction_reaction_timer -= delta
	if ai_auction_reaction_timer <= 0.0:
		_auto_ai_counter_responses(false)
		_update_ai_contract_responses(false)
		_auto_ai_monster_wagers()
		ai_auction_reaction_timer = AI_AUCTION_REACTION_INTERVAL_SECONDS
	ai_card_decision_timer -= delta
	if ai_card_decision_timer <= 0.0:
		var bootstrap := execute_v06_facility_bootstrap_cycle(false)
		if int(bootstrap.get("acted", 0)) <= 0:
			_auto_ai_card_decisions(false)
		ai_card_decision_timer = AI_CARD_DECISION_INTERVAL_SECONDS
	ai_intel_decision_timer -= delta
	if ai_intel_decision_timer <= 0.0:
		_auto_ai_intel_decisions(false)
		ai_intel_decision_timer = AI_INTEL_DECISION_INTERVAL_SECONDS
func _ai_discard_keep_value(player_index: int, slot_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 99999
	var player: Dictionary = players[player_index]
	if slot_index < 0 or slot_index >= player.get("slots", []).size():
		return 99999
	var skill_variant = player["slots"][slot_index]
	if not (skill_variant is Dictionary):
		return 99999
	var skill := skill_variant as Dictionary
	var value := int(skill.get("cost", 2)) * 22 + maxi(1, _skill_rank(String(skill.get("name", "")))) * 18
	var context := _ai_card_play_context(player_index, slot_index, skill)
	if context.is_empty():
		value -= 34
	else:
		value += clampi(int(float(int(context.get("score", 0))) / 4.0), 0, 120)
	if String(skill.get("kind", "")) == "monster_card" and _ai_owned_active_monster_count(player_index) <= 0:
		value += 140
	return value
func _ai_discard_slot_for_purchase(player_index: int, _incoming_card_name: String) -> int:
	if player_index < 0 or player_index >= players.size():
		return -1
	var player: Dictionary = players[player_index]
	var slots := _discardable_hand_slots_for_purchase(player)
	var best_slot := -1
	var best_value := 999999
	for slot_variant in slots:
		var slot_index := int(slot_variant)
		var value := _ai_discard_keep_value(player_index, slot_index)
		if value < best_value:
			best_value = value
			best_slot = slot_index
	return best_slot
func _ai_monster_wager_nearest_city_pressure(player_index: int, actor: Dictionary) -> Dictionary:
	var own_pressure := 0
	var rival_pressure := 0
	var nearest_own := 999999.0
	var nearest_rival := 999999.0
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		var city_owner := int(city.get("owner", -1))
		var distance := _entity_distance_to_district(actor, city_index)
		var city_value := _ai_city_target_score(player_index, city_index, city_owner == player_index, true)
		var proximity := maxi(0, 360 - int(round(distance)))
		var pressure := proximity + int(float(city_value) / 3.0) + int(float(int(city.get("last_income", 0))) / 5.0)
		if city_owner == player_index:
			own_pressure += pressure
			nearest_own = minf(nearest_own, distance)
		elif city_owner >= 0:
			rival_pressure += pressure
			nearest_rival = minf(nearest_rival, distance)
	return {
		"own_pressure": own_pressure,
		"rival_pressure": rival_pressure,
		"nearest_own": int(round(nearest_own)) if nearest_own < 999999.0 else -1,
		"nearest_rival": int(round(nearest_rival)) if nearest_rival < 999999.0 else -1,
	}
func _ai_monster_wager_side_score(player_index: int, entry: Dictionary, side: String) -> Dictionary:
	var slot := _monster_wager_current_slot(entry, side)
	var damage_score := _monster_wager_damage_for_side(entry, side) * 14
	var combat_score := 0
	var owner_bias := 0
	var city_bias := 0
	var resource_bias := 0
	var reason_key := "unknown"
	if slot >= 0 and slot < auto_monsters.size():
		var actor: Dictionary = auto_monsters[slot]
		var expected_damage := _monster_wager_actor_expected_damage_score(actor)
		combat_score = expected_damage * 38 + int(actor.get("hp", 0)) + int(actor.get("armor", 0)) * 6 + int(actor.get("rank", 1)) * 32
		var monster_owner := int(actor.get("owner", -1))
		if monster_owner == player_index:
			owner_bias = 120
			if not bool(actor.get("owner_revealed", false)):
				owner_bias -= 28
			reason_key = "own_monster"
		elif monster_owner >= 0:
			var leader_index := int(_ai_refresh_game_phase(player_index).get("leader_index", -1))
			owner_bias = 38
			if monster_owner == leader_index and monster_owner != player_index:
				owner_bias -= 42
				reason_key = "leader_monster"
			else:
				reason_key = "rival_monster"
		else:
			owner_bias = 18
			reason_key = "unknown_owner"
		var city_pressure := _ai_monster_wager_nearest_city_pressure(player_index, actor)
		var own_pressure := int(city_pressure.get("own_pressure", 0))
		var rival_pressure := int(city_pressure.get("rival_pressure", 0))
		city_bias = int(float(rival_pressure) / 6.0) - int(float(own_pressure) / 8.0)
		resource_bias = _monster_resource_match_score(actor, int(actor.get("position", -1))) * 18
	var score := damage_score + combat_score + owner_bias + city_bias + resource_bias
	score += int(_ai_profile_for_player(player_index).get("risk_tolerance", 1.0) * 18.0)
	score += (player_index + int(entry.get("wager_id", 0)) + slot) % 7
	return {
		"side": side,
		"score": score,
		"damage_score": damage_score,
		"combat_score": combat_score,
		"owner_bias": owner_bias,
		"city_bias": city_bias,
		"resource_bias": resource_bias,
		"reason_key": reason_key,
	}
func _ai_monster_wager_plan(player_index: int, entry: Dictionary) -> Dictionary:
	var best := {}
	var second_score := -999999
	for competitor_variant in _monster_wager_competitors(entry):
		var competitor := competitor_variant as Dictionary
		var side := String(competitor.get("side", ""))
		if side == "":
			continue
		var plan := _ai_monster_wager_side_score(player_index, entry, side)
		var score := int(plan.get("score", -999999))
		if best.is_empty() or score > int(best.get("score", -999999)):
			if not best.is_empty():
				second_score = int(best.get("score", -999999))
			best = plan
		elif score > second_score:
			second_score = score
	if best.is_empty():
		return {}
	var confidence := maxi(0, int(best.get("score", 0)) - second_score)
	var base_percent := _monster_wager_base_percent(entry)
	var raise_steps := 0
	if confidence >= 240:
		raise_steps = 5
	elif confidence >= 180:
		raise_steps = 3
	elif confidence >= 120:
		raise_steps = 2
	elif confidence >= 70:
		raise_steps = 1
	var stake_percent := _monster_wager_clamped_percent(entry, base_percent + raise_steps)
	var stake := _monster_wager_amount_for_percent(player_index, stake_percent)
	best["confidence"] = confidence
	best["stake"] = stake
	best["stake_percent"] = stake_percent
	best["ai_wager_score"] = int(best.get("score", 0))
	best["ai_wager_confidence"] = confidence
	best["ai_wager_reason_key"] = String(best.get("reason_key", "unknown"))
	best["ai_wager_owner_bias"] = int(best.get("owner_bias", 0))
	best["ai_wager_city_bias"] = int(best.get("city_bias", 0))
	best["ai_wager_expected_damage"] = int(best.get("combat_score", 0))
	best["ai_wager_stake_percent"] = stake_percent
	return best
func _ai_monster_wager_side(player_index: int, entry: Dictionary) -> String:
	var plan := _ai_monster_wager_plan(player_index, entry)
	return String(plan.get("side", ""))
func _auto_ai_monster_wagers_for_entry(wager_id: int) -> int:
	var index := _monster_wager_entry_index_by_id(wager_id)
	if index < 0:
		return 0
	var acted := 0
	for player_index in range(players.size()):
		if not _player_is_ai(player_index):
			continue
		var entry: Dictionary = active_monster_wagers[index]
		if _monster_wager_player_side(entry, player_index) != "":
			continue
		var plan := _ai_monster_wager_plan(player_index, entry)
		var side := String(plan.get("side", ""))
		if side == "":
			continue
		var stake_percent := int(plan.get("stake_percent", _monster_wager_base_percent(entry)))
		var metadata := {}
		for key_variant in plan.keys():
			var key := String(key_variant)
			if key.begins_with("ai_wager_"):
				metadata[key] = plan[key_variant]
		if _place_monster_wager_percent(wager_id, side, stake_percent, player_index, false, metadata):
			acted += 1
			index = _monster_wager_entry_index_by_id(wager_id)
			if index < 0:
				break
	return acted
func _auto_ai_monster_wagers() -> int:
	var acted := 0
	for entry_variant in active_monster_wagers.duplicate(true):
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		acted += _auto_ai_monster_wagers_for_entry(int(entry.get("wager_id", -1)))
	return acted
