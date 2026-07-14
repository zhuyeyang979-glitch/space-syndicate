extends Resource
class_name CardRuntimeCatalogV06Resource

const EXPECTED_CARD_COUNT := 348
const EXPECTED_FAMILY_COUNT := 87
const EXPECTED_CATEGORY_COUNTS := {
	"commodity": 184,
	"facility": 64,
	"supply_demand": 8,
	"monster": 32,
	"military": 28,
	"interaction": 12,
	"organization": 20,
}
const ASSET_KEYS := ["life", "energy", "industry", "technology", "commerce", "shipping", "generic"]
const PLAYER_REQUIRED_FIELDS := ["name", "rank", "type", "industry", "cost", "timing", "target", "short_effect", "effect", "duration", "visibility", "keywords", "next_step"]
const PLAYER_FORBIDDEN_FIELDS := ["card_id", "family_id", "reason_code", "resource_path", "visual_source_id", "license", "sha256", "raw_error", "implementation_status", "mana_cost", "asset_cost"]
const ORGANIZATION_REQUIRED_PAYLOAD_FIELDS := [
	"organization_axis", "organization_family_id", "organization_slot_cost", "organization_slot_limit",
	"install_policy", "stack_policy", "activation_window_offset", "persistence", "required_own_gdp_min",
	"required_positive_gdp_color_count", "public_clue_kind", "counterplay_tags", "anti_snowball_cap",
]

@export var schema_version := "v0.6"
@export_file("*.json") var source_path := "res://data/cards/card_runtime_catalog_v06.json"
@export var expected_card_count := EXPECTED_CARD_COUNT
@export var expected_family_count := EXPECTED_FAMILY_COUNT

var _catalog_cache: Dictionary = {}
var _card_index: Dictionary = {}


func reload() -> Dictionary:
	_catalog_cache.clear()
	_card_index.clear()
	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return {"valid": false, "errors": ["catalog_source_open_failed"], "source_path": source_path}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {"valid": false, "errors": ["catalog_source_json_invalid"], "source_path": source_path}
	_catalog_cache = (parsed as Dictionary).duplicate(true)
	_rebuild_index()
	return validation_report()


func catalog_snapshot() -> Dictionary:
	_ensure_loaded()
	return _catalog_cache.duplicate(true)


func card_snapshot(card_id: String) -> Dictionary:
	_ensure_loaded()
	var value: Variant = _card_index.get(card_id, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func card_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for card_id_variant in _card_index.keys():
		result.append(str(card_id_variant))
	result.sort()
	return result


func family_ids() -> Array[String]:
	_ensure_loaded()
	var seen: Dictionary = {}
	for card_variant in _cards():
		var card: Dictionary = card_variant
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		seen[str(machine.get("family_id", ""))] = true
	var result: Array[String] = []
	for family_id_variant in seen.keys():
		var family_id := str(family_id_variant)
		if not family_id.is_empty():
			result.append(family_id)
	result.sort()
	return result


func cards_for_acquisition(acquisition_kind: String) -> Array[Dictionary]:
	_ensure_loaded()
	var result: Array[Dictionary] = []
	for card_variant in _cards():
		var card: Dictionary = card_variant
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		if str(machine.get("acquisition_kind", "")) == acquisition_kind and bool(machine.get("available_for_acquisition", false)):
			result.append(card.duplicate(true))
	return result


func validation_report() -> Dictionary:
	_ensure_loaded()
	var errors: Array[String] = []
	if str(_catalog_cache.get("schema_version", "")) != schema_version:
		errors.append("schema_version_mismatch")
	var cards := _cards()
	if cards.size() != expected_card_count:
		errors.append("card_count:%d" % cards.size())
	var category_counts: Dictionary = {}
	var family_ranks: Dictionary = {}
	var seen_ids: Dictionary = {}
	var player_text_leaks := 0
	var effect_review_pending := 0
	for card_variant in cards:
		if not (card_variant is Dictionary):
			errors.append("card_record_not_dictionary")
			continue
		var card: Dictionary = card_variant
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		var player: Dictionary = card.get("player", {}) if card.get("player", {}) is Dictionary else {}
		var developer: Dictionary = card.get("developer", {}) if card.get("developer", {}) is Dictionary else {}
		var card_id := str(machine.get("card_id", ""))
		var family_id := str(machine.get("family_id", ""))
		var rank := int(machine.get("rank", 0))
		var category_id := str(machine.get("category_id", ""))
		if not _is_stable_ascii_id(card_id) or not _is_stable_ascii_id(family_id):
			errors.append("identity_invalid:%s" % card_id)
		elif card_id != "%s.rank_%d" % [family_id, rank]:
			errors.append("ranked_identity_invalid:%s" % card_id)
		if seen_ids.has(card_id):
			errors.append("duplicate_card_id:%s" % card_id)
		seen_ids[card_id] = true
		if rank < 1 or rank > 4:
			errors.append("rank_out_of_range:%s" % card_id)
		category_counts[category_id] = int(category_counts.get(category_id, 0)) + 1
		if not family_ranks.has(family_id):
			family_ranks[family_id] = []
		(family_ranks[family_id] as Array).append(rank)
		if not _valid_assets(machine.get("asset_cost", {})):
			errors.append("asset_cost_invalid:%s" % card_id)
		if int(machine.get("purchase_cash", -1)) < 0:
			errors.append("purchase_cash_invalid:%s" % card_id)
		if str(machine.get("resolution_policy", "")) != "reject_before_consume_if_unowned":
			errors.append("unsafe_resolution_policy:%s" % card_id)
		if not _is_pure_data(machine.get("effect_payload", {})):
			errors.append("effect_payload_not_pure_data:%s" % card_id)
		for field_name in PLAYER_REQUIRED_FIELDS:
			if not player.has(field_name) or (player[field_name] is String and str(player[field_name]).strip_edges().is_empty()):
				errors.append("player_field_missing:%s:%s" % [card_id, field_name])
		for field_name in PLAYER_FORBIDDEN_FIELDS:
			if player.has(field_name):
				player_text_leaks += 1
		if _contains_term(player, "法力") or JSON.stringify(player).to_lower().contains("mana"):
			player_text_leaks += 1
			errors.append("legacy_resource_term_in_player_text:%s" % card_id)
		if str(developer.get("effect_review_status", "")) != "rule_confirmed":
			effect_review_pending += 1
		if category_id == "commodity":
			if int(machine.get("purchase_cash", -1)) != 0 or _asset_total(machine.get("asset_cost", {})) != 0:
				errors.append("commodity_not_free:%s" % card_id)
			if str(machine.get("acquisition_kind", "")) != "commodity_belt_free":
				errors.append("commodity_acquisition_invalid:%s" % card_id)
		if category_id == "organization":
			var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
			if str(machine.get("effect_kind", "")) != "install_organization_upgrade" or str(machine.get("target_kind", "")) != "self_organization_slot":
				errors.append("organization_effect_contract_invalid:%s" % card_id)
			for field_name in ORGANIZATION_REQUIRED_PAYLOAD_FIELDS:
				if not payload.has(field_name):
					errors.append("organization_payload_missing:%s:%s" % [card_id, field_name])
			if bool(payload.get("direct_player_interaction", true)) or bool(payload.get("counterable", true)) or bool(payload.get("phase_veto_eligible", true)):
				errors.append("organization_interaction_scope_invalid:%s" % card_id)
			if int(payload.get("organization_slot_limit", 0)) != 3 or int(payload.get("organization_slot_cost", 0)) != 1:
				errors.append("organization_slot_contract_invalid:%s" % card_id)
	if player_text_leaks != 0:
		errors.append("player_text_leaks:%d" % player_text_leaks)
	if family_ranks.size() != expected_family_count:
		errors.append("family_count:%d" % family_ranks.size())
	for family_id_variant in family_ranks.keys():
		var ranks: Array = family_ranks[family_id_variant]
		ranks.sort()
		if ranks != [1, 2, 3, 4]:
			errors.append("family_ladder_incomplete:%s" % str(family_id_variant))
	for category_id_variant in EXPECTED_CATEGORY_COUNTS.keys():
		var category_id := str(category_id_variant)
		if int(category_counts.get(category_id, 0)) != int(EXPECTED_CATEGORY_COUNTS[category_id]):
			errors.append("category_count:%s:%d" % [category_id, int(category_counts.get(category_id, 0))])
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"source_path": source_path,
		"card_count": cards.size(),
		"family_count": family_ranks.size(),
		"category_counts": category_counts,
		"player_text_leak_count": player_text_leaks,
		"effect_review_pending_count": effect_review_pending,
	}


func debug_snapshot() -> Dictionary:
	var report := validation_report()
	return {
		"schema_version": schema_version,
		"source_path": source_path,
		"valid": report.get("valid", false),
		"card_count": report.get("card_count", 0),
		"family_count": report.get("family_count", 0),
		"category_counts": report.get("category_counts", {}),
		"effect_review_pending_count": report.get("effect_review_pending_count", 0),
	}


func _ensure_loaded() -> void:
	if _catalog_cache.is_empty():
		reload()


func _cards() -> Array:
	var value: Variant = _catalog_cache.get("cards", [])
	return value if value is Array else []


func _rebuild_index() -> void:
	_card_index.clear()
	for card_variant in _cards():
		if not (card_variant is Dictionary):
			continue
		var card: Dictionary = card_variant
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		var card_id := str(machine.get("card_id", ""))
		if not card_id.is_empty():
			_card_index[card_id] = card.duplicate(true)


func _valid_assets(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var assets: Dictionary = value
	for key in ASSET_KEYS:
		if not assets.has(key) or int(assets.get(key, -1)) < 0:
			return false
	for key_variant in assets.keys():
		if not ASSET_KEYS.has(str(key_variant)):
			return false
	return true


func _asset_total(value: Variant) -> int:
	if not (value is Dictionary):
		return -1
	var total := 0
	for key in ASSET_KEYS:
		total += int((value as Dictionary).get(key, 0))
	return total


func _contains_term(value: Variant, term: String) -> bool:
	if value is String:
		return str(value).contains(term)
	if value is Array:
		for item in value:
			if _contains_term(item, term):
				return true
	if value is Dictionary:
		for item in (value as Dictionary).values():
			if _contains_term(item, term):
				return true
	return false


func _is_stable_ascii_id(value: String) -> bool:
	if value.is_empty():
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		var valid := (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 46 or code == 95 or code == 45
		if not valid:
			return false
	return true


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not _is_pure_data(key) or not _is_pure_data(value[key]):
				return false
		return true
	return false
