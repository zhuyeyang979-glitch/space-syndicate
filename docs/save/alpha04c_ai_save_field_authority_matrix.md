# AI Save Field Authority Matrix

Baseline: `351ee15100dea6f4185a511ee360ca005e1cdfa5`

Characterization evidence SHA-256:
`71946f1d82d09c0307f62fc786986741cbac5fffb0ace5ac8d6b3041fcc9e50c`.

The production AI owner has three distinct restore classes. Save v3 contains
persistent authority. Runtime Checkpoint v2 additionally captures bounded
diagnostics needed for an exact Registry rollback. The actor-state tick cache is
a single-tick derived cache and must be empty and inactive at every Save Barrier.

| State | Authority class | Save v3 | Runtime v2 | New session v3 | Restore contract |
|---|---|---:|---:|---:|---|
| Ruleset and policy attestations | `persisted_authority` | yes | yes | no | exact match before mutation |
| Request sequence | `persisted_authority` | yes | yes | yes | exact, non-regressing cursor |
| Three AI timers | `persisted_authority` | yes | yes | yes | `f64_bits_hex_v1` bit parity |
| AI decision enabled flag | `persisted_authority` | yes | yes | yes | exact Boolean |
| Player index and complete profile | `persisted_authority` | yes | yes | no | complete wire, no regeneration |
| Complete 37-field AI memory | `persisted_authority` | yes | yes | no | complete wire, no defaulting |
| Last receipt ring | `runtime_checkpoint_authority` | no | yes | yes | exact bounded diagnostic rollback |
| Rejection and timing counters | `runtime_checkpoint_authority` | no | yes | no | exact diagnostic rollback |
| Tick-cache hit/miss counters | `runtime_checkpoint_authority` | no | yes | no | exact diagnostic rollback |
| Actor-state tick cache | `derived_post_restore_state` | no | empty | no | reject active capture; restore empty |
| Actor-state tick-cache active flag | `derived_post_restore_state` | no | false | no | reject active capture; restore false |

## Profile And Memory

All six profile decision biases and every route preference use the shared
`ClosedSaveScalarCodecV1` F64 codec. The complete profile remains in each player
state. Reconstructing it from only a profile ID would lose the captured policy
state and could silently change behavior if the Resource changed after the save.

The complete memory includes decision samples, action counts, last plan, economic
focus, strategic intent, route plan, phase/posture observations, learned policy
values and counters, episode-learning observations, and training metadata.
Learned values and decision-sample float leaves preserve their exact F64 bits.
No sample, plan, ranking, learned tag, learned value, target, ID, private score,
or reversible value fingerprint is included in this matrix or characterization
evidence. The report retains only redacted structural paths and aggregate counts.

Some profile and memory fields are observational rather than direct scoring
inputs. They still remain persistent authority because `AiActorStatePort` hashes
the complete profile and memory dictionaries into the actor-state CAS revision.
Dropping or regenerating one changes conflict and duplicate-receipt behavior.

## Checkpoint-Only State

`last_receipts` is a bounded diagnostic ring. The consumer audit found no
gameplay, candidate-scoring, action-submission, or exact-once reader. It is not a
commit journal and cannot cause an action to run again. It is retained in both
checkpoint formats so Registry and new-session rollback restore diagnostic state
exactly.

Tick timing, pre-submit rejection, and cache hit/miss counters are diagnostics,
but Runtime Checkpoint v2 restores them exactly for rollback parity. They never
enter persistent Save v3.

The actor-state tick cache is read only while `_actor_state_tick_cache_active`
is true during one AI tick. Capture fails when it is active or nonempty. Restore
therefore canonicalizes the cache to an empty Dictionary and the active flag to
`false`; no cache payload crosses a Save Barrier.

## Closed Wire

Save v3, Runtime Checkpoint v2, and New Session Checkpoint v3 all use the one
`AiRuntimeSaveWireCodecV3` representation layer and the existing
`ClosedSaveScalarCodecV1`. No raw float, null, non-string Dictionary key, Object,
Resource, Node, Callable, or RID is accepted. Legacy persistent Save v1/v2 and
legacy checkpoints fail before mutation and require backup; they are not silently
interpreted as the new schemas.
