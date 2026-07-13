# Global UI Navigation Runtime Contract

## Sprint 67 status

Global UI Navigation Characterization Sprint 67 records the current behavior of the real `main.tscn` surface without changing production navigation. The long-lived Menu Shell gate remains 24/24 and the Codex-local navigation gate remains 20/20.

The Sprint 67 characterization result is:

- 32/32 cases observed.
- 19/32 cases already aligned with the target contract.
- 13/32 cases identify a concrete cutover gap.
- `main.gd` is intentionally unchanged at 20,209 nonblank lines, 1,285 functions, 141 top-level variables, and 204 constants.
- Frozen SHA-256: `6BD3F293EC2E92AEB81A39C80266314BE6A308D2C03ECD58FD8DB22958CAE699`.

The generated evidence is written to `user://space_syndicate_design_qa/global_ui_navigation_characterization/`.

## Current ownership

The current global Back route is not a single system. Ownership is split across:

- `main.gd::_unhandled_input()` for keyboard Esc.
- `main.gd::_show_menu()` and `_close_menu()` for pause state and menu visibility.
- `MenuOverlay` signals for Continue, generic Back, catalog Back, and quick navigation.
- `OverlayLayer` for confirmation, forced temporary decisions, and the generic side drawer.
- `DistrictSupplySideDrawerOverlay` for the supply drawer.
- `FullscreenMapOverlay` for the fullscreen map.
- `CodexNavigationRuntimeController` for Codex-local page, detail, filter, preview, and return-target state.
- Campaign and Scenario action routers for explicit page-specific parent actions.

`CodexNavigationRuntimeController` is intentionally not the global owner. Its five-domain catalog state and v1 save adapter remain a closed local responsibility.

## Observed Esc precedence

The current `main.gd::_unhandled_input()` order is:

1. Close fullscreen map when visible.
2. Otherwise close any visible MenuOverlay.
3. Otherwise open the pause menu.

This branch does not inspect confirmation modals, forced temporary decisions, generic side drawers, district supply, nested page parents, or opener focus.

## Target Back precedence

Sprint 68 must implement one pure-data surface stack and one global Back action route with this order:

1. Dismiss the top dismissible confirmation, detail, tooltip, or modal.
2. Never bypass a forced temporary decision; Back leaves it active and does not open pause behind it.
3. Close card detail, generic side drawer, or district supply before opening pause.
4. Pop a secondary page and restore the exact opener focus.
5. Close fullscreen map without opening pause.
6. In a match, toggle pause without leaving the match.
7. At the root menu, request exit confirmation instead of quitting or hiding the root.
8. A future route-placement preview consumes the first Back to cancel preview and a second Back to leave the mode. Sprint 67 records this reserved contract only; v0.4 does not add manual pipeline rules.

## Surface entry schema

Every future stack entry is pure data with these fields:

- `surface_id`
- `surface_kind`
- `parent_surface_id`
- `dismiss_policy`
- `focus_restore_path`
- `opened_by_action_id`
- `context_revision`

The stack, receipts, debug snapshot, manifest, and report may only contain Dictionary, Array, String, Number, Bool, and null. They must not contain Node, Callable, Object, or Resource.

## Focus contract

Opening a dismissible surface records the current focus owner as a stable NodePath string. Popping the surface restores that focus when the node still exists and remains focusable. When it no longer exists, the route uses the first enabled control in the restored parent surface. It must never leave keyboard or controller users with an invalid focus owner.

Pointer buttons, keyboard Back, and controller `ui_cancel` must request the same stable global action. Input devices do not own separate navigation algorithms.

## Characterized gaps

The 13 current gaps are:

- Global ownership remains split across `main.gd` and scene scripts.
- Esc precedence only knows fullscreen map, menu, and pause.
- Root Esc hides the root menu instead of requesting exit confirmation.
- Root Quit calls `get_tree().quit()` without confirmation.
- Confirmation Back opens pause and leaves confirmation visible.
- Forced decision Back opens pause behind the forced decision.
- Generic side drawer Back opens pause and leaves the drawer visible.
- District supply Back opens pause and leaves the drawer visible.
- Scenario action log/replay generic Back returns to the root menu instead of its pause opener.
- Exact opener focus is not recorded.
- No global fallback exists for a freed opener.
- Global Back is key-Esc only and does not share `ui_cancel`.
- No pure-data global surface-stack snapshot exists.

These are characterization failures, not rule failures. Sprint 67 does not modify production behavior to make them green.

## Sprint 68 deletion gate

Sprint 68 may replace and delete only the navigation ownership listed below:

- The Esc and menu Enter/Space branches inside `_unhandled_input()`.
- Pause-state and surface-open ownership inside `_show_menu()`.
- Surface-close and pause-restore ownership inside `_close_menu()`.
- Cross-surface routing inside `_back_from_catalog_menu()`; Codex detail state remains Codex-owned.
- Parent-label selection in `_catalog_back_button_text()`.
- `speed_before_menu` after the new owner stores pause restoration.
- The generic `MenuOverlay.main_menu_requested` Back meaning.
- Direct campaign/scenario parent-routing branches replaced by surface-stack pop receipts.

Sprint 68 must not delete or absorb:

- Codex selected/page/filter/detail/preview state.
- Card, Product, Monster, Region, or Role presentation.
- Temporary Decision action semantics.
- District purchase window or settlement ownership.
- Fullscreen map, menu, drawer, or Overlay scene presentation.
- Any card, economy, AI, monster, military, weather, market, city, route, save, or scenario rule.

## Cutover acceptance

The future hard cutover is accepted only when:

- All 32 characterization cases remain observed and become contract-aligned.
- Menu Shell remains 24/24.
- Codex Navigation remains 20/20.
- Keyboard, controller, and pointer routes share stable action ids.
- Forced decisions cannot be bypassed.
- Parent focus is restored or safely replaced.
- Root exit requires confirmation.
- There is no parallel legacy Back fallback in `main.gd`.
- Existing save version, action ids, signals, privacy boundaries, and gameplay rules remain unchanged.
