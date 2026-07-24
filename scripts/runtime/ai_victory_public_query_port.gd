@tool
extends Node
class_name AiVictoryPublicQueryPort

const TIMER_IDS := ["victory_qualification", "public_audit"]
const PROHIBITED_PRIVATE_KEYS := [
	"own_economic_assets",
	"available_cents",
	"escrow_cents",
	"ordinary_hand",
	"facilities",
	"installations",
	"commodity_inventory",
	"color_gdp",
	"units",
	"financial_positions",
]

@export var victory_control_runtime_controller_path: NodePath

var _query_count := 0
var _rejected_query_count := 0


func is_ready() -> bool:
	return _victory() != null


func public_snapshot() -> Dictionary:
	_query_count += 1
	if not is_ready():
		_rejected_query_count += 1
		return {}
	var result := _victory().public_snapshot()
	var victory_rule: Variant = result.get("victory_rule", {})
	result["available"] = victory_rule is Dictionary and not (victory_rule as Dictionary).is_empty()
	if str(result.get("visibility_scope", "")) != "public" \
			or _contains_prohibited_private_key(result) \
			or not TablePresentationPureDataPolicy.is_pure_data(result):
		_rejected_query_count += 1
		return {}
	return TablePresentationPureDataPolicy.detached_copy(result)


func timer_duration(timer_id: String) -> float:
	_query_count += 1
	if not is_ready() or not TIMER_IDS.has(timer_id):
		_rejected_query_count += 1
		return 0.0
	return maxf(0.0, _victory().timer_duration(timer_id))


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"query_count": _query_count,
		"rejected_query_count": _rejected_query_count,
		"returns_public_victory_only": true,
		"returns_private_assets": false,
		"returns_rival_private_audit": false,
		"mutates_world": false,
		"consumes_rng": false,
		"references_main": false,
		"owns_state": false,
	}


func _contains_prohibited_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if PROHIBITED_PRIVATE_KEYS.has(str(key_variant)) \
					or _contains_prohibited_private_key((value as Dictionary).get(key_variant)):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_prohibited_private_key(item):
				return true
	return false


func _victory() -> VictoryControlRuntimeController:
	return get_node_or_null(victory_control_runtime_controller_path) as VictoryControlRuntimeController
