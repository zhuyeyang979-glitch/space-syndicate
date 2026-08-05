extends SceneTree

const Support := preload("res://tests/v074_planet_test_support.gd")
const Layout := preload("res://scripts/ui/v074/v074_responsive_table_layout.gd")
const Audit := preload("res://scripts/ui/v074/v074_ui_layout_collision_audit_v1.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array = []
	var checks := 0
	var layout_owner := Layout.new()
	var audit_owner := Audit.new()
	var cases := [
		{"size": Vector2(1366, 768), "players": 4, "mode": "COMPACT_DESKTOP", "minimum": 220.0},
		{"size": Vector2(1600, 960), "players": 4, "mode": "REGULAR_DESKTOP", "minimum": 340.0},
		{"size": Vector2(1920, 1080), "players": 8, "mode": "WIDE_DESKTOP", "minimum": 460.0},
	]
	for case_variant in cases:
		var case := case_variant as Dictionary
		var layout := layout_owner.resolve(case.get("size", Vector2.ZERO), int(case.get("players", 4)))
		var audit := audit_owner.audit_layout(layout)
		checks += 1
		Support.add_failure(failures, str(layout.get("mode", "")) == str(case.get("mode", "")), "responsive mode mismatch")
		checks += 1
		Support.add_failure(failures, float((layout.get("planet_rect", Rect2()) as Rect2).size.y) >= float(case.get("minimum", 0.0)), "planet stage below minimum")
		checks += 1
		Support.add_failure(failures, int(audit.get("unintended_major_panel_intersection_count", -1)) == 0, "major layout intersection")
		checks += 1
		Support.add_failure(failures, int(layout.get("marker_panel_header_width_consumption", -1)) == 0, "marker consumes header width")
		checks += 1
		Support.add_failure(failures, bool(layout.get("target_rail_virtualized", false)) and not bool(layout.get("target_rail_primary_surface", true)), "TargetRail contract mismatch")
		var content_rect := layout.get("content_rect", Rect2()) as Rect2
		checks += 1
		Support.add_failure(
			failures,
			content_rect.encloses(
				layout.get("hand_dock_rect", Rect2()) as Rect2
			),
			"hand dock escaped responsive content rect"
		)
	var scaled_cases := [
		{
			"physical": Vector2(1366, 768),
			"logical": Vector2(1707, 960),
			"mode": "COMPACT_DESKTOP",
			"minimum": 220.0,
		},
		{
			"physical": Vector2(1600, 960),
			"logical": Vector2(1600, 960),
			"mode": "REGULAR_DESKTOP",
			"minimum": 340.0,
		},
		{
			"physical": Vector2(1920, 1080),
			"logical": Vector2(1706, 960),
			"mode": "WIDE_DESKTOP",
			"minimum": 460.0,
		},
	]
	for case_variant in scaled_cases:
		var case := case_variant as Dictionary
		var layout := layout_owner.resolve_for_window(
			case.get("physical", Vector2.ZERO),
			case.get("logical", Vector2.ZERO),
			int(case.get("players", 4))
		)
		var logical_per_physical := (
			layout.get(
				"logical_units_per_physical_pixel",
				Vector2.ONE
			) as Vector2
		)
		var planet := layout.get("planet_rect", Rect2()) as Rect2
		var physical_planet_height := (
			planet.size.y / maxf(0.0001, logical_per_physical.y)
		)
		checks += 1
		Support.add_failure(
			failures,
			str(layout.get("mode", "")) == str(case.get("mode", "")),
			"physical-window responsive mode mismatch"
		)
		checks += 1
		Support.add_failure(
			failures,
			physical_planet_height >= float(case.get("minimum", 0.0)),
			"physical planet stage below minimum"
		)
		checks += 1
		Support.add_failure(
			failures,
			(layout.get("viewport_size", Vector2.ZERO) as Vector2).is_equal_approx(
				case.get("logical", Vector2.ZERO) as Vector2
			),
			"scaled layout does not retain logical viewport"
		)
		checks += 1
		Support.add_failure(
			failures,
			int(
				audit_owner.audit_layout(layout).get(
					"unintended_major_panel_intersection_count",
					-1
				)
			) == 0,
			"scaled layout intersection"
		)
	Support.print_result("V074_RESPONSIVE_TABLE_LAYOUT_TEST", checks, failures, self)
