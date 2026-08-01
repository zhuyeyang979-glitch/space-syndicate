extends SceneTree

const CONSTITUTION_PATH := "res://docs/rules/v071_game_constitution.json"
const CONSTITUTION_MD_PATH := "res://docs/rules/v071_game_constitution.md"
const PROGRAM_STATE_PATH := "res://docs/development/current_program_state.json"
const AGENTS_PATH := "res://AGENTS.md"
const V07_JSON_PATH := "res://docs/rules/v07_game_constitution.json"
const V07_MD_PATH := "res://docs/rules/v07_game_constitution.md"
const V07_BALANCE_PATH := "res://docs/rules/v07_balance_defaults.json"

const V07_JSON_SHA256 := "81c8ae27eba50f4d68c8a379913baf0592a819412bca0109f7e5fc9ef9a5a5fc"
const V07_MD_SHA256 := "a0d2e4324898134bdc3a58cc232ce05e5ca39b8787549b8a55a6ab50f28abb72"
const V07_BALANCE_SHA256 := "8678cfa88eeff53f60b2e209598e670e2748189c3bb3bd0ebd21bf5c5e20c6f8"

const AMENDMENT_RULE_IDS := [
	"v071.batch_boundary.independent_lead_color_cycles",
	"v071.lead.ai_private_self_notice",
	"v071.track.replacement_next_scroll_lock",
	"v071.normal_merge.minimum_total_five",
	"v071.track.level_one_only_supply",
	"v071.commodity.batch_availability",
	"v071.resolution.invalid_target_policy",
	"v071.lead.soft_hidden_publication",
]

const AUTHORITY_PRECEDENCE := [
	"latest_explicit_user_rule_decision",
	"docs/rules/v071_game_constitution.json",
	"docs/rules/v071_game_constitution.md",
	"docs/rules/v07_game_constitution.json",
	"docs/rules/v07_game_constitution.md",
	"docs/tabletop_rulebook_v06.md_current_production_only",
	"older_rule_documents",
	"older_test_oracles",
	"older_code_behavior",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var constitution := _read_json(CONSTITUTION_PATH)
	_expect(not constitution.is_empty(), "V0.7.1 constitution parses")
	_expect(str(constitution.get("constitution_id", "")) == "space_syndicate.v071.complete", "constitution ID is exact")
	_expect(str(constitution.get("ruleset_id", "")) == "v0.7.1", "ruleset ID is exact")
	_expect(str(constitution.get("status", "")) == "frozen_highest_target_constitution", "constitution is frozen highest target")
	_expect(str(constitution.get("current_production_ruleset", "")) == "v0.6", "production remains V0.6")
	_expect(constitution.get("authority_precedence", []) == AUTHORITY_PRECEDENCE, "authority precedence is exact")

	var approval: Dictionary = constitution.get("approval", {})
	_expect(bool(approval.get("approved", false)), "Candidate A approval is recorded")
	_expect(str(approval.get("approved_profile_id", "")) == "V071_CANDIDATE_A_FAST", "approved profile is exact")
	_expect(not bool(approval.get("human_fun_proven", true)) and bool(approval.get("human_test_required", false)), "freeze does not claim human fun")

	var rules: Array = constitution.get("constitutional_rules", [])
	_expect(rules.size() == 84, "constitution contains 76 inherited plus 8 amended rules")
	var ids: Dictionary = {}
	for rule_variant in rules:
		_expect(rule_variant is Dictionary, "every constitutional rule is an object")
		if not (rule_variant is Dictionary):
			continue
		var rule := rule_variant as Dictionary
		var rule_id := str(rule.get("rule_id", ""))
		_expect(not rule_id.is_empty() and not ids.has(rule_id), "%s is a unique rule ID" % rule_id)
		ids[rule_id] = true
		_expect(not str(rule.get("domain", "")).is_empty(), "%s has a domain" % rule_id)
		_expect(not str(rule.get("statement", "")).is_empty(), "%s has a statement" % rule_id)
	for rule_id in AMENDMENT_RULE_IDS:
		_expect(ids.has(rule_id), "%s is frozen" % rule_id)
	_expect(constitution.get("structural_amendment_rule_ids", []) == AMENDMENT_RULE_IDS, "eight amendment IDs are ordered and exact")

	var schema: Dictionary = constitution.get("constitutional_rule_value_schema", {})
	var schema_ids := _schema_rule_ids(schema)
	_expect(schema_ids.size() == 84, "value schema covers all 84 rules")
	for rule_id in ids:
		_expect(schema_ids.has(rule_id), "%s has a closed value schema" % rule_id)

	var save: Dictionary = constitution.get("save_obligations", {})
	for field in [
		"completed_batch_count", "lead_batch_cursor", "color_cycle_batch_cursor",
		"claimable_from_scroll_sequence", "available_from_batch_id",
		"normal_deck_minimum_count_rule_version", "invalid_target_policy_id",
		"balance_profile_id", "balance_profile_fingerprint",
	]:
		_expect(field in save.get("required_state", []), "Save requires %s" % field)
	_expect(not bool(save.get("v07_save_to_v071_direct_resume", true)), "V0.7 Save cannot directly resume as V0.7.1")
	_expect(not bool(save.get("v06_save_to_v071_direct_resume", true)) and bool(save.get("v06_save_backup_required", false)), "V0.6 Save fails closed with backup")

	var privacy: Dictionary = constitution.get("privacy_obligations", {})
	_expect(bool(privacy.get("lead_identity_not_directly_published", false)), "lead is not directly published")
	_expect(bool(privacy.get("lead_identity_may_be_inferred_from_public_information", false)), "soft-hidden inference is explicit")
	var cutover: Dictionary = constitution.get("cutover_obligations", {})
	_expect(not bool(cutover.get("production_cutover_allowed_by_this_task", true)), "docs freeze does not authorize production")
	_expect(not bool(cutover.get("v06_and_v071_dual_write_allowed", true)), "dual write is forbidden")

	_expect(_file_sha256(V07_JSON_PATH) == V07_JSON_SHA256, "V0.7 JSON remains byte-identical")
	_expect(_file_sha256(V07_MD_PATH) == V07_MD_SHA256, "V0.7 Markdown remains byte-identical")
	_expect(_file_sha256(V07_BALANCE_PATH) == V07_BALANCE_SHA256, "V0.7 defaults remain byte-identical")

	var program := _read_json(PROGRAM_STATE_PATH).get("program", {}) as Dictionary
	_expect(str(program.get("current_production_runtime_ruleset", "")) == "v0.6", "program state retains V0.6 production")
	_expect(str(program.get("highest_target_ruleset", "")) == "v0.7.1", "program state records V0.7.1 highest target")
	_expect(bool(program.get("v071_highest_constitution_frozen", false)), "program state records frozen V0.7.1")
	_expect(not bool(program.get("full_v0_7_1_runtime_cutover", true)), "program state records no V0.7.1 cutover")

	var agents := FileAccess.get_file_as_string(AGENTS_PATH)
	_expect(agents.find("docs/rules/v071_game_constitution.json") < agents.find("docs/rules/v07_game_constitution.json"), "AGENTS places V0.7.1 before V0.7")
	_expect(agents.contains("HIGHEST_TARGET_RULE_AUTHORITY=V0.7.1_COMPLETE_CONSTITUTION"), "AGENTS names V0.7.1 highest authority")
	var human := FileAccess.get_file_as_string(CONSTITUTION_MD_PATH)
	_expect(human.contains("HUMAN_FUN_PROVEN=false") and human.contains("FULL_V0_7_1_RUNTIME_CUTOVER=false"), "human constitution preserves approval boundaries")
	_finish()


func _schema_rule_ids(schema: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var closed: Dictionary = schema.get("closed_object_keys_by_rule_id", {})
	for rule_id in closed:
		result[str(rule_id)] = true
	for list_id in ["closed_string_list_rule_ids", "bool_rule_ids", "number_rule_ids", "enum_string_rule_ids"]:
		for rule_id in schema.get(list_id, []):
			result[str(rule_id)] = true
	return result


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
	print("V071_CONSTITUTION_CONTRACT_TEST|status=%s|checks=%d|failures=%d|rule_count=84|structural_errata_count=8|v07_historical_change_count=0|production_connection_count=0|human_fun_proven=false|details=%s" % [
		"PASS" if passed else "FAIL", _checks, _failures.size(), JSON.stringify(_failures)
	])
	quit(0 if passed else 1)
