extends SceneTree

const SUITE := preload("res://tests/ai_runtime_save_v3_suite.gd")


func _init() -> void:
	call_deferred("_run")


func _focus() -> String:
	return "unknown"


func _run() -> void:
	var result := await SUITE.run(self, _focus())
	var failures := result.get("failures", []) as Array
	print("%s|status=%s|checks=%d|failures=%d" % [
		_focus().to_upper(),
		"PASS" if failures.is_empty() else "FAIL",
		int(result.get("checks", 0)),
		failures.size(),
	])
	for failure in failures:
		push_error(str(failure))
	quit(0 if failures.is_empty() else 1)
