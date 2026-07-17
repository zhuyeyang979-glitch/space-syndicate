@tool
extends Node
class_name RuntimeCommandPipeline

var _card_transition_sink: CardResolutionTransitionSink
var _military_monster_damage_sink: MilitaryMonsterDamageCommandSink
var _monster_move_sink: MonsterMoveCommandSink
var _dispatch_batch_count := 0
var _dispatched_command_count := 0
var _rejected_batch_count := 0
var _last_command_trace: Array[Dictionary] = []
var _last_receipt: Dictionary = {}


func bind_card_transition_sink(sink: CardResolutionTransitionSink) -> void:
	_card_transition_sink = sink


func bind_military_monster_damage_sink(sink: MilitaryMonsterDamageCommandSink) -> void:
	_military_monster_damage_sink = sink


func bind_monster_move_sink(sink: MonsterMoveCommandSink) -> void:
	_monster_move_sink = sink


func is_ready() -> bool:
	return is_instance_valid(_card_transition_sink)


func dispatch_card_transition_batch(commands: Array) -> Dictionary:
	_last_command_trace.clear()
	if not is_ready():
		return _reject("card_transition_sink_unavailable")
	var envelopes: Array[Dictionary] = []
	var payloads: Array = []
	var seen_ids := {}
	var producer_revision := -1
	for command_index in range(commands.size()):
		if not (commands[command_index] is Dictionary):
			return _reject("command_not_dictionary", command_index)
		var envelope := RuntimeCommandEnvelope.from_card_transition(commands[command_index] as Dictionary)
		var validation := RuntimeCommandEnvelope.validate(envelope)
		if not bool(validation.get("valid", false)):
			return _reject(str(validation.get("reason", "command_invalid")), command_index)
		var command_id := str(envelope.get("command_id", ""))
		if seen_ids.has(command_id):
			return _reject("duplicate_command_id_in_batch", command_index)
		seen_ids[command_id] = true
		if int(envelope.get("order_index", -1)) != command_index:
			return _reject("non_contiguous_command_order", command_index)
		var revision := int(envelope.get("producer_revision", -1))
		if producer_revision < 0:
			producer_revision = revision
		elif revision != producer_revision:
			return _reject("mixed_command_revision", command_index)
		envelopes.append(envelope)
		payloads.append(RuntimeCommandEnvelope.extract_payload(envelope))
		_last_command_trace.append(RuntimeCommandEnvelope.trace_entry(envelope))
	_dispatch_batch_count += 1
	var sink_receipt := _card_transition_sink.apply_transition_batch(payloads)
	if not bool(sink_receipt.get("handled", false)):
		_rejected_batch_count += 1
		_last_receipt = {
			"handled": false,
			"reason": str(sink_receipt.get("reason", "card_transition_dispatch_rejected")),
			"command_type": String(RuntimeCommandEnvelope.TYPE_CARD_RESOLUTION_TRANSITION),
			"command_count": envelopes.size(),
			"command_trace": _last_command_trace.duplicate(true),
			"sink_receipt": sink_receipt.duplicate(true),
		}
		return _last_receipt.duplicate(true)
	_dispatched_command_count += envelopes.size()
	_last_receipt = {
		"handled": true,
		"reason": str(sink_receipt.get("reason", "")),
		"command_type": String(RuntimeCommandEnvelope.TYPE_CARD_RESOLUTION_TRANSITION),
		"producer_revision": producer_revision,
		"command_count": envelopes.size(),
		"command_trace": _last_command_trace.duplicate(true),
		"sink_receipt": sink_receipt.duplicate(true),
	}
	return _last_receipt.duplicate(true)


func dispatch_military_monster_damage(command: Dictionary) -> Dictionary:
	var saved_trace := _last_command_trace.duplicate(true)
	var saved_receipt := _last_receipt.duplicate(true)
	var result := _dispatch_military_monster_damage_internal(command)
	_last_command_trace = saved_trace
	_last_receipt = saved_receipt
	return result


func dispatch_monster_move(command: Dictionary) -> Dictionary:
	var saved_trace := _last_command_trace.duplicate(true)
	var saved_receipt := _last_receipt.duplicate(true)
	var result := _dispatch_monster_move_internal(command)
	_last_command_trace = saved_trace
	_last_receipt = saved_receipt
	return result


func _dispatch_monster_move_internal(command: Dictionary) -> Dictionary:
	if _monster_move_sink == null:
		return _reject("monster_move_sink_unavailable")
	var envelope := RuntimeCommandEnvelope.from_monster_move(command)
	var validation := RuntimeCommandEnvelope.validate(envelope)
	if not bool(validation.get("valid", false)):
		return _reject(str(validation.get("reason", "monster_move_invalid")))
	_dispatch_batch_count += 1
	var payload := RuntimeCommandEnvelope.extract_payload(envelope)
	var receipt := _monster_move_sink.apply_command(payload, envelope)
	var handled := bool(receipt.get("handled", false))
	if handled:
		_dispatched_command_count += 1
	else:
		_rejected_batch_count += 1
	return {
		"handled": handled,
		"reason": str(receipt.get("reason", "" if handled else "monster_move_rejected")),
		"command_type": String(RuntimeCommandEnvelope.TYPE_MONSTER_MOVE),
		"command_id": str(envelope.get("command_id", "")),
		"command_trace": [RuntimeCommandEnvelope.trace_entry(envelope)],
		"sink_receipt": receipt.duplicate(true) if receipt is Dictionary else {},
	}


func _dispatch_military_monster_damage_internal(command: Dictionary) -> Dictionary:
	if _military_monster_damage_sink == null:
		return _reject("military_monster_damage_sink_unavailable")
	var envelope := RuntimeCommandEnvelope.from_military_monster_damage(command)
	var validation := RuntimeCommandEnvelope.validate(envelope)
	if not bool(validation.get("valid", false)):
		return _reject(str(validation.get("reason", "military_monster_damage_invalid")))
	_dispatch_batch_count += 1
	var payload := RuntimeCommandEnvelope.extract_payload(envelope)
	var receipt := _military_monster_damage_sink.apply_command(payload, envelope)
	var handled := bool(receipt.get("handled", false))
	if handled:
		_dispatched_command_count += 1
	else:
		_rejected_batch_count += 1
	return {
		"handled": handled,
		"reason": str(receipt.get("reason", "" if handled else "military_monster_damage_rejected")),
		"command_type": String(RuntimeCommandEnvelope.TYPE_MILITARY_MONSTER_DAMAGE),
		"command_id": str(envelope.get("command_id", "")),
		"command_trace": [RuntimeCommandEnvelope.trace_entry(envelope)],
		"sink_receipt": receipt.duplicate(true) if receipt is Dictionary else {},
	}


func debug_snapshot() -> Dictionary:
	return {
		"ready": is_ready(),
		"supported_command_types": [String(RuntimeCommandEnvelope.TYPE_CARD_RESOLUTION_TRANSITION), String(RuntimeCommandEnvelope.TYPE_MILITARY_MONSTER_DAMAGE), String(RuntimeCommandEnvelope.TYPE_MONSTER_MOVE)],
		"supported_command_type_count": 3,
		"military_monster_damage_ready": _military_monster_damage_sink != null,
		"monster_move_ready": _monster_move_sink != null,
		"dispatch_batch_count": _dispatch_batch_count,
		"dispatched_command_count": _dispatched_command_count,
		"rejected_batch_count": _rejected_batch_count,
		"pending_command_count": 0,
		"owns_world_state": false,
		"owns_gameplay_rules": false,
		"global_bus": false,
		"autoload": false,
		"last_command_trace": _last_command_trace.duplicate(true),
		"last_receipt": _last_receipt.duplicate(true),
	}


func _reject(reason: String, command_index: int = -1) -> Dictionary:
	_rejected_batch_count += 1
	_last_receipt = {
		"handled": false,
		"reason": reason,
		"command_index": command_index,
		"command_count": 0,
		"command_trace": _last_command_trace.duplicate(true),
	}
	return _last_receipt.duplicate(true)
