extends Node

const CORE := preload("res://tests/support/shared_commodity_track_core_semantics_reference.gd")
const AI := preload("res://tests/support/shared_commodity_track_ai_semantics_reference.gd")
const PLAYER := preload("res://tests/support/shared_commodity_track_player_semantics_reference.gd")
const QUERY := preload("res://tests/support/shared_commodity_track_semantic_query_source_reference.gd")
const VECTOR_PATH := "res://docs/rules/shared_partial_visibility_commodity_track_test_vectors.json"

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var vectors := _vectors()
	_check(not vectors.is_empty(), "semantic vectors load")
	if not vectors.is_empty():
		var authority := _authority_fixture()
		var ai_observation := QUERY.ai_observation_for_bound_actor(authority, "player_0", "player_0")
		var player_projection := QUERY.player_projection_for_bound_viewer(authority, "player_0", "player_0")
		var ai_intent := AI.choose_market_stance(ai_observation, "normal", 1)
		_check(not (authority.get("market_cycle", {}) as Dictionary).is_empty(), "core semantic state builds")
		_check(AI.observation_valid(ai_observation), "AI semantic firewall accepts actor observation")
		_check(PLAYER.projection_valid(player_projection), "player semantic projection validates")
		_check(CORE.stance_intent_valid(ai_intent, ["player_0", "player_1", "player_2"]), "AI uses shared core MarketStanceIntent")
		_check(not JSON.stringify(ai_observation).contains("hidden_forward_order"), "AI projection hides full lead order")
		_check(not JSON.stringify(player_projection).contains("ordered_item_tokens"), "player projection hides full track")
		_check(QUERY.ai_observation_for_bound_actor(authority, "player_0", "player_1").is_empty(), "AI port rejects cross-seat request")
		_check(QUERY.player_projection_for_bound_viewer(authority, "player_0", "player_1").is_empty(), "player port rejects cross-viewer request")
		var capacity: Dictionary = player_projection.get("inventory_capacity", {})
		_check(str(capacity.get("normal_hand_label", "")) == "普通手牌：5 / 5", "normal hand renders its own five-card capacity")
		_check(str(capacity.get("commodity_inventory_label", "")) == "商品库存：0 / 5" and bool(capacity.get("commodity_acquisition_allowed", false)), "commodity inventory remains open when normal hand is full")
		var poisoned := authority.duplicate(true)
		poisoned["public_visible_opponent_demand"] = {"life": 1, "save_payload": {"rng_cursor": 7, "lead_player_id": "player_2"}}
		var sanitized := QUERY.ai_observation_for_bound_actor(poisoned, "player_0", "player_0")
		_check(AI.observation_valid(sanitized) and not JSON.stringify(sanitized).contains("save_payload"), "nested AI allowlist strips hostile Save and RNG aliases")
		_check(not bool((vectors.get("cutover", {}) as Dictionary).get("full_rule_cutover", true)), "bench cannot activate production cutover")
	if _failures.is_empty():
		print("SHARED_COMMODITY_TRACK_THREE_LAYER_SEMANTICS_BENCH|status=PASS|checks=%d|failures=0" % _checks)
		await get_tree().create_timer(5.0).timeout
		get_tree().quit(0)
		return
	push_error("SHARED_COMMODITY_TRACK_THREE_LAYER_SEMANTICS_BENCH|status=FAIL|checks=%d|failures=%d|notes=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(1)


func _authority_fixture() -> Dictionary:
	var market := CORE.initial_market_state(["player_0", "player_1", "player_2"], 900626424)
	var track := CORE.build_track_state([
		{"token_id": "token.life", "product_id": "product.life.alpha", "color_id": "life", "commodity_level": 1},
		{"token_id": "token.energy", "product_id": "product.energy.alpha", "color_id": "energy", "commodity_level": 1},
		{"token_id": "token.industry", "product_id": "product.industry.alpha", "color_id": "industry", "commodity_level": 1},
	], 0, {
		"player_0": [0],
		"player_1": [1],
		"player_2": [2],
	})
	var inventory_0 := CORE.initial_inventory_state("player_0")
	for index in range(5):
		var add_result := CORE.add_normal_card(inventory_0, "normal.%d" % index)
		inventory_0 = add_result.get("inventory", {})
	return {
		"market_cycle": market,
		"track": track,
		"inventories": {
			"player_0": inventory_0,
			"player_1": CORE.initial_inventory_state("player_1"),
			"player_2": CORE.initial_inventory_state("player_2"),
		},
		"actor_private_needs": {"player_0": {"life": 4, "energy": 1}},
		"public_visible_opponent_demand": {"industry": 2},
		"public_stance_history": [],
		"rule_terms": {"commodity_merge_identity_policy_id": "same_product_id"},
		"end_gate": CORE.evaluate_end_gate({}, false, false, 0),
	}


func _vectors() -> Dictionary:
	var file := FileAccess.open(VECTOR_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
