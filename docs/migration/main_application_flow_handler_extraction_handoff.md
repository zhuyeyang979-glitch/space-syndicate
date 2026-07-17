# Main application-flow handler extraction handoff

Status: `MAIN_APPLICATION_FLOW_HANDLER_EXTRACTION_GREEN`

## Goal

Move one real application-flow action out of Main without changing gameplay
order, clock formulas, values, save format, or deterministic state identity.

## Migrated slice

The `rules` action now follows:

```text
MenuOverlay / MenuRootLobby
  → ApplicationFlowPort.submit_action("rules")
  → ApplicationFlowController.open_rules()
  → MenuOverlay + RulesQuickReferenceBoard
```

The previous `Main._open_rules_menu`, `_populate_rules_summary_cards`, and
`_add_rules_quick_reference_board` functions were physically removed. The two
rules-only Main preloads were also removed.

## Boundary responsibilities

`ApplicationFlowPort` validates application action ids and rejects empty menu
requests. `ApplicationFlowController` owns only the rules page composition and
the existing session pause request. It has no RuntimeCommandPipeline,
SimulationMutationAuthority, RunRngService, gameplay state, save state, or
Main fallback.

## Metrics

| Metric | Before | After |
| --- | ---: | ---: |
| physical Main lines | 13,116 | 13,081 |
| nonblank Main lines | 11,379 | 11,350 |
| Main methods | 815 | 812 |
| top-level fields | 66 | 66 |
| constants | 110 | 108 |
| top-level preloads | 15 | 13 |
| static caller files | 102 | 102 |

Static caller files remain dominated by audit tests and Benches; production
direct dependency is measured separately. The direct rules-to-Main action
route is zero. Remaining Main action routes are listed as pending in the
inventory and are not hidden behind this cutover.

## Evidence

- `tests/main_application_flow_handler_extraction_test.gd`: PASS 22/22
- `tests/main_dependency_direction_migration_test.gd`: PASS 13/13
- Main Architecture Gate: PASS 80 checks
- Main Runtime Composition: PASS
- Main Reduction: PASS 12/12
- Determinism Foundation: PASS 30/30
- Determinism Consumption: PASS 33/33
- Runtime Authority: PASS 12/12
- Autonomous Behavior: PASS 11/11
- Monster Action: PASS 13/13
- RuntimeLoop: PASS 28/28
- Runtime Coordination: PASS 50/50
- `smoke_test.gd --check-only`: PASS
- Godot 4.7 MCP production scene: loaded without errors
- `git diff --check`: PASS

## Remaining Main responsibilities

Main remains the bootstrap and transitional application router for standings,
economy, intel, compendium, setup, save/load and input wiring. None of these
were copied into the new handler. The next safe cutovers are standings/economy
read-only query ports, then setup and save entry boundaries.

## Finalization readiness

`MAIN_COMPOSITION_ROOT_FINALIZATION_GREEN` is not yet claimed. At least five
application-flow routes and the setup/save lifecycle still have real Main
consumers. The next task should migrate one of those routes with its own parity
gate, keeping the handler narrow or splitting by actual responsibility.
