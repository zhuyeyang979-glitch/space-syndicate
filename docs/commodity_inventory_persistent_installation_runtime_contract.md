# SS06-06 Commodity Inventory and Persistent Installation Contract

## Scope

SS06-06 connects the approved v0.6 Card Flow transaction API to the real player
hand and to the existing continuous commodity economy. It does not introduce a
second hand, a second commodity-flow engine, or a commodity-belt visibility
owner.

The production ownership chain is:

1. `CardFlowTransactionServiceV06` owns claim, manual-merge, and play
   transaction policy and ordering.
2. `CardPlayerStateProductionAdapterV06` is the only v0.6 Card Flow state port.
   It exposes the real `main.gd` player hand and cash plus
   `PlayerManaRuntimeController` assets, and owns reservations, locks,
   compare-and-swap metadata, and the exact-once state journal. It stores none
   of those balances.
3. The production adapter applies one exact inventory/cash delta to the real
   player record. The retired `CommodityCardInventoryWorldBridge` is not
   composed and no parallel lock or journal exists.
4. `CommodityCardEffectRuntimeBridge` delegates v0.6 commodity effect planning
   to `CommodityCardEffectAdapterV06` and supplies compensation if the card-slot
   commit cannot complete.
5. `CommodityFlowRuntimeController` remains the sole owner of permanent
   installations, fixed-point rates, facility damage scaling, destruction
   removal, flow allocation, rent, Sale Receipts, and installation save data.
6. `RegionInfrastructureRuntimeController` remains the sole facility lifecycle
   owner.
7. `CoreEconomicCardRuntimeAdapterV06` consumes the same
   `CommodityCardInventoryRuntimeController` transaction service. It does not
   create a second Card Flow service.

Card UI, Card Flow policy, catalog authoring, and viewer-scoped belt visibility
belong to the other active workstream. SS06-06 consumes those public APIs and
does not edit or duplicate them.

## Inventory rules

- Commodity claim and play cost no cash and no six-color assets.
- Commodity cards occupy the ordinary five-card hand.
- Under the hand limit, a duplicate commodity is added as a separate card.
- When the hand is already full, exactly one same-family, same-rank match may
  auto-merge. No matching card means the claim fails without consuming the belt
  item. A matching rank-IV card also fails without consuming the item.
- Manual merge consumes two same-family, same-rank cards and creates exactly one
  next-rank card. Rank IV is terminal.
- The production state adapter applies exact deltas for inventory and cash;
  six-color mana reservations remain owned by `PlayerManaRuntimeController`.
- Existing legacy cards are represented as opaque canonical snapshots while a
  transaction is planned, then restored byte-for-byte when their slot did not
  change. They are not silently migrated or re-authored by this service.

## Persistent installation rules

- A commodity may target any active same-industry factory or market, regardless
  of facility ownership.
- The installation owner is the player who played the card. Facility ownership
  does not change.
- Ranks I-IV add 10/20/40/80 units per minute. Installations are additive.
- Facility damage changes effective capacity in the existing flow owner; it
  does not delete an installation.
- Facility destruction deactivates every attached installation exactly once.
- A card is removed from the hand only after the effect owner returns a bound,
  committed receipt. If the subsequent slot commit fails, the effect bridge
  compensates the just-created installation.
- `CardFlowTransactionServiceV06` invokes `EffectTransactionBoundary` as its
  effect handler. Finalization therefore runs inside the transaction lifecycle,
  after the player-state commit, rather than as a controller-side post-return
  patch. A successful installation is stored with `finalized=true` and
  `rollback_open=false`; later rollback attempts fail with
  `installation_rollback_closed` without removing the installation.
- Facility-card play is fail-closed until the infrastructure rollback path can
  prove preflight-before-mutation atomicity. SS06-06 does not patch that owner.

## Atomicity and persistence

- Every operation requires a non-empty transaction ID and expected player/source
  revisions.
- Reservations capture the real world fingerprint. A changed hand, cash value,
  or mana revision rejects the commit before slot mutation.
- Replaying the same transaction and intent returns the saved terminal result;
  reusing a transaction ID for another intent is rejected.
- Real hand slots remain inside the existing player save payload.
- Permanent installations remain inside `CommodityFlowRuntimeController` save
  data. The narrow controller saves belt/market metadata and terminal receipts;
  the production state adapter saves only exact-once journal metadata.
- Global supply/demand batches bind candidate snapshot revision/fingerprint,
  current route/facility lineage, and shared capacity resources. A successful
  card-state finalize closes the flow rollback window even when physical flow
  remains pending for the next economy tick.
- The global path is exercised as
  `CardFlowTransactionServiceV06 -> EffectTransactionBoundary ->
  CoreEconomicCardEffectRouterV06 -> GlobalSupplyDemand adapter/planner ->
  CommodityFlowRuntimeController`. The outer boundary validates and finalizes
  the nested authoritative Flow receipt when the frozen downstream adapter has
  no finalize hook. There is no second transaction service and no finalize call
  after the transaction has returned.

## Privacy

Debug and public snapshots expose counts, revisions, and stable reason codes.
They do not expose private hand contents, installer identity, AI plans, hidden
targets, Nodes, Callables, Objects, or Resources.

## SS06-06 gate

The focused gate covers source API consumption, scene composition, real-world
state-port binding, free claim, full-hand auto-merge, failed-claim atomicity,
manual merge, same-color installation, cross-owner installation, wrong-target
rejection, 10/20/40/80 additive rates, damage persistence, destruction removal,
save round-trip, exact-once replay, install and global-batch rollback-window
closure, pure-data snapshots, and the absence of a second player inventory.
