# Card Semantic Current-State Audit (Wave 1A)

## Audit identity

- Baseline: `59756a291f811a064726f59aed27efecc3590c9a`
- Assigned branch: `codex/card-semantic-wave1-a-audit-59756a2`
- Audit date: `2026-07-26`
- Production changes: none
- Machine-readable companion: `reports/cards/card_effect_payload_inventory.json`
- Method: structured `ConvertFrom-Json` parsing of the v0.6 catalog, deterministic aggregation, then source-level consumer and authority tracing. Tests, builders, reports, and comments were not counted as production payload consumers.

## Executive finding

The repository currently has two distinct card-definition systems, not one unified semantic catalog:

1. The global Resource-backed catalog remains the v0.4 graph: 113 family `.tres` files, 230 authored rank resources, 10 packs, and `card_runtime_catalog_v04.tres` as the root (`resources/cards/runtime/card_runtime_catalog_v04.tres:1`; `scripts/runtime/card_runtime_catalog_service.gd:4`).
2. The v0.6 Resource is a thin JSON loader whose source is `data/cards/card_runtime_catalog_v06.json` (`resources/cards/runtime/card_runtime_catalog_v06.tres:8`; `scripts/cards/card_runtime_catalog_v06_resource.gd:25`). It contains 348 cards in 87 complete I-IV families.

The v0.6 catalog is structurally complete, but semantic consumption is partial. It declares 113 distinct `effect_payload` keys across 2,920 key occurrences. Active code directly consumes only subsets; many remaining fields mirror Ruleset values or legacy flat fields, and 11 have no qualifying production read. Every catalog record still says `catalog_ready_runtime_wiring_pending`.

## Catalog inventory

### Resource graph

| Surface | Current count/status | Current role |
| --- | ---: | --- |
| `resources/cards/runtime/families/` | 113 family files | v0.4 global Resource catalog authoring graph |
| `resources/cards/runtime/packs/` | 10 packs, 113 family references, each family referenced once | v0.4 editorial grouping |
| `card_runtime_catalog_v04.tres` | 230 authored rank records | Global `CardRuntimeCatalogService` source |
| `card_runtime_catalog_v05.tres` | 5 records, 0 release-ready | Blocked migration catalog |
| `card_runtime_catalog_v06.tres` | Expected 348 cards / 87 families | Loader over the v0.6 JSON |
| `alpha01_content_manifest.tres` | 40 families / 160 rank records | Active playable selection, not the whole v0.6 catalog (`resources/content/alpha01/alpha01_content_manifest.tres:17`) |

The Alpha-01 selection contains 12 commodity, 12 facility, 3 interaction, 2 supply/demand, 3 military, and 8 monster families. It contains no organization family and omits 47 other v0.6 families.

### v0.6 family/rank totals

| Category | Families | Cards |
| --- | ---: | ---: |
| Commodity | 46 | 184 |
| Facility | 16 | 64 |
| Interaction | 3 | 12 |
| Military | 7 | 28 |
| Monster | 8 | 32 |
| Organization | 5 | 20 |
| Supply/demand | 2 | 8 |
| **Total** | **87** | **348** |

Each rank I-IV occurs 87 times. There are no duplicate `machine.card_id` values, and every family has exactly ranks `[1, 2, 3, 4]`. The validator requires `card_id == family_id + ".rank_" + rank` and stable ASCII machine identity (`scripts/cards/card_runtime_catalog_v06_resource.gd:115`).

### Layer inventory

| Layer | Distinct fields | Completeness | Purpose |
| --- | ---: | --- | --- |
| `machine` | 16 | Every field occurs 348 times | Stable identity, acquisition, activation cost, effect/target routing, payload |
| `player` | 13 | Every field occurs 348 times | Public name, rank, cost/timing/target/effect/duration/visibility copy |
| `developer` | 7 | Six fields occur 348 times; `legacy_v04_family` occurs 12 times | Declared owner, review/wiring state, source-rule and art metadata |

Stable gameplay identity is `machine.card_id`, `machine.family_id`, and `machine.rank`; `category_id` and `industry_id` classify that identity. `player.name` and Roman `player.rank` are display aliases, not stable IDs. `developer.runtime_owner` is advisory metadata, not proof that a production route exists.

`runtime_instance_id` is absent from the static catalog. The transaction service re-loads a canonical full card and adds `runtime_instance_id` to that same dictionary when constructing a hand slot (`scripts/cards/v06/card_flow_transaction_service_v06.gd:1273`).

## Costs, timing, and targets

The active rule separates acquisition cash from activation assets: commodities are free to acquire/play; other ordinary cards pay cash when bought and assets when played (`docs/tabletop_rulebook_v06.md:373`). The catalog models this separation correctly at the field level:

- Acquisition: `machine.acquisition_kind` plus `machine.purchase_cash`.
- Activation: `machine.asset_cost`.
- 184 cards use `commodity_belt_free`; 132 use `dynamic_market_cash`; 32 use `starter_or_dynamic_market_cash`.
- 184 commodities have zero purchase cash. All 164 noncommodity records have positive purchase cash.
- 200 records have zero activation assets: 184 commodities plus all 16 rank-I facilities. The remaining 148 records have positive activation assets.
- Timing copy: 324 `普通出牌窗口`, 20 `普通出牌窗口；次窗生效`, and 4 `合法响应窗口`.

The nine target kinds are complete and nonempty:

| `target_kind` | Cards |
| --- | ---: |
| `same_industry_factory_or_market` | 184 |
| `region_unique_facility_slot` | 64 |
| `region_or_existing_same_family_monster` | 32 |
| `region_or_owned_same_family_military` | 28 |
| `self_organization_slot` | 20 |
| `opponent_discardable_hand` | 8 |
| `global_matching_goods` | 4 |
| `global_matching_factories` | 4 |
| `incoming_direct_player_interaction` | 4 |

`CardFlowPolicyV06` compares a caller-supplied legal target context with `machine.target_kind`, then plans the asset debit (`scripts/cards/v06/card_flow_policy_v06.gd:348`). Target legality is therefore runtime state, not catalog payload authority.

## Effect ownership and rule authority

| `effect_kind` | Cards | Declared owner | Observed v0.6 route | Rule authority |
| --- | ---: | --- | --- | --- |
| `install_commodity_rate` | 184 | Commodity flow | Core economic route | `RULE_AUTHORITY_NOT_ESTABLISHED`; rulebook clauses exist, no mechanic ID |
| `build_upgrade_or_repair_facility` | 64 | Region infrastructure | Core economic route | `RULE_AUTHORITY_NOT_ESTABLISHED`; rulebook clauses exist, no mechanic ID |
| `deploy_or_upgrade_monster` | 32 | Monster runtime | Capability-gated monster route | `RULE_AUTHORITY_NOT_ESTABLISHED`; rulebook section 9 |
| `deploy_or_upgrade_military` | 28 | Military runtime | Unsupported fallthrough | `RULE_AUTHORITY_NOT_ESTABLISHED` |
| `install_organization_upgrade` | 20 | Catalog says owner pending | Core route exists, but active selection excludes it and consumer capabilities are incomplete | `RULE_AUTHORITY_NOT_ESTABLISHED`; higher authority says cards are not yet open |
| `global_order_budget` | 4 | Global supply/demand | Shared-resolution core route | `conditional_order_auto_settlement` ACTIVE |
| `global_supply_spawn` | 4 | Global supply/demand | Shared-resolution core route | `conditional_order_auto_settlement` ACTIVE |
| `player_hand_disrupt` | 4 | Hand interaction | Unsupported fallthrough | Effect mechanic `RULE_AUTHORITY_NOT_ESTABLISHED`; target window relates to `card_target_choice` ACTIVE |
| `player_hand_steal` | 4 | Hand interaction | Unsupported fallthrough | Effect mechanic `RULE_AUTHORITY_NOT_ESTABLISHED`; target window relates to `card_target_choice` ACTIVE |
| `card_counter` | 4 | Counter runtime | Unsupported fallthrough | `card_counter_response` ACTIVE |

The route evidence is explicit: the coordinator handles five core-economic kinds and monster cards, then returns `unsupported_v06_card_runtime` for the remaining kinds (`scripts/runtime/game_runtime_coordinator.gd:2641`). Active mechanic IDs come from the status registry (`docs/rules/v06_mechanic_status_registry.json:14`, `:16`, `:24`). No mechanic ID was inferred from a filename or owner name.

There is a material organization authority conflict. The catalog marks organization cards available and provides full effects, while the higher-order rulebook says organization cards are not yet open for purchase or installation (`docs/tabletop_rulebook_v06.md:440`). The active Alpha-01 selection excludes them, which currently prevents the catalog declaration from becoming live supply.

## Payload classification

Classification is by observed consumer topology, separate from rule authority:

- `authoritative` (56): directly read or value-validated by a current domain owner.
- `compatibility` (29): the layered field is a mirror; active behavior comes from a Ruleset, hard-coded policy, or same-name flat legacy path.
- `AI-only` (0): no field is directly consumed only by layered v0.6 AI.
- `executor-only` (4): `heal_to_full_on_upgrade`, `military_family_id`, `response_depth`, `target_scope`.
- `multi-consumer` (13): `allowed_region_states`, `card_rank`, `controlled_monster_count_limit`, `direct_player_interaction`, `facility_kind`, `industry_id`, `monster_family_id`, `organization_axis`, `organization_rank`, `primary_monster_rank_limit`, `product_id`, `same_name_upgrade_extend_seconds`, `secondary_monster_rank_limit`.
- `unknown` (11): no qualifying direct production read.

Compatibility fields:

`bound_actions_excluded_from_hand_limit`, `bound_actions_require_assets`, `bound_skill_recipient`, `counter_strength`, `counter_window_seconds`, `demand_capacity_units_per_minute`, `hand_discard_count`, `hand_lock_seconds`, `hand_steal_count`, `inbound_throughput_units_per_minute`, `operation_policy`, `outbound_throughput_units_per_minute`, `production_capacity_units_per_minute`, `rank4_repeat_behavior`, `rate_per_minute`, `region_damage_requires_explicit_unit_action`, `rent_enabled`, `shared_hp_contribution`, `shared_hp_profile`, `speed_multiplier`, `starter_conflict_policy`, `steal_fail_cash`, `storage_capacity_units`, `target_cash_penalty`, `throughput_units_per_minute`, `unit_profile_owns_stats`, `upgrade_respects_target_owner_rank_cap`, `upgrade_target_same_family_any_owner`, `valid_facility_kinds`.

Unknown fields:

`ai_effect_tags`, `anti_snowball_cap`, `bound_action_profile_review_pending`, `counterplay_tags`, `private_trace_count`, `public_clue_kind`, `public_same_source_aura`, `refund_cash`, `rent_rate_profile`, `required_own_gdp_min`, `required_positive_gdp_color_count`.

The JSON companion records every field's exact occurrence count, family/effect/target coverage, value types, first catalog line, evidence IDs, and authority IDs.

## Direct consumer audit

### AI

`AiRuntimeController` resolves flat definitions through `CardRuntimeDefinitionWorldBridge` (`scripts/runtime/ai_runtime_controller.gd:1505`) and directly scores flat fields such as `hand_discard_count`, `hand_steal_count`, `counter_strength`, and economy deltas (`scripts/runtime/ai_runtime_controller.gd:7398`). Those are v0.4-style `skill` reads, not reads from `machine.effect_payload`.

No direct layered payload read was found in `AiRuntimeController`; notably, `ai_effect_tags` has no consumer. A coordinator helper named `_ai_v06_legal_facility_region_ids` reads only `facility_kind`, `industry_id`, and `allowed_region_states` (`scripts/runtime/game_runtime_coordinator.gd:2473`), but no direct `AiRuntimeController` call to that helper was found. AI can inspect public rack IDs and prices, but field-driven v0.6 scoring is not established.

### Executors

- Commodity adapter: reads `product_id` and `industry_id`, derives rank from `card_id`, and does not read `rate_per_minute`, `valid_facility_kinds`, or commodity `persistence` (`scripts/cards/v06/effects/commodity_card_effect_adapter_v06.gd:42`). The active Ruleset owns `commodity_rate_by_rank` (`scripts/rules/space_syndicate_ruleset_profile_v06.gd:38`).
- Facility adapter: reads `facility_kind`, `card_rank`, `industry_id`, and `allowed_region_states` (`scripts/cards/v06/effects/facility_card_effect_adapter_v06.gd:66`). HP, capacity, throughput, speed, storage and rent payload values are not direct inputs; active rank profiles live in the Ruleset (`scripts/rules/space_syndicate_ruleset_profile_v06.gd:9`).
- Supply/demand owner: validates and consumes its complete contract, including route tag, distance, GDP allocation, real-node/capacity flags and unit budget (`scripts/cards/v06/effects/global_supply_demand_runtime_service_v06.gd:453`).
- Organization owner: validates most common/axis payload terms and stores the payload (`scripts/runtime/player_organization_runtime_controller.gd:547`), but does not enforce `required_own_gdp_min` or `required_positive_gdp_color_count`. It hard-codes the public clue instead of reading `public_clue_kind`.
- Monster owner: directly checks presence policy, extension seconds, refresh prohibition and ownership transfer (`scripts/runtime/monster_runtime_controller.gd:2962`). Other monster declarations remain mirrors or reference-schema fields.
- Military and interaction schemas exist, but their v0.6 catalog effect kinds fall through the production route gate.

### UI and presentation aliases

The Codex converts machine/player fields into a separate flat presentation vocabulary: `effect_kind -> kind`, `purchase_cash -> price`, `player.name -> display_name`, and text/timing/target aliases (`scripts/runtime/card_codex_public_source_service.gd:201`). Target booleans are inferred from string containment in `target_kind`, not a typed target schema.

The table view has a second normalization and explicitly limits the v0.6 cutover to facilities (`scripts/presentation/table_presentation_viewmodel_query.gd:632`). Region supply creates another alias set (`display_name`, `price_cash`, `target_type`, `effect_text`) (`scripts/runtime/game_runtime_coordinator.gd:5597`). Product Codex is the only presentation consumer that recursively searches payload values, solely to find product-related cards (`scripts/runtime/product_codex_public_source_service.gd:291`).

## Definition/state/action mixing

1. **Static definition plus instance state:** hand slots carry the complete canonical machine/player/developer card and append `runtime_instance_id`; other paths also add `queued_for_resolution` and `lock_left`. Static developer metadata therefore travels with private instances instead of being referenced by stable ID.
2. **Static definition plus legal action:** queued supply/demand handling writes `_v06_automatic_target_context` into the card dictionary (`scripts/runtime/game_runtime_coordinator.gd:2760`). This mixes transient legality with the card instance.
3. **Aliases split by surface:** Codex, table, and region supply each flatten the layers differently. Only the table path is facility-aware; other categories can fail closed or display through different semantics.
4. **Duplicated authority:** commodity rate and facility numeric fields exist in payload while execution relies on rank/Ruleset profiles. A catalog edit can change player text/payload without changing execution.

## Risks and Wave-2 gates

1. **Authority conflict:** keep organization cards excluded until the rulebook is changed or the catalog is made unavailable. Do not infer a mechanic ID.
2. **Semantic drift:** choose one authority for commodity rate and facility HP/capacity/throughput/rent, then validate player text and payload against that owner.
3. **AI blindness:** add a typed v0.6 semantic projection before claiming `ai_effect_tags` or payload-based AI scoring.
4. **Unsupported effects:** military, hand disruption/steal, and counter cards must remain fail closed until composed owners satisfy the authority gate.
5. **Unenforced organization gates:** `required_own_gdp_min` and `required_positive_gdp_color_count` must not be treated as legal requirements until an authoritative consumer exists.
6. **Metadata overclaim:** all 348 records remain wiring-pending; 132 records also have non-confirmed effect review status (64 rent, 60 unit profile, 8 legacy interaction).
7. **State separation:** future semantic DTO work should store only stable `card_id` plus instance state, and keep legal-action context in a separate intent/envelope.
8. **Presentation contract:** replace string heuristics and per-surface flattening with one sanitized typed projection once category target schemas are established.

## Audit conclusion

The catalog is count-complete and identity-stable, but it is not a single executable semantic authority. The safe current interpretation is: JSON fields are authored declarations; only fields with an observed owner read are executable inputs; Ruleset mirrors and flat legacy reads are compatibility surfaces; unsupported and unknown fields must remain fail closed. Missing mechanic IDs are recorded as `RULE_AUTHORITY_NOT_ESTABLISHED` rather than inferred.
