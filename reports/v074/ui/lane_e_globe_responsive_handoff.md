# V0.7.4 Lane E Globe and Responsive UI Handoff

## Scope

- Branch: `codex/v074-lane-e-globe-ui-05c2415`
- Base: `05c2415014187e902592bf3a8d1291222f738694`
- Role-local editor: Role B, `http://127.0.0.1:9025/`, Godot `4.7-stable`
- Production domains: planet presentation, map projection, globe interaction, and responsive layout only
- Excluded hot files: `V073SampleGameScreen`, `PlanetBoard`, bootstrap/runtime owners, and TargetRail

## Delivered

- `V074PlanetPresentationAdapterV1` consumes a `MapGenesisReceiptV1` object or dictionary without owning RNG, terrain, topology, or gameplay state.
- Lane A boundary compatibility is explicit:
  - `region_boundary_lods_spherical[region_id].near/medium/far` accepts one or more closed `Vector3` loops.
  - The largest loop becomes the legacy `MapPresentationSnapshot` district polygon.
  - Every loop is retained in `authoritative_surface.region_boundary_loop_lods_spherical`.
  - If top-level LODs are absent, embedded authoritative loops, ordered microgrid vertex references, and then shared edge references are consumed in that order.
  - Shared edge fallback only orders and reverses existing `points_unit_sphere`; it never interpolates or perturbs vertices.
  - Hit testing prefers authoritative top-level `microcell_centers_unit_sphere`, with `receipt.microgrid.microcell_centers_unit_sphere` as a compatibility fallback.
- `PlanetMapView` accepts the V0.7.4 payload while retaining existing camera and signal APIs. Camera rotation, zoom, focus, reset, click, backside filtering, and LOD projection do not rebuild authoritative geometry.
- The V0.7.4 local projection unwraps authoritative boundary points around each region center, preventing dateline/polar edges from crossing the entire stage.
- Nonselected V0.7.4 region labels remain compact at dynamic region counts; selected regions retain detail.
- The procedural shader consumes the authoritative terrain mask and sun direction for land relief, ocean depth, coast shading, atmosphere, and terminator presentation.
- Factory, market, and warehouse markers use the public projection only. Warehouse stock and private logistics fields are not copied.
- `V074ResponsiveTableLayout` provides compact, regular, and wide desktop profiles, and its collision audit checks major panels and interactive controls.

## Validation

- MCP `validate_script`: `13/13`, zero diagnostics.
- MCP scene load: `PlanetGlobeBackdrop.tscn` and `V074PlanetPresentationBench.tscn` loaded successfully.
- MCP shader/resource load: globe shader rendered in the headed scene; current editor error log returned zero error lines.
- Focused Godot gates:
  - presentation adapter: `22/22`
  - planet map view: `9/9`
  - planet shader surface: `7/7`
  - responsive table layout: `15/15`
  - UI collision audit: `4/4`
- Headed 24-region COMPLEX/BALANCED bench:
  - drag interactions: `1`
  - wheel zoom interactions: `5` (`0.72` to `1.12`)
  - map selection signals: `1`, Region 10
  - programmatic focus: Region 08
  - authoritative surface applies: `1`
  - authoritative geometry rebuilds: `1` before and after all camera interactions
  - terrain mask rebuilds: `1`
  - runtime/MCP error lines: `0`
  - drag false selection count: `0`
  - F/M/W markers visible together in local and focused views
- Editor shutdown: play mode stopped normally. Two normal editor close attempts timed out; after verifying the exact Lane E command line, PID `21204` alone was terminated. Port `9025` is closed and the role-local PID record is cleared.

## Visual Evidence

- `screenshots/v074_planet_before_rotation.png`
- `screenshots/v074_planet_after_rotation.png`
- `screenshots/v074_planet_after_zoom.png`
- `screenshots/v074_planet_region_selected.png`
- `screenshots/v074_planet_focused_region.png`
- `screenshots/v074_planet_overview.png`

All captures are from `res://scenes/ui/v074/map/V074PlanetPresentationBench.tscn` through the role-local MCP runtime bridge. The failed pre-fix white shader capture was overwritten.

## Integration Gaps

- Lane E does not own `main.tscn`, `PlanetBoard`, `V073SampleGameScreen`, runtime composition, Region Popup, or TargetRail. Production-main wiring and production screenshots remain an integration-owner step.
- The headed bench uses an exact-shape Lane A receipt fixture because Lane A is still isolated. The adapter contract covers top-level loop LODs, multiple loops, shared edge fallback, and microgrid fields, but the final merged Lane A core must still be exercised in production `main.tscn`.
- This lane does not claim 30-region frame-time P95, fullscreen roundtrip, the complete MCP sample match, or FinalSettlement. Those require the integrated runtime.
- No remaining Lane E script, shader, scene-load, interaction, privacy, or collision defect is known from this slice.
- The editor close timeout is tooling/process teardown behavior, not a project runtime failure; it is recorded for the integration owner.

## Worktree Hygiene

- Fresh import produced `57` modified tracked `.import` files and `126` untracked `.uid` files.
- None are part of the Lane E candidate. They remain unstaged and uncommitted.
- The commit stages only explicit owned source, scene, shader, test, report, and screenshot paths.
