@tool
extends Node
class_name CardCooldownRuntimeController

var _world_session: WorldSessionState
var _configured := false
var _advance_count := 0
var _mutation_revision := 0
var _last_receipt: Dictionary = {}


func configure(world_session: WorldSessionState) -> void:
	_world_session = world_session
	_configured = _world_session != null


func advance_world(delta: float) -> Dictionary:
	var step := maxf(0.0, delta)
	if not _configured:
		return _receipt(false, "world_session_unavailable", 0, 0)
	var player_cooldowns_changed := 0
	var card_cooldowns_changed := 0
	for player_variant in _world_session.players:
		if not (player_variant is Dictionary):
			continue
		var player := player_variant as Dictionary
		var action_before := maxf(0.0, float(player.get("action_cooldown", 0.0)))
		var action_after := maxf(0.0, action_before - step)
		if not is_equal_approx(action_before, action_after):
			player_cooldowns_changed += 1
		player["action_cooldown"] = action_after
		var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
		for slot_variant in slots:
			if not (slot_variant is Dictionary):
				continue
			var skill := slot_variant as Dictionary
			for field in ["cooldown_left", "lock_left"]:
				var before := maxf(0.0, float(skill.get(field, 0.0)))
				var after := maxf(0.0, before - step)
				if not is_equal_approx(before, after):
					card_cooldowns_changed += 1
				skill[field] = after
	_advance_count += 1
	if player_cooldowns_changed > 0 or card_cooldowns_changed > 0:
		_mutation_revision += 1
	return _receipt(true, "", player_cooldowns_changed, card_cooldowns_changed)


func arm_player_action(player_index: int, seconds: float) -> Dictionary:
	if not _valid_player(player_index):
		return {"armed": false, "reason": "invalid_player"}
	var player := _world_session.players[player_index] as Dictionary
	var before := maxf(0.0, float(player.get("action_cooldown", 0.0)))
	var after := maxf(before, maxf(0.0, seconds))
	player["action_cooldown"] = after
	if not is_equal_approx(before, after):
		_mutation_revision += 1
	return {"armed": true, "reason": "", "changed": not is_equal_approx(before, after), "revision": _mutation_revision}


func arm_persistent_card(player_index: int, slot_index: int, expected_runtime_instance_id: String, seconds: float) -> Dictionary:
	if not _valid_player(player_index):
		return {"armed": false, "reason": "invalid_player"}
	var player := _world_session.players[player_index] as Dictionary
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return {"armed": false, "reason": "invalid_slot"}
	var skill := slots[slot_index] as Dictionary
	var actual_runtime_instance_id := str(skill.get("runtime_instance_id", ""))
	if not expected_runtime_instance_id.is_empty() and actual_runtime_instance_id != expected_runtime_instance_id:
		return {"armed": false, "reason": "runtime_instance_mismatch"}
	var before := maxf(0.0, float(skill.get("cooldown_left", 0.0)))
	var after := maxf(before, maxf(0.0, seconds))
	skill["cooldown_left"] = after
	if not is_equal_approx(before, after):
		_mutation_revision += 1
	return {"armed": true, "reason": "", "changed": not is_equal_approx(before, after), "revision": _mutation_revision}


func debug_snapshot() -> Dictionary:
	return {
		"controller_authoritative": _configured,
		"advance_count": _advance_count,
		"mutation_revision": _mutation_revision,
		"last_player_cooldowns_changed": int(_last_receipt.get("player_cooldowns_changed", 0)),
		"last_card_cooldowns_changed": int(_last_receipt.get("card_cooldowns_changed", 0)),
		"owns_save_schema": false,
	}


func _valid_player(player_index: int) -> bool:
	return _configured and player_index >= 0 and player_index < _world_session.players.size() and _world_session.players[player_index] is Dictionary


func _receipt(advanced: bool, reason: String, player_count: int, card_count: int) -> Dictionary:
	_last_receipt = {
		"advanced": advanced,
		"reason": reason,
		"player_cooldowns_changed": player_count,
		"card_cooldowns_changed": card_count,
		"revision": _mutation_revision,
	}
	return _last_receipt.duplicate()
