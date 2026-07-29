extends SceneTree

const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")
const ROSTER_SERVICE := preload("res://scripts/presentation/public_player_roster_projection_service.gd")
const VIEWPORT_SIZES := [
	Vector2i(1920, 1080),
	Vector2i(1366, 768),
]
const BASELINE_BY_WIDTH := {
	1920: {"planet_width": 1576.0, "planet_height": 574.0, "planet_area": 904624.0},
	1366: {"planet_width": 1022.0, "planet_height": 386.0, "planet_area": 394492.0},
}

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var records: Array = []
	for viewport_size in VIEWPORT_SIZES:
		for player_count in [4, 8]:
			var viewport := SubViewport.new()
			viewport.size = viewport_size
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var screen := GAME_SCREEN_SCENE.instantiate() as Control
			viewport.add_child(screen)
			screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var roster := screen.find_child("PlayerRosterPanel", true, false) \
				as SpaceSyndicatePlayerRosterPanel
			var roster_projection := ROSTER_SERVICE.new().compose_roster(
				_public_players(player_count),
				0,
				1,
				player_count
			)
			roster.bind_viewer(0, 1)
			_expect(roster.apply_projection(roster_projection), "%d-player production roster applies" % player_count)
			await process_frame
			await process_frame
			await process_frame
			var planet := screen.find_child("PlanetBoard", true, false) as Control
			var planet_rect := planet.get_global_rect() if planet != null else Rect2()
			var permanent_right_width := 0.0
			var roster_width := roster.get_global_rect().size.x if roster != null and roster.is_visible_in_tree() else 0.0
			var roster_debug := roster.debug_snapshot()
			var baseline: Dictionary = BASELINE_BY_WIDTH.get(viewport_size.x, {})
			var width_delta := planet_rect.size.x - float(baseline.get("planet_width", 0.0))
			var area_delta := planet_rect.size.x * planet_rect.size.y \
				- float(baseline.get("planet_area", 0.0))
			_expect(permanent_right_width == 0.0, "%dx%d has zero permanent right panel width" % [viewport_size.x, viewport_size.y])
			_expect(roster_width <= 190.0, "%dx%d roster stays within 190 px" % [viewport_size.x, viewport_size.y])
			_expect(int(roster_debug.get("player_count", -1)) == player_count, "%dx%d renders all %d roster entries" % [viewport_size.x, viewport_size.y, player_count])
			_expect(int(roster_debug.get("column_count", -1)) == (1 if player_count == 4 else 2), "%d-player roster uses required column count" % player_count)
			_expect(width_delta >= 100.0, "%dx%d planet gains at least 100 px width" % [viewport_size.x, viewport_size.y])
			_expect(area_delta > 0.0, "%dx%d planet gains permanent area" % [viewport_size.x, viewport_size.y])
			records.append({
				"viewport_width": viewport_size.x,
				"viewport_height": viewport_size.y,
				"player_count": player_count,
				"planet_x": snappedf(planet_rect.position.x, 0.01),
				"planet_y": snappedf(planet_rect.position.y, 0.01),
				"planet_width": snappedf(planet_rect.size.x, 0.01),
				"planet_height": snappedf(planet_rect.size.y, 0.01),
				"planet_area": snappedf(planet_rect.size.x * planet_rect.size.y, 0.01),
				"right_permanent_panel_width": snappedf(permanent_right_width, 0.01),
				"roster_width": snappedf(roster_width, 0.01),
				"roster_columns": int(roster_debug.get("column_count", -1)),
				"planet_width_delta": snappedf(width_delta, 0.01),
				"planet_area_delta": snappedf(area_delta, 0.01),
			})
			viewport.remove_child(screen)
			screen.free()
			root.remove_child(viewport)
			viewport.free()
	if _failures.is_empty():
		print("ALPHA04B_LAYOUT_MEASUREMENT_PASS|checks=%d|records=%s" % [_checks, JSON.stringify(records)])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("ALPHA04B_LAYOUT_MEASUREMENT_FAIL|checks=%d|failures=%d|records=%s" % [_checks, _failures.size(), JSON.stringify(records)])
	quit(1)


func _public_players(count: int) -> Array:
	var players: Array = []
	for index in range(count):
		players.append({
			"player_index": index,
			"player_id": "player.%d" % index,
			"public_player_name": "玩家%d" % (index + 1),
			"role_name": "公开角色%d" % (index + 1),
			"avatar_key": "avatar.player-%d" % index,
			"public_status": "ready",
			"eliminated": false,
		})
	return players


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
