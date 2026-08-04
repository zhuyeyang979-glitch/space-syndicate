extends Control
class_name V074MapGenesisBench

@export_range(1, 2000, 1) var sample_count := 63

@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	call_deferred("_run_bench")


func _run_bench() -> void:
	status_label.text = "Running V0.7.4 authoritative map genesis audit..."
	var focused := V074MapGenesisAudit.run_focused()
	var statistics := V074MapGenesisAudit.run_sample_suite(sample_count)
	var passed := bool(focused.get("success", false)) and bool(statistics.get("success", false))
	status_label.text = "PASS" if passed else "FAIL"
	print("V074_MAP_GENESIS_BENCH|status=%s|focused=%s|statistics=%s" % [
		"PASS" if passed else "FAIL",
		JSON.stringify(focused),
		JSON.stringify(statistics),
	])
	get_tree().quit(0 if passed else 1)
