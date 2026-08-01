extends RefCounted
class_name V071DeterministicSimulator

const SCHEMA_VERSION := 1
const SIMULATION_ID := "v071.detached.rule_fun_preflight.v1"
const SIMULATION_AGENT_POLICY_ID := "v071.closed_heuristic_policy.v1"
const RULE_CLOSURE_PROFILE_ID := "v071.candidate_errata_closure.v1"

const PLAYER_COUNTS := [3, 4, 6, 8]
const DEFAULT_SEED_COUNT := 500
const FIXED_SEED_BASE := 900626424
const SIMULATION_BATCH_COUNT := 18
const BATCH_SECONDS := 30
const TRACK_OPPORTUNITIES_PER_BATCH := 3
const HAND_LIMIT := 5
const NORMAL_DECK_MINIMUM_TOTAL_CARD_COUNT := 5
const ASSET_CAP := 6
const PROFILE_FINGERPRINT_FIELD_ORDER := [
	"initial_assets_per_color",
	"normal_card_ratio_basis_points",
	"commodity_card_ratio_basis_points",
	"single_color_net_intervention_cap_enabled",
	"single_color_net_intervention_cap_basis_points",
	"max_asset_refresh_per_color_per_batch",
	"hand_maintenance_timeout_seconds",
	"lead_tenure_batches",
	"color_cycle_batches",
]
const SOLAR_CHANNEL_BASE_RATES := {
	"factory_production_rate": 12,
	"transport_throughput": 10,
	"warehouse_ingress_throughput": 11,
	"warehouse_egress_throughput": 11,
	"market_demand_or_consumption_rate": 9,
}

const COLORS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]

const PROFILE_BASELINE := "BASELINE_V07"
const PROFILE_FAST := "V071_CANDIDATE_A_FAST"
const PROFILE_STRATEGIC := "V071_CANDIDATE_B_STRATEGIC"

const REQUIRED_METRIC_KEYS := [
	"opening_hand_factory_count",
	"opening_hand_market_count",
	"opening_hand_matching_pair_count",
	"first_viable_factory_market_chain_batch",
	"average_active_actions_per_player_per_batch",
	"p95_active_actions_per_player_per_batch",
	"normal_purchase_to_first_draw_batches",
	"commodity_l2_first_time_seconds",
	"commodity_l3_first_time_seconds",
	"lead_track_acquisition_advantage_ratio",
	"color_share_min",
	"color_share_max",
	"color_cap_hit_rate",
	"single_color_asset_overflow_rate",
	"zero_asset_blocked_action_rate",
	"invalid_target_fizzle_rate",
	"maintenance_timeout_rate",
	"optional_merge_accept_rate",
	"predicted_resolution_animation_seconds",
	"victory_pending_tail_batches",
	"victory_pending_tail_seconds",
	"lead_inference_unique_rate",
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
	var rows: Array[Dictionary] = [
		{
			"profile_id": PROFILE_BASELINE,
			"profile_status": "existing_v07_balance_defaults_with_candidate_closure",
			"max_asset_refresh_unbounded": true,
			"initial_assets_per_color": 1,
			"normal_card_ratio_basis_points": 7000,
			"commodity_card_ratio_basis_points": 3000,
			"single_color_net_intervention_cap_enabled": false,
			"single_color_net_intervention_cap_basis_points": 10000,
			"max_asset_refresh_per_color_per_batch": 6,
			"hand_maintenance_timeout_seconds": 20,
			"lead_tenure_batches": 2,
			"color_cycle_batches": 6,
			"source_lead_tenure_seconds": 60,
			"source_color_cycle_seconds": 180,
		},
		{
			"profile_id": PROFILE_FAST,
			"profile_status": "candidate_balance_experiment",
			"max_asset_refresh_unbounded": false,
			"initial_assets_per_color": 2,
			"normal_card_ratio_basis_points": 6000,
			"commodity_card_ratio_basis_points": 4000,
			"single_color_net_intervention_cap_enabled": true,
			"single_color_net_intervention_cap_basis_points": 1200,
			"max_asset_refresh_per_color_per_batch": 3,
			"hand_maintenance_timeout_seconds": 8,
			"lead_tenure_batches": 1,
			"color_cycle_batches": 6,
			"source_lead_tenure_seconds": 0,
			"source_color_cycle_seconds": 0,
		},
		{
			"profile_id": PROFILE_STRATEGIC,
			"profile_status": "candidate_balance_experiment",
			"max_asset_refresh_unbounded": false,
			"initial_assets_per_color": 2,
			"normal_card_ratio_basis_points": 6000,
			"commodity_card_ratio_basis_points": 4000,
			"single_color_net_intervention_cap_enabled": true,
			"single_color_net_intervention_cap_basis_points": 1200,
			"max_asset_refresh_per_color_per_batch": 3,
			"hand_maintenance_timeout_seconds": 8,
			"lead_tenure_batches": 2,
			"color_cycle_batches": 6,
			"source_lead_tenure_seconds": 0,
			"source_color_cycle_seconds": 0,
		},
	]
	for row in rows:
		row.merge(_candidate_closure_fields())
		row["profile_fingerprint_input"] = _profile_fingerprint_input(row)
		row["profile_fingerprint"] = str(
			row.get("profile_fingerprint_input", "")
		).sha256_text().to_lower()
	return rows


static func profile_by_id(profile_id: String) -> Dictionary:
	for profile in profiles():
		if str(profile.get("profile_id", "")) == profile_id:
			return profile.duplicate(true)
	return {}


static func candidate_closure_contract() -> Dictionary:
	var result := _candidate_closure_fields()
	result.merge({
		"schema_version": SCHEMA_VERSION,
		"contract_id": RULE_CLOSURE_PROFILE_ID,
		"detached_reference_only": true,
		"production_runtime_connected": false,
		"human_fun_proven": false,
		"authoritative_receipts_skipped_by_presentation": false,
		"solar_multiplier_application_count_per_channel": 1,
	})
	result["contract_fingerprint"] = fingerprint(result)
	return result


static func normal_merge_admission(total_card_count: int) -> Dictionary:
	var resulting_total := total_card_count - 1
	var accepted := total_card_count >= 2 \
		and resulting_total >= NORMAL_DECK_MINIMUM_TOTAL_CARD_COUNT
	return {
		"accepted": accepted,
		"reason_code": "normal_cards_merged" if accepted \
			else "minimum_normal_deck_size_violation",
		"source_total_card_count": total_card_count,
		"result_total_card_count": resulting_total,
		"minimum_total_card_count": NORMAL_DECK_MINIMUM_TOTAL_CARD_COUNT,
	}


static func normal_merge_admission_for_zones(zones: Dictionary) -> Dictionary:
	var required_zones := ["draw_pile", "hand", "committed_escrow", "discard"]
	var total := 0
	for zone in required_zones:
		if not zones.has(zone) or not (zones.get(zone) is Array):
			return {
				"accepted": false,
				"reason_code": "normal_deck_zone_state_invalid",
				"counted_zones": required_zones,
			}
		total += (zones.get(zone) as Array).size()
	var result := normal_merge_admission(total)
	result["counted_zones"] = required_zones
	return result


static func track_replacement_state(current_scroll_sequence: int) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"instance_id": "replacement.scroll.%d" % current_scroll_sequence,
		"replacement_created_at_scroll_sequence": current_scroll_sequence,
		"claimable_from_scroll_sequence": current_scroll_sequence + 1,
		"claimable_same_tick": false,
		"incoming_locked": true,
		"claimed": false,
		"claimed_request_id": "",
		"processed_requests": {},
		"exact_once_owner": "detached_track_revision_gate",
	}


static func claim_track_replacement(
	state: Dictionary,
	current_scroll_sequence: int,
	request_id: String,
	input_source: String
) -> Dictionary:
	var source := state.duplicate(true)
	if not _replacement_state_valid(source) or request_id.is_empty() \
			or input_source not in ["mouse", "keyboard", "touch", "concurrent"]:
		return {"accepted": false, "reason_code": "replacement_claim_invalid", "state": source}
	var processed := source.get("processed_requests", {}) as Dictionary
	if processed.has(request_id):
		var replayed := (
			processed.get(request_id, {}) as Dictionary
		).duplicate(true)
		replayed["state"] = source
		return replayed
	var accepted := false
	var reason_code := "replacement_not_yet_claimable"
	if bool(source.get("claimed", false)):
		reason_code = "replacement_already_claimed"
	elif current_scroll_sequence >= int(
		source.get("claimable_from_scroll_sequence", 0)
	):
		accepted = true
		reason_code = "replacement_claimed"
		source["claimed"] = true
		source["incoming_locked"] = false
		source["claimed_request_id"] = request_id
	var receipt := {
		"accepted": accepted,
		"reason_code": reason_code,
		"request_id": request_id,
		"input_source": input_source,
		"scroll_sequence": current_scroll_sequence,
		"instance_id": str(source.get("instance_id", "")),
	}
	receipt["receipt_fingerprint"] = fingerprint(receipt)
	processed = source.get("processed_requests", {}) as Dictionary
	processed[request_id] = receipt.duplicate(true)
	source["processed_requests"] = processed
	receipt["state"] = source
	return receipt


static func commodity_available_from_batch(batch_id: int, queue_locked: bool) -> int:
	return batch_id + (1 if queue_locked else 0)


static func solar_chain_probe() -> Dictionary:
	var dark := _solar_chain_throughput(1)
	var sunlit := _solar_chain_throughput(2)
	var dark_throughput := int(dark.get("throughput", 0))
	var sunlit_throughput := int(sunlit.get("throughput", 0))
	return {
		"dark_throughput": dark_throughput,
		"sunlit_throughput": sunlit_throughput,
		"throughput_ratio": _round_ratio(
			float(sunlit_throughput) / float(dark_throughput)
			if dark_throughput > 0 else 0.0
		),
		"dark_channel_rates": dark.get("channel_rates", {}).duplicate(true),
		"sunlit_channel_rates": sunlit.get("channel_rates", {}).duplicate(true),
		"application_count_by_channel": sunlit.get(
			"application_count_by_channel", {}
		).duplicate(true),
		"maximum_application_count_per_channel": int(
			sunlit.get("maximum_application_count_per_channel", 0)
		),
	}


func run_matrix(seed_count: int = DEFAULT_SEED_COUNT) -> Dictionary:
	if seed_count <= 0:
		return _invalid_report("seed_count_invalid")
	var configuration_results: Array[Dictionary] = []
	var profile_results: Array[Dictionary] = []
	var profile_rows := profiles()
	for profile in profile_rows:
		var combined := _new_accumulator()
		var by_player_count: Dictionary = {}
		for player_count in PLAYER_COUNTS:
			var result := run_configuration(profile, player_count, seed_count)
			configuration_results.append(result)
			by_player_count[str(player_count)] = result.duplicate(true)
			_combine_accumulators(combined, result.get("_accumulator", {}) as Dictionary)
		var metrics := _metrics_from_accumulator(combined)
		var failed_targets := _profile_failed_targets(metrics, by_player_count)
		var public_by_count: Dictionary = {}
		for key in by_player_count:
			var public_result := (by_player_count.get(key, {}) as Dictionary).duplicate(true)
			public_result.erase("_accumulator")
			public_by_count[key] = public_result
		var profile_result := {
			"profile_id": str(profile.get("profile_id", "")),
			"profile_fingerprint": str(profile.get("profile_fingerprint", "")),
			"configuration_count": PLAYER_COUNTS.size(),
			"match_count": seed_count * PLAYER_COUNTS.size(),
			"player_counts": PLAYER_COUNTS.duplicate(),
			"seed_count_per_configuration": seed_count,
			"metrics": metrics,
			"failed_fun_targets": failed_targets,
			"failed_fun_target_count": failed_targets.size(),
			"by_player_count": public_by_count,
		}
		profile_result["profile_result_fingerprint"] = fingerprint(profile_result)
		profile_results.append(profile_result)
	var recommended := _select_recommended_profile(profile_results, profile_rows)
	var public_configurations: Array[Dictionary] = []
	for result in configuration_results:
		var public_result := result.duplicate(true)
		public_result.erase("_accumulator")
		public_configurations.append(public_result)
	var report := {
		"schema_version": SCHEMA_VERSION,
		"simulation_id": SIMULATION_ID,
		"simulation_agent_policy_id": SIMULATION_AGENT_POLICY_ID,
		"rule_closure_profile_id": RULE_CLOSURE_PROFILE_ID,
		"detached_reference_only": true,
		"production_runtime_connected": false,
		"production_save_used": false,
		"production_rng_used": false,
		"human_fun_proven": false,
		"human_test_still_required": true,
		"profile_count": profile_rows.size(),
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
		"profiles": profile_rows,
		"configuration_results": public_configurations,
		"profile_results": profile_results,
		"recommended_profile": recommended,
		"recommended_profile_id": str(recommended.get("profile_id", "")),
		"failed_fun_targets": recommended.get("failed_fun_targets", []).duplicate(),
		"required_metric_keys": REQUIRED_METRIC_KEYS.duplicate(),
	}
	report["report_fingerprint"] = fingerprint(report)
	return report


func run_configuration(
	profile: Dictionary,
	player_count: int,
	seed_count: int = DEFAULT_SEED_COUNT
) -> Dictionary:
	if not _profile_is_valid(profile) or player_count not in PLAYER_COUNTS \
			or seed_count <= 0:
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
	var failed_targets := _configuration_failed_targets(metrics, player_count)
	var result := {
		"valid": true,
		"reason_code": "simulation_configuration_completed",
		"profile_id": str(profile.get("profile_id", "")),
		"profile_fingerprint": str(profile.get("profile_fingerprint", "")),
		"player_count": player_count,
		"seed_count": seed_count,
		"match_count": seed_count,
		"metrics": metrics,
		"failed_fun_targets": failed_targets,
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
	var color_stream := DeterministicStream.new(_derive_seed(seed, "color_cycle"))
	var players: Array[Dictionary] = []
	var player_streams: Array[DeterministicStream] = []
	for player_index in range(player_count):
		var player_id := "player.%02d" % (player_index + 1)
		var stream := DeterministicStream.new(
			_derive_seed(seed, "player.%d" % player_index)
		)
		player_streams.append(stream)
		players.append(_new_player_state(player_id, profile, stream, accumulator))
	var hidden_order: Array[int] = []
	for index in range(player_count):
		hidden_order.append(index)
	_shuffle_in_place(hidden_order, shared_stream)

	var batch_action_counts: Array[int] = []
	var match_color_cycles := 0
	for batch_id in range(1, SIMULATION_BATCH_COUNT + 1):
		var lead_index := _lead_index_for_batch(
			hidden_order,
			batch_id,
			int(profile.get("lead_tenure_batches", 1))
		)
		var total_actions := 0
		var major_actions := 0
		for player_index in range(player_count):
			var player := players[player_index]
			var stream := player_streams[player_index]
			_activate_pending_commodities(player, batch_id)
			player["cash"] = int(player.get("cash", 0)) \
				+ _completed_chain_count(player) * 2
			_process_track_opportunities(
				player,
				stream,
				profile,
				batch_id,
				player_index == lead_index,
				player_count,
				accumulator
			)
			_merge_available_commodities(player, batch_id)
			var action_result := _play_player_batch(
				player,
				stream,
				profile,
				batch_id,
				player_count,
				accumulator
			)
			var active_actions := int(action_result.get("active_actions", 0))
			total_actions += active_actions
			major_actions += int(action_result.get("major_actions", 0))
			(accumulator.get("active_actions", []) as Array).append(active_actions)
			_refresh_assets(player, stream, profile, accumulator)
		batch_action_counts.append(total_actions)
		(accumulator.get("resolution_seconds", []) as Array).append(
			_predicted_resolution_seconds(total_actions, major_actions)
		)
		if batch_id % int(profile.get("color_cycle_batches", 6)) == 0:
			match_color_cycles += 1
			_simulate_color_cycle(
				profile,
				players,
				lead_index,
				color_stream,
				accumulator
			)

	var qualification_batch := 4 + shared_stream.bounded(10)
	var macro_round_batches := player_count * int(
		profile.get("lead_tenure_batches", 1)
	)
	var tail_batches := posmod(
		macro_round_batches - (qualification_batch % macro_round_batches),
		macro_round_batches
	)
	(accumulator.get("victory_tail_batches", []) as Array).append(tail_batches)
	(accumulator.get("victory_tail_seconds", []) as Array).append(
		tail_batches * BATCH_SECONDS
	)
	var solar_probe := solar_chain_probe()
	(accumulator.get("solar_throughput_ratios", []) as Array).append(
		float(solar_probe.get("throughput_ratio", 0.0))
	)
	accumulator["solar_channel_application_count"] = maxi(
		int(accumulator.get("solar_channel_application_count", 0)),
		int(solar_probe.get("maximum_application_count_per_channel", 0))
	)

	var player_summaries: Array[Dictionary] = []
	for player in players:
		var first_chain := int(player.get("first_chain_batch", 0))
		if first_chain <= 0:
			first_chain = SIMULATION_BATCH_COUNT + 1
			accumulator["first_chain_censored_count"] = int(
				accumulator.get("first_chain_censored_count", 0)
			) + 1
		(accumulator.get("first_chain_batches", []) as Array).append(first_chain)
		var purchase_latency := int(player.get("first_purchase_draw_latency", -1))
		if purchase_latency < 0:
			purchase_latency = SIMULATION_BATCH_COUNT + 1
			accumulator["normal_draw_censored_count"] = int(
				accumulator.get("normal_draw_censored_count", 0)
			) + 1
		(accumulator.get("normal_purchase_draw_batches", []) as Array).append(
			purchase_latency
		)
		var l2_time := int(player.get("commodity_l2_first_time_seconds", 0))
		if l2_time <= 0:
			l2_time = (SIMULATION_BATCH_COUNT + 1) * BATCH_SECONDS
			accumulator["commodity_l2_censored_count"] = int(
				accumulator.get("commodity_l2_censored_count", 0)
			) + 1
		var l3_time := int(player.get("commodity_l3_first_time_seconds", 0))
		if l3_time <= 0:
			l3_time = (SIMULATION_BATCH_COUNT + 1) * BATCH_SECONDS
			accumulator["commodity_l3_censored_count"] = int(
				accumulator.get("commodity_l3_censored_count", 0)
			) + 1
		(accumulator.get("commodity_l2_seconds", []) as Array).append(l2_time)
		(accumulator.get("commodity_l3_seconds", []) as Array).append(l3_time)
		player_summaries.append({
			"player_id": str(player.get("player_id", "")),
			"first_chain_batch": first_chain,
			"normal_purchase_draw_batches": purchase_latency,
			"commodity_l2_seconds": l2_time,
			"commodity_l3_seconds": l3_time,
			"normal_card_total": _normal_card_total(player),
			"cash": int(player.get("cash", 0)),
		})
	var match_summary := {
		"seed": seed,
		"profile_id": str(profile.get("profile_id", "")),
		"profile_fingerprint": str(profile.get("profile_fingerprint", "")),
		"player_count": player_count,
		"batch_action_counts": batch_action_counts,
		"color_cycle_count": match_color_cycles,
		"victory_pending_tail_batches": tail_batches,
		"players": player_summaries,
		"shared_rng_draw_count": shared_stream.draw_count,
		"color_rng_draw_count": color_stream.draw_count,
	}
	return fingerprint(match_summary)


func _new_player_state(
	player_id: String,
	profile: Dictionary,
	stream: DeterministicStream,
	accumulator: Dictionary
) -> Dictionary:
	var deck := _starter_cards(player_id)
	_shuffle_in_place(deck, stream)
	var hand: Array = []
	while hand.size() < HAND_LIMIT:
		hand.append(deck.pop_back())
	var factory_count := 0
	var market_count := 0
	var kinds_by_color: Dictionary = {}
	for color in COLORS:
		kinds_by_color[color] = {"factory": false, "market": false}
	for card_variant in hand:
		var card := card_variant as Dictionary
		var kind := str(card.get("kind", ""))
		var color := str(card.get("color", ""))
		factory_count += 1 if kind == "factory" else 0
		market_count += 1 if kind == "market" else 0
		(kinds_by_color.get(color, {}) as Dictionary)[kind] = true
	var matching_pairs := 0
	for color in COLORS:
		var color_kinds := kinds_by_color.get(color, {}) as Dictionary
		if bool(color_kinds.get("factory", false)) \
				and bool(color_kinds.get("market", false)):
			matching_pairs += 1
	(accumulator.get("opening_factory_counts", []) as Array).append(factory_count)
	(accumulator.get("opening_market_counts", []) as Array).append(market_count)
	(accumulator.get("opening_matching_pair_counts", []) as Array).append(
		matching_pairs
	)
	var assets: Dictionary = {}
	var played_kinds: Dictionary = {}
	var commodity_l1: Dictionary = {}
	var commodity_l2: Dictionary = {}
	for color in COLORS:
		assets[color] = int(profile.get("initial_assets_per_color", 1))
		played_kinds[color] = {"factory": false, "market": false}
		commodity_l1[color] = 0
		commodity_l2[color] = 0
	return {
		"player_id": player_id,
		"assets": assets,
		"cash": 15,
		"draw_pile": deck,
		"hand": hand,
		"discard": [],
		"played_kinds": played_kinds,
		"first_chain_batch": 0,
		"purchase_sequence": 0,
		"first_purchase_draw_latency": -1,
		"commodity_l1": commodity_l1,
		"commodity_l2": commodity_l2,
		"pending_commodities": [],
		"commodity_l2_first_time_seconds": 0,
		"commodity_l3_first_time_seconds": 0,
		"merge_sequence": 0,
	}


func _process_track_opportunities(
	player: Dictionary,
	stream: DeterministicStream,
	profile: Dictionary,
	batch_id: int,
	is_lead: bool,
	player_count: int,
	accumulator: Dictionary
) -> void:
	for opportunity in range(TRACK_OPPORTUNITIES_PER_BATCH):
		if is_lead:
			accumulator["lead_acquisition_exposure_count"] = int(
				accumulator.get("lead_acquisition_exposure_count", 0)
			) + 1
		else:
			accumulator["other_acquisition_exposure_count"] = int(
				accumulator.get("other_acquisition_exposure_count", 0)
			) + 1
		var acquisition_threshold := 5900 if is_lead else 5200
		if not stream.chance_basis_points(acquisition_threshold):
			continue
		var scroll_sequence := (batch_id - 1) * TRACK_OPPORTUNITIES_PER_BATCH \
			+ opportunity + 1
		var replacement := track_replacement_state(scroll_sequence)
		if bool(replacement.get("claimable_same_tick", true)):
			accumulator["replacement_same_tick_claim_count"] = int(
				accumulator.get("replacement_same_tick_claim_count", 0)
			) + 1
		var is_normal := stream.bounded(10000) < int(
			profile.get("normal_card_ratio_basis_points", 7000)
		)
		var color: String = COLORS[stream.bounded(COLORS.size())]
		if is_normal:
			if int(player.get("cash", 0)) < 5:
				continue
			player["cash"] = int(player.get("cash", 0)) - 5
			player["purchase_sequence"] = int(
				player.get("purchase_sequence", 0)
			) + 1
			var card := {
				"instance_id": "%s.purchase.%04d" % [
					str(player.get("player_id", "")),
					int(player.get("purchase_sequence", 0)),
				],
				"kind": "factory" if stream.bounded(2) == 0 else "market",
				"color": color,
				"level": 1,
				"purchase_batch": batch_id,
			}
			(player.get("discard", []) as Array).append(card)
		else:
			var queue_locked := not stream.chance_basis_points(6000)
			var available_from_batch := commodity_available_from_batch(
				batch_id,
				queue_locked
			)
			if available_from_batch == batch_id:
				var l1 := player.get("commodity_l1", {}) as Dictionary
				l1[color] = int(l1.get(color, 0)) + 1
			else:
				(player.get("pending_commodities", []) as Array).append({
					"color": color,
					"available_from_batch_id": available_from_batch,
				})
		if is_lead:
			accumulator["lead_acquisition_count"] = int(
				accumulator.get("lead_acquisition_count", 0)
			) + 1
		else:
			accumulator["other_acquisition_count"] = int(
				accumulator.get("other_acquisition_count", 0)
			) + 1
		accumulator["track_spawn_count"] = int(
			accumulator.get("track_spawn_count", 0)
		) + 1
		accumulator["track_high_level_spawn_count"] = int(
			accumulator.get("track_high_level_spawn_count", 0)
		) + 0


func _activate_pending_commodities(player: Dictionary, batch_id: int) -> void:
	var pending := player.get("pending_commodities", []) as Array
	var remaining: Array = []
	for row_variant in pending:
		var row := row_variant as Dictionary
		if int(row.get("available_from_batch_id", 0)) <= batch_id:
			var color := str(row.get("color", ""))
			var l1 := player.get("commodity_l1", {}) as Dictionary
			l1[color] = int(l1.get(color, 0)) + 1
		else:
			remaining.append(row.duplicate(true))
	player["pending_commodities"] = remaining


func _merge_available_commodities(player: Dictionary, batch_id: int) -> void:
	var l1 := player.get("commodity_l1", {}) as Dictionary
	var l2 := player.get("commodity_l2", {}) as Dictionary
	for color in COLORS:
		while int(l1.get(color, 0)) >= 2:
			l1[color] = int(l1.get(color, 0)) - 2
			l2[color] = int(l2.get(color, 0)) + 1
			if int(player.get("commodity_l2_first_time_seconds", 0)) == 0:
				player["commodity_l2_first_time_seconds"] = batch_id * BATCH_SECONDS
		while int(l2.get(color, 0)) >= 1 and int(l1.get(color, 0)) >= 1:
			l2[color] = int(l2.get(color, 0)) - 1
			l1[color] = int(l1.get(color, 0)) - 1
			if int(player.get("commodity_l3_first_time_seconds", 0)) == 0:
				player["commodity_l3_first_time_seconds"] = batch_id * BATCH_SECONDS


func _play_player_batch(
	player: Dictionary,
	stream: DeterministicStream,
	profile: Dictionary,
	batch_id: int,
	player_count: int,
	accumulator: Dictionary
) -> Dictionary:
	var target_roll := stream.bounded(10000)
	var target_actions := 2 if target_roll < 5500 else (3 if target_roll < 9000 else 4)
	var hand := player.get("hand", []) as Array
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
		return str((left.get("card", {}) as Dictionary).get("instance_id", "")) \
			< str((right.get("card", {}) as Dictionary).get("instance_id", ""))
	)
	var played_ids: Array[String] = []
	var active_actions := 0
	var major_actions := 0
	var examined := 0
	for candidate in candidates:
		if active_actions >= target_actions or examined >= HAND_LIMIT:
			break
		examined += 1
		accumulator["intended_action_count"] = int(
			accumulator.get("intended_action_count", 0)
		) + 1
		var card := candidate.get("card", {}) as Dictionary
		var color := str(card.get("color", ""))
		var cost := clampi(int(card.get("level", 1)), 1, 4)
		var assets := player.get("assets", {}) as Dictionary
		if int(assets.get(color, 0)) < cost:
			accumulator["zero_asset_blocked_action_count"] = int(
				accumulator.get("zero_asset_blocked_action_count", 0)
			) + 1
			continue
		assets[color] = int(assets.get(color, 0)) - cost
		active_actions += 1
		major_actions += 1 if int(card.get("level", 1)) >= 3 else 0
		accumulator["active_action_count"] = int(
			accumulator.get("active_action_count", 0)
		) + 1
		var fizzle_basis_points := 300 + (player_count - 3) * 70 \
			+ maxi(0, int(card.get("level", 1)) - 1) * 80
		var fizzled := stream.chance_basis_points(fizzle_basis_points)
		if fizzled:
			assets[color] = int(assets.get(color, 0)) + cost
			accumulator["invalid_target_fizzle_count"] = int(
				accumulator.get("invalid_target_fizzle_count", 0)
			) + 1
		else:
			var kinds := player.get("played_kinds", {}) as Dictionary
			var color_kinds := kinds.get(color, {}) as Dictionary
			color_kinds[str(card.get("kind", ""))] = true
			if int(player.get("first_chain_batch", 0)) == 0 \
					and bool(color_kinds.get("factory", false)) \
					and bool(color_kinds.get("market", false)):
				player["first_chain_batch"] = batch_id
		played_ids.append(str(card.get("instance_id", "")))
	var remaining_hand: Array = []
	for card_variant in hand:
		var card := card_variant as Dictionary
		if played_ids.has(str(card.get("instance_id", ""))):
			(player.get("discard", []) as Array).append(card)
		else:
			remaining_hand.append(card)
	player["hand"] = remaining_hand
	_draw_to_hand_limit(player, stream, batch_id)
	_apply_optional_merge(player, stream, profile, batch_id, accumulator)
	return {
		"active_actions": active_actions,
		"major_actions": major_actions,
	}


func _draw_to_hand_limit(
	player: Dictionary,
	stream: DeterministicStream,
	batch_id: int
) -> void:
	var hand := player.get("hand", []) as Array
	var draw_pile := player.get("draw_pile", []) as Array
	while hand.size() < HAND_LIMIT:
		if draw_pile.is_empty():
			var discard := player.get("discard", []) as Array
			if discard.is_empty():
				break
			draw_pile = discard.duplicate(true)
			discard.clear()
			_shuffle_in_place(draw_pile, stream)
			player["draw_pile"] = draw_pile
		var card := draw_pile.pop_back() as Dictionary
		hand.append(card)
		var purchase_batch := int(card.get("purchase_batch", 0))
		if purchase_batch > 0 \
				and int(player.get("first_purchase_draw_latency", -1)) < 0:
			player["first_purchase_draw_latency"] = maxi(
				1,
				batch_id - purchase_batch
			)
	player["hand"] = hand
	player["draw_pile"] = draw_pile


func _apply_optional_merge(
	player: Dictionary,
	stream: DeterministicStream,
	profile: Dictionary,
	batch_id: int,
	accumulator: Dictionary
) -> void:
	var pair := _first_merge_pair(player.get("hand", []) as Array)
	if pair.is_empty():
		return
	accumulator["maintenance_decision_count"] = int(
		accumulator.get("maintenance_decision_count", 0)
	) + 1
	accumulator["optional_merge_offer_count"] = int(
		accumulator.get("optional_merge_offer_count", 0)
	) + 1
	var decision_seconds := 2 + stream.bounded(8)
	if decision_seconds > int(profile.get("hand_maintenance_timeout_seconds", 20)):
		accumulator["maintenance_timeout_count"] = int(
			accumulator.get("maintenance_timeout_count", 0)
		) + 1
		return
	if not stream.chance_basis_points(5200):
		return
	var admission := normal_merge_admission(_normal_card_total(player))
	if not bool(admission.get("accepted", false)):
		accumulator["minimum_deck_merge_rejection_count"] = int(
			accumulator.get("minimum_deck_merge_rejection_count", 0)
		) + 1
		return
	var hand := player.get("hand", []) as Array
	var left_index := int(pair.get("left_index", -1))
	var right_index := int(pair.get("right_index", -1))
	var left := hand[left_index] as Dictionary
	var high := maxi(left_index, right_index)
	var low := mini(left_index, right_index)
	hand.remove_at(high)
	hand.remove_at(low)
	player["merge_sequence"] = int(player.get("merge_sequence", 0)) + 1
	hand.append({
		"instance_id": "%s.merge.%04d" % [
			str(player.get("player_id", "")),
			int(player.get("merge_sequence", 0)),
		],
		"kind": str(left.get("kind", "")),
		"color": str(left.get("color", "")),
		"level": int(left.get("level", 1)) + 1,
		"purchase_batch": 0,
	})
	player["hand"] = hand
	accumulator["optional_merge_accept_count"] = int(
		accumulator.get("optional_merge_accept_count", 0)
	) + 1
	_draw_to_hand_limit(player, stream, batch_id)


func _refresh_assets(
	player: Dictionary,
	stream: DeterministicStream,
	profile: Dictionary,
	accumulator: Dictionary
) -> void:
	var assets := player.get("assets", {}) as Dictionary
	for color in COLORS:
		var raw_refresh := 0
		raw_refresh += 1 if stream.chance_basis_points(5000) else 0
		raw_refresh += 1 if stream.chance_basis_points(1500) else 0
		raw_refresh += 1 if stream.chance_basis_points(400) else 0
		raw_refresh += 1 if stream.chance_basis_points(100) else 0
		var refresh_cap := int(
			profile.get("max_asset_refresh_per_color_per_batch", ASSET_CAP)
		)
		var applied_refresh := mini(raw_refresh, refresh_cap)
		accumulator["asset_refresh_candidate_points"] = int(
			accumulator.get("asset_refresh_candidate_points", 0)
		) + raw_refresh
		var candidate_total := int(assets.get(color, 0)) + applied_refresh
		var overflow := maxi(0, candidate_total - ASSET_CAP)
		accumulator["asset_overflow_points"] = int(
			accumulator.get("asset_overflow_points", 0)
		) + overflow
		assets[color] = mini(ASSET_CAP, candidate_total)


func _simulate_color_cycle(
	profile: Dictionary,
	players: Array[Dictionary],
	lead_index: int,
	stream: DeterministicStream,
	accumulator: Dictionary
) -> void:
	var stances: Array[Dictionary] = []
	for player_index in range(players.size()):
		var up_index := stream.bounded(COLORS.size())
		var down_index := stream.bounded(COLORS.size() - 1)
		if down_index >= up_index:
			down_index += 1
		stances.append({
			"actor_id": str(players[player_index].get("player_id", "")),
			"increase_color": COLORS[up_index],
			"decrease_color": COLORS[down_index],
		})
	var actual := _color_distribution(
		stances,
		str(players[lead_index].get("player_id", "")),
		profile
	)
	var distribution := actual.get("distribution_basis_points", {}) as Dictionary
	for color in COLORS:
		(accumulator.get("color_share_basis_points", []) as Array).append(
			int(distribution.get(color, 0))
		)
	accumulator["color_cycle_count"] = int(
		accumulator.get("color_cycle_count", 0)
	) + 1
	if bool(actual.get("intervention_cap_hit", false)):
		accumulator["color_cap_hit_count"] = int(
			accumulator.get("color_cap_hit_count", 0)
		) + 1
	var matching_lead_count := 0
	for candidate in players:
		var candidate_distribution := _color_distribution(
			stances,
			str(candidate.get("player_id", "")),
			profile
		).get("distribution_basis_points", {}) as Dictionary
		if candidate_distribution == distribution:
			matching_lead_count += 1
	if matching_lead_count == 1:
		accumulator["lead_inference_unique_count"] = int(
			accumulator.get("lead_inference_unique_count", 0)
		) + 1


func _color_distribution(
	stances: Array[Dictionary],
	lead_id: String,
	profile: Dictionary
) -> Dictionary:
	var deltas: Dictionary = {}
	for color in COLORS:
		deltas[color] = 0
	for stance in stances:
		var influence := 3600 if str(stance.get("actor_id", "")) == lead_id \
			else 1800
		var up := str(stance.get("increase_color", ""))
		var down := str(stance.get("decrease_color", ""))
		deltas[up] = int(deltas.get(up, 0)) + influence
		deltas[down] = int(deltas.get(down, 0)) - influence
	var intervention_cap_hit := false
	if bool(profile.get("single_color_net_intervention_cap_enabled", false)):
		var max_delta := int(
			profile.get("single_color_net_intervention_cap_basis_points", 1200)
		) * COLORS.size()
		for color in COLORS:
			var delta := int(deltas.get(color, 0))
			if absi(delta) > max_delta:
				intervention_cap_hit = true
			deltas[color] = clampi(delta, -max_delta, max_delta)
	var weights: Dictionary = {}
	for color in COLORS:
		weights[color] = clampi(10000 + int(deltas.get(color, 0)), 3000, 24000)
	return {
		"distribution_basis_points": _normalize_color_weights(weights),
		"intervention_cap_hit": intervention_cap_hit,
	}


func _normalize_color_weights(weights: Dictionary) -> Dictionary:
	var total := 0
	for color in COLORS:
		total += int(weights.get(color, 0))
	var result: Dictionary = {}
	var remainders: Array[Dictionary] = []
	var allocated := 0
	for color_index in range(COLORS.size()):
		var color: String = COLORS[color_index]
		var numerator := int(weights.get(color, 0)) * 10000
		var base := numerator / total
		result[color] = base
		allocated += base
		remainders.append({
			"color": color,
			"remainder": numerator % total,
			"color_index": color_index,
		})
	remainders.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_remainder := int(left.get("remainder", 0))
		var right_remainder := int(right.get("remainder", 0))
		if left_remainder != right_remainder:
			return left_remainder > right_remainder
		return int(left.get("color_index", 0)) < int(right.get("color_index", 0))
	)
	for index in range(10000 - allocated):
		var color := str(remainders[index].get("color", ""))
		result[color] = int(result.get(color, 0)) + 1
	return result


func _metrics_from_accumulator(accumulator: Dictionary) -> Dictionary:
	var opening_factory := accumulator.get("opening_factory_counts", []) as Array
	var opening_market := accumulator.get("opening_market_counts", []) as Array
	var opening_pairs := accumulator.get("opening_matching_pair_counts", []) as Array
	var first_chain := accumulator.get("first_chain_batches", []) as Array
	var active_actions := accumulator.get("active_actions", []) as Array
	var normal_draw := accumulator.get("normal_purchase_draw_batches", []) as Array
	var l2_seconds := accumulator.get("commodity_l2_seconds", []) as Array
	var l3_seconds := accumulator.get("commodity_l3_seconds", []) as Array
	var resolution_seconds := accumulator.get("resolution_seconds", []) as Array
	var victory_batches := accumulator.get("victory_tail_batches", []) as Array
	var victory_seconds := accumulator.get("victory_tail_seconds", []) as Array
	var color_shares := accumulator.get("color_share_basis_points", []) as Array
	var solar_ratios := accumulator.get("solar_throughput_ratios", []) as Array
	var lead_rate := _safe_ratio(
		int(accumulator.get("lead_acquisition_count", 0)),
		int(accumulator.get("lead_acquisition_exposure_count", 0))
	)
	var other_rate := _safe_ratio(
		int(accumulator.get("other_acquisition_count", 0)),
		int(accumulator.get("other_acquisition_exposure_count", 0))
	)
	return {
		"opening_hand_factory_count": _sample_summary(opening_factory),
		"opening_hand_market_count": _sample_summary(opening_market),
		"opening_hand_matching_pair_count": _sample_summary(opening_pairs),
		"first_viable_factory_market_chain_batch": _sample_summary(
			first_chain,
			int(accumulator.get("first_chain_censored_count", 0))
		),
		"average_active_actions_per_player_per_batch": _mean(active_actions),
		"p95_active_actions_per_player_per_batch": _percentile(active_actions, 0.95),
		"normal_purchase_to_first_draw_batches": _sample_summary(
			normal_draw,
			int(accumulator.get("normal_draw_censored_count", 0))
		),
		"commodity_l2_first_time_seconds": _sample_summary(
			l2_seconds,
			int(accumulator.get("commodity_l2_censored_count", 0))
		),
		"commodity_l3_first_time_seconds": _sample_summary(
			l3_seconds,
			int(accumulator.get("commodity_l3_censored_count", 0))
		),
		"lead_track_acquisition_advantage_ratio": _round_ratio(
			lead_rate / other_rate if other_rate > 0.0 else 0.0
		),
		"lead_acquisition_rate": lead_rate,
		"nonlead_acquisition_rate": other_rate,
		"color_share_min": _minimum_int(color_shares),
		"color_share_max": _maximum_int(color_shares),
		"color_cap_hit_rate": _safe_ratio(
			int(accumulator.get("color_cap_hit_count", 0)),
			int(accumulator.get("color_cycle_count", 0))
		),
		"single_color_asset_overflow_rate": _safe_ratio(
			int(accumulator.get("asset_overflow_points", 0)),
			int(accumulator.get("asset_refresh_candidate_points", 0))
		),
		"zero_asset_blocked_action_rate": _safe_ratio(
			int(accumulator.get("zero_asset_blocked_action_count", 0)),
			int(accumulator.get("intended_action_count", 0))
		),
		"invalid_target_fizzle_rate": _safe_ratio(
			int(accumulator.get("invalid_target_fizzle_count", 0)),
			int(accumulator.get("active_action_count", 0))
		),
		"maintenance_timeout_rate": _safe_ratio(
			int(accumulator.get("maintenance_timeout_count", 0)),
			int(accumulator.get("maintenance_decision_count", 0))
		),
		"optional_merge_accept_rate": _safe_ratio(
			int(accumulator.get("optional_merge_accept_count", 0)),
			int(accumulator.get("optional_merge_offer_count", 0))
		),
		"predicted_resolution_animation_seconds": _sample_summary(
			resolution_seconds
		),
		"victory_pending_tail_batches": _sample_summary(victory_batches),
		"victory_pending_tail_seconds": _sample_summary(victory_seconds),
		"lead_inference_unique_rate": _safe_ratio(
			int(accumulator.get("lead_inference_unique_count", 0)),
			int(accumulator.get("color_cycle_count", 0))
		),
		"sunlit_chain_throughput_ratio": _mean(solar_ratios),
		"solar_multiplier_application_count_per_channel": int(
			accumulator.get("solar_channel_application_count", 0)
		),
		"track_replacement_claimable_same_tick_count": int(
			accumulator.get("replacement_same_tick_claim_count", 0)
		),
		"track_high_level_normal_spawn_count": int(
			accumulator.get("track_high_level_spawn_count", 0)
		),
		"track_high_level_commodity_spawn_count": int(
			accumulator.get("track_high_level_spawn_count", 0)
		),
		"minimum_normal_deck_size_violation_commit_count": 0,
	}


func _configuration_failed_targets(metrics: Dictionary, player_count: int) -> Array[String]:
	var failed: Array[String] = []
	var first_chain := metrics.get(
		"first_viable_factory_market_chain_batch", {}
	) as Dictionary
	if float(first_chain.get("median", 999.0)) > 2.0:
		failed.append("FIRST_CHAIN_MEDIAN_BATCH")
	if float(first_chain.get("p95", 999.0)) > 3.0:
		failed.append("FIRST_CHAIN_P95_BATCH")
	var average_actions := float(
		metrics.get("average_active_actions_per_player_per_batch", 0.0)
	)
	if average_actions < 1.5 or average_actions > 3.0:
		failed.append("AVERAGE_ACTIVE_ACTIONS_PER_PLAYER_PER_BATCH")
	if float(metrics.get("invalid_target_fizzle_rate", 1.0)) >= 0.10:
		failed.append("INVALID_TARGET_FIZZLE_RATE")
	var normal_latency := metrics.get(
		"normal_purchase_to_first_draw_batches", {}
	) as Dictionary
	if float(normal_latency.get("median", 999.0)) > 3.0:
		failed.append("NORMAL_PURCHASE_TO_FIRST_DRAW_MEDIAN_BATCH")
	var l2 := metrics.get("commodity_l2_first_time_seconds", {}) as Dictionary
	var l3 := metrics.get("commodity_l3_first_time_seconds", {}) as Dictionary
	if float(l2.get("median", 999.0)) > 240.0:
		failed.append("COMMODITY_L2_MEDIAN_SECONDS")
	if float(l3.get("median", 999.0)) > 480.0:
		failed.append("COMMODITY_L3_MEDIAN_SECONDS")
	if float(metrics.get("lead_track_acquisition_advantage_ratio", 99.0)) > 1.5:
		failed.append("LEAD_ACQUISITION_ADVANTAGE_RATIO")
	if float(metrics.get("single_color_asset_overflow_rate", 1.0)) >= 0.20:
		failed.append("ASSET_OVERFLOW_RATE")
	if float(metrics.get("zero_asset_blocked_action_rate", 1.0)) >= 0.10:
		failed.append("ZERO_ASSET_BLOCKED_ACTION_RATE")
	var resolution := metrics.get(
		"predicted_resolution_animation_seconds", {}
	) as Dictionary
	if player_count == 4 and float(resolution.get("p95", 999.0)) > 15.0:
		failed.append("FOUR_PLAYER_PREDICTED_RESOLUTION_P95_SECONDS")
	if player_count == 8 and float(resolution.get("p95", 999.0)) > 25.0:
		failed.append("EIGHT_PLAYER_PREDICTED_RESOLUTION_P95_SECONDS")
	var victory := metrics.get("victory_pending_tail_seconds", {}) as Dictionary
	if float(victory.get("p95", 999.0)) > 240.0:
		failed.append("VICTORY_PENDING_TAIL_P95_SECONDS")
	var solar_ratio := float(metrics.get("sunlit_chain_throughput_ratio", 0.0))
	if solar_ratio < 1.8 or solar_ratio > 2.2:
		failed.append("SUNLIT_CHAIN_THROUGHPUT_RATIO")
	failed.sort()
	return failed


func _profile_failed_targets(
	metrics: Dictionary,
	by_player_count: Dictionary
) -> Array[String]:
	var failed := _configuration_failed_targets(metrics, 0)
	for player_count in [4, 8]:
		var result := by_player_count.get(str(player_count), {}) as Dictionary
		var count_metrics := result.get("metrics", {}) as Dictionary
		var resolution := count_metrics.get(
			"predicted_resolution_animation_seconds", {}
		) as Dictionary
		var threshold := 15.0 if player_count == 4 else 25.0
		if float(resolution.get("p95", 999.0)) > threshold:
			failed.append(
				"FOUR_PLAYER_PREDICTED_RESOLUTION_P95_SECONDS" \
				if player_count == 4 \
				else "EIGHT_PLAYER_PREDICTED_RESOLUTION_P95_SECONDS"
			)
	failed.sort()
	return _unique_strings(failed)


func _select_recommended_profile(
	profile_results: Array[Dictionary],
	profile_rows: Array[Dictionary]
) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for result in profile_results:
		if str(result.get("profile_id", "")) == PROFILE_BASELINE:
			continue
		candidates.append(result)
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_failed := int(left.get("failed_fun_target_count", 999))
		var right_failed := int(right.get("failed_fun_target_count", 999))
		if left_failed != right_failed:
			return left_failed < right_failed
		var left_tail := float((left.get("metrics", {}) as Dictionary).get(
			"victory_pending_tail_seconds", {}
		).get("p95", 999.0))
		var right_tail := float((right.get("metrics", {}) as Dictionary).get(
			"victory_pending_tail_seconds", {}
		).get("p95", 999.0))
		if not is_equal_approx(left_tail, right_tail):
			return left_tail < right_tail
		return str(left.get("profile_id", "")) < str(right.get("profile_id", ""))
	)
	if candidates.is_empty():
		return {}
	var winner := candidates[0]
	var profile: Dictionary = {}
	for row in profile_rows:
		if str(row.get("profile_id", "")) == str(winner.get("profile_id", "")):
			profile = row
			break
	return {
		"profile_id": str(winner.get("profile_id", "")),
		"profile_fingerprint": str(winner.get("profile_fingerprint", "")),
		"failed_fun_targets": winner.get("failed_fun_targets", []).duplicate(),
		"failed_fun_target_count": int(winner.get("failed_fun_target_count", 0)),
		"selection_policy": "fewest_failed_targets_then_shortest_victory_tail",
		"lead_tenure_batches": int(profile.get("lead_tenure_batches", 0)),
		"initial_assets_per_color": int(profile.get("initial_assets_per_color", 0)),
		"normal_card_ratio_basis_points": int(
			profile.get("normal_card_ratio_basis_points", 0)
		),
		"commodity_card_ratio_basis_points": int(
			profile.get("commodity_card_ratio_basis_points", 0)
		),
		"single_color_net_intervention_cap_basis_points": int(
			profile.get("single_color_net_intervention_cap_basis_points", 0)
		),
		"max_asset_refresh_per_color_per_batch": int(
			profile.get("max_asset_refresh_per_color_per_batch", 0)
		),
		"hand_maintenance_timeout_seconds": int(
			profile.get("hand_maintenance_timeout_seconds", 0)
		),
		"human_fun_proven": false,
		"human_test_still_required": true,
	}


func _new_accumulator() -> Dictionary:
	return {
		"opening_factory_counts": [],
		"opening_market_counts": [],
		"opening_matching_pair_counts": [],
		"first_chain_batches": [],
		"normal_purchase_draw_batches": [],
		"commodity_l2_seconds": [],
		"commodity_l3_seconds": [],
		"active_actions": [],
		"resolution_seconds": [],
		"victory_tail_batches": [],
		"victory_tail_seconds": [],
		"color_share_basis_points": [],
		"solar_throughput_ratios": [],
		"first_chain_censored_count": 0,
		"normal_draw_censored_count": 0,
		"commodity_l2_censored_count": 0,
		"commodity_l3_censored_count": 0,
		"lead_acquisition_exposure_count": 0,
		"lead_acquisition_count": 0,
		"other_acquisition_exposure_count": 0,
		"other_acquisition_count": 0,
		"color_cycle_count": 0,
		"color_cap_hit_count": 0,
		"lead_inference_unique_count": 0,
		"asset_refresh_candidate_points": 0,
		"asset_overflow_points": 0,
		"intended_action_count": 0,
		"active_action_count": 0,
		"zero_asset_blocked_action_count": 0,
		"invalid_target_fizzle_count": 0,
		"maintenance_decision_count": 0,
		"maintenance_timeout_count": 0,
		"optional_merge_offer_count": 0,
		"optional_merge_accept_count": 0,
		"minimum_deck_merge_rejection_count": 0,
		"replacement_same_tick_claim_count": 0,
		"track_spawn_count": 0,
		"track_high_level_spawn_count": 0,
		"solar_channel_application_count": 0,
	}


func _combine_accumulators(target: Dictionary, source: Dictionary) -> void:
	for key in target:
		if target.get(key) is Array:
			(target.get(key) as Array).append_array(
				(source.get(key, []) as Array).duplicate()
			)
		elif key == "solar_channel_application_count":
			target[key] = maxi(int(target.get(key, 0)), int(source.get(key, 0)))
		else:
			target[key] = int(target.get(key, 0)) + int(source.get(key, 0))


func _starter_cards(player_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for color in COLORS:
		for kind in ["factory", "market"]:
			result.append({
				"instance_id": "%s.starter.%s.%s" % [player_id, kind, color],
				"kind": kind,
				"color": color,
				"level": 1,
				"purchase_batch": 0,
			})
	return result


func _card_priority(card: Dictionary, player: Dictionary) -> int:
	var color := str(card.get("color", ""))
	var kind := str(card.get("kind", ""))
	var opposite := "market" if kind == "factory" else "factory"
	var color_kinds := (
		player.get("played_kinds", {}) as Dictionary
	).get(color, {}) as Dictionary
	if bool(color_kinds.get(opposite, false)) and not bool(color_kinds.get(kind, false)):
		return 0
	if not bool(color_kinds.get(kind, false)):
		return 1
	return 2 + int(card.get("level", 1))


func _first_merge_pair(hand: Array) -> Dictionary:
	for left_index in range(hand.size()):
		var left := hand[left_index] as Dictionary
		if int(left.get("level", 0)) >= 4:
			continue
		for right_index in range(left_index + 1, hand.size()):
			var right := hand[right_index] as Dictionary
			if str(left.get("kind", "")) == str(right.get("kind", "")) \
					and str(left.get("color", "")) == str(right.get("color", "")) \
					and int(left.get("level", 0)) == int(right.get("level", 0)):
				return {"left_index": left_index, "right_index": right_index}
	return {}


func _completed_chain_count(player: Dictionary) -> int:
	var count := 0
	var kinds := player.get("played_kinds", {}) as Dictionary
	for color in COLORS:
		var color_kinds := kinds.get(color, {}) as Dictionary
		if bool(color_kinds.get("factory", false)) \
				and bool(color_kinds.get("market", false)):
			count += 1
	return count


func _normal_card_total(player: Dictionary) -> int:
	return (player.get("hand", []) as Array).size() \
		+ (player.get("draw_pile", []) as Array).size() \
		+ (player.get("discard", []) as Array).size()


func _lead_index_for_batch(
	hidden_order: Array[int],
	batch_id: int,
	lead_tenure_batches: int
) -> int:
	var lead_slot := (batch_id - 1) / maxi(1, lead_tenure_batches)
	var macro_round := lead_slot / hidden_order.size()
	var within_round := lead_slot % hidden_order.size()
	var order_index := within_round if macro_round % 2 == 0 \
		else hidden_order.size() - 1 - within_round
	return hidden_order[order_index]


func _predicted_resolution_seconds(action_count: int, major_action_count: int) -> float:
	var common_count := maxi(0, action_count - major_action_count)
	var seconds := 0.0
	if action_count <= 12:
		seconds = action_count * 0.6
	elif action_count <= 24:
		seconds = 1.0 + major_action_count * 0.6 + common_count * 0.28
	else:
		seconds = 2.0 + major_action_count * 0.6 + common_count * 0.10
	return _round_ratio(seconds)


func _profile_is_valid(profile: Dictionary) -> bool:
	return not str(profile.get("profile_id", "")).is_empty() \
		and _is_lower_hex(str(profile.get("profile_fingerprint", "")), 64) \
		and int(profile.get("normal_card_ratio_basis_points", 0)) \
			+ int(profile.get("commodity_card_ratio_basis_points", 0)) == 10000 \
		and int(profile.get("initial_assets_per_color", 0)) > 0 \
		and int(profile.get("lead_tenure_batches", 0)) > 0 \
		and int(profile.get("color_cycle_batches", 0)) > 0


func _invalid_report(reason_code: String) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"simulation_id": SIMULATION_ID,
		"valid": false,
		"reason_code": reason_code,
		"human_fun_proven": false,
	}


static func _candidate_closure_fields() -> Dictionary:
	return {
		"track_replacement_activates_on_next_scroll": true,
		"track_replacement_claimable_same_tick": false,
		"normal_deck_minimum_total_card_count": NORMAL_DECK_MINIMUM_TOTAL_CARD_COUNT,
		"normal_track_spawn_level": 1,
		"commodity_track_spawn_level": 1,
		"commodity_claim_before_lock_usable_batch": "current_batch",
		"commodity_claim_after_lock_usable_batch": "next_batch",
		"default_invalid_target_policy": "FIZZLE_FULL_ASSET_REFUND",
		"fizzled_normal_card_destination": "discard",
		"lead_identity_not_directly_published": true,
		"lead_identity_may_be_inferred_from_public_information": true,
		"color_boundary_uses_outgoing_lead": true,
		"lead_advances_after_color_commit": true,
		"lead_advance_implicit_in_color_commit": false,
	}


static func _profile_fingerprint_input(profile: Dictionary) -> String:
	var values: Array[String] = [str(profile.get("profile_id", ""))]
	for field in PROFILE_FINGERPRINT_FIELD_ORDER:
		var value := str(profile.get(field, ""))
		if field == "max_asset_refresh_per_color_per_batch" \
				and bool(profile.get("max_asset_refresh_unbounded", false)):
			value = "unbounded"
		elif profile.get(field) is bool:
			value = "true" if bool(profile.get(field)) else "false"
		values.append("%s=%s" % [field, value])
	return "|".join(values)


static func _replacement_state_valid(state: Dictionary) -> bool:
	var claimed := bool(state.get("claimed", false))
	var lifecycle_valid: bool = (
		claimed
		and state.get("incoming_locked") == false
		and not str(state.get("claimed_request_id", "")).is_empty()
	) or (
		not claimed
		and state.get("incoming_locked") == true
		and str(state.get("claimed_request_id", "")).is_empty()
	)
	return lifecycle_valid \
		and int(state.get("schema_version", 0)) == SCHEMA_VERSION \
		and not str(state.get("instance_id", "")).is_empty() \
		and int(state.get("replacement_created_at_scroll_sequence", -1)) >= 0 \
		and int(state.get("claimable_from_scroll_sequence", -1)) \
			== int(state.get("replacement_created_at_scroll_sequence", -1)) + 1 \
		and state.get("claimable_same_tick") == false \
		and state.get("claimed") is bool \
		and state.get("incoming_locked") is bool \
		and state.get("processed_requests") is Dictionary


static func _solar_chain_throughput(multiplier: int) -> Dictionary:
	var channel_rates: Dictionary = {}
	var application_count_by_channel: Dictionary = {}
	var throughput := 2147483647
	var maximum_application_count := 0
	for channel in SOLAR_CHANNEL_BASE_RATES:
		var application_count := 1
		var rate := int(SOLAR_CHANNEL_BASE_RATES.get(channel, 0)) * multiplier
		channel_rates[channel] = rate
		application_count_by_channel[channel] = application_count
		maximum_application_count = maxi(maximum_application_count, application_count)
		throughput = mini(throughput, rate)
	return {
		"throughput": throughput,
		"channel_rates": channel_rates,
		"application_count_by_channel": application_count_by_channel,
		"maximum_application_count_per_channel": maximum_application_count,
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


static func _sample_summary(values: Array, censored_count: int = 0) -> Dictionary:
	return {
		"sample_count": values.size(),
		"mean": _mean(values),
		"median": _percentile(values, 0.50),
		"p95": _percentile(values, 0.95),
		"minimum": _minimum_number(values),
		"maximum": _maximum_number(values),
		"censored_count": censored_count,
		"censored_rate": _safe_ratio(censored_count, values.size()),
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


static func _minimum_number(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var result := float(values[0])
	for value in values:
		result = minf(result, float(value))
	return _round_ratio(result)


static func _maximum_number(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var result := float(values[0])
	for value in values:
		result = maxf(result, float(value))
	return _round_ratio(result)


static func _minimum_int(values: Array) -> int:
	if values.is_empty():
		return 0
	var result := int(values[0])
	for value in values:
		result = mini(result, int(value))
	return result


static func _maximum_int(values: Array) -> int:
	if values.is_empty():
		return 0
	var result := int(values[0])
	for value in values:
		result = maxi(result, int(value))
	return result


static func _safe_ratio(numerator: int, denominator: int) -> float:
	return _round_ratio(float(numerator) / float(denominator)) \
		if denominator > 0 else 0.0


static func _round_ratio(value: float) -> float:
	return round(value * 1000000.0) / 1000000.0


static func _unique_strings(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if not result.has(value):
			result.append(value)
	return result


static func _is_lower_hex(value: String, length: int) -> bool:
	if value.length() != length or value != value.to_lower():
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true


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
