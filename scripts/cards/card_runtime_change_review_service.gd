@tool
extends RefCounted
class_name CardRuntimeChangeReviewService

const REVIEW_SCHEMA := "runtime-card-change-review-v1"
const SNAPSHOT_SCHEMA := "runtime-card-authoring-baseline-v1"


func catalog_snapshot(catalog: CardRuntimeCatalogResource) -> Dictionary:
	if catalog == null:
		return {"schema": SNAPSHOT_SCHEMA, "valid": false, "cards": {}}
	var cards: Dictionary = {}
	var family_cards: Dictionary = {}
	var family_paths: Dictionary = {}
	for pack_resource in catalog.packs:
		var pack := pack_resource as CardRuntimePackResource
		if pack == null:
			continue
		for family_resource in pack.families:
			var family := family_resource as CardRuntimeFamilyResource
			if family == null:
				continue
			family_paths[family.family_id] = family.resource_path
			var ids: Array = []
			for card_id_variant in family.authored_card_ids():
				var card_id := str(card_id_variant)
				var definition := catalog.authored_definition(card_id)
				ids.append(card_id)
				cards[card_id] = {
					"card_id": card_id,
					"family_id": family.family_id,
					"pack_id": str(pack.pack_id),
					"resource_path": family.resource_path,
					"definition_hash": definition_hash(definition),
					"definition": definition.duplicate(true),
				}
			family_cards[family.family_id] = ids
	return {
		"schema": SNAPSHOT_SCHEMA,
		"valid": true,
		"catalog_version": catalog.catalog_version,
		"captured_unix_time": int(Time.get_unix_time_from_system()),
		"cards": cards,
		"family_cards": family_cards,
		"family_paths": family_paths,
		"authored_card_order": catalog.ordered_card_ids(),
		"public_pool": catalog.public_pool(),
		"upgradeable_families": catalog.upgradeable_families(),
		"catalog_order_sha256": order_hash(catalog.ordered_card_ids()),
		"public_pool_order_sha256": order_hash(catalog.public_pool()),
		"upgradeable_order_sha256": order_hash(catalog.upgradeable_families()),
	}


func compare_snapshots(current: Dictionary, baseline: Dictionary, approved_integrity: Dictionary) -> Dictionary:
	var current_cards: Dictionary = current.get("cards", {}) if current.get("cards", {}) is Dictionary else {}
	var baseline_cards: Dictionary = baseline.get("cards", {}) if baseline.get("cards", {}) is Dictionary else {}
	var approved_hashes: Dictionary = approved_integrity.get("card_hashes", {}) if approved_integrity.get("card_hashes", {}) is Dictionary else {}
	var changed: Array = []
	var added: Array = []
	var removed: Array = []
	var unchanged_count := 0
	var all_ids: Array[String] = []
	for card_id_variant in current_cards:
		all_ids.append(str(card_id_variant))
	for card_id_variant in approved_hashes:
		var card_id := str(card_id_variant)
		if not all_ids.has(card_id):
			all_ids.append(card_id)
	all_ids.sort()
	for card_id in all_ids:
		var has_current := current_cards.has(card_id)
		var has_approved := approved_hashes.has(card_id)
		if has_current and not has_approved:
			added.append(_change_record("added", card_id, current_cards[card_id], {}, "", baseline_cards))
			continue
		if not has_current and has_approved:
			removed.append(_change_record("removed", card_id, {}, baseline_cards.get(card_id, {}), str(approved_hashes[card_id]), baseline_cards))
			continue
		var current_record: Dictionary = current_cards[card_id] if current_cards[card_id] is Dictionary else {}
		var current_hash := str(current_record.get("definition_hash", ""))
		var approved_hash := str(approved_hashes.get(card_id, ""))
		if current_hash != approved_hash:
			changed.append(_change_record("modified", card_id, current_record, baseline_cards.get(card_id, {}), approved_hash, baseline_cards))
		else:
			unchanged_count += 1
	var order_changes := {
		"catalog_order_changed": str(current.get("catalog_order_sha256", "")) != str(approved_integrity.get("catalog_order_sha256", "")),
		"public_pool_order_changed": str(current.get("public_pool_order_sha256", "")) != str(approved_integrity.get("common_pool_order_sha256", "")),
		"upgradeable_order_changed": str(current.get("upgradeable_order_sha256", "")) != str(approved_integrity.get("upgradeable_order_sha256", "")),
	}
	var affected_families: Array[String] = []
	for change_list in [changed, added, removed]:
		for change_variant in change_list:
			var family_id := str((change_variant as Dictionary).get("family_id", ""))
			if not family_id.is_empty() and not affected_families.has(family_id):
				affected_families.append(family_id)
	affected_families.sort()
	var derived_impacts: Array = []
	var family_cards: Dictionary = current.get("family_cards", {}) if current.get("family_cards", {}) is Dictionary else {}
	for family_id in affected_families:
		var authored: Array = family_cards.get(family_id, []) if family_cards.get(family_id, []) is Array else []
		var potential: Array = []
		for requested_rank in range(1, 5):
			var candidate_id := "%s%d" % [family_id, requested_rank]
			if not authored.has(candidate_id):
				potential.append(candidate_id)
		derived_impacts.append({"family_id": family_id, "potential_derived_ids": potential})
	var change_count := changed.size() + added.size() + removed.size()
	return {
		"schema": REVIEW_SCHEMA,
		"baseline_available": not baseline_cards.is_empty(),
		"approved_fixture_schema": str(approved_integrity.get("schema", "")),
		"change_count": change_count,
		"changed_count": changed.size(),
		"added_count": added.size(),
		"removed_count": removed.size(),
		"unchanged_count": unchanged_count,
		"changed_cards": changed,
		"added_cards": added,
		"removed_cards": removed,
		"affected_families": affected_families,
		"derived_impacts": derived_impacts,
		"order_changes": order_changes,
		"consumer_review_checks": [
			"CardPlayEligibilityRuntimeService",
			"CardResolutionQueueRuntimeService",
			"CardPresentationRuntimeService",
			"AiRuntimeController",
			"MilitaryRuntimeController",
			"DistrictSupply",
			"Scenario/FirstTable",
			"CardCodex privacy",
			"Save card-id compatibility",
		],
		"review_status": "clean" if change_count == 0 and not _any_true(order_changes) else "changes_require_review",
	}


func definition_hash(definition: Dictionary) -> String:
	return canonical(definition).sha256_text()


func order_hash(values: Array) -> String:
	var strings: Array[String] = []
	for value in values:
		strings.append(str(value))
	return "\n".join(strings).sha256_text()


func canonical(value: Variant) -> String:
	if value == null:
		return "null"
	if value is bool:
		return "true" if value else "false"
	if value is int:
		return "i:%d" % value
	if value is float:
		return "f:%s" % String.num(value, 12)
	if value is String or value is StringName:
		return "s:%s" % JSON.stringify(str(value))
	if value is Array or value is PackedStringArray:
		var array_parts: Array[String] = []
		for item in value:
			array_parts.append(canonical(item))
		return "[%s]" % ",".join(array_parts)
	if value is Dictionary:
		var keys: Array[String] = []
		for key_variant in value:
			keys.append(str(key_variant))
		keys.sort()
		var dictionary_parts: Array[String] = []
		for key in keys:
			dictionary_parts.append("%s=%s" % [canonical(key), canonical(value[key])])
		return "{%s}" % ",".join(dictionary_parts)
	return "unsupported:%s" % typeof(value)


func _change_record(status: String, card_id: String, current_record: Dictionary, baseline_record: Dictionary, approved_hash: String, baseline_cards: Dictionary) -> Dictionary:
	var baseline_definition: Dictionary = baseline_record.get("definition", {}) if baseline_record.get("definition", {}) is Dictionary else {}
	var current_definition: Dictionary = current_record.get("definition", {}) if current_record.get("definition", {}) is Dictionary else {}
	var family_id := str(current_record.get("family_id", baseline_record.get("family_id", _family_id(card_id))))
	return {
		"status": status,
		"card_id": card_id,
		"family_id": family_id,
		"pack_id": str(current_record.get("pack_id", baseline_record.get("pack_id", ""))),
		"resource_path": str(current_record.get("resource_path", baseline_record.get("resource_path", ""))),
		"approved_hash": approved_hash,
		"baseline_hash": str(baseline_record.get("definition_hash", "")),
		"current_hash": str(current_record.get("definition_hash", "")),
		"field_changes": _field_changes(baseline_definition, current_definition) if not baseline_cards.is_empty() else [],
		"current_definition": current_definition.duplicate(true),
	}


func _field_changes(before: Dictionary, after: Dictionary) -> Array:
	var keys: Array[String] = []
	for key_variant in before:
		keys.append(str(key_variant))
	for key_variant in after:
		var key := str(key_variant)
		if not keys.has(key):
			keys.append(key)
	keys.sort()
	var changes: Array = []
	for key in keys:
		var before_has := before.has(key)
		var after_has := after.has(key)
		if before_has and after_has and _review_values_equal(before[key], after[key]):
			continue
		changes.append({
			"field": key,
			"change_kind": "added" if not before_has else ("removed" if not after_has else "modified"),
			"before": _data_copy(before.get(key)),
			"after": _data_copy(after.get(key)),
		})
	return changes


func _review_values_equal(before: Variant, after: Variant) -> bool:
	# JSON baselines deserialize every number as float. Keep catalog hashes strict,
	# but do not report an unchanged integer field as an authoring change.
	if (before is int or before is float) and (after is int or after is float):
		return is_equal_approx(float(before), float(after))
	return canonical(before) == canonical(after)


func _family_id(card_id: String) -> String:
	var end := card_id.length()
	while end > 0 and "0123456789".contains(card_id.substr(end - 1, 1)):
		end -= 1
	return card_id.substr(0, end)


func _any_true(values: Dictionary) -> bool:
	for value in values.values():
		if bool(value):
			return true
	return false


func _data_copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	if value is PackedStringArray:
		return Array(value)
	return value
