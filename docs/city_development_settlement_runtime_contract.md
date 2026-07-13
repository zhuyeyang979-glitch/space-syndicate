# City Development Settlement Runtime Contract

## Sprint 66 status

Sprint 66 completes the hard cutover. `CityDevelopmentRuntimeController` is the unique settlement planner and lifecycle owner; `CityDevelopmentWorldBridge` is a non-owning world adapter. The real-main gate reports **64/64 observed**, **64/64 contract aligned**, and **0 design decisions**. There is no parallel settlement algorithm in `main.gd`.

## Ownership

- `CityDevelopmentRuntimeController`: v0.4 legality, stable reason codes, pure planning, city/project/commerce staged mutation, validation precedence, opened/resolved lifecycle, and event intents.
- `CityDevelopmentWorldBridge`: pure world-fact capture, fingerprint preflight, exact sequence claim, atomic world commit/rollback, downstream refresh calls, and idempotent event application. It owns no rules or long-lived game state.
- `CityProductProjectState` / `CityProductProjectBridge`: project identity, contribution, shares, controller tie-break, legacy field synchronization, GDP allocation, and public/private projections.
- `CityTradeNetworkRuntimeController`: project sequence and network derivation.
- `ProductMarketRuntimeController`: product prices and market lifecycle.
- `GdpFormulaRuntimeController`: GDP arithmetic.
- `main.gd`: existing world facts, visual/event surfaces, card supply, and public/private snapshot adapters only.

Both runtime nodes are static children of `GameRuntimeCoordinator.tscn`. `main.tscn` has no direct Controller instance and no fallback city engine.

## Transaction order

1. Coordinator collects the real card-bound request.
2. WorldBridge captures pure facts plus a world fingerprint and downstream-owner readiness.
3. Controller validates player, district, terrain, local product, direction, source, and v0.4 direct-build prohibition.
4. Controller produces a pure staged plan; no player, district, network, market, RNG, ledger, or event state changes.
5. WorldBridge preflights the current fingerprint and project sequence.
6. Controller revalidates the plan against current facts.
7. Controller records `opened`; WorldBridge atomically claims one project sequence and applies the staged player/district deltas.
8. WorldBridge refreshes network, then market, then GDP, then project GDP allocation.
9. Controller records `resolved` and emits pure event intents.
10. WorldBridge applies private ledger, map effect, district pulse, anonymous public callout, First Table follow-up, and scenario signals exactly once by event receipt ID.

## Atomicity and rollback

Before claiming the sequence, WorldBridge snapshots players, districts, selected product, CityTradeNetwork save data, ProductMarket save data, and shared RNG state. Any failure after the claim restores all snapshots and invalidates the derived-network cache. Stale fingerprints, stale sequence values, missing downstream owners, invalid indices, and invalid plans fail before mutation with stable `reason_code` values.

The pure plan never replaces complete runtime world records. Commit applies only Controller-owned deltas to copies of the real player/district dictionaries, preserving typed `Vector2` and `Color` fields used by map and UI systems.

## Preserved behavior

- Project identity remains `district_index:product_id:direction`.
- First contribution receives 10,000 basis points and control.
- Repeated contribution strengthens the same project without incrementing `cities_built` again.
- Equal contribution splits 50/50; earliest contribution order retains control.
- First city adds 8 HP, repairs 2 damage, and records `built_at`.
- Commerce raises transport level by contribution units and recalculates transport score once.
- Production, demand, and commerce keep their legacy city projections synchronized.
- Current and legacy save shapes remain compatible without a save-version bump.
- Direct build action IDs remain rejection-only compatibility surfaces under v0.4.

## Privacy

The public receipt contains district, product, direction, project identity, current GDP, city-created state, and refresh order. It excludes player identity, owner/controller identity, contribution tables, share tables, private targets, private discards, and AI plans. Private economic details are event intents applied only to the relevant player's ledger.

## Deleted main.gd ownership

Sprint 66 removes the settlement body, target/normalization helpers, city-shell builder, direct creation helper, old build-error helpers, product/demand builders, lifecycle forwarding helpers, and duplicate city settlement constants. Reflection tests now use `tests/helpers/city_world_fixture_factory.gd`, which builds fixtures through a real authored city-development card and `GameRuntimeCoordinator.execute_city_development()`.

## Verification

- City Development Settlement hard-cutover gate: 64/64 observed and 64/64 aligned.
- The gate checks pure plan/preflight, all three directions, exact-once city/sequence/events, shares/tie-break, stale facts, downstream-owner rejection, rollback envelope, shared player/AI/First Table routing, save parity, privacy, migrated reflection tests, deleted legacy formulas, and unique composition.
- QA output: `user://space_syndicate_design_qa/city_development_settlement_characterization/`.
- Sprint screenshot: `user://space_syndicate_design_qa/city_development_settlement_hard_cutover_sprint_66.png`.

Project-local Godot MCP tooling is an editor/development aid and is not a player runtime dependency.
