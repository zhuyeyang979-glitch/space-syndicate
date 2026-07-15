extends SceneTree

const SERVICE_SCENE := preload("res://scenes/runtime/WeatherTelemetryRuntimeService.tscn")
const BENCH_SCENE := preload("res://scenes/tools/WeatherBalanceReportV1Bench.tscn")
const SERVICE_SCRIPT_PATH := "res://scripts/runtime/weather_telemetry_runtime_service.gd"
const REPORT_PATH := "res://docs/weather_v1_balance_report.md"

var _checks := 0
var _failures: Array[String] = []
var _service: WeatherTelemetryRuntimeService


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_service = SERVICE_SCENE.instantiate() as WeatherTelemetryRuntimeService
	root.add_child(_service)
	await process_frame
	_case_schema_and_privacy_rejection()
	_case_aggregation_math()
	_case_live_session_aggregation()
	_case_capacity_and_ordering()
	_case_local_only_boundaries()
	await _case_report_generation()
	print("WEATHER_TELEMETRY_RUNTIME_SERVICE_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	_service.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)


func _case_schema_and_privacy_rejection() -> void:
	_service.clear()
	var schema := _service.event_field_schema()
	_expect((schema.get("exact_keys", []) as Array).size() == 13, "event schema has one exact 13-field allowlist")
	_expect(schema.get("event_types", []) == ["forecast", "activation", "end"], "event types cover forecast, activation, and end")
	_expect(schema.get("response_categories", []) == ["route_after_forecast", "buy_after_forecast", "build_after_forecast", "play_after_forecast", "no_response_after_forecast"], "response categories distinguish aggregate actions from no response")
	_expect(_service.record_event(_forecast_event("ion_storm", 2, 30.0)), "valid forecast event is accepted")
	_expect(_service.record_event(_activation_event("ion_storm", 2, 45.0)), "valid activation event is accepted")
	_expect(_service.record_event(_end_event("ion_storm", 2, 30.0, 45.0, 10.0, 12.0, -4.0, "route_after_forecast", true, 0.0, 80.0)), "valid completed observation is accepted")

	for private_key in ["player_id", "player_index", "owner", "exact_cash", "hand", "discard", "card_identity", "hidden_monster_target", "monster_target", "monster_weights", "monster_target_weights", "ai_plan", "save_state", "camera_zoom"]:
		var private_key_event := _end_event("ion_storm", 2, 30.0, 45.0, 10.0, 0.0, 0.0, "play_after_forecast", false, 0.0, 0.0)
		private_key_event[private_key] = "PRIVATE_SENTINEL"
		_expect(not _service.record_event(private_key_event) and _service.get_last_error() == "private_key", "private key %s is rejected before storage" % private_key)
	var private_value_event := _end_event("ion_storm", 2, 30.0, 45.0, 10.0, 0.0, 0.0, "play_after_forecast", false, 0.0, 0.0)
	private_value_event["player_response_category"] = "player_7"
	_expect(not _service.record_event(private_value_event) and _service.get_last_error() == "private_value", "private identity-like string value is rejected")
	var extra_public_key := _end_event("ion_storm", 2, 30.0, 45.0, 10.0, 0.0, 0.0, "buy_after_forecast", false, 0.0, 0.0)
	extra_public_key["notes"] = "aggregate"
	_expect(not _service.record_event(extra_public_key) and _service.get_last_error() == "event_keys", "unknown non-private keys are rejected by exact schema")
	var unknown_definition := _forecast_event("unknown_weather", 2, 30.0)
	_expect(not _service.record_event(unknown_definition) and _service.get_last_error() == "definition_id", "unknown weather definition is rejected")
	var out_of_bounds_region := _forecast_event("ion_storm", 64, 30.0)
	_expect(not _service.record_event(out_of_bounds_region) and _service.get_last_error() == "region_index_range", "region domain is bounded")
	var scoped_forecast := _forecast_event("ion_storm", 2, 30.0)
	scoped_forecast["route_revenue_delta_percent"] = 1.0
	_expect(not _service.record_event(scoped_forecast) and _service.get_last_error() == "forecast_payload_scope", "forecast record cannot smuggle end metrics")
	var serialized_log := JSON.stringify(_service.recent_events_snapshot())
	_expect(not serialized_log.contains("PRIVATE_SENTINEL") and not serialized_log.contains("player_7"), "rejected private data never enters local log")


func _case_aggregation_math() -> void:
	_service.clear()
	_expect(_service.record_event(_end_event("ion_storm", 4, 30.0, 60.0, 10.0, 10.0, -20.0, "route_after_forecast", true, 1.0, -60.0)), "first math observation accepted")
	_expect(_service.record_event(_end_event("ion_storm", 4, 50.0, 80.0, 10.0, 20.0, -10.0, "buy_after_forecast", false, 2.0, -40.0)), "second math observation accepted")
	var aggregate := _service.aggregate_snapshot()
	var rows: Array = aggregate.get("definitions", []) as Array
	var ids: Array = []
	for row_variant in rows:
		ids.append(str((row_variant as Dictionary).get("definition_id", "")))
	_expect(rows.size() == 6 and ids == WeatherTelemetryRuntimeService.DEFINITION_IDS, "aggregate always exposes exactly six definitions in contract order")
	var ion := rows[0] as Dictionary
	var responses: Dictionary = ion.get("player_response_counts", {}) as Dictionary
	_expect(int(ion.get("event_count", 0)) == 2, "completed event count aggregates by definition")
	_expect(_near(float(ion.get("average_forecast_duration_seconds", 0.0)), 40.0) and _near(float(ion.get("average_active_duration_seconds", 0.0)), 70.0) and _near(float(ion.get("average_fade_duration_seconds", 0.0)), 10.0), "duration averages are correct")
	_expect(_near(float(ion.get("average_product_price_delta_percent", 0.0)), 15.0) and _near(float(ion.get("average_route_revenue_delta_percent", 0.0)), -15.0), "price and route-revenue averages are correct")
	_expect(int(responses.get("route_after_forecast", 0)) == 1 and int(responses.get("buy_after_forecast", 0)) == 1 and int(responses.get("build_after_forecast", 0)) == 0 and int(responses.get("play_after_forecast", 0)) == 0, "response categories aggregate without identity")
	_expect(int(ion.get("monster_target_changed_count", 0)) == 1 and _near(float(ion.get("monster_target_changed_rate", 0.0)), 0.5), "monster decision influence stores only count and rate")
	_expect(_near(float(ion.get("region_damage_total", 0.0)), 3.0), "region damage sums correctly")
	_expect(_near(float(ion.get("estimated_economic_delta_total", 0.0)), -100.0) and _near(float(ion.get("average_estimated_economic_delta", 0.0)), -50.0), "estimated aggregate economic delta math is correct")
	var regions: Array = ion.get("regions", []) as Array
	_expect(regions.size() == 1 and int((regions[0] as Dictionary).get("region_index", -1)) == 4 and int((regions[0] as Dictionary).get("event_count", 0)) == 2, "same metrics aggregate per public region")
	_expect(int((rows[1] as Dictionary).get("event_count", -1)) == 0 and (rows[1] as Dictionary).get("regions", []) == [], "definitions without samples retain deterministic zero rows")


func _case_live_session_aggregation() -> void:
	_service.clear()
	_expect(_service.begin_weather_session(17, "crystal_dust_storm", [3], 35.0, 55.0, 10.0), "live session accepts public lifecycle identity")
	_expect(_service.begin_weather_session(17, "crystal_dust_storm", [3], 35.0, 55.0, 10.0), "same live session begin is idempotent")
	_expect(_service.activate_weather_session(17), "live session activation is recorded")
	_expect(_service.observe_public_metric(17, "product_price_delta_percent", 20.0) \
		and _service.observe_public_metric(17, "product_price_delta_percent", 10.0) \
		and _service.observe_public_metric(17, "route_revenue_delta_percent", -12.0) \
		and _service.observe_public_metric(17, "region_damage", 0.75) \
		and _service.observe_public_metric(17, "estimated_economic_delta", -40.0), "live session accepts only bounded public metrics")
	_expect(_service.record_public_response(3, "route_after_forecast") == 1 and _service.mark_monster_target_changed(17), "live session records anonymous response and monster-decision change")
	_expect(_service.finish_weather_session(17), "live session emits a completed end record")
	var log := _service.recent_events_snapshot()
	var encoded := JSON.stringify(log)
	_expect(int(log.get("count", 0)) == 3 \
		and not encoded.contains("event_id") \
		and not encoded.contains("player_index") \
		and not encoded.contains("player_id") \
		and not encoded.contains("owner"), "live lifecycle log remains public and identity-free")
	var rows: Array = (_service.aggregate_snapshot().get("definitions", []) as Array)
	var crystal := rows[3] as Dictionary
	_expect(int(crystal.get("event_count", 0)) == 1 \
		and _near(float(crystal.get("average_product_price_delta_percent", 0.0)), 15.0) \
		and _near(float(crystal.get("average_route_revenue_delta_percent", 0.0)), -12.0) \
		and _near(float(crystal.get("region_damage_total", 0.0)), 0.75) \
		and _near(float(crystal.get("estimated_economic_delta_total", 0.0)), -40.0) \
		and int(crystal.get("monster_target_changed_count", 0)) == 1, "live session aggregates sampled percentages and additive outcomes correctly")


func _case_capacity_and_ordering() -> void:
	_service.clear()
	_service.event_capacity = 0
	_expect(_service.event_capacity == 1, "direct capacity assignment clamps to hard minimum")
	_service.event_capacity = 99_999
	_expect(_service.event_capacity == WeatherTelemetryRuntimeService.MAX_EVENT_CAPACITY, "direct capacity assignment clamps to hard maximum")
	_expect(_service.configure_capacity(3) == 3, "event log accepts a small bounded capacity")
	for index in range(4):
		_expect(_service.record_event(_forecast_event("gravity_tide", index, 45.0)), "bounded forecast %d accepted" % index)
	var log_snapshot := _service.recent_events_snapshot()
	var events: Array = log_snapshot.get("events", []) as Array
	_expect(int(log_snapshot.get("count", 0)) == 3 and int(log_snapshot.get("dropped_count", 0)) == 1, "event log evicts oldest record at capacity")
	_expect(int((events[0] as Dictionary).get("sequence", 0)) == 2 and int((events[2] as Dictionary).get("sequence", 0)) == 4, "retained lifecycle log ordering is deterministic")
	_expect(_service.configure_capacity(99_999) == WeatherTelemetryRuntimeService.MAX_EVENT_CAPACITY, "configured capacity clamps to hard maximum")
	var debug := _service.debug_snapshot()
	_expect(int(debug.get("definition_capacity", 0)) == 6 and int(debug.get("region_domain_size", 0)) == 64, "aggregate key domains are fixed and bounded")


func _case_local_only_boundaries() -> void:
	var debug := _service.debug_snapshot()
	_expect(not bool(debug.get("authoritative", true)) and str(debug.get("storage_scope", "")) == "local_memory_only", "service declares non-authoritative local-memory scope")
	_expect(not bool(debug.get("network_enabled", true)) and not bool(debug.get("save_owner", true)), "service declares no network and no save ownership")
	_expect(not _service.has_method("to_save_data") and not _service.has_method("apply_save_data") and not _service.has_method("save") and not _service.has_method("load"), "service exposes no save owner API")
	var source := FileAccess.get_file_as_string(SERVICE_SCRIPT_PATH)
	for forbidden_token in ["HTTPRequest", "HTTPClient", "WebSocketPeer", "WebSocketMultiplayerPeer", "TCPServer", "StreamPeerTCP", "PacketPeerUDP", "FileAccess", "DirAccess", "user://"]:
		_expect(not source.contains(forbidden_token), "service source omits transport/storage token %s" % forbidden_token)
	_expect(not source.contains("func to_save_data(") and not source.contains("func apply_save_data("), "service source has no persistence API implementation")


func _case_report_generation() -> void:
	var bench := BENCH_SCENE.instantiate()
	bench.set("auto_run", false)
	root.add_child(bench)
	await process_frame
	var first_result := bench.call("run_bench", true) as Dictionary
	var first_report := str(first_result.get("report_markdown", ""))
	var second_result := bench.call("run_bench", false) as Dictionary
	var second_report := str(second_result.get("report_markdown", ""))
	var aggregates: Dictionary = first_result.get("aggregates", {}) as Dictionary
	var rows: Array = aggregates.get("definitions", []) as Array
	var expected_forecast := [30.0, 45.0, 40.0, 35.0, 60.0, 30.0]
	var expected_active := [45.0, 75.0, 70.0, 55.0, 90.0, 45.0]
	var expected_economic := [480.0, -660.0, 270.0, -210.0, -780.0, -330.0]
	var expected_monster_changes := [2, 1, 2, 1, 2, 3]
	_expect(str(first_result.get("status", "")) == "PASS" and int(first_result.get("accepted_lifecycle_events", 0)) == 54 and int(first_result.get("completed_samples", 0)) == 18, "bench simulates all lifecycle stages for 18 completed samples")
	_expect(rows.size() == 6, "generated report source contains exactly six definition rows")
	for index in range(WeatherTelemetryRuntimeService.DEFINITION_IDS.size()):
		var row := rows[index] as Dictionary
		_expect(str(row.get("definition_id", "")) == str(WeatherTelemetryRuntimeService.DEFINITION_IDS[index]), "report row %d follows deterministic definition order" % index)
		_expect(int(row.get("event_count", 0)) == 3 \
			and _near(float(row.get("average_forecast_duration_seconds", 0.0)), float(expected_forecast[index])) \
			and _near(float(row.get("average_active_duration_seconds", 0.0)), float(expected_active[index])) \
			and _near(float(row.get("average_fade_duration_seconds", 0.0)), 10.0) \
			and _near(float(row.get("estimated_economic_delta_total", 0.0)), float(expected_economic[index])) \
			and int(row.get("monster_target_changed_count", -1)) == int(expected_monster_changes[index]), "report row %d contains expected sample count, durations, loss/delta, and monster influence" % index)
	_expect(first_report == second_report, "report Markdown is deterministic across runs")
	_expect(first_report.contains("deterministic sample/simulation evidence") and first_report.contains("not live production telemetry"), "report labels evidence as simulation rather than production telemetry")
	_expect(first_report.contains("Simulated loss") and first_report.contains("Hit regions") and first_report.contains("Monster target changed"), "report includes losses, hit regions, and monster-decision influence")
	_expect(FileAccess.file_exists(REPORT_PATH) and FileAccess.get_file_as_string(REPORT_PATH) == first_report, "bench writes the actual deterministic Markdown artifact")
	_expect(not first_report.contains("PRIVATE_SENTINEL") and not first_report.contains("player_7"), "generated report contains no rejected private values")
	bench.queue_free()
	await process_frame


func _forecast_event(definition_id: String, region_index: int, duration: float) -> Dictionary:
	return _base_event("forecast", definition_id, region_index, duration, 0.0, 0.0)


func _activation_event(definition_id: String, region_index: int, duration: float) -> Dictionary:
	return _base_event("activation", definition_id, region_index, 0.0, duration, 0.0)


func _base_event(event_type: String, definition_id: String, region_index: int, forecast_duration: float, active_duration: float, fade_duration: float) -> Dictionary:
	return {
		"schema_version": WeatherTelemetryRuntimeService.EVENT_SCHEMA,
		"event_type": event_type,
		"definition_id": definition_id,
		"region_index": region_index,
		"forecast_duration_seconds": forecast_duration,
		"active_duration_seconds": active_duration,
		"fade_duration_seconds": fade_duration,
		"product_price_delta_percent": 0.0,
		"route_revenue_delta_percent": 0.0,
		"player_response_category": WeatherTelemetryRuntimeService.NOT_APPLICABLE_RESPONSE,
		"monster_target_changed": false,
		"region_damage": 0.0,
		"estimated_economic_delta": 0.0,
	}


func _end_event(
	definition_id: String,
	region_index: int,
	forecast_duration: float,
	active_duration: float,
	fade_duration: float,
	price_delta: float,
	route_delta: float,
	response: String,
	monster_changed: bool,
	region_damage: float,
	economic_delta: float
) -> Dictionary:
	return {
		"schema_version": WeatherTelemetryRuntimeService.EVENT_SCHEMA,
		"event_type": "end",
		"definition_id": definition_id,
		"region_index": region_index,
		"forecast_duration_seconds": forecast_duration,
		"active_duration_seconds": active_duration,
		"fade_duration_seconds": fade_duration,
		"product_price_delta_percent": price_delta,
		"route_revenue_delta_percent": route_delta,
		"player_response_category": response,
		"monster_target_changed": monster_changed,
		"region_damage": region_damage,
		"estimated_economic_delta": economic_delta,
	}


func _near(actual: float, expected: float) -> bool:
	return absf(actual - expected) < 0.0001


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("WEATHER TELEMETRY: %s" % label)
