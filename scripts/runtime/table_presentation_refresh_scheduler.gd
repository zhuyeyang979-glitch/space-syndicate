@tool
extends Node
class_name TablePresentationRefreshScheduler

const LIVE_KIND := &"live"
const MAP_KIND := &"map"
const FULL_KIND := &"full"
const DEVELOPER_KIND := &"developer"
const ORDERED_KINDS := [LIVE_KIND, MAP_KIND, FULL_KIND, DEVELOPER_KIND]

@export_range(0.01, 10.0, 0.01) var live_interval_seconds := 0.18
@export_range(0.01, 10.0, 0.01) var map_interval_seconds := 0.16
@export_range(0.01, 30.0, 0.01) var full_interval_seconds := 1.80
@export_range(0.01, 30.0, 0.01) var developer_interval_seconds := 1.80

var _remaining_by_kind: Dictionary = {
	LIVE_KIND: 0.0,
	MAP_KIND: 0.0,
	FULL_KIND: 0.0,
	DEVELOPER_KIND: 0.0,
}
var _advance_count := 0
var _revision := 0


func configure_intervals(live_seconds: float, map_seconds: float, full_seconds: float, developer_seconds: float = -1.0) -> void:
	live_interval_seconds = maxf(0.01, live_seconds)
	map_interval_seconds = maxf(0.01, map_seconds)
	full_interval_seconds = maxf(0.01, full_seconds)
	developer_interval_seconds = maxf(0.01, full_interval_seconds if developer_seconds < 0.0 else developer_seconds)
	reset_table_cadence()
	_remaining_by_kind[DEVELOPER_KIND] = developer_interval_seconds
	_revision += 1


func reset_table_cadence() -> Dictionary:
	_remaining_by_kind[LIVE_KIND] = live_interval_seconds
	_remaining_by_kind[MAP_KIND] = map_interval_seconds
	_remaining_by_kind[FULL_KIND] = full_interval_seconds
	_revision += 1
	return debug_snapshot()


func request_immediate(kind: StringName) -> Dictionary:
	if not ORDERED_KINDS.has(kind):
		return {"accepted": false, "reason": "unknown_refresh_kind"}
	_remaining_by_kind[kind] = 0.0
	_revision += 1
	return {"accepted": true, "kind": kind, "revision": _revision}


func advance(real_delta: float, developer_surface_visible: bool = false) -> Dictionary:
	var step := maxf(0.0, real_delta)
	var due: Array[StringName] = []
	for kind in [LIVE_KIND, MAP_KIND, FULL_KIND]:
		_remaining_by_kind[kind] = float(_remaining_by_kind.get(kind, 0.0)) - step
		if float(_remaining_by_kind[kind]) <= 0.0:
			due.append(kind)
			_remaining_by_kind[kind] = _interval_for(kind)
	if developer_surface_visible:
		_remaining_by_kind[DEVELOPER_KIND] = float(_remaining_by_kind.get(DEVELOPER_KIND, 0.0)) - step
		if float(_remaining_by_kind[DEVELOPER_KIND]) <= 0.0:
			due.append(DEVELOPER_KIND)
			_remaining_by_kind[DEVELOPER_KIND] = developer_interval_seconds
	_advance_count += 1
	_revision += 1
	return {
		"advanced": true,
		"real_delta": step,
		"due": due,
		"advance_count": _advance_count,
		"revision": _revision,
	}


func debug_snapshot() -> Dictionary:
	return {
		"tick_owner": false,
		"gameplay_authority": false,
		"owns_save_schema": false,
		"intervals": {
			LIVE_KIND: live_interval_seconds,
			MAP_KIND: map_interval_seconds,
			FULL_KIND: full_interval_seconds,
			DEVELOPER_KIND: developer_interval_seconds,
		},
		"remaining": _remaining_by_kind.duplicate(true),
		"advance_count": _advance_count,
		"revision": _revision,
	}


func _interval_for(kind: StringName) -> float:
	match kind:
		LIVE_KIND:
			return live_interval_seconds
		MAP_KIND:
			return map_interval_seconds
		FULL_KIND:
			return full_interval_seconds
		DEVELOPER_KIND:
			return developer_interval_seconds
	return full_interval_seconds
