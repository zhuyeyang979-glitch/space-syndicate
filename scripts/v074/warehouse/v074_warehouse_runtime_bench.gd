extends Node

const Types := preload(
	"res://scripts/v074/facility/v074_facility_type_registry.gd"
)
const Slots := preload(
	"res://scripts/v074/facility/v074_facility_slot_registry.gd"
)
const Core := preload(
	"res://scripts/v074/facility/v074_facility_runtime_core.gd"
)
const Cards := preload(
	"res://scripts/v074/warehouse/v074_warehouse_card_catalog.gd"
)
const WarehouseRuntime := preload(
	"res://scripts/v074/warehouse/v074_warehouse_runtime_policy.gd"
)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var region_ids: Array[String] = []
	for index in range(16):
		region_ids.append("region.%03d" % index)
	var slots := Slots.build_slots(region_ids)
	var slot_report := Slots.validation_report(region_ids, slots)
	var warehouse_slot := Core.build_empty_slot(
		"region.000",
		1,
		"warehouse",
		"life",
		0
	)
	var action := Core.build_new_action(
		"action.bench.warehouse",
		"card.bench.warehouse",
		"player.0",
		0,
		warehouse_slot,
		_assets("life", 1),
		"standard",
		1
	)
	var state := Core.lock_batch(
		"batch.bench.warehouse",
		["player.0"],
		["player.0"],
		{"player.0": [action]},
		[warehouse_slot]
	)
	var resolved := Core.resolve_next(state)
	var resolved_state := resolved.get("state", {}) as Dictionary
	var resolved_slots := resolved_state.get("facility_slots", {}) as Dictionary
	var built := (
		resolved_slots.values()[0] as Dictionary
		if resolved_slots.size() == 1
		else {}
	)
	var sunlit := Core.refresh_slot_solar_state(built, "sunlit")
	var projection := WarehouseRuntime.public_projection(sunlit)
	var privacy := WarehouseRuntime.privacy_report(projection)
	var checks := {
		"ruleset_id": Core.RULESET_ID,
		"registered_facility_types": Types.registered_facility_types(),
		"starter_facility_types": Types.starter_facility_types(),
		"standard_track_facility_types": Types.standard_track_facility_types(),
		"facility_slot_count_per_region": Types.facility_slot_count_per_region(),
		"region_count": region_ids.size(),
		"facility_slot_count": slots.size(),
		"slot_registry_valid": bool(slot_report.get("valid", false)),
		"warehouse_l1_definition_count": (
			Cards.standard_l1_definitions().size()
		),
		"warehouse_built": (
			str(built.get("facility_type", "")) == "warehouse"
			and int(built.get("rank", 0)) == 1
		),
		"warehouse_capacity": int(built.get("capacity", 0)),
		"warehouse_dark_ingress": float(
			built.get("ingress_throughput", 0.0)
		),
		"warehouse_sunlit_ingress": float(
			sunlit.get("ingress_throughput", 0.0)
		),
		"warehouse_sunlit_egress": float(
			sunlit.get("egress_throughput", 0.0)
		),
		"warehouse_public_projection_green": not projection.is_empty(),
		"warehouse_hidden_info_field_count": int(
			privacy.get("hidden_info_field_count", -1)
		),
		"warehouse_gameplay_owner_count": int(
			WarehouseRuntime.contract_snapshot().get(
				"gameplay_owner_count",
				-1
			)
		),
		"warehouse_save_owner_count": int(
			WarehouseRuntime.contract_snapshot().get(
				"save_owner_count",
				-1
			)
		),
		"warehouse_rng_owner_count": int(
			WarehouseRuntime.contract_snapshot().get(
				"rng_owner_count",
				-1
			)
		),
	}
	var passed: bool = (
		checks.get("ruleset_id") == "v0.7.4"
		and checks.get("registered_facility_types")
		== ["factory", "market", "warehouse"]
		and checks.get("starter_facility_types")
		== ["factory", "market"]
		and checks.get("facility_slot_count_per_region") == 18
		and checks.get("facility_slot_count") == 288
		and checks.get("slot_registry_valid") == true
		and checks.get("warehouse_l1_definition_count") == 6
		and checks.get("warehouse_built") == true
		and checks.get("warehouse_capacity") == 200
		and checks.get("warehouse_dark_ingress") == 50.0
		and checks.get("warehouse_sunlit_ingress") == 100.0
		and checks.get("warehouse_sunlit_egress") == 100.0
		and checks.get("warehouse_public_projection_green") == true
		and checks.get("warehouse_hidden_info_field_count") == 0
		and checks.get("warehouse_gameplay_owner_count") == 0
		and checks.get("warehouse_save_owner_count") == 0
		and checks.get("warehouse_rng_owner_count") == 0
	)
	print(
		"V074_WAREHOUSE_RUNTIME_BENCH|%s|%s"
		% [
			"PASS" if passed else "FAIL",
			JSON.stringify(checks),
		]
	)
	get_tree().quit(0 if passed else 1)


func _assets(color_id: String, amount: int) -> Dictionary:
	var result := {
		"life": 0,
		"energy": 0,
		"industry": 0,
		"technology": 0,
		"commerce": 0,
		"shipping": 0,
	}
	result[color_id] = amount
	return result
