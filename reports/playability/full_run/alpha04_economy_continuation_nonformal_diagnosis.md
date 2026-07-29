# Alpha 0.4-A economy continuation non-Formal diagnosis

Updated: 2026-07-29 13:37 (Asia/Tokyo)

## Result

`STATUS=GREEN_DIAGNOSIS_COMPLETE_PARENT_FORMAL_GATE_STILL_PARTIAL`

No production defect requiring a rule, value, AI, Save, RNG, Main, or Dock
implementation change was found. The single authorized Formal FullRun remains
`INCOMPLETE`; this diagnosis does not turn it into a pass and did not execute a
second terminal FullRun.

The decisive observation is that the claim-on fixed-world probe installed its
second, sale-enabling facility at world `55.661847`. The Formal run stopped at
world `55.647202`: only `0.014645` world seconds earlier. The same probe then
recorded its first authoritative Sale Receipt at world `62.804056`.

This classifies the Formal result as an observation-window/throughput boundary,
not a Player Card Dock adapter regression or shared-capacity deadlock.

## Evidence boundary

- Formal FullRun command count remains `1`; Formal rerun count remains `0`.
- The diagnostic entry point is
  `tests/alpha04_economy_world_time_probe.gd`, not the Formal driver entry.
- Every diagnostic record declares `formal_full_run=false` and exits at a fixed
  public world-time target without requiring victory, settlement, terminal
  presentation, or terminal quiescence.
- Evidence runs: two world-15 presentation/observation arms and two world-80
  early-claim arms. A separate world-1 execution was compile smoke only.
- No `type=summary`, `run_count=1`, or terminal acceptance record was emitted.

## Dock / legacy Planner parity

`tests/alpha04_dock_legacy_planner_parity_test.gd` passed `45 / 45`.

The same real V0.6 catalog hand source was projected through the retired legacy
DTO shape and the production Player Card Dock row shape. The test proves
equivalence for:

- selected facility/card instance;
- facility kind and industry;
- actionable state;
- canonical play reason;
- exact authoritative `offer_fingerprint`;
- all four public facility retarget reasons;
- the final offer selected for production Action Spine submission.

There is therefore direct focused evidence against a Dock-to-Planner mapping
regression.

## Fixed-world early-claim A/B

Both arms used seed `900626424`, visible Main, per-frame Dock observation, and a
world-time target of `80`. They stopped before terminal settlement.

| Field | Early claim on | Early claim off |
| --- | ---: | ---: |
| world / wall seconds | 80.804056 / 100.145 | 80.192524 / 92.851 |
| world per wall second | 0.806871 | 0.863669 |
| actions attempted / progressed / invalid | 137 / 136 / 0 | 143 / 140 / 0 |
| rack rotations | 38 | 39 |
| rack-advancement purchases | 0 | 0 |
| pending-discard reasons | 0 | 0 |
| claim request / success / duplicate | 1 / 1 / 0 | 0 / 0 / 0 |
| first facility world time | 2.376663 | 2.267886 |
| second facility world time | 55.661847 | 56.045092 |
| first Sale Receipt world time | 62.804056 | 62.192524 |
| facilities / Sale Receipts at stop | 2 / 3 | 2 / 3 |
| final lifecycle plan | victory_lifecycle_locked | victory_lifecycle_locked |

The claim-on arm reached the second facility `0.383245` world seconds earlier
and first sale `0.611532` world seconds later. Neither arm entered a capacity
discard path, neither made a rack-advancement purchase, both reached two
facilities and three sales, and both had zero invalid actions. Early claim is
not an economic-continuation blocker.

## Forced-capacity integration

`tests/alpha04_claim_to_sale_integration_test.gd` passed `20 / 20` twice from a
fixed production-session seed.

It proves this complete production-owner chain:

```text
typed commodity claim + exact-once replay
  -> SHARED_V06 hand filled to 5
  -> real Drawer quote/purchase
  -> pending discard + temporary decision
  -> chosen filler discarded and factory purchase committed once
  -> factory played through the production submission owner
  -> complementary market quoted, purchased, and played
  -> original claimed commodity consumed into matching demand
  -> bounded CommodityFlow advance
  -> positive Sale Receipt, owner cash, and regional GDP
```

The claim is preserved through the forced discard; only the selected filler is
removed. The production cadence is observed for up to 90 world seconds so the
real approximately 45-second resolution boundary is inside the test window.

## Presentation / observation throughput A/B

The same seed and claim-off path were stopped at world 15:

| Field | Visible Main + Dock observation | Hidden Main + no explicit Dock observation |
| --- | ---: | ---: |
| world / wall seconds | 15.132659 / 30.591 | 15.101684 / 31.665 |
| world per wall second | 0.494677 | 0.476920 |
| actions attempted / progressed / invalid | 82 / 79 / 0 | 82 / 79 / 0 |
| rack rotations | 22 | 22 |
| first facility world time | 2.269024 | 2.266666 |
| Dock refresh count | 193 | 0 |

The visible/observed arm was about `3.7%` faster, while action counts, rack
rotations, first facility, and Planner transition sequence were equivalent.
This does not isolate Dock composition because the hidden Main still composes
production presentation state, but it excludes rendering plus explicit
per-frame Dock observation as the dominant cause of the Formal run's roughly
70% throughput loss.

## Classification and release effect

- `DOCK_ADAPTER_REGRESSION=false`
- `DIRECT_CLAIM_CAPACITY_BLOCKER=false`
- `VISIBLE_DOCK_OBSERVATION_PRIMARY_THROUGHPUT_CAUSE=false`
- `FORMAL_OBSERVATION_ENDED_BEFORE_SALE_ENABLING_FACILITY=true`
- `PRODUCTION_FIX_REQUIRED=false`
- `FORMAL_GATE_RESULT_CHANGED=false`
- `MERGE_TO_MAIN_ALLOWED=false`

The earlier concurrent orphan Godot process remains a material environment
confound, but this report does not claim it as the sole cause. The clean fixed-
world probes simply prove that the same production path continues through a
second facility and real sales once it is allowed to cross the missed world-
time boundary.

## Next gate

The next single gate is a separately authorized Formal FullRun rerun. Until
that terminal run is green, Draft PR #72 must stay draft and must not merge.
