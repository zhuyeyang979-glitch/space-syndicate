# Standings application-flow handoff

Status: `MAIN_STANDINGS_APPLICATION_FLOW_EXTRACTION_GREEN`

The standings quick-navigation and post-match actions now use a dedicated
application signal and a scene-owned controller/query pair. Main no longer
builds standings facts, refreshes routes on page open, mounts the scoreboard or
authorizes private data from table selection.

Focused evidence:

- `standings_application_flow_cutover_test.gd`: 17/17 PASS
- `main_application_flow_handler_extraction_test.gd`: 27/27 PASS
- `main_dependency_direction_migration_test.gd`: 13/13 PASS
- `standings_public_snapshot_service_test.gd`: PASS
- `rules_quick_reference_snapshot_v06_test.gd`: PASS
- `main_runtime_composition_test.gd`: PASS
- `smoke_test.gd --check-only`: PASS
- Godot 4.7 MCP `StandingsPublicSnapshotCutoverBench.tscn`: 20/20 PASS,
  real scene-owned open 28ms; no new standings error (existing project-wide
  script warnings remain in the MCP final warning list)
- Main budget gate: PASS; 13,081/11,350/812 -> 12,961/11,242/806

The existing unrelated `RuntimeWorldPorts.lifecycle` and
`market_facts_unavailable` fixture debts were not modified. Economy, intel,
compendium, setup and save application flows remain outside this cutover. The
broad layout smoke was also run and reached the standings checks without a
standings failure, but remains red on 19 pre-existing campaign/runtime/legacy
fixture assertions; none was weakened or restored through Main.
