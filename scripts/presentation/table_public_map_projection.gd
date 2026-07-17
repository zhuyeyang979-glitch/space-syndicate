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
	for value in [districts, city_markers, unit_markers, route_markers]:
		if not TablePresentationPureDataPolicy.is_pure_data(value):
			return {}
	return {
		"schema_version": 1,
		"viewer_index": viewer_index,
		"revision": revision,
		"districts": TablePresentationPureDataPolicy.detached_copy(districts),
		"city_markers": TablePresentationPureDataPolicy.detached_copy(city_markers),
		"unit_markers": TablePresentationPureDataPolicy.detached_copy(unit_markers),
		"route_markers": TablePresentationPureDataPolicy.detached_copy(route_markers),
		"selected_trade_product": selected_trade_product,
		"visibility_scope": "viewer_scoped_public",
	}
