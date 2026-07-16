extends SceneTree

const COMPLETION_MARKER := "GODOT_TEST_RUNNER_FIXTURE_COMPLETE"


func _init() -> void:
	print(COMPLETION_MARKER)
	quit(0)
