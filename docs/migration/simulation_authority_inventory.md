# Simulation authority inventory (v0.6)

This inventory records the current state-change boundaries after the
`SIMULATION_AUTHORITY_COVERAGE_MIGRATION` slice. It is an engineering audit,
not a claim that every historical world bridge has already been migrated.

## Authority map

```text
RuntimeLoop
  -> RuntimePhaseCoordinator
    -> RuntimeSimulationStep
      -> SimulationMutationAuthority (development audit boundary)
      -> RuntimeCommandPipeline
        -> CardResolutionTransitionSink
        -> MilitaryMonsterDamageCommandSink
    -> existing typed world ports / domain controllers
```

`RuntimeLoop` remains the only engine `_process` owner. `RuntimeSimulationStep`
opens and closes one deterministic mutation window per active simulation step.
Gameplay owners still own their state and formulas; the mutation authority
does not become a second world store.

## Coverage matrix

| Domain / entry | Class | Current owner or path | Status | Remaining risk |
|---|---|---|---|---|
| Card transition batches | A | `RuntimeCommandPipeline` -> `CardResolutionTransitionSink` | Command-covered, exact-once | None in this slice |
| Military attack on monster | A | `MilitaryRuntimeController` -> typed `military_monster_damage` command -> `MilitaryMonsterDamageCommandSink` -> `MonsterRuntimeController` | Command-covered in active simulation step | Other military effects remain direct |
| Monster autonomous movement start/advance/settle/clear | A | monster behavior decision -> typed `monster_move` command -> `MonsterMoveCommandSink` -> `MonsterRuntimeController` | Command-covered in active simulation step, audited by UID | Special monster actions remain direct |
| Region card purchase | A | Region supply / CardFlow transaction owners | Existing typed transaction | Historical fixture coverage remains separate |
| Commodity sale / installation | A | CommodityFlow and owner transaction boundaries | Existing typed transaction | No new migration here |
| Monster automatic special actions | B | Monster owner tick through phase ports | Movement is covered; attacks/effects are not | Migrate action choice/result without changing phase order |
| Military movement and non-attack effects | B | Military runtime controller | Not command-covered | Define command types without changing phase order |
| Region damage/repair and facilities | B | RegionInfrastructure owner | Not command-covered | Requires typed damage/repair command contract |
| Weather transitions | B | Weather runtime owner | Not command-covered | Randomness must remain RunRngService-only |
| AI decisions | B | AI runtime owner emits existing intents | Partially covered | Decision-to-command adapter still required |
| Contracts, intel and commitment effects | B | Existing card/domain owners | Not fully covered | Preserve private/public boundaries |
| Victory qualification/audit | B | VictoryControlRuntimeController | Domain-owned | Public receipt path is already separate; mutation command coverage pending |
| UI, camera, animation, presentation refresh | C | Scene-owned presentation ports/schedulers | Not simulation state | Must not enter simulation identity |
| Engine delta / frame metadata | C | RuntimeLoop | Not simulation state | Excluded from identity by contract |

Class A means the change already enters a typed command or existing exact-once
transaction. Class B means it is a legitimate simulation mutation but still
needs a future command adapter. Class C is runtime metadata or presentation and
must remain outside the simulation state projection.

## Forbidden shortcuts

No production code may add a second mutation store, mutate through UI, use a
Main callback, or consume randomness outside `RunRngService`. The existing
`RuntimeWorldPorts.lifecycle` and `market_facts_unavailable` fixture debts are
intentionally not part of this migration.
