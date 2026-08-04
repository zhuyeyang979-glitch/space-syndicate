extends RefCounted
class_name V073ResponsiveTableLayoutV2

const COMPACT_DESKTOP := "COMPACT_DESKTOP"
const REGULAR_DESKTOP := "REGULAR_DESKTOP"
const WIDE_DESKTOP := "WIDE_DESKTOP"


static func profile_for(viewport_size: Vector2, player_count: int) -> Dictionary:
	var mode := REGULAR_DESKTOP
	if viewport_size.x >= 1800.0 and viewport_size.y >= 1000.0:
		mode = WIDE_DESKTOP
	elif viewport_size.x < 1500.0 or viewport_size.y < 880.0:
		mode = COMPACT_DESKTOP
	var crowded_roster := player_count > 4
	match mode:
		COMPACT_DESKTOP:
			return _profile(mode, 82.0, 112.0, 250.0, 220.0, 36.0, 192.0, 212.0 if crowded_roster else 168.0, false, 2)
		WIDE_DESKTOP:
			return _profile(mode, 82.0, 132.0, 500.0, 460.0, 40.0, 204.0, 244.0 if crowded_roster else 210.0, true, 6)
		_:
			return _profile(mode, 82.0, 128.0, 380.0, 340.0, 38.0, 198.0, 228.0 if crowded_roster else 190.0, true, 5)


static func _profile(
	mode: String,
	header_height: float,
	track_height: float,
	table_height: float,
	planet_stage_height: float,
	target_height: float,
	dock_height: float,
	roster_width: float,
	show_weather: bool,
	separation: int
) -> Dictionary:
	return {
		"schema": "V073ResponsiveTableLayoutV2",
		"mode": mode,
		"header_height": header_height,
		"track_height": track_height,
		"table_height": table_height,
		"planet_stage_height": planet_stage_height,
		"target_height": target_height,
		"dock_height": dock_height,
		"roster_width": roster_width,
		"show_weather": show_weather,
		"shell_separation": separation,
		"map_priority": "highest_remaining_space",
		"player_count_aware": true,
		"width_aware": true,
		"height_aware": true,
	}


static func debug_snapshot(viewport_size: Vector2, player_count: int) -> Dictionary:
	var profile := profile_for(viewport_size, player_count)
	return {
		"owner_id": "V073ResponsiveTableLayoutV2",
		"mode": profile.get("mode", REGULAR_DESKTOP),
		"viewport_size": viewport_size,
		"player_count": player_count,
		"gameplay_owner_count": 0,
		"ruleset_value_change_count": 0,
	}
