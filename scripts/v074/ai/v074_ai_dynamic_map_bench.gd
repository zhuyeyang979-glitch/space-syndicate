extends Control

const Adapter := preload(
	"res://scripts/v074/ai/v074_dynamic_map_ai_observation_adapter.gd"
)
const Fixture := preload(
	"res://tests/v074_ai_dynamic_map_fixture.gd"
)

const QUERY_SAMPLE_COUNT := 5000

@onready var status_label: Label = %Status
@onready var map_label: Label = %MapSummary
@onready var index_label: Label = %IndexSummary
@onready var performance_label: Label = %PerformanceSummary
@onready var privacy_label: Label = %PrivacySummary


func _ready() -> void:
	call_deferred("_run_bench")


func _run_bench() -> void:
	var sources := Fixture.build_sources(30)
	var source_before := Fixture.source_fingerprint(sources)
	var adapter := Adapter.new()
	var observation := adapter.adapt(
		"player.1",
		sources.get("map_receipt", {}),
		sources.get("public_facilities", {}),
		sources.get("legal_targets", {}),
		sources.get("own_private_facts", {})
	)
	var validation := Adapter.validation_report(observation)
	var query_samples: Array[float] = []
	var definition_id := "facility.warehouse.shipping.rank_1"
	if not observation.is_empty():
		for warmup in range(100):
			adapter.indexed_legal_targets_for_card(definition_id)
		for sample_index in range(QUERY_SAMPLE_COUNT):
			var started := Time.get_ticks_usec()
			adapter.indexed_legal_targets_for_card(definition_id)
			query_samples.append(
				float(Time.get_ticks_usec() - started) / 1000.0
			)
	var p95_ms := _percentile(query_samples, 0.95)
	var debug := adapter.debug_snapshot()
	var source_unchanged := (
		Fixture.source_fingerprint(sources) == source_before
	)
	var warehouse_targets := adapter.indexed_legal_targets_for_card(
		definition_id
	)
	var passed := not observation.is_empty() 		and bool(validation.get("valid", false)) 		and int(debug.get("indexed_region_count", 0)) == 30 		and int(debug.get("indexed_facility_slot_count", 0)) == 540 		and warehouse_targets.size() == 1 		and int(debug.get("query_full_slot_scan_count", -1)) == 0 		and source_unchanged 		and p95_ms <= 16.7
	status_label.text = (
		"GREEN - read-only indexed observation"
		if passed
		else "FAILED - inspect MCP console"
	)
	status_label.modulate = (
		Color(0.35, 0.92, 0.68)
		if passed
		else Color(1.0, 0.42, 0.42)
	)
	map_label.text = "30 dynamic regions | land + ocean | connected adjacency"
	index_label.text = (
		"540 public slots | factory + market + warehouse"
		+ " | warehouse target=%d" % warehouse_targets.size()
	)
	performance_label.text = (
		"Indexed legal-target query p95 %.6f ms (%d samples)"
		% [p95_ms, query_samples.size()]
	)
	privacy_label.text = (
		"Source unchanged=%s | full-slot query scans=%d"
		% [
			str(source_unchanged),
			int(debug.get("query_full_slot_scan_count", -1)),
		]
	)
	print(
		"V074_AI_DYNAMIC_MAP_BENCH"
		+ "|status=%s|regions=30|slots=540" % (
			"PASS" if passed else "FAIL"
		)
		+ "|warehouse_targets=%d" % warehouse_targets.size()
		+ "|AI_TARGET_QUERY_30_REGION_P95_MS=%.6f" % p95_ms
		+ "|query_samples=%d|source_unchanged=%s" % [
			query_samples.size(),
			str(source_unchanged),
		]
		+ "|query_full_slot_scan_count=%d" % int(debug.get(
			"query_full_slot_scan_count",
			-1
		))
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