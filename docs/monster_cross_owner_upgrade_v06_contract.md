# Monster Cross-Owner Same-Family Upgrade Contract v0.6

Status: owner runtime implemented; production Rank II-IV profile and organization-cap facts remain integration dependencies.

## Authority and scope

`MonsterRuntimeController` remains the only roster/UID/selection/starter-marker owner. `CardFlowTransactionServiceV06` remains the only outer card/cash/asset transaction owner. The upgrade path never creates a second roster, inventory, journal, or player-state owner and never changes autonomous movement, combat, wager, damage, or target-weight rules.

The supported owner actions are:

- Rank-I starter first summon.
- Ordinary same-family reinforcement of the single active global monster of that family.

Ordinary deployment of a new family, lure, direct control, and bound-action expansion remain outside this slice.

## Resolution rules

1. An active monster family is globally unique in the v0.6 roster. More than one active v0.6 row of one family is corruption and fails closed.
2. A player whose starter state is `not_summoned` never upgrades an existing rival monster. A family collision returns `starter_monster_family_reserved`, `prepared=false`, `card_consumed=false`, and a private reselect payload without the existing owner's identity.
3. A player whose starter state is `summoned` may reinforce the globally unique same-family monster regardless of ownership. The intent must bind the authoritative unit UID, actor revision, card payload, transaction ID, and acting-player rule revision.
4. New rank is `clamp(max(current_rank + 1, card_rank), 1, 4)`. Rank IV repeats at IV.
5. The target owner's authoritative binding-rule snapshot supplies `monster_binding_rank_cap`, `primary_monster_rank_limit`, or `base_primary_monster_rank_limit`, in that order. If none is present, the only permitted fallback is the base primary cap Rank II. Request/payload cap fields are ignored.
6. Upgrade restores HP to the new authoritative profile maximum and adds the catalog's `same_name_upgrade_extend_seconds` to both total and remaining presence time. It does not reset elapsed time.
7. UID, slot, owner actor, owner index/control, reveal/clue state, and owner-damage cash attribution remain unchanged.
8. A non-empty bound-skill patch is routed to `bound_skill_recipient_actor_id = existing monster owner`. The acting player receives no control, skill, role-cash patch, or discount from reinforcement.

## Atomic lifecycle

Prepare validates catalog binding, acting-player rule revision, target UID/revision/family, target-owner rule fingerprint/rank cap, next-rank profile, dependency capabilities, and full pre/postimage fingerprints. Prepare performs no business mutation.

Commit revalidates both rule snapshots, target-owner cap, profile fingerprint, owner revision, and full core preimage before committing cross-owner participants and swapping the roster postimage once.

Rollback requires the authoritative transaction association and exact postimage, compensates cross-owner participants first, then restores the preimage in one swap. A failed compensation never claims `rolled_back=true`.

Finalize closes the rollback window, journals the terminal receipt, and emits one anonymous presentation event. Replay uses the owner transaction journal and cannot re-upgrade or re-grant a skill.

Save/load validates roster UIDs, active v0.6 family uniqueness, reservation fingerprints, journal bindings, and the core-state image before replacing owner state.

## Privacy

Public roster and receipt projections expose unit identity, family, rank, HP, duration, region, and reveal status only. They do not expose `owner_actor_id_v06`, acting actor, target owner, player index, private skill recipient, cash, hand, AI plan, rule fingerprint, or rank-cap provenance.

The private starter reselect payload is visible only through the existing actor-scoped private receipt projection. It contains no opponent identity.

## Production dependencies

- The binding-rule owner may add an authoritative primary monster rank cap. Until then, production is deliberately limited to Rank II.
- `monster_deploy_profile_snapshot_v06(family_id, rank)` must expose authoritative Rank II-IV profiles before production can upgrade beyond the current Rank-I-only provider.
- Any non-empty bound-skill patch requires a real `bound_skill_inventory` participant with prepare/commit/rollback/finalize/exact-once/checkpoint/save-load capability. Missing capability fails before roster mutation.
