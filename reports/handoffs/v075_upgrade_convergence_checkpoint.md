# V0.7.5 Upgrade Convergence Checkpoint

```text
CHECKPOINT_ID=v075.upgrade.convergence.checkpoint.v1
TASK_ID=ALPHA_0_5_C2_V075_MONSTER_AUTONOMY_PRIVATE_INSTANT_SKILLS_AND_MILITARY_ASSAULT_MISSIONS_PRODUCTION_CUTOVER
RULESET_ID=v0.7.5
BRANCH=codex/v075-monster-military-combat-bd0af5c
BASE_MAIN_SHA=bd0af5c99c5267cdbe7d66c01034f80bb4d704fd
STAGE_A_STATUS=IN_PROGRESS
STAGE_B_STARTED=false
CURRENT_TASK_NO_RESET=true
```

## Rank supply contract

V0.7.5 inherits the hand-only, equal-rank normal DBG merge rule. A monster
rank path is therefore:

```text
L1 normal card on the shared track
-> personal discard
-> normal DBG reshuffle
-> ordinary hand
-> same-family/equal-rank maintenance merge
-> higher-rank card in the ordinary hand
-> prebound UPGRADE_EXISTING action in the next submission window
```

The runtime and AI do not inspect, reorder, or predict the hidden draw-pile
order. An active rank-one source proves only its public family lineage. While
that source is active, the acquisition policy selects only its family; an
unrelated family would create a replacement detour rather than an upgrade.
The owner may keep a visible active-family L1 card in hand while another copy
cycles through the ordinary DBG. No new discard, mulligan, or draw authority is
introduced by this checkpoint.

Maintenance still scans only the authoritative hand projection. A failed merge
receipt is a runtime failure and does not silently close maintenance. A
successful merge creates a new L2 identity; it does not reset any existing
monster skill cooldown because the source cooldown belongs to the replaced
monster source, not to the DBG card identity.

## Forward-compatible successor markers

The historical V0.7.5 constitution remains unchanged. Its military public
batch wording is the current Stage A implementation, but it is not the final
successor contract:

```text
CURRENT_MILITARY_EXECUTION_MODE=normal_public_batch
V075_MILITARY_FINAL_LANE=pending_v076_private_direct_intervention
SUPERSEDED_BY_V076_DIRECT_INTERVENTION=true
CURRENT_REGION_RENDERING_MODE=independent_region_polygon_snapshot
SUPERSEDED_BY_V076_EXACT_PARTITION=true
```

No new public military queue code or queue-specific UI is added after this
checkpoint. V0.7.6 must keep military cards on the ten-slot supply track and
in the normal DBG while moving only their execution to the generic private
direct-action lane. V0.7.6 must replace presentation ownership with one exact
shared spherical topology surface; this checkpoint does not claim that map
migration is complete.

## Evidence at checkpoint

```text
AI_POLICY_TEST=25/25
NATURAL_ACQUISITION_TEST=56/56
DBG_LIFECYCLE_TEST=99/99
MONSTER_CARD_REUSE_TEST=4/4
NATURAL_RUNTIME_ERROR_ZERO_TEST=11/11
PARSE_ONLY_TEST=PASS
```

The extended diagnostic used only real runtime track purchase, discard,
reshuffle, hand, maintenance, and settlement paths. It settled with zero
runtime errors and zero deadlocks; a longer coverage run is still required to
observe a positive natural upgrade counter before Stage A can close.

```text
STAGE_A_COMPLETION=NOT_YET
STAGE_B_START=FORBIDDEN_UNTIL_V075_GREEN_MERGED_TAGGED_AND_SYNCED
```
