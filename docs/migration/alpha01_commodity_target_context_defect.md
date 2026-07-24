# Alpha 0.1 Commodity Target Context Defect

## Failure

The formal human hand-play path froze the selected region but rejected every
`install_commodity_rate` card with `v06_card_target_context_not_composed`.
`GameRuntimeCoordinator` routed facility, organization, automatic supply/demand,
and monster targets, but omitted the active commodity effect kind.

## Boundary

`CoreEconomicCardRuntimeAdapterV06` now resolves the frozen region to exactly
one active factory or market matching the commodity card industry. Zero matches
and multiple matches fail closed. The result is detached pure data and carries
the stable facility ID, region ID, industry, production/demand direction, and
capture time.

`GameRuntimeCoordinator` delegates initial target capture to that adapter and
reconstructs the same binding from the finalized CommodityFlow installation for
terminal replay. No price, production, flow, GDP, save, UI, or ruleset contract
changes are included.
