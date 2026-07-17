@tool
class_name PlanetSeatLayout
extends RefCounted

const BASE_VIEWPORT := Vector2(1600.0, 960.0)

const LAYOUTS := {
	3: ["bottom", "left_mid", "right_mid"],
	4: ["bottom", "left_mid", "top", "right_mid"],
	5: ["bottom", "left_high", "left_low", "right_high", "right_low"],
	6: ["bottom", "left_high", "left_low", "top", "right_high", "right_low"],
	7: ["bottom", "left_high", "left_mid", "left_low", "right_high", "right_mid", "right_low"],
	8: ["bottom", "left_high", "left_mid", "left_low", "top", "right_high", "right_mid", "right_low"],
}

const SLOT_CENTERS := {
	"bottom": Vector2(0.50, 0.79),
	"top": Vector2(0.50, 0.125),
	"left_high": Vector2(0.115, 0.16),
	"left_mid": Vector2(0.065, 0.405),
	"left_low": Vector2(0.125, 0.66),
	"right_high": Vector2(0.885, 0.16),
	"right_mid": Vector2(0.935, 0.405),
	"right_low": Vector2(0.875, 0.66),
}

const SLOT_SIZES := {
	"bottom": Vector2(220.0, 280.0),
	"top": Vector2(170.0, 220.0),
	"left_mid": Vector2(160.0, 210.0),
	"right_mid": Vector2(160.0, 210.0),
	"left_high": Vector2(145.0, 190.0),
	"right_high": Vector2(145.0, 190.0),
	"left_low": Vector2(145.0, 190.0),
	"right_low": Vector2(145.0, 190.0),
}


static func supported_player_counts() -> PackedInt32Array:
	return PackedInt32Array([3, 4, 5, 6, 7, 8])


static func slot_names(player_count: int) -> PackedStringArray:
	var clamped_count := clampi(player_count, 3, 8)
	var values: Array = LAYOUTS.get(clamped_count, LAYOUTS[4])
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
			"local_player": slot_name == "bottom",
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
		"local_slot": "bottom",
		"slots": slot_names(player_count),
	}


static func _layer_for_slot(slot_name: String) -> String:
	if slot_name == "bottom" or slot_name.ends_with("_low"):
		return "FrontSeatLayer"
	return "BackSeatLayer"


static func _portrait_view_for_slot(slot_name: String) -> String:
	if slot_name == "bottom" or slot_name == "top":
		return "front"
	return "side_inward"
