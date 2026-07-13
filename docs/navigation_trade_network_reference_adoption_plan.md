# Navigation And Trade-Network Reference Adoption Plan

Status: reference set accepted, implementation not started
Recorded: 2026-07-14

## 1. Product Decision

The menu/navigation and logistics references should improve two existing product surfaces:

1. one predictable back action across modal, detail, menu page, match pause, and future placement modes;
2. a readable, Godot-editable trade-route surface that exposes direction, flow, disruption, and focus without moving rules into drawing nodes.

They must not create a second menu shell, a second route engine, or a hidden replacement for Ruleset v0.4.

Ruleset v0.4 currently derives trade routes from production, demand, topology, transport factors, damage, and market facts. It does not define a free player action for manually constructing pipelines. The Mindustry, shapez, OpenLoco, and Widelands references therefore inform route visualization, inspection, editor tooling, and a possible future authored rule. They do not authorize a runtime pipeline-building feature today.

## 2. Current Repository Audit

### Navigation

- `MenuOverlay.tscn` is the scene-owned menu shell.
- Scene-owned pages and `MenuRootLobby.tscn` remain the visible menu owners.
- `CodexNavigationRuntimeController` owns Codex branch, return target, domain selection, paging, previews, and the legacy save adapter.
- `main.gd::_unhandled_input()` still directly decides Esc behavior for fullscreen map, menu close, and pause open.
- Back actions are also routed by individual page action IDs. There is no single global surface stack with modal precedence and focus restoration.
- `CodexNavigationRuntimeController` should not be expanded into a catch-all UI manager. It should remain the owner of Codex-local navigation state.

### Trade Network

- `CityTradeNetworkRuntimeController` is already the sole owner of route graph/path selection, cost, disruption, flow, refresh order, project sequence, GDP input composition, and save normalization.
- `CityTradeNetworkWorldBridge` is non-owning and applies receipts exactly once.
- `PlanetMapView` instances real `PlanetRouteSegment.tscn` components for sceneized route display.
- `PlanetRouteSegment.tscn` is currently a bare `Control`; its script still draws lines, dashes, and endpoints through `_draw()`.
- The explicit legacy `scripts/map_view.gd::_draw_trade_routes()` fallback still contains another line renderer even though the sceneized path is the production default.
- Production source currently contains no `AStar2D` or `GraphEdit` route owner and no manual pipeline-placement system.
- The asset tree contains no pipeline/pipe/conduit texture or model pack. There is nothing in that category to delete today.

## 3. Fixed Ownership Boundary

| Concern | Owner | Constraint |
| --- | --- | --- |
| Global visible-surface stack and back precedence | Future `UiNavigationRuntimeController` | Pure stack state and focus tokens only; it does not own page content or gameplay. |
| Codex branch, index, page, filter, return target | Existing `CodexNavigationRuntimeController` | Remains unchanged in purpose; global navigation treats Codex as one surface. |
| Menu/page rendering | Existing scene-owned menu components | Consume pure snapshots and emit stable action IDs. |
| Route graph, path, flow, damage, GDP inputs, save | Existing `CityTradeNetworkRuntimeController` | No parallel `PipelineGraph` runtime authority. |
| World fact capture and receipt application | Existing `CityTradeNetworkWorldBridge` | No scoring, path choice, or persistent state. |
| Route display | `PlanetMapView` and `PlanetRouteSegment` | Public presentation data only. |
| Optional automatic path helper | `AStar2D` inside the route owner only | Allowed only after parity proves deterministic path and tie-break behavior. |
| Optional graph authoring UI | `GraphEdit` editor/QA scene | Writes validated pure Resource data; never becomes live world state. |

## 4. Unified Back-Action Contract

The one global back action must resolve in this order:

1. Close the top confirmation, temporary-decision detail, card detail, tooltip, or modal that declares itself dismissible.
2. Pop the current secondary page and restore the exact prior focus owner.
3. If the match surface is active, open or close pause without leaving the match.
4. If the main-menu root is active, request an exit confirmation rather than quitting immediately.
5. If a future route-placement session is active, first back cancels its current preview; a subsequent back exits placement mode.

Each surface entry should be pure data:

```text
surface_id
surface_kind
parent_surface_id
dismiss_policy
focus_restore_path
opened_by_action_id
context_revision
```

Nodes, Callables, Objects, and Resources are forbidden in navigation snapshots and save/debug output.

## 5. Godot Primitive Contract

### Line2D

Use `Line2D` for the route polyline, preview color, width, and optional visual flow material. Endpoints, direction arrow, product marker, and disruption state should remain explicit scene children or snapshot fields.

Never store these in `Line2D`:

- product inventory;
- capacity or throughput authority;
- construction cost;
- route owner or hidden contributor;
- blockage truth;
- GDP or payout values.

### AStar2D

Do not replace the current deterministic path implementation merely because `AStar2D` exists. A cutover is allowed only if fixed-fixture parity proves:

- identical legal node set;
- identical edge cost;
- identical destroyed/miasma/panic handling;
- identical tie-break and source choice;
- identical RNG consumption, ideally none;
- identical save/public snapshot results.

If parity cannot be proven, retain the current route algorithm.

### GraphEdit

Use `GraphEdit` only for an editor-facing topology/fixture authoring workspace. Connection requests must be passed to a validator that checks endpoint type, direction, duplicate edge, topology rules, and Resource schema before persistence.

The live planet table should remain the globe/map interaction surface, not a node-editor UI.

## 6. Reference Application Matrix

| Reference | Apply to | Do not apply to |
| --- | --- | --- |
| Maaack templates | Existing menu lifecycle, settings/pause consistency, focus and loading failure states. | A second menu root or global state singleton. |
| Chickensoft GameDemo | Testable high-level state transitions and pause/save lifecycle. | C# framework installation or duplicate save owner. |
| FreeOrion / Unciv / OpenRA | Information hierarchy, map-plus-sidebar composition, alerts, responsive density. | Code, assets, IP identity, or a new strategy UI framework. |
| Godot UI Navigation System | Push/pop vocabulary, focus restoration, route graph tests. | Direct plugin dependency after local ownership already exists. |
| AppNavigation / SuperTuxKart | Nested return behavior and production-grade focus/confirmation study. | AGPL/GPL code copying. |
| Mindustry | Legal preview, continuous gesture, auto-corner, bridge, segment undo vocabulary. | GPL code, art, or automatic adoption of conveyor rules. |
| shapez.io | Direction, split/merge, throughput diagnostics, bounded network updates. | GPL implementation or a second simulation clock. |
| OpenLoco | Build markers, invalid terrain feedback, demolition, blueprint rotation. | Original Locomotion assets or an independent track engine. |
| Widelands | Endpoint/edge mental model and public resource-flow readability. | GPL implementation or settlement-economy replacement. |

## 7. Retirement Matrix

### Candidates For Deletion After Cutover

| Candidate | Replacement | Deletion gate |
| --- | --- | --- |
| Direct Esc/full-map/menu/pause branching in `main.gd::_unhandled_input()` | One global navigation controller request plus thin input adapter | All precedence, focus restoration, pointer/controller paths, and action IDs pass in real `main.tscn`. |
| Page-specific back-state duplication in `main.gd` | Stack entries and scene action routing | Call graph proves no remaining producer/consumer; save compatibility stays intact. |
| `PlanetRouteSegment._draw()`, `_draw_dashed_line()`, `_draw_endpoint()` | Static `Line2D` and endpoint/arrow child scenes | Globe/flat projection, zoom, disruption, screenshots, and interaction gates pass. |
| `scripts/map_view.gd::_draw_trade_routes()` and `_draw_trade_segment()` | Sceneized route layer | Explicit legacy fallback has zero production/test use and `legacy_draw_fallback_used=false` remains enforced. |
| Hardcoded route colors and line widths scattered across renderers | Theme/Resource route visual profile | Public states remain distinguishable at all target resolutions and reduced-motion settings. |
| Duplicate route inspection labels/callouts | Route presentation snapshot and RightInspector | No hidden owner/share/AI data enters the public snapshot. |

### Not Deletion Candidates

- `CityTradeNetworkRuntimeController` and its route/path algorithms.
- `CityTradeNetworkWorldBridge` receipt boundary.
- `CodexNavigationRuntimeController` domain state.
- `PlanetMapView`, `PlanetRouteSegment`, and `MenuOverlay` scene contracts.
- Rule, save, action ID, signal, and privacy compatibility.
- Third-party provenance records.

## 8. Development Roadmap

### Sprint N1: Global Back And Focus Characterization

- Completed in Sprint 67 by extending the existing Menu Shell gate rather than adding a duplicate bench.
- Real `main.tscn` now records 32/32 observed cases and 19/32 contract-aligned cases across modal, forced decision, drawer, detail, nested menu, Codex, fullscreen map, pause, root, input, focus, persistence, and deletion boundaries.
- The pure-data surface registry and deletion map live in `scripts/tools/global_ui_navigation_characterization_registry.gd`.
- The behavior and Sprint N2 cutover boundary live in `docs/global_ui_navigation_runtime_contract.md`.
- Production `main.gd` remained byte-identical during characterization.

### Sprint N2: Global Navigation Hard Cutover

- Add one scene-owned `UiNavigationRuntimeController` under the existing runtime composition.
- Keep `CodexNavigationRuntimeController` as the nested Codex owner.
- Route Esc/back, close buttons, page back actions, and focus restoration through one pure-data stack.
- Delete direct legacy branches in the same sprint; no wrapper forest and no parallel fallback.

### Sprint R1: Scene-Owned Route Line Cutover

- Give `PlanetRouteSegment.tscn` editable `Line2D`, endpoint, direction, and disruption children.
- Feed it the current public route snapshot without changing path rules.
- Extend `PlanetMapInteractionBench` for globe/flat projection, zoom, product focus, disruption, reduced motion, and privacy.
- Delete the custom route `_draw` methods after parity.

### Sprint R2: Route Inspection And Flow Readability

- Add route hover/select/focus states using existing PlanetMap signals or narrowly scoped route signals.
- Show product, source type, destination, public flow/speed, disruption, and consequence in RightInspector.
- Use FreeOrion/Unciv information hierarchy and Kenney/UI Minimalism SciFi semantic controls.
- Do not expose controller identity, project shares, hidden owner, private target, or AI plan.

### Sprint R3: Legacy Route Renderer Retirement

- Prove `PlanetMapView` is the only production route renderer.
- Remove the explicit `map_view.gd` trade-route fallback functions and duplicate constants.
- Keep a deletion manifest and before/after screenshots under `user://`.

### Sprint R4: Editor Topology Authoring Workspace

- Only if authored maps/fixtures need it, add a `GraphEdit`-based QA/editor workspace.
- Read/write versioned pure Resources through a validator.
- Reuse the existing City/Trade Network bench for parity; no live game dependency.

### Sprint R5: Optional Manual Infrastructure Design Gate

- Do not implement until a versioned rules document specifies build action, endpoints, cost, capacity, direction, ownership/privacy, blocking, undo/refund, destruction, AI use, and save migration.
- Characterize the current automatic-route behavior first.
- If approved, extend the existing route owner with committed infrastructure facts. Do not create a second runtime graph engine.

## 9. Asset Policy

- Keep Kenney UI Pack - Sci-Fi and UI Minimalism SciFi as the only retained visual candidates from this batch.
- Do not import generic pipeline textures or 3D pipe models as a prerequisite for the feature.
- Build route previews from Godot scene primitives, semantic icons, and project colors first.
- Any later asset import must include source, author, license, download date, and used-file manifest.

## 10. Acceptance Gates

- One global back owner and one Codex-local navigation owner with non-overlapping responsibilities.
- One city/trade-network runtime owner.
- Back precedence is deterministic across keyboard, controller, and pointer input.
- Focus returns to the exact initiating control after a page/modal pop.
- Route visuals never contain authoritative inventory, capacity, ownership, or GDP state.
- No manual pipeline action exists without a versioned ruleset decision.
- `Line2D` cutover preserves globe/flat projection, zoom, disruption, and route selection.
- Public route snapshots remain privacy-safe.
- Legacy input branches and line renderers are deleted only after zero references and full gates.
- Godot reports zero parse, runtime, node, signal, and scene-load errors.

## 11. Recommended Next Implementation

Sprint N1 is complete. Perform Sprint N2 as one hard cutover using the 32-case contract: one bounded global surface-stack owner, exact modal precedence, pointer/keyboard/controller parity, and focus restoration, followed by deletion of the characterized `main.gd` branches. After that, Sprint R1 can convert the already sceneized route component from custom drawing to editable `Line2D` children without touching the route algorithm.
