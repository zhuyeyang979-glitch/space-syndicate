@tool
extends RefCounted
class_name RuntimeCommandEnvelope

const SCHEMA_VERSION := 1
const TYPE_CARD_RESOLUTION_TRANSITION := &"card_resolution_transition"
const TYPE_MILITARY_MONSTER_DAMAGE := &"military_monster_damage"
const TYPE_MONSTER_MOVE := &"monster_move"
const TYPE_MONSTER_ACTION := &"monster_action"


static func from_card_transition(command: Dictionary) -> Dictionary:
	var command_payload := command.duplicate(true)
	return _from_payload(String(TYPE_CARD_RESOLUTION_TRANSITION), command_payload)


static func from_military_monster_damage(command: Dictionary) -> Dictionary:
	var command_payload := command.duplicate(true)
	var occurred_at_world_us := maxi(1, int(command_payload.get("occurred_at_world_us", 0)))
	var target_uid := int(command_payload.get("target_monster_uid", -1))
	var source_id := str(command_payload.get("source_entity_id", command_payload.get("source", "military")))
	if str(command_payload.get("command_id", "")).is_empty():
		command_payload["command_id"] = "military-monster-damage:%s:%d:%d" % [source_id, target_uid, occurred_at_world_us]
	command_payload["batch_revision"] = occurred_at_world_us
	command_payload["order_index"] = 0
	command_payload["command_fingerprint"] = _payload_fingerprint(command_payload)
	return _from_payload(String(TYPE_MILITARY_MONSTER_DAMAGE), command_payload)


static func from_monster_move(command: Dictionary) -> Dictionary:
	var command_payload := command.duplicate(true)
	var occurred_at_world_us := maxi(1, int(command_payload.get("occurred_at_world_us", 0)))
	var actor_uid := int(command_payload.get("actor_uid", -1))
	var operation := str(command_payload.get("operation", ""))
	var sequence := int(command_payload.get("sequence", 0))
	if str(command_payload.get("command_id", "")).is_empty():
		command_payload["command_id"] = "monster-move:%d:%s:%d:%d" % [actor_uid, operation, occurred_at_world_us, sequence]
	command_payload["batch_revision"] = occurred_at_world_us
	command_payload["order_index"] = 0
	command_payload["command_fingerprint"] = _payload_fingerprint(command_payload)
	return _from_payload(String(TYPE_MONSTER_MOVE), command_payload)


static func from_monster_action(command: Dictionary) -> Dictionary:
	var command_payload := command.duplicate(true)
	var occurred_at_world_us := maxi(1, int(command_payload.get("occurred_at_world_us", 0)))
	var actor_uid := int(command_payload.get("actor_uid", -1))
	var action_index := int(command_payload.get("action_index", -1))
	var sequence := int(command_payload.get("sequence", 0))
	if str(command_payload.get("command_id", "")).is_empty():
		command_payload["command_id"] = "monster-action:%d:%d:%d:%d" % [actor_uid, action_index, occurred_at_world_us, sequence]
	command_payload["batch_revision"] = occurred_at_world_us
	command_payload["order_index"] = 0
	command_payload["command_fingerprint"] = _payload_fingerprint(command_payload)
	return _from_payload(String(TYPE_MONSTER_ACTION), command_payload)


static func validate(envelope: Dictionary) -> Dictionary:
	if not _is_pure_data(envelope):
		return {"valid": false, "reason": "command_contains_runtime_object"}
	if int(envelope.get("schema_version", -1)) != SCHEMA_VERSION:
		return {"valid": false, "reason": "command_schema_unsupported"}
	var command_type := StringName(str(envelope.get("command_type", "")))
	if command_type not in [TYPE_CARD_RESOLUTION_TRANSITION, TYPE_MILITARY_MONSTER_DAMAGE, TYPE_MONSTER_MOVE, TYPE_MONSTER_ACTION]:
		return {"valid": false, "reason": "command_type_unsupported"}
	if str(envelope.get("command_id", "")).is_empty():
		return {"valid": false, "reason": "command_id_missing"}
	if int(envelope.get("producer_revision", -1)) < 0 or int(envelope.get("order_index", -1)) < 0:
		return {"valid": false, "reason": "command_order_invalid"}
	if str(envelope.get("payload_fingerprint", "")).is_empty():
		return {"valid": false, "reason": "command_payload_fingerprint_missing"}
	var payload_variant: Variant = envelope.get("payload", {})
	if not (payload_variant is Dictionary):
		return {"valid": false, "reason": "command_payload_invalid"}
	var payload_dictionary := payload_variant as Dictionary
	if str(payload_dictionary.get("command_id", "")) != str(envelope.get("command_id", "")) \
		or int(payload_dictionary.get("batch_revision", -1)) != int(envelope.get("producer_revision", -1)) \
		or int(payload_dictionary.get("order_index", -1)) != int(envelope.get("order_index", -1)) \
		or str(payload_dictionary.get("command_fingerprint", "")) != str(envelope.get("payload_fingerprint", "")):
		return {"valid": false, "reason": "command_payload_binding_mismatch"}
	if command_type == TYPE_MILITARY_MONSTER_DAMAGE:
		if int(payload_dictionary.get("target_monster_uid", -1)) < 0 \
			or int(payload_dictionary.get("damage", 0)) <= 0 \
			or str(payload_dictionary.get("source", "")).strip_edges().is_empty():
			return {"valid": false, "reason": "military_monster_damage_payload_invalid"}
	if command_type == TYPE_MONSTER_MOVE:
		var operation := str(payload_dictionary.get("operation", ""))
		if int(payload_dictionary.get("actor_uid", -1)) < 0 or not ["start", "advance", "settle", "clear"].has(operation):
			return {"valid": false, "reason": "monster_move_payload_invalid"}
		if operation == "advance" and float(payload_dictionary.get("delta_seconds", 0.0)) <= 0.0:
			return {"valid": false, "reason": "monster_move_delta_invalid"}
	if command_type == TYPE_MONSTER_ACTION:
		if int(payload_dictionary.get("actor_uid", -1)) < 0 or int(payload_dictionary.get("action_index", -1)) < 0:
			return {"valid": false, "reason": "monster_action_payload_invalid"}
		if not (payload_dictionary.get("action", {}) is Dictionary):
			return {"valid": false, "reason": "monster_action_definition_invalid"}
	var expected := _fingerprint(envelope)
	if str(envelope.get("envelope_fingerprint", "")) != expected:
		return {"valid": false, "reason": "command_envelope_fingerprint_mismatch"}
	return {"valid": true, "reason": "", "envelope_fingerprint": expected}


static func extract_payload(envelope: Dictionary) -> Dictionary:
	var value: Variant = envelope.get("payload", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func trace_entry(envelope: Dictionary) -> Dictionary:
	return {
		"schema_version": int(envelope.get("schema_version", -1)),
		"command_type": str(envelope.get("command_type", "")),
		"command_id": str(envelope.get("command_id", "")),
		"producer_revision": int(envelope.get("producer_revision", -1)),
		"order_index": int(envelope.get("order_index", -1)),
		"payload_fingerprint": str(envelope.get("payload_fingerprint", "")),
		"envelope_fingerprint": str(envelope.get("envelope_fingerprint", "")),
	}


static func _fingerprint(envelope: Dictionary) -> String:
	var fingerprint_source := envelope.duplicate(true)
	fingerprint_source.erase("envelope_fingerprint")
	return JSON.stringify(_canonicalize(fingerprint_source)).sha256_text()


static func _from_payload(command_type: String, command_payload: Dictionary) -> Dictionary:
	var envelope := {
		"schema_version": SCHEMA_VERSION,
		"command_type": command_type,
		"command_id": str(command_payload.get("command_id", "")),
		"producer_revision": int(command_payload.get("batch_revision", -1)),
		"order_index": int(command_payload.get("order_index", -1)),
		"payload_fingerprint": str(command_payload.get("command_fingerprint", "")),
		"payload": command_payload,
	}
	envelope["envelope_fingerprint"] = _fingerprint(envelope)
	return envelope


static func _payload_fingerprint(payload: Dictionary) -> String:
	return JSON.stringify(_canonicalize(payload)).sha256_text()


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary := value as Dictionary
		var keys: Array = dictionary.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var result := {}
		for key in keys:
			result[str(key)] = _canonicalize(dictionary.get(key))
		return result
	if value is Array:
		var result: Array = []
		for item in value as Array:
			result.append(_canonicalize(item))
		return result
	return value


static func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if not _is_pure_data(key) or not _is_pure_data((value as Dictionary).get(key)):
				return false
	elif value is Array:
		for item in value as Array:
			if not _is_pure_data(item):
				return false
	return true
