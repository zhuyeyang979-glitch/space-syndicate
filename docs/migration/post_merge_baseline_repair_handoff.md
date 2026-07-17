# Post-Merge Baseline Repair Handoff

Date: 2026-07-18

## Commits

- `549e3815dec0cb8a4b0a3663e64cc4220bf8a9c0` - RuntimeLoop cutover fixture, seven-child phase-scene alignment, and matching source-target bench fixture repair.
- `b0bbf0cf4e57145d77094149c74b4d1c36135473` - Authoritative PlayerSeat projection wiring and focused production-path coverage.
- Documentation is recorded by the commit containing this handoff.

## Focused Results

- RuntimeLoop gate and production bench: PASS, zero script errors.
- PlayerSeat public source wiring: PASS 39 checks, zero script errors.
- PlayerSeat host production/Skin/fallback: PASS, zero script errors.
- Presentation source-target cutover, query ports, viewmodel parity, refresh scheduler, Main runtime composition, composition root reduction, portrait component, and portrait Skin tests: PASS.
- UI text smoke, visual snapshot, and smoke `--check-only`: PASS.
- Original `TablePresentationSourceTargetBench.tscn` audit: run `20260717-231912-880-TablePresentationSourceTargetBench-7a3cde99` printed `FAIL 45/49`, then timed out at 300 seconds with runner exit `124`. Three failures came from a stale fixture that bound six phases but omitted the production scene-owned `RuntimeSimulationStep`; the fourth came from treating an unavailable dummy-renderer viewport texture as a headed screenshot failure. The deferred scene runner also never called `get_tree().quit`, which independently caused the timeout. Script error count was 0 and cleanup left no runtime process.

## Follow-Up Verification

- The bench now adds the production `RuntimePhaseCoordinator` scene to the tree before binding ports, so its scene-owned `RuntimeSimulationStep` participates in readiness. No simulation rule was copied and the three RuntimeLoop/cadence assertions were not relaxed.
- Deferred `auto_run=true` execution is one-shot and exits with the returned bench result. Direct or MCP/manual `run_bench()` still returns its `Dictionary` without requesting an exit.
- Screenshot evidence is environment-aware: headless/dummy runs explicitly record `dummy_renderer_skipped`; headed runs wait for frame draw, save the PNG, and verify the saved file. The headed artifact generated for inspection was restored to `HEAD` after its hash and dimensions were recorded.
- Hardened Godot 4.7 scene run `20260717-234159-484-TablePresentationSourceTargetBench-c8962899`: PASS `49/49`, process/runner exit `0`, duration `7.839s`, script errors 0, not timed out, cleanup PIDs empty, remaining runtime PIDs empty.
- Required reruns all passed with exit `0` and script errors 0: RuntimeLoop test `20260717-234244-436-runtime_loop_cutover_test-8b271d79`; RuntimeLoop bench `20260717-234250-977-RuntimeLoopCutoverBench-91450cc5`; source-target cutover `20260717-234258-214-table_presentation_source_target_cutover_test-7c16997a`; PlayerSeat wiring `20260717-234300-970-player_seat_public_source_wiring_test-9b2820fe`; smoke `--check-only` `20260717-234310-354-smoke_test-b32cf3ed`.

## MCP Evidence

- Dedicated endpoint: Funplay MCP port `8825`.
- Reported project root: `C:/Users/zhuye/Documents/New project/space-syndicate-post-merge-repair-9629ce7/`.
- Godot: `4.7-stable (official)`.
- Scene opened and run: `res://scenes/tools/PlayerSeatPortraitSkinBench.tscn`.
- Live viewport: `1600x960`.
- Runtime result text: `Skin available: yes | missing portrait fallback: yes | double display: no` (localized in the bench).
- Runtime events: bridge ready and successful node query only; no error event.
- Play mode exited and `is_playing_scene=false` was verified.
- The dedicated editor stopped normally and port `8825` was closed.
- Follow-up headed scene: `res://scenes/tools/TablePresentationSourceTargetBench.tscn`; editable scene tree showed the production coordinator, loop, phase coordinator, and typed ports.
- Follow-up console: `PASS 49/49`; headed screenshot mode, Windows display, Vulkan renderer, `save_error=0`, and no Godot error entry. The captured PNG was `1528x917`, 272453 bytes, SHA-256 `A8E6B234488FA0C19071909B4F5405B7223F93E26E43C191502A5EDB0C0EBA58` before restoration.
- Follow-up runtime events contained only bridge ready/exit, play state returned to false, the editor PID `17540` stopped, and port `8825` closed.

## Scope And Review

No fetch, rebase, push, Main edit, Compendium edit, role-catalog copy, setup/save/AI/economy/gameplay change, seat coordinate change, Skin style change, or portrait/manifest change was made. Generated `.uid`/`.import` sidecars and the MCP-refreshed tracked QA screenshot were excluded from commits.

Independent reviewers still own full Gate 0. This handoff claims only the focused repair and evidence above.
