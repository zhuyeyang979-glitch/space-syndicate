# Weather Runtime Ownership Contract

## Current v0.6 status

`WeatherRuntimeController.tscn` is the sole production owner for regional-weather lifecycle state. `WeatherRuntimeWorldBridge.tscn` is non-owning and exposes only the existing shared RNG and public world facts/actions. `WeatherPresentationRuntimeService`, `WeatherTelemetryRuntimeService`, ViewModels, overlays, and effect resolvers own no world state, clock, save section, or rules.

The active catalog contains exactly six data-driven definitions: `ion_storm`, `gravity_tide`, `spore_season`, `crystal_dust_storm`, `deep_freeze`, and `solar_flare`. The executable values live in `resources/weather/*.tres`; UI copy, tests, and reports must consume those resources instead of recreating a weather table in `main.gd`.

## Authoritative state

`WeatherRuntimeController` owns:

- the event roster and same-region waiting queue;
- event sequence, region-hit history, and next natural-generation timestamp;
- `queued`, `forecast`, `active`, `fading`, and `ended` transitions;
- source type (`natural`, `monster`, or `card`), while v1 natural generation is the default producer;
- the single existing `weather` save section and validate-then-commit restore path;
- public lifecycle snapshots and structured effect queries.

All time boundaries use the existing integer `world_effective_us` owner. Weather does not save a second clock or a solar/rotation phase. A true pause freezes that clock; opening the market does not.

## Lifecycle and selection

- New games have a 90-second grace period.
- Natural forecast generation is scheduled 90 to 150 world-effective seconds apart.
- Definition-authored forecast lead is clamped to 30 to 60 seconds.
- Definition-authored active duration is clamped to 45 to 90 seconds.
- Fade lasts 10 seconds and linearly reduces intensity to zero.
- At most two non-ended events may exist.
- Each event affects exactly one region in v1.
- A second event for an occupied region waits until that region is free.
- Selection uses public region activity and recent-hit history; it excludes destroyed regions and avoids immediate repeated hits.
- Final-settlement countdown disables new natural forecasts while allowing existing events to finish.

Natural selection is deterministic under the shared RNG, but no consumer or test may depend on the owner's internal RNG call order. Forecast/active durations come from definitions, not random duration rolls.

## Effect boundaries

`WeatherEffectResolver` starts from identity `1.0`, scales the delta by phase intensity and resistance, applies exploitation to positive deltas only, then applies channel guardrails.

- Economy contributions enter the existing production, demand, price-growth, and income chains; Weather never writes a final price.
- Route owners compute effective capacity with a 40% floor; Weather does not permanently damage route topology.
- Monster owners consume explicit family tags for preference, speed, and armor. Private weights and target identity remain hidden.
- Military owners consume explicit unit/movement tags for land, ocean, air, ranged, orbital, knockback, and flying-risk effects.
- Intel effects modify deterministic duration or range, not random success.
- Crystal-dust damage is the sole v1 weather-damage exception. The controller submits a nonlethal, capped environmental request to the existing region owner; it cannot destroy a healthy region.
- Ending an event restores every query to identity and leaves no permanent actor or route modifier.

## Presentation and telemetry

Presentation consumes pure public snapshots. The map overlay renders below district boundaries/cities and above the planet backdrop; routes, monsters, and selection remain above it. Region detail and economy contribution rows retain the same public `event_id` and player-facing weather label. Forecast notices are non-modal and can focus the affected region.

`WeatherTelemetryRuntimeService` is local-memory only, owns no save API, and has no network path. Its metrics are named for what they measure: price-growth contribution, route-efficiency contribution, anonymous forecast response, weather-influenced monster target scoring, applied region damage, and a conservative economic estimate derived only from committed public commodity-flow receipts. It stores no player identity, owner, exact cash, hand/discard, card identity, private target/weights, AI plan, save payload, or camera state.

## Save and privacy

Weather save schema v2 remains inside the existing 19-owner v0.6 envelope. It stores validated event timestamps/phases, affected regions, queue, next generation, sequence, recent-hit history, and lifecycle counters. It does not persist presentation state or outcome telemetry sessions, and the new history section does not duplicate weather state. Malformed payloads fail closed; legacy flat weather state may be conservatively cleared but must not resurrect retired timing or multiplier rules.

Public/debug snapshots and reports must remain pure data and viewer-invariant. The authoritative privacy gates reject private keys and sentinel values recursively.

## Main boundary

`main.gd` may advance the Coordinator, forward public snapshots to scene-owned UI, and record anonymous public response categories. It may not own definitions, lifecycle transitions, selection weights, effect formulas, weather save data, telemetry aggregation, or dynamic weather UI construction. No legacy weather fallback or wrapper farm may be restored.
