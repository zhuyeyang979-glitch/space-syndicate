# Stable Runtime Invariants and Sceneization Plan

This plan separates infrastructure that survives future rule changes from policies that are expected to change. The immediate playable build may use a narrow content set, but it must use these stable seams.

## Stable invariants — build these now

### 1. One authoritative owner per state domain

Hand, cash/assets, mana/commitment, commodities, facilities/cities, monsters, military, card queue/effects, market, clock, and victory each have one authoritative runtime owner. Conditional orders are ordinary card/economy effects, not a separate contract-response owner. UI, AI, campaigns, and tests consume snapshots and commands; they do not maintain parallel truth.

### 2. One command lifecycle

Every player or AI action follows the same shape:

`intent -> validate -> reserve/prepare -> commit -> public event -> finalize`

Failure follows:

`reject before mutation` or `rollback to an exact preimage`.

This contract remains stable even if costs, targets, timing, or effects change.

### 3. Scene-based production composition

The real game is assembled as Godot scenes and nodes. `main.gd` may coordinate presentation during migration, but it must not own duplicate business state or formulas.

Recommended production tree:

```text
RuntimeGameScreen (Control)
├── RuntimeOwners (Node)
│   ├── Session / Seats / Privacy
│   ├── RealtimeClock
│   ├── PlayerState
│   ├── CardInventory
│   ├── CardResolutionQueue
│   ├── RegionInfrastructure
│   ├── CommodityFlow / ProductMarket / Routes
│   ├── MonsterRuntime / MilitaryRuntime
│   └── VictoryControl
├── RuntimeServices (Node)
│   ├── IntentRouter
│   ├── SaveHandshake
│   ├── PublicEventJournal
│   └── AICommandBridge
├── TableUI (Control)
│   ├── TopPublicTrack
│   ├── LeftContextRail
│   ├── PlanetMap
│   ├── RightActionRail
│   └── PlayerHandDock
└── OverlayLayer (CanvasLayer)
    ├── SingleDecisionWindow
    ├── TooltipLayer
    ├── CardInspectLayer
    └── MatchRecap
```

### 4. Rules and balance are resources, not scene logic

Scenes expose ports; resources decide values. Card requirements, GDP thresholds, purchase discounts, auction windows, victory targets, monster uniqueness, movement multipliers, and effect strength belong in versioned resources/data plus policy services.

### 5. Realtime uses one clock domain

Income, movement, forecasts, temporary effects, auctions, and countdowns consume one authoritative monotonic game clock. Pauses and special decision windows change clock domains through a clock service, never by scattered timers.

### 6. Public/private snapshots are explicit

Every owner can produce only the views it is authorized to expose:

- public table snapshot;
- current human private snapshot;
- authorized AI private snapshot;
- developer/test audit snapshot.

Player UI never receives rival truth or AI reasoning and therefore cannot leak it accidentally.

### 7. UI consumes view models and emits intents

Buttons and panels do not calculate costs, ownership, legality, damage, or income. They render a view model and emit a typed intent. This allows menus, card faces, tutorials, and layouts to be redesigned without rewriting rules.

### 8. AI uses the same legal-action ports as humans

AI may have private scoring and training metadata, but its actual actions pass through the same intent validation and transaction owners as human actions. New rules therefore require one legality implementation, not separate human and AI versions.

### 9. Events and recap are first-class

Every committed action emits a public-safe event with stable IDs and timestamps. The card track, combat text, coach, replay, audit, and final recap all consume the same journal instead of reconstructing history from UI state.

### 10. Save/load is owner-versioned and coordinated

Each owner validates its snapshot before mutation. A save handshake records compatible owner versions and rejects partial or contradictory state. Tests use isolated save roots and never touch the player's default `user://` data.

### 11. Map movement is meter-based behind a coordinate service

Regions and spherical projection may change visually, but unit position, movement, knockback, path distance, and focus navigation share a meter-based world-coordinate service. UI projection is a view of that state, not the state itself.

### 12. Acceptance fixtures are production-facing

Critical flows have deterministic fixtures that call the real production ports. A reference Bench proves a component; a vertical-slice acceptance scene proves the actual game can be played.

## Volatile policies — isolate, do not hard-code yet

These are expected to change and must remain replaceable data/policy modules:

- cash victory versus GDP-share victory and the exact countdown;
- 30-second card windows, bidding redistribution, tips, and queue priority;
- monster uniqueness, simultaneous monster caps, and ownership limits;
- exact card-play requirements and whether rank-I cards waive them;
- regional supply composition, fixed regional monster cards, and purchase discounts;
- automatic conditional-order settlement and its public result receipts;
- wager base percentage, odds, and payout formula;
- weather frequency and forecast duration;
- commodity catalogue, elasticity, and GDP coefficients;
- card/monster/role balance values and content quantity.

Each volatile policy needs a versioned resource, a pure policy function, and focused tests. It should not require changing scene structure or UI hierarchy.

## Safe extraction and deletion order

For each `main.gd` responsibility:

1. Name the authoritative replacement owner/service/scene.
2. Move state and mutation behind its public command/snapshot API.
3. Connect it in the production scene.
4. Run a focused test and a production-facing vertical-slice check.
5. Search scenes, resources, scripts, signals, and callable strings for consumers.
6. Remove the legacy call path and rerun the gate.
7. Delete the old code only after the replacement is the sole production path.

Do not perform a big-bang rewrite of `main.gd`. Retire one verified responsibility slice at a time until the file becomes a thin screen coordinator and can finally be removed.

## Immediate priority for the playable sample

Sceneize and prove only the critical path first:

1. Session/setup and seat privacy.
2. Starter-monster first summon.
3. One city/facility and realtime income.
4. Regional card inspection/purchase and one legal play.
5. AI command bridge for the same four actions.
6. Victory countdown, settlement, and recap.
7. A single non-blocking table UI path and isolated save.

Depth expansion is welcome when it plugs into these seams. Systems likely to be redesigned should remain data-driven or fail-closed until the basic match is green.
