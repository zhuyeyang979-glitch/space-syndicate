extends RefCounted
class_name TablePublicMapProjection

var viewer_index := -1
var revision := 0
var districts: Array = []
var city_markers: Array = []
var unit_markers: Array = []
var route_markers: Array = []
var selected_trade_product := ""


func to_dictionary() -> Dictionary:
	return {
		"schema_version": 1,
		"viewer_index": viewer_index,
		"revision": revision,
		"districts": districts.duplicate(true),
		"city_markers": city_markers.duplicate(true),
		"unit_markers": unit_markers.duplicate(true),
		"route_markers": route_markers.duplicate(true),
		"selected_trade_product": selected_trade_product,
		"visibility_scope": "viewer_scoped_public",
	}
