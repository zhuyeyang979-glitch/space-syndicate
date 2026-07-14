extends Control

const AUDITED_CASH_CENTS := 98765432100
const PRIVATE_CASH_CENTS := 12345678900

@onready var _menu_overlay: Control = $MenuModalOverlay
@onready var _snapshot_service: Node = $FinalSettlementPublicSnapshotService
@onready var _composition: Node = $FinalSettlementRuntimeComposition

var _checks := 0
var _failures: Array[String] = []
var _log_entries: Array[String] = []
var _actions: Array[String] = []


func _ready() -> void:
	_snapshot_service.call("configure", {})
	call_deferred("_run")


func _run() -> void:
	var normal_context := _public_context("bench.normal", false)
	var first_result := _composition.call("present", normal_context) as Dictionary
	await _wait_frames(3)
	var board := _composition.call("board_node") as Control
	_expect(bool(first_result.get("accepted", false)), "normal public outcome opens")
	_expect(board != null and board.is_visible_in_tree() and board.size.x > 0.0 and board.size.y > 0.0, "board is visible with non-zero geometry")
	_expect(_board_count() == 1, "composition owns exactly one board")
	_expect(not _contains_value(_composition.call("last_public_snapshot"), AUDITED_CASH_CENTS) and not _contains_value(_log_entries, "987654321.00"), "ordinary outcome hides exact cash")

	var first_log_count := _log_entries.size()
	var first_board_id := board.get_instance_id()
	var replay_result := _composition.call("present", normal_context) as Dictionary
	await _wait_frames(2)
	_expect(bool(replay_result.get("accepted", false)) and _board_count() == 1 and (_composition.call("board_node") as Control).get_instance_id() == first_board_id, "reopen reuses the same board")
	_expect(_log_entries.size() == first_log_count, "reopen emits public outcome logs exactly once")

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


func _on_public_log_entry_requested(text: String) -> void:
	_log_entries.append(text)


func _on_action_requested(action_id: String) -> void:
	_actions.append(action_id)


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
