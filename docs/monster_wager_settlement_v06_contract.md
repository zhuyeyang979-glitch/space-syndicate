# Monster Wager Settlement Policy v0.6

## Scope and ownership

`MonsterWagerSettlementPolicyV06` is a stateless pure-data calculator. It validates one authoritative wager snapshot and returns deterministic cash/public-pool deltas plus a separately constructed public receipt. It never mutates cash, monsters, the historical public pool, window state, journals, or save data.

The existing wager/Monster runtime remains the only state owner. Production integration has one settlement boundary:

```gdscript
var result := MonsterWagerSettlementPolicyV06.settle(authoritative_snapshot)
```

The owner reserves every frozen commitment before resolving the wager-triggering attack, atomically applies `private_delta_receipt.participants[*].net_cash_delta`, adds the returned `public_pool_after` to any newer public-pool contributions, journals the `wager_id + revision + fingerprint` association for exact-once replay, and closes/checkpoints its existing lifecycle. This policy is not a transaction service or a second wager queue.

Ordinary spending reads that reservation through the scene-owned
`MonsterWagerCashCommitmentQueryPort`. The port combines the private
`WorldSessionState` cash snapshot with the owner's unresolved commitments but
stores neither. Wager settlement is the only path allowed to consume its own
commitment; cards, purchases, financial margins, penalties, storage debt and AI
business spending must use `available = total - unresolved commitments`.
Malformed commitment facts fail closed, while positive income remains legal.
See `docs/migration/monster_wager_cash_commitment_query_port_cutover.md`.

## Snapshot schema v1

The strict pure-data input contains:

- `schema_version=1`, non-empty `wager_id`, non-negative `revision`, and a SHA-256 `fingerprint`;
- `window={duration_seconds:15, mandatory:true, ready_can_close_early:true}`;
- `base_rate_bp`: 500-1000 inclusive in 100bp increments;
- non-negative integer `historical_public_pool`;
- at least two unique competitors: `{side_id, effective_damage}` with non-negative integer damage;
- participants: `{public_player_id, exact_cash, responded, selected_side_id, rate_bp}`.

Responded players select a legal side and use a final rate from the base through 2000bp in 100bp increments. A missing response uses `responded=false`, an empty side, and the base rate. Participant and competitor dictionaries reject unknown fields, including AI plans/scores.

`fingerprint_for_snapshot(snapshot)` hashes the canonical private binding without its `fingerprint`. Competitors and participants are ordered by stable public IDs before hashing, so input row order does not change replay identity. `settle()` rejects a mismatched fingerprint before producing any receipt.

## Stake and default-selection rules

Stake is calculated from private exact cash without an overflowing `cash * rate` multiplication:

```text
stake = floor(exact_cash × rate_bp / 10000)
```

The implementation uses quotient/remainder integer arithmetic. Positive cash that would round to zero stakes one minimum currency unit; zero cash stakes zero; stake never exceeds exact cash.

Responded stakes are totaled per public side first. Missing responses are processed in sorted `public_player_id` order; each chooses the current least-staked legal side and updates its total before the next default. Equal totals break by lexicographically smallest stable public `side_id`. Missing responses always use the base rate.

## Settlement rules

With positive effective damage:

```text
settlement_pool = historical_public_pool + 2 × sum(current stakes)
winner_self_return = 2 × that winner's own stake
remaining_bonus = settlement_pool - sum(winner_self_return)
remaining_bonus_each = floor(remaining_bonus / winner_count)
public_pool_after = remaining_bonus mod winner_count
```

Every side tied for maximum positive effective damage is winning. Remaining bonus is equal per winning player, never proportional to stake. If maximum damage is positive but nobody selected a winning side, the entire settlement pool becomes `public_pool_after`.

If every side has zero effective damage, matching money is not created: original stakes are refunded, net player cash deltas are zero, and the historical public pool is unchanged.

All non-negative additions and doubling operations are checked against signed int64 bounds. Arithmetic overflow fails closed rather than wrapping.

## Battle lifecycle owner

The wager decision window and the monster battle are separate lifecycle phases:

- `decision`: a mandatory 15-second real-time forced decision window. This is
  the only phase that globally blocks ordinary table play.
- `battle`: a world-effective monster battle phase capped at 60 seconds. Cards,
  purchases and other non-blocked gameplay can continue while the battle
  proceeds.
- `settling`: an owner-internal terminal phase used only to produce the
  exact-once settlement journal and public receipt.

Closing the 15-second decision window only freezes player commitments. It does
not debit cash, pay winners or resolve the wager. The owner keeps the frozen
opening-cash commitments reserved until the battle lifecycle ends. Settlement
occurs exactly once when the battle reaches its 60-second cap, a combatant is
down/expired/removed, or another owner-approved terminal condition is met.
Knockback distance, movement animation and hit presentation are not terminal
conditions by themselves.

The opening battle strike is applied through the typed runtime command path:

```text
MonsterRuntimeController
→ RuntimeCommandPipeline
→ MonsterActionCommandSink
→ SimulationMutationAuthority
→ MonsterRuntimeController
```

The sink accepts idempotent replay only when the command ID, wager ID,
settlement revision, actor UID, target UID, action index and action fingerprint
match the owner-recorded applied command. A reused command ID with different
combat bindings fails closed instead of being treated as a duplicate success.

`MonsterRuntimeController` remains the only wager lifecycle owner. Presentation
nodes can display the forced decision and battle summary, but cannot tick the
decision timer, tick the battle timer, apply damage, debit commitments, mutate
the public pool, or write settlement history.

## Receipts and privacy

Success returns:

- top-level binding identity and `private_delta_receipt` for the existing owners;
- `public_receipt`, constructed from an allowlisted schema containing public player IDs, choices, rates, stakes, damage, payouts, pool totals, outcome, and a public-only fingerprint.

The public receipt never copies the private snapshot fingerprint and never includes exact cash, post-settlement balances, true/hidden owner data, hands/discards, or AI score/plan metadata. Only `public_receipt` is player-facing; the top-level result and private delta receipt remain owner-side inputs.

Failure returns `ok=false`, a structured `reason_code`, empty private/public receipts, and no partial deltas.

## Evidence boundary

The pure-policy test covers settlement math, rate validation, int64-safe stakes, default choice, deterministic fingerprints/replay, fail-closed schemas, and recursive public privacy scanning. Production connection, whole-roster cash application, opening-cash save/load, pending-damage reservation, actor-scoped AI privacy, public-pool carry, strict terminal-journal binding, Main-negative gates and exact-once terminal replay are covered by `monster_wager_settlement_owner_cutover_test.gd` and `MonsterWagerSettlementOwnerBench.tscn`.

The 15-second decision / 60-second battle split, battle-phase non-freeze,
typed opening strike, save/load replay, forged duplicate rejection, early
downed-combatant settlement, combatant release, public privacy and Main-negative
tick gate are covered by
`monster_battle_lifecycle_owner_cutover_test.gd` and
`MonsterBattleLifecycleOwnerBench.tscn`.
