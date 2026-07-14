extends SceneTree

const SCHEMA := preload("res://scripts/cards/v06/units/unit_card_runtime_schema_v06.gd")
const CONTROLLER_SCRIPT := preload("res://scripts/runtime/monster_runtime_controller.gd")
const WORLD_BRIDGE_SCRIPT := preload("res://scripts/runtime/monster_runtime_world_bridge.gd")

const CARD_RANK_1 := "unit.monster.spore_tide_emperor.rank_1"
const CARD_RANK_2 := "unit.monster.spore_tide_emperor.rank_2"
const FAMILY_ID := "spore_tide_emperor"
const EFFECT_KIND := "deploy_or_upgrade_monster"
const ACTION_KIND := "deploy_or_upgrade_monster"
const HUMAN_ACTOR := "human.alpha"
const AI_ACTOR := "ai.beta"
const REGION_ID := "region.alpha"
const SAVE_KEYS := [
	"monster_card_atomic_schema_version",
	"monster_card_atomic_owner_revision",
	"monster_card_atomic_starter_state",
	"monster_card_atomic_reservations",
	"monster_card_atomic_terminal_journal",
	"monster_card_atomic_presentation_journal",
]

var _checks := 0
var _failures: Array[String] = []


class FixtureWorld:
	extends Node

	var players: Array = [
		{"actor_id": HUMAN_ACTOR, "cash": 123, "slots": ["PRIVATE-HUMAN-CARD"]},
		{"actor_id": AI_ACTOR, "cash": 987, "slots": ["PRIVATE-AI-CARD"], "ai_plan": "PRIVATE-AI-PLAN"},
	]
	var districts: Array = [{"name": "阿尔法区", "center": Vector2(120.0, 240.0)}]
	var game_time := 0.0
	var selected_player := 0
	var selected_district := 0
	var rng := RandomNumberGenerator.new()

	var region_revision := 17
	var profile_revision := 23
	var rule_revisions := {HUMAN_ACTOR: 31, AI_ACTOR: 37}
	var player_indices := {HUMAN_ACTOR: 0, AI_ACTOR: 1}
	var binding_limits := {HUMAN_ACTOR: 1, AI_ACTOR: 1}
	var region_destroyed := false
	var region_summon_allowed := true
	var disabled_capability := ""
	var failed_stages: Dictionary = {}
	var stage_calls := {"prepare": 0, "commit": 0, "rollback": 0, "finalize": 0}
	var presentation_events: Array = []
	var snapshot_calls := {"region": 0, "profile": 0, "rule": 0}
	var recursive_rule_private_lookup := false
	var bound_owner: Node

	func _init() -> void:
		rng.seed = 60611

	func monster_deploy_region_snapshot_v06(region_id: String) -> Dictionary:
		snapshot_calls["region"] = int(snapshot_calls.get("region", 0)) + 1
		if region_id != REGION_ID:
			return {
				"available": false,
				"authoritative": false,
				"region_id": region_id,
				"reason_code": "fixture_region_missing",
			}
		return {
			"available": true,
			"authoritative": true,
			"region_id": REGION_ID,
			"display_name": "阿尔法区",
			"revision": region_revision,
			"region_index": 0,
			"destroyed": region_destroyed,
			"starter_summon_allowed": region_summon_allowed,
			"allowed_monster_families": [FAMILY_ID],
			"world_position": {"x": 120.0, "y": 240.0},
		}

	func monster_deploy_profile_snapshot_v06(family_id: String, rank: int) -> Dictionary:
		snapshot_calls["profile"] = int(snapshot_calls.get("profile", 0)) + 1
		if family_id != FAMILY_ID or rank != 1:
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
			"rank": 1,
			"revision": profile_revision,
			"profile_id": "monster.profile.spore_tide_emperor.rank_1",
			"name": "孢雾海皇",
			"catalog_index": 0,
			"hp": 42,
			"move_mps": 18.5,
			"initial_duration_seconds": 137.0,
			"move_damage": 2,
			"collision_damage": 3,
			"movement_traits": ["amphibious"],
			"terrain_move_multiplier": {"ocean": 1.25},
			"resource_drain": 2,
			"resource_focus": ["life"],
			"starter_play_free": true,
			"is_starter": true,
		}

	func monster_deploy_rule_snapshot_v06(actor_id: String) -> Dictionary:
		snapshot_calls["rule"] = int(snapshot_calls.get("rule", 0)) + 1
		if recursive_rule_private_lookup:
			if int(snapshot_calls.get("rule", 0)) > 4:
				return {"available": false, "authoritative": false, "reason_code": "fixture_recursion_guard"}
			var private_snapshot: Dictionary = bound_owner.call("monster_private_snapshot_v06", actor_id) if bound_owner != null else {}
			if not bool(private_snapshot.get("available", false)):
				return {"available": false, "authoritative": false, "reason_code": "fixture_private_snapshot_unavailable"}
		if not player_indices.has(actor_id):
			return {
				"available": false,
				"authoritative": false,
				"actor_id": actor_id,
				"reason_code": "fixture_actor_missing",
			}
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
			"monster_binding_limit": int(binding_limits.get(actor_id, 1)),
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
		if not disabled_capability.is_empty():
			var path := disabled_capability.split(".")
			if path.size() == 2 and result.get(path[0]) is Dictionary:
				var row: Dictionary = (result.get(path[0]) as Dictionary).duplicate(true)
				row[path[1]] = false
				result[path[0]] = row
		return result

	func prepare_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		return _stage_receipt("prepare", "prepared", request)

	func commit_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		return _stage_receipt("commit", "committed", request)

	func rollback_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		return _stage_receipt("rollback", "rolled_back", request)

	func finalize_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		return _stage_receipt("finalize", "finalized", request)

	func _on_monster_runtime_event(event: Dictionary) -> Dictionary:
		presentation_events.append(event.duplicate(true))
		return {"accepted": true, "event_id": str(event.get("event_id", ""))}

	func _stage_receipt(stage: String, success_key: String, request: Dictionary) -> Dictionary:
		stage_calls[stage] = int(stage_calls.get(stage, 0)) + 1
		var result := {
			"transaction_id": str(request.get("transaction_id", "")),
			"participant_binding_fingerprint": str(request.get("participant_binding_fingerprint", "")),
			"stage": stage,
			"reason_code": "fixture_%s_ok" % stage,
		}
		if bool(failed_stages.get(stage, false)):
			result[success_key] = false
			result["reason_code"] = "fixture_%s_failed" % stage
			return result
		result[success_key] = true
		return result


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_starter_state_snapshot_is_pure_and_non_recursive()
	_verify_prepare_commit_and_exact_once()
	_verify_validation_and_revision_gates()
	_verify_commit_failure_and_prepared_abort()
	_verify_rollback_success_failure_and_tampering()
	_verify_finalize_retry_and_closed_rollback()
	_verify_upgrade_requires_authoritative_rank_profile()
	_verify_pending_and_terminal_save_load()
	_verify_corrupt_save_has_zero_effect()
	_finish()


func _verify_starter_state_snapshot_is_pure_and_non_recursive() -> void:
	var fixture := _fixture()
	var owner: MonsterRuntimeController = fixture.owner
	var world: FixtureWorld = fixture.world
	var bridge: MonsterRuntimeWorldBridge = fixture.bridge
	var empty_first: Dictionary = owner.monster_starter_state_snapshot_v06(HUMAN_ACTOR)
	var empty_second: Dictionary = owner.monster_starter_state_snapshot_v06(HUMAN_ACTOR)
	_expect(
		bool(empty_first.get("available", false))
		and str(empty_first.get("state", "")) == "not_summoned"
		and int(empty_first.get("unit_uid", -1)) == 0
		and str(empty_first.get("transaction_id", "x")).is_empty()
		and int(empty_first.get("revision", -1)) == 0
		and int(empty_first.get("owner_revision", -1)) == 0,
		"空 roster 的纯 owner starter snapshot 为 not_summoned"
	)
	_expect(
		SCHEMA.fingerprint(empty_first) == SCHEMA.fingerprint(empty_second)
		and int(world.snapshot_calls.get("rule", -1)) == 0,
		"连续 starter snapshot 查询稳定且不调用 WorldBridge"
	)
	var private_empty: Dictionary = owner.monster_private_snapshot_v06(HUMAN_ACTOR)
	_expect(
		bool(private_empty.get("available", false))
		and str(private_empty.get("starter_state", "")) == "not_summoned"
		and (private_empty.get("owned_units", []) as Array).is_empty()
		and int(world.snapshot_calls.get("rule", -1)) == 0,
		"private snapshot 只消费 owner 本地状态"
	)

	world.recursive_rule_private_lookup = true
	world.snapshot_calls["rule"] = 0
	var bridged_rule: Dictionary = bridge.monster_deploy_rule_snapshot_v06(HUMAN_ACTOR)
	_expect(
		bool(bridged_rule.get("available", false))
		and int(world.snapshot_calls.get("rule", 0)) == 1,
		"真实 WorldBridge 的 rule→private 回调不会再递归"
	)
	world.recursive_rule_private_lookup = false

	var intent := _starter_intent(owner, world, "tx-pure-starter-snapshot", HUMAN_ACTOR)
	var committed: Dictionary = owner.commit_unit_card_intent_v06(owner.prepare_unit_card_intent_v06(intent))
	var finalized: Dictionary = owner.finalize_unit_card_intent_v06(committed)
	var calls_before_query := world.snapshot_calls.duplicate(true)
	var summoned_first: Dictionary = owner.monster_starter_state_snapshot_v06(HUMAN_ACTOR)
	var summoned_second: Dictionary = owner.monster_starter_state_snapshot_v06(HUMAN_ACTOR)
	_expect(
		bool(finalized.get("finalized", false))
		and bool(summoned_first.get("available", false))
		and str(summoned_first.get("state", "")) == "summoned"
		and int(summoned_first.get("unit_uid", 0)) == int(committed.get("unit_uid", -1))
		and str(summoned_first.get("transaction_id", "")) == "tx-pure-starter-snapshot"
		and int(summoned_first.get("revision", 0)) > 0
		and int(summoned_first.get("owner_revision", -1)) == int(owner.unit_card_snapshot_v06("monster").get("owner_revision", -2)),
		"成功首召后纯 snapshot 返回 marker、UID、transaction 与 revisions"
	)
	_expect(
		SCHEMA.fingerprint(summoned_first) == SCHEMA.fingerprint(summoned_second)
		and SCHEMA.fingerprint(calls_before_query) == SCHEMA.fingerprint(world.snapshot_calls),
		"首召后连续查询仍不读取 world facts"
	)
	var private_summoned: Dictionary = owner.monster_private_snapshot_v06(HUMAN_ACTOR)
	_expect(
		bool(private_summoned.get("available", false))
		and str(private_summoned.get("starter_state", "")) == "summoned"
		and (private_summoned.get("owned_units", []) as Array).size() == 1,
		"private snapshot 通过本地 marker 绑定本人怪兽"
	)
	var public_snapshot: Dictionary = owner.unit_card_snapshot_v06("monster")
	var public_roster: Array = public_snapshot.get("roster", []) if public_snapshot.get("roster", []) is Array else []
	var public_actor: Dictionary = public_roster[0] as Dictionary if not public_roster.is_empty() and public_roster[0] is Dictionary else {}
	_expect(
		not public_actor.has("owner")
		and not public_actor.has("owner_actor_id_v06")
		and not public_actor.has("transaction_id")
		and not public_snapshot.has("starter_state"),
		"public snapshot 不泄漏 owner、private marker 或 transaction"
	)

	var saved: Dictionary = owner.unit_card_save_data_v06("monster")
	var restored_fixture := _fixture()
	var restored_owner: MonsterRuntimeController = restored_fixture.owner
	var restored: Dictionary = restored_owner.apply_unit_card_save_data_v06(saved, "monster")
	var restored_snapshot: Dictionary = restored_owner.monster_starter_state_snapshot_v06(HUMAN_ACTOR)
	_expect(
		bool(restored.get("applied", false))
		and str(restored_snapshot.get("state", "")) == "summoned"
		and int(restored_snapshot.get("unit_uid", 0)) == int(summoned_first.get("unit_uid", -1))
		and str(restored_snapshot.get("transaction_id", "")) == "tx-pure-starter-snapshot",
		"save/load 保留纯 starter snapshot"
	)

	var legacy_fixture := _fixture()
	var legacy_owner: MonsterRuntimeController = legacy_fixture.owner
	var legacy_apply: Dictionary = legacy_owner.apply_save_data({
		"auto_monsters": [{"uid": 91, "slot": 0, "owner": 0, "rank": 1, "hp": 10, "max_hp": 10}],
		"next_auto_monster_uid": 92,
	})
	var legacy_snapshot: Dictionary = legacy_owner.monster_starter_state_snapshot_v06(HUMAN_ACTOR)
	var legacy_private: Dictionary = legacy_owner.monster_private_snapshot_v06(HUMAN_ACTOR)
	_expect(
		bool(legacy_apply.get("applied", false))
		and not bool(legacy_snapshot.get("available", true))
		and str(legacy_snapshot.get("state", "")) == "legacy_unknown"
		and not bool(legacy_private.get("available", true)),
		"缺少 marker/actor_id 的旧 roster fail-closed 为 legacy_unknown"
	)
	_cleanup(fixture)
	_cleanup(restored_fixture)
	_cleanup(legacy_fixture)


func _verify_prepare_commit_and_exact_once() -> void:
	var fixture := _fixture()
	var owner: MonsterRuntimeController = fixture.owner
	var world: FixtureWorld = fixture.world
	var intent := _starter_intent(owner, world, "tx-deploy-exact", HUMAN_ACTOR)
	var before := _business_fingerprint(owner)
	var prepared: Dictionary = owner.prepare_unit_card_intent_v06(intent)
	_expect(bool(prepared.get("prepared", false)), "合法 I 级起始怪兽首召可以 prepare")
	_expect(str(prepared.get("operation", "")) == "deploy" and str(prepared.get("resolved_action_kind", "")) == "deploy_monster_rank1_starter_first", "owner 回执明确派生 starter first summon deploy")
	_expect(before == _business_fingerprint(owner) and owner.roster_snapshot(true).is_empty(), "prepare 不修改 roster、UID、selection 或首召业务状态")
	_expect(not bool(owner.unit_card_checkpoint_status_v06("monster").get("can_checkpoint", true)), "prepared association 阻止 checkpoint")
	var prepared_replay: Dictionary = owner.prepare_unit_card_intent_v06(intent)
	_expect(bool(prepared_replay.get("idempotent_replay", false)) and str(prepared_replay.get("reservation_fingerprint", "")) == str(prepared.get("reservation_fingerprint", "")), "同 binding prepare 重放返回同一预留")
	_expect(int(world.stage_calls.get("prepare", 0)) == 0, "无额外副作用的 P0 首召不制造跨 owner participant")

	var committed: Dictionary = owner.commit_unit_card_intent_v06(prepared)
	_expect(bool(committed.get("committed", false)) and bool(committed.get("rollback_open", false)), "commit 一次发布真实 roster 并开启 rollback window")
	var roster: Array = owner.roster_snapshot(true)
	_expect(roster.size() == 1, "commit 后真实 MonsterRuntimeController roster 出现一只怪兽")
	var actor: Dictionary = roster[0] as Dictionary
	_expect(int(actor.get("rank", 0)) == 1 and int(actor.get("hp", 0)) == 42 and int(actor.get("max_hp", 0)) == 42, "Rank I HP 完全来自权威 profile")
	_expect(is_equal_approx(float(actor.get("duration", 0.0)), 137.0) and is_equal_approx(float(actor.get("remaining_time", 0.0)), 137.0), "首次部署 duration 与 remaining time 按 profile 初始化")
	_expect(is_equal_approx(float(actor.get("move", 0.0)), 18.5) and int(actor.get("move_damage", 0)) == 2 and int(actor.get("collision_damage", 0)) == 3, "移动与伤害 meter 由 profile 初始化且 adapter 不重算")
	_expect(int(actor.get("owner_damage_cash_total", 0)) > 0 and int(actor.get("owner_damage_cash_pool", 0)) == int(actor.get("owner_damage_cash_total", -1)), "owner-damage cash meter 只在怪兽内部初始化")
	_expect(int((world.players[0] as Dictionary).get("cash", -1)) == 123, "怪兽 roster owner 不直接修改玩家现金")
	_expect(int(world.stage_calls.get("commit", 0)) == 0, "无额外副作用的 P0 首召不提交跨 owner participant")

	var committed_replay_from_prepared: Dictionary = owner.commit_unit_card_intent_v06(prepared)
	var committed_replay: Dictionary = owner.commit_unit_card_intent_v06(committed)
	_expect(bool(committed_replay_from_prepared.get("idempotent_replay", false)) and bool(committed_replay.get("idempotent_replay", false)), "prepared 或 committed 回执重放均不会创建第二只怪兽")
	_expect(owner.roster_snapshot(true).size() == 1 and int(world.stage_calls.get("commit", 0)) == 0, "commit exact-once 保护 roster 与 UID")
	_cleanup(fixture)


func _verify_validation_and_revision_gates() -> void:
	var stale_owner_fixture := _fixture()
	var stale_owner: MonsterRuntimeController = stale_owner_fixture.owner
	var stale_world: FixtureWorld = stale_owner_fixture.world
	var stale_owner_intent := _starter_intent(stale_owner, stale_world, "tx-stale-owner", HUMAN_ACTOR, CARD_RANK_1, 99)
	var stale_owner_result: Dictionary = stale_owner.prepare_unit_card_intent_v06(stale_owner_intent)
	_expect(str(stale_owner_result.get("reason_code", "")) == "monster_owner_revision_stale" and stale_owner.roster_snapshot(true).is_empty(), "旧 owner revision 在任何 participant 或 roster mutation 前拒绝")
	_cleanup(stale_owner_fixture)

	var stale_region_fixture := _fixture()
	var stale_region_owner: MonsterRuntimeController = stale_region_fixture.owner
	var stale_region_world: FixtureWorld = stale_region_fixture.world
	var stale_region := _starter_intent(stale_region_owner, stale_region_world, "tx-stale-region", HUMAN_ACTOR, CARD_RANK_1, -1, stale_region_world.region_revision - 1)
	var stale_region_result: Dictionary = stale_region_owner.prepare_unit_card_intent_v06(stale_region)
	_expect(str(stale_region_result.get("reason_code", "")) == "monster_region_revision_stale" and stale_region_owner.roster_snapshot(true).is_empty(), "旧 region revision fail-closed")
	_cleanup(stale_region_fixture)

	var stale_rule_fixture := _fixture()
	var stale_rule_owner: MonsterRuntimeController = stale_rule_fixture.owner
	var stale_rule_world: FixtureWorld = stale_rule_fixture.world
	var stale_rule := _starter_intent(stale_rule_owner, stale_rule_world, "tx-stale-rule", HUMAN_ACTOR, CARD_RANK_1, -1, -1, int(stale_rule_world.rule_revisions.get(HUMAN_ACTOR, 0)) - 1)
	var stale_rule_result: Dictionary = stale_rule_owner.prepare_unit_card_intent_v06(stale_rule)
	_expect(str(stale_rule_result.get("reason_code", "")) == "monster_binding_rule_revision_stale" and stale_rule_owner.roster_snapshot(true).is_empty(), "旧 binding-rule revision fail-closed")
	_cleanup(stale_rule_fixture)

	var invalid_region_fixture := _fixture()
	var invalid_region_owner: MonsterRuntimeController = invalid_region_fixture.owner
	var invalid_region_world: FixtureWorld = invalid_region_fixture.world
	invalid_region_world.region_destroyed = true
	var invalid_region_result: Dictionary = invalid_region_owner.prepare_unit_card_intent_v06(_starter_intent(invalid_region_owner, invalid_region_world, "tx-destroyed-region", HUMAN_ACTOR))
	_expect(not bool(invalid_region_result.get("prepared", true)) and invalid_region_owner.roster_snapshot(true).is_empty(), "被摧毁区域不能成为 starter summon 目标")
	_cleanup(invalid_region_fixture)

	var limit_fixture := _fixture()
	var limit_owner: MonsterRuntimeController = limit_fixture.owner
	var limit_world: FixtureWorld = limit_fixture.world
	limit_world.binding_limits[HUMAN_ACTOR] = 0
	var limit_result: Dictionary = limit_owner.prepare_unit_card_intent_v06(_starter_intent(limit_owner, limit_world, "tx-zero-binding-limit", HUMAN_ACTOR))
	_expect(bool(limit_result.get("prepared", false)), "旧 binding-rule 数量字段不再覆盖缺 provider 时的权威基础 1×II 限制")
	_cleanup(limit_fixture)

	var rank_fixture := _fixture()
	var rank_owner: MonsterRuntimeController = rank_fixture.owner
	var rank_world: FixtureWorld = rank_fixture.world
	var rank_two_result: Dictionary = rank_owner.prepare_unit_card_intent_v06(_starter_intent(rank_owner, rank_world, "tx-rank-two-deferred", HUMAN_ACTOR, CARD_RANK_2))
	_expect(str(rank_two_result.get("reason_code", "")) == "monster_non_starter_deploy_deferred" and rank_owner.roster_snapshot(true).is_empty(), "Rank II–IV 部署不借 P0 starter 路径解锁")
	_cleanup(rank_fixture)

	var conflict_fixture := _fixture()
	var conflict_owner: MonsterRuntimeController = conflict_fixture.owner
	var conflict_world: FixtureWorld = conflict_fixture.world
	var first := _starter_intent(conflict_owner, conflict_world, "tx-binding-conflict", HUMAN_ACTOR)
	var first_prepared: Dictionary = conflict_owner.prepare_unit_card_intent_v06(first)
	var conflicting := _starter_intent(conflict_owner, conflict_world, "tx-binding-conflict", HUMAN_ACTOR)
	conflicting["card_instance_id"] = "instance.binding-conflict.other"
	conflicting = SCHEMA.make_intent(
		"tx-binding-conflict",
		HUMAN_ACTOR,
		CARD_RANK_1,
		"instance.binding-conflict.other",
		EFFECT_KIND,
		ACTION_KIND,
		0,
		conflicting.get("target_context", {}) as Dictionary,
		_monster_fields(1),
		{"anonymous_play": true, "hidden_owner": true}
	)
	var conflict_result: Dictionary = conflict_owner.prepare_unit_card_intent_v06(conflicting)
	_expect(bool(first_prepared.get("prepared", false)) and str(conflict_result.get("reason_code", "")) == "monster_transaction_binding_conflict", "同 transaction ID 不同 card binding 被 exact-once journal 拒绝")
	_cleanup(conflict_fixture)


func _verify_commit_failure_and_prepared_abort() -> void:
	var abort_fixture := _fixture()
	var abort_owner: MonsterRuntimeController = abort_fixture.owner
	var abort_world: FixtureWorld = abort_fixture.world
	var abort_prepared: Dictionary = abort_owner.prepare_unit_card_intent_v06(_starter_intent(abort_owner, abort_world, "tx-prepared-abort", HUMAN_ACTOR))
	var aborted: Dictionary = abort_owner.rollback_unit_card_intent_v06(abort_prepared)
	_expect(bool(aborted.get("rolled_back", false)) and abort_owner.roster_snapshot(true).is_empty(), "尚未 commit 的预留可以通过同一 rollback API 完整撤销")
	_expect(bool(abort_owner.unit_card_checkpoint_status_v06("monster").get("can_checkpoint", false)), "prepared rollback 释放 checkpoint gate")
	_cleanup(abort_fixture)

	var fact_fixture := _fixture()
	var fact_owner: MonsterRuntimeController = fact_fixture.owner
	var fact_world: FixtureWorld = fact_fixture.world
	var fact_prepared: Dictionary = fact_owner.prepare_unit_card_intent_v06(_starter_intent(fact_owner, fact_world, "tx-region-changed-on-commit", HUMAN_ACTOR))
	fact_world.region_revision += 1
	var fact_before := _business_fingerprint(fact_owner)
	var fact_failed: Dictionary = fact_owner.commit_unit_card_intent_v06(fact_prepared)
	_expect(str(fact_failed.get("reason_code", "")) == "monster_region_binding_changed" and fact_before == _business_fingerprint(fact_owner), "prepare 后 region revision/fingerprint 改变时 commit 零生效")
	_cleanup(fact_fixture)


func _verify_rollback_success_failure_and_tampering() -> void:
	var fixture := _fixture()
	var owner: MonsterRuntimeController = fixture.owner
	var world: FixtureWorld = fixture.world
	var prepared: Dictionary = owner.prepare_unit_card_intent_v06(_starter_intent(owner, world, "tx-rollback-ok", HUMAN_ACTOR))
	var committed: Dictionary = owner.commit_unit_card_intent_v06(prepared)
	var rolled_back: Dictionary = owner.rollback_unit_card_intent_v06(committed)
	_expect(bool(rolled_back.get("rolled_back", false)) and owner.roster_snapshot(true).is_empty(), "committed deploy rollback 一次 swap 恢复完整 preimage")
	var revision_after_rollback := int(owner.unit_card_snapshot_v06("monster").get("owner_revision", -1))
	_expect(revision_after_rollback > int(committed.get("owner_revision_after", -1)), "rollback 保持 owner revision 单调增长")
	var rollback_replay: Dictionary = owner.rollback_unit_card_intent_v06(committed)
	_expect(bool(rollback_replay.get("rolled_back", false)) and bool(rollback_replay.get("idempotent_replay", false)) and int(world.stage_calls.get("rollback", 0)) == 0, "rollback 重放不重复 roster mutation")
	_cleanup(fixture)

	var receipt_fixture := _fixture()
	var receipt_owner: MonsterRuntimeController = receipt_fixture.owner
	var receipt_world: FixtureWorld = receipt_fixture.world
	var receipt_prepared: Dictionary = receipt_owner.prepare_unit_card_intent_v06(_starter_intent(receipt_owner, receipt_world, "tx-tampered-receipt", HUMAN_ACTOR))
	var tampered_prepared := receipt_prepared.duplicate(true)
	tampered_prepared["reservation_fingerprint"] = "tampered"
	var receipt_before := _business_fingerprint(receipt_owner)
	var tampered_commit: Dictionary = receipt_owner.commit_unit_card_intent_v06(tampered_prepared)
	_expect(str(tampered_commit.get("reason_code", "")) == "monster_transaction_receipt_tampered" and receipt_before == _business_fingerprint(receipt_owner), "篡改 reservation fingerprint 不能提交 roster")
	_cleanup(receipt_fixture)

	var postimage_fixture := _fixture()
	var postimage_owner: MonsterRuntimeController = postimage_fixture.owner
	var postimage_world: FixtureWorld = postimage_fixture.world
	var postimage_prepared: Dictionary = postimage_owner.prepare_unit_card_intent_v06(_starter_intent(postimage_owner, postimage_world, "tx-postimage-progress", HUMAN_ACTOR))
	var postimage_committed: Dictionary = postimage_owner.commit_unit_card_intent_v06(postimage_prepared)
	var advanced_actor: Dictionary = (postimage_owner.auto_monsters[0] as Dictionary).duplicate(true)
	advanced_actor["hp"] = int(advanced_actor.get("hp", 0)) - 1
	postimage_owner.auto_monsters[0] = advanced_actor
	var progressed_before := _business_fingerprint(postimage_owner)
	var progressed_rollback: Dictionary = postimage_owner.rollback_unit_card_intent_v06(postimage_committed)
	_expect(str(progressed_rollback.get("reason_code", "")) == "monster_rollback_postimage_changed" and progressed_before == _business_fingerprint(postimage_owner), "第三方状态推进或 postimage 篡改时 rollback before==after")
	_cleanup(postimage_fixture)


func _verify_finalize_retry_and_closed_rollback() -> void:
	var fixture := _fixture()
	var owner: MonsterRuntimeController = fixture.owner
	var world: FixtureWorld = fixture.world
	var prepared: Dictionary = owner.prepare_unit_card_intent_v06(_starter_intent(owner, world, "tx-finalize-retry", HUMAN_ACTOR))
	var committed: Dictionary = owner.commit_unit_card_intent_v06(prepared)
	var finalized: Dictionary = owner.finalize_unit_card_intent_v06(committed)
	_expect(bool(finalized.get("finalized", false)) and not bool(finalized.get("rollback_open", true)), "finalize 成功后明确关闭 rollback window")
	_expect(world.presentation_events.size() == 1, "presentation hook 只在业务 finalize 成功后发一次")
	var finalize_replay: Dictionary = owner.finalize_unit_card_intent_v06(finalized)
	_expect(bool(finalize_replay.get("idempotent_replay", false)) and world.presentation_events.size() == 1 and int(world.stage_calls.get("finalize", 0)) == 0, "finalize 重放不重复 presentation")
	var finalized_state := _business_fingerprint(owner)
	var closed_rollback: Dictionary = owner.rollback_unit_card_intent_v06(committed)
	_expect(not bool(closed_rollback.get("rolled_back", true)) and bool(closed_rollback.get("finalized", false)) and finalized_state == _business_fingerprint(owner), "finalize 后 rollback 永久关闭且 roster 保持")
	_expect(bool(owner.unit_card_checkpoint_status_v06("monster").get("can_checkpoint", false)), "terminal finalize 释放 checkpoint gate")
	_cleanup(fixture)


func _verify_upgrade_requires_authoritative_rank_profile() -> void:
	var fixture := _fixture()
	var owner: MonsterRuntimeController = fixture.owner
	var world: FixtureWorld = fixture.world
	var deploy_intent := _starter_intent(owner, world, "tx-upgrade-base", HUMAN_ACTOR)
	var committed: Dictionary = owner.commit_unit_card_intent_v06(owner.prepare_unit_card_intent_v06(deploy_intent))
	owner.finalize_unit_card_intent_v06(committed)
	var actor: Dictionary = owner.roster_snapshot(true)[0] as Dictionary
	var upgrade_target := {
		"valid": true,
		"unit_uid": int(actor.get("uid", 0)),
		"expected_actor_revision": int(actor.get("actor_revision_v06", 0)),
		"expected_binding_rule_revision": int(world.rule_revisions.get(HUMAN_ACTOR, -1)),
	}
	var upgrade_intent := SCHEMA.make_intent(
		"tx-upgrade-profile-gap",
		HUMAN_ACTOR,
		CARD_RANK_1,
		"instance.tx-upgrade-profile-gap",
		EFFECT_KIND,
		ACTION_KIND,
		int(owner.unit_card_snapshot_v06("monster").get("owner_revision", -1)),
		upgrade_target,
		_monster_fields(1),
		{"anonymous_play": true, "hidden_owner": true}
	)
	var before := _business_fingerprint(owner)
	var result: Dictionary = owner.prepare_unit_card_intent_v06(upgrade_intent)
	_expect(str(result.get("reason_code", "")) == "fixture_profile_missing", "缺少下一 Rank 权威 profile 时 upgrade fail-closed")
	_expect(not bool(result.get("prepared", true)) and before == _business_fingerprint(owner), "profile 缺口不调用旧 owner、不改变 Rank I roster")
	_cleanup(fixture)


func _verify_pending_and_terminal_save_load() -> void:
	var pending_fixture := _fixture()
	var pending_owner: MonsterRuntimeController = pending_fixture.owner
	var pending_world: FixtureWorld = pending_fixture.world
	var pending_intent := _starter_intent(pending_owner, pending_world, "tx-save-pending", HUMAN_ACTOR)
	var pending_receipt: Dictionary = pending_owner.prepare_unit_card_intent_v06(pending_intent)
	var pending_save: Dictionary = pending_owner.unit_card_save_data_v06("monster")
	for save_key in SAVE_KEYS:
		_expect(pending_save.has(save_key), "pending save 使用冻结 flat key：%s" % save_key)
	var restored_pending := _fixture()
	var pending_restore: Dictionary = restored_pending.owner.apply_unit_card_save_data_v06(pending_save, "monster")
	_expect(bool(pending_restore.get("applied", false)) and not bool(restored_pending.owner.unit_card_checkpoint_status_v06("monster").get("can_checkpoint", true)), "prepared association 连同 checkpoint gate 原子恢复")
	var restored_commit: Dictionary = restored_pending.owner.commit_unit_card_intent_v06(pending_receipt)
	_expect(bool(restored_commit.get("committed", false)) and restored_pending.owner.roster_snapshot(true).size() == 1, "load 后原 authoritative prepared receipt 仍可精确 commit")
	_cleanup(pending_fixture)
	_cleanup(restored_pending)

	var terminal_fixture := _fixture()
	var terminal_owner: MonsterRuntimeController = terminal_fixture.owner
	var terminal_world: FixtureWorld = terminal_fixture.world
	var terminal_intent := _starter_intent(terminal_owner, terminal_world, "tx-save-terminal", HUMAN_ACTOR)
	var terminal_committed: Dictionary = terminal_owner.commit_unit_card_intent_v06(terminal_owner.prepare_unit_card_intent_v06(terminal_intent))
	var terminal_receipt: Dictionary = terminal_owner.finalize_unit_card_intent_v06(terminal_committed)
	var terminal_save: Dictionary = terminal_owner.unit_card_save_data_v06("monster")
	var restored_terminal := _fixture()
	var terminal_restore: Dictionary = restored_terminal.owner.apply_unit_card_save_data_v06(terminal_save, "monster")
	_expect(bool(terminal_restore.get("applied", false)) and restored_terminal.owner.roster_snapshot(true).size() == 1, "finalized roster 与 terminal journal 一起恢复")
	var terminal_replay: Dictionary = restored_terminal.owner.prepare_unit_card_intent_v06(terminal_intent)
	_expect(bool(terminal_replay.get("idempotent_replay", false)) and bool(terminal_replay.get("finalized", false)), "save/load 后相同 transaction 仍由 terminal journal exact-once")
	var terminal_finalize_replay: Dictionary = restored_terminal.owner.finalize_unit_card_intent_v06(terminal_receipt)
	_expect(bool(terminal_finalize_replay.get("idempotent_replay", false)) and restored_terminal.owner.roster_snapshot(true).size() == 1, "terminal finalize receipt load 后不重复部署或发业务副作用")
	_cleanup(terminal_fixture)
	_cleanup(restored_terminal)


func _verify_corrupt_save_has_zero_effect() -> void:
	var source_fixture := _fixture()
	var source_owner: MonsterRuntimeController = source_fixture.owner
	var source_world: FixtureWorld = source_fixture.world
	source_owner.prepare_unit_card_intent_v06(_starter_intent(source_owner, source_world, "tx-corrupt-source", HUMAN_ACTOR))
	var corrupt: Dictionary = source_owner.unit_card_save_data_v06("monster")
	var reservations: Dictionary = (corrupt.get("monster_card_atomic_reservations", {}) as Dictionary).duplicate(true)
	var row: Dictionary = (reservations.get("tx-corrupt-source", {}) as Dictionary).duplicate(true)
	row["reservation_fingerprint"] = "tampered"
	reservations["tx-corrupt-source"] = row
	corrupt["monster_card_atomic_reservations"] = reservations

	var target_fixture := _fixture()
	var target_owner: MonsterRuntimeController = target_fixture.owner
	var target_world: FixtureWorld = target_fixture.world
	var stable_committed: Dictionary = target_owner.commit_unit_card_intent_v06(target_owner.prepare_unit_card_intent_v06(_starter_intent(target_owner, target_world, "tx-stable-target", AI_ACTOR)))
	target_owner.finalize_unit_card_intent_v06(stable_committed)
	var before := _whole_save_fingerprint(target_owner)
	var rejected: Dictionary = target_owner.apply_unit_card_save_data_v06(corrupt, "monster")
	_expect(not bool(rejected.get("applied", true)) and before == _whole_save_fingerprint(target_owner), "损坏 reservation 先全量验证再拒绝，目标 owner before==after")

	var bad_terminal: Dictionary = target_owner.unit_card_save_data_v06("monster")
	var terminal: Dictionary = (bad_terminal.get("monster_card_atomic_terminal_journal", {}) as Dictionary).duplicate(true)
	var terminal_row: Dictionary = (terminal.get("tx-stable-target", {}) as Dictionary).duplicate(true)
	terminal_row["intent_binding"] = {"transaction_id": "tampered"}
	terminal["tx-stable-target"] = terminal_row
	bad_terminal["monster_card_atomic_terminal_journal"] = terminal
	var rejected_terminal: Dictionary = target_owner.apply_unit_card_save_data_v06(bad_terminal, "monster")
	_expect(not bool(rejected_terminal.get("applied", true)) and before == _whole_save_fingerprint(target_owner), "损坏 terminal binding 不能部分替换 roster、marker 或 journal")
	_cleanup(source_fixture)
	_cleanup(target_fixture)


func _fixture() -> Dictionary:
	var world := FixtureWorld.new()
	root.add_child(world)
	var bridge := WORLD_BRIDGE_SCRIPT.new() as MonsterRuntimeWorldBridge
	root.add_child(bridge)
	bridge.bind_world(world)
	var owner := CONTROLLER_SCRIPT.new() as MonsterRuntimeController
	root.add_child(owner)
	owner.set_world_bridge(bridge)
	world.bound_owner = owner
	return {"world": world, "bridge": bridge, "owner": owner}


func _cleanup(fixture: Dictionary) -> void:
	for key in ["owner", "bridge", "world"]:
		var node: Node = fixture.get(key)
		if node != null and is_instance_valid(node):
			node.free()


func _starter_intent(
	owner: MonsterRuntimeController,
	world: FixtureWorld,
	transaction_id: String,
	actor_id: String,
	card_id: String = CARD_RANK_1,
	expected_owner_revision: int = -1,
	expected_region_revision: int = -1,
	expected_rule_revision: int = -1
) -> Dictionary:
	var rank := 2 if card_id == CARD_RANK_2 else 1
	var owner_revision := expected_owner_revision
	if owner_revision < 0:
		owner_revision = int(owner.unit_card_snapshot_v06("monster").get("owner_revision", 0))
	var region_revision := expected_region_revision
	if region_revision < 0:
		region_revision = world.region_revision
	var rule_revision := expected_rule_revision
	if rule_revision < 0:
		rule_revision = int(world.rule_revisions.get(actor_id, -1))
	return SCHEMA.make_intent(
		transaction_id,
		actor_id,
		card_id,
		"instance.%s" % transaction_id,
		EFFECT_KIND,
		ACTION_KIND,
		owner_revision,
		{
			"valid": true,
			"region_id": REGION_ID,
			"expected_region_revision": region_revision,
			"expected_binding_rule_revision": rule_revision,
		},
		_monster_fields(rank),
		{"anonymous_play": true, "hidden_owner": true}
	)


func _monster_fields(rank: int) -> Dictionary:
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


func _business_fingerprint(owner: MonsterRuntimeController) -> String:
	var save: Dictionary = owner.to_save_data()
	return SCHEMA.fingerprint({
		"auto_monsters": save.get("auto_monsters", []),
		"next_auto_monster_uid": save.get("next_auto_monster_uid", -1),
		"next_special_monster_slot": save.get("next_special_monster_slot", -1),
		"selected_auto_monster_slot": save.get("selected_auto_monster_slot", -1),
		"starter_state": save.get("monster_card_atomic_starter_state", {}),
	})


func _whole_save_fingerprint(owner: MonsterRuntimeController) -> String:
	return SCHEMA.fingerprint(owner.unit_card_save_data_v06("monster"))


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("MONSTER_DEPLOY_ATOMIC_LIFECYCLE_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("MONSTER_DEPLOY_ATOMIC_LIFECYCLE_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
