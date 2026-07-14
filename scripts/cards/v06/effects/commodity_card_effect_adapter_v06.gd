extends RefCounted
class_name CommodityCardEffectAdapterV06

const SUPPORT := preload("res://scripts/cards/v06/effects/card_effect_adapter_support_v06.gd")
const EXPECTED_EFFECT_KIND := "install_commodity_rate"
const EXPECTED_TARGET_KIND := "same_industry_factory_or_market"
const INDUSTRY_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]

var _flow_controller: Object
var _infrastructure_controller: Object
var _actor_player_indices: Dictionary = {}
var _prepared_by_transaction: Dictionary = {}


func configure(flow_controller: Object, infrastructure_controller: Object, actor_player_indices: Dictionary) -> Dictionary:
	_flow_controller = flow_controller
	_infrastructure_controller = infrastructure_controller
	_actor_player_indices = _normalized_actor_map(actor_player_indices)
	_prepared_by_transaction.clear()
	var configured := (
		_flow_controller != null
		and _flow_controller.has_method("install_commodity")
		and _infrastructure_controller != null
		and _infrastructure_controller.has_method("facilities_snapshot")
		and _infrastructure_controller.has_method("region_snapshot")
		and not _actor_player_indices.is_empty()
	)
	return {"configured": configured, "actor_count": _actor_player_indices.size()}


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
	var commodity_id := str(payload.get("product_id", "")).strip_edges()
	var industry_id := str(payload.get("industry_id", ""))
	if commodity_id.is_empty() or not INDUSTRY_IDS.has(industry_id):
		return SUPPORT.failure_receipt(intent, "commodity_identity_invalid")
	var rank := _rank_from_card_id(str(intent.get("card_id", "")))
	if rank < 1 or rank > 4:
		return SUPPORT.failure_receipt(intent, "commodity_rank_invalid")
	var facility_id := str(target.get("facility_id", target.get("target_id", ""))).strip_edges()
	var facility := _facility_snapshot(facility_id)
	if facility.is_empty() or not bool(facility.get("active", false)):
		return SUPPORT.failure_receipt(intent, "facility_not_active")
	var facility_kind := str(facility.get("facility_type", ""))
	var direction := "production" if facility_kind == "factory" else "demand" if facility_kind == "market" else ""
	if direction.is_empty():
		return SUPPORT.failure_receipt(intent, "commodity_target_direction_invalid")
	if str(facility.get("industry_id", "")) != industry_id:
		return SUPPORT.failure_receipt(intent, "commodity_color_mismatch")
	var target_direction := str(target.get("direction", ""))
	if not target_direction.is_empty() and target_direction != direction:
		return SUPPORT.failure_receipt(intent, "commodity_direction_mismatch")
	var region_id := str(facility.get("region_id", ""))
	var region: Dictionary = _infrastructure_controller.call("region_snapshot", region_id)
	if region.is_empty() or str(region.get("lifecycle_state", "")) == "ruined":
		return SUPPORT.failure_receipt(intent, "commodity_region_unavailable")
	var request := {
		"transaction_id": transaction_id,
		"facility": facility.duplicate(true),
		"facility_id": facility_id,
		"region_id": region_id,
		"region_revision": int(region.get("revision", 0)),
		"commodity_id": commodity_id,
		"direction": direction,
		"installer_player_index": player_index,
		"source_card_rank": rank,
		"color": industry_id,
		"installed_at": float(target.get("game_time", target.get("installed_at", 0.0))),
	}
	var prepared := SUPPORT.prepared_receipt(intent, {
		"adapter_kind": "commodity_v06",
		"prepared_token": SUPPORT.fingerprint({"binding": SUPPORT.binding_from(intent), "request": request, "region_revision": int(region.get("revision", -1))}),
		"owner_request": request,
		"region_revision": int(region.get("revision", -1)),
		"facility_fingerprint": SUPPORT.fingerprint(facility),
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
	var facility := _facility_snapshot(str(request.get("facility_id", "")))
	var region: Dictionary = _infrastructure_controller.call("region_snapshot", str(request.get("region_id", "")))
	if region.is_empty() or int(region.get("revision", -2)) != int(expected.get("region_revision", -1)):
		return SUPPORT.failure_receipt(prepared, "region_revision_changed", "commit")
	if SUPPORT.fingerprint(facility) != str(expected.get("facility_fingerprint", "")):
		return SUPPORT.failure_receipt(prepared, "facility_changed", "commit")
	var owner_variant: Variant = _flow_controller.call("install_commodity", request.duplicate(true))
	if not (owner_variant is Dictionary):
		return SUPPORT.failure_receipt(prepared, "commodity_owner_receipt_invalid", "commit")
	var receipt := SUPPORT.committed_receipt(prepared, owner_variant as Dictionary)
	if bool(receipt.get("committed", false)):
		_prepared_by_transaction.erase(transaction_id)
	return receipt


func abort_prepared_effect(prepared: Dictionary) -> void:
	var transaction_id := str(prepared.get("transaction_id", ""))
	if _prepared_by_transaction.has(transaction_id):
		var expected: Dictionary = _prepared_by_transaction[transaction_id]
		if SUPPORT.binding_matches(expected, prepared):
			_prepared_by_transaction.erase(transaction_id)


func _common_intent_error(intent: Dictionary) -> String:
	if _flow_controller == null or _infrastructure_controller == null:
		return "commodity_owner_unavailable"
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


func _facility_snapshot(facility_id: String) -> Dictionary:
	var facilities_variant: Variant = _infrastructure_controller.call("facilities_snapshot", false)
	if not (facilities_variant is Array):
		return {}
	for facility_variant in facilities_variant as Array:
		if facility_variant is Dictionary and str((facility_variant as Dictionary).get("facility_id", "")) == facility_id:
			return (facility_variant as Dictionary).duplicate(true)
	return {}


func _rank_from_card_id(card_id: String) -> int:
	var marker := ".rank_"
	var marker_position := card_id.rfind(marker)
	if marker_position < 0:
		return 0
	return int(card_id.substr(marker_position + marker.length()))


func _normalized_actor_map(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for actor_variant in source.keys():
		var actor_id := str(actor_variant).strip_edges()
		var player_index := int(source[actor_variant])
		if not actor_id.is_empty() and player_index >= 0:
			result[actor_id] = player_index
	return result
