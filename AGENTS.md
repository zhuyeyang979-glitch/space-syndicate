# AGENTS.md

## Project Identity

This repository is the Godot 4 prototype for **太空辛迪加 / Space Syndicate**.

The project is a real-time, PVE roguelike, hidden-information digital board game about alien syndicates, anonymous card play, monster pressure, city GDP, commodity routes, contracts, wagers, and inference.

The current product goal is not a generic TCG engine. The goal is to make this prototype **human-playable against AI**, with UI and flow moving toward a polished commercial board-game adaptation. Terraforming Mars, Gaia Project, Through the Ages-style card rails, modern deckbuilders, and gambling-table presentation are the main UX references.

When continuing work, optimize for:

1. A human tester can start and finish a run against 2-7 AI opponents.
2. The main game screen is readable at a glance.
3. UI feels like a board-game table, not a debug panel.
4. Rules, economy, cards, monsters, and AI behavior remain data-driven and testable.
5. AI gets smarter without exposing hidden reasoning to the player.

## Current High-Level Game Loop

Preserve this loop unless the user explicitly changes it:

1. Start a 3-8 seat PVE run.
2. Players publicly choose non-duplicate alien role cards.
3. Starter monster choice is independent from role identity.
4. Players first summon a monster.
5. Players urbanize land districts into anonymous cities.
6. Players buy cards from monster-accessible regional supply.
7. Cards enter an anonymous public reveal/auction/track system.
8. Cities produce realtime GDP from production, demand, transport, routes, damage, contracts, and market pressure.
9. Monsters and military units create visible map pressure and economic consequences.
10. Players infer hidden owners and anonymous card sources.
11. When a cash goal is reached, a final countdown starts; final ranking is by money.

Important rules:

- All seats share the same base starting cash as the general rule, but public alien role cards may explicitly modify their own starting cash through visible role passives. Do not erase role identity by forcing final starting cash to be identical.
- Monsters are not continuously player-controlled. They auto-act from probability tables.
- Monster cards can summon/upgrade/refresh monsters and grant reusable bound skills.
- Military units are weaker controlled forces that use reusable command cards.
- Card play is anonymous unless later inference reveals ownership.
- Player cash, hand size, discard choices, AI pressure buckets, and AI route plans are private.
- Public UI may show clues, aftermath, costs, bids, revealed owners, city damage, GDP trends, and product pressure.
- The economy is realtime/seconds-based; do not reintroduce turn-cycle language for GDP or temporary financial windows.

## Player-Facing UI Principles

The user strongly prefers humanized, elegant UI. Treat this as a product requirement, not cosmetic polish.

### Main Table

The main game screen should prioritize:

1. Central planet/map.
2. Current player's resource/goal/cashflow chips.
3. Current player's hand.
4. Anonymous card track.
5. One stable current-action area.
6. Short prompts for what to do next.

Avoid putting long rules, debug explanations, AI internals, or development history on the main screen.

### Menus and Codex Pages

- Each page should only show controls relevant to that page.
- Subpages should have local back/previous/next controls, not irrelevant global buttons.
- Codex pages should use thumbnail grids with hover previews and double-click detail.
- Detail pages may show richer information, but still in TCG/card-board sections.
- Rules pages should describe the current rules only. Do not mention obsolete rules or development history.
- Player-facing text should be short, concrete, and decision-oriented.

### Card UI

Card faces should emphasize:

- Name/family.
- Roman rank I-IV.
- Price / cost / requirement chips.
- Target type.
- One-line effect.
- Route/category icon.
- Hover/detail for full rules.

Do not put developer fields, generic design principles, or internal AI scoring text on card faces.

### Map UI

- The planet should feel central and alive.
- Zooming should be smooth, not an abrupt projection switch.
- Local view may be a flat XY projection of the spherical world.
- Zoomed-out view should read as a planet in space.
- Map layers should become icon/chip toggles: products, routes, intel, weather, monsters, cities.
- Movement, knockback, attacks, city damage, route damage, weather, and card effects should have visible map feedback.

## Design and Balance Principles

### Cards

Cards should be field-driven where possible. New cards should expose AI-readable effect fields rather than relying only on card names.

Useful field categories include:

- `cash`, `revenue_amount`
- `production_delta`, `transport_delta`, `consumption_delta`
- `route_damage`, `repair_routes`, `route_flow_multiplier`, `route_flow_turns`
- `price_delta`, `market_demand_pressure`, `market_supply_pressure`, `growth_multiplier`
- `gdp_bet_direction`, `gdp_bet_multiplier`, `gdp_bet_turns`, `gdp_bet_destroy_bonus`
- `damage`, `route_damage`, `region_damage`, `knockback`
- `intel_city_reveal`, `intel_card_trace`, `intel_contract_trace`
- `weather_control`
- `military_force`, `military_command`
- `generic_effect_bonus`

Rank gradient guideline:

- I: base effect / route entry.
- II: efficiency or longer duration.
- III: route core.
- IV: strong terminal pressure that remains readable and counterable.

Ranks I-IV normally keep the rank-I purchase price.

### Economy

- GDP, cashflow, commodity price movement, futures, contracts, and temporary effects should be based on realtime seconds.
- Global public refreshes, such as broad supply/demand refresh, may happen every 30-60 seconds.
- Market prices should move from supply/demand/pressure, not direct arbitrary player price-setting.
- Monster damage and route damage should ultimately be visible through GDP, income, or city/route status changes.

### AI

AI should behave like a planned test opponent:

- Open with starter monster and city building.
- Buy cards from accessible regional supply.
- Build around a product/economy route.
- Use cards anonymously.
- Defend owned income.
- Pressure competitors and leaders.
- Participate in auctions, contracts, wagers, and inference.

Do not expose AI development routes, pressure buckets, hidden scores, exact cash, hands, discard choices, or private route plans in player-facing UI.

### Hidden Information

When implementing UI or reports, always distinguish:

- Public facts.
- Current player's private facts.
- Rival private facts.
- Developer/test-only facts.

If unsure, hide the information from players and expose it only in tests/logs/docs.

## Reference Material

Root reference index:

- `REFERENCE_LINKS.md`

Local reference clones may exist under:

- `C:/Users/Administrator/Documents/New project/reference/terraforming-mars`
- `C:/Users/Administrator/Documents/New project/reference/gaia-project`
- `C:/Users/Administrator/Documents/New project/reference/UiCard`
- `C:/Users/Administrator/Documents/New project/reference/Night-Patrol`
- `C:/Users/Administrator/Documents/New project/reference/hypnagonia`

Use them as references for interaction patterns and information hierarchy. Do not copy licensed code or assets unless compatibility is confirmed.

Highest-priority references:

1. Terraforming Mars — central board, resource/player panels, card organization, menus.
2. Gaia Project — map/action/resource iconography and board-game information hierarchy.
3. UiCard — card hover, drag, hand layout, card-object feel.
4. Night Patrol — temporary UI/art/audio atmosphere.
5. Godot performance references — async loading, shader warmup, object pooling, profiler workflow.

## Repository Orientation

Key files and folders:

- `project.godot` — Godot project.
- `scenes/main.tscn` — main scene.
- `scripts/main.gd` — current large prototype script containing most game/UI logic.
- `tests/smoke_test.gd` — full behavioral smoke test.
- `tests/ui_text_smoke_test.gd` — source-level UI text/contract guard.
- `tests/visual_snapshot.gd` — source-level visual/layout contract guard.
- `tests/ui_snapshot_capture.gd` — headed screenshot capture for visual QA.
- `docs/rules_summary.md` — current rules summary.
- `docs/development_log.md` — running development log.
- `docs/reference_ui_notes.md` — deeper reference notes.
- `REFERENCE_LINKS.md` — root list of reference URLs.

The codebase is still prototype-heavy. Prefer improving stability and readability over large rewrites unless a rewrite directly reduces future risk.

## Godot Commands

Godot executable usually lives at:

```powershell
..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe
```

From repository root:

```powershell
# Fast source/UI text guard
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/ui_text_smoke_test.gd

# Visual/layout source contract
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/visual_snapshot.gd

# Fast script/load check
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/smoke_test.gd --check-only

# Full smoke test
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/smoke_test.gd
```

Headed UI snapshots should usually run on the second monitor when available:

```powershell
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --path . --windowed --position -1247,-2140 --resolution 1200x680 --script res://tests/ui_snapshot_capture.gd
```

If monitor layout changes, detect screens with:

```powershell
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Screen]::AllScreens | ForEach-Object { $_.DeviceName, $_.Primary, $_.Bounds }
```

Do not interrupt the user's primary screen for headed tests when the second monitor is available.

## Testing Expectations

For most implementation changes, run at least:

1. `tests/ui_text_smoke_test.gd`
2. `tests/visual_snapshot.gd`
3. `tests/smoke_test.gd --check-only`

For gameplay, AI, economy, save/load, map, or card-resolution changes, also run full:

```powershell
tests/smoke_test.gd
```

For UI/layout changes, also capture headed screenshots and inspect:

- `01_main_menu.png`
- `02_card_codex_grid.png`
- `03_card_codex_detail.png`
- `04_play_table.png`

Snapshot output path:

```txt
C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/
```

## Performance Expectations

The game has had UI/map stutter. Preserve these rules:

- Avoid rebuilding large UI trees every frame.
- Keep realtime status refresh separate from heavy layout rebuilds.
- Cache signatures for stable card rails, compass strips, and other repeated UI structures.
- Avoid excessive `queue_redraw()` on map interactions.
- Use object pools for frequent temporary effects when implemented.
- Warm up shaders/VFX or async-load large assets before use.
- Profile before and after big animation, monster, map, or UI changes.

## Text and Localization Style

Most player-facing text is currently Chinese.

Guidelines:

- Use concise player-facing language.
- Prefer verbs and outcomes over explanations.
- Use icons/chips where they reduce reading load.
- Do not mention obsolete rules, removed systems, or development reasoning in player UI.
- Put long explanations in 游戏规则, 经济总览, 情报档案, or docs.
- Keep developer-only terms out of player-facing screens.

## Development Workflow

Before editing:

1. Check `git status --short`.
2. Inspect the relevant current code and screenshots.
3. Preserve unrelated user changes.

While editing:

- Prefer small, testable changes.
- Use existing UI helpers/styles before creating new visual systems.
- Add or update tests when changing behavior or UI contracts.
- Keep docs in sync when rules, workflows, or major UI patterns change.

After editing:

1. Run relevant tests.
2. Capture headed UI screenshots for visual changes.
3. Update `docs/development_log.md`.
4. Commit with a clear message.
5. Push when the user has asked for GitHub sync or the thread is already operating in sync mode.

## Definition of Done

A change is done when:

1. It moves the prototype closer to a human-playable PVE board-game experience.
2. Player-facing UI remains concise and readable.
3. Hidden information stays hidden.
4. Relevant automated tests pass.
5. Visual changes have been inspected in headed screenshots when practical.
6. Development log or docs are updated for meaningful gameplay/UI/rule changes.
7. The worktree is clean after commit/push when a commit is expected.

## When Unsure

If a design choice is ambiguous:

1. Prefer the more human-readable UI.
2. Preserve hidden-information integrity.
3. Preserve data-driven card/economy/AI fields.
4. Prefer Terraforming Mars / Gaia Project style board-game clarity over debug density.
5. Make a small reversible change with tests instead of a broad rewrite.
