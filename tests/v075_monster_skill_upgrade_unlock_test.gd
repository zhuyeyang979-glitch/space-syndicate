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
	var accepted := Fixture.accept(
		state,
		Fixture.request(state, "request.upgrade.cooldown")
	)
	var resolved := Fixture.resolve(
		accepted.get("state") as Dictionary,
		true,
		"resolved"
	)
	state = resolved.get("state") as Dictionary
	var cooldown_before := int(Fixture.skill_state(state).get(
		"cooldown_remaining_batches",
		-1
	))
	var upgraded := Core.upgrade_source_skills(
		state,
		"monster.owner.001",
		1,
		4,
		Fixture.skill_ids()
	)
	state = upgraded.get("state") as Dictionary
	_expect(
		bool(upgraded.get("accepted", false))
		and int(upgraded.get("existing_cooldown_reset_count", -1)) == 0
		and int(Fixture.skill_state(state).get(
			"cooldown_remaining_batches",
			-1
		)) == cooldown_before,
		"upgrade preserves existing cooldown exactly"
	)
	_expect(
		(upgraded.get("newly_ready_skill_definition_ids") as Array)
		== ["skill.owner.2", "skill.owner.3", "skill.owner.4"],
		"rank four unlocks exactly three new skills"
	)
	for skill_id in ["skill.owner.2", "skill.owner.3", "skill.owner.4"]:
		_expect(
			Fixture.skill_state(state, skill_id).get("status") == "READY",
			"%s starts READY" % skill_id
		)
	var owner_projection := Core.owner_private_projection(state, "player.0")
	var cards := ((owner_projection.get("sources") as Array)[0] as Dictionary).get(
		"skill_cards"
	) as Array
	var ultimate_count := 0
	for card_variant in cards:
		if bool((card_variant as Dictionary).get("ultimate", false)):
			ultimate_count += 1
	_expect(
		cards.size() == 4 and ultimate_count == 1,
		"L4 owner projection contains four skills and one ultimate"
	)
	var withdrawn := Core.set_source_status(
		state,
		"monster.owner.001",
		1,
		"withdrawn"
	)
	state = withdrawn.get("state") as Dictionary
	_expect(
		(Core.owner_private_projection(
			state,
			"player.0"
		).get("sources") as Array).is_empty(),
		"withdrawn source removes revoked skill dock"
	)
	for skill_id in Fixture.skill_ids():
		_expect(
			Fixture.skill_state(state, skill_id).get("status") == "REVOKED",
			"%s is revoked on withdrawal" % skill_id
		)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("V075_MONSTER_SKILL_UPGRADE_UNLOCK_TEST|%s|%d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
	])
	quit(0 if _failures.is_empty() else 1)
