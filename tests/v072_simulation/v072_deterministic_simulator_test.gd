extends SceneTree

const SIMULATOR := preload(
	"res://scripts/v072_simulation/v072_deterministic_simulator.gd"
)
const REPORT_PATH := (
	"res://scripts/v072_simulation/v072_simulation_6000_report.json"
)
const EXPECTED_STARTER_IDS := [
	"starter.facility.factory.life.rank_1",
	"starter.facility.market.life.rank_1",
	"starter.facility.factory.energy.rank_1",
	"starter.facility.market.energy.rank_1",
	"starter.facility.factory.industry.rank_1",
	"starter.facility.market.industry.rank_1",
	"starter.facility.factory.technology.rank_1",
	"starter.facility.market.technology.rank_1",
	"starter.facility.factory.commerce.rank_1",
	"starter.facility.market.commerce.rank_1",
	"starter.facility.factory.shipping.rank_1",
	"starter.facility.market.shipping.rank_1",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	if _has_argument("--parse-only"):
		print("V072_DETERMINISTIC_SIMULATOR_TEST|status=PARSE_ONLY_PASS")
		quit(0)
		return
	call_deferred("_run")


func _run() -> void:
	_test_profiles()
	_test_starter_definition_contract()
	_test_starter_lifecycle_and_merge()
	_test_solar_probe()
	var simulator := SIMULATOR.new()
	var report := simulator.run_matrix(500)
	_test_matrix(report)
	_test_deterministic_replay(simulator, report)
	if _has_argument("--write-report"):
		_write_report(report)
	_print_summary(report)
	_finish()


func _test_profiles() -> void:
	var profiles := SIMULATOR.profiles()
	_expect(profiles.size() == 3, "exactly three paired comparison profiles exist")
	var ids: Array[String] = []
	var fingerprints: Array[String] = []
	for profile in profiles:
		var profile_id := str(profile.get("profile_id", ""))
		var input := str(profile.get("profile_fingerprint_input", ""))
		var profile_fingerprint := str(profile.get("profile_fingerprint", ""))
		ids.append(profile_id)
		fingerprints.append(profile_fingerprint)
		_expect(input.sha256_text() == profile_fingerprint,
			"%s fingerprint derives from its exact canonical input" % profile_id)
		_expect(int(profile.get("normal_card_ratio_basis_points", 0)) \
			+ int(profile.get("commodity_card_ratio_basis_points", 0)) == 10000,
			"%s track ratio closes at 10000 basis points" % profile_id)
		_expect(not bool(profile.get("human_fun_proven", true)) \
			and bool(profile.get("human_test_required", false)),
			"%s does not claim human fun" % profile_id)
	_expect(ids == [
		SIMULATOR.PROFILE_V071_FAST,
		SIMULATOR.PROFILE_V072_FAST,
		SIMULATOR.PROFILE_V072_NO_CROSS_MERGE,
	], "profile order is stable for paired comparison")
	_expect(_unique_count(fingerprints) == 3,
		"all profile identities are distinct")
	var approved := SIMULATOR.profile_by_id(SIMULATOR.PROFILE_V072_FAST)
	_expect(str(approved.get("profile_fingerprint_input", "")) \
		== SIMULATOR.V072_PROFILE_FINGERPRINT_INPUT,
		"approved V0.7.2 canonical input is exact")
	_expect(str(approved.get("profile_fingerprint", "")) \
		== "b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48",
		"approved V0.7.2 canonical fingerprint is exact")
	_expect(int(approved.get("initial_assets_per_color", -1)) == 0 \
		and int(approved.get("starter_primary_asset_cost", -1)) == 0 \
		and int(approved.get("standard_l1_primary_asset_cost", -1)) == 1 \
		and bool(approved.get("starter_standard_l1_merge_allowed", false)),
		"approved profile binds zero assets, free Starter, paid L1, and cross merge")
	var diagnostic := SIMULATOR.profile_by_id(SIMULATOR.PROFILE_V072_NO_CROSS_MERGE)
	_expect(not bool(diagnostic.get("starter_standard_l1_merge_allowed", true)) \
		and str(diagnostic.get("profile_status", "")) \
			== "diagnostic_not_candidate_authority",
		"no-cross-merge profile remains diagnostic only")


func _test_starter_definition_contract() -> void:
	var definitions := SIMULATOR.starter_definitions()
	_expect(definitions.size() == 12, "Starter registry contains exactly twelve definitions")
	var ids: Array[String] = []
	var factory_count := 0
	var market_count := 0
	for definition in definitions:
		var definition_id := str(definition.get("definition_id", ""))
		ids.append(definition_id)
		factory_count += 1 if str(definition.get("kind", "")) == "factory" else 0
		market_count += 1 if str(definition.get("kind", "")) == "market" else 0
		_expect(str(definition.get("origin_class", "")) == "starter_bootstrap" \
			and int(definition.get("level", 0)) == 1 \
			and str(definition.get("asset_cost_profile", "")) == "starter_zero_asset" \
			and int(definition.get("primary_asset_cost", -1)) == 0 \
			and bool(definition.get("starter_badge", false)) \
			and str(definition.get("starter_badge_asset_key", "")) \
				== "card.badge.starter" \
			and not bool(definition.get("track_spawn_allowed", true)) \
			and not bool(definition.get("purchase_allowed", true)),
			"%s is a closed free Starter definition" % definition_id)
	_expect(ids == EXPECTED_STARTER_IDS,
		"all twelve stable Starter definition IDs and ordering are exact")
	_expect(_unique_count(ids) == 12 and factory_count == 6 and market_count == 6,
		"each Starter definition is unique across six factories and six markets")
	var deck := SIMULATOR.genesis_deck("player.contract", SIMULATOR.PROFILE_V072_FAST)
	var instances: Array[String] = []
	for card in deck:
		instances.append(str(card.get("card_instance_id", "")))
	_expect(deck.size() == 12 and _unique_count(instances) == 12,
		"genesis creates exactly one unique instance of every Starter")
	for color in SIMULATOR.COLORS:
		for kind in ["factory", "market"]:
			var standard := SIMULATOR.standard_definition(color, kind, 1)
			_expect(str(standard.get("origin_class", "")) == "standard" \
				and int(SIMULATOR.asset_cost_for_card(standard)) == 1 \
				and not bool(standard.get("starter_badge", true)) \
				and bool(standard.get("track_spawn_allowed", false)),
				"standard %s %s L1 costs one and is the track definition" % [color, kind])
	for level in [2, 3, 4]:
		var ranked := SIMULATOR.standard_definition("life", "factory", level)
		_expect(int(SIMULATOR.asset_cost_for_card(ranked)) == level \
			and not bool(ranked.get("track_spawn_allowed", true)),
			"standard L%d retains rank cost and cannot spawn directly" % level)


func _test_starter_lifecycle_and_merge() -> void:
	var starter := SIMULATOR.starter_definitions()[0].duplicate(true)
	starter["card_instance_id"] = "starter.lifecycle.001"
	var serialized := JSON.stringify(starter)
	var restored_variant: Variant = JSON.parse_string(serialized)
	_expect(restored_variant is Dictionary,
		"Starter identity survives detached JSON Save-shaped round trip")
	if restored_variant is Dictionary:
		var restored := restored_variant as Dictionary
		_expect(str(restored.get("definition_id", "")) \
			== str(starter.get("definition_id", "")) \
			and str(restored.get("origin_class", "")) == "starter_bootstrap" \
			and str(restored.get("asset_cost_profile", "")) == "starter_zero_asset" \
			and int(SIMULATOR.asset_cost_for_card(restored)) == 0,
			"discard, reshuffle, Save, and Restore cannot remove free Starter identity")
	var standard := SIMULATOR.standard_definition("life", "factory", 1)
	standard["card_instance_id"] = "standard.lifecycle.001"
	var accepted := SIMULATOR.starter_standard_merge(starter, standard, 12, true)
	var output := accepted.get("output", {}) as Dictionary
	_expect(bool(accepted.get("accepted", false)) \
		and str(output.get("definition_id", "")) == "facility.factory.life.rank_2" \
		and str(output.get("origin_class", "")) == "standard" \
		and str(output.get("asset_cost_profile", "")) == "standard_rank_2" \
		and int(SIMULATOR.asset_cost_for_card(output)) == 2 \
		and bool(accepted.get("starter_privilege_consumed", false)),
		"Starter plus matching standard L1 yields paid standard L2")
	_expect((accepted.get("source_definition_ids", []) as Array).size() == 2 \
		and (accepted.get("source_origin_classes", []) as Array) \
			== ["starter_bootstrap", "standard"],
		"merge Receipt retains source identity and privilege consumption")
	var disabled := SIMULATOR.starter_standard_merge(starter, standard, 12, false)
	_expect(not bool(disabled.get("accepted", true)) \
		and str(disabled.get("reason_code", "")) \
			== "starter_standard_merge_disabled",
		"diagnostic profile closes cross merge")
	var wrong_color := SIMULATOR.standard_definition("energy", "factory", 1)
	var mismatch := SIMULATOR.starter_standard_merge(starter, wrong_color, 12, true)
	_expect(not bool(mismatch.get("accepted", true)) \
		and str(mismatch.get("reason_code", "")) \
			== "merge_family_or_origin_mismatch",
		"different-color or different-family merge is rejected")
	var minimum := SIMULATOR.starter_standard_merge(starter, standard, 5, true)
	_expect(not bool(minimum.get("accepted", true)) \
		and str(minimum.get("reason_code", "")) \
			== "minimum_normal_deck_size_violation",
		"Starter cross merge cannot bypass the minimum-five deck rule")


func _test_solar_probe() -> void:
	var probe := SIMULATOR.solar_chain_probe()
	var counts := probe.get("application_count_by_channel", {}) as Dictionary
	var every_channel_once := counts.size() == SIMULATOR.SOLAR_CHANNEL_BASE_RATES.size()
	for channel in counts:
		every_channel_once = every_channel_once and int(counts.get(channel, 0)) == 1
	_expect(int(probe.get("dark_throughput", 0)) == 9 \
		and int(probe.get("sunlit_throughput", 0)) == 18 \
		and float(probe.get("throughput_ratio", 0.0)) == 2.0,
		"sunlit chain throughput remains exactly two times dark throughput")
	_expect(every_channel_once \
		and int(probe.get("maximum_application_count_per_channel", 0)) == 1,
		"solar multiplier applies exactly once per work-rate channel")


func _test_matrix(report: Dictionary) -> void:
	_expect(str(report.get("simulation_id", "")) == SIMULATOR.SIMULATION_ID,
		"report identifies V0.7.2 detached bootstrap simulation")
	_expect(bool(report.get("detached_reference_only", false)) \
		and not bool(report.get("production_runtime_connected", true)) \
		and not bool(report.get("production_save_used", true)) \
		and not bool(report.get("production_rng_used", true)) \
		and int(report.get("new_rng_stream_count", -1)) == 0 \
		and str(report.get("starter_shuffle_stream_id", "")) \
			== "starter_deck_shuffle",
		"simulation remains detached and adds no RNG stream")
	_expect(not bool(report.get("human_fun_proven", true)) \
		and bool(report.get("human_test_required", false)),
		"6000 deterministic matches do not claim human fun")
	_expect(int(report.get("profile_count", 0)) == 3 \
		and report.get("player_counts", []) == [3, 4, 6, 8] \
		and int(report.get("player_count_coverage", 0)) == 4 \
		and int(report.get("seed_count_per_configuration", 0)) == 500 \
		and int(report.get("configuration_count", 0)) == 12 \
		and int(report.get("total_match_count", 0)) == 6000 \
		and bool(report.get("qualification_seed_floor_met", false)),
		"matrix covers 3/4/6/8 players with 500 seeds for 6000 matches")
	_expect(_is_lower_hex(str(report.get("report_fingerprint", "")), 64),
		"whole report has a deterministic SHA-256 fingerprint")
	_expect(str(report.get("approved_profile_id", "")) \
		== SIMULATOR.PROFILE_V072_FAST \
		and str(report.get("approved_profile_fingerprint", "")) \
			== SIMULATOR.V072_PROFILE_FINGERPRINT,
		"report retains approved canonical profile identity")

	var configurations := report.get("configuration_results", []) as Array
	_expect(configurations.size() == 12, "all twelve configuration results are retained")
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
			"%s completes 500 fixed seeds" % configuration_id)
		_expect(_is_lower_hex(str(result.get("configuration_fingerprint", "")), 64) \
			and _is_lower_hex(str(result.get("run_fingerprint_chain", "")), 64),
			"%s retains configuration and run-chain fingerprints" % configuration_id)
		var metrics := result.get("metrics", {}) as Dictionary
		for metric_key in SIMULATOR.REQUIRED_METRIC_KEYS:
			_expect(metrics.has(metric_key),
				"%s emits %s" % [configuration_id, metric_key])
		_expect(int(metrics.get("starter_track_spawn_count", -1)) == 0 \
			and int(metrics.get("starter_creation_after_genesis_count", -1)) == 0 \
			and int(metrics.get("starter_privilege_inheritance_count", -1)) == 0,
			"%s cannot spawn, recreate, or inherit Starter privilege" % configuration_id)
		_expect(float(metrics.get("sunlit_chain_throughput_ratio", 0.0)) == 2.0,
			"%s preserves one-time 2x solar throughput" % configuration_id)
		_expect(result.get("failed_balance_targets") is Array,
			"%s exposes all failed targets" % configuration_id)
	_expect(_unique_count(configuration_ids) == 12,
		"configuration identities are unique")

	var profile_results := report.get("profile_results", []) as Array
	_expect(profile_results.size() == 3,
		"three profile aggregates are retained")
	for row_variant in profile_results:
		var row := row_variant as Dictionary
		_expect(int(row.get("match_count", 0)) == 2000 \
			and int(row.get("configuration_count", 0)) == 4 \
			and _is_lower_hex(str(row.get("profile_result_fingerprint", "")), 64),
			"%s aggregate covers 2000 matches with a fingerprint" % row.get("profile_id", ""))

	var approved := _profile_result(report, SIMULATOR.PROFILE_V072_FAST)
	var approved_metrics := approved.get("metrics", {}) as Dictionary
	var opening_starters := approved_metrics.get("opening_starter_card_count", {}) as Dictionary
	var opening_affordable := approved_metrics.get("opening_asset_affordable_card_count", {}) as Dictionary
	var opening_legal := approved_metrics.get("opening_legal_target_count", {}) as Dictionary
	_expect(float(opening_starters.get("minimum", 0.0)) == 5.0 \
		and float(opening_starters.get("maximum", 0.0)) == 5.0 \
		and float(opening_affordable.get("minimum", 0.0)) == 5.0 \
		and float(opening_affordable.get("maximum", 0.0)) == 5.0 \
		and float(opening_legal.get("minimum", 0.0)) >= 1.0,
		"approved V0.7.2 always opens with five affordable Starter cards and a legal target")
	var first_facility := approved_metrics.get("first_facility_batch", {}) as Dictionary
	var first_refresh := approved_metrics.get("first_nonzero_asset_refresh_batch", {}) as Dictionary
	_expect(float(first_facility.get("median", 999.0)) <= 1.0 \
		and float(first_facility.get("p95", 999.0)) <= 2.0,
		"approved profile establishes its first facility by the opening target")
	_expect(float(first_refresh.get("median", 999.0)) <= 2.0 \
		and float(first_refresh.get("p95", 999.0)) <= 3.0,
		"approved profile reaches its first real nonzero asset refresh on target")
	_expect(float(approved_metrics.get("starter_action_share_batch_10", 1.0)) < 0.70 \
		or (approved.get("failed_balance_targets", []) as Array).has(
			"STARTER_DECK_DOMINATES_LONG_TERM_PLAY"
		), "long-term Starter dominance is either under target or explicitly reported")
	_expect(float(approved_metrics.get("zero_asset_block_rate_standard_cards_only", 1.0)) < 0.15 \
		or (approved.get("failed_balance_targets", []) as Array).has(
			"STANDARD_CARD_ASSET_ECONOMY_TOO_SLOW"
		), "slow standard-card economy is never hidden")

	var no_cross := _profile_result(report, SIMULATOR.PROFILE_V072_NO_CROSS_MERGE)
	var no_cross_metrics := no_cross.get("metrics", {}) as Dictionary
	_expect(float(no_cross_metrics.get("starter_standard_merge_rate", -1.0)) == 0.0 \
		and float(no_cross_metrics.get("starter_privilege_consumed_rate", -1.0)) == 0.0,
		"diagnostic no-cross profile consumes no Starter privilege")
	_expect(float(approved_metrics.get("starter_standard_merge_rate", 0.0)) > 0.0 \
		and float(approved_metrics.get("starter_privilege_consumed_rate", 0.0)) > 0.0,
		"approved profile exercises voluntary Starter-to-standard L2 merge")


func _test_deterministic_replay(simulator: RefCounted, report: Dictionary) -> void:
	var profile := SIMULATOR.profile_by_id(SIMULATOR.PROFILE_V072_FAST)
	var first := simulator.call("run_configuration", profile, 4, 50) as Dictionary
	var second := simulator.call("run_configuration", profile, 4, 50) as Dictionary
	_expect(str(first.get("configuration_fingerprint", "")) \
		== str(second.get("configuration_fingerprint", "")) \
		and str(first.get("run_fingerprint_chain", "")) \
			== str(second.get("run_fingerprint_chain", "")),
		"same V0.7.2 profile and seed schedule replay identically")
	var matrix_result := _configuration_result(
		report,
		SIMULATOR.PROFILE_V072_FAST,
		4
	)
	_expect(str((matrix_result.get("replay_identity", {}) as Dictionary).get(
		"profile_fingerprint",
		""
	)) == SIMULATOR.V072_PROFILE_FINGERPRINT,
		"full matrix replay identity retains the approved fingerprint")
	_expect(SIMULATOR.fixed_seed_for(4, 0) == 901026424 \
		and SIMULATOR.fixed_seed_for(4, 499) == 901026424 + 499 * 7919,
		"profile-independent seed schedule endpoints are exact")


func _write_report(report: Dictionary) -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	_expect(file != null, "6000-match report output opens")
	if file == null:
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	var retained_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string(REPORT_PATH))
	_expect(retained_variant is Dictionary \
		and str((retained_variant as Dictionary).get("report_fingerprint", "")) \
			== str(report.get("report_fingerprint", "")),
		"retained report preserves the raw report fingerprint")


func _print_summary(report: Dictionary) -> void:
	for profile_variant in report.get("profile_results", []) as Array:
		var profile := profile_variant as Dictionary
		var metrics := profile.get("metrics", {}) as Dictionary
		var first_facility := metrics.get("first_facility_batch", {}) as Dictionary
		var first_refresh := metrics.get("first_nonzero_asset_refresh_batch", {}) as Dictionary
		var first_standard := metrics.get("first_standard_l1_played_batch", {}) as Dictionary
		var tail := metrics.get("victory_pending_tail_seconds", {}) as Dictionary
		print("V072_SIMULATION_PROFILE|id=%s|first_facility_median=%s|first_facility_p95=%s|first_refresh_median=%s|first_refresh_p95=%s|first_standard_l1_play_median=%s|starter_share_b1=%s|starter_share_b3=%s|starter_share_b6=%s|starter_share_b10=%s|standard_block=%s|overflow=%s|cross_merge=%s|privilege_consumed=%s|resolution_p95=%s|tail_p95=%s|solar=%s|failed=%s" % [
			profile.get("profile_id", ""),
			first_facility.get("median", 0),
			first_facility.get("p95", 0),
			first_refresh.get("median", 0),
			first_refresh.get("p95", 0),
			first_standard.get("median", 0),
			metrics.get("starter_action_share_batch_1", 0),
			metrics.get("starter_action_share_batch_3", 0),
			metrics.get("starter_action_share_batch_6", 0),
			metrics.get("starter_action_share_batch_10", 0),
			metrics.get("zero_asset_block_rate_standard_cards_only", 0),
			metrics.get("asset_overflow_rate", 0),
			metrics.get("starter_standard_merge_rate", 0),
			metrics.get("starter_privilege_consumed_rate", 0),
			metrics.get("resolution_p95_seconds", 0),
			tail.get("p95", 0),
			metrics.get("sunlit_chain_throughput_ratio", 0),
			",".join(profile.get("failed_balance_targets", []) as Array),
		])
	print("V072_SIMULATION_REPORT|matches=%s|approved=%s|failed=%s|report_fingerprint=%s" % [
		report.get("total_match_count", 0),
		report.get("approved_profile_id", ""),
		",".join(report.get("approved_profile_failed_balance_targets", []) as Array),
		report.get("report_fingerprint", ""),
	])


func _profile_result(report: Dictionary, profile_id: String) -> Dictionary:
	for result_variant in report.get("profile_results", []) as Array:
		var result := result_variant as Dictionary
		if str(result.get("profile_id", "")) == profile_id:
			return result
	return {}


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
	push_error("V072_DETERMINISTIC_SIMULATOR_TEST: %s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V072_DETERMINISTIC_SIMULATOR_TEST|status=%s|checks=%d|failures=%d" % [
		status,
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		print("V072_DETERMINISTIC_SIMULATOR_TEST|first_failure=%s" % _failures[0])
	quit(_failures.size())
