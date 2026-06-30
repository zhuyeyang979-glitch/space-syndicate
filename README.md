# Space Syndicate Prototype

Godot 4 prototype for **太空辛迪加 / Space Syndicate**, based on the local rules draft and art requirement list.

## Current Prototype Scope

- 3-8 seat PVE roguelike sandbox with a lightweight main/pause menu. Each run can include 2-7 AI opponents plus at least one human/local player seat.
- Continuous real-time clock with pause for menus/rules inspection. The player-facing game no longer exposes 1x/2x/4x time-multiplier controls because card play, auction windows, and monster actions are meant to resolve in live time.
- News, market, and monster pressure now use one fixed real-time balance profile. The normal player UI exposes no pacing presets, forced monster/event advance buttons, or manual settlement shortcut.
- The main menu's 开局准备 branch previews total seats, AI opponent count, per-player alien role-card selection, each role's opening passive, each starter monster card face, and a first-summon summary showing unrestricted access, bound-skill rewards, and the card-buying radius before confirming a new run. A confirmed new run begins with no monsters on the planet. Eight selectable alien syndicate role cards now provide working positive passives: opening cash, starter-monster HP/speed/duration/bound skills, periodic cash from a named product, a free extra regional card, or cash when an owned monster upgrades. Later monster cards can summon more monsters with no field cap and print their own HP, movement, field duration, and summon-region restriction on the card; different monsters can require generic, land, or ocean monster-zone landing rules. There is no persistent player-controlled monster: all monsters auto-move and auto-act.
- Runtime, local settings, save data, and codex navigation contain no legacy four-monster lineup or preselection state. Only each player's starter-card choice and the automatic monsters actually summoned by played cards remain.
- While the field has no monsters, the active player's panel shows a first-summon prompt with the current landing district and a direct "在选区首召" action for the starter monster card.
- The main game view is intentionally minimal: a large planet map, the anonymous card track, and the active player's hand. The hand header only keeps compact player/cash/bid context; role details, city economy, cash paths, ledgers, and region facts live in the menu/codex/overview branches.
- The map uses a spherical world model. Zooming out shows the planet in space with region boundaries projected onto the globe; zooming in shows a local XY-style flat projection of the same spherical surface. A map button opens the map in fullscreen.
- The main menu includes 局势排名, 经济总览, 情报档案, 新手引导, 游戏规则, and a unified 图鉴 branch. 图鉴 opens submenus for 角色图鉴, 怪兽图鉴, 卡牌图鉴, 商品图鉴, and 区域图鉴.
- The menu can save and load the current run locally, not only setup preferences.
- Monster setup is no longer a main-menu branch. The read-only 怪兽图鉴 shows each monster's actions, action probabilities, movement speed, linked monster card, fixed skills, resource focus, positive economy weather, move-crush damage, knockback-collision damage, and procedural temporary monster art. It now opens as a responsive thumbnail album with hover/single-click previews, double-click detail entry, and detail-only previous/next navigation.
- The 角色图鉴 shows all eight alien syndicate role cards with procedural temporary card faces, species traits, working positive passives, starter monster cards, and links into the matching monster/card codex entries. Its card stat line exposes the concrete cash/product/card/upgrade trigger instead of leaving the benefit only in prose. The single shared 卡牌图鉴 includes monster cards rather than splitting them into a separate branch, and filters cards into monster, economy, business/contract, combat/command, supply/lure, and other subcategories. It now opens as a responsive thumbnail album: the grid size adapts to viewport space, hovering or single-clicking a card shows a detail preview, double-clicking enters the full detail page, and the full detail page alone exposes previous/next card navigation plus a return-to-thumbnails action. 商品图鉴 follows the same album pattern: it opens as a responsive thumbnail grid, hover/single-click previews price, supply/demand, weather, and product-filtered city clues, double-click enters a product detail page, and detail-only previous/next navigation can return to thumbnails. 区域图鉴 shows public region details, HP/damage, latest monster damage source, route load, monster attraction reasons, local goods, available paid cards, city temporary contracts, city route-flow acceleration, and city public status without revealing hidden owners.
- Players switch active operator views, secretly urbanize empty districts, privately mark who they think owns an unknown city, claim a card from the selected district, or play a card from hand.
- Player actions now use short cooldowns so real-time play has pacing instead of button spamming.
- Cards do not charge. District cards are bought with player funds only from a monster's current region or an adjacent region; the current region costs 80% and adjacent regions use the I-rank base price. A submitted non-persistent card leaves the hand as soon as it enters the anonymous track, then resolves once after public display and can be reacquired from district supply.
- Reacquiring a card already owned upgrades it when a next rank exists.
- Card prices form a gradient by the rank-I effect's economic power, with explicit base/advanced/high/flagship tiers and a district-access discount. Ranks I-IV all retain the rank-I purchase price. Player panels track build spend, card spend, card income, last-cycle income, and recent cash movement.
- Playing a card normally checks a required product and flow amount supplied by the player's cities without consuming that product. Some cards also require an extra cash payment; monster cards can add a cash surcharge based on how many monsters are already on the field. Cards that require a monster target ask for that target after the player chooses to play them.
- Economy cards support price pumping, short selling, market stabilization, city-product upgrades, city product-line shifts, demand redesign, route sabotage, supply-chain insurance, product-growth catalysts, route-flow accelerators, sustained product contracts such as 远期采购, 期货套保, and 包销协议, and temporary city order/contract deals such as 短期订单, 军需临单, and 星际会展. They change current prices, volatility, product lists, demand lists, product levels, route damage, sustained product demand/supply pressure, product growth multipliers, city logistics multipliers, temporary contract income, and later business-cycle income rather than acting as flavor-only cards.
- Summoned monsters can apply positive economy weather to their preferred products while they are part of the run, such as faster positive price growth or faster commercial flow on related routes. Temporary cards can stack above that weather for a limited number of business cycles, and product-contract cards add visible sustained demand/supply pressure with their own countdown.
- Player panels display a compact recent cash path, tracked-window net change, and a recent economy ledger so the run's economic gradient remains visible while spending, card income, battle rewards, commercial actions, and city income accumulate.
- Cards that need a monster target pause before entering the shared lane and ask for a target after the player presses play. One-shot lure cards such as 诱导电波 can point the chosen monster's next automatic movement toward the current selected district, but the monster returns to its own probability table immediately afterward. Every submitted card then enters the anonymous card-resolution system: the first card in an empty lane opens a 0.5-second simultaneous-play window, a lone card proceeds to a 5-second public display, and multiple cards open one 5-second anonymous auction before the whole batch order locks.
- Anonymous card auctions show bid amounts without revealing bidders or owners. The locked batch resolves in bid/clockwise order and does not reopen auctions mid-batch. Cards submitted after the 0.5-second intake closes or while that batch is displaying are accepted into a visible next-batch waiting area; once the current batch clears, all waiting cards enter one new auction together (or a lone waiting card goes straight to its own display). A locked bid is privately paid to the previous resolved card's owner when one exists, including across a batch boundary.
- The top card track records anonymous history/current/pending cards, supports horizontal dragging, and lets the current player wager on a card's owner. Correct guesses publicly attach the owner label to that card; wrong guesses pay the true owner privately without revealing the label.
- Public card events show the card, target, and result but never name the player who played it unless a later correct owner guess reveals that card's owner label. During live play, the economy overview exposes only the current player's exact cash, assets, income, cash path, and ledger; rival economies remain hidden until final settlement. The 情报档案 branch collects the current player's city-owner marks, per-mark confidence and reason, card-owner betting state, monster cash clues, and recent city public clues without revealing hidden truth early; it ranks city leads by investigation priority, offers direct private city-mark buttons, and jumps into the related region, card, monster, product, or economy pages.
- The selected district's current supply choice is kept compact on the main screen, while hand cards and codex entries use the full shared card art.
- Roguelike-style generated world map: a 1400m x 950m spherical surface is partitioned into 10-20 irregular land/ocean regions, each supporting damage, transport, local cards, and where valid urbanization.
- Land regions initially produce one good and have one local demand; ocean regions produce no goods and mainly serve as lower-cost shipping lanes. Anonymous contract cards can later add, replace, or remove supply and demand.
- Urbanizing a land district creates a visible building cluster with one initial produced good and one initial demanded good. The owner is only revealed in that player's view; rivals see an anonymous city plus their own private guess marker.
- Area contract cards require the player to click/select a supply region and a demand region before play. The first five-second card window only publicly displays those preselected endpoints, product, reward, and penalty; after that reveal, the target city's true owner gets a separate five-second accept/reject window that remains on their screen without blocking other card plays; timeout counts as rejection. The current pool includes selected-product, fixed 环晶电池, automatic-match, multi-product replacement, and punitive refusal contract families.
- During business cycles, AI syndicates can secretly urbanize profitable empty land. These new city clusters appear publicly as anonymous buildings, spend AI funds, and give the active player new ownership mysteries to mark and infer.
- AI syndicates also perform anonymous commercial actions during business cycles: they can raise prices around products they benefit from or sabotage competing cities' trade routes. These actions leave a short structured public clue history on city records—time, clue type, product keywords, and text—without revealing ownership. AI seats carry a personality profile and keep recent decision samples with action type, target, score, and reason, establishing the first training/debugging hook for smarter later behavior.
- Every business cycle, the product market refreshes current prices from supply, demand, and disrupted routes. Surviving cities earn income from production and fulfilled demand routes using those current prices. Rival cities that sell the same products compete for customers and reduce one another's income.
- City income is visible as a breakdown of production income, fulfilled-route income, permanent bonuses, temporary contract income, competition penalties, and route-disruption penalties in the region codex and economy overview.
- Players can show a selected product's trade routes on the map. Destroying regions along an existing route creates shipping disruption that reduces affected city income.
- Destroyed cities stop earning. At settlement, surviving value and intelligence results are converted into money; victory is decided only by final money.
- The standings menu previews current score, active city assets, potential cycle income, and cumulative business income.
- The economy overview menu summarizes product hot/cold rankings, active economy weather, route-income prospects, and the current player's private cash/assets/income/path/ledger while hiding rival economy totals until final settlement. The intel dossier explains how guesses convert to final money and groups the evidence players use to decide which cities, cards, and monsters likely belong to whom; its clue buttons can open the matching codex page and return directly to the dossier.
- A local run save stores the generated map, players, cities, cards, monsters, timers, logs, and scoring state for later continuation.
- Monster movement, card ranges, AOE, and knockback use meter distances on the spherical surface, not grid steps.
- Monster markers use procedural temporary portrait tokens, animate between world positions, and leave movement cues so recent movement is visible at a glance.
- Monster actions appear as text callouts on the map instead of being represented only by movement. Resource matches can stack, so a district with several attractive goods can pull multiple monsters together.
- Monster cards use Roman-numeral ranks I-IV. Higher-rank summoned monsters keep their card's HP, movement, and duration rules, and their automatic action weights tilt toward later, more dangerous named actions.
- Monsters now damage region HP through movement crush, resource drain, combat actions, and knockback collisions. When monsters meet within encounter range they use named actions from their own action table; knockback can damage the route/landing regions and destroy cities through the same region HP track.
- Card and skill ranges are meter-based AOE/range checks, so knockback, pursuit, and explosions should be tuned in meters.
- Commercial news raises district heat, while active cities, contested products, trade-route load, and monster resource preferences shape monster attention.
- Procedural temporary UI art for cards and monsters, with final authored assets still tracked in `docs/art_requirements.md`.

## Run

Open this folder in Godot 4.x and run `scenes/main.tscn`.

On Windows, `Launch Space Syndicate Prototype.cmd` tries to find Godot from PATH, `GODOT_EXE`, the sibling workspace `tools/godot-*` folder, or common install locations, then opens this project. If Godot is not installed yet, it opens the project folder instead.

## Smoke Test

The prototype includes a headless smoke test that loads the main scene, starts a four-seat run with three AI opponents, verifies alien role cards and their starter monster cards, plays four starter monster cards for battle coverage, verifies starter and later-summon restrictions plus timed monster departure, verifies the generated land/ocean map, builds a city, checks AI anonymous auto-expansion, commercial clues, and decision samples, exercises economy-card price/product-line/demand/industry/route/product-growth/route-flow/temporary-contract effects, saves and reloads the run from a test-only slot, and instantiates the temporary card and monster art views:

```powershell
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/smoke_test.gd
```

## Keyboard Shortcuts

- `1`-`8`: select player/seat, based on the configured player count
- `Q` / `E`: select previous/next district
- `B`: urbanize the selected empty district
- `G`: cycle the player-owner guess for the selected city
- `M`: save or clear the active player's private owner guess
- `R`: show or hide the selected product's trade routes
- `T`: cycle the visible trade-route product
- `C`: cycle the selected district supply card
- `X`: claim the selected district card
- `Space`: pause/resume
- `Esc`: open/close menu

The project is intentionally data-light and UI-driven so that later balancing and art replacement can happen without rebuilding the scene tree by hand.
