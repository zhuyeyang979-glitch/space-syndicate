extends RefCounted
class_name CardBalanceAnalyzer

const PROFILE_SCRIPT := preload("res://scripts/balance/card_balance_profile.gd")
const PRICE_CURVE_SCRIPT := preload("res://scripts/balance/card_price_curve.gd")
const DEFAULT_CARD_SET_PATH := "res://data/balance/vertical_slice_card_set.json"
const VERTICAL_SLICE_SCENARIOS := ["first_table", "monster_pressure", "public_track_intro", "bid_practice"]

var price_curve: Variant = PRICE_CURVE_SCRIPT.new()
var cards: Array = []


func load_defaults() -> bool:
	price_curve.call("load_default")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_CARD_SET_PATH))
	if not (parsed is Array):
		return false
	cards = parsed as Array
	return true


func analyze() -> Dictionary:
	if cards.is_empty():
		load_defaults()
	var rows: Array = []
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card: Dictionary = PROFILE_SCRIPT.normalize_card(card_variant as Dictionary)
		var suggested: int = int(price_curve.call("suggested_price", card))
		var current := int(card.get("current_price", 0))
		var row := card.duplicate(true)
		row["suggested_price"] = suggested
		row["delta"] = suggested - current
		row["power_score"] = int(card.get("effect_power", 0))
		row["hidden_info_score"] = int(card.get("hidden_info_premium", 0))
		row["economy_impact_score"] = int(card.get("economy_scaling_premium", 0))
		row["monster_impact_score"] = _monster_impact_score(card)
		row["interaction_score"] = int(card.get("interaction_premium", 0))
		row["onboarding_difficulty"] = PROFILE_SCRIPT.onboarding_difficulty(card)
		row["scenario_fit"] = card.get("scenario_tags", [])
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return abs(int(a.get("delta", 0))) > abs(int(b.get("delta", 0)))
	)
	return {
		"rows": rows,
		"price_too_low_top20": _top_by_delta(rows, true),
		"price_too_high_top20": _top_by_delta(rows, false),
		"rank_gradient_anomalies": _rank_gradient_anomalies(rows),
		"scenario_power_curve": _scenario_power_curve(rows),
		"scenario_recommendations": _scenario_recommendations_map(rows),
		"first_table_recommendations": _scenario_recommendations(rows, "first_table"),
		"complexity_exclusions": _complexity_exclusions(rows),
	}


func _top_by_delta(rows: Array, too_low: bool) -> Array:
	var filtered: Array = []
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant as Dictionary
		var delta := int(row.get("delta", 0))
		if too_low and delta > 0:
			filtered.append(row)
		elif not too_low and delta < 0:
			filtered.append(row)
	filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("delta", 0)) > int(b.get("delta", 0)) if too_low else int(a.get("delta", 0)) < int(b.get("delta", 0))
	)
	return filtered.slice(0, mini(20, filtered.size()))


func _rank_gradient_anomalies(rows: Array) -> Array:
	var anomalies: Array = []
	var by_family := {}
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant as Dictionary
		var family := str(row.get("card_id", "")).replace("_i", "").replace("_ii", "").replace("_iii", "").replace("_iv", "")
		if not by_family.has(family):
			by_family[family] = []
		(by_family[family] as Array).append(row)
	for family in by_family.keys():
		var family_rows: Array = by_family[family]
		family_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _rank_order(str(a.get("rank", "I"))) < _rank_order(str(b.get("rank", "I")))
		)
		var previous_price := -1
		for row_variant in family_rows:
			var row: Dictionary = row_variant as Dictionary
			var current := int(row.get("current_price", 0))
			if previous_price >= 0 and current < previous_price:
				anomalies.append({
					"family": family,
					"card_id": row.get("card_id", ""),
					"issue": "rank price drops below previous rank",
				})
			previous_price = current
	return anomalies


func _scenario_recommendations(rows: Array, scenario_tag: String) -> Array:
	var picks: Array = []
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant
		var tags: Array = row.get("scenario_fit", []) if row.get("scenario_fit", []) is Array else []
		if tags.has(scenario_tag) and str(row.get("onboarding_difficulty", "")) != "hard":
			picks.append(row)
	picks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("complexity_score", 0)) < int(b.get("complexity_score", 0))
	)
	return picks.slice(0, mini(12, picks.size()))


func _scenario_recommendations_map(rows: Array) -> Dictionary:
	var mapped := {}
	for scenario_id in VERTICAL_SLICE_SCENARIOS:
		mapped[scenario_id] = _scenario_recommendations(rows, scenario_id)
	return mapped


func _scenario_power_curve(rows: Array) -> Array:
	var curve: Array = []
	for scenario_id in VERTICAL_SLICE_SCENARIOS:
		var tagged_rows: Array = []
		for row_variant in rows:
			if not (row_variant is Dictionary):
				continue
			var row: Dictionary = row_variant
			var tags: Array = row.get("scenario_fit", []) if row.get("scenario_fit", []) is Array else []
			if tags.has(scenario_id):
				tagged_rows.append(row)
		curve.append(_scenario_curve_row(scenario_id, tagged_rows))
	return curve


func _scenario_curve_row(scenario_id: String, rows: Array) -> Dictionary:
	var current_total := 0
	var suggested_total := 0
	var power_total := 0
	var complexity_total := 0
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant
		current_total += int(row.get("current_price", 0))
		suggested_total += int(row.get("suggested_price", 0))
		power_total += int(row.get("power_score", 0))
		complexity_total += int(row.get("complexity_score", 0))
	var count := maxi(1, rows.size())
	return {
		"scenario_id": scenario_id,
		"card_count": rows.size(),
		"avg_current_price": int(round(float(current_total) / float(count))),
		"avg_suggested_price": int(round(float(suggested_total) / float(count))),
		"avg_power_score": int(round(float(power_total) / float(count))),
		"avg_complexity_score": int(round(float(complexity_total) / float(count))),
	}


func _monster_impact_score(card: Dictionary) -> int:
	var explicit := int(card.get("monster_impact_score", 0))
	if explicit > 0:
		return explicit
	var tags: Array = card.get("scenario_tags", []) if card.get("scenario_tags", []) is Array else []
	if tags.has("monster_pressure") or ["怪兽", "军队"].has(str(card.get("type", ""))):
		return int(card.get("effect_power", 0))
	return 0


func _complexity_exclusions(rows: Array) -> Array:
	var excluded: Array = []
	for row_variant in rows:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("onboarding_difficulty", "")) == "hard":
			excluded.append(row_variant)
	return excluded


func _rank_order(rank: String) -> int:
	match rank:
		"I":
			return 1
		"II":
			return 2
		"III":
			return 3
		"IV":
			return 4
	return 0
