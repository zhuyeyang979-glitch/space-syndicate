extends Node
class_name RulesetSaveHandshakeService

const LEGACY_V04_SAVE_VERSION := 1
const V05_SAVE_VERSION := 2
const V06_SAVE_VERSION := 3
const V05_RULESET_ID := "v0.5"
const V06_RULESET_ID := "v0.6"
const CURRENCY_SCALE := 100
const PROFILE_SCHEMA_VERSION := 1
const ENVELOPE_SCHEMA := "space_syndicate.v06.save.v3"
const FORMAT_ID := "space_syndicate_json"
const CODEC_ID := "explicit_tagged_json_v2"
const MIGRATION_POLICY := "new_session_only"
const AUTHORIZATION_SCHEMA_VERSION := 1
const CODEC_KEY := "$codec"
const CODEC_VECTOR2 := "Vector2"
const CODEC_COLOR := "Color"
const CODEC_INT64 := "Int64"
const CODEC_FLOAT64 := "Float64"
const PRE_RESUME_SECTION_VERSIONS := {
	"ruleset": 1,
	"region_infrastructure": 1,
	"region_supply": 1,
	"commodity_flow": 2,
	"routes": 1,
	"player_mana": 1,
	"commodity_belt_visibility": 1,
	"card_inventory": 1,
	"player_organization": 1,
	"monsters": 1,
	"military": 1,
	"weather": 1,
	"card_resolution_queue": 1,
	"card_resolution_execution": 1,
	"card_resolution_history": 1,
	"ai": 1,
	"bankruptcy_neutral_estate": 1,
	"victory_control": 1,
	"session": 2,
}
const V06_TOP_LEVEL_KEYS := [
	"envelope_schema",
	"save_version",
	"ruleset_id",
	"profile_schema_version",
	"currency_scale",
	"format_id",
	"codec_id",
	"envelope_id",
	"write_id",
	"controller_state_versions",
	"section_manifest",
	"sections",
	"migration_policy",
]

@export var controller_state_version_registry_v06: ControllerStateVersionRegistryResource


func validate_envelope(payload: Dictionary) -> Dictionary:
	return validate_v06_envelope(payload)


func validate_v06_envelope(payload: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var retired_payload := LegacyContractPayloadGuardV06.validation_report(payload)
	if not bool(retired_payload.get("valid", false)):
		errors.append("retired_contract_payload_rejected")
	if payload.keys().size() != V06_TOP_LEVEL_KEYS.size():
		errors.append("top_level_field_count_mismatch")
	for key in V06_TOP_LEVEL_KEYS:
		if not payload.has(key):
			errors.append("missing_top_level:%s" % key)
	for key_variant in payload.keys():
		var key := str(key_variant)
		if not V06_TOP_LEVEL_KEYS.has(key):
			errors.append("unknown_top_level:%s" % key)
	if str(payload.get("envelope_schema", "")) != ENVELOPE_SCHEMA:
		errors.append("envelope_schema_mismatch")
	if int(payload.get("save_version", 0)) != V06_SAVE_VERSION:
		errors.append("save_version_must_be_3")
	if str(payload.get("ruleset_id", "")) != V06_RULESET_ID:
		errors.append("ruleset_id_must_be_v0.6")
	if int(payload.get("profile_schema_version", 0)) != PROFILE_SCHEMA_VERSION:
		errors.append("profile_schema_version_mismatch")
	if int(payload.get("currency_scale", 0)) != CURRENCY_SCALE:
		errors.append("currency_scale_must_be_100")
	if str(payload.get("format_id", "")) != FORMAT_ID:
		errors.append("format_id_mismatch")
	if str(payload.get("codec_id", "")) != CODEC_ID:
		errors.append("codec_id_mismatch")
	if str(payload.get("migration_policy", "")) != MIGRATION_POLICY:
		errors.append("migration_policy_mismatch")
	if not _valid_identifier(str(payload.get("envelope_id", ""))):
		errors.append("envelope_id_invalid")
	if not _valid_identifier(str(payload.get("write_id", ""))):
		errors.append("write_id_invalid")
	var registry_validation := _registry_validation()
	if not bool(registry_validation.get("valid", false)):
		for registry_error in registry_validation.get("errors", []):
			errors.append(str(registry_error))
	var expected_manifest := required_section_manifest()
	var expected_versions := required_controller_versions()
	var provided_manifest: Dictionary = payload.get("section_manifest", {}) if payload.get("section_manifest", {}) is Dictionary else {}
	var provided_versions: Dictionary = payload.get("controller_state_versions", {}) if payload.get("controller_state_versions", {}) is Dictionary else {}
	if errors.is_empty() and _is_card_inventory_allocator_v2_envelope(
		payload,
		expected_manifest,
		expected_versions
	):
		return {
			"valid": false,
			"reason_code": "allocator_cursor_missing_requires_backup",
			"errors": ["allocator_cursor_missing_requires_backup"],
			"save_version": V06_SAVE_VERSION,
			"ruleset_id": V06_RULESET_ID,
			"fingerprint": "",
			"requires_backup": true,
		}
	if not _same_data(provided_manifest, expected_manifest):
		errors.append("section_manifest_mismatch")
	if not _same_data(provided_versions, expected_versions):
		errors.append("controller_state_versions_mismatch")
	var sections: Dictionary = payload.get("sections", {}) if payload.get("sections", {}) is Dictionary else {}
	if sections.keys().size() != expected_manifest.keys().size():
		errors.append("section_count_mismatch")
	for section_key_variant in sections.keys():
		var section_key := str(section_key_variant)
		if not expected_manifest.has(section_key):
			errors.append("unknown_section:%s" % section_key)
	for section_key_variant in expected_manifest.keys():
		var section_key := str(section_key_variant)
		if not sections.has(section_key):
			errors.append("missing_section:%s" % section_key)
			continue
		var section_payload: Variant = sections.get(section_key)
		if not (section_payload is Dictionary):
			errors.append("section_payload_not_dictionary:%s" % section_key)
			continue
		var expected_version := int((expected_manifest.get(section_key, {}) as Dictionary).get("state_version", 0))
		if int((section_payload as Dictionary).get("schema_version", 0)) != expected_version:
			errors.append("section_schema_version_mismatch:%s" % section_key)
	if not _is_encoded_pure_data(payload):
		errors.append("envelope_not_deterministic_pure_data")
	errors = _unique_sorted_strings(errors)
	return {
		"valid": errors.is_empty(),
		"reason_code": "valid_v06_envelope" if errors.is_empty() else str(errors[0]),
		"errors": errors,
		"save_version": V06_SAVE_VERSION,
		"ruleset_id": V06_RULESET_ID,
		"fingerprint": envelope_fingerprint(payload) if errors.is_empty() else "",
	}


func compose_v06_envelope(session: Dictionary, domains: Dictionary, identity: Dictionary = {}) -> Dictionary:
	var sections := domains.duplicate(true)
	sections["session"] = session.duplicate(true)
	var envelope := {
		"envelope_schema": ENVELOPE_SCHEMA,
		"save_version": V06_SAVE_VERSION,
		"ruleset_id": V06_RULESET_ID,
		"profile_schema_version": PROFILE_SCHEMA_VERSION,
		"currency_scale": CURRENCY_SCALE,
		"format_id": FORMAT_ID,
		"codec_id": CODEC_ID,
		"envelope_id": str(identity.get("envelope_id", "")),
		"write_id": str(identity.get("write_id", "")),
		"controller_state_versions": required_controller_versions(),
		"section_manifest": required_section_manifest(),
		"sections": sections,
		"migration_policy": MIGRATION_POLICY,
	}
	return envelope if bool(validate_v06_envelope(envelope).get("valid", false)) else {}


func inspect_envelope(payload: Dictionary, target_ruleset_id: String = V06_RULESET_ID) -> Dictionary:
	var save_version := int(payload.get("save_version", payload.get("version", 0)))
	var source_ruleset_id := str(payload.get("ruleset_id", ""))
	if save_version == LEGACY_V04_SAVE_VERSION and source_ruleset_id in ["", "v0.4"]:
		return _inspection("legacy_v1", "v0.4", target_ruleset_id, false, true, "legacy_resume_forbidden")
	if save_version == V05_SAVE_VERSION and source_ruleset_id == V05_RULESET_ID:
		var legacy_validation := validate_v05_envelope(payload)
		var result := _inspection("legacy_v2", V05_RULESET_ID, target_ruleset_id, false, true, "legacy_resume_forbidden")
		result["legacy_structure_valid"] = bool(legacy_validation.get("valid", false))
		return result
	if save_version == V06_SAVE_VERSION and source_ruleset_id == V06_RULESET_ID:
		if _is_previous_v06_manifest(payload):
			return _inspection(
				"v06_previous_manifest",
				V06_RULESET_ID,
				target_ruleset_id,
				false,
				true,
				"v06_previous_manifest_resume_forbidden"
			)
		if _is_pre_resume_v06_manifest(payload):
			return _inspection(
				"v06_pre_resume_manifest",
				V06_RULESET_ID,
				target_ruleset_id,
				false,
				true,
				"v06_pre_resume_manifest_resume_forbidden"
			)
		var validation := validate_v06_envelope(payload)
		return {
			"recognized": true,
			"classification": "v06" if bool(validation.get("valid", false)) else "v06_invalid",
			"source_ruleset_id": V06_RULESET_ID,
			"target_ruleset_id": target_ruleset_id,
			"can_resume": bool(validation.get("valid", false)) and target_ruleset_id == V06_RULESET_ID,
			"requires_backup": not bool(validation.get("valid", false)),
			"reason_code": "resume_allowed" if bool(validation.get("valid", false)) and target_ruleset_id == V06_RULESET_ID else str(validation.get("reason_code", "v06_resume_forbidden")),
			"validation": validation,
		}
	return _inspection("unknown", source_ruleset_id, target_ruleset_id, false, true, "unknown_save_envelope")


func _is_previous_v06_manifest(payload: Dictionary) -> bool:
	var sections_variant: Variant = payload.get("sections")
	if not (sections_variant is Dictionary):
		return false
	var sections := sections_variant as Dictionary
	var current_manifest := required_section_manifest()
	if current_manifest.size() != 19 or sections.size() != 18 or sections.has("card_resolution_history"):
		return false
	for section_id_variant in current_manifest.keys():
		var section_id := str(section_id_variant)
		if section_id == "card_resolution_history":
			continue
		if not sections.has(section_id):
			return false
	return true


func _is_card_inventory_allocator_v2_envelope(
	payload: Dictionary,
	expected_manifest: Dictionary,
	expected_versions: Dictionary
) -> bool:
	var provided_manifest: Dictionary = payload.get("section_manifest", {}) \
			if payload.get("section_manifest", {}) is Dictionary else {}
	var provided_versions: Dictionary = payload.get("controller_state_versions", {}) \
			if payload.get("controller_state_versions", {}) is Dictionary else {}
	var sections: Dictionary = payload.get("sections", {}) \
			if payload.get("sections", {}) is Dictionary else {}
	if provided_manifest.size() != expected_manifest.size() \
			or provided_versions.size() != expected_versions.size() \
			or sections.size() != expected_manifest.size():
		return false
	for section_id_variant in expected_manifest.keys():
		var section_id := str(section_id_variant)
		var expected_row := (expected_manifest.get(section_id, {}) as Dictionary).duplicate(true)
		var controller_id := str(expected_row.get("owner_id", ""))
		if not provided_manifest.has(section_id) or not provided_versions.has(controller_id) \
				or not sections.has(section_id) or not (sections.get(section_id) is Dictionary):
			return false
		var provided_row: Dictionary = provided_manifest.get(section_id, {}) as Dictionary
		var wrapper: Dictionary = sections.get(section_id, {}) as Dictionary
		if section_id == "card_inventory":
			expected_row["state_version"] = 2
			if int(provided_versions.get(controller_id, 0)) != 2 \
					or not _same_data(provided_row, expected_row) \
					or int(wrapper.get("schema_version", 0)) != 2:
				return false
			continue
		if int(provided_versions.get(controller_id, 0)) != int(expected_versions.get(controller_id, 0)) \
				or not _same_data(provided_row, expected_row) \
				or int(wrapper.get("schema_version", 0)) != int(expected_versions.get(controller_id, 0)):
			return false
	var card_wrapper: Dictionary = sections.get("card_inventory", {}) as Dictionary
	var decoded := decode_codec_value(card_wrapper.get("owner_state"))
	if not bool(decoded.get("ok", false)) or not (decoded.get("value") is Dictionary):
		return false
	var owner_state: Dictionary = decoded.get("value", {}) as Dictionary
	var district: Dictionary = owner_state.get("district_purchase", {}) \
			if owner_state.get("district_purchase", {}) is Dictionary else {}
	var district_payload: Dictionary = district.get("district_purchase_runtime", {}) \
			if district.get("district_purchase_runtime", {}) is Dictionary else {}
	return int(owner_state.get("schema_version", 0)) == 2 \
			and str(owner_state.get("ruleset_id", "")) == V06_RULESET_ID \
			and int(district_payload.get("schema_version", 0)) == 2 \
			and district_payload.get("sessions") is Array \
			and not district_payload.has("next_quote_sequence")


func _is_pre_resume_v06_manifest(payload: Dictionary) -> bool:
	var sections: Dictionary = payload.get("sections", {}) if payload.get("sections", {}) is Dictionary else {}
	var provided_manifest: Dictionary = payload.get("section_manifest", {}) if payload.get("section_manifest", {}) is Dictionary else {}
	var provided_versions: Dictionary = payload.get("controller_state_versions", {}) if payload.get("controller_state_versions", {}) is Dictionary else {}
	var current_manifest := required_section_manifest()
	if sections.size() != PRE_RESUME_SECTION_VERSIONS.size() \
			or provided_manifest.size() != PRE_RESUME_SECTION_VERSIONS.size() \
			or provided_versions.size() != PRE_RESUME_SECTION_VERSIONS.size() \
			or current_manifest.size() != PRE_RESUME_SECTION_VERSIONS.size():
		return false
	var expected_manifest: Dictionary = {}
	var expected_versions: Dictionary = {}
	for section_id_variant in PRE_RESUME_SECTION_VERSIONS.keys():
		var section_id := str(section_id_variant)
		var current_contract: Dictionary = current_manifest.get(section_id, {}) \
			if current_manifest.get(section_id, {}) is Dictionary else {}
		var owner_id := str(current_contract.get("owner_id", ""))
		var version := int(PRE_RESUME_SECTION_VERSIONS.get(section_id, 0))
		if owner_id.is_empty() or not (sections.get(section_id) is Dictionary):
			return false
		var wrapper := sections.get(section_id, {}) as Dictionary
		if int(wrapper.get("schema_version", 0)) != version \
				or str(wrapper.get("owner_id", "")) != owner_id:
			return false
		expected_manifest[section_id] = {"owner_id": owner_id, "state_version": version, "required": true}
		expected_versions[owner_id] = version
	return _same_data(provided_manifest, _canonicalize(expected_manifest)) \
		and _same_data(provided_versions, _canonicalize(expected_versions))


func inspect_legacy(payload: Dictionary) -> Dictionary:
	var inspection := inspect_envelope(payload, V06_RULESET_ID)
	if str(inspection.get("classification", "")) not in ["legacy_v1", "legacy_v2"]:
		return {
			"recognized": false,
			"classification": str(inspection.get("classification", "unknown")),
			"can_resume": false,
			"requires_backup": bool(inspection.get("requires_backup", true)),
			"reason_code": "not_legacy_envelope",
		}
	return inspection


func validate_v05_envelope(payload: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if int(payload.get("save_version", 0)) != V05_SAVE_VERSION:
		errors.append("save_version_must_be_2")
	if str(payload.get("ruleset_id", "")) != V05_RULESET_ID:
		errors.append("ruleset_id_must_be_v0.5")
	if not _is_encoded_pure_data(payload):
		errors.append("legacy_envelope_not_pure_data")
	return {"valid": errors.is_empty(), "errors": errors, "resumable": false}


func compose_v05_envelope(_session: Dictionary, _domains: Dictionary) -> Dictionary:
	return {}


func required_controller_versions() -> Dictionary:
	if controller_state_version_registry_v06 == null:
		return {}
	return controller_state_version_registry_v06.required_versions().duplicate(true)


func required_section_manifest() -> Dictionary:
	var manifest: Dictionary = {}
	if controller_state_version_registry_v06 == null:
		return manifest
	var registry_snapshot := controller_state_version_registry_v06.debug_snapshot()
	var entries: Array = registry_snapshot.get("entries", []) if registry_snapshot.get("entries", []) is Array else []
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if not bool(entry.get("required", false)):
			continue
		var section_id := str(entry.get("save_section", ""))
		manifest[section_id] = {
			"owner_id": str(entry.get("controller_id", "")),
			"state_version": int(entry.get("state_version", 0)),
			"required": true,
		}
	return _canonicalize(manifest) as Dictionary


func write_authorization(existing_header: Dictionary, requested_header: Dictionary, options: Dictionary = {}) -> Dictionary:
	var requested_validation := validate_v06_envelope(requested_header)
	var existing_inspection := inspect_envelope(existing_header, V06_RULESET_ID) if not existing_header.is_empty() else {}
	var requested_fingerprint := str(requested_validation.get("fingerprint", ""))
	var existing_fingerprint := envelope_fingerprint(existing_header) if not existing_header.is_empty() else ""
	var allow_replace := bool(options.get("allow_replace", false))
	var allow_backup := bool(options.get("allow_backup", false))
	var requires_backup := not existing_header.is_empty() and str(existing_inspection.get("classification", "")) != "v06"
	var idempotent := not existing_header.is_empty() and not requested_fingerprint.is_empty() and requested_fingerprint == existing_fingerprint
	var write_id_collision := str(existing_inspection.get("classification", "")) == "v06" \
		and str(existing_header.get("write_id", "")) == str(requested_header.get("write_id", "")) \
		and not idempotent
	var allowed := bool(requested_validation.get("valid", false))
	var reason_code := "authorized"
	if not allowed:
		reason_code = str(requested_validation.get("reason_code", "requested_envelope_invalid"))
	elif write_id_collision:
		allowed = false
		reason_code = "write_id_collision"
	elif idempotent:
		reason_code = "idempotent_existing_envelope"
	elif not existing_header.is_empty() and requires_backup and not (allow_replace and allow_backup):
		allowed = false
		reason_code = "backup_authorization_required"
	elif not existing_header.is_empty() and not requires_backup and not allow_replace:
		allowed = false
		reason_code = "replace_authorization_required"
	var token_payload := {
		"authorization_schema_version": AUTHORIZATION_SCHEMA_VERSION,
		"existing_fingerprint": existing_fingerprint,
		"requested_fingerprint": requested_fingerprint,
		"write_id": str(requested_header.get("write_id", "")),
		"allow_replace": allow_replace,
		"allow_backup": allow_backup,
		"requires_backup": requires_backup,
	}
	return {
		"authorization_schema_version": AUTHORIZATION_SCHEMA_VERSION,
		"allowed": allowed,
		"reason_code": reason_code,
		"authorization_token": envelope_fingerprint(token_payload),
		"write_id": str(requested_header.get("write_id", "")),
		"requested_fingerprint": requested_fingerprint,
		"existing_fingerprint": existing_fingerprint,
		"allow_replace": allow_replace,
		"allow_backup": allow_backup,
		"requires_backup": requires_backup,
		"idempotent": idempotent,
	}


func authorization_matches(existing_header: Dictionary, requested_header: Dictionary, authorization: Dictionary) -> bool:
	if int(authorization.get("authorization_schema_version", 0)) != AUTHORIZATION_SCHEMA_VERSION:
		return false
	var expected := write_authorization(existing_header, requested_header, {
		"allow_replace": bool(authorization.get("allow_replace", false)),
		"allow_backup": bool(authorization.get("allow_backup", false)),
	})
	return bool(expected.get("allowed", false)) \
		and bool(authorization.get("allowed", false)) \
		and str(expected.get("authorization_token", "")) == str(authorization.get("authorization_token", "")) \
		and str(expected.get("write_id", "")) == str(authorization.get("write_id", ""))


func encode_codec_value(value: Variant) -> Dictionary:
	var encoded := _encode_codec_value(value)
	if not bool(encoded.get("ok", false)):
		return encoded
	return {"ok": true, "value": (encoded.get("value") as Variant)}


func decode_codec_value(value: Variant) -> Dictionary:
	return _decode_codec_value(value)


func canonical_json(value: Variant) -> String:
	if not _is_encoded_pure_data(value):
		return ""
	return JSON.stringify(_canonicalize(value), "", false, true)


func envelope_fingerprint(value: Variant) -> String:
	var canonical := canonical_json(value)
	if canonical.is_empty():
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(canonical.to_utf8_buffer())
	return context.finish().hex_encode()


func debug_snapshot() -> Dictionary:
	return {
		"service_id": "ruleset_save_handshake_v06",
		"save_version": V06_SAVE_VERSION,
		"ruleset_id": V06_RULESET_ID,
		"currency_scale": CURRENCY_SCALE,
		"envelope_schema": ENVELOPE_SCHEMA,
		"format_id": FORMAT_ID,
		"codec_id": CODEC_ID,
		"legacy_resume_enabled": false,
		"production_save_path_owned": false,
		"required_section_count": required_section_manifest().size(),
		"registry_valid": bool(_registry_validation().get("valid", false)),
	}


func _registry_validation() -> Dictionary:
	var errors: Array[String] = []
	if controller_state_version_registry_v06 == null:
		return {"valid": false, "errors": ["controller_registry_v06_missing"]}
	var base_validation := controller_state_version_registry_v06.validation_snapshot()
	for base_error in base_validation.get("errors", []):
		errors.append(str(base_error))
	if str(controller_state_version_registry_v06.ruleset_id) != V06_RULESET_ID:
		errors.append("controller_registry_ruleset_mismatch")
	var seen_owners: Dictionary = {}
	var seen_sections: Dictionary = {}
	var entries: Array = controller_state_version_registry_v06.debug_snapshot().get("entries", [])
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			errors.append("controller_registry_entry_invalid")
			continue
		var entry := entry_variant as Dictionary
		var owner_id := str(entry.get("controller_id", ""))
		var section_id := str(entry.get("save_section", ""))
		if seen_owners.has(owner_id):
			errors.append("duplicate_owner:%s" % owner_id)
		if seen_sections.has(section_id):
			errors.append("duplicate_section:%s" % section_id)
		seen_owners[owner_id] = true
		seen_sections[section_id] = true
	return {"valid": errors.is_empty(), "errors": _unique_sorted_strings(errors)}


func _inspection(classification: String, source_ruleset_id: String, target_ruleset_id: String, can_resume: bool, requires_backup: bool, reason_code: String) -> Dictionary:
	return {
		"recognized": classification != "unknown",
		"classification": classification,
		"source_ruleset_id": source_ruleset_id,
		"target_ruleset_id": target_ruleset_id,
		"can_resume": can_resume,
		"requires_backup": requires_backup,
		"reason_code": reason_code,
	}


func _encode_codec_value(value: Variant) -> Dictionary:
	if value is Vector2:
		return {"ok": true, "value": {CODEC_KEY: CODEC_VECTOR2, "x": _float64_bits(value.x), "y": _float64_bits(value.y)}}
	if value is Color:
		return {"ok": true, "value": {CODEC_KEY: CODEC_COLOR, "r": _float64_bits(value.r), "g": _float64_bits(value.g), "b": _float64_bits(value.b), "a": _float64_bits(value.a)}}
	if value is int:
		return {"ok": true, "value": {CODEC_KEY: CODEC_INT64, "value": str(value)}}
	if value is float and is_finite(value):
		return {"ok": true, "value": {CODEC_KEY: CODEC_FLOAT64, "bits": _float64_bits(value)}}
	if value == null or value is String or value is bool:
		return {"ok": true, "value": value}
	if value is Array:
		var encoded_array: Array = []
		for item in value:
			var encoded_item := _encode_codec_value(item)
			if not bool(encoded_item.get("ok", false)):
				return encoded_item
			encoded_array.append(encoded_item.get("value"))
		return {"ok": true, "value": encoded_array}
	if value is Dictionary:
		var encoded_dictionary: Dictionary = {}
		for key_variant in value.keys():
			if not (key_variant is String or key_variant is StringName):
				return {"ok": false, "reason_code": "codec_dictionary_key_invalid"}
			var encoded_item := _encode_codec_value(value[key_variant])
			if not bool(encoded_item.get("ok", false)):
				return encoded_item
			encoded_dictionary[str(key_variant)] = encoded_item.get("value")
		return {"ok": true, "value": encoded_dictionary}
	return {"ok": false, "reason_code": "codec_variant_type_forbidden"}


func _decode_codec_value(value: Variant) -> Dictionary:
	# Codec v2 never transports numbers as JSON number scalars. Rejecting bare
	# numeric values here makes the codec id an enforceable wire contract and
	# prevents a seed/RNG cursor from silently passing through JSON precision.
	if value == null or value is String or value is bool:
		return {"ok": true, "value": value}
	if value is int or value is float:
		return {"ok": false, "reason_code": "codec_numeric_scalar_untagged"}
	if value is Array:
		var decoded_array: Array = []
		for item in value:
			var decoded_item := _decode_codec_value(item)
			if not bool(decoded_item.get("ok", false)):
				return decoded_item
			decoded_array.append(decoded_item.get("value"))
		return {"ok": true, "value": decoded_array}
	if value is Dictionary:
		var dictionary := value as Dictionary
		if dictionary.has(CODEC_KEY):
			var codec_type := str(dictionary.get(CODEC_KEY, ""))
			if codec_type == CODEC_FLOAT64 and dictionary.keys().size() == 2 and dictionary.get("bits") is String:
				return _decode_float64_bits(str(dictionary.get("bits", "")))
			if codec_type == CODEC_INT64 and dictionary.keys().size() == 2 and dictionary.get("value") is String:
				var integer_text := str(dictionary.get("value", ""))
				if not integer_text.is_valid_int():
					return {"ok": false, "reason_code": "codec_int64_invalid"}
				var integer_value := integer_text.to_int()
				if str(integer_value) != integer_text:
					return {"ok": false, "reason_code": "codec_int64_noncanonical"}
				return {"ok": true, "value": integer_value}
			if codec_type == CODEC_VECTOR2 and dictionary.keys().size() == 3 and dictionary.get("x") is String and dictionary.get("y") is String:
				var x_result := _decode_float64_bits(str(dictionary.get("x", "")))
				var y_result := _decode_float64_bits(str(dictionary.get("y", "")))
				return {"ok": true, "value": Vector2(float(x_result.get("value", 0.0)), float(y_result.get("value", 0.0)))} \
					if bool(x_result.get("ok", false)) and bool(y_result.get("ok", false)) else {"ok": false, "reason_code": "codec_vector2_invalid"}
			if codec_type == CODEC_COLOR and dictionary.keys().size() == 5 and dictionary.get("r") is String and dictionary.get("g") is String and dictionary.get("b") is String and dictionary.get("a") is String:
				var r_result := _decode_float64_bits(str(dictionary.get("r", "")))
				var g_result := _decode_float64_bits(str(dictionary.get("g", "")))
				var b_result := _decode_float64_bits(str(dictionary.get("b", "")))
				var a_result := _decode_float64_bits(str(dictionary.get("a", "")))
				return {"ok": true, "value": Color(float(r_result.get("value", 0.0)), float(g_result.get("value", 0.0)), float(b_result.get("value", 0.0)), float(a_result.get("value", 0.0)))} \
					if bool(r_result.get("ok", false)) and bool(g_result.get("ok", false)) and bool(b_result.get("ok", false)) and bool(a_result.get("ok", false)) else {"ok": false, "reason_code": "codec_color_invalid"}
			return {"ok": false, "reason_code": "codec_tag_invalid"}
		var decoded_dictionary: Dictionary = {}
		for key_variant in dictionary.keys():
			if not (key_variant is String or key_variant is StringName):
				return {"ok": false, "reason_code": "codec_dictionary_key_invalid"}
			var decoded_item := _decode_codec_value(dictionary[key_variant])
			if not bool(decoded_item.get("ok", false)):
				return decoded_item
			decoded_dictionary[str(key_variant)] = decoded_item.get("value")
		return {"ok": true, "value": decoded_dictionary}
	return {"ok": false, "reason_code": "codec_variant_type_forbidden"}


func _float64_bits(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()


func _decode_float64_bits(bits: String) -> Dictionary:
	if bits.length() != 16:
		return {"ok": false, "reason_code": "codec_float64_bits_invalid"}
	var bytes := bits.hex_decode()
	if bytes.size() != 8 or bytes.hex_encode() != bits.to_lower():
		return {"ok": false, "reason_code": "codec_float64_bits_invalid"}
	var value := bytes.decode_double(0)
	return {"ok": is_finite(value), "reason_code": "codec_float64_valid" if is_finite(value) else "codec_float64_nonfinite", "value": value}


func _is_encoded_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int:
		return true
	if value is float:
		return is_finite(value)
	if value is Array:
		for item in value:
			if not _is_encoded_pure_data(item):
				return false
		return true
	if value is Dictionary:
		var dictionary := value as Dictionary
		if dictionary.has(CODEC_KEY):
			return bool(_decode_codec_value(dictionary).get("ok", false))
		for key_variant in dictionary.keys():
			if not (key_variant is String or key_variant is StringName) or not _is_encoded_pure_data(dictionary[key_variant]):
				return false
		return true
	return false


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary := value as Dictionary
		var keys: Array[String] = []
		for key_variant in dictionary.keys():
			keys.append(str(key_variant))
		keys.sort()
		var result: Dictionary = {}
		for key in keys:
			result[key] = _canonicalize(dictionary[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_canonicalize(item))
		return result
	# JSON has one numeric domain. Normalize integral floats so a serialized and
	# parsed envelope retains the same deterministic fingerprint.
	if value is float and is_finite(value) and value == floor(value):
		return int(value)
	return value


func _valid_identifier(value: String) -> bool:
	if value.is_empty() or value.length() > 128 or value.contains(".."):
		return false
	for character in value:
		if not (character.is_valid_identifier() or character.is_valid_int() or character in ["-", ".", ":"]):
			return false
	return true


func _same_data(left: Variant, right: Variant) -> bool:
	return canonical_json(left) == canonical_json(right) and not canonical_json(left).is_empty()


func _unique_sorted_strings(values: Array[String]) -> Array[String]:
	var seen: Dictionary = {}
	for value in values:
		seen[value] = true
	var result: Array[String] = []
	for value in seen.keys():
		result.append(str(value))
	result.sort()
	return result
