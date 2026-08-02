# Execution Restore Field Authority Matrix

Baseline: `d9ceda8196dbc6aa4152c63cd7ec5c9ed0be98ed`

The replay-v1 mismatch contains exactly two paths. Both are diagnostic state
written to describe a successful restore; neither controls gameplay, AI, player
UI authority, receipts, Save, exact-once behavior, or Transition planning.

| Field | Observed difference | Authority class | Restore comparison | Canonical result |
|---|---:|---|---|---|
| `$.owner_debug.last_phase` | yes | `diagnostic_ephemeral` | canonical only | `restored` |
| `$.owner_debug.last_reason` | yes | `diagnostic_ephemeral` | canonical only | `execution_lineage_restored` |
| `$.owner_debug.last_summary` | no | `diagnostic_ephemeral` | canonical only | empty Dictionary |
| operation counters | no | `diagnostic_ephemeral` | apply stability only | unchanged |
| collection counts | no | `derived_post_restore_state` | derive from Save v4 | restored collection sizes |

`V06SaveOwnerRegistry` observes selected private properties only to prove capture
purity. It does not serialize, restore, or interpret them. `_last_reason` is
explicitly excluded from that reflective purity observation.

The authoritative restore oracle is the complete canonical Save v4 wire plus
typed read-only consistency checks. It never uses `debug_snapshot()` as an
authority source. The two excluded paths are exact identifiers; no prefix,
wildcard, `last_*`, String, or complete-debug exclusion is permitted.

`last_phase`, `last_reason`, and `last_summary` must not be added to Save v4.
Doing so would change the exact-key wire contract and incorrectly promote QA
diagnostics into game authority.
