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
4. Players select and hold a starter monster card; summoning is voluntary and may happen at any later point.
5. Players urbanize land districts into anonymous cities without a summon prerequisite.
6. Players browse region-specific ordinary-card racks. Every ordinary slot is dealt from one deterministic legal supply bag with no guaranteed factory, market, city-development, monster, or category order. A listing remains viewable even when it is not currently purchasable; purchase eligibility still comes from its authoritative source-region conditions, and live monsters in or adjacent to that source raise its price for every buyer.
7. Cards enter an anonymous public reveal/auction/track system.
8. Cities produce realtime GDP from production, demand, transport, routes, damage, contracts, and market pressure.
9. Monsters and military units create visible map pressure and economic consequences.
10. Players infer hidden owners and anonymous card sources.
11. A player who controls the dynamic Top-K share of surviving regions and reaches the required Top-K commodity GDP for 10 seconds enters a 120-second final audit. At audit end, qualifying players compare Top-K commodity GDP, then controlled-region count, then exact cash.

Important rules:

- All seats share the same base starting cash as the general rule, but public alien role cards may explicitly modify their own starting cash through visible role passives. Do not erase role identity by forcing final starting cash to be identical.
- Monsters are not continuously player-controlled. They auto-act from probability tables.
- Monster cards can summon/upgrade/refresh monsters and grant reusable bound skills.
- Starter-monster possession does not force an opening summon. Delaying or skipping summon must not block facilities, economy, or card-market access.
- Every region's current ordinary-card rack is public and may be inspected without refreshing it. Opening, closing, hovering, scrolling, camera movement, and zoom never redraw the rack. Purchasing fills only the vacated slot from the authoritative deterministic supply bag.
- Regional supply has no factory-first, market-after-factory, city-development guarantee, monster guarantee, or hidden category phase. AI may read the current public rack but never future bag order.
- Purchase eligibility is derived from the listing's authoritative source region and the shared 120-second `world_effective` solar rotation; camera position and zoom never affect it.
- Market quotes lock eligibility and price for exactly 5 `world_effective` seconds. Live monster ownership is irrelevant: same-region monsters add `1.0x` each, directly adjacent monsters add `0.5x` each, the total multiplier is capped at `5.0x`, and the final cash price rounds up.
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
- `intel_city_reveal`, `card_history_public_review`, `card_history_subscription`
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
- Every surviving non-ruin region has low, non-accumulating ambient consumption for every active commodity. Only same-region fresh production or a directly adjacent producer feeding a land consumer may satisfy it.
- Installed market demand accumulates unmet demand by market facility and commodity. Current steady demand is served before capped backlog recovery.
- Fresh output is allocated in the authoritative order: explicit market demand, ambient consumption, compatible warehouse storage, then irreversible waste. Ambient consumption never drains strategic warehouse inventory.
- Commodity routes run automatically in the economy but are hidden on the map by default. The player may opt into one commodity's actual or recently committed flows; candidate routes must not be presented as real traffic.

### AI

AI should behave like a planned test opponent:

- Establish an economic route without requiring an opening summon; deploy the held starter monster later when useful.
- Inspect public regional racks, buy useful ordinary cards when their authoritative source-region conditions and locked quote are legal, and never inspect future supply-bag order.
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

Headless focused tests remain required, but supplement rather than replace MCP scene/runtime evidence. Every active agent works from an isolated Git worktree with its own local Godot editor, `override.cfg` user directory, Funplay MCP endpoint, and auth token. Agents may develop concurrently but must never point two roles at the same editor endpoint. The user-designated active coordinator owns full regression, headed acceptance, screenshots, integration verdicts, and pushes to protected integration/main branches. When the Supervisor task is unavailable, the user may explicitly assign that coordinator role to another agent; the current local assignment is recorded in `reports/coordination/active_local_coordination.md`.

Agents develop and commit locally inside their own worktrees. Do not fetch or push after every atomic change. The active coordinator integrates reviewed local commits, validates a coherent milestone, and only then performs the explicitly approved cloud synchronization.

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

## V0.7 Commodity Semantic Constitution

This section is the highest development authority for the approved V0.7
shared-sushi commodity-track direction. It does not change the current runtime
rules by itself.

```text
GAME_SEMANTIC_CONSTITUTION_VERSION=V0.7
CURRENT_RUNTIME_RULE_VERSION=v0.6
TARGET_RULE_VERSION=V0.7
FULL_V0_7_CUTOVER=false
NON_INTERRUPTING_SCOPE_AMENDMENT=true
```

Until one atomic production cutover passes Core, AI, player, privacy,
determinism, persistence, and old-path deletion gates, the v0.6 runtime remains
the only production authority. V0.6 commodity clauses may continue executing,
but they are superseded as future commodity design and may not be expanded as
the target architecture.

The authority order for this V0.7 domain is:

1. the user's latest explicitly approved V0.7 semantic constitution;
2. the V0.7 Core semantic contract;
3. the V0.7 AI observation and decision contract;
4. the V0.7 player/UI projection contract;
5. feature design records;
6. conflicting v0.6 commodity rules, which remain runtime-only until cutover;
7. temporary implementation notes, code, tests, and historical fixtures.

The immutable V0.7 commodity rules are:

- one real, globally ordered, cyclic commodity track is shared by all players;
- each player and AI sees only its owner-authorized local segment;
- six-color global supply and GDP baseline aggregates are public;
- supply starts evenly, GDP drives the long horizon, and player stances drive
  one 180-second short-horizon cycle;
- each seat privately precommits one different increase/decrease color during
  the active cycle, then all valid stances reveal simultaneously with no empty
  waiting phase;
- ordinary influence is `+/-300` basis points and the current hidden lead is
  `+/-600`; the core applies weight, while public projections reveal colors but
  never lead identity, effective weight, or pre-normalization contribution;
- one hidden lead order is fixed for the session; every roster player leads
  exactly once per macro round, and macro rounds alternate exact forward and
  reverse order without reshuffling;
- original end conditions become pending mid-round and may finalize only after
  a complete macro-round boundary revalidation;
- commodity levels are linear base units: `L1+L1->L2`, `L2+L1->L3`, and
  `L3+L1->L4`; `L2+L2` and `L3+L3` are not legal upgrade edges;
- manual merge choice remains the target interaction until a later explicit
  rule authorizes another policy.

The two card capacities are independent constitutional invariants:

```text
NORMAL_CARD_HAND_LIMIT=5
COMMODITY_CARD_HAND_LIMIT=5
HAND_POOLS_ARE_INDEPENDENT=true

normal_card_count <= 5
commodity_slot_count <= 5
```

Five normal cards do not block commodity acquisition, and five commodity
stacks do not block normal-card acquisition. A valid state may contain five of
each, but there is no shared `TOTAL_CARD_COUNT<=10` rule. A merged commodity
still occupies one commodity slot. Core state, AI observation, player
projection, persistence, and eventual replay/network schemas must carry the
two counts and limits separately; generic `hand_limit` and mixed-hand authority
are forbidden in the V0.7 target.

The only legal semantic direction is:

```text
Core computes and is the sole mutation authority.
AI receives an owner-bound allowlisted observation, interprets, and submits intent.
Player UI receives public plus owner-bound private projection and submits the same intent.
```

AI and UI may not receive the full core object, calculate supply/lead/end facts,
read another seat's local track or private stance, read the hidden order, or
maintain a second inventory count. Human and AI seats use the same typed stance,
claim, merge, capacity, and overflow semantics.

The detailed executable reference and unresolved production decisions live in
`docs/rules/shared_partial_visibility_commodity_track_contract.md`. Do not wire
that reference into production. `FULL_V0_7_CUTOVER` stays false unless every
listed production gate is true and all conflicting v0.6 write paths are deleted
in the same atomic cutover.

## V0.7 Uninterrupted Card Batch Constitution

This section is the highest development authority for V0.7 card submission,
target binding, resolution pacing, and contextual table presentation. It is a
target-rule constitution and does not replace the current V0.6 production
runtime by itself.

```text
CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6
TARGET_DEVELOPMENT_CONSTITUTION=V0.7
FULL_V0_7_RUNTIME_CUTOVER=false

V07_INTERACTIVE_COUNTER_CARDS_RETIRED=true
V07_COUNTER_WINDOW_RETIRED=true
V07_COUNTER_STACK_RETIRED=true
V07_RESOLUTION_HAS_NO_GAMEPLAY_INPUT=true
```

V0.7 moves all player and AI strategy into one authoritative 30-second card
window. During that window each submitted card locks its card instance,
semantic action, actor, source revision, target kind and stable target IDs,
target revision, placement slot, mode, quantity, and authored parameters.
After locking, submission, target, mode, and quantity are immutable.

The only V0.7 state order is:

```text
CARD_WINDOW_CLOSED
-> CARD_WINDOW_OPEN
-> CARD_WINDOW_LOCKING
-> RESOLUTION_ORDER_BUILD
-> RESOLUTION_ORDER_REVEAL
-> CARD_RESOLUTION_ACTIVE
-> CARD_EFFECT_COMMIT
-> CARD_AFTERMATH
-> BATCH_AFTERMATH
-> BATCH_COMPLETE
-> CARD_WINDOW_OPEN
```

There is no `COUNTER_WINDOW`, `COUNTER_STACK`, forced card response, target
reselection, or mid-resolution submission in this state machine. Once the
order is revealed, cards resolve strictly and continuously. Presentation may
show details, targets, receipts, and local speed controls, but no player or AI
gameplay intent may be accepted. The next window may open only from an
authoritative Card Batch Complete receipt after the queue, active resolution,
receipt, aftermath, and batch after-action gates are clear.

Every target is revalidated when its card resolves. The default invalidation
policy is `FIZZLE_NO_EFFECT`. `COMMIT_LEGAL_REMAINDER`, authored refunds, and
deterministic fallback are legal only when declared by the card rule before
the window locks; none may ask a player or AI to choose again.

V0.7 defense is proactive state, not a response card. A defense, insurance, or
interference card is chosen and targeted in the 30-second window. Once its
ordinary resolution establishes a Defense Status, later effects query and
apply that existing status automatically, emit the authoritative result, add
no queue entry, consume no response input, and preserve the revealed order.
Legacy cards whose only value is deciding after seeing a resolving card must
be explicitly redesigned or retired.

World-effective simulation time and the card-window timer run during
submission. Both pause during locked batch resolution, while presentation time
may continue and each card still commits its own deterministic state. No world
tick is inserted between resolving cards. Resolution adds no decision-time RNG;
all authored random outcomes consume the injected `RunRngService` in the
stable revealed order.

The three V0.7 card pools are independent:

```text
NORMAL_CARD_HAND_LIMIT=5
COMMODITY_CARD_HAND_LIMIT=5
BOUND_ACTION_CARD_CAPACITY_COST=0
BOUND_ACTION_CARDS_IN_NORMAL_HAND=false
BOUND_ACTION_CARDS_IN_COMMODITY_INVENTORY=false
```

Monster- and military-granted bound actions remain visible in the bottom card
dock but must be authored as a window-time `batch_action` or an automatic
`passive_source_ability`; they may not retain counter or instant-response
timing.

AI receives an owner-authorized, allowlisted card-batch observation. It may
choose cards, targets, modes, quantities, proactive defenses, and a lock intent
only while `CARD_WINDOW_OPEN`. It uses the same submission schema as a human
seat and must emit zero Action Intents during resolution. Rival unrevealed
submissions, targets, hands, private inventory, hidden owners, AI plans, future
racks, RNG state, and full core state are never observation fields.

The target player table is contextual and scene-owned: the real planet map is
the permanent center stage; the compact player roster appears on the left only
with one column for three to four seats and two columns for five to eight;
region supply opens as a closable translucent popup and browsing never redraws
the rack; target-selection map clicks bind targets instead of opening supply;
the revealed sequence exists only in a transient resolution overlay; and the
bottom dock renders bound actions, normal cards, and commodities as separate
pools. No V0.7 player projection contains a counter button, counter countdown,
counter stack, or permanent right-side region rack.

V0.7 persistence stores only stable pure data needed to resume the one-shot
window or uninterrupted batch: state ID, window/batch IDs, remaining window
time, immutable submissions and target bindings, revealed order and cursor,
Defense Status records, the three independent pools, and bound-action source
lifecycle. It stores no Node, Object, Resource, Callable, UI state, Counter
Window, Counter Stack, or engine-frame metadata. Restore consumes zero RNG and
must reproduce the same batch fingerprint and receipt lineage. This is a
persistence and deterministic identity contract, not a replay-system cutover.

Until one atomic Core/AI/player/Save/privacy/determinism production migration
also removes every conflicting V0.6 writer and consumer, the V0.6 Counter
runtime remains preserved for the current production ruleset. New V0.7 code
must never call it, and no V0.6/V0.7 dual write is allowed. Reference Benches,
tests, and passive projections may be three-layer ready while
`FULL_V0_7_RUNTIME_CUTOVER` remains false.

## Active Runtime v0.6 Rule Authority Gate

Before adding any gameplay Owner, Port, Sink, Request, Receipt, RuntimeController,
UI decision window, AI policy, save field, save section, or card effect kind, the
change must identify all of the following:

- `mechanic_id`
- active rule source and section
- player-facing meaning
- authoritative owner
- required privacy
- required persistence

For currently executing production behavior, the authority order is:

1. `docs/tabletop_rulebook_v06.md`
2. `docs/rules_v06_runtime_directive.md`
3. the active Ruleset, card runtime catalog, and data Resources
4. explicit v0.6 decisions in `README.md`
5. approved migration ledgers and design records
6. production code
7. tests and Benches
8. historical code, fixtures, and text

Code and tests are not product-rule authority. When no active rule clause can be
identified, report `RULE_AUTHORITY_NOT_ESTABLISHED` and do not begin production
implementation. A failing legacy test is never a reason to restore a retired
mechanic.

Mechanics marked `RETIRED` in
`docs/rules/v06_mechanic_status_registry.json` may appear only in deletion work,
compatibility reads, data migration, historical documentation, and explicit
negative tests. They may not gain a new production Owner, Port, Sink, Receipt,
window, AI policy, or save state.

## main.gd Extinction Policy

`scripts/main.gd` is frozen legacy code.

No production task may:

- add a new method, field, constant, preload, signal, or branch to `main.gd`;
- add a new consumer of Main;
- call Main through `call`, `get`, `set`, `has_method`, or string method names;
- bind a runtime world bridge to Main;
- create a compatibility facade that keeps both old and new paths alive;
- copy or rename `main.gd` into another monolithic controller.

When a task needs any symbol currently owned by `main.gd`:

1. Stop the feature implementation.
2. Identify the real domain owner.
3. Create or extend a scene-owned typed owner.
4. Migrate every production consumer.
5. Validate that only the new path executes.
6. Delete the old `main.gd` symbol in the same change.
7. Run negative dependency and duplicate-execution gates.
8. Only then resume the original feature.

Every change touching `main.gd` must monotonically reduce its:

- physical line count;
- method count;
- fields and constants;
- external callers.

Independent tasks may proceed only when they do not touch or depend on
`main.gd`.

The end state is:

- `scenes/main.tscn` as composition;
- no `scripts/main.gd`;
- no replacement monolith;
- an optional application bootstrap of at most 120 lines containing no
  gameplay or UI-domain logic.
