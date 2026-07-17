# Typed world ports boundary hardening handoff

`STATUS=TYPED_WORLD_PORTS_GREEN`

- Branch: `codex/scene-first-remove-main-gd`
- Starting SHA: `2c4ea4a1f68a37659e01a9e8be91eaf6aeafcba0`
- Working-tree policy: existing dirty tree preserved
- Commit created: no
- Push performed: no

## Result

The authoritative frame path no longer depends on an implicit, broad world
adapter. `RuntimeLoop` receives one explicitly composed `RuntimeWorldPorts`
node and calls seven narrow typed ports. Existing controllers remain the only
owners of session, card, economy, actor, monster, presentation and victory
state. The ports own no gameplay state and contain no gameplay formulas.

The old `AuthoritativeRuntimeFramePort` script and scene were physically
removed. No Main callback, service locator, autoload, root-scene lookup,
generic world manager or compatibility fallback was added.

## Dependency diagrams

Before:

```text
RuntimeLoop
  -> AuthoritativeRuntimeFramePort (28-operation broad adapter)
      -> get_parent().get_parent()
          -> GameRuntimeCoordinator
              -> domain owners
```

After:

```text
GameRuntimeCoordinator (composition only)
  -> RuntimeWorldPorts
      -> RuntimeLifecyclePort    -> existing lifecycle owners
      -> RuntimeCardPort         -> existing card/contract/cooldown owners
      -> RuntimeEconomyPort      -> existing GDP/market/flow/mana owners
      -> RuntimeActorPort        -> existing weather/AI/military owners
      -> RuntimeMonsterPort      -> existing monster owner
      -> RuntimePresentationPort -> existing visual/scheduler/refresh owners
      -> RuntimeVictoryPort      -> existing victory/session/query owners
  -> RuntimeLoop --typed bind_ports()--> RuntimeWorldPorts
```

## Port contracts and metrics

Only frame-time intent operations are counted below; `bind_dependencies`,
`is_ready` and `debug_snapshot` are lifecycle/diagnostic helpers.

| Port | Intent operations | Responsibilities |
|---|---:|---|
| RuntimeLifecyclePort | 7 | session gates, forced decisions, global/card gates, single clock advance and game-time projection |
| RuntimeCardPort | 3 | card-resolution frame, contract tick, cooldown tick |
| RuntimeEconomyPort | 6 | GDP derivatives, futures, boons, market cycle, commodity settlement and flow continuation gate |
| RuntimeActorPort | 3 | weather, AI and military ticks |
| RuntimeMonsterPort | 5 | wager, motion, action, duration and revival ticks |
| RuntimePresentationPort | 2 | visual cues and typed table presentation cadence/application |
| RuntimeVictoryPort | 1 | victory advance, outcome and session-finish orchestration |

Totals:

- Ports added: 7
- Intent operations: 27
- RuntimeWorldPorts composition methods: 2 diagnostic/composition methods
- RuntimeLoop: 140 physical lines, 7 methods
- RuntimeLoop world traversal calls: 0
- RuntimeLoop Main/coordinator dependencies: 0
- RuntimeLoop dynamic calls: 0
- Duplicate mutation paths reported by authority audit: 0

## Ownership and behavior

- RuntimeLoop remains the unique gameplay tick owner and only determines the
  deterministic step order and early-return gates.
- World-effective clock advancement remains exactly once per active frame.
- Card, contract and cooldown mutations remain in their established owners.
- Commodity flow keeps the existing settlement, bankruptcy checkpoint,
  per-player color snapshot and mana-recovery order.
- Weather remains before AI; AI remains before monster motion; military remains
  before monster action.
- Commodity flow remains before product-market cycle and preserves its early
  return. Victory remains after market and before frame-end presentation.
- Presentation Source/Target ownership and viewer privacy are unchanged.

## Source changes

Added production composition:

- `res://scenes/runtime/RuntimeWorldPorts.tscn`
- `res://scripts/runtime/runtime_world_ports.gd`
- seven `res://scripts/runtime/runtime_*_port.gd` implementations

Changed production composition:

- `res://scenes/runtime/GameRuntimeCoordinator.tscn`
- `res://scripts/runtime/game_runtime_coordinator.gd`
- `res://scenes/runtime/RuntimeLoop.tscn`
- `res://scripts/runtime/runtime_loop.gd`

Removed production boundary:

- `res://scenes/runtime/AuthoritativeRuntimeFramePort.tscn`
- `res://scripts/runtime/authoritative_runtime_frame_port.gd`

Tests and tools changed or added:

- `res://tests/typed_world_ports_boundary_test.gd`
- `res://scenes/tools/TypedWorldPortsBoundaryBench.tscn`
- `res://scripts/tools/typed_world_ports_boundary_bench.gd`
- `res://tests/runtime_loop_cutover_test.gd`
- `res://tests/main_gd_architecture_gate_test.gd`
- `res://tests/main_runtime_composition_test.gd`
- presentation/card cutover fixtures updated to inject typed fake ports
- layout smoke received one missing local source declaration so it can run and
  report its pre-existing assertions instead of failing at parse time

## Validation

Focused green evidence:

- typed world ports boundary test: PASS 78/78
- RuntimeLoop cutover test: PASS 24/24
- typed ports production Bench, headless: PASS 7/7
- Main architecture gate: PASS 71 checks
- Main runtime composition: PASS
- card-resolution transition sink: PASS 70/70
- table presentation Source/Target: PASS 20/20
- table presentation parity: PASS 106/106
- table presentation query ports: PASS 65/65
- table presentation scheduler trace: PASS 8/8
- WorldSessionState cutover: PASS 48 checks
- Victory public projection privacy: PASS 47/47
- UI text smoke: PASS
- visual snapshot: PASS
- smoke `--check-only`: PASS
- production `main.tscn` headless load: PASS, no runtime error
- Godot 4.7 MCP production Bench run: zero runtime errors; clean stop with
  `finalErrors=[]`

The broad layout smoke now parses and runs. It still reports established,
unrelated repository debt (retired campaign ViewModels, legacy Main assertions,
older scheduler/owner fixtures); no architecture fallback was restored.

The bounded full smoke reached the same established debt rather than a new
typed-port regression:

- legacy AI military characterization failures;
- retired `Main._capture_run_state` test calls;
- historical role/intel fixtures;
- missing `_auto_monster_color` capability in the old monster WorldBridge.

The run was stopped after identifying those ownership boundaries. Full smoke
is intentionally not reported as green.

## Main and RuntimeLoop budgets

Current Main budget remains green and unchanged by this hardening:

- physical lines: 13,159
- nonblank lines: 11,414
- methods: 819
- top-level variables: 66
- constants: 110
- preloads: 15
- external Main occurrences: 1,591 across 102 files

No Main method, field, constant, preload, callback or compatibility route was
added. The task changes the RuntimeLoop boundary rather than hiding remaining
Main callers.

## Remaining debt

The parent ledger domain `typed_world_ports` remains `pending`. This hardening
only completes the active authoritative-frame boundary. It does not claim the
following unrelated work:

- 21 historical WorldBridge files still used outside the RuntimeLoop frame
  interface;
- setup/configuration-time dynamic calls in GameRuntimeCoordinator;
- retired Main calls in broad legacy tests;
- monster WorldBridge capability gaps such as `_auto_monster_color`;
- remaining AI, save/restore and presentation-action-routing cutovers.

These must be migrated domain by domain. They must not be absorbed into a
larger RuntimeWorldPorts interface or a universal service locator.

## Final declaration

All completion conditions for this atomic boundary hardening are met:
RuntimeLoop remains thin; runtime communication is explicit; domain ownership,
deterministic ordering, presentation privacy and exact-once mutation paths are
preserved; Main remains free of runtime ownership.

`TYPED_WORLD_PORTS_GREEN`
