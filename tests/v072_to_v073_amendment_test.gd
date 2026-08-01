extends SceneTree

const AMENDMENT_PATH := "res://docs/rules/v073_amendment_from_v072.json"
const AMENDMENT_MD_PATH := "res://docs/rules/v073_amendment_from_v072.md"
const V071_CONSTITUTION_PATH := "res://docs/rules/v071_game_constitution.json"
const V071_DEFAULTS_PATH := "res://docs/rules/v071_balance_defaults.json"
const V072_CONSTITUTION_PATH := "res://docs/rules/v072_game_constitution.json"
const V072_DEFAULTS_PATH := "res://docs/rules/v072_balance_defaults.json"

const HISTORICAL_FILES := {
	"res://docs/rules/v07_game_constitution.json": "81c8ae27eba50f4d68c8a379913baf0592a819412bca0109f7e5fc9ef9a5a5fc",
	"res://docs/rules/v07_game_constitution.md": "a0d2e4324898134bdc3a58cc232ce05e5ca39b8787549b8a55a6ab50f28abb72",
	"res://docs/rules/v07_balance_defaults.json": "8678cfa88eeff53f60b2e209598e670e2748189c3bb3bd0ebd21bf5c5e20c6f8",
	"res://docs/rules/v071_game_constitution.json": "a5a52a88bc5a139dc56accc46897c82ddc7c3ea1aacdcaa6f72a412815429473",
	"res://docs/rules/v071_game_constitution.md": "2b4822b915d46f575ad9f1ff4675bc3741c91a70cf19b4f56fc8f37ac9bed930",
	"res://docs/rules/v071_balance_defaults.json": "4ef853a914dafc4919848e2f28da824cb4b710058556c2013fd4cdcddc5d555a",
	"res://docs/rules/v072_game_constitution.json": "d6e93f053e961e6adf1a1410d9343fe9bccd315f429819ef59d75c2ecd6d7a33",
	"res://docs/rules/v072_game_constitution.md": "1e557e3cc3d00bcbe83f671275d90a5a3e829f7e73245f5e0cf818dd323c1304",
	"res://docs/rules/v072_balance_defaults.json": "91a9ee9bdc796013e4ac64d2ce9893267f65ce285b22551963371be610d67155",
	"res://docs/rules/v072_amendment_from_v071.json": "91c1fd7d3025b84b566c5beb023e596a90715ec03efe3e85899c6ca7f7a01195",
	"res://docs/rules/v072_amendment_from_v071.md": "9604d2a6d7d3a8e1f20da806054c9e73bb5f30363a484fefd1065c9e0504ec79",
	"res://docs/rules/v072_rule_precedence.md": "82908f46e882459fe732932258be19f9be506bc32a4a058f2eb8b156bc2139f5",
}

const STRUCTURAL_FIELDS := [
	"amendment_id",
	"classification",
	"source_rule_ids",
	"target_rule_id",
	"change_kind",
	"approved_value",
	"affected_domains",
	"save_impacts",
	"ai_impacts",
	"player_impacts",
	"rng_impacts",
	"migration_required",
	"acceptance_gates",
]

const TARGET_RULE_IDS := [
	"v073.resolution.auction_rejected",
	"v073.resolution.fixed_hidden_round_robin",
	"v073.facility.prebound_unique_slot_modes",
	"v073.facility.authoritative_revalidation_no_conversion",
	"v073.facility.contention_fizzle_privacy_and_persistence",
]

const PROFILE_INPUT := "V073_STARTER_FREE_FIXED_ORDER_CONTENTION|initial_assets_per_color=0|starter_asset_cost=0|standard_l1_asset_cost=1|normal_card_ratio_bps=6000|commodity_card_ratio_bps=4000|intervention_cap_bps=1200|max_asset_refresh_per_color_per_batch=3|hand_maintenance_timeout_seconds=8|lead_tenure_batches=1|color_cycle_batches=6|track_scroll_interval_seconds=5|track_local_visible_slot_count=5|resolution_order_mode=fixed_hidden_round_robin|facility_action_mode_required=true|build_slot_contention_fizzle=true|initiative_bid_mode=retired"
const PROFILE_FINGERPRINT := "a413ad0ddd8a06b15ccee943d9cd93c6f7941fc66ce901a1f44934797f50231c"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var document := _read_json(AMENDMENT_PATH)
	_expect(not document.is_empty(), "V0.7.3 amendment parses")
	_expect(str(document.get("amendment_document_id", "")) == "space_syndicate.v073.amendment_from_v072", "amendment ID is exact")
	_expect(str(document.get("from_constitution_id", "")) == "space_syndicate.v072.complete", "source constitution is V0.7.2")
	_expect(str(document.get("to_constitution_id", "")) == "space_syndicate.v073.complete", "target constitution is V0.7.3")
	_expect(str(document.get("from_ruleset_id", "")) == "v0.7.2" and str(document.get("to_ruleset_id", "")) == "v0.7.3", "ruleset transition is exact")
	_expect(str(document.get("status", "")) == "approved_and_frozen", "amendment is approved and frozen")

	_test_approval(document)
	var by_target := _test_structural_amendments(document)
	_test_approved_values(by_target)
	_test_profile_and_boundaries(document)
	_test_history(document)
	_test_human_companion()
	_finish()


func _test_approval(document: Dictionary) -> void:
	var approval: Dictionary = document.get("approval", {})
	_expect(bool(approval.get("approved", false)), "fixed-order contention amendment is approved")
	_expect(approval.get("decision_ids", []) == [
		"USER_REJECTS_RESOLUTION_ORDER_AUCTION",
		"USER_REJECTS_INITIATIVE_CASH_BIDDING",
		"USER_APPROVES_FIXED_ROUND_ROBIN_RESOLUTION",
		"USER_APPROVES_PREBOUND_FACILITY_CONTENTION",
		"USER_APPROVES_FACILITY_BUILD_FIZZLE_ON_SLOT_CONTENTION",
	], "five approval decisions are exact and ordered")
	_expect(str(approval.get("approved_profile_id", "")) == "V073_STARTER_FREE_FIXED_ORDER_CONTENTION", "V0.7.3 profile is approved")
	_expect(not bool(approval.get("human_fun_proven", true)) and bool(approval.get("human_test_required", false)), "approval still requires human testing")


func _test_structural_amendments(document: Dictionary) -> Dictionary:
	var source_ids := _source_authority_ids()
	var structural: Array = document.get("structural_amendments", [])
	_expect(int(document.get("structural_amendment_count", 0)) == 5 and structural.size() == 5, "five structural amendments are present")
	var amendment_ids: Dictionary = {}
	var target_ids: Array[String] = []
	var by_target: Dictionary = {}
	for entry_variant in structural:
		_expect(entry_variant is Dictionary, "every amendment is an object")
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var amendment_id := str(entry.get("amendment_id", ""))
		_expect(_exact_fields(entry, STRUCTURAL_FIELDS), "%s has the closed amendment shape" % amendment_id)
		_expect(not amendment_ids.has(amendment_id), "%s is unique" % amendment_id)
		amendment_ids[amendment_id] = true
		_expect(str(entry.get("classification", "")) == "APPROVED_FIXED_ORDER_CONTENTION_AMENDMENT", "%s has the approved classification" % amendment_id)
		var sources: Array = entry.get("source_rule_ids", [])
		_expect(not sources.is_empty(), "%s cites prior authority" % amendment_id)
		for source_id in sources:
			_expect(source_ids.has(str(source_id)), "%s source %s exists in frozen V0.7.2 composed authority" % [amendment_id, str(source_id)])
		var target_id := str(entry.get("target_rule_id", ""))
		target_ids.append(target_id)
		by_target[target_id] = entry
		_expect(target_id.begins_with("v073."), "%s targets V0.7.3" % amendment_id)
		_expect(entry.get("approved_value", null) is Dictionary and not (entry.get("approved_value", {}) as Dictionary).is_empty(), "%s has a closed approved value" % amendment_id)
		_expect(entry.get("affected_domains", null) is Array and not (entry.get("affected_domains", []) as Array).is_empty(), "%s names affected domains" % amendment_id)
		_expect(bool(entry.get("migration_required", false)), "%s requires explicit migration" % amendment_id)
		_expect(entry.get("acceptance_gates", null) is Array and not (entry.get("acceptance_gates", []) as Array).is_empty(), "%s has acceptance gates" % amendment_id)
	for index in range(5):
		_expect(amendment_ids.has("V073-C%d" % (index + 1)), "V073-C%d is present" % (index + 1))
	_expect(target_ids == TARGET_RULE_IDS, "target rule IDs are exact and ordered")
	return by_target


func _test_approved_values(by_target: Dictionary) -> void:
	var auction: Dictionary = (by_target.get("v073.resolution.auction_rejected", {}) as Dictionary).get("approved_value", {})
	_expect(not bool(auction.get("initiative_auction_enabled", true)), "auction is disabled")
	_expect(not bool(auction.get("resolution_order_bidding_enabled", true)), "resolution bidding is disabled")
	_expect(not bool(auction.get("cash_can_change_resolution_order", true)), "cash cannot change order")
	for field in ["initiative_auction_core_count", "initiative_bid_owner_count", "initiative_bid_save_field_count", "initiative_bid_ui_surface_count", "ai_initiative_bid_policy_count"]:
		_expect(int(auction.get(field, -1)) == 0, "%s is zero" % field)

	var order: Dictionary = (by_target.get("v073.resolution.fixed_hidden_round_robin", {}) as Dictionary).get("approved_value", {})
	_expect(str(order.get("resolution_order_mode", "")) == "fixed_hidden_round_robin", "fixed hidden round robin is exact")
	_expect(str(order.get("batch_resolution_order_source", "")) == "frozen_hidden_lead_order_at_batch_lock", "batch order source is exact")
	_expect(int(order.get("resolution_order_writer_count", 0)) == 1 and int(order.get("resolution_order_modifier_count", -1)) == 0, "order has one writer and no modifiers")
	_expect(not bool(order.get("resolution_order_mutation_after_batch_lock", true)), "order is immutable after lock")
	var local_indices: Array = order.get("local_action_indices", [])
	_expect(local_indices.size() == 5 and int(local_indices[0]) == 0 and int(local_indices[1]) == 1 and int(local_indices[2]) == 2 and int(local_indices[3]) == 3 and int(local_indices[4]) == 4, "five local action layers are exact")
	_expect(bool(order.get("one_action_per_player_per_layer", false)) and bool(order.get("empty_queue_skipped", false)) and bool(order.get("single_remaining_player_tail_continues", false)), "round-robin layering semantics are complete")

	var modes: Dictionary = (by_target.get("v073.facility.prebound_unique_slot_modes", {}) as Dictionary).get("approved_value", {})
	_expect(modes.get("facility_slot_unique_key", []) == ["region_id", "facility_type", "industry_id"], "facility slot key is exact")
	_expect(modes.get("allowed_facility_action_modes", []) == ["BUILD_NEW", "UPGRADE_OWN", "REPAIR_OWN"], "three prebound modes are exact")
	_expect(bool(modes.get("facility_action_mode_required", false)) and not bool(modes.get("facility_action_mode_mutable_after_lock", true)), "facility mode is required and immutable")
	_expect(not bool(modes.get("omitted_then_inferred_field_allowed", true)), "target fields cannot be guessed")

	var revalidation: Dictionary = (by_target.get("v073.facility.authoritative_revalidation_no_conversion", {}) as Dictionary).get("approved_value", {})
	_expect(str(revalidation.get("authoritative_revalidator", "")) == "region_infrastructure_owner", "infrastructure Owner is authoritative")
	_expect(not bool(revalidation.get("viewer_snapshot_may_decide_final_legality", true)), "viewer snapshot cannot decide legality")
	for field in ["build_to_upgrade_auto_conversion", "build_to_repair_auto_conversion", "upgrade_to_repair_auto_conversion", "repair_to_upgrade_auto_conversion", "target_reselection_during_resolution"]:
		_expect(not bool(revalidation.get(field, true)), "%s is false" % field)

	var fizzle: Dictionary = (by_target.get("v073.facility.contention_fizzle_privacy_and_persistence", {}) as Dictionary).get("approved_value", {})
	_expect(str(fizzle.get("invalid_target_policy_id", "")) == "FIZZLE_FULL_ASSET_REFUND", "contention uses the default full-refund policy")
	_expect(not bool(fizzle.get("target_reselected", true)), "contention does not reselect")
	_expect(bool(fizzle.get("asset_reservation_released", false)), "contention releases assets")
	_expect(str(fizzle.get("normal_card_destination", "")) == "discard", "contention discards the card")
	_expect(not bool(fizzle.get("action_slot_refunded", true)), "contention does not refund the action")
	_expect(bool(fizzle.get("starter_uses_same_policy", false)), "Starter uses the same Fizzle")
	_expect(bool(fizzle.get("public_history_owner_anonymous", false)) and int(fizzle.get("anonymous_owner_direct_disclosure_rate_required", -1)) == 0, "public history remains owner-anonymous")
	_expect(not bool(fizzle.get("v072_save_to_v073_direct_resume", true)), "V0.7.2 Save fails closed")


func _test_profile_and_boundaries(document: Dictionary) -> void:
	var profile: Dictionary = document.get("approved_profile", {})
	_expect(str(profile.get("profile_id", "")) == "V073_STARTER_FREE_FIXED_ORDER_CONTENTION", "amendment profile ID is exact")
	_expect(str(profile.get("profile_fingerprint_input", "")) == PROFILE_INPUT, "amendment stores canonical profile input")
	_expect(str(profile.get("profile_fingerprint", "")) == PROFILE_FINGERPRINT, "amendment stores canonical profile fingerprint")
	_expect(PROFILE_INPUT.sha256_text().to_lower() == PROFILE_FINGERPRINT, "amendment profile fingerprint recomputes")
	var inherited: Dictionary = profile.get("inherited_v072_values", {})
	_expect(int(inherited.get("initial_assets_per_color", -1)) == 0, "initial assets remain zero")
	_expect(int(inherited.get("starter_asset_cost", -1)) == 0 and int(inherited.get("standard_l1_asset_cost", 0)) == 1, "Starter and standard L1 costs remain zero and one")
	_expect(int(inherited.get("normal_card_ratio_bps", 0)) == 6000 and int(inherited.get("commodity_card_ratio_bps", 0)) == 4000, "60/40 track ratio is inherited")
	_expect(int(inherited.get("intervention_cap_bps", 0)) == 1200 and int(inherited.get("max_asset_refresh_per_color_per_batch", 0)) == 3, "intervention and refresh caps are inherited")
	_expect(int(inherited.get("hand_maintenance_timeout_seconds", 0)) == 8, "maintenance timeout is inherited")
	_expect(int(inherited.get("lead_tenure_batches", 0)) == 1 and int(inherited.get("color_cycle_batches", 0)) == 6, "lead and color cycle values are inherited")
	_expect(int(inherited.get("track_scroll_interval_seconds", 0)) == 5 and int(inherited.get("track_local_visible_slot_count", 0)) == 5, "track values are inherited")
	var structural: Dictionary = profile.get("v073_structural_values", {})
	_expect(str(structural.get("resolution_order_mode", "")) == "fixed_hidden_round_robin", "profile freezes fixed hidden round robin")
	_expect(bool(structural.get("facility_action_mode_required", false)) and bool(structural.get("build_slot_contention_fizzle", false)), "profile freezes explicit mode and Fizzle")
	_expect(str(structural.get("initiative_bid_max_cash", "")) == "not_applicable" and str(structural.get("initiative_bid_mode", "")) == "retired", "bid configuration is retired, not parameterized")

	var save: Dictionary = document.get("save_migration", {})
	_expect(not bool(save.get("v072_save_to_v073_direct_resume", true)), "V0.7.2 Save cannot directly resume")
	_expect(not bool(save.get("v06_save_to_v073_direct_resume", true)) and bool(save.get("v06_save_backup_required", false)), "V0.6 Save fails closed with backup")
	_expect(not bool(save.get("silent_default_allowed", true)), "new fields cannot silently default")
	_expect(int(save.get("restore_rng_draw_delta", -1)) == 0, "restore RNG draw delta is zero")

	var simulation: Dictionary = document.get("simulation_boundary", {})
	_expect(bool(simulation.get("fresh_v073_simulation_required", false)) and int(simulation.get("minimum_match_count", 0)) == 6000, "fresh 6000-match simulation is required")
	var player_counts: Array = simulation.get("player_counts", [])
	_expect(player_counts.size() == 4 and int(player_counts[0]) == 3 and int(player_counts[1]) == 4 and int(player_counts[2]) == 6 and int(player_counts[3]) == 8 and int(simulation.get("seeds_per_configuration", 0)) == 500, "simulation scope is 3/4/6/8 with 500 seeds")
	_expect(float(simulation.get("recommended_facility_build_fizzle_rate_minimum", 0.0)) == 0.03 and float(simulation.get("recommended_facility_build_fizzle_rate_maximum", 0.0)) == 0.15, "recommended Fizzle interval is exact")
	_expect(not bool(simulation.get("auction_tuning_allowed", true)), "simulation cannot justify an auction")
	_expect(not bool(simulation.get("human_fun_proven", true)) and bool(simulation.get("human_test_required", false)), "simulation does not prove human fun")

	var production: Dictionary = document.get("production_boundary", {})
	_expect(str(production.get("current_production_runtime_ruleset", "")) == "v0.6", "production remains V0.6")
	_expect(str(production.get("highest_target_ruleset", "")) == "v0.7.3", "highest target is V0.7.3")
	_expect(not bool(production.get("full_v0_7_3_runtime_cutover", true)), "no V0.7.3 runtime cutover")
	_expect(int(production.get("production_connection_count", -1)) == 0 and int(production.get("v06_mutation_count", -1)) == 0 and int(production.get("dual_write_count", -1)) == 0, "no production connection, V0.6 mutation, or dual write")


func _test_history(document: Dictionary) -> void:
	for path in HISTORICAL_FILES:
		_expect(_file_sha256(path) == str(HISTORICAL_FILES[path]), "%s remains byte-identical" % path)
	var baselines: Dictionary = document.get("historical_baselines", {})
	for version in ["v07", "v071", "v072"]:
		_expect(int((baselines.get(version, {}) as Dictionary).get("content_change_count", -1)) == 0, "%s historical content change count is zero" % version)
	var source: Dictionary = document.get("source_authority", {})
	_expect(str(source.get("sha256", "")) == HISTORICAL_FILES[V072_CONSTITUTION_PATH], "source authority pins V0.7.2")
	_expect(int(source.get("effective_rule_count", 0)) == 92, "source authority records 92 effective rules")


func _test_human_companion() -> void:
	var human := FileAccess.get_file_as_string(AMENDMENT_MD_PATH)
	for decision in [
		"USER_REJECTS_RESOLUTION_ORDER_AUCTION=true",
		"USER_REJECTS_INITIATIVE_CASH_BIDDING=true",
		"USER_APPROVES_FIXED_ROUND_ROBIN_RESOLUTION=true",
		"USER_APPROVES_PREBOUND_FACILITY_CONTENTION=true",
		"USER_APPROVES_FACILITY_BUILD_FIZZLE_ON_SLOT_CONTENTION=true",
	]:
		_expect(human.contains(decision), "human amendment records %s" % decision)
	_expect(human.contains("V072_HISTORICAL_CONSTITUTION_CONTENT_CHANGE_COUNT=0"), "human amendment preserves V0.7.2 history")
	_expect(human.contains("CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6") and human.contains("FULL_V0_7_3_RUNTIME_CUTOVER=false"), "human amendment states the runtime boundary")
	_expect(human.contains("HUMAN_FUN_PROVEN=false") and human.contains("HUMAN_TEST_REQUIRED=true"), "human amendment states the human-test boundary")


func _source_authority_ids() -> Dictionary:
	var result: Dictionary = {}
	for path in [V071_CONSTITUTION_PATH, V072_CONSTITUTION_PATH]:
		var constitution := _read_json(path)
		for collection_id in ["constitutional_rules", "inherited_v06_rules"]:
			for rule_variant in constitution.get(collection_id, []):
				if rule_variant is Dictionary:
					result[str((rule_variant as Dictionary).get("rule_id", ""))] = true
	for path in [V071_DEFAULTS_PATH, V072_DEFAULTS_PATH]:
		var defaults := _read_json(path)
		for default_variant in defaults.get("defaults", []):
			if default_variant is Dictionary:
				result[str((default_variant as Dictionary).get("default_id", ""))] = true
	return result


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
	print("V072_TO_V073_AMENDMENT_TEST|status=%s|checks=%d|failures=%d|structural_amendment_count=5|v072_historical_change_count=0|initiative_auction_core_count=0|initiative_bid_save_field_count=0|production_connection_count=0|dual_write_count=0|human_fun_proven=false|details=%s" % [
		"PASS" if passed else "FAIL", _checks, _failures.size(), JSON.stringify(_failures)
	])
	quit(0 if passed else 1)
