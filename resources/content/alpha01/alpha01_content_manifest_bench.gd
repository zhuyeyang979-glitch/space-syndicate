extends Node

@export var manifest: Resource
@export_range(1.0, 60.0, 1.0) var mcp_inspection_seconds := 30.0

var _exit_code := 1


func _ready() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	if manifest == null:
		print("ALPHA01_CONTENT_MANIFEST_BENCH|status=FAIL|errors=[\"manifest_resource_missing\"]")
		_begin_inspection_window(1)
		return
	var report: Dictionary = manifest.call("validation_report")
	var status: String = "PASS" if bool(report.get("valid", false)) else "FAIL"
	print("ALPHA01_CONTENT_MANIFEST_BENCH|status=%s|selection_sha256=%s|counts=%s|errors=%s" % [
		status,
		str(report.get("selection_sha256", "")),
		JSON.stringify(report.get("counts", {})),
		JSON.stringify(report.get("errors", [])),
	])
	_begin_inspection_window(0 if status == "PASS" else 1)


func _begin_inspection_window(exit_code: int) -> void:
	_exit_code = exit_code
	get_tree().create_timer(mcp_inspection_seconds).timeout.connect(_quit_after_inspection)


func _quit_after_inspection() -> void:
	get_tree().quit(_exit_code)
