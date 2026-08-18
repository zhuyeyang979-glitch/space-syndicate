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
	var asset_view := Fixture.asset_view(6)
	var before_assets := asset_view.duplicate(true)
	var accepted := Fixture.accept(
		state,
		Fixture.request(state, "request.fizzle.001")
	)
	state = accepted.get("state") as Dictionary
	var fizzled := Fixture.resolve(
		state,
		false,
		"target_invalid_at_boundary"
	)
	state = fizzled.get("state") as Dictionary
	var settlement := fizzled.get("asset_settlement_intent") as Dictionary
	_expect(
		not bool(fizzled.get("committed", true))
		and settlement.get("action") == "release"
		and bool(settlement.get("full_reservation_release", false)),
		"accepted fizzle releases full reservation"
	)
	var skill := Fixture.skill_state(state)
	_expect(
		skill.get("status") == "READY"
		and int(skill.get("cooldown_remaining_batches", -1)) == 0,
		"fizzle starts no cooldown"
	)
	var source := (state.get("sources") as Dictionary).get(
		"monster.owner.001"
	) as Dictionary
	_expect(
		int(source.get("batch_active_skill_use_count", -1)) == 1,
		"accepted fizzle consumes batch use"
	)
	_expect(asset_view == before_assets, "fizzle never mutates asset view")
	var public_result := (Core.public_projection(state).get(
		"public_results"
	) as Array)[0] as Dictionary
	_expect(
		public_result.get("outcome") == "fizzled"
		and public_result.get("public_effect_id") == "",
		"public sees fizzle result without skill identity"
	)
	var before_replay := state.duplicate(true)
	var replay := Core.resolve_current(
		state,
		fizzled.get("effect_receipt") as Dictionary
	)
	_expect(
		bool(replay.get("replayed", false))
		and replay.get("state") == before_replay
		and (replay.get("asset_settlement_intent") as Dictionary).is_empty(),
		"fizzle receipt replay emits no second release"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("V075_MONSTER_PRIVATE_SKILL_FIZZLE_TEST|%s|%d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
	])
	quit(0 if _failures.is_empty() else 1)
