# Military and Weather Semantic Audit (Wave 1)

## Audit identity

- Baseline: `591b8e295e81ee5d475acd98b48b3b1639f71ec1`
- Upstream main observed by this worktree: `59756a291f811a064726f59aed27efecc3590c9a` (ancestor of the baseline)
- Branch: `codex/semantic-program-wave1-military-weather-591b8e2`
- Audit date: `2026-07-27`
- Scope: military definitions, live unit instances, bound commands, type/display maps, card readiness, weather definitions, live events, timing, random selection, AI/UI/diagnostic consumers, save identity, replay/idempotence, privacy, and RNG order.
- Production changes: none. Test changes: none. Catalog/rule/balance/RNG/save changes: none.
- Owned artifacts: this report and `reports/semantic_program/military_weather_semantic_audit.json` only.
- Method: static source tracing and deterministic catalog counting. Existing tests and reports were treated as supporting evidence, never as rule authority.

## Executive verdict

Military and weather are at very different migration points.

Military has one live state owner, `MilitaryRuntimeController`, but the live path still consumes the v0.4 card catalog and raw skill dictionaries. The v0.6 catalog already supplies 28 stable card IDs across seven families and compiles them to `deploy_unit` / `upgrade_same_family_unit`, yet all 28 remain `projection_only`. They cannot safely become active because the real owner has no unit-card prepare/commit/rollback/finalize contract, bound commands mutate player inventory in the same operation, and no authoritative unit profile owns the exact live stats. There is also a product-rule conflict: v0.6 targets an owned same-family unit, while the live v0.4 path refreshes the oldest owned unit of any family when the control cap is reached. This audit does not choose between those rules.

Weather already has a credible single live owner, a six-resource definition catalog, a pure effect resolver, a deterministic lifecycle, a validated transactional save section, and public privacy projections. Its main semantic debt is duplication around that good core: four hard-coded ID/name allowlists, controller-owned UI prose, a per-weather presentation switch, raw AI interpretation, a separate incompatible diagnostic weather model, fail-open unknown-ID fallbacks, and legacy aliases. The four v0.4 weather-control cards have no v0.6 semantic catalog records. Their authored lead/duration/zone fields currently match the resources, but the live card entry point ignores those fields and uses definition timing.

The safe target is two domain specifications sharing the program's semantic kernel, not one enlarged card schema:

- `MilitaryUnitSemanticSpec` owns immutable family/rank/deployment/command/rule and presentation references.
- `WeatherSemanticSpec` owns immutable definition/timing/effect/visibility/randomness and presentation references.
- `MilitaryRuntimeController` and `WeatherRuntimeController` remain the live instance/state-machine owners.
- Existing domain transactions and `WeatherEffectResolver` remain the execution mechanisms behind registered stable operation IDs.

Audit and staged design are ready. Military production cutover is blocked on rule authority and atomicity; weather schema/compiler work can begin without changing live behavior.

## Deterministic counts

| Inventory | Count | Evidence / method |
| --- | ---: | --- |
| Findings | 35 | `M-001` through `M-018`, `W-001` through `W-017` |
| Dispositions | 21 MOVE / 4 REMOVE / 10 KEEP | Same IDs in this report and JSON |
| Military findings | 18 | 13 MOVE / 1 REMOVE / 4 KEEP |
| Weather findings | 17 | 8 MOVE / 3 REMOVE / 6 KEEP |
| Blockers | 8 | `B-001` through `B-008` |
| v0.4 military families | 7 | `resources/cards/runtime/packs/07_military.tres:3-15` |
| v0.4 military authored ranks | 28 | Four `card_id` records in each family `055` through `061` |
| v0.4 military type IDs | 7 effective | Six explicit IDs plus the `defense` default; `scripts/runtime/military_runtime_controller.gd:182-223` |
| v0.6 military cards | 28 | Deterministic JSON query by `machine.effect_kind == deploy_or_upgrade_military` |
| v0.6 military families/ranks | 7 / 4 | Stable `family_id`; ranks 1-4; `data/cards/card_runtime_catalog_v06.json:22480-24572` |
| v0.6 military runtime readiness | 0 active / 28 projection-only | `scripts/cards/semantic/card_semantic_compiler_v1.gd:12-22` |
| v0.6 military payload keys | 7 | `military_family_id`, `card_rank`, and five profile/action readiness fields |
| Live military command kinds | 4 | `move`, `guard`, `strike_district`, `attack_monster`; `scripts/runtime/military_runtime_controller.gd:510-548` |
| Weather definition resources | 6 | `resources/weather/weather_definition_catalog_v1.tres:3-13` |
| Duplicate weather identity/validation catalogs | 4 | Controller, forecast VM, runtime telemetry, UI telemetry |
| Weather presentation definition switches/maps | 3 | Effect-row switch, icon map, pattern map |
| v0.4 weather-control cards | 4 | Families `018` through `021`; one authored rank each |
| v0.6 weather cards/effect kinds | 0 / 0 | Deterministic JSON query for category/effect/target containing `weather` |
| Weather definitions without a control card | 2 | `crystal_dust_storm`, `deep_freeze` |
| Current weather card timing parity | 4/4 | Each card lead/duration equals its referenced definition |
| Weather save schema | 2 | `scripts/runtime/weather_runtime_state.gd:4-21` |
| Valid new-session weather RNG draws | 3 | region tie, definition, next interval; `scripts/runtime/weather_runtime_controller.gd:120-185` |
| Valid natural-forecast RNG draws | 3 | region tie, definition, next interval; `scripts/runtime/weather_runtime_controller.gd:668-690` |
| Valid explicit-region weather-card RNG draws | 0 | `scripts/runtime/weather_runtime_controller.gd:350-362` |
| Dedicated military/weather recording-replay subsystem | 0 | No replay/recording source file; only save state and transaction-idempotence helpers exist |

Counts were produced from the frozen baseline with PowerShell JSON parsing and anchored regular-expression scans. No Godot scene or test was run because this task is a source audit and forbids production/test edits.

## Disposition meaning

- **REMOVE**: duplicate authority, fail-open fallback, localized inference, or incompatible diagnostic interpretation that must disappear after its replacement is live.
- **MOVE**: behavior/data remains, but authority moves into a semantic spec, typed projection, typed port, or operation registry.
- **KEEP**: legitimate state owner, state machine, transaction, compatibility behavior, privacy boundary, or exact rule/RNG/save behavior that must survive migration. A KEEP item may still need a typed interface around it.

## Military findings

| ID | Class | Finding and exact evidence | Required treatment |
| --- | --- | --- | --- |
| M-001 | MOVE | Production composition still declares the v0.4 card resource authoritative (`scenes/runtime/CardRuntimeCatalogService.tscn:3-9`; `scripts/runtime/card_runtime_catalog_service.gd:5-21`), the military owner accepts only `ruleset_id == v0.4` (`scripts/runtime/military_runtime_controller.gd:76-79`), and coordinator readiness also requires v0.4 (`scripts/runtime/game_runtime_coordinator.gd:515`). | Preserve all values while compiling one `MilitaryUnitSemanticSpec` catalog; retire v0.4 runtime authority only after parity and save migration. |
| M-002 | KEEP | The v0.6 catalog already has stable card/family/rank identity and 28 military cards (`data/cards/card_runtime_catalog_v06.json:22480-24572`). The compiler recognizes one exact effect/target pair but marks it projection-only (`scripts/cards/semantic/card_semantic_compiler_v1.gd:12-22`). | Keep these IDs and costs unchanged as card inputs. Do not reactivate them before the owner gate is green. |
| M-003 | MOVE | Every v0.6 military payload says the unit profile owns stats while the profile remains review-pending and runtime wiring is pending (`data/cards/card_runtime_catalog_v06.json:22503-22511`, `:22547-22552`; repeated for 28 cards). Exact live HP/damage/move/range/duration/pressure still live in v0.4 fields (`scripts/runtime/military_runtime_controller.gd:568-587`). | Establish one reviewed rank-profile table in `MilitaryUnitSemanticSpec`; the compiler must fail closed when a profile is absent. |
| M-004 | KEEP | The v0.6 target/compiler requires an actor-controlled same-family unit (`scripts/cards/semantic/card_semantic_compiler_v1.gd:449-450`, `:515-520`). Live v0.4 instead refreshes the oldest owned unit of any family at cap (`scripts/runtime/military_runtime_controller.gd:468-479`, `:594-627`). | Freeze the live behavior as an explicit compatibility operation until product authority chooses. Never silently reinterpret it as same-family upgrade. Blocker `B-001`. |
| M-005 | MOVE | `summon_from_card` mutates the unit roster/UID, invalidates old commands, mutates player inventory, emits visual/log effects, and refreshes presentation in one non-transactional call (`scripts/runtime/military_runtime_controller.gd:594-650`). The v0.6 forwarding port requires revision, prepare, commit, rollback, finalize, exact-once, and checkpoint capability (`scripts/cards/v06/units/unit_card_owner_forwarding_port_v06.gd:5-11`, `:37-66`). | Keep `MilitaryRuntimeController` as owner, but add owner-local staged mutation and make `CardInventoryRuntimeService` an explicit transaction participant. Commit-only presentation follows finalization. |
| M-006 | MOVE | Bound commands combine localized static definition, numeric rule data, persistent instance state, and `bound_military_uid` in generated player skill dictionaries (`scripts/runtime/military_runtime_controller.gd:510-565`). Unit creation copies raw skill semantics into each live instance (`:568-591`). | Put command definitions in the unit spec; keep only command instance ID, bound unit UID, cooldown/status, and source transaction in dynamic state. |
| M-007 | MOVE | Command invalidation rewrites saved card text and inserts a 9999-second lock (`scripts/runtime/card_inventory_runtime_service.gd:301-327`). | Preserve the effective invalidation result, but move reason/status to instance state and project text from stable reason IDs. Static semantic text must remain immutable. |
| M-008 | KEEP | `move`, `guard`, `strike_district`, and `attack_monster` form a legitimate owner state machine with target checks, cooldown, range, motion, region repair/damage, monster damage, and ordered post-effects (`scripts/runtime/military_runtime_controller.gd:665-787`). Movement timing is centralized in a domain model (`scripts/balance/movement_balance_model.gd:186-221`). | Keep the state machine and formulas byte-for-byte equivalent behind registered operations. Do not replace them with a generic card interpreter. |
| M-009 | MOVE | The live owner hard-codes type labels, glyphs, motifs, colors, domain labels, and terrain labels (`scripts/runtime/military_runtime_controller.gd:182-238`); the public map calls those presentation helpers (`scripts/presentation/table_public_map_query.gd:156-169`). | Move display metadata to the player projection of `MilitaryUnitSemanticSpec`. This is display hardcoding, not rule dispatch. |
| M-010 | MOVE | Rule values accept aliases and defaults such as `military_range -> range`, `military_damage -> damage`, and `move -> military_move` (`scripts/runtime/military_runtime_controller.gd:281-298`; `scripts/balance/movement_balance_model.gd:186-221`). | Resolve aliases once in the legacy compiler. Runtime handlers consume exact canonical rank-profile fields only. |
| M-011 | MOVE | Card execution routes by a central kind/effect switch and calls military/weather owners directly (`scripts/runtime/card_effect_runtime_router.gd:81-101`, `:129-165`). | Register stable operation IDs in `OperationHandlerRegistry`; retain the current military owner methods as handlers and preserve order/failure results. |
| M-012 | MOVE | AI can read the full private roster (`scripts/runtime/ai_runtime_controller.gd:884-886`), scores raw military payload fields (`:7412-7417`), performs type-specific deployment branches (`:7505-7609`), and reads live unit/command dictionaries directly (`:7629-7838`). | Supply viewer/actor-scoped `AiObservationSnapshot` plus `AiActionCandidate`; no raw skill or unrestricted roster access. Blocker `B-005`. |
| M-013 | MOVE | Generic diagnostics rescore military raw fields (`scripts/runtime/gameplay_balance_diagnostics_runtime_service.gd:112-159`, `:919-963`), while the military owner has a second type-role/gradient report and reconstructs card names (`scripts/runtime/military_runtime_controller.gd:790-898`). | Generate one standard diagnostic projection from the unit spec/rank profiles. Keep assertions, remove duplicate semantic interpretation. |
| M-014 | MOVE | Formal save marks military unsupported because strict preflight is absent (`scenes/runtime/V06SaveOwnerRegistry.tscn:98-103`). The owner blindly stores/restores raw unit dictionaries (`scripts/runtime/military_runtime_controller.gd:901-908`) whose identity includes localized `name`/`source_card` and `military_type` but no stable semantic family (`:568-587`, `:918-931`). Player slots separately persist `bound_military_uid` as arbitrary dictionaries (`scripts/runtime/world_session_envelope_codec.gd:26-90`, `:472-478`). | Add stable family/rank identity and strict preflight while retaining all existing save fields through explicit migration; validate cross-section unit-command references. Blockers `B-003`, `B-004`. |
| M-015 | KEEP | Weather effects are resolved centrally before military movement/range/knockback use (`scripts/runtime/military_runtime_controller.gd:310-389`). Guard/strike use the region-infrastructure owner and monster attack uses the runtime command pipeline (`:714-774`). | Keep these domain owners and exact formulas. Replace dynamic calls with typed ports only when parity tests cover each receipt. |
| M-016 | REMOVE | Card art infers military art from localized family-name substrings (`scripts/card_art_view.gd:488-493`), and the military diagnostic reconstructs localized rank card IDs (`scripts/runtime/military_runtime_controller.gd:873-881`). | Remove after presentation/diagnostic projections expose stable art and family/rank IDs. Names remain localization output only. |
| M-017 | MOVE | Main assembles military/weather presentation from raw skills and owner helpers (`scripts/main.gd:3129-3163`), reconstructs rules prose (`:4743-4762`), and classifies tags by kind (`:4858-4883`). `CardPresentationRuntimeService` repeats military/weather kind/field interpretation (`scripts/runtime/card_presentation_runtime_service.gd:433-567`, `:642-709`, `:753-882`). | Cut all consumers to `PlayerPresentationDTO`; do not add another Main helper or alias chain. |
| M-018 | MOVE | `MilitaryRuntimeWorldBridge` exposes generic property and method-name routing (`scripts/runtime/military_runtime_world_bridge.gd:38-90`), while the owner calls Main-shaped helpers for role, inventory, motion, geometry, and formatting (`scripts/runtime/military_runtime_controller.gd:483-646`, `:706-766`, `:948-1046`, `:1082-1091`). | Introduce narrow typed ports for world facts/motion/inventory; presentation formatting leaves the owner. Do not create a second military or world owner. |

## Weather findings

| ID | Class | Finding and exact evidence | Required treatment |
| --- | --- | --- | --- |
| W-001 | KEEP | The executable catalog is one ordered resource containing exactly six definitions (`resources/weather/weather_definition_catalog_v1.tres:3-13`). `WeatherDefinitionCatalog` provides exact lookup and validates uniqueness/count (`scripts/runtime/weather_definition_catalog.gd:8-58`); the resources own stable ASCII IDs and exact values (`resources/weather/ion_storm.tres:7-27`, `resources/weather/gravity_tide.tres:7-25`, `resources/weather/spore_season.tres:7-27`, `resources/weather/crystal_dust_storm.tres:7-29`, `resources/weather/deep_freeze.tres:7-28`, `resources/weather/solar_flare.tres:7-33`). | Keep the resources as compiler input and single value authority; compile immutable `WeatherSemanticSpec` records without changing order or values. |
| W-002 | REMOVE | `WeatherRuntimeController.WEATHER_TYPES` duplicates all six IDs and localized names beside the real catalog (`scripts/runtime/weather_runtime_controller.gd:16-23`); AI exposes that duplicate (`scripts/runtime/ai_runtime_controller.gd:1169-1171`). | Remove after callers query the semantic catalog/projection. |
| W-003 | MOVE | The forecast VM hard-codes six IDs plus icons/patterns (`scripts/viewmodels/weather_forecast_view_model.gd:10-23`), runtime telemetry duplicates IDs/names (`scripts/runtime/weather_telemetry_runtime_service.gd:18-33`), and UI telemetry duplicates the ID allowlist (`scripts/ui/weather/weather_telemetry_buffer.gd:8-30`). | Preserve strict validation, but generate/version allowlists and localized metadata from `WeatherSemanticSpec`; telemetry stores stable IDs only. |
| W-004 | MOVE | Four v0.4 one-rank weather-control families map raw fields to `solar_flare`, `spore_season`, `gravity_tide`, and `ion_storm` (`resources/cards/runtime/families/018_太阳风暴预报.tres:8-29`, `019_酸雨云团播种.tres:8-29`, `020_引力潮汐播报.tres:8-29`, `021_电磁雾干涉.tres:8-29`). No weather category/effect/target record exists in the 348-card v0.6 JSON, and weather is absent from the compiler contracts (`scripts/cards/semantic/card_semantic_compiler_v1.gd:12-23`). | Add a v0.6 card semantic operation that references a stable weather definition ID; do not copy weather effects into the card. Blocker `B-006`. |
| W-005 | REMOVE | Unknown IDs silently select the first weather definition in public scheduling, card application, internal scheduling, and legacy conversion (`scripts/runtime/weather_runtime_controller.gd:296-315`, `:350-362`, `:693-702`, `:946-977`). AI similarly falls back to the first ID (`scripts/runtime/ai_runtime_controller.gd:6980-6989`). | Unknown semantic IDs must fail closed before mutation and RNG use. Keep a versioned, explicit legacy migration map only for known old IDs. |
| W-006 | MOVE | Cards author zone/lead/duration, but the live card path uses definition timing directly (`scripts/runtime/weather_runtime_controller.gd:350-362`) and `_definition_forecast_us` / `_definition_active_us` ignore fallback arguments (`:1255-1264`). All four current values happen to match the resources, and all zone counts are one. | Compile the card as `schedule_weather_forecast(definition_id)` and make definition timing authoritative, or establish an explicit override policy. Remove inert duplicate fields only after a parity migration; no current value may change. |
| W-007 | KEEP | `_events`, `_queue`, `_history`, `_region_history`, sequence, telemetry, and next-generation time form the canonical live state (`scripts/runtime/weather_runtime_controller.gd:44-53`). Forecast/queued/active/fading/ended transitions and conflict queue release are deterministic (`:668-797`; `scripts/runtime/weather_system.gd:26-50`). | Keep `WeatherRuntimeController` as the only live weather owner and retain lifecycle ordering exactly. |
| W-008 | MOVE | Canonical events also carry legacy aliases `type` and `districts` (`scripts/runtime/weather_runtime_controller.gd:152-169`, `:712-729`), and runtime continually rebuilds `weather_forecast` / `active_weather_zones` plus accepts legacy entries (`:929-977`). `WeatherRuntimeState` accepts both region aliases (`scripts/runtime/weather_runtime_state.gd:22-44`, `:95-103`). | Confine aliases to one versioned load/UI adapter, then cut consumers to `definition_id` and `region_indices`. Preserve save schema v2 during this program stage. |
| W-009 | MOVE | `district_multiplier(index, key)` maps generic string keys and aliases back into economy/route/monster/military/intel domains (`scripts/runtime/weather_runtime_controller.gd:387-444`). | Replace consumer calls with typed `RuleExecutionPlan`/domain projections. Keep exact multiplication, floor, cap, and ordering in `WeatherEffectResolver`. |
| W-010 | MOVE | The weather owner builds player-facing status/forecast/impact prose (`scripts/runtime/weather_runtime_controller.gd:455-570`). Presentation separately switches on every definition to rebuild effect rows and maintains icon/pattern maps (`scripts/runtime/weather_presentation_runtime_service.gd:55-78`, `:157-197`, `:216-237`). | `WeatherSemanticSpec -> PlayerPresentationDTO`; UI renders stable localization/icon/pattern/effect tokens only. |
| W-011 | MOVE | AI interprets raw card fields and raw weather templates, selects type-specific strategy, and fail-opens unknown types (`scripts/runtime/ai_runtime_controller.gd:6980-7108`, `:7492-7503`, `:8095-8105`). | Project legal weather candidates and outcome dimensions from authorized public weather observations; retain the current scoring formula as parity oracle until cutover. |
| W-012 | REMOVE | `EnvironmentBalanceModel` defines incompatible timing (60-180 forecast, 75-180 active, 1-5 zones) and a second weather taxonomy (`storm`, `rain`, `drought`, `solar_wind`, `miasma`, etc.) with independent effects (`scripts/balance/environment_balance_model.gd:15-20`, `:34-49`, `:66-141`). The resource registry repeats those bands (`scripts/balance/runtime_balance_parameters_resource.gd:99-107`). | Remove this weather rules interpretation from diagnostics after standard semantic diagnostics exist. Keep unrelated market/volatility diagnostics. Blocker `B-007`. |
| W-013 | KEEP | `WeatherEffectResolver` centrally computes typed economy, route, monster, military, intel, and nonlethal capped damage effects (`scripts/runtime/weather_effect_resolver.gd:64-102`, `:105-257`). Commodity flow, market, routes, monsters, and military consume that projection (`scripts/runtime/commodity_flow_runtime_controller.gd:1765-1800`; `product_market_runtime_controller.gd:1982-2018`; `route_network_runtime_controller.gd:306-339`; `monster_runtime_controller.gd:3140-3173`; `military_runtime_controller.gd:310-389`). | Keep formulas and consumer order; register stable effect operations and gradually type the projection boundary. |
| W-014 | KEEP | Weather is a supported transactional save owner (`scenes/runtime/V06SaveOwnerRegistry.tscn:104-113`). Schema v2 validates exact keys, IDs, phases, queue consistency, histories, and telemetry (`scripts/runtime/weather_runtime_state.gd:106-200`); apply validates before mutation (`scripts/runtime/weather_runtime_controller.gd:585-624`). | Preserve schema v2, event ordering, IDs, timestamps, and rollback behavior. Semantic specs remain unsaved immutable catalog data. |
| W-015 | KEEP | New-session planning consumes detached RNG in this exact order: best-region tie, definition, next interval (`scripts/runtime/weather_runtime_controller.gd:120-185`). A valid natural forecast uses shared RNG in the same order (`:668-690`; `scripts/runtime/weather_system.gd:53-101`). A valid explicit-region card uses zero draws (`scripts/runtime/weather_runtime_controller.gd:350-362`). | Encode these draw contracts in `SemanticRandomnessPolicy` and parity tests; compilation/presentation/AI query consume zero RNG. |
| W-016 | MOVE | `preview_districts` delegates to mutating `pick_districts`; an invalid anchor can select a fallback with shared RNG (`scripts/runtime/weather_runtime_controller.gd:280-293`). Current AI iterates only alive anchors, so its present call path consumes zero draws (`scripts/runtime/ai_runtime_controller.gd:6996-7000`). | Add a pure preview/query operation that never touches RNG. Preserve current live scheduling draws separately. |
| W-017 | KEEP | Public weather events expose definition, phase, region, timing, intensity, and source type but no actor/hand/cash/private target (`scripts/runtime/weather_runtime_state.gd:247-271`). The forecast VM explicitly rejects private-key tokens and validates exact public shapes (`scripts/viewmodels/weather_forecast_view_model.gd:117-119`, `:487-626`); the world bridge builds public region facts (`scripts/runtime/weather_runtime_world_bridge.gd:86-128`). | Keep the public visibility boundary. AI receives only this projection plus actor-authorized card facts. |

## Display hardcoding versus rule dispatch

The migration must not equate every `match` with a rules bug.

| Concern | Current examples | Classification | Target |
| --- | --- | --- | --- |
| Display hardcoding | Military labels/glyphs/colors/motifs; weather icon/pattern/effect prose; Main card summaries | MOVE | Player/presentation projection with stable localization and art tokens |
| Cross-domain route switch | `CardEffectRuntimeRouter` maps kind/effect IDs to owners | MOVE | `OperationHandlerRegistry` registration |
| Legitimate military state machine | move, guard, strike region, attack monster, cooldown/range checks | KEEP | Same owner and order behind stable operations |
| Legitimate weather state machine | schedule, queue, forecast, active, fading, ended | KEEP | Same owner, event order, timestamps, and save identity |
| Legitimate weather rule resolver | context-filtered multipliers, floors/caps, nonlethal damage | KEEP | `WeatherSemanticSpec -> RuleExecutionPlan -> WeatherEffectResolver` |
| AI/diagnostic reinterpretation | raw type/payload scoring and alternate weather taxonomy | MOVE/REMOVE | AI/diagnostic projections from the same semantic spec |

## Proposed `MilitaryUnitSemanticSpec`

The spec is immutable pure data and contains no Node, Object, Callable, live UID, owner, position, HP remaining, cooldown, card slot, localized prose, AI score, or RNG callback.

```text
MilitaryUnitSemanticSpec
  schema_version
  semantic_identity
    unit_family_id
    source_card_family_id
    definition_revision
    content_fingerprint
  classification
    unit_type_id
    movement_domain_id
    trait_ids[]
  rank_profiles[1..4]
    max_hp
    damage
    movement_rating
    command_range_m
    presence_duration_seconds
    gdp_pressure
    gdp_pressure_seconds
    strike_gdp_pressure
    strike_route_damage
    bound_command_count
  deployment_policy
    target_spec_id
    terrain_filter_ids[]
    controller_scope_id
    control_cap_policy_id
    at_cap_policy_id
  terrain_movement_multipliers
  command_profile_ids[]
  weather_interaction
    resistance
    exploitation_multiplier
  visibility_policy_id
  randomness_policy_id
  presentation_refs
    name_key
    unit_type_label_key
    glyph_id
    motif_id
    color_token
    art_key
  legacy_identity_map
```

Dynamic state remains separate:

```text
MilitaryUnitInstanceState
  unit_uid
  unit_family_id
  rank
  owner_player_id
  region_id / world_position
  hp_remaining
  presence_remaining_us
  cooldown_remaining_us
  motion_state
  public_owner_revealed
  source_transaction_id

MilitaryCommandInstanceState
  command_instance_id
  command_profile_id
  bound_unit_uid
  owner_player_id
  cooldown/status
  source_transaction_id
```

### Military stable operations and handlers

| Operation ID | Handler owner | Notes |
| --- | --- | --- |
| `deploy_unit` | `MilitaryRuntimeController` | Creates one instance after full preflight/checkpoint; zero RNG. |
| `upgrade_same_family_unit` | `MilitaryRuntimeController` | Disabled until `B-001` and `B-002` are resolved. |
| `refresh_oldest_controlled_unit` | `MilitaryRuntimeController` | Explicit v0.4 compatibility operation only; never masquerades as same-family upgrade. |
| `military_move` | `MilitaryRuntimeController` + typed motion port | Preserve movement formula and weather multiplication. |
| `military_guard` | Military owner + region-infrastructure transaction | Preserve repair amount and cooldown ordering. |
| `military_strike_region` | Military owner + region-infrastructure transaction | Preserve shared-HP damage and route/GDP pressure. |
| `military_attack_monster` | Military owner + `RuntimeCommandPipeline` | Preserve target/range/privacy and monster damage receipt. |
| `military_remove_unit` | `MilitaryRuntimeController` | Invalidates bound commands transactionally. |
| `grant_bound_command_instance` | `CardInventoryRuntimeService` participant | Internal lifecycle operation; not a second card rule engine. |
| `invalidate_bound_command_instance` | `CardInventoryRuntimeService` participant | Instance status only; semantic definition remains immutable. |

## Proposed `WeatherSemanticSpec`

The existing six resources should compile directly into this immutable pure-data shape.

```text
WeatherSemanticSpec
  schema_version
  semantic_identity
    weather_definition_id
    definition_revision
    content_fingerprint
  timing
    forecast_duration_us
    active_duration_us
    fade_duration_us
  affected_region_count
  effect_operations[]
    operation_id
    subject_filter_ids[]
    multiplier / rate
    floor / cap
    intensity_policy_id
    resistance_policy_id
    exploitation_policy_id
  selection_policy
    natural_region_policy_id
    natural_definition_policy_id
    conflict_policy_id
  visibility_policy_id
  randomness_policy_id
  presentation_refs
    name_key
    description_key
    public_summary_key
    icon_id
    pattern_id
    color_token
    counterplay_key
    exploitation_key
```

Dynamic event state remains `WeatherEventInstanceState` and preserves save schema v2 fields: event ID, definition ID, region IDs, phase, source type, timestamps, duration snapshots, lifecycle/telemetry flags, and damage accounting. No dynamic field is written back to `WeatherSemanticSpec`.

### Weather stable operations and handlers

| Operation ID | Handler owner | Notes |
| --- | --- | --- |
| `schedule_weather_forecast` | `WeatherRuntimeController` | Card/monster explicit schedule; unknown IDs fail closed; valid explicit region uses zero RNG. |
| `select_natural_weather_forecast` | `WeatherSystem` pure policy + `WeatherRuntimeController` RNG authority | Exact region/definition/next-interval draw order. |
| `queue_weather_forecast` | `WeatherRuntimeController` | Preserve conflict queue and sequence allocation. |
| `activate_weather_event` | `WeatherRuntimeController` | Preserve timestamp and telemetry order. |
| `fade_weather_event` | `WeatherRuntimeController` / `WeatherSystem` | Time-derived phase, no RNG. |
| `end_weather_event` | `WeatherRuntimeController` | Preserve history and pending-damage behavior. |
| `resolve_weather_effects` | `WeatherEffectResolver` | Pure rule projection, no mutation/RNG. |
| `apply_nonlethal_capped_region_damage` | Region-infrastructure owner | Preserve accounting and cap semantics. |

Current multiplier fields compile into registered effect operation IDs such as `modify_product_price_growth`, `modify_production`, `modify_demand`, `modify_route_efficiency`, `modify_land_movement`, `modify_ocean_movement`, `modify_air_movement`, `modify_ranged_effect`, `modify_knockback`, `modify_orbital_effect`, `modify_city_maintenance`, `modify_monster_preference`, `modify_monster_speed`, `modify_monster_armor`, `modify_intel_duration`, `modify_intel_range`, `modify_flying_risk`, and `apply_nonlethal_capped_region_damage`. Unknown operation/filter/policy IDs fail closed.

## Visibility and randomness policies

### Military

- Compilation/query randomness: `none`; draw count zero.
- Deployment and command execution currently consume no RNG and must remain zero-RNG.
- Current live owner visibility is `owner_hidden_unless_revealed_or_self`: public roster removes `owner` and `private_target` (`scripts/runtime/military_runtime_controller.gd:165-174`), and debug projection reveals owner only to self or after a flag (`:918-931`).
- v0.6 player copy says owner/rank/position/public values are public (`data/cards/card_runtime_catalog_v06.json:22515-22526`). This differs from the live policy and is blocker `B-008`; migration must preserve live behavior until product authority resolves it.
- AI must receive actor-authorized own unit identity/commands and public opponent unit facts, never `roster_snapshot(true)` without a capability.

### Weather

- Definitions, forecast type, affected regions, phase, timings, intensity, and source category are public.
- Actor/card identity is not part of the public event DTO.
- Compilation, player projection, AI projection, effect resolution, lifecycle phase calculation, and valid explicit-region scheduling consume zero RNG.
- New-session and natural forecast policies declare three ordered draws. No sorting, filtering, or preview call may be inserted between those draws without an RNG-parity migration.
- A failed semantic validation must consume zero RNG and create no event.

## Save and replay identity

### Military

- Current raw save identity is insufficient: `uid`, localized `name`/`source_card`, rank, type, and copied stats are saved, but stable family identity is absent.
- Bound command instances are stored in player `slots` and refer to military state by `bound_military_uid`; this is a cross-section identity and rollback dependency.
- Formal v0.6 resume correctly remains unsupported until strict preflight and exact rollback exist.
- The v0.6 reference adapter has an exact-once transaction shape, but it is not production-composed and the real owner does not implement its methods. It is test/reference infrastructure, not a second live owner.
- Migration should add stable identity through an explicit save-version migration while retaining current fields until cold-restore parity proves removal safe. Do not add a second military save section.

### Weather

- Save schema v2 already uses stable `definition_id`, event IDs, phase, region IDs, timestamps, sequence, history, and damage accounting.
- `type`/`districts` are compatibility aliases and must remain readable while schema v2 is frozen.
- No dedicated recording/replay log exists. Upstream card-resolution idempotence currently prevents normal repeated application, but `WeatherRuntimeController` itself has no request journal. A future operation receipt can carry the existing resolution/transaction ID without changing weather definition identity; that work must be coordinated with save/replay owners.
- Semantic compilation must not consume RNG or alter saved event identity.

## Blockers

| ID | Domain | Blocker | Required decision/capability |
| --- | --- | --- | --- |
| B-001 | Military | v0.6 same-family upgrade conflicts with v0.4 refresh-oldest-any-family behavior. | Product/rule authority chooses one; until then the two operations remain distinct and production v0.6 stays fail-closed. |
| B-002 | Military | No reviewed authoritative unit profile owns exact rank stats for all seven families. | Establish profile values by parity with the current catalog; no inferred balancing. |
| B-003 | Military | Real owner lacks unit-card revision/prepare/commit/rollback/finalize/exact-once/checkpoint methods and strict save preflight. | Add narrow owner APIs and failure injection before activation. |
| B-004 | Military | Deploy/remove spans military roster and player bound-command inventory without cross-owner atomic rollback. | One transaction coordinates both owners and defers logs/UI until commit. |
| B-005 | Both | AI has no viewer/actor-scoped military/weather semantic observation boundary. | Add authorized observation and candidate projections before removing raw reads. |
| B-006 | Weather | v0.6 catalog/compiler has no weather card semantic effect. | Add a reference-only schedule operation that points to `WeatherSemanticSpec`. |
| B-007 | Weather | QA diagnostics contain a second incompatible weather taxonomy/timing/effect engine. | Standard semantic diagnostic projection replaces only that weather portion. |
| B-008 | Military | Live owner hides controller identity while v0.6 player text says ownership is public. | Product/visibility authority resolves; preserve live privacy until then. |

## Staged migration

1. **Freeze schemas and scans.** Add `MilitaryUnitSemanticSpec` / `WeatherSemanticSpec` validation, canonical fingerprints, unknown-ID fail-closed tests, and scans banning new localized dispatch/raw AI reads. No live path changes.
2. **Compile catalogs.** Compile the seven v0.4 military family/rank records into parity fixtures while the reviewed v0.6 unit profiles are established. Compile the six existing weather resources directly. Compilation is initialization-only and zero-RNG.
3. **Cut presentation.** Produce military/weather `PlayerPresentationDTO` values, move label/icon/pattern/effect prose, then atomically remove Main/UI raw inference and duplicate weather maps.
4. **Cut AI/diagnostics.** Add viewer-scoped observations and candidates, preserve existing score outputs as parity oracles, and replace the alternate diagnostic weather model with standard projections.
5. **Weather card semantics.** Add v0.6 schedule-card specs referencing the six-definition catalog; fail unknown IDs closed; preserve four current card results and zero-draw explicit scheduling.
6. **Military transaction.** Resolve blockers `B-001`, `B-002`, and `B-008`; implement real owner transaction stages plus bound-command inventory participation, reverse rollback, exact-once, and commit-only presentation.
7. **Save/replay migration.** Add stable military family/command identity with strict preflight; preserve weather schema v2 and RNG state/order. Run cold-restore and replay parity before removing aliases.
8. **Delete compatibility.** Remove v0.4 runtime authority, duplicate maps, localized inference, alternate diagnostics, raw AI reads, and aliases only when scans show zero production consumers.

## Non-negotiable preservation

- No rule or balance value changes.
- No military command or weather lifecycle order changes.
- No RNG draw count/order changes.
- No hidden-information expansion.
- No save root/section addition and no second state owner.
- No second rules engine for AI/training/diagnostics.
- No localized string, color, icon, or tooltip as rule identity.
- Unknown semantic IDs fail closed.
- Existing v0.6 military cards remain non-active until every blocker required for atomic production use is green.

## Deterministic scan recipe

The machine-readable companion records the exact counts and evidence. The principal reproducible scans were:

```powershell
# v0.6 military count/families/ranks/payload keys
$j = Get-Content -Raw data/cards/card_runtime_catalog_v06.json | ConvertFrom-Json
$m = @($j.cards | Where-Object { $_.machine.effect_kind -eq 'deploy_or_upgrade_military' })

# v0.4 authored military ranks
Get-ChildItem resources/cards/runtime/families |
  Where-Object Name -Match '^0(55|56|57|58|59|60|61)_'

# direct consumers and duplicate maps
rg -n 'military_(hp|damage|move|range|duration)|military_type|weather_type|WEATHER_TYPES|DEFINITION_IDS' scripts
```

The audit intentionally made no claim that implementation, save migration, or full-run replay is complete.
