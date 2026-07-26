extends Node
class_name CardSemanticCompilerBench

const COMPILER := preload("res://scripts/cards/semantic/card_semantic_compiler_v1.gd")
const SCHEMA := preload("res://scripts/cards/semantic/card_semantic_schema_v1.gd")
const CATALOG_JSON_PATH := "res://data/cards/card_runtime_catalog_v06.json"
const EXPECTED_OP_COUNTS := {
	"install_rate": 184,
	"build_facility": 64,
	"upgrade_facility": 64,
	"repair_facility": 64,
	"deploy_unit": 60,
	"upgrade_same_family_unit": 60,
	"extend_presence": 32,
	"heal_unit": 32,
	"modify_supply": 4,
	"modify_demand": 4,
	"discard_random": 4,
	"steal_random": 4,
	"lock_random": 6,
	"counter_action": 4,
	"install_organization_upgrade": 20,
}

@export var auto_run := true

@onready var semantic_service: CardSemanticCatalogService = $CardSemanticCatalogService

var result_snapshot: Dictionary = {}
var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_bench")


func run_bench() -> void:
	if not _failures.is_empty() or not result_snapshot.is_empty():
		return
	var service_summary := semantic_service.validation_snapshot()
	_expect(bool(service_summary.get("configured", false)), "service_configured")
	_expect(int(service_summary.get("source_record_count", 0)) == 348, "service_source_count")
	_expect(int(service_summary.get("compiled_count", 0)) == 348, "service_compiled_count")
	_expect(int(service_summary.get("active_count", 0)) == 256, "service_active_count")
	_expect(int(service_summary.get("projection_only_count", 0)) == 92, "service_projection_count")
	_expect(int(service_summary.get("not_acquirable_count", -1)) == 0, "service_not_acquirable_count")
	_expect(int(service_summary.get("error_count", -1)) == 0, "service_error_count")
	_expect((service_summary.get("op_counts", {}) as Dictionary) == EXPECTED_OP_COUNTS, "service_op_counts")
	_expect(_sha256(str(service_summary.get("source_catalog_fingerprint", ""))), "service_source_fingerprint")
	_expect(_sha256(str(service_summary.get("semantic_catalog_fingerprint", ""))), "service_semantic_fingerprint")

	var snapshot_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_JSON_PATH))
	_expect(snapshot_value is Dictionary, "catalog_json_loads")
	var snapshot: Dictionary = snapshot_value if snapshot_value is Dictionary else {}
	var cards: Array = snapshot.get("cards", []) if snapshot.get("cards", []) is Array else []
	_expect(cards.size() == 348, "catalog_record_count")
	if cards.is_empty():
		_finish(0)
		return

	var compile_start := Time.get_ticks_usec()
	var fresh_compiler = COMPILER.new()
	var fresh_report := fresh_compiler.compile_catalog_snapshot(snapshot)
	var compile_duration_usec := Time.get_ticks_usec() - compile_start
	_expect(bool(fresh_report.get("ok", false)), "fresh_catalog_compile")
	_expect(int(fresh_report.get("compiled_count", 0)) == 348, "fresh_compile_count")
	_expect(str(fresh_report.get("semantic_catalog_fingerprint", "")) == str(service_summary.get("semantic_catalog_fingerprint", "")), "fresh_semantic_fingerprint_determinism")
	_expect((fresh_report.get("op_counts", {}) as Dictionary) == EXPECTED_OP_COUNTS, "fresh_op_counts")

	var first_record: Dictionary = (cards[0] as Dictionary).duplicate(true)
	var envelope := {
		"schema_version": 1,
		"source_kind": "public_rack",
		"source_revision": 1,
		"visibility_scope_id": "public",
		"card_record": first_record,
	}
	var first := semantic_service.compile_authorized(envelope)
	var second := semantic_service.compile_authorized(envelope)
	_expect(bool(first.get("ok", false)) and bool(second.get("ok", false)), "authorized_compile_succeeds")
	_expect(bool(first.get("cache_hit", false)) and bool(second.get("cache_hit", false)), "authorized_reads_hit_eager_cache")
	var first_spec: Dictionary = first.get("spec", {})
	var original_card_id := str((first_spec.get("identity", {}) as Dictionary).get("card_id", ""))
	(first_spec["identity"] as Dictionary)["card_id"] = "mutated.by.bench.rank_1"
	var third := semantic_service.compile_authorized(envelope)
	var third_spec: Dictionary = third.get("spec", {})
	_expect(str((third_spec.get("identity", {}) as Dictionary).get("card_id", "")) == original_card_id, "cache_returns_detached_copies")
	_expect(bool(SCHEMA.validate_semantic_spec(third_spec).get("valid", false)), "returned_spec_validates")
	_expect(not JSON.stringify(third_spec).contains("product_id") and not _contains_non_ascii(third_spec), "localized_product_id_not_emitted")

	var unknown_effect := first_record.duplicate(true)
	(unknown_effect["machine"] as Dictionary)["effect_kind"] = "unknown_effect"
	_expect(not bool(COMPILER.new().compile_card_record(unknown_effect, str(snapshot.get("catalog_id", ""))).get("ok", true)), "unknown_effect_rejected")
	var unknown_target := first_record.duplicate(true)
	(unknown_target["machine"] as Dictionary)["target_kind"] = "unknown_target"
	_expect(not bool(COMPILER.new().compile_card_record(unknown_target, str(snapshot.get("catalog_id", ""))).get("ok", true)), "unknown_target_rejected")
	var missing_payload := first_record.duplicate(true)
	((missing_payload["machine"] as Dictionary)["effect_payload"] as Dictionary).erase("rate_per_minute")
	_expect(not bool(COMPILER.new().compile_card_record(missing_payload, str(snapshot.get("catalog_id", ""))).get("ok", true)), "missing_payload_field_rejected")
	var extra_payload := first_record.duplicate(true)
	((extra_payload["machine"] as Dictionary)["effect_payload"] as Dictionary)["unsupported_bonus"] = 1
	_expect(not bool(COMPILER.new().compile_card_record(extra_payload, str(snapshot.get("catalog_id", ""))).get("ok", true)), "extra_payload_field_rejected")

	var op_fixture: Dictionary = ((third_spec.get("effect_ops", []) as Array)[0] as Dictionary).duplicate(true)
	op_fixture["unsupported"] = true
	_expect(not bool(SCHEMA.validate_effect_op(op_fixture).get("valid", true)), "extra_op_field_rejected")
	op_fixture.erase("unsupported")
	op_fixture.erase("rate_units_per_minute")
	_expect(not bool(SCHEMA.validate_effect_op(op_fixture).get("valid", true)), "missing_op_field_rejected")
	for capability_id in ["military_move", "military_guard", "military_strike", "global_order", "global_supply_spawn"]:
		_expect(bool(SCHEMA.validate_effect_op({"op_id": capability_id}).get("valid", false)), "fixture_capability_%s" % capability_id)

	var canonical_a := SCHEMA.canonical_json({"z": [{"b": 2, "a": 1}], "a": true})
	var canonical_b := SCHEMA.canonical_json({"a": true, "z": [{"a": 1, "b": 2}]})
	_expect(canonical_a == canonical_b and canonical_a == "{\"a\":true,\"z\":[{\"a\":1,\"b\":2}]}", "recursive_canonical_json")
	_expect(SCHEMA.fingerprint({"b": 2, "a": 1}) == SCHEMA.fingerprint({"a": 1, "b": 2}), "canonical_sha256")
	_expect(not semantic_service.has_method("semantic_for_card_id") and not semantic_service.has_method("card_ids") and not semantic_service.has_method("catalog_snapshot"), "no_arbitrary_id_or_enumeration_api")

	var final_summary := semantic_service.validation_snapshot()
	_expect(int(final_summary.get("cache_entry_count", 0)) == 348, "cache_entry_count")
	_expect(int(final_summary.get("compile_count", 0)) == 348, "compile_once_count")
	_expect(int(final_summary.get("cache_hit_count", 0)) >= 3, "authorized_cache_hit_count")
	_finish(compile_duration_usec)


func _finish(compile_duration_usec: int) -> void:
	result_snapshot = {
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"checks": _checks,
		"failure_count": _failures.size(),
		"failures": _failures.duplicate(),
		"compiled_count": int(semantic_service.validation_snapshot().get("compiled_count", 0)),
		"compile_duration_ms": snappedf(float(compile_duration_usec) / 1000.0, 0.001),
		"cache": semantic_service.validation_snapshot(),
	}
	print("CARD_SEMANTIC_COMPILER_BENCH|status=%s|checks=%d|failures=%d|compiled=%d|duration_ms=%.3f" % [result_snapshot["status"], _checks, _failures.size(), result_snapshot["compiled_count"], result_snapshot["compile_duration_ms"]])
	if not _failures.is_empty():
		push_error("CardSemanticCompilerBench failed: %s" % JSON.stringify(_failures))


func _expect(condition: bool, failure_id: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(failure_id)


func _sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


func _contains_non_ascii(value: Variant) -> bool:
	if value is String:
		for index in range(str(value).length()):
			if str(value).unicode_at(index) > 127:
				return true
		return false
	if value is Array:
		for item in value:
			if _contains_non_ascii(item):
				return true
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if _contains_non_ascii(str(key)) or _contains_non_ascii((value as Dictionary)[key]):
				return true
	return false