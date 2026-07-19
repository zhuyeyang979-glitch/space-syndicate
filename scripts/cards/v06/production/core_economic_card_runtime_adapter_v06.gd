@tool
extends Node
class_name CoreEconomicCardRuntimeAdapterV06

const RULESET_ID := "v0.6"
const FACILITY_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/effects/facility_card_effect_adapter_v06.gd")
const COMMODITY_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/effects/commodity_card_effect_adapter_v06.gd")
const GLOBAL_OWNER_SCRIPT := preload("res://scripts/cards/v06/effects/global_supply_demand_runtime_service_v06.gd")
const GLOBAL_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/effects/global_supply_demand_card_effect_adapter_v06.gd")
const ROUTER_SCRIPT := preload("res://scripts/cards/v06/production/core_economic_card_effect_router_v06.gd")
const BATCH_SINK_SCRIPT := preload("res://scripts/cards/v06/production/commodity_flow_atomic_batch_sink_v06.gd")
const CANDIDATE_PORT_SCRIPT := preload("res://scripts/cards/v06/production/commodity_flow_candidate_snapshot_port_v06.gd")
const ORGANIZATION_PORT_SCRIPT := preload("res://scripts/cards/v06/production/organization_production_port_v06.gd")
const ORGANIZATION_EFFECT_KIND := "install_organization_upgrade"

var _card_source_owner: Object
var _commodity_flow_owner: Object
var _infrastructure_owner: Object
var _region_product_facts_port: Object
var _facility_adapter: Object
var _commodity_adapter: Object
var _global_owner: Object
var _global_adapter: Object
var _effect_router: Object
var _batch_sink: Object
var _candidate_port: Object
var _organization_owner: Object
var _organization_consumers: Dictionary = {}
var _organization_port: Object
var _actor_player_indices: Dictionary = {}
var _configured := false
var _last_reason_code := "not_configured"


func configure(
	card_source_owner: Object,
	commodity_flow_owner: Object,
	infrastructure_owner: Object,
	actor_player_indices: Dictionary,
	region_product_facts_port: Object = null,
	organization_owner: Object = null,
	organization_consumers: Dictionary = {}
) -> Dictionary:
	_clear_bindings()
	_card_source_owner = card_source_owner
	_commodity_flow_owner = commodity_flow_owner
	_infrastructure_owner = infrastructure_owner
	_region_product_facts_port = region_product_facts_port
	_organization_owner = organization_owner
	_organization_consumers = organization_consumers.duplicate()
	_actor_player_indices = actor_player_indices.duplicate(true)
	if not _source_api_ready():
		return _configuration_failure("card_source_api_missing")

	_batch_sink = BATCH_SINK_SCRIPT.new()
	var sink_result: Dictionary = _batch_sink.call("configure", _commodity_flow_owner)
	if not bool(sink_result.get("configured", false)):
		return _configuration_failure(str(sink_result.get("reason_code", "commodity_flow_batch_api_missing")))

	_candidate_port = CANDIDATE_PORT_SCRIPT.new()
	var candidate_result: Dictionary = _candidate_port.call("configure", _commodity_flow_owner)
	if not bool(candidate_result.get("configured", false)):
		return _configuration_failure(str(candidate_result.get("reason_code", "candidate_snapshot_api_missing")))

	_global_owner = GLOBAL_OWNER_SCRIPT.new()
	var sink_binding: Dictionary = _global_owner.call("set_batch_sink", _batch_sink)
	if not bool(sink_binding.get("configured", false)):
		return _configuration_failure(str(sink_binding.get("reason_code", "global_batch_sink_unavailable")))

	_facility_adapter = FACILITY_ADAPTER_SCRIPT.new()
	var facility_result: Dictionary = _facility_adapter.call(
		"configure",
		_infrastructure_owner,
		actor_player_indices,
		_commodity_flow_owner,
		_region_product_facts_port
	)
	if not bool(facility_result.get("configured", false)):
		return _configuration_failure("facility_effect_owner_unavailable")
	if _region_product_facts_port != null and not bool(facility_result.get("product_installation_ready", false)):
		return _configuration_failure("facility_product_installation_unavailable")

	_commodity_adapter = COMMODITY_ADAPTER_SCRIPT.new()
	var commodity_result: Dictionary = _commodity_adapter.call(
		"configure",
		_commodity_flow_owner,
		_infrastructure_owner,
		actor_player_indices
	)
	if not bool(commodity_result.get("configured", false)):
		return _configuration_failure("commodity_effect_owner_unavailable")

	_global_adapter = GLOBAL_ADAPTER_SCRIPT.new()
	var global_result: Dictionary = _global_adapter.call("configure", _global_owner, actor_player_indices)
	if not bool(global_result.get("configured", false)):
		return _configuration_failure("global_supply_demand_owner_unavailable")

	var organization_result: Dictionary = {}
	if _organization_owner != null:
		_organization_port = ORGANIZATION_PORT_SCRIPT.new()
		var organization_variant: Variant = _organization_port.call("configure", _organization_owner, _organization_consumers)
		organization_result = organization_variant if organization_variant is Dictionary else {}
		if not bool(organization_result.get("configured", false)):
			return _configuration_failure("organization_owner_atomic_contract_missing")

	_effect_router = ROUTER_SCRIPT.new()
	var handlers := {
		"install_commodity_rate": _commodity_adapter,
		"build_upgrade_or_repair_facility": _facility_adapter,
		"global_order_budget": _global_adapter,
		"global_supply_spawn": _global_adapter,
	}
	if _organization_port != null:
		handlers[ORGANIZATION_EFFECT_KIND] = _organization_port
	var router_result: Dictionary = _effect_router.call("configure", handlers)
	var configured_kinds: Array = router_result.get("supported_effect_kinds", []) if router_result.get("supported_effect_kinds", []) is Array else []
	var expected_kind_count := 4 + (1 if _organization_port != null else 0)
	if not bool(router_result.get("configured", false)) or configured_kinds.size() != expected_kind_count:
		return _configuration_failure("core_effect_router_incomplete")

	_configured = true
	_last_reason_code = "configured"
	return {
		"configured": true,
		"reason_code": "configured",
		"ruleset_id": RULESET_ID,
		"effect_kinds": (_effect_router.call("configured_effect_kinds") as Array).duplicate(),
		"facility_product_installation_ready": bool(facility_result.get("product_installation_ready", false)),
		"organization_owner_ready": _organization_port != null,
		"organization_consumer_readiness": organization_consumer_readiness_snapshot(),
	}


func reset_state() -> void:
	var card_source_owner := _card_source_owner
	var commodity_flow_owner := _commodity_flow_owner
	var infrastructure_owner := _infrastructure_owner
	var region_product_facts_port := _region_product_facts_port
	var organization_owner := _organization_owner
	var organization_consumers := _organization_consumers.duplicate()
	var actor_player_indices := _actor_player_indices.duplicate(true)
	_clear_bindings()
	if card_source_owner != null and commodity_flow_owner != null and infrastructure_owner != null and not actor_player_indices.is_empty():
		configure(card_source_owner, commodity_flow_owner, infrastructure_owner, actor_player_indices, region_product_facts_port, organization_owner, organization_consumers)


func capture_new_session_binding_checkpoint() -> Dictionary:
	return {
		"schema_version": 1,
		"card_source_owner": _card_source_owner,
		"commodity_flow_owner": _commodity_flow_owner,
		"infrastructure_owner": _infrastructure_owner,
		"region_product_facts_port": _region_product_facts_port,
		"organization_owner": _organization_owner,
		"organization_consumers": _organization_consumers.duplicate(),
		"actor_player_indices": _actor_player_indices.duplicate(true),
		"configured": _configured,
	}


func restore_new_session_binding_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if int(checkpoint.get("schema_version", 0)) != 1:
		return {"restored": false, "reason_code": "core_economic_binding_checkpoint_invalid"}
	_clear_bindings()
	if not bool(checkpoint.get("configured", false)):
		return {"restored": true, "reason_code": "core_economic_binding_restored_unconfigured"}
	var restored := configure(
		checkpoint.get("card_source_owner") as Object,
		checkpoint.get("commodity_flow_owner") as Object,
		checkpoint.get("infrastructure_owner") as Object,
		(checkpoint.get("actor_player_indices", {}) as Dictionary).duplicate(true),
		checkpoint.get("region_product_facts_port") as Object,
		checkpoint.get("organization_owner") as Object,
		(checkpoint.get("organization_consumers", {}) as Dictionary).duplicate()
	)
	return {"restored": bool(restored.get("configured", false)), "reason_code": str(restored.get("reason_code", "core_economic_binding_restore_failed"))}


func _clear_bindings() -> void:
	_card_source_owner = null
	_commodity_flow_owner = null
	_infrastructure_owner = null
	_region_product_facts_port = null
	_facility_adapter = null
	_commodity_adapter = null
	_global_owner = null
	_global_adapter = null
	_effect_router = null
	_batch_sink = null
	_candidate_port = null
	_organization_owner = null
	_organization_consumers.clear()
	_organization_port = null
	_actor_player_indices.clear()
	_configured = false
	_last_reason_code = "not_configured"


func refresh_supply_demand_candidates() -> Dictionary:
	if not _configured or _candidate_port == null or _global_owner == null:
		return _failure("core_economic_runtime_unavailable")
	var value_variant: Variant = _candidate_port.call("refresh_planner", _global_owner)
	if not (value_variant is Dictionary):
		return _failure("candidate_refresh_invalid")
	var result: Dictionary = (value_variant as Dictionary).duplicate(true)
	_last_reason_code = str(result.get("reason_code", "candidate_refresh_invalid"))
	return result


func play_card(
	actor_id: String,
	slot_index: int,
	target_context: Dictionary,
	expected_player_revision: int,
	transaction_id: String
) -> Dictionary:
	if not _configured or not _source_api_ready() or _effect_router == null:
		return _failure("core_economic_runtime_unavailable")
	var effect_kind := _authoritative_slot_effect_kind(actor_id, slot_index)
	if effect_kind == ORGANIZATION_EFFECT_KIND and not bool(organization_consumer_readiness_snapshot().get("production_ready", false)):
		return _failure("organization_consumer_capabilities_incomplete")
	var value_variant: Variant = _card_source_owner.call(
		"play_core_card",
		actor_id,
		slot_index,
		target_context.duplicate(true),
		_effect_router,
		expected_player_revision,
		transaction_id
	)
	if not (value_variant is Dictionary):
		return _failure("core_card_play_invalid")
	var result: Dictionary = (value_variant as Dictionary).duplicate(true)
	_last_reason_code = str(result.get("reason_code", "committed" if bool(result.get("committed", false)) else "core_card_play_rejected"))
	return result


func debug_snapshot() -> Dictionary:
	var router_snapshot: Dictionary = _effect_router.call("debug_snapshot") if _effect_router != null and _effect_router.has_method("debug_snapshot") else {}
	var global_snapshot: Dictionary = _global_owner.call("debug_snapshot") if _global_owner != null and _global_owner.has_method("debug_snapshot") else {}
	return {
		"ruleset_id": RULESET_ID,
		"configured": _configured,
		"last_reason_code": _last_reason_code,
		"uses_shared_card_source_transaction_service": true,
		"owns_hand_state": false,
		"owns_cash_state": false,
		"owns_asset_state": false,
		"owns_commodity_or_facility_state": false,
		"uses_authoritative_region_product_facts": _region_product_facts_port != null,
		"router": router_snapshot,
		"global_supply_demand": global_snapshot,
		"organization_owner_ready": _organization_port != null,
		"organization_consumer_readiness": organization_consumer_readiness_snapshot(),
		"organization_public_snapshot": organization_public_snapshot(),
	}


func organization_consumer_readiness_snapshot() -> Dictionary:
	if _organization_port != null and _organization_port.has_method("organization_consumer_readiness_snapshot"):
		var value_variant: Variant = _organization_port.call("organization_consumer_readiness_snapshot")
		if value_variant is Dictionary:
			return (value_variant as Dictionary).duplicate(true)
	var consumers: Dictionary = {}
	var missing: Array[String] = []
	for domain in ["asset_recovery", "hand_limit", "card_window", "monster_binding", "military_command"]:
		consumers[domain] = {"ready": false}
		missing.append(domain)
	return {
		"available": false,
		"production_ready": false,
		"reason_code": "organization_consumer_capabilities_incomplete",
		"consumers": consumers,
		"missing_consumers": missing,
	}


func organization_checkpoint_status() -> Dictionary:
	if _organization_port != null and _organization_port.has_method("checkpoint_status"):
		var value_variant: Variant = _organization_port.call("checkpoint_status")
		if value_variant is Dictionary:
			return (value_variant as Dictionary).duplicate(true)
	return {"can_checkpoint": false, "reason_code": "organization_owner_checkpoint_unavailable"}


func organization_public_snapshot() -> Dictionary:
	if _organization_port != null and _organization_port.has_method("public_snapshot"):
		var value_variant: Variant = _organization_port.call("public_snapshot")
		if value_variant is Dictionary:
			return (value_variant as Dictionary).duplicate(true)
	return {"available": false, "ruleset_id": RULESET_ID, "effect_kind": ORGANIZATION_EFFECT_KIND}


func organization_public_receipt(receipt: Dictionary) -> Dictionary:
	if _organization_port != null and _organization_port.has_method("public_receipt"):
		var value_variant: Variant = _organization_port.call("public_receipt", receipt.duplicate(true))
		if value_variant is Dictionary:
			return (value_variant as Dictionary).duplicate(true)
	return {"schema_version": RULESET_ID, "effect_kind": ORGANIZATION_EFFECT_KIND, "reason_code": "organization_owner_unavailable"}


func _authoritative_slot_effect_kind(actor_id: String, slot_index: int) -> String:
	var value_variant: Variant = _card_source_owner.call("player_snapshot", actor_id)
	if not (value_variant is Dictionary):
		return ""
	var player: Dictionary = value_variant
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return ""
	var machine: Dictionary = (slots[slot_index] as Dictionary).get("machine", {}) if (slots[slot_index] as Dictionary).get("machine", {}) is Dictionary else {}
	return str(machine.get("effect_kind", ""))


func _source_api_ready() -> bool:
	return (
		_card_source_owner != null
		and _card_source_owner.has_method("play_core_card")
		and _card_source_owner.has_method("player_snapshot")
	)


func _configuration_failure(reason_code: String) -> Dictionary:
	_configured = false
	_last_reason_code = reason_code
	return {
		"configured": false,
		"reason_code": reason_code,
		"feedback": _localized_feedback(reason_code),
	}


func _failure(reason_code: String) -> Dictionary:
	_last_reason_code = reason_code
	return {
		"committed": false,
		"reason_code": reason_code,
		"feedback": _localized_feedback(reason_code),
	}


func _localized_feedback(reason_code: String) -> Dictionary:
	match reason_code:
		"candidate_snapshot_owner_unavailable", "candidate_snapshot_unavailable", "authoritative_flow_snapshot_incomplete":
			return {"reason": "当前经济流量还不足以确认这张牌的合法目标。", "next_step": "先让对应商品完成一次真实交易，再重新选择目标。"}
		"facility_effect_owner_unavailable", "commodity_effect_owner_unavailable", "global_supply_demand_owner_unavailable":
			return {"reason": "相关经济设施暂时无法响应这张牌。", "next_step": "等待设施与商品流同步后重试；本次不会扣牌、现金或资产。"}
		"organization_consumer_capabilities_incomplete", "organization_owner_atomic_contract_missing":
			return {"reason": "组织升级所需的个人能力模块尚未全部接通。", "next_step": "本次不会扣牌、现金或资产；请先选择其他卡牌。"}
		_:
			return {"reason": "核心经济卡牌暂时无法安全结算。", "next_step": "同步最新牌面和经济状态后重试；本次不会产生部分效果。"}
