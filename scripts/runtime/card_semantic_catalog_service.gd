@tool
extends Node
class_name CardSemanticCatalogService

const COMPILER := preload("res://scripts/cards/semantic/card_semantic_compiler_v1.gd")
const SCHEMA := preload("res://scripts/cards/semantic/card_semantic_schema_v1.gd")
const LEGACY_V04_INTERACTION_REFERENCE := preload(
	"res://scripts/cards/semantic/card_v04_interaction_semantic_reference_adapter_v1.gd"
)

const PUBLIC_CODEX_AUTHORIZATION_SCHEMA_VERSION := 1
const PUBLIC_CODEX_SOURCE_KIND := "codex_public_catalog"
const PUBLIC_CODEX_VISIBILITY_SCOPE_ID := "public"
const PUBLIC_CODEX_REQUEST_KEYS := [
	"schema_version",
	"source_kind",
	"visibility_scope_id",
	"source_catalog_id",
	"catalog_membership_fingerprint",
	"catalog_member_id",
	"catalog_ordinal",
	"source_record_fingerprint",
	"card_record",
	"request_fingerprint",
]
const PUBLIC_CODEX_RESULT_KEYS := [
	"schema_version",
	"accepted",
	"reason_id",
	"semantic_spec",
	"authorization_receipt",
	"cache_hit",
]
const PUBLIC_CODEX_RECEIPT_KEYS := [
	"schema_version",
	"receipt_id",
	"accepted",
	"reason_id",
	"source_kind",
	"visibility_scope_id",
	"source_catalog_id",
	"catalog_membership_fingerprint",
	"catalog_member_id",
	"catalog_ordinal",
	"source_record_fingerprint",
	"source_definition_fingerprint",
	"semantic_fingerprint",
	"runtime_readiness_id",
	"request_fingerprint",
	"receipt_fingerprint",
]
const LEGACY_V04_INTERACTION_WITNESS_RESULT_KEYS := [
	"schema_version",
	"accepted",
	"reason_id",
	"effect_witness",
]
const LEGACY_V04_INTERACTION_WITNESS_KEYS := [
	"schema_version",
	"witness_id",
	"adapter_id",
	"semantic_source_catalog_id",
	"semantic_card_id",
	"semantic_family_id",
	"semantic_rank",
	"semantic_fingerprint",
	"runtime_readiness_id",
	"effect_ops",
	"legacy_definition_fingerprint",
	"mapping_fingerprint",
	"request_fingerprint",
	"witness_fingerprint",
]

@export var configure_on_ready := true
@export var _catalog: CardRuntimeCatalogV06Resource

var _compiler = COMPILER.new()
var _configured := false
var _configuration_attempt_count := 0
var _source_catalog_id := ""
var _authorized_record_canonical_by_card_id: Dictionary = {}
var _authorized_record_fingerprint_by_card_id: Dictionary = {}
var _authorized_spec_canonical_by_card_id: Dictionary = {}
var _authorized_specs_by_card_id: Dictionary = {}
var _authorized_card_ids_by_catalog_ordinal: Array[String] = []
var _public_catalog_membership_fingerprint := ""
var _public_codex_authorization_attempt_count := 0
var _public_codex_authorization_success_count := 0
var _public_codex_authorization_rejection_count := 0
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
	"public_catalog_membership_fingerprint": "",
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
		"public_catalog_membership_fingerprint": _public_catalog_membership_fingerprint,
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


func authorize_v04_interaction_effect_witness(
	request: Dictionary
) -> Dictionary:
	if not _configured:
		configure()
	if not _configured:
		return _legacy_v04_interaction_witness_failure(
			"semantic_catalog_not_configured"
		)
	if not LEGACY_V04_INTERACTION_REFERENCE.validate_witness_request(request):
		return _legacy_v04_interaction_witness_failure(
			"legacy_v04_interaction_witness_request_invalid"
		)
	var semantic_card_id := str(request.get("semantic_card_id", ""))
	if not _authorized_specs_by_card_id.has(semantic_card_id):
		return _legacy_v04_interaction_witness_failure(
			"legacy_v04_interaction_semantic_reference_not_registered"
		)
	var semantic_spec := _authorized_specs_by_card_id.get(
		semantic_card_id,
		{}
	) as Dictionary
	var identity_value: Variant = semantic_spec.get("identity")
	var effect_ops_value: Variant = semantic_spec.get("effect_ops")
	if not (identity_value is Dictionary) or not (effect_ops_value is Array):
		return _legacy_v04_interaction_witness_failure(
			"legacy_v04_interaction_semantic_witness_invalid"
		)
	var identity := identity_value as Dictionary
	var effect_ops := effect_ops_value as Array
	if str(identity.get("card_id", "")) != semantic_card_id \
			or str(identity.get("family_id", "")) \
				!= str(request.get("semantic_family_id", "")) \
			or identity.get("rank") != request.get("semantic_rank") \
			or effect_ops.is_empty() or effect_ops.size() > 2:
		return _legacy_v04_interaction_witness_failure(
			"legacy_v04_interaction_semantic_witness_binding_invalid"
		)
	for op_value in effect_ops:
		if not (op_value is Dictionary) \
				or not bool(SCHEMA.validate_effect_op(op_value).get(
					"valid",
					false
				)):
			return _legacy_v04_interaction_witness_failure(
				"legacy_v04_interaction_semantic_effect_op_invalid"
			)
	var request_fingerprint := str(request.get("request_fingerprint", ""))
	var witness := {
		"schema_version": LEGACY_V04_INTERACTION_REFERENCE.SCHEMA_VERSION,
		"witness_id": "card-v04-interaction-effect-witness:%s" \
			% request_fingerprint,
		"adapter_id": LEGACY_V04_INTERACTION_REFERENCE.ADAPTER_ID,
		"semantic_source_catalog_id": _source_catalog_id,
		"semantic_card_id": semantic_card_id,
		"semantic_family_id": str(identity.get("family_id", "")),
		"semantic_rank": int(identity.get("rank", 0)),
		"semantic_fingerprint": str(semantic_spec.get(
			"semantic_fingerprint",
			""
		)),
		"runtime_readiness_id": str(semantic_spec.get(
			"runtime_readiness_id",
			""
		)),
		"effect_ops": effect_ops.duplicate(true),
		"legacy_definition_fingerprint": str(request.get(
			"legacy_definition_fingerprint",
			""
		)),
		"mapping_fingerprint": str(request.get("mapping_fingerprint", "")),
		"request_fingerprint": request_fingerprint,
		"witness_fingerprint": "",
	}
	witness["witness_fingerprint"] = SCHEMA.fingerprint(
		witness,
		"witness_fingerprint"
	)
	if not SCHEMA.is_pure_data(witness) \
			or not _has_exact_keys(
				witness,
				LEGACY_V04_INTERACTION_WITNESS_KEYS
			) \
			or not _is_sha256(str(witness.get("semantic_fingerprint", ""))) \
			or not _is_sha256(str(witness.get("witness_fingerprint", ""))):
		return _legacy_v04_interaction_witness_failure(
			"legacy_v04_interaction_semantic_witness_invalid"
		)
	return {
		"schema_version": LEGACY_V04_INTERACTION_REFERENCE.SCHEMA_VERSION,
		"accepted": true,
		"reason_id": "authorized",
		"effect_witness": witness.duplicate(true),
	}


func authorize_public_codex_record(request: Dictionary) -> Dictionary:
	_public_codex_authorization_attempt_count += 1
	if not _configured:
		configure()
	if not _configured:
		return _public_codex_failure("semantic_catalog_not_configured")
	var request_reason := _public_codex_request_reason(request)
	if not request_reason.is_empty():
		return _public_codex_failure(request_reason)

	var card_id := str(request.get("catalog_member_id", ""))
	var catalog_ordinal := int(request.get("catalog_ordinal", -1))
	if str(request.get("source_catalog_id", "")) != _source_catalog_id:
		return _public_codex_failure("public_codex_source_catalog_stale")
	if str(request.get("catalog_membership_fingerprint", "")) \
			!= _public_catalog_membership_fingerprint:
		return _public_codex_failure("public_codex_catalog_membership_stale")
	if catalog_ordinal >= _authorized_card_ids_by_catalog_ordinal.size() \
			or _authorized_card_ids_by_catalog_ordinal[catalog_ordinal] != card_id:
		return _public_codex_failure(
			"public_codex_catalog_member_ordinal_mismatch"
		)
	if not _authorized_record_canonical_by_card_id.has(card_id):
		return _public_codex_failure("public_codex_catalog_member_not_registered")

	var card_record := request.get("card_record", {}) as Dictionary
	var machine_value: Variant = card_record.get("machine")
	if not (machine_value is Dictionary) \
			or str((machine_value as Dictionary).get("card_id", "")) != card_id:
		return _public_codex_failure(
			"public_codex_catalog_member_identity_mismatch"
		)
	var supplied_record_canonical := SCHEMA.canonical_json(card_record)
	if supplied_record_canonical.is_empty() \
			or supplied_record_canonical != str(
				_authorized_record_canonical_by_card_id.get(card_id, "")
			):
		return _public_codex_failure(
			"public_codex_catalog_record_content_mismatch"
		)
	var source_record_fingerprint := str(
		request.get("source_record_fingerprint", "")
	)
	if source_record_fingerprint != str(
		_authorized_record_fingerprint_by_card_id.get(card_id, "")
	) or source_record_fingerprint != SCHEMA.fingerprint(card_record):
		return _public_codex_failure(
			"public_codex_source_record_fingerprint_mismatch"
		)

	var compile_before := int(_compiler.cache_metrics().get("compile_count", 0))
	var compiled := compile_authorized({
		"schema_version": SCHEMA.SCHEMA_VERSION,
		"source_kind": "public_reveal",
		"source_revision": "codex.public.%s.%d" % [
			_public_catalog_membership_fingerprint.substr(0, 16),
			catalog_ordinal,
		],
		"visibility_scope_id": "public",
		"card_record": card_record,
	})
	var compile_after := int(_compiler.cache_metrics().get("compile_count", 0))
	if not bool(compiled.get("ok", false)):
		return _public_codex_failure("public_codex_semantic_compile_failed")
	if not bool(compiled.get("cache_hit", false)) or compile_after != compile_before:
		return _public_codex_failure("public_codex_semantic_cache_miss")
	var semantic_authorization := authorize_semantic_spec(
		compiled.get("spec", {}) as Dictionary
	)
	if not bool(semantic_authorization.get("ok", false)):
		return _public_codex_failure("public_codex_semantic_spec_unauthorized")
	var semantic_spec := semantic_authorization.get("spec", {}) as Dictionary
	var identity := semantic_spec.get("identity", {}) as Dictionary
	if str(identity.get("card_id", "")) != card_id:
		return _public_codex_failure("public_codex_semantic_identity_mismatch")
	var receipt := _public_codex_receipt(request, semantic_spec)
	if receipt.is_empty():
		return _public_codex_failure("public_codex_receipt_invalid")

	_public_codex_authorization_success_count += 1
	return {
		"schema_version": PUBLIC_CODEX_AUTHORIZATION_SCHEMA_VERSION,
		"accepted": true,
		"reason_id": "authorized",
		"semantic_spec": semantic_spec.duplicate(true),
		"authorization_receipt": receipt.duplicate(true),
		"cache_hit": true,
	}


func validation_snapshot() -> Dictionary:
	var snapshot := _summary.duplicate(true)
	var metrics := _compiler.cache_metrics()
	snapshot["configuration_attempt_count"] = _configuration_attempt_count
	snapshot["cache_entry_count"] = int(metrics.get("cache_entry_count", 0))
	snapshot["compile_count"] = int(metrics.get("compile_count", 0))
	snapshot["cache_hit_count"] = int(metrics.get("cache_hit_count", 0))
	snapshot["compile_failure_count"] = int(metrics.get("failure_count", 0))
	snapshot["public_catalog_membership_fingerprint"] = \
		_public_catalog_membership_fingerprint
	snapshot["public_codex_authorization_attempt_count"] = \
		_public_codex_authorization_attempt_count
	snapshot["public_codex_authorization_success_count"] = \
		_public_codex_authorization_success_count
	snapshot["public_codex_authorization_rejection_count"] = \
		_public_codex_authorization_rejection_count
	return snapshot


func debug_snapshot() -> Dictionary:
	return validation_snapshot()


func _seal_authoritative_membership(catalog_snapshot: Dictionary) -> Array:
	var errors: Array = []
	var cards_value: Variant = catalog_snapshot.get("cards")
	if not (cards_value is Array):
		return ["catalog_membership_cards_invalid"]
	var record_canonical_by_card_id: Dictionary = {}
	var record_fingerprint_by_card_id: Dictionary = {}
	var spec_canonical_by_card_id: Dictionary = {}
	var specs_by_card_id: Dictionary = {}
	var card_ids_by_catalog_ordinal: Array[String] = []
	var membership_entries: Array = []
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
		var record_fingerprint := SCHEMA.fingerprint(record)
		if record_canonical.is_empty() or record_fingerprint.is_empty():
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
		record_fingerprint_by_card_id[card_id] = record_fingerprint
		spec_canonical_by_card_id[card_id] = spec_canonical
		specs_by_card_id[card_id] = spec.duplicate(true)
		card_ids_by_catalog_ordinal.append(card_id)
		membership_entries.append({
			"catalog_ordinal": index,
			"catalog_member_id": card_id,
			"source_record_fingerprint": record_fingerprint,
		})
	if specs_by_card_id.size() != (cards_value as Array).size():
		errors.append("catalog_membership_count_mismatch")
	var membership_fingerprint := ""
	if errors.is_empty():
		membership_fingerprint = SCHEMA.fingerprint({
			"schema_version": PUBLIC_CODEX_AUTHORIZATION_SCHEMA_VERSION,
			"source_catalog_id": _source_catalog_id,
			"members": membership_entries,
		})
		if membership_fingerprint.is_empty():
			errors.append("catalog_membership_fingerprint_failed")
	if errors.is_empty():
		_authorized_record_canonical_by_card_id = record_canonical_by_card_id
		_authorized_record_fingerprint_by_card_id = \
			record_fingerprint_by_card_id
		_authorized_spec_canonical_by_card_id = spec_canonical_by_card_id
		_authorized_specs_by_card_id = specs_by_card_id
		_authorized_card_ids_by_catalog_ordinal = card_ids_by_catalog_ordinal
		_public_catalog_membership_fingerprint = membership_fingerprint
	return errors


func _clear_authoritative_membership() -> void:
	_authorized_record_canonical_by_card_id.clear()
	_authorized_record_fingerprint_by_card_id.clear()
	_authorized_spec_canonical_by_card_id.clear()
	_authorized_specs_by_card_id.clear()
	_authorized_card_ids_by_catalog_ordinal.clear()
	_public_catalog_membership_fingerprint = ""


func _public_codex_request_reason(request: Dictionary) -> String:
	if not _has_exact_keys(request, PUBLIC_CODEX_REQUEST_KEYS):
		return "public_codex_request_keys_invalid"
	if not SCHEMA.is_pure_data(request):
		return "public_codex_request_not_pure_data"
	var schema_version: Variant = request.get("schema_version")
	if not (schema_version is int) \
			or int(schema_version) != PUBLIC_CODEX_AUTHORIZATION_SCHEMA_VERSION:
		return "public_codex_request_schema_version_invalid"
	if str(request.get("source_kind", "")) != PUBLIC_CODEX_SOURCE_KIND:
		return "public_codex_source_kind_invalid"
	if str(request.get("visibility_scope_id", "")) \
			!= PUBLIC_CODEX_VISIBILITY_SCOPE_ID:
		return "public_codex_visibility_scope_invalid"
	if not SCHEMA.is_stable_id(str(request.get("source_catalog_id", ""))):
		return "public_codex_source_catalog_id_invalid"
	if not _is_sha256(str(request.get(
		"catalog_membership_fingerprint",
		""
	))):
		return "public_codex_catalog_membership_fingerprint_invalid"
	if not SCHEMA.is_stable_id(str(request.get("catalog_member_id", ""))):
		return "public_codex_catalog_member_id_invalid"
	var catalog_ordinal: Variant = request.get("catalog_ordinal")
	if not (catalog_ordinal is int) or int(catalog_ordinal) < 0:
		return "public_codex_catalog_ordinal_invalid"
	if not _is_sha256(str(request.get("source_record_fingerprint", ""))):
		return "public_codex_source_record_fingerprint_invalid"
	if not (request.get("card_record") is Dictionary):
		return "public_codex_card_record_invalid"
	var request_fingerprint := str(request.get("request_fingerprint", ""))
	if not _is_sha256(request_fingerprint) \
			or request_fingerprint \
				!= SCHEMA.fingerprint(request, "request_fingerprint"):
		return "public_codex_request_fingerprint_invalid"
	return ""


func _public_codex_receipt(
	request: Dictionary,
	semantic_spec: Dictionary
) -> Dictionary:
	var request_fingerprint := str(request.get("request_fingerprint", ""))
	var receipt := {
		"schema_version": PUBLIC_CODEX_AUTHORIZATION_SCHEMA_VERSION,
		"receipt_id": "card.codex.public.%s" % request_fingerprint,
		"accepted": true,
		"reason_id": "authorized",
		"source_kind": PUBLIC_CODEX_SOURCE_KIND,
		"visibility_scope_id": PUBLIC_CODEX_VISIBILITY_SCOPE_ID,
		"source_catalog_id": str(request.get("source_catalog_id", "")),
		"catalog_membership_fingerprint": str(
			request.get("catalog_membership_fingerprint", "")
		),
		"catalog_member_id": str(request.get("catalog_member_id", "")),
		"catalog_ordinal": int(request.get("catalog_ordinal", -1)),
		"source_record_fingerprint": str(
			request.get("source_record_fingerprint", "")
		),
		"source_definition_fingerprint": str(
			semantic_spec.get("source_definition_fingerprint", "")
		),
		"semantic_fingerprint": str(
			semantic_spec.get("semantic_fingerprint", "")
		),
		"runtime_readiness_id": str(
			semantic_spec.get("runtime_readiness_id", "")
		),
		"request_fingerprint": request_fingerprint,
		"receipt_fingerprint": "",
	}
	receipt["receipt_fingerprint"] = SCHEMA.fingerprint(
		receipt,
		"receipt_fingerprint"
	)
	if not SCHEMA.is_pure_data(receipt) \
			or not _has_exact_keys(receipt, PUBLIC_CODEX_RECEIPT_KEYS) \
			or not _is_sha256(str(receipt.get(
				"source_definition_fingerprint",
				""
			))) \
			or not _is_sha256(str(receipt.get("semantic_fingerprint", ""))) \
			or not _is_sha256(str(receipt.get("receipt_fingerprint", ""))):
		return {}
	return receipt


func _public_codex_failure(reason_id: String) -> Dictionary:
	_public_codex_authorization_rejection_count += 1
	return {
		"schema_version": PUBLIC_CODEX_AUTHORIZATION_SCHEMA_VERSION,
		"accepted": false,
		"reason_id": reason_id,
		"semantic_spec": {},
		"authorization_receipt": {},
		"cache_hit": false,
	}


func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	var actual_keys: Array[String] = []
	for key_variant in value.keys():
		if not (key_variant is String):
			return false
		actual_keys.append(str(key_variant))
	var expected_keys: Array[String] = []
	for key_variant in expected:
		expected_keys.append(str(key_variant))
	actual_keys.sort()
	expected_keys.sort()
	return actual_keys == expected_keys


func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


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


func _legacy_v04_interaction_witness_failure(reason_id: String) -> Dictionary:
	var result := {
		"schema_version": LEGACY_V04_INTERACTION_REFERENCE.SCHEMA_VERSION,
		"accepted": false,
		"reason_id": reason_id,
		"effect_witness": {},
	}
	return result if _has_exact_keys(
		result,
		LEGACY_V04_INTERACTION_WITNESS_RESULT_KEYS
	) else {}


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
		"public_catalog_membership_fingerprint": "",
		"error_count": errors.size(),
		"errors": errors.duplicate(true),
	}
