# Alpha 0.1 Dependency, Consumer, and Privacy Audit

## Outcome

The curated resource is internally valid: every selected card rank resolves to an existing
effect kind, target kind, and non-pending runtime owner; every role, monster, and product
exists in its authoritative source; and no selected content contains an identifier retired
by the v0.6 mechanic registry.

Activation is intentionally separate. The current production consumers still read the full
catalogs and do not yet accept the Alpha whitelist. See `integration_request.json`.

## Locked dependencies

| Dependency | SHA-256 |
|---|---|
| `data/cards/card_runtime_catalog_v06.json` | `b59b73489d23578558d4a7688a03f50a3ef4d776cf528cd9eafd0e1d2a0fcb40` |
| `scripts/runtime/role_catalog_runtime_service.gd` | `c7aef1aa6dce17466925ce0a7064cdb57c22b8c52833d1370cfd062e59dc2564` |
| `scripts/runtime/monster_catalog_v06.gd` | `d9cfe29869581f459a31cda8878393a767af5b5eb0aff639e19ef29b4dea2cce` |
| `resources/content/product_industry_catalog_v05.tres` | `5544f01d1f0e50a7be38e4fa8686ba249a89517782d2b77646b913ed93cbd77a` |
| `docs/rules/v06_mechanic_status_registry.json` | `e3eb9b442532ad2eb593581de8df2d3d4cb97b43afe93b617b4d7e88be565f1e` |

The manifest loads the real card catalog resource, role catalog scene, product catalog
resource, and monster catalog script. Hash mismatches are validation failures, not silent
fallbacks.

## Card owner and target audit

| Effect kind | Catalog owner | Existing owner source | Accepted target | Registry gate |
|---|---|---|---|---|
| `install_commodity_rate` | `commodity_flow_runtime_controller` | `scripts/runtime/commodity_flow_runtime_controller.gd` | `same_industry_factory_or_market` | Existing core effect |
| `build_upgrade_or_repair_facility` | `region_infrastructure_runtime_controller` | `scripts/runtime/region_infrastructure_runtime_controller.gd` | `region_unique_facility_slot` | Existing core effect |
| `global_order_budget` | `global_supply_demand_runtime_service` | `scripts/cards/v06/effects/global_supply_demand_runtime_service_v06.gd` | `global_matching_goods` | `conditional_order_auto_settlement` ACTIVE |
| `global_supply_spawn` | `global_supply_demand_runtime_service` | same as above | `global_matching_factories` | `conditional_order_auto_settlement` ACTIVE |
| `deploy_or_upgrade_monster` | `monster_runtime_controller` | `scripts/runtime/monster_runtime_controller.gd` | `region_or_existing_same_family_monster` | Existing unit effect |
| `deploy_or_upgrade_military` | `military_runtime_controller` | `scripts/runtime/military_runtime_controller.gd` | `region_or_owned_same_family_military` | Existing unit effect |
| `player_hand_disrupt` | `player_hand_interaction_runtime_service` | `scripts/runtime/player_hand_interaction_runtime_service.gd` | `opponent_discardable_hand` | `card_target_choice` ACTIVE |
| `player_hand_steal` | `player_hand_interaction_runtime_service` | same as above | `opponent_discardable_hand` | `card_target_choice` ACTIVE |
| `card_counter` | `card_counter_runtime_service` | `scripts/runtime/card_counter_settlement_runtime_service.gd` | `incoming_direct_player_interaction` | `card_counter_response` ACTIVE |

Result: **160/160 selected rank records have the expected active owner and target**.
No owner identifier ends in `_pending`. Organization cards are excluded.

### Existing review debt, not changed by this cut

The source catalog marks 100 selected rank records as awaiting balance/effect review:

- 48 facility records: `rent_rate_review_pending`
- 32 monster records and 12 military records: `unit_profile_review_pending`
- 8 direct hand-interaction records: `legacy_effect_review_pending`

The remaining 60 records are `rule_confirmed`. This curation proves identity, owner,
target, acquisition, and retired-mechanic compatibility; it does not sign off those inherited
values. No value was edited to hide that debt.

## Runtime consumer audit

| Content | Real generic consumers found | Per-item conclusion |
|---|---|---|
| Cards | `GameRuntimeCoordinator.region_supply_catalog_card_ids`, `RegionSupplyRuntimeController`, `CommodityCardInventoryRuntimeController` | Every selected family has a rank-I acquisition record; I-IV records are execution/upgrade gradients |
| Roles | `NewGameSetupDraftService`, `SessionStartPlanBuilder`, plus the field-level gameplay consumers below | All eight source indices are valid; each selected mechanical passive has a non-Main gameplay consumer |
| Monsters | `NewGameSetupDraftService`, `SessionStartPlanBuilder`, `MonsterRuntimeController`, `MonsterCodexPublicSourceService` | The selected eight are the complete runtime roster |
| Products | `CommodityFlowRuntimeController`, `ProductMarketRuntimeController`, `GdpFormulaRuntimeController` | The selected 46 are the complete economy catalog |

The draw semantics were checked specifically:

- Regional supply builds descriptors only when `rank == 1`; `RegionSupplyRuntimeController`
  also rejects a non-rank-I descriptor.
- The default commodity belt scans the 184 commodity rank records but selects only rank-I
  records and seeds eight visible entries.
- Therefore the current runtime does **not** randomize 160 selected rank records as 160
  separate player cards.

The production catalogs are not filtered yet. Current production still offers a universe of
41 non-commodity rank-I regional-supply identities, 46 commodity families, and 24 roles.
The Alpha resource instead declares 28 regional-supply identities, 12 commodity identities,
and 8 roles. Activating those filters crosses the assigned owner boundary.

## Selected-role gameplay consumer audit

The role selection now fails closed when any selected mechanical passive field lacks a
known runtime gameplay consumer. A role definition's `name`, `species`, `trait`, `passive`,
and `flavor` are public identity fields; every other selected field is treated as mechanical.
The evidence source must live under `scripts/runtime`, must contain the exact field and API,
and may not be Main, presentation, Codex, diagnostics, tools, tests, or the role catalog.

| Mechanical field | Non-Main gameplay consumer | Consuming API |
|---|---|---|
| `starting_cash_bonus` | `SessionStartPlanBuilder` | `_build_players` |
| `bonus_card_product` | `DistrictSupplyActionPort` | `_grant_role_bonus_card` |
| `resource_cash_product` | `RoleResourceCashSettlementRuntimeService` | `plan_for_sale_receipt` |
| `resource_cash_amount` | `RoleResourceCashSettlementRuntimeService` | `plan_for_sale_receipt` |
| `monster_upgrade_cash` | `MonsterRuntimeController` | `_commit_role_monster_upgrade_cash` |
| `card_history_residual_catalog_charges` | `IntelPrivateCommandPort` | `use_residual_frame_catalog` |
| `high_volatility_sale_threshold` | `RoleResourceCashSettlementRuntimeService` | `_high_volatility_plan` |
| `high_volatility_first_sale_bonus` | `RoleResourceCashSettlementRuntimeService` | `_high_volatility_plan` |
| `high_volatility_bonus_once_per_market_cycle` | `RoleResourceCashSettlementRuntimeService` | `_high_volatility_plan` |
| `monster_control_limit_bonus` | `MonsterRuntimeController` | `_player_monster_control_limit` |
| `military_control_limit_bonus` | `MilitaryRuntimeController` | `player_control_limit` |

Across the eight selected roles this is **18 field occurrences across 11 unique fields**.
`星图审计庭` is no longer selected: `intel_city_reveal_charges` has no non-Main gameplay
consumer and `city_guess_reward_bonus` is still consumed only by legacy Main. It is replaced
by source index 9, `幽幕播报社`, whose existing `card_history_residual_catalog_charges`
flows through the typed private intel command path. No role definition or gameplay rule was
changed by this curation.

## Retired-mechanic audit

The validator derives all 20 retired identifiers from
`docs/rules/v06_mechanic_status_registry.json` and scans:

- all 160 selected card records;
- the eight selected public role definitions;
- all eight selected monster definitions; and
- all 46 product snapshots.

Result: **zero retired-identifier hits**. In particular, no contract response/accept/reject/
timeout/signature/penalty state, retired contract-trace card, or organization pending owner is
present in the cut.

## Hidden-information audit

The manifest's public selection snapshot is deliberately narrower than its internal validator.

- Roles: stores public names only. Public passive text remains in the authoritative role
  service; private inference results are not copied into the manifest.
- Cards: stores family IDs, rank-I acquisition IDs, and ranked record IDs only. It does not
  expose effect payloads, runtime owner paths, hands, discard choices, or player ownership.
- Monsters: roster membership is public catalog information. A seat's held starter-monster
  choice and monster ownership are runtime facts and are absent.
- Products: product IDs are public economy vocabulary.
- The snapshot contains no cash, hand, owner, private, developer, AI reasoning, pressure
  bucket, or route-plan keys and contains only pure data.

Runtime owner paths and review statuses appear only in the developer validation report; they
are not part of `selection_snapshot()`.
