# Space Syndicate Version Continuity Gate

GENERATED_FROM=product_surface_reachability_audit.py

STATUS=PASS_STATIC
HEAD=348a7b966afbaf0ef5e9aca25ea0dfb4ed0b95a7
TREE=6c8a559f1617798f8070194eee232e91e31af8a7
READ_ONLY=true
GODOT_FULL_REPROOF_RUN=false

## Production chain

- `res://scenes/main.tscn` — REACHABLE_FROM_CURRENT_MAIN
- `res://scripts/v075_runtime/v075_application_bootstrap.gd` — REACHABLE_FROM_CURRENT_MAIN
- `res://scenes/runtime/V075RuntimeComposition.tscn` — REACHABLE_FROM_CURRENT_MAIN
- `res://scenes/ui/v075/V075SampleGameScreen.tscn` — REACHABLE_FROM_CURRENT_MAIN
- `res://scenes/ui/v074/V074SampleGameScreen.tscn` — REACHABLE_FROM_CURRENT_MAIN
- `res://scenes/ui/V073SampleGameScreen.tscn` — REACHABLE_FROM_CURRENT_MAIN
- `res://scenes/ui/v075/V075NewGameLoadingOverlay.tscn` — REACHABLE_FROM_CURRENT_MAIN
- `res://scenes/ui/MenuOverlay.tscn` — REACHABLE_FROM_CURRENT_MAIN
- `res://scenes/ui/MenuQuickNavigation.tscn` — REACHABLE_FROM_CURRENT_MAIN
- `res://scenes/ui/MenuRootLobby.tscn` — REACHABLE_FROM_CURRENT_MAIN
- `res://scripts/runtime/menu_lifecycle_application_flow_controller.gd` — REACHABLE_FROM_CURRENT_MAIN
- `res://scenes/ui/CommercialSettingsSurface.tscn` — REACHABLE_FROM_CURRENT_MAIN
- `res://scenes/ui/OverlayLayer.tscn` — UNREACHABLE_FROM_CURRENT_MAIN
- `res://scenes/ui/NewGameSetupPage.tscn` — UNREACHABLE_FROM_CURRENT_MAIN
- `res://scenes/ui/NewGameSetupLobby.tscn` — UNREACHABLE_FROM_CURRENT_MAIN
- `res://scripts/runtime/setup_application_flow_controller.gd` — UNREACHABLE_FROM_CURRENT_MAIN

## Menu continuity

- MenuRootLobby present: True
- MenuRootLobby production reachable: True
- Embedded StartOverlay production reachable: True

## Audit limits

Dynamic loads are retained as UNKNOWN; no Godot process or full-world reproof was run.
