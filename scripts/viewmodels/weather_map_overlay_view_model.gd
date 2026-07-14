extends RefCounted
class_name WeatherMapOverlayViewModel

const FORECAST_VIEW_MODEL = preload("res://scripts/viewmodels/weather_forecast_view_model.gd")
const VIEW_SCHEMA := "weather_map_overlay_view_model.v1"
const CLOCK_DOMAIN := "world_effective"

const VIEW_KEYS := [
	"schema_version",
	"clock_domain",
	"world_effective_us",
	"source_revision",
	"state",
	"regions",
]
const REGION_KEYS := [
	"region_index",
	"event_id",
	"definition_id",
	"display_name",
	"icon_key",
	"accent_hex",
	"pattern_key",
	"phase",
	"remaining_us",
	"intensity",
	"source_type",
	"stack_index",
	"accessible_label",
]
const STATES := ["clear", "queued", "forecast", "active", "fading", "mixed"]

var _last_error := ""


func compose(forecast_view_model: Dictionary) -> Dictionary:
	_last_error = ""
	var validator := FORECAST_VIEW_MODEL.new()
	if not validator.validate_view_model(forecast_view_model):
		_last_error = "forecast_%s" % validator.get_last_error()
		return {}

	var region_stack_counts: Dictionary = {}
	var regions: Array = []
	for raw_event: Variant in forecast_view_model["events"]:
		var event := raw_event as Dictionary
		for raw_region: Variant in event["regions"]:
			var region := raw_region as Dictionary
			var region_index := int(region["region_index"])
			var stack_index := int(region_stack_counts.get(region_index, 0))
			regions.append({
				"region_index": region_index,
				"event_id": event["event_id"],
				"definition_id": event["definition_id"],
				"display_name": event["display_name"],
				"icon_key": event["icon_key"],
				"accent_hex": event["accent_hex"],
				"pattern_key": event["pattern_key"],
				"phase": event["phase"],
				"remaining_us": event["remaining_us"],
				"intensity": event["intensity"],
				"source_type": event["source_type"],
				"stack_index": stack_index,
				"accessible_label": "%s，%s，%s，剩余 %s" % [
					region["label"],
					event["display_name"],
					_phase_label(event["phase"]),
					_duration_label(event["remaining_us"]),
				],
			})
			region_stack_counts[region_index] = stack_index + 1

	return {
		"schema_version": VIEW_SCHEMA,
		"clock_domain": CLOCK_DOMAIN,
		"world_effective_us": forecast_view_model["world_effective_us"],
		"source_revision": forecast_view_model["source_revision"],
		"state": forecast_view_model["state"],
		"regions": regions,
	}


func validate_view_model(view_model: Dictionary) -> bool:
	_last_error = ""
	if not _has_exact_keys(view_model, VIEW_KEYS):
		return _reject("view_keys")
	if view_model["schema_version"] != VIEW_SCHEMA or view_model["clock_domain"] != CLOCK_DOMAIN:
		return _reject("view_schema")
	if typeof(view_model["world_effective_us"]) != TYPE_INT or int(view_model["world_effective_us"]) < 0:
		return _reject("view_clock")
	if typeof(view_model["source_revision"]) != TYPE_INT or int(view_model["source_revision"]) < 0:
		return _reject("view_revision")
	if typeof(view_model["state"]) != TYPE_STRING or not STATES.has(view_model["state"]):
		return _reject("view_state")
	if typeof(view_model["regions"]) != TYPE_ARRAY:
		return _reject("regions_type")
	var expected_stacks: Dictionary = {}
	for raw_region: Variant in view_model["regions"]:
		if typeof(raw_region) != TYPE_DICTIONARY:
			return _reject("region_type")
		var region := raw_region as Dictionary
		if not _has_exact_keys(region, REGION_KEYS):
			return _reject("region_keys")
		if typeof(region["region_index"]) != TYPE_INT or int(region["region_index"]) < 0:
			return _reject("region_index")
		if typeof(region["event_id"]) != TYPE_INT or int(region["event_id"]) < 1:
			return _reject("event_id")
		if typeof(region["definition_id"]) != TYPE_STRING or not FORECAST_VIEW_MODEL.WEATHER_IDS.has(region["definition_id"]):
			return _reject("definition_id")
		if typeof(region["display_name"]) != TYPE_STRING or (region["display_name"] as String).strip_edges().is_empty():
			return _reject("display_name")
		if typeof(region["icon_key"]) != TYPE_STRING or not FORECAST_VIEW_MODEL.ICON_KEYS.has(region["icon_key"]):
			return _reject("icon_key")
		if typeof(region["pattern_key"]) != TYPE_STRING or not FORECAST_VIEW_MODEL.PATTERN_KEYS.has(region["pattern_key"]):
			return _reject("pattern_key")
		if not _valid_hex_color(region["accent_hex"]):
			return _reject("accent_hex")
		if typeof(region["phase"]) != TYPE_STRING or not FORECAST_VIEW_MODEL.PHASES.has(region["phase"]):
			return _reject("phase")
		if typeof(region["remaining_us"]) != TYPE_INT or int(region["remaining_us"]) < 0:
			return _reject("remaining_us")
		if (typeof(region["intensity"]) != TYPE_FLOAT and typeof(region["intensity"]) != TYPE_INT) or not is_finite(float(region["intensity"])):
			return _reject("intensity")
		if float(region["intensity"]) < 0.0 or float(region["intensity"]) > 1.0:
			return _reject("intensity_range")
		if typeof(region["source_type"]) != TYPE_STRING or not FORECAST_VIEW_MODEL.SOURCE_TYPES.has(region["source_type"]):
			return _reject("source_type")
		var expected_stack := int(expected_stacks.get(region["region_index"], 0))
		if typeof(region["stack_index"]) != TYPE_INT or int(region["stack_index"]) != expected_stack:
			return _reject("stack_index")
		expected_stacks[region["region_index"]] = expected_stack + 1
		if typeof(region["accessible_label"]) != TYPE_STRING or (region["accessible_label"] as String).strip_edges().is_empty():
			return _reject("accessible_label")
	return true


func get_last_error() -> String:
	return _last_error


func view_field_schema() -> Dictionary:
	return {"view": VIEW_KEYS.duplicate(), "region": REGION_KEYS.duplicate()}


func _phase_label(phase: String) -> String:
	match phase:
		"queued": return "待发布"
		"forecast": return "预报中"
		"active": return "生效中"
		"fading": return "消退中"
	return "未知"


func _duration_label(remaining_us: int) -> String:
	var total_seconds := int(ceil(float(remaining_us) / 1_000_000.0))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	if minutes > 0:
		return "%d分%02d秒" % [minutes, seconds]
	return "%d秒" % seconds


func _valid_hex_color(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var color_text := value as String
	if color_text.length() != 7 or not color_text.begins_with("#"):
		return false
	for index: int in range(1, color_text.length()):
		if not "0123456789abcdefABCDEF".contains(color_text.substr(index, 1)):
			return false
	return true


func _has_exact_keys(value: Dictionary, expected_keys: Array) -> bool:
	if value.size() != expected_keys.size():
		return false
	for key: String in expected_keys:
		if not value.has(key):
			return false
	return true


func _reject(reason: String) -> bool:
	_last_error = reason
	return false
