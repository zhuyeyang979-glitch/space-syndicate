# Alpha 0.4-A Player Card Dock continuation

Updated: 2026-07-29 (Asia/Tokyo)

## Recovery checkpoint

- `TASK_ID=ALPHA_0_4_A_PLAYER_CARD_DOCK_CONTINUATION_DIRECT_COMMODITY_CLAIM_AND_ART`
- `RESUME_MODE=EXISTING_DIRTY_TASK_WORKTREE`
- `EFFECTIVE_BASE_SHA=e6dc983be8154908e77d3a11bdee353a1b705152`
- `EFFECTIVE_BRANCH=codex/alpha04-production-player-card-dock-cde98ae`
- `EFFECTIVE_WORKTREE=E:/SpaceSyndicateWorkspace/worktrees/alpha04-production-player-card-dock-cde98ae`
- `WORKTREE_DIRTY_AT_RESUME=true`
- `UNCOMMITTED_TASK_WORK_PRESERVED=true`
- `COMMITS_AHEAD_OF_KNOWN_CLOUD=4` relative to terminal-green `b5d5682072fd9ff02be700ce9d5503d1df996641`
- `REPEATED_PREVIOUS_WORK=false`

The dirty worktree is unambiguously task-owned: it contains the new typed
`PlayerCardDock` scene, viewer query port and projection service, GameScreen
production composition, player-board action-surface retirement, task-specific
tests, and real production screenshots under
`docs/ui_qa/alpha04_player_card_dock/`. No reset, stash, clean, or replacement
worktree was used.

## Recovered implementation (pre-audit)

- A typed, viewer-authorized `PlayerCardDockProjectionV1` and scene-owned
  `PlayerCardDockViewerQueryPort` exist as uncommitted task work.
- Production `GameScreen` already instantiates `PlayerCardDock`, binds the
  authorized viewer, projects normal and commodity cards, and routes submitted
  offers through the existing game-action spine.
- The legacy `PlayerBoard` hand/action surface has been reduced and card play
  actions are filtered out of the fixed RightInspector.
- Initial production screenshots prove normal-card and commodity-card
  visibility at 1920x1080. These are preserved but do not yet satisfy the new
  direct-claim/art evidence matrix.
- Existing task tests cover typed projection, real three-pool composition,
  target selection, layout, and production cutover. Their current pass/fail
  state is being re-established before further integration.

## New continuation scope

- Remove every source-card claim button and make the source card itself the
  accessible single-click/confirm claim surface.
- Preserve one authoritative claim intent and receipt path with pending
  exact-once protection; presentation performs no inventory or track mutation.
- Add unique abstract science-fiction art for every active commodity through
  the existing illustration catalog and CardFace path.
- Render the same commodity illustration in source and owned-inventory
  surfaces while keeping the active V0.6 shared-capacity display truthful.
- Finish production, privacy, architecture, layout, full-run, MCP runtime, and
  screenshot gates without changing gameplay values, Save, RNG, or AI policy.

## Runtime authority lock

- `CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6`
- `TARGET_DEVELOPMENT_CONSTITUTION=V0.7`
- `FULL_V0_7_RUNTIME_CUTOVER=false`
- `RUNTIME_CAPACITY_MODE=SHARED_V06`
- `NEW_MAIN_RESPONSIBILITY_COUNT=0` (required)

## Parallel ownership

- Root: hot-file production integration, regression, MCP and release handoff.
- `dock_audit`: typed dock/projection scene and dedicated tests.
- `direct_claim`: top commodity source interaction and dedicated tests.
- `commodity_art`: authoritative commodity audit, catalog assets and dedicated
  coverage tests.

The hot files `scenes/main.tscn`, `scenes/ui/GameScreen.tscn`,
`scripts/ui/game_screen.gd`, `scripts/main.gd`, `AGENTS.md`,
`docs/development/current_program_state.json`, and
`docs/semantic/global_three_layer_semantic_registry.json` remain root-only.

## Next single task

Re-establish the previous focused-test baseline, then integrate the three
continuation lanes into the real production GameScreen.
