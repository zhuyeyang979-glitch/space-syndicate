extends RefCounted
class_name V074AssetPipPresenter

const DISPLAY_MODE := "repeated_symbol_pips"
const ASSET_CAP := 6
const PIP_SLOT_COUNT := 6
const COLORS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]
const PIP_AVAILABLE := "available"
const PIP_RESERVED := "reserved"
const PIP_EMPTY := "empty"


static func model_from_projection(
	projection: Dictionary,
	color_id: String
) -> Dictionary:
	if color_id not in COLORS:
		return {}
	var exact_by_color := (
		projection.get("own_exact_assets", {}) as Dictionary
	)
	var available_by_color := (
		projection.get("own_available_assets", {}) as Dictionary
	)
	var projected_by_color := (
		projection.get("own_projected_refresh", {}) as Dictionary
	)
	var exact := clampi(int(exact_by_color.get(color_id, 0)), 0, ASSET_CAP)
	var available := clampi(
		int(available_by_color.get(color_id, 0)),
		0,
		exact
	)
	var reserved := exact - available
	var projected_final := clampi(
		int(projected_by_color.get(color_id, available)),
		0,
		ASSET_CAP
	)
	var projected_refresh := clampi(
		projected_final - available,
		0,
		ASSET_CAP
	)
	var states: Array[String] = []
	for index in range(PIP_SLOT_COUNT):
		if index < available:
			states.append(PIP_AVAILABLE)
		elif index < exact:
			states.append(PIP_RESERVED)
		else:
			states.append(PIP_EMPTY)
	return {
		"schema": "V074AssetPipModelV1",
		"display_mode": DISPLAY_MODE,
		"color_id": color_id,
		"current": exact,
		"available": available,
		"reserved": reserved,
		"empty": ASSET_CAP - exact,
		"cap": ASSET_CAP,
		"projected_final": projected_final,
		"projected_refresh": projected_refresh,
		"overflow_risk": projected_final >= ASSET_CAP,
		"pip_states": states,
		"source_projection_fingerprint": str(
			projection.get("projection_fingerprint", "")
		),
	}


static func tooltip_text(
	display_name: String,
	model: Dictionary
) -> String:
	return (
		"%s资产：当前%d，可用%d，预留%d，上限%d，预计刷新%d，溢出风险：%s"
		% [
			display_name,
			int(model.get("current", 0)),
			int(model.get("available", 0)),
			int(model.get("reserved", 0)),
			int(model.get("cap", ASSET_CAP)),
			int(model.get("projected_refresh", 0)),
			"是" if bool(model.get("overflow_risk", false)) else "否",
		]
	)


static func grid_columns(_layout_mode: String) -> int:
	return COLORS.size()


static func validation_report(model: Dictionary) -> Dictionary:
	var states := model.get("pip_states", []) as Array
	var available_count := states.count(PIP_AVAILABLE)
	var reserved_count := states.count(PIP_RESERVED)
	var empty_count := states.count(PIP_EMPTY)
	var valid := (
		str(model.get("schema", "")) == "V074AssetPipModelV1"
		and str(model.get("display_mode", "")) == DISPLAY_MODE
		and str(model.get("color_id", "")) in COLORS
		and states.size() == PIP_SLOT_COUNT
		and available_count == int(model.get("available", -1))
		and reserved_count == int(model.get("reserved", -1))
		and empty_count == int(model.get("empty", -1))
		and available_count + reserved_count + empty_count == ASSET_CAP
		and int(model.get("current", -1)) == available_count + reserved_count
		and int(model.get("cap", -1)) == ASSET_CAP
		and int(model.get("projected_refresh", -1)) >= 0
		and int(model.get("projected_refresh", -1)) <= ASSET_CAP
	)
	return {
		"valid": valid,
		"reason_code": "asset_pip_model_valid" if valid 			else "asset_pip_model_invalid",
		"pip_slot_count": states.size(),
		"available_count": available_count,
		"reserved_count": reserved_count,
		"empty_count": empty_count,
	}


static func projection_privacy_report(projection: Dictionary) -> Dictionary:
	var forbidden_keys := [
		"players",
		"other_exact_assets",
		"other_reservations",
		"opponent_assets",
		"authority_state",
		"save_payload",
	]
	var disclosure_count := 0
	for key in forbidden_keys:
		if _contains_key_recursive(projection, key):
			disclosure_count += 1
	return {
		"valid": disclosure_count == 0,
		"opponent_private_asset_disclosure_count": disclosure_count,
		"direct_runtime_state_read_count": 0,
	}


static func _contains_key_recursive(value: Variant, key_name: String) -> bool:
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			if str(key_variant) == key_name:
				return true
			if _contains_key_recursive(dictionary.get(key_variant), key_name):
				return true
	elif value is Array:
		for child in value as Array:
			if _contains_key_recursive(child, key_name):
				return true
	return false
