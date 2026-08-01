# V0.7.1 Candidate Errata

```text
STATUS=CANDIDATE_NOT_HIGHEST_AUTHORITY
USER_APPROVAL_REQUIRED_BEFORE_CONSTITUTION_FREEZE=true
HUMAN_FUN_PROVEN=false
HUMAN_TEST_STILL_REQUIRED=true
V07_CONSTITUTION_CONTENT_CHANGE_COUNT=0
V07_PRODUCTION_CONNECTION_COUNT=0
```

This document is a detached Reference proposal built on
`space_syndicate.v07.complete`. It does not amend the frozen V0.7 constitution,
change the V0.6 production rules, or authorize a production connection. The
machine-readable companion is `docs/rules/v071_candidate_errata.json`.

## Classification Summary

| Class | Count | Treatment |
| --- | ---: | --- |
| `CLASS_A_IMPLEMENTATION_CONTRADICTION` | 2 | Correct the detached implementation to match facts already owned by V0.7. |
| `CLASS_B_STATE_MACHINE_CLOSURE_ERRATA` | 6 | Candidate closure only; user approval is required before a constitution freeze. |
| `CLASS_C_BALANCE_EXPERIMENT` | 6 | Tunable sample parameters, never immutable constitutional facts. |

Total classified items: 14.

## Class A: Implementation Contradictions

### V071-A1: Independent lead and color-cycle boundaries

The frozen defaults declare a 60-second lead tenure and a 180-second color
cycle, but the Reference implementation advances the lead only from
`color_cycle.commit_boundary`. That collapses two independent cadences into one.

The detached correction uses an authoritative completed-card-batch Receipt to
drive `batch_boundary.commit`. Both cursors use completed batches, but they are
independent:

```text
LEAD_ADVANCE_UNIT=COMPLETED_CARD_BATCH
COLOR_CYCLE_ADVANCE_UNIT=COMPLETED_CARD_BATCH
LEAD_ADVANCE_IMPLICIT_IN_COLOR_COMMIT=false
```

When both boundaries occur on the same batch, the order is fixed:

1. Freeze the outgoing current lead.
2. Calculate the 6 percent weight with that outgoing lead.
3. Commit the color distribution.
4. Clear published stances.
5. Advance the lead cursor.
6. Publish the next batch state.

The UI timer cannot commit this boundary. Save/Replay must preserve
`completed_batch_count`, `lead_batch_cursor`, `color_cycle_batch_cursor`,
`current_lead`, `macro_round_number`, and `direction`, and Restore must not
repeat an already committed boundary.

### V071-A2: AI self-lead parity

The Player Projection already gives the viewing player a private self-lead
notice. The AI Observation must receive the same self-owned fact:

```text
self_is_current_lead=boolean
self_influence_class=normal|double
```

AI still cannot observe another lead identity, the hidden order, the next lead,
another unpublished stance, or raw weight decomposition. Human and AI field
names may differ, but the self-owned fact and privacy boundary must be
semantically equal.

## Class B: State-Machine Closure Errata

### V071-B1: Replacement lock

```text
TRACK_REPLACEMENT_ACTIVATES_ON_NEXT_SCROLL=true
TRACK_REPLACEMENT_CLAIMABLE_SAME_TICK=false
```

A newly inserted card records `claimable_from_scroll_sequence` or
`claimable_from_track_revision`. It remains `incoming_locked` and unclaimable
until the next authoritative track scroll. This applies to click, double-click,
high-frame-rate input, mixed keyboard/mouse input, eight-player concurrency,
and Save/Restore. Claims remain exact-once.

### V071-B2: Minimum normal-deck size

```text
NORMAL_DECK_MINIMUM_TOTAL_CARD_COUNT=5
reason_code=minimum_normal_deck_size_violation
```

Before a merge commits, count every owned normal-card instance in `draw_pile`,
`hand`, `committed_escrow`, and `discard`. The post-merge total must remain at
least five. Current hand size, an empty discard, or a possible future purchase
cannot bypass this check. This keeps draw-to-five maintenance terminating.

### V071-B3: Level-one-only track supply

```text
NORMAL_TRACK_SPAWN_LEVEL=1
COMMODITY_TRACK_SPAWN_LEVEL=1
```

Level II-IV normal cards and Level II-III commodities remain valid definitions,
but players obtain them only through their typed merge paths. The unified-track
supply cannot bypass progression by spawning a higher-level instance.

### V071-B4: Commodity batch availability

Every claimed commodity records `available_from_batch_id`.

- If the local queue is not locked, it is usable in `current_batch`.
- If the local queue is locked, it is usable in `next_batch`.

A post-lock claim cannot join the immutable queue, alter current reservations,
or alter the current action limit. Save/Restore preserves the availability
batch exactly.

### V071-B5: Invalid-target default

Every active action declares one of:

- `FIZZLE_FULL_ASSET_REFUND`
- `FIZZLE_NO_REFUND`
- `RESOLVE_LEGAL_REMAINDER`
- `DETERMINISTIC_FALLBACK`

The candidate default is `FIZZLE_FULL_ASSET_REFUND`. A fizzled normal card goes
to `discard`; all reserved assets are released; the action slot is not returned;
the card does not return to hand; no target is reselected. Core emits a typed
Receipt and public causal history. Content with no declared policy cannot enter
production V0.7.

### V071-B6: Soft-hidden lead

```text
LEAD_IDENTITY_NOT_DIRECTLY_PUBLISHED=true
LEAD_IDENTITY_MAY_BE_INFERRED_FROM_PUBLIC_INFORMATION=true
```

The system does not publish a lead portrait, lead-specific animation or sound,
lead identity in the public queue, or ownership of the 6 percent weight. It does
not promise that public outcomes are mathematically non-inferable. Measure
`LEAD_INFERENCE_UNIQUE_RATE` as an experience metric; unique inference alone is
not a privacy failure.

## Class C: Balance Experiments

| ID | Parameter | Candidate values |
| --- | --- | --- |
| `V071-C1` | Initial assets per color | 1, 2 |
| `V071-C2` | Normal/commodity ratio | 7000/3000, 6000/4000, 5000/5000 basis points |
| `V071-C3` | Single-color net intervention cap | disabled, or enabled at 1200 basis points |
| `V071-C4` | Per-color refresh per batch | no additional cap, or 3 |
| `V071-C5` | Hand-maintenance timeout | 20 seconds, 8 seconds |
| `V071-C6` | Lead tenure | 1 or 2 completed batches |

These are sample-test parameters. None is a highest-authority rule.

## Profiles

Fingerprints are SHA-256 over the UTF-8 fixed-order input recorded in the JSON
companion. `profile_id` and the actual fingerprint must be saved and replayed;
Locale, UI, and player count cannot silently select another profile.

| Profile | Assets | Track | Intervention cap | Refresh cap | Maintenance | Lead | Color cycle | Fingerprint |
| --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- |
| `BASELINE_V07` | 1 | 7000/3000 | off | none | 20s | 2 batches* | 6 batches* | `3343a3896df495ca33e927e5fa94cf92d9989874b29c79a6f7d5acda569cc15a` |
| `V071_CANDIDATE_A_FAST` | 2 | 6000/4000 | 1200 bps | 3 | 8s | 1 batch | 6 batches | `8d8de8d406ca2f7d5123ecc951a606a0a08b56282bc3d6a40e0cd4d5ff50f19a` |
| `V071_CANDIDATE_B_STRATEGIC` | 2 | 6000/4000 | 1200 bps | 3 | 8s | 2 batches | 6 batches | `29357f147ef4690fcb94255d5a7ec2fbf6836aab075441d3c65a0367530f80f4` |

`*` Baseline keeps the existing 60-second/180-second values. The 2/6 batch
figures are an explicit simulation translation at 30 seconds per completed
batch, not a constitution amendment.

The deterministic 6,000-match preflight recommends
`V071_CANDIDATE_A_FAST`: it missed no quantitative target, while Baseline and
Candidate B both exceeded the Victory-pending tail target at `330s` p95. The
recommendation uses policy `v071.closed_heuristic_policy.v1` and report
fingerprint `d664b7ba8d69fe152c7194e2b357db6c996ed36681f2b031433c773ee61d815e`.
It is a first human-sample preset, not proof of fun or a constitution freeze.

## Resolution Presentation Compression

Authoritative cards continue to resolve one by one.

| Submitted actions | Presentation candidate |
| ---: | --- |
| 1-12 | Full animation |
| 13-24 | Shortened common animation |
| 25-40 | Summary presentation for common economic actions |

Facility builds, monster attacks, military attacks, major control changes, and
Final Settlement always retain full presentation. Compression cannot merge
Receipts, change order, leak an owner, consume RNG, or remove public causal
history.

## Solar Multiplier Guard

Sunlit work uses `2.0`; dark work uses `1.0`. Each declared work-rate channel
applies the multiplier exactly once:

- `factory_production_rate`
- `transport_throughput`
- `market_demand_or_consumption_rate`
- `warehouse_ingress_throughput`
- `warehouse_egress_throughput`

For the same `factory -> transport -> warehouse -> market` chain, the candidate
acceptance range is `1.8 <= sunlit/dark throughput <= 2.2`. Ratios of `4.0` or
`8.0` indicate repeated multiplication. Presentation brightness never owns the
solar state.

## Approval Boundary

Detached Reference testing is allowed. Freezing V0.7.1 or connecting any of
these rules to production is not. The next freeze task is
`V071_HIGHEST_CONSTITUTION_AMENDMENT_FREEZE_AFTER_USER_APPROVAL`, and only after
explicit user approval.
