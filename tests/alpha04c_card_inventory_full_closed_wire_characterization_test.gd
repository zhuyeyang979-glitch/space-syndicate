extends SceneTree

const EVIDENCE_PATH := "res://reports/handoffs/alpha04c_card_inventory_save_v4_pre_edit_characterization.json"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var evidence := _read_evidence()
	_expect(not evidence.is_empty(), "frozen pre-edit characterization evidence is readable")
	if not evidence.is_empty():
		var persistent := evidence.get("persistent_save", {}) as Dictionary
		var checkpoint := evidence.get("runtime_checkpoint", {}) as Dictionary
		var persistent_types := persistent.get("type_counts", {}) as Dictionary
		var checkpoint_types := checkpoint.get("type_counts", {}) as Dictionary
		var defects := evidence.get("required_defects_reconfirmed", {}) as Dictionary
		var additional := evidence.get("additional_characterized_condition", {}) as Dictionary
		var v7 := evidence.get("immutable_v7", {}) as Dictionary
		_expect(str(evidence.get("status", "")) == "PRE_EDIT_CHARACTERIZATION_COMPLETE" \
				and str(evidence.get("baseline_sha", "")) == "9d823a6ad3ba9d5464cc47ec8a96405cc75a9187", \
				"evidence is bound to the production pre-edit baseline")
		_expect(int(persistent.get("leaf_count", 0)) == 2137 \
				and int(persistent.get("non_closed_leaf_count", 0)) == 456 \
				and persistent_types.size() == 1 \
				and int(persistent_types.get("float", -1)) == 456, \
				"persistent Save v3 frozen characterization remains 456 non-closed floats")
		_expect(int(checkpoint.get("leaf_count", 0)) == 2343 \
				and int(checkpoint.get("non_closed_leaf_count", 0)) == 503 \
				and checkpoint_types.size() == 2 \
				and int(checkpoint_types.get("float", -1)) == 502 \
				and int(checkpoint_types.get("int", -1)) == 1, \
				"runtime checkpoint v1 frozen characterization remains 502 floats plus one integer key")
		_expect(bool(defects.get("district_int_key_defect_present", false)) \
				and bool(defects.get("product_growth_float_defect_present", false)) \
				and bool(defects.get("market_timer_float_defect_present", false)), \
				"all three authorized defect families remain attested")
		_expect(str(additional.get("path", "")) == "district_purchase.pending_payload.opened_at" \
				and str(additional.get("classification", "")) == "presentation_only_non_authoritative_metadata" \
				and int(additional.get("production_reader_count", -1)) == 0, \
				"the additional District float remains explicitly classified as presentation-only")
		_expect(int(evidence.get("forbidden_dependency_type_count", -1)) == 0, \
				"no Object, Node, Resource, Callable, or RID was present before editing")
		_expect(int(v7.get("targeted_owner_capture_diagnostic_count", 0)) == 7 \
				and str(v7.get("registry_owner_capture", "")) == "7/19" \
				and int(v7.get("failing_owner_index", -1)) == 7 \
				and str(v7.get("failing_owner_id", "")) == "card_inventory" \
				and str(v7.get("failure_reason", "")) == "owner_checkpoint_not_pure_data", \
				"immutable V7 failure identity remains 7/19 at Card Inventory")
		_expect(str(v7.get("quota_ledger_sha256", "")) == "607f1a15d875321a368ab071b35693857d7acf32063b4ed5578fa4f4aea9f826" \
				and str(v7.get("failure_phase_0024_sha256", "")) == "eba66bdf8edc55071b862a6b1c9d1ab8073d130335408bcf76be9c373538b778", \
				"immutable V7 ledger and first-failure phase hashes remain pinned")
	print("ALPHA04C_CARD_INVENTORY_FULL_CLOSED_WIRE_CHARACTERIZATION_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Frozen Card Inventory characterization failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _read_evidence() -> Dictionary:
	var file := FileAccess.open(EVIDENCE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
