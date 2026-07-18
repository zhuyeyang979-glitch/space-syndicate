extends RefCounted
class_name RoleResourceCashSettlementRuntimeService

const CURRENCY_SCALE := 100
const LEDGER_CATEGORY := "role_resource_cash"
const HIGH_VOLATILITY_LEDGER_CATEGORY := "role_high_volatility_sale"


func plans_for_sale_receipt(player: Dictionary, player_index: int, sale_receipt: Dictionary) -> Array[Dictionary]:
	var plans: Array[Dictionary] = []
	var resource_plan := plan_for_sale_receipt(player, player_index, sale_receipt)
	if bool(resource_plan.get("eligible", false)):
		plans.append(resource_plan)
	var volatility_plan := _high_volatility_plan(player, player_index, sale_receipt)
	if bool(volatility_plan.get("eligible", false)):
		plans.append(volatility_plan)
	return plans


func plan_for_sale_receipt(player: Dictionary, player_index: int, sale_receipt: Dictionary) -> Dictionary:
	var source_receipt_id := str(sale_receipt.get("receipt_id", "")).strip_edges()
	if source_receipt_id.is_empty() or int(sale_receipt.get("commodity_owner", -1)) != player_index:
		return {"eligible": false, "reason_code": "not_owned_sale_receipt"}
	var role_variant: Variant = player.get("role_card", {})
	var role: Dictionary = role_variant if role_variant is Dictionary else {}
	var product_id := str(role.get("resource_cash_product", "")).strip_edges()
	var amount := maxi(0, int(role.get("resource_cash_amount", 0)))
	if product_id.is_empty() or amount <= 0 or str(sale_receipt.get("commodity_id", "")) != product_id:
		return {"eligible": false, "reason_code": "role_product_not_matched"}
	var transaction_id := "%s:role-resource-cash:%d" % [source_receipt_id, player_index]
	if _ledger_contains_transaction(player, transaction_id):
		return {
			"eligible": true,
			"duplicate": true,
			"reason_code": "role_income_already_settled",
			"transaction_id": transaction_id,
		}
	var amount_cents := amount * CURRENCY_SCALE
	return {
		"eligible": true,
		"duplicate": false,
		"reason_code": "role_income_planned",
		"cash_delta_cents": amount_cents,
		"counter_delta": amount,
		"ledger_receipt": {
			"transaction_id": transaction_id,
			"category": LEDGER_CATEGORY,
			"ledger_delta_cents": amount_cents,
			"source_receipt_id": source_receipt_id,
			"commodity_id": product_id,
			"market_region_id": str(sale_receipt.get("market_region_id", "")),
		},
	}


func debug_snapshot() -> Dictionary:
	return {
		"service_authoritative": true,
		"runtime_owner": "RoleResourceCashSettlementRuntimeService",
		"triggers": ["owned_matching_commodity_sale_receipt", "first_high_volatility_sale_per_market_cycle"],
		"ledger_categories": [LEDGER_CATEGORY, HIGH_VOLATILITY_LEDGER_CATEGORY],
		"public_receipt_fields_added": [],
		"exact_once_keys": ["source_receipt_id_and_player_index", "market_cycle_revision_and_player_index"],
	}


func _high_volatility_plan(player: Dictionary, player_index: int, sale_receipt: Dictionary) -> Dictionary:
	var source_receipt_id := str(sale_receipt.get("receipt_id", "")).strip_edges()
	if source_receipt_id.is_empty() or int(sale_receipt.get("commodity_owner", -1)) != player_index:
		return {"eligible": false, "reason_code": "not_owned_sale_receipt"}
	var role_variant: Variant = player.get("role_card", {})
	var role: Dictionary = role_variant if role_variant is Dictionary else {}
	var threshold := maxi(0, int(role.get("high_volatility_sale_threshold", 0)))
	var bonus := maxi(0, int(role.get("high_volatility_first_sale_bonus", 0)))
	var once_per_cycle := bool(role.get("high_volatility_bonus_once_per_market_cycle", false))
	var public_volatility := maxi(0, int(sale_receipt.get("public_volatility", -1)))
	var market_cycle_revision := int(sale_receipt.get("market_cycle_revision", -1))
	if threshold <= 0 or bonus <= 0 or not once_per_cycle:
		return {"eligible": false, "reason_code": "role_high_volatility_bonus_unavailable"}
	if market_cycle_revision < 0 or public_volatility < threshold:
		return {"eligible": false, "reason_code": "public_volatility_below_threshold"}
	var transaction_id := "role-high-volatility:%d:%d" % [player_index, market_cycle_revision]
	if _ledger_contains_transaction(player, transaction_id):
		return {
			"eligible": true,
			"duplicate": true,
			"reason_code": "market_cycle_bonus_already_settled",
			"transaction_id": transaction_id,
		}
	var amount_cents := bonus * CURRENCY_SCALE
	return {
		"eligible": true,
		"duplicate": false,
		"reason_code": "high_volatility_bonus_planned",
		"cash_delta_cents": amount_cents,
		"counter_delta": bonus,
		"ledger_receipt": {
			"transaction_id": transaction_id,
			"category": HIGH_VOLATILITY_LEDGER_CATEGORY,
			"ledger_delta_cents": amount_cents,
			"source_receipt_id": source_receipt_id,
			"commodity_id": str(sale_receipt.get("commodity_id", "")),
			"market_region_id": str(sale_receipt.get("market_region_id", "")),
			"market_cycle_revision": market_cycle_revision,
			"public_volatility": public_volatility,
		},
	}


func _ledger_contains_transaction(player: Dictionary, transaction_id: String) -> bool:
	var ledger_variant: Variant = player.get("v06_transaction_ledger", [])
	if not (ledger_variant is Array):
		return false
	for row_variant in ledger_variant:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("transaction_id", "")) == transaction_id:
			return true
	return false
