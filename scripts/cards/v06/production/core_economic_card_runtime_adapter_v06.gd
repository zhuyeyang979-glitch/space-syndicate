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
const EFFECT_SUPPORT_SCRIPT := preload("res://scripts/cards/v06/effects/card_effect_adapter_support_v06.gd")
const ORGANIZATION_EFFECT_KIND := "install_organization_upgrade"
const FACILITY_EFFECT_KIND := "build_upgrade_or_repair_facility"
const FACILITY_TARGET_KIND := "region_unique_facility_slot"
const AUTOMATIC_SUPPLY_DEMAND_TARGETS := {
	"global_order_budget": "global_matching_goods",
	"global_supply_spawn": "global_matching_factories",
}

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


func automatic_supply_demand_target_context(effect_kind: String, target_kind: String) -> Dictionary:
	if not _configured or _candidate_port == null or _global_owner == null:
		return {"ready": false, "reason_code": "core_economic_runtime_unavailable"}
	var expected_target_kind := str(AUTOMATIC_SUPPLY_DEMAND_TARGETS.get(effect_kind, ""))
	if expected_target_kind.is_empty() or target_kind != expected_target_kind:
		return {"ready": false, "reason_code": "automatic_supply_demand_target_kind_mismatch"}
	var refresh := refresh_supply_demand_candidates()
	if not bool(refresh.get("valid", false)):
		return {
			"ready": false,
			"reason_code": str(refresh.get("reason_code", "candidate_snapshot_unavailable")),
		}
	var metadata_variant: Variant = _global_owner.call("candidate_snapshot_metadata")
	var metadata: Dictionary = metadata_variant if metadata_variant is Dictionary else {}
	var revision := int(metadata.get("revision", -1))
	if (
		not bool(metadata.get("configured", false))
		or revision < 0
		or revision != int(refresh.get("revision", -2))
		or int(metadata.get("candidate_count", 0)) <= 0
	):
		return {"ready": false, "reason_code": "automatic_supply_demand_candidates_unavailable"}
	return {
		"ready": true,
		"reason_code": "automatic_supply_demand_target_ready",
		"target_context": {
			"valid": true,
			"target_kind": expected_target_kind,
			"candidate_snapshot_revision": revision,
		},
	}


func resolve_queued_automatic_supply_demand(
	actor_id: String,
	card: Dictionary,
	target_context: Dictionary,
	transaction_id: String
) -> Dictionary:
	if not _configured or _effect_router == null:
		return _failure("core_economic_runtime_unavailable")
	var build := _automatic_supply_demand_intent(actor_id, card, target_context, transaction_id)
	if not bool(build.get("valid", false)):
		return _queued_resolution_failure(str(build.get("reason_code", "queued_supply_demand_binding_invalid")), {})
	var binding: Dictionary = (build.get("binding", {}) as Dictionary).duplicate(true)
	var intent: Dictionary = (build.get("intent", {}) as Dictionary).duplicate(true)
	var prepared_variant: Variant = _effect_router.call("prepare_effect", intent)
	var prepared: Dictionary = prepared_variant if prepared_variant is Dictionary else {}
	if not bool(prepared.get("prepared", false)) or not EFFECT_SUPPORT_SCRIPT.binding_matches(prepared, binding):
		if _effect_router.has_method("abort_prepared_effect"):
			_effect_router.call("abort_prepared_effect", prepared.duplicate(true))
		return _queued_resolution_failure(str(prepared.get("reason_code", "effect_prepare_failed")), binding)
	var committed_variant: Variant = _effect_router.call("commit_effect", prepared.duplicate(true))
	var committed: Dictionary = committed_variant if committed_variant is Dictionary else {}
	if not bool(committed.get("committed", false)) or not EFFECT_SUPPORT_SCRIPT.binding_matches(committed, binding):
		if _effect_router.has_method("abort_prepared_effect"):
			_effect_router.call("abort_prepared_effect", prepared.duplicate(true))
		return _queued_resolution_failure(str(committed.get("reason_code", "effect_commit_failed")), binding)
	var finalized_variant: Variant = _effect_router.call("finalize_effect", committed.duplicate(true))
	var finalized: Dictionary = finalized_variant if finalized_variant is Dictionary else {}
	if not bool(finalized.get("finalized", false)):
		var rollback_variant: Variant = _effect_router.call("rollback_effect", committed.duplicate(true)) if _effect_router.has_method("rollback_effect") else {}
		var rollback: Dictionary = rollback_variant if rollback_variant is Dictionary else {}
		var reason_code := "effect_finalize_failed" if bool(rollback.get("rolled_back", false)) else "effect_compensation_failed"
		var failure := _queued_resolution_failure(reason_code, binding)
		failure["rollback"] = rollback.duplicate(true)
		return failure
	_last_reason_code = "queued_supply_demand_resolved"
	return {
		"handled": true,
		"committed": true,
		"finalized": true,
		"resolved": true,
		"reason_code": "queued_supply_demand_resolved",
		"binding": binding.duplicate(true),
		"effect_receipt": committed.duplicate(true),
		"effect_finalization": finalized.duplicate(true),
		"idempotent_replay": bool(finalized.get("idempotent_replay", false)) or bool(committed.get("duplicate", false)),
	}


func preflight_automatic_supply_demand(
	actor_id: String,
	card: Dictionary,
	target_context: Dictionary,
	transaction_id: String
) -> Dictionary:
	if not _configured or _effect_router == null:
		return {"ready": false, "reason_code": "core_economic_runtime_unavailable"}
	var build := _automatic_supply_demand_intent(actor_id, card, target_context, transaction_id)
	if not bool(build.get("valid", false)):
		return {"ready": false, "reason_code": str(build.get("reason_code", "queued_supply_demand_binding_invalid"))}
	var binding: Dictionary = (build.get("binding", {}) as Dictionary).duplicate(true)
	var intent: Dictionary = (build.get("intent", {}) as Dictionary).duplicate(true)
	var prepared_variant: Variant = _effect_router.call("prepare_effect", intent)
	var prepared: Dictionary = prepared_variant if prepared_variant is Dictionary else {}
	var ready := bool(prepared.get("prepared", false)) and EFFECT_SUPPORT_SCRIPT.binding_matches(prepared, binding)
	if _effect_router.has_method("abort_prepared_effect"):
		_effect_router.call("abort_prepared_effect", prepared.duplicate(true))
	return {
		"ready": ready,
		"reason_code": "automatic_supply_demand_preflight_ready" if ready else str(prepared.get("reason_code", "effect_prepare_failed")),
		"target_context": target_context.duplicate(true) if ready else {},
	}


func _automatic_supply_demand_intent(
	actor_id: String,
	card: Dictionary,
	target_context: Dictionary,
	transaction_id: String
) -> Dictionary:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var effect_kind := str(machine.get("effect_kind", ""))
	var expected_target_kind := str(AUTOMATIC_SUPPLY_DEMAND_TARGETS.get(effect_kind, ""))
	var card_id := str(machine.get("card_id", ""))
	var card_instance_id := str(card.get("runtime_instance_id", ""))
	var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
	if actor_id.strip_edges().is_empty() or transaction_id.strip_edges().is_empty() or card_id.is_empty() or card_instance_id.is_empty() or payload.is_empty():
		return {"valid": false, "reason_code": "queued_supply_demand_binding_invalid"}
	if expected_target_kind.is_empty() or not bool(target_context.get("valid", false)) or str(target_context.get("target_kind", "")) != expected_target_kind:
		return {"valid": false, "reason_code": "automatic_supply_demand_target_kind_mismatch"}
	var target_hash := _stable_hash(target_context)
	var payload_hash := _stable_hash(payload)
	var intent_hash := _stable_hash({
		"operation": "resolve_queued_automatic_supply_demand",
		"transaction_id": transaction_id,
		"actor_id": actor_id,
		"card_id": card_id,
		"card_instance_id": card_instance_id,
		"effect_kind": effect_kind,
		"target_hash": target_hash,
		"payload_hash": payload_hash,
	})
	var binding := {
		"transaction_id": transaction_id,
		"actor_id": actor_id,
		"card_id": card_id,
		"card_instance_id": card_instance_id,
		"effect_kind": effect_kind,
		"target_hash": target_hash,
		"payload_hash": payload_hash,
		"intent_hash": intent_hash,
	}
	var intent := binding.duplicate(true)
	intent["target_context"] = target_context.duplicate(true)
	intent["effect_payload"] = payload.duplicate(true)
	intent["contract"] = "prepare_is_side_effect_free"
	return {
		"valid": true,
		"reason_code": "automatic_supply_demand_intent_ready",
		"binding": binding.duplicate(true),
		"intent": intent.duplicate(true),
	}


func facility_target_context(
	actor_id: String,
	slot_index: int,
	card_id: String,
	region_id: String,
	game_time: float
) -> Dictionary:
	if not _configured or not _source_api_ready() or _effect_router == null:
		return {"ready": false, "reason_code": "core_economic_runtime_unavailable"}
	var player := _authoritative_player_snapshot(actor_id)
	var card := _authoritative_slot_card(player, slot_index)
	var binding_error := _facility_card_binding_error(card, card_id)
	if not binding_error.is_empty():
		return {"ready": false, "reason_code": binding_error}
	return _facility_target_context_for_card(card, region_id, game_time)


func preflight_facility_target(
	player_index: int,
	slot_index: int,
	card_id: String,
	region_id: String,
	game_time: float
) -> Dictionary:
	if not _configured or not _source_api_ready() or _effect_router == null \
			or not _effect_router.has_method("abort_prepared_effect"):
		return _public_facility_preflight(false, "core_economic_runtime_unavailable")
	var actor_id := _actor_id_for_player_index(player_index)
	if actor_id.is_empty():
		return _public_facility_preflight(false, "actor_mapping_missing")
	var player := _authoritative_player_snapshot(actor_id)
	var card := _authoritative_slot_card(player, slot_index)
	var binding_error := _facility_card_binding_error(card, card_id)
	if not binding_error.is_empty():
		return _public_facility_preflight(false, binding_error)
	var target_result := _facility_target_context_for_card(card, region_id, game_time)
	if not bool(target_result.get("ready", false)):
		return _public_facility_preflight(false, str(target_result.get("reason_code", "facility_target_unavailable")))
	var target_context: Dictionary = target_result.get("target_context", {}) if target_result.get("target_context", {}) is Dictionary else {}
	var expected_player_revision := int(player.get("revision", -1))
	var card_instance_id := str(card.get("runtime_instance_id", ""))
	# This is the same deterministic transaction binding used by the formal v0.6
	# submission. Prepare is safe here because neither CardFlow nor its journal is
	# entered, and the router record is synchronously aborted below.
	var transaction_id := "v06-play:%s:%s:%s" % [actor_id, card_instance_id, region_id]
	var build := _facility_effect_intent(
		actor_id,
		slot_index,
		card,
		target_context,
		expected_player_revision,
		transaction_id
	)
	if not bool(build.get("valid", false)):
		return _public_facility_preflight(false, str(build.get("reason_code", "facility_preflight_binding_invalid")))
	var binding: Dictionary = (build.get("binding", {}) as Dictionary).duplicate(true)
	var intent: Dictionary = (build.get("intent", {}) as Dictionary).duplicate(true)
	var prepared_variant: Variant = _effect_router.call("prepare_effect", intent)
	var prepared: Dictionary = prepared_variant if prepared_variant is Dictionary else {}
	var prepared_ready := bool(prepared.get("prepared", false)) and EFFECT_SUPPORT_SCRIPT.binding_matches(prepared, binding)
	var reason_code := "public_facility_target_ready" if prepared_ready else str(prepared.get("reason_code", "effect_prepare_failed"))
	var abort_variant: Variant = _effect_router.call("abort_prepared_effect", prepared.duplicate(true))
	var abort_receipt: Dictionary = abort_variant if abort_variant is Dictionary else {}
	var abort_verified := (
		bool(abort_receipt.get("aborted", false))
		and bool(abort_receipt.get("verified", false))
		and str(abort_receipt.get("transaction_id", "")) == transaction_id
		and not bool(abort_receipt.get("transaction_pending", true))
	)
	var ready := prepared_ready and abort_verified
	if prepared_ready and not abort_verified:
		reason_code = "facility_preflight_abort_unverified"
	return _public_facility_preflight(ready, reason_code)


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
	var card := _authoritative_slot_card(_authoritative_player_snapshot(actor_id), slot_index)
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	return str(machine.get("effect_kind", ""))


func _authoritative_player_snapshot(actor_id: String) -> Dictionary:
	if _card_source_owner == null or not _card_source_owner.has_method("player_snapshot"):
		return {}
	var value_variant: Variant = _card_source_owner.call("player_snapshot", actor_id)
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {}


func _authoritative_slot_card(player: Dictionary, slot_index: int) -> Dictionary:
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return {}
	return (slots[slot_index] as Dictionary).duplicate(true)


func _actor_id_for_player_index(player_index: int) -> String:
	for actor_variant in _actor_player_indices.keys():
		if int(_actor_player_indices.get(actor_variant, -1)) == player_index:
			return str(actor_variant)
	return ""


func _facility_card_binding_error(card: Dictionary, requested_card_id: String) -> String:
	if card.is_empty():
		return "facility_card_unavailable"
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var card_id := str(machine.get("card_id", ""))
	if card_id.is_empty() or str(card.get("runtime_instance_id", "")).is_empty():
		return "facility_card_binding_invalid"
	if requested_card_id.strip_edges().is_empty() or requested_card_id != card_id:
		return "facility_card_binding_changed"
	if str(machine.get("effect_kind", "")) != FACILITY_EFFECT_KIND \
			or str(machine.get("target_kind", "")) != FACILITY_TARGET_KIND:
		return "facility_card_binding_invalid"
	return ""


func _facility_target_context_for_card(card: Dictionary, region_id: String, game_time: float) -> Dictionary:
	var normalized_region_id := region_id.strip_edges()
	if normalized_region_id.is_empty() or _infrastructure_owner == null:
		return {"ready": false, "reason_code": "facility_target_region_missing"}
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
	var facility_kind := str(payload.get("facility_kind", ""))
	var industry_id := str(payload.get("industry_id", machine.get("industry_id", "")))
	var slot_id := str(_infrastructure_owner.call("slot_id", normalized_region_id, facility_kind, industry_id))
	var region_variant: Variant = _infrastructure_owner.call("region_snapshot", normalized_region_id)
	var region: Dictionary = region_variant if region_variant is Dictionary else {}
	if region.is_empty() or slot_id.is_empty():
		return {"ready": false, "reason_code": "facility_target_unavailable"}
	return {
		"ready": true,
		"reason_code": "facility_target_context_ready",
		"target_context": {
			"valid": true,
			"target_kind": FACILITY_TARGET_KIND,
			"region_id": normalized_region_id,
			"slot_id": slot_id,
			"industry_id": industry_id,
			"game_time": game_time,
		},
	}


func _facility_effect_intent(
	actor_id: String,
	slot_index: int,
	card: Dictionary,
	target_context: Dictionary,
	expected_player_revision: int,
	transaction_id: String
) -> Dictionary:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
	var card_id := str(machine.get("card_id", ""))
	var card_instance_id := str(card.get("runtime_instance_id", ""))
	if actor_id.is_empty() or slot_index < 0 or card_id.is_empty() or card_instance_id.is_empty() \
			or transaction_id.is_empty() or expected_player_revision < 0:
		return {"valid": false, "reason_code": "facility_preflight_binding_invalid"}
	var target_hash := _stable_hash(target_context)
	var payload_hash := _stable_hash(payload)
	# Keep this binding byte-for-byte aligned with CardFlowTransactionServiceV06.play_card.
	var intent_hash := _stable_hash({
		"operation": "play_card",
		"actor_id": actor_id,
		"slot_index": slot_index,
		"target_hash": target_hash,
		"expected_player_revision": expected_player_revision,
	})
	var binding := {
		"transaction_id": transaction_id,
		"actor_id": actor_id,
		"card_id": card_id,
		"card_instance_id": card_instance_id,
		"effect_kind": FACILITY_EFFECT_KIND,
		"target_hash": target_hash,
		"payload_hash": payload_hash,
		"intent_hash": intent_hash,
	}
	var intent := binding.duplicate(true)
	intent["target_context"] = target_context.duplicate(true)
	intent["effect_payload"] = payload.duplicate(true)
	intent["contract"] = "prepare_is_side_effect_free"
	return {
		"valid": true,
		"reason_code": "facility_preflight_intent_ready",
		"binding": binding,
		"intent": intent,
	}


func _public_facility_preflight(ready: bool, internal_reason_code: String) -> Dictionary:
	return {
		"applicable": true,
		"ready": ready,
		"reason_code": "public_facility_target_ready" if ready else _public_facility_reason_code(internal_reason_code),
	}


func _public_facility_reason_code(internal_reason_code: String) -> String:
	match internal_reason_code:
		"facility_owned_by_other":
			return "public_facility_slot_occupied"
		"facility_slot_state_mismatch":
			return "public_facility_slot_incompatible"
		"region_production_product_industry_mismatch", "region_commodity_facts_unavailable", \
		"region_commodity_facts_invalid", "region_commodity_facts_changed":
			return "public_facility_product_unavailable"
		"region_not_found", "region_lifecycle_not_allowed", "facility_slot_mismatch", \
		"facility_slot_missing", "facility_target_region_missing", "facility_target_unavailable":
			return "public_facility_target_unavailable"
		"facility_kind_invalid", "facility_rank_invalid", "facility_industry_invalid", \
		"facility_industry_mismatch", "warehouse_industry_required", \
		"transport_industry_must_be_empty", "facility_card_unavailable", \
		"facility_card_binding_invalid", "facility_card_binding_changed":
			return "public_facility_card_unavailable"
		_:
			return "public_facility_preflight_unavailable"


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


func _queued_resolution_failure(reason_code: String, binding: Dictionary) -> Dictionary:
	_last_reason_code = reason_code
	return {
		"handled": true,
		"committed": false,
		"finalized": false,
		"resolved": false,
		"reason_code": reason_code,
		"binding": binding.duplicate(true),
		"feedback": _localized_feedback(reason_code),
	}


func _stable_hash(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(_canonicalize(value)).to_utf8_buffer())
	return context.finish().hex_encode()


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		for key_variant in keys:
			result[str(key_variant)] = _canonicalize((value as Dictionary).get(key_variant))
		return result
	if value is Array:
		var result: Array = []
		for item_variant in value as Array:
			result.append(_canonicalize(item_variant))
		return result
	return value


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
