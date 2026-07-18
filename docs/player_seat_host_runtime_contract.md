# Production Player Seat Host Contract

## Purpose

The production planet table owns one public player-seat presentation host for every supported 3–8 player count. It maps public player identity and role state into stable columns beside the planet without changing the map size, intercepting map input, or exposing private game state.

The host consumes the production scene:

`res://scenes/ui/player_seat/PlayerSeatPortraitSkin.tscn`

The host never reads portrait PNG paths or an art manifest.

## Production scene paths

- Semantic host: `/GameScreen/SafeArea/MainRows/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport/RoleSeatLayerHost`
- Back presentation layer: `/GameScreen/SafeArea/MainRows/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport/BackSeatLayer`
- Planet/map layer: `/GameScreen/SafeArea/MainRows/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport/MapHost`
- Front presentation layer: `/GameScreen/SafeArea/MainRows/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport/FrontSeatLayer`

`RoleSeatLayerHost` owns the two presentation layers through exported `NodePath` bindings. All supported seats use the front presentation layer and remain outside the planet input rectangle. The back layer remains in the scene contract for non-seat presentation compatibility.

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
- `seat_index`
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

The authorized local player is rotated to descriptor seat zero and fixed at `left_low`. Later player counts only append slots, so existing seat indices never change side:

| Seat index | Stable slot |
| --- | --- |
| 0 | left_low (local) |
| 1 | right_low |
| 2 | left_mid_low |
| 3 | right_mid_low |
| 4 | left_mid_high |
| 5 | right_mid_high |
| 6 | left_high |
| 7 | right_high |

This produces the supported splits `2/1`, `2/2`, `3/2`, `3/3`, `4/3`, and `4/4` for 3–8 players. The local portrait is 1.10 times the ordinary seat presentation scale and uses the existing public `is_local_player` field to display the compact `你` marker.

Coordinates are calculated from the live `PlanetStageViewport` rectangle. Each column is centered independently, keeping 5- and 7-player layouts visually balanced. Horizontal positions are clamped to an eight-pixel safe margin. Left and right seats request inward-facing portraits; right seats set `mirror_h = true`. No full player portrait occupies the top commodity-track region.

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
- Formal `main.tscn` screenshots: `docs/ui_qa/player_seat_side_columns/player_seat_side_columns_{3,4,5,6,7,8}p.png`
- Formal scene-tree and pixel gate: `docs/ui_qa/player_seat_side_columns/player_seat_side_columns_result.json`
- Godot MCP scene: `res://scenes/ui/PlanetBoard.tscn`
- Godot MCP runtime: `res://scenes/main.tscn`
