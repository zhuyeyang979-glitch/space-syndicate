# V0.7.1 to V0.7.2 Contract Version Matrix

Status: frozen highest-target, detached implementation only.

V0.7.2 does not reinterpret a V0.7.1 or V0.6 Save. Every affected contract fails closed when the ruleset, interface, state version, required field set, or balance-profile fingerprint differs.

| Domain | V0.7.1 | V0.7.2 | Migration |
| --- | --- | --- | --- |
| Unified Track | `v071.unified_track.core_authority.v2`, state 4 | `v072.unified_track.core_authority.v3`, state 5 | forbidden |
| Card Definition Registry | absent | `space_syndicate.v072.card_definition_registry.v1` | forbidden |
| Personal DBG and all normal-card zones | state 2 | state 3 | forbidden |
| Normal Merge | `V071NormalMergeState@2` | `V072NormalMergeState@3` | forbidden |
| Six-color Assets | `v071.six_color_assets.core_authority.v2`, state 2 | `v072.six_color_assets.core_authority.v3`, state 3 | forbidden |
| AI Observation | canonical adapter v2 | canonical adapter v3 with attested `legal_targets` | forbidden |
| Player Projection | canonical adapter v2 | canonical adapter v3 with Starter presentation semantics | forbidden |
| Save | `space_syndicate.v071.semantic_save.v1` | `space_syndicate.v072.semantic_save.v2` | forbidden |
| RNG Adapter | `space_syndicate.v071.canonical_rng_adapter.v1` | `space_syndicate.v072.canonical_rng_adapter.v2` | forbidden |
| Atomic Manifest | V0.7.1 manifest v2 | V0.7.2 manifest v3 with 16 gates | forbidden |

The machine-readable matrix records every affected state and the typed failure reason. Historical V0.7.1 contracts remain unchanged.
