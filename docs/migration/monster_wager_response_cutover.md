# Monster Wager Forced-Response Cutover

Human monster-wager choices now use one typed, scene-owned production path:

`GameScreen -> ForcedDecisionResponsePort -> MonsterWagerResponseSink -> MonsterRuntimeController`

`ForcedDecisionResponsePort` remains the shared identity, active-decision and
request-journal authority. `MonsterWagerResponseSink` consumes only authorized
`monster_wager` responses, rechecks the exact option currently advertised by
the wager owner, and delegates one mutation to the existing monster runtime.
It owns no wager, player cash, public pool, save state or presentation state.

The live-option recheck prevents a forged percentage from being silently
clamped into a different wager. Rendered decision ID and revision are frozen
at display time, so a click from an old wager window cannot bind to a newer
wager. Supported competitor side identifiers use the existing `a` through `h`
syntax, while the domain sink still rejects any side absent from the current
matchup.

The owner now exposes one public typed wager-response entry used by the human
sink and the existing AI adapter. The obsolete private percentage wrapper was
deleted. Wager debits and settlement credits keep `cash` and `cash_cents`
synchronized so the wager cannot disappear from final cash accounting.

The response receipt is viewer-private. Its public projection contains only
facts that the current wager rules intentionally expose: player index, side,
percentage, stake and whether the decision closed. It omits remaining cash,
hand/discard data, hidden monster ownership, anonymous-card ownership,
`ai_wager_*` metadata, plans, scores and internal request identity.

Removed from `scripts/main.gd`:

- `TEMP_DECISION_MONSTER_WAGER`;
- the `monster_wager:<id>:<side>:<percent>` parsing branch;
- the direct call to `_place_monster_wager_percent`;
- the zero-consumer `_active_bottom_countdown_state` legacy aggregator, which
  still sampled private wager/controller state from Main.

The prior branch reported an action as handled even when the wager owner
rejected it. The typed receipt now reports the actual domain result.

## Rule-wiring debt deliberately not changed here

This cutover migrates response ownership without changing wager timing or
settlement mathematics. Production runtime values still differ from the v0.6
rulebook/pure settlement policy in window duration, maximum stake, opening-cash
snapshot, timeout side choice and payout multiplier. Those changes require a
separate atomic `MONSTER_WAGER_SETTLEMENT_OWNER_CUTOVER` with multi-player
cash/pool transaction and save-lineage tests. This response cutover must not be
used as evidence that the complete v0.6 settlement formula is production-wired.

Focused evidence:

- `res://tests/monster_wager_response_cutover_test.gd` — 40/40
- `res://tests/forced_decision_response_boundary_test.gd`
- `res://tests/card_target_choice_response_cutover_test.gd`
- `res://scenes/tools/MonsterWagerResponseSinkBench.tscn` — Godot 4.7 MCP 11/11
