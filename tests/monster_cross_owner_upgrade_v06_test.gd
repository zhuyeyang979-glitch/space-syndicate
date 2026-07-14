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
const SPORE_R1 := "unit.monster.spore_tide_emperor.rank_1"
const SAND_R1 := "unit.monster.sand_armor_rover.rank_1"
const EFFECT_KIND := "deploy_or_upgrade_monster"
const ACTION_KIND := "deploy_or_upgrade_monster"

var _checks := 0
var _failures: Array[String] = []


class FixtureWorld:
	extends Node

	var players := [
		{"actor_id": ACTOR_A, "cash": 111, "slots": ["PRIVATE-A"]},
		{"actor_id": ACTOR_B, "cash": 222, "slots": ["PRIVATE-B"], "ai_plan": "PRIVATE-PLAN"},
	]
	var districts := [{"name": "阿尔法区", "center": Vector2(80.0, 120.0)}]
	var game_time := 0.0
	var selected_player := 0
	var selected_district := 0
	var rng := RandomNumberGenerator.new()
	var rule_revisions := {ACTOR_A: 21, ACTOR_B: 22}
	var player_indices := {ACTOR_A: 0, ACTOR_B: 1}
	var starter_cards := {ACTOR_A: SPORE_R1, ACTOR_B: SAND_R1}
	var rank_caps: Dictionary = {}
	var side_effect_reservations: Dictionary = {}
	var skill_grants: Dictionary = {}
	var stage_calls := {"prepare": 0, "commit": 0, "rollback": 0, "finalize": 0}

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
			"allowed_monster_families": [SPORE, SAND],
			"world_position": {"x": 80.0, "y": 120.0},
		}

	func monster_deploy_profile_snapshot_v06(family_id: String, rank: int) -> Dictionary:
		if not [SPORE, SAND].has(family_id) or rank < 1 or rank > 4:
			return {"available": false, "authoritative": false, "reason_code": "fixture_profile_missing"}
		var base_hp := 40 if family_id == SPORE else 36
		return {
			"available": true,
			"authoritative": true,
			"revision": 100 + rank,
			"family_id": family_id,
			"rank": rank,
			"profile_id": "fixture.%s.rank_%d" % [family_id, rank],
			"name": "孢雾海皇" if family_id == SPORE else "砂铠陆行兽",
			"catalog_index": 0 if family_id == SPORE else 1,
			"hp": base_hp + rank * 8,
			"armor": rank - 1,
			"move_mps": 16.0 + rank,
			"initial_duration_seconds": 120.0 + rank * 10.0,
			"move_damage": rank,
			"collision_damage": rank + 1,
			"movement_traits": ["amphibious"] if family_id == SPORE else ["grounded"],
			"terrain_move_multiplier": {},
			"resource_drain": rank,
			"resource_focus": ["life"],
			"bound_skill_patch": {} if rank == 1 else {"grant_profile_id": "fixture.bound.%s.rank_%d" % [family_id, rank]},
			"economic_patch": {},
			"role_cash_patch": {},
		}

	func monster_deploy_rule_snapshot_v06(actor_id: String) -> Dictionary:
		if not player_indices.has(actor_id):
			return {"available": false, "authoritative": false, "reason_code": "fixture_actor_missing"}
		var result := {
			"available": true,
			"authoritative": true,
			"revision": int(rule_revisions.get(actor_id, -1)),
			"actor_id": actor_id,
			"player_index": int(player_indices.get(actor_id, -1)),
			"monster_binding_limit": 1,
			"starter_entitled": true,
			"starter_consumed": false,
			"starter_card_id": str(starter_cards.get(actor_id, "")),
			"starter_card_instance_id": "starter.%s" % actor_id,
		}
		if rank_caps.has(actor_id):
			result["primary_monster_rank_limit"] = int(rank_caps.get(actor_id, 2))
		return result

	func current_monster_binding_window_snapshot_v06() -> Dictionary:
		return {"available": true, "authoritative": true, "window_sequence": 4, "revision": 9}

	func monster_binding_caps(actor_id: String, window_sequence: int) -> Dictionary:
		if not player_indices.has(actor_id) or window_sequence != 4:
			return {"available": false, "authoritative": false, "reason_code": "fixture_cap_request_invalid"}
		var primary_limit := int(rank_caps.get(actor_id, 2))
		return {
			"available": true,
			"authoritative": true,
			"actor_id": actor_id,
			"window_sequence": window_sequence,
			"owner_revision": int(rule_revisions.get(actor_id, 0)),
			"capability_kind": "monster_caps",
			"controlled_monster_count_limit": 1,
			"primary_monster_rank_limit": primary_limit,
			"secondary_monster_rank_limit": 0,
		}

	func monster_binding_caps_for_target_owner(actor_id: String, window_sequence: int) -> Dictionary:
		return monster_binding_caps(actor_id, window_sequence)

	func monster_deploy_cross_owner_capabilities_v06() -> Dictionary:
		var result := {
			"contract_version": "v0.6",
			"region_facts": {"revisioned_snapshot": true, "owner_id": "fixture.region"},
			"monster_profile": {"revisioned_snapshot": true, "owner_id": "fixture.profile"},
			"binding_rule": {"revisioned_snapshot": true, "owner_id": "fixture.binding"},
		}
		for participant in ["bound_skill_inventory", "product_market_rng", "role_cash_ledger"]:
			result[participant] = {
				"owner_id": "fixture.%s" % participant,
				"prepare": true,
				"commit": true,
				"rollback": true,
				"finalize": true,
				"exact_once": true,
				"checkpoint": true,
				"save_load": true,
			}
		return result

	func prepare_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		stage_calls["prepare"] = int(stage_calls.get("prepare", 0)) + 1
		var tx := str(request.get("transaction_id", ""))
		side_effect_reservations[tx] = request.duplicate(true)
		return _stage_receipt("prepare", "prepared", request)

	func commit_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		stage_calls["commit"] = int(stage_calls.get("commit", 0)) + 1
		var tx := str(request.get("transaction_id", ""))
		if not side_effect_reservations.has(tx):
			return {"committed": false, "reason_code": "fixture_prepare_missing"}
		var plan: Dictionary = side_effect_reservations.get(tx, {})
		skill_grants[tx] = str(plan.get("bound_skill_recipient_actor_id", ""))
		return _stage_receipt("commit", "committed", request)

	func rollback_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		stage_calls["rollback"] = int(stage_calls.get("rollback", 0)) + 1
		var tx := str(request.get("transaction_id", ""))
		skill_grants.erase(tx)
		side_effect_reservations.erase(tx)
		return _stage_receipt("rollback", "rolled_back", request)

	func finalize_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		stage_calls["finalize"] = int(stage_calls.get("finalize", 0)) + 1
		return _stage_receipt("finalize", "finalized", request)

	func _stage_receipt(stage: String, success_key: String, request: Dictionary) -> Dictionary:
		return {
			success_key: true,
			"stage": stage,
			"reason_code": "fixture_%s_ok" % stage,
			"transaction_id": str(request.get("transaction_id", "")),
			"participant_binding_fingerprint": str(request.get("participant_binding_fingerprint", "")),
		}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_rival_upgrade_preserves_owner_and_routes_skill()
	_verify_starter_duplicate_private_reselect()
	_verify_rank_caps_and_forged_request_cap()
	_verify_rollback_replay_save_load_and_invalid_bindings()
	_verify_public_snapshot_privacy()
	_finish()


func _verify_rival_upgrade_preserves_owner_and_routes_skill() -> void:
	var fixture := _fixture()
	var owner: MonsterRuntimeController = fixture.owner
	var world: FixtureWorld = fixture.world
	_bootstrap_two_starters(owner, world)
	var target := _family_actor(owner, SPORE)
	var original_uid := int(target.get("uid", 0))
	var original_owner := str(target.get("owner_actor_id_v06", ""))
	var original_remaining := float(target.get("remaining_time", 0.0))
	var intent := _upgrade_intent(owner, world, "tx-rival-upgrade", ACTOR_B, SPORE_R1, target)
	var prepared: Dictionary = owner.prepare_unit_card_intent_v06(intent)
	_expect(bool(prepared.get("prepared", false)) and str(prepared.get("operation", "")) == "upgrade", "rival same-family upgrade prepares through authoritative owner")
	var plan: Dictionary = world.side_effect_reservations.get("tx-rival-upgrade", {})
	_expect(str(plan.get("actor_id", "")) == ACTOR_B and str(plan.get("bound_skill_recipient_actor_id", "")) == ACTOR_A, "acting player pays/plays while bound skill recipient remains current monster owner")
	var committed: Dictionary = owner.commit_unit_card_intent_v06(prepared)
	var finalized: Dictionary = owner.finalize_unit_card_intent_v06(committed)
	var upgraded := _family_actor(owner, SPORE)
	_expect(bool(finalized.get("finalized", false)) and int(upgraded.get("rank", 0)) == 2, "rank I monster upgrades to rank II")
	_expect(int(upgraded.get("uid", 0)) == original_uid and str(upgraded.get("owner_actor_id_v06", "")) == original_owner and int(upgraded.get("owner", -1)) == 0, "upgrade preserves UID, owner, control, and cash-damage attribution index")
	_expect(int(upgraded.get("hp", 0)) == int(upgraded.get("max_hp", -1)) and float(upgraded.get("remaining_time", 0.0)) == original_remaining + 60.0, "upgrade heals to full and adds 60 seconds without resetting elapsed time")
	_expect(str(world.skill_grants.get("tx-rival-upgrade", "")) == ACTOR_A, "bound skill side effect is committed only for existing owner")
	var actor_b_private: Dictionary = owner.monster_private_snapshot_v06(ACTOR_B)
	var actor_b_units: Array = actor_b_private.get("owned_units", []) if actor_b_private.get("owned_units", []) is Array else []
	_expect(actor_b_units.size() == 1 and str((actor_b_units[0] as Dictionary).get("family_id", "")) == SAND, "acting rival gains neither control nor an extra monster binding")
	_cleanup(fixture)


func _verify_starter_duplicate_private_reselect() -> void:
	var fixture := _fixture()
	var owner: MonsterRuntimeController = fixture.owner
	var world: FixtureWorld = fixture.world
	_finalize_card(owner, _starter_intent(owner, world, "tx-a-starter", ACTOR_A, SPORE_R1))
	world.starter_cards[ACTOR_B] = SPORE_R1
	var before := _business_fingerprint(owner)
	var rejected: Dictionary = owner.prepare_unit_card_intent_v06(_starter_intent(owner, world, "tx-b-duplicate-starter", ACTOR_B, SPORE_R1))
	var private_fields: Dictionary = rejected.get("private_fields", {}) if rejected.get("private_fields", {}) is Dictionary else {}
	var private_target: Dictionary = private_fields.get("private_target", {}) if private_fields.get("private_target", {}) is Dictionary else {}
	_expect(str(rejected.get("reason_code", "")) == "starter_monster_family_reserved" and not bool(rejected.get("prepared", true)) and not bool(rejected.get("card_consumed", true)), "duplicate starter returns private reselect and cannot consume card")
	_expect(bool(private_target.get("reselect_required", false)) and not JSON.stringify(rejected).contains(ACTOR_A), "reselect receipt exposes no existing owner identity")
	_expect(before == _business_fingerprint(owner) and owner.roster_snapshot(true).size() == 1, "starter collision has zero roster/UID/marker side effects")
	_cleanup(fixture)


func _verify_rank_caps_and_forged_request_cap() -> void:
	var base_fixture := _fixture()
	var base_owner: MonsterRuntimeController = base_fixture.owner
	var base_world: FixtureWorld = base_fixture.world
	_bootstrap_two_starters(base_owner, base_world)
	_finalize_card(base_owner, _upgrade_intent(base_owner, base_world, "tx-base-r2", ACTOR_B, SPORE_R1, _family_actor(base_owner, SPORE)))
	var forged := _upgrade_intent(base_owner, base_world, "tx-forged-cap", ACTOR_B, SPORE_R1, _family_actor(base_owner, SPORE), {"request_monster_rank_cap": 4})
	var before := _business_fingerprint(base_owner)
	var base_rejected: Dictionary = base_owner.prepare_unit_card_intent_v06(forged)
	_expect(str(base_rejected.get("reason_code", "")) == "monster_target_owner_rank_cap_exceeded" and before == _business_fingerprint(base_owner), "missing authoritative cap uses base Rank II and ignores forged request cap")
	_cleanup(base_fixture)

	var cap_three_fixture := _fixture()
	var cap_three_owner: MonsterRuntimeController = cap_three_fixture.owner
	var cap_three_world: FixtureWorld = cap_three_fixture.world
	cap_three_world.rank_caps[ACTOR_A] = 3
	_bootstrap_two_starters(cap_three_owner, cap_three_world)
	_finalize_card(cap_three_owner, _upgrade_intent(cap_three_owner, cap_three_world, "tx-cap3-r2", ACTOR_B, SPORE_R1, _family_actor(cap_three_owner, SPORE)))
	_finalize_card(cap_three_owner, _upgrade_intent(cap_three_owner, cap_three_world, "tx-cap3-r3", ACTOR_B, SPORE_R1, _family_actor(cap_three_owner, SPORE)))
	_expect(int(_family_actor(cap_three_owner, SPORE).get("rank", 0)) == 3, "authoritative Rank III cap permits cross-player reinforcement to III")
	var cap_three_reject: Dictionary = cap_three_owner.prepare_unit_card_intent_v06(_upgrade_intent(cap_three_owner, cap_three_world, "tx-cap3-r4-block", ACTOR_B, SPORE_R1, _family_actor(cap_three_owner, SPORE)))
	_expect(str(cap_three_reject.get("reason_code", "")) == "monster_target_owner_rank_cap_exceeded", "Rank III cap rejects III to IV")
	_cleanup(cap_three_fixture)

	var cap_four_fixture := _fixture()
	var cap_four_owner: MonsterRuntimeController = cap_four_fixture.owner
	var cap_four_world: FixtureWorld = cap_four_fixture.world
	cap_four_world.rank_caps[ACTOR_A] = 4
	_bootstrap_two_starters(cap_four_owner, cap_four_world)
	for index in range(3):
		_finalize_card(cap_four_owner, _upgrade_intent(cap_four_owner, cap_four_world, "tx-cap4-%d" % index, ACTOR_B, SPORE_R1, _family_actor(cap_four_owner, SPORE)))
	_expect(int(_family_actor(cap_four_owner, SPORE).get("rank", 0)) == 4, "authoritative Rank IV cap permits reinforcement to IV")
	_cleanup(cap_four_fixture)


func _verify_rollback_replay_save_load_and_invalid_bindings() -> void:
	var fixture := _fixture()
	var owner: MonsterRuntimeController = fixture.owner
	var world: FixtureWorld = fixture.world
	_bootstrap_two_starters(owner, world)
	var intent := _upgrade_intent(owner, world, "tx-rollback-upgrade", ACTOR_B, SPORE_R1, _family_actor(owner, SPORE))
	var prepared: Dictionary = owner.prepare_unit_card_intent_v06(intent)
	var committed: Dictionary = owner.commit_unit_card_intent_v06(prepared)
	var rolled_back: Dictionary = owner.rollback_unit_card_intent_v06(committed)
	_expect(bool(rolled_back.get("rolled_back", false)) and int(_family_actor(owner, SPORE).get("rank", 0)) == 1 and not world.skill_grants.has("tx-rollback-upgrade"), "rollback restores roster and compensates bound skill owner")
	var rollback_replay: Dictionary = owner.rollback_unit_card_intent_v06(committed)
	_expect(bool(rollback_replay.get("idempotent_replay", false)) and bool(rollback_replay.get("rolled_back", false)), "rollback replay is exact-once")

	var valid_target := _family_actor(owner, SPORE)
	var wrong_target := valid_target.duplicate(true)
	wrong_target["uid"] = int(valid_target.get("uid", 0)) + 999
	var before := _business_fingerprint(owner)
	var wrong_target_receipt: Dictionary = owner.prepare_unit_card_intent_v06(_upgrade_intent(owner, world, "tx-wrong-target", ACTOR_B, SPORE_R1, wrong_target))
	_expect(str(wrong_target_receipt.get("reason_code", "")) == "monster_upgrade_family_mismatch" and before == _business_fingerprint(owner), "wrong target UID has zero side effects")
	var wrong_actor_receipt: Dictionary = owner.prepare_unit_card_intent_v06(_upgrade_intent(owner, world, "tx-wrong-actor", "unknown.actor", SPORE_R1, valid_target))
	_expect(not bool(wrong_actor_receipt.get("prepared", true)) and before == _business_fingerprint(owner), "wrong actor has zero side effects")

	var final_intent := _upgrade_intent(owner, world, "tx-save-upgrade", ACTOR_B, SPORE_R1, valid_target)
	var final_receipt := _finalize_card(owner, final_intent)
	var saved := owner.unit_card_save_data_v06("monster")
	var restored_fixture := _fixture()
	var restored_owner: MonsterRuntimeController = restored_fixture.owner
	var applied: Dictionary = restored_owner.apply_unit_card_save_data_v06(saved, "monster")
	var replay: Dictionary = restored_owner.prepare_unit_card_intent_v06(final_intent)
	_expect(bool(applied.get("applied", false)) and bool(replay.get("idempotent_replay", false)) and bool(replay.get("finalized", false)), "save/load preserves terminal upgrade journal and replay")
	_expect(int(_family_actor(restored_owner, SPORE).get("rank", 0)) == 2 and str(_family_actor(restored_owner, SPORE).get("owner_actor_id_v06", "")) == ACTOR_A, "save/load preserves upgraded rank and original hidden owner")
	var conflicting := SCHEMA.make_intent(
		str(final_intent.get("transaction_id", "")),
		ACTOR_B,
		SPORE_R1,
		"forged.instance",
		EFFECT_KIND,
		ACTION_KIND,
		int(final_intent.get("expected_owner_revision", -1)),
		(final_intent.get("target_context", {}) as Dictionary).duplicate(true),
		(final_intent.get("effect_fields", {}) as Dictionary).duplicate(true),
		{"anonymous_play": true, "hidden_owner": true}
	)
	var conflict_receipt: Dictionary = restored_owner.prepare_unit_card_intent_v06(conflicting)
	_expect(str(conflict_receipt.get("reason_code", "")) == "monster_transaction_binding_conflict", "same transaction with wrong instance is rejected")
	_expect(bool(final_receipt.get("finalized", false)), "original upgrade finalized before checkpoint")
	_cleanup(restored_fixture)
	_cleanup(fixture)


func _verify_public_snapshot_privacy() -> void:
	var fixture := _fixture()
	var owner: MonsterRuntimeController = fixture.owner
	var world: FixtureWorld = fixture.world
	_bootstrap_two_starters(owner, world)
	_finalize_card(owner, _upgrade_intent(owner, world, "tx-privacy-upgrade", ACTOR_B, SPORE_R1, _family_actor(owner, SPORE)))
	var public_snapshot: Dictionary = owner.unit_card_snapshot_v06("monster")
	var encoded := JSON.stringify(public_snapshot)
	_expect(not encoded.contains(ACTOR_A) and not encoded.contains(ACTOR_B) and not encoded.contains("PRIVATE"), "public snapshot omits true owner and opponent private fields")
	_expect(_privacy_leaks(public_snapshot).is_empty(), "recursive public snapshot privacy scan is zero")
	_cleanup(fixture)


func _fixture() -> Dictionary:
	var world := FixtureWorld.new()
	root.add_child(world)
	var bridge := WORLD_BRIDGE_SCRIPT.new() as MonsterRuntimeWorldBridge
	root.add_child(bridge)
	bridge.bind_world(world)
	var owner := CONTROLLER_SCRIPT.new() as MonsterRuntimeController
	root.add_child(owner)
	owner.set_world_bridge(bridge)
	owner.configure_monster_binding_capability_provider_v06(world)
	return {"world": world, "bridge": bridge, "owner": owner}


func _cleanup(fixture: Dictionary) -> void:
	for key in ["owner", "bridge", "world"]:
		var node: Node = fixture.get(key)
		if node != null and is_instance_valid(node):
			node.free()


func _bootstrap_two_starters(owner: MonsterRuntimeController, world: FixtureWorld) -> void:
	_finalize_card(owner, _starter_intent(owner, world, "tx-starter-a", ACTOR_A, SPORE_R1))
	_finalize_card(owner, _starter_intent(owner, world, "tx-starter-b", ACTOR_B, SAND_R1))


func _starter_intent(owner: MonsterRuntimeController, world: FixtureWorld, tx: String, actor_id: String, card_id: String) -> Dictionary:
	return SCHEMA.make_intent(
		tx,
		actor_id,
		card_id,
		"starter.%s" % actor_id,
		EFFECT_KIND,
		ACTION_KIND,
		int(owner.unit_card_snapshot_v06("monster").get("owner_revision", 0)),
		{"valid": true, "region_id": REGION_ID, "expected_region_revision": 7, "expected_binding_rule_revision": int(world.rule_revisions.get(actor_id, -1))},
		_card_fields(card_id),
		{"anonymous_play": true, "hidden_owner": true}
	)


func _upgrade_intent(owner: MonsterRuntimeController, world: FixtureWorld, tx: String, actor_id: String, card_id: String, target_actor: Dictionary, extra_fields: Dictionary = {}) -> Dictionary:
	var fields := _card_fields(card_id)
	fields.merge(extra_fields, true)
	return SCHEMA.make_intent(
		tx,
		actor_id,
		card_id,
		"instance.%s" % tx,
		EFFECT_KIND,
		ACTION_KIND,
		int(owner.unit_card_snapshot_v06("monster").get("owner_revision", 0)),
		{
			"valid": true,
			"unit_uid": int(target_actor.get("uid", 0)),
			"expected_actor_revision": int(target_actor.get("actor_revision_v06", 0)),
			"expected_binding_rule_revision": int(world.rule_revisions.get(actor_id, -1)),
		},
		fields,
		{"anonymous_play": true, "hidden_owner": true}
	)


func _card_fields(card_id: String) -> Dictionary:
	var card: Dictionary = CATALOG.call("card_snapshot", card_id)
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	return (machine.get("effect_payload", {}) as Dictionary).duplicate(true) if machine.get("effect_payload", {}) is Dictionary else {}


func _finalize_card(owner: MonsterRuntimeController, intent: Dictionary) -> Dictionary:
	var prepared: Dictionary = owner.prepare_unit_card_intent_v06(intent)
	var committed: Dictionary = owner.commit_unit_card_intent_v06(prepared)
	return owner.finalize_unit_card_intent_v06(committed)


func _family_actor(owner: MonsterRuntimeController, family_id: String) -> Dictionary:
	for actor_variant in owner.roster_snapshot(true):
		if actor_variant is Dictionary and str((actor_variant as Dictionary).get("monster_family_id", "")) == family_id:
			return (actor_variant as Dictionary).duplicate(true)
	return {}


func _business_fingerprint(owner: MonsterRuntimeController) -> String:
	return SCHEMA.fingerprint(owner.unit_card_save_data_v06("monster"))


func _privacy_leaks(value: Variant, path: String = "$") -> Array[String]:
	var leaks: Array[String] = []
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			for token in ["true_owner", "hidden_owner", "owner_truth", "owner_actor", "player_index", "cash", "hand", "ai_plan", "private"]:
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
		print("MONSTER_CROSS_OWNER_UPGRADE_V06_PASS checks=%d failures=0" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("MONSTER_CROSS_OWNER_UPGRADE_V06_FAIL %s" % failure)
	print("MONSTER_CROSS_OWNER_UPGRADE_V06_FAIL checks=%d failures=%d" % [_checks, _failures.size()])
	quit(1)
