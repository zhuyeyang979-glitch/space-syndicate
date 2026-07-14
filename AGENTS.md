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

Default development habit:

- Before or while implementing a feature, define the player-facing hard standard that proves the feature is good enough.
- Build a reusable skeleton or data contract when the feature is likely to recur; avoid one-off UI or rule patches that cannot scale.
- Add an acceptance gate, smoke test, visual contract, or documented manual check so the standard does not depend on memory.
- If a feature is still temporary, say exactly which hard standard it does not meet yet and what the next gate should protect.
- A change without a hard standard, reusable skeleton, and acceptance gate is not considered finished, even if the visible feature appears to work.

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
11. A player who controls the dynamic Top-K share of surviving regions and reaches the required Top-K commodity GDP for 10 seconds enters a 120-second final audit. At audit end, qualifying players compare Top-K commodity GDP, then controlled-region count, then exact cash.

Important rules:

- All seats share the same base starting cash as the general rule, but public alien role cards may explicitly modify their own starting cash through visible role passives. Do not erase role identity by forcing final starting cash to be identical.
- Monsters are not continuously player-controlled. They auto-act from probability tables.
- Monster cards can summon/upgrade/refresh monsters and grant reusable bound skills.
- Military units are weaker controlled forces that use reusable command cards.
- Card play is anonymous unless later inference reveals ownership.
- Player cash, hand size, discard choices, AI pressure buckets, and AI route plans are private during ordinary play. A player who enters the authoritative final-audit roster explicitly reveals the economic facts required by the current audit rule; seats outside that roster remain private. UI must consume the owner's visibility-tagged public projection and may never infer visibility from `game_over`, winner status, or the mere presence of a cash field.
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
- The runtime `MapView` is a core table asset. Do not replace it with placeholders, static screenshots, `ColorRect` boards, fake flat maps, or non-zoomable panels. The real `main.tscn` table must default to a scalable globe planet, with local flat projection available through zoom.
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
- `scripts/main.gd` — transitional legacy facade scheduled for complete deletion. Do not add new ownership, formulas, UI construction, compatibility fallbacks, or durable feature logic here.
- `tests/smoke_test.gd` — full behavioral smoke test.
- `tests/ui_text_smoke_test.gd` — source-level UI text/contract guard.
- `tests/visual_snapshot.gd` — source-level visual/layout contract guard.
- `tests/ui_snapshot_capture.gd` — headed screenshot capture for visual QA.
- `docs/tabletop_rulebook_v06.md` — authoritative v0.6 player rules; `docs/rules_summary.md` is its current quick-reference companion.
- `docs/development_log.md` — running development log.
- `docs/reference_ui_notes.md` — deeper reference notes.
- `REFERENCE_LINKS.md` — root list of reference URLs.

The codebase is still prototype-heavy. The active architecture program is to migrate every remaining `main.gd` responsibility into an editable Godot scene plus a narrow Controller/WorldBridge or presentation service, prove the production cutover, remove conflicting legacy behavior, and finally delete `scripts/main.gd`. Do not move the monolith into another giant script.

## Mandatory Godot MCP Workflow

Every production change must use the local Godot MCP server. Editing `.gd` files and running console tests alone is not acceptance evidence.

For each task:

1. Inspect the real project and the relevant `.tscn` through Godot MCP.
2. Implement the behavior in an editable Godot scene and its scoped script/resource modules. A script-only subsystem without a production or Bench scene is incomplete.
3. Run the real scene or a production-wiring Bench with Godot MCP.
4. Read MCP debug output, resolve reported errors, and stop the running project.
5. Record the scene path, MCP runtime result, debug error count, and stop result in the handoff.

Headless focused tests remain required, but supplement rather than replace MCP scene/runtime evidence. Every active agent works from an isolated Git worktree with its own local Godot editor, `override.cfg` user directory, Funplay MCP endpoint, and auth token. Agents may develop concurrently but must never point two roles at the same editor endpoint. The Supervisor alone owns full regression, headed acceptance, screenshots, integration verdicts, and pushes to protected integration/main branches.

When current player rules contradict legacy code in `main.gd`, delete the legacy path after the replacement scene is connected and tested. Do not retain a fallback to obsolete rules merely for old tests; migrate or retire the stale oracle instead.

## Godot Commands

Use the latest stable Godot available on the machine. The current minimum accepted version is Godot 4.7. Prefer the `godot` command from PATH, and verify it reports `4.7.*` or newer:

```powershell
godot --version
```

From repository root:

```powershell
# Fast source/UI text guard
godot --headless --path . --script res://tests/ui_text_smoke_test.gd

# Visual/layout source contract
godot --headless --path . --script res://tests/visual_snapshot.gd

# Fast script/load check
godot --headless --path . --script res://tests/smoke_test.gd --check-only

# Full smoke test
godot --headless --path . --script res://tests/smoke_test.gd
```

Headed UI snapshots should usually run on the second monitor when available:

```powershell
godot --path . --windowed --position -1247,-2140 --resolution 1200x680 --script res://tests/ui_snapshot_capture.gd
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
2. Inspect the relevant current code, scene tree, and screenshots; use Godot MCP for engine-aware scene context.
3. Preserve unrelated user changes.

While editing:

- Prefer small, testable changes.
- Every new runtime or presentation responsibility must have an editable `.tscn` production/Bench surface; do not deliver a pure-script-only feature.
- Use existing UI helpers/styles before creating new visual systems.
- Add or update tests when changing behavior or UI contracts.
- Keep docs in sync when rules, workflows, or major UI patterns change.

After editing:

1. Run relevant tests.
2. Run the corresponding real scene or production Bench with Godot MCP, inspect debug output, and stop it.
3. Capture headed UI screenshots for visual changes.
4. Update `docs/development_log.md`.
5. Commit or push only when explicitly assigned and the shared-worktree coordinator confirms ownership.

## Definition of Done

A change is done when:

1. It moves the prototype closer to a human-playable PVE board-game experience.
2. Player-facing UI remains concise and readable.
3. Hidden information stays hidden.
4. Relevant automated tests pass.
5. The real Godot scene or production Bench has passed through MCP with inspected debug output and a clean stop.
6. Visual changes have been inspected in headed screenshots when practical.
7. Development log or docs are updated for meaningful gameplay/UI/rule changes.
8. The worktree is clean after commit/push when a commit is expected.

## When Unsure

If a design choice is ambiguous:

1. Prefer the more human-readable UI.
2. Preserve hidden-information integrity.
3. Preserve data-driven card/economy/AI fields.
4. Prefer Terraforming Mars / Gaia Project style board-game clarity over debug density.
5. Make a small reversible change with tests instead of a broad rewrite.
