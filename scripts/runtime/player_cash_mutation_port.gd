@tool
extends Node
class_name PlayerCashMutationPort

## Typed, actor-scoped cash mutation boundary.
##
## WorldSessionState remains the sole cash/state owner. This port stores no
## balance or transaction journal; it atomically replaces one player record and
## uses that record's existing v06_transaction_ledger for exact-once lineage.
## MonsterWagerCashCommitmentQueryPort remains the only composition boundary
## that can combine cash with unresolved wager commitments.

const CURRENCY_SCALE := 100
const ECONOMY_HISTORY_LIMIT := 24
const ECONOMY_LEDGER_LIMIT := 14
const LEDGER_CATEGORY := "player_cash_mutation_v06"
const MAX_SAFE_UNIT_DELTA := 92233720368547758

var _world_session_state: WorldSessionState
var _cash_commitment_query_port: MonsterWagerCashCommitmentQueryPort
var _mutation_authority: SimulationMutationAuthority
var _commit_count := 0
var _replay_count := 0
var _rejection_count := 0


func configure(
	world_session_state: WorldSessionState,
	cash_commitment_query_port: MonsterWagerCashCommitmentQueryPort,
	mutation_authority: SimulationMutationAuthority
) -> Dictionary:
	_world_session_state = world_session_state
	_cash_commitment_query_port = cash_commitment_query_port
	_mutation_authority = mutation_authority
	return {
		"configured": is_ready(),
		"reason_code": "player_cash_mutation_port_ready" if is_ready() else "player_cash_mutation_dependency_missing",
	}


func is_ready() -> bool:
	return _world_session_state != null and _cash_commitment_query_port != null \
		and _mutation_authority != null


func commit_product_market_cash_delta(
	transaction_id: String,
	player_index: int,
	cash_delta_units: int,
	source_id: String,
	product_id: String,
	reason_code: String,
	income_units: int = 0,
	market_cycle: int = 0
) -> Dictionary:
	if cash_delta_units > MAX_SAFE_UNIT_DELTA or cash_delta_units < -MAX_SAFE_UNIT_DELTA \
			or income_units < 0 or income_units > maxi(0, cash_delta_units):
		return _reject("product_market_cash_terms_invalid", player_index)
	var cash_delta_cents := cash_delta_units * CURRENCY_SCALE
	var income_cents := income_units * CURRENCY_SCALE
	var events: Array[Dictionary] = []
	if income_units > 0:
		events.append(_event("卡牌收入", source_id, income_units, "%s期货收益" % product_id, market_cycle))
	var non_income_units := cash_delta_units - income_units
	if non_income_units != 0:
		events.append(_event("期货保证金", source_id, non_income_units, "%s｜%s" % [product_id, reason_code], market_cycle))
	return _commit_cash_delta(
		transaction_id,
		player_index,
		cash_delta_cents,
		"product_market",
		source_id,
		reason_code,
		income_cents,
		0,
		events
	)


func commit_city_gdp_derivative_cash_delta(
	transaction_id: String,
	player_index: int,
	cash_delta_units: int,
	card_id: String,
	region_id: String,
	region_label: String,
	reason_code: String,
	income_units: int = 0,
	market_cycle: int = 0
) -> Dictionary:
	if cash_delta_units > MAX_SAFE_UNIT_DELTA or cash_delta_units < -MAX_SAFE_UNIT_DELTA \
			or income_units < 0 or income_units > maxi(0, cash_delta_units):
		return _reject("city_gdp_cash_terms_invalid", player_index)
	if region_id.strip_edges().is_empty() or region_label.strip_edges().is_empty():
		return _reject("city_gdp_region_identity_invalid", player_index)
	var cash_delta_cents := cash_delta_units * CURRENCY_SCALE
	var income_cents := income_units * CURRENCY_SCALE
	var events: Array[Dictionary] = []
	if income_units > 0:
		events.append(_event("卡牌收入", card_id, income_units, "%s GDP衍生品收益" % region_label, market_cycle))
	var non_income_units := cash_delta_units - income_units
	if non_income_units != 0:
		events.append(_event("GDP衍生品保证金", card_id, non_income_units, "%s｜%s" % [region_label, reason_code], market_cycle))
	return _commit_cash_delta(
		transaction_id,
		player_index,
		cash_delta_cents,
		"city_gdp_derivative",
		"%s@%s" % [card_id, region_id],
		reason_code,
		income_cents,
		0,
		events
	)


func commit_role_monster_upgrade_cash(
	transaction_id: String,
	player_index: int,
	reward_units: int,
	role_id: String,
	role_label: String,
	monster_uid: int,
	monster_label: String,
	old_rank: int,
	new_rank: int,
	market_cycle: int = 0
) -> Dictionary:
	if reward_units <= 0 or reward_units > MAX_SAFE_UNIT_DELTA:
		return _reject("role_monster_upgrade_reward_invalid", player_index)
	if role_id.strip_edges().is_empty() or role_label.strip_edges().is_empty() or monster_uid <= 0 or monster_label.strip_edges().is_empty():
		return _reject("role_monster_upgrade_identity_invalid", player_index)
	if old_rank < 0 or new_rank <= old_rank:
		return _reject("role_monster_upgrade_rank_invalid", player_index)
	var detail := "%s从%s升至%s" % [monster_label, _roman_rank(old_rank), _roman_rank(new_rank)]
	var events: Array[Dictionary] = [_event("角色收益", role_label, reward_units, detail, market_cycle)]
	return _commit_cash_delta(
		transaction_id,
		player_index,
		reward_units * CURRENCY_SCALE,
		"role_monster_upgrade",
		"%s@monster.%d" % [role_id, monster_uid],
		"monster_rank_upgraded",
		reward_units * CURRENCY_SCALE,
		reward_units * CURRENCY_SCALE,
		events
	)


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"commit_count": _commit_count,
		"replay_count": _replay_count,
		"rejection_count": _rejection_count,
		"stores_cash": false,
		"stores_transaction_journal": false,
		"stores_wager_commitments": false,
		"public_snapshot_provider": false,
		"cash_owner": "WorldSessionState",
		"exact_once_ledger": "WorldSessionState.players[*].v06_transaction_ledger",
		"commitment_owner": "MonsterRuntimeController",
		"simulation_mutation_authority_bound": _mutation_authority != null,
	}


func _commit_cash_delta(
	transaction_id: String,
	player_index: int,
	cash_delta_cents: int,
	mutation_kind: String,
	source_id: String,
	reason_code: String,
	card_income_cents: int,
	role_income_cents: int,
	economic_events: Array[Dictionary]
) -> Dictionary:
	var identity := _validate_identity(transaction_id, player_index, mutation_kind, source_id, reason_code)
	if not bool(identity.get("valid", false)):
		return _reject(str(identity.get("reason_code", "cash_mutation_identity_invalid")), player_index)
	if card_income_cents < 0 or role_income_cents < 0 or role_income_cents > card_income_cents:
		return _reject("cash_income_counters_invalid", player_index)
	if card_income_cents > maxi(0, cash_delta_cents) or card_income_cents % CURRENCY_SCALE != 0 or role_income_cents % CURRENCY_SCALE != 0:
		return _reject("cash_income_counter_scale_invalid", player_index)
	if not _events_are_valid(economic_events):
		return _reject("cash_economic_event_invalid", player_index)
	var player_result := _private_player_record(player_index)
	if not bool(player_result.get("valid", false)):
		return _reject(str(player_result.get("reason_code", "cash_player_invalid")), player_index)
	var player := player_result.get("player", {}) as Dictionary
	var command_fingerprint := _command_fingerprint(
		transaction_id,
		player_index,
		cash_delta_cents,
		mutation_kind,
		source_id,
		reason_code,
		card_income_cents,
		role_income_cents,
		economic_events
	)
	var prior := _prior_transaction(player, transaction_id)
	if bool(prior.get("found", false)):
		if str(prior.get("category", "")) != LEDGER_CATEGORY or str(prior.get("command_fingerprint", "")) != command_fingerprint:
			return _reject("cash_transaction_id_conflict", player_index)
		_replay_count += 1
		return _receipt_from_ledger(prior, true)
	if not is_ready():
		return _reject("player_cash_mutation_port_unavailable", player_index)
	var authority_command := {
		"command_type": "player_cash_mutation",
		"command_id": transaction_id,
		"source": mutation_kind,
	}
	var authority_receipt := _mutation_authority.authorize_mutation(authority_command)
	if not bool(authority_receipt.get("authorized", false)):
		return _reject(str(authority_receipt.get("reason", "cash_mutation_authority_rejected")), player_index)

	var cash_snapshot := _world_session_state.private_player_cash_snapshot(player_index)
	if not bool(cash_snapshot.get("valid", false)):
		return _reject(str(cash_snapshot.get("reason_code", "cash_snapshot_unavailable")), player_index)
	var expected_cash_cents := int(cash_snapshot.get("cash_cents", 0))
	var authorization_fingerprint := ""
	if cash_delta_cents < 0:
		var authorization := _cash_commitment_query_port.authorize_debit_cents(player_index, -cash_delta_cents)
		if not bool(authorization.get("authorized", false)):
			return _reject(str(authorization.get("reason_code", "cash_debit_not_authorized")), player_index)
		expected_cash_cents = int(authorization.get("total_cents", expected_cash_cents))
		authorization_fingerprint = str(authorization.get("availability_fingerprint", ""))

	player_result = _private_player_record(player_index)
	if not bool(player_result.get("valid", false)):
		return _reject(str(player_result.get("reason_code", "cash_player_invalid")), player_index)
	player = player_result.get("player", {}) as Dictionary
	var canonical := WorldSessionState.canonical_private_cash_record(player)
	var cash_before_cents := int(canonical.get("cash_cents", 0))
	if cash_before_cents != expected_cash_cents:
		return _reject("cash_balance_changed", player_index)
	var overflow := _addition_would_overflow(cash_before_cents, cash_delta_cents)
	if overflow:
		return _reject("cash_delta_overflow", player_index)
	var cash_after_cents := cash_before_cents + cash_delta_cents
	if cash_after_cents < 0:
		return _reject("cash_insufficient", player_index)

	var next_player := player.duplicate(true)
	var cash_after_units := floori(float(cash_after_cents) / float(CURRENCY_SCALE))
	next_player["cash_cents"] = cash_after_cents
	next_player["cash"] = cash_after_units
	if card_income_cents > 0:
		next_player["total_card_income"] = int(next_player.get("total_card_income", 0)) \
			+ floori(float(card_income_cents) / float(CURRENCY_SCALE))
	if role_income_cents > 0:
		next_player["total_role_income"] = int(next_player.get("total_role_income", 0)) \
			+ floori(float(role_income_cents) / float(CURRENCY_SCALE))
	_append_cash_history(next_player, cash_after_units)
	_append_economic_events(next_player, economic_events, cash_after_units)
	var ledger_entry := {
		"transaction_id": transaction_id,
		"category": LEDGER_CATEGORY,
		"player_index": player_index,
		"mutation_kind": mutation_kind,
		"command_fingerprint": command_fingerprint,
		"ledger_delta_cents": cash_delta_cents,
		"cash_before_cents": cash_before_cents,
		"cash_after_cents": cash_after_cents,
		"card_income_cents": card_income_cents,
		"role_income_cents": role_income_cents,
		"source_id": source_id,
		"reason_code": reason_code,
		"authorization_fingerprint": authorization_fingerprint,
	}
	var ledger: Array = next_player.get("v06_transaction_ledger", []) if next_player.get("v06_transaction_ledger", []) is Array else []
	ledger.append(ledger_entry)
	next_player["v06_transaction_ledger"] = ledger

	var previous_players := _world_session_state.players.duplicate(true)
	var next_players := previous_players.duplicate(true)
	next_players[player_index] = next_player
	_world_session_state.players = next_players
	var audit_receipt := _mutation_authority.record_mutation(
		authority_command,
		_cash_projection(player_index, player),
		_cash_projection(player_index, next_player),
		{
			"mutation_kind": mutation_kind,
			"cash_delta_cents": cash_delta_cents,
			"transaction_id": transaction_id,
		}
	)
	if not bool(audit_receipt.get("recorded", false)):
		_world_session_state.players = previous_players
		return _reject(str(audit_receipt.get("reason", "cash_mutation_audit_rejected")), player_index)
	_commit_count += 1
	return _receipt_from_ledger(ledger_entry, false)


func _cash_projection(player_index: int, player: Dictionary) -> Dictionary:
	var transaction_ids: Array[String] = []
	var ledger_variant: Variant = player.get("v06_transaction_ledger", [])
	if ledger_variant is Array:
		for row_variant in ledger_variant as Array:
			if row_variant is Dictionary:
				transaction_ids.append(str((row_variant as Dictionary).get("transaction_id", "")))
	return {
		"player_index": player_index,
		"cash_cents": int(player.get("cash_cents", 0)),
		"cash": int(player.get("cash", 0)),
		"total_card_income": int(player.get("total_card_income", 0)),
		"total_role_income": int(player.get("total_role_income", 0)),
		"transaction_ids": transaction_ids,
	}


func _validate_identity(transaction_id: String, player_index: int, mutation_kind: String, source_id: String, reason_code: String) -> Dictionary:
	if transaction_id.is_empty() or transaction_id != transaction_id.strip_edges() or transaction_id.length() > 192:
		return {"valid": false, "reason_code": "cash_transaction_id_invalid"}
	if player_index < 0:
		return {"valid": false, "reason_code": "cash_player_invalid"}
	if mutation_kind.is_empty() or source_id.strip_edges().is_empty() or reason_code.strip_edges().is_empty():
		return {"valid": false, "reason_code": "cash_mutation_identity_invalid"}
	return {"valid": true, "reason_code": "cash_mutation_identity_ready"}


func _private_player_record(player_index: int) -> Dictionary:
	if _world_session_state == null:
		return {"valid": false, "reason_code": "world_session_state_unavailable"}
	var players_variant: Variant = _world_session_state.players
	if not (players_variant is Array):
		return {"valid": false, "reason_code": "cash_players_unavailable"}
	var players := players_variant as Array
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return {"valid": false, "reason_code": "cash_player_invalid"}
	return {"valid": true, "player": (players[player_index] as Dictionary).duplicate(true)}


func _prior_transaction(player: Dictionary, transaction_id: String) -> Dictionary:
	var ledger_variant: Variant = player.get("v06_transaction_ledger", [])
	if not (ledger_variant is Array):
		return {"found": false}
	for row_variant in ledger_variant as Array:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("transaction_id", "")) == transaction_id:
			var result := (row_variant as Dictionary).duplicate(true)
			result["found"] = true
			return result
	return {"found": false}


func _receipt_from_ledger(ledger_entry: Dictionary, replayed: bool) -> Dictionary:
	var before_cents := int(ledger_entry.get("cash_before_cents", 0))
	var after_cents := int(ledger_entry.get("cash_after_cents", before_cents))
	var delta_cents := int(ledger_entry.get("ledger_delta_cents", 0))
	return {
		"committed": true,
		"duplicate": replayed,
		"replayed": replayed,
		"reason": "",
		"reason_code": "cash_mutation_replayed" if replayed else "cash_mutation_committed",
		"transaction_id": str(ledger_entry.get("transaction_id", "")),
		"player_index": int(ledger_entry.get("player_index", -1)),
		"mutation_kind": str(ledger_entry.get("mutation_kind", "")),
		"cash_before": floori(float(before_cents) / float(CURRENCY_SCALE)),
		"cash_after": floori(float(after_cents) / float(CURRENCY_SCALE)),
		"cash_delta": floori(float(delta_cents) / float(CURRENCY_SCALE)),
		"income_amount": floori(float(int(ledger_entry.get("card_income_cents", 0))) / float(CURRENCY_SCALE)),
		"cash_before_cents": before_cents,
		"cash_after_cents": after_cents,
		"cash_delta_cents": delta_cents,
		"command_fingerprint": str(ledger_entry.get("command_fingerprint", "")),
	}


func _reject(reason_code: String, player_index: int) -> Dictionary:
	_rejection_count += 1
	return {
		"committed": false,
		"duplicate": false,
		"replayed": false,
		"reason": reason_code,
		"reason_code": reason_code,
		"player_index": player_index,
	}


func _append_cash_history(player: Dictionary, cash_units: int) -> void:
	var history: Array = player.get("cash_history", []) if player.get("cash_history", []) is Array else []
	if history.is_empty() or int(history.back()) != cash_units:
		history.append(cash_units)
	while history.size() > ECONOMY_HISTORY_LIMIT:
		history.pop_front()
	player["cash_history"] = history


func _append_economic_events(player: Dictionary, events: Array[Dictionary], cash_after_units: int) -> void:
	var ledger: Array = player.get("economic_ledger", []) if player.get("economic_ledger", []) is Array else []
	for event in events:
		var row := event.duplicate(true)
		row["time"] = _world_session_state.game_time if _world_session_state != null else 0.0
		row["cash_after"] = cash_after_units
		ledger.append(row)
	while ledger.size() > ECONOMY_LEDGER_LIMIT:
		ledger.pop_front()
	player["economic_ledger"] = ledger


func _event(kind: String, label: String, amount_units: int, detail: String, cycle: int) -> Dictionary:
	return {
		"cycle": cycle,
		"kind": kind,
		"label": label,
		"amount": amount_units,
		"detail": detail,
	}


func _events_are_valid(events: Array[Dictionary]) -> bool:
	for event in events:
		if str(event.get("kind", "")).strip_edges().is_empty() or str(event.get("label", "")).strip_edges().is_empty():
			return false
		for key_variant in event.keys():
			var value: Variant = event[key_variant]
			if value is Object or value is Callable:
				return false
	return true


func _command_fingerprint(
	transaction_id: String,
	player_index: int,
	cash_delta_cents: int,
	mutation_kind: String,
	source_id: String,
	reason_code: String,
	card_income_cents: int,
	role_income_cents: int,
	events: Array[Dictionary]
) -> String:
	return JSON.stringify({
		"schema_version": 1,
		"transaction_id": transaction_id,
		"player_index": player_index,
		"cash_delta_cents": cash_delta_cents,
		"mutation_kind": mutation_kind,
		"source_id": source_id,
		"reason_code": reason_code,
		"card_income_cents": card_income_cents,
		"role_income_cents": role_income_cents,
		# The market cycle is presentation/history metadata captured at first
		# commit. It must not turn a later retry of the same stable transaction
		# into a conflict after time or a save/load boundary has advanced.
		"events": _stable_event_fingerprint_rows(events),
	}).sha256_text()


func _stable_event_fingerprint_rows(events: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		var row := event.duplicate(true)
		row.erase("cycle")
		result.append(row)
	return result


func _addition_would_overflow(left: int, right: int) -> bool:
	return (right > 0 and left > 9223372036854775807 - right) \
		or (right < 0 and left < -9223372036854775808 - right)


func _roman_rank(rank: int) -> String:
	match rank:
		1: return "I"
		2: return "II"
		3: return "III"
		4: return "IV"
		_: return str(rank)
