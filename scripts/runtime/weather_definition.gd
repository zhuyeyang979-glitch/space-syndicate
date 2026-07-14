@tool
extends Resource
class_name WeatherDefinition

const REQUIRED_EFFECT_KEYS := [
	"economy_multiplier",
	"route_multiplier",
	"monster_speed_multiplier",
	"military_multiplier",
	"intel_multiplier",
]

@export var id := ""
@export var display_name := ""
@export var public_summary := ""
@export var icon_key := ""
@export var accent_color := Color("#93c5fd")
@export var affected_region_count := 1
@export var economy_multiplier := 1.0
@export var route_multiplier := 1.0
@export var monster_speed_multiplier := 1.0
@export var military_multiplier := 1.0
@export var intel_multiplier := 1.0
@export var orbital_effect_multiplier := 1.0
@export var city_maintenance_multiplier := 1.0
@export var damage_per_second := 0.0
@export var damage_nonlethal := false
@export var damage_capped := false
@export var context_tags: PackedStringArray = PackedStringArray()
@export var explanation_codes: PackedStringArray = PackedStringArray()


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"label": display_name,
		"public_summary": public_summary,
		"icon_key": icon_key,
		"accent_color": accent_color.to_html(),
		"affected_region_count": affected_region_count,
		"economy_multiplier": economy_multiplier,
		"route_multiplier": route_multiplier,
		"transport_multiplier": route_multiplier,
		"monster_speed_multiplier": monster_speed_multiplier,
		"military_multiplier": military_multiplier,
		"intel_multiplier": intel_multiplier,
		"orbital_effect_multiplier": orbital_effect_multiplier,
		"city_maintenance_multiplier": city_maintenance_multiplier,
		"damage_per_second": damage_per_second,
		"damage_nonlethal": damage_nonlethal,
		"damage_capped": damage_capped,
		"context_tags": Array(context_tags),
		"explanation_codes": Array(explanation_codes),
	}


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id.strip_edges().is_empty():
		errors.append("id_missing")
	if display_name.strip_edges().is_empty():
		errors.append("display_name_missing")
	if affected_region_count != 1:
		errors.append("affected_region_count_must_be_1")
	if economy_multiplier < 1.10 or economy_multiplier > 1.30:
		errors.append("economy_multiplier_out_of_guardrail")
	if route_multiplier < 0.40:
		errors.append("route_multiplier_below_floor")
	if monster_speed_multiplier > 1.30:
		errors.append("monster_speed_above_cap")
	if military_multiplier < 0.70:
		errors.append("military_multiplier_below_floor")
	if intel_multiplier < 0.70:
		errors.append("intel_multiplier_below_floor")
	if damage_per_second > 0.0 and (not damage_nonlethal or not damage_capped):
		errors.append("damage_must_be_nonlethal_and_capped")
	return errors


func is_valid_definition() -> bool:
	return validation_errors().is_empty()
