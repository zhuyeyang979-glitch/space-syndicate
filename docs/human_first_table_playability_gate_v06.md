# Human First-Table Playability Gate v0.6

## Purpose

This focused gate proves that the current production composition exposes one coherent human first-table path without adding a second gameplay owner. It is an acceptance skeleton for the vertical slice, not a replacement for headed usability testing or the complete Tomorrow Playable Vertical Slice suite.

## Covered Path

The test instantiates `res://scenes/main.tscn` and exercises these production surfaces and facades:

1. Open the real main menu and route `new_run` to `NewGameSetupPage`.
2. Configure one human and two AI seats, verify public role information, and keep AI starter monsters anonymous.
3. Start the real session, select the recommended district, and submit the human starter summon through the existing card-resolution route.
4. Verify the authoritative Monster owner records exactly one finalized terminal transaction.
5. Open the real district card drawer and its private purchase/discard window.
6. Purchase and play the canonical rank-I facility through `GameRuntimeCoordinator` v0.6 facades.
7. Verify that the sceneized map, local hand surface, and anonymous public track remain visible.
8. Open the real `FinalSettlementBoardPanel` and verify the board capability is visible and non-zero.

## Production Ownership

- `main.gd` remains the existing presentation and session adapter for this gate.
- `GameRuntimeCoordinator` remains the only production facade used for v0.6 card purchase and play.
- `MonsterRuntimeController` remains the authoritative starter-summon transaction owner.
- District purchase state continues through the existing private UI snapshot and discard APIs.
- No test-owned gameplay state, parallel transaction journal, or replacement owner is introduced.

## Privacy Contract

The gate recursively scans public snapshots and visible controls after injecting unmistakable private sentinels into an AI seat. Public output must not expose:

- opponent cash or economic-asset amounts;
- opponent hand or discard contents;
- hidden/true owner fields;
- AI memory, plans, route plans, reasoning, or utility scores.

The setup page may show each seat's public role. Only the local human may see the selected starter monster; AI starter choices remain anonymous.

## Isolation

The test overrides the production save path before entering the scene tree and must run with isolated `APPDATA` and `LOCALAPPDATA`. It must not read or write the player's default `user://` data.

Focused command:

```powershell
godot --headless --path . --script res://tests/human_first_table_playability_v06_test.gd
```

## Interpretation

A pass proves that the current production APIs can complete this deterministic first-table skeleton and that the inspected public surfaces respect the listed privacy boundary. It does not prove mouse/keyboard ergonomics, animation timing, full AI-cycle pacing, arbitrary map seeds, save recovery, or complete-match balance. Those remain responsibilities of the coordinated vertical-slice and headed playtest gates.
