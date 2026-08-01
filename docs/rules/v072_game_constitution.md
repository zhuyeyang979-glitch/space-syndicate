# Space Syndicate V0.7.2 Complete Game Constitution

```text
CONSTITUTION_ID=space_syndicate.v072.complete
RULESET_ID=v0.7.2
STATUS=frozen_highest_target_constitution
USER_APPROVES_V072_FREE_STARTER_BOOTSTRAP=true
APPROVED_PROFILE_ID=V072_STARTER_FREE_FAST
APPROVAL_SCOPE=FIRST_HUMAN_TEST_SAMPLE_RULESET
CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6
FULL_V0_7_2_RUNTIME_CUTOVER=false
HUMAN_FUN_PROVEN=false
HUMAN_TEST_REQUIRED=true
```

This is the human-readable companion to
`docs/rules/v072_game_constitution.json`. The JSON file is the closed,
machine-readable highest target authority. V0.7.2 inherits the complete,
hash-locked V0.7.1 constitution and changes only the approved opening economy,
Starter identity, card costs, merge consequence, projections, and persistence.

V0.7.2 is not live production behavior. Production remains V0.6. Detached
Core, adapters, Save, RNG, AI, Player projections, and Review tooling may model
the target, but no production connection or V0.6/V0.7.2 dual write is allowed.

## Authority

Conflicts are resolved in this order:

1. The latest explicit user rule decision.
2. `docs/rules/v072_game_constitution.json`.
3. This document.
4. `docs/rules/v071_game_constitution.json`.
5. `docs/rules/v071_game_constitution.md`.
6. `docs/rules/v07_game_constitution.json`.
7. `docs/rules/v07_game_constitution.md`.
8. The current-production V0.6 rulebook.
9. Older documents, tests, and code.

The V0.7 and V0.7.1 constitutions, Markdown companions, and balance defaults
remain byte-identical historical evidence. V0.7.2 composes the 84 inherited
V0.7.1 rules with eight explicit V0.7.2 amendments; it does not silently edit
the earlier freeze.

## Zero-Asset Genesis

Rule: `v072.assets.zero_genesis_balances`

Each player's six-color asset Owner exists at genesis. Life, energy, industry,
technology, commerce, and shipping balances are all zero, as are their fixed
point remainders. The player surface displays `0/6`. This is an initialized
zero state, never an absent Owner, an uninitialized pool, or a third state.

```text
INITIAL_ASSETS_PER_COLOR=0
INITIAL_FIXED_POINT_REMAINDER_PER_COLOR=0
ZERO_DEADLOCK_MECHANISM=zero_asset_cost_starter_cards
```

The V0.7.1 first-sample value of two assets per color remains historical and is
not a V0.7.2 runtime default.

## Closed Starter Definitions

Rule: `v072.starter.closed_definition_registry`

Genesis creates exactly twelve normal-card instances for each player: one L1
factory and one L1 market in each of the six colors. Each definition creates
exactly one instance.

```text
starter.facility.factory.life.rank_1
starter.facility.market.life.rank_1
starter.facility.factory.energy.rank_1
starter.facility.market.energy.rank_1
starter.facility.factory.industry.rank_1
starter.facility.market.industry.rank_1
starter.facility.factory.technology.rank_1
starter.facility.market.technology.rank_1
starter.facility.factory.commerce.rank_1
starter.facility.market.commerce.rank_1
starter.facility.factory.shipping.rank_1
starter.facility.market.shipping.rank_1
```

Every definition has `origin_class=starter_bootstrap`, `level=1`,
`asset_cost_profile=starter_zero_asset`, `starter_badge=true`,
`track_spawn_allowed=false`, and `purchase_allowed=false`. Starter creation is
closed after genesis. The unified track has zero Starter definitions and can
never mint another free card.

## Persistent Free Cost

Rule: `v072.starter.persistent_zero_asset_cost`

Every legal play of a Starter card has zero primary, secondary, and any-color
asset cost. This is stable definition semantics, not a first-turn exception,
zone inference, or one-use coupon. The card remains free through draw, hand,
escrow, resolution, discard, reshuffle, Save, and Restore.

Free means only that the six-color asset cost is zero. Targets, region rules,
facility slots, action limits, queue lock, prebound targets, exact-once
Receipts, and any authored non-asset requirement remain authoritative. There
is no first-batch Runtime branch, direct asset injection, or UI cost bypass.

## Standard Card Costs

Rule: `v072.standard.level_one_asset_cost`

The unified track creates standard definitions such as
`facility.factory.life.rank_1`, never their `starter.` equivalents. A purchased
normal card enters personal discard and cannot be used immediately.

A standard L1 factory or market costs one asset of the definition's color when
played. Standard rank defaults remain L2=2, L3=3, and L4=4. An explicitly
authored card may override its rank default. Cost can never be inferred from a
display name, artwork, former zone, or ownership of a similar facility.

## Starter And Standard Merge

Rule: `v072.starter.standard_merge_consumes_privilege`

A player may deliberately merge a Starter L1 with a standard L1 when color,
facility type, merge family, and rank match. Both sources are consumed and the
output is a standard L2 with `asset_cost_profile=standard_rank_2` and primary
asset cost 2. The free privilege belongs to the consumed Starter instance and
is never inherited. Free L2, L3, and L4 outputs are forbidden.

The merge is never automatic. It still observes the V0.7.1 minimum of five
normal-card instances across draw pile, hand, committed escrow, and discard.
Its Receipt records source definitions, source origin classes, output identity,
output origin class, and `starter_privilege_consumed=true`.

## Zero-Deadlock Opening

Rule: `v072.starter.zero_deadlock_bootstrap`

The existing authoritative `starter_deck_shuffle` stream shuffles all twelve
Starter instances and deals five. Therefore the opening hand has exactly five
Starter cards and five asset-affordable cards. Map and facility legality still
apply, but genesis must guarantee at least one legal Starter facility action.

The first economic facility requires no asset or normal-track purchase. It can
produce real GDP, after which a later authoritative refresh can create the
first nonzero asset and make standard L1 cards payable. This proof cannot inject
assets or add a special first-batch cost rule.

## Player, AI, And Privacy

Rule: `v072.starter.private_observation_and_projection`

The owner-facing Player projection exposes definition ID, origin class, asset
cost, merge family, level, and `starter_badge`. The stable presentation key is
`card.badge.starter`; it must use the existing commercial-art foundation.

The AI self-observation receives definition ID, origin class, asset cost, merge
family, level, and legal targets for its own cards. It must understand that a
Starter remains playable at zero assets, a standard L1 does not, and merging a
Starter permanently consumes free privilege. This is rules parity, not extra
information. Opponents still cannot see exact hands, Starter positions in a
draw pile, future draw order, or exact assets.

## Save And Migration

Rule: `v072.starter.save_identity_and_migration`

Each persisted normal-card instance carries `card_definition_id`,
`card_instance_id`, `origin_class`, `asset_cost_profile`, `level`, and
`merge_family_id`. Starter identity comes from the closed definition contract;
it is never reverse-inferred from a current cost value. Save and replay also
persist the exact profile ID and fingerprint.

```text
V071_SAVE_TO_V072_DIRECT_RESUME=false
V06_SAVE_TO_V072_DIRECT_RESUME=false
V06_SAVE_BACKUP_REQUIRED=true
RESTORE_RNG_DRAW_DELTA=0
```

Missing V0.7.2 fields fail closed. An explicit detached test-only migration may
be tested, but it is not a production migration. V0.7.2 adds no RNG stream and
continues to use `starter_deck_shuffle`.

## First Human Sample Defaults

The approved profile is `V072_STARTER_FREE_FAST`, fingerprint
`b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48`.
Its canonical fingerprint input is stored verbatim in
`v072_balance_defaults.json`.

```text
INITIAL_ASSETS_PER_COLOR=0
STARTER_PRIMARY_ASSET_COST=0
STANDARD_L1_PRIMARY_ASSET_COST=1
NORMAL_CARD_RATIO_BPS=6000
COMMODITY_CARD_RATIO_BPS=4000
INTERVENTION_CAP_ENABLED=true
INTERVENTION_CAP_BPS=1200
MAX_ASSET_REFRESH_PER_COLOR_PER_BATCH=3
HAND_MAINTENANCE_TIMEOUT_SECONDS=8
LEAD_TENURE_BATCHES=1
COLOR_CYCLE_BATCHES=6
TRACK_SCROLL_INTERVAL_SECONDS=5
TRACK_LOCAL_VISIBLE_SLOT_COUNT=5
```

The first three values are frozen structural consequences of this amendment.
The remaining inherited Candidate A values are first-sample balance defaults,
not final commercial balance. Batch counts remain the sole Core authority for
lead and color cycles; second values are presentation estimates only.

## Human Test Boundary

The initial-asset change invalidates V0.7.1 simulation evidence for V0.7.2.
Fresh deterministic comparison across 3, 4, 6, and 8 players is required, with
at least 6,000 matches. It must report whether Starter actions dominate batch
10, whether standard cards stay unaffordable too long, the first nonzero asset
refresh, overflow, resolution duration, and Victory-pending tail.

Human testing must still evaluate Starter badge clarity, the choice to consume
a permanent free card in a merge, opening target legality, long-term standard
card relevance, the eight-second maintenance window, and six/eight-player
fatigue. A frozen sample rule is not proof of fun.
