extends SceneTree

var _checks := 0
var _failures := 0


func _init() -> void:
	var state := WorldSessionState.new()
	root.add_child(state)
	_check(state.map_width_m == 1400.0 and state.map_height_m == 950.0, "default authoritative geometry")
	var first := state.configure_world_geometry(2200.0, 1200.0)
	_check(float(first.get("width_m", 0.0)) == 2200.0, "configure width")
	_check(float(first.get("height_m", 0.0)) == 1200.0, "configure height")
	_check(first.get("world_rect", Rect2()) == Rect2(Vector2.ZERO, Vector2(2200.0, 1200.0)), "public rect")
	var revision := int(first.get("revision", -1))
	var repeated := state.configure_world_geometry(2200.0, 1200.0)
	_check(int(repeated.get("revision", -2)) == revision, "identical configure keeps revision")
	var save := state.to_save_data()
	_check(float(save.get("map_width_m", 0.0)) == 2200.0, "save owns width")
	_check(float(save.get("map_height_m", 0.0)) == 1200.0, "save owns height")
	var restored := WorldSessionState.new()
	root.add_child(restored)
	var applied := restored.apply_save_data(save)
	_check(bool(applied.get("applied", false)), "save applies")
	_check(restored.public_world_geometry_snapshot() == first, "roundtrip exact public geometry")
	var query := WorldSessionPresentationQuery.new()
	root.add_child(query)
	var authorization := LocalViewerAuthorization.new()
	root.add_child(authorization)
	authorization.configure(restored)
	query.configure(restored, authorization)
	var projection := query.public_map_geometry_projection()
	_check(projection.width_m == 2200.0 and projection.height_m == 1200.0, "presentation consumes owner geometry")
	_check(projection.world_rect == Rect2(Vector2.ZERO, Vector2(2200.0, 1200.0)), "presentation does not infer polygon bounds")
	print("world_session_geometry_owner_cutover_test: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
		return
	_failures += 1
	push_error("FAIL: %s" % label)
