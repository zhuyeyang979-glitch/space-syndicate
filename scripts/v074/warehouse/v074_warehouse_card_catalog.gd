extends RefCounted
class_name V074WarehouseCardCatalog

const FacilityTypes := preload(
	"res://scripts/v074/facility/v074_facility_type_registry.gd"
)
const CardDefinitions := preload(
	"res://scripts/v074/facility/v074_card_definition_registry.gd"
)

const SCHEMA_VERSION := 1
const CATALOG_ID := "space_syndicate.v074.warehouse_card_catalog.v1"
const RULESET_ID := "v0.7.4"
const FACILITY_TYPE := "warehouse"
const COMMERCIAL_ART_KEY := "model.facility.warehouse.base"
const PURCHASE_DESTINATION := "discard"
const OPTIONAL_MERGE_DECISION_MODE := "player_explicit"
const AUTOMATIC_MERGE_ENABLED := false


static func catalog_contract() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"catalog_id": CATALOG_ID,
		"ruleset_id": RULESET_ID,
		"facility_type": FACILITY_TYPE,
		"starter_card_count": 0,
		"standard_l1_definition_ids": standard_l1_definition_ids(),
		"standard_l1_definition_count": standard_l1_definition_ids().size(),
		"track_spawn_allowed": true,
		"purchase_destination": PURCHASE_DESTINATION,
		"dbg_draw_allowed": true,
		"optional_merge_allowed": true,
		"optional_merge_decision_mode": OPTIONAL_MERGE_DECISION_MODE,
		"automatic_merge_enabled": AUTOMATIC_MERGE_ENABLED,
		"commercial_art_key": COMMERCIAL_ART_KEY,
		"gameplay_owner_count": 0,
		"save_owner_count": 0,
		"rng_owner_count": 0,
	}


static func standard_l1_definition_ids() -> Array[String]:
	return CardDefinitions.warehouse_standard_l1_definition_ids()


static func standard_l1_definitions() -> Array:
	return CardDefinitions.warehouse_standard_l1_definitions()


static func all_definition_ids() -> Array[String]:
	var result: Array[String] = []
	for color_id in FacilityTypes.INDUSTRY_IDS:
		for rank in range(1, FacilityTypes.MAX_FACILITY_RANK + 1):
			result.append(
				CardDefinitions.standard_definition_id(
					FACILITY_TYPE,
					str(color_id),
					rank
				)
			)
	return result


static func definition(definition_id: String) -> Dictionary:
	var result := CardDefinitions.definition(definition_id)
	if str(result.get("card_type", "")) != FACILITY_TYPE:
		return {}
	return result


static func catalog_entry(definition_id: String) -> Dictionary:
	var card_definition := definition(definition_id)
	if card_definition.is_empty():
		return {}
	return {
		"definition": card_definition,
		"facility_type": FACILITY_TYPE,
		"industry_id": str(card_definition.get("primary_color", "")),
		"rank": int(card_definition.get("level", 0)),
		"commercial_art_key": COMMERCIAL_ART_KEY,
		"target_kind": "region_unique_facility_slot",
		"action_modes": ["BUILD_NEW", "UPGRADE_OWN", "REPAIR_OWN"],
		"purchase_destination": PURCHASE_DESTINATION,
		"stock_runtime_phase": "existing_external_owner_or_deferred",
	}


static func purchase_to_discard_contract(
	definition_id: String,
	track_instance_id: String,
	purchase_receipt_id: String
) -> Dictionary:
	var card_definition := definition(definition_id)
	if card_definition.is_empty():
		return _acquisition_failure("warehouse_definition_unknown")
	if not bool(card_definition.get("track_spawn_allowed", false)):
		return _acquisition_failure("warehouse_definition_not_track_spawnable")
	if track_instance_id.strip_edges().is_empty():
		return _acquisition_failure("warehouse_track_instance_id_missing")
	if purchase_receipt_id.strip_edges().is_empty():
		return _acquisition_failure("warehouse_purchase_receipt_id_missing")
	return {
		"accepted": true,
		"reason_code": "warehouse_purchase_enters_personal_discard",
		"definition_id": definition_id,
		"track_instance_id": track_instance_id,
		"purchase_receipt_id": purchase_receipt_id,
		"destination_zone": PURCHASE_DESTINATION,
		"available_for_immediate_draw": false,
		"dbg_draw_allowed_after_normal_reshuffle": true,
	}


static func drawn_card_contract(card: Dictionary) -> Dictionary:
	var definition_id := str(card.get(
		"definition_id",
		card.get("card_definition_id", "")
	))
	var card_definition := definition(definition_id)
	if card_definition.is_empty():
		return {
			"valid": false,
			"reason_code": "warehouse_draw_definition_invalid",
		}
	var instance_id := str(card.get(
		"instance_id",
		card.get("card_instance_id", "")
	))
	var valid := (
		not instance_id.strip_edges().is_empty()
		and str(card_definition.get("origin_class", ""))
		== CardDefinitions.ORIGIN_STANDARD
	)
	return {
		"valid": valid,
		"reason_code": (
			"warehouse_dbg_draw_valid"
			if valid
			else "warehouse_draw_instance_id_missing"
		),
		"definition": card_definition,
	}


static func optional_merge(
	left_definition_id: String,
	right_definition_id: String,
	decision_mode: String = OPTIONAL_MERGE_DECISION_MODE
) -> Dictionary:
	if decision_mode != OPTIONAL_MERGE_DECISION_MODE:
		return _merge_failure("warehouse_merge_requires_player_explicit_decision")
	var left := definition(left_definition_id)
	var right := definition(right_definition_id)
	if left.is_empty() or right.is_empty():
		return _merge_failure("warehouse_merge_definition_unknown")
	if (
		str(left.get("merge_family_id", ""))
		!= str(right.get("merge_family_id", ""))
	):
		return _merge_failure("warehouse_merge_family_mismatch")
	var left_level := int(left.get("level", 0))
	var right_level := int(right.get("level", 0))
	if left_level != right_level:
		return _merge_failure("warehouse_merge_rank_mismatch")
	if left_level >= FacilityTypes.MAX_FACILITY_RANK:
		return _merge_failure("warehouse_merge_max_rank")
	var output_id := CardDefinitions.standard_definition_id(
		FACILITY_TYPE,
		str(left.get("primary_color", "")),
		left_level + 1
	)
	return {
		"accepted": true,
		"reason_code": "warehouse_optional_merge_completed",
		"decision_mode": OPTIONAL_MERGE_DECISION_MODE,
		"automatic": false,
		"source_definition_ids": [
			left_definition_id,
			right_definition_id,
		],
		"output_definition_id": output_id,
		"output_definition": definition(output_id),
	}


static func _acquisition_failure(reason_code: String) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"definition_id": "",
		"track_instance_id": "",
		"purchase_receipt_id": "",
		"destination_zone": "",
		"available_for_immediate_draw": false,
		"dbg_draw_allowed_after_normal_reshuffle": false,
	}


static func _merge_failure(reason_code: String) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"decision_mode": OPTIONAL_MERGE_DECISION_MODE,
		"automatic": false,
		"source_definition_ids": [],
		"output_definition_id": "",
		"output_definition": {},
	}
