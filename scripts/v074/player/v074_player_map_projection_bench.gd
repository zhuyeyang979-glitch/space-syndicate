extends Control
class_name V074PlayerMapProjectionBench

const Wire := preload("res://scripts/semantic/semantic_wire_v1.gd")
const Adapter := preload("res://scripts/v074/player/v074_player_map_projection_adapter.gd")
const INDUSTRIES := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const FACILITY_TYPES := ["factory", "market", "warehouse"]
const FIXED_SEED := 900626424

@onready var _rail: V074VirtualizedTargetRail = %V074VirtualizedTargetRail
@onready var _status_label: RichTextLabel = %StatusLabel

var _adapter := Adapter.new()
var _projection: Dictionary = {}
var _exercise_complete := false
var _popup_signal_count := 0
var _binding_signal_count := 0
var _last_binding: Dictionary = {}


func _ready() -> void:
	_projection = _adapter.adapt(
		"player.local",
		make_map_receipt(30),
		make_public_facilities(30),
		make_legal_actions(30)
	)
	_rail.region_popup_requested.connect(func(_dto: Dictionary) -> void:
		_popup_signal_count += 1
	)
	_rail.target_binding_requested.connect(func(binding: Dictionary) -> void:
		_binding_signal_count += 1
		_last_binding = binding.duplicate(true)
	)
	_rail.bind_projection(_projection)
	_rail.set_selected_card("card.instance.warehouse.shipping")
	_rail.set_collapsed(false)
	call_deferred("_exercise_contract")


func _exercise_contract() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var factory_result := _adapter.resolve_target(
		"card.instance.factory.life",
		"region.000",
		"factory",
		"life",
		"UPGRADE_OWN"
	)
	var market_result := _adapter.resolve_target(
		"card.instance.market.energy",
		"region.000",
		"market",
		"energy",
		"BUILD_NEW"
	)
	var warehouse_result := _adapter.resolve_target(
		"card.instance.warehouse.shipping",
		"region.000",
		"warehouse",
		"shipping",
		"BUILD_NEW"
	)
	var popup := _adapter.region_popup("region.001")
	_rail.set_search_text("shipping")
	_exercise_complete = (
		not _projection.is_empty()
		and bool(factory_result.get("accepted", false))
		and bool(market_result.get("accepted", false))
		and bool(warehouse_result.get("accepted", false))
		and not popup.is_empty()
		and _rail.filtered_entry_count() == 30
	)
	var status := debug_snapshot()
	_status_label.text = (
		"[b]V0.7.4 Player Map Projection[/b]\n"
		+ "30 dynamic regions | 540 facility slots | 3 typed facility targets\n"
		+ "Warehouse public DTO: capacity + ingress + egress; private stock omitted\n"
		+ "TargetRail: search + collapse + keyboard + fixed 10-row pool\n\n"
		+ "[color=%s]%s[/color]"
	) % [
		"#62d8b3" if _exercise_complete else "#ff7b88",
		"BENCH GREEN" if _exercise_complete else "BENCH FAILED",
	]
	print("V074_PLAYER_MAP_PROJECTION_BENCH|%s" % JSON.stringify(status))


func debug_snapshot() -> Dictionary:
	var popup := _adapter.region_popup("region.001")
	var warehouse_rows := 0
	for value in popup.get("public_facilities", []) as Array:
		if str((value as Dictionary).get("facility_type", "")) == "warehouse":
			warehouse_rows += 1
	var adapter_debug := _adapter.debug_snapshot()
	var rail_debug := _rail.debug_snapshot() if is_instance_valid(_rail) else {}
	return {
		"schema": "V074PlayerMapProjectionBenchDebugV1",
		"exercise_complete": _exercise_complete,
		"projection_valid": bool(Adapter.validation_report(_projection).get("valid", false)),
		"region_count": int(_projection.get("region_count", 0)),
		"public_facility_slot_count": (_projection.get("public_facility_slots", []) as Array).size(),
		"warehouse_public_row_count_in_region_001": warehouse_rows,
		"private_stock_disclosure_count": _private_key_count(_projection),
		"adapter": adapter_debug,
		"rail": rail_debug,
		"popup_signal_count": _popup_signal_count,
		"binding_signal_count": _binding_signal_count,
		"last_binding": _last_binding.duplicate(true),
		"runtime_owner_dependency_count": 0,
	}


static func make_map_receipt(region_count: int) -> Dictionary:
	var ids: Array[String] = []
	var terrain := {}
	var adjacency := {}
	var display_names := {}
	var solar := {}
	for index in range(region_count):
		var region_id := "region.%03d" % index
		ids.append(region_id)
		terrain[region_id] = "land" if index % 3 != 1 else "ocean"
		display_names[region_id] = "Sector %02d" % (index + 1)
		solar[region_id] = {
			"sunlit": index % 2 == 0,
			"solar_efficiency_multiplier_bps": 20000 if index % 2 == 0 else 10000,
		}
	for index in range(region_count):
		var previous := ids[posmod(index - 1, region_count)]
		var next := ids[(index + 1) % region_count]
		adjacency[ids[index]] = [previous, next]
	var identity := {
		"ruleset_id": "v0.7.4",
		"map_seed": FIXED_SEED,
		"region_count": region_count,
		"region_ids": ids,
		"terrain_by_region": terrain,
		"adjacency_graph": adjacency,
	}
	return {
		"schema_version": 1,
		"ruleset_id": "v0.7.4",
		"map_id": "map.v074.bench.%d" % region_count,
		"map_seed": FIXED_SEED,
		"map_profile_id": "map.profile.standard.balanced",
		"region_count": region_count,
		"region_ids": ids,
		"terrain_by_region": terrain,
		"adjacency_graph": adjacency,
		"display_name_by_region": display_names,
		"solar_state_by_region": solar,
		"map_fingerprint": Wire.fingerprint(identity),
	}


static func make_public_facilities(region_count: int) -> Array:
	var result: Array = []
	for region_index in range(region_count):
		var region_id := "region.%03d" % region_index
		for facility_type in FACILITY_TYPES:
			for industry_id in INDUSTRIES:
				var occupied := false
				var damage := 0
				if facility_type == "factory" and industry_id == "life":
					occupied = true
				elif facility_type == "warehouse" and industry_id == "shipping":
					occupied = region_index % 3 != 0
					damage = 1 if region_index % 3 == 1 else 0
				var row := {
					"facility_id": "facility.%03d.%s.%s" % [region_index, facility_type, industry_id],
					"slot_id": "%s::%s.%s" % [region_id, facility_type, industry_id],
					"region_id": region_id,
					"facility_type": facility_type,
					"industry_id": industry_id,
					"occupancy": "occupied" if occupied else "empty",
					"owner_public_id": "player.local" if occupied else "",
					"owner_public_index": 0 if occupied else -1,
					"owner_public_label": "Commander" if occupied else "",
					"rank": 1 if occupied else 0,
					"damage_points": damage,
					"damage_revision": damage,
					"sunlit": region_index % 2 == 0,
					"solar_efficiency_multiplier_bps": 20000 if region_index % 2 == 0 else 10000,
					"asset_key": "model.facility.%s.base" % facility_type,
				}
				if facility_type == "warehouse":
					row["public_capacity"] = 12
					row["public_ingress_throughput"] = 4 * (2 if region_index % 2 == 0 else 1)
					row["public_egress_throughput"] = 3 * (2 if region_index % 2 == 0 else 1)
					row["warehouse_stock"] = {"shipping": 999999}
					row["private_logistics_plan"] = {"next_region": "PRIVATE_SENTINEL"}
				result.append(row)
	return result


static func make_legal_actions(region_count: int) -> Array:
	var result: Array = []
	for region_index in range(region_count):
		var region_id := "region.%03d" % region_index
		result.append(_legal(
			"card.instance.factory.life",
			"facility.factory.life.rank_1",
			region_id,
			"factory",
			"life",
			"UPGRADE_OWN",
			region_index
		))
		result.append(_legal(
			"card.instance.market.energy",
			"facility.market.energy.rank_1",
			region_id,
			"market",
			"energy",
			"BUILD_NEW",
			region_index
		))
		var warehouse_mode := "BUILD_NEW"
		if region_index % 3 == 1:
			warehouse_mode = "REPAIR_OWN"
		elif region_index % 3 == 2:
			warehouse_mode = "UPGRADE_OWN"
		result.append(_legal(
			"card.instance.warehouse.shipping",
			"facility.warehouse.shipping.rank_1",
			region_id,
			"warehouse",
			"shipping",
			warehouse_mode,
			region_index
		))
	return result


static func _legal(
	card_id: String,
	definition_id: String,
	region_id: String,
	facility_type: String,
	industry_id: String,
	mode: String,
	index: int
) -> Dictionary:
	var occupied := mode != "BUILD_NEW"
	return {
		"legal": true,
		"card_instance_id": card_id,
		"card_definition_id": definition_id,
		"target_region_id": region_id,
		"target_slot_id": "%s::%s.%s" % [region_id, facility_type, industry_id],
		"facility_type": facility_type,
		"industry_id": industry_id,
		"facility_action_mode": mode,
		"target_revision": 1,
		"target_slot_generation": 0,
		"expected_facility_id": "facility.%03d.%s.%s" % [index, facility_type, industry_id] if occupied else "",
		"expected_facility_generation": 1 if occupied else 0,
		"expected_owner_id": "player.local" if occupied else "",
		"expected_rank": 1 if occupied else 0,
		"expected_damage_revision": 1 if mode == "REPAIR_OWN" else 0,
		"asset_cost": 1,
		"selection_revision": 1,
	}


static func _private_key_count(value: Variant) -> int:
	var count := 0
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if key in Adapter.PRIVATE_KEYS:
				count += 1
			count += _private_key_count((value as Dictionary).get(key_variant))
	elif value is Array:
		for item in value as Array:
			count += _private_key_count(item)
	return count
