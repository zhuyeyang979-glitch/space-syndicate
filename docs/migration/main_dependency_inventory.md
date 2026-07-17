# Main dependency direction inventory

Status: `MAIN_DEPENDENCY_DIRECTION_MIGRATION_GREEN`

This inventory distinguishes application-flow dependencies from runtime
authority dependencies. The latter must never point at `scripts/main.gd`.

## Current callers

| Caller class | Current evidence | Classification | Direction after this change |
| --- | --- | --- | --- |
| `scenes/main.tscn` | owns the application root and declares the Main script | retain | scene bootstrap → Main composition root |
| `RuntimeServices/FinalSettlementRuntimeComposition` | previously connected its menu/action signals directly to Main | migrated | settlement composition → `ApplicationFlowPort` → application flow handler |
| `scripts/ai/ai_policy_resource_registry.gd` | reads Main source only for a development parity report | test/dev only | remains outside gameplay runtime; no runtime owner dependency |
| tests and characterization Benches | inspect Main source or instantiate the formal scene | test/dev only | remain evidence consumers, never gameplay callers |
| Godot MCP runtime | tooling integration | tooling only | does not participate in simulation authority |

The repository-wide static caller count is intentionally not treated as a
runtime dependency count: most of the 102 files are source-audit tests and
Benches. The production dependency removed in this cutover is the direct
FinalSettlement → Main signal edge.

## Application-flow boundary

`ApplicationFlowPort` is a narrow scene-owned port. It accepts only:

- allow-listed navigation actions (`setup`, `standings`, `economy`, `intel`,
  `rules`, `compendium`);
- a non-empty public menu title/summary and continue flag.

It owns no world state, simulation clock, command pipeline, RNG, snapshot,
cash, hand, card, or save data. Invalid actions fail closed. Main may subscribe
to this application boundary as the bootstrap/router while runtime compositions
no longer need a direct Main target.

## Forbidden directions

The following remain architectural violations:

- domain controller → Main for mutation or runtime queries;
- UI → Main to alter authoritative state directly;
- Main → private runtime state through dynamic `call/get/set` compatibility;
- a second gameplay loop, command pipeline, RNG, or simulation owner;
- replacing this port with a universal Manager or service locator.

## Migration queue

1. Move menu page routing behind the same application-flow boundary.
2. Move new-game setup actions to a typed session-start flow port.
3. Move save/load entry to a typed save-flow port while preserving save schema.
4. Delete the corresponding Main action wrappers only after each owner has a
   focused parity gate.

These are separate atomic cutovers; this change does not claim them complete.
