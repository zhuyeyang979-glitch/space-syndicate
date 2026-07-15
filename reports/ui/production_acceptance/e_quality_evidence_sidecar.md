# 1280 Production Evidence Sidecar

- Audit date: 2026-07-15
- Read-only source baseline: `a4630c885adaf0a63a6e3b78be506dbc4daad638`
- Production acceptance evidence revision: `0c25b3a421f06fc66dc8cbad172b70334c916f77`
- Verdict: **PARTIAL EVIDENCE; NOT A COMPLETE-MATCH PASS**

This sidecar separates the existing headed 1280x720 evidence from the current
`FullRunQualityDriver` result. The seven PNGs below are real production-table
captures and have structured pixel/scene evidence, but they predate the audited
source baseline. They are not output from the full-run driver and cannot prove a
complete first-run interaction, save/restore continuation, settlement, or a
twenty-seed pass.

## Covered real-table evidence at 1280x720

| Covered state | Capture | What it proves | Boundary |
|---|---|---|---|
| First-run core table | `01_first_run_core_table_1280x720.png` | Real `main.tscn` table, four players, district selection coach, forecast present | Initial frame only; no buy-card success |
| Weather forecast | `02_weather_forecast_1280x720.png` | Production-generated forecast is visible | Not a full-run transition |
| Active weather | `03_weather_active_1280x720.png` | Production activation is visible | Next forecast held for one QA review frame |
| Active plus forecast | `04_weather_dual_1280x720.png` | Active zone and next production forecast coexist | Not settlement evidence |
| Economy scrolled | `05_economy_scrolled_1280x720.png` | Real economy overview renders at a nonzero scroll offset | Readability state only |
| Economy reopened | `06_economy_reopened_1280x720.png` | Reopening resets scroll from 460 to 0 | No save/relaunch involved |
| Public table modules | `07_card_track_inspector_player_board_1280x720.png` | `PublicTrack`, `RightInspector`, and `PlayerBoard` are complete after production `_use_skill(0)` | Does not prove the first-run buy action |

The acceptance manifest reports all seven captures at 1280x720 with passing
pixel metrics, a captured scene tree, zero classified console errors/warnings,
and an unchanged default-save fingerprint. The unchanged fingerprint proves
save isolation only. It does not prove that an isolated save was written,
loaded into a fresh world, or continued successfully.

## Missing 1280x720 screenshot matrix

| Required state | Screenshot status | Runtime evidence status |
|---|---|---|
| Full-run district selection submitted and progressed | MISSING | Driver progressed two setup actions, but emitted no screenshots |
| `first_run.buy_card` with enabled `coach_buy_card` | MISSING | BLOCKED: current primary action is disabled |
| Buy-card action submitted and progressed | MISSING | NOT REACHED |
| First card played and follow-up buy/play complete | MISSING | NOT REACHED |
| Remaining first-run coach stages complete | MISSING | NOT REACHED |
| Forced decision window with a visible valid action | MISSING | NOT REACHED |
| Victory countdown and audit | MISSING | NOT REACHED |
| Production settlement presentation | MISSING | NOT REACHED; settlement remained `idle` |
| Save checkpoint before exit | MISSING | NOT ATTEMPTED; restore capability incomplete |
| Fresh-world restore of the same run | MISSING | UNSUPPORTED |
| Restored run continued to settlement | MISSING | UNSUPPORTED |
| Twenty fixed seeds at the same milestones | MISSING | Only seed index 0 was run |

No missing cell may be converted to PASS without a new real capture from the
corresponding production state. No image is synthesized or inferred here.

## Current full-run blocker

An isolated E-worktree run on the source baseline used seed index 0 and exited
with the expected nonzero driver exit code 4:

- runner: `20260715-134236-822-full_run_quality_driver-d8190f1b`;
- project path: `C:\Users\zhuye\Documents\New project\.codex-worktrees\space-syndicate-e-quality-sidecar`;
- actions: attempted 2, progressed 2, rejected invalid 0;
- terminal phase: `first_run.buy_card`;
- failure: `scripted_ui_action_disabled:coach_buy_card`;
- completion: false; settlement state: `idle`; screenshots emitted: none.

This reproduces the earlier A-side output recorded as
`20260715-130746-861-full_run_quality_driver-8c31f95e`. It is a precise blocker,
not evidence that a complete match ran.

## Save and restore limit

The same E run reported 18 required save sections, 8 transactional sections,
10 unsupported sections, `resume_ready=false`, and a fail-closed capture probe.
Its save summary was `supported=false`, `attempted=false`, and
`reason_code=restore_capability_incomplete`.

Therefore the current driver proves only that unsupported continuation is
rejected without exposing an envelope. It does not prove save creation, process
exit, fresh-world restore, deterministic RNG continuation, post-restore action,
or continuation to settlement. The default-save unchanged result in the headed
acceptance remains an isolation check and must not be cited as restore evidence.
