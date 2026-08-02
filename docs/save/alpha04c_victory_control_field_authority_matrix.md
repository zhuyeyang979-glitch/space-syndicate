# Alpha 0.4-C Victory Control Field Authority Matrix

`VictoryControlRuntimeController` remains the sole Victory owner. Save v3 and the
Registry-managed checkpoint compare only the authoritative projection: state,
per-player qualification elapsed, audit roster, audit remaining, outcome
sequence, and outcome receipt.

| Field | Authority | Restore policy | Persisted |
|---|---|---|---|
| `_state` | persisted authority | exact | yes |
| `_qualification_elapsed_by_player` | persisted authority | canonical player keys and bit-exact F64 | yes |
| `_audit_roster` | persisted authority | exact stable unique order | yes |
| `_audit_remaining_seconds` | persisted authority | bit-exact F64 except existing epsilon-to-zero rule | yes |
| `_outcome_sequence` | persisted authority | exact and bound to outcome ID | yes |
| `_outcome_receipt` | persisted authority | exact closed tree and strict identity | yes |
| `_last_candidates` | derived world fact | empty until a fresh typed world capture | no |
| `_last_player_assets` | private derived world fact | empty until a fresh typed world capture | no |
| `_last_victory_rule` | derived world fact | empty until recomputed from fresh regions | no |
| `_last_pause_reasons` | derived world fact | empty until the current barrier snapshot | no |
| `_last_settlement_checkpoint` | derived world fact | empty until a fresh endpoint snapshot | no |
| `_advance_count` | diagnostic only | zero | no |
| restore capture floor and gates | transient restore guards | rebuilt by apply | no |

The five cached world facts are intentionally excluded from Save. Persisting
them would retain stale candidates, private economic assets, an obsolete rules
projection, old pause state, or a pre-restore settlement checkpoint. A completed
Outcome receipt retains its own immutable audit evidence; that is persisted
authority and is distinct from the mutable `_last_*` caches.

The consumer audit found no gameplay, AI, UI authority, Receipt, Save, or
exact-once reader of `_advance_count`; its only reader is `debug_snapshot()`.
Derived caches do have gameplay and UI consumers, so they are not dismissed as
diagnostics: restore explicitly empties them and a monotonic WorldBridge capture
sequence gates their re-entry.

`VictoryAuthoritativeRestoreProjectionV1` decodes Save v3 and projects all six
persisted fields. It never uses `debug_snapshot()` as restore authority.
