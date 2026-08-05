extends SceneTree

const Presenter := preload(
	"res://scripts/ui/v074/v074_asset_pip_presenter.gd"
)
const PipGroup := preload(
	"res://scripts/ui/v074/v074_asset_pip_group.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(
		Presenter.DISPLAY_MODE == "repeated_symbol_pips",
		"asset pool uses repeated symbol pips"
	)
	_expect(Presenter.PIP_SLOT_COUNT == 6, "asset cap renders exactly six slots")
	_v074_asset_pip_zero_to_six_test()
	_v074_asset_pip_reserved_state_test()
	await _v074_asset_pip_projected_refresh_test()
	_v074_asset_pip_privacy_test()
	_v074_asset_pip_zero_mutation_test()
	await _v074_asset_pip_responsive_layout_test()
	_v074_asset_pip_accessibility_test()
	_finish()


func _v074_asset_pip_zero_to_six_test() -> void:
	for current in range(7):
		var projection := _projection(current, current, current)
		var model := Presenter.model_from_projection(projection, "industry")
		var report := Presenter.validation_report(model)
		var states := model.get("pip_states", []) as Array
		_expect(
			bool(report.get("valid", false)),
			"zero-to-six model %d validates" % current
		)
		_expect(states.size() == 6, "state %d keeps six slots" % current)
		_expect(
			states.count(Presenter.PIP_AVAILABLE) == current,
			"state %d available count matches" % current
		)
		_expect(
			states.count(Presenter.PIP_EMPTY) == 6 - current,
			"state %d empty count matches" % current
		)


func _v074_asset_pip_reserved_state_test() -> void:
	var model := Presenter.model_from_projection(
		_projection(4, 2, 4),
		"industry"
	)
	var states := model.get("pip_states", []) as Array
	_expect(
		int(model.get("reserved", -1)) == 2,
		"four current and two available produce two reserved"
	)
	_expect(
		states.count(Presenter.PIP_RESERVED) == 2,
		"reserved state uses two locked pips"
	)


func _v074_asset_pip_projected_refresh_test() -> void:
	var no_refresh_model := Presenter.model_from_projection(
		_projection(4, 2, 2),
		"industry"
	)
	var refresh_model := Presenter.model_from_projection(
		_projection(4, 2, 5),
		"industry"
	)
	var no_refresh_group := _build_group(no_refresh_model)
	var refresh_group := _build_group(refresh_model)
	get_root().add_child(no_refresh_group)
	get_root().add_child(refresh_group)
	await process_frame
	no_refresh_group.size = no_refresh_group.get_combined_minimum_size()
	refresh_group.size = refresh_group.get_combined_minimum_size()
	await process_frame

	var no_refresh_debug := (
		no_refresh_group.call("debug_snapshot") as Dictionary
	)
	var refresh_debug := (
		refresh_group.call("debug_snapshot") as Dictionary
	)
	_expect(
		int(refresh_model.get("projected_refresh", -1)) == 3,
		"projected refresh derives from the local projection"
	)
	_expect(
		int(refresh_debug.get(
			"rendered_projected_refresh_pip_count",
			-1
		)) == 3,
		"three existing pips receive ghost refresh state"
	)
	_expect(
		_pip_node_count(refresh_group) == 6,
		"refresh preview does not create a seventh pip slot"
	)
	_expect(
		refresh_group.get_node_or_null("PipRow/ProjectedRefresh") == null,
		"no trailing projected-refresh slot strip exists"
	)
	_expect(
		is_equal_approx(
			float(no_refresh_debug.get("minimum_width", -1.0)),
			float(refresh_debug.get("minimum_width", -2.0))
		),
		"refresh state does not expand the six-slot group width"
	)
	_expect(
		float(refresh_debug.get("trailing_blank_width", -1.0)) <= 0.01,
		"six-slot group has no stretched trailing blank"
	)
	no_refresh_group.queue_free()
	refresh_group.queue_free()


func _v074_asset_pip_privacy_test() -> void:
	var projection := _projection(4, 2, 5)
	var clean := Presenter.projection_privacy_report(projection)
	_expect(
		bool(clean.get("valid", false)),
		"local-only asset projection passes privacy"
	)
	var leaked := projection.duplicate(true)
	leaked["opponent_assets"] = {"player.ai.1": {"industry": 6}}
	var rejected := Presenter.projection_privacy_report(leaked)
	_expect(
		not bool(rejected.get("valid", true))
		and int(rejected.get(
			"opponent_private_asset_disclosure_count",
			0
		)) == 1,
		"opponent asset fields are detected as a privacy violation"
	)


func _v074_asset_pip_zero_mutation_test() -> void:
	var projection := _projection(4, 2, 5)
	var before := projection.duplicate(true)
	Presenter.model_from_projection(projection, "industry")
	_expect(
		projection == before,
		"presenter performs zero projection mutation"
	)
	_expect(
		int(Presenter.projection_privacy_report(projection).get(
			"direct_runtime_state_read_count",
			-1
		)) == 0,
		"presenter reads no runtime authority state"
	)


func _v074_asset_pip_responsive_layout_test() -> void:
	var widths := [1366.0, 1600.0, 1920.0]
	for viewport_width in widths:
		var grid := GridContainer.new()
		grid.columns = Presenter.grid_columns("desktop")
		grid.size = Vector2(viewport_width, 24.0)
		grid.add_theme_constant_override("h_separation", 4)
		get_root().add_child(grid)
		for color_id in Presenter.COLORS:
			grid.add_child(_build_group(Presenter.model_from_projection(
				_projection(6, 6, 6),
				color_id
			)))
		await process_frame
		var minimum_width := grid.get_combined_minimum_size().x
		_expect(grid.columns == 6, "six color groups stay on one row")
		_expect(
			minimum_width < viewport_width,
			"compact pip grid fits %.0f width" % viewport_width
		)
		var exact_six := true
		var no_trailing_blank := true
		for group_variant in grid.get_children():
			var group := group_variant as Control
			exact_six = exact_six and _pip_node_count(group) == 6
			var debug := group.call("debug_snapshot") as Dictionary
			no_trailing_blank = (
				no_trailing_blank
				and float(debug.get("trailing_blank_width", 0.0)) <= 0.01
			)
		_expect(exact_six, "every responsive color group has six pips")
		_expect(
			no_trailing_blank,
			"responsive grid adds no false slots after pip six"
		)
		grid.queue_free()
		await process_frame


func _v074_asset_pip_accessibility_test() -> void:
	var model := Presenter.model_from_projection(
		_projection(4, 2, 5),
		"industry"
	)
	var group := _build_group(model)
	var debug := group.call("debug_snapshot") as Dictionary
	var details := str(group.get_meta("accessibility_label", ""))
	_expect(
		bool(debug.get("accessibility_label_present", false)),
		"asset group exposes an accessibility label"
	)
	_expect(
		"当前4" in details
		and "可用2" in details
		and "预留2" in details
		and "上限6" in details
		and "预计刷新3" in details,
		"accessibility details preserve exact numeric state"
	)
	group.queue_free()


func _projection(
	current: int,
	available: int,
	projected_final: int
) -> Dictionary:
	var exact := {}
	var available_by_color := {}
	var projected := {}
	for color_id in Presenter.COLORS:
		exact[color_id] = 0
		available_by_color[color_id] = 0
		projected[color_id] = 0
	exact["industry"] = current
	available_by_color["industry"] = available
	projected["industry"] = projected_final
	return {
		"schema": "V074LocalSixColorAssetProjectionV1",
		"own_exact_assets": exact,
		"own_available_assets": available_by_color,
		"own_projected_refresh": projected,
		"projection_fingerprint": "fixture.asset.pip",
	}


func _build_group(model: Dictionary) -> Control:
	var group := PipGroup.new()
	group.configure(
		str(model.get("color_id", "industry")),
		"工业",
		null,
		null,
		Color("#60a9ff"),
		model
	)
	return group


func _pip_node_count(group: Control) -> int:
	var pips := group.get_node_or_null("PipRow/SixPips")
	return pips.get_child_count() if pips != null else 0


func _finish() -> void:
	print(
		"V074_ASSET_PIP_PROJECTION_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)
