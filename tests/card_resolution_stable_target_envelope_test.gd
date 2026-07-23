extends SceneTree

const QUERY_SCENE := preload("res://scenes/runtime/presentation/TableSelectionCatalogQueryPort.tscn")
const StableTargetEnvelope := preload("res://scripts/runtime/card_resolution_stable_target_envelope.gd")

var _checks := 0
var _failures: Array[String] = []
var _host: Node
var _world: WorldSessionState
var _selection: TableSelectionState
var _market: ProductMarketRuntimeController
var _session: GameSessionRuntimeController
var _query: TableSelectionCatalogQueryPort


class StableFactsBridge:
	extends CardPlayEligibilityWorldBridge

	var contexts: Array = []

	func build_facts(_player_index: int, _skill: Dictionary, context: Dictionary = {}) -> Dictionary:
		contexts.append(context.duplicate(true))
		return {"player_valid": true}


class StableEligibilityService:
	extends CardPlayEligibilityRuntimeService

	func evaluate_play(request: Dictionary, _facts: Dictionary) -> Dictionary:
		var skill: Dictionary = request.get("skill", {}) if request.get("skill", {}) is Dictionary else {}
		var player_target := bool(skill.get("target_player_required", false))
		var monster_target := bool(skill.get("target_monster_required", false))
		return {
			"allowed": true,
			"reason_code": "playable",
			"requires_target_monster": monster_target,
			"requires_target_player": player_target,
			"cash_cost": 0,
			"financial_margin_cash": 0,
			"financial_terms_version": "",
			"asset_cost": {},
			"target_status": {
				"target_kind": "monster" if monster_target else ("player" if player_target else "none"),
				"is_counter": false,
			},
			"requirement_status": {
				"kind": "none",
				"scope": "",
				"qualifying_district": -1,
				"required_share_percent": 0,
				"requirement_text": "Condition: none",
			},
		}


class SubmissionCoordinator:
	extends GameRuntimeCoordinator

	var queue_service: CardResolutionQueueRuntimeService

	func plan_card_resolution_queue_submission(request_snapshot: Dictionary, facts: Dictionary) -> Dictionary:
		return queue_service.plan_submission(request_snapshot, facts)

	func commit_card_resolution_queue_submission(plan: Dictionary, commit_receipt: Dictionary) -> Dictionary:
		return queue_service.commit_submission(plan, commit_receipt)

	func plan_card_inventory_queue_commit(_request_snapshot: Dictionary) -> Dictionary:
		return {"ready": true}

	func commit_card_inventory_queue_commit(player_state: Dictionary, current_facts: Dictionary, _plan: Dictionary) -> Dictionary:
		var slots: Array = player_state.get("slots", []) if player_state.get("slots", []) is Array else []
		var target_slot := int(current_facts.get("target_slot", -1))
		if target_slot >= 0 and target_slot < slots.size():
			slots[target_slot] = (current_facts.get("queued_skill", {}) as Dictionary).duplicate(true)
			player_state["slots"] = slots
		return {"committed": true}

	func commodity_color_flow_snapshot(_player_index: int) -> Dictionary:
		return {}

	func player_mana_availability(_player_index: int) -> Dictionary:
		return {"available": true}


class FrozenMonsterOwner:
	extends MonsterRuntimeController

	var captured_districts: Array[int] = []

	func _summon_monster_from_card(_acting_player_index: int, _skill: Dictionary, target_district_index: int) -> bool:
		captured_districts.append(target_district_index)
		return true

	func _trigger_bound_monster_skill(_skill: Dictionary, _player: Dictionary, target_district_index: int) -> bool:
		captured_districts.append(target_district_index)
		return true


class FrozenMilitaryOwner:
	extends MilitaryRuntimeController

	var captured_districts: Array[int] = []

	func summon_from_card(_player_index: int, _skill: Dictionary, target_district_index: int) -> bool:
		captured_districts.append(target_district_index)
		return true

	func trigger_command(
		_skill: Dictionary,
		_target_slot: int = -1,
		_acting_player_index: int = -1,
		command_context: Dictionary = {}
	) -> bool:
		captured_districts.append(int(command_context.get("selected_district", -1)))
		return true

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_catalog_fixture()
	_test_envelope_contract()
	_test_target_choice_focus_drift()
	_test_effect_router_frozen_region_dispatch()
	_test_queue_and_privacy_contracts()
	_test_source_boundaries()
	_host.free()
	print("CardResolutionStableTargetEnvelope: %d checks / %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _build_catalog_fixture() -> void:
	_host = Node.new()
	root.add_child(_host)
	_world = WorldSessionState.new()
	_world.name = "WorldSessionState"
	_host.add_child(_world)
	_selection = TableSelectionState.new()
	_selection.name = "TableSelectionState"
	_host.add_child(_selection)
	_market = ProductMarketRuntimeController.new()
	_market.name = "ProductMarketRuntimeController"
	_host.add_child(_market)
	_session = GameSessionRuntimeController.new()
	_session.name = "GameSessionRuntimeController"
	_host.add_child(_session)
	_query = QUERY_SCENE.instantiate() as TableSelectionCatalogQueryPort
	_query.name = "TableSelectionCatalogQueryPort"
	_query.world_session_state_path = NodePath("../WorldSessionState")
	_query.product_market_runtime_controller_path = NodePath("../ProductMarketRuntimeController")
	_query.game_session_runtime_controller_path = NodePath("../GameSessionRuntimeController")
	_host.add_child(_query)
	_session.set("_configured", true)
	_session.set("_ruleset_id", "v0.6")
	_session.set("_session_state", GameSessionRuntimeController.STATE_RUNNING)
	_session.set("_session_id", "stable-target-session")
	_session.set("_scenario_id", "stable-target-focused")
	_session.set("_seed", 8128)
	_session.set("_setup_summary", {"player_count": 3, "source": "focused_test"})
	_world.replace_players([
		_player_fixture(0),
		_player_fixture(1),
		_player_fixture(2),
	], true)
	_world.replace_districts(_district_fixture(), true)
	_selection.restore({
		"selected_player": 0,
		"inspected_player": 0,
		"selected_district": 0,
		"selected_trade_product": ProductMarketRuntimeController.PRODUCT_CATALOG[0],
		"selected_card_resolution_id": 17,
		"selected_hand_slot": 0,
		"selected_map_layer_focus": "all",
	})


func _test_envelope_contract() -> void:
	var envelope := StableTargetEnvelope.capture(
		_selection.snapshot(),
		_query.compose_region_catalog(),
		_query.compose_product_catalog(),
		{"target_kind": StableTargetEnvelope.TARGET_PLAYER, "capture_source": "focused_test"}
	)
	_expect(bool(StableTargetEnvelope.validate(envelope).get("valid", false)), "pending target envelope is valid pure data")
	_expect(TablePresentationPureDataPolicy.is_pure_data(envelope), "target envelope contains pure data only")
	_expect(str(envelope.get("region_id", "")) == "region.000", "envelope freezes stable region identity")
	_expect(str(envelope.get("product_id", "")) == ProductMarketRuntimeController.PRODUCT_CATALOG[0], "envelope freezes stable product identity")
	_expect(int(envelope.get("selected_card_resolution_id", -1)) == 17, "envelope freezes selected resolution identity")
	var bound := StableTargetEnvelope.bind_target(envelope, StableTargetEnvelope.TARGET_PLAYER, -1, 1)
	_expect(bool(StableTargetEnvelope.validate(bound).get("valid", false)), "pending envelope binds one explicit player target")
	var tampered := bound.duplicate(true)
	tampered["region_id"] = "region.001"
	_expect(not bool(StableTargetEnvelope.validate(tampered).get("valid", false)), "fingerprint rejects stable region tampering")
	var unresolved_entry := StableTargetEnvelope.context_at_capture(envelope)
	unresolved_entry["stable_target_envelope"] = envelope
	_expect(not bool(StableTargetEnvelope.validate_entry_binding(unresolved_entry).get("valid", false)), "queue binding rejects unresolved target")
	var monster_pending := StableTargetEnvelope.capture(
		_selection.snapshot(),
		_query.compose_region_catalog(),
		_query.compose_product_catalog(),
		{"target_kind": StableTargetEnvelope.TARGET_MONSTER, "capture_source": "focused_test"}
	)
	var monster_bound := StableTargetEnvelope.bind_target(monster_pending, StableTargetEnvelope.TARGET_MONSTER, 0, -1, 42)
	_expect(bool(StableTargetEnvelope.validate(monster_bound).get("valid", false)) and int(StableTargetEnvelope.context_at_capture(monster_bound).get("target_monster_uid", -1)) == 42, "monster target envelope fingerprints the stable monster UID together with its slot mirror")
	var monster_tampered := monster_bound.duplicate(true)
	monster_tampered["target_monster_uid"] = 43
	_expect(not bool(StableTargetEnvelope.validate(monster_tampered).get("valid", false)), "monster UID tampering invalidates the target envelope")


func _test_target_choice_focus_drift() -> void:
	var queue := CardResolutionQueueRuntimeService.new()
	queue.configure(_queue_rules())
	var resolution := CardResolutionRuntimeController.new()
	resolution.configure(_queue_rules().get("card_group", {}))
	var target_choice := CardTargetChoiceRuntimeController.new()
	var facts := StableFactsBridge.new()
	var eligibility := StableEligibilityService.new()
	var coordinator := SubmissionCoordinator.new()
	coordinator.queue_service = queue
	var submission := CardPlaySubmissionRuntimeController.new()
	submission.set_dependencies(
		_world,
		_selection,
		facts,
		eligibility,
		queue,
		resolution,
		target_choice,
		_market,
		null,
		_query,
		coordinator
	)
	var prepared_monster := submission._prepare_legacy_submission(0, {
		"name": "Focused Monster Target",
		"kind": "monster_lure",
		"target_monster_required": true,
		"persistent": false,
	}, "rule", {
		"target_slot": 0,
		"target_monster_uid": 42,
		"target_player": -1,
		"submission_source": "focused_monster_uid",
	})
	var prepared_envelope: Dictionary = prepared_monster.get("envelope", {}) if prepared_monster.get("envelope", {}) is Dictionary else {}
	var prepared_context := StableTargetEnvelope.context_at_capture(prepared_envelope)
	_expect(bool(prepared_monster.get("prepared", false)) and int(prepared_context.get("target_monster_uid", -1)) == 42, "CardPlaySubmissionRuntimeController carries the stable Monster UID into its official envelope")
	var monster_owner := MonsterRuntimeController.new()
	monster_owner.auto_monsters = [
		{"uid": 42, "slot": 0, "name": "Alpha", "hp": 10, "down": false},
		{"uid": 43, "slot": 1, "name": "Beta", "hp": 10, "down": false},
	]
	var effect_router := CardEffectRuntimeRouter.new()
	effect_router.set_dependencies(_world, _selection, monster_owner, null, null, null, null, null, null, null, null)
	_expect(effect_router._resolved_monster_target_slot({"target_slot": 0, "target_monster_uid": 42}) == 0, "effect routing resolves the original Monster slot by stable UID")
	monster_owner.auto_monsters = [monster_owner.auto_monsters[1], monster_owner.auto_monsters[0]]
	_expect(effect_router._resolved_monster_target_slot({"target_slot": 0, "target_monster_uid": 42}) == 1, "slot drift follows the Monster UID instead of striking the old array position")
	effect_router.free()
	monster_owner.free()

	var begin := submission.request_hand_play({
		"player_index": 0,
		"slot_index": 0,
		"selected_card_resolution_id": 17,
		"submission_source": "human",
	})
	_expect(bool(begin.get("target_choice_started", false)), "first card intent opens typed target choice")
	var pending := target_choice.choice_snapshot(CardTargetChoiceRuntimeController.KIND_PLAYER)
	var pending_envelope: Dictionary = pending.get("stable_target_envelope", {}) if pending.get("stable_target_envelope", {}) is Dictionary else {}
	_expect(str(pending_envelope.get("region_id", "")) == "region.000", "target choice owns the first-intent region binding")
	_expect(str(pending_envelope.get("product_id", "")) == ProductMarketRuntimeController.PRODUCT_CATALOG[0], "target choice owns the first-intent product binding")
	var saved_choice := target_choice.to_save_data()
	var saved_choice_text := JSON.stringify(saved_choice)
	_expect(not saved_choice_text.contains("stable_target_envelope") and not saved_choice_text.contains("source_card_fingerprint"), "target-choice schema v1 remains byte-shape compatible")

	_selection.restore({
		"selected_district": 1,
		"selected_trade_product": ProductMarketRuntimeController.PRODUCT_CATALOG[1],
		"selected_card_resolution_id": 99,
	})
	var submitted := submission.submit_card_play({
		"player_index": 0,
		"slot_index": 0,
		"target_slot": -1,
		"target_player": 1,
		"selected_card_resolution_id": 99,
		"submission_source": "human_target_choice",
	})
	_expect(bool(submitted.get("accepted", false)) and bool(submitted.get("queued", false)), "target continuation enters the authoritative queue")
	var entry := queue.current_queue()[0] as Dictionary
	_expect(int(entry.get("selected_district", -1)) == 0, "queue retains first-intent district index despite UI drift")
	_expect(str(entry.get("selected_trade_product", "")) == ProductMarketRuntimeController.PRODUCT_CATALOG[0], "queue retains first-intent product despite UI drift")
	_expect(int(entry.get("selected_card_resolution_id", -1)) == 17, "queue retains first-intent card-resolution focus despite UI drift")
	_expect(int(entry.get("target_player", -1)) == 1, "queue binds the later explicit target without resampling focus")
	_expect(entry.get("stable_target_envelope", {}) is Dictionary, "official submission carries one detached stable target envelope")
	_expect(facts.contexts.size() >= 2 and int((facts.contexts.back() as Dictionary).get("selected_district", -1)) == 0, "final eligibility revalidation consumes frozen context")

	var reordered := _district_fixture()
	reordered = [reordered[1], reordered[0], reordered[2]]
	_world.replace_districts(reordered, true)
	var resolved := StableTargetEnvelope.resolved_entry(entry, _world)
	_expect(bool(resolved.get("valid", false)), "delayed execution resolves a valid stable target")
	var resolved_entry: Dictionary = resolved.get("entry", {}) if resolved.get("entry", {}) is Dictionary else {}
	_expect(int(resolved_entry.get("selected_district", -1)) == 1, "delayed execution follows region ID after authoritative reorder")
	_expect(str((reordered[int(resolved_entry.get("selected_district", -1))] as Dictionary).get("region_id", "")) == "region.000", "resolved district still names the originally selected region")
	var facility_entry := entry.duplicate(true)
	var facility_skill: Dictionary = facility_entry.get("skill", {}) if facility_entry.get("skill", {}) is Dictionary else {}
	facility_skill["kind"] = "public_facility"
	facility_skill["target_region_index"] = 0
	facility_entry["skill"] = facility_skill
	var resolved_facility := StableTargetEnvelope.resolved_entry(facility_entry, _world)
	var resolved_facility_entry: Dictionary = resolved_facility.get("entry", {}) if resolved_facility.get("entry", {}) is Dictionary else {}
	var resolved_facility_skill: Dictionary = resolved_facility_entry.get("skill", {}) if resolved_facility_entry.get("skill", {}) is Dictionary else {}
	_expect(int(resolved_facility_skill.get("target_region_index", -1)) == 1, "public-facility execution mirror follows the resolved stable region")

	target_choice.reset_state()
	var restored_choice := target_choice.apply_save_data(saved_choice)
	_expect(bool(restored_choice.get("applied", false)) and int(restored_choice.get("choice_count", 0)) == 1, "schema-v1 target choice restores through the production save API")
	var legacy_resume := submission.submit_card_play({"player_index": 0, "slot_index": 0, "target_player": 1})
	_expect(not bool(legacy_resume.get("accepted", false)) and str(legacy_resume.get("reason", "")) == "stable_target_context_missing", "restored schema-v1 target choice fails closed instead of sampling current UI")
	for node in [submission, coordinator, eligibility, facts, target_choice, resolution, queue]:
		node.free()
	_world.replace_districts(_district_fixture(), true)


func _test_effect_router_frozen_region_dispatch() -> void:
	_selection.restore({"selected_district": 2})
	var monster_owner := FrozenMonsterOwner.new()
	var military_owner := FrozenMilitaryOwner.new()
	var router := CardEffectRuntimeRouter.new()
	router.set_dependencies(_world, _selection, monster_owner, military_owner, null, null, null, null, null, null, null)
	var frozen_entry := {"selected_district": 0, "resolution_id": 6401}
	var player := _world.players[0] as Dictionary
	var monster_summon := router._dispatch_domain_handler("monster_card", 0, player, frozen_entry, {"kind": "monster_card"})
	var monster_bound := router._dispatch_domain_handler("monster_bound_action", 0, player, frozen_entry, {"kind": "monster_bound_action"})
	var military_summon := router._dispatch_domain_handler("military_force", 0, player, frozen_entry, {"kind": "military_force"})
	var military_command := router._dispatch_domain_handler("military_command", 0, player, frozen_entry, {"kind": "military_command"})
	var military_targeted := router._resolve_targeted_skill({"kind": "military_command"}, player, 0, 0, 0, frozen_entry)
	_expect(
		monster_summon and monster_bound \
			and monster_owner.captured_districts == [0, 0],
		"Monster summon and bound actions receive the frozen queue district"
	)
	_expect(
		military_summon and military_command and military_targeted \
			and military_owner.captured_districts == [0, 0, 0],
		"Military deploy and command actions receive the frozen queue district"
	)
	_expect(int(_selection.selected_district) == 2, "effect routing neither reads nor mutates the live table district focus")
	for node in [router, monster_owner, military_owner]:
		node.free()

func _test_queue_and_privacy_contracts() -> void:
	var queue := CardResolutionQueueRuntimeService.new()
	queue.configure(_queue_rules())
	var selection_snapshot := _selection.snapshot()
	selection_snapshot["selected_district"] = 0
	selection_snapshot["selected_trade_product"] = ProductMarketRuntimeController.PRODUCT_CATALOG[0]
	selection_snapshot["selected_card_resolution_id"] = 17
	var envelope := StableTargetEnvelope.capture(selection_snapshot, _query.compose_region_catalog(), _query.compose_product_catalog(), {})
	var context := StableTargetEnvelope.context_at_capture(envelope)
	context["stable_target_envelope"] = envelope
	var accepted := queue.plan_submission(_queue_request(context), _queue_facts())
	_expect(bool(accepted.get("accepted", false)), "queue accepts a valid stable no-target envelope")
	var mismatch := context.duplicate(true)
	mismatch["selected_district"] = 1
	var rejected := queue.plan_submission(_queue_request(mismatch), _queue_facts())
	_expect(not bool(rejected.get("accepted", false)) and str(rejected.get("reason", "")) == "stable_target_legacy_mirror_mismatch", "queue rejects envelope/legacy mirror drift")
	var legacy_context := context.duplicate(true)
	legacy_context.erase("stable_target_envelope")
	_expect(bool(queue.plan_submission(_queue_request(legacy_context), _queue_facts()).get("accepted", false)), "legacy fixtures remain accepted without reading live UI focus")
	var committed := queue.commit_submission(accepted, {
		"authorized": true,
		"inventory_committed": true,
		"play_cost_authorized": true,
		"financial_margin_authorized": true,
		"asset_authorized": true,
	})
	_expect(bool(committed.get("committed", false)), "validated envelope reaches the real queue owner")
	var public_text := JSON.stringify(queue.public_snapshot())
	_expect(not public_text.contains("stable_target_envelope") and not public_text.contains("envelope_fingerprint"), "public queue projection never exposes the internal envelope")
	queue.free()


func _test_source_boundaries() -> void:
	var submission_source := FileAccess.get_file_as_string("res://scripts/runtime/card_play_submission_runtime_controller.gd")
	var sink_source := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_transition_sink.gd")
	var commitment_source := FileAccess.get_file_as_string("res://scripts/runtime/card_commitment_runtime_service.gd")
	var history_source := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_execution_world_bridge.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var game_screen_source := FileAccess.get_file_as_string("res://scripts/ui/game_screen.gd")
	var response_sink_source := FileAccess.get_file_as_string("res://scripts/runtime/card_target_choice_response_sink.gd")
	_expect(not submission_source.contains("_table_selection_state.selected_district") and not submission_source.contains("_table_selection_state.selected_trade_product"), "submission never re-reads mutable focus after capture")
	_expect(sink_source.contains("StableTargetEnvelope.resolved_entry(entry, _world_session)"), "transition sink resolves stable IDs before planning execution")
	_expect(commitment_source.contains("build_facts(player_index, skill, context)"), "commitment cost revalidation receives frozen context")
	_expect(history_source.contains("entry.erase(\"stable_target_envelope\")"), "history strips the private execution envelope")
	_expect(game_screen_source.contains("forced_decision_response_requested.emit(request)") and response_sink_source.contains("_submission_owner().submit_card_play(submit_request)"), "human target continuation reaches the shared submission owner through the typed forced-decision path")
	_expect(not coordinator_source.contains("func begin_card_target_choice(") and not coordinator_source.contains("func clear_card_target_choice(") and not coordinator_source.contains("func apply_card_target_choice_legacy_state("), "coordinator exposes no legacy target-choice mutation facade")
	_expect(not submission_source.contains("current_scene") and not submission_source.contains("/root/Main"), "stable target submission has no Main discovery fallback")


func _queue_request(entry_context: Dictionary) -> Dictionary:
	return {
		"player_index": 0,
		"slot_index": 0,
		"already_queued": false,
		"reactive_counter": false,
		"group_card_limit": 1,
		"play_cash_cost_cents": 0,
		"financial_margin_cents": 0,
		"available_cash_cents": 10000,
		"cash_revision": "100",
		"asset_cost": {},
		"skill": {"name": "Stable Target Test", "kind": "generic", "persistent": false},
		"entry_context": entry_context,
	}


func _queue_facts() -> Dictionary:
	return {
		"player_count": 3,
		"counter_window_active": false,
		"batch_locked": false,
		"simultaneous_timer": 20.0,
		"lock_duration": 5.0,
		"public_bid_duration": 5.0,
		"window_sequence": 1,
		"reference_player": 0,
	}


func _queue_rules() -> Dictionary:
	return {
		"ruleset_id": "v0.6",
		"card_group": {
			"group_seconds": 30,
			"planning_seconds": 20,
			"public_bid_seconds": 5,
			"lock_seconds": 5,
			"opening_extended_windows": 3,
			"opening_group_seconds": 45,
			"opening_planning_seconds": 35,
			"ordinary_card_limit": 1,
			"maximum_with_explicit_capability": 3,
		},
	}


func _player_fixture(index: int) -> Dictionary:
	var card := {
		"name": "Player Target %d" % index,
		"kind": "player_hand_disrupt",
		"target_player_required": true,
		"persistent": false,
	}
	return {
		"id": index,
		"actor_id": "player.%d" % index,
		"name": "Player %d" % (index + 1),
		"cash": 100,
		"eliminated": false,
		"queued_card_tip": 0,
		"slots": [card.duplicate(true), card.duplicate(true)],
	}


func _district_fixture() -> Array:
	return [
		{"region_id": "region.000", "name": "Alpha", "terrain": "land", "destroyed": false},
		{"region_id": "region.001", "name": "Beta", "terrain": "ocean", "destroyed": false},
		{"region_id": "region.002", "name": "Gamma", "terrain": "land", "destroyed": false},
	]


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
