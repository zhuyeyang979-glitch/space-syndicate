extends Control
class_name V074PlanetPresentationBench

const Support := preload("res://tests/v074_planet_test_support.gd")
const Adapter := preload("res://scripts/presentation/v074/v074_planet_presentation_adapter_v1.gd")

@onready var map_view: Control = %PlanetMapView
@onready var status_label: Label = %StatusLabel
@onready var reset_button: Button = %ResetButton
@onready var focus_button: Button = %FocusButton
@onready var zoom_button: Button = %ZoomButton

var _adapter: RefCounted
var _fixture: RefCounted
var _receipt: Dictionary = {}
var _selection_count := 0
var _last_selected_index := -1


func _ready() -> void:
	_adapter = Adapter.new()
	_fixture = Support.build_receipt(24, "COMPLEX")
	_receipt = Support.build_lane_a_boundary_receipt(_fixture, true)
	if reset_button != null:
		reset_button.pressed.connect(_on_reset_pressed)
	if focus_button != null:
		focus_button.pressed.connect(_on_focus_pressed)
	if zoom_button != null:
		zoom_button.pressed.connect(_on_zoom_pressed)
	if map_view != null:
		map_view.connect("district_selected", Callable(self, "_on_district_selected"))
	call_deferred("_apply_fixture")


func _apply_fixture() -> void:
	if map_view == null:
		return
	var payload := _adapter.call("build_map_view_payload", _receipt, Support.public_projection(_fixture)) as Dictionary
	var applied := bool(map_view.call("apply_v074_map_view_payload", payload))
	if status_label != null:
		status_label.text = "24 regions · COMPLEX · BALANCED · F/M/W · %s" % ("CONNECTED" if applied else "FAILED")


func _on_reset_pressed() -> void:
	map_view.call("reset_to_planet_overview")
	if status_label != null:
		status_label.text = "24 regions · COMPLEX · BALANCED · F/M/W · CONNECTED"


func _on_focus_pressed() -> void:
	map_view.call("focus_district", 7, true)
	if status_label != null:
		status_label.text = "Region 08 focused · F/M/W visible"


func _on_zoom_pressed() -> void:
	map_view.call("zoom_to_local_projection")
	if status_label != null:
		status_label.text = "Local projection · F/M/W visible"


func _on_district_selected(index: int) -> void:
	_selection_count += 1
	_last_selected_index = index
	if status_label != null:
		status_label.text = "Region %02d selected · click %d · F/M/W visible" % [index + 1, _selection_count]


func debug_snapshot() -> Dictionary:
	var map_debug := map_view.call("get_sceneization_debug_snapshot") as Dictionary if map_view != null else {}
	var planet_debug := map_view.call("v074_planet_debug_snapshot") as Dictionary if map_view != null else {}
	var backdrop_debug: Dictionary = {}
	if map_view != null:
		var backdrop := map_view.get_node_or_null("BackdropLayer/PlanetGlobeBackdrop")
		if backdrop != null and backdrop.has_method("debug_snapshot"):
			backdrop_debug = backdrop.call("debug_snapshot") as Dictionary
	return {
		"schema": "V074PlanetPresentationBenchDebugV1",
		"map_connected": not planet_debug.is_empty(),
		"region_count": int(planet_debug.get("region_count", 0)),
		"selection_count": _selection_count,
		"last_selected_index": _last_selected_index,
		"map": map_debug,
		"planet": planet_debug,
		"backdrop": backdrop_debug,
	}
