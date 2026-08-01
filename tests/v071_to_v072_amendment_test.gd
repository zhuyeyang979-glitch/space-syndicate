extends SceneTree

const AMENDMENT_PATH := "res://docs/rules/v072_amendment_from_v071.json"
const AMENDMENT_MD_PATH := "res://docs/rules/v072_amendment_from_v071.md"
const V071_CONSTITUTION_PATH := "res://docs/rules/v071_game_constitution.json"
const V071_DEFAULTS_PATH := "res://docs/rules/v071_balance_defaults.json"

const HISTORICAL_FILES := {
	"res://docs/rules/v07_game_constitution.json": "81c8ae27eba50f4d68c8a379913baf0592a819412bca0109f7e5fc9ef9a5a5fc",
	"res://docs/rules/v07_game_constitution.md": "a0d2e4324898134bdc3a58cc232ce05e5ca39b8787549b8a55a6ab50f28abb72",
	"res://docs/rules/v07_balance_defaults.json": "8678cfa88eeff53f60b2e209598e670e2748189c3bb3bd0ebd21bf5c5e20c6f8",
	"res://docs/rules/v071_game_constitution.json": "a5a52a88bc5a139dc56accc46897c82ddc7c3ea1aacdcaa6f72a412815429473",
	"res://docs/rules/v071_game_constitution.md": "2b4822b915d46f575ad9f1ff4675bc3741c91a70cf19b4f56fc8f37ac9bed930",
	"res://docs/rules/v071_balance_defaults.json": "4ef853a914dafc4919848e2f28da824cb4b710058556c2013fd4cdcddc5d555a",
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
	"v072.assets.zero_genesis_balances",
	"v072.starter.closed_definition_registry",
	"v072.starter.persistent_zero_asset_cost",
	"v072.standard.level_one_asset_cost",
	"v072.starter.standard_merge_consumes_privilege",
	"v072.starter.zero_deadlock_bootstrap",
	"v072.starter.private_observation_and_projection",
	"v072.starter.save_identity_and_migration",
]

const PROFILE_INPUT := "V072_STARTER_FREE_FAST|initial_assets_per_color=0|starter_primary_asset_cost=0|standard_l1_primary_asset_cost=1|normal_card_ratio_basis_points=6000|commodity_card_ratio_basis_points=4000|single_color_net_intervention_cap_enabled=true|single_color_net_intervention_cap_basis_points=1200|max_asset_refresh_per_color_per_batch=3|hand_maintenance_timeout_seconds=8|lead_tenure_batches=1|color_cycle_batches=6"
const PROFILE_FINGERPRINT := "b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var document := _read_json(AMENDMENT_PATH)
	_expect(str(document.get("amendment_document_id", "")) == "space_syndicate.v072.amendment_from_v071", "amendment ID is exact")
	_expect(str(document.get("from_constitution_id", "")) == "space_syndicate.v071.complete", "source constitution is V0.7.1")
	_expect(str(document.get("to_constitution_id", "")) == "space_syndicate.v072.complete", "target constitution is V0.7.2")
	_expect(str(document.get("from_ruleset_id", "")) == "v0.7.1" and str(document.get("to_ruleset_id", "")) == "v0.7.2", "ruleset transition is exact")
	_expect(str(document.get("status", "")) == "approved_and_frozen", "amendment is approved and frozen")

	var approval: Dictionary = document.get("approval", {})
	_expect(bool(approval.get("approved", false)), "free Starter amendment is approved")
	_expect(str(approval.get("approval_decision_id", "")) == "USER_APPROVES_V072_FREE_STARTER_BOOTSTRAP", "approval decision is exact")
	_expect(str(approval.get("approved_profile_id", "")) == "V072_STARTER_FREE_FAST", "V0.7.2 profile is approved")
	_expect(not bool(approval.get("human_fun_proven", true)) and bool(approval.get("human_test_required", false)), "approval still requires human testing")

	var source_ids := _source_authority_ids()
	var structural: Array = document.get("structural_amendments", [])
	_expect(int(document.get("structural_amendment_count", 0)) == 8 and structural.size() == 8, "eight structural amendments are present")
	var amendment_ids: Dictionary = {}
	var target_ids: Array[String] = []
	for entry_variant in structural:
		_expect(entry_variant is Dictionary, "every amendment is an object")
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var amendment_id := str(entry.get("amendment_id", ""))
		_expect(_exact_fields(entry, STRUCTURAL_FIELDS), "%s has the closed amendment shape" % amendment_id)
		_expect(not amendment_ids.has(amendment_id), "%s is unique" % amendment_id)
		amendment_ids[amendment_id] = true
		_expect(str(entry.get("classification", "")) == "APPROVED_STARTER_ECONOMY_AMENDMENT", "%s has the approved classification" % amendment_id)
		var sources: Array = entry.get("source_rule_ids", [])
		_expect(not sources.is_empty(), "%s cites prior authority" % amendment_id)
		for source_id in sources:
			_expect(source_ids.has(str(source_id)), "%s source %s exists in frozen V0.7.1 authority" % [amendment_id, str(source_id)])
		var target_id := str(entry.get("target_rule_id", ""))
		target_ids.append(target_id)
		_expect(target_id.begins_with("v072."), "%s targets V0.7.2" % amendment_id)
		_expect(entry.get("approved_value", null) is Dictionary and not (entry.get("approved_value", {}) as Dictionary).is_empty(), "%s has a closed approved value" % amendment_id)
		_expect(entry.get("affected_domains", null) is Array and not (entry.get("affected_domains", []) as Array).is_empty(), "%s names affected domains" % amendment_id)
		_expect(bool(entry.get("migration_required", false)), "%s requires explicit migration" % amendment_id)
		_expect(entry.get("acceptance_gates", null) is Array and not (entry.get("acceptance_gates", []) as Array).is_empty(), "%s has acceptance gates" % amendment_id)
	for index in range(8):
		_expect(amendment_ids.has("V072-S%d" % (index + 1)), "V072-S%d is present" % (index + 1))
	_expect(target_ids == TARGET_RULE_IDS, "target rule IDs are exact and ordered")

	var profile: Dictionary = document.get("approved_profile", {})
	_expect(str(profile.get("profile_id", "")) == "V072_STARTER_FREE_FAST", "amendment profile ID is exact")
	_expect(str(profile.get("profile_fingerprint_input", "")) == PROFILE_INPUT, "amendment stores canonical profile input")
	_expect(str(profile.get("profile_fingerprint", "")) == PROFILE_FINGERPRINT, "amendment stores canonical profile fingerprint")
	_expect(PROFILE_INPUT.sha256_text().to_lower() == PROFILE_FINGERPRINT, "amendment profile fingerprint recomputes")
	var changed: Dictionary = profile.get("changed_from_v071", {})
	_expect(int((changed.get("initial_assets_per_color", {}) as Dictionary).get("from", -1)) == 2 and int((changed.get("initial_assets_per_color", {}) as Dictionary).get("to", -1)) == 0, "initial assets change from two to zero")
	_expect(int((changed.get("starter_primary_asset_cost", {}) as Dictionary).get("to", -1)) == 0, "Starter cost changes to zero")
	_expect(int((changed.get("standard_l1_primary_asset_cost", {}) as Dictionary).get("to", 0)) == 1, "standard L1 remains one under explicit origin scope")

	for path in HISTORICAL_FILES:
		_expect(_file_sha256(path) == str(HISTORICAL_FILES[path]), "%s remains byte-identical" % path)
	var baselines: Dictionary = document.get("historical_baselines", {})
	_expect(int((baselines.get("v07", {}) as Dictionary).get("content_change_count", -1)) == 0, "V0.7 historical content change count is zero")
	_expect(int((baselines.get("v071", {}) as Dictionary).get("content_change_count", -1)) == 0, "V0.7.1 historical content change count is zero")

	var save: Dictionary = document.get("save_migration", {})
	_expect(not bool(save.get("v071_save_to_v072_direct_resume", true)), "V0.7.1 Save cannot directly resume as V0.7.2")
	_expect(not bool(save.get("v06_save_to_v072_direct_resume", true)) and bool(save.get("v06_save_backup_required", false)), "V0.6 Save fails closed with backup")
	_expect(not bool(save.get("silent_default_allowed", true)), "new Save identity cannot silently default")
	var simulation: Dictionary = document.get("simulation_boundary", {})
	_expect(not bool(simulation.get("v071_simulation_reusable_as_v072_balance_evidence", true)), "old simulations are not V0.7.2 balance evidence")
	_expect(bool(simulation.get("fresh_v072_simulation_required", false)) and int(simulation.get("minimum_match_count", 0)) == 6000, "fresh 6000-match simulation is required")
	var player_counts: Array = simulation.get("player_counts", [])
	_expect(player_counts.size() == 4 and int(player_counts[0]) == 3 and int(player_counts[1]) == 4 and int(player_counts[2]) == 6 and int(player_counts[3]) == 8 and int(simulation.get("seeds_per_configuration", 0)) == 500, "simulation scope is 3/4/6/8 players with 500 seeds")

	var production: Dictionary = document.get("production_boundary", {})
	_expect(str(production.get("current_production_runtime_ruleset", "")) == "v0.6", "production remains V0.6")
	_expect(not bool(production.get("full_v0_7_2_runtime_cutover", true)), "no V0.7.2 runtime cutover")
	_expect(int(production.get("production_connection_count", -1)) == 0 and int(production.get("v06_mutation_count", -1)) == 0 and int(production.get("dual_write_count", -1)) == 0, "no production connection, V0.6 mutation, or dual write")

	var human := FileAccess.get_file_as_string(AMENDMENT_MD_PATH)
	_expect(human.contains("USER_APPROVES_V072_FREE_STARTER_BOOTSTRAP=true"), "human amendment records explicit approval")
	_expect(human.contains("V07_HISTORICAL_CONSTITUTION_CONTENT_CHANGE_COUNT=0"), "human amendment preserves V0.7 history")
	_expect(human.contains("V071_HISTORICAL_CONSTITUTION_CONTENT_CHANGE_COUNT=0"), "human amendment preserves V0.7.1 history")
	_expect(human.contains("HUMAN_FUN_PROVEN=false") and human.contains("FULL_V0_7_2_RUNTIME_CUTOVER=false"), "human amendment states critical boundaries")
	_finish()


func _source_authority_ids() -> Dictionary:
	var result: Dictionary = {}
	var constitution := _read_json(V071_CONSTITUTION_PATH)
	for rule_variant in constitution.get("constitutional_rules", []):
		if rule_variant is Dictionary:
			result[str((rule_variant as Dictionary).get("rule_id", ""))] = true
	var defaults := _read_json(V071_DEFAULTS_PATH)
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
	print("V071_TO_V072_AMENDMENT_TEST|status=%s|checks=%d|failures=%d|structural_amendment_count=8|v07_historical_change_count=0|v071_historical_change_count=0|production_connection_count=0|dual_write_count=0|human_fun_proven=false|details=%s" % [
		"PASS" if passed else "FAIL", _checks, _failures.size(), JSON.stringify(_failures)
	])
	quit(0 if passed else 1)
