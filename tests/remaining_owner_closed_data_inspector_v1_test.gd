extends SceneTree

const INSPECTOR := preload("res://scripts/tools/remaining_owner_closed_data_inspector_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var closed := INSPECTOR.inspect({"schema_version": 1, "rows": [{"id": "safe", "active": true}]})
	_expect(bool(closed.get("closed_data", false)), "closed payload passes")
	_expect(int(closed.get("non_closed_leaf_count", -1)) == 0, "closed payload has zero violations")

	var timers := INSPECTOR.inspect({"monster_timer": 0.0, "special_monster_timer": 29.999})
	_expect(not bool(timers.get("closed_data", true)), "raw timers fail strict closed data")
	_expect(int(timers.get("non_closed_leaf_count", 0)) == 2, "both raw timers are enumerated")
	_expect((timers.get("non_closed_type_counts", {}) as Dictionary) == {"float": 2}, "timer type count is exact")
	_expect(str(timers.get("first_non_closed_type", "")) == "float", "first timer type is float")
	_expect(str(timers.get("first_non_closed_reason", "")) == "raw_float_timer_not_closed_data", "timer reason is typed")
	_expect((timers.get("all_non_closed_paths", []) as Array).has("$.monster_timer"), "public timer path is retained")

	var private_key := "private.actor.secret"
	var private_report := INSPECTOR.inspect({private_key: Callable(self, "_init")})
	var private_path := str(private_report.get("first_non_closed_path", ""))
	_expect(not private_path.contains(private_key), "dynamic private key is redacted")
	_expect(private_path.contains("<redacted:"), "redacted path carries only a fingerprint")

	var integer_key := INSPECTOR.inspect({7: "value"})
	_expect(int(integer_key.get("non_closed_leaf_count", 0)) == 1, "non-string dictionary key is enumerated")
	_expect(str(integer_key.get("first_non_closed_reason", "")) == "dictionary_key_not_string", "dictionary key reason is typed")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("REMAINING_OWNER_CLOSED_DATA_INSPECTOR_V1_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Remaining Owner inspector failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
