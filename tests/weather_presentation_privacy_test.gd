extends SceneTree

const FORECAST_VIEW_MODEL = preload("res://scripts/viewmodels/weather_forecast_view_model.gd")
const TELEMETRY_BUFFER = preload("res://scripts/ui/weather/weather_telemetry_buffer.gd")
const BENCH = preload("res://scripts/tools/weather_presentation_v1_bench.gd")

const PRIVATE_KEYS := ["source", "card_id", "player", "owner", "cash", "hand", "discard", "ai", "save", "camera"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := run_checks()
	for failure: String in failures:
		push_error(failure)
	if failures.is_empty():
		print("WEATHER_PRESENTATION_PRIVACY_PASS")
	quit(0 if failures.is_empty() else 1)


static func run_checks() -> Array[String]:
	var failures: Array[String] = []
	var forecast_vm := FORECAST_VIEW_MODEL.new()
	for private_key: String in PRIVATE_KEYS:
		var top_level := BENCH.fixture_source("full")
		top_level[private_key] = "private_sentinel"
		_expect(forecast_vm.compose(top_level).is_empty(), "forecast accepted top-level private key %s" % private_key, failures)
		var nested := BENCH.fixture_source("full")
		nested["events"][0][private_key] = "private_sentinel"
		_expect(forecast_vm.compose(nested).is_empty(), "forecast accepted nested private key %s" % private_key, failures)

	var private_value := BENCH.fixture_source("full")
	private_value["events"][0]["counterplay_hint"] = "private_sentinel"
	_expect(forecast_vm.compose(private_value).is_empty(), "forecast accepted a private sentinel value", failures)

	var valid_view := forecast_vm.compose(BENCH.fixture_source("full"))
	_expect(not valid_view.is_empty(), "valid fixture failed privacy setup", failures)
	_expect(not _contains_private_key(valid_view), "public forecast output contains a private key", failures)
	_expect(not JSON.stringify(valid_view).contains("private_sentinel"), "public forecast output leaked a sentinel", failures)

	var telemetry := TELEMETRY_BUFFER.new(3)
	for index: int in range(4):
		var event := _telemetry_event()
		event["world_effective_us"] += index
		_expect(telemetry.record_event(event), "valid telemetry event %d was rejected: %s" % [index, telemetry.get_last_error()], failures)
	var snapshot := telemetry.snapshot()
	_expect(snapshot["capacity"] == 3, "telemetry capacity mismatch", failures)
	_expect(snapshot["count"] == 3, "telemetry ring count mismatch", failures)
	_expect(snapshot["dropped_count"] == 1, "telemetry did not report ring eviction", failures)
	_expect(snapshot["events"][0]["sequence"] == 2, "telemetry ring did not evict oldest event", failures)

	for private_key: String in PRIVATE_KEYS + ["text", "message"]:
		var private_event := _telemetry_event()
		private_event[private_key] = "private_sentinel"
		_expect(not telemetry.record_event(private_event), "telemetry accepted private key %s" % private_key, failures)
	var arbitrary_enum := _telemetry_event()
	arbitrary_enum["event_type"] = "custom_free_text"
	_expect(not telemetry.record_event(arbitrary_enum), "telemetry accepted arbitrary event text", failures)
	_expect(not telemetry.has_method("upload") and not telemetry.has_method("save") and not telemetry.has_method("write_file"), "telemetry exposes persistence or upload API", failures)
	return failures


static func _telemetry_event() -> Dictionary:
	return {
		"schema_version": "weather_telemetry_event.v1",
		"event_type": "forecast_rendered",
		"world_effective_us": 9_876_543_210,
		"surface": "forecast_strip",
		"definition_id": "ion_storm",
		"phase": "active",
		"region_index": 0,
		"source_revision": 42,
		"motion_mode": "reduced",
		"input_kind": "none",
		"result": "shown",
	}


static func _contains_private_key(value: Variant) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		for raw_key: Variant in (value as Dictionary).keys():
			var key := str(raw_key).to_lower()
			if key != "source_revision" and key != "source_type" and PRIVATE_KEYS.has(key):
				return true
			if _contains_private_key((value as Dictionary)[raw_key]):
				return true
	elif typeof(value) == TYPE_ARRAY:
		for item: Variant in value as Array:
			if _contains_private_key(item):
				return true
	return false


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
