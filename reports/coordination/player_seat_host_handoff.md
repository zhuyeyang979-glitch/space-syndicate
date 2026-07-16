# Player Seat Host Handoff

## Scope

This branch delivers only the authoritative production host, public seat descriptors, 3–8 seat layout, depth layers, safe fallback, focused tests, and production-scene screenshots.

No role portrait PNG, art source, portrait manifest, `PlayerSeatPortraitSkin`, role portrait catalog, or Skin-focused test was modified.

## Production wiring

- `GameRuntimeCoordinator`
  - mounts `PlayerSeatPublicSourceService`;
  - binds it to the authoritative runtime world;
  - injects its public source into the table/planet source before viewmodel composition.
- `PlanetBoardSnapshot`
  - sanitizes and maps the public source through `PublicPlayerSeatSnapshot`.
- `PlanetBoard`
  - forwards final descriptors to `RoleSeatLayerHost`.
- `RoleSeatLayerHost`
  - owns `BackSeatLayer` and `FrontSeatLayer` by `NodePath`;
  - uses the real `PlanetStageViewport` rectangle;
  - dynamically mounts the future Skin or an independent fallback per seat.

`main.gd` contains no seat descriptor assembler and no `public_player_seat_sources` wiring.

## Privacy boundary

Allowed public data:

- player index;
- public player and role names;
- public player color;
- local-seat marker;
- public status;
- explicitly public current actor.

Forbidden data is neither requested nor forwarded:

- exact opponent cash;
- hand, hand count, or discard;
- hidden/true owner;
- anonymous card actor truth;
- private wager choice;
- AI plan or score;
- hidden economy state.

Anonymous activity explicitly suppresses the public actor highlight.

## Layout and fallback

- 3, 4, 5, 6, 7, and 8-seat mappings are data-defined.
- Local player is always `bottom`.
- Top/high seats render through the back layer.
- Mid/low/bottom seats render through the front layer.
- All seat surfaces ignore pointer input.
- The central map rectangle is unchanged.
- The future Skin scene is dynamically checked with `ResourceLoader.exists()`.
- Skin failure falls back per seat; legacy decorative arcs remain visible only for fallback seats.

## Evidence

Focused command:

```powershell
godot --headless --path . --resolution 1280x720 --script res://tests/player_seat_host_production_test.gd
```

Expected terminal:

`PLAYER_SEAT_HOST_PRODUCTION_TEST checks=58 failures=0`

Production screenshots:

- `reports/ui/player_seat_host/player_seat_host_3_players_1600x960.png`
- `reports/ui/player_seat_host/player_seat_host_4_players_1600x960.png`
- `reports/ui/player_seat_host/player_seat_host_6_players_1600x960.png`
- `reports/ui/player_seat_host/player_seat_host_8_players_1600x960.png`

Godot MCP:

- inspected `res://scenes/ui/PlanetBoard.tscn`;
- confirmed semantic host plus back/map/front production ordering;
- entered the real main scene;
- runtime debug errors: `0`;
- stopped runtime cleanly.

Final validation:

- `tests/player_seat_host_production_test.gd`: `58/58 PASS`.
- `tests/ui_text_smoke_test.gd`: PASS.
- `tests/visual_snapshot.gd`: PASS.
- `tests/smoke_test.gd --check-only`: PASS.
- `tests/layout_scene_smoke_test.gd`: FAIL on pre-existing cross-system legacy assertions and runtime interaction gates outside this branch; the production `GameScreen` and `PlanetBoard` scene load/Control/layout checks themselves passed, and no reported failure named the seat host.
- Godot MCP `get_script_errors`: `checked=186`, `error_count=0`.
- Godot MCP real main play: entered successfully, error log lines `0`, stopped successfully.
