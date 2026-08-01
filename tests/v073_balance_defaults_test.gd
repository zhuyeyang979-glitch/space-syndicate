extends SceneTree

const DEFAULTS_PATH := "res://docs/rules/v073_balance_defaults.json"
const V072_DEFAULTS_PATH := "res://docs/rules/v072_balance_defaults.json"
const PROFILE_ID := "V073_STARTER_FREE_FIXED_ORDER_CONTENTION"
const PROFILE_INPUT := "V073_STARTER_FREE_FIXED_ORDER_CONTENTION|initial_assets_per_color=0|starter_asset_cost=0|standard_l1_asset_cost=1|normal_card_ratio_bps=6000|commodity_card_ratio_bps=4000|intervention_cap_bps=1200|max_asset_refresh_per_color_per_batch=3|hand_maintenance_timeout_seconds=8|lead_tenure_batches=1|color_cycle_batches=6|track_scroll_interval_seconds=5|track_local_visible_slot_count=5|resolution_order_mode=fixed_hidden_round_robin|facility_action_mode_required=true|build_slot_contention_fizzle=true|initiative_bid_mode=retired"
const PROFILE_FINGERPRINT := "a413ad0ddd8a06b15ccee943d9cd93c6f7941fc66ce901a1f44934797f50231c"
const V072_DEFAULTS_SHA256 := "91a9ee9bdc796013e4ac64d2ce9893267f65ce285b22551963371be610d67155"

const DEFAULT_IDS := [
	"v073.balance.initial_assets_per_color",
	"v073.balance.starter_asset_cost",
	"v073.balance.standard_l1_asset_cost",
	"v073.balance.normal_card_ratio_bps",
	"v073.balance.commodity_card_ratio_bps",
	"v073.balance.intervention_cap_bps",
	"v073.balance.max_asset_refresh_per_color_per_batch",
	"v073.balance.hand_maintenance_timeout_seconds",
	"v073.balance.lead_tenure_batches",
	"v073.balance.color_cycle_batches",
	"v073.balance.track_scroll_interval_seconds",
	"v073.balance.track_local_visible_slot_count",
	"v073.balance.resolution_order_mode",
	"v073.balance.facility_action_mode_required",
	"v073.balance.build_slot_contention_fizzle",
]

const STRUCTURAL_IDS := [
	"v073.balance.initial_assets_per_color",
	"v073.balance.starter_asset_cost",
	"v073.balance.standard_l1_asset_cost",
	"v073.balance.resolution_order_mode",
	"v073.balance.facility_action_mode_required",
	"v073.balance.build_slot_contention_fizzle",
]

const TUNABLE_IDS := [
	"v073.balance.normal_card_ratio_bps",
	"v073.balance.commodity_card_ratio_bps",
	"v073.balance.intervention_cap_bps",
	"v073.balance.max_asset_refresh_per_color_per_batch",
	"v073.balance.hand_maintenance_timeout_seconds",
	"v073.balance.lead_tenure_batches",
	"v073.balance.color_cycle_batches",
	"v073.balance.track_scroll_interval_seconds",
	"v073.balance.track_local_visible_slot_count",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var document := _read_json(DEFAULTS_PATH)
	_expect(not document.is_empty(), "V0.7.3 balance defaults parse")
	_expect(str(document.get("defaults_id", "")) == "space_syndicate.v073.balance_defaults.first_human_sample", "defaults ID is exact")
	_expect(str(document.get("ruleset_id", "")) == "v0.7.3", "defaults target V0.7.3")
	_expect(str(document.get("status", "")) == "frozen_first_human_test_sample_defaults_not_final_commercial_balance", "defaults remain first-sample, not final commercial balance")

	_test_source_and_profile(document)
	var by_id := _test_defaults(document)
	_test_inherited_values(document, by_id)
	_test_structural_values(document, by_id)
	_test_auction_absence(document)
	_test_time_simulation_and_history(document)
	_finish()


func _test_source_and_profile(document: Dictionary) -> void:
	var source: Dictionary = document.get("source_defaults", {})
	_expect(str(source.get("ruleset_id", "")) == "v0.7.2", "defaults inherit V0.7.2")
	_expect(str(source.get("path", "")) == "docs/rules/v072_balance_defaults.json", "source path is exact")
	_expect(str(source.get("sha256", "")) == V072_DEFAULTS_SHA256, "source hash is pinned")
	_expect(int(source.get("content_change_count", -1)) == 0, "V0.7.2 defaults change count is zero")
	_expect(_file_sha256(V072_DEFAULTS_PATH) == V072_DEFAULTS_SHA256, "V0.7.2 defaults remain byte-identical")

	var profile: Dictionary = document.get("profile", {})
	_expect(str(profile.get("profile_id", "")) == PROFILE_ID, "profile ID is exact")
	_expect(str(profile.get("profile_fingerprint_input", "")) == PROFILE_INPUT, "canonical profile input is byte-exact")
	_expect(str(profile.get("profile_fingerprint", "")) == PROFILE_FINGERPRINT, "stored profile fingerprint is exact")
	_expect(PROFILE_INPUT.sha256_text().to_lower() == PROFILE_FINGERPRINT, "profile fingerprint recomputes")
	_expect(str(profile.get("profile_fingerprint_input", "")).sha256_text().to_lower() == PROFILE_FINGERPRINT, "stored input recomputes to stored fingerprint")
	_expect(not bool(profile.get("human_fun_proven", true)) and bool(profile.get("human_test_required", false)), "profile does not claim human fun")
	_expect(not bool(profile.get("locale_ui_or_player_count_may_silently_change_profile", true)), "profile cannot change silently")
	_expect(bool(profile.get("save_and_replay_must_persist_profile", false)), "Save and replay persist the profile")


func _test_defaults(document: Dictionary) -> Dictionary:
	var defaults: Array = document.get("defaults", [])
	_expect(defaults.size() == 15, "there are fifteen profile-bound defaults")
	var by_id: Dictionary = {}
	var actual_ids: Array[String] = []
	for entry_variant in defaults:
		_expect(entry_variant is Dictionary, "every default is an object")
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var default_id := str(entry.get("default_id", ""))
		actual_ids.append(default_id)
		_expect(default_id.begins_with("v073.balance.") and not by_id.has(default_id), "%s is a unique V0.7.3 default" % default_id)
		by_id[default_id] = entry
		_expect(entry.has("value"), "%s declares a value" % default_id)
		_expect(not str(entry.get("unit", "")).is_empty(), "%s declares a unit" % default_id)
		_expect(not str(entry.get("constitutional_anchor", "")).is_empty(), "%s cites authority" % default_id)
	_expect(actual_ids == DEFAULT_IDS, "default IDs are closed, exact, and ordered")
	_expect(document.get("approved_default_ids", []) == DEFAULT_IDS, "approved default IDs match the closed list")
	_expect(document.get("frozen_structural_default_ids", []) == STRUCTURAL_IDS, "six structural defaults are exact")
	_expect(document.get("approved_tunable_default_ids", []) == TUNABLE_IDS, "nine tunable defaults are exact")
	for default_id in STRUCTURAL_IDS:
		var entry: Dictionary = by_id.get(default_id, {})
		_expect(not bool(entry.get("balance_tunable", true)) and bool(entry.get("constitutional", false)), "%s is structural" % default_id)
	for default_id in TUNABLE_IDS:
		var entry: Dictionary = by_id.get(default_id, {})
		_expect(bool(entry.get("balance_tunable", false)) and not bool(entry.get("constitutional", true)), "%s remains tunable" % default_id)
	return by_id


func _test_inherited_values(document: Dictionary, by_id: Dictionary) -> void:
	var inherited: Dictionary = document.get("inherited_v072_parameters", {})
	var expected := {
		"initial_assets_per_color": 0,
		"starter_asset_cost": 0,
		"standard_l1_asset_cost": 1,
		"normal_card_ratio_bps": 6000,
		"commodity_card_ratio_bps": 4000,
		"intervention_cap_enabled": true,
		"intervention_cap_bps": 1200,
		"max_asset_refresh_per_color_per_batch": 3,
		"hand_maintenance_timeout_seconds": 8,
		"lead_tenure_batches": 1,
		"color_cycle_batches": 6,
		"track_scroll_interval_seconds": 5,
		"track_local_visible_slot_count": 5,
	}
	_expect(_exact_fields(inherited, expected.keys()), "inherited parameter object is closed")
	for field in expected:
		_expect(inherited.get(field) == expected[field], "%s preserves the V0.7.2 value" % field)

	_expect(int(_value(by_id, "v073.balance.initial_assets_per_color")) == 0, "initial assets remain zero")
	_expect(int(_value(by_id, "v073.balance.starter_asset_cost")) == 0, "Starter asset cost remains zero")
	_expect(int(_value(by_id, "v073.balance.standard_l1_asset_cost")) == 1, "standard L1 cost remains one")
	_expect(int(_value(by_id, "v073.balance.normal_card_ratio_bps")) == 6000, "normal ratio remains 6000")
	_expect(int(_value(by_id, "v073.balance.commodity_card_ratio_bps")) == 4000, "commodity ratio remains 4000")
	_expect(int(_value(by_id, "v073.balance.intervention_cap_bps")) == 1200, "intervention cap remains 1200")
	_expect(int(_value(by_id, "v073.balance.max_asset_refresh_per_color_per_batch")) == 3, "asset refresh cap remains three")
	_expect(int(_value(by_id, "v073.balance.hand_maintenance_timeout_seconds")) == 8, "maintenance remains eight seconds")
	_expect(int(_value(by_id, "v073.balance.lead_tenure_batches")) == 1, "lead tenure remains one batch")
	_expect(int(_value(by_id, "v073.balance.color_cycle_batches")) == 6, "color cycle remains six batches")
	_expect(int(_value(by_id, "v073.balance.track_scroll_interval_seconds")) == 5, "track scroll remains five seconds")
	_expect(int(_value(by_id, "v073.balance.track_local_visible_slot_count")) == 5, "local visible slots remain five")


func _test_structural_values(document: Dictionary, by_id: Dictionary) -> void:
	var structural: Dictionary = document.get("structural_configuration", {})
	_expect(str(structural.get("resolution_order_mode", "")) == "fixed_hidden_round_robin", "resolution order mode is fixed hidden round robin")
	_expect(str(structural.get("resolution_order_source", "")) == "frozen_hidden_lead_order_at_batch_lock", "resolution order source is exact")
	_expect(bool(structural.get("facility_action_mode_required", false)), "facility action mode is required")
	_expect(structural.get("allowed_facility_action_modes", []) == ["BUILD_NEW", "UPGRADE_OWN", "REPAIR_OWN"], "facility modes are exact")
	_expect(bool(structural.get("build_slot_contention_fizzle", false)), "build contention Fizzle is enabled")
	_expect(str(structural.get("invalid_target_policy_id", "")) == "FIZZLE_FULL_ASSET_REFUND", "contention uses full-refund Fizzle")
	_expect(not bool(structural.get("initiative_auction_enabled", true)) and not bool(structural.get("cash_can_change_resolution_order", true)), "auction and cash order changes are disabled")
	_expect(str(_value(by_id, "v073.balance.resolution_order_mode")) == "fixed_hidden_round_robin", "default resolution mode is exact")
	_expect(bool(_value(by_id, "v073.balance.facility_action_mode_required")), "default requires facility mode")
	_expect(bool(_value(by_id, "v073.balance.build_slot_contention_fizzle")), "default enables contention Fizzle")


func _test_auction_absence(document: Dictionary) -> void:
	var retired: Dictionary = document.get("retired_auction_configuration", {})
	_expect(str(retired.get("initiative_bid_max_cash", "")) == "not_applicable", "initiative bid max cash is not applicable")
	_expect(str(retired.get("initiative_bid_mode", "")) == "retired", "initiative bid mode is retired")
	for field in ["runtime_parameter_count", "save_field_count", "ui_surface_count", "ai_policy_count"]:
		_expect(int(retired.get(field, -1)) == 0, "%s is zero" % field)
	for entry_variant in document.get("defaults", []):
		if entry_variant is Dictionary:
			var default_id := str((entry_variant as Dictionary).get("default_id", ""))
			_expect(default_id.find("bid") == -1 and default_id.find("auction") == -1, "%s is not an auction default" % default_id)


func _test_time_simulation_and_history(document: Dictionary) -> void:
	var time: Dictionary = document.get("time_authorities", {})
	_expect(int((time.get("lead", {}) as Dictionary).get("authority_count", 0)) == 1, "lead has one authority")
	_expect(int((time.get("color_cycle", {}) as Dictionary).get("authority_count", 0)) == 1, "color cycle has one authority")
	var order: Dictionary = time.get("batch_resolution_order", {})
	_expect(int(order.get("authority_count", 0)) == 1 and int(order.get("cash_modifier_count", -1)) == 0, "batch order has one authority and no cash modifier")
	_expect(not bool(time.get("ui_timer_may_drive_core", true)), "UI timer cannot drive Core")

	var simulation: Dictionary = document.get("simulation_sample", {})
	_expect(int(simulation.get("minimum_match_count", 0)) == 6000, "simulation minimum is 6000")
	var player_counts: Array = simulation.get("player_counts", [])
	_expect(player_counts.size() == 4 and int(player_counts[0]) == 3 and int(player_counts[1]) == 4 and int(player_counts[2]) == 6 and int(player_counts[3]) == 8, "simulation covers 3/4/6/8 players")
	_expect(int(simulation.get("seeds_per_configuration", 0)) == 500, "simulation uses 500 seeds per configuration")
	_expect(float(simulation.get("facility_build_fizzle_rate_recommended_minimum", 0.0)) == 0.03 and float(simulation.get("facility_build_fizzle_rate_recommended_maximum", 0.0)) == 0.15, "recommended Fizzle range is 3% to 15%")
	_expect(not bool(simulation.get("auction_tuning_allowed", true)), "auction cannot tune contention rate")
	_expect(not bool(simulation.get("human_fun_proven", true)) and bool(simulation.get("human_test_required", false)), "simulation cannot prove human fun")

	var historical: Array = document.get("historical_profiles", [])
	_expect(historical.size() == 2, "V0.7.2 and V0.7.1 profiles remain historical")
	_expect(str((historical[0] as Dictionary).get("profile_id", "")) == "V072_STARTER_FREE_FAST", "V0.7.2 profile is retained")
	for profile_variant in historical:
		var profile := profile_variant as Dictionary
		_expect(not bool(profile.get("runtime_authority_for_v073", true)) and bool(profile.get("retained_for_comparison", false)), "%s is comparison-only" % str(profile.get("profile_id", "")))


func _value(by_id: Dictionary, default_id: String) -> Variant:
	var entry: Dictionary = by_id.get(default_id, {})
	return entry.get("value")


func _exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _file_sha256(path: String) -> String:
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if hashing.update(FileAccess.get_file_as_bytes(path)) != OK:
		return ""
	return hashing.finish().hex_encode().to_lower()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("V073_BALANCE_DEFAULTS_TEST|status=%s|checks=%d|failures=%d|default_count=15|structural_default_count=6|tunable_default_count=9|auction_runtime_parameter_count=0|profile_id=%s|profile_fingerprint=%s|human_fun_proven=false|details=%s" % [
		"PASS" if passed else "FAIL", _checks, _failures.size(), PROFILE_ID, PROFILE_FINGERPRINT, JSON.stringify(_failures)
	])
	quit(0 if passed else 1)
