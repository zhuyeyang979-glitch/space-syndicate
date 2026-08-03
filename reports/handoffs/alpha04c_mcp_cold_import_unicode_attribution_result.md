# Alpha 0.4-C MCP cold-import Unicode/NUL attribution result

```text
STATUS=ALPHA_0_4_C_MCP_COLD_IMPORT_UNICODE_NUL_BASELINE_ATTRIBUTION_GATE_REPAIR_AND_EXACT_SHA_ACCEPTANCE_BLOCKED
TASK_ID=ALPHA_0_4_C_MCP_COLD_IMPORT_UNICODE_NUL_BASELINE_ATTRIBUTION_GATE_REPAIR_AND_EXACT_SHA_ACCEPTANCE
EFFECTIVE_MAIN_SHA=794ccf010e661a4750efca20a4e0d2a5839b7f2b
EFFECTIVE_PR77_HEAD=78c777010a75cdc1a8d407fde6705f9a51ac3b56
PRODUCTION_FAIL_CLOSED_FIX_COMMIT=3e73aaa8598ee0cfe3f9f97098db194679218f20
TARGET_PROJECT_TREE=db25e364d38b91f4725655475c44145a349ab262
```

## Attempt 2 remains immutable

Attempt `alpha04c-hand-zero-candidate-commit-a-exact-sha-attempt-2` remains
`BLOCKED_BY_UNCLASSIFIED_COLD_IMPORT_DIAGNOSTICS_AT_TIME_OF_RUN`.

Its authoritative editor stderr is 588 bytes with SHA-256
`7202ac2efe624bc7149b2aaa3cba600143b71ca36523dba04eb798e826deb21f`.
It contains six identical CRLF-framed records. Each framed SHA is
`adcbecf17b06b71d7a3754512d807614f232cb949e25de451225cb8c0dd6b3fb`;
each message SHA is
`660062b6986d3290250aac5ac714e8cc6529a65f909bf5e9dcfe15bd27448757`.
The file is strict UTF-8 and contains zero raw NUL bytes. U+FFFD is the literal
valid UTF-8 sequence emitted by Godot, not decoder fallback. Recovery import
independently contains nine copies. Wrapper artifact count is zero.

Full byte evidence is in
`reports/handoffs/alpha04c_mcp_attempt2_raw_diagnostic_attribution.json`.

## Three-cell cold-import matrix

The matrix used three external ephemeral mirrors. The frozen source worktrees
were never launched. Each mirror used the exact target addon tree
`3ee2dd169db12a2a99bb866d394b9a95ec107e78`; C0 records the addon as a Tooling
overlay, while C1/C2 were already byte-equivalent. Godot, renderer, PowerShell,
locale, launch template, timeouts, cache layout and raw capture were identical.

| Cell | Head | source tree | reload | changed-script discovery | editor/recovery/total diagnostics | raw NUL | parse/load/runtime | clean stop |
|---|---|---|---|---|---:|---:|---|---|
| C0 | `794ccf01` | `3b52cd84` | GREEN | expected presence 3/3 | 6/26/32 | 0 | 18/0/0 | GREEN |
| C1 | `510ebc3b` | `931afeea` | GREEN | 3/3 | 6/9/15 | 0 | 0/0/0 | GREEN |
| C2 | `3e73aaa8` | `db25e364` | GREEN | 3/3 | 9/9/18 | 0 | 0/0/0 | GREEN |

C0 recovery stderr contains eight Unicode events and eighteen real script
parse/load events. C1/C2 recovery stderr each contains nine Unicode events and
no real project error. Recovery is an independent authoritative stream and is
included in the final matrix gate; the Godot log is retained as an independent
mirror and is not double-counted.

C2 additionally emitted three Godot editor errors during the requested reload,
each followed by one non-diagnostic `at:` context line:

```text
ERROR: Task 'reimport' already exists.
ERROR: Condition "!tasks.has(p_task)" is true. Returning: canceled
ERROR: Condition "!tasks.has(p_task)" is true.
```

The three error records have framed SHA-256 values:

```text
8ce9f4c0abde5f9e1d48e0ad7d2c11003cf3c0699fe7e1e0873e37d903c473f4
861dc5bf078a93da892e723e0434bff438e9bb7feb5da596c63ff768abd27624
6a1c7bd4e649cebbc44b6ecfa11213048690e0d70230672279ce3469edbbeb78
```

They contain no project path, changed-file path, failed load, script parse, or
runtime correlation. They are nevertheless C2-only task-introduced diagnostic
events and therefore hard-block acceptance. Their presence also changes the
strict next-event context of the six Unicode records. The Unicode core bytes
match C0/C1, but strict baseline equivalence is false, so those six remain
`unclassified` rather than being accepted by message text.

```text
COLD_IMPORT_COMPARISON_ATTEMPT_COUNT=3
C0_DIAGNOSTIC_EVENT_COUNT=32
C1_DIAGNOSTIC_EVENT_COUNT=15
C2_DIAGNOSTIC_EVENT_COUNT=18
C0_EDITOR_DIAGNOSTIC_EVENT_COUNT=6
C1_EDITOR_DIAGNOSTIC_EVENT_COUNT=6
C2_EDITOR_DIAGNOSTIC_EVENT_COUNT=9
C0_RECOVERY_DIAGNOSTIC_EVENT_COUNT=26
C1_RECOVERY_DIAGNOSTIC_EVENT_COUNT=9
C2_RECOVERY_DIAGNOSTIC_EVENT_COUNT=9
C2_RAW_STDERR_RECORD_COUNT=12
BASELINE_DIAGNOSTIC_EQUIVALENT=false
TARGET_ADDITIONAL_DIAGNOSTIC_COUNT=3
TARGET_NON_EQUIVALENT_DIAGNOSTIC_COUNT=9
TARGET_CHANGED_FILE_DIAGNOSTIC_COUNT=0
MATRIX_REAL_PROJECT_ERROR_COUNT=18
MCP_BASELINE_ENGINE_DIAGNOSTIC_COUNT=9
MCP_WRAPPER_ARTIFACT_COUNT=0
MCP_REAL_PROJECT_ERROR_COUNT=0
MCP_CHANGED_FILE_ERROR_COUNT=0
MCP_TASK_INTRODUCED_ERROR_COUNT=3
MCP_RUNTIME_ERROR_COUNT=0
MCP_UNCLASSIFIED_DIAGNOSTIC_COUNT=6
```

Authoritative external evidence:

```text
E:\ss-mcp\alpha04c-mcp-cold-unicode-attribution-v2
```

```text
MATRIX_CAPTURE_TOOLING_RUNTIME_BUILD_SHA256=27868404c7f3f9e79ac94c09bf1c131af0fd806cb7deaf141debd0a70e1ecb9f
FINAL_CLASSIFIER_SOURCE_SHA256=c14b1a7e44620216161f30c4c83f9a541a35996aa63209fbea9532a93c7612eb
FINAL_CODE_ONLY_TOOLING_RUNTIME_BUILD_SHA256=4e7fbfce1db4ca09b571d8f234da5dd788e87aa4d6bae3431e2565ec6f83a310
```

The hashes intentionally differ: the matrix preserved the capture build, while
post-run fail-closed handling was repaired for Godot continuation lines and
empty stderr files. No second matrix was run, and the repaired build does not
claim that the old red matrix is GREEN.

The original matrix result is preserved. `reclassification_v2.json` only
reclassifies the same immutable raw logs after correcting continuation-line
handling; it records `real_attempt_count_added=0` and `raw_logs_mutated=false`.
For diagnostic event counts and the authorization decision,
`reclassification_v2.json` is the final authority. The earlier
`comparison.json` is retained as the capture-build historical result and is
never treated as GREEN.

## Tooling verification and stop boundary

```text
MCP_DIAGNOSTIC_CLASSIFICATION_TESTS=13/13
MCP_BASELINE_FINGERPRINT_TESTS=20/20
MCP_CHANGED_FILE_CORRELATION_TESTS=8/8
MCP_FALSE_NEGATIVE_GUARD_TESTS=22/22
MCP_DIAGNOSTIC_TOOLING_SELF_TEST_GREEN=true
MCP_DIAGNOSTIC_SELF_TEST_FALSE_ACCEPT_COUNT=0
MCP_DIAGNOSTIC_SELF_TEST_FALSE_REJECT_COUNT=0
MCP_SELF_TEST_PROCESS_COUNT_AFTER=0
MCP_SELF_TEST_ENDPOINT_COUNT_AFTER=0
```

Exact-SHA Attempt 3 was not authorized or consumed. Attempt 4 was not created.
No functional scene, Router 41/41, Bench migration, 40-case, FullRun, Smoke,
Formal, V8, Process A/B/C, Save, Main, AI, V0.7.3, production code, scene, or
resource change was performed.

```text
NEXT_TASK=ALPHA_0_4_C_MCP_COLD_IMPORT_UNICODE_DIAGNOSTIC_ATTRIBUTION_CONTINUATION
```

## Required final field ledger

`SELF` below denotes the independent commit containing this report; its exact
Git SHA is emitted by the final handoff because a commit cannot contain its own
hash.

```text
STATUS=ALPHA_0_4_C_MCP_COLD_IMPORT_UNICODE_NUL_BASELINE_ATTRIBUTION_GATE_REPAIR_AND_EXACT_SHA_ACCEPTANCE_BLOCKED

EFFECTIVE_MAIN_SHA=794ccf010e661a4750efca20a4e0d2a5839b7f2b
EFFECTIVE_PR77_HEAD=78c777010a75cdc1a8d407fde6705f9a51ac3b56

MCP_CREATION_TIME_WIRE_FIX_COMMIT=91bb931f9056d9e8277fee0a011e096f1b16d10e
PRODUCTION_FAIL_CLOSED_FIX_COMMIT=3e73aaa8598ee0cfe3f9f97098db194679218f20
TARGET_PROJECT_TREE=db25e364d38b91f4725655475c44145a349ab262

REQUESTED_SUBAGENTS=6
ACTUAL_MAX_CONCURRENT_SUBAGENTS=3

ATTEMPT_2_RESULT=BLOCKED
ATTEMPT_2_DIAGNOSTIC_COUNT=6
ATTEMPT_2_RAW_STDERR_NUL_COUNT=0
ATTEMPT_2_UNICODE_DIAGNOSTIC_RAW_FINGERPRINTS=adcbecf17b06b71d7a3754512d807614f232cb949e25de451225cb8c0dd6b3fb,adcbecf17b06b71d7a3754512d807614f232cb949e25de451225cb8c0dd6b3fb,adcbecf17b06b71d7a3754512d807614f232cb949e25de451225cb8c0dd6b3fb,adcbecf17b06b71d7a3754512d807614f232cb949e25de451225cb8c0dd6b3fb,adcbecf17b06b71d7a3754512d807614f232cb949e25de451225cb8c0dd6b3fb,adcbecf17b06b71d7a3754512d807614f232cb949e25de451225cb8c0dd6b3fb

C0_MAIN_COLD_IMPORT_DIAGNOSTIC_COUNT=32
C1_PARENT_COLD_IMPORT_DIAGNOSTIC_COUNT=15
C2_TARGET_COLD_IMPORT_DIAGNOSTIC_COUNT=18
C0_PROJECT_RELOAD_GREEN=true
C1_PROJECT_RELOAD_GREEN=true
C2_PROJECT_RELOAD_GREEN=true
BASELINE_DIAGNOSTIC_EQUIVALENT=false
TARGET_ADDITIONAL_DIAGNOSTIC_COUNT=3
TARGET_CHANGED_FILE_DIAGNOSTIC_COUNT=0

MCP_BASELINE_ENGINE_DIAGNOSTIC_COUNT=9
MCP_WRAPPER_ARTIFACT_COUNT=0
MCP_REAL_PROJECT_ERROR_COUNT=0
MCP_CHANGED_FILE_ERROR_COUNT=0
MCP_TASK_INTRODUCED_ERROR_COUNT=3
MCP_RUNTIME_ERROR_COUNT=0
MCP_UNCLASSIFIED_DIAGNOSTIC_COUNT=6

MCP_DIAGNOSTIC_CLASSIFICATION_TESTS=13/13
MCP_BASELINE_FINGERPRINT_TESTS=20/20
MCP_CHANGED_FILE_CORRELATION_TESTS=8/8
MCP_FALSE_NEGATIVE_GUARD_TESTS=22/22
MCP_UNICODE_DIAGNOSTIC_GATE_FIX_COMMIT=SELF
MCP_DIAGNOSTIC_TOOLING_SELF_TEST_GREEN=true

MCP_ACCEPTANCE_ATTEMPT_ID=none
EXACT_SHA_ATTEMPT_3_CONSUMED=false
MCP_TOOLING_COMMIT_SHA=SELF
MCP_PROJECT_CODE_COMMIT_SHA=3e73aaa8598ee0cfe3f9f97098db194679218f20
PRODUCTION_FIX_MCP_COMMIT_SHA_MATCH=true

PRODUCTION_FIX_MCP_PROJECT_RELOAD_GREEN=false
PRODUCTION_FIX_MCP_CHANGED_SCRIPT_VALIDATION=0/3
PRODUCTION_FIX_MCP_CHANGED_SCENE_LOAD=0/2
MCP_ZERO_CANDIDATE_STEAL_GREEN=false
MCP_ZERO_CANDIDATE_DISRUPT_GREEN=false
MCP_QUEUED_ONLY_TARGET_GREEN=false
MCP_LOCKED_ONLY_TARGET_GREEN=false
MCP_STALE_PLAN_REVALIDATION_GREEN=false
MCP_VALID_STEAL_TRANSFER_GREEN=false
MCP_VALID_STEAL_CONVERSION_GREEN=false
MCP_VALID_DISRUPT_GREEN=false
MCP_VALID_HIGH_RANK_LOCK_GREEN=false
MCP_ROUTER_INTEGRATION_TESTS=0/41

PRODUCTION_FIX_MCP_REAL_PROJECT_ERROR_COUNT=NOT_RUN
PRODUCTION_FIX_MCP_CHANGED_FILE_ERROR_COUNT=NOT_RUN
PRODUCTION_FIX_MCP_TASK_INTRODUCED_ERROR_COUNT=NOT_RUN
PRODUCTION_FIX_MCP_RUNTIME_ERROR_COUNT=NOT_RUN
PRODUCTION_FIX_MCP_BASELINE_DIAGNOSTIC_COUNT=NOT_RUN
PRODUCTION_FIX_MCP_UNCLASSIFIED_DIAGNOSTIC_COUNT=NOT_RUN
PRODUCTION_FIX_MCP_STOPPED_CLEANLY=false
PRODUCTION_FIX_MCP_PROCESS_COUNT_AFTER=0
PRODUCTION_FIX_MCP_ENDPOINT_COUNT_AFTER=0

PRODUCTION_FIX_COMMIT_CHANGED_AFTER_MCP_COUNT=0
HAND_INTERACTION_BENCH_MIGRATION_COMMIT=none
CARD_INVENTORY_BENCH_TOTAL=NOT_RUN
GODOT_PROJECT_CODE_CHANGE_COUNT=0
DIRECT_PROJECT_FILE_EDIT_COUNT=0
GAMEPLAY_RULE_CHANGE_COUNT=0
BALANCE_VALUE_CHANGE_COUNT=0
SAVE_SCHEMA_CHANGE_COUNT=0
SAVE_OWNER_CHANGE_COUNT=0
MAIN_GD_CHANGE_COUNT=0
CARD_EFFECT_ROUTER_CHANGE_COUNT=0
V073_RULE_CHANGE_COUNT=0
V073_PRODUCTION_CONNECTION_COUNT=0
TARGETED_OWNER_CAPTURE_DIAGNOSTIC_COUNT=7

V8_AUTHORIZATION_CREATED=false
V8_QUOTA_CLAIMED=false
PROCESS_A_SAVE_COMPLETION_REHEARSAL_COUNT=0
OFFICIAL_ATTEMPT_2_CLAIM_CREATED=false
PROCESS_B_STARTED=false
PROCESS_C_STARTED=false
THIRD_FORMAL_RUN_PERFORMED=false
FULL_SMOKE=false
SMOKE_TEST_SCRIPT_INVOCATION_COUNT=0

GIT_STATUS_TOOLING=clean
GIT_STATUS_PROJECT=clean
REMOTE_HEAD_MATCHES_LOCAL=true
PR77_DRAFT=true

NEXT_TASK=ALPHA_0_4_C_MCP_COLD_IMPORT_UNICODE_DIAGNOSTIC_ATTRIBUTION_CONTINUATION
```
