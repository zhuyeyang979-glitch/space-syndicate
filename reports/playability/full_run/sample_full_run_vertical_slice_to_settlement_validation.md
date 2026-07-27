# Sample Full Run Vertical Slice to Settlement Validation

Status: `SAMPLE_FULL_RUN_VERTICAL_SLICE_TO_SETTLEMENT_GREEN`

## Scope

- Integration baseline: `a122208cbea1fbecf8a91cdf224027296d150661`.
- Runtime: Godot `4.7.stable.official.5b4e0cb0f`.
- Production scene: `res://scenes/main.tscn`.
- Fixed run: seed index `0`, seed `900626424`.
- Acceptance arguments: `--seed-index 0 --observation-seconds 150 --max-wall-seconds 180`.
- Save data remained isolated under temporary blocking-runner `user://` roots.

The slice uses the real production session, typed table actions, district-supply flow, card hand flow, RuntimeLoop, economy owners, VictoryControl, public presentation owners and FinalSettlement composition. It does not directly install facilities, force Victory state, mutate private player records or call a gameplay handler from the driver.

## Closed production path

1. A fixed-seed production session starts through the existing setup transaction.
2. The scripted local player uses typed district-supply and table-selection actions to obtain and play three facilities, and confirms progress only from their typed receipts.
3. The public log exposes at least one real commodity `Sale Receipt`.
4. Authorized standings progress reaches the production Victory thresholds.
5. VictoryControl advances `idle -> qualification -> audit -> resolved`.
6. FinalSettlement accepts the typed public Victory receipt, binds the authoritative and public outcomes to one canonical allowlisted audit identity, emits one outcome-bound public log receipt, and acknowledges live/full presentation before the session finishes.
7. RuntimeLoop produces eight consecutive `finished` frames with zero world delta and stable public world, action, settlement and RNG observations.

## Implementation boundary

- `FullRunAuthoritativeRuntimeStepper` offers a bounded test-only lease over the unique production RuntimeLoop. It rejects automatic double ownership, invalid deltas, invalid phase order, discontinuous frame indices and incomplete simulation receipts.
- `StandingsPublicQueryPort.victory_progress_for_authorized_viewer()` projects only the authorized viewer's own Victory candidate and public thresholds.
- `PublicFacilityTargetCandidatesSnapshot` exposes only typed, viewer-authorized candidate identifiers. The driver does not duplicate facility legality and ruined regions remain legal production targets under v0.6.
- District-supply purchase and table-selection completion are confirmed from typed action receipts rather than presentation cadence, while unavailable racks advance to the next unvisited public region.
- Hand-card presentation now carries a closed `play_reason_id`; raw eligibility/card payloads are not exposed by that field.
- Terminal presentation is exact-once and outcome-bound. Live/full apply acknowledgements are tracked separately; a missing or rejected acknowledgement keeps only the unapplied target pending for zero-world retry, while successful targets are never replayed. Duplicate replay is idempotent and same-ID content mutation is rejected.
- Authoritative settlement, public Victory projection and presentation acknowledgement compare one normalized public identity: winner order, GDP, controlled-region counts, victory rule, audit roster and settlement checkpoint. Private cash transport is never used as a cross-visibility equality shortcut.
- `final_settlement` public logs use exactly `outcome_id`, `public_status`, `reason_code` and `winner_player_indices`. Arbitrary `message` payloads are invalid.

No card/economy/Victory value, target, timing, settlement order, RNG owner, RNG draw point, Save section, world-state owner, AI scoring path or production rule was changed.

## Fresh-process evidence

| Run | Result | Wall / world | Sale receipts | Facilities final/peak | Victory | Presentation / log | Identity | Quiescence | Invalid actions |
|---|---|---:|---:|---:|---|---:|---:|---:|---:|
| A13 | settled | 170.110 s / 251.033138 s (`wall_ms=176270`) | 31 | 3/3 | idle -> qualification -> audit -> resolved | 1/1/1 | match | 8/8 | 0 |
| A14 | settled | 167.363 s / 251.749720 s (`wall_ms=173478`) | 31 | 3/3 | idle -> qualification -> audit -> resolved | 1/1/1 | match | 8/8 | 0 |

Both fresh processes used `--seed-index 0 --observation-seconds 150 --max-wall-seconds 180`, proved a peak of at least three production facilities, verified the authorized 10-second qualification and 120-second audit timers, emitted exactly one FinalSettlement public log, applied live/full terminal presentation exactly once, and stopped without residual project-scoped Godot processes.

## RNG evidence

| Checkpoint | Run A13 | Run A14 | Interpretation |
|---|---|---|---|
| setup | draw 236, `ff788bf7...` | draw 236, `ff788bf7...` | exact match |
| first Sale Receipt | draw 548, `65c2556e...` | draw 548, `65c2556e...` | exact match |
| terminal/quiescent | draw 1712, `47ce7e93...` | draw 1574, `eda8501f...` | no cross-process parity claim |

Render-delta timing changes the amount of pre-terminal waiting, so the two terminal checkpoints are intentionally not claimed equal. Within each run, terminal-to-quiescent RNG draw delta is zero. The diff changes no RNG owner or draw call.

## Focused gates

All tests used `tools/invoke_godot_test.ps1` with a 60-second timeout and isolated process/user-data roots.

| Test | Result | Wall |
|---|---:|---:|
| `full_run_quality_driver_contract_test.gd` | pass | 5.925 s |
| `full_run_authoritative_runtime_stepper_test.gd` | pass | 5.549 s |
| `full_run_quality_driver_argument_transport_test.gd` | pass | 5.661 s |
| `full_run_observation_window_policy_test.gd` | pass | 5.494 s |
| `full_run_facility_acquisition_policy_test.gd` | pass | 5.375 s |
| `runtime_victory_port_terminal_presentation_exact_once_test.gd` | pass | 5.314 s |
| `standings_application_flow_cutover_test.gd` | pass | 5.910 s |
| `card_hand_play_reason_projection_test.gd` | pass | 5.332 s |
| `final_settlement_runtime_composition_v06_test.gd` | pass | 6.971 s |
| `table_presentation_query_ports_cutover_test.gd` | pass | 6.437 s |
| `public_log_presentation_owner_save_test.gd` | pass | 1.411 s |
| `main_runtime_composition_test.gd` | pass | 12.073 s |
| `v06_save_owner_registry_test.gd` | pass | 8.180 s |
| `run_rng_service_cutover_test.gd` | pass | 8.123 s |
| `simulation_determinism_foundation_test.gd` | pass | 6.333 s |
| `simulation_determinism_consumption_layer_test.gd` | pass | 5.537 s |

The final focused matrix passed `23/23`. The two structural guards, `card_semantic_architecture_scan_test.gd` and `card_codex_playerface_runtime_invariants_test.gd`, also passed, for `25/25` relevant gates overall. The matrix includes the new facility-target query, ruined-region legality, typed purchase/selection receipt confirmation, normalized audit identity, terminal live/full partial-failure retry, duplicate acknowledgement and lifecycle rollback cases. No focused test approached the 60-second limit.

## Broad smoke comparison

- `ui_text_smoke_test.gd`, `visual_snapshot.gd` and `smoke_test.gd --check-only` pass.
- Full `smoke_test.gd` remains blocked in unchanged legacy fixtures. Its first script error is the retired `Main._new_game` call; it later reaches the stale `_summon_monster_from_card(players[0], regular_monster_card)` fixture whose dictionary argument no longer matches the typed controller signature.
- `tests/smoke_test.gd` and `scripts/runtime/monster_runtime_controller.gd` are byte-for-byte unchanged by this PR relative to `a122208c`; `scripts/main.gd` is also untouched. After the definitive fixture error and 129 seconds without new log output, the isolated run was stopped rather than restoring a compatibility wrapper. No PR-owned parse, missing-access, orphan-connection or assertion failure appeared before that historical boundary.

## Privacy and architecture

- The driver does not call `world_session_state()`, inspect raw `players`, read a direct Victory private snapshot, enumerate opponent hands or retain exact cash.
- The standings query requires the existing local-viewer authorization and rejects a mismatched private-snapshot subject.
- Public telemetry is closed by `FullRunQualitySnapshot` and rejects player, cash, hand, owner, hidden-owner, AI memory/plan, utility and raw-envelope keys.
- FinalSettlement accepts only public pure data, validates allowlisted audit evidence, and emits a structured receipt validated by `PublicLogReceipt`.
- Changed Save files: 0. Registry remains 19 required sections, 12 transactional, 7 unsupported, `resume_ready=false`.
- Changed RNG files: 0. New RNG draws/owners: 0. Checkpoint capture is read-only.
- Changed `main.gd` lines: 0. `main.tscn` adds one typed acceptance-return connection.
- New production AI consumers, state owners and generic world-player reads: 0.
- `git diff --check`: pass.

## Godot MCP acceptance

The worktree-local Funplay MCP endpoint used the real Godot 4.7 editor/runtime.

- Project root and engine version matched the worktree.
- Script scan: 286/286 GDScripts, 0 errors.
- Production `main.tscn` contained exactly the required FinalSettlement, TablePresentationQueryPorts and RuntimeLoop nodes and both terminal receipt/acceptance signal connections.
- `FinalSettlementRuntimeCompositionV06Bench` passed 24 checks with 0 failures.
- Runtime evidence showed typed settlement receipts, normalized outcome identity, live/full apply confirmation, partial-failure retry and accepted duplicate acknowledgement handling.
- Clean rerun console errors: 0.
- Scene stopped with `is_playing_scene=false`; editor stopped normally; project-scoped Godot process count returned to 0.

## Residual boundary

- Production restore remains deliberately fail-closed; this task does not claim Save/resume completion.
- Terminal RNG equality across independently timed rendered runs is not guaranteed and is not an acceptance condition. Owner/draw order remains covered by the existing determinism suites and each run's terminal quiescence check.
- A capability-alias hardening finding in the already-merged AI viewer-privacy baseline is outside this diff. It should be handled as a separate privacy atom rather than folded into this settlement slice.
