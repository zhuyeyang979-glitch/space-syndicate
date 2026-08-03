# V0.7.2 Detached Save Schema

`space_syndicate.v072.semantic_save.v2` is the only V0.7.2 target Save envelope. It remains detached from the V0.6 production registry.

The envelope and every affected section require `V072_STARTER_FREE_FAST` with fingerprint `b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48`. Missing or mismatched profile data fails before RNG restore.

Every normal-card instance in draw, hand, committed escrow, and discard preserves:

- `card_definition_id`
- `card_instance_id`
- `origin_class`
- `asset_cost_profile`
- `level`
- `merge_family_id`

Starter identity is read from the closed definition contract, never inferred from a zero cost. Merge lineage records both source definitions and origins, the standard output identity, and `starter_privilege_consumed=true`.

Direct V0.7.1-to-V0.7.2 and V0.6-to-V0.7.2 resume are forbidden. No new field has a silent default. V0.6 backup remains required.
