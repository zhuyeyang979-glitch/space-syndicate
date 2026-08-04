extends SceneTree

const Support := preload("res://tests/v074_planet_test_support.gd")
const Audit := preload("res://scripts/ui/v074/v074_ui_layout_collision_audit_v1.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array = []
	var checks := 0
	var controls: Array = [
		{"node_path": "Header", "global_rect": Rect2(0, 0, 1000, 80), "visible": true, "interactive": true, "mouse_filter": Control.MOUSE_FILTER_STOP},
		{"node_path": "Planet", "global_rect": Rect2(180, 190, 820, 430), "visible": true, "interactive": true, "mouse_filter": Control.MOUSE_FILTER_STOP},
		{"node_path": "Roster", "global_rect": Rect2(0, 190, 170, 430), "visible": true, "interactive": true, "mouse_filter": Control.MOUSE_FILTER_STOP},
		{"node_path": "Modal", "global_rect": Rect2(240, 230, 500, 300), "visible": true, "interactive": true, "mouse_filter": Control.MOUSE_FILTER_STOP, "overlap_kind": "modal"},
	]
	var result := Audit.new().audit_controls(controls, Rect2(0, 0, 1000, 700))
	checks += 1
	Support.add_failure(failures, int(result.get("unintended_major_panel_intersection_count", -1)) == 0, "intentional modal overlap misclassified")
	checks += 1
	Support.add_failure(failures, int(result.get("offscreen_count", -1)) == 0, "onscreen controls marked offscreen")
	var colliding := controls.duplicate(true)
	(colliding[2] as Dictionary)["global_rect"] = Rect2(150, 190, 170, 430)
	var collision_result := Audit.new().audit_controls(colliding, Rect2(0, 0, 1000, 700))
	checks += 1
	Support.add_failure(failures, int(collision_result.get("unintended_major_panel_intersection_count", 0)) == 1, "real overlap not detected")
	checks += 1
	Support.add_failure(failures, int(collision_result.get("interactive_control_occlusion_count", 0)) == 1, "input occlusion not detected")
	Support.print_result("V074_UI_COLLISION_AUDIT_TEST", checks, failures, self)
