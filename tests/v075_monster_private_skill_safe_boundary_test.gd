extends SceneTree

const Core := preload(
	"res://scripts/v075/monster/v075_monster_private_skill_core.gd"
)
const Bench := preload(
	"res://scripts/tools/v075/v075_monster_private_skill_bench.gd"
)
const Fixture := Bench.TestFixture

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := Fixture.state()
	var started := Core.begin_atomic_receipt(state, "public.receipt.001")
	state = started.get("state") as Dictionary
	_expect(bool(started.get("accepted", false)), "public Receipt starts")
	_expect(
		Core.begin_atomic_receipt(
			state,
			"public.receipt.reentry"
		).get("reason_code") == "atomic_transaction_reentry_forbidden",
		"atomic reentry is rejected"
	)
	var request := Fixture.request(state, "request.boundary.001")
	var accepted := Fixture.accept(state, request)
	state = accepted.get("state") as Dictionary
	_expect(
		bool(accepted.get("accepted", false))
		and not bool(accepted.get("execution_due", true)),
		"accepted request waits while Receipt is inflight"
	)
	_expect(
		Core.take_next_ready_request(
			state
		).get("reason_code") == "atomic_transaction_inflight",
		"skill cannot interrupt current atomic action"
	)
	var completed := Core.complete_atomic_receipt(state, "public.receipt.001")
	state = completed.get("state") as Dictionary
	_expect(
		bool(completed.get("execution_due", false))
		and int(completed.get("safe_boundary_sequence", -1)) == 1,
		"skill becomes due at first post-Receipt boundary"
	)
	_expect(
		Core.begin_atomic_receipt(
			state,
			"public.receipt.002"
		).get("reason_code") == "private_safe_boundary_required",
		"next public Receipt cannot skip due private skill"
	)
	var taken := Core.take_next_ready_request(state)
	state = taken.get("state") as Dictionary
	_expect(
		bool(taken.get("accepted", false)),
		"due request enters resolving at safe boundary"
	)
	_expect(
		Core.take_next_ready_request(
			state
		).get("reason_code") == "private_skill_resolution_inflight",
		"private resolution cannot reenter itself"
	)
	var effect := Core.build_effect_receipt(
		taken.get("execution_intent") as Dictionary,
		true,
		"resolved",
		{"target_kind": "enemy_facility", "target_id": "facility.target.001"},
		{"effect_summary_key": "monster.skill.test", "damage_amount": 1}
	)
	var resolved := Core.resolve_current(state, effect)
	state = resolved.get("state") as Dictionary
	_expect(bool(resolved.get("committed", false)), "safe-boundary skill resolves")
	_expect(
		bool(Core.begin_atomic_receipt(
			state,
			"public.receipt.002"
		).get("accepted", false)),
		"public flow resumes after private Receipt"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("V075_MONSTER_PRIVATE_SKILL_SAFE_BOUNDARY_TEST|%s|%d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
	])
	quit(0 if _failures.is_empty() else 1)
