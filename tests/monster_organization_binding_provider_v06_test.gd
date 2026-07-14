extends SceneTree

const SCHEMA := preload("res://scripts/cards/v06/units/unit_card_runtime_schema_v06.gd")
const CONTROLLER_SCRIPT := preload("res://scripts/runtime/monster_runtime_controller.gd")
const WORLD_BRIDGE_SCRIPT := preload("res://scripts/runtime/monster_runtime_world_bridge.gd")
const CATALOG := preload("res://resources/cards/runtime/card_runtime_catalog_v06.tres")

const ACTOR_A := "human.alpha"
const ACTOR_B := "ai.beta"
const REGION_ID := "region.alpha"
const SPORE := "spore_tide_emperor"
const SAND := "sand_armor_rover"
const METEOR := "meteor_sentinel"
const SPORE_R1 := "unit.monster.spore_tide_emperor.rank_1"
const SAND_R1 := "unit.monster.sand_armor_rover.rank_1"
const EFFECT_KIND := "deploy_or_upgrade_monster"
const ACTION_KIND := "deploy_or_upgrade_monster"

var _checks := 0
var _failures: Array[String] = []


class FixtureWorld:
	extends Node

	var players := [{"actor_id": ACTOR_A}, {"actor_id": ACTOR_B}]
	var districts := [{"name": "阿尔法区", "center": Vector2(80.0, 120.0)}]
	var game_time := 0.0
	var selected_player := 0
	var selected_district := 0
	var rng := RandomNumberGenerator.new()
	var rule_revisions := {ACTOR_A: 21, ACTOR_B: 22}
	var player_indices := {ACTOR_A: 0, ACTOR_B: 1}
	var starter_cards := {ACTOR_A: SPORE_R1, ACTOR_B: SAND_R1}
	var cap_rows := {
		ACTOR_A: [1, 2, 0],
		ACTOR_B: [1, 2, 0],
	}
	var cap_revisions := {ACTOR_A: 31, ACTOR_B: 32}
	var window_sequence := 7
	var window_revision := 11
	var corrupt_actor := false
	var corrupt_window := false
	var corrupt_kind := false
	var stale_revision := false
	var forged_gradient := false
	var validator_reject := false

	func monster_deploy_region_snapshot_v06(region_id: String) -> Dictionary:
		if region_id != REGION_ID:
			return {"available": false, "authoritative": false, "reason_code": "fixture_region_missing"}
		return {
			"available": true,
			"authoritative": true,
			"revision": 7,
			"region_id": REGION_ID,
			"region_index": 0,
			"display_name": "阿尔法区",
			"destroyed": false,
			"starter_summon_allowed": true,
			"allowed_monster_families": [SPORE, SAND, METEOR],
			"world_position": {"x": 80.0, "y": 120.0},
		}

	func monster_deploy_profile_snapshot_v06(family_id: String, rank: int) -> Dictionary:
		if not [SPORE, SAND, METEOR].has(family_id) or rank < 1 or rank > 4:
			return {"available": false, "authoritative": false, "reason_code": "fixture_profile_missing"}
		var names := {SPORE: "孢雾海皇", SAND: "砂铠陆行兽", METEOR: "流星哨兵"}
		return {
			"available": true,
			"authoritative": true,
			"revision": 100 + rank,
			"family_id": family_id,
			"rank": rank,
			"profile_id": "fixture.%s.rank_%d" % [family_id, rank],
			"name": str(names.get(family_id, "怪兽")),
			"catalog_index": [SPORE, SAND, METEOR].find(family_id),
			"hp": 40 + rank * 8,
			"armor": rank - 1,
			"move_mps": 16.0 + rank,
			"initial_duration_seconds": 120.0 + rank * 10.0,
			"move_damage": rank,
			"collision_damage": rank + 1,
			"movement_traits": [],
			"terrain_move_multiplier": {},
			"resource_drain": rank,
			"resource_focus": ["life"],
			"bound_skill_patch": {},
			"economic_patch": {},
			"role_cash_patch": {},
		}

	func monster_deploy_rule_snapshot_v06(actor_id: String) -> Dictionary:
		if not player_indices.has(actor_id):
			return {"available": false, "authoritative": false, "reason_code": "fixture_actor_missing"}
		return {
			"available": true,
			"authoritative": true,
			"revision": int(rule_revisions.get(actor_id, -1)),
			"actor_id": actor_id,
			"player_index": int(player_indices.get(actor_id, -1)),
			"monster_binding_limit": 99,
			"primary_monster_rank_limit": 4,
			"starter_entitled": true,
			"starter_consumed": false,
			"starter_card_id": str(starter_cards.get(actor_id, "")),
			"starter_card_instance_id": "starter.%s" % actor_id,
		}

	func monster_deploy_cross_owner_capabilities_v06() -> Dictionary:
		return {
			"contract_version": "v0.6",
			"region_facts": {"revisioned_snapshot": true, "owner_id": "fixture.region"},
			"monster_profile": {"revisioned_snapshot": true, "owner_id": "fixture.profile"},
			"binding_rule": {"revisioned_snapshot": true, "owner_id": "fixture.binding"},
		}

	func current_monster_binding_window_snapshot_v06() -> Dictionary:
		return {
			"available": true,
			"authoritative": true,
			"window_sequence": window_sequence,
			"revision": window_revision,
		}

	func monster_binding_caps(actor_id: String, requested_window: int) -> Dictionary:
		if not cap_rows.has(actor_id):
			return {"available": false, "authoritative": false, "reason_code": "fixture_cap_actor_missing"}
		var row: Array = (cap_rows.get(actor_id, [1, 2, 0]) as Array).duplicate()
		if forged_gradient:
			row = [2, 4, 3]
		return {
			"available": true,
			"authoritative": true,
			"actor_id": ACTOR_B if corrupt_actor and actor_id == ACTOR_A else actor_id,
			"window_sequence": requested_window + 1 if corrupt_window else requested_window,
			"owner_revision": int(cap_revisions.get(actor_id, 0)) - 1 if stale_revision else int(cap_revisions.get(actor_id, 0)),
			"capability_kind": "military_caps" if corrupt_kind else "monster_caps",
			"controlled_monster_count_limit": int(row[0]),
			"primary_monster_rank_limit": int(row[1]),
			"secondary_monster_rank_limit": int(row[2]),
		}

	func monster_binding_caps_for_target_owner(actor_id: String, requested_window: int) -> Dictionary:
		return monster_binding_caps(actor_id, requested_window)

	func validate_monster_binding_caps_v06(snapshot: Dictionary, _for_target_owner: bool) -> Dictionary:
		var actor_id := str(snapshot.get("actor_id", ""))
		var valid := (
			not validator_reject
			and cap_revisions.has(actor_id)
			and int(snapshot.get("owner_revision", -1)) == int(cap_revisions.get(actor_id, -2))
			and int(snapshot.get("window_sequence", -1)) == window_sequence
		)
		return {"valid": valid, "reason_code": "fixture_cap_valid" if valid else "fixture_cap_invalid"}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_base_fallback_and_bad_provider_inputs()
	_verify_official_gradients_and_second_slot()
	_verify_target_owner_cap_and_commit_revalidation()
	_verify_cap_downshift_save_load_and_privacy()
	_finish()


func _verify_base_fallback_and_bad_provider_inputs() -> void:
	var missing := _fixture(false)
	var missing_owner: MonsterRuntimeController = missing.owner
	var missing_world: FixtureWorld = missing.world
	_finalize_card(missing_owner, _starter_intent(missing_owner, missing_world, "tx-missing-start", ACTOR_A, SPORE_R1))
	_finalize_card(missing_owner, _upgrade_intent(missing_owner, missing_world, "tx-missing-r2", ACTOR_A, SPORE_R1, _family_actor(missing_owner, SPORE)))
	var before := _state_fingerprint(missing_owner)
	var rejected: Dictionary = missing_owner.prepare_unit_card_intent_v06(_upgrade_intent(missing_owner, missing_world, "tx-missing-r3", ACTOR_A, SPORE_R1, _family_actor(missing_owner, SPORE), {"request_monster_rank_cap": 4}))
	_expect(str(rejected.get("reason_code", "")) == "monster_target_owner_rank_cap_exceeded" and before == _state_fingerprint(missing_owner), "missing provider is base 1xII and request cap cannot elevate")
	var count_rejected: Dictionary = missing_owner.prepare_unit_card_intent_v06(_summon_intent(missing_owner, missing_world, "tx-missing-second", ACTOR_A, _card_id(METEOR, 1)))
	_expect(str(count_rejected.get("reason_code", "")) == "monster_binding_count_limit_reached" and before == _state_fingerprint(missing_owner), "missing provider base fallback also enforces one-monster count")
	_cleanup(missing)

	for mode in ["actor", "window", "revision", "kind", "gradient", "validator"]:
		var fixture := _fixture(true)
		var owner: MonsterRuntimeController = fixture.owner
		var world: FixtureWorld = fixture.world
		world.cap_rows[ACTOR_A] = [1, 4, 0]
		world.set("corrupt_%s" % mode, true) if ["actor", "window", "kind"].has(mode) else null
		if mode == "revision": world.stale_revision = true
		if mode == "gradient": world.forged_gradient = true
		if mode == "validator": world.validator_reject = true
		_finalize_card(owner, _starter_intent(owner, world, "tx-%s-start" % mode, ACTOR_A, SPORE_R1))
		_finalize_card(owner, _upgrade_intent(owner, world, "tx-%s-r2" % mode, ACTOR_A, SPORE_R1, _family_actor(owner, SPORE)))
		var mode_before := _state_fingerprint(owner)
		var mode_rejected: Dictionary = owner.prepare_unit_card_intent_v06(_upgrade_intent(owner, world, "tx-%s-r3" % mode, ACTOR_A, SPORE_R1, _family_actor(owner, SPORE)))
		_expect(str(mode_rejected.get("reason_code", "")) == "monster_target_owner_rank_cap_exceeded" and mode_before == _state_fingerprint(owner), "%s provider binding falls back to base without elevation" % mode)
		_cleanup(fixture)


func _verify_official_gradients_and_second_slot() -> void:
	var expected_primary := {"org_i": 3, "org_ii": 4, "org_iii": 4, "org_iv": 4}
	var rows := {"org_i": [1, 3, 0], "org_ii": [1, 4, 0], "org_iii": [2, 4, 2], "org_iv": [2, 4, 4]}
	for label in rows.keys():
		var fixture := _fixture(true)
		var owner: MonsterRuntimeController = fixture.owner
		var world: FixtureWorld = fixture.world
		world.cap_rows[ACTOR_A] = (rows.get(label) as Array).duplicate()
		_finalize_card(owner, _starter_intent(owner, world, "tx-%s-start" % label, ACTOR_A, SPORE_R1))
		while int(_family_actor(owner, SPORE).get("rank", 0)) < int(expected_primary.get(label, 2)):
			var rank_now := int(_family_actor(owner, SPORE).get("rank", 0))
			_finalize_card(owner, _upgrade_intent(owner, world, "tx-%s-primary-%d" % [label, rank_now], ACTOR_A, SPORE_R1, _family_actor(owner, SPORE)))
		_expect(int(_family_actor(owner, SPORE).get("rank", 0)) == int(expected_primary.get(label, 0)), "%s grants its official primary rank ceiling" % label)
		var second: Dictionary = owner.prepare_unit_card_intent_v06(_summon_intent(owner, world, "tx-%s-second" % label, ACTOR_A, _card_id(METEOR, 1)))
		if label in ["org_i", "org_ii"]:
			_expect(str(second.get("reason_code", "")) == "monster_binding_count_limit_reached", "%s keeps one-monster count limit" % label)
		else:
			var committed := owner.commit_unit_card_intent_v06(second)
			owner.finalize_unit_card_intent_v06(committed)
			var secondary_limit := 2 if label == "org_iii" else 4
			while int(_family_actor(owner, METEOR).get("rank", 0)) < secondary_limit:
				var rank_now := int(_family_actor(owner, METEOR).get("rank", 0))
				_finalize_card(owner, _upgrade_intent(owner, world, "tx-%s-secondary-%d" % [label, rank_now], ACTOR_A, _card_id(METEOR, 1), _family_actor(owner, METEOR)))
			_expect(int(_family_actor(owner, METEOR).get("rank", 0)) == secondary_limit, "%s grants the official secondary rank ceiling" % label)
			if label == "org_iii":
				var blocked: Dictionary = owner.prepare_unit_card_intent_v06(_upgrade_intent(owner, world, "tx-org-iii-secondary-block", ACTOR_A, _card_id(METEOR, 1), _family_actor(owner, METEOR)))
				_expect(str(blocked.get("reason_code", "")) == "monster_target_owner_rank_cap_exceeded", "organization III secondary slot stops at Rank II")
		_cleanup(fixture)


func _verify_target_owner_cap_and_commit_revalidation() -> void:
	var fixture := _fixture(true)
	var owner: MonsterRuntimeController = fixture.owner
	var world: FixtureWorld = fixture.world
	world.cap_rows[ACTOR_A] = [1, 3, 0]
	world.cap_rows[ACTOR_B] = [2, 4, 4]
	_finalize_card(owner, _starter_intent(owner, world, "tx-target-a", ACTOR_A, SPORE_R1))
	_finalize_card(owner, _starter_intent(owner, world, "tx-target-b", ACTOR_B, SAND_R1))
	_finalize_card(owner, _upgrade_intent(owner, world, "tx-rival-r2", ACTOR_B, SPORE_R1, _family_actor(owner, SPORE)))
	_finalize_card(owner, _upgrade_intent(owner, world, "tx-rival-r3", ACTOR_B, SPORE_R1, _family_actor(owner, SPORE)))
	var target := _family_actor(owner, SPORE)
	var rejected: Dictionary = owner.prepare_unit_card_intent_v06(_upgrade_intent(owner, world, "tx-rival-r4", ACTOR_B, SPORE_R1, target))
	_expect(str(rejected.get("reason_code", "")) == "monster_target_owner_rank_cap_exceeded" and str(target.get("owner_actor_id_v06", "")) == ACTOR_A, "rival reinforcement uses target owner cap and preserves owner")

	world.cap_rows[ACTOR_A] = [1, 4, 0]
	world.cap_revisions[ACTOR_A] = 40
	var prepared: Dictionary = owner.prepare_unit_card_intent_v06(_upgrade_intent(owner, world, "tx-cap-change", ACTOR_B, SPORE_R1, _family_actor(owner, SPORE)))
	var before_commit := _state_fingerprint(owner)
	world.cap_revisions[ACTOR_A] = 41
	world.window_revision += 1
	var failed_commit: Dictionary = owner.commit_unit_card_intent_v06(prepared)
	_expect(str(failed_commit.get("reason_code", "")) == "monster_binding_capability_changed" and before_commit == _state_fingerprint(owner), "prepare binds provider revision/window and commit change is zero mutation")
	_cleanup(fixture)


func _verify_cap_downshift_save_load_and_privacy() -> void:
	var fixture := _fixture(true)
	var owner: MonsterRuntimeController = fixture.owner
	var world: FixtureWorld = fixture.world
	world.cap_rows[ACTOR_A] = [2, 4, 4]
	_finalize_card(owner, _starter_intent(owner, world, "tx-save-start", ACTOR_A, SPORE_R1))
	_finalize_card(owner, _upgrade_intent(owner, world, "tx-save-primary-r2", ACTOR_A, SPORE_R1, _family_actor(owner, SPORE)))
	_finalize_card(owner, _upgrade_intent(owner, world, "tx-save-primary-r3", ACTOR_A, SPORE_R1, _family_actor(owner, SPORE)))
	_finalize_card(owner, _summon_intent(owner, world, "tx-save-second", ACTOR_A, _card_id(METEOR, 1)))
	var saved := owner.unit_card_save_data_v06("monster")
	var saved_text := JSON.stringify(saved)
	_expect(not saved_text.contains("controlled_monster_count_limit") and not saved_text.contains("primary_monster_rank_limit"), "save data does not persist an external cap snapshot")

	world.cap_rows[ACTOR_A] = [1, 2, 0]
	world.cap_revisions[ACTOR_A] = 50
	var downshifted: Dictionary = owner.monster_private_snapshot_v06(ACTOR_A)
	var down_units: Array = downshifted.get("owned_units", []) if downshifted.get("owned_units", []) is Array else []
	_expect(owner.roster_snapshot(true).size() == 2 and down_units.size() == 2 and bool((down_units[0] as Dictionary).get("suspended_for_new_upgrade", false)) and bool((down_units[1] as Dictionary).get("suspended_for_new_upgrade", false)), "cap downshift preserves units and marks both ineligible for new upgrade")
	var down_before := _state_fingerprint(owner)
	var blocked: Dictionary = owner.prepare_unit_card_intent_v06(_upgrade_intent(owner, world, "tx-downshift-block", ACTOR_A, SPORE_R1, _family_actor(owner, SPORE)))
	_expect(str(blocked.get("reason_code", "")) == "monster_binding_cap_suspended_for_new_upgrade" and down_before == _state_fingerprint(owner), "downshifted unit rejects upgrade with zero mutation")

	var restored := _fixture(false)
	var restored_owner: MonsterRuntimeController = restored.owner
	var restored_world: FixtureWorld = restored.world
	var applied: Dictionary = restored_owner.apply_unit_card_save_data_v06(saved, "monster")
	var fallback_private: Dictionary = restored_owner.monster_private_snapshot_v06(ACTOR_A)
	var fallback_units: Array = fallback_private.get("owned_units", []) if fallback_private.get("owned_units", []) is Array else []
	_expect(bool(applied.get("applied", false)) and fallback_units.size() == 2 and bool((fallback_units[0] as Dictionary).get("suspended_for_new_upgrade", false)), "load re-evaluates missing provider as base instead of restoring cached organization cap")
	restored_world.cap_rows[ACTOR_A] = [2, 4, 4]
	restored_owner.configure_monster_binding_capability_provider_v06(restored_world)
	var restored_private: Dictionary = restored_owner.monster_private_snapshot_v06(ACTOR_A)
	var restored_units: Array = restored_private.get("owned_units", []) if restored_private.get("owned_units", []) is Array else []
	_expect(restored_units.size() == 2 and not bool((restored_units[0] as Dictionary).get("suspended_for_new_upgrade", true)) and not bool((restored_units[1] as Dictionary).get("suspended_for_new_upgrade", true)), "provider restoration dynamically clears suspension without roster mutation")
	var public_snapshot: Dictionary = restored_owner.unit_card_snapshot_v06("monster")
	var public_text := JSON.stringify(public_snapshot)
	_expect(not public_text.contains(ACTOR_A) and not public_text.contains("binding_cap") and not public_text.contains("organization") and _privacy_leaks(public_snapshot).is_empty(), "public snapshot leaks no organization cap binding or hidden owner")
	_cleanup(restored)
	_cleanup(fixture)


func _fixture(configure_provider: bool) -> Dictionary:
	var world := FixtureWorld.new()
	root.add_child(world)
	var bridge := WORLD_BRIDGE_SCRIPT.new() as MonsterRuntimeWorldBridge
	root.add_child(bridge)
	bridge.bind_world(world)
	var owner := CONTROLLER_SCRIPT.new() as MonsterRuntimeController
	root.add_child(owner)
	owner.set_world_bridge(bridge)
	if configure_provider:
		owner.configure_monster_binding_capability_provider_v06(world)
	return {"world": world, "bridge": bridge, "owner": owner}


func _cleanup(fixture: Dictionary) -> void:
	for key in ["owner", "bridge", "world"]:
		var node: Node = fixture.get(key)
		if node != null and is_instance_valid(node):
			node.free()


func _starter_intent(owner: MonsterRuntimeController, world: FixtureWorld, tx: String, actor_id: String, card_id: String) -> Dictionary:
	return _intent(owner, world, tx, actor_id, card_id, {
		"valid": true,
		"region_id": REGION_ID,
		"expected_region_revision": 7,
		"expected_binding_rule_revision": int(world.rule_revisions.get(actor_id, -1)),
	}, "starter.%s" % actor_id)


func _summon_intent(owner: MonsterRuntimeController, world: FixtureWorld, tx: String, actor_id: String, card_id: String) -> Dictionary:
	return _intent(owner, world, tx, actor_id, card_id, {
		"valid": true,
		"region_id": REGION_ID,
		"expected_region_revision": 7,
		"expected_binding_rule_revision": int(world.rule_revisions.get(actor_id, -1)),
	}, "instance.%s" % tx)


func _upgrade_intent(owner: MonsterRuntimeController, world: FixtureWorld, tx: String, actor_id: String, card_id: String, target: Dictionary, extra_fields: Dictionary = {}) -> Dictionary:
	var fields := _card_fields(card_id)
	fields.merge(extra_fields, true)
	return SCHEMA.make_intent(
		tx, actor_id, card_id, "instance.%s" % tx, EFFECT_KIND, ACTION_KIND,
		int(owner.unit_card_snapshot_v06("monster").get("owner_revision", 0)),
		{
			"valid": true,
			"unit_uid": int(target.get("uid", 0)),
			"expected_actor_revision": int(target.get("actor_revision_v06", 0)),
			"expected_binding_rule_revision": int(world.rule_revisions.get(actor_id, -1)),
		},
		fields,
		{"anonymous_play": true, "hidden_owner": true}
	)


func _intent(owner: MonsterRuntimeController, world: FixtureWorld, tx: String, actor_id: String, card_id: String, target: Dictionary, instance_id: String) -> Dictionary:
	return SCHEMA.make_intent(
		tx, actor_id, card_id, instance_id, EFFECT_KIND, ACTION_KIND,
		int(owner.unit_card_snapshot_v06("monster").get("owner_revision", 0)),
		target, _card_fields(card_id), {"anonymous_play": true, "hidden_owner": true}
	)


func _card_fields(card_id: String) -> Dictionary:
	var card: Dictionary = CATALOG.call("card_snapshot", card_id)
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	return (machine.get("effect_payload", {}) as Dictionary).duplicate(true) if machine.get("effect_payload", {}) is Dictionary else {}


func _card_id(family_id: String, rank: int) -> String:
	return "unit.monster.%s.rank_%d" % [family_id, rank]


func _finalize_card(owner: MonsterRuntimeController, intent: Dictionary) -> Dictionary:
	var prepared: Dictionary = owner.prepare_unit_card_intent_v06(intent)
	if not bool(prepared.get("prepared", false)):
		return prepared
	var committed: Dictionary = owner.commit_unit_card_intent_v06(prepared)
	if not bool(committed.get("committed", false)):
		return committed
	return owner.finalize_unit_card_intent_v06(committed)


func _family_actor(owner: MonsterRuntimeController, family_id: String) -> Dictionary:
	for actor_variant in owner.roster_snapshot(true):
		if actor_variant is Dictionary and str((actor_variant as Dictionary).get("monster_family_id", "")) == family_id:
			return (actor_variant as Dictionary).duplicate(true)
	return {}


func _state_fingerprint(owner: MonsterRuntimeController) -> String:
	return SCHEMA.fingerprint(owner.unit_card_save_data_v06("monster"))


func _privacy_leaks(value: Variant, path: String = "$") -> Array[String]:
	var leaks: Array[String] = []
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			for token in ["true_owner", "hidden_owner", "owner_truth", "owner_actor", "player_index", "ai_plan", "capability_fingerprint"]:
				if key.contains(token):
					leaks.append("%s.%s" % [path, str(key_variant)])
			leaks.append_array(_privacy_leaks((value as Dictionary).get(key_variant), "%s.%s" % [path, str(key_variant)]))
	elif value is Array:
		for index in range((value as Array).size()):
			leaks.append_array(_privacy_leaks((value as Array)[index], "%s[%d]" % [path, index]))
	return leaks


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("MONSTER_ORGANIZATION_BINDING_PROVIDER_V06_PASS checks=%d failures=0" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("MONSTER_ORGANIZATION_BINDING_PROVIDER_V06_FAIL %s" % failure)
	print("MONSTER_ORGANIZATION_BINDING_PROVIDER_V06_FAIL checks=%d failures=%d" % [_checks, _failures.size()])
	quit(1)
