extends RefCounted
class_name V074MapGenesisRng

const STREAM_ID := "map_genesis_rng"
const MODULUS := 2147483647
const MULTIPLIER := 48271

var _state := 1
var _draw_count := 0


func _init(seed_value: int = 1, stream_namespace: String = STREAM_ID) -> void:
	reset(seed_value, stream_namespace)


func reset(seed_value: int, stream_namespace: String = STREAM_ID) -> void:
	_state = posmod(seed_value, MODULUS)
	if _state == 0:
		_state = 1
	for byte in stream_namespace.to_utf8_buffer():
		_state = posmod(_state * MULTIPLIER + int(byte) + 1, MODULUS)
		if _state == 0:
			_state = 1
	_draw_count = 0


func next_u31() -> int:
	_state = posmod(_state * MULTIPLIER, MODULUS)
	if _state == 0:
		_state = 1
	_draw_count += 1
	return _state


func next_unit() -> float:
	return float(next_u31() - 1) / float(MODULUS - 1)


func next_range(minimum: int, maximum: int) -> int:
	if maximum < minimum:
		return minimum
	var span := maximum - minimum + 1
	return minimum + (next_u31() % span)


func next_signed() -> float:
	return next_unit() * 2.0 - 1.0


func next_unit_vector() -> Vector3:
	var z := next_signed()
	var angle := next_unit() * TAU
	var radius := sqrt(maxf(0.0, 1.0 - z * z))
	return Vector3(radius * cos(angle), z, radius * sin(angle)).normalized()


func snapshot() -> Dictionary:
	return {
		"stream_id": STREAM_ID,
		"state": _state,
		"draw_count": _draw_count,
	}


func draw_count() -> int:
	return _draw_count


func state() -> int:
	return _state
