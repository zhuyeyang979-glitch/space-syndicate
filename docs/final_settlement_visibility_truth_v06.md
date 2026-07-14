# Final Settlement Visibility Truth Gate (v0.6)

## Result

The production `res://scenes/ui/FinalSettlementBoard.tscn` is a visible, layout-participating settlement board. Its intentional root node name is `FinalSettlementBoardPanel`.

The Stage 8 `first_visible_board_count=0` and `replay_visible_board_count=0` evidence is an oracle naming mismatch, not a production visibility failure. The current vertical-slice oracle searches only `FinalSettlementBoard` and `MatchRecapPanel`, while production and the existing layout contract use `FinalSettlementBoardPanel`.

## Production Evidence

- `main.gd` instantiates `FinalSettlementBoard.tscn`, adds it to the visible settlement menu container, and calls `set_board()`.
- The real scene root is visible by default and participates in container layout.
- The focused truth test mounts the real scene under a visible `VBoxContainer` and verifies non-zero local and global size.
- The same public board schema renders title, KPI, evidence, event, ranking, and action content.
- Repeated `set_board()` replaces dynamic children, preserves one board root, and emits one action signal per button press.
- The public fixture contains no exact cash fields; recursive key scanning and rendered-text sentinel checks remain clean.

## Oracle Follow-up

The central acceptance harness should identify the production board by `FinalSettlementBoardPanel`, or preferably by its scene path plus `set_board()` capability, visibility, and non-zero size. Production scene identity must not be renamed solely to satisfy an outdated test name.

Focused oracle: `res://tests/final_settlement_board_visibility_truth_v06_test.gd`.

## Victory Public Source Ownership (VS06-A13)

`res://scenes/runtime/FinalSettlementPublicSourceAdapter.tscn` now owns the pure-data allowlist that builds final-settlement public source facts, public outcome log copy, and recap summary copy. It does not own victory eligibility, ranking, cash, or the authoritative outcome receipt.

The v0.6 audit disclosure rule is state-authorized:

- Normal seats and seats outside the active audit reveal list keep exact cash private.
- Exact cash may be projected only when the authoritative Victory public snapshot declares `cash_visibility=public_audit`, includes the seat in `audit_revealed_player_indices`, and supplies that seat's exact cash in its public audit payload.
- Missing visibility state, a mismatched player index, a value injected only into raw player state, or a value present only in the internal outcome receipt fails closed and remains hidden.
- The internal Victory receipt keeps exact cash for the final tie-break. The adapter never changes that receipt and never infers disclosure from winner status, game-over state, or an internal ranking.

The current Victory owner does not yet emit the v0.6 audit-cash authorization fields. Until its separate owner task adds them, the production adapter correctly hides every exact balance. The adapter Bench separately proves the authorized state path, the non-audit path, and the forged-without-visibility path.

## Main Retirement Evidence

The following formatter and source families were physically removed from `main.gd` after the scene API replaced them:

- `_final_settlement_public_source_snapshot`
- `_final_settlement_money_source_entries`
- `_final_player_breakdown_summary`
- `_final_run_summary_text`

`main.gd` now keeps only the scene lookup, public world-fact read, and existing signal/menu forwarding required by the current root composition. Public log construction and recap formatting are no longer implemented in `main.gd`.

Focused runtime gate: `res://scenes/tools/FinalSettlementPublicSourceAdapterBench.tscn`.
