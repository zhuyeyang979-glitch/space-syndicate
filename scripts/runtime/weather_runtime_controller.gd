@tool
extends Node
class_name WeatherRuntimeController

const FORECAST_LEAD_MIN_SECONDS := 60.0
const FORECAST_LEAD_MAX_SECONDS := 180.0
const DURATION_MIN_SECONDS := 75.0
const DURATION_MAX_SECONDS := 135.0
const ZONE_MAX := 5
const WEATHER_TYPES := {
	"solar_storm": {
		"label": "太阳风暴",
		"production_multiplier": 1.08,
		"transport_multiplier": 0.82,
		"consumption_multiplier": 1.06,
		"color": Color("#f97316"),
		"text": "电子干扰压低交通速度，但能源与避险消费会短暂升温。",
	},
	"acid_rain": {
		"label": "酸雨云团",
		"production_multiplier": 0.82,
		"transport_multiplier": 0.88,
		"consumption_multiplier": 0.96,
		"color": Color("#a3e635"),
		"text": "酸雨削弱露天生产与陆路效率，适合压制高GDP城区。",
	},
	"gravity_tide": {
		"label": "引力潮汐",
		"production_multiplier": 0.96,
		"transport_multiplier": 1.10,
		"ocean_transport_multiplier": 1.26,
		"consumption_multiplier": 1.02,
		"color": Color("#38bdf8"),
		"text": "潮汐让海洋商路和公共交通提速，水域周边城市更容易放大流通GDP。",
	},
	"magnetic_fog": {
		"label": "电磁雾",
		"production_multiplier": 1.0,
		"transport_multiplier": 0.92,
		"consumption_multiplier": 0.90,
		"color": Color("#c084fc"),
		"text": "电磁雾拖慢流通与消费判断，让匿名行动留下更多推理噪声。",
	},
}

var _world_bridge: WeatherRuntimeWorldBridge
var _product_market_runtime_controller: ProductMarketRuntimeController
var _ruleset_snapshot: Dictionary = {}
var _configured := false

var weather_forecast: Dictionary = {}
var active_weather_zones: Array = []
var weather_sequence := 0


func set_world_bridge(bridge: WeatherRuntimeWorldBridge) -> void:
	_world_bridge = bridge


func set_product_market_runtime_controller(controller: ProductMarketRuntimeController) -> void:
	_product_market_runtime_controller = controller


func configure(ruleset_snapshot: Dictionary) -> void:
	_ruleset_snapshot = ruleset_snapshot.duplicate(true)
	_configured = str(_ruleset_snapshot.get("ruleset_id", "")) == "v0.4" and _world_bridge != null and _world_bridge.has_world() and _world_bridge.shared_rng() != null


func reset_state() -> void:
	weather_forecast.clear()
	active_weather_zones.clear()
	weather_sequence = 0


func tick(_delta_seconds: float) -> void:
	if not _configured:
		return
	if weather_forecast.is_empty():
		schedule_next_forecast()
	if not weather_forecast.is_empty() and _game_time() >= float(weather_forecast.get("starts_at", _game_time() + 9999.0)):
		activate_forecast()
	var remaining: Array = []
	var expired := false
	for entry_variant in active_weather_zones:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if _game_time() >= float(entry.get("ends_at", _game_time())):
			expired = true
			_log("天气结束：%s对%s的影响已结束。" % [label(str(entry.get("type", ""))), district_names(entry, 5)])
			continue
		remaining.append(entry)
	if expired:
		active_weather_zones = remaining
		_refresh_weather_dependents()


func template(type_id: String) -> Dictionary:
	return (WEATHER_TYPES.get(type_id, WEATHER_TYPES.get("solar_storm", {})) as Dictionary).duplicate(true)


func label(type_id: String) -> String:
	return str(template(type_id).get("label", type_id))


func color(type_id: String) -> Color:
	return template(type_id).get("color", Color("#93c5fd")) as Color


func weather_type_ids() -> Array:
	return WEATHER_TYPES.keys().duplicate()


func weather_types_snapshot() -> Dictionary:
	var result := {}
	for type_id_variant in WEATHER_TYPES:
		var type_id := str(type_id_variant)
		var source := template(type_id)
		result[type_id] = {
			"label": str(source.get("label", type_id)),
			"production_multiplier": float(source.get("production_multiplier", 1.0)),
			"transport_multiplier": float(source.get("transport_multiplier", 1.0)),
			"ocean_transport_multiplier": float(source.get("ocean_transport_multiplier", source.get("transport_multiplier", 1.0))),
			"consumption_multiplier": float(source.get("consumption_multiplier", 1.0)),
			"color": color(type_id).to_html(),
			"text": str(source.get("text", "")),
		}
	return result


func zone_count_for_planet() -> int:
	return clampi(ceili(float(maxi(1, _districts().size())) / 12.0), 1, ZONE_MAX)


func district_names(entry: Dictionary, limit: int = 3) -> String:
	var names: Array = []
	var district_ids: Array = entry.get("districts", []) if entry.get("districts", []) is Array else []
	var districts := _districts()
	for index in range(mini(limit, district_ids.size())):
		var district_index := int(district_ids[index])
		if district_index >= 0 and district_index < districts.size():
			names.append(str((districts[district_index] as Dictionary).get("name", "区域")))
	var suffix := ""
	if district_ids.size() > names.size():
		suffix = "等%d区" % district_ids.size()
	return " / ".join(names) + suffix


func pick_districts(anchor_index: int, zone_count: int) -> Array:
	var alive := _alive_district_indices()
	if alive.is_empty():
		return []
	var count := clampi(zone_count, 1, mini(ZONE_MAX, alive.size()))
	var shared_rng := _shared_rng()
	if shared_rng == null:
		return []
	var anchor := anchor_index if alive.has(anchor_index) else int(alive[shared_rng.randi_range(0, alive.size() - 1)])
	var result: Array = [anchor]
	var frontier: Array = [anchor]
	var districts := _districts()
	while result.size() < count and not frontier.is_empty():
		var current := int(frontier.pop_front())
		for neighbor_variant in (districts[current] as Dictionary).get("neighbors", []):
			var neighbor := int(neighbor_variant)
			if neighbor < 0 or neighbor >= districts.size() or bool((districts[neighbor] as Dictionary).get("destroyed", false)):
				continue
			if result.has(neighbor):
				continue
			result.append(neighbor)
			frontier.append(neighbor)
			if result.size() >= count:
				break
	while result.size() < count and not alive.is_empty():
		var picked := int(alive[shared_rng.randi_range(0, alive.size() - 1)])
		alive.erase(picked)
		if not result.has(picked):
			result.append(picked)
	return result


func preview_districts(anchor_index: int, zone_count: int) -> Array:
	var alive := _alive_district_indices()
	if alive.is_empty():
		return []
	var count := clampi(zone_count, 1, mini(ZONE_MAX, alive.size()))
	var anchor := anchor_index if alive.has(anchor_index) else int(alive[0])
	var result: Array = [anchor]
	var frontier: Array = [anchor]
	var districts := _districts()
	while result.size() < count and not frontier.is_empty():
		var current := int(frontier.pop_front())
		for neighbor_variant in (districts[current] as Dictionary).get("neighbors", []):
			var neighbor := int(neighbor_variant)
			if neighbor < 0 or neighbor >= districts.size() or bool((districts[neighbor] as Dictionary).get("destroyed", false)):
				continue
			if result.has(neighbor):
				continue
			result.append(neighbor)
			frontier.append(neighbor)
			if result.size() >= count:
				break
	for alive_variant in alive:
		if result.size() >= count:
			break
		var picked := int(alive_variant)
		if not result.has(picked):
			result.append(picked)
	return result


func schedule_forecast(type_id: String, anchor_index: int, zone_count: int, lead_seconds: float, duration_seconds: float, source: String, forced: bool = false) -> bool:
	if not _configured or _districts().is_empty():
		return false
	if not WEATHER_TYPES.has(type_id):
		type_id = "solar_storm"
	var district_ids := pick_districts(anchor_index, zone_count)
	if district_ids.is_empty():
		return false
	weather_sequence += 1
	weather_forecast = {
		"id": weather_sequence,
		"type": type_id,
		"districts": district_ids,
		"created_at": _game_time(),
		"starts_at": _game_time() + clampf(lead_seconds, FORECAST_LEAD_MIN_SECONDS, FORECAST_LEAD_MAX_SECONDS),
		"duration": clampf(duration_seconds, DURATION_MIN_SECONDS * 0.5, DURATION_MAX_SECONDS * 1.5),
		"source": source,
		"forced": forced,
	}
	_log("星球气象预报%s：%s将在%s后影响%s，持续%s。" % [
		"被匿名卡牌改写" if forced else "",
		label(type_id),
		_duration_short_text(float(weather_forecast.get("starts_at", _game_time())) - _game_time()),
		district_names(weather_forecast, 5),
		_duration_short_text(float(weather_forecast.get("duration", 0.0))),
	])
	return true


func schedule_next_forecast(announce: bool = false) -> bool:
	if not _configured or not weather_forecast.is_empty() or _districts().is_empty():
		return false
	var keys := WEATHER_TYPES.keys()
	var alive := _alive_district_indices()
	var shared_rng := _shared_rng()
	if keys.is_empty() or alive.is_empty() or shared_rng == null:
		return false
	var type_id := str(keys[shared_rng.randi_range(0, keys.size() - 1)])
	var anchor := int(alive[shared_rng.randi_range(0, alive.size() - 1)])
	var lead := shared_rng.randf_range(FORECAST_LEAD_MIN_SECONDS, FORECAST_LEAD_MAX_SECONDS)
	var duration := shared_rng.randf_range(DURATION_MIN_SECONDS, DURATION_MAX_SECONDS)
	var scheduled := schedule_forecast(type_id, anchor, zone_count_for_planet(), lead, duration, "星球气象台", false)
	if scheduled and announce:
		_add_action_callout("星球气象台", "天气预报", status_text(), color(type_id), _district_center(anchor), 6.0)
	return scheduled


func activate_forecast() -> bool:
	if weather_forecast.is_empty():
		return false
	var entry := weather_forecast.duplicate(true)
	var type_id := str(entry.get("type", "solar_storm"))
	entry["started_at"] = _game_time()
	entry["ends_at"] = _game_time() + maxf(1.0, float(entry.get("duration", DURATION_MIN_SECONDS)))
	active_weather_zones.append(entry)
	weather_forecast = {}
	_refresh_weather_dependents()
	var district_ids: Array = entry.get("districts", []) if entry.get("districts", []) is Array else []
	var center_index := int(district_ids[0]) if not district_ids.is_empty() else int(_world_value(&"selected_district", 0))
	_add_action_callout(
		"星球天气",
		label(type_id),
		"%s开始影响%s，GDP会按生产/交通/消费修正。" % [label(type_id), district_names(entry, 5)],
		color(type_id),
		_district_center(center_index),
		8.0
	)
	_log("天气生效：%s覆盖%s；%s" % [label(type_id), district_names(entry, 5), str(template(type_id).get("text", "天气影响区域经济。"))])
	schedule_next_forecast()
	return true


func apply_weather_control(skill: Dictionary) -> bool:
	var source := str(skill.get("name", "天气干预"))
	var selected_district := int(_world_value(&"selected_district", -1))
	var districts := _districts()
	if selected_district < 0 or selected_district >= districts.size() or bool((districts[selected_district] as Dictionary).get("destroyed", false)):
		_log("%s需要选中一个未毁区域作为天气锚点。" % source)
		return false
	var type_id := str(skill.get("weather_type", "solar_storm"))
	var zone_count := clampi(int(skill.get("weather_zone_count", zone_count_for_planet())), 1, ZONE_MAX)
	var lead := float(skill.get("weather_forecast_lead_seconds", FORECAST_LEAD_MIN_SECONDS))
	var duration := float(skill.get("weather_duration_seconds", DURATION_MIN_SECONDS))
	if not schedule_forecast(type_id, selected_district, zone_count, lead, duration, source, true):
		_log("%s未能改写天气预报。" % source)
		return false
	_add_action_callout(
		"匿名气象干预",
		source,
		"星球天气预报被改写：%s将在%s后影响%s。" % [
			label(type_id),
			_duration_short_text(maxf(0.0, float(weather_forecast.get("starts_at", _game_time())) - _game_time())),
			district_names(weather_forecast, 5),
		],
		color(type_id),
		_district_center(selected_district),
		7.0
	)
	return true


func entries_for_district(index: int) -> Array:
	var result: Array = []
	for entry_variant in active_weather_zones:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var district_ids: Array = entry.get("districts", []) if entry.get("districts", []) is Array else []
		if district_ids.has(index):
			result.append(entry.duplicate(true))
	return result


func district_multiplier(index: int, key: String, default_value: float = 1.0) -> float:
	var multiplier := default_value
	var districts := _districts()
	for entry_variant in entries_for_district(index):
		var entry := entry_variant as Dictionary
		var weather_template := template(str(entry.get("type", "")))
		var value := float(weather_template.get(key, 1.0))
		if key == "transport_multiplier" and index >= 0 and index < districts.size() and str((districts[index] as Dictionary).get("terrain", "land")) == "ocean":
			value = float(weather_template.get("ocean_transport_multiplier", value))
		multiplier *= value
	return multiplier


func district_summary(index: int) -> String:
	var entries := entries_for_district(index)
	if entries.is_empty():
		return "无活跃天气"
	var pieces: Array = []
	for entry_variant in entries:
		pieces.append(label(str((entry_variant as Dictionary).get("type", ""))))
	return " / ".join(pieces)


func status_text() -> String:
	var active_text := "无活跃天气"
	if not active_weather_zones.is_empty():
		var entry := active_weather_zones[0] as Dictionary
		active_text = "%s影响%s" % [label(str(entry.get("type", ""))), district_names(entry, 2)]
	var forecast_text := "暂无预报"
	if not weather_forecast.is_empty():
		forecast_text = "%s即将到达%s" % [label(str(weather_forecast.get("type", ""))), district_names(weather_forecast, 2)]
	return "天气:%s｜预报:%s" % [active_text, forecast_text]


func active_ui_text() -> String:
	if active_weather_zones.is_empty():
		return "现在：无天气"
	var entry := active_weather_zones[0] as Dictionary
	var extra := " +%d" % (active_weather_zones.size() - 1) if active_weather_zones.size() > 1 else ""
	return "现在：%s%s｜%s" % [label(str(entry.get("type", ""))), extra, district_names(entry, 3)]


func forecast_ui_text() -> String:
	if weather_forecast.is_empty():
		return "预报：暂无下一条"
	var source_text := "匿名改写" if bool(weather_forecast.get("forced", false)) else "气象台"
	return "预报：%s｜%s｜%s" % [label(str(weather_forecast.get("type", ""))), district_names(weather_forecast, 3), source_text]


func impact_ui_text() -> String:
	var entry: Dictionary = {}
	if not active_weather_zones.is_empty():
		entry = active_weather_zones[0] as Dictionary
	elif not weather_forecast.is_empty():
		entry = weather_forecast
	if entry.is_empty():
		return "影响：产/交/消"
	var weather_template := template(str(entry.get("type", "")))
	var parts: Array = [
		"产×%.2f" % float(weather_template.get("production_multiplier", 1.0)),
		"交×%.2f" % float(weather_template.get("transport_multiplier", 1.0)),
		"消×%.2f" % float(weather_template.get("consumption_multiplier", 1.0)),
	]
	if weather_template.has("ocean_transport_multiplier"):
		parts.append("海交×%.2f" % float(weather_template.get("ocean_transport_multiplier", 1.0)))
	return "影响：%s" % " ".join(parts)


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
	return {
		"forecast": _public_entry(weather_forecast),
		"active_zones": _public_entries(active_weather_zones),
		"sequence": weather_sequence,
		"active_text": active_ui_text(),
		"forecast_text": forecast_ui_text(),
		"impact_text": impact_ui_text(),
		"status_text": status_text(),
		"short_text": planet_short_text(),
	}


func replace_runtime_state(forecast: Dictionary, active_zones: Array, sequence: int = 0) -> void:
	weather_forecast = forecast.duplicate(true)
	active_weather_zones = active_zones.duplicate(true)
	weather_sequence = maxi(0, sequence)


func to_save_data() -> Dictionary:
	return {
		"weather_forecast": weather_forecast.duplicate(true),
		"active_weather_zones": active_weather_zones.duplicate(true),
		"weather_sequence": weather_sequence,
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var forecast_variant: Variant = data.get("weather_forecast", {})
	var zones_variant: Variant = data.get("active_weather_zones", [])
	weather_forecast = (forecast_variant as Dictionary).duplicate(true) if forecast_variant is Dictionary else {}
	active_weather_zones = (zones_variant as Array).duplicate(true) if zones_variant is Array else []
	weather_sequence = maxi(0, int(data.get("weather_sequence", 0)))
	return {"applied": true, "forecast_present": not weather_forecast.is_empty(), "active_zone_count": active_weather_zones.size(), "sequence": weather_sequence}


func debug_snapshot(_viewer_index: int = -1) -> Dictionary:
	return {
		"controller_ready": _configured and _world_bridge != null and _world_bridge.has_world() and _shared_rng() != null,
		"controller_authoritative": true,
		"runtime_owner": "WeatherRuntimeController",
		"parallel_legacy_owner": false,
		"shared_rng_bound": _shared_rng() != null,
		"forecast": _public_entry(weather_forecast),
		"active_zones": _public_entries(active_weather_zones),
		"sequence": weather_sequence,
		"forecast_lead_min_seconds": FORECAST_LEAD_MIN_SECONDS,
		"forecast_lead_max_seconds": FORECAST_LEAD_MAX_SECONDS,
		"duration_min_seconds": DURATION_MIN_SECONDS,
		"duration_max_seconds": DURATION_MAX_SECONDS,
		"zone_max": ZONE_MAX,
		"weather_types": weather_types_snapshot(),
	}


func _public_entries(entries: Array) -> Array:
	var result: Array = []
	for entry_variant in entries:
		if entry_variant is Dictionary:
			result.append(_public_entry(entry_variant as Dictionary))
	return result


func _public_entry(entry: Dictionary) -> Dictionary:
	if entry.is_empty():
		return {}
	return {
		"id": int(entry.get("id", 0)),
		"type": str(entry.get("type", "solar_storm")),
		"districts": (entry.get("districts", []) as Array).duplicate(true) if entry.get("districts", []) is Array else [],
		"created_at": float(entry.get("created_at", 0.0)),
		"starts_at": float(entry.get("starts_at", 0.0)),
		"duration": float(entry.get("duration", 0.0)),
		"started_at": float(entry.get("started_at", 0.0)),
		"ends_at": float(entry.get("ends_at", 0.0)),
		"forced": bool(entry.get("forced", false)),
	}


func _alive_district_indices() -> Array:
	var result: Array = []
	var districts := _districts()
	for index in range(districts.size()):
		if not bool((districts[index] as Dictionary).get("destroyed", false)):
			result.append(index)
	return result


func _districts() -> Array:
	var value: Variant = _world_value(&"districts", [])
	return value as Array if value is Array else []


func _game_time() -> float:
	return float(_world_value(&"game_time", 0.0))


func _shared_rng() -> RandomNumberGenerator:
	return _world_bridge.shared_rng() if _world_bridge != null else null


func _world_value(property_name: StringName, default_value: Variant = null) -> Variant:
	return _world_bridge.read_world_value(property_name, default_value) if _world_bridge != null else default_value


func _world_call(method_name: StringName, arguments: Array = []) -> Variant:
	return _world_bridge.call_world(method_name, arguments) if _world_bridge != null else null


func _duration_short_text(seconds: float) -> String:
	var value: Variant = _world_call(&"_duration_short_text", [seconds])
	return str(value) if value != null else "%d秒" % ceili(maxf(0.0, seconds))


func _district_center(index: int) -> Vector2:
	var value: Variant = _world_call(&"_district_center", [index])
	return value as Vector2 if value is Vector2 else Vector2.ZERO


func _refresh_weather_dependents() -> void:
	_world_call(&"_refresh_city_networks")
	if _product_market_runtime_controller != null:
		_product_market_runtime_controller.refresh_prices()


func _log(message: String) -> void:
	_world_call(&"_log", [message])


func _add_action_callout(source: String, title: String, detail: String, accent: Color, world_position: Vector2, duration: float = 5.0) -> void:
	_world_call(&"_add_action_callout", [source, title, detail, accent, world_position, duration])
