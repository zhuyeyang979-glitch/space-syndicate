extends RefCounted
class_name V074ResponsiveTableLayout

const COMPACT_DESKTOP := "COMPACT_DESKTOP"
const REGULAR_DESKTOP := "REGULAR_DESKTOP"
const WIDE_DESKTOP := "WIDE_DESKTOP"
const SAFE_MARGIN := 12.0
const MIN_PLANET_HEIGHT := {
	COMPACT_DESKTOP: 220.0,
	REGULAR_DESKTOP: 340.0,
	WIDE_DESKTOP: 460.0,
}


func resolve(viewport_size: Vector2, player_count: int) -> Dictionary:
	var safe_size := Vector2(maxf(960.0, viewport_size.x), maxf(640.0, viewport_size.y))
	var mode := _mode_for(safe_size, player_count)
	var metrics := _metrics(mode, player_count)
	var content := Rect2(Vector2.ONE * SAFE_MARGIN, safe_size - Vector2.ONE * SAFE_MARGIN * 2.0)
	var primary_header := Rect2(content.position, Vector2(content.size.x, float(metrics["primary_header_height"])))
	var utility_header := Rect2(
		Vector2(content.position.x, primary_header.end.y),
		Vector2(content.size.x, float(metrics["utility_header_height"]))
	)
	var track := Rect2(
		Vector2(content.position.x, utility_header.end.y + 6.0),
		Vector2(content.size.x, float(metrics["track_height"]))
	)
	var hand_dock := Rect2(
		Vector2(content.position.x, content.end.y - float(metrics["hand_dock_height"])),
		Vector2(content.size.x, float(metrics["hand_dock_height"]))
	)
	var table_top := track.end.y + 8.0
	var table_bottom := hand_dock.position.y - 8.0
	var table := Rect2(
		Vector2(content.position.x, table_top),
		Vector2(content.size.x, maxf(0.0, table_bottom - table_top))
	)
	var roster_width := float(metrics["roster_width"])
	var roster := Rect2(table.position, Vector2(roster_width, table.size.y))
	var target_height := float(metrics["target_rail_height"])
	var planet_column := Rect2(
		Vector2(roster.end.x + 8.0, table.position.y),
		Vector2(maxf(0.0, table.end.x - roster.end.x - 8.0), table.size.y)
	)
	var target_rail := Rect2(
		Vector2(planet_column.position.x, planet_column.end.y - target_height),
		Vector2(planet_column.size.x, target_height)
	)
	var planet := Rect2(
		planet_column.position,
		Vector2(planet_column.size.x, maxf(0.0, planet_column.size.y - target_height - 6.0))
	)
	var minimum_planet_height := float(MIN_PLANET_HEIGHT[mode])
	var marker_button := Rect2(
		Vector2(utility_header.end.x - 38.0, utility_header.position.y + 3.0),
		Vector2(34.0, maxf(28.0, utility_header.size.y - 6.0))
	)
	var marker_panel := Rect2(
		Vector2(roster.position.x + 6.0, roster.end.y - 132.0),
		Vector2(maxf(148.0, roster.size.x - 12.0), 126.0)
	)
	var camera_controls := Rect2(
		Vector2(planet.end.x - 154.0, planet.position.y + 8.0),
		Vector2(146.0, 38.0)
	)
	return {
		"schema": "V074ResponsiveTableLayoutV1",
		"mode": mode,
		"viewport_size": safe_size,
		"player_count": clampi(player_count, 1, 8),
		"content_rect": content,
		"primary_header_rect": primary_header,
		"utility_header_rect": utility_header,
		"track_rect": track,
		"table_rect": table,
		"roster_rect": roster,
		"planet_rect": planet,
		"target_rail_rect": target_rail,
		"hand_dock_rect": hand_dock,
		"marker_button_rect": marker_button,
		"marker_panel_safe_rect": marker_panel,
		"camera_controls_rect": camera_controls,
		"minimum_planet_height": minimum_planet_height,
		"planet_height_green": planet.size.y >= minimum_planet_height,
		"target_rail_primary_surface": false,
		"target_rail_virtualized": true,
		"marker_panel_header_width_consumption": 0,
		"header_row_count": 2,
		"roster_columns": 2 if player_count > 4 and mode == WIDE_DESKTOP else 1,
	}


func modes() -> Array[String]:
	return [COMPACT_DESKTOP, REGULAR_DESKTOP, WIDE_DESKTOP]


func _mode_for(viewport_size: Vector2, player_count: int) -> String:
	if viewport_size.x >= 1840.0 and viewport_size.y >= 1000.0:
		return WIDE_DESKTOP
	if viewport_size.x < 1480.0 or viewport_size.y < 860.0 or player_count >= 7 and viewport_size.x < 1720.0:
		return COMPACT_DESKTOP
	return REGULAR_DESKTOP


func _metrics(mode: String, player_count: int) -> Dictionary:
	match mode:
		COMPACT_DESKTOP:
			return {
				"primary_header_height": 40.0,
				"utility_header_height": 36.0,
				"track_height": 88.0,
				"hand_dock_height": 174.0,
				"target_rail_height": 38.0,
				"roster_width": 164.0 if player_count <= 4 else 178.0,
			}
		WIDE_DESKTOP:
			return {
				"primary_header_height": 38.0,
				"utility_header_height": 34.0,
				"track_height": 108.0,
				"hand_dock_height": 228.0,
				"target_rail_height": 42.0,
				"roster_width": 264.0 if player_count > 4 else 224.0,
			}
	return {
		"primary_header_height": 40.0,
		"utility_header_height": 36.0,
		"track_height": 100.0,
		"hand_dock_height": 206.0,
		"target_rail_height": 40.0,
		"roster_width": 204.0 if player_count <= 4 else 222.0,
	}
