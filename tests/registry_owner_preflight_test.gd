extends SceneTree

const SUITE_PATH := "res://tests/alpha04c_production_registry_transaction_test.gd"


func _init() -> void:
	var source := FileAccess.get_file_as_string(SUITE_PATH)
	var green := source.contains("capture_all_sections_detailed") \
			and source.contains('int(detailed_capture.get("section_count", 0)) == 19') \
			and source.contains('int(preflight.get("preflight_count", 0)) == 19') \
			and source.contains("detailed_state_before == detailed_state_between")
	print("REGISTRY_OWNER_PREFLIGHT_TEST|status=%s|checks=4|failures=%d" % [
		"PASS" if green else "FAIL", 0 if green else 1,
	])
	if not green:
		push_error("Registry Owner preflight suite contract missing")
	quit(0 if green else 1)
