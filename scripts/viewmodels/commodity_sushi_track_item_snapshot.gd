extends RefCounted
class_name CommoditySushiTrackItemSnapshot

const VALID_AVAILABILITY_STATES := ["available", "unavailable"]
const ALLOWED_INPUT_KEYS := [
	"commodity_slot_id",
	"commodity_card_id",
	"public_name",
	"public_icon_id",
	"slot_index",
	"availability_state",
	"claimable",
	"public_claim_disabled_reason",
	"public_supply_pressure",
	"public_demand_pressure",
	"public_market_price",
	"public_market_trend",
	"public_refresh_phase",
	"display_accent_id",
	"public_industry",
	"public_short_effect",
]

var commodity_slot_id := ""
var commodity_card_id := ""
var public_name := ""
var public_icon_id := "generic"
var slot_index := -1
var availability_state := "unavailable"
var claimable := false
var public_claim_disabled_reason := ""
var public_supply_pressure := 0
var public_demand_pressure := 0
var public_market_price := -1
var public_market_trend := 0
var public_refresh_phase := ""
var display_accent_id := "generic"
var public_industry := ""
var public_short_effect := ""
var _valid := false


func apply_dictionary(source: Dictionary) -> CommoditySushiTrackItemSnapshot:
	_valid = false
	for key_variant in source.keys():
		if not ALLOWED_INPUT_KEYS.has(str(key_variant)):
			return self
	commodity_slot_id = str(source.get("commodity_slot_id", "")).strip_edges()
	commodity_card_id = str(source.get("commodity_card_id", "")).strip_edges()
	public_name = str(source.get("public_name", "")).strip_edges()
	public_icon_id = str(source.get("public_icon_id", "generic")).strip_edges()
	slot_index = int(source.get("slot_index", -1))
	availability_state = str(source.get("availability_state", "unavailable")).strip_edges()
	claimable = bool(source.get("claimable", false))
	public_claim_disabled_reason = str(source.get("public_claim_disabled_reason", "")).strip_edges()
	public_supply_pressure = int(source.get("public_supply_pressure", 0))
	public_demand_pressure = int(source.get("public_demand_pressure", 0))
	public_market_price = int(source.get("public_market_price", -1))
	public_market_trend = int(source.get("public_market_trend", 0))
	public_refresh_phase = str(source.get("public_refresh_phase", "")).strip_edges()
	display_accent_id = str(source.get("display_accent_id", "generic")).strip_edges()
	public_industry = str(source.get("public_industry", "")).strip_edges()
	public_short_effect = str(source.get("public_short_effect", "")).strip_edges()
	_valid = _validation_errors().is_empty()
	return self


func is_valid() -> bool:
	return _valid and _validation_errors().is_empty()


func to_dictionary() -> Dictionary:
	if not is_valid():
		return {}
	return {
		"commodity_slot_id": commodity_slot_id,
		"commodity_card_id": commodity_card_id,
		"public_name": public_name,
		"public_icon_id": public_icon_id,
		"slot_index": slot_index,
		"availability_state": availability_state,
		"claimable": claimable,
		"public_claim_disabled_reason": public_claim_disabled_reason,
		"public_supply_pressure": public_supply_pressure,
		"public_demand_pressure": public_demand_pressure,
		"public_market_price": public_market_price,
		"public_market_trend": public_market_trend,
		"public_refresh_phase": public_refresh_phase,
		"display_accent_id": display_accent_id,
		"public_industry": public_industry,
		"public_short_effect": public_short_effect,
	}


func _validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if commodity_slot_id.is_empty():
		errors.append("commodity_slot_id_missing")
	if commodity_card_id.is_empty():
		errors.append("commodity_card_id_missing")
	if public_name.is_empty():
		errors.append("public_name_missing")
	if slot_index < 0:
		errors.append("slot_index_invalid")
	if not VALID_AVAILABILITY_STATES.has(availability_state):
		errors.append("availability_state_invalid")
	if claimable and availability_state != "available":
		errors.append("claimable_state_mismatch")
	if not claimable and public_claim_disabled_reason.is_empty():
		errors.append("disabled_reason_missing")
	return errors
