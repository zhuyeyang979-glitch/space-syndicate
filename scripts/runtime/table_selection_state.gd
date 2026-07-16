@tool
extends Node
class_name TableSelectionState

signal selection_changed(snapshot: Dictionary)

var _selected_player := 0
var _inspected_player := 0
var _selected_district := 0
var _selected_trade_product := ""
var _revision := 0

var selected_player: int:
	get:
		return _selected_player
	set(value):
		_set_value(&"selected_player", value)

var inspected_player: int:
	get:
		return _inspected_player
	set(value):
		_set_value(&"inspected_player", value)

var selected_district: int:
	get:
		return _selected_district
	set(value):
		_set_value(&"selected_district", value)

var selected_trade_product: String:
	get:
		return _selected_trade_product
	set(value):
		_set_value(&"selected_trade_product", value)


func reset() -> Dictionary:
	return restore({
		"selected_player": 0,
		"inspected_player": 0,
		"selected_district": 0,
		"selected_trade_product": "",
	})


func set_active_context(player_index: int, district_index: int, product_id: String) -> Dictionary:
	return restore({
		"selected_player": player_index,
		"inspected_player": _inspected_player,
		"selected_district": district_index,
		"selected_trade_product": product_id,
	})


func restore(data: Dictionary) -> Dictionary:
	var next_player := int(data.get("selected_player", _selected_player))
	var next_inspected := int(data.get("inspected_player", _inspected_player))
	var next_district := int(data.get("selected_district", _selected_district))
	var next_product := str(data.get("selected_trade_product", _selected_trade_product))
	var changed := next_player != _selected_player \
		or next_inspected != _inspected_player \
		or next_district != _selected_district \
		or next_product != _selected_trade_product
	_selected_player = next_player
	_inspected_player = next_inspected
	_selected_district = next_district
	_selected_trade_product = next_product
	if changed:
		_revision += 1
		selection_changed.emit(snapshot())
	return snapshot()


func snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"selected_player": _selected_player,
		"inspected_player": _inspected_player,
		"selected_district": _selected_district,
		"selected_trade_product": _selected_trade_product,
		"revision": _revision,
	}


func to_save_data() -> Dictionary:
	return snapshot()


func apply_save_data(data: Dictionary) -> Dictionary:
	if int(data.get("schema_version", -1)) != 1:
		return {
			"applied": false,
			"reason_code": "table_selection_save_invalid",
		}
	_selected_player = int(data.get("selected_player", 0))
	_inspected_player = int(data.get("inspected_player", _selected_player))
	_selected_district = int(data.get("selected_district", 0))
	_selected_trade_product = str(data.get("selected_trade_product", ""))
	_revision = maxi(0, int(data.get("revision", 0)))
	var restored := snapshot()
	selection_changed.emit(restored)
	return {
		"applied": true,
		"reason_code": "table_selection_restored",
		"selection": restored,
	}


func debug_snapshot() -> Dictionary:
	var result := snapshot()
	result["owns_table_selection_state"] = true
	result["private_player_state_exposed"] = false
	return result


func _set_value(property_name: StringName, value: Variant) -> void:
	var changed := false
	match property_name:
		&"selected_player":
			var normalized_player := int(value)
			changed = normalized_player != _selected_player
			_selected_player = normalized_player
		&"inspected_player":
			var normalized_inspected := int(value)
			changed = normalized_inspected != _inspected_player
			_inspected_player = normalized_inspected
		&"selected_district":
			var normalized_district := int(value)
			changed = normalized_district != _selected_district
			_selected_district = normalized_district
		&"selected_trade_product":
			var normalized_product := str(value)
			changed = normalized_product != _selected_trade_product
			_selected_trade_product = normalized_product
	if changed:
		_revision += 1
		selection_changed.emit(snapshot())
