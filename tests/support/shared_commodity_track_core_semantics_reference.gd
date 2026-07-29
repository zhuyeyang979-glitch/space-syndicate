extends RefCounted
class_name SharedCommodityTrackCoreSemanticsReference

const COLOR_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const TOTAL_BASIS_POINTS := 10_000
const MARKET_CYCLE_DURATION_US := 180_000_000
const NORMAL_INFLUENCE_BP := 300
const LEAD_INFLUENCE_BP := 600
const NORMAL_CARD_HAND_LIMIT := 5
const COMMODITY_CARD_HAND_LIMIT := 5
const MAX_COMMODITY_LEVEL := 4


static func initial_distribution() -> Dictionary:
	var result := {}
	var quotient := int(float(TOTAL_BASIS_POINTS) / float(COLOR_IDS.size()))
	var remainder := TOTAL_BASIS_POINTS % COLOR_IDS.size()
	for index in range(COLOR_IDS.size()):
		result[COLOR_IDS[index]] = quotient + (1 if index < remainder else 0)
	return result


static func zero_distribution() -> Dictionary:
	var result := {}
	for color_id in COLOR_IDS:
		result[color_id] = 0
	return result


static func hidden_order(player_ids: Array, seed_value: int) -> Dictionary:
	if player_ids.size() < 3 or player_ids.size() > 8:
		return {"valid": false, "reason_code": "player_count_out_of_range", "order": []}
	var seen := {}
	var rows: Array = []
	for player_id_variant in player_ids:
		var player_id := str(player_id_variant).strip_edges()
		if player_id.is_empty() or seen.has(player_id):
			return {"valid": false, "reason_code": "player_identity_invalid", "order": []}
		seen[player_id] = true
		rows.append({"item_id": player_id, "weight": 1})
	var shuffled := RunRngService.deterministic_weighted_shuffle(rows, maxi(1, seed_value))
	return {
		"valid": (shuffled.get("items", []) as Array).size() == player_ids.size(),
		"reason_code": "hidden_order_ready",
		"order": (shuffled.get("items", []) as Array).duplicate(),
		"detached_rng_terminal_state": int(shuffled.get("rng_state", 0)),
		"authoritative_rng_draw_delta": 0,
	}


static func macro_round_order(forward_order: Array, macro_round_index: int) -> Array:
	var result := forward_order.duplicate()
	if maxi(1, macro_round_index) % 2 == 0:
		result.reverse()
	return result


static func stance_intent(
	actor_id: String,
	expected_cycle_index: int,
	increase_color: String,
	decrease_color: String,
	lock: bool,
	intent_revision: int
) -> Dictionary:
	return {
		"schema_version": 1,
		"actor_id": actor_id,
		"expected_cycle_index": expected_cycle_index,
		"increase_color": increase_color,
		"decrease_color": decrease_color,
		"lock": lock,
		"intent_revision": intent_revision,
	}


static func stance_intent_valid(intent: Dictionary, player_ids: Array) -> bool:
	return _has_exact_keys(intent, [
		"schema_version",
		"actor_id",
		"expected_cycle_index",
		"increase_color",
		"decrease_color",
		"lock",
		"intent_revision",
	]) \
		and int(intent.get("schema_version", 0)) == 1 \
		and player_ids.has(str(intent.get("actor_id", ""))) \
		and int(intent.get("expected_cycle_index", -1)) >= 0 \
		and COLOR_IDS.has(str(intent.get("increase_color", ""))) \
		and COLOR_IDS.has(str(intent.get("decrease_color", ""))) \
		and str(intent.get("increase_color", "")) != str(intent.get("decrease_color", "")) \
		and typeof(intent.get("lock")) == TYPE_BOOL \
		and int(intent.get("intent_revision", 0)) > 0 \
		and is_pure_data(intent)


static func initial_market_state(player_ids: Array, seed_value: int, started_at_us: int = 0) -> Dictionary:
	var order_result := hidden_order(player_ids, seed_value)
	if not bool(order_result.get("valid", false)):
		return {}
	var forward_order: Array = order_result.get("order", [])
	var distribution := initial_distribution()
	return {
		"schema_version": 1,
		"cycle_index": 0,
		"simulation_time_us": maxi(0, started_at_us),
		"cycle_started_at_simulation_us": maxi(0, started_at_us),
		"cycle_ends_at_simulation_us": maxi(0, started_at_us) + MARKET_CYCLE_DURATION_US,
		"cycle_remaining_us": MARKET_CYCLE_DURATION_US,
		"current_revealed_stances": [],
		"next_private_stances": {},
		"hidden_forward_order": forward_order.duplicate(),
		"hidden_order_fingerprint": stable_fingerprint(forward_order),
		"macro_round_index": 1,
		"macro_round_direction": "forward",
		"cycle_index_in_macro_round": 0,
		"current_hidden_lead_player_id": str(forward_order[0]),
		"players_completed_in_current_macro_round": [],
		"macro_round_complete": false,
		"completed_macro_round_index": 0,
		"gdp_baseline_distribution": distribution.duplicate(true),
		"temporary_intervention_distribution": zero_distribution(),
		"final_runtime_distribution": distribution.duplicate(true),
		"previous_runtime_distribution": distribution.duplicate(true),
		"event_log": [],
	}


static func submit_stance(state: Dictionary, intent: Dictionary) -> Dictionary:
	var player_ids: Array = state.get("hidden_forward_order", []) if state.get("hidden_forward_order", []) is Array else []
	if not stance_intent_valid(intent, player_ids) \
			or int(intent.get("expected_cycle_index", -1)) != int(state.get("cycle_index", -2)):
		return {"accepted": false, "reason_code": "market_stance_intent_invalid", "state": state.duplicate(true)}
	var actor_id := str(intent.get("actor_id", ""))
	var next_stances: Dictionary = state.get("next_private_stances", {}) \
		if state.get("next_private_stances", {}) is Dictionary else {}
	var previous: Dictionary = next_stances.get(actor_id, {}) if next_stances.get(actor_id, {}) is Dictionary else {}
	if bool(previous.get("lock", false)):
		return {"accepted": false, "reason_code": "market_stance_already_locked", "state": state.duplicate(true)}
	var updated := state.duplicate(true)
	var updated_stances := next_stances.duplicate(true)
	updated_stances[actor_id] = intent.duplicate(true)
	updated["next_private_stances"] = updated_stances
	return {
		"accepted": true,
		"reason_code": "market_stance_locked" if bool(intent.get("lock", false)) else "market_stance_selected",
		"state": updated,
		"receipt": {
			"schema_version": 1,
			"actor_id": actor_id,
			"cycle_index": int(state.get("cycle_index", 0)),
			"intent_revision": int(intent.get("intent_revision", 0)),
			"locked": bool(intent.get("lock", false)),
		},
	}


static func gdp_baseline_distribution(gdp_by_color: Dictionary, equal_mix_bp: int) -> Dictionary:
	var mix_bp := clampi(equal_mix_bp, 0, TOTAL_BASIS_POINTS)
	var nonnegative_gdp := {}
	var total_gdp := 0
	for color_id in COLOR_IDS:
		var value := maxi(0, int(gdp_by_color.get(color_id, 0)))
		nonnegative_gdp[color_id] = value
		total_gdp += value
	if total_gdp <= 0:
		return initial_distribution()
	var gdp_share := _apportion(nonnegative_gdp, TOTAL_BASIS_POINTS)
	var equal_share := initial_distribution()
	var mixed_weights := {}
	for color_id in COLOR_IDS:
		mixed_weights[color_id] = int(equal_share.get(color_id, 0)) * mix_bp \
			+ int(gdp_share.get(color_id, 0)) * (TOTAL_BASIS_POINTS - mix_bp)
	return _apportion(mixed_weights, TOTAL_BASIS_POINTS)


static func aggregate_intervention(stances: Array, lead_player_id: String) -> Dictionary:
	var vector := zero_distribution()
	var contributions: Array = []
	var seen := {}
	for stance_variant in stances:
		if not (stance_variant is Dictionary):
			continue
		var stance := stance_variant as Dictionary
		var actor_id := str(stance.get("actor_id", ""))
		var increase_color := str(stance.get("increase_color", ""))
		var decrease_color := str(stance.get("decrease_color", ""))
		if actor_id.is_empty() or seen.has(actor_id) or not COLOR_IDS.has(increase_color) \
				or not COLOR_IDS.has(decrease_color) or increase_color == decrease_color:
			continue
		seen[actor_id] = true
		var influence := LEAD_INFLUENCE_BP if actor_id == lead_player_id else NORMAL_INFLUENCE_BP
		vector[increase_color] = int(vector.get(increase_color, 0)) + influence
		vector[decrease_color] = int(vector.get(decrease_color, 0)) - influence
		contributions.append({
			"actor_id": actor_id,
			"increase_color": increase_color,
			"decrease_color": decrease_color,
			"effective_influence_bp": influence,
		})
	return {"vector": vector, "authority_contributions": contributions}


static func final_runtime_distribution(
	baseline: Dictionary,
	intervention: Dictionary,
	minimum_color_bp: int,
	maximum_color_bp: int
) -> Dictionary:
	var even_share := int(float(TOTAL_BASIS_POINTS) / float(COLOR_IDS.size()))
	var floor_bp := clampi(minimum_color_bp, 0, even_share)
	var ceiling_bp := clampi(maximum_color_bp, even_share, TOTAL_BASIS_POINTS)
	var result := {}
	for color_id in COLOR_IDS:
		result[color_id] = clampi(
			int(baseline.get(color_id, 0)) + int(intervention.get(color_id, 0)),
			floor_bp,
			ceiling_bp
		)
	var total := _distribution_total(result)
	var guard := 0
	while total != TOTAL_BASIS_POINTS and guard < TOTAL_BASIS_POINTS * COLOR_IDS.size():
		var changed := false
		if total < TOTAL_BASIS_POINTS:
			for color_id in COLOR_IDS:
				if total >= TOTAL_BASIS_POINTS:
					break
				if int(result.get(color_id, 0)) < ceiling_bp:
					result[color_id] = int(result.get(color_id, 0)) + 1
					total += 1
					changed = true
		else:
			for color_index in range(COLOR_IDS.size() - 1, -1, -1):
				if total <= TOTAL_BASIS_POINTS:
					break
				var color_id: String = COLOR_IDS[color_index]
				if int(result.get(color_id, 0)) > floor_bp:
					result[color_id] = int(result.get(color_id, 0)) - 1
					total -= 1
					changed = true
		guard += 1
		if not changed:
			return {}
	return result if total == TOTAL_BASIS_POINTS else {}


static func settle_cycle(
	state: Dictionary,
	locked_stances: Array,
	gdp_by_color: Dictionary,
	equal_mix_bp: int,
	minimum_color_bp: int,
	maximum_color_bp: int
) -> Dictionary:
	var lead_player_id := str(state.get("current_hidden_lead_player_id", ""))
	var baseline := gdp_baseline_distribution(gdp_by_color, equal_mix_bp)
	var intervention := aggregate_intervention(locked_stances, lead_player_id)
	var vector: Dictionary = intervention.get("vector", {})
	var final_distribution := final_runtime_distribution(
		baseline,
		vector,
		minimum_color_bp,
		maximum_color_bp
	)
	if final_distribution.is_empty():
		return {"settled": false, "reason_code": "distribution_normalization_failed"}
	var revealed: Array = []
	for stance_variant in locked_stances:
		if stance_variant is Dictionary:
			var stance := stance_variant as Dictionary
			revealed.append({
				"actor_id": str(stance.get("actor_id", "")),
				"increase_color": str(stance.get("increase_color", "")),
				"decrease_color": str(stance.get("decrease_color", "")),
			})
	revealed.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("actor_id", "")) < str(right.get("actor_id", ""))
	)
	var previous: Dictionary = state.get("final_runtime_distribution", initial_distribution())
	var trend := {}
	for color_id in COLOR_IDS:
		trend[color_id] = int(final_distribution.get(color_id, 0)) - int(previous.get(color_id, 0))
	var public_receipt := {
		"schema_version": 1,
		"settled_cycle_index": int(state.get("cycle_index", 0)),
		"revealed_stances": revealed,
		"gdp_baseline_distribution": baseline,
		"final_runtime_distribution": final_distribution,
		"previous_runtime_distribution": previous.duplicate(true),
		"trend_distribution": trend,
	}
	return {
		"settled": true,
		"reason_code": "market_cycle_settled",
		"public_receipt": public_receipt,
		"authority_receipt": {
			"schema_version": 1,
			"current_hidden_lead_player_id": lead_player_id,
			"temporary_intervention_distribution": vector.duplicate(true),
			"private_contributions": (intervention.get("authority_contributions", []) as Array).duplicate(true),
		},
	}


static func advance_market_time(
	state: Dictionary,
	delta_us: int,
	default_stances: Dictionary,
	gdp_by_color: Dictionary,
	equal_mix_bp: int,
	minimum_color_bp: int,
	maximum_color_bp: int
) -> Dictionary:
	if state.is_empty() or delta_us < 0:
		return {"advanced": false, "reason_code": "market_cycle_state_invalid", "state": state.duplicate(true)}
	var updated := state.duplicate(true)
	updated["simulation_time_us"] = int(updated.get("simulation_time_us", 0)) + delta_us
	var boundaries: Array = []
	while int(updated.get("simulation_time_us", 0)) >= int(updated.get("cycle_ends_at_simulation_us", 0)):
		var locked_result := _locked_stances_for_boundary(updated, default_stances)
		if not bool(locked_result.get("ready", false)):
			return {
				"advanced": false,
				"reason_code": str(locked_result.get("reason_code", "default_stance_policy_unresolved")),
				"state": state.duplicate(true),
				"boundary_count": 0,
			}
		var settlement := settle_cycle(
			updated,
			locked_result.get("stances", []) as Array,
			gdp_by_color,
			equal_mix_bp,
			minimum_color_bp,
			maximum_color_bp
		)
		if not bool(settlement.get("settled", false)):
			return {"advanced": false, "reason_code": str(settlement.get("reason_code", "cycle_settlement_failed")), "state": state.duplicate(true)}
		var forward_order: Array = updated.get("hidden_forward_order", [])
		var completed: Array = updated.get("players_completed_in_current_macro_round", []) \
			if updated.get("players_completed_in_current_macro_round", []) is Array else []
		completed = completed.duplicate()
		completed.append(str(updated.get("current_hidden_lead_player_id", "")))
		var macro_round_index := int(updated.get("macro_round_index", 1))
		var completed_macro_round := completed.size() == forward_order.size()
		var next_macro_round_index := macro_round_index + (1 if completed_macro_round else 0)
		var next_position := 0 if completed_macro_round else int(updated.get("cycle_index_in_macro_round", 0)) + 1
		var next_order := macro_round_order(forward_order, next_macro_round_index)
		var public_receipt: Dictionary = settlement.get("public_receipt", {})
		var authority_receipt: Dictionary = settlement.get("authority_receipt", {})
		boundaries.append({
			"public_receipt": public_receipt.duplicate(true),
			"authority_receipt": authority_receipt.duplicate(true),
			"macro_round_complete": completed_macro_round,
			"completed_macro_round_index": macro_round_index if completed_macro_round else 0,
		})
		updated["previous_runtime_distribution"] = (public_receipt.get("previous_runtime_distribution", {}) as Dictionary).duplicate(true)
		updated["gdp_baseline_distribution"] = (public_receipt.get("gdp_baseline_distribution", {}) as Dictionary).duplicate(true)
		updated["temporary_intervention_distribution"] = (authority_receipt.get("temporary_intervention_distribution", {}) as Dictionary).duplicate(true)
		updated["final_runtime_distribution"] = (public_receipt.get("final_runtime_distribution", {}) as Dictionary).duplicate(true)
		updated["current_revealed_stances"] = (public_receipt.get("revealed_stances", []) as Array).duplicate(true)
		updated["next_private_stances"] = {}
		updated["cycle_index"] = int(updated.get("cycle_index", 0)) + 1
		updated["cycle_started_at_simulation_us"] = int(updated.get("cycle_ends_at_simulation_us", 0))
		updated["cycle_ends_at_simulation_us"] = int(updated.get("cycle_ends_at_simulation_us", 0)) + MARKET_CYCLE_DURATION_US
		updated["macro_round_index"] = next_macro_round_index
		updated["macro_round_direction"] = "forward" if next_macro_round_index % 2 == 1 else "reverse"
		updated["cycle_index_in_macro_round"] = next_position
		updated["current_hidden_lead_player_id"] = str(next_order[next_position])
		updated["players_completed_in_current_macro_round"] = [] if completed_macro_round else completed
		updated["macro_round_complete"] = completed_macro_round
		updated["completed_macro_round_index"] = macro_round_index if completed_macro_round else 0
		var event_log: Array = updated.get("event_log", []) if updated.get("event_log", []) is Array else []
		event_log = event_log.duplicate(true)
		event_log.append({
			"event_kind": "market_cycle_boundary",
			"cycle_index": int(public_receipt.get("settled_cycle_index", -1)),
			"public_fingerprint": stable_fingerprint(public_receipt),
			"macro_round_complete": completed_macro_round,
		})
		updated["event_log"] = event_log
	updated["cycle_remaining_us"] = maxi(
		0,
		int(updated.get("cycle_ends_at_simulation_us", 0)) - int(updated.get("simulation_time_us", 0))
	)
	return {
		"advanced": true,
		"reason_code": "market_cycle_time_advanced",
		"state": updated,
		"boundary_count": boundaries.size(),
		"boundaries": boundaries,
	}


static func build_track_state(
	tokens: Array,
	track_cursor: int,
	seat_segment_offsets: Dictionary,
	track_direction: String = "forward"
) -> Dictionary:
	if tokens.is_empty() or not ["forward", "reverse"].has(track_direction):
		return {}
	var seen_tokens := {}
	var normalized_tokens: Array = []
	for token_variant in tokens:
		if not (token_variant is Dictionary):
			return {}
		var token := token_variant as Dictionary
		var token_id := str(token.get("token_id", "")).strip_edges()
		var color_id := str(token.get("color_id", ""))
		var product_id := str(token.get("product_id", "")).strip_edges()
		var level := int(token.get("commodity_level", 0))
		if token_id.is_empty() or product_id.is_empty() or seen_tokens.has(token_id) \
				or not COLOR_IDS.has(color_id) or level < 1 or level > MAX_COMMODITY_LEVEL:
			return {}
		seen_tokens[token_id] = true
		normalized_tokens.append({
			"token_id": token_id,
			"product_id": product_id,
			"color_id": color_id,
			"commodity_level": level,
			"base_unit_count": level,
			"spawn_sequence": int(token.get("spawn_sequence", normalized_tokens.size())),
			"authoritative_track_position": normalized_tokens.size(),
		})
	return {
		"schema_version": 1,
		"track_revision": 1,
		"movement_revision": 0,
		"ordered_item_tokens": normalized_tokens,
		"track_cursor": posmod(track_cursor, normalized_tokens.size()),
		"track_direction": track_direction,
		"seat_segment_offsets": seat_segment_offsets.duplicate(true),
		"generation_sequence": normalized_tokens.size(),
		"topology_parameter_status": "RULE_AUTHORITY_NOT_ESTABLISHED",
	}


static func viewer_local_segment(track_state: Dictionary, viewer_id: String) -> Array:
	var tokens: Array = track_state.get("ordered_item_tokens", []) \
		if track_state.get("ordered_item_tokens", []) is Array else []
	var bindings: Dictionary = track_state.get("seat_segment_offsets", {}) \
		if track_state.get("seat_segment_offsets", {}) is Dictionary else {}
	var offsets: Array = bindings.get(viewer_id, []) if bindings.get(viewer_id, []) is Array else []
	if tokens.is_empty() or offsets.is_empty():
		return []
	var cursor := posmod(int(track_state.get("track_cursor", 0)), tokens.size())
	var direction := -1 if str(track_state.get("track_direction", "forward")) == "reverse" else 1
	var result: Array = []
	for local_index in range(offsets.size()):
		var token_index := posmod(cursor + direction * int(offsets[local_index]), tokens.size())
		var token: Dictionary = tokens[token_index] if tokens[token_index] is Dictionary else {}
		result.append({
			"local_slot_index": local_index,
			"token_id": str(token.get("token_id", "")),
			"product_id": str(token.get("product_id", "")),
			"color_id": str(token.get("color_id", "")),
			"commodity_level": int(token.get("commodity_level", 0)),
			"base_unit_count": int(token.get("base_unit_count", 0)),
			"claimable": true,
		})
	return result


static func initial_inventory_state(actor_id: String) -> Dictionary:
	return {
		"schema_version": 1,
		"actor_id": actor_id,
		"revision": 1,
		"normal_card_count": 0,
		"normal_card_limit": NORMAL_CARD_HAND_LIMIT,
		"normal_cards": [],
		"commodity_slot_count": 0,
		"commodity_slot_limit": COMMODITY_CARD_HAND_LIMIT,
		"commodity_stacks": [],
	}


static func inventory_valid(inventory: Dictionary) -> bool:
	var expected_keys := [
		"schema_version",
		"actor_id",
		"revision",
		"normal_card_count",
		"normal_card_limit",
		"normal_cards",
		"commodity_slot_count",
		"commodity_slot_limit",
		"commodity_stacks",
	]
	if inventory.size() != expected_keys.size() or not is_pure_data(inventory):
		return false
	for key in expected_keys:
		if not inventory.has(key):
			return false
	if int(inventory.get("schema_version", 0)) != 1 \
			or str(inventory.get("actor_id", "")).is_empty() \
			or int(inventory.get("revision", 0)) < 1 \
			or int(inventory.get("normal_card_limit", 0)) != NORMAL_CARD_HAND_LIMIT \
			or int(inventory.get("commodity_slot_limit", 0)) != COMMODITY_CARD_HAND_LIMIT:
		return false
	var normal_cards: Array = inventory.get("normal_cards", []) if inventory.get("normal_cards", []) is Array else []
	var commodity_stacks: Array = inventory.get("commodity_stacks", []) if inventory.get("commodity_stacks", []) is Array else []
	if int(inventory.get("normal_card_count", -1)) != normal_cards.size() \
			or int(inventory.get("commodity_slot_count", -1)) != commodity_stacks.size() \
			or normal_cards.size() > NORMAL_CARD_HAND_LIMIT \
			or commodity_stacks.size() > COMMODITY_CARD_HAND_LIMIT:
		return false
	var normal_ids := {}
	for card_variant in normal_cards:
		if not (card_variant is String) or str(card_variant).is_empty() or normal_ids.has(card_variant):
			return false
		normal_ids[card_variant] = true
	var stack_ids := {}
	for stack_variant in commodity_stacks:
		if not (stack_variant is Dictionary) or not commodity_stack_valid(stack_variant as Dictionary):
			return false
		var stack_id := str((stack_variant as Dictionary).get("group_id", ""))
		if stack_ids.has(stack_id):
			return false
		stack_ids[stack_id] = true
	return true


static func commodity_stack_valid(stack: Dictionary) -> bool:
	var expected_keys := ["group_id", "product_id", "color_id", "commodity_level", "base_unit_count"]
	if stack.size() != expected_keys.size():
		return false
	for key in expected_keys:
		if not stack.has(key):
			return false
	var level := int(stack.get("commodity_level", 0))
	return not str(stack.get("group_id", "")).is_empty() \
		and not str(stack.get("product_id", "")).is_empty() \
		and COLOR_IDS.has(str(stack.get("color_id", ""))) \
		and level >= 1 \
		and level <= MAX_COMMODITY_LEVEL \
		and int(stack.get("base_unit_count", 0)) == level


static func add_normal_card(inventory: Dictionary, card_id: String) -> Dictionary:
	if not inventory_valid(inventory) or card_id.is_empty():
		return {"committed": false, "reason_code": "normal_card_request_invalid", "inventory": inventory.duplicate(true)}
	var cards: Array = inventory.get("normal_cards", [])
	if cards.has(card_id):
		return {"committed": false, "reason_code": "normal_card_duplicate", "inventory": inventory.duplicate(true)}
	if cards.size() >= int(inventory.get("normal_card_limit", NORMAL_CARD_HAND_LIMIT)):
		return {"committed": false, "reason_code": "normal_card_hand_full", "inventory": inventory.duplicate(true)}
	var updated := inventory.duplicate(true)
	var updated_cards := cards.duplicate()
	updated_cards.append(card_id)
	updated["normal_cards"] = updated_cards
	updated["normal_card_count"] = updated_cards.size()
	updated["revision"] = int(updated.get("revision", 0)) + 1
	return {"committed": true, "reason_code": "normal_card_added", "inventory": updated}


static func add_commodity_stack(inventory: Dictionary, stack: Dictionary) -> Dictionary:
	if not inventory_valid(inventory) or not commodity_stack_valid(stack):
		return {"committed": false, "reason_code": "commodity_stack_request_invalid", "inventory": inventory.duplicate(true)}
	var stacks: Array = inventory.get("commodity_stacks", [])
	for existing_variant in stacks:
		if existing_variant is Dictionary \
				and str((existing_variant as Dictionary).get("group_id", "")) == str(stack.get("group_id", "")):
			return {"committed": false, "reason_code": "commodity_stack_duplicate", "inventory": inventory.duplicate(true)}
	if stacks.size() >= int(inventory.get("commodity_slot_limit", COMMODITY_CARD_HAND_LIMIT)):
		return {"committed": false, "reason_code": "commodity_inventory_full", "inventory": inventory.duplicate(true)}
	var updated := inventory.duplicate(true)
	var updated_stacks := stacks.duplicate(true)
	updated_stacks.append(stack.duplicate(true))
	updated["commodity_stacks"] = updated_stacks
	updated["commodity_slot_count"] = updated_stacks.size()
	updated["revision"] = int(updated.get("revision", 0)) + 1
	return {"committed": true, "reason_code": "commodity_stack_added", "inventory": updated}


static func inventory_reference_payload(inventory: Dictionary) -> Dictionary:
	if not inventory_valid(inventory):
		return {}
	return {
		"schema_version": 1,
		"inventory": inventory.duplicate(true),
		"inventory_fingerprint": stable_fingerprint(inventory),
	}


static func restore_inventory_reference_payload(payload: Dictionary) -> Dictionary:
	if payload.size() != 3 \
			or int(payload.get("schema_version", 0)) != 1 \
			or not payload.has("inventory") \
			or not payload.has("inventory_fingerprint") \
			or not (payload.get("inventory", {}) is Dictionary):
		return {"restored": false, "reason_code": "inventory_reference_payload_invalid"}
	var inventory := (payload.get("inventory", {}) as Dictionary).duplicate(true)
	if not inventory_valid(inventory) \
			or stable_fingerprint(inventory) != str(payload.get("inventory_fingerprint", "")):
		return {"restored": false, "reason_code": "inventory_reference_payload_fingerprint_mismatch"}
	return {"restored": true, "reason_code": "inventory_reference_payload_restored", "inventory": inventory}


static func merge_commodity_stacks(
	inventory: Dictionary,
	base_group_id: String,
	level_one_group_id: String,
	identity_policy_id: String
) -> Dictionary:
	if not ["same_product_id", "same_color_id"].has(identity_policy_id) \
			or base_group_id == level_one_group_id:
		return {"committed": false, "reason_code": "commodity_merge_identity_policy_unresolved", "inventory": inventory.duplicate(true)}
	if not inventory_valid(inventory):
		return {"committed": false, "reason_code": "commodity_inventory_invalid", "inventory": inventory.duplicate(true)}
	var groups: Array = inventory.get("commodity_stacks", []) if inventory.get("commodity_stacks", []) is Array else []
	var base_index := -1
	var unit_index := -1
	for index in range(groups.size()):
		if groups[index] is Dictionary:
			var group := groups[index] as Dictionary
			if str(group.get("group_id", "")) == base_group_id:
				base_index = index
			if str(group.get("group_id", "")) == level_one_group_id:
				unit_index = index
	if base_index < 0 or unit_index < 0:
		return {"committed": false, "reason_code": "commodity_merge_group_missing", "inventory": inventory.duplicate(true)}
	var base := (groups[base_index] as Dictionary).duplicate(true)
	var unit := groups[unit_index] as Dictionary
	var base_level := int(base.get("commodity_level", 0))
	var unit_level := int(unit.get("commodity_level", 0))
	var identity_matches := str(base.get("product_id", "")) == str(unit.get("product_id", "")) \
		if identity_policy_id == "same_product_id" \
		else str(base.get("color_id", "")) == str(unit.get("color_id", ""))
	if not identity_matches:
		return {"committed": false, "reason_code": "commodity_merge_identity_mismatch", "inventory": inventory.duplicate(true)}
	if base_level < 1 or base_level >= MAX_COMMODITY_LEVEL or unit_level != 1 \
			or int(base.get("base_unit_count", 0)) != base_level \
			or int(unit.get("base_unit_count", 0)) != 1:
		return {"committed": false, "reason_code": "commodity_merge_requires_one_level_one_unit", "inventory": inventory.duplicate(true)}
	base["commodity_level"] = base_level + 1
	base["base_unit_count"] = base_level + 1
	var updated_groups := groups.duplicate(true)
	updated_groups[base_index] = base
	updated_groups.remove_at(unit_index)
	var updated := inventory.duplicate(true)
	updated["revision"] = int(updated.get("revision", 0)) + 1
	updated["commodity_stacks"] = updated_groups
	updated["commodity_slot_count"] = updated_groups.size()
	return {
		"committed": true,
		"reason_code": "commodity_linear_merge_committed",
		"inventory": updated,
		"result_group": base.duplicate(true),
		"consumed_group_id": level_one_group_id,
	}


static func evaluate_end_gate(
	gate_state: Dictionary,
	original_end_condition_met: bool,
	current_macro_round_complete: bool,
	cycle_index: int
) -> Dictionary:
	var updated := gate_state.duplicate(true)
	if updated.is_empty():
		updated = {
			"schema_version": 1,
			"original_end_condition_met": false,
			"end_condition_pending": false,
			"pending_since_cycle": -1,
			"current_macro_round_complete": false,
			"final_end_validation_ready": false,
			"game_may_end": false,
		}
	updated["original_end_condition_met"] = original_end_condition_met
	updated["current_macro_round_complete"] = current_macro_round_complete
	updated["final_end_validation_ready"] = current_macro_round_complete \
		and (bool(updated.get("end_condition_pending", false)) or original_end_condition_met)
	updated["game_may_end"] = false
	if current_macro_round_complete:
		updated["game_may_end"] = original_end_condition_met
		updated["end_condition_pending"] = false
		updated["pending_since_cycle"] = -1
	elif original_end_condition_met:
		if not bool(updated.get("end_condition_pending", false)):
			updated["pending_since_cycle"] = cycle_index
		updated["end_condition_pending"] = true
	return updated


static func stable_fingerprint(value: Variant) -> String:
	return JSON.stringify(_canonical_value(value)).sha256_text()


static func is_pure_data(value: Variant) -> bool:
	if value is Object or value is Callable:
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not is_pure_data(key_variant) or not is_pure_data((value as Dictionary).get(key_variant)):
				return false
	if value is Array:
		for child_variant in value as Array:
			if not is_pure_data(child_variant):
				return false
	return true


static func _locked_stances_for_boundary(state: Dictionary, defaults: Dictionary) -> Dictionary:
	var player_ids: Array = state.get("hidden_forward_order", []) if state.get("hidden_forward_order", []) is Array else []
	var submitted: Dictionary = state.get("next_private_stances", {}) if state.get("next_private_stances", {}) is Dictionary else {}
	var result: Array = []
	for player_id_variant in player_ids:
		var player_id := str(player_id_variant)
		var stance: Dictionary = submitted.get(player_id, {}) if submitted.get(player_id, {}) is Dictionary else {}
		if stance.is_empty():
			var default_value: Dictionary = defaults.get(player_id, {}) if defaults.get(player_id, {}) is Dictionary else {}
			if not COLOR_IDS.has(str(default_value.get("increase_color", ""))) \
					or not COLOR_IDS.has(str(default_value.get("decrease_color", ""))) \
					or str(default_value.get("increase_color", "")) == str(default_value.get("decrease_color", "")):
				return {"ready": false, "reason_code": "default_stance_policy_unresolved", "stances": []}
			stance = stance_intent(
				player_id,
				int(state.get("cycle_index", 0)),
				str(default_value.get("increase_color", "")),
				str(default_value.get("decrease_color", "")),
				true,
				1
			)
		else:
			stance = stance.duplicate(true)
			stance["lock"] = true
		result.append(stance)
	return {"ready": true, "reason_code": "boundary_stances_ready", "stances": result}


static func _apportion(weights: Dictionary, target_total: int) -> Dictionary:
	var total_weight := 0
	for color_id in COLOR_IDS:
		total_weight += maxi(0, int(weights.get(color_id, 0)))
	if total_weight <= 0:
		return initial_distribution() if target_total == TOTAL_BASIS_POINTS else {}
	var result := {}
	var remainders: Array = []
	var assigned := 0
	for index in range(COLOR_IDS.size()):
		var color_id: String = COLOR_IDS[index]
		var numerator := maxi(0, int(weights.get(color_id, 0))) * target_total
		var quotient := int(floor(float(numerator) / float(total_weight)))
		result[color_id] = quotient
		assigned += quotient
		remainders.append({"color_id": color_id, "remainder": numerator % total_weight, "stable_index": index})
	remainders.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_remainder := int(left.get("remainder", 0))
		var right_remainder := int(right.get("remainder", 0))
		return left_remainder > right_remainder \
			if left_remainder != right_remainder \
			else int(left.get("stable_index", 0)) < int(right.get("stable_index", 0))
	)
	for index in range(target_total - assigned):
		var color_id := str((remainders[index % remainders.size()] as Dictionary).get("color_id", ""))
		result[color_id] = int(result.get(color_id, 0)) + 1
	return result


static func _distribution_total(distribution: Dictionary) -> int:
	var total := 0
	for color_id in COLOR_IDS:
		total += int(distribution.get(color_id, 0))
	return total


static func _canonical_value(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys := (value as Dictionary).keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		for key_variant in keys:
			result[str(key_variant)] = _canonical_value((value as Dictionary).get(key_variant))
		return result
	if value is Array:
		var result: Array = []
		for child_variant in value as Array:
			result.append(_canonical_value(child_variant))
		return result
	return value


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(key_variant):
			return false
	return true
