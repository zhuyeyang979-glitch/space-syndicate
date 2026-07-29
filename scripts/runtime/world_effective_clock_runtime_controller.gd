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


func capture_runtime_checkpoint() -> Dictionary:
	return {
		"schema_version": 1,
		"configured": _configured,
		"world_effective_us": _world_effective_us,
		"fractional_microseconds": _fractional_microseconds,
		"advance_count": _advance_count,
	}


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	var expected := ["schema_version", "configured", "world_effective_us", "fractional_microseconds", "advance_count"]
	if checkpoint.keys().size() != expected.size():
		return {"applied": false, "reason_code": "world_clock_checkpoint_invalid"}
	for key in expected:
		if not checkpoint.has(key):
			return {"applied": false, "reason_code": "world_clock_checkpoint_invalid"}
	if not (checkpoint.get("schema_version") is int) \
			or int(checkpoint.get("schema_version", 0)) != 1 \
			or not (checkpoint.get("configured") is bool) \
			or not (checkpoint.get("world_effective_us") is int) \
			or int(checkpoint.get("world_effective_us", -1)) < 0 \
			or not (checkpoint.get("fractional_microseconds") is float) \
			or not is_finite(float(checkpoint.get("fractional_microseconds", 0.0))) \
			or float(checkpoint.get("fractional_microseconds", -1.0)) < 0.0 \
			or float(checkpoint.get("fractional_microseconds", 1.0)) >= 1.0 \
			or not (checkpoint.get("advance_count") is int) \
			or int(checkpoint.get("advance_count", -1)) < 0:
		return {"applied": false, "reason_code": "world_clock_checkpoint_invalid"}
	_configured = bool(checkpoint.get("configured", false))
	_world_effective_us = int(checkpoint.get("world_effective_us", 0))
	_fractional_microseconds = float(checkpoint.get("fractional_microseconds", 0.0))
	_advance_count = int(checkpoint.get("advance_count", 0))
	return {"applied": true, "reason_code": "world_clock_checkpoint_restored"}


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
