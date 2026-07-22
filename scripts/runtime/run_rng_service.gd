@tool
extends Node
class_name RunRngService

signal state_restored(state: int)
signal plan_state_committed(state: int, draw_count_delta: int)

var _rng := RandomNumberGenerator.new()
var _draw_count := 0
var _restore_count := 0

var state: int:
	get:
		return _rng.state
	set(value):
		restore_state(value)

var seed: int:
	get:
		return _rng.seed
	set(value):
		set_seed(value)


func configure(_rules: Dictionary = {}) -> void:
	if _rng.state == 0:
		_rng.seed = 1


func randomize() -> void:
	_rng.randomize()


func set_seed(value: int) -> void:
	_rng.seed = value if value != 0 else 1


func restore_state(value: int) -> void:
	_rng.state = value if value != 0 else 1
	_restore_count += 1
	state_restored.emit(_rng.state)


func randi() -> int:
	_draw_count += 1
	return _rng.randi()


func randi_range(from: int, to: int) -> int:
	_draw_count += 1
	return _rng.randi_range(from, to)


func randf() -> float:
	_draw_count += 1
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	_draw_count += 1
	return _rng.randf_range(from, to)


static func deterministic_weighted_shuffle(rows: Array, rng_state: int) -> Dictionary:
	var derived_rng := RandomNumberGenerator.new()
	derived_rng.state = maxi(1, rng_state)
	var weighted_rows: Array[Dictionary] = []
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		var item_id := str(row.get("item_id", ""))
		if item_id.is_empty():
			continue
		var weight := maxi(1, int(row.get("weight", 1)))
		var uniform := clampf(derived_rng.randf(), 0.000001, 0.999999)
		weighted_rows.append({
			"item_id": item_id,
			"weighted_key": pow(uniform, 1.0 / float(weight)),
		})
	weighted_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_key := float(left.get("weighted_key", 0.0))
		var right_key := float(right.get("weighted_key", 0.0))
		if not is_equal_approx(left_key, right_key):
			return left_key > right_key
		return str(left.get("item_id", "")) < str(right.get("item_id", ""))
	)
	var ordered_items: Array[String] = []
	for row in weighted_rows:
		ordered_items.append(str(row.get("item_id", "")))
	return {
		"items": ordered_items,
		"rng_state": derived_rng.state,
	}


func capture_plan_checkpoint() -> Dictionary:
	return {"schema_version": 1, "rng_state": _rng.state, "draw_count": _draw_count}


static func detached_randi_range(cursor: Dictionary, from: int, to: int) -> Dictionary:
	if int(cursor.get("schema_version", 0)) != 1 or int(cursor.get("rng_state", 0)) == 0 or from > to:
		return {"ok": false, "reason_code": "rng_cursor_invalid"}
	var detached := RandomNumberGenerator.new()
	detached.state = int(cursor.get("rng_state", 1))
	var value := detached.randi_range(from, to)
	return {"ok": true, "value": value, "rng_state": detached.state, "draw_count": int(cursor.get("draw_count", 0)) + 1}


static func detached_randf_range(cursor: Dictionary, from: float, to: float) -> Dictionary:
	if int(cursor.get("schema_version", 0)) != 1 or int(cursor.get("rng_state", 0)) == 0 or from > to:
		return {"ok": false, "reason_code": "rng_cursor_invalid"}
	var detached := RandomNumberGenerator.new()
	detached.state = int(cursor.get("rng_state", 1))
	var value := detached.randf_range(from, to)
	return {"ok": true, "value": value, "rng_state": detached.state, "draw_count": int(cursor.get("draw_count", 0)) + 1}


func preflight_plan_commit(expected_checkpoint: Dictionary, terminal_cursor: Dictionary) -> Dictionary:
	if int(expected_checkpoint.get("schema_version", 0)) != 1 or int(terminal_cursor.get("schema_version", 0)) != 1:
		return {"accepted": false, "reason_code": "rng_plan_schema_invalid"}
	if int(expected_checkpoint.get("rng_state", 0)) != _rng.state or int(expected_checkpoint.get("draw_count", -1)) != _draw_count:
		return {"accepted": false, "reason_code": "session_start_rng_state_stale"}
	if int(terminal_cursor.get("rng_state", 0)) == 0 or int(terminal_cursor.get("draw_count", -1)) < _draw_count:
		return {"accepted": false, "reason_code": "rng_terminal_cursor_invalid"}
	return {"accepted": true, "reason_code": "rng_plan_commit_valid"}


func commit_plan_state(expected_checkpoint: Dictionary, terminal_cursor: Dictionary) -> Dictionary:
	return _commit_plan_state(expected_checkpoint, terminal_cursor, true)


## Commits a detached plan without publishing an irreversible observer signal.
## A caller may use this only inside a synchronous reversible transaction and
## must either restore the captured checkpoint or finish the transaction before
## yielding control.
func commit_reversible_plan_state(expected_checkpoint: Dictionary, terminal_cursor: Dictionary) -> Dictionary:
	return _commit_plan_state(expected_checkpoint, terminal_cursor, false)


func _commit_plan_state(expected_checkpoint: Dictionary, terminal_cursor: Dictionary, publish_signal: bool) -> Dictionary:
	var preflight := preflight_plan_commit(expected_checkpoint, terminal_cursor)
	if not bool(preflight.get("accepted", false)):
		return {"committed": false, "reason_code": str(preflight.get("reason_code", "rng_plan_commit_invalid"))}
	var delta := int(terminal_cursor.get("draw_count", _draw_count)) - _draw_count
	_rng.state = int(terminal_cursor.get("rng_state", _rng.state))
	_draw_count += delta
	if publish_signal:
		plan_state_committed.emit(_rng.state, delta)
	return {
		"committed": true,
		"reason_code": "rng_plan_state_committed" if publish_signal else "rng_reversible_plan_state_committed",
		"rng_state": _rng.state,
		"draw_count_delta": delta,
		"observer_signal_published": publish_signal,
	}


func restore_plan_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if int(checkpoint.get("schema_version", 0)) != 1 or int(checkpoint.get("rng_state", 0)) == 0 or int(checkpoint.get("draw_count", -1)) < 0:
		return {"restored": false, "reason_code": "rng_plan_checkpoint_invalid"}
	_rng.state = int(checkpoint.get("rng_state", 1))
	_draw_count = int(checkpoint.get("draw_count", 0))
	return {"restored": true, "reason_code": "rng_plan_checkpoint_restored"}


func to_save_data() -> Dictionary:
	return {
		"schema_version": 1,
		"rng_state": _rng.state,
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var schema_version := int(data.get("schema_version", -1))
	var restored_state := int(data.get("rng_state", 0))
	if schema_version != 1 or restored_state == 0:
		return {
			"applied": false,
			"reason_code": "run_rng_save_invalid",
		}
	restore_state(restored_state)
	return {
		"applied": true,
		"reason_code": "run_rng_state_restored",
		"rng_state": _rng.state,
	}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _rng.state > 0,
		"schema_version": 1,
		"rng_state": _rng.state,
		"draw_count": _draw_count,
		"restore_count": _restore_count,
		"owns_rng_state": true,
	}
