extends "res://scripts/content/compendium_codex_entry_resource.gd"
class_name CardCodexEntryResource

@export var rank := "I"
@export var card_kind := "Reference"
@export var cost := "$0"
@export var target := "Public target"
@export var route := "Public route"
@export_multiline var requirement := "Public requirement."
@export_multiline var effect := "Public effect summary."
@export_multiline var read_order := "Cost -> target -> route -> effect -> upgrade ladder"
@export_multiline var face_note := "Codex display entry. Gameplay values still come from the existing rules layer."
@export_multiline var timing_note := "Use when the public board state makes the line readable."
@export_multiline var risk_note := "Public pressure can telegraph intent."
@export_multiline var public_resolution_note := "Public track records the result without hidden owner data."
@export_multiline var upgrade_i_note := "Entry-level public effect."
@export_multiline var upgrade_iv_note := "Peak public effect, still privacy-safe."
@export var tactical_notes: PackedStringArray = []
@export var fact_notes: PackedStringArray = []


func entry_kind() -> String:
	return "card"


func required_fields_missing() -> Array[String]:
	var missing := super.required_fields_missing()
	if card_kind.strip_edges() == "":
		missing.append("card_kind")
	if cost.strip_edges() == "":
		missing.append("cost")
	if effect.strip_edges() == "":
		missing.append("effect")
	return missing


func to_card_codex_payload() -> Dictionary:
	var tactical_entries := _note_cards(tactical_notes, "Line", accent)
	if tactical_entries.is_empty():
		tactical_entries = [
			{"title": "Timing", "body": timing_note, "accent": accent},
			{"title": "Target", "body": target, "accent": "#93c5fd"},
			{"title": "Risk", "body": risk_note, "accent": "#facc15"},
		]
	var fact_entries := _note_cards(fact_notes, "Fact", "#93c5fd")
	if fact_entries.is_empty():
		fact_entries = [
			{"title": "Requirement", "body": requirement, "meta": "Public", "accent": "#93c5fd"},
			{"title": "Privacy", "body": "No hidden owner, private target, or private discard fields are stored in this codex resource.", "meta": "Sanitized", "accent": "#f472b6"},
		]
	return {
		"entry_id": entry_id,
		"entry_type": entry_kind(),
		"accent": accent,
		"face_note": face_note,
		"card_face": {
			"name": display_name,
			"rank": rank,
			"type": card_kind,
			"cost": cost,
			"effect": effect,
			"minimum_width": 230.0,
			"minimum_height": 300.0,
		},
		"summary": {
			"title": "Scan order",
			"accent": accent,
			"header_chips": [{"text": cost, "accent": "#facc15"}, {"text": "Target: %s" % target, "accent": "#93c5fd"}],
			"chips": _chips_to_payload(chips, accent),
			"effect": effect,
			"read_order": read_order,
		},
		"tactical": {
			"title": "Table use | read these first",
			"entries": tactical_entries,
		},
		"facts": fact_entries,
		"upgrades": [
			{"roman": "I", "price": cost, "band": "Entry", "body": upgrade_i_note, "accent": accent},
			{"roman": "IV", "price": cost, "band": "Peak", "body": upgrade_iv_note, "accent": "#facc15"},
		],
		"resolution": {"title": "Resolution", "body": public_resolution_note, "meta": "Public note only.", "accent": "#22c55e"},
	}


func to_payload() -> Dictionary:
	return to_card_codex_payload()
