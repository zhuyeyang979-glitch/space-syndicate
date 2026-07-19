# Monster Card Actor Propagation Audit

## Authority chain

The authoritative card actor is frozen as `active_entry.player_index` by
`CardResolutionQueueRuntimeService`. `CardResolutionExecutionRuntimeService`
copies the detached active entry into its execution transaction, and
`CardEffectRuntimeRouter` validates that actor against `WorldSessionState`
before dispatch.

The former defect was the final Router-to-MonsterRuntime hop: the Router had
the validated index but passed only a player dictionary, while
`MonsterRuntimeController._summon_monster_from_card` reread the mutable table
selection. That could redirect ownership, control-cap checks, same-family
upgrades, and bound-skill grants when the inspected player changed.

## Cutover contract

- `CardEffectRuntimeRouter` passes the validated `player_index` explicitly.
- `MonsterRuntimeController` rejects an invalid actor before logging, RNG, or
  state mutation.
- Owner, cap, upgrade lookup, skill recipient, and scenario eligibility use
  the same explicit actor.
- Public card and monster presentation remains anonymous.
- No second execution journal or save field is introduced.

## Persistence evidence and remaining debt

Execution schema v3 persists complete inflight transactions, including the
active entry actor, so inflight execution actor roundtrip is proven. Queue
runtime checkpoints also retain the complete active entry. The formal save
registry still reports the pre-existing queue-only `apply_api_missing` debt;
therefore queue-only formal envelope cold restore is not claimed by this
cutover.
