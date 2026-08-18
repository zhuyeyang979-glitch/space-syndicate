extends RefCounted
class_name V075PresentationReceiptIdentityV2

const SCHEMA := "PresentationReceiptIdentityV2"
const SCHEMA_VERSION := 2
const PAYLOAD_SCHEMA := "V075CombatPresentationCanonicalPayloadV2"
const PAYLOAD_SCHEMA_VERSION := 2
const ID_DOMAIN := "presentation_receipt_v2"
const AUDIENCE_KEY_DOMAIN := "presentation_audience_v2"
const OBSERVER_CORRELATION_DOMAIN := "presentation_observer_correlation_v1"
const PUBLIC_AUDIENCE_SCOPE := "PUBLIC"
const AUDIENCE_SCOPES := [
	"PUBLIC",
	"PLAYER_PRIVATE",
	"LOCAL_PRESENTATION_ONLY",
]
const PRESENTATION_ID_PREFIX := "presentation.v2."

const PUBLIC_SEMANTIC_FIELDS := [
	"public_effect_id",
	"source_public_name",
	"source_instance_id",
	"source_generation",
	"source_rank",
	"monster_family_id",
	"monster_card_mode",
	"old_rank",
	"new_rank",
	"refresh_percent",
	"preferred_industry_color",
	"movement_profile",
	"movement_id",
	"trample_region_receipt_id",
	"start_region_id",
	"destination_region_id",
	"region_id",
	"target_region_id",
	"target_facility_id",
	"target_monster_source_instance_id",
	"target_kind",
	"ordered_region_path",
	"distance_milli_arc",
	"region_damage_budget",
	"allocated_damage",
	"unallocated_damage",
	"damage_amount",
	"armor_absorbed",
	"hp_before",
	"hp_after",
	"armor_before",
	"armor_after",
	"damage_before",
	"damage_after",
	"max_hp",
	"destroyed",
	"status",
	"facility_type",
	"facility_damage_state",
	"military_tier",
	"task_kind",
	"outcome",
	"reason_code",
	"public_summary",
	"public_presentation_key",
	"effect_summary_key",
	"status_changes",
	"facility_damage_receipt_ids",
]
const PUBLIC_STRING_FIELDS := [
	"public_effect_id",
	"source_public_name",
	"source_instance_id",
	"monster_family_id",
	"monster_card_mode",
	"preferred_industry_color",
	"movement_profile",
	"movement_id",
	"trample_region_receipt_id",
	"start_region_id",
	"destination_region_id",
	"region_id",
	"target_region_id",
	"target_facility_id",
	"target_monster_source_instance_id",
	"target_kind",
	"status",
	"facility_type",
	"facility_damage_state",
	"task_kind",
	"outcome",
	"reason_code",
	"public_summary",
	"public_presentation_key",
	"effect_summary_key",
]
const PUBLIC_INTEGER_FIELDS := [
	"source_generation",
	"source_rank",
	"old_rank",
	"new_rank",
	"refresh_percent",
	"distance_milli_arc",
	"region_damage_budget",
	"allocated_damage",
	"unallocated_damage",
	"damage_amount",
	"armor_absorbed",
	"hp_before",
	"hp_after",
	"armor_before",
	"armor_after",
	"damage_before",
	"damage_after",
	"max_hp",
	"military_tier",
]
const PUBLIC_BOOLEAN_FIELDS := ["destroyed"]
const PUBLIC_STRING_ARRAY_FIELDS := [
	"ordered_region_path",
	"facility_damage_receipt_ids",
]
const PUBLIC_STRUCTURED_ARRAY_FIELDS := ["status_changes"]
const FORBIDDEN_PUBLIC_FRAGMENTS := [
	"skill_definition",
	"skill_card",
	"asset_cost",
	"cooldown_remaining",
	"private",
	"future",
	"request_sequence",
	"internal_order",
	"hidden",
	"rng_state",
]
const REQUIRED_FIELDS := [
	"schema",
	"schema_version",
	"payload_schema",
	"payload_schema_version",
	"presentation_receipt_id",
	"source_receipt_id",
	"source_receipt_fingerprint",
	"observer_correlation_id",
	"observer_correlation_fingerprint",
	"source_authority_sequence",
	"presentation_kind",
	"presentation_ordinal",
	"audience_scope",
	"audience_key_fingerprint",
	"ruleset_id",
	"session_id",
	"canonical_payload",
	"canonical_payload_fingerprint",
]


static func build_public(
	source_receipt_id: String,
	source_receipt_fingerprint: String,
	source_authority_sequence: int,
	presentation_kind: String,
	presentation_ordinal: int,
	ruleset_id: String,
	session_id: String,
	public_payload_source: Dictionary,
	observer_correlation_id: String = ""
) -> Dictionary:
	return build_for_audience(
		source_receipt_id,
		source_receipt_fingerprint,
		source_authority_sequence,
		presentation_kind,
		presentation_ordinal,
		PUBLIC_AUDIENCE_SCOPE,
		PUBLIC_AUDIENCE_SCOPE,
		ruleset_id,
		session_id,
		public_payload_source,
		observer_correlation_id
	)


static func build_for_audience(
	source_receipt_id: String,
	source_receipt_fingerprint: String,
	source_authority_sequence: int,
	presentation_kind: String,
	presentation_ordinal: int,
	audience_scope: String,
	audience_key: String,
	ruleset_id: String,
	session_id: String,
	authorized_payload_source: Dictionary,
	observer_correlation_id: String = ""
) -> Dictionary:
	if (
		source_receipt_id.is_empty()
		or not valid_sha256(source_receipt_fingerprint)
		or source_authority_sequence < 0
		or presentation_kind.is_empty()
		or presentation_ordinal < 0
		or audience_scope not in AUDIENCE_SCOPES
		or audience_key.is_empty()
		or ruleset_id.is_empty()
		or session_id.is_empty()
	):
		return {}
	if not _public_payload_types_valid(authorized_payload_source):
		return {}
	var canonical_payload := project_public_payload(authorized_payload_source)
	var resolved_observer_correlation_id := observer_correlation_id
	if resolved_observer_correlation_id.is_empty():
		resolved_observer_correlation_id = source_receipt_id
	if _forbidden_fragment_count(canonical_payload) > 0:
		return {}
	var audience_key_fingerprint := canonical_sha256({
		"domain": AUDIENCE_KEY_DOMAIN,
		"ruleset_id": ruleset_id,
		"session_id": session_id,
		"audience_scope": audience_scope,
		"audience_key": audience_key,
	})
	var identity_binding := _identity_binding(
		source_receipt_id,
		source_authority_sequence,
		presentation_kind,
		presentation_ordinal,
		audience_scope,
		audience_key_fingerprint,
		ruleset_id,
		session_id
	)
	var presentation_receipt_id := (
		PRESENTATION_ID_PREFIX + canonical_sha256(identity_binding)
	)
	var semantic_envelope := _semantic_envelope(
		source_receipt_id,
		source_receipt_fingerprint,
		source_authority_sequence,
		presentation_kind,
		presentation_ordinal,
		audience_scope,
		audience_key_fingerprint,
		ruleset_id,
		session_id,
		canonical_payload
	)
	var observer_correlation_fingerprint := canonical_sha256({
		"domain": OBSERVER_CORRELATION_DOMAIN,
		"presentation_receipt_id": presentation_receipt_id,
		"observer_correlation_id": resolved_observer_correlation_id,
	})
	return {
		"schema": SCHEMA,
		"schema_version": SCHEMA_VERSION,
		"payload_schema": PAYLOAD_SCHEMA,
		"payload_schema_version": PAYLOAD_SCHEMA_VERSION,
		"presentation_receipt_id": presentation_receipt_id,
		"source_receipt_id": source_receipt_id,
		"source_receipt_fingerprint": source_receipt_fingerprint,
		"observer_correlation_id": resolved_observer_correlation_id,
		"observer_correlation_fingerprint": observer_correlation_fingerprint,
		"source_authority_sequence": source_authority_sequence,
		"presentation_kind": presentation_kind,
		"presentation_ordinal": presentation_ordinal,
		"audience_scope": audience_scope,
		"audience_key_fingerprint": audience_key_fingerprint,
		"ruleset_id": ruleset_id,
		"session_id": session_id,
		"canonical_payload": canonical_payload.duplicate(true),
		"canonical_payload_fingerprint": canonical_sha256(semantic_envelope),
	}


static func validate(receipt: Dictionary) -> Dictionary:
	if receipt.size() != REQUIRED_FIELDS.size():
		return _invalid("presentation_receipt_v2_fields_invalid")
	for key_variant in receipt.keys():
		if not (key_variant is String) or str(key_variant) not in REQUIRED_FIELDS:
			return _invalid("presentation_receipt_v2_fields_invalid")
	for field_name in REQUIRED_FIELDS:
		if not receipt.has(field_name):
			return _invalid("presentation_receipt_v2_field_missing:%s" % field_name)
	if (
		str(receipt.get("schema", "")) != SCHEMA
		or int(receipt.get("schema_version", -1)) != SCHEMA_VERSION
		or str(receipt.get("payload_schema", "")) != PAYLOAD_SCHEMA
		or int(receipt.get("payload_schema_version", -1)) != PAYLOAD_SCHEMA_VERSION
	):
		return _invalid("presentation_receipt_v2_schema_invalid")
	if (
		not (receipt.get("schema") is String)
		or not (receipt.get("payload_schema") is String)
		or not (receipt.get("presentation_receipt_id") is String)
		or not (receipt.get("source_receipt_id") is String)
		or not (receipt.get("source_receipt_fingerprint") is String)
		or not (receipt.get("observer_correlation_id") is String)
		or not (receipt.get("observer_correlation_fingerprint") is String)
		or not (receipt.get("presentation_kind") is String)
		or not (receipt.get("audience_scope") is String)
		or not (receipt.get("audience_key_fingerprint") is String)
		or not (receipt.get("ruleset_id") is String)
		or not (receipt.get("session_id") is String)
		or not (receipt.get("canonical_payload_fingerprint") is String)
		or not (receipt.get("schema_version") is int)
		or not (receipt.get("payload_schema_version") is int)
		or not (receipt.get("source_authority_sequence") is int)
		or not (receipt.get("presentation_ordinal") is int)
		or int(receipt.get("source_authority_sequence", -1)) < 0
		or int(receipt.get("presentation_ordinal", -1)) < 0
		or not (receipt.get("canonical_payload") is Dictionary)
	):
		return _invalid("presentation_receipt_v2_type_invalid")
	var source_receipt_id := str(receipt.get("source_receipt_id", ""))
	var observer_correlation_id := str(
		receipt.get("observer_correlation_id", "")
	)
	var observer_correlation_fingerprint := str(
		receipt.get("observer_correlation_fingerprint", "")
	)
	var source_fingerprint_value := str(
		receipt.get("source_receipt_fingerprint", "")
	)
	var presentation_kind := str(receipt.get("presentation_kind", ""))
	var audience_scope := str(receipt.get("audience_scope", ""))
	var audience_key_fingerprint := str(
		receipt.get("audience_key_fingerprint", "")
	)
	var ruleset_id := str(receipt.get("ruleset_id", ""))
	var session_id := str(receipt.get("session_id", ""))
	if (
		source_receipt_id.is_empty()
		or observer_correlation_id.is_empty()
		or not valid_sha256(source_fingerprint_value)
		or not valid_sha256(observer_correlation_fingerprint)
		or presentation_kind.is_empty()
		or audience_scope not in AUDIENCE_SCOPES
		or not valid_sha256(audience_key_fingerprint)
		or (
			audience_scope == PUBLIC_AUDIENCE_SCOPE
			and audience_key_fingerprint != canonical_sha256({
				"domain": AUDIENCE_KEY_DOMAIN,
				"ruleset_id": ruleset_id,
				"session_id": session_id,
				"audience_scope": audience_scope,
				"audience_key": PUBLIC_AUDIENCE_SCOPE,
			})
		)
		or ruleset_id.is_empty()
		or session_id.is_empty()
	):
		return _invalid("presentation_receipt_v2_identity_invalid")
	var canonical_payload := (
		receipt.get("canonical_payload", {}) as Dictionary
	).duplicate(true)
	if not _canonical_payload_fields_valid(canonical_payload):
		return _invalid("presentation_receipt_v2_payload_type_invalid")
	if _forbidden_fragment_count(canonical_payload) > 0:
		return _invalid("presentation_receipt_v2_payload_private")
	var sequence := int(receipt.get("source_authority_sequence", -1))
	var ordinal := int(receipt.get("presentation_ordinal", -1))
	var expected_id := PRESENTATION_ID_PREFIX + canonical_sha256(
		_identity_binding(
			source_receipt_id,
			sequence,
			presentation_kind,
			ordinal,
			audience_scope,
			audience_key_fingerprint,
			ruleset_id,
			session_id
		)
	)
	if str(receipt.get("presentation_receipt_id", "")) != expected_id:
		return _invalid("presentation_receipt_v2_id_mismatch")
	var expected_observer_fingerprint := canonical_sha256({
		"domain": OBSERVER_CORRELATION_DOMAIN,
		"presentation_receipt_id": expected_id,
		"observer_correlation_id": observer_correlation_id,
	})
	if observer_correlation_fingerprint != expected_observer_fingerprint:
		return _invalid("presentation_receipt_v2_observer_correlation_mismatch")
	var expected_fingerprint := canonical_sha256(
		_semantic_envelope(
			source_receipt_id,
			source_fingerprint_value,
			sequence,
			presentation_kind,
			ordinal,
			audience_scope,
			audience_key_fingerprint,
			ruleset_id,
			session_id,
			canonical_payload
		)
	)
	if str(receipt.get("canonical_payload_fingerprint", "")) != expected_fingerprint:
		return _invalid("presentation_receipt_v2_fingerprint_mismatch")
	return {
		"valid": true,
		"reason_code": "none",
		"presentation_receipt_id": expected_id,
		"canonical_payload_fingerprint": expected_fingerprint,
		"observer_correlation_fingerprint": expected_observer_fingerprint,
	}


static func project_public_payload(source: Dictionary) -> Dictionary:
	var result := {}
	for field_name in PUBLIC_SEMANTIC_FIELDS:
		if source.has(field_name):
			result[field_name] = _safe_copy(source.get(field_name))
	return result


static func source_fingerprint(
	source_receipt_id: String,
	source: Dictionary
) -> String:
	return canonical_sha256({
		"source_receipt_id": source_receipt_id,
		"source": source.duplicate(true),
	})


static func normalize_serialized_receipt(receipt: Dictionary) -> Dictionary:
	var result := receipt.duplicate(true)
	for field_name in [
		"schema_version",
		"payload_schema_version",
		"source_authority_sequence",
		"presentation_ordinal",
	]:
		if result.has(field_name):
			result[field_name] = _normalize_json_integer(result.get(field_name))
	if result.get("canonical_payload") is Dictionary:
		var payload := (
			result.get("canonical_payload", {}) as Dictionary
		).duplicate(true)
		for field_name in PUBLIC_INTEGER_FIELDS:
			if payload.has(field_name):
				payload[field_name] = _normalize_json_integer(
					payload.get(field_name)
				)
		for field_name in PUBLIC_STRUCTURED_ARRAY_FIELDS:
			if payload.has(field_name):
				payload[field_name] = _normalize_json_value(
					payload.get(field_name)
				)
		result["canonical_payload"] = payload
	return result


static func normalize_serialized_public_payload(payload: Dictionary) -> Dictionary:
	var result := payload.duplicate(true)
	for field_name in PUBLIC_INTEGER_FIELDS:
		if result.has(field_name):
			result[field_name] = _normalize_json_integer(result.get(field_name))
	for field_name in PUBLIC_STRUCTURED_ARRAY_FIELDS:
		if result.has(field_name):
			result[field_name] = _normalize_json_value(result.get(field_name))
	return result


static func valid_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


static func canonical_sha256(value: Variant) -> String:
	return canonical_json(value).sha256_text()


static func canonical_json(value: Variant) -> String:
	if value is Dictionary:
		var dictionary := value as Dictionary
		var keys: Array[String] = []
		for key_variant in dictionary.keys():
			keys.append(str(key_variant))
		keys.sort()
		var fields: Array[String] = []
		for key in keys:
			fields.append(
				"%s:%s" % [
					JSON.stringify(key),
					canonical_json(dictionary.get(key)),
				]
			)
		return "{%s}" % ",".join(fields)
	if value is Array:
		var items: Array[String] = []
		for item in value as Array:
			items.append(canonical_json(item))
		return "[%s]" % ",".join(items)
	return JSON.stringify(value)


static func _identity_binding(
	source_receipt_id: String,
	sequence: int,
	presentation_kind: String,
	ordinal: int,
	audience_scope: String,
	audience_key_fingerprint: String,
	ruleset_id: String,
	session_id: String
) -> Dictionary:
	return {
		"domain": ID_DOMAIN,
		"schema_version": SCHEMA_VERSION,
		"payload_schema_version": PAYLOAD_SCHEMA_VERSION,
		"ruleset_id": ruleset_id,
		"session_id": session_id,
		"source_receipt_id": source_receipt_id,
		"source_authority_sequence": sequence,
		"presentation_kind": presentation_kind,
		"presentation_ordinal": ordinal,
		"audience_scope": audience_scope,
		"audience_key_fingerprint": audience_key_fingerprint,
	}


static func _semantic_envelope(
	source_receipt_id: String,
	source_receipt_fingerprint: String,
	sequence: int,
	presentation_kind: String,
	ordinal: int,
	audience_scope: String,
	audience_key_fingerprint: String,
	ruleset_id: String,
	session_id: String,
	canonical_payload: Dictionary
) -> Dictionary:
	var result := _identity_binding(
		source_receipt_id,
		sequence,
		presentation_kind,
		ordinal,
		audience_scope,
		audience_key_fingerprint,
		ruleset_id,
		session_id
	)
	result["source_receipt_fingerprint"] = source_receipt_fingerprint
	result["canonical_payload"] = canonical_payload.duplicate(true)
	return result


static func _forbidden_fragment_count(value: Variant) -> int:
	var count := 0
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			var key := str(key_variant).to_lower()
			for fragment in FORBIDDEN_PUBLIC_FRAGMENTS:
				if str(fragment) in key:
					count += 1
					break
			count += _forbidden_fragment_count(dictionary.get(key_variant))
	elif value is Array:
		for child in value as Array:
			count += _forbidden_fragment_count(child)
	return count


static func _public_payload_types_valid(source: Dictionary) -> bool:
	for field_name in PUBLIC_STRING_FIELDS:
		if source.has(field_name) and not (source.get(field_name) is String):
			return false
	for field_name in PUBLIC_INTEGER_FIELDS:
		if source.has(field_name) and not (source.get(field_name) is int):
			return false
	for field_name in PUBLIC_BOOLEAN_FIELDS:
		if source.has(field_name) and not (source.get(field_name) is bool):
			return false
	for field_name in PUBLIC_STRING_ARRAY_FIELDS:
		if source.has(field_name):
			if not (source.get(field_name) is Array):
				return false
			for item in source.get(field_name) as Array:
				if not (item is String):
					return false
	for field_name in PUBLIC_STRUCTURED_ARRAY_FIELDS:
		if source.has(field_name):
			if not (source.get(field_name) is Array):
				return false
			if not _canonical_value_supported(source.get(field_name)):
				return false
	return true


static func _canonical_payload_fields_valid(source: Dictionary) -> bool:
	for key_variant in source.keys():
		if not (key_variant is String) or str(key_variant) not in PUBLIC_SEMANTIC_FIELDS:
			return false
	return _public_payload_types_valid(source)


static func _canonical_value_supported(value: Variant) -> bool:
	if value == null or value is bool or value is int or value is String:
		return true
	if value is Array:
		for item in value as Array:
			if not _canonical_value_supported(item):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if (
				not (key_variant is String)
				or not _canonical_value_supported(
					(value as Dictionary).get(key_variant)
				)
			):
				return false
		return true
	return false


static func _normalize_json_integer(value: Variant) -> Variant:
	if not (value is float):
		return value
	var number := float(value)
	if not is_finite(number) or floor(number) != number:
		return value
	return int(number)


static func _normalize_json_value(value: Variant) -> Variant:
	if value is float:
		return _normalize_json_integer(value)
	if value is Array:
		var normalized_array := []
		for item in value as Array:
			normalized_array.append(_normalize_json_value(item))
		return normalized_array
	if value is Dictionary:
		var normalized_dictionary := {}
		for key_variant in (value as Dictionary).keys():
			normalized_dictionary[key_variant] = _normalize_json_value(
				(value as Dictionary).get(key_variant)
			)
		return normalized_dictionary
	return value


static func _safe_copy(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value


static func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code}
