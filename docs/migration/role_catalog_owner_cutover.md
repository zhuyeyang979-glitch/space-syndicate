# Role catalog read-only owner cutover

Status: `ROLE_CATALOG_READ_ONLY_OWNER_CUTOVER_GREEN`

## Authority

- Scene: `res://scenes/runtime/RoleCatalogRuntimeService.tscn`
- Script: `res://scripts/runtime/role_catalog_runtime_service.gd`
- Composition: the one scene instance under `GameRuntimeCoordinator`
- Canonical count: 24
- Canonical source audit hash: `7609b20741bec0e835e7768f2301f587c1848180a49aad8ca7c767e6c8d1cbe0`

The service owns the original ordered role definitions and returns duplicated
read-only projections. `PLAYER_ROLE_CATALOG` was physically removed from Main
in the same atomic cutover, so there is no second production catalog.

## Preserved contracts

- Chinese role name and array index remain runtime and save identity.
- Setup order and random selection behavior are unchanged.
- AI role choice and passive values are unchanged.
- Existing save fields (`role_index`, `role_name`, `role_card`) are unchanged.
- Starter monster selection remains independent from role selection.
- The PlayerSeat path remains `WorldSessionState -> WorldSessionPublicProjection.role_name -> PlayerSeatPublicSourceService -> RoleSeatLayerHost`.
- Portrait manifest names, slugs, rendered count 8 and pending count 16 remain unchanged.

## Public API

`role_count`, `ordered_role_names`, `definition_at`, `definition_by_name`,
`index_by_name`, `public_definition_at`, and `validate_catalog`.

## Evidence

`res://tests/role_catalog_runtime_service_test.gd` verifies count, order, full
field parity, immutable copies, duplicate count, setup/AI/passive/save/public
projection parity and portrait-manifest parity.
