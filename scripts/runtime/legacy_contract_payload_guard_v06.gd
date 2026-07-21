extends RefCounted
class_name LegacyContractPayloadGuardV06

const RETIRED_KEYS := [
	"contract_response",
	"pending_contract_response",
	"pending_contract_responses",
	"pending_contract_offers",
	"contract_responder",
	"contract_response_deadline",
	"contract_response_status",
	"contract_response_state",
	"contract_response_receipt",
	"contract_accept",
	"accept_contract",
	"contract_reject",
	"reject_contract",
	"contract_timeout",
	"contract_penalty",
	"contract_signature",
	"awaiting_contract_response",
	"target_player_contract_consent",
	"area_trade_contract",
	"known_contract_parties",
	"district_pair",
	"is_contract",
	"contract_source_district",
	"contract_target_district",
	"contract_source_region_id",
	"contract_target_region_id",
	"contract_selection_revision",
	"contract_product",
	"trace_contract_count",
]
const RETIRED_SCALAR_VALUES := [
	"legacy_project_contract",
	"contract_response",
	"ContractResponse",
	"contract_accept",
	"accept_contract",
	"contract_reject",
	"reject_contract",
	"contract_timeout",
	"contract_penalty",
	"contract_signature",
	"area_trade_contract",
	"contract_offer_v06",
	"interaction_domain=contract",
	"target_player_contract_consent",
	"区域供需合约1",
	"区域供需合约2",
	"组合供需合约1",
	"自动撮合合约1",
	"环晶电池专供1",
	"双边对冲合约1",
	"惩罚性拒签条款1",
	"密约回溯",
	"密约回溯1",
	"密约回溯2",
	"intel_contract_trace",
]


static func validation_report(value: Variant) -> Dictionary:
	var hit := _first_hit(value, "$")
	return {
		"valid": hit.is_empty(),
		"reason_code": "" if hit.is_empty() else "retired_contract_payload_rejected",
		"path": str(hit.get("path", "")),
		"identifier": str(hit.get("identifier", "")),
	}


static func strip_migration_only_runtime_fields(value: Dictionary) -> Dictionary:
	var sanitized := value.duplicate(true)
	sanitized.erase("known_contract_parties")
	return sanitized


static func _first_hit(value: Variant, path: String) -> Dictionary:
	if (value is String or value is StringName) and str(value) in RETIRED_SCALAR_VALUES:
		return {"path": path, "identifier": str(value)}
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var child_path := "%s.%s" % [path, key]
			if key in RETIRED_KEYS:
				return {"path": child_path, "identifier": key}
			var nested := _first_hit((value as Dictionary)[key_variant], child_path)
			if not nested.is_empty():
				return nested
	elif value is Array:
		for index in range((value as Array).size()):
			var nested := _first_hit((value as Array)[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
	return {}
