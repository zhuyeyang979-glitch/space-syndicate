extends SceneTree

const INSPECTOR := preload("res://scripts/tools/card_inventory_checkpoint_purity_inspector_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	# Frozen v1 composite fixture from the V7 failure boundary. Live District
	# checkpoints now use the v2 canonical string-key map and must stay green.
	var historical_v1 := {
		"captured": true,
		"schema_version": 1,
		"children": {
			"commodity_card_inventory": {"schema_version": 1},
			"product_market": {"schema_version": 1},
			"district_purchase": {
				"schema_version": 1,
				"windows_by_player": {
					0: {"player_index": 0, "state": "active"},
				},
			},
		},
		"modes": {
			"commodity_card_inventory": "runtime",
			"product_market": "runtime",
			"district_purchase": "runtime",
		},
	}
	var report := INSPECTOR.inspect(historical_v1)
	_expect(not bool(report.get("payload_pure_data", true)), "V7 Owner codec rejects the frozen integer-key checkpoint")
	_expect(int(report.get("non_pure_leaf_count", 0)) == 1, "exactly one V7-incompatible leaf is preserved")
	_expect(str(report.get("first_non_pure_child_id", "")) == "district_purchase", "District Purchase remains the attested child")
	_expect(str(report.get("first_non_pure_path", "")) == "$.children.district_purchase.windows_by_player.<non_string_key:int>", "historical first path remains exact")
	_expect(str(report.get("first_non_pure_variant_type", "")) == "int", "historical first Variant type remains int")
	_expect(str(report.get("first_non_pure_reason", "")) == "dictionary_key_not_owner_codec_compatible", "historical typed reason remains exact")
	var redaction := INSPECTOR.inspect({"children": {"district_purchase": {"windows_by_player": {"private-player-key": 1.5}}}})
	var strict := redaction.get("strict_non_closed_leaves", []) as Array
	var redacted_path := str((strict[0] as Dictionary).get("json_path", "")) if not strict.is_empty() else ""
	_expect(redacted_path.contains("<redacted:") and not redacted_path.contains("private-player-key"), "dynamic keys remain fingerprint-redacted")
	print("ALPHA04C_CARD_INVENTORY_V7_FAILURE_PATH_CHARACTERIZATION_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(),
	])
	if not _failures.is_empty():
		push_error("V7 historical failure-path characterization failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
