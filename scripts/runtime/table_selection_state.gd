@tool
extends Node
class_name TableSelectionState

signal selection_changed(snapshot: Dictionary)

const MAP_LAYER_FOCUS_IDS := [
	"all",
	"product",
	"route",
	"intel",
	"weather",
	"monster",
	"city",
	"economy",
	"military",
]

var _selected_player := 0
var _inspected_player := 0
var _selected_district := 0
var _selected_trade_product := ""
var _selected_card_resolution_id := -1
var _selected_hand_slot := -1
var _selected_map_layer_focus := "all"
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

var selected_card_resolution_id: int:
	get:
		return _selected_card_resolution_id
	set(value):
		_set_value(&"selected_card_resolution_id", value)

var selected_hand_slot: int:
	get:
		return _selected_hand_slot
	set(value):
		_set_value(&"selected_hand_slot", value)

var selected_map_layer_focus: String:
	get:
		return _selected_map_layer_focus
	set(value):
		_set_value(&"selected_map_layer_focus", value)


func reset() -> Dictionary:
	return restore({
		"selected_player": 0,
		"inspected_player": 0,
		"selected_district": 0,
		"selected_trade_product": "",
		"selected_card_resolution_id": -1,
		"selected_hand_slot": -1,
		"selected_map_layer_focus": "all",
	})


func set_active_context(player_index: int, district_index: int, product_id: String) -> Dictionary:
	return restore({
		"selected_player": player_index,
		"inspected_player": _inspected_player,
		"selected_district": district_index,
		"selected_trade_product": product_id,
	})


func inspected_player_index() -> int:
	return _inspected_player


func select_inspected_player(target_player_index: int, expected_selection_revision: int) -> Dictionary:
	if expected_selection_revision != _revision:
		return {
			"applied": false,
			"changed": false,
			"reason_code": "selection_revision_stale",
			"previous_inspected_player_index": _inspected_player,
			"inspected_player_index": _inspected_player,
			"selection_revision": _revision,
		}
	if target_player_index < 0:
		return {
			"applied": false,
			"changed": false,
			"reason_code": "target_player_invalid",
			"previous_inspected_player_index": _inspected_player,
			"inspected_player_index": _inspected_player,
			"selection_revision": _revision,
		}
	var previous := _inspected_player
	var changed := target_player_index != _inspected_player or target_player_index != _selected_player
	_selected_player = target_player_index
	_inspected_player = target_player_index
	if changed:
		_revision += 1
		selection_changed.emit(snapshot())
	return {
		"applied": true,
		"changed": changed,
		"reason_code": "inspection_applied" if changed else "inspection_unchanged",
		"previous_inspected_player_index": previous,
		"inspected_player_index": _inspected_player,
		"selection_revision": _revision,
	}


func inspected_player_snapshot() -> Dictionary:
	return {
		"inspected_player_index": _inspected_player,
		"selection_revision": _revision,
		"presentation_only": true,
	}


func select_district_target(target_district_index: int, expected_selection_revision: int, clear_hand_selection := true) -> Dictionary:
	if expected_selection_revision != _revision:
		return _target_result(false, false, "selection_revision_stale", {
			"previous_district_index": _selected_district,
			"district_index": _selected_district,
			"previous_hand_slot": _selected_hand_slot,
			"hand_slot": _selected_hand_slot,
		})
	if target_district_index < 0:
		return _target_result(false, false, "target_district_invalid", {
			"previous_district_index": _selected_district,
			"district_index": _selected_district,
			"previous_hand_slot": _selected_hand_slot,
			"hand_slot": _selected_hand_slot,
		})
	var previous_district := _selected_district
	var previous_hand_slot := _selected_hand_slot
	var next_hand_slot := -1 if clear_hand_selection else _selected_hand_slot
	var changed := target_district_index != _selected_district or next_hand_slot != _selected_hand_slot
	_selected_district = target_district_index
	_selected_hand_slot = next_hand_slot
	if changed:
		_revision += 1
		selection_changed.emit(snapshot())
	return _target_result(true, changed, "district_selection_applied" if changed else "district_selection_unchanged", {
		"previous_district_index": previous_district,
		"district_index": _selected_district,
		"previous_hand_slot": previous_hand_slot,
		"hand_slot": _selected_hand_slot,
	})


func select_trade_product_target(target_product_id: String, expected_selection_revision: int) -> Dictionary:
	if expected_selection_revision != _revision:
		return _target_result(false, false, "selection_revision_stale", {
			"previous_trade_product_id": _selected_trade_product,
			"trade_product_id": _selected_trade_product,
		})
	if target_product_id.length() > 80 or target_product_id.strip_edges() != target_product_id:
		return _target_result(false, false, "target_trade_product_invalid", {
			"previous_trade_product_id": _selected_trade_product,
			"trade_product_id": _selected_trade_product,
		})
	var previous := _selected_trade_product
	var changed := target_product_id != _selected_trade_product
	_selected_trade_product = target_product_id
	if changed:
		_revision += 1
		selection_changed.emit(snapshot())
	return _target_result(true, changed, "trade_product_selection_applied" if changed else "trade_product_selection_unchanged", {
		"previous_trade_product_id": previous,
		"trade_product_id": _selected_trade_product,
	})


func select_hand_target(target_slot: int, expected_selection_revision: int) -> Dictionary:
	if expected_selection_revision != _revision:
		return _target_result(false, false, "selection_revision_stale", {
			"previous_hand_slot": _selected_hand_slot,
			"hand_slot": _selected_hand_slot,
		})
	if target_slot < -1:
		return _target_result(false, false, "target_hand_slot_invalid", {
			"previous_hand_slot": _selected_hand_slot,
			"hand_slot": _selected_hand_slot,
		})
	var previous := _selected_hand_slot
	var changed := target_slot != _selected_hand_slot
	_selected_hand_slot = target_slot
	if changed:
		_revision += 1
		selection_changed.emit(snapshot())
	return _target_result(true, changed, "hand_selection_applied" if changed else "hand_selection_unchanged", {
		"previous_hand_slot": previous,
		"hand_slot": _selected_hand_slot,
	})


func restore(data: Dictionary) -> Dictionary:
	var next_player := int(data.get("selected_player", _selected_player))
	var next_inspected := int(data.get("inspected_player", _inspected_player))
	var next_district := int(data.get("selected_district", _selected_district))
	var next_product := str(data.get("selected_trade_product", _selected_trade_product))
	var next_resolution_id := int(data.get("selected_card_resolution_id", _selected_card_resolution_id))
	var next_hand_slot := int(data.get("selected_hand_slot", _selected_hand_slot))
	var next_map_layer_focus := _normalize_map_layer_focus(str(data.get("selected_map_layer_focus", _selected_map_layer_focus)))
	var changed := next_player != _selected_player \
		or next_inspected != _inspected_player \
		or next_district != _selected_district \
		or next_product != _selected_trade_product \
		or next_resolution_id != _selected_card_resolution_id \
		or next_hand_slot != _selected_hand_slot \
		or next_map_layer_focus != _selected_map_layer_focus
	_selected_player = next_player
	_inspected_player = next_inspected
	_selected_district = next_district
	_selected_trade_product = next_product
	_selected_card_resolution_id = next_resolution_id
	_selected_hand_slot = next_hand_slot
	_selected_map_layer_focus = next_map_layer_focus
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
		"selected_card_resolution_id": _selected_card_resolution_id,
		"selected_hand_slot": _selected_hand_slot,
		"selected_map_layer_focus": _selected_map_layer_focus,
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
	_selected_card_resolution_id = int(data.get("selected_card_resolution_id", -1))
	_selected_hand_slot = int(data.get("selected_hand_slot", -1))
	_selected_map_layer_focus = _normalize_map_layer_focus(str(data.get("selected_map_layer_focus", "all")))
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
	result["selected_player_semantics"] = "presentation_inspection_target"
	result["authorized_actor_source"] = "external_identity_authority"
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
		&"selected_card_resolution_id":
			var normalized_resolution_id := int(value)
			changed = normalized_resolution_id != _selected_card_resolution_id
			_selected_card_resolution_id = normalized_resolution_id
		&"selected_hand_slot":
			var normalized_hand_slot := int(value)
			changed = normalized_hand_slot != _selected_hand_slot
			_selected_hand_slot = normalized_hand_slot
		&"selected_map_layer_focus":
			var normalized_map_layer_focus := _normalize_map_layer_focus(str(value))
			changed = normalized_map_layer_focus != _selected_map_layer_focus
			_selected_map_layer_focus = normalized_map_layer_focus
	if changed:
		_revision += 1
		selection_changed.emit(snapshot())


func _normalize_map_layer_focus(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	return normalized if normalized in MAP_LAYER_FOCUS_IDS else "all"


func _target_result(applied: bool, changed: bool, reason_code: String, values: Dictionary) -> Dictionary:
	var result := {
		"applied": applied,
		"changed": changed,
		"reason_code": reason_code,
		"selection_revision": _revision,
	}
	result.merge(values, true)
	return result
