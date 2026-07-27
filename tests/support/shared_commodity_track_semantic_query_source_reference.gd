extends RefCounted
class_name SharedCommodityTrackSemanticQuerySourceReference

const CORE := preload("res://tests/support/shared_commodity_track_core_semantics_reference.gd")
const AI := preload("res://tests/support/shared_commodity_track_ai_semantics_reference.gd")
const PLAYER := preload("res://tests/support/shared_commodity_track_player_semantics_reference.gd")


static func ai_observation_for_bound_actor(
	authority_state: Dictionary,
	bound_actor_id: String,
	requested_actor_id: String
) -> Dictionary:
	if bound_actor_id.is_empty() or bound_actor_id != requested_actor_id:
		return {}
	var market := _dictionary(authority_state.get("market_cycle", {}))
	var track := _dictionary(authority_state.get("track", {}))
	var inventories := _dictionary(authority_state.get("inventories", {}))
	var private_needs := _dictionary(authority_state.get("actor_private_needs", {}))
	var next_stances := _dictionary(market.get("next_private_stances", {}))
	var own_stance := _dictionary(next_stances.get(bound_actor_id, {}))
	var forward_order := _array(market.get("hidden_forward_order", []))
	var completed := _array(market.get("players_completed_in_current_macro_round", []))
	var previous := _dictionary(market.get("previous_runtime_distribution", {}))
	var current := _dictionary(market.get("final_runtime_distribution", {}))
	var trend := {}
	for color_id in CORE.COLOR_IDS:
		trend[color_id] = _safe_int(current.get(color_id, 0)) - _safe_int(previous.get(color_id, 0))
	if not inventories.has(bound_actor_id):
		return {}
	var observation := {
		"schema_version": 1,
		"actor_id": bound_actor_id,
		"cycle_index": _safe_int(market.get("cycle_index", 0)),
		"cycle_remaining_us": maxi(0, _safe_int(market.get("cycle_remaining_us", 0))),
		"macro_round_index": maxi(1, _safe_int(market.get("macro_round_index", 1))),
		"macro_round_direction": "reverse" if str(market.get("macro_round_direction", "forward")) == "reverse" else "forward",
		"cycles_remaining_in_macro_round": maxi(0, forward_order.size() - completed.size()),
		"current_runtime_distribution": _color_value_map(current),
		"gdp_baseline_distribution": _color_value_map(market.get("gdp_baseline_distribution", {})),
		"trend_distribution": _color_value_map(trend),
		"current_revealed_stances": _revealed_stances(market.get("current_revealed_stances", [])),
		"public_stance_history": _public_history(authority_state.get("public_stance_history", [])),
		"local_track_segment": CORE.viewer_local_segment(track, bound_actor_id),
		"own_inventory": _inventory_projection(inventories.get(bound_actor_id, {})),
		"own_next_stance": _private_stance_shape(own_stance),
		"own_stance_locked": bool(own_stance.get("lock", false)),
		"self_is_current_lead": str(market.get("current_hidden_lead_player_id", "")) == bound_actor_id,
		"own_color_needs": _color_value_map(private_needs.get(bound_actor_id, {})),
		"public_visible_opponent_demand": _color_value_map(authority_state.get("public_visible_opponent_demand", {})),
		"commodity_merge_identity_policy_id": _merge_identity_policy(_dictionary(authority_state.get("rule_terms", {}))),
		"end_condition_pending": bool(_dictionary(authority_state.get("end_gate", {})).get("end_condition_pending", false)),
	}
	return observation if AI.observation_valid(observation) else {}


static func player_projection_for_bound_viewer(
	authority_state: Dictionary,
	bound_viewer_id: String,
	requested_viewer_id: String
) -> Dictionary:
	if bound_viewer_id.is_empty() or bound_viewer_id != requested_viewer_id:
		return {}
	var market := _dictionary(authority_state.get("market_cycle", {}))
	var track := _dictionary(authority_state.get("track", {}))
	var inventories := _dictionary(authority_state.get("inventories", {}))
	if not inventories.has(bound_viewer_id):
		return {}
	var inventory := _dictionary(inventories.get(bound_viewer_id, {}))
	if str(inventory.get("actor_id", "")) != bound_viewer_id:
		return {}
	var normal_cards := _normal_cards(inventory.get("normal_cards", []))
	var commodity_stacks := _commodity_stacks(inventory.get("commodity_stacks", []))
	var private_stances := _dictionary(market.get("next_private_stances", {}))
	var own_stance := _dictionary(private_stances.get(bound_viewer_id, {}))
	var current := _dictionary(market.get("final_runtime_distribution", {}))
	var baseline := _dictionary(market.get("gdp_baseline_distribution", {}))
	var previous := _dictionary(market.get("previous_runtime_distribution", {}))
	var supply_rows: Array = []
	for color_id in CORE.COLOR_IDS:
		supply_rows.append({
			"color_id": color_id,
			"final_basis_points": _safe_int(current.get(color_id, 0)),
			"gdp_baseline_basis_points": _safe_int(baseline.get(color_id, 0)),
			"trend_basis_points": _safe_int(current.get(color_id, 0)) - _safe_int(previous.get(color_id, 0)),
		})
	var self_is_lead := str(market.get("current_hidden_lead_player_id", "")) == bound_viewer_id
	var projection := {
		"schema_version": 1,
		"viewer_id": bound_viewer_id,
		"market_cycle": {
			"cycle_index": _safe_int(market.get("cycle_index", 0)),
			"remaining_seconds": float(maxi(0, _safe_int(market.get("cycle_remaining_us", 0)))) / 1_000_000.0,
			"macro_round_index": maxi(1, _safe_int(market.get("macro_round_index", 1))),
			"direction_label": "反向大轮" if str(market.get("macro_round_direction", "forward")) == "reverse" else "正向大轮",
		},
		"public_supply_rows": supply_rows,
		"revealed_stances": _revealed_stances(market.get("current_revealed_stances", [])),
		"viewer_private": {
			"local_track_segment": CORE.viewer_local_segment(track, bound_viewer_id),
			"next_stance": _private_stance_shape(own_stance),
			"stance_locked": bool(own_stance.get("lock", false)),
			"lead_notice_visible": self_is_lead,
			"lead_notice_text": "本周期你拥有市场主导权。你的供给立场影响为普通玩家的两倍。" if self_is_lead else "",
		},
		"inventory_capacity": {
			"normal_hand_count": normal_cards.size(),
			"normal_hand_limit": CORE.NORMAL_CARD_HAND_LIMIT,
			"normal_hand_label": "普通手牌：%d / %d" % [normal_cards.size(), CORE.NORMAL_CARD_HAND_LIMIT],
			"normal_card_acquisition_allowed": normal_cards.size() < CORE.NORMAL_CARD_HAND_LIMIT,
			"normal_status_reason": "normal_card_hand_full" if normal_cards.size() >= CORE.NORMAL_CARD_HAND_LIMIT else "normal_card_space_available",
			"commodity_slot_count": commodity_stacks.size(),
			"commodity_slot_limit": CORE.COMMODITY_CARD_HAND_LIMIT,
			"commodity_inventory_label": "商品库存：%d / %d" % [commodity_stacks.size(), CORE.COMMODITY_CARD_HAND_LIMIT],
			"commodity_acquisition_allowed": commodity_stacks.size() < CORE.COMMODITY_CARD_HAND_LIMIT,
			"commodity_status_reason": "commodity_inventory_full" if commodity_stacks.size() >= CORE.COMMODITY_CARD_HAND_LIMIT else "commodity_space_available",
			"commodity_stacks": commodity_stacks,
		},
		"upgrade_ladder": [
			{"from_level": 1, "plus_level": 1, "to_level": 2, "base_unit_count": 2},
			{"from_level": 2, "plus_level": 1, "to_level": 3, "base_unit_count": 3},
			{"from_level": 3, "plus_level": 1, "to_level": 4, "base_unit_count": 4},
		],
		"end_gate": _end_gate_projection(_dictionary(authority_state.get("end_gate", {}))),
	}
	return projection if PLAYER.projection_valid(projection) else {}


static func _dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _array(value: Variant) -> Array:
	return value if value is Array else []


static func _safe_int(value: Variant) -> int:
	return int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else 0


static func _color_value_map(source_variant: Variant) -> Dictionary:
	var source := _dictionary(source_variant)
	var result := {}
	for color_id in CORE.COLOR_IDS:
		result[color_id] = _safe_int(source.get(color_id, 0))
	return result


static func _revealed_stances(source_variant: Variant) -> Array:
	var result: Array = []
	for stance_variant in _array(source_variant):
		if not (stance_variant is Dictionary):
			continue
		var stance := stance_variant as Dictionary
		var actor_id := str(stance.get("actor_id", ""))
		var increase_color := str(stance.get("increase_color", ""))
		var decrease_color := str(stance.get("decrease_color", ""))
		if not actor_id.is_empty() and CORE.COLOR_IDS.has(increase_color) \
				and CORE.COLOR_IDS.has(decrease_color) and increase_color != decrease_color:
			result.append({
				"actor_id": actor_id,
				"increase_color": increase_color,
				"decrease_color": decrease_color,
			})
	return result


static func _public_history(source_variant: Variant) -> Array:
	var result: Array = []
	for event_variant in _array(source_variant):
		if not (event_variant is Dictionary):
			continue
		var event := event_variant as Dictionary
		result.append({
			"cycle_index": _safe_int(event.get("cycle_index", 0)),
			"revealed_stances": _revealed_stances(event.get("revealed_stances", [])),
			"final_runtime_distribution": _color_value_map(event.get("final_runtime_distribution", {})),
		})
	return result


static func _normal_cards(source_variant: Variant) -> Array:
	var result: Array = []
	for card_variant in _array(source_variant):
		if card_variant is String and not str(card_variant).is_empty():
			result.append(str(card_variant))
	return result


static func _commodity_stacks(source_variant: Variant) -> Array:
	var result: Array = []
	for stack_variant in _array(source_variant):
		if not (stack_variant is Dictionary):
			continue
		var stack := stack_variant as Dictionary
		var normalized := {
			"group_id": str(stack.get("group_id", "")),
			"product_id": str(stack.get("product_id", "")),
			"color_id": str(stack.get("color_id", "")),
			"commodity_level": _safe_int(stack.get("commodity_level", 0)),
			"base_unit_count": _safe_int(stack.get("base_unit_count", 0)),
		}
		if CORE.commodity_stack_valid(normalized):
			result.append(normalized)
	return result


static func _inventory_projection(source_variant: Variant) -> Dictionary:
	var source := _dictionary(source_variant)
	if source.is_empty():
		return {}
	var normal_cards := _normal_cards(source.get("normal_cards", []))
	var commodity_stacks := _commodity_stacks(source.get("commodity_stacks", []))
	return {
		"schema_version": 1,
		"actor_id": str(source.get("actor_id", "")),
		"revision": maxi(1, _safe_int(source.get("revision", 1))),
		"normal_card_count": normal_cards.size(),
		"normal_card_limit": CORE.NORMAL_CARD_HAND_LIMIT,
		"normal_cards": normal_cards,
		"commodity_slot_count": commodity_stacks.size(),
		"commodity_slot_limit": CORE.COMMODITY_CARD_HAND_LIMIT,
		"commodity_stacks": commodity_stacks,
	}


static func _private_stance_shape(stance: Dictionary) -> Dictionary:
	var increase_color := str(stance.get("increase_color", ""))
	var decrease_color := str(stance.get("decrease_color", ""))
	if stance.is_empty() or not CORE.COLOR_IDS.has(increase_color) \
			or not CORE.COLOR_IDS.has(decrease_color) or increase_color == decrease_color:
		return {}
	return {"increase_color": increase_color, "decrease_color": decrease_color}


static func _merge_identity_policy(rule_terms: Dictionary) -> String:
	var policy_id := str(rule_terms.get("commodity_merge_identity_policy_id", ""))
	return policy_id if ["same_product_id", "same_color_id"].has(policy_id) else ""


static func _end_gate_projection(gate: Dictionary) -> Dictionary:
	if bool(gate.get("game_may_end", false)):
		return {"state": "final_validation_passed", "message": "完整大轮已结束，结束条件复核通过。", "final_scoring_allowed": true}
	if bool(gate.get("end_condition_pending", false)):
		return {"state": "pending_macro_round_boundary", "message": "结束条件已触发，游戏将在当前完整大轮结束时重新验证。", "final_scoring_allowed": false}
	return {"state": "running", "message": "市场周期进行中。", "final_scoring_allowed": false}
