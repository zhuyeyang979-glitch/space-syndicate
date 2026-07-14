extends SceneTree

const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const WEATHER_SPEC_PATH := "res://docs/weather_system_v1_spec.md"
const EXPECTED_SECTION_COUNT := 18
const WEATHER_SECTION_ID := "weather"
const FORBIDDEN_SECTION_TOKENS := ["solar", "sunlight", "planet_rotation", "rotation", "sun"]
const FORBIDDEN_PUBLIC_TOKENS := [
	"player_index", "player", "cash", "cash_cents", "hand", "discard",
	"owner", "hidden_owner", "city_guesses", "ai_plan", "camera", "rng",
	"private_source", "selected_player", "selected_district",
]
const REQUIRED_V2_SAVE_KEYS := [
	"schema_version",
	"events",
	"queue",
	"next_natural_forecast_at_world_us",
	"sequence",
	"history",
	"telemetry",
]
const REQUIRED_V1_METHODS := [
	"weather_v1_tick_world_us",
	"weather_v1_public_snapshot",
	"weather_v1_to_save_data",
	"weather_v1_validate_save_data",
	"weather_v1_apply_save_data",
	"weather_v1_set_final_settlement_block",
	"weather_v1_market_opened",
]


class FakeWeatherWorld:
	extends Node

	var rng := RandomNumberGenerator.new()
	var game_time := 0.0
	var selected_district := 0
	var districts := [
		{"name": "Alpha", "destroyed": false, "terrain": "land", "neighbors": [1], "city": {"active": true}},
		{"name": "Beta", "destroyed": false, "terrain": "ocean", "neighbors": [0], "city": {"active": false}},
	]
	var players := [
		{"cash": 123456, "hand": ["WEATHER_V1_PRIVATE_HAND_SENTINEL"], "private_discard": ["WEATHER_V1_PRIVATE_DISCARD_SENTINEL"], "city_guesses": {0: 1}, "ai_private_plan": "WEATHER_V1_AI_PRIVATE_PLAN"},
		{"cash": 654321, "hand": [], "private_discard": [], "city_guesses": {}, "ai_private_plan": ""},
	]
	var action_callouts: Array = []
	var log_lines: Array = []

	func _ready() -> void:
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


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(COORDINATOR_SCENE_PATH), "coordinator_scene_exists")
	_expect(FileAccess.file_exists(WEATHER_SPEC_PATH), "weather_v1_spec_exists")
	var packed := load(COORDINATOR_SCENE_PATH) as PackedScene
	if packed == null:
		_finish()
		return

	var world := FakeWeatherWorld.new()
	world.name = "WeatherV1AcceptanceWorld"
	root.add_child(world)
	var coordinator := packed.instantiate()
	root.add_child(coordinator)
	await process_frame

	var session := coordinator.get_node_or_null("GameSessionRuntimeController")
	var save := session.get_node_or_null("GameSaveRuntimeCoordinator") if session != null else null
	var handshake := save.get_node_or_null("RulesetSaveHandshakeService") if save != null else null
	var registry := session.get_node_or_null("V06SaveOwnerRegistry") if session != null else null
	var weather := coordinator.get_node_or_null("WeatherRuntimeController")
	var weather_bridge := coordinator.get_node_or_null("WeatherRuntimeWorldBridge")
	var clock := coordinator.get_node_or_null("WorldEffectiveClockRuntimeController")

	if clock != null and clock.has_method("configure"):
		clock.call("configure", {})
	if session != null and session.has_method("set_world_effective_clock"):
		session.call("set_world_effective_clock", clock)
	if session != null and session.has_method("configure"):
		session.call("configure", {"ruleset_id": "v0.6"}, {})
	if weather_bridge != null and weather_bridge.has_method("bind_world"):
		weather_bridge.call("bind_world", world)
	if weather != null and weather.has_method("set_world_bridge"):
		weather.call("set_world_bridge", weather_bridge)
	if weather != null and weather.has_method("configure"):
		weather.call("configure", {"ruleset_id": "v0.6"})

	_expect(session != null and save != null and handshake != null and registry != null, "save_owner_stack_reachable")
	_expect(weather != null, "weather_runtime_owner_reachable")
	_expect(clock != null, "world_effective_clock_owner_reachable")
	if handshake != null and registry != null:
		_check_save_section_boundary(handshake, registry)
	if weather != null:
		_check_public_privacy(weather)
		_check_v1_capabilities(weather)
		_check_save_schema_v2(weather)
		_check_validate_then_commit(weather)
		_check_lifecycle_contracts(weather)
	if session != null and clock != null:
		_check_session_clock_authority(session, clock)

	root.remove_child(coordinator)
	coordinator.queue_free()
	root.remove_child(world)
	world.queue_free()
	await process_frame
	_finish()


func _check_save_section_boundary(handshake: Node, registry: Node) -> void:
	var manifest: Dictionary = handshake.call("required_section_manifest") if handshake.has_method("required_section_manifest") else {}
	var order: Array = registry.call("fixed_section_order") if registry.has_method("fixed_section_order") else []
	var weather_count := 0
	var forbidden_sections: Array[String] = []
	for section_variant in manifest.keys():
		var section_id := str(section_variant)
		var lowered := section_id.to_lower()
		if section_id == WEATHER_SECTION_ID:
			weather_count += 1
		elif lowered.contains("weather"):
			forbidden_sections.append(section_id)
		for token in FORBIDDEN_SECTION_TOKENS:
			if lowered.contains(token):
				forbidden_sections.append(section_id)
	_expect(manifest.size() == EXPECTED_SECTION_COUNT and order.size() == EXPECTED_SECTION_COUNT, "weather_v1_save_registry_still_has_exactly_18_sections")
	_expect(weather_count == 1 and manifest.has(WEATHER_SECTION_ID) and order.has(WEATHER_SECTION_ID), "weather_v1_reuses_existing_weather_section")
	_expect(forbidden_sections.is_empty(), "weather_v1_no_solar_or_weather_19th_section|sections=%s" % [forbidden_sections])
	var binding := _binding_snapshot(registry, WEATHER_SECTION_ID)
	_expect(str(binding.get("owner_id", "")) == "weather_runtime", "weather_v1_section_owned_by_weather_runtime")


func _check_public_privacy(weather: Node) -> void:
	if weather.has_method("replace_runtime_state"):
		weather.call("replace_runtime_state", {
			"id": 42,
			"type": "solar_storm",
			"definition_id": "ion_storm",
			"display_name": "Ion Storm",
			"districts": [0],
			"created_at": 1.0,
			"starts_at": 90.0,
			"duration": 45.0,
			"source": "WEATHER_V1_PRIVATE_SOURCE_SENTINEL",
			"source_type": "natural",
			"owner": "WEATHER_V1_OWNER_SENTINEL",
			"player_index": 1,
			"cash_cents": 987654321,
			"hand": ["WEATHER_V1_PRIVATE_HAND_SENTINEL"],
			"discard": ["WEATHER_V1_PRIVATE_DISCARD_SENTINEL"],
			"city_guesses": {0: 2},
			"ai_plan": "WEATHER_V1_AI_PRIVATE_PLAN",
			"camera": {"zoom": 7},
			"rng_state": 12345,
		}, [], 42)
	var snapshot: Dictionary = weather.call("public_snapshot") if weather.has_method("public_snapshot") else {}
	var leaks: Array[String] = []
	_collect_forbidden_public_paths(snapshot, "public", leaks)
	_expect(not snapshot.is_empty(), "weather_v1_public_snapshot_available")
	_expect(leaks.is_empty(), "weather_v1_public_snapshot_has_no_private_recursive_fields|leaks=%s" % [leaks])
	_expect(_event_entries(snapshot).size() > 0, "weather_v1_public_snapshot_exposes_event_entries")
	_expect(_public_entries_have_source_type(snapshot), "weather_v1_public_snapshot_exposes_public_source_type_without_private_source")


func _check_v1_capabilities(weather: Node) -> void:
	var missing: Array[String] = []
	for method_name in REQUIRED_V1_METHODS:
		if not weather.has_method(method_name):
			missing.append(method_name)
	_expect(missing.is_empty(), "weather_v1_core_api_available|missing=%s" % [missing])


func _check_save_schema_v2(weather: Node) -> void:
	var save_data: Dictionary = weather.call("weather_v1_to_save_data") if weather.has_method("weather_v1_to_save_data") else (weather.call("to_save_data") if weather.has_method("to_save_data") else {})
	var missing: Array[String] = []
	for key in REQUIRED_V2_SAVE_KEYS:
		if not save_data.has(key):
			missing.append(key)
	var non_world_time_keys: Array[String] = []
	_collect_non_world_time_keys(save_data, "weather", non_world_time_keys)
	_expect(int(save_data.get("schema_version", 0)) == 2 and missing.is_empty(), "weather_v1_save_schema_v2_complete|missing=%s" % [missing])
	_expect(non_world_time_keys.is_empty(), "weather_v1_save_uses_absolute_world_us_boundaries_only|keys=%s" % [non_world_time_keys])
	_expect(not _contains_key_fragment(save_data, ["game_time", "clock", "time_scale", "ui", "camera"]), "weather_v1_save_stores_no_second_clock_or_ui_state")


func _check_validate_then_commit(weather: Node) -> void:
	if not weather.has_method("to_save_data") or not weather.has_method("apply_save_data"):
		_expect(false, "weather_v1_validate_then_commit_api_missing")
		return
	if weather.has_method("replace_runtime_state"):
		weather.call("replace_runtime_state", {
			"id": 5,
			"type": "solar_storm",
			"districts": [0],
			"created_at": 10.0,
			"starts_at": 100.0,
			"duration": 45.0,
			"source_type": "natural",
		}, [], 5)
	var before: Dictionary = weather.call("to_save_data")
	var malformed := {
		"schema_version": 2,
		"events": "not-an-array",
		"weather_forecast": "not-a-dictionary",
		"active_weather_zones": "not-an-array",
		"weather_sequence": "not-an-int",
	}
	var receipt: Dictionary = weather.call("weather_v1_apply_save_data", malformed) if weather.has_method("weather_v1_apply_save_data") else weather.call("apply_save_data", malformed)
	var after: Dictionary = weather.call("to_save_data")
	var rejected := not bool(receipt.get("applied", receipt.get("ok", true)))
	_expect(rejected and _same_data(before, after), "weather_v1_malformed_apply_fails_closed_without_partial_pollution|receipt=%s" % [receipt])


func _check_lifecycle_contracts(weather: Node) -> void:
	_expect(weather.has_method("weather_v1_tick_world_us"), "weather_v1_lifecycle_uses_integer_world_us_tick_api")
	_expect(weather.has_method("weather_v1_opening_grace_snapshot"), "weather_v1_opening_grace_90s_gate_available")
	_expect(weather.has_method("weather_v1_set_final_settlement_block"), "weather_v1_settlement_blocks_new_natural_forecasts_api_available")
	_expect(weather.has_method("weather_v1_market_opened"), "weather_v1_market_open_does_not_pause_weather_api_available")
	_expect(weather.has_method("weather_v1_pause_snapshot"), "weather_v1_true_pause_freeze_gate_available")
	_expect(weather.has_method("weather_v1_conflicting_region_queue_snapshot"), "weather_v1_max_two_and_same_region_queue_gate_available")
	if not weather.has_method("weather_v1_public_snapshot"):
		_expect(false, "weather_v1_natural_source_type_only_before_card_or_monster_sources")


func _check_session_clock_authority(session: Node, clock: Node) -> void:
	var payload := {
		"game_session_runtime": {
			"schema_version": 1,
			"ruleset_id": "v0.6",
			"session_state": "running",
			"session_id": "weather-v1-acceptance",
			"scenario_id": "weather-v1",
			"seed": 123,
			"setup": {},
			"outcome_receipt": {},
			"world_effective_us": 123456789,
		}
	}
	var receipt: Dictionary = session.call("apply_save_data", payload) if session.has_method("apply_save_data") else {}
	var snapshot: Dictionary = clock.call("snapshot") if clock.has_method("snapshot") else {}
	_expect(bool(receipt.get("applied", false)) and int(snapshot.get("world_effective_us", -1)) == 123456789, "game_session_world_effective_us_restores_integer_clock")
	_expect(session.has_method("apply_save_data") and clock.has_method("world_effective_micros"), "weather_v1_restore_order_can_use_session_clock_as_authority")


func _binding_snapshot(registry: Node, section_id: String) -> Dictionary:
	var bindings_variant: Variant = registry.get("bindings")
	var bindings: Array = bindings_variant if bindings_variant is Array else []
	for binding in bindings:
		if binding == null or str(binding.get("section_id")) != section_id:
			continue
		return binding.call("contract_snapshot") if binding.has_method("contract_snapshot") else {
			"section_id": str(binding.get("section_id")),
			"owner_id": str(binding.get("owner_id")),
		}
	return {}


func _event_entries(snapshot: Dictionary) -> Array:
	var result: Array = []
	for key in ["events", "forecast", "active", "active_zones", "queue"]:
		var value: Variant = snapshot.get(key)
		if value is Dictionary and not (value as Dictionary).is_empty():
			result.append(value)
		elif value is Array:
			for entry in value:
				if entry is Dictionary:
					result.append(entry)
	return result


func _public_entries_have_source_type(snapshot: Dictionary) -> bool:
	var entries := _event_entries(snapshot)
	if entries.is_empty():
		return false
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		if str(entry.get("source_type", "")) == "natural" and not entry.has("source"):
			return true
	return false


func _collect_forbidden_public_paths(value: Variant, path: String, out: Array[String]) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var lowered := key.to_lower()
			for token in FORBIDDEN_PUBLIC_TOKENS:
				if lowered.contains(token):
					out.append("%s.%s" % [path, key])
			_collect_forbidden_public_paths((value as Dictionary)[key_variant], "%s.%s" % [path, key], out)
	elif value is Array:
		var index := 0
		for item in value:
			_collect_forbidden_public_paths(item, "%s[%d]" % [path, index], out)
			index += 1
	elif value is String:
		var lowered_value := str(value).to_lower()
		for token in FORBIDDEN_PUBLIC_TOKENS:
			if lowered_value.contains(token):
				out.append("%s=<string:%s>" % [path, token])


func _collect_non_world_time_keys(value: Variant, path: String, out: Array[String]) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var lowered := key.to_lower()
			if _looks_like_time_key(lowered) and not lowered.ends_with("_world_us") and lowered != "schema_version":
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
