# AI Session Public Query Port

## Boundary

`AiSessionPublicQueryPort` is a read-only, scene-owned adapter over the existing
`GameSessionRuntimeController`, `WorldSessionState`, world-effective clock,
ProductMarket, card-resolution phase, and card-resolution queue owners. It owns
no state and adds no save section.

The exact detached snapshot contains session identity and revision, lifecycle
state, world-effective and legacy world time, public market-cycle revision,
player and district counts, map dimensions, challenge depth, active-resolution
presence, and public card phase. It never returns `players`, `districts`, cash,
hands, RNG, Nodes, Objects, Callables, or mutable Resources.

## Cutover

`AiRuntimeController.session_finished` and `AiRuntimeController.game_time` now
read this typed snapshot. Their former `_call_world("_runtime_session_finished")`
and `_world_value("game_time")` routes are physically absent. The generic bridge
still serves other unmigrated domains, so the parent P0 gate remains active.

## Evidence

- Focused production-composition test: 16/16.
- Actor-state regression: 95/95.
- Query mutation count: 0.
- Query RNG delta: 0.
- Whole-player and whole-district fields returned: 0.
- Main references: 0.
- New save sections: 0.
- `FULL_RUN_RESUME_CLAIM=false`.
