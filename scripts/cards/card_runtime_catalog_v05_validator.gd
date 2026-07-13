extends RefCounted
class_name CardRuntimeCatalogV05Validator

const PlayerTextSpecScript := preload("res://scripts/presentation/player_text_spec_v05.gd")

const ALLOWED_KINDS := [
	"colorless",
	"single_industry",
	"dual_industry",
	"either_industry",
	"named_product",
]


static func validate_catalog(catalog: Resource, industry_catalog: Resource) -> Dictionary:
	var errors: Array[String] = []
	if catalog == null:
		return {"valid": false, "errors": ["catalog_missing"], "card_results": []}
	if industry_catalog == null:
		return {"valid": false, "errors": ["industry_catalog_missing"], "card_results": []}
	if str(catalog.schema_version) != "v0.5":
		errors.append("catalog_schema_version_invalid")
	var seen: Dictionary = {}
	var card_results: Array[Dictionary] = []
	for card in catalog.cards:
		var result := validate_card(card, industry_catalog)
		card_results.append(result)
		var card_id := str(result.get("card_id", ""))
		if card_id.is_empty():
			errors.append("card_id_missing")
		elif seen.has(card_id):
			errors.append("duplicate_card_id:%s" % card_id)
		else:
			seen[card_id] = true
		if not bool(result.get("valid", false)):
			errors.append("card_invalid:%s" % card_id)
	for release_id_variant in catalog.release_ready_card_ids:
		var release_id := str(release_id_variant)
		if not seen.has(release_id):
			errors.append("unknown_release_ready_card:%s" % release_id)
			continue
		var release_card: Dictionary = catalog.card_snapshot(release_id)
		if str(release_card.get("migration_status", "")) != "release_ready" or not bool(release_card.get("release_ready", false)):
			errors.append("blocked_card_in_release_ready:%s" % release_id)
	for public_id_variant in catalog.public_pool_card_ids:
		var public_id := str(public_id_variant)
		if not catalog.release_ready_card_ids.has(public_id):
			errors.append("public_pool_card_not_release_ready:%s" % public_id)
		var public_card: Dictionary = catalog.card_snapshot(public_id)
		if not bool(public_card.get("public_pool", false)):
			errors.append("public_pool_flag_missing:%s" % public_id)
	var snapshot: Dictionary = catalog.debug_snapshot()
	if not _is_pure_data(snapshot):
		errors.append("catalog_snapshot_not_pure_data")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"card_results": card_results,
		"snapshot": snapshot,
	}


static func validate_card(card: Resource, industry_catalog: Resource) -> Dictionary:
	var errors: Array[String] = []
	if card == null:
		return {"valid": false, "card_id": "", "errors": ["card_missing"]}
	if str(card.schema_version) != "v0.5":
		errors.append("schema_version_invalid")
	if str(card.card_id).is_empty() or str(card.family_id).is_empty():
		errors.append("identity_missing")
	elif not PlayerTextSpecScript.is_stable_ascii_id(str(card.card_id)) or not PlayerTextSpecScript.is_stable_ascii_id(str(card.family_id)):
		errors.append("identity_not_stable_ascii")
	for text_key_variant in [card.name_key, card.rules_key, card.short_effect_key, card.assistive_name_key]:
		var text_key := str(text_key_variant)
		if not text_key.is_empty() and not PlayerTextSpecScript.is_stable_ascii_id(text_key):
			errors.append("text_key_not_stable_ascii:%s" % text_key)
	if int(card.rank) < 1 or int(card.rank) > 4:
		errors.append("rank_out_of_range")
	var migration_status := str(card.migration_status)
	if migration_status == "blocked":
		if str(card.blocking_reason).strip_edges().is_empty():
			errors.append("blocked_card_requires_reason")
		if bool(card.release_ready) or bool(card.public_pool):
			errors.append("blocked_card_cannot_ship")
		return {"valid": errors.is_empty(), "card_id": str(card.card_id), "blocked": true, "errors": errors}
	if card.requirements.is_empty():
		errors.append("requirements_missing")
	if card.requirements.size() > 2:
		errors.append("too_many_major_requirements")
	for requirement in card.requirements:
		var requirement_result := validate_requirement(requirement, industry_catalog)
		if not bool(requirement_result.get("valid", false)):
			errors.append_array(requirement_result.get("errors", []))
	if migration_status == "release_ready" and not bool(card.release_ready):
		errors.append("release_ready_flag_missing")
	if migration_status == "release_ready" and (str(card.name_key).is_empty() or str(card.rules_key).is_empty() or str(card.assistive_name_key).is_empty()):
		errors.append("release_ready_text_keys_missing")
	return {"valid": errors.is_empty(), "card_id": str(card.card_id), "blocked": false, "errors": errors}


static func validate_requirement(requirement: Resource, industry_catalog: Resource) -> Dictionary:
	var errors: Array[String] = []
	if requirement == null:
		return {"valid": false, "errors": ["requirement_missing"]}
	var kind := str(requirement.requirement_kind)
	var industry_ids: Array = requirement.industry_ids
	var unique_industries: Dictionary = {}
	for industry_id_variant in industry_ids:
		unique_industries[str(industry_id_variant)] = true
	if not ALLOWED_KINDS.has(kind):
		errors.append("unknown_requirement_kind")
	for industry_id_variant in industry_ids:
		if not industry_catalog.industry_ids().has(str(industry_id_variant)):
			errors.append("unknown_industry:%s" % str(industry_id_variant))
	if unique_industries.size() != industry_ids.size():
		errors.append("duplicate_industry")
	if int(requirement.required_capacity) < 0 or int(requirement.required_product_gdp) < 0 or int(requirement.required_influence_bp) < 0:
		errors.append("negative_requirement")
	if int(requirement.required_influence_bp) > 10000:
		errors.append("influence_bp_out_of_range")
	match kind:
		"colorless":
			if not industry_ids.is_empty() or int(requirement.required_capacity) != 0 or not str(requirement.product_id).is_empty():
				errors.append("colorless_cannot_charge_industry")
		"single_industry":
			if industry_ids.size() != 1 or int(requirement.required_capacity) <= 0 or not str(requirement.product_id).is_empty():
				errors.append("single_industry_shape_invalid")
		"dual_industry":
			if industry_ids.size() != 2 or int(requirement.required_capacity) <= 0 or not str(requirement.product_id).is_empty():
				errors.append("dual_industry_shape_invalid")
		"either_industry":
			if industry_ids.size() != 2 or int(requirement.required_capacity) <= 0 or not str(requirement.product_id).is_empty():
				errors.append("either_industry_shape_invalid")
		"named_product":
			if not industry_ids.is_empty() or int(requirement.required_capacity) != 0:
				errors.append("named_product_replaces_industry_charge")
			if str(requirement.product_id).is_empty() or industry_catalog.industry_for_product(str(requirement.product_id)).is_empty():
				errors.append("unknown_product:%s" % str(requirement.product_id))
	return {"valid": errors.is_empty(), "errors": errors, "snapshot": requirement.to_snapshot()}


static func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName or key is int) or not _is_pure_data(value[key]):
				return false
		return true
	return false
