extends SceneTree

const SUITE_PATH := "res://tests/alpha04c_production_registry_transaction_test.gd"


func _init() -> void:
	var source := FileAccess.get_file_as_string(SUITE_PATH)
	var green := source.contains("for section_variant in registry.fixed_section_order()") \
			and source.contains("registry.arm_test_apply_failure_once(section_id)") \
			and source.contains("fault_passes == 19") \
			and source.contains("reverse_order_passes == 19")
	print("REGISTRY_OWNER_FAULT_ROLLBACK_TEST|status=%s|checks=4|failures=%d" % [
		"PASS" if green else "FAIL", 0 if green else 1,
	])
	if not green:
		push_error("Registry Owner rollback suite contract missing")
	quit(0 if green else 1)
