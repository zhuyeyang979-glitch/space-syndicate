extends RefCounted
class_name RoleCodexPublicSourceAdapter

const ROLE_FIELDS := [
	"name", "species", "trait", "passive", "flavor", "starting_cash_bonus", "bonus_card_product",
	"resource_cash_product", "resource_cash_amount", "monster_upgrade_cash", "intel_city_reveal_charges",
	"city_guess_reward_bonus", "card_history_residual_catalog_charges",
	"card_history_public_exclusion_charges", "high_volatility_sale_threshold",
	"high_volatility_first_sale_bonus", "high_volatility_bonus_once_per_market_cycle",
	"monster_control_limit_bonus", "military_control_limit_bonus", "monster_cards_as_counter",
]
const FACE_FIELDS := ["name", "cost", "effect", "type", "rank", "card_kind", "card_stats", "accent", "minimum_width", "minimum_height"]
const FORBIDDEN_KEYS := {
	"player": true, "players": true, "player_index": true, "viewer": true, "viewer_index": true,
	"cash": true, "hand": true, "discard": true, "inventory": true, "owner": true, "hidden_owner": true,
	"city_guesses": true, "private_plan": true, "ai_plan": true, "ai_score": true, "monster_owner": true,
}

var _rejected_count := 0


func compose_source(role_definition: Dictionary, presentation: Dictionary, index: int, total: int) -> Dictionary:
	if not _is_public_value(role_definition) or not _is_public_value(presentation):
		_rejected_count += 1
		return {}
	if str(role_definition.get("name", "")).strip_edges() == "":
		return {}
	var role_card := _allowlist(role_definition, ROLE_FIELDS)
	var face_source := presentation.get("face", {}) as Dictionary if presentation.get("face", {}) is Dictionary else {}
	return {
		"role_card": role_card,
		"index": maxi(0, index),
		"total": maxi(1, total),
		"passive_text": str(role_card.get("passive", "暂无被动")),
		"starting_cash_delta": int(role_card.get("starting_cash_bonus", 0)),
		"accent": presentation.get("accent", Color("#38bdf8")) if presentation.get("accent", Color("#38bdf8")) is Color else Color("#38bdf8"),
		"kpi_columns": clampi(int(presentation.get("kpi_columns", 1)), 1, 4),
		"route_columns": clampi(int(presentation.get("route_columns", 1)), 1, 3),
		"face": _allowlist(face_source, FACE_FIELDS),
		"face_effect": str(presentation.get("face_effect", "")),
	}


func accepts_public_input(value: Variant) -> bool:
	var accepted := _is_public_value(value)
	if not accepted:
		_rejected_count += 1
	return accepted


func public_field_schema() -> Dictionary:
	return {"role_fields": ROLE_FIELDS.duplicate(), "face_fields": FACE_FIELDS.duplicate(), "forbidden_keys": FORBIDDEN_KEYS.keys()}


func debug_snapshot() -> Dictionary:
	return {"adapter_ready": true, "rejected_count": _rejected_count, "pure_data_only": true, "reads_player_state": false, "reads_private_world": false}


func _allowlist(source: Dictionary, fields: Array) -> Dictionary:
	var result := {}
	for field_variant: Variant in fields:
		var field := str(field_variant)
		if source.has(field):
			result[field] = source[field].duplicate(true) if source[field] is Dictionary or source[field] is Array else source[field]
	return result


func _is_public_value(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant: Variant in value:
			var key := str(key_variant).to_lower()
			if FORBIDDEN_KEYS.has(key) or key.begins_with("private_") or key.begins_with("hidden_"):
				return false
			if not _is_public_value(value[key_variant]):
				return false
	elif value is Array:
		for item_variant: Variant in value:
			if not _is_public_value(item_variant):
				return false
	return true
