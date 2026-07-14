@tool
extends Node
class_name SolarAvailabilityRuntimeService

const WORLD_ROTATION_PERIOD_US := 120_000_000
const INITIAL_SUBSOLAR_TURN := 0.0
const ZERO_DOT_EPSILON := 0.000000001

var _configured := false
var _evaluation_count := 0


func configure(_config: Dictionary = {}) -> void:
	_configured = true


func availability(world_effective_us: int, center_x: float, world_width: float, destroyed := false) -> Dictionary:
	_evaluation_count += 1
	if not _configured or world_effective_us < 0 or not is_finite(center_x) or not is_finite(world_width) or world_width <= 0.0:
		return _unavailable("invalid_solar_facts")
	var center_turn := fposmod(center_x / world_width, 1.0)
	var sun_turn := sun_turn_at(world_effective_us)
	var center_angle := center_turn * TAU
	var sun_angle := sun_turn * TAU
	var dot := cos(center_angle - sun_angle)
	var sunlit := not destroyed and dot >= -ZERO_DOT_EPSILON
	return {
		"viewable": not destroyed,
		"purchasable": sunlit,
		"availability_kind": "sunlit" if sunlit else ("destroyed" if destroyed else "dark"),
		"reason_code": "sunlit" if sunlit else ("source_region_destroyed" if destroyed else "source_region_dark"),
		"world_effective_us": world_effective_us,
		"rotation_period_us": WORLD_ROTATION_PERIOD_US,
		"center_turn_ppm": int(round(center_turn * 1_000_000.0)),
		"sun_turn_ppm": int(round(sun_turn * 1_000_000.0)),
		"dot_millionths": int(round(dot * 1_000_000.0)),
	}


func sun_turn_at(world_effective_us: int) -> float:
	if world_effective_us < 0:
		return INITIAL_SUBSOLAR_TURN
	return fposmod(INITIAL_SUBSOLAR_TURN + float(world_effective_us % WORLD_ROTATION_PERIOD_US) / float(WORLD_ROTATION_PERIOD_US), 1.0)


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"pure_derivation": true,
		"rotation_period_us": WORLD_ROTATION_PERIOD_US,
		"fixed_initial_turn_ppm": int(round(INITIAL_SUBSOLAR_TURN * 1_000_000.0)),
		"evaluation_count": _evaluation_count,
		"owns_solar_phase": false,
	}


func _unavailable(reason_code: String) -> Dictionary:
	return {
		"viewable": false,
		"purchasable": false,
		"availability_kind": "invalid",
		"reason_code": reason_code,
	}
