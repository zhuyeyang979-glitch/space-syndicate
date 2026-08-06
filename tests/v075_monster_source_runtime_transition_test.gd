extends SceneTree

const Core := preload(
	"res://scripts/v075/monster/v075_monster_source_core.gd"
)

const SOURCE_ID := "monster.alpha.runtime"
const SOURCE_GENERATION := 1

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := Core.build_source_snapshot(
		_definition(),
		SOURCE_ID,
		"player.alpha",
		"region.a",
		2,
		100,
		"active",
		SOURCE_GENERATION,
		"card.origin.runtime",
		{
			"skill.alpha.1": {
				"status": Core.SKILL_COOLDOWN,
				"cooldown_batches_remaining": 2,
				"skill_generation": 5,
				"resume_status": Core.SKILL_COOLDOWN,
			},
		}
	)
	var state := Core.new_state(
		["player.alpha"],
		{},
		[source]
	)
	_expect(
		Core.validation_report(state).get("valid") == true,
		"initial runtime transition state validates"
	)
	var initial_checkpoint := Core.capture_checkpoint(
		state,
		"checkpoint.runtime.initial"
	)
	var initial_fingerprint := str(state.get("state_fingerprint", ""))

	var generation_mismatch := Core.commit_authoritative_movement(
		state,
		"transition.move.generation.mismatch",
		SOURCE_ID,
		SOURCE_GENERATION + 1,
		"region.b"
	)
	_expect(
		generation_mismatch.get("accepted") == false
		and generation_mismatch.get("reason_code")
		== "monster_transition_source_generation_mismatch"
		and (generation_mismatch.get("state", {}) as Dictionary).get(
			"state_fingerprint"
		) == initial_fingerprint,
		"generation mismatch rejects movement with zero state change"
	)
	var tampered_operation := Core.build_movement_transition_operation(
		"transition.move.tampered",
		SOURCE_ID,
		SOURCE_GENERATION,
		"region.b"
	)
	tampered_operation["destination_region_id"] = "region.c"
	var tampered := Core.commit_runtime_transition(
		state,
		tampered_operation
	)
	_expect(
		tampered.get("accepted") == false
		and tampered.get("reason_code")
		== "monster_transition_operation_fingerprint_invalid"
		and (tampered.get("state", {}) as Dictionary).get(
			"state_fingerprint"
		) == initial_fingerprint,
		"sealed operation rejects direct Runtime Owner mutation"
	)

	var moved := Core.commit_authoritative_movement(
		state,
		"transition.move.commit",
		SOURCE_ID,
		SOURCE_GENERATION,
		"region.b"
	)
	var move_receipt := moved.get("receipt", {}) as Dictionary
	state = moved.get("state", {}) as Dictionary
	_expect(
		moved.get("accepted") == true
		and Core.source_snapshot(state, SOURCE_ID).get("region_id")
		== "region.b"
		and move_receipt.get("previous_region_id") == "region.a"
		and move_receipt.get("current_region_id") == "region.b"
		and move_receipt.get("animation_authority_count") == 0
		and move_receipt.get("frame_position_mutation_count") == 0,
		"movement commits region identity without animation authority"
	)
	var moved_fingerprint := str(state.get("state_fingerprint", ""))
	var move_replay := Core.commit_authoritative_movement(
		state,
		"transition.move.commit",
		SOURCE_ID,
		SOURCE_GENERATION,
		"region.b"
	)
	_expect(
		move_replay.get("accepted") == true
		and move_replay.get("idempotent_replay") == true
		and (move_replay.get("state", {}) as Dictionary).get(
			"state_fingerprint"
		) == moved_fingerprint
		and (state.get(
			"transition_receipt_journal",
			[]
		) as Array).size() == 1,
		"duplicate movement returns exact-once receipt"
	)
	var move_conflict := Core.commit_authoritative_movement(
		state,
		"transition.move.commit",
		SOURCE_ID,
		SOURCE_GENERATION,
		"region.c"
	)
	_expect(
		move_conflict.get("accepted") == false
		and move_conflict.get("reason_code")
		== "monster_transition_operation_id_conflict"
		and (move_conflict.get("state", {}) as Dictionary).get(
			"state_fingerprint"
		) == moved_fingerprint,
		"same operation ID cannot bind a different movement"
	)
	var move_noop := Core.commit_authoritative_movement(
		state,
		"transition.move.noop",
		SOURCE_ID,
		SOURCE_GENERATION,
		"region.b"
	)
	_expect(
		move_noop.get("accepted") == false
		and move_noop.get("reason_code")
		== "monster_movement_destination_unchanged",
		"same-region movement is rejected"
	)
	var destroy_active := Core.commit_destroy_transition(
		state,
		"transition.destroy.active.invalid",
		SOURCE_ID,
		SOURCE_GENERATION,
		"combat.execution"
	)
	_expect(
		destroy_active.get("accepted") == false
		and destroy_active.get("reason_code")
		== "monster_destroy_requires_downed_source",
		"destroy is an explicit downed-only transition"
	)

	state = _commit_detection(
		state,
		"transition.detect.grow.1",
		Core.DETECTION_NO_TARGET_GROWTH,
		4
	)
	_expect(
		Core.source_snapshot(
			state,
			SOURCE_ID
		).get("current_detection_range_hops") == 3,
		"no-target transition grows detection by one"
	)
	state = _commit_detection(
		state,
		"transition.detect.grow.2",
		Core.DETECTION_NO_TARGET_GROWTH,
		4
	)
	_expect(
		Core.source_snapshot(
			state,
			SOURCE_ID
		).get("current_detection_range_hops") == 4,
		"detection growth deterministically reaches full-map range"
	)
	var growth_at_full := Core.commit_detection_range_transition(
		state,
		"transition.detect.grow.full.invalid",
		SOURCE_ID,
		SOURCE_GENERATION,
		Core.DETECTION_NO_TARGET_GROWTH,
		4
	)
	_expect(
		growth_at_full.get("accepted") == false
		and growth_at_full.get("reason_code")
		== "monster_detection_requires_hungry_plan",
		"full-map no-target state requires explicit hungry plan"
	)
	var hungry := Core.commit_detection_range_transition(
		state,
		"transition.detect.hungry",
		SOURCE_ID,
		SOURCE_GENERATION,
		Core.DETECTION_HUNGRY_PLAN,
		4
	)
	var hungry_receipt := hungry.get("receipt", {}) as Dictionary
	state = hungry.get("state", {}) as Dictionary
	var hungry_source := Core.source_snapshot(state, SOURCE_ID)
	_expect(
		hungry.get("accepted") == true
		and hungry_source.get("current_detection_range_hops") == 4
		and not hungry_source.has("hungry")
		and hungry_receipt.get("hungry_after_transition") == true
		and hungry_receipt.get("detection_transition_kind")
		== Core.DETECTION_HUNGRY_PLAN,
		"hungry is receipt-only while source schema remains closed"
	)
	var preferred := Core.commit_detection_range_transition(
		state,
		"transition.detect.preferred",
		SOURCE_ID,
		SOURCE_GENERATION,
		Core.DETECTION_PREFERRED_COLOR_HIT
	)
	var preferred_receipt := (
		preferred.get("receipt", {}) as Dictionary
	)
	state = preferred.get("state", {}) as Dictionary
	_expect(
		preferred.get("accepted") == true
		and Core.source_snapshot(
			state,
			SOURCE_ID
		).get("current_detection_range_hops") == 2
		and preferred_receipt.get("hungry_after_transition") == false,
		"preferred-color hit restores authored base detection range"
	)

	var armor_only := Core.commit_combat_damage(
		state,
		"transition.damage.armor",
		SOURCE_ID,
		SOURCE_GENERATION,
		2
	)
	var armor_receipt := armor_only.get("receipt", {}) as Dictionary
	state = armor_only.get("state", {}) as Dictionary
	var armor_source := Core.source_snapshot(state, SOURCE_ID)
	_expect(
		armor_source.get("armor") == 1
		and armor_source.get("hp") == 100
		and armor_source.get("damage_revision") == 1
		and armor_receipt.get("armor_absorbed") == 2
		and armor_receipt.get("hp_damage") == 0,
		"armor absorbs damage before HP and advances damage revision"
	)
	var armor_state_fingerprint := str(state.get("state_fingerprint", ""))
	var armor_replay := Core.commit_combat_damage(
		state,
		"transition.damage.armor",
		SOURCE_ID,
		SOURCE_GENERATION,
		2
	)
	_expect(
		armor_replay.get("idempotent_replay") == true
		and (armor_replay.get("state", {}) as Dictionary).get(
			"state_fingerprint"
		) == armor_state_fingerprint
		and Core.source_snapshot(
			state,
			SOURCE_ID
		).get("damage_revision") == 1,
		"duplicate damage cannot debit armor or revision twice"
	)
	var mixed_damage := Core.commit_combat_damage(
		state,
		"transition.damage.mixed",
		SOURCE_ID,
		SOURCE_GENERATION,
		11
	)
	var mixed_receipt := (
		mixed_damage.get("receipt", {}) as Dictionary
	)
	state = mixed_damage.get("state", {}) as Dictionary
	_expect(
		mixed_receipt.get("armor_absorbed") == 1
		and mixed_receipt.get("hp_damage") == 10
		and Core.source_snapshot(state, SOURCE_ID).get("armor") == 0
		and Core.source_snapshot(state, SOURCE_ID).get("hp") == 90
		and Core.source_snapshot(
			state,
			SOURCE_ID
		).get("damage_revision") == 2,
		"remaining damage crosses armor into HP exactly once"
	)
	var downed_result := Core.commit_combat_damage(
		state,
		"transition.damage.downed",
		SOURCE_ID,
		SOURCE_GENERATION,
		999
	)
	var downed_receipt := (
		downed_result.get("receipt", {}) as Dictionary
	)
	state = downed_result.get("state", {}) as Dictionary
	var downed_source := Core.source_snapshot(state, SOURCE_ID)
	var downed_skills := (
		downed_source.get("skill_states", {}) as Dictionary
	)
	_expect(
		downed_source.get("hp") == 0
		and downed_source.get("status") == "downed"
		and downed_source.get("damage_revision") == 3
		and downed_receipt.get("status_after") == "downed"
		and (downed_skills.get(
			"skill.alpha.1",
			{}
		) as Dictionary).get("status") == Core.SKILL_DISABLED
		and (downed_skills.get(
			"skill.alpha.1",
			{}
		) as Dictionary).get("cooldown_batches_remaining") == 2
		and (downed_skills.get(
			"skill.alpha.2",
			{}
		) as Dictionary).get("status") == Core.SKILL_DISABLED,
		"zero HP enters downed and disables unlocked skills"
	)
	var downed_fingerprint := str(state.get("state_fingerprint", ""))
	var downed_damage := Core.commit_combat_damage(
		state,
		"transition.damage.downed.invalid",
		SOURCE_ID,
		SOURCE_GENERATION,
		1
	)
	var downed_move := Core.commit_authoritative_movement(
		state,
		"transition.move.downed.invalid",
		SOURCE_ID,
		SOURCE_GENERATION,
		"region.c"
	)
	_expect(
		downed_damage.get("reason_code")
		== "monster_damage_source_downed_requires_destroy"
		and downed_move.get("reason_code")
		== "monster_movement_source_downed"
		and (downed_move.get("state", {}) as Dictionary).get(
			"state_fingerprint"
		) == downed_fingerprint,
		"downed source cannot take normal damage or move"
	)
	var destroy_generation_mismatch := Core.commit_destroy_transition(
		state,
		"transition.destroy.generation.mismatch",
		SOURCE_ID,
		SOURCE_GENERATION + 1,
		"combat.execution"
	)
	_expect(
		destroy_generation_mismatch.get("accepted") == false
		and destroy_generation_mismatch.get("reason_code")
		== "monster_transition_source_generation_mismatch",
		"destroy validates source generation"
	)
	var destroyed_result := Core.commit_destroy_transition(
		state,
		"transition.destroy.commit",
		SOURCE_ID,
		SOURCE_GENERATION,
		"combat.execution"
	)
	var destroy_receipt := (
		destroyed_result.get("receipt", {}) as Dictionary
	)
	state = destroyed_result.get("state", {}) as Dictionary
	var destroyed_source := Core.source_snapshot(state, SOURCE_ID)
	_expect(
		destroyed_source.get("status") == "destroyed"
		and destroyed_source.get("damage_revision") == 4
		and _all_skills_revoked(
			destroyed_source.get("skill_states", {}) as Dictionary
		)
		and destroy_receipt.get("destroy_reason_id")
		== "combat.execution",
		"explicit destroy transitions downed source and revokes skills"
	)
	var destroyed_fingerprint := str(state.get("state_fingerprint", ""))
	var destroy_replay := Core.commit_destroy_transition(
		state,
		"transition.destroy.commit",
		SOURCE_ID,
		SOURCE_GENERATION,
		"combat.execution"
	)
	_expect(
		destroy_replay.get("idempotent_replay") == true
		and (destroy_replay.get("state", {}) as Dictionary).get(
			"state_fingerprint"
		) == destroyed_fingerprint,
		"duplicate destroy is exact-once"
	)
	_expect(
		(state.get("processed_transitions", {}) as Dictionary).size()
		== 9
		and (state.get(
			"transition_receipt_journal",
			[]
		) as Array).size() == 9
		and Core.validation_report(state).get("valid") == true,
		"transition ledger records only nine committed operations"
	)
	var rollback := Core.rollback_to_checkpoint(
		state,
		initial_checkpoint
	)
	var restored := rollback.get("state", {}) as Dictionary
	var restored_source := Core.source_snapshot(restored, SOURCE_ID)
	_expect(
		rollback.get("accepted") == true
		and restored.get("state_fingerprint") == initial_fingerprint
		and restored_source.get("region_id") == "region.a"
		and restored_source.get("armor") == 3
		and restored_source.get("hp") == 100
		and restored_source.get("status") == "active"
		and (restored.get(
			"processed_transitions",
			{}
		) as Dictionary).is_empty(),
		"checkpoint rollback restores source and transition ledger exactly"
	)
	_finish()


func _commit_detection(
	state: Dictionary,
	operation_id: String,
	transition_kind: String,
	full_map_range: int
) -> Dictionary:
	var result := Core.commit_detection_range_transition(
		state,
		operation_id,
		SOURCE_ID,
		SOURCE_GENERATION,
		transition_kind,
		full_map_range
	)
	_expect(
		result.get("accepted") == true,
		"detection transition commits: %s"
		% str(result.get("reason_code", ""))
	)
	return result.get("state", {}) as Dictionary


func _all_skills_revoked(skill_states: Dictionary) -> bool:
	for skill_variant in skill_states.values():
		if (
			str((skill_variant as Dictionary).get("status", ""))
			!= Core.SKILL_REVOKED
		):
			return false
	return skill_states.size() == 4


func _definition() -> Dictionary:
	return {
		"source_definition_id": "monster.alpha.source",
		"monster_family_id": "alpha",
		"preferred_industry_color": "life",
		"facility_type_preference": ["factory", "market", "warehouse"],
		"base_detection_range_hops": 2,
		"movement_profile": "ground_trample",
		"movement_budget_milli_arc_by_rank": [1000, 1200, 1400, 1600],
		"max_hp_by_rank": [80, 100, 120, 140],
		"armor_by_rank": [2, 3, 4, 5],
		"active_skill_definition_ids": [
			"skill.alpha.1",
			"skill.alpha.2",
			"skill.alpha.3",
			"skill.alpha.4",
		],
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for failure in _failures:
		push_error(
			"V075_MONSTER_SOURCE_RUNTIME_TRANSITION_TEST|FAIL|%s"
			% failure
		)
	print(
		"V075_MONSTER_SOURCE_RUNTIME_TRANSITION_TEST|%s|checks=%d|failures=%d"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
		]
	)
	quit(0 if _failures.is_empty() else 1)
