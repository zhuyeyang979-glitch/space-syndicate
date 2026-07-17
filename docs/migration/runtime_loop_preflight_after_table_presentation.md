# Authoritative Runtime Loop Cutover Preflight — third pass

Status: **RUNTIME_LOOP_PREFLIGHT_GREEN**

- Branch: `codex/scene-first-remove-main-gd`
- Audited head before commit: `5b5b11ef123962553ca34c2483f57a32e392f3f0` plus the uncommitted atomic presentation cutover
- Production `RuntimeLoop` created: **no**
- Main/new-loop double run created: **no**
- Unique frame entry: `res://scripts/main.gd::_process`

## Blocker verdict

The two blockers from the second pass are removed:

1. Card transition commands are consumed by the scene-owned
   `CardResolutionTransitionSink`; Main no longer consumes command arrays.
2. Table/map/developer/victory presentation is consumed by the scene-owned
   `TablePresentationSourceOwner` and `TablePresentationRefreshPort`; Main no
   longer consumes scheduler receipts.

There are no remaining `ROOT_ONLY_BLOCKER` steps in the authoritative frame
order. Existing AI, monster, military, weather, economy/route and victory
world bridges remain typed-world-port debt, but the RuntimeLoop can use their
already-existing coordinator APIs without adding or expanding a Main callback.
World dimensions are no longer a hidden Main dependency: the existing
`WorldSessionState` owns configuration, public projection and save/restore,
and both presentation and card-market policy consume that same owner.

## Frozen deterministic order

| Order | Step | Delta | Target API |
|---:|---|---|---|
| 1 | session-finished gate | none | coordinator/session owner |
| 2 | forced-decision synchronization | none | coordinator |
| 3 | global-time block gate | none | coordinator |
| 4 | blocked wager tick | real | coordinator |
| 5 | blocked visual-cue ageing | real | coordinator |
| 6 | blocked table presentation | real | `advance_table_presentation` |
| 7 | ordinary pause gate | none | session state |
| 8 | calculate world delta | world | frame boundary |
| 9 | world-effective clock advance | world | coordinator |
| 10 | game-time projection sync | world | `WorldSessionState` |
| 11 | card-resolution gate and frame | world | coordinator/transition sink |
| 12 | contract tick | world | coordinator |
| 13 | card cooldowns | world | coordinator |
| 14 | GDP derivative timers | world | scene owner |
| 15 | futures timers | world | scene owner |
| 16 | weather tick | world | coordinator |
| 17 | economic-boon ageing | world | scene owner |
| 18 | monster-wager tick | world | coordinator |
| 19 | AI tick | world | coordinator |
| 20 | monster motion | world | coordinator |
| 21 | military tick | world | coordinator |
| 22 | monster actions | world | coordinator |
| 23 | monster durations | world | coordinator |
| 24 | visual-cue ageing | world | coordinator |
| 25 | monster revivals | world | coordinator |
| 26 | commodity flow and early-return gate | world | coordinator |
| 27 | post-flow session-finished gate | none | session owner |
| 28 | product-market cycle | world | coordinator |
| 29 | victory advance and typed presentation receipt | world | coordinator |
| 30 | post-victory session-finished gate | none | session owner |
| 31 | frame-end table presentation | real | `advance_table_presentation` |

The blocked path uses real delta only for wager, visual cues and presentation.
Ordinary pause stops cadence and gameplay. Running advances the unique world
clock once. Session-finished frames stop immediately.

## Go decision

- Card transition ROOT_ONLY blocker: removed
- Table/map/developer presentation ROOT_ONLY blocker: removed
- Victory presentation ROOT_ONLY blocker: removed
- Scheduler remains cadence-only: yes
- Main consumes presentation receipts: no
- Main owns map width/height: no
- legacy scheduler-only immediate request in Main: no
- Main remains the sole frame entry: yes
- RuntimeLoop exists: no
- Double run exists: no

The next permitted atomic task is **AUTHORITATIVE_RUNTIME_LOOP_CUTOVER**.
