extends RefCounted
class_name PublicPlayerSeatSnapshot

const LAYOUTS := {
	3: [&"bottom", &"left_mid", &"right_mid"],
	4: [&"bottom", &"left_mid", &"top", &"right_mid"],
	5: [&"bottom", &"left_high", &"left_low", &"right_high", &"right_low"],
	6: [&"bottom", &"left_high", &"left_low", &"top", &"right_high", &"right_low"],
	7: [&"bottom", &"left_high", &"left_mid", &"left_low", &"right_high", &"right_mid", &"right_low"],
	8: [&"bottom", &"left_high", &"left_mid", &"left_low", &"top", &"right_high", &"right_mid", &"right_low"],
}

const ALLOWED_SOURCE_KEYS := [
	"player_index",
	"public_player_name",
	"role_name",
	"player_color",
	"is_local_player",
	"public_status",
	"is_publicly_active",
	"public_activity_is_anonymous",
]


func compose(source_entries: Array) -> Array:
	var sanitized := _sanitize_sources(source_entries)
	if sanitized.size() < 3 or sanitized.size() > 8:
		return []
	var local_offset := _local_source_offset(sanitized)
	var ordered := _rotate_local_first(sanitized, local_offset)
	var positions: Array = LAYOUTS.get(ordered.size(), [])
	var result: Array = []
	for index in range(mini(ordered.size(), positions.size())):
		var source: Dictionary = ordered[index]
		var seat_position: StringName = positions[index]
		var descriptor := {
			"player_index": int(source.get("player_index", index)),
			"public_player_name": str(source.get("public_player_name", "玩家%d" % (index + 1))),
			"role_name": str(source.get("role_name", "外星辛迪加")),
			"player_color": _as_color(source.get("player_color", Color.WHITE)),
			"seat_position": seat_position,
			"portrait_variant": &"front" if seat_position in [&"bottom", &"top"] else &"side_inward",
			"mirror_h": str(seat_position).begins_with("right_"),
			"is_local_player": index == 0,
			"public_status": _public_status(source.get("public_status", &"waiting")),
			"is_publicly_active": bool(source.get("is_publicly_active", false)) and not bool(source.get("public_activity_is_anonymous", false)),
			"visual_scale": _visual_scale(seat_position),
			"depth_group": _depth_group(seat_position),
		}
		result.append(descriptor)
	return result


func _sanitize_sources(source_entries: Array) -> Array:
	var result: Array = []
	var seen := {}
	for source_variant in source_entries:
		if not (source_variant is Dictionary):
			continue
		var source: Dictionary = source_variant
		var player_index := int(source.get("player_index", -1))
		if player_index < 0 or seen.has(player_index):
			continue
		seen[player_index] = true
		var safe := {}
		for key in ALLOWED_SOURCE_KEYS:
			if source.has(key):
				safe[key] = source[key]
		safe["player_index"] = player_index
		result.append(safe)
	return result


func _local_source_offset(entries: Array) -> int:
	for index in range(entries.size()):
		if bool((entries[index] as Dictionary).get("is_local_player", false)):
			return index
	return 0


func _rotate_local_first(entries: Array, local_offset: int) -> Array:
	var result: Array = []
	for offset in range(entries.size()):
		result.append((entries[(local_offset + offset) % entries.size()] as Dictionary).duplicate(true))
	return result


func _depth_group(seat_position: StringName) -> StringName:
	return &"back" if seat_position in [&"top", &"left_high", &"right_high"] else &"front"


func _visual_scale(seat_position: StringName) -> float:
	if seat_position == &"top":
		return 0.84
	if seat_position in [&"left_high", &"right_high"]:
		return 0.90
	if seat_position in [&"left_mid", &"right_mid"]:
		return 0.96
	return 1.0


func _public_status(value: Variant) -> StringName:
	var normalized := StringName(str(value).strip_edges().to_lower())
	return normalized if normalized in [&"waiting", &"ready", &"active", &"eliminated", &"disconnected"] else &"waiting"


func _as_color(value: Variant) -> Color:
	if value is Color:
		return value
	if value is String and str(value).begins_with("#"):
		return Color(str(value))
	return Color.WHITE
