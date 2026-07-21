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


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_stack_is_physically_absent()
	_test_active_catalog_is_clean()
	_test_runtime_composition_is_clean()
	_test_active_qa_tools_have_no_deleted_contract_resource_paths()
	_test_v06_save_registry_has_no_legacy_section()
	_test_preserved_mechanics_remain_composed()
	await _test_legacy_nested_response_payload_cold_restore_rejected()
	_finish()


func _test_stack_is_physically_absent() -> void:
	for path in RETIRED_PATHS:
		_expect(not FileAccess.file_exists(path) and not ResourceLoader.exists(path), "retired path is absent: %s" % path)


func _test_active_catalog_is_clean() -> void:
	var sources := "\n".join([
		FileAccess.get_file_as_string("res://resources/cards/runtime/card_runtime_catalog_v04.tres"),
		FileAccess.get_file_as_string("res://resources/cards/runtime/packs/04_contracts.tres"),
		FileAccess.get_file_as_string("res://resources/cards/runtime/card_runtime_catalog_v06.tres"),
	])
	for card_id in RETIRED_CARD_IDS:
		_expect(not sources.contains(card_id), "retired family is absent from active catalogs: %s" % card_id)
	_expect(not sources.contains("area_trade_contract"), "retired family kind is absent from active catalogs")


func _test_runtime_composition_is_clean() -> void:
	var sources := "\n".join([
		FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn"),
		FileAccess.get_file_as_string("res://scenes/ui/OverlayLayer.tscn"),
		FileAccess.get_file_as_string("res://scripts/main.gd"),
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
	var capture := envelope_owner.capture_composite_state() if envelope_owner != null else {}
	var baseline := capture.get("state", {}) as Dictionary
	var before_economy := _cold_restore_economy_fingerprint(coordinator)
	var before_scheduler: Dictionary = scheduler.debug_snapshot() if scheduler != null and scheduler.has_method("debug_snapshot") else {}
	var before_apply_count := int(envelope_owner.debug_snapshot().get("apply_count", -1)) if envelope_owner != null else -1
	_expect(bool(capture.get("captured", false)) and not baseline.is_empty(), "cold-restore fixture captures the real v0.6 session envelope")
	for location in ["session", "queue", "history", "ai", "annotations"]:
		var forged := _legacy_contract_payload_at(baseline, location)
		var preflight := envelope_owner.preflight_save_data(forged) if envelope_owner != null else {}
		var apply := envelope_owner.apply_save_data(forged) if envelope_owner != null else {}
		_expect(not bool(preflight.get("accepted", true)), "legacy nested %s payload is rejected by v0.6 cold-restore preflight" % location)
		_expect(not bool(apply.get("applied", true)) and int(apply.get("apply_count", 0)) == 0, "legacy nested %s payload reaches zero owner applies" % location)
		_expect(_cold_restore_economy_fingerprint(coordinator) == before_economy, "legacy nested %s payload changes no cash/GDP/commodity/route/reward authority" % location)
		var after_scheduler: Dictionary = scheduler.debug_snapshot() if scheduler != null and scheduler.has_method("debug_snapshot") else {}
		_expect(after_scheduler == before_scheduler and not _has_contract_candidate(after_scheduler), "legacy nested %s payload creates no forced contract decision/window" % location)
	_expect(int(envelope_owner.debug_snapshot().get("apply_count", -2)) == before_apply_count, "all rejected legacy payloads preserve the envelope owner apply counter")
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
		"session":
			(forged.get("game_session_runtime", {}) as Dictionary)["pending_contract_offers"] = legacy_payload
		"queue":
			(forged.get("world_session_state", {}) as Dictionary)["card_resolution_queue"] = legacy_payload
		"history":
			(forged.get("world_session_state", {}) as Dictionary)["card_resolution_history"] = legacy_payload
		"ai":
			(forged.get("world_session_state", {}) as Dictionary)["ai_runtime"] = legacy_payload
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
