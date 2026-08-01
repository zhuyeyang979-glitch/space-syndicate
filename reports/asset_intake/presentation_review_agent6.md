# Commercial Art Integration Review Scene

## Status

`GREEN_REVIEW_SKELETON_WITH_EXPLICIT_CATALOG_GATES`

The second-stage presentation Review scene is implemented and load-tested. It is a tool scene only, has no production connection, and creates no Session, Save, RNG draw, gameplay mutation, or Main reference.

## Files

- `res://scenes/tools/CommercialArtIntegrationReview.tscn`
- `res://scripts/tools/commercial_art_integration_review.gd`
- `res://scripts/tools/commercial_art_review_asset_badge.gd`
- `res://tests/commercial_art/commercial_art_review_scene_test.gd`

## Catalog Boundary

The scene loads only the existing canonical resource at `res://resources/presentation/alpha01_card_illustration_catalog.tres`. It does not define a second Catalog and contains no commercial vendor path.

For every commercial asset it first calls `resource_for_asset_key`. That generic API landed concurrently during validation, but the canonical `.tres` does not yet contain stable commercial resource rows, so all 42 commercial stable keys currently render a visible `MISSING_CATALOG_BINDING` gate. This is intentional and fail-closed.

Three existing card illustrations are resolved through `presentation_key_for_card` plus `texture_for_key`, giving the normal, commodity, and bound-action previews real content while their commercial frames remain gated. `refresh_catalog_bindings` rebuilds the Review once the Catalog single writer lands the generic resource table.

When stable resources become available, the same code automatically applies UI textures as 9-slice style boxes, displays icon and frame textures, applies fonts, previews local audio streams, and instantiates `PackedScene` model resources in isolated 3D subviewports. No second resource path is needed.

## Coverage

The scene shows:

- Six asset icons with six distinct code-owned base shapes.
- Normal, commodity, and bound-action frames plus a normal card back.
- Hover, selected, drag, legal-target, locked, and insufficient-cost states.
- The Agent3 opaque planet component with day/night material, zoom, and backside culling.
- Four facility slots, six monster slots, four military tiers, and three shipping slots.
- SC, JP, and display-font samples.
- Five SFX buttons, four music buttons, and one volume control.
- Third-Party Assets, Licenses, Music, and Fonts Credits placeholders.

Missing models, streams, fonts, icons, and frames show stable-key gates rather than loading third-party paths directly. Audio fails closed, model slots remain named, and font samples use the existing production theme until catalog bindings arrive.

## Interaction Boundary

The interactive sample uses the fixed values from the task: hover scale `1.08`, hover lift `28 px`, hover duration `120 ms`, drag deadzone `8 px`, drag lift duration `110 ms`, and maximum tilt `4 degrees`. Selected and legal-target samples expose the required 2 px and 3 px treatments.

These controls only animate Review nodes. They emit no gameplay offer, do not reorder a runtime queue, and cannot submit a card.

## Planet Reuse

The scene directly instances Agent3's internal Review component:

`res://scenes/tools/commercial_art/components/planet/CommercialPlanetReviewComponent.tscn`

Its runtime snapshot confirms opaque alpha `1.0`, back-face culling, depth testing, zero backside marker/facility visibility, zero outer-orbit decoration, zoom `0.72..1.85` in `0.08` steps, and unsaved camera state.

## Validation

Godot 4.7 focused validation passed `400/400` in total:

- Review scene: `54/54`.
- Architecture preflight: `287/287`.
- Agent3 planet contract: `59/59`.

The Review test loaded and exercised the scene at 1366x768 and 1920x1080, verified exact section counts, applied hover and drag animations, checked the planet contract, confirmed fail-closed missing audio, scanned production scenes for zero Review references, and scanned Agent6 scene/scripts for zero vendor, Session, Save, RNG, or Main APIs.

No full Smoke or Formal run was started.

Other lanes modified Catalog and production Dock hot files concurrently. Agent6 did not edit, stage, revert, or clean any of those files.
