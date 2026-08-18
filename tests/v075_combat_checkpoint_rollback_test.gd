extends SceneTree

const Core := preload(
	"res://scripts/v075/monster/v075_monster_private_skill_core.gd"
)
const Checkpoint := preload(
	"res://scripts/v075/combat/v075_combat_checkpoint_v1.gd"
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
	var initial := Fixture.state()
	var accepted := Fixture.accept(
		initial,
		Fixture.request(initial, "request.checkpoint.001")
	)
	var pending_state := accepted.get("state") as Dictionary
	var pending_before := pending_state.duplicate(true)
	var checkpoint := Checkpoint.capture_monster_skill(
		"checkpoint.monster.skill.001",
		pending_state
	)
	var checkpoint_before := checkpoint.duplicate(true)
	_expect(
		bool(Checkpoint.validation_report(checkpoint).get("valid", false))
		and Checkpoint.is_pure_data(checkpoint),
		"checkpoint is valid pure detached data"
	)
	_expect(
		pending_state == pending_before and checkpoint == checkpoint_before,
		"capture mutates neither authority state nor checkpoint"
	)
	var taken := Core.take_next_ready_request(pending_state)
	var execution_id := str((taken.get(
		"execution_intent"
	) as Dictionary).get("execution_id", ""))
	var resolved := Fixture.resolve(pending_state, false, "target_invalid_at_boundary")
	var changed_state := resolved.get("state") as Dictionary
	var rollback := Checkpoint.rollback(changed_state, checkpoint)
	var restored := rollback.get("state") as Dictionary
	_expect(
		bool(rollback.get("rolled_back", false))
		and restored == pending_state,
		"rollback restores pending queue, reservation, and ledgers exactly"
	)
	var retaken := Core.take_next_ready_request(restored)
	_expect(
		str((retaken.get("execution_intent") as Dictionary).get(
			"execution_id",
			""
		)) == execution_id,
		"rollback deterministically replays same execution identity"
	)
	var replayed := Checkpoint.rollback(pending_state, checkpoint)
	_expect(
		bool(replayed.get("rolled_back", false))
		and bool(replayed.get("replayed", false))
		and replayed.get("state") == pending_state,
		"restored checkpoint replay is exact-once and stable"
	)
	var from_future := Checkpoint.rollback(initial, checkpoint)
	_expect(
		not bool(from_future.get("rolled_back", true))
		and from_future.get("reason_code") == "checkpoint_from_future",
		"future checkpoint cannot roll back an earlier revision"
	)
	var other_state := Core.create_state(
		"batch.other.001",
		[
			Core.build_source_snapshot(
				"monster.other.001",
				1,
				"player.0",
				1,
				"active",
				Fixture.skill_ids(),
				["skill.owner.1"]
			),
		],
		Fixture.definitions()
	)
	var wrong_lineage := Checkpoint.rollback(other_state, checkpoint)
	_expect(
		not bool(wrong_lineage.get("rolled_back", true))
		and wrong_lineage.get("reason_code") == "checkpoint_lineage_invalid",
		"checkpoint cannot cross combat lineage"
	)
	_expect(
		int(Checkpoint.contract_snapshot().get(
			"production_save_write_count",
			-1
		)) == 0
		and not bool(Checkpoint.contract_snapshot().get(
			"production_save_owner_connected",
			true
		)),
		"detached checkpoint never writes production Save"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("V075_COMBAT_CHECKPOINT_ROLLBACK_TEST|%s|%d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
	])
	quit(0 if _failures.is_empty() else 1)
