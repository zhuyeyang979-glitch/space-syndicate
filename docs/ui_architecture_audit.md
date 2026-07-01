# UI Architecture Audit

This note records the current UI architecture state for the Space Syndicate prototype. It is intentionally product-facing and implementation-facing: future Codex work should use it to avoid sliding back into a giant `main.gd` UI generator.

## Current authoritative scene tree

- `project.godot` still launches `res://scenes/main.tscn`.
- `scenes/main.tscn` is a full-rect `Control` shell with `res://scripts/main.gd` attached.
- Runtime gameplay UI is still mostly generated from `scripts/main.gd`.
- Greybox/editor-visible UI scenes now exist under `scenes/ui/` and at the root scene level:
  - `scenes/ui/GameScreen.tscn`
  - `scenes/ui/TopBar.tscn`
  - `scenes/ui/CardTrack.tscn`
  - `scenes/ui/PlanetBoard.tscn`
  - `scenes/ui/RightInspector.tscn`
  - `scenes/ui/PlayerBoard.tscn`
  - `scenes/ui/HandRack.tscn`
  - `scenes/ui/CardFace.tscn`
  - `scenes/ui/OverlayLayer.tscn`
  - `scenes/GameScreen.tscn`
  - `scenes/CardUI.tscn`
  - `scenes/LayoutDemo.tscn`

## Wrong architecture still present

The main remaining product/UI debt is not Node2D-based UI. The debt is that `main.gd` still owns too much UI construction:

- Runtime UI panels, labels, buttons, card faces, drawers, and overlays are still mostly created through script code.
- Human designers cannot yet adjust the live main table primarily through Godot Editor scenes.
- The main runtime table can still feel like a vertical information waterfall because the live scene has not been migrated to `scenes/ui/GameScreen.tscn`.
- The old runtime has many valid board-game components, but they compete for first-screen attention.

## Architecture fixed in this pass

- Periodic full refresh no longer forces the bottom player board to destroy/recreate every refresh tick; live values can update in place.
- `RightInspector` is now a first-class editor-visible UI component, so the right side has a single "why / detail / action" destination.
- `HandRack` is a custom `Control` responsible for child-card layout and hover lift.
- `CardFace/CardUI` are editor-visible card components instead of anonymous labels/buttons.
- ViewModel snapshot scripts now exist under `scripts/viewmodels/` to define the bridge between domain state and UI scenes.
- Layout tests instantiate key UI scenes at 1280x720, 1366x768, 1600x960, 1920x1080, and 2560x1440.

## Next migration rule

Do not add new player-facing UI branches directly inside `scripts/main.gd` unless the change is a small compatibility adapter. New UI should land as:

1. a `scripts/viewmodels/*_snapshot.gd` shape if game state must be translated,
2. a `scenes/ui/*.tscn` component if the player sees it,
3. a `scripts/ui/*.gd` renderer that only consumes snapshots and emits signals,
4. a small bridge in `main.gd` that passes runtime data into the component.

The target product frame remains:

```text
Main table = board-game table
RightInspector = explanation and current context
Codex = encyclopedia
Debug/test reports = backstage only
```
