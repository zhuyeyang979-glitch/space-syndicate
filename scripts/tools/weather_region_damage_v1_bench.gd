extends Control
class_name WeatherRegionDamageV1Bench

const WEATHER_CONTROLLER_SCENE := preload("res://scenes/runtime/WeatherRuntimeController.tscn")
const WEATHER_BRIDGE_SCENE := preload("res://scenes/runtime/WeatherRuntimeWorldBridge.tscn")
const REGION_CONTROLLER_SCENE := preload("res://scenes/runtime/RegionInfrastructureRuntimeController.tscn")
const REGION_BRIDGE_SCENE := preload("res://scenes/runtime/RegionInfrastructureWorldBridge.tscn")
const WEATHER_CATALOG := preload("res://resources/weather/weather_definition_catalog_v1.tres")
const RULESET_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")

@export var auto_run := true

@onready var summary_label: Label = %SummaryLabel
@onready var detail_label: RichTextLabel = %DetailLabel

var _checks := 0
var _failures: Array[String] = []
var _lines: Array[String] = []


class FakeClock:
	extends Node
	var now_us := 0

	func world_effective_micros() -> int:
		return now_us


class FakeWorld:
	extends Node
	var rng := RandomNumberGenerator.new()
	var districts: Array = []
	var log_lines: Array = []
	var callouts: Array = []

	func _duration_short_text(seconds: float) -> String:
		return "%d秒" % ceili(maxf(0.0, seconds))

	func _district_center(index: int) -> Vector2:
		return Vector2(float(index) * 20.0, 0.0)

	func _log(message: String) -> void:
		log_lines.append(message)

	func _add_action_callout(source: String, title: String, detail: String, accent: Color, world_position: Vector2, duration: float = 5.0) -> void:
		callouts.append({"source": source, "title": title, "detail": detail, "accent": accent.to_html(), "world_position": world_position, "duration": duration})


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_suite")


func run_suite() -> void:
	_checks = 0
	_failures.clear()
	_lines.clear()
	_case_lifecycle_and_fade()
	_case_no_damage_weather()
	_case_pause_and_step_invariance()
	_case_nonlethal_and_resistance()
	_case_undeveloped_region_settles()
	_case_save_restore_exact_once()
	_case_save_restore_catches_up()
	_update_ui()
	print("WEATHER_REGION_DAMAGE_V1_BENCH|status=%s|checks=%d|failures=%d|details=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	if DisplayServer.get_name() == "headless" and auto_run:
		get_tree().quit(0 if _failures.is_empty() else 1)


func debug_snapshot() -> Dictionary:
	return {
		"bench_complete": true,
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"check_count": _checks,
		"failure_count": _failures.size(),
		"failed_cases": _failures.duplicate(),
	}


func _case_lifecycle_and_fade() -> void:
	var fixture := _fixture()
	var weather := fixture.weather as WeatherRuntimeController
	var clock := fixture.clock as FakeClock
	_expect(_schedule(weather, "crystal_dust_storm"), "crystal dust forecast schedules from data definition")
	weather.tick(0.0)
	_expect(_damage(fixture) == 0, "forecast phase causes no region damage")
	var timing := _timing(weather)
	clock.now_us = int(timing.active_start)
	weather.tick(0.0)
	_expect(_damage(fixture) == 0 and _phase(weather) == WeatherRuntimeState.PHASE_ACTIVE, "active boundary starts at zero accumulated damage")
	clock.now_us = int(timing.active_start) + 50_000_000
	weather.tick(0.0)
	_expect(_damage(fixture) == 1, "crystal dust applies one light damage after fifty active seconds")
	clock.now_us = int(timing.active_end) + 5_000_000
	weather.tick(0.0)
	var effects: Array = (weather.region_effect_snapshot(0).get("effects", []) as Array)
	var fade_rate := _damage_rate(effects)
	_expect(_phase(weather) == WeatherRuntimeState.PHASE_FADING, "crystal dust enters fading phase")
	_expect(is_equal_approx(fade_rate, 0.01), "fade damage rate continuously reaches half intensity at five seconds")
	clock.now_us = int(timing.fade_end)
	weather.tick(0.0)
	_expect(weather.region_effect_snapshot(0).get("effects", []).is_empty(), "ended weather restores zero live effect")
	_expect(_damage(fixture) == 1, "fade completion does not over-apply fractional damage")
	_expect(is_equal_approx(WEATHER_CATALOG.definition("crystal_dust_storm").region_damage_per_second, 0.02), "runtime never mutates the weather definition")
	_lines.append("lifecycle: forecast -> active -> fading -> ended")
	_dispose(fixture)


func _case_no_damage_weather() -> void:
	var fixture := _fixture()
	var weather := fixture.weather as WeatherRuntimeController
	var clock := fixture.clock as FakeClock
	_expect(_schedule(weather, "ion_storm"), "zero-damage ion storm schedules normally")
	var timing := _timing(weather)
	clock.now_us = int(timing.fade_end)
	weather.tick(0.0)
	_expect(_damage(fixture) == 0, "weather with zero region_damage_per_second never damages infrastructure")
	_lines.append("zero-damage definition: unchanged")
	_dispose(fixture)


func _case_pause_and_step_invariance() -> void:
	var paused := _fixture()
	var paused_weather := paused.weather as WeatherRuntimeController
	var paused_clock := paused.clock as FakeClock
	_schedule(paused_weather, "crystal_dust_storm")
	var paused_timing := _timing(paused_weather)
	paused_clock.now_us = int(paused_timing.active_start) + 49_000_000
	paused_weather.tick(0.0)
	for ignored in range(20):
		paused_weather.tick(5.0)
	_expect(_damage(paused) == 0, "repeated ticks at frozen world_effective time cause no weather progress")
	paused_clock.now_us += 1_000_000
	paused_weather.tick(0.0)
	_expect(_damage(paused) == 1, "weather resumes from the same timeline when world_effective time advances")
	_dispose(paused)

	var small := _fixture()
	var small_weather := small.weather as WeatherRuntimeController
	var small_clock := small.clock as FakeClock
	_schedule(small_weather, "crystal_dust_storm")
	var small_timing := _timing(small_weather)
	var cursor := int(small_timing.active_start)
	while cursor <= int(small_timing.fade_end):
		small_clock.now_us = cursor
		small_weather.tick(0.0)
		cursor += 1_000_000
	var small_damage := _damage(small)

	var large := _fixture()
	var large_weather := large.weather as WeatherRuntimeController
	var large_clock := large.clock as FakeClock
	_schedule(large_weather, "crystal_dust_storm")
	var large_timing := _timing(large_weather)
	large_clock.now_us = int(large_timing.fade_end)
	large_weather.tick(0.0)
	var large_damage := _damage(large)
	_expect(small_damage == large_damage and large_damage == 1, "one-second and whole-event steps settle identical deterministic damage")
	_lines.append("clock: paused + step invariant")
	_dispose(small)
	_dispose(large)


func _case_nonlethal_and_resistance() -> void:
	var fragile := _fixture(0.0, 98)
	var fragile_weather := fragile.weather as WeatherRuntimeController
	var fragile_clock := fragile.clock as FakeClock
	_schedule(fragile_weather, "crystal_dust_storm")
	var timing := _timing(fragile_weather)
	fragile_clock.now_us = int(timing.fade_end)
	fragile_weather.tick(0.0)
	var snapshot := _region_snapshot(fragile)
	_expect(int(snapshot.get("derived_current_hp", 0)) == 1, "weather preserves the nonlethal one-HP floor")
	_expect(str(snapshot.get("lifecycle_state", "")) != "ruined", "weather cannot independently ruin a healthy region")
	fragile_weather.tick(0.0)
	_expect(int(_region_snapshot(fragile).get("derived_current_hp", 0)) == 1, "nonlethal floor settlement is exact-once")
	_dispose(fragile)

	var resistant := _fixture(0.5)
	var resistant_weather := resistant.weather as WeatherRuntimeController
	var resistant_clock := resistant.clock as FakeClock
	_schedule(resistant_weather, "crystal_dust_storm")
	var resistant_timing := _timing(resistant_weather)
	resistant_clock.now_us = int(resistant_timing.fade_end)
	resistant_weather.tick(0.0)
	_expect(_damage(resistant) == 0, "public region weather_resistance dampens cumulative damage")
	_lines.append("guardrail: nonlethal + resistance")
	_dispose(resistant)


func _case_undeveloped_region_settles() -> void:
	var fixture := _fixture()
	var weather := fixture.weather as WeatherRuntimeController
	var clock := fixture.clock as FakeClock
	var definition := WEATHER_CATALOG.definition("crystal_dust_storm")
	_expect(weather.schedule_forecast("crystal_dust_storm", 1, 1, definition.forecast_duration, definition.active_duration, "focused_test", true), "crystal dust can target an undeveloped public region")
	var timing := _timing(weather)
	clock.now_us = int(timing.fade_end)
	weather.tick(0.0)
	_expect((weather.to_save_data().get("events", []) as Array).is_empty(), "zero-HP region acknowledges weather damage and leaves no ended zombie event")
	_expect(int((fixture.region as RegionInfrastructureRuntimeController).region_snapshot("region.far").get("derived_current_hp", 0)) == 0, "undeveloped region remains unchanged")
	_lines.append("empty region: settled no-op")
	_dispose(fixture)


func _case_save_restore_exact_once() -> void:
	var source := _fixture()
	var source_weather := source.weather as WeatherRuntimeController
	var source_clock := source.clock as FakeClock
	_schedule(source_weather, "crystal_dust_storm")
	var timing := _timing(source_weather)
	source_clock.now_us = int(timing.active_start) + 50_000_000
	source_weather.tick(0.0)
	var weather_save := source_weather.to_save_data()
	var region_save := (source.region as RegionInfrastructureRuntimeController).to_save_data()
	_expect(_damage(source) == 1, "source save captures one applied damage")

	var restored := _fixture()
	var restored_clock := restored.clock as FakeClock
	restored_clock.now_us = source_clock.now_us
	var region_apply := (restored.region as RegionInfrastructureRuntimeController).apply_save_data(region_save)
	var weather_apply := (restored.weather as WeatherRuntimeController).apply_save_data(weather_save)
	(restored.weather as WeatherRuntimeController).tick(0.0)
	_expect(bool(region_apply.get("applied", false)) and bool(weather_apply.get("applied", false)), "region and existing weather save owners restore without a new section")
	_expect(_damage(restored) == 1, "load at the same world time does not repeat settled damage")
	restored_clock.now_us = int(timing.fade_end)
	(restored.weather as WeatherRuntimeController).tick(0.0)
	_expect(_damage(restored) == 1, "restored event completes without duplicate damage")
	_lines.append("save: exact-once")
	_dispose(source)
	_dispose(restored)


func _case_save_restore_catches_up() -> void:
	var source := _fixture()
	var source_weather := source.weather as WeatherRuntimeController
	var source_clock := source.clock as FakeClock
	_schedule(source_weather, "crystal_dust_storm")
	var timing := _timing(source_weather)
	source_clock.now_us = int(timing.active_start) + 49_000_000
	source_weather.tick(0.0)
	var weather_save := source_weather.to_save_data()
	var region_save := (source.region as RegionInfrastructureRuntimeController).to_save_data()
	_expect(_damage(source) == 0, "pre-threshold save has no rounded damage")

	var restored := _fixture()
	(restored.region as RegionInfrastructureRuntimeController).apply_save_data(region_save)
	(restored.clock as FakeClock).now_us = int(timing.fade_end)
	var weather_apply := (restored.weather as WeatherRuntimeController).apply_save_data(weather_save)
	_expect(bool(weather_apply.get("applied", false)), "ended catch-up event survives restore until owner settlement")
	(restored.weather as WeatherRuntimeController).tick(0.0)
	_expect(_damage(restored) == 1, "first post-load tick catches up elapsed active and fade damage without skipping")
	_expect((restored.weather as WeatherRuntimeController).region_effect_snapshot(0).get("effects", []).is_empty(), "catch-up event is removed after deterministic settlement")
	_lines.append("save: no skipped terminal damage")
	_dispose(source)
	_dispose(restored)


func _fixture(resistance: float = 0.0, pre_damage: int = 0) -> Dictionary:
	var host := Node.new()
	host.name = "Fixture"
	add_child(host)
	var clock := FakeClock.new()
	clock.name = "WorldEffectiveClockRuntimeController"
	var world := FakeWorld.new()
	world.name = "World"
	world.rng.seed = 170715
	world.districts = [
		{"name": "晶谷", "destroyed": false, "terrain": "land", "neighbors": [1], "city": {"active": true}, "weather_resistance": clampf(resistance, 0.0, 1.0)},
		{"name": "远港", "destroyed": false, "terrain": "land", "neighbors": [0], "city": {}},
	]
	var weather_bridge := WEATHER_BRIDGE_SCENE.instantiate() as WeatherRuntimeWorldBridge
	var region := REGION_CONTROLLER_SCENE.instantiate() as RegionInfrastructureRuntimeController
	var region_bridge := REGION_BRIDGE_SCENE.instantiate() as RegionInfrastructureWorldBridge
	var weather := WEATHER_CONTROLLER_SCENE.instantiate() as WeatherRuntimeController
	for node in [clock, world, weather_bridge, region, region_bridge, weather]:
		host.add_child(node)
	_expect(bool(region.configure(RULESET_PROFILE.debug_snapshot()).get("configured", false)), "region owner configures")
	_expect(bool(region.initialize_regions([
		{"region_id": "region.crystal", "terrain_id": "land", "neighbor_region_ids": ["region.far"], "legacy_index": 0},
		{"region_id": "region.far", "terrain_id": "land", "neighbor_region_ids": ["region.crystal"], "legacy_index": 1},
	]).get("initialized", false)), "region owner initializes fixture map")
	var build := region.apply_facility_action({
		"transaction_id": "fixture-build",
		"region_id": "region.crystal",
		"owner_kind": "player",
		"owner_player_index": 0,
		"facility_type": "factory",
		"industry_id": "industry",
		"rank": 1,
		"occurred_at": 0.0,
	})
	region.finalize_facility_action(build)
	_expect(bool(build.get("committed", false)) and int(region.region_snapshot("region.crystal").get("derived_max_hp", 0)) == 100, "fixture provides 100 regional HP")
	if pre_damage > 0:
		region.apply_unit_damage({"transaction_id": "fixture-pre-damage", "source_kind": "monster", "source_entity_id": "monster.fixture", "region_id": "region.crystal", "amount": pre_damage, "occurred_at": 0.0})
	weather_bridge.bind_world(world)
	region_bridge.set_controller(region)
	region_bridge.bind_world(world)
	weather.set_world_bridge(weather_bridge)
	weather.set_world_effective_clock(clock)
	weather.set_region_infrastructure_world_bridge(region_bridge)
	weather.configure({"ruleset_id": "v0.6"})
	weather.set_new_forecasts_allowed(false)
	_expect(bool(weather.debug_snapshot().get("controller_ready", false)), "weather owner configures with deterministic clock")
	return {"host": host, "clock": clock, "world": world, "weather": weather, "region": region, "region_bridge": region_bridge}


func _schedule(weather: WeatherRuntimeController, weather_id: String) -> bool:
	var definition := WEATHER_CATALOG.definition(weather_id)
	return weather.schedule_forecast(weather_id, 0, 1, definition.forecast_duration, definition.active_duration, "focused_test", true)


func _timing(weather: WeatherRuntimeController) -> Dictionary:
	var events: Array = weather.to_save_data().get("events", [])
	var event: Dictionary = events[0] if not events.is_empty() and events[0] is Dictionary else {}
	return {
		"active_start": int(event.get("active_starts_at_world_us", 0)),
		"active_end": int(event.get("active_ends_at_world_us", 0)),
		"fade_end": int(event.get("fade_ends_at_world_us", 0)),
	}


func _phase(weather: WeatherRuntimeController) -> String:
	var events: Array = weather.debug_snapshot().get("events", [])
	return str((events[0] as Dictionary).get("phase", "")) if not events.is_empty() and events[0] is Dictionary else WeatherRuntimeState.PHASE_ENDED


func _damage(fixture: Dictionary) -> int:
	return int(_region_snapshot(fixture).get("damage_taken", 0))


func _region_snapshot(fixture: Dictionary) -> Dictionary:
	return (fixture.region as RegionInfrastructureRuntimeController).region_snapshot("region.crystal")


func _damage_rate(effects: Array) -> float:
	if effects.is_empty() or not (effects[0] is Dictionary):
		return 0.0
	var damage_variant: Variant = (effects[0] as Dictionary).get("damage", {})
	return float((damage_variant as Dictionary).get("per_second", 0.0)) if damage_variant is Dictionary else 0.0


func _dispose(fixture: Dictionary) -> void:
	var host_variant: Variant = fixture.get("host")
	if host_variant is Node and is_instance_valid(host_variant):
		(host_variant as Node).free()


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _update_ui() -> void:
	if summary_label != null:
		summary_label.text = "Weather Region Damage v1 | %s | %d checks" % ["PASS" if _failures.is_empty() else "FAIL", _checks]
	if detail_label != null:
		detail_label.text = "\n".join(_lines + (["Failures: %s" % str(_failures)] if not _failures.is_empty() else []))
