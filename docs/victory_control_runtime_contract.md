# Victory Control Runtime Contract (Ruleset v0.5)

## Status

SS05-04 is a hard cutover. `VictoryControlRuntimeController` is the only runtime owner of region control, Top-N qualification, the audit lifecycle, endpoint ordering, special victory comparison, save state, and the immutable outcome receipt. There is no cash-goal or legacy countdown fallback.

## Ownership

`VictoryControlRuntimeController` owns:

- unique-highest region control at 3000 basis points;
- depth I-VI requirements: 3/90, 4/130, 5/180, 6/230, 7/290, and 8/360;
- automatic Top-N selection from controlled regions;
- 10 world-effective seconds of qualification;
- a sticky 120-second public audit roster;
- a 30-second failed-audit cooldown;
- endpoint order: Top-N attributable GDP, controlled-region count, cash ledger;
- exact ties as co-victory;
- last-survivor and planet-destruction receipts;
- versioned save/load state and exact-once outcome identity.

`VictoryControlWorldBridge` is non-owning. It only collects pure facts from the current world and forwards an outcome receipt once. It does not calculate GDP, project shares, control, eligibility, ordering, cash mutation, or session state.

`CityTradeNetworkRuntimeController` and the structured GDP project bridge remain the only owners of GDP rows and player attribution. `GameSessionRuntimeController` consumes the first outcome receipt and owns the finished session state.

## Region Control

For each non-destroyed region with positive GDP:

1. Read each player's attributable GDP from the existing private project-attribution receipt.
2. Calculate share in basis points against total regional GDP.
3. Require at least 3000bp.
4. Require the player to be the unique highest contributor.

An exact highest-share tie, destroyed region, or zero-GDP region has `controller_player_index=-1`. Neutral rounding remainder is not awarded to a player.

## Qualification And Audit

An eligible leading player satisfies both the controlled-region count and Top-N attributable GDP requirement for the selected depth. The leading comparison chain is Top-N GDP, controlled-region count, then cash ledger.

- Qualification progress resets when a player is no longer a qualifying leader.
- At 10 effective seconds, the current tied leaders enter the audit roster.
- Audit lasts 120 effective seconds and does not cancel when a listed player temporarily loses eligibility.
- A new sole or tied leader joins the roster immediately and becomes public.
- At the endpoint, same-tick leaders join before ranking.
- Only roster players who are still eligible become finalists.
- If no finalist remains, the controller enters a 30-second cooldown and audit-only assets become private again.

Menu pause, readonly pause, forced-decision pre-emption, and the monster-wager world freeze consume no qualification, audit, or cooldown time.

## Privacy

Before audit, exact economic assets are viewer-private. During audit, only roster players expose:

- available and escrow cash, plus their sum as `cash_ledger_cents`;
- project positions, share basis points, and attributable GDP;
- contracts, warehouses, financial positions, margins, hand count, and public unit count.

Specific hand contents, private intel, hidden monster ownership, private targets, private discards, and AI plans never enter public snapshots. A player who joined the roster remains public until audit resolution or failed-audit cooldown.

## Outcome Receipt

Normal audit receipts use comparison order:

1. `top_n_gdp_per_minute`
2. `controlled_region_count`
3. `cash_ledger_cents`

Planet destruction uses cash ledger only and equal ledgers co-win. Last survivor uses the same versioned receipt envelope. `GameSessionRuntimeController`, Final Settlement, standings history, AI learning, and save summaries consume this receipt; they do not reconstruct a second score.

## Save Contract

The victory domain saves its schema version, ruleset ID, state, per-player qualification elapsed time, sticky audit roster, remaining audit/cooldown time, outcome sequence, and outcome receipt. Invalid schema, ruleset, or state fails closed without mutating active state. Legacy absence initializes an idle controller.

## Deletion Gate

Production code must not contain a writable `game_over` variable, `victory_countdown_*`, `_roguelike_cash_goal`, `_player_visible_settlement_estimate`, `_player_final_score`, `_final_score_rankings`, or `CITY_FINAL_VALUE`. Compatibility blocker facts may still use the pure-data key `game_over` while their consumers migrate, but that key is derived only from `GameSessionRuntimeController.is_finished()`.

## Evidence

`VictoryControlRuntimeBench` provides 56 cases covering thresholds, all depths, qualification/audit/cooldown boundaries, clock freezes, roster stickiness, endpoint order, co-victory, save/load, public/private scope, special outcomes, exact-once session completion, consumer ownership, main composition, and legacy deletion.
