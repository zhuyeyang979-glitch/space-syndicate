extends SceneTree


func _init() -> void:
	var scene := load("res://scenes/tools/BankruptcyNeutralEstateRuntimeBench.tscn") as PackedScene
	if scene == null:
		push_error("Bankruptcy neutral-estate bench scene failed to load.")
		quit(1)
		return
	var bench := scene.instantiate()
	bench.connect("bench_finished", func(exit_code: int) -> void: quit(exit_code))
	root.add_child(bench)
