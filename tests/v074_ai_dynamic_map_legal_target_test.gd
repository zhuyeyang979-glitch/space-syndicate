extends SceneTree

const Adapter := preload(
	"res://scripts/v074/ai/v074_dynamic_map_ai_observation_adapter.gd"
)
const Fixture := preload(
	"res://tests/v074_ai_dynamic_map_fixture.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_registered_facility_actions()
	_verify_mismatched_targets_fail_closed()
	_verify_index_queries_never_scan_all_slots()
	var passed := _failures.is_empty()
	print(
		"V074_AI_DYNAMIC_MAP_LEGAL_TARGET_TEST"
		+ "|status=%s|passed=%d|total=%d|details=%s" % [
			"PASS" if passed else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if passed else 1)


func _verify_registered_facility_actions() -> void:
	var sources := Fixture.build_sources(30)
	var adapter := Adapter.new()
	var observation := _adapt(adapter, sources)
	_check(not observation.is_empty(), "30-region observation accepted")
	var expectations := {
		"facility.factory.life.rank_1": [
			"factory",
			"BUILD_NEW",
			"region.000",
		],
		"facility.market.energy.rank_1": [
			"market",
			"UPGRADE_OWN",
			"region.001",
		],
		"facility.warehouse.shipping.rank_1": [
			"warehouse",
			"REPAIR_OWN",
			"region.002",
		],
		"facility.warehouse.commerce.rank_1": [
			"warehouse",
			"BUILD_NEW",
			"region.003",
		],
	}
	for definition_id in expectations:
		var targets := adapter.indexed_legal_targets_for_card(
			definition_id
		)
		_check(targets.size() == 1, "%s indexed once" % definition_id)
		if targets.is_empty():
			continue
		var target := targets[0] as Dictionary
		var expected := expectations.get(definition_id, []) as Array
		_check(
			target.get("facility_type") == expected[0],
			"%s facility type preserved" % definition_id
		)
		_check(
			target.get("action_mode") == expected[1],
			"%s action mode preserved" % definition_id
		)
		_check(
			target.get("region_id") == expected[2],
			"%s region preserved" % definition_id
		)
	_check(
		adapter.indexed_slots_for_facility(
			"warehouse",
			"shipping"
		).size() == 30,
		"warehouse shipping index covers 30 regions"
	)
	_check(
		adapter.indexed_slots_for_facility(
			"factory",
			"shipping"
		).size() == 30,
		"factory shipping index covers 30 regions"
	)
	_check(
		adapter.indexed_slots_for_facility(
			"market",
			"shipping"
		).size() == 30,
		"market shipping index covers 30 regions"
	)


func _verify_mismatched_targets_fail_closed() -> void:
	var cases := [
		["warehouse routed to market", "facility_type", "market"],
		["warehouse wrong industry", "industry_id", "life"],
		["warehouse wrong region", "region_id", "region.004"],
		["warehouse wrong slot", "target_slot_id",
			Fixture.slot_id("region.002", "market", "shipping")],
	]
	for case_variant in cases:
		var case := case_variant as Array
		var sources := Fixture.build_sources(16)
		var legal := (
			sources.get("legal_targets", {}) as Dictionary
		).duplicate(true)
		var actions := (
			legal.get("authorized_legal_actions", []) as Array
		).duplicate(true)
		var action := (actions[2] as Dictionary).duplicate(true)
		action[str(case[1])] = case[2]
		actions[2] = action
		legal["authorized_legal_actions"] = actions
		sources["legal_targets"] = legal
		var adapter := Adapter.new()
		_check(
			_adapt(adapter, sources).is_empty(),
			"%s rejected" % str(case[0])
		)
		_check(
			int(adapter.validation_counters().get(
				"adapt_rejection_count",
				0
			)) == 1,
			"%s rejection counted" % str(case[0])
		)


func _verify_index_queries_never_scan_all_slots() -> void:
	var sources := Fixture.build_sources(30)
	var adapter := Adapter.new()
	_check(
		not _adapt(adapter, sources).is_empty(),
		"performance observation accepted"
	)
	for iteration in range(10000):
		adapter.indexed_legal_targets_for_card(
			"facility.warehouse.shipping.rank_1"
		)
	var counters := adapter.validation_counters()
	_check(
		int(counters.get("indexed_legal_target_query_count", -1))
			== 10000,
		"all indexed queries counted"
	)
	_check(
		int(counters.get("query_full_slot_scan_count", -1)) == 0,
		"10000 card queries scan no facility registry"
	)


func _adapt(adapter: RefCounted, sources: Dictionary) -> Dictionary:
	return adapter.adapt(
		"player.1",
		sources.get("map_receipt", {}),
		sources.get("public_facilities", {}),
		sources.get("legal_targets", {}),
		sources.get("own_private_facts", {})
	)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)