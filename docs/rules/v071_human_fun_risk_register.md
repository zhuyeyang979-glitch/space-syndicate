# V0.7.1 Human-Fun Risk Register

```text
STATUS=CANDIDATE_NOT_HIGHEST_AUTHORITY
USER_APPROVAL_REQUIRED_BEFORE_CONSTITUTION_FREEZE=true
HUMAN_FUN_PROVEN=false
HUMAN_TEST_STILL_REQUIRED=true
```

This register accompanies `v071_candidate_errata`. It separates deterministic
closure evidence from questions that only people playing the sample can answer.
Simulation can reject a bad profile; it cannot prove that a passing profile is
fun, clear, fair, or comfortable.

## Coverage

- Class A implementation contradictions: exactly 2.
- Class B state-machine closure errata: exactly 6.
- Class C balance experiments: exactly 6.
- Classified risks: exactly 14.
- Profiles: `BASELINE_V07`, `V071_CANDIDATE_A_FAST`, and
  `V071_CANDIDATE_B_STRATEGIC`.
- Player counts: 3, 4, 6, and 8.
- Minimum deterministic seeds: 500 per profile/player-count configuration.

## Class A Risks

| Risk | Severity | Deterministic evidence | Human question |
| --- | --- | --- | --- |
| `V071-R-A1` lead/color cadence collapse | Critical | Independent batch cursors, boundary ordering, exact-once Restore | Can players understand lead changes without a public identity reveal? |
| `V071-R-A2` AI lacks its legal self-lead fact | High | Player/AI semantic parity; no rival identity or hidden-order exposure | Does AI feel coherent without appearing to know another secret? |

## Class B Risks

| Risk | Severity | Deterministic evidence | Human question |
| --- | --- | --- | --- |
| `V071-R-B1` same-revision replacement claims | Critical | Mixed-input exact-once tests, 8-player concurrency, Save/Restore | Is `incoming_locked` obvious without slowing track scanning? |
| `V071-R-B2` merge reduces normal deck below five | Critical | All-zone count and draw-to-five termination | Is the rejection reason immediately understandable? |
| `V071-R-B3` high-level supply bypasses merging | High | Zero Level II+ track spawns | Does Level-I-only supply still create varied early choices? |
| `V071-R-B4` ambiguous post-lock commodity timing | High | `available_from_batch_id` legality and persistence | Is current-versus-next availability readable at a glance? |
| `V071-R-B5` undefined invalid-target resolution | High | Policy coverage and deterministic Receipts | Does full asset refund feel fair when the card and slot are spent? |
| `V071-R-B6` soft-hidden lead can be inferred | Medium | Unique-inference rate and public-cue audit | Is inference satisfying deduction or unwanted bookkeeping? |

## Class C Risks

| Risk | Severity | Deterministic evidence | Human question |
| --- | --- | --- | --- |
| `V071-R-C1` starting assets | High | First-chain timing and zero-asset block rate | Is early scarcity interesting rather than stalled? |
| `V071-R-C2` 70/30, 60/40, or 50/50 supply | High | Purchase-to-draw and commodity merge timing | Does the mixed track create tension without dead arrivals? |
| `V071-R-C3` disabled versus 12 percent color cap | Medium | Color range, cap-hit rate, lead advantage | Do public stances matter without one coalition locking a color? |
| `V071-R-C4` unbounded versus 3-point refresh cap | Medium | Overflow and blocked-action rates | Does the cap reward planning rather than hoarding? |
| `V071-R-C5` 20-second versus 8-second maintenance | High | Timeout and optional-merge acceptance rates | Can new or slower readers decide comfortably in 8 seconds? |
| `V071-R-C6` 1-batch versus 2-batch lead tenure | Medium | Lead advantage, inference, macro-round and victory tail | Which cadence supports planning without exposing the order? |

## Resolution-Pacing Control

This control is cross-cutting and is not an additional Class A, B, or C item.

| Action count | Candidate presentation |
| ---: | --- |
| 1-12 | Full animation |
| 13-24 | Shortened common animation |
| 25-40 | Summary for common economic actions |

Facility builds, monster attacks, military attacks, major control changes, and
Final Settlement stay full. Authority still resolves every card and emits every
Receipt in order. Presentation cannot leak the owner or consume RNG. Human
testing must check whether summary mode remains understandable at the
eight-player ceiling.

## Solar-Multiplier Control

This control is also cross-cutting, not a fifteenth classified risk. Sunlit
facilities use `2.0` and dark facilities use `1.0`. The multiplier applies once
per declared work-rate channel. For an otherwise identical
`factory -> transport -> warehouse -> market` chain:

```text
1.8 <= SUNLIT_CHAIN_THROUGHPUT_RATIO <= 2.2
SOLAR_MULTIPLIER_APPLICATION_COUNT_PER_CHANNEL=1
```

A result of `4.0` or `8.0` is repeated multiplication. A human sample must also
check whether the solar advantage reads as an opportunity without demanding
formula tracking.

## Quantitative Preflight Targets

- First viable factory/market chain: median batch <= 2, p95 <= 3.
- Active actions per player per batch: average 1.5 to 3.0.
- Invalid-target fizzle rate: < 0.10.
- Normal purchase to first draw: median <= 3 batches.
- Commodity Level II median <= 240 seconds; Level III <= 480 seconds.
- Lead acquisition advantage ratio <= 1.5.
- Asset overflow rate < 0.20.
- Zero-asset blocked-action rate < 0.10.
- Resolution p95 <= 15 seconds at 4 players and <= 25 seconds at 8 players.
- Victory-pending tail p95 <= 240 seconds.
- Sunlit chain throughput ratio: 1.8 to 2.2.

A missed target must be reported rather than hidden. It calls for a parameter
recommendation and another experiment, not an unreviewed constitution change.

## Deterministic Result

The 6,000-match matrix covered all three profiles at 3, 4, 6, and 8 players
with 500 fixed seeds per configuration. `V071_CANDIDATE_A_FAST` is the
recommended first human-sample preset.

| Profile | First chain median/P95 | Zero-asset block | Lead advantage | Overflow | Victory tail P95 | Failed targets |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `BASELINE_V07` | 2 / 3 batches | 0.092672 | 1.131989 | 0.129800 | 330s | `VICTORY_PENDING_TAIL_P95_SECONDS` |
| `V071_CANDIDATE_A_FAST` | 2 / 3 batches | 0.024953 | 1.135421 | 0.185933 | 180s | none |
| `V071_CANDIDATE_B_STRATEGIC` | 2 / 3 batches | 0.025544 | 1.133868 | 0.186234 | 330s | `VICTORY_PENDING_TAIL_P95_SECONDS` |

Candidate A also produced 4-player/8-player resolution p95 values of `7.2s`
and `7.44s`, a lead-inference unique rate of `0.873833`, and an explicit
factory-to-market solar throughput ratio of `2.0` with one multiplier
application per work-rate channel. Report fingerprint:
`d664b7ba8d69fe152c7194e2b357db6c996ed36681f2b031433c773ee61d815e`.

This result selects parameters for a sample; it does not prove human fun.

## Human Sample Gate

At least the following perspectives remain necessary: a first-time player, a
returning strategy player, and an accessibility or slower-reading perspective.
Observe opening-choice comprehension, replacement-lock comprehension,
current-versus-next commodity timing, maintenance pressure, fizzle fairness,
hidden-lead deduction, six/eight-player resolution fatigue, and the clarity of
the Victory-pending tail.

No simulation result changes these facts:

```text
HUMAN_FUN_PROVEN=false
HUMAN_TEST_STILL_REQUIRED=true
V07_CONSTITUTION_CONTENT_CHANGE_COUNT=0
V07_PRODUCTION_CONNECTION_COUNT=0
```

Only explicit user approval may authorize a later V0.7.1 highest-constitution
freeze.
