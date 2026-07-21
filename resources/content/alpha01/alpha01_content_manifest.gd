@tool
extends Resource
class_name Alpha01ContentManifestResource

const MONSTER_CATALOG := preload("res://scripts/runtime/monster_catalog_v06.gd")
const PRODUCT_INDUSTRY_DEFINITION_RESOURCE := preload("res://scripts/content/product_industry_definition_resource.gd")
const PRODUCT_INDUSTRY_ENTRY_RESOURCE := preload("res://scripts/content/product_industry_entry_resource.gd")
const PRODUCT_INDUSTRY_CATALOG_RESOURCE := preload("res://scripts/content/product_industry_catalog_resource.gd")
const CARD_RUNTIME_CATALOG_RESOURCE := preload("res://scripts/cards/card_runtime_catalog_v06_resource.gd")
const MECHANIC_REGISTRY_PATH := "res://docs/rules/v06_mechanic_status_registry.json"
const SOURCE_PATHS := {
	"cards": "res://data/cards/card_runtime_catalog_v06.json",
	"roles": "res://scripts/runtime/role_catalog_runtime_service.gd",
	"monsters": "res://scripts/runtime/monster_catalog_v06.gd",
	"products": "res://resources/content/product_industry_catalog_v05.tres",
	"mechanic_registry": MECHANIC_REGISTRY_PATH,
}
const RUNTIME_CONSUMER_EVIDENCE := {
	"cards": [
		"res://scripts/runtime/game_runtime_coordinator.gd",
		"res://scripts/runtime/region_supply_runtime_controller.gd",
		"res://scripts/runtime/commodity_card_inventory_runtime_controller.gd",
	],
	"roles": [
		"res://scripts/runtime/new_game_setup_draft_service.gd",
		"res://scripts/runtime/session_start_plan_builder.gd",
		"res://scripts/runtime/role_codex_public_source_service.gd",
	],
	"monsters": [
		"res://scripts/runtime/new_game_setup_draft_service.gd",
		"res://scripts/runtime/session_start_plan_builder.gd",
		"res://scripts/runtime/monster_runtime_controller.gd",
		"res://scripts/runtime/monster_codex_public_source_service.gd",
	],
	"products": [
		"res://scripts/runtime/commodity_flow_runtime_controller.gd",
		"res://scripts/runtime/product_market_runtime_controller.gd",
		"res://scenes/runtime/GdpFormulaRuntimeController.tscn",
	],
}
const EXPECTED_SELECTION_COUNTS := {
	"roles": 8,
	"card_identities": 40,
	"rank_records": 160,
	"monsters": 8,
	"products": 46,
}
const EXPECTED_CARD_FAMILY_CATEGORY_COUNTS := {
	"commodity": 12,
	"facility": 12,
	"interaction": 3,
	"supply_demand": 2,
	"military": 3,
	"monster": 8,
}
const PUBLIC_SELECTION_KEYS := [
	"schema_version",
	"manifest_id",
	"role_names",
	"card_family_ids",
	"acquisition_card_ids",
	"ranked_card_ids",
	"monster_names",
	"product_ids",
	"counts",
	"card_family_category_counts",
]
const PRIVATE_KEY_FRAGMENTS := [
	"cash",
	"hand",
	"owner",
	"private",
	"developer",
	"ai_",
	"route_plan",
	"pressure_bucket",
	"reasoning",
]
const OWNER_BINDINGS := {
	"install_commodity_rate": {
		"catalog_owner": "commodity_flow_runtime_controller",
		"owner_path": "res://scripts/runtime/commodity_flow_runtime_controller.gd",
		"target_kinds": ["same_industry_factory_or_market"],
		"mechanic_id": "",
	},
	"build_upgrade_or_repair_facility": {
		"catalog_owner": "region_infrastructure_runtime_controller",
		"owner_path": "res://scripts/runtime/region_infrastructure_runtime_controller.gd",
		"target_kinds": ["region_unique_facility_slot"],
		"mechanic_id": "",
	},
	"global_order_budget": {
		"catalog_owner": "global_supply_demand_runtime_service",
		"owner_path": "res://scripts/cards/v06/effects/global_supply_demand_runtime_service_v06.gd",
		"target_kinds": ["global_matching_goods"],
		"mechanic_id": "conditional_order_auto_settlement",
	},
	"global_supply_spawn": {
		"catalog_owner": "global_supply_demand_runtime_service",
		"owner_path": "res://scripts/cards/v06/effects/global_supply_demand_runtime_service_v06.gd",
		"target_kinds": ["global_matching_factories"],
		"mechanic_id": "conditional_order_auto_settlement",
	},
	"deploy_or_upgrade_monster": {
		"catalog_owner": "monster_runtime_controller",
		"owner_path": "res://scripts/runtime/monster_runtime_controller.gd",
		"target_kinds": ["region_or_existing_same_family_monster"],
		"mechanic_id": "",
	},
	"deploy_or_upgrade_military": {
		"catalog_owner": "military_runtime_controller",
		"owner_path": "res://scripts/runtime/military_runtime_controller.gd",
		"target_kinds": ["region_or_owned_same_family_military"],
		"mechanic_id": "",
	},
	"player_hand_disrupt": {
		"catalog_owner": "player_hand_interaction_runtime_service",
		"owner_path": "res://scripts/runtime/player_hand_interaction_runtime_service.gd",
		"target_kinds": ["opponent_discardable_hand"],
		"mechanic_id": "card_target_choice",
	},
	"player_hand_steal": {
		"catalog_owner": "player_hand_interaction_runtime_service",
		"owner_path": "res://scripts/runtime/player_hand_interaction_runtime_service.gd",
		"target_kinds": ["opponent_discardable_hand"],
		"mechanic_id": "card_target_choice",
	},
	"card_counter": {
		"catalog_owner": "card_counter_runtime_service",
		"owner_path": "res://scripts/runtime/card_counter_settlement_runtime_service.gd",
		"target_kinds": ["incoming_direct_player_interaction"],
		"mechanic_id": "card_counter_response",
	},
}

@export var schema_version := "alpha01.content_manifest.v1"
@export var manifest_id := "alpha01_playable_cut"
@export var card_catalog: Resource
@export var role_catalog_scene: PackedScene
@export var product_catalog: Resource
@export var role_names: PackedStringArray = []
@export var card_family_ids: PackedStringArray = []
@export var monster_names: PackedStringArray = []
@export var product_ids: PackedStringArray = []
@export_group("Dependency Lock")
@export var expected_card_source_sha256 := ""
@export var expected_role_source_sha256 := ""
@export var expected_monster_source_sha256 := ""
@export var expected_product_source_sha256 := ""
@export var expected_mechanic_registry_sha256 := ""
@export var expected_selection_sha256 := ""


func ranked_card_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for family_id in card_family_ids:
		for rank in range(1, 5):
			result.append("%s.rank_%d" % [family_id, rank])
	return result


func acquisition_card_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for family_id in card_family_ids:
		result.append("%s.rank_1" % family_id)
	return result


func selection_snapshot() -> Dictionary:
	return {
		"schema_version": schema_version,
		"manifest_id": manifest_id,
		"role_names": _packed_to_array(role_names),
		"card_family_ids": _packed_to_array(card_family_ids),
		"acquisition_card_ids": _packed_to_array(acquisition_card_ids()),
		"ranked_card_ids": _packed_to_array(ranked_card_ids()),
		"monster_names": _packed_to_array(monster_names),
		"product_ids": _packed_to_array(product_ids),
		"counts": EXPECTED_SELECTION_COUNTS.duplicate(true),
		"card_family_category_counts": EXPECTED_CARD_FAMILY_CATEGORY_COUNTS.duplicate(true),
	}


func deterministic_sha256() -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(_canonical_json(selection_snapshot()).to_utf8_buffer())
	return context.finish().hex_encode()


func validation_report() -> Dictionary:
	var errors: Array[String] = []
	_validate_selection_shape(errors)
	var dependency_hashes := _validate_dependency_hashes(errors)
	var registry := _mechanic_registry_snapshot(errors)
	var card_audit := _validate_cards(registry, errors)
	var role_audit := _validate_roles(registry, errors)
	var monster_audit := _validate_monsters(registry, errors)
	var product_audit := _validate_products(registry, errors)
	var hidden_information_audit := _validate_hidden_information(errors)
	var runtime_consumer_audit := _validate_runtime_consumers(errors)
	var actual_selection_sha256 := deterministic_sha256()
	if expected_selection_sha256.is_empty():
		errors.append("selection_sha256_missing:%s" % actual_selection_sha256)
	elif actual_selection_sha256 != expected_selection_sha256:
		errors.append("selection_sha256_mismatch:%s:%s" % [expected_selection_sha256, actual_selection_sha256])
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"manifest_id": manifest_id,
		"counts": {
			"roles": role_names.size(),
			"card_identities": acquisition_card_ids().size(),
			"rank_records": ranked_card_ids().size(),
			"monsters": monster_names.size(),
			"products": product_ids.size(),
		},
		"selection_sha256": actual_selection_sha256,
		"dependency_sha256": dependency_hashes,
		"card_audit": card_audit,
		"role_audit": role_audit,
		"monster_audit": monster_audit,
		"product_audit": product_audit,
		"hidden_information_audit": hidden_information_audit,
		"runtime_consumer_audit": runtime_consumer_audit,
		"retired_identifier_count": (registry.get("retired_identifiers", []) as Array).size(),
	}


func _validate_selection_shape(errors: Array[String]) -> void:
	var actual_counts := {
		"roles": role_names.size(),
		"card_identities": acquisition_card_ids().size(),
		"rank_records": ranked_card_ids().size(),
		"monsters": monster_names.size(),
		"products": product_ids.size(),
	}
	for key_variant in EXPECTED_SELECTION_COUNTS.keys():
		var key := str(key_variant)
		if int(actual_counts.get(key, -1)) != int(EXPECTED_SELECTION_COUNTS[key]):
			errors.append("selection_count:%s:%d" % [key, int(actual_counts.get(key, -1))])
	_validate_unique("role", role_names, errors)
	_validate_unique("card_family", card_family_ids, errors)
	_validate_unique("acquisition_card", acquisition_card_ids(), errors)
	_validate_unique("monster", monster_names, errors)
	_validate_unique("product", product_ids, errors)
	var original_card_families := _packed_to_array(card_family_ids)
	var sorted_card_families := original_card_families.duplicate()
	sorted_card_families.sort()
	if original_card_families != sorted_card_families:
		errors.append("card_family_ids_not_lexically_sorted")
	if not _all_rank_one(acquisition_card_ids()):
		errors.append("acquisition_card_ids_must_be_rank_one")


func _validate_unique(label: String, values: PackedStringArray, errors: Array[String]) -> void:
	var seen: Dictionary = {}
	for value in values:
		if value.strip_edges().is_empty():
			errors.append("%s_id_empty" % label)
		elif seen.has(value):
			errors.append("duplicate_%s:%s" % [label, value])
		seen[value] = true


func _validate_dependency_hashes(errors: Array[String]) -> Dictionary:
	var actual: Dictionary = {}
	for source_key_variant in SOURCE_PATHS.keys():
		var source_key := str(source_key_variant)
		var path := str(SOURCE_PATHS[source_key])
		var source_hash := _file_sha256(path)
		actual[source_key] = source_hash
		if source_hash.is_empty():
			errors.append("dependency_unreadable:%s:%s" % [source_key, path])
			continue
		var expected_hash := _expected_dependency_hash(source_key)
		if expected_hash.is_empty():
			errors.append("dependency_sha256_missing:%s:%s" % [source_key, source_hash])
		elif source_hash != expected_hash:
			errors.append("dependency_sha256_mismatch:%s:%s:%s" % [source_key, expected_hash, source_hash])
	return actual


func _expected_dependency_hash(source_key: String) -> String:
	match source_key:
		"cards":
			return expected_card_source_sha256
		"roles":
			return expected_role_source_sha256
		"monsters":
			return expected_monster_source_sha256
		"products":
			return expected_product_source_sha256
		"mechanic_registry":
			return expected_mechanic_registry_sha256
	return ""


func _mechanic_registry_snapshot(errors: Array[String]) -> Dictionary:
	var parsed := _load_json(MECHANIC_REGISTRY_PATH)
	if parsed.is_empty():
		errors.append("mechanic_registry_invalid")
		return {"statuses": {}, "retired_identifiers": []}
	var statuses: Dictionary = {}
	var retired_identifiers: Array[String] = []
	var mechanics: Array = parsed.get("mechanics", []) if parsed.get("mechanics", []) is Array else []
	for entry_variant in mechanics:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var mechanic_id := str(entry.get("mechanic_id", ""))
		var status := str(entry.get("status", ""))
		statuses[mechanic_id] = status
		if status != "RETIRED":
			continue
		var identifiers: Array = entry.get("retired_identifiers", []) if entry.get("retired_identifiers", []) is Array else []
		for identifier_variant in identifiers:
			var identifier := str(identifier_variant)
			if not identifier.is_empty() and not retired_identifiers.has(identifier):
				retired_identifiers.append(identifier)
	retired_identifiers.sort()
	return {"statuses": statuses, "retired_identifiers": retired_identifiers}


func _validate_cards(registry: Dictionary, errors: Array[String]) -> Dictionary:
	var category_counts: Dictionary = {}
	var review_status_counts: Dictionary = {}
	var active_owner_ranked_cards := 0
	var retired_hits: Array[String] = []
	var validated_effect_kinds: Dictionary = {}
	if card_catalog == null:
		errors.append("card_catalog_resource_missing")
		return {
			"ranked_card_count": 0,
			"active_owner_ranked_card_count": 0,
			"category_counts": category_counts,
			"review_status_counts": review_status_counts,
			"retired_hits": retired_hits,
		}
	var source_report: Dictionary = card_catalog.call("reload")
	if not bool(source_report.get("valid", false)):
		errors.append("card_catalog_source_invalid:%s" % JSON.stringify(source_report.get("errors", [])))
	var retired_identifiers: Array = registry.get("retired_identifiers", []) if registry.get("retired_identifiers", []) is Array else []
	var statuses: Dictionary = registry.get("statuses", {}) if registry.get("statuses", {}) is Dictionary else {}
	for family_id in card_family_ids:
		var family_category := ""
		for rank in range(1, 5):
			var card_id := "%s.rank_%d" % [family_id, rank]
			var card: Dictionary = card_catalog.call("card_snapshot", card_id)
			if card.is_empty():
				errors.append("selected_card_missing:%s" % card_id)
				continue
			var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
			var developer: Dictionary = card.get("developer", {}) if card.get("developer", {}) is Dictionary else {}
			if str(machine.get("card_id", "")) != card_id or str(machine.get("family_id", "")) != family_id or int(machine.get("rank", 0)) != rank:
				errors.append("selected_card_identity_mismatch:%s" % card_id)
			if not bool(machine.get("available_for_acquisition", false)):
				errors.append("selected_card_unavailable:%s" % card_id)
			var category_id := str(machine.get("category_id", ""))
			if family_category.is_empty():
				family_category = category_id
			elif family_category != category_id:
				errors.append("selected_family_category_drift:%s" % family_id)
			var effect_kind := str(machine.get("effect_kind", ""))
			var target_kind := str(machine.get("target_kind", ""))
			var runtime_owner := str(developer.get("runtime_owner", ""))
			if not OWNER_BINDINGS.has(effect_kind):
				errors.append("selected_effect_owner_binding_missing:%s:%s" % [card_id, effect_kind])
			else:
				var binding: Dictionary = OWNER_BINDINGS[effect_kind]
				if runtime_owner.is_empty() or runtime_owner.ends_with("_pending"):
					errors.append("selected_card_owner_inactive:%s:%s" % [card_id, runtime_owner])
				elif runtime_owner != str(binding.get("catalog_owner", "")):
					errors.append("selected_card_owner_mismatch:%s:%s" % [card_id, runtime_owner])
				elif target_kind.is_empty() or not (binding.get("target_kinds", []) as Array).has(target_kind):
					errors.append("selected_card_target_mismatch:%s:%s" % [card_id, target_kind])
				else:
					active_owner_ranked_cards += 1
				if not validated_effect_kinds.has(effect_kind):
					_validate_owner_binding(effect_kind, binding, statuses, errors)
					validated_effect_kinds[effect_kind] = true
			var review_status := str(developer.get("effect_review_status", "missing"))
			review_status_counts[review_status] = int(review_status_counts.get(review_status, 0)) + 1
			var card_text := JSON.stringify(card).to_lower()
			for identifier_variant in retired_identifiers:
				var identifier := str(identifier_variant)
				if not identifier.is_empty() and card_text.contains(identifier.to_lower()):
					var hit := "%s:%s" % [card_id, identifier]
					retired_hits.append(hit)
					errors.append("retired_mechanic_identifier:%s" % hit)
		if not family_category.is_empty():
			category_counts[family_category] = int(category_counts.get(family_category, 0)) + 1
	if category_counts != EXPECTED_CARD_FAMILY_CATEGORY_COUNTS:
		errors.append("selected_card_category_counts:%s" % JSON.stringify(category_counts))
	if active_owner_ranked_cards != EXPECTED_SELECTION_COUNTS["rank_records"]:
		errors.append("active_owner_ranked_card_count:%d" % active_owner_ranked_cards)
	return {
		"player_card_identity_count": acquisition_card_ids().size(),
		"rank_record_count": ranked_card_ids().size(),
		"acquisition_card_ids_are_rank_one_only": _all_rank_one(acquisition_card_ids()),
		"rank_records_are_upgrade_gradient_only": true,
		"active_owner_ranked_card_count": active_owner_ranked_cards,
		"active_effect_kinds": validated_effect_kinds.keys(),
		"category_counts": category_counts,
		"review_status_counts": review_status_counts,
		"retired_hits": retired_hits,
	}


func _validate_owner_binding(effect_kind: String, binding: Dictionary, statuses: Dictionary, errors: Array[String]) -> void:
	var owner_path := str(binding.get("owner_path", ""))
	if owner_path.is_empty() or not ResourceLoader.exists(owner_path):
		errors.append("active_owner_resource_missing:%s:%s" % [effect_kind, owner_path])
	elif not FileAccess.get_file_as_string(owner_path).contains("extends"):
		errors.append("active_owner_source_invalid:%s:%s" % [effect_kind, owner_path])
	var mechanic_id := str(binding.get("mechanic_id", ""))
	if not mechanic_id.is_empty() and str(statuses.get(mechanic_id, "MISSING")) != "ACTIVE":
		errors.append("effect_mechanic_not_active:%s:%s:%s" % [effect_kind, mechanic_id, str(statuses.get(mechanic_id, "MISSING"))])


func _validate_roles(registry: Dictionary, errors: Array[String]) -> Dictionary:
	var selected_indices: Array[int] = []
	var retired_hits: Array[String] = []
	if role_catalog_scene == null:
		errors.append("role_catalog_scene_missing")
		return {"source_count": 0, "selected_indices": selected_indices, "public_fields_only": false, "retired_hits": retired_hits}
	var owner := role_catalog_scene.instantiate()
	if owner == null:
		errors.append("role_catalog_scene_instantiate_failed")
		return {"source_count": 0, "selected_indices": selected_indices, "public_fields_only": false, "retired_hits": retired_hits}
	var required_methods := ["role_count", "ordered_role_names", "index_by_name", "public_definition_at", "validate_catalog"]
	for method_name in required_methods:
		if not owner.has_method(method_name):
			errors.append("role_catalog_method_missing:%s" % method_name)
	if not owner.has_method("validate_catalog"):
		owner.free()
		return {"source_count": 0, "selected_indices": selected_indices, "public_fields_only": false, "retired_hits": retired_hits}
	var source_report: Dictionary = owner.call("validate_catalog")
	if not bool(source_report.get("valid", false)):
		errors.append("role_catalog_source_invalid:%s" % JSON.stringify(source_report))
	var source_names: Array = owner.call("ordered_role_names")
	var previous_index := -1
	var public_fields_only := true
	for role_name in role_names:
		var index := int(owner.call("index_by_name", role_name))
		selected_indices.append(index)
		if index < 0:
			errors.append("selected_role_missing:%s" % role_name)
			continue
		if index <= previous_index:
			errors.append("selected_role_source_order_invalid:%s" % role_name)
		previous_index = index
		var public_definition: Variant = owner.call("public_definition_at", index)
		if not (public_definition is Dictionary) or str((public_definition as Dictionary).get("name", "")) != role_name or not _is_pure_data(public_definition):
			public_fields_only = false
			errors.append("selected_role_public_projection_invalid:%s" % role_name)
		else:
			retired_hits.append_array(_retired_hits("role:%s" % role_name, public_definition, registry))
	var source_count := int(owner.call("role_count"))
	if source_names.size() != source_count:
		errors.append("role_catalog_ordered_count_mismatch")
	owner.free()
	for hit in retired_hits:
		errors.append("retired_mechanic_identifier:%s" % hit)
	return {
		"source_count": source_count,
		"selected_indices": selected_indices,
		"public_fields_only": public_fields_only,
		"manifest_payload": "names_only",
		"retired_hits": retired_hits,
	}


func _validate_monsters(registry: Dictionary, errors: Array[String]) -> Dictionary:
	var source_names: Array = MONSTER_CATALOG.roster_names()
	var selected := _packed_to_array(monster_names)
	var retired_hits: Array[String] = []
	if selected != source_names:
		errors.append("monster_selection_source_order_or_membership_mismatch")
	if MONSTER_CATALOG.catalog_size() != EXPECTED_SELECTION_COUNTS["monsters"]:
		errors.append("monster_catalog_count:%d" % MONSTER_CATALOG.catalog_size())
	for index in range(MONSTER_CATALOG.catalog_size()):
		retired_hits.append_array(_retired_hits("monster:%s" % str(source_names[index]), MONSTER_CATALOG.catalog_entry(index), registry))
	for hit in retired_hits:
		errors.append("retired_mechanic_identifier:%s" % hit)
	return {
		"source_count": MONSTER_CATALOG.catalog_size(),
		"selected_all_source_monsters": selected == source_names,
		"retired_hits": retired_hits,
	}


func _validate_products(registry: Dictionary, errors: Array[String]) -> Dictionary:
	if product_catalog == null:
		errors.append("product_catalog_resource_missing")
		return {"source_count": 0, "selected_all_source_products": false, "retired_hits": []}
	var selected := _packed_to_array(product_ids)
	var source_ids: Array[String] = product_catalog.call("product_ids")
	var report: Dictionary = product_catalog.call("validation_snapshot", selected)
	if not bool(report.get("valid", false)):
		errors.append("product_catalog_source_invalid:%s" % JSON.stringify(report.get("errors", [])))
	if selected != source_ids:
		errors.append("product_selection_source_order_or_membership_mismatch")
	var retired_hits: Array[String] = []
	for product_id in source_ids:
		retired_hits.append_array(_retired_hits("product:%s" % product_id, product_catalog.call("product_snapshot", product_id), registry))
	for hit in retired_hits:
		errors.append("retired_mechanic_identifier:%s" % hit)
	return {
		"source_count": source_ids.size(),
		"selected_all_source_products": selected == source_ids,
		"industry_count": int(report.get("industry_count", 0)),
		"retired_hits": retired_hits,
	}


func _validate_runtime_consumers(errors: Array[String]) -> Dictionary:
	var missing_paths: Array[String] = []
	for content_kind_variant in RUNTIME_CONSUMER_EVIDENCE.keys():
		var content_kind := str(content_kind_variant)
		for path_variant in RUNTIME_CONSUMER_EVIDENCE[content_kind]:
			var path := str(path_variant)
			if not FileAccess.file_exists(path):
				missing_paths.append("%s:%s" % [content_kind, path])
	if not missing_paths.is_empty():
		errors.append("runtime_consumer_evidence_missing:%s" % JSON.stringify(missing_paths))
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var region_supply_source := FileAccess.get_file_as_string("res://scripts/runtime/region_supply_runtime_controller.gd")
	var commodity_belt_source := FileAccess.get_file_as_string("res://scripts/runtime/commodity_card_inventory_runtime_controller.gd")
	var rank_one_draw_contract := coordinator_source.contains("if rank != 1") \
		and region_supply_source.contains("not _rank_is_one") \
		and commodity_belt_source.contains("int(machine.get(\"rank\", 0)) == 1")
	if not rank_one_draw_contract:
		errors.append("runtime_rank_one_draw_contract_unverified")
	return {
		"consumer_paths": RUNTIME_CONSUMER_EVIDENCE.duplicate(true),
		"missing_paths": missing_paths,
		"rank_one_draw_contract": rank_one_draw_contract,
		"player_card_identity_count": acquisition_card_ids().size(),
		"rank_record_count": ranked_card_ids().size(),
		"rank_records_are_not_draw_ids": rank_one_draw_contract,
		"whitelist_runtime_consumer_attached": false,
		"integration_request_required": true,
	}


func _all_rank_one(card_ids: PackedStringArray) -> bool:
	for card_id in card_ids:
		if not card_id.ends_with(".rank_1"):
			return false
	return true


func _retired_hits(label: String, value: Variant, registry: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var text := JSON.stringify(value).to_lower()
	var identifiers: Array = registry.get("retired_identifiers", []) if registry.get("retired_identifiers", []) is Array else []
	for identifier_variant in identifiers:
		var identifier := str(identifier_variant)
		if not identifier.is_empty() and text.contains(identifier.to_lower()):
			result.append("%s:%s" % [label, identifier])
	return result


func _validate_hidden_information(errors: Array[String]) -> Dictionary:
	var snapshot := selection_snapshot()
	var top_level_keys: Array = snapshot.keys()
	top_level_keys.sort()
	var expected_keys := PUBLIC_SELECTION_KEYS.duplicate()
	expected_keys.sort()
	if top_level_keys != expected_keys:
		errors.append("public_selection_keys_invalid:%s" % JSON.stringify(top_level_keys))
	var forbidden_paths: Array[String] = []
	_collect_forbidden_key_paths(snapshot, "selection", forbidden_paths)
	if not forbidden_paths.is_empty():
		errors.append("hidden_information_key_leak:%s" % JSON.stringify(forbidden_paths))
	if not _is_pure_data(snapshot):
		errors.append("public_selection_not_pure_data")
	return {
		"pure_data": _is_pure_data(snapshot),
		"forbidden_key_paths": forbidden_paths,
		"contains_role_passives": false,
		"contains_card_payloads": false,
		"contains_runtime_owners": false,
	}


func _collect_forbidden_key_paths(value: Variant, path: String, result: Array[String]) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var lower_key := key.to_lower()
			for fragment in PRIVATE_KEY_FRAGMENTS:
				if lower_key.contains(fragment):
					result.append("%s.%s" % [path, key])
					break
			_collect_forbidden_key_paths((value as Dictionary)[key_variant], "%s.%s" % [path, key], result)
	elif value is Array:
		for index in range((value as Array).size()):
			_collect_forbidden_key_paths((value as Array)[index], "%s[%d]" % [path, index], result)


func _is_pure_data(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_ARRAY:
			for item in value as Array:
				if not _is_pure_data(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key_variant in (value as Dictionary).keys():
				if not (key_variant is String) or not _is_pure_data((value as Dictionary)[key_variant]):
					return false
			return true
	return false


func _packed_to_array(values: PackedStringArray) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(value)
	return result


func _canonical_json(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = (value as Dictionary).keys()
		keys.sort()
		var fields: Array[String] = []
		for key_variant in keys:
			var key := str(key_variant)
			fields.append("%s:%s" % [JSON.stringify(key), _canonical_json((value as Dictionary)[key_variant])])
		return "{%s}" % ",".join(fields)
	if value is Array:
		var items: Array[String] = []
		for item in value as Array:
			items.append(_canonical_json(item))
		return "[%s]" % ",".join(items)
	return JSON.stringify(value)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _file_sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(file.get_buffer(file.get_length()))
	return context.finish().hex_encode()
