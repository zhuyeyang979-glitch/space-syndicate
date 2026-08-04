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
	for region_count in [6, 8, 12, 16, 20, 24, 30]:
		_verify_region_count(region_count)
	_verify_damaged_warehouse_zero_throughput()
	_verify_empty_hand_observation()
	var passed := _failures.is_empty()
	print(
		"V074_AI_DYNAMIC_MAP_OBSERVATION_TEST"
		+ "|status=%s|passed=%d|total=%d|details=%s" % [
			"PASS" if passed else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if passed else 1)


func _verify_region_count(region_count: int) -> void:
	var sources := Fixture.build_sources(region_count)
	var source_before := Fixture.source_fingerprint(sources)
	var adapter := Adapter.new()
	var observation := adapter.adapt(
		"player.1",
		sources.get("map_receipt", {}),
		sources.get("public_facilities", {}),
		sources.get("legal_targets", {}),
		sources.get("own_private_facts", {})
	)
	_check(not observation.is_empty(), "%d observation accepted" % region_count)
	if observation.is_empty():
		return
	var validation := Adapter.validation_report(observation)
	_check(
		bool(validation.get("valid", false)),
		"%d observation validates" % region_count
	)
	_check(
		int(observation.get("region_count", -1)) == region_count,
		"%d dynamic region count" % region_count
	)
	_check(
		(observation.get("public_facility_slots", []) as Array).size()
			== region_count * 18,
		"%d complete facility slot matrix" % region_count
	)
	for facility_type in ["factory", "market", "warehouse"]:
		for industry_id in Adapter.INDUSTRY_IDS:
			_check(
				Adapter.slots_for(
					observation,
					facility_type,
					industry_id
				).size() == region_count,
				"%d indexed %s %s slots" % [
					region_count,
					facility_type,
					industry_id,
				]
			)
	for terrain_class in ["land", "ocean"]:
		_check(
			not Adapter.regions_for_terrain(
				observation,
				terrain_class
			).is_empty(),
			"%d %s regions indexed" % [region_count, terrain_class]
		)
	var indexed_terrain_count := (
		Adapter.regions_for_terrain(observation, "land").size()
		+ Adapter.regions_for_terrain(observation, "ocean").size()
	)
	_check(
		indexed_terrain_count == region_count,
		"%d every region has one terrain" % region_count
	)
	_check(
		Adapter.neighbors_for(observation, "region.000").size() == 2,
		"%d adjacency indexed" % region_count
	)
	for industry_id in Adapter.INDUSTRY_IDS:
		_check(
			Adapter.warehouse_slots_for_industry(
				observation,
				industry_id
			).size() == region_count,
			"%d warehouse %s index" % [region_count, industry_id]
		)
	_check(
		adapter.indexed_legal_targets_for_card(
			"facility.factory.life.rank_1"
		).size() == 1,
		"%d factory legal action" % region_count
	)
	_check(
		adapter.indexed_legal_targets_for_card(
			"facility.market.energy.rank_1"
		).size() == 1,
		"%d market legal action" % region_count
	)
	_check(
		adapter.indexed_legal_targets_for_card(
			"facility.warehouse.shipping.rank_1"
		).size() == 1,
		"%d warehouse repair legal action" % region_count
	)
	_check(
		adapter.indexed_legal_targets_for_card(
			"facility.warehouse.commerce.rank_1"
		).size() == 1,
		"%d warehouse build legal action" % region_count
	)
	var debug := adapter.debug_snapshot()
	_check(
		int(debug.get("indexed_facility_slot_count", -1))
			== region_count * 18,
		"%d debug indexed slot count" % region_count
	)
	_check(
		int(debug.get("query_full_slot_scan_count", -1)) == 0,
		"%d query performs no full scan" % region_count
	)
	_check(
		Fixture.source_fingerprint(sources) == source_before,
		"%d source payloads unchanged" % region_count
	)
	_check(
		not (observation.get("region_ids", []) as Array).has(
			"region.alpha"
		),
		"%d no retired alpha-zeta identity" % region_count
	)
	var detached := observation.duplicate(true)
	(detached.get("region_ids", []) as Array).clear()
	_check(
		(adapter.detached_observation().get(
			"region_ids",
			[]
		) as Array).size() == region_count,
		"%d adapter cache detached" % region_count
	)


func _verify_damaged_warehouse_zero_throughput() -> void:
	var sources := Fixture.build_sources(16)
	var facilities := (
		sources.get("public_facilities", {}) as Dictionary
	).duplicate(true)
	var slots := (
		facilities.get("public_facility_slots", []) as Array
	).duplicate(true)
	for slot_index in range(slots.size()):
		var slot := (slots[slot_index] as Dictionary).duplicate(true)
		if slot.get("region_id") == "region.002" 				and slot.get("facility_type") == "warehouse" 				and slot.get("industry_id") == "shipping":
			slot["public_ingress_throughput"] = 0
			slot["public_egress_throughput"] = 0
			slots[slot_index] = slot
			break
	facilities["public_facility_slots"] = slots
	sources["public_facilities"] = facilities
	var adapter := Adapter.new()
	var observation := adapter.adapt(
		"player.1",
		sources.get("map_receipt", {}),
		sources.get("public_facilities", {}),
		sources.get("legal_targets", {}),
		sources.get("own_private_facts", {})
	)
	_check(
		not observation.is_empty(),
		"damaged warehouse may publicly report zero throughput"
	)


func _verify_empty_hand_observation() -> void:
	var sources := Fixture.build_sources(16)
	var own_facts := (
		sources.get("own_private_facts", {}) as Dictionary
	).duplicate(true)
	own_facts["own_cards"] = []
	sources["own_private_facts"] = own_facts
	var legal_targets := (
		sources.get("legal_targets", {}) as Dictionary
	).duplicate(true)
	legal_targets["authorized_legal_actions"] = []
	sources["legal_targets"] = legal_targets
	var adapter := Adapter.new()
	var observation := adapter.adapt(
		"player.1",
		sources.get("map_receipt", {}),
		sources.get("public_facilities", {}),
		sources.get("legal_targets", {}),
		sources.get("own_private_facts", {})
	)
	_check(
		not observation.is_empty(),
		"empty hand remains a valid read-only observation"
	)
	_check(
		adapter.indexed_legal_targets_for_card(
			"facility.warehouse.shipping.rank_1"
		).is_empty(),
		"empty hand has zero indexed legal targets"
	)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)