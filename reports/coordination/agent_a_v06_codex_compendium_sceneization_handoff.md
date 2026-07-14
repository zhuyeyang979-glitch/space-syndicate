# Agent A v0.6 Codex/Compendium Sceneization Handoff

## Scope

- Branch: `codex/a-v06-main-sceneization`
- Authoritative pre-rebase baseline: `79c6366`
- Integration rebase target announced by Supervisor: `ceed2a6`
- Godot MCP: role A endpoint `8775`
- Project root verified by MCP: `C:/Users/zhuye/Documents/New project/.codex-worktrees/space-syndicate-a-v06/`

## Delivered

- `MenuOverlay.tscn` statically owns one `CodexCompendiumSurface.tscn`.
- The Surface statically owns the hub, card, monster, product, role, and region browser/detail scenes.
- The Surface consumes duplicated pure-data dictionaries and emits action IDs plus pure payloads.
- `MenuOverlay.clear_preview()` exclusively owns the persistent Surface lifecycle. `main.gd::_clear_children()` remains a generic container helper and is now used only for card-resolution badges.
- `main.gd` no longer preloads or dynamically constructs the Codex scenes, searches them with `find_child`, or owns their local-navigation rendering helpers.
- Added a pure `CompendiumHubSnapshot` viewmodel for the hub presentation dictionary.

## Deletion Gate

- `main.gd`: 20,147 -> 19,947 physical lines (`-200`).
- `main.gd`: 1,150 -> 1,132 functions (`-18`).
- Diff: `+150/-351` in `main.gd`.
- Retired presentation helper residuals: `0` of 21.
- Direct Codex scene references in `main.gd`: `0`.
- Codex-specific `find_child` references in `main.gd`: `0`.

## Focused Evidence

- Funplay MCP opened the static Surface and exposed all child scene contracts.
- Final real headed `CodexSceneHardCutoverBench.tscn`: `20/20` passed.
- Runtime query returned `StatusLabel=PASS` and `SummaryLabel=20/20 cutover cases passed`.
- Final MCP capture: `user://space_syndicate_design_qa/codex_compendium_sceneization_v06_final.png` (`1528x917`).
- Focused manifest: `user://space_syndicate_design_qa/codex_scene_hard_cutover/manifest.json`.
- Privacy case passed: no hidden-owner, private-target, or private-discard keys in Codex snapshots.
- Godot play mode was stopped and verified false after capture.
- `git diff --check` passed.

## Boundaries

- No GameRuntimeCoordinator, card/commodity/AI/save runtime, Scenario Lab, rule, or license files were changed.
- No dependency on B's `AiV06EconomyActionPort v2` or `actor_id_for_player_index` exists in A-owned files.
- No complete suite was run by A; Supervisor remains the owner of full headed/headless, privacy, license, and integration acceptance.
