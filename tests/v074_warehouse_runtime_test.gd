extends SceneTree

const Core := preload(
	"res://scripts/v074/facility/v074_facility_runtime_core.gd"
)
const WarehouseRuntime := preload(
	"res://scripts/v074/warehouse/v074_warehouse_runtime_policy.gd"
)
const WarehouseCards := preload(
	"res://scripts/v074/warehouse/v074_warehouse_card_catalog.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_build_and_contention()
	_test_upgrade_repair_and_solar()
	_test_atomic_solar_refresh()
	_test_dbg_merge_and_privacy()
	_finish()


func _test_build_and_contention() -> void:
	var slot := Core.build_empty_slot(
		"region.000",
		1,
		"warehouse",
		"life",
		0
	)
	var first := Core.build_new_action(
		"action.build.first",
		"card.warehouse.life.001",
		"player.0",
		0,
		slot,
		_assets("life", 1),
		"standard",
		1
	)
	var second := Core.build_new_action(
		"action.build.second",
		"card.warehouse.life.002",
		"player.1",
		0,
		slot,
		_assets("life", 1),
		"standard",
		1
	)
	var state := Core.lock_batch(
		"batch.contention",
		["player.0", "player.1"],
		["player.0", "player.1"],
		{"player.0": [first], "player.1": [second]},
		[slot]
	)
	_expect(Core.validation_report(state).get("valid") == true, "contention batch validates")
	var first_result := Core.resolve_next(state)
	state = first_result.get("state", {}) as Dictionary
	var second_result := Core.resolve_next(state)
	state = second_result.get("state", {}) as Dictionary
	var first_receipt := first_result.get("receipt", {}) as Dictionary
	var second_receipt := second_result.get("receipt", {}) as Dictionary
	var resolved_slot := (
		(state.get("facility_slots", {}) as Dictionary).get(
			str(slot.get("slot_id", "")),
			{}
		) as Dictionary
	)
	_expect(
		first_receipt.get("facility_created") == true,
		"earlier warehouse build creates the facility"
	)
	_expect(
		resolved_slot.get("facility_type") == "warehouse"
		and resolved_slot.get("owner_id") == "player.0"
		and resolved_slot.get("rank") == 1
		and resolved_slot.get("capacity") == 200
		and resolved_slot.get("ingress_throughput") == 50.0
		and resolved_slot.get("egress_throughput") == 50.0,
		"dark rank-I warehouse exposes authoritative capacity and throughput"
	)
	_expect(
		second_receipt.get("outcome_id") == "facility_action_fizzled"
		and second_receipt.get("reason_code")
		== "facility_target_invalid_slot_occupied"
		and second_receipt.get("asset_reservation_released") == true
		and second_receipt.get("asset_release_amount") == _assets("life", 1)
		and second_receipt.get("normal_card_destination") == "discard"
		and second_receipt.get("action_slot_refunded") == false
		and second_receipt.get("target_reselected") == false,
		"later warehouse contention uses full-refund discard fizzle semantics"
	)


func _test_upgrade_repair_and_solar() -> void:
	var occupied := Core.build_occupied_slot(
		"region.004",
		3,
		"warehouse",
		"energy",
		2,
		"facility.warehouse.energy.1",
		4,
		"player.0",
		1,
		2,
		150,
		"dark"
	)
	var repair := Core.build_repair_action(
		"action.repair",
		"card.warehouse.energy.repair",
		"player.0",
		0,
		occupied,
		_assets("energy", 1),
		"standard",
		1
	)
	var repaired_state := Core.lock_batch(
		"batch.repair",
		["player.0"],
		["player.0"],
		{"player.0": [repair]},
		[occupied]
	)
	var repaired_result := Core.resolve_next(repaired_state)
	var repaired_slot := _only_slot(
		repaired_result.get("state", {}) as Dictionary
	)
	_expect(
		repaired_slot.get("damage_points") == 50
		and repaired_slot.get("damage_revision") == 3,
		"rank-I repair removes one hundred damage without changing rank"
	)
	var upgrade := Core.build_upgrade_action(
		"action.upgrade",
		"card.warehouse.energy.rank2",
		"player.0",
		0,
		repaired_slot,
		_assets("energy", 2),
		"standard",
		2
	)
	var upgraded_state := Core.lock_batch(
		"batch.upgrade",
		["player.0"],
		["player.0"],
		{"player.0": [upgrade]},
		[repaired_slot]
	)
	var upgraded_result := Core.resolve_next(upgraded_state)
	var upgraded_slot := _only_slot(
		upgraded_result.get("state", {}) as Dictionary
	)
	_expect(
		upgraded_slot.get("rank") == 2
		and upgraded_slot.get("capacity") == 400
		and upgraded_slot.get("ingress_throughput") == 100.0
		and upgraded_slot.get("egress_throughput") == 100.0,
		"warehouse upgrade refreshes the rank-II public profile"
	)
	var sunlit := Core.refresh_slot_solar_state(upgraded_slot, "sunlit")
	_expect(
		sunlit.get("capacity") == 400
		and sunlit.get("ingress_throughput") == 200.0
		and sunlit.get("egress_throughput") == 200.0
		and sunlit.get("solar_efficiency_state") == "sunlit",
		"sunlight doubles ingress and egress but never capacity"
	)


func _test_atomic_solar_refresh() -> void:
	var empty_warehouse := Core.build_empty_slot(
		"region.010",
		1,
		"warehouse",
		"commerce",
		0
	)
	var factory := Core.build_occupied_slot(
		"region.011",
		1,
		"factory",
		"industry",
		2,
		"facility.factory.industry.1",
		1,
		"player.0",
		1,
		0,
		0,
		"dark"
	)
	var warehouse := Core.build_occupied_slot(
		"region.012",
		1,
		"warehouse",
		"technology",
		3,
		"facility.warehouse.technology.1",
		2,
		"player.0",
		1,
		0,
		0,
		"dark"
	)
	var state := Core.lock_batch(
		"batch.solar.refresh",
		["player.0"],
		["player.0"],
		{"player.0": []},
		[empty_warehouse, factory, warehouse]
	)
	var original_fingerprint := str(state.get("state_fingerprint", ""))
	var original_slots := (
		state.get("facility_slots", {}) as Dictionary
	).duplicate(true)
	var refreshed := Core.refresh_warehouse_solar_states(
		state,
		{"region.012": "sunlit"}
	)
	var refreshed_slots := refreshed.get("facility_slots", {}) as Dictionary
	var warehouse_slot_id := str(warehouse.get("slot_id", ""))
	var public_projection := Core.public_projection(refreshed)
	var public_warehouse := _public_slot(
		public_projection,
		warehouse_slot_id
	)
	_expect(
		Core.validation_report(refreshed).get("valid") == true
		and refreshed.get("revision") == 2
		and refreshed.get("warehouse_solar_refresh_count") == 1
		and str(refreshed.get("state_fingerprint", "")) != original_fingerprint,
		"atomic solar refresh advances revision and reseals authoritative state"
	)
	_expect(
		refreshed_slots.get(str(empty_warehouse.get("slot_id", "")))
		== original_slots.get(str(empty_warehouse.get("slot_id", "")))
		and refreshed_slots.get(str(factory.get("slot_id", "")))
		== original_slots.get(str(factory.get("slot_id", ""))),
		"solar refresh leaves empty and nonwarehouse slots unchanged"
	)
	_expect(
		public_projection.get("state_revision") == 2
		and public_warehouse.get("solar_efficiency_state") == "sunlit"
		and public_warehouse.get("capacity") == 200
		and public_warehouse.get("ingress_throughput") == 100
		and public_warehouse.get("egress_throughput") == 100,
		"current public projection immediately reflects geometric warehouse solar state"
	)
	var next_slots: Array = []
	for slot_variant in refreshed_slots.values():
		next_slots.append((slot_variant as Dictionary).duplicate(true))
	var next_state := Core.lock_batch(
		"batch.solar.next",
		["player.0"],
		["player.0"],
		{"player.0": []},
		next_slots
	)
	var next_public_warehouse := _public_slot(
		Core.public_projection(next_state),
		warehouse_slot_id
	)
	_expect(
		Core.validation_report(next_state).get("valid") == true
		and next_public_warehouse.get("solar_efficiency_state") == "sunlit"
		and next_public_warehouse.get("ingress_throughput") == 100,
		"next batch receives refreshed warehouse solar facts"
	)
	var rejected := Core.refresh_warehouse_solar_states(
		state,
		{"region.012": "twilight"}
	)
	_expect(
		rejected.is_empty()
		and state.get("state_fingerprint") == original_fingerprint,
		"invalid solar map is rejected without mutating input state"
	)


func _test_dbg_merge_and_privacy() -> void:
	var definitions := WarehouseCards.standard_l1_definitions()
	_expect(definitions.size() == 6, "warehouse catalog returns six L1 definitions")
	var life_id := "facility.warehouse.life.rank_1"
	var purchase := WarehouseCards.purchase_to_discard_contract(
		life_id,
		"track.card.0001",
		"receipt.purchase.0001"
	)
	_expect(
		purchase.get("accepted") == true
		and purchase.get("destination_zone") == "discard"
		and purchase.get("available_for_immediate_draw") == false
		and purchase.get("dbg_draw_allowed_after_normal_reshuffle") == true,
		"warehouse purchase enters discard before normal DBG draw"
	)
	var draw := WarehouseCards.drawn_card_contract({
		"instance_id": "card.player0.warehouse.life.1",
		"definition_id": life_id,
	})
	_expect(draw.get("valid") == true, "warehouse card is valid after DBG draw")
	var merge := WarehouseCards.optional_merge(life_id, life_id)
	_expect(
		merge.get("accepted") == true
		and merge.get("automatic") == false
		and merge.get("output_definition_id")
		== "facility.warehouse.life.rank_2",
		"same-color same-rank warehouses merge only by explicit choice"
	)
	var slot := Core.build_occupied_slot(
		"region.009",
		1,
		"warehouse",
		"shipping",
		1,
		"facility.warehouse.shipping.1",
		1,
		"player.2",
		1,
		0,
		0,
		"sunlit"
	)
	var projection := WarehouseRuntime.public_projection(slot)
	var privacy := WarehouseRuntime.privacy_report(projection)
	_expect(
		privacy.get("valid") == true
		and privacy.get("hidden_info_field_count") == 0
		and projection.get("private_stock_included") == false
		and projection.get("private_logistics_included") == false
		and not projection.has("warehouse_stock")
		and not projection.has("inventory")
		and not projection.has("logistics_plan"),
		"public warehouse projection excludes stock and private logistics"
	)


func _public_slot(projection: Dictionary, slot_id: String) -> Dictionary:
	for slot_variant in projection.get("public_facility_slots", []) as Array:
		if (
			slot_variant is Dictionary
			and (slot_variant as Dictionary).get("slot_id") == slot_id
		):
			return (slot_variant as Dictionary).duplicate(true)
	return {}


func _only_slot(state: Dictionary) -> Dictionary:
	var slots := state.get("facility_slots", {}) as Dictionary
	if slots.size() != 1:
		return {}
	return (slots.values()[0] as Dictionary).duplicate(true)


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


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V074_WAREHOUSE_RUNTIME_TEST|PASS|checks=%d" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("V074_WAREHOUSE_RUNTIME_TEST|FAIL|%s" % failure)
	print(
		"V074_WAREHOUSE_RUNTIME_TEST|FAIL|checks=%d|failures=%d"
		% [_checks, _failures.size()]
	)
	quit(1)
