# Production Planet Read-Only Review

Status: PARTIAL

Failure code: BACKSIDE_SCENEIZED_MARKER_RECURRENCE

## Findings

### Blocker: backside Sceneized markers remain visible

The underlying spherical projection is correct. A point at world position
(0, 475) reports visible=false and z=-1.0 while the overview faces
(700, 475). The Sceneized overlay discards that visibility result:

- scripts/ui/planet_map_view.gd:1171 returns only projected position.
- scripts/ui/planet_map_view.gd:607 creates every district label.
- scripts/ui/planet_map_view.gd:695 creates every city marker.
- scripts/ui/planet_map_view.gd:750 creates every monster token.

The real production PlanetMapView screenshot contains 76 bright-magenta
sentinel pixels over the planet center. One backside district label, one city
marker, and one monster marker are all visible even though their projection
is explicitly behind the globe.

This bug predates the current four-file production diff, but it blocks the
requested backside-occlusion gate. The main Agent should make Sceneized
consumers preserve and enforce projection.visible before creating or showing
Controls, then add a backside sentinel regression.

### Existing test debt: live-refresh route fixture

tests/planet_map_live_refresh_identity_test.gd passes 7/8 checks but fails its
initial route-node assertion. The same failure reproduces on adapter worktree
a1fdfc485815e924f465562d60165500cd436671, where the tested map scene,
wrapper, and test are byte-identical to base 2e387647.

The fixture injects legacy direct route data. The current
OptionalRoutePresentationRuntimeService correctly exposes no route or route
segment without an explicit public snapshot; only the movement-trail node is
created. The fixture should use set_optional_route_public_snapshot, or public
summaries plus geometry, before asserting route nodes.

### Test hygiene: one anchor warning

commercial_planet_production_presentation_test.gd passes 6/6, but line 17
assigns size after a full-anchor Control is ready and emits one layout
warning. Set top-left anchors before assigning size, or defer the assignment.

## Production diff

The reviewed delta against 2e387647 is four files, 22 insertions and 90
deletions:

| File | Reviewed change |
| --- | --- |
| scripts/map_view.gd | Zoom defaults, clamp range, additive 0.08 wheel step, read-only debug fields |
| scripts/ui/map/planet_globe_backdrop.gd | Opaque ocean, 0.50 night overlay, old table ring removal |
| scripts/ui/map/planet_map_render_model.gd | Orbit payload becomes an empty array |
| scripts/ui/map/planet_orbit_guide.gd | Orbit and latitude/longitude drawing retired |

No set_map assignment, district list, target index, selection signal, hit-test,
action-routing, public projection, Save, RNG, AI, or gameplay-value contract
changed.

The following authority files are byte-identical to the base:

| File | Blob SHA |
| --- | --- |
| scripts/ui/planet_map_view.gd | 1345f5e7ed9da32c1fbc54f63fd9b646c8c31737 |
| scenes/ui/PlanetMapView.tscn | 6c598a3f8f349332300ed39b2758170165625d77 |
| scripts/ui/planet_board.gd | 89a19f352f4458564a4b765714579d6658331cec |
| scenes/ui/PlanetBoard.tscn | a7f2ceb3fd3a695a97ef6bfa1fc2d5311a0b8e41 |
| scripts/runtime/table_player_action_application_flow_controller.gd | 75052cfeaedde734fbe6e35405800a5ecd05e477 |

Conclusion: the reviewed four-file diff itself is presentation-only and does
not alter map, district, or target authority.

## Focused tests

| Test | Result | Notes |
| --- | --- | --- |
| commercial_planet_production_presentation_test.gd | 6/6 | Pass, one anchor warning |
| commercial_planet_asset_contract_test.gd | 59/59 | Pass |
| map_view_globe_default_test.gd | 2/2 | Pass |
| map_view_focus_rotation_test.gd | 22/22 | Pass |
| planet_map_live_refresh_identity_test.gd | 7/8 | Baseline fixture debt reproduced |

Aggregate: 96/97.

planet_solar_camera_presentation_test.gd was intentionally not run because it
creates GameSession and touches Save ownership. runtime_pointer_input_layer_test
was not run because it instantiates the complete main runtime composition.
No Formal or full Smoke was started.

## Pixel evidence

Both captures use the real res://scenes/ui/PlanetMapView.tscn at 1366x768,
Godot 4.7 Forward+, without creating Session or Save.

### Opaque and orbit probe

- File: production_planet_opaque_orbit_1366x768.png
- SHA-256: 885aa439a687f212c3eddf2aa5e6fcad3c692ff87186df4efbdb44dd79d99b0e
- Planet-center RGBA: 28,35,42,255
- Non-opaque output pixels: 0
- Magenta probe background pixels leaking inside planet: 0
- Cyan pixels in the retired outer-orbit annulus: 0
- Gold pixels in the retired outer-orbit annulus: 0

The production planet is opaque and the outer decorative orbit is absent.

### Backside sentinel probe

- File: production_planet_backside_sentinel_1366x768.png
- SHA-256: 3141e871d546de593f7cbbfe6a204b8ce42e0ce1f25b45604209a4cfa5ec2cf5
- Backside projection: visible=false, z=-1.0
- Visible magenta sentinel pixels: 76
- Backside region marker visible count: 1
- Backside city marker visible count: 1
- Backside monster marker visible count: 1

## Boundary

Hot-file edit count by Agent 3: 0.

Session create count: 0. Save create count: 0. Production gameplay, AI,
Save, RNG, PlanetBoard, PlanetMapView scene, and target authority were not
modified during this review.
