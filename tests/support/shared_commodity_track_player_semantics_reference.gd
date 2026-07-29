extends RefCounted
class_name SharedCommodityTrackPlayerSemanticsReference

const CORE := preload("res://tests/support/shared_commodity_track_core_semantics_reference.gd")
const PROJECTION_KEYS := [
	"schema_version",
	"viewer_id",
	"market_cycle",
	"public_supply_rows",
	"revealed_stances",
	"viewer_private",
	"inventory_capacity",
	"upgrade_ladder",
	"end_gate",
]


static func projection_valid(projection: Dictionary) -> bool:
	if not _has_exact_keys(projection, PROJECTION_KEYS) or not CORE.is_pure_data(projection):
		return false
	if str(projection.get("viewer_id", "")).is_empty() \
			or not _market_cycle_valid(projection.get("market_cycle", {})) \
			or not _supply_rows_valid(projection.get("public_supply_rows", [])) \
			or not _revealed_stances_valid(projection.get("revealed_stances", [])) \
			or not _viewer_private_valid(projection.get("viewer_private", {})) \
			or not _inventory_capacity_valid(projection.get("inventory_capacity", {})) \
			or not _upgrade_ladder_valid(projection.get("upgrade_ladder", [])) \
			or not _end_gate_valid(projection.get("end_gate", {})):
		return false
	var serialized := JSON.stringify(projection)
	for forbidden in [
		"current_hidden_lead_player_id",
		"hidden_forward_order",
		"hidden_order",
		"hidden_order_fingerprint",
		"lead_player_id",
		"effective_influence_bp",
		"effective_weight",
		"weight_bp",
		"authority_contributions",
		"ordered_item_tokens",
		"next_private_stances",
		"rng_state",
		"rng_cursor",
		"save_payload",
		"save_state",
		"decision_samples",
		"learning_metadata",
		"600",
		"6%",
	]:
		if serialized.contains(forbidden):
			return false
	return true


static func _commodity_stacks(source_variant: Variant) -> Array:
	var source: Array = source_variant if source_variant is Array else []
	var result: Array = []
	for stack_variant in source:
		if not (stack_variant is Dictionary):
			continue
		var stack := stack_variant as Dictionary
		var normalized := {
			"group_id": str(stack.get("group_id", "")),
			"product_id": str(stack.get("product_id", "")),
			"color_id": str(stack.get("color_id", "")),
			"commodity_level": int(stack.get("commodity_level", 0)),
			"base_unit_count": int(stack.get("base_unit_count", 0)),
		}
		if CORE.commodity_stack_valid(normalized):
			result.append(normalized)
	return result


static func _revealed_stance_valid(stance: Dictionary) -> bool:
	return _has_exact_keys(stance, ["actor_id", "increase_color", "decrease_color"]) \
		and not str(stance.get("actor_id", "")).is_empty() \
		and CORE.COLOR_IDS.has(str(stance.get("increase_color", ""))) \
		and CORE.COLOR_IDS.has(str(stance.get("decrease_color", ""))) \
		and str(stance.get("increase_color", "")) != str(stance.get("decrease_color", ""))


static func _revealed_stances_valid(value_variant: Variant) -> bool:
	if not (value_variant is Array):
		return false
	for stance_variant in value_variant as Array:
		if not (stance_variant is Dictionary) or not _revealed_stance_valid(stance_variant as Dictionary):
			return false
	return true


static func _market_cycle_valid(value_variant: Variant) -> bool:
	if not (value_variant is Dictionary):
		return false
	var value := value_variant as Dictionary
	return _has_exact_keys(value, ["cycle_index", "remaining_seconds", "macro_round_index", "direction_label"]) \
		and typeof(value.get("cycle_index")) == TYPE_INT \
		and typeof(value.get("remaining_seconds")) == TYPE_FLOAT \
		and float(value.get("remaining_seconds", -1.0)) >= 0.0 \
		and int(value.get("macro_round_index", 0)) >= 1 \
		and ["正向大轮", "反向大轮"].has(str(value.get("direction_label", "")))


static func _supply_rows_valid(value_variant: Variant) -> bool:
	if not (value_variant is Array) or (value_variant as Array).size() != CORE.COLOR_IDS.size():
		return false
	var seen := {}
	for row_variant in value_variant as Array:
		if not (row_variant is Dictionary):
			return false
		var row := row_variant as Dictionary
		var color_id := str(row.get("color_id", ""))
		if not _has_exact_keys(row, ["color_id", "final_basis_points", "gdp_baseline_basis_points", "trend_basis_points"]) \
				or not CORE.COLOR_IDS.has(color_id) \
				or seen.has(color_id) \
				or typeof(row.get("final_basis_points")) != TYPE_INT \
				or typeof(row.get("gdp_baseline_basis_points")) != TYPE_INT \
				or typeof(row.get("trend_basis_points")) != TYPE_INT:
			return false
		seen[color_id] = true
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


static func _viewer_private_valid(value_variant: Variant) -> bool:
	if not (value_variant is Dictionary):
		return false
	var value := value_variant as Dictionary
	if not _has_exact_keys(value, ["local_track_segment", "next_stance", "stance_locked", "lead_notice_visible", "lead_notice_text"]) \
			or not _local_segment_valid(value.get("local_track_segment", [])) \
			or typeof(value.get("stance_locked")) != TYPE_BOOL \
			or typeof(value.get("lead_notice_visible")) != TYPE_BOOL:
		return false
	var stance: Dictionary = value.get("next_stance", {}) if value.get("next_stance", {}) is Dictionary else {}
	if not stance.is_empty() and (not _has_exact_keys(stance, ["increase_color", "decrease_color"]) \
			or not CORE.COLOR_IDS.has(str(stance.get("increase_color", ""))) \
			or not CORE.COLOR_IDS.has(str(stance.get("decrease_color", ""))) \
			or str(stance.get("increase_color", "")) == str(stance.get("decrease_color", ""))):
		return false
	return (bool(value.get("lead_notice_visible", false)) and not str(value.get("lead_notice_text", "")).is_empty()) \
		or (not bool(value.get("lead_notice_visible", false)) and str(value.get("lead_notice_text", "")).is_empty())


static func _inventory_capacity_valid(value_variant: Variant) -> bool:
	if not (value_variant is Dictionary):
		return false
	var value := value_variant as Dictionary
	var expected := [
		"normal_hand_count",
		"normal_hand_limit",
		"normal_hand_label",
		"normal_card_acquisition_allowed",
		"normal_status_reason",
		"commodity_slot_count",
		"commodity_slot_limit",
		"commodity_inventory_label",
		"commodity_acquisition_allowed",
		"commodity_status_reason",
		"commodity_stacks",
	]
	if not _has_exact_keys(value, expected):
		return false
	var stacks := _commodity_stacks(value.get("commodity_stacks", []))
	var normal_count := int(value.get("normal_hand_count", -1))
	var commodity_count := int(value.get("commodity_slot_count", -1))
	if stacks != value.get("commodity_stacks", []) \
			or normal_count < 0 or normal_count > CORE.NORMAL_CARD_HAND_LIMIT \
			or commodity_count != stacks.size() or commodity_count > CORE.COMMODITY_CARD_HAND_LIMIT \
			or int(value.get("normal_hand_limit", 0)) != CORE.NORMAL_CARD_HAND_LIMIT \
			or int(value.get("commodity_slot_limit", 0)) != CORE.COMMODITY_CARD_HAND_LIMIT:
		return false
	return str(value.get("normal_hand_label", "")) == "普通手牌：%d / %d" % [normal_count, CORE.NORMAL_CARD_HAND_LIMIT] \
		and str(value.get("commodity_inventory_label", "")) == "商品库存：%d / %d" % [commodity_count, CORE.COMMODITY_CARD_HAND_LIMIT] \
		and bool(value.get("normal_card_acquisition_allowed", false)) == (normal_count < CORE.NORMAL_CARD_HAND_LIMIT) \
		and bool(value.get("commodity_acquisition_allowed", false)) == (commodity_count < CORE.COMMODITY_CARD_HAND_LIMIT) \
		and str(value.get("normal_status_reason", "")) == ("normal_card_hand_full" if normal_count >= CORE.NORMAL_CARD_HAND_LIMIT else "normal_card_space_available") \
		and str(value.get("commodity_status_reason", "")) == ("commodity_inventory_full" if commodity_count >= CORE.COMMODITY_CARD_HAND_LIMIT else "commodity_space_available")


static func _upgrade_ladder_valid(value_variant: Variant) -> bool:
	return value_variant == [
		{"from_level": 1, "plus_level": 1, "to_level": 2, "base_unit_count": 2},
		{"from_level": 2, "plus_level": 1, "to_level": 3, "base_unit_count": 3},
		{"from_level": 3, "plus_level": 1, "to_level": 4, "base_unit_count": 4},
	]


static func _end_gate_valid(value_variant: Variant) -> bool:
	if not (value_variant is Dictionary):
		return false
	var value := value_variant as Dictionary
	if not _has_exact_keys(value, ["state", "message", "final_scoring_allowed"]):
		return false
	var state := str(value.get("state", ""))
	return ["running", "pending_macro_round_boundary", "final_validation_passed"].has(state) \
		and not str(value.get("message", "")).is_empty() \
		and typeof(value.get("final_scoring_allowed")) == TYPE_BOOL \
		and bool(value.get("final_scoring_allowed", false)) == (state == "final_validation_passed")


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(key_variant):
			return false
	return true
