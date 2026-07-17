# Authoritative Runtime Loop cutover preflight

Status before production edits: **GO**

- Branch: `codex/scene-first-remove-main-gd`
- Start SHA: `2c4ea4a1f68a37659e01a9e8be91eaf6aeafcba0`
- Unique gameplay frame entry: `res://scripts/main.gd::_process`
- Production RuntimeLoop instances: `0`
- Gameplay `_physics_process` entries: `0`
- `process_frame` gameplay connections: `0`
- Current world-time multipliers: `0` and `1` only; the scene-owned `GameSessionRuntimeController` is the running/paused authority.

## Entry-point inventory

The only production method that advances the authoritative runtime domains is
`Main._process`. The `_process` methods in the planet solar camera, map view,
and weather strip are presentation animation owners and do not advance gameplay.
The one-shot `process_frame` connection in Main restores menu scroll focus and
does not advance gameplay. Tool/bench `await process_frame` calls are test
synchronization only. No production timer, physics callback, autoload, root
lookup, or deferred callback advances the authoritative domain sequence.

## Frozen frame order

1. session-finished gate
2. forced-decision synchronization
3. global-time block gate
4. blocked wager tick (real delta)
5. blocked visual-cue ageing (real delta)
6. blocked table presentation (real delta)
7. ordinary session-pause gate
8. authoritative world-effective clock advance and `WorldSessionState.game_time` projection
9. card-resolution gate and frame
10. contract tick
11. card cooldowns
12. GDP derivative timers
13. futures timers
14. weather tick
15. economic-boon ageing
16. monster-wager tick
17. AI tick
18. monster motion
19. military tick
20. monster actions
21. monster durations
22. visual-cue ageing
23. monster revivals
24. commodity flow and early-return gate
25. post-flow session-finished gate
26. product-market cycle
27. victory advance and typed presentation receipt
28. post-victory session-finished gate
29. frame-end table presentation (real delta)

## Ownership classification

Every step is available through an existing scene owner or a narrow
`GameRuntimeCoordinator` API. The cutover may add explicit, behavior-preserving
coordinator methods for the four operations that Main currently reaches through
generic calls: derivative timers, futures timers, boon ageing, and the composed
commodity-flow checkpoint. These methods do not add a world bridge or new
domain authority.

The RuntimeLoop will receive a typed `AuthoritativeRuntimeFramePort`. The port
is only an adapter to the already-composed coordinator. RuntimeLoop will not
know Main, UI targets, presentation receipt kinds, world data, or domain rules.

## Go/No-Go

- ROOT_ONLY_BLOCKER: none
- second clock required: no
- second presentation scheduler required: no
- Main callback required: no
- gameplay-rule migration required: no
- decision: **GO**
