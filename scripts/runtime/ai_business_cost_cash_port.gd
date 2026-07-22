@tool
extends Node
class_name AiBusinessCostCashPort

const JOURNAL_LIMIT := 256
const CURRENCY_SCALE := WorldSessionState.CASH_CENTS_PER_UNIT

var _world_session_state: WorldSessionState
var _cash_commitment_query_port: MonsterWagerCashCommitmentQueryPort
var _player_cash_mutation_port: PlayerCashMutationPort
var _game_session: GameSessionRuntimeController
var _mutation_authority: SimulationMutationAuthority
var _policy_profile: AiPolicyProfileResource
var _business_action_policy: Dictionary = {}
var _product_market: ProductMarketRuntimeController
var _capability: AiBusinessCostCapability
var _journal: Dictionary = {}
var _journal_order: Array[String] = []
var _journal_session_id := ""
var _commit_count := 0
var _replay_count := 0
var _collision_count := 0
var _rejection_count := 0


func configure(
	world_session_state: WorldSessionState,
	cash_commitment_query_port: MonsterWagerCashCommitmentQueryPort,
	player_cash_mutation_port: PlayerCashMutationPort,
	game_session: GameSessionRuntimeController,
	mutation_authority: SimulationMutationAuthority,
	policy_profile: AiPolicyProfileResource,
	product_market: ProductMarketRuntimeController,
	capability: AiBusinessCostCapability
) -> Dictionary:
	_world_session_state = world_session_state
	_cash_commitment_query_port = cash_commitment_query_port
	_player_cash_mutation_port = player_cash_mutation_port
	_game_session = game_session
	_mutation_authority = mutation_authority
	_policy_profile = policy_profile
	_business_action_policy = policy_profile.business_action_terms().duplicate(true) if policy_profile != null else {}
	_product_market = product_market
	_capability = capability
	var session_id := str(_game_session.session_summary().get("session_id", "")) if _game_session != null else ""
	_ensure_session_scope(session_id)
	return {
		"configured": is_ready(),
		"reason_code": "ai_business_cost_cash_port_ready" if is_ready() else "ai_business_cost_cash_dependency_missing",
	}


func is_ready() -> bool:
	return _world_session_state != null and _cash_commitment_query_port != null \
		and _cash_commitment_query_port.is_ready() and _player_cash_mutation_port != null \
		and _player_cash_mutation_port.is_ready() and _game_session != null \
		and _mutation_authority != null and _policy_profile != null \
		and _business_action_policy_valid(_business_action_policy) \
		and _product_market != null and _capability != null


func private_request_context(capability: AiBusinessCostCapability, player_index: int) -> Dictionary:
	var common := _common_authorization(capability, player_index)
	if not bool(common.get("authorized", false)):
		return common
	var availability := _cash_commitment_query_port.private_cash_availability_snapshot(player_index)
	if not bool(availability.get("valid", false)):
		return _context_failure(str(availability.get("reason_code", "ai_business_cost_cash_availability_invalid")))
	var debit_authorization := _cash_commitment_query_port.authorize_debit_cents(
		player_index,
		authoritative_cost_cents(),
		str(availability.get("availability_fingerprint", ""))
	)
	if not bool(debit_authorization.get("authorized", false)):
		return _context_failure(str(debit_authorization.get("reason_code", "ai_business_cost_cash_not_authorized")))
	var market := _product_market.ai_business_market_pressure_authority_snapshot()
	if not bool(market.get("available", false)) or bool(market.get("recovery_required", false)):
		return _context_failure("ai_business_cost_market_authority_unavailable")
	var session := _game_session.session_summary()
	return {
		"authorized": true,
		"reason_code": "ai_business_cost_request_context_ready",
		"session_id": str(session.get("session_id", "")),
		"session_revision": _game_session.session_start_revision(),
		"business_cycle_revision": int(market.get("market_revision", -1)),
		"simulation_step_index": _mutation_authority.current_step_index(),
		"cost_cents": authoritative_cost_cents(),
		"policy_fingerprint": str(_business_action_policy.get("policy_fingerprint", "")),
		"expected_availability_fingerprint": str(availability.get("availability_fingerprint", "")),
		"available_cents": int(availability.get("available_cents", 0)),
		"market_fingerprint": str(market.get("market_fingerprint", "")),
	}


func authoritative_cost_cents() -> int:
	return maxi(0, int(_business_action_policy.get("cost_units", 0))) * CURRENCY_SCALE


func cached_receipt(
	capability: AiBusinessCostCapability,
	request: AiBusinessCostDebitRequest
) -> AiBusinessCostDebitReceipt:
	var validation := _validate_replay_lookup(capability, request)
	if not bool(validation.get("valid", false)):
		return _rejected(request, str(validation.get("reason_code", "ai_business_cost_request_rejected")))
	_ensure_session_scope(request.session_id)
	if _journal.has(request.request_id):
		var stored := _journal.get(request.request_id) as AiBusinessCostDebitReceipt
		if stored != null and stored.request_fingerprint == request.request_fingerprint:
			_replay_count += 1
			var replay := stored.detached_copy()
			replay.idempotent = true
			replay.changed = false
			return replay
		_collision_count += 1
		return _rejected(request, "ai_business_cost_request_id_collision")
	var owner_status := _player_cash_mutation_port.ai_business_action_cost_transaction_status(request)
	if bool(owner_status.get("found", false)):
		if bool(owner_status.get("collision", false)):
			_collision_count += 1
			return _rejected(request, "ai_business_cost_request_id_collision")
		var replay := _receipt_from_cash(request, owner_status.get("receipt", {}) as Dictionary, {}, true)
		_store_receipt(replay)
		_replay_count += 1
		return replay
	return null


func submit(
	capability: AiBusinessCostCapability,
	request: AiBusinessCostDebitRequest
) -> AiBusinessCostDebitReceipt:
	var cached := cached_receipt(capability, request)
	if cached != null:
		return cached
	var validation := _validate_current_request(capability, request, true)
	if not bool(validation.get("valid", false)):
		return _rejected(request, str(validation.get("reason_code", "ai_business_cost_request_rejected")))
	var authorization := _cash_commitment_query_port.authorize_debit_cents(
		request.player_index,
		request.cost_cents,
		request.expected_availability_fingerprint
	)
	if not bool(authorization.get("authorized", false)):
		return _rejected(request, str(authorization.get("reason_code", "ai_business_cost_cash_not_authorized")))
	var cash_receipt := _player_cash_mutation_port.commit_ai_business_action_cost(request)
	if not bool(cash_receipt.get("committed", false)):
		return _rejected(request, str(cash_receipt.get("reason_code", "ai_business_cost_cash_commit_failed")))
	var receipt := _receipt_from_cash(request, cash_receipt, authorization, bool(cash_receipt.get("replayed", false)))
	_store_receipt(receipt)
	if receipt.idempotent:
		_replay_count += 1
	else:
		_commit_count += 1
	return receipt


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"journal_size": _journal.size(),
		"journal_limit": JOURNAL_LIMIT,
		"commit_count": _commit_count,
		"replay_count": _replay_count,
		"collision_count": _collision_count,
		"rejection_count": _rejection_count,
		"stores_cash": false,
		"stores_wager_commitments": false,
		"owns_save_section": false,
		"public_snapshot_provider": false,
		"capability_bound": _capability != null,
		"cash_owner": "WorldSessionState",
		"commitment_owner": "MonsterRuntimeController",
	}


func _validate_current_request(
	capability: AiBusinessCostCapability,
	request: AiBusinessCostDebitRequest,
	validate_availability: bool
) -> Dictionary:
	if capability == null or capability != _capability:
		return {"valid": false, "reason_code": "ai_business_cost_capability_rejected"}
	if not is_ready():
		return {"valid": false, "reason_code": "ai_business_cost_cash_port_unavailable"}
	if request == null:
		return {"valid": false, "reason_code": "ai_business_cost_request_missing"}
	var report := request.validation_report()
	if not bool(report.get("valid", false)):
		return {"valid": false, "reason_code": str(report.get("reason_code", "ai_business_cost_request_invalid"))}
	var common := _common_authorization(capability, request.player_index)
	if not bool(common.get("authorized", false)):
		return {"valid": false, "reason_code": str(common.get("reason_code", "ai_business_cost_actor_rejected"))}
	var session := _game_session.session_summary()
	if request.session_id != str(session.get("session_id", "")):
		return {"valid": false, "reason_code": "ai_business_cost_session_stale"}
	if request.session_revision != _game_session.session_start_revision():
		return {"valid": false, "reason_code": "ai_business_cost_session_revision_stale"}
	if not _mutation_authority.is_active() or request.simulation_step_index != _mutation_authority.current_step_index():
		return {"valid": false, "reason_code": "ai_business_cost_simulation_step_stale"}
	if request.business_cycle_revision != int(_product_market.ai_business_market_pressure_authority_snapshot().get("market_revision", -1)):
		return {"valid": false, "reason_code": "ai_business_cost_cycle_stale"}
	if request.cost_cents != authoritative_cost_cents() or request.cost_cents <= 0:
		return {"valid": false, "reason_code": "ai_business_cost_policy_mismatch"}
	if request.policy_fingerprint != str(_business_action_policy.get("policy_fingerprint", "")):
		return {"valid": false, "reason_code": "ai_business_cost_policy_revision_mismatch"}
	if validate_availability:
		var authorization := _cash_commitment_query_port.authorize_debit_cents(
			request.player_index,
			request.cost_cents,
			request.expected_availability_fingerprint
		)
		if not bool(authorization.get("authorized", false)):
			return {"valid": false, "reason_code": str(authorization.get("reason_code", "ai_business_cost_cash_not_authorized"))}
	return {"valid": true, "reason_code": "ai_business_cost_request_current"}


func _validate_replay_lookup(
	capability: AiBusinessCostCapability,
	request: AiBusinessCostDebitRequest
) -> Dictionary:
	if capability == null or capability != _capability:
		return {"valid": false, "reason_code": "ai_business_cost_capability_rejected"}
	if not is_ready():
		return {"valid": false, "reason_code": "ai_business_cost_cash_port_unavailable"}
	if request == null:
		return {"valid": false, "reason_code": "ai_business_cost_request_missing"}
	var report := request.validation_report()
	if not bool(report.get("valid", false)):
		return {"valid": false, "reason_code": str(report.get("reason_code", "ai_business_cost_request_invalid"))}
	var session := _game_session.session_summary()
	if request.session_id != str(session.get("session_id", "")):
		return {"valid": false, "reason_code": "ai_business_cost_session_stale"}
	if request.session_revision != _game_session.session_start_revision():
		return {"valid": false, "reason_code": "ai_business_cost_session_revision_stale"}
	return {"valid": true, "reason_code": "ai_business_cost_replay_lookup_ready"}


func _common_authorization(capability: AiBusinessCostCapability, player_index: int) -> Dictionary:
	if capability == null or capability != _capability:
		return _context_failure("ai_business_cost_capability_rejected")
	if not is_ready():
		return _context_failure("ai_business_cost_cash_port_unavailable")
	var session := _game_session.session_summary()
	if str(session.get("session_state", "")) != GameSessionRuntimeController.STATE_RUNNING:
		return _context_failure("ai_business_cost_session_not_running")
	if not _mutation_authority.is_active():
		return _context_failure("ai_business_cost_mutation_step_inactive")
	if player_index < 0 or player_index >= _world_session_state.players.size() \
		or not (_world_session_state.players[player_index] is Dictionary):
		return _context_failure("ai_business_cost_player_invalid")
	var player := _world_session_state.players[player_index] as Dictionary
	if str(player.get("seat_type", "")) != "ai" and not bool(player.get("is_ai", false)):
		return _context_failure("ai_business_cost_human_seat_rejected")
	if bool(player.get("eliminated", false)):
		return _context_failure("ai_business_cost_eliminated_seat_rejected")
	return {"authorized": true, "reason_code": "ai_business_cost_actor_authorized"}


func _receipt_from_cash(
	request: AiBusinessCostDebitRequest,
	cash_receipt: Dictionary,
	authorization: Dictionary,
	idempotent: bool
) -> AiBusinessCostDebitReceipt:
	var result := AiBusinessCostDebitReceipt.new()
	result.request_id = request.request_id
	result.request_fingerprint = request.request_fingerprint
	result.accepted = true
	result.applied = true
	result.changed = not idempotent
	result.idempotent = idempotent
	result.reason_code = "ai_business_cost_replayed" if idempotent else "ai_business_cost_debited"
	result.player_index = request.player_index
	result.debit_cents = request.cost_cents
	result.total_cents_before = int(cash_receipt.get("cash_before_cents", 0))
	result.total_cents_after = int(cash_receipt.get("cash_after_cents", 0))
	result.reserved_cents = int(authorization.get("reserved_cents", cash_receipt.get("reserved_cents", 0)))
	result.available_cents_before = int(authorization.get(
		"available_cents",
		cash_receipt.get("available_cents_before", result.total_cents_before - result.reserved_cents)
	))
	result.available_cents_after = int(cash_receipt.get(
		"available_cents_after",
		maxi(0, result.available_cents_before - request.cost_cents)
	))
	result.availability_fingerprint = request.expected_availability_fingerprint
	result.session_revision = request.session_revision
	result.business_cycle_revision = request.business_cycle_revision
	return result


func _rejected(request: AiBusinessCostDebitRequest, reason_code: String) -> AiBusinessCostDebitReceipt:
	_rejection_count += 1
	var result := AiBusinessCostDebitReceipt.new()
	result.reason_code = reason_code
	if request != null:
		result.request_id = request.request_id
		result.request_fingerprint = request.request_fingerprint
		result.player_index = request.player_index
		result.debit_cents = request.cost_cents
		result.session_revision = request.session_revision
		result.business_cycle_revision = request.business_cycle_revision
	return result


func _store_receipt(receipt: AiBusinessCostDebitReceipt) -> void:
	if receipt == null or receipt.request_id.is_empty():
		return
	if not _journal.has(receipt.request_id):
		_journal_order.append(receipt.request_id)
	_journal[receipt.request_id] = receipt.detached_copy()
	while _journal_order.size() > JOURNAL_LIMIT:
		var expired: String = _journal_order.pop_front()
		_journal.erase(expired)


func _ensure_session_scope(session_id: String) -> void:
	if session_id == _journal_session_id:
		return
	_journal_session_id = session_id
	_journal.clear()
	_journal_order.clear()


func _context_failure(reason_code: String) -> Dictionary:
	return {"authorized": false, "reason_code": reason_code}


func _business_action_policy_valid(terms: Dictionary) -> bool:
	return terms.has("chance_percent") and terms.has("max_per_cycle") and terms.has("cost_units") \
		and int(terms.get("chance_percent", -1)) >= 0 and int(terms.get("chance_percent", -1)) <= 100 \
		and int(terms.get("max_per_cycle", 0)) > 0 \
		and int(terms.get("cost_units", 0)) > 0 \
		and str(terms.get("policy_fingerprint", "")) == _business_action_policy_fingerprint(terms)


func _business_action_policy_fingerprint(terms: Dictionary) -> String:
	return JSON.stringify([
		"ai_business_cost_v1",
		int(terms.get("cost_units", -1)),
	]).sha256_text()
