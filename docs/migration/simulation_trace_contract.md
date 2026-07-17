# Simulation trace contract

## Status

This is a development-only consumer contract layered on the existing deterministic simulation foundation. It is not a replay log, rollback journal, network packet, save format, presentation snapshot, or second world state.

## Stable record

One trace record contains only:

- `simulation_step_index`;
- the ordered, allowlisted command envelope summary;
- one accepted/rejected result per command;
- the ordered phase transition;
- authoritative state fingerprints before and after the step;
- an allowlisted deterministic mutation summary;
- completion and stable stop-reason fields;
- the trace fingerprint produced by `SimulationStateIdentity`.

Dictionary keys are canonicalized before SHA-256 hashing. Array order remains semantic. Unknown command, result, and mutation fields are removed rather than copied into the trace.

## Forbidden content

Trace records reject runtime `Object`, `Node`, `Callable`, and `Resource` instances. They also reject engine-frame timing, UI state, presentation state, scene, viewport, and node-path fields. The trace contract never receives or retains the mutable world. Diagnostic violation details are fingerprinted and discarded.

## Consumption API

`SimulationDeterminismAudit` keeps at most 32 traces and 32 violation records in memory. Its development-facing API exposes:

- the latest recorded simulation identity;
- the current recorded step index;
- the latest or bounded recent deterministic traces;
- stable violation codes and details fingerprints;
- passive counters for development diagnostics.

The audit has no `_process`, save API, presentation target, world mutation API, or random source. `RuntimeSimulationStep` remains the authoritative step boundary and explicitly records a trace only when a development verifier supplies the before/after projections and allowlisted summaries.

## Randomness boundary

All production RNG construction and sampling now passes through `RunRngService`. The region-supply shuffle bag retains its explicit per-region derived state and save-roundtrip behavior, but asks `RunRngService.deterministic_weighted_shuffle()` to perform the draw. Any direct RNG constructor outside `RunRngService` fails the source allowlist, and any uncontrolled world-mutating declaration fails `SimulationRandomnessBoundary`.

## Non-goals

This contract does not provide command playback, rollback, multiplayer synchronization, save migration, fixed-step scheduling, cross-platform floating-point guarantees, or a complete internal world projection. Future systems may consume the pure trace and fingerprint contracts, but must not promote the trace into a second gameplay authority.
