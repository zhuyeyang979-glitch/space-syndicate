extends SceneTree

const Simulator := preload(
	"res://scripts/v075_simulation/v075_combat_deterministic_simulator.gd"
)

const DEFAULT_CONFIGURATION_INDEX := 0
const DEFAULT_MATCH_INDEX := 0
const DEFAULT_STEP_LIMIT := 128
const COMBAT_ACTION_KEYS := [
	"MONSTER_DEPLOY_COUNT",
	"MONSTER_REFRESH_COUNT",
	"MONSTER_UPGRADE_COUNT",
	"MONSTER_REPLACE_COUNT",
	"MONSTER_PRIVATE_SKILL_USE_COUNT",
	"MONSTER_TRAMPLE_REGION_RECEIPT_COUNT",
	"MILITARY_REGION_ASSAULT_COUNT",
	"MILITARY_MONSTER_ASSAULT_COUNT",
	"FACILITY_COMBAT_DAMAGE_COUNT",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var simulator := Simulator.new()
	var configuration_index := _argument_int(
		"--configuration-index",
		DEFAULT_CONFIGURATION_INDEX
	)
	var configurations := simulator.configurations()
	if (
		configuration_index < 0
		or configuration_index >= configurations.size()
	):
		_fail(
			"configuration index %d is outside the production matrix"
			% configuration_index
		)
		_finish({}, configuration_index, 0)
		return

	var configuration := (
		configurations[configuration_index] as Dictionary
	).duplicate(true)
	var match_index := _argument_int("--match-index", DEFAULT_MATCH_INDEX)
	var default_seed := int(simulator.seed_for(configuration_index, match_index))
	var match_seed := _argument_int("--match-seed", default_seed)
	var step_limit := _argument_int("--step-limit", DEFAULT_STEP_LIMIT)
	if step_limit < 1:
		_fail("step limit must be positive")
		_finish({}, configuration_index, match_seed)
		return

	# One call is intentional: this gate must observe the real production path.
	var row: Dictionary = simulator.run_match(
		configuration,
		match_seed,
		step_limit,
		configuration_index,
		match_index
	)
	_test_natural_match(row)
	_finish(row, configuration_index, match_seed)


func _test_natural_match(row: Dictionary) -> void:
	_expect(
		bool((row.get("start_receipt", {}) as Dictionary).get("accepted", false)),
		"natural match start was accepted"
	)
	var completion := row.get("completion", {}) as Dictionary
	_expect(
		bool(completion.get("accepted", false))
			and str(completion.get("phase", "")) == "settled"
			and str(completion.get("reason_code", ""))
			== "sample_match_completed",
		"natural production match reaches settled FinalSettlement"
	)
	_expect(
		int(row.get("steps", 0)) > 0,
		"natural production match advances at least one runtime step"
	)

	var metrics := row.get("metrics", {}) as Dictionary
	_expect(
		int(metrics.get("COMBAT_SIMULATION_MATCH_COUNT", -1)) == 1
			and int(metrics.get("COMBAT_SIMULATION_SETTLED_COUNT", -1)) == 1
			and int(metrics.get("COMBAT_SIMULATION_DEADLOCK_COUNT", -1)) == 0,
		"bounded gate executes exactly one settled match without deadlock"
	)
	_expect(
		int(metrics.get("FINAL_SETTLEMENT_COUNT", -1)) == 1
			and int(metrics.get("DUPLICATE_SETTLEMENT_COUNT", -1)) == 0
			and not str((row.get("identity", {}) as Dictionary).get(
				"settlement_id",
				""
			)).is_empty(),
		"FinalSettlement is committed exactly once"
	)
	_expect(
		int(metrics.get("COMBAT_RUNTIME_ERROR_COUNT", -1)) == 0,
		"natural production match has zero runtime errors"
	)
	_expect(
		int(metrics.get("COMBAT_DUPLICATE_EFFECT_COUNT", -1)) == 0,
		"natural production match has no duplicate combat effects"
	)
	_expect(
		int(metrics.get("COMBAT_HIDDEN_INFO_VIOLATION_COUNT", -1)) == 0,
		"natural production match has no hidden-information violations"
	)
	_expect(
		int(metrics.get("COMBAT_INVALID_TARGET_COUNT", -1)) == 0
			and int(metrics.get("COMBAT_NONFINITE_COUNT", -1)) == 0,
		"natural production match has valid finite combat state"
	)
	_expect(
		_combat_action_count(metrics) > 0,
		"natural production match produces at least one combat action"
	)

	var performance := row.get("simulation_performance", {}) as Dictionary
	var acceleration := completion.get(
		"simulation_acceleration",
		{}
	) as Dictionary
	_expect(
		int(performance.get("direct_state_injection_count", -1)) == 0
			and int(acceleration.get("direct_state_injection_count", -1)) == 0,
		"natural match uses no direct card, asset, target, damage, or victory injection"
	)


func _combat_action_count(metrics: Dictionary) -> int:
	var result := 0
	for key_variant in COMBAT_ACTION_KEYS:
		result += int(metrics.get(str(key_variant), 0))
	return result


func _argument_int(prefix: String, fallback: int) -> int:
	for argument_variant in OS.get_cmdline_user_args():
		var argument := str(argument_variant)
		if not argument.begins_with(prefix + "="):
			continue
		var value := argument.trim_prefix(prefix + "=")
		if value.is_valid_int():
			return int(value)
	return fallback


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("V075_NATURAL_RUNTIME_ERROR_ZERO_TEST|FAIL|%s" % message)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_fail(message)


func _finish(row: Dictionary, configuration_index: int, match_seed: int) -> void:
	var metrics := row.get("metrics", {}) as Dictionary
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"V075_NATURAL_RUNTIME_ERROR_ZERO_TEST|status=%s|checks=%d|failures=%d|configuration_index=%d|seed=%d|settled=%d|final_settlement=%d|runtime_errors=%d|duplicate_effects=%d|hidden_info=%d|combat_actions=%d"
		% [
			status,
			_checks,
			_failures.size(),
			configuration_index,
			match_seed,
			int(metrics.get("COMBAT_SIMULATION_SETTLED_COUNT", 0)),
			int(metrics.get("FINAL_SETTLEMENT_COUNT", 0)),
			int(metrics.get("COMBAT_RUNTIME_ERROR_COUNT", 0)),
			int(metrics.get("COMBAT_DUPLICATE_EFFECT_COUNT", 0)),
			int(metrics.get("COMBAT_HIDDEN_INFO_VIOLATION_COUNT", 0)),
			_combat_action_count(metrics),
		]
	)
	if not _failures.is_empty():
		print(
			"V075_NATURAL_RUNTIME_ERROR_ZERO_TEST_FAILURES|%s"
			% JSON.stringify(_failures)
		)
	quit(0 if _failures.is_empty() else 1)
