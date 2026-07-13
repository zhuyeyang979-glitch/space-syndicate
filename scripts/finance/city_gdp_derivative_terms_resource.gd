@tool
extends Resource
class_name CityGdpDerivativeTermsResource

@export_category("Identity")
@export var card_id := ""
@export_range(1, 4, 1) var rank := 1
@export var terms_version := "v0.4"

@export_category("Position")
@export_enum("up", "down") var direction := "up"
@export var insurance := false
@export_range(5.0, 600.0, 1.0) var duration_seconds := 60.0
@export_range(0.1, 10.0, 0.05) var multiplier := 1.0
@export_range(0, 5000, 1) var destroy_bonus := 0
@export_enum("any_active_city", "owned_active_city") var target_scope := "any_active_city"

@export_category("Cash Terms")
@export_range(0, 5000, 1) var action_fee_cash := 0
@export_range(0, 5000, 1) var margin_cash := 120
@export_range(0, 10000, 1) var maximum_gain := 260
@export_range(0, 5000, 1) var maximum_loss := 120

@export_category("Settlement")
@export_enum("effect_open") var entry_lock_mode := "effect_open"
@export var reference_value_kind := "city_gdp_per_minute"
@export var settlement_formula_id := "city_gdp_derivative_v04_settlement"
@export var destruction_formula_id := "city_gdp_derivative_v04_destruction"
@export_multiline var design_note := "Purchase price remains separate. Queue authorizes cash; the city GDP derivative controller locks refundable margin when the effect opens."


func to_runtime_dictionary() -> Dictionary:
	return {
		"card_id": card_id,
		"rank": rank,
		"terms_version": terms_version,
		"direction": direction,
		"insurance": insurance,
		"duration_seconds": duration_seconds,
		"multiplier": multiplier,
		"destroy_bonus": destroy_bonus,
		"target_scope": target_scope,
		"action_fee_cash": action_fee_cash,
		"margin_cash": margin_cash,
		"maximum_gain": maximum_gain,
		"maximum_loss": maximum_loss,
		"entry_lock_mode": entry_lock_mode,
		"reference_value_kind": reference_value_kind,
		"settlement_formula_id": settlement_formula_id,
		"destruction_formula_id": destruction_formula_id,
	}


func validation_issues() -> Array:
	var issues: Array = []
	if card_id.strip_edges() == "": issues.append("card_id_missing")
	if not ["up", "down"].has(direction): issues.append("direction_invalid")
	if duration_seconds < 5.0: issues.append("duration_invalid")
	if multiplier <= 0.0: issues.append("multiplier_invalid")
	if insurance and (direction != "down" or target_scope != "owned_active_city"): issues.append("insurance_boundary_invalid")
	if not insurance and target_scope != "any_active_city": issues.append("speculation_target_scope_invalid")
	if margin_cash <= 0 or maximum_gain <= 0: issues.append("cash_terms_invalid")
	if maximum_loss < 0 or maximum_loss > margin_cash: issues.append("maximum_loss_exceeds_margin")
	if settlement_formula_id == "" or destruction_formula_id == "": issues.append("settlement_formula_missing")
	return issues
