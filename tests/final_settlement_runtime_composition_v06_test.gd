extends SceneTree

const COMPOSITION_SCENE := "res://scenes/runtime/FinalSettlementRuntimeComposition.tscn"
const BENCH_SCENE := "res://scenes/tools/FinalSettlementRuntimeCompositionV06Bench.tscn"
const MENU_OVERLAY_SCENE := "res://scenes/ui/MenuOverlay.tscn"
const SNAPSHOT_SERVICE_SCENE := "res://scenes/runtime/FinalSettlementPublicSnapshotService.tscn"

const RETIRED_MAIN_SYMBOLS := [
	"_open_final_settlement_menu",
	"_populate_final_settlement_summary_cards",
	"_add_final_settlement_board_panel",
	"_final_settlement_public_facts",
	"_final_settlement_public_snapshot",
	"_on_final_settlement_action_requested",
	"_final_settlement_public_summary_text",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var composition_packed := load(COMPOSITION_SCENE) as PackedScene
	var bench_packed := load(BENCH_SCENE) as PackedScene
	_expect(composition_packed != null and bench_packed != null, "production composition and dedicated bench load")
	var composition := composition_packed.instantiate() if composition_packed != null else null
	_expect(composition != null and composition.has_method("present") and composition.has_method("compose_public_source") and composition.has_method("compose_public_snapshot") and composition.has_method("latest_public_summary") and composition.has_method("reset_state") and composition.has_method("_on_session_authorization_context_changed"), "composition exposes the narrow public presentation and session-reset API")
	_expect(composition != null and composition.get_node_or_null("FinalSettlementPublicSourceAdapter") != null and composition.get_node_or_null("FinalSettlementBoardPanel") != null, "composition statically owns one source adapter and one board")
	if composition != null:
		composition.call("reset_state")
		var debug: Dictionary = composition.call("debug_snapshot")
		_expect(not bool(debug.get("owns_victory_rules", true)) and not bool(debug.get("owns_cash", true)) and not bool(debug.get("reads_raw_players", true)) and not bool(debug.get("reads_internal_receipt", true)) and int(debug.get("present_count", -1)) == 0 and int(debug.get("logged_outcome_count", -1)) == 0, "composition reset is empty and declares no Victory, cash, or private-source ownership")
		composition.free()
	await _exercise_acknowledgement_loss_and_rollback(composition_packed)
	var main_scene_source := FileAccess.get_file_as_string("res://scenes/main.tscn")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(main_scene_source.count("[node name=\"FinalSettlementRuntimeComposition\"") == 1 and main_scene_source.contains("FinalSettlementRuntimeComposition.tscn"), "main scene composes exactly one runtime composition node")
	var main_packed := load("res://scenes/main.tscn") as PackedScene
	var main := main_packed.instantiate() if main_packed != null else null
	var production_composition := main.get_node_or_null("RuntimeServices/FinalSettlementRuntimeComposition") if main != null else null
	_expect(production_composition != null and production_composition.scene_file_path == COMPOSITION_SCENE and production_composition.has_method("present"), "real main exposes the production composition node and API")
	if main != null:
		main.free()
	var retired := true
	for symbol in RETIRED_MAIN_SYMBOLS:
		retired = retired and not main_source.contains("func %s(" % symbol)
	_expect(retired and not main_source.contains("FinalSettlementBoardScene"), "main has no retired final settlement builders, formatters, or dynamic board preload")
	_expect(main_scene_source.contains('signal="public_log_receipt_requested" from="RuntimeServices/FinalSettlementRuntimeComposition" to="RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/TablePresentationQueryPorts" method="acknowledge_final_settlement_public_log"'), "production FinalSettlement has one synchronous public-log acknowledgement route")
	_expect(not main_scene_source.contains('signal="public_log_receipt_requested" from="RuntimeServices/FinalSettlementRuntimeComposition" to="RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator" method="append_public_log_receipt"'), "fire-and-forget FinalSettlement log route is retired")
	_expect(main_scene_source.contains('signal="authorization_context_changed" from="RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController" to="RuntimeServices/FinalSettlementRuntimeComposition" method="_on_session_authorization_context_changed"'), "production session authorization context resets FinalSettlement state")
	_expect(main_scene_source.contains('signal="authorization_context_changed" from="RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController" to="RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/TablePresentationQueryPorts" method="_on_session_authorization_context_changed"'), "production session authorization context resets public-log and presentation acknowledgement state")
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("FINAL_SETTLEMENT_RUNTIME_COMPOSITION_V06_TEST|status=%s|checks=%d|failures=%d|notes=%s" % [status, _checks, _failures.size(), JSON.stringify(_failures)])
	quit(0 if _failures.is_empty() else 1)


func _exercise_acknowledgement_loss_and_rollback(composition_packed: PackedScene) -> void:
	var overlay_packed := load(MENU_OVERLAY_SCENE) as PackedScene
	var snapshot_packed := load(SNAPSHOT_SERVICE_SCENE) as PackedScene
	_expect(composition_packed != null and overlay_packed != null and snapshot_packed != null, "transactional presentation fixture scenes load")
	if composition_packed == null or overlay_packed == null or snapshot_packed == null:
		return
	var harness := Node.new()
	harness.name = "FinalSettlementTransactionalPresentationHarness"
	root.add_child(harness)
	var overlay := overlay_packed.instantiate()
	overlay.name = "MenuOverlay"
	harness.add_child(overlay)
	var snapshot_service := snapshot_packed.instantiate()
	snapshot_service.name = "SnapshotService"
	harness.add_child(snapshot_service)
	snapshot_service.call("configure", {})
	var composition := composition_packed.instantiate()
	composition.name = "Composition"
	composition.set("menu_overlay_path", NodePath("../MenuOverlay"))
	composition.set("snapshot_service_path", NodePath("../SnapshotService"))
	harness.add_child(composition)
	var public_log_owner := PublicLogPresentationOwner.new()
	public_log_owner.name = "PublicLogOwner"
	harness.add_child(public_log_owner)
	await process_frame

	var lose_first_acknowledgement := [true]
	var emitted_log_receipts: Array = []
	composition.public_log_receipt_requested.connect(func(receipt: PublicLogReceipt, acknowledgement: Dictionary) -> void:
		emitted_log_receipts.append({
			"receipt_id": receipt.receipt_id,
			"source_revision": receipt.source_revision,
			"world_time": receipt.world_time,
			"fingerprint": receipt.fingerprint(),
		})
		var owner_result := public_log_owner.append_receipt(receipt)
		if bool(lose_first_acknowledgement[0]):
			lose_first_acknowledgement[0] = false
			return
		var duplicate := bool(owner_result.get("duplicate", false))
		var accepted := bool(owner_result.get("applied", false)) or duplicate
		acknowledgement.assign({
			"schema_version": 1,
			"receipt_id": receipt.receipt_id,
			"outcome_id": str(receipt.public_values.get("outcome_id", "")),
			"receipt_fingerprint": receipt.fingerprint(),
			"accepted": accepted,
			"duplicate": duplicate,
			"reason_id": "" if accepted else str(owner_result.get("reason_code", "public_log_rejected")),
		})
	)
	var public_context := _terminal_public_context()
	var first_result: Dictionary = composition.call("present", public_context)
	_expect(not bool(first_result.get("accepted", true)) and public_log_owner.recent_public_entries(8).size() == 1 and int(composition.call("debug_snapshot").get("present_count", -1)) == 0, "lost downstream acknowledgement rejects presentation after exactly one owner apply")
	var second_result: Dictionary = composition.call("present", public_context.duplicate(true))
	var owner_debug := public_log_owner.debug_snapshot()
	_expect(bool(second_result.get("accepted", false)) and not bool(second_result.get("duplicate", true)) and public_log_owner.recent_public_entries(8).size() == 1, "retry accepts the owner's exact duplicate without adding a second public-log row")
	_expect(emitted_log_receipts.size() == 2 and emitted_log_receipts[0] == emitted_log_receipts[1] and int(owner_debug.get("duplicate_receipt_count", -1)) == 1 and int(owner_debug.get("collision_receipt_count", -1)) == 0, "acknowledgement-loss retry preserves receipt ID, source revision, world time, and fingerprint with zero collision")

	var board := composition.call("board_node") as Control
	var preview_host := overlay.call("get_preview_host") as Container
	var snapshot_before_rollback: Dictionary = composition.call("last_public_snapshot")
	var debug_before_rollback: Dictionary = composition.call("debug_snapshot")
	var title_before_rollback := str((board.find_child("FinalSettlementBoardTitle", true, false) as Label).text) if board != null else ""
	_expect(board != null and preview_host != null and board.get_parent() == preview_host and board.visible and not snapshot_before_rollback.is_empty(), "accepted settlement owns one mounted, visible final board")
	composition.call("_on_session_authorization_context_changed", "session_plan_applied")
	_expect(board.get_parent() == composition and not board.visible and int(composition.call("debug_snapshot").get("present_count", -1)) == 0, "session plan apply parks the final board and exposes empty new-session presentation state")
	composition.call("_on_session_authorization_context_changed", "session_checkpoint_rolled_back")
	var debug_after_rollback: Dictionary = composition.call("debug_snapshot")
	var title_after_rollback := str((board.find_child("FinalSettlementBoardTitle", true, false) as Label).text)
	_expect(composition.call("last_public_snapshot") == snapshot_before_rollback and debug_after_rollback == debug_before_rollback, "session rollback restores the settlement snapshot and exact-once journals exactly")
	_expect(board.get_parent() == preview_host and board.visible and title_after_rollback == title_before_rollback, "session rollback remounts the same final-board content and visibility")

	composition.call("_on_session_authorization_context_changed", "session_save_applied")
	var save_quarantine_debug: Dictionary = composition.call("debug_snapshot")
	_expect(composition.call("last_public_snapshot").is_empty() and board.get_parent() == composition and not board.visible and str(save_quarantine_debug.get("session_lifecycle_checkpoint_kind", "")) == "session_save_applied", "first save-owner apply quarantines the predecessor board and exact-once journals")
	composition.call("_on_session_authorization_context_changed", "session_save_applied")
	var failed_load_restored_debug: Dictionary = composition.call("debug_snapshot")
	_expect(composition.call("last_public_snapshot") == snapshot_before_rollback and failed_load_restored_debug == debug_before_rollback and board.get_parent() == preview_host and board.visible, "reverse-order save rollback restores the predecessor board and settlement lineage exactly")

	composition.call("_on_session_authorization_context_changed", "session_save_applied")
	composition.call("_on_session_authorization_context_changed", "session_load_completed")
	var committed_load_debug: Dictionary = composition.call("debug_snapshot")
	_expect(composition.call("last_public_snapshot").is_empty() and int(committed_load_debug.get("presented_outcome_count", -1)) == 0 and int(committed_load_debug.get("logged_outcome_count", -1)) == 0 and str(committed_load_debug.get("session_lifecycle_checkpoint_kind", "stale")) == "" and board.get_parent() == composition and not board.visible, "successful load commits an empty settlement lineage and cannot resurrect the predecessor board")
	var loaded_session_result: Dictionary = composition.call("present", public_context.duplicate(true))
	_expect(bool(loaded_session_result.get("accepted", false)) and not bool(loaded_session_result.get("duplicate", true)) and int(composition.call("debug_snapshot").get("present_count", -1)) == 1, "loaded session may reuse the predecessor outcome ID as a fresh presentation while the public-log owner accepts its exact duplicate")
	var loaded_snapshot := composition.call("last_public_snapshot") as Dictionary
	for non_reset_reason in ["session_paused", "session_resumed", "session_finished"]:
		composition.call("_on_session_authorization_context_changed", non_reset_reason)
	_expect(composition.call("last_public_snapshot") == loaded_snapshot and board.get_parent() == preview_host and board.visible, "pause, resume, and session-finished lifecycle notices retain the terminal board")
	harness.queue_free()
	await process_frame


func _terminal_public_context() -> Dictionary:
	return {
		"source_revision": 17,
		"world_time": 185.0,
		"participant_names": {"0": "测试玩家"},
		"public_map_facts": {
			"active_city_count": 2,
			"destroyed_district_count": 1,
			"active_monster_count": 0,
			"monster_count": 1,
		},
		"victory_public_snapshot": {
			"controller_id": "victory_control_runtime_v06",
			"ruleset_id": "v0.6",
			"state": "resolved",
			"victory_rule": {
				"required_region_count": 2,
				"required_top_k_gdp_per_minute": 72,
			},
			"qualification_remaining_seconds": 0.0,
			"audit_remaining_seconds": 0.0,
			"audit_roster": [0],
			"audit_entries": [],
			"paused": false,
			"pause_reasons": [],
			"settlement_checkpoint": "post_world_settlement",
			"outcome_receipt": {
				"outcome_id": "victory.v06.ack-loss-fixture",
				"schema_version": "victory_outcome_v1",
				"ruleset_id": "v0.6",
				"reason_code": "public_audit_complete",
				"winner_player_indices": [0],
				"co_victory": false,
				"comparison_order": ["top_k_gdp_per_minute", "controlled_region_count", "cash_ledger_cents"],
				"rankings": [{
					"player_index": 0,
					"top_k_gdp_per_minute": 120,
					"controlled_region_count": 3,
					"winner": true,
				}],
				"audit_evidence": {
					"victory_rule": {},
					"audit_roster": [0],
					"settlement_checkpoint": "post_world_settlement",
				},
				"visibility_scope": "public",
			},
			"visibility_scope": "public",
		},
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
