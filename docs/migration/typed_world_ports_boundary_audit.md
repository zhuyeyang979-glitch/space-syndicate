# Typed world ports boundary audit

Status before production edits: **HARDENING REQUIRED**

- Branch: `codex/scene-first-remove-main-gd`
- Start SHA: `2c4ea4a1f68a37659e01a9e8be91eaf6aeafcba0`
- Source of truth: the dirty working tree containing the completed RuntimeLoop
  cutover
- Gameplay tick owners: 1 (`RuntimeLoop`)
- Main gameplay process callbacks: 0

## Current coupling

`RuntimeLoop` currently depends on one 28-operation
`AuthoritativeRuntimeFramePort`. That adapter discovers the concrete
`GameRuntimeCoordinator` through two parent traversals and then forwards every
operation to it. The loop itself does not traverse the world, but the adapter
is a broad interface and its implicit parent binding is not a durable typed
boundary.

The coordinator is the production composition root and still contains 95
explicit child-node lookups and a large historical dynamic-call surface. Most
of that surface is outside the frame path and belongs to later per-domain
cutovers. The active RuntimeLoop path uses only the operations classified
below. This atomic hardening will not rewrite the remaining 21 historical
WorldBridge files or their domain rules.

## Active frame access classification

| Order | Intent | Access | Current owner | Target port |
|---:|---|---|---|---|
| 1 | readiness / finished / paused | lifecycle query | session/coordinator | lifecycle |
| 2 | forced decision synchronization | lifecycle mutation | candidate sources | lifecycle |
| 3 | global/card block gates | lifecycle query | scheduler | lifecycle |
| 4 | world clock + game-time projection | lifecycle mutation | clock + WorldSessionState | lifecycle |
| 5 | card-resolution frame | mutation | CardResolutionFrameDriver | card |
| 6 | contract tick | mutation | ContractRuntimeController | card |
| 7 | cooldown tick | mutation | CardCooldownRuntimeController | card |
| 8 | GDP derivative timers | mutation | CityGdpDerivativeRuntimeController | economy |
| 9 | futures and boon timers | mutation | ProductMarketRuntimeController | economy |
| 10 | commodity settlement/checkpoint/recovery | mutation | CommodityFlow + bankruptcy + mana owners | economy |
| 11 | market cycle | mutation | ProductMarketRuntimeController | economy |
| 12 | weather / AI / military | mutation | respective controllers | actors |
| 13 | monster wager/motion/action/lifecycle | mutation | MonsterRuntimeController | monster |
| 14 | visual cue ageing | presentation mutation | VisualCueRuntimeOwner | presentation |
| 15 | table refresh cadence/apply | presentation mutation | scheduler + refresh port | presentation |
| 16 | victory advance/outcome | lifecycle mutation | victory/session/AI/query owners | victory |

No active-frame step requires Main, a service locator, an autoload, a world
singleton, `current_scene`, `/root/Main`, or a mutable world object passed into
RuntimeLoop.

## Hardening decision

Replace the broad parent-discovering adapter with one scene-owned
`RuntimeWorldPorts` composition containing seven narrow typed ports:

1. lifecycle
2. card
3. economy
4. actors
5. monster
6. presentation
7. victory

The coordinator will bind existing typed domain owners once during explicit
scene composition. RuntimeLoop receives the port composition through a typed
binding API. Frame-time code will not traverse the scene tree or dynamically
discover an owner. Existing coordinator convenience APIs will delegate to the
same ports where migrated, so tests and non-frame callers cannot create a
second implementation path.

## Out of scope debt

- Historical WorldBridge-to-Main methods not reached by RuntimeLoop.
- Setup/configuration-time dynamic calls in the composition root.
- Card, AI, monster, military, weather, economy and victory rule redesign.
- Save schema and presentation action routing.

These remain ledger debt. They must not be hidden behind a universal port or
claimed complete by this hardening.
