# Region Infrastructure Runtime Ownership Contract

Status: SS06-01 region infrastructure hard cutover landed. Facility-card authoring and the v0.6 continuous economy remain follow-up work.

## Baseline

- Immutable tag: `pre-v0.6-runtime-baseline`
- Commit: `c9c1b33841df3f96efe6a5b2a2132ed19e0effce`
- Branch: `rules/v06-runtime-integration`
- `main.gd`: 22,825 total lines, 20,163 nonblank lines, 1,287 functions.
- `main.gd` SHA-256: `7F4AF6CA535051FB5189BDCD4273B990CE996464BFBCBE756A43BA7381673A62`.

The baseline was imported and checked from an independent clean clone before the tag was created. The tag is immutable and is not a runtime selector.

## Observed v0.4/v0.5 Ownership

`main.gd` owns the legacy region dictionary fields `hp`, `damage`, and `destroyed`. `hp` is generated from map area and terrain rather than public facilities. `_damage_district()` owns a broad transaction:

1. Validate the target and mutate `damage`.
2. Record source/time, raise panic, and emit map presentation.
3. Set `destroyed` when `damage >= hp`.
4. Disrupt trade routes.
5. Settle destroyed-city GDP derivatives and warehouse futures.
6. Deactivate the embedded city and emit public feedback.
7. Refresh city networks.

`_repair_district()` directly reduces the same legacy `damage` field. Monster and Military controllers retain their own unit lifecycles but currently reach legacy district mutation through world callbacks. Several non-unit card paths also call `_damage_district()` or directly mutate `trade_route_damage`; those paths violate the v0.6 rule that only deployed Monster/Military units may damage regional shared HP.

The current city object also contains five v0.5 project slots, project shares/generation/tombstones, route damage, warehouse markers, and active/destroyed state. These are migration evidence, not v0.6 product state.

## Legacy Heat / Panic Retirement

v0.6 has no region heat or panic resource. The terms appear only in the rulebook's list of invalidated rules and in legacy v0.4 runtime/content evidence. The v0.6 Profile, Region schema, save envelope, receipts, and public snapshots must never add a `heat` or `panic` field.

SS06-01 must retire this concept across the whole active path, not merely hide one label:

- Delete the district `panic` writer/state from the new region owner and save shape.
- Remove heat from Monster targeting scores and public monster facts.
- Remove heat-triggered HP damage and all non-unit direct-HP routes.
- Remove player-facing Region Codex/Card Presentation heat chips, labels, tooltips, and accessibility text.
- Reauthor affected cards as v0.6 market, route, public-clue, or explicit monster-lure effects only when the rulebook supports that behavior; otherwise mark them blocked and exclude them from the v0.6 release catalog.
- Replace the unrelated dashboard phrase "商品热度" with an unambiguous market term such as "市场动向" so the retired mechanic cannot leak back through copy.

The legacy source inventory is frozen in `RegionInfrastructureCharacterizationRegistry.LEGACY_HEAT_OWNERSHIP`, and the hard requirement is frozen in `LEGACY_HEAT_DELETION_GATE`.

## SS06-01 Single Owner

SS06-01 must create one `RegionInfrastructureRuntimeController` and one non-owning world bridge. The Controller owns:

- Public facility roster, stable slot/facility IDs, rank, owner kind, owner index, and generation.
- Region `damage_taken`, ruin/revival lifecycle, and revision.
- Derived `max_hp = sum(active facility rank HP contribution)`.
- Build, upgrade, repair, unit-damage authorization, and atomic lifecycle receipts.
- Save/load for public facilities and region infrastructure.

The Controller must not own Monster/Military targeting, commodity flow, route planning, market settlement, card execution, presentation, or AI choice. Those systems exchange typed pure-data intents and receipts.

`main.gd` may retain at most 180 lines of region world adaptation and presentation forwarding. It may not retain a second HP formula, build/repair algorithm, project mutation engine, or wrapper farm for reflection tests.

## Damage And Lifecycle Ordering

Only `MonsterRuntimeController` and `MilitaryRuntimeController` may produce authorized shared-HP damage requests. Region Infrastructure applies one atomic receipt. Non-unit card/news/weather/finance paths must be converted to capacity, speed, price, rent, or availability effects, or explicitly retired.

For one timestamp the ordering is:

1. Locked intents.
2. Facility build/upgrade/repair.
3. Unit attacks.
4. Shared HP and ruin/revival lifecycle.
5. Route rebuild.
6. Continuous commodity flow.
7. Sale receipts.
8. Bankruptcy, belt visibility, and victory checks.

Warehouse derivative settlement, route refresh, GDP refresh, public events, and presentation consume the lifecycle receipt after infrastructure commits. They do not mutate HP.

## Save Boundary

The v0.6 envelope uses save version 3 and `ruleset_id = "v0.6"`. A v0.6 session stores public facilities and `damage_taken`; it never stores an independently writable `max_hp`. Legacy v0.4/v0.5 saves are recognized and backed up but cannot resume as v0.6. No facility ownership, rank, slot, installation, or shared HP may be inferred from legacy project/city data.

## Hard Deletion Gate For SS06-01

SS06-01 must delete old ownership in the same commit as the new owner and callers:

- At least 700 nonblank lines removed from `main.gd`.
- At least 24 functions removed from `main.gd`.
- Final `main.gd` no more than 19,463 nonblank lines and 1,263 functions.
- Region infrastructure adapters in `main.gd` no more than 180 lines.
- `_damage_district`, `_repair_district`, five-project mutation/snapshot helpers, city-active/project-share authority, legacy network destruction orchestration, and direct non-unit HP routes absent.
- Region heat/panic state, Monster heat scoring, heat-triggered damage, player-facing heat labels, and release-ready legacy heat cards absent.
- No parallel fallback and no one-line compatibility wrapper farm.

If the runtime cannot satisfy the gate without changing behavior outside the approved v0.6 contract, SS06-01 stops and reports the precise dependency. It does not leave two engines active.

## SS06-01 Cutover Evidence

The region infrastructure owner and non-owning bridge are now static children of `GameRuntimeCoordinator`:

- `RegionInfrastructureRuntimeController` owns the public facility roster, stable slot/facility generations, derived shared HP, authorized unit damage, repair, ruin/revival, exact-once receipts, and its pure-data save shape.
- `RegionInfrastructureWorldBridge` only maps current world indices to stable region IDs, submits typed intents, and forwards committed receipts.
- Monster and Military submit shared-HP damage through this bridge. Their old direct district/route mutation paths have no fallback to `main.gd`.
- `main.gd` keeps a 90-line read/presentation adapter. Its `hp`, `damage`, and `destroyed` dictionary fields are temporary view projections, not writable authority.

Hard-deletion result, measured from the immutable pre-v0.6 baseline:

| Metric | Baseline | After SS06-01 deletion | Delta |
|---|---:|---:|---:|
| Nonblank `main.gd` lines | 20,163 | 19,064 | -1,099 |
| `main.gd` functions | 1,287 | 1,248 | -39 |
| Top-level variables | 141 | 132 | -9 |
| Top-level constants | 204 | 200 | -4 |

Current `main.gd` SHA-256: `9C181FFF8FCB26D15942227C3388486404A867CE500027DF24A42E9E5FB1C727`.

The active `main.gd` path no longer contains heat/panic state, `_damage_district`, `_repair_district`, project-share snapshots, direct `trade_route_damage` mutation, anonymous `route_sabotage`, or a disabled direct-build compatibility action. Historical characterization tests and v0.4-only services may still mention these terms; they are evidence to retire or replace, not production fallback authority.

## SS06-01B Public Facility Cutover Evidence

The production card path now recognizes only `kind = "public_facility"` for region infrastructure construction. `GameRuntimeCoordinator.submit_public_facility_card()` validates that kind and routes one typed request through `RegionInfrastructureWorldBridge` to `RegionInfrastructureRuntimeController`. A legacy `city_development` card fails closed with `legacy_card_kind_retired`; there is no mapping, fallback, or second settlement owner.

The active `GameRuntimeCoordinator` composition no longer instances `CityDevelopmentRuntimeController` or `CityDevelopmentWorldBridge`. `main.gd` no longer owns the runtime card pack, guaranteed district supply, site legality, synthetic teaching-card placement, authored AI city expansion, or old settlement dispatch. Its only remaining `city_development` token removes the obsolete `city_development_guarantee_card` field while normalizing legacy district data.

Updated deletion result, measured from the immutable pre-v0.6 baseline:

| Metric | Baseline | After SS06-01B | Delta |
|---|---:|---:|---:|
| Nonblank `main.gd` lines | 20,163 | 18,854 | -1,309 |
| `main.gd` functions | 1,287 | 1,238 | -49 |
| Top-level variables | 141 | 131 | -10 |
| Top-level constants | 204 | 199 | -5 |

Current `main.gd` SHA-256: `9A2B63C3BCEEDB598D89BE21839110AD324E2BAD3F31ED90D24692983A6F1872`.

The old v0.4 controller scenes, source files, characterization benches, and reflection tests remain as historical migration evidence while concurrent UI/card QA work is active. They are not present in the production scene tree and are not a runtime fallback. Their physical deletion and test replacement are a separate cleanup gate after the concurrent test changes land.
