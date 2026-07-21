@tool
extends Node
class_name MonsterWagerCashCommitmentQueryPort

## Private, read-only cash-availability boundary for unresolved monster wagers.
##
## WorldSessionState remains the only cash balance owner and
## MonsterRuntimeController remains the only wager/commitment owner.  This port
## stores neither.  It combines their current private snapshots so every cash
## consumer applies the same rule: committed wager cash is unavailable to
## ordinary spending, while income remains unrestricted.

const CURRENCY_SCALE := 100

var _world_session_state: WorldSessionState
var _monster_runtime_controller: MonsterRuntimeController
var _query_count := 0
var _authorization_count := 0
var _rejection_count := 0


func configure(
	world_session_state: WorldSessionState,
	monster_runtime_controller: MonsterRuntimeController
) -> Dictionary:
	_world_session_state = world_session_state
	_monster_runtime_controller = monster_runtime_controller
	return {
		"configured": is_ready(),
		"reason_code": "monster_wager_cash_commitment_query_ready" if is_ready() else "monster_wager_cash_commitment_query_dependency_missing",
	}


func is_ready() -> bool:
	return _world_session_state != null and _monster_runtime_controller != null


func private_cash_availability_snapshot(player_index: int) -> Dictionary:
	_query_count += 1
	if not is_ready():
		return _failure(player_index, "monster_wager_cash_commitment_query_unavailable")
	var players_variant: Variant = _world_session_state.players
	if not (players_variant is Array):
		return _failure(player_index, "cash_players_unavailable")
	var players := players_variant as Array
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return _failure(player_index, "cash_player_invalid")
	var cash_snapshot := _world_session_state.private_player_cash_snapshot(player_index)
	if not bool(cash_snapshot.get("valid", false)):
		return _failure(player_index, str(cash_snapshot.get("reason_code", "cash_player_invalid")))
	var total_cents := maxi(0, int(cash_snapshot.get("cash_cents", 0)))
	var commitment := _monster_runtime_controller.private_wager_cash_commitment_snapshot(player_index)
	if not bool(commitment.get("valid", false)):
		return _failure(player_index, str(commitment.get("reason_code", "monster_wager_commitment_snapshot_invalid")))
	var reserved_cents := clampi(int(commitment.get("reserved_cents", 0)), 0, total_cents)
	var result := {
		"valid": true,
		"reason_code": "cash_availability_ready",
		"player_index": player_index,
		"total_cents": total_cents,
		"reserved_cents": reserved_cents,
		"available_cents": total_cents - reserved_cents,
		"commitment_revision": int(commitment.get("commitment_revision", 0)),
		"commitment_fingerprint": str(commitment.get("commitment_fingerprint", "")),
		"currency_fields_consistent": bool(cash_snapshot.get("currency_fields_consistent", false)),
		"used_legacy_unit_reconciliation": bool(cash_snapshot.get("used_legacy_unit_reconciliation", false)),
	}
	result["availability_fingerprint"] = _fingerprint(result)
	return result


func authorize_debit_cents(
	player_index: int,
	debit_cents: int,
	expected_availability_fingerprint: String = ""
) -> Dictionary:
	_authorization_count += 1
	if debit_cents < 0:
		return _reject(player_index, "cash_debit_invalid", {})
	var snapshot := private_cash_availability_snapshot(player_index)
	if not bool(snapshot.get("valid", false)):
		return _reject(player_index, str(snapshot.get("reason_code", "cash_availability_invalid")), snapshot)
	if not expected_availability_fingerprint.is_empty() and expected_availability_fingerprint != str(snapshot.get("availability_fingerprint", "")):
		return _reject(player_index, "cash_availability_changed", snapshot)
	if debit_cents > int(snapshot.get("available_cents", 0)):
		return _reject(player_index, "cash_reserved_for_monster_wager", snapshot)
	var result := snapshot.duplicate(true)
	result["authorized"] = true
	result["reason_code"] = "cash_debit_authorized"
	result["debit_cents"] = debit_cents
	return result


func authorize_debit_units(
	player_index: int,
	debit_units: int,
	expected_availability_fingerprint: String = ""
) -> Dictionary:
	if debit_units < 0 or debit_units > 92233720368547758:
		return _reject(player_index, "cash_debit_invalid", {})
	return authorize_debit_cents(
		player_index,
		debit_units * CURRENCY_SCALE,
		expected_availability_fingerprint
	)


func available_cash_cents(player_index: int) -> int:
	var snapshot := private_cash_availability_snapshot(player_index)
	return int(snapshot.get("available_cents", 0)) if bool(snapshot.get("valid", false)) else 0


func available_cash_units(player_index: int) -> int:
	return floori(float(available_cash_cents(player_index)) / float(CURRENCY_SCALE))


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"query_count": _query_count,
		"authorization_count": _authorization_count,
		"rejection_count": _rejection_count,
		"stores_cash": false,
		"stores_commitments": false,
		"public_snapshot_provider": false,
		"world_session_state_is_cash_owner": true,
		"monster_runtime_is_commitment_owner": true,
	}


func _failure(player_index: int, reason_code: String) -> Dictionary:
	return {
		"valid": false,
		"authorized": false,
		"reason_code": reason_code,
		"player_index": player_index,
		"total_cents": 0,
		"reserved_cents": 0,
		"available_cents": 0,
		"commitment_revision": -1,
		"commitment_fingerprint": "",
		"availability_fingerprint": "",
	}


func _reject(player_index: int, reason_code: String, snapshot: Dictionary) -> Dictionary:
	_rejection_count += 1
	var result := snapshot.duplicate(true) if not snapshot.is_empty() else _failure(player_index, reason_code)
	result["valid"] = bool(snapshot.get("valid", false))
	result["authorized"] = false
	result["reason_code"] = reason_code
	return result


func _fingerprint(snapshot: Dictionary) -> String:
	return JSON.stringify({
		"player_index": int(snapshot.get("player_index", -1)),
		"total_cents": int(snapshot.get("total_cents", 0)),
		"reserved_cents": int(snapshot.get("reserved_cents", 0)),
		"available_cents": int(snapshot.get("available_cents", 0)),
		"commitment_revision": int(snapshot.get("commitment_revision", 0)),
		"commitment_fingerprint": str(snapshot.get("commitment_fingerprint", "")),
	}).sha256_text()
