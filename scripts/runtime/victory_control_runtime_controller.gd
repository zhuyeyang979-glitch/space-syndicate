@tool
extends Node
class_name VictoryControlRuntimeController

const CONTROLLER_ID := "victory_control_v05"
const SAVE_SCHEMA_VERSION := 1
const OUTCOME_SCHEMA_VERSION := 1
const STATE_IDLE := "idle"
const STATE_QUALIFICATION := "qualification"
const STATE_AUDIT := "audit"
const STATE_COOLDOWN := "cooldown"
const STATE_RESOLVED := "resolved"
const VALID_STATES := [STATE_IDLE, STATE_QUALIFICATION, STATE_AUDIT, STATE_COOLDOWN, STATE_RESOLVED]
const DEPTH_ORDER := ["I", "II", "III", "IV", "V", "VI"]
const COMPARISON_ORDER := ["top_n_gdp_per_minute", "controlled_region_count", "cash_ledger_cents"]

@export var ruleset_profile: Resource
@export var clock_domain_registry: Resource

var _world_bridge: Node
var _configured := false
var _profile: Dictionary = {}
var _clock_rules: Dictionary = {}
var _state := STATE_IDLE
var _qualification_elapsed_by_player: Dictionary = {}
var _audit_roster: Array = []
var _audit_remaining_seconds := 0.0
var _cooldown_remaining_seconds := 0.0
var _outcome_sequence := 0
var _outcome_receipt: Dictionary = {}
var _last_candidates: Array = []
var _last_player_assets: Dictionary = {}
var _last_depth_rule: Dictionary = {}
var _last_pause_reasons: Array = []
var _advance_count := 0


func set_world_bridge(bridge: Node) -> void:
	_world_bridge = bridge


func configure(profile_overrides: Dictionary = {}, clock_overrides: Dictionary = {}) -> Dictionary:
	_profile = _profile_from_resource()
	if _is_data_only(profile_overrides):
		_profile.merge(profile_overrides, true)
	_clock_rules = _clock_rules_from_resource()
	if _is_data_only(clock_overrides):
		_clock_rules.merge(clock_overrides, true)
	var errors := _configuration_errors()
	_configured = errors.is_empty()
	reset_state()
	return {
		"configured": _configured,
		"ruleset_id": str(_profile.get("ruleset_id", "")),
		"errors": errors,
	}


func reset_state() -> void:
	_state = STATE_IDLE
	_qualification_elapsed_by_player = {}
	_audit_roster = []
	_audit_remaining_seconds = 0.0
	_cooldown_remaining_seconds = 0.0
	_outcome_sequence = 0
	_outcome_receipt = {}
	_last_candidates = []
	_last_player_assets = {}
	_last_depth_rule = {}
	_last_pause_reasons = []
	_advance_count = 0


func evaluate_region_control(region_snapshot: Dictionary) -> Dictionary:
	var region_gdp := maxi(0, int(region_snapshot.get("region_gdp_per_minute", 0)))
	var player_gdp_by_index: Dictionary = region_snapshot.get("player_gdp_by_index", {}) if region_snapshot.get("player_gdp_by_index", {}) is Dictionary else {}
	var result := {
		"region_id": str(region_snapshot.get("region_id", "")),
		"district_index": int(region_snapshot.get("district_index", -1)),
		"destroyed": bool(region_snapshot.get("destroyed", false)),
		"region_gdp_per_minute": region_gdp,
		"controller_player_index": -1,
		"control_threshold_basis_points": int(_profile.get("region_control_threshold_bp", 3000)),
		"player_results": [],
	}
	if bool(result["destroyed"]) or region_gdp <= 0:
		return result
	var highest_gdp := 0
	var highest_players: Array = []
	var player_indices: Array = []
	for player_key_variant in player_gdp_by_index.keys():
		player_indices.append(int(str(player_key_variant)))
	player_indices.sort()
	for player_index_variant in player_indices:
		var player_index := int(player_index_variant)
		var player_gdp := maxi(0, int(player_gdp_by_index.get(str(player_index), player_gdp_by_index.get(player_index, 0))))
		var share_basis_points := int(floor(float(player_gdp * 10000) / float(region_gdp)))
		(result["player_results"] as Array).append({
			"player_index": player_index,
			"attributable_gdp_per_minute": player_gdp,
			"share_basis_points": clampi(share_basis_points, 0, 10000),
		})
		if player_gdp > highest_gdp:
			highest_gdp = player_gdp
			highest_players = [player_index]
		elif player_gdp > 0 and player_gdp == highest_gdp:
			highest_players.append(player_index)
	if highest_players.size() != 1:
		return result
	var highest_player := int(highest_players[0])
	for player_result_variant in result["player_results"]:
		if player_result_variant is Dictionary and int((player_result_variant as Dictionary).get("player_index", -1)) == highest_player:
			if int((player_result_variant as Dictionary).get("share_basis_points", 0)) >= int(result["control_threshold_basis_points"]):
				result["controller_player_index"] = highest_player
			break
	return result


func evaluate_candidates(world_snapshot: Dictionary) -> Array:
	if not _configured or not _is_data_only(world_snapshot):
		return []
	var depth_rule := _depth_rule(world_snapshot)
	var player_rows: Dictionary = {}
	for player_variant in world_snapshot.get("players", []):
		if not (player_variant is Dictionary):
			continue
		var player: Dictionary = player_variant
		var player_index := int(player.get("player_index", -1))
		if player_index < 0:
			continue
		player_rows[str(player_index)] = {
			"player_index": player_index,
			"eliminated": bool(player.get("eliminated", false)),
			"controlled_regions": [],
			"controlled_region_count": 0,
			"top_n_gdp_per_minute": 0,
			"required_region_count": int(depth_rule.get("regions", 0)),
			"required_top_n_gdp_per_minute": int(depth_rule.get("depth", 0)),
			"cash_ledger_cents": int(player.get("cash_ledger_cents", 0)),
			"eligible": false,
		}
	for region_variant in world_snapshot.get("regions", []):
		if not (region_variant is Dictionary):
			continue
		var control := evaluate_region_control(region_variant as Dictionary)
		var controller_player := int(control.get("controller_player_index", -1))
		var player_key := str(controller_player)
		if controller_player < 0 or not player_rows.has(player_key):
			continue
		var player_gdp := 0
		var share_basis_points := 0
		for player_result_variant in control.get("player_results", []):
			if player_result_variant is Dictionary and int((player_result_variant as Dictionary).get("player_index", -1)) == controller_player:
				player_gdp = int((player_result_variant as Dictionary).get("attributable_gdp_per_minute", 0))
				share_basis_points = int((player_result_variant as Dictionary).get("share_basis_points", 0))
				break
		var row: Dictionary = player_rows[player_key]
		(row["controlled_regions"] as Array).append({
			"region_id": str(control.get("region_id", "")),
			"district_index": int(control.get("district_index", -1)),
			"attributable_gdp_per_minute": player_gdp,
			"share_basis_points": share_basis_points,
		})
		player_rows[player_key] = row
	var candidates: Array = []
	var player_keys: Array = player_rows.keys()
	player_keys.sort_custom(func(left: Variant, right: Variant) -> bool: return int(str(left)) < int(str(right)))
	for player_key_variant in player_keys:
		var candidate: Dictionary = player_rows[player_key_variant]
		var controlled_regions: Array = candidate.get("controlled_regions", []) as Array
		controlled_regions.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_gdp := int(left.get("attributable_gdp_per_minute", 0))
			var right_gdp := int(right.get("attributable_gdp_per_minute", 0))
			return left_gdp > right_gdp if left_gdp != right_gdp else int(left.get("district_index", -1)) < int(right.get("district_index", -1))
		)
		candidate["controlled_regions"] = controlled_regions
		candidate["controlled_region_count"] = controlled_regions.size()
		var top_n_gdp := 0
		for region_index in range(mini(controlled_regions.size(), int(candidate.get("required_region_count", 0)))):
			top_n_gdp += int((controlled_regions[region_index] as Dictionary).get("attributable_gdp_per_minute", 0))
		candidate["top_n_gdp_per_minute"] = top_n_gdp
		candidate["eligible"] = not bool(candidate.get("eliminated", false)) \
			and int(candidate.get("controlled_region_count", 0)) >= int(candidate.get("required_region_count", 0)) \
			and top_n_gdp >= int(candidate.get("required_top_n_gdp_per_minute", 0))
		candidates.append(candidate)
	return candidates


func advance_world_effective(delta_seconds: float, world_snapshot: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(world_snapshot):
		return _advance_result(false, "controller_not_ready_or_snapshot_invalid")
	_capture_world_facts(world_snapshot)
	_last_pause_reasons = _pause_reasons(world_snapshot)
	if _state == STATE_RESOLVED or delta_seconds <= 0.0 or not _last_pause_reasons.is_empty():
		return _advance_result(true, "paused" if not _last_pause_reasons.is_empty() else "")
	_advance_count += 1
	match _state:
		STATE_IDLE, STATE_QUALIFICATION:
			_advance_qualification(delta_seconds)
		STATE_AUDIT:
			_advance_audit(delta_seconds)
		STATE_COOLDOWN:
			_advance_cooldown(delta_seconds)
	return _advance_result(true, "")


func resolve_special_outcome(reason_code: String, world_snapshot: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(world_snapshot):
		return {}
	if not _outcome_receipt.is_empty():
		return _outcome_receipt.duplicate(true)
	_capture_world_facts(world_snapshot)
	var active_candidates: Array = []
	for candidate_variant in _last_candidates:
		if candidate_variant is Dictionary and not bool((candidate_variant as Dictionary).get("eliminated", false)):
			active_candidates.append((candidate_variant as Dictionary).duplicate(true))
	var winners: Array = []
	if reason_code == "last_survivor" and active_candidates.size() == 1:
		winners = [int((active_candidates[0] as Dictionary).get("player_index", -1))]
	elif reason_code == "planet_destroyed":
		active_candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return int(left.get("cash_ledger_cents", 0)) > int(right.get("cash_ledger_cents", 0)) if int(left.get("cash_ledger_cents", 0)) != int(right.get("cash_ledger_cents", 0)) else int(left.get("player_index", -1)) < int(right.get("player_index", -1))
		)
		if not active_candidates.is_empty():
			var best_cash := int((active_candidates[0] as Dictionary).get("cash_ledger_cents", 0))
			for candidate_variant in active_candidates:
				if int((candidate_variant as Dictionary).get("cash_ledger_cents", 0)) == best_cash:
					winners.append(int((candidate_variant as Dictionary).get("player_index", -1)))
	if winners.is_empty():
		return {}
	var comparison_order := ["cash_ledger_cents"] if reason_code == "planet_destroyed" else COMPARISON_ORDER
	_finalize_outcome(reason_code, active_candidates, winners, comparison_order)
	return _outcome_receipt.duplicate(true)


func preview_rankings(world_snapshot: Dictionary, eligible_only := false) -> Array:
	var candidates := evaluate_candidates(world_snapshot)
	if eligible_only:
		candidates = candidates.filter(func(candidate: Dictionary) -> bool: return bool(candidate.get("eligible", false)))
	_sort_candidates(candidates)
	return candidates


func depth_rule_for_tier(depth_tier: Variant) -> Dictionary:
	return _depth_rule({"depth_tier": depth_tier})


func timer_duration(timer_id: String) -> float:
	return _timer_duration(timer_id)


func public_snapshot(_viewer_index := -1) -> Dictionary:
	var roster_entries: Array = []
	for player_index_variant in _audit_roster:
		var player_index := int(player_index_variant)
		var candidate := _candidate_for(player_index)
		if candidate.is_empty():
			continue
		roster_entries.append({
			"player_index": player_index,
			"eligible": bool(candidate.get("eligible", false)),
			"top_n_gdp_per_minute": int(candidate.get("top_n_gdp_per_minute", 0)),
			"controlled_region_count": int(candidate.get("controlled_region_count", 0)),
			"cash_ledger_cents": int(candidate.get("cash_ledger_cents", 0)),
			"controlled_regions": (candidate.get("controlled_regions", []) as Array).duplicate(true),
			"economic_assets": _public_audit_assets(player_index),
		})
	return {
		"controller_id": CONTROLLER_ID,
		"ruleset_id": str(_profile.get("ruleset_id", "")),
		"state": _state,
		"depth_rule": _last_depth_rule.duplicate(true),
		"qualification_remaining_seconds": _qualification_remaining_seconds(),
		"audit_remaining_seconds": _audit_remaining_seconds,
		"cooldown_remaining_seconds": _cooldown_remaining_seconds,
		"audit_roster": _audit_roster.duplicate(),
		"audit_entries": roster_entries,
		"paused": not _last_pause_reasons.is_empty(),
		"pause_reasons": _last_pause_reasons.duplicate(),
		"outcome_receipt": _public_outcome_receipt(),
		"visibility_scope": "public",
	}


func private_snapshot(viewer_index: int) -> Dictionary:
	var result := public_snapshot(viewer_index)
	var candidate := _candidate_for(viewer_index)
	result["viewer_player_index"] = viewer_index
	result["own_candidate"] = candidate
	result["own_economic_assets"] = _private_assets_for(viewer_index)
	result["own_qualification_elapsed_seconds"] = float(_qualification_elapsed_by_player.get(str(viewer_index), 0.0))
	result["visibility_scope"] = "viewer_private"
	return result


func outcome_receipt() -> Dictionary:
	return _outcome_receipt.duplicate(true)


func to_save_data() -> Dictionary:
	return {
		"victory_control_runtime": {
			"schema_version": SAVE_SCHEMA_VERSION,
			"ruleset_id": str(_profile.get("ruleset_id", "v0.5")),
			"state": _state,
			"qualification_elapsed_by_player": _qualification_elapsed_by_player.duplicate(true),
			"audit_roster": _audit_roster.duplicate(),
			"audit_remaining_seconds": _audit_remaining_seconds,
			"cooldown_remaining_seconds": _cooldown_remaining_seconds,
			"outcome_sequence": _outcome_sequence,
			"outcome_receipt": _outcome_receipt.duplicate(true),
		}
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var payload: Dictionary = data.get("victory_control_runtime", data) if data.get("victory_control_runtime", data) is Dictionary else {}
	if payload.is_empty():
		reset_state()
		return {"applied": true, "legacy_default": true, "state": _state}
	if not _is_data_only(payload) or int(payload.get("schema_version", 0)) != SAVE_SCHEMA_VERSION or str(payload.get("ruleset_id", "")) != "v0.5":
		return {"applied": false, "reason": "victory_save_invalid"}
	var saved_state := str(payload.get("state", STATE_IDLE))
	if saved_state not in VALID_STATES:
		return {"applied": false, "reason": "victory_state_invalid"}
	_state = saved_state
	_qualification_elapsed_by_player = (payload.get("qualification_elapsed_by_player", {}) as Dictionary).duplicate(true) if payload.get("qualification_elapsed_by_player", {}) is Dictionary else {}
	_audit_roster = (payload.get("audit_roster", []) as Array).duplicate() if payload.get("audit_roster", []) is Array else []
	_audit_remaining_seconds = clampf(float(payload.get("audit_remaining_seconds", 0.0)), 0.0, _timer_duration("public_audit"))
	_cooldown_remaining_seconds = clampf(float(payload.get("cooldown_remaining_seconds", 0.0)), 0.0, _timer_duration("audit_failure_cooldown"))
	_outcome_sequence = maxi(0, int(payload.get("outcome_sequence", 0)))
	_outcome_receipt = (payload.get("outcome_receipt", {}) as Dictionary).duplicate(true) if payload.get("outcome_receipt", {}) is Dictionary else {}
	return {"applied": true, "legacy_default": false, "state": _state}


func debug_snapshot() -> Dictionary:
	return {
		"controller_id": CONTROLLER_ID,
		"controller_ready": _configured,
		"controller_authoritative": _configured,
		"ruleset_id": str(_profile.get("ruleset_id", "")),
		"state": _state,
		"depth_rule": _last_depth_rule.duplicate(true),
		"qualification_candidate_count": _qualification_elapsed_by_player.size(),
		"audit_roster_count": _audit_roster.size(),
		"audit_remaining_seconds": _audit_remaining_seconds,
		"cooldown_remaining_seconds": _cooldown_remaining_seconds,
		"outcome_emitted": not _outcome_receipt.is_empty(),
		"outcome_sequence": _outcome_sequence,
		"advance_count": _advance_count,
		"world_bridge_ready": _world_bridge != null,
		"owns_gdp_formula": false,
		"owns_project_attribution": false,
		"owns_cash_mutation": false,
		"owns_victory_state": true,
		"owns_outcome_ordering": true,
		"legacy_cash_goal_fallback_used": false,
	}


func _advance_qualification(delta_seconds: float) -> void:
	var leaders := _leading_candidates(_last_candidates)
	if leaders.is_empty():
		_state = STATE_IDLE
		_qualification_elapsed_by_player = {}
		return
	_state = STATE_QUALIFICATION
	var next_elapsed := {}
	var reached := false
	for leader_variant in leaders:
		var player_index := int((leader_variant as Dictionary).get("player_index", -1))
		var key := str(player_index)
		var elapsed := float(_qualification_elapsed_by_player.get(key, 0.0)) + delta_seconds
		next_elapsed[key] = elapsed
		if elapsed + 0.000001 >= _timer_duration("victory_qualification"):
			reached = true
	_qualification_elapsed_by_player = next_elapsed
	if not reached:
		return
	_state = STATE_AUDIT
	_audit_remaining_seconds = _timer_duration("public_audit")
	_audit_roster = []
	_add_leaders_to_roster(leaders)
	_qualification_elapsed_by_player = {}


func _advance_audit(delta_seconds: float) -> void:
	_add_leaders_to_roster(_leading_candidates(_last_candidates))
	_audit_remaining_seconds = maxf(0.0, _audit_remaining_seconds - delta_seconds)
	if _audit_remaining_seconds > 0.0:
		return
	var finalists: Array = []
	for player_index_variant in _audit_roster:
		var candidate := _candidate_for(int(player_index_variant))
		if not candidate.is_empty() and bool(candidate.get("eligible", false)) and not bool(candidate.get("eliminated", false)):
			finalists.append(candidate)
	if finalists.is_empty():
		_state = STATE_COOLDOWN
		_cooldown_remaining_seconds = _timer_duration("audit_failure_cooldown")
		_audit_roster = []
		return
	_sort_candidates(finalists)
	var winners: Array = []
	var best: Dictionary = finalists[0]
	for candidate_variant in finalists:
		var candidate: Dictionary = candidate_variant
		if _candidates_tied(candidate, best):
			winners.append(int(candidate.get("player_index", -1)))
	_finalize_outcome("public_audit_complete", finalists, winners, COMPARISON_ORDER)


func _advance_cooldown(delta_seconds: float) -> void:
	_cooldown_remaining_seconds = maxf(0.0, _cooldown_remaining_seconds - delta_seconds)
	if _cooldown_remaining_seconds <= 0.0:
		_state = STATE_IDLE
		_qualification_elapsed_by_player = {}


func _finalize_outcome(reason_code: String, ranked_candidates: Array, winner_player_indices: Array, comparison_order: Array) -> void:
	if not _outcome_receipt.is_empty():
		return
	_sort_candidates_by_order(ranked_candidates, comparison_order)
	_outcome_sequence += 1
	var rankings: Array = []
	for candidate_variant in ranked_candidates:
		if not (candidate_variant is Dictionary):
			continue
		var candidate: Dictionary = candidate_variant
		var player_index := int(candidate.get("player_index", -1))
		rankings.append({
			"player_index": player_index,
			"top_n_gdp_per_minute": int(candidate.get("top_n_gdp_per_minute", 0)),
			"controlled_region_count": int(candidate.get("controlled_region_count", 0)),
			"cash_ledger_cents": int(candidate.get("cash_ledger_cents", 0)),
			"winner": winner_player_indices.has(player_index),
		})
	_outcome_receipt = {
		"outcome_id": "victory.v05.%d" % _outcome_sequence,
		"schema_version": OUTCOME_SCHEMA_VERSION,
		"ruleset_id": "v0.5",
		"reason_code": reason_code,
		"winner_player_indices": winner_player_indices.duplicate(),
		"co_victory": winner_player_indices.size() > 1,
		"comparison_order": comparison_order.duplicate(),
		"rankings": rankings,
		"audit_evidence": {
			"depth_rule": _last_depth_rule.duplicate(true),
			"audit_roster": _audit_roster.duplicate(),
		},
		"visibility_scope": "public",
	}
	_state = STATE_RESOLVED


func _capture_world_facts(world_snapshot: Dictionary) -> void:
	_last_candidates = evaluate_candidates(world_snapshot)
	_last_depth_rule = _depth_rule(world_snapshot)
	_last_player_assets = {}
	for player_variant in world_snapshot.get("players", []):
		if player_variant is Dictionary:
			var player_index := int((player_variant as Dictionary).get("player_index", -1))
			if player_index >= 0:
				_last_player_assets[str(player_index)] = _sanitize_private_assets((player_variant as Dictionary).get("audit_assets", {}) as Dictionary if (player_variant as Dictionary).get("audit_assets", {}) is Dictionary else {})


func _depth_rule(world_snapshot: Dictionary) -> Dictionary:
	var depth_tier_variant: Variant = world_snapshot.get("depth_tier", 3)
	var depth_id := str(depth_tier_variant).to_upper()
	if depth_tier_variant is int or depth_tier_variant is float:
		depth_id = DEPTH_ORDER[clampi(int(depth_tier_variant), 1, DEPTH_ORDER.size()) - 1]
	if depth_id not in DEPTH_ORDER:
		depth_id = "III"
	var table: Dictionary = _profile.get("victory_depth_table", {}) if _profile.get("victory_depth_table", {}) is Dictionary else {}
	var rule: Dictionary = (table.get(depth_id, {}) as Dictionary).duplicate(true) if table.get(depth_id, {}) is Dictionary else {}
	rule["depth_id"] = depth_id
	return rule


func _leading_candidates(candidates: Array) -> Array:
	var eligible: Array = []
	for candidate_variant in candidates:
		if candidate_variant is Dictionary and bool((candidate_variant as Dictionary).get("eligible", false)):
			eligible.append((candidate_variant as Dictionary).duplicate(true))
	if eligible.is_empty():
		return []
	_sort_candidates(eligible)
	var leaders: Array = []
	var best: Dictionary = eligible[0]
	for candidate_variant in eligible:
		if _candidates_tied(candidate_variant as Dictionary, best):
			leaders.append(candidate_variant)
	return leaders


func _sort_candidates(candidates: Array) -> void:
	_sort_candidates_by_order(candidates, COMPARISON_ORDER)


func _sort_candidates_by_order(candidates: Array, comparison_order: Array) -> void:
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		for key_variant in comparison_order:
			var key := str(key_variant)
			var left_value := int(left.get(key, 0))
			var right_value := int(right.get(key, 0))
			if left_value != right_value:
				return left_value > right_value
		return int(left.get("player_index", -1)) < int(right.get("player_index", -1))
	)


func _candidates_tied(left: Dictionary, right: Dictionary) -> bool:
	for key in COMPARISON_ORDER:
		if int(left.get(key, 0)) != int(right.get(key, 0)):
			return false
	return true


func _add_leaders_to_roster(leaders: Array) -> void:
	for leader_variant in leaders:
		if not (leader_variant is Dictionary):
			continue
		var player_index := int((leader_variant as Dictionary).get("player_index", -1))
		if player_index >= 0 and not _audit_roster.has(player_index):
			_audit_roster.append(player_index)
	_audit_roster.sort()


func _candidate_for(player_index: int) -> Dictionary:
	for candidate_variant in _last_candidates:
		if candidate_variant is Dictionary and int((candidate_variant as Dictionary).get("player_index", -1)) == player_index:
			return (candidate_variant as Dictionary).duplicate(true)
	return {}


func _qualification_remaining_seconds() -> float:
	if _state != STATE_QUALIFICATION or _qualification_elapsed_by_player.is_empty():
		return 0.0
	var greatest_elapsed := 0.0
	for elapsed_variant in _qualification_elapsed_by_player.values():
		greatest_elapsed = maxf(greatest_elapsed, float(elapsed_variant))
	return maxf(0.0, _timer_duration("victory_qualification") - greatest_elapsed)


func _pause_reasons(world_snapshot: Dictionary) -> Array:
	var reasons: Array = []
	var pause: Dictionary = world_snapshot.get("clock_pause", {}) if world_snapshot.get("clock_pause", {}) is Dictionary else {}
	for key in ["menu_paused", "readonly_paused", "forced_decision_paused", "monster_wager_world_frozen", "world_effective_paused"]:
		if bool(pause.get(key, false)):
			reasons.append(key)
	return reasons


func _advance_result(valid: bool, reason: String) -> Dictionary:
	return {
		"valid": valid,
		"reason": reason,
		"state": _state,
		"public_snapshot": public_snapshot(),
		"outcome_receipt": _outcome_receipt.duplicate(true),
	}


func _profile_from_resource() -> Dictionary:
	if ruleset_profile == null or not ruleset_profile.has_method("validation_snapshot") or not ruleset_profile.has_method("timing_rules"):
		return {}
	var validation_variant: Variant = ruleset_profile.call("validation_snapshot")
	var timing_variant: Variant = ruleset_profile.call("timing_rules")
	var result: Dictionary = (validation_variant as Dictionary).duplicate(true) if validation_variant is Dictionary else {}
	if timing_variant is Dictionary:
		result.merge(timing_variant as Dictionary, true)
	return result


func _clock_rules_from_resource() -> Dictionary:
	var result := {}
	if clock_domain_registry == null or not clock_domain_registry.has_method("debug_snapshot"):
		return result
	var debug_variant: Variant = clock_domain_registry.call("debug_snapshot")
	if not (debug_variant is Dictionary):
		return result
	for timer_variant in (debug_variant as Dictionary).get("timers", []):
		if timer_variant is Dictionary:
			result[str((timer_variant as Dictionary).get("timer_id", ""))] = (timer_variant as Dictionary).duplicate(true)
	return result


func _configuration_errors() -> Array:
	var errors: Array = []
	if str(_profile.get("ruleset_id", "")) != "v0.5":
		errors.append("ruleset_id_invalid")
	if int(_profile.get("region_control_threshold_bp", 0)) != 3000:
		errors.append("region_control_threshold_invalid")
	var table: Dictionary = _profile.get("victory_depth_table", {}) if _profile.get("victory_depth_table", {}) is Dictionary else {}
	for depth_id in DEPTH_ORDER:
		if not (table.get(depth_id, null) is Dictionary):
			errors.append("depth_rule_missing:%s" % depth_id)
	for timer_id in ["victory_qualification", "public_audit", "audit_failure_cooldown"]:
		var timer: Dictionary = _clock_rules.get(timer_id, {}) if _clock_rules.get(timer_id, {}) is Dictionary else {}
		if timer.is_empty() or str(timer.get("clock_domain", "")) != "world_effective":
			errors.append("clock_rule_invalid:%s" % timer_id)
		for behavior_key in ["menu_pause_behavior", "readonly_pause_behavior", "forced_decision_behavior", "monster_wager_freeze_behavior"]:
			if str(timer.get(behavior_key, "")) != "pause":
				errors.append("clock_pause_invalid:%s:%s" % [timer_id, behavior_key])
	if int(_profile.get("qualification_seconds", 0)) != int(_timer_duration("victory_qualification")):
		errors.append("qualification_duration_mismatch")
	if int(_profile.get("audit_seconds", 0)) != int(_timer_duration("public_audit")):
		errors.append("audit_duration_mismatch")
	if int(_profile.get("audit_failure_cooldown_seconds", 0)) != int(_timer_duration("audit_failure_cooldown")):
		errors.append("cooldown_duration_mismatch")
	return errors


func _timer_duration(timer_id: String) -> float:
	var timer: Dictionary = _clock_rules.get(timer_id, {}) if _clock_rules.get(timer_id, {}) is Dictionary else {}
	return maxf(0.0, float(timer.get("duration_seconds", 0.0)))


func _private_assets_for(player_index: int) -> Dictionary:
	return (_last_player_assets.get(str(player_index), {}) as Dictionary).duplicate(true) if _last_player_assets.get(str(player_index), {}) is Dictionary else {}


func _public_audit_assets(player_index: int) -> Dictionary:
	if _state not in [STATE_AUDIT, STATE_RESOLVED] or not _audit_roster.has(player_index):
		return {}
	return _private_assets_for(player_index)


func _sanitize_private_assets(source: Dictionary) -> Dictionary:
	var result := {
		"available_cents": int(source.get("available_cents", 0)),
		"escrow_cents": int(source.get("escrow_cents", 0)),
		"cash_ledger_cents": int(source.get("cash_ledger_cents", 0)),
		"project_positions": (source.get("project_positions", []) as Array).duplicate(true) if source.get("project_positions", []) is Array else [],
		"contracts": (source.get("contracts", []) as Array).duplicate(true) if source.get("contracts", []) is Array else [],
		"warehouses": (source.get("warehouses", []) as Array).duplicate(true) if source.get("warehouses", []) is Array else [],
		"financial_positions": (source.get("financial_positions", []) as Array).duplicate(true) if source.get("financial_positions", []) is Array else [],
		"hand_count": maxi(0, int(source.get("hand_count", 0))),
		"unit_count": maxi(0, int(source.get("unit_count", 0))),
	}
	return result if _is_data_only(result) else {}


func _public_outcome_receipt() -> Dictionary:
	return _outcome_receipt.duplicate(true) if not _outcome_receipt.is_empty() else {}


func _is_data_only(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT or value is Callable:
		return false
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
	elif value is Array:
		for item_variant in value:
			if not _is_data_only(item_variant):
				return false
	return true
