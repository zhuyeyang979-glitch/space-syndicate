extends SceneTree

const DEFAULTS_PATH := "res://docs/rules/v072_balance_defaults.json"
const PROFILE_ID := "V072_STARTER_FREE_FAST"
const PROFILE_FINGERPRINT := "b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48"
const PROFILE_INPUT := "V072_STARTER_FREE_FAST|initial_assets_per_color=0|starter_primary_asset_cost=0|standard_l1_primary_asset_cost=1|normal_card_ratio_basis_points=6000|commodity_card_ratio_basis_points=4000|single_color_net_intervention_cap_enabled=true|single_color_net_intervention_cap_basis_points=1200|max_asset_refresh_per_color_per_batch=3|hand_maintenance_timeout_seconds=8|lead_tenure_batches=1|color_cycle_batches=6"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var document := _read_json(DEFAULTS_PATH)
	_expect(str(document.get("defaults_id", "")) == "space_syndicate.v072.balance_defaults.first_human_sample", "defaults ID is exact")
	_expect(str(document.get("ruleset_id", "")) == "v0.7.2", "defaults target V0.7.2")
	var profile: Dictionary = document.get("profile", {})
	_expect(str(profile.get("profile_id", "")) == PROFILE_ID, "approved profile ID is exact")
	_expect(str(profile.get("profile_fingerprint_input", "")) == PROFILE_INPUT, "stored canonical profile input is byte-exact")
	_expect(str(profile.get("profile_fingerprint", "")) == PROFILE_FINGERPRINT, "stored profile fingerprint is exact")
	_expect(PROFILE_INPUT.sha256_text().to_lower() == PROFILE_FINGERPRINT, "V0.7.2 profile fingerprint recomputes")
	_expect(str(profile.get("profile_fingerprint_input", "")).sha256_text().to_lower() == PROFILE_FINGERPRINT, "stored input recomputes to stored fingerprint")
	_expect(not bool(profile.get("human_fun_proven", true)) and bool(profile.get("human_test_required", false)), "profile does not claim human fun")
	_expect(not bool(profile.get("locale_ui_or_player_count_may_silently_change_profile", true)), "profile cannot change silently")

	var defaults: Array = document.get("defaults", [])
	_expect(defaults.size() == 25, "there are 25 authoritative defaults")
	var by_id: Dictionary = {}
	for entry_variant in defaults:
		_expect(entry_variant is Dictionary, "every default is an object")
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var default_id := str(entry.get("default_id", ""))
		_expect(default_id.begins_with("v072.balance.") and not by_id.has(default_id), "%s is a unique V0.7.2 default" % default_id)
		by_id[default_id] = entry
		_expect(not str(entry.get("unit", "")).is_empty(), "%s declares a unit" % default_id)
		_expect(not str(entry.get("constitutional_anchor", "")).is_empty(), "%s cites a constitutional anchor" % default_id)

	_expect(int(_value(by_id, "v072.balance.initial_assets_per_color")) == 0, "initial assets are zero")
	_expect(int(_value(by_id, "v072.balance.starter_primary_asset_cost")) == 0, "Starter primary asset cost is zero")
	_expect(int(_value(by_id, "v072.balance.standard_l1_primary_asset_cost")) == 1, "standard L1 primary asset cost is one")
	_expect(int(_value(by_id, "v072.balance.level_2_primary_asset_cost")) == 2, "standard L2 cost is two")
	_expect(int(_value(by_id, "v072.balance.level_3_primary_asset_cost")) == 3, "standard L3 cost is three")
	_expect(int(_value(by_id, "v072.balance.level_4_primary_asset_cost")) == 4, "standard L4 cost is four")
	_expect(not by_id.has("v072.balance.level_1_primary_asset_cost"), "ambiguous origin-free L1 cost is retired")
	_expect(not by_id.has("v072.balance.starter_card_setup_cost_exemption"), "one-time Starter setup exemption is retired")

	for structural_id in document.get("frozen_structural_default_ids", []):
		var entry: Dictionary = by_id.get(str(structural_id), {})
		_expect(not bool(entry.get("balance_tunable", true)) and bool(entry.get("constitutional", false)), "%s is frozen structural authority" % str(structural_id))
	for tunable_id in document.get("approved_tunable_default_ids", []):
		var entry: Dictionary = by_id.get(str(tunable_id), {})
		_expect(bool(entry.get("balance_tunable", false)) and not bool(entry.get("constitutional", true)), "%s remains a tunable first-sample default" % str(tunable_id))

	_expect(int(_value(by_id, "v072.balance.track_normal_card_ratio_basis_points")) == 6000, "normal ratio is 6000")
	_expect(int(_value(by_id, "v072.balance.track_commodity_card_ratio_basis_points")) == 4000, "commodity ratio is 4000")
	var cap: Dictionary = _value(by_id, "v072.balance.single_color_net_intervention_cap") as Dictionary
	_expect(bool(cap.get("enabled", false)) and int(cap.get("absolute_basis_points", 0)) == 1200, "intervention cap is enabled at 1200 bps")
	_expect(int(_value(by_id, "v072.balance.max_asset_refresh_per_color_per_batch")) == 3, "refresh cap is three")
	_expect(int(_value(by_id, "v072.balance.hand_maintenance_timeout_seconds")) == 8, "maintenance timeout is eight seconds")
	_expect(int(_value(by_id, "v072.balance.lead_tenure_batches")) == 1, "lead tenure is one batch")
	_expect(int(_value(by_id, "v072.balance.color_cycle_batches")) == 6, "color cycle is six batches")
	_expect(int(_value(by_id, "v072.balance.track_scroll_interval_seconds")) == 5, "track scroll remains five seconds")
	_expect(int(_value(by_id, "v072.balance.track_local_visible_slot_count")) == 5, "local visible slots remain five")

	var approved: Array = document.get("approved_default_ids", [])
	_expect(approved.size() == 10, "ten profile-bound approved defaults are explicit")
	_expect((document.get("frozen_structural_default_ids", []) as Array).size() == 3, "three Starter-bootstrap defaults are constitutional")
	_expect((document.get("approved_tunable_default_ids", []) as Array).size() == 7, "seven inherited Candidate A values remain tunable")
	for default_id in approved:
		_expect(by_id.has(str(default_id)), "%s resolves to one default" % str(default_id))

	var time: Dictionary = document.get("runtime_time_authorities", {})
	_expect(int((time.get("lead", {}) as Dictionary).get("authority_count", 0)) == 1, "lead has one time authority")
	_expect(int((time.get("color_cycle", {}) as Dictionary).get("authority_count", 0)) == 1, "color cycle has one time authority")
	_expect(not bool(time.get("ui_timer_may_drive_core", true)), "UI timer cannot drive Core")
	var derived: Dictionary = document.get("derived_presentation_estimates", {})
	_expect(not bool(derived.get("runtime_authority", true)), "seconds are presentation-only estimates")

	var historical: Array = document.get("historical_profiles", [])
	_expect(historical.size() == 1, "Candidate A is retained as one historical comparison profile")
	var old_profile: Dictionary = historical[0] as Dictionary
	_expect(str(old_profile.get("profile_id", "")) == "V071_CANDIDATE_A_FAST" and not bool(old_profile.get("runtime_authority_for_v072", true)), "V0.7.1 profile is historical, not V0.7.2 authority")
	_finish()


func _value(by_id: Dictionary, default_id: String) -> Variant:
	var entry: Dictionary = by_id.get(default_id, {})
	return entry.get("value")


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("V072_BALANCE_DEFAULTS_TEST|status=%s|checks=%d|failures=%d|default_count=25|approved_default_count=10|frozen_structural_default_count=3|approved_tunable_default_count=7|profile_id=%s|profile_fingerprint=%s|human_fun_proven=false|details=%s" % [
		"PASS" if passed else "FAIL", _checks, _failures.size(), PROFILE_ID, PROFILE_FINGERPRINT, JSON.stringify(_failures)
	])
	quit(0 if passed else 1)
