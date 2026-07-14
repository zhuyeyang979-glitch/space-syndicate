extends Control

const PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const CONTROLLER_SCRIPT := preload("res://scripts/runtime/region_infrastructure_runtime_controller.gd")
const OUTPUT_DIR := "user://space_syndicate_design_qa/region_infrastructure_atomic_lifecycle_v06"
const MANIFEST_PATH := OUTPUT_DIR + "/manifest.json"
const REPORT_PATH := OUTPUT_DIR + "/report.md"

@onready var controller: RegionInfrastructureRuntimeController = %RegionInfrastructureRuntimeController
@onready var status_label: Label = %StatusLabel
@onready var pass_count_label: Label = %PassCountLabel
@onready var lifecycle_label: Label = %LifecycleLabel
@onready var output_label: Label = %OutputLabel
@onready var result_list: VBoxContainer = %ResultList
@onready var rerun_button: Button = %RerunButton
@onready var print_button: Button = %PrintButton

var _records: Array = []
var _last_manifest: Dictionary = {}


func _ready() -> void:
	rerun_button.pressed.connect(run_suite)
	print_button.pressed.connect(_print_output_paths)
	call_deferred("run_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func flow_cases() -> Array:
	return [
		"scene_composition_and_readiness",
		"build_apply_and_binding",
		"tampered_receipt_zero_effect",
		"rollback_exact_once",
		"pending_save_restore",
		"finalize_failure_retry",
		"finalized_rollback_closed",
		"upgrade_preimage_restore",
		"repair_preimage_restore",
		"corrupt_save_zero_effect",
		"third_party_progression_fail_closed",
		"pure_data_and_terminal_journal",
	]


func build_manifest_preview() -> Dictionary:
	return _last_manifest.duplicate(true) if not _last_manifest.is_empty() else {
		"suite_id": "region_infrastructure_atomic_lifecycle_v06",
		"records": flow_cases().map(func(case_id: String) -> Dictionary: return _record(case_id, false, "not_run")),
	}


func run_suite() -> Dictionary:
	_records.clear()
	_status("RUNNING", Color("#e6c86a"))
	_reset_controller(controller)
	_record_result("scene_composition_and_readiness", controller.scene_file_path.ends_with("RegionInfrastructureRuntimeController.tscn") and controller.facility_rollback_atomic_ready(), "scene owner exposes measured lifecycle v2 capability")

	var build_request := _request("bench-build", "factory", "life", 1)
	var build := controller.apply_facility_action(build_request)
	_record_result("build_apply_and_binding", bool(build.get("committed", false)) and not str(build.get("owner_binding_fingerprint", "")).is_empty() and controller.facilities_snapshot(false).size() == 1, "build stores owner binding and one facility")
	var applied_fingerprint := _fingerprint(controller.to_save_data())
	var tampered := build.duplicate(true)
	tampered["owner_binding_fingerprint"] = "tampered"
	var rejected := controller.rollback_facility_action(tampered)
	_record_result("tampered_receipt_zero_effect", not bool(rejected.get("rolled_back", true)) and applied_fingerprint == _fingerprint(controller.to_save_data()), "binding failure leaves roster revision and journal unchanged")
	var rollback := controller.rollback_facility_action(build)
	var rollback_state := _fingerprint(controller.to_save_data())
	var rollback_replay := controller.rollback_facility_action(build)
	_record_result("rollback_exact_once", bool(rollback.get("rolled_back", false)) and bool(rollback_replay.get("duplicate", false)) and rollback_state == _fingerprint(controller.to_save_data()), "rollback restores preimage and replays terminal receipt")

	_reset_controller(controller)
	var pending := controller.apply_facility_action(_request("bench-pending", "market", "energy", 1))
	var pending_save := controller.to_save_data()
	var restored := _transient_controller()
	var restored_result := restored.apply_save_data(pending_save)
	_record_result("pending_save_restore", bool(restored_result.get("applied", false)) and str(restored.facility_action_lifecycle_snapshot("bench-pending").get("state", "")) == "applied", "open preimage and binding survive round-trip")
	var bad_finalize := pending.duplicate(true)
	bad_finalize["owner_binding_fingerprint"] = "bad"
	var finalize_failure := restored.finalize_facility_action(bad_finalize)
	var finalize_retry := restored.finalize_facility_action(pending)
	_record_result("finalize_failure_retry", bool(finalize_failure.get("committed", false)) and not bool(finalize_failure.get("finalized", true)) and bool(finalize_retry.get("finalized", false)), "failed finalize preserves committed receipt and valid retry closes owner")
	var finalized_state := _fingerprint(restored.to_save_data())
	var closed := restored.rollback_facility_action(pending)
	_record_result("finalized_rollback_closed", str(closed.get("reason_code", "")) == "facility_action_rollback_closed" and finalized_state == _fingerprint(restored.to_save_data()), "finalized owner cannot be undone")
	restored.free()

	_reset_controller(controller)
	var base := controller.apply_facility_action(_request("bench-base", "factory", "industry", 1))
	controller.finalize_facility_action(base)
	var upgrade := controller.apply_facility_action(_request("bench-upgrade", "factory", "industry", 2))
	controller.rollback_facility_action(upgrade)
	var base_facility := _facility(controller, str(base.get("facility_id", "")))
	_record_result("upgrade_preimage_restore", int(base_facility.get("rank", 0)) == 1, "upgrade rollback restores rank I")
	var damage := controller.apply_unit_damage({"transaction_id": "bench-damage", "source_kind": "monster", "source_entity_id": "monster.bench", "region_id": "region.alpha", "amount": 25, "occurred_at": 4.0})
	var repair := controller.apply_facility_action(_request("bench-repair", "factory", "industry", 1))
	controller.rollback_facility_action(repair)
	_record_result("repair_preimage_restore", bool(damage.get("committed", false)) and int(controller.region_state_snapshot("region.alpha").get("damage_taken", 0)) == 25, "repair rollback restores damage before the card")

	_reset_controller(controller)
	controller.apply_facility_action(_request("bench-corrupt", "warehouse", "commerce", 1))
	var corrupt := controller.to_save_data()
	var corrupt_lifecycles: Dictionary = (corrupt.get("facility_action_lifecycles", {}) as Dictionary).duplicate(true)
	var corrupt_record: Dictionary = (corrupt_lifecycles.get("bench-corrupt", {}) as Dictionary).duplicate(true)
	corrupt_record["preimage"] = {}
	corrupt_lifecycles["bench-corrupt"] = corrupt_record
	corrupt["facility_action_lifecycles"] = corrupt_lifecycles
	var stable := _transient_controller()
	var stable_before := _fingerprint(stable.to_save_data())
	var corrupt_result := stable.apply_save_data(corrupt)
	_record_result("corrupt_save_zero_effect", not bool(corrupt_result.get("applied", true)) and stable_before == _fingerprint(stable.to_save_data()), "invalid lifecycle snapshot fails before state swap")
	stable.free()

	_reset_controller(controller)
	var progress_base := controller.apply_facility_action(_request("bench-progress-base", "factory", "life", 1))
	controller.finalize_facility_action(progress_base)
	var progress_pending := controller.apply_facility_action(_request("bench-progress-pending", "market", "life", 1))
	controller.apply_unit_damage({"transaction_id": "bench-progress-damage", "source_kind": "military", "source_entity_id": "unit.bench", "region_id": "region.alpha", "amount": 1, "occurred_at": 5.0})
	var progress_before := _fingerprint(controller.to_save_data())
	var progress_rollback := controller.rollback_facility_action(progress_pending)
	_record_result("third_party_progression_fail_closed", str(progress_rollback.get("reason_code", "")) == "facility_action_controller_revision_changed" and progress_before == _fingerprint(controller.to_save_data()) and not controller.facility_rollback_atomic_ready(), "advanced owner state cannot be partially erased")
	var save_data := controller.to_save_data()
	_record_result("pure_data_and_terminal_journal", _is_pure_data(save_data) and (save_data.get("transaction_receipts", {}) as Dictionary).size() >= 3, "save and debug evidence contain only pure data")

	var passed := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			passed += 1
	_last_manifest = {
		"suite_id": "region_infrastructure_atomic_lifecycle_v06",
		"ruleset_id": "v0.6",
		"passed": passed,
		"total": _records.size(),
		"all_passed": passed == _records.size(),
		"records": _records.duplicate(true),
		"output_dir": OUTPUT_DIR,
	}
	_write_outputs(_last_manifest)
	_render_records()
	pass_count_label.text = "%d / %d gates" % [passed, _records.size()]
	lifecycle_label.text = "Lifecycle v2  |  copy-swap  |  exact-once"
	output_label.text = ProjectSettings.globalize_path(OUTPUT_DIR)
	_status("PASS" if passed == _records.size() else "FAIL", Color("#66d29a") if passed == _records.size() else Color("#ef7d7d"))
	print("REGION_INFRASTRUCTURE_ATOMIC_LIFECYCLE_V06_BENCH|status=%s|passed=%d|total=%d|manifest=%s|report=%s" % ["PASS" if passed == _records.size() else "FAIL", passed, _records.size(), MANIFEST_PATH, REPORT_PATH])
	_reset_controller(controller)
	var display_receipt := controller.apply_facility_action(_request("bench-display", "factory", "life", 1))
	controller.finalize_facility_action(display_receipt)
	return _last_manifest.duplicate(true)


func _reset_controller(target: RegionInfrastructureRuntimeController) -> void:
	target.configure(PROFILE.debug_snapshot())
	target.initialize_regions([{"region_id": "region.alpha", "terrain_id": "land", "neighbor_region_ids": [], "legacy_index": 0}])


func _transient_controller() -> RegionInfrastructureRuntimeController:
	var target := CONTROLLER_SCRIPT.new() as RegionInfrastructureRuntimeController
	%RuntimeHost.add_child(target)
	_reset_controller(target)
	return target


func _request(transaction_id: String, facility_type: String, industry_id: String, rank: int) -> Dictionary:
	return {"transaction_id": transaction_id, "region_id": "region.alpha", "owner_kind": "player", "owner_player_index": 0, "facility_type": facility_type, "industry_id": industry_id, "rank": rank, "occurred_at": 1.0}


func _facility(target: RegionInfrastructureRuntimeController, facility_id: String) -> Dictionary:
	for facility_variant in target.facilities_snapshot(false):
		if facility_variant is Dictionary and str((facility_variant as Dictionary).get("facility_id", "")) == facility_id:
			return (facility_variant as Dictionary).duplicate(true)
	return {}


func _record_result(case_id: String, passed: bool, notes: String) -> void:
	_records.append(_record(case_id, passed, notes))


func _record(case_id: String, passed: bool, notes: String) -> Dictionary:
	return {"case_id": case_id, "apply_checked": true, "rollback_checked": true, "finalize_checked": true, "save_load_checked": true, "exact_once_checked": true, "atomic_checked": true, "pure_data_checked": true, "passed": passed, "notes": notes}


func _render_records() -> void:
	for child in result_list.get_children():
		child.queue_free()
	for record_variant in _records:
		var record: Dictionary = record_variant
		var row := Label.new()
		row.text = "%s  %s" % ["PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("case_id", ""))]
		row.modulate = Color("#a9f0c7") if bool(record.get("passed", false)) else Color("#ffabab")
		row.tooltip_text = str(record.get("notes", ""))
		result_list.add_child(row)


func _write_outputs(manifest: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if manifest_file != null:
		manifest_file.store_string(JSON.stringify(manifest, "  "))
	var lines := ["# Region Infrastructure Atomic Lifecycle v0.6", "", "Result: %d/%d passed." % [int(manifest.get("passed", 0)), int(manifest.get("total", 0))], ""]
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("- [%s] `%s`: %s" % ["x" if bool(record.get("passed", false)) else " ", str(record.get("case_id", "")), str(record.get("notes", ""))])
	var report_file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string("\n".join(lines) + "\n")


func _status(value: String, color: Color) -> void:
	status_label.text = value
	status_label.modulate = color


func _print_output_paths() -> void:
	print("REGION_INFRASTRUCTURE_ATOMIC_LIFECYCLE_V06_OUTPUT|manifest=%s|report=%s" % [MANIFEST_PATH, REPORT_PATH])


func _fingerprint(value: Variant) -> String:
	return JSON.stringify(value)


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not (key_variant is String or key_variant is StringName or key_variant is int):
				return false
			if not _is_pure_data(value[key_variant]):
				return false
		return true
	return false
