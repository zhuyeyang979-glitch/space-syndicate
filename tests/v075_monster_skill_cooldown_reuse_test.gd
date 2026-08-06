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
	var first_accept := Fixture.accept(
		state,
		Fixture.request(state, "request.cooldown.first")
	)
	var first_resolve := Fixture.resolve(
		first_accept.get("state") as Dictionary,
		true,
		"resolved"
	)
	state = first_resolve.get("state") as Dictionary
	_expect(
		Fixture.skill_state(state).get("status") == "COOLDOWN"
		and int(Fixture.skill_state(state).get(
			"cooldown_remaining_batches",
			-1
		)) == 2,
		"successful skill starts two-batch cooldown"
	)
	var batch_two := Core.advance_batch(state, "batch.test.002")
	state = batch_two.get("state") as Dictionary
	_expect(
		Fixture.skill_state(state).get("status") == "COOLDOWN"
		and int(Fixture.skill_state(state).get(
			"cooldown_remaining_batches",
			-1
		)) == 1,
		"first batch boundary decrements cooldown"
	)
	var too_soon := Core.submit_request(
		state,
		Fixture.request(state, "request.cooldown.too.soon"),
		Fixture.asset_view()
	)
	_expect(
		not bool(too_soon.get("accepted", true))
		and too_soon.get("reason_code") == "skill_not_ready",
		"cooling skill cannot be requested"
	)
	state = too_soon.get("state") as Dictionary
	var batch_three := Core.advance_batch(state, "batch.test.003")
	state = batch_three.get("state") as Dictionary
	_expect(
		int(batch_three.get("cooldown_recovered_count", 0)) == 1
		and Fixture.skill_state(state).get("status") == "READY",
		"second boundary restores READY"
	)
	var reuse_accept := Fixture.accept(
		state,
		Fixture.request(state, "request.cooldown.reuse"),
		6,
		4
	)
	var reuse_resolve := Fixture.resolve(
		reuse_accept.get("state") as Dictionary,
		true,
		"resolved"
	)
	state = reuse_resolve.get("state") as Dictionary
	_expect(
		bool(reuse_resolve.get("committed", false))
		and (Core.public_projection(state).get(
			"public_results"
		) as Array).size() == 2,
		"same skill resolves again after cooldown"
	)
	var downed := Core.set_source_status(
		state,
		"monster.owner.001",
		1,
		"downed"
	)
	state = downed.get("state") as Dictionary
	_expect(
		Fixture.skill_state(state).get("status") == "DISABLED"
		and int(Fixture.skill_state(state).get(
			"cooldown_remaining_batches",
			-1
		)) == 2,
		"downed status preserves cooldown counter"
	)
	var recovered := Core.set_source_status(
		state,
		"monster.owner.001",
		1,
		"active"
	)
	state = recovered.get("state") as Dictionary
	_expect(
		Fixture.skill_state(state).get("status") == "COOLDOWN"
		and int(Fixture.skill_state(state).get(
			"cooldown_remaining_batches",
			-1
		)) == 2,
		"source recovery resumes preserved cooldown"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("V075_MONSTER_SKILL_COOLDOWN_REUSE_TEST|%s|%d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
	])
	quit(0 if _failures.is_empty() else 1)
