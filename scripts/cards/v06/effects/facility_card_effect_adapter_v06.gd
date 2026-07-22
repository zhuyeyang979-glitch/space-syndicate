extends RefCounted
class_name FacilityCardEffectAdapterV06

const SUPPORT := preload("res://scripts/cards/v06/effects/card_effect_adapter_support_v06.gd")
const EXPECTED_EFFECT_KIND := "build_upgrade_or_repair_facility"
const EXPECTED_TARGET_KIND := "region_unique_facility_slot"
const COLORED_FACILITY_KINDS := ["factory", "market", "warehouse"]
const TRANSPORT_FACILITY_KINDS := ["road", "port", "spaceport"]
const INDUSTRY_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]

var _controller: Object
var _flow_controller: Object
var _region_facts_port: Object
var _actor_player_indices: Dictionary = {}
var _prepared_by_transaction: Dictionary = {}


func configure(
	controller: Object,
	actor_player_indices: Dictionary,
	flow_controller: Object = null,
	region_facts_port: Object = null
) -> Dictionary:
	_controller = controller
	_flow_controller = flow_controller
	_region_facts_port = region_facts_port
	_actor_player_indices = _normalized_actor_map(actor_player_indices)
	_prepared_by_transaction.clear()
	var configured := (
		_controller != null
		and _controller.has_method("region_snapshot")
		and _controller.has_method("slot_id")
		and _controller.has_method("apply_facility_action")
		and _controller.has_method("rollback_facility_action")
		and not _actor_player_indices.is_empty()
	)
	var product_installation_ready := (
		_flow_controller != null
		and _flow_controller.has_method("install_commodity")
		and _flow_controller.has_method("rollback_commodity_installation")
		and _flow_controller.has_method("commodity_installation_finalize_preflight")
		and _flow_controller.has_method("finalize_commodity_installation")
		and _flow_controller.has_method("installations_snapshot")
		and _region_facts_port != null
		and _region_facts_port.has_method("region_commodity_facts")
	)
	return {
		"configured": configured,
		"actor_count": _actor_player_indices.size(),
		"product_installation_ready": product_installation_ready,
	}


func prepare_effect(intent: Dictionary) -> Dictionary:
	var common_error := _common_intent_error(intent)
	if not common_error.is_empty():
		return SUPPORT.failure_receipt(intent, common_error)
	var transaction_id := str(intent.get("transaction_id", ""))
	if _prepared_by_transaction.has(transaction_id):
		var previous: Dictionary = _prepared_by_transaction[transaction_id]
		if SUPPORT.binding_matches(previous, intent):
			return previous.duplicate(true)
		return SUPPORT.failure_receipt(intent, "transaction_binding_collision")
	var actor_id := str(intent.get("actor_id", ""))
	var player_index := int(_actor_player_indices.get(actor_id, -1))
	var payload: Dictionary = intent.get("effect_payload", {}) if intent.get("effect_payload", {}) is Dictionary else {}
	var target: Dictionary = intent.get("target_context", {}) if intent.get("target_context", {}) is Dictionary else {}
	var facility_kind := str(payload.get("facility_kind", ""))
	var rank := int(payload.get("card_rank", 0))
	if not COLORED_FACILITY_KINDS.has(facility_kind) and not TRANSPORT_FACILITY_KINDS.has(facility_kind):
		return SUPPORT.failure_receipt(intent, "facility_kind_invalid")
	if rank < 1 or rank > 4:
		return SUPPORT.failure_receipt(intent, "facility_rank_invalid")
	var industry_result := _resolve_industry(facility_kind, payload, target)
	if not bool(industry_result.get("valid", false)):
		return SUPPORT.failure_receipt(intent, str(industry_result.get("reason_code", "facility_industry_invalid")))
	var industry_id := str(industry_result.get("industry_id", ""))
	var region_id := str(target.get("region_id", "")).strip_edges()
	var region: Dictionary = _controller.call("region_snapshot", region_id)
	if region.is_empty():
		return SUPPORT.failure_receipt(intent, "region_not_found")
	var lifecycle_state := str(region.get("lifecycle_state", ""))
	var allowed_states: Array = payload.get("allowed_region_states", []) if payload.get("allowed_region_states", []) is Array else []
	if not allowed_states.has(lifecycle_state):
		return SUPPORT.failure_receipt(intent, "region_lifecycle_not_allowed")
	var expected_slot_id := str(_controller.call("slot_id", region_id, facility_kind, industry_id))
	var target_slot_id := str(target.get("slot_id", target.get("target_id", ""))).strip_edges()
	if target_slot_id.is_empty() or target_slot_id != expected_slot_id:
		return SUPPORT.failure_receipt(intent, "facility_slot_mismatch")
	var slot_ids: Array = region.get("facility_slot_ids", []) if region.get("facility_slot_ids", []) is Array else []
	if not slot_ids.has(expected_slot_id):
		return SUPPORT.failure_receipt(intent, "facility_slot_missing")
	var existing := _facility_for_slot(region, expected_slot_id)
	if not existing.is_empty():
		if str(existing.get("owner_kind", "")) != "player" or int(existing.get("owner_player_index", -1)) != player_index:
			return SUPPORT.failure_receipt(intent, "facility_owned_by_other")
		if str(existing.get("facility_type", "")) != facility_kind or str(existing.get("industry_id", "")) != industry_id:
			return SUPPORT.failure_receipt(intent, "facility_slot_state_mismatch")
	var production_binding: Dictionary = {}
	var product_installation_required := false
	if facility_kind == "factory" and _flow_controller != null and _region_facts_port != null:
		var region_facts := _region_commodity_facts(region_id)
		if not bool(region_facts.get("available", false)) or not bool(region_facts.get("authoritative", false)):
			return SUPPORT.failure_receipt(intent, str(region_facts.get("reason_code", "region_commodity_facts_unavailable")))
		production_binding = _production_product_binding(region_facts, industry_id)
		if production_binding.is_empty():
			return SUPPORT.failure_receipt(intent, "region_production_product_industry_mismatch")
		product_installation_required = existing.is_empty() or not _active_production_installation_exists(
			str(existing.get("facility_id", "")),
			str(production_binding.get("product_id", "")),
			player_index
		)
	var request := {
		"transaction_id": transaction_id,
		"region_id": region_id,
		"owner_kind": "player",
		"owner_player_index": player_index,
		"facility_type": facility_kind,
		"industry_id": industry_id,
		"rank": rank,
		"occurred_at": float(target.get("game_time", target.get("occurred_at", 0.0))),
	}
	var prepared := SUPPORT.prepared_receipt(intent, {
		"adapter_kind": "facility_commodity_composite_v06" if product_installation_required else "facility_v06",
		"prepared_token": SUPPORT.fingerprint({"binding": SUPPORT.binding_from(intent), "request": request, "region_revision": int(region.get("revision", -1)), "production_binding": production_binding}),
		"owner_request": request,
		"region_revision": int(region.get("revision", -1)),
		"slot_id": expected_slot_id,
		"production_binding": production_binding.duplicate(true),
		"product_installation_required": product_installation_required,
	})
	_prepared_by_transaction[transaction_id] = prepared.duplicate(true)
	return prepared


func commit_effect(prepared: Dictionary) -> Dictionary:
	var transaction_id := str(prepared.get("transaction_id", ""))
	if not _prepared_by_transaction.has(transaction_id):
		return SUPPORT.failure_receipt(prepared, "prepared_record_missing", "commit")
	var expected: Dictionary = _prepared_by_transaction[transaction_id]
	if not SUPPORT.binding_matches(expected, prepared) or str(expected.get("prepared_token", "")) != str(prepared.get("prepared_token", "")):
		return SUPPORT.failure_receipt(prepared, "prepared_record_mismatch", "commit")
	var request: Dictionary = expected.get("owner_request", {}) if expected.get("owner_request", {}) is Dictionary else {}
	var region: Dictionary = _controller.call("region_snapshot", str(request.get("region_id", "")))
	if region.is_empty() or int(region.get("revision", -2)) != int(expected.get("region_revision", -1)):
		return SUPPORT.failure_receipt(prepared, "region_revision_changed", "commit")
	if bool(expected.get("product_installation_required", false)):
		var current_facts := _region_commodity_facts(str(request.get("region_id", "")))
		var expected_binding: Dictionary = expected.get("production_binding", {}) if expected.get("production_binding", {}) is Dictionary else {}
		if not bool(current_facts.get("available", false)) \
			or str(current_facts.get("facts_fingerprint", "")) != str(expected_binding.get("facts_fingerprint", "")):
			return SUPPORT.failure_receipt(prepared, "region_commodity_facts_changed", "commit")
	var owner_variant: Variant = _controller.call("apply_facility_action", request.duplicate(true))
	if not (owner_variant is Dictionary):
		return SUPPORT.failure_receipt(prepared, "facility_owner_receipt_invalid", "commit")
	var facility_receipt: Dictionary = (owner_variant as Dictionary).duplicate(true)
	if not bool(facility_receipt.get("committed", false)):
		return SUPPORT.committed_receipt(prepared, facility_receipt)
	if not bool(expected.get("product_installation_required", false)):
		var facility_only_receipt := SUPPORT.committed_receipt(prepared, facility_receipt)
		_prepared_by_transaction.erase(transaction_id)
		return facility_only_receipt
	var production_binding: Dictionary = expected.get("production_binding", {}) if expected.get("production_binding", {}) is Dictionary else {}
	var facility := _facility_snapshot(str(facility_receipt.get("facility_id", "")))
	if facility.is_empty():
		var missing_facility_rollback: Variant = _controller.call("rollback_facility_action", facility_receipt.duplicate(true))
		var missing_facility_failure := SUPPORT.failure_receipt(prepared, "facility_post_commit_snapshot_missing", "commit")
		missing_facility_failure["compensation"] = missing_facility_rollback
		return missing_facility_failure
	var commodity_transaction_id := "%s:commodity-production" % transaction_id
	var installation_request := {
		"transaction_id": commodity_transaction_id,
		"installation_id": "%s:installation" % commodity_transaction_id,
		"facility": facility.duplicate(true),
		"facility_id": str(facility.get("facility_id", "")),
		"region_id": str(facility.get("region_id", "")),
		"region_revision": int((_controller.call("region_snapshot", str(facility.get("region_id", ""))) as Dictionary).get("revision", 0)),
		"commodity_id": str(production_binding.get("product_id", "")),
		"direction": "production",
		"installer_player_index": int(request.get("owner_player_index", -1)),
		"source_card_rank": int(request.get("rank", 0)),
		"color": str(production_binding.get("industry_id", "")),
		"installed_at": float(request.get("occurred_at", 0.0)),
	}
	var commodity_variant: Variant = _flow_controller.call("install_commodity", installation_request)
	var commodity_receipt: Dictionary = (commodity_variant as Dictionary).duplicate(true) if commodity_variant is Dictionary else {}
	if not bool(commodity_receipt.get("committed", false)):
		var facility_rollback_variant: Variant = _controller.call("rollback_facility_action", facility_receipt.duplicate(true))
		var facility_rollback: Dictionary = (facility_rollback_variant as Dictionary).duplicate(true) if facility_rollback_variant is Dictionary else {}
		var install_failure := SUPPORT.failure_receipt(prepared, "commodity_installation_commit_failed", "commit")
		install_failure["owner_reason_code"] = str(commodity_receipt.get("reason_code", commodity_receipt.get("reason", "commodity_installation_rejected")))
		install_failure["compensation"] = facility_rollback
		install_failure["compensation_failed"] = not bool(facility_rollback.get("rolled_back", false))
		return install_failure
	var composite_owner_receipt := {
		"receipt_kind": "facility_commodity_composite",
		"transaction_id": transaction_id,
		"committed": true,
		"rollback_open": true,
		"finalized": false,
		"facility_receipt": facility_receipt.duplicate(true),
		"commodity_receipt": commodity_receipt.duplicate(true),
		"product_id": str(production_binding.get("product_id", "")),
		"industry_id": str(production_binding.get("industry_id", "")),
	}
	var receipt := SUPPORT.committed_receipt(prepared, composite_owner_receipt)
	if bool(receipt.get("committed", false)):
		_prepared_by_transaction.erase(transaction_id)
	return receipt


func abort_prepared_effect(prepared: Dictionary) -> Dictionary:
	var transaction_id := str(prepared.get("transaction_id", ""))
	if not _prepared_by_transaction.has(transaction_id):
		return {
			"aborted": false,
			"reason_code": "facility_prepared_record_missing",
			"transaction_id": transaction_id,
			"prepared_token": str(prepared.get("prepared_token", "")),
			"pending_transaction_count": _prepared_by_transaction.size(),
		}
	var expected: Dictionary = _prepared_by_transaction[transaction_id]
	if not SUPPORT.binding_matches(expected, prepared) \
			or str(expected.get("prepared_token", "")) != str(prepared.get("prepared_token", "")):
		return {
			"aborted": false,
			"reason_code": "facility_prepared_record_mismatch",
			"transaction_id": transaction_id,
			"prepared_token": str(prepared.get("prepared_token", "")),
			"pending_transaction_count": _prepared_by_transaction.size(),
		}
	_prepared_by_transaction.erase(transaction_id)
	return {
		"aborted": true,
		"reason_code": "facility_prepared_aborted",
		"transaction_id": transaction_id,
		"prepared_token": str(expected.get("prepared_token", "")),
		"pending_transaction_count": _prepared_by_transaction.size(),
	}


func rollback_effect(receipt: Dictionary) -> Dictionary:
	if _controller == null or not _controller.has_method("rollback_facility_action"):
		return {"rolled_back": false, "committed": false, "reason": "facility_owner_unavailable"}
	if not SUPPORT.binding_is_complete(receipt):
		return {"rolled_back": false, "committed": false, "reason": "effect_receipt_invalid"}
	var transaction_id := str(receipt.get("transaction_id", "")).strip_edges()
	var owner_receipt := _owner_receipt(receipt)
	if owner_receipt.is_empty() or str(owner_receipt.get("transaction_id", "")) != transaction_id or not bool(owner_receipt.get("committed", false)):
		return {"rolled_back": false, "committed": false, "reason": "effect_receipt_invalid", "transaction_id": transaction_id}
	if str(owner_receipt.get("receipt_kind", "")) == "facility_commodity_composite":
		var commodity_receipt: Dictionary = owner_receipt.get("commodity_receipt", {}) if owner_receipt.get("commodity_receipt", {}) is Dictionary else {}
		var facility_receipt: Dictionary = owner_receipt.get("facility_receipt", {}) if owner_receipt.get("facility_receipt", {}) is Dictionary else {}
		var commodity_variant: Variant = _flow_controller.call("rollback_commodity_installation", str(commodity_receipt.get("transaction_id", "")))
		var commodity_result: Dictionary = (commodity_variant as Dictionary).duplicate(true) if commodity_variant is Dictionary else {}
		if not bool(commodity_result.get("rolled_back", false)):
			return {"rolled_back": false, "committed": true, "reason_code": "commodity_installation_rollback_failed", "transaction_id": transaction_id, "commodity_result": commodity_result}
		var facility_variant: Variant = _controller.call("rollback_facility_action", facility_receipt.duplicate(true))
		var facility_result: Dictionary = (facility_variant as Dictionary).duplicate(true) if facility_variant is Dictionary else {}
		return {
			"rolled_back": bool(facility_result.get("rolled_back", false)),
			"committed": not bool(facility_result.get("rolled_back", false)),
			"reason_code": "facility_commodity_composite_rolled_back" if bool(facility_result.get("rolled_back", false)) else "facility_action_rollback_failed",
			"transaction_id": transaction_id,
			"commodity_result": commodity_result,
			"facility_result": facility_result,
		}
	var result_variant: Variant = _controller.call("rollback_facility_action", owner_receipt.duplicate(true))
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {
		"rolled_back": false,
		"committed": false,
		"reason": "facility_owner_rollback_invalid",
		"transaction_id": transaction_id,
	}


func finalize_effect(receipt: Dictionary) -> Dictionary:
	if _controller == null or not _controller.has_method("finalize_facility_action"):
		return {"finalized": false, "reason_code": "facility_owner_finalize_unavailable"}
	var transaction_id := str(receipt.get("transaction_id", "")).strip_edges()
	var owner_receipt := _owner_receipt(receipt)
	if transaction_id.is_empty() or owner_receipt.is_empty() or str(owner_receipt.get("transaction_id", "")) != transaction_id:
		return {"finalized": false, "reason_code": "effect_receipt_invalid", "transaction_id": transaction_id}
	if str(owner_receipt.get("receipt_kind", "")) == "facility_commodity_composite":
		var commodity_receipt: Dictionary = owner_receipt.get("commodity_receipt", {}) if owner_receipt.get("commodity_receipt", {}) is Dictionary else {}
		var facility_receipt: Dictionary = owner_receipt.get("facility_receipt", {}) if owner_receipt.get("facility_receipt", {}) is Dictionary else {}
		var facility_preflight := _facility_finalize_preflight(facility_receipt)
		if not bool(facility_preflight.get("ready", false)):
			return {"finalized": false, "reason_code": str(facility_preflight.get("reason_code", "facility_action_finalize_preflight_failed")), "transaction_id": transaction_id, "facility_preflight": facility_preflight}
		var commodity_preflight := _commodity_finalize_preflight(commodity_receipt)
		if not bool(commodity_preflight.get("ready", false)):
			return {"finalized": false, "reason_code": str(commodity_preflight.get("reason_code", "commodity_installation_finalize_preflight_failed")), "transaction_id": transaction_id, "commodity_preflight": commodity_preflight}
		var facility_variant: Variant = _controller.call("finalize_facility_action", facility_receipt.duplicate(true))
		var facility_result: Dictionary = (facility_variant as Dictionary).duplicate(true) if facility_variant is Dictionary else {}
		if not bool(facility_result.get("finalized", false)):
			return {
				"finalized": false,
				"reason_code": "facility_action_finalize_failed",
				"transaction_id": transaction_id,
				"commodity_rollback_open": true,
				"facility_result": facility_result,
			}
		# The flow owner has no remaining rejection branch after this preflight in the
		# same synchronous call stack, so closing it second cannot strand the facility.
		var commodity_variant: Variant = _flow_controller.call("finalize_commodity_installation", commodity_receipt.duplicate(true))
		var commodity_result: Dictionary = (commodity_variant as Dictionary).duplicate(true) if commodity_variant is Dictionary else {}
		if not bool(commodity_result.get("finalized", false)):
			return {"finalized": false, "reason_code": "commodity_installation_finalize_failed_after_facility", "transaction_id": transaction_id, "commodity_result": commodity_result, "facility_result": facility_result}
		return {
			"finalized": true,
			"reason_code": "facility_commodity_composite_finalized",
			"transaction_id": transaction_id,
			"commodity_result": commodity_result,
			"facility_result": facility_result,
		}
	# Facility-only owner finalization belongs to the inventory transaction
	# boundary, which can persist and retry a failed owner finalization. This
	# adapter directly finalizes only the two-owner composite above.
	return {
		"finalized": false,
		"reason_code": "facility_owner_finalize_delegated",
		"transaction_id": transaction_id,
	}


func _common_intent_error(intent: Dictionary) -> String:
	if _controller == null:
		return "facility_owner_unavailable"
	if not SUPPORT.binding_is_complete(intent):
		return "effect_binding_incomplete"
	if str(intent.get("effect_kind", "")) != EXPECTED_EFFECT_KIND:
		return "effect_kind_mismatch"
	var target: Dictionary = intent.get("target_context", {}) if intent.get("target_context", {}) is Dictionary else {}
	if not bool(target.get("valid", false)) or str(target.get("target_kind", "")) != EXPECTED_TARGET_KIND:
		return "target_kind_mismatch"
	var actor_id := str(intent.get("actor_id", ""))
	if not _actor_player_indices.has(actor_id):
		return "actor_mapping_missing"
	return ""


func _resolve_industry(facility_kind: String, payload: Dictionary, target: Dictionary) -> Dictionary:
	var payload_industry := str(payload.get("industry_id", ""))
	var target_industry := str(target.get("industry_id", ""))
	if facility_kind == "warehouse":
		if not INDUSTRY_IDS.has(target_industry):
			return {"valid": false, "reason_code": "warehouse_industry_required"}
		return {"valid": true, "industry_id": target_industry}
	if COLORED_FACILITY_KINDS.has(facility_kind):
		if not INDUSTRY_IDS.has(payload_industry):
			return {"valid": false, "reason_code": "facility_industry_invalid"}
		if not target_industry.is_empty() and target_industry != payload_industry:
			return {"valid": false, "reason_code": "facility_industry_mismatch"}
		return {"valid": true, "industry_id": payload_industry}
	if not payload_industry.is_empty() or not target_industry.is_empty():
		return {"valid": false, "reason_code": "transport_industry_must_be_empty"}
	return {"valid": true, "industry_id": ""}


func _facility_for_slot(region: Dictionary, target_slot_id: String) -> Dictionary:
	var facilities: Array = region.get("facilities", []) if region.get("facilities", []) is Array else []
	for facility_variant in facilities:
		if facility_variant is Dictionary and str((facility_variant as Dictionary).get("slot_id", "")) == target_slot_id:
			return (facility_variant as Dictionary).duplicate(true)
	return {}


func _region_commodity_facts(region_id: String) -> Dictionary:
	if _region_facts_port == null or not _region_facts_port.has_method("region_commodity_facts"):
		return {
			"available": false,
			"authoritative": false,
			"reason_code": "region_commodity_facts_unavailable",
		}
	var value: Variant = _region_facts_port.call("region_commodity_facts", region_id)
	if not (value is Dictionary):
		return {
			"available": false,
			"authoritative": false,
			"reason_code": "region_commodity_facts_invalid",
		}
	return (value as Dictionary).duplicate(true)


func _production_product_binding(region_facts: Dictionary, industry_id: String) -> Dictionary:
	var products: Array = region_facts.get("production_products", []) if region_facts.get("production_products", []) is Array else []
	var fallback: Dictionary = {}
	for product_variant in products:
		if not (product_variant is Dictionary):
			continue
		var product: Dictionary = product_variant
		if str(product.get("industry_id", "")) != industry_id:
			continue
		var product_id := str(product.get("product_id", "")).strip_edges()
		if product_id.is_empty():
			continue
		var binding := {
			"product_id": product_id,
			"industry_id": industry_id,
			"region_id": str(region_facts.get("region_id", "")),
			"region_revision": int(region_facts.get("region_revision", 0)),
			"facts_fingerprint": str(region_facts.get("facts_fingerprint", "")),
		}
		if _active_public_demand_exists(product_id):
			return binding
		if fallback.is_empty():
			fallback = binding
	return fallback


func _active_public_demand_exists(product_id: String) -> bool:
	if product_id.is_empty() or _flow_controller == null or not _flow_controller.has_method("installations_snapshot"):
		return false
	var value: Variant = _flow_controller.call("installations_snapshot", false)
	if not (value is Array):
		return false
	for installation_variant in value as Array:
		if not (installation_variant is Dictionary):
			continue
		var installation: Dictionary = installation_variant
		if bool(installation.get("active", false)) \
			and str(installation.get("direction", "")) == "demand" \
			and str(installation.get("owner_kind", "")) == "public" \
			and str(installation.get("commodity_id", "")) == product_id:
			return true
	return false


func _active_production_installation_exists(facility_id: String, product_id: String, player_index: int) -> bool:
	if facility_id.is_empty() or product_id.is_empty() or _flow_controller == null or not _flow_controller.has_method("installations_snapshot"):
		return false
	var value: Variant = _flow_controller.call("installations_snapshot", false)
	if not (value is Array):
		return false
	for installation_variant in value as Array:
		if not (installation_variant is Dictionary):
			continue
		var installation: Dictionary = installation_variant
		if bool(installation.get("active", false)) \
			and str(installation.get("direction", "")) == "production" \
			and str(installation.get("facility_id", "")) == facility_id \
			and str(installation.get("commodity_id", "")) == product_id \
			and int(installation.get("installer_player_index", -1)) == player_index:
			return true
	return false


func _facility_snapshot(facility_id: String) -> Dictionary:
	if facility_id.is_empty() or _controller == null or not _controller.has_method("facilities_snapshot"):
		return {}
	var value: Variant = _controller.call("facilities_snapshot", false)
	if not (value is Array):
		return {}
	for facility_variant in value as Array:
		if facility_variant is Dictionary and str((facility_variant as Dictionary).get("facility_id", "")) == facility_id:
			return (facility_variant as Dictionary).duplicate(true)
	return {}


func _facility_finalize_preflight(facility_receipt: Dictionary) -> Dictionary:
	if _controller == null or not _controller.has_method("facility_action_lifecycle_snapshot"):
		return {"ready": false, "reason_code": "facility_finalize_preflight_unavailable"}
	var transaction_id := str(facility_receipt.get("transaction_id", "")).strip_edges()
	if transaction_id.is_empty() or str(facility_receipt.get("receipt_kind", "")) != "facility_action":
		return {"ready": false, "reason_code": "facility_receipt_binding_invalid", "transaction_id": transaction_id}
	var lifecycle_variant: Variant = _controller.call("facility_action_lifecycle_snapshot", transaction_id)
	var lifecycle: Dictionary = (lifecycle_variant as Dictionary).duplicate(true) if lifecycle_variant is Dictionary else {}
	if lifecycle.is_empty():
		return {"ready": false, "reason_code": "facility_action_transaction_missing", "transaction_id": transaction_id}
	var state := str(lifecycle.get("state", ""))
	if state == "finalized":
		return {"ready": true, "reason_code": "facility_finalize_ready", "transaction_id": transaction_id, "already_finalized": true}
	var original: Dictionary = lifecycle.get("original_receipt", {}) if lifecycle.get("original_receipt", {}) is Dictionary else {}
	if state != "applied" \
		or not bool(lifecycle.get("rollback_open", false)) \
		or str(original.get("transaction_id", "")) != transaction_id \
		or str(original.get("owner_binding_fingerprint", "")) != str(facility_receipt.get("owner_binding_fingerprint", "")) \
		or int(original.get("receipt_sequence", -1)) != int(facility_receipt.get("receipt_sequence", -2)):
		return {"ready": false, "reason_code": "facility_receipt_binding_invalid", "transaction_id": transaction_id}
	return {"ready": true, "reason_code": "facility_finalize_ready", "transaction_id": transaction_id, "already_finalized": false}


func _commodity_finalize_preflight(commodity_receipt: Dictionary) -> Dictionary:
	if _flow_controller == null or not _flow_controller.has_method("commodity_installation_finalize_preflight"):
		return {"ready": false, "reason_code": "commodity_finalize_preflight_unavailable"}
	var value: Variant = _flow_controller.call("commodity_installation_finalize_preflight", commodity_receipt.duplicate(true))
	return (value as Dictionary).duplicate(true) if value is Dictionary else {
		"ready": false,
		"reason_code": "commodity_finalize_preflight_invalid",
	}


func _owner_receipt(receipt: Dictionary) -> Dictionary:
	var nested: Variant = receipt.get("owner_receipt", null)
	if nested is Dictionary:
		return (nested as Dictionary).duplicate(true)
	if not str(receipt.get("receipt_kind", "")).is_empty():
		return receipt.duplicate(true)
	return {}


func _normalized_actor_map(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for actor_variant in source.keys():
		var actor_id := str(actor_variant).strip_edges()
		var player_index := int(source[actor_variant])
		if not actor_id.is_empty() and player_index >= 0:
			result[actor_id] = player_index
	return result
