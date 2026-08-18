# PR #90 Runtime Event Cursor Instrumentation Blocker

## Release disposition

`STATUS=BLOCKED`

PR #90 remains on exact Head `4d5b173fccae7c6bb1004488e4d561c11714210a` and Tree `365a2a0d8b09162cc7338a460935e8b881cac770`. The live GitHub PR Head, direct PR ref, direct product branch ref, and clean local clone all match that identity. CI Run `32055074222` remains `SUCCESS`; PR #90 remains OPEN DRAFT, MERGEABLE, and CLEAN.

The already sealed Formal result remains `79/79 PASS` and is reused without rerun. PR #90 product Head changes in this continuation are zero. The frozen failed Exact-SHA MCP evidence was not modified, overwritten, or rerun.

The release chain stops before the newly authorized MCP run because neither permitted runtime-event continuity mode can be implemented honestly against the current interface:

`BLOCKED_REQUIRES_RUNTIME_EVENT_CURSOR_INSTRUMENTATION`

## Why the prior product end state can be green while MCP remains failed

The frozen Exact-SHA MCP run reached a correct terminal product state: the match settled once, FinalSettlement was observed once, Presentation collision and duplicate counts were zero, the required observer topology was `3/0/0`, and no runtime, privacy, invalid-action, nonfinite, or duplicate-settlement failure was observed.

That does not prove complete runtime-event evidence. The final query returned exactly the 100-event ring capacity and no longer contained the early `ready` event. A green terminal snapshot cannot prove that an earlier failure was not evicted. The frozen run therefore remains `FAIL`; this continuation did not reinterpret it.

## Why increasing or tail-limiting the 100-event window is not a fix

The production bridge fixes `MAX_RUNTIME_EVENTS` at 100 in `addons/funplay_mcp/runtime/funplay_mcp_runtime_bridge.gd:10`. Events contain only `kind`, `message`, `details`, and `timestamp`; when the array exceeds 100, `pop_front()` discards the oldest event at lines 518-526.

`get_runtime_events` exposes only `max_events` and `timeout_msec` in `addons/funplay_mcp/core/funplay_tool_registry.gd:577-583`. Its implementation returns a duplicate of the current ring and applies a tail limit in `addons/funplay_mcp/core/funplay_core_tools.gd:4303-4326`. It does not acknowledge, drain, clear, or advance a cursor.

Raising a client request limit above 100 cannot recover events already evicted by the bridge. Requesting only 80 events makes the response look smaller while hiding that the underlying ring has already saturated. Neither operation establishes completeness.

## Continuity mode audit

### Mode A: MONOTONIC_EVENT_SEQUENCE_OR_CURSOR

Impossible with the current interface. There is no event sequence, event ID, cursor, total generated-event count, `since` token, acknowledgement, or drain operation. The timestamp is not an authoritative unique occurrence identity.

### Mode B: OVERLAPPING_WINDOWS_WITH_NO_SATURATION

Also impossible for the known natural run. Polling is non-consuming, so the same cumulative ring continues growing until it reaches 100. From then on, each new event evicts an old event and the ring remains saturated. More frequent polling can save snapshots, but without occurrence identities it cannot prove that no event was inserted and evicted between two snapshots. It also cannot satisfy the formal requirement that no observed window reach 100.

Canonical fingerprints over `kind/message/details/timestamp` are not a substitute: identical events can legitimately recur within the same timestamp resolution. Fingerprints cannot distinguish occurrences, prove global order, or detect every eviction.

Accordingly:

```text
RUNTIME_EVENT_COLLECTOR_MODE=NONE
RUNTIME_EVENT_COLLECTOR_SELFTEST_STATUS=BLOCKED
RUNTIME_EVENT_COLLECTOR_SELFTEST_CASE_COUNT=0
AUTHORIZED_NEW_EXACT_SHA_MCP_RUN_COUNT_CONSUMED=0
EXACT_SHA_MCP_STATUS=NOT_RUN
```

The single-run authorization was not consumed and is not transferred to a future task. Runtime cursor instrumentation and any new exact-SHA run require fresh explicit authorization.

## Import Finalizer and later release stages

The conjunction of MCP preconditions failed at the Collector requirement, so no new DisposableExactClone was created, no Post-Import Baseline was sealed, and no Import Finalizer dry run or formal runbook dry run was started. The frozen failed clone remains untouched.

Per the release stop rule, the new Exact-SHA MCP, Viewport, Headless Matrix, and Product Headless 2,000 were not run. PR #90 was not made Ready and was not merged. No V0.7.6 branch or Detached POC A was created.

## Read-only Headless Presentation characterization

The Product 2,000 blocker remains independently valid, but no harness was implemented or run after the earlier Collector prerequisite failed.

- `scripts/v075_simulation/v075_combat_simulation_runtime_driver.gd:18` sets `_simulation_presentation_observer_disabled=true`; lines 443-452 intentionally omit the Presentation consumer and connect only receipt telemetry.
- Lines 1203-1205 expose only `presentation_observer_disabled`, `presentation_gameplay_mutation_count`, and `presentation_rng_draw_delta`. They do not expose Presentation collision or duplicate-observer-edge metrics.
- Production wiring is present at `scripts/v075_runtime/v075_runtime_owner.gd:5977-6006`: it creates `V075CombatPresentationConsumer` and connects the three required receipt/cue/telemetry edges.
- A tooling harness could instantiate that production consumer and collect its debug metrics, but the harness would have a new identity and must be explicitly authorized and sealed before formal use.
- The existing authority module can describe the expected 100 shards for 2,000 matches, but the command wrapper exposes `plan-shards` only. No dispatcher was run. Actual planned/dispatched/completed counts in this continuation are `0/0/0`.

## Machine-readable summary

```text
STATUS=BLOCKED
PRODUCT_HEAD_SHA=4d5b173fccae7c6bb1004488e4d561c11714210a
PRODUCT_TREE_SHA=365a2a0d8b09162cc7338a460935e8b881cac770
PR90_PRODUCT_HEAD_CHANGE_COUNT=0
AGGREGATED_PRODUCT_FOCUSED_TESTS=79/79
RUNTIME_EVENT_COLLECTOR_MODE=NONE
RUNTIME_EVENT_COLLECTOR_SELFTEST_STATUS=BLOCKED
FORMAL_EVENT_POLL_COUNT=0
FORMAL_READY_WITNESS_COUNT=0
FORMAL_EVENT_WINDOW_SATURATION_COUNT=0
FORMAL_EVENT_EVIDENCE_GAP_COUNT=NOT_RUN
POST_IMPORT_BASELINE_SEALED=false
IMPORT_FINALIZER_STATUS=NOT_RUN_BLOCKED_BY_EVENT_COLLECTOR_PRECONDITION
DISPOSABLE_CLONE_DISPOSITION=NOT_CREATED
EXACT_SHA_MCP_RUN_ID=pr90-gate78-repaired-exact-sha-mcp-002
EXACT_SHA_MCP_STATUS=NOT_RUN
MCP_EVENT_EVIDENCE_COMPLETE=false
MCP_PRESENTATION_COLLISION_COUNT=NOT_RUN
MCP_DUPLICATE_PRESENTATION_EFFECT_COUNT=NOT_RUN
HEADLESS_PRESENTATION_USES_PRODUCTION_CONSUMER=false
PRESENTATION_PARITY_SEED_COUNT=0
PRESENTATION_AUDIT_AUTHORITY_STATE_PARITY=false
DISPATCHER_AVAILABLE=false
SHARD_PLANNED_COUNT=0
SHARD_DISPATCHED_COUNT=0
SHARD_COMPLETED_COUNT=0
UNIQUE_SEED_COUNT=0
VIEWPORT_STATUS=NOT_RUN
HEADLESS_MATRIX_STATUS=NOT_RUN
PRODUCT_HEADLESS_2000_STATUS=NOT_RUN
PRODUCT_HEADLESS_COMPLETED_COUNT=NOT_RUN
PRODUCT_HEADLESS_PRESENTATION_RECEIPT_COUNT=NOT_RUN
PRODUCT_HEADLESS_PRESENTATION_COLLISION_COUNT=NOT_RUN
PRODUCT_HEADLESS_DUPLICATE_OBSERVER_EDGE_COUNT=NOT_RUN
PR90_READY=false
PR90_MERGED=false
PR90_MERGE_SHA=none
MAIN_RESULT_SHA=bd0af5c99c5267cdbe7d66c01034f80db4d704fd
V076_BRANCH_CREATED=false
V076_BRANCH=none
V076_POC_STARTED=false
POC_SEED_COUNT=0
DETERMINISTIC_REPLAY_COUNT=0
STATE_HASH_MISMATCH_COUNT=NOT_RUN
POC_MONSTER_DIRECTIONAL_MOVE_GREEN=NOT_RUN
V076_PRODUCTION_CUTOVER_PERFORMED=false
HANDOFF_AVAILABLE_IN_CLOUD=true
HANDOFF_PRODUCT_CODE_CHANGE_COUNT=0
NEXT_TASK=PR90_RUNTIME_EVENT_CURSOR_INSTRUMENTATION_AUTHORIZATION
```
