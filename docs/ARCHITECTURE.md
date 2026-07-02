# Space Syndicate Architecture

This project is still prototype-heavy, but new work should follow hard layer boundaries so multiple Codex agents can work in parallel without turning `scripts/main.gd` into a larger knot.

## Layers

### Domain / Rules

Owns economy, cards, monsters, military, contracts, AI policy, hidden information, victory, and settlement rules.

Rules-layer code must not create Godot UI nodes and must not read or write concrete `Control`, `Button`, or `Label` instances.

### Runtime Controller

`scripts/main.gd` is currently the runtime facade. It may keep legacy prototype state while the project is being split.

Its intended role:

- hold runtime state;
- receive UI `action_requested` signals;
- call rules/services;
- build snapshots through ViewModel/runtime adapters;
- push snapshots into `GameScreen`.

Avoid adding large UI construction or new rule subsystems directly to `main.gd`. If `main.gd` must be touched, keep the change to thin wiring and document the touched functions in the PR.

### ViewModel / Snapshot

Files under `scripts/viewmodels/*` convert runtime state into UI-safe dictionaries.

They are responsible for:

- player-facing text shape;
- hidden-information filtering;
- compact UI read order;
- data-only payloads with no `Callable` rule handles.

### UI Scene / Renderer

Files under `scenes/ui/*` and `scripts/ui/*` render snapshots and emit signals.

UI scripts should:

- use `Control`/`Container`/`Theme`;
- avoid game-rule decisions;
- avoid reading opponent private state directly;
- avoid creating debug panels for player-facing UI.

### Scenario / Playability Lab

Files under `scripts/scenarios/*` and `data/scenarios/*` define fixed playable scenarios, fixture packages, phase goals, action logs, and lightweight replay points.

Scenario code exists to help humans test whether the game can be played. It may prepare fixture state, but it must not change core card, economy, monster, AI, PublicTrack, BidBoard, or IntelDossier rules.

### Tests / Verification

Files under `tests/*` are the acceptance layer:

- smoke tests prove the project loads and can run;
- layout tests prove UI scenes instantiate and fit;
- visual snapshot contracts prevent UI regression;
- scenario tests prove fixed playability drills load, progress, and hide private information;
- privacy tests prevent hidden information leaks.

## Main.gd Reduction Rule

Do not perform a broad rewrite of `main.gd` in one PR.

Preferred order:

1. add scene/viewmodel/scenario files outside `main.gd`;
2. add a thin `main.gd` bridge only when runtime wiring is unavoidable;
3. later move side-effect-light snapshot helpers into `scripts/runtime/*`;
4. only after stable playability tests, split domain systems.

New PR guidance:

- `main.gd` net new lines should preferably stay under 150 unless explicitly approved.
- New UI construction in `main.gd` should be zero.
- New runtime data should prefer `scripts/viewmodels/*`, `scripts/runtime/*`, or `scripts/scenarios/*`.
- New rules must have smoke or fixture coverage.

