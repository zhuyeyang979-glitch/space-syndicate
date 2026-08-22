extends SceneTree

const Crosswalk := preload(
	"res://scripts/v076/military/v076_military_card_crosswalk_v1.gd"
)
const CatalogResource := preload(
	"res://scripts/cards/card_runtime_catalog_v06_resource.gd"
)
const ACTIVE_CATALOG_PATH := "res://data/v075/v075_combat_active_catalog.json"
const BALANCE_DEFAULTS_PATH := "res://docs/rules/v075_combat_balance_defaults.json"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var adapter := Crosswalk.new()
	var catalog := CatalogResource.new()
	var catalog_report := catalog.reload()
	_expect(bool(catalog_report.get("valid", false)), "source catalog Owner validates")
	var catalog_snapshot := catalog.catalog_snapshot()
	var active_catalog := _read_json(ACTIVE_CATALOG_PATH)
	var balance_defaults := _read_json(BALANCE_DEFAULTS_PATH)
	var document := adapter.load_document()
	var report := adapter.validate_document(
		document, catalog_snapshot, active_catalog, balance_defaults
	)
	if not bool(report.get("valid", false)):
		print("V076_MILITARY_CARD_CROSSWALK_DIAGNOSTIC|%s" % JSON.stringify(report))

	_expect(bool(report.get("valid", false)), "canonical Crosswalk validates")
	_expect(str(report.get("status", "")) == "PARTIAL", "honest result is PARTIAL")
	_expect(int(report.get("source_military_card_count", 0)) == 28, "source military catalog closes at 28")
	_expect(int(report.get("source_military_family_count", 0)) == 7, "source military families close at seven")
	_expect(str(report.get("source_family_rank_coverage", "")) == "7/7", "all families cover ranks I-IV")
	_expect(str(report.get("source_card_fingerprint_coverage", "")) == "28/28", "all source machine fingerprints match")
	_expect(int(report.get("mapping_record_count", 0)) == 28, "Crosswalk contains exactly 28 records")
	_expect(int(report.get("unmapped_card_count", -1)) == 0, "no source card is unmapped")
	_expect(int(report.get("duplicate_mapping_count", -1)) == 0, "no source card is mapped twice")
	_expect(int(report.get("unknown_source_card_count", -1)) == 0, "no mapping points to an unknown source")
	_expect(int(report.get("missing_family_rank_record_count", -1)) == 0, "no family/rank record is missing")
	_expect(str(report.get("unit_profile_id_coverage", "")) == "28/28", "every record names its exact or required unit profile")
	_expect(int(report.get("positive_asset_cost_binding_count", 0)) == 28, "all records bind a positive catalog-owned cost")
	_expect(int(report.get("exact_combat_profile_binding_count", 0)) == 12, "twelve active cards bind frozen V075 combat profiles")
	_expect(int(report.get("exact_mapped_count", 0)) == 12, "three active families produce twelve exact mappings")
	_expect(int(report.get("reauthor_required_count", 0)) == 16, "four deferred families produce sixteen authoring gaps")
	_expect(int(report.get("retired_from_alpha07_count", -1)) == 0, "no source identity is silently retired")
	_expect(int(report.get("unresolved_source_conflict_count", -1)) == 0, "no source conflict remains")
	_expect(int(report.get("forbidden_mission_token_count", -1)) == 0, "no forbidden mission enters an active mapping")
	_expect(int(report.get("name_based_mission_inference_count", -1)) == 0, "mission mapping never reads card names")
	_expect(int(report.get("text_parse_runtime_rule_count", -1)) == 0, "mission mapping never parses player text")
	_expect(int(report.get("mission_fallback_count", -1)) == 0, "mission mapping has no fallback")
	_expect(int(report.get("public_batch_entry_count", -1)) == 0, "military Direct Actions never enter public batch")
	_expect(int(report.get("shared_sushi_track_resolution_count", -1)) == 0, "military Direct Actions never use the shared sushi track")
	_expect(int(report.get("public_card_text_disclosure_count", -1)) == 0, "private input never discloses card text")
	_expect(int(report.get("exact_once_binding_count", 0)) == 28, "all identities preserve exact-once instance binding")
	_expect(int(report.get("stale_hand_membership_revalidation_count", 0)) == 28, "all records require stale hand revalidation")
	_expect(int(report.get("source_collision_rejection_count", 0)) == 28, "all records require source-collision rejection")
	_expect(int(report.get("production_green_count", -1)) == 0, "Crosswalk cannot claim production green")
	_expect(int(report.get("human_green_count", -1)) == 0, "Crosswalk cannot claim human green")
	_expect(not str(report.get("crosswalk_fingerprint_sha256", "")).is_empty(), "Crosswalk fingerprint is deterministic and nonempty")

	var roundtrip_variant: Variant = JSON.parse_string(JSON.stringify(document))
	_expect(roundtrip_variant is Dictionary and roundtrip_variant == document, "Mapping JSON roundtrips exactly")
	var reversed := document.duplicate(true)
	(reversed.get("records", []) as Array).reverse()
	_expect(adapter.canonical_fingerprint(reversed) == adapter.canonical_fingerprint(document), "record order does not change canonical hash")

	var drift := document.duplicate(true)
	((drift.get("records", []) as Array)[0] as Dictionary)["source_machine_fingerprint_sha256"] = "0".repeat(64)
	_expect(_has_error(adapter.validate_document(drift, catalog_snapshot, active_catalog, balance_defaults), "source_fingerprint_mismatch"), "source drift fails closed")

	var duplicate := document.duplicate(true)
	(duplicate.get("records", []) as Array).append(((duplicate.get("records", []) as Array)[0] as Dictionary).duplicate(true))
	_expect(_has_error(adapter.validate_document(duplicate, catalog_snapshot, active_catalog, balance_defaults), "duplicate_mapping"), "duplicate mapping fails closed")

	var missing := document.duplicate(true)
	(missing.get("records", []) as Array).remove_at(0)
	_expect(_has_error(adapter.validate_document(missing, catalog_snapshot, active_catalog, balance_defaults), "source_card_unmapped"), "missing mapping fails closed")

	var unknown := document.duplicate(true)
	((unknown.get("records", []) as Array)[0] as Dictionary)["source_card_id"] = "unit.military.unknown.rank_1"
	_expect(_has_error(adapter.validate_document(unknown, catalog_snapshot, active_catalog, balance_defaults), "unknown_source_card"), "unknown source card fails closed")

	var non_military := document.duplicate(true)
	((non_military.get("records", []) as Array)[0] as Dictionary)["source_card_id"] = "facility.factory.rank_1"
	_expect(not bool(adapter.validate_document(non_military, catalog_snapshot, active_catalog, balance_defaults).get("valid", true)), "non-military card fails closed")

	var guard := document.duplicate(true)
	((guard.get("records", []) as Array)[0] as Dictionary)["allowed_missions"] = ["GUARD"]
	_expect(_has_error(adapter.validate_document(guard, catalog_snapshot, active_catalog, balance_defaults), "forbidden_mission_present"), "Guard mission is rejected")

	var protect := document.duplicate(true)
	((protect.get("records", []) as Array)[0] as Dictionary)["allowed_missions"] = ["PROTECT"]
	_expect(_has_error(adapter.validate_document(protect, catalog_snapshot, active_catalog, balance_defaults), "forbidden_mission_present"), "Protect mission is rejected")

	var inferred := document.duplicate(true)
	((inferred.get("records", []) as Array)[0] as Dictionary)["name_based_mission_inference"] = true
	_expect(_has_error(adapter.validate_document(inferred, catalog_snapshot, active_catalog, balance_defaults), "name_based_mission_inference"), "name inference is rejected")

	var parsed_text := document.duplicate(true)
	((parsed_text.get("records", []) as Array)[0] as Dictionary)["text_parse_runtime_rule"] = true
	_expect(_has_error(adapter.validate_document(parsed_text, catalog_snapshot, active_catalog, balance_defaults), "text_parse_runtime_rule"), "runtime text parsing is rejected")

	var fallback := document.duplicate(true)
	((fallback.get("records", []) as Array)[0] as Dictionary)["mission_fallback"] = "ASSAULT_REGION"
	_expect(_has_error(adapter.validate_document(fallback, catalog_snapshot, active_catalog, balance_defaults), "mission_fallback_present"), "mission fallback is rejected")

	var stale := document.duplicate(true)
	((stale.get("records", []) as Array)[0] as Dictionary)["stale_hand_membership_revalidation"] = false
	_expect(_has_error(adapter.validate_document(stale, catalog_snapshot, active_catalog, balance_defaults), "stale_revalidation_missing"), "stale membership bypass is rejected")

	var collision := document.duplicate(true)
	((collision.get("records", []) as Array)[0] as Dictionary)["source_collision_rejection"] = false
	_expect(_has_error(adapter.validate_document(collision, catalog_snapshot, active_catalog, balance_defaults), "collision_rejection_missing"), "source-collision bypass is rejected")

	var production_green := document.duplicate(true)
	production_green["production_green"] = true
	_expect(_has_error(adapter.validate_document(production_green, catalog_snapshot, active_catalog, balance_defaults), "production_false_green"), "production false-green is rejected")

	var human_green := document.duplicate(true)
	human_green["human_green"] = true
	_expect(_has_error(adapter.validate_document(human_green, catalog_snapshot, active_catalog, balance_defaults), "human_false_green"), "human false-green is rejected")

	print("V076_MILITARY_CARD_CROSSWALK_TEST|status=%s|checks=%d|failures=%d|exact=12|reauthor=16" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)


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
