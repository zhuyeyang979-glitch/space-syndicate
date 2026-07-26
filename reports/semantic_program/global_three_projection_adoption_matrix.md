# Global Three-Projection Adoption Matrix

## Audit Basis

- Baseline: `46b356f99da5b536f877d96a946ceddd1720fef4`
- Branch: `codex/codex-first-playerface-cutover-46b356f`
- Observed: `2026-07-27`
- Machine-readable authority: `reports/semantic_program/global_three_projection_adoption_matrix.json`
- Claim policy: an existing domain-specific snapshot, DTO, controller, or state machine is not counted as a shared SemanticSpec projection unless it consumes the immutable shared semantic contract.
- Worktree note: the Card Codex cutover is recorded as `CODEX_ONLY_ACTIVE`; full-catalog, runtime, performance, privacy, and Godot MCP gates are green.

## Program Snapshot

| Domain | Immutable Core | PlayerProjection | AiProjection | RulesProjection | Dynamic State Owner |
| --- | --- | --- | --- | --- | --- |
| Card | `GREEN` | `CODEX_ONLY_ACTIVE` (local and MCP gates green) | `PASSIVE_OWN_HAND_AUTHORIZED` | `NOT_STARTED` | Existing Card/WorldSession owners |
| Role | Not implemented; rule authority blocked | Legacy domain-specific | Raw catalog/saved fields | `NOT_STARTED` | `WorldSessionState` plus existing passive effect owners |
| Monster | Not implemented | Legacy Monster Codex/presentation | Raw controller/roster reads | `NOT_STARTED` | `MonsterRuntimeController` |
| MonsterBehavior | Not implemented | Legacy action presentation | Controller-internal weights/raw facts | `NOT_STARTED` | `MonsterRuntimeController` |
| Product | Not implemented; order parity blocked | Legacy Product Codex/market | Raw product and market reads | `NOT_STARTED` | `ProductMarketRuntimeController` and commodity owners |
| Facility | Not implemented; no one static catalog | Legacy owner snapshots | Raw facility-kind reads | `NOT_STARTED` | `RegionInfrastructureRuntimeController` |
| MilitaryUnit | Not implemented; no complete profile | Legacy flat-field mapping | Raw v0.4 skill reads | `NOT_STARTED` | `MilitaryRuntimeController` |
| Weather | Not implemented; source ready | Legacy weather presentation | Domain public-template reads | `NOT_STARTED` | `WeatherRuntimeController` |
| Victory | Not implemented; split inputs | Legacy victory snapshots | Direct dictionary reads | `NOT_STARTED` | `VictoryControlRuntimeController` |

No domain has an active shared RulesProjection. `OperationHandlerRegistry` remains metadata-only. The Save registry remains fixed at 19 sections and no semantic spec is persisted.

## Card

- **Authoritative catalog:** the sealed semantic source is `data/cards/card_runtime_catalog_v06.json`, loaded by `CardRuntimeCatalogV06Resource` and owned semantically by `CardSemanticCatalogService`. Production execution still carries active v0.4/v0.6 debt.
- **Immutable spec:** `CardSemanticSpecV1` is `GREEN`: 348 definitions compile, 256 are active, and 92 remain `projection_only`.
- **Dynamic owners:** `WorldSessionState` owns hand-slot records; `CardInventoryRuntimeService` owns inventory policy; cooldown and queue/execution state remain in their existing owners. The semantic layer owns none of this state.
- **PlayerProjection:** `CODEX_ONLY_ACTIVE`; full-catalog, production-scene, visual, performance, privacy, and architecture gates are green. It uses `PlayerFaceDTOv1` detail plus the closed `PlayerCardCodexDTOv1` and family-ladder DTO. Market, hand, and card-track cutovers remain false.
- **AiProjection:** `PASSIVE_OWN_HAND_AUTHORIZED` through `AiActorHandInventoryQueryPort`, `CardSemanticSourceAuthorizationPort`, and `CardInstanceDecisionStateV1`. Production AI remains on its old path.
- **RulesProjection:** `NOT_STARTED`; no production `RuleExecutionPlan` or gameplay handler registration exists.
- **Visibility:** public Codex records require exact catalog membership and trusted public localization; own-hand semantics require actor/session capability authorization. Other source kinds fail closed.
- **RNG and Save:** semantic compilation and both projections consume zero RNG. Semantic specs and authorization bundles are not saved. Card instance restore remains partial across existing session, inventory, queue, execution, and history sections.
- **Bridges:** temporary DTO-to-Codex snapshot adaptation, narrow audited legacy identity compatibility, raw AI/non-Codex UI readers, and the v0.4/v0.6 execution bridge.
- **Next boundary:** `AI_VIEWER_PRIVACY_AND_RAW_READ_RATCHET_BATCH1`.

## Role

- **Catalog:** `RoleCatalogRuntimeService` is the one ordered catalog, but full mutable definitions are copied into live players and Save state.
- **Immutable spec:** `RoleSemanticSpec` is not implemented. Stable `role_id` is absent and all audited passive families are blocked by `RULE_AUTHORITY_NOT_ESTABLISHED`.
- **Dynamic owner:** `WorldSessionState.players[*]` holds selected role state; viewer-private usage remains in `CardHistoryPrivateAnnotationService`; actual passive mutations belong to existing cash, inventory, monster, military, and response owners.
- **Projections:** Role Codex, setup, table, intel, portraits, and AI have domain-specific paths. None consumes a standard Role semantic projection; AI rehydrates by index/name and gameplay often reads saved flat fields.
- **Visibility, RNG, Save:** role identity is public while usage is viewer-private. Random role assignment uses `RunRngService`; passives consume no audited RNG. Save identity remains role index plus localized name and a copied full role definition.
- **Blockers:** rule authority, stable identity, authored-prose/execution disagreement, and exact-once Save migration.
- **Next boundary:** `ROLE_STABLE_ID_AND_RULE_AUTHORITY_FREEZE`.

## Monster

- **Catalog:** static authority is split among `MonsterCatalogV06`, weather traits, v0.4 family resources, and Main-generated compatibility definitions.
- **Immutable spec:** `MonsterSemanticSpec` is not implemented; legacy instances can omit stable family identity.
- **Dynamic owner:** `MonsterRuntimeController` remains the sole live owner for instances, lifecycle, battle, wager, motion, and ownership state.
- **Projections:** Monster Codex and event/map presentation are legacy domain-specific paths. AI still reads controller/roster facts and can bypass the desired viewer-scoped boundary. No RulesProjection exists; the existing monster state machines remain authoritative.
- **Visibility, RNG, Save:** public and actor-private filtering remains controller-owned. `RunRngService` supplies timers, weighted action/region selection, revival, wager, and edge-case physics draws. The transactional `monsters` section still permits index/name identity fallbacks.
- **Blockers:** stable family identity, hidden-owner clipping, complete rank profiles, and removal of parallel sources.
- **Next boundary:** `MONSTER_STABLE_FAMILY_ID_AND_SOURCE_AUTHORITY_FREEZE`.

## MonsterBehavior

- **Catalog:** actions live in `MonsterCatalogV06.MONSTER_ACTION_TABLES`; weights and transforms are split between that catalog and `MonsterRuntimeController`.
- **Immutable spec:** `MonsterBehaviorSpec` and stable behavior/action operation IDs are not implemented.
- **Dynamic owner:** behavior state is part of `MonsterRuntimeController`; there is no second behavior owner or Save section.
- **Projections:** player action presentation is legacy Monster Codex output, AI consumes controller-internal weights/raw facts, and rules execute inside the monster state machine.
- **Visibility, RNG, Save:** target weights and hidden ownership must remain private. RNG order is action ticket first, then region ticket after weather modifiers. Behavior identity/fingerprint is not independently saved.
- **Blockers:** freeze weight/rank parity, stable action IDs, viewer-scoped AI facts, and exact RNG ordering.
- **Next boundary:** `MONSTER_BEHAVIOR_SPEC_AND_RNG_PARITY`.

## Product

- **Catalog:** `ProductMarketRuntimeController.PRODUCT_CATALOG/PRODUCT_PROFILES` and `ProductIndustryCatalogResource` contain the same 46 IDs in different orders. No source can be replaced until deterministic order parity is frozen.
- **Immutable spec:** `ProductSemanticSpec` is not implemented. The intended direction is to evolve `ProductIndustryCatalogResource` in place, not add a third catalog.
- **Dynamic owners:** market prices, cycles, timers, and futures remain in `ProductMarketRuntimeController`; commodity flow and placed product state remain in their existing owners.
- **Projections:** Product Codex/market UI and AI use legacy raw profiles. No shared Player, AI, or Rules projection exists.
- **Visibility, RNG, Save:** market public snapshots are domain-owned. Product enumeration order assigns `RunRngService` draws to IDs, making order a behavioral contract. Localized product IDs remain persistence identity; market restore coverage is incomplete.
- **Blockers:** order/RNG parity, localized identity migration, fixed-section restoration, and parallel presentation/AI profiles.
- **Next boundary:** `PRODUCT_ORDER_AND_IDENTITY_PARITY_FREEZE`.

## Facility

- **Catalog:** there is no single static catalog. Numeric profiles are split between v0.6 rules and card payloads; type policy is repeated in the infrastructure owner and facility adapter.
- **Immutable spec:** `FacilitySemanticSpec` is not implemented.
- **Dynamic owner:** `RegionInfrastructureRuntimeController` remains the sole live facility owner. `FacilityCardEffectAdapterV06` keeps the legitimate prepare/commit/rollback/finalize transaction boundary.
- **Projections:** public and viewer-private facility snapshots are domain-specific; AI reads flat facility-kind fields. No shared projection exists.
- **Visibility, RNG, Save:** visibility is enforced by the infrastructure owner. The audited owner/adapter consume no RNG. `region_infrastructure` is transactional and already carries stable facility/region identity.
- **Blockers:** one static authority, duplicated numeric profiles, unresolved rent semantics, and preservation of composite rollback.
- **Next boundary:** `FACILITY_STATIC_PROFILE_AUTHORITY_FREEZE`.

## MilitaryUnit

- **Catalog:** v0.4 family resources remain executable while all 28 v0.6 military cards are correctly `projection_only`. No reviewed seven-family rank profile exists.
- **Immutable spec:** `MilitaryUnitSemanticSpec` is not implemented.
- **Dynamic owner:** `MilitaryRuntimeController` owns roster, commands, cooldowns, position, HP, and ownership.
- **Projections:** display uses legacy flat-field mapping; AI reads v0.4 skill fields; the controller command state machine remains the rules path.
- **Visibility, RNG, Save:** live privacy hides ownership unless self/revealed, conflicting with v0.6 authored public ownership. Military operations consume zero audited RNG. The `military` Save section lacks strict preflight and stable `unit_family_id`.
- **Blockers:** exact rank profiles, the upgrade-rule conflict, visibility authority, atomic card/unit rollback, and strict Save restore.
- **Next boundary:** `MILITARY_UNIT_PROFILE_AND_VISIBILITY_AUTHORITY`.

## Weather

- **Catalog:** `WeatherDefinitionCatalog` over `weather_definition_catalog_v1.tres` is the one real source, but runtime, forecast, and telemetry duplicate identity maps.
- **Immutable spec:** `WeatherSemanticSpec` is not implemented, although the existing definition resource is a suitable in-place source.
- **Dynamic owner:** `WeatherRuntimeController` with `WeatherRuntimeState` owns events, queue, history, phase, regions, and sequence.
- **Projections:** weather presentation and AI public templates are mature domain-specific paths, not shared SemanticSpec projections. Rules remain in the controller and `WeatherEffectResolver`.
- **Visibility, RNG, Save:** planetary weather is public. New-session and natural forecast generation use three ordered draws; explicit card scheduling currently uses zero. The transactional `weather` section is schema 2 and still accepts `type`/`districts` aliases.
- **Blockers:** duplicate maps, parallel diagnostic semantics, no v0.6 card weather operation, and no standard AI projection.
- **Next boundary:** `WEATHER_SEMANTIC_SPEC_FROM_EXISTING_CATALOG`.

## Victory

- **Catalog:** static inputs are split between `SpaceSyndicateRulesetProfileV06` and the v0.6 clock registry.
- **Immutable spec:** `VictorySemanticSpec` is not implemented.
- **Dynamic owner:** `VictoryControlRuntimeController` is the one owner for qualification, audit, settlement, and exact-once outcome state.
- **Projections:** public/private snapshots and presentation receipts are legacy domain-specific outputs. AI directly reads dictionaries. No standard Player, AI, or Rules projection exists.
- **Visibility, RNG, Save:** the controller's sticky audit roster is the current visibility authority, but disclosure policy and internal exact-cash receipts conflict. Victory consumes no RNG. `victory_control` schema 2 restores transactionally but has no semantic fingerprint or durable cross-session replay identity.
- **Blockers:** visibility policy, typed internal/public/AI receipts, cross-section terminal validation, and session-scoped replay identity.
- **Next boundary:** `VICTORY_VISIBILITY_POLICY_AND_SEMANTIC_SPEC_FREEZE`.

## Program Order

The immediate program boundary after the Card Codex integration is `AI_VIEWER_PRIVACY_AND_RAW_READ_RATCHET_BATCH1`. The matrix does not authorize parallel full-domain cutovers. Each later domain should first freeze one immutable authority and preserve its existing dynamic owner, visibility boundary, RNG order, and Save identity before any consumer switch.
