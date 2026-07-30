# Alpha 0.4-C depth-1 card action routing inventory

Status: `AUDIT_COMPLETE_NO_PRODUCTION_CHANGE`

Source: `a55b938f41402be2f3eb510300c483de5ae09458` on challenge depth `1`.

This is a static and committed-evidence audit. It changes no production code, test, scene, state, Save owner, RNG owner, or UID. It does not run the Formal chain, official cold-restore chain, qualification, or full Smoke.

## Reachable identity boundary

The active manifest directly sources 28 non-commodity rank-I families and 12 unique commodity rank-I cards. RegionSupply rebuilds a region's deterministic bag from the same legal non-unique rank-I set whenever that bag empties. The inventory transaction owner can merge two same-family same-rank cards into the next catalog rank. Therefore the complete single-run obtainable identity set is:

- 28 repeating region families x ranks I-IV = 112 IDs;
- 12 one-shot commodity-track rank-I IDs = 12 IDs;
- total `DEPTH1_CONCRETE_CARD_IDENTITY_COUNT=124` across 40 families.

Higher commodity ranks are not counted: the audited belt has one unique claimable rank-I item per selected commodity ID and no production refill path. Starter entitlements reuse eight rank-I monster IDs and add no identity.

## Counting contract

- `DEPTH1_ACTION_FAMILY_COUNT=9`: the eight required classification buckets plus the actually acquirable commodity bucket.
- `DEPTH1_CONCRETE_CARD_FAMILY_COUNT=40`.
- `DEPTH1_CONCRETE_CARD_IDENTITY_COUNT=124`.
- Static route identity counts are not live legal-offer counts. The exact live direct count was not serialized by the bounded qualification.

## Result

- `DEPTH1_DIRECT_RESOLVE_CAPABLE_IDENTITY_COUNT=68`: 48 facilities, 12 rank-I commodities, and 8 rank-I monster IDs when selected as the actor's unconsumed starter.
- `DEPTH1_QUEUE_ROUTE_IDENTITY_COUNT=8`: ranks I-IV of the two supply/demand families.
- `DEPTH1_UNSUPPORTED_PRE_QUEUE_IDENTITY_COUNT=48`: 12 interactions, 12 military cards, and 24 higher-rank monster cards.
- `DEPTH1_BOUND_ACTION_INSTANCE_COUNT=0`.
- `DEPTH1_LEGAL_DIRECT_RESOLVE_ACTION_COUNT_BEFORE_EXACT=EVIDENCE_INSUFFICIENT`.
- `DEPTH1_LEGAL_DIRECT_RESOLVE_ACTION_COUNT_BEFORE_LOWER_BOUND=1`.
- `DEPTH1_LEGAL_QUEUEABLE_ACTION_COUNT_BEFORE=0` for seed `900626424`, 1 local + 3 AI, run `alpha04c-qualification-decoupled-economy-02`.

The direct lower bound is backed by committed production facility play evidence. The exact number of simultaneously legal direct offers was not captured, so this audit does not relabel 68 static route-capable identities as 68 live offers. The Queue count is exact for the frozen capture: it ended with `legal_factory_market_queue_target_missing` and `queue_count=0`.

## Post-bridge delta

The table above remains the frozen `a55b938f` before-snapshot. On the current
bridge descendant, all 48 factory/market identities use one capability-bound
facility Queue route. Static depth-1 routing is now:

- Queue route identities: `56` (`48` facility plus `8` conditional supply/demand);
- direct-resolve-capable identities: `20` (`12` commodity plus `8` selected rank-I starters);
- pre-Queue unsupported identities: `48`;
- direct facility resolution paths: `0`;
- facility Queue submission paths: `1`.

The Queue preserves front order: a facility cannot pass an earlier ordinary
entry. Submission reserves assets, moves the card to escrow, and binds the
target without applying the facility. RegionInfrastructure remains the only
facility rule Owner. Card finalization follows facility finalization so a
post-effect card-owner fault remains a saveable commitment retry instead of
destroying the only recoverable card record.

Focused route, privacy, rollback, parity, and restore gates are green. A new
trusted non-official depth-1 qualification at seed `900626424` is still required
before the post-bridge live legal Queue count is promoted to current evidence.

## Classification

| Required bucket | Internal bucket | Obtainable IDs | Current resolution | Queue status |
| --- | --- | ---: | --- | --- |
| Factory facility | `facility_factory` | 24 | direct V0.6 CardFlow | No |
| Market facility | `facility_market` | 24 | direct V0.6 CardFlow | No |
| Other facility | `facility_other` | 0 | none reachable | No |
| Ordinary/shared interaction | `ordinary_shared_effect` | 12 | pre-Queue route rejection | No |
| Supply/demand | `supply_demand` | 8 | shared Queue after preflight | Code yes; frozen legal count 0 |
| Monster card | `monster_card` | 32 | rank-I selected starter direct; ranks II-IV reject | No |
| Military card | `military_card` | 12 | pre-Queue route rejection | No |
| Monster/military bound action | `monster_or_military_bound_action` | 0 | latent legacy Queue route only | No concrete offer |
| Commodity | `commodity` | 12 | direct V0.6 CardFlow | No |

## Production route

```text
Player Card Dock / capability-bound AI offer
  -> GameActionOfferV1(card.play)
  -> GameActionIntentV1(card.play)
  -> TablePlayerActionApplicationFlowController
  -> CardPlaySubmissionRuntimeController
       -> _submit_v06
          -> GameRuntimeCoordinator.play_v06_runtime_card
          -> CardFlowTransactionServiceV06
          -> domain Owner                         [direct]
       -> _submit_v06_automatic_supply_demand
          -> CardResolutionQueueRuntimeService
          -> authorized resolution step
          -> GlobalSupplyDemandRuntimeServiceV06  [queued]
```

The only existing shared-Queue effect kinds are `global_order_budget` and `global_supply_spawn`. Facilities of every obtainable rank enter `_submit_v06()` and call `play_v06_runtime_card()` in the submission stack. They never survive the submission call as a Queue entry.

## Owner graph

| Responsibility | Current owner |
| --- | --- |
| `offer_and_intent_owner` | TablePlayerActionApplicationFlowController |
| `card_submission_owner` | CardPlaySubmissionRuntimeController |
| `direct_card_transaction_owner` | CommodityCardInventoryRuntimeController + CardFlowTransactionServiceV06 + CardPlayerStateProductionAdapterV06 |
| `facility_effect_owner` | RegionInfrastructureRuntimeController through FacilityCardEffectAdapterV06 |
| `commodity_effect_owner` | CommodityFlowRuntimeController through CommodityCardEffectRuntimeBridge |
| `supply_demand_effect_owner` | GlobalSupplyDemandRuntimeServiceV06 through CommodityFlowRuntimeController atomic batch sink |
| `monster_effect_owner` | MonsterRuntimeController through MonsterCardEffectAdapterV06 |
| `queue_owner` | CardResolutionQueueRuntimeService |
| `inventory_dynamic_state_owner` | WorldSessionState; CardPlayerStateProductionAdapterV06 is a lock/CAS adapter and stores no second inventory |
| `activation_asset_owner` | PlayerManaRuntimeController |
| `region_supply_owner` | RegionSupplyRuntimeController; non-unique rank-I bags rebuild after exhaustion |
| `merge_owner` | CardFlowTransactionServiceV06/CardInventoryRuntimeService policy |
| `save_sections_touched_by_existing_routes` | card_inventory, card_resolution_queue, player_mana, region_infrastructure, commodity_flow, monster_runtime |

`CardPlayerStateProductionAdapterV06` reserves and CAS-commits existing `WorldSessionState` slots plus `PlayerManaRuntimeController` assets; it stores no second inventory, cash, or asset state. `CardResolutionQueueRuntimeService` owns Queue order/save state but declares `asset_reservation_authority=false`.

## Per-card inventory

The JSON companion contains every requested field for all 124 obtainable card identities. Catalog purchase cash is shown as authored evidence; for ranks II-IV, the actual depth-1 acquisition mode is merge, not direct purchase.

| Card semantic ID | Acquisition mode | Bucket | Effect / target | Current mode | Direct | Queueable | Frozen legal | Exact catalog values |
| --- | --- | --- | --- | --- | ---: | ---: | ---: | --- |
| `commodity.blue_tide_algae.rank_1` | `commodity_sushi_track_rank1_single_item` | `commodity` | `install_commodity_rate` / `same_industry_factory_or_market` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 0; assets all 0 |
| `commodity.deep_sea_fungal_mat.rank_1` | `commodity_sushi_track_rank1_single_item` | `commodity` | `install_commodity_rate` / `same_industry_factory_or_market` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 0; assets all 0 |
| `commodity.dream_fragrance.rank_1` | `commodity_sushi_track_rank1_single_item` | `commodity` | `install_commodity_rate` / `same_industry_factory_or_market` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 0; assets all 0 |
| `commodity.gravity_ceramic.rank_1` | `commodity_sushi_track_rank1_single_item` | `commodity` | `install_commodity_rate` / `same_industry_factory_or_market` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 0; assets all 0 |
| `commodity.living_chip.rank_1` | `commodity_sushi_track_rank1_single_item` | `commodity` | `install_commodity_rate` / `same_industry_factory_or_market` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 0; assets all 0 |
| `commodity.photosynthetic_gel.rank_1` | `commodity_sushi_track_rank1_single_item` | `commodity` | `install_commodity_rate` / `same_industry_factory_or_market` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 0; assets all 0 |
| `commodity.ring_crystal_battery.rank_1` | `commodity_sushi_track_rank1_single_item` | `commodity` | `install_commodity_rate` / `same_industry_factory_or_market` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 0; assets all 0 |
| `commodity.solar_scale.rank_1` | `commodity_sushi_track_rank1_single_item` | `commodity` | `install_commodity_rate` / `same_industry_factory_or_market` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 0; assets all 0 |
| `commodity.star_whale_canning.rank_1` | `commodity_sushi_track_rank1_single_item` | `commodity` | `install_commodity_rate` / `same_industry_factory_or_market` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 0; assets all 0 |
| `commodity.storm_pearl.rank_1` | `commodity_sushi_track_rank1_single_item` | `commodity` | `install_commodity_rate` / `same_industry_factory_or_market` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 0; assets all 0 |
| `commodity.titanium_shell_clam.rank_1` | `commodity_sushi_track_rank1_single_item` | `commodity` | `install_commodity_rate` / `same_industry_factory_or_market` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 0; assets all 0 |
| `commodity.trajectory_ink.rank_1` | `commodity_sushi_track_rank1_single_item` | `commodity` | `install_commodity_rate` / `same_industry_factory_or_market` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 0; assets all 0 |
| `facility.factory.commerce.rank_1` | `district_supply_rank1_repeat` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | yes | catalog cash 4; assets all 0 |
| `facility.factory.commerce.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 7; assets commerce:2 |
| `facility.factory.commerce.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 11; assets commerce:4 |
| `facility.factory.commerce.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 16; assets commerce:7 |
| `facility.factory.energy.rank_1` | `district_supply_rank1_repeat` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | yes | catalog cash 4; assets all 0 |
| `facility.factory.energy.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 7; assets energy:2 |
| `facility.factory.energy.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 11; assets energy:4 |
| `facility.factory.energy.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 16; assets energy:7 |
| `facility.factory.industry.rank_1` | `district_supply_rank1_repeat` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | yes | catalog cash 4; assets all 0 |
| `facility.factory.industry.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 7; assets industry:2 |
| `facility.factory.industry.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 11; assets industry:4 |
| `facility.factory.industry.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 16; assets industry:7 |
| `facility.factory.life.rank_1` | `district_supply_rank1_repeat` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | yes | catalog cash 4; assets all 0 |
| `facility.factory.life.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 7; assets life:2 |
| `facility.factory.life.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 11; assets life:4 |
| `facility.factory.life.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 16; assets life:7 |
| `facility.factory.shipping.rank_1` | `district_supply_rank1_repeat` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | yes | catalog cash 4; assets all 0 |
| `facility.factory.shipping.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 7; assets shipping:2 |
| `facility.factory.shipping.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 11; assets shipping:4 |
| `facility.factory.shipping.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 16; assets shipping:7 |
| `facility.factory.technology.rank_1` | `district_supply_rank1_repeat` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | yes | catalog cash 4; assets all 0 |
| `facility.factory.technology.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 7; assets technology:2 |
| `facility.factory.technology.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 11; assets technology:4 |
| `facility.factory.technology.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_factory` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 16; assets technology:7 |
| `facility.market.commerce.rank_1` | `district_supply_rank1_repeat` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | yes | catalog cash 4; assets all 0 |
| `facility.market.commerce.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 7; assets commerce:2 |
| `facility.market.commerce.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 11; assets commerce:4 |
| `facility.market.commerce.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 16; assets commerce:7 |
| `facility.market.energy.rank_1` | `district_supply_rank1_repeat` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | yes | catalog cash 4; assets all 0 |
| `facility.market.energy.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 7; assets energy:2 |
| `facility.market.energy.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 11; assets energy:4 |
| `facility.market.energy.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 16; assets energy:7 |
| `facility.market.industry.rank_1` | `district_supply_rank1_repeat` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | yes | catalog cash 4; assets all 0 |
| `facility.market.industry.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 7; assets industry:2 |
| `facility.market.industry.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 11; assets industry:4 |
| `facility.market.industry.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 16; assets industry:7 |
| `facility.market.life.rank_1` | `district_supply_rank1_repeat` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | yes | catalog cash 4; assets all 0 |
| `facility.market.life.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 7; assets life:2 |
| `facility.market.life.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 11; assets life:4 |
| `facility.market.life.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 16; assets life:7 |
| `facility.market.shipping.rank_1` | `district_supply_rank1_repeat` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | yes | catalog cash 4; assets all 0 |
| `facility.market.shipping.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 7; assets shipping:2 |
| `facility.market.shipping.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 11; assets shipping:4 |
| `facility.market.shipping.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 16; assets shipping:7 |
| `facility.market.technology.rank_1` | `district_supply_rank1_repeat` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | yes | catalog cash 4; assets all 0 |
| `facility.market.technology.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 7; assets technology:2 |
| `facility.market.technology.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 11; assets technology:4 |
| `facility.market.technology.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `facility_market` | `build_upgrade_or_repair_facility` / `region_unique_facility_slot` | `direct_v06_cardflow_transaction` | yes | no | no | catalog cash 16; assets technology:7 |
| `interaction.phase_veto.rank_1` | `district_supply_rank1_repeat` | `ordinary_shared_effect` | `card_counter` / `incoming_direct_player_interaction` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 5; assets technology:2 |
| `interaction.phase_veto.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `ordinary_shared_effect` | `card_counter` / `incoming_direct_player_interaction` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 8; assets technology:3 |
| `interaction.phase_veto.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `ordinary_shared_effect` | `card_counter` / `incoming_direct_player_interaction` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 12; assets technology:5 |
| `interaction.phase_veto.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `ordinary_shared_effect` | `card_counter` / `incoming_direct_player_interaction` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 17; assets technology:8 |
| `interaction.shadow_warehouse_traction.rank_1` | `district_supply_rank1_repeat` | `ordinary_shared_effect` | `player_hand_steal` / `opponent_discardable_hand` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 5; assets technology:2 |
| `interaction.shadow_warehouse_traction.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `ordinary_shared_effect` | `player_hand_steal` / `opponent_discardable_hand` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 8; assets technology:3 |
| `interaction.shadow_warehouse_traction.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `ordinary_shared_effect` | `player_hand_steal` / `opponent_discardable_hand` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 12; assets technology:5 |
| `interaction.shadow_warehouse_traction.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `ordinary_shared_effect` | `player_hand_steal` / `opponent_discardable_hand` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 17; assets technology:8 |
| `interaction.starlink_dismantle.rank_1` | `district_supply_rank1_repeat` | `ordinary_shared_effect` | `player_hand_disrupt` / `opponent_discardable_hand` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 5; assets technology:2 |
| `interaction.starlink_dismantle.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `ordinary_shared_effect` | `player_hand_disrupt` / `opponent_discardable_hand` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 8; assets technology:3 |
| `interaction.starlink_dismantle.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `ordinary_shared_effect` | `player_hand_disrupt` / `opponent_discardable_hand` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 12; assets technology:5 |
| `interaction.starlink_dismantle.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `ordinary_shared_effect` | `player_hand_disrupt` / `opponent_discardable_hand` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 17; assets technology:8 |
| `unit.military.air_superiority_fighter.rank_1` | `district_supply_rank1_repeat` | `military_card` | `deploy_or_upgrade_military` / `region_or_owned_same_family_military` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 6; assets industry:2 |
| `unit.military.air_superiority_fighter.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `military_card` | `deploy_or_upgrade_military` / `region_or_owned_same_family_military` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 10; assets industry:4 |
| `unit.military.air_superiority_fighter.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `military_card` | `deploy_or_upgrade_military` / `region_or_owned_same_family_military` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 15; assets industry:6 |
| `unit.military.air_superiority_fighter.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `military_card` | `deploy_or_upgrade_military` / `region_or_owned_same_family_military` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 21; assets industry:9 |
| `unit.military.planetary_defense_force.rank_1` | `district_supply_rank1_repeat` | `military_card` | `deploy_or_upgrade_military` / `region_or_owned_same_family_military` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 6; assets industry:2 |
| `unit.military.planetary_defense_force.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `military_card` | `deploy_or_upgrade_military` / `region_or_owned_same_family_military` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 10; assets industry:4 |
| `unit.military.planetary_defense_force.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `military_card` | `deploy_or_upgrade_military` / `region_or_owned_same_family_military` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 15; assets industry:6 |
| `unit.military.planetary_defense_force.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `military_card` | `deploy_or_upgrade_military` / `region_or_owned_same_family_military` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 21; assets industry:9 |
| `unit.military.submarine_fleet.rank_1` | `district_supply_rank1_repeat` | `military_card` | `deploy_or_upgrade_military` / `region_or_owned_same_family_military` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 6; assets technology:2 |
| `unit.military.submarine_fleet.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `military_card` | `deploy_or_upgrade_military` / `region_or_owned_same_family_military` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 10; assets technology:4 |
| `unit.military.submarine_fleet.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `military_card` | `deploy_or_upgrade_military` / `region_or_owned_same_family_military` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 15; assets technology:6 |
| `unit.military.submarine_fleet.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `military_card` | `deploy_or_upgrade_military` / `region_or_owned_same_family_military` | `pre_queue_v06_route_rejection` | no | no | no | catalog cash 21; assets technology:9 |
| `unit.monster.blue_edge_knight.rank_1` | `district_supply_rank1_repeat_or_starter_monster_entitlement` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `direct_v06_atomic_starter_transaction_or_fail_closed` | yes | no | yes | catalog cash 6; assets technology:2 |
| `unit.monster.blue_edge_knight.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 10; assets technology:4 |
| `unit.monster.blue_edge_knight.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 15; assets technology:6 |
| `unit.monster.blue_edge_knight.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 21; assets technology:9 |
| `unit.monster.flame_ring_proto_star.rank_1` | `district_supply_rank1_repeat_or_starter_monster_entitlement` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `direct_v06_atomic_starter_transaction_or_fail_closed` | yes | no | yes | catalog cash 6; assets energy:2 |
| `unit.monster.flame_ring_proto_star.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 10; assets energy:4 |
| `unit.monster.flame_ring_proto_star.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 15; assets energy:6 |
| `unit.monster.flame_ring_proto_star.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 21; assets energy:9 |
| `unit.monster.meteor_sentinel.rank_1` | `district_supply_rank1_repeat_or_starter_monster_entitlement` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `direct_v06_atomic_starter_transaction_or_fail_closed` | yes | no | yes | catalog cash 6; assets energy:2 |
| `unit.monster.meteor_sentinel.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 10; assets energy:4 |
| `unit.monster.meteor_sentinel.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 15; assets energy:6 |
| `unit.monster.meteor_sentinel.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 21; assets energy:9 |
| `unit.monster.mirror_hunter.rank_1` | `district_supply_rank1_repeat_or_starter_monster_entitlement` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `direct_v06_atomic_starter_transaction_or_fail_closed` | yes | no | yes | catalog cash 6; assets technology:2 |
| `unit.monster.mirror_hunter.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 10; assets technology:4 |
| `unit.monster.mirror_hunter.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 15; assets technology:6 |
| `unit.monster.mirror_hunter.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 21; assets technology:9 |
| `unit.monster.oasis_repairer.rank_1` | `district_supply_rank1_repeat_or_starter_monster_entitlement` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `direct_v06_atomic_starter_transaction_or_fail_closed` | yes | no | yes | catalog cash 6; assets life:2 |
| `unit.monster.oasis_repairer.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 10; assets life:4 |
| `unit.monster.oasis_repairer.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 15; assets life:6 |
| `unit.monster.oasis_repairer.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 21; assets life:9 |
| `unit.monster.prism_blade_colossus.rank_1` | `district_supply_rank1_repeat_or_starter_monster_entitlement` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `direct_v06_atomic_starter_transaction_or_fail_closed` | yes | no | yes | catalog cash 6; assets commerce:2 |
| `unit.monster.prism_blade_colossus.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 10; assets commerce:4 |
| `unit.monster.prism_blade_colossus.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 15; assets commerce:6 |
| `unit.monster.prism_blade_colossus.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 21; assets commerce:9 |
| `unit.monster.sand_armor_rover.rank_1` | `district_supply_rank1_repeat_or_starter_monster_entitlement` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `direct_v06_atomic_starter_transaction_or_fail_closed` | yes | no | yes | catalog cash 6; assets industry:2 |
| `unit.monster.sand_armor_rover.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 10; assets industry:4 |
| `unit.monster.sand_armor_rover.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 15; assets industry:6 |
| `unit.monster.sand_armor_rover.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 21; assets industry:9 |
| `unit.monster.spore_tide_emperor.rank_1` | `district_supply_rank1_repeat_or_starter_monster_entitlement` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `direct_v06_atomic_starter_transaction_or_fail_closed` | yes | no | yes | catalog cash 6; assets life:2 |
| `unit.monster.spore_tide_emperor.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 10; assets life:4 |
| `unit.monster.spore_tide_emperor.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 15; assets life:6 |
| `unit.monster.spore_tide_emperor.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `monster_card` | `deploy_or_upgrade_monster` / `region_or_existing_same_family_monster` | `pre_queue_monster_non_starter_deploy_rejection` | no | no | no | catalog cash 21; assets life:9 |
| `supply_demand.near_land_supply.rank_1` | `district_supply_rank1_repeat` | `supply_demand` | `global_supply_spawn` / `global_matching_factories` | `shared_card_resolution_queue_after_domain_preflight` | no | yes | no | catalog cash 5; assets industry:2 |
| `supply_demand.near_land_supply.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `supply_demand` | `global_supply_spawn` / `global_matching_factories` | `shared_card_resolution_queue_after_domain_preflight` | no | yes | no | catalog cash 8; assets industry:3 |
| `supply_demand.near_land_supply.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `supply_demand` | `global_supply_spawn` / `global_matching_factories` | `shared_card_resolution_queue_after_domain_preflight` | no | yes | no | catalog cash 12; assets industry:5 |
| `supply_demand.near_land_supply.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `supply_demand` | `global_supply_spawn` / `global_matching_factories` | `shared_card_resolution_queue_after_domain_preflight` | no | yes | no | catalog cash 17; assets industry:8 |
| `supply_demand.remote_sea_order.rank_1` | `district_supply_rank1_repeat` | `supply_demand` | `global_order_budget` / `global_matching_goods` | `shared_card_resolution_queue_after_domain_preflight` | no | yes | no | catalog cash 5; assets shipping:2 |
| `supply_demand.remote_sea_order.rank_2` | `inventory_merge_from_two_same_family_previous_rank_cards` | `supply_demand` | `global_order_budget` / `global_matching_goods` | `shared_card_resolution_queue_after_domain_preflight` | no | yes | no | catalog cash 8; assets shipping:3 |
| `supply_demand.remote_sea_order.rank_3` | `inventory_merge_from_two_same_family_previous_rank_cards` | `supply_demand` | `global_order_budget` / `global_matching_goods` | `shared_card_resolution_queue_after_domain_preflight` | no | yes | no | catalog cash 12; assets shipping:5 |
| `supply_demand.remote_sea_order.rank_4` | `inventory_merge_from_two_same_family_previous_rank_cards` | `supply_demand` | `global_order_budget` / `global_matching_goods` | `shared_card_resolution_queue_after_domain_preflight` | no | yes | no | catalog cash 17; assets shipping:8 |

## Bound actions

The production bound-action identity set is empty. The selected rank-I starter monster can complete through the current V0.6 atomic monster owner, but the tested production Dock still projects `bound_actions=[]`. The military card is acquired through the typed rack path, then fails with `v06_card_effect_route_unavailable`; it remains in hand and creates no command.

If an authoritative legacy `monster_bound_action` or `military_command` Dictionary existed, it would fall through non-V0.6 `_submit_legacy()` and be Queue-capable. That latent code path is not a legal depth-1 action, has no concrete semantic ID, and must not be fabricated. The JSON records both latent classes with `card_semantic_id=null` and `depth1_reachable=false`.

## Why facility is first

The 48 obtainable facility identities are derived from 12 active rank-I families. They have exact region targets, traverse the typed Action Spine, and use one direct atomic V0.6 transaction for build, upgrade, or repair. Moving this family behind the authoritative Queue creates a real save boundary without loosening military rules, inventing a shared-effect target, generating a fake bound action, or changing map/seed.

`recommended_disposition=migrate_first_to_authoritative_card_resolution_queue` applies only to factory and market facility records. Other categories remain outside this audit agent's implementation authority.

## Evidence

- Direct sources: `docs/playtest/alpha_0_1/content_manifest.json:21` and `scripts/runtime/alpha01_runtime_content_selection.gd:6-7,98-122`.
- Repeating rank-I bags: `scripts/runtime/region_supply_runtime_controller.gd:593-645` and `scripts/runtime/game_runtime_coordinator.gd:6108-6139`.
- Rank derivation: `scripts/cards/v06/card_flow_transaction_service_v06.gd:1159-1231`.
- One-shot commodity belt: `scripts/runtime/commodity_card_inventory_runtime_controller.gd:278-342`.
- Offer/Intent spine: `scripts/runtime/table_player_action_application_flow_controller.gd:63,86,219,340,659`.
- Direct versus shared dispatch: `scripts/runtime/card_play_submission_runtime_controller.gd:8,60,300,345,799`.
- V0.6 route owner: `scripts/runtime/game_runtime_coordinator.gd:19,2882,2918,3010,3044`.
- Card/asset reservation and lifecycle: `scripts/cards/v06/card_flow_transaction_service_v06.gd:1234,1863,2005` and `scripts/cards/v06/production/card_player_state_production_adapter_v06.gd:282,480`.
- Queue and missing asset authority: `scripts/runtime/card_resolution_queue_runtime_service.gd:118,222,582,747`.
- Queue-zero witness: `reports/handoffs/alpha04c_no_legal_queue_acceptance_scenario.json:24-33,53-62,82-103`.
- Monster/military and bound-action witness: `tests/player_card_dock_real_three_pool_production_test.gd:173-239`.

## Open questions

- The committed qualification artifact proves at least one direct facility action occurred but does not enumerate every simultaneously legal direct GameActionOffer. Therefore the exact live direct count is not asserted; lower bound 1 is the strongest committed evidence.
- The 68 direct-capable identities are static route capabilities, not simultaneously present live offers. Higher facility ranks require repeated rank-I purchase and inventory merges.
- Card semantic readiness marks monster cards projection_only, while the current V0.6 selected rank-I starter route is executable. Higher monster ranks are obtainable but rejected as monster_non_starter_deploy_deferred.
- The existing supply/demand Queue route consumes a nonpersistent card into queue escrow but CardResolutionQueueRuntimeService declares asset_reservation_authority=false. A future bridge must not copy this gap when per-action activation assets are required.
- No non-factory/non-market facility identity is reachable from the active rank-I source families.
- No concrete monster or military bound-action semantic ID is present in the production Dock; localized legacy technique/command generation must not be counted as an active semantic identity.

No full Smoke, Formal FullRun, qualification rerun, or official A -> B -> C chain was executed by this audit.
