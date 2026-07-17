# Authoritative RuntimeLoop cutover handoff

Status: `CUTOVER_RUNTIME_LOOP_GREEN`

- Branch: `codex/scene-first-remove-main-gd`
- Start SHA: `2c4ea4a1f68a37659e01a9e8be91eaf6aeafcba0`
- Commit: intentionally uncommitted by task contract
- Push: not performed

## Production ownership

- Owner scene: `res://scenes/runtime/RuntimeLoop.tscn`
- Owner script: `res://scripts/runtime/runtime_loop.gd`
- Typed adapter: `res://scripts/runtime/authoritative_runtime_frame_port.gd`
- Production path:
  `main.tscn -> GameRuntimeCoordinator.tscn -> RuntimeLoop.tscn -> AuthoritativeRuntimeFramePort`
- Runtime authority path count: 1
- Duplicate tick/signal/snapshot/save-writer/mutation counts: 0/0/0/0/0

RuntimeLoop owns only the engine frame callback, real/world delta boundary,
deterministic ordering, stop gates, frame receipts and diagnostic frame count.
It owns no world records, rules, formulas, AI policy, card effects, UI target,
save schema, world bridge or presentation cadence.

## Frozen order

1. session-finished gate
2. forced-decision synchronization
3. global-time block gate
4. blocked wager, visual and table-presentation ticks using real delta
5. ordinary session-pause gate
6. authoritative clock advance and game-time projection
7. card-resolution gate and frame
8. contract tick
9. card cooldowns
10. GDP derivative timers
11. futures timers
12. weather
13. economic boons
14. monster wager
15. AI
16. monster motion
17. military
18. monster actions
19. monster durations
20. visual cues
21. monster revivals
22. commodity flow and early-return gate
23. post-flow finished gate
24. product market
25. victory
26. post-victory finished gate
27. frame-end table presentation using real delta

The active path advances `WorldEffectiveClockRuntimeController` exactly once.
Global wager blocking advances only wager, visual and presentation real-time
work. Ordinary pause and finished sessions do not advance gameplay.

## Main retirement evidence

Deleted from Main:

- `_process`
- `_update_victory_control`
- `_advance_continuous_commodity_flow`

No `_physics_process`, forwarding `_process`, Main callback, current-scene
lookup or `/root/Main` fallback was added. The port uses explicit coordinator
APIs only.

Budget at task start:

- physical lines: 13,243
- nonblank lines: 11,490
- methods: 822
- variables/constants/preloads: 66/110/15
- external Main occurrences: 1,597

Budget after cutover:

- physical lines: 13,159
- nonblank lines: 11,414
- methods: 819
- variables/constants/preloads: 66/110/15
- external Main occurrences: 1,591
- external Main caller files: 102 (gate limit 102)

RuntimeLoop itself is 146 physical lines, 125 nonblank lines, 8 methods and 3
fields. The typed frame port is 140 physical lines, 83 nonblank lines, 28
methods and one field.

## Validation

Green focused evidence:

- `runtime_loop_cutover_test.gd`: 22/22
- `RuntimeLoopCutoverBench.tscn`: 6/6
- card-resolution transition sink: 70/70
- Main architecture gate: 63 checks
- Main runtime composition: pass
- table presentation source/target: 20/20
- table presentation parity: 106/106
- presentation query ports: 65/65
- presentation scheduler trace: 8/8
- WorldSessionState: 48 checks
- world-session geometry owner: 11/11
- commodity ambient/backlog/warehouse/save/privacy: 22/27/17/19/93
- victory public projection privacy: 47 checks
- UI text smoke: pass
- visual snapshot: pass
- smoke `--check-only`: pass
- Main budget gate: pass
- Godot 4.7 production main run: zero runtime errors; existing warning baseline
  remains

Full smoke was run with an isolated save directory. It reaches the established
legacy suite debts rather than a RuntimeLoop-owned assertion: retired
`_capture_run_state` fixtures, AI military-policy expectations and the missing
typed-world-port route for `_auto_monster_color`. The long-running legacy suite
was stopped after capturing these first failures. No compatibility method was
restored and full smoke is not claimed green.

The legacy `layout_scene_smoke_test.gd` still has its pre-existing undefined
`presentation_query_source` parse debt. Product-market, weather and market-save
characterization suites also retain previously recorded old-owner assertions.

## Integration risks and next boundary

- Twenty-four old tool Benches stop only `Main.set_process(false)`; a configured
  fixture must now stop its child RuntimeLoop explicitly before manually
  advancing domains, or it may double tick during awaited frames.
- RuntimeLoop diagnostic `frame_index` includes unavailable and finished
  frames, though those frames perform no gameplay mutation.
- old save restoration still mirrors `Main.time_scale`; session-pause restore
  belongs to the later save/restore cutover.
- the unused Main `_has_pending_blocking_decision` helper remains typed-world-
  ports debt and must not be reconnected.

Next recommended boundary: `typed_world_ports`. It should remove the remaining
pre-existing world bridges without changing RuntimeLoop order or adding a Main
fallback.
