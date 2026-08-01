# Space Syndicate V0.7.1 Complete Game Constitution

```text
CONSTITUTION_ID=space_syndicate.v071.complete
RULESET_ID=v0.7.1
STATUS=frozen_highest_target_constitution
APPROVED_PROFILE_ID=V071_CANDIDATE_A_FAST
APPROVAL_SCOPE=FIRST_HUMAN_TEST_SAMPLE_RULESET
CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6
FULL_V0_7_1_RUNTIME_CUTOVER=false
HUMAN_FUN_PROVEN=false
HUMAN_TEST_REQUIRED=true
```

This is the human-readable companion to
`docs/rules/v071_game_constitution.json`. The JSON file is the closed,
machine-readable highest target authority. It incorporates every rule in the
frozen V0.7 baseline and adds the eight approved V0.7.1 structural rules below.

V0.7.1 is not live production behavior. Production remains V0.6, and the
V0.7.1 Core, adapters, Save, RNG, AI, Player projections, and Review remain
detached until an explicitly authorized atomic cutover. No V0.6/V0.7.1 dual
write is allowed.

## Authority

Conflicts are resolved in this order:

1. The latest explicit user rule decision.
2. `docs/rules/v071_game_constitution.json`.
3. This document.
4. `docs/rules/v07_game_constitution.json`.
5. `docs/rules/v07_game_constitution.md`.
6. The current-production V0.6 rulebook.
7. Older documents, tests, and code.

The three V0.7 files remain byte-identical historical evidence. Their SHA-256
values are frozen in `v071_amendment_from_v07.json`.

## Inherited Structure

All 76 V0.7 constitutional rules remain in force. In particular, V0.7.1 keeps:

- one mixed normal/commodity track with exclusive local segments;
- uniform six-color cycle reset and public revealed stances;
- a fixed hidden lead order that reverses each macro round;
- personal normal-card draw, hand, escrow, and discard zones;
- independent commodity inventory and optional typed merges;
- six independently capped player assets and full action reservations;
- one prebound, immutable card batch and anonymous round-robin resolution;
- facility-only solar work-rate multipliers applied once per channel; and
- the complete-macro-round Victory gate and exact-once FinalSettlement.

The eight V0.7.1 rules close boundaries that V0.7 left ambiguous or that the
detached Reference implementation contradicted.

## Completed Batch Boundary

Rule: `v071.batch_boundary.independent_lead_color_cycles`

`batch_boundary.commit` is driven only by an authoritative completed-card-batch
Receipt. Lead and color-cycle cursors both count completed batches, but neither
cursor owns or implicitly advances the other. A UI timer cannot commit this
boundary.

When both boundaries occur on the same batch, the authority:

1. freezes the outgoing lead;
2. computes double influence with that outgoing lead;
3. commits the color distribution;
4. publishes legal stances and clears the old stance state;
5. advances the lead; and
6. publishes the next batch state.

Save and replay preserve `completed_batch_count`, `lead_batch_cursor`,
`color_cycle_batch_cursor`, `current_lead`, `macro_round_number`, and
`direction`. Restore cannot repeat a committed boundary.

## Private AI Lead Fact

Rule: `v071.lead.ai_private_self_notice`

An AI seat may observe only its own `self_is_current_lead` boolean and its own
`self_influence_class` (`normal` or `double`). This is semantic parity with the
human player's private self-notice, not extra AI knowledge.

The AI cannot observe another player's lead identity, the complete hidden
order, the next lead, another unpublished stance, or the raw weight breakdown.

## Replacement Lock

Rule: `v071.track.replacement_next_scroll_lock`

A newly inserted track item records `claimable_from_scroll_sequence`. It is
projected as `incoming_locked` and cannot be claimed in the same tick as the
claim that caused its replacement. The next authoritative track scroll unlocks
it. Save/Restore preserves the lock, and all claims remain exact-once.

## Minimum Normal Deck

Rule: `v071.normal_merge.minimum_total_five`

Before a normal-card merge commits, the authority counts all owned normal-card
instances in `draw_pile`, `hand`, `committed_escrow`, and `discard`. The result
must remain at least five. A smaller result is rejected with
`minimum_normal_deck_size_violation`.

Current hand size, an empty discard, or a possible future purchase cannot
bypass this rule. Draw-to-five maintenance must always terminate.

## Level-One Supply

Rule: `v071.track.level_one_only_supply`

The unified track spawns only level-one normal and commodity cards. Normal
levels II-IV and commodity levels II-III remain valid definitions, but only
their typed merge authorities may create them.

## Commodity Availability

Rule: `v071.commodity.batch_availability`

Every claimed commodity records `available_from_batch_id`.

- Before the local queue locks, the commodity is usable in the current batch.
- After the local queue locks, it is usable from the next batch.

A post-lock claim cannot join the locked queue, change current reservations, or
change the current action limit. Save/Restore preserves the availability batch.

## Invalid Targets

Rule: `v071.resolution.invalid_target_policy`

Every active action selects one closed policy:

- `FIZZLE_FULL_ASSET_REFUND`
- `FIZZLE_NO_REFUND`
- `RESOLVE_LEGAL_REMAINDER`
- `DETERMINISTIC_FALLBACK`

The default is `FIZZLE_FULL_ASSET_REFUND`. No target is reselected. A fizzled
normal card enters discard, all of that action's reserved assets are released,
the action slot is not returned, and the card does not return to hand. A typed
Receipt and owner-anonymous public causal history are mandatory.

## Soft-Hidden Lead

Rule: `v071.lead.soft_hidden_publication`

Lead identity is not directly published. Public UI cannot show a lead portrait,
lead-specific animation or sound, lead identity in the queue, or ownership of
the double-influence contribution.

The constitution does not promise information-theoretic secrecy. A player may
infer the lead from lawful public mathematics. The measured
`LEAD_INFERENCE_UNIQUE_RATE=0.873833` is therefore a human-experience risk, not a
privacy-contract failure.

## First Human Sample Defaults

The approved profile is `V071_CANDIDATE_A_FAST`, fingerprint
`8d8de8d406ca2f7d5123ecc951a606a0a08b56282bc3d6a40e0cd4d5ff50f19a`.
Its authoritative tunable defaults live in `v071_balance_defaults.json`:

```text
INITIAL_ASSETS_PER_COLOR=2
TRACK_NORMAL_CARD_RATIO_BASIS_POINTS=6000
TRACK_COMMODITY_CARD_RATIO_BASIS_POINTS=4000
SINGLE_COLOR_NET_INTERVENTION_CAP_ENABLED=true
SINGLE_COLOR_NET_INTERVENTION_CAP_BASIS_POINTS=1200
MAX_ASSET_REFRESH_PER_COLOR_PER_BATCH=3
HAND_MAINTENANCE_TIMEOUT_SECONDS=8
LEAD_TENURE_BATCHES=1
COLOR_CYCLE_BATCHES=6
TRACK_SCROLL_INTERVAL_SECONDS=5
TRACK_LOCAL_VISIBLE_SLOT_COUNT=5
```

Batch counts are the sole Core timing authority for lead and color cycles.
Seconds may be shown only as derived presentation estimates.

## Save And Migration

V0.7.1 Save must explicitly preserve the new cursors, lock sequences,
availability batches, rule versions, invalid-target policy, and balance profile
identity and fingerprint. Missing or wrong values fail closed.

```text
V07_SAVE_TO_V071_DIRECT_RESUME=false
V06_SAVE_TO_V071_DIRECT_RESUME=false
V06_SAVE_BACKUP_REQUIRED=true
```

A V0.7 Reference Save may use an explicit detached test-only migration. It can
never be silently interpreted as V0.7.1 and is not a production migration.

## Human Test Boundary

The 6,000 deterministic simulations justified Candidate A as the first sample
default; they did not prove fun. Human testing must still examine the eight
second maintenance window, replacement and commodity timing clarity, full
refund fizzle incentives, high lead inference, approximately 18.6 percent asset
overflow, six/eight-player resolution fatigue, the 60/40 supply ratio, rapid
lead rotation, and the 180-second Victory-pending tail.
