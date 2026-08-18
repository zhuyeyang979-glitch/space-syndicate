extends SceneTree

func _init() -> void:
	print("RUNNER_RAW_NUL|" + String.chr(0) + "|CONTROL")
	print("GODOT_TEST_RUNNER_FIXTURE_COMPLETE")
	quit(0)
