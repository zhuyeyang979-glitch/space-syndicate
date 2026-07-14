extends RefCounted
class_name RegionCodexPublicSourceAdapter

const SCHEMA_VERSION := 1
const REGION_CONTRACT := "region_codex_public_facts_v06"
const MONSTER_CONTRACT := "monster_region_public_attraction_v06"
const REGION_FIELDS := [
	"available", "card_ids", "city", "contract_version", "demands", "destroyed", "economic_focus_label",
	"hp_now", "hp_total", "index", "name", "neighbor_indices", "products", "public_clue", "reason_code",
	"region_id", "terrain", "terrain_label", "total",
]
const CITY_FIELDS := ["active", "last_income", "level", "present"]
const MONSTER_FIELDS := ["available", "contract_version", "entries", "reason_code", "region_index"]
const MONSTER_ENTRY_FIELDS := ["factor_codes", "name", "ordinal", "reason"]
const MONSTER_FACTOR_CODES := ["distance", "city", "competition", "warehouse", "resource", "miasma", "other_monster"]
const FORBIDDEN_PRIVATE_KEYS := {
	"viewer": true, "viewer_index": true, "selected": true, "selected_player": true, "selected_district": true,
	"player": true, "players": true, "player_index": true, "actor_id": true, "raw_actor": true,
	"city_guesses": true, "cash": true, "exact_cash": true, "cash_cents": true, "hand": true,
	"discard": true, "owner": true, "owner_id": true, "owner_index": true, "owner_player_index": true,
	"owner_actor_id": true, "hidden_owner": true, "true_owner": true, "owner_truth": true,
	"private": true, "private_text": true, "private_clue": true, "private_plan": true,
	"ai_plan": true, "ai_private_plan": true, "ai_route_plan": true, "ai_score": true, "target_plan": true,
	"plan": true, "score": true, "target": true, "actual_target": true, "target_score": true,
	"developer": true, "developer_text": true, "developer_fields": true, "observer_intent": true,
	"observer_intents": true, "facilities": true, "facility_owner": true, "warehouses": true,
	"warehouse_inventory": true,
}
const FORBIDDEN_VALUE_MARKERS := [
	"private_sentinel", "private-sentinel", "secret_sentinel", "secret-sentinel", "do_not_leak", "do-not-leak",
	"cash_sentinel", "hand_sentinel", "discard_sentinel", "owner_sentinel", "ai_plan_sentinel",
]

var _compose_count := 0
var _rejected_count := 0


func compose_source(region_facts: Dictionary, monster_facts: Dictionary, weather_text: String, route_load: int) -> Dictionary:
	if not _accepts_public_input(region_facts) or not _accepts_public_input(monster_facts) or not _accepts_public_input(weather_text):
		_rejected_count += 1
		return {}
	if not _valid_region_facts(region_facts) or not _valid_monster_facts(monster_facts) or route_load < 0:
		_rejected_count += 1
		return {}
	_compose_count += 1
	if not bool(region_facts.get("available", false)):
		return {"valid": false, "index": int(region_facts.get("index", -1)), "total": maxi(0, int(region_facts.get("total", 0)))}
	var city := region_facts.get("city", {}) as Dictionary
	var products := _string_array(region_facts.get("products", []))
	var demands := _string_array(region_facts.get("demands", []))
	var card_ids := _string_array(region_facts.get("card_ids", []))
	var neighbors := _index_array(region_facts.get("neighbor_indices", []))
	var monster_entries: Array = []
	for entry_variant: Variant in monster_facts.get("entries", []) as Array:
		var entry := entry_variant as Dictionary
		monster_entries.append({
			"ordinal": int(entry.get("ordinal", 0)),
			"name": str(entry.get("name", "怪兽")),
			"factor_codes": _string_array(entry.get("factor_codes", [])),
			"reason": str(entry.get("reason", "")),
		})
	return {
		"valid": true,
		"index": int(region_facts.get("index", 0)),
		"total": maxi(1, int(region_facts.get("total", 1))),
		"name": str(region_facts.get("name", "区域")),
		"terrain": str(region_facts.get("terrain", "land")),
		"terrain_label": str(region_facts.get("terrain_label", "区域")),
		"economic_focus_label": str(region_facts.get("economic_focus_label", "均衡")),
		"destroyed": bool(region_facts.get("destroyed", false)),
		"hp_total": maxi(0, int(region_facts.get("hp_total", 0))),
		"hp_now": maxi(0, int(region_facts.get("hp_now", 0))),
		"trade_route_load": route_load,
		"card_count": card_ids.size(),
		"city_present": bool(city.get("present", false)),
		"city_active": bool(city.get("active", false)),
		"city_level": maxi(0, int(city.get("level", 0))),
		"city_last_income": maxi(0, int(city.get("last_income", 0))),
		"supply_text": _limited_names(products, 3, "无"),
		"demand_text": _limited_names(demands, 3, "无"),
		"weather_text": weather_text if not weather_text.is_empty() else "暂无",
		"connection_summary": "邻接%d区" % neighbors.size(),
		"card_choice_summary": _limited_names(card_ids, 4, "无"),
		"monster_entries": monster_entries,
		"public_clue": str(region_facts.get("public_clue", "暂无公开线索")),
		"card_names": card_ids,
		"route_flow_status": "暂无",
		"contract_status": "暂无",
		"gdp_trend": "暂无",
		"income_detail_lines": [],
		"products": products,
	}


func accepts_public_input(value: Variant) -> bool:
	var accepted := _accepts_public_input(value)
	if not accepted:
		_rejected_count += 1
	return accepted


func public_field_schema() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"region_contract": REGION_CONTRACT,
		"monster_contract": MONSTER_CONTRACT,
		"region_fields": REGION_FIELDS.duplicate(),
		"city_fields": CITY_FIELDS.duplicate(),
		"monster_fields": MONSTER_FIELDS.duplicate(),
		"monster_entry_fields": MONSTER_ENTRY_FIELDS.duplicate(),
		"monster_factor_codes": MONSTER_FACTOR_CODES.duplicate(),
		"forbidden_private_keys": FORBIDDEN_PRIVATE_KEYS.keys(),
	}


func debug_snapshot() -> Dictionary:
	return {
		"adapter_ready": true,
		"schema_version": SCHEMA_VERSION,
		"compose_count": _compose_count,
		"rejected_count": _rejected_count,
		"pure_data_only": true,
		"reads_runtime_nodes": false,
		"reads_world_bridge": false,
		"owns_rules": false,
		"owns_save_state": false,
		"has_save_api": false,
	}


func _valid_region_facts(value: Dictionary) -> bool:
	if not _keys_exact(value, REGION_FIELDS) or str(value.get("contract_version", "")) != REGION_CONTRACT:
		return false
	if not (value.get("city", {}) is Dictionary) or not _keys_exact(value.get("city", {}) as Dictionary, CITY_FIELDS):
		return false
	return _is_string_array(value.get("products", [])) and _is_string_array(value.get("demands", [])) and _is_string_array(value.get("card_ids", [])) and _is_index_array(value.get("neighbor_indices", []))


func _valid_monster_facts(value: Dictionary) -> bool:
	if not _keys_exact(value, MONSTER_FIELDS) or str(value.get("contract_version", "")) != MONSTER_CONTRACT:
		return false
	if int(value.get("region_index", -1)) < 0 or not (value.get("entries", []) is Array):
		return false
	for entry_variant: Variant in value.get("entries", []) as Array:
		if not (entry_variant is Dictionary):
			return false
		var entry := entry_variant as Dictionary
		if not _keys_exact(entry, MONSTER_ENTRY_FIELDS) or int(entry.get("ordinal", 0)) <= 0 or not _is_string_array(entry.get("factor_codes", [])):
			return false
		var codes := _string_array(entry.get("factor_codes", []))
		if codes.size() > 3:
			return false
		for code_variant: Variant in codes:
			if not MONSTER_FACTOR_CODES.has(str(code_variant)):
				return false
		if not _public_monster_reason(str(entry.get("reason", ""))):
			return false
	return true


func _public_monster_reason(reason: String) -> bool:
	if reason.is_empty():
		return false
	var lowered := reason.to_lower()
	for forbidden in ["权重", "%", "+", "numerator", "total", "概率", "rng", "target", "lure", "uid", "owner", "fingerprint", "binding", "private"]:
		if lowered.contains(str(forbidden).to_lower()):
			return false
	for character in reason:
		if str(character).is_valid_int():
			return false
	return true


func _keys_exact(value: Dictionary, expected: Array) -> bool:
	var keys := value.keys()
	keys.sort()
	var fields := expected.duplicate()
	fields.sort()
	return keys == fields


func _accepts_public_input(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is String or value is StringName:
		var lowered_value := str(value).to_lower()
		for marker in FORBIDDEN_VALUE_MARKERS:
			if lowered_value.contains(marker):
				return false
		return true
	if value is Dictionary:
		for key_variant: Variant in value:
			var key := str(key_variant).to_lower()
			if FORBIDDEN_PRIVATE_KEYS.has(key) or key.begins_with("private_") or key.begins_with("hidden_") or key.begins_with("ai_") or key.ends_with("_owner") or key.ends_with("_plan") or key.ends_with("_score"):
				return false
			if not _accepts_public_input(value[key_variant]):
				return false
	elif value is Array:
		for entry_variant: Variant in value:
			if not _accepts_public_input(entry_variant):
				return false
	return true


func _is_string_array(value: Variant) -> bool:
	if not (value is Array):
		return false
	for entry_variant: Variant in value as Array:
		if not (entry_variant is String or entry_variant is StringName):
			return false
	return true


func _is_index_array(value: Variant) -> bool:
	if not (value is Array):
		return false
	for entry_variant: Variant in value as Array:
		if not (entry_variant is int) or int(entry_variant) < 0:
			return false
	return true


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for entry_variant: Variant in value as Array:
		result.append(str(entry_variant))
	return result


func _index_array(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for entry_variant: Variant in value as Array:
		result.append(int(entry_variant))
	return result


func _limited_names(values: Array, limit: int, empty_text: String) -> String:
	if values.is_empty():
		return empty_text
	var pieces: Array[String] = []
	for index in range(mini(maxi(1, limit), values.size())):
		pieces.append(str(values[index]))
	if values.size() > limit:
		pieces.append("另有公开条目")
	return "、".join(pieces)
