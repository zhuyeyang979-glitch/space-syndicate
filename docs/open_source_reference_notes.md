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
| `Maaack/Godot-Menus-Template` | Menu shell, options/settings pages, loading flow, credits/settings separation. | Verify current license before copying; useful for Menu/Codex extraction. |

## Card And Hand References

| Reference | Use for Space Syndicate | Copy stance |
| --- | --- | --- |
| `chun92/card-framework` | Hand/pile manager boundaries, data-backed card resources, drag/hover contracts. | Verify license before copying; compare with `HandRack`. |
| `twdoor/simple-cards-v-2` | Godot card plugin component split: resource, layout, hand management. | Verify license before copying; useful for `CardFace`/`HandRack`. |
| `cyanglaz/gcard_layout` | Hand layout math, spread, hover animation, card positions. | Verify license before copying formulas. |
| `mathrick/godot-simple-card-pile-ui` | Draw/hand/discard piles, drop zones, spread/rotation/vertical curves. | Verify license before copying. |
| `db0/godot-card-game-framework` | Drag-and-drop card framework and scripting boundaries. | AGPL-3.0: study behavior; do not paste code unless license obligations are accepted. |

## Non-Godot Feel References

| Reference | Use for Space Syndicate | Copy stance |
| --- | --- | --- |
| `ycarowr/UiCard` | TCG-like card hover, zoom, hand pivot, drop zone positioning. | Verify license before copying; adapt interaction feel. |
| `pipeworks-studios/CardHouse` | Card groups, phase manager, drag handling, position/rotation/scale seekers. | CC0: good candidate for direct pattern port, rewritten in GDScript. |
| `mixandjam/Balatro-Feel` | Card juice: hover elasticity, snap, reveal timing, small tactile effects. | MIT: safe to adapt small feel patterns with attribution. |
| Kenney UI Pack | Neutral UI panels/icons if current theme needs asset reinforcement. | CC0: usable assets if style matches. |

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
- Card/monster art baseline: the repository currently uses the attributed Night Patrol UI frame/sigil pack, MIT `Moth-Fried-Games/moth-kaijuice`, CC0 `victrolaface/monster_battler`, CC0 Kenney sprite references, and CC0 `sparklinlabs/superpowers-asset-packs` monster bodies. `CardArtView` now uses a multi-source temporary card-illustration layer with per-card `visual_source_id`, route-aware source selection, local composition/color/effect/motif variants, and a ten-source-family minimum gate. `MonsterArtView` uses a multi-source body-art roster: Moth/MOS kaiju body art is limited to one monster family, every current monster must have a distinct body sprite key plus `visual_source_id`, at least four upstream body-art packs must appear in the current roster, and no single pack may supply more than half of the roster. Copied files and licenses are logged in `docs/third_party_assets.md`.
- Art production gate: `docs/art_production_contract.md` and `tests/art_identity_gate_test.gd` now require every card, monster, and monster action slot to have a unique visual/motion profile before this phase can be considered complete. `tests/art_contact_sheet_capture.gd` generates review sheets under `reports/art/`.
- Reference standard for future card UI/code study: `twdoor/simple-cards-v-2`, `chun92/card-framework`, and `insideout-andrew/simple-card-pile-ui` are suitable Godot card layout/interaction references; adapt structure and interaction feel, not unvetted art or text.
