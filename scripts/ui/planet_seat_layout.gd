@tool
class_name PlanetSeatLayout
extends RefCounted

const BASE_VIEWPORT := Vector2(1600.0, 960.0)

const STABLE_SLOTS := [
	"left_low", "right_low", "left_mid_low", "right_mid_low",
	"left_mid_high", "right_mid_high", "left_high", "right_high",
]

const SLOT_CENTERS := {
	"left_high": Vector2(0.10, 0.20),
	"left_mid_high": Vector2(0.10, 0.38),
	"left_mid_low": Vector2(0.10, 0.56),
	"left_low": Vector2(0.10, 0.74),
	"right_high": Vector2(0.90, 0.20),
	"right_mid_high": Vector2(0.90, 0.38),
	"right_mid_low": Vector2(0.90, 0.56),
	"right_low": Vector2(0.90, 0.74),
}

const SLOT_SIZES := {
	"left_high": Vector2(145.0, 190.0),
	"left_mid_high": Vector2(145.0, 190.0),
	"left_mid_low": Vector2(145.0, 190.0),
	"left_low": Vector2(159.5, 209.0),
	"right_high": Vector2(145.0, 190.0),
	"right_mid_high": Vector2(145.0, 190.0),
	"right_mid_low": Vector2(145.0, 190.0),
	"right_low": Vector2(145.0, 190.0),
}


static func supported_player_counts() -> PackedInt32Array:
	return PackedInt32Array([3, 4, 5, 6, 7, 8])


static func slot_names(player_count: int) -> PackedStringArray:
	var clamped_count := clampi(player_count, 3, 8)
	var values: Array = STABLE_SLOTS.slice(0, clamped_count)
	var result := PackedStringArray()
	for value in values:
		result.append(str(value))
	return result


static func resolve(player_count: int, viewport_size: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var safe_size := Vector2(maxf(viewport_size.x, 960.0), maxf(viewport_size.y, 640.0))
	var scale_factor := clampf(minf(safe_size.x / BASE_VIEWPORT.x, safe_size.y / BASE_VIEWPORT.y), 0.68, 1.15)
	var slots := slot_names(player_count)
	for seat_index in slots.size():
		var slot_name := slots[seat_index]
		var base_size: Vector2 = SLOT_SIZES[slot_name]
		var seat_size := base_size * scale_factor
		var center: Vector2 = safe_size * (SLOT_CENTERS[slot_name] as Vector2)
		result.append({
			"seat_index": seat_index,
			"slot_name": slot_name,
			"position": (center - seat_size * 0.5).round(),
			"size": seat_size.round(),
			"layer": _layer_for_slot(slot_name),
			"portrait_view": _portrait_view_for_slot(slot_name),
			"flip_horizontal": slot_name.begins_with("right_"),
			"local_player": seat_index == 0,
			"faces_planet": true,
		})
	return result


static func debug_snapshot(player_count: int, viewport_size: Vector2) -> Dictionary:
	var rows := resolve(player_count, viewport_size)
	var back_count := 0
	var front_count := 0
	for row in rows:
		if str(row.get("layer", "")) == "BackSeatLayer":
			back_count += 1
		else:
			front_count += 1
	return {
		"player_count": clampi(player_count, 3, 8),
		"seat_count": rows.size(),
		"back_seat_count": back_count,
		"front_seat_count": front_count,
		"local_slot": "left_low",
		"slots": slot_names(player_count),
	}


static func _layer_for_slot(slot_name: String) -> String:
	return "FrontSeatLayer"


static func _portrait_view_for_slot(slot_name: String) -> String:
	return "side_inward"
