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

The current branch now has an automated development-route pressure audit. It checks the six required AI-baseline routes — city growth, contract route, finance speculation, monster pressure, intel/supply, and direct interaction — for card coverage, complete I-IV ladders, money/disruption/protection/intel pressure, gates, public inference clues, counterplay, and at least one primary AI profile.

| Route | Current support | Main risk | Next balancing need |
| --- | --- | --- | --- |
| City GDP growth | City financing, product/demand shifts, temporary orders, route-flow buffs, contracts | Can snowball if early city remains untouched | Keep GDP boosts readable through breakdown; add more targeted city defense and city-specific sabotage tests |
| Contract economy | Supply/demand contract families, punitive refusal terms, temporary city contracts | Some contracts can feel abstract without clear route visualization | Make contract acceptance/rejection consequences more visible in economy overview and card previews |
| Finance/GDP speculation | City buy-up, city short, disaster insurance, commodity futures, warehouse stockpile | High leverage can become “cash from nowhere” if not tied to visible GDP/price movement | Commodity futures now have field-driven leverage/gate/clue audits; next pass should compare long-run AI profits across city GDP, commodity futures, and monster pressure routes |
| Monster pressure | Monster cards, lures, takeover, resource preferences, monster wagers, ecology identity audit | Randomness can feel unfair if target reasons are hidden | Continue exposing attraction reasons, resource matches, and action text without revealing owner; future monsters must pass movement/resource/action/bound-skill/art differentiation checks |
| Military command | Defense army, fighter, bomber, tank, missile, submarine, warship, reusable commands | Could overlap too much with monster destruction if not bounded | Keep movement non-crushing; reserve area HP damage for explicit strike commands; tune GDP pressure by unit role |
| Intel/supply | Owner lens, card trace, contract trace, remote supply, global purchase | Too much truth can collapse the anonymous inference game | Prefer limited charges, private clues, and money stakes over full public reveal |
| Direct interaction | 星链拆解, 影仓牵引, 产权冻结, 轨道齐射, 相位否决 | Player-target effects can feel punitive if too cheap | Keep strong effects gated by product flow, public target result, and counter windows |
| Weather/news | Forecasts, route weather cards, heat/crisis/market rumors | Passive noise would be confusing | Keep news card-made only; keep weather forecast public and limited to 1-5 regions |
| Commodity/ocean economy | 46 goods with terrain profiles; ocean goods support fish, algae/fiber, black oil, tidal power, crystal, coral; run card supply now filters fixed-product cards and monster-resource cards by goods present on the generated planet, then local district supply requires matching nearby products/demands | Goods may still feel like names unless their art, regional source, and card route are visible enough in play | Tune distribution/rarity so each planet has several viable product routes without flooding every district with the same goods |
| Card supply readability | Card codex, current-run pool, and district supply are now surfaced as 图鉴全集 / 本局星球牌池 / 区域补给 | If the UI slips back into development terms like generic market/skill pool, players may think every codex card is purchasable | Keep card detail, hover, and district purchase UI aligned on these three player-facing layers |

## Immediate numeric watchlist

1. Covered now: military-force cards have an automated identity audit that checks GDP pressure, pressure duration, explicit route damage, mobility, range, durability, and land/ocean multipliers:
   - Fighter remains a low-GDP-pressure fast responder.
   - Bomber remains the primary city-GDP pressure unit.
   - Tank remains the durable land defender with weak ocean mobility.
   - Missile remains range-gated and position-readable.
   - Submarine and warship remain strongest on ocean trade maps.
2. Covered now: core development routes have an automated pressure audit. City growth, contract route, finance speculation, monster pressure, intel/supply, and direct interaction must each maintain enough cards, at least one complete I-IV ladder, money/disruption/intel/protection pressure, gates, public clues, counterplay, and AI profile coverage.
3. Covered now: commodity futures and warehouse stockpile have an automated balance audit that compares leverage against ordinary city-income reference values and checks that stronger payouts carry real-time windows, product-flow gates, public product/warehouse clues, and warehouse destruction risk.
4. Covered now: direct interaction cards have an automated balance audit. The four I-IV families must keep pressure, gates, public clues, and counter availability aligned, so hand pressure creates disruption plus inference clues instead of becoming cheap invisible deletion.
5. Covered now: monster ecology has an automated differentiation audit. Each monster must keep movement ecology, resource focus, economy hook, temporary art profile, action identity tags, late-rank probability shift, and I-IV bound-skill ladder coverage.
6. Covered now: AI endgame victory-race pressure is field-driven instead of card-name scripted. Build, buy, play, and anonymous business candidates can receive hidden `victory_race_*` metadata for breaking another player's countdown, protecting a lead, last-push catch-up, or racing toward the cash goal. This should make late-game AI more decisive without exposing its route buckets to the player.
7. Role cards now have a separate role-budget audit. The current role pool is broad enough, but the next tuning pass should watch high-leverage public passives:
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
- Endgame behavior should visibly change when the cash goal or countdown matters: leaders protect and lock value, trailing players attack the leader's GDP/route base or take higher-leverage financial bets, and close contenders mix defense with targeted pressure.

Current automated runtime guards: the eight-seat smoke run now calls `_ai_live_route_balance_report()`, `_ai_product_route_bridge_report()`, and `_ai_profile_strategy_identity_report()` after AI opening, city building, buying, playing, business actions, cashflow, and primary-route exercises. It also exercises explicit leader/trailer/endgame scenarios for `victory_race_*` scoring. These reports are internal-only. The first checks live route diversity, money progress, primary-route hits, and multiple action kinds. The second checks that hidden AI samples actually bridge product ecology, focus products, route-plan products, route stages, development routes, and policy families such as buying, playing, anonymous commerce, contracts, futures, weather, direct interaction, monster pressure, military, or intel. The third checks that each simulated AI personality expresses its own route and action-family identity instead of collapsing into one generic opponent, and now also verifies that the real scoring layer produced `profile_signature_bonus` samples for every simulated profile. The phase-policy check now additionally verifies that a trailing AI can enter `break_countdown` pressure against a leader and a leading AI can enter `protect_lead` defense. Together they close the gap between “card fields say the route exists” and “AI actually connects products, cards, routes, personality, finale pressure, and economy in a simulated run.”

## Test gaps to close next

- Covered now: warehouse stockpile leaves public but anonymous clues on the product and city surfaces: product status/codex show active anonymous futures direction, nearest expiry, and warehouse count; the warehouse city clue shows product and units without revealing the owner. Destroying that city clears only the warehouse stockpile while ordinary non-warehouse futures remain.
- Covered now: commodity futures settle only after their real-time holding window and pay from actual product price movement, not from abstract economy cycles.
- Covered now: commodity futures balance is audited from card fields. The smoke test verifies 商品看涨, 商品看跌, and 港仓囤货 all have I-IV ladders, real seconds, non-regressing leverage/gate gradients, product-flow gates, public clues, ordinary-futures exposure caps, and higher warehouse exposure only when tied to warehouse-city risk.
- Covered now: temporary economy durations are audited as real seconds. City contracts, product contracts, product-growth boons, route-flow boons, GDP derivatives, and commodity futures expose `*_seconds` fields; old `*_turns` fields are treated as compatibility mirrors in tests.
- Covered now: military movement and monster-attack commands do not damage districts/routes; district and route damage is reserved for explicit strike commands.
- Covered now: the eight-seat AI smoke run reports route-tagged decision samples per AI profile, verifies every profile gets route actions, and checks that multiple core routes plus primary-profile routes appear.
- Covered now: role setup resolves duplicate public-role selections into unique seats, random AI roles resolve without duplicates at run start, and every real role card exposes hidden balance-budget metadata for audit tests.
- Covered now: generated-run card supply respects planet goods. Fixed-product cards enter only when their required product exists, monster cards enter by resource focus with a safe fallback, and district choices are audited against local products/demands so unavailable goods do not leak into purchasable cards.
- Covered now: the player-facing card codex explains the same supply logic with three layers — 图鉴全集, 本局星球牌池, and 区域补给 — backed by `_card_supply_layer_report()`. The smoke test checks layer counts and ensures the UI describes window-lock purchase rules instead of exposing old development terminology.
- Covered now: individual card pages and hover tooltips also show the card's current supply layer through `_card_supply_layer_for_card()`. The smoke test checks that cards already placed in district choices display `区域补给`, so the codex no longer behaves like a vague always-buyable market.
- Covered now: product ecosystem readability is audited by `_product_ecosystem_report()`. The product codex thumbnail page now shows current-run land/ocean goods, production/demand slots, route/category distribution, strategy opportunities, fixed-card hooks, monster-focus hooks, and profile/art completeness before the player opens individual product details.
- Covered now: AI product-route bridging is audited by `_ai_product_route_bridge_report()` inside the eight-seat smoke run. The test verifies all AI seats produce product-linked samples, at least four goods appear across hidden decisions, route stages and development routes are represented, policy families are diverse, and some samples align the chosen product with the AI's economic focus or route-plan product. This guard stays out of player-facing UI.
- Covered now: AI personality identity is both scored and audited. `_ai_profile_signature_bonus_for_candidate()` adds a medium-strength hidden bias to build, business, buy, and play candidates from each profile's preferred routes and signature action families; `_ai_profile_strategy_identity_report()` verifies six simulated personality profiles, identity-ready samples for each, at least five primary routes, at least four expected action families, at least three signature action families, and real `profile_signature_bonus` hits for every simulated profile. This is a guard against all AI profiles degenerating into one generic policy while keeping hidden AI scoring out of player pages.
- Covered now: AI finale pressure is scored and audited. `_ai_victory_race_bonus_for_candidate()` adds hidden candidate pressure for breaking another player's countdown, protecting a lead, making a last-push catch-up, or racing toward the cash target; smoke verifies these fields on both trailing sabotage and leading protection scenarios without exposing the AI's route buckets in player UI.
- Covered now: military identity balance is audited from the card data. The smoke test verifies each military family has I-IV cards, non-regressing rank gradients, fighter mobility, bomber GDP pressure, missile range, tank durability/terrain weakness, ocean-force sea mobility, and route-damage boundaries.
- Covered now: direct-interaction balance is audited from card fields. The smoke test verifies 星链拆解, 影仓牵引, 产权冻结, and 轨道齐射 all have I-IV ladders, non-regressing pressure/gates, product-flow gates, public target/result clues, and counter-window support.
- Covered now: core development-route pressure is audited from card fields. The smoke test verifies city growth, contract route, finance speculation, monster pressure, intel/supply, and direct interaction all have enough card coverage, at least one full I-IV ladder, field-driven money or disruption value, gates, public clues, counterplay, sample cards, and AI profile coverage.
- Covered now: the AI strategy-intent test now uses explicit scenarios instead of relying on incidental cash-goal scale. A damaged leading route must trigger `defend_routes`; a trailing AI facing a rich competing city must trigger `disrupt_competitors`; opening growth remains `grow_focus`.
- Covered now: live AI route balance is audited inside the eight-seat smoke run. The test verifies all seven AI seats produce route-tagged samples, at least six show money progress, at least four core routes appear in live samples, at least four AI seats hit their primary route, and action samples contain at least three distinct action kinds.
- Covered now: monster ecology differentiation is audited from the monster roster and generated monster technique cards. The smoke test verifies at least eight monsters, flying/ocean/land movement coverage, a broad product-focus pool, distinct action signatures, action identity tags, economy hooks, temporary art, late-rank probability shifts, and complete bound-skill ladders.
- Covered now: monster ecology identity is visible in the player-facing bestiary without exposing hidden AI route data. The smoke test verifies the thumbnail overview, hover preview, and detail page all surface movement ecology, product preference, action role, and bound-skill growth as readable TCG-style cards.
