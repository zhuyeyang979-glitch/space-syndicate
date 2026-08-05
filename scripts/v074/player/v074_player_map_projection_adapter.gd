extends RefCounted
class_name V074PlayerMapProjectionAdapter

const Wire := preload("res://scripts/semantic/semantic_wire_v1.gd")
const PopupDto := preload("res://scripts/v074/player/v074_region_popup_dto_v1.gd")
const TargetBinding := preload("res://scripts/v074/player/v074_map_target_binding_v1.gd")

const SCHEMA_VERSION := 1
const RULESET_ID := "v0.7.4"
const ADAPTER_ID := "v074.player_map_projection_adapter.v1"
const PROJECTION_ID := "v074.player_map_projection.v1"
const TARGET_RESULT_ID := "v074.target_resolution.result.v1"
const MIN_REGION_COUNT := 6
const MAX_VERIFIED_REGION_COUNT := 30
const PROJECTION_FIELDS := [
	"schema_version", "projection_id", "adapter_id", "ruleset_id",
	"visibility_scope_id", "viewer_id", "map_id", "map_seed", "map_profile_id",
	"map_fingerprint", "region_count", "region_ids", "regions",
	"public_facility_slots", "region_popup_by_id",
	"legal_target_bindings_by_card_instance", "target_rail_region_entries",
	"target_rail_target_entries", "planet_primary_target_selection_surface",
	"target_rail_primary_surface", "target_rail_virtualized",
	"projection_fingerprint",
]
const PRIVATE_KEYS := [
	"warehouse_stock", "warehouse_inventory", "inventory_by_commodity",
	"warehouse_stock_by_commodity", "private_logistics", "private_logistics_plan",
	"future_transport_plan", "future_action", "future_submission", "ai_plan",
	"ai_score", "opponent_hand", "other_player_hand", "hidden_lead_order",
	"future_supply", "rng_state", "save_payload",
]

var _projection: Dictionary = {}
var _region_popups: Dictionary = {}
var _legal_actions: Array = []
var _adapt_count := 0
var _resolve_count := 0
var _rejection_count := 0
var _last_reason_code := "adapter_unconfigured"


func adapt(
	viewer_id: String,
	map_receipt: Dictionary,
	public_facilities: Array,
	legal_actions: Array
) -> Dictionary:
	if not Wire.is_stable_id(viewer_id):
		return _reject_projection("viewer_id_invalid")
	if str(map_receipt.get("ruleset_id", "")) != RULESET_ID:
		return _reject_projection("ruleset_id_invalid")
	var region_ids := _region_ids(map_receipt.get("region_ids", []))
	var region_count := int(map_receipt.get("region_count", region_ids.size()))
	if region_count != region_ids.size() 			or region_count < MIN_REGION_COUNT 			or region_count > MAX_VERIFIED_REGION_COUNT:
		return _reject_projection("region_count_invalid")
	var map_fingerprint := str(map_receipt.get("map_fingerprint", ""))
	if not Wire.is_fingerprint(map_fingerprint):
		return _reject_projection("map_fingerprint_invalid")
	var safe_facilities := _safe_facility_rows(public_facilities, region_ids, map_receipt)
	var regions := _build_regions(map_receipt, region_ids, safe_facilities)
	if regions.size() != region_count:
		return _reject_projection("region_projection_incomplete")
	_region_popups = {}
	for region_variant in regions:
		var region := region_variant as Dictionary
		var popup := PopupDto.build(region, safe_facilities, map_fingerprint)
		if popup.is_empty():
			return _reject_projection("region_popup_invalid")
		_region_popups[str(region.get("region_id", ""))] = popup
	_legal_actions = _safe_legal_actions(legal_actions, region_ids)
	var bindings_by_card := _bindings_by_card(_legal_actions, "target_rail")
	var region_entries := _region_entries(regions)
	var target_entries := _target_entries(bindings_by_card, regions)
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"projection_id": PROJECTION_ID,
		"adapter_id": ADAPTER_ID,
		"ruleset_id": RULESET_ID,
		"visibility_scope_id": "viewer_authorized_plus_public_map",
		"viewer_id": viewer_id,
		"map_id": str(map_receipt.get("map_id", "map.v074")),
		"map_seed": int(map_receipt.get("map_seed", 0)),
		"map_profile_id": str(map_receipt.get("map_profile_id", "map.profile.custom")),
		"map_fingerprint": map_fingerprint,
		"region_count": region_count,
		"region_ids": region_ids,
		"regions": regions,
		"public_facility_slots": safe_facilities,
		"region_popup_by_id": _region_popups.duplicate(true),
		"legal_target_bindings_by_card_instance": bindings_by_card,
		"target_rail_region_entries": region_entries,
		"target_rail_target_entries": target_entries,
		"planet_primary_target_selection_surface": true,
		"target_rail_primary_surface": false,
		"target_rail_virtualized": true,
	}
	var projection := Wire.sealed_copy(unsealed, "projection_fingerprint")
	var report := validation_report(projection)
	if not bool(report.get("valid", false)):
		return _reject_projection(str(report.get("reason_code", "projection_invalid")))
	_projection = projection.duplicate(true)
	_adapt_count += 1
	_last_reason_code = "projection_adapted"
	return _projection.duplicate(true)


func region_popup(region_id: String) -> Dictionary:
	if not Wire.is_stable_id(region_id) or not _region_popups.has(region_id):
		_last_reason_code = "region_popup_not_found"
		return {}
	_last_reason_code = "region_popup_ready"
	return (_region_popups.get(region_id, {}) as Dictionary).duplicate(true)


func resolve_target(
	card_instance_id: String,
	region_id: String,
	facility_type: String,
	industry_id: String,
	mode: String
) -> Dictionary:
	if _projection.is_empty():
		return _target_result(false, "projection_unbound", {})
	if facility_type not in TargetBinding.FACILITY_TYPES:
		return _target_result(false, "facility_type_invalid", {})
	if industry_id not in TargetBinding.INDUSTRY_IDS:
		return _target_result(false, "industry_id_invalid", {})
	if mode not in TargetBinding.ACTION_MODES:
		return _target_result(false, "facility_action_mode_invalid", {})
	var near_match := false
	for option_variant in _legal_actions:
		var option := option_variant as Dictionary
		if str(option.get("card_instance_id", "")) != card_instance_id:
			continue
		if str(option.get("target_region_id", "")) != region_id:
			continue
		near_match = true
		if str(option.get("facility_type", "")) != facility_type 				or str(option.get("industry_id", "")) != industry_id 				or str(option.get("facility_action_mode", "")) != mode:
			continue
		var binding := TargetBinding.from_legal_option(
			card_instance_id,
			str(option.get("card_definition_id", "")),
			option,
			"planet_map",
			int(option.get("selection_revision", 0))
		)
		if binding.is_empty():
			return _target_result(false, "target_binding_invalid", {})
		_resolve_count += 1
		_last_reason_code = "target_resolved"
		return _target_result(true, "target_resolved", binding)
	return _target_result(
		false,
		"target_slot_identity_mismatch" if near_match else "target_not_legal",
		{}
	)


func projection() -> Dictionary:
	return _projection.duplicate(true)


func debug_snapshot() -> Dictionary:
	return {
		"schema": "V074PlayerMapProjectionAdapterDebugV1",
		"adapter_id": ADAPTER_ID,
		"ruleset_id": RULESET_ID,
		"adapt_count": _adapt_count,
		"resolve_count": _resolve_count,
		"rejection_count": _rejection_count,
		"last_reason_code": _last_reason_code,
		"region_count": int(_projection.get("region_count", 0)),
		"map_gameplay_owner_count": 0,
		"save_owner_count": 0,
		"rng_owner_count": 0,
		"runtime_owner_dependency_count": 0,
		"hidden_info_field_count": 0,
		"planet_primary_target_selection_surface": true,
		"target_rail_primary_surface": false,
	}


static func validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not Wire.is_closed_data(value):
		return _invalid("projection_not_closed_data")
	var projection := value as Dictionary
	if not Wire.exact_fields(projection, PROJECTION_FIELDS):
		return _invalid("projection_fields_invalid")
	if int(projection.get("schema_version", 0)) != SCHEMA_VERSION 			or str(projection.get("projection_id", "")) != PROJECTION_ID 			or str(projection.get("adapter_id", "")) != ADAPTER_ID 			or str(projection.get("ruleset_id", "")) != RULESET_ID:
		return _invalid("projection_identity_invalid")
	if not Wire.is_stable_id(projection.get("viewer_id")) 			or not Wire.is_ascii_reference(projection.get("map_id")) 			or not Wire.is_ascii_reference(projection.get("map_profile_id")) 			or not Wire.is_fingerprint(projection.get("map_fingerprint")):
		return _invalid("projection_map_identity_invalid")
	var region_ids := projection.get("region_ids", []) as Array
	if _region_ids(region_ids).size() != int(projection.get("region_count", -1)):
		return _invalid("projection_region_ids_invalid")
	if (projection.get("regions", []) as Array).size() != region_ids.size():
		return _invalid("projection_regions_incomplete")
	var popups := projection.get("region_popup_by_id", {}) as Dictionary
	if popups.size() != region_ids.size():
		return _invalid("projection_region_popups_incomplete")
	for region_id_variant in region_ids:
		var region_id := str(region_id_variant)
		if not popups.has(region_id) 				or not bool(PopupDto.validation_report(popups.get(region_id)).get("valid", false)):
			return _invalid("projection_region_popup_invalid")
	if not bool(projection.get("planet_primary_target_selection_surface", false)) 			or bool(projection.get("target_rail_primary_surface", true)) 			or not bool(projection.get("target_rail_virtualized", false)):
		return _invalid("projection_surface_authority_invalid")
	if Wire.contains_key_recursive(projection, PRIVATE_KEYS):
		return _invalid("projection_private_field_detected")
	var fingerprint := str(projection.get("projection_fingerprint", ""))
	if not Wire.is_fingerprint(fingerprint) 			or fingerprint != Wire.fingerprint(projection, "projection_fingerprint"):
		return _invalid("projection_fingerprint_invalid")
	return {"valid": true, "reason_code": "none"}


static func _build_regions(
	map_receipt: Dictionary,
	region_ids: Array,
	facilities: Array
) -> Array:
	var terrain := map_receipt.get("terrain_by_region", {}) as Dictionary
	var adjacency := map_receipt.get("adjacency_graph", {}) as Dictionary
	var display_names := map_receipt.get("display_name_by_region", {}) as Dictionary
	var solar := _solar_by_region(map_receipt)
	var result: Array = []
	for index in range(region_ids.size()):
		var region_id := str(region_ids[index])
		var terrain_class := str(terrain.get(region_id, ""))
		if terrain_class not in ["land", "ocean"]:
			return []
		var solar_row := solar.get(region_id, {}) as Dictionary
		var sunlit := bool(solar_row.get("sunlit", false))
		var facility_count := 0
		var warehouse_count := 0
		for value in facilities:
			var row := value as Dictionary
			if str(row.get("region_id", "")) == region_id 					and str(row.get("occupancy", "")) == "occupied":
				facility_count += 1
				if str(row.get("facility_type", "")) == "warehouse":
					warehouse_count += 1
		result.append({
			"region_id": region_id,
			"public_index": index,
			"display_name": str(display_names.get(region_id, "Region %02d" % (index + 1))),
			"terrain_class": terrain_class,
			"sunlit": sunlit,
			"solar_efficiency_multiplier_bps": _multiplier_bps(
				solar_row,
				20000 if sunlit else 10000
			),
			"neighbor_region_ids": _neighbors(adjacency.get(region_id, []), region_ids),
			"public_facility_count": facility_count,
			"public_warehouse_count": warehouse_count,
		})
	return result


static func _safe_facility_rows(
	values: Array,
	region_ids: Array,
	map_receipt: Dictionary
) -> Array:
	var solar := _solar_by_region(map_receipt)
	var result: Array = []
	for value in values:
		if not (value is Dictionary):
			continue
		var source := value as Dictionary
		var region_id := str(source.get("region_id", ""))
		if region_id not in region_ids:
			continue
		var sunlit := bool((solar.get(region_id, {}) as Dictionary).get("sunlit", false))
		var row := PopupDto.public_facility_row(source, sunlit)
		if not row.is_empty():
			result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return "%s|%s" % [a.get("region_id", ""), a.get("slot_id", "")] 			< "%s|%s" % [b.get("region_id", ""), b.get("slot_id", "")]
	)
	return result


static func _safe_legal_actions(values: Array, region_ids: Array) -> Array:
	var result: Array = []
	for value in values:
		if not (value is Dictionary):
			continue
		var source := value as Dictionary
		var region_id := str(source.get("target_region_id", source.get("region_id", "")))
		var card_id := str(source.get("card_instance_id", ""))
		var definition_id := str(source.get("card_definition_id", source.get("definition_id", "")))
		var kind := str(source.get("facility_type", ""))
		var industry := str(source.get("industry_id", ""))
		var mode := str(source.get("facility_action_mode", source.get("action_mode", "")))
		if region_id not in region_ids or not Wire.is_stable_id(card_id) 				or not Wire.is_stable_id(definition_id) 				or kind not in TargetBinding.FACILITY_TYPES 				or industry not in TargetBinding.INDUSTRY_IDS 				or mode not in TargetBinding.ACTION_MODES:
			continue
		var option := {
			"legal": true,
			"card_instance_id": card_id,
			"card_definition_id": definition_id,
			"target_region_id": region_id,
			"target_slot_id": str(source.get("target_slot_id", source.get("slot_id", ""))),
			"facility_type": kind,
			"industry_id": industry,
			"facility_action_mode": mode,
			"target_revision": _nonnegative_int(source.get("target_revision", source.get("region_revision", 0))),
			"target_slot_generation": _nonnegative_int(source.get("target_slot_generation", source.get("slot_generation", 0))),
			"expected_facility_id": _text_or_empty(source.get("expected_facility_id", source.get("facility_id", ""))),
			"expected_facility_generation": _nonnegative_int(source.get("expected_facility_generation", source.get("facility_generation", 0))),
			"expected_owner_id": _text_or_empty(source.get("expected_owner_id", source.get("owner_id", ""))),
			"expected_rank": _nonnegative_int(source.get("expected_rank", source.get("rank", 0))),
			"expected_damage_revision": _nonnegative_int(source.get("expected_damage_revision", source.get("damage_revision", 0))),
			"asset_cost": _nonnegative_int(source.get("asset_cost", source.get("primary_asset_cost", 0))),
			"selection_revision": _nonnegative_int(source.get("selection_revision", 0)),
		}
		if not str(option.get("target_slot_id", "")).is_empty():
			result.append(option)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _legal_sort_key(a) < _legal_sort_key(b)
	)
	return result


static func _bindings_by_card(actions: Array, source_surface: String) -> Dictionary:
	var result := {}
	for value in actions:
		var option := value as Dictionary
		var card_id := str(option.get("card_instance_id", ""))
		var binding := TargetBinding.from_legal_option(
			card_id,
			str(option.get("card_definition_id", "")),
			option,
			source_surface,
			int(option.get("selection_revision", 0))
		)
		if binding.is_empty():
			continue
		if not result.has(card_id):
			result[card_id] = []
		(result[card_id] as Array).append(binding)
	return result


static func _region_entries(regions: Array) -> Array:
	var result: Array = []
	for value in regions:
		var region := value as Dictionary
		var region_id := str(region.get("region_id", ""))
		result.append({
			"entry_id": "rail.region.%s" % region_id,
			"entry_kind": "region_popup",
			"region_id": region_id,
			"display_name": str(region.get("display_name", region_id)),
			"terrain_class": str(region.get("terrain_class", "")),
			"sunlit": bool(region.get("sunlit", false)),
			"card_instance_id": "",
			"facility_type": "",
			"industry_id": "",
			"facility_action_mode": "",
			"search_text": "%s %s %s" % [region_id, region.get("display_name", ""), region.get("terrain_class", "")],
			"binding": {},
		})
	return result


static func _target_entries(bindings_by_card: Dictionary, regions: Array) -> Array:
	var region_by_id := {}
	for value in regions:
		var region := value as Dictionary
		region_by_id[str(region.get("region_id", ""))] = region
	var result: Array = []
	var card_ids: Array = bindings_by_card.keys()
	card_ids.sort()
	for card_id_variant in card_ids:
		for value in bindings_by_card.get(card_id_variant, []) as Array:
			var binding := value as Dictionary
			var region_id := str(binding.get("target_region_id", ""))
			var region := region_by_id.get(region_id, {}) as Dictionary
			result.append({
				"entry_id": "rail.target.%s" % str(binding.get("binding_fingerprint", "")).substr(0, 20),
				"entry_kind": "target_binding",
				"region_id": region_id,
				"display_name": str(region.get("display_name", region_id)),
				"terrain_class": str(region.get("terrain_class", "")),
				"sunlit": bool(region.get("sunlit", false)),
				"card_instance_id": str(binding.get("card_instance_id", "")),
				"facility_type": str(binding.get("facility_type", "")),
				"industry_id": str(binding.get("industry_id", "")),
				"facility_action_mode": str(binding.get("facility_action_mode", "")),
				"search_text": "%s %s %s %s %s" % [
					region_id, region.get("display_name", ""),
					binding.get("facility_type", ""), binding.get("industry_id", ""),
					binding.get("facility_action_mode", ""),
				],
				"binding": binding.duplicate(true),
			})
	return result


static func _solar_by_region(map_receipt: Dictionary) -> Dictionary:
	var source: Variant = map_receipt.get("solar_state_by_region", map_receipt.get("region_solar", {}))
	if source is Dictionary:
		return (source as Dictionary).duplicate(true)
	var result := {}
	if source is Array:
		for value in source as Array:
			if value is Dictionary:
				var row := value as Dictionary
				result[str(row.get("region_id", ""))] = row.duplicate(true)
	return result


static func _multiplier_bps(row: Dictionary, fallback: int) -> int:
	var value: Variant = row.get("solar_efficiency_multiplier_bps", row.get("facility_efficiency_multiplier", fallback))
	if value is int:
		return int(value) if int(value) >= 1000 else int(value) * 10000
	if value is float:
		return int(round(float(value) * 10000.0))
	return fallback


static func _region_ids(value: Variant) -> Array:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for item in value as Array:
		var region_id := str(item)
		if not Wire.is_stable_id(region_id) or result.has(region_id):
			return []
		result.append(region_id)
	return result


static func _neighbors(value: Variant, region_ids: Array) -> Array:
	var result: Array[String] = []
	if value is Array:
		for item in value as Array:
			var region_id := str(item)
			if region_id in region_ids and not result.has(region_id):
				result.append(region_id)
	result.sort()
	return result


static func _legal_sort_key(row: Dictionary) -> String:
	return "%s|%s|%s|%s|%s" % [
		row.get("card_instance_id", ""), row.get("target_region_id", ""),
		row.get("facility_type", ""), row.get("industry_id", ""),
		row.get("facility_action_mode", ""),
	]


func _target_result(accepted: bool, reason_code: String, binding: Dictionary) -> Dictionary:
	if not accepted:
		_rejection_count += 1
		_last_reason_code = reason_code
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"result_id": TARGET_RESULT_ID,
		"ruleset_id": RULESET_ID,
		"accepted": accepted,
		"reason_code": reason_code,
		"binding": binding.duplicate(true),
	}
	return Wire.sealed_copy(unsealed, "result_fingerprint")


func _reject_projection(reason_code: String) -> Dictionary:
	_rejection_count += 1
	_last_reason_code = reason_code
	_projection = {}
	_region_popups = {}
	_legal_actions = []
	return {}


static func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code}


static func _nonnegative_int(value: Variant) -> int:
	if value is int:
		return maxi(0, int(value))
	if value is float and is_finite(float(value)):
		return maxi(0, int(round(float(value))))
	return 0


static func _text_or_empty(value: Variant) -> String:
	return "" if value == null else str(value)
