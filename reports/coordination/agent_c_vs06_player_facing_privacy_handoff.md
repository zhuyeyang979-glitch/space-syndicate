# Agent C VS06-C7 Player-Facing Privacy Handoff

## Outcome

PASS at the owned focused-gate level. New-game setup and district-supply presentation now enforce privacy in the source snapshot, not by hiding already-leaked UI values.

## Modified files

- `scripts/main.gd`
  - `_new_game_setup_seat_card_snapshot`: AI seats return role-only public data with no starter-specific keys or card face; the local human retains their selected starter.
  - `_refresh_district_supply_overlay`: passes the explicit local viewer.
  - `_district_supply_snapshot_source`: separates `subject_player_index` from `viewer_player_index` and fails missing/forged/opponent/AI viewers closed to public scope.
  - `_district_supply_private_viewer_authorized` and `_district_supply_public_card_source`: central authorization and fixed public browse-state sanitizer.
- `scripts/ui/new_game_setup_seat_card.gd`
  - AI seats render fixed “随机分配/开局后未知” copy without reading missing private keys; human controls are unchanged.
- `scripts/runtime/district_supply_snapshot_service.gd`
  - Explicit public/viewer-private schema validation, recursive forbidden-key checks, and a public purchase-state allowlist.
  - Public cards keep their canonical public price and fixed `仅浏览` state, while cash/hand/window/real eligibility are absent.
- `tests/player_facing_privacy_boundary_test.gd`
  - Production-facing focused gate using real `main.tscn`, setup page, Coordinator, snapshot service, and district drawer.

No Coordinator, AI, CardFlow, CommodityFlow, Victory, Monster, catalog, rules, or TomorrowVerticalSlice file was changed.

## Public API contract

`_district_supply_snapshot_source(district_index, subject_player_index, viewer_player_index = -1)` now has these semantics:

- `viewer_private`: only when viewer == subject == local human and that seat is not AI. Includes exact own `player_cash`, `counted_hand_size`, `hand_limit`, `can_buy`, `purchase_window`, and per-card eligibility.
- `public`: missing viewer, forged viewer, opponent subject, or AI subject. Omits those private top-level fields. Each card exposes only public price plus an allowlisted `purchase_state` with `label=仅浏览`, `actionable=false`, and `requires_discard=false`.
- Recursive forbidden owner/hand/discard/AI-plan metadata makes the service return its safe empty snapshot instead of rendering an invalid source.

Legacy two-argument callers are intentionally public and cannot recover private aggregates by omission.

## Minimal verification

Command used with isolated `APPDATA`:

```powershell
$env:APPDATA = Join-Path $env:TEMP 'space_syndicate_vs06_c7_appdata'
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/player_facing_privacy_boundary_test.gd
```

Result: `PLAYER_FACING_PRIVACY_BOUNDARY_TEST|status=PASS|checks=67|failures=0`, exit code 0, with no parse/runtime error in the final run.

The gate proves:

- full recursive AI seat snapshots contain no starter-specific keys or actual starter names;
- the local human still sees their own selected starter and its card face;
- real visible setup controls show fixed AI wording and no AI starter secret;
- missing, forged, AI-self, and opponent district viewers all produce safe public sources;
- public compose is non-empty, preserves cards/public prices, and has zero injected cash/hand/discard/owner/AI-plan leaks;
- the local human self-view preserves exact own cash, hand aggregate, purchase window, and eligibility;
- the normal drawer coerces an AI subject back to the local human and still renders the human's own private aggregates.

## Evidence boundary / remaining work

- Full vertical slice, full regression, MCP, and headful checks were not run; coordination owns the unified run.
- The old `layout_scene_smoke_test.gd` hand-built district source lacks explicit viewer/subject/scope fields. That fixture is stale under the fail-closed schema and was not edited outside this task's boundary.
- `scripts/main.gd` already contained extensive shared-worktree changes. C7 changed only the named setup/district-supply functions above; no unrelated diff was reverted.

## Lessons for other agents

- **invariant:** Privacy authorization belongs at source construction; presentation code must never receive an opponent's exact private value.
- **failed approach:** Treating every `purchase_state/actionable` key as private made a safe public browse state invalid; deleting the state also removed legitimate price/`仅浏览` presentation. A constrained public state is the correct split.
- **stable API:** District supply callers must provide both subject and viewer; omitted viewer is public by design.
- **test oracle:** Require recursive seat/source scans, a non-empty public compose result, fixed false public eligibility, and exact self-private values in the same test.
- **integration trap:** Passing an AI seat as both subject and viewer is not AI authorization; only the local human self-relation unlocks private aggregates.
- **reusable pattern:** Use a common public schema, optional viewer-private fields, an allowlisted public sub-schema, recursive forbidden-key validation, and an independent sentinel scan.
- **stale evidence:** Any fixture that fabricates cash/hand fields without explicit viewer/subject/scope is pre-C7 evidence and should fail closed.
- **next dependency:** Coordination should rerun Stage9 and update only stale test fixtures/callers that genuinely require the explicit private-view contract.
