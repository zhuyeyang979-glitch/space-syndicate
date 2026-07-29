# Alpha 0.4-B production contextual table shell — post-merge handoff

## Result

```text
STATUS=ALPHA_0_4_B_PRODUCTION_CONTEXTUAL_TABLE_SHELL_TYPED_CUTOVER_GREEN
BASE_MAIN_SHA=eef2465fcf61111b888581e1f6d209a5665c9407
RESULT_HEAD_SHA=c169cb729bae0f085f06d0adb72693afe8b5e5f9
PULL_REQUEST=75
MERGE_COMMIT=29c2cdf96a13d75a5dd62afb2eb69435edbaf895
MAIN_RESULT_SHA=29c2cdf96a13d75a5dd62afb2eb69435edbaf895
```

PR #75 merged to `main` with a merge commit. PR #71 was closed as superseded;
PR #70 remains an open Draft and reference-only. No PR #70/#71 V0.7 runtime,
AI, Save/Replay, Bench, fixture, or scene tree was merged into production.

## Production cutover

- Ten current RightInspector responsibilities moved to narrow, viewer-authorized
  typed surfaces: player roster, player inspection, region supply, compact
  non-card action context, toast/public history, and closed-union detail.
- The fixed RightInspector scene, script, snapshot, signal forwarding, dynamic
  calls, generic fallback, and production references were physically deleted.
- RoleSeatLayerHost, Back/Front seat layers, public seat source/snapshot,
  seat-position IDs, depth/mirroring data, orbit seat pips, and legacy fixtures
  were physically deleted.
- The roster stays on the left and preserves `public_order_index`. Three to four
  players use one column; five to eight use two columns. The local player is
  marked but never rotated to the first slot.
- Region supply uses the existing authoritative rack query and action ports.
  Popup open, close, switch, hover, map camera, and zoom do not refresh the
  rack. Duplicate visual copies have unique rack identities while action offers
  retain the real semantic card target.
- Player Card Dock remains the only production card-submission surface.

## Authority and validation

Gameplay values, V0.6 rules, AI policy, Save owners/sections/schema, RNG
owners/draw points, Main responsibilities, Victory, FinalSettlement, terminal
timers, RuntimeLoop, and terminal owners have zero diff from the base. Production
remains V0.6; V0.7 remains the target constitution and
`GLOBAL_THREE_LAYER_COMPLETE=false`.

```text
ALPHA04_A_REGRESSION=598/598
ROSTER_INSPECTION_SCHEMA_PRIVACY=268/268
REGION_ACTION_SEMANTIC_FLOW=273/273
LEGACY_RETIREMENT_ARCHITECTURE=60/60
LAYOUT_MEASUREMENT=28/28
PRODUCTION_UI_JOURNEY=53/53
PRODUCTION_SCREENSHOTS=10
SMOKE_CHECK_ONLY=PASS
GODOT_MCP_SCRIPT_ERRORS=0
GODOT_MCP_RUNTIME_ERRORS=0
GODOT_PROCESS_COUNT_AFTER=0
THIRD_FORMAL_RUN_PERFORMED=false
FULL_SMOKE=false
```

The map gained 120 permanent pixels of width. Its measured permanent area gain
is 68,880 pixels at 1920×1080 and 46,320 pixels at 1366×768 for both four- and
eight-player layouts.

## Next product boundary

`ALPHA_0_4_C_SAVE_RESUME_OWNER_COVERAGE_AND_COLD_RESTORE_VERTICAL_SLICE`

The player-facing table shell is now coherent and the existing V0.6 run can
reach settlement. The largest remaining product risk is persistence: seven
required owners are still outside the transactional Save envelope, and cold
startup restore/continued play are unproved. Expanding more UI would not reduce
that loss-of-run risk, while a full V0.7 runtime cutover would multiply state
migration requirements before the current production state can be restored.

