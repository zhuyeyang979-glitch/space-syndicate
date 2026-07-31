# Alpha 0.4-C V4 ledger binding matrix

The machine-readable companion records all 35 ordered checks: exact field set,
raw ledger SHA-256, 32 ledger fields, and the cross-field nonce rule. The exact
retained V4 bytes pass the repaired canonical validator at `35/35`.

## First mismatch before repair

```text
FIRST_LEDGER_BINDING_MISMATCH_FIELD=schema_version
FIRST_LEDGER_BINDING_MISMATCH_REASON=godot_json_integer_materialized_as_float
EXPECTED_TYPE=int
ACTUAL_TYPE=float
```

PowerShell constructed `schema_version` as an integer and serialized it as the
JSON token `4`. Godot 4.7's `JSON.parse_string()` materialized that JSON number
as a `float`. The legacy validator required `TYPE_INT`, so it rejected the first
numeric field before examining any later value. The same latent runtime-type
mismatch affected:

- `authorized_new_diagnostic_count`
- `diagnostic_count_before`
- `diagnostic_count_after`
- `diagnostic_count_maximum`
- `orchestrator_process_id`

The canonical wire type is now `json_integer_number`. PowerShell requires an
actual integral CLR numeric type. GDScript accepts `int` or a finite, integral,
exact JSON-safe `float`, then compares the normalized integer value. Creation
ticks remain a decimal string because their 18-digit value is outside JSON's
portable exact-integer range.

## Ordered groups

| Checks | Result | Binding |
|---|---:|---|
| field set and raw ledger SHA-256 | 2/2 | Exact 32 fields and retained raw bytes |
| schema, ledger, authorization, task | 4/4 | Shared binding and authorization contracts |
| timestamp, run, HEAD, scenario | 4/4 | UTC shape and exact child options |
| six JSON integer fields | 6/6 | Integral and JSON-safe semantic integers |
| previous and historical identities | 4/4 | Exact shared contract literals |
| bootstrap and prequota evidence | 4/4 | Portable absolute paths and lower SHA-256 values |
| timeout and official boundaries | 6/6 | Exact option/authorization values and strict booleans |
| script, process, ticks, nonces, status | 8/8 | Typed shapes, option binding, and consumed state |
| claim/launch nonce inequality | 1/1 | Cross-field fail-closed rule |

The detailed JSON rows contain `field_id`, ledger/option/contract source,
expected and actual types, safe value fingerprints, normalization rule,
comparison kind, pass status, and typed failure reason. They contain no raw
nonce, full local path, Save content, or private Owner payload.

## Replay result

```text
V4_REPLAY_PRE_FIX_REASON=targeted_owner_capture_ledger_binding_invalid
V4_REPLAY_PRE_FIX_FIELD=schema_version
V4_RETAINED_LEDGER_REPLAY_GREEN=true
V4_CHILD_BOOTSTRAP_BINDING_GREEN=true
REPLAY_DIAGNOSTIC_COUNT_DELTA=0
REPLAY_QUOTA_CLAIM_COUNT=0
REPLAY_SESSION_CREATE_COUNT=0
REPLAY_SAVE_WRITE_COUNT=0
REPLAY_OWNER_CAPTURE_COUNT=0
```
