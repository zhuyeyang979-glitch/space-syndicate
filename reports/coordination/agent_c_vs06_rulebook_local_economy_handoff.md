# Agent C VS06-C12 — Player Rulebook Sync Handoff

## Status

Frozen. `docs/tabletop_rulebook_v06.md` now states the authoritative local-economy, relaxed-map, shared-window, and mandatory monster-betting rules. No production code, test, catalog, or runtime configuration was changed.

## Player-facing rules synchronized

- Explicit exact-product demand and a legal route settle before local fallback and remain the high-yield option.
- Residual isolated factory output absorbs at `min(1 unit/min, 10% effective rate)` for 1000bp value; isolated market turnover is 1 unit/min for 500bp value.
- Neutral/public market turnover contributes regional commodity GDP and no player cash.
- Remaining output goes to reachable storage or backpressure; local fallback is not unlimited self-sale.
- A generated planet guarantees at least one cross-district exact-product opportunity, without adjacency or full-source coverage.
- A future local-self-consumption modifier card is a confirmed direction but is not playable until its values and lifecycle are authored by A11.
- Regular shared windows are 30 seconds (20 planning, 5 reveal/bid, 5 lock/response); the first three are 45 seconds (35/5/5). All-ready may end early. Default submission cap is one ordinary card, raised only by an explicit role/effect field.
- Monster betting is a mandatory 15-second global freeze with no odds. A public common baseline is 5%-10% (standard 5%); players may add one percentage point at a time to a hard 20% cap. Missing responses stay at baseline and choose the monster with the least public total stake. Settlement uses `historical pool + 2 × current stakes`; winners first receive twice their own stake, then equally split the remainder. Rates, choices, and amounts are public while total cash remains hidden.
- Same-name monsters remain globally unique. Initial-summon name conflicts require private reselection so every player owns a starter; after initial summons, any player may publicly target an existing same-name monster for an anonymous upgrade without transferring ownership or owner-only benefits.
- Organization cards are a new top-level category limited to the card player's own operating rules and never enter phase-veto response. Confirmed first directions are self GDP-to-six-color-asset conversion and a personal shared-window submission increase from the default one, with organization/role effects capped at three total; these cards are explicitly not yet available.
- Organization growth is now fully stated: three persistent slots, highest Rank per family, next-window activation, hand caps 6/7/8/9, and exact monster-binding/army-command Rank I-IV gradients. Base limits remain hand 5, one Rank-II monster binding, and one Rank-II army command. Temporary suppression locks excess commands/upgrades without destroying field units.
- Cross-player monster upgrades preflight against the target monster's current player's visible binding permission; an over-Rank attempt is rejected before anonymous submission is accepted and the card stays in hand.
- Dynamic region-control, Top-K GDP, qualification, and audit formulas are unchanged. The three suggested progress bars are presentation only.

The timing ruling supersedes the earlier 8-second/three-card shared window. The final betting ruling supersedes voluntary betting, odds, highest-odds auto-selection, no-raise betting, pure equal-split pooling, and proportional payout. `docs/rules_summary.md` was not edited because it is a legacy ruleset summary rather than a suitable v0.6 companion; partially patching it would leave unrelated obsolete player rules presented as current.

## Static evidence

- Referenced v0.6 directive/development-plan links exist.
- Markdown diff check passed.
- Stale exact phrases for the 8-second shared window, three-card default, voluntary/odds betting, cancelled raises, pure pool equal-split, proportional payout, and production-plus-demand-as-an-absolute-GDP-gate: 0 matches.
- Required 30/45/15-second, one-card, 5%-10% baseline, 1-point raises, 20% cap, doubled current stakes, winner self-double plus remainder split, organization gradients, local fallback, neutral cash, backpressure, relaxed-map, and unchanged-victory terms are present.

## Lessons for other agents

- **Invariant:** remote explicit demand consumes claims first; local production/market fallback only sees residual capacity.
- **Failed approach:** requiring paired supply/demand for all GDP created dead starts; requiring every source to have direct demand overconstrained map generation.
- **Stable API:** player rules describe receipt outcomes and caps, while CommodityFlow remains the sole economic owner.
- **Test oracle:** remote allocation must exclude local double counting; residual factory and market caps are 1 unit/min with 1000bp/500bp values and neutral cash remains zero.
- **Integration trap:** the new 30/45-second and mandatory 15-second windows are formal rules but this documentation task does not prove runtime/UI cutover.
- **Reusable pattern:** state priority, cap, value, ownership, and overflow behavior together so a fallback cannot become an unlimited sink.
- **Stale evidence:** 8-second shared play, three ordinary cards per window, voluntary betting, and C9 100% direct map coverage are superseded.
- **Next dependency:** A11 must author the modifier-card values/lifecycle; runtime owners/UI must separately implement the newly ruled timing, doubled-stake mandatory bet, ownership-safe monster upgrade, and organization-card growth before claiming production readiness.
