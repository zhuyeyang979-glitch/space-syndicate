extends RefCounted
class_name SharedCommodityTrackAiSemanticsReference

const CORE := preload("res://tests/support/shared_commodity_track_core_semantics_reference.gd")
const DIFFICULTIES := ["easy", "normal", "hard", "expert"]
const OBSERVATION_KEYS := [
	"schema_version",
	"actor_id",
	"cycle_index",
	"cycle_remaining_us",
	"macro_round_index",
	"macro_round_direction",
	"cycles_remaining_in_macro_round",
	"current_runtime_distribution",
	"gdp_baseline_distribution",
	"trend_distribution",
	"current_revealed_stances",
	"public_stance_history",
	"local_track_segment",
	"own_inventory",
	"own_next_stance",
	"own_stance_locked",
	"self_is_current_lead",
	"own_color_needs",
	"public_visible_opponent_demand",
	"commodity_merge_identity_policy_id",
	"end_condition_pending",
]


static func observation_valid(observation: Dictionary) -> bool:
	if not _has_exact_keys(observation, OBSERVATION_KEYS) or not CORE.is_pure_data(observation):
		return false
	if str(observation.get("actor_id", "")).is_empty() \
			or not ["forward", "reverse"].has(str(observation.get("macro_round_direction", ""))):
		return false
	if not _color_map_valid(observation.get("current_runtime_distribution", {})) \
			or not _color_map_valid(observation.get("gdp_baseline_distribution", {})) \
			or not _color_map_valid(observation.get("trend_distribution", {})) \
			or not _color_map_valid(observation.get("own_color_needs", {})) \
			or not _color_map_valid(observation.get("public_visible_opponent_demand", {})):
		return false
	if not _revealed_stances_valid(observation.get("current_revealed_stances", [])) \
			or not _public_history_valid(observation.get("public_stance_history", [])) \
			or not _local_segment_valid(observation.get("local_track_segment", [])):
		return false
	var inventory: Dictionary = observation.get("own_inventory", {}) \
		if observation.get("own_inventory", {}) is Dictionary else {}
	if not CORE.inventory_valid(inventory) \
			or str(inventory.get("actor_id", "")) != str(observation.get("actor_id", "")):
		return false
	var own_stance: Dictionary = observation.get("own_next_stance", {}) \
		if observation.get("own_next_stance", {}) is Dictionary else {}
	if not own_stance.is_empty() and not _public_stance_valid(own_stance, false):
		return false
	if not ["", "same_product_id", "same_color_id"].has(str(observation.get("commodity_merge_identity_policy_id", ""))):
		return false
	var serialized := JSON.stringify(observation)
	for forbidden in [
		"hidden_forward_order",
		"hidden_order",
		"hidden_order_fingerprint",
		"current_hidden_lead_player_id",
		"lead_player_id",
		"next_private_stances",
		"authority_contributions",
		"effective_influence_bp",
		"effective_weight",
		"weight_bp",
		"ordered_item_tokens",
		"authoritative_track_position",
		"other_private_inventory",
		"rng_state",
		"rng_cursor",
		"save_payload",
		"save_state",
		"decision_samples",
		"learning_metadata",
	]:
		if serialized.contains(forbidden):
			return false
	return true


static func choose_market_stance(
	observation: Dictionary,
	difficulty: String,
	intent_revision: int
) -> Dictionary:
	if not observation_valid(observation) or not DIFFICULTIES.has(difficulty):
		return {}
	var own_needs: Dictionary = observation.get("own_color_needs", {})
	var public_demand: Dictionary = observation.get("public_visible_opponent_demand", {})
	var distribution: Dictionary = observation.get("current_runtime_distribution", {})
	var history: Array = observation.get("public_stance_history", [])
	var increase_scores := {}
	var decrease_scores := {}
	for color_id in CORE.COLOR_IDS:
		var scarcity := CORE.TOTAL_BASIS_POINTS - int(distribution.get(color_id, 0))
		var own_need := int(own_needs.get(color_id, 0))
		var opponent_need := int(public_demand.get(color_id, 0))
		var history_pressure := _public_history_pressure(history, color_id)
		increase_scores[color_id] = own_need * 100
		decrease_scores[color_id] = int(distribution.get(color_id, 0))
		if difficulty in ["normal", "hard", "expert"]:
			increase_scores[color_id] += int(float(scarcity) / 25.0)
			decrease_scores[color_id] += opponent_need * 80
		if difficulty in ["hard", "expert"]:
			increase_scores[color_id] -= maxi(0, history_pressure) * 20
			decrease_scores[color_id] += maxi(0, history_pressure) * 30
		if difficulty == "expert" and bool(observation.get("end_condition_pending", false)):
			increase_scores[color_id] += own_need * 60
			decrease_scores[color_id] += opponent_need * 60
	var increase_color := _highest_color(increase_scores, "")
	var decrease_color := _highest_color(decrease_scores, increase_color)
	if increase_color.is_empty() or decrease_color.is_empty():
		return {}
	return CORE.stance_intent(
		str(observation.get("actor_id", "")),
		int(observation.get("cycle_index", 0)),
		increase_color,
		decrease_color,
		true,
		intent_revision
	)


static func choose_commodity_action(observation: Dictionary) -> Dictionary:
	if not observation_valid(observation):
		return {"action_kind": "wait", "reason_code": "observation_invalid"}
	var inventory: Dictionary = observation.get("own_inventory", {})
	var groups: Array = inventory.get("commodity_stacks", []) \
		if inventory.get("commodity_stacks", []) is Array else []
	var identity_policy_id := str(observation.get("commodity_merge_identity_policy_id", ""))
	for base_variant in groups:
		if not (base_variant is Dictionary):
			continue
		var base := base_variant as Dictionary
		var base_level := int(base.get("commodity_level", 0))
		if base_level < 1 or base_level >= CORE.MAX_COMMODITY_LEVEL:
			continue
		for unit_variant in groups:
			if not (unit_variant is Dictionary):
				continue
			var unit := unit_variant as Dictionary
			var identity_matches := str(unit.get("product_id", "")) == str(base.get("product_id", "")) \
				if identity_policy_id == "same_product_id" \
				else str(unit.get("color_id", "")) == str(base.get("color_id", ""))
			if not identity_policy_id.is_empty() \
					and str(unit.get("group_id", "")) != str(base.get("group_id", "")) \
					and int(unit.get("commodity_level", 0)) == 1 \
					and identity_matches:
				return {
					"action_kind": "merge_commodity",
					"base_group_id": str(base.get("group_id", "")),
					"level_one_group_id": str(unit.get("group_id", "")),
					"identity_policy_id": identity_policy_id,
				}
	var segment: Array = observation.get("local_track_segment", [])
	if may_accept_commodity_card(observation):
		var needs: Dictionary = observation.get("own_color_needs", {})
		var best_item: Dictionary = {}
		var best_score := -1
		for item_variant in segment:
			if item_variant is Dictionary and bool((item_variant as Dictionary).get("claimable", false)):
				var item := item_variant as Dictionary
				var score := int(needs.get(str(item.get("color_id", "")), 0)) * 100 \
					+ int(item.get("commodity_level", 0))
				if score > best_score:
					best_item = item
					best_score = score
		if not best_item.is_empty():
			return {
				"action_kind": "claim_local_commodity",
				"token_id": str(best_item.get("token_id", "")),
				"local_slot_index": int(best_item.get("local_slot_index", -1)),
			}
	return {"action_kind": "wait", "reason_code": "no_legal_commodity_action"}


static func may_accept_normal_card(observation: Dictionary) -> bool:
	if not observation_valid(observation):
		return false
	var inventory: Dictionary = observation.get("own_inventory", {})
	return int(inventory.get("normal_card_count", 0)) < int(inventory.get("normal_card_limit", 0))


static func may_accept_commodity_card(observation: Dictionary) -> bool:
	if not observation_valid(observation):
		return false
	var inventory: Dictionary = observation.get("own_inventory", {})
	return int(inventory.get("commodity_slot_count", 0)) < int(inventory.get("commodity_slot_limit", 0))


static func _color_map_valid(value_variant: Variant) -> bool:
	if not (value_variant is Dictionary):
		return false
	var value := value_variant as Dictionary
	if value.size() != CORE.COLOR_IDS.size():
		return false
	for color_id in CORE.COLOR_IDS:
		if not value.has(color_id) or typeof(value.get(color_id)) != TYPE_INT:
			return false
	return true


static func _revealed_stances_valid(value_variant: Variant) -> bool:
	if not (value_variant is Array):
		return false
	for stance_variant in value_variant as Array:
		if not (stance_variant is Dictionary) or not _public_stance_valid(stance_variant as Dictionary, true):
			return false
	return true


static func _public_history_valid(value_variant: Variant) -> bool:
	if not (value_variant is Array):
		return false
	for event_variant in value_variant as Array:
		if not (event_variant is Dictionary):
			return false
		var event := event_variant as Dictionary
		if not _has_exact_keys(event, ["cycle_index", "revealed_stances", "final_runtime_distribution"]) \
				or typeof(event.get("cycle_index")) != TYPE_INT \
				or not _revealed_stances_valid(event.get("revealed_stances", [])) \
				or not _color_map_valid(event.get("final_runtime_distribution", {})):
			return false
	return true


static func _local_segment_valid(value_variant: Variant) -> bool:
	if not (value_variant is Array):
		return false
	for item_variant in value_variant as Array:
		if not (item_variant is Dictionary):
			return false
		var item := item_variant as Dictionary
		if not _has_exact_keys(item, ["local_slot_index", "token_id", "product_id", "color_id", "commodity_level", "base_unit_count", "claimable"]) \
				or int(item.get("local_slot_index", -1)) < 0 \
				or str(item.get("token_id", "")).is_empty() \
				or str(item.get("product_id", "")).is_empty() \
				or not CORE.COLOR_IDS.has(str(item.get("color_id", ""))) \
				or int(item.get("commodity_level", 0)) < 1 \
				or int(item.get("base_unit_count", 0)) != int(item.get("commodity_level", 0)) \
				or typeof(item.get("claimable")) != TYPE_BOOL:
			return false
	return true


static func _public_stance_valid(stance: Dictionary, require_actor_id: bool) -> bool:
	var expected := ["increase_color", "decrease_color"]
	if require_actor_id:
		expected.push_front("actor_id")
	if not _has_exact_keys(stance, expected):
		return false
	return (not require_actor_id or not str(stance.get("actor_id", "")).is_empty()) \
		and CORE.COLOR_IDS.has(str(stance.get("increase_color", ""))) \
		and CORE.COLOR_IDS.has(str(stance.get("decrease_color", ""))) \
		and str(stance.get("increase_color", "")) != str(stance.get("decrease_color", ""))


static func _public_history_pressure(history: Array, color_id: String) -> int:
	var pressure := 0
	for event_variant in history:
		if not (event_variant is Dictionary):
			continue
		for stance_variant in (event_variant as Dictionary).get("revealed_stances", []) as Array:
			if stance_variant is Dictionary:
				var stance := stance_variant as Dictionary
				pressure += 1 if str(stance.get("increase_color", "")) == color_id else 0
				pressure -= 1 if str(stance.get("decrease_color", "")) == color_id else 0
	return pressure


static func _highest_color(scores: Dictionary, excluded_color: String) -> String:
	var best_color := ""
	var best_score := -9_223_372_036_854_775_808
	for color_id in CORE.COLOR_IDS:
		if color_id == excluded_color:
			continue
		var score := int(scores.get(color_id, 0))
		if best_color.is_empty() or score > best_score:
			best_color = color_id
			best_score = score
	return best_color


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(key_variant):
			return false
	return true
