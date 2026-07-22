extends SceneTree

const MANIFEST_PATH := "res://resources/content/alpha01/alpha01_content_manifest.tres"

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest: Resource = load(MANIFEST_PATH)
	_expect(manifest != null, "Alpha 0.1 content manifest loads as a real resource")
	if manifest == null:
		_finish()
		return
	var report: Dictionary = manifest.call("validation_report")
	_expect(bool(report.get("valid", false)), "manifest passes deterministic validation: %s" % JSON.stringify(report.get("errors", [])))
	var counts: Dictionary = report.get("counts", {}) if report.get("counts", {}) is Dictionary else {}
	_expect(counts == {"roles": 8, "card_identities": 40, "rank_records": 160, "monsters": 8, "products": 46}, "cut contains 8 roles, 40 player card identities, 160 rank records, 8 monsters, and 46 products")
	var family_ids: PackedStringArray = manifest.get("card_family_ids")
	_expect(family_ids.size() >= 30 and family_ids.size() <= 50, "card-family cut stays within the Alpha 0.1 scope")
	var ranked_ids: PackedStringArray = manifest.call("ranked_card_ids")
	var acquisition_ids: PackedStringArray = manifest.call("acquisition_card_ids")
	_expect(acquisition_ids.size() == 40 and _all_rank_one(acquisition_ids), "draw-facing whitelist exposes exactly 40 rank-I family identities")
	_expect(ranked_ids.size() == 160, "160 records are dependency-checked rank I-IV upgrade gradients, not independent draw identities")
	var selection_sha256: String = manifest.call("deterministic_sha256")
	_expect(not selection_sha256.is_empty() and selection_sha256 == str(manifest.get("expected_selection_sha256")), "selection fingerprint is pinned")
	_expect(selection_sha256 == str(manifest.call("deterministic_sha256")), "selection fingerprint is deterministic across repeated reads")
	var dependency_sha256: Dictionary = report.get("dependency_sha256", {}) if report.get("dependency_sha256", {}) is Dictionary else {}
	_expect(dependency_sha256.size() == 5 and not dependency_sha256.values().has(""), "five authoritative dependencies are readable and hash-locked")
	var card_audit: Dictionary = report.get("card_audit", {}) if report.get("card_audit", {}) is Dictionary else {}
	_expect(int(card_audit.get("player_card_identity_count", 0)) == 40 and int(card_audit.get("rank_record_count", 0)) == 160, "card audit distinguishes 40 identities from 160 rank records")
	_expect(int(card_audit.get("active_owner_ranked_card_count", 0)) == 160, "every ranked card resolves to an active owner and target contract")
	_expect((card_audit.get("retired_hits", []) as Array).is_empty(), "selected card data contains no retired-mechanic identifiers")
	_expect(card_audit.get("category_counts", {}) == {"commodity": 12, "facility": 12, "interaction": 3, "supply_demand": 2, "military": 3, "monster": 8}, "card-family category mix is exact")
	var role_audit: Dictionary = report.get("role_audit", {}) if report.get("role_audit", {}) is Dictionary else {}
	_expect(bool(role_audit.get("public_fields_only", false)) and str(role_audit.get("manifest_payload", "")) == "names_only" and (role_audit.get("retired_hits", []) as Array).is_empty(), "role selection uses public identity, stores names only, and contains no retired identifier")
	_expect(role_audit.get("selected_indices", []) == [0, 1, 2, 3, 9, 16, 21, 22], "selected roles preserve authoritative source indices including Ghost Broadcast at index 9")
	_expect(bool(role_audit.get("all_passive_fields_have_non_main_gameplay_consumers", false)) and (role_audit.get("unsupported_passive_fields", []) as Array).is_empty(), "every selected role passive field has an audited non-Main gameplay consumer")
	_expect(int(role_audit.get("passive_field_occurrence_count", 0)) == 18 and (role_audit.get("unique_passive_fields", []) as Array).size() == 11, "role consumer audit covers all 18 selected passive-field occurrences across 11 mechanics")
	var hidden_audit: Dictionary = report.get("hidden_information_audit", {}) if report.get("hidden_information_audit", {}) is Dictionary else {}
	_expect(bool(hidden_audit.get("pure_data", false)) and (hidden_audit.get("forbidden_key_paths", []) as Array).is_empty(), "public whitelist carries no private runtime state or developer payload")
	var product_audit: Dictionary = report.get("product_audit", {}) if report.get("product_audit", {}) is Dictionary else {}
	_expect(bool(product_audit.get("selected_all_source_products", false)) and int(product_audit.get("source_count", 0)) == 46 and (product_audit.get("retired_hits", []) as Array).is_empty(), "all 46 authoritative products remain available without retired identifiers")
	var monster_audit: Dictionary = report.get("monster_audit", {}) if report.get("monster_audit", {}) is Dictionary else {}
	_expect(bool(monster_audit.get("selected_all_source_monsters", false)) and int(monster_audit.get("source_count", 0)) == 8 and (monster_audit.get("retired_hits", []) as Array).is_empty(), "all 8 authoritative monsters remain available without retired identifiers")
	var consumer_audit: Dictionary = report.get("runtime_consumer_audit", {}) if report.get("runtime_consumer_audit", {}) is Dictionary else {}
	_expect(bool(consumer_audit.get("rank_one_draw_contract", false)) and bool(consumer_audit.get("rank_records_are_not_draw_ids", false)), "current draw consumers accept rank-I identities rather than 160 rank records")
	_expect((consumer_audit.get("missing_paths", []) as Array).is_empty(), "cards, roles, monsters, and products each have real runtime consumer evidence")
	_expect(not bool(consumer_audit.get("whitelist_runtime_consumer_attached", true)) and bool(consumer_audit.get("integration_request_required", false)), "hot-file whitelist activation remains an explicit integration handoff")
	_finish()


func _all_rank_one(card_ids: PackedStringArray) -> bool:
	for card_id in card_ids:
		if not card_id.ends_with(".rank_1"):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ALPHA01_CONTENT_MANIFEST_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("ALPHA01_CONTENT_MANIFEST_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
