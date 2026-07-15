extends SceneTree

const STRIP_SCENE := preload("res://scenes/ui/weather/WeatherForecastStrip.tscn")
const FORECAST_VIEW_MODEL := preload("res://scripts/viewmodels/weather_forecast_view_model.gd")
const WEATHER_BENCH := preload("res://scripts/tools/weather_presentation_v1_bench.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var strip := STRIP_SCENE.instantiate() as Control
	root.add_child(strip)
	await process_frame
	var forecast := FORECAST_VIEW_MODEL.new().compose(WEATHER_BENCH.fixture_source("full"))
	_expect(not forecast.is_empty() and bool(strip.call("set_view_model", forecast)), "real weather fixture applies to WeatherForecastStrip")
	await process_frame
	var region_buttons := strip.find_child("RegionButtons", true, false) as Container
	var initial_ids := _button_ids(region_buttons)
	var detail := strip.find_child("WeatherDetail", true, false) as Label
	var initial_text := detail.text if detail != null else ""
	_expect(not initial_ids.is_empty(), "weather forecast renders region jump buttons")

	var subsecond := _with_remaining_delta(forecast, -100_000)
	strip.call("set_view_model", subsecond)
	await process_frame
	_expect(_button_ids(region_buttons) == initial_ids and (detail.text if detail != null else "") == initial_text, "subsecond refresh does not rebuild buttons or visible countdown")

	var next_second := _with_remaining_delta(forecast, -1_100_000)
	strip.call("set_view_model", next_second)
	await process_frame
	_expect(_button_ids(region_buttons) == initial_ids, "visible countdown refresh reuses region buttons")
	_expect(detail != null and detail.text != initial_text, "visible countdown refresh updates player-facing remaining time")

	strip.queue_free()
	await process_frame
	_finish()


func _with_remaining_delta(source: Dictionary, delta_us: int) -> Dictionary:
	var result := source.duplicate(true)
	var events := result.get("events", []) as Array
	if events.is_empty():
		return result
	var event := (events[0] as Dictionary).duplicate(true)
	event["remaining_us"] = maxi(0, int(event.get("remaining_us", 0)) + delta_us)
	events[0] = event
	result["events"] = events
	result["world_effective_us"] = int(result.get("world_effective_us", 0)) - delta_us
	return result


func _button_ids(parent: Node) -> Array[int]:
	var result: Array[int] = []
	if parent == null:
		return result
	for child in parent.get_children():
		if child is Button:
			result.append((child as Button).get_instance_id())
	return result


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("WEATHER_FORECAST_STRIP_LIVE_REFRESH_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("WEATHER_FORECAST_STRIP_LIVE_REFRESH_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
