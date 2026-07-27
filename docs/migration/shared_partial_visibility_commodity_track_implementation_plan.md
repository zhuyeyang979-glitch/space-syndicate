# Shared Partial-Visibility Commodity Track Implementation Plan

```text
GAME_SEMANTIC_CONSTITUTION_VERSION=V0.7
CURRENT_RUNTIME_RULE_VERSION=v0.6
TARGET_RULE_VERSION=V0.7
CONSTITUTION_AMENDMENT_RECORDED=true
FULL_V0_7_CUTOVER=false
```

## Current checkpoint

```text
CURRENT_PHASE=A_CONTRACT_PLUS_B_REFERENCE
PRODUCTION_WIRING=false
SINGLE_PRODUCTION_AUTHORITY=true
FULL_RULE_CUTOVER=false
```

The executable reference now proves the settled three-layer semantics without
connecting a second writer. Production remains v0.6 until the unresolved rule
decisions and all Phase B/C gates are complete.

## Target ownership

```text
RuntimeSimulationStep
├─ future SharedCommodityTrackRuntimeController
│  ├─ cycle / stance / distribution
│  ├─ hidden lead / macro-round cursor
│  └─ global sequence / movement / stock / generation
├─ existing CommodityFlowRuntimeController
│  └─ typed six-color GDP aggregate query only
├─ existing CardFlow + CardPlayerStateProductionAdapterV06
│  └─ separate commodity partition / linear merge
├─ existing ProductMarketRuntimeController
│  └─ price and futures (unchanged ownership)
└─ existing VictoryControlRuntimeController
   └─ original end conditions + attested macro-round boundary
```

There is no new Manager, second RuntimeLoop, second RNG, second Victory owner,
or Main callback.

## Phase B — decisions and pure simulation

Before a production owner exists, approve explicit policy IDs for:

- track topology, movement, stock, refill and unclaimed lifecycle;
- simultaneous claim tie-break;
- missing stance/bootstrap choice;
- eliminated/disconnected/restored roster;
- merge identity, rate mapping and full-capacity reject/discard/replace behavior;
- irreversible special-outcome end gate;
- GDP smoothing, floor, ceiling, net cap and player scaling.

Manual player-controlled merge and independent `normal 5 + commodity 5`
capacity are constitutionally frozen and are no longer open decisions.

Then promote the current reference reducer into a versioned immutable rule spec
and pure deterministic simulation. Prove identical traces and restore identity
for 3-8 seats without changing production Save.

## Phase C — passive AI and player semantics

Add production-shaped, read-only typed ports only after Phase B:

- `CommodityMarketObservation` for both human-equivalent AI visibility and AI
  policy;
- public distribution/history and actor-private track/stance/inventory
  projections;
- a passive UI Bench showing local track, six ratios, countdown, stance lock,
  private lead notice, split capacities, linear merge and pending end;
- human and AI emit the same `MarketStanceIntent`.

No Phase C object may mutate gameplay, calculate a second distribution, save a
projection, or read a full core object outside the projection owner.

## Phase D — one atomic production cutover

In one reviewed program stage:

1. add one scene-owned runtime controller under `RuntimeSimulationStep`;
2. route claim, stance and merge through typed commands and
   `SimulationMutationAuthority`;
3. migrate the existing inventory ownership chain to separate partitions;
4. add the typed GDP aggregate and Victory boundary attestation;
5. migrate Save with exact restore and no dual write;
6. switch AI and player consumers together;
7. delete old `_belt/configure_belt/claim_belt_card`, direct Sushi service
   mutation, same-rank merge/auto-merge, broad empty-allowlist visibility, old
   UI interaction and stale tests;
8. prove one owner, exact-once, privacy, RNG, determinism and performance.

`ProductMarketRuntimeController` and `CommodityFlowRuntimeController` are not
old track authorities and remain in their price/futures and real-flow roles.

## Next minimum task

```text
NEXT_TASK=SHARED_COMMODITY_TRACK_RULE_DECISION_FREEZE
```

That task should approve only the unresolved policy IDs. It should not begin
production wiring, Save migration, or UI replacement.
