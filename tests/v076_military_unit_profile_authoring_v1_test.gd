extends SceneTree

const ProfileCatalog := preload(
	"res://scripts/v076/military/v076_military_unit_profile_catalog_v1.gd"
)
const CatalogResource := preload(
	"res://scripts/cards/card_runtime_catalog_v06_resource.gd"
)
const BALANCE_DEFAULTS_PATH := "res://docs/rules/v075_combat_balance_defaults.json"
const CARD_MATRIX_PATH := (
	"res://reports/card_certification/v076_card_certification_matrix.json"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var adapter := ProfileCatalog.new()
	var source := CatalogResource.new()
	var source_report := source.reload()
	_expect(bool(source_report.get("valid", false)), "source card authority validates")
	var source_snapshot := source.catalog_snapshot()
	var balance := _read_json(BALANCE_DEFAULTS_PATH)
	var document := adapter.load_document()
	var report := adapter.validate_document(document, source_snapshot, balance)
	if not bool(report.get("valid", false)):
		print("V076_MILITARY_AUTHORING_DIAGNOSTIC|%s" % JSON.stringify(report))
		for record_variant in document.get("records", []):
			var record := record_variant as Dictionary
			print("V076_PROFILE_EXPECTED_FINGERPRINT|%s|%s" % [
				str(record.get("profile_id", "")),
				adapter.canonical_record_fingerprint(record),
			])
		print("V076_PROFILE_EXPECTED_CATALOG_FINGERPRINT|%s" %
			adapter.canonical_document_fingerprint(document))

	_expect(bool(report.get("valid", false)), "the unique Profile Authority validates")
	_expect(int(report.get("existing_military_profile_source_count", 0)) == 4,
		"four existing military profile sources were audited")
	_expect(int(report.get("reused_profile_schema_count", 0)) == 3,
		"three existing schemas are reused")
	_expect(bool(report.get("new_profile_schema_required", false)),
		"the versioned speed and provenance extension is justified")
	_expect(int(report.get("profile_authority_count", 0)) == 1,
		"there is exactly one Profile Authority")
	_expect(int(report.get("military_profile_record_count", 0)) == 28,
		"the Profile Authority closes all 28 military records")
	_expect(int(report.get("new_authored_profile_count", 0)) == 16,
		"exactly sixteen deferred records are newly authored")
	_expect(int(report.get("inherited_profile_count", 0)) == 12,
		"all twelve V075 combat profiles remain inherited")
	_expect(int(report.get("new_authored_speed_field_count", 0)) == 28,
		"all physical speeds are explicit new V076 authoring")
	_expect(int(report.get("profile_duplicate_count", -1)) == 0,
		"profile IDs and family/rank pairs are unique")
	_expect(int(report.get("profile_unknown_card_family_count", -1)) == 0,
		"all Profile families are known source families")
	_expect(str(report.get("source_profile_binding_coverage", "")) == "28/28",
		"every Profile binds one exact source card cost")
	_expect(str(report.get("profile_fingerprint_coverage", "")) == "28/28",
		"every Profile canonical fingerprint matches")
	_expect(int(report.get("speed_positive_count", 0)) == 28,
		"all Profile speeds are positive integers")
	_expect(int(report.get("asset_cost_positive_count", 0)) == 28,
		"all catalog-owned asset costs are positive")
	_expect(int(report.get("active_forbidden_mission_count", -1)) == 0,
		"no forbidden mission is active")
	_expect(int(report.get("active_persistent_unit_count", -1)) == 0,
		"no Profile creates a persistent unit")
	_expect(int(report.get("auto_retarget_count", -1)) == 0,
		"no Profile enables auto-retarget")
	_expect(int(report.get("auto_repeat_task_count", -1)) == 0,
		"no Profile enables auto-repeat")
	_expect(int(report.get("profile_fallback_count", -1)) == 0,
		"no Profile contains a mission fallback")
	_expect(int(report.get("name_based_runtime_inference_count", -1)) == 0,
		"runtime never infers Profile from names")
	_expect(int(report.get("text_based_runtime_parse_count", -1)) == 0,
		"runtime never parses player text")
	_expect(int(report.get("assault_region_power_monotonic_family_count", 0)) == 7,
		"all seven region power curves are monotonic")
	_expect(int(report.get("assault_monster_power_monotonic_family_count", 0)) == 7,
		"all seven monster power curves are monotonic")
	_expect(int(report.get("float_authority_field_count", -1)) == 0,
		"Profile authority contains no float fields")
	_expect(not str(report.get("profile_catalog_fingerprint_sha256", "")).is_empty(),
		"Profile catalog fingerprint is deterministic")
	_expect(not bool(report.get("production_green", true)),
		"authoring cannot claim production green")
	_expect(not bool(report.get("human_green", true)),
		"authoring cannot claim human green")

	for family_id in ProfileCatalog.FAMILY_IDS:
		var ranks := []
		for rank in range(1, 5):
			var profile := adapter.profile_for_family_rank(str(family_id), rank)
			if not profile.is_empty():
				ranks.append(int(profile.get("rank", 0)))
		_expect(ranks == [1, 2, 3, 4], "%s closes ranks I-IV" % str(family_id))

	var roundtrip: Variant = JSON.parse_string(JSON.stringify(document))
	_expect(
		roundtrip is Dictionary
			and adapter.normalize_json_value(roundtrip) == document,
		"Profile JSON roundtrips exactly")
	var reversed := document.duplicate(true)
	(reversed.get("records", []) as Array).reverse()
	_expect(adapter.canonical_document_fingerprint(reversed)
		== adapter.canonical_document_fingerprint(document),
		"record order does not change the canonical hash")

	var zero_speed := _tamper_record(document, 0, "speed_distance_mu_per_tick", 0, adapter)
	_expect(_has_error(adapter.validate_document(zero_speed, source_snapshot, balance),
		"profile_movement_invalid"), "zero speed fails closed")
	var negative_speed := _tamper_record(document, 0, "speed_distance_mu_per_tick", -1, adapter)
	_expect(_has_error(adapter.validate_document(negative_speed, source_snapshot, balance),
		"profile_movement_invalid"), "negative speed fails closed")
	var float_speed := _tamper_record(document, 0, "speed_distance_mu_per_tick", 1.5, adapter)
	_expect(_has_error(adapter.validate_document(float_speed, source_snapshot, balance),
		"profile_movement_invalid"), "float speed fails closed")
	var guard := _tamper_record(document, 0, "allowed_missions", ["GUARD"], adapter)
	_expect(_has_error(adapter.validate_document(guard, source_snapshot, balance),
		"profile_mission_forbidden"), "Guard fails closed")
	var protect := _tamper_record(document, 0, "allowed_missions", ["PROTECT"], adapter)
	_expect(_has_error(adapter.validate_document(protect, source_snapshot, balance),
		"profile_mission_forbidden"), "Protect fails closed")
	var persistent := _tamper_record(document, 0, "persistent_unit", true, adapter)
	_expect(_has_error(adapter.validate_document(persistent, source_snapshot, balance),
		"profile_lifecycle_invalid"), "persistent units fail closed")
	var retarget := _tamper_record(document, 0, "auto_retarget", true, adapter)
	_expect(_has_error(adapter.validate_document(retarget, source_snapshot, balance),
		"profile_lifecycle_invalid"), "auto-retarget fails closed")
	var repeat_task := _tamper_record(document, 0, "auto_repeat_task", true, adapter)
	_expect(_has_error(adapter.validate_document(repeat_task, source_snapshot, balance),
		"profile_lifecycle_invalid"), "auto-repeat fails closed")
	var wrong_lifecycle := _tamper_record(document, 0, "lifecycle", "PERSIST", adapter)
	_expect(_has_error(adapter.validate_document(wrong_lifecycle, source_snapshot, balance),
		"profile_lifecycle_invalid"), "non-withdrawing lifecycle fails closed")
	var inferred := _tamper_record(document, 0, "name_based_runtime_inference", true, adapter)
	_expect(_has_error(adapter.validate_document(inferred, source_snapshot, balance),
		"profile_runtime_inference_invalid"), "name inference fails closed")
	var parsed := _tamper_record(document, 0, "text_based_runtime_parse", true, adapter)
	_expect(_has_error(adapter.validate_document(parsed, source_snapshot, balance),
		"profile_runtime_inference_invalid"), "text parsing fails closed")
	var fallback := _tamper_record(document, 0, "mission_fallback", "ASSAULT_REGION", adapter)
	_expect(_has_error(adapter.validate_document(fallback, source_snapshot, balance),
		"profile_runtime_inference_invalid"), "mission fallback fails closed")

	var duplicate := document.duplicate(true)
	(duplicate.get("records", []) as Array).append(
		((duplicate.get("records", []) as Array)[0] as Dictionary).duplicate(true)
	)
	_expect(_has_error(adapter.validate_document(duplicate, source_snapshot, balance),
		"profile_duplicate"), "duplicate Profile fails closed")
	var missing := document.duplicate(true)
	(missing.get("records", []) as Array).remove_at(0)
	_expect(_has_error(adapter.validate_document(missing, source_snapshot, balance),
		"profile_family_rank_coverage_invalid"), "missing Profile fails closed")
	var unknown := _tamper_record(document, 0, "family_id", "unknown", adapter)
	_expect(_has_error(adapter.validate_document(unknown, source_snapshot, balance),
		"profile_unknown_family"), "unknown family fails closed")
	var source_drift := document.duplicate(true)
	var source_record := (source_drift.get("records", []) as Array)[0] as Dictionary
	(source_record.get("asset_cost_binding", {}) as Dictionary)[
		"expected_positive_amount"
	] = 999
	source_record["canonical_fingerprint"] = adapter.canonical_record_fingerprint(source_record)
	_expect(_has_error(adapter.validate_document(source_drift, source_snapshot, balance),
		"profile_asset_binding_invalid"), "source asset drift fails closed")

	var profile_tamper := adapter.profile_by_id("v076.military.orbital_bomber.rank_1")
	profile_tamper["canonical_fingerprint"] = "0".repeat(64)
	_expect(not bool(adapter.record_validation_report(profile_tamper).get("valid", true)),
		"Profile fingerprint tamper fails closed")
	_expect(adapter.profile_by_id("v076.military.unknown.rank_1").is_empty(),
		"unknown Profile lookup fails closed")

	var production_green := document.duplicate(true)
	production_green["production_green"] = true
	_expect(_has_error(adapter.validate_document(production_green, source_snapshot, balance),
		"profile_production_false_green"), "production false-green fails closed")
	var human_green := document.duplicate(true)
	human_green["human_green"] = true
	_expect(_has_error(adapter.validate_document(human_green, source_snapshot, balance),
		"profile_human_false_green"), "human false-green fails closed")
	var card_matrix := _read_json(CARD_MATRIX_PATH)
	_expect(int((card_matrix.get("aggregate", {}) as Dictionary).get(
		"alpha07_certified_card_count", -1
	)) == 0, "Card Matrix remains non-production and is not reset or falsely promoted")

	print("V076_MILITARY_AUTHORING_SELFTEST|status=%s|checks=%d|failures=%d|profiles=28|new=16" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(),
	])
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _tamper_record(
	document: Dictionary,
	index: int,
	field: String,
	value: Variant,
	adapter: RefCounted
) -> Dictionary:
	var tampered := document.duplicate(true)
	var record := (tampered.get("records", []) as Array)[index] as Dictionary
	record[field] = value
	record["canonical_fingerprint"] = adapter.canonical_record_fingerprint(record)
	return tampered


func _has_error(report: Dictionary, prefix: String) -> bool:
	for error_variant in report.get("errors", []):
		if str(error_variant).begins_with(prefix):
			return true
	return false


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
