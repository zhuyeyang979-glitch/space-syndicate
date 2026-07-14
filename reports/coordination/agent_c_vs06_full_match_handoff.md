# Agent C VS06-C full-match acceptance handoff

Status: acceptance harness authored; Agent C-owned parse/minimal self-check PASS. Full cross-owner match, privacy, save, MCP, and headed evidence remain intentionally pending for the coordination thread.

## Changed files

- `tests/tomorrow_playable_vertical_slice_test.gd`
- `scripts/tools/tomorrow_playable_vertical_slice_bench.gd`
- Godot-generated UID companions for those two GDScript files
- `scenes/tools/TomorrowPlayableVerticalSliceBench.tscn`
- `docs/tomorrow_human_playtest_checklist.md`
- `reports/playability/tomorrow_vertical_slice/acceptance_spec.md`
- `reports/playability/tomorrow_vertical_slice/parse_self_check.md`

SS06-10 remains separately frozen in `reports/coordination/agent_c_ss06_10_wip_handoff.md`; no Contract file was changed after the priority override.

## Public acceptance API

`TomorrowPlayableVerticalSliceBench` exposes:

- `run_acceptance() -> Dictionary`
- exports `auto_run_on_ready`, `write_evidence`, and `quit_when_complete`
- fixed 1600×960 `%RuntimeViewport`
- QA run-save path `user://space_syndicate_design_qa/test_runs/tomorrow_vertical_slice.save`
- machine line `TOMORROW_VERTICAL_SLICE_BENCH|status=...|checks=...|failures=...|privacy_leaks=...`
- manifest at `reports/playability/tomorrow_vertical_slice/coordinator_runtime_manifest.json` when full execution is enabled

The manifest has ten mandatory ordered records. Every record is derived from a real `main.tscn` action and an authoritative before/after snapshot or receipt; absent integration is a FAIL, never a skip or hard-coded PASS:

1. root menu `new_run` / real setup / idle-close guard;
2. real 3-seat start, 1 human + 2 AI, CoreEconomic configured actor map;
3. human first summon with one finalized v0.6 monster lifecycle receipt;
4. production-catalog rank-I `public_facility` rack acquisition and exact-once CoreEconomic CardFlow dispatch;
5. CommodityFlow Sale Receipt, GDP, and cash-ledger change over seconds;
6. both AI first summon plus an AI income source and buy/play without queue deadlock;
7. VictoryControl qualification -> configured audit countdown -> versioned outcome receipt;
8. one visible settlement/recap, with outcome replay not duplicating it;
9. recursive public snapshot scan plus independent rendered-control scan, including AI setup starter and AI-seat rack canaries;
10. QA-only save roundtrip and unchanged default-player-save SHA-256 fingerprint.

## Minimal self-check

- Suite: parse-only scene/script load
- Checks: Bench scene loads and instantiates; test and Bench scripts compile
- Failures: 0
- Result: `TOMORROW_VERTICAL_SLICE_TEST|status=PASS|failures=0`
- Godot version: `4.7.stable.official.5b4e0cb0f`
- Godot MCP recognized the two GDScript resources. Agent C did not run the complete match or MCP Bench.

## Known risks and currently unproven wiring

These are audit-time risks; the harness will turn each into a structured red record if still present when the coordination thread runs it:

- Root lobby previously had a `new_run` handler but no root action, and idle `_close_menu()` could expose an empty table.
- Setup snapshots previously disclosed exact AI starter monsters/cards; AI-seat district-supply snapshots exposed exact cash and counted hand size.
- CoreEconomic was previously configured against an empty actor map before players existed; reset/new-game did not prove post-seat refresh.
- Main first summon previously used the legacy monster mutation path rather than the v0.6 prepare/commit/finalize journal.
- Public-facility play previously bypassed CoreEconomic CardFlow; a facility alone did not prove a CommodityFlow installation or Sale Receipt.
- AI action APIs have no single exact-once cross-domain receipt; the Bench therefore requires public domain outcomes and an idle queue, not an AI plan object.
- Victory public audit previously contained exact cash/ordinary-hand facts; the tomorrow privacy gate intentionally overrides that stale disclosure expectation.
- Ordinary victory opens `FinalSettlementBoard`; it may not create a campaign `MatchRecapPanel`. The oracle accepts one visible settlement/recap backed by the composed public board, not stale text labels.

## Coordination-thread execution

Run once after A/B wiring is stable:

```powershell
godot.cmd --headless --path . --script res://tests/tomorrow_playable_vertical_slice_test.gd
```

Then use Godot 4.7 MCP to run `res://scenes/tools/TomorrowPlayableVerticalSliceBench.tscn`, collect the summary, `get_debug_output`, and `stop_project`; require all ten records PASS, `privacy_leaks=0`, debug errors `[]`, and stop `finalErrors=[]`.

For headed evidence, follow `docs/tomorrow_human_playtest_checklist.md`: dynamically select a non-primary display, use 1600×960 native or explicitly labeled scaled SubViewport, and do not occupy display 1 when display 2 is unavailable.

## Lessons for other agents

- **Invariant:** a vertical-slice gate is green only when the player action and the authoritative owner receipt/snapshot both advance exactly once.
- **Failed approach:** a Bench record marked PASS merely because its skeleton exists hides production gaps and is not acceptance evidence.
- **Stable API:** `run_acceptance()` returns a fixed, ordered ten-record pure-data manifest and writes only the QA evidence path when enabled.
- **Test oracle:** compare owner journal/revision/roster/facility/receipt state before, after, and after replay; UI visibility alone is insufficient.
- **Integration trap:** binding adapters while `world.players` is empty can make static composition look ready while all runtime actor mappings are absent after new-game reset.
- **Reusable pattern:** install the QA save override on detached Main before adding it to the tree, and independently compare the production save fingerprint before/after.
- **Stale evidence:** legacy summon success, special `planet_destroyed` settlement, old final-menu prose, and public exact-cash audit assertions do not prove the current v0.6/tomorrow contract.
- **Next dependency:** A/B must finish the real CoreEconomic, facility/CommodityFlow, and monster lifecycle paths; the coordination thread then owns the single integrated/MCP/headed execution.

No commit, push, merge, `git add -A`, central index edit, default-player-save access, complete match run, or screenshot was performed by Agent C.
