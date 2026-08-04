extends SceneTree

const Adapter := preload(
	"res://scripts/v074/ai/v074_dynamic_map_ai_observation_adapter.gd"
)
const Fixture := preload(
	"res://tests/v074_ai_dynamic_map_fixture.gd"
)

const QUERY_SAMPLE_COUNT := 10000
const BUILD_SAMPLE_COUNT := 40
const QUERY_P95_TARGET_MS := 16.7

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var sources := Fixture.build_sources(30)
	var adapter := Adapter.new()
	var observation := _adapt(adapter, sources)
	_check(not observation.is_empty(), "30-region observation accepted")
	var definition_id := "facility.warehouse.shipping.rank_1"
	for warmup in range(200):
		adapter.indexed_legal_targets_for_card(definition_id)
	var query_samples: Array[float] = []
	for sample_index in range(QUERY_SAMPLE_COUNT):
		var started := Time.get_ticks_usec()
		var targets := adapter.indexed_legal_targets_for_card(
			definition_id
		)
		var elapsed_ms := (
			float(Time.get_ticks_usec() - started) / 1000.0
		)
		query_samples.append(elapsed_ms)
		if targets.size() != 1:
			_failures.append("query returned wrong target count")
			break
	var build_samples: Array[float] = []
	for sample_index in range(BUILD_SAMPLE_COUNT):
		var build_adapter := Adapter.new()
		var started := Time.get_ticks_usec()
		var built := _adapt(build_adapter, sources)
		build_samples.append(
			float(Time.get_ticks_usec() - started) / 1000.0
		)
		if built.is_empty():
			_failures.append("observation build rejected")
			break
	var query_p95 := _percentile(query_samples, 0.95)
	var build_p95 := _percentile(build_samples, 0.95)
	_check(
		query_p95 <= QUERY_P95_TARGET_MS,
		"30-region indexed legal target p95 within 16.7ms"
	)
	var counters := adapter.validation_counters()
	_check(
		int(counters.get("query_full_slot_scan_count", -1)) == 0,
		"query path has zero full-slot scans"
	)
	_check(
		int(adapter.debug_snapshot().get(
			"indexed_facility_slot_count",
			-1
		)) == 540,
		"30-region observation indexed 540 slots"
	)
	var passed := _failures.is_empty()
	print(
		"V074_AI_DYNAMIC_MAP_PERFORMANCE_TEST"
		+ "|status=%s|passed=%d|total=%d" % [
			"PASS" if passed else "FAIL",
			_checks - _failures.size(),
			_checks,
		]
		+ "|AI_TARGET_QUERY_30_REGION_P95_MS=%.6f" % query_p95
		+ "|AI_OBSERVATION_BUILD_30_REGION_P95_MS=%.6f" % build_p95
		+ "|query_samples=%d|build_samples=%d|details=%s" % [
			query_samples.size(),
			build_samples.size(),
			JSON.stringify(_failures),
		]
	)
	quit(0 if passed else 1)


func _adapt(adapter: RefCounted, sources: Dictionary) -> Dictionary:
	return adapter.adapt(
		"player.1",
		sources.get("map_receipt", {}),
		sources.get("public_facilities", {}),
		sources.get("legal_targets", {}),
		sources.get("own_private_facts", {})
	)


func _percentile(samples: Array[float], percentile: float) -> float:
	if samples.is_empty():
		return INF
	samples.sort()
	var index := clampi(
		int(ceil(percentile * float(samples.size()))) - 1,
		0,
		samples.size() - 1
	)
	return samples[index]


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)