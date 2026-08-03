# V0.7.3 Sample-First Atomic Production Cutover

STATUS=ALPHA_0_5_B_V073_SAMPLE_FIRST_ATOMIC_PRODUCTION_CUTOVER_AND_PLAYABLE_SLICE_GREEN

BASE_MAIN_SHA=794ccf010e661a4750efca20a4e0d2a5839b7f2b

PRODUCTION_COMMIT_SHA=f49c86af20b6a65e9792aa87703154e853d4dc76

PRODUCTION_TREE=08253aef8ac1859e7a0fa451ad278f39e919a661

BRANCH=codex/v073-sample-first-atomic-production-cutover-794ccf0

PULL_REQUEST=PENDING_CREATION

REQUESTED_SUBAGENTS=6

ACTUAL_MAX_CONCURRENT_SUBAGENTS=6

ALPHA04C_RELIABILITY_TRACK_FROZEN=true

PR77_MODIFIED_BY_THIS_TASK=false

V073_CONSTITUTION_ID=space_syndicate.v073.complete

V073_RULESET_ID=v0.7.3

V073_ATOMIC_CUTOVER_DOMAIN_COUNT=19

V073_CONNECTED_DOMAIN_COUNT=19

V073_DUAL_WRITE_COUNT=0

V073_LEGACY_FALLBACK_COUNT=0

V073_MIXED_RULESET_STATE_COUNT=0

V06_PRODUCTION_RULE_OWNER_COUNT=0

V06_PRODUCTION_AI_POLICY_COUNT=0

V06_PUBLIC_BID_PRODUCTION_REFERENCE_COUNT=0

V06_AUCTION_TIMER_PRODUCTION_REFERENCE_COUNT=0

V073_UNIFIED_TRACK_PRODUCTION_GREEN=true

V073_DBG_DECK_PRODUCTION_GREEN=true

V073_OPTIONAL_MERGE_PRODUCTION_GREEN=true

V073_SIX_COLOR_ASSET_PRODUCTION_GREEN=true

V073_CARD_BATCH_PRODUCTION_GREEN=true

V073_ROUND_ROBIN_PRODUCTION_GREEN=true

V073_FACILITY_CONTENTION_PRODUCTION_GREEN=true

V073_SOLAR_EFFICIENCY_PRODUCTION_GREEN=true

V073_AI_ADAPTER_CONNECTED=true

V073_PLAYER_ADAPTER_CONNECTED=true

V073_UI_RUNTIME_CUTOVER=true

V073_NEW_GAME_ONLY_SAMPLE=true

V073_SAVE_RESUME_ENABLED=false

V06_SAVE_FILE_DELETE_COUNT=0

V06_SAVE_FILE_OVERWRITE_COUNT=0

V073_3P_SIM_GREEN=true

V073_4P_SIM_GREEN=true

V073_6P_SIM_GREEN=true

V073_8P_SIM_GREEN=true

V073_SAMPLE_MATCH_STARTED=true

V073_SAMPLE_MATCH_COMPLETED=true

V073_VICTORY_REACHED=true

V073_FINAL_SETTLEMENT_COUNT=1

V073_DUPLICATE_SETTLEMENT_COUNT=0

INVALID_ACTION_COUNT=0

NONFINITE_COUNT=0

HIDDEN_INFO_VIOLATION_COUNT=0

DUAL_AUTHORITY_COUNT=0

MCP_CHANGED_FILE_ERROR_COUNT=0

MCP_PROJECT_ERROR_COUNT=0

MCP_RUNTIME_ERROR_COUNT=0

MCP_TASK_INTRODUCED_ERROR_COUNT=0

MCP_BASELINE_DIAGNOSTIC_COUNT=26

MAIN_NEW_RESPONSIBILITY_COUNT=0

PLANET_OPAQUE=true

OUTER_ORBIT_DECORATION_COUNT=0

RIGHT_PERMANENT_PANEL_COUNT=0

SIX_COLOR_ICON_COVERAGE=6/6

NORMAL_CARD_ART_COVERAGE=100_PERCENT

COMMODITY_CARD_ART_COVERAGE=100_PERCENT

HUMAN_PLAYABLE_SAMPLE_READY=true

MERGE_TO_MAIN_ALLOWED=true

MERGED_TO_MAIN=false

MAIN_RESULT_SHA=unchanged_at_report_generation

PR77_DRAFT=true

NEXT_TASK=ALPHA_0_5_C_V073_HUMAN_PLAYTEST_INSTRUMENTATION_AND_BALANCE_ITERATION

## Outcome

The production branch now boots directly into the V0.7.3 Contextual Table Shell. Its only reachable gameplay composition owns the V0.7.3 ruleset, new-game setup, personal DBG deck, unified normal-plus-commodity track, six-color assets, card batches, hidden fixed round-robin resolution, facility contention, AI and player projections, victory gate, and FinalSettlement. `scripts/main.gd` was not changed and gained no gameplay responsibility.

The first sample is intentionally new-game-only. Save and Continue remain visible but disabled, the UI states `V0.7.3样品暂不支持中途保存`, and no V0.6 save was read, deleted, or overwritten. The detached V0.7.3 Save adapter remains outside production writes.

## Why Alpha 0.4-C Was Frozen

Alpha 0.4-C is a reliability line, not the V0.7.3 gameplay authority. Keeping it as a separate frozen track preserves PR #77, the five Save-owner upgrades, MCP lifecycle repairs, Session Start migration, Product Market rollback, discardability typed query, and zero-candidate hand interaction work without importing unfinished Save/Session behavior into the new-game-only sample. The exact commit and tree inventory is in [alpha04c_reliability_track_freeze.md](alpha04c_reliability_track_freeze.md).

The MCP checkpoint is remotely preserved as `origin/wip/mcp-tooling-frozen-6cf1d30`; it is not presented as a GREEN gameplay PR. Alpha 0.4-C Attempt 3/4, V8, Process A, Formal, FullRun, Smoke, and `smoke_test.gd` were not run.

## Production Owners

The atomic manifest reports 19 connected domains and zero partial connection, dual write, legacy fallback, or mixed ruleset state. The production graph now connects:

- V0.7.3 Ruleset Runtime Owner and New Game application flow.
- Personal DBG draw, discard, refill, reshuffle, and optional merge.
- One unified track carrying normal and commodity cards with replacement lock.
- Six-color assets with icon-plus-label presentation and a 0/6 cap.
- Prebound targets, full reservation, fixed hidden round-robin resolution, and typed Fizzle.
- Facility slot contention and sunlight efficiency at 2.0/1.0 without changing track color supply.
- Canonical AI observation and player projection adapters.
- Macro-round victory revalidation and exactly-once FinalSettlement.
- Commercial presentation keys used by production cards and table surfaces.

The sample runtime reports zero V0.6 rule, AI-policy, player-projection, supply, resolution-order, or asset-refresh owners. Public bid, auction timer, region purchase surface, permanent right panel, and implicit fallback counts are all zero.

## Gameplay Proof

The focused and aggregate evidence is GREEN:

| Evidence | Result |
| --- | ---: |
| Constitution contract | 269/269 |
| Balance defaults | 183/183 |
| Atomic cutover manifest | 249/249, 19/19 connected |
| Adapter architecture | 82/82 |
| Canonical adapters | 21/21 |
| Commercial art keys | 169/169 |
| Production Core aggregate | 52/52 |
| Production sample acceptance | 672/672 |

The production acceptance suite used legal production actions for 3, 4, 6, and 8 players. Every run reached `settled`; 24 facility-contention Fizzles were resolved with zero invalid action, nonfinite value, hidden-information violation, dual authority, or runtime failure.

The single exact-SHA MCP acceptance match used one local human and three production AIs. The human started through the visible 4-player button, and the visible `继续至终局` command performed the authorized accelerated legal-action run. It reached Victory and presented FinalSettlement once after 450 runtime frames. Final counts were: invalid actions 0, nonfinite 0, privacy violations 0, dual authority 0, runtime errors 0, duplicate settlement 0, V0.6 save apply/write 0.

## MCP Proof

The exact project head was `f49c86af20b6a65e9792aa87703154e853d4dc76`, with production tree `08253aef8ac1859e7a0fa451ad278f39e919a661`. The frozen tooling overlay was the only uncommitted difference in the isolated acceptance worktree.

- Session: `v073-f49c86af-exact-acceptance-01`
- Editor PID: `15540`
- Endpoint: `http://127.0.0.1:8897/`
- Fresh project cache, user data, log root, and process identity: GREEN
- Initial scan and import quiescence: GREEN
- Changed GDScript validation: 54/54
- Changed scene load: 7/7
- Production `main.tscn` runtime console errors: 0
- Changed-file, production-project, task-introduced, and unclassified target errors: 0
- Clean stop: true; forced stop: false; editor exit code: 0; process count after: 0

The cold recovery import still emitted 26 inherited diagnostics: 8 Unicode lines, 12 parse lines, and 6 failed script loads. The six root scripts are byte-identical to `origin/main`, are all old V0.6 bench/test files, and have zero references from the V0.7.3 production composition. They are recorded as legacy bench debt, not hidden or globally ignored. The live editor and production runtime had zero errors.

One headless Production Core launch exited with native signal 11 before any test marker. The identical aggregate passed windowed 52/52 immediately, and the exact MCP editor completed import, validation, play, and clean stop without a native crash. The raw headless run remains preserved under `.codex-godot/test-runs/production-core` and is not attributed to project code.

## Visual Evidence

- [1600x960 four-player production table](../ui/v073_sample_final/1600x960-four-player-production.png)
- [1366x768 four-player region popup](../ui/v073_sample_final/1366x768-four-player-region-popup.png)
- [1920x1080 eight-player roster, map, and track](../ui/v073_sample_final/1920x1080-eight-player-roster-map-track.png)
- [MCP target binding and local queue](../ui/v073_sample_final/1528x917-target-popup-queue-mcp.png)
- [MCP exact-SHA FinalSettlement](../ui/v073_sample_final/1528x917-final-settlement-mcp-exact-sha.png)

The 1600x960, 1366x768, and 1920x1080 captures have exact PNG dimensions. Godot 4.7's embedded MCP game viewport reports a 1528x917 framebuffer inside a 1600x960 editor launch, so the two MCP-only interaction captures are named with their actual payload dimensions rather than being mislabeled.

## Player-Facing State

The sample begins with 12 free Starter cards per player, draws 5, and starts every asset color at 0/6. Normal cards discard and refill through the personal DBG owner; new normal cards enter discard. Commodity inventory is separate and capped at 5. Optional merge remains player-driven.

The unified track carries both card kinds. GDP is absent from track-color distribution and remains confined to the six-color asset rules. Targets bind before lock, reservations commit at lock, and stale or contended actions return typed Fizzle outcomes. Cash cannot alter hidden round-robin order. Sunlit and dark facilities use 2.0 and 1.0 efficiency respectively, without affecting unified-track supply.

The AI sees its own private facts plus public state only. The player UI exposes the local hand, unified track, six-color pool, target rail, local queue controls, region popup, AI roster, and settlement. Four players use one roster column; eight use two. The planet is opaque, the backside is occluded, outer-orbit decoration and the permanent right panel are absent, and cards/assets do not rely on color alone.

## Scope And Stop

No MCP addon, `.import`, `.uid`, `.godot`, session log, or generated user-data file belongs in the production commit. PR #77 is untouched and remains Draft. The next task is human playtest instrumentation and balance iteration; this task does not resume Session v4 or any V0.6 reliability bench campaign.
