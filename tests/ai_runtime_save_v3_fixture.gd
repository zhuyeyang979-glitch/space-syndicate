extends RefCounted
class_name AiRuntimeSaveV3Fixture

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const RULESET_V04 := preload("res://resources/rules/space_syndicate_ruleset_v04.tres")


static func create(tree: SceneTree) -> Dictionary:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	tree.root.add_child(coordinator)
	await tree.process_frame
	coordinator.configure(RULESET_V04.debug_snapshot())
	var world := coordinator.world_session_state()
	var catalog := coordinator.get_node_or_null("RoleCatalogRuntimeService") as RoleCatalogRuntimeService
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var port := coordinator.get_node_or_null("AiActorStatePort") as AiActorStatePort
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	if world == null or catalog == null or session == null or ai == null or port == null or rng == null:
		return {"coordinator": coordinator, "ready": false}
	session.configure({"ruleset_id": "v0.6"}, {})
	session.begin_session({
		"session_id": "alpha04c-ai-save-v3-fixture",
		"scenario_id": "typed-owner-fixture",
		"seed": 900626424,
		"player_count": 4,
	})
	world.restore({
		"players": [
			_player(catalog, 0, false),
			_player(catalog, 1, true),
			_player(catalog, 2, true),
			_player(catalog, 3, true),
		],
		"districts": [],
		"game_time": 17.25,
		"map_width_m": 1000.0,
		"map_height_m": 600.0,
		"world_geometry_revision": 2,
	}, true)
	ai.configure({"ruleset_id": "v0.6"})
	ai._ensure_player_ai_state()
	return {
		"ready": true,
		"coordinator": coordinator,
		"world": world,
		"session": session,
		"ai": ai,
		"port": port,
		"rng": rng,
		"capability": ai.get("_ai_actor_state_capability"),
	}


static func enrich(fixture: Dictionary) -> Dictionary:
	var ai := fixture.get("ai") as AiRuntimeController
	var port := fixture.get("port") as AiActorStatePort
	var capability := fixture.get("capability") as AiActorStateCapability
	if ai == null or port == null or capability == null:
		return {"accepted": false, "reason_code": "fixture_not_ready"}
	var capture := port.capture_ai_state_batch_for_save(capability, true)
	var rows := (capture.get("rows", []) as Array).duplicate(true)
	for row_index in range(rows.size()):
		var row := rows[row_index] as Dictionary
		var memory := (row.get("ai_memory", {}) as Dictionary).duplicate(true)
		memory["decision_samples"] = [_decision_sample(row_index)]
		memory["action_counts"] = {
			"ordinary_card_purchase": row_index + 1,
			"legal_card_submission": 1,
		}
		memory["last_plan"] = "private-plan-redacted-%d" % row_index
		memory["economic_focus_product"] = "fixture-product-%d" % row_index
		memory["economic_focus_score"] = 120 + row_index
		memory["economic_focus_reason"] = "private-focus-redacted"
		memory["economic_focus_cycle"] = 3
		memory["economic_focus_rankings"] = [{"product": "fixture", "score": 120 + row_index}]
		memory["strategic_intent"] = "expand_route"
		memory["strategic_intent_score"] = 210 + row_index
		memory["strategic_intent_reason"] = "private-intent-redacted"
		memory["strategic_intent_cycle"] = 3
		memory["strategic_intent_rankings"] = [{"intent": "expand_route", "score": 210 + row_index}]
		memory["route_plan_product"] = "fixture-product-%d" % row_index
		memory["route_plan_stage"] = "supply"
		memory["route_plan_score"] = 330 + row_index
		memory["route_plan_reason"] = "private-route-redacted"
		memory["route_plan_cycle"] = 3
		memory["route_plan_target_city"] = row_index
		memory["route_plan_partner_district"] = row_index + 4
		memory["route_plan_rankings"] = [{"stage": "supply", "score": 330 + row_index}]
		memory["game_phase"] = "midgame"
		memory["competitive_posture"] = "trailing"
		memory["score_gap_to_leader"] = -40 - row_index
		memory["leader_index"] = 1
		memory["phase_reason"] = "private-phase-redacted"
		memory["learned_policy_values"] = {
			"action:ordinary_card_purchase": {
				"value": 1.23456789012345 + float(row_index) * 0.125,
				"samples": 2 + row_index,
				"reward_total": 31 + row_index,
				"last_reward": 17 + row_index,
				"last_cycle": 3,
			},
		}
		memory["learning_updates"] = row_index + 1
		memory["learning_last_reward"] = 17 + row_index
		memory["learning_last_tags"] = ["action:ordinary_card_purchase"]
		memory["episode_learning_updates"] = 1
		memory["episode_last_reward"] = 91 + row_index
		memory["episode_last_top_n_gdp"] = 140 + row_index
		memory["episode_last_controlled_regions"] = 2
		memory["episode_last_rank"] = row_index
		memory["episode_last_result"] = "characterized"
		row["ai_memory"] = memory
		rows[row_index] = row
	var applied := port.apply_ai_state_batch_for_restore(capability, rows)
	if not bool(applied.get("accepted", false)):
		return applied
	ai.ai_card_decision_timer = 0.0123456789012345
	ai.ai_auction_reaction_timer = 0.0345678901234567
	ai.ai_intel_decision_timer = 4.56789012345678
	ai.set("_game_action_request_sequence", 19)
	ai.commit_plan_receipt({
		"intent_id": "ai-game-action.1.19",
		"action_id": "ordinary-card-purchase",
		"applied": true,
		"reason": "committed",
		"context_revision": 7,
	})
	ai.set("_card_target_pre_submit_rejection_count", 2)
	ai.set("_tick_timing_count", {"runtime_tick": 3})
	ai.set("_tick_timing_total_usec", {"runtime_tick": 1700})
	ai.set("_tick_timing_max_usec", {"runtime_tick": 800})
	ai.set("_actor_state_tick_cache", {})
	ai.set("_actor_state_tick_cache_active", false)
	ai.set("_actor_state_tick_cache_hit_count", 4)
	ai.set("_actor_state_tick_cache_miss_count", 5)
	return {"accepted": true, "reason_code": "fixture_enriched", "row_count": rows.size()}


static func close(tree: SceneTree, fixture: Dictionary) -> void:
	var coordinator := fixture.get("coordinator") as Node
	if coordinator != null:
		coordinator.queue_free()
		await tree.process_frame


static func _decision_sample(index: int) -> Dictionary:
	return {
		"time": 17.1234567890123 + float(index) * 0.25,
		"cycle": 3,
		"kind": "ordinary_card_purchase",
		"target": index + 4,
		"score": 200 + index,
		"reason": "private-sample-redacted",
		"state": {"authorized_public_feature": 1},
		"candidates": [{"candidate_id": "redacted", "score": 200 + index}],
		"focus_product": "fixture-product-%d" % index,
		"focus_score": 120 + index,
		"focus_reason": "private-focus-redacted",
		"strategy_intent": "expand_route",
		"strategy_score": 210 + index,
		"strategy_reason": "private-intent-redacted",
		"route_plan_product": "fixture-product-%d" % index,
		"route_plan_stage": "supply",
		"route_plan_score": 330 + index,
		"route_plan_reason": "private-route-redacted",
		"game_phase": "midgame",
		"competitive_posture": "trailing",
		"score_gap_to_leader": -40 - index,
		"leader_index": 1,
		"phase_reason": "private-phase-redacted",
		"endgame_urgency": 10,
		"baseline_cash": 700,
		"baseline_victory_gdp": 100,
		"baseline_victory_regions": 1,
		"reward_cash": 20,
		"reward_victory_gdp": 3,
		"reward_victory_regions": 0,
		"reward_score": 35,
		"reward_finalized": true,
		"learning_applied": true,
	}


static func _player(catalog: RoleCatalogRuntimeService, player_index: int, is_ai: bool) -> Dictionary:
	var role := catalog.definition_at(player_index)
	role["role_index"] = player_index
	return {
		"id": player_index,
		"name": "AI-%d" % player_index if is_ai else "Human-%d" % player_index,
		"seat_type": "ai" if is_ai else "human",
		"is_ai": is_ai,
		"ai_profile": {},
		"ai_memory": {},
		"role_index": player_index,
		"role_card": role,
		"base_starting_cash": 700,
		"role_starting_cash_delta": 0,
		"starting_cash_total": 700,
		"cash": 700,
		"cash_cents": 70000,
		"cash_history": [],
		"v06_transaction_ledger": [],
		"eliminated": false,
		"eliminated_at": -1.0,
		"elimination_reason": "",
		"economic_ledger": [],
		"city_guesses": {},
		"city_guess_confidence": {},
		"city_guess_reasons": {},
		"cities_built": 0,
		"total_card_spend": 0,
		"card_purchase_count": 0,
		"total_build_spend": 0,
		"total_card_income": 0,
		"total_role_income": 0,
		"total_business_spend": 0,
		"action_cooldown": 0.0,
		"queued_card_tip": 0,
		"slots": [],
	}
