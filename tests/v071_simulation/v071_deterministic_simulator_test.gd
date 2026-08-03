extends SceneTree

const SIMULATOR := preload(
	"res://scripts/v071_simulation/v071_deterministic_simulator.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	if _has_argument("--parse-only"):
		print("V071_DETERMINISTIC_SIMULATOR_TEST|status=PARSE_ONLY_PASS")
		quit(0)
		return
	call_deferred("_run")


func _run() -> void:
	_test_candidate_contract()
	_test_track_replacement_input_matrix()
	_test_solar_chain_multiplier_once()
	var simulator := SIMULATOR.new()
	var report := simulator.run_matrix(500)
	_test_full_matrix(report)
	_test_deterministic_replay(simulator, report)
	_print_result_summary(report)
	_finish()


func _test_candidate_contract() -> void:
	var profiles := SIMULATOR.profiles()
	_expect(profiles.size() == 3, "exactly three balance profiles are registered")
	var profile_ids: Array[String] = []
	var fingerprints: Array[String] = []
	for profile in profiles:
		var profile_id := str(profile.get("profile_id", ""))
		var profile_fingerprint := str(profile.get("profile_fingerprint", ""))
		profile_ids.append(profile_id)
		fingerprints.append(profile_fingerprint)
		_expect(_is_lower_hex(profile_fingerprint, 64), "%s has a deterministic profile fingerprint" % profile_id)
		_expect(int(profile.get("normal_card_ratio_basis_points", 0)) \
			+ int(profile.get("commodity_card_ratio_basis_points", 0)) == 10000,
			"%s card-kind ratio closes at 10000 basis points" % profile_id)
		_expect(bool(profile.get("track_replacement_activates_on_next_scroll", false)) \
			and not bool(profile.get("track_replacement_claimable_same_tick", true)),
			"%s uses the next-scroll replacement gate" % profile_id)
		_expect(int(profile.get("normal_track_spawn_level", 0)) == 1 \
			and int(profile.get("commodity_track_spawn_level", 0)) == 1,
			"%s supplies only level-one track instances" % profile_id)
	_expect(profile_ids == [
		SIMULATOR.PROFILE_BASELINE,
		SIMULATOR.PROFILE_FAST,
		SIMULATOR.PROFILE_STRATEGIC,
	], "profile order and IDs are frozen for paired comparison")
	_expect(_unique_count(fingerprints) == 3, "all three profile fingerprints are distinct")
	var errata_variant: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://docs/rules/v071_candidate_errata.json")
	)
	_expect(errata_variant is Dictionary, "candidate Errata profile contract parses")
	if errata_variant is Dictionary:
		var errata_profiles := (
			(errata_variant as Dictionary).get("profiles", []) as Array
		)
		for profile in profiles:
			var documented := _profile_by_id(
				errata_profiles,
				str(profile.get("profile_id", ""))
			)
			_expect(
				str(profile.get("profile_fingerprint_input", ""))
					== str(documented.get("profile_fingerprint_input", ""))
					and str(profile.get("profile_fingerprint", ""))
						== str(documented.get("profile_fingerprint", "")),
				"%s simulation fingerprint matches the Errata machine contract"
					% profile.get("profile_id", "")
			)

	var fast := SIMULATOR.profile_by_id(SIMULATOR.PROFILE_FAST)
	var strategic := SIMULATOR.profile_by_id(SIMULATOR.PROFILE_STRATEGIC)
	_expect(int(fast.get("initial_assets_per_color", 0)) == 2 \
		and int(fast.get("normal_card_ratio_basis_points", 0)) == 6000 \
		and int(fast.get("commodity_card_ratio_basis_points", 0)) == 4000 \
		and int(fast.get("lead_tenure_batches", 0)) == 1,
		"Candidate A exact fast values are stable")
	_expect(int(strategic.get("lead_tenure_batches", 0)) == 2 \
		and int(strategic.get("hand_maintenance_timeout_seconds", 0)) == 8,
		"Candidate B differs only through the strategic two-batch lead tenure")
	var replacement := SIMULATOR.track_replacement_state(12)
	_expect(int(replacement.get("claimable_from_scroll_sequence", 0)) == 13 \
		and not bool(replacement.get("claimable_same_tick", true)),
		"replacement created at scroll 12 is locked until scroll 13")
	var allowed_merge := SIMULATOR.normal_merge_admission(6)
	var rejected_merge := SIMULATOR.normal_merge_admission(5)
	_expect(bool(allowed_merge.get("accepted", false)) \
		and int(allowed_merge.get("result_total_card_count", 0)) == 5,
		"six normal cards may merge down to five")
	_expect(not bool(rejected_merge.get("accepted", true)) \
		and str(rejected_merge.get("reason_code", "")) \
			== "minimum_normal_deck_size_violation",
		"five normal cards cannot merge down to four")
	var allowed_zones := {
		"draw_pile": [{}, {}],
		"hand": [{}, {}],
		"committed_escrow": [{}],
		"discard": [{}],
	}
	var rejected_zones := allowed_zones.duplicate(true)
	(rejected_zones.get("discard", []) as Array).clear()
	rejected_zones["future_supply"] = [{}, {}, {}]
	_expect(
		bool(SIMULATOR.normal_merge_admission_for_zones(allowed_zones).get(
			"accepted",
			false
		)),
		"all four owned normal-card zones admit a six-to-five merge"
	)
	_expect(
		not bool(SIMULATOR.normal_merge_admission_for_zones(rejected_zones).get(
			"accepted",
			true
		)),
		"future supply cannot bypass the five-card owned-zone minimum"
	)
	_expect(
		SIMULATOR.commodity_available_from_batch(7, false) == 7
			and SIMULATOR.commodity_available_from_batch(7, true) == 8,
		"commodity claims are current-batch before lock and next-batch after lock"
	)


func _test_track_replacement_input_matrix() -> void:
	var initial := SIMULATOR.track_replacement_state(12)
	var immediate := SIMULATOR.claim_track_replacement(
		initial,
		12,
		"request.mouse.immediate",
		"mouse"
	)
	_expect(
		not bool(immediate.get("accepted", true))
			and str(immediate.get("reason_code", ""))
				== "replacement_not_yet_claimable",
		"single click cannot claim a same-scroll replacement"
	)
	var immediate_state := immediate.get("state", {}) as Dictionary
	var double_click := SIMULATOR.claim_track_replacement(
		immediate_state,
		12,
		"request.mouse.immediate",
		"mouse"
	)
	_expect(
		double_click.get("receipt_fingerprint")
			== immediate.get("receipt_fingerprint")
			and not bool(double_click.get("accepted", true)),
		"double click replays the same rejection exactly once"
	)
	var high_frame_state := immediate_state.duplicate(true)
	var high_frame_accept_count := 0
	for frame in range(16):
		var attempt := SIMULATOR.claim_track_replacement(
			high_frame_state,
			12,
			"request.frame.%02d" % frame,
			"mouse"
		)
		high_frame_state = (attempt.get("state", {}) as Dictionary).duplicate(true)
		high_frame_accept_count += 1 if bool(attempt.get("accepted", false)) else 0
	_expect(high_frame_accept_count == 0, "high-frame-rate clicks remain locked")
	var keyboard := SIMULATOR.claim_track_replacement(
		high_frame_state,
		12,
		"request.keyboard.same-scroll",
		"keyboard"
	)
	var mouse := SIMULATOR.claim_track_replacement(
		keyboard.get("state", {}) as Dictionary,
		12,
		"request.mouse.same-scroll",
		"mouse"
	)
	_expect(
		not bool(keyboard.get("accepted", true))
			and not bool(mouse.get("accepted", true)),
		"keyboard and mouse submissions cannot bypass the revision lock"
	)
	var restored_locked_state := (
		mouse.get("state", {}) as Dictionary
	).duplicate(true)
	var restored_attempt := SIMULATOR.claim_track_replacement(
		restored_locked_state,
		12,
		"request.restore.same-scroll",
		"touch"
	)
	_expect(
		not bool(restored_attempt.get("accepted", true))
			and bool((restored_attempt.get("state", {}) as Dictionary).get(
				"incoming_locked",
				false
			)),
		"Save/Restore preserves a locked replacement before the next scroll"
	)
	var concurrent_state := (
		restored_attempt.get("state", {}) as Dictionary
	).duplicate(true)
	var accepted_count := 0
	var accepted_request_id := ""
	for player_index in range(8):
		var request_id := "request.concurrent.player.%02d" % player_index
		var attempt := SIMULATOR.claim_track_replacement(
			concurrent_state,
			13,
			request_id,
			"concurrent"
		)
		concurrent_state = (attempt.get("state", {}) as Dictionary).duplicate(true)
		if bool(attempt.get("accepted", false)):
			accepted_count += 1
			accepted_request_id = request_id
	_expect(accepted_count == 1, "eight concurrent claims commit exactly once")
	var exact_once := SIMULATOR.claim_track_replacement(
		concurrent_state,
		13,
		accepted_request_id,
		"concurrent"
	)
	_expect(
		bool(exact_once.get("accepted", false))
			and str(exact_once.get("reason_code", "")) == "replacement_claimed"
			and str((exact_once.get("state", {}) as Dictionary).get(
				"claimed_request_id",
				""
			)) == accepted_request_id,
		"the accepted replacement request replays without a second mutation"
	)


func _test_solar_chain_multiplier_once() -> void:
	var probe := SIMULATOR.solar_chain_probe()
	var counts := probe.get("application_count_by_channel", {}) as Dictionary
	var every_channel_once := counts.size() == SIMULATOR.SOLAR_CHANNEL_BASE_RATES.size()
	for channel in counts:
		every_channel_once = every_channel_once and int(counts.get(channel, 0)) == 1
	_expect(
		int(probe.get("dark_throughput", 0)) == 9
			and int(probe.get("sunlit_throughput", 0)) == 18
			and float(probe.get("throughput_ratio", 0.0)) == 2.0,
		"factory-to-market chain doubles throughput without 4x or 8x compounding"
	)
	_expect(
		every_channel_once
			and int(probe.get("maximum_application_count_per_channel", 0)) == 1,
		"solar multiplier is applied exactly once in every declared work-rate channel"
	)


func _test_full_matrix(report: Dictionary) -> void:
	_expect(str(report.get("simulation_id", "")) == SIMULATOR.SIMULATION_ID,
		"report identifies the detached V0.7.1 simulation")
	_expect(bool(report.get("detached_reference_only", false)) \
		and not bool(report.get("production_runtime_connected", true)) \
		and not bool(report.get("production_save_used", true)) \
		and not bool(report.get("production_rng_used", true)),
		"matrix remains detached from production Runtime, Save, and RNG")
	_expect(not bool(report.get("human_fun_proven", true)) \
		and bool(report.get("human_test_still_required", false)),
		"simulation explicitly does not claim human fun")
	_expect(int(report.get("profile_count", 0)) == 3 \
		and report.get("player_counts", []) == [3, 4, 6, 8] \
		and int(report.get("player_count_coverage", 0)) == 4,
		"matrix covers three profiles and 3/4/6/8 players")
	_expect(int(report.get("seed_count_per_configuration", 0)) == 500 \
		and bool(report.get("qualification_seed_floor_met", false)) \
		and int(report.get("configuration_count", 0)) == 12 \
		and int(report.get("total_match_count", 0)) == 6000,
		"matrix executes 500 fixed seeds for each of 12 configurations")
	_expect(str(report.get("simulation_agent_policy_id", "")) \
		== SIMULATOR.SIMULATION_AGENT_POLICY_ID,
		"closed heuristic policy ID is included")
	_expect(_is_lower_hex(str(report.get("report_fingerprint", "")), 64),
		"whole report has a deterministic SHA-256 fingerprint")

	var configurations := report.get("configuration_results", []) as Array
	_expect(configurations.size() == 12, "all configuration summaries are retained")
	var configuration_ids: Array[String] = []
	for result_variant in configurations:
		var result := result_variant as Dictionary
		var configuration_id := "%s.%d" % [
			str(result.get("profile_id", "")),
			int(result.get("player_count", 0)),
		]
		configuration_ids.append(configuration_id)
		_expect(bool(result.get("valid", false)) \
			and int(result.get("seed_count", 0)) == 500,
			"%s completes all 500 seeds" % configuration_id)
		_expect(_is_lower_hex(str(result.get("configuration_fingerprint", "")), 64) \
			and _is_lower_hex(str(result.get("run_fingerprint_chain", "")), 64),
			"%s retains configuration and run-chain fingerprints" % configuration_id)
		var replay_identity := result.get("replay_identity", {}) as Dictionary
		_expect(str(replay_identity.get("profile_id", "")) \
			== str(result.get("profile_id", "")) \
			and str(replay_identity.get("profile_fingerprint", "")) \
			== str(result.get("profile_fingerprint", "")) \
			and int(replay_identity.get("seed_count", 0)) == 500,
			"%s replay identity saves the actual profile and seed schedule" % configuration_id)
		var metrics := result.get("metrics", {}) as Dictionary
		for metric_key in SIMULATOR.REQUIRED_METRIC_KEYS:
			_expect(metrics.has(metric_key), "%s emits metric %s" % [configuration_id, metric_key])
		_expect(int(metrics.get("track_replacement_claimable_same_tick_count", -1)) == 0,
			"%s never claims its same-scroll replacement" % configuration_id)
		_expect(int(metrics.get("track_high_level_normal_spawn_count", -1)) == 0 \
			and int(metrics.get("track_high_level_commodity_spawn_count", -1)) == 0,
			"%s track supply contains no high-level spawn" % configuration_id)
		_expect(int(metrics.get("minimum_normal_deck_size_violation_commit_count", -1)) == 0,
			"%s commits no below-five normal-deck merge" % configuration_id)
		_expect(int(metrics.get("solar_multiplier_application_count_per_channel", 0)) == 1 \
			and float(metrics.get("sunlit_chain_throughput_ratio", 0.0)) >= 1.8 \
			and float(metrics.get("sunlit_chain_throughput_ratio", 0.0)) <= 2.2,
			"%s applies solar once per channel and yields near-2x throughput" % configuration_id)
		_expect(result.get("failed_fun_targets") is Array,
			"%s exposes every failed fun target instead of hiding it" % configuration_id)
	_expect(_unique_count(configuration_ids) == 12,
		"profile/player-count configuration identities are unique")

	var profile_results := report.get("profile_results", []) as Array
	_expect(profile_results.size() == 3, "three profile aggregates are emitted")
	for profile_variant in profile_results:
		var profile_result := profile_variant as Dictionary
		_expect(int(profile_result.get("match_count", 0)) == 2000 \
			and int(profile_result.get("configuration_count", 0)) == 4,
			"%s aggregate covers 2,000 matches" % profile_result.get("profile_id", ""))
		_expect(_is_lower_hex(str(profile_result.get("profile_result_fingerprint", "")), 64),
			"%s aggregate has a fingerprint" % profile_result.get("profile_id", ""))
		_expect(profile_result.get("failed_fun_targets") is Array,
			"%s aggregate keeps failed targets" % profile_result.get("profile_id", ""))
	var recommended := report.get("recommended_profile", {}) as Dictionary
	_expect(str(recommended.get("profile_id", "")) in [
		SIMULATOR.PROFILE_FAST,
		SIMULATOR.PROFILE_STRATEGIC,
	], "recommendation selects a candidate, not the frozen baseline")
	_expect(str(recommended.get("selection_policy", "")) \
		== "fewest_failed_targets_then_shortest_victory_tail" \
		and not bool(recommended.get("human_fun_proven", true)),
		"recommendation is deterministic, transparent, and not a human-fun claim")
	_expect(report.get("failed_fun_targets", []) \
		== recommended.get("failed_fun_targets", []),
		"top-level failed targets exactly match the recommended profile")


func _test_deterministic_replay(simulator: RefCounted, report: Dictionary) -> void:
	var fast := SIMULATOR.profile_by_id(SIMULATOR.PROFILE_FAST)
	var first := simulator.call("run_configuration", fast, 4, 500) as Dictionary
	var second := simulator.call("run_configuration", fast, 4, 500) as Dictionary
	_expect(str(first.get("configuration_fingerprint", "")) \
		== str(second.get("configuration_fingerprint", "")) \
		and str(first.get("run_fingerprint_chain", "")) \
		== str(second.get("run_fingerprint_chain", "")),
		"same profile, player count, and 500-seed schedule replay identically")
	var matrix_result := _configuration_result(
		report,
		SIMULATOR.PROFILE_FAST,
		4
	)
	_expect(str(matrix_result.get("configuration_fingerprint", "")) \
		== str(first.get("configuration_fingerprint", "")),
		"standalone replay matches the full-matrix configuration fingerprint")
	var strategic := SIMULATOR.profile_by_id(SIMULATOR.PROFILE_STRATEGIC)
	var different := simulator.call("run_configuration", strategic, 4, 500) as Dictionary
	_expect(str(different.get("configuration_fingerprint", "")) \
		!= str(first.get("configuration_fingerprint", "")),
		"different lead-tenure profile has a distinct deterministic fingerprint")
	_expect(SIMULATOR.fixed_seed_for(4, 0) == 901026424 \
		and SIMULATOR.fixed_seed_for(4, 499) \
			== 901026424 + 499 * 7919,
		"fixed-seed schedule endpoints are exact and profile-independent")


func _print_result_summary(report: Dictionary) -> void:
	for profile_variant in report.get("profile_results", []) as Array:
		var profile := profile_variant as Dictionary
		var metrics := profile.get("metrics", {}) as Dictionary
		var first_chain := metrics.get(
			"first_viable_factory_market_chain_batch", {}
		) as Dictionary
		var normal_draw := metrics.get(
			"normal_purchase_to_first_draw_batches", {}
		) as Dictionary
		var commodity_l2 := metrics.get(
			"commodity_l2_first_time_seconds", {}
		) as Dictionary
		var commodity_l3 := metrics.get(
			"commodity_l3_first_time_seconds", {}
		) as Dictionary
		var tail := metrics.get("victory_pending_tail_seconds", {}) as Dictionary
		var by_count := profile.get("by_player_count", {}) as Dictionary
		var four_metrics := (
			by_count.get("4", {}) as Dictionary
		).get("metrics", {}) as Dictionary
		var eight_metrics := (
			by_count.get("8", {}) as Dictionary
		).get("metrics", {}) as Dictionary
		var four_resolution := four_metrics.get(
			"predicted_resolution_animation_seconds", {}
		) as Dictionary
		var eight_resolution := eight_metrics.get(
			"predicted_resolution_animation_seconds", {}
		) as Dictionary
		print(
			"V071_SIMULATION_PROFILE|id=%s|first_chain_median=%s|first_chain_p95=%s|active_mean=%s|active_p95=%s|normal_draw_median=%s|commodity_l2_median_seconds=%s|commodity_l3_median_seconds=%s|blocked=%s|fizzle=%s|lead_advantage=%s|overflow=%s|maintenance_timeout=%s|merge_accept=%s|lead_inference=%s|four_resolution_p95=%s|eight_resolution_p95=%s|tail_p95_seconds=%s|solar_ratio=%s|failed=%s" % [
				profile.get("profile_id", ""),
				first_chain.get("median", 0),
				first_chain.get("p95", 0),
				metrics.get("average_active_actions_per_player_per_batch", 0),
				metrics.get("p95_active_actions_per_player_per_batch", 0),
				normal_draw.get("median", 0),
				commodity_l2.get("median", 0),
				commodity_l3.get("median", 0),
				metrics.get("zero_asset_blocked_action_rate", 0),
				metrics.get("invalid_target_fizzle_rate", 0),
				metrics.get("lead_track_acquisition_advantage_ratio", 0),
				metrics.get("single_color_asset_overflow_rate", 0),
				metrics.get("maintenance_timeout_rate", 0),
				metrics.get("optional_merge_accept_rate", 0),
				metrics.get("lead_inference_unique_rate", 0),
				four_resolution.get("p95", 0),
				eight_resolution.get("p95", 0),
				tail.get("p95", 0),
				metrics.get("sunlit_chain_throughput_ratio", 0),
				",".join(profile.get("failed_fun_targets", []) as Array),
			]
		)
	print("V071_SIMULATION_RECOMMENDATION|profile=%s|failed=%s|report_fingerprint=%s" % [
		report.get("recommended_profile_id", ""),
		",".join(report.get("failed_fun_targets", []) as Array),
		report.get("report_fingerprint", ""),
	])


func _configuration_result(
	report: Dictionary,
	profile_id: String,
	player_count: int
) -> Dictionary:
	for result_variant in report.get("configuration_results", []) as Array:
		var result := result_variant as Dictionary
		if str(result.get("profile_id", "")) == profile_id \
				and int(result.get("player_count", 0)) == player_count:
			return result
	return {}


func _profile_by_id(profiles: Array, profile_id: String) -> Dictionary:
	for profile_variant in profiles:
		if profile_variant is Dictionary \
				and str((profile_variant as Dictionary).get("profile_id", "")) \
					== profile_id:
			return (profile_variant as Dictionary).duplicate(true)
	return {}


func _has_argument(expected: String) -> bool:
	for arguments in [OS.get_cmdline_user_args(), OS.get_cmdline_args()]:
		for argument in arguments:
			if str(argument) == expected:
				return true
	return false


func _unique_count(values: Array) -> int:
	var unique: Array = []
	for value in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _is_lower_hex(value: String, length: int) -> bool:
	if value.length() != length or value != value.to_lower():
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("V071_DETERMINISTIC_SIMULATOR_TEST: %s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V071_DETERMINISTIC_SIMULATOR_TEST|status=%s|checks=%d|failures=%d" % [
		status,
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		print("V071_DETERMINISTIC_SIMULATOR_TEST|first_failure=%s" % _failures[0])
	quit(_failures.size())
