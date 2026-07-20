# Inherited Region Codex Bridge Oracle Migration

## Classification

`INHERITED_SAME_BOUNDARY_ORACLE`

The previous `service_bridge_api_is_narrow` assertion treated one bridge method as
one bridge call site. It required exactly one occurrence of
`_region_public_bridge.call(` even though the production service already had two
legitimate read-only call sites before the public selection catalog work began.

## Existing Call Sites

1. `compose_source(region_index)` reads public region facts for the requested
   region.
2. `public_region_count()` reads public region facts for region zero and uses the
   public `total` field.

Both sites call the same allowlisted method:
`region_codex_public_facts`.

The production service, bench, and bridge blobs were identical in `origin/main`,
`84b6ebf2640bc95ed1f673af6c6cbe8a5ca7dcf0`, and the candidate HEAD before this
migration:

| File | Blob |
| --- | --- |
| `scripts/runtime/region_codex_public_source_service.gd` | `1d6de62f443382c8f63a6a0ad27f7424d7ce377f` |
| `scripts/tools/region_codex_public_source_bench.gd` | `2aee1a8f83e6cfaa17566b30d0ce19beab619f91` |
| `scripts/runtime/region_infrastructure_world_bridge.gd` | `0e46e709526fcf29fdebf4e9d76fc35b771019d6` |

This proves the failure was inherited and was not introduced by the selection
catalog candidate.

## Replacement Contract

The oracle now requires at least one bridge call, requires every bridge call to
use a literal method name, and requires the unique literal method set to equal
`[region_codex_public_facts]`. Dynamic method names, legacy region snapshots,
commodity aggregation APIs, selection state, Main dependencies, and save
mutation APIs remain forbidden.

An exact call-site count is brittle because adding another valid read-only use of
the same narrow method does not broaden the bridge API. The method allowlist is
the actual authority and privacy boundary.

No production service, bridge, adapter, scene, Main route, or privacy rule was
changed or relaxed by this migration.
