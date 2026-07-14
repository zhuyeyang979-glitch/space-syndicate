# Active Local Coordination

Updated: 2026-07-15

This checkpoint records the user-designated local integration arrangement after the Supervisor task became unavailable. It is operational guidance, not a gameplay rules source.

## Active roles

| Role | Worktree | Branch | Godot MCP | Responsibility |
| --- | --- | --- | --- | --- |
| Codex A / active coordinator | `C:/Users/zhuye/Documents/New project/.codex-worktrees/space-syndicate-a-v06` | `codex/a-v06-local-integration` | `8775` | Review and integrate local commits, own `main.gd` deletion/cutover, run milestone acceptance, and decide when the milestone is ready to push. |
| Codex B | `C:/Users/zhuye/Documents/New project/.codex-worktrees/space-syndicate-b-v06` | task-specific branch | `8785` | Scoped production implementation. Do not edit A/C-owned files or protected integration branches. |
| Codex C | `C:/Users/zhuye/Documents/New project/.codex-worktrees/space-syndicate-c-v06` | task-specific branch | `8795` | Independent production acceptance and stale-oracle retirement. Production edits require an explicit new assignment. |

The retired Supervisor worktree at `space-syndicate-supervisor` is read-only. Its head `26f16d3` is already an ancestor of the A integration line through merge `c5602f2`; do not re-merge or resume it.

## Integration policy

1. Each role edits, tests, and commits only in its own worktree.
2. B and C report local commit SHAs to A. They do not push unless A explicitly assigns a milestone push.
3. A reviews and merges local commits into `codex/a-v06-local-integration` without force-pushing.
4. Cloud synchronization happens after a coherent milestone passes focused, privacy, save, and headed visual acceptance. It does not happen after every atomic commit.
5. `scripts/main.gd` is a deletion target. A may add only a narrow temporary connection to an already scene-owned/runtime-owned API, and the same milestone must remain net-negative in Main responsibility and code.
6. Never restore retired Main wrappers or obsolete rules to satisfy stale tests. Migrate or physically retire the stale oracle after an owner-focused replacement gate exists.

## Current v0.6 rule lock

- Starter monster selection grants a held card; summoning is voluntary and never gates facilities, economy, or market access.
- Ordinary-card listings are globally visible but purchasable only when their authoritative source region is sunlit.
- The planet completes one rotation every 120 integer `world_effective` seconds. Solar phase is derived and owns no save section.
- A quote locks eligibility and price for five `world_effective` seconds and is valid only while `now < expires_at`.
- For base price `P`, `q2 = min(10, 2 + 2 * same_alive + adjacent_alive)` and `final_price = ceil(P * q2 / 2)`. Monster ownership is irrelevant; down or expired monsters do not count.
- Camera pan, zoom, selection, projection, and programmatic focus never affect sunlight, listing facts, price, quote identity, or authorization.

The authoritative player rules remain `docs/tabletop_rulebook_v06.md`; this checkpoint must be updated rather than used to override that rulebook.

## Current local milestone

- A local integration is at `2471b19`: it includes the retired Supervisor work, v0.6 solar market runtime, public/private quote identity separation, save/privacy gates, static Main composition cutover, scene-owned solar-facing MapView camera, and the narrow public snapshot injection. Nothing in this milestone has been pushed.
- The solar camera milestone is green on its 23-check state-machine gate, Main composition, 5-check cross-seat quote privacy, 16-check clock/save production acceptance, globe default, smoke check-only, 286-script parse, and a real headed quick-start run. Play mode and child processes were cleanly stopped.
- B is read-only auditing the remaining Codex/Compendium public-source cluster from exact A baseline `2471b19`; any implementation must stay outside `main.gd` until A approves a deletion cutover.
- C is conservatively replacing only the Weather owner reset inside one smoke case from baseline `92c6e26`; unsupported private intel/AI/route/scenario assertions remain untouched. A will review and merge the local C commit when its focused evidence is complete.
