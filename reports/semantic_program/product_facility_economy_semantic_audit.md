# Product, Facility, And Economy Semantic Audit

## Audit identity

- Baseline: `4ee3d0e1e80224be362692db9214e960b2f8864f`
- Branch: `codex/semantic-program-wave1-product-economy-4ee3d0e`
- Scope: authoritative product/facility catalogs and resources, runtime economy owners, card adapters, AI, presentation, Codex, diagnostics, save/replay, privacy, and RNG consumers.
- Write scope: this report and `reports/semantic_program/product_facility_economy_semantic_audit.json` only.
- Production changes: none.
- Tests, catalogs, rules, balance values, RNG behavior, save payloads, and prior reports were not modified.

## Executive verdict

The product and facility gameplay owners are real and should remain. The problem is the static meaning around them:

1. Product identity is currently authoritative in `ProductMarketRuntimeController.PRODUCT_CATALOG`, while `product_industry_catalog_v05.tres` repeats the same 46 IDs in a different order.
2. That order difference is behaviorally significant because market initialization and refresh consume one deterministic RNG sequence in `PRODUCT_CATALOG` order.
3. Product presentation metadata is embedded in the live market owner and then reimplemented in Main and Product Codex.
4. Facility state has one legitimate owner, but no single facility-definition catalog. Type sets and industry allowlists are repeated in the owner, card adapters, compiler, and capacity services.
5. The v0.6 card catalog already compiles product/facility/supply-demand cards to six useful semantic operation IDs, but production execution still dispatches legacy `effect_kind` in several places.
6. Product IDs are localized Chinese strings, but they are not merely labels. They are current cross-owner, RNG, card, route, AI, and save identity keys. This audit therefore forbids inventing ASCII aliases or renaming them in place.

The audit records **32 grouped findings**: **9 REMOVE**, **15 MOVE**, and **8 KEEP**. `KEEP` means a legitimate state owner, transaction, deterministic ordering contract, privacy boundary, or numeric rules authority. It does not authorize new raw-payload or localized-text interpretation.

## Deterministic inventory

| Measure | Result |
| --- | ---: |
| Runtime product IDs | 46 |
| Product-industry resource IDs | 46 |
| Product ID sets equal | true |
| Product orders equal | false |
| Stable industries | 6 |
| Static product profiles | 46 |
| Unique profile category strings | 44 |
| Unique profile route strings | 10 |
| Unique profile terrain strings | 46 |
| Ocean-product duplicate subset | 12 |
| Non-runtime Compendium product entries | 9 |
| v0.6 card records | 348 |
| Commodity installation cards | 184, 46 families x 4 ranks |
| Facility cards | 64, 16 families x 4 ranks |
| Supply/demand cards | 8, 2 families x 4 ranks |
| Facility kinds | 6 |
| Facility card kinds | factory 24, market 24, road 4, port 4, spaceport 4, warehouse 4 |
| Semantic operation IDs in this domain | 6 |
| Production files referencing market catalog authority | 11 |
| Production files referencing product-industry resource | 7 |
| Production files defining facility static sets | 3 |
| Production industry allowlist definitions | 6 |
| Product/economy alias lexical candidates | 19 in 12 files |
| Cross-schema alias candidates requiring migration | 9 |
| Product-specific equality/switch branches over the 46 real IDs | 0 |

Deterministic fingerprints:

| Input | SHA-256 |
| --- | --- |
| Market product order | `f4fb63967af45db0d3cfc2efb8f5f580be7f495e396ff52c59e7e9d0a46db262` |
| Product-resource order | `4a54d8bf6511fbb73fedd6fb8eb1c421d2ea6a2a71740905447537e6e491badb` |
| Sorted product ID set | `f9b5cce077451535592191b99b8cc9cf2c62a193b583f2a4d7d4a85df927a815` |
| Facility-kind order | `a1ce2f96e109dc9f7be62f2220068e0e01ffe9bf08a872a3efa5a70fbea2c367` |
| Product market source file | `516ff4e66f67040f940c51e07ecb35c22872e6cdb5b994fbb67776235729a869` |
| Product-industry resource file | `5544f01d1f0e50a7be38e4fa8686ba249a89517782d2b77646b913ed93cbd77a` |
| v0.6 card catalog file | `b59b73489d23578558d4a7688a03f50a3ef4d776cf528cd9eafd0e1d2a0fcb40` |

The market order starts `星露莓, 磁核榴莲, 月壤葡萄, 量子蜜瓜`; the resource order starts `星露莓, 月壤葡萄, 孢子丝绸, 光合凝胶`. The set is identical, but replacing one enumeration with the other would assign deterministic random draws to different products.

## Current authority map

| Concern | Current authority | Status | Required destination |
| --- | --- | --- | --- |
| Product live price, trend, supply, demand, futures, cadence | `ProductMarketRuntimeController.product_market` | legitimate single state owner | KEEP |
| Product runtime identity and market order | `ProductMarketRuntimeController.PRODUCT_CATALOG` | current compatibility authority | Move authoring to one Product semantic catalog while preserving this exact order |
| Product industry and weather tags | `product_industry_catalog_v05.tres` | duplicate static source, but best canonical-source candidate | Evolve in place and compile once to `ProductSemanticSpec` |
| Product presentation profile | `ProductMarketRuntimeController.PRODUCT_PROFILES` | misplaced static metadata | `ProductSemanticSpec -> ProductPresentationDTO` |
| Product market numeric rules | Product market constants plus formula/ruleset services | legitimate rules, not content identity | KEEP until separate rule-resource cutover |
| Facility live instances, slots, lifecycle, receipts | `RegionInfrastructureRuntimeController` | legitimate single state owner | KEEP |
| Facility kinds and industry binding | repeated code constants | no single catalog | `FacilitySemanticSpec` catalog |
| Facility rank numbers | `space_syndicate_ruleset_v06.tres` / profile | legitimate balance authority | Resolve into compiled Facility specs by reference, never duplicate as a second authoring table |
| Installed commodity rates and physical flow | `CommodityFlowRuntimeController` | legitimate single state owner | KEEP |
| Card static semantics | v0.6 machine catalog compiled by `CardSemanticCompilerV1` | correct Phase 1 direction | Use its op IDs for all three projections and execution plans |
| Economic card dispatch | Core economic router, adapter, and coordinator kind branches | transitional multi-dispatch | One `OperationHandlerRegistry` built by promoting the existing router machinery |
| Product/facility UI | product Codex, dashboard, map, table presentation | reinterprets raw profile/state | Product/Facility presentation DTOs |
| AI economic choice | AI reads product catalog and live dictionaries | legitimate goals mixed with unscoped inputs | viewer-authorized `AiObservationSnapshot` and semantic candidates |
| Diagnostics | diagnostics bridge/service and runtime balance model | second interpreter | standard semantic diagnostic projection |

## Static definitions versus live state

`ProductSemanticSpec` must never contain current price, supply, demand, history, futures positions, weather projection, market timer, or business-cycle revision. Those stay in `ProductMarketRuntimeController`.

`FacilitySemanticSpec` must never contain facility instance ID, region ID, owner, current rank, generation, active state, tombstone, receipt, or transaction journal. Those stay in `RegionInfrastructureRuntimeController`.

Installed commodity amounts, rate remainders, backlog, warehouse inventory, sale receipts, and physical flow remain in `CommodityFlowRuntimeController`. A compiled semantic spec can describe what an operation means; it cannot become a second gameplay-state owner.

## Proposed ProductSemanticSpec

The safest canonical authoring source is the existing `resources/content/product_industry_catalog_v05.tres`, evolved in place rather than shadowed by another product list. Its compiled immutable output should contain:

```text
ProductSemanticSpec
  schema_version: int
  identity:
    domain_id: "product"
    product_id: current exact localized authority value
    identity_policy_id: "localized_authority_compat_v1"
  market_order_index: int
  industry_id: stable ASCII ID
  taxonomy_tag_ids: stable IDs
  weather_tag_ids: stable IDs
  terrain_tag_ids: stable IDs
  presentation:
    display_name_ref
    icon_key
    color_key
    category_id
    route_id
    summary_message_ref
  visibility_policy_id: "public_static_definition"
  save_identity_policy_id: "preserve_exact_product_id"
  source_fingerprint
```

Migration rules:

- `product_id` remains exactly the current Chinese value. No ASCII synonym, slug, or name parser is introduced.
- Add an explicit `market_order_index` matching the current `PRODUCT_CATALOG` order. Do not rely on `.tres` array order.
- Move the 46 static profiles out of the live market owner into this same canonical source.
- Replace free-form `category`, `route`, and terrain rule guesses with stable IDs and localized presentation refs.
- Add an explicit ocean/terrain tag for the existing 12-product ocean subset. Preserve the exact current ordered pool used by session generation.
- Keep price-tier assignment, current price, market pressure, and futures positions out of the spec.
- Compile once at catalog initialization and cache by source fingerprint. Consumers receive detached pure-data snapshots, not the Resource object.

## Proposed FacilitySemanticSpec

There is no current facility-definition catalog. Introduce one canonical catalog in an atomic cutover, then delete the repeated code sets. It should reference the existing v0.6 ruleset balance tables instead of copying their numbers as new authoring authority.

```text
FacilitySemanticSpec
  schema_version: int
  facility_kind_id: factory | market | road | port | spaceport | warehouse
  industry_binding_policy_id: required | forbidden
  slot_key_policy_id
  allowed_region_state_ids
  operation_ids
  rank_profile_ref
  resolved_rank_profile
  presentation:
    display_name_ref
    icon_key
    color_key
    capability_message_refs
  save_identity_policy_id: "preserve_facility_type_and_slot_id"
  source_fingerprints:
    facility_catalog
    ruleset_v06
```

The compiled `resolved_rank_profile` may carry detached values for execution, but the authoring numbers remain owned by the v0.6 ruleset profile. Validation must fail closed if card payload, facility catalog, and ruleset disagree.

## Operation registry plan

Do not create a second economic router. Promote the registration and lifecycle binding already present in `CoreEconomicCardEffectRouterV06` into the shared `OperationHandlerRegistry`, then register semantic operation IDs:

| Semantic operation ID | Current effect kind | Registered handler/facade | Live owner | Required preservation |
| --- | --- | --- | --- | --- |
| `install_rate` | `install_commodity_rate` | `CommodityCardEffectAdapterV06` | `CommodityFlowRuntimeController` | product/industry/facility validation; exact-once install |
| `build_facility` | `build_upgrade_or_repair_facility` | `FacilityCardEffectAdapterV06` | `RegionInfrastructureRuntimeController` | empty-slot build branch |
| `upgrade_facility` | same | same | same | higher-rank branch |
| `repair_facility` | same | same | same | equal/lower-rank repair branch |
| `modify_supply` | `global_supply_spawn` | `GlobalSupplyDemandRuntimeServiceV06` | `CommodityFlowRuntimeController` through atomic batch sink | real factories/routes/capacity; one-shot physical goods |
| `modify_demand` | `global_order_budget` | `GlobalSupplyDemandRuntimeServiceV06` | `CommodityFlowRuntimeController` through atomic batch sink | real markets/routes/capacity; one-shot demand |

The facility adapter is a composite transaction facade. A factory build may also install its production commodity. `build_facility` and the automatic installation must not become two independently committed registry actions. The execution plan selects one facility branch, while the existing adapter retains prepare/commit/rollback/finalize coordination.

Legacy product futures and other v0.4 market-card kinds are not silently assigned new operation IDs by this audit. They remain an explicit blocker until the card compiler receives validated finance terms and parity is proven.

## REMOVE findings

| ID | Exact evidence | Finding | Required removal |
| --- | --- | --- | --- |
| PFE-001 | `scripts/runtime/product_market_runtime_controller.gd:80-88`; `resources/content/product_industry_catalog_v05.tres:55-423` | Two lists define the same 46 product IDs in different orders. | After order-fingerprint parity, remove the controller literal and query the compiled Product semantic catalog. |
| PFE-002 | `scripts/runtime/session_start_world_plan_builder.gd:13`, `:46`, `:150-153`, `:184-190` | `OCEAN_PRODUCTS` is a second localized product classification and directly shapes RNG pools. | Replace with an explicit semantic terrain tag while preserving the exact current ordered pool and RNG cursor. |
| PFE-003 | `resources/compendium/products/water_ice.tres:7`; `ore_freight.tres:7`; `spice_market.tres:7`; `contract_goods_pack.tres:8`, `:30`, `:52`, `:74`, `:96`, `:118` | Nine Codex-only pseudo-products have IDs disjoint from the 46 runtime products. | Remove them from the active product catalog surface or quarantine them as tutorial fixtures; they cannot be a second Product definition source. |
| PFE-004 | `scripts/cards/v06/effects/commodity_card_effect_adapter_v06.gd:49-51`, `:150-155` | Commodity rank is parsed from the `.rank_` suffix of `card_id`. | Pass typed rank from `RuleExecutionPlan`; delete suffix parsing. |
| PFE-005 | `scripts/runtime/product_codex_public_source_service.gd:287-319` | Product Codex recursively scans arbitrary raw `effect_payload` values to infer related cards. | Use typed semantic product references or a standard relation projection. |
| PFE-006 | `scripts/runtime/ai_runtime_controller.gd:1551-1554` | AI searches localized public clue prose for every product name. | Clue producers emit typed product IDs; AI reads authorized observation facts only. |
| PFE-007 | `scripts/ui/planet_map_view.gd:1374-1388` | UI selects route color by English/Chinese product-like labels and otherwise falls back to yellow. | Product presentation projection supplies `color_key` or rendered color token. |
| PFE-008 | `scripts/runtime/product_market_runtime_controller.gd:177-183`; `scripts/runtime/game_runtime_coordinator.gd:180-187`, `:515`; `scripts/main.gd:273-283` | Product market and coordinator readiness remain gated by v0.4 while product/facility card execution is v0.6. | Remove the dual-version runtime gate only after finance, timing, save, and execution parity. |
| PFE-009 | `scripts/runtime/industry_capacity_runtime_service.gd:4`, `:152-170`; `scripts/rules/space_syndicate_ruleset_profile_v05.gd:4`, `:23`; `scripts/runtime/gdp_formula_runtime_controller.gd:5-18`; `scenes/runtime/GdpFormulaRuntimeController.tscn:10-11` | Uncomposed v0.5 capacity logic and a retired GDP scene retain duplicate product/rule dependencies. | Confirm tool/test-only status, then retire or move them out of production paths; do not restore their retired gameplay mechanics. |

## MOVE findings

| ID | Exact evidence | Finding | Stable destination |
| --- | --- | --- | --- |
| PFE-010 | `scripts/runtime/product_market_runtime_controller.gd:98-145`; duplicate access/fallback at `scripts/main.gd:2145-2169` and `scripts/runtime/product_codex_public_source_service.gd:236-250` | Forty-six static profiles live in the mutable market owner and are interpreted twice more. | One `ProductSemanticSpec` and `ProductPresentationDTO`. |
| PFE-011 | `scripts/content/product_industry_catalog_resource.gd:4-6`, `:17-43`, `:46-109`; `scripts/content/product_industry_definition_resource.gd:4-9` | The best product source also carries v0.5 schema and hard-coded capacity thresholds. | Evolve it into the single product authoring source; move numeric capacity authority to ruleset references. |
| PFE-012 | `scripts/runtime/product_market_runtime_controller.gd:214-264`, `:267-292`, `:486-510`, `:534-595` | Product enumeration order binds deterministic tier, price, and refresh draws to product identity. | Explicit Product semantic `market_order_index` and a frozen order fingerprint. |
| PFE-013 | `scripts/runtime/commodity_flow_runtime_controller.gd:18`, `:352`, `:518`, `:1760-1764`, `:2360-2376`; `scripts/runtime/product_market_runtime_controller.gd:1982-1985`; `scripts/runtime/region_infrastructure_world_bridge.gd:471-489` | Industry and weather meaning is repeatedly queried from the raw Resource. | Read detached Product semantic facts from one catalog service; keep live calculations in existing owners. |
| PFE-014 | `scripts/runtime/region_infrastructure_runtime_controller.gd:15-16`, `:218-235`, `:1618-1623` | Facility kind and industry-binding policy are code constants inside the live state owner. | `FacilitySemanticSpec`; the owner validates detached specs and keeps instance state. |
| PFE-015 | `scripts/rules/space_syndicate_ruleset_profile_v06.gd:9-16`, `:38`, `:51`; card payload validation at `scripts/cards/semantic/card_semantic_compiler_v1.gd:272-297` | Rank numbers are authoritative in ruleset v0.6 but repeated in card payloads. | Compile a facility/rate profile with fail-closed ruleset parity; no value changes. |
| PFE-016 | `scripts/cards/v06/effects/commodity_card_effect_adapter_v06.gd:7`; `facility_card_effect_adapter_v06.gd:7-9`; `global_supply_demand_runtime_service_v06.gd:7-8`; `scripts/runtime/industry_capacity_runtime_service.gd:4`; `region_infrastructure_runtime_controller.gd:15-16`; `scripts/cards/semantic/card_semantic_schema_v1.gd:7` | Six production definitions repeat the same six industry IDs; three files independently define facility sets. | Shared semantic identity/catalog validation, not another copied constant. |
| PFE-017 | `scripts/runtime/commodity_flow_runtime_controller.gd:346`, `:512`, `:4581`; `scripts/runtime/industry_capacity_world_bridge.gd:32`; `scripts/runtime/victory_control_world_bridge.gd:293`; `scripts/runtime/economy_dashboard_viewer_query_port.gd:125`, `:130-131`; `scripts/runtime/economy_dashboard_public_snapshot_service.gd:125` | Product/commodity, current/base price, supply/market-supply, demand/market-demand, and quantity/unit shapes are bridged by nested aliases. | Typed canonical requests and Product/Economy DTOs; preserve distinct concepts such as current price versus base price. |
| PFE-018 | `scripts/cards/v06/production/core_economic_card_effect_router_v06.gd:5-12`, `:17-28`, `:34-60`, `:125-214` | Existing registration and transaction lifecycle are keyed by legacy effect kind. | Promote this machinery into `OperationHandlerRegistry` keyed by semantic op ID. |
| PFE-019 | `scripts/runtime/game_runtime_coordinator.gd:16-26`, `:2897-2977`, `:3045-3112` | Coordinator duplicates target/replay reconstruction for product/facility effect kinds. | Handler capability registration for target planning and replay validation; coordinator remains orchestration-only. |
| PFE-020 | `scripts/cards/semantic/card_semantic_compiler_v1.gd:481-506`, `:521-543`; `card_semantic_schema_v1.gd:56-57` | Correct semantic ops exist, but production rules still consume raw machine payload. | `CardSemanticSpec -> RuleExecutionPlan`; handlers receive validated operations, not arbitrary payload. |
| PFE-021 | `scripts/runtime/ai_runtime_controller.gd:1121-1123`, `:1394-1454`, `:4870-4873`, `:5195-5260`, `:5283-5295`, `:7180-7222` | AI has legitimate product strategy logic but directly enumerates catalog and live dictionaries. | Viewer-authorized `AiObservationSnapshot` plus `AiActionCandidate`; retain dynamic scoring and remove static catalog interpretation. |
| PFE-022 | `scripts/runtime/gameplay_balance_diagnostics_world_bridge.gd:106-148`, `:163-177`; `gameplay_balance_diagnostics_runtime_service.gd:112-159`, `:203-234`, `:889-914`, `:917-930`, `:1136-1149`; `scripts/balance/environment_balance_model.gd:66-108`; `scripts/balance/runtime_balance_model.gd:250-298`, `:630-645`, `:686-706` | Diagnostics rebuild card and product meaning from raw skill fields, localized categories, profiles, and aliases. | Standard semantic diagnostic projection shared with rules/player/AI consistency tests. |
| PFE-023 | `scripts/runtime/product_codex_public_source_service.gd:49-95`, `:230-250`, `:401-406`; `scripts/runtime/economy_dashboard_viewer_query_port.gd:117-157`; `scripts/runtime/codex_public_snapshot_service.gd:188-199`; `scripts/presentation/table_presentation_viewmodel_query.gd:294`, `:353` | Presentation formats static meaning and facility types from raw dictionaries. | `ProductPresentationDTO` and `FacilityPresentationDTO`; UI formats only DTO fields/tokens. |
| PFE-024 | `scripts/runtime/product_market_runtime_controller.gd:1627-1669`, `:1823-1826`; `scripts/runtime/region_infrastructure_runtime_controller.gd:927-985`, `:1419-1476`; `scripts/runtime/commodity_flow_runtime_controller.gd:1380-1428`, `:1464-1488` | Save data embeds current product/facility IDs but does not bind them to a shared semantic catalog fingerprint. | Add detached restore preflight against the canonical semantic catalog while preserving the existing envelope and exact encoded IDs. |

## KEEP findings

| ID | Exact evidence | Why it stays | Constraint |
| --- | --- | --- | --- |
| PFE-025 | `scripts/runtime/product_market_runtime_controller.gd:148-164`, `:486-531`, `:1627-1678`, `:1749-1752` | It is the sole live owner of market state, cadence, RNG commit, futures state, and save/load. | Remove only static content duplication; do not create another market state owner. |
| PFE-026 | `scripts/runtime/product_market_runtime_controller.gd:80-88`; product foreign keys in `data/cards/card_runtime_catalog_v06.json:29-37`; save keys at `product_market_runtime_controller.gd:1627-1648` | Current localized product IDs are real compatibility identities across systems. | Preserve exact values; no ASCII alias, transliteration, or parsing. |
| PFE-027 | `scripts/runtime/region_infrastructure_runtime_controller.gd:246-380`, `:414-567`, `:927-985` | Build/upgrade/repair, rollback/finalize, instance identity, and save are a legitimate transactional state machine. | Register semantic operations to it; do not flatten or duplicate it. |
| PFE-028 | `scripts/runtime/commodity_flow_runtime_controller.gd:330-399`, `:500-530`, `:1380-1488`, `:3940-3980`, `:4238-4280` | Installed rates, real facility/route legality, physical goods, backlog, and settlement are legitimate live rules. | Static product facts arrive through semantic facts; topology and transaction checks stay here. |
| PFE-029 | `scripts/cards/v06/effects/facility_card_effect_adapter_v06.gd:54-130`, `:141-205`, `:223-316` | The adapter preserves atomic facility mutation plus optional factory commodity installation. | Keep one composite prepare/commit/rollback/finalize boundary behind registered ops. |
| PFE-030 | `scripts/cards/v06/effects/global_supply_demand_runtime_service_v06.gd:103-157`, `:453-492`, `:525-600`; sink binding at `:665-689` | It deterministically allocates real supply/demand through existing physical owners. | Consume validated `modify_supply`/`modify_demand` plans; no second training/simulation rule engine. |
| PFE-031 | `scripts/rules/space_syndicate_ruleset_profile_v06.gd:9-16`, `:38`, `:51`, `:95-114`, `:149-166` | These are the current numeric rule/balance authorities for facilities, rates, and supply/demand units. | Semantic compilation validates equality; it does not change or re-author numbers. |
| PFE-032 | `scripts/viewmodels/public_product_selection_catalog_snapshot.gd:5-34`, `:38-99`; `scripts/presentation/table_selection_catalog_query_port.gd:41-78`; public/private facility projection at `region_infrastructure_runtime_controller.gd:874-924` | Typed detached selection and viewer-scoped facility projections already enforce read-only/public boundaries. | Retarget their static source to semantic projections without weakening authorization or adding Main access. |

## Consumer matrix

| Consumer | Current input | Classification | Migration result |
| --- | --- | --- | --- |
| Product market | static literal + mutable market | MOVE static / KEEP live | compiled Product catalog + unchanged live state |
| World generation | literal market list + `OCEAN_PRODUCTS` | REMOVE/MOVE | detached ordered Product semantic facts; identical RNG pools |
| Commodity flow | raw Product Resource + live facilities/routes | MOVE static / KEEP live | Product facts + existing flow owner |
| Region infrastructure | code facility sets + live instances | MOVE static / KEEP live | Facility specs + existing owner |
| Card compiler | v0.6 machine payload | KEEP transitional compiler | emits typed ops and domain references |
| Core economic adapter | raw machine/effect payload | MOVE | `RuleExecutionPlan` and registry binding |
| AI | direct catalog/live dictionary reads | MOVE | authorized observations and candidates |
| Product Codex | profiles + recursive payload scan | REMOVE/MOVE | Product presentation/relation DTO |
| Economy dashboard | public state with aliases | MOVE | canonical economy/product/facility DTO |
| Diagnostics | raw skill/profile/kind maps | MOVE | standard diagnostic projection |
| Save/replay | embedded current IDs and effect-kind replay branches | KEEP IDs / MOVE validation | exact payload compatibility plus semantic preflight |

## Save, replay, privacy, and RNG contract

### Save and replay

- Product market save keys remain the exact current product IDs.
- Commodity flow installations, backlog, waste, warehouse inventory, and receipts retain `commodity_id` values exactly.
- Facility `facility_type`, `industry_id`, generated `facility_id`, `slot_id`, generation, receipts, and tombstones remain unchanged.
- No new save owner or save section is proposed.
- The existing envelope shape is not changed by this audit.
- Replay target reconstruction must move behind registered handlers, but its target hash and exact-once semantics remain unchanged.
- A semantic catalog fingerprint may be checked during preflight from the active rules/content bundle; it must not silently rewrite legacy IDs.

### Privacy

- Product market prices and public pressure are public facts; private inventory, AI reasoning, owner-only facilities, and hidden cards are not added to semantic specs.
- `ProductSemanticSpec` is static and public. It conveys no player ownership or live hidden state.
- `AiObservationSnapshot` must be viewer-scoped before product/facility candidates are generated.
- Product Codex may use public static relations and public world facts, but must stop recursively inspecting arbitrary payloads.
- Existing public/own facility snapshots remain separate.

### RNG

- Product market initialization currently consumes two draws per product in market order, then one interval draw.
- New-session refresh and live refresh consume one noise draw per product in the same market order.
- Product semantic compilation consumes zero RNG.
- Replacing `PRODUCT_CATALOG` with resource array order would preserve draw count but change which product receives each draw. That is a rules regression.
- Cutover requires exact product order, resulting market snapshot, terminal RNG cursor, and replay fingerprint parity.
- Facility semantic compilation and facility operations introduce no new random draws.

## Migration sequence

1. Add read-only Product and Facility semantic schemas plus validation. Do not wire execution yet.
2. Enrich the existing product catalog with explicit market order and missing stable taxonomy/terrain tags. Prove 46/46 set and order parity.
3. Move `PRODUCT_PROFILES` into the same product source and cut Product Codex/selection/presentation to DTOs.
4. Add one canonical facility-definition catalog referencing v0.6 ruleset profiles; delete repeated type/industry sets only in the same cutover.
5. Promote the existing core economic router into `OperationHandlerRegistry`; register the six semantic ops to existing adapters/owners.
6. Move coordinator target/replay branches behind registered handler capabilities without changing hashes or transaction order.
7. Cut AI and diagnostics to authorized/standard projections.
8. Run save, replay, privacy, RNG, numeric parity, transaction rollback, and UI snapshot gates.
9. Only then delete legacy aliases, v0.5 dead assets, and v0.4 product-market gates proven unused.

## Blockers

1. **RNG order blocker:** the two 46-ID sources have different orders. A canonical catalog needs explicit current market order before any runtime source swap.
2. **Localized identity blocker:** product IDs are persisted and cross-referenced in cards, districts, routes, market state, commodity state, role/monster references, and saves. Renaming is out of scope and unsafe.
3. **Version blocker:** ProductMarket/coordinator still require v0.4 while v0.6 product/facility cards and infrastructure/flow owners are active. Finance and timing parity must precede gate removal.
4. **Facility authority blocker:** no single static facility catalog exists. Type policy is code-owned while rank numbers are ruleset-owned and repeated in card payloads.
5. **Composite transaction blocker:** factory construction can atomically install production. A naive one-op-at-a-time registry would leave partial state.
6. **Unresolved rent semantics:** card payload currently carries `rent_rate_profile = pending_first_playtest_table`; no new rent meaning may be inferred.
7. **Save binding blocker:** current owner payloads carry IDs but no shared semantic-catalog fingerprint. Preflight must be added without altering current IDs or creating a save owner.
8. **Presentation atomicity blocker:** Main, Product Codex, dashboard, map, and table surfaces depend on current profile/raw fields. DTO producer and consumers must cut over atomically.
9. **Legacy asset blocker:** v0.5 capacity and retired GDP assets appear uncomposed in production, but tool/test consumers must be classified before deletion.

These block future production cutovers, not this read-only audit.

## Preservation guarantees

- No product ID, facility kind, industry ID, card value, facility value, market formula, supply/demand amount, or balance number changed.
- No RNG call, ordering, checkpoint, or cursor changed.
- No save field, section, registry binding, replay shape, or envelope changed.
- No private state was added to a public or AI projection.
- No retired industry-capacity or GDP mechanic was restored.
- No second product market, facility state owner, commodity flow owner, content catalog, or rule engine was proposed.
- Existing owner transactions remain the execution authority behind stable registered operation IDs.

## Conclusion

The safe first cut is not a product rename and not a new economy engine. It is an immutable semantic layer over the current exact identities, an explicit frozen market order, and a registry that routes six stable operations into the owners that already execute them correctly. Static meaning moves; live ownership, formulas, transactions, RNG order, and save identity stay put.
