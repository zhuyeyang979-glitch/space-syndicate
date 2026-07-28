@tool
extends RefCounted
class_name CardBatchInventoryStateV1

const PURE = preload("res://scripts/semantic/card_batch_pure_data.gd")

const SCHEMA_VERSION := 1
const NORMAL_CARD_HAND_LIMIT := 5
const COMMODITY_CARD_HAND_LIMIT := 5
const BOUND_ACTION_CAPACITY_COST := 0
const BOUND_ACTION_KINDS := ["batch_action", "passive_source_ability"]
const FIELDS: Array[String] = [
	"schema_version", "actor_id", "normal_hand_limit", "commodity_inventory_limit",
	"normal_cards", "commodity_cards", "bound_actions",
]


static func empty(actor_id: String) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"actor_id": actor_id,
		"normal_hand_limit": NORMAL_CARD_HAND_LIMIT,
		"commodity_inventory_limit": COMMODITY_CARD_HAND_LIMIT,
		"normal_cards": [],
		"commodity_cards": [],
		"bound_actions": [],
	}


static func add_normal_card(state: Dictionary, card: Dictionary) -> Dictionary:
	var validation := validate(state)
	if not bool(validation.get("valid", false)):
		return _rejected(str(validation.get("reason_code", "inventory_invalid")), state)
	if not _valid_card_item(card):
		return _rejected("normal_card_invalid", state)
	var result: Dictionary = validation.get("normalized", {})
	var cards: Array = result.get("normal_cards", [])
	if cards.size() >= NORMAL_CARD_HAND_LIMIT:
		return _rejected("normal_hand_full", state)
	if _contains_item_id(cards, str(card.get("card_instance_id", ""))):
		return _rejected("normal_card_duplicate", state)
	cards.append(card.duplicate(true))
	result["normal_cards"] = cards
	return _committed(result)


static func add_commodity_card(state: Dictionary, card: Dictionary) -> Dictionary:
	var validation := validate(state)
	if not bool(validation.get("valid", false)):
		return _rejected(str(validation.get("reason_code", "inventory_invalid")), state)
	if not _valid_commodity_item(card):
		return _rejected("commodity_card_invalid", state)
	var result: Dictionary = validation.get("normalized", {})
	var cards: Array = result.get("commodity_cards", [])
	if cards.size() >= COMMODITY_CARD_HAND_LIMIT:
		return _rejected("commodity_inventory_full", state)
	if _contains_item_id(cards, str(card.get("card_instance_id", ""))):
		return _rejected("commodity_card_duplicate", state)
	cards.append(card.duplicate(true))
	result["commodity_cards"] = cards
	return _committed(result)


static func grant_bound_action(state: Dictionary, action: Dictionary) -> Dictionary:
	var validation := validate(state)
	if not bool(validation.get("valid", false)):
		return _rejected(str(validation.get("reason_code", "inventory_invalid")), state)
	if not _valid_bound_action(action):
		return _rejected("bound_action_invalid", state)
	var result: Dictionary = validation.get("normalized", {})
	var actions: Array = result.get("bound_actions", [])
	var action_id := str(action.get("bound_action_id", ""))
	if _contains_bound_id(actions, action_id):
		return _rejected("bound_action_duplicate", state)
	actions.append(action.duplicate(true))
	actions.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return _bound_sort_key(left) < _bound_sort_key(right))
	result["bound_actions"] = actions
	return _committed(result)


static func revoke_source(state: Dictionary, source_kind: String, source_id: String) -> Dictionary:
	var validation := validate(state)
	if not bool(validation.get("valid", false)):
		return _rejected(str(validation.get("reason_code", "inventory_invalid")), state)
	var result: Dictionary = validation.get("normalized", {})
	var kept: Array = []
	for action_variant in result.get("bound_actions", []) as Array:
		var action := action_variant as Dictionary
		if str(action.get("source_kind", "")) == source_kind and str(action.get("source_id", "")) == source_id:
			continue
		kept.append(action.duplicate(true))
	result["bound_actions"] = kept
	return _committed(result)


static func validate(value: Dictionary) -> Dictionary:
	if not PURE.has_exact_keys(value, FIELDS) or int(value.get("schema_version", -1)) != SCHEMA_VERSION:
		return _invalid("card_batch_inventory_schema_invalid")
	if not PURE.is_pure_json_data(value) or str(value.get("actor_id", "")).is_empty():
		return _invalid("card_batch_inventory_not_pure_data")
	if int(value.get("normal_hand_limit", -1)) != NORMAL_CARD_HAND_LIMIT or int(value.get("commodity_inventory_limit", -1)) != COMMODITY_CARD_HAND_LIMIT:
		return _invalid("card_batch_inventory_limits_invalid")
	for key in ["normal_cards", "commodity_cards", "bound_actions"]:
		if not (value.get(key) is Array):
			return _invalid("card_batch_inventory_array_invalid")
	var normals: Array = value.get("normal_cards", [])
	var commodities: Array = value.get("commodity_cards", [])
	var bounds: Array = value.get("bound_actions", [])
	if normals.size() > NORMAL_CARD_HAND_LIMIT:
		return _invalid("normal_hand_overflow")
	if commodities.size() > COMMODITY_CARD_HAND_LIMIT:
		return _invalid("commodity_inventory_overflow")
	var seen_normal: Array[String] = []
	for item_variant in normals:
		if not (item_variant is Dictionary) or not _valid_card_item(item_variant as Dictionary):
			return _invalid("normal_card_invalid")
		var item_id := str((item_variant as Dictionary).get("card_instance_id", ""))
		if item_id in seen_normal:
			return _invalid("normal_card_duplicate")
		seen_normal.append(item_id)
	var seen_commodity: Array[String] = []
	for item_variant in commodities:
		if not (item_variant is Dictionary) or not _valid_commodity_item(item_variant as Dictionary):
			return _invalid("commodity_card_invalid")
		var item_id := str((item_variant as Dictionary).get("card_instance_id", ""))
		if item_id in seen_commodity:
			return _invalid("commodity_card_duplicate")
		seen_commodity.append(item_id)
	var seen_bound: Array[String] = []
	for item_variant in bounds:
		if not (item_variant is Dictionary) or not _valid_bound_action(item_variant as Dictionary):
			return _invalid("bound_action_invalid")
		var item_id := str((item_variant as Dictionary).get("bound_action_id", ""))
		if item_id in seen_bound:
			return _invalid("bound_action_duplicate")
		seen_bound.append(item_id)
	return {"valid": true, "reason_code": "card_batch_inventory_valid", "normalized": value.duplicate(true)}


static func capacity_snapshot(value: Dictionary) -> Dictionary:
	var validation := validate(value)
	if not bool(validation.get("valid", false)):
		return {}
	var normalized: Dictionary = validation.get("normalized", {})
	return {
		"normal_card_count": (normalized.get("normal_cards", []) as Array).size(),
		"normal_hand_limit": NORMAL_CARD_HAND_LIMIT,
		"commodity_card_count": (normalized.get("commodity_cards", []) as Array).size(),
		"commodity_inventory_limit": COMMODITY_CARD_HAND_LIMIT,
		"bound_action_count": (normalized.get("bound_actions", []) as Array).size(),
		"bound_action_capacity_cost": BOUND_ACTION_CAPACITY_COST,
	}


static func _valid_card_item(card: Dictionary) -> bool:
	return PURE.is_pure_json_data(card) \
		and str(card.get("card_instance_id", "")) != "" \
		and str(card.get("card_semantic_id", "")) != ""


static func _valid_commodity_item(card: Dictionary) -> bool:
	return _valid_card_item(card) \
		and str(card.get("commodity_id", "")) != "" \
		and int(card.get("commodity_level", 0)) in [1, 2, 3, 4]


static func _valid_bound_action(action: Dictionary) -> bool:
	return PURE.is_pure_json_data(action) \
		and str(action.get("bound_action_id", "")) != "" \
		and str(action.get("card_semantic_id", "")) != "" \
		and str(action.get("action_kind", "")) in BOUND_ACTION_KINDS \
		and str(action.get("source_kind", "")) in ["monster", "military"] \
		and str(action.get("source_id", "")) != "" \
		and int(action.get("source_revision", -1)) >= 0 \
		and int(action.get("cooldown_remaining_phase_time_usec", -1)) >= 0 \
		and int(action.get("charges", -1)) >= 0


static func _contains_item_id(items: Array, item_id: String) -> bool:
	for item_variant in items:
		if item_variant is Dictionary and str((item_variant as Dictionary).get("card_instance_id", "")) == item_id:
			return true
	return false


static func _contains_bound_id(items: Array, item_id: String) -> bool:
	for item_variant in items:
		if item_variant is Dictionary and str((item_variant as Dictionary).get("bound_action_id", "")) == item_id:
			return true
	return false


static func _bound_sort_key(action: Dictionary) -> String:
	return "%s|%s|%s" % [str(action.get("source_kind", "")), str(action.get("source_id", "")), str(action.get("bound_action_id", ""))]


static func _committed(state: Dictionary) -> Dictionary:
	return {"committed": true, "reason_code": "inventory_committed", "state": state.duplicate(true)}


static func _rejected(reason_code: String, state: Dictionary) -> Dictionary:
	return {"committed": false, "reason_code": reason_code, "state": state.duplicate(true)}


static func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code, "normalized": {}}
