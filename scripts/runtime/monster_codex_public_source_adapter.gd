extends RefCounted
class_name MonsterCodexPublicSourceAdapter

const SCHEMA_VERSION := 1
const FORBIDDEN_PRIVATE_KEYS := {
	"viewer": true,
	"viewer_index": true,
	"selected_player": true,
	"selected_district": true,
	"players": true,
	"player": true,
	"player_index": true,
	"cash": true,
	"cash_cents": true,
	"exact_cash": true,
	"hand": true,
	"private_hand": true,
	"discard": true,
	"private_discard": true,
	"owner": true,
	"owner_id": true,
	"owner_index": true,
	"owner_player_index": true,
	"owner_actor": true,
	"true_owner": true,
	"hidden_owner": true,
	"hidden_owner_id": true,
	"owner_truth": true,
	"city_guesses": true,
	"private_text": true,
	"developer_text": true,
	"developer_fields": true,
	"private_plan": true,
	"ai_plan": true,
	"ai_private_plan": true,
	"ai_route_plan": true,
	"ai_score": true,
	"target_plan": true,
	"target_index": true,
	"target_weight": true,
	"target_weights": true,
	"rng": true,
	"rng_state": true,
	"random_seed": true,
	"roster": true,
	"auto_monsters": true,
	"world_bridge": true,
	"quote": true,
	"quote_id": true,
	"quote_fingerprint": true,
	"market_quote": true,
	"camera": true,
	"view_center": true,
	"view_zoom": true,
	"save_data": true,
}
const FORBIDDEN_VALUE_SENTINELS := [
	"private",
	"hidden_owner",
	"owner_truth",
	"exact_cash",
	"opponent_hand",
	"ai_private",
	"ai_plan",
	"target_weight",
	"rng_state",
	"market_quote",
]
const TOP_LEVEL_FIELDS := [
	"schema_version", "contract_version", "valid", "index", "total", "selected", "entry", "ecology",
	"profile", "accent", "move_text", "art_move_text", "ecology_move_text", "max_range_text",
	"encounter_range_text", "mobility_summary", "action_summary", "rank_iv_probability_summary", "actions",
	"monster_card", "monster_card_link", "level_labels",
]
const ENTRY_FIELDS := [
	"name", "style", "hp", "armor", "move", "resource_focus", "movement_traits",
	"terrain_move_multiplier", "summon_access",
]
const ECOLOGY_FIELDS := [
	"movement_archetype", "movement_traits", "terrain_move_multiplier", "role_tags",
	"bound_skill_counts", "summon_access", "resource_drain", "max_damage", "max_range", "move",
	"economy_boon", "rank_iv_probability_shift",
]
const ECOLOGY_BOON_FIELDS := ["label", "text"]
const PROFILE_FIELDS := ["accent", "secondary", "glyph", "motif", "subtitle", "sprite_key", "sprite_cell", "visual_source_id"]
const ACTION_FIELDS := [
	"name", "text", "tags", "facts", "i_open", "i_destroyed", "iv_open", "iv_destroyed",
	"probability_tooltip",
]
const MONSTER_CARD_FIELDS := ["valid", "card_name", "display_name", "price", "region_text"]
const MONSTER_CARD_LINK_FIELDS := ["visible", "card_name", "label", "button_text", "tooltip"]

var _source_compose_count := 0
var _rejected_private_input_count := 0


func compose_source(source: Dictionary) -> Dictionary:
	if not _accepts_public_input(source):
		_rejected_private_input_count += 1
		return {}
	var result := _allowlist_dictionary(source, TOP_LEVEL_FIELDS)
	result["schema_version"] = SCHEMA_VERSION
	var entry_source := source.get("entry", {}) as Dictionary if source.get("entry", {}) is Dictionary else {}
	result["entry"] = _allowlist_dictionary(entry_source, ENTRY_FIELDS)
	result["ecology"] = _allowlist_ecology(source.get("ecology", {}))
	var profile_source := source.get("profile", {}) as Dictionary if source.get("profile", {}) is Dictionary else {}
	result["profile"] = _allowlist_dictionary(profile_source, PROFILE_FIELDS)
	result["actions"] = _allowlist_actions(source.get("actions", []))
	var monster_card_source := source.get("monster_card", {}) as Dictionary if source.get("monster_card", {}) is Dictionary else {}
	result["monster_card"] = _allowlist_dictionary(monster_card_source, MONSTER_CARD_FIELDS)
	var monster_card_link_source := source.get("monster_card_link", {}) as Dictionary if source.get("monster_card_link", {}) is Dictionary else {}
	result["monster_card_link"] = _allowlist_dictionary(monster_card_link_source, MONSTER_CARD_LINK_FIELDS)
	result["level_labels"] = _string_array(source.get("level_labels", []), 4)
	_source_compose_count += 1
	return result


func accepts_public_input(value: Variant) -> bool:
	var accepted := _accepts_public_input(value)
	if not accepted:
		_rejected_private_input_count += 1
	return accepted


func public_field_schema() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"top_level_fields": TOP_LEVEL_FIELDS.duplicate(),
		"entry_fields": ENTRY_FIELDS.duplicate(),
		"ecology_fields": ECOLOGY_FIELDS.duplicate(),
		"profile_fields": PROFILE_FIELDS.duplicate(),
		"action_fields": ACTION_FIELDS.duplicate(),
		"monster_card_fields": MONSTER_CARD_FIELDS.duplicate(),
		"monster_card_link_fields": MONSTER_CARD_LINK_FIELDS.duplicate(),
		"forbidden_private_keys": FORBIDDEN_PRIVATE_KEYS.keys(),
	}


func debug_snapshot() -> Dictionary:
	return {
		"adapter_ready": true,
		"schema_version": SCHEMA_VERSION,
		"source_compose_count": _source_compose_count,
		"rejected_private_input_count": _rejected_private_input_count,
		"pure_data_only": true,
		"reads_runtime_nodes": false,
		"reads_world_bridge": false,
		"owns_rules": false,
		"owns_save_state": false,
		"has_save_api": false,
	}


func _allowlist_ecology(value: Variant) -> Dictionary:
	var source := value as Dictionary if value is Dictionary else {}
	var result := _allowlist_dictionary(source, ECOLOGY_FIELDS)
	if source.get("economy_boon", {}) is Dictionary:
		result["economy_boon"] = _allowlist_dictionary(source.get("economy_boon", {}) as Dictionary, ECOLOGY_BOON_FIELDS)
	return result


func _allowlist_actions(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for entry_variant: Variant in value:
		if entry_variant is Dictionary:
			result.append(_allowlist_dictionary(entry_variant as Dictionary, ACTION_FIELDS))
	return result


func _allowlist_dictionary(source: Dictionary, fields: Array) -> Dictionary:
	var result := {}
	for field_variant: Variant in fields:
		var field := str(field_variant)
		if source.has(field):
			result[field] = _duplicate_data(source[field])
	return result


func _accepts_public_input(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant: Variant in value:
			var key := str(key_variant).to_lower()
			if FORBIDDEN_PRIVATE_KEYS.has(key) or key.begins_with("private_") or key.begins_with("hidden_"):
				return false
			if not _accepts_public_input(value[key_variant]):
				return false
	elif value is Array:
		for entry_variant: Variant in value:
			if not _accepts_public_input(entry_variant):
				return false
	elif value is String or value is StringName:
		var text := str(value).to_lower()
		for sentinel_variant: Variant in FORBIDDEN_VALUE_SENTINELS:
			if text.contains(str(sentinel_variant).to_lower()):
				return false
	return true


func _duplicate_data(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value


func _string_array(value: Variant, limit: int) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for entry_variant: Variant in value:
		var entry := str(entry_variant)
		if entry != "":
			result.append(entry)
		if result.size() >= limit:
			break
	return result
