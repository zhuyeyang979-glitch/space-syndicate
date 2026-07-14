extends SceneTree

const ROUTER_SCRIPT := preload("res://scripts/cards/v06/production/core_economic_card_effect_router_v06.gd")
const EFFECT_KINDS := [
	"install_commodity_rate",
	"build_upgrade_or_repair_facility",
	"global_order_budget",
	"global_supply_spawn",
]

var _checks := 0
var _failures: Array[String] = []


class RoutedHandler:
	extends RefCounted

	var effect_kind := ""
	var prepare_calls: Array[Dictionary] = []
	var commit_calls: Array[Dictionary] = []
	var abort_calls: Array[Dictionary] = []
	var rollback_calls: Array[Dictionary] = []
	var finalize_calls: Array[Dictionary] = []


	func _init(value: String) -> void:
		effect_kind = value


	func prepare_effect(intent: Dictionary) -> Dictionary:
		prepare_calls.append(intent.duplicate(true))
		var prepared := intent.duplicate(true)
		prepared["prepared"] = true
		prepared["committed"] = false
		prepared["owner_effect_kind"] = effect_kind
		return prepared


	func commit_effect(prepared: Dictionary) -> Dictionary:
		commit_calls.append(prepared.duplicate(true))
		var receipt := prepared.duplicate(true)
		receipt["prepared"] = false
		receipt["committed"] = true
		receipt["owner_effect_kind"] = effect_kind
		return receipt


	func abort_prepared_effect(prepared: Dictionary) -> void:
		abort_calls.append(prepared.duplicate(true))


	func rollback_effect(receipt: Dictionary) -> Dictionary:
		rollback_calls.append(receipt.duplicate(true))
		return {
			"rolled_back": true,
			"committed": false,
			"transaction_id": str(receipt.get("transaction_id", "")),
			"owner_effect_kind": effect_kind,
		}


	func finalize_effect(receipt: Dictionary) -> Dictionary:
		finalize_calls.append(receipt.duplicate(true))
		return {
			"finalized": true,
			"reason_code": "owner_finalized",
			"transaction_id": str(receipt.get("transaction_id", "")),
			"owner_effect_kind": effect_kind,
		}


class HandlerWithoutFinalize:
	extends RefCounted

	var commit_calls := 0
	var rollback_calls := 0


	func prepare_effect(intent: Dictionary) -> Dictionary:
		var prepared := intent.duplicate(true)
		prepared["prepared"] = true
		prepared["committed"] = false
		return prepared


	func commit_effect(prepared: Dictionary) -> Dictionary:
		commit_calls += 1
		var receipt := prepared.duplicate(true)
		receipt["prepared"] = false
		receipt["committed"] = true
		return receipt


	func rollback_effect(receipt: Dictionary) -> Dictionary:
		rollback_calls += 1
		return {
			"rolled_back": true,
			"committed": false,
			"transaction_id": str(receipt.get("transaction_id", "")),
		}


class HandlerWithoutRollback:
	extends RefCounted

	var commit_calls := 0


	func prepare_effect(intent: Dictionary) -> Dictionary:
		var prepared := intent.duplicate(true)
		prepared["prepared"] = true
		prepared["committed"] = false
		return prepared


	func commit_effect(prepared: Dictionary) -> Dictionary:
		commit_calls += 1
		var receipt := prepared.duplicate(true)
		receipt["prepared"] = false
		receipt["committed"] = true
		return receipt


class InvalidHandler:
	extends RefCounted


	func commit_effect(prepared: Dictionary) -> Dictionary:
		return prepared.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_all_four_effect_kinds_route_and_finalize()
	_verify_missing_owner_fails_closed()
	_verify_abort_forwards_and_releases_association()
	_verify_rollback_forwards_and_releases_association()
	_verify_optional_finalize_releases_association()
	_verify_missing_rollback_fails_closed_and_releases_association()
	_finish()


func _verify_all_four_effect_kinds_route_and_finalize() -> void:
	var router = ROUTER_SCRIPT.new()
	var handlers := {}
	for effect_kind_variant in EFFECT_KINDS:
		var effect_kind := str(effect_kind_variant)
		handlers[effect_kind] = RoutedHandler.new(effect_kind)
	var configured: Dictionary = router.configure(handlers)
	_expect(bool(configured.get("configured", false)), "router configures with the four production effect owners")
	_expect(router.configured_effect_kinds() == _sorted_effect_kinds(), "router reports all four effect kinds deterministically")

	for index in range(EFFECT_KINDS.size()):
		var effect_kind := str(EFFECT_KINDS[index])
		var transaction_id := "tx-router-route-%d" % index
		var handler := handlers[effect_kind] as RoutedHandler
		var prepared: Dictionary = router.prepare_effect(_intent(transaction_id, effect_kind))
		_expect(bool(prepared.get("prepared", false)), "%s prepare is routed" % effect_kind)
		_expect(handler.prepare_calls.size() == 1, "%s reaches only its prepare owner" % effect_kind)
		var receipt: Dictionary = router.commit_effect(prepared)
		_expect(bool(receipt.get("committed", false)), "%s commit is routed" % effect_kind)
		_expect(handler.commit_calls.size() == 1, "%s reaches only its commit owner" % effect_kind)
		_expect(str(receipt.get("owner_effect_kind", "")) == effect_kind, "%s cannot cross-route to another owner" % effect_kind)
		_expect(int(router.debug_snapshot().get("pending_transaction_count", -1)) == 1, "%s keeps one association until state finalization" % effect_kind)
		var finalized: Dictionary = _finalize_router_effect(router, receipt)
		_expect(bool(finalized.get("finalized", false)) and bool(finalized.get("router_finalized", false)), "%s supports explicit successful finalization" % effect_kind)
		_expect(handler.finalize_calls.size() == 1, "%s finalize is forwarded once" % effect_kind)
		var replay: Dictionary = _finalize_router_effect(router, receipt)
		_expect(bool(replay.get("finalized", false)) and bool(replay.get("idempotent_replay", false)), "%s repeated finalize replays the recorded result" % effect_kind)
		_expect(handler.finalize_calls.size() == 1, "%s repeated finalize is idempotent" % effect_kind)
		_expect(_association_is_released(router, transaction_id), "%s finalization releases its transaction association" % effect_kind)
		var closed_rollback: Dictionary = router.rollback_effect(receipt)
		_expect(not bool(closed_rollback.get("rolled_back", true)) and str(closed_rollback.get("reason_code", "")) == "effect_rollback_closed", "%s finalization closes rollback even when the receipt still names its effect kind" % effect_kind)


func _verify_missing_owner_fails_closed() -> void:
	var router = ROUTER_SCRIPT.new()
	var configured: Dictionary = router.configure({
		"install_commodity_rate": RoutedHandler.new("install_commodity_rate"),
		"global_supply_spawn": InvalidHandler.new(),
	})
	_expect(bool(configured.get("configured", false)), "router can configure a safe subset of owners")
	_expect(not router.configured_effect_kinds().has("global_supply_spawn"), "handler missing prepare is excluded")
	var prepare_failure: Dictionary = router.prepare_effect(_intent("tx-router-missing", "global_order_budget"))
	_expect(not bool(prepare_failure.get("prepared", true)), "missing prepare owner fails closed")
	_expect(str(prepare_failure.get("reason_code", "")) == "effect_owner_unavailable", "missing prepare owner has a stable reason")
	var commit_failure: Dictionary = router.commit_effect({"transaction_id": "tx-router-unknown"})
	_expect(not bool(commit_failure.get("committed", true)), "unknown transaction cannot commit")
	_expect(str(commit_failure.get("reason_code", "")) == "effect_owner_unavailable", "unknown commit has a stable fail-closed reason")
	var finalize_failure: Dictionary = router.finalize_effect({"transaction_id": "tx-router-unknown", "effect_kind": "install_commodity_rate"})
	_expect(not bool(finalize_failure.get("finalized", true)) and str(finalize_failure.get("reason_code", "")) == "effect_finalize_transaction_missing", "unknown transaction finalize never fabricates success")


func _verify_abort_forwards_and_releases_association() -> void:
	var handler := RoutedHandler.new("install_commodity_rate")
	var router = ROUTER_SCRIPT.new()
	router.configure({"install_commodity_rate": handler})
	var transaction_id := "tx-router-abort"
	var prepared: Dictionary = router.prepare_effect(_intent(transaction_id, "install_commodity_rate"))
	prepared.erase("effect_kind")
	router.abort_prepared_effect(prepared)
	_expect(handler.abort_calls.size() == 1, "abort is routed by the prepared transaction association")
	_expect(_association_is_released(router, transaction_id), "abort releases the prepared transaction association")
	router.abort_prepared_effect(prepared)
	_expect(handler.abort_calls.size() == 1, "repeated abort does not reach an owner after release")


func _verify_rollback_forwards_and_releases_association() -> void:
	var handler := RoutedHandler.new("build_upgrade_or_repair_facility")
	var router = ROUTER_SCRIPT.new()
	router.configure({"build_upgrade_or_repair_facility": handler})
	var transaction_id := "tx-router-rollback"
	var prepared: Dictionary = router.prepare_effect(_intent(transaction_id, "build_upgrade_or_repair_facility"))
	var receipt: Dictionary = router.commit_effect(prepared)
	var mismatched_receipt := receipt.duplicate(true)
	mismatched_receipt["effect_kind"] = "global_supply_spawn"
	var mismatch: Dictionary = router.rollback_effect(mismatched_receipt)
	_expect(not bool(mismatch.get("rolled_back", true)) and str(mismatch.get("reason_code", "")) == "effect_rollback_binding_mismatch", "rollback uses the saved transaction association instead of a receipt-selected owner")
	_expect(handler.rollback_calls.is_empty(), "rollback binding mismatch reaches no owner")
	receipt.erase("effect_kind")
	var rolled_back: Dictionary = router.rollback_effect(receipt)
	_expect(bool(rolled_back.get("rolled_back", false)), "rollback is routed by the committed transaction association")
	_expect(handler.rollback_calls.size() == 1, "rollback reaches its owner exactly once")
	_expect(_association_is_released(router, transaction_id), "rollback releases the committed transaction association")
	var replay: Dictionary = router.rollback_effect(receipt)
	_expect(not bool(replay.get("rolled_back", true)), "rollback replay fails closed after association release")
	_expect(handler.rollback_calls.size() == 1, "rollback replay does not reach the owner twice")


func _verify_optional_finalize_releases_association() -> void:
	var handler := HandlerWithoutFinalize.new()
	var router = ROUTER_SCRIPT.new()
	router.configure({"global_order_budget": handler})
	var transaction_id := "tx-router-optional-finalize"
	var prepared: Dictionary = router.prepare_effect(_intent(transaction_id, "global_order_budget"))
	var receipt: Dictionary = router.commit_effect(prepared)
	_expect(bool(receipt.get("committed", false)), "owner without finalize can still commit")
	var finalized: Dictionary = _finalize_router_effect(router, receipt)
	_expect(not bool(finalized.get("router_finalized", true)) and not bool(finalized.get("owner_finalize_supported", true)), "router records that the owner has no finalize hook")
	_expect(not bool(finalized.get("finalized", true)) and str(finalized.get("reason_code", "")) == "effect_owner_finalize_unavailable", "missing owner finalize is never reported as completed")
	_expect(int(router.debug_snapshot().get("pending_transaction_count", 0)) == 1, "missing owner finalize keeps the transaction association for diagnosis or retry")
	_expect(handler.commit_calls == 1, "optional finalize never replays commit")


func _verify_missing_rollback_fails_closed_and_releases_association() -> void:
	var handler := HandlerWithoutRollback.new()
	var router = ROUTER_SCRIPT.new()
	router.configure({"global_supply_spawn": handler})
	var transaction_id := "tx-router-no-rollback"
	var prepared: Dictionary = router.prepare_effect(_intent(transaction_id, "global_supply_spawn"))
	var receipt: Dictionary = router.commit_effect(prepared)
	receipt.erase("effect_kind")
	var failure: Dictionary = router.rollback_effect(receipt)
	_expect(not bool(failure.get("rolled_back", true)), "owner without rollback fails closed")
	_expect(str(failure.get("reason_code", "")) == "effect_rollback_unavailable", "missing rollback has a stable reason")
	_expect(handler.commit_calls == 1, "missing rollback never replays the committed effect")
	_expect(int(router.debug_snapshot().get("pending_transaction_count", 0)) == 1, "failed rollback keeps its transaction association for diagnosis or retry")


func _intent(transaction_id: String, effect_kind: String) -> Dictionary:
	return {
		"transaction_id": transaction_id,
		"actor_id": "syndicate-a",
		"card_id": "card-router-test",
		"card_instance_id": "instance-router-test",
		"effect_kind": effect_kind,
		"target_hash": "target-hash",
		"payload_hash": "payload-hash",
		"intent_hash": "intent-hash",
	}


func _finalize_router_effect(router: Object, receipt: Dictionary) -> Dictionary:
	if not router.has_method("finalize_effect"):
		_expect(false, "router exposes finalize_effect for successful state commits")
		return {}
	var value_variant: Variant = router.call("finalize_effect", receipt.duplicate(true))
	if not (value_variant is Dictionary):
		_expect(false, "router finalize returns a structured result")
		return {}
	return (value_variant as Dictionary).duplicate(true)


func _association_is_released(router: Object, transaction_id: String) -> bool:
	var probe: Dictionary = router.call("commit_effect", {"transaction_id": transaction_id})
	return (
		not bool(probe.get("committed", true))
		and str(probe.get("reason_code", "")) == "effect_owner_unavailable"
	)


func _sorted_effect_kinds() -> Array[String]:
	var result: Array[String] = []
	for effect_kind_variant in EFFECT_KINDS:
		result.append(str(effect_kind_variant))
	result.sort()
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CORE_ECONOMIC_CARD_EFFECT_ROUTER_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("CORE_ECONOMIC_CARD_EFFECT_ROUTER_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(1)
