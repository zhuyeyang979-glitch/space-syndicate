# Main economy application-flow extraction handoff

Status: `MAIN_ECONOMY_APPLICATION_FLOW_EXTRACTION_IMPLEMENTED`

The economy page is scene-composed and viewer-scoped. Opening it is a cached, pure read: no catalog initialization, route refresh, world advance, RNG use, selection update, command dispatch or log append. Intel's economy link submits the same application intent and returns before the legacy full-refresh callback.

The snapshot service remains a formatter. It receives only bounded, allow-listed pure data and contains no runtime node access or visibility decision. The `PublicSnapshotService` name is retained for compatibility; its class comment and debug snapshot explicitly describe public facts plus authorized own-private facts.

Not migrated: intel mutations, compendium, setup, save/load, gameplay economy authority, RuntimeLoop, card execution, AI policy, monster/military/weather authority.

Focused acceptance: dedicated-signal exact-once test, viewer-scoped snapshot test, recursive rendered bench, source-negative Main gate, Godot project load and main-scene launch.

Main budget moved from `12961 physical / 11242 nonblank / 806 methods / 66 fields / 107 constants / 12 preloads` to `12505 / 10822 / 788 / 66 / 106 / 11`. This removes 456 physical lines, 420 nonblank lines, 18 methods, one constant and one preload without adding a Main caller.

Generated UID classification: `economy_application_flow_controller.gd.uid` and `economy_dashboard_viewer_query_port.gd.uid` belong to new production scripts referenced by new production scenes. All unrelated editor-generated UIDs were removed.
