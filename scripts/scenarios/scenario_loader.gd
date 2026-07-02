extends RefCounted
class_name ScenarioLoader

const DEFINITION_SCRIPT := preload("res://scripts/scenarios/scenario_definition.gd")
const SCENARIO_IDS := [
	"first_table",
	"market_hand",
	"public_track_intro",
	"bid_practice",
	"monster_pressure",
	"contract_goods",
	"intel_guess",
	"final_countdown",
]
const SCENARIO_DIR := "res://data/scenarios"


func load_all() -> Array:
	var scenarios: Array = []
	for id_variant in SCENARIO_IDS:
		var definition := load_by_id(str(id_variant))
		if not definition.is_empty():
			scenarios.append(definition)
	return scenarios


func load_by_id(scenario_id: String) -> Dictionary:
	var path := "%s/%s.json" % [SCENARIO_DIR, scenario_id]
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	var definition: Variant = DEFINITION_SCRIPT.new().apply_dictionary(parsed as Dictionary)
	var dictionary: Dictionary = definition.to_dictionary()
	return dictionary if bool(definition.is_valid()) else {}


func scenario_ids() -> Array:
	return SCENARIO_IDS.duplicate(true)
