# Prototype Scope

This first Godot build converts the board-game draft into a playable digital sandbox, not a final rules engine.

## Implemented as interactive systems

- Players start with 2000 chips, move through an action track, and spend chips on bets or skill charging.
- Districts can receive collapse/survive predictions, bets, market bonuses, and damage.
- Destroyed districts settle immediately: collapse predictions pay out, survival predictions lose, and the top bettor receives the district bonus.
- Unresolved districts settle as survival when a monster or guardian is defeated.
- Skill slots can be charged, expanded, and filled from a simple public skill market.
- Monster control starts a combat round. If no player controls the monster during a round, the control space gains a 100-chip pot.
- Guardian actions are resolved with D6 checks based on the rule draft's guardian-card concept.
- Monster skills cover movement, melee/ranged damage, district damage, miasma marking, and armor-like effects.

## Deliberate simplifications

- The prototype uses 4 players and 2 actions per player per round.
- The board is a 3x3 district grid rather than a final physical layout.
- Many named cards are represented by reusable effect categories.
- Card upgrade chains, every guardian/monster variant, and exact forced-movement targeting are left as future balancing work.
- Art is placeholder UI only; the art production list is recorded in `docs/art_requirements.md`.

## Next useful adjustments

- Add a setup screen for player count, monster, and guardian selection.
- Replace generic skill effects with exact card-by-card data tables.
- Split `scripts/main.gd` into model, rules, and UI scripts after the prototype rules settle.
- Add authored sprites and card frames once the art direction is fixed.
