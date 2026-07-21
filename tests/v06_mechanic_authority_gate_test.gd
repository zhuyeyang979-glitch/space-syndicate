extends SceneTree

const REGISTRY_PATH := "res://docs/rules/v06_mechanic_status_registry.json"
var failures: Array[String] = []


func _init() -> void:
	var output: Array = []
	var exit_code := OS.execute("python", ["tools/rules/check_v06_mechanic_authority.py", "--summary"], output, true)
	_expect(exit_code == 0, "static authority checker passes: %s" % "\n".join(output))
	var checker_report: Variant = JSON.parse_string("\n".join(output))
	_expect(checker_report is Dictionary, "static authority checker returns structured JSON")
	if checker_report is Dictionary:
		_expect(
			str(checker_report.get("status", "")) == "PASS"
			and int(checker_report.get("retired_production_identifier_count", -1)) == 0
			and int(checker_report.get("source_splitting_evasion_count", -1)) == 0
			and int(checker_report.get("rule_authority_unreferenced_mechanic_count", -1)) == 0
			and (checker_report.get("registry_errors", []) as Array).is_empty(),
			"authority report has zero retired, split-source, unreferenced, or registry violations"
		)
	var self_test_output: Array = []
	var self_test_exit := OS.execute("python", ["tools/rules/check_v06_mechanic_authority.py", "--self-test"], self_test_output, true)
	var self_test_report: Variant = JSON.parse_string("\n".join(self_test_output))
	_expect(self_test_exit == 0 and self_test_report is Dictionary and str(self_test_report.get("status", "")) == "PASS", "authority checker detects split-source evasions without false positives")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
	_expect(parsed is Dictionary, "mechanic registry JSON parses")
	if parsed is Dictionary:
		var statuses := {}
		for item_variant in (parsed as Dictionary).get("mechanics", []):
			if item_variant is Dictionary:
				statuses[str(item_variant.get("mechanic_id", ""))] = str(item_variant.get("status", ""))
		_expect(statuses.get("contract_response") == "RETIRED", "legacy response is retired")
		_expect(statuses.get("contract_offer_v06") == "RETIRED", "legacy anonymous contract offer is retired")
		_expect(statuses.get("legacy_contract_trace_intel_card") == "RETIRED", "contract-party trace cards are retired without replacement")
		_expect(statuses.get("card_counter_response") == "ACTIVE", "card counter remains active")
		_expect(statuses.get("monster_wager_response") == "ACTIVE", "monster wager remains active")
		_expect(statuses.get("card_target_choice") == "ACTIVE", "card target choice remains active")
		_expect(statuses.get("conditional_order_auto_settlement") == "ACTIVE", "automatic conditional orders remain active")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("V06_MECHANIC_AUTHORITY_GATE_PASS")
		quit(0)
	else:
		print("V06_MECHANIC_AUTHORITY_GATE_FAIL (%d)" % failures.size())
		quit(1)
