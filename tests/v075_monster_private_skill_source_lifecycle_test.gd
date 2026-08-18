extends SceneTree

const Core := preload(
	"res://scripts/v075/monster/v075_monster_private_skill_core.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definitions := _definitions()
	var empty_state := Core.create_state(
		"batch.lifecycle.001",
		[],
		definitions
	)
	_expect(
		bool(Core.validation_report(empty_state).get("valid", false))
		and (empty_state.get("sources") as Dictionary).is_empty(),
		"empty source list creates a valid sealed state"
	)
	_expect(
		Core.create_state("batch.lifecycle.invalid", [], []).is_empty(),
		"empty skill definitions remain invalid"
	)

	var source := _source_core_snapshot(1, "active", 1, 0)
	var created_with_source := Core.create_state(
		"batch.lifecycle.direct",
		[source],
		definitions
	)
	_expect(
		bool(Core.validation_report(created_with_source).get("valid", false))
		and _skill(created_with_source, "skill.owner.1").get("status")
		== "READY"
		and _skill(created_with_source, "skill.owner.2").get("status")
		== "LOCKED_BY_RANK",
		"create_state and registration share Source Core initialization semantics"
	)
	var locally_downed := Core.set_source_status(
		created_with_source,
		"monster.owner.001",
		1,
		"downed"
	)
	var source_resync := Core.sync_source_snapshot(
		locally_downed.get("state") as Dictionary,
		source
	)
	_expect(
		bool(source_resync.get("accepted", false))
		and not bool(source_resync.get("replayed", true))
		and source_resync.get("reason_code") == "source_snapshot_refreshed"
		and _skill(
			source_resync.get("state") as Dictionary,
			"skill.owner.1"
		).get("status") == "READY",
		"snapshot replay still reconciles lifecycle changes made through existing API"
	)
	var destroyed_snapshot := Core.build_source_snapshot(
		"monster.destroyed.001",
		1,
		"player.0",
		1,
		"destroyed",
		_skill_ids(),
		["skill.owner.1"]
	)
	var destroyed_state := Core.create_state(
		"batch.lifecycle.destroyed",
		[destroyed_snapshot],
		definitions
	)
	var destroyed_source := (destroyed_state.get("sources") as Dictionary).get(
		"monster.destroyed.001"
	) as Dictionary
	var destroyed_all_revoked := true
	for destroyed_skill_variant in (
		destroyed_source.get("skill_states") as Dictionary
	).values():
		if str((destroyed_skill_variant as Dictionary).get(
			"status",
			""
		)) != "REVOKED":
			destroyed_all_revoked = false
	_expect(
		destroyed_all_revoked,
		"destroyed source initializes every skill REVOKED"
	)
	var registered := Core.register_source_snapshot(empty_state, source)
	_expect(
		bool(registered.get("accepted", false))
		and not bool(registered.get("replayed", true))
		and registered.get("reason_code") == "source_snapshot_registered",
		"Source Core snapshot registers into an empty state"
	)
	var state := registered.get("state") as Dictionary
	var revision_after_register := int(state.get("revision", -1))
	_expect(
		_skill(state, "skill.owner.1").get("status") == "READY"
		and _skill(state, "skill.owner.2").get("status") == "LOCKED_BY_RANK",
		"registration initializes unlocked READY and locked states"
	)

	var duplicate := Core.register_source_snapshot(state, source)
	_expect(
		bool(duplicate.get("accepted", false))
		and bool(duplicate.get("replayed", false))
		and int((duplicate.get("state") as Dictionary).get("revision", -1))
		== revision_after_register,
		"exact duplicate registration is a no-op replay"
	)
	var conflicting_registration := _source_core_snapshot(
		1,
		"active",
		1,
		1
	)
	var conflict := Core.register_source_snapshot(
		state,
		conflicting_registration
	)
	_expect(
		not bool(conflict.get("accepted", true))
		and conflict.get("reason_code") == "source_registration_collision"
		and conflict.get("state") == state,
		"conflicting duplicate registration is rejected without mutation"
	)

	state = _resolve_skill(state, "request.lifecycle.cooldown")
	var cooldown_before := int(_skill(state, "skill.owner.1").get(
		"cooldown_remaining_batches",
		-1
	))
	var action_generation_before := int(
		((state.get("sources") as Dictionary).get(
			"monster.owner.001"
		) as Dictionary).get("action_generation", -1)
	)
	_expect(
		_skill(state, "skill.owner.1").get("status") == "COOLDOWN"
		and cooldown_before == 2,
		"private skill cooldown is established before source synchronization"
	)

	var upgraded := Core.sync_source_snapshot(
		state,
		_source_core_snapshot(2, "active", 1, 2)
	)
	_expect(
		bool(upgraded.get("accepted", false))
		and upgraded.get("reason_code") == "source_snapshot_upgraded"
		and int(upgraded.get("existing_cooldown_reset_count", -1)) == 0
		and (upgraded.get("newly_ready_skill_definition_ids") as Array)
		== ["skill.owner.2"],
		"same-generation upgrade reports preserved cooldown and one new skill"
	)
	state = upgraded.get("state") as Dictionary
	_expect(
		int(_skill(state, "skill.owner.1").get(
			"cooldown_remaining_batches",
			-1
		)) == cooldown_before
		and _skill(state, "skill.owner.2").get("status") == "READY",
		"upgrade keeps old cooldown and initializes new skill READY"
	)

	var downed := Core.sync_source_snapshot(
		state,
		_source_core_snapshot(2, "downed", 1, 3)
	)
	state = downed.get("state") as Dictionary
	_expect(
		bool(downed.get("accepted", false))
		and _skill(state, "skill.owner.1").get("status") == "DISABLED"
		and int(_skill(state, "skill.owner.1").get(
			"cooldown_remaining_batches",
			-1
		)) == cooldown_before
		and _skill(state, "skill.owner.2").get("status") == "DISABLED",
		"downed synchronization disables skills without losing cooldown"
	)
	var recovered := Core.sync_source_snapshot(
		state,
		_source_core_snapshot(2, "active", 1, 4)
	)
	state = recovered.get("state") as Dictionary
	_expect(
		bool(recovered.get("accepted", false))
		and recovered.get("reason_code") == "source_snapshot_refreshed"
		and _skill(state, "skill.owner.1").get("status") == "COOLDOWN"
		and int(_skill(state, "skill.owner.1").get(
			"cooldown_remaining_batches",
			-1
		)) == cooldown_before
		and _skill(state, "skill.owner.2").get("status") == "READY",
		"active recovery restores readiness while preserving cooldown"
	)
	var recovery_replay := Core.sync_source_snapshot(
		state,
		_source_core_snapshot(2, "active", 1, 4)
	)
	_expect(
		bool(recovery_replay.get("replayed", false))
		and recovery_replay.get("state") == state,
		"repeating the current snapshot is an exact sync replay"
	)

	var withdrawn := Core.sync_source_snapshot(
		state,
		_source_core_snapshot(2, "withdrawn", 1, 5)
	)
	state = withdrawn.get("state") as Dictionary
	_expect(
		bool(withdrawn.get("accepted", false))
		and withdrawn.get("reason_code") == "source_snapshot_revoked",
		"withdrawn Source Core snapshot is accepted as a lifecycle transition"
	)
	for skill_id in _skill_ids():
		_expect(
			_skill(state, skill_id).get("status") == "REVOKED",
			"withdrawn source revokes %s" % skill_id
		)
	_expect(
		(Core.owner_private_projection(state, "player.0").get(
			"sources"
		) as Array).is_empty(),
		"revoked source leaves no owner skill dock"
	)

	var recycled := Core.sync_source_snapshot(
		state,
		_source_core_snapshot(1, "active", 2, 6)
	)
	state = recycled.get("state") as Dictionary
	var recycled_source := (state.get("sources") as Dictionary).get(
		"monster.owner.001"
	) as Dictionary
	_expect(
		bool(recycled.get("generation_replaced", false))
		and int(recycled_source.get("source_generation", -1)) == 2
		and int(recycled_source.get("action_generation", -1))
		!= action_generation_before
		and int(_skill(state, "skill.owner.1").get(
			"cooldown_remaining_batches",
			-1
		)) == 0
		and _skill(state, "skill.owner.1").get("status") == "READY",
		"higher generation starts a fresh private action generation"
	)
	var stale := Core.sync_source_snapshot(
		state,
		_source_core_snapshot(1, "active", 1, 7)
	)
	_expect(
		not bool(stale.get("accepted", true))
		and stale.get("reason_code") == "source_snapshot_generation_stale"
		and stale.get("state") == state,
		"lower generation snapshot is rejected without mutation"
	)

	var pending_request := Core.build_request(
		"request.lifecycle.old-generation",
		str(state.get("batch_id", "")),
		"player.0",
		"monster.owner.001",
		2,
		"skill.owner.1",
		{"target_kind": "enemy_facility", "target_id": "facility.target.001"}
	)
	var pending_submit := Core.submit_request(
		state,
		pending_request,
		_asset_view()
	)
	state = pending_submit.get("state") as Dictionary
	var next_generation := _source_core_snapshot(1, "active", 3, 8)
	var generation_sync := Core.sync_source_snapshot(state, next_generation)
	state = generation_sync.get("state") as Dictionary
	var owner_after_generation_sync := Core.owner_private_projection(
		state,
		"player.0"
	)
	_expect(
		not JSON.stringify(owner_after_generation_sync).contains(
			"request.lifecycle.old-generation"
		)
		and not JSON.stringify(owner_after_generation_sync).contains(
			"facility.target.001"
		),
		"old-generation pending target is absent from the new owner projection"
	)
	var old_reservation := Core.build_asset_reservation_receipt(
		pending_submit.get("asset_reservation_request") as Dictionary,
		true,
		"reservation_committed",
		11
	)
	var old_reserved := Core.apply_asset_reservation_receipt(
		state,
		old_reservation
	)
	state = old_reserved.get("state") as Dictionary
	var new_source_after_old_receipt := (state.get("sources") as Dictionary).get(
		"monster.owner.001"
	) as Dictionary
	_expect(
		int(new_source_after_old_receipt.get(
			"source_generation",
			-1
		)) == 3
		and int(new_source_after_old_receipt.get(
			"batch_active_skill_use_count",
			-1
		)) == 0
		and _skill(state, "skill.owner.1").get("status") == "READY",
		"old-generation reservation receipt cannot mutate replacement source"
	)
	var old_taken := Core.take_next_ready_request(state)
	state = old_taken.get("state") as Dictionary
	var old_effect := Core.build_effect_receipt(
		old_taken.get("execution_intent") as Dictionary,
		true,
		"resolved",
		{},
		{}
	)
	var old_resolved := Core.resolve_current(state, old_effect)
	state = old_resolved.get("state") as Dictionary
	_expect(
		bool(old_resolved.get("accepted", false))
		and not bool(old_resolved.get("committed", true))
		and old_resolved.get("reason_code")
		== "source_generation_changed_at_boundary"
		and _skill(state, "skill.owner.1").get("status") == "READY"
		and int(_skill(state, "skill.owner.1").get(
			"cooldown_remaining_batches",
			-1
		)) == 0,
		"old-generation action fizzles without touching new skill state"
	)

	var public_projection := Core.public_projection(state)
	var privacy := Core.public_projection_privacy_report(public_projection)
	var public_text := JSON.stringify(public_projection)
	_expect(
		bool(privacy.get("valid", false))
		and int(privacy.get("public_skill_card_disclosure_count", -1)) == 0
		and int(privacy.get("future_skill_target_disclosure_count", -1)) == 0
		and not public_text.contains("asset_cost_by_color")
		and not public_text.contains("cooldown_remaining_batches")
		and not public_text.contains("old-generation"),
		"source synchronization does not change the private/public projection contract"
	)
	_finish()


func _definitions() -> Array:
	var result: Array = []
	for rank in range(1, 5):
		result.append(Core.build_skill_definition(
			"skill.owner.%d" % rank,
			"effect.monster.%d" % rank,
			rank,
			rank == 4,
			_cost(1),
			{"target_kind": "enemy_facility"},
			{"range_hops": rank + 1},
			2 if rank == 1 else 1,
			"monster.skill.%d" % rank
		))
	return result


func _source_core_snapshot(
	rank: int,
	status: String,
	generation: int,
	damage_revision: int
) -> Dictionary:
	var skill_states := {}
	for index in range(4):
		var skill_id := "skill.owner.%d" % (index + 1)
		var unlocked := index < rank
		var skill_status := "LOCKED_BY_RANK"
		var resume_status := "LOCKED_BY_RANK"
		var skill_generation := 0
		if ["destroyed", "withdrawn"].has(status):
			skill_status = "REVOKED"
			resume_status = "REVOKED"
			skill_generation = 2
		elif unlocked:
			skill_status = "READY" if status == "active" else "DISABLED"
			resume_status = "READY"
			skill_generation = 1
		skill_states[skill_id] = {
			"skill_definition_id": skill_id,
			"status": skill_status,
			"cooldown_batches_remaining": 0,
			"skill_generation": skill_generation,
			"resume_status": resume_status,
		}
	var snapshot := {
		"schema_version": "1.0.0",
		"contract_id": "v075.monster_source.v1",
		"ruleset_id": "v0.7.5",
		"source_instance_id": "monster.owner.001",
		"source_definition_id": "monster.definition.alpha",
		"definition_fingerprint": (
			"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
		),
		"monster_family_id": "monster.family.alpha",
		"owner_player_id": "player.0",
		"region_id": "region.001",
		"source_generation": generation,
		"rank": rank,
		"hp": 100 if status == "active" else 0,
		"max_hp": 100,
		"armor": 3,
		"status": status,
		"damage_revision": damage_revision,
		"preferred_industry_color": "life",
		"facility_type_preference": ["factory", "market", "warehouse"],
		"base_detection_range_hops": 2,
		"current_detection_range_hops": 2,
		"movement_profile": "ground_trample",
		"movement_budget_milli_arc": 1000,
		"unlocked_skill_definition_ids": [
			"skill.owner.1",
			"skill.owner.2",
			"skill.owner.3",
			"skill.owner.4",
		].slice(0, rank),
		"skill_states": skill_states,
		"batch_active_skill_use_count": 0,
		"created_from_card_instance_id": "card.monster.alpha.001",
		"withdrawal_reason": "replaced" if status == "withdrawn" else "",
		"kill_reward_count": 0,
	}
	snapshot["source_fingerprint"] = _fingerprint(snapshot)
	return snapshot


func _resolve_skill(state: Dictionary, request_id: String) -> Dictionary:
	var request := Core.build_request(
		request_id,
		str(state.get("batch_id", "")),
		"player.0",
		"monster.owner.001",
		int(((state.get("sources") as Dictionary).get(
			"monster.owner.001"
		) as Dictionary).get("source_generation", 1)),
		"skill.owner.1",
		{"target_kind": "enemy_facility", "target_id": "facility.target.001"}
	)
	var submitted := Core.submit_request(state, request, _asset_view())
	var reservation := Core.build_asset_reservation_receipt(
		submitted.get("asset_reservation_request") as Dictionary,
		true,
		"reservation_committed",
		9
	)
	var reserved := Core.apply_asset_reservation_receipt(
		submitted.get("state") as Dictionary,
		reservation
	)
	var taken := Core.take_next_ready_request(reserved.get("state") as Dictionary)
	var effect := Core.build_effect_receipt(
		taken.get("execution_intent") as Dictionary,
		true,
		"resolved",
		{"target_kind": "enemy_facility", "target_id": "facility.target.001"},
		{"effect_summary_key": "test"}
	)
	var resolved := Core.resolve_current(taken.get("state") as Dictionary, effect)
	return resolved.get("state") as Dictionary


func _skill(state: Dictionary, skill_id: String) -> Dictionary:
	var source := (state.get("sources") as Dictionary).get(
		"monster.owner.001"
	) as Dictionary
	return (source.get("skill_states") as Dictionary).get(skill_id) as Dictionary


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


func _asset_view() -> Dictionary:
	return {
		"viewer_id": "player.0",
		"state_revision": 7,
		"own_available_assets": _cost(6),
	}


func _fingerprint(value: Variant) -> String:
	return _canonical_json(value).sha256_text().to_lower()


func _canonical_json(value: Variant) -> String:
	if value == null or value is String or value is bool or value is int:
		return JSON.stringify(value)
	if value is Array:
		var items: Array[String] = []
		for item in value as Array:
			items.append(_canonical_json(item))
		return "[" + ",".join(items) + "]"
	var dictionary := value as Dictionary
	var keys: Array[String] = []
	for key_variant in dictionary.keys():
		keys.append(str(key_variant))
	keys.sort()
	var members: Array[String] = []
	for key in keys:
		members.append(JSON.stringify(key) + ":" + _canonical_json(
			dictionary.get(key)
		))
	return "{" + ",".join(members) + "}"


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("V075_MONSTER_PRIVATE_SKILL_SOURCE_LIFECYCLE_TEST|%s|%d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
	])
	quit(0 if _failures.is_empty() else 1)
