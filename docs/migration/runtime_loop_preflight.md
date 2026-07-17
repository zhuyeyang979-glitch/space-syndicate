# Authoritative Runtime Loop Cutover Preflight — second pass

Status: **RUNTIME_LOOP_PREFLIGHT_BLOCKED**

- Branch: `codex/scene-first-remove-main-gd`
- Original task start: `297ed167bd0e656aef00a08c68b1edfcadd59474`
- Audited prerequisite/test head: `8af35b1ed8c3637f2222a844147e4566360071d5`
- Audited path: `res://scripts/main.gd::_process`
- Production `RuntimeLoop` created: **no**
- Main/new-loop double run created: **no**

The requested prerequisites are now scene-owned and production-composed:

1. `ForcedDecisionCandidateSources`
2. `CardResolutionFrameDriver`
3. `CardCooldownRuntimeController`
4. `VisualCueRuntimeOwner`
5. `TablePresentationRefreshScheduler`

The second Go/No-Go still fails. Card timing now produces ordered transition commands, but applying those commands still enters Main-private card execution and presentation methods. Refresh timing now produces ordered due receipts, but the real table, map and developer presentation targets are still Main-private. Moving `_process` now would therefore require a callback to Main, skip behavior, or create a second execution path.

The machine-readable inventory is in `runtime_loop_preflight.json`.

## What is green now

### Frame-front and blocked-time ownership

- Forced-decision candidates are composed from scene owners through `GameRuntimeCoordinator.synchronize_forced_decisions()`.
- Monster wagers remain the only global-time blocker and continue to tick with real delta.
- Visual cue lifetimes are owned by `VisualCueRuntimeOwner`; global block uses real delta and active play uses world delta.
- Refresh accumulators are owned by `TablePresentationRefreshScheduler`; it accepts real delta and emits `live`, `map`, `full`, `developer` receipts in deterministic order.

### Active-world ownership

- `CardResolutionFrameDriver` owns the single timing tick and fact assembly.
- `CardCooldownRuntimeController` owns card/action cooldown ageing while `WorldSessionState.players` remains the state/save owner.
- The world-effective clock remains unique and is advanced once by the current frame path.
- Existing explicit coordinator APIs cover contracts, weather, wagers, AI, monsters, military, commodity flow, product market and victory control.

## Current deterministic order

| Order | Step | Delta | Classification |
|---:|---|---|---|
| 1 | Session-finished gate | none | `EXISTING_COORDINATOR_API` |
| 2 | Synchronize forced decisions | none | `EXISTING_COORDINATOR_API` |
| 3 | Global-time block gate | none | `EXISTING_COORDINATOR_API` |
| 4 | Blocked wager tick | real | `EXISTING_COORDINATOR_API` |
| 5 | Blocked visual-cue ageing | real | `EXISTING_COORDINATOR_API` |
| 6 | Blocked refresh cadence | real | `PRESENTATION_CADENCE` |
| 7 | Apply blocked refresh receipt | none | `ROOT_ONLY_BLOCKER` |
| 8 | Ordinary pause gate | none | `READY_SCENE_OWNER` |
| 9 | Calculate world delta | world | `READY_SCENE_OWNER` |
| 10 | Advance world-effective clock | world | `EXISTING_COORDINATOR_API` |
| 11 | Synchronize `WorldSessionState.game_time` | world | `READY_SCENE_OWNER` |
| 12 | Card-resolution progress gate | none | `EXISTING_COORDINATOR_API` |
| 13 | Card-resolution frame driver | world | `EXISTING_COORDINATOR_API` |
| 14 | Apply card transition commands | none | `ROOT_ONLY_BLOCKER` |
| 15 | Contract tick | world | `EXISTING_COORDINATOR_API` |
| 16 | Card/action cooldown ageing | world | `EXISTING_COORDINATOR_API` |
| 17 | GDP derivative timers | world | `READY_SCENE_OWNER` |
| 18 | Futures timers | world | `READY_SCENE_OWNER` |
| 19 | Weather tick | world | `EXISTING_COORDINATOR_API` |
| 20 | Economic-boon ageing | world | `READY_SCENE_OWNER` |
| 21 | Monster-wager tick | world | `EXISTING_COORDINATOR_API` |
| 22 | AI tick | world | `EXISTING_COORDINATOR_API` |
| 23 | Monster motion | world | `EXISTING_COORDINATOR_API` |
| 24 | Military tick | world | `EXISTING_COORDINATOR_API` |
| 25 | Monster actions | world | `EXISTING_COORDINATOR_API` |
| 26 | Monster durations | world | `EXISTING_COORDINATOR_API` |
| 27 | Visual-cue ageing | world | `EXISTING_COORDINATOR_API` |
| 28 | Monster revivals | world | `EXISTING_COORDINATOR_API` |
| 29 | Continuous commodity flow | world | `EXISTING_COORDINATOR_API` |
| 30 | Flow-result early-return gate | none | `EXISTING_COORDINATOR_API` |
| 31 | Post-flow session-finished gate | none | `EXISTING_COORDINATOR_API` |
| 32 | Product-market cycle | world | `EXISTING_COORDINATOR_API` |
| 33 | Victory-control advance | world | `EXISTING_COORDINATOR_API` |
| 34 | Victory state-change presentation | none | `ROOT_ONLY_BLOCKER` |
| 35 | Post-victory session-finished gate | none | `EXISTING_COORDINATOR_API` |
| 36 | Frame-end refresh cadence | real | `PRESENTATION_CADENCE` |
| 37 | Apply frame-end refresh receipt | none | `ROOT_ONLY_BLOCKER` |

## Remaining ROOT_ONLY_BLOCKER domains

### 1. Card transition execution and presentation sink

`GameRuntimeCoordinator.advance_card_resolution_frame(world_delta)` now returns deterministic commands, but Main still consumes each command through `_apply_card_resolution_controller_transition()`. That path can start/complete resolutions, finish played skills, update queues and open/close presentation surfaces. It belongs to the explicitly separate `card_execution` domain.

Minimum prerequisite:

- create one scene-owned `CardResolutionTransitionSink` or extend the existing execution service with a typed `apply_transition(command)` API;
- route gameplay mutations to existing card/economy/monster/military owners;
- route public presentation receipts to the card presentation service/overlay port;
- migrate all production consumers;
- prove exact-once execution and remove `_apply_card_resolution_controller_transition()` plus its now-dead Main helpers in the same atomic change.

Forbidden shortcut: a sink signal, `Callable`, method table, or fallback that invokes Main.

### 2. Table/map/developer presentation targets

`TablePresentationRefreshScheduler` owns cadence only. Main still applies due receipts through `_refresh_live_ui()`, `_refresh_board()`, `_refresh_ui()` and `_refresh_developer_balance_greybox()`. Those methods assemble world/public view-model inputs and target `GameScreen`, map, overlays and the developer panel.

Minimum prerequisite:

- create a scene-owned `TablePresentationSourceOwner` that builds visibility-safe public/current-player snapshots from typed owners;
- expose typed refresh targets on `GameScreen`, `PlanetBoard`/map and the developer-only panel;
- create a narrow `TablePresentationRefreshPort` that consumes scheduler receipts without discovering Main;
- migrate direct refresh requests from domain controllers to the port;
- remove the four Main refresh targets and verify hidden information remains absent.

The scheduler must remain cadence-only and must not absorb snapshot assembly or UI layout logic.

#### Victory state-change presentation side effects

`GameRuntimeCoordinator.advance_victory_control()` owns the authoritative outcome and session finish, but Main's `_update_victory_control()` still compares before/after state, writes the public log and requests an immediate refresh. A future RuntimeLoop cannot silently drop those visible state-change receipts.

Minimum prerequisite: have victory control emit a visibility-safe state-change receipt consumed by the same scene-owned presentation port. This is part of blocker domain 2, not a third owner program, and must not give RuntimeLoop UI responsibilities.

## Commodity flow is not a blocker

The current Main helper adds only public/session facts and checks the returned bankruptcy checkpoint. `GameRuntimeCoordinator.advance_commodity_flow(delta, facts)` already owns the real operation and returns the exact early-exit receipt. A future RuntimeLoop can obtain `game_over`, pause state, world-effective time and player count from existing scene owners without a Main callback. No new commodity owner is required.

## Time and pause verdict

The current product semantics remain binary running/paused:

| Situation | Wager | Visual | Refresh cadence | World clock/gameplay |
|---|---|---|---|---|
| Session finished | stopped | stopped | stopped | stopped |
| Monster-wager global block | real delta | real delta | real delta | stopped |
| Ordinary menu/pause | stopped | stopped | stopped | stopped |
| Running | world delta | world delta | real delta | once, ordered |

`GameSessionRuntimeController` is the future pause authority. The remaining Main `time_scale`/menu mirror is legacy presentation/save debt; no `RuntimePacingState` is justified by current rules. QA-only acceleration uses test drivers and does not define production pacing.

## Existing typed-world-port debt

AI, monster, military, weather, economy/product/route, victory and card-resolution bridges still contain pre-existing Main access. None of the five prerequisite cutovers added bridge capabilities or new production Main reference files. These remain the next `typed_world_ports` program after the RuntimeLoop can be cut over; they are not claimed as migrated here.

## Go/No-Go verdict

Because `ROOT_ONLY_BLOCKER` entries remain:

- no `RuntimeLoop.tscn` or `runtime_loop.gd` was created;
- Main `_process` remains the only gameplay tick path;
- no double tick or second world clock exists;
- `runtime_loop` remains `pending` in the cutover ledger;
- the prohibited full RuntimeLoop production commit was not created.

Recommended next prerequisite: **Card Resolution Transition Sink Cutover**, followed by **Table Presentation Source/Target Cutover**. Then rerun this preflight a third time.

## Current budget

`python tools/architecture/check_main_gd_budget.py --json` at `8af35b1e` passes:

- physical lines: 15,126
- nonblank lines: 13,212
- methods: 894
- top-level variables: 79
- constants: 111
- top-level preloads: 15
- external Main caller occurrences: 1,647
- external Main caller files: 102
- production Main reference files: 3

Compared with the first preflight, every tracked Main metric decreased and no production Main reference file was added.

## Validation status

Green gates:

- Forced-decision, card-frame, cooldown, visual-cue and refresh-cadence focused tests
- Godot MCP production/Bench runs for each prerequisite
- Main architecture and budget gates
- Main runtime composition
- UI text smoke
- visual snapshot
- `smoke_test.gd --check-only`

The isolated full smoke run is **not green**: 284 assertions pass and 95 fail across existing AI policy, card-handler coverage, economy fixtures and legacy UI expectations. The test was migrated so deleted `_update_card_resolution_queue`, `movement_trails`, `action_callouts` and `map_event_effects` Main surfaces produce zero missing-access errors; no compatibility fields were restored. Because the RuntimeLoop Go/No-Go is blocked before production implementation, this report does not mislabel the broad full-smoke baseline as a RuntimeLoop regression or as completed acceptance.
