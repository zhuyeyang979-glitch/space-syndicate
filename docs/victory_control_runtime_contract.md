# Victory Control Runtime Contract (Ruleset v0.6)

## Status

SS06-05 is a hard cutover. `VictoryControlRuntimeController` is the only runtime owner of region control, dynamic victory requirements, qualification, public audit, endpoint comparison, save state, special outcomes, and the immutable outcome receipt. The v0.5 fixed-depth table and failed-audit cooldown have no runtime fallback.

## Ownership

`VictoryControlRuntimeController` owns:

- unique-highest commodity GDP region control at 3000 basis points;
- the live surviving-region denominator `A`;
- `K = ceil(A * 40%)`, clamped to at least one when `A > 0`;
- the live GDP threshold `K * 36 GDP/min`;
- each player's top-K controlled-region commodity GDP;
- independent 10-second qualification progress for every eligible player;
- the sticky 120-second public audit roster;
- the only public exact-cash authorization derived from that roster;
- endpoint order: exact top-K commodity GDP cents, controlled-region count, exact cash ledger cents;
- exact ties as co-victory;
- last-survivor and explicitly authorized irreversible-planet-destruction receipts;
- versioned save/load state and exact-once outcome identity.

`VictoryControlWorldBridge` is non-owning. It collects pure region lifecycle facts from `RegionInfrastructureRuntimeController`, exact 30-second sale GDP facts from `CommodityFlowRuntimeController`, authorized audit disclosure facts from other domain owners, and a settlement checkpoint. It does not calculate GDP, control, eligibility, ordering, cash mutation, or session state.

`GameSessionRuntimeController` consumes the first outcome receipt and remains the only owner of the finished session state.

## Dynamic Region Rule

For every surviving, non-ruined region:

1. Read total commodity GDP and each player's exact attributable commodity GDP in cents.
2. Calculate each player share in basis points against regional GDP.
3. Require at least 3000bp.
4. Require the player to be the unique highest contributor.

An exact highest-share tie or zero-GDP region has `controller_player_index=-1`. A surviving zero-GDP region still contributes to `A`. Ruined regions do not contribute to `A`.

The ordinary victory requirement is recomputed from current world facts:

- `A` is the current number of surviving regions.
- `K = ceil(A * 4000 / 10000)` and is at least one when `A > 0`.
- required GDP is `K * 36 GDP/min`.
- a player must control at least `K` regions and the sum of that player's highest `K` controlled-region GDP values must meet the threshold.
- when `A == 0`, ordinary GDP victory is paused until a surviving region exists.

## Qualification And Audit

- Every eligible player accumulates qualification time independently.
- Losing eligibility resets only that player's qualification progress.
- At 10 world-effective seconds, the player joins the audit roster.
- Audit lasts 120 world-effective seconds and never restarts because `A`, `K`, control, GDP, or roster membership changes.
- A new player may join during audit only after completing their own 10-second qualification.
- Once listed, a player remains disclosed for the lifetime of that audit.
- At the endpoint, only roster players who still satisfy the live dynamic rule become finalists.
- If no finalist remains, the controller returns directly to idle. v0.6 has no failed-audit cooldown.

Menu pause, readonly pause, forced-decision pre-emption, and monster-wager world freeze consume no qualification or audit time.

## Same-Tick Settlement Order

The audit endpoint may settle only from a world snapshot marked `post_world_settlement`. In the endpoint tick, the runtime order is:

1. complete locked attack, monster, military, logistics, and lifecycle mutations;
2. settle continuous commodity flow and sale receipts;
3. apply bankruptcy/elimination state;
4. refresh region lifecycle and exact GDP facts;
5. evaluate the victory endpoint.

A read-only or stale checkpoint returns `awaiting_post_world_settlement_checkpoint` and emits no outcome receipt.

## Audit Disclosure And Privacy

Before audit, exact cash and economic assets remain viewer-private. During an active authoritative audit, and after a normal audit has finalized, the owner may disclose exact `cash_ledger_cents` only for the stable unique seats in its own sticky audit roster. It publishes the authorization at the top level as `cash_visibility="public_audit"` and `audit_revealed_player_indices=[...]`; each authorized row repeats `cash_visibility="public_audit"` and carries a canonical integer `cash_ledger_cents`. Missing, malformed, stale, or non-authoritative roster state exposes no exact cash at all.

The authorization is a narrow cash-only projection. Public audit entries never contain available cash, escrow cash, ordinary hand contents, owned inventory, contracts, positions, organization ownership truth, AI plans, or an `economic_assets` envelope. A winner, high rank, `game_over`, private receipt, or caller-supplied field cannot authorize disclosure. A seat outside the owner roster stays hidden even when it wins or ranks above a roster seat.

`private_snapshot(viewer_index)` may expose that viewer's exact authorized assets only under `own_economic_assets`. Its `own_candidate`, public audit entries, public rankings, and every other seat remain public projections. A viewer-private snapshot must not contain another seat's exact assets.

`outcome_receipt()` and saved controller state remain authoritative internal records and retain exact cash for the final comparison. `public_snapshot().outcome_receipt` is separately constructed. It preserves rank, winner, GDP, controlled-region count, reason, and comparison order; exact cash is added only for the same owner-authorized audit seats. Special outcomes without an audit roster, including cash-tiebreak planet destruction, publish no exact cash. Projection never mutates the internal receipt.

Private investigations, secret goals, AI weights or plans, private targets, private discards, and exact economic assets never enter public snapshots or reports. Filtering occurs in the Victory domain before presentation; renaming a private value is not sanitization.

## Outcome Receipt

Normal audit receipts use this canonical comparison order:

1. `top_k_gdp_per_minute_cents`
2. `controlled_region_count`
3. `cash_ledger_cents`

An exact three-stage tie yields co-victory. Last survivor uses the same versioned receipt envelope.

Ordinary ruined regions never trigger a cash-most victory. A cash-only planet-destruction result is allowed only when the scenario snapshot explicitly contains both `irreversible_planet_destruction_triggered=true` and `scenario_allows_cash_fallback=true`.

## Save Contract

The victory domain saves schema version 2, ruleset ID `v0.6`, current state, per-player qualification progress, sticky audit roster, remaining audit time, outcome sequence, and outcome receipt. Load validates the complete envelope before one state swap. Invalid schema, ruleset, state, roster ordering/uniqueness, timer, rankings, or impure data fails closed without mutating active state. A v0.5 fixed-depth save cannot silently resume as v0.6.

World-derived candidates, exact player assets, dynamic rule caches, checkpoint markers, and cash-disclosure projection caches are never restored from the victory save. Immediately after load, public cash authorization is closed. A fresh authoritative world snapshot must bind every roster seat to a current candidate before disclosure can reopen, preventing a previous game or pre-load runtime cache from leaking.

## Deletion Gate

Production victory code must not contain a fixed victory-depth table, depth-based requirement helpers, a failed-audit cooldown state, parallel cash-goal countdown logic, or a second region-control algorithm. Presentation may retain compatibility labels only when they read the controller's canonical result and do not recalculate eligibility.

## Evidence

`VictoryControlRuntimeBench`, `victory_control_public_projection_privacy_v06_test.gd`, and `VictoryAuditVisibilityV06Bench` cover dynamic victory behavior plus pre-audit hiding, partial authoritative disclosure, non-roster hiding, winner non-bypass, recursive privacy, stable projections, and save/load cache invalidation.
