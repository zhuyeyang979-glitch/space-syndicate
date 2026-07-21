extends RefCounted
class_name MonsterBattleLifecyclePolicyV06

const SCHEMA_VERSION := 1
const PHASE_DECISION := "decision"
const PHASE_BATTLE := "battle"
const PHASE_SETTLING := "settling"


static func initial_state(
	competitors: Array,
	battle_limit_seconds: float,
	decision_seconds: float,
	pending_attack: Dictionary
) -> Dictionary:
	var locked_uids := _locked_uids(competitors)
	return {
		"lifecycle_schema_version": SCHEMA_VERSION,
		"lifecycle_phase": PHASE_DECISION,
		"lifecycle_revision": 1,
		"decision_remaining_seconds": maxf(0.0, decision_seconds),
		"battle_limit_seconds": maxf(0.0, battle_limit_seconds),
		"battle_remaining_seconds": maxf(0.0, battle_limit_seconds),
		"locked_competitor_uids": locked_uids,
		"battle_roster_fingerprint": roster_fingerprint(competitors),
		"opening_attack_applied": pending_attack.is_empty(),
	}


static func transition_to_battle(entry: Dictionary, reason: String) -> Dictionary:
	var next := entry.duplicate(true)
	next["lifecycle_phase"] = PHASE_BATTLE
	next["lifecycle_revision"] = int(next.get("lifecycle_revision", 0)) + 1
	next["decision_open"] = false
	next["decision_remaining_seconds"] = 0.0
	next["decision_close_reason"] = reason
	next["battle_remaining_seconds"] = maxf(
		0.0,
		float(next.get("battle_limit_seconds", 0.0))
	)
	return next


static func transition_to_settling(entry: Dictionary, reason: String) -> Dictionary:
	var next := entry.duplicate(true)
	if str(next.get("lifecycle_phase", "")) != PHASE_SETTLING:
		next["lifecycle_revision"] = int(next.get("lifecycle_revision", 0)) + 1
	next["lifecycle_phase"] = PHASE_SETTLING
	next["decision_open"] = false
	next["settlement_reason"] = reason
	return next


static func advance_decision(entry: Dictionary, real_delta: float) -> Dictionary:
	var next := entry.duplicate(true)
	next["decision_remaining_seconds"] = maxf(
		0.0,
		float(next.get("decision_remaining_seconds", 0.0)) - maxf(0.0, real_delta)
	)
	return next


static func advance_battle(entry: Dictionary, world_delta: float) -> Dictionary:
	var next := entry.duplicate(true)
	next["battle_remaining_seconds"] = maxf(
		0.0,
		float(next.get("battle_remaining_seconds", 0.0)) - maxf(0.0, world_delta)
	)
	return next


static func roster_fingerprint(competitors: Array) -> String:
	var rows: Array = []
	for competitor_variant: Variant in competitors:
		if not (competitor_variant is Dictionary):
			return ""
		var competitor := competitor_variant as Dictionary
		rows.append({
			"side": str(competitor.get("side", "")),
			"uid": int(competitor.get("uid", 0)),
		})
	rows.sort_custom(func(left: Variant, right: Variant) -> bool:
		return str((left as Dictionary).get("side", "")) < str((right as Dictionary).get("side", ""))
	)
	return JSON.stringify(rows).sha256_text()


static func validate(entry: Dictionary, expected_battle_limit_seconds: float, decision_limit_seconds: float) -> Dictionary:
	if int(entry.get("lifecycle_schema_version", -1)) != SCHEMA_VERSION:
		return _invalid("monster_battle_lifecycle_schema_invalid")
	var phase := str(entry.get("lifecycle_phase", ""))
	if not [PHASE_DECISION, PHASE_BATTLE, PHASE_SETTLING].has(phase):
		return _invalid("monster_battle_lifecycle_phase_invalid")
	if int(entry.get("lifecycle_revision", 0)) <= 0:
		return _invalid("monster_battle_lifecycle_revision_invalid")
	for timer_key in ["decision_remaining_seconds", "battle_limit_seconds", "battle_remaining_seconds"]:
		var timer_variant: Variant = entry.get(timer_key)
		if not (timer_variant is int or timer_variant is float) or not is_finite(float(timer_variant)) or float(timer_variant) < 0.0:
			return _invalid("monster_battle_lifecycle_timer_invalid")
	var battle_limit := float(entry.get("battle_limit_seconds", 0.0))
	var battle_remaining := float(entry.get("battle_remaining_seconds", 0.0))
	var decision_remaining := float(entry.get("decision_remaining_seconds", 0.0))
	if not is_equal_approx(battle_limit, expected_battle_limit_seconds) or battle_remaining > battle_limit + 0.0001:
		return _invalid("monster_battle_lifecycle_battle_limit_invalid")
	if decision_remaining > decision_limit_seconds + 0.0001:
		return _invalid("monster_battle_lifecycle_decision_limit_invalid")
	if not (entry.get("decision_open") is bool):
		return _invalid("monster_battle_lifecycle_decision_flag_invalid")
	if (phase == PHASE_DECISION) != bool(entry.get("decision_open", false)):
		return _invalid("monster_battle_lifecycle_phase_flag_mismatch")
	if phase != PHASE_DECISION and decision_remaining > 0.0001:
		return _invalid("monster_battle_lifecycle_closed_decision_timer_invalid")
	if phase == PHASE_DECISION and not is_equal_approx(battle_remaining, battle_limit):
		return _invalid("monster_battle_lifecycle_battle_timer_started_early")
	if not (entry.get("opening_attack_applied") is bool):
		return _invalid("monster_battle_lifecycle_opening_attack_flag_invalid")
	var competitors_variant: Variant = entry.get("competitors", [])
	var locked_variant: Variant = entry.get("locked_competitor_uids", [])
	if not (competitors_variant is Array) or not (locked_variant is Array):
		return _invalid("monster_battle_lifecycle_roster_invalid")
	var competitors := competitors_variant as Array
	var locked := locked_variant as Array
	var seen_sides := {}
	for competitor_variant: Variant in competitors:
		if not (competitor_variant is Dictionary):
			return _invalid("monster_battle_lifecycle_roster_invalid")
		var side := str((competitor_variant as Dictionary).get("side", "")).strip_edges()
		if side.is_empty() or seen_sides.has(side):
			return _invalid("monster_battle_lifecycle_side_invalid")
		seen_sides[side] = true
	var expected_locked := _locked_uids(competitors)
	if expected_locked.size() < 2 or locked != expected_locked:
		return _invalid("monster_battle_lifecycle_roster_binding_invalid")
	var expected_fingerprint := roster_fingerprint(competitors)
	if expected_fingerprint.is_empty() or str(entry.get("battle_roster_fingerprint", "")) != expected_fingerprint:
		return _invalid("monster_battle_lifecycle_roster_fingerprint_invalid")
	return {"valid": true, "reason_code": "monster_battle_lifecycle_valid"}


static func _locked_uids(competitors: Array) -> Array:
	var result: Array = []
	for competitor_variant: Variant in competitors:
		if not (competitor_variant is Dictionary):
			return []
		var uid := int((competitor_variant as Dictionary).get("uid", 0))
		if uid <= 0 or result.has(uid):
			return []
		result.append(uid)
	return result


static func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code}
