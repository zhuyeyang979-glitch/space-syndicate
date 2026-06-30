# Balance Audit Snapshot

This note is the current tuning map for the playable PVE prototype. It is meant for development, not for the player-facing rules page.

## Current data snapshot

Measured from `scripts/main.gd` on the current branch:

- 24 public alien role cards.
- 6 AI personality profiles.
- 46 total products, including 12 ocean products.
- 239 static skill/card entries, plus generated monster-card entries in the shared card codex.
- 22 complete static I-IV rank ladders.
- 28 military-force cards: 行星防卫军 plus air, land, and ocean forces.
- 12 product-futures cards: commodity long/short and warehouse stockpile lines.
- 12 city-GDP derivative cards: buy-up, short, and disaster-insurance lines.
- 7 area trade-contract cards.
- 6 news-event cards and 8 weather-control cards.
- 4 card-counter cards.
- 8 direct hand-interaction cards across 拆牌/牵牌 style effects.

## Balance standard for the next pass

The prototype should not balance by making every route equally strong in every situation. The healthier target is:

- Each major route has a clear money engine.
- Each route has at least one visible risk or public inference clue.
- Each route has at least one counterplay family.
- Rank I should be frequent and understandable.
- Rank II should improve efficiency, range, or duration.
- Rank III should make the route feel like a plan, not a one-off.
- Rank IV can be dramatic, but must remain gated by product flow, timing, target choice, anonymity risk, or counter cards.

## Major route audit

| Route | Current support | Main risk | Next balancing need |
| --- | --- | --- | --- |
| City GDP growth | City financing, product/demand shifts, temporary orders, route-flow buffs, contracts | Can snowball if early city remains untouched | Keep GDP boosts readable through breakdown; add more targeted city defense and city-specific sabotage tests |
| Contract economy | Supply/demand contract families, punitive refusal terms, temporary city contracts | Some contracts can feel abstract without clear route visualization | Make contract acceptance/rejection consequences more visible in economy overview and card previews |
| Finance/GDP speculation | City buy-up, city short, disaster insurance, commodity futures, warehouse stockpile | High leverage can become “cash from nowhere” if not tied to visible GDP/price movement | Keep payouts tied to real-time windows; add more tests around warehouse destruction and public clues |
| Monster pressure | Monster cards, lures, takeover, resource preferences, monster wagers | Randomness can feel unfair if target reasons are hidden | Continue exposing attraction reasons, resource matches, and action text without revealing owner |
| Military command | Defense army, fighter, bomber, tank, missile, submarine, warship, reusable commands | Could overlap too much with monster destruction if not bounded | Keep movement non-crushing; reserve area HP damage for explicit strike commands; tune GDP pressure by unit role |
| Intel/supply | Owner lens, card trace, contract trace, remote supply, global purchase | Too much truth can collapse the anonymous inference game | Prefer limited charges, private clues, and money stakes over full public reveal |
| Direct interaction | 星链拆解, 影仓牵引, 产权冻结, 轨道齐射, 相位否决 | Player-target effects can feel punitive if too cheap | Keep strong effects gated by product flow, public target result, and counter windows |
| Weather/news | Forecasts, route weather cards, heat/crisis/market rumors | Passive noise would be confusing | Keep news card-made only; keep weather forecast public and limited to 1-5 regions |
| Commodity/ocean economy | 46 goods with terrain profiles; ocean goods support fish, algae/fiber, black oil, tidal power, crystal, coral; run card supply now filters fixed-product cards and monster-resource cards by goods present on the generated planet, then local district supply requires matching nearby products/demands | Goods may still feel like names unless their art, regional source, and card route are visible enough in play | Tune distribution/rarity so each planet has several viable product routes without flooding every district with the same goods |

## Immediate numeric watchlist

1. Military-force cards have strong identity now, but their GDP pressure numbers need simulation:
   - Fighter should be a low-damage fast responder.
   - Bomber should be the primary city-GDP pressure unit.
   - Tank should be the durable land defender.
   - Missile should be range-gated and position-readable.
   - Submarine and warship should matter most on ocean trade maps.
2. Commodity futures and warehouse stockpile are now strategically interesting, but the payout unit and stockpile unit counts need long-run tests against ordinary city income.
3. Direct hand pressure should create inference clues and disruption, not simply delete the best player’s options every time.
4. Role cards now have a separate role-budget audit. The current role pool is broad enough, but the next tuning pass should watch high-leverage public passives:
   - Extra purchase range can be very strong on large planets.
   - Monster or military control-limit bonuses are board-state dependent.
   - Intel charges are powerful only if the cash reward and guessing stakes justify them.
   - Monster-card-as-counter is powerful only during the fixed phase-response window.

## AI balance targets

The current 6 AI profiles should cover at least these money-facing styles:

- City growth / GDP snowball.
- Contract and route GDP.
- Finance and commodity speculation.
- Monster pressure.
- Direct disruption.
- Intel and supply control.

Next AI tuning should check whether each profile actually does its thing in long runs:

- 拓荒型AI should build and protect high-GDP cities.
- 套利型AI should buy commodity/GDP speculation when the map supports it.
- 破坏型AI should use direct interaction, route sabotage, monsters, and shorts against leaders.
- 驯怪型AI should create monster pressure without pretending to control monsters permanently.
- 合约型AI should build supply/demand links and accept/reject deals sensibly.
- 情报型AI should use traces and owner guesses as a money route, not just as flavor.

## Test gaps to close next

- Covered now: warehouse stockpile loses its stored value when the warehouse city is destroyed, while ordinary non-warehouse futures remain.
- Covered now: commodity futures settle only after their real-time holding window and pay from actual product price movement, not from abstract economy cycles.
- Covered now: military movement and monster-attack commands do not damage districts/routes; district and route damage is reserved for explicit strike commands.
- Covered now: the eight-seat AI smoke run reports route-tagged decision samples per AI profile, verifies every profile gets route actions, and checks that multiple core routes plus primary-profile routes appear.
- Covered now: role setup resolves duplicate public-role selections into unique seats, random AI roles resolve without duplicates at run start, and every real role card exposes hidden balance-budget metadata for audit tests.
- Covered now: generated-run card supply respects planet goods. Fixed-product cards enter only when their required product exists, monster cards enter by resource focus with a safe fallback, and district choices are audited against local products/demands so unavailable goods do not leak into purchasable cards.
