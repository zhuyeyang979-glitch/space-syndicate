# V0.7.3 Candidate Balance Hypotheses

Status: observation hypotheses only. None of the items below is approved for production.

Baseline profile: `v073_human_baseline_01`

Fingerprint: `d696623d8cb3371d08c8870189927a53e48212ca30e9f276bc81b6491b01fbd2`

Production balance value changes in this task: `0`

The automated runs prove legality, determinism, privacy, and completion. They do not prove that a human understands the first turn or enjoys the pacing. Any proposed adjustment must cite both required human sessions and preserve the V0.7.3 Constitution.

| ID | Question for the first human baseline | Evidence to compare | Review trigger | Candidate direction, not approved |
| --- | --- | --- | --- | --- |
| H-01 | Is 30 seconds enough for a first-time player? | `TIME_TO_FIRST_VALID_SUBMISSION_SECONDS`, `AVERAGE_PLANNING_TIME_SECONDS`, `SUBMISSION_TIMEOUT_COUNT`, first-round questionnaire score | Both runs show timeout or a score of 3 or lower | Consider onboarding/presentation first; consider a window change only with repeated evidence |
| H-02 | Does the zero-asset opening delay the first meaningful paid L1 play? | `TIME_TO_FIRST_ASSET_REFRESH_SECONDS`, `TIME_TO_FIRST_PAID_L1_PLAY_SECONDS`, `ASSET_STARVATION_BATCH_COUNT` | Paid L1 never occurs or starvation persists across multiple batches in both runs | Review refresh cadence or offer clarity without changing Starter cost |
| H-03 | Does facility contention create strategy or repeated frustration? | `FACILITY_CONTENTION_COUNT`, `FIZZLE_COUNT_BY_REASON`, `LOCAL_PLAYER_FIZZLE_RATE`, Frustrated markers, Fizzle fairness score | High local Fizzle rate aligns with repeated frustration and fairness score 3 or lower | Improve prediction and target feedback before considering a rule/value change |
| H-04 | Is the Unified Track understandable and worth using? | `TRACK_COMMODITY_CLAIM_COUNT`, `TRACK_NORMAL_PURCHASE_COUNT`, Track hover count, Unified Track questionnaire score | Offers are seen but rarely acquired, with comprehension score 3 or lower | Review card presentation and acquisition affordance before changing the 60/40 ratio |
| H-05 | Does the personal DBG create a readable draw/discard rhythm? | `RESHUFFLE_COUNT`, optional merge count, Hand Dock hover count, free-text confusion | Players cannot explain discard/reshuffle or avoid optional merge because it is unclear | Improve deck/discard projection; preserve the 12-card Starter baseline for the first pass |
| H-06 | Is AI resolution waiting noticeable? | `AI_THINK_LATENCY_P50_MS`, `AI_THINK_LATENCY_P95_MS`, `BATCH_RESOLUTION_P95_MS`, resolution-wait score | P95 latency is high and the human score is 3 or lower | Profile AI/presentation timing; do not weaken AI information boundaries |
| H-07 | Is the victory tail longer than the interesting part of the match? | `VICTORY_PENDING_DURATION_SECONDS`, `MATCH_DURATION_SECONDS`, expected-length answer, Fun/Frustrated marker timing | Both runs report an overlong tail or desired length materially below observed length | Review progress cadence only after confirming the tail is rules-driven rather than UI waiting |
| H-08 | Does hidden lead feel unfair despite deterministic rotation? | Fizzle chronology, public history, hidden-lead fairness score, free-text comments | Both runs score fairness 3 or lower and cite order uncertainty | Improve public explanation and post-resolution trace before changing fixed hidden round-robin |

## Balance-pass entry gate

The first production balance pass may begin only after Run A and Run B each return `events.jsonl`, `summary.json`, `feedback.json`, and `report.md`, with matching manifest hashes. The analysis must distinguish comprehension, presentation, pacing, and numerical balance before proposing changes.
