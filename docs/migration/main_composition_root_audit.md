# Main composition root audit

Status: `MAIN_COMPOSITION_ROOT_AUDIT_GREEN`

## Production composition

```text
scenes/main.tscn
└── RuntimeServices
    └── RuntimeControllerHost
        └── GameRuntimeCoordinator
            ├── RuntimeLoop
            ├── RuntimePhaseCoordinator
            │   └── RuntimeSimulationStep
            │       └── SimulationMutationAuthority
            ├── RuntimeCommandPipeline
            │   ├── CardResolutionTransitionSink
            │   ├── MilitaryMonsterDamageCommandSink
            │   ├── MonsterMoveCommandSink
            │   └── MonsterActionCommandSink
            └── domain controllers and typed world/presentation ports
```

`main.tscn` remains the application scene composition root for the current
prototype. `GameRuntimeCoordinator` is the sole runtime-domain composition
root; it owns the one RuntimeLoop, one simulation mutation authority, one
command pipeline and one monster controller. `main.gd` does not own the
monster action command sink or its mutation function.

## Audit gates

- RuntimeLoop count: exactly one.
- RuntimeCommandPipeline count: exactly one.
- SimulationMutationAuthority count: exactly one.
- MonsterRuntimeController count: exactly one.
- Monster move/action sinks: one each.
- Pipeline reports four supported command types and both autonomous monster
  sinks ready.
- Coordinator and runtime production scripts do not discover `/root/Main`,
  `current_scene`, or a dynamic Main fallback.
- Main contains no special-action mutation implementation.

## Boundary interpretation

This is an audit gate, not the final physical deletion of `scripts/main.gd`.
The remaining Main responsibilities are tracked by the scene-first migration
ledger and are not silently reintroduced by this audit. The next deletions
must continue to reduce Main's physical lines, methods and callers.

The complete responsibility classification and staged deletion order are in
[`main_responsibility_inventory.md`](main_responsibility_inventory.md).

## Evidence

- `tests/composition_root_audit_test.gd`
- `scenes/tools/MainCompositionRootAuditBench.tscn`
- `tests/main_runtime_composition_test.gd`
- `tests/main_gd_architecture_gate_test.gd`
