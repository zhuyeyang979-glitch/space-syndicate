extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SOURCES_SCENE := preload("res://scenes/runtime/ForcedDecisionCandidateSources.tscn")
const TARGET_SCENE := preload("res://scenes/runtime/CardTargetChoiceRuntimeController.tscn")
const PURCHASE_SCENE := preload("res://scenes/runtime/DistrictPurchaseRuntimeController.tscn")
const CARD_CONTROLLER_SCENE := preload("res://scenes/runtime/CardResolutionRuntimeController.tscn")
const QUEUE_SCENE := preload("res://scenes/runtime/CardResolutionQueueRuntimeService.tscn")
const CONTRACT_SCENE := preload("res://scenes/runtime/ContractRuntimeController.tscn")
const MONSTER_SCENE := preload("res://scenes/runtime/MonsterRuntimeController.tscn")
const SCHEDULER_SCENE := preload("res://scenes/runtime/ForcedDecisionRuntimeScheduler.tscn")
const BATTLE_LIFECYCLE_POLICY := preload("res://scripts/runtime/monster_battle_lifecycle_policy_v06.gd")

var _checks := 0
var _failures: Array[String] = []


class QuoteAuthority:
	extends Node

	func export_quote_for_session(_quote_id: String) -> Dictionary:
		return {}

	func restore_quote_from_session(_snapshot: Dictionary) -> Dictionary:
		return {"restored": true, "quote": {}}

	func quote_snapshot(_quote_id: String) -> Dictionary:
		return {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var monster := MONSTER_SCENE.instantiate() as MonsterRuntimeController
	var card_controller := CARD_CONTROLLER_SCENE.instantiate() as CardResolutionRuntimeController
	var queue := QUEUE_SCENE.instantiate() as CardResolutionQueueRuntimeService
	var contract := CONTRACT_SCENE.instantiate() as ContractRuntimeController
	var purchase := PURCHASE_SCENE.instantiate() as DistrictPurchaseRuntimeController
	var target := TARGET_SCENE.instantiate() as CardTargetChoiceRuntimeController
	var scheduler := SCHEDULER_SCENE.instantiate() as ForcedDecisionRuntimeScheduler
	var sources := SOURCES_SCENE.instantiate() as ForcedDecisionCandidateSources
	var quote_authority := QuoteAuthority.new()
	for node in [monster, card_controller, queue, contract, purchase, target, scheduler, sources, quote_authority]:
		root.add_child(node)
	scheduler.configure(["monster_wager", "counter_response", "contract_response", "other_choice"])
	purchase.set_quote_authority(quote_authority)
	purchase.configure()

	monster.auto_monsters = [
		{"slot": 0, "uid": 4101, "name": "候选怪兽A", "position": 0, "down": false},
		{"slot": 1, "uid": 4102, "name": "候选怪兽B", "position": 0, "down": false},
	]
	monster.active_monster_wagers = [_formal_wager_fixture(41)]
	card_controller.begin_counter(5.0)
	queue.replace_active_entry({"resolution_id": 42, "skill": {"name": "公开卡面"}, "player_index": 6})
	contract.pending_offers = [{
		"contract_response": "pending",
		"contract_offer_id": 43,
		"contract_target_owner": 1,
		"contract_source_owner": 7,
	}]
	purchase.open_window(2, 3, {"supply_revision": "rack-1"})
	purchase.acknowledge_card_selection(2, 3, "secret-card", "rack-1")
	purchase.attach_quote(2, 3, {"quote_id": "private-quote", "district_index": 3, "supply_revision": "rack-1", "card_id": "secret-card"})
	purchase.reserve_pending_discard({"player_index": 2, "district_index": 3, "card_id": "secret-card", "skill_name": "secret-card", "price": 777})
	target.begin_choice(CardTargetChoiceRuntimeController.KIND_MONSTER, 3, 4)
	target.begin_choice(CardTargetChoiceRuntimeController.KIND_PLAYER, 4, 5)
	sources.configure(monster, card_controller, queue, contract, purchase, target, scheduler)

	var first := sources.synchronize()
	var second := sources.synchronize()
	_expect(int(first.get("candidate_count", -1)) == 6, "all six authoritative forced-decision kinds are projected")
	_expect(bool(first.get("changed", false)) and not bool(second.get("changed", true)), "identical synchronization is idempotent")
	_expect(scheduler.active_priority_group() == "monster_wager" and scheduler.blocks_global_time(), "scheduler preserves public wager priority and block semantics")

	var source_debug := sources.debug_snapshot()
	var debug_text := JSON.stringify(source_debug)
	_expect(int(source_debug.get("candidate_count", -1)) == 6, "source debug reports aggregate count")
	for forbidden in ["owner_player_index", "cash", "hand", "card_id", "quote", "hidden_owner", "player_index", "slot_index"]:
		_expect(not debug_text.contains(forbidden), "source debug omits private field %s" % forbidden)
	var collected_text := JSON.stringify(sources.collect_candidates())
	_expect(not collected_text.contains("secret-card") and not collected_text.contains("private-quote") and not collected_text.contains("pending_attack"), "candidate descriptors omit card, quote, and wager internals")
	_expect(not collected_text.contains("battle_resolved") and not collected_text.contains("hidden_owner"), "candidate descriptors do not depend on retired wager fixture fields")

	monster.active_monster_wagers.clear()
	sources.synchronize()
	_expect(scheduler.active_priority_group() == "counter_response", "counter becomes active after wager closes")
	card_controller.counter_window_active = false
	contract.pending_offers = [contract.pending_offers[0]]
	purchase.resolve_pending_discard({"player_index": 2, "reason": "test"})
	target.clear_choice(CardTargetChoiceRuntimeController.KIND_MONSTER)
	target.clear_choice(CardTargetChoiceRuntimeController.KIND_PLAYER)
	sources.synchronize()
	var hidden := scheduler.active_decision(0)
	var visible := scheduler.active_decision(1)
	_expect(not bool(hidden.get("visible_to_viewer", true)) and bool(visible.get("visible_to_viewer", false)), "private contract decision is visible only to its owner")
	_expect(not JSON.stringify(hidden).contains("owner_player_index"), "non-owner placeholder omits private owner identity")

	target.begin_choice(CardTargetChoiceRuntimeController.KIND_PLAYER, 5, 6)
	var saved_target := target.to_save_data()
	target.reset_state()
	_expect(bool(target.apply_save_data(saved_target).get("applied", false)), "target-choice owner save applies")
	_expect(target.to_save_data() == saved_target, "target-choice save roundtrip is exact")

	var sources_text := FileAccess.get_file_as_string("res://scripts/runtime/forced_decision_candidate_sources.gd")
	_expect(not sources_text.contains("Main") and not sources_text.contains("current_scene") and not sources_text.contains("Callable"), "candidate source has no Main callback or service locator")

	var main := MAIN_SCENE.instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(main)
	await process_frame
	var production_sources := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ForcedDecisionCandidateSources")
	var production_target := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardTargetChoiceRuntimeController")
	_expect(production_sources != null and production_target != null, "production main scene composes the two prerequisite owners exactly once")
	main.queue_free()

	for node in [monster, card_controller, queue, contract, purchase, target, scheduler, sources, quote_authority]:
		node.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _formal_wager_fixture(wager_id: int) -> Dictionary:
	var competitors := [
		{"side": "a", "name": "候选怪兽A", "slot": 0, "uid": 4101, "damage": 0},
		{"side": "b", "name": "候选怪兽B", "slot": 1, "uid": 4102, "damage": 0},
	]
	return {
		"wager_id": wager_id,
		"settlement_revision": wager_id,
		"base_percent": 5,
		"competitors": competitors,
		"damage_a": 0,
		"damage_b": 0,
		"bets": {},
		"public_bets": [],
		"historical_public_pool": 0,
		"eligible_player_indices": [0, 1],
		"opening_cash_units_by_player": {"0": 100, "1": 100},
		"public_player_ids_by_index": {"0": "player.0", "1": "player.1"},
		"lifecycle_schema_version": BATTLE_LIFECYCLE_POLICY.SCHEMA_VERSION,
		"lifecycle_phase": BATTLE_LIFECYCLE_POLICY.PHASE_DECISION,
		"lifecycle_revision": 1,
		"decision_remaining_seconds": 15.0,
		"battle_limit_seconds": 60.0,
		"battle_remaining_seconds": 60.0,
		"locked_competitor_uids": [4101, 4102],
		"battle_roster_fingerprint": BATTLE_LIFECYCLE_POLICY.roster_fingerprint(competitors),
		"opening_attack_applied": true,
		"decision_open": true,
		"resolved": false,
	}


func _finish() -> void:
	if _failures.is_empty():
		print("Forced decision candidate sources cutover passed (%d checks)." % _checks)
		quit(0)
		return
	push_error("Forced decision candidate sources cutover failed:\n- " + "\n- ".join(_failures))
	quit(1)
