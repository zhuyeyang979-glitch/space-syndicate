# Organization Production Composition v0.6

## Boundary

`PlayerOrganizationRuntimeController` remains the only owner of organization slots, revisions, lifecycle journals, and private capability terms. `OrganizationProductionPortV06` is a stateless production forwarding boundary: it owns no organization, card, cash, asset, window, monster, military, or save truth.

Organization cards enter the existing CardFlow path only when the catalog machine field is:

```text
effect_kind = install_organization_upgrade
```

Names and player text never select the route. The existing Inventory/CardFlow transaction remains the only transaction that consumes the card and colored assets.

## Atomic order

The single outer transaction performs:

1. Read the authoritative card instance and effect kind from Inventory.
2. Check organization consumer readiness before reserving or committing player resources.
3. Prepare the organization owner without mutation.
4. Prepare the existing player-state mutation.
5. Commit the organization owner.
6. Commit card/asset state through the existing CardFlow state port.
7. Roll back the organization owner if the outer state commit fails.
8. Finalize the organization owner after the outer commit succeeds.

The router records transaction-to-effect association during prepare. Commit, rollback, and finalize use that association; receipt-reported effect kinds cannot select another owner. Replays are returned by the existing CardFlow journal and the organization owner's exact-once journal.

## Consumer readiness gate

The public readiness snapshot always lists:

- `asset_recovery`
- `hand_limit`
- `card_window`
- `monster_binding`
- `military_command`

Except for the frozen Monster provider API below, a consumer is ready only when its real production node both declares `organization_consumer_capabilities_v06(domain)` and implements the domain's functional ingestion method. Request payloads and caller-supplied readiness fields are ignored. If any domain is missing, organization play returns `organization_consumer_capabilities_incomplete` before CardFlow resource commit.

Reference consumers may satisfy the same object-and-method probes in focused tests. They never change production readiness.

## Monster binding delegate

When available, `MonsterRuntimeController.configure_monster_binding_capability_provider_v06(provider)` receives the production port. The provider implements:

- `current_monster_binding_window_snapshot_v06()`
- `monster_binding_caps(actor_id, window_sequence)`
- `monster_binding_caps_for_target_owner(actor_id, window_sequence)`

Window sequence and revision are read live from the single CardResolutionQueue owner. Capability terms are forwarded live from the single organization owner. The delegate caches neither window facts nor capability snapshots and never accepts either from a play request.

## Save and checkpoint

Coordinator exposes `player_organization_to_save_data`, `apply_player_organization_save_data`, and `player_organization_checkpoint_status`. A prepared or rollback-open organization transaction makes checkpoint save fail closed. Only a checkpoint-safe owner snapshot is returned as save-ready.

The organization owner snapshot contains its finalized and inflight lifecycle truth. CardFlow continues to own its separate player-resource terminal journal; no second save or transaction truth is introduced.

## Privacy

Internal lifecycle receipts retain actor binding because CardFlow validates it. Player-facing code must use `organization_public_receipt` or the port's `public_receipt`, which omits actor identity, exact consumer capabilities, private hand/cash data, hidden ownership, and AI planning metadata. Public readiness contains only domain names and ready booleans.

## Current production status

The unique organization owner and field route are composed. Monster binding uses the frozen provider boundary when its owner parses and declares it. The remaining business consumers are intentionally not connected in this task, so organization cards remain safely unavailable in production until all five domains are real and ready.
