# Monster organization binding provider v0.6

## Ownership boundary

`MonsterRuntimeController` remains the only monster roster, UID, rank, hidden-owner, lifecycle, journal, save/load and legality owner. `PlayerOrganizationRuntimeController` remains the only organization slot and capability owner. The Monster owner stores one provider object reference and never copies organization slots or cap state into its save data.

The production integration surface is one call:

```gdscript
monster_owner.configure_monster_binding_capability_provider_v06(provider)
```

The provider is a stateless trusted delegate and must expose:

```gdscript
current_monster_binding_window_snapshot_v06() -> Dictionary
monster_binding_caps(actor_id, window_sequence) -> Dictionary
monster_binding_caps_for_target_owner(actor_id, window_sequence) -> Dictionary
```

It may additionally expose `validate_monster_binding_caps_v06(snapshot, for_target_owner)`. When present, validator rejection is fail-closed. The provider must obtain the current window and capability directly from authoritative production owners; it must not accept a client-supplied cap, owner, window or revision.

## Validation and fallback

The Monster owner requires an authoritative current window, exact actor binding, exact window sequence, nonnegative organization owner revision, `capability_kind=monster_caps`, and one exact official cap tuple. A mismatched actor/window/kind, invalid revision, illegal tuple, failed validator or unavailable provider cannot elevate permission and resolves to the base rules:

| Capability | Count | Primary rank | Secondary rank |
|---|---:|---:|---:|
| Base / invalid provider | 1 | II | none |
| Organization I | 1 | III | none |
| Organization II | 1 | IV | none |
| Organization III | 2 | IV | II |
| Organization IV | 2 | IV | IV |

Stable binding slots are ordered by Monster UID. A request field that claims a higher cap is ignored.

## Lifecycle binding

Starter summon, ordinary summon, self-upgrade and cross-player same-family reinforcement resolve a cap snapshot during prepare. The reservation stores only opaque binding evidence: target actor, query kind, window/revision and a fingerprint. It does not store the external count/rank cap row. Commit re-queries the current authoritative provider; any change to the current window, organization revision or cap terms returns `monster_binding_capability_changed` before roster mutation.

Cross-player reinforcement always queries `monster_binding_caps_for_target_owner` for the existing monster owner. The acting player's organization cannot grant rank to another owner's monster. Owner/control/cash attribution and bound-skill recipient remain the existing owner.

## Capability compression

If an organization expires or downgrades, existing monsters are not deleted or demoted. The private owner snapshot derives `suspended_for_new_upgrade` dynamically:

- a monster outside the current count limit is suspended;
- a monster whose current rank exceeds its stable slot rank limit is suspended;
- a suspended monster cannot receive a new upgrade;
- no new monster can be summoned beyond the current count/slot rank limit;
- restoring the capability clears the derived suspension without rewriting the roster.

Command legality for suspended monsters belongs to the command owner and is outside this task.

## Save/load and privacy

Monster save data persists roster and transaction binding evidence, never the provider object or an external exact cap row. After load, the Coordinator must configure the provider again; until then, base 1×II applies. Pending reservations re-query current facts before commit.

Public snapshots do not include organization identity, exact cap values, capability fingerprints, hidden monster owner, AI plans or opponent-private state. Private owner snapshots expose only the derived eligibility boolean and localized-neutral status code needed by the owning player.

## C15 production wiring

The Coordinator should construct or expose one stateless delegate over the authoritative current card-window source and `PlayerOrganizationRuntimeController`, then call the configure API after both owners are mounted and again after composition/load replacement. It must not cache capability rows or authorize requests itself.
