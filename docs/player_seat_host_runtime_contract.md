# Production Player Seat Host Contract

## Purpose

The production planet table owns one public player-seat presentation host for 3–8 seats. It maps public player identity and role state around the existing planet without changing the map size, intercepting map input, or exposing private game state.

The host is ready to consume the future scene:

`res://scenes/ui/player_seat/PlayerSeatPortraitSkin.tscn`

The host never reads portrait PNG paths or an art manifest.

## Production scene paths

- Semantic host: `/GameScreen/SafeArea/MainRows/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport/RoleSeatLayerHost`
- Back presentation layer: `/GameScreen/SafeArea/MainRows/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport/BackSeatLayer`
- Planet/map layer: `/GameScreen/SafeArea/MainRows/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport/MapHost`
- Front presentation layer: `/GameScreen/SafeArea/MainRows/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport/FrontSeatLayer`

`RoleSeatLayerHost` owns the two presentation layers through exported `NodePath` bindings. The layers are siblings in the production scene so their tree order can place top/high seats behind the opaque planet disc and lower/bottom seats in front without using global `z_index`.

All host and seat presentation controls use `MOUSE_FILTER_IGNORE`.

## Public data source

`PlayerSeatPublicSourceService` is mounted in `GameRuntimeCoordinator`. It is bound to the authoritative runtime world and builds a narrow public source from existing public world accessors:

- public player name;
- public role card name;
- public player color;
- public elimination status;
- local human player index.

The coordinator injects that source into the production table source before `GameTableViewModelRuntimeService` composes the UI snapshot. `main.gd` does not assemble seat descriptors or wire the seat source into the planet snapshot.

The public source does not forward cash, hand or discard information, hidden ownership, anonymous card truth, private wager choices, AI plans, or private economy data.

## Descriptor contract

`PublicPlayerSeatSnapshot` emits only:

- `player_index`
- `public_player_name`
- `role_name`
- `player_color`
- `seat_position`
- `portrait_variant`
- `mirror_h`
- `is_local_player`
- `public_status`
- `is_publicly_active`
- `visual_scale`
- `depth_group`

When an action is anonymous, `public_activity_is_anonymous` suppresses `is_publicly_active`; it is not forwarded into the final descriptor.

## Seat mapping

The local player is rotated to the first descriptor and fixed at `bottom`.

| Seats | Clockwise presentation order from local player |
| --- | --- |
| 3 | bottom, left_mid, right_mid |
| 4 | bottom, left_mid, top, right_mid |
| 5 | bottom, left_high, left_low, right_high, right_low |
| 6 | bottom, left_high, left_low, top, right_high, right_low |
| 7 | bottom, left_high, left_mid, left_low, right_high, right_mid, right_low |
| 8 | bottom, left_high, left_mid, left_low, top, right_high, right_mid, right_low |

Coordinates are calculated from the live `PlanetStageViewport` rectangle. The seat pivot is its bottom center. Horizontal positions are clamped to an eight-pixel safe margin.

`top`, `left_high`, and `right_high` use the back layer. All other positions use the front layer. Left and right seats request inward-facing portraits; right seats set `mirror_h = true`.

## Dynamic Skin handoff

The host checks `ResourceLoader.exists()` at runtime. It never creates a static external-resource dependency on the future Skin scene.

For each seat independently:

1. If the Skin resource exists, instantiate it.
2. Require a `Control` root and `apply_public_view_model`.
3. Apply the narrow public Skin view model.
4. If application succeeds and optional `skin_available()` is true, use the Skin.
5. Otherwise, use `RoleSeatFallback`.

Only a seat that successfully mounts its Skin hides its corresponding legacy decorative arc. Missing, invalid, or unavailable Skin content keeps that seat's fallback and decoration visible. The host never globally hides all fallback arcs.

## Acceptance evidence

- Focused production host test: `tests/player_seat_host_production_test.gd`
- Production-scene capture driver: `tests/player_seat_host_capture.gd`
- Screenshots: `reports/ui/player_seat_host/player_seat_host_{3,4,6,8}_players_1600x960.png`
- Godot MCP scene: `res://scenes/ui/PlanetBoard.tscn`
- Godot MCP runtime: `res://scenes/main.tscn`
