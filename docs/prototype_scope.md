# Prototype Scope

This Godot build converts the board-game draft into a playable real-time digital sandbox, not a final rules engine.

## Implemented as interactive systems

- A lightweight main/pause menu now wraps the prototype, while the setup panel configures 2-5 players, the monster roster entry, the guardian roster entry, and the active balance preset before restarting the run.
- Guardian roster choices now load separate probability action models for 机械杰克, 机械艾斯, and 纳伊斯, including abstracted repair/support effects for 纳伊斯.
- Each run now builds a run-specific card pool from common cards, the selected monster's dedicated cards, and response cards tied to the selected guardian/Ultraman.
- Monster roster choices load differentiated dedicated card pools: 尸套龙 gains expanded miasma bloom/reclaim tools, while 土砂龙 gains charge upgrades, roar delay, burrow upgrades, and roll attacks.
- Guardian roster choices add tailored real-time response cards, such as 机械杰克 counter windows, 机械艾斯 prediction/armor windows, and 纳伊斯 repair-interference tools.
- Players start with 2000 chips and can act continuously instead of waiting for turns.
- A global clock advances news events, market bonuses, monster pressure, and guardian probability actions.
- Balance presets now tune event/market cadence, news heat, monster district damage, guardian movement/damage, and monster-control decay for steady, standard, or crisis-length sessions.
- Players can switch active operator at any time, then bet, withdraw chips, charge cards, claim cards from the selected district, seize monster control, or direct monster movement.
- Player actions use short cooldowns; charged cards are played instantly, resolve immediately, then enter cooldown, without a card-turn structure.
- Keyboard shortcuts cover the common real-time loop: player selection, district selection, betting, charging, buying, monster control, and pause/resume.
- Betting now shows the active collapse/survival prediction preview, estimated payout, and district collapse pressure before the player commits chips.
- Each run generates a larger roguelike-style city map: 10-20 irregular regions partition a continuous 1400m x 950m city plane.
- The visible map emphasizes continuous region polygons; it no longer exposes or relies on square cells for movement/range gameplay.
- Districts can receive collapse/survive predictions, bets, market bonuses, damage, and 3-4 local card choices for players to weigh.
- Run-specific monster and guardian cards are seeded into district choices first, then common cards fill each district to 3-4 options.
- Destroyed districts settle immediately: collapse predictions pay out, survival predictions lose, and the top bettor receives the district bonus.
- Unresolved districts settle as survival when a monster or guardian is defeated.
- Card slots can be charged, expanded, upgraded, replaced, and filled from the selected district's local card choices; the current run's card pool remains visible as a reference/debug list.
- Monster control now decays over time; the player with the highest control can direct the monster more reliably.
- Guardian actions are resolved with timed probability simulation based on the rule draft's guardian-card concept.
- Uncontrolled monster movement now uses a weighted target model instead of a deterministic best-target pick, favoring panic, bonuses, bets, proximity, and miasma pressure.
- Probability explanations now surface in the UI: guardian action percentages, top monster target candidates, and the selected district's monster-target factors.
- Monster cards now support several build routes: betting economy, market manipulation, control tempo, charge acceleration, district destruction, long-range pressure, mobility burst, miasma pressure, and armor sustain.
- The common card pool has been expanded with additional economy, heat-steering, control, chain-charge, long-range destruction, and armor-upgrade cards.

## Deliberate simplifications

- The prototype supports 2-5 players but still removes fixed per-round action counts.
- Movement, pursuit, card range, AOE, and knockback-style tuning are expressed in meters instead of grid steps.
- Many named cards are represented by reusable effect categories.
- Full card-chain balancing, every guardian/monster variant, and exact forced-movement targeting are left as future balancing work.
- Art is placeholder UI only; the art production list is recorded in `docs/art_requirements.md`.

## Next useful adjustments

- Continue replacing remaining generic monster effects with exact card-by-card data tables.
- Add a small visual minimap/animation layer for monster and guardian movement.
- Split `scripts/main.gd` into model, rules, and UI scripts after the prototype rules settle.
- Add authored sprites and card frames once the art direction is fixed.
