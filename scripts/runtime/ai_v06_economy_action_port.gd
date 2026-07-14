@tool
extends RefCounted
class_name AiV06EconomyActionPort

const CONTRACT_VERSION := "v0.6-ai-economy-action-port-v1"
const REQUIRED_METHODS: Array[StringName] = [
	&"market_snapshot",
	&"purchase_rank_i_facility",
	&"player_snapshot",
	&"play_runtime_card",
	&"economic_source_snapshot",
]

var _delegate: Object


func bind_delegate(delegate: Object) -> Dictionary:
	_delegate = delegate
	return capability_snapshot()


func capability_snapshot() -> Dictionary:
	var missing: Array[String] = []
	if _delegate == null or not is_instance_valid(_delegate):
		for method_name in REQUIRED_METHODS:
			missing.append(str(method_name))
	else:
		for method_name in REQUIRED_METHODS:
			if not _delegate.has_method(method_name):
				missing.append(str(method_name))
	return {
		"available": missing.is_empty(),
		"revision": 1,
		"reason_code": "ai_v06_economy_port_ready" if missing.is_empty() else "ai_v06_economy_port_capability_missing",
		"contract_version": CONTRACT_VERSION,
		"missing_methods": missing,
	}


func market_snapshot(actor_id: String) -> Dictionary:
	return _call_delegate(&"market_snapshot", [actor_id.strip_edges()], "ai_v06_market_snapshot_unavailable")


func purchase_rank_i_facility(
	actor_id: String,
	item_id: String,
	transaction_id: String,
	expected_market_revision: int,
	expected_player_revision: int,
	expected_source_revision: int
) -> Dictionary:
	return _call_delegate(
		&"purchase_rank_i_facility",
		[
			actor_id.strip_edges(),
			item_id.strip_edges(),
			transaction_id.strip_edges(),
			expected_market_revision,
			expected_player_revision,
			expected_source_revision,
		],
		"ai_v06_facility_purchase_unavailable"
	)


func player_snapshot(actor_id: String) -> Dictionary:
	return _call_delegate(&"player_snapshot", [actor_id.strip_edges()], "ai_v06_player_snapshot_unavailable")


func play_runtime_card(request: Dictionary) -> Dictionary:
	return _call_delegate(&"play_runtime_card", [request.duplicate(true)], "ai_v06_facility_play_unavailable")


func economic_source_snapshot(actor_id: String) -> Dictionary:
	return _call_delegate(&"economic_source_snapshot", [actor_id.strip_edges()], "ai_v06_economic_source_unavailable")


func _call_delegate(method_name: StringName, arguments: Array, unavailable_reason: String) -> Dictionary:
	if _delegate == null or not is_instance_valid(_delegate) or not _delegate.has_method(method_name):
		return _failure(unavailable_reason)
	var value: Variant = _delegate.callv(method_name, arguments)
	if not (value is Dictionary) or not _is_pure_data(value):
		return _failure("ai_v06_economy_port_result_invalid")
	var result := (value as Dictionary).duplicate(true)
	if not result.has("available") or not (result.get("available") is bool):
		return _failure("ai_v06_economy_port_availability_missing")
	if not result.has("revision") or int(result.get("revision", -1)) < 0:
		return _failure("ai_v06_economy_port_revision_missing")
	var reason_code := str(result.get("reason_code", "")).strip_edges()
	if reason_code.is_empty():
		return _failure("ai_v06_economy_port_reason_missing")
	result["reason_code"] = reason_code
	return result


func _failure(reason_code: String) -> Dictionary:
	return {
		"available": false,
		"revision": 0,
		"reason_code": reason_code,
	}


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not _is_pure_data(key_variant) or not _is_pure_data((value as Dictionary).get(key_variant)):
				return false
	elif value is Array:
		for item_variant in value as Array:
			if not _is_pure_data(item_variant):
				return false
	return true
