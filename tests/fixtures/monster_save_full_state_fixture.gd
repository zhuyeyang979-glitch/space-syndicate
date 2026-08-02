extends RefCounted
class_name MonsterSaveFullStateFixture

const SCHEMA := preload("res://scripts/cards/v06/units/unit_card_runtime_schema_v06.gd")
const CONTROLLER_SCRIPT := preload("res://scripts/runtime/monster_runtime_controller.gd")
const WORLD_BRIDGE_SCRIPT := preload("res://scripts/runtime/monster_runtime_world_bridge.gd")
const WORLD_STATE_SCRIPT := preload("res://scripts/runtime/world_session_state.gd")
const RNG_SERVICE_SCRIPT := preload("res://scripts/runtime/run_rng_service.gd")
const BATTLE_LIFECYCLE_POLICY := preload("res://scripts/runtime/monster_battle_lifecycle_policy_v06.gd")

const CARD_RANK_1 := "unit.monster.spore_tide_emperor.rank_1"
const FAMILY_ID := "spore_tide_emperor"
const EFFECT_KIND := "deploy_or_upgrade_monster"
const ACTION_KIND := "deploy_or_upgrade_monster"
const HUMAN_ACTOR := "human.alpha"
const AI_ACTOR := "ai.beta"
const REGION_ID := "region.alpha"


class FixtureWorld:
	extends Node

	var region_revision := 17
	var profile_revision := 23
	var rule_revisions := {HUMAN_ACTOR: 31, AI_ACTOR: 37}
	var player_indices := {HUMAN_ACTOR: 0, AI_ACTOR: 1}
	var presentation_events: Array = []
	var economic_events: Array = []
	var cash_snapshots: Array = []
	var public_log_revision := 5
	var private_feedback_revision := 7
	var presentation_revision := 11
	var bound_owner: Node

	func monster_deploy_region_snapshot_v06(region_id: String) -> Dictionary:
		if region_id != REGION_ID:
			return {"available": false, "authoritative": false, "region_id": region_id, "reason_code": "fixture_region_missing"}
		return {
			"available": true,
			"authoritative": true,
			"region_id": REGION_ID,
			"display_name": "Alpha Region",
			"revision": region_revision,
			"region_index": 0,
			"destroyed": false,
			"starter_summon_allowed": true,
			"allowed_monster_families": [FAMILY_ID],
			"world_position": {"x": 120.125, "y": 240.375},
		}

	func monster_deploy_profile_snapshot_v06(family_id: String, rank: int) -> Dictionary:
		if family_id != FAMILY_ID or rank not in [1, 2]:
			return {
				"available": false,
				"authoritative": false,
				"family_id": family_id,
				"rank": rank,
				"reason_code": "fixture_profile_missing",
			}
		return {
			"available": true,
			"authoritative": true,
			"family_id": FAMILY_ID,
			"rank": rank,
			"revision": profile_revision + rank,
			"profile_id": "monster.profile.spore_tide_emperor.rank_%d" % rank,
			"name": "Spore Tide Emperor",
			"catalog_index": 0,
			"hp": 42 + (rank - 1) * 8,
			"move_mps": 18.5 + float(rank - 1) * 1.125,
			"initial_duration_seconds": 137.0 + float(rank - 1) * 23.25,
			"move_damage": 2 + rank - 1,
			"collision_damage": 3 + rank - 1,
			"movement_traits": ["amphibious"],
			"terrain_move_multiplier": {"ocean": 1.25, "city": 0.875},
			"resource_drain": 2,
			"resource_focus": ["life"],
			"starter_play_free": rank == 1,
			"is_starter": rank == 1,
		}

	func monster_deploy_rule_snapshot_v06(actor_id: String) -> Dictionary:
		if not player_indices.has(actor_id):
			return {"available": false, "authoritative": false, "actor_id": actor_id, "reason_code": "fixture_actor_missing"}
		return {
			"available": true,
			"authoritative": true,
			"actor_id": actor_id,
			"player_index": int(player_indices.get(actor_id, -1)),
			"revision": int(rule_revisions.get(actor_id, -1)),
			"starter_entitled": true,
			"starter_consumed": false,
			"first_summon_state": "not_summoned",
			"starter_card_id": CARD_RANK_1,
			"monster_binding_limit": 1,
		}

	func monster_deploy_cross_owner_capabilities_v06() -> Dictionary:
		var result := {
			"contract_version": "v0.6",
			"region_facts": {"revisioned_snapshot": true, "owner_id": "fixture.region"},
			"monster_profile": {"revisioned_snapshot": true, "owner_id": "fixture.profile"},
			"binding_rule": {"revisioned_snapshot": true, "owner_id": "fixture.binding"},
		}
		for participant_name in ["bound_skill_inventory", "product_market_rng", "role_cash_ledger"]:
			result[participant_name] = {
				"owner_id": "fixture.%s" % participant_name,
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
		return _stage_receipt("prepare", "prepared", request)

	func commit_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		return _stage_receipt("commit", "committed", request)

	func rollback_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		return _stage_receipt("rollback", "rolled_back", request)

	func finalize_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		return _stage_receipt("finalize", "finalized", request)

	func _stage_receipt(stage: String, success_key: String, request: Dictionary) -> Dictionary:
		return {
			"transaction_id": str(request.get("transaction_id", "")),
			"participant_binding_fingerprint": str(request.get("participant_binding_fingerprint", "")),
			"stage": stage,
			"reason_code": "fixture_%s_ok" % stage,
			success_key: true,
		}

	func _on_monster_runtime_event(event: Dictionary) -> Dictionary:
		presentation_events.append(event.duplicate(true))
		presentation_revision += 1
		return {"accepted": true, "event_id": str(event.get("event_id", ""))}

	func _entity_world_position(entity: Dictionary) -> Vector2:
		var value: Variant = entity.get("world_position", Vector2.ZERO)
		return value if value is Vector2 else Vector2.ZERO

	func _player_name(player_index: int) -> String:
		return "Player %d" % player_index

	func _limited_name_list(names: Array, limit: int = 6, empty_text: String = "none") -> String:
		if names.is_empty():
			return empty_text
		return ", ".join(names.slice(0, mini(limit, names.size())))

	func _record_player_economic_event(player_index: int, kind: String, label: String, amount: int, detail: String = "") -> void:
		economic_events.append({"player_index": player_index, "kind": kind, "label": label, "amount": amount, "detail": detail})

	func _record_player_cash_snapshot(player_index: int) -> void:
		cash_snapshots.append(player_index)


static func create(tree: SceneTree) -> Dictionary:
	var host := Node.new()
	host.name = "MonsterSaveFullStateFixture"
	tree.root.add_child(host)
	var world_state = WORLD_STATE_SCRIPT.new()
	world_state.name = "WorldSessionState"
	host.add_child(world_state)
	world_state.players = [
		{"id": "player-0", "actor_id": HUMAN_ACTOR, "name": "Player 0", "cash": 1000, "cash_cents": 100000, "eliminated": false, "is_ai": false},
		{"id": "player-1", "actor_id": AI_ACTOR, "name": "Player 1", "cash": 900, "cash_cents": 90000, "eliminated": false, "is_ai": true},
	]
	world_state.districts = [{"name": "Alpha Region", "center": Vector2(120.125, 240.375)}]
	world_state.game_time = 33.875
	var world := FixtureWorld.new()
	world.name = "FixtureWorld"
	host.add_child(world)
	var bridge = WORLD_BRIDGE_SCRIPT.new()
	bridge.name = "MonsterRuntimeWorldBridge"
	bridge.bind_world(world)
	bridge.call("set_world_session_state", world_state)
	var rng = RNG_SERVICE_SCRIPT.new()
	rng.name = "RunRngService"
	rng.set_seed(900626424)
	host.add_child(rng)
	bridge.call("set_rng_service", rng)
	host.add_child(bridge)
	var owner = CONTROLLER_SCRIPT.new()
	owner.name = "MonsterRuntimeController"
	owner.call("set_world_bridge", bridge)
	host.add_child(owner)
	world.bound_owner = owner
	return {"host": host, "world_state": world_state, "world": world, "rng": rng, "bridge": bridge, "owner": owner}


static func cleanup(fixture: Dictionary) -> void:
	var host: Node = fixture.get("host")
	if host != null and is_instance_valid(host):
		host.queue_free()


static func build_nontrivial_state(fixture: Dictionary) -> Dictionary:
	var owner = fixture.get("owner")
	var world = fixture.get("world")
	var deploy_intent := _starter_intent(owner, world, "tx-characterize-deploy")
	var deploy_prepared: Dictionary = owner.call("prepare_unit_card_intent_v06", deploy_intent)
	var deploy_committed: Dictionary = owner.call("commit_unit_card_intent_v06", deploy_prepared)
	var deploy_finalized: Dictionary = owner.call("finalize_unit_card_intent_v06", deploy_committed)
	if not bool(deploy_finalized.get("finalized", false)):
		return {"ok": false, "reason_code": "characterization_deploy_failed", "receipt": deploy_finalized}

	var first_actor := (owner.auto_monsters[0] as Dictionary).duplicate(true)
	first_actor["world_position"] = Vector2(123.125, 241.75)
	first_actor["linear_move_target_position"] = Vector2(287.625, 91.5)
	first_actor["linear_move_speed_mps"] = 19.375
	first_actor["linear_move_started_at"] = 33.875
	first_actor["remaining_time"] = 91.625
	first_actor["last_owner_damage_time"] = 31.125
	first_actor["revive_available"] = true
	first_actor["revive_timer"] = 7.75
	owner.auto_monsters[0] = first_actor

	var second_actor := first_actor.duplicate(true)
	second_actor["uid"] = 2
	second_actor["slot"] = 1
	second_actor["monster_family_id"] = "fixture_recovery_monster"
	second_actor["name"] = "Recovery Sentinel"
	second_actor["owner"] = 1
	second_actor["owner_actor_id_v06"] = AI_ACTOR
	second_actor["world_position"] = Vector2(512.875, 418.0625)
	second_actor["linear_move_target_position"] = Vector2(480.25, 377.875)
	second_actor["down"] = true
	second_actor["hp"] = 0
	second_actor["revive_available"] = true
	second_actor["revive_timer"] = 5.125
	owner.auto_monsters.append(second_actor)
	owner.next_auto_monster_uid = 3
	owner.next_special_monster_slot = 1
	owner.selected_auto_monster_slot = 0
	owner.monster_timer = 2.375
	owner.special_monster_timer = 3.8125
	owner.set("_autonomous_move_sequence", 11)
	owner.auto_monster_action_sequence = 13

	var bankruptcy_prepare: Dictionary = owner.call("bankruptcy_estate_stage", "prepare", {
		"transaction_id": "tx-characterize-bankruptcy",
		"player_indices": [1],
	})
	if not bool(bankruptcy_prepare.get("prepared", false)):
		return {"ok": false, "reason_code": "characterization_bankruptcy_prepare_failed", "receipt": bankruptcy_prepare}

	var actor_for_upgrade := owner.auto_monsters[0] as Dictionary
	var upgrade_target := {
		"valid": true,
		"unit_uid": int(actor_for_upgrade.get("uid", 0)),
		"expected_actor_revision": int(actor_for_upgrade.get("actor_revision_v06", 0)),
		"expected_binding_rule_revision": int(world.rule_revisions.get(HUMAN_ACTOR, -1)),
	}
	var upgrade_intent := SCHEMA.make_intent(
		"tx-characterize-upgrade",
		HUMAN_ACTOR,
		CARD_RANK_1,
		"instance.tx-characterize-upgrade",
		EFFECT_KIND,
		ACTION_KIND,
		int(owner.unit_card_snapshot_v06("monster").get("owner_revision", -1)),
		upgrade_target,
		_monster_fields(1),
		{"anonymous_play": true, "hidden_owner": true}
	)
	var upgrade_prepared: Dictionary = owner.call("prepare_unit_card_intent_v06", upgrade_intent)
	if not bool(upgrade_prepared.get("prepared", false)):
		return {"ok": false, "reason_code": "characterization_upgrade_prepare_failed", "receipt": upgrade_prepared}

	_seed_wager(owner, 60, 6, [0, 1], {"0": 1000, "1": 900}, 9, 4, [900, 901])
	owner.submit_monster_wager_response(60, 0, &"a", 5)
	owner.submit_monster_wager_response(60, 1, &"b", 5)
	owner.tick_battle_lifecycles(0.0)
	if owner.resolved_monster_wager_history.is_empty():
		return {"ok": false, "reason_code": "characterization_resolved_wager_missing"}

	_seed_wager(owner, 70, 8, [0, 1], {"0": 1000, "1": 900}, 3, 7, [1, 2])
	var active := owner.active_monster_wagers[0] as Dictionary
	active["started_at"] = 33.875
	active["bets"] = {
		"0": {"player_index": 0, "side": "a", "stake": 50, "stake_percent": 5, "forced": false, "last_time": 34.125},
	}
	active["public_bets"] = [
		{"player_index": 0, "side": "a", "stake": 50, "stake_percent": 5, "forced": false, "time": 34.125},
	]
	owner.active_monster_wagers[0] = active
	owner.monster_wager_sequence = 70
	owner.set("_monster_wager_settlement_revision", 8)

	return {
		"ok": true,
		"save": owner.to_save_data(),
		"pre_edit_omitted_runtime_state": {
			"autonomous_move_sequence": int(owner.get("_autonomous_move_sequence")),
			"auto_monster_action_sequence": owner.auto_monster_action_sequence,
			"bankruptcy_estate_journal": (owner.get("_bankruptcy_estate_journal") as Dictionary).duplicate(true),
		},
		"deploy_finalized": deploy_finalized,
		"upgrade_prepared": upgrade_prepared,
		"bankruptcy_prepared": bankruptcy_prepare,
	}


static func _starter_intent(owner, world, transaction_id: String) -> Dictionary:
	return SCHEMA.make_intent(
		transaction_id,
		HUMAN_ACTOR,
		CARD_RANK_1,
		"instance.%s" % transaction_id,
		EFFECT_KIND,
		ACTION_KIND,
		int(owner.unit_card_snapshot_v06("monster").get("owner_revision", 0)),
		{
			"valid": true,
			"region_id": REGION_ID,
			"expected_region_revision": world.region_revision,
			"expected_binding_rule_revision": int(world.rule_revisions.get(HUMAN_ACTOR, -1)),
		},
		_monster_fields(1),
		{"anonymous_play": true, "hidden_owner": true}
	)


static func _monster_fields(rank: int) -> Dictionary:
	return {
		"monster_family_id": FAMILY_ID,
		"card_rank": rank,
		"same_name_upgrade_extend_seconds": 60,
		"refresh_total_presence_time": false,
		"presence_time_policy": "add_to_remaining_time",
		"heal_to_full_on_upgrade": true,
		"rank4_repeat_behavior": "heal_to_full_and_extend_60_seconds",
		"upgrade_target_same_family_any_owner": true,
		"ownership_transfer_on_upgrade": false,
		"bound_skill_recipient": "existing_monster_owner",
		"starter_conflict_policy": "private_reselect",
		"upgrade_respects_target_owner_rank_cap": true,
		"unit_profile_owns_stats": true,
	}


static func _seed_wager(
	owner,
	wager_id: int,
	revision: int,
	eligible: Array,
	opening_cash: Dictionary,
	damage_a: int,
	damage_b: int,
	uids: Array
) -> void:
	var public_ids: Dictionary = {}
	for player_index_variant: Variant in eligible:
		public_ids[str(int(player_index_variant))] = "player.%d" % int(player_index_variant)
	var competitors := [
		{"side": "a", "name": "Monster A", "slot": 0, "uid": int(uids[0]), "damage": damage_a},
		{"side": "b", "name": "Monster B", "slot": 1, "uid": int(uids[1]), "damage": damage_b},
	]
	var entry := {
		"wager_id": wager_id,
		"settlement_revision": revision,
		"base_percent": 5,
		"competitors": competitors,
		"damage_a": damage_a,
		"damage_b": damage_b,
		"bets": {},
		"public_bets": [],
		"historical_public_pool": 17,
		"eligible_player_indices": eligible.duplicate(true),
		"opening_cash_units_by_player": opening_cash.duplicate(true),
		"public_player_ids_by_index": public_ids,
		"decision_open": true,
		"context": "full state characterization",
		"resolved": false,
	}
	entry.merge(BATTLE_LIFECYCLE_POLICY.initial_state(competitors, 60.0, 15.0, {}), true)
	owner.active_monster_wagers = [entry]
	owner.monster_wager_sequence = maxi(owner.monster_wager_sequence, wager_id)
	owner.set("_monster_wager_settlement_revision", maxi(int(owner.get("_monster_wager_settlement_revision")), revision))
	owner.public_card_bid_monster_wager_pool = 0
