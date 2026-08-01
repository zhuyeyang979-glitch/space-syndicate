extends RefCounted
class_name V072DeterministicSimulator

const SCHEMA_VERSION := 1
const SIMULATION_ID := "v072.detached.free_starter_bootstrap.v1"
const SIMULATION_AGENT_POLICY_ID := "v072.closed_bootstrap_heuristic.v1"
const PLAYER_COUNTS := [3, 4, 6, 8]
const DEFAULT_SEED_COUNT := 500
const FIXED_SEED_BASE := 900626424
const SIMULATION_BATCH_COUNT := 18
const BATCH_SECONDS := 30
const HAND_LIMIT := 5
const ASSET_CAP := 6
const FACILITY_SLOT_COUNT := 36
const TRACK_OPPORTUNITIES_PER_BATCH := 2
const NORMAL_CARD_PURCHASE_CASH_COST := 3
const SOLAR_CHANNEL_BASE_RATES := {
	"factory_production_rate": 12,
	"transport_throughput": 10,
	"warehouse_ingress_throughput": 11,
	"warehouse_egress_throughput": 11,
	"market_demand_or_consumption_rate": 9,
}

const PROFILE_V071_FAST := "V071_CANDIDATE_A_FAST"
const PROFILE_V072_FAST := "V072_STARTER_FREE_FAST"
const PROFILE_V072_NO_CROSS_MERGE := "V072_STARTER_FREE_NO_CROSS_MERGE"

const V071_PROFILE_FINGERPRINT_INPUT := "V071_CANDIDATE_A_FAST|initial_assets_per_color=2|normal_card_ratio_basis_points=6000|commodity_card_ratio_basis_points=4000|single_color_net_intervention_cap_enabled=true|single_color_net_intervention_cap_basis_points=1200|max_asset_refresh_per_color_per_batch=3|hand_maintenance_timeout_seconds=8|lead_tenure_batches=1|color_cycle_batches=6"
const V071_PROFILE_FINGERPRINT := "8d8de8d406ca2f7d5123ecc951a606a0a08b56282bc3d6a40e0cd4d5ff50f19a"
const V072_PROFILE_FINGERPRINT_INPUT := "V072_STARTER_FREE_FAST|initial_assets_per_color=0|starter_primary_asset_cost=0|standard_l1_primary_asset_cost=1|normal_card_ratio_basis_points=6000|commodity_card_ratio_basis_points=4000|single_color_net_intervention_cap_enabled=true|single_color_net_intervention_cap_basis_points=1200|max_asset_refresh_per_color_per_batch=3|hand_maintenance_timeout_seconds=8|lead_tenure_batches=1|color_cycle_batches=6"
const V072_PROFILE_FINGERPRINT := "b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48"
const V072_NO_CROSS_MERGE_FINGERPRINT_INPUT := "V072_STARTER_FREE_NO_CROSS_MERGE|initial_assets_per_color=0|starter_primary_asset_cost=0|standard_l1_primary_asset_cost=1|normal_card_ratio_basis_points=6000|commodity_card_ratio_basis_points=4000|single_color_net_intervention_cap_enabled=true|single_color_net_intervention_cap_basis_points=1200|max_asset_refresh_per_color_per_batch=3|hand_maintenance_timeout_seconds=8|lead_tenure_batches=1|color_cycle_batches=6|starter_standard_l1_merge_allowed=false"
const V072_NO_CROSS_MERGE_FINGERPRINT := "466c86f0a930337c92d391a1b873b714a259ed31b8bd94fde49ad10a803fe579"

const COLORS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]

const REQUIRED_METRIC_KEYS := [
	"opening_starter_card_count",
	"opening_asset_affordable_card_count",
	"opening_legal_target_count",
	"first_facility_batch",
	"first_factory_market_chain_batch",
	"first_nonzero_asset_refresh_batch",
	"first_standard_l1_affordable_batch",
	"first_standard_l1_played_batch",
	"starter_action_share_batch_1",
	"starter_action_share_batch_3",
	"starter_action_share_batch_6",
	"starter_action_share_batch_10",
	"standard_card_action_share",
	"asset_spend_per_batch",
	"asset_overflow_rate",
	"zero_asset_block_rate_standard_cards_only",
	"normal_purchase_to_first_draw_batches",
	"normal_purchase_to_first_play_batches",
	"starter_standard_merge_rate",
	"starter_privilege_consumed_rate",
	"facility_slot_saturation_batch",
	"free_starter_repeat_build_rate",
	"victory_pending_tail_seconds",
	"resolution_p95_seconds",
	"sunlit_chain_throughput_ratio",
]


class DeterministicStream extends RefCounted:
	const MODULUS := 2147483647
	const MULTIPLIER := 48271

	var state := 1
	var draw_count := 0

	func _init(seed: int) -> void:
		state = posmod(seed, MODULUS - 1) + 1

	func next_int() -> int:
		state = (state * MULTIPLIER) % MODULUS
		draw_count += 1
		return state

	func bounded(limit: int) -> int:
		return next_int() % limit if limit > 0 else 0

	func chance_basis_points(threshold: int) -> bool:
		return bounded(10000) < clampi(threshold, 0, 10000)


static func profiles() -> Array[Dictionary]:
	return [
		_profile(
			PROFILE_V071_FAST,
			"historical_v071_comparison",
			2,
			false,
			false,
			V071_PROFILE_FINGERPRINT_INPUT,
			V071_PROFILE_FINGERPRINT
		),
		_profile(
			PROFILE_V072_FAST,
			"approved_first_human_test_sample",
			0,
			true,
			true,
			V072_PROFILE_FINGERPRINT_INPUT,
			V072_PROFILE_FINGERPRINT
		),
		_profile(
			PROFILE_V072_NO_CROSS_MERGE,
			"diagnostic_not_candidate_authority",
			0,
			true,
			false,
			V072_NO_CROSS_MERGE_FINGERPRINT_INPUT,
			V072_NO_CROSS_MERGE_FINGERPRINT
		),
	]


static func profile_by_id(profile_id: String) -> Dictionary:
	for profile in profiles():
		if str(profile.get("profile_id", "")) == profile_id:
			return profile.duplicate(true)
	return {}


static func starter_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for color in COLORS:
		for kind in ["factory", "market"]:
			definitions.append({
				"definition_id": "starter.facility.%s.%s.rank_1" % [kind, color],
				"origin_class": "starter_bootstrap",
				"kind": kind,
				"color": color,
				"level": 1,
				"merge_family_id": "facility.%s.%s" % [kind, color],
				"asset_cost_profile": "starter_zero_asset",
				"primary_asset_cost": 0,
				"secondary_asset_cost": 0,
				"any_asset_cost": 0,
				"starter_badge": true,
				"starter_badge_asset_key": "card.badge.starter",
				"track_spawn_allowed": false,
				"purchase_allowed": false,
			})
	return definitions


static func standard_definition(color: String, kind: String, level: int = 1) -> Dictionary:
	if color not in COLORS or kind not in ["factory", "market"] or level < 1 or level > 4:
		return {}
	return {
		"definition_id": "facility.%s.%s.rank_%d" % [kind, color, level],
		"origin_class": "standard",
		"kind": kind,
		"color": color,
		"level": level,
		"merge_family_id": "facility.%s.%s" % [kind, color],
		"asset_cost_profile": "standard_rank_%d" % level,
		"primary_asset_cost": level,
		"secondary_asset_cost": 0,
		"any_asset_cost": 0,
		"starter_badge": false,
		"starter_badge_asset_key": "",
		"track_spawn_allowed": level == 1,
		"purchase_allowed": level == 1,
	}


static func genesis_deck(player_id: String, profile_id: String) -> Array[Dictionary]:
	var use_starters := profile_id != PROFILE_V071_FAST
	var definitions := starter_definitions() if use_starters else _standard_l1_definitions()
	var cards: Array[Dictionary] = []
	for index in range(definitions.size()):
		var card := definitions[index].duplicate(true)
		card["card_instance_id"] = "%s.genesis.%02d" % [player_id, index + 1]
		card["genesis_created"] = true
		card["purchase_batch"] = 0
		cards.append(card)
	return cards


static func asset_cost_for_card(card: Dictionary) -> int:
	var definition_id := str(card.get("definition_id", ""))
	var origin_class := str(card.get("origin_class", ""))
	var profile := str(card.get("asset_cost_profile", ""))
	if definition_id.begins_with("starter.facility.") \
			and origin_class == "starter_bootstrap" \
			and profile == "starter_zero_asset":
		return 0
	if origin_class == "standard" and profile == "standard_rank_%d" % int(
		card.get("level", 0)
	):
		return clampi(int(card.get("level", 0)), 1, 4)
	return -1


static func starter_standard_merge(
	left: Dictionary,
	right: Dictionary,
	total_normal_card_count: int,
	cross_merge_allowed: bool = true
) -> Dictionary:
	var left_origin := str(left.get("origin_class", ""))
	var right_origin := str(right.get("origin_class", ""))
	var origins := [left_origin, right_origin]
	var same_family := not str(left.get("merge_family_id", "")).is_empty() \
		and str(left.get("merge_family_id", "")) == str(right.get("merge_family_id", ""))
	var one_starter_one_standard := origins.has("starter_bootstrap") \
		and origins.has("standard")
	var accepted := cross_merge_allowed \
		and same_family \
		and one_starter_one_standard \
		and int(left.get("level", 0)) == 1 \
		and int(right.get("level", 0)) == 1 \
		and total_normal_card_count - 1 >= 5
	var reason_code := "starter_standard_l1_merged"
	if not cross_merge_allowed:
		reason_code = "starter_standard_merge_disabled"
	elif not same_family or not one_starter_one_standard:
		reason_code = "merge_family_or_origin_mismatch"
	elif total_normal_card_count - 1 < 5:
		reason_code = "minimum_normal_deck_size_violation"
	elif int(left.get("level", 0)) != 1 or int(right.get("level", 0)) != 1:
		reason_code = "starter_standard_level_mismatch"
	var output := {}
	if accepted:
		output = standard_definition(
			str(left.get("color", "")),
			str(left.get("kind", "")),
			2
		)
	var receipt := {
		"accepted": accepted,
		"reason_code": reason_code,
		"source_definition_ids": [
			str(left.get("definition_id", "")),
			str(right.get("definition_id", "")),
		],
		"source_origin_classes": origins,
		"output_definition_id": str(output.get("definition_id", "")),
		"output_origin_class": str(output.get("origin_class", "")),
		"starter_privilege_consumed": accepted,
		"output": output,
	}
	receipt["receipt_fingerprint"] = fingerprint(receipt)
	return receipt


static func preview_opening_hand(seed: int = FIXED_SEED_BASE) -> Array[Dictionary]:
	var stream := DeterministicStream.new(_derive_seed(seed, "review.opening_hand"))
	var deck := genesis_deck("review.player", PROFILE_V072_FAST)
	_shuffle_in_place(deck, stream)
	var hand: Array[Dictionary] = []
	while hand.size() < HAND_LIMIT:
		hand.append(deck.pop_back())
	return hand


static func solar_chain_probe() -> Dictionary:
	var dark := _solar_chain_throughput(1)
	var sunlit := _solar_chain_throughput(2)
	return {
		"dark_throughput": int(dark.get("throughput", 0)),
		"sunlit_throughput": int(sunlit.get("throughput", 0)),
		"throughput_ratio": _round_ratio(
			float(sunlit.get("throughput", 0)) / float(dark.get("throughput", 1))
		),
		"application_count_by_channel": (
			sunlit.get("application_count_by_channel", {}) as Dictionary
		).duplicate(true),
		"maximum_application_count_per_channel": int(
			sunlit.get("maximum_application_count_per_channel", 0)
		),
	}


func run_matrix(seed_count: int = DEFAULT_SEED_COUNT) -> Dictionary:
	if seed_count <= 0:
		return _invalid_report("seed_count_invalid")
	var profile_rows := profiles()
	var configuration_results: Array[Dictionary] = []
	var profile_results: Array[Dictionary] = []
	for profile in profile_rows:
		var combined := _new_accumulator()
		var by_player_count: Dictionary = {}
		for player_count in PLAYER_COUNTS:
			var result := run_configuration(profile, player_count, seed_count)
			configuration_results.append(_public_result(result))
			by_player_count[str(player_count)] = _public_result(result)
			_combine_accumulators(combined, result.get("_accumulator", {}) as Dictionary)
		var metrics := _metrics_from_accumulator(combined)
		var failed_targets := _failed_targets(profile, metrics)
		var profile_result := {
			"profile_id": str(profile.get("profile_id", "")),
			"profile_fingerprint": str(profile.get("profile_fingerprint", "")),
			"profile_status": str(profile.get("profile_status", "")),
			"configuration_count": PLAYER_COUNTS.size(),
			"match_count": seed_count * PLAYER_COUNTS.size(),
			"player_counts": PLAYER_COUNTS.duplicate(),
			"seed_count_per_configuration": seed_count,
			"metrics": metrics,
			"failed_balance_targets": failed_targets,
			"failed_balance_target_count": failed_targets.size(),
			"by_player_count": by_player_count,
		}
		profile_result["profile_result_fingerprint"] = fingerprint(profile_result)
		profile_results.append(profile_result)
	var approved := _profile_result_by_id(profile_results, PROFILE_V072_FAST)
	var report := {
		"schema_version": SCHEMA_VERSION,
		"simulation_id": SIMULATION_ID,
		"simulation_agent_policy_id": SIMULATION_AGENT_POLICY_ID,
		"detached_reference_only": true,
		"production_runtime_connected": false,
		"production_save_used": false,
		"production_rng_used": false,
		"new_rng_stream_count": 0,
		"starter_shuffle_stream_id": "starter_deck_shuffle",
		"human_fun_proven": false,
		"human_test_required": true,
		"profile_count": profile_rows.size(),
		"profiles": profile_rows,
		"player_counts": PLAYER_COUNTS.duplicate(),
		"player_count_coverage": PLAYER_COUNTS.size(),
		"seed_count_per_configuration": seed_count,
		"qualification_seed_floor": DEFAULT_SEED_COUNT,
		"qualification_seed_floor_met": seed_count >= DEFAULT_SEED_COUNT,
		"configuration_count": profile_rows.size() * PLAYER_COUNTS.size(),
		"total_match_count": profile_rows.size() * PLAYER_COUNTS.size() * seed_count,
		"simulation_batch_count_per_match": SIMULATION_BATCH_COUNT,
		"fixed_seed_schedule": {
			"base_seed": FIXED_SEED_BASE,
			"formula_id": "base_plus_player_count_times_100000_plus_seed_index_times_7919",
			"profile_independent_for_paired_comparison": true,
		},
		"required_metric_keys": REQUIRED_METRIC_KEYS.duplicate(),
		"configuration_results": configuration_results,
		"profile_results": profile_results,
		"approved_profile_id": PROFILE_V072_FAST,
		"approved_profile_fingerprint": V072_PROFILE_FINGERPRINT,
		"approved_profile_failed_balance_targets": (
			approved.get("failed_balance_targets", []) as Array
		).duplicate(),
	}
	report["report_fingerprint"] = fingerprint(report)
	return report


func run_configuration(
	profile: Dictionary,
	player_count: int,
	seed_count: int = DEFAULT_SEED_COUNT
) -> Dictionary:
	if not _profile_is_valid(profile) or player_count not in PLAYER_COUNTS or seed_count <= 0:
		return {
			"valid": false,
			"reason_code": "simulation_configuration_invalid",
			"_accumulator": _new_accumulator(),
		}
	var accumulator := _new_accumulator()
	var match_fingerprints: Array[String] = []
	for seed_index in range(seed_count):
		var seed := fixed_seed_for(player_count, seed_index)
		match_fingerprints.append(
			_simulate_match(profile, player_count, seed, accumulator)
		)
	var metrics := _metrics_from_accumulator(accumulator)
	var result := {
		"valid": true,
		"reason_code": "simulation_configuration_completed",
		"profile_id": str(profile.get("profile_id", "")),
		"profile_fingerprint": str(profile.get("profile_fingerprint", "")),
		"player_count": player_count,
		"seed_count": seed_count,
		"match_count": seed_count,
		"metrics": metrics,
		"failed_balance_targets": _failed_targets(profile, metrics),
		"run_fingerprint_chain": fingerprint(match_fingerprints),
		"replay_identity": {
			"profile_id": str(profile.get("profile_id", "")),
			"profile_fingerprint": str(profile.get("profile_fingerprint", "")),
			"simulation_agent_policy_id": SIMULATION_AGENT_POLICY_ID,
			"first_seed": fixed_seed_for(player_count, 0),
			"last_seed": fixed_seed_for(player_count, seed_count - 1),
			"seed_count": seed_count,
		},
	}
	result["configuration_fingerprint"] = fingerprint(result)
	result["_accumulator"] = accumulator
	return result


static func fixed_seed_for(player_count: int, seed_index: int) -> int:
	return FIXED_SEED_BASE + player_count * 100000 + seed_index * 7919


func _simulate_match(
	profile: Dictionary,
	player_count: int,
	seed: int,
	accumulator: Dictionary
) -> String:
	var shared_stream := DeterministicStream.new(_derive_seed(seed, "shared"))
	var players: Array[Dictionary] = []
	var streams: Array[DeterministicStream] = []
	for player_index in range(player_count):
		var stream := DeterministicStream.new(
			_derive_seed(seed, "player.%d.starter_deck_shuffle" % player_index)
		)
		streams.append(stream)
		players.append(_new_player_state(
			"player.%02d" % (player_index + 1),
			profile,
			stream,
			accumulator
		))
	var match_action_counts: Array[int] = []
	for batch_id in range(1, SIMULATION_BATCH_COUNT + 1):
		var batch_actions := 0
		var batch_major_actions := 0
		for player_index in range(player_count):
			var player := players[player_index]
			var stream := streams[player_index]
			_refresh_assets(player, profile, batch_id, stream, accumulator)
			var action_result := _play_batch(
				player,
				profile,
				batch_id,
				stream,
				accumulator
			)
			batch_actions += int(action_result.get("action_count", 0))
			batch_major_actions += int(action_result.get("major_action_count", 0))
			_process_track(player, profile, batch_id, stream, accumulator)
			_offer_cross_merge(player, profile, batch_id, stream, accumulator)
			_draw_to_limit(player, stream, batch_id, accumulator)
			_maintain_hand(player, stream, batch_id, accumulator)
			accumulator["player_batch_count"] = int(
				accumulator.get("player_batch_count", 0)
			) + 1
		match_action_counts.append(batch_actions)
		(accumulator.get("resolution_seconds", []) as Array).append(
			_predicted_resolution_seconds(batch_actions, batch_major_actions)
		)
	var macro_round_batches := player_count * int(profile.get("lead_tenure_batches", 1))
	var qualification_batch := 4 + shared_stream.bounded(10)
	var tail_batches := posmod(
		macro_round_batches - (qualification_batch % macro_round_batches),
		macro_round_batches
	)
	(accumulator.get("victory_tail_seconds", []) as Array).append(
		tail_batches * BATCH_SECONDS
	)
	(accumulator.get("solar_ratios", []) as Array).append(
		float(solar_chain_probe().get("throughput_ratio", 0.0))
	)
	for player in players:
		_finalize_player_metrics(player, accumulator)
	return fingerprint({
		"seed": seed,
		"profile_id": str(profile.get("profile_id", "")),
		"profile_fingerprint": str(profile.get("profile_fingerprint", "")),
		"player_count": player_count,
		"batch_action_counts": match_action_counts,
		"victory_tail_batches": tail_batches,
		"players": _player_summaries(players),
		"shared_draw_count": shared_stream.draw_count,
	})


func _new_player_state(
	player_id: String,
	profile: Dictionary,
	stream: DeterministicStream,
	accumulator: Dictionary
) -> Dictionary:
	var deck := genesis_deck(player_id, str(profile.get("profile_id", "")))
	_shuffle_in_place(deck, stream)
	var hand: Array[Dictionary] = []
	while hand.size() < HAND_LIMIT:
		hand.append(deck.pop_back())
	var assets: Dictionary = {}
	var facility_counts: Dictionary = {}
	for color in COLORS:
		assets[color] = int(profile.get("initial_assets_per_color", 0))
		facility_counts[color] = {"factory": 0, "market": 0}
	var opening_starters := 0
	var opening_affordable := 0
	var opening_legal := 0
	for card in hand:
		opening_starters += 1 if str(card.get("origin_class", "")) == "starter_bootstrap" else 0
		var color := str(card.get("color", ""))
		var cost := asset_cost_for_card(card)
		opening_affordable += 1 if cost >= 0 and int(assets.get(color, 0)) >= cost else 0
		opening_legal += 1 if _card_has_legal_target(card, facility_counts, 0) else 0
	(accumulator.get("opening_starter_counts", []) as Array).append(opening_starters)
	(accumulator.get("opening_affordable_counts", []) as Array).append(opening_affordable)
	(accumulator.get("opening_legal_counts", []) as Array).append(opening_legal)
	if bool(profile.get("starter_bootstrap_enabled", false)):
		accumulator["genesis_starter_instance_count"] = int(
			accumulator.get("genesis_starter_instance_count", 0)
		) + 12
	return {
		"player_id": player_id,
		"initial_assets_per_color": int(profile.get("initial_assets_per_color", 0)),
		"assets": assets,
		"fixed_remainders": _zero_color_dictionary(),
		"cash": 18,
		"draw_pile": deck,
		"hand": hand,
		"discard": [],
		"committed_escrow": [],
		"facility_counts": facility_counts,
		"facility_count": 0,
		"purchase_sequence": 0,
		"merge_sequence": 0,
		"first_facility_batch": 0,
		"first_chain_batch": 0,
		"first_nonzero_asset_refresh_batch": 0,
		"first_standard_affordable_batch": 0,
		"first_standard_played_batch": 0,
		"first_purchase_draw_latency": -1,
		"first_purchase_play_latency": -1,
		"slot_saturation_batch": 0,
	}


func _refresh_assets(
	player: Dictionary,
	profile: Dictionary,
	batch_id: int,
	stream: DeterministicStream,
	accumulator: Dictionary
) -> void:
	if batch_id <= 1 or int(player.get("facility_count", 0)) <= 0:
		return
	var assets := player.get("assets", {}) as Dictionary
	var facilities := player.get("facility_counts", {}) as Dictionary
	var candidates: Array[String] = []
	for color in COLORS:
		var kinds := facilities.get(color, {}) as Dictionary
		var count := int(kinds.get("factory", 0)) + int(kinds.get("market", 0))
		if count > 0:
			candidates.append(color)
	if candidates.is_empty():
		return
	var refresh_count := mini(
		int(profile.get("max_asset_refresh_per_color_per_batch", 3)),
		1 + (1 if _completed_chain_count(player) >= 3 and batch_id % 2 == 0 else 0)
	)
	var refreshed := 0
	var deficit_colors := _standard_deficit_colors(player, candidates)
	for offset in range(refresh_count):
		var source_colors := deficit_colors if not deficit_colors.is_empty() else candidates
		var color := source_colors[
			(batch_id + offset + stream.bounded(source_colors.size())) % source_colors.size()
		]
		accumulator["asset_refresh_candidate_points"] = int(
			accumulator.get("asset_refresh_candidate_points", 0)
		) + 1
		if int(assets.get(color, 0)) >= ASSET_CAP:
			accumulator["asset_overflow_points"] = int(
				accumulator.get("asset_overflow_points", 0)
			) + 1
			continue
		assets[color] = int(assets.get(color, 0)) + 1
		refreshed += 1
	if refreshed > 0 and int(player.get("first_nonzero_asset_refresh_batch", 0)) == 0:
		player["first_nonzero_asset_refresh_batch"] = batch_id


func _process_track(
	player: Dictionary,
	profile: Dictionary,
	batch_id: int,
	stream: DeterministicStream,
	accumulator: Dictionary
) -> void:
	for _opportunity in range(TRACK_OPPORTUNITIES_PER_BATCH):
		if not stream.chance_basis_points(7600):
			continue
		if stream.bounded(10000) >= int(profile.get("normal_card_ratio_basis_points", 6000)):
			continue
		if int(player.get("cash", 0)) < NORMAL_CARD_PURCHASE_CASH_COST:
			continue
		var color := _purchase_color(player, stream)
		var kind := "factory" if stream.bounded(2) == 0 else "market"
		var card := standard_definition(color, kind, 1)
		player["purchase_sequence"] = int(player.get("purchase_sequence", 0)) + 1
		card["card_instance_id"] = "%s.purchase.%04d" % [
			str(player.get("player_id", "")),
			int(player.get("purchase_sequence", 0)),
		]
		card["genesis_created"] = false
		card["purchase_batch"] = batch_id
		(player.get("discard", []) as Array).append(card)
		player["cash"] = int(player.get("cash", 0)) - NORMAL_CARD_PURCHASE_CASH_COST
		accumulator["normal_purchase_count"] = int(
			accumulator.get("normal_purchase_count", 0)
		) + 1


func _offer_cross_merge(
	player: Dictionary,
	profile: Dictionary,
	batch_id: int,
	stream: DeterministicStream,
	accumulator: Dictionary
) -> void:
	var pair := _first_starter_standard_pair(player.get("hand", []) as Array)
	if pair.is_empty():
		return
	accumulator["starter_standard_merge_offer_count"] = int(
		accumulator.get("starter_standard_merge_offer_count", 0)
	) + 1
	if not stream.chance_basis_points(6200):
		return
	var hand := player.get("hand", []) as Array
	var left_index := int(pair.get("left_index", -1))
	var right_index := int(pair.get("right_index", -1))
	var left := hand[left_index] as Dictionary
	var right := hand[right_index] as Dictionary
	var receipt := starter_standard_merge(
		left,
		right,
		_normal_card_total(player),
		bool(profile.get("starter_standard_l1_merge_allowed", false))
	)
	if not bool(receipt.get("accepted", false)):
		return
	var high := maxi(left_index, right_index)
	var low := mini(left_index, right_index)
	hand.remove_at(high)
	hand.remove_at(low)
	var output := (receipt.get("output", {}) as Dictionary).duplicate(true)
	player["merge_sequence"] = int(player.get("merge_sequence", 0)) + 1
	output["card_instance_id"] = "%s.merge.%04d" % [
		str(player.get("player_id", "")),
		int(player.get("merge_sequence", 0)),
	]
	output["genesis_created"] = false
	output["purchase_batch"] = batch_id
	hand.append(output)
	accumulator["starter_standard_merge_accept_count"] = int(
		accumulator.get("starter_standard_merge_accept_count", 0)
	) + 1
	accumulator["starter_privilege_consumed_count"] = int(
		accumulator.get("starter_privilege_consumed_count", 0)
	) + 1


func _play_batch(
	player: Dictionary,
	_profile: Dictionary,
	batch_id: int,
	stream: DeterministicStream,
	accumulator: Dictionary
) -> Dictionary:
	var hand := player.get("hand", []) as Array
	var assets := player.get("assets", {}) as Dictionary
	var facilities := player.get("facility_counts", {}) as Dictionary
	var target_actions := 3
	var candidates: Array[Dictionary] = []
	for card_variant in hand:
		var card := card_variant as Dictionary
		candidates.append({
			"card": card,
			"priority": _card_priority(card, player),
		})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_priority := int(left.get("priority", 0))
		var right_priority := int(right.get("priority", 0))
		if left_priority != right_priority:
			return left_priority < right_priority
		return str((left.get("card", {}) as Dictionary).get("card_instance_id", "")) \
			< str((right.get("card", {}) as Dictionary).get("card_instance_id", ""))
	)
	var played_ids: Array[String] = []
	var action_count := 0
	var major_action_count := 0
	for candidate in candidates:
		if action_count >= target_actions or int(player.get("facility_count", 0)) >= FACILITY_SLOT_COUNT:
			break
		var card := candidate.get("card", {}) as Dictionary
		if not _card_has_legal_target(card, facilities, int(player.get("facility_count", 0))):
			continue
		var color := str(card.get("color", ""))
		var cost := asset_cost_for_card(card)
		if str(card.get("origin_class", "")) == "standard":
			accumulator["standard_card_consideration_count"] = int(
				accumulator.get("standard_card_consideration_count", 0)
			) + 1
			if cost >= 0 and int(assets.get(color, 0)) < cost:
				accumulator["standard_zero_asset_block_count"] = int(
					accumulator.get("standard_zero_asset_block_count", 0)
				) + 1
		if cost < 0 or int(assets.get(color, 0)) < cost:
			continue
		if str(card.get("origin_class", "")) == "standard" \
				and int(card.get("level", 0)) == 1 \
				and int(player.get("first_standard_affordable_batch", 0)) == 0:
			player["first_standard_affordable_batch"] = batch_id
		assets[color] = int(assets.get(color, 0)) - cost
		accumulator["asset_spend_points"] = int(
			accumulator.get("asset_spend_points", 0)
		) + cost
		var origin := str(card.get("origin_class", ""))
		accumulator["total_action_count"] = int(accumulator.get("total_action_count", 0)) + 1
		if origin == "starter_bootstrap":
			accumulator["starter_action_count"] = int(
				accumulator.get("starter_action_count", 0)
			) + 1
			if _same_facility_already_built(card, facilities):
				accumulator["starter_repeat_build_count"] = int(
					accumulator.get("starter_repeat_build_count", 0)
				) + 1
		else:
			accumulator["standard_action_count"] = int(
				accumulator.get("standard_action_count", 0)
			) + 1
			if int(card.get("level", 0)) == 1:
				if int(player.get("first_standard_played_batch", 0)) == 0:
					player["first_standard_played_batch"] = batch_id
				var purchase_batch := int(card.get("purchase_batch", 0))
				if purchase_batch > 0 \
						and int(player.get("first_purchase_play_latency", -1)) < 0:
					player["first_purchase_play_latency"] = batch_id - purchase_batch
		var batch_counts := accumulator.get("action_counts_by_batch", {}) as Dictionary
		var row := batch_counts.get(batch_id, {"starter": 0, "standard": 0}) as Dictionary
		row["starter" if origin == "starter_bootstrap" else "standard"] = int(
			row.get("starter" if origin == "starter_bootstrap" else "standard", 0)
		) + 1
		batch_counts[batch_id] = row
		_build_facility(card, player, batch_id)
		played_ids.append(str(card.get("card_instance_id", "")))
		action_count += 1
		major_action_count += 1 if int(card.get("level", 1)) >= 3 else 0
	for card_id in played_ids:
		for index in range(hand.size() - 1, -1, -1):
			var card := hand[index] as Dictionary
			if str(card.get("card_instance_id", "")) == card_id:
				(player.get("discard", []) as Array).append(card)
				hand.remove_at(index)
				break
	player["cash"] = int(player.get("cash", 0)) + _completed_chain_count(player) * 2
	return {
		"action_count": action_count,
		"major_action_count": major_action_count,
	}


func _draw_to_limit(
	player: Dictionary,
	stream: DeterministicStream,
	batch_id: int,
	_accumulator: Dictionary
) -> void:
	var hand := player.get("hand", []) as Array
	var draw_pile := player.get("draw_pile", []) as Array
	var discard := player.get("discard", []) as Array
	while hand.size() < HAND_LIMIT:
		if draw_pile.is_empty():
			if discard.is_empty():
				break
			draw_pile.append_array(discard)
			discard.clear()
			_shuffle_in_place(draw_pile, stream)
		var card := draw_pile.pop_back() as Dictionary
		hand.append(card)
		var purchase_batch := int(card.get("purchase_batch", 0))
		if purchase_batch > 0 and int(player.get("first_purchase_draw_latency", -1)) < 0:
			player["first_purchase_draw_latency"] = batch_id - purchase_batch


func _maintain_hand(
	player: Dictionary,
	stream: DeterministicStream,
	batch_id: int,
	accumulator: Dictionary
) -> void:
	var hand := player.get("hand", []) as Array
	if hand.is_empty():
		return
	var every_card_blocked := true
	for card in hand:
		if _card_is_affordable(card, player) and _card_has_legal_target(
			card,
			player.get("facility_counts", {}) as Dictionary,
			int(player.get("facility_count", 0))
		):
			every_card_blocked = false
			break
	if not every_card_blocked:
		return
	var discard_index := stream.bounded(hand.size())
	(player.get("discard", []) as Array).append(hand[discard_index])
	hand.remove_at(discard_index)
	_draw_to_limit(player, stream, batch_id, accumulator)


func _build_facility(card: Dictionary, player: Dictionary, batch_id: int) -> void:
	var color := str(card.get("color", ""))
	var kind := str(card.get("kind", ""))
	var facilities := player.get("facility_counts", {}) as Dictionary
	var kinds := facilities.get(color, {}) as Dictionary
	kinds[kind] = int(kinds.get(kind, 0)) + 1
	player["facility_count"] = int(player.get("facility_count", 0)) + 1
	if int(player.get("first_facility_batch", 0)) == 0:
		player["first_facility_batch"] = batch_id
	if int(player.get("first_chain_batch", 0)) == 0 and _completed_chain_count(player) > 0:
		player["first_chain_batch"] = batch_id
	if int(player.get("facility_count", 0)) >= FACILITY_SLOT_COUNT \
			and int(player.get("slot_saturation_batch", 0)) == 0:
		player["slot_saturation_batch"] = batch_id


func _finalize_player_metrics(player: Dictionary, accumulator: Dictionary) -> void:
	var censored := SIMULATION_BATCH_COUNT + 1
	var fields := {
		"first_facility_batches": int(player.get("first_facility_batch", 0)),
		"first_chain_batches": int(player.get("first_chain_batch", 0)),
		"first_nonzero_refresh_batches": int(player.get("first_nonzero_asset_refresh_batch", 0)),
		"first_standard_affordable_batches": int(player.get("first_standard_affordable_batch", 0)),
		"first_standard_played_batches": int(player.get("first_standard_played_batch", 0)),
		"facility_slot_saturation_batches": int(player.get("slot_saturation_batch", 0)),
	}
	for key in fields:
		var value := int(fields.get(key, 0))
		if value <= 0:
			value = 0 if key == "first_nonzero_refresh_batches" \
				and int(player.get("initial_assets_per_color", 0)) > 0 else censored
		(accumulator.get(key, []) as Array).append(value)
	var draw_latency := int(player.get("first_purchase_draw_latency", -1))
	var play_latency := int(player.get("first_purchase_play_latency", -1))
	(accumulator.get("purchase_draw_batches", []) as Array).append(
		draw_latency if draw_latency >= 0 else censored
	)
	(accumulator.get("purchase_play_batches", []) as Array).append(
		play_latency if play_latency >= 0 else censored
	)


func _metrics_from_accumulator(accumulator: Dictionary) -> Dictionary:
	return {
		"opening_starter_card_count": _sample_summary(
			accumulator.get("opening_starter_counts", []) as Array
		),
		"opening_asset_affordable_card_count": _sample_summary(
			accumulator.get("opening_affordable_counts", []) as Array
		),
		"opening_legal_target_count": _sample_summary(
			accumulator.get("opening_legal_counts", []) as Array
		),
		"first_facility_batch": _sample_summary(
			accumulator.get("first_facility_batches", []) as Array
		),
		"first_factory_market_chain_batch": _sample_summary(
			accumulator.get("first_chain_batches", []) as Array
		),
		"first_nonzero_asset_refresh_batch": _sample_summary(
			accumulator.get("first_nonzero_refresh_batches", []) as Array
		),
		"first_standard_l1_affordable_batch": _sample_summary(
			accumulator.get("first_standard_affordable_batches", []) as Array
		),
		"first_standard_l1_played_batch": _sample_summary(
			accumulator.get("first_standard_played_batches", []) as Array
		),
		"starter_action_share_batch_1": _starter_share_for_batch(accumulator, 1),
		"starter_action_share_batch_3": _starter_share_for_batch(accumulator, 3),
		"starter_action_share_batch_6": _starter_share_for_batch(accumulator, 6),
		"starter_action_share_batch_10": _starter_share_for_batch(accumulator, 10),
		"standard_card_action_share": _safe_ratio(
			int(accumulator.get("standard_action_count", 0)),
			int(accumulator.get("total_action_count", 0))
		),
		"asset_spend_per_batch": _safe_ratio(
			int(accumulator.get("asset_spend_points", 0)),
			int(accumulator.get("player_batch_count", 0))
		),
		"asset_overflow_rate": _safe_ratio(
			int(accumulator.get("asset_overflow_points", 0)),
			int(accumulator.get("asset_refresh_candidate_points", 0))
		),
		"zero_asset_block_rate_standard_cards_only": _safe_ratio(
			int(accumulator.get("standard_zero_asset_block_count", 0)),
			int(accumulator.get("standard_card_consideration_count", 0))
		),
		"normal_purchase_to_first_draw_batches": _sample_summary(
			accumulator.get("purchase_draw_batches", []) as Array
		),
		"normal_purchase_to_first_play_batches": _sample_summary(
			accumulator.get("purchase_play_batches", []) as Array
		),
		"starter_standard_merge_rate": _safe_ratio(
			int(accumulator.get("starter_standard_merge_accept_count", 0)),
			int(accumulator.get("starter_standard_merge_offer_count", 0))
		),
		"starter_privilege_consumed_rate": _safe_ratio(
			int(accumulator.get("starter_privilege_consumed_count", 0)),
			int(accumulator.get("genesis_starter_instance_count", 0))
		),
		"facility_slot_saturation_batch": _sample_summary(
			accumulator.get("facility_slot_saturation_batches", []) as Array
		),
		"free_starter_repeat_build_rate": _safe_ratio(
			int(accumulator.get("starter_repeat_build_count", 0)),
			int(accumulator.get("starter_action_count", 0))
		),
		"victory_pending_tail_seconds": _sample_summary(
			accumulator.get("victory_tail_seconds", []) as Array
		),
		"resolution_p95_seconds": _percentile(
			accumulator.get("resolution_seconds", []) as Array,
			0.95
		),
		"predicted_resolution_animation_seconds": _sample_summary(
			accumulator.get("resolution_seconds", []) as Array
		),
		"sunlit_chain_throughput_ratio": _mean(
			accumulator.get("solar_ratios", []) as Array
		),
		"solar_multiplier_application_count_per_channel": 1,
		"starter_track_spawn_count": 0,
		"starter_creation_after_genesis_count": 0,
		"starter_privilege_inheritance_count": 0,
	}


static func _profile(
	profile_id: String,
	profile_status: String,
	initial_assets: int,
	starter_enabled: bool,
	cross_merge_allowed: bool,
	fingerprint_input: String,
	fingerprint_value: String
) -> Dictionary:
	return {
		"profile_id": profile_id,
		"profile_status": profile_status,
		"profile_fingerprint_input": fingerprint_input,
		"profile_fingerprint": fingerprint_value,
		"initial_assets_per_color": initial_assets,
		"starter_bootstrap_enabled": starter_enabled,
		"starter_primary_asset_cost": 0 if starter_enabled else 1,
		"standard_l1_primary_asset_cost": 1,
		"starter_standard_l1_merge_allowed": cross_merge_allowed,
		"normal_card_ratio_basis_points": 6000,
		"commodity_card_ratio_basis_points": 4000,
		"single_color_net_intervention_cap_enabled": true,
		"single_color_net_intervention_cap_basis_points": 1200,
		"max_asset_refresh_per_color_per_batch": 3,
		"hand_maintenance_timeout_seconds": 8,
		"lead_tenure_batches": 1,
		"color_cycle_batches": 6,
		"track_scroll_interval_seconds": 5,
		"track_local_visible_slot_count": 5,
		"human_fun_proven": false,
		"human_test_required": true,
	}


static func _standard_l1_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for color in COLORS:
		for kind in ["factory", "market"]:
			definitions.append(standard_definition(color, kind, 1))
	return definitions


func _purchase_color(player: Dictionary, stream: DeterministicStream) -> String:
	var assets := player.get("assets", {}) as Dictionary
	var affordable_colors: Array[String] = []
	for color in COLORS:
		if int(assets.get(color, 0)) > 0:
			affordable_colors.append(color)
	if not affordable_colors.is_empty() and stream.chance_basis_points(8500):
		return affordable_colors[stream.bounded(affordable_colors.size())]
	var facility_colors: Array[String] = []
	var facilities := player.get("facility_counts", {}) as Dictionary
	for color in COLORS:
		var kinds := facilities.get(color, {}) as Dictionary
		if int(kinds.get("factory", 0)) + int(kinds.get("market", 0)) > 0:
			facility_colors.append(color)
	if not facility_colors.is_empty() and stream.chance_basis_points(9000):
		return facility_colors[stream.bounded(facility_colors.size())]
	var hand_colors: Array[String] = []
	for card_variant in player.get("hand", []) as Array:
		var color := str((card_variant as Dictionary).get("color", ""))
		if color in COLORS and not hand_colors.has(color):
			hand_colors.append(color)
	if not hand_colors.is_empty() and stream.chance_basis_points(8500):
		return hand_colors[stream.bounded(hand_colors.size())]
	return COLORS[stream.bounded(COLORS.size())]


static func _standard_deficit_colors(
	player: Dictionary,
	eligible_colors: Array[String]
) -> Array[String]:
	var result: Array[String] = []
	var assets := player.get("assets", {}) as Dictionary
	for zone_id in ["hand", "draw_pile", "discard", "committed_escrow"]:
		for card_variant in player.get(zone_id, []) as Array:
			var card := card_variant as Dictionary
			if str(card.get("origin_class", "")) != "standard":
				continue
			var color := str(card.get("color", ""))
			if color in eligible_colors \
					and int(assets.get(color, 0)) < asset_cost_for_card(card) \
					and not result.has(color):
				result.append(color)
	return result


static func _card_priority(card: Dictionary, player: Dictionary) -> int:
	var affordable := _card_is_affordable(card, player)
	if str(card.get("origin_class", "")) == "standard" and affordable:
		return 0
	var color := str(card.get("color", ""))
	var kind := str(card.get("kind", ""))
	var opposite := "market" if kind == "factory" else "factory"
	var kinds := (
		player.get("facility_counts", {}) as Dictionary
	).get(color, {}) as Dictionary
	if bool(int(kinds.get(opposite, 0)) > 0) and int(kinds.get(kind, 0)) == 0:
		return 1
	if int(kinds.get(kind, 0)) == 0:
		return 2
	return 3 if str(card.get("origin_class", "")) == "starter_bootstrap" else 4


static func _card_is_affordable(card: Dictionary, player: Dictionary) -> bool:
	var cost := asset_cost_for_card(card)
	return cost >= 0 and int((player.get("assets", {}) as Dictionary).get(
		str(card.get("color", "")),
		0
	)) >= cost


static func _card_has_legal_target(
	card: Dictionary,
	facility_counts: Dictionary,
	total_facility_count: int
) -> bool:
	if total_facility_count >= FACILITY_SLOT_COUNT:
		return false
	var kinds := facility_counts.get(str(card.get("color", "")), {}) as Dictionary
	return int(kinds.get(str(card.get("kind", "")), 0)) < 6


static func _same_facility_already_built(card: Dictionary, facilities: Dictionary) -> bool:
	var kinds := facilities.get(str(card.get("color", "")), {}) as Dictionary
	return int(kinds.get(str(card.get("kind", "")), 0)) > 0


static func _first_starter_standard_pair(hand: Array) -> Dictionary:
	for left_index in range(hand.size()):
		var left := hand[left_index] as Dictionary
		for right_index in range(left_index + 1, hand.size()):
			var right := hand[right_index] as Dictionary
			if str(left.get("merge_family_id", "")) != str(right.get("merge_family_id", "")):
				continue
			var origins := [
				str(left.get("origin_class", "")),
				str(right.get("origin_class", "")),
			]
			if origins.has("starter_bootstrap") and origins.has("standard") \
					and int(left.get("level", 0)) == 1 \
					and int(right.get("level", 0)) == 1:
				return {"left_index": left_index, "right_index": right_index}
	return {}


static func _normal_card_total(player: Dictionary) -> int:
	return (player.get("draw_pile", []) as Array).size() \
		+ (player.get("hand", []) as Array).size() \
		+ (player.get("committed_escrow", []) as Array).size() \
		+ (player.get("discard", []) as Array).size()


static func _completed_chain_count(player: Dictionary) -> int:
	var result := 0
	var facilities := player.get("facility_counts", {}) as Dictionary
	for color in COLORS:
		var kinds := facilities.get(color, {}) as Dictionary
		if int(kinds.get("factory", 0)) > 0 and int(kinds.get("market", 0)) > 0:
			result += 1
	return result


static func _player_has_initial_assets(player: Dictionary) -> bool:
	var assets := player.get("assets", {}) as Dictionary
	for color in COLORS:
		if int(assets.get(color, 0)) > 0:
			return true
	return false


static func _player_summaries(players: Array[Dictionary]) -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for player in players:
		summaries.append({
			"player_id": str(player.get("player_id", "")),
			"first_facility_batch": int(player.get("first_facility_batch", 0)),
			"first_chain_batch": int(player.get("first_chain_batch", 0)),
			"first_nonzero_asset_refresh_batch": int(
				player.get("first_nonzero_asset_refresh_batch", 0)
			),
			"first_standard_played_batch": int(player.get("first_standard_played_batch", 0)),
			"facility_count": int(player.get("facility_count", 0)),
			"normal_card_total": _normal_card_total(player),
		})
	return summaries


static func _zero_color_dictionary() -> Dictionary:
	var result: Dictionary = {}
	for color in COLORS:
		result[color] = 0
	return result


static func _starter_share_for_batch(accumulator: Dictionary, batch_id: int) -> float:
	var rows := accumulator.get("action_counts_by_batch", {}) as Dictionary
	var row := rows.get(batch_id, {}) as Dictionary
	var starter := int(row.get("starter", 0))
	var standard := int(row.get("standard", 0))
	return _safe_ratio(starter, starter + standard)


static func _failed_targets(profile: Dictionary, metrics: Dictionary) -> Array[String]:
	var failed: Array[String] = []
	if bool(profile.get("starter_bootstrap_enabled", false)):
		var opening_affordable := metrics.get("opening_asset_affordable_card_count", {}) as Dictionary
		if float(opening_affordable.get("minimum", 0.0)) != 5.0 \
				or float(opening_affordable.get("maximum", 0.0)) != 5.0:
			failed.append("OPENING_ASSET_AFFORDABLE_CARD_COUNT")
		var first_facility := metrics.get("first_facility_batch", {}) as Dictionary
		if float(first_facility.get("median", 999.0)) > 1.0:
			failed.append("FIRST_FACILITY_MEDIAN_BATCH")
		if float(first_facility.get("p95", 999.0)) > 2.0:
			failed.append("FIRST_FACILITY_P95_BATCH")
		var first_refresh := metrics.get("first_nonzero_asset_refresh_batch", {}) as Dictionary
		if float(first_refresh.get("median", 999.0)) > 2.0:
			failed.append("FIRST_NONZERO_ASSET_REFRESH_MEDIAN_BATCH")
		if float(first_refresh.get("p95", 999.0)) > 3.0:
			failed.append("FIRST_NONZERO_ASSET_REFRESH_P95_BATCH")
		var standard_play := metrics.get("first_standard_l1_played_batch", {}) as Dictionary
		if float(standard_play.get("median", 999.0)) > 4.0:
			failed.append("FIRST_STANDARD_L1_PLAY_MEDIAN_BATCH")
			failed.append("STANDARD_CARD_ASSET_ECONOMY_TOO_SLOW")
		if float(metrics.get("zero_asset_block_rate_standard_cards_only", 1.0)) >= 0.15:
			failed.append("STANDARD_CARD_ZERO_ASSET_BLOCK_RATE")
			if not failed.has("STANDARD_CARD_ASSET_ECONOMY_TOO_SLOW"):
				failed.append("STANDARD_CARD_ASSET_ECONOMY_TOO_SLOW")
		if float(metrics.get("starter_action_share_batch_10", 1.0)) >= 0.70:
			failed.append("STARTER_ACTION_SHARE_BATCH_10")
			failed.append("STARTER_DECK_DOMINATES_LONG_TERM_PLAY")
	if float(metrics.get("asset_overflow_rate", 1.0)) >= 0.20:
		failed.append("ASSET_OVERFLOW_RATE")
	var tail := metrics.get("victory_pending_tail_seconds", {}) as Dictionary
	if float(tail.get("p95", 999.0)) > 240.0:
		failed.append("VICTORY_PENDING_TAIL_P95_SECONDS")
	var solar_ratio := float(metrics.get("sunlit_chain_throughput_ratio", 0.0))
	if solar_ratio < 1.8 or solar_ratio > 2.2:
		failed.append("SUNLIT_CHAIN_THROUGHPUT_RATIO")
	failed.sort()
	return _unique_strings(failed)


static func _profile_is_valid(profile: Dictionary) -> bool:
	var input := str(profile.get("profile_fingerprint_input", ""))
	return not str(profile.get("profile_id", "")).is_empty() \
		and input.sha256_text() == str(profile.get("profile_fingerprint", "")) \
		and int(profile.get("initial_assets_per_color", -1)) >= 0 \
		and int(profile.get("normal_card_ratio_basis_points", 0)) \
			+ int(profile.get("commodity_card_ratio_basis_points", 0)) == 10000


static func _profile_result_by_id(rows: Array[Dictionary], profile_id: String) -> Dictionary:
	for row in rows:
		if str(row.get("profile_id", "")) == profile_id:
			return row
	return {}


static func _public_result(result: Dictionary) -> Dictionary:
	var public := result.duplicate(true)
	public.erase("_accumulator")
	return public


static func _new_accumulator() -> Dictionary:
	return {
		"opening_starter_counts": [],
		"opening_affordable_counts": [],
		"opening_legal_counts": [],
		"first_facility_batches": [],
		"first_chain_batches": [],
		"first_nonzero_refresh_batches": [],
		"first_standard_affordable_batches": [],
		"first_standard_played_batches": [],
		"purchase_draw_batches": [],
		"purchase_play_batches": [],
		"facility_slot_saturation_batches": [],
		"victory_tail_seconds": [],
		"resolution_seconds": [],
		"solar_ratios": [],
		"action_counts_by_batch": {},
		"genesis_starter_instance_count": 0,
		"normal_purchase_count": 0,
		"total_action_count": 0,
		"starter_action_count": 0,
		"standard_action_count": 0,
		"starter_repeat_build_count": 0,
		"standard_card_consideration_count": 0,
		"standard_zero_asset_block_count": 0,
		"asset_spend_points": 0,
		"player_batch_count": 0,
		"asset_refresh_candidate_points": 0,
		"asset_overflow_points": 0,
		"starter_standard_merge_offer_count": 0,
		"starter_standard_merge_accept_count": 0,
		"starter_privilege_consumed_count": 0,
	}


static func _combine_accumulators(target: Dictionary, source: Dictionary) -> void:
	for key in target:
		if target.get(key) is Array:
			(target.get(key) as Array).append_array(
				(source.get(key, []) as Array).duplicate()
			)
		elif key == "action_counts_by_batch":
			var target_rows := target.get(key, {}) as Dictionary
			var source_rows := source.get(key, {}) as Dictionary
			for batch_id in source_rows:
				var target_row := target_rows.get(batch_id, {"starter": 0, "standard": 0}) as Dictionary
				var source_row := source_rows.get(batch_id, {}) as Dictionary
				target_row["starter"] = int(target_row.get("starter", 0)) + int(source_row.get("starter", 0))
				target_row["standard"] = int(target_row.get("standard", 0)) + int(source_row.get("standard", 0))
				target_rows[batch_id] = target_row
		else:
			target[key] = int(target.get(key, 0)) + int(source.get(key, 0))


static func _predicted_resolution_seconds(action_count: int, major_action_count: int) -> float:
	var common_count := maxi(0, action_count - major_action_count)
	var seconds := 0.0
	if action_count <= 12:
		seconds = action_count * 0.6
	elif action_count <= 24:
		seconds = 1.0 + major_action_count * 0.6 + common_count * 0.28
	else:
		seconds = 2.0 + major_action_count * 0.6 + common_count * 0.10
	return _round_ratio(seconds)


static func _solar_chain_throughput(multiplier: int) -> Dictionary:
	var throughput := 2147483647
	var counts: Dictionary = {}
	for channel in SOLAR_CHANNEL_BASE_RATES:
		throughput = mini(throughput, int(SOLAR_CHANNEL_BASE_RATES.get(channel, 0)) * multiplier)
		counts[channel] = 1
	return {
		"throughput": throughput,
		"application_count_by_channel": counts,
		"maximum_application_count_per_channel": 1,
	}


static func _derive_seed(seed: int, stream_id: String) -> int:
	var prefix := ("%d|%s" % [seed, stream_id]).sha256_text().left(8)
	return posmod(prefix.hex_to_int(), DeterministicStream.MODULUS - 1) + 1


static func _shuffle_in_place(values: Array, stream: DeterministicStream) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := stream.bounded(index + 1)
		var temporary: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary


static func _sample_summary(values: Array) -> Dictionary:
	return {
		"sample_count": values.size(),
		"mean": _mean(values),
		"median": _percentile(values, 0.50),
		"p95": _percentile(values, 0.95),
		"minimum": _minimum(values),
		"maximum": _maximum(values),
	}


static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return _round_ratio(total / values.size())


static func _percentile(values: Array, ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(ceili(ratio * sorted.size()) - 1, 0, sorted.size() - 1)
	return _round_ratio(float(sorted[index]))


static func _minimum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var result := float(values[0])
	for value in values:
		result = minf(result, float(value))
	return _round_ratio(result)


static func _maximum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var result := float(values[0])
	for value in values:
		result = maxf(result, float(value))
	return _round_ratio(result)


static func _safe_ratio(numerator: int, denominator: int) -> float:
	return _round_ratio(float(numerator) / float(denominator)) if denominator > 0 else 0.0


static func _round_ratio(value: float) -> float:
	return round(value * 1000000.0) / 1000000.0


static func _unique_strings(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if not result.has(value):
			result.append(value)
	return result


static func _invalid_report(reason_code: String) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"simulation_id": SIMULATION_ID,
		"valid": false,
		"reason_code": reason_code,
		"human_fun_proven": false,
		"human_test_required": true,
	}


static func fingerprint(value: Variant) -> String:
	return _canonical(value).sha256_text()


static func _canonical(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_INT:
			return str(int(value))
		TYPE_FLOAT:
			return String.num(float(value), 17)
		TYPE_STRING, TYPE_STRING_NAME:
			return JSON.stringify(str(value))
		TYPE_ARRAY:
			var rows: Array[String] = []
			for item in value as Array:
				rows.append(_canonical(item))
			return "[%s]" % ",".join(rows)
		TYPE_DICTIONARY:
			var keys: Array = (value as Dictionary).keys()
			keys.sort_custom(func(left: Variant, right: Variant) -> bool:
				return str(left) < str(right)
			)
			var pairs: Array[String] = []
			for key in keys:
				pairs.append("%s:%s" % [
					JSON.stringify(str(key)),
					_canonical((value as Dictionary).get(key)),
				])
			return "{%s}" % ",".join(pairs)
	return JSON.stringify(str(value))
