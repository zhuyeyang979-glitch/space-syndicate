# V0.7.3 First Human Playtest Candidate Handoff

STATUS=ALPHA_0_5_C_V073_HUMAN_PLAYTEST_READY_BUILD_INSTRUMENTATION_ONBOARDING_AND_BASELINE_FREEZE_GREEN

BASE_MAIN_SHA=804ed1f0105f00d340253df477d0844c85b170c2

MCP_ACCEPTED_IMPLEMENTATION_SHA=2aafa7de7a2d330551c4c7aef0114a1819e5ddc6

MCP_ACCEPTED_IMPLEMENTATION_TREE=167cc2803015c92487641026d265f26a77d21de4

BRANCH=codex/v073-human-playtest-ready-804ed1f

REQUESTED_SUBAGENTS=6

ACTUAL_MAX_CONCURRENT_SUBAGENTS=6

V073_RULESET_ID=v0.7.3

V073_HUMAN_BASELINE_PROFILE_ID=v073_human_baseline_01

V073_HUMAN_BASELINE_PROFILE_FINGERPRINT=d696623d8cb3371d08c8870189927a53e48212ca30e9f276bc81b6491b01fbd2

PRODUCTION_BALANCE_VALUE_CHANGE_COUNT=0

PLAYTEST_EVENT_SCHEMA_VERSION=1

PLAYTEST_EVENT_TYPE_COUNT=43

PLAYTEST_TELEMETRY_READY=true

PLAYTEST_TELEMETRY_GAMEPLAY_OWNER_COUNT=0

PLAYTEST_TELEMETRY_SAVE_OWNER_COUNT=0

PLAYTEST_TELEMETRY_RNG_OWNER_COUNT=0

PLAYTEST_HIDDEN_INFO_FIELD_COUNT=0

COACH_MARK_COUNT=14

COACH_MARKS_READY=true

PLAYTEST_MARKERS_READY=true

FINAL_QUESTIONNAIRE_READY=true

PLAYTEST_EXPORT_FILES=events.jsonl,summary.json,feedback.json,report.md,manifest.json

PLAYTEST_EXPORT_ATOMIC_WRITE_GREEN=true

TELEMETRY_WORLD_MUTATION_COUNT=0

TELEMETRY_PLAYER_MUTATION_COUNT=0

TELEMETRY_RNG_DRAW_DELTA=0

TELEMETRY_WORLD_TIME_DELTA=0

MCP_CHANGED_SCRIPT_VALIDATION=13/13

MCP_CHANGED_SCENE_LOAD=7/7

MCP_PROJECT_ERROR_COUNT=0

MCP_RUNTIME_ERROR_COUNT=0

MCP_TASK_INTRODUCED_ERROR_COUNT=0

MCP_SANITY_MATCH_COMPLETED=true

MCP_FINAL_SETTLEMENT_COUNT=1

MCP_PLAYTEST_EXPORT_GREEN=true

LAYOUT_1600X960_GREEN=true

LAYOUT_1366X768_GREEN=true

LAYOUT_1920X1080_GREEN=true

REAL_HUMAN_PLAYTEST_COMPLETED_BY_AGENT=false

REAL_HUMAN_PLAYTEST_PENDING_USER=true

HUMAN_PLAYTEST_CANDIDATE_READY=true

MERGE_TO_MAIN_ALLOWED=true

RELEASE_TAG_PLANNED=alpha-0.5c-v073-human-playtest-1

PR77_MODIFIED_BY_THIS_TASK=false

ALPHA04C_RELIABILITY_TRACK_FROZEN=true

NEXT_TASK=WAIT_FOR_USER_HUMAN_PLAYTEST_DATA

## Outcome

The V0.7.3 production sample now has an observation-only playtest layer, lightweight first-session guidance, three in-match subjective markers, a scrollable post-match questionnaire, and atomic local reports. The candidate keeps the already connected V0.7.3 gameplay, AI, player projection, UI, Victory, and FinalSettlement owners intact. Save and Continue remain visible, disabled, and explicitly described as unavailable for this sample.

This task did not reopen Alpha 0.4-C, PR #77, V0.6 Save, Formal, FullRun, Smoke, V8, or Process A. It also did not alter a production balance value. The branch changes 28 scoped files: 13 GDScripts, 7 scenes, the launcher, two playtest documents, one hypothesis report, and four visual evidence files. No MCP overlay, `.import`, `.uid`, `.godot`, runtime export, production balance file, Save file, or `main.gd` change is in the implementation commit.

## Frozen Human Baseline

`v073_human_baseline_01` is a named fingerprint over the exact production values inherited from the sample build. Its canonical input recomputes to `d696623d8cb3371d08c8870189927a53e48212ca30e9f276bc81b6491b01fbd2`.

| Value | Frozen baseline |
| --- | ---: |
| Initial assets / per-color cap | 0 / 6 |
| Starter / standard L1 asset cost | 0 / 1 |
| Unified Track normal / commodity | 6000 / 4000 bps |
| Intervention cap | 1200 bps |
| Max refresh per color per batch | 3 |
| Maintenance timeout | 8 seconds |
| Lead tenure | 1 batch |
| Color cycle | 6 batches |
| Track cadence / local visible slots | 5 seconds / 5 |
| Normal hand / commodity inventory | 5 / 5 |
| Submission window | 30 seconds |
| Sunlit / dark efficiency | 2.0 / 1.0 |

Resolution remains fixed hidden round-robin, facility contention still Fizzles the later action, and initiative bidding remains retired. The task records possible future balance questions in [v073_candidate_balance_hypotheses.md](../playtest/v073_candidate_balance_hypotheses.md), but approves none of them. Human Run A and Run B must happen before any production balance pass.

## Observation Boundary

`V073PlaytestTelemetryService` subscribes to the typed `V073SampleApplicationReceiptV1` stream, local/public projection changes, public resolution receipts, public observation receipts, FinalSettlement presentation, and local UI presentation/feedback signals. It never issues a gameplay intent. Its debug contract reports gameplay owner 0, Save owner 0, RNG owner 0, world mutation 0, player mutation 0, RNG draw delta 0, world-time delta 0, public-log delta 0, and private-feedback delta 0.

The deterministic acceptance runs the same fixed-seed 1 Human + 3 AI match once with telemetry detached and once with telemetry connected. The final gameplay snapshot and FinalSettlement match exactly. This is the authoritative zero-side-effect proof; telemetry never recomputes a result and cannot participate in rules, RNG, AI, time, resolution order, or Victory.

The 43-event schema covers session lifecycle, card and target interactions, submission, track and deck activity, optional merge, asset refresh, batch resolution, contention/Fizzle, solar efficiency, AI submission, Victory, settlement, Coach Marks, markers, UI backtracking, and questionnaire state. Every payload key is allowlisted and fails closed. Opponent hands, unpublished targets, AI plans, full hidden lead order, private assets, future submissions, private card instance IDs, user/account identity, machine identity, and absolute paths are explicitly forbidden.

## First-Session Help And Feedback

Fourteen contextual Coach Marks explain the hand and commodity limits, 0/6 assets, free Starters, paid L1 cards, the unified track, target binding, lock semantics, local action ordering, hidden round-robin resolution, contention/Fizzle, solar efficiency, and the Save boundary. They are short, skippable, replayable from settings, and do not pause AI or alter gameplay values.

The in-match panel records `confused`, `frustrated`, or `fun`, plus an optional short note, current public interaction mode, public surface, batch ID, and timestamp. It can be closed and has no gameplay mutation path.

After FinalSettlement, the skippable questionnaire presents fourteen 1-7 ratings covering comprehension, first-turn direction, assets, track, targets, ordering, Fizzle, hidden lead, the 30-second window, resolution wait, AI, readability, fun, and replay intent. Five optional text prompts capture the best, most confusing, and most frustrating moments, one desired rule change, and expected match length.

## Local Export

Each session writes atomically under `user://playtests/v073/<session_id>/`:

- `events.jsonl`
- `summary.json`
- `feedback.json`
- `report.md`
- `manifest.json`

The manifest binds the build SHA, ruleset, frozen profile, seed, player count, timestamps, schema versions, and SHA-256 hashes. Export has no network dependency and no Save-owner role. A failure is a non-blocking UI notice with no unbounded retry.

The exact-SHA MCP sanity export used build `2aafa7de7a2d330551c4c7aef0114a1819e5ddc6`, seed `900626424`, four players, and the frozen profile. All five files exist; the 21 events have contiguous sequence numbers, no forbidden fields, matching hashes, submitted questionnaire data, and exactly one FinalSettlement.

## Verification

| Evidence | Result |
| --- | ---: |
| Instrumentation, privacy, export, and zero-side-effect acceptance | 183/183 |
| V0.7.3 Constitution contract | 269/269 |
| V0.7.3 balance defaults | 183/183 |
| V0.7.3 production Core aggregate | 52/52 |
| Production 3/4/6/8-player regression | 672/672 |
| MCP changed scripts | 13/13 |
| MCP changed scenes | 7/7 |

All four player-count runs reached `settled` and exercised 24 facility-contention Fizzles with zero invalid actions, nonfinite values, privacy violations, dual authority, or failures.

The exact MCP session `v073pt-exact-2aafa7de-01` ran Godot 4.7 at endpoint `http://127.0.0.1:8921/` with editor PID 4944. Initial scan reached quiescence, the active import-operation maximum was one, and no request reached HTTP before readiness. The live 1 Human + 3 AI sanity match completed with runtime errors 0, duplicate settlement 0, export GREEN, and FinalSettlement exactly once. Play mode then exited and the editor stopped cleanly without force: exit code 0, endpoint owner after 0, process count after 0, native signal 11 count 0.

The scan retained 26 certified baseline diagnostics: 8 Unicode diagnostics, 12 parse diagnostics, and 6 consequent failed legacy-script loads. They are unchanged, have no changed-file or V0.7.3 production-path association, and did not affect reload, scene loading, the runtime marker, export, or clean stop. They remain recorded rather than globally ignored.

## UI Evidence

- [1600x960 four-player Coach Mark](../ui/v073_human_playtest/1600x960_4p_coach.png)
- [1366x768 four-player Region Popup](../ui/v073_human_playtest/1366x768_4p_region_popup.png)
- [1366x768 scrollable questionnaire](../ui/v073_human_playtest/1366x768_questionnaire.png)
- [1920x1080 eight-player Coach Mark and roster](../ui/v073_human_playtest/1920x1080_8p_coach.png)

All three target resolutions pass. Coach Marks avoid the Hand Dock and unified track, the marker avoids the target rail, the questionnaire scrolls, the six-color pool remains legible, special actions remain visible, the Save-disabled notice remains visible, and the Region Popup still closes.

## Human Runs

The agent completed MCP sanity only; it does not claim human fun. The user-facing procedure is [v073_first_human_playtest_guide.md](../../docs/playtest/v073_first_human_playtest_guide.md).

Run A uses 1 Human + 3 AI at 1600x960 with seed `900626424`. Run B uses the same profile at 1366x768 or the user's normal resolution with a random seed. Both must be played naturally to FinalSettlement without the sanity acceleration command. Return `events.jsonl`, `summary.json`, `feedback.json`, and `report.md` from both runs, keeping `manifest.json` beside them for identity and hash verification.

After those human reports return, the next engineering task is `ALPHA_0_5_D_V073_HUMAN_PLAYTEST_DATA_BALANCE_PASS_1`. Until then, the next task is `WAIT_FOR_USER_HUMAN_PLAYTEST_DATA`.
