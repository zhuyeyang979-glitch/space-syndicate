# Simulation determinism preflight

## Decision

The current runtime can accept a minimal simulation-step boundary without changing product timing. `RuntimeLoop` remains the sole Godot frame owner. The new boundary moves only the ordered active-world sequence behind one explicit call; it does not introduce a fixed timestep, accumulator, replay log, networking, or a second world clock.

## Advancement inventory

| Order / source | Classification | Authority and determinism boundary |
| --- | --- | --- |
| Session-finished, forced-decision and pause gates | lifecycle-only | `RuntimeLifecyclePhaseCoordinator` through `RuntimeLifecyclePort` |
| World-effective clock and `WorldSessionState.game_time` projection | deterministic simulation mutation | `WorldEffectiveClockRuntimeController` remains the sole integer-microsecond clock owner |
| Card resolution, contracts and cooldowns | deterministic simulation mutation | `RuntimeCommandPhaseCoordinator` through `RuntimeCardPort`; migrated card transitions enter `RuntimeCommandPipeline` |
| Weather, AI, monster and military advancement | deterministic simulation mutation | Existing typed actor/monster ports and domain owners; ordering remains frozen |
| Commodity flow, product market and victory | deterministic simulation mutation / commit | Existing economy and victory ports; flow and terminal early-return gates remain frozen |
| Visual cues and table refresh cadence | presentation-only | Existing presentation port and presentation schedule; excluded from simulation state identity |
| Save/load restoration | external lifecycle input | Existing save owners; not redesigned by this foundation |
| Engine frame delta | external scheduling input | `RuntimeLoop` supplies it; the simulation boundary receives an explicit world delta and does not own `_process` |

## Randomness inventory

| Source | Classification | Evidence / treatment |
| --- | --- | --- |
| `RunRngService` | seeded simulation randomness | One owned `RandomNumberGenerator`, serializable state and deterministic draw count. AI, monster, weather and product-market bridges receive this service. |
| Region supply shuffle bag | seeded simulation randomness | The owner restores authoritative per-region bag RNG state and delegates the pure weighted draw to `RunRngService`, which returns the next state. Save-roundtrip tests cover the stream; it does not use frame time or UI activity. |
| New-run `RunRngService.randomize()` | external initialization | Chooses the run's starting RNG state before authoritative evolution. Once the initial state is fixed, subsequent draws are reproducible. It is not called by `RuntimeSimulationStep`. |
| Presentation / UI | visual randomness | No direct visual random source was found in the production presentation/UI scan. Any future visual source must declare no world-mutation capability. |
| Direct hidden simulation RNG | uncontrolled randomness | Not approved. `SimulationRandomnessBoundary` reports any declaration combining `uncontrolled` with world mutation as a violation. |

## Go / no-go

GO. The simulation step can invoke the existing command, simulation, resolution, lifecycle-post-flow, state-commit and lifecycle-post-victory coordinators without learning gameplay formulas or presentation targets. The only production behavior retained is currently one active simulation step per active engine frame; the API no longer makes that relationship structural.

## Known debt

- The new fingerprint mechanism identifies an explicitly supplied internal simulation projection. It is not yet a full-world snapshot aggregator and is deliberately not a public presentation source.
- Existing domain owners still use variable world delta. This foundation does not promise cross-platform bit-identical floating-point physics or introduce a fixed-step scheduler.
- Only the migrated `card_resolution_transition` command family currently enters `RuntimeCommandPipeline`. Other direct intent families remain separately documented command-boundary debt.
