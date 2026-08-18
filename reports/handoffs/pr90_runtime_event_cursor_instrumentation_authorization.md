# PR #90 Runtime Event Cursor Instrumentation Candidate

## Candidate identity

This isolated tooling candidate is based exactly on the frozen PR #90 Head:

```text
BASE_PR90_HEAD=4d5b173fccae7c6bb1004488e4d561c11714210a
BASE_PR90_TREE=365a2a0d8b09162cc7338a460935e8b881cac770
CANDIDATE_BRANCH=codex/pr90-runtime-event-cursor-instrumentation
CANDIDATE_HEAD=1ba7b1cb6fb88c79348350ff0603de14aa5c7e0b
CANDIDATE_TREE=22c14e536687b6a84ffa6871183b90fd527ceb18
PRODUCT_RUNTIME_CODE_CHANGE_COUNT=0
GAMEPLAY_RULE_CHANGE_COUNT=0
BALANCE_VALUE_CHANGE_COUNT=0
```

The candidate changes only MCP editor/tooling code and a focused contract test. It does not modify PR #90, PR #91, gameplay rules, presentation ownership, AI, balance, Save, or production game runtime code.

## Implemented fail-closed contract

The runtime bridge now assigns every event a per-incarnation `stream_id` and a monotonic `event_sequence`. `get_runtime_events` accepts `stream_id` plus `since_sequence` and reports the retained ring boundaries, next sequence, overflow count, and continuity status.

Strict cursor requests fail closed for:

- stream restart or mismatch: `RUNTIME_EVENT_STREAM_CHANGED`;
- missing stream identity: `RUNTIME_EVENT_STREAM_ID_REQUIRED`;
- negative cursor: `RUNTIME_EVENT_CURSOR_INVALID`;
- future cursor: `RUNTIME_EVENT_CURSOR_AHEAD`;
- evicted events or sequence gaps: `RUNTIME_EVENT_EVENTS_DROPPED`;
- malformed sequence metadata: `RUNTIME_EVENT_METADATA_INVALID`;
- client-side `max_events` truncation: `RUNTIME_EVENT_CLIENT_TRUNCATED`.

Existing no-cursor callers remain compatible, but their result is explicitly `SNAPSHOT_ONLY` and `event_evidence_complete=false`. The retained `event_count` meaning is unchanged. A full ring is reported separately from actual eviction using `event_window_saturated` and `event_window_overflowed`.

## Validation

```text
GODOT_VERSION=4.7.stable.official.5b4e0cb0f
CONTRACT_TEST_STATUS=PASS
CONTRACT_TEST_CASE_COUNT=33
EDITOR_SCAN_STATUS=PASS
GODOT_MCP_PROJECT_RUN=STARTED_AND_STOPPED
GODOT_MCP_NEW_ERROR_COUNT=0
GIT_DIFF_CHECK=PASS
```

The Godot MCP run produced only the repository's pre-existing GDScript warnings and stopped cleanly. No new runtime error was observed.

The contract test covers an empty stream, ready witness, monotonic sequences, incremental cursor reads, ring overflow, retained-boundary recovery, invalid/missing/ahead cursors, stream restart detection, legacy snapshot downgrade, and client-side truncation metadata.

## Formal release boundary

This candidate is not yet PR #90 release evidence. The prior authorization was bound to the original PR #90 Head and was not consumed here:

```text
AUTHORIZED_NEW_EXACT_SHA_MCP_RUN_COUNT_CONSUMED=0
EXACT_SHA_MCP_STATUS=NOT_RUN
POST_IMPORT_BASELINE_SEALED=false
IMPORT_FINALIZER_STATUS=NOT_RUN
VIEWPORT_STATUS=NOT_RUN
HEADLESS_MATRIX_STATUS=NOT_RUN
PRODUCT_HEADLESS_2000_STATUS=NOT_RUN
PR90_READY=false
PR90_MERGED=false
V076_BRANCH_CREATED=false
V076_POC_STARTED=false
```

Before a new Exact-SHA MCP run, this candidate needs its own manifest/hash authorization, candidate CI, and complete Formal Gate 1—79 revalidation. The old frozen MCP failure remains untouched. The next task is:

`PR90_CURSOR_INSTRUMENTATION_FORMAL_AUTHORIZATION_AND_79_GATE_REVALIDATION`
