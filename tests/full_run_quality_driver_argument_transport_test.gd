extends SceneTree

const DriverScript := preload("res://scripts/tools/full_run_quality_driver.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var canonical := DriverScript.parse_command_line_options(
		_args(["--preflight-only", "--seed-index", "2", "--observation-seconds=45", "--max-wall-seconds", "55"]),
		_args(["--script", "res://scripts/tools/full_run_quality_driver.gd"])
	)
	_expect(
		bool(canonical.get("valid", false))
			and bool(canonical.get("preflight_only", false))
			and int(canonical.get("seed_index", -1)) == 2
			and int(canonical.get("observation_seconds", -1)) == 45
			and int(canonical.get("max_wall_seconds", -1)) == 55,
		"arguments after the Godot delimiter are authoritative and preserve split and equals forms"
	)

	var defaults := DriverScript.parse_command_line_options(
		PackedStringArray(),
		_args(["--script", "res://scripts/tools/full_run_quality_driver.gd"])
	)
	_expect(
		bool(defaults.get("valid", false))
			and int(defaults.get("seed_index", -1)) == 0
			and int(defaults.get("observation_seconds", -1)) == DriverScript.DEFAULT_OBSERVATION_SECONDS
			and int(defaults.get("max_wall_seconds", -1)) == DriverScript.DEFAULT_MAX_WALL_SECONDS,
		"engine arguments unrelated to this driver leave the closed defaults intact"
	)

	var legacy := DriverScript.parse_command_line_options(
		PackedStringArray(),
		_args(["--script", "res://scripts/tools/full_run_quality_driver.gd", "--seed-index=3", "--observation-seconds", "40", "--max-wall-seconds=50"])
	)
	_expect(
		bool(legacy.get("valid", false))
			and int(legacy.get("seed_index", -1)) == 3
			and int(legacy.get("observation_seconds", -1)) == 40
			and int(legacy.get("max_wall_seconds", -1)) == 50,
		"the empty-user-argument compatibility path accepts only exact recognized engine-side options"
	)

	_expect(
		not _valid(["--unknown-option"], []),
		"an unknown canonical user argument fails closed"
	)
	_expect(
		not _valid(["--preflight-only", "--preflight-only"], []),
		"a duplicate flag fails closed"
	)
	_expect(
		not _valid(["--seed-index=1", "--seed-index", "1"], []),
		"the same value supplied through duplicate forms fails closed"
	)
	_expect(
		not _valid(["--seed-index=1", "--seed-index=2"], []),
		"conflicting values for one option fail closed"
	)
	_expect(
		not _valid(["--observation-seconds", "45", "--max-wall-seconds", "55"], ["--seed-index", "0"]),
		"canonical and legacy driver transports cannot be combined"
	)
	_expect(
		not _valid([], ["--script", "res://scripts/tools/full_run_quality_driver.gd", "--seed-index:2"]),
		"a malformed reserved option on the legacy path fails closed"
	)
	_expect(
		not _valid(["--seed-index"], []),
		"a missing split-form value fails closed"
	)
	_expect(
		not _valid(["--seed-index=20"], []),
		"an out-of-range seed index fails closed"
	)
	_expect(
		not _valid(["--observation-seconds=55", "--max-wall-seconds=55"], []),
		"an observation boundary that reaches the wall boundary fails closed"
	)
	_expect(
		not _valid(["--observation-seconds=150", "--max-wall-seconds=181"], []) \
			and _valid(["--observation-seconds=150", "--max-wall-seconds=180"], []),
		"the repair profile enforces an explicit maximum 180-second wall boundary"
	)
	_finish()


func _valid(user_values: Array, engine_values: Array) -> bool:
	return bool(DriverScript.parse_command_line_options(_args(user_values), _args(engine_values)).get("valid", false))


func _args(values: Array) -> PackedStringArray:
	var result := PackedStringArray()
	for value in values:
		result.append(str(value))
	return result


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("FULL_RUN_QUALITY_DRIVER_ARGUMENT_TRANSPORT|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("FULL_RUN_QUALITY_DRIVER_ARGUMENT_TRANSPORT: %s" % failure)
	print("FULL_RUN_QUALITY_DRIVER_ARGUMENT_TRANSPORT|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)
