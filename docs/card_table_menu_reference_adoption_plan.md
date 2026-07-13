# Card, Table, Menu Reference Adoption And Retirement Plan

Status: reference set accepted, implementation not started
Recorded: 2026-07-14

## 1. Decision

Space Syndicate should adopt the new references as a presentation and production-workflow benchmark, not as replacement game engines.

The project already has authoritative runtime ownership for card definitions, eligibility, queueing, execution, presentation snapshots, public tracks, the right inspector, and menu navigation. Replacing those systems with a plugin or Unity template would create parallel ownership and undo the modularization work. The useful opportunity is narrower and more valuable:

- make card layouts and feel profiles editable in Godot;
- unify the hand, market, track, Codex, and inspector around one card visual grammar;
- unify table controls, HUD icons, menus, focus, accessibility, and responsive behavior;
- replace temporary mixed-source card frames and scattered style construction;
- preserve all action IDs, signals, privacy rules, and runtime services.

No external asset or source file was downloaded as part of this planning pass.

Global back-stack behavior and trade-route/pipeline references are intentionally separated into `docs/navigation_trade_network_reference_adoption_plan.md`. Economy, card-rule, offline balance, and monster-consequence references are tracked in `docs/runtime_rule_reference_adoption_plan.md`. Those plans share the same hard rule: improve the existing owner, then delete the replaced path; never add a parallel engine.

## 2. Current Project Audit

### Keep As Authoritative

| Area | Current owner | Decision |
| --- | --- | --- |
| Card definitions and Inspector authoring | `CardRuntimeCatalogService`, card `.tres` Resources, Runtime Card Authoring Workspace | Keep. External card plugins may inform editor UX but cannot become a second catalog. |
| Play legality and targets | `CardPlayEligibilityRuntimeService` | Keep. UI references do not own rules. |
| Shared group window and queue | `CardResolutionRuntimeController`, `CardResolutionQueueRuntimeService` | Keep. Phase-like stack presentation consumes snapshots only. |
| Effect execution | `CardResolutionExecutionRuntimeService` and effect-family services | Keep narrow. No visual reference may add gameplay formulas here. |
| Card presentation data | `CardPresentationRuntimeService`, `GameTableViewModelRuntimeService` | Keep. New scenes consume their pure-data output. |
| Public resolution surface | `CardResolutionTrack.tscn`, `PublicTrack.tscn` | Keep as scene owners. Restyle and improve motion without changing signal semantics. |
| Detail surface | `RightInspector.tscn`, Card Codex scenes | Keep. Improve hierarchy and icons without duplicating detail logic. |
| Menu navigation | `MenuOverlay.tscn`, `MenuRootLobby.tscn`, scene-owned menu pages | Keep. Maaack patterns improve focus/navigation/loading around this shell. |

### Presentation Debt Suitable For Replacement

| Finding | Evidence | Target |
| --- | --- | --- |
| Two card-scene entry points | `CardFace.tscn` currently instances root-level `CardUI.tscn`; repository references both paths. | Make `scenes/ui/CardFace.tscn` the one canonical player-facing scene, then remove the root legacy scene/script after zero references. |
| Temporary Night Patrol card skin | Eight UI art files are hardcoded through `scripts/card_art_view.gd`. | Replace with a project-owned card skin assembled from a curated CC0 prototype subset and Space Syndicate colors/typography. |
| Mixed icon ownership | Ten CC BY Game-icons SVGs are hardcoded in `card_art_view.gd`; other controls use text glyphs or local symbols. | Introduce semantic icon IDs and an icon catalog. Prefer Kenney CC0 coverage; retain only genuinely missing Game-icons with per-author attribution. |
| Scattered style construction | Current audit finds 95 `StyleBoxFlat.new()` calls, 269 script `add_theme_stylebox_override()` calls, and 46 scene-local style overrides. | Move stable visual states to `Theme`, theme type variations, and reusable StyleBox/skin Resources. Keep runtime-created style only for truly data-driven colors. |
| Hand feel stored as script constants | `HandLayout.gd` has many exported values, but no reusable named feel Resource shared by QA/editor workflows. | Add Resource-backed hand feel profiles and editor preview; keep `HandRack` as interaction owner. |
| Menu/Card/HUD skins vary by surface | Menu, Codex, track, overlay, authoring, and table scripts create similar panels independently. | Establish one player-facing skin and a separate high-contrast developer/QA skin. |

## 3. Reference Adoption Matrix

### Tier A: Direct Pattern Candidates

| Reference | Adopt | Do Not Adopt |
| --- | --- | --- |
| Simple Cards v2, MIT | Editor-visible card layouts, layout metadata, data/layout separation, animation Resources, hand/deck preview ideas. | Do not install as a second runtime catalog, deck owner, or rules layer. |
| CardHouse, CC0 | Target position/rotation/scale model, group layout, drag boundaries, phase/pile organization. | Do not import Unity runtime or create a parallel card state machine. |
| UiCard, MIT code | Fan spacing, hover magnification, neighboring-card displacement, opponent-hand representation, drop-zone feedback. | Do not import externally sourced illustrations or Unity-specific runtime dependencies. |
| Balatro-Feel, MIT | Small continuous motion, hover elasticity, selection snap, reveal and settlement pacing. | Do not reproduce Balatro art, shaders, branding, sounds, or exact visual identity. |
| Maaack Game/Menu Templates, MIT | Focus navigation, controller support, options/pause/accessibility/loading page boundaries, scene-loader failure handling. | Do not add a second menu root or replace stable Space Syndicate action IDs. |

### Tier B: Product And Architecture Study

| Reference | Adopt | Boundary |
| --- | --- | --- |
| Phase, MIT/Apache-2.0 | Table hierarchy, public stack, target arrow, payment state, hidden information, animation staging. | No MTG names, symbols, rules, Scryfall images, or other card art/data. |
| NueDeck, MIT | Authoring/editor workflow, reward/content organization, validation concepts. | Existing Godot Resources and Runtime Catalog remain authoritative. |
| Hypnagonia, AGPL-3.0 | Godot deckbuilder product flow, state display, Codex and thematic organization. | Observation only; no code/assets copied. |
| Godot Card Game Framework, AGPL-3.0 | Scene and rules-boundary comparison. | Observation only unless repository licensing policy explicitly changes. |
| GodotOS, AGPL-3.0 | Window hierarchy, sidebar rhythm, icon consistency, dark UI restraint. | Observation only; repository also includes separately sourced assets. |

### Tier C: Curated Prototype Assets

| Role | Primary source | Secondary source | Policy |
| --- | --- | --- | --- |
| Card trim and mechanical HUD accents | Mechanized Magic, CC0 | Project-owned vector/StyleBox shapes | Import one selected style only; recolor and recombine into Space Syndicate identity. |
| Buttons, sliders, panels, modal states | Kenney UI Pack - Sci-Fi, CC0 | Kenney UI Pack, CC0 | Sci-Fi pack is primary. General pack fills missing control states only. |
| Resource, pile, bid, turn, operation icons | Kenney Board Game Icons, CC0 | Kenney Board Game Info, CC0 | Route every icon through semantic IDs. |
| Rules, tutorial, requirement, warning icons | Kenney Board Game Info, CC0 | selected Game-icons.net icons | Game-icons are fallback only and require per-author CC BY 3.0 attribution. |
| Table pieces, chips, piles, neutral card backs | Kenney Board Game Pack / Playing Cards Pack, CC0 | Project-owned shapes | Prototype/readability use only; do not let generic playing-card art define the brand. |
| Dark HUD graybox | SCIFI UI, CC0 | none | Reference/prototype tier; do not mix visibly with the chosen production skin. |
| Developer/QA high-contrast skin | Wenrexa White UI Kit, CC0 | project Theme | Keep distinct from the player-facing table unless adopted as an explicit accessibility theme. |

## 4. Target Visual Language

The selected references are ingredients, not a collage. The target remains recognizably Space Syndicate:

- central spherical planet as the primary table object;
- bottom fan hand with stable selected state;
- thin anonymous public resolution track;
- material resource chips and compact action area;
- right-side inspector for reason, requirement, target, and action;
- mechanical orbital framing rather than fantasy ornament;
- restrained dark neutral surfaces with distinct economic, monster, intelligence, contract, weather, and military accents;
- no copyrighted card-game frames, symbols, names, or signature visual effects.

One component may use one primary skin family. Mechanized Magic card trim, Kenney controls, SCIFI UI panels, and Wenrexa panels must not all appear on the same player-facing surface.

## 5. Retirement Matrix

### Eligible For Large-Scale Retirement After Cutover

| Candidate | Planned action | Deletion gate |
| --- | --- | --- |
| `assets/third_party/night_patrol/ui/card-frame-*.png` | Replace all four frames with the new card skin. | Card hand, supply, track reveal, inspector, Codex, authoring workspace, and screenshots use the new skin; source references reach zero. |
| Night Patrol `card-sigil.svg`, `panel-talisman.png`, `button-blue.png`, `button-red.png` | Remove from card composition after equivalent project-owned/CC0 trim and controls exist. | `card_art_view.gd`, scenes, tests, and docs no longer require these files. Keep historical provenance in documentation. |
| Root `scenes/CardUI.tscn` and `scripts/CardUI.gd` legacy entry | Move the canonical node tree/API to `scenes/ui/CardFace.tscn` and `scripts/ui/card_face.gd`; update all callers. | Runtime, authoring, Codex, supply, QA, and tests have zero old-path references; no compatibility wrapper remains. |
| Repeated script-created panel/button styles | Replace stable states with `GameTheme` type variations and reusable style Resources. | Visual parity at all required resolutions; script style creation reduced by at least 75%; runtime-data accent cases documented. |
| Repeated scene-local menu/card styles | Replace duplicate styles with named Theme variations. | Focus, hover, pressed, disabled, selected, warning, and high-contrast states remain visibly distinct. |
| Text glyphs used as semantic icons | Replace with semantic icon catalog entries where a vetted icon exists. | Localization, font fallback, controller focus, and color-blind checks pass. |
| CC BY Game-icons equivalents | Replace with Kenney CC0 icons when semantic clarity is equal or better. | Exact semantic mapping and screenshots pass; attribution records remain in history. |
| Old UI screenshots and contact sheets | Regenerate against the new skin and archive obsolete review artifacts according to project report policy. | New baseline is accepted and paths are no longer used by tests/docs. |

### Keep Unless A Separate Audit Proves Redundancy

- Night Patrol BGM and non-card audio: not replaced by this UI plan.
- Monster body art and monster presentation references: handled by the giant-monster presentation track.
- Card artwork composition logic: `CardArtView` may be refactored, but its public presentation role remains until a separate art-production cutover replaces it.
- Runtime services, card Resources, action IDs, signals, save data, and privacy filters.
- `CardResolutionTrack`, `RightInspector`, `HandRack`, `MenuOverlay`, and `MenuRootLobby` scene contracts.
- Third-party license/provenance records, even after runtime assets are retired.

## 6. Zero-Reference Deletion Gate

An old asset, scene, script, or style system can be deleted only when all conditions are true:

1. A replacement exists in a Godot-editable scene, Theme, or Resource.
2. All player-facing surfaces have switched to it.
3. `rg` reports zero production and test references to the old path/API.
4. The new source and license are registered in `docs/third_party_assets.md` before files enter `assets/third_party/`.
5. Card Authoring, Runtime Card Catalog, First Mission, layout, focus-order, composition, privacy, and screenshot gates pass.
6. Godot reports no parse, runtime, missing-node, missing-signal, or scene-load errors.
7. A before/after screenshot set and deletion manifest are saved under `user://space_syndicate_design_qa/`.

There is no "delete first and rebuild later" path for assets currently referenced by the live table.

## 7. Development Roadmap

### Presentation Sprint A: Reference Intake And Skin Lab

- Import only a minimal subset: one Mechanized Magic style, the required Kenney Sci-Fi control states, and 20-30 candidate Kenney board/info icons.
- Store each source under `assets/third_party/<source_id>/` with upstream license/readme and registration.
- Create one Godot-editable card/table/menu skin lab using real `CardFace`, `HandRack`, `CardResolutionTrack`, `RightInspector`, and menu scene instances.
- Compare six real cards across hand, selected, disabled, track, inspector, and Codex states.
- Do not change production defaults in this sprint.

### Presentation Sprint B: Theme And Semantic Icon Foundation

- Add named Theme variations for card, table panel, modal, menu command, compact chip, warning, disabled, selected, and QA surfaces.
- Add a semantic icon catalog using IDs such as `cash`, `gdp`, `product`, `route`, `contract`, `intel`, `monster`, `bid`, `queue`, `target`, and `warning`.
- Prefer Kenney CC0 sources; retain attributed Game-icons only where they are clearer.
- Replace stable script-created StyleBoxes while preserving runtime accent colors as data.

### Presentation Sprint C: Canonical CardFace Hard Cutover

- Make `scenes/ui/CardFace.tscn` the only card face scene.
- Preserve existing snapshot API and click/double-click signals.
- Apply the new skin to hand, district supply, resolution reveal, inspector, Codex, and authoring workspace.
- Remove `CardUI.tscn`, `CardUI.gd`, and Night Patrol UI card assets only after the zero-reference gate passes.

### Presentation Sprint D: Hand Feel Profiles And Target Feedback

- Convert `HandLayout.gd` tuning into Inspector-editable Resource profiles for comfortable, compressed, pressure, reduced-motion, and controller-focused states.
- Reuse existing `HandRack` selection/hover/drag signals.
- Add scene-owned target arrow and payment/requirement feedback inspired by Phase and UiCard, consuming Eligibility/Queue snapshots only.
- Do not move target legality or payment rules into UI.

### Presentation Sprint E: Table And Inspector Unification

- Apply the shared skin/icon language to `CardResolutionTrack`, `PublicTrack`, `RightInspector`, `OverlayLayer`, supply drawer, and action dock.
- Keep anonymous ownership and privacy filters intact.
- Ensure actor, target, cost, response window, disabled reason, and resolution state can be read without opening full rules text.

### Presentation Sprint F: Menu, Settings, Loading, And Accessibility

- Adapt Maaack/Chickensoft-style navigation, focus, loading, and lifecycle patterns into existing menu scenes.
- Consolidate duplicate menu styles into Theme variations.
- Characterize and then hard-cut over the global back stack using the precedence and deletion gate in `docs/navigation_trade_network_reference_adoption_plan.md`.
- Verify keyboard, controller, pointer, back-stack, focus restoration, pause, settings, reduced motion, contrast, and UI audio behavior.
- Keep GodotOS as observation-only structure reference.

### Presentation Sprint G: Asset Retirement And Baseline Reset

- Run the zero-reference deletion report.
- Remove replaced Night Patrol card UI files, root CardUI compatibility files, redundant CC BY icons, and obsolete style builders.
- Regenerate card, table, menu, authoring, and responsive screenshot baselines.
- Record final retained third-party sources and credits.

### Parallel Track: Giant Monster Presentation

The giant-monster/city-destruction plan remains valid and should reuse the same Theme/icon/audio provenance rules. It should begin after the card/table skin foundation is stable enough that monster event callouts and damage states have a consistent HUD language. Physics remains presentation-only and never determines rules, GDP, damage, or ownership.

## 8. Acceptance Targets

- One canonical card scene and one runtime card catalog.
- One player-facing Theme family plus an explicit QA/accessibility variation.
- Stable semantic icon IDs; no new player UI hardcodes third-party file paths.
- At least 75% reduction in script-created stable panel/button StyleBoxes.
- Night Patrol card UI asset references reduced to zero before those eight files are removed.
- Game-icons attribution remains complete for every retained CC BY icon.
- Longest localized labels fit at 1280x720, 1600x960, 1920x1080, and 2560x1440.
- Hover, selected, dragged, invalid-drop, disabled, queued, active, resolved, and hidden-opponent states remain visually distinct.
- Reduced-motion mode communicates every state without relying on bounce or shake.
- No private owner, target, discard, hand, or AI-plan information enters public snapshots.
- Existing runtime, composition, layout, focus, authoring, catalog, first-mission, and error gates remain green.

## 9. Recommended First Implementation

Start with Presentation Sprint A, not a bulk asset replacement. It creates a real Godot comparison surface and proves that one selected Mechanized Magic/Kenney combination can improve the six highest-frequency card states before any production asset is removed.
