extends RefCounted
class_name CardResolutionStableTargetEnvelope

const SCHEMA_VERSION := 3
const TARGET_NONE := "none"
const TARGET_MONSTER := "monster"
const TARGET_PLAYER := "player"
const TARGET_KINDS := [TARGET_NONE, TARGET_MONSTER, TARGET_PLAYER]
const ALLOWED_KEYS := [
	"schema_version",
	"session_id",
	"session_revision",
	"selection_revision",
	"region_id",
	"region_public_index_at_capture",
	"region_ordering_revision",
	"region_ordering_fingerprint",
	"product_id",
	"product_public_index_at_capture",
	"product_ordering_revision",
	"product_ordering_fingerprint",
	"selected_card_resolution_id",
	"target_kind",
	"target_slot",
	"target_monster_uid",
	"target_player",
	"play_requirement_region_id",
	"play_requirement_public_index_at_capture",
	"capture_source",
	"envelope_fingerprint",
]


static func capture(
	selection_snapshot: Dictionary,
	region_catalog: PublicRegionSelectionCatalogSnapshot,
	product_catalog: PublicProductSelectionCatalogSnapshot,
	context: Dictionary = {}
) -> Dictionary:
	if not TablePresentationPureDataPolicy.is_pure_data(selection_snapshot) \
			or not TablePresentationPureDataPolicy.is_pure_data(context) \
			or region_catalog == null or product_catalog == null \
			or not region_catalog.is_valid() or not product_catalog.is_valid() \
			or not region_catalog.available or not product_catalog.available \
			or region_catalog.session_id != product_catalog.session_id \
			or region_catalog.session_revision != product_catalog.session_revision:
		return {}
	var region_index := int(selection_snapshot.get("selected_district", -1))
	var region_binding := _region_binding(region_catalog, region_index, false)
	if not bool(region_binding.get("valid", false)):
		return {}
	var product_id := str(selection_snapshot.get("selected_trade_product", ""))
	var product_binding := _product_binding(product_catalog, product_id)
	if not bool(product_binding.get("valid", false)):
		return {}
	var requirement := _region_binding(region_catalog, int(context.get("play_requirement_district", -1)), true)
	if not bool(requirement.get("valid", false)):
		return {}
	var envelope := {
		"schema_version": SCHEMA_VERSION,
		"session_id": region_catalog.session_id,
		"session_revision": region_catalog.session_revision,
		"selection_revision": int(selection_snapshot.get("revision", -1)),
		"region_id": str(region_binding.get("region_id", "")),
		"region_public_index_at_capture": int(region_binding.get("public_index", -1)),
		"region_ordering_revision": region_catalog.ordering_revision,
		"region_ordering_fingerprint": region_catalog.ordering_fingerprint,
		"product_id": str(product_binding.get("product_id", "")),
		"product_public_index_at_capture": int(product_binding.get("public_index", -1)),
		"product_ordering_revision": product_catalog.ordering_revision,
		"product_ordering_fingerprint": product_catalog.ordering_fingerprint,
		"selected_card_resolution_id": int(selection_snapshot.get("selected_card_resolution_id", -1)),
		"target_kind": str(context.get("target_kind", TARGET_NONE)),
		"target_slot": int(context.get("target_slot", -1)),
		"target_monster_uid": int(context.get("target_monster_uid", -1)),
		"target_player": int(context.get("target_player", -1)),
		"play_requirement_region_id": str(requirement.get("region_id", "")),
		"play_requirement_public_index_at_capture": int(requirement.get("public_index", -1)),
		"capture_source": str(context.get("capture_source", "card_play_submission")),
	}
	envelope["envelope_fingerprint"] = _fingerprint(envelope)
	return envelope if bool(validate(envelope).get("valid", false)) else {}


static func bind_target(envelope: Dictionary, target_kind: String, target_slot: int, target_player: int, target_monster_uid: int = -1) -> Dictionary:
	if not bool(validate(envelope).get("valid", false)) or target_kind not in TARGET_KINDS:
		return {}
	var result := envelope.duplicate(true)
	result["target_kind"] = target_kind
	result["target_slot"] = target_slot
	result["target_monster_uid"] = target_monster_uid
	result["target_player"] = target_player
	result["envelope_fingerprint"] = _fingerprint(result)
	return result if bool(validate(result).get("valid", false)) else {}


static func bind_requirement(envelope: Dictionary, district_index: int, region_id: String) -> Dictionary:
	if not bool(validate(envelope).get("valid", false)):
		return {}
	var result := envelope.duplicate(true)
	result["play_requirement_public_index_at_capture"] = district_index
	result["play_requirement_region_id"] = region_id if district_index >= 0 else ""
	result["envelope_fingerprint"] = _fingerprint(result)
	return result if bool(validate(result).get("valid", false)) else {}


static func validate(envelope: Dictionary) -> Dictionary:
	if not TablePresentationPureDataPolicy.is_pure_data(envelope):
		return _invalid("stable_target_not_pure_data")
	if envelope.size() != ALLOWED_KEYS.size():
		return _invalid("stable_target_key_count_invalid")
	for key_variant in envelope.keys():
		if not ALLOWED_KEYS.has(str(key_variant)):
			return _invalid("stable_target_key_not_allowed")
	for key in [
		"session_id", "region_id", "region_ordering_revision", "region_ordering_fingerprint",
		"product_id", "product_ordering_revision", "product_ordering_fingerprint", "target_kind",
		"play_requirement_region_id",
		"capture_source", "envelope_fingerprint",
	]:
		if not envelope.has(key) or typeof(envelope[key]) != TYPE_STRING:
			return _invalid("stable_target_type_invalid")
	for key in [
		"schema_version", "session_revision", "selection_revision", "region_public_index_at_capture",
		"product_public_index_at_capture", "selected_card_resolution_id", "target_slot", "target_monster_uid", "target_player",
		"play_requirement_public_index_at_capture",
	]:
		if not envelope.has(key) or typeof(envelope[key]) != TYPE_INT:
			return _invalid("stable_target_type_invalid")
	if int(envelope["schema_version"]) != SCHEMA_VERSION:
		return _invalid("stable_target_schema_invalid")
	if not _text_id(str(envelope["session_id"]), false) or int(envelope["session_revision"]) <= 0:
		return _invalid("stable_target_session_invalid")
	if int(envelope["selection_revision"]) < 0:
		return _invalid("stable_target_selection_revision_invalid")
	if not _text_id(str(envelope["region_id"]), false) or int(envelope["region_public_index_at_capture"]) < 0:
		return _invalid("stable_target_region_invalid")
	if not _sha256(str(envelope["region_ordering_revision"])) or not _sha256(str(envelope["region_ordering_fingerprint"])):
		return _invalid("stable_target_region_catalog_binding_invalid")
	var product_id := str(envelope["product_id"])
	var product_index := int(envelope["product_public_index_at_capture"])
	if (product_id.is_empty() and product_index != -1) or (not product_id.is_empty() and (not _text_id(product_id, false) or product_index < 0)):
		return _invalid("stable_target_product_invalid")
	if not _sha256(str(envelope["product_ordering_revision"])) or not _sha256(str(envelope["product_ordering_fingerprint"])):
		return _invalid("stable_target_product_catalog_binding_invalid")
	if int(envelope["selected_card_resolution_id"]) < -1:
		return _invalid("stable_target_resolution_invalid")
	var target_kind := str(envelope["target_kind"])
	var target_slot := int(envelope["target_slot"])
	var target_monster_uid := int(envelope["target_monster_uid"])
	var target_player := int(envelope["target_player"])
	if target_kind not in TARGET_KINDS:
		return _invalid("stable_target_kind_invalid")
	if target_kind == TARGET_NONE and (target_slot != -1 or target_monster_uid != -1 or target_player != -1):
		return _invalid("stable_target_none_binding_invalid")
	if target_kind == TARGET_MONSTER and (target_player != -1 or not ((target_slot == -1 and target_monster_uid == -1) or (target_slot >= 0 and target_monster_uid > 0))):
		return _invalid("stable_target_monster_binding_invalid")
	if target_kind == TARGET_PLAYER and (target_player < -1 or target_slot != -1 or target_monster_uid != -1):
		return _invalid("stable_target_player_binding_invalid")
	var requirement_region_id := str(envelope["play_requirement_region_id"])
	var requirement_public_index := int(envelope["play_requirement_public_index_at_capture"])
	if (requirement_region_id.is_empty() and requirement_public_index != -1) \
			or (not requirement_region_id.is_empty() and (not _text_id(requirement_region_id, false) or requirement_public_index < 0)):
		return _invalid("stable_target_optional_region_binding_invalid")
	if not _text_id(str(envelope["capture_source"]), false):
		return _invalid("stable_target_capture_source_invalid")
	var expected := _fingerprint(envelope)
	if not _sha256(str(envelope["envelope_fingerprint"])) or str(envelope["envelope_fingerprint"]) != expected:
		return _invalid("stable_target_fingerprint_mismatch")
	return {"valid": true, "reason_code": "", "envelope_fingerprint": expected}


static func validate_entry_binding(entry: Dictionary) -> Dictionary:
	var envelope_variant: Variant = entry.get("stable_target_envelope", {})
	if not (envelope_variant is Dictionary):
		return _invalid("stable_target_envelope_missing")
	var envelope := envelope_variant as Dictionary
	var validation := validate(envelope)
	if not bool(validation.get("valid", false)):
		return validation
	var target_kind := str(envelope["target_kind"])
	if target_kind == TARGET_MONSTER and int(envelope["target_slot"]) < 0:
		return _invalid("stable_target_monster_unresolved")
	if target_kind == TARGET_PLAYER and int(envelope["target_player"]) < 0:
		return _invalid("stable_target_player_unresolved")
	var mirrors_match := int(entry.get("selected_district", -2)) == int(envelope["region_public_index_at_capture"]) \
		and str(entry.get("selected_trade_product", "\u0000")) == str(envelope["product_id"]) \
		and int(entry.get("selected_card_resolution_id", -2)) == int(envelope["selected_card_resolution_id"]) \
		and int(entry.get("target_slot", -2)) == int(envelope["target_slot"]) \
		and int(entry.get("target_monster_uid", -2)) == int(envelope["target_monster_uid"]) \
		and int(entry.get("target_player", -2)) == int(envelope["target_player"]) \
		and int(entry.get("play_requirement_district", -2)) == int(envelope["play_requirement_public_index_at_capture"])
	if not mirrors_match:
		return _invalid("stable_target_legacy_mirror_mismatch")
	return {"valid": true, "reason_code": "", "envelope": envelope.duplicate(true)}


static func context_at_capture(envelope: Dictionary) -> Dictionary:
	if not bool(validate(envelope).get("valid", false)):
		return {}
	return {
		"selected_district": int(envelope["region_public_index_at_capture"]),
		"selected_trade_product": str(envelope["product_id"]),
		"selected_card_resolution_id": int(envelope["selected_card_resolution_id"]),
		"target_slot": int(envelope["target_slot"]),
		"target_monster_uid": int(envelope["target_monster_uid"]),
		"target_player": int(envelope["target_player"]),
		"play_requirement_district": int(envelope["play_requirement_public_index_at_capture"]),
	}


static func resolve_for_world(
	envelope: Dictionary,
	world_session_state: WorldSessionState,
	region_catalog: PublicRegionSelectionCatalogSnapshot = null,
	product_catalog: PublicProductSelectionCatalogSnapshot = null
) -> Dictionary:
	var validation := validate(envelope)
	if not bool(validation.get("valid", false)):
		return validation
	if world_session_state == null:
		return _invalid("stable_target_world_unavailable")
	if region_catalog != null or product_catalog != null:
		if region_catalog == null or product_catalog == null \
				or not region_catalog.is_valid() or not product_catalog.is_valid() \
				or not region_catalog.available or not product_catalog.available:
			return _invalid("stable_target_catalog_unavailable")
		if region_catalog.session_id != str(envelope["session_id"]) \
				or product_catalog.session_id != str(envelope["session_id"]):
			return _invalid("stable_target_session_mismatch")
		if region_catalog.entry_by_id(str(envelope["region_id"])) == null:
			return _invalid("stable_target_region_missing")
		var product_id := str(envelope["product_id"])
		if not product_id.is_empty() and product_catalog.entry_by_id(product_id) == null:
			return _invalid("stable_target_product_missing")
	var context := context_at_capture(envelope)
	var region_index := world_session_state.district_index_for_region_id(str(envelope["region_id"]))
	if region_index < 0:
		return _invalid("stable_target_region_missing")
	context["selected_district"] = region_index
	var requirement_region_id := str(envelope["play_requirement_region_id"])
	if requirement_region_id.is_empty():
		context["play_requirement_district"] = -1
	else:
		var resolved_index := world_session_state.district_index_for_region_id(requirement_region_id)
		if resolved_index < 0:
			return _invalid("stable_target_optional_region_missing")
		context["play_requirement_district"] = resolved_index
	return {
		"valid": true,
		"reason_code": "",
		"context": context,
		"envelope": envelope.duplicate(true),
	}


static func resolved_entry(
	entry: Dictionary,
	world_session_state: WorldSessionState,
	region_catalog: PublicRegionSelectionCatalogSnapshot = null,
	product_catalog: PublicProductSelectionCatalogSnapshot = null
) -> Dictionary:
	var binding := validate_entry_binding(entry)
	if not bool(binding.get("valid", false)):
		return binding
	var envelope := binding.get("envelope", {}) as Dictionary
	var resolution := resolve_for_world(envelope, world_session_state, region_catalog, product_catalog)
	if not bool(resolution.get("valid", false)):
		return resolution
	var context := resolution.get("context", {}) as Dictionary
	var result := entry.duplicate(true)
	for key in context.keys():
		result[key] = context[key]
	var skill_variant: Variant = result.get("skill", {})
	if skill_variant is Dictionary:
		var skill := (skill_variant as Dictionary).duplicate(true)
		if str(skill.get("kind", "")) == "public_facility" and skill.has("target_region_index"):
			skill["target_region_index"] = int(context["selected_district"])
		result["skill"] = skill
	return {
		"valid": true,
		"reason_code": "",
		"entry": result,
		"context": context.duplicate(true),
		"envelope": envelope.duplicate(true),
	}


static func card_fingerprint(skill: Dictionary) -> String:
	if skill.is_empty() or not TablePresentationPureDataPolicy.is_pure_data(skill):
		return ""
	return JSON.stringify(_canonicalize(skill)).sha256_text()


static func _region_binding(catalog: PublicRegionSelectionCatalogSnapshot, public_index: int, optional: bool) -> Dictionary:
	if optional and public_index < 0:
		return {"valid": true, "region_id": "", "public_index": -1}
	for entry in catalog.entries:
		if entry.public_index == public_index:
			return {"valid": true, "region_id": entry.region_id, "public_index": entry.public_index}
	return {"valid": false}


static func _product_binding(catalog: PublicProductSelectionCatalogSnapshot, product_id: String) -> Dictionary:
	if product_id.is_empty():
		return {"valid": true, "product_id": "", "public_index": -1}
	var entry := catalog.entry_by_id(product_id)
	return {"valid": true, "product_id": entry.product_id, "public_index": entry.public_index} if entry != null else {"valid": false}


static func _fingerprint(envelope: Dictionary) -> String:
	var source := envelope.duplicate(true)
	source.erase("envelope_fingerprint")
	return JSON.stringify(_canonicalize(source)).sha256_text()


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array[String] = []
		for key_variant in (value as Dictionary).keys():
			keys.append(str(key_variant))
		keys.sort()
		for key in keys:
			result[key] = _canonicalize((value as Dictionary).get(key))
		return result
	if value is Array:
		var result: Array = []
		for child in value as Array:
			result.append(_canonicalize(child))
		return result
	return value


static func _text_id(value: String, allow_empty: bool) -> bool:
	if value.is_empty():
		return allow_empty
	if value.length() > 160 or value != value.strip_edges():
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if code < 32 or code == 127:
			return false
	return true


static func _sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


static func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code}
