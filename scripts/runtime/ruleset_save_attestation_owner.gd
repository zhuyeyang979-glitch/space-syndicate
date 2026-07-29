@tool
extends Node
class_name RulesetSaveAttestationOwner

const StrictState := preload("res://scripts/runtime/save_owner_state_v2_contract.gd")

const SCHEMA_VERSION := 1
const RULESET_ID := "v0.6"
const SAVE_KEYS := [
	"schema_version",
	"ruleset_id",
	"profile_schema_version",
	"ruleset_profile_id",
	"ruleset_fingerprint",
	"compatibility_profile_fingerprint",
	"balance_fingerprint",
	"content_manifest_fingerprint",
]

@export var active_profile: Resource = preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
@export var compatibility_profile: Resource = preload("res://resources/rules/space_syndicate_ruleset_v04.tres")
@export var balance_profile: Resource = preload("res://resources/balance/balance_parameter_profile_v1.tres")
@export var runtime_balance_parameters: Resource = preload("res://resources/balance/runtime_balance_parameters_v1.tres")
@export var content_manifest: Resource = preload("res://resources/content/alpha01/alpha01_content_manifest.tres")


func to_save_data() -> Dictionary:
	return _current_attestation()


func preflight_save_data(data: Dictionary) -> Dictionary:
	var validation := _validate_shape(data)
	if not bool(validation.get("valid", false)):
		var reason_code := str(validation.get("reason_code", "ruleset_attestation_invalid"))
		return {"accepted": false, "reason": reason_code, "reason_code": reason_code}
	var current := _current_attestation()
	if data != current:
		return {
			"accepted": false,
			"reason": "ruleset_attestation_mismatch",
			"reason_code": "ruleset_attestation_mismatch",
		}
	return {
		"accepted": true,
		"reason": "",
		"reason_code": "ruleset_attestation_valid",
		"normalized_state": current,
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var preflight := preflight_save_data(data)
	if not bool(preflight.get("accepted", false)):
		return {
			"applied": false,
			"reason": str(preflight.get("reason_code", "ruleset_attestation_invalid")),
			"reason_code": str(preflight.get("reason_code", "ruleset_attestation_invalid")),
		}
	return {
		"applied": true,
		"immutable": true,
		"reason": "ruleset_attestation_verified",
		"reason_code": "ruleset_attestation_verified",
	}


func capture_runtime_checkpoint() -> Dictionary:
	return to_save_data()


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	var receipt := apply_save_data(checkpoint)
	return {
		"restored": bool(receipt.get("applied", false)),
		"reason_code": str(receipt.get("reason_code", "ruleset_attestation_invalid")),
	}


func rollback_save_data(checkpoint: Dictionary) -> Dictionary:
	return apply_save_data(checkpoint)


func debug_snapshot() -> Dictionary:
	var state := _current_attestation()
	return {
		"owner_ready": bool(preflight_save_data(state).get("accepted", false)),
		"owner_authoritative": true,
		"immutable_attestation": true,
		"ruleset_id": RULESET_ID,
		"schema_version": SCHEMA_VERSION,
		"ruleset_profile_id": str(state.get("ruleset_profile_id", "")),
		"compatibility_profile_id": str(compatibility_profile.get("ruleset_id")) if compatibility_profile != null else "",
		"fingerprint_count": 4,
		"owns_rng_continuation": false,
	}


func _current_attestation() -> Dictionary:
	var active_snapshot := _profile_snapshot(active_profile)
	var compatibility_snapshot := _profile_snapshot(compatibility_profile)
	var balance_profile_snapshot := {
		"summary": _resource_call_dictionary(balance_profile, "resource_summary"),
		"runtime_targets": _resource_call_dictionary(balance_profile, "to_runtime_targets_dictionary"),
		"price_curve": _resource_call_dictionary(balance_profile, "to_price_curve_dictionary"),
	}
	var runtime_balance_snapshot := _resource_call_dictionary(runtime_balance_parameters, "to_runtime_targets_dictionary")
	var content_fingerprint := _resource_call_string(content_manifest, "deterministic_sha256")
	if not _valid_fingerprint(content_fingerprint):
		content_fingerprint = StrictState.fingerprint(_resource_call_dictionary(content_manifest, "selection_snapshot"))
	return {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"profile_schema_version": int(active_profile.get("profile_schema_version")) if active_profile != null else 0,
		"ruleset_profile_id": str(active_profile.get("ruleset_id")) if active_profile != null else "",
		"ruleset_fingerprint": StrictState.fingerprint(active_snapshot),
		"compatibility_profile_fingerprint": StrictState.fingerprint(compatibility_snapshot),
		"balance_fingerprint": StrictState.fingerprint({
			"balance_profile": balance_profile_snapshot,
			"runtime_parameters": runtime_balance_snapshot,
		}),
		"content_manifest_fingerprint": content_fingerprint,
	}


func _validate_shape(data: Dictionary) -> Dictionary:
	if not StrictState.is_codec_data(data) or StrictState.contains_rng_continuation(data):
		return {"valid": false, "reason_code": "ruleset_attestation_not_codec_data"}
	if not StrictState.has_exact_keys(data, SAVE_KEYS):
		return {"valid": false, "reason_code": "ruleset_attestation_shape_invalid"}
	if not (data.get("schema_version") is int) or int(data.get("schema_version")) != SCHEMA_VERSION \
			or not (data.get("ruleset_id") is String) or str(data.get("ruleset_id")) != RULESET_ID:
		return {"valid": false, "reason_code": "ruleset_attestation_header_invalid"}
	if not (data.get("profile_schema_version") is int) or int(data.get("profile_schema_version")) <= 0 \
			or not (data.get("ruleset_profile_id") is String) \
			or str(data.get("ruleset_profile_id")) != RULESET_ID:
		return {"valid": false, "reason_code": "ruleset_attestation_schema_invalid"}
	for key in ["ruleset_fingerprint", "compatibility_profile_fingerprint", "balance_fingerprint", "content_manifest_fingerprint"]:
		if not (data.get(key) is String) or not _valid_fingerprint(str(data.get(key))):
			return {"valid": false, "reason_code": "ruleset_fingerprint_invalid"}
	return {"valid": true, "reason_code": "ruleset_attestation_valid"}


func _profile_snapshot(resource: Resource) -> Dictionary:
	return _resource_call_dictionary(resource, "debug_snapshot")


func _resource_call_dictionary(resource: Resource, method_name: StringName) -> Dictionary:
	if resource == null or not resource.has_method(method_name):
		return {}
	var value: Variant = resource.call(method_name)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _resource_call_string(resource: Resource, method_name: StringName) -> String:
	if resource == null or not resource.has_method(method_name):
		return ""
	return str(resource.call(method_name))


func _valid_fingerprint(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true
