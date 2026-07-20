extends RefCounted
class_name ProductMarketFrozenTargetContext

const SCHEMA_VERSION := 1
const SOURCE_STABLE_ENVELOPE := "card_resolution_stable_target_envelope"
const SOURCE_LEGACY_ENTRY := "legacy_card_resolution_entry"
const SOURCES := [SOURCE_STABLE_ENVELOPE, SOURCE_LEGACY_ENTRY]
const ALLOWED_KEYS := [
	"schema_version",
	"source",
	"session_id",
	"session_revision",
	"region_id",
	"region_public_index_at_capture",
	"region_ordering_revision",
	"region_ordering_fingerprint",
	"region_district_index",
	"product_id",
	"product_public_index_at_capture",
	"product_ordering_revision",
	"product_ordering_fingerprint",
	"warehouse_required",
	"warehouse_region_id",
	"warehouse_district_index",
	"resolution_id",
	"envelope_fingerprint",
	"context_fingerprint",
]

const StableTargetEnvelope := preload("res://scripts/runtime/card_resolution_stable_target_envelope.gd")


static func from_entry(entry: Dictionary, world_session_state: WorldSessionState, requires_warehouse: bool) -> Dictionary:
	if world_session_state == null or entry.is_empty():
		return _invalid("product_target_context_world_unavailable")
	var envelope_variant: Variant = entry.get("stable_target_envelope", {})
	var has_stable_envelope := envelope_variant is Dictionary and not (envelope_variant as Dictionary).is_empty()
	var source := SOURCE_STABLE_ENVELOPE if has_stable_envelope else SOURCE_LEGACY_ENTRY
	var envelope: Dictionary = envelope_variant as Dictionary if has_stable_envelope else {}
	var product_id := ""
	var region_id := ""
	var region_capture_index := -1
	var product_capture_index := -1
	var session_id := ""
	var session_revision := 0
	var region_ordering_revision := ""
	var region_ordering_fingerprint := ""
	var product_ordering_revision := ""
	var product_ordering_fingerprint := ""
	var envelope_fingerprint := ""
	var resolution_id := int(entry.get("resolution_id", entry.get("selected_card_resolution_id", -1)))
	if has_stable_envelope:
		var envelope_validation := StableTargetEnvelope.validate(envelope)
		if not bool(envelope_validation.get("valid", false)):
			return _invalid(str(envelope_validation.get("reason_code", "product_target_envelope_invalid")))
		product_id = str(envelope.get("product_id", ""))
		region_id = str(envelope.get("region_id", ""))
		region_capture_index = int(envelope.get("region_public_index_at_capture", -1))
		product_capture_index = int(envelope.get("product_public_index_at_capture", -1))
		session_id = str(envelope.get("session_id", ""))
		session_revision = int(envelope.get("session_revision", 0))
		region_ordering_revision = str(envelope.get("region_ordering_revision", ""))
		region_ordering_fingerprint = str(envelope.get("region_ordering_fingerprint", ""))
		product_ordering_revision = str(envelope.get("product_ordering_revision", ""))
		product_ordering_fingerprint = str(envelope.get("product_ordering_fingerprint", ""))
		envelope_fingerprint = str(envelope.get("envelope_fingerprint", ""))
		resolution_id = int(envelope.get("selected_card_resolution_id", resolution_id))
	else:
		# Legacy queue entries are allowed to use only their detached numeric mirrors.
		# They never sample TableSelectionState or call back into Main.
		product_id = str(entry.get("selected_trade_product", ""))
		var numeric_region := int(entry.get("selected_district", -1))
		if numeric_region >= 0:
			region_id = world_session_state.region_id_for_district(numeric_region)
			region_capture_index = numeric_region
		if product_id.is_empty() or region_id.is_empty():
			return _invalid("product_target_context_missing")
	var region_index := world_session_state.district_index_for_region_id(region_id)
	if region_index < 0:
		return _invalid("product_target_region_missing")
	if str(entry.get("selected_trade_product", product_id)) != product_id:
		return _invalid("product_target_product_mirror_mismatch")
	if has_stable_envelope and int(entry.get("selected_district", -1)) != region_index:
		return _invalid("product_target_region_mirror_mismatch")
	if product_id.is_empty():
		return _invalid("product_target_product_missing")
	var warehouse_region_id := region_id if requires_warehouse else ""
	var warehouse_district_index := region_index if requires_warehouse else -1
	var context := {
		"schema_version": SCHEMA_VERSION,
		"source": source,
		"session_id": session_id,
		"session_revision": session_revision,
		"region_id": region_id,
		"region_public_index_at_capture": region_capture_index,
		"region_ordering_revision": region_ordering_revision,
		"region_ordering_fingerprint": region_ordering_fingerprint,
		"region_district_index": region_index,
		"product_id": product_id,
		"product_public_index_at_capture": product_capture_index,
		"product_ordering_revision": product_ordering_revision,
		"product_ordering_fingerprint": product_ordering_fingerprint,
		"warehouse_required": requires_warehouse,
		"warehouse_region_id": warehouse_region_id,
		"warehouse_district_index": warehouse_district_index,
		"resolution_id": resolution_id,
		"envelope_fingerprint": envelope_fingerprint,
	}
	context["context_fingerprint"] = _fingerprint(context)
	var validation := validate(context)
	return {"valid": true, "reason_code": "", "context": context.duplicate(true)} if bool(validation.get("valid", false)) else validation


static func validate(context: Dictionary) -> Dictionary:
	if not TablePresentationPureDataPolicy.is_pure_data(context):
		return _invalid("product_target_context_not_pure_data")
	if context.size() != ALLOWED_KEYS.size():
		return _invalid("product_target_context_key_count_invalid")
	for key_variant in context.keys():
		if not ALLOWED_KEYS.has(str(key_variant)):
			return _invalid("product_target_context_key_not_allowed")
	for key in ["source", "session_id", "region_id", "region_ordering_revision", "region_ordering_fingerprint", "product_id", "product_ordering_revision", "product_ordering_fingerprint", "warehouse_region_id", "envelope_fingerprint", "context_fingerprint"]:
		if not context.has(key) or typeof(context[key]) != TYPE_STRING:
			return _invalid("product_target_context_type_invalid")
	for key in ["schema_version", "session_revision", "region_public_index_at_capture", "product_public_index_at_capture", "region_district_index", "warehouse_district_index", "resolution_id"]:
		if not context.has(key) or typeof(context[key]) != TYPE_INT:
			return _invalid("product_target_context_type_invalid")
	if not context.has("warehouse_required") or typeof(context["warehouse_required"]) != TYPE_BOOL:
		return _invalid("product_target_context_type_invalid")
	if int(context["schema_version"]) != SCHEMA_VERSION or not SOURCES.has(str(context["source"])):
		return _invalid("product_target_context_schema_invalid")
	if str(context["product_id"]).is_empty() or str(context["region_id"]).is_empty():
		return _invalid("product_target_context_identity_missing")
	if int(context["region_district_index"]) < 0 or int(context["resolution_id"]) < -1:
		return _invalid("product_target_context_index_invalid")
	var stable_source := str(context["source"]) == SOURCE_STABLE_ENVELOPE
	if stable_source:
		if str(context["session_id"]).is_empty() or int(context["session_revision"]) <= 0:
			return _invalid("product_target_context_session_invalid")
		if int(context["region_public_index_at_capture"]) < 0 or int(context["product_public_index_at_capture"]) < 0:
			return _invalid("product_target_context_capture_index_invalid")
		for key in ["region_ordering_revision", "region_ordering_fingerprint", "product_ordering_revision", "product_ordering_fingerprint", "envelope_fingerprint"]:
			if not _sha256(str(context[key])):
				return _invalid("product_target_context_catalog_binding_invalid")
	else:
		if not str(context["session_id"]).is_empty() or int(context["session_revision"]) != 0:
			return _invalid("product_target_context_legacy_session_invalid")
		if int(context["region_public_index_at_capture"]) < 0 or int(context["product_public_index_at_capture"]) != -1:
			return _invalid("product_target_context_legacy_index_invalid")
		for key in ["region_ordering_revision", "region_ordering_fingerprint", "product_ordering_revision", "product_ordering_fingerprint", "envelope_fingerprint"]:
			if not str(context[key]).is_empty():
				return _invalid("product_target_context_legacy_binding_invalid")
	var warehouse_required := bool(context["warehouse_required"])
	if warehouse_required:
		if str(context["warehouse_region_id"]).is_empty() or int(context["warehouse_district_index"]) < 0:
			return _invalid("product_target_context_warehouse_missing")
		if str(context["warehouse_region_id"]) != str(context["region_id"]):
			return _invalid("product_target_context_warehouse_region_mismatch")
	else:
		if not str(context["warehouse_region_id"]).is_empty() or int(context["warehouse_district_index"]) != -1:
			return _invalid("product_target_context_unexpected_warehouse")
	var expected := _fingerprint(context)
	if not _sha256(str(context["context_fingerprint"])) or str(context["context_fingerprint"]) != expected:
		return _invalid("product_target_context_fingerprint_mismatch")
	return {"valid": true, "reason_code": "", "context_fingerprint": expected}


static func is_stable_envelope_context(context: Dictionary) -> bool:
	return str(context.get("source", "")) == SOURCE_STABLE_ENVELOPE


static func _fingerprint(context: Dictionary) -> String:
	var source := context.duplicate(true)
	source.erase("context_fingerprint")
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


static func _sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


static func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code}
