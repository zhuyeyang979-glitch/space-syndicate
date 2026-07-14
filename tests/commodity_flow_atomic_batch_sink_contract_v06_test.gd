extends SceneTree

const SINK_SCRIPT := preload("res://scripts/cards/v06/production/commodity_flow_atomic_batch_sink_v06.gd")

var _checks := 0
var _failures: Array[String] = []


class FakeCommodityFlowOwner:
	extends RefCounted
	var prepare_calls := 0
	var commit_calls := 0
	var rollback_calls := 0

	func prepare_card_effect_batch(plan: Dictionary) -> Dictionary:
		prepare_calls += 1
		var result := _binding(plan)
		result["prepared"] = true
		result["prepared_token"] = "token"
		return result

	func commit_card_effect_batch(prepared: Dictionary) -> Dictionary:
		commit_calls += 1
		var result := _binding(prepared)
		result["committed"] = true
		result["duplicate"] = false
		return result

	func rollback_card_effect_batch(receipt: Dictionary) -> Dictionary:
		rollback_calls += 1
		return {"transaction_id": str(receipt.get("transaction_id", "")), "rolled_back": true, "committed": false}

	func _binding(source: Dictionary) -> Dictionary:
		return {
			"transaction_id": str(source.get("transaction_id", "")),
			"intent_hash": str(source.get("intent_hash", "")),
			"plan_hash": str(source.get("plan_hash", "")),
		}


func _init() -> void:
	var sink = SINK_SCRIPT.new()
	var request := {"transaction_id": "tx-contract", "intent_hash": "intent", "plan_hash": "plan"}
	var unavailable: Dictionary = sink.prepare_batch(request)
	_expect(not bool(unavailable.get("prepared", true)) and str(unavailable.get("reason_code", "")) == "commodity_flow_owner_unavailable", "sink fails closed before owner configuration")
	var incomplete_owner := RefCounted.new()
	_expect(not bool(sink.configure(incomplete_owner).get("configured", true)), "sink rejects owners without all three authoritative batch methods")
	var owner := FakeCommodityFlowOwner.new()
	_expect(bool(sink.configure(owner).get("configured", false)), "sink accepts the complete CommodityFlow authoritative API")
	var prepared: Dictionary = sink.prepare_batch(request)
	var committed: Dictionary = sink.commit_batch(prepared)
	var rolled_back: Dictionary = sink.rollback_batch(committed)
	_expect(bool(prepared.get("prepared", false)) and owner.prepare_calls == 1, "prepare delegates exactly once")
	_expect(bool(committed.get("committed", false)) and owner.commit_calls == 1, "commit delegates exactly once")
	_expect(bool(rolled_back.get("rolled_back", false)) and owner.rollback_calls == 1, "rollback delegates exactly once")
	var debug: Dictionary = sink.debug_snapshot()
	_expect(not bool(debug.get("owns_commodity_state", true)) and not bool(debug.get("owns_sale_receipts", true)) and not bool(debug.get("owns_cash_gdp_rent_or_assets", true)), "sink explicitly owns no economic state or receipts")
	if _failures.is_empty():
		print("COMMODITY_FLOW_ATOMIC_BATCH_SINK_CONTRACT_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("COMMODITY_FLOW_ATOMIC_BATCH_SINK_CONTRACT_V06_TEST|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
