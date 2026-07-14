extends SceneTree

const FORECAST_VIEW_MODEL = preload("res://scripts/viewmodels/weather_forecast_view_model.gd")
const OVERLAY_VIEW_MODEL = preload("res://scripts/viewmodels/weather_map_overlay_view_model.gd")
const BENCH = preload("res://scripts/tools/weather_presentation_v1_bench.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := run_checks()
	for failure: String in failures:
		push_error(failure)
	if failures.is_empty():
		print("WEATHER_PRESENTATION_VIEW_MODEL_PASS")
	quit(0 if failures.is_empty() else 1)


static func run_checks() -> Array[String]:
	var failures: Array[String] = []
	var forecast_vm := FORECAST_VIEW_MODEL.new()
	var overlay_vm := OVERLAY_VIEW_MODEL.new()
	var expected_states := {"clear": "clear", "full": "mixed", "reduced": "forecast", "off": "fading"}
	var seen_phases: Dictionary = {}
	var seen_sources: Dictionary = {}

	for fixture_id: String in ["clear", "full", "reduced", "off"]:
		var source := BENCH.fixture_source(fixture_id)
		var view := forecast_vm.compose(source)
		_expect(not view.is_empty(), "%s fixture was rejected: %s" % [fixture_id, forecast_vm.get_last_error()], failures)
		if view.is_empty():
			continue
		_expect(view["schema_version"] == "weather_forecast_view_model.v1", "%s schema mismatch" % fixture_id, failures)
		_expect(view["clock_domain"] == "world_effective", "%s clock domain mismatch" % fixture_id, failures)
		_expect(view["world_effective_us"] == source["world_effective_us"], "%s clock was recomputed" % fixture_id, failures)
		_expect(view["state"] == expected_states[fixture_id], "%s state mismatch" % fixture_id, failures)
		_expect(forecast_vm.validate_view_model(view), "%s output failed its public schema" % fixture_id, failures)
		for event_index: int in range((source["events"] as Array).size()):
			var source_event := (source["events"] as Array)[event_index] as Dictionary
			var view_event := (view["events"] as Array)[event_index] as Dictionary
			seen_phases[source_event["phase"]] = true
			seen_sources[source_event["source_type"]] = true
			_expect((view_event["effects"] as Array).size() == 3, "%s event did not expose exactly three effects" % fixture_id, failures)
			_expect(view_event["remaining_us"] == source_event["remaining_us"], "%s remaining_us was recomputed" % fixture_id, failures)
			_expect(is_equal_approx(float(view_event["intensity"]), float(source_event["intensity"])), "%s intensity was recomputed" % fixture_id, failures)
		var overlay := overlay_vm.compose(view)
		_expect(not overlay.is_empty(), "%s overlay was rejected: %s" % [fixture_id, overlay_vm.get_last_error()], failures)
		if not overlay.is_empty():
			_expect(overlay_vm.validate_view_model(overlay), "%s overlay output failed schema" % fixture_id, failures)
			_expect(overlay["world_effective_us"] == view["world_effective_us"], "%s overlay clock changed" % fixture_id, failures)
			for raw_region: Variant in overlay["regions"]:
				var region := raw_region as Dictionary
				_expect(region.has("region_index"), "%s overlay omitted region_index" % fixture_id, failures)
				_expect(not region.has("position") and not region.has("camera"), "%s overlay acquired runtime geometry" % fixture_id, failures)

	for phase: String in ["queued", "forecast", "active", "fading"]:
		_expect(seen_phases.has(phase), "phase fixture missing: %s" % phase, failures)
	for source_type: String in ["natural", "monster", "card"]:
		_expect(seen_sources.has(source_type), "source_type fixture missing: %s" % source_type, failures)

	var extra_key_source := BENCH.fixture_source("full")
	extra_key_source["unexpected"] = true
	_expect(forecast_vm.compose(extra_key_source).is_empty(), "source accepted an unknown top-level key", failures)
	var missing_key_source := BENCH.fixture_source("full")
	missing_key_source.erase("source_revision")
	_expect(forecast_vm.compose(missing_key_source).is_empty(), "source accepted a missing required key", failures)
	var bad_phase_source := BENCH.fixture_source("full")
	bad_phase_source["events"][0]["phase"] = "ended"
	_expect(forecast_vm.compose(bad_phase_source).is_empty(), "source accepted unsupported phase", failures)
	var two_effect_source := BENCH.fixture_source("full")
	two_effect_source["events"][0]["effects"].pop_back()
	_expect(forecast_vm.compose(two_effect_source).is_empty(), "source accepted fewer than three effects", failures)
	return failures


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
