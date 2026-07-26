extends SceneTree

const SCHEMA := preload("res://scripts/cards/semantic/card_semantic_schema_v1.gd")
const COMPILER := preload("res://scripts/cards/semantic/card_semantic_compiler_v1.gd")

const CATALOG_PATH := "res://data/cards/card_runtime_catalog_v06.json"
const FACILITY_FIXTURE_PATH := "res://tests/fixtures/card_semantic_phase1/facility_commodity_golden.json"
const UNIT_FIXTURE_PATH := "res://tests/fixtures/card_semantic_phase1/unit_supply_golden.json"
const INTERACTION_FIXTURE_PATH := "res://tests/fixtures/card_semantic_phase1/interaction_counter_golden.json"
const EXPECTED_CATALOG_SHA256 := "b59b73489d23578558d4a7688a03f50a3ef4d776cf528cd9eafd0e1d2a0fcb40"

const FACILITY_ROOT_FIELDS := [
	"schema_version", "fixture_id", "schema_authority", "template_set_id",
	"source_catalog_id", "source_catalog_sha256", "canonicalization_profile_id",
	"expected_projection_count", "expected_active_count", "cases", "behavioral_proofs",
	"fail_closed_cases", "validation_contract",
]
const UNIT_ROOT_FIELDS := [
	"schema_version", "fixture_id", "template_set_id", "baseline_commit",
	"source_catalog_id", "source_catalog_path", "source_catalog_sha256",
	"expected_card_count", "expected_capability_only_count", "comparison_contract",
	"effect_capability_mappings", "cards", "capability_only_rows", "fail_closed_contract",
	"privacy_contract",
]
const INTERACTION_ROOT_FIELDS := [
	"schema_version", "fixture_id", "baseline_commit", "source_catalog_id",
	"source_catalog_path", "source_catalog_sha256", "expected_card_count",
	"comparison_contract", "response_timing_contract", "cards",
	"privacy_comparison_contract", "privacy_cases",
]
const FACILITY_CASE_FIELDS := ["case_id", "source_card_id", "source_catalog_evidence", "expected_projection"]
const CARD_CASE_FIELDS := ["card_id", "catalog_values", "expected_semantic"]
const UNIT_CAPABILITY_CARD_FIELDS := ["card_id", "catalog_values", "expected_semantic", "capability_id"]

var _checks := 0
var _failures: Array[String] = []
var _mismatch_count := 0
var _compiled_card_count := 0
var _started_usec := 0


func _init() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")


func _run() -> void:
	var catalog_sha_before := FileAccess.get_sha256(CATALOG_PATH).to_lower()
	_expect(catalog_sha_before == EXPECTED_CATALOG_SHA256, "source catalog SHA matches the frozen fixtures")
	var catalog := _load_json_object(CATALOG_PATH)
	var facility := _load_normalized_json(FACILITY_FIXTURE_PATH)
	var unit_supply := _load_normalized_json(UNIT_FIXTURE_PATH)
	var interaction := _load_normalized_json(INTERACTION_FIXTURE_PATH)
	if catalog.is_empty() or facility.is_empty() or unit_supply.is_empty() or interaction.is_empty():
		_finish()
		return

	_expect(_fixture_shape_valid("facility", facility), "facility fixture uses the exact closed shape")
	_expect(_fixture_shape_valid("unit", unit_supply), "unit fixture uses the exact closed shape")
	_expect(_fixture_shape_valid("interaction", interaction), "interaction fixture uses the exact closed shape")
	_verify_extra_fixture_fields_fail_closed("facility", facility)
	_verify_extra_fixture_fields_fail_closed("unit", unit_supply)
	_verify_extra_fixture_fields_fail_closed("interaction", interaction)

	var catalog_id := str(catalog.get("catalog_id", ""))
	var cards: Array = catalog.get("cards", []) as Array
	var by_id: Dictionary = {}
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var record := card_variant as Dictionary
		var machine: Dictionary = record.get("machine", {}) as Dictionary
		by_id[str(machine.get("card_id", ""))] = record
	_expect(catalog_id == "space_syndicate.card_runtime_catalog.v06", "fixture compiler uses the sole v0.6 source catalog")
	_expect(cards.size() == 348 and by_id.size() == 348, "source catalog index is complete and unique")
	for fixture in [facility, unit_supply, interaction]:
		_expect(str((fixture as Dictionary).get("source_catalog_id", "")) == catalog_id, "fixture source catalog ID matches authority")
		_expect(str((fixture as Dictionary).get("source_catalog_sha256", "")).to_lower() == catalog_sha_before, "fixture source catalog SHA matches authority")

	var compiler = COMPILER.new()
	_compile_exact_fixture("facility", facility.get("cases", []) as Array, "source_card_id", "expected_projection", by_id, catalog_id, compiler, false)
	_compile_exact_fixture("unit", unit_supply.get("cards", []) as Array, "card_id", "expected_semantic", by_id, catalog_id, compiler, true)
	_compile_interaction_fixture(interaction.get("cards", []) as Array, by_id, catalog_id, compiler)

	_expect(_compiled_card_count == 40, "all 40 representative cards compile")
	_expect(_mismatch_count == 0, "all 40 golden cards have zero semantic mismatches")
	_expect(int(facility.get("expected_projection_count", -1)) == 12, "facility fixture declares 12 exact projections")
	_expect(int(unit_supply.get("expected_card_count", -1)) == 16, "unit fixture declares 16 exact projections")
	_expect(int(interaction.get("expected_card_count", -1)) == 12, "interaction fixture declares 12 declared-field projections")

	var extra_spec_result := compiler.compile_card_record(by_id.values()[0] as Dictionary, catalog_id)
	if bool(extra_spec_result.get("ok", false)):
		var extra_spec: Dictionary = (extra_spec_result.get("spec", {}) as Dictionary).duplicate(true)
		extra_spec["fixture_only_extra"] = true
		_expect(not bool(SCHEMA.validate_semantic_spec(extra_spec).get("valid", true)), "unknown semantic fixture field fails closed in the sole schema")
	else:
		_expect(false, "extra-field schema probe compiles")

	var catalog_sha_after := FileAccess.get_sha256(CATALOG_PATH).to_lower()
	_expect(catalog_sha_after == catalog_sha_before, "source catalog bytes remain unchanged")
	_finish()


func _compile_exact_fixture(
	fixture_id: String,
	rows: Array,
	card_id_field: String,
	expected_field: String,
	by_id: Dictionary,
	catalog_id: String,
	compiler: CardSemanticCompilerV1,
	normalize_source_integrals: bool
) -> void:
	for row_variant in rows:
		if not (row_variant is Dictionary):
			_record_mismatch("%s row is not a dictionary" % fixture_id)
			continue
		var row := row_variant as Dictionary
		var card_id := str(row.get(card_id_field, ""))
		var record: Dictionary = by_id.get(card_id, {}) as Dictionary
		_expect(not record.is_empty(), "%s source card exists: %s" % [fixture_id, card_id])
		if record.is_empty():
			_record_mismatch("%s missing source %s" % [fixture_id, card_id])
			continue
		if row.has("catalog_values"):
			_expect(_catalog_values_match(record, row.get("catalog_values", {}) as Dictionary), "%s catalog values match: %s" % [fixture_id, card_id])
		elif row.has("source_catalog_evidence"):
			_expect(_facility_evidence_matches(record, row.get("source_catalog_evidence", {}) as Dictionary), "%s source evidence matches: %s" % [fixture_id, card_id])
		var compile_record: Dictionary = (
			_normalize_integral_json_values(record) as Dictionary
			if normalize_source_integrals
			else record
		)
		var result := compiler.compile_card_record(compile_record, catalog_id)
		var repeated := compiler.compile_card_record(compile_record, catalog_id)
		_expect(bool(result.get("ok", false)) and bool(repeated.get("ok", false)), "%s compiler accepts %s" % [fixture_id, card_id])
		if not bool(result.get("ok", false)):
			_record_mismatch("%s compile failed %s" % [fixture_id, card_id])
			continue
		var actual: Dictionary = result.get("spec", {}) as Dictionary
		var expected: Dictionary = row.get(expected_field, {}) as Dictionary
		_compiled_card_count += 1
		_expect(bool(SCHEMA.validate_semantic_spec(actual).get("valid", false)), "%s schema validates %s" % [fixture_id, card_id])
		_expect(SCHEMA.is_pure_data(actual), "%s semantic spec is pure data: %s" % [fixture_id, card_id])
		_expect(SCHEMA.fingerprint(actual, "semantic_fingerprint") == str(actual.get("semantic_fingerprint", "")), "%s semantic fingerprint recomputes: %s" % [fixture_id, card_id])
		_expect(SCHEMA.canonical_json(actual) == SCHEMA.canonical_json(repeated.get("spec", {})), "%s repeated compile is deterministic: %s" % [fixture_id, card_id])
		_expect(_effect_op_ids(actual) == _effect_op_ids(expected), "%s effect-op order matches: %s" % [fixture_id, card_id])
		_expect(str(actual.get("runtime_readiness_id", "")) == str(expected.get("runtime_readiness_id", "")), "%s readiness matches: %s" % [fixture_id, card_id])
		if normalize_source_integrals:
			var raw_result := COMPILER.new().compile_card_record(record, catalog_id)
			_expect(
				bool(raw_result.get("ok", false))
					and SCHEMA.canonical_json(_without_fingerprints(raw_result.get("spec", {}) as Dictionary))
						== SCHEMA.canonical_json(_without_fingerprints(actual)),
				"%s integral normalization changes fingerprints only: %s" % [fixture_id, card_id]
			)
		if SCHEMA.canonical_json(actual) != SCHEMA.canonical_json(expected):
			_record_mismatch("%s exact semantic mismatch %s" % [fixture_id, card_id])


func _compile_interaction_fixture(
	rows: Array,
	by_id: Dictionary,
	catalog_id: String,
	compiler: CardSemanticCompilerV1
) -> void:
	for row_variant in rows:
		if not (row_variant is Dictionary):
			_record_mismatch("interaction row is not a dictionary")
			continue
		var row := row_variant as Dictionary
		var card_id := str(row.get("card_id", ""))
		var record: Dictionary = by_id.get(card_id, {}) as Dictionary
		_expect(not record.is_empty(), "interaction source card exists: %s" % card_id)
		if record.is_empty():
			_record_mismatch("interaction missing source %s" % card_id)
			continue
		_expect(_catalog_values_match(record, row.get("catalog_values", {}) as Dictionary), "interaction catalog values match: %s" % card_id)
		var result := compiler.compile_card_record(record, catalog_id)
		var repeated := compiler.compile_card_record(record, catalog_id)
		_expect(bool(result.get("ok", false)) and bool(repeated.get("ok", false)), "interaction compiler accepts %s" % card_id)
		if not bool(result.get("ok", false)):
			_record_mismatch("interaction compile failed %s" % card_id)
			continue
		var actual: Dictionary = result.get("spec", {}) as Dictionary
		var expected: Dictionary = row.get("expected_semantic", {}) as Dictionary
		var declared_actual: Dictionary = {}
		for key_variant in expected.keys():
			declared_actual[key_variant] = actual.get(key_variant)
		var machine: Dictionary = record.get("machine", {}) as Dictionary
		var expected_source_fingerprint := SCHEMA.fingerprint({
			"source_catalog_id": catalog_id,
			"machine": machine,
		})
		_compiled_card_count += 1
		_expect(bool(SCHEMA.validate_semantic_spec(actual).get("valid", false)), "interaction schema validates %s" % card_id)
		_expect(SCHEMA.is_pure_data(actual), "interaction semantic spec is pure data: %s" % card_id)
		_expect(str(actual.get("source_definition_fingerprint", "")) == expected_source_fingerprint, "interaction source fingerprint computes: %s" % card_id)
		_expect(SCHEMA.fingerprint(actual, "semantic_fingerprint") == str(actual.get("semantic_fingerprint", "")), "interaction semantic fingerprint computes: %s" % card_id)
		_expect(SCHEMA.canonical_json(actual) == SCHEMA.canonical_json(repeated.get("spec", {})), "interaction repeated compile is deterministic: %s" % card_id)
		_expect(_effect_op_ids(actual) == _effect_op_ids(expected), "interaction effect-op order matches: %s" % card_id)
		_expect(str(actual.get("runtime_readiness_id", "")) == str(expected.get("runtime_readiness_id", "")), "interaction readiness matches: %s" % card_id)
		if not _recursive_subset_matches(declared_actual, expected):
			_record_mismatch("interaction declared semantic mismatch %s" % card_id)


func _fixture_shape_valid(kind: String, fixture: Dictionary) -> bool:
	var root_fields: Array = []
	var row_fields: Array = []
	var rows: Array = []
	match kind:
		"facility":
			root_fields = FACILITY_ROOT_FIELDS
			row_fields = FACILITY_CASE_FIELDS
			rows = fixture.get("cases", []) as Array
		"unit":
			root_fields = UNIT_ROOT_FIELDS
			row_fields = CARD_CASE_FIELDS
			rows = fixture.get("cards", []) as Array
		"interaction":
			root_fields = INTERACTION_ROOT_FIELDS
			row_fields = CARD_CASE_FIELDS
			rows = fixture.get("cards", []) as Array
		_:
			return false
	if not _has_exact_fields(fixture, root_fields):
		return false
	for row_variant in rows:
		if not (row_variant is Dictionary):
			return false
		var row := row_variant as Dictionary
		var row_valid := _has_exact_fields(row, row_fields)
		if kind == "unit":
			row_valid = row_valid or _has_exact_fields(row, UNIT_CAPABILITY_CARD_FIELDS)
		if not row_valid:
			return false
	return true


func _verify_extra_fixture_fields_fail_closed(kind: String, fixture: Dictionary) -> void:
	var extra_root := fixture.duplicate(true)
	extra_root["unexpected_fixture_field"] = true
	_expect(not _fixture_shape_valid(kind, extra_root), "%s unknown root fixture field fails closed" % kind)
	var extra_row := fixture.duplicate(true)
	var row_key := "cases" if kind == "facility" else "cards"
	var rows: Array = extra_row.get(row_key, []) as Array
	if not rows.is_empty() and rows[0] is Dictionary:
		(rows[0] as Dictionary)["unexpected_row_field"] = true
		_expect(not _fixture_shape_valid(kind, extra_row), "%s unknown row fixture field fails closed" % kind)
	else:
		_expect(false, "%s fixture has a row for fail-closed probing" % kind)


func _catalog_values_match(record: Dictionary, expected: Dictionary) -> bool:
	var machine: Dictionary = record.get("machine", {}) as Dictionary
	var developer: Dictionary = record.get("developer", {}) as Dictionary
	for key_variant in expected.keys():
		var key := str(key_variant)
		var source: Dictionary = machine if machine.has(key) else developer
		if not source.has(key) or not _recursive_subset_matches(source.get(key), expected.get(key)):
			return false
	return true


func _recursive_subset_matches(actual: Variant, expected: Variant) -> bool:
	if expected is Dictionary:
		if not (actual is Dictionary):
			return false
		for key_variant in (expected as Dictionary).keys():
			if not (actual as Dictionary).has(key_variant) \
					or not _recursive_subset_matches(
						(actual as Dictionary).get(key_variant),
						(expected as Dictionary).get(key_variant)
					):
				return false
		return true
	if expected is Array:
		if not (actual is Array) or (actual as Array).size() != (expected as Array).size():
			return false
		for index in range((expected as Array).size()):
			if not _recursive_subset_matches((actual as Array)[index], (expected as Array)[index]):
				return false
		return true
	return actual == expected


func _facility_evidence_matches(record: Dictionary, evidence: Dictionary) -> bool:
	var machine: Dictionary = record.get("machine", {}) as Dictionary
	if str(machine.get("effect_kind", "")) != str(evidence.get("effect_kind", "")) \
			or str(machine.get("target_kind", "")) != str(evidence.get("target_kind", "")):
		return false
	if evidence.has("opaque_product_id"):
		var payload: Dictionary = machine.get("effect_payload", {}) as Dictionary
		return str(payload.get("product_id", "")) == str(evidence.get("opaque_product_id", ""))
	return true


func _effect_op_ids(spec: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for op_variant in spec.get("effect_ops", []) as Array:
		result.append(str((op_variant as Dictionary).get("op_id", "")) if op_variant is Dictionary else "")
	return result


func _without_fingerprints(spec: Dictionary) -> Dictionary:
	var result := spec.duplicate(true)
	result.erase("source_definition_fingerprint")
	result.erase("semantic_fingerprint")
	return result


func _has_exact_fields(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for field_variant in expected:
		if not value.has(str(field_variant)):
			return false
	return true


func _load_normalized_json(path: String) -> Dictionary:
	var parsed := _load_json_object(path)
	var normalized: Variant = _normalize_integral_json_values(parsed)
	return normalized as Dictionary if normalized is Dictionary else {}


func _load_json_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_expect(false, "JSON source exists: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(parsed is Dictionary, "JSON source parses: %s" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _normalize_integral_json_values(value: Variant) -> Variant:
	if value is float:
		var number := float(value)
		if is_finite(number) and number == floor(number) \
				and number >= -9007199254740991.0 and number <= 9007199254740991.0:
			return int(number)
		return number
	if value is Array:
		var result: Array = []
		for item in value as Array:
			result.append(_normalize_integral_json_values(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key_variant in (value as Dictionary).keys():
			result[str(key_variant)] = _normalize_integral_json_values((value as Dictionary).get(key_variant))
		return result
	return value


func _record_mismatch(message: String) -> void:
	_mismatch_count += 1
	_failures.append(message)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var elapsed_usec := Time.get_ticks_usec() - _started_usec
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"CARD_SEMANTIC_GOLDEN_FIXTURE_TEST|status=%s|checks=%d|failures=%d|cards=%d|mismatches=%d|elapsed_usec=%d"
		% [status, _checks, _failures.size(), _compiled_card_count, _mismatch_count, elapsed_usec]
	)
	for failure in _failures:
		push_error("CARD_SEMANTIC_GOLDEN_FIXTURE_TEST: %s" % failure)
	print("CARD_SEMANTIC_GOLDEN_FIXTURE_TEST_COMPLETE")
	quit(0 if _failures.is_empty() else 1)
