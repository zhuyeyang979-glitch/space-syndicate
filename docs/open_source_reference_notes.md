# Open Source Reference Notes

This file turns the reference list from the product brief into implementation guidance for the Space Syndicate UI refactor.

## Copying Rule

- Prefer copying product structure, interaction patterns, screen rhythm, and component boundaries before copying code.
- MIT or CC0 references can be ported more directly after preserving license/attribution notes.
- GPL, AGPL, and LGPL references are useful for architecture and UI behavior study, but do not paste code or assets into this repo unless the project intentionally accepts the license obligations.
- Unknown-license references must be checked before copying implementation details.
- When copying a permissive implementation pattern, rewrite it in local Godot/GDScript style and keep the source in this note or a nearby attribution comment. Do not hide copied code inside generated UI helpers.

## Next-Stage Copy Targets

The next phase should copy benchmark structure first, then apply small Space Syndicate-specific edits.

| Target | Primary references | Copy stance | Local landing zone |
| --- | --- | --- | --- |
| Main-table read order | `terraforming-mars/terraforming-mars`, `boardgamers/gaia-project`, `vassalengine/vassal` | Product hierarchy only for GPL/LGPL/unknown-license projects. | `GameScreen`, `TopBar`, `PlanetBoard`, `RightInspector`, `PlayerBoard` |
| HandRack feel v2 | `pipeworks-studios/CardHouse`, `mixandjam/Balatro-Feel`, `ycarowr/UiCard`, `twdoor/simple-cards-v-2`, `cyanglaz/gcard_layout`, `chun92/card-framework` | MIT/CC0 patterns can be ported directly after attribution and GDScript rewrite. | `HandLayout.gd`, `hand_rack.gd`, `CardUI.gd`, `HandRack.tscn` |
| Menu/Codex pages | `Maaack/Godot-Menus-Template`, `godotengine/godot-demo-projects`, `boardgameio/boardgame.io` | MIT patterns can guide scene shell, local navigation, and view-layer boundaries. | `MenuOverlay`, `MenuRootLobby`, `CardCodexBrowser`, `CardCodexDetail` |
| Theme/style extraction | Godot official Theme/Container/Custom Control docs, Maaack templates | Use directly as engine guidance; do not keep scattering one-off style constants. | `themes/`, `scenes/ui/*.tscn`, `scripts/ui/*` |
| Visual QA gates | Godot UI docs plus existing screenshot tests | Keep concrete multi-resolution screenshots as acceptance evidence. | `tests/ui_snapshot_capture.gd`, `tests/layout_scene_smoke_test.gd`, `tests/visual_snapshot.gd` |

## Board-Game Table References

| Reference | Use for Space Syndicate | Copy stance |
| --- | --- | --- |
| `terraforming-mars/terraforming-mars` | Player tableau, resource/production scan line, table-first board composition, card market rhythm. | GPL-3.0: study layout and product hierarchy; do not paste code/assets. |
| `boardgamers/gaia-project` | Engine/viewer separation, board state adapter, dense but playable board-game UI. | Verify license before copying; use architecture as reference. |
| `vassalengine/vassal` | Board module concept, transient overlays, player-facing table surface over generic rules engine. | LGPL-2.1: study architecture; avoid direct code copying. |
| `boardgameio/boardgame.io` | View-layer-agnostic state, moves, phases, logs, replay/time-travel style boundaries. | MIT: safe to adapt small patterns with attribution, but rewrite in GDScript idioms. |
| `GAIGResearch/TabletopGames` | AI/game-state separation and reproducible test skeletons. | Verify license before copying; use as AI/domain reference. |

## Godot UI References

| Reference | Use for Space Syndicate | Copy stance |
| --- | --- | --- |
| Godot Containers / Theme / Custom Controls docs | Container sizing, minimum-size contracts, theme reuse, custom `Control` rendering. | Official docs: use directly as implementation guidance. |
| `godotengine/godot-demo-projects` | Importable Godot project organization and scene conventions. | MIT: safe to adapt patterns with attribution. |
| [`Maaack/Godot-Game-Template`](https://github.com/Maaack/Godot-Game-Template) | Main menu, pause, options, accessibility, loading, tutorial, UI audio, controller navigation, and scene-loader boundaries. | MIT; current upstream targets Godot 4.7 and remains compatible with 4.3+. Adapt small scene/navigation patterns into the existing menu ownership. |
| [`Maaack/Godot-Menus-Template`](https://github.com/Maaack/Godot-Menus-Template) | Lighter menu shell, settings/credits pages, return stack, and scene loading. | MIT; current upstream targets Godot 4.7. Do not install it as a parallel menu framework beside `MenuOverlay` and `MenuRootLobby`. |
| [`popcar2/GodotOS`](https://github.com/popcar2/GodotOS) | Window hierarchy, sidebar navigation, icon consistency, and a restrained dark desktop surface. | AGPL-3.0 and includes separately sourced wallpapers/icons. Study product organization only; do not copy code or assets. |

## Card And Hand References

| Reference | Use for Space Syndicate | Local landing zone | Copy stance |
| --- | --- | --- | --- |
| [`twdoor/simple-cards-v-2`](https://github.com/twdoor/simple-cards-v-2) | Godot editor preview, data/layout separation, reusable animation resources, hand layouts, drop slots, pile preview, and layout management. | `CardFace`, `HandRack`, Runtime Card Authoring Workspace, future card-layout QA. | MIT; Godot 4.5.1+. Do not install it wholesale or create a second card catalog/deck owner. Port editor and presentation patterns into existing scenes/Resources. |
| [`phase-rs/phase`](https://github.com/phase-rs/phase) | Battlefield/hand/stack hierarchy, targeting overlay, payment surface, animation staging, and hidden-information boundaries. | `GameScreen`, `CardResolutionTrack`, `OverlayLayer`, `RightInspector`, target/payment presentation. | Code is dual MIT/Apache-2.0. Scryfall card images and MTG data/IP are separate; do not import card art, symbols, names, text, or game rules. |
| [`db0/hypnagonia`](https://github.com/db0/hypnagonia) | Complete Godot deckbuilder table, status effects, deck/pile flow, Codex, and thematic UI organization. | Product review only for `CardCodex`, status presentation, and pile navigation. | AGPL-3.0. Study behavior and scene boundaries only; no code or assets enter this repository. |
| [`db0/godot-card-game-framework`](https://github.com/db0/godot-card-game-framework) | Card scenes, hands/decks, hover, drag/drop, and rule-script separation. | Architecture comparison for `CardFace`, `HandRack`, Queue, and Eligibility boundaries. | AGPL-3.0. Do not paste code unless the project explicitly accepts AGPL obligations. |
| `chun92/card-framework` | Hand/pile manager boundaries, data-backed card resources, drag/hover contracts. | `HandRack` architecture comparison. | Verify license before any code reuse. |
| `cyanglaz/gcard_layout` | Hand layout math, spread, hover animation, card positions. | `HandLayout.gd` formula comparison. | Verify license before copying formulas. |
| `mathrick/godot-simple-card-pile-ui` | Draw/hand/discard piles, drop zones, spread/rotation/vertical curves. | Future pile/discard surface comparison. | Verify license before copying. |

## Non-Godot Feel References

| Reference | Use for Space Syndicate | Copy stance |
| --- | --- | --- |
| [`ycarowr/UiCard`](https://github.com/ycarowr/UiCard) | TCG-like draw, hover zoom, hand pivot, neighbor displacement, drop-zone positioning, and opponent-hand presentation. | MIT code, but the repository credits external illustrations. Rewrite behavior in GDScript; do not copy its art without separately verifying every source. |
| [`pipeworks-studios/CardHouse`](https://github.com/pipeworks-studios/CardHouse) | Card groups, phase manager, drag handling, position/rotation/scale seekers, and target transforms. | CC0. Good structural reference, but rewrite Unity/C# patterns into the existing `HandRack`/`HandLayout` contracts. |
| [`mixandjam/Balatro-Feel`](https://github.com/mixandjam/Balatro-Feel) | Hover elasticity, snap, neighbor reflow, reveal/settlement timing, and restrained continuous feedback. | MIT. Adapt motion vocabulary and timing only; do not copy Balatro assets, trademarks, or visual identity. |
| [`Arefnue/NueDeck`](https://github.com/Arefnue/NueDeck) | Card editor, Scriptable Object authoring, combat table, reward choice, and content pipeline. | MIT. Use as authoring-workflow comparison because Space Syndicate already owns a Resource Catalog and validator; do not create a second runtime card model. |

## Flat UI And Icon Asset References

These packs are candidates, not a request to import every file. A production component must use one primary skin family plus project-owned colors/typography; mixing every pack on one screen would create a new inconsistency problem.

| Reference | License / contents | Intended role | Import boundary |
| --- | --- | --- | --- |
| [Mechanized Magic: Ultimate UI Pack](https://opengameart.org/content/mechanized-magic-2d-vector-cards-pack-0) | CC0; free pack currently lists 60 icons and 75 HUD elements in multiple styles. | First candidate for card trim, mechanical dividers, card/HUD accents, and strategy-screen motifs. | Import only the selected style and required resolutions. Recolor/recompose into a Space Syndicate skin; do not let the pack define the whole brand unchanged. |
| [Kenney UI Pack - Sci-Fi](https://kenney.nl/assets/ui-pack-sci-fi) | CC0; 130 files. | Primary control-state source for buttons, sliders, panels, status bars, and modal frames. | Import a curated control subset after a Theme prototype proves nine-patch/stretch behavior. |
| [Kenney UI Pack](https://kenney.nl/assets/ui-pack) | CC0; 430 files. | Fallback source for common controls missing from the Sci-Fi pack. | Do not bulk-import all files and do not mix visibly different control families in one player-facing scene. |
| [Kenney Board Game Icons](https://kenney.nl/assets/board-game-icons) | CC0; 250 files. | Cash, resources, piles, bids, turn state, dice, and table actions. | Curate through a project icon registry; no direct hardcoded paths in card/menu scripts. |
| [Kenney Board Game Info](https://kenney.nl/assets/board-game-info) | CC0; 280 files. | Rules, tutorial, keywords, requirements, warnings, and status explanations. | Curate through the same icon registry and semantic IDs. |
| [Kenney Board Game Pack](https://kenney.nl/assets/boardgame-pack) | CC0; 490 files. | Prototype piles, discard, chips, dice, and table objects. | Use only where a real table object improves readability; do not replace project-owned card presentation or gameplay data. |
| [Kenney Playing Cards Pack](https://kenney.nl/assets/playing-cards-pack) | CC0; 270 files. | Card proportion, corner duplication, suit/identity repetition, card-back structure. | Primarily a layout reference. Import only if a neutral placeholder is required. |
| [SCIFI UI](https://opengameart.org/content/scifi-ui) | CC0; panels, buttons, bars, inputs, and source PSD. | Rapid dark-HUD graybox and slicing reference. | Reference/prototype tier. Do not ship it beside the primary Mechanized Magic/Kenney skin without an explicit art-direction decision. |
| [Wenrexa White UI Kit](https://opengameart.org/content/assets-wenrexa-free-ui-kit-white-interface-5-panels-buttons) | CC0; five-color PNG panel/button set. | High-contrast developer tools, QA surfaces, and economic reports. | Keep out of the default play table unless the accessibility theme adopts it deliberately. |
| [Game-icons.net](https://game-icons.net/about.html) | CC BY 3.0; icons have individual authors. | Semantic fallback when the CC0 Kenney sets do not cover a product, contract, intelligence, monster, or route concept. | Every imported icon must record author, source URL, and license. Prefer CC0 replacements when equivalent so Credits remain manageable. |

## Card/Table/Menu Reference Product Boundary

- Keep `CardRuntimeCatalogService`, Runtime Card Authoring Resources, Queue, Eligibility, Execution, and Presentation ownership. None of these references justify a parallel card engine.
- Keep `CardResolutionTrack`, `RightInspector`, `PublicTrack`, `MenuOverlay`, and `MenuRootLobby` as the product scene owners. References improve their composition and skin; they do not replace stable action IDs or signals.
- `Simple Cards v2` is the strongest Godot-native editor reference, but its addon is not a drop-in runtime dependency for this project. Reuse its ideas for editor preview, layout metadata, animation Resources, and QA navigation.
- `Phase` is the strongest table-composition reference, but its MTG-specific art, symbols, names, card text, and payment rules are outside scope.
- AGPL references (`Hypnagonia`, `godot-card-game-framework`, `GodotOS`) are observation-only unless the repository deliberately changes licensing policy.
- The detailed adoption, cutover, and zero-reference deletion plan is `docs/card_table_menu_reference_adoption_plan.md`.

## Menu Navigation And Strategy-Screen References

The current `MenuOverlay`, scene-owned menu pages, and `CodexNavigationRuntimeController` remain authoritative. These references are inputs to a future global back-stack cutover, not permission to install a second menu framework.

| Reference | Useful pattern | Copy and ownership boundary |
| --- | --- | --- |
| [Maaack Godot Game Template](https://github.com/Maaack/Godot-Game-Template) | Main menu, options, pause, scene loading, accessibility, controller focus, and shared page lifecycle. | MIT. Adapt focused Godot patterns into the existing scenes; do not add another menu root or global state owner. |
| [Chickensoft GameDemo](https://github.com/chickensoft-games/GameDemo) | Testable `menu -> game -> pause -> save/load` state transitions and lifecycle boundaries. | MIT, Godot C#. Translate state boundaries into local GDScript and tests; do not add a parallel C# framework. |
| [FreeOrion](https://github.com/freeorion/freeorion) | Central star map, top resources, side intelligence, production/research windows, and strategic alert hierarchy. | GPL-family code and separately licensed assets. Product-study only; verify every directory before any reuse. |
| [Unciv](https://github.com/yairm210/Unciv) | Dense strategy information, map-plus-modal composition, and adaptive desktop/mobile layout. | MPL-2.0. Current use is behavior/layout study only; copied source would require file-level compliance. |
| [OpenRA](https://github.com/OpenRA/OpenRA) | Consistent visual language across lobby, campaign, settings, and in-game sidebars. | GPL-3.0. Product-study only; do not copy code or original-game assets. |
| [Godot UI Navigation System](https://github.com/levinzonr/godot-ui-navigation-system) | Push/pop graph, transitions, history, and focus restoration. | MIT but early-stage. Reimplement the small pattern locally after characterization; do not install it as another authority. |
| [AppNavigation](https://godotengine.org/asset-library/asset/4813) | App-like routes and page stack in Godot 4.5. | AGPL-3.0. Observation only unless repository licensing changes explicitly. |
| [SuperTuxKart](https://github.com/supertuxkart/stk-code) | Mature nested menus, gamepad focus, Esc behavior, confirmations, and lobby flows. | GPL. Behavior study only. |

The target back-action precedence is fixed for future implementation:

1. Close the top confirmation, card detail, tooltip, or modal.
2. Pop a secondary page and restore the previous focused control.
3. During a match, toggle pause instead of leaving the match.
4. At the root main-menu page, show exit confirmation.
5. During a future route-placement mode, first back cancels the preview; a second back exits placement mode.

`main.gd` currently contains direct Esc branches for fullscreen map and menu visibility. Those branches are retirement candidates only after a single global navigation owner proves the same ordering, focus restoration, and action-id behavior.

## Trade-Network And Pipeline Interaction References

### Godot primitive boundary

- [`Line2D`](https://docs.godotengine.org/en/stable/classes/class_line2d.html) is a renderer. It may display a preview or committed route, but it must not own product inventory, direction, capacity, cost, player identity, blockage, or payout state.
- [`AStar2D`](https://docs.godotengine.org/en/stable/classes/class_astar2d.html) is a path-search helper. Route legality, edge weights, ownership, deterministic tie-breaks, and blocked-node semantics remain game rules.
- [`GraphEdit`](https://docs.godotengine.org/en/stable/classes/class_graphedit.html) provides connection editing. The application must validate each connection and decide what the connection means. Prefer it for editor/QA authoring, not as the live table or runtime graph owner.

### Product references

| Reference | Useful pattern | Boundary for Space Syndicate |
| --- | --- | --- |
| [Mindustry](https://github.com/Anuken/Mindustry) | Legal/illegal preview, automatic orientation and corners, continuous drag construction, bridges, and segment undo. | GPL-3.0. Observe interaction only; no code or art copying. |
| [shapez.io](https://github.com/tobspr-games/shapez.io) | Directed production nodes, split/merge, throughput, blueprints, and large network update structure. | GPL-3.0. Observe data-flow concepts only. |
| [OpenLoco](https://github.com/OpenLoco/OpenLoco) | Drag build markers, curves/slopes, invalid terrain feedback, demolition, and blueprint rotation. | MIT code is a strong implementation reference, but the original game assets required by OpenLoco are not reusable here. |
| [Widelands](https://github.com/widelands/widelands) | Endpoints as nodes and roads as edges, plus resource movement over a network. | GPL-2.0+ code and mixed asset licenses. Product/data-model study only. |

Ruleset v0.4 currently defines trade routes as derived paths between production and demand. It does not give players a free manual pipeline-build action. Therefore:

- `CityTradeNetworkRuntimeController` remains the only owner of route graph/path selection, flow, disruption, refresh order, GDP inputs, and save normalization.
- `PlanetRouteSegment` and future `Line2D` children consume public route snapshots only.
- A route-placement gesture can be prototyped only as a non-committing editor/QA surface until a later ruleset explicitly defines cost, capacity, direction, ownership, cancellation, and save behavior.
- If manual infrastructure becomes a rule, its committed graph must be incorporated into `CityTradeNetworkRuntimeController`; a second `PipelineGraph` runtime authority is forbidden.
- Pure pipeline textures and models are not a core dependency. The retained visual candidates are Kenney UI Pack - Sci-Fi and UI Minimalism SciFi, both CC0.

The adoption, deletion, and future sprint sequence is recorded in `docs/navigation_trade_network_reference_adoption_plan.md`.

## Economy, Card-Rule, And Monster-Rule References

### Economy and GDP

| Reference | What to learn | Runtime boundary |
| --- | --- | --- |
| [Project Alice](https://github.com/schombert/Project-Alice) | Separation of goods, population, production, and macroeconomic updates. | GPL-3.0 and dependent on original-game assets. Architecture study only. |
| [Unknown Horizons](https://github.com/unknown-horizons/unknown-horizons) | A smaller production-demand-tax-trade loop and readable settlement upgrades. | GPL-2.0. Study the loop, then express any accepted rule through current Resources and controllers. |
| [FreeOrion](https://github.com/freeorion/freeorion) | Empire/universe/combat/script boundaries, planetary allocation, and threats. | GPL-family code with asset-specific licensing. Study only. |
| [OpenVic-Simulation](https://github.com/OpenVicProject/OpenVic-Simulation) | Data objects and deterministic daily/monthly update organization. | MIT is permissive, but do not import a second simulation runtime; small patterns require attribution and local rewrite. |
| [BEA value-added definition](https://www.bea.gov/help/glossary/value-added) | Gross output minus intermediate inputs, preventing intermediate goods from being counted repeatedly. | Use first as an offline diagnostic. The current v0.4 GDP profile remains authoritative until a versioned design decision and parity/balance gate approves a formula change. |

The proposed value-added equation is useful for a sandbox report:

```text
facility_value_added = output_quantity * market_price - intermediate_input_value
planet_gdp = sum(facility_value_added) + product_taxes - subsidies
tax_revenue = planet_gdp * effective_tax_rate * collection_efficiency
real_growth = current_real_gdp / prior_real_gdp - 1
```

It must not silently replace `GdpFormulaRuntimeController`. The first deliverable should compare the current game GDP, value-added diagnostic GDP, double-count exposure, and player-facing pacing under fixed fixtures.

### Card rules and offline balance

| Reference | What to learn | Runtime boundary |
| --- | --- | --- |
| [CSBCGF](https://github.com/finkmoritz/csbcgf) | State changes only through actions, pre-execution legality recheck, queued reactions, explicit events, and simultaneous action groups. | MIT. Convert these ideas into conformance tests around the existing Eligibility, Queue, and Execution services; do not add another card engine. |
| [boardgame.io](https://github.com/boardgameio/boardgame.io) | View-independent moves, phase permissions, logs, replay, testable bots, and state synchronization. | MIT. Space Syndicate is realtime with a 30/25/5 shared window, so use boundaries and tests, not its turn loop as a replacement. |
| [OpenSpiel](https://github.com/google-deepmind/open_spiel) | Simultaneous/sequential actions, imperfect information, multi-player evaluation, and game-solving experiments. | Apache-2.0. Optional offline adapter only; never a player runtime dependency or source of private-state leakage. |
| [Forge](https://github.com/Card-Forge/forge) | Complex trigger, replacement, continuous-effect, priority, and card-AI organization. | GPL-3.0 and MTG-specific content. Observation only. |

CSBCGF's strongest immediately applicable checks are: queue authorization and execution authorization are separate; every queued action is revalidated immediately before mutation; a failed revalidation produces no partial mutation or reactions; effects declared simultaneous take their state snapshot before any participant is removed.

### Monster rules and consequence chain

| Reference | What to learn | Runtime boundary |
| --- | --- | --- |
| [Godot Roguelike Example](https://github.com/statico/godot-roguelike-example) | Godot 4 action components, behavior trees, factions, damage types, resistance, status, and data-driven monster definitions. | MIT code; bundled art has separate licenses. Study component boundaries without changing the realtime autonomous-monster rules. |
| [OpenXcom](https://github.com/OpenXcom/OpenXcom) | Target scoring, hit/armor/facing, morale, panic, and tactical mission state. | GPL-3.0; original game assets are not open. Observation only. |
| [Cataclysm: DDA](https://github.com/CleverRaven/Cataclysm-DDA) | Broad monster data, special attacks, resistance/status vocabulary, and the pathfinding cost of multi-tile creatures. | Strong copyleft/share-alike material with file-specific obligations. Observation only. Keep a giant monster as one logical pathfinding entity with a larger presentation footprint. |

The desired consequence chain is `monster intent -> explicit world damage/disruption receipt -> city/route/market refresh -> next GDP calculation`. A monster action must not bypass world owners by directly editing GDP. Current `MonsterRuntimeController`, `CityTradeNetworkRuntimeController`, `ProductMarketRuntimeController`, and `GdpFormulaRuntimeController` should be audited against this chain rather than replaced.

The full adoption and retirement plan is `docs/runtime_rule_reference_adoption_plan.md`.

## Giant Monster Combat Reference Pack / 巨兽战斗参考包

### Product boundary

Space Syndicate is not becoming a continuously controlled 3D kaiju brawler. Its monsters remain probability-driven actors whose movement, attacks, city damage, route pressure, and economic consequences are resolved by the game rules. These references are for improving monster identity, action readability, destruction staging, camera language, VFX/audio feedback, and the asset pipeline.

Do not copy GigaBash, Godzilla, Ultraman, Gamera, or other protected character names, silhouettes, signature attacks, logos, UI, audio, or story material. A CC0 base mesh does not make a derivative design of protected IP safe.

### Verified permissive reference set

| Reference | License / contents | What to study or prototype | Space Syndicate landing zone | Do not do |
| --- | --- | --- | --- | --- |
| [Quaternius Ultimate Monsters](https://quaternius.com/packs/ultimatemonsters.html) | CC0; 50 animated monsters in FBX, OBJ, Blend, and glTF. | Silhouette families, locomotion contrast, attack anticipation, hit reaction, death/retreat pose, and scale tiers. | `scripts/monster_art_view.gd`, bestiary profiles, monster action review captures, optional isolated import spike under `assets/third_party/`. | Do not assign one pack or one body family to the whole roster; do not ship unmodified placeholder designs as the final identity layer. |
| [Quaternius Animated Mech Pack](https://quaternius.com/packs/animatedmech.html) | CC0; 4 animated mechs in FBX, OBJ, Blend, and glTF. | Mechanical weight, turn rate, recoil, charge-up timing, and biological-versus-mechanical silhouette separation. | Military/monster visual profiles, bestiary reference sheets, future showcase-only animation spike. | Do not turn military units into player-controlled action characters or erase their weaker support-force role. |
| [Quaternius Animated Monster Pack](https://quaternius.com/packs/animatedmonster.html) | CC0; 4 animated monsters. | Small reference set for punch, attack, jump, flight, walk, and animation import testing. | A disposable Godot import bench or monster motion profile documentation. | Do not treat its low-poly style as the final art direction without a separate visual-direction decision. |
| [Kenney City Kit (Commercial)](https://kenney.nl/assets/city-kit-commercial) | CC0; 50 commercial-city models. | Skyline hierarchy, landmark readability, dense city clusters, and intact/damaged/destroyed visual tiers. | City/region art studies, destruction contact sheets, optional off-table 3D showcase bench. | Do not replace the readable planet board with a dense 3D city or add physics debris to the main table without a budget. |
| [Kenney City Kit (Suburban)](https://kenney.nl/assets/city-kit-suburban) | CC0; 40 suburban-building models. | Low-density district language and contrast with commercial cores. | District visual taxonomy and region-state reference sheets. | Do not use building count as a substitute for current city-share, GDP, route, and damage information. |
| [Godot Destruction Plugin](https://github.com/Jummit/godot-destruction-plugin) | Code MIT; other files CC0. Uses Blender Cell Fracture and an intact-to-fragmented scene swap. | The event boundary `intact -> impact -> fragmented`, pre-fracture workflow, center-of-mass setup, and small rigid-body budgets. | Monster action VFX staging, city-damage presentation contract, future isolated destruction benchmark. | Do not install it directly into production before profiling; its own README says it was tested only in small scenes. |
| [Godot 4 Smooth Destructible Terrain](https://github.com/ape1121/Godot4-3D-Smooth-Destructible-Terrain) | MIT; chunked terrain modification demo. | Dirty-chunk regeneration, bounded updates, and local modification rather than full-world rebuilds. | `scripts/map_view.gd` performance reasoning and future local-projection damage overlays. | Do not replace the spherical `MapView`, current region ownership model, or board-game information hierarchy. |
| [Kenney 3D Platformer Starter Kit](https://github.com/KenneyNL/Starter-Kit-3D-Platformer) | Code MIT; included models, sprites, and sounds CC0. | Camera orbit/zoom separation, controller boundaries, gamepad input, and scene organization. | Future showcase camera/input experiments and Godot coding conventions. | Do not introduce continuous monster control into the core rules. |
| [Godot Demo Projects](https://github.com/godotengine/godot-demo-projects) | MIT official demonstrations. | Engine-supported animation, input, physics, scene, and resource patterns. | Any implementation spike that needs an official baseline before community code is considered. | Do not copy a demo wholesale when a smaller local pattern is enough. |
| [Kenney Particle Pack](https://kenney.nl/assets/particle-pack) | CC0; 80 VFX/particle files. | Impact flash, dust, shockwave, warning, destruction, and skill-event vocabulary. | Visual event registry, pooled VFX, monster action review captures. | Do not hide the target, damage tier, or economic consequence under particles; feedback must remain readable at table scale. |
| [CC0 Deep Monster Roar](https://opengameart.org/content/cc0-deep-monster-roar) | CC0 WAV monster roar. | Temporary summon, reveal, threat-escalation, and major-action audio cue. | Audio event registry and temporary monster SFX source. | Do not reuse one roar for every monster identity; use it only as a prototype cue unless differentiated. |

### Required workflow before importing any file

1. Start with a reference-only spike. Record the exact upstream URL, version or download date, author, license, and files being evaluated.
2. Import only the minimum files needed for one isolated proof. Put accepted external files under `assets/third_party/<source_id>/`, include the upstream license/readme, and register them in `docs/third_party_assets.md`.
3. Keep source identity explicit in runtime profiles (`visual_source_id`, `upstream_source_id`, motion/VFX/audio profile ids). Do not hide provenance in an import folder.
4. Convert the useful idea into Space Syndicate's data-driven contracts. Monster rules and probabilities stay outside presentation components; visuals consume resolved public events.
5. Run the existing art identity, visual snapshot, layout, and smoke gates. For a real 3D/destruction spike, add a separate benchmark with a fixed rigid-body/debris count and capture before/after frame-time evidence.

### How developers should apply the references

- **Monster design:** use the three Quaternius packs to build a motion vocabulary matrix—heavy walk, agile leap, flight, recoil, charge, ranged release, hit stun, retreat—then assign distinct combinations to current monster action profiles. The final monster names, silhouettes, materials, effects, and signature actions must remain original.
- **City damage:** use the Kenney city packs for size and density studies. Represent gameplay state first: healthy, pressured, damaged, disabled, destroyed. Each state must still expose city share, GDP/route consequence, owner-safe public information, and repair opportunity.
- **Destruction:** borrow the destruction plugin's pre-fractured swap pattern for presentation, but let the authoritative result come from the existing monster/city/economy runtime. Spawn bounded debris after resolution; never make physics determine rules, ownership, damage, or GDP.
- **Planet/map performance:** borrow dirty-chunk and local-regeneration ideas from the terrain demo only for local projection overlays or cached damage decals. Preserve the scalable globe and current map interaction contract.
- **Camera/input:** use the Kenney starter kit only if a future bestiary/showcase scene needs orbit, zoom, or gamepad inspection. Main gameplay remains the board-game table and monsters remain auto-acting.
- **VFX/audio:** map particle and roar references to public event stages: warning/telegraph, impact, target response, aftermath/economic consequence. Pool frequent effects and provide visual cues when audio is disabled.

### Acceptance gates for any derived implementation

- The reference must improve a current Space Syndicate requirement: monster identity, public action readability, city/route consequence, performance, or art-production workflow.
- A monster action must read in order: actor, telegraph, target, impact, state change, economic consequence.
- No imported reference may bypass `visual_source_id` / `upstream_source_id`, the third-party asset register, or license preservation.
- No single external body or audio pack may become the universal identity for the roster.
- Destruction must have a fixed debris/rigid-body lifetime budget and must not rebuild the main map or UI tree every frame.
- The core rule remains unchanged: monsters auto-act from data/probability tables; players influence them through cards and systems rather than direct continuous control.

## Immediate Application Plan

- `HandRack`: compare against `gcard_layout`, `godot-simple-card-pile-ui`, `UiCard`, and `CardHouse` for spread curves, hover lift, and drag/drop boundaries.
- `HandRack`: port the permissive-reference structure first. `pipeworks-studios/CardHouse` (CC0) provides the position/rotation/scale seeker model; `mixandjam/balatro-feel` (MIT) provides the hover/selection/hand-reflow feel. Current Godot implementation rewrites those ideas in `scripts/HandLayout.gd` instead of importing Unity/C# files.
- `HandRack v2 current port`: `scripts/HandLayout.gd` now rewrites the permissive card-rack feel as local GDScript profiles (`single_focus`, `comfortable`, `compressed`, `pressure`). The copied patterns are structural only: CardHouse-style target position/rotation/scale metadata and seeker motion, Balatro-Feel-style hover lift plus neighbor reflow, and UiCard-style hand spacing/drop-zone affordance. No Unity/C# source, GPL/AGPL/LGPL source, external assets, or reference UI text was pasted into the repo.
- `HandRack / CardFace Commercial Feel v3`: this pass continues the same copy boundary and ports only product structure and tunable feel parameters. CardHouse-style seeker / gate patterns become local `HandLayout` selected/drag state targets and UI-only drag release signals. Balatro-style hover elasticity is represented through stronger lift/scale, selected focus, invalid-drop rebound, and z-index separation. UiCard-style hand spacing / pivot / lift remains in the fan/arc profiles, pressure spacing, hover lift, and drop-zone metadata. Godot card plugin references such as simple-cards-v-2, card-framework, and gcard_layout are used only for Control component boundaries: card data stays in snapshots, CardFace renders presentation specs, HandRack owns hover/selection/drag signals, and rules stay in `main.gd`. No Unity/C# source, JS source, GPL/AGPL/LGPL source, external assets, trademarks, or reference UI text was pasted into the repo.
- `Hearthstone-grade Vertical Slice v1`: this pass copies only commercial product structure from collectible-card battlers: readable play table, tactile hand-card object flow, target arrow, card-play flyout, monster attack read order, resource floats, audio hooks, and frame-sequence QA. It does not copy Blizzard IP, Hearthstone card frames, icons, card backs, art, text, trademarks, or gameplay rules. Open-source card references remain structural only: CardHouse-style deterministic event/seeker staging, Balatro-Feel-style juice timing vocabulary, UiCard-style target/drop feedback, and Godot card-plugin separation between data, visual surface, hand layout, drag signal, and rules.
- `OverlayLayer`: compare against VASSAL module/layer separation and Maaack menu shell; transient surfaces should become scenes under `scenes/ui/`.
- `main.gd` controller split: use boardgame.io as the conceptual reference for rules/moves/logs staying view-layer agnostic.
- `PlayerBoard`: use Terraforming Mars as the strongest product reference for first-glance resource/goal/tableau composition, without copying GPL code.
- `Codex/Menu`: use Maaack menu structure and VASSAL-style module pages as references for moving 3-minute information out of the main table.
- `MenuRootLobby`: copy the commercial entry rhythm first: one dominant visual, one clear primary-command column, and auxiliary buttons below. Use permissive references for implementation patterns only; do not paste GPL menu code or assets.
- `PlanetBoard`: copy the board-game/video-game stage composition before ornamentation: a square central play surface, thin side HUDs, and background space outside the projection boundary. Dense labels and callouts should appear only when zoom/focus justifies them.
- Current menu/planet pass: borrowed the product structure from commercial board-game/digital-table references rather than external assets or GPL code: dominant planet visual, numbered right-side command tower, square central board, side orbit rails, and low-density map labels.
- Current MiniCard pass: copied the common TCG/deckbuilder information hierarchy rather than card text density: hand cards show cost, short name, route/type, rank, a large art anchor, keyword chips, and a 2-3 line use summary; hover scales the card into a readable state while full rules stay in inspector/drawer/Codex.
- Card/monster art baseline: the repository currently uses the attributed Night Patrol UI frame/sigil pack, MIT `Moth-Fried-Games/moth-kaijuice`, CC0 `victrolaface/monster_battler`, CC0 Kenney sprite references, CC0 `rakkarage/PixelMob`, and CC0 `sparklinlabs/superpowers-asset-packs` monster bodies. `CardArtView` now uses a multi-source temporary card-illustration layer with per-card `visual_source_id`, route-aware source selection, local composition/color/effect/motif variants, and a ten-source-family minimum gate. `MonsterArtView` uses a multi-source body-art roster: Moth/MOS kaiju body art is limited to one monster family, every current monster must have a distinct body sprite key plus `visual_source_id`, at least five upstream body-art packs must appear in the current roster, and no single pack may supply more than 35% of the roster. Copied files and licenses are logged in `docs/third_party_assets.md`.
- Art production gate: `docs/art_production_contract.md` and `tests/art_identity_gate_test.gd` now require every card, monster, and monster action slot to have a unique visual/motion profile before this phase can be considered complete. `tests/art_contact_sheet_capture.gd` generates overview sheets under `reports/art/`; `tests/card_runtime_review_capture.gd` generates per-card first-run review sheets under `reports/art/card_reviews/` so cards that are technically unique but visually too similar can be caught by human review.
- Reference standard for future card UI/code study: `twdoor/simple-cards-v-2`, `chun92/card-framework`, and `insideout-andrew/simple-card-pile-ui` are suitable Godot card layout/interaction references; adapt structure and interaction feel, not unvetted art or text.
