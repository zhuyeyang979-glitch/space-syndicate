extends "res://scripts/content/compendium_codex_entry_resource.gd"
class_name MonsterCodexEntryResource

@export var hp := 10
@export var armor := 1
@export var move_text := "Move 1 | public pressure"
@export var style := "Orbital monster profile."
@export_multiline var profile := "Public ecology note."
@export var public_tells: PackedStringArray = []
@export var action_names: PackedStringArray = []
@export var action_tags: PackedStringArray = []
@export var action_probabilities: PackedStringArray = []
@export var action_facts: PackedStringArray = []
@export var action_bodies: PackedStringArray = []


func entry_kind() -> String:
	return "monster"


func required_fields_missing() -> Array[String]:
	var missing := super.required_fields_missing()
	if hp <= 0:
		missing.append("hp")
	if move_text.strip_edges() == "":
		missing.append("move_text")
	return missing


func to_bestiary_payload() -> Dictionary:
	return {
		"entry_id": entry_id,
		"entry_type": entry_kind(),
		"accent": accent,
		"title": display_name,
		"subtitle": subtitle,
		"art": {
			"name": display_name,
			"style": style,
			"hp": hp,
			"armor": armor,
			"move_text": move_text,
			"profile": {"accent": accent, "body": profile},
		},
		"chips": _chips_to_payload(chips, accent),
		"kpis": [
			{"title": "HP", "value": str(hp), "meta": "Public durability", "accent": accent},
			{"title": "Armor", "value": str(armor), "meta": "Public mitigation", "accent": "#facc15"},
			{"title": "Move", "value": move_text, "meta": "Public movement tell", "accent": "#38bdf8"},
			{"title": "Tell", "value": "Public", "meta": _tell_summary(), "accent": "#f472b6"},
		],
		"actions": _action_payloads(),
	}


func to_payload() -> Dictionary:
	return to_bestiary_payload()


func _tell_summary() -> String:
	var tells := _string_array(public_tells)
	return tells[0] if not tells.is_empty() else "No hidden owner data is present."


func _action_payloads() -> Array:
	var result: Array = []
	var action_count := maxi(1, action_names.size())
	for index in range(action_count):
		var action_name := str(action_names[index]) if index < action_names.size() else "Public Pressure"
		result.append({
			"index": "%02d" % (index + 1),
			"name": action_name,
			"tags": str(action_tags[index]) if index < action_tags.size() else "event",
			"probability": str(action_probabilities[index]) if index < action_probabilities.size() else "I 1/6 | IV 2/6",
			"facts": str(action_facts[index]) if index < action_facts.size() else "Public table effect.",
			"body": str(action_bodies[index]) if index < action_bodies.size() else "Effect appears as public information only.",
			"accent": accent if index == 0 else "#facc15",
		})
	return result
