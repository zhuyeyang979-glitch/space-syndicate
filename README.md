# Space Syndicate Prototype

Godot 4 prototype for **太空辛迪加 / Space Syndicate**, based on the local rules draft and art requirement list.

## Current Prototype Scope

- 4-player real-time digital tabletop sandbox.
- Continuous clock with pause, 1x, 2x, and 4x speed controls.
- Players can switch active operator at any time and immediately bet, withdraw chips, charge skills, buy skills, seize monster control, or direct monster movement.
- Player actions now use short cooldowns so real-time play has pacing instead of button spamming.
- Charged skills have their own cooldown timers and show readiness in the player panel.
- 3x3 district board with collapse/survive predictions, chip bets, district bonuses, monster/guardian positions, damage, and destruction settlement.
- Monster/guardian combat loop runs on timers with D6 guardian actions and usable charged monster skills.
- News/market events raise district heat, bonuses, and collapse pressure while the game runs.
- Placeholder UI for the art assets listed in `docs/art_requirements.md`.

## Run

Open this folder in Godot 4.x and run `scenes/main.tscn`.

On Windows, `Launch Space Syndicate Prototype.cmd` tries to find Godot and open this project. If Godot is not installed yet, it opens the project folder instead.

## Keyboard Shortcuts

- `1`-`4`: select player
- `Q` / `E`: select previous/next district
- `B`: bet on selected district
- `W`: withdraw chips from selected district
- `C`: charge skills
- `X`: buy selected market skill
- `V`: seize monster control
- `G`: direct monster movement
- `Space`: pause/resume

The project is intentionally data-light and UI-driven so that later balancing and art replacement can happen without rebuilding the scene tree by hand.
