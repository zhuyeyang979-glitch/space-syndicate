# Content Authority Duality Audit

## Audit identity

- Baseline: `bd24b463660e55d83fc63deaab650c64c134be20`
- Branch: `codex/semantic-program-content-authority-bd24b46`
- Mode: read-only authority and bridge audit
- Production code, tests, catalogs, rules, balance, RNG, save, and existing reports changed: no
- Machine-readable companion: `reports/semantic_program/content_authority_duality_audit.json`
- Scope scanned: 530 production GDScript files, 273 production scenes, 206 Resource files, and 305 test GDScript files

## Executive conclusion

Production authority duality is confirmed.

The live game is not simply carrying old files beside a new catalog. The formal composition still enters through the v0.4 ruleset and requires `_ruleset_id == "v0.4"` for readiness, while the same coordinator directly preloads the v0.6 ruleset for region infrastructure, routes, commodity flow, weather, monster lifecycle, and victory. Card submission then chooses between v0.6 and legacy execution by inspecting the runtime card dictionary. The legacy effect router accepts both flat `kind` and layered `machine.effect_kind`.

The current production shape is therefore:

```text
RulesetRuntimeBridge(v0.4)
  -> GameRuntimeCoordinator overall composition gate
  -> CardRuntimeCatalogService(v0.4)
  -> legacy card definitions, requirements, AI, UI, diagnostics

GameRuntimeCoordinator direct preload(v0.6)
  -> v0.6 card JSON/resource and Alpha selection
  -> commodity/facility/supply-demand transactions
  -> selected v0.6 domain rules, weather, monster lifecycle, victory

CardPlaySubmissionRuntimeController
  -> runtime-shape check
     -> v0.6 path
     -> legacy path
```

No source can be safely deleted today. The target is not another manager. Each domain needs one immutable semantic authority, while existing runtime controllers keep live state and transaction custody.

## Deterministic totals

| Measure | Count |
| --- | ---: |
| Findings | 55 |
| REMOVE | 14 |
| MOVE | 22 |
| KEEP | 19 |
| Authority graph nodes | 37 |
| Authority graph edges | 44 |
| Audited domains | 8 |
| Blocking or major cutover risks | 14 |
| Compatibility readers that must remain | 7 |

The full ordered node/edge graph is in the JSON companion. Nodes and edges are sorted by stable IDs so repeated audits can diff the graph deterministically.

## Domain authorities

| Domain | Current production authority | Parallel source or bridge | One target authority | Current deletion blocker |
| --- | --- | --- | --- | --- |
| Card | v0.4 Resource graph through `CardRuntimeCatalogService`; partial v0.6 JSON consumers | Runtime-shape submission split, Main monster synthesis, financial enrichment, flat-kind routers | `CardSemanticSpec` compiled from v0.6 `machine` blocks and cached by `CardSemanticCatalogService` | 256 active / 92 projection-only semantic records; legacy inventory, AI, UI, diagnostics, finance, monster, and execution consumers remain |
| Role | `RoleCatalogRuntimeService._CATALOG` | Full role dictionaries copied into players/save and reinterpreted by AI, diagnostics, Codex, monster, and military | `RoleSemanticSpec` with stable ASCII `role_id`, emitted by the existing role owner | Save identity is index plus localized name; passive rule authority is incomplete |
| Monster | `MonsterCatalogV06` roster/action tables plus `MonsterRuntimeController` static tables | v0.4 card resources, Main name-based card synthesis, v0.6 card references | `MonsterSemanticSpec` plus `MonsterBehaviorSpec`, keyed by `monster_family_id` | Main callbacks, name joins, missing stable IDs in legacy instances, split weight tables, incomplete v0.6 transaction readiness |
| Product | `ProductMarketRuntimeController.PRODUCT_CATALOG/PRODUCT_PROFILES` and `ProductIndustryCatalogResource` | Same 46 IDs in different order; direct AI/UI/diagnostic reads | `ProductSemanticSpec` owned by the product-industry catalog with frozen order | Changing order changes deterministic market RNG assignment; localized IDs cross save, cards, routes, and market state |
| Facility | v0.6 card payloads, v0.6 Ruleset numeric profiles, and `RegionInfrastructureRuntimeController` allowlists | Adapter and schema repeat kind/profile rules | `FacilitySemanticSpec` keyed by stable facility kind | Numeric mirrors and unresolved rent profile; cards and owner do not yet share one profile reference |
| Military | v0.4 flat military card resources interpreted by `MilitaryRuntimeController` | v0.6 military cards exist but remain projection-only | `MilitaryUnitSemanticSpec` keyed by `military_family_id` | No complete authoritative unit profile or fully wired v0.6 transaction exists |
| Weather | `WeatherDefinitionCatalog` and six WeatherDefinition resources | Duplicate `WEATHER_TYPES` labels and a parallel diagnostic weather model | `WeatherSemanticSpec` projected from the existing catalog | AI compatibility property and diagnostics still read parallel maps |
| Victory | v0.6 Ruleset values plus v0.6 clock registry, consumed by one state owner | Controller repeats exact balance values in validation; v0.5 resources remain historical | One compiled `VictorySemanticSpec` consumed by `VictoryControlRuntimeController` | Schema boundary is missing; save/privacy/lifecycle owner must remain unchanged |

## Consumer matrix

| Domain | Runtime execution | AI | Player presentation | Diagnostics | Session start | Save/replay |
| --- | --- | --- | --- | --- | --- | --- |
| Card | Both v0.4 flat skills and v0.6 layered cards | v0.4 definition bridge and flat fields | v0.4 service, raw v0.6 flatteners, CardPresentation kind maps, and Card Codex target heuristics | Raw v0.4 catalog and reauthored formulas | v0.6 Alpha selection | Legacy flat and v0.6 layered instances coexist |
| Role | Catalog plus copied `role_card` | Catalog validation plus copied flat fields | Catalog and copied flat fields | Full definitions and ad hoc weights | Catalog indices | Full static definition copied into envelope |
| Monster | Catalog, runtime static tables, Main synthesis, v0.4 cards | Catalog/runtime internals | Catalog/runtime helpers | Main private callbacks and raw actions | Catalog plus v0.6 starter card | Live instances, some lacking stable family IDs |
| Product | Product market literals plus industry resource | Product market constants | Product market constants/profiles | Product market constants and Main callbacks | Product market order drives generation | Localized IDs and market state |
| Facility | v0.6 payload, Ruleset, adapter, region owner | Raw kind/profile fields | Raw kind/profile fields | Raw payload and Ruleset mirrors | Region owner plan | Region owner instances |
| Military | v0.4 flat cards and controller | Flat skill fields | Controller display switches | Flat fields | No semantic unit start plan | Controller live units |
| Weather | Catalog and controller | Public templates, plus duplicate compatibility property | Controller public snapshot | Parallel environment model | Catalog-based deterministic plan | Controller event state |
| Victory | v0.6 Ruleset, clock registry, controller | Controller projections | Controller projections | No separate content reader | Controller reset | Controller state plus fail-closed legacy inspection |

## Findings

`REMOVE` means the production duplication has no enduring role after parity. `MOVE` means semantics must move to the named target authority while state/transaction behavior stays with its owner. `KEEP` means the source is a legitimate owner, derived projection, selection manifest, compatibility reader, or explicitly non-production fixture.

| ID | Class | Finding and exact evidence |
| --- | --- | --- |
| CA-001 | REMOVE | v0.4 remains the global production card catalog: `scenes/runtime/CardRuntimeCatalogService.tscn:3-9`, `scripts/runtime/card_runtime_catalog_service.gd:5-21`, `resources/cards/runtime/card_runtime_catalog_v04.tres:3-21`. Remove it from composition only after all consumers reach zero. |
| CA-002 | MOVE | v0.6 `machine` data is the target static card authority: `resources/cards/runtime/card_runtime_catalog_v06.tres:3-10`, `scripts/cards/card_runtime_catalog_v06_resource.gd:24-55`, `data/cards/card_runtime_catalog_v06.json:1-7`. |
| CA-003 | KEEP | The semantic compiler/cache is deterministic derived data, not authoring or state: `scripts/cards/semantic/card_semantic_compiler_v1.gd:52-151`, `scripts/runtime/card_semantic_catalog_service.gd:37-90`. |
| CA-004 | KEEP | Alpha is a stable-ID selection manifest, not a definition source: `resources/content/alpha01/alpha01_content_manifest.gd:237-313`, `:455-493`. |
| CA-005 | KEEP | v0.5 card catalog is uncomposed migration evidence: `resources/cards/runtime/card_runtime_catalog_v05.tres:1-3`, `scripts/cards/card_runtime_catalog_v05_resource.gd:1-4`. |
| CA-006 | REMOVE | Submission selects v0.6 or legacy by card shape: `scripts/runtime/card_play_submission_runtime_controller.gd:60-109`, `:782-796`. |
| CA-007 | MOVE | Facility play has a second special v0.6 submission entry: `scripts/runtime/card_play_submission_runtime_controller.gd:112-161`, `:515-544`. Move to one typed plan path. |
| CA-008 | REMOVE | Definition bridge calls Main to obtain monster definitions: `scripts/runtime/card_runtime_definition_world_bridge.gd:31-43`, `:77-86`. |
| CA-009 | MOVE | Financial terms are mutably appended after catalog lookup: `scripts/runtime/card_runtime_definition_world_bridge.gd:66-74`, `:89-103`. Compile an immutable finance semantic reference. |
| CA-010 | REMOVE | Family/rank are inferred from localized ID suffixes: `scripts/cards/card_runtime_catalog_resource.gd:59-75`, `scripts/cards/card_play_requirement_policy.gd:94-106`. |
| CA-011 | MOVE | Play requirements are reauthored as kind tables: `scripts/cards/card_play_requirement_policy.gd:16-55`, `:116-140`. Move unchanged values to `SemanticCondition`. |
| CA-012 | MOVE | Effect router accepts both flat `kind` and `machine.effect_kind`: `scripts/runtime/card_effect_runtime_router.gd:44-101`, `:129-159`. Register handlers by `operation_id`. |
| CA-013 | MOVE | Core economic router is a valid transaction registry but is keyed by legacy effect kind: `scripts/cards/v06/production/core_economic_card_effect_router_v06.gd:4-45`. |
| CA-014 | MOVE | Balance diagnostics reinterprets raw card and role fields: `scripts/runtime/gameplay_balance_diagnostics_runtime_service.gd:64-234`, `:357-391`, `:889-930`. |
| CA-015 | REMOVE | Diagnostic bridge calls Main private methods and chooses named sample cards: `scripts/runtime/gameplay_balance_diagnostics_world_bridge.gd:53-88`, `:181-223`, `:306-315`. |
| CA-016 | MOVE | Coordinator combines a v0.4 session snapshot with direct v0.6 domain profiles: `scripts/runtime/game_runtime_coordinator.gd:9-22`, `:85-217`. |
| CA-017 | REMOVE | Composition readiness is still hard-gated to v0.4: `scripts/runtime/game_runtime_coordinator.gd:490-517`, `scripts/main.gd:273-283`. |
| CA-018 | MOVE | Region supply reparses raw v0.6 machine/payload fields: `scripts/runtime/game_runtime_coordinator.gd:5597-5620`. |
| CA-019 | KEEP | `RoleCatalogRuntimeService` is the one current static role source: `scripts/runtime/role_catalog_runtime_service.gd:37-359`, `scenes/runtime/RoleCatalogRuntimeService.tscn:3-7`. Refactor it in place. |
| CA-020 | MOVE | Role identity is array index plus localized name: `scripts/runtime/role_catalog_runtime_service.gd:268-294`, `scripts/runtime/world_session_envelope_codec.gd:448-468`. |
| CA-021 | REMOVE | Full role definitions are copied into live players and save: `scripts/runtime/session_start_plan_builder.gd:169-203`, `scripts/runtime/world_session_envelope_codec.gd:26-90`, `:389-438`. |
| CA-022 | MOVE | Multiple systems interpret flat passive fields: `scripts/runtime/gameplay_balance_diagnostics_runtime_service.gd:357-380`, `scripts/runtime/ai_runtime_controller.gd:5245-5261`, `scripts/runtime/monster_runtime_controller.gd:3968-4005`, `scripts/runtime/military_runtime_controller.gd:482-485`. |
| CA-023 | KEEP | Legacy save recognition is bounded and fail closed: `scripts/runtime/ruleset_save_handshake_service.gd:141-172`, `scripts/runtime/game_session_runtime_controller.gd:55-57`. |
| CA-024 | KEEP | Alpha role validation is a selection/hash gate: `resources/content/alpha01/alpha01_content_manifest.gd:551-604`, `resources/content/alpha01/alpha01_content_manifest.tres:13-16`. |
| CA-025 | MOVE | Monster catalog mixes roster, behavior, art, and presentation helpers: `scripts/runtime/monster_catalog_v06.gd:9-355`. Split projections around one stable identity. |
| CA-026 | REMOVE | Monster runtime duplicates localized name-to-family and action weight tables: `scripts/runtime/monster_runtime_controller.gd:24-33`, `:250-269`, `:990-1008`. |
| CA-027 | REMOVE | Main synthesizes monster and technique card rules from names: `scripts/main.gd:4195-4253`, `:4264-4310`. |
| CA-028 | KEEP | v0.6 monster cards are stable references but correctly projection-only: `scripts/cards/semantic/card_semantic_compiler_v1.gd:12-23`, `:330-344`, `data/cards/card_runtime_catalog_v06.json:19893-19909`. |
| CA-029 | KEEP | Monster runtime remains the live instance, RNG, save, and transaction owner: `scripts/runtime/monster_runtime_controller.gd:74-107`, `:1457-1510`, `:1840-2122`. |
| CA-030 | MOVE | v0.6 monster profile bridge joins player-facing card name to roster: `scripts/main.gd:473-493`, `:591-624`. Replace with `monster_family_id`. |
| CA-031 | MOVE | Product market state owner embeds a second catalog and presentation profiles: `scripts/runtime/product_market_runtime_controller.gd:56-145`, `:148-212`. |
| CA-032 | MOVE | Product industry resource has the same 46 IDs in a different order: `resources/content/product_industry_catalog_v05.tres:55-423`, `scripts/content/product_industry_catalog_resource.gd:4-46`, `scripts/runtime/product_market_runtime_controller.gd:80-88`. |
| CA-033 | REMOVE | AI, UI, and diagnostics directly consume product-market literals: `scripts/runtime/ai_runtime_controller.gd:1121-1123`, `scripts/runtime/product_codex_public_source_service.gd:55-73`, `:230-237`, `scripts/runtime/gameplay_balance_diagnostics_world_bridge.gd:163-177`. |
| CA-034 | KEEP | Localized product IDs are current cross-system compatibility identity: `scripts/runtime/product_market_runtime_controller.gd:80-88`, `resources/content/product_industry_catalog_v05.tres:55-69`, `data/cards/card_runtime_catalog_v06.json:20-50`. |
| CA-035 | MOVE | Facility kind allowlists repeat in owner, adapter, and schema: `scripts/runtime/region_infrastructure_runtime_controller.gd:12-15`, `scripts/cards/v06/effects/facility_card_effect_adapter_v06.gd:7-8`, `scripts/cards/semantic/card_semantic_schema_v1.gd:32-51`. |
| CA-036 | REMOVE | Facility numeric profiles are mirrored in Ruleset and every card payload: `scripts/rules/space_syndicate_ruleset_profile_v06.gd:8-16`, `data/cards/card_runtime_catalog_v06.json:13997-14029`, `scripts/cards/semantic/card_semantic_compiler_v1.gd:272-297`. |
| CA-037 | KEEP | Region infrastructure remains the live facility state and transaction owner: `scripts/runtime/region_infrastructure_runtime_controller.gd:35-61`, `:181-265`, `:417-550`, `:927-996`. |
| CA-038 | KEEP | Facility adapter is a valid composite transaction boundary: `scripts/cards/v06/effects/facility_card_effect_adapter_v06.gd:54-277`. Keep lifecycle; remove duplicate policy tables. |
| CA-039 | MOVE | Military runtime interprets flat stats and owns display mapping: `scripts/runtime/military_runtime_controller.gd:182-298`, `:571-580`. Move static profile and presentation to `MilitaryUnitSemanticSpec`. |
| CA-040 | KEEP | v0.6 military cards remain projection-only because no complete unit profile exists: `scripts/cards/semantic/card_semantic_compiler_v1.gd:17-22`, `:347-357`, `data/cards/card_runtime_catalog_v06.json:22485-22504`. |
| CA-041 | REMOVE | v0.4 military family resources remain executable stat sources: `resources/cards/runtime/families/055_行星防卫军.tres:6-101`, `scripts/runtime/card_effect_runtime_router.gd:145-150`. |
| CA-042 | KEEP | Military controller remains the live unit/command/save owner: `scripts/runtime/military_runtime_controller.gd:19-33`, `:87-148`, `:902-938`. |
| CA-043 | KEEP | WeatherDefinitionCatalog is the one real static weather source: `resources/weather/weather_definition_catalog_v1.tres:1-13`, `scripts/runtime/weather_definition_catalog.gd:8-58`, `scripts/runtime/weather_runtime_controller.gd:120-185`. |
| CA-044 | REMOVE | Weather runtime exposes a duplicate label catalog: `scripts/runtime/weather_runtime_controller.gd:16-23`, `scripts/runtime/ai_runtime_controller.gd:1169-1171`. |
| CA-045 | MOVE | Balance model maintains a parallel weather state/effect table: `scripts/balance/environment_balance_model.gd:34-138`, `scripts/balance/runtime_balance_model.gd:186-203`, `:630-645`. |
| CA-046 | KEEP | Weather controller owns live events and deterministic RNG contract: `scripts/runtime/weather_runtime_controller.gd:31-53`, `:107-185`, `:220-259`. |
| CA-047 | MOVE | Victory rule input is split between v0.6 Ruleset and clock registry: `scripts/rules/space_syndicate_ruleset_profile_v06.gd:18-23`, `:118-124`, `resources/rules/clock_domain_registry_v06.tres:6-31`, `scripts/runtime/victory_control_runtime_controller.gd:46-60`. Compile one `VictorySemanticSpec`. |
| CA-048 | REMOVE | Victory controller duplicates exact balance values in validation: `scripts/runtime/victory_control_runtime_controller.gd:720-745`. Move value constraints to the semantic schema. |
| CA-049 | KEEP | Victory controller is the single live state/privacy/receipt owner: `scripts/runtime/victory_control_runtime_controller.gd:23-75`, `:319-456`. |
| CA-050 | KEEP | v0.5 Ruleset and clock registry are uncomposed historical fixtures: `resources/rules/space_syndicate_ruleset_v05.tres:1-21`, `resources/rules/clock_domain_registry_v05.tres:1-16`. |
| CA-051 | KEEP | Save handshake recognizes v0.4/v0.5 only to reject resume: `scripts/runtime/ruleset_save_handshake_service.gd:141-172`, `:341-349`. |
| CA-052 | MOVE | GameSession accepts v0.4 composition while save operations are strict v0.6: `scripts/runtime/game_session_runtime_controller.gd:44-57`, `:537-564`. Narrow after whole-session cutover. |
| CA-053 | KEEP | Directory compendium registry is editorial and uncomposed: `scripts/content/compendium_content_registry.gd:4-7`, `:132-180`. It is not product, monster, or card rule authority. |
| CA-054 | MOVE | Card Presentation reinterprets raw kind/fields into category, player facts, animation style, and aftermath rules: `scripts/runtime/card_presentation_runtime_service.gd:577-646`, `:668-718`, `:739-885`. Use `PlayerPresentationDTO`; presentation-owned animation maps must consume operation IDs. |
| CA-055 | MOVE | Card Codex owns parallel category/icon maps and infers target semantics with string containment: `scripts/runtime/card_codex_public_source_service.gd:7-44`, `:195-253`, `:390-411`. Use the same DTO and typed target projection as the table. |

## Current content counts

| Source/domain | Count | Authority meaning |
| --- | ---: | --- |
| v0.4 card graph | 113 families / 230 authored rank resources / 10 packs | Current global legacy production catalog |
| v0.6 card catalog | 87 families / 348 cards | Target card definition source; only 256 are currently active semantic routes |
| v0.6 card semantic readiness | 256 active / 92 projection-only | Projection-only = monster 32, military 28, interaction 12, organization 20 |
| Alpha card selection | 40 families / 160 rank records | Active selection, not definition authority |
| Roles | 24 | One current catalog, but identity and passive consumers are not typed |
| Monsters | 8 roster families | Static profile and behavior authority is split |
| Products | 46 | Same ID set appears in two different orders |
| Facility kinds | 6 | No single immutable facility spec exists |
| Military families | 7 | v0.4 executable; v0.6 projection-only |
| Weather definitions | 6 | Existing Resource catalog is the target source |

## Production versus historical sources

These files are not current production definition authorities and must not be used as fallback:

| Source | Classification | Production consumers |
| --- | --- | ---: |
| `resources/cards/runtime/card_runtime_catalog_v05.tres` | Migration/conformance fixture | 0 |
| `resources/rules/space_syndicate_ruleset_v05.tres` | Historical Ruleset fixture; its IndustryCapacity scene is uncomposed | 0 |
| `resources/rules/clock_domain_registry_v05.tres` | Historical clock fixture | 0 |
| `scripts/content/compendium_content_registry.gd` and directory entries | Uncomposed editorial registry | 0 beyond the registry itself |
| `resources/migrations/card_text_v04_to_v05_registry.tres` | Historical text migration map | 0 execution consumers |
| `tests/**/*.gd` | Test oracle | Never production authority |
| `scripts/tools/**/*.gd`, `scenes/tools/**/*.tscn` | Builder/Bench | Never production authority |

The v0.4 catalog is different: it is old, but it is still production authority today. Labeling it as a historical fixture before consumer cutover would be false.

## Compatibility readers to retain

1. `scripts/runtime/ruleset_save_handshake_service.gd:141-172` must continue recognizing old envelopes and rejecting resume safely.
2. `scripts/runtime/world_session_envelope_codec.gd:448-468` must read legacy role index/name until the role-ID save migration is complete.
3. `scripts/runtime/game_session_runtime_controller.gd:44-57` must tolerate the current transitional v0.4 composition until the atomic session cutover.
4. `scripts/presentation/card_text_migration_registry_resource.gd:1-22` may remain as migration provenance, never execution authority.
5. `resources/migrations/card_text_v04_to_v05_registry.tres:1-9` may remain for historical mapping and tests.
6. `scripts/runtime/product_market_runtime_controller.gd:80-88` must preserve exact localized IDs and order until a versioned product/save/RNG migration exists.
7. The frozen v0.4 card catalog may remain after cutover as a non-composed historical fixture if migration tests require it.

## Atomic cutover and deletion order

1. Freeze source fingerprints, exact sets, deterministic product order, RNG draw counts, save fixtures, and current execution outcomes.
2. Land shared identity, condition, target, operation, visibility, randomness, compiler, and validation contracts without changing routes.
3. Establish one immutable target authority per non-card domain. Do not add parallel long-lived owners.
4. Compile v0.6 card `machine` definitions once at catalog initialization. Unknown or projection-only operations remain fail closed.
5. Register existing domain handlers by stable `operation_id`; preserve prepare/commit/rollback/finalize and RNG order.
6. Cut diagnostics, player presentation, and AI to standard projections. Migrated domains must have zero raw-catalog fallback.
7. Migrate setup, session start, and save writes to stable IDs plus instance state. Retain bounded legacy readers.
8. Cut execution over domain by domain: core economy, interaction/counter, monster, military, finance/weather, role passives, then victory.
9. Atomically remove runtime-shape submission branching, suffix inference, and flat-kind routing. There must be one typed submission path.
10. Delete Main monster synthesis and definition-bridge special sources after production consumer counts reach zero.
11. Remove `CardRuntimeCatalogService` and v0.4 catalog from production composition only after inventory, AI, UI, diagnostics, execution, save, and replay parity are green.
12. Remove the overall v0.4 composition gate only after every currently v0.4-configured owner consumes the single session rules authority. Keep fail-closed legacy inspection according to support policy.

## Blockers

1. Card semantic readiness is only 256 active / 92 projection-only.
2. v0.4 has 230 authored ranks while v0.6 has 348 records; they are not drop-in equivalents.
3. Submission and effect routing still dispatch by shape and legacy kind.
4. Main still synthesizes monster rules and performs localized-name joins.
5. The two 46-product catalogs have different order, so authority replacement can change RNG assignment.
6. Role save identity is index plus localized name, and full role definitions are persisted.
7. Legacy monsters may lack stable family IDs; behavior weights are split.
8. No complete authoritative military unit profile exists.
9. Facility numbers are mirrored and `rent_rate_profile` is not executable authority.
10. Overall composition remains v0.4-gated while selected domains run v0.6 profiles.
11. AI, UI, and diagnostics still consume raw definitions for several domains.
12. Financial terms are runtime-enriched rather than immutable semantic references.
13. Organization catalog completeness does not establish gameplay authority; those cards remain selection-excluded and projection-only.
14. Identity migration must preserve the fixed save owner order, privacy, RNG, and explicit legacy-resume policy.

## Safe conclusion

The target architecture is feasible without replacing live owners or transactions. The immediate next boundary is the shared semantic kernel plus one-authority identity contracts. Deleting legacy catalogs first would break production and would also erase the parity oracle needed to prove the migration.
