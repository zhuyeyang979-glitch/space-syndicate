# Agent B — RegionSupply Purchase Cutover

## Scope completed

- The active regional rack is now configured only from the stable v0.6 runtime-card catalog.
- The legacy v0.4 card list passed by `main.gd` is ignored by the production RegionSupply configuration.
- All active rack slots use stable ASCII card IDs and exclude commodity-belt cards, retired cards, non-acquirable cards, and ranks above I.
- `main.gd::_buy_card_for_player_from_district` now submits one source-bound request through:
  `GameRuntimeCoordinator.purchase_region_supply_card`
  → `CommodityCardInventoryRuntimeController.purchase_region_supply_card`
  → `CardFlowTransactionServiceV06.purchase_region_supply_card`.
- The temporary combined bridge `commit_district_purchase_with_region_supply` and the main-owned `_district_purchase_settlement_request` were physically deleted.
- The separate first-table facility shelf was removed from the active rack presentation. Facility cards are ordinary stable v0.6 RegionSupply listings.
- The global legacy card-definition facade remains schema-pure; RegionSupply explicitly reads `v06_card_definition`.
- `main.gd` changed from 17,761 total / 15,570 nonblank / 1,028 functions to
  17,634 total / 15,449 nonblank / 1,024 functions:
  net -127 total lines, -121 nonblank lines, and -4 functions.

## Ownership and privacy

- RegionSupply remains the only rack, slot-refill, shuffle-bag, RNG, and supply-revision owner.
- CommodityCardInventory/CardFlow remains the only cash, inventory, purchase-count, journal, and purchase-transaction owner.
- Main retains only input adaptation, player feedback, and presentation refresh.
- Public purchase receipts still omit buyer identity, exact card identity, private quote binding, hand contents, and private cash.

## Focused Godot 4.7 evidence

- `human_region_supply_purchase_cutover_v06_test.gd`: PASS 22/22
- `card_flow_region_supply_purchase_v06_test.gd`: PASS 51/51
- `card_flow_region_supply_production_wiring_v06_test.gd`: PASS 22/22
- `main_runtime_composition_test.gd`: PASS
- `action_result_v1_district_purchase_adopter_test.gd`: PASS 39/39
- Earlier in the same frozen diff, `region_supply_full_randomization_v06_test.gd`: PASS
- Godot MCP `get_script_errors`: PASS, 286 scripts checked, 0 errors
- Godot MCP `CardFlowRegionSupplyProductionWiringV06Bench.tscn`: PASS 22/22
- `git diff --check`: PASS

The focused tests used an isolated APPDATA/LOCALAPPDATA profile and did not access the default player save.
The MCP play session and editor were stopped; the owned PID exited and port 8765 was verified closed.

## Remaining integration risk

- The older `plan_district_purchase_settlement` and `commit_district_purchase_settlement` Coordinator methods still exist for unrelated legacy callers, but the human regional purchase path has zero references to them.
- The old first-table facility-market Coordinator API remains available to its isolated legacy tests; it is no longer a Main/UI purchase source. It should be retired separately only after all non-rack callers are migrated.
- Full commercial acceptance belongs to the integration owner after the concurrent public-surface work is frozen.
