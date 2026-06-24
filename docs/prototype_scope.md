# Prototype Scope

This Godot build converts the board-game draft into a playable real-time digital sandbox, not a final rules engine.

## Implemented as interactive systems

- Players start with 2000 chips and can act continuously instead of waiting for turns.
- A global clock advances news events, market bonuses, monster pressure, and guardian checks.
- Players can switch active operator at any time, then bet, withdraw chips, charge skills, buy skills, seize monster control, or direct monster movement.
- Player actions use short cooldowns; charged skills also have cooldowns after release.
- Keyboard shortcuts cover the common real-time loop: player selection, district selection, betting, charging, buying, monster control, and pause/resume.
- Districts can receive collapse/survive predictions, bets, market bonuses, and damage.
- Destroyed districts settle immediately: collapse predictions pay out, survival predictions lose, and the top bettor receives the district bonus.
- Unresolved districts settle as survival when a monster or guardian is defeated.
- Skill slots can be charged, expanded, and filled from a simple public skill market.
- Monster control now decays over time; the player with the highest control can direct the monster more reliably.
- Guardian actions are resolved with timed D6 checks based on the rule draft's guardian-card concept.
- Monster skills cover movement, melee/ranged damage, district damage, miasma marking, and armor-like effects.

## Deliberate simplifications

- The prototype uses 4 players and removes fixed per-round action counts.
- The board is a 3x3 district grid rather than a final physical layout.
- Many named cards are represented by reusable effect categories.
- Card upgrade chains, every guardian/monster variant, and exact forced-movement targeting are left as future balancing work.
- Art is placeholder UI only; the art production list is recorded in `docs/art_requirements.md`.

## Next useful adjustments

- Add a setup screen for player count, monster, and guardian selection.
- Replace generic skill effects with exact card-by-card data tables.
- Add a small visual minimap/animation layer for monster and guardian movement.
- Add difficulty/balance presets for event frequency, guardian aggression, and monster rampage pressure.
- Split `scripts/main.gd` into model, rules, and UI scripts after the prototype rules settle.
- Add authored sprites and card frames once the art direction is fixed.
