# Military Runtime Ownership Contract

## Sprint 46 baseline and Sprint 47 cutover

Sprint 46 locked the observed behavior and deletion gate. Sprint 47 moved that
behavior as one unit into `MilitaryRuntimeController`, composed a non-owning
`MilitaryRuntimeWorldBridge`, and deleted the parallel state and algorithms
from `main.gd`. No military number or command order changed.

The v0.4 rulebook boundary is:

- A player normally controls one military unit; a role may increase that cap.
- Military units act only through fixed commands.
- Movement is realtime and causes no implicit trample damage.
- Explicit attacks may damage districts, routes, city GDP, or monsters.
- Military damage never causes owner-proportional cash loss.
- Public military commands and markers do not reveal the controller.

## Current owner

`MilitaryRuntimeController` now owns:

- `military_units` and `next_military_unit_uid`.
- Deployment validation, creation, cap handling, refresh, and removal.
- Linear movement start/arrival and realtime lifetime/cooldown ticks.
- Bound command definitions, ordering, labels, and grant orchestration.
- Guard, district strike, route pressure, GDP pressure, and monster attack
  command execution.
- The `military_units` and `next_military_unit_uid` v1 save keys.

`main.gd` retains only Controller lookup, pure world-fact access, existing
shared world mutation hooks, and public event forwarding. It has no fallback
roster or command engine.

## Seven runtime families

| Family | Domain | Deployment | Runtime identity |
| --- | --- | --- | --- |
| 行星防卫军 | mixed | any | short basic defense |
| 制空战斗机 | air | any | fast interception, light GDP pressure |
| 轨道轰炸机 | air | any | district, GDP, and route pressure |
| 重装坦克 | land | land | durable land defense |
| 导弹阵地 | land | land | low mobility, long range |
| 潜航舰队 | sea | ocean | fast ocean movement and route pressure |
| 星海战舰 | sea | ocean | durable ocean defense and bombardment |

All seven families have real I-IV assets. HP, damage, and duration do not
decrease as rank increases.

## Observed lifecycle ordering

### Deploy and refresh

1. Validate player, selected district, destruction state, and terrain.
2. Read rank and control cap.
3. If below cap, allocate `next_military_unit_uid`, then increment it.
4. If at cap, select the oldest owned unit and refresh it in place.
5. Copy card stats and reset HP, duration, position, and world position.
6. On refresh, invalidate old bound commands.
7. Grant the new command set through the inventory adapter.
8. Emit anonymous map/callout/log feedback.

Sprint 47 deliberately preserves the characterized cap behavior: deployment
at the cap atomically refreshes the shortest-remaining owned unit instead of
creating another unit. The misleading historical case id remains stable for
report compatibility; its contract now records replacement as the observed
runtime behavior.

### Realtime update and exit

1. Advance any active linear movement by meters per second.
2. On arrival, commit world position and recompute district index from map
   geometry.
3. Apply declared movement-arrival GDP pressure, but no district/route damage.
4. Clear linear-motion metadata.
5. Decrement lifetime and command cooldown.
6. If lifetime or HP reaches zero, invalidate bound commands and remove the
   unit. Array indices compact; surviving UIDs remain stable.

Wrapped-polygon arrival preserves the characterized behavior: world position
is exact, motion metadata clears, and district identity follows the existing
geometry lookup when overlap occurs.

### Commands

The stable command order is `move`, `guard`, `strike_district`,
`attack_monster`.

1. Resolve the bound unit, then verify ownership, movement, and cooldown.
2. Validate the selected target and command range.
3. Apply exactly one command-specific mutation.
4. Start command cooldown only after success.
5. Emit anonymous public feedback and refresh dependent world views.

`move` starts linear motion. `guard` repairs district/route pressure and lowers
panic. `strike_district` explicitly applies district damage, route pressure,
and temporary GDP pressure. `attack_monster` delegates armor/HP/down mutation
to `MonsterRuntimeController`.

## External ownership boundaries

- `AiRuntimeController` owns candidate scoring and intent selection only. Human
  and AI commands use the same world execution route.
- `CardInventoryRuntimeService` remains the only command-slot mutation owner.
  Persistent military commands are exempt from the ordinary five-card limit.
- `MonsterRuntimeController` remains the only owner of monster armor, HP, down
  state, lifecycle, and monster save data.
- Existing district, route, city GDP, balance, and presentation owners remain
  unchanged.

## GDP and damage observations

- Reapplying the same military pressure uses max semantics; it does not add the
  penalty twice.
- `military_pressure_until` is an absolute realtime expiry. The existing
  economy aging pass clears the penalty and source after expiry.
- Normal movement never changes district damage or route damage.
- District and route damage occur only on an explicit strike command.
- A zero-armor monster loses exactly one unit-damage amount per successful
  attack command.
- Invalid or down monster targets leave monster HP and unit cooldown unchanged.

## Save and privacy contract

Current saves still contain `military_units` and `next_military_unit_uid`. A
legacy save missing both keys restores an empty roster and UID 1. The keys are
now produced and consumed by `MilitaryRuntimeController`; save version 1 is
unchanged.

Public map markers, callouts, logs, debug records, manifests, and reports must
not expose owner, hidden target, private discard, or AI private plan. The owner
may count its own unrevealed unit; another viewer may not.

## Sprint 47 deletion result

Sprint 47 migrated together and deleted from `main.gd`:

- `military_units`, `next_military_unit_uid`, and the four military timing
  constants.
- Unit stat, terrain, presentation metadata, index, count, and cap helpers.
- Deployment, refresh, command grant/invalidation, update, and removal.
- GDP pressure and all four command execution branches.
- Military save capture/apply ownership and public visibility assembly.

The Controller does not absorb AI scoring, card inventory mutation, monster
damage rules, district/route algorithms, UI controls, or card resolution
orchestration. `CardInventoryRuntimeService` invalidates bound command slots;
`MonsterRuntimeController.take_external_damage()` is the sole monster HP
handoff. The 50-case gate verifies behavior parity, ownership, pure debug data,
save compatibility, and absence of the old `main.gd` engine.
