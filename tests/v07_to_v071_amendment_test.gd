extends SceneTree

const AMENDMENT_PATH := "res://docs/rules/v071_amendment_from_v07.json"
const AMENDMENT_MD_PATH := "res://docs/rules/v071_amendment_from_v07.md"
const V07_JSON_PATH := "res://docs/rules/v07_game_constitution.json"
const V07_MD_PATH := "res://docs/rules/v07_game_constitution.md"
const V07_BALANCE_PATH := "res://docs/rules/v07_balance_defaults.json"

const STRUCTURAL_FIELDS := [
	"amendment_id", "classification", "source_rule_ids", "target_rule_id",
	"change_kind", "approved_value", "save_impacts", "ai_impacts",
	"player_impacts", "rng_impacts", "migration_required", "acceptance_gates",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var document := _read_json(AMENDMENT_PATH)
	_expect(str(document.get("amendment_document_id", "")) == "space_syndicate.v071.amendment_from_v07", "amendment ID is exact")
	_expect(str(document.get("from_constitution_id", "")) == "space_syndicate.v07.complete", "source constitution is V0.7")
	_expect(str(document.get("to_constitution_id", "")) == "space_syndicate.v071.complete", "target constitution is V0.7.1")
	_expect(str(document.get("status", "")) == "approved_and_frozen", "amendment is approved and frozen")

	var structural: Array = document.get("structural_amendments", [])
	_expect(int(document.get("structural_amendment_count", 0)) == 8 and structural.size() == 8, "eight structural amendments are present")
	var ids: Dictionary = {}
	for entry_variant in structural:
		_expect(entry_variant is Dictionary, "every amendment is an object")
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var amendment_id := str(entry.get("amendment_id", ""))
		_expect(_exact_fields(entry, STRUCTURAL_FIELDS), "%s has the closed amendment shape" % amendment_id)
		_expect(not ids.has(amendment_id), "%s is unique" % amendment_id)
		ids[amendment_id] = true
		_expect(str(entry.get("classification", "")) in ["CLASS_A_IMPLEMENTATION_CONTRADICTION", "CLASS_B_STATE_MACHINE_CLOSURE_ERRATA"], "%s has an allowed classification" % amendment_id)
		_expect(entry.get("source_rule_ids", null) is Array and not (entry.get("source_rule_ids", []) as Array).is_empty(), "%s cites V0.7 source rules" % amendment_id)
		_expect(str(entry.get("target_rule_id", "")).begins_with("v071."), "%s targets V0.7.1" % amendment_id)
		_expect(bool(entry.get("migration_required", false)), "%s requires explicit migration" % amendment_id)
	for expected_id in ["V071-A1", "V071-A2", "V071-B1", "V071-B2", "V071-B3", "V071-B4", "V071-B5", "V071-B6"]:
		_expect(ids.has(expected_id), "%s is present" % expected_id)

	var balance: Array = document.get("balance_amendments", [])
	_expect(int(document.get("approved_balance_default_count", 0)) == 8 and balance.size() == 8, "eight balance records are approved")
	var approval: Dictionary = document.get("approval", {})
	_expect(str(approval.get("approved_profile_id", "")) == "V071_CANDIDATE_A_FAST", "Candidate A is approved")
	_expect(not bool(approval.get("human_fun_proven", true)) and bool(approval.get("human_test_required", false)), "approval still requires human testing")

	var baseline: Dictionary = document.get("historical_v07_baseline", {})
	_expect(_file_sha256(V07_JSON_PATH) == str(baseline.get("constitution_json_sha256", "")), "V0.7 JSON hash matches amendment provenance")
	_expect(_file_sha256(V07_MD_PATH) == str(baseline.get("constitution_markdown_sha256", "")), "V0.7 Markdown hash matches amendment provenance")
	_expect(_file_sha256(V07_BALANCE_PATH) == str(baseline.get("balance_defaults_sha256", "")), "V0.7 defaults hash matches amendment provenance")
	_expect(int(baseline.get("content_change_count", -1)) == 0, "V0.7 historical content change count is zero")

	var provenance: Dictionary = document.get("candidate_provenance", {})
	_expect(int(provenance.get("total_simulated_matches", 0)) == 6000, "approval records 6000 simulations")
	var player_counts: Array = provenance.get("simulation_player_counts", [])
	_expect(player_counts.size() == 4 and int(player_counts[0]) == 3 and int(player_counts[1]) == 4 and int(player_counts[2]) == 6 and int(player_counts[3]) == 8, "approval covers 3, 4, 6, and 8 players")
	_expect(int(provenance.get("simulation_seeds_per_configuration", 0)) == 500, "approval records 500 seeds per configuration")
	_expect(str(provenance.get("simulation_fingerprint", "")) == "d664b7ba8d69fe152c7194e2b357db6c996ed36681f2b031433c773ee61d815e", "simulation fingerprint is retained")

	var production: Dictionary = document.get("production_boundary", {})
	_expect(str(production.get("current_production_runtime_ruleset", "")) == "v0.6", "production remains V0.6")
	_expect(not bool(production.get("full_v0_7_1_runtime_cutover", true)), "no V0.7.1 runtime cutover")
	_expect(int(production.get("production_connection_count", -1)) == 0 and int(production.get("dual_write_count", -1)) == 0, "no production connection or dual write")
	var human := FileAccess.get_file_as_string(AMENDMENT_MD_PATH)
	_expect(human.contains("HUMAN_FUN_PROVEN=false") and human.contains("V07_HISTORICAL_CONSTITUTION_CONTENT_CHANGE_COUNT=0"), "human amendment states the two critical boundaries")
	_finish()


func _exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true


func _read_json(path: String) -> Dictionary:
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
	print("V07_TO_V071_AMENDMENT_TEST|status=%s|checks=%d|failures=%d|structural_amendment_count=8|approved_balance_default_count=8|v07_historical_change_count=0|production_connection_count=0|dual_write_count=0|details=%s" % [
		"PASS" if passed else "FAIL", _checks, _failures.size(), JSON.stringify(_failures)
	])
	quit(0 if passed else 1)
