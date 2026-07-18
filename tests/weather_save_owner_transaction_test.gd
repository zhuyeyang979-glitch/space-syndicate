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

	var detached_probe := weather.duplicate() as WeatherRuntimeController
	var probe_receipt: Dictionary = detached_probe.apply_save_data(checkpoint) if detached_probe != null else {}
	_expect(bool(probe_receipt.get("applied", false)) and _same_data(checkpoint, detached_probe.to_save_data()), "detached registry preflight normalizes weather state exactly without a clock")
	detached_probe.free()

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
	var snapshot: Dictionary = registry.registry_snapshot() if registry != null else {}
	_expect(registry != null and bool(snapshot.get("valid", false)), "production registry remains structurally valid")
	_expect(int(snapshot.get("transactional_section_count", 0)) == 12 and int(snapshot.get("unsupported_section_count", 0)) == 7, "history registration advances the honest production boundary to 12 transactional and 7 unsupported sections")
	var weather_binding: Resource
	if registry != null:
		for binding in registry.bindings:
			if binding != null and str(binding.section_id) == "weather":
				weather_binding = binding
				break
	_expect(weather_binding != null and weather_binding.is_transactional() and str(weather_binding.owner_path) == "../../WeatherRuntimeController", "registry binds weather to the unique production owner")
	_expect(not bool(snapshot.get("resume_ready", true)) and int(snapshot.get("required_section_count", 0)) == 19 and int(snapshot.get("unsupported_section_count", 0)) == 7, "full resume remains fail-closed while seven required sections are unsupported")
	coordinator.queue_free()
	await process_frame
	_finish()


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
