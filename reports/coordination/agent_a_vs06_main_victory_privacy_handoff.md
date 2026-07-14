# Agent A VS06-A13 Handoff: Victory Public Source Privacy

Status: complete and frozen.

## Ownership And Files

- `scenes/runtime/FinalSettlementPublicSourceAdapter.tscn` is the production scene owner for final-settlement public-source allowlisting, outcome log copy, and recap summary copy.
- `scripts/runtime/final_settlement_public_source_adapter.gd` consumes only pure public facts and the authoritative Victory public projection. It owns no Victory rule, ranking, cash, save, or player state.
- `scenes/tools/FinalSettlementPublicSourceAdapterBench.tscn` and `scripts/tools/final_settlement_public_source_adapter_bench.gd` form the editable MCP gate.
- `scenes/main.tscn` statically instances the adapter under `RuntimeServices`.
- `scripts/main.gd` only locates the node, reads public world facts, validates public/internal outcome identity, and forwards existing menu/signals.
- `tests/main_victory_public_privacy_v06_test.gd` exercises a real main/Victory outcome before checking every public projection.
- `scripts/tools/final_settlement_public_snapshot_cutover_bench.gd` now consumes the scene API instead of the deleted main helper.

## v0.6 Audit Visibility Contract

Exact cash is public only when all three conditions are present in the authoritative Victory public snapshot:

1. `cash_visibility == "public_audit"`.
2. The seat is in `audit_revealed_player_indices`.
3. The public audit payload provides that seat's `cash_ledger_cents`.

The adapter never reads exact cash from raw players or the internal outcome receipt. Winner/game-over state does not imply disclosure. Missing visibility, wrong seat, and injected values fail closed. The current Victory owner does not yet emit these new fields, so current production remains hidden until that separate owner task is aligned with rulebook v0.6 section 4.3.

## Main Deletion Gate

Physically absent from `scripts/main.gd`:

- `_final_settlement_public_source_snapshot`
- `_final_settlement_money_source_entries`
- `_final_player_breakdown_summary`
- `_final_run_summary_text`

Captured pre-slice spans reconstruct total lines as 20,512 before A13. Current measurement is 20,409 total lines and 17,934 nonblank lines: net total deletion 103 lines. Function count moved from 1,166 to 1,165. Static `rg` finds zero production definitions for all four retired symbols.

## Focused Evidence

- `tests/main_victory_public_privacy_v06_test.gd`: PASS 20/20. Real outcome keeps exact cash internally; ordinary public path hides it; explicit audit authorization reveals only the listed seat; non-audit and forged values remain hidden.
- `tests/victory_control_public_projection_privacy_v06_test.gd`: PASS 28/28 before the section 4.3 correction. This is useful owner-regression evidence but its blanket-hide expectation is stale and must be revised by the Victory owner task.
- `tests/human_first_table_playability_v06_test.gd`: PASS 25/25, privacy leaks 0.
- `FinalSettlementPublicSourceAdapterBench.tscn` Godot MCP run: PASS 5/5. The Bench instances the production Adapter and `FinalSettlementPublicSnapshotService`, checks authorized audit visibility, non-audit hiding, and forged-state rejection.
- Godot MCP 4.7 evidence: `run_project(res://scenes/tools/FinalSettlementPublicSourceAdapterBench.tscn)` -> `get_debug_output` returned `errors=[]` -> `stop_project` returned `finalErrors=[]`.

No full smoke, default `user://`, commit, push, merge, or cross-owner production edit was performed.

## Known Risks And Next Dependency

- Victory public projection must add the explicit v0.6 audit reveal state and public audit amount. The adapter is ready and fail-closed, but does not invent that owner state.
- Existing historical docs/tests that say exact cash is always hidden are stale after rulebook v0.6 section 4.3. They must be migrated by the Victory owner, not restored as production behavior.
- The public source still reads bounded public world facts from main. Moving those facts into a dedicated WorldBridge is the next safe main-retirement slice.

## Lessons For Other Agents

- **Invariant:** internal exact cash remains authoritative for tie-breaks; disclosure is a separate public-projection decision.
- **Failed approach:** blanket removal of every cash field contradicted the newer v0.6 audit rule.
- **Stable API:** `compose_public_source`, `compose_public_summary`, `public_outcome_log_payload`, and `sanitize_public_log_entries` accept and return pure data.
- **Test oracle:** inject exact sentinels before a real outcome, then test authorized, non-authorized, and forged visibility states independently.
- **Integration trap:** winner or resolved state is not audit authorization; do not infer visibility from either.
- **Reusable pattern:** rebuild public payloads from allowlists and state-bound capability fields instead of recursively redacting private payloads.
- **Stale evidence:** the old 28/28 Victory public test validates the previous blanket-hide contract and is not complete v0.6 conformance evidence.
- **Next dependency:** Victory owner must publish `cash_visibility`, `audit_revealed_player_indices`, and the authorized audit-cash payload before real audit disclosure can appear.

MCP lease released after the project was stopped; no A-owned Godot process remains.
