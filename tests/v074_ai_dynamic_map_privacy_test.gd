extends SceneTree

const Adapter := preload(
	"res://scripts/v074/ai/v074_dynamic_map_ai_observation_adapter.gd"
)
const Codec := preload(
	"res://scripts/v07_adapters/v07_canonical_data_codec.gd"
)
const Fixture := preload(
	"res://tests/v074_ai_dynamic_map_fixture.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_public_observation_privacy()
	_verify_forbidden_sources_fail_closed()
	var passed := _failures.is_empty()
	print(
		"V074_AI_DYNAMIC_MAP_PRIVACY_TEST"
		+ "|status=%s|passed=%d|total=%d|details=%s" % [
			"PASS" if passed else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if passed else 1)


func _verify_public_observation_privacy() -> void:
	var sources := Fixture.build_sources(30)
	var adapter := Adapter.new()
	var observation := _adapt(adapter, sources)
	_check(not observation.is_empty(), "baseline observation accepted")
	var encoded := Codec.canonical_json(observation)
	for forbidden_key in Adapter.FORBIDDEN_INFORMATION_KEYS:
		_check(
			not encoded.contains('"%s"' % forbidden_key),
			"output excludes %s" % forbidden_key
		)
	var rival_warehouse_found := false
	for slot_variant in observation.get(
		"public_facility_slots",
		[]
	) as Array:
		var slot := slot_variant as Dictionary
		if slot.get("facility_type") == "warehouse" 				and slot.get("owner_id") == "player.2":
			rival_warehouse_found = true
			_check(
				int(slot.get("public_capacity", 0)) > 0,
				"rival warehouse public capacity retained"
			)
			_check(
				int(slot.get("public_ingress_throughput", 0)) > 0,
				"rival warehouse public ingress retained"
			)
			_check(
				int(slot.get("public_egress_throughput", 0)) > 0,
				"rival warehouse public egress retained"
			)
	_check(rival_warehouse_found, "rival public warehouse observed")
	_check(
		int(adapter.debug_snapshot().get(
			"query_full_slot_scan_count",
			-1
		)) == 0,
		"privacy adaptation adds no query scan"
	)


func _verify_forbidden_sources_fail_closed() -> void:
	var cases := [
		["public warehouse stock", "public_facilities", "warehouse_stock"],
		["opponent hand", "own_private_facts", "opponent_hand"],
		["opponent targets", "legal_targets", "opponent_targets"],
		["hidden lead order", "map_receipt", "hidden_lead_order"],
		["rival plan", "legal_targets", "ai_plans"],
		["rng state", "map_receipt", "rng_state"],
		["save payload", "own_private_facts", "save_payload"],
	]
	for case_variant in cases:
		var case := case_variant as Array
		var sources := Fixture.build_sources(16)
		var source_name := str(case[1])
		var poisoned := (
			sources.get(source_name, {}) as Dictionary
		).duplicate(true)
		poisoned[str(case[2])] = {"secret": "must-not-pass"}
		sources[source_name] = poisoned
		var adapter := Adapter.new()
		var observation := _adapt(adapter, sources)
		_check(
			observation.is_empty(),
			"%s rejected" % str(case[0])
		)
		var debug := adapter.debug_snapshot()
		_check(
			str(debug.get("last_reason_code", ""))
				== "integration_source_privacy_rejected",
			"%s reason is privacy rejection" % str(case[0])
		)
		_check(
			int(debug.get("adapt_rejection_count", 0)) == 1,
			"%s counted once" % str(case[0])
		)
		_check(
			int(debug.get("validation_count", 0)) == 1
				and int(debug.get("validation_failure_count", 0)) == 1,
			"%s validation counters updated" % str(case[0])
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