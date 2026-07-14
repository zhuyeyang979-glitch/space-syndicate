# Agent A - VS06-A7 Victory Public Privacy Handoff

## Status

VS06-A7 is complete at focused-evidence level. Only the Victory public/private projection boundary changed. Victory eligibility, qualification and audit clocks, candidate ordering, exact cash tie-break, immutable internal outcome receipt, and save data remain authoritative and unchanged.

The four centrally reported public leak paths are no longer emitted:

- `victory.public.audit_entries[*].cash_ledger_cents`
- `victory.public.audit_entries[*].economic_assets.available_cents`
- `victory.public.audit_entries[*].economic_assets.cash_ledger_cents`
- `victory.public.outcome_receipt.rankings[*].cash_ledger_cents`

## Projection Boundary

`public_snapshot(-1)` now exposes only public victory evidence:

- player index and eligibility;
- top-K public GDP;
- controlled-region count and controlled-region IDs;
- public region-share evidence;
- audit state and timing;
- ranking order, winner flags, reason, and settlement checkpoint.

It does not expose exact cash, available/escrow balances, an `economic_assets` envelope, ordinary hands, inventory, contracts, financial positions, or renamed equivalents.

`public_snapshot(viewer_index)` remains the same anonymous public projection; the viewer argument does not authorize private data. `private_snapshot(viewer_index)` exposes exact authorized assets only under `own_economic_assets`. Its `own_candidate`, audit entries, rankings, and other seats remain public projections.

`outcome_receipt()` remains the internal canonical receipt and still contains exact `cash_ledger_cents` in rankings for the final comparator. `to_save_data()` still stores that exact internal receipt. `public_snapshot().outcome_receipt` is now built independently and removes exact cash values without mutating the internal receipt. The published `comparison_order` may name `cash_ledger_cents` as a rule, but never carries the compared values.

`VictoryControlWorldBridge` was intentionally not changed in A7. It must continue supplying exact cash and economic facts to the internal Victory owner; sanitization belongs at the controller's public projection exit, not at fact capture.

## Modified Files

- `scripts/runtime/victory_control_runtime_controller.gd`
  - Added a public candidate projection.
  - Removed public audit cash/economic asset emission.
  - Added an independently constructed public outcome projection.
  - Sanitized `private_snapshot().own_candidate` while retaining exact own data under `own_economic_assets`.
- `tests/victory_control_public_projection_privacy_v06_test.gd`
  - Added recursive forbidden-key and exact-value sentinel coverage for public and viewer-private outputs.
  - Proves internal cash ranking and saved receipt remain exact.
- `docs/victory_control_runtime_contract.md`
  - Corrected the public/private disclosure contract to match the active privacy requirement.

No `main.gd`, Coordinator, world capture, settlement, UI, AI, economy, card, monster, timing, rule formula, or C-owned acceptance file was modified.

## Focused Verification

All commands used Godot `4.7.stable` with isolated temporary `APPDATA` and `LOCALAPPDATA` directories.

- `tests/victory_control_public_projection_privacy_v06_test.gd`: PASS, `28/28`, failures `0`, no engine errors.
- `tests/victory_control_split_delta_precision_test.gd`: PASS, `57/57`, failures `0`.
- Focused tracked diff whitespace check: PASS.

The privacy test proves:

- recursive forbidden public key paths: `0`;
- recursive exact cash/private-hand sentinel paths in public output: `0`;
- another seat's private values in viewer-private output: `0`;
- exact own values exist only under `own_economic_assets`;
- internal rankings retain both exact cash values and cash ordering;
- public projection does not mutate `outcome_receipt()`;
- save data retains the authoritative internal receipt;
- all public and private projections are pure data.

No full vertical slice, MCP/headed run, default `user://` access, commit, push, merge, staging, reset, or clean operation was performed. Central acceptance remains coordinator-owned.

## Known Risks And Next Acceptance

- The coordinator must rerun the isolated Tomorrow Playable Vertical Slice and confirm Stage 9 has zero recursive privacy violations.
- The controller and contract already contained shared-worktree changes before A7; this handoff claims only the projection changes described above.
- Any future public receipt field must be added through explicit projection, never by duplicating the internal receipt.

## Lessons for other agents

- **invariant:** exact cash may remain authoritative for victory ordering while still being absent from every public projection.
- **failed approach:** returning `_outcome_receipt.duplicate(true)` as a public receipt leaks internal comparator inputs.
- **stable API:** `outcome_receipt()` is internal exact state; `public_snapshot().outcome_receipt` is a separate sanitized schema; `private_snapshot().own_economic_assets` is the only exact viewer-owned envelope.
- **test oracle:** recursive forbidden-key and sentinel scans must both be zero, while internal rankings and save data still contain the exact expected cash values.
- **integration trap:** removing cash at the WorldBridge would break tie-break correctness and save parity; sanitize only after internal evaluation.
- **reusable pattern:** capture exact facts, compute authoritative receipt, then construct an allow-listed public projection field by field.
- **stale evidence:** the previous contract text that exposed full audit economic assets publicly is obsolete and unsafe.
- **next dependency:** coordinator reruns Stage 9 privacy scanning against the real combined snapshot.
