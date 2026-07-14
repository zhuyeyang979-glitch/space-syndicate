@tool
extends Node
class_name VictoryControlRuntimeController

const CONTROLLER_ID := "victory_control_v06"
const RULESET_ID := "v0.6"
const SAVE_SCHEMA_VERSION := 2
const OUTCOME_SCHEMA_VERSION := 2
const STATE_IDLE := "idle"
const STATE_QUALIFICATION := "qualification"
const STATE_AUDIT := "audit"
const STATE_RESOLVED := "resolved"
const VALID_STATES := [STATE_IDLE, STATE_QUALIFICATION, STATE_AUDIT, STATE_RESOLVED]
const COMPARISON_ORDER := ["top_k_gdp_per_minute_cents", "controlled_region_count", "cash_ledger_cents"]
const POST_SETTLEMENT_CHECKPOINT := "post_world_settlement"
# One microsecond matches the existing qualification boundary tolerance while
# remaining far below any configured gameplay tick or rule duration.
const TIMER_BOUNDARY_EPSILON_SECONDS := 0.000001

@export var ruleset_profile: Resource
@export var clock_domain_registry: Resource

var _world_bridge: Node
var _configured := false
var _profile: Dictionary = {}
var _clock_rules: Dictionary = {}
var _clock_registry_ruleset_id := ""
var _state := STATE_IDLE
var _qualification_elapsed_by_player: Dictionary = {}
var _audit_roster: Array = []
var _audit_remaining_seconds := 0.0
var _outcome_sequence := 0
var _outcome_receipt: Dictionary = {}
var _last_candidates: Array = []
var _last_player_assets: Dictionary = {}
var _last_victory_rule: Dictionary = {}
var _last_pause_reasons: Array = []
var _last_settlement_checkpoint := ""
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
	_outcome_sequence = 0
	_outcome_receipt = {}
	_last_candidates = []
	_last_player_assets = {}
	_last_victory_rule = {}
	_last_pause_reasons = []
	_last_settlement_checkpoint = ""
	_advance_count = 0


func evaluate_region_control(region_snapshot: Dictionary) -> Dictionary:
	var currency_scale := maxi(1, int(_profile.get("currency_scale", 100)))
	var region_gdp_cents := maxi(0, int(region_snapshot.get(
		"region_gdp_per_minute_cents",
		int(region_snapshot.get("region_gdp_per_minute", 0)) * currency_scale
	)))
	var lifecycle_state := str(region_snapshot.get("lifecycle_state", "active"))
	var destroyed := bool(region_snapshot.get("destroyed", false)) or lifecycle_state == "ruined"
	var player_gdp_by_index: Dictionary = region_snapshot.get("player_gdp_by_index", {}) if region_snapshot.get("player_gdp_by_index", {}) is Dictionary else {}
	var result := {
		"region_id": str(region_snapshot.get("region_id", "")),
		"district_index": int(region_snapshot.get("district_index", -1)),
		"lifecycle_state": lifecycle_state,
		"destroyed": destroyed,
		"surviving": not destroyed,
		"region_gdp_per_minute_cents": region_gdp_cents,
		"region_gdp_per_minute": int(round(float(region_gdp_cents) / float(currency_scale))),
		"controller_player_index": -1,
		"control_threshold_basis_points": int(_profile.get("region_control_threshold_bp", 3000)),
		"player_results": [],
	}
	if destroyed or region_gdp_cents <= 0:
		return result
	var highest_gdp_cents := 0
	var highest_players: Array = []
	var player_indices: Array = []
	for player_key_variant in player_gdp_by_index.keys():
		player_indices.append(int(str(player_key_variant)))
	player_indices.sort()
	for player_index_variant in player_indices:
		var player_index := int(player_index_variant)
		var player_gdp_cents := maxi(0, int(player_gdp_by_index.get(str(player_index), player_gdp_by_index.get(player_index, 0))))
		var share_basis_points := int(floor(float(player_gdp_cents) * 10000.0 / float(region_gdp_cents)))
		(result["player_results"] as Array).append({
			"player_index": player_index,
			"attributable_gdp_per_minute_cents": player_gdp_cents,
			"attributable_gdp_per_minute": int(round(float(player_gdp_cents) / float(currency_scale))),
			"share_basis_points": clampi(share_basis_points, 0, 10000),
		})
		if player_gdp_cents > highest_gdp_cents:
			highest_gdp_cents = player_gdp_cents
			highest_players = [player_index]
		elif player_gdp_cents > 0 and player_gdp_cents == highest_gdp_cents:
			highest_players.append(player_index)
	if highest_players.size() != 1:
		return result
	var highest_player := int(highest_players[0])
	for player_result_variant in result["player_results"]:
		if not (player_result_variant is Dictionary):
			continue
		var player_result: Dictionary = player_result_variant
		if int(player_result.get("player_index", -1)) == highest_player and int(player_result.get("share_basis_points", 0)) >= int(result["control_threshold_basis_points"]):
			result["controller_player_index"] = highest_player
			break
	return result


func victory_rule_for_world(world_snapshot: Dictionary) -> Dictionary:
	var surviving_region_count := 0
	for region_variant in world_snapshot.get("regions", []):
		if not (region_variant is Dictionary):
			continue
		var region: Dictionary = region_variant
		if not bool(region.get("destroyed", false)) and str(region.get("lifecycle_state", "active")) != "ruined":
			surviving_region_count += 1
	var coverage_basis_points := clampi(int(_profile.get("dynamic_victory_coverage_bp", 4000)), 1, 10000)
	var required_region_count := 0
	if surviving_region_count > 0:
		required_region_count = maxi(1, ceili(float(surviving_region_count * coverage_basis_points) / 10000.0))
	var gdp_per_region := maxi(1, int(_profile.get("gdp_per_required_region_per_minute", 36)))
	var currency_scale := maxi(1, int(_profile.get("currency_scale", 100)))
	return {
		"surviving_region_count": surviving_region_count,
		"coverage_basis_points": coverage_basis_points,
		"required_region_count": required_region_count,
		"gdp_per_required_region_per_minute": gdp_per_region,
		"required_top_k_gdp_per_minute": required_region_count * gdp_per_region,
		"required_top_k_gdp_per_minute_cents": required_region_count * gdp_per_region * currency_scale,
		"ordinary_victory_paused": surviving_region_count <= 0,
	}


func evaluate_candidates(world_snapshot: Dictionary) -> Array:
	if not _configured or not _is_data_only(world_snapshot):
		return []
	var victory_rule := victory_rule_for_world(world_snapshot)
	var currency_scale := maxi(1, int(_profile.get("currency_scale", 100)))
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
			"region_shares": [],
			"controlled_region_count": 0,
			"top_k_gdp_per_minute_cents": 0,
			"top_k_gdp_per_minute": 0,
			"top_n_gdp_per_minute": 0,
			"required_region_count": int(victory_rule.get("required_region_count", 0)),
			"required_top_k_gdp_per_minute_cents": int(victory_rule.get("required_top_k_gdp_per_minute_cents", 0)),
			"required_top_k_gdp_per_minute": int(victory_rule.get("required_top_k_gdp_per_minute", 0)),
			"required_top_n_gdp_per_minute": int(victory_rule.get("required_top_k_gdp_per_minute", 0)),
			"cash_ledger_cents": int(player.get("cash_ledger_cents", 0)),
			"eligible": false,
		}
	for region_variant in world_snapshot.get("regions", []):
		if not (region_variant is Dictionary):
			continue
		var control := evaluate_region_control(region_variant as Dictionary)
		for player_key_variant in player_rows.keys():
			var player_key := str(player_key_variant)
			var player_index := int(player_key)
			var share_row := _player_region_row(control, player_index)
			var row: Dictionary = player_rows[player_key]
			(row["region_shares"] as Array).append({
				"region_id": str(control.get("region_id", "")),
				"district_index": int(control.get("district_index", -1)),
				"surviving": bool(control.get("surviving", false)),
				"attributable_gdp_per_minute_cents": int(share_row.get("attributable_gdp_per_minute_cents", 0)),
				"attributable_gdp_per_minute": int(share_row.get("attributable_gdp_per_minute", 0)),
				"share_basis_points": int(share_row.get("share_basis_points", 0)),
				"controls": int(control.get("controller_player_index", -1)) == player_index,
			})
			player_rows[player_key] = row
		var controller_player := int(control.get("controller_player_index", -1))
		var controller_key := str(controller_player)
		if controller_player < 0 or not player_rows.has(controller_key):
			continue
		var controlled_row := _player_region_row(control, controller_player)
		var controller_result: Dictionary = player_rows[controller_key]
		(controller_result["controlled_regions"] as Array).append({
			"region_id": str(control.get("region_id", "")),
			"district_index": int(control.get("district_index", -1)),
			"attributable_gdp_per_minute_cents": int(controlled_row.get("attributable_gdp_per_minute_cents", 0)),
			"attributable_gdp_per_minute": int(controlled_row.get("attributable_gdp_per_minute", 0)),
			"share_basis_points": int(controlled_row.get("share_basis_points", 0)),
		})
		player_rows[controller_key] = controller_result
	var candidates: Array = []
	var player_keys: Array = player_rows.keys()
	player_keys.sort_custom(func(left: Variant, right: Variant) -> bool: return int(str(left)) < int(str(right)))
	for player_key_variant in player_keys:
		var candidate: Dictionary = player_rows[player_key_variant]
		var controlled_regions: Array = candidate.get("controlled_regions", []) as Array
		controlled_regions.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_gdp := int(left.get("attributable_gdp_per_minute_cents", 0))
			var right_gdp := int(right.get("attributable_gdp_per_minute_cents", 0))
			return left_gdp > right_gdp if left_gdp != right_gdp else int(left.get("district_index", -1)) < int(right.get("district_index", -1))
		)
		candidate["controlled_regions"] = controlled_regions
		candidate["controlled_region_count"] = controlled_regions.size()
		var top_k_gdp_cents := 0
		for region_index in range(mini(controlled_regions.size(), int(candidate.get("required_region_count", 0)))):
			top_k_gdp_cents += int((controlled_regions[region_index] as Dictionary).get("attributable_gdp_per_minute_cents", 0))
		var top_k_gdp := int(round(float(top_k_gdp_cents) / float(currency_scale)))
		candidate["top_k_gdp_per_minute_cents"] = top_k_gdp_cents
		candidate["top_k_gdp_per_minute"] = top_k_gdp
		candidate["top_n_gdp_per_minute"] = top_k_gdp
		candidate["eligible"] = not bool(candidate.get("eliminated", false)) \
			and not bool(victory_rule.get("ordinary_victory_paused", true)) \
			and int(candidate.get("controlled_region_count", 0)) >= int(candidate.get("required_region_count", 0)) \
			and top_k_gdp_cents >= int(candidate.get("required_top_k_gdp_per_minute_cents", 0))
		candidate["victory_rule"] = victory_rule.duplicate(true)
		candidates.append(candidate)
	return candidates


func advance_world_effective(delta_seconds: float, world_snapshot: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(world_snapshot):
		return _advance_result(false, "controller_not_ready_or_snapshot_invalid")
	_capture_world_facts(world_snapshot)
	_last_pause_reasons = _pause_reasons(world_snapshot)
	_last_settlement_checkpoint = str(world_snapshot.get("settlement_checkpoint", ""))
	if _state == STATE_RESOLVED or not _last_pause_reasons.is_empty():
		return _advance_result(true, "paused" if not _last_pause_reasons.is_empty() else "")
	if delta_seconds < 0.0:
		return _advance_result(false, "negative_delta_invalid")
	if delta_seconds <= 0.0 and not (_state == STATE_AUDIT and _timer_has_elapsed(_audit_remaining_seconds)):
		return _advance_result(true, "")
	_advance_count += 1
	var reason := ""
	if _state == STATE_AUDIT:
		reason = _advance_audit(delta_seconds, world_snapshot)
	else:
		_advance_qualification(delta_seconds)
	return _advance_result(true, reason)


func resolve_special_outcome(reason_code: String, world_snapshot: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(world_snapshot) or not _outcome_receipt.is_empty():
		return _outcome_receipt.duplicate(true)
	_capture_world_facts(world_snapshot)
	var active_candidates: Array = []
	for candidate_variant in _last_candidates:
		if candidate_variant is Dictionary and not bool((candidate_variant as Dictionary).get("eliminated", false)):
			active_candidates.append((candidate_variant as Dictionary).duplicate(true))
	var winners: Array = []
	var comparison_order: Array = COMPARISON_ORDER.duplicate()
	if reason_code == "last_survivor" and active_candidates.size() == 1:
		winners = [int((active_candidates[0] as Dictionary).get("player_index", -1))]
	elif reason_code == "planet_destroyed" and bool(world_snapshot.get("irreversible_planet_destruction_triggered", false)) and bool(world_snapshot.get("scenario_allows_cash_fallback", false)):
		comparison_order = ["cash_ledger_cents"]
		_sort_candidates_by_order(active_candidates, comparison_order)
		if not active_candidates.is_empty():
			var best_cash := int((active_candidates[0] as Dictionary).get("cash_ledger_cents", 0))
			for candidate_variant in active_candidates:
				if int((candidate_variant as Dictionary).get("cash_ledger_cents", 0)) == best_cash:
					winners.append(int((candidate_variant as Dictionary).get("player_index", -1)))
	if winners.is_empty():
		return {}
	_finalize_outcome(reason_code, active_candidates, winners, comparison_order)
	return _outcome_receipt.duplicate(true)


func preview_rankings(world_snapshot: Dictionary, eligible_only := false) -> Array:
	var candidates := evaluate_candidates(world_snapshot)
	if eligible_only:
		candidates = candidates.filter(func(candidate: Dictionary) -> bool: return bool(candidate.get("eligible", false)))
	_sort_candidates(candidates)
	return candidates


func timer_duration(timer_id: String) -> float:
	return _timer_duration(timer_id)


func public_snapshot(_viewer_index := -1) -> Dictionary:
	var audit_revealed_player_indices := _authoritative_audit_visibility_player_indices()
	var roster_entries: Array = []
	for player_index_variant in _audit_roster:
		var player_index := int(player_index_variant)
		var candidate := _candidate_for(player_index)
		if candidate.is_empty():
			continue
		var entry := _public_candidate_projection(candidate)
		if audit_revealed_player_indices.has(player_index):
			entry["cash_visibility"] = "public_audit"
			entry["cash_ledger_cents"] = int(candidate.get("cash_ledger_cents", 0))
		roster_entries.append(entry)
	var result := {
		"controller_id": CONTROLLER_ID,
		"ruleset_id": str(_profile.get("ruleset_id", "")),
		"state": _state,
		"victory_rule": _last_victory_rule.duplicate(true),
		"qualification_remaining_seconds": _qualification_remaining_seconds(),
		"audit_remaining_seconds": _audit_remaining_seconds,
		"audit_roster": _audit_roster.duplicate(),
		"audit_entries": roster_entries,
		"paused": not _last_pause_reasons.is_empty(),
		"pause_reasons": _last_pause_reasons.duplicate(),
		"settlement_checkpoint": _last_settlement_checkpoint,
		"outcome_receipt": _public_outcome_receipt(audit_revealed_player_indices),
		"visibility_scope": "public",
	}
	if not audit_revealed_player_indices.is_empty():
		result["cash_visibility"] = "public_audit"
		result["audit_revealed_player_indices"] = audit_revealed_player_indices.duplicate()
		result["rank_entries"] = roster_entries.duplicate(true)
	return result


func private_snapshot(viewer_index: int) -> Dictionary:
	var result := public_snapshot(viewer_index)
	result["viewer_player_index"] = viewer_index
	result["own_candidate"] = _public_candidate_projection(_candidate_for(viewer_index))
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
			"ruleset_id": RULESET_ID,
			"state": _state,
			"qualification_elapsed_by_player": _qualification_elapsed_by_player.duplicate(true),
			"audit_roster": _audit_roster.duplicate(),
			"audit_remaining_seconds": _audit_remaining_seconds,
			"outcome_sequence": _outcome_sequence,
			"outcome_receipt": _outcome_receipt.duplicate(true),
		}
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var payload: Dictionary = data.get("victory_control_runtime", data) if data.get("victory_control_runtime", data) is Dictionary else {}
	if payload.is_empty():
		reset_state()
		return {"applied": true, "legacy_default": true, "state": _state}
	if not _is_data_only(payload):
		return {"applied": false, "reason": "victory_save_not_pure_data"}
	if int(payload.get("schema_version", 0)) != SAVE_SCHEMA_VERSION or str(payload.get("ruleset_id", "")) != RULESET_ID:
		return {"applied": false, "reason": "victory_save_header_invalid"}
	var saved_state := str(payload.get("state", STATE_IDLE))
	if saved_state not in VALID_STATES:
		return {"applied": false, "reason": "victory_state_invalid"}
	var qualification_validation := _validated_saved_qualification(payload.get("qualification_elapsed_by_player", null))
	if not bool(qualification_validation.get("valid", false)):
		return {"applied": false, "reason": str(qualification_validation.get("reason", "victory_qualification_invalid"))}
	var roster_validation := _validated_saved_audit_roster(payload.get("audit_roster", null))
	if not bool(roster_validation.get("valid", false)):
		return {"applied": false, "reason": str(roster_validation.get("reason", "victory_audit_roster_invalid"))}
	var next_audit_roster: Array = roster_validation.get("roster", []) as Array
	if saved_state in [STATE_IDLE, STATE_QUALIFICATION] and not next_audit_roster.is_empty():
		return {"applied": false, "reason": "victory_audit_roster_state_mismatch"}
	if saved_state == STATE_AUDIT and next_audit_roster.is_empty():
		return {"applied": false, "reason": "victory_audit_roster_missing"}
	var remaining_variant: Variant = payload.get("audit_remaining_seconds", null)
	if typeof(remaining_variant) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(remaining_variant)):
		return {"applied": false, "reason": "victory_audit_remaining_invalid"}
	var public_audit_duration := _timer_duration("public_audit")
	var next_audit_remaining := float(remaining_variant)
	if next_audit_remaining < 0.0 or next_audit_remaining > public_audit_duration + TIMER_BOUNDARY_EPSILON_SECONDS:
		return {"applied": false, "reason": "victory_audit_remaining_out_of_range"}
	var sequence_variant: Variant = payload.get("outcome_sequence", null)
	if typeof(sequence_variant) != TYPE_INT or int(sequence_variant) < 0:
		return {"applied": false, "reason": "victory_outcome_sequence_invalid"}
	var receipt_validation := _validated_saved_outcome_receipt(payload.get("outcome_receipt", null), saved_state, next_audit_roster)
	if not bool(receipt_validation.get("valid", false)):
		return {"applied": false, "reason": str(receipt_validation.get("reason", "victory_outcome_receipt_invalid"))}
	# Apply only after the whole envelope has passed validation. Runtime world facts
	# are deliberately not restored: the bridge must provide fresh authoritative
	# candidates before any audit cash can be projected again.
	_state = saved_state
	_qualification_elapsed_by_player = (qualification_validation.get("qualification", {}) as Dictionary).duplicate(true)
	_audit_roster = next_audit_roster.duplicate()
	_audit_remaining_seconds = _normalized_timer_remaining(next_audit_remaining, public_audit_duration)
	_outcome_sequence = int(sequence_variant)
	_outcome_receipt = (receipt_validation.get("receipt", {}) as Dictionary).duplicate(true)
	_last_candidates = []
	_last_player_assets = {}
	_last_victory_rule = {}
	_last_pause_reasons = []
	_last_settlement_checkpoint = ""
	_advance_count = 0
	return {"applied": true, "legacy_default": false, "state": _state}


func debug_snapshot() -> Dictionary:
	return {
		"controller_id": CONTROLLER_ID,
		"controller_ready": _configured,
		"controller_authoritative": _configured,
		"ruleset_id": str(_profile.get("ruleset_id", "")),
		"state": _state,
		"victory_rule": _last_victory_rule.duplicate(true),
		"qualification_candidate_count": _qualification_elapsed_by_player.size(),
		"audit_roster_count": _audit_roster.size(),
		"audit_remaining_seconds": _audit_remaining_seconds,
		"outcome_emitted": not _outcome_receipt.is_empty(),
		"outcome_sequence": _outcome_sequence,
		"advance_count": _advance_count,
		"timer_boundary_epsilon_seconds": TIMER_BOUNDARY_EPSILON_SECONDS,
		"world_bridge_ready": _world_bridge != null,
		"owns_gdp_formula": false,
		"owns_region_lifecycle": false,
		"owns_cash_mutation": false,
		"owns_victory_state": true,
		"owns_outcome_ordering": true,
		"owns_public_audit_roster": true,
		"owns_public_audit_cash_authorization": true,
		"audit_cash_requires_fresh_world_facts": true,
		"dynamic_denominator_enabled": true,
		"fixed_depth_table_present": false,
		"audit_failure_cooldown_present": false,
		"legacy_cash_goal_fallback_used": false,
	}


func _advance_qualification(delta_seconds: float) -> void:
	var next_elapsed := {}
	var reached_players: Array = []
	for candidate_variant in _last_candidates:
		if not (candidate_variant is Dictionary) or not bool((candidate_variant as Dictionary).get("eligible", false)):
			continue
		var player_index := int((candidate_variant as Dictionary).get("player_index", -1))
		var key := str(player_index)
		var elapsed := float(_qualification_elapsed_by_player.get(key, 0.0)) + delta_seconds
		if _timer_has_reached(elapsed, _timer_duration("victory_qualification")):
			reached_players.append(player_index)
		else:
			next_elapsed[key] = elapsed
	_qualification_elapsed_by_player = next_elapsed
	if reached_players.is_empty():
		_state = STATE_QUALIFICATION if not next_elapsed.is_empty() else STATE_IDLE
		return
	_state = STATE_AUDIT
	_audit_remaining_seconds = _timer_duration("public_audit")
	_audit_roster = []
	for player_index_variant in reached_players:
		_add_player_to_roster(int(player_index_variant))


func _advance_audit(delta_seconds: float, world_snapshot: Dictionary) -> String:
	var next_elapsed := {}
	for candidate_variant in _last_candidates:
		if not (candidate_variant is Dictionary):
			continue
		var candidate: Dictionary = candidate_variant
		var player_index := int(candidate.get("player_index", -1))
		if _audit_roster.has(player_index) or not bool(candidate.get("eligible", false)):
			continue
		var key := str(player_index)
		var elapsed := float(_qualification_elapsed_by_player.get(key, 0.0)) + delta_seconds
		if _timer_has_reached(elapsed, _timer_duration("victory_qualification")):
			_add_player_to_roster(player_index)
		else:
			next_elapsed[key] = elapsed
	_qualification_elapsed_by_player = next_elapsed
	_audit_remaining_seconds = _normalized_timer_remaining(
		_audit_remaining_seconds - delta_seconds,
		_timer_duration("public_audit")
	)
	if not _timer_has_elapsed(_audit_remaining_seconds):
		return ""
	if str(world_snapshot.get("settlement_checkpoint", "")) != POST_SETTLEMENT_CHECKPOINT:
		return "awaiting_post_world_settlement_checkpoint"
	var finalists: Array = []
	for player_index_variant in _audit_roster:
		var candidate := _candidate_for(int(player_index_variant))
		if not candidate.is_empty() and bool(candidate.get("eligible", false)) and not bool(candidate.get("eliminated", false)):
			finalists.append(candidate)
	if finalists.is_empty():
		_state = STATE_IDLE
		_audit_roster = []
		_qualification_elapsed_by_player = {}
		_audit_remaining_seconds = 0.0
		return "audit_completed_without_finalist"
	_sort_candidates(finalists)
	var winners: Array = []
	var best: Dictionary = finalists[0]
	for candidate_variant in finalists:
		if _candidates_tied(candidate_variant as Dictionary, best):
			winners.append(int((candidate_variant as Dictionary).get("player_index", -1)))
	_finalize_outcome("public_audit_complete", finalists, winners, COMPARISON_ORDER)
	return ""


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
			"top_k_gdp_per_minute_cents": int(candidate.get("top_k_gdp_per_minute_cents", 0)),
			"top_k_gdp_per_minute": int(candidate.get("top_k_gdp_per_minute", 0)),
			"top_n_gdp_per_minute": int(candidate.get("top_k_gdp_per_minute", 0)),
			"controlled_region_count": int(candidate.get("controlled_region_count", 0)),
			"cash_ledger_cents": int(candidate.get("cash_ledger_cents", 0)),
			"winner": winner_player_indices.has(player_index),
		})
	_outcome_receipt = {
		"outcome_id": "victory.v06.%d" % _outcome_sequence,
		"schema_version": OUTCOME_SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"reason_code": reason_code,
		"winner_player_indices": winner_player_indices.duplicate(),
		"co_victory": winner_player_indices.size() > 1,
		"comparison_order": comparison_order.duplicate(),
		"rankings": rankings,
		"audit_evidence": {
			"victory_rule": _last_victory_rule.duplicate(true),
			"audit_roster": _audit_roster.duplicate(),
			"settlement_checkpoint": _last_settlement_checkpoint,
		},
		"visibility_scope": "public",
	}
	_state = STATE_RESOLVED


func _capture_world_facts(world_snapshot: Dictionary) -> void:
	_last_candidates = evaluate_candidates(world_snapshot)
	_last_victory_rule = victory_rule_for_world(world_snapshot)
	_last_player_assets = {}
	for player_variant in world_snapshot.get("players", []):
		if not (player_variant is Dictionary):
			continue
		var player: Dictionary = player_variant
		var player_index := int(player.get("player_index", -1))
		if player_index >= 0:
			_last_player_assets[str(player_index)] = _sanitize_private_assets(player.get("audit_assets", {}) as Dictionary if player.get("audit_assets", {}) is Dictionary else {})


func _player_region_row(control: Dictionary, player_index: int) -> Dictionary:
	for row_variant in control.get("player_results", []):
		if row_variant is Dictionary and int((row_variant as Dictionary).get("player_index", -1)) == player_index:
			return (row_variant as Dictionary).duplicate(true)
	return {}


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
	for key_variant in COMPARISON_ORDER:
		var key := str(key_variant)
		if int(left.get(key, 0)) != int(right.get(key, 0)):
			return false
	return true


func _add_player_to_roster(player_index: int) -> void:
	if player_index >= 0 and not _audit_roster.has(player_index):
		_audit_roster.append(player_index)
		_audit_roster.sort()


func _candidate_for(player_index: int) -> Dictionary:
	for candidate_variant in _last_candidates:
		if candidate_variant is Dictionary and int((candidate_variant as Dictionary).get("player_index", -1)) == player_index:
			return (candidate_variant as Dictionary).duplicate(true)
	return {}


func _qualification_remaining_seconds() -> float:
	if _state not in [STATE_QUALIFICATION, STATE_AUDIT] or _qualification_elapsed_by_player.is_empty():
		return 0.0
	var greatest_elapsed := 0.0
	for elapsed_variant in _qualification_elapsed_by_player.values():
		greatest_elapsed = maxf(greatest_elapsed, float(elapsed_variant))
	var duration := _timer_duration("victory_qualification")
	return _normalized_timer_remaining(duration - greatest_elapsed, duration)


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
	if ruleset_profile == null:
		return {}
	var result: Dictionary = {}
	if ruleset_profile.has_method("debug_snapshot"):
		var debug_variant: Variant = ruleset_profile.call("debug_snapshot")
		if debug_variant is Dictionary:
			var debug: Dictionary = debug_variant
			if debug.get("identity", {}) is Dictionary:
				result.merge(debug.get("identity", {}) as Dictionary, true)
			if debug.get("victory", {}) is Dictionary:
				result.merge(debug.get("victory", {}) as Dictionary, true)
	if result.is_empty() and ruleset_profile.has_method("validation_snapshot"):
		var validation_variant: Variant = ruleset_profile.call("validation_snapshot")
		if validation_variant is Dictionary:
			result = (validation_variant as Dictionary).duplicate(true)
		if ruleset_profile.has_method("victory_rules"):
			var victory_variant: Variant = ruleset_profile.call("victory_rules")
			if victory_variant is Dictionary:
				result.merge(victory_variant as Dictionary, true)
	return result


func _clock_rules_from_resource() -> Dictionary:
	var result := {}
	_clock_registry_ruleset_id = ""
	if clock_domain_registry == null or not clock_domain_registry.has_method("debug_snapshot"):
		return result
	var debug_variant: Variant = clock_domain_registry.call("debug_snapshot")
	if not (debug_variant is Dictionary):
		return result
	_clock_registry_ruleset_id = str((debug_variant as Dictionary).get("ruleset_id", ""))
	for timer_variant in (debug_variant as Dictionary).get("timers", []):
		if timer_variant is Dictionary:
			result[str((timer_variant as Dictionary).get("timer_id", ""))] = (timer_variant as Dictionary).duplicate(true)
	return result


func _configuration_errors() -> Array:
	var errors: Array = []
	if str(_profile.get("ruleset_id", "")) != RULESET_ID:
		errors.append("ruleset_id_invalid")
	if _clock_registry_ruleset_id != RULESET_ID:
		errors.append("clock_registry_ruleset_invalid")
	if int(_profile.get("currency_scale", 0)) != 100:
		errors.append("currency_scale_invalid")
	if int(_profile.get("region_control_threshold_bp", 0)) != 3000:
		errors.append("region_control_threshold_invalid")
	if int(_profile.get("dynamic_victory_coverage_bp", 0)) != 4000:
		errors.append("dynamic_victory_coverage_invalid")
	if int(_profile.get("gdp_per_required_region_per_minute", 0)) != 36:
		errors.append("gdp_per_required_region_invalid")
	for timer_id in ["victory_qualification", "public_audit"]:
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
	return errors


func _timer_duration(timer_id: String) -> float:
	var timer: Dictionary = _clock_rules.get(timer_id, {}) if _clock_rules.get(timer_id, {}) is Dictionary else {}
	return maxf(0.0, float(timer.get("duration_seconds", 0.0)))


func _timer_has_reached(elapsed_seconds: float, duration_seconds: float) -> bool:
	return elapsed_seconds + TIMER_BOUNDARY_EPSILON_SECONDS >= duration_seconds


func _timer_has_elapsed(remaining_seconds: float) -> bool:
	return remaining_seconds <= TIMER_BOUNDARY_EPSILON_SECONDS


func _normalized_timer_remaining(remaining_seconds: float, duration_seconds: float) -> float:
	var clamped := clampf(remaining_seconds, 0.0, maxf(0.0, duration_seconds))
	return 0.0 if _timer_has_elapsed(clamped) else clamped


func _private_assets_for(player_index: int) -> Dictionary:
	return (_last_player_assets.get(str(player_index), {}) as Dictionary).duplicate(true) if _last_player_assets.get(str(player_index), {}) is Dictionary else {}


func _authoritative_audit_visibility_player_indices() -> Array:
	if _state not in [STATE_AUDIT, STATE_RESOLVED] or _audit_roster.is_empty():
		return []
	var result: Array = []
	var previous_player_index := -1
	for player_index_variant in _audit_roster:
		if typeof(player_index_variant) != TYPE_INT:
			return []
		var player_index := int(player_index_variant)
		if player_index < 0 or player_index <= previous_player_index:
			return []
		var candidate := _candidate_for(player_index)
		if candidate.is_empty() or typeof(candidate.get("cash_ledger_cents", null)) != TYPE_INT:
			return []
		result.append(player_index)
		previous_player_index = player_index
	return result


func _public_candidate_projection(candidate: Dictionary) -> Dictionary:
	if candidate.is_empty():
		return {}
	return {
		"player_index": int(candidate.get("player_index", -1)),
		"eligible": bool(candidate.get("eligible", false)),
		"top_k_gdp_per_minute_cents": int(candidate.get("top_k_gdp_per_minute_cents", 0)),
		"top_k_gdp_per_minute": int(candidate.get("top_k_gdp_per_minute", 0)),
		"top_n_gdp_per_minute": int(candidate.get("top_k_gdp_per_minute", 0)),
		"controlled_region_count": int(candidate.get("controlled_region_count", 0)),
		"controlled_regions": _safe_array(candidate.get("controlled_regions", [])),
		"region_shares": _safe_array(candidate.get("region_shares", [])),
	}


func _sanitize_private_assets(source: Dictionary) -> Dictionary:
	var result := {
		"available_cents": int(source.get("available_cents", 0)),
		"escrow_cents": int(source.get("escrow_cents", 0)),
		"cash_ledger_cents": int(source.get("cash_ledger_cents", 0)),
		"ordinary_hand": _safe_array(source.get("ordinary_hand", [])),
		"facilities": _safe_array(source.get("facilities", [])),
		"installations": _safe_array(source.get("installations", [])),
		"commodity_inventory": _safe_array(source.get("commodity_inventory", [])),
		"color_gdp": _safe_dictionary(source.get("color_gdp", {})),
		"units": _safe_array(source.get("units", [])),
		"contracts": _safe_array(source.get("contracts", [])),
		"financial_positions": _safe_array(source.get("financial_positions", [])),
	}
	return result if _is_data_only(result) else {}


func _safe_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array and _is_data_only(value) else []


func _safe_dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary and _is_data_only(value) else {}


func _public_outcome_receipt(audit_revealed_player_indices: Array = []) -> Dictionary:
	if _outcome_receipt.is_empty():
		return {}
	var rankings: Array = []
	for ranking_variant in _outcome_receipt.get("rankings", []):
		if not (ranking_variant is Dictionary):
			continue
		var ranking: Dictionary = ranking_variant
		var public_ranking := {
			"player_index": int(ranking.get("player_index", -1)),
			"top_k_gdp_per_minute_cents": int(ranking.get("top_k_gdp_per_minute_cents", 0)),
			"top_k_gdp_per_minute": int(ranking.get("top_k_gdp_per_minute", 0)),
			"top_n_gdp_per_minute": int(ranking.get("top_k_gdp_per_minute", 0)),
			"controlled_region_count": int(ranking.get("controlled_region_count", 0)),
			"winner": bool(ranking.get("winner", false)),
		}
		var player_index := int(public_ranking.get("player_index", -1))
		if audit_revealed_player_indices.has(player_index):
			var candidate := _candidate_for(player_index)
			if not candidate.is_empty() and typeof(candidate.get("cash_ledger_cents", null)) == TYPE_INT:
				public_ranking["cash_visibility"] = "public_audit"
				public_ranking["cash_ledger_cents"] = int(candidate.get("cash_ledger_cents", 0))
		rankings.append(public_ranking)
	var internal_evidence: Dictionary = _outcome_receipt.get("audit_evidence", {}) if _outcome_receipt.get("audit_evidence", {}) is Dictionary else {}
	var result := {
		"outcome_id": str(_outcome_receipt.get("outcome_id", "")),
		"schema_version": str(_outcome_receipt.get("schema_version", "")),
		"ruleset_id": str(_outcome_receipt.get("ruleset_id", "")),
		"reason_code": str(_outcome_receipt.get("reason_code", "")),
		"winner_player_indices": _safe_array(_outcome_receipt.get("winner_player_indices", [])),
		"co_victory": bool(_outcome_receipt.get("co_victory", false)),
		"comparison_order": _safe_array(_outcome_receipt.get("comparison_order", [])),
		"rankings": rankings,
		"audit_evidence": {
			"victory_rule": _safe_dictionary(internal_evidence.get("victory_rule", {})),
			"audit_roster": _safe_array(internal_evidence.get("audit_roster", [])),
			"settlement_checkpoint": str(internal_evidence.get("settlement_checkpoint", "")),
		},
		"visibility_scope": "public",
	}
	if not audit_revealed_player_indices.is_empty():
		result["cash_visibility"] = "public_audit"
		result["audit_revealed_player_indices"] = audit_revealed_player_indices.duplicate()
	return result if _is_data_only(result) else {}


func _validated_saved_qualification(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not _is_data_only(value):
		return {"valid": false, "reason": "victory_qualification_invalid"}
	var result := {}
	var qualification_duration := _timer_duration("victory_qualification")
	for key_variant in (value as Dictionary).keys():
		var key := str(key_variant)
		if not key.is_valid_int() or int(key) < 0:
			return {"valid": false, "reason": "victory_qualification_player_invalid"}
		var elapsed_variant: Variant = (value as Dictionary)[key_variant]
		if typeof(elapsed_variant) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(elapsed_variant)):
			return {"valid": false, "reason": "victory_qualification_elapsed_invalid"}
		var elapsed := float(elapsed_variant)
		if elapsed < 0.0 or elapsed >= qualification_duration + TIMER_BOUNDARY_EPSILON_SECONDS:
			return {"valid": false, "reason": "victory_qualification_elapsed_out_of_range"}
		result[key] = elapsed
	return {"valid": true, "qualification": result}


func _validated_saved_audit_roster(value: Variant) -> Dictionary:
	if not (value is Array) or not _is_data_only(value):
		return {"valid": false, "reason": "victory_audit_roster_invalid"}
	var result: Array = []
	var previous_player_index := -1
	for player_index_variant in value as Array:
		if typeof(player_index_variant) != TYPE_INT:
			return {"valid": false, "reason": "victory_audit_roster_player_invalid"}
		var player_index := int(player_index_variant)
		if player_index < 0 or player_index <= previous_player_index:
			return {"valid": false, "reason": "victory_audit_roster_not_stable_unique"}
		result.append(player_index)
		previous_player_index = player_index
	return {"valid": true, "roster": result}


func _validated_saved_outcome_receipt(value: Variant, saved_state: String, audit_roster: Array) -> Dictionary:
	if not (value is Dictionary) or not _is_data_only(value):
		return {"valid": false, "reason": "victory_outcome_receipt_invalid"}
	var receipt := (value as Dictionary).duplicate(true)
	if saved_state != STATE_RESOLVED:
		return {"valid": receipt.is_empty(), "reason": "" if receipt.is_empty() else "victory_outcome_receipt_state_mismatch", "receipt": {}}
	if receipt.is_empty() or str(receipt.get("ruleset_id", "")) != RULESET_ID:
		return {"valid": false, "reason": "victory_resolved_receipt_missing"}
	if not receipt.get("rankings", null) is Array or not receipt.get("winner_player_indices", null) is Array:
		return {"valid": false, "reason": "victory_outcome_rankings_invalid"}
	var ranking_players: Array = []
	for ranking_variant in receipt.get("rankings", []):
		if not (ranking_variant is Dictionary):
			return {"valid": false, "reason": "victory_outcome_ranking_invalid"}
		var ranking: Dictionary = ranking_variant
		var player_index_variant: Variant = ranking.get("player_index", null)
		var cash_variant: Variant = ranking.get("cash_ledger_cents", null)
		if typeof(player_index_variant) != TYPE_INT or int(player_index_variant) < 0 or ranking_players.has(int(player_index_variant)):
			return {"valid": false, "reason": "victory_outcome_ranking_player_invalid"}
		if typeof(cash_variant) != TYPE_INT:
			return {"valid": false, "reason": "victory_outcome_ranking_cash_invalid"}
		ranking_players.append(int(player_index_variant))
	for winner_variant in receipt.get("winner_player_indices", []):
		if typeof(winner_variant) != TYPE_INT or not ranking_players.has(int(winner_variant)):
			return {"valid": false, "reason": "victory_outcome_winner_invalid"}
	var evidence: Dictionary = receipt.get("audit_evidence", {}) if receipt.get("audit_evidence", {}) is Dictionary else {}
	var evidence_roster_validation := _validated_saved_audit_roster(evidence.get("audit_roster", null))
	if not bool(evidence_roster_validation.get("valid", false)) or (evidence_roster_validation.get("roster", []) as Array) != audit_roster:
		return {"valid": false, "reason": "victory_outcome_audit_roster_mismatch"}
	return {"valid": true, "receipt": receipt}


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
