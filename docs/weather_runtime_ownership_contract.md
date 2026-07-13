# Weather Runtime Ownership Contract

## Sprint 49 status

Sprint 49 completed the Weather Runtime hard cutover. `WeatherRuntimeController.tscn` is the sole production owner for weather state and behavior. `WeatherRuntimeWorldBridge.tscn` is a non-owning adapter to the existing shared RNG and existing world refresh, log, position, and callout methods. The legacy `main.gd` weather engine was deleted in the same change.

The authoritative gate remains `WeatherRuntimeCharacterizationBench.tscn`. It now runs 53 cases: the 40 Sprint 48 behavior observations plus 13 hard-cutover ownership checks.

## Authoritative state

`WeatherRuntimeController` owns:

- `weather_forecast`
- `active_weather_zones`
- `weather_sequence`
- the four production weather templates
- the 60-180 second forecast range
- the 75-135 second natural duration range
- the one-to-five district zone cap

The controller owns scheduling, neighbor-first selection, shared-RNG fallback selection, activation, overlap, expiration, district multiplier lookup, weather-card rewrites, public weather snapshots, and v1 save serialization.

## Scheduling and RNG order

Natural scheduling consumes the existing `main.rng` through `WeatherRuntimeWorldBridge.shared_rng()` in this order:

1. weather type
2. anchor district
3. forecast lead
4. duration
5. disconnected-zone fallback picks, only when required

The Controller never constructs, seeds, or randomizes another RNG. Destroyed districts are excluded. Zone selection expands through valid neighbors before random fallback.

## Activation and expiration order

Activation preserves the characterized order:

1. copy the pending forecast
2. stamp `started_at` and `ends_at`
3. append the active zone
4. clear the forecast slot
5. refresh city networks and product prices once
6. emit the public callout and log
7. schedule the next public forecast

Expiration removes only elapsed zones and performs one city/market refresh pair for the expiry batch.

## Multipliers

- `solar_storm`: production 1.08, transport 0.82, consumption 1.06
- `acid_rain`: production 0.82, transport 0.88, consumption 0.96
- `gravity_tide`: production 0.96, transport 1.10, ocean transport 1.26, consumption 1.02
- `magnetic_fog`: production 1.00, transport 0.92, consumption 0.90

Overlapping weather multipliers compose multiplicatively.

## External boundaries

- `AiRuntimeController` selects weather intent and target only. It reads templates and deterministic preview zones from `WeatherRuntimeController`.
- Card Resolution dispatches `weather_control` once to `WeatherRuntimeController.apply_weather_control()`.
- GDP and market owners consume weather multipliers; they do not own weather state or lifecycle.
- GameScreen, TopBar, and PlanetBoard consume public-safe weather ViewModel text.
- `EnvironmentBalanceModel` remains an Inspector/QA model and is not a production fallback.
- Monster wager and readonly pause continue to freeze planet time before `Coordinator.tick_weather()`.

## Save and privacy

Save version 1 retains the flat keys `weather_forecast`, `active_weather_zones`, and `weather_sequence`. `main.gd` preserves only the compatibility envelope; `WeatherRuntimeController.to_save_data()` and `apply_save_data()` own serialization and missing-key defaults.

Public and debug snapshots contain only pure data. They do not expose acting player identity, hidden owner, private target, private discard, or AI private plan.

## Deleted legacy owner

Sprint 49 removed the legacy weather state, six top-level constants, UI label mirrors, and 21 main functions, including scheduling, selection, activation, ticking, multiplier lookup, weather text assembly, and weather-card commit. No parallel main fallback remains.

The Sprint 48 baseline was 25,380 nonblank lines and 1,436 functions. Sprint 49 reduced `main.gd` to 25,039 nonblank lines and 1,415 functions before documentation and QA registry updates; the production weather deletion was 341 nonblank lines and 21 functions.

The v0.4 rules text mentions possible monster-movement and financial-risk weather effects. Those effects were not present in the characterized runtime, so Sprint 49 does not invent them. They require a future behavior characterization before extending the Controller.
