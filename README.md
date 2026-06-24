# Space Syndicate Prototype

Godot 4 prototype for **太空辛迪加 / Space Syndicate**, based on the local rules draft and art requirement list.

## Current Prototype Scope

- 4-player digital tabletop sandbox.
- Action track with betting, skill charging, skill acquisition, market manipulation, first-player control, and monster control.
- 3x3 district board with collapse/survive predictions, chip bets, district bonuses, monster/guardian positions, damage, and destruction settlement.
- Monster/guardian combat loop with D6 guardian actions and usable charged monster skills.
- Placeholder UI for the art assets listed in `docs/art_requirements.md`.

## Run

Open this folder in Godot 4.x and run `scenes/main.tscn`.

The project is intentionally data-light and UI-driven so that later balancing and art replacement can happen without rebuilding the scene tree by hand.
