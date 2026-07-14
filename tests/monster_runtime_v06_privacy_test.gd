extends SceneTree

const SCHEMA := preload("res://scripts/cards/v06/units/unit_card_runtime_schema_v06.gd")
const FILTER := preload("res://scripts/cards/v06/units/unit_card_receipt_filter_v06.gd")
const CONTROLLER_SCRIPT := preload("res://scripts/runtime/monster_runtime_controller.gd")
const WORLD_BRIDGE_SCRIPT := preload("res://scripts/runtime/monster_runtime_world_bridge.gd")

const CARD_ID := "unit.monster.spore_tide_emperor.rank_1"
const FAMILY_ID := "spore_tide_emperor"
const ACTOR_ID := "human.alpha"
const OTHER_ACTOR_ID := "ai.beta"
const REGION_ID := "region.alpha"

var _checks := 0
var _failures: Array[String] = []


class PrivacyWorld:
	extends Node

	var players: Array = [
		{"actor_id": ACTOR_ID, "cash": 123, "slots": ["PRIVATE-HUMAN-HAND"]},
		{"actor_id": OTHER_ACTOR_ID, "cash": 987, "slots": ["PRIVATE-AI-HAND"], "ai_plan": "PRIVATE-AI-PLAN"},
	]
	var districts: Array = [{"name": "阿尔法区", "center": Vector2(80.0, 160.0)}]
	var game_time := 0.0
	var selected_player := 0
	var selected_district := 0
	var rng := RandomNumberGenerator.new()
	var events: Array = []

	func _init() -> void:
		rng.seed = 61107

	func monster_deploy_region_snapshot_v06(region_id: String) -> Dictionary:
		if region_id != REGION_ID:
			return {"available": false, "authoritative": false, "region_id": region_id, "reason_code": "fixture_region_missing"}
		return {
			"available": true,
			"authoritative": true,
			"region_id": REGION_ID,
			"display_name": "阿尔法区",
			"revision": 7,
			"region_index": 0,
			"destroyed": false,
			"starter_summon_allowed": true,
			"allowed_monster_families": [FAMILY_ID],
			"world_position": {"x": 80.0, "y": 160.0},
		}

	func monster_deploy_profile_snapshot_v06(family_id: String, rank: int) -> Dictionary:
		if family_id != FAMILY_ID or rank != 1:
			return {"available": false, "authoritative": false, "family_id": family_id, "rank": rank}
		return {
			"available": true,
			"authoritative": true,
			"family_id": FAMILY_ID,
			"rank": 1,
			"revision": 9,
			"profile_id": "monster.profile.spore_tide_emperor.rank_1",
			"name": "孢雾海皇",
			"catalog_index": 0,
			"hp": 42,
			"move_mps": 18.5,
			"initial_duration_seconds": 137.0,
			"starter_play_free": true,
			"is_starter": true,
		}

	func monster_deploy_rule_snapshot_v06(actor_id: String) -> Dictionary:
		if not [ACTOR_ID, OTHER_ACTOR_ID].has(actor_id):
			return {"available": false, "authoritative": false, "actor_id": actor_id}
		return {
			"available": true,
			"authoritative": true,
			"actor_id": actor_id,
			"player_index": 0 if actor_id == ACTOR_ID else 1,
			"revision": 11 if actor_id == ACTOR_ID else 13,
			"starter_entitled": true,
			"starter_consumed": false,
			"first_summon_state": "not_summoned",
			"starter_card_id": CARD_ID,
			"monster_binding_limit": 1,
		}

	func monster_deploy_cross_owner_capabilities_v06() -> Dictionary:
		var result := {
			"contract_version": "v0.6",
			"region_facts": {"revisioned_snapshot": true, "owner_id": "privacy.region"},
			"monster_profile": {"revisioned_snapshot": true, "owner_id": "privacy.profile"},
			"binding_rule": {"revisioned_snapshot": true, "owner_id": "privacy.binding"},
		}
		for participant in ["bound_skill_inventory", "product_market_rng", "role_cash_ledger"]:
			result[participant] = {
				"owner_id": "privacy.%s" % participant,
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
		return _stage("prepared", request)

	func commit_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		return _stage("committed", request)

	func rollback_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		return _stage("rolled_back", request)

	func finalize_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
		return _stage("finalized", request)

	func _on_monster_runtime_event(event: Dictionary) -> Dictionary:
		events.append(event.duplicate(true))
		return {"accepted": true}

	func _stage(success_key: String, request: Dictionary) -> Dictionary:
		return {
			success_key: true,
			"transaction_id": str(request.get("transaction_id", "")),
			"participant_binding_fingerprint": str(request.get("participant_binding_fingerprint", "")),
		}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := _fixture()
	var owner: MonsterRuntimeController = fixture.owner
	var world: PrivacyWorld = fixture.world
	var intent := _intent(owner, "tx-privacy-deploy", ACTOR_ID, REGION_ID, 7, 11)
	var committed: Dictionary = owner.commit_unit_card_intent_v06(owner.prepare_unit_card_intent_v06(intent))
	var finalized: Dictionary = owner.finalize_unit_card_intent_v06(committed)
	_expect(bool(finalized.get("finalized", false)), "隐私 fixture 先通过真实 owner 完成 I 级首召")
	_verify_public_and_private_snapshots(owner)
	_verify_receipt_filter(finalized)
	_verify_localized_failure(owner)
	_cleanup(fixture)
	_finish()


func _verify_public_and_private_snapshots(owner: MonsterRuntimeController) -> void:
	var private_truth: Array = owner.roster_snapshot(true)
	_expect(private_truth.size() == 1 and str((private_truth[0] as Dictionary).get("owner_actor_id_v06", "")) == ACTOR_ID, "developer/private roster 保留真实 owner 绑定供诊断")

	var public_snapshot: Dictionary = owner.unit_card_snapshot_v06("monster")
	var public_json := JSON.stringify(public_snapshot)
	var public_leaks := _privacy_leaks(public_snapshot)
	_expect(bool(public_snapshot.get("available", false)) and int(public_snapshot.get("monster_count", 0)) == 1, "public snapshot 来自真实 production roster")
	_expect(public_leaks.is_empty(), "public snapshot 独立递归隐私扫描为 0")
	_expect(not public_json.contains(ACTOR_ID) and not public_json.contains("PRIVATE-") and not public_json.contains("987"), "public snapshot 不泄漏 owner、手牌、现金或 AI metadata 值")
	_expect(not public_snapshot.has("starter_state") and not public_json.contains("owner_damage_cash") and not public_json.contains("bound_skill"), "public snapshot 不暴露首召 marker、内部现金 meter 或私有技能")
	var public_roster: Array = public_snapshot.get("roster", []) as Array
	_expect(not public_roster.is_empty() and not (public_roster[0] as Dictionary).has("owner_actor_id_v06"), "public monster row 保留单位事实但移除隐藏归属")

	var own_private: Dictionary = owner.monster_private_snapshot_v06(ACTOR_ID)
	var owned_units: Array = own_private.get("owned_units", []) as Array
	_expect(bool(own_private.get("available", false)) and str(own_private.get("domain", "")) == "monster" and str(own_private.get("starter_state", "")) == "summoned", "private API 只向本人返回首召状态")
	_expect(not own_private.has("viewer_actor_id") and not JSON.stringify(own_private).contains(ACTOR_ID), "private API 不回显 viewer actor ID")
	_expect(owned_units.size() == 1, "private API 只返回本人的 owned_units，而非全局 roster")
	if not owned_units.is_empty():
		var row: Dictionary = owned_units[0] as Dictionary
		for key in ["unit_uid", "family_id", "rank", "hp", "max_hp", "region_index", "down", "actor_revision", "suspended_for_new_upgrade", "binding_status"]:
			_expect(row.has(key), "private owned unit 使用冻结最小字段：%s" % key)
		_expect(_privacy_leaks(row).is_empty() and not JSON.stringify(row).contains("capability_fingerprint"), "private 最小 row 不复制 owner truth、组织 capability、现金、手牌、技能或 AI 数据")

	var other_private: Dictionary = owner.monster_private_snapshot_v06(OTHER_ACTOR_ID)
	_expect(bool(other_private.get("available", false)) and (other_private.get("owned_units", []) as Array).is_empty(), "其他 actor 看不到本人的隐藏怪兽归属")
	var public_roster_legacy := owner.roster_snapshot(false)
	_expect(not JSON.stringify(public_roster_legacy).contains(ACTOR_ID) and _privacy_leaks(public_roster_legacy).is_empty(), "legacy public roster surface 同样移除 owner_actor_id_v06")

	var developer: Dictionary = owner.monster_card_developer_snapshot_v06()
	_expect(JSON.stringify(developer).contains("tx-privacy-deploy") and not public_json.contains("tx-privacy-deploy"), "developer journal 可诊断 transaction，但 public snapshot 不可见")


func _verify_receipt_filter(finalized: Dictionary) -> void:
	var raw := finalized.duplicate(true)
	raw["true_owner"] = ACTOR_ID
	raw["hidden_owner"] = {"actor_id": ACTOR_ID, "cash": 123}
	raw["ai_private"] = {"ai_plan": "PRIVATE-AI-PLAN"}
	raw["private_fields"] = {
		"bound_unit_uid": int(finalized.get("unit_uid", 0)),
		"own_unit_state": {"rank": 1, "opponent_cash": 987, "ai_plan": "PRIVATE-AI-PLAN"},
	}
	raw["public_fields"] = {
		"unit_public_id": "monster-public-1",
		"unit_rank": 1,
		"target_public": {"region_id": REGION_ID, "owner_truth": ACTOR_ID},
		"public_changes": [{"visible_change": "怪兽已出现", "opponent_hand": ["PRIVATE-AI-HAND"]}],
	}
	var public_receipt: Dictionary = FILTER.public_view(raw)
	var built_in_scan: Dictionary = FILTER.public_leak_scan(public_receipt)
	var public_json := JSON.stringify(public_receipt)
	_expect(bool(built_in_scan.get("safe", false)) and int(built_in_scan.get("leak_count", -1)) == 0, "receipt allowlist + recursive sanitizer 的内建扫描为 0")
	_expect(_privacy_leaks(public_receipt).is_empty(), "独立递归 scanner 同样确认 public receipt 零泄漏")
	_expect(not public_receipt.has("transaction_id") and not public_receipt.has("reason_code") and not public_json.contains(ACTOR_ID) and not public_json.contains("PRIVATE-"), "public receipt 不暴露 machine/developer/private 绑定和值")

	var own_view: Dictionary = FILTER.private_view(raw, ACTOR_ID)
	var rival_view: Dictionary = FILTER.private_view(raw, OTHER_ACTOR_ID)
	_expect(own_view.has("private") and not rival_view.has("private"), "receipt private fields 只向 matching actor 开放")
	_expect(not JSON.stringify(own_view).contains("987") and not JSON.stringify(own_view).contains("PRIVATE-AI-PLAN"), "本人 private receipt 仍递归移除对手资源和 AI 计划")


func _verify_localized_failure(owner: MonsterRuntimeController) -> void:
	var failure: Dictionary = owner.prepare_unit_card_intent_v06(_intent(
		owner,
		"tx-privacy-failure",
		OTHER_ACTOR_ID,
		"region.missing",
		7,
		13
	))
	var feedback: Dictionary = failure.get("player_feedback", {}) as Dictionary
	var reason := str(feedback.get("reason", ""))
	var next_step := str(feedback.get("next_step", ""))
	_expect(not bool(failure.get("prepared", true)) and _has_non_ascii(reason) and _has_non_ascii(next_step), "失败 receipt 同时提供本地化原因与下一步")
	var player_view: Dictionary = FILTER.public_view(failure)
	var encoded := JSON.stringify(player_view)
	_expect(not encoded.contains("reason_code") and not encoded.contains("card_id") and not encoded.contains("raw_error") and not encoded.contains("region.missing"), "玩家失败文本不使用内部 ID、路径或英文开发 fallback")


func _fixture() -> Dictionary:
	var world := PrivacyWorld.new()
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


func _intent(owner: MonsterRuntimeController, transaction_id: String, actor_id: String, region_id: String, region_revision: int, rule_revision: int) -> Dictionary:
	return SCHEMA.make_intent(
		transaction_id,
		actor_id,
		CARD_ID,
		"instance.%s" % transaction_id,
		"deploy_or_upgrade_monster",
		"deploy_or_upgrade_monster",
		int(owner.unit_card_snapshot_v06("monster").get("owner_revision", 0)),
		{
			"valid": true,
			"region_id": region_id,
			"expected_region_revision": region_revision,
			"expected_binding_rule_revision": rule_revision,
		},
		{
			"monster_family_id": FAMILY_ID,
			"card_rank": 1,
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
		},
		{"anonymous_play": true, "hidden_owner": true}
	)


func _privacy_leaks(value: Variant, path: String = "$") -> Array[String]:
	var leaks: Array[String] = []
	_scan_privacy(value, path, leaks)
	return leaks


func _scan_privacy(value: Variant, path: String, leaks: Array[String]) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var lowered := key.to_lower()
			var allowed_public_owner_field := lowered in ["owner_revision", "owner_revealed"]
			if not allowed_public_owner_field and (
				lowered == "owner"
				or lowered.contains("actor_id")
				or lowered.contains("owner_")
				or lowered.contains("player_index")
				or lowered.contains("cash")
				or lowered.contains("hand")
				or lowered.contains("inventory")
				or lowered.contains("lure")
				or lowered.contains("bound_skill")
				or lowered.contains("ai_")
			):
				leaks.append("%s.%s" % [path, key])
			_scan_privacy((value as Dictionary).get(key_variant), "%s.%s" % [path, key], leaks)
	elif value is Array:
		for index in range((value as Array).size()):
			_scan_privacy((value as Array)[index], "%s[%d]" % [path, index], leaks)


func _has_non_ascii(value: String) -> bool:
	for index in range(value.length()):
		if value.unicode_at(index) > 127:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("MONSTER_RUNTIME_V06_PRIVACY_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("MONSTER_RUNTIME_V06_PRIVACY_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
