extends Control
class_name DistrictPurchaseRuntimeCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/district_purchase_runtime_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/district_purchase_settlement_runtime_cutover_sprint_29.png"
const OWNERSHIP_CASE_COUNT := 45
const CHARACTERIZATION_CASE_COUNT := 17
const SETTLEMENT_CUTOVER_CASE_COUNT := 18
const SETTLEMENT_SERVICE_SCENE_PATH := "res://scenes/runtime/DistrictPurchaseSettlementRuntimeService.tscn"
const SETTLEMENT_SERVICE_SCRIPT_PATH := "res://scripts/runtime/district_purchase_settlement_runtime_service.gd"
const CARD_INVENTORY_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_inventory_runtime_service.gd"
const SNAPSHOT_SERVICE_SCENE_PATH := "res://scenes/runtime/DistrictSupplySnapshotService.tscn"
const SNAPSHOT_SERVICE_SCRIPT_PATH := "res://scripts/runtime/district_supply_snapshot_service.gd"
const DRAWER_SCENE_PATH := "res://scenes/ui/DistrictSupplyDrawer.tscn"
const DRAWER_SCRIPT_PATH := "res://scripts/ui/district_supply_drawer.gd"
const MARKET_CARD_SCENE_PATH := "res://scenes/ui/DistrictSupplyMarketCard.tscn"
const PREVIEW_CARD_SCENE_PATH := "res://scenes/ui/DistrictSupplyPreviewCard.tscn"
const STATUS_CHIP_SCENE_PATH := "res://scenes/ui/DistrictSupplyStatusChip.tscn"

@export var auto_run := true

@onready var ruleset_bridge: Node = %RulesetRuntimeBridge
@onready var coordinator: Node = %GameRuntimeCoordinator
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var drawer_preview: Control = %DistrictSupplyDrawerPreview

var _records: Array = []
var _failures: Array[String] = []
var _real_main: Control = null
var _drawer_actions: Array = []


func _ready() -> void:
	print("DistrictPurchaseRuntimeCutoverBench ready: auto_run=%s editor_hint=%s" % [auto_run, Engine.is_editor_hint()])
	_configure_runtime()
	if drawer_preview != null and drawer_preview.has_signal("supply_action_requested"):
		var drawer_action_callable := Callable(self, "_on_drawer_action_requested")
		if not drawer_preview.is_connected("supply_action_requested", drawer_action_callable):
			drawer_preview.connect("supply_action_requested", drawer_action_callable)
	_reset_drawer_fixture()
	if auto_run and not Engine.is_editor_hint():
		print("DistrictPurchaseRuntimeCutoverBench scheduling suite")
		call_deferred("run_cutover_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func ownership_cases() -> Array:
	return [
		"controller_scene_composition",
		"purchase_window_uses_ruleset_12_seconds",
		"view_only_district_has_no_timer",
		"eligible_window_opens",
		"countdown_and_exact_expiry",
		"close_and_switch_invalidate",
		"one_window_per_player",
		"monster_move_does_not_change_locked_access",
		"monster_binding_change_does_not_change_locked_discount",
		"landed_and_adjacent_price_context",
		"bound_monster_064_and_080_context",
		"discounts_do_not_stack",
		"final_price_floor",
		"supply_change_keeps_window_and_requires_reselection",
		"pending_discard_preserves_context",
		"expired_window_rejects_purchase",
		"real_main_player_purchase_delegates",
		"real_main_ai_purchase_delegates",
		"legacy_save_snapshot_restores",
		"privacy_and_pure_data",
		"main_legacy_window_authority_inactive",
		"drawer_scene_composition",
		"pure_drawer_snapshot",
		"market_cards_render_from_snapshot",
		"selected_preview_rendering",
		"hover_and_click_preview_routes",
		"purchase_activation_routes",
		"disabled_preview_buy_guard",
		"purchase_window_status_passthrough",
		"empty_supply_safe_state",
		"keyboard_focus_chain",
		"real_main_drawer_route",
		"legacy_drawer_builders_and_node_refs_absent",
		"snapshot_service_scene_composition",
		"pure_snapshot_source_contract",
		"source_rejects_runtime_objects",
		"header_chip_format_parity",
		"market_summary_format_parity",
		"market_card_format_parity",
		"selected_preview_format_parity",
		"purchase_window_service_passthrough",
		"viewer_private_boundary",
		"real_main_snapshot_service_route",
		"snapshot_service_has_no_rule_authority",
		"legacy_snapshot_formatter_closure_absent",
	]


func settlement_characterization_cases() -> Array:
	return [
		"settlement_new_card_commit",
		"settlement_same_family_upgrade_commit",
		"settlement_max_rank_rejected_without_mutation",
		"settlement_exact_cash_debit_and_ledger",
		"settlement_insufficient_cash_without_mutation",
		"settlement_supply_remains_after_purchase",
		"settlement_hand_limit_opens_pending_discard_without_charge",
		"settlement_hand_limit_exempt_card_bypasses_discard",
		"settlement_discard_cancel_restores_window",
		"settlement_discard_confirm_commits_once",
		"settlement_invalid_discard_slot_without_mutation",
		"settlement_locked_or_queued_card_not_discardable",
		"settlement_pending_discard_state_drift_audit",
		"settlement_ai_uses_same_authorized_path",
		"settlement_public_private_event_boundary",
		"settlement_post_commit_hooks_exactly_once",
		"legacy_upgrade_replace_routes_classified",
	]


func settlement_service_cutover_cases() -> Array:
	return [
		"settlement_service_scene_composition",
		"coordinator_composes_settlement_service",
		"pure_settlement_request_contract",
		"service_new_card_plan_and_commit",
		"service_duplicate_upgrade_plan_and_commit",
		"service_rank_iv_rejection",
		"service_hand_limit_requires_discard_without_commit",
		"service_discard_confirm_atomic_commit",
		"service_discard_cancel_no_commit",
		"service_cash_drift_rejected_without_mutation",
		"service_invalid_discard_rejected_without_mutation",
		"service_exact_once_counter_ledger_and_event_intents",
		"real_main_player_route_delegates_to_service",
		"real_main_ai_route_delegates_to_service",
		"real_main_resumed_discard_route_delegates_to_service",
		"window_and_legacy_save_ownership_unchanged",
		"legacy_main_settlement_mutations_absent",
		"service_debug_snapshot_privacy_and_pure_data",
	]


func cutover_cases() -> Array:
	var cases := ownership_cases()
	cases.append_array(settlement_characterization_cases())
	cases.append_array(settlement_service_cutover_cases())
	return cases


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite": "district-purchase-runtime-cutover-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"ownership_case_count": OWNERSHIP_CASE_COUNT,
		"characterization_case_count": CHARACTERIZATION_CASE_COUNT,
		"characterization_observed_count": 0,
		"characterization_aligned_count": 0,
		"settlement_cutover_case_count": SETTLEMENT_CUTOVER_CASE_COUNT,
		"settlement_cutover_passed_count": 0,
		"record_count": records.size(),
		"records": records,
	}


func run_cutover_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	_configure_runtime()
	_reset_drawer_fixture()
	_real_main = await _prepare_real_main()
	for case_id_variant in cutover_cases():
		var case_id := str(case_id_variant)
		var record: Dictionary = await _run_case(case_id)
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "failed"))])
	_release_real_main()
	await get_tree().process_frame
	await get_tree().process_frame
	var manifest := {
		"suite": "district-purchase-runtime-cutover-v04",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"ownership_case_count": OWNERSHIP_CASE_COUNT,
		"ownership_passed_count": _ownership_passed_count(),
		"characterization_case_count": CHARACTERIZATION_CASE_COUNT,
		"characterization_observed_count": _characterization_observed_count(),
		"characterization_aligned_count": _characterization_aligned_count(),
		"characterization_mismatch_count": CHARACTERIZATION_CASE_COUNT - _characterization_aligned_count(),
		"settlement_cutover_case_count": SETTLEMENT_CUTOVER_CASE_COUNT,
		"settlement_cutover_passed_count": _settlement_cutover_passed_count(),
		"record_count": _records.size(),
		"passed_count": _passed_count(),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("DistrictPurchaseRuntimeCutoverBench manifest: %s" % MANIFEST_PATH)
	print("DistrictPurchaseRuntimeCutoverBench report: %s" % REPORT_PATH)
	print("DistrictPurchaseRuntimeCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("DistrictPurchaseRuntimeCutoverBench ownership: %d/%d" % [_ownership_passed_count(), OWNERSHIP_CASE_COUNT])
	print("DistrictPurchaseRuntimeCutoverBench characterization: %d/%d observed, %d/%d aligned" % [_characterization_observed_count(), CHARACTERIZATION_CASE_COUNT, _characterization_aligned_count(), CHARACTERIZATION_CASE_COUNT])
	print("DistrictPurchaseRuntimeCutoverBench settlement service cutover: %d/%d" % [_settlement_cutover_passed_count(), SETTLEMENT_CUTOVER_CASE_COUNT])
	print("DistrictPurchaseRuntimeCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("DistrictPurchaseRuntimeCutoverBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func _run_case(case_id: String) -> Dictionary:
	if settlement_characterization_cases().has(case_id):
		var characterization := await _run_settlement_characterization_case(case_id)
		return _record(case_id, bool(characterization.get("observed", false)), str(characterization.get("notes", "characterization incomplete")), characterization)
	if settlement_service_cutover_cases().has(case_id):
		var cutover := await _run_settlement_service_cutover_case(case_id)
		return _record(case_id, bool(cutover.get("passed", false)), str(cutover.get("notes", "settlement service cutover incomplete")), cutover)
	var controller := _controller_node()
	var passed := false
	var notes := ""
	var flags := {}
	match case_id:
		"controller_scene_composition":
			passed = controller != null and controller.scene_file_path == "res://scenes/runtime/DistrictPurchaseRuntimeController.tscn"
			notes = "scene-owned controller is composed by GameRuntimeCoordinator"
		"purchase_window_uses_ruleset_12_seconds":
			_reset_controller()
			var debug: Dictionary = controller.call("debug_snapshot")
			passed = is_equal_approx(float(debug.get("purchase_window_seconds", 0.0)), 12.0)
			flags["timing_checked"] = true
			notes = "duration comes from the v0.4 Ruleset profile"
		"view_only_district_has_no_timer":
			_reset_controller()
			var snapshot: Dictionary = controller.call("open_window", 0, 3, _qualification("none", false))
			passed = str(snapshot.get("state", "")) == "view_only" and not bool(snapshot.get("active", true)) and is_zero_approx(float(snapshot.get("remaining_seconds", -1.0)))
			flags["view_only_checked"] = true
			notes = "unqualified racks remain readable without a purchase timer"
		"eligible_window_opens":
			_reset_controller()
			var snapshot: Dictionary = controller.call("open_window", 0, 3, _qualification("landed", true))
			passed = str(snapshot.get("state", "")) == "active" and is_equal_approx(float(snapshot.get("remaining_seconds", 0.0)), 12.0)
			flags["timing_checked"] = true
			notes = "eligible access opens one authoritative 12-second window"
		"countdown_and_exact_expiry":
			_reset_controller()
			controller.call("open_window", 0, 3, _qualification("adjacent", true))
			var session := coordinator.get_node_or_null("GameSessionRuntimeController")
			if session != null:
				session.set("_session_state", "paused")
			coordinator.call("tick_district_purchase_windows", 2.0, [])
			var paused_remaining := float(controller.call("remaining_seconds", 0))
			if session != null:
				session.set("_session_state", "running")
			coordinator.call("tick_district_purchase_windows", 11.5, [])
			var before := float(controller.call("remaining_seconds", 0))
			var events: Array = coordinator.call("tick_district_purchase_windows", 0.5, [])
			var after: Dictionary = controller.call("private_ui_snapshot", 0)
			passed = is_equal_approx(paused_remaining, 12.0) and is_equal_approx(before, 0.5) and str(after.get("state", "")) == "expired" and events.size() == 1
			flags["expiry_checked"] = true
			notes = "session pause preserves the timer, then the window expires at exactly 12 active seconds"
		"close_and_switch_invalidate":
			_reset_controller()
			controller.call("open_window", 0, 1, _qualification("landed", true))
			controller.call("open_window", 0, 2, _qualification("adjacent", true))
			var switched := not bool(controller.call("is_window_active", 0, 1)) and bool(controller.call("is_window_active", 0, 2))
			controller.call("close_window", 0, "drawer_closed")
			passed = switched and not bool(controller.call("is_window_active", 0, 2))
			flags["invalidation_checked"] = true
			notes = "switch replaces the same player's window and close invalidates it"
		"one_window_per_player":
			_reset_controller()
			controller.call("open_window", 0, 1, _qualification("landed", true))
			controller.call("open_window", 1, 2, _qualification("adjacent", true))
			controller.call("open_window", 0, 4, _qualification("extended", true))
			passed = bool(controller.call("is_window_active", 0, 4)) and not bool(controller.call("is_window_active", 0, 1)) and bool(controller.call("is_window_active", 1, 2))
			notes = "each player owns at most one independent window"
		"monster_move_does_not_change_locked_access":
			_reset_controller()
			var qualification := _qualification("landed", true)
			controller.call("open_window", 0, 2, qualification)
			qualification["access_kind"] = "none"
			passed = str(controller.call("locked_access_kind", 0, 2)) == "landed"
			flags["lock_checked"] = true
			notes = "later world movement cannot mutate the locked access kind"
		"monster_binding_change_does_not_change_locked_discount":
			_reset_controller()
			var qualification := _qualification("landed", true, true)
			controller.call("open_window", 0, 2, qualification)
			qualification["source_bound_to_player"] = false
			var context: Dictionary = controller.call("locked_price_context", 0, 2)
			passed = is_equal_approx(float(context.get("locked_price_multiplier", 0.0)), 0.64)
			flags["lock_checked"] = true
			notes = "binding and private channel discount remain locked"
		"landed_and_adjacent_price_context":
			_reset_controller()
			controller.call("open_window", 0, 1, _qualification("landed", true))
			var landed: Dictionary = controller.call("locked_price_context", 0, 1)
			controller.call("open_window", 0, 2, _qualification("adjacent", true))
			var adjacent: Dictionary = controller.call("locked_price_context", 0, 2)
			passed = is_equal_approx(float(landed.get("locked_price_multiplier", 0.0)), 0.8) and is_equal_approx(float(adjacent.get("locked_price_multiplier", 0.0)), 1.0)
			flags["price_checked"] = true
			notes = "ordinary landed and adjacent access preserve 0.8 and 1.0"
		"bound_monster_064_and_080_context":
			_reset_controller()
			controller.call("open_window", 0, 1, _qualification("landed", true, true))
			var landed: Dictionary = controller.call("locked_price_context", 0, 1)
			controller.call("open_window", 0, 2, _qualification("adjacent", true, true))
			var adjacent: Dictionary = controller.call("locked_price_context", 0, 2)
			passed = is_equal_approx(float(landed.get("locked_price_multiplier", 0.0)), 0.64) and is_equal_approx(float(adjacent.get("locked_price_multiplier", 0.0)), 0.8)
			flags["price_checked"] = true
			notes = "bound-monster channel discount produces the v0.4 private prices"
		"discounts_do_not_stack":
			_reset_controller()
			var qualification := _qualification("landed", true, true)
			qualification["source_count"] = 4
			qualification["channel_discount_multiplier"] = 0.8
			controller.call("open_window", 0, 1, qualification)
			var context: Dictionary = controller.call("locked_price_context", 0, 1)
			passed = is_equal_approx(float(context.get("channel_discount_multiplier", 0.0)), 0.8) and is_equal_approx(float(context.get("locked_price_multiplier", 0.0)), 0.64)
			flags["price_checked"] = true
			notes = "one deterministic monster source supplies one non-stacking discount"
		"final_price_floor":
			_reset_controller()
			var qualification := _qualification("landed", true, true)
			qualification["additional_multiplier"] = 0.25
			controller.call("open_window", 0, 1, qualification)
			var context: Dictionary = controller.call("locked_price_context", 0, 1)
			passed = is_equal_approx(float(context.get("locked_price_multiplier", 0.0)), 0.5)
			flags["price_checked"] = true
			notes = "combined discounts respect the v0.4 50 percent floor"
		"supply_change_keeps_window_and_requires_reselection":
			_reset_controller()
			controller.call("open_window", 0, 1, _qualification("landed", true))
			controller.call("acknowledge_card_selection", 0, 1, "card_a", "supply-a")
			var changed: Dictionary = controller.call("mark_supply_revision", 0, 1, "supply-b")
			var denied: Dictionary = controller.call("authorize_purchase", {"player_index": 0, "district_index": 1, "card_id": "card_a", "supply_revision": "supply-b"})
			passed = bool(controller.call("is_window_active", 0, 1)) and bool(changed.get("requires_reselection", false)) and str(denied.get("reason", "")) == "reselection_required"
			flags["supply_checked"] = true
			notes = "rack changes do not reserve inventory or close the window"
		"pending_discard_preserves_context":
			_reset_controller()
			controller.call("open_window", 0, 1, _qualification("landed", true, true))
			controller.call("reserve_pending_discard", {"player_index": 0, "district_index": 1, "card_id": "card_a"})
			controller.call("tick_window", 30.0, {})
			var pending: Dictionary = controller.call("private_ui_snapshot", 0)
			var authorization: Dictionary = controller.call("authorize_purchase", {"player_index": 0, "district_index": 1, "card_id": "card_a", "resume_pending_discard": true})
			passed = str(pending.get("state", "")) == "pending_discard" and is_equal_approx(float(pending.get("remaining_seconds", 0.0)), 12.0) and bool(authorization.get("authorized", false))
			flags["discard_checked"] = true
			notes = "private discard preserves the accepted purchase context without inventory reservation"
		"expired_window_rejects_purchase":
			_reset_controller()
			controller.call("open_window", 0, 1, _qualification("landed", true))
			controller.call("tick_window", 12.0, {})
			var result: Dictionary = controller.call("authorize_purchase", {"player_index": 0, "district_index": 1, "card_id": "card_a"})
			passed = not bool(result.get("authorized", true)) and str(result.get("reason", "")) == "window_expired"
			flags["expiry_checked"] = true
			notes = "expired qualification cannot authorize settlement"
		"real_main_player_purchase_delegates":
			var result := _exercise_real_main_purchase(0, false)
			passed = bool(result.get("bought", false)) and bool(result.get("controller_active", false))
			flags["main_delegation_checked"] = true
			notes = "real player purchase is authorized by the scene-owned controller%s" % ["" if passed else ": %s" % JSON.stringify(result)]
		"real_main_ai_purchase_delegates":
			var result := _exercise_real_main_purchase(1, true)
			passed = bool(result.get("bought", false)) and bool(result.get("controller_active", false))
			flags["main_delegation_checked"] = true
			notes = "real AI purchase opens and uses the same authority without a bypass%s" % ["" if passed else ": %s" % JSON.stringify(result)]
		"legacy_save_snapshot_restores":
			_reset_controller()
			var restored: Dictionary = controller.call("apply_legacy_save_snapshot", {"player_index": 0, "district_index": 2, "access_kind": "landed", "opened_at": 20.0, "extended_multiplier": 1.10, "global_multiplier": 1.35}, 25.0)
			var legacy: Dictionary = controller.call("to_legacy_save_snapshot", 0)
			passed = str(restored.get("state", "")) == "active" and is_equal_approx(float(restored.get("remaining_seconds", 0.0)), 7.0) and int(legacy.get("district_index", -1)) == 2
			flags["save_compatibility_checked"] = true
			notes = "old v1 opened_at snapshots restore without a version change"
		"privacy_and_pure_data":
			_reset_controller()
			var qualification := _qualification("landed", true, true)
			qualification["source_monster_uid"] = 9988
			qualification["owner_player_index"] = 0
			controller.call("open_window", 0, 1, qualification)
			var debug: Dictionary = controller.call("debug_snapshot")
			var encoded := JSON.stringify(debug)
			passed = _is_data_only(debug) and not encoded.contains("source_monster_uid") and not encoded.contains("owner_player_index") and not encoded.contains("9988")
			flags["privacy_checked"] = true
			flags["pure_data_checked"] = true
			notes = "debug output exposes discount state but no monster source or owner identity"
		"main_legacy_window_authority_inactive":
			var main_script := _real_main.get_script() as Script if _real_main != null else null
			var source := FileAccess.get_file_as_string(main_script.resource_path) if main_script != null else ""
			passed = not source.contains("var district_card_purchase_snapshot") and not source.contains("district_card_purchase_snapshot =") and source.contains("authorize_district_purchase") and source.contains("_district_purchase_qualification_compatibility_adapter")
			flags["main_delegation_checked"] = true
			notes = "main retains a pure qualification adapter but no purchase-window state authority"
		"drawer_scene_composition":
			_reset_drawer_fixture()
			var required_nodes := ["DistrictSupplyTitleLabel", "DistrictSupplyRuleStrip", "DistrictPurchaseWindowStatus", "DistrictSupplyShelfChipRail", "DistrictSupplyMarketStatusRail", "DistrictSupplyPrivacyHint", "DistrictSupplyMarketGrid", "DistrictSupplyMarketEmptyState", "DistrictSupplyPreviewBox", "DistrictSupplyPreviewEmptyState"]
			passed = drawer_preview != null and drawer_preview.scene_file_path == DRAWER_SCENE_PATH and drawer_preview.has_method("set_supply") and drawer_preview.has_method("clear_supply") and drawer_preview.has_method("debug_snapshot") and drawer_preview.has_signal("supply_action_requested") and _has_nodes(drawer_preview, required_nodes) and ResourceLoader.exists(STATUS_CHIP_SCENE_PATH)
			flags["drawer_checked"] = true
			notes = "DistrictSupplyDrawer owns the editable shelf, market, preview, status and empty-state hierarchy"
		"pure_drawer_snapshot":
			_reset_drawer_fixture()
			var debug: Dictionary = drawer_preview.call("debug_snapshot") if drawer_preview != null else {}
			var encoded := JSON.stringify(debug)
			passed = _is_data_only(_drawer_fixture()) and _is_data_only(debug) and not _contains_private_tokens(encoded)
			flags["drawer_checked"] = true
			flags["pure_data_checked"] = true
			flags["privacy_checked"] = true
			flags["snapshot_checked"] = true
			notes = "drawer input and debug output remain pure data without private ownership fields"
		"market_cards_render_from_snapshot":
			_reset_drawer_fixture()
			var cards := _drawer_market_cards()
			var names := []
			for card in cards:
				names.append(str(card.call("get_card_name")))
			passed = cards.size() == 2 and names == ["轨道融资1", "城市融资1"]
			flags["drawer_checked"] = true
			flags["snapshot_checked"] = true
			notes = "two real DistrictSupplyMarketCard scenes render in snapshot order"
		"selected_preview_rendering":
			_reset_drawer_fixture()
			var preview := drawer_preview.find_child("DistrictSupplySelectedPreview", true, false) as Control if drawer_preview != null else null
			var title := drawer_preview.find_child("DistrictSupplyPreviewTitle", true, false) as Label if drawer_preview != null else null
			var buy_button := drawer_preview.find_child("DistrictSupplyPreviewBuyButton", true, false) as Button if drawer_preview != null else null
			passed = preview != null and title != null and title.text.contains("轨道融资") and buy_button != null and not buy_button.disabled
			flags["drawer_checked"] = true
			flags["snapshot_checked"] = true
			notes = "selected card preview reuses DistrictSupplyPreviewCard and its real buy button"
		"hover_and_click_preview_routes":
			_reset_drawer_fixture()
			_drawer_actions.clear()
			var cards := _drawer_market_cards()
			if not cards.is_empty():
				cards[0].emit_signal("card_hovered", "轨道融资1")
				cards[0].emit_signal("card_preview_requested", "轨道融资1")
			passed = _drawer_actions.size() == 2 and _drawer_action_matches(0, "district_supply_preview_card", "轨道融资1", "hover") and _drawer_action_matches(1, "district_supply_preview_card", "轨道融资1", "click_or_keyboard")
			flags["drawer_checked"] = true
			flags["action_route_checked"] = true
			notes = "hover and click/keyboard preview signals are aggregated as pure action intents"
		"purchase_activation_routes":
			_reset_drawer_fixture()
			_drawer_actions.clear()
			var cards := _drawer_market_cards()
			var preview := drawer_preview.find_child("DistrictSupplySelectedPreview", true, false) as Control if drawer_preview != null else null
			if not cards.is_empty():
				cards[0].emit_signal("card_activated", "轨道融资1")
			if preview != null:
				preview.emit_signal("buy_requested", "轨道融资1")
			passed = _drawer_actions.size() == 2 and _drawer_action_matches(0, "district_supply_purchase_card", "轨道融资1", "market_activation") and _drawer_action_matches(1, "district_supply_purchase_card", "轨道融资1", "preview_button")
			flags["drawer_checked"] = true
			flags["action_route_checked"] = true
			notes = "market activation and preview Buy emit the same purchase intent with distinct sources"
		"disabled_preview_buy_guard":
			var fixture := _drawer_fixture()
			(fixture["preview"] as Dictionary)["buy_enabled"] = false
			drawer_preview.call("set_supply", fixture)
			_drawer_actions.clear()
			var buy_button := drawer_preview.find_child("DistrictSupplyPreviewBuyButton", true, false) as Button if drawer_preview != null else null
			await _activate_focused_button(buy_button)
			passed = buy_button != null and buy_button.disabled and _drawer_actions.is_empty()
			flags["drawer_checked"] = true
			flags["disabled_checked"] = true
			notes = "a disabled preview Buy button cannot emit a purchase action through real UI input"
		"purchase_window_status_passthrough":
			_reset_drawer_fixture()
			var status := drawer_preview.find_child("DistrictPurchaseWindowStatus", true, false) if drawer_preview != null else null
			var debug: Dictionary = status.call("debug_snapshot") if status != null and status.has_method("debug_snapshot") else {}
			passed = str(debug.get("state", "")) == "active" and is_equal_approx(float(debug.get("remaining_seconds", 0.0)), 9.5) and is_equal_approx(float(debug.get("duration_seconds", 0.0)), 12.0)
			flags["drawer_checked"] = true
			flags["timing_checked"] = true
			flags["snapshot_checked"] = true
			notes = "the scene-owned purchase status receives the controller's private 12-second snapshot unchanged"
		"empty_supply_safe_state":
			var fixture := _drawer_fixture()
			fixture["cards"] = []
			fixture["preview"] = {}
			fixture["selected_card_name"] = ""
			drawer_preview.call("set_supply", fixture)
			var debug: Dictionary = drawer_preview.call("debug_snapshot")
			passed = int(debug.get("rendered_card_count", -1)) == 0 and bool(debug.get("market_empty_visible", false)) and bool(debug.get("preview_empty_visible", false))
			flags["drawer_checked"] = true
			flags["snapshot_checked"] = true
			notes = "empty supply renders two static empty states without creating fallback Labels"
		"keyboard_focus_chain":
			_reset_drawer_fixture()
			var cards := _drawer_market_cards()
			var links_ok := cards.size() == 2
			if links_ok:
				links_ok = cards[0].focus_mode == Control.FOCUS_ALL and cards[1].focus_mode == Control.FOCUS_ALL and cards[0].get_node_or_null(cards[0].focus_next) == cards[1] and cards[1].get_node_or_null(cards[1].focus_previous) == cards[0]
			passed = links_ok
			flags["drawer_checked"] = true
			flags["focus_checked"] = true
			notes = "Drawer owns a stable wraparound keyboard focus chain for market cards"
		"real_main_drawer_route":
			var route_result := await _exercise_real_main_drawer_route()
			passed = bool(route_result.get("opened", false)) and bool(route_result.get("rendered", false)) and bool(route_result.get("closed", false)) and bool(route_result.get("pure", false))
			flags["drawer_checked"] = true
			flags["action_route_checked"] = true
			flags["main_delegation_checked"] = true
			flags["pure_data_checked"] = true
			notes = "real main opens, renders and closes the scene-owned Drawer through its aggregate signal%s" % ["" if passed else ": %s" % JSON.stringify(route_result)]
		"legacy_drawer_builders_and_node_refs_absent":
			var source := FileAccess.get_file_as_string("res://scripts/main.gd")
			var retired_tokens := ["DistrictSupplyMarketCardScene", "DistrictSupplyPreviewCardScene", "var district_supply_title_label", "var district_supply_access_label", "var district_supply_chip_row", "var district_supply_state_rail", "var district_supply_list_box", "var district_supply_preview_box", "func _add_district_supply_header_chips", "func _add_district_supply_summary_chip", "func _add_district_supply_market_status_rail", "func _sync_district_supply_market_focus_links", "func _add_district_supply_card_button", "func _add_district_supply_preview", "func _on_district_card_gui_input"]
			var retired := true
			for token_variant: Variant in retired_tokens:
				retired = retired and not source.contains(str(token_variant))
			passed = retired and source.contains("func _district_supply_snapshot_source") and source.contains("func _on_district_supply_action_requested") and source.contains("compose_district_supply_snapshot") and source.contains("district_supply_overlay.call(\"set_supply\"")
			flags["drawer_checked"] = true
			flags["legacy_deletion_checked"] = true
			notes = "main keeps one pure source adapter and action router with no Drawer child-node mirrors or builders"
		"snapshot_service_scene_composition":
			var service := _snapshot_service()
			passed = service != null and service.scene_file_path == SNAPSHOT_SERVICE_SCENE_PATH and service.has_method("compose") and service.has_method("validate_source") and service.has_method("debug_snapshot") and ResourceLoader.exists(SNAPSHOT_SERVICE_SCRIPT_PATH)
			flags["snapshot_service_checked"] = true
			notes = "GameRuntimeCoordinator statically owns the editable DistrictSupplySnapshotService"
		"pure_snapshot_source_contract":
			var service := _snapshot_service()
			var source := _snapshot_source_fixture()
			var validation: Dictionary = service.call("validate_source", source) if service != null else {}
			var output: Dictionary = service.call("compose", source) if service != null else {}
			passed = bool(validation.get("valid", false)) and _is_data_only(source) and _is_data_only(output) and _all_color_fields_are_hex(output)
			flags["snapshot_service_checked"] = true
			flags["source_contract_checked"] = true
			flags["pure_data_checked"] = true
			flags["snapshot_checked"] = true
			notes = "source and Drawer output are pure dictionaries with hexadecimal display colors"
		"source_rejects_runtime_objects":
			var service := _snapshot_service()
			var source := _snapshot_source_fixture()
			source["runtime_object"] = drawer_preview
			var validation: Dictionary = service.call("validate_source", source) if service != null else {}
			var output: Dictionary = service.call("compose", source) if service != null else {}
			passed = not bool(validation.get("valid", true)) and not bool(validation.get("pure_data", true)) and (output.get("cards", []) as Array).is_empty() and _is_data_only(output)
			flags["snapshot_service_checked"] = true
			flags["source_contract_checked"] = true
			flags["pure_data_checked"] = true
			notes = "Node/Object input is rejected and yields a viewer-safe empty snapshot"
		"header_chip_format_parity":
			var output := _compose_snapshot_fixture()
			var chips: Array = output.get("header_chips", []) if output.get("header_chips", []) is Array else []
			passed = _entries_contain_text(chips, "牌架 2") and _entries_contain_text(chips, "可购买") and _entries_contain_text(chips, "怪兽脚下") and _entries_contain_text(chips, "¥900") and _entries_contain_text(chips, "手牌 3/10") and _entries_contain_text(chips, "价格已锁")
			flags["snapshot_service_checked"] = true
			flags["format_parity_checked"] = true
			notes = "header chips preserve rack, access, viewer cash, hand pressure and locked-window reads"
		"market_summary_format_parity":
			var output := _compose_snapshot_fixture()
			var entries: Array = output.get("market_status", []) if output.get("market_status", []) is Array else []
			passed = _entries_contain_text(entries, "可买 1") and _entries_contain_text(entries, "仅看 1") and _entries_contain_text(entries, "升级 1")
			flags["snapshot_service_checked"] = true
			flags["format_parity_checked"] = true
			notes = "service derives the same actionable, browse and upgrade summary from supplied rule states"
		"market_card_format_parity":
			var output := _compose_snapshot_fixture()
			var cards: Array = output.get("cards", []) if output.get("cards", []) is Array else []
			var first: Dictionary = cards[0] if cards.size() > 0 and cards[0] is Dictionary else {}
			var second: Dictionary = cards[1] if cards.size() > 1 and cards[1] is Dictionary else {}
			passed = cards.size() == 2 and str(first.get("card_name", "")) == "轨道融资1" and bool(first.get("selected", false)) and bool(first.get("actionable", false)) and str(second.get("card_name", "")) == "城市融资1" and not bool(second.get("actionable", true)) and str(first.get("accent", "")).begins_with("#")
			flags["snapshot_service_checked"] = true
			flags["format_parity_checked"] = true
			notes = "two market-card snapshots preserve order, selection, enabled state and color contract"
		"selected_preview_format_parity":
			var output := _compose_snapshot_fixture()
			var preview: Dictionary = output.get("preview", {}) if output.get("preview", {}) is Dictionary else {}
			var scans: Array = preview.get("scan_sections", []) if preview.get("scan_sections", []) is Array else []
			var face: Dictionary = preview.get("card_face", {}) if preview.get("card_face", {}) is Dictionary else {}
			passed = str(preview.get("card_name", "")) == "轨道融资1" and str(preview.get("title", "")).contains("轨道融资") and bool(preview.get("buy_enabled", false)) and scans.size() == 4 and str(face.get("presentation", "")) == "inspector_full"
			flags["snapshot_service_checked"] = true
			flags["format_parity_checked"] = true
			notes = "selected preview preserves verdict, four scan sections, enabled Buy and full CardFace data"
		"purchase_window_service_passthrough":
			var source := _snapshot_source_fixture()
			var expected: Dictionary = (source.get("purchase_window", {}) as Dictionary).duplicate(true)
			var service := _snapshot_service()
			var output: Dictionary = service.call("compose", source) if service != null else {}
			passed = output.get("purchase_window", {}) == expected and is_equal_approx(float((output.get("purchase_window", {}) as Dictionary).get("remaining_seconds", 0.0)), 9.5)
			flags["snapshot_service_checked"] = true
			flags["format_parity_checked"] = true
			flags["timing_checked"] = true
			notes = "controller-owned private 12-second status passes through without reinterpretation"
		"viewer_private_boundary":
			var source := _snapshot_source_fixture()
			var output := _compose_snapshot_fixture()
			var encoded := JSON.stringify({"source": source, "output": output})
			passed = int(source.get("player_cash", -1)) == 900 and int(source.get("counted_hand_size", -1)) == 3 and not _contains_private_tokens(encoded) and not encoded.contains("秘密手牌") and not encoded.contains("弃置牌名")
			flags["snapshot_service_checked"] = true
			flags["privacy_checked"] = true
			flags["source_contract_checked"] = true
			notes = "viewer cash and counted hand size cross privately without hand names, discard content, owners or channel source"
		"real_main_snapshot_service_route":
			var result := await _exercise_real_main_snapshot_service_route()
			passed = bool(result.get("service_found", false)) and bool(result.get("source_pure", false)) and bool(result.get("output_pure", false)) and bool(result.get("drawer_rendered", false)) and int(result.get("source_count", 0)) == int(result.get("output_count", -1))
			flags["snapshot_service_checked"] = true
			flags["source_contract_checked"] = true
			flags["main_delegation_checked"] = true
			flags["pure_data_checked"] = true
			notes = "real main builds one pure fact source and routes it through Coordinator to the scene-owned Drawer%s" % ["" if passed else ": %s" % JSON.stringify(result)]
		"snapshot_service_has_no_rule_authority":
			var service := _snapshot_service()
			service.call("compose", _snapshot_source_fixture())
			var debug: Dictionary = service.call("debug_snapshot") if service != null else {}
			passed = bool(debug.get("service_ready", false)) and bool(debug.get("service_authoritative", false)) and not bool(debug.get("calculates_purchase_eligibility", true)) and not bool(debug.get("calculates_card_price", true)) and not bool(debug.get("mutates_player_cash", true)) and not bool(debug.get("mutates_inventory", true)) and not bool(debug.get("reads_private_hand_cards", true)) and not bool(debug.get("reads_runtime_nodes", true))
			flags["snapshot_service_checked"] = true
			flags["authority_boundary_checked"] = true
			notes = "service owns formatting only and explicitly rejects purchase, price, cash, inventory and runtime-node authority"
		"legacy_snapshot_formatter_closure_absent":
			var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
			var service_source := FileAccess.get_file_as_string(SNAPSHOT_SERVICE_SCRIPT_PATH)
			var retired_functions := ["_district_supply_drawer_snapshot", "_district_supply_pure_ui_value", "_district_supply_header_chip_entries", "_district_supply_market_summary", "_district_supply_market_status_entries", "_district_supply_market_status_entry", "_district_supply_access_short_label", "_district_supply_access_color", "_district_supply_purchase_verdict_entries", "_district_supply_micro_card_chip_entries", "_district_supply_decision_chip_entries", "_district_supply_preview_scan_sections", "_district_supply_buy_scan_text", "_district_supply_play_scan_text", "_district_supply_target_scan_text", "_district_supply_target_scan_tooltip", "_district_supply_market_card_snapshot", "_district_supply_preview_snapshot", "_district_supply_preview_card_face_snapshot"]
			var retired := true
			for function_name_variant: Variant in retired_functions:
				retired = retired and not main_source.contains("func %s(" % str(function_name_variant))
			var rule_tokens_absent := true
			for token_variant: Variant in ["_card_price(", "_can_buy_card_from_district(", "_purchase_requires_discard(", "_player_can_receive_card_with_discard(", "_buy_card_for_player_from_district("]:
				rule_tokens_absent = rule_tokens_absent and not service_source.contains(str(token_variant))
			passed = retired and rule_tokens_absent and main_source.contains("func _district_supply_purchase_state") and main_source.contains("func _district_supply_snapshot_source") and main_source.contains("compose_district_supply_snapshot")
			flags["snapshot_service_checked"] = true
			flags["authority_boundary_checked"] = true
			flags["legacy_deletion_checked"] = true
			notes = "nineteen main formatters are absent while purchase-state rules stay in main and never enter the service"
	return _record(case_id, passed, notes, flags)


func _run_settlement_characterization_case(case_id: String) -> Dictionary:
	if case_id == "legacy_upgrade_replace_routes_classified":
		return _characterize_legacy_settlement_routes()
	var main := await _prepare_settlement_main()
	if main == null:
		return _characterization_result({}, {}, false, "real main could not be instantiated")
	var result := _execute_settlement_characterization(main, case_id)
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return result


func _execute_settlement_characterization(main: Control, case_id: String) -> Dictionary:
	var player_index := 1 if case_id == "settlement_ai_uses_same_authorized_path" else 0
	var fixture := _prepare_settlement_fixture(main, player_index)
	if fixture.is_empty():
		return _characterization_result({}, {}, false, "no real district supply fixture was available")
	var card_id := str(fixture.get("card_id", ""))
	var district_index := int(fixture.get("district_index", -1))
	var price := int(fixture.get("price", 0))
	match case_id:
		"settlement_new_card_commit":
			var transaction := _exercise_settlement_purchase(main, fixture)
			var before: Dictionary = transaction.get("before", {})
			var after: Dictionary = transaction.get("after", {})
			var aligned := bool(transaction.get("bought", false)) and int(after.get("cash", 0)) - int(before.get("cash", 0)) == -price and int(after.get("hand_count", 0)) - int(before.get("hand_count", 0)) == 1 and int(after.get("purchase_count", 0)) - int(before.get("purchase_count", 0)) == 1 and _slot_change_kind(before, after) == "added"
			return _characterization_result(before, after, aligned, "new-family purchase commits one card and one exact debit", {"mutation_expected": "add_card"})
		"settlement_same_family_upgrade_commit":
			_set_settlement_slots(main, player_index, [main.call("_make_skill", card_id)])
			var transaction := _exercise_settlement_purchase(main, fixture)
			var before: Dictionary = transaction.get("before", {})
			var after: Dictionary = transaction.get("after", {})
			var aligned := bool(transaction.get("bought", false)) and int(after.get("hand_count", 0)) == int(before.get("hand_count", -1)) and int(after.get("purchase_count", 0)) - int(before.get("purchase_count", 0)) == 1 and _slot_change_kind(before, after) == "upgrade"
			return _characterization_result(before, after, aligned, "duplicate family upgrades in place before hand-limit pressure", {"mutation_expected": "upgrade", "upgrade_checked": true})
		"settlement_max_rank_rejected_without_mutation":
			var max_rank_name := _max_upgrade_name(main, card_id)
			_set_settlement_slots(main, player_index, [main.call("_make_skill", max_rank_name)])
			var transaction := _exercise_settlement_purchase(main, fixture)
			var before: Dictionary = transaction.get("before", {})
			var after: Dictionary = transaction.get("after", {})
			var aligned := not bool(transaction.get("bought", true)) and _no_settlement_mutation(before, after)
			return _characterization_result(before, after, aligned, "a held rank-IV family rejects another copy without charge", {"mutation_expected": "none", "upgrade_checked": true})
		"settlement_exact_cash_debit_and_ledger":
			_set_settlement_cash(main, player_index, price)
			var transaction := _exercise_settlement_purchase(main, fixture)
			var before: Dictionary = transaction.get("before", {})
			var after: Dictionary = transaction.get("after", {})
			var aligned := bool(transaction.get("bought", false)) and int(after.get("cash", -1)) == 0 and int(after.get("total_card_spend", 0)) - int(before.get("total_card_spend", 0)) == price and int(after.get("ledger_card_spend_count", 0)) - int(before.get("ledger_card_spend_count", 0)) == 1
			return _characterization_result(before, after, aligned, "exact cash pays once and records one private card-spend entry", {"mutation_expected": "debit_and_add"})
		"settlement_insufficient_cash_without_mutation":
			_set_settlement_cash(main, player_index, maxi(0, price - 1))
			var transaction := _exercise_settlement_purchase(main, fixture)
			var before: Dictionary = transaction.get("before", {})
			var after: Dictionary = transaction.get("after", {})
			var aligned := not bool(transaction.get("bought", true)) and _no_settlement_mutation(before, after)
			return _characterization_result(before, after, aligned, "insufficient cash fails before acquisition, debit, and spend ledger", {"mutation_expected": "none"})
		"settlement_supply_remains_after_purchase":
			var transaction := _exercise_settlement_purchase(main, fixture)
			var before: Dictionary = transaction.get("before", {})
			var after: Dictionary = transaction.get("after", {})
			var aligned := bool(transaction.get("bought", false)) and str(before.get("supply_fingerprint", "")) == str(after.get("supply_fingerprint", ""))
			return _characterization_result(before, after, aligned, "purchase does not reserve or silently consume the shared rack", {"mutation_expected": "player_only"})
		"settlement_hand_limit_opens_pending_discard_without_charge":
			_set_settlement_slots(main, player_index, _full_counted_hand(main, card_id, int(fixture.get("hand_limit", 5))))
			var transaction := _exercise_settlement_purchase(main, fixture)
			var before: Dictionary = transaction.get("before", {})
			var after: Dictionary = transaction.get("after", {})
			var aligned := not bool(transaction.get("bought", true)) and str(after.get("window_state", "")) == "pending_discard" and bool(after.get("pending_discard", false)) and int(after.get("cash", 0)) == int(before.get("cash", -1)) and int(after.get("purchase_count", 0)) == int(before.get("purchase_count", -1)) and int(after.get("total_card_spend", 0)) == int(before.get("total_card_spend", -1)) and _slot_change_kind(before, after) == "none"
			return _characterization_result(before, after, aligned, "a sixth ordinary card opens private discard before payment", {"mutation_expected": "pending_discard", "discard_checked": true})
		"settlement_hand_limit_exempt_card_bypasses_discard":
			var full_hand := _full_counted_hand(main, card_id, int(fixture.get("hand_limit", 5)))
			_set_settlement_slots(main, player_index, full_hand)
			var before := _settlement_probe(main, player_index, district_index)
			var military_controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MilitaryRuntimeController")
			var fixed_skill: Dictionary = military_controller.call("make_command_skill", "move", 1, 99001, "settlement-characterization") if military_controller != null else {}
			var slots := full_hand.duplicate(true)
			slots.append(fixed_skill)
			_set_settlement_slots(main, player_index, slots)
			var after := _settlement_probe(main, player_index, district_index)
			var player: Dictionary = _settlement_player(main, player_index)
			var discardable: Array = main.call("_discardable_hand_slots_for_purchase", player)
			var aligned := int(after.get("hand_count", -1)) == int(before.get("hand_count", -2)) and int(after.get("slot_count", 0)) == int(before.get("slot_count", 0)) + 1 and not discardable.has(slots.size() - 1)
			return _characterization_result(before, after, aligned, "fixed persistent skills do not count toward the five-card limit or private discard", {"mutation_expected": "exempt_slot_addition", "discard_checked": true})
		"settlement_discard_cancel_restores_window":
			_set_settlement_slots(main, player_index, _full_counted_hand(main, card_id, int(fixture.get("hand_limit", 5))))
			var before := _settlement_probe(main, player_index, district_index)
			main.call("_buy_card_for_player_from_district", player_index, district_index, card_id, false, true, -1)
			var pending := _settlement_probe(main, player_index, district_index)
			main.call("_cancel_discard_purchase")
			var after := _settlement_probe(main, player_index, district_index)
			var aligned := str(pending.get("window_state", "")) == "pending_discard" and not bool(after.get("pending_discard", true)) and str(after.get("window_state", "")) == "active" and _no_settlement_mutation(before, after)
			return _characterization_result(before, after, aligned, "cancelled private discard cancels purchase and restores the live window", {"mutation_expected": "none", "discard_checked": true})
		"settlement_discard_confirm_commits_once":
			_set_settlement_slots(main, player_index, _full_counted_hand(main, card_id, int(fixture.get("hand_limit", 5))))
			var before := _settlement_probe(main, player_index, district_index)
			main.call("_buy_card_for_player_from_district", player_index, district_index, card_id, false, true, -1)
			var discardable: Array = main.call("_discardable_hand_slots_for_purchase", _settlement_player(main, player_index))
			if not discardable.is_empty():
				main.call("_confirm_discard_purchase", int(discardable[0]))
			var after := _settlement_probe(main, player_index, district_index)
			var aligned := not discardable.is_empty() and int(after.get("cash", 0)) - int(before.get("cash", 0)) == -price and int(after.get("hand_count", 0)) == int(before.get("hand_count", -1)) and int(after.get("purchase_count", 0)) - int(before.get("purchase_count", 0)) == 1 and int(after.get("ledger_card_spend_count", 0)) - int(before.get("ledger_card_spend_count", 0)) == 1 and not bool(after.get("pending_discard", true)) and _slot_change_kind(before, after) == "discard_replace"
			return _characterization_result(before, after, aligned, "valid private discard replaces one ordinary card and commits payment once", {"mutation_expected": "discard_replace", "discard_checked": true})
		"settlement_invalid_discard_slot_without_mutation":
			_set_settlement_slots(main, player_index, _full_counted_hand(main, card_id, int(fixture.get("hand_limit", 5))))
			var before := _settlement_probe(main, player_index, district_index)
			main.call("_buy_card_for_player_from_district", player_index, district_index, card_id, false, true, -1)
			main.call("_confirm_discard_purchase", 99999)
			var after := _settlement_probe(main, player_index, district_index)
			var aligned := _no_settlement_mutation(before, after) and not bool(after.get("pending_discard", true)) and str(after.get("window_state", "")) == "active"
			return _characterization_result(before, after, aligned, "invalid private discard cannot remove a card, debit cash, or increment purchase count", {"mutation_expected": "none", "discard_checked": true})
		"settlement_locked_or_queued_card_not_discardable":
			var slots := _full_counted_hand(main, card_id, int(fixture.get("hand_limit", 5)))
			if slots.size() >= 2:
				(slots[0] as Dictionary)["queued_for_resolution"] = true
				(slots[1] as Dictionary)["lock_left"] = 5.0
			_set_settlement_slots(main, player_index, slots)
			var before := _settlement_probe(main, player_index, district_index)
			var discardable: Array = main.call("_discardable_hand_slots_for_purchase", _settlement_player(main, player_index))
			var after := _settlement_probe(main, player_index, district_index)
			var aligned := slots.size() >= 2 and not discardable.has(0) and not discardable.has(1) and discardable.size() == slots.size() - 2 and _no_settlement_mutation(before, after)
			return _characterization_result(before, after, aligned, "queued and cooldown-locked cards are excluded from private discard choices", {"mutation_expected": "none", "discard_checked": true})
		"settlement_pending_discard_state_drift_audit":
			_set_settlement_slots(main, player_index, _full_counted_hand(main, card_id, int(fixture.get("hand_limit", 5))))
			main.call("_buy_card_for_player_from_district", player_index, district_index, card_id, false, true, -1)
			var discardable: Array = main.call("_discardable_hand_slots_for_purchase", _settlement_player(main, player_index))
			_set_settlement_cash(main, player_index, maxi(0, price - 1))
			var before := _settlement_probe(main, player_index, district_index)
			if not discardable.is_empty():
				main.call("_confirm_discard_purchase", int(discardable[0]))
			var after := _settlement_probe(main, player_index, district_index)
			var aligned := not discardable.is_empty() and _no_settlement_mutation(before, after) and not bool(after.get("pending_discard", true)) and str(after.get("window_state", "")) == "active"
			return _characterization_result(before, after, aligned, "cash drift is revalidated before discard, so a failed resume does not consume the chosen old card", {"mutation_expected": "none", "discard_checked": true, "risk": "high if future cutover changes validation order"})
		"settlement_ai_uses_same_authorized_path":
			_set_settlement_slots(main, player_index, _full_counted_hand(main, card_id, int(fixture.get("hand_limit", 5))))
			var transaction := _exercise_settlement_purchase(main, fixture, true)
			var before: Dictionary = transaction.get("before", {})
			var after: Dictionary = transaction.get("after", {})
			var safe := _public_delta_is_private_safe(main, int(before.get("log_count", 0)), [str(_settlement_player(main, player_index).get("name", "")), card_id, str(main.call("_card_display_name", card_id))])
			var aligned := bool(transaction.get("bought", false)) and int(after.get("cash", 0)) - int(before.get("cash", 0)) == -price and int(after.get("hand_count", 0)) == int(before.get("hand_count", -1)) and int(after.get("purchase_count", 0)) - int(before.get("purchase_count", 0)) == 1 and safe
			return _characterization_result(before, after, aligned, "AI purchase uses the same authorized transaction and keeps discard identity private", {"mutation_expected": "discard_replace", "discard_checked": true, "privacy_checked": safe})
		"settlement_public_private_event_boundary":
			var transaction := _exercise_settlement_purchase(main, fixture)
			var before: Dictionary = transaction.get("before", {})
			var after: Dictionary = transaction.get("after", {})
			var player_name := str(_settlement_player(main, player_index).get("name", ""))
			var safe := _public_delta_is_private_safe(main, int(before.get("log_count", 0)), [player_name, card_id, str(main.call("_card_display_name", card_id))])
			var private_spend := int(after.get("ledger_card_spend_count", 0)) - int(before.get("ledger_card_spend_count", 0)) == 1
			var aligned := bool(transaction.get("bought", false)) and safe and private_spend
			return _characterization_result(before, after, aligned, "public feedback stays anonymous while the buyer receives one private spend record", {"mutation_expected": "debit_and_add", "privacy_checked": safe})
		"settlement_post_commit_hooks_exactly_once":
			var transaction := _exercise_settlement_purchase(main, fixture)
			var before: Dictionary = transaction.get("before", {})
			var after: Dictionary = transaction.get("after", {})
			var aligned := bool(transaction.get("bought", false)) and int(after.get("purchase_count", 0)) - int(before.get("purchase_count", 0)) == 1 and int(after.get("ledger_card_spend_count", 0)) - int(before.get("ledger_card_spend_count", 0)) == 1 and int(after.get("total_card_spend", 0)) - int(before.get("total_card_spend", 0)) == price
			return _characterization_result(before, after, aligned, "purchase counter, spend ledger, and debit-side hooks each commit exactly once", {"mutation_expected": "single_commit"})
	return _characterization_result({}, {}, false, "unknown settlement characterization case")


func _run_settlement_service_cutover_case(case_id: String) -> Dictionary:
	var main: Control = null
	var passed := false
	var notes := ""
	var flags := {
		"service_owner_checked": true,
		"plan_checked": false,
		"commit_checked": false,
		"main_adapter_checked": false,
		"legacy_formula_absent": false,
		"pure_data_checked": false,
		"window_owner_unchanged": false,
		"event_intents_checked": false,
	}
	match case_id:
		"settlement_service_scene_composition":
			var packed := load(SETTLEMENT_SERVICE_SCENE_PATH) as PackedScene
			var service := packed.instantiate() if packed != null else null
			passed = service != null and service.scene_file_path == SETTLEMENT_SERVICE_SCENE_PATH and service.has_method("plan_purchase") and service.has_method("commit_purchase") and service.has_method("validate_discard") and service.has_method("debug_snapshot") and load(SETTLEMENT_SERVICE_SCRIPT_PATH) != null
			notes = "scene-owned settlement service exposes the planned transaction boundary"
			if service != null:
				service.free()
		"coordinator_composes_settlement_service":
			var service := _settlement_service_node()
			var debug := _settlement_service_debug()
			passed = service != null and service.scene_file_path == SETTLEMENT_SERVICE_SCENE_PATH and bool(debug.get("service_ready", false)) and bool(debug.get("service_authoritative", false))
			notes = "GameRuntimeCoordinator statically composes and configures the authoritative settlement service"
		"pure_settlement_request_contract":
			main = await _prepare_settlement_main()
			var fixture := _prepare_settlement_fixture(main, 0) if main != null else {}
			var request := _build_settlement_service_request(main, fixture)
			var plan := _plan_settlement_service(main, request)
			passed = not request.is_empty() and _is_data_only(request) and _is_data_only(plan) and str(plan.get("status", "")) == "ready"
			flags["plan_checked"] = true
			flags["pure_data_checked"] = passed
			notes = "real world facts become a pure-data request and plan without mutating runtime state"
		"service_new_card_plan_and_commit":
			main = await _prepare_settlement_main()
			var fixture := _prepare_settlement_fixture(main, 0) if main != null else {}
			var transaction := _direct_settlement_service_transaction(main, fixture)
			var before: Dictionary = transaction.get("before", {})
			var after: Dictionary = transaction.get("after", {})
			var plan: Dictionary = transaction.get("plan", {})
			var result: Dictionary = transaction.get("result", {})
			passed = str(plan.get("operation", "")) == "add" and bool(result.get("committed", false)) and int(after.get("cash", 0)) - int(before.get("cash", 0)) == -int(fixture.get("price", 0)) and int(after.get("hand_count", 0)) - int(before.get("hand_count", 0)) == 1 and int(after.get("purchase_count", 0)) - int(before.get("purchase_count", 0)) == 1 and _slot_change_kind(before, after) == "added"
			flags["plan_checked"] = true
			flags["commit_checked"] = true
			notes = "new-card purchase is planned as add and committed atomically once"
		"service_duplicate_upgrade_plan_and_commit":
			main = await _prepare_settlement_main()
			var fixture := _prepare_settlement_fixture(main, 0) if main != null else {}
			var card_variant: Variant = main.call("_make_skill", str(fixture.get("card_id", ""))) if main != null else {}
			if card_variant is Dictionary:
				_set_settlement_slots(main, 0, [(card_variant as Dictionary).duplicate(true)])
			var transaction := _direct_settlement_service_transaction(main, fixture)
			var before: Dictionary = transaction.get("before", {})
			var after: Dictionary = transaction.get("after", {})
			var plan: Dictionary = transaction.get("plan", {})
			var result: Dictionary = transaction.get("result", {})
			passed = str(plan.get("operation", "")) == "upgrade" and bool(result.get("committed", false)) and int(after.get("hand_count", 0)) == int(before.get("hand_count", -1)) and _slot_change_kind(before, after) == "upgrade" and int(after.get("purchase_count", 0)) - int(before.get("purchase_count", 0)) == 1
			flags["plan_checked"] = true
			flags["commit_checked"] = true
			flags["upgrade_checked"] = true
			notes = "same-family ownership upgrades before applying the five-card hand limit"
		"service_rank_iv_rejection":
			main = await _prepare_settlement_main()
			var fixture := _prepare_settlement_fixture(main, 0) if main != null else {}
			var max_card_id := _max_upgrade_name(main, str(fixture.get("card_id", ""))) if main != null else ""
			var max_card_variant: Variant = main.call("_make_skill", max_card_id) if main != null and not max_card_id.is_empty() else {}
			if max_card_variant is Dictionary:
				_set_settlement_slots(main, 0, [(max_card_variant as Dictionary).duplicate(true)])
			var before := _settlement_probe(main, 0, int(fixture.get("district_index", -1))) if main != null else {}
			var plan := _plan_settlement_service(main, _build_settlement_service_request(main, fixture))
			var after := _settlement_probe(main, 0, int(fixture.get("district_index", -1))) if main != null else {}
			passed = str(plan.get("status", "")) == "rejected" and str(plan.get("reason", "")) == "max_rank" and _no_settlement_mutation(before, after)
			flags["plan_checked"] = true
			flags["upgrade_checked"] = true
			notes = "a maximum-rank family is rejected during planning with no partial mutation"
		"service_hand_limit_requires_discard_without_commit":
			main = await _prepare_settlement_main()
			var fixture := _prepare_settlement_fixture(main, 0) if main != null else {}
			_set_settlement_slots(main, 0, _full_counted_hand(main, str(fixture.get("card_id", "")), int(fixture.get("hand_limit", 5))))
			var before := _settlement_probe(main, 0, int(fixture.get("district_index", -1)))
			var plan := _plan_settlement_service(main, _build_settlement_service_request(main, fixture))
			var after := _settlement_probe(main, 0, int(fixture.get("district_index", -1)))
			passed = str(plan.get("status", "")) == "requires_discard" and not bool(plan.get("mutation_expected", true)) and not (plan.get("discardable_slots", []) as Array).is_empty() and _no_settlement_mutation(before, after)
			flags["plan_checked"] = true
			flags["discard_checked"] = true
			notes = "a full ordinary hand produces a private discard plan without charging or changing cards"
		"service_discard_confirm_atomic_commit":
			main = await _prepare_settlement_main()
			var fixture := _prepare_settlement_fixture(main, 0) if main != null else {}
			_set_settlement_slots(main, 0, _full_counted_hand(main, str(fixture.get("card_id", "")), int(fixture.get("hand_limit", 5))))
			var discardable: Array = main.call("_discardable_hand_slots_for_purchase", _settlement_player(main, 0))
			var discard_slot := int(discardable[0]) if not discardable.is_empty() else -1
			var transaction := _direct_settlement_service_transaction(main, fixture, discard_slot)
			var before: Dictionary = transaction.get("before", {})
			var after: Dictionary = transaction.get("after", {})
			var plan: Dictionary = transaction.get("plan", {})
			var result: Dictionary = transaction.get("result", {})
			passed = discard_slot >= 0 and str(plan.get("operation", "")) == "replace" and bool(result.get("committed", false)) and int(after.get("cash", 0)) - int(before.get("cash", 0)) == -int(fixture.get("price", 0)) and int(after.get("hand_count", 0)) == int(before.get("hand_count", -1)) and _slot_change_kind(before, after) == "discard_replace" and int(after.get("purchase_count", 0)) - int(before.get("purchase_count", 0)) == 1
			flags["plan_checked"] = true
			flags["commit_checked"] = true
			flags["discard_checked"] = true
			notes = "valid discard, replacement, debit, counter, and ledger changes commit as one transaction"
		"service_discard_cancel_no_commit":
			main = await _prepare_settlement_main()
			var fixture := _prepare_settlement_fixture(main, 0) if main != null else {}
			_set_settlement_slots(main, 0, _full_counted_hand(main, str(fixture.get("card_id", "")), int(fixture.get("hand_limit", 5))))
			var before := _settlement_probe(main, 0, int(fixture.get("district_index", -1)))
			var debug_before := _settlement_service_debug(main)
			main.call("_buy_card_for_player_from_district", 0, int(fixture.get("district_index", -1)), str(fixture.get("card_id", "")), false, true, -1)
			var pending := _settlement_probe(main, 0, int(fixture.get("district_index", -1)))
			main.call("_cancel_discard_purchase")
			var after := _settlement_probe(main, 0, int(fixture.get("district_index", -1)))
			var debug_after := _settlement_service_debug(main)
			passed = bool(pending.get("pending_discard", false)) and not bool(after.get("pending_discard", true)) and _no_settlement_mutation(before, after) and int(debug_after.get("committed_count", -1)) == int(debug_before.get("committed_count", -2))
			flags["plan_checked"] = true
			flags["commit_checked"] = true
			flags["discard_checked"] = true
			flags["main_adapter_checked"] = true
			notes = "cancel only resolves Controller/Overlay state and never invokes a settlement commit"
		"service_cash_drift_rejected_without_mutation":
			main = await _prepare_settlement_main()
			var fixture := _prepare_settlement_fixture(main, 0) if main != null else {}
			var initial_request := _build_settlement_service_request(main, fixture)
			var plan := _plan_settlement_service(main, initial_request)
			_set_settlement_cash(main, 0, maxi(0, int(fixture.get("price", 0)) - 1))
			var drift_before := _settlement_probe(main, 0, int(fixture.get("district_index", -1)))
			var current_request := _build_settlement_service_request(main, fixture)
			var result := _commit_settlement_service_plan(main, fixture, current_request, plan)
			var after := _settlement_probe(main, 0, int(fixture.get("district_index", -1)))
			passed = str(plan.get("status", "")) == "ready" and not bool(result.get("committed", true)) and ["state_drift", "cash_drift"].has(str(result.get("reason", ""))) and _no_non_cash_settlement_mutation(drift_before, after)
			flags["plan_checked"] = true
			flags["commit_checked"] = true
			notes = "cash drift between plan and commit rejects without touching cards, ledger, or counters"
		"service_invalid_discard_rejected_without_mutation":
			main = await _prepare_settlement_main()
			var fixture := _prepare_settlement_fixture(main, 0) if main != null else {}
			_set_settlement_slots(main, 0, _full_counted_hand(main, str(fixture.get("card_id", "")), int(fixture.get("hand_limit", 5))))
			var before := _settlement_probe(main, 0, int(fixture.get("district_index", -1)))
			var request := _build_settlement_service_request(main, fixture, 99999)
			var plan := _plan_settlement_service(main, request)
			var validation := _validate_settlement_discard(main, request, 99999)
			var after := _settlement_probe(main, 0, int(fixture.get("district_index", -1)))
			passed = str(plan.get("status", "")) == "rejected" and str(plan.get("reason", "")) == "invalid_discard_slot" and not bool(validation.get("valid", true)) and _no_settlement_mutation(before, after)
			flags["plan_checked"] = true
			flags["discard_checked"] = true
			notes = "an invalid discard slot is rejected by the service before any settlement mutation"
		"service_exact_once_counter_ledger_and_event_intents":
			main = await _prepare_settlement_main()
			var fixture := _prepare_settlement_fixture(main, 0) if main != null else {}
			var request := _build_settlement_service_request(main, fixture)
			var plan := _plan_settlement_service(main, request)
			var before := _settlement_probe(main, 0, int(fixture.get("district_index", -1)))
			var first_result := _commit_settlement_service_plan(main, fixture, request, plan)
			var after_first := _settlement_probe(main, 0, int(fixture.get("district_index", -1)))
			var second_request := _build_settlement_service_request(main, fixture)
			var second_result := _commit_settlement_service_plan(main, fixture, second_request, plan)
			var after_second := _settlement_probe(main, 0, int(fixture.get("district_index", -1)))
			var intents_ok := (first_result.get("ledger_intents", []) as Array).size() == 1 and (first_result.get("public_event_intents", []) as Array).size() == 1 and (first_result.get("private_event_intents", []) as Array).size() == 1 and (first_result.get("post_commit_hooks", []) as Array).size() == 4 and _is_data_only(first_result)
			passed = bool(first_result.get("committed", false)) and not bool(second_result.get("committed", true)) and int(after_first.get("purchase_count", 0)) - int(before.get("purchase_count", 0)) == 1 and int(after_first.get("ledger_card_spend_count", 0)) - int(before.get("ledger_card_spend_count", 0)) == 1 and _no_settlement_mutation(after_first, after_second) and intents_ok
			flags["plan_checked"] = true
			flags["commit_checked"] = true
			flags["event_intents_checked"] = intents_ok
			flags["pure_data_checked"] = _is_data_only(first_result) and _is_data_only(second_result)
			notes = "one plan commits counters, private ledger, event intents, and hooks exactly once"
		"real_main_player_route_delegates_to_service":
			main = await _prepare_settlement_main()
			var fixture := _prepare_settlement_fixture(main, 0) if main != null else {}
			var debug_before := _settlement_service_debug(main)
			var transaction := _exercise_settlement_purchase(main, fixture)
			var debug_after := _settlement_service_debug(main)
			passed = bool(transaction.get("bought", false)) and int(debug_after.get("committed_count", 0)) - int(debug_before.get("committed_count", 0)) == 1
			flags["plan_checked"] = true
			flags["commit_checked"] = true
			flags["main_adapter_checked"] = true
			notes = "the real player purchase compatibility entry delegates one commit to the service"
		"real_main_ai_route_delegates_to_service":
			main = await _prepare_settlement_main()
			var fixture := _prepare_settlement_fixture(main, 1) if main != null else {}
			_set_settlement_slots(main, 1, _full_counted_hand(main, str(fixture.get("card_id", "")), int(fixture.get("hand_limit", 5))))
			var debug_before := _settlement_service_debug(main)
			var transaction := _exercise_settlement_purchase(main, fixture, true)
			var debug_after := _settlement_service_debug(main)
			passed = bool(transaction.get("bought", false)) and int(debug_after.get("committed_count", 0)) - int(debug_before.get("committed_count", 0)) == 1
			flags["plan_checked"] = true
			flags["commit_checked"] = true
			flags["main_adapter_checked"] = true
			flags["privacy_checked"] = true
			notes = "AI auto-discard and purchase use the same service route without a parallel settlement formula"
		"real_main_resumed_discard_route_delegates_to_service":
			main = await _prepare_settlement_main()
			var fixture := _prepare_settlement_fixture(main, 0) if main != null else {}
			_set_settlement_slots(main, 0, _full_counted_hand(main, str(fixture.get("card_id", "")), int(fixture.get("hand_limit", 5))))
			var bought_initially := bool(main.call("_buy_card_for_player_from_district", 0, int(fixture.get("district_index", -1)), str(fixture.get("card_id", "")), false, true, -1))
			var discardable: Array = main.call("_discardable_hand_slots_for_purchase", _settlement_player(main, 0))
			var debug_before := _settlement_service_debug(main)
			if not discardable.is_empty():
				main.call("_confirm_discard_purchase", int(discardable[0]))
			var debug_after := _settlement_service_debug(main)
			var after := _settlement_probe(main, 0, int(fixture.get("district_index", -1)))
			passed = not bought_initially and not discardable.is_empty() and int(debug_after.get("committed_count", 0)) - int(debug_before.get("committed_count", 0)) == 1 and not bool(after.get("pending_discard", true))
			flags["plan_checked"] = true
			flags["commit_checked"] = true
			flags["main_adapter_checked"] = true
			flags["discard_checked"] = true
			notes = "resumed private discard re-enters the same main adapter and commits through the service once"
		"window_and_legacy_save_ownership_unchanged":
			var controller := _controller_node()
			var service_debug := _settlement_service_debug()
			passed = controller != null and coordinator.has_method("authorize_district_purchase") and coordinator.has_method("district_purchase_legacy_save_snapshot") and coordinator.has_method("apply_district_purchase_legacy_save_snapshot") and coordinator.has_method("restore_district_purchase_legacy_state") and not bool(service_debug.get("window_authority", true)) and not bool(service_debug.get("presentation_authority", true))
			flags["window_owner_unchanged"] = passed
			notes = "Controller retains window, authorization, pending-discard, and legacy-save ownership"
		"legacy_main_settlement_mutations_absent":
			var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
			var buy_source := _function_source(main_source, "_buy_card_for_player_from_district")
			var adapters_present := buy_source.contains("plan_district_purchase_settlement") and buy_source.contains("commit_district_purchase_settlement") and main_source.contains("func _district_purchase_settlement_request(")
			var retired_helpers_absent := not main_source.contains("func _record_player_card_purchase(") and not main_source.contains("func _discard_card_from_player(") and not main_source.contains("func _find_previous_rank_card_slot(") and not main_source.contains("func _find_owned_card_slot(")
			var formulas_absent := not buy_source.contains("player[\"cash\"] =") and not buy_source.contains("_record_player_card_spend(") and not buy_source.contains("card_purchase_count\"] =") and not buy_source.contains("slots[")
			var service_source := FileAccess.get_file_as_string(SETTLEMENT_SERVICE_SCRIPT_PATH)
			var inventory_source := FileAccess.get_file_as_string(CARD_INVENTORY_SERVICE_SCRIPT_PATH)
			var settlement_owns_finance := service_source.contains("after_player[\"cash\"] =") and service_source.contains("after_player[\"card_purchase_count\"] =") and service_source.contains("_append_ledger_entry")
			var settlement_delegates_inventory := service_source.contains("func set_inventory_service(") and service_source.contains("_inventory_receive_plan(") and not service_source.contains("func _plan_inventory_receive(") and not service_source.contains("func _apply_inventory_operation(")
			var inventory_owns_slots := inventory_source.contains("func _plan_receive(") and inventory_source.contains("func _apply_receive_operation(") and inventory_source.contains("func discardable_slots(")
			passed = adapters_present and retired_helpers_absent and formulas_absent and settlement_owns_finance and settlement_delegates_inventory and inventory_owns_slots
			flags["main_adapter_checked"] = adapters_present
			flags["service_owner_checked"] = settlement_owns_finance and settlement_delegates_inventory and inventory_owns_slots
			flags["legacy_formula_absent"] = retired_helpers_absent and formulas_absent
			notes = "main.gd keeps a thin fact/authorization/post-hook adapter; Settlement Service owns finance while Card Inventory Service owns slot mutation"
		"service_debug_snapshot_privacy_and_pure_data":
			var debug := _settlement_service_debug()
			var encoded := JSON.stringify(debug)
			passed = _is_data_only(debug) and not _contains_private_tokens(encoded) and not encoded.contains("card_id") and not encoded.contains("player_index") and not bool(debug.get("legacy_settlement_fallback_used", true))
			flags["pure_data_checked"] = _is_data_only(debug)
			flags["privacy_checked"] = not _contains_private_tokens(encoded)
			notes = "service diagnostics expose only counters and operation class, never buyer or private hand identity"
		_:
			notes = "unknown settlement service cutover case"
	if main != null and is_instance_valid(main):
		main.queue_free()
		await get_tree().process_frame
	flags["passed"] = passed
	flags["notes"] = notes
	return flags


func _build_settlement_service_request(main: Control, fixture: Dictionary, discard_slot: int = -1) -> Dictionary:
	if main == null or fixture.is_empty():
		return {}
	var player_index := int(fixture.get("player_index", -1))
	var district_index := int(fixture.get("district_index", -1))
	var card_id := str(fixture.get("card_id", ""))
	var districts: Array = main.get("districts") as Array
	if district_index < 0 or district_index >= districts.size() or not (districts[district_index] is Dictionary):
		return {}
	var supply_revision := str((districts[district_index] as Dictionary).get("card_choices", []))
	var authorization := {"authorized": true, "reason": "authorized", "price_context": {}}
	var value: Variant = main.call("_district_purchase_settlement_request", player_index, district_index, card_id, int(fixture.get("price", 0)), supply_revision, authorization, discard_slot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _plan_settlement_service(main: Control, request: Dictionary) -> Dictionary:
	var runtime := _settlement_runtime(main)
	if runtime == null:
		return {}
	var value: Variant = runtime.call("plan_district_purchase_settlement", request)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _validate_settlement_discard(main: Control, request: Dictionary, discard_slot: int) -> Dictionary:
	var runtime := _settlement_runtime(main)
	if runtime == null:
		return {}
	var value: Variant = runtime.call("validate_district_purchase_discard", request, discard_slot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _commit_settlement_service_plan(main: Control, fixture: Dictionary, request: Dictionary, plan: Dictionary) -> Dictionary:
	var runtime := _settlement_runtime(main)
	var player_index := int(fixture.get("player_index", -1))
	var players: Array = main.get("players") as Array if main != null else []
	if runtime == null or player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return {}
	var player: Dictionary = players[player_index]
	var value: Variant = runtime.call("commit_district_purchase_settlement", player, request, plan)
	players[player_index] = player
	main.set("players", players)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _direct_settlement_service_transaction(main: Control, fixture: Dictionary, discard_slot: int = -1) -> Dictionary:
	if main == null or fixture.is_empty():
		return {}
	var player_index := int(fixture.get("player_index", -1))
	var district_index := int(fixture.get("district_index", -1))
	var before := _settlement_probe(main, player_index, district_index)
	var request := _build_settlement_service_request(main, fixture, discard_slot)
	var plan := _plan_settlement_service(main, request)
	var result := _commit_settlement_service_plan(main, fixture, request, plan) if str(plan.get("status", "")) == "ready" else {}
	var after := _settlement_probe(main, player_index, district_index)
	return {"before": before, "request": request, "plan": plan, "result": result, "after": after}


func _settlement_runtime(main: Control = null) -> Node:
	if main != null:
		return main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	return coordinator


func _card_exists_for(main: Control, card_id: String) -> bool:
	var runtime := _settlement_runtime(main)
	return bool(runtime.call("card_exists", card_id)) if runtime != null else false


func _card_family_for(main: Control, card_id: String) -> String:
	var runtime := _settlement_runtime(main)
	return str(runtime.call("card_family_id", card_id)) if runtime != null else ""


func _card_rank_for(main: Control, card_id: String) -> int:
	var runtime := _settlement_runtime(main)
	return int(runtime.call("card_rank", card_id)) if runtime != null else 0


func _monster_controller_for(main: Control) -> Node:
	var runtime := _settlement_runtime(main)
	return runtime.get_node_or_null("MonsterRuntimeController") if runtime != null else null


func _settlement_service_node(main: Control = null) -> Node:
	var runtime := _settlement_runtime(main)
	return runtime.get_node_or_null("DistrictPurchaseSettlementRuntimeService") if runtime != null else null


func _settlement_service_debug(main: Control = null) -> Dictionary:
	var runtime := _settlement_runtime(main)
	if runtime == null or not runtime.has_method("district_purchase_settlement_debug"):
		return {}
	var value: Variant = runtime.call("district_purchase_settlement_debug")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _no_non_cash_settlement_mutation(before: Dictionary, after: Dictionary) -> bool:
	return int(after.get("hand_count", 0)) == int(before.get("hand_count", -1)) and int(after.get("purchase_count", 0)) == int(before.get("purchase_count", -1)) and int(after.get("total_card_spend", 0)) == int(before.get("total_card_spend", -1)) and int(after.get("ledger_count", 0)) == int(before.get("ledger_count", -1)) and _slot_change_kind(before, after) == "none"


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + 5)
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _prepare_settlement_main() -> Control:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	var main := packed.instantiate() as Control
	if main == null:
		return null
	main.visible = false
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.call("_new_game")
	await get_tree().process_frame
	main.set_process(false)
	return main


func _prepare_settlement_fixture(main: Control, player_index: int) -> Dictionary:
	var players: Array = main.get("players") as Array
	if player_index < 0 or player_index >= players.size():
		return {}
	var supply := _find_settlement_supply(main)
	if supply.is_empty():
		return {}
	var district_index := int(supply.get("district_index", -1))
	var card_id := str(supply.get("card_id", ""))
	_reset_settlement_player(main, player_index, 100000)
	main.set("selected_player", player_index)
	main.set("selected_district", district_index)
	main.set("selected_market_skill", card_id)
	main.set("previewed_district_card", card_id)
	var monsters := _monster_controller_for(main)
	var monster_variant: Variant = monsters.call("_make_auto_monster", 0, 0, district_index, player_index, 1) if monsters != null else {}
	var monster: Dictionary = monster_variant if monster_variant is Dictionary else {}
	if monsters != null:
		monsters.call("replace_runtime_state", {"auto_monsters": [monster]})
	main.call("_open_district_card_purchase_window", district_index, player_index)
	var source_variant: Variant = main.call("_district_supply_snapshot_source", district_index, player_index)
	var source: Dictionary = source_variant if source_variant is Dictionary else {}
	return {
		"player_index": player_index,
		"district_index": district_index,
		"card_id": card_id,
		"price": int(main.call("_card_price", card_id, district_index, player_index)),
		"hand_limit": int(source.get("hand_limit", 5)),
	}


func _find_settlement_supply(main: Control) -> Dictionary:
	var districts: Array = main.get("districts") as Array
	var fallback: Dictionary = {}
	for district_index in range(districts.size()):
		var district: Dictionary = districts[district_index] if districts[district_index] is Dictionary else {}
		if bool(district.get("destroyed", false)):
			continue
		var choices: Array = district.get("card_choices", []) if district.get("card_choices", []) is Array else []
		for card_variant: Variant in choices:
			var card_id := str(main.call("_canonical_card_supply_name", str(card_variant)))
			if card_id.is_empty() or not _card_exists_for(main, card_id):
				continue
			var candidate := {"district_index": district_index, "card_id": card_id}
			if fallback.is_empty():
				fallback = candidate
			if str(main.call("_next_upgrade_name", card_id)) != "":
				return candidate
	return fallback


func _reset_settlement_player(main: Control, player_index: int, cash: int) -> void:
	var players: Array = (main.get("players") as Array).duplicate(true)
	if player_index < 0 or player_index >= players.size():
		return
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
	player["cash"] = cash
	player["slots"] = []
	player["economic_ledger"] = []
	player["cash_history"] = [cash]
	player["card_purchase_count"] = 0
	player["total_card_spend"] = 0
	player["eliminated"] = false
	player["action_cooldown"] = 0.0
	var role_card: Dictionary = player.get("role_card", {}) if player.get("role_card", {}) is Dictionary else {}
	if not role_card.is_empty():
		role_card = role_card.duplicate(true)
		role_card["bonus_card_product"] = ""
		player["role_card"] = role_card
	players[player_index] = player
	main.set("players", players)


func _set_settlement_slots(main: Control, player_index: int, slots: Array) -> void:
	var players: Array = (main.get("players") as Array).duplicate(true)
	if player_index < 0 or player_index >= players.size():
		return
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
	player["slots"] = slots.duplicate(true)
	players[player_index] = player
	main.set("players", players)


func _set_settlement_cash(main: Control, player_index: int, cash: int) -> void:
	var players: Array = (main.get("players") as Array).duplicate(true)
	if player_index < 0 or player_index >= players.size():
		return
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
	player["cash"] = cash
	players[player_index] = player
	main.set("players", players)


func _settlement_player(main: Control, player_index: int) -> Dictionary:
	var players: Array = main.get("players") as Array
	return (players[player_index] as Dictionary).duplicate(true) if player_index >= 0 and player_index < players.size() and players[player_index] is Dictionary else {}


func _full_counted_hand(main: Control, incoming_card_id: String, limit: int) -> Array:
	var result: Array = []
	var incoming_family := _card_family_for(main, incoming_card_id)
	var names: Array = main.call("_card_codex_names", "all")
	var fallback_skill: Dictionary = {}
	for name_variant: Variant in names:
		var card_id := str(main.call("_canonical_card_supply_name", str(name_variant)))
		if card_id.is_empty() or _card_family_for(main, card_id) == incoming_family or not _card_exists_for(main, card_id):
			continue
		var skill_variant: Variant = main.call("_make_skill", card_id)
		var skill: Dictionary = skill_variant if skill_variant is Dictionary else {}
		if skill.is_empty() or not bool(main.call("_counts_toward_hand_limit", skill)):
			continue
		if fallback_skill.is_empty():
			fallback_skill = skill.duplicate(true)
		result.append(skill.duplicate(true))
		if result.size() >= limit:
			break
	while result.size() < limit and not fallback_skill.is_empty():
		result.append(fallback_skill.duplicate(true))
	return result


func _max_upgrade_name(main: Control, base_card_id: String) -> String:
	var current := base_card_id
	while true:
		var next_name := str(main.call("_next_upgrade_name", current))
		if next_name.is_empty():
			return current
		current = next_name
	return current


func _exercise_settlement_purchase(main: Control, fixture: Dictionary, anonymous: bool = false, discard_slot: int = -1) -> Dictionary:
	var player_index := int(fixture.get("player_index", -1))
	var district_index := int(fixture.get("district_index", -1))
	var before := _settlement_probe(main, player_index, district_index)
	var bought := bool(main.call("_buy_card_for_player_from_district", player_index, district_index, str(fixture.get("card_id", "")), anonymous, true, discard_slot))
	var after := _settlement_probe(main, player_index, district_index)
	return {"bought": bought, "before": before, "after": after}


func _settlement_probe(main: Control, player_index: int, district_index: int) -> Dictionary:
	var player := _settlement_player(main, player_index)
	var runtime := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var window: Dictionary = runtime.call("district_purchase_window", player_index) if runtime != null else {}
	var pending_variant: Variant = main.get("pending_discard_purchase")
	var pending: Dictionary = pending_variant if pending_variant is Dictionary else {}
	var districts: Array = main.get("districts") as Array
	var choices: Array = []
	if district_index >= 0 and district_index < districts.size() and districts[district_index] is Dictionary:
		choices = ((districts[district_index] as Dictionary).get("card_choices", []) as Array).duplicate(true)
	var ledger: Array = player.get("economic_ledger", []) if player.get("economic_ledger", []) is Array else []
	var card_spend_count := 0
	for entry_variant: Variant in ledger:
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("kind", "")) == "卡牌支出":
			card_spend_count += 1
	var logs: Array = main.get("log_lines") as Array
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	return {
		"cash": int(player.get("cash", 0)),
		"hand_count": int(main.call("_player_counted_hand_size", player)),
		"slot_count": _dictionary_slot_count(slots),
		"slots": _anonymized_slot_fingerprints(main, slots),
		"purchase_count": int(player.get("card_purchase_count", 0)),
		"total_card_spend": int(player.get("total_card_spend", 0)),
		"ledger_count": ledger.size(),
		"ledger_card_spend_count": card_spend_count,
		"log_count": logs.size(),
		"window_state": str(window.get("state", "")),
		"window_remaining": float(window.get("remaining_seconds", 0.0)),
		"pending_discard": not pending.is_empty() and int(pending.get("player_index", -1)) == player_index,
		"supply_fingerprint": JSON.stringify(choices).sha256_text().substr(0, 16),
		"supply_revision": str(window.get("supply_revision", "")),
	}


func _dictionary_slot_count(slots: Array) -> int:
	var count := 0
	for slot_variant: Variant in slots:
		if slot_variant is Dictionary:
			count += 1
	return count


func _anonymized_slot_fingerprints(main: Control, slots: Array) -> Array:
	var result: Array = []
	for slot_variant: Variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var slot: Dictionary = slot_variant
		var card_name := str(slot.get("name", ""))
		var family := _card_family_for(main, card_name)
		result.append({
			"family_code": family.sha256_text().substr(0, 8),
			"rank": _card_rank_for(main, card_name),
			"queued": bool(slot.get("queued_for_resolution", false)),
			"locked": float(slot.get("lock_left", 0.0)) > 0.0,
		})
	return result


func _slot_change_kind(before: Dictionary, after: Dictionary) -> String:
	var before_slots: Array = before.get("slots", []) if before.get("slots", []) is Array else []
	var after_slots: Array = after.get("slots", []) if after.get("slots", []) is Array else []
	if before_slots == after_slots:
		return "none"
	if int(after.get("slot_count", 0)) > int(before.get("slot_count", 0)):
		return "added"
	if before_slots.size() == after_slots.size():
		var family_changed := false
		var rank_increased := false
		for index in range(before_slots.size()):
			var before_slot: Dictionary = before_slots[index] if before_slots[index] is Dictionary else {}
			var after_slot: Dictionary = after_slots[index] if after_slots[index] is Dictionary else {}
			if str(before_slot.get("family_code", "")) != str(after_slot.get("family_code", "")):
				family_changed = true
			elif int(after_slot.get("rank", 0)) > int(before_slot.get("rank", 0)):
				rank_increased = true
		if rank_increased and not family_changed:
			return "upgrade"
		if family_changed:
			return "discard_replace"
	return "changed"


func _no_settlement_mutation(before: Dictionary, after: Dictionary) -> bool:
	return int(after.get("cash", 0)) == int(before.get("cash", -1)) and int(after.get("hand_count", 0)) == int(before.get("hand_count", -1)) and int(after.get("purchase_count", 0)) == int(before.get("purchase_count", -1)) and int(after.get("total_card_spend", 0)) == int(before.get("total_card_spend", -1)) and _slot_change_kind(before, after) == "none"


func _public_delta_is_private_safe(main: Control, start_index: int, private_values: Array) -> bool:
	var logs: Array = main.get("log_lines") as Array
	for index in range(maxi(0, start_index), logs.size()):
		var line := str(logs[index])
		for value_variant: Variant in private_values:
			var private_value := str(value_variant)
			if not private_value.is_empty() and line.contains(private_value):
				return false
	return true


func _characterization_result(before: Dictionary, after: Dictionary, aligned: bool, notes: String, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"observed": not before.is_empty() and not after.is_empty(),
		"contract_aligned": aligned,
		"mutation_expected": str(extra.get("mutation_expected", "none")),
		"cash_delta": int(after.get("cash", 0)) - int(before.get("cash", 0)),
		"hand_count_delta": int(after.get("hand_count", 0)) - int(before.get("hand_count", 0)),
		"slot_change_kind": _slot_change_kind(before, after) if not before.is_empty() and not after.is_empty() else "none",
		"purchase_count_delta": int(after.get("purchase_count", 0)) - int(before.get("purchase_count", 0)),
		"ledger_delta": int(after.get("ledger_count", 0)) - int(before.get("ledger_count", 0)),
		"public_event_delta": int(after.get("log_count", 0)) - int(before.get("log_count", 0)),
		"private_event_delta": int(after.get("ledger_count", 0)) - int(before.get("ledger_count", 0)),
		"window_state_before": str(before.get("window_state", "")),
		"window_state_after": str(after.get("window_state", "")),
		"discard_checked": bool(extra.get("discard_checked", false)),
		"upgrade_checked": bool(extra.get("upgrade_checked", false)),
		"privacy_checked": bool(extra.get("privacy_checked", false)),
		"legacy_route_status": str(extra.get("legacy_route_status", "not_applicable")),
		"risk": str(extra.get("risk", "" if aligned else "observed behavior does not match the v0.4 transaction contract")),
		"notes": notes,
	}
	return result


func _characterize_legacy_settlement_routes() -> Dictionary:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var retired_names := ["_upgrade_skill_slot", "_replace_skill_slot", "_can_upgrade_skill_slot", "_can_replace_skill_slot"]
	var retired := true
	for function_name_variant: Variant in retired_names:
		retired = retired and not main_source.contains("func %s(" % str(function_name_variant))
	var unified_route := main_source.contains("func _buy_card_for_player_from_district(") and main_source.contains("func _acquire_card_for_player(")
	var result := _characterization_result({"window_state": "source_audit"}, {"window_state": "source_audit"}, retired and unified_route, "zero-caller direct upgrade/replace routes are removed; the unified purchase path remains", {"legacy_route_status": "removed_dead_routes" if retired else "dead_route_still_present", "mutation_expected": "source_deletion"})
	result["observed"] = true
	return result


func _drawer_fixture() -> Dictionary:
	return {
		"title": "区域牌架｜轨道电梯",
		"rule_strip": "市场牌架｜悬停看｜双击买",
		"rule_tooltip": "测试 fixture：购买资格和价格在开窗时锁定。",
		"purchase_window": {
			"active": true,
			"state": "active",
			"remaining_seconds": 9.5,
			"duration_seconds": 12.0,
			"access_kind": "landed",
			"locked_price_multiplier": 0.8,
			"channel_discount_applied": false,
			"requires_reselection": false,
		},
		"header_chips": [
			{"text": "牌架 2", "accent": "#bfdbfe", "fg": "#bfdbfe", "bg": "#0f172a", "tooltip": "两张公开供牌"},
			{"text": "可购买", "accent": "#4ade80", "fg": "#bbf7d0", "bg": "#064e3b", "tooltip": "怪兽落地区"},
			{"text": "价格已锁", "accent": "#fde68a", "fg": "#fde68a", "bg": "#713f12", "tooltip": "开窗价格"},
		],
		"market_status": [
			{"text": "可买 1", "accent": "#4ade80", "active": true, "tooltip": "现在可买"},
			{"text": "仅看 1", "accent": "#93c5fd", "active": true, "tooltip": "只读供牌"},
		],
		"cards": [
			_drawer_market_card_fixture("轨道融资1", "轨道融资", true, true, "#38bdf8", "可购买"),
			_drawer_market_card_fixture("城市融资1", "城市融资", false, false, "#c084fc", "仅浏览"),
		],
		"selected_card_name": "轨道融资1",
		"preview": _drawer_preview_fixture(true),
		"empty_state": {
			"market_text": "当前区域暂无卡牌。",
			"preview_text": "选择一张区域供牌查看详情。",
		},
		"privacy_hint": "购买状态只对当前玩家显示；不会公开手牌、弃牌或渠道来源。",
		"privacy_tooltip": "fixture contains public supply plus viewer-safe purchase state only",
	}


func _drawer_market_card_fixture(card_name: String, display_name: String, selected: bool, actionable: bool, accent: String, state_text: String) -> Dictionary:
	return {
		"card_name": card_name,
		"display_name": display_name,
		"selected": selected,
		"actionable": actionable,
		"title": "%s%s" % ["> " if selected else "", display_name],
		"title_tooltip": display_name,
		"rank": "I",
		"rank_number": 1,
		"rank_tooltip": "一级发展牌",
		"kind": "economic",
		"card_stats": "融资 / GDP",
		"card_art_stats": "融资 / GDP",
		"chips": [{"text": "¥120", "accent": "#fde68a", "fg": "#fde68a", "bg": "#713f12", "tooltip": "锁定价格"}],
		"micro_chips": [{"text": "免门槛", "fg": "#cbd5e1", "bg": "#334155", "tooltip": "打出无前置门槛"}],
		"route": "城市化 / 现金流",
		"route_tooltip": "首局经济路线",
		"facts": "建立公开经济反馈",
		"facts_tooltip": "fixture fact",
		"state_text": state_text,
		"state_tooltip": "fixture purchase state",
		"accent": accent,
		"theme_color": accent,
		"tooltip": "%s fixture" % display_name,
	}


func _drawer_preview_fixture(buy_enabled: bool) -> Dictionary:
	return {
		"card_name": "轨道融资1",
		"title": "轨道融资｜经济",
		"title_tooltip": "轨道融资首局教学牌",
		"chips": [{"text": "可购买", "accent": "#4ade80", "fg": "#bbf7d0", "bg": "#064e3b", "tooltip": "fixture"}],
		"micro_chips": [{"text": "免门槛", "fg": "#cbd5e1", "bg": "#334155", "tooltip": "fixture"}],
		"decision_chips": [{"text": "用途:城市化", "fg": "#dbeafe", "bg": "#1e3a8a", "tooltip": "fixture"}],
		"verdicts": [{"text": "可购买", "accent": "#4ade80", "active": buy_enabled, "tooltip": "fixture"}],
		"scan_sections": [
			{"title": "用途", "body": "建立现金流", "accent": "#38bdf8", "tooltip": "fixture"},
			{"title": "买入", "body": "¥120", "accent": "#4ade80", "tooltip": "fixture"},
			{"title": "打出", "body": "免门槛", "accent": "#86efac", "tooltip": "fixture"},
			{"title": "目标", "body": "当前选区", "accent": "#c4b5fd", "tooltip": "fixture"},
		],
		"body": "用公开融资建立第一条城市经济反馈。",
		"facts": "首局教学 fixture",
		"status_text": "可购买｜¥120",
		"status_tooltip": "fixture",
		"buy_text": "购买 ¥120",
		"buy_enabled": buy_enabled,
		"buy_tooltip": "fixture buy",
		"card_face": {
			"name": "轨道融资",
			"cost": "$120",
			"effect": "建立第一条正向现金流。",
			"use_case": "城市化",
			"table_use": "城市化",
			"type": "经济 / 融资",
			"rank": "I",
			"kind": "economic",
			"card_kind": "economic",
			"card_stats": "融资 / GDP",
			"presentation": "inspector_full",
			"accent": "#38bdf8",
			"minimum_width": 174.0,
			"minimum_height": 218.0,
		},
		"accent": "#4ade80",
		"theme_color": "#38bdf8",
		"tooltip": "fixture preview",
	}


func _snapshot_source_fixture() -> Dictionary:
	return {
		"district_index": 2,
		"district_name": "轨道电梯",
		"player_index": 0,
		"selected_card_name": "轨道融资1",
		"access_kind": "landed",
		"access_text": "怪兽位于当前区域，购买价格按锁定窗口计算。",
		"can_buy": true,
		"player_cash": 900,
		"counted_hand_size": 3,
		"hand_limit": 10,
		"local_product_names": ["轨道盆栽", "重力陶瓷"],
		"purchase_window": {
			"active": true,
			"state": "active",
			"remaining_seconds": 9.5,
			"duration_seconds": 12.0,
			"access_kind": "landed",
			"locked_price_multiplier": 0.8,
			"channel_discount_applied": false,
			"requires_reselection": false,
		},
		"cards": [
			_snapshot_card_source("轨道融资1", "轨道融资", true, true, false, "可购买", "#22c55eff", "#38bdf8ff"),
			_snapshot_card_source("城市融资1", "城市融资", false, false, true, "仅浏览", "#94a3b8ff", "#c084fcff"),
		],
	}


func _snapshot_card_source(card_name: String, display_name: String, selected: bool, actionable: bool, is_upgrade: bool, state_label: String, state_accent: String, theme_color: String) -> Dictionary:
	return {
		"card_name": card_name,
		"display_name": display_name,
		"icon": "◇",
		"rank": 1,
		"rank_label": "I",
		"kind": "economic",
		"persistent": false,
		"is_upgrade": is_upgrade,
		"selected": selected,
		"strategy_route": "城市化 / 现金流",
		"purchase_state": {
			"label": state_label,
			"detail": "fixture purchase state",
			"actionable": actionable,
			"requires_discard": false,
			"price": 120,
			"accent": state_accent,
		},
		"price": 120,
		"play_share_required": 0,
		"play_requirement_text": "打出无前置门槛。",
		"play_cash_cost": 0,
		"target_kind": "current_district",
		"effect_text": "用公开融资建立第一条城市经济反馈。",
		"key_rule_facts": ["建立公开经济反馈", "城市化份额"],
		"art_stats": "融资 / GDP",
		"theme_color": theme_color,
		"detail_tooltip": "%s fixture" % display_name,
		"primary_type_label": "经济",
		"card_face_facts": {
			"quick_effect": "建立第一条正向现金流。",
			"use_case": "城市化",
			"route_text": "经济 / 融资",
			"level_text": "I",
		},
	}


func _snapshot_service() -> Node:
	return coordinator.get_node_or_null("DistrictSupplySnapshotService") if coordinator != null else null


func _compose_snapshot_fixture() -> Dictionary:
	var service := _snapshot_service()
	var value: Variant = service.call("compose", _snapshot_source_fixture()) if service != null else {}
	return value as Dictionary if value is Dictionary else {}


func _entries_contain_text(entries: Array, expected: String) -> bool:
	for entry_variant: Variant in entries:
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("text", "")).contains(expected):
			return true
	return false


func _all_color_fields_are_hex(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in value.keys():
			var key := str(key_variant)
			var child: Variant = value.get(key_variant)
			if key in ["accent", "fg", "bg", "theme_color", "title_color"] and (not (child is String) or not str(child).begins_with("#")):
				return false
			if not _all_color_fields_are_hex(child):
				return false
	elif value is Array:
		for child_variant: Variant in value:
			if not _all_color_fields_are_hex(child_variant):
				return false
	return true


func _reset_drawer_fixture() -> void:
	_drawer_actions.clear()
	if drawer_preview == null:
		return
	drawer_preview.visible = true
	if drawer_preview.has_method("set_supply"):
		drawer_preview.call("set_supply", _drawer_fixture())


func _drawer_market_cards() -> Array[Control]:
	var cards: Array[Control] = []
	if drawer_preview == null:
		return cards
	for child_variant: Variant in drawer_preview.find_children("*", "", true, false):
		if child_variant is Control and (child_variant as Control).has_method("get_card_name"):
			cards.append(child_variant as Control)
	return cards


func _on_drawer_action_requested(action_id: String, payload: Dictionary) -> void:
	_drawer_actions.append({"action_id": action_id, "payload": payload.duplicate(true)})


func _drawer_action_matches(index: int, action_id: String, card_name: String, source: String) -> bool:
	if index < 0 or index >= _drawer_actions.size():
		return false
	var entry: Dictionary = _drawer_actions[index] if _drawer_actions[index] is Dictionary else {}
	var payload: Dictionary = entry.get("payload", {}) if entry.get("payload", {}) is Dictionary else {}
	return str(entry.get("action_id", "")) == action_id and str(payload.get("card_name", "")) == card_name and str(payload.get("source", "")) == source


func _activate_focused_button(button: Button) -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		focus_owner.release_focus()
	if button == null:
		return
	button.grab_focus()
	var press := InputEventAction.new()
	press.action = "ui_accept"
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release := InputEventAction.new()
	release.action = "ui_accept"
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


func _exercise_real_main_drawer_route() -> Dictionary:
	if _real_main == null:
		return {}
	var districts: Array = _real_main.get("districts") as Array
	var district_index := -1
	for index in range(districts.size()):
		var district: Dictionary = districts[index] if districts[index] is Dictionary else {}
		var choices: Array = district.get("card_choices", []) if district.get("card_choices", []) is Array else []
		if not choices.is_empty():
			district_index = index
			break
	if district_index < 0:
		return {"reason": "no district supply"}
	_real_main.set("selected_player", 0)
	_real_main.call("_open_district_supply_from_map", district_index)
	await get_tree().process_frame
	await get_tree().process_frame
	var drawer := _real_main.find_child("DistrictSupplySideDrawerOverlay", true, false) as Control
	var debug: Dictionary = drawer.call("debug_snapshot") if drawer != null and drawer.has_method("debug_snapshot") else {}
	var opened := drawer != null and drawer.visible and int(_real_main.get("district_supply_open_district")) == district_index
	var rendered := int(debug.get("rendered_card_count", 0)) > 0 and drawer.find_child("DistrictSupplySelectedPreview", true, false) != null
	var pure := _is_data_only(debug) and not _contains_private_tokens(JSON.stringify(debug))
	if drawer != null and drawer.has_signal("supply_action_requested"):
		drawer.emit_signal("supply_action_requested", "district_supply_close", {})
	await get_tree().process_frame
	var closed := drawer != null and not drawer.visible and int(_real_main.get("district_supply_open_district")) == -1
	return {"opened": opened, "rendered": rendered, "closed": closed, "pure": pure, "district_index": district_index, "card_count": int(debug.get("rendered_card_count", 0))}


func _exercise_real_main_snapshot_service_route() -> Dictionary:
	if _real_main == null:
		return {}
	var districts: Array = _real_main.get("districts") as Array
	var district_index := -1
	for index in range(districts.size()):
		var district: Dictionary = districts[index] if districts[index] is Dictionary else {}
		if not (district.get("card_choices", []) as Array).is_empty():
			district_index = index
			break
	if district_index < 0:
		return {"reason": "no district supply"}
	_real_main.set("selected_player", 0)
	_real_main.call("_open_district_supply_from_map", district_index)
	await get_tree().process_frame
	await get_tree().process_frame
	var runtime := _real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var service := runtime.get_node_or_null("DistrictSupplySnapshotService") if runtime != null else null
	var source_variant: Variant = _real_main.call("_district_supply_snapshot_source", district_index, 0)
	var source: Dictionary = source_variant if source_variant is Dictionary else {}
	var output_variant: Variant = runtime.call("compose_district_supply_snapshot", source) if runtime != null else {}
	var output: Dictionary = output_variant if output_variant is Dictionary else {}
	var drawer := _real_main.find_child("DistrictSupplySideDrawerOverlay", true, false) as Control
	var drawer_debug: Dictionary = drawer.call("debug_snapshot") if drawer != null and drawer.has_method("debug_snapshot") else {}
	var result := {
		"service_found": service != null and service.scene_file_path == SNAPSHOT_SERVICE_SCENE_PATH,
		"source_pure": _is_data_only(source) and not _contains_private_tokens(JSON.stringify(source)),
		"output_pure": _is_data_only(output) and not _contains_private_tokens(JSON.stringify(output)),
		"drawer_rendered": drawer != null and drawer.visible and int(drawer_debug.get("rendered_card_count", 0)) > 0,
		"source_count": int((source.get("cards", []) as Array).size()),
		"output_count": int((output.get("cards", []) as Array).size()),
	}
	if drawer != null and drawer.has_signal("supply_action_requested"):
		drawer.emit_signal("supply_action_requested", "district_supply_close", {})
	await get_tree().process_frame
	return result


func _has_nodes(root: Node, node_names: Array) -> bool:
	if root == null:
		return false
	for node_name_variant: Variant in node_names:
		if root.find_child(str(node_name_variant), true, false) == null:
			return false
	return true


func _contains_private_tokens(encoded: String) -> bool:
	for token in ["hidden_owner", "owner_player_index", "source_monster_uid", "private_target", "private_discard", "private_plan"]:
		if encoded.contains(token):
			return true
	return false


func _configure_runtime() -> void:
	if coordinator != null and ruleset_bridge != null:
		coordinator.call("configure", ruleset_bridge.call("debug_snapshot"))


func _reset_controller() -> void:
	var controller := _controller_node()
	if controller != null:
		controller.call("reset_state")
		controller.call("configure", ruleset_bridge.call("timing_rules"))


func _controller_node() -> Node:
	return coordinator.get_node_or_null("DistrictPurchaseRuntimeController") if coordinator != null else null


func _qualification(access_kind: String, eligible: bool, source_bound: bool = false) -> Dictionary:
	return {
		"access_kind": access_kind,
		"eligible": eligible,
		"opened_at": 10.0,
		"source_kind": "monster" if access_kind != "global" else "ability",
		"source_bound_to_player": source_bound,
		"channel_discount_multiplier": 0.8 if source_bound else 1.0,
		"extended_multiplier": 1.10,
		"global_multiplier": 1.35,
		"price_floor_multiplier": 0.5,
		"supply_revision": "supply-a",
	}


func _prepare_real_main() -> Control:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	var main := packed.instantiate() as Control
	if main == null:
		return null
	main.visible = false
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.call("_new_game")
	await get_tree().process_frame
	main.set_process(false)
	return main


func _exercise_real_main_purchase(player_index: int, anonymous: bool) -> Dictionary:
	if _real_main == null:
		return {}
	var players: Array = (_real_main.get("players") as Array).duplicate(true)
	var districts: Array = _real_main.get("districts") as Array
	if player_index < 0 or player_index >= players.size() or districts.is_empty():
		return {}
	var district_index := 0
	var choices: Array = (districts[district_index] as Dictionary).get("card_choices", [])
	if choices.is_empty():
		return {}
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
	player["cash"] = 999999
	players[player_index] = player
	_real_main.set("players", players)
	var monsters := _monster_controller_for(_real_main)
	var monster_variant: Variant = monsters.call("_make_auto_monster", 0, 0, district_index, player_index, 1) if monsters != null else {}
	var monster: Dictionary = monster_variant if monster_variant is Dictionary else {}
	if monsters != null:
		monsters.call("replace_runtime_state", {"auto_monsters": [monster]})
	_real_main.call("_open_district_card_purchase_window", district_index, player_index)
	var card_id := str(choices[0])
	var runtime := _real_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var window: Dictionary = runtime.call("district_purchase_window", player_index) if runtime != null else {}
	var supply_revision := str((districts[district_index] as Dictionary).get("card_choices", []))
	var authorization: Dictionary = runtime.call("authorize_district_purchase", {"player_index": player_index, "district_index": district_index, "card_id": card_id, "supply_revision": supply_revision}) if runtime != null else {}
	var can_buy := bool(_real_main.call("_can_buy_card_from_district", district_index, player_index))
	var has_card := bool(_real_main.call("_district_has_card", district_index, card_id))
	var bought := bool(_real_main.call("_buy_card_for_player_from_district", player_index, district_index, card_id, anonymous, true, -1))
	var active := runtime != null and bool(runtime.call("district_purchase_window_active", player_index, district_index))
	var log_lines: Array = _real_main.get("log_lines") as Array
	return {
		"bought": bought,
		"controller_active": active,
		"window": window,
		"authorization": authorization,
		"can_buy": can_buy,
		"has_card": has_card,
		"card_id": card_id,
		"last_log": str(log_lines[-1]) if not log_lines.is_empty() else "",
	}


func _release_real_main() -> void:
	if _real_main != null and is_instance_valid(_real_main):
		_real_main.queue_free()
	_real_main = null


func _record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var controller := _controller_node()
	var debug: Dictionary = controller.call("debug_snapshot") if controller != null else {}
	var window: Dictionary = controller.call("private_ui_snapshot", 0) if controller != null else {}
	return {
		"case_id": case_id,
		"window_state": str(window.get("state", "")),
		"remaining_seconds": float(window.get("remaining_seconds", 0.0)),
		"access_kind": str(window.get("access_kind", "none")),
		"locked_multiplier": float(window.get("locked_price_multiplier", 1.0)),
		"timing_checked": bool(flags.get("timing_checked", false)),
		"expiry_checked": bool(flags.get("expiry_checked", false)),
		"lock_checked": bool(flags.get("lock_checked", false)),
		"price_checked": bool(flags.get("price_checked", false)),
		"supply_checked": bool(flags.get("supply_checked", false)),
		"discard_checked": bool(flags.get("discard_checked", false)),
		"main_delegation_checked": bool(flags.get("main_delegation_checked", false)),
		"save_compatibility_checked": bool(flags.get("save_compatibility_checked", false)),
		"privacy_checked": bool(flags.get("privacy_checked", false)),
		"pure_data_checked": bool(flags.get("pure_data_checked", false)),
		"drawer_checked": bool(flags.get("drawer_checked", false)),
		"action_route_checked": bool(flags.get("action_route_checked", false)),
		"disabled_checked": bool(flags.get("disabled_checked", false)),
		"focus_checked": bool(flags.get("focus_checked", false)),
		"snapshot_checked": bool(flags.get("snapshot_checked", false)),
		"legacy_deletion_checked": bool(flags.get("legacy_deletion_checked", false)),
		"snapshot_service_checked": bool(flags.get("snapshot_service_checked", false)),
		"source_contract_checked": bool(flags.get("source_contract_checked", false)),
		"format_parity_checked": bool(flags.get("format_parity_checked", false)),
		"authority_boundary_checked": bool(flags.get("authority_boundary_checked", false)),
		"service_owner_checked": bool(flags.get("service_owner_checked", false)),
		"plan_checked": bool(flags.get("plan_checked", false)),
		"commit_checked": bool(flags.get("commit_checked", false)),
		"main_adapter_checked": bool(flags.get("main_adapter_checked", false)),
		"legacy_formula_absent": bool(flags.get("legacy_formula_absent", false)),
		"window_owner_unchanged": bool(flags.get("window_owner_unchanged", false)),
		"event_intents_checked": bool(flags.get("event_intents_checked", false)),
		"observed": bool(flags.get("observed", false)),
		"contract_aligned": bool(flags.get("contract_aligned", false)),
		"mutation_expected": str(flags.get("mutation_expected", "none")),
		"cash_delta": int(flags.get("cash_delta", 0)),
		"hand_count_delta": int(flags.get("hand_count_delta", 0)),
		"slot_change_kind": str(flags.get("slot_change_kind", "none")),
		"purchase_count_delta": int(flags.get("purchase_count_delta", 0)),
		"ledger_delta": int(flags.get("ledger_delta", 0)),
		"public_event_delta": int(flags.get("public_event_delta", 0)),
		"private_event_delta": int(flags.get("private_event_delta", 0)),
		"window_state_before": str(flags.get("window_state_before", "")),
		"window_state_after": str(flags.get("window_state_after", "")),
		"upgrade_checked": bool(flags.get("upgrade_checked", false)),
		"legacy_route_status": str(flags.get("legacy_route_status", "not_applicable")),
		"risk": str(flags.get("risk", "")),
		"controller_ready": bool(debug.get("controller_ready", false)),
		"passed": passed,
		"notes": notes,
	}


func _passed_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _ownership_passed_count() -> int:
	var count := 0
	for record_variant: Variant in _records:
		if record_variant is Dictionary:
			var record: Dictionary = record_variant
			if ownership_cases().has(str(record.get("case_id", ""))) and bool(record.get("passed", false)):
				count += 1
	return count


func _characterization_observed_count() -> int:
	var count := 0
	for record_variant: Variant in _records:
		if record_variant is Dictionary:
			var record: Dictionary = record_variant
			if settlement_characterization_cases().has(str(record.get("case_id", ""))) and bool(record.get("observed", false)):
				count += 1
	return count


func _characterization_aligned_count() -> int:
	var count := 0
	for record_variant: Variant in _records:
		if record_variant is Dictionary:
			var record: Dictionary = record_variant
			if settlement_characterization_cases().has(str(record.get("case_id", ""))) and bool(record.get("contract_aligned", false)):
				count += 1
	return count


func _settlement_cutover_passed_count() -> int:
	var count := 0
	for record_variant: Variant in _records:
		if record_variant is Dictionary:
			var record: Dictionary = record_variant
			if settlement_service_cutover_cases().has(str(record.get("case_id", ""))) and bool(record.get("passed", false)):
				count += 1
	return count


func _update_ui(manifest: Dictionary) -> void:
	var passed := int(manifest.get("passed_count", 0))
	var total := int(manifest.get("record_count", 0))
	summary_label.text = "District purchase: %d/%d ownership | %d/%d observed | %d/%d aligned | %d/%d service" % [int(manifest.get("ownership_passed_count", 0)), OWNERSHIP_CASE_COUNT, int(manifest.get("characterization_observed_count", 0)), CHARACTERIZATION_CASE_COUNT, int(manifest.get("characterization_aligned_count", 0)), CHARACTERIZATION_CASE_COUNT, int(manifest.get("settlement_cutover_passed_count", 0)), SETTLEMENT_CUTOVER_CASE_COUNT]
	status_label.text = "PASS" if passed == total else "FAIL"
	status_label.add_theme_color_override("font_color", Color("#4ade80") if passed == total else Color("#fb7185"))
	ownership_text.text = "[b]DistrictPurchaseRuntimeController[/b]\n• 12-second qualification, locked context, expiry, and pending discard window\n\n[b]DistrictPurchaseSettlementRuntimeService[/b]\n• pure planning, upgrade-first inventory policy, atomic cash/card/counter/ledger commit\n• player, AI, Coach, and resumed discard share one settlement route\n\n[b]DistrictSupplySnapshotService + Drawer[/b]\n• viewer-safe formatting and scene-owned interaction\n\n[b]Sprint 29 compatibility boundary[/b]\n• main.gd is a world-fact and post-commit adapter\n• characterization remains separately reported as observed and aligned"


func _markdown_report(manifest: Dictionary) -> String:
	var lines := [
		"# District Purchase Settlement Runtime Cutover QA",
		"",
		"- Ruleset: `v0.4`",
		"- Purchase window: `12 seconds`",
		"- Passed: **%d/%d**" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"- Ownership gates: **%d/%d**" % [int(manifest.get("ownership_passed_count", 0)), OWNERSHIP_CASE_COUNT],
		"- Characterization observed: **%d/%d**" % [int(manifest.get("characterization_observed_count", 0)), CHARACTERIZATION_CASE_COUNT],
		"- Characterization aligned: **%d/%d**" % [int(manifest.get("characterization_aligned_count", 0)), CHARACTERIZATION_CASE_COUNT],
		"- Settlement service cutover: **%d/%d**" % [int(manifest.get("settlement_cutover_passed_count", 0)), SETTLEMENT_CUTOVER_CASE_COUNT],
		"- Output: `%s`" % OUTPUT_DIR,
		"",
		"| Case | Observed | Aligned | Cash | Hand | Slot change | Window | Risk | Passed | Notes |",
		"| --- | --- | --- | ---: | ---: | --- | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %s | %d | %d | %s | %s → %s | %s | %s | %s |" % [str(record.get("case_id", "")), "yes" if bool(record.get("observed", false)) else "-", "yes" if bool(record.get("contract_aligned", false)) else "-", int(record.get("cash_delta", 0)), int(record.get("hand_count_delta", 0)), str(record.get("slot_change_kind", "none")), str(record.get("window_state_before", record.get("window_state", ""))), str(record.get("window_state_after", record.get("window_state", ""))), str(record.get("risk", "")).replace("|", "/"), "yes" if bool(record.get("passed", false)) else "no", str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines) + "\n"


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for file_name: String in ["manifest.json", "report.md"]:
		var path: String = OUTPUT_DIR + file_name
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(ProjectSettings.globalize_path(SCREENSHOT_PATH))


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not _is_data_only(key) or not _is_data_only(value[key]):
				return false
		return true
	return false
