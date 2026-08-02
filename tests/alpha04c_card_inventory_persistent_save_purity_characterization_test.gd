extends SceneTree

const INSPECTOR := preload("res://scripts/tools/card_inventory_checkpoint_purity_inspector_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	# This is an immutable v3 wire fixture. Production now emits v4, so the
	# historical defect proof must not execute old assertions against live code.
	var historical_v3 := {
		"schema_version": 3,
		"ruleset_id": "v0.6",
		"commodity_card_inventory": {"state_version": 1},
		"product_market": {
			"state_version": 1,
			"ruleset_id": "v0.6",
			"product_market": {
				"<redacted-product>": {"growth_multiplier": 1.25},
			},
			"business_cycle_count": 0,
			"market_timer": 8.5,
			"futures_position_sequence": 0,
		},
		"district_purchase": {"district_purchase_runtime": {"schema_version": 3}},
	}
	var report := INSPECTOR.inspect(historical_v3, {
		"commodity_card_inventory": "to_save_data",
		"product_market": "to_save_data",
		"district_purchase": "to_save_data",
	})
	var leaves := report.get("strict_non_closed_leaves", []) as Array
	var paths: Array[String] = []
	for leaf_variant in leaves:
		paths.append(str((leaf_variant as Dictionary).get("json_path", "")))
	_expect(bool(report.get("payload_pure_data", false)), "historical V7 Owner codec accepts finite v3 floats")
	_expect(not bool(report.get("strict_closed_data", true)), "SemanticWire rejects the historical raw-float wire")
	_expect(int(report.get("strict_non_closed_leaf_count", 0)) == 2, "historical fixture exposes exactly two focused Product Market floats")
	_expect((report.get("strict_non_closed_type_counts", {}) as Dictionary) == {"float": 2}, "historical non-closed type count is stable")
	_expect(paths.any(func(path: String) -> bool: return path.ends_with(".growth_multiplier")), "growth multiplier defect remains attested")
	_expect(paths.any(func(path: String) -> bool: return path.ends_with(".market_timer")), "market timer defect remains attested")
	_expect(leaves.all(func(leaf: Dictionary) -> bool: return str(leaf.get("source_child_id", "")) == "product_market"), "both focused defects belong to Product Market")
	print("ALPHA04C_CARD_INVENTORY_PERSISTENT_SAVE_PURITY_CHARACTERIZATION_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(),
	])
	if not _failures.is_empty():
		push_error("Persistent Save historical characterization failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
