@tool
extends Node
class_name AiRuntimeWorldBridge

signal intent_routed(intent: Dictionary, receipt: Dictionary)

var _world: Node
var _rng_service: RunRngService
var _table_selection_state: TableSelectionState
var _world_session_state: WorldSessionState
var _routed_intent_count := 0
var _failed_intent_count := 0


func bind_world(world: Node) -> void:
	_world = world


func set_rng_service(service: RunRngService) -> void:
	_rng_service = service


func set_table_selection_state(state: TableSelectionState) -> void:
	_table_selection_state = state


func set_world_session_state(state: WorldSessionState) -> void:
	_world_session_state = state


func world_session_state() -> WorldSessionState:
	return _world_session_state


func shared_rng() -> RunRngService:
	return _rng_service


func table_selection_state() -> TableSelectionState:
	return _table_selection_state


func has_world() -> bool:
	return _world != null and is_instance_valid(_world)


func read_world_value(property_name: StringName, default_value: Variant = null) -> Variant:
	match property_name:
		&"players":
			return _world_session_state.players if _world_session_state != null else default_value
		&"districts":
			return _world_session_state.districts if _world_session_state != null else default_value
		&"game_time":
			return _world_session_state.game_time if _world_session_state != null else default_value
	if not has_world():
		return default_value
	var value: Variant = _world.get(property_name)
	return default_value if value == null else value


func write_world_value(property_name: StringName, value: Variant) -> bool:
	match property_name:
		&"players":
			if _world_session_state != null and value is Array:
				_world_session_state.players = value
				return true
			return false
		&"districts":
			if _world_session_state != null and value is Array:
				_world_session_state.districts = value
				return true
			return false
		&"game_time":
			if _world_session_state != null:
				_world_session_state.game_time = float(value)
				return true
			return false
	if not has_world():
		return false
	_world.set(property_name, value)
	return true


func read_world_constant(constant_name: StringName, default_value: Variant = null) -> Variant:
	if not has_world() or not _world.has_method("_ai_runtime_world_constant_snapshot"):
		return default_value
	var constants_variant: Variant = _world.call("_ai_runtime_world_constant_snapshot")
	if not (constants_variant is Dictionary):
		return default_value
	return (constants_variant as Dictionary).get(str(constant_name), default_value)


func call_world(method_name: StringName, arguments: Array = []) -> Variant:
	if not has_world() or not _world.has_method(method_name):
		push_error("AiRuntimeWorldBridge cannot route world method: %s" % method_name)
		return null
	return _world.callv(method_name, arguments)


func route_intent(intent: Dictionary) -> Dictionary:
	var normalized := _normalize_intent(intent)
	if normalized.is_empty() or not has_world() or not _world.has_method("_apply_ai_runtime_intent"):
		_failed_intent_count += 1
		return {"applied": false, "reason": "world_or_intent_invalid", "intent_id": str(intent.get("intent_id", ""))}
	var result_variant: Variant = _world.call("_apply_ai_runtime_intent", normalized)
	var receipt: Dictionary = (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {}
	if bool(receipt.get("applied", false)):
		_routed_intent_count += 1
	else:
		_failed_intent_count += 1
	intent_routed.emit(_public_intent(normalized), _public_receipt(receipt))
	return receipt


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": has_world(),
		"rng_service_ready": _rng_service != null,
		"table_selection_state_ready": _table_selection_state != null,
		"world_session_state_ready": _world_session_state != null,
		"city_inference_writes_world_session_owner": true,
		"routed_intent_count": _routed_intent_count,
		"failed_intent_count": _failed_intent_count,
		"owns_ai_state": false,
		"owns_ai_scoring": false,
	}


func _normalize_intent(intent: Dictionary) -> Dictionary:
	if not _is_pure_data(intent):
		return {}
	var action_id := str(intent.get("action_id", ""))
	var player_index := int(intent.get("player_index", -1))
	if action_id == "" or player_index < 0:
		return {}
	return {
		"intent_id": str(intent.get("intent_id", "%s:%d" % [action_id, player_index])),
		"action_id": action_id,
		"player_index": player_index,
		"target_kind": str(intent.get("target_kind", "")),
		"target_index": int(intent.get("target_index", -1)),
		"card_id": str(intent.get("card_id", "")),
		"bid": maxi(0, int(intent.get("bid", 0))),
		"context_revision": int(intent.get("context_revision", -1)),
		"payload": (intent.get("payload", {}) as Dictionary).duplicate(true) if intent.get("payload", {}) is Dictionary else {},
	}


func _public_intent(intent: Dictionary) -> Dictionary:
	return {
		"intent_id": str(intent.get("intent_id", "")),
		"action_id": str(intent.get("action_id", "")),
		"target_kind": str(intent.get("target_kind", "")),
		"target_index": int(intent.get("target_index", -1)),
		"card_id": str(intent.get("card_id", "")),
		"bid": int(intent.get("bid", 0)),
		"context_revision": int(intent.get("context_revision", -1)),
	}


func _public_receipt(receipt: Dictionary) -> Dictionary:
	return {
		"applied": bool(receipt.get("applied", false)),
		"reason": str(receipt.get("reason", "")),
		"intent_id": str(receipt.get("intent_id", "")),
		"action_id": str(receipt.get("action_id", "")),
	}


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key in (value as Dictionary):
			if not _is_pure_data(key) or not _is_pure_data((value as Dictionary)[key]):
				return false
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
	return true
