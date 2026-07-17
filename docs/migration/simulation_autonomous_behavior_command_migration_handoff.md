# Simulation autonomous behavior command migration handoff

Status: `SIMULATION_AUTONOMOUS_BEHAVIOR_COMMAND_MIGRATION_GREEN`

## Autonomous authority map

```text
Monster behavior decision
  -> MonsterMoveCommand (pure data)
  -> RuntimeCommandPipeline
  -> MonsterMoveCommandSink
  -> SimulationMutationAuthority
  -> MonsterRuntimeController mutation
  -> SimulationDeterminismAudit before/after fingerprints
```

The behavior layer selects a target and emits intent data. It no longer starts
or advances autonomous linear movement directly. `MonsterMoveCommandSink` is
the only new mutation path and remains a non-owning command consumer.

## Command contract

`monster_move` supports four explicit operations:

- `start`: bind a monster UID to a district target and deterministic speed;
- `advance`: advance the existing linear motion by the supplied world delta;
- `settle`: resolve the legal same-region autonomous movement outcome;
- `clear`: clear movement when the monster is down.

Commands contain only pure data: actor UID, operation, target district,
movement mode, speed, deterministic delta, source, sequence and world-effective
timestamp. Node, Object, Resource and Callable payloads are rejected.

## Coverage update

Covered autonomous mutation:

- ordinary automatic movement target start;
- lure consumption attached to that movement command;
- deterministic per-step linear motion advance;
- arrival position and arrival/path consequences;
- same-region settlement;
- downed-monster movement cleanup.

Still outside command coverage:

- monster special action choice and attack/effect resolution;
- monster duration/revival state changes;
- AI economic and military decisions;
- military movement and non-monster effects;
- weather transitions;
- region infrastructure damage/repair outside covered movement consequences;
- contracts, intel and some victory mutations.

## Determinism and RNG

The migration does not add a random source. Existing target/action randomness
continues to use the already-bound `RunRngService`. The typed command records
the selected deterministic result; the mutation sink does not roll again.

## Verification

- autonomous behavior migration: 11/11;
- foundation: 30/30;
- consumption: 33/33;
- authority migration: 12/12;
- command pipeline: 31/31;
- card frame driver: 104/104;
- card transition sink: 70/70;
- transition fault injection: 61/61;
- runtime phases: 50/50;
- RuntimeLoop: 28/28;
- typed world ports: 80/80;
- Main architecture: 80/80;
- visual snapshot and smoke `--check-only`: pass;
- autonomous Godot CLI Bench: 3/3.

The broad layout test remains red on established retired-fixture assertions and
the full smoke remains bounded/stalled on the existing integration debt. No
legacy Main fallback was restored. The known `RuntimeWorldPorts.lifecycle` and
`market_facts_unavailable` debts remain unchanged.

## Recommended next migration

Move monster special action choice/result into typed autonomous commands. Keep
decision, RNG consumption and mutation as separate responsibilities; do not
combine the entire monster controller into a replacement monolith.
