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
const CODEC_ID := "explicit_tagged_json_v1"
const MIGRATION_POLICY := "new_session_only"
const AUTHORIZATION_SCHEMA_VERSION := 1
const CODEC_KEY := "$codec"
const CODEC_VECTOR2 := "Vector2"
const CODEC_COLOR := "Color"
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

@export var controller_state_version_registry: ControllerStateVersionRegistryResource
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
		return {"ok": true, "value": {CODEC_KEY: CODEC_VECTOR2, "x": value.x, "y": value.y}}
	if value is Color:
		return {"ok": true, "value": {CODEC_KEY: CODEC_COLOR, "r": value.r, "g": value.g, "b": value.b, "a": value.a}}
	if value == null or value is String or value is bool or value is int or (value is float and is_finite(value)):
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
	if value == null or value is String or value is bool or value is int or (value is float and is_finite(value)):
		return {"ok": true, "value": value}
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
			if codec_type == CODEC_VECTOR2 and dictionary.keys().size() == 3 and dictionary.has("x") and dictionary.has("y"):
				return {"ok": true, "value": Vector2(float(dictionary.x), float(dictionary.y))}
			if codec_type == CODEC_COLOR and dictionary.keys().size() == 5 and dictionary.has("r") and dictionary.has("g") and dictionary.has("b") and dictionary.has("a"):
				return {"ok": true, "value": Color(float(dictionary.r), float(dictionary.g), float(dictionary.b), float(dictionary.a))}
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
