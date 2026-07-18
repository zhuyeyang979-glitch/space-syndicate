extends RefCounted
class_name PublicPlayerSeatSnapshot

const STABLE_SEAT_POSITIONS := [
	&"left_low",
	&"right_low",
	&"left_mid_low",
	&"right_mid_low",
	&"left_mid_high",
	&"right_mid_high",
	&"left_high",
	&"right_high",
]
const LOCAL_PRESENTATION_SCALE := 1.10

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
	var positions: Array = STABLE_SEAT_POSITIONS.slice(0, ordered.size())
	var result: Array = []
	for index in range(mini(ordered.size(), positions.size())):
		var source: Dictionary = ordered[index]
		var seat_position: StringName = positions[index]
		var descriptor := {
			"seat_index": index,
			"player_index": int(source.get("player_index", index)),
			"public_player_name": str(source.get("public_player_name", "玩家%d" % (index + 1))),
			"role_name": str(source.get("role_name", "外星辛迪加")),
			"player_color": _as_color(source.get("player_color", Color.WHITE)),
			"seat_position": seat_position,
			"portrait_variant": &"side_inward",
			"mirror_h": str(seat_position).begins_with("right_"),
			"is_local_player": index == 0,
			"public_status": _public_status(source.get("public_status", &"waiting")),
			"is_publicly_active": bool(source.get("is_publicly_active", false)) and not bool(source.get("public_activity_is_anonymous", false)),
			"visual_scale": LOCAL_PRESENTATION_SCALE if index == 0 else 1.0,
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
	return &"front"


func _public_status(value: Variant) -> StringName:
	var normalized := StringName(str(value).strip_edges().to_lower())
	return normalized if normalized in [&"waiting", &"ready", &"active", &"eliminated", &"disconnected"] else &"waiting"


func _as_color(value: Variant) -> Color:
	if value is Color:
		return value
	if value is String and str(value).begins_with("#"):
		return Color(str(value))
	return Color.WHITE
