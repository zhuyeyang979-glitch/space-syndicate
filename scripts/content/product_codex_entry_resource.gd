extends "res://scripts/content/compendium_codex_entry_resource.gd"
class_name ProductCodexEntryResource

@export var glyph := "PR"
@export var profile := "Commodity | contract line"
@export var terrain := "Terrain: market"
@export var price := "$90 | base $90 | stable"
@export var demand := "Medium"
@export var supply := "Medium"
@export var risk := "2 / 5"
@export var volatility := "2"
@export_multiline var weather := "Weather pressure is public and table-readable."
@export_multiline var use_case := "Use this product to explain public market pressure."
@export var kpi_notes: PackedStringArray = []
@export var strategy_notes: PackedStringArray = []


func entry_kind() -> String:
	return "product"


func required_fields_missing() -> Array[String]:
	var missing := super.required_fields_missing()
	if profile.strip_edges() == "":
		missing.append("profile")
	if price.strip_edges() == "":
		missing.append("price")
	return missing


func to_product_codex_payload() -> Dictionary:
	var kpis := _product_kpis()
	var strategies := _note_cards(strategy_notes, "Strategy", accent)
	if strategies.is_empty():
		strategies = [
			{"title": "Safe line", "body": "Pair with visible route control and public market timing.", "accent": "#38bdf8"},
			{"title": "Aggressive line", "body": "Force auction tempo only when the public track already supports the read.", "accent": "#fb7185"},
			{"title": "Teaching note", "body": "Keep this reference public-safe and separate from rules data.", "accent": "#facc15"},
		]
	return {
		"entry_id": entry_id,
		"entry_type": entry_kind(),
		"accent": accent,
		"secondary": "#bbf7d0",
		"title": display_name,
		"subtitle": subtitle,
		"badge": {
			"glyph": glyph,
			"name": display_name,
			"profile": profile,
			"terrain": terrain,
			"price": price,
			"meter": "Supply %s Demand %s Risk %s Vol %s" % [supply, demand, risk, volatility],
			"weather": weather,
			"use": use_case,
			"accent": accent,
			"secondary": "#bbf7d0",
		},
		"chips": _chips_to_payload(chips, accent),
		"kpis": kpis,
		"strategies": strategies,
	}


func to_payload() -> Dictionary:
	return to_product_codex_payload()


func _product_kpis() -> Array:
	var notes := _string_array(kpi_notes)
	return [
		{"title": "Demand", "value": demand, "meta": notes[0] if notes.size() > 0 else "Demand is read from public market pressure.", "accent": accent},
		{"title": "Supply", "value": supply, "meta": notes[1] if notes.size() > 1 else "Supply is a public codex reference.", "accent": "#38bdf8"},
		{"title": "Volatility", "value": volatility, "meta": notes[2] if notes.size() > 2 else "Watch public route and event pressure.", "accent": "#facc15"},
		{"title": "Risk", "value": risk, "meta": notes[3] if notes.size() > 3 else "No hidden ownership appears in this entry.", "accent": "#fb7185"},
	]
