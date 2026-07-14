# Agent A - VS06-A8 Final Settlement Visibility Handoff

## Status

VS06-A8 is complete at focused-evidence level. The real Final Settlement board is visible and correctly laid out. No production scene or UI script change was necessary.

The central Stage 8 counts are an oracle mismatch:

- production scene root: `FinalSettlementBoardPanel`;
- existing layout contract: explicitly requires `FinalSettlementBoardPanel`;
- existing Final Settlement cutover bench: locates `FinalSettlementBoardPanel`;
- vertical-slice oracle: counts only `FinalSettlementBoard` and `MatchRecapPanel`.

Renaming the production root to satisfy that stale oracle would break the established scene contract and was intentionally rejected.

## Read-Only Production Audit

`main.gd` already performs the correct composition sequence:

1. instantiate `FinalSettlementBoard.tscn`;
2. connect the board's `action_requested` signal once;
3. add the board to the visible settlement preview container;
4. call `set_board()` with the public board snapshot.

The scene root is visible by default, uses container layout, expands horizontally, and has no script path that hides or collapses it. `set_board()` renders into static scene-owned containers and clears dynamic children before rebuilding them.

No changes were made to `main.gd`, the vertical-slice harness/tests, Coordinator, Victory, settlement service, economy, AI, rules, or settlement data.

## Focused Truth Gate

Added:

- `tests/final_settlement_board_visibility_truth_v06_test.gd`
- `docs/final_settlement_visibility_truth_v06.md`

The test directly instantiates the real scene under a visible `VBoxContainer`, supplies the production board schema, and proves:

- host, layout, and board are visible in tree;
- local and global board sizes are non-zero;
- title, KPI cards, public rankings, and after-actions render;
- the established root remains `FinalSettlementBoardPanel`;
- repeated `set_board()` leaves exactly one board root;
- dynamic child counts remain stable after replay;
- one button press emits exactly one stable `action_requested("standings")` signal;
- the public fixture has zero recursive exact-cash/economic-asset keys;
- rendered text contains no exact opponent-cash sentinel.

Godot `4.7.stable`, isolated temporary `APPDATA` and `LOCALAPPDATA`:

- A7 `tests/victory_control_public_projection_privacy_v06_test.gd`: PASS, `28/28`, failures `0`, no engine errors.
- A7 `tests/victory_control_split_delta_precision_test.gd`: PASS, `57/57`, failures `0`.
- `tests/final_settlement_board_visibility_truth_v06_test.gd`: PASS, `16/16`, failures `0`, no engine errors.

Combined frozen evidence is therefore `28/28` privacy, `57/57` victory precision, and `16/16` Final Settlement visibility truth. A8 did not rerun or modify the already frozen A7 production boundary.

No full vertical slice, MCP/headed run, default `user://` access, commit, push, merge, staging, reset, or clean operation was performed.

## Required Central Follow-up

After C9/B5b freeze, the central oracle should either:

1. include the established node name `FinalSettlementBoardPanel`; or
2. preferably locate `res://scenes/ui/FinalSettlementBoard.tscn` by scene path/capability and require `is_visible_in_tree()` plus non-zero size.

Then rerun Stage 8 first-open and replay counts. Production UI should not be renamed.

## Lessons for other agents

- **invariant:** scene identity and acceptance-oracle identity are separate; a zero name count is not proof of an invisible Control.
- **failed approach:** renaming `FinalSettlementBoardPanel` to an oracle's expected string would repair the test while weakening the production scene contract.
- **stable API:** `FinalSettlementBoard.tscn` plus `set_board(Dictionary)` and `action_requested(String)` is the production contract.
- **test oracle:** mount the real scene under a visible container, then require in-tree visibility, non-zero geometry, stable child counts, and exact-once action emission.
- **integration trap:** Godot may auto-rename repeated dynamic sibling nodes, so count container children rather than exact sibling names.
- **reusable pattern:** first distinguish composition, visibility, geometry, and naming; only edit production when the first three fail.
- **stale evidence:** `first_visible_board_count=0` from a two-name allowlist is obsolete because it omits the actual scene root.
- **next dependency:** B/central acceptance updates the oracle after C9 freezes and reruns Stage 8.
