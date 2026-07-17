# Card-resolution frame driver cutover

## Scope

`CardResolutionFrameDriver` is the unique scene-owned adapter that builds the public timing facts consumed by `CardResolutionRuntimeController.tick()` and advances that timing controller once per allowed world frame.

Production path:

`main.tscn -> GameRuntimeCoordinator -> CardResolutionFrameDriver -> CardResolutionRuntimeController`

The direct `CardResolutionRuntimeController` sibling under Main's runtime host has been removed. Main no longer owns `_update_card_resolution_queue()` or `_card_resolution_controller_facts()`.

## Authority boundary

The driver owns no queue entries, card effects, presentation state, player records, clocks, or save schema. It reads the existing queue, world-session and field-driven eligibility services and returns ordered controller commands. The queue and timing controller remain the authoritative owners of their existing state.

This cutover deliberately does **not** claim that card execution is scene-owned. Main still consumes the ordered commands and still contains the current reveal/counter/complete/start transition sink. That remaining sink is a `card_execution` and presentation dependency that must be migrated before the authoritative RuntimeLoop can become production owner.

## Negative guarantees

- no Main reference or callback in the driver;
- no service locator or `current_scene` lookup;
- no second card queue or timing state;
- one production driver and one production timing controller;
- debug output contains only aggregate tick/trace metadata;
- eliminated seats are excluded from ready-player facts without exposing their private records.

## Acceptance

`tests/card_resolution_frame_driver_cutover_test.gd` verifies complete ordered transition arrays, counter eligibility, tick exactness, privacy, production uniqueness and negative Main dependencies. `CardResolutionFrameDriverBench.tscn` provides a real Godot runtime check through the production coordinator.
