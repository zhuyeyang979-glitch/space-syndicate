# Space Syndicate Prototype

Godot 4 prototype for **太空辛迪加 / Space Syndicate**, based on the local rules draft and art requirement list.

## Current Prototype Scope

- 2-5 player real-time digital tabletop sandbox with a lightweight main/pause/help menu and an in-game setup panel.
- Continuous clock with pause, 1x, 2x, and 4x speed controls.
- Balance presets switch between steady, standard, and crisis pacing for event frequency, guardian aggression, monster rampage pressure, and control decay.
- Setup options choose player count, the monster roster entry, and the guardian roster entry before restarting the run.
- Setup choices are saved to a local `user://` config so the next launch keeps the last player count, monster, guardian, and balance preset.
- Guardian selection now changes the probability action model, including Jack, Ace, and Nice-style combat patterns.
- Each run builds its card pool from common cards, the selected monster's dedicated cards, and response cards tied to the selected guardian/Ultraman.
- Monster selection changes the dedicated card pool: Vaal Hazak leans into miasma bloom/reclaim while Barroth leans into charge, roar, burrow, and roll attacks.
- Guardian selection adds tailored real-time response cards, such as Jack counters, Ace prediction windows, and Nice repair-interference cards.
- Players can switch active operator at any time and immediately bet, withdraw chips, charge cards, claim a card from the selected district, seize monster control, or direct monster movement.
- Player actions now use short cooldowns so real-time play has pacing instead of button spamming.
- Charged cards are played instantly, resolve immediately, then enter short cooldown timers shown in the player panel.
- Roguelike-style generated city map: a continuous 1400m x 950m city plane is partitioned into 10-20 irregular regions, each supporting collapse/survive predictions, chip bets, bonuses, damage, settlement, and 3-4 local card choices.
- The global card list is now a run-pool reference/debug view; actual card acquisition comes from the selected district's local choices, so route and region choice matter.
- The common card pool now has more build-around options and upgrade routes for economy sustain, heat steering, control tempo, chain charging, long-range district damage, market bait, and armor sustain.
- The map view draws continuous region polygons; monster and guardian movement uses meter distances and speed, not grid steps.
- Card and skill ranges are meter-based AOE/range checks, so knockback, pursuit, and explosions should be tuned in meters.
- Monster/guardian combat loop runs on timers with probability-weighted guardian actions, autonomous monster targeting, and instantly played charged cards; there is no card turn structure in the digital prototype.
- Probability debug text exposes guardian action odds, the top monster target candidates, and the selected district's monster-target factors.
- News/market events raise district heat, bonuses, and collapse pressure while the game runs.
- Placeholder UI for the art assets listed in `docs/art_requirements.md`.

## Run

Open this folder in Godot 4.x and run `scenes/main.tscn`.

On Windows, `Launch Space Syndicate Prototype.cmd` tries to find Godot from PATH, `GODOT_EXE`, the sibling workspace `tools/godot-*` folder, or common install locations, then opens this project. If Godot is not installed yet, it opens the project folder instead.

## Keyboard Shortcuts

- `1`-`5`: select player, based on the configured player count
- `Q` / `E`: select previous/next district
- `T`: toggle the current prediction between collapse and survival
- `Y`: cycle the balance preset
- `B`: bet on selected district
- `W`: withdraw chips from selected district
- `C`: charge cards
- `X`: claim the selected district card
- `V`: seize monster control
- `G`: direct monster movement
- `Space`: pause/resume

The project is intentionally data-light and UI-driven so that later balancing and art replacement can happen without rebuilding the scene tree by hand.
