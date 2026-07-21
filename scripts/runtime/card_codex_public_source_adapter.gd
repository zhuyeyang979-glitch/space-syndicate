extends RefCounted
class_name CardCodexPublicSourceAdapter

const SCHEMA_VERSION := 2
const FORBIDDEN_PRIVATE_KEYS := {
	"selected_player": true, "selected_district": true, "players": true, "player_index": true,
	"viewer_index": true, "actor_id": true, "cash": true, "cash_cents": true, "exact_cash": true,
	"hand": true, "private_hand": true, "discard": true, "private_discard": true,
	"owner": true, "owner_id": true, "owner_index": true, "true_owner": true, "hidden_owner": true,
	"city_guesses": true, "private_text": true, "developer": true, "developer_text": true,
	"developer_fields": true, "private_plan": true, "ai_plan": true, "ai_private_plan": true,
	"ai_score": true, "effect_payload": true, "raw_world": true, "world_bridge": true,
}
const FORBIDDEN_RETIRED_FIELDS := {
	"play_region_share_required": true, "city_share": true, "project_share": true, "project_gdp": true,
	"investment_unit": true, "route_hp": true,
	"route_damage": true, "repair_routes": true, "direct_cash": true, "direct_gdp": true,
	"direct_region_damage": true, "play_cash_cost": true,
}
const CARD_FACT_FIELDS := [
	"valid", "index", "card_name", "display_name", "icon", "family", "kind", "rank", "rank_label",
	"tag_text", "accent", "price", "purchase_cost_text", "play_cost_text", "category_label", "category_id",
	"industry_label", "icon_route_label", "subtype_label", "source_type_label", "supply_layer", "art_stats",
	"use_case", "strategy_route_label", "strategy_summary", "strategy_use_text", "quick_effect_compact",
	"quick_effect_full", "full_effect_text", "rules_text_compact", "level_gradient_text", "detail_tooltip",
	"face_route_text", "type_label", "requires_target", "requires_target_monster", "targets_player",
	"targets_monster", "target_text", "timing_text", "duration_text", "visibility_text", "play_requirement_text",
	"key_rule_facts", "read_chips", "resolution_animation_text",
]
const BROWSER_REQUEST_FIELDS := [
	"names", "columns", "rows", "page_index", "filter_id", "filter_label", "selected_card", "icon_legend",
	"run_pool_count", "district_supply_count", "filters",
]
const UPGRADE_FIELDS := [
	"roman", "price", "purchase_cost_text", "play_cost_text", "strength_band", "preview", "display_name",
	"full_effect_text", "accent", "fill_weight",
]

var _rejected_input_count := 0


func compose_card_facts(source: Dictionary) -> Dictionary:
	if not _accepts_public_input(source):
		_rejected_input_count += 1
		return {}
	return _allowlist_dictionary(source, CARD_FACT_FIELDS)


func compose_browser_source(request: Dictionary, cards: Array, preview_card: Dictionary, filters: Array) -> Dictionary:
	if not _accepts_public_input(request) or not _accepts_public_input(cards) or not _accepts_public_input(preview_card) or not _accepts_public_input(filters):
		_rejected_input_count += 1
		return {}
	var source := _allowlist_dictionary(request, BROWSER_REQUEST_FIELDS)
	source["schema_version"] = SCHEMA_VERSION
	source["names"] = _string_array(request.get("names", []))
	source["cards"] = cards.duplicate(true)
	source["preview_card"] = preview_card.duplicate(true)
	source["filters"] = filters.duplicate(true)
	return source


func compose_detail_source(card_facts: Dictionary, upgrades: Array, total: int) -> Dictionary:
	if not _accepts_public_input(card_facts) or not _accepts_public_input(upgrades):
		_rejected_input_count += 1
		return {}
	var source := _allowlist_dictionary(card_facts, CARD_FACT_FIELDS)
	source["schema_version"] = SCHEMA_VERSION
	source["total"] = maxi(1, total)
	var safe_upgrades: Array = []
	for upgrade_variant: Variant in upgrades:
		if upgrade_variant is Dictionary:
			safe_upgrades.append(_allowlist_dictionary(upgrade_variant as Dictionary, UPGRADE_FIELDS))
	source["upgrades"] = safe_upgrades
	return source


func accepts_public_input(value: Variant) -> bool:
	var accepted := _accepts_public_input(value)
	if not accepted:
		_rejected_input_count += 1
	return accepted


func public_field_schema() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"card_fact_fields": CARD_FACT_FIELDS.duplicate(),
		"browser_request_fields": BROWSER_REQUEST_FIELDS.duplicate(),
		"upgrade_fields": UPGRADE_FIELDS.duplicate(),
		"forbidden_private_keys": FORBIDDEN_PRIVATE_KEYS.keys(),
		"forbidden_retired_fields": FORBIDDEN_RETIRED_FIELDS.keys(),
	}


func debug_snapshot() -> Dictionary:
	return {
		"adapter_ready": true,
		"schema_version": SCHEMA_VERSION,
		"rejected_input_count": _rejected_input_count,
		"pure_data_only": true,
		"reads_runtime_nodes": false,
		"reads_world_bridge": false,
		"owns_rules": false,
		"owns_save_state": false,
	}


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
			if FORBIDDEN_PRIVATE_KEYS.has(key) or FORBIDDEN_RETIRED_FIELDS.has(key) or key.begins_with("private_") or key.begins_with("hidden_"):
				return false
			if not _accepts_public_input(value[key_variant]):
				return false
	elif value is Array:
		for item_variant: Variant in value:
			if not _accepts_public_input(item_variant):
				return false
	return true


func _duplicate_data(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item_variant: Variant in value:
			var item := str(item_variant).strip_edges()
			if item != "":
				result.append(item)
	return result
