extends RefCounted
class_name MapPresentationSnapshot

var revision := 0
var viewer_index := -1
var authorization_revision := 0
var districts: Array = []
var width_m := 1.0
var height_m := 1.0
var selected_district := -1
var palette: Array[Color] = []
var movement_trails: Array = []
var action_callouts: Array = []
var map_event_effects: Array = []
var unit_markers: Array = []
var city_markers: Array = []
var route_markers: Array = []
var selected_trade_product := ""
var selected_map_layer_focus := "all"
var solar_presentation: Dictionary = {}
var weather_forecast: Dictionary = {}
var weather_overlay: Dictionary = {}
var motion_mode := "full"


func is_valid() -> bool:
	return revision >= 0 and viewer_index >= 0 and authorization_revision > 0 \
		and width_m > 0.0 and height_m > 0.0 \
		and TablePresentationPureDataPolicy.is_pure_data([
			districts, palette, movement_trails, action_callouts, map_event_effects,
			unit_markers, city_markers, route_markers, selected_trade_product,
			selected_map_layer_focus,
			solar_presentation, weather_forecast, weather_overlay, motion_mode,
		])
