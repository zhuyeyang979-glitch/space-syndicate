@tool
extends Resource
class_name GdpFormulaProfileV05Resource

@export var profile_id := "gdp_formula_v05"
@export var schema_version := "v0.5.structured-project-gdp.1"
@export var display_name := "Space Syndicate Structured Project GDP v0.5"
@export_multiline var design_notes := "Inspector-editable parameters for project-keyed GDP rows. Region GDP may reach zero; no minimum-city floor exists."

@export_group("Production GDP")
@export_range(0, 1000, 1) var product_base_revenue := 42
@export_range(0, 1000, 1) var product_rank_revenue := 12
@export_range(1, 1000, 1) var product_price_revenue_divisor := 5
@export_range(0.0, 10.0, 0.01) var production_gdp_scale := 0.58

@export_group("Demand GDP")
@export_range(0, 1000, 1) var demand_supply_revenue := 28
@export_range(1, 1000, 1) var demand_price_revenue_divisor := 8
@export_range(0.0, 10.0, 0.01) var consumption_gdp_scale := 0.72

@export_group("Commerce GDP")
@export_range(0, 1000, 1) var transit_gdp_base := 18
@export_range(1, 1000, 1) var transit_price_divisor := 20

@export_group("Pressure")
@export_range(0, 1000, 1) var competition_penalty := 16
@export_range(0, 1000, 1) var trade_disruption_penalty := 55
@export_range(0, 1000, 1) var district_damage_penalty := 18

@export_group("Bounds and allocation")
@export_range(0.0, 10.0, 0.01) var minimum_flow_amount := 0.25
@export var zero_gdp_allowed := true
@export_enum("proportional_gross_receipt_id") var pressure_allocation_mode := "proportional_gross_receipt_id"


func to_dictionary() -> Dictionary:
	return {
		"profile_id": profile_id,
		"schema_version": schema_version,
		"display_name": display_name,
		"product_base_revenue": product_base_revenue,
		"product_rank_revenue": product_rank_revenue,
		"product_price_revenue_divisor": product_price_revenue_divisor,
		"production_gdp_scale": production_gdp_scale,
		"demand_supply_revenue": demand_supply_revenue,
		"demand_price_revenue_divisor": demand_price_revenue_divisor,
		"consumption_gdp_scale": consumption_gdp_scale,
		"transit_gdp_base": transit_gdp_base,
		"transit_price_divisor": transit_price_divisor,
		"competition_penalty": competition_penalty,
		"trade_disruption_penalty": trade_disruption_penalty,
		"district_damage_penalty": district_damage_penalty,
		"minimum_flow_amount": minimum_flow_amount,
		"zero_gdp_allowed": zero_gdp_allowed,
		"pressure_allocation_mode": pressure_allocation_mode,
	}


func validate_profile() -> Array:
	return [
		_validation_record("identity", profile_id == "gdp_formula_v05" and schema_version.begins_with("v0.5."), "profile and row schema are v0.5"),
		_validation_record("price_divisors", product_price_revenue_divisor > 0 and demand_price_revenue_divisor > 0 and transit_price_divisor > 0, "all price divisors are positive"),
		_validation_record("scales", production_gdp_scale > 0.0 and consumption_gdp_scale > 0.0, "production and demand scales are positive"),
		_validation_record("pressure", competition_penalty >= 0 and trade_disruption_penalty >= 0 and district_damage_penalty >= 0, "pressure values are non-negative"),
		_validation_record("zero_gdp", zero_gdp_allowed, "v0.5 permits a region to reach zero GDP"),
		_validation_record("allocation", pressure_allocation_mode == "proportional_gross_receipt_id" and minimum_flow_amount > 0.0, "pressure and flow allocation are deterministic"),
	]


func _validation_record(record_id: String, passed: bool, notes: String) -> Dictionary:
	return {"id": record_id, "passed": passed, "notes": notes}
