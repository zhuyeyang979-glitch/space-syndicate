extends SceneTree

const SIMULATOR := preload(
	"res://scripts/v073_simulation/v073_deterministic_contention_simulator.gd"
)
const CORE := preload(
	"res://scripts/v07_semantic/v073_fixed_order_facility_contention_core.gd"
)
const REPORT_PATH := (
	"res://scripts/v073_simulation/v073_simulation_6000_report.json"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	if _has_argument("--parse-only"):
		print("V073_DETERMINISTIC_CONTENTION_SIMULATOR_TEST|status=PARSE_ONLY_PASS")
		quit(0)
		return
	call_deferred("_run")


func _run() -> void:
	_test_profile_contracts()
	_test_core_contract_alignment()
	var simulator := SIMULATOR.new()
	var report := simulator.run_matrix(500)
	_test_matrix(report)
	_test_approved_metrics(report)
	_test_comparison_metrics(report)
	_test_deterministic_replay(simulator, report)
	if _has_argument("--write-report"):
		_write_report(report)
	_print_summary(report)
	_finish()


func _test_profile_contracts() -> void:
	var profiles := SIMULATOR.profiles()
	_expect(profiles.size() == 3, "exactly three contention profiles exist")
	var profile_ids: Array[String] = []
	var fingerprints: Array[String] = []
	for profile in profiles:
		var profile_id := str(profile.get("profile_id", ""))
		var fingerprint_input := str(profile.get("profile_fingerprint_input", ""))
		var profile_fingerprint := str(profile.get("profile_fingerprint", ""))
		profile_ids.append(profile_id)
		fingerprints.append(profile_fingerprint)
		_expect(
			fingerprint_input.sha256_text() == profile_fingerprint,
			"%s fingerprint derives from its exact canonical input" % profile_id
		)
		_expect(
			profile.get("initiative_auction_enabled") == false
				and profile.get("cash_can_change_resolution_order") == false,
			"%s has no initiative auction or cash order mutation" % profile_id
		)
		_expect(
			profile.get("human_fun_proven") == false
				and profile.get("human_test_required") == true,
			"%s remains deterministic evidence, not human fun proof" % profile_id
		)
	_expect(profile_ids == SIMULATOR.PROFILE_IDS, "paired profile ordering is stable")
	_expect(_unique_count(fingerprints) == 3, "profile fingerprints are unique")
	var approved := SIMULATOR.profile_by_id(SIMULATOR.PROFILE_V073_FIXED)
	_expect(
		approved.get("resolution_order_mode") == "fixed_hidden_round_robin"
			and approved.get("resolution_order_source")
				== "frozen_hidden_lead_order_at_batch_lock"
			and approved.get("facility_action_mode_required") == true
			and approved.get("build_slot_contention_fizzle") == true
			and approved.get("generic_target_reselection") == false,
		"approved profile binds fixed order, explicit modes, and contention Fizzle"
	)
	var historical := SIMULATOR.profile_by_id(SIMULATOR.PROFILE_V072_GENERIC)
	_expect(
		historical.get("generic_target_reselection") == true
			and historical.get("profile_status") == "historical_detached_comparison",
		"V0.7.2 generic targeting remains comparison-only"
	)
	var diagnostic := SIMULATOR.profile_by_id(SIMULATOR.PROFILE_V073_HIGH_CONTENTION)
	_expect(
		diagnostic.get("profile_status") == "diagnostic_not_candidate_authority"
			and int(diagnostic.get("hot_target_basis_points", 0))
				> int(approved.get("hot_target_basis_points", 0)),
		"high-contention profile is diagnostic and not candidate authority"
	)


func _test_core_contract_alignment() -> void:
	var contract := CORE.contract_snapshot()
	_expect(
		contract.get("ruleset_id") == "v0.7.3"
			and contract.get("resolution_order_mode") == "fixed_hidden_round_robin"
			and contract.get("resolution_order_source")
				== "frozen_hidden_lead_order_at_batch_lock",
		"simulator targets the detached Core fixed-order contract"
	)
	_expect(
		contract.get("maximum_actions_per_player")
			== SIMULATOR.MAX_ACTIONS_PER_PLAYER
			and contract.get("facility_slot_key_fields")
				== ["region_id", "facility_type", "industry_id"],
		"simulator queue bound and unique slot key match Core"
	)
	_expect(
		contract.get("initiative_auction_core_count") == 0
			and contract.get("initiative_bid_save_field_count") == 0
			and contract.get("initiative_bid_ui_surface_count") == 0
			and contract.get("ai_initiative_bid_policy_count") == 0,
		"Core exposes zero auction surfaces across all detached domains"
	)
	var source := FileAccess.get_file_as_string(
		"res://scripts/v073_simulation/v073_deterministic_contention_simulator.gd"
	)
	for forbidden in [
		"res://scenes/main.tscn",
		"res://scripts/main.gd",
		"GameRuntimeCoordinator",
		"V06SaveOwnerRegistry",
		"RandomNumberGenerator",
		"InitiativeBidIntent",
		"V073InitiativeAuctionCore",
	]:
		_expect(not source.contains(forbidden), "simulator excludes %s" % forbidden)


func _test_matrix(report: Dictionary) -> void:
	_expect(
		int(report.get("profile_count", 0)) == 3
			and int(report.get("player_count_coverage", 0)) == 4
			and report.get("player_counts") == [3, 4, 6, 8],
		"matrix covers three profiles and all four player counts"
	)
	_expect(
		int(report.get("seed_count_per_configuration", 0)) == 500
			and bool(report.get("qualification_seed_floor_met", false))
			and int(report.get("configuration_count", 0)) == 12
			and int(report.get("total_match_count", 0)) == 6000,
		"matrix retains 500 seeds per configuration and 6000 matches"
	)
	_expect(
		report.get("detached_reference_only") == true
			and report.get("production_runtime_connected") == false
			and int(report.get("production_connection_count", -1)) == 0
			and int(report.get("v06_mutation_count", -1)) == 0
			and int(report.get("dual_write_count", -1)) == 0,
		"simulation remains detached with zero production or V0.6 mutation"
	)
	_expect(
		int(report.get("initiative_auction_core_count", -1)) == 0
			and int(report.get("initiative_bid_save_field_count", -1)) == 0
			and int(report.get("initiative_bid_ui_surface_count", -1)) == 0
			and int(report.get("ai_initiative_bid_policy_count", -1)) == 0,
		"report retains zero auction Core, Save, UI, and AI counts"
	)
	_expect(
		report.get("human_fun_proven") == false
			and report.get("human_test_required") == true,
		"6000 matches do not claim human fun"
	)
	_expect(_is_lower_hex(str(report.get("report_fingerprint", "")), 64),
		"report has a stable SHA-256 fingerprint")
	var configuration_ids: Array[String] = []
	for result_variant in report.get("configuration_results", []) as Array:
		var result := result_variant as Dictionary
		configuration_ids.append(str(result.get("configuration_id", "")))
		_expect(
			result.get("valid") == true
				and int(result.get("match_count", 0)) == 500
				and int(result.get("seed_count", 0)) == 500,
			"%s contains exactly 500 deterministic matches" % result.get(
				"configuration_id",
				""
			)
		)
		var metrics := result.get("metrics", {}) as Dictionary
		for metric_key in SIMULATOR.REQUIRED_METRIC_KEYS:
			_expect(
				metrics.has(metric_key),
				"%s emits %s" % [result.get("configuration_id", ""), metric_key]
			)
		_expect(
			float(metrics.get("anonymous_owner_direct_disclosure_rate", 1.0)) == 0.0,
			"%s directly discloses no anonymous queue owner" % result.get(
				"configuration_id",
				""
			)
		)
	_expect(_unique_count(configuration_ids) == 12, "configuration identities are unique")
	for profile_variant in report.get("profile_results", []) as Array:
		var profile := profile_variant as Dictionary
		_expect(
			int(profile.get("match_count", 0)) == 2000
				and int(profile.get("configuration_count", 0)) == 4
				and _is_lower_hex(str(profile.get("profile_result_fingerprint", "")), 64),
			"%s aggregate covers 2000 matches" % profile.get("profile_id", "")
		)


func _test_approved_metrics(report: Dictionary) -> void:
	var approved := _profile_result(report, SIMULATOR.PROFILE_V073_FIXED)
	var metrics := approved.get("metrics", {}) as Dictionary
	var fizzle_rate := float(metrics.get("facility_build_fizzle_rate", -1.0))
	_expect(
		fizzle_rate >= 0.03 and fizzle_rate <= 0.15
			or not (approved.get("failed_balance_targets", []) as Array).is_empty(),
		"approved Fizzle rate is in the 3%-15% sample band or explicitly registered"
	)
	_expect(
		int(metrics.get("facility_build_attempt_count", 0)) > 0
			and int(metrics.get("facility_build_success_count", 0)) > 0
			and int(metrics.get("card_discarded_on_contention", 0)) > 0
			and int(metrics.get("asset_refunded_on_contention", 0)) > 0,
		"approved profile exercises builds, successes, discards, and real refunds"
	)
	_expect(
		int(metrics.get("build_to_upgrade_auto_conversion_count", -1)) == 0
			and int(metrics.get("build_to_repair_auto_conversion_count", -1)) == 0
			and int(metrics.get("target_reselected_during_resolution_count", -1)) == 0
			and int(metrics.get("action_slot_refunded_on_contention", -1)) == 0,
		"approved contention never converts, reselects, or refunds action slots"
	)
	var rates_by_players := metrics.get("fizzle_rate_by_player_count", {}) as Dictionary
	_expect(
		rates_by_players.keys().size() == 4
			and rates_by_players.has("3")
			and rates_by_players.has("4")
			and rates_by_players.has("6")
			and rates_by_players.has("8"),
		"approved profile reports Fizzle separately for every player count"
	)
	var rates_by_index := metrics.get("fizzle_rate_by_local_action_index", {}) as Dictionary
	_expect(
		rates_by_index.keys().size() == 5
			and rates_by_index.has("0")
			and rates_by_index.has("2")
			and rates_by_index.has("4"),
		"approved profile reports every local action layer"
	)
	_expect(
		float(metrics.get("critical_build_local_index_0_success_rate", 0.0))
			>= float(metrics.get("critical_build_local_index_2_success_rate", 1.0))
			and float(metrics.get("critical_build_local_index_2_success_rate", 0.0))
				>= float(metrics.get("critical_build_local_index_4_success_rate", 1.0)),
		"earlier local placement weakly improves critical build success"
	)
	_expect(
		float(metrics.get("anonymous_owner_direct_disclosure_rate", 1.0)) == 0.0,
		"approved anonymous public history has zero direct owner disclosure"
	)
	_expect(
		float(metrics.get("starter_action_share_batch_10", -1.0)) >= 0.0
			and float(metrics.get("starter_action_share_batch_10", 2.0)) <= 1.0
			and float(metrics.get("resolution_p95_seconds", 0.0)) > 0.0,
		"late Starter share and resolution p95 are bounded metrics"
	)


func _test_comparison_metrics(report: Dictionary) -> void:
	var historical := _profile_result(report, SIMULATOR.PROFILE_V072_GENERIC)
	var approved := _profile_result(report, SIMULATOR.PROFILE_V073_FIXED)
	var diagnostic := _profile_result(report, SIMULATOR.PROFILE_V073_HIGH_CONTENTION)
	var historical_metrics := historical.get("metrics", {}) as Dictionary
	var approved_metrics := approved.get("metrics", {}) as Dictionary
	var diagnostic_metrics := diagnostic.get("metrics", {}) as Dictionary
	_expect(
		int(historical_metrics.get("target_reselected_during_resolution_count", 0)) > 0
			and float(historical_metrics.get("facility_build_fizzle_rate", 1.0))
				< float(approved_metrics.get("facility_build_fizzle_rate", 0.0)),
		"historical generic comparison exposes its hidden retargeting difference"
	)
	_expect(
		float(diagnostic_metrics.get("facility_slot_collision_rate", 0.0))
			> float(approved_metrics.get("facility_slot_collision_rate", 1.0))
			and float(diagnostic_metrics.get("facility_build_fizzle_rate", 0.0))
				> float(approved_metrics.get("facility_build_fizzle_rate", 1.0)),
		"high-contention diagnostic produces more collisions and Fizzles"
	)
	_expect(
		int(diagnostic_metrics.get("build_to_upgrade_auto_conversion_count", -1)) == 0
			and int(diagnostic_metrics.get("build_to_repair_auto_conversion_count", -1)) == 0
			and int(diagnostic_metrics.get("target_reselected_during_resolution_count", -1)) == 0,
		"diagnostic pressure does not weaken V0.7.3 locked-mode semantics"
	)


func _test_deterministic_replay(simulator: RefCounted, report: Dictionary) -> void:
	var profile := SIMULATOR.profile_by_id(SIMULATOR.PROFILE_V073_FIXED)
	var first := simulator.call("run_configuration", profile, 4, 50) as Dictionary
	var second := simulator.call("run_configuration", profile, 4, 50) as Dictionary
	_expect(
		first.get("configuration_fingerprint") == second.get("configuration_fingerprint")
			and first.get("run_fingerprint_chain") == second.get("run_fingerprint_chain"),
		"same V0.7.3 profile and seed schedule replay identically"
	)
	var matrix_result := _configuration_result(
		report,
		SIMULATOR.PROFILE_V073_FIXED,
		4
	)
	_expect(
		(matrix_result.get("replay_identity", {}) as Dictionary).get(
			"profile_fingerprint"
		) == profile.get("profile_fingerprint"),
		"full matrix retains approved profile identity"
	)
	_expect(
		SIMULATOR.fixed_seed_for(4, 0) == 901126424
			and SIMULATOR.fixed_seed_for(4, 499) == 901126424 + 499 * 7919,
		"profile-independent seed schedule endpoints are exact"
	)


func _write_report(report: Dictionary) -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	_expect(file != null, "6000-match report output opens")
	if file == null:
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	var retained_variant: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(REPORT_PATH)
	)
	_expect(
		retained_variant is Dictionary
			and (retained_variant as Dictionary).get("report_fingerprint")
				== report.get("report_fingerprint"),
		"retained report preserves its raw report fingerprint"
	)


func _print_summary(report: Dictionary) -> void:
	for profile_variant in report.get("profile_results", []) as Array:
		var profile := profile_variant as Dictionary
		var metrics := profile.get("metrics", {}) as Dictionary
		var first_chain := metrics.get("first_factory_market_chain_batch", {}) as Dictionary
		var first_standard := metrics.get("first_standard_l1_play_batch", {}) as Dictionary
		print("V073_SIMULATION_PROFILE|id=%s|collision=%s|build_fizzle=%s|index0_success=%s|index2_success=%s|index4_success=%s|refund=%s|discard=%s|upgrade_conversion=%s|repair_conversion=%s|upgrade_invalid=%s|repair_invalid=%s|repeat_contention=%s|first_chain_median=%s|first_standard_median=%s|starter_share_b10=%s|resolution_p95=%s|owner_disclosure=%s|failed=%s" % [
			profile.get("profile_id", ""),
			metrics.get("facility_slot_collision_rate", 0),
			metrics.get("facility_build_fizzle_rate", 0),
			metrics.get("critical_build_local_index_0_success_rate", 0),
			metrics.get("critical_build_local_index_2_success_rate", 0),
			metrics.get("critical_build_local_index_4_success_rate", 0),
			metrics.get("asset_refunded_on_contention", 0),
			metrics.get("card_discarded_on_contention", 0),
			metrics.get("build_to_upgrade_auto_conversion_count", 0),
			metrics.get("build_to_repair_auto_conversion_count", 0),
			metrics.get("upgrade_target_invalidation_rate", 0),
			metrics.get("repair_target_invalidation_rate", 0),
			metrics.get("repeated_contention_same_slot_rate", 0),
			first_chain.get("median", 0),
			first_standard.get("median", 0),
			metrics.get("starter_action_share_batch_10", 0),
			metrics.get("resolution_p95_seconds", 0),
			metrics.get("anonymous_owner_direct_disclosure_rate", 0),
			",".join(profile.get("failed_balance_targets", []) as Array),
		])
	print("V073_SIMULATION_REPORT|matches=%s|approved=%s|failed=%s|report_fingerprint=%s" % [
		report.get("total_match_count", 0),
		report.get("approved_profile_id", ""),
		",".join(report.get("approved_profile_failed_balance_targets", []) as Array),
		report.get("report_fingerprint", ""),
	])


func _profile_result(report: Dictionary, profile_id: String) -> Dictionary:
	for result_variant in report.get("profile_results", []) as Array:
		var result := result_variant as Dictionary
		if result.get("profile_id") == profile_id:
			return result
	return {}


func _configuration_result(
	report: Dictionary,
	profile_id: String,
	player_count: int
) -> Dictionary:
	for result_variant in report.get("configuration_results", []) as Array:
		var result := result_variant as Dictionary
		if result.get("profile_id") == profile_id \
				and int(result.get("player_count", 0)) == player_count:
			return result
	return {}


func _has_argument(expected: String) -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument == expected:
			return true
	return false


func _unique_count(values: Array[String]) -> int:
	var unique: Array[String] = []
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
	push_error("V073_DETERMINISTIC_CONTENTION_SIMULATOR_TEST: %s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V073_DETERMINISTIC_CONTENTION_SIMULATOR_TEST|status=%s|checks=%d|failures=%d" % [
		status,
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		print("V073_DETERMINISTIC_CONTENTION_SIMULATOR_TEST|first_failure=%s" % _failures[0])
	quit(_failures.size())
