# V0.7.5 Military Semantic Inventory

This inventory treats V0.6 military code as authoring and algorithm evidence,
not as V0.7.5 production authority.

## Source Summary

The legacy card catalog contains seven stable military families and 28 I-IV
cards. The older runtime creates long-lived units, a separate control cap,
movement, terrain/weather modifiers, reusable bound commands, real-time
cooldowns, Guard repair, region strike, monster attack, and a military Save
payload. All 28 v06 records were still projection-only in the prior semantic
audit.

V0.7.5 keeps stable card identity and selected rank authoring but replaces the
runtime model with a one-shot mission transaction.

## Active Definitions

The first candidate activates three families already included in the prior
first-content selection:

| Stable definition | Legacy name | First-candidate role |
|---|---|---|
| `planetary_defense_force` | 行星防卫军 | balanced region assault |
| `air_superiority_fighter` | 制空战斗机 | stronger monster assault |
| `submarine_fleet` | 潜航舰队 | stronger region budget |

`orbital_bomber`, `heavy_tank`, `missile_emplacement`, and
`star_ocean_battleship` are deferred, not deleted. Three definitions are enough
to exercise both mission interfaces while staying below the maximum of four.

All three reuse the integrated rank model keys `model.military.tier1` through
`model.military.tier4`, `audio.military.action`, and the existing
`military_fire_line` event language. These are presentation-only.

Their normal-card color remains the value supplied by the existing unified
track color authority. Card action costs are `primary_asset_cost` on that
`track_primary_color`; mission type does not recolor or reinterpret the card.

## Retain Or Adapt

- Retain stable family/card IDs, I-IV rank and merge identity, normal DBG
  membership, anonymous public batch ownership, and exact-once command ideas.
- Adapt legacy rank damage gradients into V0.7.5 region budgets and one-shot
  monster damage. All numeric values live only in combat balance defaults.
- Adapt `strike_district` into `assault_region`, targeting exact locked enemy
  factories, markets, and warehouses through `FacilityCombatDamageIntentV1`.
- Adapt `attack_monster` into `assault_monster`, locking exact source instance,
  generation, revision, and public region with no retarget.
- After success or Fizzle, withdraw and return the card to personal discard for
  normal reshuffle.

## Presentation Only

Localized unit names, glyphs, motifs, commercial rank models, fire lines,
impacts, and military audio are presentation data. They cannot select missions,
targets, budgets, damage, or owner identity.

## Deferred

Four additional military families, terrain and weather combat modifiers, and
production Save migration are deferred. V0.7.5 adds no land/ocean combat
modifier and connects no production military Save owner.

## Retired Or Conflicting

The following cannot enter V0.7.5 production:

- persistent military sources, HP/duration timers, unit roster, and unit cap;
- Move, Guard, protection, defense, and interception tasks;
- reusable bound commands, military skill dock, and cooldown;
- direct shared-region HP mutation and full damage copied to every facility;
- resolution-time retargeting or selecting a new monster;
- military-on-military tasks;
- `MilitaryRuntimeController` as a production node, Save owner, or fallback.

The old Controller may be read to extract a pure damage or armor formula. Its
roster, dynamic callbacks, commands, and state machine must remain unreachable
from V0.7.5 production composition.
