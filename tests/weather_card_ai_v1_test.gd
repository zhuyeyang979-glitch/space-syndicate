extends SceneTree

const WEATHER_CARD_PATHS := [
	"res://resources/cards/runtime/families/018_太阳风暴预报.tres",
	"res://resources/cards/runtime/families/019_酸雨云团播种.tres",
	"res://resources/cards/runtime/families/020_引力潮汐播报.tres",
	"res://resources/cards/runtime/families/021_电磁雾干涉.tres",
	"res://resources/cards/runtime/families/040_航线预报.tres",
]
const WEATHER_IDS := ["ion_storm", "gravity_tide", "spore_season", "crystal_dust_storm", "deep_freeze", "solar_flare"]
const DEFINITION_TIMING := {
	"ion_storm": [30.0, 45.0],
	"gravity_tide": [45.0, 75.0],
	"spore_season": [40.0, 70.0],
	"crystal_dust_storm": [35.0, 55.0],
	"deep_freeze": [60.0, 90.0],
	"solar_flare": [30.0, 45.0],
}

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var seen_ids: Dictionary = {}
	for path: String in WEATHER_CARD_PATHS:
		var family := load(path)
		_expect(family != null, "weather card family loads: %s" % path)
		if family == null:
			continue
		var ranks_variant: Variant = family.get("authored_ranks")
		var ranks: Array = ranks_variant if ranks_variant is Array else []
		_expect(not ranks.is_empty(), "weather card family has authored ranks: %s" % path)
		for rank_variant in ranks:
			var rank := rank_variant as Resource
			var parameters_variant: Variant = rank.get("effect_parameters")
			var parameters: Dictionary = parameters_variant if parameters_variant is Dictionary else {}
			var weather_id := str(parameters.get("weather_type", ""))
			seen_ids[weather_id] = true
			_expect(WEATHER_IDS.has(weather_id), "%s uses a Weather v1 definition id" % str(rank.get("card_id")))
			if DEFINITION_TIMING.has(weather_id):
				var timing := DEFINITION_TIMING[weather_id] as Array
				_expect(is_equal_approx(float(parameters.get("weather_forecast_lead_seconds", -1.0)), float(timing[0])), "%s card forecast matches its data definition" % str(rank.get("card_id")))
				_expect(is_equal_approx(float(parameters.get("weather_duration_seconds", -1.0)), float(timing[1])), "%s card duration matches its data definition" % str(rank.get("card_id")))
			_expect(int(parameters.get("weather_zone_count", 0)) == 1, "%s respects the first-version single-region definition" % str(rank.get("card_id")))

	var serialized_cards := ""
	for path: String in WEATHER_CARD_PATHS:
		serialized_cards += FileAccess.get_file_as_string(path)
	for retired_id: String in ["solar_storm", "acid_rain", "magnetic_fog"]:
		_expect(not serialized_cards.contains(retired_id), "weather cards physically retire %s" % retired_id)
	_expect(seen_ids.has("solar_flare") and seen_ids.has("spore_season") and seen_ids.has("gravity_tide") and seen_ids.has("ion_storm"), "existing weather cards cover four valid Weather v1 definitions")

	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	_expect(ai_source.contains("_ai_weather_definition_has_risk") and ai_source.contains("_ai_weather_definition_has_opportunity"), "AI classifies weather from definition multipliers")
	_expect(ai_source.contains("demand_multiplier") and ai_source.contains("ocean_movement_multiplier"), "AI consumes Weather v1 demand and movement fields")
	_expect(not ai_source.contains('["solar_storm", "acid_rain", "magnetic_fog"]') and not ai_source.contains('type_id = "solar_storm"'), "AI no longer uses the retired four-weather name table or fallback")

	print("WEATHER_CARD_AI_V1_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("WEATHER CARD AI V1: %s" % label)
