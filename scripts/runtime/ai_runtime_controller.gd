@tool
extends Node
class_name AiRuntimeController

const CardPlayRequirementPolicyScript := preload("res://scripts/cards/card_play_requirement_policy.gd")
const RuntimeBalanceModelScript := preload("res://scripts/balance/runtime_balance_model.gd")
const DEFAULT_POLICY_PROFILE := preload("res://resources/ai/ai_policy_profile_v1.tres")
const ACTIVE_RESPONSE_KINDS := [
	"counter_response",
	"monster_wager",
	"discard_purchase",
	"monster_target_choice",
	"player_target_choice",
	"public_bid",
	"card_order_bid",
]
const AI_SAVE_FIELDS := [
	"ai_card_decision_timer",
	"ai_auction_reaction_timer",
	"ai_intel_decision_timer",
	"ai_card_decision_enabled",
	"player_states",
]
const AI_PLAYER_SAVE_FIELDS := ["player_index", "ai_profile", "ai_memory"]
const AUTO_MONSTER_ENCOUNTER_RANGE_METERS := MonsterRuntimeController.AUTO_MONSTER_ENCOUNTER_RANGE_METERS
const DEFAULT_AOE_RADIUS_METERS := MonsterRuntimeController.DEFAULT_AOE_RADIUS_METERS
const ACTION_CALLOUT_DURATION := VisualCueRuntimeOwner.ACTION_CALLOUT_DURATION
const NEARBY_RADIUS_METERS := MonsterRuntimeController.NEARBY_RADIUS_METERS
const PLAYER_HAND_LIMIT := CardFlowPolicyV06.HAND_LIMIT
const RIVAL_AUTO_BUILD_BASE_CITY_CAP := 2
const RIVAL_AUTO_BUILD_MAX_CITY_CAP := 5
const AI_EVENT_TARGET_BASE_WEIGHT := 8
const AI_EVENT_TARGET_PANIC_WEIGHT := 1
const AI_EVENT_TARGET_MIASMA_BONUS := 14
const AI_EVENT_TARGET_MONSTER_BONUS := 10
const AI_EVENT_TARGET_CITY_BONUS := 24
const AI_EVENT_TARGET_COMPETITION_WEIGHT := 3
const AI_EVENT_TARGET_TRADE_WEIGHT := 4
const AI_OWN_WAREHOUSE_COUNT_PRESSURE := 34
const AI_OWN_WAREHOUSE_UNIT_PRESSURE := 8
const AI_OWN_WAREHOUSE_PRODUCT_PRESSURE := 10

@export var policy_profile: Resource = DEFAULT_POLICY_PROFILE

var _runtime_balance_model := RuntimeBalanceModelScript.new()

var _world_bridge: Node
var _run_rng_service: RunRngService
var _ai_session_public_query_port: AiSessionPublicQueryPort
var _ai_card_hand_query_port: AiCardHandQueryPort
var _ai_card_hand_capabilities: Dictionary = {}
var _ai_card_hand_capability_binding_initialized := false
var _ai_card_queue_query_port: AiCardQueueQueryPort
var _ai_card_queue_capabilities: Dictionary = {}
var _ai_card_queue_capability_binding_initialized := false
var _ai_card_eligibility_query_port: AiCardEligibilityQueryPort
var _ai_card_eligibility_capabilities: Dictionary = {}
var _ai_card_eligibility_capability_binding_initialized := false
var _ai_actor_economy_query_port: AiActorEconomyQueryPort
var _ai_actor_economy_capabilities: Dictionary = {}
var _ai_actor_economy_capability_binding_initialized := false
var _ai_market_public_query_port: AiMarketPublicQueryPort
var _ai_route_public_query_port: AiRoutePublicQueryPort
var _ai_actor_state_port: AiActorStatePort
var _ai_actor_state_capabilities: Dictionary = {}
var _ai_actor_state_capability_binding_initialized := false
var _ai_region_knowledge_query_port: AiRegionKnowledgeQueryPort
var _ai_region_knowledge_capabilities: Dictionary = {}
var _ai_region_knowledge_capability_binding_initialized := false
var _ai_city_inference_command_port: AiCityInferenceCommandPort
var _ai_monster_public_query_port: AiMonsterPublicQueryPort
var _ai_monster_actor_query_port: AiMonsterActorQueryPort
var _ai_monster_actor_capabilities: Dictionary = {}
var _ai_monster_actor_capability_binding_initialized := false
var _ai_military_public_query_port: AiMilitaryPublicQueryPort
var _ai_military_actor_query_port: AiMilitaryActorQueryPort
var _ai_military_actor_capabilities: Dictionary = {}
var _ai_military_actor_capability_binding_initialized := false
var _ai_weather_public_query_port: AiWeatherPublicQueryPort
var _ai_victory_public_query_port: AiVictoryPublicQueryPort
var _ai_actor_victory_query_port: AiActorVictoryQueryPort
var _ai_actor_victory_capabilities: Dictionary = {}
var _ai_actor_victory_capability_binding_initialized := false
var _monster_runtime_controller: MonsterRuntimeController
var _military_runtime_controller: MilitaryRuntimeController
var _product_market_runtime_controller: ProductMarketRuntimeController
var _city_gdp_derivative_runtime_controller: CityGdpDerivativeRuntimeController
var _card_definition_bridge: CardRuntimeDefinitionWorldBridge
var _card_play_eligibility_runtime_service: CardPlayEligibilityRuntimeService
var _gameplay_balance_diagnostics_service: GameplayBalanceDiagnosticsRuntimeService
var _route_network_runtime_controller: RouteNetworkRuntimeController
var _visual_cue_runtime_owner: VisualCueRuntimeOwner
var _card_play_submission_controller: CardPlaySubmissionRuntimeController
var _card_resolution_history_service: CardResolutionHistoryRuntimeService
var _district_supply_action_port: DistrictSupplyActionPort
var _district_supply_runtime_query_port: DistrictSupplyRuntimeQueryPort
var _district_supply_ai_query_capabilities: Dictionary = {}
var _district_supply_ai_capability_binding_initialized := false
var _ai_business_cost_cash_port: AiBusinessCostCashPort
var _ai_business_cost_capability: AiBusinessCostCapability
var _ruleset_snapshot: Dictionary = {}
var _policy_main_payload: Dictionary = {}
var _business_action_policy: Dictionary = {}
var _configured := false
var _last_receipts: Array = []
var ai_card_decision_timer := 2.2
var ai_auction_reaction_timer := 0.7
var ai_intel_decision_timer := 5.5
var ai_card_decision_enabled := true


func set_world_bridge(bridge: Node) -> void:
	_world_bridge = bridge


func set_run_rng_service(service: RunRngService) -> void:
	_run_rng_service = service


func set_world_typed_ports(
	session_public_query_port: AiSessionPublicQueryPort,
	actor_state_port: AiActorStatePort,
	actor_state_capabilities: Dictionary,
	region_knowledge_query_port: AiRegionKnowledgeQueryPort,
	region_knowledge_capabilities: Dictionary,
	city_inference_command_port: AiCityInferenceCommandPort
) -> void:
	_ai_session_public_query_port = session_public_query_port
	_ai_actor_state_port = actor_state_port
	set_actor_state_capabilities(actor_state_capabilities)
	_ai_region_knowledge_query_port = region_knowledge_query_port
	set_region_knowledge_capabilities(region_knowledge_capabilities)
	_ai_city_inference_command_port = city_inference_command_port


func set_region_knowledge_capabilities(capabilities_by_actor: Dictionary) -> void:
	_ai_region_knowledge_capabilities = capabilities_by_actor.duplicate()
	_ai_region_knowledge_capability_binding_initialized = true


func set_actor_state_capabilities(actor_state_capabilities: Dictionary) -> void:
	_ai_actor_state_capabilities = actor_state_capabilities.duplicate()
	_ai_actor_state_capability_binding_initialized = true


func set_card_hand_query_port(
	port: AiCardHandQueryPort,
	capabilities_by_actor: Dictionary
) -> void:
	_ai_card_hand_query_port = port
	_ai_card_hand_capabilities = capabilities_by_actor.duplicate()
	_ai_card_hand_capability_binding_initialized = true


func _session_public_snapshot() -> Dictionary:
	return _ai_session_public_query_port.public_snapshot() \
		if _ai_session_public_query_port != null and _ai_session_public_query_port.is_ready() else {}


func _ai_card_hand_snapshot(player_index: int) -> Dictionary:
	if _ai_card_hand_query_port == null or not _ai_card_hand_capability_binding_initialized:
		return {}
	return _ai_card_hand_query_port.private_hand_snapshot(
		_ai_card_hand_capabilities.get(player_index) as AiCardHandCapability,
		player_index
	)


func set_card_queue_query_port(
	port: AiCardQueueQueryPort,
	capabilities_by_actor: Dictionary
) -> void:
	_ai_card_queue_query_port = port
	_ai_card_queue_capabilities = capabilities_by_actor.duplicate()
	_ai_card_queue_capability_binding_initialized = true


func _card_queue_public_snapshot() -> Dictionary:
	return _ai_card_queue_query_port.public_resolution_snapshot() \
		if _ai_card_queue_query_port != null and _ai_card_queue_query_port.is_ready() else {}


func _card_queue_window_snapshot() -> Dictionary:
	return _ai_card_queue_query_port.public_window_snapshot() \
		if _ai_card_queue_query_port != null and _ai_card_queue_query_port.is_ready() else {}


func _ai_card_queue_snapshot(player_index: int) -> Dictionary:
	if _ai_card_queue_query_port == null or not _ai_card_queue_capability_binding_initialized:
		return {}
	return _ai_card_queue_query_port.private_actor_submission_snapshot(
		_ai_card_queue_capabilities.get(player_index) as AiCardQueueCapability,
		player_index
	)


func set_card_eligibility_query_port(
	port: AiCardEligibilityQueryPort,
	capabilities_by_actor: Dictionary
) -> void:
	_ai_card_eligibility_query_port = port
	_ai_card_eligibility_capabilities = capabilities_by_actor.duplicate()
	_ai_card_eligibility_capability_binding_initialized = true


func _ai_card_eligibility_snapshot(
	player_index: int,
	skill: Dictionary,
	evaluation_mode: String,
	selected_district: int = -1
) -> Dictionary:
	if (
		_ai_card_eligibility_query_port == null
		or not _ai_card_eligibility_capability_binding_initialized
	):
		return {}
	return _ai_card_eligibility_query_port.eligibility_snapshot(
		_ai_card_eligibility_capabilities.get(
			player_index
		) as AiCardEligibilityCapability,
		player_index,
		skill,
		evaluation_mode,
		selected_district
	)


func _ai_card_requirement_snapshot(
	player_index: int,
	skill: Dictionary,
	selected_district: int = -1
) -> Dictionary:
	if (
		_ai_card_eligibility_query_port == null
		or not _ai_card_eligibility_capability_binding_initialized
	):
		return {}
	return _ai_card_eligibility_query_port.requirement_snapshot(
		_ai_card_eligibility_capabilities.get(
			player_index
		) as AiCardEligibilityCapability,
		player_index,
		skill,
		selected_district
	)


func _ai_card_best_share_snapshot(player_index: int) -> Dictionary:
	if (
		_ai_card_eligibility_query_port == null
		or not _ai_card_eligibility_capability_binding_initialized
	):
		return {}
	return _ai_card_eligibility_query_port.best_share_snapshot(
		_ai_card_eligibility_capabilities.get(
			player_index
		) as AiCardEligibilityCapability,
		player_index
	)


func set_actor_economy_query_port(
	port: AiActorEconomyQueryPort,
	capabilities_by_actor: Dictionary
) -> void:
	_ai_actor_economy_query_port = port
	_ai_actor_economy_capabilities = capabilities_by_actor.duplicate()
	_ai_actor_economy_capability_binding_initialized = true


func _ai_actor_economy_snapshot(player_index: int) -> Dictionary:
	if _ai_actor_economy_query_port == null or not _ai_actor_economy_capability_binding_initialized:
		return {}
	return _ai_actor_economy_query_port.private_economy_snapshot(
		_ai_actor_economy_capabilities.get(player_index) as AiActorEconomyCapability,
		player_index
	)


func _actor_cash_units(player_index: int) -> int:
	var snapshot := _ai_actor_economy_snapshot(player_index)
	var cash: Dictionary = snapshot.get("cash", {}) if snapshot.get("cash", {}) is Dictionary else {}
	return maxi(0, int(cash.get("total_units", 0)))


func _actor_available_cash_units(player_index: int) -> int:
	var snapshot := _ai_actor_economy_snapshot(player_index)
	var cash: Dictionary = snapshot.get("cash", {}) if snapshot.get("cash", {}) is Dictionary else {}
	return maxi(0, int(cash.get("available_units", 0)))


func set_market_route_query_ports(
	market_public_query_port: AiMarketPublicQueryPort,
	route_public_query_port: AiRoutePublicQueryPort
) -> void:
	_ai_market_public_query_port = market_public_query_port
	_ai_route_public_query_port = route_public_query_port


func _market_public_product(product_id: String) -> Dictionary:
	return _ai_market_public_query_port.public_product(product_id) \
		if _ai_market_public_query_port != null else {}


func _route_public_summary(district_index: int) -> Dictionary:
	return _ai_route_public_query_port.region_route_summary(district_index) \
		if _ai_route_public_query_port != null else {}


func set_monster_military_query_ports(
	monster_public_query_port: AiMonsterPublicQueryPort,
	monster_actor_query_port: AiMonsterActorQueryPort,
	monster_actor_capabilities: Dictionary,
	military_public_query_port: AiMilitaryPublicQueryPort,
	military_actor_query_port: AiMilitaryActorQueryPort,
	military_actor_capabilities: Dictionary
) -> void:
	_ai_monster_public_query_port = monster_public_query_port
	_ai_monster_actor_query_port = monster_actor_query_port
	set_monster_actor_capabilities(monster_actor_capabilities)
	_ai_military_public_query_port = military_public_query_port
	_ai_military_actor_query_port = military_actor_query_port
	set_military_actor_capabilities(military_actor_capabilities)


func set_monster_actor_capabilities(capabilities_by_actor: Dictionary) -> void:
	_ai_monster_actor_capabilities = capabilities_by_actor.duplicate()
	_ai_monster_actor_capability_binding_initialized = true


func set_military_actor_capabilities(capabilities_by_actor: Dictionary) -> void:
	_ai_military_actor_capabilities = capabilities_by_actor.duplicate()
	_ai_military_actor_capability_binding_initialized = true


func set_weather_victory_query_ports(
	weather_public_query_port: AiWeatherPublicQueryPort,
	victory_public_query_port: AiVictoryPublicQueryPort,
	actor_victory_query_port: AiActorVictoryQueryPort,
	actor_victory_capabilities: Dictionary
) -> void:
	_ai_weather_public_query_port = weather_public_query_port
	_ai_victory_public_query_port = victory_public_query_port
	_ai_actor_victory_query_port = actor_victory_query_port
	set_actor_victory_capabilities(actor_victory_capabilities)


func set_actor_victory_capabilities(capabilities_by_actor: Dictionary) -> void:
	_ai_actor_victory_capabilities = capabilities_by_actor.duplicate()
	_ai_actor_victory_capability_binding_initialized = true


func _weather_rules_snapshot() -> Dictionary:
	return _ai_weather_public_query_port.rules_snapshot() \
		if _ai_weather_public_query_port != null and _ai_weather_public_query_port.is_ready() else {}


func _monster_public_roster() -> Array:
	return _ai_monster_public_query_port.public_roster_snapshot() \
		if _ai_monster_public_query_port != null and _ai_monster_public_query_port.is_ready() else []


func _monster_actor_roster(actor_index: int) -> Array:
	if _ai_monster_actor_query_port == null or not _ai_monster_actor_capability_binding_initialized:
		return []
	var snapshot := _ai_monster_actor_query_port.actor_roster_snapshot(
		_ai_monster_actor_capabilities.get(actor_index) as AiMonsterActorCapability,
		actor_index
	)
	var roster: Variant = snapshot.get("roster", [])
	return (roster as Array).duplicate(true) if roster is Array else []


func _monster_actor_at_slot(actor_index: int, slot_index: int) -> Dictionary:
	for actor_variant in _monster_actor_roster(actor_index):
		var actor := actor_variant as Dictionary
		if int(actor.get("slot", -1)) == slot_index:
			return actor.duplicate(true)
	return {}


func _monster_uid_at_slot(actor_index: int, slot_index: int) -> int:
	return int(_monster_actor_at_slot(actor_index, slot_index).get("uid", -1))


func _military_actor_roster(actor_index: int) -> Array:
	if _ai_military_actor_query_port == null or not _ai_military_actor_capability_binding_initialized:
		return []
	var snapshot := _ai_military_actor_query_port.actor_roster_snapshot(
		_ai_military_actor_capabilities.get(actor_index) as AiMilitaryActorCapability,
		actor_index
	)
	var roster: Variant = snapshot.get("roster", [])
	return (roster as Array).duplicate(true) if roster is Array else []


func set_monster_runtime_controller(controller: MonsterRuntimeController) -> void:
	_monster_runtime_controller = controller


func set_military_runtime_controller(controller: MilitaryRuntimeController) -> void:
	_military_runtime_controller = controller



func set_product_market_runtime_controller(controller: ProductMarketRuntimeController) -> void:
	_product_market_runtime_controller = controller


func set_city_gdp_derivative_runtime_controller(controller: CityGdpDerivativeRuntimeController) -> void:
	_city_gdp_derivative_runtime_controller = controller


func set_card_definition_bridge(
	bridge: CardRuntimeDefinitionWorldBridge,
	eligibility_service: CardPlayEligibilityRuntimeService = null
) -> void:
	_card_definition_bridge = bridge
	_card_play_eligibility_runtime_service = eligibility_service


func set_gameplay_balance_diagnostics_service(service: GameplayBalanceDiagnosticsRuntimeService) -> void:
	_gameplay_balance_diagnostics_service = service



func set_route_network_runtime_controller(controller: RouteNetworkRuntimeController) -> void:
	_route_network_runtime_controller = controller


func set_visual_cue_runtime_owner(cue_owner: VisualCueRuntimeOwner) -> void:
	_visual_cue_runtime_owner = cue_owner


func set_card_execution_dependencies(
	submission_controller: CardPlaySubmissionRuntimeController,
	history_service: CardResolutionHistoryRuntimeService
) -> void:
	_card_play_submission_controller = submission_controller
	_card_resolution_history_service = history_service


func set_district_supply_action_port(port: DistrictSupplyActionPort) -> void:
	_district_supply_action_port = port


func set_district_supply_runtime_query_port(
	port: DistrictSupplyRuntimeQueryPort,
	capabilities_by_actor: Dictionary
) -> void:
	_district_supply_runtime_query_port = port
	_district_supply_ai_query_capabilities = capabilities_by_actor.duplicate()
	_district_supply_ai_capability_binding_initialized = true


func set_ai_business_cost_cash_port(
	port: AiBusinessCostCashPort,
	capability: AiBusinessCostCapability
) -> void:
	_ai_business_cost_cash_port = port
	_ai_business_cost_capability = capability


func new_session_identity_for_seat(player_index: int, human_player_count: int) -> Dictionary:
	if player_index < human_player_count:
		return {"is_ai": false, "seat_type": "human", "ai_profile": {}, "ai_memory": {}}
	if AI_PERSONALITY_CATALOG.is_empty():
		return {"is_ai": true, "seat_type": "ai", "ai_profile": {}, "ai_memory": _empty_ai_memory()}
	var ai_order := maxi(0, player_index - human_player_count)
	var profile_index := wrapi(ai_order, 0, AI_PERSONALITY_CATALOG.size())
	var profile := (AI_PERSONALITY_CATALOG[profile_index] as Dictionary).duplicate(true)
	profile["profile_index"] = profile_index
	return {"is_ai": true, "seat_type": "ai", "ai_profile": profile, "ai_memory": _empty_ai_memory()}


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
	if not (policy_profile is AiPolicyProfileResource) \
			or not policy_profile.has_method("to_main_source_dictionary") \
			or not policy_profile.has_method("business_action_terms"):
		_configured = false
		push_error("AiRuntimeController policy profile cannot provide typed runtime parameters.")
		return
	var payload_variant: Variant = policy_profile.call("to_main_source_dictionary")
	_policy_main_payload = (payload_variant as Dictionary).duplicate(true) if payload_variant is Dictionary else {}
	var business_terms_variant: Variant = policy_profile.call("business_action_terms")
	_business_action_policy = (business_terms_variant as Dictionary).duplicate(true) if business_terms_variant is Dictionary else {}
	_configured = not _policy_main_payload.is_empty() and _business_action_policy_valid(_business_action_policy)
	if not _configured:
		push_error("AiRuntimeController requires complete Business Action Policy terms.")
		return
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


func capture_new_session_checkpoint() -> Dictionary:
	return {
		"schema_version": 2,
		"ai_card_decision_timer": ai_card_decision_timer,
		"ai_auction_reaction_timer": ai_auction_reaction_timer,
		"ai_intel_decision_timer": ai_intel_decision_timer,
		"ai_card_decision_enabled": ai_card_decision_enabled,
		"last_receipts": _last_receipts.duplicate(true),
	}


func restore_new_session_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if int(checkpoint.get("schema_version", 0)) != 2 \
			or not TablePresentationPureDataPolicy.is_pure_data(checkpoint) \
			or not (checkpoint.get("last_receipts", []) is Array) \
			or not (checkpoint.get("ai_card_decision_enabled") is bool):
		return {"restored": false, "reason_code": "ai_new_session_checkpoint_invalid"}
	for timer_key in ["ai_card_decision_timer", "ai_auction_reaction_timer", "ai_intel_decision_timer"]:
		var timer_value: Variant = checkpoint.get(timer_key)
		if not (timer_value is int or timer_value is float) or not is_finite(float(timer_value)):
			return {"restored": false, "reason_code": "ai_new_session_checkpoint_invalid"}
	ai_card_decision_timer = float(checkpoint.get("ai_card_decision_timer", 0.0))
	ai_auction_reaction_timer = float(checkpoint.get("ai_auction_reaction_timer", 0.0))
	ai_intel_decision_timer = float(checkpoint.get("ai_intel_decision_timer", 0.0))
	ai_card_decision_enabled = bool(checkpoint.get("ai_card_decision_enabled", true))
	_last_receipts = (checkpoint.get("last_receipts", []) as Array).duplicate(true)
	return {"restored": true, "reason_code": "ai_new_session_checkpoint_restored"}


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
	if response_kind not in ACTIVE_RESPONSE_KINDS:
		return {"planned": false, "reason": "response_kind_unsupported", "response_kind": response_kind, "player_index": player_index, "candidate_count": 0, "selected": {}}
	var candidates: Array = []
	match response_kind:
		"counter_response":
			candidates = _ai_counter_response_candidates(player_index)
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


func to_save_data() -> Dictionary:
	var player_states: Array = []
	if not _actor_state_ready():
		return {}
	var capture := _ai_actor_state_port.capture_ai_state_batch_receipt(
		_ai_actor_state_capabilities,
		true
	)
	if not bool(capture.get("captured", false)):
		return {}
	for row_variant in capture.get("rows", []) as Array:
		var player := row_variant as Dictionary
		player_states.append({
			"player_index": int(player.get("player_index", -1)),
			"ai_profile": (player.get("ai_profile", {}) as Dictionary).duplicate(true),
			"ai_memory": (player.get("ai_memory", {}) as Dictionary).duplicate(true),
		})
	return {
		"ai_card_decision_timer": ai_card_decision_timer,
		"ai_auction_reaction_timer": ai_auction_reaction_timer,
		"ai_intel_decision_timer": ai_intel_decision_timer,
		"ai_card_decision_enabled": ai_card_decision_enabled,
		"player_states": player_states,
	}


func preflight_save_data(data: Dictionary) -> Dictionary:
	if not TablePresentationPureDataPolicy.is_pure_data(data) or not _has_exact_save_fields(data, AI_SAVE_FIELDS):
		return {"accepted": false, "reason_code": "ai_save_shape_invalid"}
	var retired_payload := LegacyContractPayloadGuardV06.validation_report(data)
	if not bool(retired_payload.get("valid", false)):
		return {"accepted": false, "reason_code": "retired_contract_payload_rejected"}
	for timer_key in ["ai_card_decision_timer", "ai_auction_reaction_timer", "ai_intel_decision_timer"]:
		var timer_value: Variant = data.get(timer_key)
		if not (timer_value is int or timer_value is float) or not is_finite(float(timer_value)):
			return {"accepted": false, "reason_code": "ai_save_timer_invalid"}
	if not (data.get("ai_card_decision_enabled") is bool) or not (data.get("player_states") is Array):
		return {"accepted": false, "reason_code": "ai_save_shape_invalid"}
	var normalized_states: Array = []
	var seen_player_indices: Dictionary = {}
	for state_variant in data.get("player_states", []) as Array:
		if not (state_variant is Dictionary):
			return {"accepted": false, "reason_code": "ai_player_save_invalid"}
		var state := state_variant as Dictionary
		if not _has_exact_save_fields(state, AI_PLAYER_SAVE_FIELDS) \
				or not (state.get("player_index") is int) \
				or int(state.get("player_index", -1)) < 0 \
				or not (state.get("ai_profile") is Dictionary) \
				or not (state.get("ai_memory") is Dictionary):
			return {"accepted": false, "reason_code": "ai_player_save_invalid"}
		var player_index := int(state.get("player_index", -1))
		if seen_player_indices.has(player_index):
			return {"accepted": false, "reason_code": "ai_player_save_duplicate"}
		seen_player_indices[player_index] = true
		normalized_states.append(state.duplicate(true))
	return {
		"accepted": true,
		"reason_code": "ai_save_valid",
		"normalized_state": {
			"ai_card_decision_timer": maxf(0.1, float(data.get("ai_card_decision_timer", 2.2))),
			"ai_auction_reaction_timer": maxf(0.1, float(data.get("ai_auction_reaction_timer", 0.7))),
			"ai_intel_decision_timer": maxf(0.1, float(data.get("ai_intel_decision_timer", 5.5))),
			"ai_card_decision_enabled": bool(data.get("ai_card_decision_enabled", true)),
			"player_states": normalized_states,
		},
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var preflight := preflight_save_data(data)
	if not bool(preflight.get("accepted", false)):
		return {"applied": false, "reason_code": str(preflight.get("reason_code", "ai_save_invalid")), "player_state_count": 0}
	var normalized := preflight.get("normalized_state", {}) as Dictionary
	if not _actor_state_ready():
		return {"applied": false, "reason_code": "ai_actor_state_port_missing", "player_state_count": 0}
	var saved_actor_indices: Array = []
	for state_variant in normalized.get("player_states", []) as Array:
		saved_actor_indices.append(int((state_variant as Dictionary).get("player_index", -1)))
	saved_actor_indices.sort()
	var expected_actor_indices := _ai_actor_state_port.ai_player_indices(true)
	expected_actor_indices.sort()
	if saved_actor_indices != expected_actor_indices:
		return {"applied": false, "reason_code": "ai_save_actor_roster_mismatch", "player_state_count": 0}
	var actor_rows: Array = []
	for state_variant in normalized.get("player_states", []) as Array:
		var state: Dictionary = state_variant
		var player_index := int(state.get("player_index", -1))
		var actor := _ai_actor_state_snapshot(player_index)
		if actor.is_empty():
			return {"applied": false, "reason_code": "ai_save_actor_missing", "player_state_count": 0}
		actor_rows.append({
			"player_index": player_index,
			"ai_profile": (state.get("ai_profile", {}) as Dictionary).duplicate(true),
			"ai_memory": _normalized_ai_memory(state.get("ai_memory", {})),
			"expected_revision": str(actor.get("state_revision", "")),
		})
	var batch_receipt := _ai_actor_state_port.apply_ai_state_batch(
		_ai_actor_state_capabilities,
		actor_rows
	)
	if not bool(batch_receipt.get("accepted", false)):
		return {"applied": false, "reason_code": str(batch_receipt.get("reason_code", "ai_save_actor_batch_rejected")), "player_state_count": 0}
	ai_card_decision_timer = float(normalized.get("ai_card_decision_timer", _policy_value("timing", "card_decision_interval_seconds", 2.2)))
	ai_auction_reaction_timer = float(normalized.get("ai_auction_reaction_timer", _policy_value("timing", "auction_reaction_interval_seconds", 0.7)))
	ai_intel_decision_timer = float(normalized.get("ai_intel_decision_timer", _policy_value("timing", "intel_decision_interval_seconds", 5.5)))
	ai_card_decision_enabled = bool(normalized.get("ai_card_decision_enabled", true))
	return {"applied": true, "reason_code": "ai_save_applied", "player_state_count": int((normalized.get("player_states", []) as Array).size())}


func _has_exact_save_fields(dictionary: Dictionary, fields: Array) -> bool:
	if dictionary.size() != fields.size():
		return false
	for field_variant in fields:
		if not dictionary.has(str(field_variant)):
			return false
	return true


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
		"shared_rng": rng != null,
		"typed_weather_public_query_bound": _ai_weather_public_query_port != null and _ai_weather_public_query_port.is_ready(),
		"weather_query_uses_direct_owner": false,
		"typed_victory_public_query_bound": _ai_victory_public_query_port != null and _ai_victory_public_query_port.is_ready(),
		"typed_actor_victory_query_bound": _ai_actor_victory_query_port != null and _ai_actor_victory_capability_binding_initialized and _ai_actor_victory_query_port.is_ready(),
		"victory_query_capabilities_are_actor_scoped": true,
		"victory_query_uses_direct_owner": false,
		"typed_card_submission_bound": _card_play_submission_controller != null,
		"typed_card_history_bound": _card_resolution_history_service != null,
		"typed_business_cost_cash_bound": _ai_business_cost_cash_port != null and _ai_business_cost_capability != null,
		"typed_session_public_query_bound": _ai_session_public_query_port != null and _ai_session_public_query_port.is_ready(),
		"session_public_query_uses_main": false,
		"typed_card_hand_query_bound": _ai_card_hand_query_port != null and _ai_card_hand_query_port.is_ready(),
		"card_hand_query_uses_whole_players": false,
		"typed_actor_economy_query_bound": _ai_actor_economy_query_port != null and _ai_actor_economy_query_port.is_ready(),
		"actor_economy_capabilities_are_actor_scoped": true,
		"actor_economy_query_uses_main": false,
		"actor_economy_query_exposes_rival_private_state": false,
		"typed_market_public_query_bound": _ai_market_public_query_port != null and _ai_market_public_query_port.is_ready(),
		"typed_route_public_query_bound": _ai_route_public_query_port != null and _ai_route_public_query_port.is_ready(),
		"market_route_queries_use_main": false,
		"typed_actor_state_bound": _ai_actor_state_port != null and _ai_actor_state_capability_binding_initialized and _ai_actor_state_port.is_ready(),
		"actor_state_capabilities_are_actor_scoped": true,
		"actor_state_uses_main": false,
		"actor_state_uses_whole_players": false,
		"typed_region_knowledge_bound": _ai_region_knowledge_query_port != null and _ai_region_knowledge_capability_binding_initialized and _ai_region_knowledge_query_port.is_ready(),
		"region_knowledge_capabilities_are_actor_scoped": true,
		"typed_city_inference_command_bound": _ai_city_inference_command_port != null and _ai_city_inference_command_port.is_ready(),
		"city_inference_uses_main": false,
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


func _actor_state_ready() -> bool:
	return _ai_actor_state_port != null \
		and _ai_actor_state_capability_binding_initialized \
		and _ai_actor_state_port.is_ready()


func _ai_actor_state_snapshot(player_index: int) -> Dictionary:
	if not _actor_state_ready():
		return {}
	return _ai_actor_state_port.ai_actor_state_snapshot(
		_ai_actor_state_capabilities.get(player_index) as AiActorStateCapability,
		player_index
	)


func _commit_ai_actor_state(
	player_index: int,
	profile: Dictionary,
	memory: Dictionary,
	actor_snapshot: Dictionary = {}
) -> Dictionary:
	var source := actor_snapshot if not actor_snapshot.is_empty() else _ai_actor_state_snapshot(player_index)
	if source.is_empty() or int(source.get("player_index", -1)) != player_index:
		return {"accepted": false, "changed": false, "reason_code": "ai_actor_state_snapshot_missing"}
	return _ai_actor_state_port.commit_ai_state(
		_ai_actor_state_capabilities.get(player_index) as AiActorStateCapability,
		player_index,
		{
			"ai_profile": profile.duplicate(true),
			"ai_memory": memory.duplicate(true),
		},
		str(source.get("state_revision", ""))
	)


func _commit_ai_memory(
	player_index: int,
	memory: Dictionary,
	actor_snapshot: Dictionary = {}
) -> Dictionary:
	var source := actor_snapshot if not actor_snapshot.is_empty() else _ai_actor_state_snapshot(player_index)
	if source.is_empty():
		return {"accepted": false, "changed": false, "reason_code": "ai_actor_state_snapshot_missing"}
	var profile: Dictionary = source.get("ai_profile", {}) \
		if source.get("ai_profile", {}) is Dictionary else {}
	var baseline_memory := _normalized_ai_memory(source.get("ai_memory", {}))
	var first := _commit_ai_actor_state(player_index, profile, memory, source)
	if bool(first.get("accepted", false)) \
			or str(first.get("reason_code", "")) != "ai_actor_state_revision_changed":
		return first
	var latest := _ai_actor_state_snapshot(player_index)
	if latest.is_empty():
		return first
	if int(latest.get("state_generation", -1)) != int(source.get("state_generation", -2)):
		first["rebase_rejected"] = "actor_state_generation_changed"
		return first
	var rebased_memory := _normalized_ai_memory(latest.get("ai_memory", {}))
	for key_variant in memory.keys():
		var key: Variant = key_variant
		var baseline_has := baseline_memory.has(key)
		var latest_has := rebased_memory.has(key)
		var desired_value: Variant = memory.get(key)
		var local_changed: bool = not baseline_has or baseline_memory.get(key) != desired_value
		if not local_changed:
			continue
		var latest_changed: bool = latest_has != baseline_has \
			or (latest_has and baseline_has and rebased_memory.get(key) != baseline_memory.get(key))
		if latest_changed and (not latest_has or rebased_memory.get(key) != desired_value):
			first["rebase_rejected"] = "actor_state_memory_conflict"
			first["conflict_key"] = key
			return first
		rebased_memory[key] = TablePresentationPureDataPolicy.detached_copy(desired_value)
	for key_variant in baseline_memory.keys():
		var key: Variant = key_variant
		if not memory.has(key):
			var latest_has := rebased_memory.has(key)
			if latest_has and rebased_memory.get(key) != baseline_memory.get(key):
				first["rebase_rejected"] = "actor_state_memory_conflict"
				first["conflict_key"] = key
				return first
			rebased_memory.erase(key)
	var latest_profile: Dictionary = latest.get("ai_profile", {}) \
		if latest.get("ai_profile", {}) is Dictionary else {}
	var retry := _commit_ai_actor_state(player_index, latest_profile, rebased_memory, latest)
	retry["rebased"] = true
	return retry


func _committed_change_count(receipt: Dictionary, proposed_count: int) -> int:
	return maxi(0, proposed_count) \
		if bool(receipt.get("accepted", false)) and bool(receipt.get("changed", false)) else 0


func _city_inference_ports_ready() -> bool:
	return _ai_actor_state_port != null \
		and _ai_actor_state_capability_binding_initialized \
		and _ai_region_knowledge_query_port != null \
		and _ai_region_knowledge_capability_binding_initialized \
		and _ai_city_inference_command_port != null \
		and _ai_actor_state_port.is_ready() \
		and _ai_region_knowledge_query_port.is_ready() \
		and _ai_city_inference_command_port.is_ready()


func _city_inference_rules() -> Dictionary:
	if _ai_region_knowledge_query_port == null:
		return {}
	return _ai_region_knowledge_query_port.inference_rules_snapshot()


func _city_inference_snapshot(actor_index: int) -> Dictionary:
	if not _city_inference_ports_ready():
		return {}
	return _ai_region_knowledge_query_port.actor_intelligence_snapshot(
		_ai_region_knowledge_capabilities.get(actor_index) as AiRegionKnowledgeCapability,
		actor_index
	)


func _typed_ai_player_indices() -> Array:
	return _ai_actor_state_port.ai_player_indices(false) if _actor_state_ready() else []


func _player_count() -> int:
	return _ai_actor_state_port.player_count() if _actor_state_ready() else 0


func _district_count() -> int:
	return _ai_region_knowledge_query_port.region_count() \
		if _ai_region_knowledge_query_port != null and _ai_region_knowledge_query_port.is_ready() else 0


func _public_district(district_index: int) -> Dictionary:
	return _ai_region_knowledge_query_port.public_region(district_index) \
		if _ai_region_knowledge_query_port != null and _ai_region_knowledge_query_port.is_ready() else {}


func _actor_district(actor_index: int, district_index: int) -> Dictionary:
	return _ai_region_knowledge_query_port.region_for_actor(
		_ai_region_knowledge_capabilities.get(actor_index) as AiRegionKnowledgeCapability,
		actor_index,
		district_index
	) if _city_inference_ports_ready() else {}


func _call_world(method_name: StringName, arguments: Array = []) -> Variant:
	return _world_bridge.call("call_world", method_name, arguments) if _world_ready() else null


func _call_monster(method_name: StringName, arguments: Array = []) -> Variant:
	if _monster_runtime_controller == null or not _monster_runtime_controller.has_method(method_name):
		return null
	return _monster_runtime_controller.callv(method_name, arguments)


func _active_monster_wager_ids() -> Array:
	return _ai_monster_public_query_port.active_wager_ids_snapshot() \
		if _ai_monster_public_query_port != null else []


func _monster_wager_decision_snapshot_for_actor(wager_id: int, player_index: int) -> Dictionary:
	if _ai_monster_actor_query_port == null or not _ai_monster_actor_capability_binding_initialized:
		return {}
	return _ai_monster_actor_query_port.wager_decision_snapshot(
		_ai_monster_actor_capabilities.get(player_index) as AiMonsterActorCapability,
		player_index,
		wager_id
	)


func _policy_value(group: String, field: String, default_value: Variant) -> Variant:
	var group_variant: Variant = _policy_main_payload.get(group, {})
	return (group_variant as Dictionary).get(field, default_value) if group_variant is Dictionary else default_value


func _business_action_policy_valid(terms: Dictionary) -> bool:
	return terms.has("chance_percent") and terms.has("max_per_cycle") and terms.has("cost_units") \
		and int(terms.get("chance_percent", -1)) >= 0 and int(terms.get("chance_percent", -1)) <= 100 \
		and int(terms.get("max_per_cycle", 0)) > 0 \
		and int(terms.get("cost_units", 0)) > 0 \
		and str(terms.get("policy_fingerprint", "")) == _business_action_policy_fingerprint(terms)


func _business_action_policy_fingerprint(terms: Dictionary) -> String:
	return JSON.stringify([
		"ai_business_cost_v1",
		int(terms.get("cost_units", -1)),
	]).sha256_text()


var business_cycle_count:
	get:
		return int(_session_public_snapshot().get("business_cycle_revision", 0))

var card_resolution_auction_open:
	get:
		return bool(_card_queue_window_snapshot().get("auction_open", false))

var card_resolution_batch_locked:
	get:
		return bool(_card_queue_window_snapshot().get("batch_locked", false))

var card_resolution_counter_window_active:
	get:
		return bool(_card_queue_window_snapshot().get("counter_window_active", false))

var session_finished:
	get:
		return bool(_session_public_snapshot().get("session_finished", false))

var game_time:
	get:
		return float(_session_public_snapshot().get("game_time", 0.0))

var resolved_card_history:
	get:
		return _card_resolution_history_service.history_snapshot() if _card_resolution_history_service != null else []

var rng:
	get:
		return _run_rng_service


var victory_control_active:
	get:
		var snapshot := _victory_public_snapshot()
		return bool(snapshot.get("available", false)) \
			and str(snapshot.get("state", "idle")) in ["qualification", "audit"]

var victory_control_remaining_seconds:
	get:
		var snapshot := _victory_public_snapshot()
		if not bool(snapshot.get("available", false)):
			return 0.0
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

var CITY_GUESS_CONFIDENCE_DEFAULT:
	get:
		return int(_city_inference_rules().get("confidence_default", WorldSessionState.CITY_GUESS_CONFIDENCE_MEDIUM))

var CITY_GUESS_CONFIDENCE_HIGH:
	get:
		return int(_city_inference_rules().get("confidence_high", WorldSessionState.CITY_GUESS_CONFIDENCE_HIGH))

var CITY_GUESS_CONFIDENCE_LOW:
	get:
		return int(_city_inference_rules().get("confidence_low", WorldSessionState.CITY_GUESS_CONFIDENCE_LOW))

var CITY_GUESS_CONFIDENCE_MEDIUM:
	get:
		return int(_city_inference_rules().get("confidence_medium", WorldSessionState.CITY_GUESS_CONFIDENCE_MEDIUM))

var CITY_GUESS_REASON_CARD:
	get:
		return str(_city_inference_rules().get("reason_card", "card"))

var CITY_GUESS_REASON_DEFAULT:
	get:
		return str(_city_inference_rules().get("reason_default", "intuition"))

var CITY_GUESS_REASON_INTUITION:
	get:
		return str(_city_inference_rules().get("reason_intuition", "intuition"))

var CITY_GUESS_REASON_PRODUCT:
	get:
		return str(_city_inference_rules().get("reason_product", "product"))

var CITY_GUESS_REASON_ROUTE:
	get:
		return str(_city_inference_rules().get("reason_route", "route"))

var PRODUCT_CATALOG:
	get:
		return ProductMarketRuntimeController.PRODUCT_CATALOG

var RIVAL_BUSINESS_ACTION_CHANCE_PERCENT:
	get:
		return int(_business_action_policy.get("chance_percent", 0))

var RIVAL_BUSINESS_ACTION_COST:
	get:
		return int(_business_action_policy.get("cost_units", 0))

var RIVAL_BUSINESS_ACTION_MAX_PER_CYCLE:
	get:
		return int(_business_action_policy.get("max_per_cycle", 0))

var WEATHER_DURATION_MIN_SECONDS:
	get:
		return float(_weather_rules_snapshot().get("duration_min_seconds", 45.0))

var WEATHER_FORECAST_LEAD_MAX_SECONDS:
	get:
		return float(_weather_rules_snapshot().get("forecast_lead_max_seconds", 60.0))

var WEATHER_FORECAST_LEAD_MIN_SECONDS:
	get:
		return float(_weather_rules_snapshot().get("forecast_lead_min_seconds", 30.0))


var WEATHER_ZONE_MAX:
	get:
		return maxi(1, int(_weather_rules_snapshot().get("zone_max", 1)))

# World fact and mutation adapters. Decision ownership stays above this boundary.

func _ruleset_timing_seconds(rule_id: StringName) -> float:
	return _call_monster(&"_ruleset_timing_seconds", [rule_id])

func _card_resolution_active_entry() -> Dictionary:
	var snapshot := _card_queue_public_snapshot()
	return (snapshot.get("active", {}) as Dictionary).duplicate(true) \
		if snapshot.get("active", {}) is Dictionary else {}

func _intel_city_guess_entries(viewer_index: int, limit: int = 6) -> Array:
	var entries: Array = []
	var snapshot := _city_inference_snapshot(viewer_index)
	if snapshot.is_empty():
		return entries
	var player_count := _ai_actor_state_port.player_count()
	for region_variant in snapshot.get("regions", []) as Array:
		if not (region_variant is Dictionary):
			continue
		var region := region_variant as Dictionary
		if bool(region.get("destroyed", false)):
			continue
		var city_index := int(region.get("district_index", -1))
		var city: Dictionary = region.get("city", {}) if region.get("city", {}) is Dictionary else {}
		if not _city_is_active(city) or str(city.get("owner_knowledge", "")) == "actor_own":
			continue
		var guess := int(city.get("owner", -1))
		var marked: bool = guess >= 0 and guess < player_count \
			and str(city.get("owner_knowledge", "")) in ["actor_guess", "authorized_reveal"]
		var competition := 0
		var entry := {
			"district_index": city_index,
			"region_id": str(region.get("region_id", "")),
			"name": str(region.get("name", "区域%d" % (city_index + 1))),
			"guess": guess,
			"marked": marked,
			"confidence": _normalized_city_guess_confidence(int(city.get("owner_confidence", CITY_GUESS_CONFIDENCE_DEFAULT))) if marked else 0,
			"potential_income": int(region.get("current_gdp_per_minute", 0)),
			"last_income": int(city.get("last_income", 0)),
			"products": (city.get("product_names", []) as Array).duplicate(true),
			"demands": (city.get("demand_names", []) as Array).duplicate(true),
			"competition": competition,
			"disrupted": int(city.get("trade_disrupted_routes", 0)),
			"latest_clue": _ai_latest_city_public_clue_text(city),
			"warehouse_pressure": _city_warehouse_stockpile_pressure(city),
			"city": city.duplicate(true),
		}
		entry["priority"] = _city_intel_priority_score(entry)
		entries.append(entry)
	entries.sort_custom(Callable(self, "_sort_ai_city_guess_entry"))
	var result := []
	for index in range(mini(maxi(limit, 0), entries.size())):
		result.append(entries[index])
	return result

func _sort_ai_city_guess_entry(a: Dictionary, b: Dictionary) -> bool:
	var a_priority := int(a.get("priority", 0))
	var b_priority := int(b.get("priority", 0))
	if a_priority != b_priority:
		return a_priority > b_priority
	var a_marked := bool(a.get("marked", false))
	var b_marked := bool(b.get("marked", false))
	if a_marked != b_marked:
		return not a_marked
	var a_income := int(a.get("potential_income", 0))
	var b_income := int(b.get("potential_income", 0))
	if a_income != b_income:
		return a_income > b_income
	return String(a.get("name", "")) < String(b.get("name", ""))

func _city_intel_priority_score(entry: Dictionary) -> int:
	var score := 0
	score += clampi(int(float(int(entry.get("potential_income", 0))) / 10.0), 0, 80)
	score += clampi(int(float(int(entry.get("last_income", 0))) / 20.0), 0, 30)
	score += int(entry.get("competition", 0)) * 18
	score += int(entry.get("disrupted", 0)) * 16
	score += clampi(int(float(int(entry.get("warehouse_pressure", 0))) / 2.0), 0, 120)
	score += (entry.get("products", []) as Array).size() * 4
	score += (entry.get("demands", []) as Array).size() * 4
	var latest_clue := String(entry.get("latest_clue", ""))
	if latest_clue != "" and latest_clue != "暂无公开线索":
		score += 20
	if bool(entry.get("marked", false)):
		match _normalized_city_guess_confidence(int(entry.get("confidence", CITY_GUESS_CONFIDENCE_DEFAULT))):
			CITY_GUESS_CONFIDENCE_LOW:
				score += 18
			CITY_GUESS_CONFIDENCE_MEDIUM:
				score += 8
			CITY_GUESS_CONFIDENCE_HIGH:
				score -= 12
	else:
		score += 45
	return maxi(0, score)

func _normalized_city_guess_confidence(confidence: int) -> int:
	return clampi(confidence, CITY_GUESS_CONFIDENCE_LOW, CITY_GUESS_CONFIDENCE_HIGH)

func _ai_latest_city_public_clue_text(city: Dictionary) -> String:
	var public_clues: Array = city.get("public_clues", []) if city.get("public_clues", []) is Array else []
	for index in range(public_clues.size() - 1, -1, -1):
		var clue := _normalize_city_public_clue_entry(public_clues[index])
		var clue_text := String(clue.get("text", ""))
		if not clue_text.is_empty():
			return clue_text
	var last_clue := String(city.get("last_public_clue", ""))
	return last_clue if not last_clue.is_empty() else "暂无公开线索"

func _victory_public_snapshot() -> Dictionary:
	return _ai_victory_public_query_port.public_snapshot() \
		if _ai_victory_public_query_port != null and _ai_victory_public_query_port.is_ready() else {}

func _victory_snapshot_available() -> bool:
	return bool(_victory_public_snapshot().get("available", false))

func _victory_candidate(viewer_index: int, subject_index: int = -1) -> Dictionary:
	if _ai_actor_victory_query_port == null or not _ai_actor_victory_capability_binding_initialized:
		return {}
	var resolved_subject := viewer_index if subject_index < 0 else subject_index
	return _ai_actor_victory_query_port.candidate_visible_to_actor(
		_ai_actor_victory_capabilities.get(viewer_index) as AiActorVictoryCapability,
		viewer_index,
		resolved_subject
	)

func _victory_top_n_gdp(viewer_index: int, subject_index: int = -1) -> int:
	return maxi(0, int(_victory_candidate(viewer_index, subject_index).get("top_n_gdp_per_minute", 0)))

func _victory_controlled_regions(viewer_index: int, subject_index: int = -1) -> int:
	return maxi(0, int(_victory_candidate(viewer_index, subject_index).get("controlled_region_count", 0)))

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
	if _ai_victory_public_query_port == null or not _ai_victory_public_query_port.is_ready():
		return 1.0
	var state := str(_victory_public_snapshot().get("state", "idle"))
	var timer_id := "public_audit" if state == "audit" else "victory_qualification"
	return maxf(1.0, _ai_victory_public_query_port.timer_duration(timer_id))

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
	return _ai_actor_state_port.is_player_eliminated(player_index) if _actor_state_ready() else true

func _product_count_summary(counts: Dictionary, limit: int = 4, empty_text: String = "暂无") -> String:
	var entries: Array = []
	for key_variant in counts.keys():
		var key := str(key_variant)
		entries.append({"label": key, "count": int(counts.get(key, 0))})
	entries.sort_custom(func(left: Variant, right: Variant) -> bool:
		var left_entry := left as Dictionary
		var right_entry := right as Dictionary
		var left_count := int(left_entry.get("count", 0))
		var right_count := int(right_entry.get("count", 0))
		if left_count != right_count:
			return left_count > right_count
		return str(left_entry.get("label", "")) < str(right_entry.get("label", ""))
	)
	var pieces: Array[String] = []
	for index in range(mini(limit, entries.size())):
		var entry := entries[index] as Dictionary
		pieces.append("%s×%d" % [str(entry.get("label", "")), int(entry.get("count", 0))])
	return " / ".join(pieces) if not pieces.is_empty() else empty_text

func _product_strategy_scores(product_name: String, player_index: int = -1) -> Dictionary:
	var entry := _market_public_product(product_name)
	var supply := int(entry.get("supply", 0))
	var demand := int(entry.get("demand", 0))
	var disrupted := int(entry.get("disrupted", 0))
	var volatility := int(entry.get("volatility", 0))
	var temporary_demand := int(entry.get("temporary_demand_pressure", 0))
	var temporary_supply := int(entry.get("temporary_supply_pressure", 0))
	var contract_seconds := maxf(0.0, float(entry.get("market_contract_seconds", 0.0)))
	if not entry.has("market_contract_seconds"):
		contract_seconds = float(maxi(0, int(entry.get("market_contract_turns", 0)))) \
			* ProductMarketRuntimeController.ECONOMY_LEGACY_TURN_SECONDS
	var contract_demand := int(entry.get("market_contract_demand", 0)) if contract_seconds > 0.0 else 0
	var contract_supply := int(entry.get("market_contract_supply", 0)) if contract_seconds > 0.0 else 0
	var futures_up := 0
	var futures_down := 0
	for position_variant in entry.get("futures_positions", []) as Array:
		if not (position_variant is Dictionary):
			continue
		if str((position_variant as Dictionary).get("direction", "up")) == "down":
			futures_down += 1
		else:
			futures_up += 1
	var warehouse_units := 0
	if player_index >= 0:
		var economy := _ai_actor_economy_snapshot(player_index)
		for position_variant in economy.get("own_futures", []) as Array:
			if not (position_variant is Dictionary):
				continue
			var position := position_variant as Dictionary
			if str(position.get("product_id", "")) == product_name \
					and not str(position.get("warehouse_region_id", "")).is_empty():
				warehouse_units += maxi(1, int(position.get("units", 1)))
	var monster_focus_count := 0
	if _ai_monster_public_query_port != null:
		for monster_variant in _ai_monster_public_query_port.public_catalog_snapshot():
			if monster_variant is Dictionary \
					and ((monster_variant as Dictionary).get("resource_focus", []) as Array).has(product_name):
				monster_focus_count += 1
	var growth_bonus := int(round(maxf(0.0, float(entry.get("growth_multiplier", 1.0)) - 1.0) * 40.0))
	var route_bonus := int(round(maxf(0.0, float(entry.get("route_flow_multiplier", 1.0)) - 1.0) * 32.0))
	var long_score := maxi(0, demand - supply) * 14 + demand * 3 + disrupted * 10 + temporary_demand * 8 + contract_demand * 9 + growth_bonus + futures_up * 3
	var short_score := maxi(0, supply - demand) * 14 + supply * 3 + temporary_supply * 8 + contract_supply * 9 + volatility * 2 + futures_down * 3
	var stockpile_score := long_score + volatility * 4 + warehouse_units * 5 + route_bonus
	var route_score := (supply + demand) * 6 + route_bonus + disrupted * 4 + contract_demand * 3 + contract_supply * 3
	var monster_risk_score := monster_focus_count * 18 + warehouse_units * 7 + disrupted * 3
	return {
		"long": maxi(0, long_score),
		"short": maxi(0, short_score),
		"stockpile": maxi(0, stockpile_score),
		"route": maxi(0, route_score),
		"monster": maxi(0, monster_risk_score),
		"supply": supply,
		"demand": demand,
		"disrupted": disrupted,
		"volatility": volatility,
	}

func _limited_name_list(names: Array, limit: int = 6, empty_text: String = "无") -> String:
	return _call_monster(&"_limited_name_list", [names, limit, empty_text])

func _player_product_flow(player_index: int, product_name: String) -> int:
	var economy := _ai_actor_economy_snapshot(player_index)
	var summary: Dictionary = economy.get("economy_summary", {}) \
		if economy.get("economy_summary", {}) is Dictionary else {}
	var flow_by_id: Dictionary = summary.get("product_flow_by_id", {}) \
		if summary.get("product_flow_by_id", {}) is Dictionary else {}
	return maxi(0, int(flow_by_id.get(product_name, 0)))

func _first_player_flow_product(player_index: int) -> String:
	var economy := _ai_actor_economy_snapshot(player_index)
	for city_variant in economy.get("own_cities", []) as Array:
		if not (city_variant is Dictionary):
			continue
		var city := city_variant as Dictionary
		for key in ["product_names", "demand_names"]:
			var names: Array = city.get(key, []) if city.get(key, []) is Array else []
			if not names.is_empty():
				return str(names[0])
	if _ai_market_public_query_port == null:
		return ""
	var market := _ai_market_public_query_port.public_snapshot()
	var products: Array = market.get("products", []) if market.get("products", []) is Array else []
	return str((products[0] as Dictionary).get("product_id", "")) \
		if not products.is_empty() and products[0] is Dictionary else ""

func _best_player_flow_product(player_index: int, required: int = 1, preferred_products: Array = []) -> String:
	var safe_required := maxi(1, required)
	var economy := _ai_actor_economy_snapshot(player_index)
	var summary: Dictionary = economy.get("economy_summary", {}) \
		if economy.get("economy_summary", {}) is Dictionary else {}
	var flow_by_id: Dictionary = summary.get("product_flow_by_id", {}) \
		if summary.get("product_flow_by_id", {}) is Dictionary else {}
	var flow_order: Array = summary.get("product_flow_order", []) \
		if summary.get("product_flow_order", []) is Array else []
	var seen: Dictionary = {}
	for product_variant in preferred_products:
		var product_id := str(product_variant).strip_edges()
		if product_id.is_empty() or seen.has(product_id):
			continue
		seen[product_id] = true
		if int(flow_by_id.get(product_id, 0)) >= safe_required:
			return product_id
	var best_product := ""
	var best_flow := -1
	for product_variant in flow_order:
		var product_id := str(product_variant)
		if product_id.is_empty() or seen.has(product_id):
			continue
		seen[product_id] = true
		var flow := int(flow_by_id.get(product_id, 0))
		if flow >= safe_required and flow > best_flow:
			best_product = product_id
			best_flow = flow
	return best_product

func _skill_play_product(skill: Dictionary, player_index: int) -> String:
	var explicit := str(skill.get("play_product", "")).strip_edges()
	return explicit if not explicit.is_empty() else _first_player_flow_product(player_index)

func _skill_play_flow_required(skill: Dictionary, _player_index: int = -1) -> int:
	return maxi(0, int(skill.get("play_flow_required", 0))) \
		if bool(skill.get("legacy_flow_gate_enabled", false)) else 0

func _skill_play_region_scope(skill: Dictionary, player_index: int) -> String:
	return str(_skill_play_requirement_status(player_index, skill).get("scope", CardPlayRequirementPolicyScript.SCOPE_OWN_BEST_REGION))

func _best_player_gdp_share_district(player_index: int) -> int:
	return int(_ai_card_best_share_snapshot(player_index).get(
		"best_share_district",
		-1
	))

func _skill_play_requirement_status(player_index: int, skill: Dictionary) -> Dictionary:
	var receipt := _ai_card_requirement_snapshot(player_index, skill, -1)
	var value: Variant = receipt.get("requirement_status", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}

func _skill_play_cash_cost(skill: Dictionary, player_index: int) -> int:
	return int(_skill_play_requirement_status(player_index, skill).get("cash_cost", 0))

func _can_play_skill_now(player_index: int, skill: Dictionary) -> bool:
	return bool(_ai_card_eligibility_snapshot(
		player_index,
		skill,
		"rule",
		-1
	).get("allowed", false))

func _signed_int_text(value: int) -> String:
	return "+%d" % value if value > 0 else "%d" % value

func _card_price(skill_name: String, district_index: int = -1, _player_index: int = -1) -> int:
	if skill_name.is_empty():
		return 0
	if district_index >= 0:
		if _district_supply_runtime_query_port == null:
			return 0
		var preview := _district_supply_runtime_query_port.public_price_preview(district_index, skill_name)
		return int(preview.get("final_price", 0)) if not preview.is_empty() else 0
	if _card_definition_bridge == null:
		return 0
	var price_name := "%s1" % _card_definition_bridge.family_id(skill_name)
	if not _card_definition_bridge.has_runtime_card(price_name):
		price_name = skill_name
	var skill := _card_definition_bridge.resolve_definition(price_name)
	return int(_runtime_balance_model.card_price_for_skill(skill)) if not skill.is_empty() else 0

func _card_strength_budget_points(card_name: String) -> int:
	return _gameplay_balance_diagnostics_service.card_budget_points_for_id(card_name) if _gameplay_balance_diagnostics_service != null else 0

func _product_price(product_name: String) -> int:
	return _ai_market_public_query_port.public_price(product_name) \
		if _ai_market_public_query_port != null else 0

func _active_auto_monster_count() -> int:
	return _ai_monster_public_query_port.active_monster_count() \
		if _ai_monster_public_query_port != null else 0


func _auto_monster_slot_by_uid(uid: int) -> int:
	return _ai_monster_public_query_port.slot_for_uid(uid) \
		if _ai_monster_public_query_port != null else -1


func _military_unit_type_label(unit_or_skill: Dictionary) -> String:
	return _ai_military_public_query_port.unit_type_label(unit_or_skill) \
		if _ai_military_public_query_port != null else "military"


func _can_deploy_military_card_at_district(skill: Dictionary, district_index: int) -> bool:
	return _ai_military_public_query_port.can_deploy_at_district(skill, district_index) \
		if _ai_military_public_query_port != null else false


func _military_unit_terrain_move_multiplier(unit_or_skill: Dictionary, district_index: int) -> float:
	return _ai_military_public_query_port.terrain_move_multiplier(unit_or_skill, district_index) \
		if _ai_military_public_query_port != null else 1.0


func _military_unit_mobility_summary(unit_or_skill: Dictionary) -> String:
	return _ai_military_public_query_port.mobility_summary(unit_or_skill) \
		if _ai_military_public_query_port != null else ""


func _military_unit_index_by_uid(uid: int) -> int:
	var roster := _ai_military_public_query_port.public_roster_snapshot() \
		if _ai_military_public_query_port != null else []
	for index in range(roster.size()):
		if int((roster[index] as Dictionary).get("uid", 0)) == uid:
			return index
	return -1


func _owned_active_military_unit_index(player_index: int) -> int:
	var roster := _military_actor_roster(player_index)
	for index in range(roster.size()):
		var unit := roster[index] as Dictionary
		if str(unit.get("ownership_scope", "")) == "actor_own" \
			and int(unit.get("hp", 0)) > 0 and float(unit.get("remaining_time", 0.0)) > 0.0:
			return index
	return -1

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
	if product_name.is_empty() or district_index < 0 or district_index >= _district_count():
		return false
	var district := _public_district(district_index)
	if (district.get("products", []) as Array).has(product_name) or (district.get("demands", []) as Array).has(product_name):
		return true
	var city := _district_city(district_index)
	return _city_is_active(city) and (_city_product_names(city).has(product_name) or _city_demand_names(city).has(product_name))

func _skill_exists(skill_name: String) -> bool:
	return _card_definition_bridge.has_runtime_card(skill_name) if _card_definition_bridge != null else false

func _skill_definition(skill_name: String) -> Dictionary:
	return _card_definition_bridge.resolve_definition(skill_name) if _card_definition_bridge != null else {}

func _request_table_presentation_refresh() -> void:
	return _call_monster(&"request_table_presentation_refresh")

func _district_city(index: int, actor_index := -1) -> Dictionary:
	var district := _actor_district(actor_index, index) if actor_index >= 0 else _public_district(index)
	return (district.get("city", {}) as Dictionary).duplicate(true) \
		if district.get("city", {}) is Dictionary else {}

func _city_is_active(city: Dictionary) -> bool:
	return not city.is_empty() and bool(city.get("active", true))

func _city_product_names(city: Dictionary) -> Array:
	if city.get("product_names", []) is Array and not (city.get("product_names", []) as Array).is_empty():
		return (city.get("product_names", []) as Array).duplicate(true)
	var result: Array = []
	for product_variant in city.get("products", []) as Array:
		if product_variant is Dictionary:
			result.append(str((product_variant as Dictionary).get("name", "未知商品")))
		else:
			result.append(str(product_variant))
	return result

func _city_demand_names(city: Dictionary) -> Array:
	if city.get("demand_names", []) is Array and not (city.get("demand_names", []) as Array).is_empty():
		return (city.get("demand_names", []) as Array).duplicate(true)
	var result: Array = []
	for product_variant in city.get("demands", []) as Array:
		result.append(str(product_variant))
	return result

func _normalize_city_public_clue_entry(value: Variant) -> Dictionary:
	var entry: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	var clue_text := str(entry.get("text", entry.get("clue", ""))).strip_edges() \
		if value is Dictionary else str(value).strip_edges()
	if clue_text.is_empty():
		return {}
	entry["text"] = clue_text
	if not entry.has("time"):
		entry["time"] = float(entry.get("game_time", -1.0))
	if not entry.has("cycle"):
		entry["cycle"] = 0
	if str(entry.get("kind", "")).is_empty():
		entry["kind"] = _city_public_clue_kind(clue_text)
	if not (entry.get("products", []) is Array) or (entry.get("products", []) as Array).is_empty():
		var products: Array = []
		for product_variant in ProductMarketRuntimeController.PRODUCT_CATALOG:
			var product_name := str(product_variant)
			if not product_name.is_empty() and clue_text.contains(product_name):
				products.append(product_name)
		entry["products"] = products
	return entry


func _city_public_clue_kind(clue_text: String) -> String:
	if clue_text.contains("合约"):
		return "合约"
	if clue_text.contains("商路") or clue_text.contains("断路") or clue_text.contains("黑客"):
		return "商路"
	if clue_text.contains("需求压力") or clue_text.contains("市场") or clue_text.contains("价格"):
		return "市场"
	if clue_text.contains("GDP") or clue_text.contains("生产") or clue_text.contains("交通") or clue_text.contains("消费"):
		return "经营"
	return "公开"

func _mark_city_guess_for_player(viewer_index: int, city_index: int, guessed_player: int, confidence: int = CITY_GUESS_CONFIDENCE_DEFAULT, reason: String = CITY_GUESS_REASON_DEFAULT) -> bool:
	var snapshot := _city_inference_snapshot(viewer_index)
	if snapshot.is_empty():
		return false
	var region_id := ""
	for region_variant in snapshot.get("regions", []) as Array:
		if region_variant is Dictionary and int((region_variant as Dictionary).get("district_index", -1)) == city_index:
			region_id = str((region_variant as Dictionary).get("region_id", ""))
			break
	var owner_revision := str(snapshot.get("owner_revision", ""))
	if region_id.is_empty() or owner_revision.is_empty():
		return false
	var command_id := "ai-city-inference:%s" % JSON.stringify([
		viewer_index,
		region_id,
		guessed_player,
		confidence,
		reason,
		owner_revision,
	]).sha256_text()
	var receipt := _ai_city_inference_command_port.submit_guess(
		_ai_region_knowledge_capabilities.get(viewer_index) as AiRegionKnowledgeCapability,
		command_id,
		viewer_index,
		region_id,
		guessed_player,
		confidence,
		reason,
		owner_revision
	)
	return bool(receipt.get("applied", false))

func _latest_public_history_resolution_id() -> int:
	if _card_resolution_history_service == null:
		return -1
	var entries := _card_resolution_history_service.public_history_snapshot()
	for index in range(entries.size() - 1, -1, -1):
		if entries[index] is Dictionary:
			var resolution_id := int((entries[index] as Dictionary).get("resolution_id", -1))
			if resolution_id >= 0:
				return resolution_id
	return -1

func _monster_wager_base_percent(entry: Dictionary) -> int:
	return _call_monster(&"_monster_wager_base_percent", [entry])

func _monster_wager_clamped_percent(entry: Dictionary, percent: int) -> int:
	return _call_monster(&"_monster_wager_clamped_percent", [entry, percent])

func _monster_wager_amount_for_percent(player_index: int, percent: int, entry: Dictionary = {}) -> int:
	return _call_monster(&"_monster_wager_amount_for_percent", [player_index, percent, entry])

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

func _skill_duration_seconds(
	skill: Dictionary,
	seconds_key: String,
	turns_key: String,
	default_turns: int = 0
) -> float:
	if skill.has(seconds_key):
		return maxf(0.0, float(skill.get(seconds_key, 0.0)))
	return float(maxi(0, int(skill.get(turns_key, default_turns)))) \
		* ProductMarketRuntimeController.ECONOMY_LEGACY_TURN_SECONDS

func _city_gdp_derivative_duration_seconds(skill: Dictionary) -> float:
	return float(_city_gdp_derivative_terms(skill).get("duration_seconds", 0.0))

func _can_summon_monster_card_at_district(skill: Dictionary, district_index: int) -> bool:
	return _call_monster(&"_can_summon_monster_card_at_district", [skill, district_index])

func _short_card_text(text: String, max_len: int) -> String:
	return _call_world(&"_short_card_text", [text, max_len])

func _queue_monster_card_as_counter(
	player_index: int,
	slot_index: int,
	target_district: int,
	target_product: String,
	selected_resolution_id: int
) -> Dictionary:
	if _card_play_submission_controller == null:
		return {"accepted": false, "reason": "submission_controller_missing"}
	return _card_play_submission_controller.submit_monster_counter_conversion({
		"player_index": player_index,
		"slot_index": slot_index,
		"selected_district": target_district,
		"selected_trade_product": target_product,
		"selected_card_resolution_id": selected_resolution_id,
		"target_source_revision": int(_session_public_snapshot().get("session_revision", 0)),
		"submission_source": "ai_counter_conversion",
	})


func _player_is_ai(player_index: int) -> bool:
	return _ai_actor_state_port.is_ai_player(player_index) if _actor_state_ready() else false

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
	if skill_name.is_empty() or _card_definition_bridge == null:
		return ""
	var rank := _card_definition_bridge.rank(skill_name)
	if rank <= 0:
		return skill_name if _card_definition_bridge.has_runtime_card(skill_name) else ""
	var base_name := "%s1" % _card_definition_bridge.family_id(skill_name)
	return base_name if _card_definition_bridge.has_runtime_card(base_name) else ""

func _district_supply_card_ids(district_index: int) -> Array:
	return _district_supply_runtime_query_port.public_card_ids_for_district(district_index) \
		if _district_supply_runtime_query_port != null else []

func _alive_district_indices() -> Array:
	return _call_world(&"_alive_district_indices")

func _weather_template(type_id: String) -> Dictionary:
	return _ai_weather_public_query_port.definition_snapshot(type_id) \
		if _ai_weather_public_query_port != null else {}

func _weather_label(type_id: String) -> String:
	return _ai_weather_public_query_port.label(type_id) \
		if _ai_weather_public_query_port != null else type_id

func _weather_zone_count_for_planet() -> int:
	return maxi(1, int(_weather_rules_snapshot().get("zone_count_for_planet", 1)))


func _weather_type_ids() -> Array:
	var value: Variant = _weather_rules_snapshot().get("weather_type_ids", [])
	return (value as Array).duplicate() if value is Array else []


func _weather_preview_districts(anchor_index: int, zone_count: int) -> Array:
	return _ai_weather_public_query_port.preview_districts(anchor_index, zone_count) \
		if _ai_weather_public_query_port != null else []

func _weighted_pick_index(weights: Array) -> int:
	return _call_monster(&"_weighted_pick_index", [weights])

func _card_display_name(card_name: String) -> String:
	if card_name.is_empty() or _card_definition_bridge == null:
		return ""
	var family := _card_definition_bridge.family_id(card_name)
	var rank := maxi(1, _card_definition_bridge.rank(card_name))
	return "%s %s" % [family, _card_rank_level_text(rank)]


func _card_rank_level_text(rank: int) -> String:
	var roman_levels := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	return "%s级" % roman_levels[clampi(rank, 1, roman_levels.size()) - 1]

func _district_event_weight(index: int, actor_index: int = -1) -> int:
	if index < 0 or index >= _district_count():
		return 0
	var district := _public_district(index)
	if district.is_empty() or bool(district.get("destroyed", false)):
		return 0
	var score := AI_EVENT_TARGET_BASE_WEIGHT
	score += maxi(0, int(district.get("panic", 0))) * AI_EVENT_TARGET_PANIC_WEIGHT
	var public_city: Dictionary = district.get("city", {}) \
		if district.get("city", {}) is Dictionary else {}
	if _city_is_active(public_city):
		score += AI_EVENT_TARGET_CITY_BONUS + (public_city.get("products", []) as Array).size()
		score += maxi(0, int(public_city.get("competition_matches", 0))) * AI_EVENT_TARGET_COMPETITION_WEIGHT
	if actor_index >= 0:
		var actor_region := _actor_district(actor_index, index)
		var actor_city: Dictionary = actor_region.get("city", {}) \
			if actor_region.get("city", {}) is Dictionary else {}
		if str(actor_city.get("owner_knowledge", "")) == "actor_own":
			score += maxi(0, int(actor_city.get("warehouse_stockpile_count", 0))) * AI_OWN_WAREHOUSE_COUNT_PRESSURE
			score += maxi(0, int(actor_city.get("warehouse_stockpile_units", 0))) * AI_OWN_WAREHOUSE_UNIT_PRESSURE
			score += (actor_city.get("warehouse_stockpile_products", []) as Array).size() * AI_OWN_WAREHOUSE_PRODUCT_PRESSURE
	if _ai_route_public_query_port != null and _ai_route_public_query_port.is_ready():
		var route_summary := _ai_route_public_query_port.region_route_summary(index)
		score += maxi(0, int(route_summary.get("legal_route_count", 0))) * AI_EVENT_TARGET_TRADE_WEIGHT
	if bool(district.get("miasma", false)):
		score += AI_EVENT_TARGET_MIASMA_BONUS
	for actor_variant in _monster_public_roster():
		if not (actor_variant is Dictionary):
			continue
		var monster := actor_variant as Dictionary
		if not bool(monster.get("down", false)) and int(monster.get("position", -1)) == index:
			score += AI_EVENT_TARGET_MONSTER_BONUS
	return maxi(1, score)

func _monster_resource_match_score(actor: Dictionary, index: int, player_index: int) -> int:
	if _ai_monster_public_query_port == null or not _ai_monster_public_query_port.is_ready():
		return 0
	var focus: Array = actor.get("resource_focus", []) if actor.get("resource_focus", []) is Array else []
	if focus.is_empty():
		return 0
	var score := _ai_monster_public_query_port.public_resource_match_score_for_actor(actor, index)
	if player_index < 0 or score >= 8:
		return mini(score, 8)
	var economy := _ai_actor_economy_snapshot(player_index)
	var own_cities_variant: Variant = economy.get("own_cities", [])
	if not (own_cities_variant is Array):
		return mini(score, 8)
	for city_variant in own_cities_variant as Array:
		if not (city_variant is Dictionary):
			continue
		var city := city_variant as Dictionary
		if int(city.get("district_index", -1)) != index:
			continue
		var warehouse_products: Array = city.get("warehouse_stockpile_products", []) \
			if city.get("warehouse_stockpile_products", []) is Array else []
		var warehouse_units := maxi(0, int(city.get("warehouse_stockpile_units", 0)))
		for product_variant in focus:
			if warehouse_products.has(str(product_variant)):
				score += 2 + mini(3, int(float(warehouse_units) / 2.0))
		break
	return mini(score, 8)

func _route_network_load_for_legacy_region(index: int) -> int:
	return int(_route_public_summary(index).get("legal_route_count", 0))

func _market_listing_purchasable(district_index: int) -> bool:
	return _district_supply_runtime_query_port.public_market_purchasable(district_index) \
		if _district_supply_runtime_query_port != null else false

func _skill_rank(skill_name: String) -> int:
	return _card_definition_bridge.rank(skill_name) if _card_definition_bridge != null else 0

func _ai_has_current_card_submission(player_index: int) -> bool:
	var snapshot := _ai_card_queue_snapshot(player_index)
	return snapshot.is_empty() or bool(snapshot.get("has_current_submission", false))

func _ai_has_next_card_submission(player_index: int) -> bool:
	var snapshot := _ai_card_queue_snapshot(player_index)
	return snapshot.is_empty() or bool(snapshot.get("has_next_submission", false))

func _find_highest_family_card_slot(player: Dictionary, skill_name: String) -> int:
	if _card_definition_bridge == null:
		return -1
	var family := _card_definition_bridge.family_id(skill_name)
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	var best_slot := -1
	var best_rank := -1
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var current_name := str((slots[slot_index] as Dictionary).get("name", ""))
		if _card_definition_bridge.family_id(current_name) != family:
			continue
		var rank := maxi(1, _card_definition_bridge.rank(current_name))
		if rank > best_rank:
			best_rank = rank
			best_slot = slot_index
	return best_slot

func _player_counted_hand_size(player: Dictionary) -> int:
	var count := 0
	for skill_variant in player.get("slots", []):
		if not (skill_variant is Dictionary):
			continue
		var skill := skill_variant as Dictionary
		var persistent_bound_action := bool(skill.get("persistent", false)) \
			and ["monster_bound_action", "military_command"].has(str(skill.get("kind", "")))
		if not persistent_bound_action:
			count += 1
	return count

func _discardable_hand_slots_for_purchase(player_index: int) -> Array:
	return _district_supply_runtime_query_port.private_discardable_slots_for_actor(
		_district_supply_ai_query_capabilities.get(player_index) as DistrictSupplyAiQueryCapability,
		player_index
	) if _district_supply_runtime_query_port != null else []

func _player_can_receive_card_with_discard(player_index: int, skill_name: String) -> bool:
	return _district_supply_runtime_query_port.private_can_receive_with_discard(
		_district_supply_ai_query_capabilities.get(player_index) as DistrictSupplyAiQueryCapability,
		player_index,
		skill_name
	) if _district_supply_runtime_query_port != null else false

func _purchase_requires_discard(player_index: int, skill_name: String) -> bool:
	return _district_supply_runtime_query_port.private_requires_discard(
		_district_supply_ai_query_capabilities.get(player_index) as DistrictSupplyAiQueryCapability,
		player_index,
		skill_name
	) if _district_supply_runtime_query_port != null else false

func _city_warehouse_stockpile_pressure(city: Dictionary) -> int:
	if not _city_is_active(city):
		return 0
	var count := maxi(0, int(city.get("warehouse_stockpile_count", 0)))
	var units := maxi(0, int(city.get("warehouse_stockpile_units", 0)))
	var products: Array = city.get("warehouse_stockpile_products", []) \
		if city.get("warehouse_stockpile_products", []) is Array else []
	return count * int(_policy_value("city_inference", "warehouse_stockpile_count_pressure", 34)) \
		+ units * int(_policy_value("city_inference", "warehouse_stockpile_unit_pressure", 8)) \
		+ products.size() * int(_policy_value("city_inference", "warehouse_stockpile_product_pressure", 10))

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

func _buy_card_for_player_from_district(player_index: int, district_index: int, skill_name: String, _anonymous: bool = false, _ignore_cooldown: bool = false, discard_slot: int = -1) -> bool:
	if _district_supply_action_port == null:
		return false
	return _district_supply_action_port.submit_ai_purchase(player_index, district_index, skill_name, discard_slot)

func _card_play_target_status(skill: Dictionary) -> Dictionary:
	return _card_play_eligibility_runtime_service.target_status({"skill": skill}, {}) \
		if _card_play_eligibility_runtime_service != null else {}


func _skill_targets_monster(skill: Dictionary) -> bool:
	return bool(_card_play_target_status(skill).get("targets_monster", false))


func _skill_targets_player(skill: Dictionary) -> bool:
	return bool(_card_play_target_status(skill).get("targets_player", false))

func _playable_card_resolution_coverage_report() -> Dictionary:
	return _gameplay_balance_diagnostics_service.playable_card_resolution_coverage_report() if _gameplay_balance_diagnostics_service != null else {}

func _card_can_open_counter_window(entry: Dictionary) -> bool:
	return bool(entry.get("counterable", false))

func _card_resolution_entry_card_label(entry: Dictionary) -> String:
	return str(entry.get("card_label", entry.get("card_name", "匿名卡牌")))

func _queue_skill_resolution(
	player_index: int,
	slot_index: int,
	target_slot: int = -1,
	target_player: int = -1,
	selected_resolution_id: int = -1,
	target_district: int = -1,
	target_product: String = "",
	target_monster_uid: int = -1
) -> Dictionary:
	if _card_play_submission_controller == null:
		return {"accepted": false, "reason": "submission_controller_missing"}
	return _card_play_submission_controller.submit_card_play({
		"player_index": player_index,
		"slot_index": slot_index,
		"target_slot": target_slot,
		"target_monster_uid": target_monster_uid,
		"target_player": target_player,
		"selected_district": target_district,
		"selected_trade_product": target_product,
		"selected_card_resolution_id": selected_resolution_id,
		"target_source_revision": int(_session_public_snapshot().get("session_revision", 0)),
		"submission_source": "ai",
	})


func _is_counter_skill(skill: Dictionary) -> bool:
	return bool(_card_play_target_status(skill).get("is_counter", false))

func _can_convert_monster_card_to_counter(player_index: int, skill: Dictionary) -> bool:
	var result := _ai_card_eligibility_snapshot(
		player_index,
		skill,
		"hand",
		-1
	)
	return str(result.get("reason_code", "")) == "counter_conversion_ready"

func _skill_is_counterable_player_interaction(skill: Dictionary) -> bool:
	return bool(_card_play_target_status(skill).get(
		"counterable_player_interaction",
		false
	))

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
	var response: Variant = _call_monster(&"submit_monster_wager_response", [wager_id, player_index, StringName(side), stake_percent, forced, metadata])
	return bool((response as Dictionary).get("applied", false)) if response is Dictionary else false

func _monster_wager_actor_expected_damage_score(actor: Dictionary) -> int:
	return _call_monster(&"_monster_wager_actor_expected_damage_score", [actor])

func _active_city_district_indices() -> Array:
	return _route_network_runtime_controller.active_region_legacy_indices() if _route_network_runtime_controller != null else []

func _player_active_city_count(player_index: int) -> int:
	return _call_world(&"_player_active_city_count", [player_index])

func _visible_active_city_count_for_actor(viewer_index: int, subject_index: int) -> int:
	var result := 0
	for district_index in range(_district_count()):
		var city := _district_city(district_index, viewer_index)
		if _city_is_active(city) and int(city.get("owner", -1)) == subject_index:
			result += 1
	return result

func _visible_active_monster_count_for_actor(viewer_index: int, subject_index: int) -> int:
	var result := 0
	for actor_variant in _monster_actor_roster(viewer_index):
		var actor := actor_variant as Dictionary
		if bool(actor.get("down", false)):
			continue
		var ownership_scope := str(actor.get("ownership_scope", "public_unknown"))
		if subject_index == viewer_index and ownership_scope == "actor_own":
			result += 1
		elif ownership_scope == "public_revealed" \
				and int(actor.get("public_owner_index", -1)) == subject_index:
			result += 1
	return result

func _city_competition_matches(district_index: int) -> int:
	return _call_world(&"_city_competition_matches", [district_index])

func _route_network_routes_for_legacy_region(district_index: int) -> Array:
	var rows: Variant = _route_public_summary(district_index).get("rows", [])
	return (rows as Array).duplicate(true) if rows is Array else []

func _city_cycle_income(district_index: int, competition_matches: int) -> int:
	return _call_world(&"_city_cycle_income", [district_index, competition_matches])

func _city_cycle_income_breakdown(district_index: int, competition_matches: int) -> Dictionary:
	return _call_world(&"_city_cycle_income_breakdown", [district_index, competition_matches])

func _add_action_callout(actor: String, action: String, detail: String, color: Color, world_position: Vector2, duration: float = ACTION_CALLOUT_DURATION) -> void:
	if _visual_cue_runtime_owner != null:
		_visual_cue_runtime_owner.add_action_callout(actor, action, detail, color, world_position, duration)

func _auto_monster_target_weight_parts(actor: Dictionary, index: int) -> Dictionary:
	return _call_monster(&"_auto_monster_target_weight_parts", [actor, index])

func _auto_monster_target_weight(actor: Dictionary, index: int) -> int:
	return _call_monster(&"_auto_monster_target_weight", [actor, index])

func _auto_monster_target_factor_summary(actor: Dictionary, index: int) -> String:
	return _call_monster(&"_auto_monster_target_factor_summary", [actor, index])

func _district_center(index: int) -> Vector2:
	var district := _public_district(index)
	return district.get("center", Vector2.ZERO) if district.get("center", Vector2.ZERO) is Vector2 else Vector2.ZERO


func _entity_world_position(entity: Dictionary) -> Vector2:
	var value: Variant = entity.get("world_position", Vector2.ZERO)
	if value is Vector2:
		return value
	if value is Dictionary:
		return Vector2(float((value as Dictionary).get("x", 0.0)), float((value as Dictionary).get("y", 0.0)))
	return Vector2.ZERO


func _wrapped_distance(from_position: Vector2, to_position: Vector2) -> float:
	return _ai_monster_public_query_port.public_distance_between_entities(
		{"world_position": from_position},
		{"world_position": to_position}
	) if _ai_monster_public_query_port != null else INF


func _entity_distance_to_district(entity: Dictionary, district_index: int) -> float:
	return _wrapped_distance(_entity_world_position(entity), _district_center(district_index))


func _meters_text(value: float) -> String:
	return _ai_monster_public_query_port.meters_text(value) \
		if _ai_monster_public_query_port != null else ""

func _log(message: String) -> void:
	return _call_monster(&"publish_public_log_message", [message])

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
	var profile_variant: Variant = _ai_profile_for_player(player_index)
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
	var memory_variant: Variant = _ai_memory_for_player(player_index)
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
	for player_index_variant in (_ai_actor_state_port.ai_player_indices(true) if _actor_state_ready() else []):
		result.append(int(player_index_variant))
	for i in range(result.size()):
		var swap_index := int(rng.randi_range(i, result.size() - 1))
		var tmp = result[i]
		result[i] = result[swap_index]
		result[swap_index] = tmp
	return result
func _district_product_overlap_with_rival_cities(player_index: int, district_index: int) -> int:
	if district_index < 0 or district_index >= _district_count():
		return 0
	var local_products: Array = _public_district(district_index).get("products", [])
	if local_products.is_empty():
		return 0
	var matches := 0
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index, player_index)
		if int(city.get("owner", -1)) == player_index:
			continue
		for product_name in _city_product_names(city):
			if local_products.has(product_name):
				matches += 1
	return matches
func _district_ocean_neighbor_count(district_index: int) -> int:
	if district_index < 0 or district_index >= _district_count():
		return 0
	var count := 0
	for neighbor_variant in _public_district(district_index).get("neighbors", []):
		var neighbor := int(neighbor_variant)
		if neighbor >= 0 and neighbor < _district_count() and String(_public_district(neighbor).get("terrain", "land")) == "ocean":
			count += 1
	return count
func _auto_build_monster_risk_score(district_index: int, player_index: int) -> int:
	if district_index < 0 or district_index >= _district_count():
		return 0
	var risk := int(round(float(_public_district(district_index).get("panic", 0)) / 4.0))
	for actor_variant in _monster_public_roster():
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
		risk += _monster_resource_match_score(actor, district_index, player_index) * 8
	return risk
func _active_city_indices_for_player(player_index: int) -> Array:
	var result := []
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		if int(_district_city(city_index, player_index).get("owner", -1)) == player_index:
			result.append(city_index)
	return result
func _competing_city_indices_for_product(player_index: int, product_name: String) -> Array:
	var result := []
	if product_name == "":
		return result
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index, player_index)
		if int(city.get("owner", -1)) == player_index:
			continue
		if _city_product_names(city).has(product_name):
			result.append(city_index)
	return result
func _rival_business_candidates_for_player(player_index: int) -> Array:
	var result := []
	if player_index < 0 or player_index >= _player_count() or not _player_is_ai(player_index):
		return result
	if _spendable_cash_units(player_index) < RIVAL_BUSINESS_ACTION_COST:
		return result
	if _ai_market_public_query_port == null or not _ai_market_public_query_port.is_ready():
		return result
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
		var own_city := _district_city(own_city_index, player_index)
		for product_name_variant in _city_product_names(own_city):
			var product_name := String(product_name_variant)
			var entry := _market_public_product(product_name)
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
				var target_city := _district_city(target_city_index, player_index)
				var route_score := 42 + int(round(float(price) / 5.0))
				route_score += int(target_city.get("trade_route_count", 0)) * 4
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


func _execute_rival_business_action_transaction(
	player_index: int,
	action: Dictionary,
	attempt_ordinal: int
) -> bool:
	if _ai_business_cost_cash_port == null or _ai_business_cost_capability == null \
		or _product_market_runtime_controller == null:
		return false
	var action_kind := str(action.get("kind", "")).strip_edges()
	# Route sabotage remains a scored candidate for parity, but no production
	# owner currently has a reversible route-sabotage lifecycle. It therefore
	# stays fail-closed exactly as the retired Main dispatch did.
	if action_kind != "price_pump":
		return false
	var product_id := str(action.get("product", "")).strip_edges()
	var own_city_index := int(action.get("own_city", -1))
	var public_region_id := _ai_business_public_region_id(own_city_index)
	if product_id.is_empty() or public_region_id.is_empty():
		return false
	var context := _ai_business_cost_cash_port.private_request_context(
		_ai_business_cost_capability,
		player_index
	)
	if not bool(context.get("authorized", false)):
		return false
	var request := AiBusinessCostDebitRequest.new()
	request.request_id = _ai_business_request_id(
		str(context.get("session_id", "")),
		int(context.get("business_cycle_revision", -1)),
		player_index,
		attempt_ordinal,
		action_kind,
		product_id,
		public_region_id
	)
	request.player_index = player_index
	request.business_action_id = action_kind
	request.product_id = product_id
	request.public_region_id = public_region_id
	request.business_cycle_revision = int(context.get("business_cycle_revision", -1))
	request.session_id = str(context.get("session_id", ""))
	request.session_revision = int(context.get("session_revision", -1))
	request.simulation_step_index = int(context.get("simulation_step_index", -1))
	request.cost_cents = int(context.get("cost_cents", 0))
	request.policy_fingerprint = str(_business_action_policy.get("policy_fingerprint", ""))
	request.expected_availability_fingerprint = str(context.get("expected_availability_fingerprint", ""))
	request.source = AiBusinessCostDebitRequest.SOURCE_AI_RUNTIME
	request.seal()
	if not bool(request.validation_report().get("valid", false)):
		return false
	# A cash-owner replay must be observed before touching ProductMarket. This
	# also protects retries after either bounded participant journal evicts its
	# terminal record.
	var cached := _ai_business_cost_cash_port.cached_receipt(
		_ai_business_cost_capability,
		request
	)
	if cached != null:
		return false
	var prepared := _product_market_runtime_controller.prepare_ai_business_market_pressure({
		"schema_version": 1,
		"transaction_id": request.request_id,
		"action_kind": action_kind,
		"product_id": product_id,
		"public_region_id": public_region_id,
		"source_revision": request.business_cycle_revision,
		"expected_market_fingerprint": str(context.get("market_fingerprint", "")),
	})
	if not bool(prepared.get("prepared", false)):
		return false
	if bool(prepared.get("finalized", false)):
		return false
	var market_commit := _product_market_runtime_controller.commit_ai_business_market_pressure(prepared)
	if not bool(market_commit.get("committed", false)):
		_product_market_runtime_controller.rollback_ai_business_market_pressure(prepared)
		return false
	var market_finalize_ready := _product_market_runtime_controller.seal_ai_business_market_pressure_finalization(market_commit)
	if not bool(market_finalize_ready.get("finalization_ready", false)):
		_product_market_runtime_controller.rollback_ai_business_market_pressure(market_commit)
		return false
	var cash_receipt := _ai_business_cost_cash_port.submit(
		_ai_business_cost_capability,
		request
	)
	if cash_receipt == null or not cash_receipt.accepted or not cash_receipt.applied \
			or cash_receipt.idempotent or not cash_receipt.changed:
		_product_market_runtime_controller.rollback_ai_business_market_pressure(market_finalize_ready)
		return false
	var market_final := _product_market_runtime_controller.finalize_ai_business_market_pressure(market_finalize_ready)
	if not bool(market_final.get("finalized", false)):
		if bool(market_final.get("committed", false)) \
				and str(market_final.get("reason_code", "")) == "ai_business_market_pressure_publication_pending":
			# Cash, market and RNG are already exact-once committed. The market
			# owner's presentation-only drain will retry the missing public target;
			# this action must still count toward the per-cycle cap.
			return true
		# seal_ai_business_market_pressure_finalization() closes every mutable
		# market/RNG precondition before cash commit. Reaching this branch is an
		# invariant violation rather than a recoverable gameplay rejection.
		push_error("AI business market finalization violated its sealed synchronous contract.")
		return false
	var public_receipt: Dictionary = market_final.get("public_receipt", {}) \
		if market_final.get("public_receipt", {}) is Dictionary else {}
	_publish_ai_business_market_pressure_callout(public_receipt, own_city_index)
	return true


func _ai_business_public_region_id(district_index: int) -> String:
	if district_index < 0 or district_index >= _district_count():
		return ""
	var district := _public_district(district_index)
	if bool(district.get("destroyed", false)) or not _city_is_active(_district_city(district_index)):
		return ""
	return str(district.get("region_id", "region.%03d" % district_index)).strip_edges()


func _ai_business_request_id(
	session_id: String,
	cycle_revision: int,
	player_index: int,
	attempt_ordinal: int,
	action_kind: String,
	product_id: String,
	public_region_id: String
) -> String:
	var session_token := session_id.sha256_text().left(12)
	var target_token := JSON.stringify([action_kind, product_id, public_region_id]).sha256_text().left(12)
	return "ai-business:%s:%d:%d:%d:%s:%s" % [
		session_token,
		cycle_revision,
		player_index,
		attempt_ordinal,
		action_kind,
		target_token,
	]


func _publish_ai_business_market_pressure_callout(public_receipt: Dictionary, district_index: int) -> void:
	if str(public_receipt.get("visibility_scope", "")) != "public" \
		or str(public_receipt.get("event_kind", "")) != "ai_business_market_pressure_resolved":
		return
	var product_id := str(public_receipt.get("product_id", ""))
	var pressure_units := maxi(0, int(public_receipt.get("pressure_units", 0)))
	if product_id.is_empty() or pressure_units <= 0:
		return
	_add_action_callout(
		"匿名商业",
		"需求造势",
		"%s需求压力+%d，价格由供需重算；可能暴露生产方利益。" % [product_id, pressure_units],
		Color("#f59e0b"),
		_district_center(district_index)
	)


func _auto_rival_business_actions(force: bool = false) -> int:
	if session_finished or _player_count() <= 1:
		return 0
	var acted := 0
	var attempt_ordinal := 0
	var limit: int = _player_count() - 1 if force else int(RIVAL_BUSINESS_ACTION_MAX_PER_CYCLE)
	for player_index_variant in _rival_build_player_order():
		attempt_ordinal += 1
		if acted >= limit:
			break
		var player_index := int(player_index_variant)
		if _spendable_cash_units(player_index) < RIVAL_BUSINESS_ACTION_COST:
			continue
		if not force and rng.randi_range(1, 100) > RIVAL_BUSINESS_ACTION_CHANCE_PERCENT:
			continue
		var action := _pick_rival_business_action(player_index)
		if action.is_empty():
			continue
		if _execute_rival_business_action_transaction(player_index, action, attempt_ordinal):
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
		_request_table_presentation_refresh()
	return acted


func _spendable_cash_units(player_index: int) -> int:
	return _actor_available_cash_units(player_index)
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
		var profile_variant: Variant = _ai_profile_for_player(player_index)
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
		var memory_variant: Variant = _ai_memory_for_player(player_index)
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
		ai_count += 1
		var player: Dictionary = (_ai_actor_economy_snapshot(player_index).get("economy_summary", {}) as Dictionary).duplicate(true)
		var profile := _ai_profile_for_player(player_index)
		var primary := _ai_profile_primary_development_route(profile)
		var primary_route := String(primary.get("route_id", ""))
		var memory_variant: Variant = _ai_memory_for_player(player_index)
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
		var profile := _ai_profile_for_player(player_index)
		var primary := _ai_profile_primary_development_route(profile)
		var primary_route := String(primary.get("route_id", ""))
		var samples := []
		var memory_variant: Variant = _ai_memory_for_player(player_index)
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
	if kind.contains("合约") or policy_kind.contains("contract"):
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
		ai_count += 1
		var profile := _ai_profile_for_player(player_index)
		var memory_variant: Variant = _ai_memory_for_player(player_index)
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
			"focus_product": String((memory_variant as Dictionary).get("economic_focus_product", "")),
			"route_plan_product": String((memory_variant as Dictionary).get("route_plan_product", "")),
			"route_plan_stage": String((memory_variant as Dictionary).get("route_plan_stage", "")),
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
		ai_count += 1
		var profile_variant: Variant = _ai_profile_for_player(player_index)
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
		var memory_variant: Variant = _ai_memory_for_player(player_index)
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
	return _ai_actor_state_port.ai_player_indices(true).size() if _actor_state_ready() else 0
func _ai_player_indices() -> Array:
	return _typed_ai_player_indices()
func _ai_profile_for_config_index(player_index: int) -> Dictionary:
	if AI_PERSONALITY_CATALOG.is_empty():
		return {}
	var human_count := 0
	for player_variant in (_ai_actor_state_port.public_players_snapshot() if _actor_state_ready() else []):
		if not (player_variant is Dictionary):
			continue
		var player := player_variant as Dictionary
		if not (bool(player.get("is_ai", false)) or str(player.get("seat_type", "human")) == "ai"):
			human_count += 1
	human_count = maxi(1, human_count)
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
func _normalized_ai_memory(source: Variant) -> Dictionary:
	var memory := (source as Dictionary).duplicate(true) if source is Dictionary else _empty_ai_memory()
	var defaults := _empty_ai_memory()
	for key_variant in defaults.keys():
		var key := String(key_variant)
		var default_value: Variant = defaults[key]
		if not memory.has(key):
			memory[key] = TablePresentationPureDataPolicy.detached_copy(default_value)
			continue
		var value: Variant = memory[key]
		if default_value is Array and not (value is Array):
			memory[key] = (default_value as Array).duplicate(true)
		elif default_value is Dictionary and not (value is Dictionary):
			memory[key] = (default_value as Dictionary).duplicate(true)
		elif default_value is String and String(value) == "":
			memory[key] = default_value
	return memory
func _ensure_player_ai_state() -> void:
	if not _actor_state_ready():
		return
	for player_variant in _ai_actor_state_port.public_players_snapshot():
		if not (player_variant is Dictionary):
			continue
		var player := player_variant as Dictionary
		if not (bool(player.get("is_ai", false)) or str(player.get("seat_type", "human")) == "ai"):
			continue
		var player_index := int(player.get("player_index", -1))
		var actor := _ai_actor_state_snapshot(player_index)
		if actor.is_empty():
			continue
		var profile: Dictionary = actor.get("ai_profile", {}) \
			if actor.get("ai_profile", {}) is Dictionary else {}
		if profile.is_empty():
			profile = _ai_profile_for_config_index(player_index)
		var memory := _normalized_ai_memory(actor.get("ai_memory", {}))
		_commit_ai_actor_state(player_index, profile, memory, actor)
func _ai_owned_active_monster_count(player_index: int) -> int:
	if _ai_monster_actor_query_port == null or not _ai_monster_actor_capability_binding_initialized:
		return 0
	return _ai_monster_actor_query_port.own_active_monster_count(
		_ai_monster_actor_capabilities.get(player_index) as AiMonsterActorCapability,
		player_index
	)
func _ai_score_gap_to_leader(player_index: int) -> int:
	if not _victory_snapshot_available():
		return 0
	var leader := _visible_score_leader_entry(player_index)
	if int(leader.get("player_index", -1)) < 0:
		return 0
	return _victory_top_n_gdp(player_index) - int(leader.get("score", 0))
func _ai_game_phase(player_index: int) -> String:
	var score := _victory_top_n_gdp(player_index)
	var gdp_goal := _victory_required_gdp()
	if victory_control_active \
			or (_victory_snapshot_available() and gdp_goal > 0 \
				and score >= int(round(float(gdp_goal) * AI_ENDGAME_GOAL_RATIO))) \
			or business_cycle_count >= AI_ENDGAME_CYCLE:
		return "endgame"
	if business_cycle_count <= AI_OPENING_CYCLE_MAX or _ai_owned_active_monster_count(player_index) <= 0 or _player_active_city_count(player_index) <= 0:
		return "opening"
	return "midgame"
func _ai_competitive_posture(player_index: int) -> String:
	if not _victory_snapshot_available():
		return "contesting"
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
	if player_index < 0 or player_index >= _player_count() or not _victory_snapshot_available():
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
	if not _player_is_ai(player_index):
		return {
			"phase": "human",
			"posture": "human",
			"gap": 0,
			"leader_index": -1,
			"reason": "真人玩家",
		}
	var actor := _ai_actor_state_snapshot(player_index)
	if actor.is_empty():
		return {}
	var memory := _normalized_ai_memory(actor.get("ai_memory", {}))
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
	var commit := _commit_ai_memory(player_index, memory, actor)
	if not bool(commit.get("accepted", false)):
		return {}
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
func _ai_best_city_for_owner(viewer_index: int, owner_index: int, prefer_damaged: bool = false) -> int:
	var best_index := -1
	var best_score := -999999
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index, viewer_index)
		if int(city.get("owner", -1)) != owner_index:
			continue
		var score := int(city.get("last_income", 0)) + _city_cycle_income(city_index, _city_competition_matches(city_index))
		score += (city.get("products", []) as Array).size() * 28
		score += (city.get("demands", []) as Array).size() * 18
		score -= int(city.get("trade_route_damage", 0)) * 22
		score -= int(_public_district(city_index).get("damage", 0)) * 14
		score += _city_warehouse_stockpile_pressure(city) * 2
		if prefer_damaged:
			score += int(city.get("trade_route_damage", 0)) * 74 + int(_public_district(city_index).get("damage", 0)) * 36
		if score > best_score:
			best_score = score
			best_index = city_index
	return best_index
func _ai_best_pressure_target_city(player_index: int) -> int:
	var leader := _visible_score_leader_entry(player_index)
	var leader_index := int(leader.get("player_index", -1))
	if leader_index >= 0 and leader_index != player_index:
		var leader_city := _ai_best_city_for_owner(player_index, leader_index, _ai_competitive_posture(player_index) == "trailing")
		if leader_city >= 0:
			return leader_city
	return _ai_best_city_district(player_index, false)
func _ai_direct_interaction_target_player(player_index: int) -> int:
	var plan := _ai_direct_player_interaction_plan(player_index, {})
	return int(plan.get("target_player", -1))
func _ai_direct_player_interaction_plan(player_index: int, skill: Dictionary) -> Dictionary:
	if player_index < 0 or player_index >= _player_count() or _player_count() <= 1:
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
		var own_hand := _ai_card_hand_snapshot(player_index)
		if int(own_hand.get("counted_hand_size", PLAYER_HAND_LIMIT)) < int(own_hand.get("hand_limit", PLAYER_HAND_LIMIT)):
			receive_pressure += 46
		else:
			receive_pressure += int(float(maxi(0, int(skill.get("steal_fail_cash", 0)))) / 3.0) - 32
	var best := {}
	var best_score := -999999
	for i in range(_player_count()):
		if i == player_index:
			continue
		var settlement := _victory_top_n_gdp(player_index, i)
		var settlement_gap := settlement - self_estimate
		var city_pressure := _visible_active_city_count_for_actor(player_index, i) * 74
		var monster_pressure := _visible_active_monster_count_for_actor(player_index, i) * 42
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
			+ leader_bonus \
			+ posture_bonus \
			+ hand_effect_pressure \
			+ receive_pressure
		score += (i * 13 + player_index * 7 + business_cycle_count) % 17
		var role := "pressure_high_value_player"
		if i == leader_index:
			role = "pressure_leader_hand"
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
				"direct_effect_pressure": hand_effect_pressure,
				"score": score,
				"reason": "直接互动%s｜%s｜估值差%d｜效果压强%d" % [
					_interaction_target_label(i),
					role,
					settlement_gap,
					hand_effect_pressure,
				],
			}
	return best
func _ai_direct_city_target_score(player_index: int, district_index: int, skill: Dictionary) -> int:
	if district_index < 0 or district_index >= _district_count():
		return -999999
	var city := _district_city(district_index, player_index)
	if not _city_is_active(city):
		return -999999
	var city_owner := int(city.get("owner", -1))
	if city_owner == player_index:
		return -999999
	var kind := String(skill.get("kind", "city_control_dispute"))
	var phase_info := _ai_refresh_game_phase(player_index)
	var leader_index := int(phase_info.get("leader_index", -1))
	var income := int(city.get("last_income", _city_cycle_income(district_index, _city_competition_matches(district_index))))
	var route_load := int(city.get("trade_route_count", 0))
	var warehouse_pressure := _city_warehouse_stockpile_pressure(city)
	var route_damage := int(city.get("trade_route_damage", 0)) + int(city.get("trade_disrupted_routes", 0))
	var district_damage := int(_public_district(district_index).get("damage", 0))
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
	if player_index < 0 or player_index >= _player_count():
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
	var city := _district_city(best_city, player_index)
	var city_owner := int(city.get("owner", -1))
	var warehouse_pressure := _city_warehouse_stockpile_pressure(city)
	var route_damage := int(city.get("trade_route_damage", 0)) + int(city.get("trade_disrupted_routes", 0))
	var district_damage := int(_public_district(best_city).get("damage", 0))
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
			String(_public_district(best_city).get("name", "城市")),
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
	if player_index < 0 or player_index >= _player_count() or not _player_is_ai(player_index):
		return result
	if not _victory_snapshot_available():
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
	if resolved_owner == -999 and district_index >= 0 and district_index < _district_count():
		var city := _district_city(district_index, player_index)
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
	var economy := _ai_actor_economy_snapshot(player_index)
	var hand := _ai_card_hand_snapshot(player_index)
	if economy.is_empty() or hand.is_empty():
		return {}
	var focus_product := _ai_focus_product(player_index)
	var phase_info := _ai_refresh_game_phase(player_index)
	var memory := _ai_memory_for_player(player_index)
	var total_flow := 0
	for product_variant in PRODUCT_CATALOG:
		total_flow += _player_product_flow(player_index, String(product_variant))
	return {
		"cash": int((economy.get("cash", {}) as Dictionary).get("total_units", 0)),
		"victory_top_n_gdp_per_minute": _victory_top_n_gdp(player_index),
		"victory_controlled_region_count": _victory_controlled_regions(player_index),
		"counted_hand": int(hand.get("counted_hand_size", 0)),
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
		"queue_current": int(_card_queue_public_snapshot().get("current_count", 0)),
		"queue_next": int(_card_queue_public_snapshot().get("next_count", 0)),
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
func _ai_intel_policy_candidates_for_audit(player_index: int) -> Array:
	var result := []
	if not _player_is_ai(player_index):
		return result
	result.append_array(_ai_city_guess_candidates(player_index))
	return result
func _ai_monster_wager_policy_candidates_for_audit(player_index: int) -> Array:
	var result := []
	if not _player_is_ai(player_index):
		return result
	for wager_id_variant: Variant in _active_monster_wager_ids():
		var wager := _monster_wager_decision_snapshot_for_actor(int(wager_id_variant), player_index)
		if wager.is_empty():
			continue
		var plan := _ai_monster_wager_plan(player_index, wager)
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
	var audit_roster := _monster_public_roster()
	for actor_index in range(audit_roster.size()):
		var actor: Dictionary = audit_roster[actor_index]
		if bool(actor.get("down", false)):
			continue
		var district_reports := []
		var positive_alive_count := 0
		for district_index in range(_district_count()):
			var parts := _auto_monster_target_weight_parts(actor, district_index)
			var weight := _auto_monster_target_weight(actor, district_index)
			var destroyed := bool(_public_district(district_index).get("destroyed", false))
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
	if tag == "" or not _player_is_ai(player_index):
		return 0
	var memory := _ai_memory_for_player(player_index)
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
	var actor_state := _ai_actor_state_snapshot(player_index)
	if actor_state.is_empty():
		return
	var memory := _normalized_ai_memory(actor_state.get("ai_memory", {}))
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
		"baseline_cash": _actor_cash_units(player_index),
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
	var commit := _commit_ai_memory(player_index, memory, actor_state)
	if not bool(commit.get("accepted", false)):
		return
func _finalize_ai_decision_rewards() -> int:
	var finalized := 0
	for player_index_variant in _ai_player_indices():
		var player_index := int(player_index_variant)
		var actor_state := _ai_actor_state_snapshot(player_index)
		if actor_state.is_empty():
			continue
		var memory := _normalized_ai_memory(actor_state.get("ai_memory", {}))
		var samples := (memory.get("decision_samples", []) as Array).duplicate(true)
		var changed := false
		var player_finalized := 0
		for i in range(samples.size()):
			if not (samples[i] is Dictionary):
				continue
			var sample: Dictionary = samples[i]
			if bool(sample.get("reward_finalized", false)) or int(sample.get("cycle", business_cycle_count)) >= business_cycle_count:
				continue
			var current_cash := _actor_cash_units(player_index)
			sample["reward_cash"] = current_cash - int(sample.get("baseline_cash", current_cash))
			sample["reward_victory_gdp"] = _victory_top_n_gdp(player_index) - int(sample.get("baseline_victory_gdp", 0))
			sample["reward_victory_regions"] = _victory_controlled_regions(player_index) - int(sample.get("baseline_victory_regions", 0))
			sample["reward_score"] = _ai_learning_reward_for_sample(sample)
			sample["reward_finalized"] = true
			sample["reward_cycle"] = business_cycle_count
			memory = _ai_apply_learning_sample(player_index, memory, sample)
			sample["learning_tags"] = _ai_learning_tags_for_sample(sample)
			sample["learning_applied"] = true
			samples[i] = sample
			player_finalized += 1
			changed = true
		if changed:
			memory["decision_samples"] = samples
			var commit := _commit_ai_memory(player_index, memory, actor_state)
			finalized += _committed_change_count(commit, player_finalized)
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
	var seat_span := maxi(1, _player_count() - 1)
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
	if _ai_player_count() <= 0 or receipt.is_empty() or not (receipt.get("rankings", []) is Array) or not (receipt.get("winner_player_indices", []) is Array):
		return 0
	var rankings := (receipt.get("rankings", []) as Array).duplicate(true)
	var winner_indices := (receipt.get("winner_player_indices", []) as Array).duplicate()
	var reason := str(receipt.get("reason_code", "victory_resolved"))
	var updated := 0
	for player_index_variant in _ai_player_indices():
		var player_index := int(player_index_variant)
		var actor_state := _ai_actor_state_snapshot(player_index)
		if actor_state.is_empty():
			continue
		var memory := _normalized_ai_memory(actor_state.get("ai_memory", {}))
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
		var commit := _commit_ai_memory(player_index, memory, actor_state)
		updated += _committed_change_count(commit, sample_updates)
	return updated
func _ai_profile_for_player(player_index: int) -> Dictionary:
	var actor := _ai_actor_state_snapshot(player_index)
	var profile_variant: Variant = actor.get("ai_profile", {})
	return (profile_variant as Dictionary).duplicate(true) if profile_variant is Dictionary else {}
func _ai_memory_for_player(player_index: int) -> Dictionary:
	var actor := _ai_actor_state_snapshot(player_index)
	var memory_variant: Variant = actor.get("ai_memory", {})
	return (memory_variant as Dictionary).duplicate(true) if memory_variant is Dictionary else _empty_ai_memory()
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
		var city := _district_city(city_index, player_index)
		if int(city.get("owner", -1)) == player_index:
			continue
		if _city_product_names(city).has(product_name) or _city_demand_names(city).has(product_name):
			count += 1
	return count
func _ai_product_market_signal_score(product_name: String) -> int:
	if product_name == "":
		return 0
	var entry := _market_public_product(product_name)
	if entry.is_empty():
		return 0
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
		var city := _district_city(city_index, player_index)
		var city_owner := int(city.get("owner", -1))
		var product_match := _city_product_names(city).has(product_name)
		var demand_match := _city_demand_names(city).has(product_name)
		if city_owner == player_index:
			if product_match:
				score += 72 + int(float(int(city.get("last_income", 0))) / 4.0)
			if demand_match:
				score += 46
			if (city.get("active_trade_route_products", []) as Array).has(product_name):
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
	if not _player_is_ai(player_index):
		return ""
	var actor_state := _ai_actor_state_snapshot(player_index)
	if actor_state.is_empty():
		return ""
	var memory := _normalized_ai_memory(actor_state.get("ai_memory", {}))
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
	var commit := _commit_ai_memory(player_index, memory, actor_state)
	if not bool(commit.get("accepted", false)):
		return str(_ai_memory_for_player(player_index).get("economic_focus_product", ""))
	return best_product
func _ai_focus_product(player_index: int) -> String:
	if player_index < 0 or player_index >= _player_count():
		return ""
	if not _player_is_ai(player_index):
		return _first_player_flow_product(player_index)
	return _ai_refresh_economic_focus(player_index)
func _ai_focus_score(player_index: int) -> int:
	if not _player_is_ai(player_index):
		return 0
	_ai_refresh_economic_focus(player_index)
	var memory := _ai_memory_for_player(player_index)
	return int(memory.get("economic_focus_score", 0))
func _ai_own_route_threat_score(player_index: int) -> int:
	var score := 0
	for city_index_variant in _active_city_indices_for_player(player_index):
		var city_index := int(city_index_variant)
		var city := _district_city(city_index, player_index)
		score += int(city.get("trade_route_damage", 0)) * 84
		score += int(city.get("trade_disrupted_routes", 0)) * 46
		score += int(_public_district(city_index).get("damage", 0)) * 18
		score += int(float(int(_public_district(city_index).get("panic", 0))) / 3.0)
		score += _city_warehouse_stockpile_pressure(city)
		for actor_variant in _monster_public_roster():
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
			score += _monster_resource_match_score(actor, city_index, player_index) * 18
	return score
func _ai_focus_rival_pressure_score(player_index: int) -> int:
	var focus := _ai_focus_product(player_index)
	if focus == "":
		return 0
	var score := 0
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index, player_index)
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
	if not _player_is_ai(player_index):
		return {}
	_ai_refresh_economic_focus(player_index, force)
	var cached_actor_state := _ai_actor_state_snapshot(player_index)
	if cached_actor_state.is_empty():
		return {}
	var memory := _normalized_ai_memory(cached_actor_state.get("ai_memory", {}))
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
	# Candidate construction may refresh game phase, which commits the same actor
	# memory. Re-read before writing the strategy fields so CAS cannot discard the
	# first strategy refresh as stale.
	var actor_state := _ai_actor_state_snapshot(player_index)
	if actor_state.is_empty():
		return {}
	memory = _normalized_ai_memory(actor_state.get("ai_memory", {}))
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
	var commit := _commit_ai_memory(player_index, memory, actor_state)
	if not bool(commit.get("accepted", false)):
		var stored_memory := _ai_memory_for_player(player_index)
		var latest_intent := str(stored_memory.get("strategic_intent", ""))
		return {} if latest_intent.is_empty() else {
			"intent": latest_intent,
			"score": int(stored_memory.get("strategic_intent_score", 0)),
			"reason": str(stored_memory.get("strategic_intent_reason", "")),
		}
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
	if resolved_owner == -999 and district_index >= 0 and district_index < _district_count():
		var city := _district_city(district_index, player_index)
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
			if ["city_build", "city_revenue_boost", "city_product_upgrade", "city_product_shift", "city_demand_shift", "city_contract_boon", "route_flow_boon", "product_speculation", "city_gdp_derivative", "product_contract_boon", "product_growth_boon", "cash_gain", "region_economy_shift", "news_event", "weather_control"].has(kind):
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
		"product_contract_boon":
			return "contract_route"
		"product_speculation", "product_futures", "city_gdp_derivative", "market_stabilize", "product_growth_boon", "cash_gain":
			return "finance_speculation"
		"monster_card", "monster_bound_action", "monster_lure", "monster_takeover", "mudslide", "special_monster_delay", "news_event", "weather_control", "route_sabotage", "panic_shift":
			return "monster_pressure"
		"intel_city_reveal", "card_history_public_review", "card_history_subscription", "supply_draw":
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
	for field_name in ["weather_type", "direct_interaction_role", "futures_direction", "strategic_role"]:
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
	if player_index < 0 or player_index >= _player_count() or not _player_is_ai(player_index) or kind == "":
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
	if resolved_owner == -999 and district_index >= 0 and district_index < _district_count():
		var city := _district_city(district_index, player_index)
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
		var city := _district_city(int(city_index_variant), player_index)
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
	if product_name == "" or district_index < 0 or district_index >= _district_count():
		return false
	var district := _public_district(district_index)
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
		var city := _district_city(city_index, player_index)
		var related := _ai_city_touches_product(city, product_name)
		var active_route_products: Array = city.get("active_trade_route_products", [])
		var disrupted_route_products: Array = city.get("disrupted_trade_route_products", [])
		if active_route_products.has(product_name) or disrupted_route_products.has(product_name):
			related = true
			if disrupted_route_products.has(product_name):
				score += 58
		if not related:
			continue
		score += int(city.get("trade_route_damage", 0)) * 92
		score += int(city.get("trade_disrupted_routes", 0)) * 54
		score += int(_public_district(city_index).get("damage", 0)) * 18
		score += int(float(int(_public_district(city_index).get("panic", 0))) / 4.0)
	return score
func _ai_best_owned_route_city_for_product(player_index: int, product_name: String, prefer_damaged: bool = false) -> int:
	var best_index := -1
	var best_score := -1
	for city_index_variant in _active_city_indices_for_player(player_index):
		var city_index := int(city_index_variant)
		var city := _district_city(city_index, player_index)
		var score := 20 + _ai_city_target_score(player_index, city_index, true, prefer_damaged)
		if _city_product_names(city).has(product_name):
			score += 120
		if _city_demand_names(city).has(product_name):
			score += 82
		var active_route_products: Array = city.get("active_trade_route_products", [])
		var disrupted_route_products: Array = city.get("disrupted_trade_route_products", [])
		if active_route_products.has(product_name) or disrupted_route_products.has(product_name):
			score += 48
			if disrupted_route_products.has(product_name):
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
		var city := _district_city(city_index, player_index)
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
	if player_index < 0 or player_index >= _player_count() or not _player_is_ai(player_index):
		return result
	if _ai_market_public_query_port == null or not _ai_market_public_query_port.is_ready():
		return result
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
	if not _player_is_ai(player_index):
		return {}
	_ai_refresh_economic_focus(player_index, force)
	var cached_actor_state := _ai_actor_state_snapshot(player_index)
	if cached_actor_state.is_empty():
		return {}
	var memory := _normalized_ai_memory(cached_actor_state.get("ai_memory", {}))
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
	# Route candidates may commit strategy and phase updates. Preserve those
	# fields by refreshing the actor snapshot before the route-plan CAS write.
	var actor_state := _ai_actor_state_snapshot(player_index)
	if actor_state.is_empty():
		return {}
	var latest_memory := _normalized_ai_memory(actor_state.get("ai_memory", {}))
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
	memory = latest_memory
	memory["route_plan_product"] = String(best.get("product", ""))
	memory["route_plan_stage"] = String(best.get("stage", ""))
	memory["route_plan_score"] = int(best.get("score", 0))
	memory["route_plan_reason"] = String(best.get("reason", ""))
	memory["route_plan_cycle"] = business_cycle_count
	memory["route_plan_target_city"] = int(best.get("target_city", -1))
	memory["route_plan_partner_district"] = int(best.get("partner_district", -1))
	memory["route_plan_rankings"] = compact_rankings
	var commit := _commit_ai_memory(player_index, memory, actor_state)
	if not bool(commit.get("accepted", false)):
		var stored_memory := _ai_memory_for_player(player_index)
		var latest_product := str(stored_memory.get("route_plan_product", ""))
		var latest_stage := str(stored_memory.get("route_plan_stage", ""))
		return {} if latest_product.is_empty() or latest_stage.is_empty() else {
			"product": latest_product,
			"stage": latest_stage,
			"score": int(stored_memory.get("route_plan_score", 0)),
			"reason": str(stored_memory.get("route_plan_reason", "")),
			"target_city": int(stored_memory.get("route_plan_target_city", -1)),
			"partner_district": int(stored_memory.get("route_plan_partner_district", -1)),
		}
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
	if resolved_owner == -999 and district_index >= 0 and district_index < _district_count():
		var city := _district_city(district_index, player_index)
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
			elif ["city_product_shift", "product_contract_boon", "region_economy_shift"].has(kind) and product_match:
				bonus += 72
		"create_demand":
			if ["city_demand_shift", "product_contract_boon", "route_flow_boon", "city_contract_boon"].has(kind) and product_match:
				bonus += 118
			if resolved_owner == player_index:
				bonus += 42
		"strengthen_route":
			if ["route_flow_boon", "city_revenue_boost", "city_product_upgrade", "city_contract_boon", "product_speculation", "city_gdp_derivative", "product_contract_boon", "product_growth_boon", "news_event", "weather_control"].has(kind) and product_match:
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
	var scope := _skill_play_region_scope(evaluated_skill, player_index)
	var has_locked_requirement_district := evaluated_skill.has("play_requirement_district")
	var requirement_district := int(evaluated_skill.get("play_requirement_district", planned_district))
	if not has_locked_requirement_district:
		if scope == CardPlayRequirementPolicyScript.SCOPE_OWN_BEST_REGION:
			requirement_district = _best_player_gdp_share_district(player_index)
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
	var hand := _ai_card_hand_snapshot(player_index)
	if hand.is_empty() or route_id == "":
		return result
	var slots_variant: Variant = hand.get("slots", [])
	if not (slots_variant is Array):
		return result
	var cash := _actor_available_cash_units(player_index)
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
		var cash_cost := _skill_play_cash_cost(skill, player_index)
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
	if resolved_owner == -999 and district_index >= 0 and district_index < _district_count():
		var city := _district_city(district_index, player_index)
		if _city_is_active(city):
			resolved_owner = int(city.get("owner", -1))
	var product_match := product_name == plan_product
	if not product_match and district_index >= 0:
		product_match = _ai_district_touches_product(district_index, plan_product)
	var field_match := 1 if product_match else 0
	var production_delta := int(skill.get("production_delta", 0))
	var transport_delta := int(skill.get("transport_delta", 0))
	var consumption_delta := int(skill.get("consumption_delta", 0))
	var supply_boost := maxi(0, production_delta) + int(skill.get("product_shift", 0))
	var demand_boost := maxi(0, consumption_delta) + int(skill.get("demand_shift", 0)) + int(ceil(float(maxi(0, int(skill.get("market_demand_pressure", 0)))) / 2.0))
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
	pressure_strength += int(skill.get("route_damage", 0)) + int(skill.get("damage", 0))
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
	if focus == "" or district_index < 0 or district_index >= _district_count():
		return 0
	var score := 0
	if (_public_district(district_index).get("products", []) as Array).has(focus):
		score += AI_ECONOMIC_FOCUS_MATCH_BONUS + int(round(float(_product_price(focus)) / 4.0))
	if (_public_district(district_index).get("demands", []) as Array).has(focus):
		score += 48
	var city := _district_city(district_index, player_index)
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
	if route_product != "" and (_player_product_flow(player_index, route_product) > 0 or ["product_speculation", "product_futures", "product_contract_boon", "product_growth_boon", "market_stabilize", "city_product_shift", "city_demand_shift", "region_economy_shift", "news_event", "weather_control"].has(kind)):
		return route_product
	if focus != "" and (_player_product_flow(player_index, focus) > 0 or ["product_speculation", "product_futures", "product_contract_boon", "product_growth_boon", "market_stabilize", "city_product_shift", "city_demand_shift", "region_economy_shift", "news_event", "weather_control"].has(kind)):
		return focus
	return _skill_play_product(skill, player_index)
func _ai_first_alive_district() -> int:
	for i in range(_district_count()):
		if not bool(_public_district(i).get("destroyed", false)):
			return i
	return -1
func _ai_city_target_score(player_index: int, district_index: int, own_city: bool, prefer_damaged: bool = false) -> int:
	var city := _district_city(district_index, player_index)
	if not _city_is_active(city):
		return -1
	var is_owned := int(city.get("owner", -1)) == player_index
	if is_owned != own_city:
		return -1
	var score := 30
	score += int(city.get("last_income", 0))
	score += (city.get("products", []) as Array).size() * 28
	score += (city.get("demands", []) as Array).size() * 18
	score += int(city.get("trade_route_count", 0)) * 10
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
		score += int(_public_district(district_index).get("damage", 0)) * 20
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
		var city := _district_city(district_index, player_index)
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
	var district := _public_district(district_index)
	var catalog_index := int(skill.get("catalog_index", 0))
	var template := _catalog_entry(catalog_index)
	var probe := {"resource_focus": (template.get("resource_focus", []) as Array).duplicate(true)}
	score += _monster_resource_match_score(probe, district_index, player_index) * 28
	for product_variant in district.get("products", []):
		score += int(round(float(_product_price(String(product_variant))) / 8.0))
	score += int(round(float(district.get("transport_score", 1.0)) * 15.0))
	score += _district_supply_card_ids(district_index).size() * 7
	var city := _district_city(district_index, player_index)
	if _city_is_active(city):
		if int(city.get("owner", -1)) == player_index:
			score -= 120
		else:
			score += 130 + int(city.get("last_income", 0))
	score -= int(district.get("damage", 0)) * 8
	return score
func _ai_best_monster_card_district(player_index: int, skill: Dictionary) -> int:
	var monster_name := String(skill.get("monster_name", ""))
	for actor_variant in _monster_actor_roster(player_index):
		var actor := actor_variant as Dictionary
		if not bool(actor.get("down", false)) \
				and str(actor.get("ownership_scope", "")) == "actor_own" \
				and String(actor.get("name", "")) == monster_name \
				and int(actor.get("rank", 1)) < 4:
			return int(actor.get("position", _ai_first_alive_district()))
	var best_index := -1
	var best_score := -1
	for i in range(_district_count()):
		var score := _ai_monster_card_landing_score(player_index, skill, i)
		if score > best_score:
			best_score = score
			best_index = i
	return best_index

func _ai_monster_actor_for_skill(player_index: int, skill: Dictionary) -> Dictionary:
	var roster := _monster_actor_roster(player_index)
	var bound_uid := int(skill.get("bound_monster_uid", 0))
	if bound_uid > 0:
		for actor_variant in roster:
			var bound_actor := actor_variant as Dictionary
			if int(bound_actor.get("uid", -1)) == bound_uid \
					and not bool(bound_actor.get("down", false)) \
					and str(bound_actor.get("ownership_scope", "")) == "actor_own":
				return bound_actor.duplicate(true)
		return {}
	var kind := String(skill.get("kind", ""))
	var prefer_foreign := ["monster_lure", "special_monster_delay", "mudslide", "monster_takeover"].has(kind)
	var best_actor := {}
	var best_score := -1
	for actor_variant in roster:
		var actor := actor_variant as Dictionary
		if bool(actor.get("down", false)):
			continue
		var is_owned := str(actor.get("ownership_scope", "")) == "actor_own"
		if prefer_foreign and is_owned:
			continue
		if not prefer_foreign and not is_owned:
			continue
		var score := int(actor.get("rank", 1)) * 45 \
			+ int(actor.get("hp", 0)) \
			+ int(actor.get("armor", 0)) * 8
		if score > best_score:
			best_score = score
			best_actor = actor.duplicate(true)
	return best_actor


func _ai_best_district_near_monster(player_index: int, actor: Dictionary, range_limit: float = -1.0) -> int:
	if actor.is_empty():
		return _ai_best_city_district(player_index, false)
	var best_index := -1
	var best_score := -1
	for i in range(_district_count()):
		if bool(_public_district(i).get("destroyed", false)):
			continue
		if range_limit > 0.0 and _entity_distance_to_district(actor, i) > range_limit:
			continue
		var score := _district_event_weight(i, player_index)
		var city := _district_city(i, player_index)
		if _city_is_active(city):
			score += 100 if int(city.get("owner", -1)) != player_index else -120
		if score > best_score:
			best_score = score
			best_index = i
	if best_index >= 0:
		return best_index
	return int(actor.get("position", _ai_first_alive_district()))

func _ai_city_product_overlap_score(player_index: int, target_city_index: int) -> int:
	var target_city := _district_city(target_city_index, player_index)
	if not _city_is_active(target_city):
		return 0
	var target_products := _city_product_names(target_city)
	var target_demands := _city_demand_names(target_city)
	var score := 0
	for own_city_index_variant in _active_city_indices_for_player(player_index):
		var own_city := _district_city(int(own_city_index_variant), player_index)
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
	if district_index < 0 or district_index >= _district_count() or bool(_public_district(district_index).get("destroyed", false)):
		return -1
	var city := _district_city(district_index, player_index)
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
	score += int(city.get("trade_route_count", 0)) * 20
	score += _route_network_load_for_legacy_region(district_index) * 14
	score += _city_product_names(city).size() * 24
	score += _city_demand_names(city).size() * 14
	score += _city_warehouse_stockpile_pressure(city) * 2
	score += competition * 18
	score -= int(city.get("trade_route_damage", 0)) * 12
	score -= int(_public_district(district_index).get("damage", 0)) * 5
	if city_owner < 0:
		score -= 25
	return maxi(1, score)
func _ai_monster_lure_plan(player_index: int, _skill: Dictionary, range_limit: float = -1.0) -> Dictionary:
	var best := {}
	var best_score := -1
	for actor_variant in _monster_actor_roster(player_index):
		var actor := actor_variant as Dictionary
		if bool(actor.get("down", false)):
			continue
		var slot := int(actor.get("slot", -1))
		var ownership_scope := str(actor.get("ownership_scope", "public_unknown"))
		for city_index_variant in _active_city_district_indices():
			var city_index := int(city_index_variant)
			var attack_value := _ai_rival_city_pressure_score(player_index, city_index)
			if attack_value <= 0:
				continue
			var distance := _entity_distance_to_district(actor, city_index)
			if range_limit > 0.0 and distance > range_limit:
				continue
			var resource_match := _monster_resource_match_score(actor, city_index, player_index)
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
			if ownership_scope == "actor_own":
				score -= 28
			elif ownership_scope == "public_revealed":
				score += 36
			else:
				score += 12
			if int(actor.get("position", -1)) == city_index:
				score += 34
			if score <= best_score:
				continue
			var city := _district_city(city_index, player_index)
			var target_products := _city_product_names(city)
			var product_name := String(target_products[0]) if not target_products.is_empty() else _ai_preferred_product(player_index, true)
			best_score = score
			best = {
				"target_slot": slot,
				"target_monster_uid": int(actor.get("uid", -1)),
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
					String(_public_district(city_index).get("name", "竞争城市")),
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
	for actor_variant in _monster_actor_roster(player_index):
		var actor := actor_variant as Dictionary
		if bool(actor.get("down", false)) \
				or str(actor.get("ownership_scope", "")) == "actor_own":
			continue
		var slot := int(actor.get("slot", -1))
		for city_index_variant in _active_city_indices_for_player(player_index):
			var city_index := int(city_index_variant)
			var city_score := _ai_city_target_score(player_index, city_index, true, false)
			if city_score <= 0:
				continue
			var distance := _entity_distance_to_district(actor, city_index)
			var resource_match := _monster_resource_match_score(actor, city_index, player_index)
			var score := 72 + city_score + resource_match * 42 \
				+ int(actor.get("rank", 1)) * 25 - int(round(distance / 28.0))
			if score <= best_score:
				continue
			best_score = score
			best = {
				"target_slot": slot,
				"target_monster_uid": int(actor.get("uid", -1)),
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
					String(_public_district(city_index).get("name", "城市")),
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
	if district_index >= 0 and district_index < _district_count() and _city_is_active(_district_city(district_index)):
		return district_index
	return -1
func _ai_counter_entry_target_owner(viewer_index: int, entry: Dictionary) -> int:
	var target_player := int(entry.get("target_player", -1))
	if target_player >= 0 and target_player < _player_count():
		return target_player
	var target_city := _ai_counter_entry_target_city(entry)
	if target_city >= 0:
		return int(_district_city(target_city, viewer_index).get("owner", -1))
	return -1
func _ai_counter_nearest_owned_city_pressure(player_index: int, district_index: int) -> int:
	if district_index < 0 or district_index >= _district_count():
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
	var skill: Dictionary = target_entry.get("card_facts", {}) as Dictionary
	if skill.is_empty() or bool(target_entry.get("is_counter", false)):
		return {"score": -999999, "reason_key": "not_counterable", "summary": "当前牌不可反制。"}
	if not bool(target_entry.get("counterable_player_interaction", false)):
		return {"score": -999999, "reason_key": "not_player_interaction", "summary": "相位否决只响应直接玩家互动牌。"}
	var own_queue := _ai_card_queue_snapshot(player_index)
	if bool(own_queue.get("has_active_submission", false)) \
			and int(own_queue.get("active_resolution_id", -1)) == int(target_entry.get("resolution_id", -1)):
		return {"score": -999999, "reason_key": "own_card", "summary": "AI不会反制自己已经提交的匿名牌。"}
	var kind := String(skill.get("kind", ""))
	var derivative_terms := _city_gdp_derivative_terms(skill) if kind == "city_gdp_derivative" else {}
	var district_index := int(target_entry.get("selected_district", -1))
	var target_player := int(target_entry.get("target_player", -1))
	var target_owner := _ai_counter_entry_target_owner(player_index, target_entry)
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
		var city := _district_city(district_index, player_index)
		var negative_delta := maxi(0, -int(skill.get("production_delta", 0))) \
			+ maxi(0, -int(skill.get("transport_delta", 0))) \
			+ maxi(0, -int(skill.get("consumption_delta", 0)))
		var route_damage := maxi(0, int(skill.get("route_damage", 0))) \
			+ maxi(0, int(skill.get("global_barrage_route_damage", 0))) \
			+ maxi(0, int(skill.get("military_strike_route_damage", 0)))
		var area_damage := maxi(0, int(skill.get("damage", 0))) + maxi(0, int(skill.get("global_barrage_damage", 0)))
		var city_pressure := negative_delta * 128 + route_damage * 132 + area_damage * 118
		city_pressure += maxi(0, int(skill.get("control_gdp_penalty", 0))) * 3
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
			+ maxi(0, int(skill.get("consumption_delta", 0)))
		var rival_boost := positive_delta * 78 \
			+ int(float(int(skill.get("revenue_amount", 0))) / 3.0) \
			+ int(float(int(skill.get("contract_income", 0))) / 4.0) \
			+ maxi(0, int(skill.get("repair_routes", 0))) * 64
		var flow_multiplier := float(skill.get("route_flow_multiplier", 1.0))
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
	if _ai_has_current_card_submission(player_index) or _ai_has_next_card_submission(player_index):
		return {}
	var entry := _card_resolution_active_entry() if target_entry.is_empty() else target_entry
	if not _card_can_open_counter_window(entry):
		return {}
	var counter_skill := _counter_skill_for_ai_candidate(player_index, source_skill)
	if counter_skill.is_empty():
		return {}
	if not _can_play_skill_now(player_index, counter_skill):
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
	if district_index < 0 or district_index >= _district_count():
		return 0
	var city := _district_city(district_index, player_index)
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
	var city := _district_city(district_index, player_index)
	if not _city_is_active(city):
		return {"score": 0, "owner": -1, "positive": 0, "negative": 0, "value": 0}
	var template := _weather_template(type_id)
	var production_multiplier := float(template.get("production_multiplier", 1.0))
	var transport_multiplier := float(template.get("route_efficiency_multiplier", template.get("transport_multiplier", 1.0)))
	if String(_public_district(district_index).get("terrain", "land")) == "ocean":
		transport_multiplier *= float(template.get("ocean_movement_multiplier", 1.0))
	var consumption_multiplier := float(template.get("demand_multiplier", 1.0))
	var route_load := _route_network_load_for_legacy_region(district_index)
	var product_weight := 110 + _city_product_names(city).size() * 34 + int(float(int(city.get("last_income", 0))) / 10.0)
	var transport_weight := 120 + route_load * 48 + (_route_network_routes_for_legacy_region(district_index) as Array).size() * 36 + int(round(float(_public_district(district_index).get("transport_score", 1.0)) * 28.0))
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
	if district_index < 0 or district_index >= _district_count():
		return 0
	var template := _weather_template(type_id)
	var terrain := String(_public_district(district_index).get("terrain", "land"))
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
	for product_variant in _public_district(district_index).get("products", []):
		var product_name := String(product_variant)
		if product_name != "" and (product_name == focus or product_name == route_product):
			score += 28
	for demand_variant in _public_district(district_index).get("demands", []):
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
			if String(_public_district(district_index).get("terrain", "land")) == "ocean":
				var weather_template := _weather_template(type_id)
				var ocean_transport := float(weather_template.get("route_efficiency_multiplier", weather_template.get("transport_multiplier", 1.0))) * float(weather_template.get("ocean_movement_multiplier", 1.0))
				if ocean_transport > 1.001:
					terrain_bonus += 58 + int(round((ocean_transport - 1.0) * 180.0))
				elif ocean_transport < 0.999:
					terrain_bonus += 20
			var empty_score := _ai_weather_empty_district_effect(player_index, district_index, type_id)
			neutral_value += empty_score
			var city := _district_city(district_index, player_index)
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
				"weather_target_terrain": String(_public_district(anchor).get("terrain", "land")),
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
					String(_public_district(anchor).get("name", "区域")),
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
	if district_index < 0 or district_index >= _district_count():
		return -1
	var city := _district_city(district_index, player_index)
	if not _city_is_active(city) or int(city.get("owner", -1)) != player_index:
		return -1
	var last_income := int(city.get("last_income", _city_cycle_income(district_index, _city_competition_matches(district_index))))
	var damage := int(_public_district(district_index).get("damage", 0))
	var disrupted := int(city.get("trade_disrupted_routes", 0)) + int(city.get("trade_route_damage", 0))
	var score := 90 + maxi(0, last_income)
	score += damage * 58 + disrupted * 72 + int(float(int(_public_district(district_index).get("panic", 0))) / 2.0)
	score += _city_warehouse_stockpile_pressure(city)
	score += int(float(_auto_build_monster_risk_score(district_index, player_index)) / 2.0)
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
		var city := _district_city(index, player_index)
		var city_owner := int(city.get("owner", -1))
		var last_income := int(city.get("last_income", _city_cycle_income(index, _city_competition_matches(index))))
		var damage := int(_public_district(index).get("damage", 0))
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
			score += damage * 52 + disrupted * 62 + int(float(int(_public_district(index).get("panic", 0))) / 2.0)
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
		var city := _district_city(index, player_index)
		var score := 80 + _ai_city_target_score(player_index, index, true, false)
		if _city_product_names(city).has(product_name):
			score += 130
		if _city_demand_names(city).has(product_name):
			score += 92
		score += int(float(int(city.get("last_income", 0))) / 4.0)
		score += int(round(float(_public_district(index).get("transport_score", 1.0)) * 36.0))
		score += _route_network_load_for_legacy_region(index) * 12
		score -= int(_public_district(index).get("damage", 0)) * 34
		score -= int(city.get("trade_route_damage", 0)) * 38
		score -= int(city.get("trade_disrupted_routes", 0)) * 28
		score -= int(float(_auto_build_monster_risk_score(index, player_index)) / 3.0)
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
	if district_index >= 0 and district_index < _district_count():
		var target_city := _district_city(district_index, player_index)
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
			("仓库:%s｜" % String(_public_district(warehouse_city).get("name", "城市"))) if warehouse_city >= 0 else "",
			_duration_short_text(_product_futures_duration_seconds(skill)),
		],
	}
	return result
func _ai_generic_card_effect_score(player_index: int, skill: Dictionary, district_index: int, product_name: String = "", target_owner: int = -999) -> int:
	var score := 0
	var harmful_target := target_owner >= 0 and target_owner != player_index
	var helpful_target := target_owner == player_index
	var target_city := _district_city(district_index, player_index)
	var warehouse_pressure := _city_warehouse_stockpile_pressure(target_city) if _city_is_active(target_city) else 0
	score += int(float(int(skill.get("cash", 0))) / 4.0)
	score += int(skill.get("draw_amount", 0)) * 45
	score += int(skill.get("history_review_count", 0)) * 28
	score += int(skill.get("history_subscription_count", 0)) * 24
	score += int(skill.get("reveal_city_count", 0)) * 48
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
			score += 96 if not _monster_public_roster().is_empty() else 18
	score += int(float(int(skill.get("revenue_amount", 0))) / 2.0)
	score += int(float(int(skill.get("contract_income", 0)) * maxi(1, int(ceil(float(_skill_duration_seconds(skill, "contract_seconds", "contract_turns", 1)) / ProductMarketRuntimeController.ECONOMY_LEGACY_TURN_SECONDS)))) / 5.0)
	score += int(round((float(skill.get("route_flow_multiplier", 1.0)) - 1.0) * 120.0)) if helpful_target else 0
	score += int(skill.get("repair_routes", 0)) * (55 if helpful_target else 18)
	var economy_delta := int(skill.get("production_delta", 0)) + int(skill.get("transport_delta", 0)) + int(skill.get("consumption_delta", 0))
	if economy_delta > 0:
		score += economy_delta * (60 if helpful_target else 24)
	elif economy_delta < 0:
		score += abs(economy_delta) * (70 if harmful_target else -45)
	var route_damage := int(skill.get("route_damage", 0))
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
		var city := _district_city(district_index, player_index)
		var last_income := int(city.get("last_income", 0))
		var risk := int(_public_district(district_index).get("damage", 0)) * 26 + int(city.get("trade_disrupted_routes", 0)) * 32 if district_index >= 0 and district_index < _district_count() else 0
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
	var city := _district_city(district_index, player_index)
	var city_owner := int(city.get("owner", -1)) if _city_is_active(city) else -1
	var terrain := String(_public_district(district_index).get("terrain", "land"))
	var terrain_multiplier := _military_unit_terrain_move_multiplier(skill, district_index)
	var income := int(city.get("last_income", _city_cycle_income(district_index, _city_competition_matches(district_index)))) if _city_is_active(city) else 0
	var route_pressure := int(city.get("trade_route_damage", 0)) + int(city.get("trade_disrupted_routes", 0)) if _city_is_active(city) else 0
	var warehouse_pressure := _city_warehouse_stockpile_pressure(city) if _city_is_active(city) else 0
	var route_load := _route_network_load_for_legacy_region(district_index)
	var monster_risk := _auto_build_monster_risk_score(district_index, player_index)
	var damage := int(_public_district(district_index).get("damage", 0))
	var panic := int(_public_district(district_index).get("panic", 0))
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
			String(_public_district(district_index).get("name", "区域")),
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
	for index in range(_district_count()):
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
	if _ai_military_actor_query_port == null \
			or not _ai_military_actor_capability_binding_initialized:
		return {}
	return _ai_military_actor_query_port.ready_owned_unit_by_uid(
		_ai_military_actor_capabilities.get(player_index) as AiMilitaryActorCapability,
		player_index,
		int(skill.get("bound_military_uid", 0))
	)

func _ai_military_guard_target(player_index: int, unit: Dictionary, command_range: float) -> Dictionary:
	var best := {}
	var best_score := -999999
	for city_index_variant in _active_city_indices_for_player(player_index):
		var city_index := int(city_index_variant)
		if _entity_distance_to_district(unit, city_index) > command_range:
			continue
		var city := _district_city(city_index, player_index)
		var damage := int(_public_district(city_index).get("damage", 0))
		var panic := int(_public_district(city_index).get("panic", 0))
		var route_damage := int(city.get("trade_route_damage", 0))
		var disrupted := int(city.get("trade_disrupted_routes", 0))
		var warehouse_pressure := _city_warehouse_stockpile_pressure(city)
		var monster_risk := _auto_build_monster_risk_score(city_index, player_index)
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
					String(_public_district(city_index).get("name", "城市")),
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
		var city := _district_city(city_index, player_index)
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
					String(_public_district(city_index).get("name", "城市")),
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
	for actor_variant in _monster_actor_roster(player_index):
		var actor := actor_variant as Dictionary
		if bool(actor.get("down", false)):
			continue
		var slot := int(actor.get("slot", -1))
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
		var resource_pressure := _monster_resource_match_score(actor, monster_position, player_index) \
			if monster_position >= 0 and monster_position < _district_count() else 0
		var ownership_scope := str(actor.get("ownership_scope", "public_unknown"))
		var score := 72 + int(actor.get("rank", 1)) * 42 \
			+ int(actor.get("hp", 0)) * 3 \
			+ resource_pressure * 65 \
			+ int(unit.get("damage", 1)) * 58
		if nearest_own_city >= 0:
			score += maxi(0, 260 - int(round(nearest_own_city_distance))) * 2
			score += int(float(_ai_city_target_score(player_index, nearest_own_city, true, true)) / 4.0)
		if ownership_scope == "actor_own":
			score -= 120
		elif ownership_scope == "public_revealed":
			score += 50
		if score > best_score:
			best_score = score
			best = {
				"target_slot": slot,
				"target_monster_uid": int(actor.get("uid", -1)),
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
	for index in range(_district_count()):
		if bool(_public_district(index).get("destroyed", false)):
			continue
		var city := _district_city(index, player_index)
		var city_owner := int(city.get("owner", -1)) if _city_is_active(city) else -1
		var distance := _entity_distance_to_district(unit, index)
		var terrain_multiplier := _military_unit_terrain_move_multiplier(unit, index)
		var score := int(round(terrain_multiplier * 55.0)) - int(round(distance / 20.0))
		if city_owner == player_index:
			score += 80 + int(float(_ai_city_target_score(player_index, index, true, true)) / 3.0)
			score += int(float(_auto_build_monster_risk_score(index, player_index)) / 2.0)
		elif city_owner >= 0:
			score += 65 + int(float(_ai_rival_city_pressure_score(player_index, index)) / 4.0)
			if ["bomber", "missile", "submarine", "warship"].has(unit_type):
				score += 70
		score += _route_network_load_for_legacy_region(index) * (18 if ["submarine", "warship"].has(unit_type) else 8)
		if String(_public_district(index).get("terrain", "land")) == "ocean" and ["submarine", "warship"].has(unit_type):
			score += 85
		if String(_public_district(index).get("terrain", "land")) == "land" and unit_type == "tank":
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
					String(_public_district(index).get("name", "区域")),
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
		"target_monster_uid": -1,
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
		"selected_card_resolution_id": -1,
		"score": 70 + maxi(0, int(skill.get("cost", 2))) * 12 + maxi(1, _skill_rank(String(skill.get("name", "")))) * 9,
		"reason": "按卡牌强度、目标价值、GDP份额、路线计划与AI性格评分",
	}
	if kind == "card_counter":
		return _ai_counter_response_candidate(player_index, slot_index, skill)
	if kind == "monster_card":
		context["district"] = _ai_best_monster_card_district(player_index, skill)
		context["score"] = 1180 if bool(skill.get("starter_play_free", false)) else int(context["score"]) + 150
	elif kind == "monster_bound_action":
		var bound_actor := _ai_monster_actor_for_skill(player_index, skill)
		if bound_actor.is_empty():
			return {}
		context["target_slot"] = int(bound_actor.get("slot", -1))
		context["target_monster_uid"] = int(bound_actor.get("uid", -1))
		context["district"] = _ai_best_district_near_monster(player_index, bound_actor)
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
		var target_actor := _ai_monster_actor_for_skill(player_index, skill)
		if target_actor.is_empty():
			return {}
		context["target_slot"] = int(target_actor.get("slot", -1))
		context["target_monster_uid"] = int(target_actor.get("uid", -1))
		var target_range := float(skill.get("range", -1.0)) if kind == "mudslide" else -1.0
		context["district"] = _ai_best_district_near_monster(player_index, target_actor, target_range)
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
	elif ["city_revenue_boost", "city_product_upgrade", "city_product_shift", "city_demand_shift", "city_contract_boon", "route_flow_boon"].has(kind):
		if own_city < 0:
			return {}
		context["district"] = own_city
		context["score"] = int(context["score"]) + 90
		context["focus_bonus"] = int(context.get("focus_bonus", 0)) + _ai_district_focus_score(player_index, own_city)
	elif kind == "route_insurance":
		var damaged_city := _ai_best_city_district(player_index, true, true)
		if damaged_city < 0 or int(_district_city(damaged_city, player_index).get("trade_route_damage", 0)) <= 0:
			var route_city := _ai_best_owned_route_city_for_product(player_index, route_product, false) if route_product != "" else -1
			damaged_city = route_city if route_city >= 0 else own_city
		if damaged_city < 0:
			return {}
		context["district"] = damaged_city
		var defense_city := _district_city(damaged_city, player_index)
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
		context["target_owner"] = int(_district_city(gdp_target, player_index).get("owner", -1))
		context["score"] = int(context["score"]) + 110 + int(round(float(derivative_terms.get("multiplier", 1.0)) * 35.0)) + int(float(int(derivative_terms.get("destroy_bonus", 0))) / 10.0) + _city_gdp_derivative_risk_adjusted_value(derivative_terms)
		if gdp_insurance:
			context["score"] = int(context["score"]) + int(float(_ai_city_gdp_insurance_score(player_index, gdp_target)) / 3.0)
		context["reason"] = "匿名%s%sGDP｜倍率×%.2f｜持仓%s" % [
			"灾害保单对冲" if gdp_insurance else ("买涨" if gdp_direction == "up" else "做空"),
			_public_district(gdp_target)["name"],
			float(derivative_terms.get("multiplier", 1.0)),
			_duration_short_text(_city_gdp_derivative_duration_seconds(skill)),
		]
	elif kind == "news_event":
		if rival_city < 0:
			return {}
		context["district"] = rival_city
		context["target_city"] = rival_city
		context["target_owner"] = int(_district_city(rival_city, player_index).get("owner", -1))
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
		context["target_owner"] = int(_district_city(rival_city, player_index).get("owner", -1))
		context["product"] = _ai_preferred_product(player_index, true)
		if String(context.get("product", "")) == focus_product and focus_product != "":
			context["focus_bonus"] = int(context.get("focus_bonus", 0)) + AI_ECONOMIC_FOCUS_MATCH_BONUS
		context["score"] = int(context["score"]) + 105
	elif kind == "region_economy_shift":
		var net_shift := int(skill.get("production_delta", 0)) + int(skill.get("transport_delta", 0)) + int(skill.get("consumption_delta", 0))
		context["district"] = own_city if net_shift >= 0 else rival_city
		if int(context["district"]) < 0:
			return {}
		var shifted_city := _district_city(int(context["district"]), player_index)
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
		var rival_city_snapshot := _district_city(rival_city, player_index)
		context["score"] = int(context["score"]) + 88 + _city_intel_priority_score({"potential_income": int(rival_city_snapshot.get("last_income", 0)), "last_income": int(rival_city_snapshot.get("last_income", 0)), "competition": _city_competition_matches(rival_city), "disrupted": int(rival_city_snapshot.get("trade_disrupted_routes", 0)), "products": _city_product_names(rival_city_snapshot), "demands": _city_demand_names(rival_city_snapshot), "marked": false})
	elif ["card_history_public_review", "card_history_subscription"].has(kind):
		var history_resolution_id := _latest_public_history_resolution_id()
		if history_resolution_id < 0:
			return {}
		context["selected_card_resolution_id"] = history_resolution_id
		context["district"] = _ai_first_alive_district()
		context["score"] = int(context["score"]) + 70 + mini(36, resolved_card_history.size() * 3)
	elif kind == "supply_draw":
		context["district"] = -1
		for i in range(_district_count()):
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
	var cash_cost := _skill_play_cash_cost(skill, player_index)
	if _actor_available_cash_units(player_index) < cash_cost:
		return {}
	var target_owner := -999
	var context_district := int(context.get("district", -1))
	if context.has("target_owner"):
		target_owner = int(context.get("target_owner", -999))
	elif context_district >= 0 and context_district < _district_count():
		var target_city := _district_city(context_district, player_index)
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
	var hand := _ai_card_hand_snapshot(player_index)
	if hand.is_empty() or float(hand.get("action_cooldown", 0.0)) > 0.0:
		return result
	if _ai_has_current_card_submission(player_index) or _ai_has_next_card_submission(player_index):
		return result
	var slots: Array = hand.get("slots", []) if hand.get("slots", []) is Array else []
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
	var hand := _ai_card_hand_snapshot(player_index)
	if hand.is_empty() or float(hand.get("action_cooldown", 0.0)) > 0.0:
		return result
	var player := {"slots": (hand.get("slots", []) as Array).duplicate(true)}
	var cash := _actor_available_cash_units(player_index)
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
	for district_index in range(_district_count()):
		if not _market_listing_purchasable(district_index) or bool(_public_district(district_index).get("destroyed", false)):
			continue
		for card_variant in _district_supply_card_ids(district_index):
			var card_name := String(card_variant)
			if card_name == "" or not _player_can_receive_card_with_discard(player_index, card_name):
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
			var needs_discard := _purchase_requires_discard(player_index, card_name)
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
			var city := _district_city(district_index, player_index)
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
		"target_monster_uid": int(candidate.get("target_monster_uid", -1)),
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
	var target_district := int(candidate.get("district", _ai_first_alive_district()))
	var target_product := String(candidate.get("product", ""))
	var receipt := _queue_skill_resolution(
		player_index,
		slot_index,
		target_slot,
		target_player,
		int(candidate.get("selected_card_resolution_id", -1)),
		target_district,
		target_product,
		int(candidate.get("target_monster_uid", -1))
	)
	var queued := bool(receipt.get("accepted", false))
	if queued:
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
	return queued


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
	var hand := _ai_card_hand_snapshot(player_index)
	if hand.is_empty() or float(hand.get("action_cooldown", 0.0)) > 0.0:
		return result
	if _ai_has_current_card_submission(player_index) or _ai_has_next_card_submission(player_index):
		return result
	var slots: Array = hand.get("slots", []) if hand.get("slots", []) is Array else []
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
	var hand := _ai_card_hand_snapshot(player_index)
	if hand.is_empty():
		return false
	var slots: Array = hand.get("slots", []) if hand.get("slots", []) is Array else []
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return false
	var source_skill: Dictionary = slots[slot_index]
	var target_district := int(candidate.get("district", int(_card_resolution_active_entry().get("selected_district", _ai_first_alive_district()))))
	var target_product := String(candidate.get("product", _skill_play_product(source_skill, player_index)))
	var selected_resolution_id := int(candidate.get("counter_target_resolution_id", -1))
	var receipt: Dictionary
	if bool(candidate.get("counter_converted_monster", false)):
		receipt = _queue_monster_card_as_counter(
			player_index,
			slot_index,
			target_district,
			target_product,
			selected_resolution_id
		)
	else:
		receipt = _queue_skill_resolution(
			player_index,
			slot_index,
			-1,
			-1,
			selected_resolution_id,
			target_district,
			target_product
		)
	var queued := bool(receipt.get("accepted", false))
	if queued:
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
func _ai_public_player_product_signal(viewer_index: int, guessed_player: int, product_name: String) -> int:
	var snapshot := _city_inference_snapshot(viewer_index)
	var player_count := _ai_actor_state_port.player_count() if _ai_actor_state_port != null else 0
	if snapshot.is_empty() or guessed_player < 0 or guessed_player >= player_count or product_name == "":
		return 0
	var signal_score := 0
	for region_variant in snapshot.get("regions", []) as Array:
		if not (region_variant is Dictionary):
			continue
		var region := region_variant as Dictionary
		var city: Dictionary = region.get("city", {}) if region.get("city", {}) is Dictionary else {}
		if int(city.get("owner", -1)) != guessed_player \
				or str(city.get("owner_knowledge", "")) not in ["actor_guess", "authorized_reveal"]:
			continue
		if not _city_is_active(city):
			continue
		var confidence := _normalized_city_guess_confidence(int(city.get("owner_confidence", CITY_GUESS_CONFIDENCE_DEFAULT)))
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
	return signal_score
func _ai_city_guess_owner_candidate(viewer_index: int, city_entry: Dictionary, guessed_player: int) -> Dictionary:
	var city_index := int(city_entry.get("district_index", -1))
	var player_count := _ai_actor_state_port.player_count() if _ai_actor_state_port != null else 0
	if city_index < 0 or guessed_player < 0 or guessed_player >= player_count or guessed_player == viewer_index:
		return {}
	var city: Dictionary = city_entry.get("city", {}) if city_entry.get("city", {}) is Dictionary else {}
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
			str(city_entry.get("name", "城市")),
			guessed_player + 1,
			"、".join(reason_bits),
		],
	}
func _ai_city_guess_candidates(player_index: int) -> Array:
	var result := []
	if not _city_inference_ports_ready() or not _ai_actor_state_port.is_ai_player(player_index) \
			or _ai_actor_state_port.is_player_eliminated(player_index):
		return result
	var player_count := _ai_actor_state_port.player_count()
	for entry_variant in _intel_city_guess_entries(player_index, 12):
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if bool(entry.get("marked", false)) and int(entry.get("confidence", 0)) >= CITY_GUESS_CONFIDENCE_HIGH:
			continue
		var best := {}
		for guessed_player in range(player_count):
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
func _auto_ai_intel_decisions(force: bool = false) -> int:
	if session_finished or not ai_card_decision_enabled:
		return 0
	var acted := 0
	for player_index_variant in _typed_ai_player_indices():
		var player_index := int(player_index_variant)
		var city_candidates := _ai_city_guess_candidates(player_index)
		var city_choice := _ai_pick_candidate(player_index, city_candidates, force)
		if not city_choice.is_empty() and (force or int(city_choice.get("score", 0)) >= AI_INTEL_MIN_CITY_SCORE):
			if _ai_apply_city_guess_candidate(player_index, city_choice, city_candidates):
				acted += 1
		if acted >= AI_INTEL_ACTIONS_PER_TICK and not force:
			return acted
	return acted
func _update_ai_decisions(delta: float) -> void:
	if not ai_card_decision_enabled or _ai_player_count() <= 0:
		return
	ai_auction_reaction_timer -= delta
	if ai_auction_reaction_timer <= 0.0:
		_auto_ai_counter_responses(false)
		_auto_ai_monster_wagers()
		ai_auction_reaction_timer = AI_AUCTION_REACTION_INTERVAL_SECONDS
	ai_card_decision_timer -= delta
	if ai_card_decision_timer <= 0.0:
		_auto_ai_card_decisions(false)
		ai_card_decision_timer = AI_CARD_DECISION_INTERVAL_SECONDS
	ai_intel_decision_timer -= delta
	if ai_intel_decision_timer <= 0.0:
		_auto_ai_intel_decisions(false)
		ai_intel_decision_timer = AI_INTEL_DECISION_INTERVAL_SECONDS
func _ai_discard_keep_value(player_index: int, slot_index: int) -> int:
	var hand := _ai_card_hand_snapshot(player_index)
	if hand.is_empty():
		return 99999
	var slots: Array = hand.get("slots", []) if hand.get("slots", []) is Array else []
	if slot_index < 0 or slot_index >= slots.size():
		return 99999
	var skill_variant: Variant = slots[slot_index]
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
	if _ai_card_hand_snapshot(player_index).is_empty():
		return -1
	var slots := _discardable_hand_slots_for_purchase(player_index)
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
		var city := _district_city(city_index, player_index)
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
	var actor := _monster_actor_at_slot(player_index, slot)
	if not actor.is_empty():
		var expected_damage := _monster_wager_actor_expected_damage_score(actor)
		combat_score = expected_damage * 38 \
			+ int(actor.get("hp", 0)) \
			+ int(actor.get("armor", 0)) * 6 \
			+ int(actor.get("rank", 1)) * 32
		var ownership_scope := str(actor.get("ownership_scope", "public_unknown"))
		if ownership_scope == "actor_own":
			owner_bias = 120
			if not bool(actor.get("owner_revealed", false)):
				owner_bias -= 28
			reason_key = "own_monster"
		elif ownership_scope == "public_revealed":
			var public_owner := int(actor.get("public_owner_index", -1))
			var leader_index := int(_ai_refresh_game_phase(player_index).get("leader_index", -1))
			owner_bias = 38
			if public_owner == leader_index and public_owner != player_index:
				owner_bias -= 42
				reason_key = "leader_monster"
			else:
				reason_key = "revealed_rival_monster"
		else:
			owner_bias = 18
			reason_key = "unknown_owner"
		var city_pressure := _ai_monster_wager_nearest_city_pressure(player_index, actor)
		var own_pressure := int(city_pressure.get("own_pressure", 0))
		var rival_pressure := int(city_pressure.get("rival_pressure", 0))
		city_bias = int(float(rival_pressure) / 6.0) - int(float(own_pressure) / 8.0)
		resource_bias = _monster_resource_match_score(actor, int(actor.get("position", -1)), player_index) * 18
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
	var stake := _monster_wager_amount_for_percent(player_index, stake_percent, entry)
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
	if not _active_monster_wager_ids().has(wager_id):
		return 0
	var acted := 0
	for player_index_variant in (_ai_actor_state_port.ai_player_indices(true) if _actor_state_ready() else []):
		var player_index := int(player_index_variant)
		var entry := _monster_wager_decision_snapshot_for_actor(wager_id, player_index)
		if entry.is_empty():
			continue
		if not bool(entry.get("decision_open", false)):
			break
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
			if not _active_monster_wager_ids().has(wager_id):
				break
	return acted
func _auto_ai_monster_wagers() -> int:
	var acted := 0
	for wager_id_variant: Variant in _active_monster_wager_ids():
		acted += _auto_ai_monster_wagers_for_entry(int(wager_id_variant))
	return acted
