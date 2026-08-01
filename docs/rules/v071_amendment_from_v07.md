# V0.7 to V0.7.1 Approved Amendment

```text
STATUS=approved_and_frozen
FROM_CONSTITUTION_ID=space_syndicate.v07.complete
TO_CONSTITUTION_ID=space_syndicate.v071.complete
APPROVED_PROFILE_ID=V071_CANDIDATE_A_FAST
CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6
FULL_V0_7_1_RUNTIME_CUTOVER=false
HUMAN_FUN_PROVEN=false
HUMAN_TEST_REQUIRED=true
```

The user approved Candidate A for the first human-test sample. This amendment
promotes eight structural closures to the highest target constitution and
freezes eight tunable profile records for that sample. It does not overwrite
the V0.7 baseline, connect production, or authorize dual writes.

## Structural Amendments

| ID | Classification | V0.7.1 rule | Approved closure |
| --- | --- | --- | --- |
| `V071-A1` | implementation contradiction | `v071.batch_boundary.independent_lead_color_cycles` | Independent completed-batch cursors; outgoing lead weights a simultaneous color boundary. |
| `V071-A2` | implementation contradiction | `v071.lead.ai_private_self_notice` | AI receives only its own lead boolean and influence class. |
| `V071-B1` | state-machine closure | `v071.track.replacement_next_scroll_lock` | Replacement is locked until the next authoritative scroll. |
| `V071-B2` | state-machine closure | `v071.normal_merge.minimum_total_five` | A merge cannot leave fewer than five owned normal cards. |
| `V071-B3` | state-machine closure | `v071.track.level_one_only_supply` | Unified-track supply creates only level-one cards. |
| `V071-B4` | state-machine closure | `v071.commodity.batch_availability` | Queue lock determines current- versus next-batch availability. |
| `V071-B5` | state-machine closure | `v071.resolution.invalid_target_policy` | Default fizzle refunds assets, discards the card, and consumes the action slot. |
| `V071-B6` | state-machine closure | `v071.lead.soft_hidden_publication` | Lead is never directly published but may be inferred. |

## Approved Defaults

| Record | V0.7 | V0.7.1 first sample |
| --- | ---: | ---: |
| Initial assets per color | 1 | 2 |
| Normal track ratio | 7000 | 6000 |
| Commodity track ratio | 3000 | 4000 |
| Single-color intervention cap | disabled | enabled, 1200 bps |
| Refresh cap per color/batch | none | 3 |
| Maintenance timeout | 20 seconds | 8 seconds |
| Lead tenure authority | 60-second estimate | 1 completed batch |
| Color cycle authority | 180-second estimate | 6 completed batches |

Track scroll remains five seconds and each local segment remains five slots.
The profile remains tunable after human evidence; it is not final commercial
balance.

## Evidence

The approval is based on three deterministic profiles across 3, 4, 6, and 8
players with 500 seeds per configuration, for 6,000 matches total. Candidate A
met all encoded targets and reduced Victory-pending p95 from 330 seconds to 180
seconds. Its observed zero-asset block rate was `0.024953`, lead acquisition
advantage `1.135421`, asset overflow `0.185933`, lead inference unique rate
`0.873833`, and sunlit-chain throughput ratio `2.0`.

Simulation report fingerprint:
`d664b7ba8d69fe152c7194e2b357db6c996ed36681f2b031433c773ee61d815e`.

## Historical Baseline

The machine companion records SHA-256 and Git-blob provenance for V0.7 and the
PR #82 candidate evidence. The V0.7 constitution and defaults remain immutable;
`V07_HISTORICAL_CONSTITUTION_CONTENT_CHANGE_COUNT=0`.

## Migration Boundary

V0.7 and V0.6 Saves cannot directly resume as V0.7.1. New fields cannot be
silently defaulted. An explicit detached V0.7 test migration may exist, while a
V0.6 production migration requires backup and a future atomic-cutover task.
