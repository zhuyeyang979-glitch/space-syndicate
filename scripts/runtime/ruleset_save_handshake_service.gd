extends Node
class_name RulesetSaveHandshakeService

const LEGACY_V04_SAVE_VERSION := 1
const V05_SAVE_VERSION := 2
const V05_RULESET_ID := "v0.5"
const CURRENCY_SCALE := 100

@export var controller_state_version_registry: ControllerStateVersionRegistryResource


func inspect_envelope(payload: Dictionary, target_ruleset_id: String) -> Dictionary:
	var save_version := int(payload.get("save_version", 0))
	var source_ruleset_id := str(payload.get("ruleset_id", ""))
	if save_version == LEGACY_V04_SAVE_VERSION and source_ruleset_id.is_empty():
		return {
			"recognized": true,
			"classification": "legacy_v04",
			"source_ruleset_id": "v0.4",
			"target_ruleset_id": target_ruleset_id,
			"can_resume": target_ruleset_id == "v0.4",
			"requires_backup": target_ruleset_id == V05_RULESET_ID,
			"reason": "legacy_v04_requires_new_v05_session" if target_ruleset_id == V05_RULESET_ID else "legacy_v04_current_runtime",
		}
	if save_version == V05_SAVE_VERSION and source_ruleset_id == V05_RULESET_ID:
		var validation := validate_v05_envelope(payload)
		return {
			"recognized": bool(validation.get("valid", false)),
			"classification": "v05",
			"source_ruleset_id": V05_RULESET_ID,
			"target_ruleset_id": target_ruleset_id,
			"can_resume": bool(validation.get("valid", false)) and target_ruleset_id == V05_RULESET_ID,
			"requires_backup": false,
			"reason": "ok" if bool(validation.get("valid", false)) and target_ruleset_id == V05_RULESET_ID else "target_or_envelope_mismatch",
			"validation": validation,
		}
	return {
		"recognized": false,
		"classification": "unknown",
		"source_ruleset_id": source_ruleset_id,
		"target_ruleset_id": target_ruleset_id,
		"can_resume": false,
		"requires_backup": false,
		"reason": "unknown_save_envelope",
	}


func validate_v05_envelope(payload: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if int(payload.get("save_version", 0)) != V05_SAVE_VERSION:
		errors.append("save_version_must_be_2")
	if str(payload.get("ruleset_id", "")) != V05_RULESET_ID:
		errors.append("ruleset_id_must_be_v0.5")
	if int(payload.get("profile_schema_version", 0)) <= 0:
		errors.append("profile_schema_version_invalid")
	if int(payload.get("currency_scale", 0)) != CURRENCY_SCALE:
		errors.append("currency_scale_must_be_100")
	if not payload.get("session", null) is Dictionary:
		errors.append("session_must_be_dictionary")
	if not payload.get("domains", null) is Dictionary:
		errors.append("domains_must_be_dictionary")
	if not payload.get("controller_state_versions", null) is Dictionary:
		errors.append("controller_state_versions_missing")
	elif controller_state_version_registry == null:
		errors.append("controller_registry_missing")
	else:
		var provided: Dictionary = payload.controller_state_versions
		for controller_id_variant in controller_state_version_registry.required_versions().keys():
			var controller_id := str(controller_id_variant)
			var expected_version := int(controller_state_version_registry.required_versions()[controller_id_variant])
			if int(provided.get(controller_id, 0)) != expected_version:
				errors.append("controller_version_mismatch:%s" % controller_id)
	if not _is_pure_data(payload):
		errors.append("envelope_not_pure_data")
	return {"valid": errors.is_empty(), "errors": errors}


func compose_v05_envelope(session: Dictionary, domains: Dictionary) -> Dictionary:
	if controller_state_version_registry == null:
		push_error("RulesetSaveHandshakeService requires controller state registry")
		return {}
	return {
		"save_version": V05_SAVE_VERSION,
		"ruleset_id": V05_RULESET_ID,
		"profile_schema_version": 1,
		"currency_scale": CURRENCY_SCALE,
		"controller_state_versions": controller_state_version_registry.required_versions(),
		"session": session.duplicate(true),
		"domains": domains.duplicate(true),
	}


func write_authorization(existing_header: Dictionary, requested_header: Dictionary) -> Dictionary:
	if existing_header.is_empty():
		return {"allowed": true, "reason": "empty_destination"}
	var existing_kind := _header_ruleset(existing_header)
	var requested_kind := _header_ruleset(requested_header)
	if existing_kind == "unknown" or requested_kind == "unknown":
		return {"allowed": false, "reason": "unknown_header"}
	if existing_kind != requested_kind:
		return {
			"allowed": false,
			"reason": "%s_cannot_overwrite_%s" % [requested_kind.replace(".", ""), existing_kind.replace(".", "")],
		}
	return {"allowed": true, "reason": "same_ruleset_version"}


func debug_snapshot() -> Dictionary:
	return {
		"service_id": "ruleset_save_handshake_v05",
		"v05_save_version": V05_SAVE_VERSION,
		"v05_ruleset_id": V05_RULESET_ID,
		"currency_scale": CURRENCY_SCALE,
		"passive_only": true,
		"production_save_path_owned": false,
		"controller_registry": controller_state_version_registry.debug_snapshot() if controller_state_version_registry != null else {},
	}


func _header_ruleset(header: Dictionary) -> String:
	if int(header.get("save_version", 0)) == LEGACY_V04_SAVE_VERSION and str(header.get("ruleset_id", "")).is_empty():
		return "v0.4"
	if int(header.get("save_version", 0)) == V05_SAVE_VERSION and str(header.get("ruleset_id", "")) == V05_RULESET_ID:
		return "v0.5"
	return "unknown"


func _is_pure_data(value: Variant) -> bool:
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
