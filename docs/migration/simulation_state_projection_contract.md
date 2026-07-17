# Simulation state projection contract

`SimulationStateProjectionContract` defines the pure-data boundary used by
`SimulationStateIdentity` and the development mutation audit. It is not a save
format, replay format, rollback snapshot, or network packet.

## Required shape

```text
{
  schema_version: 1,
  projection_kind: "authoritative_simulation",
  scope: "full|owner|test",
  authoritative_entities: { ... },
  resources: { ... },
  phase_state: { ... },
  pending_commands: [ ... ],
  deterministic_timers: { ... },
  coverage: {
    covered_domains: [ ... ],
    missing_domains: [ ... ]
  }
}
```

All values must be stable pure data: dictionaries, arrays, strings, numbers,
booleans and null. Dictionary keys are canonicalized before hashing. Node,
Object, Callable, Resource, scene, viewport, camera, animation and engine-time
metadata are rejected.

## Inclusion rules

Include only state that can affect a future simulation result:

- authoritative entity identity and state;
- player resources that gameplay reads;
- active simulation phase and phase revision;
- accepted pending commands in deterministic order;
- deterministic timers expressed in world-effective units;
- explicit owner revisions needed to distinguish stale commands.

Exclude UI hover/focus, camera transforms, animation progress, engine frame
numbers, real-frame delta, debug panels and presentation caches. Private values
may be represented by a stable fingerprint when a public projection is being
built; they must not be copied into public snapshots.

## Coverage policy

Owners should provide a projection section rather than exposing mutable owner
objects. A projection is only complete when its `coverage.missing_domains` is
empty. The current migration deliberately reports missing domains for monster
automatic behavior, military non-attack behavior, region infrastructure,
weather, AI intents, contracts/intel and some victory mutations. This prevents
an apparently stable hash from being mistaken for complete authority coverage.

## Mutation audit relationship

`SimulationMutationAuthority` accepts a typed command only during an active
`RuntimeSimulationStep`. A sink captures a pure before projection, applies the
owner mutation, captures a pure after projection, and records both fingerprints
with the command id/type and a small allowlisted summary in
`SimulationDeterminismAudit`. The audit is development-only and does not alter
gameplay, save data or clock behavior.
