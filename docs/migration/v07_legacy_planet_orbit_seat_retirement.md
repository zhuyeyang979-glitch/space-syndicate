# V0.7 legacy planet/orbit player-position retirement

Status: `REFERENCE_LAYER_GREEN`

This migration is deliberately limited to the V0.7 reference table. PR #69 is
now GREEN on its remote sibling branch at
`b5d5682072fd9ff02be700ce9d5503d1df996641`; it is an external prerequisite,
not a Git ancestor of this Lane B stack. The V0.6 production runtime remains
authoritative and the split typed presentation targets are not yet complete.
No production `GameScreen`, `PlanetBoard`, player-position snapshot, map scene,
or runtime composition is changed.

## Problem and previous dependency chain

The V0.7 contextual table previously instantiated the production board:

```text
V07ContextualTableSurface
└─ PlanetBoard
   ├─ RoleSeatLayerHost
   ├─ BackSeatLayer
   ├─ PlanetMapView
   │  ├─ PlanetGlobeBackdrop (eight positional decoration points)
   │  └─ PlanetOrbitGuide (eight radial spokes)
   └─ FrontSeatLayer
```

Passing an empty `player_seats` array to `PlanetBoard.set_board_state()` only
hid some runtime content. It did not remove the duplicate placement source,
the player-position layers, or the positional visual language from the
reference scene tree.

Baseline reference metrics were:

```text
V07_REFERENCE_PLAYER_ROSTER_SOURCE_COUNT=2
ORBIT_PLAYER_MARKER_COUNT=8
ORBIT_RADIAL_SPOKE_COUNT=8
LEFT_RIGHT_SEAT_LAYER_COUNT=2
```

## Reference-only replacement

The V0.7 surface now composes:

```text
V07ContextualTableSurface
├─ PlayerRosterPanel (the only player placement source)
└─ V07ReferencePlanetStage
   └─ V07ReferencePlanetMapView
      ├─ V07ReferencePlanetBackdrop
      ├─ V07ReferencePlanetGuide
      ├─ real district/route/monster/weather layers
      └─ real map input, zoom, projection and solar-camera implementation
```

`V07ReferencePlanetMapView` inherits `scripts/ui/planet_map_view.gd` through a
narrow reference-only boundary and reuses the existing editable map layers. It
does not instantiate production
`PlanetMapView.tscn`, `PlanetGlobeBackdrop.tscn`, or `PlanetOrbitGuide.tscn`.
Its scene explicitly fixes:

```text
sceneized_visual_cutover_enabled=true
legacy_draw_fallback_enabled=false
```

The reference boundary reasserts both values during ready, processing and
immediately before drawing. A caller therefore cannot revive the inherited
legacy eight-position visual path by changing an exported property.

The neutral backdrop implements only the map underlay `configure(Dictionary)`
protocol. It has no player-position constants, visibility method, or decoration
points. The neutral guide retains non-semantic planet rings and local grid
lines, but has no radial spokes or positional markers.

The Bench now applies deterministic map fixture data directly to the embedded
map view. It no longer calls `PlanetBoard.set_board_state()` or relies on an
empty production player-position projection.

## Typed single-side player roster

The exact-key public roster row contains:

```text
player_id
display_name
public_status
public_order_index
is_viewer
optional avatar_key
optional accent
```

`public_order_index` is required, non-negative, and unique. The presentation
sorts only by this authority-provided public order. It never derives order from
the local player, display name, player ID, input array order, private state, or
the retired orbit positions.

The roster provides one column for 3-4 players and two columns for 5-8 players.
Exactly one owner-authorized row carries a `你` marker; the marker never
rotates that player to the first row or changes `public_order_index` ordering.
Every row is a focusable button with explicit directional/tab focus links.
Mouse or focused-keyboard activation emits only the selected public
`player_id`, and exactly one inspected row remains visually selected. Unknown
IDs, missing/duplicate order, Nodes/Objects, and non-allowlisted private fields
fail closed.

## Reference acceptance gates

Runtime and source-negative tests jointly require:

```text
V07_REFERENCE_PLAYER_ROSTER_SOURCE_COUNT=1
ORBIT_PLAYER_MARKER_COUNT=0
ORBIT_RADIAL_SPOKE_COUNT=0
LEFT_RIGHT_SEAT_LAYER_COUNT=0
PRODUCTION_PLANET_BOARD_REFERENCE_COUNT=0
PRODUCTION_POSITION_HOST_REFERENCE_COUNT=0
PRODUCTION_POSITIONAL_UNDERLAY_REFERENCE_COUNT=0
LEGACY_DRAW_FALLBACK_ENABLED=false
```

The gates cover 3, 4, 5, 6 and 8 players; scrambled delivery order; one stable
viewer marker without local-first rotation; non-overlap between the roster and
planet stage; a dedicated non-overlapping context-hint lane; public inspection;
actual focused Enter activation; privacy rejection; 1366x768 and
1920x1080 layout bounds; map wheel zoom; contextual popup/target behavior; and
the uninterrupted resolution overlay. Headed evidence must be captured only
after the deterministic real-map fixture is applied, so the empty-map
placeholder cannot be mistaken for player-position decoration.

The initial implementation QA used isolated endpoint `8825`; the final
coordinator QA used independent endpoint `8815`. Both ran
`V07UninterruptedCardBatchContextualTableBench.tscn` on Godot 4.7. The final
4-player, 8-player and physical 1366x768 runs each passed 44/44. At 1600x960
the roster ended at x=328 and the planet began at x=364.8, leaving 36.8 pixels;
the 1366x768 gap was 39.26 pixels. Seat, BackSeat and FrontSeat runtime node
counts were all zero, and the viewer marker count was exactly one.

Final clean-session MCP diagnostics were zero runtime errors, zero script
errors and zero warnings. Three earlier exploratory-session script errors (one
editor placeholder preview and two malformed dynamic QA snippets) remain
honestly recorded as pre-clean diagnostics; a fresh editor/runtime session
proved they are not production or Bench failures. Six existing Unicode-NUL
decode diagnostics remain baseline-only. The final endpoint listener and
project Godot process counts were both zero.

Final automated evidence is: RightInspector inventory 80/80, reference
retirement 90/90, player semantics 71/71, contextual Bench 44/44, architecture
17/17, three-layer integration 24/24, performance 11/11, Main architecture
219/219, Main runtime composition PASS, UI text PASS, visual contract PASS and
smoke check-only exit 0.

The headed comparison is explicit about scope:

- `docs/ui_qa/v07_card_batch/reference_orbit_overlap_before.png` is the V0.7
  reference surface before detaching the production orbit/seat composition; it
  is not a production GameScreen screenshot.
- `docs/ui_qa/v07_card_batch/legacy_planet_orbit_seat_retired_1600x960.png` is
  the initial detached reference stage after the eight positional markers and
  spokes are absent.
- `docs/ui_qa/v07_card_batch/v07_reference_roster_4p_popup_1600x960.png` proves
  one-column four-player layout and the owner-authorized `你` marker.
- `docs/ui_qa/v07_card_batch/v07_reference_roster_8p_popup_1600x960.png` and
  `v07_reference_roster_8p_popup_1366x768.png` prove the two-column layout at
  desktop and low resolution.
- `docs/ui_qa/v07_card_batch/v07_reference_roster_8p_popup_closed_1600x960.png`
  proves the popup closes without replacing the full planet map.

## Production components intentionally retained

| Component | Current production consumers | Why it remains |
| --- | --- | --- |
| `PlanetBoard.tscn` / `planet_board.gd` | `GameScreen.tscn`, `game_screen.gd`, table presentation targets and production tests | V0.6 production board and map composition still depend on it. |
| `RoleSeatLayerHost` | `PlanetBoard`, production inspection flows, player-position host tests | Production single-side roster has not cut over. |
| `BackSeatLayer` / `FrontSeatLayer` | `RoleSeatLayerHost`, `PlanetBoard` layout | The production host still mounts both layers. |
| `PublicPlayerSeatSnapshot` and position enums | `PlanetBoardSnapshot`, table snapshot/view-model services, `planet_board.gd`, production tests | No production typed public roster replacement exists yet. |
| `RoleSeatFallback` / `PlayerSeatPortraitSkin` | `RoleSeatLayerHost` dynamic presentation | Production role-art fallback remains live. |
| production `PlanetMapView` | `PlanetBoard`, GameScreen/map tests and visual snapshots | V0.6 map remains production authority. |
| production `PlanetGlobeBackdrop` | production `PlanetMapView`, host decoration visibility | Its production consumers have not migrated. |
| production `PlanetOrbitGuide` | production `PlanetMapView` | Production visual cutover is outside this atom. |
| `map_view.gd` legacy fallback | inherited by production and reference map scripts | Physical deletion requires a separate production fallback-retirement proof. |

Representative current production tests include
`player_seat_host_production_test.gd`,
`player_seat_public_source_wiring_test.gd`,
`selected_player_actor_authority_split_test.gd`,
`role_table_art/player_seat_portrait_component_test.gd`,
`layout_scene_smoke_test.gd`, and `visual_snapshot.gd`.

## Exact final deletion gate

Production player-position components may be physically deleted only after all
of the following are true:

1. PR69 is GREEN. This prerequisite is now satisfied.
2. The formal V0.7 production table-shell cutover is complete.
3. Production `GameScreen` consumes one typed, visibility-safe single-side
   roster projection with mouse, keyboard, inspection and privacy parity.
4. `PlanetBoard`, `RoleSeatLayerHost`, both position layers,
   `PublicPlayerSeatSnapshot`, fallback/skin components, and production
   positional underlays have zero production consumers.
5. Production map, weather, route, target-selection, popup, zoom and visual
   snapshot tests pass without those components.
6. The production map's legacy eight-position fallback has a separate deletion
   proof; it is not merely disabled by a V0.7 reference scene.

Until those gates are met, physical production deletion is forbidden. This
atom removes only the independent V0.7 reference dependency and creates no
dual runtime authority.
