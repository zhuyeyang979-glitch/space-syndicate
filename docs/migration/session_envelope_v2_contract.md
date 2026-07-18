# Session Envelope v2 Contract

## Shape

The `session` owner state has exactly four root fields:

```text
schema_version = 2
game_session_runtime
world_session_state
card_history_private_annotations
```

The adapter rejects extra root fields, missing children, objects, nodes,
callables, non-finite numbers, and malformed child schemas.

`world_session_state` uses schema version 1 and is a deterministic codec DTO.
Runtime integer-key city maps are encoded as sorted records and restored to the
existing integer-key runtime shape. This avoids non-string dictionary keys in
the v3 codec without changing gameplay lookups.

## World Session Fields

The DTO covers players, districts, game time, map width and height, and world
geometry revision. Player role identity and city-guess state remain inside the
player records owned by `WorldSessionState`.

Normal city-guess confidence is 1 through 3 and reason values come from the
existing runtime allowlist. The existing authorized public-reveal sentinel is
accepted only with confidence 100 and a bounded nonempty reason. Save restore
does not evaluate guesses, award cash, spend charges, append public log rows,
or invoke final settlement.

## Apply and Rollback

Preflight completes for all children before apply. The adapter then captures
runtime checkpoints and applies:

1. `WorldSessionState`
2. `CardHistoryPrivateAnnotationService`
3. `GameSessionRuntimeController`

The lifecycle owner is last so a session cannot return to running before world
and viewer-private state are ready. On failure, touched owners are restored in
reverse order and rollback failures are returned explicitly.

Registry preflight also cross-validates the normalized private annotation
checkpoint against the normalized `card_resolution_history` section from the
same envelope. This dependency check does not read live history and completes
before any of the 19 section owners are applied. In global restore order,
`card_resolution_execution` is section 14, `card_resolution_history` is section
15, and the composite `session` owner is section 19; public history is therefore
available before private annotation apply.

World-session restore retains the established signal order:

1. `players_replaced`
2. `districts_replaced`
3. `game_time_changed`
4. `world_geometry_changed`
5. `session_restored`

`GameSessionRuntimeController.complete_load(OK)` preserves a lifecycle already
restored by the registry; it only converts a still-loading state to running.
