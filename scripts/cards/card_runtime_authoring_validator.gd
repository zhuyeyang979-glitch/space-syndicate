@tool
extends RefCounted
class_name CardRuntimeAuthoringValidator

const KindSchema := preload("res://scripts/cards/card_runtime_kind_schema.gd")


func validate_target(target: Resource, catalog: CardRuntimeCatalogResource) -> Dictionary:
	if target is CardRuntimeCatalogResource:
		return validate_catalog(target as CardRuntimeCatalogResource)
	if target is CardRuntimePackResource:
		return validate_pack(target as CardRuntimePackResource, catalog)
	if target is CardRuntimeFamilyResource:
		return validate_family(target as CardRuntimeFamilyResource, catalog)
	if target is CardRuntimeRankResource:
		var rank_resource := target as CardRuntimeRankResource
		return validate_rank(rank_resource, _family_for_id(catalog, rank_resource.family_id), catalog)
	return _result("unsupported", "", [_check("supported_resource_type", false, "error", "Only catalog, pack, family, and rank Resources are authorable.")])


func validate_catalog(catalog: CardRuntimeCatalogResource) -> Dictionary:
	var checks: Array = []
	if catalog == null:
		return _result("catalog", "", [_check("catalog_present", false, "error", "Catalog Resource is missing.")])
	var base_report := catalog.validation_report()
	checks.append(_check("runtime_catalog_validation", bool(base_report.get("valid", false)), "error", "Runtime catalog validators pass.", {"errors": base_report.get("errors", [])}))
	var pack_ids: Array = []
	var family_ids: Array = []
	var authored_ids: Array = []
	var memberships: Dictionary = {}
	for pack_resource in catalog.packs:
		var pack := pack_resource as CardRuntimePackResource
		checks.append(_check("pack_resource_type", pack != null, "error", "Every catalog pack is a CardRuntimePackResource."))
		if pack == null:
			continue
		pack_ids.append(str(pack.pack_id))
		var pack_result := validate_pack(pack, catalog)
		checks.append_array(pack_result.get("checks", []))
		for family_resource in pack.families:
			var family := family_resource as CardRuntimeFamilyResource
			if family == null:
				continue
			family_ids.append(family.family_id)
			memberships[family.family_id] = int(memberships.get(family.family_id, 0)) + 1
			for card_id in family.authored_card_ids():
				authored_ids.append(str(card_id))
	checks.append(_check("pack_ids_unique", _is_unique(pack_ids), "error", "Pack ids are unique."))
	checks.append(_check("family_ids_unique", _is_unique(family_ids), "error", "Every family belongs to exactly one pack."))
	checks.append(_check("authored_card_ids_unique", _is_unique(authored_ids), "error", "Authored card ids are unique."))
	var membership_ok := true
	for family_id_variant in memberships:
		if int(memberships[family_id_variant]) != 1:
			membership_ok = false
			break
	checks.append(_check("single_pack_membership", membership_ok, "error", "Every family has one pack membership."))
	var ordered_ids := catalog.ordered_card_ids()
	checks.append(_check("authored_order_unique", _is_unique(ordered_ids), "error", "Authored card order has no duplicates."))
	checks.append(_check("authored_order_complete", _same_string_set(ordered_ids, authored_ids), "error", "Authored card order contains every authored rank exactly once."))
	var pool_ids := catalog.public_pool()
	checks.append(_check("public_pool_unique", _is_unique(pool_ids), "error", "Public pool has no duplicate card ids."))
	checks.append(_check("public_pool_cards_exist", _all_values_in(pool_ids, authored_ids), "error", "Every public-pool card is authored."))
	var upgradeable_ids := catalog.upgradeable_families()
	checks.append(_check("upgradeable_order_unique", _is_unique(upgradeable_ids), "error", "Upgradeable family order has no duplicates."))
	checks.append(_check("upgradeable_families_exist", _all_values_in(upgradeable_ids, family_ids), "error", "Every upgradeable family exists."))
	checks.append(_check("catalog_output_pure_data", _is_data_only(catalog.debug_snapshot()), "error", "Catalog validation and debug snapshots are pure data."))
	return _result("catalog", catalog.catalog_version, checks, {
		"pack_count": pack_ids.size(),
		"family_count": family_ids.size(),
		"card_count": authored_ids.size(),
		"kind_count": int(base_report.get("kind_count", 0)),
	})


func validate_pack(pack: CardRuntimePackResource, catalog: CardRuntimeCatalogResource) -> Dictionary:
	var checks: Array = []
	if pack == null:
		return _result("pack", "", [_check("pack_present", false, "error", "Pack Resource is missing.")])
	checks.append(_check("pack_id_present", not str(pack.pack_id).is_empty(), "error", "Pack id is present."))
	checks.append(_check("pack_display_name_present", not pack.display_name.strip_edges().is_empty(), "warning", "Pack has a human-readable display name."))
	checks.append(_check("pack_has_families", not pack.families.is_empty(), "error", "Pack contains at least one family."))
	var family_ids: Array = []
	for family_resource in pack.families:
		var family := family_resource as CardRuntimeFamilyResource
		checks.append(_check("pack_family_type", family != null, "error", "Pack members are family Resources."))
		if family == null:
			continue
		family_ids.append(family.family_id)
		checks.append(_check("family_pack_id_matches", str(family.pack_id) == str(pack.pack_id), "error", "Family pack_id matches its containing pack.", {"family_id": family.family_id, "pack_id": str(pack.pack_id)}))
		var family_result := validate_family(family, catalog)
		checks.append_array(family_result.get("checks", []))
	checks.append(_check("pack_family_ids_unique", _is_unique(family_ids), "error", "Pack contains no duplicate family references."))
	return _result("pack", str(pack.pack_id), checks, {"family_count": family_ids.size()})


func validate_family(family: CardRuntimeFamilyResource, catalog: CardRuntimeCatalogResource) -> Dictionary:
	var checks: Array = []
	if family == null:
		return _result("family", "", [_check("family_present", false, "error", "Family Resource is missing.")])
	checks.append(_check("family_id_present", not family.family_id.is_empty(), "error", "Family id is present."))
	checks.append(_check("family_pack_id_present", not str(family.pack_id).is_empty(), "error", "Family pack id is present."))
	checks.append(_check("family_has_authored_rank", not family.authored_ranks.is_empty(), "error", "Family has at least one authored rank."))
	var ranks: Array = []
	var card_ids: Array = []
	for rank_resource in family.authored_ranks:
		var authored := rank_resource as CardRuntimeRankResource
		checks.append(_check("rank_resource_type", authored != null, "error", "Family members are rank Resources.", {"family_id": family.family_id}))
		if authored == null:
			continue
		ranks.append(authored.rank)
		card_ids.append(authored.card_id)
		var rank_result := validate_rank(authored, family, catalog)
		checks.append_array(rank_result.get("checks", []))
	checks.append(_check("family_rank_numbers_unique", _is_unique(ranks), "error", "Authored rank numbers are unique."))
	checks.append(_check("family_card_ids_unique", _is_unique(card_ids), "error", "Family card ids are unique."))
	checks.append(_check("family_rank_order_ascending", _is_non_decreasing_ints(ranks), "error", "Authored ranks remain in ascending order."))
	checks.append(_check("derivation_has_rank_one", not family.derivation_enabled or ranks.has(1), "error", "Derived families author rank I as their stable base."))
	if catalog != null:
		var pool_contains_family := false
		for card_id in card_ids:
			if catalog.public_pool().has(str(card_id)):
				pool_contains_family = true
				break
		checks.append(_check("public_pool_flag_consistent", family.public_pool_eligible == pool_contains_family, "warning", "Public-pool eligibility matches current pool membership."))
		checks.append(_check("upgradeable_flag_consistent", family.upgradeable_family == catalog.upgradeable_families().has(family.family_id), "error", "Upgradeable-family flag matches catalog order."))
	return _result("family", family.family_id, checks, {"rank_count": ranks.size(), "card_ids": card_ids})


func validate_rank(rank_resource: CardRuntimeRankResource, family: CardRuntimeFamilyResource, catalog: CardRuntimeCatalogResource) -> Dictionary:
	var checks: Array = []
	if rank_resource == null:
		return _result("rank", "", [_check("rank_present", false, "error", "Rank Resource is missing.")])
	var definition := rank_resource.to_dictionary()
	var expected_family := family.family_id if family != null else rank_resource.family_id
	var expected_card_id := "%s%d" % [expected_family, rank_resource.rank]
	checks.append(_check("card_id_present", not rank_resource.card_id.is_empty(), "error", "Card id is present."))
	checks.append(_check("family_id_present", not rank_resource.family_id.is_empty(), "error", "Rank family id is present."))
	checks.append(_check("family_id_matches", rank_resource.family_id == expected_family, "error", "Rank family id matches its containing family."))
	checks.append(_check("rank_in_range", rank_resource.rank >= 1 and rank_resource.rank <= 4, "error", "Rank is between I and IV."))
	checks.append(_check("card_id_matches_family_rank", rank_resource.card_id == expected_card_id, "error", "Card id is family id plus rank.", {"expected_card_id": expected_card_id}))
	checks.append(_check("authored_keys_unique", _is_unique(Array(rank_resource.authored_keys)), "error", "authored_keys contains no duplicates."))
	checks.append(_check("authored_shape_exact", _same_string_set(Array(rank_resource.authored_keys), definition.keys()), "error", "to_dictionary emits exactly the authored keys."))
	checks.append(_check("effect_parameters_pure_data", _is_data_only(rank_resource.effect_parameters), "error", "Effect parameters contain pure data only."))
	checks.append(_check("definition_pure_data", _is_data_only(definition), "error", "Authored definition contains pure data only."))
	checks.append(_check("rules_text_present", not rank_resource.rules_text.strip_edges().is_empty(), "error", "Rules text is present."))
	var kind_id := str(rank_resource.kind)
	var kind_rule: Dictionary = {}
	if catalog != null:
		var rule_variant: Variant = catalog.kind_field_rules.get(kind_id, {})
		kind_rule = rule_variant if rule_variant is Dictionary else {}
	checks.append(_check("kind_registered", not kind_id.is_empty() and not kind_rule.is_empty(), "error", "Card kind has an authored validator.", {"kind": kind_id}))
	var schema_report := KindSchema.validate_definition(definition, kind_rule)
	checks.append(_check("kind_schema_valid", bool(schema_report.get("valid", false)), "error", "Card definition passes its kind schema.", {"kind": kind_id, "errors": schema_report.get("errors", [])}))
	var core_fields_ok := true
	for field_name in rank_resource.integer_core_fields:
		if not ["move", "range"].has(str(field_name)):
			core_fields_ok = false
			break
	checks.append(_check("integer_core_fields_supported", core_fields_ok, "error", "Integer core-field markers are limited to move and range."))
	return _result("rank", rank_resource.card_id, checks, {"family_id": expected_family, "rank": rank_resource.rank, "kind": kind_id})


func _family_for_id(catalog: CardRuntimeCatalogResource, family_id: String) -> CardRuntimeFamilyResource:
	if catalog == null:
		return null
	for pack_resource in catalog.packs:
		var pack := pack_resource as CardRuntimePackResource
		if pack == null:
			continue
		for family_resource in pack.families:
			var family := family_resource as CardRuntimeFamilyResource
			if family != null and family.family_id == family_id:
				return family
	return null


func _result(scope_kind: String, scope_id: String, checks: Array, extra: Dictionary = {}) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	for check_variant in checks:
		var check: Dictionary = check_variant if check_variant is Dictionary else {}
		if bool(check.get("passed", false)):
			continue
		if str(check.get("severity", "error")) == "warning":
			warnings.append(check.duplicate(true))
		else:
			errors.append(check.duplicate(true))
	var result := {
		"scope_kind": scope_kind,
		"scope_id": scope_id,
		"valid": errors.is_empty(),
		"error_count": errors.size(),
		"warning_count": warnings.size(),
		"errors": errors,
		"warnings": warnings,
		"checks": checks.duplicate(true),
	}
	for key in extra:
		result[key] = _data_copy(extra[key])
	return result


func _check(check_id: String, passed: bool, severity: String, message: String, context: Dictionary = {}) -> Dictionary:
	return {
		"check_id": check_id,
		"passed": passed,
		"severity": severity,
		"message": message,
		"context": context.duplicate(true),
	}


func _is_unique(values: Array) -> bool:
	var seen: Dictionary = {}
	for value in values:
		var key := str(value)
		if seen.has(key):
			return false
		seen[key] = true
	return true


func _same_string_set(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	var left_values: Array[String] = []
	var right_values: Array[String] = []
	for value in left:
		left_values.append(str(value))
	for value in right:
		right_values.append(str(value))
	left_values.sort()
	right_values.sort()
	return left_values == right_values


func _all_values_in(values: Array, candidates: Array) -> bool:
	var allowed: Dictionary = {}
	for candidate in candidates:
		allowed[str(candidate)] = true
	for value in values:
		if not allowed.has(str(value)):
			return false
	return true


func _is_non_decreasing_ints(values: Array) -> bool:
	for index in range(1, values.size()):
		if int(values[index]) < int(values[index - 1]):
			return false
	return true


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array or value is PackedStringArray:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName) or not _is_data_only(value[key]):
				return false
		return true
	return false


func _data_copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	if value is PackedStringArray:
		return Array(value)
	return value
