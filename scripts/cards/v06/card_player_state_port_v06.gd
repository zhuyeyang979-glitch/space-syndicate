extends RefCounted
class_name CardPlayerStatePortV06

const DEFAULT_HAND_LIMIT := 5
const COLORED_ASSET_KEYS: Array[String] = [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]

var _players: Dictionary = {}
var _actor_player_indices: Dictionary = {}
var _reservations: Dictionary = {}
var _player_locks: Dictionary = {}
var _inflight_transactions: Dictionary = {}
var _journal: Dictionary = {}
var _reservation_results: Dictionary = {}
var _next_reservation_sequence := 1


func register_player(actor_id: String, initial_state: Dictionary) -> Dictionary:
	var normalized_actor_id := actor_id.strip_edges()
	if normalized_actor_id.is_empty():
		return _setup_reject("actor_id_invalid")
	if _players.has(normalized_actor_id):
		return _setup_reject("player_already_registered")
	var has_player_index := initial_state.has("player_index")
	var player_index := int(initial_state.get("player_index", -1))
	if has_player_index and (player_index < 0 or _actor_player_indices.values().has(player_index)):
		return _setup_reject("player_index_invalid")
	var normalized := _normalize_player_state(normalized_actor_id, initial_state)
	if not bool(normalized.get("valid", false)):
		return _setup_reject(str(normalized.get("reason_code", "player_state_invalid")))
	var candidate_players := _players.duplicate(true)
	candidate_players[normalized_actor_id] = (normalized.get("player_state", {}) as Dictionary).duplicate(true)
	var identity_check := _validate_global_card_instances(candidate_players)
	if not bool(identity_check.get("valid", false)):
		return _setup_reject(str(identity_check.get("reason_code", "card_instance_duplicate_global")))
	_players = candidate_players
	if has_player_index:
		_actor_player_indices[normalized_actor_id] = player_index
	return {
		"configured": true,
		"reason_code": "player_registered",
		"player_state": _player_snapshot(normalized_actor_id),
	}


func read_player(actor_id: String) -> Dictionary:
	var normalized_actor_id := actor_id.strip_edges()
	if normalized_actor_id.is_empty():
		var invalid := _reject("actor_id_invalid")
		invalid["found"] = false
		return invalid
	if not _players.has(normalized_actor_id):
		var missing := _reject("player_missing", {"actor_id": normalized_actor_id})
		missing["found"] = false
		return missing
	return {
		"found": true,
		"reason_code": "player_ready",
		"player_state": _player_snapshot(normalized_actor_id),
	}


func actor_player_indices() -> Dictionary:
	return _actor_player_indices.duplicate(true)


func reserve_transaction(
	transaction_id: String,
	intent_hash: String,
	expected_revisions: Dictionary,
	actor_ids: Array
) -> Dictionary:
	var normalized_transaction_id := transaction_id.strip_edges()
	var normalized_intent_hash := intent_hash.strip_edges()
	if normalized_transaction_id.is_empty():
		return _reject("transaction_id_missing")
	if normalized_intent_hash.is_empty():
		return _reject("intent_hash_missing", {"transaction_id": normalized_transaction_id})
	if _journal.has(normalized_transaction_id):
		return _replay_or_collision(normalized_transaction_id, normalized_intent_hash, true)

	var request := _normalize_reservation_request(expected_revisions, actor_ids)
	if not bool(request.get("valid", false)):
		return _remember_reserve_reject(
			normalized_transaction_id,
			normalized_intent_hash,
			str(request.get("reason_code", "reservation_request_invalid"))
		)
	var normalized_actor_ids: Array = request.get("actor_ids", []) as Array
	var normalized_revisions: Dictionary = request.get("expected_revisions", {}) as Dictionary
	var request_signature := _stable_hash({
		"actor_ids": normalized_actor_ids,
		"expected_revisions": normalized_revisions,
	})

	if _inflight_transactions.has(normalized_transaction_id):
		var inflight: Dictionary = _inflight_transactions.get(normalized_transaction_id, {}) as Dictionary
		if str(inflight.get("intent_hash", "")) != normalized_intent_hash \
		or str(inflight.get("request_signature", "")) != request_signature:
			return _reject("transaction_intent_collision", {
				"transaction_id": normalized_transaction_id,
				"intent_hash": normalized_intent_hash,
			})
		var existing_reservation_id := str(inflight.get("reservation_id", ""))
		if not _reservations.has(existing_reservation_id):
			return _reject("reservation_lost", {
				"transaction_id": normalized_transaction_id,
				"intent_hash": normalized_intent_hash,
			})
		return _reservation_result(
			_reservations.get(existing_reservation_id, {}) as Dictionary,
			true
		)

	for actor_id_variant in normalized_actor_ids:
		var actor_id := str(actor_id_variant)
		if not _players.has(actor_id):
			return _remember_reserve_reject(
				normalized_transaction_id,
				normalized_intent_hash,
				"player_missing",
				{"actor_id": actor_id}
			)
		if _player_locks.has(actor_id):
			return _remember_reserve_reject(
				normalized_transaction_id,
				normalized_intent_hash,
				"player_busy",
				{"actor_id": actor_id}
			)
		var player_state := _player_snapshot(actor_id)
		if int(player_state.get("revision", -1)) != int(normalized_revisions.get(actor_id, -1)):
			return _remember_reserve_reject(
				normalized_transaction_id,
				normalized_intent_hash,
				"player_revision_changed",
				{"actor_id": actor_id}
			)

	var reservation_id := "player-state:%d:%s" % [_next_reservation_sequence, normalized_transaction_id]
	_next_reservation_sequence += 1
	var before_snapshots: Dictionary = {}
	for actor_id_variant in normalized_actor_ids:
		var actor_id := str(actor_id_variant)
		before_snapshots[actor_id] = _player_snapshot(actor_id)
	var reservation := {
		"reservation_id": reservation_id,
		"transaction_id": normalized_transaction_id,
		"intent_hash": normalized_intent_hash,
		"request_signature": request_signature,
		"actor_ids": normalized_actor_ids.duplicate(),
		"expected_revisions": normalized_revisions.duplicate(true),
		"before_snapshots": before_snapshots.duplicate(true),
	}
	_reservations[reservation_id] = reservation.duplicate(true)
	_inflight_transactions[normalized_transaction_id] = {
		"intent_hash": normalized_intent_hash,
		"request_signature": request_signature,
		"reservation_id": reservation_id,
	}
	for actor_id_variant in normalized_actor_ids:
		_player_locks[str(actor_id_variant)] = reservation_id
	return _reservation_result(reservation, false)


func commit_reserved(
	reservation_id: String,
	next_states: Dictionary,
	effect_receipt: Dictionary
) -> Dictionary:
	var normalized_reservation_id := reservation_id.strip_edges()
	if normalized_reservation_id.is_empty():
		return _reject("reservation_id_missing")
	if _reservation_results.has(normalized_reservation_id):
		return _reservation_terminal_replay(normalized_reservation_id)
	if not _reservations.has(normalized_reservation_id):
		return _reject("reservation_missing", {"reservation_id": normalized_reservation_id})
	var reservation: Dictionary = _reservations.get(normalized_reservation_id, {}) as Dictionary
	var transaction_id := str(reservation.get("transaction_id", ""))
	var intent_hash := str(reservation.get("intent_hash", ""))
	var actor_ids: Array = reservation.get("actor_ids", []) as Array
	var expected_revisions: Dictionary = reservation.get("expected_revisions", {}) as Dictionary

	for actor_id_variant in actor_ids:
		var actor_id := str(actor_id_variant)
		if str(_player_locks.get(actor_id, "")) != normalized_reservation_id:
			return _commit_reject(reservation, "reservation_lost", {"actor_id": actor_id})
		if not _players.has(actor_id):
			return _commit_reject(reservation, "player_missing", {"actor_id": actor_id})
		if int((_players.get(actor_id, {}) as Dictionary).get("revision", -1)) != int(expected_revisions.get(actor_id, -1)):
			return _commit_reject(reservation, "player_revision_changed", {"actor_id": actor_id})

	if not bool(effect_receipt.get("committed", false)):
		return _commit_reject(reservation, "effect_not_committed")
	if effect_receipt.has("transaction_id") \
	and str(effect_receipt.get("transaction_id", "")) != transaction_id:
		return _commit_reject(reservation, "effect_receipt_mismatch")
	if effect_receipt.has("intent_hash") \
	and str(effect_receipt.get("intent_hash", "")) != intent_hash:
		return _commit_reject(reservation, "effect_receipt_mismatch")

	var next_by_actor: Dictionary = {}
	for actor_id_variant in next_states.keys():
		var actor_id := str(actor_id_variant).strip_edges()
		if actor_id.is_empty() or next_by_actor.has(actor_id) or not actor_ids.has(actor_id):
			return _commit_reject(reservation, "next_states_mismatch")
		var state_variant: Variant = next_states.get(actor_id_variant)
		if not (state_variant is Dictionary):
			return _commit_reject(reservation, "next_state_invalid", {"actor_id": actor_id})
		next_by_actor[actor_id] = (state_variant as Dictionary).duplicate(true)
	if next_by_actor.size() != actor_ids.size():
		return _commit_reject(reservation, "next_states_mismatch")

	var candidate_players := _players.duplicate(true)
	for actor_id_variant in actor_ids:
		var actor_id := str(actor_id_variant)
		var expected_revision := int(expected_revisions.get(actor_id, -1))
		var proposed: Dictionary = (next_by_actor.get(actor_id, {}) as Dictionary).duplicate(true)
		if proposed.has("actor_id") and str(proposed.get("actor_id", "")) != actor_id:
			return _commit_reject(reservation, "next_state_actor_mismatch", {"actor_id": actor_id})
		if proposed.has("revision"):
			var proposed_revision: Variant = proposed.get("revision")
			if not (proposed_revision is int) \
			or (int(proposed_revision) != expected_revision and int(proposed_revision) != expected_revision + 1):
				return _commit_reject(reservation, "next_state_revision_invalid", {"actor_id": actor_id})
		proposed["actor_id"] = actor_id
		proposed["revision"] = expected_revision + 1
		var normalized := _normalize_player_state(actor_id, proposed)
		if not bool(normalized.get("valid", false)):
			return _commit_reject(
				reservation,
				str(normalized.get("reason_code", "next_state_invalid")),
				{"actor_id": actor_id}
			)
		candidate_players[actor_id] = (normalized.get("player_state", {}) as Dictionary).duplicate(true)

	var identity_check := _validate_global_card_instances(candidate_players)
	if not bool(identity_check.get("valid", false)):
		return _commit_reject(
			reservation,
			str(identity_check.get("reason_code", "card_instance_duplicate_global"))
		)

	_players = candidate_players
	var player_states: Dictionary = {}
	var revision_vector: Dictionary = {}
	for actor_id_variant in actor_ids:
		var actor_id := str(actor_id_variant)
		player_states[actor_id] = _player_snapshot(actor_id)
		revision_vector[actor_id] = int((player_states.get(actor_id, {}) as Dictionary).get("revision", -1))
	var result := {
		"committed": true,
		"reserved": false,
		"reason_code": "committed",
		"reservation_id": normalized_reservation_id,
		"transaction_id": transaction_id,
		"intent_hash": intent_hash,
		"actor_ids": actor_ids.duplicate(),
		"previous_revision_vector": expected_revisions.duplicate(true),
		"revision_vector": revision_vector,
		"player_states": player_states,
		"effect_receipt": effect_receipt.duplicate(true),
		"idempotent_replay": false,
	}
	_release_reservation(reservation)
	_store_terminal_result(reservation, result)
	return result.duplicate(true)


func abort_reserved(
	reservation_id: String,
	reason_code: String = "reservation_aborted"
) -> Dictionary:
	var normalized_reservation_id := reservation_id.strip_edges()
	if normalized_reservation_id.is_empty():
		return _reject("reservation_id_missing")
	if _reservation_results.has(normalized_reservation_id):
		return _reservation_terminal_replay(normalized_reservation_id)
	if not _reservations.has(normalized_reservation_id):
		return _reject("reservation_missing", {"reservation_id": normalized_reservation_id})
	var reservation: Dictionary = _reservations.get(normalized_reservation_id, {}) as Dictionary
	var normalized_reason_code := reason_code.strip_edges()
	if normalized_reason_code.is_empty():
		normalized_reason_code = "reservation_aborted"
	var result := _reject(normalized_reason_code, {
		"aborted": true,
		"reservation_id": normalized_reservation_id,
		"transaction_id": str(reservation.get("transaction_id", "")),
		"intent_hash": str(reservation.get("intent_hash", "")),
		"actor_ids": (reservation.get("actor_ids", []) as Array).duplicate(),
	})
	_release_reservation(reservation)
	_store_terminal_result(reservation, result)
	return result.duplicate(true)


func remember_result(transaction_id: String, intent_hash: String, result: Dictionary) -> Dictionary:
	var normalized_transaction_id := transaction_id.strip_edges()
	var normalized_intent_hash := intent_hash.strip_edges()
	if normalized_transaction_id.is_empty():
		return _reject("transaction_id_missing")
	if normalized_intent_hash.is_empty():
		return _reject("intent_hash_missing", {"transaction_id": normalized_transaction_id})
	if _journal.has(normalized_transaction_id):
		var replay := _replay_or_collision(normalized_transaction_id, normalized_intent_hash, false)
		if str(replay.get("reason_code", "")) == "transaction_intent_collision":
			return replay
		return {
			"remembered": true,
			"reason_code": "result_remembered",
			"transaction_id": normalized_transaction_id,
			"intent_hash": normalized_intent_hash,
			"result": replay,
			"idempotent_replay": true,
		}
	if _inflight_transactions.has(normalized_transaction_id):
		var inflight: Dictionary = _inflight_transactions.get(normalized_transaction_id, {}) as Dictionary
		var inflight_intent_hash := str(inflight.get("intent_hash", ""))
		var inflight_reason := "transaction_in_progress" \
			if inflight_intent_hash == normalized_intent_hash \
			else "transaction_intent_collision"
		return _reject(inflight_reason, {
			"transaction_id": normalized_transaction_id,
			"intent_hash": normalized_intent_hash,
		})
	if result.has("transaction_id") \
	and str(result.get("transaction_id", "")) != normalized_transaction_id:
		return _reject("result_binding_mismatch", {
			"transaction_id": normalized_transaction_id,
			"intent_hash": normalized_intent_hash,
		})
	if result.has("intent_hash") and str(result.get("intent_hash", "")) != normalized_intent_hash:
		return _reject("result_binding_mismatch", {
			"transaction_id": normalized_transaction_id,
			"intent_hash": normalized_intent_hash,
		})
	var saved := result.duplicate(true)
	saved["transaction_id"] = normalized_transaction_id
	saved["intent_hash"] = normalized_intent_hash
	saved["idempotent_replay"] = false
	_journal[normalized_transaction_id] = {
		"intent_hash": normalized_intent_hash,
		"result": saved.duplicate(true),
	}
	return {
		"remembered": true,
		"reason_code": "result_remembered",
		"transaction_id": normalized_transaction_id,
		"intent_hash": normalized_intent_hash,
		"result": saved.duplicate(true),
		"idempotent_replay": false,
	}


func replay_result(transaction_id: String, intent_hash: String) -> Dictionary:
	var normalized_transaction_id := transaction_id.strip_edges()
	var normalized_intent_hash := intent_hash.strip_edges()
	if normalized_transaction_id.is_empty():
		return _reject("transaction_id_missing", {"found": false})
	if normalized_intent_hash.is_empty():
		return _reject("intent_hash_missing", {
			"found": false,
			"transaction_id": normalized_transaction_id,
		})
	if not _journal.has(normalized_transaction_id):
		return _reject("transaction_not_found", {
			"found": false,
			"transaction_id": normalized_transaction_id,
			"intent_hash": normalized_intent_hash,
		})
	return _replay_or_collision(normalized_transaction_id, normalized_intent_hash, false)


func player_feedback(reason_code: String) -> Dictionary:
	var messages := {
		"actor_id_invalid": ["玩家身份无效。", "返回对局并重新选择当前玩家。"],
		"player_already_registered": ["这名玩家已经载入本局。", "读取最新玩家状态，不要重复载入。"],
		"player_state_invalid": ["玩家状态无法载入。", "重新同步手牌、现金和六色资产。"],
		"player_missing": ["当前玩家尚未加入这局游戏。", "重新进入对局或等待玩家同步完成。"],
		"player_revision_changed": ["你的手牌、现金或资产已经发生变化。", "使用最新状态重新确认。"],
		"player_busy": ["相关玩家正在结算另一项操作。", "等待当前结算结束后，用新的操作编号重试。"],
		"cash_invalid": ["现金状态无效。", "重新同步当前现金后再操作。"],
		"assets_invalid": ["六色资产状态无效。", "重新同步六种产业资产后再操作。"],
		"generic_asset_pool_forbidden": ["玩家余额中不能保存通用资产。", "把通用费用分配到六种产业资产后再确认。"],
		"inventory_invalid": ["手牌状态无效。", "重新同步当前手牌后再操作。"],
		"card_instance_id_missing": ["手牌中有一张牌缺少唯一身份。", "等待手牌重新同步后再操作。"],
		"card_instance_duplicate": ["手牌中出现了重复的卡牌实例。", "重新同步手牌并保留每张牌的唯一实例。"],
		"card_instance_duplicate_global": ["不同玩家持有了同一个卡牌实例。", "重新同步所有相关玩家的手牌。"],
		"transaction_id_missing": ["本次操作缺少交易编号。", "重新发起这项操作。"],
		"intent_hash_missing": ["本次操作缺少完整意图。", "重新选择目标并再次确认。"],
		"transaction_in_progress": ["这项操作正在结算。", "等待当前结算结果，不要重复点击。"],
		"transaction_intent_collision": ["同一交易编号对应了不同操作。", "取消旧操作并使用新的交易编号。"],
		"transaction_not_found": ["没有找到这项操作的结算记录。", "同步最新对局状态后重新发起操作。"],
		"reservation_request_invalid": ["本次操作的玩家范围无效。", "重新选择参与这次结算的玩家。"],
		"expected_revisions_invalid": ["玩家状态版本不完整。", "读取所有相关玩家的最新状态后重试。"],
		"reservation_id_missing": ["本次结算缺少预留编号。", "重新发起这项操作。"],
		"reservation_missing": ["这项状态预留已经失效。", "同步最新状态并重新发起操作。"],
		"reservation_lost": ["相关玩家的状态预留已经失效。", "取消当前操作并重新预留。"],
		"reservation_aborted": ["本次结算已取消。", "确认当前状态后可以重新发起操作。"],
		"effect_not_committed": ["卡牌效果尚未成功结算。", "取消本次预留，修正目标后重新操作。"],
		"effect_receipt_mismatch": ["效果凭据与本次操作不一致。", "取消本次预留并重新发起操作。"],
		"next_states_mismatch": ["提交的玩家状态范围不完整。", "同时提交所有已预留玩家的状态。"],
		"next_state_invalid": ["提交后的玩家状态无效。", "重新计算手牌、现金和六色资产后再提交。"],
		"next_state_actor_mismatch": ["提交状态对应了错误的玩家。", "使用预留时的玩家身份重新提交。"],
		"next_state_revision_invalid": ["提交状态的版本不正确。", "从预留快照重新计算，并让系统推进版本。"],
		"result_binding_mismatch": ["结算结果与原操作不一致。", "使用原交易编号和操作意图重新核对。"],
	}
	var pair: Array = messages.get(
		reason_code,
		["当前操作没有完成。", "玩家状态未被消耗，请同步后重新操作。"]
	)
	return {"reason": str(pair[0]), "next_step": str(pair[1])}


func _normalize_reservation_request(expected_revisions: Dictionary, actor_ids: Array) -> Dictionary:
	if actor_ids.is_empty():
		return {"valid": false, "reason_code": "reservation_request_invalid"}
	var normalized_actor_ids: Array[String] = []
	for actor_id_variant in actor_ids:
		var actor_id := str(actor_id_variant).strip_edges()
		if actor_id.is_empty() or normalized_actor_ids.has(actor_id):
			return {"valid": false, "reason_code": "reservation_request_invalid"}
		normalized_actor_ids.append(actor_id)
	normalized_actor_ids.sort()
	var normalized_revisions: Dictionary = {}
	for actor_id_variant in expected_revisions.keys():
		var actor_id := str(actor_id_variant).strip_edges()
		var revision_variant: Variant = expected_revisions.get(actor_id_variant)
		if actor_id.is_empty() or normalized_revisions.has(actor_id) \
		or not (revision_variant is int) or int(revision_variant) < 0:
			return {"valid": false, "reason_code": "expected_revisions_invalid"}
		normalized_revisions[actor_id] = int(revision_variant)
	if normalized_revisions.size() != normalized_actor_ids.size():
		return {"valid": false, "reason_code": "expected_revisions_invalid"}
	for actor_id in normalized_actor_ids:
		if not normalized_revisions.has(actor_id):
			return {"valid": false, "reason_code": "expected_revisions_invalid"}
	return {
		"valid": true,
		"actor_ids": normalized_actor_ids,
		"expected_revisions": normalized_revisions,
	}


func _normalize_player_state(actor_id: String, input_state: Dictionary) -> Dictionary:
	if input_state.has("actor_id") \
	and str(input_state.get("actor_id", "")).strip_edges() != actor_id:
		return {"valid": false, "reason_code": "player_state_invalid"}
	var revision_variant: Variant = input_state.get("revision", 0)
	var cash_variant: Variant = input_state.get("cash", 0)
	var purchase_count_variant: Variant = input_state.get("card_purchase_count", 0)
	var total_spend_variant: Variant = input_state.get("total_card_spend", 0)
	if not (revision_variant is int) or int(revision_variant) < 0:
		return {"valid": false, "reason_code": "player_state_invalid"}
	if not (cash_variant is int) or int(cash_variant) < 0:
		return {"valid": false, "reason_code": "cash_invalid"}
	if not (purchase_count_variant is int) or int(purchase_count_variant) < 0 or not (total_spend_variant is int) or int(total_spend_variant) < 0:
		return {"valid": false, "reason_code": "purchase_ledger_invalid"}

	var assets_variant: Variant = input_state.get("assets", {})
	if not (assets_variant is Dictionary):
		return {"valid": false, "reason_code": "assets_invalid"}
	var input_assets: Dictionary = assets_variant as Dictionary
	for key_variant in input_assets.keys():
		var key := str(key_variant)
		if key == "generic":
			return {"valid": false, "reason_code": "generic_asset_pool_forbidden"}
		if not COLORED_ASSET_KEYS.has(key):
			return {"valid": false, "reason_code": "assets_invalid"}
	var assets: Dictionary = {}
	for key in COLORED_ASSET_KEYS:
		if not input_assets.has(key):
			return {"valid": false, "reason_code": "assets_invalid"}
		var value_variant: Variant = input_assets.get(key)
		if not (value_variant is int) or int(value_variant) < 0:
			return {"valid": false, "reason_code": "assets_invalid"}
		assets[key] = int(value_variant)

	var inventory_variant: Variant = input_state.get("inventory", {})
	if not (inventory_variant is Dictionary):
		return {"valid": false, "reason_code": "inventory_invalid"}
	var input_inventory: Dictionary = inventory_variant as Dictionary
	var hand_limit_variant: Variant = input_inventory.get("hand_limit", DEFAULT_HAND_LIMIT)
	var slots_variant: Variant = input_inventory.get("slots", [])
	if not (hand_limit_variant is int) or int(hand_limit_variant) < 0 \
	or not (slots_variant is Array):
		return {"valid": false, "reason_code": "inventory_invalid"}
	var slots: Array = []
	var local_instance_ids: Dictionary = {}
	for slot_variant in slots_variant as Array:
		if slot_variant == null:
			slots.append(null)
			continue
		if not (slot_variant is Dictionary):
			return {"valid": false, "reason_code": "inventory_invalid"}
		var card := (slot_variant as Dictionary).duplicate(true)
		var instance_id := str(card.get("runtime_instance_id", "")).strip_edges()
		if instance_id.is_empty():
			return {"valid": false, "reason_code": "card_instance_id_missing"}
		if local_instance_ids.has(instance_id):
			return {"valid": false, "reason_code": "card_instance_duplicate"}
		local_instance_ids[instance_id] = true
		slots.append(card)
	var inventory := input_inventory.duplicate(true)
	inventory["hand_limit"] = int(hand_limit_variant)
	inventory["slots"] = slots
	return {
		"valid": true,
		"player_state": {
			"actor_id": actor_id,
			"revision": int(revision_variant),
			"cash": int(cash_variant),
			"card_purchase_count": int(purchase_count_variant),
			"total_card_spend": int(total_spend_variant),
			"assets": assets,
			"inventory": inventory,
		},
	}


func _validate_global_card_instances(players: Dictionary) -> Dictionary:
	var owners: Dictionary = {}
	for actor_id_variant in players.keys():
		var actor_id := str(actor_id_variant)
		var player_state: Dictionary = players.get(actor_id_variant, {}) as Dictionary
		var inventory: Dictionary = player_state.get("inventory", {}) as Dictionary
		var slots: Array = inventory.get("slots", []) as Array
		for slot_variant in slots:
			if not (slot_variant is Dictionary):
				continue
			var instance_id := str((slot_variant as Dictionary).get("runtime_instance_id", ""))
			if owners.has(instance_id):
				return {
					"valid": false,
					"reason_code": "card_instance_duplicate_global",
				}
			owners[instance_id] = actor_id
	return {"valid": true}


func _reservation_result(reservation: Dictionary, idempotent_replay: bool) -> Dictionary:
	return {
		"reserved": true,
		"committed": false,
		"reason_code": "reserved",
		"reservation_id": str(reservation.get("reservation_id", "")),
		"transaction_id": str(reservation.get("transaction_id", "")),
		"intent_hash": str(reservation.get("intent_hash", "")),
		"actor_ids": (reservation.get("actor_ids", []) as Array).duplicate(),
		"expected_revisions": (reservation.get("expected_revisions", {}) as Dictionary).duplicate(true),
		"before_snapshots": (reservation.get("before_snapshots", {}) as Dictionary).duplicate(true),
		"idempotent_replay": idempotent_replay,
	}


func _commit_reject(reservation: Dictionary, reason_code: String, extra: Dictionary = {}) -> Dictionary:
	var details := {
		"reservation_id": str(reservation.get("reservation_id", "")),
		"transaction_id": str(reservation.get("transaction_id", "")),
		"intent_hash": str(reservation.get("intent_hash", "")),
	}
	for key_variant in extra.keys():
		details[key_variant] = extra.get(key_variant)
	return _reject(reason_code, details)


func _remember_reserve_reject(
	transaction_id: String,
	intent_hash: String,
	reason_code: String,
	extra: Dictionary = {}
) -> Dictionary:
	var details := {
		"transaction_id": transaction_id,
		"intent_hash": intent_hash,
	}
	for key_variant in extra.keys():
		details[key_variant] = extra.get(key_variant)
	var result := _reject(reason_code, details)
	_journal[transaction_id] = {
		"intent_hash": intent_hash,
		"result": result.duplicate(true),
	}
	return result


func _release_reservation(reservation: Dictionary) -> void:
	var reservation_id := str(reservation.get("reservation_id", ""))
	for actor_id_variant in reservation.get("actor_ids", []) as Array:
		var actor_id := str(actor_id_variant)
		if str(_player_locks.get(actor_id, "")) == reservation_id:
			_player_locks.erase(actor_id)
	var transaction_id := str(reservation.get("transaction_id", ""))
	var inflight: Dictionary = _inflight_transactions.get(transaction_id, {}) as Dictionary
	if str(inflight.get("reservation_id", "")) == reservation_id:
		_inflight_transactions.erase(transaction_id)
	_reservations.erase(reservation_id)


func _store_terminal_result(reservation: Dictionary, result: Dictionary) -> void:
	var reservation_id := str(reservation.get("reservation_id", ""))
	var transaction_id := str(reservation.get("transaction_id", ""))
	var intent_hash := str(reservation.get("intent_hash", ""))
	var saved := result.duplicate(true)
	saved["idempotent_replay"] = false
	_reservation_results[reservation_id] = saved.duplicate(true)
	_journal[transaction_id] = {
		"intent_hash": intent_hash,
		"result": saved.duplicate(true),
	}


func _reservation_terminal_replay(reservation_id: String) -> Dictionary:
	var replay: Dictionary = (_reservation_results.get(reservation_id, {}) as Dictionary).duplicate(true)
	replay["idempotent_replay"] = true
	replay["replayed"] = true
	return replay


func _replay_or_collision(transaction_id: String, intent_hash: String, from_reserve: bool) -> Dictionary:
	var record: Dictionary = _journal.get(transaction_id, {}) as Dictionary
	if str(record.get("intent_hash", "")) != intent_hash:
		return _reject("transaction_intent_collision", {
			"transaction_id": transaction_id,
			"intent_hash": intent_hash,
		})
	var replay: Dictionary = (record.get("result", {}) as Dictionary).duplicate(true)
	replay["idempotent_replay"] = true
	replay["replayed"] = true
	replay["found"] = true
	if from_reserve:
		replay["handled"] = true
	return replay


func _player_snapshot(actor_id: String) -> Dictionary:
	var state_variant: Variant = _players.get(actor_id, {})
	return (state_variant as Dictionary).duplicate(true) if state_variant is Dictionary else {}


func _setup_reject(reason_code: String) -> Dictionary:
	var result := _reject(reason_code)
	result["configured"] = false
	return result


func _reject(reason_code: String, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"committed": false,
		"reserved": false,
		"reason_code": reason_code,
		"feedback": player_feedback(reason_code),
		"idempotent_replay": false,
	}
	for key_variant in extra.keys():
		result[key_variant] = extra.get(key_variant)
	return result


func _stable_hash(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(_canonicalize(value)).to_utf8_buffer())
	return context.finish().hex_encode()


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key_variant in keys:
			result[str(key_variant)] = _canonicalize((value as Dictionary).get(key_variant))
		return result
	if value is Array:
		var result_array: Array = []
		for item in value as Array:
			result_array.append(_canonicalize(item))
		return result_array
	return value
