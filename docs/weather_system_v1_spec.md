# Regional Weather System v1

Status: integrated release candidate. Focused runtime, economy, route, monster, military/intel, presentation, telemetry, save/privacy, damage, and headed screenshot gates are accepted; full-project regression remains a release gate.

## Product Intent

Regional weather is a public, forecastable decision modifier. It connects the economy, routes, monsters, the map, and one military or intel channel without becoming a second combat system or a source of unexplained random punishment.

Every weather event must:

- announce its region, duration, three most important effects, exploitation hint, and counterplay hint before activation;
- create both an opportunity and a cost for at least one table position;
- use existing product, monster, unit, route, and card tags rather than matching display names;
- expose a structured public explanation wherever it changes a visible value;
- return every consumer to its identity multiplier when the event ends.

## Ownership

`WeatherRuntimeController` remains the only production owner of weather state and save data. It delegates pure calculations to:

- `WeatherDefinition`: one data-driven weather definition;
- `WeatherRuntimeState`: validation and public projection of one runtime event;
- `WeatherSystem`: pure lifecycle, queue, and region-selection transitions;
- `WeatherEffectResolver`: pure resistance, exploitation, intensity, and safety-cap calculations;
- `WeatherForecastViewModel`: public presentation snapshots;
- `WeatherTelemetry`: local-only event and outcome aggregation.

These helpers do not own an independent clock, save section, world state, or UI nodes. The existing `weather` section remains one of the 18 v0.6 save-owner sections. `main.gd` may coordinate and forward only; it must not contain weather definitions, lifecycle transitions, tag inference, price formulas, or UI construction.

## Time Contract

All lifecycle boundaries use the integer `world_effective_us` clock already owned by the game session.

- New games have a 90-second weather grace period.
- Natural forecasts are generated every 90 to 150 world-effective seconds.
- Forecast duration is 30 to 60 seconds.
- Active duration is 45 to 90 seconds.
- Fading duration is 10 seconds.
- A boundary is half-open: an event advances when `now_us >= phase_end_us`.
- True pause freezes weather because the authoritative clock does not advance.
- Opening a non-modal menu or market does not freeze weather unless the whole game is paused.
- Final-settlement countdown prevents new natural forecasts; existing events finish normally.

Phases are `queued`, `forecast`, `active`, `fading`, and `ended`. Active intensity is `1.0`. Fading intensity decreases linearly from `1.0` to `0.0`. Forecast and queued intensity are `0.0`.

At most two non-ended regional events may be scheduled concurrently. An affected region may have only one forecast, active, or fading event. A later conflicting event waits in the queue until the region is free. The natural selector prefers regions with active cities, routes, live monsters, or public trade activity, while penalizing recently hit regions.

## Weather Definitions

The first catalog contains exactly six definitions. Values below are balance bands; the resource files are the executable source of truth.

| ID | Display name | Primary opportunity | Primary risk |
| --- | --- | --- | --- |
| `ion_storm` | 离子风暴 | energy growth and air-route efficiency | flying-unit risk; electromagnetic monster speed |
| `gravity_tide` | 引力潮 | knockback and orbital effects | ocean and heavy-land movement efficiency |
| `spore_season` | 孢子季 | biological, medicine, and food production/demand | polluted-route efficiency; biological attraction |
| `crystal_dust_storm` | 晶尘暴 | crystal production | light capped region damage; ranged loss; crystal armor |
| `deep_freeze` | 极寒期 | food and energy demand | land movement and city-maintenance pressure; cold monster buffs |
| `solar_flare` | 太阳耀斑 | energy growth | electronics production and intel duration/range; energy monster actions |

Every definition includes the full field set requested by the v1 product specification: identity and copy, lifecycle durations, affected-region count, product tags and economy multipliers, route and movement multipliers, ranged and knockback multipliers, region damage rate, monster tags and multipliers, intel multiplier, and exploitation/counterplay hints. Presentation metadata such as icon and accent may be added, but rules may not be inferred from it.

## Effect Resolution

The resolver starts from an identity multiplier of `1.0` and scales only the weather delta:

1. phase intensity scales the delta from identity;
2. `weather_resistance` in `[0, 1]` reduces both positive and negative deltas for the protected target;
3. `weather_exploitation_multiplier >= 1` amplifies positive deltas only;
4. channel safety limits are applied last.

First-release safety limits:

- positive economic weather contribution: 10% to 30% of the affected baseline channel;
- route efficiency floor: `0.40`;
- monster speed ceiling: `1.30`;
- military and intel negative multiplier floor: `0.70`;
- no weather effect may directly mutate a final product price outside the market formula;
- no weather effect may leave a permanent actor, route, economy, or intel modifier.

Crystal-dust region damage is an explicit exception to the earlier no-weather-damage rule. It must route through the existing authoritative region-damage owner, be tagged as environmental weather damage, stop at a nonlethal floor, and obey a per-event cumulative cap. Weather alone may not destroy a healthy region. The weather resolver returns a damage request; it never writes region HP itself.

## Integration Boundaries

Economy owners consume tagged production, demand, and positive-price-growth contributions before their existing formulas run. Public price and income breakdowns include the weather contribution as one named component.

Route owners consume effective land, ocean, air, and generic efficiency multipliers. Weather does not permanently damage a route unless a separate authoritative damage request is explicitly defined.

Monster owners consume weather affinity and movement/armor/action modifiers by explicit tags. AI target scoring may include a public weather-benefit term, but Weather never selects a monster target and never exposes private target weights.

Military owners consume movement-domain, ranged, orbital, and knockback multipliers. Intel owners prefer deterministic duration or range modification over random failure. Public weather snapshots never expose private card success, hidden targets, hands, cash, owners, or AI plans.

Existing weather-control or route-forecast cards may call the explicit weather action API. They do not justify a new card family, name-based branching, or direct mutation of Weather state from `main.gd`.

## Public Presentation

The public snapshot allowlist contains event id, definition id, display name, icon/accent key, affected region ids, phase, remaining time, intensity, source type, up to three primary effect lines, exploitation hint, counterplay hint, and non-sensitive contribution lines.

The map uses a lightweight overlay that preserves region borders, cities, monsters, and routes. Region detail and economy overview consume the same event and contribution ids. Forecast notices are non-modal and provide a region-focus action. Reduced-motion mode replaces animated coverage with static icon, tint, and countdown states.

## Save And Telemetry

Weather save schema v2 lives inside the existing `weather` section. It stores validated definitions by id, event timestamps and phases, affected regions, waiting queue, next natural-generation time, sequence/history needed for repeat avoidance, and bounded lifecycle counters. It stores neither a second clock, UI state, nor outcome-telemetry sessions. Apply is validate-then-commit and fails closed on malformed data. Legacy v1 weather data may be conservatively migrated or cleared; it may not resurrect old timing or multiplier rules.

Telemetry remains local-memory only and is not a save owner. It records definition id, phase durations, affected regions, price-growth and route-efficiency contributions, forecast-response action categories, monster target-score influence, capped region damage, and an anonymous conservative economic estimate derived from committed public commodity-flow receipts. Deterministic acceptance reports must label missing realized currency as `N/A` and distinguish resolver-backed samples from observed human playtest data.

## Acceptance

The release is complete only when all six definitions are data driven; lifecycle, pause, save/restore, settlement stop, concurrency, queueing, and fade boundaries pass; economy, route, monster, and military or intel consumers restore to baseline after expiry; map, region, and economy surfaces explain the same facts; privacy scans pass; deterministic balance reports are generated; and no new Weather rules are added to `main.gd`.
