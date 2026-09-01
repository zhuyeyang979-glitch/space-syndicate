@tool
extends RefCounted
class_name V076AuthorityCommandV1

const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")
const SCHEMA_VERSION := 1
const FIELD_NAMES := [
	"schema_version",
	"command_id",
	"domain_id",
	"command_type",
	"actor_id",
	"scheduled_tick",
	"domain_priority",
	"producer_sequence",
	"payload",
	"payload_sha256",
]


static func build(
	command_id: String,
	domain_id: String,
	command_type: String,
	actor_id: String,
	scheduled_tick: int,
	domain_priority: int,
	producer_sequence: int,
	payload: Dictionary
) -> Dictionary:
	var command := {
		"schema_version": SCHEMA_VERSION,
		"command_id": command_id,
		"domain_id": domain_id,
		"command_type": command_type,
		"actor_id": actor_id,
		"scheduled_tick": scheduled_tick,
		"domain_priority": domain_priority,
		"producer_sequence": producer_sequence,
		"payload": payload.duplicate(true),
		"payload_sha256": StateCodec.fingerprint(payload),
	}
	var validation := validate(command)
	return {
		"accepted": bool(validation.get("valid", false)),
		"reason": str(validation.get("reason", "")),
		"path": str(validation.get("path", "")),
		"command": command if bool(validation.get("valid", false)) else {},
		"command_sha256": fingerprint(command) if bool(validation.get("valid", false)) else "",
	}


static func validate(command: Dictionary) -> Dictionary:
	if command.size() != FIELD_NAMES.size():
		return {"valid": false, "reason": "command_field_count_mismatch", "path": "$"}
	for key_variant in command.keys():
		if typeof(key_variant) != TYPE_STRING or not FIELD_NAMES.has(str(key_variant)):
			return {"valid": false, "reason": "command_unknown_field", "path": "$.%s" % str(key_variant)}
	for required_name in FIELD_NAMES:
		if not command.has(required_name):
			return {"valid": false, "reason": "command_required_field_missing", "path": "$.%s" % required_name}
	if typeof(command.get("schema_version")) != TYPE_INT or int(command.get("schema_version", 0)) != SCHEMA_VERSION:
		return {"valid": false, "reason": "command_schema_mismatch", "path": "$.schema_version"}
	for string_field in ["command_id", "domain_id", "command_type", "actor_id"]:
		if typeof(command.get(string_field)) != TYPE_STRING or str(command.get(string_field, "")).is_empty():
			return {"valid": false, "reason": "command_string_field_invalid", "path": "$.%s" % string_field}
	for integer_field in ["scheduled_tick", "domain_priority", "producer_sequence"]:
		if typeof(command.get(integer_field)) != TYPE_INT:
			return {"valid": false, "reason": "command_integer_field_invalid", "path": "$.%s" % integer_field}
	if int(command.get("scheduled_tick", 0)) < 1:
		return {"valid": false, "reason": "command_tick_invalid", "path": "$.scheduled_tick"}
	if int(command.get("producer_sequence", -1)) < 0:
		return {"valid": false, "reason": "producer_sequence_invalid", "path": "$.producer_sequence"}
	if not (command.get("payload") is Dictionary):
		return {"valid": false, "reason": "command_payload_not_dictionary", "path": "$.payload"}
	var payload_validation := StateCodec.validate(command.get("payload"), "$.payload")
	if not bool(payload_validation.get("valid", false)):
		return payload_validation
	if typeof(command.get("payload_sha256")) != TYPE_STRING or str(command.get("payload_sha256", "")).is_empty():
		return {"valid": false, "reason": "command_payload_hash_type_invalid", "path": "$.payload_sha256"}
	var expected_payload_sha := StateCodec.fingerprint(command.get("payload"))
	if expected_payload_sha.is_empty() or str(command.get("payload_sha256", "")) != expected_payload_sha:
		return {"valid": false, "reason": "command_payload_hash_mismatch", "path": "$.payload_sha256"}
	var envelope_validation := StateCodec.validate(command)
	if not bool(envelope_validation.get("valid", false)):
		return envelope_validation
	return {"valid": true, "reason": "", "path": ""}


static func fingerprint(command: Dictionary) -> String:
	return StateCodec.fingerprint(command)


static func less_than(left: Dictionary, right: Dictionary) -> bool:
	for integer_field in ["scheduled_tick", "domain_priority"]:
		var left_int := int(left.get(integer_field, 0))
		var right_int := int(right.get(integer_field, 0))
		if left_int != right_int:
			return left_int < right_int
	for string_field in ["domain_id", "actor_id"]:
		var left_string := str(left.get(string_field, ""))
		var right_string := str(right.get(string_field, ""))
		if left_string != right_string:
			return left_string < right_string
	var left_producer := int(left.get("producer_sequence", 0))
	var right_producer := int(right.get("producer_sequence", 0))
	if left_producer != right_producer:
		return left_producer < right_producer
	return str(left.get("command_id", "")) < str(right.get("command_id", ""))
