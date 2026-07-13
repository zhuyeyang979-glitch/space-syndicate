extends RefCounted
class_name CardTextMigrationRegistryBuilder

const RegistryScript := preload("res://scripts/presentation/card_text_migration_registry_resource.gd")
const V04_CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v04.tres"
const V05_CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v05.tres"
const DEFAULT_OUTPUT_PATH := "res://resources/migrations/card_text_v04_to_v05_registry.tres"
const DEFAULT_BLOCKING_REASON := "The v0.5 effect, requirement, and terms owners have not completed semantic cutover."


static func build_entries() -> Array[Dictionary]:
	var v04_catalog: Resource = load(V04_CATALOG_PATH)
	var v05_catalog: Resource = load(V05_CATALOG_PATH)
	if v04_catalog == null or v05_catalog == null:
		return []
	var v05_by_source: Dictionary = {}
	for v05_card in v05_catalog.cards:
		if v05_card != null:
			v05_by_source[str(v05_card.source_v04_card_id)] = v05_card
	var authored_by_id: Dictionary = {}
	var family_path_by_id: Dictionary = {}
	for pack in v04_catalog.packs:
		if pack == null:
			continue
		for family in pack.families:
			if family == null:
				continue
			for authored in family.authored_ranks:
				if authored == null:
					continue
				authored_by_id[str(authored.card_id)] = authored
				family_path_by_id[str(authored.card_id)] = str(family.resource_path)
	var entries: Array[Dictionary] = []
	for legacy_id_variant in v04_catalog.authored_card_order:
		var legacy_id := str(legacy_id_variant)
		var authored: Resource = authored_by_id.get(legacy_id)
		if authored == null:
			continue
		var v05_card: Resource = v05_by_source.get(legacy_id)
		var proposed_stable_id := str(v05_card.card_id) if v05_card != null else ""
		var migration_status := str(v05_card.migration_status) if v05_card != null else "blocked"
		var blocking_reason := str(v05_card.blocking_reason) if v05_card != null else DEFAULT_BLOCKING_REASON
		var resource_path := str(family_path_by_id.get(legacy_id, ""))
		entries.append({
			"legacy_card_id": legacy_id,
			"resource_path": resource_path,
			"family": str(authored.family_id),
			"rank": int(authored.rank),
			"rules_text_hash": str(authored.rules_text).sha256_text().to_upper(),
			"proposed_stable_id": proposed_stable_id,
			"migration_status": migration_status,
			"blocking_reason": blocking_reason,
			"effect_owner": "v0.4_runtime:%s" % str(authored.kind),
			"requirement_owner": "res://scripts/runtime/card_play_eligibility_runtime_service.gd",
			"terms_owner": resource_path,
			"parity_evidence": [],
		})
	return entries


static func build_registry() -> Resource:
	var registry: Resource = RegistryScript.new()
	registry.schema_version = "v0.5"
	registry.source_catalog_path = V04_CATALOG_PATH
	registry.expected_entry_count = 239
	registry.entries = build_entries()
	return registry


static func write_registry(output_path: String = DEFAULT_OUTPUT_PATH) -> Dictionary:
	var registry := build_registry()
	var validation: Dictionary = registry.validation_snapshot()
	if not bool(validation.get("valid", false)):
		return {"written": false, "error": "registry_validation_failed", "validation": validation}
	var save_error := ResourceSaver.save(registry, output_path)
	return {
		"written": save_error == OK,
		"error": "" if save_error == OK else error_string(save_error),
		"output_path": output_path,
		"validation": validation,
	}
