@tool
extends Node
class_name WorldEffectiveClockRuntimeController

const MICROS_PER_SECOND := 1_000_000

var _configured := false
var _world_effective_us := 0
var _fractional_microseconds := 0.0
var _advance_count := 0


func configure(_config: Dictionary = {}) -> void:
	_configured = true


func reset_state() -> void:
	_world_effective_us = 0
	_fractional_microseconds = 0.0
	_advance_count = 0


func advance(delta_seconds: float) -> Dictionary:
	if not _configured or not is_finite(delta_seconds) or delta_seconds < 0.0:
		return snapshot()
	var accumulated_us := delta_seconds * float(MICROS_PER_SECOND) + _fractional_microseconds
	var delta_us := int(floor(accumulated_us))
	_fractional_microseconds = accumulated_us - float(delta_us)
	if delta_us > 0:
		_world_effective_us += delta_us
		_advance_count += 1
	return snapshot()


func restore_seconds(seconds: float) -> Dictionary:
	if not _configured or not is_finite(seconds) or seconds < 0.0:
		return snapshot()
	_world_effective_us = int(round(seconds * float(MICROS_PER_SECOND)))
	_fractional_microseconds = 0.0
	return snapshot()


func restore_micros(value: int) -> Dictionary:
	if _configured:
		_world_effective_us = maxi(0, value)
		_fractional_microseconds = 0.0
	return snapshot()


func world_effective_micros() -> int:
	return _world_effective_us


func world_effective_seconds() -> float:
	return float(_world_effective_us) / float(MICROS_PER_SECOND)


func snapshot() -> Dictionary:
	return {
		"clock_domain": "world_effective",
		"world_effective_us": _world_effective_us,
		"world_effective_seconds": world_effective_seconds(),
	}


func debug_snapshot() -> Dictionary:
	return {
		"controller_ready": _configured,
		"clock_domain": "world_effective",
		"integer_authority": true,
		"world_effective_us": _world_effective_us,
		"advance_count": _advance_count,
		"fractional_microseconds_runtime_only": _fractional_microseconds,
		"owns_solar_phase": false,
	}
