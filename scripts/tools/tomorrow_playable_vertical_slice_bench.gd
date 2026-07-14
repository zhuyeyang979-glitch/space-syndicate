extends Control
class_name TomorrowPlayableVerticalSliceBench

const SUITE_ID := "tomorrow-playable-vertical-slice-vs06-c"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const QA_SAVE_PATH := "user://test_runs/tomorrow_vertical_slice.save"
const DEFAULT_PLAYER_SAVE_PATH := "user://space_syndicate_current_run.save"
const REPORT_PATH := "res://reports/playability/tomorrow_vertical_slice/coordinator_runtime_manifest.json"
const FIXED_SEED := 60610
const EXPECTED_RECORD_IDS := [
	"main_menu_new_run_setup",
	"new_match_one_human_two_ai",
	"public_facility_core_dispatch_exact_once",
	"commodity_flow_realtime_income",
	"human_optional_summon_after_economy",
	"ai_progress_without_deadlock",
	"victory_qualification_audit_outcome",
	"settlement_recap_visible",
	"player_facing_privacy",
	"qa_save_isolation",
]
const FORBIDDEN_PUBLIC_KEYS := [
	"true_owner",
	"hidden_owner",
	"owner_truth",
	"private_owner",
	"private_payload",
	"opponent_cash",
	"opponent_hand",
	"opponent_discard",
	"cash_ledger_cents",
	"available_cents",
	"counted_hand_size",
	"ordinary_hand_count",
	"private_hand",
	"discard_pile",
	"ai_memory",
	"ai_plan",
	"ai_private_plan",
	"private_plan",
	"route_plan",
	"decision_samples",
	"reasoning",
	"utility_scores",
]
const PRIVATE_VALUE_SENTINELS := [
	"987654321",
	"VS06_PRIVATE_HAND_SENTINEL",
	"VS06_TRUE_OWNER_SENTINEL",
	"VS06_AI_PLAN_SENTINEL",
]

@export var auto_run_on_ready := true
@export var write_evidence := true
@export var quit_when_complete := true

@onready var runtime_viewport: SubViewport = %RuntimeViewport
@onready var status_label: Label = %StatusLabel
@onready var result_label: RichTextLabel = %ResultLabel

var _records: Array[Dictionary] = []
var _failures: Array[String] = []
var _privacy_leaks: Array[String] = []
var _main: Node
var _coordinator: Node
var _setup_snapshot: Dictionary = {}
var _ai_setup_secrets: Array[String] = []
var _victory_receipt: Dictionary = {}
var _final_settlement_snapshot: Dictionary = {}
var _stage4_facility_region_id := ""
var _default_save_before := ""
var _qa_override_ready := false


func _ready() -> void:
	if auto_run_on_ready and not Engine.is_editor_hint():
		call_deferred("_run_from_scene")


func _run_from_scene() -> void:
	var manifest := await run_acceptance()
	print("TOMORROW_VERTICAL_SLICE_BENCH|status=%s|checks=%d|failures=%d|privacy_leaks=%d" % [
		"PASS" if bool(manifest.get("passed", false)) else "FAIL",
		int(manifest.get("checks", 0)),
		int(manifest.get("failure_count", 0)),
		int(manifest.get("privacy_leak_count", 0)),
	])
	if quit_when_complete:
		get_tree().quit(0 if bool(manifest.get("passed", false)) else 1)


func run_acceptance() -> Dictionary:
	_records.clear()
	_failures.clear()
	_privacy_leaks.clear()
	_setup_snapshot.clear()
	_ai_setup_secrets.clear()
	_victory_receipt.clear()
	_final_settlement_snapshot.clear()
	status_label.text = "Running deterministic production-facing vertical slice…"
	_default_save_before = _file_fingerprint(DEFAULT_PLAYER_SAVE_PATH)

	_main = await _instantiate_production_main()
	if _main == null:
		_record("main_menu_new_run_setup", false, "main.tscn could not be loaded and instantiated through the isolated QA harness")
		_record_remaining_as_blocked("main_scene_unavailable")
		return _finish_manifest()

	await _stage_main_menu_and_setup()
	await _stage_start_three_seat_match()
	await _stage_public_facility_dispatch()
	await _stage_realtime_income()
	await _stage_human_optional_summon_after_economy()
	await _stage_ai_progress()
	await _stage_victory_countdown()
	await _stage_settlement_recap()
	await _stage_privacy()
	await _stage_save_isolation()
	_release_main()
	return _finish_manifest()


func _instantiate_production_main() -> Node:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	var main := packed.instantiate()
	if main == null:
		return null
	var save := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	if save == null or not save.has_method("set_qa_default_save_path_override"):
		main.free()
		return null
	_qa_override_ready = bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH))
	if not _qa_override_ready:
		main.free()
		return null
	runtime_viewport.size = Vector2i(1600, 960)
	runtime_viewport.add_child(main)
	await _wait_frames(8)
	var rng_variant: Variant = main.get("rng")
	if rng_variant is RandomNumberGenerator:
		(rng_variant as RandomNumberGenerator).seed = FIXED_SEED
	_coordinator = main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	return main


func _stage_main_menu_and_setup() -> void:
	_main.call("_open_main_menu")
	await _wait_frames(2)
	var lobby_variant: Variant = _main.call("_main_menu_root_lobby_snapshot")
	var lobby: Dictionary = lobby_variant if lobby_variant is Dictionary else {}
	var has_new_run := _contains_action_id(lobby, "new_run")
	if has_new_run:
		_main.call("_on_menu_root_lobby_action_requested", "new_run")
	else:
		# Continue gathering independent evidence without turning this missing root action green.
		_main.call("_open_new_game_setup_menu")
	await _wait_frames(3)
	var setup_node := _main.find_child("NewGameSetupPage", true, false)
	var setup_visible := setup_node is CanvasItem and (setup_node as CanvasItem).is_visible_in_tree()
	var menu_overlay: Variant = _main.get("menu_overlay")
	var menu_visible := menu_overlay is CanvasItem and (menu_overlay as CanvasItem).visible

	_main.call("_close_menu")
	await _wait_frames(2)
	var players: Array = _array_property(_main, "players")
	menu_overlay = _main.get("menu_overlay")
	var idle_close_safe := not players.is_empty() or (menu_overlay is CanvasItem and (menu_overlay as CanvasItem).visible)
	if not (menu_overlay is CanvasItem and (menu_overlay as CanvasItem).visible):
		_main.call("_open_new_game_setup_menu")
		await _wait_frames(2)
	_record(
		"main_menu_new_run_setup",
		has_new_run and setup_visible and menu_visible and idle_close_safe,
		"root lobby must expose new_run, open the real NewGameSetupPage, and refuse an idle close into an empty table",
		{
			"root_new_run_action": has_new_run,
			"setup_visible": setup_visible,
			"idle_close_safe": idle_close_safe,
		}
	)


func _stage_start_three_seat_match() -> void:
	_main.set("configured_player_count", 3)
	_main.set("configured_ai_player_count", 2)
	_main.set("configured_roguelike_depth", 1)
	_main.set("configured_role_indices", [0, 1, 2])
	_main.set("configured_starter_monster_indices", [0, 1, 2])
	_main.call("_open_new_game_setup_menu")
	await _wait_frames(2)
	_setup_snapshot = (_main.call("_new_game_setup_page_snapshot") as Dictionary).duplicate(true)
	_capture_ai_setup_secrets()
	_main.call("_on_new_game_setup_action_requested", "setup_start")
	await _wait_frames(10)

	var players: Array = _array_property(_main, "players")
	var seats_valid := players.size() == 3
	if players.size() == 3:
		seats_valid = seats_valid and not bool((players[0] as Dictionary).get("is_ai", true))
		seats_valid = seats_valid and bool((players[1] as Dictionary).get("is_ai", false))
		seats_valid = seats_valid and bool((players[2] as Dictionary).get("is_ai", false))
	var session_summary: Dictionary = {}
	if _coordinator != null and _coordinator.has_method("session_debug_snapshot"):
		var session_variant: Variant = _coordinator.call("session_debug_snapshot")
		session_summary = session_variant if session_variant is Dictionary else {}
	else:
		var session := _coordinator.get_node_or_null("GameSessionRuntimeController") if _coordinator != null else null
		if session != null and session.has_method("session_summary"):
			session_summary = session.call("session_summary") as Dictionary
	var session_running := str(session_summary.get("session_state", "")) == "running"

	var adapter: Object = _coordinator.call("card_player_state_production_adapter_v06") if _coordinator != null and _coordinator.has_method("card_player_state_production_adapter_v06") else null
	var core: Object = _coordinator.call("core_economic_card_runtime_adapter_v06") if _coordinator != null and _coordinator.has_method("core_economic_card_runtime_adapter_v06") else null
	var actor_map: Dictionary = adapter.call("actor_player_indices") if adapter != null and adapter.has_method("actor_player_indices") else {}
	var actor_map_valid := actor_map.size() == 3
	for player_index in range(3):
		actor_map_valid = actor_map_valid and int(actor_map.get(_actor_id(players, player_index), -1)) == player_index
	var core_debug: Dictionary = core.call("debug_snapshot") if core != null and core.has_method("debug_snapshot") else {}
	var core_configured := bool(core_debug.get("configured", false))
	_record(
		"new_match_one_human_two_ai",
		seats_valid and session_running and actor_map_valid and core_configured,
		"real setup_start must create one human plus two AI and refresh the v0.6 production player bindings",
		{
			"player_count": players.size(),
			"session_state": str(session_summary.get("session_state", "missing")),
			"actor_map": actor_map,
			"core_configured": core_configured,
			"core_reason": str(core_debug.get("last_reason_code", "missing")),
		}
	)


func _stage_human_optional_summon_after_economy() -> void:
	var monster := _monster_owner()
	var before_snapshot: Dictionary = monster.call("unit_card_snapshot_v06", "monster") if monster != null and monster.has_method("unit_card_snapshot_v06") else {}
	var before_count := int(before_snapshot.get("monster_count", -1))
	var before_save: Dictionary = monster.call("to_save_data") if monster != null and monster.has_method("to_save_data") else {}
	var before_journal: Dictionary = before_save.get("monster_card_atomic_terminal_journal", {}) if before_save.get("monster_card_atomic_terminal_journal", {}) is Dictionary else {}

	var district := int(_main.call("_first_run_recommended_start_district", 0))
	if district >= 0:
		_main.call("_select_district", district)
	var submitted := bool(_main.call("_activate_first_run_coach_action", "coach_first_summon"))
	var drained := await _drain_card_resolution(240)
	var after_snapshot: Dictionary = monster.call("unit_card_snapshot_v06", "monster") if monster != null and monster.has_method("unit_card_snapshot_v06") else {}
	var after_save: Dictionary = monster.call("to_save_data") if monster != null and monster.has_method("to_save_data") else {}
	var after_journal: Dictionary = after_save.get("monster_card_atomic_terminal_journal", {}) if after_save.get("monster_card_atomic_terminal_journal", {}) is Dictionary else {}
	var new_terminals := _new_dictionary_keys(before_journal, after_journal)
	var finalized_count := 0
	var terminal_evidence: Array[Dictionary] = []
	for transaction_id in new_terminals:
		var terminal: Dictionary = after_journal.get(transaction_id, {}) if after_journal.get(transaction_id, {}) is Dictionary else {}
		var terminal_receipt: Dictionary = terminal.get("receipt", {}) if terminal.get("receipt", {}) is Dictionary else {}
		var receipt_finalized := bool(terminal_receipt.get("finalized", false))
		if str(terminal.get("stage", "")) == "finalized" and receipt_finalized:
			finalized_count += 1
		terminal_evidence.append({
			"transaction_id": str(transaction_id),
			"stage": str(terminal.get("stage", "missing")),
			"receipt_finalized": receipt_finalized,
		})
	var scenario := _scenario_state()
	var signals: Dictionary = scenario.get("completed_signals", {}) if scenario.get("completed_signals", {}) is Dictionary else {}
	var evidence := {
		"submitted": submitted,
		"queue_drained": drained,
		"before_count": before_count,
		"after_count": int(after_snapshot.get("monster_count", -1)),
		"new_terminal_count": new_terminals.size(),
		"finalized_count": finalized_count,
		"terminal_evidence": terminal_evidence,
		"inflight_count": int(after_snapshot.get("inflight_count", -1)),
		"checkpoint_open": bool(after_snapshot.get("checkpoint_open", false)),
	}
	var passed := _optional_summon_evidence_passes(evidence)
	_record(
		"human_optional_summon_after_economy",
		passed,
		"after facility and income progress, the held human starter remains voluntarily summonable through one authoritative prepare/commit/finalize transaction",
		{
			"submitted": bool(evidence.get("submitted", false)),
			"queue_drained": bool(evidence.get("queue_drained", false)),
			"before_count": int(evidence.get("before_count", -1)),
			"after_count": int(evidence.get("after_count", -1)),
			"new_terminal_count": int(evidence.get("new_terminal_count", -1)),
			"finalized_count": int(evidence.get("finalized_count", -1)),
			"terminal_evidence": terminal_evidence.duplicate(true),
			"inflight_count": int(evidence.get("inflight_count", -1)),
			"checkpoint_open": bool(evidence.get("checkpoint_open", false)),
			"checkpoint_semantics": "open means the authoritative monster reservation set is empty after finalize",
			"scenario_signal_gated": false,
			"campaign_monster_summoned_signal_observed": bool(signals.get("monster_summoned", false)),
			"campaign_objective_scope": "not asserted by ordinary setup_start",
		}
	)


func _stage_public_facility_dispatch() -> void:
	var players := _array_property(_main, "players")
	var actor_id := _actor_id(players, 0)
	var inventory := _commodity_inventory_owner()
	var core := _core_economic_owner()
	var infrastructure := _infrastructure_owner()
	var canonical_card: Dictionary = _coordinator.call("v06_first_table_facility_card") if _coordinator != null and _coordinator.has_method("v06_first_table_facility_card") else {}
	var canonical_machine: Dictionary = canonical_card.get("machine", {}) if canonical_card.get("machine", {}) is Dictionary else {}
	var canonical_player_text: Dictionary = canonical_card.get("player", {}) if canonical_card.get("player", {}) is Dictionary else {}
	var canonical_card_id := str(canonical_machine.get("card_id", ""))
	var market_surface: Dictionary = _coordinator.call("v06_first_table_facility_market_snapshot", actor_id) if _coordinator != null and _coordinator.has_method("v06_first_table_facility_market_snapshot") else {}
	var before_market: Dictionary = market_surface.get("market", {}) if market_surface.get("market", {}) is Dictionary else {}
	var listing: Dictionary = market_surface.get("listing", {}) if market_surface.get("listing", {}) is Dictionary else {}
	var listing_card: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
	var listing_machine: Dictionary = listing_card.get("machine", {}) if listing_card.get("machine", {}) is Dictionary else {}
	var source_item_id := str(listing.get("item_id", ""))
	var before_player: Dictionary = market_surface.get("player", {}) if market_surface.get("player", {}) is Dictionary else {}
	var before_assets: Dictionary = before_player.get("assets", {}) if before_player.get("assets", {}) is Dictionary else {}
	var before_journal: Dictionary = inventory.call("transaction_journal_snapshot") if inventory != null and inventory.has_method("transaction_journal_snapshot") else {}
	var before_facilities: Array = infrastructure.call("facilities_snapshot", false) if infrastructure != null and infrastructure.has_method("facilities_snapshot") else []
	var core_debug: Dictionary = core.call("debug_snapshot") if core != null and core.has_method("debug_snapshot") else {}

	var purchase_transaction_id := "vs06-c:facility-purchase:%s" % actor_id
	var purchase: Dictionary = _coordinator.call(
		"purchase_v06_first_table_facility_card",
		actor_id,
		source_item_id,
		purchase_transaction_id
	) if _coordinator != null and _coordinator.has_method("purchase_v06_first_table_facility_card") else {}
	var after_purchase_player: Dictionary = _coordinator.call("v06_card_player_snapshot", actor_id) if _coordinator != null and _coordinator.has_method("v06_card_player_snapshot") else {}
	var after_purchase_facilities: Array = infrastructure.call("facilities_snapshot", false) if infrastructure != null and infrastructure.has_method("facilities_snapshot") else []
	var after_purchase_surface: Dictionary = _coordinator.call("v06_first_table_facility_market_snapshot", actor_id) if _coordinator != null and _coordinator.has_method("v06_first_table_facility_market_snapshot") else {}
	var after_purchase_market: Dictionary = after_purchase_surface.get("market", {}) if after_purchase_surface.get("market", {}) is Dictionary else {}
	var slot_index := _find_v06_card_slot(after_purchase_player, canonical_card_id)
	var region_id := _selected_v06_region_id()
	var play_transaction_id := "vs06-c:facility-play:%s:%s" % [actor_id, canonical_card_id]
	var play_request := {
		"actor_id": actor_id,
		"slot_index": slot_index,
		"transaction_id": play_transaction_id,
		"region_id": region_id,
		"game_time": float(_main.get("game_time")),
	}
	var play: Dictionary = _coordinator.call("play_v06_runtime_card", play_request) if bool(purchase.get("committed", false)) and slot_index >= 0 and not region_id.is_empty() and _coordinator != null and _coordinator.has_method("play_v06_runtime_card") else {}
	var play_effect_finalization: Dictionary = play.get("effect_finalization", {}) if play.get("effect_finalization", {}) is Dictionary else {}
	if bool(play.get("committed", false)) and bool(play_effect_finalization.get("finalized", false)):
		_stage4_facility_region_id = region_id
	var after_player: Dictionary = _coordinator.call("v06_card_player_snapshot", actor_id) if _coordinator != null and _coordinator.has_method("v06_card_player_snapshot") else {}
	var after_play_surface: Dictionary = _coordinator.call("v06_first_table_facility_market_snapshot", actor_id) if _coordinator != null and _coordinator.has_method("v06_first_table_facility_market_snapshot") else {}
	var after_market: Dictionary = after_play_surface.get("market", {}) if after_play_surface.get("market", {}) is Dictionary else {}
	var after_journal: Dictionary = inventory.call("transaction_journal_snapshot") if inventory != null and inventory.has_method("transaction_journal_snapshot") else {}
	var after_facilities: Array = infrastructure.call("facilities_snapshot", false) if infrastructure != null and infrastructure.has_method("facilities_snapshot") else []
	var new_transactions := _new_dictionary_keys(before_journal, after_journal)
	var finalized_play_transactions := 0
	for transaction_id in new_transactions:
		var journal_entry: Dictionary = after_journal.get(transaction_id, {}) if after_journal.get(transaction_id, {}) is Dictionary else {}
		var result: Dictionary = journal_entry.get("result", {}) if journal_entry.get("result", {}) is Dictionary else {}
		var finalization: Dictionary = result.get("effect_finalization", {}) if result.get("effect_finalization", {}) is Dictionary else {}
		if str(result.get("operation", "")) == "play_card" and bool(result.get("committed", false)) and bool(finalization.get("finalized", false)):
			finalized_play_transactions += 1
	var purchase_journal_entry: Dictionary = after_journal.get(purchase_transaction_id, {}) if after_journal.get(purchase_transaction_id, {}) is Dictionary else {}
	var purchase_journal_result: Dictionary = purchase_journal_entry.get("result", {}) if purchase_journal_entry.get("result", {}) is Dictionary else {}
	var play_journal_entry: Dictionary = after_journal.get(play_transaction_id, {}) if after_journal.get(play_transaction_id, {}) is Dictionary else {}
	var play_journal_result: Dictionary = play_journal_entry.get("result", {}) if play_journal_entry.get("result", {}) is Dictionary else {}
	var play_finalization: Dictionary = play_journal_result.get("effect_finalization", {}) if play_journal_result.get("effect_finalization", {}) is Dictionary else {}

	# Replay the same public request, rather than merely draining an already-empty queue.
	var replay: Dictionary = _coordinator.call("play_v06_runtime_card", play_request) if bool(play.get("committed", false)) and _coordinator != null and _coordinator.has_method("play_v06_runtime_card") else {}
	var replay_player: Dictionary = _coordinator.call("v06_card_player_snapshot", actor_id) if _coordinator != null and _coordinator.has_method("v06_card_player_snapshot") else {}
	var replay_market_surface: Dictionary = _coordinator.call("v06_first_table_facility_market_snapshot", actor_id) if _coordinator != null and _coordinator.has_method("v06_first_table_facility_market_snapshot") else {}
	var replay_market: Dictionary = replay_market_surface.get("market", {}) if replay_market_surface.get("market", {}) is Dictionary else {}
	var replay_journal: Dictionary = inventory.call("transaction_journal_snapshot") if inventory != null and inventory.has_method("transaction_journal_snapshot") else {}
	var replay_facilities: Array = infrastructure.call("facilities_snapshot", false) if infrastructure != null and infrastructure.has_method("facilities_snapshot") else []
	var after_purchase_assets: Dictionary = after_purchase_player.get("assets", {}) if after_purchase_player.get("assets", {}) is Dictionary else {}
	var after_assets: Dictionary = after_player.get("assets", {}) if after_player.get("assets", {}) is Dictionary else {}
	var replay_assets: Dictionary = replay_player.get("assets", {}) if replay_player.get("assets", {}) is Dictionary else {}
	var evidence := {
		"canonical_card_id": canonical_card_id,
		"canonical_facility": str(canonical_machine.get("category_id", "")) == "facility" and int(canonical_machine.get("rank", 0)) == 1 and str(canonical_machine.get("effect_kind", "")) == "build_upgrade_or_repair_facility",
		"canonical_purchase_cash": int(canonical_machine.get("purchase_cash", -1)),
		"canonical_asset_total": _asset_total(canonical_machine.get("asset_cost", {})),
		"market_ready": bool(market_surface.get("ready", false)),
		"listing_matches_canonical": str(listing_machine.get("card_id", "")) == canonical_card_id and not source_item_id.is_empty(),
		"core_configured": bool(core_debug.get("configured", false)),
		"purchase_committed": bool(purchase.get("committed", false)),
		"purchase_card_matches": str(purchase.get("card_id", "")) == canonical_card_id,
		"purchase_price": int(purchase.get("canonical_price_cash", -1)),
		"cash_debit": int(before_player.get("cash", 0)) - int(after_purchase_player.get("cash", 0)),
		"cash_stable_after_purchase": int(after_purchase_player.get("cash", -1)) == int(after_player.get("cash", -2)) and int(after_player.get("cash", -1)) == int(replay_player.get("cash", -2)),
		"assets_unchanged": _same_data(before_assets, after_purchase_assets) and _same_data(after_purchase_assets, after_assets) and _same_data(after_assets, replay_assets),
		"player_revision_before": int(before_player.get("revision", -1)),
		"player_revision_after_purchase": int(after_purchase_player.get("revision", -1)),
		"player_revision_after_play": int(after_player.get("revision", -1)),
		"player_revision_after_replay": int(replay_player.get("revision", -1)),
		"market_revision_before": int(before_market.get("revision", -1)),
		"market_revision_after_purchase": int(after_purchase_market.get("revision", -1)),
		"market_revision_after_play": int(after_market.get("revision", -1)),
		"market_revision_after_replay": int(replay_market.get("revision", -1)),
		"slot_index": slot_index,
		"region_id": region_id,
		"card_consumed": _find_v06_card_slot(after_player, canonical_card_id) < 0,
		"play_handled": bool(play.get("handled", false)),
		"play_committed": bool(play.get("committed", false)),
		"play_route_id": str(play.get("route_id", "")),
		"play_finalized": bool((play.get("effect_finalization", {}) as Dictionary).get("finalized", false)) if play.get("effect_finalization", {}) is Dictionary else false,
		"new_transaction_count": new_transactions.size(),
		"purchase_journal_committed": str(purchase_journal_result.get("operation", "")) == "market_purchase" and bool(purchase_journal_result.get("committed", false)),
		"play_transaction_present": str(play_journal_result.get("operation", "")) == "play_card" and bool(play_journal_result.get("committed", false)) and bool(play_finalization.get("finalized", false)),
		"finalized_play_transaction_count": finalized_play_transactions,
		"facility_delta": after_facilities.size() - before_facilities.size(),
		"purchase_did_not_build": _same_data(before_facilities, after_purchase_facilities),
		"replay_committed": bool(replay.get("committed", false)),
		"replay_idempotent": bool(replay.get("idempotent_replay", false)),
		"replay_state_unchanged": _same_data(after_player, replay_player) and _same_data(after_market, replay_market) and _same_data(after_facilities, replay_facilities) and _same_data(after_journal, replay_journal),
	}
	var passed := _stage4_evidence_passes(evidence)
	_record(
		"public_facility_core_dispatch_exact_once",
		passed,
		"the canonical rank-I v0.6 facility must be bought and played once through the frozen Coordinator facade with exact revisions and idempotent CardFlow replay",
		{
			"canonical_card_id": canonical_card_id,
			"card_name": str(canonical_player_text.get("name", canonical_card_id)),
			"source_item_id": source_item_id,
			"purchase_reason": str(purchase.get("reason_code", "missing")),
			"play_reason": str(play.get("reason_code", "missing")),
			"replay_reason": str(replay.get("reason_code", "missing")),
			"purchase_transaction_id": purchase_transaction_id,
			"play_transaction_id": play_transaction_id,
			"new_transactions": new_transactions,
			"evidence": evidence,
		}
	)


func _stage_realtime_income() -> void:
	var flow := _commodity_flow_owner()
	var players: Array = _array_property(_main, "players")
	var before_cash := _player_cash_cents(players, 0)
	var before_receipts: Array = flow.call("recent_sale_receipts_snapshot", -1) if flow != null and flow.has_method("recent_sale_receipts_snapshot") else []
	for _second in range(120):
		_main.set("game_time", float(_main.get("game_time")) + 1.0)
		_main.call("_advance_continuous_commodity_flow", 1.0)
		if _second % 10 == 0:
			await get_tree().process_frame
	players = _array_property(_main, "players")
	var after_cash := _player_cash_cents(players, 0)
	var after_receipts: Array = flow.call("recent_sale_receipts_snapshot", -1) if flow != null and flow.has_method("recent_sale_receipts_snapshot") else []
	var new_receipts: Array = after_receipts.slice(before_receipts.size()) if after_receipts.size() >= before_receipts.size() else []
	var gdp_region_id := _stage4_facility_region_id
	var trade_kinds: Array[String] = []
	var local_sold_units := 0
	for receipt_variant in new_receipts:
		if not (receipt_variant is Dictionary):
			continue
		var receipt: Dictionary = receipt_variant
		var receipt_region_id := str(receipt.get("market_region_id", "")).strip_edges()
		if not receipt_region_id.is_empty():
			gdp_region_id = receipt_region_id
		var trade_kind := str(receipt.get("trade_kind", "")).strip_edges()
		trade_kinds.append(trade_kind)
		if trade_kind.begins_with("local_"):
			local_sold_units += maxi(0, int(receipt.get("units", 0)))
	var region_gdp: Dictionary = {}
	if flow != null and flow.has_method("region_gdp_snapshot") and not gdp_region_id.is_empty():
		region_gdp = flow.call("region_gdp_snapshot", gdp_region_id) as Dictionary
	var ledger := ((players[0] as Dictionary).get("v06_transaction_ledger", []) as Array) if not players.is_empty() else []
	var sale_rows := 0
	for row_variant in ledger:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("category", "")) == "commodity_sale":
			sale_rows += 1
	var gdp_cents := int(region_gdp.get("region_gdp_per_minute_cents", 0))
	var flow_debug: Dictionary = flow.call("debug_snapshot") if flow != null and flow.has_method("debug_snapshot") else {}
	var flow_metrics: Dictionary = flow_debug.get("last_flow_metrics", {}) if flow_debug.get("last_flow_metrics", {}) is Dictionary else {}
	var passed := after_receipts.size() > before_receipts.size() and after_cash > before_cash and sale_rows > 0 and gdp_cents > 0
	_record(
		"commodity_flow_realtime_income",
		passed,
		"the played facility/project must feed CommodityFlow so real seconds create Sale Receipts, GDP, and cash ledger income",
		{
			"receipt_delta": after_receipts.size() - before_receipts.size(),
			"cash_cents_delta": after_cash - before_cash,
			"commodity_sale_rows": sale_rows,
			"gdp_region_id": gdp_region_id,
			"region_gdp_per_minute_cents": gdp_cents,
			"trade_kinds": trade_kinds,
			"local_sold_units": local_sold_units,
			"backpressured_milliunits": int(flow_metrics.get("backpressured_milliunits", 0)),
			"warehouse_stored_milliunits": int(flow_metrics.get("warehouse_stored_milliunits", 0)),
		}
	)


func _stage_ai_progress() -> void:
	var ai := _coordinator.get_node_or_null("AiRuntimeController") if _coordinator != null else null
	var players: Array = _array_property(_main, "players")
	for player_index in [1, 2]:
		var player: Dictionary = players[player_index] if player_index < players.size() else {}
		player["action_cooldown"] = 0.0
		if player_index < players.size():
			players[player_index] = player
	_main.set("players", players)
	var infrastructure := _infrastructure_owner()
	var flow := _commodity_flow_owner()
	var before_facilities: Array = infrastructure.call("facilities_snapshot", false) if infrastructure != null and infrastructure.has_method("facilities_snapshot") else []
	var before_facility_ids := _row_id_set(before_facilities, "facility_id")
	var before_owned_receipt_ids: Dictionary = {}
	var before_ai_cash := 0
	players = _array_property(_main, "players")
	for player_index in [1, 2]:
		before_owned_receipt_ids[player_index] = _owned_sale_receipt_ids(flow, player_index)
		before_ai_cash += _player_cash_cents(players, player_index)
	var bootstrap_results: Array[Dictionary] = []
	for _cycle in range(2):
		var bootstrap_variant: Variant = ai.call("execute_v06_facility_bootstrap_cycle", true) if ai != null and ai.has_method("execute_v06_facility_bootstrap_cycle") else {}
		var bootstrap: Dictionary = bootstrap_variant if bootstrap_variant is Dictionary else {}
		bootstrap_results.append({
			"acted": int(bootstrap.get("acted", 0)),
			"attempted": int(bootstrap.get("attempted", 0)),
			"reason_code": str(bootstrap.get("reason_code", "missing")),
		})
	var after_facilities: Array = infrastructure.call("facilities_snapshot", false) if infrastructure != null and infrastructure.has_method("facilities_snapshot") else []
	var built := 0
	for facility_variant in after_facilities:
		if not (facility_variant is Dictionary):
			continue
		var facility: Dictionary = facility_variant
		if not before_facility_ids.has(str(facility.get("facility_id", ""))) and [1, 2].has(int(facility.get("owner_player_index", -1))):
			built += 1
	for _second in range(120):
		_main.set("game_time", float(_main.get("game_time")) + 1.0)
		_main.call("_advance_continuous_commodity_flow", 1.0)
		if _second % 20 == 0:
			await get_tree().process_frame
	players = _array_property(_main, "players")
	var after_ai_cash := 0
	var ai_receipt_delta := 0
	var ai_trade_kinds: Array[String] = []
	var ai_local_sold_units := 0
	for player_index in [1, 2]:
		after_ai_cash += _player_cash_cents(players, player_index)
		var after_ids := _owned_sale_receipt_ids(flow, player_index)
		var before_ids: Dictionary = before_owned_receipt_ids.get(player_index, {}) if before_owned_receipt_ids.get(player_index, {}) is Dictionary else {}
		for receipt_id_variant in after_ids.keys():
			if before_ids.has(receipt_id_variant):
				continue
			ai_receipt_delta += 1
			var receipt: Dictionary = after_ids.get(receipt_id_variant, {}) as Dictionary
			var trade_kind := str(receipt.get("trade_kind", "")).strip_edges()
			ai_trade_kinds.append(trade_kind)
			if trade_kind.begins_with("local_"):
				ai_local_sold_units += maxi(0, int(receipt.get("units", 0)))
	var ai_income_source_count := _ai_production_installation_count(flow)
	var ai_flow_debug: Dictionary = flow.call("debug_snapshot") if flow != null and flow.has_method("debug_snapshot") else {}
	var ai_flow_metrics: Dictionary = ai_flow_debug.get("last_flow_metrics", {}) if ai_flow_debug.get("last_flow_metrics", {}) is Dictionary else {}
	var queue_idle := _card_queue_idle()
	var passed := built > 0 \
		and ai_income_source_count > 0 \
		and ai_receipt_delta > 0 \
		and after_ai_cash > before_ai_cash \
		and queue_idle
	_record(
		"ai_progress_without_deadlock",
		passed,
		"without requiring a first card play, AI seats must build and finalize a real v0.6 facility, then earn authoritative CommodityFlow income without leaving the queue locked",
		{
			"built": built,
			"ai_income_source_count": ai_income_source_count,
			"ai_sale_receipt_delta": ai_receipt_delta,
			"ai_cash_cents_delta": after_ai_cash - before_ai_cash,
			"ai_trade_kinds": ai_trade_kinds,
			"ai_local_sold_units": ai_local_sold_units,
			"backpressured_milliunits": int(ai_flow_metrics.get("backpressured_milliunits", 0)),
			"warehouse_stored_milliunits": int(ai_flow_metrics.get("warehouse_stored_milliunits", 0)),
			"bootstrap_results": bootstrap_results,
			"queue_idle": queue_idle,
		}
	)


func _stage_victory_countdown() -> void:
	var controller: Object = _coordinator.call("victory_control_runtime_controller") if _coordinator != null and _coordinator.has_method("victory_control_runtime_controller") else null
	if controller == null:
		_record("victory_qualification_audit_outcome", false, "VictoryControlRuntimeController is missing")
		return
	controller.call("reset_state")
	var qualification_seconds := float(controller.call("timer_duration", "victory_qualification"))
	var audit_seconds := float(controller.call("timer_duration", "public_audit"))
	var world := _eligible_victory_world("")
	controller.call("advance_world_effective", qualification_seconds * 0.5, world)
	var qualification: Dictionary = controller.call("public_snapshot") as Dictionary
	controller.call("advance_world_effective", qualification_seconds * 0.5, world)
	var audit_start: Dictionary = controller.call("public_snapshot") as Dictionary
	controller.call("advance_world_effective", maxf(0.0, audit_seconds - 0.01), world)
	var audit_near_end: Dictionary = controller.call("public_snapshot") as Dictionary
	var endpoint_world := _eligible_victory_world("post_world_settlement")
	controller.call("advance_world_effective", 0.01, endpoint_world)
	var resolved: Dictionary = controller.call("public_snapshot") as Dictionary
	_victory_receipt = (controller.call("outcome_receipt") as Dictionary).duplicate(true)
	var passed := qualification_seconds > 0.0 \
		and audit_seconds > 0.0 \
		and str(qualification.get("state", "")) == "qualification" \
		and float(qualification.get("qualification_remaining_seconds", 0.0)) > 0.0 \
		and str(audit_start.get("state", "")) == "audit" \
		and is_equal_approx(float(audit_start.get("audit_remaining_seconds", -1.0)), audit_seconds) \
		and str(audit_near_end.get("state", "")) == "audit" \
		and str(resolved.get("state", "")) == "resolved" \
		and not str(_victory_receipt.get("outcome_id", "")).is_empty() \
		and str(_victory_receipt.get("reason_code", "")) == "public_audit_complete"
	_record(
		"victory_qualification_audit_outcome",
		passed,
		"the production VictoryControl owner must traverse qualification and the configured audit countdown before emitting its versioned outcome receipt",
		{
			"qualification_seconds": qualification_seconds,
			"audit_seconds": audit_seconds,
			"qualification_state": str(qualification.get("state", "missing")),
			"audit_state": str(audit_start.get("state", "missing")),
			"resolved_state": str(resolved.get("state", "missing")),
			"outcome_id": str(_victory_receipt.get("outcome_id", "")),
		}
	)


func _stage_settlement_recap() -> void:
	if not _victory_receipt.is_empty() and _coordinator != null and _coordinator.has_method("_apply_victory_outcome_receipt"):
		_coordinator.call("_apply_victory_outcome_receipt", _victory_receipt)
	await _wait_frames(4)
	var first_board_count := _visible_final_settlement_board_count()
	if not _victory_receipt.is_empty() and _coordinator != null and _coordinator.has_method("_apply_victory_outcome_receipt"):
		_coordinator.call("_apply_victory_outcome_receipt", _victory_receipt)
	await _wait_frames(3)
	var replay_board_count := _visible_final_settlement_board_count()
	var diagnostic_title := "公开审计完成"
	var composition := _final_settlement_composition()
	var public_context := _final_settlement_public_context()
	var public_source: Dictionary = composition.call("compose_public_source", public_context) if composition != null and composition.has_method("compose_public_source") else {}
	_final_settlement_snapshot = {}
	if _coordinator != null and _coordinator.has_method("compose_final_settlement_snapshot"):
		var snapshot_variant: Variant = _coordinator.call("compose_final_settlement_snapshot", public_source)
		_final_settlement_snapshot = (snapshot_variant as Dictionary).duplicate(true) if snapshot_variant is Dictionary else {}
	var presented_snapshot: Dictionary = composition.call("last_public_snapshot") if composition != null and composition.has_method("last_public_snapshot") else {}
	var board: Dictionary = _final_settlement_snapshot.get("board", {}) if _final_settlement_snapshot.get("board", {}) is Dictionary else {}
	var menu_title := _visible_label_text("MenuTitleLabel")
	var session_finished := bool(_main.call("_runtime_session_finished"))
	var passed := session_finished \
		and first_board_count == 1 \
		and replay_board_count == 1 \
		and not board.is_empty() \
		and presented_snapshot == _final_settlement_snapshot \
		and (menu_title == "终局结算" or replay_board_count == 1)
	_record(
		"settlement_recap_visible",
		passed,
		"the authoritative outcome must finish the session and open one visible settlement/recap; replay must not duplicate it",
		{
			"diagnostic_title": diagnostic_title,
			"session_finished": session_finished,
			"first_visible_board_count": first_board_count,
			"replay_visible_board_count": replay_board_count,
			"menu_title": menu_title,
			"board_present": not board.is_empty(),
		}
	)


func _stage_privacy() -> void:
	_privacy_leaks.clear()
	_scan_setup_ai_privacy()
	var players: Array = _array_property(_main, "players")
	var player_backup := players.duplicate(true)
	if players.size() >= 3:
		var ai_player: Dictionary = (players[1] as Dictionary).duplicate(true)
		ai_player["cash"] = 987654321
		ai_player["cash_cents"] = 98765432100
		ai_player["slots"] = [
			{"name": "VS06_PRIVATE_HAND_SENTINEL_A"},
			{"name": "VS06_PRIVATE_HAND_SENTINEL_B"},
			{"name": "VS06_PRIVATE_HAND_SENTINEL_C"},
		]
		ai_player["ai_memory"] = {"route_plan": "VS06_AI_PLAN_SENTINEL"}
		ai_player["hidden_owner"] = "VS06_TRUE_OWNER_SENTINEL"
		players[1] = ai_player
		_main.set("players", players)
	var district := int(_main.get("selected_district"))
	var ai_supply: Dictionary = {}
	if district >= 0 and _main.has_method("_district_supply_snapshot_source"):
		ai_supply = _main.call("_district_supply_snapshot_source", district, 1) as Dictionary
		_scan_public_value(ai_supply, "district_supply.ai_view")
		_main.set("district_supply_open_district", district)
		_main.set("district_supply_open_player", 1)
		var overlay: Variant = _main.get("district_supply_overlay")
		if overlay is CanvasItem:
			(overlay as CanvasItem).visible = true
		_main.call("_refresh_district_supply_overlay")
		await _wait_frames(2)
	var monster := _monster_owner()
	var public_monsters: Variant = monster.call("roster_snapshot", false) if monster != null and monster.has_method("roster_snapshot") else []
	_scan_public_value(public_monsters, "monster.public_roster")
	var victory_public: Variant = _coordinator.call("victory_control_public_snapshot", -1) if _coordinator != null and _coordinator.has_method("victory_control_public_snapshot") else {}
	_scan_victory_public_value(victory_public)
	var unknown_audit_cash_path_rejected := _victory_unknown_audit_cash_path_rejected(victory_public)
	_scan_public_value(_final_settlement_snapshot, "settlement.public")
	_scan_visible_controls(_main, "main.visible")
	_main.set("players", player_backup)
	_record(
		"player_facing_privacy",
		_privacy_leaks.is_empty() and unknown_audit_cash_path_rejected,
		"independent recursive snapshot and rendered-control scans must expose zero rival cash/hand/starter, hidden owner truth, or AI-private plan values",
		{
			"privacy_leak_count": _privacy_leaks.size(),
			"privacy_leaks": _privacy_leaks.duplicate(),
			"ai_supply_snapshot_present": not ai_supply.is_empty(),
			"unknown_audit_cash_path_rejected": unknown_audit_cash_path_rejected,
		}
	)


func _stage_save_isolation() -> void:
	var save := _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	var session := save.get_parent() if save != null else null
	var handshake := save.get_node_or_null("RulesetSaveHandshakeService") if save != null else null
	var envelope := _v3_transport_fixture_envelope(handshake)
	var authorization: Dictionary = save.call("write_authorization", QA_SAVE_PATH, envelope, {"allow_replace": true}) if save != null and save.has_method("write_authorization") and not envelope.is_empty() else {}
	var write_result: Dictionary = session.call("request_save", QA_SAVE_PATH, envelope, authorization) if session != null and session.has_method("request_save") else {}
	var read_result: Dictionary = session.call("read_save", QA_SAVE_PATH) if session != null and session.has_method("read_save") else {}
	var public_receipt: Dictionary = save.call("public_operation_receipt", write_result) if save != null and save.has_method("public_operation_receipt") else {}
	var operation: Dictionary = save.call("operation_snapshot") if save != null and save.has_method("operation_snapshot") else {}
	var default_after := _file_fingerprint(DEFAULT_PLAYER_SAVE_PATH)
	var transport_fingerprint_match := not str(write_result.get("fingerprint", "")).is_empty() and str(write_result.get("fingerprint", "")) == str(read_result.get("fingerprint", ""))
	var passed := _qa_override_ready \
		and bool(operation.get("qa_save_path_override_active", false)) \
		and str(operation.get("default_save_path", "")) == QA_SAVE_PATH \
		and str(operation.get("last_path", "")) == QA_SAVE_PATH \
		and not envelope.is_empty() \
		and bool(authorization.get("allowed", false)) \
		and bool(write_result.get("ok", false)) \
		and bool(read_result.get("ok", false)) \
		and transport_fingerprint_match \
		and _save_public_receipt_is_safe(public_receipt) \
		and _default_save_before == default_after
	_record(
		"qa_save_isolation",
		passed,
		"the narrow v3 envelope transport may write/read only the QA test_runs path; full owner capture/apply/rollback remains outside this transport gate",
		{
			"scope": "v3_envelope_transport_isolation",
			"full_owner_restore_claimed": false,
			"qa_override_active": bool(operation.get("qa_save_path_override_active", false)),
			"default_save_path": str(operation.get("default_save_path", "")),
			"last_path": str(operation.get("last_path", "")),
			"envelope_valid": not envelope.is_empty(),
			"authorization_allowed": bool(authorization.get("allowed", false)),
			"write_ok": bool(write_result.get("ok", false)),
			"read_ok": bool(read_result.get("ok", false)),
			"transport_fingerprint_match": transport_fingerprint_match,
			"public_receipt_safe": _save_public_receipt_is_safe(public_receipt),
			"default_before": _default_save_before,
			"default_after": default_after,
		}
	)


func _v3_transport_fixture_envelope(handshake: Node) -> Dictionary:
	if handshake == null or not handshake.has_method("required_section_manifest") or not handshake.has_method("compose_v06_envelope"):
		return {}
	var manifest_variant: Variant = handshake.call("required_section_manifest")
	var manifest: Dictionary = manifest_variant if manifest_variant is Dictionary else {}
	var session_section: Dictionary = {}
	var domain_sections: Dictionary = {}
	for section_variant in manifest.keys():
		var section_id := str(section_variant)
		var section_contract: Dictionary = manifest.get(section_variant, {}) if manifest.get(section_variant, {}) is Dictionary else {}
		var section_payload := {
			"schema_version": int(section_contract.get("state_version", 0)),
			"revision": 0,
			"transport_fixture": "tomorrow_v06_isolation",
		}
		if section_id == "session":
			session_section = section_payload
		else:
			domain_sections[section_id] = section_payload
	if session_section.is_empty() or domain_sections.size() + 1 != manifest.size():
		return {}
	var contract_suffix := JSON.stringify(manifest).sha256_text().substr(0, 16)
	var envelope_variant: Variant = handshake.call("compose_v06_envelope", session_section, domain_sections, {
		"envelope_id": "tomorrow-v06-transport-envelope-%s" % contract_suffix,
		"write_id": "tomorrow-v06-transport-write-%s" % contract_suffix,
	})
	return (envelope_variant as Dictionary).duplicate(true) if envelope_variant is Dictionary else {}


func _save_public_receipt_is_safe(receipt: Dictionary) -> bool:
	if receipt.is_empty():
		return false
	for forbidden_key in ["sections", "players", "cash", "cash_cents", "cash_ledger_cents", "private_hand", "owner_truth", "ai_plan"]:
		if _dictionary_has_key_recursive(receipt, forbidden_key):
			return false
	return not JSON.stringify(receipt).contains("tomorrow_v06_isolation")


func optional_summon_oracle_self_check() -> Dictionary:
	var valid := {
		"submitted": true,
		"queue_drained": true,
		"before_count": 0,
		"after_count": 1,
		"new_terminal_count": 1,
		"finalized_count": 1,
		"terminal_evidence": [{"transaction_id": "summon.tx.1", "stage": "finalized", "receipt_finalized": true}],
		"inflight_count": 0,
		"checkpoint_open": true,
		"campaign_monster_summoned_signal_observed": false,
	}
	var mutations := [
		{"field": "submitted", "value": false},
		{"field": "queue_drained", "value": false},
		{"field": "after_count", "value": 0},
		{"field": "new_terminal_count", "value": 2},
		{"field": "finalized_count", "value": 0},
		{"field": "terminal_evidence", "value": [{"transaction_id": "summon.tx.1", "stage": "committed", "receipt_finalized": false}]},
		{"field": "inflight_count", "value": 1},
		{"field": "checkpoint_open", "value": false},
	]
	var scenario_signal_false_passed := _optional_summon_evidence_passes(valid)
	var scenario_signal_true := valid.duplicate(true)
	scenario_signal_true["campaign_monster_summoned_signal_observed"] = true
	var scenario_signal_true_passed := _optional_summon_evidence_passes(scenario_signal_true)
	var rejected_mutations := 0
	for mutation_variant in mutations:
		var mutation: Dictionary = mutation_variant
		var candidate := valid.duplicate(true)
		candidate[str(mutation.get("field", ""))] = mutation.get("value")
		if not _optional_summon_evidence_passes(candidate):
			rejected_mutations += 1
	return {
		"passed": scenario_signal_false_passed and scenario_signal_true_passed and rejected_mutations == mutations.size(),
		"checks": mutations.size() + 2,
		"scenario_variants_accepted": int(scenario_signal_false_passed) + int(scenario_signal_true_passed),
		"rejected_mutations": rejected_mutations,
	}


func _optional_summon_evidence_passes(evidence: Dictionary) -> bool:
	var terminals: Array = evidence.get("terminal_evidence", []) if evidence.get("terminal_evidence", []) is Array else []
	if terminals.size() != 1 or not (terminals[0] is Dictionary):
		return false
	var terminal: Dictionary = terminals[0]
	return bool(evidence.get("submitted", false)) \
		and bool(evidence.get("queue_drained", false)) \
		and int(evidence.get("before_count", -1)) >= 0 \
		and int(evidence.get("after_count", -1)) == int(evidence.get("before_count", -1)) + 1 \
		and int(evidence.get("new_terminal_count", -1)) == 1 \
		and int(evidence.get("finalized_count", -1)) == 1 \
		and str(terminal.get("stage", "")) == "finalized" \
		and bool(terminal.get("receipt_finalized", false)) \
		and int(evidence.get("inflight_count", -1)) == 0 \
		and bool(evidence.get("checkpoint_open", false))


func stage4_oracle_self_check() -> Dictionary:
	var valid := {
		"canonical_card_id": "facility.factory.life.rank_1",
		"canonical_facility": true,
		"canonical_purchase_cash": 4,
		"canonical_asset_total": 0,
		"market_ready": true,
		"listing_matches_canonical": true,
		"core_configured": true,
		"purchase_committed": true,
		"purchase_card_matches": true,
		"purchase_price": 4,
		"cash_debit": 4,
		"cash_stable_after_purchase": true,
		"assets_unchanged": true,
		"player_revision_before": 7,
		"player_revision_after_purchase": 8,
		"player_revision_after_play": 9,
		"player_revision_after_replay": 9,
		"market_revision_before": 3,
		"market_revision_after_purchase": 4,
		"market_revision_after_play": 4,
		"market_revision_after_replay": 4,
		"slot_index": 0,
		"region_id": "region.alpha",
		"card_consumed": true,
		"play_handled": true,
		"play_committed": true,
		"play_route_id": "core_economic_card_runtime",
		"play_finalized": true,
		"new_transaction_count": 2,
		"purchase_journal_committed": true,
		"play_transaction_present": true,
		"finalized_play_transaction_count": 1,
		"facility_delta": 1,
		"purchase_did_not_build": true,
		"replay_committed": true,
		"replay_idempotent": true,
		"replay_state_unchanged": true,
	}
	var mutations := [
		{"field": "canonical_purchase_cash", "value": 3},
		{"field": "assets_unchanged", "value": false},
		{"field": "player_revision_after_play", "value": 8},
		{"field": "market_revision_after_purchase", "value": 3},
		{"field": "finalized_play_transaction_count", "value": 2},
		{"field": "facility_delta", "value": 2},
		{"field": "replay_idempotent", "value": false},
		{"field": "replay_state_unchanged", "value": false},
	]
	var valid_passed := _stage4_evidence_passes(valid)
	var rejected_mutations := 0
	for mutation_variant in mutations:
		var mutation: Dictionary = mutation_variant
		var candidate := valid.duplicate(true)
		candidate[str(mutation.get("field", ""))] = mutation.get("value")
		if not _stage4_evidence_passes(candidate):
			rejected_mutations += 1
	return {
		"passed": valid_passed and rejected_mutations == mutations.size(),
		"checks": mutations.size() + 1,
		"valid_fixture_passed": valid_passed,
		"rejected_mutations": rejected_mutations,
	}


func _stage4_evidence_passes(evidence: Dictionary) -> bool:
	return not str(evidence.get("canonical_card_id", "")).is_empty() \
		and bool(evidence.get("canonical_facility", false)) \
		and int(evidence.get("canonical_purchase_cash", -1)) == 4 \
		and int(evidence.get("canonical_asset_total", -1)) == 0 \
		and bool(evidence.get("market_ready", false)) \
		and bool(evidence.get("listing_matches_canonical", false)) \
		and bool(evidence.get("core_configured", false)) \
		and bool(evidence.get("purchase_committed", false)) \
		and bool(evidence.get("purchase_card_matches", false)) \
		and int(evidence.get("purchase_price", -1)) == 4 \
		and int(evidence.get("cash_debit", -1)) == 4 \
		and bool(evidence.get("cash_stable_after_purchase", false)) \
		and bool(evidence.get("assets_unchanged", false)) \
		and int(evidence.get("player_revision_before", -1)) >= 0 \
		and int(evidence.get("player_revision_after_purchase", -1)) == int(evidence.get("player_revision_before", -1)) + 1 \
		and int(evidence.get("player_revision_after_play", -1)) == int(evidence.get("player_revision_after_purchase", -1)) + 1 \
		and int(evidence.get("player_revision_after_replay", -1)) == int(evidence.get("player_revision_after_play", -1)) \
		and int(evidence.get("market_revision_before", -1)) >= 0 \
		and int(evidence.get("market_revision_after_purchase", -1)) == int(evidence.get("market_revision_before", -1)) + 1 \
		and int(evidence.get("market_revision_after_play", -1)) == int(evidence.get("market_revision_after_purchase", -1)) \
		and int(evidence.get("market_revision_after_replay", -1)) == int(evidence.get("market_revision_after_play", -1)) \
		and int(evidence.get("slot_index", -1)) >= 0 \
		and not str(evidence.get("region_id", "")).is_empty() \
		and bool(evidence.get("card_consumed", false)) \
		and bool(evidence.get("play_handled", false)) \
		and bool(evidence.get("play_committed", false)) \
		and str(evidence.get("play_route_id", "")) == "core_economic_card_runtime" \
		and bool(evidence.get("play_finalized", false)) \
		and int(evidence.get("new_transaction_count", -1)) == 2 \
		and bool(evidence.get("purchase_journal_committed", false)) \
		and bool(evidence.get("play_transaction_present", false)) \
		and int(evidence.get("finalized_play_transaction_count", -1)) == 1 \
		and int(evidence.get("facility_delta", -1)) == 1 \
		and bool(evidence.get("purchase_did_not_build", false)) \
		and bool(evidence.get("replay_committed", false)) \
		and bool(evidence.get("replay_idempotent", false)) \
		and bool(evidence.get("replay_state_unchanged", false))


func _find_v06_card_slot(player: Dictionary, card_id: String) -> int:
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var machine: Dictionary = (slots[slot_index] as Dictionary).get("machine", {}) if (slots[slot_index] as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("card_id", "")) == card_id:
			return slot_index
	return -1


func _selected_v06_region_id() -> String:
	if _main == null:
		return ""
	var districts := _array_property(_main, "districts")
	var district_index := int(_main.get("selected_district"))
	if (district_index < 0 or district_index >= districts.size()) and _main.has_method("_first_run_recommended_start_district"):
		district_index = int(_main.call("_first_run_recommended_start_district", 0))
	if district_index < 0 or district_index >= districts.size() or not (districts[district_index] is Dictionary):
		return ""
	return str((districts[district_index] as Dictionary).get("region_id", "")).strip_edges()


func _asset_total(value: Variant) -> int:
	if not (value is Dictionary):
		return -1
	var total := 0
	for amount in (value as Dictionary).values():
		total += int(amount)
	return total


func _same_data(first: Variant, second: Variant) -> bool:
	return JSON.stringify(first) == JSON.stringify(second)


func _eligible_victory_world(checkpoint: String) -> Dictionary:
	var players: Array = []
	var world_players: Array = _array_property(_main, "players")
	for player_index in range(world_players.size()):
		var player: Dictionary = world_players[player_index] as Dictionary
		players.append({
			"player_index": player_index,
			"eliminated": false,
			"cash_ledger_cents": _player_cash_cents(world_players, player_index),
			"audit_assets": {},
		})
	return {
		"schema_version": "v0.6.victory-world.1",
		"players": players,
		"regions": [{
			"region_id": "vs06-c-eligible-region",
			"district_index": 0,
			"lifecycle_state": "active",
			"destroyed": false,
			"region_gdp_per_minute": 72,
			"region_gdp_per_minute_cents": 7200,
			"player_gdp_by_index": {"0": 7200, "1": 0, "2": 0},
		}],
		"clock_pause": {},
		"settlement_checkpoint": checkpoint,
		"ordering_receipt": {},
	}


func _scenario_state() -> Dictionary:
	if _coordinator == null or not _coordinator.has_method("runtime_scenario_state"):
		return {}
	var value: Variant = _coordinator.call("runtime_scenario_state", float(_main.get("game_time")))
	return value as Dictionary if value is Dictionary else {}


func _card_queue_idle() -> bool:
	var active: Variant = _main.get("active_card_resolution")
	var queue: Variant = _main.get("card_resolution_queue")
	var next_queue: Variant = _main.get("next_card_resolution_queue")
	return (not (active is Dictionary) or (active as Dictionary).is_empty()) \
		and (not (queue is Array) or (queue as Array).is_empty()) \
		and (not (next_queue is Array) or (next_queue as Array).is_empty()) \
		and not bool(_main.get("card_resolution_batch_locked"))


func _drain_card_resolution(max_frames: int) -> bool:
	for _frame in range(maxi(1, max_frames)):
		if _card_queue_idle():
			return true
		_main.call("_update_card_resolution_queue", 0.5)
		await get_tree().process_frame
	return _card_queue_idle()


func _capture_ai_setup_secrets() -> void:
	var seats: Array = _setup_snapshot.get("seats", []) if _setup_snapshot.get("seats", []) is Array else []
	for player_index in [1, 2]:
		var configured_index := int(_main.call("_configured_starter_monster_index", player_index))
		var catalog_entry: Dictionary = _main.call("_catalog_entry", configured_index) as Dictionary
		var name := str(catalog_entry.get("name", "")).strip_edges()
		if not name.is_empty():
			_ai_setup_secrets.append(name)
		if player_index >= seats.size():
			_ai_setup_secrets.append("missing_ai_seat_%d" % player_index)


func _scan_setup_ai_privacy() -> void:
	var seats: Array = _setup_snapshot.get("seats", []) if _setup_snapshot.get("seats", []) is Array else []
	for player_index in [1, 2]:
		if player_index >= seats.size():
			_privacy_leaks.append("setup.seats[%d]:missing" % player_index)
			continue
		var encoded := JSON.stringify(seats[player_index])
		for secret in _ai_setup_secrets:
			if not secret.begins_with("missing_") and encoded.contains(secret):
				_privacy_leaks.append("setup.seats[%d]:exact_ai_starter:%s" % [player_index, secret])
		for forbidden_key in ["starter_monster_index", "starter_monster_name", "starter_monster_card", "monster_label"]:
			if _dictionary_has_key_recursive(seats[player_index], forbidden_key):
				_privacy_leaks.append("setup.seats[%d]:forbidden_key:%s" % [player_index, forbidden_key])


func _scan_victory_public_value(value: Variant) -> void:
	var snapshot: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	var authorized_indices := _victory_authorized_audit_indices(snapshot)
	_scan_public_value(_victory_privacy_scan_copy(snapshot, authorized_indices), "victory.public")


func _victory_authorized_audit_indices(snapshot: Dictionary) -> Array[int]:
	var authorized_indices: Array[int] = []
	var raw_indices: Variant = snapshot.get("audit_revealed_player_indices", [])
	var authority_valid := str(snapshot.get("cash_visibility", "")) == "public_audit" and raw_indices is Array
	if authority_valid:
		for player_index_variant in raw_indices as Array:
			if typeof(player_index_variant) != TYPE_INT or int(player_index_variant) < 0 or authorized_indices.has(int(player_index_variant)):
				authority_valid = false
				break
			authorized_indices.append(int(player_index_variant))
	if not authority_valid:
		authorized_indices.clear()
	return authorized_indices


func _victory_unknown_audit_cash_path_rejected(value: Variant) -> bool:
	var snapshot: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	var authorized_indices := _victory_authorized_audit_indices(snapshot)
	if authorized_indices.is_empty():
		return false
	var probe := snapshot.duplicate(true)
	probe["unknown_nested_audit_payload"] = {
		"player_index": authorized_indices[0],
		"cash_visibility": "public_audit",
		"cash_ledger_cents": 606100006061,
	}
	var leak_count_before := _privacy_leaks.size()
	_scan_public_value(_victory_privacy_scan_copy(probe, authorized_indices), "victory.unknown_path_probe")
	var rejected := _privacy_leaks.size() > leak_count_before
	_privacy_leaks.resize(leak_count_before)
	return rejected


func _victory_privacy_scan_copy(snapshot: Dictionary, authorized_indices: Array[int]) -> Dictionary:
	var result := snapshot.duplicate(true)
	if result.get("audit_entries", []) is Array:
		result["audit_entries"] = _victory_rows_without_authorized_audit_cash(result.get("audit_entries", []), authorized_indices)
	if result.get("rank_entries", []) is Array:
		result["rank_entries"] = _victory_rows_without_authorized_audit_cash(result.get("rank_entries", []), authorized_indices)
	var outcome_receipt: Dictionary = result.get("outcome_receipt", {}) if result.get("outcome_receipt", {}) is Dictionary else {}
	if not outcome_receipt.is_empty() and outcome_receipt.get("rankings", []) is Array:
		outcome_receipt["rankings"] = _victory_rows_without_authorized_audit_cash(outcome_receipt.get("rankings", []), authorized_indices)
		result["outcome_receipt"] = outcome_receipt
	return result


func _victory_rows_without_authorized_audit_cash(value: Variant, authorized_indices: Array[int]) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for row_variant in value as Array:
		if not (row_variant is Dictionary):
			result.append(row_variant)
			continue
		var row := (row_variant as Dictionary).duplicate(true)
		if _audit_cash_row_is_authorized(row, authorized_indices):
			row.erase("cash_ledger_cents")
		result.append(row)
	return result


func _audit_cash_row_is_authorized(row: Dictionary, authorized_indices: Array[int]) -> bool:
	return not authorized_indices.is_empty() \
		and str(row.get("cash_visibility", "")) == "public_audit" \
		and typeof(row.get("player_index", null)) == TYPE_INT \
		and authorized_indices.has(int(row.get("player_index", -1))) \
		and typeof(row.get("cash_ledger_cents", null)) == TYPE_INT


func _scan_public_value(value: Variant, path: String) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var lowered := key.to_lower()
			if FORBIDDEN_PUBLIC_KEYS.has(lowered):
				_privacy_leaks.append("%s.%s:forbidden_key" % [path, key])
			_scan_public_value((value as Dictionary).get(key_variant), "%s.%s" % [path, key])
		return
	if value is Array:
		for index in range((value as Array).size()):
			_scan_public_value((value as Array)[index], "%s[%d]" % [path, index])
		return
	var text := str(value)
	for sentinel in PRIVATE_VALUE_SENTINELS:
		if text.contains(sentinel):
			_privacy_leaks.append("%s:private_value:%s" % [path, sentinel])


func _scan_visible_controls(node: Node, path: String) -> void:
	if node is Control and (node as Control).is_visible_in_tree():
		var fragments: Array[String] = []
		if node is Label:
			fragments.append((node as Label).text)
		elif node is RichTextLabel:
			fragments.append((node as RichTextLabel).text)
		elif node is Button:
			fragments.append((node as Button).text)
		elif node is LineEdit:
			fragments.append((node as LineEdit).text)
		fragments.append((node as Control).tooltip_text)
		for fragment in fragments:
			for sentinel in PRIVATE_VALUE_SENTINELS:
				if fragment.contains(sentinel):
					_privacy_leaks.append("%s/%s:visible_private_value:%s" % [path, node.name, sentinel])
	for child in node.get_children():
		_scan_visible_controls(child, "%s/%s" % [path, node.name])


func _dictionary_has_key_recursive(value: Variant, expected_key: String) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant).to_lower() == expected_key.to_lower():
				return true
			if _dictionary_has_key_recursive((value as Dictionary).get(key_variant), expected_key):
				return true
	elif value is Array:
		for item in value:
			if _dictionary_has_key_recursive(item, expected_key):
				return true
	return false


func _contains_action_id(value: Variant, action_id: String) -> bool:
	if value is Dictionary:
		if str((value as Dictionary).get("id", "")) == action_id:
			return true
		for child in (value as Dictionary).values():
			if _contains_action_id(child, action_id):
				return true
	elif value is Array:
		for child in value:
			if _contains_action_id(child, action_id):
				return true
	return false


func _new_dictionary_keys(before: Dictionary, after: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key_variant in after.keys():
		var key := str(key_variant)
		if not before.has(key_variant) and not before.has(key):
			result.append(key)
	result.sort()
	return result


func _actor_id(players: Array, player_index: int) -> String:
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return ""
	var configured := str((players[player_index] as Dictionary).get("actor_id", "")).strip_edges()
	return configured if not configured.is_empty() else "player.%d" % player_index


func _player_cash_cents(players: Array, player_index: int) -> int:
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return 0
	var player: Dictionary = players[player_index]
	return int(player.get("cash_cents", int(player.get("cash", 0)) * 100))


func _row_id_set(rows: Array, field_name: String) -> Dictionary:
	var result: Dictionary = {}
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row_id := str((row_variant as Dictionary).get(field_name, "")).strip_edges()
		if not row_id.is_empty():
			result[row_id] = true
	return result


func _owned_sale_receipt_ids(flow: Object, player_index: int) -> Dictionary:
	var result: Dictionary = {}
	if flow == null or not flow.has_method("recent_sale_receipts_snapshot"):
		return result
	var receipts_variant: Variant = flow.call("recent_sale_receipts_snapshot", player_index)
	var receipts: Array = receipts_variant if receipts_variant is Array else []
	for receipt_variant in receipts:
		if not (receipt_variant is Dictionary):
			continue
		var receipt: Dictionary = receipt_variant
		if int(receipt.get("commodity_owner", -1)) != player_index:
			continue
		var receipt_id := str(receipt.get("receipt_id", "")).strip_edges()
		if not receipt_id.is_empty():
			result[receipt_id] = receipt.duplicate(true)
	return result


func _ai_production_installation_count(flow: Object) -> int:
	if flow == null or not flow.has_method("installations_snapshot"):
		return 0
	var count := 0
	for installation_variant in flow.call("installations_snapshot", false):
		if not (installation_variant is Dictionary):
			continue
		var installation: Dictionary = installation_variant
		if bool(installation.get("active", false)) \
				and str(installation.get("direction", "")) == "production" \
				and str(installation.get("owner_kind", "")) == "player" \
				and [1, 2].has(int(installation.get("installer_player_index", -1))):
			count += 1
	return count


func _array_property(node: Object, property_name: String) -> Array:
	var value: Variant = node.get(property_name)
	return value as Array if value is Array else []


func _monster_owner() -> Node:
	return _coordinator.call("monster_runtime_controller") if _coordinator != null and _coordinator.has_method("monster_runtime_controller") else null


func _infrastructure_owner() -> Node:
	return _coordinator.call("region_infrastructure_runtime_controller") if _coordinator != null and _coordinator.has_method("region_infrastructure_runtime_controller") else null


func _commodity_flow_owner() -> Node:
	return _coordinator.call("commodity_flow_runtime_controller") if _coordinator != null and _coordinator.has_method("commodity_flow_runtime_controller") else null


func _commodity_inventory_owner() -> Node:
	return _coordinator.call("commodity_card_inventory_runtime_controller") if _coordinator != null and _coordinator.has_method("commodity_card_inventory_runtime_controller") else null


func _core_economic_owner() -> Node:
	return _coordinator.call("core_economic_card_runtime_adapter_v06") if _coordinator != null and _coordinator.has_method("core_economic_card_runtime_adapter_v06") else null


func _visible_named_node_count(names: Array[String]) -> int:
	var count := 0
	for node_name in names:
		for node_variant in _main.find_children(node_name, "", true, false):
			if node_variant is CanvasItem and (node_variant as CanvasItem).is_visible_in_tree():
				count += 1
	return count


func _visible_final_settlement_board_count() -> int:
	var count := 0
	for node_variant in _main.find_children("*", "", true, false):
		if not (node_variant is Control):
			continue
		var control := node_variant as Control
		var scene_path := str(control.scene_file_path)
		var identity_matches := str(control.name) == "FinalSettlementBoardPanel" \
			or scene_path == "res://scenes/ui/FinalSettlementBoard.tscn"
		if identity_matches and control.has_method("set_board") and control.is_visible_in_tree() \
				and control.size.x > 0.0 and control.size.y > 0.0:
			count += 1
	return count


func _final_settlement_composition() -> Node:
	return _main.get_node_or_null("RuntimeServices/FinalSettlementRuntimeComposition") if _main != null else null


func _final_settlement_public_context() -> Dictionary:
	var victory_public: Dictionary = _coordinator.call("victory_control_public_snapshot", -1) if _coordinator != null and _coordinator.has_method("victory_control_public_snapshot") else {}
	var participant_names: Dictionary = {}
	var players := _array_property(_main, "players")
	for player_index in range(players.size()):
		participant_names[str(player_index)] = str(_main.call("_player_name", player_index))
	return {
		"victory_public_snapshot": victory_public,
		"participant_names": participant_names,
	}


func _visible_label_text(node_name: String) -> String:
	var node := _main.find_child(node_name, true, false)
	return (node as Label).text if node is Label and (node as Label).is_visible_in_tree() else ""


func _file_fingerprint(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "missing"
	return FileAccess.get_sha256(path)


func _wait_frames(count: int) -> void:
	for _frame in range(maxi(1, count)):
		await get_tree().process_frame


func _release_main() -> void:
	if _main == null or not is_instance_valid(_main):
		return
	for audio_variant in _main.find_children("*", "AudioStreamPlayer", true, false):
		if audio_variant is AudioStreamPlayer:
			(audio_variant as AudioStreamPlayer).stop()
			(audio_variant as AudioStreamPlayer).stream = null
	_main.queue_free()
	_main = null


func _record(step_id: String, passed: bool, detail: String, evidence: Dictionary = {}) -> void:
	var row := {
		"step_id": step_id,
		"passed": passed,
		"detail": detail,
		"evidence": evidence.duplicate(true),
	}
	_records.append(row)
	print("TOMORROW_VERTICAL_SLICE_CASE|step=%s|passed=%s" % [step_id, str(passed).to_lower()])
	if not passed:
		print("TOMORROW_VERTICAL_SLICE_DIAGNOSTIC|step=%s|evidence=%s" % [step_id, JSON.stringify(evidence)])
		_failures.append("%s: %s" % [step_id, detail])


func _record_remaining_as_blocked(reason: String) -> void:
	var present: Dictionary = {}
	for record in _records:
		present[str(record.get("step_id", ""))] = true
	for step_id in EXPECTED_RECORD_IDS:
		if not present.has(step_id):
			_record(step_id, false, "blocked by %s" % reason, {"blocker": reason})


func _finish_manifest() -> Dictionary:
	var actual_ids: Array[String] = []
	for record in _records:
		actual_ids.append(str(record.get("step_id", "")))
	var complete := actual_ids == EXPECTED_RECORD_IDS
	if not complete:
		_failures.append("acceptance_record_set_incomplete")
	var manifest := {
		"suite": SUITE_ID,
		"seed": FIXED_SEED,
		"qa_save_path": QA_SAVE_PATH,
		"default_player_save_path": DEFAULT_PLAYER_SAVE_PATH,
		"checks": _records.size(),
		"failure_count": _failures.size(),
		"privacy_leak_count": _privacy_leaks.size(),
		"passed": complete and _failures.is_empty() and _privacy_leaks.is_empty(),
		"records": _records.duplicate(true),
		"failures": _failures.duplicate(),
	}
	_render_manifest(manifest)
	if write_evidence:
		_write_manifest(manifest)
	return manifest


func _render_manifest(manifest: Dictionary) -> void:
	status_label.text = "PASS" if bool(manifest.get("passed", false)) else "FAIL"
	result_label.text = JSON.stringify(manifest, "  ")


func _write_manifest(manifest: Dictionary) -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(manifest, "  "))
