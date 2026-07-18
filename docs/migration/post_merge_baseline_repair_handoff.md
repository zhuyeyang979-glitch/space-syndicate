# Post-Merge Baseline Repair Handoff

Date: 2026-07-18

Final status: `POST_MERGE_BASELINE_REPAIR_GREEN`

Next status: `COMPENDIUM_CUTOVER_UNBLOCKED`

## Repair Commits

- `549e3815dec0cb8a4b0a3663e64cc4220bf8a9c0` - aligned the RuntimeLoop cutover test and dedicated benches with the merged seven-child production phase scene.
- `b0bbf0cf4e57145d77094149c74b4d1c36135473` - restored authoritative PlayerSeat public projection wiring and real presentation-query injection without adding a Main fallback.
- `c8d2edfb06f5bb424dd9332d8f1dfddf2ed28609` - recorded the initial RuntimeLoop and PlayerSeat failure analysis and repair evidence.
- `c9152f740eb6076541b30077398814911e1a0a8c` - hardened the TablePresentation source-target scene gate, including the scene-owned simulation step, deterministic auto-exit, and headed/dummy screenshot branches.
- `ddf0cbce07422a47956fff0968a9dd7ba9ea996f` - moved monster visual-color resolution into the Monster runtime owner using `MONSTER_CATALOG_V06.art_profile()` and a stable catalog fallback.
- `4b5cd3cfb3412096f45258f15a80a076d71f5628` - migrated the rules and role/commodity settlement tests to the merged ApplicationFlow and typed `WorldSessionState` owners.
- The commit containing this handoff is the docs-only recording commit; it is intentionally not self-referential by SHA.

## Failure Classification

The original RuntimeLoop cutover report listed 16 script errors. They were repeated observations of one fixture getter-lifecycle event: the fixture assigned through getter-only child lookups before the seven typed child ports existed. The production RuntimeLoop was present, unique, and correctly ordered; this original incident contained zero production Runtime defects. The gate was repaired by constructing the typed children first, without restoring Main callbacks or changing production order.

The original PlayerSeat finding was a separate production wiring defect. The public source service was bound to Main even though Main did not expose players, and the presentation query omitted `public_player_seat_sources`. The repair consumes the existing allowlisted `WorldSessionPublicProjection`; it preserves empty pre-session seats, privacy, one local player, unique public indices, and Skin/fallback exclusivity.

Later headed QA exposed an origin/main production P0 unrelated to the original 16 script errors: `MonsterRuntimeController._auto_monster_color()` still routed to a physically deleted Main helper. Commit `ddf0cbc` made the Monster owner resolve the public monster name through the existing catalog art profile and return a stable `Color` fallback for invalid slots/profiles. No Main wrapper, catalog copy, or simulation dependency was introduced.

## Presentation Gate History

- Original scene run `20260717-231912-880-TablePresentationSourceTargetBench-7a3cde99`: `FAIL 45/49`, runner exit `124`, timeout 300 seconds, script errors 0. Three failures were the omitted production scene-owned `RuntimeSimulationStep`; one was the dummy-renderer screenshot assumption. The deferred runner also lacked an exit request.
- Repaired scene run `20260717-234159-484-TablePresentationSourceTargetBench-c8962899`: `PASS 49/49`, process/runner exit `0`, duration `7.839s`, not timed out, script errors 0, no residual runtime PID.
- Final independent rerun `20260718-065210-097-TablePresentationSourceTargetBench-193a2e67`: `PASS 49/49`, exit `0`.

## Merged-Owner Fixture Results

- `player_rules_in_game_test`: exit `0`, run `20260718-064951-279-player_rules_in_game_test-832e8124`. The composition assertion now targets `ApplicationFlowController`; Main remains free of a duplicate builder/compose path.
- `role_resource_cash_commodity_settlement_v06_test`: `PASS 82/82`, exit `0`, run `20260718-064953-828-role_resource_cash_commodity_settlement_v06_test-bcc07bd1`. The fixture now uses typed `WorldSessionState` through the real bridge chain; no `world.players` fallback was restored.
- Monster autonomous migration: `PASS 14/14`, exit `0`, run `20260718-064943-987-simulation_autonomous_behavior_command_migration_test-e54c0fe4`.
- RuntimeLoop cutover: exit `0`, run `20260718-065000-124-runtime_loop_cutover_test-e46810d7`.

## Final Independent QA

- Full tracked-script scan: `848/848`, parse errors `0`. The earlier `386` count was an early restricted scan; this final scan covered all tracked scripts and is the stronger result. The repair candidate added only one test file relative to the audited source baseline.
- Critical scenes: `12/12` loaded.
- Focused gate set: `14/14` exited `0`; all were non-timeout runs with zero script errors and no remaining test PID.
- Smoke `--check-only`: exit `0`, run `20260718-065202-503-smoke_test-be40ed27`.
- Main budget: `12505` physical lines and `788` methods.
- Audited runtime owner families: one production owner each; Main fallback count `0`; registered save owners `18`.

## Real Four-Player PVE

The final independent headed QA used the real `res://scenes/main.tscn` UI path: Start New Game, default four-player PVE, Start Run. It ran for more than 18 seconds, entered operations, and then advanced to planning.

- FPS: `145`.
- RuntimeLoop: `frame_index=29037`, `path=active`, `stopped_reason=completed`.
- World effective clock sample: `7739891 us`; the UI timer showed `00:18`.
- Three real monsters advanced; movement, action, and duration traces were present.
- Console error lines: `0`; `_auto_monster_color`, bridge-routing, `Nil -> Color`, and RuntimeLoop-blocking errors: `0`.
- Public PlayerSeat descriptors: `4`; production seat nodes: `4`; unique indices: `0-3`.
- P0/P2 used `PlayerSeatPortraitSkin`; P1/P3 used the missing-portrait fallback. Skin and fallback were mutually exclusive for every seat.
- Screenshot: `C:/Users/zhuye/AppData/Local/SpaceSyndicate/post_merge_targeted_qa_4b5cd3c/real_four_player_after_15s.png`.
- Screenshot size: `390693` bytes; SHA-256: `EF978CC349E595A3721FE66672385774205F16178125194738A8B1D884095905`.

## Remaining P2

`monster_card_real_owner_integration_v06_test.gd` remains `22/31` with 9 failures in run `20260718-065218-749-monster_card_real_owner_integration_v06_test-47a7215c`. All nine failures are a deferred stale-fixture issue: the old cross-owner fixture does not inject typed `WorldSessionState`. The failures do not reproduce in the formal new-game path and do not affect the current Gate 0 verdict. This handoff does not claim that every repository test is green.

## Stop And Scope Evidence

- Play mode ended with `is_playing_scene=false`.
- The dedicated final-QA editor exceeded its normal close timeout; only its verified PID `16196` was then terminated. Final worktree Godot process count was `0`, and dedicated listener `8845` count was `0`.
- Generated `.uid`/`.import` files and temporary internal captures were removed individually. The repair worktree was clean and `git diff --check` exited `0`.
- Compendium files modified: `0`.
- No fetch, rebase, push, Main fallback, `world.players` fallback, save-schema change, or Compendium implementation was performed.

The repaired baseline is green for the recorded Gate 0 scope, and the separate Compendium cutover may resume from its preserved worktree.
