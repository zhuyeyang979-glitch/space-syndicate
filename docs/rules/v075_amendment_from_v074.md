# V0.7.4 to V0.7.5 Combat Amendment

V0.7.5 changes only combat. It inherits the V0.7.4 dynamic planet, geography,
facility registry, warehouse, unified track, asset pips, application bootstrap,
privacy, Victory, and new-game-only boundaries without reinterpretation.

## Monster Sources And Cards

Monsters become persistent V0.7.5 combat sources. Every normal player has base
capacity one plus a typed Character Semantic modifier. Capacity loss blocks new
deployment but never destroys a source.

Monster cards remain normal DBG cards, but `deploy_or_upgrade` inference is
replaced by one prebound mode: `DEPLOY_NEW`, `REFRESH_EXISTING`,
`UPGRADE_EXISTING`, or `REPLACE_EXISTING`. Same-family rank I-IV refresh heals
25%, 50%, 75%, or 100% of maximum HP when the card cannot upgrade. A higher
rank upgrades and fully heals without resetting existing cooldowns. A
different-family replacement withdraws the old source without a kill reward.

## Preferred-Color Autonomy And Trample

The first catalog contains exactly six families and one explicit preferred
industry color per family. Runtime never infers that color from localized
names, legacy `resource_focus`, or model color.

Preferred color affects autonomous target matching only. Monster and military
normal-card primary color remains the value supplied by the existing unified
track color authority, and its action cost is `primary_asset_cost` on that
`track_primary_color`. A preferred color never recolors a card or its cost.

At each maintenance boundary, all active monsters plan from the same frozen
public snapshot. Candidate targets are enemy public factories, markets, and
warehouses with matching `industry_id`. Distance is dynamic adjacency shortest
path, never pixels, camera projection, array-index difference, polygon
vertices, or microcells. Missing targets expand search range; whole-map failure
enters hungry fallback to the nearest enemy public facility.

Ground movement applies capped per-region facility trample from integer
fixed-point spherical arc distance. Flying and teleport movement do not
trample. Default forced movement does not trample. Complexity and boundary
detail cannot change damage.

## Private Monster Skills

The inherited bound-action source list changes as follows:

```text
BOUND_ACTION_SOURCE_KINDS_BEFORE=[monster,military]
BOUND_ACTION_SOURCE_KINDS_AFTER=[monster]
MILITARY_BOUND_ACTION_ENABLED=false
MONSTER_SKILL_PUBLIC_BATCH_QUEUE_MEMBER=false
```

Monster skills remain bound to their source but leave the inherited public
batch-capacity behavior. They live only in the owner's private dock and never
enter the public queue, five normal action slots, hand, deck, discard,
commodity inventory, or merge flow.

A legal request resolves immediately when no atomic transaction is active, or
at the first safe receipt boundary otherwise. It cannot interrupt or roll back
another action and does not restore Counter windows. A source can use at most
one skill per batch. Only available unreserved assets may be reserved. An
accepted Fizzle refunds all skill assets, starts no cooldown, and consumes the
batch use.

The owner sees skill cards, costs, targets, and cooldown detail. Rivals see only
the monster, committed animation, public target, damage, and status result.

## One-Shot Military Missions

Military cards remain normal DBG cards and ordinary anonymous public batch
actions. They no longer create a persistent source, command cards, cooldown,
private skill dock, or separate control cap.

The task set is closed to `assault_region` and `assault_monster`.
`guard_region`, protection, defense, interception, and military-on-military
tasks are retired.

Region assault locks the region plus exact enemy facility generations. One
total card/rank damage budget is distributed one point at a time over the
stable locked order. It is never copied in full to each facility and never adds
a replacement target. Monster assault locks one exact source and generation,
attacks it once if still legal, and never retargets. Either mission then
withdraws and returns the card to personal discard for future reshuffle.

## Authority Cutover

One `V075CombatRuntimeOwner` owns monster sources, private skill state and
sequence, military transactions, and combat exact-once receipts. Pure Cores
plan transitions. Typed ports delegate map, asset, DBG, facility, Victory, and
checkpoint responsibilities.

Combat facility damage always uses `FacilityCombatDamageIntentV1`; Region
Infrastructure remains the only facility writer. Warehouse private stock and
logistics remain invisible.

The old V0.6 `MonsterRuntimeController` and `MilitaryRuntimeController` are
semantic inventory and pure-algorithm references only. Neither may be reachable
from V0.7.5 production composition, and no copied combat monolith or legacy
fallback may replace them.

## V0.7.4 Invariants

The ten-place shared sushi track keeps slow motion and acquisition vacancies.
Buying a combat card does not refill, slide, advance the supply cursor or
instance sequence, or draw supply RNG. Normal/Commodity supply remains
6000/4000 basis points. Six-color asset pips keep exactly six positions. The
dynamic 6-30 region globe, all three facility kinds, warehouse privacy, and
deleted `scripts/main.gd` remain intact.
