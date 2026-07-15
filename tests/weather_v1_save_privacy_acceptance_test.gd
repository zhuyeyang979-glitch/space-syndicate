extends SceneTree

const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const WEATHER_SPEC_PATH := "res://docs/weather_system_v1_spec.md"
const EXPECTED_SECTION_COUNT := 18
const WEATHER_SECTION_ID := "weather"
const WEATHER_OWNER_ID := "weather_runtime"
const WEATHER_SCHEMA_VERSION := 2
const WEATHER_EVENT_SCHEMA_VERSION := 1
const WEATHER_START_GRACE_US := 90_000_000
const WEATHER_FORECAST_LEAD_MIN_US := 30_000_000
const WEATHER_ACTIVE_MIN_US := 45_000_000
const WEATHER_FADE_US := 10_000_000
const PHASE_FORECAST := "forecast"
const PHASE_ACTIVE := "active"
const PHASE_FADING := "fading"
const PHASE_QUEUED := "queued"
const FORBIDDEN_SECTION_TOKENS := ["solar", "sunlight", "planet_rotation", "rotation", "sun"]
const REQUIRED_OWNER_METHODS := [
	"set_world_effective_clock",
	"set_new_forecasts_allowed",
	"tick",
	"public_snapshot",
	"to_save_data",
	"apply_save_data",
	"forecast_snapshot",
	"active_zones_snapshot",
	"region_effect_snapshot",
]
const REQUIRED_V2_SAVE_KEYS := [
	"schema_version",
	"events",
	"queue",
	"next_generation_world_us",
	"sequence",
	"history",
	"region_history",
	"telemetry",
]
const FORBIDDEN_PRIVACY_KEY_TOKENS := [
	"player_index",
	"selected_player",
	"cash",
	"hand",
	"discard",
	"owner",
	"hidden_owner",
	"city_guesses",
	"ai_plan",
	"private",
	"camera",
	"rng",
	"selected_district",
	"private_source",
]
const PRIVATE_CANARIES := [
	"WEATHER_V1_PRIVATE_HAND_SENTINEL",
	"WEATHER_V1_PRIVATE_DISCARD_SENTINEL",
	"WEATHER_V1_PRIVATE_OWNER_SENTINEL",
	"WEATHER_V1_PRIVATE_CITY_GUESS_SENTINEL",
	"WEATHER_V1_PRIVATE_AI_PLAN_SENTINEL",
	"WEATHER_V1_PRIVATE_CAMERA_SENTINEL",
	"WEATHER_V1_PRIVATE_SOURCE_SENTINEL",
	"WEATHER_V1_PRIVATE_RNG_SENTINEL",
]


class FakeWeatherWorld:
	extends Node

	var rng := RandomNumberGenerator.new()
	var game_time := 9_999.0
	var selected_district := 0
	var market_open := false
	var camera_state := {"center": "WEATHER_V1_PRIVATE_CAMERA_SENTINEL", "zoom": 7.5}
	var districts := [
		{"name": "Alpha", "destroyed": false, "terrain": "land", "neighbors": [1, 2], "city": {"active": true, "level": 2, "owner": "WEATHER_V1_PRIVATE_OWNER_SENTINEL"}, "trade_volume_bucket": 3},
		{"name": "Beta", "destroyed": false, "terrain": "ocean", "neighbors": [0, 2], "city": {"active": false, "owner": "WEATHER_V1_PRIVATE_OWNER_SENTINEL"}, "trade_volume_bucket": 1},
		{"name": "Gamma", "destroyed": false, "terrain": "land", "neighbors": [0, 1], "city": {}, "trade_volume_bucket": 2},
	]
	var auto_monsters := [
		{"district_index": 0, "down": false, "remaining_time": 45.0, "owner": "WEATHER_V1_PRIVATE_OWNER_SENTINEL"},
		{"district_index": 1, "down": true, "remaining_time": 45.0, "owner": "WEATHER_V1_PRIVATE_OWNER_SENTINEL"},
		{"district_index": 2, "down": false, "remaining_time": 0.0, "owner": "WEATHER_V1_PRIVATE_OWNER_SENTINEL"},
	]
	var players := [
		{
			"cash": 123456789,
			"hand": ["WEATHER_V1_PRIVATE_HAND_SENTINEL"],
			"discard": ["WEATHER_V1_PRIVATE_DISCARD_SENTINEL"],
			"city_guesses": {0: "WEATHER_V1_PRIVATE_CITY_GUESS_SENTINEL"},
			"ai_private_plan": "WEATHER_V1_PRIVATE_AI_PLAN_SENTINEL",
		},
	]
	var action_callouts: Array = []
	var log_lines: Array = []

	func _init() -> void:
		rng.seed = 20260715

	func _duration_short_text(seconds: float) -> String:
		return "%d秒" % ceili(maxf(0.0, seconds))

	func _district_center(index: int) -> Vector2:
		return Vector2(float(index) * 32.0, 0.0)

	func _log(message: String) -> void:
		log_lines.append(message)

	func _add_action_callout(source: String, title: String, detail: String, accent: Color, world_position: Vector2, duration: float = 5.0) -> void:
		action_callouts.append({
			"source": source,
			"title": title,
			"detail": detail,
			"accent": accent.to_html(),
			"world_position": world_position,
			"duration": duration,
		})

	func _player_is_ai(player_index: int) -> bool:
		return player_index > 0

	func weather_public_live_monster_counts_by_region() -> Dictionary:
		var result := {}
		for monster_variant in auto_monsters:
			if not (monster_variant is Dictionary):
				continue
			var monster := monster_variant as Dictionary
			if bool(monster.get("down", false)) or float(monster.get("remaining_time", 0.0)) <= 0.0:
				continue
			var region := int(monster.get("district_index", -1))
			if region < 0:
				continue
			result[region] = int(result.get(region, 0)) + 1
		return result


var _checks := 0
var _failures: Array[String] = []
var _coordinator: Node
var _session: Node
var _save: Node
var _handshake: Node
var _registry: Node
var _weather: Node
var _weather_bridge: Node
var _clock: Node
var _world: FakeWeatherWorld


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(COORDINATOR_SCENE_PATH), "coordinator_scene_exists")
	_expect(FileAccess.file_exists(WEATHER_SPEC_PATH), "weather_v1_spec_exists")
	await _setup_runtime()
	if _weather == null or _clock == null:
		_finish()
		return
	_check_save_section_boundary()
	var owner_ready := _check_owner_api_surface()
	if not owner_ready:
		_cleanup_runtime()
		await process_frame
		_finish()
		return
	_check_opening_grace_and_natural_source()
	_check_lifecycle_effect_queue_and_sources()
	_check_pause_settlement_and_market_open()
	_check_save_schema_clock_authority_and_atomic_apply()
	_check_privacy_surfaces()
	_cleanup_runtime()
	await process_frame
	_finish()


func _setup_runtime() -> void:
	var packed := load(COORDINATOR_SCENE_PATH) as PackedScene
	if packed == null:
		_expect(false, "coordinator_scene_loads")
		return
	_world = FakeWeatherWorld.new()
	_world.name = "WeatherV1AcceptanceWorld"
	root.add_child(_world)
	_coordinator = packed.instantiate()
	_coordinator.name = "WeatherV1AcceptanceCoordinator"
	root.add_child(_coordinator)
	await process_frame
	_session = _coordinator.get_node_or_null("GameSessionRuntimeController")
	_save = _session.get_node_or_null("GameSaveRuntimeCoordinator") if _session != null else null
	_handshake = _save.get_node_or_null("RulesetSaveHandshakeService") if _save != null else null
	_registry = _session.get_node_or_null("V06SaveOwnerRegistry") if _session != null else null
	_weather = _coordinator.get_node_or_null("WeatherRuntimeController")
	_weather_bridge = _coordinator.get_node_or_null("WeatherRuntimeWorldBridge")
	_clock = _coordinator.get_node_or_null("WorldEffectiveClockRuntimeController")
	if _clock != null and _clock.has_method("configure"):
		_clock.call("configure", {})
	if _session != null and _session.has_method("set_world_effective_clock"):
		_session.call("set_world_effective_clock", _clock)
	if _session != null and _session.has_method("configure"):
		_session.call("configure", {"ruleset_id": "v0.6"}, {})
	if _weather_bridge != null and _weather_bridge.has_method("bind_world"):
		_weather_bridge.call("bind_world", _world)
	if _weather != null and _weather.has_method("set_world_bridge"):
		_weather.call("set_world_bridge", _weather_bridge)
	if _weather != null and _weather.has_method("set_world_effective_clock"):
		_weather.call("set_world_effective_clock", _clock)
	if _weather != null and _weather.has_method("configure"):
		_weather.call("configure", {"ruleset_id": "v0.6"})
	var debug: Dictionary = _weather.call("debug_snapshot") if _weather != null and _weather.has_method("debug_snapshot") else {}
	_expect(_session != null and _save != null and _handshake != null and _registry != null, "save_owner_stack_reachable")
	_expect(_weather != null and _weather_bridge != null and _clock != null, "weather_owner_bridge_clock_reachable")
	_expect(bool(debug.get("controller_ready", false)), "weather_owner_configures_with_real_bridge_clock_and_catalog")


func _cleanup_runtime() -> void:
	if _coordinator != null and is_instance_valid(_coordinator):
		root.remove_child(_coordinator)
		_coordinator.queue_free()
	if _world != null and is_instance_valid(_world):
		root.remove_child(_world)
		_world.queue_free()


func _reset_weather_and_clock(world_us: int = 0) -> void:
	if _weather != null and _weather.has_method("reset_state"):
		_weather.call("reset_state")
	if _weather != null and _weather.has_method("set_new_forecasts_allowed"):
		_weather.call("set_new_forecasts_allowed", true)
	if _clock != null and _clock.has_method("restore_micros"):
		_clock.call("restore_micros", maxi(0, world_us))


func _check_save_section_boundary() -> void:
	if _handshake == null or _registry == null:
		_expect(false, "save_section_boundary_nodes_available")
		return
	var manifest: Dictionary = _handshake.call("required_section_manifest") if _handshake.has_method("required_section_manifest") else {}
	var order: Array = _registry.call("fixed_section_order") if _registry.has_method("fixed_section_order") else []
	var snapshot: Dictionary = _registry.call("registry_snapshot") if _registry.has_method("registry_snapshot") else {}
	var weather_count := 0
	var forbidden_sections: Array[String] = []
	var owner_ids := {}
	for section_variant in manifest.keys():
		var section_id := str(section_variant)
		var lowered := section_id.to_lower()
		var contract: Dictionary = manifest.get(section_id, {}) if manifest.get(section_id, {}) is Dictionary else {}
		owner_ids[str(contract.get("owner_id", ""))] = true
		if section_id == WEATHER_SECTION_ID:
			weather_count += 1
		elif lowered.contains("weather"):
			forbidden_sections.append(section_id)
		for token in FORBIDDEN_SECTION_TOKENS:
			if lowered.contains(token):
				forbidden_sections.append(section_id)
	_expect(manifest.size() == EXPECTED_SECTION_COUNT and order.size() == EXPECTED_SECTION_COUNT, "save_registry_remains_exactly_18_sections")
	_expect(owner_ids.size() == EXPECTED_SECTION_COUNT, "save_registry_has_unique_owner_per_section")
	_expect(weather_count == 1 and manifest.has(WEATHER_SECTION_ID) and order.has(WEATHER_SECTION_ID), "weather_v1_reuses_existing_weather_section")
	_expect(forbidden_sections.is_empty(), "no_solar_rotation_or_weather_19th_section|sections=%s" % [forbidden_sections])
	var weather_contract: Dictionary = manifest.get(WEATHER_SECTION_ID, {}) if manifest.get(WEATHER_SECTION_ID, {}) is Dictionary else {}
	_expect(str(weather_contract.get("owner_id", "")) == WEATHER_OWNER_ID, "weather_section_bound_to_weather_runtime_owner")
	_expect(not bool(snapshot.get("resume_ready", true)) and int(snapshot.get("required_section_count", 0)) == EXPECTED_SECTION_COUNT, "registry_resume_remains_fail_closed_with_18_sections")


func _check_owner_api_surface() -> bool:
	var missing: Array[String] = []
	for method_name in REQUIRED_OWNER_METHODS:
		if not _weather.has_method(method_name):
			missing.append(str(method_name))
	_expect(missing.is_empty(), "weather_owner_true_api_surface_available|missing=%s" % [missing])
	var debug: Dictionary = _weather.call("debug_snapshot") if _weather.has_method("debug_snapshot") else {}
	_expect(bool(debug.get("single_save_owner", false)) and str(debug.get("runtime_owner", "")) == "WeatherRuntimeController", "weather_runtime_controller_is_single_weather_save_owner")
	_expect(not bool(debug.get("reads_game_time", true)) and not bool(debug.get("reads_selected_district", true)) and not bool(debug.get("reads_private_player_state", true)), "weather_owner_declares_no_game_time_selection_or_private_player_dependency")
	return missing.is_empty() and bool(debug.get("single_save_owner", false)) and str(debug.get("runtime_owner", "")) == "WeatherRuntimeController"


func _check_opening_grace_and_natural_source() -> void:
	_reset_weather_and_clock(0)
	_weather.call("tick", 0.0)
	_expect(_event_entries(_weather.call("public_snapshot")).is_empty(), "opening_grace_blocks_weather_at_zero")
	_clock.call("restore_micros", WEATHER_START_GRACE_US - 1)
	_weather.call("tick", 0.0)
	_expect(_event_entries(_weather.call("public_snapshot")).is_empty(), "opening_grace_blocks_weather_before_90s_boundary")
	_clock.call("restore_micros", WEATHER_START_GRACE_US)
	_weather.call("tick", 0.0)
	var snapshot: Dictionary = _weather.call("public_snapshot")
	var events := _event_entries(snapshot)
	var first_event: Dictionary = events[0] if not events.is_empty() and events[0] is Dictionary else {}
	_expect(not first_event.is_empty() and str(first_event.get("source_type", "")) == "natural", "opening_grace_allows_natural_forecast_at_exact_90s_boundary")
	_expect(int(snapshot.get("world_effective_us", -1)) == WEATHER_START_GRACE_US, "public_weather_snapshot_uses_integer_world_effective_clock")


func _check_lifecycle_effect_queue_and_sources() -> void:
	_reset_weather_and_clock(0)
	_expect(_weather.call("schedule_forecast", "ion_storm", 0, 1, 30.0, 45.0, "acceptance", false), "natural_source_schedule_uses_owner_api")
	_clock.call("restore_micros", WEATHER_FORECAST_LEAD_MIN_US - 1)
	_weather.call("tick", 0.0)
	_expect(_weather.call("active_zones_snapshot").is_empty(), "forecast_phase_holds_until_active_start_exclusive")
	_clock.call("restore_micros", WEATHER_FORECAST_LEAD_MIN_US)
	_weather.call("tick", 0.0)
	var active: Array = _weather.call("active_zones_snapshot")
	_expect(active.size() == 1 and str((active[0] as Dictionary).get("phase", "")) == PHASE_ACTIVE, "forecast_transitions_to_active_at_exact_boundary")
	var effect_snapshot: Dictionary = _weather.call("region_effect_snapshot", 0, {"product_tags": ["weather_energy"], "movement_domain": "air"})
	_expect(effect_snapshot.get("effects") is Array and (effect_snapshot.get("effects") as Array).size() > 0, "active_weather_exposes_region_effect_snapshot")
	_clock.call("restore_micros", WEATHER_FORECAST_LEAD_MIN_US + WEATHER_ACTIVE_MIN_US)
	_weather.call("tick", 0.0)
	var fading: Array = _weather.call("active_zones_snapshot")
	_expect(fading.size() == 1 and str((fading[0] as Dictionary).get("phase", "")) == PHASE_FADING, "active_transitions_to_fading_at_exact_active_end")
	_clock.call("restore_micros", WEATHER_FORECAST_LEAD_MIN_US + WEATHER_ACTIVE_MIN_US + WEATHER_FADE_US)
	_weather.call("tick", 0.0)
	_expect(_weather.call("active_zones_snapshot").is_empty() and _event_entries(_weather.call("public_snapshot")).is_empty(), "fading_event_ends_at_exact_fade_boundary")

	_reset_weather_and_clock(0)
	_expect(_weather.call("schedule_forecast", "ion_storm", 0, 1, 30.0, 45.0, "acceptance", false), "same_region_first_event_schedules")
	_expect(_weather.call("schedule_forecast", "solar_flare", 0, 1, 30.0, 45.0, "acceptance", false), "same_region_second_event_enters_queue")
	var queued_snapshot: Dictionary = _weather.call("public_snapshot")
	var queued_events := _event_entries(queued_snapshot)
	_expect(queued_events.size() == 2 and str((queued_events[1] as Dictionary).get("phase", "")) == PHASE_QUEUED and (queued_snapshot.get("queue") as Array).size() == 1, "same_region_conflict_exposes_queue_snapshot")
	_expect(not _weather.call("schedule_forecast", "deep_freeze", 1, 1, 30.0, 45.0, "acceptance", false), "third_unended_weather_rejected_by_max_two_cap")

	_reset_weather_and_clock(0)
	_expect(_weather.call("apply_weather_control_at", {"weather_type": "gravity_tide"}, 1), "card_source_schedules_through_explicit_target_api")
	var card_events := _event_entries(_weather.call("public_snapshot"))
	var card_event: Dictionary = card_events[0] if not card_events.is_empty() and card_events[0] is Dictionary else {}
	_expect(str(card_event.get("source_type", "")) == "card", "card_source_type_is_public_and_canonical")

	_reset_weather_and_clock(12_000_000)
	var monster_payload := _weather_save_payload([_event_payload(7, "deep_freeze", 2, "monster", 12_000_000, 12_000_000, 42_000_000, 87_000_000, 97_000_000)])
	var monster_receipt: Dictionary = _weather.call("apply_save_data", monster_payload)
	var monster_events := _event_entries(_weather.call("public_snapshot"))
	var monster_event: Dictionary = monster_events[0] if not monster_events.is_empty() and monster_events[0] is Dictionary else {}
	_expect(bool(monster_receipt.get("applied", false)) and str(monster_event.get("source_type", "")) == "monster", "monster_source_type_roundtrips_through_real_apply_save_data")


func _check_pause_settlement_and_market_open() -> void:
	_reset_weather_and_clock(0)
	_world.market_open = true
	_expect(_weather.call("schedule_forecast", "spore_season", 0, 1, 30.0, 45.0, "acceptance", false), "market_open_fixture_schedules_forecast")
	var before: Dictionary = _weather.call("public_snapshot")
	_world.game_time = 1_000_000.0
	for _i in range(3):
		_weather.call("tick", 20.0)
	_expect(_same_data(before, _weather.call("public_snapshot")), "true_pause_freezes_weather_when_world_effective_clock_does_not_advance")
	var market_events := _event_entries(before)
	var active_boundary_us := int((market_events[0] as Dictionary).get("active_starts_at_world_us", WEATHER_FORECAST_LEAD_MIN_US)) if not market_events.is_empty() else WEATHER_FORECAST_LEAD_MIN_US
	_clock.call("advance", float(active_boundary_us) / 1_000_000.0)
	_weather.call("tick", 0.0)
	_expect((_weather.call("active_zones_snapshot") as Array).size() == 1, "market_open_does_not_freeze_weather_when_world_effective_clock_advances")

	_reset_weather_and_clock(200_000_000)
	_weather.call("set_new_forecasts_allowed", false)
	_weather.call("tick", 0.0)
	_expect(_event_entries(_weather.call("public_snapshot")).is_empty(), "settlement_blocks_new_natural_forecasts")
	_reset_weather_and_clock(0)
	_expect(_weather.call("schedule_forecast", "solar_flare", 0, 1, 30.0, 45.0, "acceptance", false), "existing_forecast_scheduled_before_settlement")
	_weather.call("set_new_forecasts_allowed", false)
	_clock.call("restore_micros", WEATHER_FORECAST_LEAD_MIN_US + WEATHER_ACTIVE_MIN_US + WEATHER_FADE_US)
	_weather.call("tick", 0.0)
	var settled_save: Dictionary = _weather.call("to_save_data")
	_expect(_event_entries(_weather.call("public_snapshot")).is_empty() and (settled_save.get("history") as Array).size() == 1, "settlement_allows_existing_weather_to_end_naturally")


func _check_save_schema_clock_authority_and_atomic_apply() -> void:
	_reset_weather_and_clock(0)
	_expect(_weather.call("schedule_forecast", "ion_storm", 0, 1, 30.0, 45.0, "acceptance", false), "save_schema_seed_event_schedules")
	var save_data: Dictionary = _weather.call("to_save_data")
	var missing: Array[String] = []
	for key in REQUIRED_V2_SAVE_KEYS:
		if not save_data.has(str(key)):
			missing.append(str(key))
	_expect(int(save_data.get("schema_version", 0)) == WEATHER_SCHEMA_VERSION and missing.is_empty(), "weather_save_schema_v2_complete|missing=%s" % [missing])
	var non_world_time_keys: Array[String] = []
	_collect_non_world_time_keys(save_data, "weather", non_world_time_keys)
	_expect(non_world_time_keys.is_empty(), "weather_save_uses_absolute_world_us_boundaries_only|keys=%s" % [non_world_time_keys])
	_expect(not _contains_key_fragment(save_data, ["game_time", "clock", "time_scale", "ui", "camera", "selected"]), "weather_save_stores_no_second_clock_or_ui_state")

	var before: Dictionary = _weather.call("to_save_data")
	var malformed := before.duplicate(true)
	malformed["events"] = "not-an-array"
	var malformed_receipt: Dictionary = _weather.call("apply_save_data", malformed)
	_expect(not bool(malformed_receipt.get("applied", true)) and _same_data(before, _weather.call("to_save_data")), "malformed_apply_fails_closed_without_partial_pollution")

	_reset_weather_and_clock(0)
	_world.game_time = 1.25
	var session_payload := {
		"game_session_runtime": {
			"schema_version": 1,
			"ruleset_id": "v0.6",
			"session_state": "running",
			"session_id": "weather-v1-clock-authority",
			"scenario_id": "weather-v1",
			"seed": 77,
			"setup": {},
			"outcome_receipt": {},
			"world_effective_us": 777_000_000,
		}
	}
	var session_receipt: Dictionary = _session.call("apply_save_data", session_payload) if _session != null and _session.has_method("apply_save_data") else {}
	var restored_payload := _weather_save_payload([_event_payload(11, "deep_freeze", 0, "natural", 700_000_000, 700_000_000, 710_000_000, 800_000_000, 810_000_000)])
	var weather_receipt: Dictionary = _weather.call("apply_save_data", restored_payload)
	var restored_public: Dictionary = _weather.call("public_snapshot")
	var restored_active: Array = _weather.call("active_zones_snapshot")
	_expect(bool(session_receipt.get("applied", false)) and bool(weather_receipt.get("applied", false)), "session_then_weather_apply_receipts_succeed")
	_expect(int(_clock.call("world_effective_micros")) == 777_000_000 and int(restored_public.get("world_effective_us", -1)) == 777_000_000, "game_session_world_effective_us_is_final_clock_authority")
	_expect(restored_active.size() == 1 and str((restored_active[0] as Dictionary).get("phase", "")) == PHASE_ACTIVE, "weather_restore_uses_restored_world_effective_clock_instead_of_game_time")


func _check_privacy_surfaces() -> void:
	_reset_weather_and_clock(WEATHER_START_GRACE_US)
	_weather.call("tick", 0.0)
	var before_public: Dictionary = _weather.call("public_snapshot")
	_world.players[0]["cash"] = 987654321
	_world.players[0]["hand"] = ["WEATHER_V1_PRIVATE_HAND_SENTINEL", "WEATHER_V1_PRIVATE_RNG_SENTINEL"]
	_world.players[0]["discard"] = ["WEATHER_V1_PRIVATE_DISCARD_SENTINEL"]
	_world.players[0]["city_guesses"] = {1: "WEATHER_V1_PRIVATE_CITY_GUESS_SENTINEL"}
	_world.players[0]["ai_private_plan"] = "WEATHER_V1_PRIVATE_AI_PLAN_SENTINEL"
	_world.auto_monsters[0]["owner"] = "WEATHER_V1_PRIVATE_OWNER_SENTINEL"
	_world.selected_district = 2
	_world.camera_state = {"center": "WEATHER_V1_PRIVATE_CAMERA_SENTINEL", "zoom": 99.0}
	var after_public: Dictionary = _weather.call("public_snapshot")
	_expect(_same_data(before_public, after_public), "public_weather_snapshot_invariant_to_private_player_owner_ai_camera_mutations")
	var save_data: Dictionary = _weather.call("to_save_data")
	var telemetry: Dictionary = save_data.get("telemetry", {}) if save_data.get("telemetry", {}) is Dictionary else {}
	var public_leaks: Array[String] = []
	var save_leaks: Array[String] = []
	var telemetry_leaks: Array[String] = []
	_collect_privacy_leaks(after_public, "public", public_leaks, true)
	_collect_privacy_leaks(save_data, "save", save_leaks, false)
	_collect_privacy_leaks(telemetry, "telemetry", telemetry_leaks, false)
	_expect(public_leaks.is_empty(), "public_weather_snapshot_has_no_private_recursive_fields|leaks=%s" % [public_leaks])
	_expect(save_leaks.is_empty(), "weather_save_payload_has_no_private_canary_or_forbidden_keys|leaks=%s" % [save_leaks])
	_expect(telemetry_leaks.is_empty(), "weather_telemetry_has_no_private_canary_or_forbidden_keys|leaks=%s" % [telemetry_leaks])
	_expect(_all_source_types_public_safe(after_public) and _all_source_types_public_safe(save_data), "weather_public_and_save_sources_are_limited_to_natural_card_monster")


func _weather_save_payload(events: Array) -> Dictionary:
	return {
		"schema_version": WEATHER_SCHEMA_VERSION,
		"events": events.duplicate(true),
		"queue": [],
		"next_generation_world_us": 900_000_000,
		"sequence": events.size(),
		"history": [],
		"region_history": {},
		"telemetry": {},
	}


func _event_payload(id: int, type_id: String, region_index: int, source_type: String, created_us: int, forecast_start_us: int, active_start_us: int, active_end_us: int, fade_end_us: int) -> Dictionary:
	return {
		"event_schema_version": WEATHER_EVENT_SCHEMA_VERSION,
		"id": id,
		"definition_id": type_id,
		"type": type_id,
		"region_indices": [region_index],
		"districts": [region_index],
		"phase": PHASE_FORECAST,
		"source_type": source_type,
		"created_at_world_us": created_us,
		"forecast_starts_at_world_us": forecast_start_us,
		"active_starts_at_world_us": active_start_us,
		"active_ends_at_world_us": active_end_us,
		"fade_ends_at_world_us": fade_end_us,
		"forecast_duration_world_us": active_start_us - forecast_start_us,
		"active_duration_world_us": active_end_us - active_start_us,
		"fade_duration_world_us": fade_end_us - active_end_us,
	}


func _event_entries(snapshot: Dictionary) -> Array:
	var result: Array = []
	var canonical_events: Variant = snapshot.get("events")
	if canonical_events is Array and not (canonical_events as Array).is_empty():
		for item in canonical_events:
			if item is Dictionary:
				result.append(item)
		return result
	for key in ["forecast", "active_zones"]:
		var value: Variant = snapshot.get(key)
		if value is Dictionary and not (value as Dictionary).is_empty():
			result.append(value)
		elif value is Array:
			for item in value:
				if item is Dictionary:
					result.append(item)
	return result


func _all_source_types_public_safe(value: Variant) -> bool:
	var sources: Array[String] = []
	_collect_source_types(value, sources)
	for source_type in sources:
		if source_type not in ["natural", "card", "monster"]:
			return false
	return true


func _collect_source_types(value: Variant, out: Array[String]) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) == "source_type":
				out.append(str((value as Dictionary).get(key_variant)))
			_collect_source_types((value as Dictionary).get(key_variant), out)
	elif value is Array:
		for item in value:
			_collect_source_types(item, out)


func _collect_privacy_leaks(value: Variant, path: String, out: Array[String], scan_key_tokens: bool) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if scan_key_tokens:
				var lowered := key.to_lower()
				for token in FORBIDDEN_PRIVACY_KEY_TOKENS:
					if lowered.contains(token):
						out.append("%s.%s" % [path, key])
			_collect_privacy_leaks((value as Dictionary)[key_variant], "%s.%s" % [path, key], out, scan_key_tokens)
	elif value is Array:
		var index := 0
		for item in value:
			_collect_privacy_leaks(item, "%s[%d]" % [path, index], out, scan_key_tokens)
			index += 1
	elif value is String:
		var text := str(value)
		for canary in PRIVATE_CANARIES:
			if text.contains(canary):
				out.append("%s=<%s>" % [path, canary])


func _collect_non_world_time_keys(value: Variant, path: String, out: Array[String]) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var lowered := key.to_lower()
			if _looks_like_time_key(lowered) and not lowered.ends_with("_world_us") and lowered != "schema_version" and lowered != "event_schema_version":
				out.append("%s.%s" % [path, key])
			_collect_non_world_time_keys((value as Dictionary)[key_variant], "%s.%s" % [path, key], out)
	elif value is Array:
		var index := 0
		for item in value:
			_collect_non_world_time_keys(item, "%s[%d]" % [path, index], out)
			index += 1


func _looks_like_time_key(key: String) -> bool:
	for token in ["time", "created_at", "starts_at", "started_at", "ends_at", "duration", "remaining", "clock"]:
		if key.contains(token):
			return true
	return false


func _contains_key_fragment(value: Variant, fragments: Array[String]) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var lowered := str(key_variant).to_lower()
			for fragment in fragments:
				if lowered.contains(fragment):
					return true
			if _contains_key_fragment((value as Dictionary)[key_variant], fragments):
				return true
	elif value is Array:
		for item in value:
			if _contains_key_fragment(item, fragments):
				return true
	return false


func _same_data(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a) == JSON.stringify(b)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("WEATHER_V1_SAVE_PRIVACY_ACCEPTANCE: %s" % label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("WEATHER_V1_SAVE_PRIVACY_ACCEPTANCE|status=%s|checks=%d|failures=%d|labels=%s" % [
		status,
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
