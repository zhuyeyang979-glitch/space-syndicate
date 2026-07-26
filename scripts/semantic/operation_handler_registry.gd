extends Node
class_name OperationHandlerRegistry

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const DESCRIPTOR := preload("res://scripts/semantic/operation_handler_descriptor.gd")
const VALIDATION_REPORT := preload("res://scripts/semantic/semantic_validation_report.gd")
const SCHEMA_VERSION := 1
const MANIFEST_FIELDS := [
	"schema_version",
	"domain_id",
	"operation_id",
	"operation_version",
	"execution_readiness_id",
	"semantic_fingerprint",
]
const READINESS_IDS := ["active", "projection_only", "unavailable"]

var _descriptors: Dictionary = {}
var _sealed := false
var _registry_fingerprint := ""
var _last_report: Dictionary = {}
var _applied_registration_count := 0


# This first slice registers detached descriptors only. Owner-bound executable
# ports are intentionally deferred so no Callable or gameplay owner is retained.
func register_handler(descriptor: Dictionary) -> Dictionary:
	if _sealed:
		return _registration_receipt(false, "registry_sealed", descriptor, false)
	var report := DESCRIPTOR.validate(descriptor)
	if not bool(report.get("valid", false)):
		return _registration_receipt(false, str(report.get("reason_id", "descriptor_invalid")), descriptor, false)
	var key := _descriptor_key(
		str(descriptor.get("operation_id", "")), int(descriptor.get("operation_version", 0))
	)
	if _descriptors.has(key):
		var current := _descriptors.get(key) as Dictionary
		if str(current.get("descriptor_fingerprint", "")) \
				== str(descriptor.get("descriptor_fingerprint", "")):
			return _registration_receipt(true, "already_registered", current, false)
		return _registration_receipt(false, "registration_conflict", descriptor, false)
	_descriptors[key] = descriptor.duplicate(true)
	_applied_registration_count += 1
	return _registration_receipt(true, "registered", descriptor, true)


func seal(compiled_manifests: Array[Dictionary]) -> Dictionary:
	if _sealed:
		return validation_snapshot()
	var normalized_manifests: Array[Dictionary] = []
	var issues: Array[Dictionary] = []
	var manifest_keys: Array[String] = []
	var active_operation_ids: Array[String] = []
	var projection_only_operation_ids: Array[String] = []
	var unknown_operation_ids: Array[String] = []
	for manifest_variant in compiled_manifests:
		var manifest_error := _manifest_error(manifest_variant)
		if not manifest_error.is_empty():
			issues.append(_issue("blocker", manifest_error, "card", "invalid.manifest", "compiled_manifests"))
			continue
		var manifest := manifest_variant.duplicate(true)
		var key := _descriptor_key(
			str(manifest.get("operation_id", "")), int(manifest.get("operation_version", 0))
		)
		if manifest_keys.has(key):
			issues.append(_issue(
				"blocker",
				"registry.manifest_duplicate",
				str(manifest.get("domain_id", "")),
				str(manifest.get("operation_id", "")),
				"compiled_manifests"
			))
			continue
		manifest_keys.append(key)
		normalized_manifests.append(manifest)
		var readiness_id := str(manifest.get("execution_readiness_id", ""))
		var operation_id := str(manifest.get("operation_id", ""))
		if readiness_id == "active":
			_append_unique(active_operation_ids, operation_id)
			if not _descriptors.has(key):
				_append_unique(unknown_operation_ids, operation_id)
				issues.append(_issue(
					"blocker",
					"registry.active_handler_missing",
					str(manifest.get("domain_id", "")),
					operation_id,
					"operation_id"
				))
			else:
				var descriptor := _descriptors.get(key) as Dictionary
				var capability_error := _active_descriptor_error(descriptor, manifest)
				if not capability_error.is_empty():
					issues.append(_issue(
						"blocker",
						capability_error,
						str(manifest.get("domain_id", "")),
						operation_id,
						"descriptor"
					))
		elif readiness_id == "projection_only":
			_append_unique(projection_only_operation_ids, operation_id)

	for key_variant in _descriptors.keys():
		var key := str(key_variant)
		if not manifest_keys.has(key):
			var descriptor := _descriptors.get(key) as Dictionary
			issues.append(_issue(
				"error",
				"registry.descriptor_without_manifest",
				str(descriptor.get("domain_id", "")),
				str(descriptor.get("operation_id", "")),
				"descriptor"
			))

	normalized_manifests.sort_custom(_manifest_less)
	issues.sort_custom(_issue_less)
	active_operation_ids.sort()
	projection_only_operation_ids.sort()
	unknown_operation_ids.sort()
	var source_manifest_fingerprint := WIRE.fingerprint({
		"manifest_kind": "compiled_operation_refs",
		"rows": normalized_manifests,
	})
	var semantic_catalog_fingerprint := WIRE.fingerprint({
		"manifest_kind": "semantic_operation_refs",
		"rows": normalized_manifests,
	})
	var registry_fingerprint := _calculate_registry_fingerprint()
	var report_input := {
		"schema_version": SCHEMA_VERSION,
		"report_id": "semantic.registry.seal",
		"phase_id": "registry_seal",
		"valid": issues.is_empty(),
		"source_manifest_fingerprint": source_manifest_fingerprint,
		"semantic_catalog_fingerprint": semantic_catalog_fingerprint,
		"registry_fingerprint": registry_fingerprint,
		"issues": issues,
		"domain_summaries": _domain_summaries(normalized_manifests),
		"unknown_condition_ids": [],
		"unknown_target_ids": [],
		"unknown_operation_ids": unknown_operation_ids,
		"unknown_randomness_policy_ids": [],
		"unknown_visibility_policy_ids": [],
		"unknown_mechanic_ids": [],
		"retired_identifier_hits": [],
		"active_operation_ids": active_operation_ids,
		"projection_only_operation_ids": projection_only_operation_ids,
	}
	_last_report = VALIDATION_REPORT.build(report_input)
	if _last_report.is_empty():
		return {}
	if bool(_last_report.get("valid", false)):
		_registry_fingerprint = registry_fingerprint
		_sealed = true
	return _last_report.duplicate(true)


func descriptor_for(operation_id: String, operation_version: int) -> Dictionary:
	if not _sealed or not WIRE.is_stable_id(operation_id) \
			or not WIRE.is_positive_integer(operation_version):
		return {}
	var descriptor: Variant = _descriptors.get(_descriptor_key(operation_id, operation_version))
	return (descriptor as Dictionary).duplicate(true) if descriptor is Dictionary else {}


func validation_snapshot() -> Dictionary:
	if not _last_report.is_empty():
		return _last_report.duplicate(true)
	var report := VALIDATION_REPORT.build({
		"schema_version": SCHEMA_VERSION,
		"report_id": "semantic.registry.unsealed",
		"phase_id": "source_validation",
		"valid": true,
		"source_manifest_fingerprint": WIRE.fingerprint([]),
		"issues": [],
		"domain_summaries": [],
		"unknown_condition_ids": [],
		"unknown_target_ids": [],
		"unknown_operation_ids": [],
		"unknown_randomness_policy_ids": [],
		"unknown_visibility_policy_ids": [],
		"unknown_mechanic_ids": [],
		"retired_identifier_hits": [],
		"active_operation_ids": [],
		"projection_only_operation_ids": [],
	})
	return report.duplicate(true)


func registry_fingerprint() -> String:
	return _registry_fingerprint if _sealed else ""


func debug_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"sealed": _sealed,
		"descriptor_count": _descriptors.size(),
		"applied_registration_count": _applied_registration_count,
		"registry_fingerprint": registry_fingerprint(),
		"metadata_only": true,
		"stores_callable": false,
		"owns_gameplay_state": false,
		"owns_catalog": false,
		"owns_rng": false,
		"owns_save_section": false,
	}


func _manifest_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "registry.manifest_not_closed_data"
	var manifest := value as Dictionary
	if not WIRE.exact_fields(manifest, MANIFEST_FIELDS):
		return "registry.manifest_fields_invalid"
	if manifest.get("schema_version") != SCHEMA_VERSION:
		return "registry.manifest_schema_version_invalid"
	if not WIRE.DOMAIN_IDS.has(str(manifest.get("domain_id", ""))) \
			or not WIRE.is_stable_id(manifest.get("operation_id")):
		return "registry.manifest_identity_invalid"
	if not WIRE.is_positive_integer(manifest.get("operation_version")):
		return "registry.manifest_operation_version_invalid"
	if not READINESS_IDS.has(str(manifest.get("execution_readiness_id", ""))):
		return "registry.manifest_readiness_unknown"
	if not WIRE.is_fingerprint(manifest.get("semantic_fingerprint")):
		return "registry.manifest_fingerprint_invalid"
	return ""


func _active_descriptor_error(descriptor: Dictionary, manifest: Dictionary) -> String:
	if str(descriptor.get("domain_id", "")) != str(manifest.get("domain_id", "")):
		return "registry.descriptor_domain_mismatch"
	for capability in [
		"supports_preflight",
		"supports_checkpoint",
		"supports_apply",
		"supports_rollback",
		"supports_rules_projection",
		"supports_player_projection",
		"supports_ai_projection",
	]:
		if not bool(descriptor.get(capability, false)):
			return "registry.active_capability_missing"
	return ""


func _calculate_registry_fingerprint() -> String:
	var descriptors: Array[Dictionary] = []
	var keys: Array[String] = []
	for key_variant in _descriptors.keys():
		keys.append(str(key_variant))
	keys.sort()
	for key in keys:
		descriptors.append((_descriptors.get(key) as Dictionary).duplicate(true))
	return WIRE.fingerprint({"registry_kind": "operation_handler_descriptors", "rows": descriptors})


func _domain_summaries(manifests: Array[Dictionary]) -> Array[Dictionary]:
	var grouped: Dictionary = {}
	for manifest in manifests:
		var domain_id := str(manifest.get("domain_id", ""))
		if not grouped.has(domain_id):
			grouped[domain_id] = []
		(grouped[domain_id] as Array).append(manifest.duplicate(true))
	var domain_ids: Array[String] = []
	for domain_variant in grouped.keys():
		domain_ids.append(str(domain_variant))
	domain_ids.sort()
	var summaries: Array[Dictionary] = []
	for domain_id in domain_ids:
		var rows := grouped.get(domain_id) as Array
		var active_count := 0
		var projection_only_count := 0
		var failed_count := 0
		for row_variant in rows:
			match str((row_variant as Dictionary).get("execution_readiness_id", "")):
				"active":
					active_count += 1
				"projection_only":
					projection_only_count += 1
				_:
					failed_count += 1
		var domain_fingerprint := WIRE.fingerprint(rows)
		summaries.append({
			"schema_version": SCHEMA_VERSION,
			"domain_id": domain_id,
			"source_definition_count": rows.size(),
			"compiled_definition_count": rows.size() - failed_count,
			"active_definition_count": active_count,
			"projection_only_definition_count": projection_only_count,
			"failed_definition_count": failed_count,
			"source_catalog_fingerprint": domain_fingerprint,
			"semantic_catalog_fingerprint": domain_fingerprint,
		})
	return summaries


func _registration_receipt(
	ok: bool,
	status_id: String,
	descriptor: Dictionary,
	applied: bool
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"ok": ok,
		"status_id": status_id,
		"operation_id": str(descriptor.get("operation_id", "")),
		"operation_version": int(descriptor.get("operation_version", 0)),
		"descriptor_fingerprint": str(descriptor.get("descriptor_fingerprint", "")),
		"applied": applied,
	}


func _issue(
	severity_id: String,
	issue_code: String,
	domain_id: String,
	definition_id: String,
	path: String
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"severity_id": severity_id,
		"issue_code": issue_code,
		"domain_id": domain_id,
		"definition_id": definition_id,
		"path": path,
	}


func _descriptor_key(operation_id: String, operation_version: int) -> String:
	return "%s|%d" % [operation_id, operation_version]


func _append_unique(values: Array[String], value: String) -> void:
	if not values.has(value):
		values.append(value)


func _manifest_less(left: Dictionary, right: Dictionary) -> bool:
	return _descriptor_key(str(left.get("operation_id", "")), int(left.get("operation_version", 0))) \
		< _descriptor_key(str(right.get("operation_id", "")), int(right.get("operation_version", 0)))


func _issue_less(left: Dictionary, right: Dictionary) -> bool:
	var severity_order := {"blocker": 0, "error": 1, "warning": 2}
	var left_key := "%d|%s|%s|%s|%s" % [
		severity_order.get(str(left.get("severity_id", "")), 99),
		left.get("domain_id", ""),
		left.get("definition_id", ""),
		left.get("path", ""),
		left.get("issue_code", ""),
	]
	var right_key := "%d|%s|%s|%s|%s" % [
		severity_order.get(str(right.get("severity_id", "")), 99),
		right.get("domain_id", ""),
		right.get("definition_id", ""),
		right.get("path", ""),
		right.get("issue_code", ""),
	]
	return left_key < right_key
