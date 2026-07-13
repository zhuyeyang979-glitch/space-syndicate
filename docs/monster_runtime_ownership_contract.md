# Monster Runtime Ownership Contract

## Sprint 44 scope

Sprint 44 characterizes the monster world state and action lifecycle in the
real `main.tscn`. It deliberately does not create a Monster Runtime Service or
move production algorithms. The baseline is the deletion gate for a single
hard cutover in Sprint 45.

The v0.4 rulebook sections 3, 11, 14, and 15 are authoritative for the public
and private information boundary, purchase access, autonomous monster
behavior, and monster wagers. Authored catalog tables remain authoritative for
monster-specific HP, movement, ecology, actions, weights, damage, and bound
skills where the rulebook intentionally gives no numeric table.

## Current owner map

`main.gd` currently owns:

- the `auto_monsters` roster, UID/slot allocation, selected slot, timers, and
  special-action cursor;
- summon, same-family upgrade/refresh, binding limits, bound skill grants, and
  duration/revival lifecycle;
- target facts, weighted target selection, lure consumption, shared RNG use,
  terrain movement, linear motion, path pressure, and arrival hooks;
- action-table selection, rank-weight shifts, monster encounters, armor/HP
  damage, knockback, defeat, revival, and ownership-cash clues;
- active/resolved wagers, the public bid pool, forced bets, battle damage,
  refunds, payouts, and world-freeze behavior;
- monster and wager fields in the current save compatibility envelope.

Already scene-owned presentation remains outside this future runtime owner:

- `PlanetMonsterToken` renders public map markers;
- `MonsterCodexPublicSnapshotService` formats public bestiary data;
- `MonsterWagerDecisionPanel` renders the forced decision;
- `PlanetMapView` renders movement trails, event effects, and action callouts.

These components must not acquire monster rules during Sprint 45.

## Observed lifecycle ordering

### Summon and upgrade

1. Validate catalog entry, binding limit, district, and summon access.
2. Same-family cards upgrade or refresh the existing bound monster before a
   new binding is considered.
3. A new actor receives UID, slot, rank-scaled HP/movement, duration,
   position/world position, ecology fields, hidden owner, and passive state.
4. Economic boons and product prices refresh.
5. Bound fixed skills enter the summoner's private inventory.
6. Public callout/log and scenario hooks are forwarded without revealing the
   owner.

Upgrade restores HP and remaining lifetime, resets the owner-damage cash
meter, invalidates old bound skills, grants the current rank's skill set, and
preserves an owner clue that was already public. A rank-IV duplicate refreshes
rank IV; rank V is never created.

### Lifetime and roster

Remaining lifetime decreases with runtime delta. Expiry removes the monster
even when down, invalidates its bound skills, compacts slots, repairs selected
slot, and repairs the special-action cursor. Down monsters remain in the
roster until expiry but do not count as active and do not take automatic
actions.

### Target and movement

Target weight is the sum of base, panic, city, product competition, warehouse,
resource preference, distance, miasma, and rival-monster factors. Destroyed
districts are excluded. Weighted selection consumes the existing shared game
RNG; there is no monster-only RNG.

A lure overrides one selected destination and then erases its control fields.
Movement starts a linear-motion envelope rather than teleporting. Position is
committed to the destination district on arrival, after path/arrival pressure
and resource-drain hooks. Flying suppresses ordinary trample damage; terrain
multipliers and aquatic/flying movement remain catalog-driven.

### Combat and ownership clues

Range rejection is atomic. On a valid hit, armor is consumed before HP.
Reactive passives, HP damage, ownership-linked cash loss/clue, defeat/revival,
counter damage, and knockback then run in the existing order. A non-revival
monster at zero HP is marked down and stops acting.

The current authored runtime maps a bound monster's HP damage proportionally
to a capped owner cash pool, then reveals an ownership clue. This is public
only after that rule event; an unrevealed binding remains absent from public
map/Codex snapshots.

### Monster wager

An in-range monster encounter opens a wager before its pending attack deals
damage. While unresolved, the wager freezes planet simulation. The live v0.4
Ruleset profile supplies 20 seconds by default and a 30-second maximum.

The accumulated highest card-group bid moves into exactly one wager. Player
identity, side, percentage, and amount are public as required by section 15;
monster binding owner is not. A no-damage or tied result refunds player stakes
and retains the pre-existing public card-bid pool for the next valid wager.

## Save and privacy boundary

The current compatibility envelope retains roster, UID/cursor/selection,
timers, active and resolved wagers, wager sequence, public pool, and shared RNG
state. Missing legacy monster keys normalize to an empty roster and safe
defaults. Save data is private runtime state and is never copied wholesale to
UI, manifest, or report.

Public output may contain monster name, visible HP/down state, location,
movement/action effects, wager participants and public bets, and explicitly
revealed ownership clues. It must not contain an unrevealed owner, private
target, private discard, opponent hand, or AI private plan.

## Sprint 45 hard-cutover result

`MonsterRuntimeController` is now the scene-owned single owner and
`MonsterRuntimeWorldBridge` is its narrow, non-owning world boundary. Roster,
UID/selection, timers, summon/upgrade, lifecycle, target/shared-RNG ordering,
movement, combat, monster card commands, wagers, and the legacy-compatible
monster save envelope moved together.

The mapped `main.gd` function families, state fields, and monster runtime
constants were deleted in the same sprint. `main.gd` retains scheduling,
world facts/presentation hooks, dynamic property compatibility for old tools,
and save merge/apply adapters. Those adapters route to the controller and do
not contain a parallel monster algorithm.

The existing bench now combines the original 37 behavior records with 13
hard-cutover ownership records. It passes 50/50 while continuing to record
`observed`, `contract_aligned`, and `needs_design_decision` separately. A
mismatch must still be reviewed; production rules must never be changed merely
to make the gate green.
