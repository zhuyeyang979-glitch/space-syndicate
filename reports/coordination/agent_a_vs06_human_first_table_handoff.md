# Agent A VS06-A9 Handoff

## Result

VS06-A9 Human First-Table Playability Gate is frozen.

- Focused result: `PASS | checks=25 | failures=0 | privacy_leaks=0`
- Godot: `4.7.stable.official.5b4e0cb0f`
- Production files changed: none
- Default player `user://` accessed: no
- Full slice, MCP, and headed validation run: no, by coordination contract

## Files Added

- `tests/human_first_table_playability_v06_test.gd`
- `docs/human_first_table_playability_gate_v06.md`
- `reports/coordination/agent_a_vs06_human_first_table_handoff.md`

## Proven Production Path

The focused test instantiates real `main.tscn` and proves:

1. main menu `new_run` opens the real new-game setup;
2. one human plus two AI seats start, with public roles and anonymous AI starters;
3. the human starter summon drains through the real card-resolution path and creates exactly one finalized Monster terminal;
4. a selected district opens the real supply drawer, active purchase window, and private pending-discard capability;
5. the canonical rank-I facility is purchased and finalized through existing Coordinator facades;
6. `PlanetBoard`, `PlanetMapView`, `PlayerBoard`, `HandRack`, and anonymous `PublicTrack` remain visible and non-zero;
7. the real `FinalSettlementBoardPanel` capability opens visibly.

This task did not add a test transaction owner, modify rules, or change production routing.

## Privacy Evidence

The test injects distinct opponent-cash, private-hand, hidden-owner, and AI-plan sentinels. It recursively scans setup, district-supply, Victory public, Final Settlement public, and visible control text. Result: zero forbidden keys or sentinel values reached the inspected public/player-visible surfaces.

## Focused Command

Run from the repository root with isolated temporary `APPDATA` and `LOCALAPPDATA`:

```powershell
godot --headless --path . --script res://tests/human_first_table_playability_v06_test.gd
```

Output:

```text
HUMAN_FIRST_TABLE_PLAYABILITY_V06_TEST|status=PASS|checks=25|failures=0|privacy_leaks=0
```

## Known Limits And Coordination Follow-up

- This is a deterministic headless acceptance skeleton, not a headed usability or pacing test.
- It does not replace the Tomorrow Playable Vertical Slice, full AI progression, save/load isolation, arbitrary map-seed coverage, or real mouse/keyboard navigation.
- Coordination should run the unified vertical slice after active B/C production changes freeze.
- The test intentionally checks Final Settlement capability without fabricating a completed Victory receipt.

## Lessons for other agents

- **Invariant:** A playability gate must call the existing production facade and verify the authoritative owner's terminal journal; a coach boolean or UI animation is not completion evidence.
- **Failed approach:** Treating scene presence or a submitted queue entry as proof of first summon/play completion misses pre-owner rejection and partial lifecycle failures.
- **Stable API:** `GameRuntimeCoordinator.v06_first_table_facility_market_snapshot`, `purchase_v06_first_table_facility_card`, `v06_card_player_snapshot`, and `play_v06_runtime_card` form the current facility path; Monster completion is evidenced by its terminal journal.
- **Test oracle:** Require exact owner deltas and a finalized terminal, then verify the real scene surfaces remain visible.
- **Integration trap:** Setup information has two independent boundaries: public roles are visible, while AI starter monster choices remain anonymous.
- **Reusable pattern:** Inject unmistakable private sentinels into an opponent, then recursively scan both pure-data snapshots and visible control text.
- **Stale evidence:** Historical fixture benches and scene-name counts do not prove the current real-main path or runtime visibility.
- **Next dependency:** Coordination owns the complete vertical-slice, headed input/usability, save isolation, and multi-seed acceptance after all active owners freeze.
