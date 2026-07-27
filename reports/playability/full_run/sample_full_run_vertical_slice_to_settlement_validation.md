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
2. The scripted local player uses typed UI actions to obtain and play three facilities.
3. The public log exposes at least one real commodity `Sale Receipt`.
4. Authorized standings progress reaches the production Victory thresholds.
5. VictoryControl advances `idle -> qualification -> audit -> resolved`.
6. FinalSettlement accepts the typed public Victory receipt, emits one outcome-bound public log receipt, and acknowledges presentation before the session finishes.
7. RuntimeLoop produces eight consecutive `finished` frames with zero world delta and stable public world, action, settlement and RNG observations.

## Implementation boundary

- `FullRunAuthoritativeRuntimeStepper` offers a bounded test-only lease over the unique production RuntimeLoop. It rejects automatic double ownership, invalid deltas, invalid phase order, discontinuous frame indices and incomplete simulation receipts.
- `StandingsPublicQueryPort.victory_progress_for_authorized_viewer()` projects only the authorized viewer's own Victory candidate and public thresholds.
- Hand-card presentation now carries a closed `play_reason_id`; raw eligibility/card payloads are not exposed by that field.
- Terminal presentation is exact-once and outcome-bound. A missing or rejected presentation acknowledgement keeps the session live for retry; replay is idempotent and same-ID content mutation is rejected.
- `final_settlement` public logs use exactly `outcome_id`, `public_status`, `reason_code` and `winner_player_indices`. Arbitrary `message` payloads are invalid.

No card/economy/Victory value, target, timing, settlement order, RNG owner, RNG draw point, Save section, world-state owner, AI scoring path or production rule was changed.

## Fresh-process evidence

| Run | Result | Wall | Sale receipts | Installations | Victory | Outcome | Quiescence | Invalid actions |
|---|---|---:|---:|---:|---|---|---:|---:|
| A | settled | 153.450 s (`wall_ms=159998`) | 4 | 3/3 | idle -> qualification -> audit -> resolved | `victory.v06.1` / `public_audit_complete` | 8/8 | 0 |
| B | settled | 137.855 s (`wall_ms=144503`) | 4 | 3/3 | idle -> qualification -> audit -> resolved | `victory.v06.1` / `public_audit_complete` | 8/8 | 0 |

Each process emitted exactly one FinalSettlement public log and one accepted presentation outcome. Both processes stopped without residual project-scoped Godot processes.

## RNG evidence

| Checkpoint | Run A | Run B | Interpretation |
|---|---|---|---|
| setup | draw 236, `ff788bf7...` | draw 236, `ff788bf7...` | exact match |
| first Sale Receipt | draw 351, `80b2130a...` | draw 351, `80b2130a...` | exact match |
| terminal/quiescent | draw 548, `24ace3dd...` | draw 536, `f3dde97f...` | no cross-process parity claim |

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

Suite result: `failed=0`, `total=16`. No focused test approached the 60-second limit.

## Privacy and architecture

- The driver does not call `world_session_state()`, inspect raw `players`, read a direct Victory private snapshot, enumerate opponent hands or retain exact cash.
- The standings query requires the existing local-viewer authorization and rejects a mismatched private-snapshot subject.
- Public telemetry is closed by `FullRunQualitySnapshot` and rejects player, cash, hand, owner, hidden-owner, AI memory/plan, utility and raw-envelope keys.
- FinalSettlement accepts only public pure data and emits a structured receipt validated by `PublicLogReceipt`.
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
- `FinalSettlementRuntimeCompositionV06Bench` passed 16 checks with 0 failures.
- Runtime evidence showed two structured settlement receipts plus accepted and duplicate acknowledgements.
- Clean rerun console errors: 0.
- Scene stopped with `is_playing_scene=false`; editor stopped normally; project-scoped Godot process count returned to 0.

## Residual boundary

- Production restore remains deliberately fail-closed; this task does not claim Save/resume completion.
- Terminal RNG equality across independently timed rendered runs is not guaranteed and is not an acceptance condition. Owner/draw order remains covered by the existing determinism suites and each run's terminal quiescence check.
- A capability-alias hardening finding in the already-merged AI viewer-privacy baseline is outside this diff. It should be handled as a separate privacy atom rather than folded into this settlement slice.
