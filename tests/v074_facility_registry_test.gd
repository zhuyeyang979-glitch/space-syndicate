extends SceneTree

const FacilityTypes := preload(
	"res://scripts/v074/facility/v074_facility_type_registry.gd"
)
const FacilitySlots := preload(
	"res://scripts/v074/facility/v074_facility_slot_registry.gd"
)
const CardDefinitions := preload(
	"res://scripts/v074/facility/v074_card_definition_registry.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_facility_type_registry()
	_test_dynamic_slot_counts()
	_test_card_definition_registry()
	_finish()


func _test_facility_type_registry() -> void:
	var report := FacilityTypes.validation_report()
	_expect(bool(report.get("valid", false)), "facility registry validates")
	_expect(
		FacilityTypes.REGISTERED_FACILITY_TYPES
		== ["factory", "market", "warehouse"],
		"complete facility registry includes warehouse"
	)
	_expect(
		FacilityTypes.STARTER_FACILITY_TYPES == ["factory", "market"],
		"starter subset remains factory and market"
	)
	_expect(
		FacilityTypes.STANDARD_TRACK_FACILITY_TYPES
		== ["factory", "market", "warehouse"],
		"standard track includes all three facility types"
	)
	_expect(
		FacilityTypes.facility_slot_count_per_region() == 18,
		"three types times six industries yields eighteen slots"
	)
	_expect(
		FacilityTypes.commercial_art_key("warehouse")
		== "model.facility.warehouse.base",
		"warehouse resolves the stable Commercial Art key"
	)


func _test_dynamic_slot_counts() -> void:
	var expected := {
		6: 108,
		8: 144,
		12: 216,
		16: 288,
		20: 360,
		24: 432,
		30: 540,
	}
	for region_count_variant in expected.keys():
		var region_count := int(region_count_variant)
		var region_ids: Array[String] = []
		for index in range(region_count):
			region_ids.append("region.%03d" % index)
		var slots := FacilitySlots.build_slots(region_ids)
		var report := FacilitySlots.validation_report(region_ids, slots)
		_expect(
			slots.size() == int(expected.get(region_count, -1)),
			"%d regions receive the expected slot count" % region_count
		)
		_expect(
			bool(report.get("valid", false)),
			"%d-region slot registry validates" % region_count
		)


func _test_card_definition_registry() -> void:
	var starters := CardDefinitions.starter_definitions()
	var track_ids := CardDefinitions.normal_track_supply_definition_ids()
	var warehouse_l1 := CardDefinitions.warehouse_standard_l1_definitions()
	_expect(starters.size() == 12, "starter deck remains exactly twelve cards")
	var starter_warehouse_count := 0
	for starter_variant in starters:
		var starter := starter_variant as Dictionary
		if str(starter.get("card_type", "")) == "warehouse":
			starter_warehouse_count += 1
	_expect(
		starter_warehouse_count == 0,
		"starter deck contains no warehouse"
	)
	_expect(track_ids.size() == 18, "normal track supply has three types by six colors")
	_expect(warehouse_l1.size() == 6, "warehouse L1 definition coverage is six of six")
	for card_variant in warehouse_l1:
		var card := card_variant as Dictionary
		_expect(
			card.get("origin_class") == "standard"
			and card.get("level") == 1
			and card.get("primary_asset_cost") == 1
			and card.get("track_spawn_allowed") == true
			and card.get("purchase_allowed") == true,
			"warehouse L1 is a paid standard track definition"
		)
		_expect(
			CardDefinitions.definition_error(card).is_empty(),
			"warehouse L1 satisfies the V072-compatible definition contract"
		)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V074_FACILITY_REGISTRY_TEST|PASS|checks=%d" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("V074_FACILITY_REGISTRY_TEST|FAIL|%s" % failure)
	print(
		"V074_FACILITY_REGISTRY_TEST|FAIL|checks=%d|failures=%d"
		% [_checks, _failures.size()]
	)
	quit(1)
