extends RefCounted
class_name GlobalUiNavigationCharacterizationRegistry

const OUTPUT_DIR := "user://space_syndicate_design_qa/global_ui_navigation_characterization/"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/global_ui_navigation_characterization_sprint_67.png"


static func surface_registry() -> Array:
	return [
		_surface("gameplay", "gameplay", "", "pause_only", "", "runtime_boot", 0),
		_surface("pause_menu", "menu", "gameplay", "dismiss", "", "pause_open", 0),
		_surface("main_menu_root", "menu_root", "", "confirm_exit", "", "boot", 0),
		_surface("menu_secondary_page", "menu_page", "main_menu_root", "pop", "", "menu_action", 0),
		_surface("campaign_page", "menu_page", "main_menu_root", "pop", "", "campaign_action", 0),
		_surface("scenario_page", "menu_page", "pause_menu", "pop", "", "scenario_action", 0),
		_surface("codex_atlas", "codex_page", "menu_secondary_page", "pop", "", "codex_open", 0),
		_surface("codex_detail", "codex_detail", "codex_atlas", "pop", "", "codex_entry_open", 0),
		_surface("fullscreen_map", "fullscreen_surface", "gameplay", "dismiss", "", "open_fullscreen_map", 0),
		_surface("side_drawer", "drawer", "gameplay", "dismiss", "", "drawer_open", 0),
		_surface("district_supply", "drawer", "gameplay", "dismiss", "", "district_supply_open", 0),
		_surface("confirmation_modal", "modal", "", "dismiss", "", "confirm_open", 0),
		_surface("temporary_decision", "forced_modal", "", "forced_action_only", "", "temporary_decision_open", 0),
		_surface("exit_confirmation", "modal", "main_menu_root", "explicit_choice", "", "root_back", 0),
		_surface("route_placement_preview", "future_mode", "gameplay", "cancel_then_exit", "", "future_route_mode", 0),
	]


static func characterization_cases() -> Array:
	return [
		_case("navigation_call_graph_complete", "gameplay", "gameplay", "audit", "main_scattered_routes", "global_navigation_controller_route", false, "Global Back ownership is split across main.gd, MenuOverlay, OverlayLayer, drawers, and the Codex-local controller.", {"risk": "high"}),
		_case("current_escape_precedence_recorded", "gameplay", "gameplay", "back", "fullscreen_map_then_menu_then_pause", "modal_forced_drawer_page_map_pause_root", false, "The current key branch only checks fullscreen map, menu visibility, then pause.", {"risk": "high"}),
		_case("gameplay_escape_opens_pause", "gameplay", "gameplay", "back", "open_pause_menu", "open_pause_menu", true, "Back on the bare table opens the pause menu.", {"stack_depth_before": 1, "stack_depth_after": 2, "pause_state_after": true}),
		_case("pause_escape_returns_game", "gameplay", "pause_menu", "back", "close_menu_resume_game", "close_menu_resume_game", true, "Back closes the pause menu and resumes the session.", {"stack_depth_before": 2, "stack_depth_after": 1, "pause_state_before": true}),
		_case("fullscreen_map_escape_closes_map_only", "gameplay", "fullscreen_map", "back", "close_fullscreen_map", "close_fullscreen_map", true, "Fullscreen map has the only explicit surface precedence above the menu.", {"stack_depth_before": 2, "stack_depth_after": 1}),
		_case("menu_root_escape_behavior", "main_menu_root", "main_menu_root", "back", "close_root_menu", "request_exit_confirmation", false, "Root Back currently hides the root menu instead of requesting exit confirmation.", {"risk": "high"}),
		_case("exit_requires_confirmation", "main_menu_root", "main_menu_root", "quit", "quit_immediately", "show_exit_confirmation", false, "The root quit action calls get_tree().quit() directly.", {"risk": "high"}),
		_case("confirm_modal_precedes_menu", "gameplay", "confirmation_modal", "back", "open_pause_keep_confirmation", "dismiss_confirmation", false, "The Esc branch does not inspect OverlayLayer's confirmation surface.", {"modal_precedence_checked": true, "risk": "high"}),
		_case("temporary_decision_not_bypassed", "gameplay", "temporary_decision", "back", "open_pause_keep_forced_decision", "block_back_keep_forced_decision", false, "Forced temporary decisions remain visible, but Back can still open pause behind them.", {"modal_precedence_checked": true, "risk": "high"}),
		_case("side_drawer_closes_before_pause", "gameplay", "side_drawer", "back", "open_pause_keep_side_drawer", "close_side_drawer", false, "The generic side drawer is not represented in the Esc branch.", {"modal_precedence_checked": true, "risk": "medium"}),
		_case("card_detail_closes_before_parent", "menu_secondary_page", "codex_detail", "back", "close_codex_detail", "close_codex_detail", true, "Codex-local Back closes detail before leaving the catalog.", {"stack_depth_before": 3, "stack_depth_after": 2}),
		_case("district_supply_drawer_closes_before_pause", "gameplay", "district_supply", "back", "open_pause_keep_district_supply", "close_district_supply", false, "District supply has a close action, but global Back does not route to it.", {"modal_precedence_checked": true, "risk": "high"}),
		_case("nested_codex_detail_returns_atlas", "codex_atlas", "codex_detail", "catalog_back", "close_codex_detail", "close_codex_detail", true, "Card, monster, and product detail state returns to its atlas.", {"stack_depth_before": 3, "stack_depth_after": 2}),
		_case("codex_atlas_returns_compendium", "menu_secondary_page", "codex_atlas", "catalog_back", "open_compendium", "open_compendium", true, "Compendium-origin catalogs return to the Compendium page.", {"stack_depth_before": 2, "stack_depth_after": 1}),
		_case("codex_from_intel_returns_intel", "menu_secondary_page", "codex_atlas", "catalog_back", "open_intel_dossier", "open_intel_dossier", true, "Intel-origin catalogs preserve their local return target."),
		_case("codex_from_economy_returns_economy", "menu_secondary_page", "codex_atlas", "catalog_back", "open_economy_overview", "open_economy_overview", true, "Economy-origin catalogs preserve their local return target."),
		_case("codex_from_standings_returns_standings", "menu_secondary_page", "codex_atlas", "catalog_back", "open_standings", "open_standings", true, "Standings-origin catalogs preserve their local return target."),
		_case("codex_from_game_returns_game", "gameplay", "codex_atlas", "catalog_back", "close_menu_resume_game", "close_menu_resume_game", true, "Game-origin catalogs return directly to the table."),
		_case("campaign_briefing_back", "campaign_page", "campaign_page", "campaign_menu", "open_campaign_menu", "open_campaign_menu", true, "Campaign briefing exposes an explicit stable action back to the campaign map."),
		_case("campaign_settings_back", "campaign_page", "menu_secondary_page", "campaign_settings_back", "open_campaign_menu", "open_campaign_menu", true, "Campaign settings has a stable explicit parent action."),
		_case("campaign_reward_recap_back", "campaign_page", "menu_secondary_page", "campaign_reward_or_menu", "open_reward_or_campaign_menu", "open_reward_or_campaign_menu", true, "Reward and recap panels expose explicit parent actions instead of hidden state mutation."),
		_case("scenario_settings_back", "scenario_page", "menu_secondary_page", "scenario_settings_back", "open_scenario_browser", "open_scenario_browser", true, "Scenario settings has a stable explicit parent action."),
		_case("scenario_log_replay_back", "pause_menu", "scenario_page", "back", "open_main_menu", "open_pause_menu", false, "The generic MenuOverlay Back signal returns logs/replay to the root menu, not their pause opener.", {"risk": "medium"}),
		_case("new_game_setup_back", "main_menu_root", "menu_secondary_page", "back", "open_main_menu", "open_main_menu", true, "The setup page's current parent is the root lobby."),
		_case("focus_restores_to_opener", "gameplay", "menu_secondary_page", "back", "focus_untracked", "restore_exact_opener_focus", false, "No global surface entry stores the opener focus path.", {"focus_before": "opener_button", "focus_after": "untracked", "focus_restore_checked": true, "risk": "high"}),
		_case("freed_focus_uses_safe_fallback", "gameplay", "menu_secondary_page", "back", "no_global_focus_fallback", "focus_first_enabled_parent", false, "FocusTools exists locally, but no global Back route owns a freed-opener fallback.", {"focus_before": "freed_opener", "focus_after": "untracked", "focus_restore_checked": true, "risk": "medium"}),
		_case("keyboard_controller_pointer_parity", "gameplay", "gameplay", "back", "key_escape_only", "ui_cancel_shared_route", false, "Global Back is implemented as InputEventKey/KEY_ESCAPE and does not consume ui_cancel for controller parity.", {"risk": "high"}),
		_case("repeat_escape_debounced", "gameplay", "gameplay", "back_echo", "ignore_echo", "ignore_echo", true, "Echoed key events are rejected before routing."),
		_case("no_direct_quit_from_match", "gameplay", "gameplay", "back", "open_pause_menu", "open_pause_menu", true, "The match Back branch never calls the quit helper."),
		_case("save_navigation_legacy_parity", "menu_secondary_page", "codex_atlas", "save_load", "codex_legacy_keys_roundtrip", "codex_legacy_keys_roundtrip", true, "Codex-local v1 navigation persistence remains unchanged."),
		_case("pure_navigation_snapshot", "gameplay", "gameplay", "debug_snapshot", "global_snapshot_missing", "pure_global_surface_stack_snapshot", false, "Codex snapshots are pure data, but there is no global navigation snapshot yet.", {"pure_data_checked": true, "risk": "medium"}),
		_case("sprint68_deletion_candidates_complete", "gameplay", "gameplay", "audit", "deletion_list_recorded", "deletion_list_recorded", true, "The contract records the exact main.gd branches and adapters eligible for Sprint 68 replacement."),
	]


static func deletion_candidates() -> Array:
	return [
		{"symbol": "_unhandled_input", "scope": "Esc and menu Enter/Space branches only", "replacement": "global Back action router"},
		{"symbol": "_show_menu", "scope": "pause-state and surface-open ownership", "replacement": "surface push plus thin renderer adapter"},
		{"symbol": "_close_menu", "scope": "surface-close and pause restore ownership", "replacement": "surface pop plus thin renderer adapter"},
		{"symbol": "_back_from_catalog_menu", "scope": "cross-surface return routing only", "replacement": "global pop; Codex detail state remains Codex-owned"},
		{"symbol": "_catalog_back_button_text", "scope": "parent label selection", "replacement": "top surface parent descriptor"},
		{"symbol": "speed_before_menu", "scope": "menu pause restoration", "replacement": "global navigation session state"},
		{"symbol": "MenuOverlay.main_menu_requested", "scope": "generic Back semantics", "replacement": "stable global back request signal"},
		{"symbol": "direct page back branches", "scope": "campaign/scenario parent routing", "replacement": "surface stack pop receipts"},
	]


static func case_ids() -> Array:
	var result: Array = []
	for record_variant: Variant in characterization_cases():
		result.append(str((record_variant as Dictionary).get("case_id", "")))
	return result


static func _surface(surface_id: String, surface_kind: String, parent_surface_id: String, dismiss_policy: String, focus_restore_path: String, opened_by_action_id: String, context_revision: int) -> Dictionary:
	return {
		"surface_id": surface_id,
		"surface_kind": surface_kind,
		"parent_surface_id": parent_surface_id,
		"dismiss_policy": dismiss_policy,
		"focus_restore_path": focus_restore_path,
		"opened_by_action_id": opened_by_action_id,
		"context_revision": context_revision,
	}


static func _case(case_id: String, initial_surface: String, top_surface: String, requested_action: String, documented_current_action: String, expected_action: String, aligned: bool, notes: String, overrides: Dictionary = {}) -> Dictionary:
	var record := {
		"case_id": case_id,
		"initial_surface": initial_surface,
		"top_surface": top_surface,
		"requested_action": requested_action,
		"resolved_action": documented_current_action,
		"documented_current_action": documented_current_action,
		"expected_action": expected_action,
		"stack_depth_before": 1,
		"stack_depth_after": 1,
		"focus_before": "untracked",
		"focus_after": "untracked",
		"pause_state_before": false,
		"pause_state_after": false,
		"modal_precedence_checked": false,
		"focus_restore_checked": false,
		"action_route_checked": true,
		"privacy_checked": true,
		"pure_data_checked": true,
		"observed": false,
		"contract_aligned": aligned,
		"needs_design_decision": false,
		"risk": "low",
		"notes": notes,
	}
	record.merge(overrides, true)
	return record
