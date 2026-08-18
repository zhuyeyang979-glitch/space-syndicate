extends Node

const Core := preload(
	"res://scripts/v075/monster/v075_monster_private_skill_core.gd"
)
const Checkpoint := preload(
	"res://scripts/v075/combat/v075_combat_checkpoint_v1.gd"
)



class TestFixture:
	const SkillCore := preload(
		"res://scripts/v075/monster/v075_monster_private_skill_core.gd"
	)

	static func cost(amount: int = 1) -> Dictionary:
		return {
			"life": 0,
			"energy": 0,
			"industry": 0,
			"technology": amount,
			"commerce": 0,
			"shipping": 0,
		}

	static func skill_ids() -> Array:
		return [
			"skill.owner.1",
			"skill.owner.2",
			"skill.owner.3",
			"skill.owner.4",
		]

	static func definitions() -> Array:
		var result: Array = []
		for rank in range(1, 5):
			result.append(SkillCore.build_skill_definition(
				"skill.owner.%d" % rank,
				"effect.monster.%d" % rank,
				rank,
				rank == 4,
				cost(1 if rank < 3 else 2),
				{
					"target_kind": (
						"enemy_monster" if rank == 2 else "enemy_facility"
					),
				},
				{"range_hops": rank + 1},
				2 if rank == 1 else 1,
				"monster.skill.%d" % rank
			))
		return result

	static func state(
		rank: int = 1,
		include_rival: bool = false
	) -> Dictionary:
		var ids := skill_ids()
		var unlocked: Array = []
		for index in range(rank):
			unlocked.append(ids[index])
		var sources: Array = [
			SkillCore.build_source_snapshot(
				"monster.owner.001",
				1,
				"player.0",
				rank,
				"active",
				ids,
				unlocked
			),
		]
		if include_rival:
			sources.append(SkillCore.build_source_snapshot(
				"monster.rival.001",
				1,
				"player.1",
				1,
				"active",
				ids,
				["skill.owner.1"]
			))
		return SkillCore.create_state(
			"batch.test.001",
			sources,
			definitions()
		)

	static func asset_view(
		available: int = 6,
		owner_id: String = "player.0",
		revision: int = 1
	) -> Dictionary:
		return {
			"viewer_id": owner_id,
			"state_revision": revision,
			"own_available_assets": cost(available),
		}

	static func request(
		current_state: Dictionary,
		request_id: String,
		skill_id: String = "skill.owner.1",
		target_kind: String = "enemy_facility",
		target_id: String = "facility.target.001"
	) -> Dictionary:
		return SkillCore.build_request(
			request_id,
			str(current_state.get("batch_id", "")),
			"player.0",
			"monster.owner.001",
			1,
			skill_id,
			{
				"target_kind": target_kind,
				"target_id": target_id,
			}
		)

	static func accept(
		current_state: Dictionary,
		skill_request: Dictionary,
		available: int = 6,
		asset_revision: int = 2
	) -> Dictionary:
		var submitted := SkillCore.submit_request(
			current_state,
			skill_request,
			asset_view(available)
		)
		if not bool(submitted.get("accepted", false)):
			return submitted
		var asset_receipt := SkillCore.build_asset_reservation_receipt(
			submitted.get("asset_reservation_request") as Dictionary,
			true,
			"reservation_committed",
			asset_revision
		)
		var reserved := SkillCore.apply_asset_reservation_receipt(
			submitted.get("state") as Dictionary,
			asset_receipt
		)
		reserved["submitted"] = submitted
		reserved["asset_receipt"] = asset_receipt
		return reserved

	static func resolve(
		current_state: Dictionary,
		committed: bool = true,
		reason_code: String = "resolved"
	) -> Dictionary:
		var taken := SkillCore.take_next_ready_request(current_state)
		if not bool(taken.get("accepted", false)):
			return taken
		var effect_receipt := SkillCore.build_effect_receipt(
			taken.get("execution_intent") as Dictionary,
			committed,
			reason_code,
			{
				"target_kind": "enemy_facility",
				"target_id": "facility.target.001",
				"target_region_id": "region.001",
			},
			{
				"effect_summary_key": "monster.skill.test",
				"damage_amount": 2,
				"combat_receipt_id": "combat.receipt.test",
			}
		)
		var result := SkillCore.resolve_current(
			taken.get("state") as Dictionary,
			effect_receipt
		)
		result["taken"] = taken
		result["effect_receipt"] = effect_receipt
		return result

	static func skill_state(
		current_state: Dictionary,
		skill_id: String = "skill.owner.1"
	) -> Dictionary:
		var source := (current_state.get("sources") as Dictionary).get(
			"monster.owner.001"
		) as Dictionary
		return (source.get("skill_states") as Dictionary).get(
			skill_id
		) as Dictionary


var _checks := 0
var _failures: Array[String] = []
var bench_complete := false
var bench_passed := false
var bench_summary: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var definitions := _definitions()
	var state := Core.create_state(
		"batch.private.001",
		[
			Core.build_source_snapshot(
				"monster.owner.001",
				1,
				"player.0",
				1,
				"active",
				_skill_ids(),
				["skill.owner.1"]
			),
			Core.build_source_snapshot(
				"monster.rival.001",
				1,
				"player.1",
				1,
				"active",
				_skill_ids(),
				["skill.owner.1"]
			),
		],
		definitions
	)
	_check(
		bool(Core.validation_report(state).get("valid", false)),
		"initial state validates"
	)
	_check(
		Core.EXECUTION_MODE == "private_instant_serial",
		"execution mode is private serial"
	)

	var owner_projection := Core.owner_private_projection(state, "player.0")
	var rival_projection := Core.owner_private_projection(state, "player.1")
	var public_projection := Core.public_projection(state)
	_check(
		_projection_source_ids(owner_projection) == ["monster.owner.001"],
		"owner receives only own private source"
	)
	_check(
		_projection_source_ids(rival_projection) == ["monster.rival.001"],
		"rival receives only rival private source"
	)
	_check(
		_private_skill_count(owner_projection) == 1,
		"L1 owner receives one private skill"
	)
	_check(
		bool(Core.public_projection_privacy_report(
			public_projection
		).get("valid", false)),
		"public projection excludes private skill fields"
	)

	var asset_view := _asset_view(2)
	var asset_before := asset_view.duplicate(true)
	var request := Core.build_request(
		"request.immediate.001",
		"batch.private.001",
		"player.0",
		"monster.owner.001",
		1,
		"skill.owner.1",
		{
			"target_kind": "enemy_facility",
			"target_id": "facility.life.001",
		}
	)
	var submitted := Core.submit_request(state, request, asset_view)
	state = submitted.get("state") as Dictionary
	_check(
		bool(submitted.get("accepted", false))
		and not (submitted.get(
			"asset_reservation_request",
			{}
		) as Dictionary).is_empty(),
		"legal request emits typed reservation request"
	)
	_check(asset_view == asset_before, "request does not mutate asset view")
	var reservation_request := submitted.get(
		"asset_reservation_request"
	) as Dictionary
	var reservation_receipt := Core.build_asset_reservation_receipt(
		reservation_request,
		true,
		"reservation_committed",
		8
	)
	var reserved := Core.apply_asset_reservation_receipt(
		state,
		reservation_receipt
	)
	state = reserved.get("state") as Dictionary
	_check(
		bool(reserved.get("execution_due", false))
		and reserved.get("execution_timing") == "immediate",
		"no public transaction executes at immediate safe boundary"
	)
	var taken := Core.take_next_ready_request(state)
	state = taken.get("state") as Dictionary
	var execution := taken.get("execution_intent") as Dictionary
	_check(
		bool(taken.get("accepted", false))
		and not execution.is_empty(),
		"immediate request enters resolving"
	)
	var effect_receipt := Core.build_effect_receipt(
		execution,
		true,
		"resolved",
		{
			"target_kind": "enemy_facility",
			"target_id": "facility.life.001",
			"target_region_id": "region.001",
		},
		{
			"effect_summary_key": "monster.skill.hit",
			"damage_amount": 3,
			"combat_receipt_id": "combat.receipt.001",
		}
	)
	var resolved := Core.resolve_current(state, effect_receipt)
	state = resolved.get("state") as Dictionary
	_check(
		bool(resolved.get("committed", false))
		and (resolved.get("asset_settlement_intent") as Dictionary).get(
			"action"
		) == "commit",
		"successful skill commits reservation"
	)
	_check(
		_skill_state(state, "monster.owner.001", "skill.owner.1").get(
			"status"
		) == "COOLDOWN"
		and int(_skill_state(
			state,
			"monster.owner.001",
			"skill.owner.1"
		).get("cooldown_remaining_batches", -1)) == 2,
		"success starts authored cooldown"
	)
	var before_replay := state.duplicate(true)
	var replay := Core.resolve_current(state, effect_receipt)
	_check(
		bool(replay.get("replayed", false))
		and (replay.get(
			"asset_settlement_intent",
			{}
		) as Dictionary).is_empty()
		and replay.get("state") == before_replay,
		"effect receipt replay has zero duplicate intent"
	)

	var upgraded := Core.upgrade_source_skills(
		state,
		"monster.owner.001",
		1,
		2,
		["skill.owner.1", "skill.owner.2"]
	)
	state = upgraded.get("state") as Dictionary
	_check(
		int(upgraded.get("existing_cooldown_reset_count", -1)) == 0
		and int(_skill_state(
			state,
			"monster.owner.001",
			"skill.owner.1"
		).get("cooldown_remaining_batches", -1)) == 2,
		"upgrade preserves old cooldown"
	)
	_check(
		_skill_state(state, "monster.owner.001", "skill.owner.2").get(
			"status"
		) == "READY",
		"new rank skill starts READY"
	)
	var batch_two := Core.advance_batch(state, "batch.private.002")
	state = batch_two.get("state") as Dictionary
	var batch_three := Core.advance_batch(state, "batch.private.003")
	state = batch_three.get("state") as Dictionary
	_check(
		int(batch_three.get("cooldown_recovered_count", 0)) == 1
		and _skill_state(
			state,
			"monster.owner.001",
			"skill.owner.1"
		).get("status") == "READY",
		"cooldown returns skill to READY"
	)

	var atomic_started := Core.begin_atomic_receipt(
		state,
		"public.receipt.301"
	)
	state = atomic_started.get("state") as Dictionary
	var boundary_request := Core.build_request(
		"request.boundary.001",
		"batch.private.003",
		"player.0",
		"monster.owner.001",
		1,
		"skill.owner.1",
		{
			"target_kind": "enemy_facility",
			"target_id": "facility.life.002",
		}
	)
	var boundary_submit := Core.submit_request(
		state,
		boundary_request,
		_asset_view(2)
	)
	state = boundary_submit.get("state") as Dictionary
	var boundary_reservation := Core.build_asset_reservation_receipt(
		boundary_submit.get("asset_reservation_request") as Dictionary,
		true,
		"reservation_committed",
		9
	)
	var boundary_reserved := Core.apply_asset_reservation_receipt(
		state,
		boundary_reservation
	)
	state = boundary_reserved.get("state") as Dictionary
	_check(
		not bool(boundary_reserved.get("execution_due", true))
		and not bool(Core.take_next_ready_request(
			state
		).get("accepted", true)),
		"request cannot reenter inflight public Receipt"
	)
	var completed := Core.complete_atomic_receipt(
		state,
		"public.receipt.301"
	)
	state = completed.get("state") as Dictionary
	_check(
		bool(completed.get("execution_due", false)),
		"request becomes due at first boundary after Receipt"
	)
	_check(
		Core.begin_atomic_receipt(
			state,
			"public.receipt.302"
		).get("reason_code") == "private_safe_boundary_required",
		"next public Receipt waits for due private skill"
	)
	var boundary_taken := Core.take_next_ready_request(state)
	state = boundary_taken.get("state") as Dictionary
	var fizzle_receipt := Core.build_effect_receipt(
		boundary_taken.get("execution_intent") as Dictionary,
		false,
		"target_invalid_at_boundary",
		{},
		{}
	)
	var fizzled := Core.resolve_current(state, fizzle_receipt)
	state = fizzled.get("state") as Dictionary
	_check(
		not bool(fizzled.get("committed", true))
		and (fizzled.get("asset_settlement_intent") as Dictionary).get(
			"action"
		) == "release"
		and bool((fizzled.get(
			"asset_settlement_intent"
		) as Dictionary).get("full_reservation_release", false)),
		"accepted fizzle fully releases reservation"
	)
	_check(
		_skill_state(state, "monster.owner.001", "skill.owner.1").get(
			"status"
		) == "READY"
		and int(_skill_state(
			state,
			"monster.owner.001",
			"skill.owner.1"
		).get("cooldown_remaining_batches", -1)) == 0,
		"fizzle starts no cooldown"
	)
	var second_request := Core.submit_request(
		state,
		Core.build_request(
			"request.same.batch.002",
			"batch.private.003",
			"player.0",
			"monster.owner.001",
			1,
			"skill.owner.2",
			{
				"target_kind": "enemy_monster",
				"target_id": "monster.rival.001",
			}
		),
		_asset_view(2)
	)
	_check(
		not bool(second_request.get("accepted", true))
		and second_request.get("reason_code")
		== "source_batch_skill_use_exhausted",
		"accepted fizzle still consumes source batch use"
	)

	var downed := Core.set_source_status(
		state,
		"monster.owner.001",
		1,
		"downed"
	)
	state = downed.get("state") as Dictionary
	_check(
		_skill_state(state, "monster.owner.001", "skill.owner.1").get(
			"status"
		) == "DISABLED",
		"downed source disables skill"
	)
	var recovered := Core.set_source_status(
		state,
		"monster.owner.001",
		1,
		"active"
	)
	state = recovered.get("state") as Dictionary
	_check(
		_skill_state(state, "monster.owner.001", "skill.owner.1").get(
			"status"
		) == "READY",
		"recovered source restores readiness"
	)

	var checkpoint := Checkpoint.capture_monster_skill(
		"checkpoint.skill.001",
		state
	)
	var checkpoint_before := checkpoint.duplicate(true)
	var destroyed := Core.set_source_status(
		state,
		"monster.owner.001",
		1,
		"withdrawn"
	)
	var changed_state := destroyed.get("state") as Dictionary
	var rollback := Checkpoint.rollback(changed_state, checkpoint)
	_check(
		bool(rollback.get("rolled_back", false))
		and rollback.get("state") == state,
		"pure checkpoint restores exact skill authority state"
	)
	_check(
		checkpoint == checkpoint_before
		and bool(Checkpoint.validation_report(
			checkpoint
		).get("pure_data", false)),
		"checkpoint capture and rollback do not mutate checkpoint"
	)

	var ordered := Core.stable_queue_order([
		{
			"authority_receive_sequence": 4,
			"owner_player_id": "player.2",
			"request_id": "request.c",
		},
		{
			"authority_receive_sequence": 4,
			"owner_player_id": "player.1",
			"request_id": "request.b",
		},
		{
			"authority_receive_sequence": 3,
			"owner_player_id": "player.9",
			"request_id": "request.a",
		},
	])
	_check(
		(ordered[0] as Dictionary).get("request_id") == "request.a"
		and (ordered[1] as Dictionary).get("request_id") == "request.b"
		and (ordered[2] as Dictionary).get("request_id") == "request.c",
		"queue order is receive sequence then player then request"
	)
	_check(
		bool(Core.validation_report(state).get("valid", false))
		and int(Core.debug_snapshot(state).get(
			"direct_asset_write_count",
			-1
		)) == 0,
		"final core state validates with zero asset writes"
	)

	var summary := {
		"checks": _checks,
		"failures": _failures.size(),
		"execution_mode": Core.EXECUTION_MODE,
		"public_skill_card_disclosure_count": int(
			Core.public_projection_privacy_report(
				Core.public_projection(state)
			).get("public_skill_card_disclosure_count", -1)
		),
		"direct_asset_write_count": int(
			Core.debug_snapshot(state).get("direct_asset_write_count", -1)
		),
		"fizzle_cooldown_start_count": 0,
		"checkpoint_pure_data": Checkpoint.is_pure_data(checkpoint),
	}
	if _failures.is_empty():
		print(
			"V075_MONSTER_PRIVATE_SKILL_BENCH|PASS|%s"
			% JSON.stringify(summary)
		)
	else:
		push_error(
			"V075_MONSTER_PRIVATE_SKILL_BENCH|FAIL|%s"
			% JSON.stringify(summary)
		)
	bench_complete = true
	bench_passed = _failures.is_empty()
	bench_summary = summary.duplicate(true)
	set_meta("bench_complete", bench_complete)
	set_meta("bench_passed", bench_passed)
	set_meta("bench_summary", bench_summary)


func _definitions() -> Array:
	return [
		Core.build_skill_definition(
			"skill.owner.1",
			"effect.monster.pulse",
			1,
			false,
			_cost(1),
			{"target_kind": "enemy_facility"},
			{"range_hops": 2},
			2,
			"monster.skill.pulse"
		),
		Core.build_skill_definition(
			"skill.owner.2",
			"effect.monster.hunt",
			2,
			false,
			_cost(1),
			{"target_kind": "enemy_monster"},
			{"range_hops": 3},
			1,
			"monster.skill.hunt"
		),
		Core.build_skill_definition(
			"skill.owner.3",
			"effect.monster.surge",
			3,
			false,
			_cost(2),
			{"target_kind": "enemy_facility"},
			{"range_hops": 4},
			2,
			"monster.skill.surge"
		),
		Core.build_skill_definition(
			"skill.owner.4",
			"effect.monster.ultimate",
			4,
			true,
			_cost(3),
			{"target_kind": "enemy_region"},
			{"range_hops": 5},
			3,
			"monster.skill.ultimate"
		),
	]


func _skill_ids() -> Array:
	return [
		"skill.owner.1",
		"skill.owner.2",
		"skill.owner.3",
		"skill.owner.4",
	]


func _cost(technology: int) -> Dictionary:
	return {
		"life": 0,
		"energy": 0,
		"industry": 0,
		"technology": technology,
		"commerce": 0,
		"shipping": 0,
	}


func _asset_view(available: int) -> Dictionary:
	return {
		"viewer_id": "player.0",
		"state_revision": 7,
		"own_available_assets": _cost(available),
	}


func _skill_state(
	state: Dictionary,
	source_id: String,
	skill_id: String
) -> Dictionary:
	var source := (state.get("sources") as Dictionary).get(source_id) as Dictionary
	return (source.get("skill_states") as Dictionary).get(
		skill_id
	) as Dictionary


func _projection_source_ids(projection: Dictionary) -> Array:
	var result: Array[String] = []
	for source_variant in projection.get("sources", []) as Array:
		result.append(str((source_variant as Dictionary).get(
			"source_instance_id",
			""
		)))
	return result


func _private_skill_count(projection: Dictionary) -> int:
	var count := 0
	for source_variant in projection.get("sources", []) as Array:
		count += ((source_variant as Dictionary).get(
			"skill_cards",
			[]
		) as Array).size()
	return count


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("V075 MONSTER PRIVATE SKILL BENCH: %s" % message)
