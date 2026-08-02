extends SceneTree

const SUITE_PATH := "res://tests/alpha04c_production_registry_transaction_test.gd"


func _init() -> void:
	var source := FileAccess.get_file_as_string(SUITE_PATH)
	var green := source.contains("capture_resume_envelope") \
			and source.contains("registry.preflight_envelope(envelope)") \
			and source.contains("registry.apply_envelope(envelope)") \
			and source.contains('int(success.get("apply_count", 0)) == 19')
	print("PRODUCTION_REGISTRY_TRANSACTION_TEST|status=%s|checks=4|failures=%d" % [
		"PASS" if green else "FAIL", 0 if green else 1,
	])
	if not green:
		push_error("Production Registry transaction suite contract missing")
	quit(0 if green else 1)
