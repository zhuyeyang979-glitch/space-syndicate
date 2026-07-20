@tool
extends Node
class_name CardTargetChoiceRuntimeController

const KIND_MONSTER := "monster_target_choice"
const KIND_PLAYER := "player_target_choice"
const VALID_KINDS := [KIND_MONSTER, KIND_PLAYER]
const SAVE_SCHEMA_VERSION := 1
const StableTargetEnvelope := preload("res://scripts/runtime/card_resolution_stable_target_envelope.gd")

var _choices: Dictionary = {}
var _next_choice_sequence := 1
var _revision := 0


func reset_state() -> void:
	_choices.clear()
	_next_choice_sequence = 1
	_revision += 1


func begin_choice(
	kind: String,
	player_index: int,
	slot_index: int,
	stable_target_envelope: Dictionary = {},
	source_card_fingerprint: String = ""
) -> Dictionary:
	if kind not in VALID_KINDS or player_index < 0 or slot_index < 0:
		return {"accepted": false, "reason": "target_choice_binding_invalid"}
	if not stable_target_envelope.is_empty():
		var envelope_validation := StableTargetEnvelope.validate(stable_target_envelope)
		if not bool(envelope_validation.get("valid", false)) \
				or str(stable_target_envelope.get("target_kind", "")) != _envelope_target_kind(kind) \
				or not _sha256(source_card_fingerprint):
			return {"accepted": false, "reason": "stable_target_choice_binding_invalid"}
	var choice := {
		"choice_id": "target_choice_%d" % _next_choice_sequence,
		"kind": kind,
		"player_index": player_index,
		"slot_index": slot_index,
		"opened_sequence": _next_choice_sequence,
		"revision": _revision + 1,
	}
	if not stable_target_envelope.is_empty():
		choice["stable_target_envelope"] = stable_target_envelope.duplicate(true)
		choice["source_card_fingerprint"] = source_card_fingerprint
	_next_choice_sequence += 1
	_revision += 1
	_choices[kind] = choice
	return _private_choice_snapshot(choice)


func clear_choice(kind: String) -> Dictionary:
	if kind not in VALID_KINDS or not _choices.has(kind):
		return {"cleared": false, "reason": "target_choice_not_active"}
	var choice := (_choices[kind] as Dictionary).duplicate(true)
	_choices.erase(kind)
	_revision += 1
	return {
		"cleared": true,
		"choice_id": str(choice.get("choice_id", "")),
		"kind": kind,
		"revision": _revision,
	}


func has_choice(kind: String) -> bool:
	return kind in VALID_KINDS and _choices.has(kind)


func choice_snapshot(kind: String) -> Dictionary:
	var choice_variant: Variant = _choices.get(kind, {})
	return _private_choice_snapshot(choice_variant as Dictionary) if choice_variant is Dictionary else {}


func private_snapshot(viewer_index: int) -> Dictionary:
	var result: Dictionary = {}
	for kind in VALID_KINDS:
		var choice := choice_snapshot(kind)
		if not choice.is_empty() and int(choice.get("player_index", -1)) == viewer_index:
			result[kind] = choice
	return {
		"revision": _revision,
		"choices": result,
	}


func forced_decision_candidates() -> Array:
	var result: Array = []
	for kind in VALID_KINDS:
		var choice := choice_snapshot(kind)
		if choice.is_empty():
			continue
		result.append({
			"id": str(choice.get("choice_id", "")),
			"kind": kind,
			"priority_group": "other_choice",
			"owner_player_index": int(choice.get("player_index", -1)),
			"visibility_scope": "private",
			"presentation_surface": "overlay",
			"opened_sequence": float(choice.get("opened_sequence", 0)),
			"blocks_global_time": false,
			"blocks_player_actions": true,
			"blocks_card_resolution": false,
			"source_ref": kind,
			"notes": "Private target selection happens before the card enters the public track.",
		})
	return result


func to_save_data() -> Dictionary:
	var choices: Array = []
	for kind in VALID_KINDS:
		var choice := _save_choice_snapshot(kind)
		if not choice.is_empty():
			choices.append(choice)
	return {
		"card_target_choice_runtime": {
			"schema_version": SAVE_SCHEMA_VERSION,
			"next_choice_sequence": _next_choice_sequence,
			"revision": _revision,
			"choices": choices,
		}
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var payload_variant: Variant = data.get("card_target_choice_runtime", data)
	var payload: Dictionary = payload_variant if payload_variant is Dictionary else {}
	if payload.is_empty():
		reset_state()
		return {"applied": true, "choice_count": 0}
	if int(payload.get("schema_version", 0)) != SAVE_SCHEMA_VERSION or not (payload.get("choices", []) is Array):
		return {"applied": false, "reason": "target_choice_save_invalid"}
	var restored: Dictionary = {}
	var max_sequence := 0
	for choice_variant in payload.get("choices", []):
		if not (choice_variant is Dictionary):
			return {"applied": false, "reason": "target_choice_entry_invalid"}
		var choice := choice_variant as Dictionary
		var kind := str(choice.get("kind", ""))
		var sequence := int(choice.get("opened_sequence", 0))
		if kind not in VALID_KINDS or int(choice.get("player_index", -1)) < 0 or int(choice.get("slot_index", -1)) < 0 or sequence <= 0:
			return {"applied": false, "reason": "target_choice_binding_invalid"}
		var restored_choice := {
			"choice_id": str(choice.get("choice_id", "target_choice_%d" % sequence)),
			"kind": kind,
			"player_index": int(choice.get("player_index", -1)),
			"slot_index": int(choice.get("slot_index", -1)),
			"opened_sequence": sequence,
			"revision": int(choice.get("revision", sequence)),
		}
		restored[kind] = restored_choice
		max_sequence = maxi(max_sequence, sequence)
	_choices = restored
	_next_choice_sequence = maxi(max_sequence + 1, int(payload.get("next_choice_sequence", max_sequence + 1)))
	_revision = maxi(int(payload.get("revision", 0)), max_sequence)
	return {"applied": true, "choice_count": _choices.size()}


func apply_legacy_state(data: Dictionary) -> Dictionary:
	reset_state()
	if int(data.get("pending_target_player_index", -1)) >= 0 and int(data.get("pending_target_slot_index", -1)) >= 0:
		begin_choice(KIND_MONSTER, int(data.get("pending_target_player_index", -1)), int(data.get("pending_target_slot_index", -1)))
	if int(data.get("pending_player_target_player_index", -1)) >= 0 and int(data.get("pending_player_target_slot_index", -1)) >= 0:
		begin_choice(KIND_PLAYER, int(data.get("pending_player_target_player_index", -1)), int(data.get("pending_player_target_slot_index", -1)))
	return {"applied": true, "choice_count": _choices.size()}


func debug_snapshot() -> Dictionary:
	var kinds: Array[String] = []
	for kind in VALID_KINDS:
		if has_choice(kind):
			kinds.append(kind)
	return {
		"controller_authoritative": true,
		"choice_count": kinds.size(),
		"active_kinds": kinds,
		"revision": _revision,
	}


func _private_choice_snapshot(choice: Dictionary) -> Dictionary:
	if choice.is_empty():
		return {}
	var result := {
		"choice_id": str(choice.get("choice_id", "")),
		"kind": str(choice.get("kind", "")),
		"player_index": int(choice.get("player_index", -1)),
		"slot_index": int(choice.get("slot_index", -1)),
		"opened_sequence": int(choice.get("opened_sequence", 0)),
		"revision": int(choice.get("revision", 0)),
	}
	if choice.get("stable_target_envelope", {}) is Dictionary and not (choice.get("stable_target_envelope", {}) as Dictionary).is_empty():
		result["stable_target_envelope"] = (choice.get("stable_target_envelope", {}) as Dictionary).duplicate(true)
		result["source_card_fingerprint"] = str(choice.get("source_card_fingerprint", ""))
	return result


func _save_choice_snapshot(kind: String) -> Dictionary:
	var private_choice := choice_snapshot(kind)
	if private_choice.is_empty():
		return {}
	# Schema v1 predates stable target envelopes. Keep its serialized shape
	# unchanged; a restored in-progress legacy choice must fail closed instead
	# of sampling whatever table focus happens to be current after load.
	private_choice.erase("stable_target_envelope")
	private_choice.erase("source_card_fingerprint")
	return private_choice


func _envelope_target_kind(choice_kind: String) -> String:
	return StableTargetEnvelope.TARGET_MONSTER if choice_kind == KIND_MONSTER else StableTargetEnvelope.TARGET_PLAYER


func _sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true
