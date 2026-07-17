# Runtime coordination phase decomposition audit

Status before production edits: **DECOMPOSITION REQUIRED**

- Branch: `codex/scene-first-remove-main-gd`
- Start SHA: `2c4ea4a1f68a37659e01a9e8be91eaf6aeafcba0`
- Source of truth: the dirty working tree at `TYPED_WORLD_PORTS_GREEN`
- Authoritative frame owner count: 1 (`RuntimeLoop`)
- RuntimeLoop physical/nonblank lines: 140 / 121
- RuntimeLoop methods: 7
- GameRuntimeCoordinator physical/nonblank lines: 6,008 / 4,886
- GameRuntimeCoordinator methods: 560
- GameRuntimeCoordinator direct node lookups: 103
- GameRuntimeCoordinator dynamic-call markers: 955

## Current responsibility inventory

| Responsibility | Current location | Classification | This cutover |
|---|---|---|---|
| engine `_process` callback and frame receipt | RuntimeLoop | frame orchestration | retain in RuntimeLoop |
| complete concrete system order and early returns | RuntimeLoop | phase orchestration | move to RuntimePhaseCoordinator and explicit phase children |
| typed domain operation forwarding | seven RuntimeWorldPorts children | boundary, not authority | retain unchanged |
| port-to-domain-owner binding | GameRuntimeCoordinator | composition | retain as explicit composition only |
| runtime owner scene composition | GameRuntimeCoordinator | composition | retain |
| gameplay formulas, AI policy and combat behavior | existing domain controllers | gameplay authority | unchanged |
| world/session/card/economy/monster state | existing domain controllers | world ownership | unchanged |
| table cadence, snapshots and UI application | presentation services | presentation ownership | unchanged |
| historical public facades, setup and save APIs | GameRuntimeCoordinator | migration debt | out of scope |

The coordinator does not currently contain the authoritative frame-order
switch; that switch lives in RuntimeLoop. The architectural risk is therefore
twofold: RuntimeLoop knows 27 concrete typed-port operations, while
GameRuntimeCoordinator remains the only place that can compose the port graph.
This cutover removes concrete system knowledge from RuntimeLoop without moving
rules or state into GameRuntimeCoordinator.

## Frozen authoritative order

The existing full trace is authoritative:

1. session-finished gate
2. forced-decision synchronization
3. global-time block gate
4. blocked path: wager, visual cues, table presentation using real delta
5. ordinary pause gate
6. world clock advance and WorldSessionState projection
7. card-resolution gate and frame advance
8. contract tick
9. card cooldowns
10. GDP derivative timers
11. product futures timers
12. weather
13. economic boons
14. monster wager
15. AI
16. monster motion
17. military
18. monster actions
19. monster durations
20. visual cues
21. monster revivals
22. continuous commodity flow and early-return gate
23. post-flow session-finished gate
24. product-market cycle
25. victory advance
26. post-victory session-finished gate
27. frame-end table presentation using real delta

No order, delta domain, pause behavior or early-return condition may change.

## Target phase ownership

| Phase coordinator | Typed ports | Operations |
|---|---|---|
| LifecycleCoordinator | lifecycle | start gates, forced synchronization, pause decision, one world-clock advance, post-flow/post-victory terminal gates |
| CommandPhaseCoordinator | lifecycle + card | card gate, card frame, contract and cooldown |
| SimulationPhaseCoordinator | economy + actors + monster + presentation | pre-flow simulation sequence and blocked real-time wager |
| ResolutionPhaseCoordinator | economy | continuous commodity flow and its continuation decision |
| StateCommitCoordinator | lifecycle + economy + victory | post-flow gate, market, victory, post-victory gate |
| PresentationScheduleCoordinator | presentation | blocked visual/table cadence and active frame-end table cadence |

`RuntimePhaseCoordinator` owns only the phase order, frame trace and
ephemeral frame receipt. `RuntimeLoop` owns only the engine callback, frame
counter and invocation of one phase coordinator. Domain systems remain the
only mutation owners.

## Go decision

**GO.** All phase operations already have narrow typed ports. No Main callback,
new world query, gameplay formula, second clock or second process loop is
required. The change can be atomic: add one explicitly composed phase graph,
bind it to the existing port graph, switch RuntimeLoop to one typed phase call,
and update negative/trace gates.

## Out-of-scope debt

- Historical GameRuntimeCoordinator facades, setup and save/load APIs.
- The 21 historical WorldBridge files recorded by the prior cutover.
- Domain rule redesign, action routing and Main final deletion.
- Existing broad smoke failures in legacy AI, retired Main fixtures and the
  monster WorldBridge.
