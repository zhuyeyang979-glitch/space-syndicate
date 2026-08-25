# Space Syndicate Version Continuity Gate

GENERATED_FROM=product_surface_reachability_audit.py

STATUS=PASS_STATIC
HEAD=e372c105cb0e0727f07347bda215cf526f79f75a
TREE=441d0056ffc740cbbc054bdb06246237909264ad
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
- `res://scenes/ui/OverlayLayer.tscn` — UNREACHABLE_FROM_CURRENT_MAIN
- `res://scenes/ui/MenuOverlay.tscn` — UNREACHABLE_FROM_CURRENT_MAIN
- `res://scenes/ui/MenuQuickNavigation.tscn` — UNREACHABLE_FROM_CURRENT_MAIN
- `res://scenes/ui/MenuRootLobby.tscn` — UNREACHABLE_FROM_CURRENT_MAIN
- `res://scenes/ui/NewGameSetupPage.tscn` — UNREACHABLE_FROM_CURRENT_MAIN
- `res://scenes/ui/NewGameSetupLobby.tscn` — UNREACHABLE_FROM_CURRENT_MAIN
- `res://scripts/runtime/menu_lifecycle_application_flow_controller.gd` — UNREACHABLE_FROM_CURRENT_MAIN
- `res://scripts/runtime/setup_application_flow_controller.gd` — UNREACHABLE_FROM_CURRENT_MAIN

## Menu continuity

- MenuRootLobby present: True
- MenuRootLobby production reachable: False
- Embedded StartOverlay production reachable: True

## Audit limits

Dynamic loads are retained as UNKNOWN; no Godot process or full-world reproof was run.
