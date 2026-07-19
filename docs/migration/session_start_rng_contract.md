# Session-start RNG contract

Status: `GO_WITH_FROZEN_DEBT`

Scope: analysis-only contract for `SETUP SESSION START TRANSACTION CUTOVER` at
`2575fb4ac3192f8030c1719401531c582c9121c1`. This document freezes current
production behavior; it does not authorize a rules change.

## Findings first

1. **The current start path mutates the one live RNG before it knows that the
   new session can succeed.** `RunRngService` owns a single
   `RandomNumberGenerator` and increments its draw counter on every typed draw
   (`scripts/runtime/run_rng_service.gd:7-8`, `scripts/runtime/run_rng_service.gd:43-60`).
   `_new_game` resets live owners first, then generates market, roles and world
   directly from that stream (`scripts/main.gd:4373-4422`,
   `scripts/main.gd:4470-4505`). A failure after any of those calls leaves both
   old world state and RNG consumed. The transaction cutover must therefore
   plan against a detached cursor and commit one post-plan state only after all
   owner applies succeed.

2. **Application startup, not each new run, chooses the initial entropy.**
   `_ready()` calls `RunRngService.randomize()` once before opening the main menu
   (`scripts/main.gd:268-276`). `_new_game()` never calls `randomize`, `set_seed`
   or `restore_state`. A second run in the same process continues from the
   current authoritative stream. Re-randomizing for every new run would be a
   product behavior change and is forbidden by this cutover.

3. **Setup rendering is RNG-neutral; only unresolved AI role placeholders are
   random at Start.** Setup snapshots build cards and labels from configured
   indices (`scripts/main.gd:3524-3548`). A random AI role renders a static
   placeholder (`scripts/main.gd:4769-4791`) and is resolved only in
   `_resolve_configured_role_indices_for_run()` (`scripts/main.gd:7280-7313`).
   Query/render/refresh must stay at zero draws.

4. **Random roles are unique without replacement and are currently AI-only.**
   Normalization preserves `ROLE_RANDOM_INDEX == -1` only for AI seats and
   resolves every explicit role to the next unused catalog index
   (`scripts/main.gd:7174-7200`, `scripts/main.gd:7249-7257`). Start processes
   unresolved seats in ascending seat order, selecting from the remaining role
   indices without replacement (`scripts/main.gd:7283-7312`). Existing tests
   require eight-seat random AI roles to resolve to unique public roles
   (`tests/smoke_test.gd:1984-2012`,
   `tests/role_codex_public_contract_test.gd:112-140`).

5. **Starter-monster selection is not random in current production.** Each seat
   uses its configured catalog index; normalization only clamps it and does not
   enforce uniqueness (`scripts/main.gd:7215-7222`,
   `scripts/main.gd:7242-7246`). Card construction is a deterministic lookup
   (`scripts/main.gd:4965-4983`). Repeated starter monsters are therefore
   allowed, and starter selection remains independent from role identity
   (`tests/smoke_test.gd:4203-4220`). The AI-facing Setup text
   `random assignment / hidden until start` (`scripts/main.gd:3678-3707`) is
   misleading: the production value is configured and merely hidden. This is
   presentation debt, not permission to add an RNG draw.

6. **The current shared-stream draw order is observable game behavior.** The
   product market is randomized before random roles; world topology and region
   goods follow; the region supply captures an intermediate state as its
   deterministic gameplay seed; two price refreshes and the initial weather
   forecast then consume later draws (`scripts/main.gd:4396-4505`). A plan that
   groups random decisions by domain in a different order will change every
   downstream result even if each individual formula is unchanged.

7. **Region supply has a separate derived stream, not a second live RNG owner.**
   It receives the shared RNG state after world generation as `gameplay_seed`
   (`scripts/main.gd:4483-4490`), derives one state per stable region ID and
   builds deterministic weighted bags (`scripts/runtime/region_supply_runtime_controller.gd:45-99`,
   `scripts/runtime/region_supply_runtime_controller.gd:619-623`). Supply setup
   does not advance `RunRngService`; the exact intermediate seed must be stored
   in `SessionStartPlan`.

8. **Weather is randomized immediately at Start despite the ordinary 90-second
   generation grace.** Weather reset sets the normal next-generation gate to
   90 seconds (`scripts/runtime/weather_runtime_controller.gd:107-117`), but
   `_new_game` explicitly invokes `schedule_next_forecast(true)`
   (`scripts/main.gd:4499-4500`). That call selects a tied region, a weather
   definition and the next generation interval from the shared RNG
   (`scripts/runtime/weather_runtime_controller.gd:568-590`). Authored forecast
   and active durations are not randomized (`scripts/runtime/weather_runtime_controller.gd:1124-1133`).

## Current authoritative RNG

`GameRuntimeCoordinator.tscn` contains one `RunRngService` instance. Its public
state contract is:

- `state`: authoritative `RandomNumberGenerator.state`; assigning it calls
  `restore_state`, emits `state_restored`, and increments restore diagnostics
  (`scripts/runtime/run_rng_service.gd:10-18`,
  `scripts/runtime/run_rng_service.gd:36-40`).
- `randomize()`: external process-start entropy selection
  (`scripts/runtime/run_rng_service.gd:29-30`).
- `randi`, `randi_range`, `randf`, `randf_range`: authoritative draws; each
  increments `_draw_count` once (`scripts/runtime/run_rng_service.gd:43-60`).
- `to_save_data` / `apply_save_data`: persist the state, not draw count
  (`scripts/runtime/run_rng_service.gd:96-116`).
- `deterministic_weighted_shuffle`: a pure detached helper that accepts and
  returns a state and never changes the service instance
  (`scripts/runtime/run_rng_service.gd:63-93`).

AI, monster, product-market and weather bridges all consume this same service;
tests freeze that identity (`tests/run_rng_service_cutover_test.gd:40-62`). A
new Setup-local `RandomNumberGenerator`, RNG autoload or persisted draft seed
would create a forbidden second authority.

## Setup-time versus Start-time behavior

### Setup/query time: zero draws

The following operations are deterministic projections or draft edits and must
not consume RNG:

- opening or refreshing Setup;
- changing player count, AI count or challenge depth;
- stepping an explicit role;
- selecting the `-1` random-role placeholder;
- stepping a starter-monster catalog index;
- resizing/normalizing seat arrays;
- rendering role, starter-monster, option and summary cards.

Current evidence: page composition only calls configured/catalog helpers
(`scripts/main.gd:3524-3548`, `scripts/main.gd:3678-3772`); role and starter
commands write settings and request presentation refresh but perform no draw
(`scripts/main.gd:7249-7270`, `scripts/main.gd:7316-7330`). Settings persist the
placeholder/index values, not resolved random outputs
(`scripts/main.gd:3852-3892`).

### Start time: frozen draw sequence

For parity, `SessionStartPlanBuilder` must reproduce the following sequence
against a detached cursor initialized from the captured live state:

| Order | Draw family | Committed output | Evidence |
| ---: | --- | --- | --- |
| 1 | Product tier ticket then base-price draw for every product in catalog order | full initial product-market base prices and tiers | `scripts/main.gd:4396`; `scripts/runtime/product_market_runtime_controller.gd:159-168`, `scripts/runtime/product_market_runtime_controller.gd:216-241`, `scripts/runtime/product_market_runtime_controller.gd:863-871` |
| 2 | One `randi_range` per unresolved random AI seat, ascending seat order | resolved unique role indices/names | `scripts/main.gd:4420-4428`, `scripts/main.gd:7280-7313` |
| 3 | One region-count draw | target region count within depth bounds | `scripts/main.gd:3931-3940` |
| 4 | X/Y site draws per placement attempt, including rejected-too-close attempts and fallback points | ordered site coordinates, Voronoi polygons and centers | `scripts/main.gd:3976-3998` |
| 5 | Ocean ratio, seed-count, unique seed retries and neighbor-growth picks | ocean region index set | `scripts/main.gd:4181-4209` |
| 6 | One ocean-name offset | ocean names; land names remain fixed by index | `scripts/main.gd:3948-3952`, `scripts/main.gd:4053-4061` |
| 7 | Per-region focus/product/demand draws in region order | terrain economy focus, one product and one non-product demand per region | `scripts/main.gd:4027-4029`, `scripts/main.gd:4056-4100`, `scripts/main.gd:4236-4249` |
| 8 | No live draw: capture current cursor state | `region_supply_gameplay_seed`; all initial rack contents derived from it | `scripts/main.gd:4483-4490`; `scripts/runtime/region_supply_runtime_controller.gd:74-96` |
| 9 | One product-price noise draw per product, twice, preserving catalog order | final initial product prices/trends and price histories | `scripts/main.gd:4494`, `scripts/main.gd:4504`; `scripts/runtime/product_market_runtime_controller.gd:299-339` |
| 10 | Weather region tie-break, weather-definition choice, next-generation interval | initial public forecast and next weather generation time | `scripts/main.gd:4499-4500`; `scripts/runtime/weather_runtime_controller.gd:568-590`; `scripts/runtime/weather_system.gd:53-72`, `scripts/runtime/weather_system.gd:75-101` |
| 11 | No draw: capture final cursor state | `rng_post_state` committed after successful owner transaction | current `_new_game` later exposes the current state as session seed at `scripts/main.gd:4519-4529` |

Variable rejection loops are part of the algorithm. A plan cannot replace site
placement or unique ocean-seed retries with a fixed draw budget without changing
the generated world and downstream stream state.

## What is deterministic and does not consume Start RNG

- AI personality assignment is a wrap by AI order, not random
  (`scripts/runtime/ai_runtime_controller.gd:2952-2960`).
- Explicit roles and all starter monsters are catalog lookups.
- Player colors follow fixed seat order (`scripts/main.gd:97-106`).
- No field monster is spawned at start; players only receive their configured
  starter monster card (`scripts/main.gd:4428-4467`;
  `tests/smoke_test.gd:136-140`).
- Region infrastructure initialization only converts generated region facts
  into definitions (`scripts/main.gd:542-563`); it does not create random
  facilities.
- The commodity sushi belt is a deterministic rank-I catalog selection in fixed
  industry order (`scripts/runtime/commodity_card_inventory_runtime_controller.gd:255-304`).
- Region viability normalization is deterministic and may patch at most one
  demand after full validation (`scripts/main.gd:4111-4178`).
- Monster action timers are primed from fixed balance values, not `_roll_timer`
  (`scripts/main.gd:4414`, `scripts/main.gd:8238-8242`).
- Later AI choices, market cycles, weather generations and monster actions use
  the authoritative live stream, but they are runtime simulation, not
  SessionStartPlan inputs (`scripts/runtime/ai_runtime_controller.gd:7333`,
  `scripts/runtime/product_market_runtime_controller.gd:324`,
  `scripts/runtime/monster_runtime_controller.gd:3355`).

## Required detached cursor contract

`RunRngService` currently has replay-by-state but no atomic session-start fork or
compare-and-commit API. The cutover should add a narrow capability to that same
owner. Names may follow local conventions, but semantics must be equivalent:

1. `capture_plan_checkpoint()` returns detached pure data:
   `schema_version`, `rng_state`, and diagnostic `draw_count`.
2. Pure state-threading draw helpers accept a cursor state and return
   `{value, rng_state, draw_count_delta}` for integer and float ranges. They may
   use a temporary `RandomNumberGenerator` internally, as
   `deterministic_weighted_shuffle` already does, but the temporary object never
   escapes and owns no persisted state.
3. `SessionStartPlanBuilder` stores only the cursor dictionary while planning.
   It must not assign `RunRngService.state`, call live draw methods, or store an
   RNG Object in the plan.
4. `SessionStartPlan` records at least `rng_pre_state`, `rng_post_state`,
   `rng_draw_count_delta`, the intermediate `region_supply_gameplay_seed`, and a
   fingerprint binding these fields to the setup draft and all resolved outputs.
5. `preflight_plan_commit(expected_pre_state, post_state, fingerprint)` checks
   that the live state still equals `rng_pre_state`. A mismatch is
   `session_start_rng_state_stale` and applies nothing.
6. After all domain owners and `GameSessionRuntimeController` have applied
   successfully, `commit_plan_state` performs one compare-and-commit to
   `rng_post_state`. It increments live draw diagnostics by the planned delta
   without replaying draws and emits at most one explicit commit signal.
7. A transaction failure before RNG commit leaves live state and draw count
   byte-equivalent. If a fault can occur after RNG commit, the coordinator must
   checkpoint and restore both state and diagnostic draw count; the safer
   contract makes RNG commit the non-failing, preflighted final commit-only
   operation.

This is a fork of capability, not authority: `RunRngService` remains the only
live RNG owner, while the plan carries resolved pure data.

## Plan-output requirements

Every value selected by the detached cursor must be committed as explicit plan
data rather than re-drawn by an applying owner. At minimum:

- resolved role index/name per seat;
- starter-monster index/ID per seat (deterministic draft value);
- initial product-market entries after both current refreshes;
- region count, ordered sites, region IDs/names/polygons/centers/neighbors;
- terrain, economy focus, products and demands per region;
- the region-supply gameplay seed and deterministic rack checkpoint;
- initial weather event and next-generation timestamp;
- pre/post RNG states and planned draw count.

Owners must accept those resolved subplans. Calling `generate_product_market`,
`refresh_prices`, `_generate_roguelike_districts`, or
`schedule_next_forecast` against live RNG during apply would double-consume the
stream and violates the contract.

## Exact parity and failure gates

Required tests:

- same draft + same rules/catalog versions + same pre-state -> byte-equivalent
  plan and fingerprint;
- query/open/refresh/typed draft edits -> live state and draw count unchanged;
- failed planning, stale draft, stale active session and every transaction fault
  -> live state and draw count unchanged;
- successful start -> live state equals plan `rng_post_state` exactly;
- current sequential implementation and detached planner, starting from the
  same state, produce equal resolved roles, product market, world, supply seed,
  racks and initial weather;
- random roles remain unique and are processed in seat order;
- explicit roles consume no role draw;
- repeated starter-monster indices remain legal and consume no draw;
- role changes do not alter starter selections, and starter changes do not alter
  role resolution except through the expected shared-stream difference only
  when the role itself is random;
- failed active-session replacement preserves the old live RNG exactly;
- duplicate successful request returns the prior receipt with zero additional
  draws.

## Ambiguities and disposition

No ambiguity currently requires
`SETUP_SESSION_START_BLOCKED_BY_RNG_CONTRACT`; the executable behavior is
determinable and can be preserved.

Two debts must remain explicit:

1. AI starter-monster UI says `random assignment` although no RNG draw occurs.
   Preserve configured-index behavior in this cutover; a later product decision
   may change the text or authorize actual random selection.
2. The initial weather forecast bypasses the ordinary 90-second grace through
   an explicit start call. Preserve that call and its draw order; changing the
   first-weather timing belongs to weather product rules, not Setup extraction.

If implementation cannot produce resolved product-market, world and weather
subplans without invoking live owner draws, or cannot compare-and-commit the RNG
state without exposing partial state, then the correct result is
`SETUP_SESSION_START_BLOCKED_BY_RNG_CONTRACT` rather than a best-effort start.
