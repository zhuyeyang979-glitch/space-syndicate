@tool
extends Node
class_name GdpFormulaRuntimeController

const RETIRED_BY := "SS06-02B"
const REPLACEMENT_OWNER := "CommodityFlowRuntimeController.sale_receipts"


func debug_snapshot() -> Dictionary:
	return {
		"controller_ready": false,
		"controller_authoritative": false,
		"retired": true,
		"retired_by": RETIRED_BY,
		"replacement_owner": REPLACEMENT_OWNER,
		"owns_gdp_formula": false,
		"owns_project_attribution": false,
		"legacy_fallback_available": false,
	}
