# Runtime coordination phase decomposition handoff

`STATUS=RUNTIME_COORDINATION_PHASE_DECOMPOSITION_GREEN`

- Branch: `codex/scene-first-remove-main-gd`
- Starting SHA: `2c4ea4a1f68a37659e01a9e8be91eaf6aeafcba0`
- Working-tree baseline: existing dirty tree at `TYPED_WORLD_PORTS_GREEN`
- Commit created: no
- Push performed: no

## Outcome

Runtime coordination is now explicitly phase-based. `RuntimeLoop` remains the
only engine frame owner, but it no longer knows any individual gameplay system
or typed-port family. It invokes one `RuntimePhaseCoordinator`; that owner
preserves the authoritative order through six small scene-owned phase
coordinators. All mutations still occur behind the existing seven typed ports
and their established domain owners.

No gameplay rule, formula, timer duration, AI policy, combat behavior,
presentation projection, save schema or hidden-information boundary changed.

## Architecture

Before:

```text
RuntimeLoop (_process + complete concrete system order)
  -> RuntimeLifecyclePort
  -> RuntimeCardPort
  -> RuntimeEconomyPort
  -> RuntimeActorPort
  -> RuntimeMonsterPort
  -> RuntimePresentationPort
  -> RuntimeVictoryPort
      -> existing domain owners
```

After:

```text
RuntimeLoop (_process + frame receipt only)
  -> RuntimePhaseCoordinator (deterministic phase order)
      -> RuntimeLifecyclePhaseCoordinator
      -> RuntimeCommandPhaseCoordinator
      -> RuntimeSimulationPhaseCoordinator
      -> RuntimeResolutionPhaseCoordinator
      -> RuntimeStateCommitCoordinator
      -> RuntimePresentationScheduleCoordinator
          -> narrow RuntimeWorldPorts
              -> existing domain owners
```

GameRuntimeCoordinator remains the production composition root only. It binds
the existing owner graph to `RuntimeWorldPorts`, binds those ports to the phase
graph, then binds the phase graph to RuntimeLoop. It does not execute the phase
order or inspect phase receipts.

## Phase ownership map

| Phase owner | Operations coordinated | Typed boundaries |
|---|---|---|
| Lifecycle | terminal gate, forced-decision sync, global block, ordinary pause, one clock advance, post-flow/post-victory gates | RuntimeLifecyclePort |
| Command | card gate, card-resolution frame, contracts, cooldowns | RuntimeLifecyclePort, RuntimeCardPort |
| Simulation | GDP/futures/weather/boons, wager, AI, monster motion, military, monster action/duration/revival and visual cues | RuntimeEconomyPort, RuntimeActorPort, RuntimeMonsterPort, RuntimePresentationPort |
| Resolution | continuous commodity flow and continuation gate | RuntimeEconomyPort |
| State commit | product market then victory | RuntimeEconomyPort, RuntimeVictoryPort |
| Presentation schedule | global-block visual/table cadence and active frame-end table cadence | RuntimePresentationPort |

The global-block path remains:

```text
lifecycle begin
-> blocked wager (real delta)
-> blocked visual cues (real delta)
-> blocked table presentation (real delta)
```

The active path remains:

```text
lifecycle begin/clock
-> command
-> simulation
-> resolution
-> lifecycle post-flow gate
-> state commit
-> lifecycle post-victory gate
-> presentation frame end
```

## Ownership changes

Moved out of RuntimeLoop:

- concrete typed-port selection;
- card/weather/AI/monster/military/economy/victory/presentation order;
- flow and terminal gate placement;
- blocked-path system selection.

Retained in RuntimeLoop:

- the sole `_process(real_delta)` callback;
- one phase-coordinator invocation;
- frame index and immutable receipt copy;
- `frame_advanced` signal.

Retained in domain systems:

- all state;
- all gameplay mutations and formulas;
- all AI, combat, economy, card and victory rules;
- all presentation snapshot and target ownership.

## Metrics

### GameRuntimeCoordinator

| Metric | Before | After |
|---|---:|---:|
| Physical lines | 6,008 | 6,005 |
| Nonblank lines | 4,886 | 4,885 |
| Methods | 560 | 559 |
| Direct node lookups | 103 | 104 |
| Dynamic-call markers | 955 | 955 |
| Phase-order switches | 0 | 0 |

The one additional node lookup is the explicit
`RuntimePhaseCoordinator.tscn` composition. The unused
`runtime_loop_can_advance` facade was physically deleted. No generic
dispatcher or dynamic-call surface was added.

### RuntimeLoop

| Metric | Before | After |
|---|---:|---:|
| Physical lines | 140 | 57 |
| Nonblank lines | 121 | 41 |
| Methods | 7 | 7 |
| Direct typed-port families known | 7 | 0 |
| Phase dependencies | 0 | 1 |
| Gameplay/world traversal | 0 | 0 |

### Phase coordinators

| Script | Physical lines | Methods |
|---|---:|---:|
| RuntimePhaseCoordinator | 69 | 5 |
| Lifecycle | 61 | 6 |
| Command | 30 | 4 |
| Simulation | 62 | 5 |
| Resolution | 25 | 4 |
| State commit | 26 | 4 |
| Presentation schedule | 30 | 5 |

- Explicit child phase coordinators: 6
- Root plus child scripts: 303 physical lines, 33 methods
- Phase scripts with `_process`: 0
- Phase scripts with Main/root/current-scene lookup: 0
- Phase scripts with direct world traversal: 0
- Phase scripts with gameplay formula fields: 0

## Files

Added:

- `res://scenes/runtime/RuntimePhaseCoordinator.tscn`
- `res://scripts/runtime/runtime_phase_frame_context.gd`
- `res://scripts/runtime/runtime_phase_coordinator.gd`
- six `res://scripts/runtime/runtime_*_phase_coordinator.gd` scripts
- `res://tests/runtime_coordination_phase_decomposition_test.gd`
- `res://scenes/tools/RuntimeCoordinationPhaseDecompositionBench.tscn`
- `res://scripts/tools/runtime_coordination_phase_decomposition_bench.gd`
- preflight audit Markdown/JSON

Changed:

- `RuntimeLoop` to depend only on `RuntimePhaseCoordinator`
- `GameRuntimeCoordinator.tscn` and its explicit wiring
- RuntimeLoop, typed-port, Main architecture, card and presentation gates
- migration ledger, plan and development log

Deleted:

- the unused `GameRuntimeCoordinator.runtime_loop_can_advance` facade

No Main method, field, constant, preload or compatibility route was added.

## Validation

Green focused evidence:

- runtime phase ownership/boundary/determinism: PASS 50/50
- RuntimeLoop complete order and path regression: PASS 28/28
- typed world ports: PASS 80/80
- phase production Bench: PASS 7/7
- RuntimeLoop production Bench: PASS 8/8
- typed-port production Bench: PASS 8/8
- Main architecture gate: PASS 72 checks
- Main runtime composition: PASS
- card transition exact-once: PASS 70/70
- table Source/Target: PASS 20/20
- presentation ViewModel parity: PASS 106/106
- presentation query ports: PASS 65/65
- presentation scheduler trace: PASS 8/8
- Victory public projection privacy: PASS 47/47
- UI text smoke: PASS
- visual snapshot: PASS
- smoke `--check-only`: PASS
- production `main.tscn` headless load: PASS

The Source/Target production Bench applies 48/48 non-screenshot assertions in
headless mode; its sole failed assertion is the known headless texture capture
limitation, not a presentation or phase regression.

Godot 4.7 MCP launched the real `res://scenes/main.tscn` and stopped cleanly.
No runtime exception or missing-access error was produced. MCP repeated only
pre-existing source warnings in RunRngService, WorldSessionState,
RouteNetworkRuntimeController and WeatherDefinitionCatalog.

The bounded full smoke reached the same historical debt as the baseline:

- legacy AI military characterization failures;
- old test calls to retired `Main._capture_run_state`;
- historical role/intel fixtures;
- missing `_auto_monster_color` routing in MonsterRuntimeWorldBridge.

The new stack frames show those existing domain failures passing through the
Simulation phase, RuntimePhaseCoordinator and RuntimeLoop exactly once. No new
phase-owned failure, duplicate tick or duplicate mutation path appeared. Full
smoke is intentionally not reported as green.

## Remaining historical debt

- The parent `typed_world_ports` domain remains pending for 21 historical
  WorldBridge files and setup-time dynamic calls.
- GameRuntimeCoordinator still contains broad historical setup, public façade
  and save/load responsibilities outside the frame path.
- Broad smoke fixtures must migrate away from deleted Main test hooks.
- Monster WorldBridge capability gaps remain domain-owner work.
- Main final deletion, action routing and save/restore cutovers remain separate
  atomic tasks.

These debts were not hidden inside the phase graph and no universal manager,
event bus, autoload or compatibility facade was introduced.

## Final declaration

All atomic completion conditions are met:

1. RuntimeLoop is the sole frame owner.
2. Runtime coordination is explicitly phase-based.
3. GameRuntimeCoordinator owns no phase order and decreased in size/methods.
4. Typed ports remain narrow and unchanged in authority.
5. Domain systems retain all gameplay ownership.
6. Full ordered traces and deterministic replay are unchanged.
7. Main remains free of runtime ownership.

`RUNTIME_COORDINATION_PHASE_DECOMPOSITION_GREEN`
