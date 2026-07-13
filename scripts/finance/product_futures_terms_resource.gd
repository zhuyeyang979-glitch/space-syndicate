@tool
extends Resource
class_name ProductFuturesTermsResource

@export_category("Identity")
@export var card_id := ""
@export_range(1, 4, 1) var rank := 1
@export var terms_version := "v0.4"

@export_category("Position")
@export_enum("up", "down") var direction := "up"
@export_range(5.0, 600.0, 1.0) var duration_seconds := 60.0
@export_range(0.1, 10.0, 0.05) var multiplier := 1.0
@export_range(1, 64, 1) var units := 1
@export var requires_warehouse := false

@export_category("Cash Terms")
@export_range(0, 5000, 1) var action_fee_cash := 0
@export_range(0, 5000, 1) var margin_cash := 120
@export_range(0, 10000, 1) var maximum_gain := 260
@export_range(0, 5000, 1) var maximum_loss := 120

@export_category("Settlement")
@export_enum("effect_open") var entry_lock_mode := "effect_open"
@export var settlement_formula_id := "product_futures_v04_settlement"
@export var warehouse_loss_formula_id := "warehouse_futures_v04_loss"
@export_multiline var design_note := "Purchase price remains separate. Queue authorizes cash; the market controller locks refundable margin when the effect opens."


func to_runtime_dictionary() -> Dictionary:
	return {
		"card_id": card_id,
		"rank": rank,
		"terms_version": terms_version,
		"direction": direction,
		"duration_seconds": duration_seconds,
		"multiplier": multiplier,
		"units": units,
		"requires_warehouse": requires_warehouse,
		"action_fee_cash": action_fee_cash,
		"margin_cash": margin_cash,
		"maximum_gain": maximum_gain,
		"maximum_loss": maximum_loss,
		"entry_lock_mode": entry_lock_mode,
		"settlement_formula_id": settlement_formula_id,
		"warehouse_loss_formula_id": warehouse_loss_formula_id,
		"partial_damage_settlement": false,
	}


func validation_issues() -> Array:
	var issues: Array = []
	if card_id.strip_edges() == "": issues.append("card_id_missing")
	if not ["up", "down"].has(direction): issues.append("direction_invalid")
	if duration_seconds < 5.0: issues.append("duration_invalid")
	if multiplier <= 0.0 or units <= 0: issues.append("exposure_invalid")
	if margin_cash <= 0 or maximum_gain <= 0: issues.append("cash_terms_invalid")
	if maximum_loss < 0 or maximum_loss > margin_cash: issues.append("maximum_loss_exceeds_margin")
	if settlement_formula_id == "": issues.append("settlement_formula_missing")
	if requires_warehouse and warehouse_loss_formula_id == "": issues.append("warehouse_formula_missing")
	return issues
