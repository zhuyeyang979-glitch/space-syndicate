# Player Organization Runtime v0.6

## Purpose

`PlayerOrganizationRuntimeController` is the single owner of per-player organization upgrades. An organization card installs one persistent self-upgrade into one of three organization slots. It does not own cash, six-color assets, cards, hand mutations, queues, monsters, military units, GDP, or public identity resolution.

The runtime accepts only the catalog contract:

- `effect_kind = install_organization_upgrade`
- `target_kind = self_organization_slot`
- three slots per player
- same-family higher-rank replacement only
- equal/lower-rank attempts reject during prepare, before CardFlow consumes the card
- all successful installs activate at the start of the next shared window
- all upgrades persist for the run

## Owned state

Each registered actor has:

- an opaque `actor_id` used only in private/runtime state;
- a monotonic owner revision;
- exactly three organization slots;
- zero or one installed record per organization family.

The controller additionally owns its transaction lifecycle journal and a private capability-signing secret. It owns no business currency or gameplay entity roster.

## Atomic lifecycle

The production lifecycle is:

1. `prepare_organization_upgrade(intent)` validates binding, self-target, authoritative window sequence, catalog payload, owner revision, slot availability, and replacement rank. It records preimage/postimage but does not change a modifier.
2. `commit_organization_upgrade(prepared)` verifies the prepared token and unchanged preimage, then swaps the complete player state once.
3. `rollback_organization_upgrade(receipt)` restores modifier content from the preimage in one swap. The owner revision remains monotonic so pre-commit capabilities cannot become valid again.
4. `finalize_organization_upgrade(receipt)` closes rollback without changing gameplay state.
5. `abort_prepared_organization_upgrade(prepared)` closes a side-effect-free prepare when CardFlow rejects before effect commit.

Every transaction ID is bound to actor, card, card instance, effect, target hash, payload hash, and intent hash. Same-binding replay returns the recorded receipt. A different binding using the same transaction ID fails closed.

`checkpoint_status()` is false while any transaction is prepared or committed with rollback open. Save data nevertheless records the full lifecycle so recovery code can explicitly roll back or finalize an inflight transaction after load.

## Five organization families

| Family | Axis | I | II | III | IV |
|---|---|---|---|---|---|
| `organization.starport_clearinghouse` | Asset conversion | +500 bp, cap 50 milli/s | +1000, cap 100 | +1500, cap 150 | +2000, cap 200 |
| `organization.quantum_agenda_network` | Action bandwidth | +1, surcharge 4 | +1, surcharge 3 | +1, surcharge 2 | +1, surcharge 1; every third active window gets a third submission at surcharge 4 |
| `organization.deep_space_archive` | Hand capacity | 6 | 7 | 8 | 9 |
| `organization.monster_liaison_charter` | Monster binding | 1 primary up to III | 1 primary up to IV | primary IV + secondary II | 2 up to IV |
| `organization.stellar_command_directorate` | Military command | 1 primary up to III | 1 primary up to IV | primary IV + secondary II | 2 up to IV |

Monster organization terms never create continuous player control. They only expose binding/rank limits to the monster owner. A same-name reinforcement targeting another player's monster queries that current owner's caps and does not transfer ownership.

## Read-only consumer APIs

These APIs are private authoritative snapshots. Consumers must not cache them across owner revisions or windows.

### Asset recovery

```gdscript
asset_recovery_terms(actor_id, window_sequence)
```

Returns the same-color GDP conversion bonus in basis points and the total bonus cap in milli-assets per second. `PlayerManaRuntimeController` remains the only asset recovery owner and must consume these terms without moving asset state here.

### Hand capacity

```gdscript
hand_limit_terms(actor_id, window_sequence)
```

Returns base five, the authorized ordinary hand limit, bonus, and absolute cap nine. Inventory/CardFlow remain the only hand mutation owners.

### Shared-window submission capability

```gdscript
card_window_submission_capability(actor_id, window_sequence)
validate_card_window_submission_capability(capability)
```

The capability binds:

- `actor_id`
- `window_sequence`
- `owner_revision`
- opaque `capability_id`
- base, bonus, effective, and hard submission limits
- activation/expiry window
- extra-card surcharge and optional IV burst surcharge

The queue must receive a controller-issued capability through authoritative facts. A request's `max_cards` or copied partial fields never grant permission. Response cards remain outside ordinary submission count and are not implemented by this controller.

### Monster and military caps

```gdscript
monster_binding_caps(actor_id, window_sequence)
monster_binding_caps_for_target_owner(actor_id, window_sequence)
military_command_caps(actor_id, window_sequence)
```

MonsterRuntime and MilitaryRuntime remain the final legality and roster owners. These snapshots only provide authorized count/rank terms.

## CardFlow adapter

`OrganizationCardEffectAdapterV06` translates the existing CardFlow effect-handler surface directly to the organization owner:

- `prepare_effect`
- `commit_effect`
- `rollback_effect`
- `finalize_effect`
- `abort_prepared_effect`
- `checkpoint_status`

It does not establish a second transaction service or consume a card itself.

## Save and privacy

`to_save_data()` and `apply_save_data()` include player modifier state, journal, revisions, and the private capability secret. Save data is internal/private.

`public_snapshot()` contains only static system rules. It intentionally excludes:

- actor or owner identity;
- exact hand limit;
- exact asset conversion multiplier/cap;
- monster or military capacity;
- private capabilities and signatures;
- AI reasoning or score fields.

The anonymous public card track may show that an organization axis was installed, but identity association belongs to the existing anonymous reveal system, not this owner.

## Production integration still required

The controller and adapter are not yet mounted in the production Coordinator. The minimum future integration is:

1. mount exactly one `PlayerOrganizationRuntimeController` scene;
2. register current run actor IDs;
3. route `install_organization_upgrade` through the existing Inventory/CardFlow transaction and `OrganizationCardEffectAdapterV06`;
4. pass authoritative current window sequence and expected organization revision in target context;
5. have PlayerMana, Inventory/CardFlow, Queue, MonsterRuntime, and MilitaryRuntime consume only the narrow read APIs above;
6. add owner save/load at the existing coordinated checkpoint boundary;
7. keep public UI on `public_snapshot()` and local-player details on `private_snapshot()` only.

Do not place organization state in `main.gd`, accept limits directly from player requests, or add parallel owners for cards, assets, units, or queue state.
