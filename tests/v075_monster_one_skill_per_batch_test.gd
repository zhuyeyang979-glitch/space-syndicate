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
	var state := Fixture.state(2)
	var first := Core.submit_request(
		state,
		Fixture.request(state, "request.pending.001"),
		Fixture.asset_view()
	)
	state = first.get("state") as Dictionary
	var while_pending := Core.submit_request(
		state,
		Fixture.request(
			state,
			"request.pending.002",
			"skill.owner.2",
			"enemy_monster",
			"monster.target.001"
		),
		Fixture.asset_view()
	)
	_expect(
		not bool(while_pending.get("accepted", true))
		and while_pending.get("reason_code")
		== "source_batch_skill_request_pending"
		and (while_pending.get(
			"asset_reservation_request"
		) as Dictionary).is_empty(),
		"pending reservation blocks second source request"
	)
	var rejected_receipt := Core.build_asset_reservation_receipt(
		first.get("asset_reservation_request") as Dictionary,
		false,
		"asset_reservation_conflict",
		2
	)
	var rejected := Core.apply_asset_reservation_receipt(
		state,
		rejected_receipt
	)
	state = rejected.get("state") as Dictionary
	_expect(
		not bool(rejected.get("accepted", true))
		and int(((state.get("sources") as Dictionary).get(
			"monster.owner.001"
		) as Dictionary).get("batch_active_skill_use_count", -1)) == 0,
		"rejected asset reservation consumes no batch use"
	)
	var accepted := Fixture.accept(
		state,
		Fixture.request(state, "request.accepted.001")
	)
	state = accepted.get("state") as Dictionary
	var fizzled := Fixture.resolve(
		state,
		false,
		"target_invalid_at_boundary"
	)
	state = fizzled.get("state") as Dictionary
	var after_fizzle := Core.submit_request(
		state,
		Fixture.request(
			state,
			"request.after.fizzle",
			"skill.owner.2",
			"enemy_monster",
			"monster.target.001"
		),
		Fixture.asset_view()
	)
	_expect(
		not bool(after_fizzle.get("accepted", true))
		and after_fizzle.get("reason_code")
		== "source_batch_skill_use_exhausted",
		"accepted fizzle exhausts one use for current batch"
	)
	var advanced := Core.advance_batch(state, "batch.test.002")
	state = advanced.get("state") as Dictionary
	var next_batch := Core.submit_request(
		state,
		Fixture.request(
			state,
			"request.next.batch",
			"skill.owner.2",
			"enemy_monster",
			"monster.target.001"
		),
		Fixture.asset_view()
	)
	_expect(
		bool(next_batch.get("accepted", false)),
		"next batch restores one source skill use"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("V075_MONSTER_ONE_SKILL_PER_BATCH_TEST|%s|%d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
	])
	quit(0 if _failures.is_empty() else 1)
