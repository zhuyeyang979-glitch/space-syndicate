@tool
extends Node
class_name EconomyCashflowRuntimeController

const RETIRED_BY := "SS06-02B"
const REPLACEMENT_OWNER := "CommodityFlowRuntimeController"


func debug_snapshot() -> Dictionary:
	return {
		"controller_ready": false,
		"controller_authoritative": false,
		"retired": true,
		"retired_by": RETIRED_BY,
		"replacement_owner": REPLACEMENT_OWNER,
		"owns_clock": false,
		"owns_payouts": false,
		"owns_cash_mutation": false,
		"legacy_fallback_available": false,
	}
