extends SceneTree

const RETIRED_PATHS := [
	"res://scripts/runtime/contract_runtime_controller.gd",
	"res://scripts/runtime/contract_runtime_world_bridge.gd",
	"res://scripts/ui/contract_response_decision_panel.gd",
	"res://scenes/runtime/ContractRuntimeController.tscn",
	"res://scenes/runtime/ContractRuntimeWorldBridge.tscn",
	"res://scenes/ui/ContractResponseDecisionPanel.tscn",
]
const RETIRED_CARD_IDS := [
	"区域供需合约1", "区域供需合约2", "组合供需合约1", "自动撮合合约1",
	"环晶电池专供1", "双边对冲合约1", "惩罚性拒签条款1",
	"密约回溯1", "密约回溯2",
]
const ACTIVE_DECISION_SCRIPTS := [
	"res://scripts/runtime/forced_decision_response_option_policy.gd",
	"res://scripts/runtime/monster_runtime_controller.gd",
	"res://scripts/runtime/card_target_choice_runtime_controller.gd",
]
const ACTIVE_QA_TOOL_PATHS := [
	"res://scripts/tools/card_resolution_queue_runtime_characterization_bench.gd",
	"res://scripts/tools/city_trade_network_runtime_characterization_bench.gd",
	"res://scripts/tools/product_market_runtime_characterization_bench.gd",
]
const MAIN_SCENE := preload("res://scenes/main.tscn")

var _checks := 0
var _failures: Array[String] = []


class AutomaticCardSource:
	extends RefCounted

	func play_core_card(_actor_id: String, _slot_index: int, _target: Dictionary, _router: Object, _expected_revision: int, _transaction_id: String) -> Dictionary:
		return {"committed": false}

	func player_snapshot(_actor_id: String) -> Dictionary:
		return {"inventory": {"slots": []}}


class AutomaticCandidateFlow:
	extends RefCounted

	var matching_product_gdp_30s := 10
	var prepare_calls := 0
	var commit_calls := 0
	var finalize_calls := 0
	var rollback_calls := 0

	func card_effect_candidates_snapshot() -> Dictionary:
		return {
			"valid": true,
			"reason_code": "ready",
			"revision": 17,
			"candidates": [{
				"candidate_id": "automatic-land-candidate",
				"facility": {"facility_id": "factory-a", "facility_type": "factory", "industry_id": "industry", "region_id": "region-a", "owner_player_index": 0, "active": true},
				"region": {"region_id": "region-a", "revision": 1, "lifecycle_state": "active"},
				"product": {"product_id": "test-product", "industry_id": "industry"},
				"commodity_owner_player_index": 0,
				"matching_product_gdp_30s": matching_product_gdp_30s,
				"route": {
					"route_id": "route-a",
					"source_facility_id": "factory-a",
					"market_facility_id": "market-a",
					"mode_tags": ["land"],
					"shortest_legal_distance": 1,
					"topology_revision": "1",
					"capacity_resources": [{"resource_id": "capacity-a", "available_units": 20}],
					"expected_owner_net_cash": 100,
					"arrival_milliseconds": 1000,
					"transfer_count": 0,
				},
				"available_capacity_units": 20,
			}],
		}

	func prepare_card_effect_batch(plan: Dictionary) -> Dictionary:
		prepare_calls += 1
		return _batch_binding(plan, {"prepared": true, "reason_code": "prepared", "batch_request": plan.duplicate(true)})

	func commit_card_effect_batch(prepared: Dictionary) -> Dictionary:
		commit_calls += 1
		return _batch_binding(prepared, {"committed": true, "reason_code": "committed"})

	func rollback_card_effect_batch(receipt: Dictionary) -> Dictionary:
		rollback_calls += 1
		return _batch_binding(receipt, {"rolled_back": true, "committed": false, "reason_code": "rolled_back"})

	func finalize_card_effect_batch(receipt: Dictionary) -> Dictionary:
		finalize_calls += 1
		return _batch_binding(receipt, {"finalized": true, "committed": true, "reason_code": "finalized"})

	func install_commodity(_request: Dictionary) -> Dictionary:
		return {"committed": false}

	func _batch_binding(source: Dictionary, details: Dictionary) -> Dictionary:
		var result := {
			"transaction_id": str(source.get("transaction_id", "")),
			"intent_hash": str(source.get("intent_hash", "")),
			"plan_hash": str(source.get("plan_hash", "")),
		}
		result.merge(details, true)
		return result


class AutomaticInfrastructure:
	extends RefCounted

	func region_snapshot(_region_id: String) -> Dictionary:
		return {}

	func slot_id(_region_id: String, _facility_type: String, _industry_id := "") -> String:
		return ""

	func apply_facility_action(_request: Dictionary) -> Dictionary:
		return {"committed": false}

	func rollback_facility_action(_receipt: Dictionary) -> Dictionary:
		return {"rolled_back": false}

	func facilities_snapshot(_include_tombstones := false) -> Array:
		return []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_stack_is_physically_absent()
	_test_active_catalog_is_clean()
	_test_runtime_composition_is_clean()
	_test_active_qa_tools_have_no_deleted_contract_resource_paths()
	_test_v06_save_registry_has_no_legacy_section()
	_test_preserved_mechanics_remain_composed()
	_test_automatic_supply_demand_production_wiring()
	_test_automatic_supply_demand_preflight_and_exact_once()
	_test_public_queue_and_history_group_privacy()
	_test_recursive_legacy_payload_guard()
	await _test_legacy_nested_response_payload_cold_restore_rejected()
	_finish()


func _test_stack_is_physically_absent() -> void:
	for path in RETIRED_PATHS:
		_expect(not FileAccess.file_exists(path) and not ResourceLoader.exists(path), "retired path is absent: %s" % path)


func _test_active_catalog_is_clean() -> void:
	var sources := "\n".join([
		FileAccess.get_file_as_string("res://resources/cards/runtime/card_runtime_catalog_v04.tres"),
		FileAccess.get_file_as_string("res://resources/cards/runtime/packs/04_contracts.tres"),
		FileAccess.get_file_as_string("res://resources/cards/runtime/packs/05_intel_counter.tres"),
		FileAccess.get_file_as_string("res://resources/cards/runtime/card_runtime_catalog_v06.tres"),
	])
	for card_id in RETIRED_CARD_IDS:
		_expect(not sources.contains(card_id), "retired family is absent from active catalogs: %s" % card_id)
	_expect(not sources.contains("area_trade_contract"), "retired family kind is absent from active catalogs")
	_expect(not sources.contains("intel_contract_trace") and not sources.contains("trace_contract_count"), "retired contract-party trace effect is absent from active catalogs")


func _test_runtime_composition_is_clean() -> void:
	var sources := "\n".join([
		FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn"),
		FileAccess.get_file_as_string("res://scenes/ui/OverlayLayer.tscn"),
		FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd"),
	])
	for identifier in ["ContractRuntimeController", "ContractRuntimeWorldBridge", "ContractResponseDecisionPanel", "contract_response", "area_trade_contract"]:
		_expect(not sources.contains(identifier), "runtime composition omits retired identifier: %s" % identifier)
	var interaction_schema := FileAccess.get_file_as_string("res://scripts/cards/v06/interaction/anonymous_interaction_runtime_schema_v06.gd")
	var interaction_router := FileAccess.get_file_as_string("res://scripts/cards/v06/interaction/interaction_effect_router_v06.gd")
	_expect(not interaction_schema.contains("contract_offer_v06") and not interaction_schema.contains('interaction_domain", "")) == "contract"'), "anonymous interaction schema has no contract offer/domain route")
	_expect(not interaction_router.contains('"contract"') and not interaction_router.contains("contract_offer_v06"), "interaction router has no contract domain")


func _test_v06_save_registry_has_no_legacy_section() -> void:
	var registry := FileAccess.get_file_as_string("res://resources/rules/controller_state_version_registry_v06.tres")
	_expect(not registry.contains('save_section = "contracts"'), "v0.6 adds no legacy save section")


func _test_active_qa_tools_have_no_deleted_contract_resource_paths() -> void:
	for path in ACTIVE_QA_TOOL_PATHS:
		var source := FileAccess.get_file_as_string(path)
		_expect(
			not source.contains("contract_runtime_controller.gd")
			and not source.contains("contract_runtime_world_bridge.gd")
			and not source.contains("ContractRuntimeController"),
			"active QA tool has no deleted contract resource path: %s" % path
		)


func _test_preserved_mechanics_remain_composed() -> void:
	for path in ACTIVE_DECISION_SCRIPTS:
		_expect(ResourceLoader.exists(path), "preserved mechanic owner exists: %s" % path)
	_expect(bool(ForcedDecisionResponseOptionPolicy.validation_report(&"counter_response", "counter_response_1", "counter_pass").get("valid", false)), "counter response remains active")
	_expect(bool(ForcedDecisionResponseOptionPolicy.validation_report(&"monster_wager", "monster_wager_1", "monster_wager:1:a:5").get("valid", false)), "monster wager response remains active")
	_expect(bool(ForcedDecisionResponseOptionPolicy.validation_report(&"player_target_choice", "player_target_1", "target_player_1").get("valid", false)), "target choice remains active")


func _test_automatic_supply_demand_production_wiring() -> void:
	var adapter := CoreEconomicCardRuntimeAdapterV06.new()
	root.add_child(adapter)
	var configured := adapter.configure(AutomaticCardSource.new(), AutomaticCandidateFlow.new(), AutomaticInfrastructure.new(), {"player.0": 0})
	_expect(bool(configured.get("configured", false)), "automatic supply/demand uses the existing core economic adapter and real candidate-port contract")
	var target := adapter.automatic_supply_demand_target_context("global_supply_spawn", "global_matching_factories")
	var context: Dictionary = target.get("target_context", {}) if target.get("target_context", {}) is Dictionary else {}
	_expect(bool(target.get("ready", false)) and int(context.get("candidate_snapshot_revision", -1)) == 17, "automatic supply target is derived from the authoritative candidate revision without a responder")
	var mismatched := adapter.automatic_supply_demand_target_context("global_supply_spawn", "target_player")
	_expect(not bool(mismatched.get("ready", true)) and str(mismatched.get("reason_code", "")) == "automatic_supply_demand_target_kind_mismatch", "target-player consent cannot be forged onto an automatic supply card")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_expect(
		coordinator_source.contains('if ["global_order_budget", "global_supply_spawn"].has(effect_kind):')
		and coordinator_source.contains('"automatic_supply_demand_target_context"')
		and coordinator_source.contains('effect_receipt.get("owner_receipt", {})')
		and coordinator_source.contains('"candidate_snapshot_revision": candidate_snapshot_revision'),
		"Coordinator production play and terminal replay both preserve the authoritative automatic supply/demand target binding"
	)
	adapter.queue_free()


func _test_automatic_supply_demand_preflight_and_exact_once() -> void:
	var catalog := load("res://resources/cards/runtime/card_runtime_catalog_v06.tres")
	_expect(catalog != null and bool(catalog.call("reload").get("valid", false)), "automatic supply/demand preflight uses the active v0.6 catalog")
	if catalog == null:
		return
	var card_variant: Variant = catalog.call("card_snapshot", "supply_demand.near_land_supply.rank_1")
	var card: Dictionary = (card_variant as Dictionary).duplicate(true) if card_variant is Dictionary else {}
	card["runtime_instance_id"] = "retirement-auto-supply-instance"
	var flow := AutomaticCandidateFlow.new()
	var adapter := CoreEconomicCardRuntimeAdapterV06.new()
	root.add_child(adapter)
	var configured := adapter.configure(AutomaticCardSource.new(), flow, AutomaticInfrastructure.new(), {"player.0": 0})
	var target := adapter.automatic_supply_demand_target_context("global_supply_spawn", "global_matching_factories")
	var context: Dictionary = target.get("target_context", {}) if target.get("target_context", {}) is Dictionary else {}
	var preflight := adapter.preflight_automatic_supply_demand("player.0", card, context, "preflight:retirement:auto-supply")
	_expect(bool(configured.get("configured", false)) and bool(preflight.get("ready", false)), "legal automatic supply card passes a real effect-level prepare/abort preflight")
	_expect(flow.prepare_calls == 0 and flow.commit_calls == 0 and flow.finalize_calls == 0 and flow.rollback_calls == 0, "preflight produces no CommodityFlow batch mutation")
	_expect(int((adapter.debug_snapshot().get("router", {}) as Dictionary).get("pending_transaction_count", -1)) == 0, "preflight abort leaves no prepared router transaction")
	var resolved := adapter.resolve_queued_automatic_supply_demand("player.0", card, context, "card-resolution:777:v06-supply-demand")
	_expect(bool(resolved.get("resolved", false)) and bool(resolved.get("committed", false)) and bool(resolved.get("finalized", false)), "queued automatic supply resolves through prepare, commit, and finalize without a responder")
	_expect(flow.prepare_calls == 1 and flow.commit_calls == 1 and flow.finalize_calls == 1 and flow.rollback_calls == 0, "automatic supply batch reaches each authoritative lifecycle stage exactly once")
	_expect(int((adapter.debug_snapshot().get("router", {}) as Dictionary).get("pending_transaction_count", -1)) == 0, "first automatic supply finalization leaves no prepared router transaction")
	var replay := adapter.resolve_queued_automatic_supply_demand("player.0", card, context, "card-resolution:777:v06-supply-demand")
	_expect(bool(replay.get("resolved", false)) and bool(replay.get("idempotent_replay", false)), "automatic supply terminal replay returns the original finalized result")
	_expect(flow.prepare_calls == 1 and flow.commit_calls == 1 and flow.finalize_calls == 1, "automatic supply replay does not duplicate CommodityFlow mutation")
	_expect(int((adapter.debug_snapshot().get("router", {}) as Dictionary).get("pending_transaction_count", -1)) == 0, "terminal replay leaves no prepared router transaction")
	adapter.queue_free()

	var rejected_flow := AutomaticCandidateFlow.new()
	rejected_flow.matching_product_gdp_30s = 0
	var rejected_adapter := CoreEconomicCardRuntimeAdapterV06.new()
	root.add_child(rejected_adapter)
	rejected_adapter.configure(AutomaticCardSource.new(), rejected_flow, AutomaticInfrastructure.new(), {"player.0": 0})
	var rejected_target := rejected_adapter.automatic_supply_demand_target_context("global_supply_spawn", "global_matching_factories")
	var rejected_context: Dictionary = rejected_target.get("target_context", {}) if rejected_target.get("target_context", {}) is Dictionary else {}
	var rejected := rejected_adapter.preflight_automatic_supply_demand("player.0", card, rejected_context, "preflight:retirement:zero-gdp")
	_expect(not bool(rejected.get("ready", true)) and str(rejected.get("reason_code", "")) == "actor_matching_product_gdp_not_positive", "zero matching GDP is rejected before an automatic supply card can leave the hand")
	_expect(rejected_flow.prepare_calls == 0 and rejected_flow.commit_calls == 0 and rejected_flow.finalize_calls == 0, "failed preflight has zero economic partial mutation")
	var submission_source := FileAccess.get_file_as_string("res://scripts/runtime/card_play_submission_runtime_controller.gd")
	var preflight_position := submission_source.find("preflight_v06_automatic_supply_demand")
	var inventory_position := submission_source.find("plan_card_inventory_queue_commit", preflight_position)
	_expect(preflight_position >= 0 and inventory_position > preflight_position, "production submission performs effect preflight before inventory removal and queue commit")
	rejected_adapter.queue_free()


func _test_public_queue_and_history_group_privacy() -> void:
	var private_entry := {
		"resolution_id": 8801,
		"queued_order": 8801,
		"player_index": 6,
		"slot_index": 2,
		"group_id": "window_9_group_6",
		"group_order": 1,
		"group_size": 1,
		"v06_actor_id": "player.6",
		"v06_card_instance_id": "private-instance",
		"transaction_id": "private-transaction",
		"skill": {"name": "近地供货潮 I", "display_name": "近地供货潮 I", "kind": "supply_demand", "rank": 1},
	}
	var queue := CardResolutionQueueRuntimeService.new()
	root.add_child(queue)
	queue.configure({
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
	})
	queue.replace_current_queue([private_entry])
	var queue_json := JSON.stringify(queue.public_snapshot())
	_expect(queue_json.contains("public_set_1") and not queue_json.contains("window_9_group_6"), "public queue replaces seat-derived group ids with anonymous set aliases")
	for token in ["player_index", "slot_index", "player.6", "private-instance", "private-transaction", "v06_actor_id"]:
		_expect(not queue_json.contains(token), "public queue omits private token: %s" % token)
	queue.queue_free()

	var history := CardResolutionHistoryRuntimeService.new()
	root.add_child(history)
	history.configure()
	history.append_resolved(private_entry)
	var history_json := JSON.stringify(history.public_history_snapshot())
	_expect(history_json.contains("public_set_1") and not history_json.contains("window_9_group_6"), "public history replaces seat-derived group ids with anonymous set aliases")
	for token in ["player_index", "slot_index", "player.6", "private-instance", "private-transaction", "v06_actor_id"]:
		_expect(not history_json.contains(token), "public history omits private token: %s" % token)
	history.queue_free()


func _test_recursive_legacy_payload_guard() -> void:
	var nested_payloads := [
		{"setup": {"extension": {"contract_response": "accept"}}},
		{"outcome": [{"pending_contract_offers": [{"reward": 500}]}]},
		{"players": [{"ai_memory": {"known_contract_parties": {1: true}}}]},
		{"queue": [{"district_pair": [0, 1]}]},
		{"slots": [{"name": "区域供需合约1"}]},
		{"slots": [{"card_id": "密约回溯1"}]},
		{"skill": {"kind": "intel_contract_trace"}},
		{"skill": {"trace_contract_count": 1}},
		{"kind": "area_trade_contract"},
		{"mechanic_id": &"contract_response"},
		{"effect_kind": "contract_offer_v06"},
		{"schema": "interaction_domain=contract"},
		{"state": "ContractResponse"},
	]
	for payload in nested_payloads:
		var report := LegacyContractPayloadGuardV06.validation_report(payload)
		_expect(not bool(report.get("valid", true)) and str(report.get("reason_code", "")) == "retired_contract_payload_rejected", "recursive legacy response payload is identified before apply")
	_expect(bool(LegacyContractPayloadGuardV06.validation_report({"kind": "product_contract_boon", "city_contract_boon": 2}).get("valid", false)), "automatic non-consensual economy contract kinds remain legal")


func _test_legacy_nested_response_payload_cold_restore_rejected() -> void:
	var formal_root := MAIN_SCENE.instantiate()
	formal_root.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(formal_root)
	await process_frame
	var services := formal_root.get_node_or_null("RuntimeServices")
	var coordinator := services.get_node_or_null("RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator if services != null else null
	var draft := services.get_node_or_null("NewGameSetupDraftService") as NewGameSetupDraftService if services != null else null
	var transaction := services.get_node_or_null("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator if services != null else null
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController if coordinator != null else null
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController if coordinator != null else null
	var envelope_owner := session.get_node_or_null("SessionEnvelopeSaveOwner") as SessionEnvelopeSaveOwner if session != null else null
	var scheduler := coordinator.get_node_or_null("ForcedDecisionRuntimeScheduler") if coordinator != null else null
	var request := SessionStartRequest.create(
		"contract-retirement-cold-restore",
		draft.draft_snapshot() if draft != null else {},
		session.session_start_revision() if session != null else -1,
		"focused_test"
	)
	var start := transaction.start_session(request) if transaction != null else null
	_expect(start != null and start.applied, "cold-restore fixture starts through the authoritative session transaction")
	await process_frame
	var before_rejected_begin := session.session_summary() if session != null else {}
	var rejected_begin := session.begin_session({"session_id": "forged", "player_count": 3, "card_id": "区域供需合约1"}) if session != null else {}
	_expect(bool(rejected_begin.get("rejected", false)) and str(rejected_begin.get("reason_code", "")) == "retired_contract_payload_rejected", "legacy card identity is rejected before begin-session mutation")
	_expect(session.session_summary() == before_rejected_begin, "rejected legacy begin-session payload preserves the active session exactly")
	var capture := envelope_owner.capture_composite_state() if envelope_owner != null else {}
	var baseline := capture.get("state", {}) as Dictionary
	var before_economy := _cold_restore_economy_fingerprint(coordinator)
	var before_scheduler: Dictionary = scheduler.debug_snapshot() if scheduler != null and scheduler.has_method("debug_snapshot") else {}
	var before_apply_count := int(envelope_owner.debug_snapshot().get("apply_count", -1)) if envelope_owner != null else -1
	_expect(bool(capture.get("captured", false)) and not baseline.is_empty(), "cold-restore fixture captures the real v0.6 session envelope")
	for location in ["setup", "outcome", "player_ai_memory", "player_known_parties", "annotations"]:
		var forged := _legacy_contract_payload_at(baseline, location)
		var preflight := envelope_owner.preflight_save_data(forged) if envelope_owner != null else {}
		var apply := envelope_owner.apply_save_data(forged) if envelope_owner != null else {}
		_expect(not bool(preflight.get("accepted", true)), "legacy nested %s payload is rejected by v0.6 cold-restore preflight" % location)
		_expect(not bool(apply.get("applied", true)) and int(apply.get("apply_count", 0)) == 0, "legacy nested %s payload reaches zero owner applies" % location)
		_expect(_cold_restore_economy_fingerprint(coordinator) == before_economy, "legacy nested %s payload changes no cash/GDP/commodity/route/reward authority" % location)
		var after_scheduler: Dictionary = scheduler.debug_snapshot() if scheduler != null and scheduler.has_method("debug_snapshot") else {}
		_expect(after_scheduler == before_scheduler and not _has_contract_candidate(after_scheduler), "legacy nested %s payload creates no forced contract decision/window" % location)
	_expect(int(envelope_owner.debug_snapshot().get("apply_count", -2)) == before_apply_count, "all rejected legacy payloads preserve the envelope owner apply counter")
	if ai != null:
		var unsupported_plan := ai.build_response_plan("contract_response", 1, {"candidates": [{"score": 9999}]})
		_expect(not bool(unsupported_plan.get("planned", true)) and str(unsupported_plan.get("reason", "")) == "response_kind_unsupported", "AI rejects retired response kinds before ranking supplied candidates")
		var target_plan := ai.build_response_plan("player_target_choice", 1, {"candidates": [{"candidate_id": "target_player_2", "score": 20}]})
		_expect(bool(target_plan.get("planned", false)), "AI preserves active player-target response planning")
		var ai_save := ai.to_save_data()
		var forged_ai_save := ai_save.duplicate(true)
		var ai_states: Array = (forged_ai_save.get("player_states", []) as Array).duplicate(true)
		if not ai_states.is_empty():
			var ai_state := (ai_states[0] as Dictionary).duplicate(true)
			var ai_memory := (ai_state.get("ai_memory", {}) as Dictionary).duplicate(true)
			ai_memory["contract_response"] = "accept"
			ai_state["ai_memory"] = ai_memory
			ai_states[0] = ai_state
			forged_ai_save["player_states"] = ai_states
			var before_ai_save := ai.to_save_data()
			var ai_preflight := ai.preflight_save_data(forged_ai_save)
			var ai_apply := ai.apply_save_data(forged_ai_save)
			_expect(not bool(ai_preflight.get("accepted", true)) and not bool(ai_apply.get("applied", true)), "AI save rejects nested retired response state before mutation")
			_expect(ai.to_save_data() == before_ai_save, "failed AI legacy load preserves the current AI runtime state")
	formal_root.queue_free()
	await process_frame


func _legacy_contract_payload_at(baseline: Dictionary, location: String) -> Dictionary:
	var forged := baseline.duplicate(true)
	var legacy_payload := {
		"pending_contract_offers": [{
			"contract_response": "accept",
			"responder": 1,
			"accept": true,
			"reject": false,
			"timeout": 15,
			"penalty": 987,
			"reward": 654,
		}],
	}
	match location:
		"setup":
			var game_setup := ((forged.get("game_session_runtime", {}) as Dictionary).get("setup", {}) as Dictionary).duplicate(true)
			game_setup["extension"] = legacy_payload
			(forged.get("game_session_runtime", {}) as Dictionary)["setup"] = game_setup
		"outcome":
			var outcome := ((forged.get("game_session_runtime", {}) as Dictionary).get("outcome_receipt", {}) as Dictionary).duplicate(true)
			outcome["extension"] = legacy_payload
			(forged.get("game_session_runtime", {}) as Dictionary)["outcome_receipt"] = outcome
		"player_ai_memory":
			var memory_players := ((forged.get("world_session_state", {}) as Dictionary).get("players", []) as Array).duplicate(true)
			var memory_player := (memory_players[0] as Dictionary).duplicate(true)
			var memory := (memory_player.get("ai_memory", {}) as Dictionary).duplicate(true)
			memory["contract_response"] = legacy_payload
			memory_player["ai_memory"] = memory
			memory_players[0] = memory_player
			(forged.get("world_session_state", {}) as Dictionary)["players"] = memory_players
		"player_known_parties":
			var known_players := ((forged.get("world_session_state", {}) as Dictionary).get("players", []) as Array).duplicate(true)
			var known_player := (known_players[0] as Dictionary).duplicate(true)
			known_player["known_contract_parties"] = {1: "legacy"}
			known_players[0] = known_player
			(forged.get("world_session_state", {}) as Dictionary)["players"] = known_players
		"annotations":
			(forged.get("card_history_private_annotations", {}) as Dictionary)["contract_response"] = legacy_payload
	return forged


func _cold_restore_economy_fingerprint(coordinator: GameRuntimeCoordinator) -> String:
	if coordinator == null:
		return ""
	var sources: Dictionary = {}
	for node_name in ["CommodityFlowRuntimeController", "ProductMarketRuntimeController", "RouteNetworkRuntimeController", "CardResolutionQueueRuntimeService", "CardResolutionHistoryRuntimeService"]:
		var node := coordinator.get_node_or_null(node_name)
		if node != null and node.has_method("to_save_data"):
			sources[node_name] = node.call("to_save_data")
	var world := coordinator.world_session_state()
	sources["world_session"] = world.to_save_data() if world != null else {}
	return JSON.stringify(sources).sha256_text()


func _has_contract_candidate(snapshot: Dictionary) -> bool:
	for candidate_variant in snapshot.get("candidates", []) as Array:
		var candidate := candidate_variant as Dictionary
		if str(candidate.get("kind", "")).contains("contract") or str(candidate.get("decision_id", "")).contains("contract"):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V06 contract-response retirement passed (%d checks)." % _checks)
		quit(0)
		return
	push_error("V06 contract-response retirement failed:\n- " + "\n- ".join(_failures))
	quit(1)
