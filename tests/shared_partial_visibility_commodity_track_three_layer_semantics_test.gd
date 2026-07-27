extends SceneTree

const CORE := preload("res://tests/support/shared_commodity_track_core_semantics_reference.gd")
const AI := preload("res://tests/support/shared_commodity_track_ai_semantics_reference.gd")
const PLAYER := preload("res://tests/support/shared_commodity_track_player_semantics_reference.gd")
const QUERY := preload("res://tests/support/shared_commodity_track_semantic_query_source_reference.gd")
const VECTOR_PATH := "res://docs/rules/shared_partial_visibility_commodity_track_test_vectors.json"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var vectors := _load_vectors()
	_expect(not vectors.is_empty(), "three-layer semantic vectors parse")
	if vectors.is_empty():
		_finish()
		return
	_test_rule_constants(vectors)
	_test_hidden_lead_orders(vectors)
	_test_distribution_and_cycle(vectors)
	_test_track_visibility_and_three_layers(vectors)
	_test_inventory_and_end_gate()
	_test_fixed_seed_trace(vectors)
	_test_production_negative_boundary(vectors)
	_finish()


func _test_rule_constants(vectors: Dictionary) -> void:
	_expect(CORE.COLOR_IDS == vectors.get("stable_color_order", []), "one stable six-color identity order drives all three layers")
	_expect(CORE.MARKET_CYCLE_DURATION_US == int(vectors.get("market_cycle_duration_us", 0)), "market cycle contract is exactly 180 simulation seconds")
	_expect(CORE.NORMAL_INFLUENCE_BP == 300 and CORE.LEAD_INFLUENCE_BP == 600, "ordinary and hidden-lead influence are 300/600 basis points")
	_expect(CORE.NORMAL_CARD_HAND_LIMIT == 5 and CORE.COMMODITY_CARD_HAND_LIMIT == 5, "normal-card and commodity capacities are independent five-slot limits")
	_expect(str(vectors.get("target_rule_version", "")) == "V0.7" and not bool(vectors.get("full_v0_7_cutover", true)), "V0.7 is the approved target while the runtime remains v0.6")
	_expect(CORE.MAX_COMMODITY_LEVEL == 4, "commodity level IV is terminal")
	var initial := CORE.initial_distribution()
	_expect(_distribution_total(initial) == 10_000, "initial six-color distribution sums to exactly 10,000 basis points")
	_expect(initial.values().max() - initial.values().min() <= 1, "initial six-color distribution is as even as integer basis points permit")
	_expect(str(vectors.get("rule_status", "")) == "v0_7_approved_semantic_constitution_not_active_runtime_rule", "V0.7 reference semantics do not claim active production authority")
	_expect(not bool((vectors.get("cutover", {}) as Dictionary).get("full_rule_cutover", true)), "contract keeps full production cutover disabled")


func _test_hidden_lead_orders(vectors: Dictionary) -> void:
	for vector_variant in vectors.get("seat_vectors", []) as Array:
		if not (vector_variant is Dictionary):
			continue
		var vector := vector_variant as Dictionary
		var player_ids: Array = vector.get("player_ids", [])
		var seed_value := int(vector.get("seed", 0))
		var first := CORE.hidden_order(player_ids, seed_value)
		var second := CORE.hidden_order(player_ids, seed_value)
		var forward: Array = first.get("order", [])
		print("COMMODITY_TRACK_HIDDEN_ORDER_VECTOR|seats=%d|order=%s" % [player_ids.size(), JSON.stringify(forward)])
		var reverse_order := CORE.macro_round_order(forward, 2)
		var expected_reverse := forward.duplicate()
		expected_reverse.reverse()
		_expect(bool(first.get("valid", false)) and first == second, "%d-seat hidden order is fixed for the same seed" % player_ids.size())
		_expect(int(first.get("authoritative_rng_draw_delta", -1)) == 0, "%d-seat detached contract vector does not consume the live RunRngService cursor" % player_ids.size())
		_expect(_same_members(forward, player_ids), "%d-seat hidden order contains every player exactly once" % player_ids.size())
		_expect(CORE.macro_round_order(forward, 1) == forward, "%d-seat first macro round is forward" % player_ids.size())
		_expect(reverse_order == expected_reverse, "%d-seat second macro round is the exact reverse" % player_ids.size())
		_expect(CORE.macro_round_order(forward, 3) == forward, "%d-seat third macro round returns to forward" % player_ids.size())
		var expected: Array = vector.get("expected_forward_order", [])
		if not expected.is_empty():
			_expect(forward == expected, "%d-seat frozen hidden-order vector matches" % player_ids.size())


func _test_distribution_and_cycle(vectors: Dictionary) -> void:
	var parameters: Dictionary = vectors.get("simulation_parameters_not_balance_lock", {})
	var mix_bp := int(parameters.get("gdp_equal_mix_bp", 0))
	var floor_bp := int(parameters.get("minimum_color_bp", 0))
	var ceiling_bp := int(parameters.get("maximum_color_bp", 10_000))
	var gdp := {
		"life": 600,
		"energy": 300,
		"industry": 200,
		"technology": 100,
		"commerce": 50,
		"shipping": 25,
	}
	var baseline := CORE.gdp_baseline_distribution(gdp, mix_bp)
	_expect(_distribution_total(baseline) == 10_000 and int(baseline.get("life", 0)) > int(baseline.get("shipping", 0)), "GDP changes influence the long-horizon baseline without float drift")
	var state := CORE.initial_market_state(["player_0", "player_1", "player_2"], 900626424)
	var stances := [
		CORE.stance_intent("player_0", 0, "life", "energy", true, 1),
		CORE.stance_intent("player_1", 0, "industry", "technology", true, 1),
		CORE.stance_intent("player_2", 0, "commerce", "shipping", true, 1),
	]
	var lead_id := str(state.get("current_hidden_lead_player_id", ""))
	var intervention := CORE.aggregate_intervention(stances, lead_id)
	var authority_contributions: Array = intervention.get("authority_contributions", [])
	var lead_contribution: Dictionary = {}
	for contribution_variant in authority_contributions:
		if contribution_variant is Dictionary and str((contribution_variant as Dictionary).get("actor_id", "")) == lead_id:
			lead_contribution = contribution_variant
	_expect(int(lead_contribution.get("effective_influence_bp", 0)) == 600, "the current hidden lead receives 600 basis points inside core only")
	for contribution_variant in authority_contributions:
		if contribution_variant is Dictionary and str((contribution_variant as Dictionary).get("actor_id", "")) != lead_id:
			_expect(int((contribution_variant as Dictionary).get("effective_influence_bp", 0)) == 300, "ordinary players receive 300 basis points")
	var settlement := CORE.settle_cycle(state, stances, gdp, mix_bp, floor_bp, ceiling_bp)
	var public_receipt: Dictionary = settlement.get("public_receipt", {})
	var public_serialized := JSON.stringify(public_receipt)
	_expect(bool(settlement.get("settled", false)) and _distribution_total(public_receipt.get("final_runtime_distribution", {})) == 10_000, "cycle settlement produces one normalized core distribution")
	_expect(not public_serialized.contains("lead") and not public_serialized.contains("influence") and not public_serialized.contains("600"), "public stance receipt hides lead identity and effective weights")
	_expect((public_receipt.get("revealed_stances", []) as Array).size() == 3, "all locked stances reveal simultaneously at the boundary")
	var defaults: Dictionary = vectors.get("deterministic_default_stances", {})
	var before_boundary := CORE.advance_market_time(state, 179_999_999, defaults, gdp, mix_bp, floor_bp, ceiling_bp)
	_expect(bool(before_boundary.get("advanced", false)) and int(before_boundary.get("boundary_count", -1)) == 0, "179.999999 simulation seconds do not cross the market boundary")
	var exact_boundary := CORE.advance_market_time(state, 180_000_000, defaults, gdp, mix_bp, floor_bp, ceiling_bp)
	_expect(bool(exact_boundary.get("advanced", false)) and int(exact_boundary.get("boundary_count", 0)) == 1, "exactly 180 simulation seconds crosses one market boundary with no voting downtime")
	var two_boundaries := CORE.advance_market_time(state, 360_000_000, defaults, gdp, mix_bp, floor_bp, ceiling_bp)
	_expect(bool(two_boundaries.get("advanced", false)) and int(two_boundaries.get("boundary_count", 0)) == 2, "large deterministic delta crosses multiple ordered 180-second boundaries")
	var unresolved_default := CORE.advance_market_time(state, 180_000_000, {}, gdp, mix_bp, floor_bp, ceiling_bp)
	_expect(not bool(unresolved_default.get("advanced", true)) and str(unresolved_default.get("reason_code", "")) == "default_stance_policy_unresolved", "missing bootstrap/default stance policy fails closed instead of inventing a rule")
	var submit := CORE.submit_stance(state, CORE.stance_intent("player_1", 0, "energy", "life", false, 1))
	var submitted_state: Dictionary = submit.get("state", {})
	_expect(bool(submit.get("accepted", false)) and (submitted_state.get("current_revealed_stances", []) as Array).is_empty(), "next-cycle selection remains private before boundary reveal")
	var locked := CORE.submit_stance(submitted_state, CORE.stance_intent("player_1", 0, "energy", "life", true, 2))
	var rejected_change := CORE.submit_stance(locked.get("state", {}), CORE.stance_intent("player_1", 0, "life", "energy", true, 3))
	_expect(bool(locked.get("accepted", false)) and not bool(rejected_change.get("accepted", true)), "explicit lock prevents a later same-cycle stance rewrite")


func _test_track_visibility_and_three_layers(vectors: Dictionary) -> void:
	var tokens := _fixture_tokens()
	var bindings := {
		"player_0": [0, 1],
		"player_1": [2, 3],
		"player_2": [4, 5],
	}
	var track := CORE.build_track_state(tokens, 0, bindings)
	var market := CORE.initial_market_state(["player_0", "player_1", "player_2"], 900626424)
	var selection := CORE.submit_stance(market, CORE.stance_intent("player_0", 0, "life", "energy", true, 1))
	market = selection.get("state", {})
	var inventory_0 := _inventory_with_contents("player_0", ["normal.a", "normal.b"], _merge_fixture_groups())
	var authority := {
		"market_cycle": market,
		"track": track,
		"inventories": {
			"player_0": inventory_0,
			"player_1": CORE.initial_inventory_state("player_1"),
			"player_2": CORE.initial_inventory_state("player_2"),
		},
		"actor_private_needs": {
			"player_0": {"life": 8, "energy": 2},
			"player_1": {"technology": 7},
		},
		"public_visible_opponent_demand": {"industry": 4, "commerce": 3},
		"public_stance_history": [],
		"rule_terms": {"commodity_merge_identity_policy_id": "same_product_id"},
		"end_gate": CORE.evaluate_end_gate({}, true, false, 0),
	}
	var segment_0 := CORE.viewer_local_segment(track, "player_0")
	var segment_1 := CORE.viewer_local_segment(track, "player_1")
	_expect(segment_0.size() == 2 and segment_1.size() == 2 and segment_0 != segment_1, "one shared sequence yields distinct actor-private local segments")
	_expect(not JSON.stringify(segment_0).contains(str((segment_1[0] as Dictionary).get("token_id", ""))), "viewer A segment contains no viewer B token identity")
	var ai_0 := QUERY.ai_observation_for_bound_actor(authority, "player_0", "player_0")
	var ai_1 := QUERY.ai_observation_for_bound_actor(authority, "player_1", "player_1")
	_expect(AI.observation_valid(ai_0) and AI.observation_valid(ai_1), "AI observations pass the actor-scoped information firewall")
	_expect(ai_0.get("local_track_segment", []) == segment_0 and ai_1.get("local_track_segment", []) == segment_1, "AI receives the same local segment its corresponding human seat may see")
	_expect(bool(ai_0.get("self_is_current_lead", false)) == (str(market.get("current_hidden_lead_player_id", "")) == "player_0"), "AI may know only whether itself is current lead")
	var player_0 := QUERY.player_projection_for_bound_viewer(authority, "player_0", "player_0")
	var player_1 := QUERY.player_projection_for_bound_viewer(authority, "player_1", "player_1")
	_expect(PLAYER.projection_valid(player_0) and PLAYER.projection_valid(player_1), "player projections remain pure and visibility-scoped")
	_expect(QUERY.ai_observation_for_bound_actor(authority, "player_0", "player_1").is_empty(), "AI observation rejects cross-seat impersonation at the owner-bound actor port")
	_expect(QUERY.player_projection_for_bound_viewer(authority, "player_0", "player_1").is_empty(), "player projection rejects cross-viewer impersonation at the owner-bound viewer port")
	_expect(((player_0.get("viewer_private", {}) as Dictionary).get("local_track_segment", []) as Array) == segment_0, "player UI projection uses the core-provided viewer segment without recomputing track visibility")
	_expect(((player_1.get("viewer_private", {}) as Dictionary).get("next_stance", {}) as Dictionary).is_empty(), "viewer B cannot see viewer A's hidden next-cycle stance")
	var public_player_projection := player_0.duplicate(true)
	public_player_projection.erase("viewer_private")
	_expect(not JSON.stringify(public_player_projection).contains("主导权") and not JSON.stringify(public_player_projection).contains("600"), "public player semantics contain no lead side channel or doubled weight")
	var ai_intent := AI.choose_market_stance(ai_0, "expert", 5)
	var human_intent := CORE.stance_intent(
		"player_0",
		int(market.get("cycle_index", 0)),
		str(ai_intent.get("increase_color", "")),
		str(ai_intent.get("decrease_color", "")),
		true,
		5
	)
	_expect(CORE.stance_intent_valid(ai_intent, ["player_0", "player_1", "player_2"]) and _sorted_keys(ai_intent) == _sorted_keys(human_intent), "AI and human submit the exact same typed MarketStanceIntent shape")
	for difficulty in AI.DIFFICULTIES:
		_expect(CORE.stance_intent_valid(AI.choose_market_stance(ai_0, difficulty, 6), ["player_0", "player_1", "player_2"]), "%s AI produces a legal stance using only its observation" % difficulty)
	var commodity_action := AI.choose_commodity_action(ai_0)
	_expect(str(commodity_action.get("action_kind", "")) == "merge_commodity", "AI understands L2/L3 accumulation through one additional level-I commodity")
	var poisoned := authority.duplicate(true)
	poisoned["public_visible_opponent_demand"] = {
		"industry": 4,
		"save_payload": {"rng_cursor": 7, "lead_player_id": "player_2"},
	}
	poisoned["public_stance_history"] = [{
		"cycle_index": 0,
		"revealed_stances": [{
			"actor_id": "player_2",
			"increase_color": "life",
			"decrease_color": "energy",
			"effective_weight": 600,
		}],
		"final_runtime_distribution": CORE.initial_distribution(),
		"hidden_order_fingerprint": "must-not-cross",
	}]
	var poisoned_inventories := (poisoned.get("inventories", {}) as Dictionary).duplicate(true)
	var poisoned_inventory := (poisoned_inventories.get("player_0", {}) as Dictionary).duplicate(true)
	var poisoned_stacks := (poisoned_inventory.get("commodity_stacks", []) as Array).duplicate(true)
	(poisoned_stacks[0] as Dictionary)["save_payload"] = {"rng_cursor": 8}
	poisoned_inventory["commodity_stacks"] = poisoned_stacks
	poisoned_inventories["player_0"] = poisoned_inventory
	poisoned["inventories"] = poisoned_inventories
	var sanitized_ai := QUERY.ai_observation_for_bound_actor(poisoned, "player_0", "player_0")
	var sanitized_player := QUERY.player_projection_for_bound_viewer(poisoned, "player_0", "player_0")
	var sanitized_serialized := JSON.stringify({"ai": sanitized_ai, "player": sanitized_player})
	_expect(AI.observation_valid(sanitized_ai) and PLAYER.projection_valid(sanitized_player), "nested allowlists rebuild valid AI and player DTOs from hostile authority fixtures")
	_expect(not sanitized_serialized.contains("save_payload") and not sanitized_serialized.contains("rng_cursor") and not sanitized_serialized.contains("lead_player_id") and not sanitized_serialized.contains("effective_weight") and not sanitized_serialized.contains("hidden_order_fingerprint"), "nested Save RNG lead and weight aliases cannot cross either reference projection")
	_expect(CORE.is_pure_data(authority) and CORE.is_pure_data(ai_0) and CORE.is_pure_data(player_0), "core fixture, AI observation, and player projection serialize as pure data")
	_expect(str(track.get("topology_parameter_status", "")) == "RULE_AUTHORITY_NOT_ESTABLISHED", "local-window fixture does not silently freeze unresolved production track topology")
	_expect(not bool((vectors.get("cutover", {}) as Dictionary).get("runtime_cutover_performed", true)), "passive three-layer semantics do not create a second production authority")


func _test_inventory_and_end_gate() -> void:
	var normal_full := _inventory_with_contents("player_0", ["n1", "n2", "n3", "n4", "n5"], [])
	var normal_full_with_commodities := normal_full
	for index in range(5):
		var add_result := CORE.add_commodity_stack(normal_full_with_commodities, _group("commodity.%d" % index, "product.life.%d" % index, "life", 1))
		_expect(bool(add_result.get("committed", false)), "normal hand full still accepts commodity slot %d/5" % (index + 1))
		normal_full_with_commodities = add_result.get("inventory", {})
	_expect(CORE.inventory_valid(normal_full_with_commodities) and int(normal_full_with_commodities.get("normal_card_count", 0)) == 5 and int(normal_full_with_commodities.get("commodity_slot_count", 0)) == 5, "five normal cards plus five commodity stacks is one legal dual-capacity state")
	var sixth_normal := CORE.add_normal_card(normal_full_with_commodities, "n6")
	_expect(not bool(sixth_normal.get("committed", true)) and str(sixth_normal.get("reason_code", "")) == "normal_card_hand_full" and int((sixth_normal.get("inventory", {}) as Dictionary).get("commodity_slot_count", -1)) == 5, "sixth normal card overflows only the normal hand")

	var commodity_full := _inventory_with_contents("player_1", [], [
		_group("c1", "product.energy.1", "energy", 1),
		_group("c2", "product.energy.2", "energy", 1),
		_group("c3", "product.energy.3", "energy", 1),
		_group("c4", "product.energy.4", "energy", 1),
		_group("c5", "product.energy.5", "energy", 1),
	])
	var commodity_full_with_normals := commodity_full
	for index in range(5):
		var add_result := CORE.add_normal_card(commodity_full_with_normals, "normal.%d" % index)
		_expect(bool(add_result.get("committed", false)), "commodity inventory full still accepts normal card %d/5" % (index + 1))
		commodity_full_with_normals = add_result.get("inventory", {})
	var sixth_commodity := CORE.add_commodity_stack(commodity_full_with_normals, _group("c6", "product.energy.6", "energy", 1))
	_expect(not bool(sixth_commodity.get("committed", true)) and str(sixth_commodity.get("reason_code", "")) == "commodity_inventory_full" and int((sixth_commodity.get("inventory", {}) as Dictionary).get("normal_card_count", -1)) == 5, "sixth commodity overflows only the commodity inventory")

	var inventory := _inventory_with_contents("player_0", ["a", "b", "c", "d", "e"], _merge_fixture_groups())
	_expect(CORE.inventory_valid(inventory) and not inventory.has("hand_limit"), "V0.7 reference state has two explicit limits and no unified hand_limit")
	var merge_2 := CORE.merge_commodity_stacks(inventory, "group.base", "group.unit.1", "same_product_id")
	var level_2: Dictionary = merge_2.get("inventory", {})
	var merge_3 := CORE.merge_commodity_stacks(level_2, "group.base", "group.unit.2", "same_product_id")
	var level_3: Dictionary = merge_3.get("inventory", {})
	var merge_4 := CORE.merge_commodity_stacks(level_3, "group.base", "group.unit.3", "same_product_id")
	var result_group: Dictionary = merge_4.get("result_group", {})
	_expect(bool(merge_2.get("committed", false)) and int((merge_2.get("result_group", {}) as Dictionary).get("base_unit_count", 0)) == 2 and int(level_2.get("commodity_slot_count", 0)) == 3 and int(level_2.get("normal_card_count", 0)) == 5, "L1 + L1 produces one L2 slot, releases one commodity slot, and leaves normal cards unchanged")
	_expect(bool(merge_3.get("committed", false)) and int((merge_3.get("result_group", {}) as Dictionary).get("base_unit_count", 0)) == 3 and int(level_3.get("commodity_slot_count", 0)) == 2, "L2 + L1 produces one L3 slot")
	_expect(bool(merge_4.get("committed", false)) and int(result_group.get("commodity_level", 0)) == 4 and int(result_group.get("base_unit_count", 0)) == 4 and int((merge_4.get("inventory", {}) as Dictionary).get("commodity_slot_count", 0)) == 1, "L3 + L1 produces one L4 slot with four base units")
	var invalid_inventory := _inventory_with_contents("player_0", [], [
		_group("g.a", "product.life.alpha", "life", 2),
		_group("g.b", "product.life.alpha", "life", 2),
	])
	var invalid_merge := CORE.merge_commodity_stacks(invalid_inventory, "g.a", "g.b", "same_product_id")
	_expect(not bool(invalid_merge.get("committed", true)) and str(invalid_merge.get("reason_code", "")) == "commodity_merge_requires_one_level_one_unit", "L2 + L2 is rejected by the linear upgrade contract")
	var unresolved_merge := CORE.merge_commodity_stacks(inventory, "group.base", "group.unit.1", "")
	_expect(not bool(unresolved_merge.get("committed", true)), "production merge identity fails closed until same-product versus same-color authority is approved")

	var normal_full_authority := _authority_for_inventory(normal_full)
	var commodity_full_authority := _authority_for_inventory(commodity_full)
	var normal_full_ai := QUERY.ai_observation_for_bound_actor(normal_full_authority, "player_0", "player_0")
	var commodity_full_ai := QUERY.ai_observation_for_bound_actor(commodity_full_authority, "player_1", "player_1")
	_expect(not AI.may_accept_normal_card(normal_full_ai) and AI.may_accept_commodity_card(normal_full_ai), "AI treats a full normal hand and open commodity inventory independently")
	_expect(AI.may_accept_normal_card(commodity_full_ai) and not AI.may_accept_commodity_card(commodity_full_ai), "AI treats a full commodity inventory and open normal hand independently")
	var human_commodity_accepts := bool(CORE.add_commodity_stack(normal_full, _group("human.ai.parity", "product.life.parity", "life", 1)).get("committed", false))
	var human_normal_accepts := bool(CORE.add_normal_card(commodity_full, "human.ai.parity").get("committed", false))
	_expect(AI.may_accept_commodity_card(normal_full_ai) == human_commodity_accepts and AI.may_accept_normal_card(commodity_full_ai) == human_normal_accepts, "AI and human/core use the same independent capacity legality")
	var normal_full_ui := QUERY.player_projection_for_bound_viewer(normal_full_authority, "player_0", "player_0")
	var capacity: Dictionary = normal_full_ui.get("inventory_capacity", {})
	_expect(str(capacity.get("normal_hand_label", "")) == "普通手牌：5 / 5" and str(capacity.get("commodity_inventory_label", "")) == "商品库存：0 / 5", "player semantics display two separate x/5 capacity labels")
	_expect(not bool(capacity.get("normal_card_acquisition_allowed", true)) and bool(capacity.get("commodity_acquisition_allowed", false)), "player semantics never show a generic hand-full block when commodities still fit")
	var payload := CORE.inventory_reference_payload(normal_full_with_commodities)
	var restored := CORE.restore_inventory_reference_payload(payload)
	_expect(bool(restored.get("restored", false)) and CORE.stable_fingerprint(restored.get("inventory", {})) == CORE.stable_fingerprint(normal_full_with_commodities), "reference persistence round-trip preserves both independent capacities and contents")
	var deterministic_copy := _inventory_with_contents("player_0", ["n1", "n2", "n3", "n4", "n5"], [
		_group("commodity.0", "product.life.0", "life", 1),
		_group("commodity.1", "product.life.1", "life", 1),
		_group("commodity.2", "product.life.2", "life", 1),
		_group("commodity.3", "product.life.3", "life", 1),
		_group("commodity.4", "product.life.4", "life", 1),
	])
	_expect(CORE.stable_fingerprint(deterministic_copy) == CORE.stable_fingerprint(normal_full_with_commodities), "same ordered inventory intents deterministically reproduce both capacity pools")
	var pending := CORE.evaluate_end_gate({}, true, false, 3)
	_expect(bool(pending.get("end_condition_pending", false)) and not bool(pending.get("game_may_end", true)), "original end condition mid-macro-round becomes pending and cannot finish")
	var canceled := CORE.evaluate_end_gate(pending, false, true, 5)
	_expect(not bool(canceled.get("end_condition_pending", true)) and not bool(canceled.get("game_may_end", true)), "macro-round boundary revalidation clears a no-longer-valid end condition")
	var allowed := CORE.evaluate_end_gate(pending, true, true, 5)
	_expect(bool(allowed.get("game_may_end", false)) and bool(allowed.get("final_end_validation_ready", false)), "only a still-valid original condition at the complete macro-round boundary may finish")


func _test_fixed_seed_trace(vectors: Dictionary) -> void:
	var defaults: Dictionary = vectors.get("deterministic_default_stances", {})
	var parameters: Dictionary = vectors.get("simulation_parameters_not_balance_lock", {})
	var state_a := CORE.initial_market_state(["player_0", "player_1", "player_2"], 900626424)
	var state_b := CORE.initial_market_state(["player_0", "player_1", "player_2"], 900626424)
	var gdp := {"life": 6, "energy": 5, "industry": 4, "technology": 3, "commerce": 2, "shipping": 1}
	var run_a := CORE.advance_market_time(state_a, 540_000_000, defaults, gdp, int(parameters.get("gdp_equal_mix_bp", 0)), int(parameters.get("minimum_color_bp", 0)), int(parameters.get("maximum_color_bp", 10_000)))
	var run_b := CORE.advance_market_time(state_b, 540_000_000, defaults, gdp, int(parameters.get("gdp_equal_mix_bp", 0)), int(parameters.get("minimum_color_bp", 0)), int(parameters.get("maximum_color_bp", 10_000)))
	_expect(bool(run_a.get("advanced", false)) and CORE.stable_fingerprint(run_a) == CORE.stable_fingerprint(run_b), "same seed and same stance stream produce the same three-cycle event trace fingerprint")
	var track := CORE.build_track_state(_fixture_tokens(), 0, {"player_0": [0, 1]})
	var track_before := CORE.stable_fingerprint(track)
	CORE.advance_market_time(state_a, 180_000_000, defaults, gdp, int(parameters.get("gdp_equal_mix_bp", 0)), int(parameters.get("minimum_color_bp", 0)), int(parameters.get("maximum_color_bp", 10_000)))
	_expect(CORE.stable_fingerprint(track) == track_before, "a new supply distribution never rewrites commodity tokens already on the track")


func _test_production_negative_boundary(vectors: Dictionary) -> void:
	var forbidden_reference_symbols := [
		"SharedCommodityTrackCoreSemanticsReference",
		"SharedCommodityTrackAiSemanticsReference",
		"SharedCommodityTrackPlayerSemanticsReference",
		"SharedCommodityTrackSemanticQuerySourceReference",
		"SharedCommodityTrackThreeLayerSemanticsBench",
	]
	for path in [
		"res://scenes/runtime/GameRuntimeCoordinator.tscn",
		"res://scenes/main.tscn",
		"res://scripts/runtime/runtime_simulation_step.gd",
		"res://scripts/runtime/game_runtime_coordinator.gd",
		"res://scripts/runtime/ai_runtime_controller.gd",
		"res://scripts/ui/table/top_commodity_sushi_track.gd",
		"res://scripts/main.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		var clean := not source.is_empty()
		for symbol in forbidden_reference_symbols:
			clean = clean and not source.contains(symbol)
		_expect(clean, "%s has no reference-model production wiring" % path)
	var cutover: Dictionary = vectors.get("cutover", {})
	_expect(not bool(cutover.get("runtime_cutover_performed", true)) and not bool(cutover.get("old_rule_authority_disabled", true)), "old v0.6 remains the sole production authority while the new reference is passive")
	var contract_file := FileAccess.get_file_as_string("res://docs/rules/shared_partial_visibility_commodity_track_contract.json")
	var contract_value: Variant = JSON.parse_string(contract_file)
	var contract: Dictionary = contract_value if contract_value is Dictionary else {}
	_expect(not (contract.get("rule_authority_not_established", []) as Array).is_empty(), "unresolved topology is machine-readable and blocks accidental Phase D cutover")
	_expect(str(contract.get("game_semantic_constitution_version", "")) == "V0.7" and bool(contract.get("constitution_amendment_recorded", false)), "V0.7 semantic constitution amendment is machine-readable")
	var reference_gates: Dictionary = contract.get("nonproduction_reference_gates", {})
	_expect(bool(reference_gates.get("hand_pools_independent", false)) and bool(reference_gates.get("nested_allowlist_privacy", false)), "reference gates record independent capacities and nested privacy")
	var production_gates: Dictionary = contract.get("v0_7_production_cutover_gate", {})
	_expect(not bool(production_gates.get("hand_pools_independent", true)) and not bool(production_gates.get("full_v0_7_cutover", true)), "production V0.7 capacity and full-cutover gates remain false")
	var agent_constitution := FileAccess.get_file_as_string("res://AGENTS.md")
	_expect(agent_constitution.contains("## V0.7 Commodity Semantic Constitution") and agent_constitution.contains("NORMAL_CARD_HAND_LIMIT=5") and agent_constitution.contains("COMMODITY_CARD_HAND_LIMIT=5") and agent_constitution.contains("HAND_POOLS_ARE_INDEPENDENT=true"), "existing highest development authority records the V0.7 independent-capacity constitution")
	var active_rulebook := FileAccess.get_file_as_string("res://docs/tabletop_rulebook_v06.md")
	_expect(active_rulebook.contains("SUPERSEDED_AS_FUTURE_COMMODITY_DIRECTION") and active_rulebook.contains("FULL_V0_7_CUTOVER=false"), "v0.6 rulebook remains runtime authority but is marked superseded as future commodity direction")
	var readme := FileAccess.get_file_as_string("res://README.md")
	_expect(readme.contains("active runtime rules remain **v0.6**") and readme.contains("FULL_V0_7_CUTOVER=false"), "repository version boundary distinguishes active v0.6 from target V0.7")
	var ai_source := FileAccess.get_file_as_string("res://tests/support/shared_commodity_track_ai_semantics_reference.gd")
	var player_source := FileAccess.get_file_as_string("res://tests/support/shared_commodity_track_player_semantics_reference.gd")
	var query_source := FileAccess.get_file_as_string("res://tests/support/shared_commodity_track_semantic_query_source_reference.gd")
	_expect(not ai_source.contains("authority_state") and not player_source.contains("authority_state") and query_source.contains("authority_state"), "only the core/query-owned reference source accepts complete authority fixtures")


func _fixture_tokens() -> Array:
	var result: Array = []
	for index in range(CORE.COLOR_IDS.size()):
		result.append({
			"token_id": "token.%d" % index,
			"product_id": "product.%s.alpha" % CORE.COLOR_IDS[index],
			"color_id": CORE.COLOR_IDS[index],
			"commodity_level": 1,
			"spawn_sequence": index,
		})
	return result


func _merge_fixture_groups() -> Array:
	return [
		_group("group.base", "product.life.alpha", "life", 1),
		_group("group.unit.1", "product.life.alpha", "life", 1),
		_group("group.unit.2", "product.life.alpha", "life", 1),
		_group("group.unit.3", "product.life.alpha", "life", 1),
	]


func _group(group_id: String, product_id: String, color_id: String, level: int) -> Dictionary:
	return {
		"group_id": group_id,
		"product_id": product_id,
		"color_id": color_id,
		"commodity_level": level,
		"base_unit_count": level,
	}


func _inventory_with_contents(actor_id: String, normal_cards: Array, commodity_stacks: Array) -> Dictionary:
	var inventory := CORE.initial_inventory_state(actor_id)
	for card_variant in normal_cards:
		var add_normal := CORE.add_normal_card(inventory, str(card_variant))
		if not bool(add_normal.get("committed", false)):
			return {}
		inventory = add_normal.get("inventory", {})
	for stack_variant in commodity_stacks:
		if not (stack_variant is Dictionary):
			return {}
		var add_commodity := CORE.add_commodity_stack(inventory, stack_variant as Dictionary)
		if not bool(add_commodity.get("committed", false)):
			return {}
		inventory = add_commodity.get("inventory", {})
	return inventory


func _authority_for_inventory(inventory: Dictionary) -> Dictionary:
	var actors := ["player_0", "player_1", "player_2"]
	var inventories := {
		"player_0": CORE.initial_inventory_state("player_0"),
		"player_1": CORE.initial_inventory_state("player_1"),
		"player_2": CORE.initial_inventory_state("player_2"),
	}
	var actor_id := str(inventory.get("actor_id", ""))
	if inventories.has(actor_id):
		inventories[actor_id] = inventory.duplicate(true)
	return {
		"market_cycle": CORE.initial_market_state(actors, 900626424),
		"track": CORE.build_track_state(_fixture_tokens(), 0, {
			"player_0": [0, 1],
			"player_1": [2, 3],
			"player_2": [4, 5],
		}),
		"inventories": inventories,
		"actor_private_needs": {},
		"public_visible_opponent_demand": {},
		"public_stance_history": [],
		"rule_terms": {"commodity_merge_identity_policy_id": "same_product_id"},
		"end_gate": CORE.evaluate_end_gate({}, false, false, 0),
	}


func _distribution_total(distribution_variant: Variant) -> int:
	var distribution: Dictionary = distribution_variant if distribution_variant is Dictionary else {}
	var total := 0
	for color_id in CORE.COLOR_IDS:
		total += int(distribution.get(color_id, 0))
	return total


func _same_members(left: Array, right: Array) -> bool:
	var left_copy := left.duplicate()
	var right_copy := right.duplicate()
	left_copy.sort()
	right_copy.sort()
	return left_copy == right_copy and left.size() == right.size()


func _sorted_keys(value: Dictionary) -> Array:
	var keys := value.keys()
	keys.sort()
	return keys


func _load_vectors() -> Dictionary:
	var file := FileAccess.open(VECTOR_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("COMMODITY_TRACK_THREE_LAYER_SEMANTICS_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	push_error("COMMODITY_TRACK_THREE_LAYER_SEMANTICS_TEST|status=FAIL|checks=%d|failures=%d\n- %s" % [_checks, _failures.size(), "\n- ".join(_failures)])
	quit(1)
