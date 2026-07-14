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

const EDITABLE_LAYER_NAMES := [
	"BackdropLayer",
	"OrbitLayer",
	"DistrictLayer",
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
var _sceneized_animation_sync_timer := 0.0
var _sceneized_projection_signature := ""
var _render_model: RefCounted = PlanetMapRenderModelScript.new()


func _ready() -> void:
	super._ready()
	_configure_editable_layers()
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
	if not _sceneized_animated_surfaces_active():
		return
	_sceneized_animation_sync_timer -= delta
	if _sceneized_animation_sync_timer <= 0.0:
		_sceneized_animation_sync_timer = 0.08
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
		new_trade_route_markers,
		new_trade_product,
		new_visual_layer_focus
	)
	_sceneized_projection_signature = ""
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


func _sync_sceneized_map_children() -> void:
	_sceneized_sync_queued = false
	if not is_inside_tree():
		return
	_configure_editable_layers()
	_sync_projection_metrics_for_query()
	_sync_underlay_components()
	_clear_sceneized_map_children()
	_sync_district_polygons()
	_sync_route_segments()
	_sync_movement_trails()
	_sync_route_markers()
	_sync_district_nodes()
	_sync_city_markers()
	_sync_monster_tokens()
	_sync_selection_marker()
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
			"screen_position": get_district_control_position(index),
			"selected": index == selected_district,
			"accent": _palette_hex(index),
		})
		if node.has_signal("district_pressed"):
			node.connect("district_pressed", Callable(self, "_on_sceneized_district_pressed"))
		_sceneized_district_nodes.append(node)


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
	for marker_variant in auto_monster_markers:
		if not (marker_variant is Dictionary):
			continue
		var marker: Dictionary = (marker_variant as Dictionary).duplicate(true)
		var node := PlanetMonsterTokenScene.instantiate() as Control
		if node == null:
			continue
		node.set_meta("sceneized_planet_map_child", true)
		node.set_meta("sceneized_planet_map_kind", "monster")
		monster_layer.add_child(node)
		node.call("configure", {
			"screen_position": _sceneized_world_to_control(marker.get("position", Vector2.ZERO)),
			"name": str(marker.get("name", "Monster")),
			"label": str(marker.get("label", "")),
			"glyph": str(marker.get("glyph", "M")),
			"motif": str(marker.get("motif", "threat")),
			"accent": _color_to_hex(marker.get("color", Color("#ef4444"))),
			"secondary": _color_to_hex(marker.get("secondary", Color("#fde68a"))),
		})
		_sceneized_monster_token_nodes.append(node)


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
				"segment_index": segment_index,
				"accent": _route_accent_hex(str(route.get("product", trade_product))),
			})
			_sceneized_route_segment_nodes.append(node)
			segment_index += 1


func _sync_route_markers() -> void:
	_sceneized_route_marker_nodes.clear()
	if route_layer == null:
		return
	for route_variant in trade_route_markers:
		if not (route_variant is Dictionary):
			continue
		var route: Dictionary = (route_variant as Dictionary).duplicate(true)
		if not bool(route.get("show_marker", true)):
			continue
		var points := _route_points(route.get("points", []))
		var node := PlanetRouteMarkerScene.instantiate() as Control
		if node == null:
			continue
		node.set_meta("sceneized_planet_map_child", true)
		node.set_meta("sceneized_planet_map_kind", "route")
		route_layer.add_child(node)
		node.call("configure", {
			"screen_position": _sceneized_route_midpoint(points),
			"product": str(route.get("product", trade_product)),
			"disrupted": bool(route.get("disrupted", false)),
			"point_count": points.size(),
			"accent": _route_accent_hex(str(route.get("product", trade_product))),
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
		"detail": "当前焦点｜%s" % str(entry.get("terrain", "地表区")),
		"screen_position": get_district_control_position(selected_district),
		"accent": "#facc15",
	})
	_sceneized_selection_nodes.append(node)


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
	var panel_width: float = minf(390.0, size.x * 0.52)
	var row_height := 52.0
	var panel_x: float = maxf(12.0, size.x - panel_width - 14.0)
	var first_index: int = max(0, action_callouts.size() - 4)
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


func _configure_editable_layers() -> void:
	backdrop_layer = get_node_or_null("BackdropLayer") as Control
	orbit_layer = get_node_or_null("OrbitLayer") as Control
	district_layer = get_node_or_null("DistrictLayer") as Control
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


func _rounded_float(value: float, scale_value: float) -> float:
	if scale_value <= 0.0:
		return value
	return roundf(value * scale_value) / scale_value


func _sceneized_animated_surfaces_active() -> bool:
	return not movement_trails.is_empty() or not action_callouts.is_empty() or not map_event_effects.is_empty()


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
