@tool
extends Node
class_name WeatherRuntimeController

var _table_presentation_refresh_port: TablePresentationRefreshPort
var _public_log_producer_port: PublicLogProducerPort
var _presentation_world_clock: WorldEffectiveClockRuntimeController

const DEFAULT_DEFINITION_CATALOG := preload("res://resources/weather/weather_definition_catalog_v1.tres")

const FORECAST_LEAD_MIN_SECONDS := WeatherSystem.FORECAST_LEAD_MIN_SECONDS
const FORECAST_LEAD_MAX_SECONDS := WeatherSystem.FORECAST_LEAD_MAX_SECONDS
const DURATION_MIN_SECONDS := WeatherSystem.ACTIVE_MIN_SECONDS
const DURATION_MAX_SECONDS := WeatherSystem.ACTIVE_MAX_SECONDS
const ZONE_MAX := WeatherSystem.DEFAULT_AFFECTED_REGION_COUNT
const WEATHER_TYPES := {
	"ion_storm": {"label": "离子风暴", "display_name": "离子风暴"},
	"gravity_tide": {"label": "引力潮", "display_name": "引力潮"},
	"spore_season": {"label": "孢子季", "display_name": "孢子季"},
	"crystal_dust_storm": {"label": "晶尘暴", "display_name": "晶尘暴"},
	"deep_freeze": {"label": "极寒期", "display_name": "极寒期"},
	"solar_flare": {"label": "太阳耀斑", "display_name": "太阳耀斑"},
}
const SOURCE_TYPE_NATURAL := "natural"
const SOURCE_TYPE_CARD := "card"
const SOURCE_TYPE_MONSTER := "monster"
const SOURCE_TYPES := [SOURCE_TYPE_NATURAL, SOURCE_TYPE_CARD, SOURCE_TYPE_MONSTER]

@export var definition_catalog: Resource = DEFAULT_DEFINITION_CATALOG

var _world_bridge: WeatherRuntimeWorldBridge
var _product_market_runtime_controller: ProductMarketRuntimeController
var _route_network_runtime_controller: RouteNetworkRuntimeController
var _region_infrastructure_world_bridge: RegionInfrastructureWorldBridge
var _weather_telemetry_runtime_service: Node
var _visual_cue_runtime_owner: VisualCueRuntimeOwner
var _world_effective_clock: Node
var _ruleset_snapshot: Dictionary = {}
var _configured := false
var _new_forecasts_allowed := true
var _system := WeatherSystem.new()
var _resolver := WeatherEffectResolver.new()

var weather_forecast: Dictionary = {}
var active_weather_zones: Array = []
var weather_sequence := 0

var _events: Array = []
var _queue: Array = []
var _history: Array = []
var _region_history: Dictionary = {}
var _telemetry: Dictionary = {}
var _next_generation_world_us := WeatherSystem.START_GRACE_US


func _ready() -> void:
	_bind_clock_from_scene()


func set_world_bridge(bridge: WeatherRuntimeWorldBridge) -> void:
	_world_bridge = bridge
	_configured = _compute_configured()


func set_world_effective_clock(clock: Node) -> void:
	_world_effective_clock = clock
	_configured = _compute_configured()


func set_new_forecasts_allowed(allowed: bool) -> void:
	_new_forecasts_allowed = allowed


func set_product_market_runtime_controller(controller: ProductMarketRuntimeController) -> void:
	_product_market_runtime_controller = controller


func set_route_network_runtime_controller(controller: RouteNetworkRuntimeController) -> void:
	_route_network_runtime_controller = controller


func set_region_infrastructure_world_bridge(bridge: RegionInfrastructureWorldBridge) -> void:
	_region_infrastructure_world_bridge = bridge


func set_weather_telemetry_runtime_service(service: Node) -> void:
	_weather_telemetry_runtime_service = service


func set_visual_cue_runtime_owner(cue_owner: VisualCueRuntimeOwner) -> void:
	_visual_cue_runtime_owner = cue_owner


func configure(ruleset_snapshot: Dictionary) -> void:
	_ruleset_snapshot = ruleset_snapshot.duplicate(true)
	_bind_clock_from_scene()
	_configured = _compute_configured()
	_refresh_legacy_projection()


func set_table_presentation_ports(refresh_port: TablePresentationRefreshPort, log_port: PublicLogProducerPort, clock: WorldEffectiveClockRuntimeController) -> void:
	_table_presentation_refresh_port = refresh_port
	_public_log_producer_port = log_port
	_presentation_world_clock = clock


func reset_state() -> void:
	_events.clear()
	_queue.clear()
	_history.clear()
	_region_history.clear()
	_telemetry.clear()
	_next_generation_world_us = WeatherSystem.START_GRACE_US
	weather_sequence = 0
	if _weather_telemetry_runtime_service != null and _weather_telemetry_runtime_service.has_method("clear"):
		_weather_telemetry_runtime_service.call("clear")
	_refresh_legacy_projection()


static func build_new_session_plan(cursor: Dictionary, districts: Array, now_us := 0) -> Dictionary:
	if int(cursor.get("schema_version", 0)) != 1 or int(cursor.get("rng_state", 0)) == 0:
		return {"ok": false, "reason_code": "weather_new_session_rng_cursor_invalid"}
	var catalog := DEFAULT_DEFINITION_CATALOG as WeatherDefinitionCatalog
	if catalog == null or not bool(catalog.validate_catalog().get("valid", false)):
		return {"ok": false, "reason_code": "weather_new_session_catalog_invalid"}
	var candidates := _new_session_region_candidates(districts)
	if candidates.is_empty():
		return {"ok": false, "reason_code": "weather_new_session_region_missing"}
	var next_cursor := cursor.duplicate(true)
	var region_draw := RunRngService.detached_randi_range(next_cursor, 0, candidates.size() - 1)
	if not bool(region_draw.get("ok", false)):
		return region_draw
	next_cursor = _cursor_from_detached_draw(region_draw)
	var region_index := int(candidates[int(region_draw.get("value", 0))])
	var definition_ids := catalog.definition_ids()
	if definition_ids.is_empty():
		return {"ok": false, "reason_code": "weather_new_session_definition_missing"}
	var definition_draw := RunRngService.detached_randi_range(next_cursor, 0, definition_ids.size() - 1)
	if not bool(definition_draw.get("ok", false)):
		return definition_draw
	next_cursor = _cursor_from_detached_draw(definition_draw)
	var definition := catalog.definition(str(definition_ids[int(definition_draw.get("value", 0))]))
	if definition == null:
		return {"ok": false, "reason_code": "weather_new_session_definition_invalid"}
	var generation_draw := RunRngService.detached_randi_range(next_cursor, WeatherSystem.GENERATION_MIN_US, WeatherSystem.GENERATION_MAX_US)
	if not bool(generation_draw.get("ok", false)):
		return generation_draw
	next_cursor = _cursor_from_detached_draw(generation_draw)
	var forecast_us := int(round(clampf(definition.forecast_duration, WeatherSystem.FORECAST_LEAD_MIN_SECONDS, WeatherSystem.FORECAST_LEAD_MAX_SECONDS) * 1_000_000.0))
	var active_us := int(round(clampf(definition.active_duration, WeatherSystem.ACTIVE_MIN_SECONDS, WeatherSystem.ACTIVE_MAX_SECONDS) * 1_000_000.0))
	var fade_us := int(round(maxf(0.0, definition.fade_duration) * 1_000_000.0))
	var event := {
		"event_schema_version": WeatherRuntimeState.EVENT_SCHEMA_VERSION,
		"id": 1,
		"definition_id": definition.id,
		"type": definition.id,
		"region_indices": [region_index],
		"districts": [region_index],
		"phase": WeatherRuntimeState.PHASE_FORECAST,
		"source_type": SOURCE_TYPE_NATURAL,
		"created_at_world_us": now_us,
		"forecast_starts_at_world_us": now_us,
		"active_starts_at_world_us": now_us + forecast_us,
		"active_ends_at_world_us": now_us + forecast_us + active_us,
		"fade_ends_at_world_us": now_us + forecast_us + active_us + fade_us,
		"forecast_duration_world_us": forecast_us,
		"active_duration_world_us": active_us,
		"fade_duration_world_us": fade_us,
	}
	return {
		"ok": true,
		"reason_code": "weather_new_session_plan_ready",
		"state": {
			"schema_version": WeatherRuntimeState.SCHEMA_VERSION,
			"events": [event],
			"queue": [],
			"next_generation_world_us": now_us + int(generation_draw.get("value", WeatherSystem.GENERATION_MIN_US)),
			"sequence": 1,
			"history": [],
			"region_history": {str(region_index): 1},
			"telemetry": {"scheduled_forecast": 1, "scheduled_natural": 1},
		},
		"cursor": next_cursor,
		"draw_count_delta": int(next_cursor.get("draw_count", 0)) - int(cursor.get("draw_count", 0)),
	}


func preflight_new_session(plan_state: Dictionary) -> Dictionary:
	var validation := WeatherRuntimeState.validate_save_payload(plan_state, weather_type_ids())
	if not bool(validation.get("valid", false)):
		return {"accepted": false, "reason_code": "weather_new_session_plan_invalid", "details": validation}
	if (plan_state.get("events", []) as Array).size() != 1 or int(plan_state.get("sequence", 0)) != 1:
		return {"accepted": false, "reason_code": "weather_new_session_forecast_missing"}
	return {"accepted": true, "reason_code": "weather_new_session_plan_valid"}


func apply_new_session_plan(plan_state: Dictionary) -> Dictionary:
	var preflight := preflight_new_session(plan_state)
	if not bool(preflight.get("accepted", false)):
		return {"applied": false, "reason_code": str(preflight.get("reason_code", "weather_new_session_plan_invalid"))}
	var result := apply_save_data(plan_state)
	return {
		"applied": bool(result.get("applied", false)),
		"reason_code": "weather_new_session_plan_applied" if bool(result.get("applied", false)) else str(result.get("reason", "weather_new_session_apply_failed")),
	}


func commit_new_session_presentation() -> Dictionary:
	if weather_forecast.is_empty():
		return {"committed": true, "reason_code": "weather_new_session_presentation_empty"}
	var definition := _definition(str(weather_forecast.get("definition_id", weather_forecast.get("type", ""))))
	if definition == null:
		return {"committed": true, "reason_code": "weather_new_session_presentation_definition_unavailable"}
	_announce_forecast(weather_forecast, definition)
	_log("天气预报：%s将在%s后影响%s。" % [definition.display_name, _duration_short_text(float(weather_forecast.get("forecast_duration_world_us", 0)) / 1_000_000.0), district_names(weather_forecast, 5)])
	_add_action_callout("星球气象台", "天气预报", status_text(), color(definition.id), _district_center(int(WeatherRuntimeState.event_region_indices(weather_forecast).front())), 6.0)
	return {"committed": true, "reason_code": "weather_new_session_presentation_committed"}


func tick(_delta_seconds: float) -> void:
	if not _configured:
		return
	var now_us := _now_us()
	var changed := _apply_region_weather_damage(now_us)
	changed = _advance_lifecycle(now_us) or changed
	changed = _release_waiting_queue(now_us) or changed
	if _system.can_generate_natural(now_us, _next_generation_world_us, _new_forecasts_allowed, _unended_event_count()):
		_schedule_natural_forecast(now_us)
		changed = true
	elif not _new_forecasts_allowed and now_us >= _next_generation_world_us:
		_increment_telemetry("blocked_settlement")
	if changed:
		_refresh_weather_dependents()
	_refresh_legacy_projection()


func template(type_id: String) -> Dictionary:
	var definition := _definition(type_id)
	return definition.to_dictionary() if definition != null else {}


func label(type_id: String) -> String:
	var definition := _definition(type_id)
	return definition.display_name if definition != null else type_id


func color(type_id: String) -> Color:
	var definition := _definition(type_id)
	return definition.accent_color if definition != null else Color("#93c5fd")


func weather_type_ids() -> Array:
	var catalog := _catalog()
	return catalog.definition_ids() if catalog != null else []


func weather_types_snapshot() -> Dictionary:
	var catalog := _catalog()
	return catalog.snapshot() if catalog != null else {}


func zone_count_for_planet() -> int:
	return WeatherSystem.DEFAULT_AFFECTED_REGION_COUNT


func district_names(entry: Dictionary, limit: int = 3) -> String:
	var names: Array = []
	var district_ids: Array = WeatherRuntimeState.event_region_indices(entry)
	var districts := _districts()
	for index in range(mini(limit, district_ids.size())):
		var district_index := int(district_ids[index])
		if district_index >= 0 and district_index < districts.size():
			names.append(str((districts[district_index] as Dictionary).get("name", "区域")))
	var suffix := ""
	if district_ids.size() > names.size():
		suffix = "等%d区" % district_ids.size()
	return (" / ".join(names) if not names.is_empty() else "未命名区域") + suffix


func pick_districts(anchor_index: int, _zone_count: int) -> Array:
	var alive := _alive_district_indices()
	if alive.is_empty():
		return []
	if alive.has(anchor_index):
		return [anchor_index]
	var region := _system.select_region(_region_facts(), _occupied_regions(), _region_history, _shared_rng())
	if region >= 0:
		return [region]
	return [int(alive[0])]


func preview_districts(anchor_index: int, zone_count: int) -> Array:
	return pick_districts(anchor_index, zone_count)


func schedule_forecast(type_id: String, anchor_index: int, _zone_count: int, lead_seconds: float, duration_seconds: float, _source: String, forced: bool = false) -> bool:
	if not _configured:
		return false
	var definition := _definition(type_id)
	if definition == null:
		definition = _first_definition()
	if definition == null:
		return false
	var regions := pick_districts(anchor_index, definition.affected_region_count)
	if regions.is_empty():
		return false
	var source_type := SOURCE_TYPE_CARD if forced else SOURCE_TYPE_NATURAL
	return _schedule_event(
		definition.id,
		regions,
		_definition_forecast_us(definition, lead_seconds),
		_definition_active_us(definition, duration_seconds),
		source_type,
		_now_us()
	)


func schedule_next_forecast(announce: bool = false) -> bool:
	if not _configured:
		return false
	var scheduled := _schedule_natural_forecast(_now_us())
	if scheduled and announce:
		var event := forecast_snapshot()
		_add_action_callout("星球气象台", "天气预报", status_text(), color(str(event.get("type", ""))), _district_center(int(WeatherRuntimeState.event_region_indices(event).front())), 6.0)
	return scheduled


func activate_forecast() -> bool:
	if weather_forecast.is_empty():
		return false
	var event_id := int(weather_forecast.get("id", 0))
	var now_us := _now_us()
	for event_variant in _events:
		if not (event_variant is Dictionary):
			continue
		var event := event_variant as Dictionary
		if int(event.get("id", 0)) != event_id:
			continue
		event["active_starts_at_world_us"] = now_us
		event["active_ends_at_world_us"] = now_us + int(event.get("active_duration_world_us", WeatherSystem.ACTIVE_MIN_US))
		event["fade_ends_at_world_us"] = int(event.get("active_ends_at_world_us", now_us)) + int(event.get("fade_duration_world_us", WeatherSystem.FADE_US))
		event["phase"] = WeatherRuntimeState.PHASE_ACTIVE
		_increment_telemetry("activated")
		_refresh_weather_dependents()
		_refresh_legacy_projection()
		return true
	return false


func apply_weather_control_at(skill: Dictionary, target_region_index: int) -> bool:
	if not _configured:
		return false
	if target_region_index < 0 or not _alive_district_indices().has(target_region_index):
		_increment_telemetry("rejected_invalid_target")
		return false
	var type_id := str(skill.get("weather_type", weather_type_ids().front() if not weather_type_ids().is_empty() else ""))
	var definition := _definition(type_id)
	if definition == null:
		definition = _first_definition()
	if definition == null:
		return false
	return _schedule_event(definition.id, [target_region_index], _definition_forecast_us(definition), _definition_active_us(definition), SOURCE_TYPE_CARD, _now_us())


func apply_weather_control(_skill: Dictionary) -> bool:
	_increment_telemetry("deprecated_apply_weather_control_rejected")
	return false


func entries_for_district(index: int) -> Array:
	var result: Array = []
	var now_us := _now_us()
	for event_variant in _events:
		if not (event_variant is Dictionary):
			continue
		var event := event_variant as Dictionary
		var phase := str(event.get("phase", ""))
		if not [WeatherRuntimeState.PHASE_ACTIVE, WeatherRuntimeState.PHASE_FADING].has(phase):
			continue
		if not WeatherRuntimeState.event_region_indices(event).has(index):
			continue
		var definition := _definition(str(event.get("definition_id", event.get("type", ""))))
		result.append(WeatherRuntimeState.public_event(event, now_us, definition, _system.intensity(event, now_us)))
	return result


func district_multiplier(index: int, key: String, default_value: float = 1.0) -> float:
	var multiplier := default_value
	var context := _legacy_context_for_multiplier_key(key)
	for entry_variant in _effect_entries_for_region(index, context):
		var effect := entry_variant as Dictionary
		match key:
			"price_growth_multiplier":
				multiplier *= float((effect.get("economy", {}) as Dictionary).get("price_growth_multiplier", 1.0))
			"production_multiplier":
				multiplier *= float((effect.get("economy", {}) as Dictionary).get("production_multiplier", 1.0))
			"consumption_multiplier", "demand_multiplier":
				multiplier *= float((effect.get("economy", {}) as Dictionary).get("demand_multiplier", 1.0))
			"maintenance_multiplier", "city_maintenance_multiplier":
				multiplier *= float((effect.get("economy", {}) as Dictionary).get("maintenance_multiplier", 1.0))
			"economy_multiplier":
				multiplier *= float((effect.get("economy", {}) as Dictionary).get("multiplier", 1.0))
			"transport_multiplier", "route_multiplier":
				multiplier *= float((effect.get("route", {}) as Dictionary).get("generic_multiplier", 1.0))
			"land_transport_multiplier", "land_movement_multiplier":
				multiplier *= float((effect.get("route", {}) as Dictionary).get("land_multiplier", 1.0))
			"ocean_transport_multiplier", "ocean_movement_multiplier":
				multiplier *= float((effect.get("route", {}) as Dictionary).get("ocean_multiplier", 1.0))
			"air_transport_multiplier", "air_movement_multiplier":
				multiplier *= float((effect.get("route", {}) as Dictionary).get("air_multiplier", 1.0))
			"monster_speed_multiplier":
				multiplier *= float((effect.get("monster", {}) as Dictionary).get("speed_multiplier", 1.0))
			"monster_armor_multiplier":
				multiplier *= float((effect.get("monster", {}) as Dictionary).get("armor_multiplier", 1.0))
			"monster_preference_multiplier":
				multiplier *= float((effect.get("monster", {}) as Dictionary).get("preference_multiplier", 1.0))
			"military_multiplier":
				multiplier *= float((effect.get("military", {}) as Dictionary).get("effect_multiplier", 1.0))
			"intel_multiplier":
				multiplier *= float((effect.get("intel", {}) as Dictionary).get("effect_multiplier", 1.0))
	return multiplier


func _legacy_context_for_multiplier_key(key: String) -> Dictionary:
	match key:
		"price_growth_multiplier":
			return {"product_tags": ["weather_energy", "weather_food", "weather_medicine", "weather_biological", "weather_crystal", "weather_electronic"]}
		"production_multiplier", "consumption_multiplier", "demand_multiplier", "economy_multiplier":
			return {"product_tags": ["weather_energy", "weather_food", "weather_medicine", "weather_biological", "weather_crystal", "weather_electronic"]}
		"maintenance_multiplier", "city_maintenance_multiplier":
			return {"context_tags": ["city", "maintenance"]}
		"transport_multiplier", "route_multiplier":
			return {"route_mode": "generic"}
		"land_transport_multiplier", "land_movement_multiplier":
			return {"movement_domain": "land"}
		"ocean_transport_multiplier", "ocean_movement_multiplier":
			return {"movement_domain": "ocean"}
		"air_transport_multiplier", "air_movement_multiplier":
			return {"movement_domain": "air"}
		"military_multiplier":
			return {"unit_tags": ["ranged", "knockback", "orbital", "flying"], "movement_domain": "land"}
		"intel_multiplier":
			return {"context_tags": ["intel"], "intel_domain": "duration"}
	return {}


func region_effect_snapshot(region_index: int, context: Dictionary = {}) -> Dictionary:
	return {
		"available": _configured,
		"region_index": region_index,
		"effects": _effect_entries_for_region(region_index, context),
	}


func district_summary(index: int) -> String:
	var entries := entries_for_district(index)
	if entries.is_empty():
		return "无活跃天气"
	var pieces: Array = []
	for entry_variant in entries:
		pieces.append(str((entry_variant as Dictionary).get("label", "天气")))
	return " / ".join(pieces)


func status_text() -> String:
	var active_text := "无活跃天气"
	if not active_weather_zones.is_empty():
		var entry := active_weather_zones[0] as Dictionary
		active_text = "%s影响%s" % [str(entry.get("label", label(str(entry.get("type", ""))))), district_names(entry, 2)]
	var forecast_text := "暂无预报"
	if not weather_forecast.is_empty():
		forecast_text = "%s即将到达%s" % [str(weather_forecast.get("label", label(str(weather_forecast.get("type", ""))))), district_names(weather_forecast, 2)]
	return "天气:%s｜预报:%s" % [active_text, forecast_text]


func active_ui_text() -> String:
	if active_weather_zones.is_empty():
		return "现在：无天气"
	var entry := active_weather_zones[0] as Dictionary
	var extra := " +%d" % (active_weather_zones.size() - 1) if active_weather_zones.size() > 1 else ""
	return "现在：%s%s｜%s" % [str(entry.get("label", label(str(entry.get("type", ""))))), extra, district_names(entry, 3)]


func forecast_ui_text() -> String:
	if weather_forecast.is_empty():
		return "预报：暂无下一条"
	var source_text := "卡牌干预" if str(weather_forecast.get("source_type", SOURCE_TYPE_NATURAL)) == SOURCE_TYPE_CARD else "气象台"
	var phase := str(weather_forecast.get("phase", WeatherRuntimeState.PHASE_FORECAST))
	var phase_text := "排队" if phase == WeatherRuntimeState.PHASE_QUEUED else "预报"
	return "%s：%s｜%s｜%s" % [phase_text, str(weather_forecast.get("label", label(str(weather_forecast.get("type", ""))))), district_names(weather_forecast, 3), source_text]


func impact_ui_text() -> String:
	var entry: Dictionary = {}
	if not active_weather_zones.is_empty():
		entry = active_weather_zones[0] as Dictionary
	elif not weather_forecast.is_empty():
		entry = weather_forecast
	if entry.is_empty():
		return "影响：经济/路线/怪兽/军情"
	var definition := _definition(str(entry.get("definition_id", entry.get("type", ""))))
	if definition == null:
		return "影响：经济/路线/怪兽/军情"
	return "影响：价×%.2f 产×%.2f 需×%.2f 路×%.2f 怪×%.2f 情×%.2f" % [
		definition.product_price_growth_multiplier,
		definition.production_multiplier,
		definition.demand_multiplier,
		definition.route_efficiency_multiplier,
		definition.monster_speed_multiplier,
		definition.intel_effect_multiplier,
	]


func planet_short_text() -> String:
	if not active_weather_zones.is_empty():
		return "活跃%d" % active_weather_zones.size()
	if not weather_forecast.is_empty():
		return "预报"
	return "平稳"


func has_forecast() -> bool:
	return not weather_forecast.is_empty()


func active_zone_count() -> int:
	return active_weather_zones.size()


func sequence_value() -> int:
	return weather_sequence


func forecast_snapshot() -> Dictionary:
	return weather_forecast.duplicate(true)


func active_zones_snapshot() -> Array:
	return active_weather_zones.duplicate(true)


func public_snapshot() -> Dictionary:
	var now_us := _now_us()
	return {
		"schema_version": WeatherRuntimeState.SCHEMA_VERSION,
		"world_effective_us": now_us,
		"forecast": weather_forecast.duplicate(true),
		"active_zones": active_weather_zones.duplicate(true),
		"events": _public_events(now_us),
		"queue": _queue.duplicate(true),
		"sequence": weather_sequence,
		"next_generation_world_us": _next_generation_world_us,
		"new_forecasts_allowed": _new_forecasts_allowed,
		"active_text": active_ui_text(),
		"forecast_text": forecast_ui_text(),
		"impact_text": impact_ui_text(),
		"status_text": status_text(),
		"short_text": planet_short_text(),
		"timing": {
			"forecast_min_seconds": WeatherSystem.FORECAST_LEAD_MIN_SECONDS,
			"forecast_max_seconds": WeatherSystem.FORECAST_LEAD_MAX_SECONDS,
			"active_min_seconds": WeatherSystem.ACTIVE_MIN_SECONDS,
			"active_max_seconds": WeatherSystem.ACTIVE_MAX_SECONDS,
			"fade_seconds": WeatherSystem.FADE_SECONDS,
			"generation_min_seconds": WeatherSystem.GENERATION_MIN_SECONDS,
			"generation_max_seconds": WeatherSystem.GENERATION_MAX_SECONDS,
			"start_grace_seconds": WeatherSystem.START_GRACE_SECONDS,
			"max_unended_events": WeatherSystem.MAX_UNENDED_EVENTS,
		},
	}


func replace_runtime_state(forecast: Dictionary, active_zones: Array, sequence: int = 0) -> void:
	_events.clear()
	_queue.clear()
	weather_sequence = maxi(0, sequence)
	if not forecast.is_empty():
		_events.append(_event_from_legacy(forecast, WeatherRuntimeState.PHASE_FORECAST))
	for entry_variant in active_zones:
		if entry_variant is Dictionary:
			_events.append(_event_from_legacy(entry_variant as Dictionary, WeatherRuntimeState.PHASE_ACTIVE))
	_refresh_legacy_projection()


func to_save_data() -> Dictionary:
	return {
		"schema_version": WeatherRuntimeState.SCHEMA_VERSION,
		"events": WeatherRuntimeState.duplicate_events(_events),
		"queue": _queue.duplicate(true),
		"next_generation_world_us": _next_generation_world_us,
		"sequence": weather_sequence,
		"history": _history.duplicate(true),
		"region_history": _region_history.duplicate(true),
		"telemetry": _telemetry.duplicate(true),
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	if data.is_empty():
		reset_state()
		return {"applied": true, "reason": "empty_payload_cleared", "schema_version": WeatherRuntimeState.SCHEMA_VERSION}
	if not data.has("schema_version"):
		reset_state()
		weather_sequence = maxi(0, int(data.get("weather_sequence", 0)))
		_increment_telemetry("flat_shape_failclosed_migration")
		_refresh_legacy_projection()
		return {"applied": true, "migrated_from_v1": true, "fail_closed": true, "forecast_present": false, "active_zone_count": 0, "sequence": weather_sequence}
	var validation := WeatherRuntimeState.validate_save_payload(data, weather_type_ids())
	if not bool(validation.get("valid", false)):
		return {"applied": false, "reason": str(validation.get("reason", "invalid_payload")), "schema_version": data.get("schema_version", null)}
	var next_events := WeatherRuntimeState.duplicate_events(data.get("events", []))
	var next_queue: Array = (data.get("queue", []) as Array).duplicate(true)
	var next_history: Array = (data.get("history", []) as Array).duplicate(true)
	var next_region_history: Dictionary = (data.get("region_history", {}) as Dictionary).duplicate(true)
	var next_telemetry: Dictionary = (data.get("telemetry", {}) as Dictionary).duplicate(true)
	_events = next_events
	_queue = next_queue
	_history = next_history
	_region_history = next_region_history
	_telemetry = next_telemetry
	_next_generation_world_us = int(data.get("next_generation_world_us", WeatherSystem.START_GRACE_US))
	weather_sequence = maxi(0, int(data.get("sequence", 0)))
	_refresh_legacy_projection()
	return {"applied": true, "schema_version": WeatherRuntimeState.SCHEMA_VERSION, "forecast_present": not weather_forecast.is_empty(), "active_zone_count": active_weather_zones.size(), "sequence": weather_sequence}


func debug_snapshot(_viewer_index: int = -1) -> Dictionary:
	var catalog := _catalog()
	var catalog_validation := catalog.validate_catalog() if catalog != null else {"valid": false, "reason": "catalog_missing"}
	var bridge_debug := _world_bridge.debug_snapshot() if _world_bridge != null else {}
	return {
		"controller_ready": _configured,
		"controller_authoritative": true,
		"runtime_owner": "WeatherRuntimeController",
		"parallel_legacy_owner": false,
		"schema_version": WeatherRuntimeState.SCHEMA_VERSION,
		"single_save_owner": true,
		"pure_services_own_save_state": false,
		"world_effective_clock_bound": _clock_ready(),
		"reads_game_time": false,
		"reads_selected_district": false,
		"reads_private_player_state": false,
		"new_forecasts_allowed": _new_forecasts_allowed,
		"forecast": weather_forecast.duplicate(true),
		"active_zones": active_weather_zones.duplicate(true),
		"events": _public_events(_now_us()),
		"queue": _queue.duplicate(true),
		"sequence": weather_sequence,
		"next_generation_world_us": _next_generation_world_us,
		"telemetry": _telemetry.duplicate(true),
		"forecast_lead_min_seconds": WeatherSystem.FORECAST_LEAD_MIN_SECONDS,
		"forecast_lead_max_seconds": WeatherSystem.FORECAST_LEAD_MAX_SECONDS,
		"duration_min_seconds": WeatherSystem.ACTIVE_MIN_SECONDS,
		"duration_max_seconds": WeatherSystem.ACTIVE_MAX_SECONDS,
		"fade_seconds": WeatherSystem.FADE_SECONDS,
		"generation_min_seconds": WeatherSystem.GENERATION_MIN_SECONDS,
		"generation_max_seconds": WeatherSystem.GENERATION_MAX_SECONDS,
		"start_grace_seconds": WeatherSystem.START_GRACE_SECONDS,
		"zone_max": WeatherSystem.DEFAULT_AFFECTED_REGION_COUNT,
		"max_unended_events": WeatherSystem.MAX_UNENDED_EVENTS,
		"weather_types": weather_types_snapshot(),
		"catalog_validation": catalog_validation,
		"world_bridge": bridge_debug,
		"deprecated_apply_weather_control_fails_closed": true,
	}


func _schedule_natural_forecast(now_us: int) -> bool:
	var rng := _shared_rng()
	var catalog := _catalog()
	if rng == null or catalog == null:
		return false
	var region := _system.select_region(_region_facts(), _occupied_regions(), _region_history, rng)
	var type_id := _system.select_definition_id(catalog.definition_ids(), rng)
	if region < 0 or type_id.is_empty():
		_next_generation_world_us = _system.next_generation_us(now_us, rng)
		_increment_telemetry("natural_no_region")
		return false
	var definition := _definition(type_id)
	if definition == null:
		_next_generation_world_us = _system.next_generation_us(now_us, rng)
		_increment_telemetry("natural_missing_definition")
		return false
	var lead_us := _definition_forecast_us(definition)
	var active_us := _definition_active_us(definition)
	var scheduled := _schedule_event(type_id, [region], lead_us, active_us, "natural", now_us)
	_next_generation_world_us = _system.next_generation_us(now_us, rng)
	if scheduled:
		_increment_telemetry("scheduled_natural")
	return scheduled


func _schedule_event(type_id: String, regions: Array, forecast_duration_us: int, active_duration_us: int, source_type: String, now_us: int) -> bool:
	var definition := _definition(type_id)
	if definition == null:
		definition = _first_definition()
	if definition == null:
		return false
	var forecast_us := _definition_forecast_us(definition, float(forecast_duration_us) / 1_000_000.0)
	var active_us := _definition_active_us(definition, float(active_duration_us) / 1_000_000.0)
	var fade_us := _definition_fade_us(definition)
	var clean_regions := _clean_region_indices(regions, definition.affected_region_count)
	if clean_regions.is_empty():
		return false
	if _unended_event_count() >= WeatherSystem.MAX_UNENDED_EVENTS:
		_increment_telemetry("rejected_max_unended")
		return false
	var conflict := _regions_occupied(clean_regions)
	weather_sequence += 1
	var phase := WeatherRuntimeState.PHASE_QUEUED if conflict else WeatherRuntimeState.PHASE_FORECAST
	var start_us := now_us if not conflict else 0
	var event := {
		"event_schema_version": WeatherRuntimeState.EVENT_SCHEMA_VERSION,
		"id": weather_sequence,
		"definition_id": definition.id,
		"type": definition.id,
		"region_indices": clean_regions,
		"districts": clean_regions,
		"phase": phase,
		"source_type": _normalize_source_type(source_type),
		"created_at_world_us": now_us,
		"forecast_starts_at_world_us": start_us,
		"active_starts_at_world_us": start_us + forecast_us if not conflict else 0,
		"active_ends_at_world_us": start_us + forecast_us + active_us if not conflict else 0,
		"fade_ends_at_world_us": start_us + forecast_us + active_us + fade_us if not conflict else 0,
		"forecast_duration_world_us": forecast_us,
		"active_duration_world_us": active_us,
		"fade_duration_world_us": fade_us,
	}
	_events.append(event)
	if conflict:
		_queue.append(int(event.get("id", 0)))
		_increment_telemetry("queued_conflict")
	else:
		_increment_telemetry("scheduled_forecast")
		_begin_telemetry_session(event)
		_announce_forecast(event, definition)
	for region in clean_regions:
		_region_history[str(region)] = weather_sequence
	_log("天气预报：%s将在%s后影响%s。" % [definition.display_name, _duration_short_text(float(event.get("forecast_duration_world_us", 0)) / 1_000_000.0), district_names(event, 5)])
	_refresh_legacy_projection()
	return true


func _advance_lifecycle(now_us: int) -> bool:
	var changed := false
	var remaining: Array = []
	for event_variant in _events:
		if not (event_variant is Dictionary):
			continue
		var event := event_variant as Dictionary
		_ensure_telemetry_session(event)
		var old_phase := str(event.get("phase", WeatherRuntimeState.PHASE_FORECAST))
		var new_phase := _system.lifecycle_phase(event, now_us)
		if new_phase != old_phase:
			changed = true
			event["phase"] = new_phase
			_increment_telemetry("phase_%s" % new_phase)
			if new_phase == WeatherRuntimeState.PHASE_ACTIVE:
				_activate_telemetry_session(event)
				_add_action_callout("星球天气", label(str(event.get("definition_id", ""))), "%s开始影响%s。" % [label(str(event.get("definition_id", ""))), district_names(event, 5)], color(str(event.get("definition_id", ""))), _district_center(int(WeatherRuntimeState.event_region_indices(event).front())), 8.0)
		if new_phase == WeatherRuntimeState.PHASE_ENDED:
			_finish_telemetry_session(event)
			if not bool(event.get("lifecycle_end_recorded", false)):
				_history.append(_history_entry(event, now_us))
				_increment_telemetry("ended")
				event["lifecycle_end_recorded"] = true
			if not _event_has_pending_region_damage(event, now_us):
				continue
		remaining.append(event)
	_events = remaining
	_queue = _live_queue_ids()
	return changed


func _release_waiting_queue(now_us: int) -> bool:
	var changed := false
	for event_variant in _events:
		if not (event_variant is Dictionary):
			continue
		var event := event_variant as Dictionary
		if str(event.get("phase", "")) != WeatherRuntimeState.PHASE_QUEUED:
			continue
		if _regions_occupied(WeatherRuntimeState.event_region_indices(event), int(event.get("id", 0))):
			continue
		event["phase"] = WeatherRuntimeState.PHASE_FORECAST
		event["forecast_starts_at_world_us"] = now_us
		event["active_starts_at_world_us"] = now_us + int(event.get("forecast_duration_world_us", WeatherSystem.FORECAST_LEAD_MIN_US))
		event["active_ends_at_world_us"] = int(event.get("active_starts_at_world_us", now_us)) + int(event.get("active_duration_world_us", WeatherSystem.ACTIVE_MIN_US))
		event["fade_ends_at_world_us"] = int(event.get("active_ends_at_world_us", now_us)) + int(event.get("fade_duration_world_us", WeatherSystem.FADE_US))
		_increment_telemetry("dequeued")
		_begin_telemetry_session(event)
		var definition := _definition(str(event.get("definition_id", event.get("type", ""))))
		_announce_forecast(event, definition)
		changed = true
	_queue = _live_queue_ids()
	return changed


func _effect_entries_for_region(region_index: int, context: Dictionary) -> Array:
	var result: Array = []
	var now_us := _now_us()
	for event_variant in _events:
		if not (event_variant is Dictionary):
			continue
		var event := event_variant as Dictionary
		if not WeatherRuntimeState.event_region_indices(event).has(region_index):
			continue
		var phase := str(event.get("phase", ""))
		if not [WeatherRuntimeState.PHASE_ACTIVE, WeatherRuntimeState.PHASE_FADING].has(phase):
			continue
		var definition := _definition(str(event.get("definition_id", event.get("type", ""))))
		var effect := _resolver.resolve(definition, phase, _system.intensity(event, now_us), context)
		effect["event_id"] = int(event.get("id", 0))
		effect["region_index"] = region_index
		result.append(effect)
	return result


func _apply_region_weather_damage(now_us: int) -> bool:
	if _region_infrastructure_world_bridge == null or not is_instance_valid(_region_infrastructure_world_bridge):
		return false
	if not _region_infrastructure_world_bridge.has_method("submit_weather_damage_by_legacy_index"):
		return false
	var changed := false
	for event_variant in _events:
		if not (event_variant is Dictionary):
			continue
		var event := event_variant as Dictionary
		var definition := _definition(str(event.get("definition_id", event.get("type", ""))))
		if definition == null or definition.region_damage_per_second <= 0.0 or not definition.damage_nonlethal or not definition.damage_capped:
			continue
		var accounted: Dictionary = (event.get("weather_damage_accounted_units_by_region", {}) as Dictionary).duplicate(true) if event.get("weather_damage_accounted_units_by_region", {}) is Dictionary else {}
		var applied_totals: Dictionary = (event.get("weather_damage_applied_units_by_region", {}) as Dictionary).duplicate(true) if event.get("weather_damage_applied_units_by_region", {}) is Dictionary else {}
		for region_variant in WeatherRuntimeState.event_region_indices(event):
			var region_index := int(region_variant)
			var region_key := str(region_index)
			var expected_total := _expected_region_damage_units(event, definition, region_index, now_us)
			var accounted_total := maxi(0, int(accounted.get(region_key, 0)))
			if expected_total <= accounted_total:
				continue
			var amount := expected_total - accounted_total
			var receipt_variant: Variant = _region_infrastructure_world_bridge.call(
				"submit_weather_damage_by_legacy_index",
				region_index,
				int(event.get("id", 0)),
				amount,
				expected_total,
				now_us
			)
			if not (receipt_variant is Dictionary):
				continue
			var receipt := receipt_variant as Dictionary
			if not bool(receipt.get("committed", false)):
				continue
			accounted[region_key] = expected_total
			applied_totals[region_key] = maxi(0, int(applied_totals.get(region_key, 0))) + maxi(0, int(receipt.get("applied_damage", 0)))
			event["weather_damage_last_accounted_world_us"] = now_us
			_increment_telemetry("region_damage_accounted")
			if int(receipt.get("applied_damage", 0)) > 0:
				_increment_telemetry("region_damage_applied")
				_observe_telemetry_metric(int(event.get("id", 0)), "region_damage", float(receipt.get("applied_damage", 0)))
			changed = true
		event["weather_damage_accounted_units_by_region"] = accounted
		event["weather_damage_applied_units_by_region"] = applied_totals
	return changed


func _event_has_pending_region_damage(event: Dictionary, now_us: int) -> bool:
	var definition := _definition(str(event.get("definition_id", event.get("type", ""))))
	if definition == null or definition.region_damage_per_second <= 0.0 or not definition.damage_nonlethal or not definition.damage_capped:
		return false
	var accounted: Dictionary = event.get("weather_damage_accounted_units_by_region", {}) if event.get("weather_damage_accounted_units_by_region", {}) is Dictionary else {}
	for region_variant in WeatherRuntimeState.event_region_indices(event):
		var region_index := int(region_variant)
		if _expected_region_damage_units(event, definition, region_index, now_us) > maxi(0, int(accounted.get(str(region_index), 0))):
			return true
	return false


func _expected_region_damage_units(event: Dictionary, definition: WeatherDefinition, region_index: int, now_us: int) -> int:
	var resistance := _region_weather_resistance(region_index)
	var resolved := _resolver.resolve(definition, WeatherRuntimeState.PHASE_ACTIVE, 1.0, {"weather_resistance": resistance})
	var damage: Dictionary = resolved.get("damage", {}) if resolved.get("damage", {}) is Dictionary else {}
	var rate_per_second := maxf(0.0, float(damage.get("per_second", 0.0)))
	var integrated_intensity_seconds := _integrated_damage_intensity_seconds(event, now_us)
	return maxi(0, int(floor(rate_per_second * integrated_intensity_seconds + 0.000001)))


func _integrated_damage_intensity_seconds(event: Dictionary, now_us: int) -> float:
	var active_start := int(event.get("active_starts_at_world_us", 0))
	var active_end := maxi(active_start, int(event.get("active_ends_at_world_us", active_start)))
	var fade_end := maxi(active_end, int(event.get("fade_ends_at_world_us", active_end)))
	if now_us <= active_start:
		return 0.0
	var active_elapsed_us := clampi(now_us - active_start, 0, active_end - active_start)
	var integrated_us := float(active_elapsed_us)
	var fade_duration_us := fade_end - active_end
	if now_us > active_end and fade_duration_us > 0:
		var fade_elapsed_us := clampi(now_us - active_end, 0, fade_duration_us)
		integrated_us += float(fade_elapsed_us) - (float(fade_elapsed_us) * float(fade_elapsed_us) / (2.0 * float(fade_duration_us)))
	return integrated_us / 1_000_000.0


func _region_weather_resistance(region_index: int) -> float:
	if _region_infrastructure_world_bridge == null or not is_instance_valid(_region_infrastructure_world_bridge):
		return 0.0
	if not _region_infrastructure_world_bridge.has_method("weather_intervention_snapshot_for_legacy_index"):
		return 0.0
	var value: Variant = _region_infrastructure_world_bridge.call("weather_intervention_snapshot_for_legacy_index", region_index)
	if not (value is Dictionary):
		return 0.0
	return clampf(float((value as Dictionary).get("weather_resistance", 0.0)), 0.0, 1.0)


func _public_events(now_us: int) -> Array:
	var result: Array = []
	for event_variant in _events:
		if not (event_variant is Dictionary):
			continue
		var event := event_variant as Dictionary
		var definition := _definition(str(event.get("definition_id", event.get("type", ""))))
		var public := WeatherRuntimeState.public_event(event, now_us, definition, _system.intensity(event, now_us))
		if not public.is_empty():
			result.append(public)
	return result


func _refresh_legacy_projection() -> void:
	var now_us := _now_us()
	weather_forecast = {}
	active_weather_zones = []
	for event_variant in _events:
		if not (event_variant is Dictionary):
			continue
		var event := event_variant as Dictionary
		var definition := _definition(str(event.get("definition_id", event.get("type", ""))))
		var public := WeatherRuntimeState.public_event(event, now_us, definition, _system.intensity(event, now_us))
		var phase := str(public.get("phase", ""))
		if [WeatherRuntimeState.PHASE_FORECAST, WeatherRuntimeState.PHASE_QUEUED].has(phase) and weather_forecast.is_empty():
			weather_forecast = public
		elif [WeatherRuntimeState.PHASE_ACTIVE, WeatherRuntimeState.PHASE_FADING].has(phase):
			active_weather_zones.append(public)


func _event_from_legacy(entry: Dictionary, default_phase: String) -> Dictionary:
	var now_us := _now_us()
	var definition := _definition(str(entry.get("definition_id", entry.get("type", ""))))
	if definition == null:
		definition = _first_definition()
	var id := maxi(0, int(entry.get("id", weather_sequence)))
	var start_us := _seconds_to_us(float(entry.get("started_at", entry.get("starts_at", float(now_us) / 1_000_000.0))))
	var duration_us := _seconds_to_us(float(entry.get("duration", WeatherSystem.ACTIVE_MIN_SECONDS)))
	if float(entry.get("duration", 0.0)) > 10_000.0:
		duration_us = int(entry.get("duration", WeatherSystem.ACTIVE_MIN_US))
	var phase := str(entry.get("phase", default_phase))
	var active_start := start_us if phase == WeatherRuntimeState.PHASE_ACTIVE else _seconds_to_us(float(entry.get("starts_at", float(now_us) / 1_000_000.0)))
	var active_end := _seconds_to_us(float(entry.get("ends_at", 0.0))) if entry.has("ends_at") else active_start + duration_us
	var fade_us := _definition_fade_us(definition)
	return {
		"event_schema_version": WeatherRuntimeState.EVENT_SCHEMA_VERSION,
		"id": id,
		"definition_id": definition.id if definition != null else "",
		"type": definition.id if definition != null else "",
		"region_indices": WeatherRuntimeState.event_region_indices(entry),
		"districts": WeatherRuntimeState.event_region_indices(entry),
		"phase": phase,
		"source_type": SOURCE_TYPE_CARD,
		"created_at_world_us": _seconds_to_us(float(entry.get("created_at", 0.0))),
		"forecast_starts_at_world_us": _seconds_to_us(float(entry.get("starts_at", 0.0))),
		"active_starts_at_world_us": active_start,
		"active_ends_at_world_us": active_end,
		"fade_ends_at_world_us": active_end + fade_us,
		"forecast_duration_world_us": clampi(active_start - _seconds_to_us(float(entry.get("created_at", 0.0))), WeatherSystem.FORECAST_LEAD_MIN_US, WeatherSystem.FORECAST_LEAD_MAX_US),
		"active_duration_world_us": clampi(active_end - active_start, WeatherSystem.ACTIVE_MIN_US, WeatherSystem.ACTIVE_MAX_US),
		"fade_duration_world_us": fade_us,
	}


func _history_entry(event: Dictionary, now_us: int) -> Dictionary:
	return {
		"id": int(event.get("id", 0)),
		"definition_id": str(event.get("definition_id", event.get("type", ""))),
		"region_indices": WeatherRuntimeState.event_region_indices(event),
		"ended_at_world_us": now_us,
	}


func _catalog() -> WeatherDefinitionCatalog:
	if definition_catalog == null:
		definition_catalog = DEFAULT_DEFINITION_CATALOG
	return definition_catalog as WeatherDefinitionCatalog


func _definition(type_id: String) -> WeatherDefinition:
	var catalog := _catalog()
	return catalog.definition(type_id) if catalog != null else null


func _first_definition() -> WeatherDefinition:
	var catalog := _catalog()
	return catalog.first_definition() if catalog != null else null


func _compute_configured() -> bool:
	var catalog := _catalog()
	var catalog_valid := catalog != null and bool(catalog.validate_catalog().get("valid", false))
	return catalog_valid and _world_bridge != null and _world_bridge.has_world() and _shared_rng() != null and _clock_ready()


func _normalize_source_type(source_type: String) -> String:
	return source_type if SOURCE_TYPES.has(source_type) else SOURCE_TYPE_NATURAL


func _bind_clock_from_scene() -> void:
	if _world_effective_clock != null and is_instance_valid(_world_effective_clock):
		return
	var parent_node := get_parent()
	if parent_node != null:
		var sibling := parent_node.get_node_or_null("WorldEffectiveClockRuntimeController")
		if sibling != null and sibling.has_method("world_effective_micros"):
			_world_effective_clock = sibling


func _clock_ready() -> bool:
	return _world_effective_clock != null and is_instance_valid(_world_effective_clock) and _world_effective_clock.has_method("world_effective_micros")


func _now_us() -> int:
	return int(_world_effective_clock.call("world_effective_micros")) if _clock_ready() else 0


func _region_facts() -> Array:
	if _world_bridge != null and _world_bridge.has_method("region_facts_for_weather"):
		var value: Variant = _world_bridge.call("region_facts_for_weather", _region_history.duplicate(true))
		return value as Array if value is Array else []
	var result: Array = []
	for index in _alive_district_indices():
		result.append({"index": int(index), "destroyed": false, "has_active_city": false, "active_route_count": 0, "live_monster_count": 0, "trade_volume_bucket": 0, "last_weather_sequence": int(_region_history.get(str(index), 0))})
	return result


func _districts() -> Array:
	if _world_bridge != null and _world_bridge.has_method("districts_public_snapshot"):
		var value: Variant = _world_bridge.call("districts_public_snapshot")
		return value as Array if value is Array else []
	return []


func _alive_district_indices() -> Array:
	var result: Array = []
	var districts := _districts()
	for index in range(districts.size()):
		if not bool((districts[index] as Dictionary).get("destroyed", false)):
			result.append(index)
	return result


func _occupied_regions(excluded_event_id: int = -1) -> Array:
	var result: Array = []
	for event_variant in _events:
		if not (event_variant is Dictionary):
			continue
		var event := event_variant as Dictionary
		if int(event.get("id", -1)) == excluded_event_id:
			continue
		if not WeatherRuntimeState.is_unended(event):
			continue
		for region in WeatherRuntimeState.event_region_indices(event):
			if not result.has(region):
				result.append(region)
	return result


func _regions_occupied(regions: Array, excluded_event_id: int = -1) -> bool:
	return _system.regions_conflict(regions, _occupied_regions(excluded_event_id))


func _unended_event_count() -> int:
	var count := 0
	for event_variant in _events:
		if event_variant is Dictionary and WeatherRuntimeState.is_unended(event_variant as Dictionary):
			count += 1
	return count


func _live_queue_ids() -> Array:
	var result: Array = []
	for event_variant in _events:
		if event_variant is Dictionary and str((event_variant as Dictionary).get("phase", "")) == WeatherRuntimeState.PHASE_QUEUED:
			result.append(int((event_variant as Dictionary).get("id", 0)))
	return result


func _clean_region_indices(regions: Array, max_count: int = WeatherSystem.DEFAULT_AFFECTED_REGION_COUNT) -> Array:
	var alive := _alive_district_indices()
	var result: Array = []
	var limit := maxi(1, max_count)
	for region_variant in regions:
		var region := int(region_variant)
		if alive.has(region) and not result.has(region):
			result.append(region)
		if result.size() >= limit:
			break
	return result


static func _new_session_region_candidates(districts: Array) -> Array:
	var best_score := -INF
	var candidates: Array = []
	for index in range(districts.size()):
		if not (districts[index] is Dictionary):
			continue
		var district: Dictionary = districts[index]
		if bool(district.get("destroyed", false)):
			continue
		var city_variant: Variant = district.get("city", {})
		var has_active_city := city_variant is Dictionary and not (city_variant as Dictionary).is_empty() \
			and bool((city_variant as Dictionary).get("active", true)) and not bool((city_variant as Dictionary).get("destroyed", false))
		var neighbors: Array = district.get("neighbors", []) if district.get("neighbors", []) is Array else []
		var trade_volume_bucket := maxi(0, int(district.get("public_trade_volume_bucket", district.get("trade_volume_bucket", district.get("route_load_bucket", 0)))))
		var score := (8.0 if has_active_city else 0.0) + float(neighbors.size()) * 2.0 + float(trade_volume_bucket) * 1.25
		if score > best_score + 0.001:
			best_score = score
			candidates = [index]
		elif is_equal_approx(score, best_score):
			candidates.append(index)
	return candidates


static func _cursor_from_detached_draw(draw: Dictionary) -> Dictionary:
	return {
		"schema_version": 1,
		"rng_state": int(draw.get("rng_state", 1)),
		"draw_count": int(draw.get("draw_count", 0)),
	}


func _shared_rng() -> RunRngService:
	return _world_bridge.shared_rng() if _world_bridge != null else null


func _world_call(method_name: StringName, arguments: Array = []) -> Variant:
	return _world_bridge.call_world(method_name, arguments) if _world_bridge != null else null


func _duration_short_text(seconds: float) -> String:
	var value: Variant = _world_call(&"_duration_short_text", [seconds])
	return str(value) if value != null else "%d秒" % ceili(maxf(0.0, seconds))


func _district_center(index: int) -> Vector2:
	var value: Variant = _world_call(&"_district_center", [index])
	return value as Vector2 if value is Vector2 else Vector2.ZERO


func _refresh_weather_dependents() -> void:
	if _route_network_runtime_controller != null:
		_route_network_runtime_controller.refresh_routes()
	if _product_market_runtime_controller != null:
		_product_market_runtime_controller.refresh_prices()


func _log(message: String) -> void:
	if _public_log_producer_port != null and not message.is_empty():
		_public_log_producer_port.publish(
			&"weather_public_update", &"public.weather.updated",
			{"action_kind": "weather", "public_status": "updated"},
			_presentation_source_revision(), _presentation_world_time()
		)


func _presentation_source_revision() -> int:
	return _presentation_world_clock.world_effective_micros() if _presentation_world_clock != null else 0


func _presentation_world_time() -> float:
	return _presentation_world_clock.world_effective_seconds() if _presentation_world_clock != null else 0.0


func _add_action_callout(source: String, title: String, detail: String, accent: Color, world_position: Vector2, duration: float = 5.0) -> void:
	if _visual_cue_runtime_owner != null:
		_visual_cue_runtime_owner.add_action_callout(source, title, detail, accent, world_position, duration)


func _announce_forecast(event: Dictionary, definition: WeatherDefinition) -> void:
	if definition == null:
		return
	var regions := WeatherRuntimeState.event_region_indices(event)
	if regions.is_empty():
		return
	var lead_seconds := float(event.get("forecast_duration_world_us", 0)) / 1_000_000.0
	var active_seconds := float(event.get("active_duration_world_us", 0)) / 1_000_000.0
	_add_action_callout(
		"气象台",
		"预报·%s" % definition.display_name,
		"%s后影响%s，预计持续%s。%s｜点击天气条定位。" % [
			_duration_short_text(lead_seconds),
			district_names(event, 3),
			_duration_short_text(active_seconds),
			definition.counterplay_hint,
		],
		definition.accent_color,
		_district_center(int(regions.front())),
		8.0
	)


func _ensure_telemetry_session(event: Dictionary) -> void:
	if _weather_telemetry_runtime_service == null:
		return
	if str(event.get("phase", "")) == WeatherRuntimeState.PHASE_QUEUED:
		return
	_begin_telemetry_session(event)
	if [WeatherRuntimeState.PHASE_ACTIVE, WeatherRuntimeState.PHASE_FADING, WeatherRuntimeState.PHASE_ENDED].has(str(event.get("phase", ""))):
		_activate_telemetry_session(event)


func _begin_telemetry_session(event: Dictionary) -> void:
	if _weather_telemetry_runtime_service == null or not _weather_telemetry_runtime_service.has_method("begin_weather_session"):
		return
	_weather_telemetry_runtime_service.call(
		"begin_weather_session",
		int(event.get("id", 0)),
		str(event.get("definition_id", event.get("type", ""))),
		WeatherRuntimeState.event_region_indices(event),
		float(event.get("forecast_duration_world_us", 0)) / 1_000_000.0,
		float(event.get("active_duration_world_us", 0)) / 1_000_000.0,
		float(event.get("fade_duration_world_us", 0)) / 1_000_000.0
	)


func _activate_telemetry_session(event: Dictionary) -> void:
	if _weather_telemetry_runtime_service != null and _weather_telemetry_runtime_service.has_method("activate_weather_session"):
		_weather_telemetry_runtime_service.call("activate_weather_session", int(event.get("id", 0)))


func _finish_telemetry_session(event: Dictionary) -> void:
	if bool(event.get("telemetry_end_recorded", false)):
		return
	if _weather_telemetry_runtime_service != null and _weather_telemetry_runtime_service.has_method("finish_weather_session"):
		if bool(_weather_telemetry_runtime_service.call("finish_weather_session", int(event.get("id", 0)))):
			event["telemetry_end_recorded"] = true


func _observe_telemetry_metric(event_id: int, metric: String, value: float) -> void:
	if _weather_telemetry_runtime_service != null and _weather_telemetry_runtime_service.has_method("observe_public_metric"):
		_weather_telemetry_runtime_service.call("observe_public_metric", event_id, metric, value)


func _seconds_to_us(seconds: float) -> int:
	return maxi(0, int(round(seconds * 1_000_000.0)))


func _definition_forecast_us(definition: WeatherDefinition, _fallback_seconds: float = -1.0) -> int:
	if definition == null:
		return WeatherSystem.FORECAST_LEAD_MIN_US
	return _seconds_to_us(clampf(definition.forecast_duration, WeatherSystem.FORECAST_LEAD_MIN_SECONDS, WeatherSystem.FORECAST_LEAD_MAX_SECONDS))


func _definition_active_us(definition: WeatherDefinition, _fallback_seconds: float = -1.0) -> int:
	if definition == null:
		return WeatherSystem.ACTIVE_MIN_US
	return _seconds_to_us(clampf(definition.active_duration, WeatherSystem.ACTIVE_MIN_SECONDS, WeatherSystem.ACTIVE_MAX_SECONDS))


func _definition_fade_us(definition: WeatherDefinition) -> int:
	if definition == null:
		return WeatherSystem.FADE_US
	return _seconds_to_us(maxf(0.0, definition.fade_duration))


func _increment_telemetry(key: String) -> void:
	_telemetry[key] = int(_telemetry.get(key, 0)) + 1
