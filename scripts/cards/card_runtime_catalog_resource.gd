@tool
extends Resource
class_name CardRuntimeCatalogResource

const KindSchema := preload("res://scripts/cards/card_runtime_kind_schema.gd")

@export var catalog_version := "v0.4"
@export var packs: Array[Resource] = []
@export var authored_card_order := PackedStringArray()
@export var common_pool_card_ids := PackedStringArray()
@export var upgradeable_family_order := PackedStringArray()
@export var kind_field_rules: Dictionary = {}
@export var source_catalog_order_sha256 := ""
@export var source_upgradeable_order_sha256 := ""
@export var source_common_pool_order_sha256 := ""

var _card_index: Dictionary = {}
var _family_index: Dictionary = {}
var _index_ready := false


func has_card(card_id: String) -> bool:
	_ensure_index()
	if _card_index.has(card_id):
		return true
	var parsed_rank := rank(card_id)
	var parsed_family := family_id(card_id)
	return parsed_rank >= 1 and parsed_rank <= 4 and _family_index.has(parsed_family) and not (_family_index[parsed_family] as CardRuntimeFamilyResource).exact_definition(1).is_empty()


func authored_definition(card_id: String) -> Dictionary:
	_ensure_index()
	var resource := _card_index.get(card_id) as CardRuntimeRankResource
	return resource.to_dictionary() if resource != null else {}


func exact_definition(card_id: String) -> Dictionary:
	var card_definition := authored_definition(card_id)
	if not card_definition.is_empty():
		card_definition["name"] = card_id
	return card_definition


func derived_definition(card_id: String) -> Dictionary:
	_ensure_index()
	var parsed_rank := rank(card_id)
	var parsed_family := family_id(card_id)
	var family := _family_index.get(parsed_family) as CardRuntimeFamilyResource
	if family == null or parsed_rank < 1 or parsed_rank > 4:
		return {}
	return family.derived_definition(parsed_rank)


func definition(card_id: String) -> Dictionary:
	var exact := exact_definition(card_id)
	return exact if not exact.is_empty() else derived_definition(card_id)


func family_id(card_id: String) -> String:
	var end := card_id.length()
	while end > 0 and "0123456789".contains(card_id.substr(end - 1, 1)):
		end -= 1
	return card_id.substr(0, end)


func rank(card_id: String) -> int:
	var digits := ""
	var index := card_id.length() - 1
	while index >= 0:
		var character := card_id.substr(index, 1)
		if not "0123456789".contains(character):
			break
		digits = character + digits
		index -= 1
	return int(digits) if not digits.is_empty() else 0


func ordered_card_ids() -> Array:
	return Array(authored_card_order).duplicate()


func public_pool() -> Array:
	return Array(common_pool_card_ids).duplicate()


func upgradeable_families() -> Array:
	return Array(upgradeable_family_order).duplicate()


func validation_report() -> Dictionary:
	_ensure_index()
	var errors: Array = []
	var family_membership: Dictionary = {}
	var authored_rank_count := 0
	var kinds: Dictionary = {}
	for pack_resource in packs:
		var pack := pack_resource as CardRuntimePackResource
		if pack == null:
			errors.append("invalid_pack_resource")
			continue
		for family_resource in pack.families:
			var family := family_resource as CardRuntimeFamilyResource
			if family == null:
				errors.append("invalid_family_resource:%s" % str(pack.pack_id))
				continue
			family_membership[family.family_id] = int(family_membership.get(family.family_id, 0)) + 1
			for rank_resource in family.authored_ranks:
				var authored := rank_resource as CardRuntimeRankResource
				if authored == null:
					errors.append("invalid_rank_resource:%s" % family.family_id)
					continue
				authored_rank_count += 1
				var card_definition := authored.to_dictionary()
				var kind_id := str(card_definition.get("kind", ""))
				kinds[kind_id] = int(kinds.get(kind_id, 0)) + 1
				var rule_variant: Variant = kind_field_rules.get(kind_id, {})
				var rule: Dictionary = rule_variant if rule_variant is Dictionary else {}
				var result := KindSchema.validate_definition(card_definition, rule)
				if not bool(result.get("valid", false)):
					errors.append({"card_id": authored.card_id, "errors": result.get("errors", [])})
	for family_name in family_membership:
		if int(family_membership[family_name]) != 1:
			errors.append("family_pack_membership:%s:%d" % [family_name, int(family_membership[family_name])])
	for card_id in authored_card_order:
		if not _card_index.has(str(card_id)):
			errors.append("ordered_card_missing:%s" % str(card_id))
	for card_id in common_pool_card_ids:
		if not _card_index.has(str(card_id)):
			errors.append("public_pool_card_missing:%s" % str(card_id))
	return {
		"valid": errors.is_empty(),
		"catalog_version": catalog_version,
		"card_count": _card_index.size(),
		"authored_rank_count": authored_rank_count,
		"family_count": _family_index.size(),
		"pack_count": packs.size(),
		"common_pool_count": common_pool_card_ids.size(),
		"upgradeable_family_count": upgradeable_family_order.size(),
		"kind_count": kinds.size(),
		"kind_ids": _sorted_strings(kinds.keys()),
		"errors": errors,
	}


func debug_snapshot() -> Dictionary:
	var report := validation_report()
	return {
		"catalog_version": catalog_version,
		"catalog_ready": bool(report.get("valid", false)),
		"card_count": int(report.get("card_count", 0)),
		"family_count": int(report.get("family_count", 0)),
		"pack_count": int(report.get("pack_count", 0)),
		"common_pool_count": common_pool_card_ids.size(),
		"upgradeable_family_count": upgradeable_family_order.size(),
		"kind_count": int(report.get("kind_count", 0)),
		"catalog_order_sha256": _order_hash(ordered_card_ids()),
		"upgradeable_order_sha256": _order_hash(upgradeable_families()),
		"common_pool_order_sha256": _order_hash(public_pool()),
		"validation_errors": (report.get("errors", []) as Array).duplicate(true),
	}


func invalidate_index() -> void:
	_card_index.clear()
	_family_index.clear()
	_index_ready = false


func _ensure_index() -> void:
	if _index_ready:
		return
	_card_index.clear()
	_family_index.clear()
	for pack_resource in packs:
		var pack := pack_resource as CardRuntimePackResource
		if pack == null:
			continue
		for family_resource in pack.families:
			var family := family_resource as CardRuntimeFamilyResource
			if family == null:
				continue
			_family_index[family.family_id] = family
			for rank_resource in family.authored_ranks:
				var authored := rank_resource as CardRuntimeRankResource
				if authored != null:
					_card_index[authored.card_id] = authored
	_index_ready = true


func _order_hash(values: Array) -> String:
	var strings: Array[String] = []
	for value in values:
		strings.append(str(value))
	return "\n".join(strings).sha256_text()


func _sorted_strings(values: Array) -> Array:
	var strings: Array[String] = []
	for value in values:
		strings.append(str(value))
	strings.sort()
	return strings
