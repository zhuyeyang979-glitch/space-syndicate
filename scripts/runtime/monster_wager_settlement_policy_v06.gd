extends RefCounted
class_name MonsterWagerSettlementPolicyV06

const SCHEMA_VERSION := 1
const POLICY_ID := "monster_wager_settlement_policy_v06"
const WINDOW_DURATION_SECONDS := 15
const MIN_BASE_RATE_BP := 500
const MAX_BASE_RATE_BP := 1000
const RATE_INCREMENT_BP := 100
const MAX_FINAL_RATE_BP := 2000
const BASIS_POINTS_DENOMINATOR := 10000
const MAX_INT64 := 9223372036854775807
const PUBLIC_RECEIPT_KEYS := [
	"schema_version", "policy_id", "wager_id", "revision", "outcome_kind",
	"base_rate_bp", "competitors", "participants", "historical_public_pool",
	"current_stake_total", "matching_money", "settlement_pool",
	"winning_side_ids", "maximum_effective_damage", "remaining_bonus",
	"remaining_bonus_each", "public_pool_after", "payout_total", "fingerprint",
]


static func fingerprint_for_snapshot(snapshot: Dictionary) -> String:
	if not _is_pure_data(snapshot):
		return ""
	return _stable_fingerprint(_fingerprint_payload(snapshot))


static func is_sha256(value: String) -> bool:
	return _is_sha256(value)


static func public_receipt_is_valid(receipt: Dictionary, expected_wager_id: String, expected_revision: int) -> bool:
	if not _is_pure_data(receipt) or not _has_exact_keys(receipt, PUBLIC_RECEIPT_KEYS):
		return false
	if int(receipt.get("schema_version", -1)) != SCHEMA_VERSION or str(receipt.get("policy_id", "")) != POLICY_ID:
		return false
	if str(receipt.get("wager_id", "")) != expected_wager_id or int(receipt.get("revision", -1)) != expected_revision:
		return false
	var fingerprint := str(receipt.get("fingerprint", ""))
	if not _is_sha256(fingerprint):
		return false
	var payload := receipt.duplicate(true)
	payload.erase("fingerprint")
	return fingerprint == _stable_fingerprint(payload)


static func stake_for_cash(exact_cash: int, rate_bp: int) -> Dictionary:
	# This is the single production arithmetic entry for wager commitments.  The
	# runtime owner uses it for previews and settlement, so UI and gameplay can
	# never drift on rounding or the positive-cash minimum.
	return _stake_for_cash(exact_cash, rate_bp).duplicate(true)


static func complete_timeout_commitments(snapshot: Dictionary) -> Dictionary:
	# Timeout selection is part of the settlement policy, but the runtime owner
	# materializes these commitments before resolving the pending attack. This
	# lets monster-owner cash loss respect every frozen wager commitment without
	# duplicating the deterministic least-staked-side rule in the controller.
	var validation := _validate_snapshot(snapshot)
	if not bool(validation.get("valid", false)):
		return _failure(snapshot, str(validation.get("reason_code", "snapshot_invalid")))
	var competitors: Array = validation.get("competitors", []) as Array
	var participants: Array = validation.get("participants", []) as Array
	var side_totals: Dictionary = {}
	for competitor_variant: Variant in competitors:
		side_totals[str((competitor_variant as Dictionary).get("side_id", ""))] = 0
	var prepared_participants: Array = []
	var total_stakes := 0
	for participant_variant: Variant in participants:
		var participant := participant_variant as Dictionary
		var stake_result := _stake_for_cash(int(participant.get("exact_cash", 0)), int(participant.get("rate_bp", 0)))
		if not bool(stake_result.get("ok", false)):
			return _failure(snapshot, str(stake_result.get("reason_code", "stake_calculation_failed")))
		var stake := int(stake_result.get("stake", 0))
		var sum_result := _safe_add(total_stakes, stake)
		if not bool(sum_result.get("ok", false)):
			return _failure(snapshot, "stake_sum_overflow")
		total_stakes = int(sum_result.get("value", 0))
		var prepared := {
			"public_player_id": str(participant.get("public_player_id", "")),
			"responded": bool(participant.get("responded", false)),
			"auto_selected": false,
			"selected_side_id": str(participant.get("selected_side_id", "")),
			"rate_bp": int(participant.get("rate_bp", 0)),
			"stake": stake,
			"winner": false,
			"payout": 0,
			"remaining_bonus_share": 0,
		}
		prepared_participants.append(prepared)
		if bool(prepared.get("responded", false)):
			var side_id := str(prepared.get("selected_side_id", ""))
			var side_sum_result := _safe_add(int(side_totals.get(side_id, 0)), stake)
			if not bool(side_sum_result.get("ok", false)):
				return _failure(snapshot, "side_stake_total_overflow")
			side_totals[side_id] = int(side_sum_result.get("value", 0))

	# Missing responses resolve in stable public-player order. Each assignment is
	# included before resolving the next missing response.
	for participant_index in range(prepared_participants.size()):
		var prepared := prepared_participants[participant_index] as Dictionary
		if bool(prepared.get("responded", false)):
			continue
		var selected_side_id := _least_staked_side(side_totals)
		prepared["selected_side_id"] = selected_side_id
		prepared["auto_selected"] = true
		prepared_participants[participant_index] = prepared
		var auto_sum_result := _safe_add(int(side_totals.get(selected_side_id, 0)), int(prepared.get("stake", 0)))
		if not bool(auto_sum_result.get("ok", false)):
			return _failure(snapshot, "side_stake_total_overflow")
		side_totals[selected_side_id] = int(auto_sum_result.get("value", 0))
	return {
		"ok": true,
		"reason_code": "timeout_commitments_ready",
		"schema_version": SCHEMA_VERSION,
		"wager_id": str(snapshot.get("wager_id", "")),
		"revision": int(snapshot.get("revision", -1)),
		"fingerprint": str(snapshot.get("fingerprint", "")),
		"competitors": competitors.duplicate(true),
		"participants": prepared_participants,
		"side_totals": side_totals,
		"total_stakes": total_stakes,
	}


static func settle(snapshot: Dictionary) -> Dictionary:
	var commitments := complete_timeout_commitments(snapshot)
	if not bool(commitments.get("ok", false)):
		return commitments

	var wager_id := str(snapshot.get("wager_id", ""))
	var revision := int(snapshot.get("revision", -1))
	var private_fingerprint := str(snapshot.get("fingerprint", ""))
	var historical_public_pool := int(snapshot.get("historical_public_pool", 0))
	var base_rate_bp := int(snapshot.get("base_rate_bp", 0))
	var competitors: Array = (commitments.get("competitors", []) as Array).duplicate(true)
	var prepared_participants: Array = (commitments.get("participants", []) as Array).duplicate(true)
	var side_totals: Dictionary = (commitments.get("side_totals", {}) as Dictionary).duplicate(true)
	var total_stakes := int(commitments.get("total_stakes", 0))

	var maximum_effective_damage := 0
	for competitor_variant: Variant in competitors:
		maximum_effective_damage = maxi(maximum_effective_damage, int((competitor_variant as Dictionary).get("effective_damage", 0)))
	var winning_side_ids: Array = []
	if maximum_effective_damage > 0:
		for competitor_variant: Variant in competitors:
			var competitor := competitor_variant as Dictionary
			if int(competitor.get("effective_damage", 0)) == maximum_effective_damage:
				winning_side_ids.append(str(competitor.get("side_id", "")))

	var outcome_kind := "void_no_effective_damage"
	var matching_money := 0
	var settlement_pool := historical_public_pool
	var remaining_bonus := 0
	var remaining_bonus_each := 0
	var public_pool_after := historical_public_pool
	var winner_indices: Array = []
	if maximum_effective_damage <= 0:
		var void_pool_result := _safe_add(historical_public_pool, total_stakes)
		if not bool(void_pool_result.get("ok", false)):
			return _failure(snapshot, "void_pool_overflow")
		settlement_pool = int(void_pool_result.get("value", 0))
		for participant_index in range(prepared_participants.size()):
			var prepared := prepared_participants[participant_index] as Dictionary
			prepared["payout"] = int(prepared.get("stake", 0))
			prepared_participants[participant_index] = prepared
	else:
		var doubled_stakes_result := _safe_double(total_stakes)
		if not bool(doubled_stakes_result.get("ok", false)):
			return _failure(snapshot, "matching_money_overflow")
		matching_money = total_stakes
		var pool_result := _safe_add(historical_public_pool, int(doubled_stakes_result.get("value", 0)))
		if not bool(pool_result.get("ok", false)):
			return _failure(snapshot, "settlement_pool_overflow")
		settlement_pool = int(pool_result.get("value", 0))
		for participant_index in range(prepared_participants.size()):
			var prepared := prepared_participants[participant_index] as Dictionary
			if winning_side_ids.has(str(prepared.get("selected_side_id", ""))):
				winner_indices.append(participant_index)
		if winner_indices.is_empty():
			outcome_kind = "rolled_to_public_pool_no_winner"
			public_pool_after = settlement_pool
		else:
			outcome_kind = "settled_with_winners"
			var winner_double_total := 0
			for participant_index_variant: Variant in winner_indices:
				var participant_index := int(participant_index_variant)
				var prepared := prepared_participants[participant_index] as Dictionary
				var double_result := _safe_double(int(prepared.get("stake", 0)))
				if not bool(double_result.get("ok", false)):
					return _failure(snapshot, "winner_double_overflow")
				var double_stake := int(double_result.get("value", 0))
				var winner_sum_result := _safe_add(winner_double_total, double_stake)
				if not bool(winner_sum_result.get("ok", false)):
					return _failure(snapshot, "winner_double_total_overflow")
				winner_double_total = int(winner_sum_result.get("value", 0))
				prepared["winner"] = true
				prepared["payout"] = double_stake
				prepared_participants[participant_index] = prepared
			if winner_double_total > settlement_pool:
				return _failure(snapshot, "winner_double_exceeds_pool")
			remaining_bonus = settlement_pool - winner_double_total
			remaining_bonus_each = remaining_bonus / winner_indices.size()
			public_pool_after = remaining_bonus % winner_indices.size()
			for participant_index_variant: Variant in winner_indices:
				var participant_index := int(participant_index_variant)
				var prepared := prepared_participants[participant_index] as Dictionary
				var payout_result := _safe_add(int(prepared.get("payout", 0)), remaining_bonus_each)
				if not bool(payout_result.get("ok", false)):
					return _failure(snapshot, "winner_payout_overflow")
				prepared["remaining_bonus_share"] = remaining_bonus_each
				prepared["payout"] = int(payout_result.get("value", 0))
				prepared_participants[participant_index] = prepared

	var private_rows: Array = []
	var public_rows: Array = []
	var payout_total := 0
	for participant_variant: Variant in prepared_participants:
		var prepared := participant_variant as Dictionary
		var payout := int(prepared.get("payout", 0))
		var payout_sum_result := _safe_add(payout_total, payout)
		if not bool(payout_sum_result.get("ok", false)):
			return _failure(snapshot, "payout_total_overflow")
		payout_total = int(payout_sum_result.get("value", 0))
		var stake := int(prepared.get("stake", 0))
		private_rows.append({
			"public_player_id": str(prepared.get("public_player_id", "")),
			"selected_side_id": str(prepared.get("selected_side_id", "")),
			"responded": bool(prepared.get("responded", false)),
			"auto_selected": bool(prepared.get("auto_selected", false)),
			"rate_bp": int(prepared.get("rate_bp", 0)),
			"stake": stake,
			"stake_cash_delta": -stake,
			"payout": payout,
			"payout_cash_delta": payout,
			"net_cash_delta": payout - stake,
			"winner": bool(prepared.get("winner", false)),
			"remaining_bonus_share": int(prepared.get("remaining_bonus_share", 0)),
		})
		public_rows.append({
			"public_player_id": str(prepared.get("public_player_id", "")),
			"selected_side_id": str(prepared.get("selected_side_id", "")),
			"responded": bool(prepared.get("responded", false)),
			"auto_selected": bool(prepared.get("auto_selected", false)),
			"rate_bp": int(prepared.get("rate_bp", 0)),
			"stake": stake,
			"winner": bool(prepared.get("winner", false)),
			"payout": payout,
		})

	var conserved_result := _safe_add(payout_total, public_pool_after)
	if not bool(conserved_result.get("ok", false)) or int(conserved_result.get("value", -1)) != settlement_pool:
		return _failure(snapshot, "settlement_conservation_failed")

	var competitor_rows: Array = []
	for competitor_variant: Variant in competitors:
		var competitor := competitor_variant as Dictionary
		var side_id := str(competitor.get("side_id", ""))
		competitor_rows.append({
			"side_id": side_id,
			"effective_damage": int(competitor.get("effective_damage", 0)),
			"total_stake": int(side_totals.get(side_id, 0)),
		})

	var private_delta_receipt := {
		"schema_version": SCHEMA_VERSION,
		"policy_id": POLICY_ID,
		"wager_id": wager_id,
		"revision": revision,
		"fingerprint": private_fingerprint,
		"outcome_kind": outcome_kind,
		"base_rate_bp": base_rate_bp,
		"historical_public_pool": historical_public_pool,
		"current_stake_total": total_stakes,
		"matching_money": matching_money,
		"settlement_pool": settlement_pool,
		"winning_side_ids": winning_side_ids,
		"maximum_effective_damage": maximum_effective_damage,
		"remaining_bonus": remaining_bonus,
		"remaining_bonus_each": remaining_bonus_each,
		"public_pool_after": public_pool_after,
		"public_pool_delta": public_pool_after - historical_public_pool,
		"payout_total": payout_total,
		"participants": private_rows,
	}
	var public_receipt := {
		"schema_version": SCHEMA_VERSION,
		"policy_id": POLICY_ID,
		"wager_id": wager_id,
		"revision": revision,
		"outcome_kind": outcome_kind,
		"base_rate_bp": base_rate_bp,
		"competitors": competitor_rows,
		"participants": public_rows,
		"historical_public_pool": historical_public_pool,
		"current_stake_total": total_stakes,
		"matching_money": matching_money,
		"settlement_pool": settlement_pool,
		"winning_side_ids": winning_side_ids,
		"maximum_effective_damage": maximum_effective_damage,
		"remaining_bonus": remaining_bonus,
		"remaining_bonus_each": remaining_bonus_each,
		"public_pool_after": public_pool_after,
		"payout_total": payout_total,
	}
	public_receipt["fingerprint"] = _stable_fingerprint(public_receipt)
	return {
		"ok": true,
		"reason_code": "settlement_ready",
		"schema_version": SCHEMA_VERSION,
		"wager_id": wager_id,
		"revision": revision,
		"fingerprint": private_fingerprint,
		"private_delta_receipt": private_delta_receipt,
		"public_receipt": public_receipt,
	}


static func _validate_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _is_pure_data(snapshot):
		return {"valid": false, "reason_code": "snapshot_not_pure_data"}
	if not _has_exact_keys(snapshot, ["schema_version", "wager_id", "revision", "fingerprint", "window", "base_rate_bp", "historical_public_pool", "competitors", "participants"]):
		return {"valid": false, "reason_code": "snapshot_schema_invalid"}
	if not (snapshot.get("schema_version") is int) or int(snapshot.get("schema_version", -1)) != SCHEMA_VERSION:
		return {"valid": false, "reason_code": "schema_version_unsupported"}
	if not (snapshot.get("wager_id") is String) or str(snapshot.get("wager_id", "")).strip_edges().is_empty():
		return {"valid": false, "reason_code": "wager_id_invalid"}
	if not (snapshot.get("revision") is int) or int(snapshot.get("revision", -1)) < 0:
		return {"valid": false, "reason_code": "revision_invalid"}
	if not (snapshot.get("fingerprint") is String) or not _is_sha256(str(snapshot.get("fingerprint", ""))):
		return {"valid": false, "reason_code": "fingerprint_invalid"}
	if str(snapshot.get("fingerprint", "")) != fingerprint_for_snapshot(snapshot):
		return {"valid": false, "reason_code": "fingerprint_mismatch"}
	if not (snapshot.get("window") is Dictionary):
		return {"valid": false, "reason_code": "window_invalid"}
	var window := snapshot.get("window", {}) as Dictionary
	if not _has_exact_keys(window, ["duration_seconds", "mandatory", "ready_can_close_early"]):
		return {"valid": false, "reason_code": "window_schema_invalid"}
	if not (window.get("duration_seconds") is int) or int(window.get("duration_seconds", 0)) != WINDOW_DURATION_SECONDS \
		or not (window.get("mandatory") is bool) or not bool(window.get("mandatory", false)) \
		or not (window.get("ready_can_close_early") is bool) or not bool(window.get("ready_can_close_early", false)):
		return {"valid": false, "reason_code": "window_contract_invalid"}
	if not (snapshot.get("base_rate_bp") is int):
		return {"valid": false, "reason_code": "base_rate_invalid"}
	var base_rate_bp := int(snapshot.get("base_rate_bp", 0))
	if base_rate_bp < MIN_BASE_RATE_BP or base_rate_bp > MAX_BASE_RATE_BP or base_rate_bp % RATE_INCREMENT_BP != 0:
		return {"valid": false, "reason_code": "base_rate_invalid"}
	if not (snapshot.get("historical_public_pool") is int) or int(snapshot.get("historical_public_pool", -1)) < 0:
		return {"valid": false, "reason_code": "historical_public_pool_invalid"}
	if not (snapshot.get("competitors") is Array) or not (snapshot.get("participants") is Array):
		return {"valid": false, "reason_code": "wager_rows_invalid"}

	var competitors: Array = (snapshot.get("competitors", []) as Array).duplicate(true)
	if competitors.size() < 2:
		return {"valid": false, "reason_code": "competitor_count_invalid"}
	var side_ids: Dictionary = {}
	for competitor_variant: Variant in competitors:
		if not (competitor_variant is Dictionary):
			return {"valid": false, "reason_code": "competitor_invalid"}
		var competitor := competitor_variant as Dictionary
		if not _has_exact_keys(competitor, ["side_id", "effective_damage"]):
			return {"valid": false, "reason_code": "competitor_schema_invalid"}
		if not (competitor.get("side_id") is String) or str(competitor.get("side_id", "")).strip_edges().is_empty() or side_ids.has(str(competitor.get("side_id", ""))):
			return {"valid": false, "reason_code": "side_id_invalid"}
		if not (competitor.get("effective_damage") is int) or int(competitor.get("effective_damage", -1)) < 0:
			return {"valid": false, "reason_code": "effective_damage_invalid"}
		side_ids[str(competitor.get("side_id", ""))] = true
	competitors.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("side_id", "")) < str(right.get("side_id", "")))

	var participants: Array = (snapshot.get("participants", []) as Array).duplicate(true)
	if participants.is_empty():
		return {"valid": false, "reason_code": "participant_count_invalid"}
	var player_ids: Dictionary = {}
	for participant_variant: Variant in participants:
		if not (participant_variant is Dictionary):
			return {"valid": false, "reason_code": "participant_invalid"}
		var participant := participant_variant as Dictionary
		if not _has_exact_keys(participant, ["public_player_id", "exact_cash", "responded", "selected_side_id", "rate_bp"]):
			return {"valid": false, "reason_code": "participant_schema_invalid"}
		if not (participant.get("public_player_id") is String) or str(participant.get("public_player_id", "")).strip_edges().is_empty() or player_ids.has(str(participant.get("public_player_id", ""))):
			return {"valid": false, "reason_code": "public_player_id_invalid"}
		if not (participant.get("exact_cash") is int) or int(participant.get("exact_cash", -1)) < 0:
			return {"valid": false, "reason_code": "exact_cash_invalid"}
		if not (participant.get("responded") is bool) or not (participant.get("selected_side_id") is String) or not (participant.get("rate_bp") is int):
			return {"valid": false, "reason_code": "participant_value_invalid"}
		var responded := bool(participant.get("responded", false))
		var selected_side_id := str(participant.get("selected_side_id", ""))
		var rate_bp := int(participant.get("rate_bp", 0))
		if responded and not side_ids.has(selected_side_id):
			return {"valid": false, "reason_code": "selected_side_invalid"}
		if not responded and not selected_side_id.is_empty():
			return {"valid": false, "reason_code": "unresponsive_selection_must_be_empty"}
		if rate_bp < base_rate_bp or rate_bp > MAX_FINAL_RATE_BP or (rate_bp - base_rate_bp) % RATE_INCREMENT_BP != 0:
			return {"valid": false, "reason_code": "participant_rate_invalid"}
		if not responded and rate_bp != base_rate_bp:
			return {"valid": false, "reason_code": "unresponsive_rate_must_equal_base"}
		player_ids[str(participant.get("public_player_id", ""))] = true
	participants.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("public_player_id", "")) < str(right.get("public_player_id", "")))
	return {"valid": true, "competitors": competitors, "participants": participants}


static func _stake_for_cash(exact_cash: int, rate_bp: int) -> Dictionary:
	if exact_cash < 0 or rate_bp < 0 or rate_bp > MAX_FINAL_RATE_BP:
		return {"ok": false, "reason_code": "stake_terms_invalid", "stake": 0}
	var quotient: int = exact_cash / BASIS_POINTS_DENOMINATOR
	var remainder: int = exact_cash % BASIS_POINTS_DENOMINATOR
	var stake: int = quotient * rate_bp + (remainder * rate_bp) / BASIS_POINTS_DENOMINATOR
	if exact_cash > 0 and stake == 0:
		stake = 1
	if stake < 0 or stake > exact_cash:
		return {"ok": false, "reason_code": "stake_out_of_bounds", "stake": 0}
	return {"ok": true, "reason_code": "stake_ready", "stake": stake}


static func _least_staked_side(side_totals: Dictionary) -> String:
	var side_ids: Array = side_totals.keys()
	side_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	var selected_side_id := ""
	var selected_total := MAX_INT64
	for side_id_variant: Variant in side_ids:
		var side_id := str(side_id_variant)
		var total := int(side_totals.get(side_id, 0))
		if selected_side_id.is_empty() or total < selected_total:
			selected_side_id = side_id
			selected_total = total
	return selected_side_id


static func _safe_add(first: int, second: int) -> Dictionary:
	if first < 0 or second < 0 or second > MAX_INT64 - first:
		return {"ok": false, "value": 0}
	return {"ok": true, "value": first + second}


static func _safe_double(value: int) -> Dictionary:
	if value < 0 or value > MAX_INT64 / 2:
		return {"ok": false, "value": 0}
	return {"ok": true, "value": value * 2}


static func _failure(snapshot: Dictionary, reason_code: String) -> Dictionary:
	return {
		"ok": false,
		"reason_code": reason_code,
		"schema_version": SCHEMA_VERSION,
		"wager_id": str(snapshot.get("wager_id", "")) if snapshot.get("wager_id") is String else "",
		"revision": int(snapshot.get("revision", -1)) if snapshot.get("revision") is int else -1,
		"fingerprint": str(snapshot.get("fingerprint", "")) if snapshot.get("fingerprint") is String else "",
		"private_delta_receipt": {},
		"public_receipt": {},
	}


static func _fingerprint_payload(snapshot: Dictionary) -> Dictionary:
	var competitors: Array = (snapshot.get("competitors", []) as Array).duplicate(true) if snapshot.get("competitors") is Array else []
	var participants: Array = (snapshot.get("participants", []) as Array).duplicate(true) if snapshot.get("participants") is Array else []
	competitors.sort_custom(func(left: Variant, right: Variant) -> bool:
		return str((left as Dictionary).get("side_id", "")) < str((right as Dictionary).get("side_id", "")) if left is Dictionary and right is Dictionary else str(left) < str(right)
	)
	participants.sort_custom(func(left: Variant, right: Variant) -> bool:
		return str((left as Dictionary).get("public_player_id", "")) < str((right as Dictionary).get("public_player_id", "")) if left is Dictionary and right is Dictionary else str(left) < str(right)
	)
	return {
		"schema_version": snapshot.get("schema_version"),
		"wager_id": snapshot.get("wager_id"),
		"revision": snapshot.get("revision"),
		"window": (snapshot.get("window", {}) as Dictionary).duplicate(true) if snapshot.get("window") is Dictionary else snapshot.get("window"),
		"base_rate_bp": snapshot.get("base_rate_bp"),
		"historical_public_pool": snapshot.get("historical_public_pool"),
		"competitors": competitors,
		"participants": participants,
	}


static func _stable_fingerprint(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(_canonicalize(value)).to_utf8_buffer())
	return context.finish().hex_encode()


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array = source.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var result: Dictionary = {}
		for key_variant: Variant in keys:
			result[str(key_variant)] = _canonicalize(source.get(key_variant))
		return result
	if value is Array:
		var result: Array = []
		for item_variant: Variant in value as Array:
			result.append(_canonicalize(item_variant))
		return result
	return value


static func _has_exact_keys(value: Dictionary, allowed: Array) -> bool:
	if value.size() != allowed.size():
		return false
	for key_variant: Variant in value.keys():
		if not (key_variant is String) or not allowed.has(str(key_variant)):
			return false
	for key_variant: Variant in allowed:
		if not value.has(str(key_variant)):
			return false
	return true


static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


static func _is_pure_data(value: Variant) -> bool:
	if value == null or value is bool or value is int or value is float or value is String:
		return true
	if value is Array:
		for item_variant: Variant in value as Array:
			if not _is_pure_data(item_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant: Variant in (value as Dictionary).keys():
			if not (key_variant is String) or not _is_pure_data((value as Dictionary).get(key_variant)):
				return false
		return true
	return false
