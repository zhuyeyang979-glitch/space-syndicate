# Tomorrow Playable Vertical Slice Gate

## Deadline and outcome

By 2026-07-16, a human tester must be able to launch the Godot 4.7 build, start a local match with two AI seats, and reach a real final settlement without developer intervention.

The sample is accepted only when this production path works:

1. Main menu -> new match -> role and starter-monster setup.
2. One human seat and at least two AI seats enter the real table.
3. The human can select a district and perform the first monster summon.
4. The human can create one income-producing city/facility.
5. The human can inspect a regional supply, buy one card, and play one legal card.
6. AI seats summon, establish income, acquire or play a card, and continue acting without a deadlock.
7. Realtime income changes cash/GDP and the public table gives readable feedback.
8. The real victory controller starts its countdown and produces final settlement/recap.
9. Rival cash, rival hand, hidden owner truth, and AI private plans remain private.
10. The run is verified in Godot 4.7 with an isolated test save path and a headed human-flow check.

## Scope cut

Required for this build:

- first summon and monster deployment;
- one city/facility development path;
- one regional purchase path;
- one legal card-play path;
- minimum AI progression;
- realtime income;
- victory countdown and final settlement;
- readable next-action feedback.

Allowed to remain disabled or fail-closed if they are not required by the path above:

- contracts;
- military deployment;
- advanced counters and direct-player interaction;
- weather control;
- the complete card catalogue;
- every seat count and every roguelike depth.

No optional subsystem may display a blocking modal or prevent the core match from finishing.

## Legacy deletion gate

Delete a legacy script or compatibility path only when all of these are true:

1. A named production owner already replaces it.
2. `rg` and the scene/resource dependency scan show no remaining production consumer.
3. The replacement has focused tests and the vertical-slice acceptance path passes.
4. Save/load and hidden-information ownership remain unambiguous.
5. The deletion is listed in a retirement report with the replacement and evidence.

Do not delete a still-working path merely because it is old. Do not keep two active owners for hand, cash, assets, commodities, facilities, monsters, queue, or victory state.

## Agent lanes

### Agent A — production composition and legacy retirement

- Finish only the minimum SS06-09 facility lifecycle gate needed for one city/facility card.
- Become the sole production-composition integrator after that handoff.
- Wire the already-proven owners into the real runtime composition without creating duplicate owners.
- Audit and remove only replacement-backed legacy paths using the deletion gate above.
- Own integration failures reported by the vertical-slice acceptance test.

### Agent B — first summon and monster deploy

- Make rank-I starter-monster deployment work through the authoritative Monster owner.
- Preserve exact-once, rollback/finalize, privacy, save/load, and meter-based movement contracts.
- Same-family upgrade is P1 only after first summon is green.
- Do not expand combat, movement AI, wager, balance, or art scope.

### Agent C — full-match acceptance and human playtest

- Stop contract work at a safe checkpoint; leave incomplete effects fail-closed.
- Build one deterministic production-facing acceptance fixture for the exact ten-step path above.
- Author deterministic assertions for AI progression, countdown, recap, privacy, and isolated save behavior.
- Produce the headed Godot 4.7 playtest checklist; the coordinator owns final execution and capture.
- Report integration defects to A or B; do not patch their owners.

## Centralized validation model

Agents are implementers, not three separate release validators.

- Each Agent runs only a parser/load check and the smallest focused test needed to catch a broken handoff.
- Agents write exact commands and expected assertions into their handoff, without repeating full logs.
- The coordinator runs changed-cross-owner tests once, then one integrated headless gate, one privacy gate, and one headed human-flow check.
- Godot MCP/second-monitor capture is run once by the coordinator after all three lanes converge.
- No Agent runs the full smoke suite or duplicates another Agent's regression matrix unless the coordinator requests a specific fault isolation.

## Hard failure conditions

- The tester needs the editor, debug console, or manual state mutation.
- Any mandatory action has no visible entry point or is covered by a blocking panel.
- The match stalls before final settlement.
- A second business owner or transaction queue exists on the production path.
- Rival private state or AI reasoning appears in player-facing UI.
- Tests touch the default `user://` player save.
- A legacy deletion has no replacement/call-graph/test evidence.
