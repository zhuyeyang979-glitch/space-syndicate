extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const QA_SAVE_PATH := "user://test_runs/main_victory_public_privacy_v06.save"
const PRIVATE_CASH_CENTS := 98765432100
const PRIVATE_CASH_TEXT := "987654321.00"
const NON_AUDITED_CASH_CENTS := 12345678900
const FORBIDDEN_PUBLIC_KEYS := ["cash", "cash_cents", "cash_ledger_cents", "available", "available_cents", "escrow", "escrow_cents", "economic_assets", "audit_assets"]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "real main scene loads")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate() as Control
	_expect(main != null, "real main scene instantiates")
	if main == null:
		_finish()
		return
	var save := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	_expect(save != null and bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "victory privacy gate isolates its save path")
	root.add_child(main)
	await _wait_frames(6)
	main.call("_new_game")
	await _wait_frames(6)
	main.set_process(false)

	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var composition := main.get_node_or_null("RuntimeServices/FinalSettlementRuntimeComposition")
	var adapter := composition.get_node_or_null("FinalSettlementPublicSourceAdapter") if composition != null else null
	_expect(coordinator != null and composition != null and adapter != null, "main statically composes Coordinator and FinalSettlementRuntimeComposition with its source adapter")
	if coordinator == null or composition == null or adapter == null:
		main.queue_free()
		await process_frame
		_finish()
		return
	var adapter_debug: Dictionary = adapter.call("debug_snapshot")
	_expect(not bool(adapter_debug.get("owns_victory_rules", true)) and not bool(adapter_debug.get("owns_cash", true)) and not bool(adapter_debug.get("exposes_exact_cash", true)), "public source adapter owns no victory, cash, or exact-balance state")

	var players: Array = (((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array).duplicate(true)
	_expect(players.size() >= 2 and bool((players[1] as Dictionary).get("is_ai", false)), "real new game provides an AI seat for the private cash sentinel")
	if players.size() < 2:
		main.queue_free()
		await process_frame
		_finish()
		return
	var ai_player := (players[1] as Dictionary).duplicate(true)
	ai_player["cash"] = int(PRIVATE_CASH_CENTS / 100)
	ai_player["cash_cents"] = PRIVATE_CASH_CENTS
	players[1] = ai_player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players

	var controller := coordinator.call("victory_control_runtime_controller") as Node
	var world: Dictionary = coordinator.call("victory_control_world_snapshot")
	world["irreversible_planet_destruction_triggered"] = true
	world["scenario_allows_cash_fallback"] = true
	var receipt: Dictionary = controller.call("resolve_special_outcome", "planet_destroyed", world) if controller != null else {}
	var internal_rankings: Array = receipt.get("rankings", []) if receipt.get("rankings", []) is Array else []
	_expect(not receipt.is_empty() and _contains_exact_value(receipt, PRIVATE_CASH_CENTS), "real Victory outcome retains the AI exact cash sentinel internally")
	_expect(not internal_rankings.is_empty() and int((internal_rankings[0] as Dictionary).get("player_index", -1)) == 1, "internal cash tie-break still determines the authoritative ranking")
	_expect(controller.call("outcome_receipt") == receipt, "Victory owner keeps the exact authoritative receipt unchanged")

	coordinator.call("_apply_victory_outcome_receipt", receipt)
	await _wait_frames(3)
	var public_log: Array = coordinator.call("presentation_recent_public_log_entries", 90)
	var participant_names := _participant_names(main, players.size())
	var public_context := {
		"victory_public_snapshot": coordinator.call("victory_control_public_snapshot", -1),
		"participant_names": participant_names,
		"reason": "隐私测试终局",
	}
	var public_source: Dictionary = composition.call("compose_public_source", public_context)
	var public_snapshot: Dictionary = coordinator.call("compose_final_settlement_snapshot", public_source)
	var public_summary := str(composition.call("latest_public_summary"))
	var standings_query := main.get_node_or_null("RuntimeServices/StandingsPublicQueryPort")
	var standings_snapshot: Dictionary = standings_query.call("snapshot_for_authorized_viewer", 960.0) if standings_query != null else {}
	var root_summary := str(standings_snapshot.get("summary_text", ""))

	var key_paths: Array[String] = []
	for named_value in [
		{"name": "context", "value": public_context},
		{"name": "source", "value": public_source},
		{"name": "snapshot", "value": public_snapshot},
	]:
		_collect_forbidden_key_paths((named_value as Dictionary).get("value"), str((named_value as Dictionary).get("name", "public")), key_paths)
	_expect(key_paths.is_empty(), "public facts/source/snapshot recursively omit exact cash and asset keys: %s" % [key_paths])
	var value_paths: Array[String] = []
	_collect_exact_value_paths([public_log, public_context, public_source, public_snapshot, public_summary, root_summary], [PRIVATE_CASH_CENTS, PRIVATE_CASH_TEXT, str(PRIVATE_CASH_CENTS), "987654321"], "public", value_paths)
	_expect(value_paths.is_empty(), "outcome log, settlement source, board source, and root summary contain no private cash sentinel: %s" % [value_paths])
	_expect(public_summary.contains("准确现金只对权威审计名单公开") and root_summary.contains("准确现金只对权威审计名单公开"), "public recap explains the state-authorized audit boundary")
	_expect(_is_pure_data(public_source) and _is_pure_data(public_log), "public adapter and log outputs are pure data")

	var authorized_public: Dictionary = (public_context.get("victory_public_snapshot", {}) as Dictionary).duplicate(true)
	authorized_public["cash_visibility"] = "public_audit"
	authorized_public["audit_revealed_player_indices"] = [1]
	authorized_public["audit_entries"] = [
		{"player_index": 1, "cash_ledger_cents": PRIVATE_CASH_CENTS},
		{"player_index": 0, "cash_ledger_cents": NON_AUDITED_CASH_CENTS},
	]
	var authorized_context := public_context.duplicate(true)
	authorized_context["victory_public_snapshot"] = authorized_public
	var authorized_source: Dictionary = composition.call("compose_public_source", authorized_context)
	var authorized_log: Dictionary = adapter.call("public_outcome_log_payload", authorized_public, participant_names)
	_expect(_contains_exact_value(authorized_source, PRIVATE_CASH_CENTS) and _contains_exact_value(authorized_log, PRIVATE_CASH_TEXT), "an explicitly authorized audit seat exposes its exact cash through the public projection")
	_expect(not _contains_exact_value(authorized_source, NON_AUDITED_CASH_CENTS) and not _contains_exact_value(authorized_log, "123456789.00"), "a non-audit opponent remains hidden even when an untrusted entry carries exact cash")
	var forged_public := authorized_public.duplicate(true)
	forged_public.erase("cash_visibility")
	var forged_context := authorized_context.duplicate(true)
	forged_context["victory_public_snapshot"] = forged_public
	var forged_source: Dictionary = composition.call("compose_public_source", forged_context)
	var forged_log: Dictionary = adapter.call("public_outcome_log_payload", forged_public, participant_names)
	_expect(not _contains_exact_value(forged_source, PRIVATE_CASH_CENTS) and not _contains_exact_value(forged_log, PRIVATE_CASH_TEXT), "cash injected without the authoritative visibility state fails closed")

	var raw_log_count := (coordinator.call("presentation_recent_public_log_entries", 90) as Array).size()
	var first_outcome_count := int(((coordinator.table_presentation_query_ports().debug_snapshot().get("victory_receipts", {}) as Dictionary)).get("outcome_receipt_count", 0))
	coordinator.call("_apply_victory_outcome_receipt", receipt)
	var replay_logs: Array = coordinator.call("presentation_recent_public_log_entries", 90)
	var replay_paths: Array[String] = []
	_collect_exact_value_paths(replay_logs, [PRIVATE_CASH_CENTS, PRIVATE_CASH_TEXT, str(PRIVATE_CASH_CENTS), "987654321"], "replay_logs", replay_paths)
	_expect((coordinator.call("presentation_recent_public_log_entries", 90) as Array).size() >= raw_log_count and replay_paths.is_empty(), "reapplying an outcome never adds a sensitive public log")
	var replay_outcome_count := int(((coordinator.table_presentation_query_ports().debug_snapshot().get("victory_receipts", {}) as Dictionary)).get("outcome_receipt_count", 0))
	_expect(first_outcome_count == 1 and replay_outcome_count == first_outcome_count, "session outcome, AI learning handoff, and victory presentation remain exact-once on replay")
	var invalid_log_count := (coordinator.call("presentation_recent_public_log_entries", 90) as Array).size()
	coordinator.call("_apply_victory_outcome_receipt", {})
	coordinator.call("_apply_victory_outcome_receipt", {"outcome_id": "invalid", "rankings": []})
	_expect((coordinator.call("presentation_recent_public_log_entries", 90) as Array).size() == invalid_log_count, "empty and malformed outcomes fail closed without public logs")

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var main_scene_source := FileAccess.get_file_as_string(MAIN_SCENE_PATH)
	_expect(not main_source.contains("func _final_settlement_public_source_snapshot(") and not main_source.contains("func _final_run_summary_text(") and not main_source.contains("func _final_player_breakdown_summary("), "legacy main settlement source and summary formatters are physically absent")
	_expect(main_scene_source.contains("FinalSettlementRuntimeComposition.tscn") and main_source.contains("func _final_settlement_runtime_composition_node("), "main scene owns the settlement composition and main retains only its node lookup boundary")

	main.queue_free()
	await process_frame
	_finish()


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _participant_names(main: Node, player_count: int) -> Dictionary:
	var result: Dictionary = {}
	for player_index in range(player_count):
		result[str(player_index)] = str(main.call("_player_name", player_index))
	return result


func _collect_forbidden_key_paths(value: Variant, path: String, result: Array[String]) -> void:
	if value is Dictionary:
		for key_variant in value.keys():
			var key := str(key_variant)
			var child_path := "%s.%s" % [path, key]
			if FORBIDDEN_PUBLIC_KEYS.has(key.to_lower()):
				result.append(child_path)
			_collect_forbidden_key_paths(value[key_variant], child_path, result)
	elif value is Array:
		for index in range(value.size()):
			_collect_forbidden_key_paths(value[index], "%s[%d]" % [path, index], result)


func _collect_exact_value_paths(value: Variant, sentinels: Array, path: String, result: Array[String]) -> void:
	if value is Dictionary:
		for key_variant in value.keys():
			_collect_exact_value_paths(value[key_variant], sentinels, "%s.%s" % [path, str(key_variant)], result)
	elif value is Array:
		for index in range(value.size()):
			_collect_exact_value_paths(value[index], sentinels, "%s[%d]" % [path, index], result)
	elif sentinels.has(value) or (value is String and (str(value).contains(PRIVATE_CASH_TEXT) or str(value).contains(str(PRIVATE_CASH_CENTS)))):
		result.append(path)


func _contains_exact_value(value: Variant, sentinel: Variant) -> bool:
	if value is Dictionary:
		for key_variant in value.keys():
			if _contains_exact_value(value[key_variant], sentinel):
				return true
		return false
	if value is Array:
		for item_variant in value:
			if _contains_exact_value(item_variant, sentinel):
				return true
		return false
	if value is String:
		return str(value).contains(str(sentinel))
	return typeof(value) == typeof(sentinel) and value == sentinel


func _is_pure_data(value: Variant) -> bool:
	if value is Object or value is Callable:
		return false
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item_variant in value:
			if not _is_pure_data(item_variant):
				return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("MAIN VICTORY PUBLIC PRIVACY: %s" % message)


func _finish() -> void:
	print("MAIN_VICTORY_PUBLIC_PRIVACY_V06_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(_failures.size())
