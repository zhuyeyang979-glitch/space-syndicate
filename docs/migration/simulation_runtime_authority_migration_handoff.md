# Simulation runtime authority migration handoff

Status: `SIMULATION_RUNTIME_AUTHORITY_MIGRATION_GREEN` (focused slice)

## Delivered

- Added `SimulationStateProjectionContract` for pure-data authoritative
  sections and explicit missing-domain reporting.
- Added `SimulationMutationAuthority` under the existing
  `RuntimeSimulationStep`; it owns no world, clock or save state.
- Extended `SimulationDeterminismAudit` with bounded mutation records containing
  before/after state fingerprints.
- Added the typed `military_monster_damage` command envelope and pipeline sink.
- Migrated the military attack-monster path to the command sink. The sink is
  UID-based, synchronous, duplicate-safe and fail-closed outside an active
  simulation step.
- Kept automatic monster actions, military movement, weather, AI and other
  domain mutations on their existing phase owners; they are listed as future
  command-coverage work rather than being duplicated here.

## Evidence

- `simulation_runtime_authority_migration_test.gd`: 12/12
- `SimulationRuntimeAuthorityMigrationBench.tscn`: 7/7
- determinism foundation: 30/30
- determinism consumption: 33/33
- command pipeline boundary: 31/31
- card frame driver: 104/104
- card transition sink: 70/70
- card transition fault injection: 61/61
- runtime phase decomposition: 50/50
- runtime loop: 28/28

The Godot editor scan reports the pre-existing `RuntimeWorldPorts.lifecycle`
access error; this task does not change that unrelated boundary. The known
`market_facts_unavailable` production fixture remains outside this migration.

## Remaining bypass risks

1. Automatic monster and military ticks still mutate through their domain
   owners and need typed automatic-command adapters.
2. Region infrastructure damage/repair and weather transitions need explicit
   command contracts.
3. AI intents need a command-producing adapter; policy must remain separate from
   mutation authority.
4. The legacy CityDevelopment bridge still contains historical RNG state access
   and is not changed here; future work must route all active randomness through
   `RunRngService`.
5. Projection completeness is not yet global; missing domains remain explicit in
   the coverage matrix.

## Safe future boundaries

Replay, networking and save migration remain intentionally blocked until the
coverage matrix is complete and all authoritative domains emit deterministic
commands. The current projection and audit can support those future systems,
but they must not be treated as those systems themselves.
