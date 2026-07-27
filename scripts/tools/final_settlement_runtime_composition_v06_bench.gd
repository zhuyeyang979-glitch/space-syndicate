extends Control

const AUDITED_CASH_CENTS := 98765432100
const PRIVATE_CASH_CENTS := 12345678900

@onready var _menu_overlay: Control = $MenuModalOverlay
@onready var _snapshot_service: Node = $FinalSettlementPublicSnapshotService
@onready var _composition: Node = $FinalSettlementRuntimeComposition

var _checks := 0
var _failures: Array[String] = []
var _log_entries: Array[Dictionary] = []
var _actions: Array[String] = []
var _presentation_results: Array[Dictionary] = []
var _log_acknowledgements: Array[Dictionary] = []
var _query_ports: TablePresentationQueryPorts
var _public_log_owner: PublicLogPresentationOwner
var _public_log_port: PublicLogProducerPort
var _rejecting_public_log_port: PublicLogProducerPort
var _fail_next_log_ack := false


func _ready() -> void:
	_snapshot_service.call("configure", {})
	_query_ports = TablePresentationQueryPorts.new()
	_query_ports.name = "BenchTablePresentationQueryPorts"
	add_child(_query_ports)
	_public_log_owner = PublicLogPresentationOwner.new()
	_public_log_owner.name = "PublicLogPresentationOwner"
	_query_ports.add_child(_public_log_owner)
	_public_log_port = PublicLogProducerPort.new()
	_public_log_port.name = "PublicLogProducerPort"
	_query_ports.add_child(_public_log_port)
	_public_log_port.configure(_public_log_owner)
	_query_ports.public_log_owner = _public_log_owner
	_query_ports.public_log_port = _public_log_port
	_rejecting_public_log_port = PublicLogProducerPort.new()
	_rejecting_public_log_port.name = "RejectingPublicLogProducerPort"
	add_child(_rejecting_public_log_port)
	_composition.victory_presentation_result_ready.connect(_on_victory_presentation_result_ready)
	call_deferred("_run")


func _run() -> void:
	var fail_once_context := _public_context("bench.fail-once", false)
	var fail_once_receipt := _presentation_receipt(fail_once_context)
	_fail_next_log_ack = true
	var rejected_once := _composition.call("present_victory_receipt", fail_once_receipt) as Dictionary
	var rejected_debug := _composition.call("debug_snapshot") as Dictionary
	_expect(not bool(rejected_once.get("accepted", true)) and str(rejected_once.get("reason", "")) == "public_log_owner_missing", "missing log-owner acknowledgement fails the settlement closed")
	_expect(int(rejected_debug.get("present_count", -1)) == 0 and int(rejected_debug.get("logged_outcome_count", -1)) == 0 and _log_entries.is_empty() and (_composition.call("last_public_snapshot") as Dictionary).is_empty() and not (_composition.call("board_node") as Control).visible, "failed acknowledgement leaves presentation, log dedupe, snapshots, and board uncommitted")
	var accepted_retry := _composition.call("present_victory_receipt", fail_once_receipt) as Dictionary
	_expect(bool(accepted_retry.get("accepted", false)) and not bool(accepted_retry.get("duplicate", true)) and _log_entries.size() == 1, "fail-once public log retries normally and commits exactly once")
	_expect(_log_acknowledgements.size() == 2 and not bool(_log_acknowledgements[0].get("accepted", true)) and bool(_log_acknowledgements[1].get("accepted", false)), "fail-once owner returns one rejected and one accepted synchronous acknowledgement")
	_reset_session("session_reset")

	var reused_outcome_context := _public_context("victory.v06.1", false)
	var reused_outcome_receipt := _presentation_receipt(reused_outcome_context)
	var first_session_result := _composition.call("present_victory_receipt", reused_outcome_receipt) as Dictionary
	_expect(bool(first_session_result.get("accepted", false)) and not bool(first_session_result.get("duplicate", true)) and _log_entries.size() == 1, "first session presents victory.v06.1 exactly once")
	_reset_session("session_began")
	var reset_debug := _composition.call("debug_snapshot") as Dictionary
	_expect(int(reset_debug.get("present_count", -1)) == 0 and int(reset_debug.get("logged_outcome_count", -1)) == 0 and (_composition.call("last_public_snapshot") as Dictionary).is_empty() and not (_composition.call("board_node") as Control).visible, "session_began clears settlement snapshots, dedupe, counters, and board visibility")
	var second_session_result := _composition.call("present_victory_receipt", reused_outcome_receipt) as Dictionary
	var second_session_debug := _composition.call("debug_snapshot") as Dictionary
	_expect(bool(second_session_result.get("accepted", false)) and not bool(second_session_result.get("duplicate", true)), "second session may reuse victory.v06.1 without stale duplicate or collision")
	_expect(int(second_session_debug.get("present_count", -1)) == 1 and int(second_session_debug.get("logged_outcome_count", -1)) == 1 and _log_entries.size() == 1, "session reset clears presentation and public-log dedupe before reuse")
	_reset_session("session_reset")

	var normal_context := _public_context("bench.normal", false)
	var normal_receipt := _presentation_receipt(normal_context)
	var first_result := _composition.call("present_victory_receipt", normal_receipt) as Dictionary
	await _wait_frames(3)
	var board := _composition.call("board_node") as Control
	_expect(bool(first_result.get("accepted", false)), "normal public outcome opens")
	_expect(board != null and board.is_visible_in_tree() and board.size.x > 0.0 and board.size.y > 0.0, "board is visible with non-zero geometry")
	_expect(_board_count() == 1, "composition owns exactly one board")
	_expect(_presentation_results.size() == 1 and bool(_presentation_results[0].get("accepted", false)) and str(_presentation_results[0].get("outcome_id", "")) == "bench.normal", "typed Victory receipt receives one accepted FinalSettlement acknowledgement")
	_expect(_log_entries.size() == 1 and str(_log_entries[0].get("event_kind", "")) == "final_settlement" and str((_log_entries[0].get("public_values", {}) as Dictionary).get("public_status", "")) == "settled" and str((_log_entries[0].get("public_values", {}) as Dictionary).get("outcome_id", "")) == "bench.normal", "normal outcome emits one valid structured final-settlement receipt bound to its outcome")
	_expect(not _contains_value(_composition.call("last_public_snapshot"), AUDITED_CASH_CENTS) and not _contains_value(_log_entries, "987654321.00"), "ordinary outcome hides exact cash")

	var first_log_count := _log_entries.size()
	var first_board_id := board.get_instance_id()
	var replay_result := _composition.call("present_victory_receipt", normal_receipt) as Dictionary
	await _wait_frames(2)
	var replay_debug := _composition.call("debug_snapshot") as Dictionary
	_expect(bool(replay_result.get("accepted", false)) and bool(replay_result.get("duplicate", false)) and int(replay_debug.get("present_count", -1)) == 1, "same outcome replay is idempotent and does not present twice")
	_expect(_board_count() == 1 and (_composition.call("board_node") as Control).get_instance_id() == first_board_id, "reopen reuses the same board")
	_expect(_log_entries.size() == first_log_count, "reopen emits public outcome logs exactly once")
	var collision_context := normal_context.duplicate(true)
	var collision_snapshot := (collision_context.get("victory_public_snapshot", {}) as Dictionary).duplicate(true)
	var collision_outcome := (collision_snapshot.get("outcome_receipt", {}) as Dictionary).duplicate(true)
	collision_outcome["reason_code"] = "forged_collision_reason"
	collision_snapshot["outcome_receipt"] = collision_outcome
	collision_context["victory_public_snapshot"] = collision_snapshot
	var collision_result := _composition.call("present", collision_context) as Dictionary
	_expect(not bool(collision_result.get("accepted", true)) and str(collision_result.get("reason", "")) == "victory_outcome_binding_collision" and int((_composition.call("debug_snapshot") as Dictionary).get("present_count", -1)) == 1, "same outcome id with changed public content fails as a collision")

	var action_button := board.find_child("FinalSettlementAfterActionButton", true, false) as Button
	if action_button != null:
		action_button.emit_signal("pressed")
	await _wait_frames(1)
	_expect(action_button != null and _actions.size() == 1, "board action emits once")

	var audited_context := _public_context("bench.audit", true)
	var audited_result := _composition.call("present", audited_context) as Dictionary
	await _wait_frames(2)
	var audited_snapshot := _composition.call("last_public_snapshot") as Dictionary
	_expect(bool(audited_result.get("accepted", false)) and _contains_value(audited_snapshot, "987654321.00"), "authorized audit seat exact cash reaches the production board snapshot")
	_expect(not _contains_value(audited_snapshot, PRIVATE_CASH_CENTS) and not _contains_value(audited_snapshot, "123456789.00"), "non-audit opponent exact cash stays hidden")

	var generation_before := int((_composition.call("debug_snapshot") as Dictionary).get("present_count", -1))
	var invalid_context := audited_context.duplicate(true)
	invalid_context["raw_players"] = [{"cash_ledger_cents": PRIVATE_CASH_CENTS}]
	var invalid_result := _composition.call("present", invalid_context) as Dictionary
	var generation_after := int((_composition.call("debug_snapshot") as Dictionary).get("present_count", -1))
	_expect(not bool(invalid_result.get("accepted", true)) and generation_before == generation_after and _board_count() == 1, "illegal raw snapshot fails closed without UI mutation")

	var debug := _composition.call("debug_snapshot") as Dictionary
	_expect(int(debug.get("present_count", -1)) == 2 and int(debug.get("presented_outcome_count", -1)) == 2 and str(debug.get("last_presented_outcome_id", "")) == "bench.audit" and int(debug.get("logged_outcome_count", -1)) == 2, "debug evidence binds exactly one presentation and one public log per outcome")
	_expect(not bool(debug.get("owns_victory_rules", true)) and not bool(debug.get("owns_cash", true)) and not bool(debug.get("reads_raw_players", true)) and bool(debug.get("pure_data_snapshots", false)), "composition advertises the narrow public-only boundary")
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("FINAL_SETTLEMENT_RUNTIME_COMPOSITION_V06_BENCH|status=%s|checks=%d|failures=%d|notes=%s" % [status, _checks, _failures.size(), JSON.stringify(_failures)])
	if not _failures.is_empty():
		push_error("FinalSettlementRuntimeCompositionV06Bench failed: %s" % [_failures])


func _public_context(outcome_id: String, audited: bool) -> Dictionary:
	var victory_public := {
		"state": "resolved",
		"victory_rule": {"required_top_k_gdp_per_minute": 72, "required_region_count": 2},
		"audit_entries": [
			{"player_index": 0, "cash_ledger_cents": AUDITED_CASH_CENTS},
			{"player_index": 1, "cash_ledger_cents": PRIVATE_CASH_CENTS},
		],
		"outcome_receipt": {
			"outcome_id": outcome_id,
			"schema_version": "v0.6",
			"ruleset_id": "v0.6",
			"reason_code": "public_audit_complete",
			"winner_player_indices": [0],
			"co_victory": false,
			"comparison_order": ["top_k_gdp_per_minute", "controlled_region_count", "cash_ledger_cents"],
			"rankings": [
				{"player_index": 0, "top_k_gdp_per_minute": 120, "top_n_gdp_per_minute": 120, "controlled_region_count": 3, "winner": true},
				{"player_index": 1, "top_k_gdp_per_minute": 90, "top_n_gdp_per_minute": 90, "controlled_region_count": 2, "winner": false},
			],
		},
	}
	if audited:
		victory_public["cash_visibility"] = "public_audit"
		victory_public["audit_revealed_player_indices"] = [0]
	return {
		"victory_public_snapshot": victory_public,
		"participant_names": {"0": "P1", "1": "P2"},
		"public_map_facts": {"active_city_count": 3, "destroyed_district_count": 1, "active_monster_count": 1, "monster_count": 2},
		"resolved_card_count": 4,
	}


func _presentation_receipt(context: Dictionary) -> VictoryPresentationStateChangeReceipt:
	var receipt := VictoryPresentationStateChangeReceipt.new()
	var public_snapshot: Dictionary = context.get("victory_public_snapshot", {}) \
		if context.get("victory_public_snapshot", {}) is Dictionary else {}
	var outcome: Dictionary = public_snapshot.get("outcome_receipt", {}) \
		if public_snapshot.get("outcome_receipt", {}) is Dictionary else {}
	receipt.receipt_id = "victory-outcome-%s" % str(outcome.get("outcome_id", "")).sha256_text().left(16)
	receipt.revision = 4
	receipt.change_kind = &"outcome"
	receipt.previous_state = "audit"
	receipt.state = "resolved"
	receipt.world_time = 185.0
	receipt.public_snapshot = VictoryPresentationStateChangeReceipt.project_public_snapshot(context.get("victory_public_snapshot", {}) as Dictionary)
	receipt.participant_names = VictoryPresentationStateChangeReceipt.project_participant_names(context.get("participant_names", {}) as Dictionary)
	receipt.public_map_facts = VictoryPresentationStateChangeReceipt.project_public_map_facts(context.get("public_map_facts", {}) as Dictionary)
	receipt.immediate_refresh_mask = [&"live", &"full"]
	return receipt


func _on_menu_open_requested(title: String, summary: String, can_continue: bool) -> void:
	_menu_overlay.call("present_menu_shell", {
		"title": title,
		"body": summary,
		"context": "Public final settlement composition bench",
		"context_visible": true,
		"hint": "",
		"hint_visible": false,
		"continue_disabled": not can_continue,
		"continue_visible": can_continue,
		"back_visible": true,
		"nav_visible": true,
		"run_save_visible": false,
		"root_table_menu": false,
		"compact_page": false,
		"viewport_size": Vector2(1280, 720),
		"quick_nav": [],
		"quick_nav_active_id": "standings",
		"quick_nav_visible": false,
	})


func _on_public_log_receipt_requested(receipt: PublicLogReceipt, acknowledgement: Dictionary) -> void:
	var active_port := _query_ports.public_log_port
	if _fail_next_log_ack:
		_query_ports.public_log_port = _rejecting_public_log_port
		_fail_next_log_ack = false
	_query_ports.acknowledge_final_settlement_public_log(receipt, acknowledgement)
	_query_ports.public_log_port = active_port
	_log_acknowledgements.append(acknowledgement.duplicate(true))
	if receipt != null and receipt.is_valid() and bool(acknowledgement.get("accepted", false)) \
			and not bool(acknowledgement.get("duplicate", false)):
		_log_entries.append(receipt.to_dictionary())


func _on_victory_presentation_result_ready(result: Dictionary) -> void:
	_presentation_results.append(result.duplicate(true))


func _on_action_requested(action_id: String) -> void:
	_actions.append(action_id)


func _reset_session(reason_id: String) -> void:
	_query_ports._on_session_authorization_context_changed(reason_id)
	_composition.call("_on_session_authorization_context_changed", reason_id)
	_log_entries.clear()
	_log_acknowledgements.clear()
	_presentation_results.clear()


func _board_count() -> int:
	return find_children("FinalSettlementBoardPanel", "Control", true, false).size()


func _contains_value(value: Variant, needle: Variant) -> bool:
	if value is Dictionary:
		for child_variant in value.values():
			if _contains_value(child_variant, needle):
				return true
		return false
	if value is Array:
		for child_variant in value:
			if _contains_value(child_variant, needle):
				return true
		return false
	if value is String:
		return str(value).contains(str(needle))
	return typeof(value) == typeof(needle) and value == needle


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
