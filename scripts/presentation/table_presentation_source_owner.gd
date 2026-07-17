@tool
extends Node
class_name TablePresentationSourceOwner

const MAP_PALETTE: Array[Color] = [
	Color("#334155"), Color("#0f766e"), Color("#7c3aed"), Color("#b45309"),
	Color("#be123c"), Color("#0369a1"), Color("#4d7c0f"), Color("#a21caf"),
]

var _query_ports: TablePresentationQueryPorts
var _viewmodel_query: TablePresentationViewModelQuery
var _diagnostics: GameplayBalanceDiagnosticsRuntimeService
var _visual_cues: VisualCueRuntimeOwner
var _solar: SolarAvailabilityRuntimeService
var _world_clock: WorldEffectiveClockRuntimeController
var _weather: WeatherPresentationRuntimeService
var _revision := 0
var _snapshot_build_count_by_kind := {"live": 0, "map": 0, "full": 0, "developer": 0}


func configure(
	query_ports: TablePresentationQueryPorts,
	viewmodel_query: TablePresentationViewModelQuery,
	diagnostics: GameplayBalanceDiagnosticsRuntimeService = null,
	visual_cues: VisualCueRuntimeOwner = null,
	solar: SolarAvailabilityRuntimeService = null,
	world_clock: WorldEffectiveClockRuntimeController = null,
	weather: WeatherPresentationRuntimeService = null
) -> void:
	_query_ports = query_ports
	_viewmodel_query = viewmodel_query
	_diagnostics = diagnostics
	_visual_cues = visual_cues
	_solar = solar
	_world_clock = world_clock
	_weather = weather


func build_live_snapshot(receipt: TablePresentationRefreshReceipt) -> TableLivePresentationSnapshot:
	var snapshot := TableLivePresentationSnapshot.new()
	if not _can_build(receipt, &"live"):
		return snapshot
	_revision += 1
	_snapshot_build_count_by_kind["live"] = int(_snapshot_build_count_by_kind.get("live", 0)) + 1
	var context := _query_ports.viewer_context()
	var viewer := context.viewer_index
	snapshot.revision = _revision
	snapshot.viewer_index = viewer
	snapshot.authorization_revision = context.authorization_revision
	snapshot.table_state = _viewmodel_query.compose_table_state(viewer, false) if _viewmodel_query != null else {}
	return snapshot


func build_full_snapshot(receipt: TablePresentationRefreshReceipt) -> TableFullPresentationSnapshot:
	var snapshot := TableFullPresentationSnapshot.new()
	if not _can_build(receipt, &"full"):
		return snapshot
	_revision += 1
	_snapshot_build_count_by_kind["full"] = int(_snapshot_build_count_by_kind.get("full", 0)) + 1
	var context := _query_ports.viewer_context()
	var viewer := context.viewer_index
	snapshot.revision = _revision
	snapshot.viewer_index = viewer
	snapshot.authorization_revision = context.authorization_revision
	snapshot.table_state = _viewmodel_query.compose_table_state(viewer, true) if _viewmodel_query != null else {}
	return snapshot


func build_map_snapshot(receipt: TablePresentationRefreshReceipt) -> MapPresentationSnapshot:
	var snapshot := MapPresentationSnapshot.new()
	if not _can_build(receipt, &"map"):
		return snapshot
	_revision += 1
	_snapshot_build_count_by_kind["map"] = int(_snapshot_build_count_by_kind.get("map", 0)) + 1
	var context := _query_ports.viewer_context()
	var viewer := context.viewer_index
	var action := _query_ports.action_projection(viewer).to_dictionary()
	var availability: Dictionary = action.get("availability", {}) if action.get("availability", {}) is Dictionary else {}
	var map_projection := _query_ports.public_map_projection(viewer)
	var geometry := _query_ports.public_map_geometry_projection()
	snapshot.revision = _revision
	snapshot.viewer_index = viewer
	snapshot.authorization_revision = context.authorization_revision
	var public_districts := map_projection.districts
	if _visual_cues != null:
		_visual_cues.configure_world_bounds(geometry.width_m, geometry.height_m)
		public_districts = _visual_cues.districts_with_pulses(public_districts)
	var cue_snapshot: Dictionary = _visual_cues.public_snapshot() if _visual_cues != null else {}
	snapshot.districts = TablePresentationPureDataPolicy.detached_copy(public_districts) as Array
	snapshot.width_m = geometry.width_m
	snapshot.height_m = geometry.height_m
	snapshot.selected_district = int(availability.get("selected_district", -1))
	snapshot.palette = MAP_PALETTE.duplicate()
	snapshot.unit_markers = TablePresentationPureDataPolicy.detached_copy(map_projection.unit_markers) as Array
	snapshot.city_markers = TablePresentationPureDataPolicy.detached_copy(map_projection.city_markers) as Array
	snapshot.route_markers = TablePresentationPureDataPolicy.detached_copy(map_projection.route_markers) as Array
	snapshot.selected_trade_product = map_projection.selected_trade_product
	snapshot.selected_map_layer_focus = _query_ports.selected_map_layer_focus()
	snapshot.movement_trails = TablePresentationPureDataPolicy.detached_copy(cue_snapshot.get("movement_trails", [])) as Array
	snapshot.action_callouts = TablePresentationPureDataPolicy.detached_copy(cue_snapshot.get("action_callouts", [])) as Array
	snapshot.map_event_effects = TablePresentationPureDataPolicy.detached_copy(cue_snapshot.get("map_event_effects", [])) as Array
	if _solar != null and _world_clock != null:
		snapshot.solar_presentation = TablePresentationPureDataPolicy.detached_copy(
			_solar.public_presentation_snapshot(_world_clock.world_effective_micros())
		) as Dictionary
	if _weather != null:
		snapshot.weather_forecast = TablePresentationPureDataPolicy.detached_copy(_weather.forecast_view_model()) as Dictionary
		snapshot.weather_overlay = TablePresentationPureDataPolicy.detached_copy(_weather.map_overlay_view_model()) as Dictionary
	return snapshot


func build_developer_snapshot(receipt: TablePresentationRefreshReceipt, enabled: bool) -> DeveloperBalancePresentationSnapshot:
	var snapshot := DeveloperBalancePresentationSnapshot.new()
	if not _can_build(receipt, &"developer"):
		return snapshot
	_revision += 1
	_snapshot_build_count_by_kind["developer"] = int(_snapshot_build_count_by_kind.get("developer", 0)) + 1
	snapshot.revision = _revision
	snapshot.enabled = enabled and _diagnostics != null
	if snapshot.enabled:
		var report := _diagnostics.build_developer_panel_snapshot({}, true)
		snapshot.report = TablePresentationPureDataPolicy.detached_copy(report) as Dictionary if TablePresentationPureDataPolicy.is_pure_data(report) else {}
	return snapshot


func debug_snapshot() -> Dictionary:
	return {
		"configured": _query_ports != null and _viewmodel_query != null,
		"revision": _revision,
		"snapshot_build_count_by_kind": _snapshot_build_count_by_kind.duplicate(true),
		"references_main": false,
		"owns_refresh_cadence": false,
		"owns_gameplay_state": false,
		"viewmodel_query": _viewmodel_query.debug_snapshot() if _viewmodel_query != null else {},
	}


func viewer_context() -> TablePresentationViewerContext:
	return _query_ports.viewer_context() if _query_ports != null else TablePresentationViewerContext.denied()


func _can_build(receipt: TablePresentationRefreshReceipt, expected_kind: StringName) -> bool:
	return _query_ports != null and receipt != null and receipt.is_valid() and receipt.kind == expected_kind and _query_ports.authorized_viewer_index() >= 0
