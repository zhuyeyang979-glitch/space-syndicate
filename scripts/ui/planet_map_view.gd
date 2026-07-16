extends "res://scripts/map_view.gd"
class_name SpaceSyndicatePlanetMapView

const PlanetDistrictNodeScene := preload("res://scenes/ui/map/PlanetDistrictNode.tscn")
const PlanetDistrictPolygonScene := preload("res://scenes/ui/map/PlanetDistrictPolygon.tscn")
const PlanetSelectionRingScene := preload("res://scenes/ui/map/PlanetSelectionRing.tscn")
const PlanetCityMarkerScene := preload("res://scenes/ui/map/PlanetCityMarker.tscn")
const PlanetMonsterTokenScene := preload("res://scenes/ui/map/PlanetMonsterToken.tscn")
const PlanetRouteMarkerScene := preload("res://scenes/ui/map/PlanetRouteMarker.tscn")
const PlanetRouteSegmentScene := preload("res://scenes/ui/map/PlanetRouteSegment.tscn")
const PlanetMovementTrailScene := preload("res://scenes/ui/map/PlanetMovementTrail.tscn")
const PlanetMapEventEffectScene := preload("res://scenes/ui/map/PlanetMapEventEffect.tscn")
const PlanetActionCalloutScene := preload("res://scenes/ui/map/PlanetActionCallout.tscn")
const PlanetMapRenderModelScript := preload("res://scripts/ui/map/planet_map_render_model.gd")

@onready var backdrop_layer: Control = get_node_or_null("BackdropLayer") as Control
@onready var orbit_layer: Control = get_node_or_null("OrbitLayer") as Control
@onready var district_layer: Control = get_node_or_null("DistrictLayer") as Control
@onready var weather_layer: Control = get_node_or_null("WeatherLayer") as Control
@onready var route_layer: Control = get_node_or_null("RouteLayer") as Control
@onready var monster_layer: Control = get_node_or_null("MonsterLayer") as Control
@onready var selection_layer: Control = get_node_or_null("SelectionLayer") as Control
@onready var effect_layer: Control = get_node_or_null("EffectLayer") as Control
@onready var callout_layer: Control = get_node_or_null("CalloutLayer") as Control
@onready var debug_overlay_layer: Control = get_node_or_null("DebugOverlayLayer") as Control
@onready var globe_backdrop: Control = get_node_or_null("BackdropLayer/PlanetGlobeBackdrop") as Control
@onready var orbit_guide: Control = get_node_or_null("OrbitLayer/PlanetOrbitGuide") as Control
@onready var focus_range_overlay: Control = get_node_or_null("SelectionLayer/PlanetFocusRangeOverlay") as Control
@onready var scale_hint: Control = get_node_or_null("DebugOverlayLayer/PlanetMapScaleHint") as Control
@onready var solar_camera_controller: Control = get_node_or_null("PlanetSolarCameraController") as Control
@onready var optional_route_presentation_service: Node = get_node_or_null("%OptionalRoutePresentationRuntimeService")

const EDITABLE_LAYER_NAMES := [
	"BackdropLayer",
	"OrbitLayer",
	"DistrictLayer",
	"WeatherLayer",
	"RouteLayer",
	"MonsterLayer",
	"SelectionLayer",
	"EffectLayer",
	"CalloutLayer",
	"DebugOverlayLayer",
]

var preview_note := "Waiting for map data"
@export var sceneized_visual_cutover_enabled := true
@export var legacy_draw_fallback_enabled := false
var legacy_draw_fallback_used := false
var _sceneized_district_polygon_nodes: Array[Node] = []
var _sceneized_district_nodes: Array[Node] = []
var _sceneized_route_segment_nodes: Array[Node] = []
var _sceneized_movement_trail_nodes: Array[Node] = []
var _sceneized_city_marker_nodes: Array[Node] = []
var _sceneized_monster_token_nodes: Array[Node] = []
var _sceneized_route_marker_nodes: Array[Node] = []
var _sceneized_selection_nodes: Array[Node] = []
var _sceneized_map_event_effect_nodes: Array[Node] = []
var _sceneized_action_callout_nodes: Array[Node] = []
var _sceneized_sync_queued := false
var _sceneized_dynamic_sync_queued := false
var _sceneized_projection_signature := ""
var _render_model: RefCounted = PlanetMapRenderModelScript.new()
var _optional_route_public_snapshot: Dictionary = {
	"available": false,
	"public_revision": -1,
	"selected_commodity_id": "",
	"rows": [],
}
var _optional_route_world_effective_seconds := -1.0
var _optional_route_source_explicit := false
var _optional_route_geometry_by_route_id: Dictionary = {}
var _last_legacy_trade_product := ""


func _ready() -> void:
	super._ready()
	add_to_group("optional_route_presentation_views")
	_configure_editable_layers()
	if solar_camera_controller != null and solar_camera_controller.has_method("bind_map_view"):
		solar_camera_controller.call("bind_map_view", self)
	set_meta("mcp_sceneized_component", "PlanetMapView")
	_queue_sceneized_sync()


func _draw() -> void:
	legacy_draw_fallback_used = false
	if districts.is_empty():
		_draw_sceneized_placeholder()
		return
	if sceneized_visual_cutover_enabled:
		return
	if legacy_draw_fallback_enabled:
		_draw_legacy_map_underlay_without_sceneized_surfaces()


func _process(delta: float) -> void:
	super._process(delta)
	var next_projection_signature := _current_sceneized_projection_signature()
	if next_projection_signature != _sceneized_projection_signature:
		_sceneized_projection_signature = next_projection_signature
		_queue_sceneized_sync()


func editable_layer_names() -> Array[String]:
	var result: Array[String] = []
	for layer_name in EDITABLE_LAYER_NAMES:
		result.append(str(layer_name))
	return result


func set_preview_note(note: String) -> void:
	preview_note = note
	queue_redraw()
	_queue_sceneized_sync()


func set_map(
	new_districts: Array,
	width_m: float,
	height_m: float,
	selected: int,
	colors: Array,
	trails: Array = [],
	callouts: Array = [],
	event_effects: Array = [],
	monster_markers: Array = [],
	new_city_markers: Array = [],
	new_trade_route_markers: Array = [],
	new_trade_product: String = "",
	new_visual_layer_focus: String = "all"
) -> void:
	_last_legacy_trade_product = new_trade_product
	var visible_route_markers := _compose_optional_route_markers(new_districts)
	var visible_trade_product := _optional_route_selected_product()
	var previous_map_signature := _map_signature
	var previous_visual_signature := _visual_payload_signature
	var previous_structural_signature := _sceneized_structural_payload_signature(
		districts,
		selected_district,
		city_markers,
		trade_route_markers,
		trade_product,
		visual_layer_focus
	)
	super.set_map(
		new_districts,
		width_m,
		height_m,
		selected,
		colors,
		trails,
		callouts,
		event_effects,
		monster_markers,
		new_city_markers,
		visible_route_markers,
		visible_trade_product,
		new_visual_layer_focus
	)
	if previous_map_signature == _map_signature and previous_visual_signature == _visual_payload_signature:
		return
	var structural_signature := _sceneized_structural_payload_signature(
		districts,
		selected_district,
		city_markers,
		trade_route_markers,
		trade_product,
		visual_layer_focus
	)
	if previous_map_signature != _map_signature or previous_structural_signature != structural_signature:
		_sceneized_projection_signature = _current_sceneized_projection_signature()
		_queue_sceneized_sync()
	else:
		_queue_sceneized_dynamic_sync()


func set_optional_route_selection(product_id: String) -> bool:
	if optional_route_presentation_service == null:
		return false
	var selected := false
	if product_id.strip_edges().is_empty():
		if optional_route_presentation_service.has_method("hide_routes"):
			optional_route_presentation_service.call("hide_routes")
	else:
		selected = bool(optional_route_presentation_service.call("select_product", product_id)) if optional_route_presentation_service.has_method("select_product") else false
	_apply_optional_route_presentation()
	return selected


func hide_optional_route_presentation() -> void:
	set_optional_route_selection("")


func reset_optional_route_presentation_for_new_run() -> void:
	_optional_route_public_snapshot = {
		"available": false,
		"public_revision": -1,
		"selected_commodity_id": "",
		"rows": [],
	}
	_optional_route_world_effective_seconds = -1.0
	_optional_route_source_explicit = false
	_optional_route_geometry_by_route_id = {}
	if optional_route_presentation_service != null and optional_route_presentation_service.has_method("reset_for_new_run"):
		optional_route_presentation_service.call("reset_for_new_run")
	_apply_optional_route_presentation()


func set_optional_route_public_snapshot(snapshot: Dictionary, world_effective_seconds := -1.0) -> void:
	_optional_route_public_snapshot = snapshot.duplicate(true)
	_optional_route_world_effective_seconds = world_effective_seconds
	_optional_route_source_explicit = true
	_apply_optional_route_presentation()


func set_optional_route_public_summaries(summaries: Array, world_effective_seconds := -1.0) -> void:
	var public_revision := 0
	for summary_variant in summaries:
		if summary_variant is Dictionary:
			public_revision = maxi(public_revision, int((summary_variant as Dictionary).get("public_revision", 0)))
	set_optional_route_public_snapshot({
		"available": true,
		"public_revision": public_revision,
		"selected_commodity_id": "",
		"rows": summaries,
	}, world_effective_seconds)


func clear_optional_route_public_snapshot() -> void:
	_optional_route_public_snapshot = {
		"available": false,
		"public_revision": -1,
		"selected_commodity_id": "",
		"rows": [],
	}
	_optional_route_world_effective_seconds = -1.0
	_optional_route_source_explicit = false
	_apply_optional_route_presentation()


func clear_optional_route_public_summaries() -> void:
	clear_optional_route_public_snapshot()


func set_optional_route_public_geometry(geometry_by_route_id: Dictionary) -> void:
	_optional_route_geometry_by_route_id = geometry_by_route_id.duplicate(true)
	_apply_optional_route_presentation()


func optional_route_presentation_snapshot() -> Dictionary:
	var local_state: Dictionary = {}
	var service_debug: Dictionary = {}
	if optional_route_presentation_service != null:
		if optional_route_presentation_service.has_method("local_state_snapshot"):
			local_state = optional_route_presentation_service.call("local_state_snapshot") as Dictionary
		if optional_route_presentation_service.has_method("debug_snapshot"):
			service_debug = optional_route_presentation_service.call("debug_snapshot") as Dictionary
	return {
		"local_state": local_state.duplicate(true),
		"service": service_debug.duplicate(true),
		"visible_route_count": trade_route_markers.size(),
		"visible_product_id": trade_product,
		"legacy_input_product_id": _last_legacy_trade_product,
		"explicit_public_source": _optional_route_source_explicit,
	}


func _compose_optional_route_markers(district_source: Array = districts) -> Array:
	if optional_route_presentation_service == null or not optional_route_presentation_service.has_method("compose_visible_snapshot"):
		return []
	var value: Variant = optional_route_presentation_service.call(
		"compose_visible_snapshot",
		_optional_route_public_snapshot,
		_optional_route_world_effective_seconds
	)
	return _materialize_optional_route_geometry((value as Array).duplicate(true), district_source) if value is Array else []


func _materialize_optional_route_geometry(markers: Array, district_source: Array = districts) -> Array:
	var result: Array = []
	for marker_variant in markers:
		if not (marker_variant is Dictionary):
			continue
		var marker := (marker_variant as Dictionary).duplicate(true)
		var points := _route_points(marker.get("points", []))
		if points.size() < 2:
			var flow_kind := str(marker.get("flow_kind", ""))
			if flow_kind == "ambient_consumption":
				points = _ambient_region_points(
					str(marker.get("from_region_id", "")),
					str(marker.get("to_region_id", "")),
					district_source
				)
			else:
				var route_id := str(marker.get("route_id", ""))
				points = _route_points(_optional_route_geometry_by_route_id.get(route_id, []))
		if points.size() < 2:
			continue
		if str(marker.get("flow_kind", "")) == "ambient_consumption" and points.size() != 2:
			continue
		marker["points"] = points
		result.append(marker)
	return result


func _ambient_region_points(from_region_id: String, to_region_id: String, district_source: Array = districts) -> Array[Vector2]:
	var from_position: Variant = _region_center_for_public_id(from_region_id, district_source)
	var to_position: Variant = _region_center_for_public_id(to_region_id, district_source)
	if from_position == null or to_position == null:
		return []
	var points: Array[Vector2] = []
	points.append(from_position as Vector2)
	points.append(to_position as Vector2)
	return points


func _region_center_for_public_id(region_id: String, district_source: Array = districts) -> Variant:
	if region_id.is_empty():
		return null
	for index in range(district_source.size()):
		if not (district_source[index] is Dictionary):
			continue
		var district := district_source[index] as Dictionary
		var candidate_id := ""
		for key in ["region_id", "district_id", "id"]:
			candidate_id = str(district.get(key, "")).strip_edges()
			if not candidate_id.is_empty():
				break
		if candidate_id != region_id:
			continue
		var center_variant: Variant = district.get("center", null)
		if center_variant is Vector2:
			return center_variant
	return null


func _optional_route_selected_product() -> String:
	if optional_route_presentation_service == null:
		return ""
	return str(optional_route_presentation_service.get("selected_trade_product_id")) if bool(optional_route_presentation_service.get("route_view_enabled")) else ""


func _apply_optional_route_presentation() -> void:
	var visible_route_markers := _compose_optional_route_markers()
	var visible_trade_product := _optional_route_selected_product()
	super.set_map(
		districts,
		map_width_m,
		map_height_m,
		selected_district,
		palette,
		movement_trails,
		action_callouts,
		map_event_effects,
		auto_monster_markers,
		city_markers,
		visible_route_markers,
		visible_trade_product,
		visual_layer_focus
	)
	_sceneized_projection_signature = _current_sceneized_projection_signature()
	_queue_sceneized_sync()


func reset_to_planet_overview() -> void:
	super.reset_to_planet_overview()
	_sceneized_projection_signature = ""
	_queue_sceneized_sync()


func focus_district(index: int, keep_zoom: bool = true) -> void:
	super.focus_district(index, keep_zoom)
	_sceneized_projection_signature = ""
	_queue_sceneized_sync()


func zoom_to_local_projection() -> void:
	super.zoom_to_local_projection()
	_sceneized_projection_signature = ""
	_queue_sceneized_sync()


func set_solar_presentation_snapshot(snapshot: Dictionary) -> bool:
	if solar_camera_controller == null or not solar_camera_controller.has_method("apply_public_solar_snapshot"):
		return false
	return bool(solar_camera_controller.call("apply_public_solar_snapshot", snapshot))


func set_weather_overlay_view_model(view_model: Dictionary) -> bool:
	if weather_layer == null or not weather_layer.has_method("set_overlay_view_model"):
		return false
	var applied := bool(weather_layer.call("set_overlay_view_model", view_model))
	_sync_weather_overlay_layout()
	return applied


func set_weather_overlay_motion_mode(mode: String) -> void:
	if weather_layer != null and weather_layer.has_method("set_motion_mode"):
		weather_layer.call("set_motion_mode", mode)


func focus_weather_region(region_index: int) -> bool:
	if region_index < 0 or region_index >= districts.size():
		return false
	focus_district(region_index, true)
	district_selected.emit(region_index)
	grab_focus()
	return true


func weather_overlay_debug_snapshot() -> Dictionary:
	if weather_layer == null or not weather_layer.has_method("debug_snapshot"):
		return {}
	var snapshot_variant: Variant = weather_layer.call("debug_snapshot")
	return (snapshot_variant as Dictionary).duplicate(true) if snapshot_variant is Dictionary else {}


func set_solar_camera_motion_mode(mode: String) -> void:
	if solar_camera_controller != null and solar_camera_controller.has_method("set_motion_mode"):
		solar_camera_controller.call("set_motion_mode", mode)


func request_solar_camera_return() -> void:
	if solar_camera_controller != null and solar_camera_controller.has_method("request_return_to_sun"):
		solar_camera_controller.call("request_return_to_sun")


func solar_camera_debug_snapshot() -> Dictionary:
	if solar_camera_controller == null or not solar_camera_controller.has_method("debug_snapshot"):
		return {}
	var snapshot_variant: Variant = solar_camera_controller.call("debug_snapshot")
	return (snapshot_variant as Dictionary).duplicate(true) if snapshot_variant is Dictionary else {}


func get_sceneization_debug_snapshot() -> Dictionary:
	var present_layers: Array[String] = []
	for layer_name in EDITABLE_LAYER_NAMES:
		if get_node_or_null(NodePath(layer_name)) != null:
			present_layers.append(str(layer_name))
	var snapshot := {
		"component": "PlanetMapView",
		"extends_runtime_map_view": true,
		"district_count": districts.size(),
		"selected_district": selected_district,
		"has_map_data": not districts.is_empty(),
		"editable_layers": present_layers,
		"preview_note": preview_note,
		"runtime_focus_kind": str(get_meta("runtime_focus_kind", "")),
	}
	snapshot["solar_camera"] = solar_camera_debug_snapshot()
	snapshot["weather_overlay"] = weather_overlay_debug_snapshot()
	snapshot["optional_route_presentation"] = optional_route_presentation_snapshot()
	snapshot.merge(get_sceneized_child_snapshot(), true)
	return snapshot


func get_sceneized_child_snapshot() -> Dictionary:
	return {
		"globe_backdrop_sceneized": _underlay_component_sceneized(globe_backdrop, "PlanetGlobeBackdrop"),
		"orbit_guide_sceneized": _underlay_component_sceneized(orbit_guide, "PlanetOrbitGuide"),
		"focus_range_overlay_sceneized": _underlay_component_sceneized(focus_range_overlay, "PlanetFocusRangeOverlay"),
		"scale_hint_sceneized": _underlay_component_sceneized(scale_hint, "PlanetMapScaleHint"),
		"sceneized_visual_cutover_enabled": sceneized_visual_cutover_enabled,
		"legacy_draw_fallback_enabled": legacy_draw_fallback_enabled,
		"legacy_draw_fallback_used": legacy_draw_fallback_used,
		"district_polygon_count": _live_node_count(_sceneized_district_polygon_nodes),
		"district_node_count": _live_node_count(_sceneized_district_nodes),
		"route_segment_count": _live_node_count(_sceneized_route_segment_nodes),
		"movement_trail_count": _live_node_count(_sceneized_movement_trail_nodes),
		"city_marker_count": _live_node_count(_sceneized_city_marker_nodes),
		"monster_token_count": _live_node_count(_sceneized_monster_token_nodes),
		"route_marker_count": _live_node_count(_sceneized_route_marker_nodes),
		"selection_marker_count": _live_node_count(_sceneized_selection_nodes),
		"map_event_effect_count": _live_node_count(_sceneized_map_event_effect_nodes),
		"action_callout_count": _live_node_count(_sceneized_action_callout_nodes),
		"selected_marker_visible": _live_node_count(_sceneized_selection_nodes) > 0,
		"draw_backed_surfaces": _draw_backed_surfaces(),
		"remaining_draw_backed_surfaces": _remaining_draw_backed_surfaces(),
		"sceneized_layers": {
			"globe_backdrop": "PlanetGlobeBackdrop",
			"orbit_guide": "PlanetOrbitGuide",
			"focus_range_overlay": "PlanetFocusRangeOverlay",
			"scale_hint": "PlanetMapScaleHint",
			"district_polygons": "PlanetDistrictPolygon",
			"districts": "PlanetDistrictNode",
			"route_segments": "PlanetRouteSegment",
			"movement_trails": "PlanetMovementTrail",
			"cities": "PlanetCityMarker",
			"monsters": "PlanetMonsterToken",
			"routes": "PlanetRouteMarker",
			"selection": "PlanetSelectionRing",
			"event_effects": "PlanetMapEventEffect",
			"action_callouts": "PlanetActionCallout",
		},
	}


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_queue_sceneized_sync()


func _queue_sceneized_sync() -> void:
	if _sceneized_sync_queued:
		return
	_sceneized_sync_queued = true
	call_deferred("_sync_sceneized_map_children")


func _queue_sceneized_dynamic_sync() -> void:
	if _sceneized_sync_queued or _sceneized_dynamic_sync_queued:
		return
	_sceneized_dynamic_sync_queued = true
	call_deferred("_sync_sceneized_dynamic_children")


func _sync_sceneized_map_children() -> void:
	_sceneized_sync_queued = false
	_sceneized_dynamic_sync_queued = false
	if not is_inside_tree():
		return
	_configure_editable_layers()
	_sync_projection_metrics_for_query()
	_sync_underlay_components()
	_clear_sceneized_map_children()
	_sync_district_polygons()
	_sync_weather_overlay_layout()
	_sync_route_segments()
	_sync_movement_trails()
	_sync_route_markers()
	_sync_district_nodes()
	_sync_city_markers()
	_sync_monster_tokens()
	_sync_selection_marker()
	_sync_map_event_effects()
	_sync_action_callouts()
	_sceneized_projection_signature = _current_sceneized_projection_signature()


func _sync_sceneized_dynamic_children() -> void:
	if not _sceneized_dynamic_sync_queued:
		return
	_sceneized_dynamic_sync_queued = false
	if not is_inside_tree():
		return
	_sync_projection_metrics_for_query()
	_clear_sceneized_node_list(_sceneized_movement_trail_nodes)
	_clear_sceneized_node_list(_sceneized_monster_token_nodes)
	_clear_sceneized_node_list(_sceneized_map_event_effect_nodes)
	_clear_sceneized_node_list(_sceneized_action_callout_nodes)
	_sync_movement_trails()
	_sync_monster_tokens()
	_sync_map_event_effects()
	_sync_action_callouts()


func render_model_debug_payload() -> Dictionary:
	return _build_render_model_payload()


func _sync_district_polygons() -> void:
	_sceneized_district_polygon_nodes.clear()
	if district_layer == null:
		return
	for index in range(districts.size()):
		var entry: Dictionary = districts[index]
		var points := _sceneized_polygon_points(entry.get("polygon", []))
		if points.size() < 3:
			continue
		var node := PlanetDistrictPolygonScene.instantiate() as Control
		if node == null:
			continue
		node.set_meta("sceneized_planet_map_child", true)
		node.set_meta("sceneized_planet_map_kind", "district_polygon")
		district_layer.add_child(node)
		node.call("configure", {
			"index": index,
			"name": str(entry.get("name", "District")),
			"screen_points": points,
			"selected": index == selected_district,
			"accent": _palette_hex(index),
		})
		_sceneized_district_polygon_nodes.append(node)


func _sync_district_nodes() -> void:
	_sceneized_district_nodes.clear()
	if district_layer == null:
		return
	var overview_compact := _sceneized_overview_compact()
	var label_positions := _overview_district_label_positions() if overview_compact else {}
	for index in range(districts.size()):
		var entry: Dictionary = districts[index]
		var node := PlanetDistrictNodeScene.instantiate() as Control
		if node == null:
			continue
		node.set_meta("sceneized_planet_map_child", true)
		node.set_meta("sceneized_planet_map_kind", "district")
		district_layer.add_child(node)
		node.call("configure", {
			"index": index,
			"name": str(entry.get("name", "District")),
			"terrain": str(entry.get("terrain", "surface")),
			"hp": int(entry.get("hp", 0)),
			"panic": int(entry.get("panic", 0)),
			"products": entry.get("products", []),
			"screen_position": label_positions.get(index, get_district_control_position(index)),
			"selected": index == selected_district,
			"compact": overview_compact and index != selected_district,
			"accent": _palette_hex(index),
		})
		if node.has_signal("district_pressed"):
			node.connect("district_pressed", Callable(self, "_on_sceneized_district_pressed"))
		if node.has_signal("district_double_pressed"):
			node.connect("district_double_pressed", Callable(self, "_on_sceneized_district_double_pressed"))
		_sceneized_district_nodes.append(node)


func _overview_district_label_positions() -> Dictionary:
	var result := {}
	var occupied: Array[Rect2] = []
	var ordered_indices: Array[int] = []
	if selected_district >= 0 and selected_district < districts.size():
		ordered_indices.append(selected_district)
	for index in range(districts.size()):
		if index != selected_district:
			ordered_indices.append(index)
	var globe_center := size * 0.5
	if has_method("_globe_center"):
		globe_center = call("_globe_center") as Vector2
	for index in ordered_indices:
		var base := get_district_control_position(index)
		var selected := index == selected_district
		var label_size := Vector2(128, 106) if selected else Vector2(92, 28)
		var radial := (base - globe_center).normalized()
		if radial.length_squared() < 0.01:
			radial = Vector2.UP
		var tangent := Vector2(-radial.y, radial.x)
		var offsets: Array[Vector2] = [Vector2.ZERO]
		if not selected:
			offsets.append_array([
				radial * 28.0,
				tangent * 50.0,
				-tangent * 50.0,
				radial * 34.0 + tangent * 48.0,
				radial * 34.0 - tangent * 48.0,
				radial * 58.0,
			])
		var chosen := _clamp_overview_label_center(base, label_size)
		for offset in offsets:
			var candidate := _clamp_overview_label_center(base + offset, label_size)
			var candidate_rect := Rect2(candidate - label_size * 0.5, label_size).grow(4.0)
			var overlaps_existing := false
			for occupied_rect in occupied:
				if candidate_rect.intersects(occupied_rect):
					overlaps_existing = true
					break
			if not overlaps_existing:
				chosen = candidate
				break
		result[index] = chosen
		occupied.append(Rect2(chosen - label_size * 0.5, label_size).grow(4.0))
	return result


func _clamp_overview_label_center(value: Vector2, label_size: Vector2) -> Vector2:
	var half := label_size * 0.5
	return Vector2(
		clampf(value.x, half.x + 6.0, maxf(half.x + 6.0, size.x - half.x - 6.0)),
		clampf(value.y, half.y + 6.0, maxf(half.y + 6.0, size.y - half.y - 6.0))
	)


func _sync_city_markers() -> void:
	_sceneized_city_marker_nodes.clear()
	if district_layer == null:
		return
	for marker_variant in city_markers:
		if not (marker_variant is Dictionary):
			continue
		var marker: Dictionary = (marker_variant as Dictionary).duplicate(true)
		var node := PlanetCityMarkerScene.instantiate() as Control
		if node == null:
			continue
		node.set_meta("sceneized_planet_map_child", true)
		node.set_meta("sceneized_planet_map_kind", "city")
		district_layer.add_child(node)
		node.call("configure", {
			"screen_position": _sceneized_world_to_control(marker.get("position", Vector2.ZERO)),
			"tag": str(marker.get("tag", "C")),
			"level": int(marker.get("level", 1)),
			"products": marker.get("products", []),
			"accent": _color_to_hex(marker.get("tag_color", Color("#38bdf8"))),
			"active": bool(marker.get("active", true)),
		})
		_sceneized_city_marker_nodes.append(node)


func _sync_monster_tokens() -> void:
	_sceneized_monster_token_nodes.clear()
	if monster_layer == null:
		return
	var overview_compact := _sceneized_overview_compact()
	for entry_variant in _monster_presentation_entries(overview_compact):
		var entry := entry_variant as Dictionary
		var marker := entry.get("marker", {}) as Dictionary
		var marker_position := entry.get("screen_position", Vector2.ZERO) as Vector2
		var node := PlanetMonsterTokenScene.instantiate() as Control
		if node == null:
			continue
		node.set_meta("sceneized_planet_map_child", true)
		node.set_meta("sceneized_planet_map_kind", "monster")
		monster_layer.add_child(node)
		node.call("configure", {
			"screen_position": marker_position,
			"name": str(marker.get("name", "Monster")),
			"label": str(marker.get("label", "")),
			"glyph": str(marker.get("glyph", "M")),
			"detail_label": str(marker.get("display_subtitle", "场上单位")),
			"accent": _color_to_hex(marker.get("color", Color("#ef4444"))),
			"secondary": _color_to_hex(marker.get("secondary", Color("#fde68a"))),
			"compact": overview_compact,
			"count": int(entry.get("count", 1)),
			"names": entry.get("names", []),
		})
		_sceneized_monster_token_nodes.append(node)


func _monster_presentation_entries(overview_compact: bool) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for marker_variant in auto_monster_markers:
		if not (marker_variant is Dictionary):
			continue
		var marker := (marker_variant as Dictionary).duplicate(true)
		var screen_position := _sceneized_world_to_control(marker.get("position", Vector2.ZERO))
		var display_name := str(marker.get("name", "未知怪兽"))
		if not overview_compact:
			entries.append({"marker": marker, "screen_position": screen_position, "count": 1, "names": [display_name]})
			continue
		var grouped_index := -1
		for entry_index in range(entries.size()):
			var existing := entries[entry_index]
			if (existing.get("screen_position", Vector2.ZERO) as Vector2).distance_to(screen_position) <= 72.0:
				grouped_index = entry_index
				break
		if grouped_index < 0:
			entries.append({"marker": marker, "screen_position": screen_position, "count": 1, "names": [display_name]})
			continue
		var grouped := entries[grouped_index]
		var previous_count := int(grouped.get("count", 1))
		grouped["screen_position"] = ((grouped.get("screen_position", Vector2.ZERO) as Vector2) * float(previous_count) + screen_position) / float(previous_count + 1)
		grouped["count"] = previous_count + 1
		var names := grouped.get("names", []) as Array
		names.append(display_name)
		grouped["names"] = names
		entries[grouped_index] = grouped
	for entry_index in range(entries.size()):
		var entry := entries[entry_index]
		entry["screen_position"] = _compact_monster_token_position(entry.get("screen_position", Vector2.ZERO) as Vector2, entry_index)
		entries[entry_index] = entry
	return entries


func _sync_route_segments() -> void:
	_sceneized_route_segment_nodes.clear()
	if route_layer == null:
		return
	var segment_index := 0
	for route_variant in trade_route_markers:
		if not (route_variant is Dictionary):
			continue
		var route: Dictionary = (route_variant as Dictionary).duplicate(true)
		var points := _route_points(route.get("points", []))
		if points.size() < 2:
			continue
		for i in range(points.size() - 1):
			var segment := _sceneized_route_segment(points[i], points[i + 1])
			if segment.is_empty():
				continue
			var node := PlanetRouteSegmentScene.instantiate() as Control
			if node == null:
				continue
			node.set_meta("sceneized_planet_map_child", true)
			node.set_meta("sceneized_planet_map_kind", "route_segment")
			route_layer.add_child(node)
			node.call("configure", {
				"from_position": segment.get("from_position", Vector2.ZERO),
				"to_position": segment.get("to_position", Vector2.ZERO),
				"product": str(route.get("product", trade_product)),
				"disrupted": bool(route.get("disrupted", false)),
				"flow_kind": str(route.get("flow_kind", "market_sale")),
				"strength": str(route.get("strength", "weak")),
				"low_emphasis": bool(route.get("low_emphasis", false)),
				"capacity_limited": bool(route.get("capacity_limited", false)),
				"congested": bool(route.get("congested", false)),
				"transport_modes": route.get("transport_modes", []),
				"segment_index": segment_index,
				"accent": _route_accent_hex(str(route.get("product", trade_product))),
			})
			_sceneized_route_segment_nodes.append(node)
			segment_index += 1


func _sync_route_markers() -> void:
	_sceneized_route_marker_nodes.clear()
	if route_layer == null:
		return
	var overview_compact := _sceneized_overview_compact()
	var overview_group_counts := {}
	if overview_compact:
		for route_variant in trade_route_markers:
			if not (route_variant is Dictionary):
				continue
			var route := route_variant as Dictionary
			if not bool(route.get("show_marker", true)):
				continue
			var group_key := _overview_route_group_key(route)
			overview_group_counts[group_key] = int(overview_group_counts.get(group_key, 0)) + 1
	var emitted_overview_groups := {}
	for route_variant in trade_route_markers:
		if not (route_variant is Dictionary):
			continue
		var route: Dictionary = (route_variant as Dictionary).duplicate(true)
		if not bool(route.get("show_marker", true)):
			continue
		var overview_group_key := _overview_route_group_key(route)
		if overview_compact and emitted_overview_groups.has(overview_group_key):
			continue
		emitted_overview_groups[overview_group_key] = true
		var points := _route_points(route.get("points", []))
		var node := PlanetRouteMarkerScene.instantiate() as Control
		if node == null:
			continue
		node.set_meta("sceneized_planet_map_child", true)
		node.set_meta("sceneized_planet_map_kind", "route")
		route_layer.add_child(node)
		node.call("configure", {
			"screen_position": _sceneized_route_midpoint(points),
			"product": _route_product_display(route),
			"disrupted": bool(route.get("disrupted", false)),
			"flow_kind": str(route.get("flow_kind", "market_sale")),
			"strength": str(route.get("strength", "weak")),
			"capacity_limited": bool(route.get("capacity_limited", false)),
			"congested": bool(route.get("congested", false)),
			"transport_modes": route.get("transport_modes", []),
			"point_count": points.size(),
			"accent": _route_accent_hex(_route_product_display(route)),
			"compact": overview_compact,
			"route_count": int(overview_group_counts.get(overview_group_key, 1)),
		})
		_sceneized_route_marker_nodes.append(node)


func _sync_movement_trails() -> void:
	_sceneized_movement_trail_nodes.clear()
	if route_layer == null:
		return
	var trail_index := 0
	for trail_variant in movement_trails:
		if not (trail_variant is Dictionary):
			continue
		var trail: Dictionary = (trail_variant as Dictionary).duplicate(true)
		var segment := _sceneized_route_segment(_as_vector2(trail.get("from", Vector2.ZERO)), _as_vector2(trail.get("to", Vector2.ZERO)))
		if segment.is_empty():
			continue
		var node := PlanetMovementTrailScene.instantiate() as Control
		if node == null:
			continue
		node.set_meta("sceneized_planet_map_child", true)
		node.set_meta("sceneized_planet_map_kind", "movement_trail")
		route_layer.add_child(node)
		node.call("configure", {
			"from_position": segment.get("from_position", Vector2.ZERO),
			"to_position": segment.get("to_position", Vector2.ZERO),
			"label": str(trail.get("label", "")),
			"style": str(trail.get("style", "movement")),
			"life": float(trail.get("life", trail.get("duration", 1.0))),
			"duration": float(trail.get("duration", 1.0)),
			"trail_index": trail_index,
			"accent": _color_to_hex(trail.get("color", Color("#38bdf8"))),
		})
		_sceneized_movement_trail_nodes.append(node)
		trail_index += 1


func _sync_selection_marker() -> void:
	_sceneized_selection_nodes.clear()
	if selection_layer == null:
		return
	if selected_district < 0 or selected_district >= districts.size():
		return
	var entry: Dictionary = districts[selected_district]
	var node := PlanetSelectionRingScene.instantiate() as Control
	if node == null:
		return
	node.set_meta("sceneized_planet_map_child", true)
	node.set_meta("sceneized_planet_map_kind", "selection")
	selection_layer.add_child(node)
	node.call("configure", {
		"index": selected_district,
		"name": str(entry.get("name", "Selected region")),
		"detail": "当前焦点｜%s" % _terrain_display_label(str(entry.get("terrain", "地表区"))),
		"screen_position": get_district_control_position(selected_district),
		"accent": "#facc15",
	})
	_sceneized_selection_nodes.append(node)


func _terrain_display_label(terrain_id: String) -> String:
	return str({
		"land": "陆地",
		"ocean": "海洋",
		"sea": "海洋",
		"coast": "海岸",
		"city": "城区",
	}.get(terrain_id.to_lower(), terrain_id))


func _sync_map_event_effects() -> void:
	_sceneized_map_event_effect_nodes.clear()
	if effect_layer == null:
		return
	var effect_index := 0
	for effect_variant in map_event_effects:
		if not (effect_variant is Dictionary):
			continue
		var effect: Dictionary = (effect_variant as Dictionary).duplicate(true)
		var payload := _sceneized_map_event_effect_payload(effect, effect_index)
		if payload.is_empty():
			continue
		var node := PlanetMapEventEffectScene.instantiate() as Control
		if node == null:
			continue
		node.set_meta("sceneized_planet_map_child", true)
		node.set_meta("sceneized_planet_map_kind", "event_effect")
		effect_layer.add_child(node)
		node.call("configure", payload)
		_sceneized_map_event_effect_nodes.append(node)
		effect_index += 1


func _sync_action_callouts() -> void:
	_sceneized_action_callout_nodes.clear()
	if callout_layer == null:
		return
	if action_callouts.is_empty():
		return
	var overview_compact := _sceneized_overview_compact()
	var panel_width: float = minf(196.0, size.x * 0.34) if overview_compact else minf(390.0, size.x * 0.52)
	var row_height := 32.0 if overview_compact else 52.0
	var panel_x: float = maxf(12.0, size.x - panel_width - 14.0)
	var visible_callout_count := 2 if overview_compact else 4
	var first_index: int = max(0, action_callouts.size() - visible_callout_count)
	var row := 0
	for i in range(action_callouts.size() - 1, first_index - 1, -1):
		var callout_variant: Variant = action_callouts[i]
		if not (callout_variant is Dictionary):
			continue
		var callout: Dictionary = (callout_variant as Dictionary).duplicate(true)
		var duration: float = maxf(0.01, float(callout.get("duration", 1.0)))
		var alpha: float = clampf(float(callout.get("life", duration)) / duration, 0.0, 1.0)
		var node := PlanetActionCalloutScene.instantiate() as Control
		if node == null:
			continue
		node.set_meta("sceneized_planet_map_child", true)
		node.set_meta("sceneized_planet_map_kind", "action_callout")
		callout_layer.add_child(node)
		node.call("configure", {
			"title": _action_callout_title(callout),
			"detail": str(callout.get("detail", "")),
			"accent": _color_to_hex(callout.get("color", callout.get("accent", Color("#facc15")))),
			"alpha": alpha,
			"panel_position": Vector2(panel_x, 38.0 + float(row) * (row_height + 6.0)),
			"panel_size": Vector2(panel_width, row_height),
			"callout_index": i,
			"compact": overview_compact,
		})
		_sceneized_action_callout_nodes.append(node)
		row += 1


func _clear_sceneized_map_children() -> void:
	for layer in [district_layer, route_layer, monster_layer, selection_layer, effect_layer, callout_layer, debug_overlay_layer]:
		if layer == null:
			continue
		for child in layer.get_children():
			if child.get_meta("sceneized_planet_map_child", false):
				layer.remove_child(child)
				child.queue_free()
	_sceneized_district_polygon_nodes.clear()
	_sceneized_district_nodes.clear()
	_sceneized_route_segment_nodes.clear()
	_sceneized_movement_trail_nodes.clear()
	_sceneized_city_marker_nodes.clear()
	_sceneized_monster_token_nodes.clear()
	_sceneized_route_marker_nodes.clear()
	_sceneized_selection_nodes.clear()
	_sceneized_map_event_effect_nodes.clear()
	_sceneized_action_callout_nodes.clear()


func _clear_sceneized_node_list(nodes: Array[Node]) -> void:
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		var parent := node.get_parent()
		if parent != null:
			parent.remove_child(node)
		node.queue_free()
	nodes.clear()


func _configure_editable_layers() -> void:
	backdrop_layer = get_node_or_null("BackdropLayer") as Control
	orbit_layer = get_node_or_null("OrbitLayer") as Control
	district_layer = get_node_or_null("DistrictLayer") as Control
	weather_layer = get_node_or_null("WeatherLayer") as Control
	route_layer = get_node_or_null("RouteLayer") as Control
	monster_layer = get_node_or_null("MonsterLayer") as Control
	selection_layer = get_node_or_null("SelectionLayer") as Control
	effect_layer = get_node_or_null("EffectLayer") as Control
	callout_layer = get_node_or_null("CalloutLayer") as Control
	debug_overlay_layer = get_node_or_null("DebugOverlayLayer") as Control
	globe_backdrop = get_node_or_null("BackdropLayer/PlanetGlobeBackdrop") as Control
	orbit_guide = get_node_or_null("OrbitLayer/PlanetOrbitGuide") as Control
	focus_range_overlay = get_node_or_null("SelectionLayer/PlanetFocusRangeOverlay") as Control
	scale_hint = get_node_or_null("DebugOverlayLayer/PlanetMapScaleHint") as Control
	for layer_name in EDITABLE_LAYER_NAMES:
		var layer := get_node_or_null(NodePath(layer_name)) as Control
		if layer == null:
			continue
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.set_meta("mcp_planet_map_layer", layer_name)


func _sync_weather_overlay_layout() -> void:
	if weather_layer == null or not weather_layer.has_method("set_region_layout") or size.x <= 1.0 or size.y <= 1.0:
		return
	var overview_compact := _sceneized_overview_compact()
	if weather_layer.has_method("set_compact_mode"):
		weather_layer.call("set_compact_mode", overview_compact)
	var overview_positions := _overview_weather_marker_positions() if overview_compact else {}
	var normalized_positions: Dictionary = {}
	for index in range(districts.size()):
		var position: Vector2 = overview_positions.get(index, get_district_control_position(index))
		normalized_positions[index] = Vector2(
			clampf(position.x / size.x, 0.0, 1.0),
			clampf(position.y / size.y, 0.0, 1.0)
		)
	weather_layer.call("set_region_layout", normalized_positions)


func _overview_weather_marker_positions() -> Dictionary:
	var label_positions := _overview_district_label_positions()
	var occupied: Array[Rect2] = []
	for index in range(districts.size()):
		var selected := index == selected_district
		var label_size := Vector2(128, 106) if selected else Vector2(92, 28)
		var label_center: Vector2 = label_positions.get(index, get_district_control_position(index))
		occupied.append(Rect2(label_center - label_size * 0.5, label_size).grow(5.0))
	var result := {}
	for index in range(districts.size()):
		var selected := index == selected_district
		var label_center: Vector2 = label_positions.get(index, get_district_control_position(index))
		var offsets: Array = [
			Vector2(88.0, 0.0), Vector2(-88.0, 0.0), Vector2(0.0, -76.0), Vector2(0.0, 76.0),
		] if selected else [
			Vector2(0.0, 52.0), Vector2(0.0, -52.0), Vector2(76.0, 0.0), Vector2(-76.0, 0.0),
		]
		var chosen := _clamp_weather_marker_center(label_center + offsets[0])
		for offset in offsets:
			var candidate := _clamp_weather_marker_center(label_center + offset)
			var candidate_rect := Rect2(candidate - Vector2(34, 34), Vector2(68, 68))
			var overlaps_existing := false
			for occupied_rect in occupied:
				if candidate_rect.intersects(occupied_rect):
					overlaps_existing = true
					break
			if not overlaps_existing:
				chosen = candidate
				break
		result[index] = chosen
		occupied.append(Rect2(chosen - Vector2(34, 34), Vector2(68, 68)))
	return result


func _clamp_weather_marker_center(value: Vector2) -> Vector2:
	return Vector2(
		clampf(value.x, 42.0, maxf(42.0, size.x - 42.0)),
		clampf(value.y, 34.0, maxf(34.0, size.y - 48.0))
	)


func _sync_underlay_components() -> void:
	var payload := _build_render_model_payload()
	if globe_backdrop != null and globe_backdrop.has_method("configure"):
		globe_backdrop.call("configure", payload)
	if orbit_guide != null and orbit_guide.has_method("configure"):
		orbit_guide.call("configure", payload)
	if focus_range_overlay != null and focus_range_overlay.has_method("configure"):
		focus_range_overlay.call("configure", payload)
	if scale_hint != null and scale_hint.has_method("configure"):
		scale_hint.call("configure", payload)


func _build_render_model_payload() -> Dictionary:
	if _render_model != null and _render_model.has_method("build_from_map_view"):
		var payload_variant: Variant = _render_model.call("build_from_map_view", self)
		if payload_variant is Dictionary:
			return (payload_variant as Dictionary).duplicate(true)
	return {}


func _remaining_draw_backed_surfaces() -> Array[String]:
	if _render_model != null and _render_model.has_method("remaining_draw_backed_surfaces"):
		var surfaces_variant: Variant = _render_model.call("remaining_draw_backed_surfaces")
		var result: Array[String] = []
		if surfaces_variant is Array:
			for surface in surfaces_variant:
				result.append(str(surface))
		return result
	return ["legacy_region_fill_fallback", "legacy_region_label_fallback"]


func _draw_backed_surfaces() -> Array[String]:
	var result: Array[String] = []
	if legacy_draw_fallback_enabled or legacy_draw_fallback_used or not sceneized_visual_cutover_enabled:
		result.append("legacy_map_underlay_fallback")
	return result


func _underlay_component_sceneized(node: Control, component_name: String) -> bool:
	return node != null and node.has_method("configure") and str(node.get_meta("mcp_sceneized_component", "")) == component_name


func _on_sceneized_district_pressed(index: int) -> void:
	if index < 0:
		return
	district_selected.emit(index)


func _on_sceneized_district_double_pressed(index: int) -> void:
	if index < 0:
		return
	district_selected.emit(index)
	district_double_clicked.emit(index)


func _sceneized_world_to_control(value: Variant) -> Vector2:
	var world_position := _as_vector2(value)
	if size.x <= 1.0 or size.y <= 1.0:
		return Vector2.ZERO
	var projection := _map_event_screen_position(world_position)
	return projection.get("position", _world_to_screen(world_position))


func _sceneized_route_midpoint(points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return size * 0.5
	var total := Vector2.ZERO
	for point in points:
		total += _sceneized_world_to_control(point)
	return total / float(points.size())


func _compact_monster_token_position(base_position: Vector2, token_index: int) -> Vector2:
	var center := size * 0.5
	if has_method("_globe_center"):
		center = call("_globe_center") as Vector2
	var radial := (base_position - center).normalized()
	if radial.length_squared() < 0.01:
		radial = Vector2.UP
	var tangent := Vector2(-radial.y, radial.x)
	var lane := float((token_index % 3) - 1)
	return base_position + radial * 34.0 + tangent * lane * 20.0


func _sceneized_route_segment(from_world: Vector2, to_world: Vector2) -> Dictionary:
	if _is_globe_mode():
		var from_projected := _project_globe(from_world)
		var to_projected := _project_globe(to_world)
		if not bool(from_projected.get("visible", true)) and not bool(to_projected.get("visible", true)):
			return {}
		return {
			"from_position": from_projected.get("position", Vector2.ZERO),
			"to_position": to_projected.get("position", Vector2.ZERO),
		}
	return {
		"from_position": _world_to_screen(from_world),
		"to_position": _world_to_screen(to_world),
	}


func _sceneized_map_event_effect_payload(effect: Dictionary, effect_index: int) -> Dictionary:
	var fallback_position := _as_vector2(effect.get("position", Vector2.ZERO))
	var kind := str(effect.get("kind", "impact"))
	var from_world := _as_vector2(effect.get("from", fallback_position))
	var to_world := _as_vector2(effect.get("to", fallback_position))
	var from_projected := _map_event_screen_position(from_world)
	var to_projected := _map_event_screen_position(to_world)
	var center_projected := _map_event_screen_position(fallback_position)
	var attack_effect := kind == "laser" or kind == "beam" or kind == "melee"
	if attack_effect and not bool(from_projected.get("visible", true)) and not bool(to_projected.get("visible", true)):
		return {}
	if not attack_effect and not bool(center_projected.get("visible", true)):
		return {}
	return {
		"kind": kind,
		"from_position": from_projected.get("position", Vector2.ZERO),
		"to_position": to_projected.get("position", center_projected.get("position", Vector2.ZERO)),
		"screen_position": center_projected.get("position", to_projected.get("position", Vector2.ZERO)),
		"label": str(effect.get("label", "")),
		"life": float(effect.get("life", effect.get("duration", 1.0))),
		"duration": float(effect.get("duration", 1.0)),
		"radius_px": maxf(12.0, float(effect.get("radius_m", 70.0)) * maxf(_scale, 0.1)),
		"motion_family": str(effect.get("motion_family", "")),
		"effect_layer": str(effect.get("effect_layer", "")),
		"card_style": str(effect.get("card_style", "")),
		"effect_index": effect_index,
		"accent": _color_to_hex(effect.get("color", Color("#fbbf24"))),
	}


func _action_callout_title(callout: Dictionary) -> String:
	if str(callout.get("title", "")) != "":
		return str(callout.get("title", ""))
	var actor := str(callout.get("actor", "Action"))
	var action := str(callout.get("action", ""))
	if action == "":
		return actor
	return "%s | %s" % [actor, action]


func _draw_legacy_map_underlay_without_sceneized_surfaces() -> void:
	legacy_draw_fallback_used = true
	var saved_trails := movement_trails
	var saved_callouts := action_callouts
	var saved_effects := map_event_effects
	movement_trails = []
	action_callouts = []
	map_event_effects = []
	super._draw()
	movement_trails = saved_trails
	action_callouts = saved_callouts
	map_event_effects = saved_effects


func _current_sceneized_projection_signature() -> String:
	var snapshot := get_projection_debug_snapshot() if has_method("get_projection_debug_snapshot") else {}
	var mode := str(snapshot.get("mode", ""))
	var center := _as_vector2(snapshot.get("view_center_m", Vector2.ZERO))
	return "|".join([
		str(int(size.x)),
		str(int(size.y)),
		str(districts.size()),
		str(selected_district),
		str(_rounded_float(float(snapshot.get("view_zoom", 0.0)), 100.0)),
		str(_rounded_float(float(snapshot.get("target_view_zoom", 0.0)), 100.0)),
		str(_rounded_float(float(snapshot.get("globe_blend", 0.0)), 100.0)),
		str(_rounded_float(center.x, 10.0)),
		str(_rounded_float(center.y, 10.0)),
		str(int(snapshot.get("focus_target_district", -1))),
		str(_rounded_float(float(snapshot.get("focus_beacon_alpha", 0.0)), 10.0)),
		mode,
		visual_layer_focus,
		str(sceneized_visual_cutover_enabled),
		str(legacy_draw_fallback_enabled),
	])


func _sceneized_structural_payload_signature(
	map_districts: Array,
	selected: int,
	map_city_markers: Array,
	map_route_markers: Array,
	map_trade_product: String,
	layer_focus: String
) -> String:
	return _build_visual_payload_signature(
		map_districts,
		selected,
		[],
		[],
		[],
		[],
		map_city_markers,
		map_route_markers,
		map_trade_product,
		layer_focus
	)


func _sceneized_overview_compact() -> bool:
	var snapshot := get_projection_debug_snapshot() if has_method("get_projection_debug_snapshot") else {}
	return str(snapshot.get("mode", "globe")) == "globe" or float(snapshot.get("globe_blend", 1.0)) > 0.62


func _overview_route_group_key(route: Dictionary) -> String:
	return "%s|%s" % [
		_route_product_display(route),
		"blocked" if bool(route.get("disrupted", false)) else "open",
	]


func _route_product_display(route: Dictionary) -> String:
	var product := str(route.get("product", trade_product)).strip_edges()
	return product if product != "" else "商路"


func _rounded_float(value: float, scale_value: float) -> float:
	if scale_value <= 0.0:
		return value
	return roundf(value * scale_value) / scale_value


func _sceneized_polygon_points(value: Variant) -> PackedVector2Array:
	var world_points := _route_points(value)
	if world_points.size() < 3:
		return PackedVector2Array()
	if _is_globe_mode():
		return _globe_projected_polygon(world_points)
	return _screen_polygon(world_points)


func _route_points(value: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not (value is Array):
		return result
	for item in value:
		result.append(_as_vector2(item))
	return result


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if value is Dictionary:
		var dict := value as Dictionary
		return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
	return Vector2.ZERO


func _palette_hex(index: int) -> String:
	if palette.is_empty():
		return "#38bdf8"
	var color_variant: Variant = palette[index % palette.size()]
	return _color_to_hex(color_variant)


func _route_accent_hex(product: String) -> String:
	match product:
		"ore", "工业商品":
			return "#94a3b8"
		"water", "航运商品":
			return "#38bdf8"
		"food", "生命商品":
			return "#22c55e"
		"fuel", "能源商品":
			return "#f97316"
		"data", "科技商品":
			return "#a855f7"
		"商贸商品":
			return "#c084fc"
	return "#facc15"


func _color_to_hex(value: Variant) -> String:
	if value is Color:
		return "#%s" % (value as Color).to_html(false)
	var text := str(value)
	if text.begins_with("#"):
		return text
	return "#%s" % text


func _live_node_count(nodes: Array[Node]) -> int:
	var count := 0
	for node in nodes:
		if is_instance_valid(node):
			count += 1
	return count


func _draw_sceneized_placeholder() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var center := rect.size * 0.5
	var radius := maxf(24.0, minf(rect.size.x, rect.size.y) * 0.32)
	draw_rect(rect, Color("#020617"), true)
	var outer := Color("#0f766e")
	outer.a = 0.16
	draw_circle(center, radius * 1.18, outer)
	draw_circle(center, radius, Color("#082f49"))
	draw_arc(center, radius + 8.0, 0.0, TAU, 96, Color("#facc15"), 1.4, true)
	draw_arc(center, radius * 0.64, 0.0, TAU, 80, Color("#38bdf8", 0.32), 1.0, true)
	draw_arc(center, radius * 0.38, 0.0, TAU, 72, Color("#22c55e", 0.26), 1.0, true)
	for i in range(6):
		var angle := TAU * float(i) / 6.0 - PI * 0.18
		var pos := center + Vector2(cos(angle), sin(angle)) * radius * 0.56
		var color := Color("#38bdf8").lerp(Color("#f59e0b"), float(i) / 5.0)
		color.a = 0.66
		draw_circle(pos, maxf(5.0, radius * 0.045), color)
	var font := get_theme_default_font()
	draw_string(
		font,
		center + Vector2(-radius * 0.72, radius + 26.0),
		preview_note,
		HORIZONTAL_ALIGNMENT_CENTER,
		radius * 1.44,
		12,
		Color("#cbd5e1")
	)
