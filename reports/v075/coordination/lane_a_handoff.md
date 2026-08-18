# V0.7.5 Lane A Handoff

Lane A is complete for coordinator integration. It changed only its exclusive
docs/data/report scope, created no Godot file, used no runtime editor, created no
extra branch/worktree, and performed no push.

## Outputs

- Closed V0.7.5 constitution and V0.7.4 amendment.
- Combat authority manifest with one `V075CombatRuntimeOwner`, six pure Cores,
  typed external ports, privacy allowlists, exact-once identity, and forbidden
  V0.6 Controller reachability.
- Combat balance defaults containing every numeric combat tunable.
- Monster and military legacy semantic inventories with explicit
  `retain`, `adapt_to_v075`, `presentation_only`, `defer`, `retired`, or
  `conflicts_with_v075` disposition.
- Active catalog with six monster families, 6/6 preferred colors, four skills
  per family, one L4 ultimate per family, and three military definitions using
  only `assault_region` and `assault_monster`.

## Active Monster Catalog

| Family | Preferred color | Movement profile | Model key |
|---|---|---|---|
| `spore_tide_emperor` | life | ground trample | `model.monster.life` |
| `meteor_sentinel` | energy | flying, no trample | `model.monster.energy` |
| `sand_armor_rover` | industry | ground trample | `model.monster.industry` |
| `blue_edge_knight` | technology | ground trample | `model.monster.technology` |
| `prism_blade_colossus` | commerce | ground trample | `model.monster.commerce` |
| `mirror_hunter` | shipping | teleport, no trample | `model.monster.shipping` |

`oasis_repairer` and `flame_ring_proto_star` remain deferred authoring. They
were not deleted or reinterpreted.

## Active Military Catalog

The first candidate uses `planetary_defense_force`,
`air_superiority_fighter`, and `submarine_fleet`. These were already selected
for the prior first content set and have complete I-IV authoring. Every one uses
the same two mission interfaces. Four additional legacy families remain
deferred.

There is no persistent military source, Guard, protection task, bound command,
skill dock, cooldown, follow-up command, or military-on-military mission.

## Balance Selection

Normal-card subtypes are `facility=7000`, `monster=1500`, and
`military=1500` basis points. This conservative first-sample split preserves a
70% facility core while giving both combat categories natural track presence.
It is frozen as the candidate default, not claimed as final commercial balance.
The coordinator must validate it in at least 2000 natural matches; simulation
must report rather than silently mutate the file.

The inherited global track ratio remains Normal/Commodity `6000/4000`, with
shared-scroll vacancies, slow sushi motion, and zero acquisition-time refill,
cursor advance, instance advance, or supply RNG draw.

Monster and military card action costs are explicitly
`track_primary_color + primary_asset_cost`. The color comes from the existing
unified-track color supply, not from monster preference. `mirror_hunter` is the
deliberate audit case: preferred target color `shipping`, card/cost color
`technology`. First-candidate private skill costs are also explicitly authored
on the source card's track primary color; the preferred-color field is never a
cost lookup key.

## Validation

Source-level validation parsed all seven JSON authorities and asserted:

- constitution rules: declared `30`, actual `30`, all unique;
- active monster families: `6`;
- preferred colors: `6/6`;
- active skill definitions: `24`, all unique and all balance-linked;
- every family: ranks `1,2,3,4`, exactly one rank-four ultimate;
- required skill fields missing: `0`;
- active military definitions: `3`, contract failures `0`;
- card primary-color/cost contract failures: `0`;
- subtype weight sum: `10000`;
- global track kind ratio unchanged: true.

Lane A does not claim runtime wiring, MCP evidence, simulations, or sample-match
completion. Those remain coordinator gates on the integrated same SHA.
