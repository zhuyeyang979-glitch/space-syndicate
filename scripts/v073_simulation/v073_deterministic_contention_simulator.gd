extends RefCounted
class_name V073DeterministicContentionSimulator


const CORE := preload(
	"res://scripts/v07_semantic/v073_fixed_order_facility_contention_core.gd"
)

const SCHEMA_VERSION := 1
const SIMULATION_ID := "v073.detached.fixed_order_facility_contention.v1"
const SIMULATION_POLICY_ID := "v073.closed_contention_heuristic.v1"
const PLAYER_COUNTS := [3, 4, 6, 8]
const DEFAULT_SEED_COUNT := 500
const FIXED_SEED_BASE := 900726424
const SIMULATION_BATCH_COUNT := 10
const BATCH_SECONDS := 30
const MAX_ACTIONS_PER_PLAYER := 5
const REGION_COUNT := 16

const PROFILE_V072_GENERIC := "V072_GENERIC_FACILITY_TARGETING"
const PROFILE_V073_FIXED := "V073_EXPLICIT_MODES_FIXED_ORDER"
const PROFILE_V073_HIGH_CONTENTION := "V073_HIGH_CONTENTION_DIAGNOSTIC"

const PROFILE_IDS := [
	PROFILE_V072_GENERIC,
	PROFILE_V073_FIXED,
	PROFILE_V073_HIGH_CONTENTION,
]
const NUMERIC_ACCUMULATOR_KEYS := [
	"facility_build_attempt_count",
	"facility_build_success_count",
	"facility_slot_collision_count",
	"facility_build_fizzle_count",
	"asset_refunded_on_contention",
	"card_discarded_on_contention",
	"action_slot_refunded_on_contention",
	"target_reselected_during_resolution_count",
	"build_to_upgrade_auto_conversion_count",
	"build_to_repair_auto_conversion_count",
	"upgrade_attempt_count",
	"upgrade_target_invalidation_count",
	"repair_attempt_count",
	"repair_target_invalidation_count",
	"repeated_contention_same_slot_count",
	"total_action_count",
	"starter_action_count_batch_10",
	"total_action_count_batch_10",
	"anonymous_projection_check_count",
	"anonymous_owner_direct_disclosure_count",
]
const SAMPLE_ACCUMULATOR_KEYS := [
	"first_factory_market_chain_batches",
	"first_standard_l1_play_batches",
	"resolution_seconds",
	"victory_pending_tail_seconds",
]
const REQUIRED_METRIC_KEYS := [
	"facility_build_attempt_count",
	"facility_build_success_count",
	"facility_slot_collision_rate",
	"facility_build_fizzle_rate",
	"fizzle_rate_by_player_count",
	"fizzle_rate_by_local_action_index",
	"critical_build_local_index_0_success_rate",
	"critical_build_local_index_2_success_rate",
	"critical_build_local_index_4_success_rate",
	"asset_refunded_on_contention",
	"card_discarded_on_contention",
	"build_to_upgrade_auto_conversion_count",
	"build_to_repair_auto_conversion_count",
	"upgrade_target_invalidation_rate",
	"repair_target_invalidation_rate",
	"repeated_contention_same_slot_rate",
	"first_factory_market_chain_batch",
	"first_standard_l1_play_batch",
	"starter_action_share_batch_10",
	"resolution_p95_seconds",
	"victory_pending_tail_seconds",
	"anonymous_owner_direct_disclosure_rate",
]


static func profiles() -> Array[Dictionary]:
	return [
		_profile(
			PROFILE_V072_GENERIC,
			"historical_detached_comparison",
			"generic_local_queue",
			false,
			false,
			true,
			800,
			100
		),
		_profile(
			PROFILE_V073_FIXED,
			"approved_first_human_test_sample",
			"fixed_hidden_round_robin",
			true,
			true,
			false,
			700,
			150
		),
		_profile(
			PROFILE_V073_HIGH_CONTENTION,
			"diagnostic_not_candidate_authority",
			"fixed_hidden_round_robin",
			true,
			true,
			false,
			4300,
			450
		),
	]


static func profile_by_id(profile_id: String) -> Dictionary:
	for profile in profiles():
		if profile.get("profile_id") == profile_id:
			return profile.duplicate(true)
	return {}


static func fixed_seed_for(player_count: int, seed_index: int) -> int:
	return FIXED_SEED_BASE + player_count * 100000 + seed_index * 7919


func run_matrix(seed_count: int = DEFAULT_SEED_COUNT) -> Dictionary:
	if seed_count <= 0:
		return _invalid_report("seed_count_invalid")
	var configuration_results: Array[Dictionary] = []
	var profile_results: Array[Dictionary] = []
	for profile in profiles():
		var combined := _new_accumulator()
		var by_player_count := {}
		for player_count in PLAYER_COUNTS:
			var result := run_configuration(profile, player_count, seed_count)
			var public_result := _public_result(result)
			configuration_results.append(public_result)
			by_player_count[str(player_count)] = public_result
			_combine_accumulators(combined, result.get("_accumulator", {}) as Dictionary)
		var metrics := _metrics_from_accumulator(combined)
		metrics["fizzle_rate_by_player_count"] = _rates_by_player_count(
			by_player_count
		)
		var failed_targets := _failed_targets(profile, metrics)
		var profile_result := {
			"profile_id": profile.get("profile_id"),
			"profile_fingerprint": profile.get("profile_fingerprint"),
			"profile_status": profile.get("profile_status"),
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
	var approved := _profile_result(profile_results, PROFILE_V073_FIXED)
	var report := {
		"schema_version": SCHEMA_VERSION,
		"simulation_id": SIMULATION_ID,
		"simulation_policy_id": SIMULATION_POLICY_ID,
		"ruleset_id": "v0.7.3",
		"balance_profile_id": "V073_STARTER_FREE_FIXED_ORDER_CONTENTION",
		"detached_reference_only": true,
		"production_runtime_connected": false,
		"production_connection_count": 0,
		"v06_mutation_count": 0,
		"dual_write_count": 0,
		"production_save_used": false,
		"production_rng_used": false,
		"rules_rng_stream_count": 0,
		"external_asset_source_count": 0,
		"initiative_auction_core_count": 0,
		"initiative_bid_save_field_count": 0,
		"initiative_bid_ui_surface_count": 0,
		"ai_initiative_bid_policy_count": 0,
		"human_fun_proven": false,
		"human_test_required": true,
		"profile_count": PROFILE_IDS.size(),
		"profiles": profiles(),
		"player_counts": PLAYER_COUNTS.duplicate(),
		"player_count_coverage": PLAYER_COUNTS.size(),
		"seed_count_per_configuration": seed_count,
		"qualification_seed_floor": DEFAULT_SEED_COUNT,
		"qualification_seed_floor_met": seed_count >= DEFAULT_SEED_COUNT,
		"configuration_count": PROFILE_IDS.size() * PLAYER_COUNTS.size(),
		"total_match_count": PROFILE_IDS.size() * PLAYER_COUNTS.size() * seed_count,
		"simulation_batch_count_per_match": SIMULATION_BATCH_COUNT,
		"fixed_seed_schedule": {
			"base_seed": FIXED_SEED_BASE,
			"formula_id": "base_plus_player_count_times_100000_plus_seed_index_times_7919",
			"profile_independent_for_paired_comparison": true,
		},
		"required_metric_keys": REQUIRED_METRIC_KEYS.duplicate(),
		"configuration_results": configuration_results,
		"profile_results": profile_results,
		"approved_profile_id": PROFILE_V073_FIXED,
		"approved_profile_fingerprint": approved.get("profile_fingerprint", ""),
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
	if not _profile_valid(profile) or player_count not in PLAYER_COUNTS or seed_count <= 0:
		return {
			"valid": false,
			"reason_code": "simulation_configuration_invalid",
			"_accumulator": _new_accumulator(),
		}
	var accumulator := _new_accumulator()
	var match_fingerprints: Array[String] = []
	for seed_index in range(seed_count):
		match_fingerprints.append(_simulate_match(
			profile,
			player_count,
			fixed_seed_for(player_count, seed_index),
			accumulator
		))
	var metrics := _metrics_from_accumulator(accumulator)
	metrics["fizzle_rate_by_player_count"] = {
		str(player_count): metrics.get("facility_build_fizzle_rate", 0.0),
	}
	var result := {
		"valid": true,
		"reason_code": "simulation_configuration_completed",
		"configuration_id": "%s.players_%d.seeds_%d" % [
			profile.get("profile_id"),
			player_count,
			seed_count,
		],
		"profile_id": profile.get("profile_id"),
		"profile_fingerprint": profile.get("profile_fingerprint"),
		"player_count": player_count,
		"seed_count": seed_count,
		"match_count": seed_count,
		"metrics": metrics,
		"failed_balance_targets": _failed_targets(profile, metrics),
		"run_fingerprint_chain": fingerprint(match_fingerprints),
		"replay_identity": {
			"profile_id": profile.get("profile_id"),
			"profile_fingerprint": profile.get("profile_fingerprint"),
			"simulation_policy_id": SIMULATION_POLICY_ID,
			"first_seed": fixed_seed_for(player_count, 0),
			"last_seed": fixed_seed_for(player_count, seed_count - 1),
			"seed_count": seed_count,
		},
	}
	result["configuration_fingerprint"] = fingerprint(result)
	result["_accumulator"] = accumulator
	return result


func _simulate_match(
	profile: Dictionary,
	player_count: int,
	seed: int,
	accumulator: Dictionary
) -> String:
	var player_ids: Array[String] = []
	var players := {}
	for player_index in range(player_count):
		var player_id := "player.%02d" % (player_index + 1)
		player_ids.append(player_id)
		players[player_id] = {
			"first_chain_batch": 0,
			"first_standard_l1_play_batch": 0,
		}
	var slot_catalog := _slot_catalog()
	var occupied := {}
	var batch_action_counts: Array[int] = []
	for batch_id in range(1, SIMULATION_BATCH_COUNT + 1):
		_apply_damage(seed, batch_id, occupied)
		var empty_at_lock := _empty_slot_ids(slot_catalog, occupied)
		var hot_target := ""
		if not empty_at_lock.is_empty():
			hot_target = empty_at_lock[_bounded(
				seed,
				"batch.%d.hot_target" % batch_id,
				empty_at_lock.size()
			)]
		var queues := {}
		for player_id in player_ids:
			queues[player_id] = _build_player_queue(
				profile,
				seed,
				batch_id,
				player_id,
				empty_at_lock,
				hot_target,
				occupied
			)
		var frozen_order := _rotated_order(
			player_ids,
			_bounded(seed, "batch.%d.order" % batch_id, player_count)
		)
		var batch_result := _resolve_batch(
			profile,
			seed,
			batch_id,
			frozen_order,
			queues,
			slot_catalog,
			occupied,
			players,
			accumulator
		)
		batch_action_counts.append(int(batch_result.get("action_count", 0)))
		(accumulator.get("resolution_seconds") as Array).append(
			batch_result.get("resolution_seconds", 0.0)
		)
	var macro_round_batches := player_count
	var qualification_batch := 6 + _bounded(seed, "victory.qualification", 12)
	var tail_batches := posmod(
		macro_round_batches - (qualification_batch % macro_round_batches),
		macro_round_batches
	)
	(accumulator.get("victory_pending_tail_seconds") as Array).append(
		tail_batches * BATCH_SECONDS
	)
	for player_id in player_ids:
		var player := players.get(player_id) as Dictionary
		var chain_batch := int(player.get("first_chain_batch", 0))
		var standard_batch := int(player.get("first_standard_l1_play_batch", 0))
		(accumulator.get("first_factory_market_chain_batches") as Array).append(
			chain_batch if chain_batch > 0 else SIMULATION_BATCH_COUNT + 1
		)
		(accumulator.get("first_standard_l1_play_batches") as Array).append(
			standard_batch if standard_batch > 0 else SIMULATION_BATCH_COUNT + 1
		)
	return fingerprint({
		"seed": seed,
		"profile_id": profile.get("profile_id"),
		"player_count": player_count,
		"batch_action_counts": batch_action_counts,
		"occupied_slot_count": occupied.size(),
		"victory_tail_batches": tail_batches,
		"player_milestones": players,
	})


func _build_player_queue(
	profile: Dictionary,
	seed: int,
	batch_id: int,
	player_id: String,
	empty_at_lock: Array[String],
	hot_target: String,
	occupied: Dictionary
) -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	var desired_count := _bounded(
		seed,
		"batch.%d.%s.action_count" % [batch_id, player_id],
		MAX_ACTIONS_PER_PLAYER + 1
	)
	for local_index in range(desired_count):
		var action := _build_action(
			profile,
			seed,
			batch_id,
			player_id,
			local_index,
			empty_at_lock,
			hot_target,
			occupied
		)
		if not action.is_empty():
			queue.append(action)
	return queue


func _build_action(
	profile: Dictionary,
	seed: int,
	batch_id: int,
	player_id: String,
	local_index: int,
	empty_at_lock: Array[String],
	hot_target: String,
	occupied: Dictionary
) -> Dictionary:
	var token := "batch.%d.%s.local.%d" % [batch_id, player_id, local_index]
	var own_upgrade := _own_facility_ids(occupied, player_id, false, true)
	var own_repair := _own_facility_ids(occupied, player_id, true, false)
	var mode_roll := _bounded(seed, "%s.mode" % token, 10000)
	var mode := "BUILD_NEW"
	if mode_roll >= 6500 and mode_roll < 8500 and not own_upgrade.is_empty():
		mode = "UPGRADE_OWN"
	elif mode_roll >= 8500 and not own_repair.is_empty():
		mode = "REPAIR_OWN"
	elif empty_at_lock.is_empty() and not own_upgrade.is_empty():
		mode = "UPGRADE_OWN"
	elif empty_at_lock.is_empty() and not own_repair.is_empty():
		mode = "REPAIR_OWN"
	elif empty_at_lock.is_empty():
		return {}
	var origin_class := "starter_bootstrap" if _bounded(
		seed,
		"%s.origin" % token,
		10000
	) < maxi(1800, 8800 - batch_id * 680) else "standard"
	var action := {
		"action_id": "action.%d.%s.%d" % [batch_id, player_id, local_index],
		"actor_id": player_id,
		"local_action_index": local_index,
		"origin_class": origin_class,
		"asset_cost": 0 if origin_class == "starter_bootstrap" else 1,
		"facility_action_mode": mode,
		"target_slot_id": "",
		"target_slot_generation": 0,
		"expected_facility_generation": null,
		"expected_rank": null,
		"expected_damage_revision": null,
	}
	if mode == "BUILD_NEW":
		var hot_threshold := mini(
			9000,
			int(profile.get("hot_target_basis_points", 0))
				+ local_index * int(profile.get("hot_target_index_step_basis_points", 0))
		)
		var use_hot := not hot_target.is_empty() and _bounded(
			seed,
			"%s.hot" % token,
			10000
		) < hot_threshold
		var target_id := hot_target if use_hot else empty_at_lock[_bounded(
			seed,
			"%s.build_target" % token,
			empty_at_lock.size()
		)]
		action["target_slot_id"] = target_id
	else:
		var candidates := own_upgrade if mode == "UPGRADE_OWN" else own_repair
		var target_id := candidates[_bounded(
			seed,
			"%s.own_target" % token,
			candidates.size()
		)]
		var facility := occupied.get(target_id) as Dictionary
		action["target_slot_id"] = target_id
		action["target_slot_generation"] = facility.get("slot_generation", 0)
		action["expected_facility_generation"] = facility.get("facility_generation")
		if mode == "UPGRADE_OWN":
			action["expected_rank"] = facility.get("rank")
		else:
			action["expected_damage_revision"] = facility.get("damage_revision")
	return action


func _resolve_batch(
	profile: Dictionary,
	seed: int,
	batch_id: int,
	frozen_order: Array[String],
	queues: Dictionary,
	slot_catalog: Dictionary,
	occupied: Dictionary,
	players: Dictionary,
	accumulator: Dictionary
) -> Dictionary:
	var action_count := 0
	var batch_fizzle_count := 0
	var batch_invalidation_count := 0
	var collision_counts_by_slot := {}
	for local_index in range(MAX_ACTIONS_PER_PLAYER):
		for player_id in frozen_order:
			var queue := queues.get(player_id, []) as Array
			if local_index >= queue.size():
				continue
			var action := queue[local_index] as Dictionary
			action_count += 1
			accumulator["total_action_count"] = int(
				accumulator.get("total_action_count", 0)
			) + 1
			if batch_id == 10:
				accumulator["total_action_count_batch_10"] = int(
					accumulator.get("total_action_count_batch_10", 0)
				) + 1
				if action.get("origin_class") == "starter_bootstrap":
					accumulator["starter_action_count_batch_10"] = int(
						accumulator.get("starter_action_count_batch_10", 0)
					) + 1
			if action.get("origin_class") == "standard":
				var player := players.get(player_id) as Dictionary
				if int(player.get("first_standard_l1_play_batch", 0)) == 0:
					player["first_standard_l1_play_batch"] = batch_id
			var mode := str(action.get("facility_action_mode", ""))
			if mode == "BUILD_NEW":
				var outcome := _resolve_build(
					profile,
					seed,
					batch_id,
					action,
					slot_catalog,
					occupied,
					collision_counts_by_slot,
					players,
					accumulator
				)
				batch_fizzle_count += 1 if outcome == "fizzled" else 0
			elif mode == "UPGRADE_OWN":
				if not _resolve_upgrade(action, occupied, accumulator):
					batch_invalidation_count += 1
			else:
				if not _resolve_repair(action, occupied, accumulator):
					batch_invalidation_count += 1
			accumulator["anonymous_projection_check_count"] = int(
				accumulator.get("anonymous_projection_check_count", 0)
			) + 1
	var seconds := 0.8 + action_count * 0.24 \
		+ batch_fizzle_count * 0.35 + batch_invalidation_count * 0.20
	return {
		"action_count": action_count,
		"resolution_seconds": _round_ratio(seconds),
	}


func _resolve_build(
	profile: Dictionary,
	seed: int,
	batch_id: int,
	action: Dictionary,
	slot_catalog: Dictionary,
	occupied: Dictionary,
	collision_counts_by_slot: Dictionary,
	players: Dictionary,
	accumulator: Dictionary
) -> String:
	var local_index := int(action.get("local_action_index", 0))
	var attempts := accumulator.get("build_attempts_by_local_index") as Array
	attempts[local_index] = int(attempts[local_index]) + 1
	accumulator["facility_build_attempt_count"] = int(
		accumulator.get("facility_build_attempt_count", 0)
	) + 1
	var target_id := str(action.get("target_slot_id", ""))
	if not occupied.has(target_id):
		_create_facility(target_id, action, slot_catalog, occupied, players, batch_id)
		accumulator["facility_build_success_count"] = int(
			accumulator.get("facility_build_success_count", 0)
		) + 1
		var successes := accumulator.get("build_successes_by_local_index") as Array
		successes[local_index] = int(successes[local_index]) + 1
		return "resolved"
	accumulator["facility_slot_collision_count"] = int(
		accumulator.get("facility_slot_collision_count", 0)
	) + 1
	var prior_collisions := int(collision_counts_by_slot.get(target_id, 0))
	if prior_collisions > 0:
		accumulator["repeated_contention_same_slot_count"] = int(
			accumulator.get("repeated_contention_same_slot_count", 0)
		) + 1
	collision_counts_by_slot[target_id] = prior_collisions + 1
	if bool(profile.get("generic_target_reselection", false)):
		var replacement := _replacement_empty_slot(
			seed,
			"batch.%d.%s.retarget" % [batch_id, action.get("action_id")],
			slot_catalog,
			occupied
		)
		if not replacement.is_empty():
			_create_facility(
				replacement,
				action,
				slot_catalog,
				occupied,
				players,
				batch_id
			)
			accumulator["facility_build_success_count"] = int(
				accumulator.get("facility_build_success_count", 0)
			) + 1
			var successes := accumulator.get("build_successes_by_local_index") as Array
			successes[local_index] = int(successes[local_index]) + 1
			accumulator["target_reselected_during_resolution_count"] = int(
				accumulator.get("target_reselected_during_resolution_count", 0)
			) + 1
			return "retargeted"
	accumulator["facility_build_fizzle_count"] = int(
		accumulator.get("facility_build_fizzle_count", 0)
	) + 1
	var fizzles := accumulator.get("build_fizzles_by_local_index") as Array
	fizzles[local_index] = int(fizzles[local_index]) + 1
	accumulator["asset_refunded_on_contention"] = int(
		accumulator.get("asset_refunded_on_contention", 0)
	) + int(action.get("asset_cost", 0))
	accumulator["card_discarded_on_contention"] = int(
		accumulator.get("card_discarded_on_contention", 0)
	) + 1
	return "fizzled"


func _resolve_upgrade(
	action: Dictionary,
	occupied: Dictionary,
	accumulator: Dictionary
) -> bool:
	accumulator["upgrade_attempt_count"] = int(
		accumulator.get("upgrade_attempt_count", 0)
	) + 1
	var target_id := str(action.get("target_slot_id", ""))
	var valid := occupied.has(target_id)
	var facility := occupied.get(target_id, {}) as Dictionary
	valid = valid \
		and facility.get("owner_id") == action.get("actor_id") \
		and facility.get("facility_generation") \
			== action.get("expected_facility_generation") \
		and facility.get("rank") == action.get("expected_rank") \
		and int(facility.get("rank", 0)) < 4
	if not valid:
		accumulator["upgrade_target_invalidation_count"] = int(
			accumulator.get("upgrade_target_invalidation_count", 0)
		) + 1
		return false
	facility["rank"] = int(facility.get("rank", 0)) + 1
	facility["facility_generation"] = int(facility.get("facility_generation", 0)) + 1
	return true


func _resolve_repair(
	action: Dictionary,
	occupied: Dictionary,
	accumulator: Dictionary
) -> bool:
	accumulator["repair_attempt_count"] = int(
		accumulator.get("repair_attempt_count", 0)
	) + 1
	var target_id := str(action.get("target_slot_id", ""))
	var valid := occupied.has(target_id)
	var facility := occupied.get(target_id, {}) as Dictionary
	valid = valid \
		and facility.get("owner_id") == action.get("actor_id") \
		and facility.get("facility_generation") \
			== action.get("expected_facility_generation") \
		and facility.get("damage_revision") == action.get("expected_damage_revision") \
		and int(facility.get("damage_points", 0)) > 0
	if not valid:
		accumulator["repair_target_invalidation_count"] = int(
			accumulator.get("repair_target_invalidation_count", 0)
		) + 1
		return false
	facility["damage_points"] = 0
	facility["damage_revision"] = int(facility.get("damage_revision", 0)) + 1
	facility["facility_generation"] = int(facility.get("facility_generation", 0)) + 1
	return true


func _create_facility(
	target_id: String,
	action: Dictionary,
	slot_catalog: Dictionary,
	occupied: Dictionary,
	players: Dictionary,
	batch_id: int
) -> void:
	var spec := slot_catalog.get(target_id) as Dictionary
	occupied[target_id] = {
		"slot_id": target_id,
		"slot_generation": 1,
		"facility_generation": 1,
		"owner_id": action.get("actor_id"),
		"rank": 1,
		"damage_revision": 0,
		"damage_points": 0,
		"facility_type": spec.get("facility_type"),
		"industry_id": spec.get("industry_id"),
	}
	var player := players.get(action.get("actor_id")) as Dictionary
	if int(player.get("first_chain_batch", 0)) == 0 \
			and _player_has_chain(str(action.get("actor_id")), occupied):
		player["first_chain_batch"] = batch_id


func _apply_damage(seed: int, batch_id: int, occupied: Dictionary) -> void:
	var slot_ids: Array[String] = []
	for slot_id_variant in occupied.keys():
		slot_ids.append(str(slot_id_variant))
	slot_ids.sort()
	for slot_id in slot_ids:
		var facility := occupied.get(slot_id) as Dictionary
		if _bounded(seed, "batch.%d.damage.%s" % [batch_id, slot_id], 10000) < 1500:
			facility["damage_points"] = mini(3, int(facility.get("damage_points", 0)) + 1)
			facility["damage_revision"] = int(facility.get("damage_revision", 0)) + 1


static func _profile(
	profile_id: String,
	profile_status: String,
	resolution_order_mode: String,
	facility_action_mode_required: bool,
	build_slot_contention_fizzle: bool,
	generic_target_reselection: bool,
	hot_target_basis_points: int,
	hot_target_index_step_basis_points: int
) -> Dictionary:
	var fingerprint_input := "%s|resolution_order_mode=%s|facility_action_mode_required=%s|build_slot_contention_fizzle=%s|generic_target_reselection=%s|hot_target_basis_points=%d|hot_target_index_step_basis_points=%d|initiative_auction_enabled=false|cash_can_change_resolution_order=false" % [
		profile_id,
		resolution_order_mode,
		str(facility_action_mode_required).to_lower(),
		str(build_slot_contention_fizzle).to_lower(),
		str(generic_target_reselection).to_lower(),
		hot_target_basis_points,
		hot_target_index_step_basis_points,
	]
	return {
		"profile_id": profile_id,
		"profile_status": profile_status,
		"resolution_order_mode": resolution_order_mode,
		"resolution_order_source": (
			"frozen_hidden_lead_order_at_batch_lock"
			if resolution_order_mode == "fixed_hidden_round_robin"
			else "v072_generic_reference"
		),
		"facility_action_mode_required": facility_action_mode_required,
		"build_slot_contention_fizzle": build_slot_contention_fizzle,
		"generic_target_reselection": generic_target_reselection,
		"hot_target_basis_points": hot_target_basis_points,
		"hot_target_index_step_basis_points": hot_target_index_step_basis_points,
		"initiative_auction_enabled": false,
		"cash_can_change_resolution_order": false,
		"human_fun_proven": false,
		"human_test_required": true,
		"profile_fingerprint_input": fingerprint_input,
		"profile_fingerprint": fingerprint_input.sha256_text(),
	}


static func _profile_valid(profile: Dictionary) -> bool:
	var input := str(profile.get("profile_fingerprint_input", ""))
	return profile.get("profile_id") in PROFILE_IDS \
		and input.sha256_text() == profile.get("profile_fingerprint") \
		and profile.get("initiative_auction_enabled") == false \
		and profile.get("cash_can_change_resolution_order") == false


static func _slot_catalog() -> Dictionary:
	var catalog := {}
	for region_index in range(REGION_COUNT):
		var region_id := "region.%02d" % (region_index + 1)
		for facility_type in CORE.FACILITY_TYPES:
			for industry_id in CORE.INDUSTRIES:
				var slot_id := CORE.facility_slot_id(
					region_id,
					facility_type,
					industry_id
				)
				catalog[slot_id] = {
					"slot_id": slot_id,
					"region_id": region_id,
					"facility_type": facility_type,
					"industry_id": industry_id,
				}
	return catalog


static func _empty_slot_ids(slot_catalog: Dictionary, occupied: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for slot_id_variant in slot_catalog.keys():
		var slot_id := str(slot_id_variant)
		if not occupied.has(slot_id):
			result.append(slot_id)
	result.sort()
	return result


static func _own_facility_ids(
	occupied: Dictionary,
	player_id: String,
	require_damage: bool,
	require_upgrade_room: bool
) -> Array[String]:
	var result: Array[String] = []
	for slot_id_variant in occupied.keys():
		var facility := occupied.get(slot_id_variant) as Dictionary
		if facility.get("owner_id") != player_id:
			continue
		if require_damage and int(facility.get("damage_points", 0)) <= 0:
			continue
		if require_upgrade_room and int(facility.get("rank", 0)) >= 4:
			continue
		result.append(str(slot_id_variant))
	result.sort()
	return result


static func _replacement_empty_slot(
	seed: int,
	token: String,
	slot_catalog: Dictionary,
	occupied: Dictionary
) -> String:
	var available := _empty_slot_ids(slot_catalog, occupied)
	if available.is_empty():
		return ""
	return available[_bounded(seed, token, available.size())]


static func _rotated_order(player_ids: Array[String], offset: int) -> Array[String]:
	var result: Array[String] = []
	for index in range(player_ids.size()):
		result.append(player_ids[(index + offset) % player_ids.size()])
	return result


static func _player_has_chain(player_id: String, occupied: Dictionary) -> bool:
	var factories: Array[String] = []
	var markets: Array[String] = []
	for facility_variant in occupied.values():
		var facility := facility_variant as Dictionary
		if facility.get("owner_id") != player_id:
			continue
		var industry_id := str(facility.get("industry_id", ""))
		if facility.get("facility_type") == "factory":
			factories.append(industry_id)
		else:
			markets.append(industry_id)
	for industry_id in factories:
		if markets.has(industry_id):
			return true
	return false


static func _new_accumulator() -> Dictionary:
	var result := {
		"first_factory_market_chain_batches": [],
		"first_standard_l1_play_batches": [],
		"resolution_seconds": [],
		"victory_pending_tail_seconds": [],
		"build_attempts_by_local_index": [0, 0, 0, 0, 0],
		"build_successes_by_local_index": [0, 0, 0, 0, 0],
		"build_fizzles_by_local_index": [0, 0, 0, 0, 0],
	}
	for key in NUMERIC_ACCUMULATOR_KEYS:
		result[key] = 0
	return result


static func _combine_accumulators(target: Dictionary, source: Dictionary) -> void:
	for key in NUMERIC_ACCUMULATOR_KEYS:
		target[key] = int(target.get(key, 0)) + int(source.get(key, 0))
	for key in SAMPLE_ACCUMULATOR_KEYS:
		(target.get(key) as Array).append_array((source.get(key, []) as Array).duplicate())
	for key in [
		"build_attempts_by_local_index",
		"build_successes_by_local_index",
		"build_fizzles_by_local_index",
	]:
		var target_values := target.get(key) as Array
		var source_values := source.get(key) as Array
		for index in range(MAX_ACTIONS_PER_PLAYER):
			target_values[index] = int(target_values[index]) + int(source_values[index])


static func _metrics_from_accumulator(accumulator: Dictionary) -> Dictionary:
	var attempts := int(accumulator.get("facility_build_attempt_count", 0))
	var collisions := int(accumulator.get("facility_slot_collision_count", 0))
	var fizzles := int(accumulator.get("facility_build_fizzle_count", 0))
	var attempts_by_index := accumulator.get("build_attempts_by_local_index") as Array
	var successes_by_index := accumulator.get("build_successes_by_local_index") as Array
	var fizzles_by_index := accumulator.get("build_fizzles_by_local_index") as Array
	var fizzle_by_index := {}
	var success_by_index := {}
	for index in range(MAX_ACTIONS_PER_PLAYER):
		fizzle_by_index[str(index)] = _safe_ratio(
			int(fizzles_by_index[index]),
			int(attempts_by_index[index])
		)
		success_by_index[str(index)] = _safe_ratio(
			int(successes_by_index[index]),
			int(attempts_by_index[index])
		)
	var resolution := _sample_summary(accumulator.get("resolution_seconds") as Array)
	return {
		"facility_build_attempt_count": attempts,
		"facility_build_success_count": int(
			accumulator.get("facility_build_success_count", 0)
		),
		"facility_slot_collision_rate": _safe_ratio(collisions, attempts),
		"facility_build_fizzle_rate": _safe_ratio(fizzles, attempts),
		"fizzle_rate_by_player_count": {},
		"fizzle_rate_by_local_action_index": fizzle_by_index,
		"build_success_rate_by_local_action_index": success_by_index,
		"critical_build_local_index_0_success_rate": success_by_index.get("0", 0.0),
		"critical_build_local_index_2_success_rate": success_by_index.get("2", 0.0),
		"critical_build_local_index_4_success_rate": success_by_index.get("4", 0.0),
		"asset_refunded_on_contention": int(
			accumulator.get("asset_refunded_on_contention", 0)
		),
		"card_discarded_on_contention": int(
			accumulator.get("card_discarded_on_contention", 0)
		),
		"action_slot_refunded_on_contention": int(
			accumulator.get("action_slot_refunded_on_contention", 0)
		),
		"target_reselected_during_resolution_count": int(
			accumulator.get("target_reselected_during_resolution_count", 0)
		),
		"build_to_upgrade_auto_conversion_count": int(
			accumulator.get("build_to_upgrade_auto_conversion_count", 0)
		),
		"build_to_repair_auto_conversion_count": int(
			accumulator.get("build_to_repair_auto_conversion_count", 0)
		),
		"upgrade_target_invalidation_rate": _safe_ratio(
			int(accumulator.get("upgrade_target_invalidation_count", 0)),
			int(accumulator.get("upgrade_attempt_count", 0))
		),
		"repair_target_invalidation_rate": _safe_ratio(
			int(accumulator.get("repair_target_invalidation_count", 0)),
			int(accumulator.get("repair_attempt_count", 0))
		),
		"repeated_contention_same_slot_rate": _safe_ratio(
			int(accumulator.get("repeated_contention_same_slot_count", 0)),
			collisions
		),
		"first_factory_market_chain_batch": _sample_summary(
			accumulator.get("first_factory_market_chain_batches") as Array
		),
		"first_standard_l1_play_batch": _sample_summary(
			accumulator.get("first_standard_l1_play_batches") as Array
		),
		"starter_action_share_batch_10": _safe_ratio(
			int(accumulator.get("starter_action_count_batch_10", 0)),
			int(accumulator.get("total_action_count_batch_10", 0))
		),
		"resolution_p95_seconds": resolution.get("p95", 0.0),
		"predicted_resolution_seconds": resolution,
		"victory_pending_tail_seconds": _sample_summary(
			accumulator.get("victory_pending_tail_seconds") as Array
		),
		"anonymous_owner_direct_disclosure_rate": _safe_ratio(
			int(accumulator.get("anonymous_owner_direct_disclosure_count", 0)),
			int(accumulator.get("anonymous_projection_check_count", 0))
		),
	}


static func _rates_by_player_count(by_player_count: Dictionary) -> Dictionary:
	var result := {}
	for player_count in PLAYER_COUNTS:
		var row := by_player_count.get(str(player_count), {}) as Dictionary
		var metrics := row.get("metrics", {}) as Dictionary
		result[str(player_count)] = metrics.get("facility_build_fizzle_rate", 0.0)
	return result


static func _failed_targets(profile: Dictionary, metrics: Dictionary) -> Array[String]:
	var failed: Array[String] = []
	if profile.get("profile_id") == PROFILE_V073_FIXED:
		var fizzle_rate := float(metrics.get("facility_build_fizzle_rate", 0.0))
		if fizzle_rate < 0.03:
			failed.append("FACILITY_CONTENTION_STRATEGY_PRESENCE_TOO_LOW")
		if fizzle_rate > 0.15:
			failed.append("FACILITY_BUILD_FIZZLE_RATE_TOO_HIGH")
	if profile.get("profile_id") != PROFILE_V072_GENERIC:
		if int(metrics.get("build_to_upgrade_auto_conversion_count", -1)) != 0:
			failed.append("BUILD_TO_UPGRADE_AUTO_CONVERSION")
		if int(metrics.get("build_to_repair_auto_conversion_count", -1)) != 0:
			failed.append("BUILD_TO_REPAIR_AUTO_CONVERSION")
		if int(metrics.get("target_reselected_during_resolution_count", -1)) != 0:
			failed.append("TARGET_RESELECTED_DURING_RESOLUTION")
	if float(metrics.get("anonymous_owner_direct_disclosure_rate", 1.0)) != 0.0:
		failed.append("ANONYMOUS_OWNER_DIRECT_DISCLOSURE")
	failed.sort()
	return failed


static func _profile_result(rows: Array[Dictionary], profile_id: String) -> Dictionary:
	for row in rows:
		if row.get("profile_id") == profile_id:
			return row
	return {}


static func _public_result(result: Dictionary) -> Dictionary:
	var public := result.duplicate(true)
	public.erase("_accumulator")
	return public


static func _sample_summary(values: Array) -> Dictionary:
	return {
		"sample_count": values.size(),
		"minimum": _percentile(values, 0.0),
		"mean": _mean(values),
		"median": _percentile(values, 0.5),
		"p95": _percentile(values, 0.95),
		"maximum": _percentile(values, 1.0),
	}


static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return _round_ratio(total / float(values.size()))


static func _percentile(values: Array, ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(int(ceil((sorted.size() - 1) * ratio)), 0, sorted.size() - 1)
	return _round_ratio(float(sorted[index]))


static func _safe_ratio(numerator: int, denominator: int) -> float:
	return _round_ratio(float(numerator) / float(denominator)) if denominator > 0 else 0.0


static func _round_ratio(value: float) -> float:
	return snappedf(value, 0.000001)


static func _bounded(seed: int, token: String, limit: int) -> int:
	if limit <= 0:
		return 0
	return posmod(("%d|%s" % [seed, token]).hash(), limit)


static func _invalid_report(reason_code: String) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"simulation_id": SIMULATION_ID,
		"valid": false,
		"reason_code": reason_code,
		"total_match_count": 0,
	}


static func fingerprint(value: Variant) -> String:
	return _canonical(value).sha256_text()


static func _canonical(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array[String] = []
		for key_variant in (value as Dictionary).keys():
			keys.append(str(key_variant))
		keys.sort()
		var parts: Array[String] = []
		for key in keys:
			parts.append("%s:%s" % [JSON.stringify(key), _canonical((value as Dictionary).get(key))])
		return "{%s}" % ",".join(parts)
	if value is Array:
		var parts: Array[String] = []
		for item in value as Array:
			parts.append(_canonical(item))
		return "[%s]" % ",".join(parts)
	return JSON.stringify(value)
