extends RefCounted
class_name RoleResourceCashSettlementRuntimeService

const CURRENCY_SCALE := 100
const LEDGER_CATEGORY := "role_resource_cash"


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
		"trigger": "owned_matching_commodity_sale_receipt",
		"ledger_category": LEDGER_CATEGORY,
		"public_receipt_fields_added": [],
		"exact_once_key": "source_receipt_id_and_player_index",
	}


func _ledger_contains_transaction(player: Dictionary, transaction_id: String) -> bool:
	var ledger_variant: Variant = player.get("v06_transaction_ledger", [])
	if not (ledger_variant is Array):
		return false
	for row_variant in ledger_variant:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("transaction_id", "")) == transaction_id:
			return true
	return false
