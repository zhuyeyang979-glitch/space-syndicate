extends RefCounted
class_name WeatherForecastViewModel

const SOURCE_SCHEMA := "weather_public_snapshot.v1"
const VIEW_SCHEMA := "weather_forecast_view_model.v1"
const CLOCK_DOMAIN := "world_effective"

const WEATHER_IDS := [
	"ion_storm",
	"gravity_tide",
	"spore_season",
	"crystal_dust_storm",
	"deep_freeze",
	"solar_flare",
]
const PHASES := ["queued", "forecast", "active", "fading"]
const SOURCE_TYPES := ["natural", "monster", "card"]
const EFFECT_SCOPES := ["economy", "route", "monster", "military", "intel", "region"]
const EFFECT_POLARITIES := ["opportunity", "risk", "mixed"]
const ICON_KEYS := ["ion_bolt", "gravity_wave", "spore", "crystal", "snowflake", "solar"]
const PATTERN_KEYS := ["diagonal", "concentric", "dots", "facets", "crosshatch", "rays"]

const SOURCE_KEYS := [
	"schema_version",
	"clock_domain",
	"world_effective_us",
	"source_revision",
	"definitions",
	"events",
]
const DEFINITION_KEYS := ["definition_id", "display_name", "icon_key", "accent_hex", "pattern_key"]
const SOURCE_EVENT_KEYS := [
	"event_id",
	"definition_id",
	"regions",
	"phase",
	"remaining_us",
	"intensity",
	"source_type",
	"effects",
	"exploitation_hint",
	"counterplay_hint",
]
const REGION_KEYS := ["region_index", "label"]
const EFFECT_KEYS := ["effect_id", "scope", "label", "value_text", "polarity", "classification_tags"]
const VIEW_KEYS := [
	"schema_version",
	"clock_domain",
	"world_effective_us",
	"source_revision",
	"state",
	"definitions",
	"events",
	"summary",
]
const VIEW_EVENT_KEYS := [
	"event_id",
	"definition_id",
	"display_name",
	"icon_key",
	"accent_hex",
	"pattern_key",
	"regions",
	"phase",
	"remaining_us",
	"intensity",
	"source_type",
	"effects",
	"exploitation_hint",
	"counterplay_hint",
	"accessible_text",
]
const SUMMARY_KEYS := ["headline", "detail", "accessible_text"]
const VIEW_STATES := ["clear", "queued", "forecast", "active", "fading", "mixed"]

const FORBIDDEN_KEY_TOKENS := ["source", "card_id", "player", "owner", "cash", "hand", "discard", "ai", "save", "camera"]
const ALLOWED_SOURCE_KEYS := ["source_revision", "source_type"]
const FORBIDDEN_VALUE_MARKERS := ["private_sentinel", "secret_sentinel", "do_not_expose"]

var _last_error := ""


func compose(public_snapshot: Dictionary) -> Dictionary:
	_last_error = ""
	if not _validate_source(public_snapshot):
		return {}

	var definitions: Array = []
	var definitions_by_id: Dictionary = {}
	for raw_definition: Variant in public_snapshot["definitions"]:
		var definition := (raw_definition as Dictionary).duplicate(true)
		definitions.append(definition)
		definitions_by_id[definition["definition_id"]] = definition

	var events: Array = []
	for raw_event: Variant in public_snapshot["events"]:
		var event := raw_event as Dictionary
		var definition := definitions_by_id[event["definition_id"]] as Dictionary
		var regions := (event["regions"] as Array).duplicate(true)
		var effects := (event["effects"] as Array).duplicate(true)
		var view_event := {
			"event_id": event["event_id"],
			"definition_id": event["definition_id"],
			"display_name": definition["display_name"],
			"icon_key": definition["icon_key"],
			"accent_hex": definition["accent_hex"],
			"pattern_key": definition["pattern_key"],
			"regions": regions,
			"phase": event["phase"],
			"remaining_us": event["remaining_us"],
			"intensity": float(event["intensity"]),
			"source_type": event["source_type"],
			"effects": effects,
			"exploitation_hint": event["exploitation_hint"],
			"counterplay_hint": event["counterplay_hint"],
			"accessible_text": _event_accessible_text(definition, event),
		}
		events.append(view_event)

	var state := _state_for_events(events)
	return {
		"schema_version": VIEW_SCHEMA,
		"clock_domain": CLOCK_DOMAIN,
		"world_effective_us": public_snapshot["world_effective_us"],
		"source_revision": public_snapshot["source_revision"],
		"state": state,
		"definitions": definitions,
		"events": events,
		"summary": _build_summary(events, state),
	}


func validate_view_model(view_model: Dictionary) -> bool:
	_last_error = ""
	if _contains_forbidden_key(view_model):
		return _reject("forbidden_key")
	if not _has_exact_keys(view_model, VIEW_KEYS):
		return _reject("view_keys")
	if view_model["schema_version"] != VIEW_SCHEMA or view_model["clock_domain"] != CLOCK_DOMAIN:
		return _reject("view_schema")
	if typeof(view_model["world_effective_us"]) != TYPE_INT or int(view_model["world_effective_us"]) < 0:
		return _reject("view_clock")
	if typeof(view_model["source_revision"]) != TYPE_INT or int(view_model["source_revision"]) < 0:
		return _reject("view_revision")
	if typeof(view_model["state"]) != TYPE_STRING or not VIEW_STATES.has(view_model["state"]):
		return _reject("view_state")
	if typeof(view_model["definitions"]) != TYPE_ARRAY or typeof(view_model["events"]) != TYPE_ARRAY:
		return _reject("view_collections")
	if typeof(view_model["summary"]) != TYPE_DICTIONARY:
		return _reject("view_summary_type")
	var summary := view_model["summary"] as Dictionary
	if not _has_exact_keys(summary, SUMMARY_KEYS):
		return _reject("view_summary_keys")
	for key: String in SUMMARY_KEYS:
		if not _valid_public_text(summary[key], true, 512):
			return _reject("view_summary_text")

	var definitions_by_id: Dictionary = {}
	if not _validate_definitions(view_model["definitions"] as Array, definitions_by_id):
		return false
	var source_events: Array = []
	for raw_event: Variant in view_model["events"]:
		if typeof(raw_event) != TYPE_DICTIONARY:
			return _reject("view_event_type")
		var event := raw_event as Dictionary
		if not _has_exact_keys(event, VIEW_EVENT_KEYS):
			return _reject("view_event_keys")
		if not definitions_by_id.has(event["definition_id"]):
			return _reject("view_definition_id")
		var definition := definitions_by_id[event["definition_id"]] as Dictionary
		for style_key: String in ["display_name", "icon_key", "accent_hex", "pattern_key"]:
			if event[style_key] != definition[style_key]:
				return _reject("view_style_mismatch")
		if not _valid_public_text(event["accessible_text"], false, 1024):
			return _reject("view_accessible_text")
		source_events.append({
			"event_id": event["event_id"],
			"definition_id": event["definition_id"],
			"regions": event["regions"],
			"phase": event["phase"],
			"remaining_us": event["remaining_us"],
			"intensity": event["intensity"],
			"source_type": event["source_type"],
			"effects": event["effects"],
			"exploitation_hint": event["exploitation_hint"],
			"counterplay_hint": event["counterplay_hint"],
		})

	var source := {
		"schema_version": SOURCE_SCHEMA,
		"clock_domain": CLOCK_DOMAIN,
		"world_effective_us": view_model["world_effective_us"],
		"source_revision": view_model["source_revision"],
		"definitions": view_model["definitions"],
		"events": source_events,
	}
	if not _validate_source(source):
		return false
	if _state_for_events(view_model["events"] as Array) != view_model["state"]:
		return _reject("view_state_mismatch")
	return true


func get_last_error() -> String:
	return _last_error


func source_field_schema() -> Dictionary:
	return {
		"source": SOURCE_KEYS.duplicate(),
		"definition": DEFINITION_KEYS.duplicate(),
		"event": SOURCE_EVENT_KEYS.duplicate(),
		"region": REGION_KEYS.duplicate(),
		"effect": EFFECT_KEYS.duplicate(),
	}


func view_field_schema() -> Dictionary:
	return {
		"view": VIEW_KEYS.duplicate(),
		"definition": DEFINITION_KEYS.duplicate(),
		"event": VIEW_EVENT_KEYS.duplicate(),
		"region": REGION_KEYS.duplicate(),
		"effect": EFFECT_KEYS.duplicate(),
		"summary": SUMMARY_KEYS.duplicate(),
	}


func _validate_source(public_snapshot: Dictionary) -> bool:
	if _contains_forbidden_key(public_snapshot):
		return _reject("forbidden_key")
	if not _has_exact_keys(public_snapshot, SOURCE_KEYS):
		return _reject("source_keys")
	if public_snapshot["schema_version"] != SOURCE_SCHEMA or public_snapshot["clock_domain"] != CLOCK_DOMAIN:
		return _reject("source_schema")
	if typeof(public_snapshot["world_effective_us"]) != TYPE_INT or int(public_snapshot["world_effective_us"]) < 0:
		return _reject("world_effective_us")
	if typeof(public_snapshot["source_revision"]) != TYPE_INT or int(public_snapshot["source_revision"]) < 0:
		return _reject("source_revision")
	if typeof(public_snapshot["definitions"]) != TYPE_ARRAY or typeof(public_snapshot["events"]) != TYPE_ARRAY:
		return _reject("source_collections")

	var definitions_by_id: Dictionary = {}
	if not _validate_definitions(public_snapshot["definitions"] as Array, definitions_by_id):
		return false
	var events := public_snapshot["events"] as Array
	if events.size() > 16:
		return _reject("event_count")
	var event_ids: Dictionary = {}
	for raw_event: Variant in events:
		if not _validate_source_event(raw_event, definitions_by_id, event_ids):
			return false
	return true


func _validate_definitions(definitions: Array, definitions_by_id: Dictionary) -> bool:
	if definitions.size() != WEATHER_IDS.size():
		return _reject("definition_count")
	for raw_definition: Variant in definitions:
		if typeof(raw_definition) != TYPE_DICTIONARY:
			return _reject("definition_type")
		var definition := raw_definition as Dictionary
		if not _has_exact_keys(definition, DEFINITION_KEYS):
			return _reject("definition_keys")
		var definition_id: Variant = definition["definition_id"]
		if typeof(definition_id) != TYPE_STRING or not WEATHER_IDS.has(definition_id):
			return _reject("definition_id")
		if definitions_by_id.has(definition_id):
			return _reject("definition_duplicate")
		if not _valid_public_text(definition["display_name"], false, 64):
			return _reject("definition_name")
		if typeof(definition["icon_key"]) != TYPE_STRING or not ICON_KEYS.has(definition["icon_key"]):
			return _reject("definition_icon")
		if typeof(definition["pattern_key"]) != TYPE_STRING or not PATTERN_KEYS.has(definition["pattern_key"]):
			return _reject("definition_pattern")
		if not _valid_hex_color(definition["accent_hex"]):
			return _reject("definition_color")
		definitions_by_id[definition_id] = definition
	for expected_id: String in WEATHER_IDS:
		if not definitions_by_id.has(expected_id):
			return _reject("definition_missing")
	return true


func _validate_source_event(raw_event: Variant, definitions_by_id: Dictionary, event_ids: Dictionary) -> bool:
	if typeof(raw_event) != TYPE_DICTIONARY:
		return _reject("event_type")
	var event := raw_event as Dictionary
	if not _has_exact_keys(event, SOURCE_EVENT_KEYS):
		return _reject("event_keys")
	if typeof(event["event_id"]) != TYPE_INT or int(event["event_id"]) < 1:
		return _reject("event_id")
	if event_ids.has(event["event_id"]):
		return _reject("event_duplicate")
	event_ids[event["event_id"]] = true
	if typeof(event["definition_id"]) != TYPE_STRING or not definitions_by_id.has(event["definition_id"]):
		return _reject("event_definition")
	if typeof(event["phase"]) != TYPE_STRING or not PHASES.has(event["phase"]):
		return _reject("event_phase")
	if typeof(event["source_type"]) != TYPE_STRING or not SOURCE_TYPES.has(event["source_type"]):
		return _reject("event_source_type")
	if typeof(event["remaining_us"]) != TYPE_INT or int(event["remaining_us"]) < 0:
		return _reject("event_remaining")
	if not _valid_intensity(event["intensity"], event["phase"]):
		return _reject("event_intensity")
	if typeof(event["regions"]) != TYPE_ARRAY or not _validate_regions(event["regions"] as Array):
		return false
	if typeof(event["effects"]) != TYPE_ARRAY or not _validate_effects(event["effects"] as Array):
		return false
	if not _valid_public_text(event["exploitation_hint"], false, 256):
		return _reject("event_exploitation_hint")
	if not _valid_public_text(event["counterplay_hint"], false, 256):
		return _reject("event_counterplay_hint")
	return true


func _validate_regions(regions: Array) -> bool:
	if regions.is_empty() or regions.size() > 32:
		return _reject("regions_count")
	var seen: Dictionary = {}
	for raw_region: Variant in regions:
		if typeof(raw_region) != TYPE_DICTIONARY:
			return _reject("region_type")
		var region := raw_region as Dictionary
		if not _has_exact_keys(region, REGION_KEYS):
			return _reject("region_keys")
		if typeof(region["region_index"]) != TYPE_INT or int(region["region_index"]) < 0:
			return _reject("region_index")
		if seen.has(region["region_index"]):
			return _reject("region_duplicate")
		seen[region["region_index"]] = true
		if not _valid_public_text(region["label"], false, 64):
			return _reject("region_label")
	return true


func _validate_effects(effects: Array) -> bool:
	if effects.size() != 3:
		return _reject("effects_count")
	var effect_ids: Dictionary = {}
	for raw_effect: Variant in effects:
		if typeof(raw_effect) != TYPE_DICTIONARY:
			return _reject("effect_type")
		var effect := raw_effect as Dictionary
		if not _has_exact_keys(effect, EFFECT_KEYS):
			return _reject("effect_keys")
		if not _valid_machine_token(effect["effect_id"], 64):
			return _reject("effect_id")
		if effect_ids.has(effect["effect_id"]):
			return _reject("effect_duplicate")
		effect_ids[effect["effect_id"]] = true
		if typeof(effect["scope"]) != TYPE_STRING or not EFFECT_SCOPES.has(effect["scope"]):
			return _reject("effect_scope")
		if typeof(effect["polarity"]) != TYPE_STRING or not EFFECT_POLARITIES.has(effect["polarity"]):
			return _reject("effect_polarity")
		if not _valid_public_text(effect["label"], false, 96):
			return _reject("effect_label")
		if not _valid_public_text(effect["value_text"], false, 96):
			return _reject("effect_value")
		if typeof(effect["classification_tags"]) != TYPE_ARRAY:
			return _reject("effect_tags_type")
		var tags := effect["classification_tags"] as Array
		if tags.is_empty() or tags.size() > 8:
			return _reject("effect_tags_count")
		for tag: Variant in tags:
			if not _valid_machine_token(tag, 64):
				return _reject("effect_tag")
	return true


func _valid_intensity(raw_intensity: Variant, phase: String) -> bool:
	if typeof(raw_intensity) != TYPE_FLOAT and typeof(raw_intensity) != TYPE_INT:
		return false
	var intensity := float(raw_intensity)
	if not is_finite(intensity) or intensity < 0.0 or intensity > 1.0:
		return false
	if phase == "queued" or phase == "forecast":
		return is_zero_approx(intensity)
	if phase == "active":
		return is_equal_approx(intensity, 1.0)
	return true


func _state_for_events(events: Array) -> String:
	if events.is_empty():
		return "clear"
	var phases: Dictionary = {}
	for raw_event: Variant in events:
		phases[(raw_event as Dictionary)["phase"]] = true
	if phases.size() == 1:
		return str(phases.keys()[0])
	return "mixed"


func _build_summary(events: Array, state: String) -> Dictionary:
	if events.is_empty():
		return {
			"headline": "天气平稳",
			"detail": "当前没有区域天气事件。",
			"accessible_text": "天气平稳。当前没有区域天气事件。",
		}
	var event := events[0] as Dictionary
	var region_names: Array[String] = []
	for raw_region: Variant in event["regions"]:
		region_names.append(str((raw_region as Dictionary)["label"]))
	var headline := "%s · %s" % [event["display_name"], _phase_label(event["phase"])]
	var detail := "%s；剩余 %s" % ["、".join(region_names), _duration_label(event["remaining_us"])]
	if events.size() > 1:
		detail += "；另有 %d 个天气事件" % (events.size() - 1)
	return {
		"headline": headline,
		"detail": detail,
		"accessible_text": "%s。%s。" % [headline, detail],
	}


func _event_accessible_text(definition: Dictionary, event: Dictionary) -> String:
	var region_names: Array[String] = []
	for raw_region: Variant in event["regions"]:
		region_names.append(str((raw_region as Dictionary)["label"]))
	var effect_lines: Array[String] = []
	for raw_effect: Variant in event["effects"]:
		var effect := raw_effect as Dictionary
		effect_lines.append("%s %s" % [effect["label"], effect["value_text"]])
	return "%s，%s，区域 %s，剩余 %s。影响：%s。利用：%s。应对：%s。" % [
		definition["display_name"],
		_phase_label(event["phase"]),
		"、".join(region_names),
		_duration_label(event["remaining_us"]),
		"；".join(effect_lines),
		event["exploitation_hint"],
		event["counterplay_hint"],
	]


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


func _valid_public_text(value: Variant, allow_empty: bool, max_length: int) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text := value as String
	if not allow_empty and text.strip_edges().is_empty():
		return false
	if text.length() > max_length:
		return false
	var lowered := text.to_lower()
	for marker: String in FORBIDDEN_VALUE_MARKERS:
		if lowered.contains(marker):
			return false
	return true


func _valid_machine_token(value: Variant, max_length: int) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var token := value as String
	if token.is_empty() or token.length() > max_length:
		return false
	for index: int in range(token.length()):
		var character := token.substr(index, 1)
		if not "abcdefghijklmnopqrstuvwxyz0123456789_.:-".contains(character):
			return false
	return true


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


func _contains_forbidden_key(value: Variant) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		for raw_key: Variant in (value as Dictionary).keys():
			var key := str(raw_key).to_lower()
			if not ALLOWED_SOURCE_KEYS.has(key) and _key_has_forbidden_token(key):
				return true
			if _contains_forbidden_key((value as Dictionary)[raw_key]):
				return true
	elif typeof(value) == TYPE_ARRAY:
		for item: Variant in value as Array:
			if _contains_forbidden_key(item):
				return true
	return false


func _key_has_forbidden_token(key: String) -> bool:
	for token: String in FORBIDDEN_KEY_TOKENS:
		if key == token or key.begins_with(token + "_") or key.ends_with("_" + token) or key.contains("_" + token + "_"):
			return true
	return false


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
