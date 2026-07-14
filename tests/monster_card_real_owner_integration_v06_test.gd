extends SceneTree

const SCHEMA := preload("res://scripts/cards/v06/units/unit_card_runtime_schema_v06.gd")
const CONTROLLER_SCRIPT := preload("res://scripts/runtime/monster_runtime_controller.gd")
const WORLD_BRIDGE_SCRIPT := preload("res://scripts/runtime/monster_runtime_world_bridge.gd")
const ADAPTER_SCRIPT := preload("res://scripts/cards/v06/units/monster_card_effect_adapter_v06.gd")
const OWNER_PORT_SCRIPT := preload("res://scripts/cards/v06/units/monster_card_owner_port_v06.gd")

const CARD_RANK_1 := "unit.monster.spore_tide_emperor.rank_1"
const CARD_RANK_2 := "unit.monster.spore_tide_emperor.rank_2"
const FAMILY_ID := "spore_tide_emperor"
const EFFECT_KIND := "deploy_or_upgrade_monster"
const ACTION_KIND := "deploy_or_upgrade_monster"
const HUMAN_ACTOR := "human.alpha"
const AI_ACTOR := "ai.beta"
const REGION_ID := "region.alpha"

var _checks := 0
var _failures: Array[String] = []


class FixtureWorld:
	extends Node

	var players: Array = [
		{"actor_id": HUMAN_ACTOR, "cash": 100, "slots": []},
		{"actor_id": AI_ACTOR, "cash": 100, "slots": [], "ai_plan": "PRIVATE-AI-PLAN"},
	]
	var districts: Array = [{"name": "阿尔法区", "center": Vector2(90.0, 180.0)}]
	var game_time := 0.0
	var selected_player := 0
	var selected_district := 0
	var rng := RandomNumberGenerator.new()
	var region_revision := 11
	var profile_revision := 13
	var rule_revisions := {HUMAN_ACTOR: 17, AI_ACTOR: 19}
	var player_indices := {HUMAN_ACTOR: 0, AI_ACTOR: 1}
	var disabled_capability := ""
	var stage_calls := {"prepare": 0, "commit": 0, "rollback": 0, "finalize": 0}
	var presentation_events: Array = []

	func _init() -> void:
		rng.seed = 60711

	func monster_deploy_region_snapshot_v06(region_id: String) -> Dictionary:
		if region_id != REGION_ID:
			return {"available": false, "authoritative": false, "region_id": region_id, "reason_code": "fixture_region_missing"}
		return {
			"available": true,
			"authoritative": true,
			"region_id": REGION_ID,
			"display_name": "阿尔法区",
			"revision": region_revision,
			"region_index": 0,
			"destroyed": false,
			"starter_summon_allowed": true,
			"allowed_monster_families": [FAMILY_ID],
			"world_position": {"x": 90.0, "y": 180.0},
		}

	func monster_deploy_profile_snapshot_v06(family_id: String, rank: int) -> Dictionary:
		if family_id != FAMILY_ID or rank != 1:
			return {"available": false, "authoritative": false, "family_id": family_id, "rank": rank, "reason_code": "fixture_profile_missing"}
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
			"starter_play_free": true,
			"is_starter": true,
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
		if not disabled_capability.is_empty():
			var path := disabled_capability.split(".")
			if path.size() == 2 and result.get(path[0]) is Dictionary:
				var row: Dictionary = (result.get(path[0]) as Dictionary).duplicate(true)
				row[path[1]] = false
				result[path[0]] = row
		return result

	func prepare_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		return _stage("prepare", "prepared", request)

	func commit_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		return _stage("commit", "committed", request)

	func rollback_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		return _stage("rollback", "rolled_back", request)

	func finalize_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		return _stage("finalize", "finalized", request)

	func _on_monster_runtime_event(event: Dictionary) -> Dictionary:
		presentation_events.append(event.duplicate(true))
		return {"accepted": true}

	func _stage(stage: String, success_key: String, request: Dictionary) -> Dictionary:
		stage_calls[stage] = int(stage_calls.get(stage, 0)) + 1
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
	_verify_real_owner_unlocks_ss06_07_adapter()
	_verify_human_and_ai_use_the_same_owner_api()
	_verify_missing_dependency_stops_before_owner_prepare()
	_verify_nonstarter_and_upgrade_paths_remain_closed()
	_verify_real_owner_snapshot_private_snapshot_and_save_surface()
	_finish()


func _verify_real_owner_unlocks_ss06_07_adapter() -> void:
	var fixture := _fixture()
	var owner: MonsterRuntimeController = fixture.owner
	var world: FixtureWorld = fixture.world
	var capabilities: Dictionary = owner.monster_runtime_capabilities_v06()
	_expect(bool(capabilities.get("atomic_mutation_ready", false)), "真实 MonsterRuntimeController 在方法和 dependency matrix 完整时仅解锁 P0 原子路径")
	_expect(str(capabilities.get("capability_reason", "")) == "monster_atomic_ready", "capability readiness 来自实测矩阵而非常量")
	_expect((capabilities.get("supported_effect_kinds", []) as Array) == [EFFECT_KIND] and (capabilities.get("supported_action_kinds", []) as Array) == [ACTION_KIND], "capability 只宣告冻结的外层 effect/action")
	_expect(bool(capabilities.get("upgrade_duration_policy_ready", false)) and str(capabilities.get("upgrade_duration_policy_reason", "")) == "monster_upgrade_adds_remaining_time", "capability 宣告冻结的强化时间语义：只增加剩余时间")

	var adapter = ADAPTER_SCRIPT.new()
	var configured: Dictionary = adapter.configure(owner)
	_expect(bool(configured.get("configured", false)) and bool((configured.get("capability_matrix", {}) as Dictionary).get("atomic_mutation_ready", false)), "SS06-07 Monster adapter 由真实 owner 能力解锁")
	var intent := _intent(owner, world, "tx-real-adapter", HUMAN_ACTOR)
	var prepared: Dictionary = adapter.prepare_effect(intent)
	var committed: Dictionary = adapter.commit_effect(prepared)
	var finalized: Dictionary = adapter.finalize_effect(committed)
	_expect(bool(prepared.get("prepared", false)) and bool(committed.get("committed", false)) and bool(finalized.get("finalized", false)), "adapter 透传真实 owner 的 prepare/commit/finalize 生命周期")
	_expect(str(committed.get("operation", "")) == "deploy" and owner.roster_snapshot(true).size() == 1, "adapter 回执 operation=deploy 且业务真相只存在真实 roster owner")
	_expect(int(world.stage_calls.get("prepare", 0)) == 1 and int(world.stage_calls.get("commit", 0)) == 1 and int(world.stage_calls.get("finalize", 0)) == 1, "真实 owner 经 WorldBridge 调用每个 participant 阶段一次")
	_cleanup(fixture)


func _verify_human_and_ai_use_the_same_owner_api() -> void:
	var fixture := _fixture()
	var owner: MonsterRuntimeController = fixture.owner
	var world: FixtureWorld = fixture.world
	var adapter = ADAPTER_SCRIPT.new()
	adapter.configure(owner)
	var human_intent := _intent(owner, world, "tx-human-starter", HUMAN_ACTOR)
	var human_finalized: Dictionary = adapter.finalize_effect(adapter.commit_effect(adapter.prepare_effect(human_intent)))
	_expect(bool(human_finalized.get("finalized", false)), "真人 actor_id 通过统一 adapter/port/owner 完成首召")
	var ai_intent := _intent(owner, world, "tx-ai-starter", AI_ACTOR)
	var ai_finalized: Dictionary = adapter.finalize_effect(adapter.commit_effect(adapter.prepare_effect(ai_intent)))
	_expect(bool(ai_finalized.get("finalized", false)), "AI actor_id 通过完全相同 API 和校验完成首召")
	var roster: Array = owner.roster_snapshot(true)
	_expect(roster.size() == 2, "同一真实 owner 为两名 actor 各持有一只合法怪兽而不创建 AI 平行 roster")
	var owners: Array[String] = []
	for actor_variant in roster:
		if actor_variant is Dictionary:
			owners.append(str((actor_variant as Dictionary).get("owner_actor_id_v06", "")))
	owners.sort()
	_expect(owners == [AI_ACTOR, HUMAN_ACTOR], "真人与 AI 的差异只来自 actor binding 输入")
	_expect(int(world.stage_calls.get("prepare", 0)) == 2 and int(world.stage_calls.get("commit", 0)) == 2 and int(world.stage_calls.get("finalize", 0)) == 2, "真人与 AI 共享同一跨 owner exact-once 生命周期")
	_cleanup(fixture)


func _verify_missing_dependency_stops_before_owner_prepare() -> void:
	var fixture := _fixture()
	var owner: MonsterRuntimeController = fixture.owner
	var world: FixtureWorld = fixture.world
	world.disabled_capability = "role_cash_ledger.rollback"
	var owner_capabilities: Dictionary = owner.monster_runtime_capabilities_v06()
	_expect(not bool(owner_capabilities.get("atomic_mutation_ready", true)) and str(owner_capabilities.get("capability_reason", "")) == "monster_cross_owner_atomicity_unavailable", "任一 participant 缺 rollback 时真实 owner capability fail-closed")
	var adapter = ADAPTER_SCRIPT.new()
	var configured: Dictionary = adapter.configure(owner)
	_expect(bool(configured.get("configured", false)) and not bool((configured.get("capability_matrix", {}) as Dictionary).get("atomic_mutation_ready", true)), "port 不把方法存在误判为 production atomic ready")
	var before_calls: Dictionary = (owner.monster_card_developer_snapshot_v06().get("call_counts", {}) as Dictionary).duplicate(true)
	var before_roster := owner.roster_snapshot(true)
	var rejected: Dictionary = adapter.prepare_effect(_intent(owner, world, "tx-missing-participant", HUMAN_ACTOR))
	var after_calls: Dictionary = owner.monster_card_developer_snapshot_v06().get("call_counts", {}) as Dictionary
	_expect(not bool(rejected.get("prepared", true)) and not str(rejected.get("reason_code", "")).is_empty(), "adapter 返回结构化本地化失败而非伪造成功")
	_expect(int(after_calls.get("prepare", -1)) == int(before_calls.get("prepare", -2)) and int(world.stage_calls.get("prepare", 0)) == 0, "capability 缺口在调用真实 owner prepare 前被 port 截断")
	_expect(before_roster == owner.roster_snapshot(true), "跨 owner dependency 缺能力时 roster call count=0 且 before==after")
	_cleanup(fixture)


func _verify_nonstarter_and_upgrade_paths_remain_closed() -> void:
	var rank_fixture := _fixture()
	var rank_owner: MonsterRuntimeController = rank_fixture.owner
	var rank_world: FixtureWorld = rank_fixture.world
	var rank_adapter = ADAPTER_SCRIPT.new()
	rank_adapter.configure(rank_owner)
	var rank_two: Dictionary = rank_adapter.prepare_effect(_intent(rank_owner, rank_world, "tx-rank-two", HUMAN_ACTOR, CARD_RANK_2))
	_expect(str(rank_two.get("reason_code", "")) == "monster_non_starter_deploy_deferred" and rank_owner.roster_snapshot(true).is_empty(), "Rank II–IV 不因 combined effect kind 而解锁")
	_cleanup(rank_fixture)

	var upgrade_fixture := _fixture()
	var upgrade_owner: MonsterRuntimeController = upgrade_fixture.owner
	var upgrade_world: FixtureWorld = upgrade_fixture.world
	var upgrade_adapter = ADAPTER_SCRIPT.new()
	upgrade_adapter.configure(upgrade_owner)
	var base: Dictionary = upgrade_adapter.commit_effect(upgrade_adapter.prepare_effect(_intent(upgrade_owner, upgrade_world, "tx-upgrade-base", HUMAN_ACTOR)))
	upgrade_adapter.finalize_effect(base)
	var actor: Dictionary = upgrade_owner.roster_snapshot(true)[0] as Dictionary
	var upgrade := SCHEMA.make_intent(
		"tx-upgrade-closed",
		HUMAN_ACTOR,
		CARD_RANK_1,
		"instance.tx-upgrade-closed",
		EFFECT_KIND,
		ACTION_KIND,
		int(upgrade_owner.unit_card_snapshot_v06("monster").get("owner_revision", -1)),
		{
			"valid": true,
			"unit_uid": int(actor.get("uid", 0)),
			"expected_actor_revision": int(actor.get("actor_revision_v06", 0)),
			"expected_binding_rule_revision": int(upgrade_world.rule_revisions.get(HUMAN_ACTOR, -1)),
		},
		_fields(1),
		{"anonymous_play": true, "hidden_owner": true}
	)
	var before := SCHEMA.fingerprint(upgrade_owner.roster_snapshot(true))
	var upgrade_rejected: Dictionary = upgrade_adapter.prepare_effect(upgrade)
	_expect(str(upgrade_rejected.get("reason_code", "")) == "fixture_profile_missing" and before == SCHEMA.fingerprint(upgrade_owner.roster_snapshot(true)), "缺少下一 Rank 权威 profile 时真实 adapter fail-closed")
	_cleanup(upgrade_fixture)


func _verify_real_owner_snapshot_private_snapshot_and_save_surface() -> void:
	var fixture := _fixture()
	var owner: MonsterRuntimeController = fixture.owner
	var world: FixtureWorld = fixture.world
	var committed: Dictionary = owner.commit_unit_card_intent_v06(owner.prepare_unit_card_intent_v06(_intent(owner, world, "tx-real-snapshot", HUMAN_ACTOR)))
	owner.finalize_unit_card_intent_v06(committed)
	var port = OWNER_PORT_SCRIPT.new()
	var configured: Dictionary = port.configure_owner(owner)
	_expect(bool(configured.get("configured", false)), "Monster owner forwarding port 可直接绑定真实 owner")
	var safe: Dictionary = port.safe_snapshot()
	_expect(bool(safe.get("available", false)) and int(safe.get("monster_count", 0)) == 1, "port safe snapshot 直接读取真实 production roster")
	var private: Dictionary = owner.monster_private_snapshot_v06(HUMAN_ACTOR)
	_expect(bool(private.get("available", false)) and str(private.get("domain", "")) == "monster" and (private.get("owned_units", []) as Array).size() == 1, "本人 private snapshot 只返回自己的最小单位 rows")
	_expect(str(private.get("starter_state", "")) == "summoned", "private snapshot 可查看本人的首召状态")
	var save: Dictionary = owner.unit_card_save_data_v06("monster")
	for key in ["monster_card_atomic_schema_version", "monster_card_atomic_owner_revision", "monster_card_atomic_starter_state", "monster_card_atomic_reservations", "monster_card_atomic_terminal_journal", "monster_card_atomic_presentation_journal"]:
		_expect(save.has(key), "真实 owner save envelope 使用冻结 flat key：%s" % key)
	_expect(bool(owner.unit_card_checkpoint_status_v06("monster").get("can_checkpoint", false)), "finalized production owner 可安全 checkpoint")
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
	return {"world": world, "bridge": bridge, "owner": owner}


func _cleanup(fixture: Dictionary) -> void:
	for key in ["owner", "bridge", "world"]:
		var node: Node = fixture.get(key)
		if node != null and is_instance_valid(node):
			node.free()


func _intent(owner: MonsterRuntimeController, world: FixtureWorld, transaction_id: String, actor_id: String, card_id: String = CARD_RANK_1) -> Dictionary:
	var rank := 2 if card_id == CARD_RANK_2 else 1
	return SCHEMA.make_intent(
		transaction_id,
		actor_id,
		card_id,
		"instance.%s" % transaction_id,
		EFFECT_KIND,
		ACTION_KIND,
		int(owner.unit_card_snapshot_v06("monster").get("owner_revision", 0)),
		{
			"valid": true,
			"region_id": REGION_ID,
			"expected_region_revision": world.region_revision,
			"expected_binding_rule_revision": int(world.rule_revisions.get(actor_id, -1)),
		},
		_fields(rank),
		{"anonymous_play": true, "hidden_owner": true}
	)


func _fields(rank: int) -> Dictionary:
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


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("MONSTER_CARD_REAL_OWNER_INTEGRATION_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("MONSTER_CARD_REAL_OWNER_INTEGRATION_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
