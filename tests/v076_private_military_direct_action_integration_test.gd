extends SceneTree

const BENCH := preload(
	"res://scenes/tools/v076/V076PrivateMilitaryDirectActionBench.tscn"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bench := BENCH.instantiate()
	if bench == null:
		push_error("V076 private military Direct Action Bench failed to instantiate")
		quit(1)
		return
	root.add_child(bench)
