# Agent C — VS06-C3 Vertical-Slice Stage 4 Gate Handoff

## Outcome

TomorrowPlayableVerticalSlice stage 4 now consumes only the frozen v0.6 Coordinator façade:

- canonical card: `v06_first_table_facility_card`
- canonical market: `v06_first_table_facility_market_snapshot`
- purchase: `purchase_v06_first_table_facility_card`
- authoritative player state: `v06_card_player_snapshot`
- play and replay: `play_v06_runtime_card`

The legacy v0.4 card scan, district-card fixture, `_claim_district_card`, and empty-queue replay probe were removed. No production API, owner, UI, catalog, rule, or scene was changed.

## Stage 4 oracle

The real stage now requires all of the following before it can pass:

- the façade card/listing is the same canonical rank-I facility, with purchase cash `4` and asset total `0`;
- purchase commits through the canonical market, debits cash exactly `4`, preserves all assets, advances player and market revision once, and creates no facility;
- public runtime play routes through `core_economic_card_runtime`, advances only the player revision, consumes the card, produces exactly one finalized `play_card` journal row, and increases the facility roster once;
- the journal delta contains exactly the separate market-purchase and finalized play transactions;
- resubmitting the same public play request must return a committed idempotent replay while player, market, journal, assets, cash, and facilities remain byte-for-byte unchanged.

## Modified files

- `scripts/tools/tomorrow_playable_vertical_slice_bench.gd`
- `tests/tomorrow_playable_vertical_slice_test.gd`
- this handoff

`scenes/tools/TomorrowPlayableVerticalSliceBench.tscn` did not require modification.

## Minimal verification

- Godot 4.7 parse-only: PASS, failures `0`.
- Stage-4 oracle self-check: PASS. One complete lifecycle fixture passed and eight weakened fixtures were rejected (wrong cash, asset mutation, bad player/market revisions, duplicate finalize/facility, and weak replay evidence).
- No complete vertical slice, headed input run, default `user://` access, commit, push, merge, or new editor/MCP process was performed.

Coordinator commands:

```powershell
godot --headless --path . --script res://tests/tomorrow_playable_vertical_slice_test.gd -- --parse-only
godot --headless --path . --script res://tests/tomorrow_playable_vertical_slice_test.gd -- --stage4-oracle-self-check
godot --headless --path . --script res://tests/tomorrow_playable_vertical_slice_test.gd
```

## Evidence boundary and risk

This is an acceptance-path and oracle repair, not proof of a complete headed human flow. The coordinator owns the isolated full run.

The Gate deliberately requires public façade replay to return `committed=true` and `idempotent_replay=true`. Current static inspection shows `play_v06_runtime_card` resolves the consumed hand slot before forwarding to CardFlow; if that prevents the second call from reaching the terminal journal, the full Gate will correctly fail rather than treating a rejected call or an empty queue as replay evidence. Agent C did not change that production surface.

## Lessons for other agents

- **invariant:** v0.6 cards remain nested canonical definitions and never enter v0.4 district choices.
- **failed approach:** draining an empty resolution queue does not prove transaction replay.
- **stable API:** stage 4 uses only the five frozen Coordinator façade methods listed above.
- **test oracle:** purchase and play are two transactions with separate revision effects.
- **integration trap:** a post-consumption façade lookup can block terminal-journal replay.
- **reusable pattern:** snapshot owner state before purchase, after purchase, after play, and after same-ID replay.
- **stale evidence:** legacy `public_facility` name scanning and `_claim_district_card` were false v0.6 coverage.
- **next dependency:** coordination runs the isolated full Gate and routes any public-replay failure back to the façade owner.
