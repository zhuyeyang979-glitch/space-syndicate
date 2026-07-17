# Monster action command migration handoff

Status: `SIMULATION_MONSTER_ACTION_COMMAND_MIGRATION_GREEN`

## Authority map

```text
Monster action decision (weighted choice + target selection)
  -> pure `monster_action` command
  -> RuntimeCommandPipeline
  -> MonsterActionCommandSink
  -> SimulationMutationAuthority
  -> MonsterRuntimeController.apply_autonomous_action_command
```

The decision function consumes the existing `RunRngService` through the
controller's existing RNG boundary. The sink never chooses an action and does
not consume randomness. It only authorizes, applies, audits and deduplicates a
typed command.

## Command fields

`actor_uid`, `action_index`, pure-data `action`, `target_district`, optional
target slot, weight summary, source, world timestamp and monotonic sequence.
The envelope fingerprint is stable for equivalent dictionaries and rejects
runtime objects, Nodes, Callables and malformed actor/action identifiers.

## Exactly-once and failure behavior

Commands are rejected outside an active `RuntimeSimulationStep`, after the
step closes, or when their command id has already been applied. A successful
command produces one `SimulationMutationAuthority` audit record with a
monster UID target key and action metadata. No second state store is created.

## Preserved behavior

Action tables, weights, target scoring, phase order, damage values, wager
opening and presentation calls are unchanged. The command carries the already
selected action, so the sink never re-rolls or re-targets the action.

## Remaining bypasses

Some follow-up effects inside the authorized action result still call existing
monster domain helpers (wager opening, knockback and district effects). They
execute inside the sink-authorized mutation window and are the next candidate
for narrower command sinks if future deterministic coverage requires them.
