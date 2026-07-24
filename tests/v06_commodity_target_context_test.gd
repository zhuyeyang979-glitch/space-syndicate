extends SceneTree

const CORE_ADAPTER := preload("res://scripts/cards/v06/production/core_economic_card_runtime_adapter_v06.gd")
const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"

var _checks := 0
var _failures: Array[String] = []


class CardSource:
	extends RefCounted
	var card: Dictionary = {}

	func player_snapshot(_actor_id: String) -> Dictionary:
		return {"inventory": {"slots": [card.duplicate(true)]}}

	func play_core_card(_actor_id: String, _slot_index: int, _target: Dictionary, _router: Object, _expected_revision: int, _transaction_id: String) -> Dictionary:
		return {"committed": false}


class FlowOwner:
	extends RefCounted

	func install_commodity(_request: Dictionary) -> Dictionary:
		return {"committed": false}

	func card_effect_candidates_snapshot() -> Dictionary:
		return {"valid": true, "reason_code": "ready", "revision": 1, "candidates": []}

	func prepare_card_effect_batch(plan: Dictionary) -> Dictionary:
		return _batch_receipt(plan, {"prepared": true})

	func commit_card_effect_batch(plan: Dictionary) -> Dictionary:
		return _batch_receipt(plan, {"committed": true})

	func rollback_card_effect_batch(plan: Dictionary) -> Dictionary:
		return _batch_receipt(plan, {"rolled_back": true})

	func finalize_card_effect_batch(plan: Dictionary) -> Dictionary:
		return _batch_receipt(plan, {"finalized": true})

	func _batch_receipt(source: Dictionary, detail: Dictionary) -> Dictionary:
		var result := {
			"transaction_id": str(source.get("transaction_id", "")),
			"intent_hash": str(source.get("intent_hash", "")),
			"plan_hash": str(source.get("plan_hash", "")),
		}
		result.merge(detail, true)
		return result


class InfrastructureOwner:
	extends RefCounted
	var facilities: Array = []

	func facilities_snapshot(_include_tombstones := false) -> Array:
		return facilities.duplicate(true)

	func region_snapshot(region_id: String) -> Dictionary:
		return {"region_id": region_id, "revision": 7, "lifecycle_state": "active"}

	func slot_id(region_id: String, facility_type: String, industry_id := "") -> String:
		return "%s::%s.%s" % [region_id, facility_type, industry_id]

	func apply_facility_action(_request: Dictionary) -> Dictionary:
		return {"committed": false}

	func rollback_facility_action(_receipt: Dictionary) -> Dictionary:
		return {"rolled_back": false}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(CATALOG_PATH)
	_expect(catalog != null and bool(catalog.call("reload").get("valid", false)), "active v0.6 catalog loads")
	if catalog == null:
		_finish()
		return
	var card_variant: Variant = catalog.call("card_snapshot", "commodity.star_whale_canning.rank_1")
	var commodity_card: Dictionary = (card_variant as Dictionary).duplicate(true) if card_variant is Dictionary else {}
	commodity_card["runtime_instance_id"] = "commodity-target-context-test-instance"
	var card_source := CardSource.new()
	card_source.card = commodity_card.duplicate(true)
	var flow := FlowOwner.new()
	var infrastructure := InfrastructureOwner.new()
	infrastructure.facilities = [_facility("market.shipping.one", "region.market", "market", "shipping")]
	var adapter := CORE_ADAPTER.new()
	root.add_child(adapter)
	var configured := adapter.configure(card_source, flow, infrastructure, {"player.0": 0})
	_expect(bool(configured.get("configured", false)), "core economic adapter configures against the focused owner contracts")
	_expect(adapter.has_method("commodity_target_context"), "core economic adapter exposes the commodity target composer")

	var before := JSON.stringify(infrastructure.facilities)
	var target := adapter.commodity_target_context(
		"player.0",
		0,
		"commodity.star_whale_canning.rank_1",
		"region.market",
		12.5
	)
	var context: Dictionary = target.get("target_context", {}) if target.get("target_context", {}) is Dictionary else {}
	_expect(bool(target.get("ready", false)), "one compatible facility in the frozen region yields a ready target")
	_expect(str(context.get("facility_id", "")) == "market.shipping.one", "target binds the exact stable facility ID")
	_expect(str(context.get("region_id", "")) == "region.market" and str(context.get("industry_id", "")) == "shipping", "target retains region and industry identity")
	_expect(str(context.get("direction", "")) == "demand", "market target resolves to demand direction")
	_expect(str(context.get("target_kind", "")) == "same_industry_factory_or_market" and is_equal_approx(float(context.get("game_time", 0.0)), 12.5), "target preserves the catalog target kind and capture time")
	_expect(JSON.stringify(infrastructure.facilities) == before, "target query does not mutate infrastructure")
	_expect(_is_pure_data(context), "target context is detached pure data")
	var coordinator := GameRuntimeCoordinator.new()
	var target_hash := str(coordinator.call("_v06_stable_hash", context))
	var effect_receipt := {
		"target_hash": target_hash,
		"owner_receipt": {
			"installation": {
				"facility_id": "market.shipping.one",
				"region_id": "region.market",
				"commodity_id": "星鲸罐头",
				"color": "shipping",
				"direction": "demand",
				"installed_at": 12.5,
			},
		},
	}
	var replay := coordinator.call(
		"_v06_runtime_card_replay_target_context",
		commodity_card,
		{"region_id": "region.market", "game_time": 99.0},
		effect_receipt,
		0
	) as Dictionary
	_expect(bool(replay.get("ready", false)) and JSON.stringify(replay.get("target_context", {})) == JSON.stringify(context), "terminal replay reconstructs the exact committed commodity target")
	var tampered_receipt := effect_receipt.duplicate(true)
	((tampered_receipt.get("owner_receipt", {}) as Dictionary).get("installation", {}) as Dictionary)["color"] = "commerce"
	var tampered := coordinator.call(
		"_v06_runtime_card_replay_target_context",
		commodity_card,
		{"region_id": "region.market", "game_time": 99.0},
		tampered_receipt,
		0
	) as Dictionary
	_expect(not bool(tampered.get("ready", true)) and str(tampered.get("reason_code", "")) == "v06_card_play_terminal_invalid", "tampered installation lineage fails closed during replay")
	coordinator.free()

	infrastructure.facilities = []
	var missing := adapter.commodity_target_context("player.0", 0, "commodity.star_whale_canning.rank_1", "region.market", 13.0)
	_expect(not bool(missing.get("ready", true)) and str(missing.get("reason_code", "")) == "commodity_target_facility_missing", "zero compatible facilities fail closed")

	infrastructure.facilities = [
		_facility("factory.shipping.one", "region.market", "factory", "shipping"),
		_facility("market.shipping.one", "region.market", "market", "shipping"),
	]
	var ambiguous := adapter.commodity_target_context("player.0", 0, "commodity.star_whale_canning.rank_1", "region.market", 14.0)
	_expect(not bool(ambiguous.get("ready", true)) and str(ambiguous.get("reason_code", "")) == "commodity_target_facility_ambiguous" and int(ambiguous.get("candidate_count", 0)) == 2, "multiple compatible facilities fail closed without silently choosing one")

	var changed := adapter.commodity_target_context("player.0", 0, "commodity.other", "region.market", 15.0)
	_expect(not bool(changed.get("ready", true)) and str(changed.get("reason_code", "")) == "commodity_card_binding_changed", "card identity changes fail closed")

	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_expect(coordinator_source.contains('if effect_kind == "install_commodity_rate":') and coordinator_source.contains('"commodity_target_context"'), "Coordinator capture routes commodity cards to the typed target composer")
	_expect(coordinator_source.contains('owner_receipt.get("installation", {})') and coordinator_source.contains('str(installation.get("facility_id", ""))'), "Coordinator terminal replay reconstructs the committed commodity facility binding")
	adapter.queue_free()
	_finish()


func _facility(facility_id: String, region_id: String, facility_type: String, industry_id: String) -> Dictionary:
	return {
		"facility_id": facility_id,
		"region_id": region_id,
		"facility_type": facility_type,
		"industry_id": industry_id,
		"owner_kind": "player",
		"owner_player_index": 0,
		"active": true,
	}


func _is_pure_data(value: Variant) -> bool:
	if value is Object or value is Callable:
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not _is_pure_data(key_variant) or not _is_pure_data((value as Dictionary).get(key_variant)):
				return false
	if value is Array:
		for item_variant in value as Array:
			if not _is_pure_data(item_variant):
				return false
	return true


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("V06 COMMODITY TARGET CONTEXT: %s" % label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V06_COMMODITY_TARGET_CONTEXT_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
