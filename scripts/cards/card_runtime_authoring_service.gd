@tool
extends RefCounted
class_name CardRuntimeAuthoringService

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v04.tres"
const INTEGRITY_PATH := "res://tests/fixtures/runtime_card_catalog_v04_integrity.json"
const OUTPUT_DIR := "user://space_syndicate_design_qa/runtime_card_authoring/"
const BASELINE_PATH := OUTPUT_DIR + "working_baseline.json"
const REVIEW_JSON_PATH := OUTPUT_DIR + "change_review.json"
const REVIEW_MARKDOWN_PATH := OUTPUT_DIR + "change_review.md"

var _catalog: CardRuntimeCatalogResource
var _validator := CardRuntimeAuthoringValidator.new()
var _reviewer := CardRuntimeChangeReviewService.new()


func configure(catalog_path: String = CATALOG_PATH) -> Dictionary:
	_catalog = load(catalog_path) as CardRuntimeCatalogResource
	return {
		"configured": _catalog != null,
		"catalog_path": catalog_path,
		"error": "" if _catalog != null else "catalog_resource_missing",
	}


func output_dir() -> String:
	return OUTPUT_DIR


func baseline_path() -> String:
	return BASELINE_PATH


func review_paths() -> Dictionary:
	return {"json": REVIEW_JSON_PATH, "markdown": REVIEW_MARKDOWN_PATH}


func authoring_index() -> Dictionary:
	if not _ensure_catalog():
		return {"valid": false, "packs": [], "families": [], "cards": []}
	var packs: Array = []
	var families: Array = []
	var cards: Array = []
	for pack_resource in _catalog.packs:
		var pack := pack_resource as CardRuntimePackResource
		if pack == null:
			continue
		var family_ids: Array = []
		for family_resource in pack.families:
			var family := family_resource as CardRuntimeFamilyResource
			if family == null:
				continue
			family_ids.append(family.family_id)
			var card_ids := family.authored_card_ids()
			families.append({
				"family_id": family.family_id,
				"pack_id": str(pack.pack_id),
				"resource_path": family.resource_path,
				"card_ids": card_ids,
				"rank_count": card_ids.size(),
				"derivation_enabled": family.derivation_enabled,
				"public_pool_eligible": family.public_pool_eligible,
				"upgradeable_family": family.upgradeable_family,
			})
			for card_id_variant in card_ids:
				var card_id := str(card_id_variant)
				var definition := _catalog.authored_definition(card_id)
				cards.append({
					"card_id": card_id,
					"family_id": family.family_id,
					"pack_id": str(pack.pack_id),
					"resource_path": family.resource_path,
					"rank": _catalog.rank(card_id),
					"kind": str(definition.get("kind", "")),
					"purchase_cost": int(definition.get("cost", 0)),
					"rules_text": str(definition.get("text", "")),
					"definition_hash": _reviewer.definition_hash(definition),
				})
		packs.append({
			"pack_id": str(pack.pack_id),
			"display_name": pack.display_name,
			"resource_path": pack.resource_path,
			"family_ids": family_ids,
			"family_count": family_ids.size(),
		})
	return {
		"valid": true,
		"catalog_path": CATALOG_PATH,
		"pack_count": packs.size(),
		"family_count": families.size(),
		"card_count": cards.size(),
		"packs": packs,
		"families": families,
		"cards": cards,
	}


func validate_catalog() -> Dictionary:
	if not _ensure_catalog():
		return {"valid": false, "error_count": 1, "errors": [{"check_id": "catalog_resource_missing"}]}
	return _validator.validate_catalog(_catalog)


func validate_target(target: Resource) -> Dictionary:
	if not _ensure_catalog():
		return {"valid": false, "error_count": 1, "errors": [{"check_id": "catalog_resource_missing"}]}
	return _validator.validate_target(target, _catalog)


func validate_family_id(family_id: String) -> Dictionary:
	if not _ensure_catalog():
		return {"valid": false, "error_count": 1, "errors": [{"check_id": "catalog_resource_missing"}]}
	var family := _family_for_id(family_id)
	return _validator.validate_family(family, _catalog)


func validate_card_id(card_id: String) -> Dictionary:
	if not _ensure_catalog():
		return {"valid": false, "error_count": 1, "errors": [{"check_id": "catalog_resource_missing"}]}
	var rank_resource := _rank_for_id(card_id)
	return _validator.validate_rank(rank_resource, _family_for_id(_catalog.family_id(card_id)), _catalog)


func capture_baseline() -> Dictionary:
	if not _ensure_catalog():
		return {"captured": false, "error": "catalog_resource_missing"}
	var snapshot := _reviewer.catalog_snapshot(_catalog)
	var write_result := _write_json(BASELINE_PATH, snapshot)
	return {
		"captured": bool(write_result.get("written", false)),
		"path": BASELINE_PATH,
		"card_count": int((snapshot.get("cards", {}) as Dictionary).size()),
		"catalog_order_sha256": str(snapshot.get("catalog_order_sha256", "")),
		"error": str(write_result.get("error", "")),
	}


func build_change_review(write_files := true) -> Dictionary:
	if not _ensure_catalog():
		return {"schema": CardRuntimeChangeReviewService.REVIEW_SCHEMA, "review_status": "blocked", "error": "catalog_resource_missing"}
	var current := _reviewer.catalog_snapshot(_catalog)
	var baseline := _read_json(BASELINE_PATH)
	var integrity := _read_json(INTEGRITY_PATH)
	var review := _reviewer.compare_snapshots(current, baseline, integrity)
	review["validation"] = _validator.validate_catalog(_catalog)
	review["review_ready"] = bool((review.get("validation", {}) as Dictionary).get("valid", false)) and str(review.get("review_status", "")) != "blocked"
	review["catalog_path"] = CATALOG_PATH
	review["output_dir"] = OUTPUT_DIR
	review["generated_unix_time"] = int(Time.get_unix_time_from_system())
	if write_files:
		var json_result := _write_json(REVIEW_JSON_PATH, review)
		var markdown_result := _write_text(REVIEW_MARKDOWN_PATH, _review_markdown(review))
		review["review_json_path"] = REVIEW_JSON_PATH if bool(json_result.get("written", false)) else ""
		review["review_markdown_path"] = REVIEW_MARKDOWN_PATH if bool(markdown_result.get("written", false)) else ""
	return review


func debug_snapshot() -> Dictionary:
	var index := authoring_index()
	return {
		"service_ready": bool(index.get("valid", false)),
		"catalog_path": CATALOG_PATH,
		"pack_count": int(index.get("pack_count", 0)),
		"family_count": int(index.get("family_count", 0)),
		"card_count": int(index.get("card_count", 0)),
		"output_dir": OUTPUT_DIR,
		"baseline_path": BASELINE_PATH,
		"review_paths": review_paths(),
		"runtime_owner_unchanged": "CardRuntimeCatalogService",
		"editor_only": true,
	}


func _ensure_catalog() -> bool:
	if _catalog != null:
		return true
	configure()
	return _catalog != null


func _family_for_id(family_id: String) -> CardRuntimeFamilyResource:
	if _catalog == null:
		return null
	for pack_resource in _catalog.packs:
		var pack := pack_resource as CardRuntimePackResource
		if pack == null:
			continue
		for family_resource in pack.families:
			var family := family_resource as CardRuntimeFamilyResource
			if family != null and family.family_id == family_id:
				return family
	return null


func _rank_for_id(card_id: String) -> CardRuntimeRankResource:
	var family := _family_for_id(_catalog.family_id(card_id))
	return family.exact_rank_resource(_catalog.rank(card_id)) if family != null else null


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _write_json(path: String, payload: Dictionary) -> Dictionary:
	return _write_text(path, JSON.stringify(payload, "  ", false))


func _write_text(path: String, content: String) -> Dictionary:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if error != OK:
		return {"written": false, "error": error_string(error)}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"written": false, "error": "file_open_failed"}
	file.store_string(content)
	file.close()
	return {"written": true, "path": path, "error": ""}


func _review_markdown(review: Dictionary) -> String:
	var lines: Array[String] = [
		"# Runtime Card Authoring Change Review",
		"",
		"- Status: `%s`" % str(review.get("review_status", "unknown")),
		"- Validation: `%s`" % ("passed" if bool((review.get("validation", {}) as Dictionary).get("valid", false)) else "failed"),
		"- Baseline available: `%s`" % str(review.get("baseline_available", false)),
		"- Changed: `%d`" % int(review.get("changed_count", 0)),
		"- Added: `%d`" % int(review.get("added_count", 0)),
		"- Removed: `%d`" % int(review.get("removed_count", 0)),
		"",
		"## Card changes",
	]
	var wrote_change := false
	for key in ["changed_cards", "added_cards", "removed_cards"]:
		var values: Array = review.get(key, []) if review.get(key, []) is Array else []
		for value_variant in values:
			var value: Dictionary = value_variant if value_variant is Dictionary else {}
			lines.append("- `%s` %s, family `%s`, fields `%d`" % [str(value.get("card_id", "")), str(value.get("status", "")), str(value.get("family_id", "")), (value.get("field_changes", []) as Array).size()])
			wrote_change = true
	if not wrote_change:
		lines.append("- No changes from the approved integrity fixture.")
	lines.append_array(["", "## Order review"])
	var order_changes: Dictionary = review.get("order_changes", {}) if review.get("order_changes", {}) is Dictionary else {}
	for key in order_changes:
		lines.append("- `%s`: `%s`" % [str(key), str(order_changes[key])])
	lines.append_array(["", "## Required consumer review"])
	for consumer in review.get("consumer_review_checks", []):
		lines.append("- %s" % str(consumer))
	lines.append_array(["", "Generated under `user://`; this report is not a runtime data source."])
	return "\n".join(lines) + "\n"
