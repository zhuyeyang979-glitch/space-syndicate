extends SceneTree

const Policy := preload("res://scripts/runtime/monster_wager_settlement_policy_v06.gd")
const LARGE_CASH := 9223372036854770000

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_single_winner()
	_check_multiple_winners_different_stakes()
	_check_all_players_win()
	_check_tied_damage_sides()
	_check_no_effective_damage_refund()
	_check_no_winner_rolls_full_pool()
	_check_rate_contract()
	_check_small_zero_and_large_cash()
	_check_auto_selection()
	_check_deterministic_replay_and_fingerprint()
	_check_public_privacy()
	_check_fail_closed_schema()
	_finish()


func _check_single_winner() -> void:
	var result := _settle(100, 500, [_side("monster.a", 20), _side("monster.b", 10)], [
		_player("player.1", 1000, true, "monster.a", 500),
		_player("player.2", 1000, true, "monster.b", 500),
	], "wager.single")
	var receipt := _private_receipt(result)
	var first := _participant_row(receipt, "player.1")
	var second := _participant_row(receipt, "player.2")
	_expect(bool(result.get("ok", false)), "single winner settles")
	_expect(int(receipt.get("current_stake_total", -1)) == 100, "single winner stake total is exact")
	_expect(int(receipt.get("settlement_pool", -1)) == 300, "historical pool is counted once beside doubled stakes")
	_expect(int(first.get("stake", -1)) == 50 and int(first.get("payout", -1)) == 300 and int(first.get("net_cash_delta", -1)) == 250, "single winner receives self-double plus remaining bonus")
	_expect(int(second.get("payout", -1)) == 0 and int(second.get("net_cash_delta", 0)) == -50, "single loser receives no payout")
	_expect(int(receipt.get("public_pool_after", -1)) == 0 and int(receipt.get("payout_total", -1)) == 300, "single winner settlement conserves the pool")


func _check_multiple_winners_different_stakes() -> void:
	var result := _settle(101, 500, [_side("monster.a", 30), _side("monster.b", 10)], [
		_player("player.1", 1000, true, "monster.a", 500),
		_player("player.2", 1000, true, "monster.a", 2000),
		_player("player.3", 2000, true, "monster.b", 500),
	], "wager.multi")
	var receipt := _private_receipt(result)
	var first := _participant_row(receipt, "player.1")
	var second := _participant_row(receipt, "player.2")
	var third := _participant_row(receipt, "player.3")
	_expect(bool(result.get("ok", false)) and int(receipt.get("settlement_pool", -1)) == 801, "different-stake multi-winner pool uses history plus twice all stakes")
	_expect(int(receipt.get("remaining_bonus", -1)) == 301 and int(receipt.get("remaining_bonus_each", -1)) == 150, "remaining bonus is divided by winner count")
	_expect(int(first.get("remaining_bonus_share", -1)) == 150 and int(second.get("remaining_bonus_share", -1)) == 150, "different winner stakes receive equal remaining bonus")
	_expect(int(first.get("payout", -1)) == 250 and int(second.get("payout", -1)) == 550, "each winner first receives twice their own stake")
	_expect(int(third.get("payout", -1)) == 0 and int(receipt.get("public_pool_after", -1)) == 1, "loser payout is zero and integer remainder rolls public")
	_expect(int(receipt.get("payout_total", -1)) + int(receipt.get("public_pool_after", -1)) == int(receipt.get("settlement_pool", -2)), "multi-winner settlement conserves exact integers")


func _check_all_players_win() -> void:
	var result := _settle(5, 500, [_side("monster.a", 9), _side("monster.b", 1)], [
		_player("player.1", 1000, true, "monster.a", 500),
		_player("player.2", 1000, true, "monster.a", 1000),
	], "wager.all_win")
	var receipt := _private_receipt(result)
	var first := _participant_row(receipt, "player.1")
	var second := _participant_row(receipt, "player.2")
	_expect(int(receipt.get("settlement_pool", -1)) == 305 and int(receipt.get("remaining_bonus", -1)) == 5, "all-winner case keeps historical pool single")
	_expect(int(first.get("payout", -1)) == 102 and int(second.get("payout", -1)) == 202, "all winners receive self-double plus equal history share")
	_expect(int(receipt.get("public_pool_after", -1)) == 1, "all-winner odd history leaves one public unit")


func _check_tied_damage_sides() -> void:
	var result := _settle(0, 500, [_side("monster.a", 12), _side("monster.b", 12), _side("monster.c", 3)], [
		_player("player.1", 1000, true, "monster.a", 500),
		_player("player.2", 1000, true, "monster.b", 500),
		_player("player.3", 1000, true, "monster.c", 500),
	], "wager.tie")
	var receipt := _private_receipt(result)
	_expect(JSON.stringify(receipt.get("winning_side_ids", [])) == '["monster.a","monster.b"]', "all maximum-damage sides are winning sides")
	_expect(bool(_participant_row(receipt, "player.1").get("winner", false)) and bool(_participant_row(receipt, "player.2").get("winner", false)), "players on either tied maximum side win")
	_expect(not bool(_participant_row(receipt, "player.3").get("winner", true)), "non-maximum side remains a loser")


func _check_no_effective_damage_refund() -> void:
	var result := _settle(77, 500, [_side("monster.a", 0), _side("monster.b", 0)], [
		_player("player.1", 1000, true, "monster.a", 500),
		_player("player.2", 1000, true, "monster.b", 1000),
	], "wager.void")
	var receipt := _private_receipt(result)
	_expect(str(receipt.get("outcome_kind", "")) == "void_no_effective_damage", "zero damage takes the void branch")
	_expect(int(receipt.get("matching_money", -1)) == 0 and int(receipt.get("settlement_pool", -1)) == 227, "void branch adds no matching money")
	_expect(int(_participant_row(receipt, "player.1").get("net_cash_delta", -1)) == 0 and int(_participant_row(receipt, "player.2").get("net_cash_delta", -1)) == 0, "void branch refunds original stakes exactly")
	_expect(int(receipt.get("public_pool_after", -1)) == 77, "void branch preserves historical public pool")


func _check_no_winner_rolls_full_pool() -> void:
	var result := _settle(7, 500, [_side("monster.a", 10), _side("monster.b", 2)], [
		_player("player.1", 1000, true, "monster.b", 500),
		_player("player.2", 1000, true, "monster.b", 1000),
	], "wager.no_winner")
	var receipt := _private_receipt(result)
	_expect(str(receipt.get("outcome_kind", "")) == "rolled_to_public_pool_no_winner", "effective damage with no correct selection uses no-winner branch")
	_expect(int(receipt.get("settlement_pool", -1)) == 307 and int(receipt.get("public_pool_after", -1)) == 307, "entire doubled settlement pool rolls public when nobody picked the winner")
	_expect(int(receipt.get("payout_total", -1)) == 0, "no-winner branch pays no player")


func _check_rate_contract() -> void:
	var base_500 := _settle(0, 500, [_side("a", 1), _side("b", 0)], [_player("p", 1000, true, "a", 500)], "wager.base500")
	var base_1000 := _settle(0, 1000, [_side("a", 1), _side("b", 0)], [_player("p", 1000, true, "a", 2000)], "wager.base1000")
	_expect(bool(base_500.get("ok", false)) and int(_participant_row(_private_receipt(base_500), "p").get("stake", -1)) == 50, "500bp base is legal")
	_expect(bool(base_1000.get("ok", false)) and int(_participant_row(_private_receipt(base_1000), "p").get("stake", -1)) == 200, "1000bp base and 2000bp final cap are legal")

	for invalid_base in [400, 550, 1100]:
		var snapshot := _snapshot(0, int(invalid_base), [_side("a", 1), _side("b", 0)], [_player("p", 1000, true, "a", int(invalid_base))], "wager.bad_base.%s" % invalid_base)
		_assert_fail_closed(Policy.settle(snapshot), "base_rate_invalid", "base %s" % invalid_base)
	for invalid_rate in [400, 650, 2100]:
		var snapshot := _snapshot(0, 500, [_side("a", 1), _side("b", 0)], [_player("p", 1000, true, "a", int(invalid_rate))], "wager.bad_rate.%s" % invalid_rate)
		_assert_fail_closed(Policy.settle(snapshot), "participant_rate_invalid", "rate %s" % invalid_rate)


func _check_small_zero_and_large_cash() -> void:
	var small := _settle(0, 500, [_side("a", 1), _side("b", 1)], [
		_player("cash.zero", 0, true, "a", 2000),
		_player("cash.one", 1, true, "b", 500),
	], "wager.small")
	_expect(int(_participant_row(_private_receipt(small), "cash.zero").get("stake", -1)) == 0, "zero cash produces zero stake")
	_expect(int(_participant_row(_private_receipt(small), "cash.one").get("stake", -1)) == 1, "positive cash rounds up to one minimum currency unit")

	var large := _settle(0, 500, [_side("a", 1), _side("b", 0)], [
		_player("cash.large", LARGE_CASH, true, "a", 2000),
		_player("cash.zero", 0, true, "b", 500),
	], "wager.large")
	var large_row := _participant_row(_private_receipt(large), "cash.large")
	_expect(bool(large.get("ok", false)), "large int64 cash settles without multiplication overflow")
	_expect(int(large_row.get("stake", -1)) == 1844674407370954000, "large int64 stake uses exact quotient/remainder math")
	_expect(int(large_row.get("stake", -1)) <= LARGE_CASH, "large stake never exceeds cash")

	var overflow_players: Array = []
	for index in range(3):
		overflow_players.append(_player("cash.large.%d" % index, LARGE_CASH, true, "a", 2000))
	var overflow := _snapshot(0, 500, [_side("a", 1), _side("b", 0)], overflow_players, "wager.overflow")
	_assert_fail_closed(Policy.settle(overflow), "matching_money_overflow", "overflow snapshot")


func _check_auto_selection() -> void:
	var result := _settle(0, 500, [_side("monster.a", 1), _side("monster.b", 2)], [
		_player("player.1", 1000, true, "monster.a", 1000),
		_player("player.2", 1000, true, "monster.b", 500),
		_player("player.3", 1000, false, "", 500),
	], "wager.auto_least")
	var auto_row := _participant_row(_private_receipt(result), "player.3")
	_expect(bool(auto_row.get("auto_selected", false)) and str(auto_row.get("selected_side_id", "")) == "monster.b", "missing response selects the least-staked public side")
	_expect(int(auto_row.get("rate_bp", -1)) == 500 and int(auto_row.get("stake", -1)) == 50, "missing response uses base rate only")

	var tie := _settle(0, 500, [_side("monster.b", 0), _side("monster.a", 0)], [
		_player("player.auto", 100, false, "", 500),
	], "wager.auto_tie")
	_expect(str(_participant_row(_private_receipt(tie), "player.auto").get("selected_side_id", "")) == "monster.a", "auto-selection tie breaks by stable public side id")


func _check_deterministic_replay_and_fingerprint() -> void:
	var competitors := [_side("b", 2), _side("a", 3)]
	var participants := [_player("p2", 1000, true, "b", 600), _player("p1", 2000, true, "a", 500)]
	var first := _snapshot(9, 500, competitors, participants, "wager.replay", 4)
	var second := _snapshot(9, 500, [competitors[1], competitors[0]], [participants[1], participants[0]], "wager.replay", 4)
	_expect(str(first.get("fingerprint", "")) == str(second.get("fingerprint", "")), "snapshot fingerprint is stable across input row order")
	var first_result: Dictionary = Policy.settle(first)
	var second_result: Dictionary = Policy.settle(second)
	_expect(JSON.stringify(first_result) == JSON.stringify(second_result), "deterministic replay returns byte-equivalent canonical receipts")
	_expect(str((_public_receipt(first_result)).get("fingerprint", "")).length() == 64, "public receipt carries its own public-only fingerprint")
	_expect(str((_public_receipt(first_result)).get("fingerprint", "")) != str(first.get("fingerprint", "")), "public fingerprint does not expose the private snapshot fingerprint")

	var forged := first.duplicate(true)
	(forged.get("participants", []) as Array)[0]["exact_cash"] = 9999
	_assert_fail_closed(Policy.settle(forged), "fingerprint_mismatch", "forged replay")


func _check_public_privacy() -> void:
	var cash_one := 917431
	var cash_two := 628319
	var result := _settle(13, 500, [_side("monster.a", 5), _side("monster.b", 4)], [
		_player("public.player.1", cash_one, true, "monster.a", 700),
		_player("public.player.2", cash_two, true, "monster.b", 500),
	], "wager.privacy")
	var public_receipt := _public_receipt(result)
	var leaks: Array[String] = []
	_scan_privacy(public_receipt, "public", leaks)
	var serialized := JSON.stringify(public_receipt)
	if serialized.contains(str(cash_one)) or serialized.contains(str(cash_two)):
		leaks.append("public.exact_cash_value")
	_expect(leaks.is_empty(), "public receipt recursive privacy scan has zero leaks: %s" % ",".join(leaks))
	var public_row := _participant_row(public_receipt, "public.player.1")
	_expect(str(public_row.get("selected_side_id", "")) == "monster.a" and int(public_row.get("rate_bp", 0)) == 700 and int(public_row.get("stake", 0)) > 0, "public receipt retains allowed identity, choice, rate, and stake")


func _check_fail_closed_schema() -> void:
	var valid := _snapshot(0, 500, [_side("a", 1), _side("b", 0)], [_player("p", 100, true, "a", 500)], "wager.schema")
	var wrong_window := valid.duplicate(true)
	(wrong_window.get("window", {}) as Dictionary)["duration_seconds"] = 14
	wrong_window["fingerprint"] = Policy.fingerprint_for_snapshot(wrong_window)
	_assert_fail_closed(Policy.settle(wrong_window), "window_contract_invalid", "wrong window")

	var duplicate_side := valid.duplicate(true)
	duplicate_side["competitors"] = [_side("a", 1), _side("a", 0)]
	duplicate_side["fingerprint"] = Policy.fingerprint_for_snapshot(duplicate_side)
	_assert_fail_closed(Policy.settle(duplicate_side), "side_id_invalid", "duplicate side")

	var negative_pool := valid.duplicate(true)
	negative_pool["historical_public_pool"] = -1
	negative_pool["fingerprint"] = Policy.fingerprint_for_snapshot(negative_pool)
	_assert_fail_closed(Policy.settle(negative_pool), "historical_public_pool_invalid", "negative pool")

	var ai_metadata := valid.duplicate(true)
	(ai_metadata.get("participants", []) as Array)[0]["ai_private_plan"] = "secret"
	ai_metadata["fingerprint"] = Policy.fingerprint_for_snapshot(ai_metadata)
	_assert_fail_closed(Policy.settle(ai_metadata), "participant_schema_invalid", "AI private metadata")


func _settle(historical_pool: int, base_rate_bp: int, competitors: Array, participants: Array, wager_id: String, revision: int = 1) -> Dictionary:
	return Policy.settle(_snapshot(historical_pool, base_rate_bp, competitors, participants, wager_id, revision))


func _snapshot(historical_pool: int, base_rate_bp: int, competitors: Array, participants: Array, wager_id: String, revision: int = 1) -> Dictionary:
	var snapshot := {
		"schema_version": 1,
		"wager_id": wager_id,
		"revision": revision,
		"fingerprint": "",
		"window": {"duration_seconds": 15, "mandatory": true, "ready_can_close_early": true},
		"base_rate_bp": base_rate_bp,
		"historical_public_pool": historical_pool,
		"competitors": competitors.duplicate(true),
		"participants": participants.duplicate(true),
	}
	snapshot["fingerprint"] = Policy.fingerprint_for_snapshot(snapshot)
	return snapshot


func _side(side_id: String, effective_damage: int) -> Dictionary:
	return {"side_id": side_id, "effective_damage": effective_damage}


func _player(player_id: String, exact_cash: int, responded: bool, side_id: String, rate_bp: int) -> Dictionary:
	return {
		"public_player_id": player_id,
		"exact_cash": exact_cash,
		"responded": responded,
		"selected_side_id": side_id,
		"rate_bp": rate_bp,
	}


func _private_receipt(result: Dictionary) -> Dictionary:
	return result.get("private_delta_receipt", {}) as Dictionary


func _public_receipt(result: Dictionary) -> Dictionary:
	return result.get("public_receipt", {}) as Dictionary


func _participant_row(receipt: Dictionary, player_id: String) -> Dictionary:
	for row_variant: Variant in receipt.get("participants", []) as Array:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("public_player_id", "")) == player_id:
			return row_variant as Dictionary
	return {}


func _assert_fail_closed(result: Dictionary, reason_code: String, label: String) -> void:
	_expect(not bool(result.get("ok", true)), "%s fails closed" % label)
	_expect(str(result.get("reason_code", "")) == reason_code, "%s reports %s" % [label, reason_code])
	_expect((result.get("private_delta_receipt", {}) as Dictionary).is_empty() and (result.get("public_receipt", {}) as Dictionary).is_empty(), "%s returns zero partial receipts" % label)


func _scan_privacy(value: Variant, path: String, leaks: Array[String]) -> void:
	var forbidden := [
		"exact_cash", "cash_after", "true_owner", "hidden_owner", "owner_truth",
		"ai_private_score", "ai_score", "ai_plan", "ai_private_plan", "private_route_plan",
	]
	if value is Dictionary:
		for key_variant: Variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			var child_path := "%s.%s" % [path, key]
			if forbidden.has(key):
				leaks.append(child_path)
			_scan_privacy((value as Dictionary).get(key_variant), child_path, leaks)
	elif value is Array:
		for index in range((value as Array).size()):
			_scan_privacy((value as Array)[index], "%s[%d]" % [path, index], leaks)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("MONSTER_WAGER_SETTLEMENT_POLICY_TEST: %s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("MONSTER_WAGER_SETTLEMENT_POLICY_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	if not _failures.is_empty():
		print("MONSTER_WAGER_SETTLEMENT_POLICY_TEST|first_failure=%s" % _failures[0])
	quit(_failures.size())
