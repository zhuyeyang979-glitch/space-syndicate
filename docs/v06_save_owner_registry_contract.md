# v0.6 Save Owner Registry Contract

## Boundary

`V06SaveOwnerRegistry` is the single production composition that maps every
required v3 section to one versioned gameplay owner. It is a child of
`GameSessionRuntimeController`, beside `GameSaveRuntimeCoordinator`; it does
not replace the session lifecycle, handshake, envelope validation, write
authorization, or atomic file-I/O owners.

The registry stores bindings only. It does not store gameplay state, discover
owners dynamically, call UI or `main.gd`, or publish an envelope. Capture and
apply operate on pure-data snapshots owned by the bound production nodes.

## Current capability boundary

The registry has exactly the 18 sections declared by
`RulesetSaveHandshakeService.required_section_manifest()`. The first audited
transactional bindings are:

- `session`
- `region_infrastructure`
- `monsters`
- `victory_control`
- `player_organization`
- `player_mana`
- `bankruptcy_neutral_estate`

The remaining 11 sections are explicitly `unsupported` with a non-empty
capability reason. Production capture, preflight, and apply therefore reject
with `restore_capability_incomplete`. This phase does not claim that a whole
run can be restored.

`bankruptcy_neutral_estate` is its own required section. Its runtime controller
owns the transaction lifecycle journal, neutral-rent exact-once journal,
sanitized public receipt, and last-survivor trigger marker. The registry binds
that same owner transactionally; strict save allowlists reject participant
cash, hands, AI plans, and unknown fields. It does not copy any of the five
participant-owner journals.

`player_mana` also binds directly to its sole production owner. Save apply and
rollback restore the saved revision exactly, including private asset pools,
remainders, reservations, and terminal receipts. A detached registry probe can
normalize the payload without enabling business actions on an unconfigured
owner.

The unsupported set remains fail-closed until the existing business owner for
each section provides validation-before-commit and exact rollback capability.
In particular, the registry must not split CommodityFlow state itself, invent
ruleset/belt/inventory/queue/execution apply logic, approximate mana rollback,
or create parallel military/weather/AI state.

## Capture and codec

For a complete registry, capture calls each unique owner in the fixed section
order and wraps its pure state as:

- `schema_version`
- `owner_id`
- `owner_state`

`owner_state` is encoded only through the existing explicit tagged v3 codec.
The real handshake composes and validates the full 18-section envelope. Any
missing owner, method, version, section, codec value, or manifest mismatch
rejects capture before an envelope is returned.

## Apply transaction

Apply uses this fixed sequence:

1. Validate the registry against the authoritative 18-section manifest.
2. Validate the complete envelope through `RulesetSaveHandshakeService`.
3. Decode exact wrappers and run every owner apply on a detached probe.
4. Capture every live owner's rollback checkpoint.
5. Apply live owners in the fixed registry order, with `session` last.
6. Re-capture and compare the normalized encoded owner state after each apply.
7. On any failure or mismatch, roll back every touched owner, including the
   failing owner, in exact reverse order.
8. Re-capture every rolled-back owner and require exact encoded equality with
   its checkpoint. Any compensation failure remains an explicit failed result.

No live owner is mutated until the full envelope and all owner preflights have
succeeded. A registry-busy request also fails closed.

## Privacy

Internal capture/apply results may carry an envelope or section IDs for the
authorized persistence caller and focused tests. Public consumers must use
`public_operation_receipt()`, which emits only normalized scalar status,
counts, and rollback flags. It never emits sections, fingerprints, exact cash,
hands, owner truth, AI plans, applied section IDs, or rollback section IDs.
Unknown operations/reason codes and forged values in allowlisted fields are
normalized to fail-closed public values.

## Gate

- Production scene: `res://scenes/runtime/V06SaveOwnerRegistry.tscn`
- Production composition: `res://scenes/runtime/GameSessionRuntimeController.tscn`
- MCP Bench: `res://scenes/tools/V06SaveOwnerRegistryBench.tscn`
- Headless test: `res://tests/v06_save_owner_registry_test.gd`
- PlayerMana transaction: `res://tests/player_mana_save_owner_transaction_test.gd`
- Bankruptcy transaction: `res://tests/bankruptcy_neutral_estate_save_owner_transaction_test.gd`

The gate covers exact manifest mapping, the production 8/10 capability
boundary, full fake-owner capture through the real handshake, late preflight
rejection with zero live mutation, fixed-order apply, reverse-order rollback
including a partially mutated failing owner, exact checkpoint restoration, and
adversarial public-receipt privacy. The owner-focused tests additionally prove
detached preflight, repeated exact rollback, and private-field rejection for the
newly transactional PlayerMana, Bankruptcy, and Weather sections. Weather
restore is exact and clock-neutral during apply; lifecycle catch-up happens on
the first owner tick after the Session owner restores world-effective time.
