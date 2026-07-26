@tool
extends Node
class_name CardSemanticCatalogService

const COMPILER := preload("res://scripts/cards/semantic/card_semantic_compiler_v1.gd")
const SCHEMA := preload("res://scripts/cards/semantic/card_semantic_schema_v1.gd")

@export var configure_on_ready := true
@export var _catalog: CardRuntimeCatalogV06Resource

var _compiler = COMPILER.new()
var _configured := false
var _configuration_attempt_count := 0
var _source_catalog_id := ""
var _authorized_record_canonical_by_card_id: Dictionary = {}
var _authorized_spec_canonical_by_card_id: Dictionary = {}
var _authorized_specs_by_card_id: Dictionary = {}
var _summary: Dictionary = {
	"schema_version": 1,
	"configured": false,
	"source_catalog_id": "",
	"source_record_count": 0,
	"compiled_count": 0,
	"active_count": 0,
	"projection_only_count": 0,
	"not_acquirable_count": 0,
	"op_counts": {},
	"source_catalog_fingerprint": "",
	"semantic_catalog_fingerprint": "",
	"error_count": 0,
	"errors": [],
}


func _ready() -> void:
	if configure_on_ready and not Engine.is_editor_hint():
		configure()


func configure() -> Dictionary:
	if _configured:
		return validation_snapshot()
	_configuration_attempt_count += 1
	if _catalog == null:
		_set_failure(["catalog_resource_missing"])
		return validation_snapshot()
	var catalog_report := _catalog.reload()
	if not bool(catalog_report.get("valid", false)):
		_set_failure([{"error_id": "catalog_validation_failed", "details": (catalog_report.get("errors", []) as Array).duplicate()}])
		return validation_snapshot()
	var catalog_snapshot := _catalog.catalog_snapshot()
	_source_catalog_id = str(catalog_snapshot.get("catalog_id", ""))
	var compile_report := _compiler.compile_catalog_snapshot(catalog_snapshot)
	var membership_errors: Array = []
	if bool(compile_report.get("ok", false)):
		membership_errors = _seal_authoritative_membership(catalog_snapshot)
	var compile_errors: Array = (compile_report.get("errors", []) as Array).duplicate(true)
	compile_errors.append_array(membership_errors)
	_summary = {
		"schema_version": SCHEMA.SCHEMA_VERSION,
		"configured": bool(compile_report.get("ok", false)) and membership_errors.is_empty(),
		"source_catalog_id": _source_catalog_id,
		"source_record_count": int(compile_report.get("source_record_count", 0)),
		"compiled_count": int(compile_report.get("compiled_count", 0)),
		"active_count": int(compile_report.get("active_count", 0)),
		"projection_only_count": int(compile_report.get("projection_only_count", 0)),
		"not_acquirable_count": int(compile_report.get("not_acquirable_count", 0)),
		"op_counts": (compile_report.get("op_counts", {}) as Dictionary).duplicate(true),
		"source_catalog_fingerprint": str(compile_report.get("source_catalog_fingerprint", "")),
		"semantic_catalog_fingerprint": str(compile_report.get("semantic_catalog_fingerprint", "")),
		"error_count": compile_errors.size(),
		"errors": compile_errors,
	}
	_configured = bool(_summary["configured"])
	if not _configured:
		_clear_authoritative_membership()
	return validation_snapshot()


func compile_authorized(envelope: Dictionary) -> Dictionary:
	if not _configured:
		configure()
	if not _configured:
		return _failure_result("semantic_catalog_not_configured")
	var envelope_report: Dictionary = SCHEMA.validate_authorized_envelope(envelope)
	if not bool(envelope_report.get("valid", false)):
		return {
			"ok": false,
			"spec": {},
			"errors": (envelope_report.get("errors", []) as Array).duplicate(),
			"source_definition_fingerprint": "",
			"cache_hit": false,
		}
	var card_record := envelope.get("card_record", {}) as Dictionary
	var machine_value: Variant = card_record.get("machine")
	if not (machine_value is Dictionary):
		return _failure_result("catalog_record_machine_invalid")
	var machine := machine_value as Dictionary
	var card_id := str(machine.get("card_id", ""))
	if not _authorized_record_canonical_by_card_id.has(card_id):
		return _failure_result("catalog_record_not_registered")
	var supplied_canonical := SCHEMA.canonical_json(card_record)
	if supplied_canonical.is_empty() or supplied_canonical != str(
		_authorized_record_canonical_by_card_id.get(card_id, "")
	):
		return _failure_result("catalog_record_content_mismatch")
	return _compiler.compile_authorized(envelope.duplicate(true), _source_catalog_id)


func authorize_semantic_spec(semantic_spec: Dictionary) -> Dictionary:
	if not _configured:
		configure()
	if not _configured:
		return _semantic_authorization_failure("semantic_catalog_not_configured")
	var identity_value: Variant = semantic_spec.get("identity")
	if not (identity_value is Dictionary):
		return _semantic_authorization_failure("semantic_spec_identity_invalid")
	var identity := identity_value as Dictionary
	var card_id := str(identity.get("card_id", ""))
	if not _authorized_specs_by_card_id.has(card_id):
		return _semantic_authorization_failure("semantic_spec_not_registered")
	var supplied_canonical := SCHEMA.canonical_json(semantic_spec)
	if supplied_canonical.is_empty() or supplied_canonical != str(
		_authorized_spec_canonical_by_card_id.get(card_id, "")
	):
		return _semantic_authorization_failure("semantic_spec_content_mismatch")
	return {
		"ok": true,
		"spec": (_authorized_specs_by_card_id[card_id] as Dictionary).duplicate(true),
		"errors": [],
	}


func validation_snapshot() -> Dictionary:
	var snapshot := _summary.duplicate(true)
	var metrics := _compiler.cache_metrics()
	snapshot["configuration_attempt_count"] = _configuration_attempt_count
	snapshot["cache_entry_count"] = int(metrics.get("cache_entry_count", 0))
	snapshot["compile_count"] = int(metrics.get("compile_count", 0))
	snapshot["cache_hit_count"] = int(metrics.get("cache_hit_count", 0))
	snapshot["compile_failure_count"] = int(metrics.get("failure_count", 0))
	return snapshot


func debug_snapshot() -> Dictionary:
	return validation_snapshot()


func _seal_authoritative_membership(catalog_snapshot: Dictionary) -> Array:
	var errors: Array = []
	var cards_value: Variant = catalog_snapshot.get("cards")
	if not (cards_value is Array):
		return ["catalog_membership_cards_invalid"]
	var record_canonical_by_card_id: Dictionary = {}
	var spec_canonical_by_card_id: Dictionary = {}
	var specs_by_card_id: Dictionary = {}
	for index in range((cards_value as Array).size()):
		var record_value: Variant = (cards_value as Array)[index]
		if not (record_value is Dictionary):
			errors.append("catalog_membership_record_invalid:%d" % index)
			continue
		var record := record_value as Dictionary
		var machine := record.get("machine", {}) as Dictionary
		var card_id := str(machine.get("card_id", ""))
		if not SCHEMA.is_stable_id(card_id) or record_canonical_by_card_id.has(card_id):
			errors.append("catalog_membership_identity_invalid:%d" % index)
			continue
		var record_canonical := SCHEMA.canonical_json(record)
		if record_canonical.is_empty():
			errors.append("catalog_membership_record_not_pure_data:%s" % card_id)
			continue
		var compiled := _compiler.compile_card_record(record, _source_catalog_id)
		if not bool(compiled.get("ok", false)):
			errors.append({
				"error_id": "catalog_membership_compile_failed",
				"card_id": card_id,
				"details": (compiled.get("errors", []) as Array).duplicate(),
			})
			continue
		var spec := compiled.get("spec", {}) as Dictionary
		var spec_identity := spec.get("identity", {}) as Dictionary
		var spec_canonical := SCHEMA.canonical_json(spec)
		if str(spec_identity.get("card_id", "")) != card_id or spec_canonical.is_empty():
			errors.append("catalog_membership_spec_invalid:%s" % card_id)
			continue
		record_canonical_by_card_id[card_id] = record_canonical
		spec_canonical_by_card_id[card_id] = spec_canonical
		specs_by_card_id[card_id] = spec.duplicate(true)
	if specs_by_card_id.size() != (cards_value as Array).size():
		errors.append("catalog_membership_count_mismatch")
	if errors.is_empty():
		_authorized_record_canonical_by_card_id = record_canonical_by_card_id
		_authorized_spec_canonical_by_card_id = spec_canonical_by_card_id
		_authorized_specs_by_card_id = specs_by_card_id
	return errors


func _clear_authoritative_membership() -> void:
	_authorized_record_canonical_by_card_id.clear()
	_authorized_spec_canonical_by_card_id.clear()
	_authorized_specs_by_card_id.clear()


func _failure_result(error_id: String) -> Dictionary:
	return {
		"ok": false,
		"spec": {},
		"errors": [error_id],
		"source_definition_fingerprint": "",
		"cache_hit": false,
	}


func _semantic_authorization_failure(error_id: String) -> Dictionary:
	return {"ok": false, "spec": {}, "errors": [error_id]}


func _set_failure(errors: Array) -> void:
	_configured = false
	_source_catalog_id = ""
	_clear_authoritative_membership()
	_summary = {
		"schema_version": SCHEMA.SCHEMA_VERSION,
		"configured": false,
		"source_catalog_id": "",
		"source_record_count": 0,
		"compiled_count": 0,
		"active_count": 0,
		"projection_only_count": 0,
		"not_acquirable_count": 0,
		"op_counts": {},
		"source_catalog_fingerprint": "",
		"semantic_catalog_fingerprint": "",
		"error_count": errors.size(),
		"errors": errors.duplicate(true),
	}
