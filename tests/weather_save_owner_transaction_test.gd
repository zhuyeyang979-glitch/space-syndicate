extends SceneTree

const WEATHER_SCENE := preload("res://scenes/runtime/WeatherRuntimeController.tscn")
const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

var _checks := 0
var _failures: Array[String] = []


class FakeClock:
	extends Node

	var now_us := 0

	func world_effective_micros() -> int:
		return now_us


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var clock := FakeClock.new()
	clock.name = "WorldEffectiveClockRuntimeController"
	root.add_child(clock)
	var weather := WEATHER_SCENE.instantiate() as WeatherRuntimeController
	root.add_child(weather)
	weather.set_world_effective_clock(clock)
	var checkpoint := _checkpoint()
	var applied := weather.apply_save_data(checkpoint)
	_expect(bool(applied.get("applied", false)) and _same_data(checkpoint, weather.to_save_data()), "weather owner restores one exact checkpoint without consuming lifecycle time")
	_expect((weather.to_save_data().get("events", []) as Array).size() == 1, "weather event remains pending until the first post-restore owner tick")

	var before_preflight := weather.to_save_data()
	var first_preflight := weather.preflight_save_data(checkpoint)
	var second_preflight := weather.preflight_save_data(checkpoint)
	_expect(bool(first_preflight.get("accepted", false)) and bool(second_preflight.get("accepted", false)), "weather owner preflights its exact checkpoint repeatedly without duplicating a live node")
	_expect(_same_data(before_preflight, weather.to_save_data()) and clock.now_us == 0, "weather preflight mutates neither owner lifecycle state nor the bound world clock")
	_expect(_same_data(first_preflight.get("normalized_state", {}), second_preflight.get("normalized_state", {})), "weather preflight normalization is deterministic")
	var detached_normalized := (first_preflight.get("normalized_state", {}) as Dictionary).duplicate(true)
	detached_normalized["sequence"] = 999
	_expect(_same_data(before_preflight, weather.to_save_data()), "mutating normalized weather output cannot alias live owner state")
	var catalogless_weather := WeatherRuntimeController.new()
	root.add_child(catalogless_weather)
	catalogless_weather.definition_catalog = null
	var catalogless_preflight := catalogless_weather.preflight_save_data(checkpoint)
	_expect(bool(catalogless_preflight.get("accepted", false)) and catalogless_weather.definition_catalog == null, "weather preflight reads the default definition catalog locally without writing it into the owner")
	catalogless_weather.free()
	_verify_strict_preflight_rejections(weather, checkpoint, clock)

	clock.now_us = 200_000_000
	var late_apply := weather.apply_save_data(checkpoint)
	_expect(bool(late_apply.get("applied", false)) and _same_data(checkpoint, weather.to_save_data()), "weather apply is neutral to the pre-session clock value")
	weather.apply_save_data({})
	var rollback := weather.apply_save_data(checkpoint)
	_expect(bool(rollback.get("applied", false)) and _same_data(checkpoint, weather.to_save_data()), "weather rollback restores the exact checkpoint repeatedly")
	var before_invalid := weather.to_save_data()
	var private_injection := before_invalid.duplicate(true)
	private_injection["private_hand"] = ["WEATHER_SAVE_OWNER_PRIVATE_HAND"]
	var rejected_private := weather.apply_save_data(private_injection)
	_expect(not bool(rejected_private.get("applied", true)) and str(rejected_private.get("reason", "")) == "save_keys_invalid", "weather restore rejects unknown private top-level fields")
	_expect(_same_data(before_invalid, weather.to_save_data()), "private top-level rejection mutates no weather state")
	var event_injection := before_invalid.duplicate(true)
	((event_injection.get("events", []) as Array)[0] as Dictionary)["owner"] = "WEATHER_SAVE_OWNER_PRIVATE_OWNER"
	var rejected_event := weather.apply_save_data(event_injection)
	_expect(not bool(rejected_event.get("applied", true)) and str(rejected_event.get("reason", "")) == "event_keys_invalid", "weather restore rejects private event fields before they enter save state")
	_expect(_same_data(before_invalid, weather.to_save_data()), "private event rejection mutates no weather state")
	weather.queue_free()
	clock.queue_free()

	var coordinator := COORDINATOR_SCENE.instantiate()
	root.add_child(coordinator)
	await process_frame
	var registry := coordinator.get_node_or_null("GameSessionRuntimeController/V06SaveOwnerRegistry")
	_expect(registry != null, "production registry is present for weather owner binding inspection")
	var weather_binding: Resource
	if registry != null:
		for binding in registry.bindings:
			if binding != null and str(binding.section_id) == "weather":
				weather_binding = binding
				break
	_expect(weather_binding != null and weather_binding.is_transactional() and str(weather_binding.owner_path) == "../../WeatherRuntimeController", "registry binds weather to the unique production owner")
	coordinator.queue_free()
	await process_frame
	_finish()


func _verify_strict_preflight_rejections(weather: WeatherRuntimeController, checkpoint: Dictionary, clock: FakeClock) -> void:
	var unknown_root := checkpoint.duplicate(true)
	unknown_root["private_hand"] = []
	_expect(_preflight_rejects_without_mutation(weather, unknown_root, clock), "weather preflight rejects unknown root fields")
	var coercible_schema := checkpoint.duplicate(true)
	coercible_schema["schema_version"] = "2"
	_expect(_preflight_rejects_without_mutation(weather, coercible_schema, clock), "weather preflight rejects coercible schema strings")
	var nonfinite_telemetry := checkpoint.duplicate(true)
	(nonfinite_telemetry.get("telemetry") as Dictionary)["scheduled_forecast"] = INF
	_expect(_preflight_rejects_without_mutation(weather, nonfinite_telemetry, clock), "weather preflight rejects non-finite codec data")
	var coercible_region := checkpoint.duplicate(true)
	((coercible_region.get("events") as Array)[0] as Dictionary)["region_indices"] = ["0"]
	_expect(_preflight_rejects_without_mutation(weather, coercible_region, clock), "weather preflight rejects coercible event region indices")
	var queue_mismatch := checkpoint.duplicate(true)
	(queue_mismatch.get("queue") as Array).append(1)
	_expect(_preflight_rejects_without_mutation(weather, queue_mismatch, clock), "weather preflight rejects queue and event phase mismatch")


func _preflight_rejects_without_mutation(weather: WeatherRuntimeController, candidate: Dictionary, clock: FakeClock) -> bool:
	var before := weather.to_save_data()
	var clock_before := clock.now_us
	var result := weather.preflight_save_data(candidate)
	return not bool(result.get("accepted", true)) \
		and _same_data(before, weather.to_save_data()) \
		and clock_before == clock.now_us


func _checkpoint() -> Dictionary:
	return {
		"schema_version": WeatherRuntimeState.SCHEMA_VERSION,
		"events": [{
			"event_schema_version": WeatherRuntimeState.EVENT_SCHEMA_VERSION,
			"id": 1,
			"definition_id": "ion_storm",
			"type": "ion_storm",
			"region_indices": [0],
			"districts": [0],
			"phase": WeatherRuntimeState.PHASE_FORECAST,
			"source_type": "natural",
			"created_at_world_us": 0,
			"forecast_starts_at_world_us": 0,
			"active_starts_at_world_us": 30_000_000,
			"active_ends_at_world_us": 75_000_000,
			"fade_ends_at_world_us": 85_000_000,
			"forecast_duration_world_us": 30_000_000,
			"active_duration_world_us": 45_000_000,
			"fade_duration_world_us": 10_000_000,
		}],
		"queue": [],
		"next_generation_world_us": 140_000_000,
		"sequence": 1,
		"history": [],
		"region_history": {"0": 1},
		"telemetry": {"scheduled_forecast": 1},
	}


func _same_data(left: Variant, right: Variant) -> bool:
	return JSON.stringify(left) == JSON.stringify(right)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("WEATHER_SAVE_OWNER_TRANSACTION_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
