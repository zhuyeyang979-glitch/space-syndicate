# V0.7.2 human-test risk register

`V072_STARTER_FREE_FAST` is frozen for the first human sample. The freeze records the user's
rule decision; it does not establish commercial balance or human fun.

```text
HUMAN_FUN_PROVEN=false
HUMAN_TEST_REQUIRED=true
V072_PRODUCTION_CONNECTION_COUNT=0
V072_DUAL_WRITE_COUNT=0
```

## Quantitative warning

The 6,000-match deterministic report retained two failed targets:

- `FIRST_STANDARD_L1_PLAY_MEDIAN_BATCH`: observed `5`, target `<=4`.
- `STANDARD_CARD_ASSET_ECONOMY_TOO_SLOW`: paid cards enter play later than intended.

Starter action share at batch 10 is `0.634132`, below the `0.70` hard warning threshold, but
the free-Starter repeat-build rate is `0.575579`. The hard threshold passes; long-term choice
quality remains a human-test question.

## Required observations

| Risk | Human-test question |
| --- | --- |
| Paid L1 timing | Does the paid-card economy feel delayed after the free opening? |
| Starter dominance | Are free Starters chosen for interesting plans or because paid cards feel inefficient? |
| Merge sacrifice | Is losing a permanent free L1 for a standard L2 clear and satisfying? |
| Zero-asset comprehension | Does `0/6` read as an intentional initialized state rather than a missing system? |
| Card identity | Is the Starter badge legible in hand, discard, reshuffle, Restore, and merge views? |
| Economy causality | Can players connect the first facility and GDP to the batch-two asset refresh? |
| Maintenance time | Can first-time and slower-reading players evaluate the new merge tradeoff in eight seconds? |
| Large tables | Do six- and eight-player repeated resolutions remain comprehensible rather than tiring? |
| End tail | Does the 150-second Victory-pending P95 still contain meaningful decisions? |

Simulation can prove deterministic closure, zero opening asset deadlock, and encoded thresholds.
It cannot prove comprehension, perceived fairness, strategic variety, pacing, or fun. These risks
must remain open until the first human sample is observed.
