# Commercial Visual Style V1

## Authority

This document freezes the presentation treatment for the selected commercial
art foundation. It does not authorize a rules, AI, Save, RNG, or V0.7 runtime
cutover.

```text
CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6
TARGET_DEVELOPMENT_CONSTITUTION=V0.7
FULL_V0_7_RUNTIME_CUTOVER=false
PRESENTATION_ASSETS_OWN_GAMEPLAY_STATE=false
PRESENTATION_RNG_DRAW_COUNT=0
```

Only the sources named in the task authorization may be used. Source filenames
remain private to the presentation catalog and third-party manifest. Gameplay
code consumes semantic data; presentation code consumes stable asset keys.

## Surface Palette

| Role | Color |
|---|---|
| Primary background | `#111720` |
| Secondary background | `#19222E` |
| Raised panel | `#222F3D` |
| Primary stroke | `#617184` |
| Highlight stroke | `#D8E5F0` |

Panel opacity stays between `0.88` and `0.96`. Kenney Sci-Fi UI surfaces are
recolored into this palette and use nine-slice margins. No panel texture may be
stretched without preserved corners.

Patterns are low-frequency support textures. They may appear on card backs,
deck and discard surfaces, asset bases, and quiet panel areas. High-frequency
patterns that produce moire at 1366x768 are excluded.

## Six Asset Families

Player-facing language uses `asset`, never mana.

| Asset key | Player name | Color | Base shape | Icon source |
|---|---|---|---|---|
| `icon.asset.life` | Life Asset | `#59C878` | circle with leaf notch | Leaf Swirl |
| `icon.asset.energy` | Energy Asset | `#FF9F43` | diamond | Lightning Electron |
| `icon.asset.industry` | Industry Asset | `#98A3B3` | hexagon | Cog |
| `icon.asset.technology` | Technology Asset | `#4EA1FF` | clipped square | Circuitry |
| `icon.asset.commerce` | Commerce Asset | `#B66CFF` | octagon | Receive Money |
| `icon.asset.shipping` | Shipping Asset | `#35D0C5` | horizontal capsule with chevrons | Spaceship |

Every family is identifiable by glyph and base silhouette without color. SVG
art uses a normalized viewBox, transparent background, consistent optical
margin, and comparable black/white weight. Production derivatives are 128,
64, and 32 pixels.

V0.7-only counters such as current value out of six, reservations, and batch
costs remain in the Reference/Review presentation until a typed production
projection exists. This task does not change V0.6 asset limits or costs.

## Card Frames

No external card framework is used. Existing `CardUI`, the selected Kenney UI
surfaces, and the selected pattern texture form three presentation variants.

### Normal

- Stable key: `card.frame.normal`.
- Deep graphite body and thin border.
- Six-color accent rail across the top.
- Primary asset icon at upper left and rank at upper right.
- Asset cost rail at the bottom.
- Existing authored illustration remains the central art source.

### Commodity

- Stable key: `card.frame.commodity`.
- Metallic silver-gray body and a wider six-color base.
- Existing abstract commodity illustration remains central.
- Commodity level remains at upper right.
- The card itself remains the single-click claim surface; no claim button is
  added.

### Bound Action

- Stable key: `card.frame.bound_action`.
- Navy or obsidian body with source-type border motif.
- Monster or military source emblem at upper left.
- Explicit presentation mark that it does not consume normal-hand capacity.
- It cannot visually impersonate a normal or commodity card.

### Card Back

- Stable key: `card.back.normal`.
- Selected low-frequency Kenney pattern recolored with `#121820`, `#263445`,
  and `#4A6278`.
- Center contains only an existing Space Syndicate mark or stable project
  symbol.

## Hand Interaction

```text
HOVER_SCALE=1.08
HOVER_LIFT_PIXELS=28
HOVER_DURATION_MS=120
DRAG_DEADZONE_PIXELS=8
DRAG_LIFT_DURATION_MS=110
DRAG_MAX_TILT_DEGREES=4
SELECTED_OUTLINE_PIXELS=2
LEGAL_TARGET_GLOW_PIXELS=3
```

Hover, keyboard focus, controller focus, click selection, drag, invalid-target
return, local queue reorder, locked state, cost preview, and insufficient-asset
feedback are presentation states over the existing action spine. They never
submit a second command, mutate gameplay directly, consume RNG, or bypass an
Intent and Receipt.

## Planet

The selected planet body, cloud, and atmosphere shaders are extracted from the
authorized MIT source only. The production map retains its existing district,
target, facility, and selection authorities.

```text
PLANET_OPAQUE=true
PLANET_ALPHA=1.0
BACK_FACE_CULLING=true
DEPTH_TEST=true
ZOOM_MIN=0.72
ZOOM_MAX=1.85
MOUSE_WHEEL_ZOOM_STEP=0.08
DAY_BRIGHTNESS=1.0
NIGHT_BRIGHTNESS_MIN=0.45
NIGHT_BRIGHTNESS_MAX=0.55
OUTER_ORBIT_DECORATION_COUNT=0
```

Backside districts, facilities, and units are culled by the presentation
projection. Camera rotation, pan, zoom, interpolation, and reset state are not
saved and do not feed gameplay. Atmosphere is restrained and the planet body
never becomes translucent.

## Map Entities

Quaternius content shares one low-poly material language. Player ownership is
shown on a base ring and small identification lights, never by recoloring the
whole model. Industry identity uses local emissive details.

- Factory: tall, heavy industrial silhouette with one or two pipe groups and a
  central emissive core; MetalPlates013.
- Market: open circular or hexagonal platform with two to four displays and a
  trade terminal; PaintedMetal007.
- Warehouse: low rectangular silhouette with crates and loading platform;
  SheetMetal003.
- Starport: platform, antenna, landing mark, and one selected small ship;
  shipping-cyan emissive detail.

Monster, military, and ship selections are frozen by exact source filename in
the third-party manifest. Model scale mapping is deterministic from imported
AABB volume. Full models appear in the Review scene; production may use catalog
billboards at low zoom without changing the authoritative entity owner.

## VFX

Particles are short presentation receipts. Particle count, lifetime, and blend
area are bounded. Smoke is reserved for facility operation/damage, monster and
military attacks, and destruction; it is not emitted continuously at high
transparent overdraw.

## Audio

Each event resolves to one selected file. There is no random variant selection
and no gameplay RNG involvement. Music crossfade duration is `1.5` seconds and
may respond only to public presentation state, never hidden information.

```text
music.menu=Pondering the Cosmos
music.gameplay=Robotic City
music.crisis=Space Graveyard
music.military=Interstellar Fleet 1
```

## Typography

Noto Sans CJK SC Regular/Bold is the default Chinese body family. Japanese
locale selects Noto Sans CJK JP Regular/Bold. Oxanium Medium, SemiBold, and Bold
are restricted to Latin display text, numbers, GDP, cash, timers, ranks, asset
values, and percentages. Oxanium never renders Chinese or Japanese body text.

## Production And Reference Boundary

Production-safe presentation integration may include global fonts, theme
surfaces, current card frames, commodity accents, opaque planet rendering,
current entity art, UI sound, menu music, Credits, orbit-decoration removal,
and camera zoom.

The unified V0.7 track, personal DBG draw/discard, six-asset value cap,
five-action reorder, reservation UI, and anonymous resolution queue remain in
`CommercialArtIntegrationReview` or an existing V0.7 Reference presentation
until a matching typed production projection is present on `main`.

## Replacement Boundary

Every external asset is replaceable behind a stable presentation key. Core,
AI, Player semantic ports, Save, RNG, and card IDs never depend on vendor names,
source filenames, or resource paths.
