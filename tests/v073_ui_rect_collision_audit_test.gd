extends SceneTree

const Support := preload("res://tests/support/v073_ui_globe_test_support.gd")
const CASE_ID := "ui_rect_collision_audit"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := await Support.run_case(self, CASE_ID)
	var failures := result.get("failures", []) as Array
	var checks := int(result.get("checks", 0))
	var passed := failures.is_empty()
	print("V073_UI_RECT_COLLISION_AUDIT_TEST|status=%s|passed=%d|total=%d|details=%s" % [
		"PASS" if passed else "FAIL",
		checks - failures.size(),
		checks,
		JSON.stringify(failures),
	])
	quit(0 if passed else 1)
