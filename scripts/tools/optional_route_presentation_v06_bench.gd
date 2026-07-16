extends Control
class_name OptionalRoutePresentationV06Bench

const ACCEPTANCE_WINDOW_SIZE := Vector2i(1280, 720)

@onready var embedded_map: Control = %EmbeddedRouteMap
@onready var fullscreen_map: Control = %FullscreenRouteMap
@onready var status_label: Label = %RouteBenchStatus
@onready var hidden_button: Button = %HideRoutesButton
@onready var crystal_button: Button = %CrystalRouteButton
@onready var algae_button: Button = %AlgaeRouteButton


func _ready() -> void:
	get_window().size = ACCEPTANCE_WINDOW_SIZE
	hidden_button.pressed.connect(_select_product.bind(""))
	crystal_button.pressed.connect(_select_product.bind("晶雾"))
	algae_button.pressed.connect(_select_product.bind("氦藻"))
	_configure_maps()
	_select_product("晶雾")


func _configure_maps() -> void:
	var summaries := {
		"available": true,
		"public_revision": 3,
		"selected_commodity_id": "",
		"rows": [
			_flow("sale-001", "晶雾", "route:sale", "high", "market_sale", false),
			_flow("ambient-001", "晶雾", "", "trace", "ambient_consumption", false).merged({"ambient_one_hop": true, "transport_modes": [], "low_emphasis": true}, true),
			_flow("warehouse-001", "氦藻", "route:warehouse", "medium", "warehouse_inbound", true),
		],
	}
	var districts := [
		{"region_id": "region.a", "name": "A", "center": Vector2(170, 260)},
		{"region_id": "region.b", "name": "B", "center": Vector2(470, 390)},
	]
	var geometry := {
		"route:sale": [Vector2(170, 260), Vector2(360, 165), Vector2(520, 290)],
		"route:warehouse": [Vector2(180, 280), Vector2(500, 430)],
	}
	for map_view in [embedded_map, fullscreen_map]:
		map_view.call("set_optional_route_public_geometry", geometry)
		map_view.call("set_optional_route_public_snapshot", summaries, 100.0)
		map_view.call("set_map", districts, 1400.0, 950.0, -1, [Color("#38bdf8"), Color("#22c55e")], [], [], [], [], [], [], "晶雾", "route")


func _select_product(product_id: String) -> void:
	for map_view in [embedded_map, fullscreen_map]:
		map_view.call("set_optional_route_selection", product_id)
	call_deferred("_report_bench_state")


func _report_bench_state() -> void:
	var embedded := embedded_map.call("optional_route_presentation_snapshot") as Dictionary
	var fullscreen := fullscreen_map.call("optional_route_presentation_snapshot") as Dictionary
	var viewport_rect := get_viewport().get_visible_rect()
	var exact_target_window := get_window().size == ACCEPTANCE_WINDOW_SIZE
	var editor_embedded_host := not exact_target_window and viewport_rect.size.is_equal_approx(Vector2(1600, 960))
	var layout_ok := (exact_target_window or editor_embedded_host) \
		and embedded_map.get_global_rect().intersection(fullscreen_map.get_global_rect()).get_area() <= 0.01 \
		and viewport_rect.encloses(hidden_button.get_global_rect())
	var passed := int(embedded.get("visible_route_count", -1)) == int(fullscreen.get("visible_route_count", -2)) and layout_ok
	status_label.text = "%s｜嵌入 %d 条｜全图 %d 条｜1280×720 %s" % [
		"PASS" if passed else "FAIL",
		int(embedded.get("visible_route_count", 0)),
		int(fullscreen.get("visible_route_count", 0)),
		"无遮挡" if layout_ok else "需调整",
	]
	print("OPTIONAL_ROUTE_PRESENTATION_V06_BENCH|passed=%s|window=%s|viewport=%s|window_mode=%s|embedded=%d|fullscreen=%d|layout=%s" % [
		str(passed),
		str(get_window().size),
		str(viewport_rect.size),
		"exact_1280x720" if exact_target_window else "editor_embedded_1600x960",
		int(embedded.get("visible_route_count", 0)),
		int(fullscreen.get("visible_route_count", 0)),
		str(layout_ok),
	])
	if not passed:
		push_error("OptionalRoutePresentationV06Bench failed.")
	if DisplayServer.get_name().to_lower() == "headless":
		get_tree().quit(0 if passed else 1)


func _flow(event_id: String, commodity_id: String, route_id: String, band: String, kind: String, limited: bool) -> Dictionary:
	return {
		"flow_event_id": event_id,
		"public_revision": 1,
		"commodity_id": commodity_id,
		"from_region_id": "region.a",
		"to_region_id": "region.b",
		"flow_kind": kind,
		"display_label": "A → B",
		"route_id": route_id,
		"transport_modes": ["land"],
		"delivered_units_band": band,
		"capacity_limited": limited,
		"congested": false,
		"last_active_world_effective": 99.0,
		"activity_state": "recent",
		"ambient_one_hop": false,
		"low_emphasis": false,
	}
