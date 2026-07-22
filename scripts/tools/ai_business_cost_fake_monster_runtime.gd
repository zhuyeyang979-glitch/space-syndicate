@tool
extends MonsterRuntimeController
class_name AiBusinessCostFakeMonsterRuntime

var qa_reserved_cents_by_player: Dictionary = {}
var _qa_world_session_state: WorldSessionState
var _qa_commitment_revision := 1


func set_qa_world_session_state(state: WorldSessionState) -> void:
	_qa_world_session_state = state


func set_qa_reserved_cents(player_index: int, reserved_cents: int) -> void:
	qa_reserved_cents_by_player[str(player_index)] = maxi(0, reserved_cents)
	_qa_commitment_revision += 1


func private_wager_cash_commitment_snapshot(player_index: int, _excluded_wager_id: int = -1) -> Dictionary:
	if _qa_world_session_state == null or player_index < 0 or player_index >= _qa_world_session_state.players.size():
		return {
			"valid": false,
			"reason_code": "monster_wager_commitment_player_invalid",
			"reserved_cents": 0,
			"commitment_revision": _qa_commitment_revision,
			"commitment_fingerprint": "",
		}
	var reserved_cents := int(qa_reserved_cents_by_player.get(str(player_index), 0))
	var fingerprint := JSON.stringify({
		"player_index": player_index,
		"reserved_cents": reserved_cents,
		"commitment_revision": _qa_commitment_revision,
	}).sha256_text()
	return {
		"valid": true,
		"reason_code": "monster_wager_commitment_ready",
		"reserved_cents": reserved_cents,
		"commitment_revision": _qa_commitment_revision,
		"commitment_fingerprint": fingerprint,
	}


func _district_city(index: int) -> Dictionary:
	if _qa_world_session_state == null or index < 0 or index >= _qa_world_session_state.districts.size():
		return {}
	var district := _qa_world_session_state.districts[index] as Dictionary
	return (district.get("city", {}) as Dictionary).duplicate(true) if district.get("city", {}) is Dictionary else {}


func _city_is_active(city: Dictionary) -> bool:
	return not city.is_empty() and bool(city.get("active", true))


func _district_center(index: int) -> Vector2:
	return Vector2(100.0 + float(index) * 10.0, 100.0)
