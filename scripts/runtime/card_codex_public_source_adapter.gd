extends RefCounted
class_name CardCodexPublicSourceAdapter

const PlayerCardCodexDTO := preload(
	"res://scripts/presentation/player_card_codex_dto_v1.gd"
)
const PlayerCardCodexFamilyLadderDTO := preload(
	"res://scripts/presentation/player_card_codex_family_ladder_dto_v1.gd"
)
const TOKEN_MANIFEST := preload(
	"res://scripts/presentation/card_player_face_public_token_manifest_v1.gd"
)

const SCHEMA_VERSION := 3
const RANK_LABEL_BY_RANK := TOKEN_MANIFEST.RANK_LABEL_BY_RANK

const FORBIDDEN_INPUT_KEYS := {
	"selected_player": true, "selected_district": true, "players": true,
	"player_index": true, "viewer_index": true, "actor_id": true,
	"cash": true, "cash_cents": true, "exact_cash": true,
	"hand": true, "private_hand": true, "rival_hand": true,
	"opponent_hand": true, "discard": true, "private_discard": true,
	"owner": true, "owner_id": true, "owner_index": true,
	"true_owner": true, "hidden_owner": true, "city_guesses": true,
	"private_text": true, "private_plan": true, "ai_plan": true,
	"ai_private_plan": true, "ai_score": true, "ai_value": true,
	"route_plan": true, "future_bag": true, "rng_state": true,
	"save_payload": true, "raw_world": true, "world_bridge": true,
	"machine": true, "player": true, "developer": true,
	"developer_text": true, "developer_fields": true,
	"effect_payload": true, "effect_kind": true, "target_kind": true,
	"skill": true, "method_name": true, "script_path": true,
}
const FORBIDDEN_RETIRED_FIELDS := {
	"cost": true, "price": true, "play_cost": true,
	"description": true,
	"play_region_share_required": true, "city_share": true,
	"project_share": true, "project_gdp": true, "investment_unit": true,
	"route_hp": true, "route_damage": true, "repair_routes": true,
	"direct_cash": true, "direct_gdp": true,
	"direct_region_damage": true, "play_cash_cost": true,
}

const CARD_FACT_FIELDS := [
	"valid",
	"index",
	"card_name",
	"display_name",
	"family_id",
	"family_name",
	"rank",
	"rank_label",
	"category_id",
	"category_label",
	"industry_id",
	"industry_label",
	"icon",
	"accent",
	"illustration_key",
	"acquisition_cash",
	"acquisition_cost_text",
	"activation_cost_text",
	"timing_text",
	"target_text",
	"condition_texts",
	"effect_step_texts",
	"duration_text",
	"counterability_text",
	"information_scope_text",
	"keyword_chips",
	"short_effect_text",
	"full_effect_text",
	"semantic_fingerprint",
	"dto_fingerprint",
	"family_ladder",
	"facts_fingerprint",
]
const BROWSER_REQUEST_FIELDS := [
	"names",
	"columns",
	"rows",
	"page_index",
	"filter_id",
	"filter_label",
	"selected_card",
	"icon_legend",
	"run_pool_count",
	"district_supply_count",
	"filters",
]
const FILTER_FIELDS := [
	"id", "label", "short_label", "icon", "count", "active", "disabled", "accent",
]
const UPGRADE_FIELDS := [
	"card_id",
	"family_id",
	"rank",
	"rank_label",
	"display_name",
	"acquisition_cost_text",
	"activation_cost_text",
	"target_text",
	"effect_step_texts",
	"duration_text",
	"accent",
	"illustration_key",
	"full_effect_text",
]

# These names exist only at the final legacy UI boundary. New Codex code must use
# the canonical field named by replacement and must not add entries here.
const COMPATIBILITY_ALIAS_RETIREMENT := {
	"card_name": {
		"replacement": "card_id",
		"consumer": "scripts/ui/card_codex_browser.gd signal payload",
		"remove_when": "Codex UI signals carry card_id",
	},
	"kind": {
		"replacement": "category_id",
		"consumer": "scripts/ui/codex/card_codex_thumbnail_card.gd fallback art",
		"remove_when": "thumbnail fallback art accepts presentation tokens",
	},
	"route": {
		"replacement": "category_label + industry_label",
		"consumer": "scripts/ui/codex/card_codex_thumbnail_card.gd",
		"remove_when": "thumbnail accepts taxonomy presentation",
	},
	"effect": {
		"replacement": "short_effect_text or full_effect_text",
		"consumer": "thumbnail and CardFace compatibility inputs",
		"remove_when": "Codex UI accepts named effect presentation fields",
	},
	"cost": {
		"replacement": "acquisition_cost_text + activation_cost_text",
		"consumer": "scripts/CardUI.gd CardFace input",
		"remove_when": "CardFace accepts separated costs",
	},
	"type": {
		"replacement": "category_label + industry_label",
		"consumer": "scripts/CardUI.gd CardFace input",
		"remove_when": "CardFace accepts taxonomy presentation",
	},
	"rank": {
		"replacement": "rank_number + rank_label",
		"consumer": "thumbnail and CardFace compatibility inputs",
		"remove_when": "Codex UI accepts separated rank fields",
	},
	"roman": {
		"replacement": "rank + rank_label",
		"consumer": "scripts/ui/card_codex_detail.gd upgrade ladder",
		"remove_when": "upgrade ladder accepts numeric rank",
	},
	"price": {
		"replacement": "acquisition_cost_text",
		"consumer": "scripts/ui/card_codex_detail.gd upgrade ladder",
		"remove_when": "upgrade ladder accepts separated costs",
	},
}
const TOKEN_RESOLUTION_RETIREMENT := {
	"source_owner": "card_player_face_public_localization_source_service",
	"accepted_input": "stable presentation token IDs only",
	"remove_when": "Codex UI consumes the authorized presentation token manifest directly",
}

var _rejected_input_count := 0
var _dto_compose_count := 0


func compose_card_facts(
	codex_dto: Dictionary,
	card_index: int = -1,
	ladder_dto: Dictionary = {}
) -> Dictionary:
	if not bool(PlayerCardCodexDTO.validate(codex_dto).get("valid", false)):
		_rejected_input_count += 1
		return {}
	if not ladder_dto.is_empty():
		if not bool(PlayerCardCodexFamilyLadderDTO.validate(ladder_dto).get("valid", false)):
			_rejected_input_count += 1
			return {}
	return _compose_card_facts(codex_dto, card_index, ladder_dto)


# CardCodexPublicSourceService calls this only while sealing its startup cache,
# immediately after both DTO schemas have accepted the inputs.
func compose_catalog_owned_card_facts(
	codex_dto: Dictionary,
	card_index: int,
	ladder_dto: Dictionary
) -> Dictionary:
	if str(codex_dto.get("dto_fingerprint", "")).length() != 64 \
			or str(ladder_dto.get("ladder_fingerprint", "")).length() != 64:
		_rejected_input_count += 1
		return {}
	return _compose_card_facts(codex_dto, card_index, ladder_dto)


func compose_catalog_owned_upgrade_facts(ladder_dto: Dictionary) -> Array:
	if str(ladder_dto.get("ladder_fingerprint", "")).length() != 64:
		_rejected_input_count += 1
		return []
	return _upgrade_rows(ladder_dto)


func _compose_card_facts(
	codex_dto: Dictionary,
	card_index: int,
	ladder_dto: Dictionary
) -> Dictionary:

	var detail_face := codex_dto.get("detail_face", {}) as Dictionary
	var taxonomy := codex_dto.get("taxonomy", {}) as Dictionary
	var tokens := codex_dto.get("presentation_tokens", {}) as Dictionary
	var copy := codex_dto.get("presentation_copy", {}) as Dictionary
	var family_id := str(detail_face.get("family_id", ""))
	var card_id := str(detail_face.get("card_id", ""))
	if not ladder_dto.is_empty():
		if str(ladder_dto.get("family_id", "")) != family_id \
				or not _ladder_contains_card(ladder_dto, card_id):
			_rejected_input_count += 1
			return {}

	var rank := int(detail_face.get("rank", 0))
	var rank_label := str(RANK_LABEL_BY_RANK.get(rank, ""))
	var accent := _presentation_accent(tokens)
	var semantic_binding := codex_dto.get("semantic_binding", {}) as Dictionary
	var facts := {
		"valid": true,
		"index": card_index,
		"card_name": card_id,
		"display_name": "%s %s" % [str(copy.get("name", "")), rank_label],
		"family_id": family_id,
		"family_name": str(copy.get("family_name", "")),
		"rank": rank,
		"rank_label": rank_label,
		"category_id": str(taxonomy.get("category_id", "")),
		"category_label": str(copy.get("category_label", "")),
		"industry_id": str(taxonomy.get("industry_id", "")),
		"industry_label": str(copy.get("industry_label", "")),
		"icon": _icon_for_token(
			str(tokens.get("category_icon_token_id", "")),
			"□"
		),
		"accent": accent,
		"illustration_key": str(tokens.get("illustration_key", "")),
		"acquisition_cash": int((detail_face.get(
			"acquisition_cost",
			{}
		) as Dictionary).get("purchase_cash", 0)),
		"acquisition_cost_text": str(copy.get("acquisition_cost", "")),
		"activation_cost_text": str(copy.get("activation_cost", "")),
		"timing_text": str(copy.get("timing", "")),
		"target_text": _joined_text(copy.get("targets", []), "；"),
		"condition_texts": (copy.get("conditions", []) as Array).duplicate(true),
		"effect_step_texts": (copy.get("effect_steps", []) as Array).duplicate(true),
		"duration_text": str(copy.get("duration", "")),
		"counterability_text": str(copy.get("counterability", "")),
		"information_scope_text": str(copy.get("information_scope", "")),
		"keyword_chips": _keyword_chips(
			copy.get("keywords", []) as Array,
			detail_face.get("keywords", []) as Array,
			accent
		),
		"short_effect_text": str(copy.get("short_effect", "")),
		"full_effect_text": str(copy.get("full_effect", "")),
		"semantic_fingerprint": str(semantic_binding.get("semantic_fingerprint", "")),
		"dto_fingerprint": str(codex_dto.get("dto_fingerprint", "")),
		"family_ladder": _upgrade_rows(ladder_dto),
	}
	facts["facts_fingerprint"] = _card_facts_fingerprint(facts)
	if not _valid_card_facts(facts):
		_rejected_input_count += 1
		return {}
	_dto_compose_count += 1
	return facts.duplicate(true)


func compose_upgrade_facts(ladder_dto: Dictionary) -> Array:
	if not bool(PlayerCardCodexFamilyLadderDTO.validate(ladder_dto).get("valid", false)):
		_rejected_input_count += 1
		return []
	return _upgrade_rows(ladder_dto)


func compose_browser_source(
	request: Dictionary,
	cards: Array,
	preview_card: Dictionary,
	filters: Array
) -> Dictionary:
	if not _valid_browser_request(request) \
			or not _valid_card_fact_array(cards) \
			or (not preview_card.is_empty() and not _valid_card_facts(preview_card)) \
			or not _valid_filters(filters):
		_rejected_input_count += 1
		return {}
	var source := _allowlist_dictionary(request, BROWSER_REQUEST_FIELDS)
	source["schema_version"] = SCHEMA_VERSION
	source["names"] = _string_array(request.get("names", []))
	source["cards"] = cards.duplicate(true)
	source["preview_card"] = preview_card.duplicate(true)
	source["filters"] = filters.duplicate(true)
	return source


func compose_detail_source(
	card_facts: Dictionary,
	upgrades: Array,
	total: int
) -> Dictionary:
	if not _valid_card_facts(card_facts) or not _valid_upgrade_rows(upgrades):
		_rejected_input_count += 1
		return {}
	var source := card_facts.duplicate(true)
	source["schema_version"] = SCHEMA_VERSION
	source["total"] = maxi(1, total)
	source["upgrades"] = upgrades.duplicate(true)
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
		"forbidden_input_keys": FORBIDDEN_INPUT_KEYS.keys(),
		"forbidden_retired_fields": FORBIDDEN_RETIRED_FIELDS.keys(),
		"compatibility_alias_retirement": COMPATIBILITY_ALIAS_RETIREMENT.duplicate(true),
		"token_resolution_retirement": TOKEN_RESOLUTION_RETIREMENT.duplicate(true),
	}


func debug_snapshot() -> Dictionary:
	return {
		"adapter_ready": true,
		"schema_version": SCHEMA_VERSION,
		"rejected_input_count": _rejected_input_count,
		"dto_compose_count": _dto_compose_count,
		"dto_only_semantic_input": true,
		"family_ladder_dto_supported": true,
		"upgrade_facts_from_ladder_only": true,
		"pure_data_only": true,
		"reads_runtime_nodes": false,
		"reads_world_bridge": false,
		"reads_raw_card_record": false,
		"infers_rules_from_text": false,
		"owns_rules": false,
		"owns_save_state": false,
	}


func _upgrade_rows(ladder_dto: Dictionary) -> Array:
	if ladder_dto.is_empty():
		return []
	var rows: Array = []
	for entry_variant in ladder_dto.get("entries", []) as Array:
		var entry := entry_variant as Dictionary
		var face := entry.get("detail_face", {}) as Dictionary
		var copy := entry.get("presentation_copy", {}) as Dictionary
		var tokens := entry.get("presentation_tokens", {}) as Dictionary
		var rank := int(face.get("rank", 0))
		var rank_label := str(RANK_LABEL_BY_RANK.get(rank, ""))
		rows.append({
			"card_id": str(face.get("card_id", "")),
			"family_id": str(face.get("family_id", "")),
			"rank": rank,
			"rank_label": rank_label,
			"display_name": "%s %s" % [str(copy.get("name", "")), rank_label],
			"acquisition_cost_text": str(copy.get("acquisition_cost", "")),
			"activation_cost_text": str(copy.get("activation_cost", "")),
			"target_text": _joined_text(copy.get("targets", []), "；"),
			"effect_step_texts": (copy.get("effect_steps", []) as Array).duplicate(true),
			"duration_text": str(copy.get("duration", "")),
			"accent": _presentation_accent(tokens),
			"illustration_key": str(tokens.get("illustration_key", "")),
			"full_effect_text": str(copy.get("full_effect", "")),
		})
	return rows


func _ladder_contains_card(ladder_dto: Dictionary, card_id: String) -> bool:
	for entry_variant in ladder_dto.get("entries", []) as Array:
		var entry := entry_variant as Dictionary
		var face := entry.get("detail_face", {}) as Dictionary
		if str(face.get("card_id", "")) == card_id:
			return true
	return false


func _keyword_chips(
	copy_rows: Array,
	face_rows: Array,
	fallback_accent: Color
) -> Array:
	var chips: Array = []
	for index in range(copy_rows.size()):
		var face_row := face_rows[index] as Dictionary
		var accent := _color_for_token(
			str(face_row.get("color_token_id", "")),
			fallback_accent
		)
		chips.append({
			"text": str(copy_rows[index]),
			"tooltip": str(copy_rows[index]),
			"fg": accent.lightened(0.16),
			"bg": Color("#020617").lerp(accent, 0.16),
			"accent": accent,
		})
	return chips


func _presentation_accent(tokens: Dictionary) -> Color:
	var category_color := _color_for_token(
		str(tokens.get("category_color_token_id", "")),
		Color("#93c5fd")
	)
	return _color_for_token(
		str(tokens.get("industry_color_token_id", "")),
		category_color
	)


func _color_for_token(token_id: String, fallback: Color) -> Color:
	var value := TOKEN_MANIFEST.color_value(token_id)
	return Color(value) if not value.is_empty() else fallback


func _icon_for_token(token_id: String, fallback: String) -> String:
	var value := TOKEN_MANIFEST.icon_value(token_id)
	return value if not value.is_empty() else fallback


func _valid_browser_request(request: Dictionary) -> bool:
	return _accepts_public_input(request) \
		and _has_only_fields(request, BROWSER_REQUEST_FIELDS)


func _valid_card_fact_array(cards: Array) -> bool:
	for card_variant in cards:
		if not (card_variant is Dictionary) \
				or not _valid_card_facts(card_variant as Dictionary):
			return false
	return true


func _valid_card_facts(facts: Dictionary) -> bool:
	if not _accepts_public_input(facts) \
			or not _has_exact_fields(facts, CARD_FACT_FIELDS) \
			or not bool(facts.get("valid", false)):
		return false
	var fingerprint := str(facts.get("facts_fingerprint", ""))
	if fingerprint.length() != 64:
		return false
	var fingerprint_input := facts.duplicate(true)
	fingerprint_input.erase("facts_fingerprint")
	fingerprint_input.erase("index")
	return fingerprint == _fingerprint_value(fingerprint_input) \
		and _valid_upgrade_rows(facts.get("family_ladder", []) as Array)


func _valid_upgrade_rows(rows: Array) -> bool:
	for row_variant in rows:
		if not (row_variant is Dictionary):
			return false
		var row := row_variant as Dictionary
		if not _accepts_public_input(row) \
				or not _has_exact_fields(row, UPGRADE_FIELDS) \
				or int(row.get("rank", 0)) < 1 \
				or int(row.get("rank", 0)) > 4:
			return false
	return true


func _valid_filters(filters: Array) -> bool:
	for filter_variant in filters:
		if not (filter_variant is Dictionary):
			return false
		var filter_row := filter_variant as Dictionary
		if not _accepts_public_input(filter_row) \
				or not _has_only_fields(filter_row, FILTER_FIELDS):
			return false
	return true


func _allowlist_dictionary(source: Dictionary, fields: Array) -> Dictionary:
	var result := {}
	for field_variant in fields:
		var field := str(field_variant)
		if source.has(field):
			result[field] = _duplicate_data(source[field])
	return result


func _accepts_public_input(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is float and not is_finite(float(value)):
		return false
	if value is Dictionary:
		for key_variant in value:
			var key := str(key_variant).to_lower()
			if FORBIDDEN_INPUT_KEYS.has(key) \
					or FORBIDDEN_RETIRED_FIELDS.has(key) \
					or key.begins_with("private_") \
					or key.begins_with("hidden_"):
				return false
			if not _accepts_public_input(value[key_variant]):
				return false
	elif value is Array:
		for item_variant in value:
			if not _accepts_public_input(item_variant):
				return false
	return true


func _fingerprint_value(value: Variant) -> String:
	return JSON.stringify(_canonicalize(value)).sha256_text().to_lower()


func _card_facts_fingerprint(facts: Dictionary) -> String:
	var fingerprint_input := facts.duplicate(true)
	fingerprint_input.erase("facts_fingerprint")
	fingerprint_input.erase("index")
	return _fingerprint_value(fingerprint_input)


func _canonicalize(value: Variant) -> Variant:
	if value is Color:
		return (value as Color).to_html(true)
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array[String] = []
		for key_variant in source.keys():
			keys.append(str(key_variant))
		keys.sort()
		var normalized := {}
		for key in keys:
			normalized[key] = _canonicalize(source.get(key))
		return normalized
	if value is Array:
		var normalized_array: Array = []
		for item in value as Array:
			normalized_array.append(_canonicalize(item))
		return normalized_array
	return value


func _has_exact_fields(source: Dictionary, expected_fields: Array) -> bool:
	return source.size() == expected_fields.size() \
		and _has_only_fields(source, expected_fields)


func _has_only_fields(source: Dictionary, allowed_fields: Array) -> bool:
	for key_variant in source.keys():
		if not allowed_fields.has(str(key_variant)):
			return false
	return true


func _duplicate_data(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item_variant in value:
			var item := str(item_variant).strip_edges()
			if item != "":
				result.append(item)
	return result


func _joined_text(value: Variant, separator: String) -> String:
	var rows: Array[String] = []
	if value is Array:
		for item_variant in value as Array:
			rows.append(str(item_variant))
	return separator.join(rows)
