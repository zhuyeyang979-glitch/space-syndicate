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
	var runtime_overflow := Audit.new().audit_runtime_geometry({
		"viewport_rect": Rect2(0, 0, 1600, 960),
		"header_rect": Rect2(12, -40, 1576, 94),
		"track_rect": Rect2(12, 59, 1576, 172),
		"roster_rect": Rect2(12, 236, 204, 486),
		"planet_board_rect": Rect2(222, 236, 1366, 486),
		"target_rail_rect": Rect2(12, 727, 1576, 56),
		"hand_dock_rect": Rect2(12, 788, 1576, 212),
		"planet_stage_rect": Rect2(223, 261, 1364, 460),
		"planet_map_rect": Rect2(223, 261, 1364, 460),
		"minimum_planet_height": 340.0,
	})
	checks += 1
	Support.add_failure(
		failures,
		int(runtime_overflow.get("header_overflow_count", 0)) == 1,
		"runtime header overflow was masked"
	)
	var runtime_green := Audit.new().audit_runtime_geometry({
		"viewport_rect": Rect2(0, 0, 1600, 960),
		"header_rect": Rect2(12, 12, 1576, 94),
		"track_rect": Rect2(12, 111, 1576, 172),
		"roster_rect": Rect2(12, 288, 204, 382),
		"planet_board_rect": Rect2(222, 288, 1366, 382),
		"target_rail_rect": Rect2(12, 675, 1576, 56),
		"hand_dock_rect": Rect2(12, 736, 1576, 212),
		"planet_stage_rect": Rect2(223, 313, 1364, 356),
		"planet_map_rect": Rect2(223, 313, 1364, 356),
		"minimum_planet_height": 340.0,
	})
	checks += 1
	Support.add_failure(
		failures,
		int(runtime_green.get("header_overflow_count", -1)) == 0
		and bool(runtime_green.get("planet_height_green", false)),
		"valid runtime geometry failed responsive audit"
	)
	Support.print_result("V074_UI_COLLISION_AUDIT_TEST", checks, failures, self)
