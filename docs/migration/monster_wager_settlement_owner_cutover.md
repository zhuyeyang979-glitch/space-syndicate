# Monster Wager Settlement Owner Cutover

## Result

`MonsterRuntimeController` remains the only owner of active wagers, resolved
history, the carried public pool, the decision clock and wager save state.  The
existing stateless `MonsterWagerSettlementPolicyV06` is now its only production
settlement calculator; no second wager queue, cash owner or transaction service
was introduced.

## Frozen production contract

- One 15-second mandatory decision window.  Every eligible seat responding may
  close it early.
- One shared base rate sampled once per battle from 5%-10% through the existing
  authoritative `RunRngService`.
- Legal rates are every 1% step from that base through the hard 20% cap.
- The eligible roster and each seat's whole-unit opening cash are frozen when
  the window opens.  Already-eliminated seats are excluded; zero-cash seats are
  included with a zero stake.
- A response records a choice and public commitment only.  It does not mutate
  cash.  Closing the window builds one strict policy snapshot and applies every
  participant's net cash delta by one whole-array `WorldSessionState.players`
  swap.
- Every manual or deterministic-timeout commitment is reserved inside the
  wager owner. Pending monster-owner damage can spend only cash above that
  reservation, so resolving the triggering attack cannot strand a closed
  wager with `cash_insufficient`.
- Positive-damage settlement uses `historical pool + 2 × current stakes`.
  Every player on any side tied for maximum positive damage is a winner.  Each
  winner receives twice their own stake, then all winners equally split the
  remaining bonus; an integer remainder stays in the public pool.
- Positive damage with no correct bettor rolls the whole doubled pool forward.
  Zero effective damage refunds the original commitments, creates no matching
  money and preserves the historical public pool.
- A roster frozen at opening remains bound to settlement.  Later elimination
  does not cancel the wager, reverse elimination or restore participation.

## Exact-once and save boundary

The owner persists a monotonic settlement revision and a terminal journal bound
to `wager_id + revision + private fingerprint`. Save restore verifies the
dictionary key, terminal schema, wager/revision pair, public-receipt binding and
the public receipt's own SHA-256. Identical terminal replay is idempotent.
Active/terminal collisions, stale revisions, malformed opening-cash maps and
malformed journal rows fail closed during save restore. An unresolved wager
continues to hold the forced-decision block even after its choice window closes
until its atomic settlement succeeds.

AI wager planning consumes an actor-scoped query containing public wager facts
plus only that AI seat's own opening-cash snapshot. The former all-player
private active-wager snapshot API has been removed from production consumers.

## Retired paths

- Main `_get`/`_set` wager proxies.
- Main wager escrow helper.
- AI's setter for the owner's active wager array.
- 30% cap, five-visible-step UI, response-time cash lookup, float/ceil stake
  calculation, immediate response debit, unique-winner-only settlement and
  single-pool payout formula.

## Evidence

- `monster_wager_settlement_policy_v06_test.gd`: 77/77.
- `monster_wager_settlement_owner_cutover_test.gd`: 47/47, including pending
  damage reservation, actor-scoped AI privacy, forged journal rejection and
  terminal save/load replay.
- `monster_wager_response_cutover_test.gd`: 40/40.
- `MonsterWagerSettlementOwnerBench.tscn`: production owner scene and real
  settlement path.

This atomic boundary deliberately does not redesign the separate 60-second
monster combat lifecycle.  It removes the cash/formula ambiguity so a later
combat-duration boundary can decide exactly when the already-authoritative
settlement call occurs without changing payout math.
