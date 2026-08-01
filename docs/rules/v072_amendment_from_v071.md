# V0.7.1 To V0.7.2 Approved Amendment

```text
AMENDMENT_ID=space_syndicate.v072.amendment_from_v071
FROM_RULESET_ID=v0.7.1
TO_RULESET_ID=v0.7.2
STATUS=approved_and_frozen
USER_APPROVES_V072_FREE_STARTER_BOOTSTRAP=true
APPROVED_PROFILE_ID=V072_STARTER_FREE_FAST
V07_HISTORICAL_CONSTITUTION_CONTENT_CHANGE_COUNT=0
V071_HISTORICAL_CONSTITUTION_CONTENT_CHANGE_COUNT=0
CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6
FULL_V0_7_2_RUNTIME_CUTOVER=false
HUMAN_FUN_PROVEN=false
HUMAN_TEST_REQUIRED=true
```

This amendment does not edit the frozen V0.7 or V0.7.1 files. It composes the
complete V0.7.1 authority with eight approved V0.7.2 rules for a zero-asset,
free-Starter opening economy.

## Frozen Changes

| ID | V0.7.2 rule | Frozen decision |
| --- | --- | --- |
| V072-S1 | `v072.assets.zero_genesis_balances` | The six-color Owner exists, but all balances and remainders begin at zero. |
| V072-S2 | `v072.starter.closed_definition_registry` | Genesis creates one instance of each of twelve stable Starter definitions; no post-genesis or track creation is legal. |
| V072-S3 | `v072.starter.persistent_zero_asset_cost` | Starter identity has a persistent zero-asset cost profile across every DBG cycle, Save, and Restore. |
| V072-S4 | `v072.standard.level_one_asset_cost` | Standard L1 factories and markets cost one matching-color asset and remain separate from Starter definitions. |
| V072-S5 | `v072.starter.standard_merge_consumes_privilege` | An optional matching Starter+standard L1 merge creates a standard L2 costing two; free privilege is consumed. |
| V072-S6 | `v072.starter.zero_deadlock_bootstrap` | Five shuffled Starter cards are asset-affordable and at least one legal opening facility action is required. |
| V072-S7 | `v072.starter.private_observation_and_projection` | Owner-facing AI and Player views receive stable identity/cost semantics without exposing opponent cards or assets. |
| V072-S8 | `v072.starter.save_identity_and_migration` | Stable definition, instance, origin, cost-profile, level, family, and profile identity are saved; older Saves fail closed. |

## Profile Binding

```text
PROFILE_ID=V072_STARTER_FREE_FAST
PROFILE_FINGERPRINT_INPUT=V072_STARTER_FREE_FAST|initial_assets_per_color=0|starter_primary_asset_cost=0|standard_l1_primary_asset_cost=1|normal_card_ratio_basis_points=6000|commodity_card_ratio_basis_points=4000|single_color_net_intervention_cap_enabled=true|single_color_net_intervention_cap_basis_points=1200|max_asset_refresh_per_color_per_batch=3|hand_maintenance_timeout_seconds=8|lead_tenure_batches=1|color_cycle_batches=6
PROFILE_FINGERPRINT=b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48
```

V0.7.1 Candidate A remains historical comparison evidence. Its opening value
of two assets per color is not a V0.7.2 authority. The 60/40 supply ratio,
1,200-basis-point intervention cap, three-point refresh cap, eight-second
maintenance, one-batch lead tenure, six-batch color cycle, five-second scroll,
and five visible slots remain first-sample defaults rather than final balance.

## Migration And Runtime Boundary

V0.7.1 and V0.6 Saves cannot directly resume as V0.7.2. A detached test-only
migration must be explicit and fail closed on missing identity fields. Restore
cannot advance RNG. V0.7.2 adds no RNG stream and keeps
`starter_deck_shuffle`.

This docs-only freeze does not connect Detached Core or adapters to production,
does not mutate V0.6, and does not authorize dual write. Runtime cutover remains
blocked until the separately authorized atomic-cutover task after PR #77.

## Evidence Boundary

Changing genesis assets from two to zero means the prior 6,000 V0.7.1 matches
cannot serve as V0.7.2 balance evidence. A fresh 6,000-match deterministic
comparison must cover 3, 4, 6, and 8 players and disclose Starter dominance or
slow standard-card economy. Simulation does not prove human fun.
